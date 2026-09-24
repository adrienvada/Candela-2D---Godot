extends Node3D

## Le banc des CORPS VOXEL — chantier ISO, étape ISO3 (vague 0 : les dix corps
## et leurs mouvements ; vague 1 : accroupi et enjambement ; vague 4 : le
## réglage d'épaisseur, `--epaisseur=`).
##
## Dix corps sur une grille, une lumière SIMULÉE (pas une `Light3D` — voir plus
## bas), des touches pour déclencher marche, tir, touché, mort, accroupi,
## enjambement. C'est le seul endroit où l'on voit les dix classes ensemble
## avant qu'ISO2 ne pose de vrais capteurs.
##
## ## Pourquoi la lumière est simulée, et pas une vraie `Light3D`
##
## Cette étape ne pose aucun capteur (c'est ISO2) : `lumiere_recue` est un
## simple uniform que quelqu'un règle de l'extérieur. Ici, c'est le curseur du
## banc — `definir_lumiere()` sur chaque corps, directement, sans lumière
## traversant une scène. Le cône dessiné dans la scène est un REPÈRE VISUEL
## (où une torche pointerait), pas une source qui participerait au calcul :
## bouger le cône ne change rien à ce que les corps reçoivent. Une vraie
## `Light3D` ici referait exactement l'erreur qu'ISO0 a écartée (§ 5.3 de
## `docs/ETUDE_ISO.md`) — une deuxième vérité d'ombre, à côté de celle que la
## lightmap 2D décidera plus tard.
##
## ## Lancer
##
##   godot --path . tools/banc_corps.tscn
##   godot --path . tools/banc_corps.tscn -- --lumiere=0 --capture=/chemin/noir.png
##   godot --path . tools/banc_corps.tscn -- --classe=spectre --lumiere=0.8 --capture=/chemin/spectre.png
##   godot --path . tools/banc_corps.tscn -- --pose=accroupi --lumiere=0.8 --capture=/chemin/accroupi.png
##   godot --path . tools/banc_corps.tscn -- --pose=enjambe --lumiere=0.8 --capture=/chemin/enjambe.png
##   godot --path . tools/banc_corps.tscn -- --capteur --lumiere=0.8 --capture=/chemin/modele.png
##   godot --path . tools/banc_corps.tscn -- --opacite=0.5 --capture=/chemin/efface.png
##   godot --path . tools/banc_corps.tscn -- --silhouette --lumiere=0 --capture=/chemin/silhouette.png
##   godot --path . tools/banc_corps.tscn -- --epaisseur=leger --lumiere=0.8 --capture=/chemin/avant.png
##   godot --path . tools/banc_corps.tscn -- --epaisseur=x1_6 --lumiere=0.8 --capture=/chemin/apres.png
##   godot --path . tools/banc_corps.tscn -- --encre=0.03 --lumiere=0.8 --capture=/chemin/encre.png
##   godot --path . tools/banc_corps.tscn -- --modele --lumiere=0.8 --capture=/chemin/modele.png
##   godot --path . tools/banc_corps.tscn -- --corps=portraits --lumiere=0.8 --capture=/chemin/portraits.png
##
## `--epaisseur` (ISO3 vague 4) : `leger` (×1,0, l'ancien gabarit vague 0-3),
## `x1_3`, `x1_6` (le réglage par défaut si l'option est omise — voir
## `VoxelCatalogue.EPAISSEUR_PAR_DEFAUT`) ou `x2_0`.
##
## `--encre` (ISO3 vague 5, contrat d'ISO7 Beauté) : `definir_encre(X)` sur
## chaque corps, `X` en tuiles (0.0 par défaut — aucun effet, comme le shader).
##
## Sans `--capture`, la fenêtre reste ouverte et interactive. Comme
## `tools/proto_iso.gd`, la capture exige une vraie fenêtre (`RenduCommun`) et
## refuse en headless plutôt que d'y pendre.
##
## ## Le rapport
##
## Toujours : le nombre de boîtes par corps (neuf attendues, voir
## `tools/test_voxel_corps.gd`). Chaque fois que le rendu doit être noir
## (lumière nulle, capteur synthétique éteint, silhouette hors mode soi) ET
## `--capture` : la valeur maximale des pixels de l'image rendue — elle doit
## être exactement 0, et c'est un examen réel du rendu, pas une lecture
## d'uniform (voir la suite headless, qui elle ne peut que lire les nombres).

