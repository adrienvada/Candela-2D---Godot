extends Node2D

## Le prototype des MURS BAS ET DE L'ACCROUPI — chantier MB, étape MB0.
##
## Lancer (fenêtre obligatoire : rien ne se rastérise en headless) :
##   /Applications/Godot.app/Contents/MacOS/Godot --path "<worktree>" \
##       res://tools/proto_murs_bas.tscn -- --no-eos
## Options après `--` : `--piste A|B|C`, `--auto` (contrôles puis sortie),
## `--capture <dossier>` (écrit les images des contrôles).
##
## ## Ce qu'il doit montrer
##
## Les six règles d'Adrien du 2026-09-14, dans une arène de murs hauts et de
## trois murs bas, sous une seule torche qu'on déplace :
##   1. un mur bas arrête la lumière mais laisse voir une tête debout ;
##   2. un accroupi derrière un mur bas n'est pas éclairé depuis l'autre côté,
##      mais l'est par une lumière venue de son côté ;
##   3. balles et lumière debout franchissent le mur bas selon un même angle :
##      un accroupi loin derrière redevient visible et touchable ;
##   4. on enjambe un mur bas avec « croix » (ici Espace), lentement, avec bruit ;
##   5. la torche d'un accroupi bute sur le mur ;
##   6. l'accroupi ralentit fortement, étouffe ses pas, se lit à sa silhouette et
##      à une marque HUD pour soi.
##
## ## Trois pistes, et un contrôle qui les départage au pixel
##
##   A — NATIF, occluders de posture : les murs bas sont des occluders sur leur
##       bit, que toutes les lumières activent. Ombre infinie.
##   B — POLYGONES FINIS : la zone morte de chaque mur bas, calculée depuis la
##       torche, posée comme occluder. On espère une ombre finie.
##   C — ANALYTIQUE : la zone morte calculée dans `light()` par le shader, depuis
##       la même formule que la balle (`murs_bas.gd`, `MursBas`).
##
## `V` rend une scène fixe et compare, point par point, ce que l'écran montre à
## ce que `franchit()` décide — la seule vérité, celle qui fait payer la balle.
## Une piste qui n'a qu'une vérité est une piste où les deux s'accordent partout.
##
## ⚠️ Aucun relevé de cadence de ce prototype n'est un relevé au protocole : pas
## de minute au premier plan, pas de machine refroidie. `M` donne un ORDRE DE
## GRANDEUR (appels de dessin, coût du shader), et dit dans quel état de focus
## il a été pris.

const Geo := preload("res://murs_bas.gd")
const Conditions := preload("res://conditions_de_match.gd")
const SHADER := preload("res://tools/proto_murs_bas.gdshader")

# ── Arène ───────────────────────────────────────────────────────────────────

const TUILE := Geo.TUILE
const TAILLE_ARENE := Vector2i(32, 18)
## Rectangles en TUILES, repère de l'arène (la ceinture est ajoutée à part).
const MURS_HAUTS_TUILES := [
	Rect2(14, 3, 2, 5),      # pilier central haut
	Rect2(22, 11, 5, 2),     # abri bas-droite
	Rect2(4, 12, 2, 3),      # abri bas-gauche
]
const MURS_BAS_TUILES := [
	Rect2(5, 6, 6, 1),       # long mur bas horizontal
	Rect2(20, 3, 1, 5),      # mur bas vertical
	Rect2(11, 13, 4, 1),     # muret près de l'abri
]

# ── Canaux (propres au prototype, voir docs/MURS_BAS.md § 3 pour le jeu) ───

const BIT_DECOR := 1
const BIT_CORPS := 2
## Occluders des murs bas « pleins » : ceux qu'une lumière ACCROUPIE voit.
const BIT_MUR_BAS := 64
## Piste B : les polygones de zone morte de profondeur finie.
const BIT_ZONE_FINIE := 128

enum Piste { A_NATIF, B_POLYGONES, C_ANALYTIQUE }
const NOMS_PISTE := ["A natif (occluders de posture)", "B polygones finis", "C analytique (light())"]
const LETTRES_PISTE := ["A", "B", "C"]

# ── Corps ────────────────────────────────────────────────────────────────────

## `player.gd` : `@export var speed: float = 260.0`. Recopié et relié par
## `tools/test_murs_bas.gd`, qui relit le texte de `player.gd`.
const VITESSE_DEBOUT := 260.0
const RAYON_DEBOUT := 18.0
## Silhouette ramassée : plus petite et plus ronde (voir `_silhouette`).
const RAYON_ACCROUPI := 13.0
const FACTEUR_ENJAMBEMENT := 0.25
const PORTEE_TORCHE := 330.0
## `MapGeometry.OCCLUDER_INSET`, recopié et relié par la suite.
const RETRAIT_OCCLUDER := 3.0
const PORTEE_TIR := 1400.0

## Proposition de dosage des pas (MB2 le fixera au banc audio) : décibels et
## portée relative, par état. Le jeu marche à −13 dB / 0,60 (séance du
## 2026-08-26).
const PAS := {
	"debout": [-13.0, 0.60],
	"accroupi": [-22.0, 0.30],
	"enjambement": [-4.0, 0.80],
}

enum Role { PORTEUR, DEBOUT, ACCROUPI }
const NOMS_ROLE := ["Porteur de torche", "Cible debout", "Cible accroupie"]

# ── Réglages à chaud ─────────────────────────────────────────────────────────

var h_bas := Geo.HAUTEUR_MUR_BAS          # tuiles
var h_accroupi := Geo.HAUTEUR_ACCROUPI    # tuiles
var angle := Geo.ANGLE_FRANCHISSEMENT     # degrés
## Fixée par Adrien à H-MB0 (2026-09-14) : ×0,25, soit 65 px/s. Proposée à ×0,45.
var facteur_accroupi := 0.25

const PAS_HAUTEUR := 0.05
const PAS_ANGLE := 0.5
const PAS_FACTEUR := 0.05

var piste: int = Piste.C_ANALYTIQUE

# ── État ─────────────────────────────────────────────────────────────────────

var _monde: Node2D
var _sol: Polygon2D
var _murs_hauts: Array = []   # Rect2, pixels de monde
var _murs_bas: Array = []     # Rect2, pixels de monde (dont piliers de mesure)
var _nb_murs_bas_arene := 0
var _noeuds_murs_bas: Array = []
var _occluders_finis: Node2D

var _acteurs: Array = []      # Dictionary par rôle
var _selection: int = Role.PORTEUR
var _torche: PointLight2D
var _flash: PointLight2D
var _trace: Line2D
var _flash_reste := 0.0
var _trace_reste := 0.0
var _visee := Vector2.ZERO

