class_name MursBasRendu
## Chantier MURS BAS, étape MB3c — la zone morte dessinée à l'écran.
##
## `MursBas` (murs_bas.gd) dit la règle, dans le monde. Ce fichier la PORTE aux
## matériaux : il convertit murs bas et longueurs de zone morte dans l'espace
## écran d'une vue, celui où `light()` lit LIGHT_POSITION et LIGHT_VERTEX, et
## remplit les uniformes de `murs_bas_zone.gdshaderinc`.
##
## Aucun autoload, aucun nœud : tout se vérifie en headless
## (`tools/test_murs_bas_rendu.gd`). Ce qui ne se vérifie qu'en fenêtre — que le
## pixel suive la règle — est au banc `tools/banc_murs_bas.tscn`.

const SHADER_SOL := preload("res://murs_bas_sol.gdshader")
const SHADER_DECOR := preload("res://murs_bas_decor.gdshader")

## Nombre de murs bas qu'un matériau peut recevoir (`mb_murs[64]` dans l'include).
const MURS_MAX := 64

## La hauteur qui marque une lampe SANS POINT D'ORIGINE, en pixels : le shader ne
## lui applique aucune zone morte. Seul le bandeau LED des murs la porte
## (`mur_led.gd`). Voir `mb_dans_la_zone_morte()`.
##
## ⚠️ **Elle valait 1,0 jusqu'au chantier Gadgets et lumières (2026-09-15)**, quand
## « hauteur non nulle » voulait dire « sans origine ». Les sources ont désormais une
## vraie hauteur (`poser_hauteur_source`) : une braise vaut 1,75 px, et 1,0 se serait
## lu comme une source au ras du sol. La marque est donc hors de toute hauteur réelle
## — 117 tuiles —, et le shader la reconnaît par un seuil (`mb_z_sans_origine`, sa
## moitié à l'écran), jamais par une égalité : la hauteur y arrive multipliée par
## l'échelle de la vue.
const HAUTEUR_SANS_ORIGINE := 4096.0

## Gadgets et lumières (2026-09-15) — les hauteurs des sources, en tuiles. Une source
## qui en déclare une suit la règle de la hauteur (`zone_morte_source`) ; une source
## qui n'en déclare pas suit la règle du jeu (« un même angle »). Voir la section
## « Gadgets et lumières en iso » de la ROADMAP pour le pourquoi de chaque valeur.
const HAUTEUR_FUSEE_LANCER := 1.5
const HAUTEUR_FUSEE_AU_SOL := 0.15
const HAUTEUR_AU_RAS_DU_SOL := 0.05
## Plus bas que ceci, une hauteur n'en est plus une : 0 veut dire « règle du jeu ».
const HAUTEUR_MIN := 0.01


## Donne à une lampe sa hauteur de source, en tuiles, et le masque d'ombre qui va
## avec : au ras d'un muret ou plus bas, elle bute dessus (`COUCHE_OMBRE_MUR_BAS`,
## ombre infinie, comme la torche d'un accroupi) ; plus haut, elle passe par-dessus
## et le shader dessine la zone morte finie que sa hauteur laisse derrière lui.
##
## ⚠️ **Le seul endroit du jeu qui pose `height` sur une lampe de gameplay** — les
## deux décisions (hauteur, masque) se prennent ensemble ou pas du tout : une lampe
## basse sans le bit traverserait les murets, une lampe haute avec lui y buterait.
## `tools/test_murs_bas_rendu.gd` refuse toute autre écriture de `height`.
static func poser_hauteur_source(lumiere: Light2D, tuiles: float) -> void:
	if lumiere == null:
		return
	var h := maxf(tuiles, HAUTEUR_MIN)
	lumiere.height = MursBas.en_pixels(h)
	lumiere.shadow_item_cull_mask = CanauxLumiere.masque_ombre_posture(
		lumiere.shadow_item_cull_mask, h <= MursBas.HAUTEUR_MUR_BAS)


## La hauteur de source d'une lampe, en tuiles — 0 si elle n'en déclare pas (règle du
## jeu), -1 si elle n'a pas de point d'origine.
static func hauteur_source(lumiere: Light2D) -> float:
	if lumiere == null or lumiere.height <= 0.0:
		return 0.0
	if lumiere.height >= HAUTEUR_SANS_ORIGINE * 0.5:
		return -1.0
	return lumiere.height / MursBas.TUILE


## LA règle de la hauteur, jumelle de `mb_dans_la_zone_morte()` : longueur de la zone
## morte derrière un muret, comptée depuis sa face de sortie, pour une source à
## `h_source` dont le rayon sort du muret à la distance `d_sortie`. Unités libres,
## mais les mêmes pour les trois hauteurs et pour `d_sortie`.
##
## `INF` si la source ne dépasse pas le muret (elle bute) ; 0 si la cible le dépasse.
static func zone_morte_source(d_sortie: float, h_source: float, h_mur: float, h_cible: float) -> float:
	if h_source <= h_mur:
		return INF
	if h_cible >= h_mur:
		return 0.0
	return d_sortie * (h_mur - h_cible) / (h_source - h_mur)