const VoxelCorpsT := preload("res://voxel_corps.gd")
const VoxelCatalogueT := preload("res://voxel_catalogue.gd")
const Charte := preload("res://charte.gd")

const COLONNES := 5
const ESPACEMENT_TUILES := 2.4
const VITESSE_MARCHE_PX := 220.0     # px/s — cohérent avec l'ordre de grandeur du jeu, sans le recopier
const VITESSE_MARCHE_ACCROUPI_PX := 55.0  # px/s — ordre de grandeur du ×0,25 du jeu (MB2), pas recopié
const DUREE_TIR := 0.12
const DUREE_TOUCHE := 0.5
const DUREE_ENJAMBE_BANC := 0.5      # « ton banc le simule sur une demi-seconde » (brief ISO3 vague 1)
const TAILLE_CAPTEUR := 256
# Le monde que le dégradé synthétique couvre, en pixels 2D, et jusqu'où on y
# lit — mêmes grandeurs que `CapteurCorps.MONDE_PX`/`RAYON_PX` (ISO2), pas
# recopiées : juste assez large pour qu'un corps (rayon 0,4 tuile ≈ 14 px)
# tienne dedans avec de la marge.
const MONDE_CAPTEUR_PX := 64.0
const RAYON_LU_PX := 20.0

var _capture := ""
var _classe_filtre := ""
var _pose_forcee := ""               # "" | "accroupi" | "enjambe" — --pose, pour la planche
var _epaisseur := VoxelCatalogueT.EPAISSEUR_PAR_DEFAUT  # ISO3 vague 4 — --epaisseur=leger|x1_3|x1_6|x2_0
var _lumiere := 0.6
var _taille := Vector2i(1920, 1080)
var _frames := 3
var _capteur_force := false          # --capteur : capteur synthétique dès le départ
var _opacite_force := -1.0           # --opacite=X : sinon 1.0
var _silhouette_force := false       # --silhouette : mode_silhouette=1 dès le départ
var _encre := 0.0                    # ISO3 vague 5 — --encre=X (tuiles) : définir_encre(X), sinon 0.0 (défaut)
## ISO7b (crochet d'ISO7 Beauté) — `--modele` : le modelé des corps par la caméra (dessus 1,15, face sud 0,9, autres
## faces 1), sans aucune lecture de la lumière — décision de la session cloud, 2026-09-15 14:21.
var _modele := false
## ISO12 — `--palette-grise` (avec `--corps=portraits`) : toutes les couleurs du portrait remplacées par le gris de la classe.
## Contrôle : la teinte rend alors exactement le gris, et tout écart entre les deux captures viendrait d'ailleurs.
var _palette_grise := false
## ISO12 — `--opaque` : les corps rendus par une copie OPAQUE de leur shader (ni `blend_mix` ni ALPHA : plus aucun mélange
## au bord), mêmes paramètres. Diagnostic de l'ordre 145 : désigne si le pourtour tient au mélange.
var _opaque := false
## ISO12 — le temps du banc FIGÉ pendant les captures (avec `--corps=portraits`) : les corps ne respirent plus entre la prise
## peinte et la prise au portrait éteint. Sans lui, 40 000 pixels différaient même au contrôle (palette grise, 2026-09-23 05:56),
## et le noir absolu ne se prouve pas au niveau de ce bruit. Aucun shader des corps ne lit TIME : figer `_temps` fige tout.
var _fige := false
## ISO13 — `--temps-fixe` : le temps posé à 0 et jamais avancé, pour que deux lancements (deux arbres) rendent la même pose et
## se comparent à l'octet. Le temps figé seul fige l'instant où il s'arrête, qui varie d'un lancement à l'autre.
var _temps_fixe := false
## ISO12, tenues sombres — `--toutes-tenues` (avec une tenue peinte) : après la prise de la tenue et sa prise grise, la même
## scène dans chacune des tenues sombres (`_sombre1.png`…), posées par uniformes sur les mêmes matériaux, au temps figé.
var _toutes_tenues := false
## ISO13 — `--directions-mannequin` (avec `--mannequin`) : après la prise principale, la même scène sans mannequin, puis avec
## la lumière venue d'aucun côté, du sud, du nord, de l'est et de l'ouest (`_mannequin_<côté>.png`), même partie, temps figé.
var _directions_mannequin := false
## ISO13, lot B — `--contours-essai` : la même scène sans contour, puis avec le contour de la silhouette à 1 px et à 2 px
## (`_contour_<px>.png`), même partie.
var _contours_essai := false
const DIRECTIONS_MANNEQUIN := [["sans", Vector2.ZERO], ["aucune", Vector2.ZERO], ["sud", Vector2(0, 1)], ["nord", Vector2(0, -1)],
	["est", Vector2(1, 0)], ["ouest", Vector2(-1, 0)]]