var _hud_couche: CanvasLayer
var _hud: Label
var _marque: Label
var _guide := false
var _dessin_guide: Node2D
var _occupe := false          # un contrôle tourne : les entrées sont ignorées
var _dossier_captures := ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	var args := OS.get_cmdline_user_args()
	var i := args.find("--piste")
	if i >= 0 and i + 1 < args.size():
		piste = maxi(0, LETTRES_PISTE.find(args[i + 1].to_upper()))
	i = args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_dossier_captures = args[i + 1]
		DirAccess.make_dir_recursive_absolute(_dossier_captures)

	_construire()
	_appliquer_piste()
	_imprimer_reglages("depart")
	print("PROTO_MURS_BAS piste=%s fenetre=%s rendu=%s" % [LETTRES_PISTE[piste],
		DisplayServer.window_get_size(), get_viewport().get_texture().get_size()])
	if args.has("--auto"):
		_auto.call_deferred()


# ═════════════════════════════════════════════════════════════════════════════
# CONSTRUCTION
# ═════════════════════════════════════════════════════════════════════════════

## L'arène est un Node2D mis à l'échelle pour remplir l'écran de base (1920×1080).
func _construire() -> void:
	var fond := CanvasModulate.new()
	fond.color = Color.BLACK   # le noir absolu : rien n'existe hors lumière
	add_child(fond)

	_monde = Node2D.new()
	_monde.name = "Monde"
	var taille := Vector2(TAILLE_ARENE) * TUILE
	var echelle := minf(1800.0 / (taille.x + 2 * TUILE), 1000.0 / (taille.y + 2 * TUILE))
	_monde.scale = Vector2.ONE * echelle
	_monde.position = (Vector2(1920, 1080) - (taille + Vector2.ONE * 2 * TUILE) * echelle) * 0.5 \
		+ Vector2.ONE * TUILE * echelle
	add_child(_monde)

	_sol = Polygon2D.new()
	_sol.name = "Sol"
	_sol.polygon = _rect_poly(Rect2(Vector2.ZERO, taille))
	_sol.material = _materiau(Vector3(0.30, 0.30, 0.32), 0)
	_sol.light_mask = BIT_DECOR
	_monde.add_child(_sol)

	# Ceinture : quatre murs hauts autour de l'arène.
	var ceinture := [
		Rect2(-TUILE, -TUILE, taille.x + 2 * TUILE, TUILE),
		Rect2(-TUILE, taille.y, taille.x + 2 * TUILE, TUILE),
		Rect2(-TUILE, 0, TUILE, taille.y),
		Rect2(taille.x, 0, TUILE, taille.y),
	]
	for r: Rect2 in ceinture:
		_ajouter_mur_haut(r)
	for r: Rect2 in MURS_HAUTS_TUILES:
		_ajouter_mur_haut(_tuiles(r))
	for r: Rect2 in MURS_BAS_TUILES:
		_ajouter_mur_bas(_tuiles(r))
	_nb_murs_bas_arene = _murs_bas.size()

	_occluders_finis = Node2D.new()
	_occluders_finis.name = "OccludersFinis"
	_monde.add_child(_occluders_finis)

	_acteurs = [
		_creer_acteur(Role.PORTEUR, _tuiles_pt(Vector2(8, 3)), false),
		_creer_acteur(Role.DEBOUT, _tuiles_pt(Vector2(7, 9)), false),
		_creer_acteur(Role.ACCROUPI, _tuiles_pt(Vector2(9.5, 7.8)), true),
	]

	_torche = _lumiere("Torche", PORTEE_TORCHE, 1.6)
	_acteurs[Role.PORTEUR]["noeud"].add_child(_torche)
	_flash = _lumiere("Flash", 260.0, 2.5)
	_flash.enabled = false
	_acteurs[Role.PORTEUR]["noeud"].add_child(_flash)

	_trace = Line2D.new()
	_trace.width = 2.0
	_trace.default_color = Color(1.0, 0.85, 0.5, 0.9)
	var additif := CanvasItemMaterial.new()
	additif.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additif.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trace.material = additif
	_trace.visible = false
	_monde.add_child(_trace)

	_dessin_guide = Node2D.new()
	_dessin_guide.material = additif
	_dessin_guide.draw.connect(_dessiner_guide)
	_dessin_guide.visible = false
	_monde.add_child(_dessin_guide)

	_hud_couche = CanvasLayer.new()
	add_child(_hud_couche)
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_font_size_override("font_size", 17)
	_hud.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_hud_couche.add_child(_hud)
	_marque = Label.new()
	_marque.add_theme_font_size_override("font_size", 30)
	_marque.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	_marque.position = Vector2(1640, 990)
	_marque.text = "▼ ACCROUPI"
	_hud_couche.add_child(_marque)


func _ajouter_mur_haut(r: Rect2) -> void:
	_murs_hauts.append(r)
	var poly := Polygon2D.new()
	poly.polygon = _rect_poly(r)
	poly.material = _materiau(Vector3(0.62, 0.60, 0.56), 0, false)
	poly.light_mask = BIT_DECOR
	_monde.add_child(poly)
	var occ := LightOccluder2D.new()
	occ.occluder = _occluder(r)
	occ.occluder_light_mask = BIT_DECOR
	_monde.add_child(occ)


func _ajouter_mur_bas(r: Rect2) -> void:
	_murs_bas.append(r)
	var poly := Polygon2D.new()
	poly.polygon = _rect_poly(r)
	# Le dessus d'un mur bas : hachuré et plus sombre qu'un mur haut. Invisible
	# dans le noir comme lui — c'est un matériau éclairé, rien de plus.
	poly.material = _materiau(Vector3(0.50, 0.46, 0.40), 1, false)
	poly.light_mask = BIT_DECOR
	_monde.add_child(poly)
	var occ := LightOccluder2D.new()
	occ.occluder = _occluder(r)
	occ.occluder_light_mask = BIT_MUR_BAS
	_monde.add_child(occ)
	_noeuds_murs_bas.append([poly, occ])


func _retirer_piliers() -> void:
	while _murs_bas.size() > _nb_murs_bas_arene:
		_murs_bas.pop_back()
		var paire: Array = _noeuds_murs_bas.pop_back()
		for n: Node in paire:
			n.queue_free()


## Piliers bas de 1×1 tuile pour la mesure du coût, posés sur une grille dans le
## quart haut-gauche (hors des scènes du contrôle d'accord).
func _poser_piliers(nb: int) -> void:
	_retirer_piliers()
	for k in nb:
		var cx := 1.0 + float(k % 6) * 1.5
		var cy := 1.0 + float(k / 6) * 1.0
		_ajouter_mur_bas(_tuiles(Rect2(cx, cy * 0.5 + 0.2, 0.6, 0.35)))