## `MursBas.franchit()` pour une source qui a une hauteur, et pour la lumière seule :
## ce que le shader et l'occluder dessinent ensemble, point par point. Pixels de monde,
## murets déjà rentrés (`MursBas.forme_de_lumiere`).
static func eclaire_par_hauteur(source: Vector2, cible: Vector2, h_source: float, h_cible: float,
		murs: Array, h_mur: float) -> bool:
	var longueur := (cible - source).length()
	for r: Rect2 in murs:
		var t := MursBas.sortie_du_rect(source, cible, r)
		if t < 0.0:
			continue
		if (1.0 - t) * longueur < zone_morte_source(t * longueur, h_source, h_mur, h_cible):
			return false
	return true


## Un matériau de sol neuf. Additif, comme le `CanvasItemMaterial` qu'il remplace.
static func materiau_sol() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_SOL
	return m


## Un matériau de décor peint neuf. Mélange normal.
static func materiau_decor() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_DECOR
	return m


## Les uniformes communs d'une vue : murs en écran, longueurs de zone morte en
## pixels d'écran.
##
## `monde_vers_ecran` : la transformation du repère des murs (celui de l'arène)
## vers les pixels de la cible de rendu. `ecran` : le rectangle de la cible, en
## pixels ; seuls les murs dont la zone morte peut y tomber sont gardés — la
## fenêtre agrandie de la plus longue zone. Au-delà de `MURS_MAX`, les murs en
## trop sont perdus et `debordement` le dit.
##
## Les murs sont RENTRÉS de `MapGeometry.OCCLUDER_INSET`, comme leur occluder :
## pour la LUMIÈRE, un mur bas n'a qu'une forme, que la lampe soit haute (ici) ou
## basse (l'occluder plein). Mesuré au prototype MB0 : avec les rectangles pleins,
## des points rasant un bout de mur sous une torche accroupie étaient noircis par
## le shader et pas par l'occluder.
static func uniformes_de_vue(monde_vers_ecran: Transform2D, murs: Array, ecran: Rect2) -> Dictionary:
	var echelle := monde_vers_ecran.get_scale().x
	var h_mur := MursBas.hauteur_mur()  # déjà en pixels
	var angle := MursBas.ANGLE_FRANCHISSEMENT
	var l_sol := MursBas.longueur_zone_morte(h_mur, 0.0, angle) * echelle
	var l_acc := MursBas.longueur_zone_morte(h_mur, MursBas.en_pixels(MursBas.HAUTEUR_ACCROUPI), angle) * echelle
	var champ := ecran.grow(l_sol)
	var tableau := PackedVector4Array()
	var debordement := 0
	for r: Rect2 in murs:
		var rentre := r.grow(-MursBas.RETRAIT_LUMIERE)
		var a := monde_vers_ecran * rentre.position
		var b := monde_vers_ecran * rentre.end
		var e := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		if not champ.intersects(e, true):
			continue
		if tableau.size() >= MURS_MAX:
			debordement += 1
			continue
		tableau.append(Vector4(e.position.x, e.position.y, e.end.x, e.end.y))
	var nb := tableau.size()
	tableau.resize(MURS_MAX)
	# ⚠️ Le champ ci-dessus est agrandi de `l_sol`, la zone de la règle du jeu. La zone
	# d'une source à hauteur peut être plus longue (une fusée basse loin d'un muret) :
	# un muret hors de ce champ ne projette alors pas la sienne sur le bord de l'écran.
	# Signalé dans la ROADMAP (Gadgets et lumières) plutôt qu'élargi à l'aveugle — les
	# rectangles gardés font le coût du shader.
	return {"murs": tableau, "nb": nb, "l_sol": l_sol, "l_accroupi": l_acc,
		"echelle": echelle, "debordement": debordement,
		"h_mur": h_mur * echelle,
		"h_accroupi": MursBas.en_pixels(MursBas.HAUTEUR_ACCROUPI) * echelle,
		"h_debout": MursBas.en_pixels(MursBas.HAUTEUR_DEBOUT) * echelle,
		"z_sans_origine": HAUTEUR_SANS_ORIGINE * 0.5 * echelle}


## Remplit un matériau de sol ou de décor pour sa vue.
static func poser_sol(m: ShaderMaterial, u: Dictionary) -> void:
	_poser(m, u, u["l_sol"], Vector2.ZERO, false, 0.0)


## Remplit le matériau d'un corps : jugé en son centre (écran), zone morte d'un
## accroupi s'il l'est, aucune debout — « un mur bas laisse voir une tête debout ».
## Pour une source à hauteur, la cible est à la hauteur de la posture.
static func poser_corps(m: ShaderMaterial, u: Dictionary, centre_ecran: Vector2, accroupi: bool) -> void:
	_poser(m, u, u["l_accroupi"] if accroupi else 0.0, centre_ecran, true,
		u["h_accroupi"] if accroupi else u["h_debout"])


static func _poser(m: ShaderMaterial, u: Dictionary, zone: float, centre: Vector2, au_centre: bool,
		h_cible: float) -> void:
	if m == null:
		return
	m.set_shader_parameter("mb_nb_murs", u["nb"])
	m.set_shader_parameter("mb_murs", u["murs"])
	m.set_shader_parameter("mb_zone_morte", zone)
	m.set_shader_parameter("mb_centre", centre)
	m.set_shader_parameter("mb_au_centre", au_centre)
	m.set_shader_parameter("mb_h_mur", u["h_mur"])
	m.set_shader_parameter("mb_h_cible", h_cible)
	m.set_shader_parameter("mb_z_sans_origine", u["z_sans_origine"])