var _corps: Array = []     # [{ "slug": String, "noeud": VoxelCorps, "pos_px": Vector2, "centre_tuiles": Vector2 }]
var _temps := 0.0
var _marche := false
var _tir_t0 := -1.0
var _touche_t0 := -1.0
var _mort_t0 := -1.0
var _accroupi := false
var _accroupi_t0 := 0.0
var _enjambe_t0 := -1.0
var _capteur_actif := false
var _opacite := 1.0
var _mode_silhouette := 0
var _capteur_tex: ImageTexture

var _bandeau: Label
var _releve: Label
var _sol_mat: ShaderMaterial
var _couche_bandeau: CanvasLayer
var _cone_repere: MeshInstance3D


func _ready() -> void:
	_lire_arguments(OS.get_cmdline_user_args())
	_construire_scene()
	_imprimer_rapport_boites()
	if _capture != "":
		_capturer_puis_quitter()


func _lire_arguments(args: PackedStringArray) -> void:
	for a in args:
		if not a.begins_with("--"):
			continue
		var egal := a.find("=")
		var cle := a.substr(2, egal - 2) if egal >= 0 else a.substr(2)
		var val := a.substr(egal + 1) if egal >= 0 else ""
		match cle:
			"capture": _capture = val
			"classe": _classe_filtre = val
			"lumiere": _lumiere = clampf(float(val), 0.0, 1.0)
			"frames": _frames = maxi(1, int(val))
			"pose":
				if val == "accroupi" or val == "enjambe":
					_pose_forcee = val
				else:
					push_warning("banc_corps : --pose attend accroupi|enjambe (reçu « %s »)" % val)
			"taille":
				var parts := val.to_lower().split("x")
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					_taille = Vector2i(int(parts[0]), int(parts[1]))
				else:
					push_warning("banc_corps : --taille attend LxH (reçu « %s »)" % val)
			"capteur": _capteur_force = true
			"opacite": _opacite_force = clampf(float(val), 0.0, 1.0)
			"silhouette": _silhouette_force = true
			"epaisseur":
				if VoxelCatalogueT.EPAISSEUR_REGLAGES.has(val):
					_epaisseur = val
				else:
					push_warning("banc_corps : --epaisseur attend %s (reçu « %s »)"
						% [", ".join(VoxelCatalogueT.EPAISSEUR_REGLAGES.keys()), val])
			"encre": _encre = maxf(0.0, float(val))
			"modele": _modele = true
			# ISO12 — lu par `VoxelCatalogue.portraits_actifs()` : les corps d'après les dix portraits de classe.
			"palette-grise": _palette_grise = true
			"opaque": _opaque = true
			"corps":
				if val != "portraits" and val != "gris" and not VoxelCatalogueT.TENUES_SOMBRES.has(val if val != "sombre" else "sombre1"):
					push_warning("banc_corps : --corps attend gris, portraits, sombre, sombre2 ou sombre3 (reçu « %s »)" % val)
			"equite":
				# ISO13 — la calibration de l'équité de V3 : le même facteur pour toutes les classes (`VoxelCatalogue.V3_EQUITE`).
				VoxelCatalogueT.forcer_equite = maxf(0.0, float(val))
			"toutes-tenues": _toutes_tenues = true
			"temps-fixe": _temps_fixe = true
			"directions-mannequin": _directions_mannequin = true
			"contours-essai": _contours_essai = true
			"mannequin":
				pass  # lu par `VoxelCatalogue.mannequin_actif()`
			"teinte":
				# Lu par `VoxelCatalogue.teinte()` : la teinte des tenues sombres (`olive`, `froide`).
				if not VoxelCatalogueT.TEINTES.has(val):
					push_warning("banc_corps : --teinte attend %s (reçu « %s »)" % [", ".join(VoxelCatalogueT.TEINTES.keys()), val])
			"no-eos", "sans-maj", "eos-ephemeral":
				pass
			_:
				push_warning("banc_corps : argument inconnu --%s" % cle)


# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func _construire_scene() -> void:
	_construire_environnement()
	_construire_sol()
	_construire_cone_repere()

	var slugs: PackedStringArray = VoxelCatalogueT.slugs()
	if _classe_filtre != "":
		if not slugs.has(_classe_filtre):
			push_error("banc_corps : classe inconnue « %s » (connues : %s)"
				% [_classe_filtre, ", ".join(slugs)])
			slugs = PackedStringArray()
		else:
			slugs = PackedStringArray([_classe_filtre])

	var n := slugs.size()
	var colonnes := 1 if n == 1 else COLONNES
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	for i in n:
		var slug: String = slugs[i]
		var col := i % colonnes
		var ligne := i / colonnes
		var demi_largeur := float(colonnes - 1) * 0.5
		var demi_hauteur := float((n - 1) / colonnes) * 0.5
		var x_tuiles := (float(col) - demi_largeur) * ESPACEMENT_TUILES
		var z_tuiles := (float(ligne) - demi_hauteur) * ESPACEMENT_TUILES

		var noeud: Node3D = VoxelCorpsT.new()
		noeud.name = "Corps_%s" % slug
		add_child(noeud)
		if not noeud.construire(slug, _epaisseur):
			continue
		noeud.definir_lumiere(_lumiere)
		# Ce banc garde ses corps en tuiles (comme `voxel_corps.gd` partout
		# ailleurs) ; le capteur d'ISO2 raisonne en pixels 2D — voir
		# `pixels_par_unite` dans `corps_iso.gdshader`.
		noeud.definir_pixels_par_unite(tuile)
		if _encre > 0.0:
			noeud.definir_encre(_encre)
		if _modele:
			var m: ShaderMaterial = noeud.materiau()
			m.set_shader_parameter("modele", 1.0)
		if _opaque:
			var mo: ShaderMaterial = noeud.materiau()
			mo.shader = _shader_opaque(mo.shader)
		if _palette_grise:
			var mg: ShaderMaterial = noeud.materiau()
			var gris: Color = noeud.couleur()
			for cle in ["ocre", "rouille", "brun", "bouteille", "arme"]:
				mg.set_shader_parameter("portrait_%s" % cle, gris)
			mg.set_shader_parameter("portrait_cartouche", Color(0, 0, 0, 0))
			for cle in ["tete", "arete"]:
				if (mg.get_shader_parameter("portrait_%s" % cle) as Color).a > 0.0:
					mg.set_shader_parameter("portrait_%s" % cle, gris)
		_corps.append({
			"slug": slug, "noeud": noeud,
			"pos_px": Vector2(x_tuiles, z_tuiles) * tuile,
		})

	var lignes: int = (n + colonnes - 1) / colonnes if n > 0 else 1
	var largeur: float = float(maxi(colonnes - 1, 0)) * ESPACEMENT_TUILES + 2.0
	var profondeur: float = float(maxi(lignes - 1, 0)) * ESPACEMENT_TUILES + 2.0
	_construire_camera(largeur, profondeur)
	_construire_bandeau()

	_capteur_actif = _capteur_force
	if _opacite_force >= 0.0:
		_opacite = _opacite_force
	_mode_silhouette = 1 if _silhouette_force else 0
	if _capteur_actif:
		_regenerer_capteur()
	_rafraichir_poses()


func _construire_environnement() -> void:
	var monde := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	monde.environment = env
	add_child(monde)


## Un plan sombre, juste assez visible pour situer les pieds — jamais assez
## clair pour fausser le relevé « valeur maximale à lumière 0 » : sa propre
## teinte est nulle à `_lumiere == 0`, par la même formule que les corps.
## Toujours plus sombre que le gris le plus bas du catalogue (55 % du plafond,
## `VoxelCatalogue._facteur_gris`) : sans cette marge, l'Occulteur — le plus
## sombre des dix — se fond dans le sol au lieu de s'en détacher.
func _construire_sol() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ESPACEMENT_TUILES * (COLONNES + 1), ESPACEMENT_TUILES * 4.0)
	var inst := MeshInstance3D.new()
	inst.name = "Sol"
	inst.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://corps_iso.gdshader")
	mat.set_shader_parameter("couleur_fiche", Color(0.11, 0.115, 0.125))
	mat.set_shader_parameter("lumiere_recue", _lumiere)
	inst.material_override = mat
	add_child(inst)
	_sol_mat = mat