func _creer_acteur(role: int, pos: Vector2, accroupi: bool) -> Dictionary:
	var n := Node2D.new()
	n.name = NOMS_ROLE[role].replace(" ", "")
	n.position = pos
	var corps := Polygon2D.new()
	corps.name = "Corps"
	corps.light_mask = BIT_DECOR | BIT_CORPS
	n.add_child(corps)
	_monde.add_child(n)
	var a := {"role": role, "noeud": n, "corps": corps, "accroupi": accroupi,
		"enjambe": false, "bruit_emis": false}
	_accorder_silhouette(a)
	return a


## Debout : un disque et un nez. Accroupi : plus petit, plus rond, sans nez —
## la silhouette « basse et ramassée » d'Adrien.
func _accorder_silhouette(a: Dictionary) -> void:
	var corps: Polygon2D = a["corps"]
	var rayon := RAYON_ACCROUPI if a["accroupi"] else RAYON_DEBOUT
	var pts := PackedVector2Array()
	for k in 20:
		var ang := TAU * k / 20.0
		var r := rayon
		if not a["accroupi"] and absf(wrapf(ang, -PI, PI)) < 0.35:
			r = rayon * 1.35
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	corps.polygon = pts
	corps.material = _materiau(Vector3(0.92, 0.9, 0.85), 0, a["accroupi"], true)


