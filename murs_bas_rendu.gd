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

## La hauteur qui marque une lampe SANS POINT D'ORIGINE : le shader ne lui
## applique pas la zone morte. Seul le bandeau LED des murs la porte
## (`mur_led.gd`). Voir `mb_dans_la_zone_morte()` : aucune autre lampe du jeu ne
## pose de hauteur, qui n'a d'effet qu'avec une carte de normales.
const HAUTEUR_SANS_ORIGINE := 1.0


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
		var rentre := r.grow(-MapGeometry.OCCLUDER_INSET)
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
	return {"murs": tableau, "nb": nb, "l_sol": l_sol, "l_accroupi": l_acc,
		"echelle": echelle, "debordement": debordement}


## Remplit un matériau de sol ou de décor pour sa vue.
static func poser_sol(m: ShaderMaterial, u: Dictionary) -> void:
	_poser(m, u, u["l_sol"], Vector2.ZERO, false)


## Remplit le matériau d'un corps : jugé en son centre (écran), zone morte d'un
## accroupi s'il l'est, aucune debout — « un mur bas laisse voir une tête debout ».
static func poser_corps(m: ShaderMaterial, u: Dictionary, centre_ecran: Vector2, accroupi: bool) -> void:
	_poser(m, u, u["l_accroupi"] if accroupi else 0.0, centre_ecran, true)


static func _poser(m: ShaderMaterial, u: Dictionary, zone: float, centre: Vector2, au_centre: bool) -> void:
	if m == null:
		return
	m.set_shader_parameter("mb_nb_murs", u["nb"])
	m.set_shader_parameter("mb_murs", u["murs"])
	m.set_shader_parameter("mb_zone_morte", zone)
	m.set_shader_parameter("mb_centre", centre)
	m.set_shader_parameter("mb_au_centre", au_centre)