## Repère purement visuel — voir l'en-tête du fichier.
func _construire_cone_repere() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.35
	mesh.height = 1.4
	var inst := MeshInstance3D.new()
	inst.name = "ConeRepere"
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(Charte.AMBRE, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inst.material_override = mat
	inst.position = Vector3(-ESPACEMENT_TUILES * 2.4, 2.2, -1.2)
	inst.rotation_degrees = Vector3(-55.0, 20.0, 0.0)
	add_child(inst)
	_cone_repere = inst


## `size` est le DEMI-côté vertical en mode `KEEP_HEIGHT` (le défaut de
## `Camera3D`) : la largeur visible vaut `size * aspect`. La scène est large
## (cinq colonnes) et peu profonde (deux rangées) — c'est presque toujours la
## largeur qui commande, jamais la profondeur brute (le tangage la raccourcit
## encore par `sin(tangage)`).
func _construire_camera(largeur_tuiles: float, profondeur_tuiles: float) -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := float(_taille.x) / float(_taille.y)
	# 52°, pas le 58° d'origine (antérieur à H15) : c'est le tangage RÉELLEMENT
	# tranché par Adrien pour le jeu (ROADMAP, « H15 tranché ») — corrigé ici en
	# ISO3 vague 4, dont le brief cite explicitement « sous la lampe à 0,8, à
	# 52° » pour juger la planche avant/après (même correctif déjà fait pour
	# `banc_objets.gd` en vague 3, jamais reporté ici avant maintenant).
	var pitch := deg_to_rad(52.0)
	var depuis_largeur := largeur_tuiles / aspect
	var depuis_profondeur := profondeur_tuiles * sin(pitch) + 1.0
	cam.size = maxf(depuis_largeur, depuis_profondeur) * 1.1
	cam.near = 0.05
	cam.far = 100.0
	var recul := (largeur_tuiles + profondeur_tuiles) * 1.5
	cam.position = Vector3(0.0, sin(pitch) * recul, cos(pitch) * recul)
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.4, 0.0), Vector3.UP)
	cam.current = true


func _construire_bandeau() -> void:
	var couche := CanvasLayer.new()
	couche.name = "Bandeau"
	add_child(couche)
	_couche_bandeau = couche

	_bandeau = Label.new()
	_bandeau.position = Vector2(18, 14)
	_bandeau.add_theme_font_size_override("font_size", 13)
	_bandeau.add_theme_color_override("font_color", Charte.DIM)
	_bandeau.text = ("ESPACE marche   T tir   H touché   M mort   R reviens   "
		+ "A accroupi   E enjamber   C capteur   V silhouette de soi   "
		+ "[ / ] opacité ±0,1   HAUT/BAS lumière ±0,05   ÉCHAP quitter")
	couche.add_child(_bandeau)

	_releve = Label.new()
	_releve.position = Vector2(18, 38)
	_releve.add_theme_font_size_override("font_size", 14)
	_releve.add_theme_color_override("font_color", Charte.HALOGENE)
	couche.add_child(_releve)


# ---------------------------------------------------------------------------
# LE RAPPORT
# ---------------------------------------------------------------------------

## Un dégradé horizontal, 256² — un côté à `_lumiere`, l'autre à 0 : la lampe
## latérale du brief ISO3 vague 2. Chaque corps le lit à SA place (voir l'en-
## tête de `corps_iso.gdshader`), donc chacun, posé n'importe où sur la grille,
## montre le même modelé « côté lampe clair, dos sombre » que les autres — un
## seul dégradé suffit, il n'y a pas besoin d'un capteur par corps ici.
func _regenerer_capteur() -> void:
	var img := Image.create(TAILLE_CAPTEUR, TAILLE_CAPTEUR, false, Image.FORMAT_RGB8)
	for y in TAILLE_CAPTEUR:
		for x in TAILLE_CAPTEUR:
			var t := float(x) / float(TAILLE_CAPTEUR - 1)
			var v := _lumiere * (1.0 - t)
			img.set_pixel(x, y, Color(v, v, v))
	_capteur_tex = ImageTexture.create_from_image(img)


func _imprimer_rapport_boites() -> void:
	print("BANC_CORPS — boîtes par corps :")
	for c in _corps:
		var noeud: Node3D = c["noeud"]
		print("  %-12s %d boîtes" % [c["slug"], noeud.nombre_de_boites()])