func _lumiere(nom: String, portee: float, energie: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.name = nom
	l.texture = _texture_disque()
	l.texture_scale = portee * 2.0 / 256.0
	l.energy = energie
	l.color = Color(1.0, 0.93, 0.8)
	l.shadow_enabled = true
	l.shadow_filter = Light2D.SHADOW_FILTER_NONE
	l.range_item_cull_mask = BIT_DECOR | BIT_CORPS
	return l


## Un disque plat à 85 % puis un fondu : le contrôle d'accord ne lit que
## l'intérieur plat, sans dépendre d'une courbe d'atténuation.
static func _texture_disque() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.85, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func _materiau(albedo: Vector3, motif: int, recoit_zone := true, au_centre := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("motif", motif)
	m.set_shader_parameter("actif", recoit_zone)
	m.set_shader_parameter("au_centre", au_centre)
	return m


# ═════════════════════════════════════════════════════════════════════════════
# PISTES — qui fait de l'ombre à qui
# ═════════════════════════════════════════════════════════════════════════════

## Pose les masques de la piste courante. Pur, pour la suite : voir
## `masques_de_piste()`.
func _appliquer_piste() -> void:
	var porteur_accroupi: bool = _acteurs[Role.PORTEUR]["accroupi"]
	var m := masques_de_piste(piste, porteur_accroupi)
	for l: PointLight2D in [_torche, _flash]:
		l.shadow_item_cull_mask = m["ombre_lumiere"]
	for a: Dictionary in _acteurs:
		var corps: Polygon2D = a["corps"]
		corps.light_mask = m["corps_accroupi"] if a["accroupi"] else m["corps_debout"]
	_occluders_finis.visible = piste == Piste.B_POLYGONES
	if piste != Piste.B_POLYGONES:
		for c in _occluders_finis.get_children():
			c.queue_free()


## Les masques d'une piste — sans nœud, pour que la suite headless les vérifie.
##
##   ombre_lumiere  : `shadow_item_cull_mask` de la torche et du flash ;
##   corps_debout / corps_accroupi : `light_mask` des corps selon la posture ;
##   shader         : la zone morte analytique est-elle calculée ?
static func masques_de_piste(p: int, porteur_accroupi: bool) -> Dictionary:
	match p:
		Piste.A_NATIF:
			# Tout ou rien : les murs bas ombrent tout ce qui reçoit l'ombre. Pour
			# qu'une tête debout reste visible, le corps debout ne doit PAS
			# recevoir d'ombre… de rien, murs hauts compris (Pièges connus,
			# « shadow_item_cull_mask filtre AUSSI les sprites »).
			return {"ombre_lumiere": BIT_DECOR | BIT_MUR_BAS,
				"corps_debout": BIT_CORPS, "corps_accroupi": BIT_DECOR | BIT_CORPS,
				"shader": false}
		Piste.B_POLYGONES:
			var ombre := BIT_DECOR | (BIT_MUR_BAS if porteur_accroupi else BIT_ZONE_FINIE)
			return {"ombre_lumiere": ombre,
				"corps_debout": BIT_CORPS, "corps_accroupi": BIT_DECOR | BIT_CORPS,
				"shader": false}
		_:
			# C : les murs hauts par occluders, les murs bas par le shader ; une
			# lumière accroupie active en plus les occluders pleins des murs bas.
			var ombre_c := BIT_DECOR | (BIT_MUR_BAS if porteur_accroupi else 0)
			return {"ombre_lumiere": ombre_c,
				"corps_debout": BIT_DECOR | BIT_CORPS, "corps_accroupi": BIT_DECOR | BIT_CORPS,
				"shader": true}


# ═════════════════════════════════════════════════════════════════════════════
# CHAQUE IMAGE
# ═════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _occupe:
		_deplacer(delta)
		_visee = _monde.get_local_mouse_position()
		var porteur: Node2D = _acteurs[Role.PORTEUR]["noeud"]
		porteur.rotation = (_visee - porteur.position).angle()
	_flash_reste -= delta
	_flash.enabled = _flash_reste > 0.0
	_trace_reste -= delta
	_trace.visible = _trace_reste > 0.0
	_pousser_uniformes()
	if piste == Piste.B_POLYGONES:
		_reconstruire_zones_finies()
	_maj_hud()
	if _guide:
		_dessin_guide.queue_redraw()


## Convertit murs et zones mortes en espace écran pour le shader.
func _pousser_uniformes() -> void:
	var xf := get_viewport().get_final_transform() * _monde.get_global_transform_with_canvas()
	var echelle := xf.get_scale().x
	var murs := PackedVector4Array()
	# Rentrés comme leurs occluders : pour la LUMIÈRE, un mur bas a une seule
	# forme, que la torche soit haute (shader) ou basse (occluder plein). Troisième
	# passage de l'accord : avec les rectangles pleins ici, 2 points rasant un bout
	# de mur sous une torche accroupie étaient noircis par le shader, pas par
	# l'occluder.
	for r: Rect2 in _rentres(_murs_bas):
		var a := xf * r.position
		var b := xf * r.end
		murs.append(Vector4(minf(a.x, b.x), minf(a.y, b.y), maxf(a.x, b.x), maxf(a.y, b.y)))
	var tableau := murs.duplicate()
	tableau.resize(64)
	var shader_actif := piste == Piste.C_ANALYTIQUE
	var l_sol := Geo.longueur_zone_morte(Geo.en_pixels(h_bas), 0.0, angle) * echelle
	var l_acc := Geo.longueur_zone_morte(Geo.en_pixels(h_bas), Geo.en_pixels(h_accroupi), angle) * echelle
	var materiaux: Array = [[_sol.material, l_sol, Vector2.ZERO, false]]
	for a: Dictionary in _acteurs:
		var zone := l_acc if a["accroupi"] else 0.0
		materiaux.append([a["corps"].material, zone, xf * (a["noeud"] as Node2D).position, true])
	for entree: Array in materiaux:
		var m: ShaderMaterial = entree[0]
		m.set_shader_parameter("nb_murs", mini(murs.size(), 64))
		m.set_shader_parameter("murs", tableau)
		m.set_shader_parameter("zone_morte", entree[1] if shader_actif else 0.0)
		m.set_shader_parameter("centre", entree[2])
		m.set_shader_parameter("au_centre", entree[3])


## Piste B : un polygone par mur bas, depuis la torche, de profondeur L_sol.
## Ce qu'on attend de lui : une ombre finie. Ce qu'un occluder fait : infinie.
func _reconstruire_zones_finies() -> void:
	var source: Vector2 = (_acteurs[Role.PORTEUR]["noeud"] as Node2D).position
	var l_sol := Geo.longueur_zone_morte(Geo.en_pixels(h_bas), 0.0, angle)
	var enfants := _occluders_finis.get_children()
	for k in _murs_bas.size():
		var poly := polygone_zone_finie(source, _murs_bas[k], l_sol)
		var occ: LightOccluder2D
		if k < enfants.size():
			occ = enfants[k]
		else:
			occ = LightOccluder2D.new()
			occ.occluder = OccluderPolygon2D.new()
			occ.occluder_light_mask = BIT_ZONE_FINIE
			_occluders_finis.add_child(occ)
		(occ.occluder as OccluderPolygon2D).polygon = poly
	for k in range(_murs_bas.size(), enfants.size()):
		enfants[k].queue_free()


## Enveloppe convexe du mur et de son image poussée de `profondeur` le long des
## rayons issus de la source. Statique, pour la suite.
static func polygone_zone_finie(source: Vector2, r: Rect2, profondeur: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		pts.append(c)
		pts.append(c + (c - source).normalized() * profondeur)
	return Geometry2D.convex_hull(pts)


# ═════════════════════════════════════════════════════════════════════════════
# DÉPLACEMENT, ENJAMBEMENT, TIR
# ═════════════════════════════════════════════════════════════════════════════

func _deplacer(delta: float) -> void:
	var dir := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var a: Dictionary = _acteurs[_selection]
	var noeud: Node2D = a["noeud"]
	var enjamber := Input.is_physical_key_pressed(KEY_SPACE)
	var res := pas_de_marche(noeud.position, dir, delta, a["accroupi"], enjamber,
		_murs_hauts, _murs_bas, facteur_accroupi)
	noeud.position = res["position"]
	if res["enjambe"] and not a["enjambe"]:
		# L'accroupi se relève pour enjamber : il est debout, et il s'entend.
		if a["accroupi"]:
			a["accroupi"] = false
			_accorder_silhouette(a)
			_appliquer_piste()
		print("BRUIT enjambement role=%s niveau=%.0f dB portee=%.2f" % [NOMS_ROLE[a["role"]],
			PAS["enjambement"][0], PAS["enjambement"][1]])
	a["enjambe"] = res["enjambe"]


## Un pas de marche, pur : collisions cercle/rectangles, enjambement.
##
## Un mur haut bloque toujours. Un mur bas bloque, sauf si `enjamber` est tenu :
## le corps le traverse alors à `FACTEUR_ENJAMBEMENT` de la vitesse debout, et
## `enjambe` reste vrai tant qu'il le chevauche. Déplacement axe par axe.
static func pas_de_marche(pos: Vector2, dir: Vector2, delta: float, accroupi: bool,
		enjamber: bool, murs_hauts: Array, murs_bas: Array, facteur_acc: float) -> Dictionary:
	var rayon := RAYON_ACCROUPI if accroupi else RAYON_DEBOUT
	var sur_mur_bas := _chevauche(pos, rayon, murs_bas)
	var vitesse := VITESSE_DEBOUT * (facteur_acc if accroupi else 1.0)
	if sur_mur_bas or (enjamber and dir != Vector2.ZERO and
			_chevauche(pos + dir.normalized() * (rayon * 0.5), rayon, murs_bas)):
		vitesse = VITESSE_DEBOUT * FACTEUR_ENJAMBEMENT
	var pas := dir.normalized() * vitesse * delta if dir != Vector2.ZERO else Vector2.ZERO
	var p := pos
	for axe in 2:
		var essai := p
		essai[axe] += pas[axe]
		if _chevauche(essai, rayon, murs_hauts):
			continue
		if _chevauche(essai, rayon, murs_bas) and not enjamber and not _chevauche(p, rayon, murs_bas):
			continue
		p = essai
	return {"position": p, "enjambe": _chevauche(p, rayon, murs_bas), "vitesse": vitesse}


static func _chevauche(c: Vector2, rayon: float, rects: Array) -> bool:
	for r: Rect2 in rects:
		var proche := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		if proche.distance_squared_to(c) < rayon * rayon:
			return true
	return false


func _tirer() -> void:
	var porteur: Dictionary = _acteurs[Role.PORTEUR]
	if porteur["enjambe"]:
		print("TIR refuse : on ne tire pas en enjambant (proposition MB0)")
		return
	var src: Vector2 = (porteur["noeud"] as Node2D).position
	var cibles := []
	for a: Dictionary in _acteurs:
		if a["role"] == Role.PORTEUR:
			continue
		cibles.append({"nom": NOMS_ROLE[a["role"]], "centre": (a["noeud"] as Node2D).position,
			"rayon": RAYON_ACCROUPI if a["accroupi"] else RAYON_DEBOUT,
			"hauteur": Geo.en_pixels(h_accroupi if a["accroupi"] else Geo.HAUTEUR_DEBOUT)})
	var h_src := Geo.en_pixels(h_accroupi if porteur["accroupi"] else Geo.HAUTEUR_DEBOUT)
	var res := resoudre_tir(src, (_visee - src).normalized(), h_src, cibles, _murs_hauts,
		_murs_bas, Geo.en_pixels(h_bas), angle)
	_trace.points = PackedVector2Array([src, res["point"]])
	_trace_reste = 0.15
	_flash_reste = 0.08
	print("TIR piste=%s tireur=%s -> %s" % [LETTRES_PISTE[piste],
		"accroupi" if porteur["accroupi"] else "debout", res["texte"]])


## La balle, pure : même `franchit()` que la lumière. Parcourt les cibles et les
## murs le long du rayon, rend le premier arrêt. Une cible dans la zone morte
## n'arrête pas la balle : elle passe au-dessus.
static func resoudre_tir(src: Vector2, dir: Vector2, h_src: float, cibles: Array,
		murs_hauts: Array, murs_bas: Array, h_mur: float, angle_deg: float) -> Dictionary:
	var fin := src + dir * PORTEE_TIR
	var arret := PORTEE_TIR
	var texte := "rien touche"
	for r: Rect2 in murs_hauts:
		var d := _entree_rect(src, fin, r)
		if d >= 0.0 and d < arret:
			arret = d
			texte = "mur haut a %.0f px" % d
	if h_src <= h_mur:
		for r: Rect2 in murs_bas:
			var d := _entree_rect(src, fin, r)
			if d >= 0.0 and d < arret:
				arret = d
				texte = "mur bas a %.0f px (canon accroupi, sous le mur)" % d
	var passes := []
	var touche := ""
	for c: Dictionary in cibles:
		var d := _entree_cercle(src, dir, c["centre"], c["rayon"])
		if d < 0.0 or d >= arret:
			continue
		if Geo.franchit(src, c["centre"], h_src, c["hauteur"], murs_bas, h_mur, angle_deg):
			arret = d
			touche = c["nom"]
			texte = "TOUCHE %s a %.0f px" % [c["nom"], d]
		else:
			passes.append(c["nom"])
	for nom in passes:
		if nom != touche:
			texte += " | passe au-dessus de %s (zone morte)" % nom
	return {"point": src + dir * arret, "distance": arret, "touche": touche,
		"passe_au_dessus": passes, "texte": texte}


static func _entree_rect(a: Vector2, b: Vector2, r: Rect2) -> float:
	var d := b - a
	var te := 0.0
	var ts := 1.0
	for axe in 2:
		var o: float = a[axe]
		var v: float = d[axe]
		if absf(v) < 1e-9:
			if o < r.position[axe] or o > r.end[axe]:
				return -1.0
			continue
		var t1: float = (r.position[axe] - o) / v
		var t2: float = (r.end[axe] - o) / v
		te = maxf(te, minf(t1, t2))
		ts = minf(ts, maxf(t1, t2))
		if te > ts:
			return -1.0
	return te * d.length()


static func _entree_cercle(o: Vector2, dir: Vector2, c: Vector2, r: float) -> float:
	var m := o - c
	var b := m.dot(dir)
	var cc := m.dot(m) - r * r
	var disc := b * b - cc
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return t if t >= 0.0 else (0.0 if cc <= 0.0 else -1.0)


# ═════════════════════════════════════════════════════════════════════════════
# ENTRÉES
# ═════════════════════════════════════════════════════════════════════════════

func _unhandled_input(evt: InputEvent) -> void:
	if _occupe:
		return
	if evt is InputEventMouseButton and evt.pressed:
		if evt.button_index == MOUSE_BUTTON_LEFT:
			_tirer()
		elif evt.button_index == MOUSE_BUTTON_RIGHT:
			(_acteurs[_selection]["noeud"] as Node2D).position = _monde.get_local_mouse_position()
		return
	if not (evt is InputEventKey and evt.pressed and not evt.echo):
		return
	match (evt as InputEventKey).physical_keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_TAB:
			_selection = (_selection + 1) % _acteurs.size()
		KEY_C:
			var a: Dictionary = _acteurs[_selection]
			if not a["enjambe"]:
				a["accroupi"] = not a["accroupi"]
				_accorder_silhouette(a)
				_appliquer_piste()
				print("POSTURE %s -> %s" % [NOMS_ROLE[a["role"]], "accroupi" if a["accroupi"] else "debout"])
		KEY_F:
			_torche.enabled = not _torche.enabled
		KEY_P:
			piste = (piste + 1) % 3
			_appliquer_piste()
			print("PISTE %s — %s" % [LETTRES_PISTE[piste], NOMS_PISTE[piste]])
		KEY_G:
			_guide = not _guide
			_dessin_guide.visible = _guide
		KEY_H:
			_hud_couche.visible = not _hud_couche.visible
		KEY_1: _regler("h_bas", -PAS_HAUTEUR)
		KEY_2: _regler("h_bas", PAS_HAUTEUR)
		KEY_3: _regler("h_accroupi", -PAS_HAUTEUR)
		KEY_4: _regler("h_accroupi", PAS_HAUTEUR)
		KEY_5: _regler("angle", -PAS_ANGLE)
		KEY_6: _regler("angle", PAS_ANGLE)
		KEY_7: _regler("facteur_accroupi", -PAS_FACTEUR)
		KEY_8: _regler("facteur_accroupi", PAS_FACTEUR)
		KEY_N:
			_controle_noir()
		KEY_V:
			_controle_accord_toutes_pistes()
		KEY_M:
			_mesurer_cout()


func _regler(nom: String, pas: float) -> void:
	var r := regler(nom, pas, {"h_bas": h_bas, "h_accroupi": h_accroupi, "angle": angle,
		"facteur_accroupi": facteur_accroupi})
	h_bas = r["h_bas"]
	h_accroupi = r["h_accroupi"]
	angle = r["angle"]
	facteur_accroupi = r["facteur_accroupi"]
	_imprimer_reglages(nom)


## Les bornes des réglages, pures : un accroupi reste plus bas que le mur, un mur
## bas plus bas qu'une tête debout, l'angle dans ses bornes.
static func regler(nom: String, pas: float, v: Dictionary) -> Dictionary:
	var o := v.duplicate()
	match nom:
		"h_bas":
			o["h_bas"] = clampf(snappedf(v["h_bas"] + pas, 0.01), v["h_accroupi"] + 0.05, Geo.HAUTEUR_DEBOUT - 0.05)
		"h_accroupi":
			o["h_accroupi"] = clampf(snappedf(v["h_accroupi"] + pas, 0.01), 0.05, v["h_bas"] - 0.05)
		"angle":
			o["angle"] = clampf(snappedf(v["angle"] + pas, 0.01), Geo.ANGLE_MIN, Geo.ANGLE_MAX)
		"facteur_accroupi":
			o["facteur_accroupi"] = clampf(snappedf(v["facteur_accroupi"] + pas, 0.01), 0.1, 1.0)
	return o


func _imprimer_reglages(cause: String) -> void:
	var l_sol := Geo.longueur_zone_morte(h_bas, 0.0, angle)
	var l_acc := Geo.longueur_zone_morte(h_bas, h_accroupi, angle)
	print("REGLAGE %s h_bas=%.2f h_accroupi=%.2f h_debout=%.2f angle=%.1f° vitesse_accroupie=%.0f px/s (x%.2f) L_sol=%.2f tuiles (%.0f px) L_accroupi=%.2f tuiles (%.0f px)" % [
		cause, h_bas, h_accroupi, Geo.HAUTEUR_DEBOUT, angle, VITESSE_DEBOUT * facteur_accroupi,
		facteur_accroupi, l_sol, l_sol * TUILE, l_acc, l_acc * TUILE])


# ═════════════════════════════════════════════════════════════════════════════
# HUD ET GUIDE
# ═════════════════════════════════════════════════════════════════════════════

func _maj_hud() -> void:
	var a: Dictionary = _acteurs[_selection]
	var etat := "enjambement" if a["enjambe"] else ("accroupi" if a["accroupi"] else "debout")
	var l_sol := Geo.longueur_zone_morte(h_bas, 0.0, angle)
	var l_acc := Geo.longueur_zone_morte(h_bas, h_accroupi, angle)
	_hud.text = "\n".join([
		"MURS BAS — piste %s [P]  ·  contrôle : %s [Tab]  ·  %s" % [LETTRES_PISTE[piste], NOMS_ROLE[_selection], etat],
		"h_bas %.2f [1/2]   h_accroupi %.2f [3/4]   α %.1f° [5/6]   vitesse accroupie ×%.2f [7/8]" % [h_bas, h_accroupi, angle, facteur_accroupi],
		"zone morte : sol %.2f tuiles, accroupi %.2f tuiles   ·   pas %s : %.0f dB, portée %.2f" % [l_sol, l_acc, etat, PAS[etat][0], PAS[etat][1]],
		"ZQSD bouger · Espace tenu enjamber · C accroupi · clic gauche tir · clic droit poser · F torche · G guide · N noir · V accord · M coût · H HUD · Échap",
	])
	# « Une marque HUD pour soi » : celle de l'acteur qu'on contrôle, et lui seul.
	_marque.visible = a["accroupi"]


## Le guide dessine les zones mortes ATTENDUES (bords), en surimpression non
## éclairée. Il est éteint par défaut et coupé pendant tout contrôle.
func _dessiner_guide() -> void:
	var source: Vector2 = (_acteurs[Role.PORTEUR]["noeud"] as Node2D).position
	var l_sol := Geo.longueur_zone_morte(Geo.en_pixels(h_bas), 0.0, angle)
	var l_acc := Geo.longueur_zone_morte(Geo.en_pixels(h_bas), Geo.en_pixels(h_accroupi), angle)
	for k in 180:
		var dir := Vector2.from_angle(TAU * k / 180.0)
		for r: Rect2 in _murs_bas:
			var fin_sol := Geo.fin_de_zone_morte(source, dir, PORTEE_TORCHE, r, Geo.en_pixels(h_bas), 0.0, angle)
			if fin_sol > 0.0 and fin_sol < PORTEE_TORCHE:
				_dessin_guide.draw_circle(source + dir * fin_sol, 1.5, Color(0.3, 0.6, 1.0, 0.8))
			var fin_acc := fin_sol - l_sol + l_acc
			if fin_sol > 0.0 and fin_acc < PORTEE_TORCHE:
				_dessin_guide.draw_circle(source + dir * fin_acc, 1.5, Color(1.0, 0.5, 0.2, 0.8))


# ═════════════════════════════════════════════════════════════════════════════
# CONTRÔLES — noir absolu, accord rendu/vérité, coût
# ═════════════════════════════════════════════════════════════════════════════

func _auto() -> void:
	# macOS bride une fenêtre au second plan au point que `frame_post_draw` cesse
	# d'être émis (remède de `photographe.gd`) : en mode automatique seulement,
	# la fenêtre passe devant et y reste. Jamais en jeu libre, où elle gênerait.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	await _attendre_images(10)
	await _controle_noir()
	await _controle_accord_toutes_pistes()
	await _mesurer_cout()
	get_tree().quit()


func _attendre_images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


func _capture() -> Image:
	return get_viewport().get_texture().get_image()


func _sauver(img: Image, nom: String) -> void:
	if _dossier_captures == "":
		return
	img.save_png(_dossier_captures.path_join(nom + ".png"))


## Toutes lumières éteintes, HUD, guide et traçante coupés : l'image doit être à
## 0/255 partout. Un contour de mur bas ou une silhouette accroupie qui se voit
## ici est un échec.
func _controle_noir() -> void:
	_occupe = true
	var hud := _hud_couche.visible
	_hud_couche.visible = false
	_dessin_guide.visible = false
	_trace_reste = 0.0
	_flash_reste = 0.0
	var torche := _torche.enabled
	_torche.enabled = false
	# Un accroupi ET un debout en vue, contre un mur bas : ce qui doit rester noir.
	var resultats := []
	for p in 3:
		piste = p
		_appliquer_piste()
		await _attendre_images(3)
		var img := _capture()
		var maxi := valeur_maximale(img)
		_sauver(img, "noir_piste_%s" % LETTRES_PISTE[p])
		resultats.append(maxi)
		print("NOIR_ABSOLU piste=%s max=%d/255 image=%s %s" % [LETTRES_PISTE[p], maxi, img.get_size(),
			"OK" if maxi == 0 else "ECHEC"])
	piste = Piste.C_ANALYTIQUE
	_appliquer_piste()
	_torche.enabled = torche
	_hud_couche.visible = hud
	_dessin_guide.visible = _guide
	_occupe = false


## Valeur maximale sur R, G, B, en 0-255. Le cas attendu — tout à zéro — se
## tranche par une égalité d'octets native (quelques ms pour 11 millions
## d'octets) ; la boucle lente ne tourne que pour chiffrer un échec.
static func valeur_maximale(img: Image) -> int:
	var rgb := img.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var octets := rgb.get_data()
	var zeros := PackedByteArray()
	zeros.resize(octets.size())
	if octets == zeros:
		return 0
	var maxi := 0
	for o in octets:
		maxi = maxi if maxi >= o else o
	return maxi


## Les scènes fixes du contrôle d'accord : où est la torche, dans quelle posture,
## où sont les deux cibles. Pures, pour que la suite vérifie ce qu'elles
## prétendent mettre en scène (ex. « accroupi à L − 12 px derrière le mur »).
func scenes_d_accord() -> Array:
	var mur: Rect2 = _murs_bas[0]           # le long mur bas horizontal
	var haut: Rect2 = _murs_hauts[6]        # l'abri bas-gauche (après la ceinture)
	var l_acc := Geo.longueur_zone_morte(Geo.en_pixels(h_bas), Geo.en_pixels(h_accroupi), angle)
	var x := mur.get_center().x
	var torche_nord := Vector2(x, mur.position.y - 2.5 * TUILE)
	return [
		{"nom": "torche debout au nord, accroupi a L-12", "torche": torche_nord, "torche_accroupie": false,
			"debout": Vector2(x - 2.2 * TUILE, mur.end.y + 1.2 * TUILE),
			"accroupi": Vector2(x + 1.0, mur.end.y + l_acc - 12.0)},
		{"nom": "torche debout au nord, accroupi a L+12", "torche": torche_nord, "torche_accroupie": false,
			"debout": Vector2(x + 2.2 * TUILE, mur.end.y + 1.2 * TUILE),
			"accroupi": Vector2(x + 1.0, mur.end.y + l_acc + 12.0)},
		# Le debout DERRIÈRE UN MUR HAUT (l'abri bas-gauche) : une tête ne dépasse
		# pas un mur haut, et c'est ce que la piste A casse.
		{"nom": "torche du meme cote que l'accroupi", "torche": Vector2(x - 3.0 * TUILE, mur.end.y + 3.0 * TUILE),
			"torche_accroupie": false,
			"debout": Vector2(haut.get_center().x, haut.end.y + 1.3 * TUILE),
			"accroupi": Vector2(x + 1.0, mur.end.y + 0.8 * TUILE)},
		{"nom": "torche accroupie au nord (bute)", "torche": torche_nord, "torche_accroupie": true,
			"debout": Vector2(x - 2.2 * TUILE, mur.end.y + 1.2 * TUILE),
			"accroupi": Vector2(x + 1.0, mur.end.y + l_acc + 40.0)},
	]


func _controle_accord_toutes_pistes() -> void:
	for p in 3:
		await _controle_accord(p)
	piste = Piste.C_ANALYTIQUE
	_appliquer_piste()


## Une piste : pour chaque scène, lit l'écran et le compare à `visible()` —
## sur le sol (grille de points, en écartant ceux trop près d'une frontière de
## la vérité) et au centre des deux cibles.
func _controle_accord(p: int) -> void:
	_occupe = true
	var hud := _hud_couche.visible
	_hud_couche.visible = false
	_dessin_guide.visible = false
	_trace_reste = 0.0
	_flash_reste = 0.0
	var sauvegarde := []
	for a: Dictionary in _acteurs:
		sauvegarde.append([(a["noeud"] as Node2D).position, a["accroupi"]])
	var torche := _torche.enabled
	_torche.enabled = true
	piste = p

	var sol_ok := 0
	var sol_total := 0
	var ecartes := 0
	var corps_ok := 0
	var corps_total := 0
	var ecarts := []
	var h_mur := Geo.en_pixels(h_bas)
	for scene: Dictionary in scenes_d_accord():
		var porteur: Dictionary = _acteurs[Role.PORTEUR]
		(porteur["noeud"] as Node2D).position = scene["torche"]
		porteur["accroupi"] = scene["torche_accroupie"]
		var deb: Dictionary = _acteurs[Role.DEBOUT]
		(deb["noeud"] as Node2D).position = scene["debout"]
		deb["accroupi"] = false
		var acc: Dictionary = _acteurs[Role.ACCROUPI]
		(acc["noeud"] as Node2D).position = scene["accroupi"]
		acc["accroupi"] = true
		for a: Dictionary in _acteurs:
			_accorder_silhouette(a)
		# Le porteur est invisible au contrôle : son corps masquerait le sol.
		(porteur["corps"] as Polygon2D).visible = false
		_appliquer_piste()
		await _attendre_images(4)
		print("  accord piste=%s scene « %s » t=%d ms" % [LETTRES_PISTE[p], scene["nom"], Time.get_ticks_msec()])
		var img := _capture()
		_sauver(img, "accord_%s_%s" % [LETTRES_PISTE[p], (scene["nom"] as String).replace(" ", "_")])
		var xf := get_viewport().get_final_transform() * _monde.get_global_transform_with_canvas()
		var src: Vector2 = scene["torche"]
		var h_src := Geo.en_pixels(h_accroupi if scene["torche_accroupie"] else Geo.HAUTEUR_DEBOUT)

		# Le sol.
		var pas := 12.0
		var y := src.y - PORTEE_TORCHE
		while y <= src.y + PORTEE_TORCHE:
			var xx := src.x - PORTEE_TORCHE
			while xx <= src.x + PORTEE_TORCHE:
				var pt := Vector2(xx, y)
				xx += pas
				if pt.distance_to(src) > PORTEE_TORCHE * 0.8 or not Rect2(Vector2.ZERO, Vector2(TAILLE_ARENE) * TUILE).grow(-4).has_point(pt):
					continue
				if _pres_d_un_corps_ou_mur(pt, 8.0):
					continue
				var verite := _verite_sol(src, pt, h_src, h_mur)
				if not _verite_stable(src, pt, h_src, h_mur, verite, 6.0):
					ecartes += 1
					continue
				var lu := _allume(img, xf * pt)
				sol_total += 1
				if lu == verite:
					sol_ok += 1
				elif ecarts.size() < 6:
					ecarts.append("%s sol %s attendu=%s lu=%s" % [scene["nom"], pt.round(), verite, lu])
			y += pas

		# Les deux cibles, en leur centre.
		for cible: Dictionary in [deb, acc]:
			var centre: Vector2 = (cible["noeud"] as Node2D).position
			var h_c := Geo.en_pixels(h_accroupi if cible["accroupi"] else Geo.HAUTEUR_DEBOUT)
			var verite_c := centre.distance_to(src) < PORTEE_TORCHE * 0.8 \
				and Geo.visible(src, centre, h_src, h_c, _rentres(_murs_hauts), _rentres(_murs_bas), h_mur, angle)
			var lu_c := _allume(img, xf * centre)
			corps_total += 1
			if lu_c == verite_c:
				corps_ok += 1
			else:
				ecarts.append("%s %s attendu=%s lu=%s" % [scene["nom"],
					NOMS_ROLE[cible["role"]], verite_c, lu_c])
		(porteur["corps"] as Polygon2D).visible = true

	print("ACCORD piste=%s sol=%d/%d (%.1f %%) corps=%d/%d ecartes=%d %s" % [LETTRES_PISTE[p],
		sol_ok, sol_total, 100.0 * sol_ok / maxf(1, sol_total), corps_ok, corps_total, ecartes,
		"UNE_VERITE" if sol_ok == sol_total and corps_ok == corps_total else "DEUX_VERITES"])
	for e in ecarts:
		print("  ECART ", e)

	for k in _acteurs.size():
		var a: Dictionary = _acteurs[k]
		(a["noeud"] as Node2D).position = sauvegarde[k][0]
		a["accroupi"] = sauvegarde[k][1]
		_accorder_silhouette(a)
	_torche.enabled = torche
	_appliquer_piste()
	_hud_couche.visible = hud
	_dessin_guide.visible = _guide
	_occupe = false


## La vérité de la LUMIÈRE sur le sol. Les murs hauts s'y comptent rentrés de
## `RETRAIT_OCCLUDER` : c'est la forme que la carte d'ombre reçoit. La balle,
## elle, bute sur la tuile entière (la collision) — un écart de 3 px aux coins
## qui existe déjà dans le jeu (`MapGeometry.OCCLUDER_INSET`), pas introduit ici.
## Mesuré au premier passage : les 12 seuls écarts de la piste C étaient des
## rayons rasants à moins de 3 px d'un coin de mur haut.
##
## Même chose pour une source ACCROUPIE : ce qui l'arrête est l'occluder plein du
## mur bas, rentré lui aussi. Second passage : les 4 derniers écarts de C étaient
## des rayons de la torche accroupie rasant un bout de mur bas à moins de 3 px.
func _verite_sol(src: Vector2, pt: Vector2, h_src: float, h_mur: float) -> bool:
	return Geo.visible(src, pt, h_src, 0.0, _rentres(_murs_hauts), _rentres(_murs_bas), h_mur, angle)


static func _rentres(rects: Array) -> Array:
	var out := []
	for r: Rect2 in rects:
		out.append(r.grow(-RETRAIT_OCCLUDER))
	return out


## Un point dont la vérité change à `marge` px près est sur une frontière :
## l'ombre d'un occluder y a la résolution de sa carte d'ombre, pas celle de la
## formule. On l'écarte, et on le compte.
func _verite_stable(src: Vector2, pt: Vector2, h_src: float, h_mur: float, verite: bool, marge: float) -> bool:
	for d: Vector2 in [Vector2(marge, 0), Vector2(-marge, 0), Vector2(0, marge), Vector2(0, -marge)]:
		if _verite_sol(src, pt + d, h_src, h_mur) != verite:
			return false
	return true


func _pres_d_un_corps_ou_mur(pt: Vector2, marge: float) -> bool:
	for r: Rect2 in _murs_hauts + _murs_bas:
		if r.grow(marge).has_point(pt):
			return true
	for a: Dictionary in _acteurs:
		if a["role"] != Role.PORTEUR and pt.distance_to((a["noeud"] as Node2D).position) < RAYON_DEBOUT * 1.4 + marge:
			return true
	return false


static func _allume(img: Image, p: Vector2) -> bool:
	var x := clampi(int(p.x), 0, img.get_width() - 1)
	var y := clampi(int(p.y), 0, img.get_height() - 1)
	var c := img.get_pixel(x, y)
	return maxf(c.r, maxf(c.g, c.b)) > 10.0 / 255.0


## Le coût : appels de dessin et durée d'image avec 0, 12, 40 et 160 arêtes de
## murs bas (0, 3, 10, 40 rectangles), pistes A et C. Ordre de grandeur, pas
## relevé au protocole.
func _mesurer_cout() -> void:
	_occupe = true
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var torche := _torche.enabled
	_torche.enabled = true
	# Le plafond d'images (120 par défaut du jeu) cachait tout : 8,33 ms de médiane
	# dans les huit configurations au premier passage. Levé le temps de la mesure.
	var plafond := Engine.max_fps
	var vsync := DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("COUT focus=%s vsync=%d->0 max_fps=%d->0 fenetre=%s (ordre de grandeur, pas un releve au protocole)" % [
		"premier_plan" if get_window().has_focus() else "second_plan",
		vsync, plafond, DisplayServer.window_get_size()])
	for p: int in [Piste.A_NATIF, Piste.C_ANALYTIQUE]:
		piste = p
		for config: Array in [[0, true], [0, false], [7, false], [37, false]]:
			var extra: int = config[0]
			var sans_arene: bool = config[1]
			_poser_piliers(extra)
			var murs_sauves := []
			if sans_arene:
				for k in _nb_murs_bas_arene:
					murs_sauves.append(_murs_bas[k])
					(_noeuds_murs_bas[k][0] as Node).visible = false
					(_noeuds_murs_bas[k][1] as Node).visible = false
				_murs_bas = _murs_bas.slice(_nb_murs_bas_arene)
			_appliquer_piste()
			await _attendre_images(30)
			var durees := PackedFloat32Array()
			var appels := []
			var cpu := 0.0
			var gpu := 0.0
			var debut := Time.get_ticks_usec()
			for k in 240:
				await RenderingServer.frame_post_draw
				var maintenant := Time.get_ticks_usec()
				durees.append(float(maintenant - debut) / 1e6)
				debut = maintenant
				appels.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			appels.sort()
			var st := Conditions.statistiques(durees)
			print("COUT piste=%s aretes=%d rectangles=%d appels=%d image_mediane=%.2f ms 1pc_bas=%.1f fps rendu_cpu=%.3f ms rendu_gpu=%.3f ms" % [
				LETTRES_PISTE[p], _murs_bas.size() * 4, _murs_bas.size(), appels[appels.size() / 2],
				1000.0 / maxf(0.001, st["fps_median"]), st["fps_1pc_bas"], cpu / 240.0, gpu / 240.0])
			if sans_arene:
				_murs_bas = murs_sauves + _murs_bas
				for k in _nb_murs_bas_arene:
					(_noeuds_murs_bas[k][0] as Node).visible = true
					(_noeuds_murs_bas[k][1] as Node).visible = true
	_retirer_piliers()
	Engine.max_fps = plafond
	DisplayServer.window_set_vsync_mode(vsync)
	piste = Piste.C_ANALYTIQUE
	_appliquer_piste()
	_torche.enabled = torche
	_occupe = false


# ── utilitaires ─────────────────────────────────────────────────────────────

static func _tuiles(r: Rect2) -> Rect2:
	return Rect2(r.position * TUILE, r.size * TUILE)


static func _tuiles_pt(p: Vector2) -> Vector2:
	return p * TUILE


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Même retrait que `MapGeometry.OCCLUDER_INSET` : sans lui, un mur se tient dans
## sa propre ombre et sa face éclairée ne capte rien.
static func _occluder(r: Rect2) -> OccluderPolygon2D:
	var o := OccluderPolygon2D.new()
	o.polygon = _rect_poly(r.grow(-RETRAIT_OCCLUDER))
	return o