# ---------------------------------------------------------------------------
# LA BOUCLE
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _fige and not _temps_fixe:
		_temps += delta

	if _tir_t0 >= 0.0 and _temps - _tir_t0 > DUREE_TIR:
		_tir_t0 = -1.0
	if _touche_t0 >= 0.0 and _temps - _touche_t0 > DUREE_TOUCHE:
		_touche_t0 = -1.0

	_rafraichir_poses()
	_rafraichir_releve()


## Voir l'en-tête « pourquoi `t` change de sens » dans `voxel_corps.gd` : hors
## d'un déclencheur transitoire, `t` est l'horloge continue du banc (la marche
## et la respiration en ont besoin) ; pendant un tir, un touché ou le passage
## à accroupi, `t` redevient le temps ÉCOULÉ DEPUIS LE DÉCLENCHEMENT, sans quoi
## l'enveloppe de recul, la secousse ou la bascule accroupie — calées sur une
## fenêtre de quelques centaines de ms — liraient un `t` déjà grand et
## resteraient à leur valeur de repos. `enjambe`, lui, n'a pas besoin de ce
## traitement : c'est l'appelant qui fournit directement la progression 0..1,
## voir l'en-tête de `voxel_corps.gd`.
func _rafraichir_poses() -> void:
	var tir := _tir_t0 >= 0.0
	var touche := _touche_t0 >= 0.0
	var mort := _mort_t0 >= 0.0

	var t := _temps
	if mort:
		t = _temps - _mort_t0
	elif tir or touche:
		var debut := _temps
		if tir:
			debut = minf(debut, _tir_t0)
		if touche:
			debut = minf(debut, _touche_t0)
		t = _temps - debut
	elif _accroupi:
		t = _temps - _accroupi_t0

	var enjambe := 0.0
	if _enjambe_t0 >= 0.0:
		var progres := (_temps - _enjambe_t0) / DUREE_ENJAMBE_BANC
		if progres >= 1.0:
			_enjambe_t0 = -1.0
		else:
			enjambe = progres

	# La vitesse suit la posture : ×0,25 accroupi, comme MB2 (grandeur du jeu,
	# jamais recopiée — voir la constante).
	var vitesse_base := VITESSE_MARCHE_ACCROUPI_PX if _accroupi else VITESSE_MARCHE_PX
	var vitesse := Vector2(vitesse_base, 0.0) if (_marche and not mort) else Vector2.ZERO

	var accroupi_effectif := _accroupi
	if _pose_forcee == "accroupi":
		accroupi_effectif = true
		t = 1.0  # bien au-delà de DUREE_TRANSITION_ACCROUPI : posture stabilisée
	elif _pose_forcee == "enjambe":
		enjambe = 0.5  # le milieu du geste — le plus lisible sur une planche figée

	for c in _corps:
		var noeud: Node3D = c["noeud"]
		noeud.poser({
			"position": c["pos_px"], "visee": Vector2(0.0, 1.0), "vitesse": vitesse,
			"torche": true, "arme": c["slug"], "tir": tir, "touche": touche,
			"mort": mort, "accroupi": accroupi_effectif, "enjambe": enjambe, "t": t,
		})
		if _capteur_actif and _capteur_tex != null:
			noeud.definir_capteur(_capteur_tex, c["pos_px"], MONDE_CAPTEUR_PX, RAYON_LU_PX)
		else:
			noeud.effacer_capteur()
		noeud.definir_opacite(_opacite)
		if _mode_silhouette == 1:
			noeud.definir_silhouette(noeud.couleur() * 0.5, 1.0)
		else:
			noeud.definir_silhouette(Color(0.0, 0.0, 0.0, 0.0), 0.0)

	if _sol_mat != null:
		_sol_mat.set_shader_parameter("lumiere_recue", _lumiere)


func _rafraichir_releve() -> void:
	if _releve == null:
		return
	_releve.text = ("lumière %.2f · %s%s%s%s%s%s%s · opacité %.1f%s · %d corps"
		% [_lumiere,
			"marche" if _marche else "repos",
			" · TIR" if _tir_t0 >= 0.0 else "",
			" · TOUCHÉ" if _touche_t0 >= 0.0 else "",
			" · MORT" if _mort_t0 >= 0.0 else "",
			" · ACCROUPI" if _accroupi else "",
			" · ENJAMBE" if _enjambe_t0 >= 0.0 else "",
			" · CAPTEUR" if _capteur_actif else "",
			_opacite,
			" · SILHOUETTE DE SOI" if _mode_silhouette == 1 else "",
			_corps.size()])


# ---------------------------------------------------------------------------
# LES COMMANDES
# ---------------------------------------------------------------------------

func _unhandled_input(evt: InputEvent) -> void:
	if not (evt is InputEventKey) or not evt.pressed or evt.echo:
		return
	var kc := (evt as InputEventKey).keycode
	match kc:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			_marche = not _marche
		KEY_T:
			_tir_t0 = _temps
		KEY_H:
			_touche_t0 = _temps
		KEY_M:
			_mort_t0 = _temps
		KEY_R:
			_mort_t0 = -1.0
			_tir_t0 = -1.0
			_touche_t0 = -1.0
		KEY_A:
			_accroupi = not _accroupi
			if _accroupi:
				_accroupi_t0 = _temps
		KEY_E:
			_enjambe_t0 = _temps
		KEY_C:
			_capteur_actif = not _capteur_actif
			if _capteur_actif:
				_regenerer_capteur()
		KEY_V:
			_mode_silhouette = 1 - _mode_silhouette
		KEY_BRACKETLEFT:
			_opacite = clampf(_opacite - 0.1, 0.0, 1.0)
		KEY_BRACKETRIGHT:
			_opacite = clampf(_opacite + 0.1, 0.0, 1.0)
		KEY_UP:
			_lumiere = clampf(_lumiere + 0.05, 0.0, 1.0)
			for c in _corps:
				(c["noeud"] as Node3D).definir_lumiere(_lumiere)
			if _capteur_actif:
				_regenerer_capteur()
		KEY_DOWN:
			_lumiere = clampf(_lumiere - 0.05, 0.0, 1.0)
			for c in _corps:
				(c["noeud"] as Node3D).definir_lumiere(_lumiere)
			if _capteur_actif:
				_regenerer_capteur()


# ---------------------------------------------------------------------------
# CAPTURE
# ---------------------------------------------------------------------------

func _capturer_puis_quitter() -> void:
	var refus := RenduCommun.refus_headless()
	if refus != "":
		push_error("banc_corps : capture impossible — %s" % refus)
		get_tree().quit(3)
		return
	# Ni le bandeau (texte clair, hors sujet) ni le cône repère (couleur fixe,
	# indifférente au curseur de lumière) ne doivent entrer dans une capture :
	# le premier fausserait toute lecture, le second romprait à lui seul la
	# preuve du noir absolu à lumière 0.
	if _couche_bandeau != null:
		_couche_bandeau.visible = false
	if _cone_repere != null:
		_cone_repere.visible = false
	get_window().size = _taille
	await get_tree().process_frame
	_fige = VoxelCatalogueT.portraits_actifs() or VoxelCatalogueT.mannequin_actif() or _temps_fixe
	for i in _frames:
		await get_tree().process_frame
	var image: Image = await RenduCommun.capturer(get_tree(), 60000)
	if image == null:
		push_error("banc_corps : aucune image rendue en 60 s")
		get_tree().quit(4)
		return
	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	var erreur := image.save_png(_capture)
	if erreur != OK:
		push_error("banc_corps : écriture impossible de %s (%s)" % [_capture, error_string(erreur)])
		get_tree().quit(5)
		return
	# ISO12 — avec `--corps=portraits`, la même scène reprise le portrait ÉTEINT sur les mêmes matériaux (`_gris.png`) : la
	# peinture seule change entre les deux, rien d'autre (deux lancements séparés ne se comparent pas au pixel près).
	if VoxelCatalogueT.portraits_actifs() or VoxelCatalogueT.mannequin_actif() or _contours_essai:
		for c in _corps:
			(c["noeud"] as VoxelCorpsT).materiau().set_shader_parameter("portrait", 0.0)
		for i in _frames:
			await get_tree().process_frame
		var gris: Image = await RenduCommun.capturer(get_tree(), 60000)
		# Le portrait rallumé seulement s'il l'était : sous `--mannequin` sans tenue, le rallumer peignait le corps de la palette
		# par défaut (blanche) — toutes les prises « gris » du mannequin sortaient blanches (2026-09-24, 00:42).
		for c in _corps:
			(c["noeud"] as VoxelCorpsT).materiau().set_shader_parameter("portrait", 1.0 if VoxelCatalogueT.portraits_actifs() else 0.0)
		if gris != null:
			gris.save_png(_capture.get_basename() + "_gris.png")
			print("BANC_CORPS capture du même corps, portrait éteint : %s" % (_capture.get_basename() + "_gris.png"))
		if _directions_mannequin:
			for entree in DIRECTIONS_MANNEQUIN:
				for c in _corps:
					var m: ShaderMaterial = (c["noeud"] as VoxelCorpsT).materiau()
					m.set_shader_parameter("mannequin", 0.0 if entree[0] == "sans" else 1.0)
					(c["noeud"] as VoxelCorpsT).eclairer_mannequin(entree[1])
				for i in _frames:
					await get_tree().process_frame
				var prise_m: Image = await RenduCommun.capturer(get_tree(), 60000)
				if prise_m != null:
					prise_m.save_png(_capture.get_basename() + "_mannequin_%s.png" % entree[0])
					print("BANC_CORPS capture du même corps, mannequin %s" % entree[0])
			for c in _corps:
				(c["noeud"] as VoxelCorpsT).materiau().set_shader_parameter("mannequin", 1.0)
				(c["noeud"] as VoxelCorpsT).eclairer_mannequin(Vector2.ZERO)
		if _contours_essai:
			for px in [0.0, IsoMateriaux.CONTOUR_PX_ESSAI, IsoMateriaux.CONTOUR_PX_EPAIS]:
				for c in _corps:
					(c["noeud"] as VoxelCorpsT).definir_contour(px)
				for i in _frames:
					await get_tree().process_frame
				var prise_c: Image = await RenduCommun.capturer(get_tree(), 60000)
				if prise_c != null:
					prise_c.save_png(_capture.get_basename() + "_contour_%d.png" % roundi(px))
					print("BANC_CORPS capture du même corps, contour %.1f px" % px)
			for c in _corps:
				(c["noeud"] as VoxelCorpsT).definir_contour(0.0)
		if _toutes_tenues:
			for nom in VoxelCatalogueT.TENUES_SOMBRES:
				for c in _corps:
					(c["noeud"] as VoxelCorpsT).porter_tenue(nom)
				for i in _frames:
					await get_tree().process_frame
				var prise: Image = await RenduCommun.capturer(get_tree(), 60000)
				if prise != null:
					prise.save_png(_capture.get_basename() + "_%s.png" % nom)
					print("BANC_CORPS capture du même corps, tenue %s : %s" % [nom, _capture.get_basename() + "_%s.png" % nom])
			for c in _corps:
				(c["noeud"] as VoxelCorpsT).porter_tenue(VoxelCatalogueT.tenue())
	print("BANC_CORPS capture %s %dx%d (lumière=%.2f, capteur=%s, opacité=%.2f, silhouette=%s)"
		% [_capture, image.get_width(), image.get_height(), _lumiere,
			str(_capteur_actif), _opacite, str(_mode_silhouette == 1)])
	# Le noir strict n'est attendu qu'à lumière nulle ET silhouette de soi
	# éteinte : en mode « soi », le corps reste volontairement visible dans
	# le noir (50 % de sa couleur) — ce n'est pas une régression du noir
	# absolu, c'est exactement ce que ce mode doit montrer.
	if _lumiere == 0.0 and _mode_silhouette == 0:
		var maxi := _valeur_max(image)
		print("BANC_CORPS valeur maximale des pixels à lumière 0 : %.6f (doit être 0)" % maxi)
	get_tree().quit(0)


## Balayage complet (pas un échantillon) : à lumière nulle, la revendication
## est « aucun pixel », et un pixel manqué par un pas d'échantillonnage serait
## exactement le genre de défaut que ce banc existe pour attraper.
func _valeur_max(img: Image) -> float:
	var maxi := 0.0
	var largeur := img.get_width()
	var hauteur := img.get_height()
	for y in hauteur:
		for x in largeur:
			var c := img.get_pixel(x, y)
			maxi = maxf(maxi, maxf(c.r, maxf(c.g, c.b)))
	return maxi



## Une copie opaque du shader d'un corps : `blend_mix` et `depth_draw_always` retirés, ALPHA non écrit.
static func _shader_opaque(source: Shader) -> Shader:
	var code := source.code.replace(", blend_mix, depth_draw_always", "").replace("ALPHA = a;", "")
	var copie := Shader.new()
	copie.code = code
	return copie
