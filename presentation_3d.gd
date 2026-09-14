## Presentation3D — la vue isométrique du duel (chantier ISO, étape ISO1).
##
## ## Ce qu'elle est
##
## **B-projection** (`docs/ETUDE_ISO.md`, § 3.2). La sous-vue 2D regardée continue de
## rendre TOUT le duel — sol, murs, encre, LED, décals, lumières, ombres, masques
## d'équité — et devient une « lightmap » ; ce nœud la projette sur un sol 3D, extrude
## les murs (`IsoGeometrie`), pose deux corps grossiers et une `CameraIso`. **Aucune
## `Light3D`** : la seule vérité d'ombre reste celle qui décide du jeu. Ce que l'écran
## montre est, au pixel près, ce que l'hôte fait payer.
##
## ## Où elle vit, et pourquoi
##
## Enfant de la RACINE de l'arbre (`/root/Presentation3D`), sœur de `Main` — **jamais
## sous `Player*` ni sous `GameState`**. Un nœud ajouté sous un porteur de RPC peut
## dérouter les RPC sans la moindre erreur console (« Pièges connus »). Ici, aucun
## chemin du duel ne change. Sa 3D se dessine dans le `World3D` de la fenêtre.
##
## ## Quand elle s'allume
##
## `GameSettings.mode_iso` (« Vue isométrique (expérimental) » dans les réglages, ou
## `--iso`) **et** une seule vue regardée — l'entraînement, le duel en ligne. L'écran
## scindé reste en vue de dessus jusqu'à ISO2 ; la ligne « VUE ISO » du panneau F3 le
## dit, et le journal aussi, une fois.
##
## Le jeu ne l'appelle qu'à UN endroit : la fin de `GameState.rebuild_arena()`. Tout le
## reste — allumer, tenir, éteindre, reconstruire les murs — elle le fait elle-même, à
## chaque image : le jeu redéfait ses gestes (accords de rendu, couches de sprites) et
## elle les repose en les comptant, comme le banc ISO0.b.
##
## ## Ce qu'elle écrit, et rien d'autre
##
## De la présentation seulement : l'alpha et le filtre souris du conteneur regardé, le
## `Background`, `GameState.rendu_racine_autorise` (le chemin `SubViewport` forcé, sans
## quoi la texture de la vue n'existe pas), le mode de mise à jour de la vue, et la
## couche de visibilité des dix sprites de corps — **jamais `visible`**, que le rejeu
## lit. Positions, rotations et `visual.visible` sont LUS. Tout est rendu en l'état à
## l'extinction.
class_name Presentation3D
extends Node3D

const IsoPate := preload("res://iso_pate.gd")
const SHADER_SOL := preload("res://sol_projete.gdshader")
const SHADER_MUR := preload("res://mur_iso.gdshader")
const SHADER_CORPS := preload("res://corps_grossier_iso.gdshader")

const NOM := "Presentation3D"

## La couche de visibilité où partent les sprites de corps : AUCUNE.
##
## ⚠️ **`main.tscn` déclare 3 et 5, et c'est faux dès la première image** : le jeu
## réécrit les masques en `~4` (vue de J1) et `~2` (vue de J2) dans `_setup_players()`.
## Aucun bit non nul n'échappe aux deux vues ; zéro ne partage rien avec aucun masque,
## racine comprise. Vérifié sur les masques vivants par `tools/test_iso_geometrie.gd`.
const COUCHE_HORS_VUE := 0
## Les dix nœuds qui dessinent un corps, dans les deux vues (liste du banc ISO0.b).
const APPUIS_JOUEUR := ["visual", "visual_ptr", "visual_reveal", "visual_reveal_ptr",
	"visual_dim", "visual_dim_ptr", "visual_enemy", "visual_enemy_ptr",
	"visual_reveal_enemy", "visual_reveal_enemy_ptr"]

## Où la face d'un mur lit sa lumière : à ce nombre de pixels devant elle.
const PIED_PX := 8.0
## Le corps grossier du banc : 0,4 tuile de rayon, une tuile de haut.
const RAYON_CORPS_PX := 14.0
const HAUTEUR_CORPS_PX := 35.0

## Les touches de la pâte, pendant qu'elle est allumée : **1, 2, 3, 4** choisissent A, B, C,
## D et **0** la brute ; F2 les fait défiler.
##
## ⚠️ **F2 seule n'a jamais atteint le jeu chez Adrien** (2026-09-14, trois parties, aucune
## ligne `[iso] pâte` au journal) : sur un Mac, F2 sans `fn` règle la luminosité et n'est pas
## transmise à l'application. La rangée des chiffres se lit par `physical_keycode` : en
## AZERTY, `keycode` y donne `&`, `é`, `"` (piège de `tools/banc_audio.gd`). Aucune action
## de l'Input Map ni aucun script du jeu ne la prend.
const TOUCHE_PATE := KEY_F2
const TOUCHES_DIRECTES := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_0: -1}
## **D, lavis et pochoir — décision d'Adrien, 2026-09-14** (jalon H-ISO1), sur la planche
## et la mesure de fidélité : la seule pâte qui garde la lueur faible au niveau de la vue
## de dessus.
const PATE_PAR_DEFAUT := IsoPate.LAVIS
const DRAPEAU_PATE := "--pate"

static var _instance: Presentation3D

## La pâte en cours (uniform `style`) — `--pate A|B|C|D|brute`, puis 1-4, 0 ou F2.
var style_pate := PATE_PAR_DEFAUT
## Ce que la ligne « VUE ISO » du panneau F3 affiche.
var etat := "en attente du prochain duel"

## Ce que le jeu a défait et qu'elle a dû reposer. Un compteur qui monte dit qu'un
## chemin du jeu repose des couches ou des modes de rendu : ISO2 devra le savoir.
var corps_recaches := 0
var vues_relancees := 0

var _main: Node
var _actif := false
var _reconstruire := true
var _vue: SubViewport
var _sauvegarde := {}
## CanvasItem → couche d'origine, pour rendre les sprites à l'extinction.
var _couches := {}
var _scinde_signale := false

var _scene: Node3D
var _camera: CameraIso
var _sol: MeshInstance3D
var _murs: Node3D
var _corps: Array[Node3D] = []
var _mat_sol: ShaderMaterial
var _mat_mur: ShaderMaterial
var _mat_corps: Array[ShaderMaterial] = []


## Le crochet du jeu — appelé par `GameState.rebuild_arena()`, sous garde `mode_iso`.
## Crée le nœud au premier appel, puis demande seulement de reconstruire les murs :
## la carte vient peut-être de changer.
static func accrocher(main: Node) -> Presentation3D:
	if not is_instance_valid(_instance):
		_instance = Presentation3D.new()
		_instance.name = NOM
		# Différé : `rebuild_arena()` tourne aussi pendant le `_ready()` de `Main`, quand
		# la racine refuse encore qu'on lui ajoute un enfant.
		main.get_tree().root.add_child.call_deferred(_instance)
	_instance._main = main
	_instance._reconstruire = true
	return _instance


static func instance() -> Presentation3D:
	return _instance if is_instance_valid(_instance) else null


## Le texte de la ligne « VUE ISO » du panneau F3.
static func texte_f3(mode_iso: bool) -> String:
	if not mode_iso:
		return "désactivée"
	var p := instance()
	return p.etat if p != null else "en attente du prochain duel"


func _ready() -> void:
	# Après la caméra 2D et l'interpolation des joueurs : sinon le sol et la lightmap
	# auraient une image d'écart, et le sol tremblerait à chaque pas.
	process_priority = 10000
	var args := OS.get_cmdline_user_args()
	var i := args.find(DRAPEAU_PATE)
	if i >= 0 and i + 1 < args.size():
		var st := IsoPate.style_depuis_nom(args[i + 1])
		if st >= IsoPate.BRUTE:
			style_pate = st
		else:
			push_error("Presentation3D : --pate attend A, B, C, D ou brute (reçu « %s »)" % args[i + 1])
	_construire_la_scene()


func _exit_tree() -> void:
	if _actif:
		_eteindre()


func _process(_delta: float) -> void:
	var vue := _vue_a_projeter()
	if _actif and vue != _vue:
		_eteindre()
	if vue != null:
		if not _actif:
			_allumer(vue)
		_tenir()
		_suivre()
	etat = _decrire(vue)


# ---------------------------------------------------------------------------
# ALLUMER, TENIR, ÉTEINDRE
# ---------------------------------------------------------------------------

func _mode_iso_voulu() -> bool:
	var reglages := get_node_or_null(^"/root/GameSettings")
	return reglages != null and bool(reglages.get("mode_iso"))


## La vue à projeter, ou `null`. Le `visible` d'un conteneur est la source de vérité
## du jeu pour « quelle vue est regardée » (`_accorder_rendu_aux_vues`) : on la lit là,
## sans en tenir une seconde.
func _vue_a_projeter() -> SubViewport:
	if not _mode_iso_voulu() or not is_instance_valid(_main) or not _main.is_inside_tree():
		return null
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2) or _main.cam1 == null:
		return null
	var regardees: Array[SubViewport] = []
	for vue: SubViewport in [_main.vp1, _main.vp2]:
		var conteneur := vue.get_parent() as Control
		if conteneur != null and conteneur.visible:
			regardees.append(vue)
	return regardees[0] if regardees.size() == 1 else null


func _allumer(vue: SubViewport) -> void:
	_vue = vue
	var conteneur := vue.get_parent() as SubViewportContainer
	var fond := _main.get_node_or_null("Background") as CanvasItem
	_sauvegarde = {
		"autorise": _main.rendu_racine_autorise,
		"conteneur": conteneur,
		"alpha": conteneur.modulate.a,
		"souris": conteneur.mouse_filter,
		"fond": fond,
		"fond_visible": fond.visible if fond != null else false,
	}
	# Le chemin `SubViewport` : sans lui, la vue unique est rendue par la racine et la
	# texture de la vue reste gelée — il n'y aurait rien à projeter.
	_main.rendu_racine_autorise = false
	_main._accorder_rendu_aux_vues()
	# ⚠️ **Transparent, pas caché** (écart voulu du banc ISO0.b) : caché, le jeu
	# arrêterait la vue à chaque accord, retirerait son brouillage, et le conteneur ne
	# transmettrait plus la souris. Transparent, il reste regardé ; la 3D prend l'écran.
	conteneur.modulate.a = 0.0
	# La visée souris est reprojetée sur le sol par `_viser_a_la_souris()`.
	conteneur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le fond noir plein cadre de `main.tscn` se dessine APRÈS la 3D de la racine.
	# `visible` et non `modulate` : c'est `modulate` que le jeu réécrit à chaque accord.
	if fond != null:
		fond.visible = false
	if _reconstruire or _murs == null:
		_construire_les_murs()
	for m in _materiaux():
		m.set_shader_parameter("lumiere", vue.get_texture())
	for j in [_main.p1, _main.p2]:
		_cacher_corps(j)
	_scene.visible = true
	_camera.current = true
	_actif = true
	_scinde_signale = false
	print("[iso] vue isométrique allumée sur %s — tangage %s°, murs %s tuile (%s), pâte %s"
		% [vue.name, str(_camera.tangage_deg), str(IsoGeometrie.hauteur_mur_haut()),
		IsoGeometrie.source_des_hauteurs(), IsoPate.NOMS[style_pate]])


func _eteindre() -> void:
	_actif = false
	if _scene != null:
		_scene.visible = false
	if _camera != null:
		_camera.current = false
	_rendre_corps()
	if not _sauvegarde.is_empty():
		var conteneur = _sauvegarde["conteneur"]
		if is_instance_valid(conteneur):
			conteneur.modulate.a = _sauvegarde["alpha"]
			conteneur.mouse_filter = _sauvegarde["souris"]
		var fond = _sauvegarde["fond"]
		if is_instance_valid(fond):
			fond.visible = _sauvegarde["fond_visible"]
		if is_instance_valid(_main):
			_main.rendu_racine_autorise = _sauvegarde["autorise"]
			if _main.is_inside_tree():
				_main._accorder_rendu_aux_vues()
	_sauvegarde.clear()
	_vue = null
	print("[iso] vue isométrique éteinte (%d corps recachés, %d vue(s) relancée(s) pendant qu'elle tenait)"
		% [corps_recaches, vues_relancees])


## Ce que le jeu peut défaire pendant la partie, reposé et compté.
func _tenir() -> void:
	var conteneur = _sauvegarde["conteneur"]
	if is_instance_valid(conteneur) and conteneur.modulate.a != 0.0:
		conteneur.modulate.a = 0.0
	var fond = _sauvegarde["fond"]
	if is_instance_valid(fond) and fond.visible:
		fond.visible = false
	if _main.rendu_racine_autorise:
		_main.rendu_racine_autorise = false
		_main._accorder_rendu_aux_vues()
	if _vue.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vues_relancees += 1
	for j in [_main.p1, _main.p2]:
		corps_recaches += _cacher_corps(j)


func _suivre() -> void:
	var canevas: Transform2D = _vue.canvas_transform
	var taille := Vector2(_vue.size_2d_override) if _vue.size_2d_override != Vector2i.ZERO \
		else Vector2(_vue.size)
	for m in _materiaux():
		m.set_shader_parameter("canevas_x", canevas.x)
		m.set_shader_parameter("canevas_y", canevas.y)
		m.set_shader_parameter("canevas_o", canevas.origin)
		m.set_shader_parameter("taille_2d", taille)
		m.set_shader_parameter("style", style_pate)
	var rect := CameraIso.rect_couvert(canevas, taille)
	_sol.position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	_sol.scale = Vector3(rect.size.x, 1.0, rect.size.y)
	_camera.suivre(canevas, taille)
	var joueurs := [_main.p1, _main.p2]
	for i in 2:
		var j = joueurs[i]
		# `visual.visible` est LU, jamais écrit : c'est l'état de mort que le rejeu
		# enregistre. `visible` du joueur : l'entraînement cache J2 ainsi.
		_corps[i].visible = is_instance_valid(j) and j.visible and j.visual.visible
		if not _corps[i].visible:
			continue
		var p: Vector2 = j.global_position
		_corps[i].position = Vector3(p.x, 0.0, p.y)
		_corps[i].basis = Basis.looking_at(Vector3(cos(j.rotation), 0.0, sin(j.rotation)), Vector3.UP)
		_mat_corps[i].set_shader_parameter("pied_corps", p)


func _cacher_corps(joueur: Node) -> int:
	if not is_instance_valid(joueur):
		return 0
	var n := 0
	for nom in APPUIS_JOUEUR:
		var noeud := joueur.get(nom) as CanvasItem
		if noeud == null or noeud.visibility_layer == COUCHE_HORS_VUE:
			continue
		if not _couches.has(noeud):
			_couches[noeud] = noeud.visibility_layer
		noeud.visibility_layer = COUCHE_HORS_VUE
		n += 1
	return n


## Rend aux sprites leur couche d'origine — sauf si le jeu en a posé une autre entre
## temps, qui fait alors foi.
func _rendre_corps() -> void:
	for noeud in _couches:
		if is_instance_valid(noeud) and (noeud as CanvasItem).visibility_layer == COUCHE_HORS_VUE:
			(noeud as CanvasItem).visibility_layer = _couches[noeud]
	_couches.clear()


func _decrire(vue: SubViewport) -> String:
	if not _mode_iso_voulu():
		return "désactivée"
	if _actif and vue != null:
		return "%s° · murs %s t · pâte %s · lightmap %d×%d" % [str(_camera.tangage_deg),
			str(IsoGeometrie.hauteur_mur_haut()), IsoPate.NOMS[style_pate].get_slice(" ", 0),
			vue.size.x, vue.size.y]
	if is_instance_valid(_main) and is_instance_valid(_main.p1) \
			and (_main.round_active or _main.sandbox_mode) and _main.vp2.get_parent().visible \
			and _main.vp1.get_parent().visible:
		if not _scinde_signale:
			_scinde_signale = true
			print("[iso] écran scindé : vue de dessus jusqu'à ISO2")
		return "écran scindé : vue de dessus jusqu'à ISO2"
	return "en attente du prochain duel"


# ---------------------------------------------------------------------------
# LA SCÈNE
# ---------------------------------------------------------------------------

func _construire_la_scene() -> void:
	_scene = Node3D.new()
	_scene.name = "SceneIso"
	_scene.visible = false
	add_child(_scene)

	_camera = CameraIso.new()
	add_child(_camera)

	_mat_sol = _materiau(SHADER_SOL)
	_mat_mur = _materiau(SHADER_MUR)
	_mat_mur.set_shader_parameter("pied", PIED_PX)

	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE
	_sol = MeshInstance3D.new()
	_sol.name = "Sol"
	_sol.mesh = plan
	_sol.material_override = _mat_sol
	_sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene.add_child(_sol)

	var cylindre := CylinderMesh.new()
	cylindre.top_radius = RAYON_CORPS_PX
	cylindre.bottom_radius = RAYON_CORPS_PX
	cylindre.height = HAUTEUR_CORPS_PX
	var nez := BoxMesh.new()
	nez.size = Vector3(6.0, 6.0, 12.0)
	for i in 2:
		var mat := _materiau(SHADER_CORPS)
		mat.set_shader_parameter("gris", Charte.ADVERSAIRE)
		_mat_corps.append(mat)
		var corps := Node3D.new()
		corps.name = "Corps%d" % (i + 1)
		var pieces := [[cylindre, Vector3(0.0, HAUTEUR_CORPS_PX * 0.5, 0.0), "Tronc"],
			[nez, Vector3(0.0, HAUTEUR_CORPS_PX * 0.6, -(RAYON_CORPS_PX + 4.0)), "Nez"]]
		for piece in pieces:
			var mi := MeshInstance3D.new()
			mi.name = piece[2]
			mi.mesh = piece[0]
			mi.position = piece[1]
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			corps.add_child(mi)
		_scene.add_child(corps)
		_corps.append(corps)


func _construire_les_murs() -> void:
	if _murs != null:
		_scene.remove_child(_murs)
		_murs.queue_free()
	var cartes := get_node_or_null(^"/root/MapData")
	var data: Dictionary = cartes.get_selected() if cartes != null else {}
	_murs = IsoGeometrie.build_meshes(data, _mat_mur)
	_scene.add_child(_murs)
	_reconstruire = false


## Un matériau par shader PRÉCHARGÉ : aucun `Shader.new()` à la volée, qui compilerait
## au premier affichage (piège consigné — le hoquet tombe sur l'action).
func _materiau(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("style", style_pate)
	return m


func _materiaux() -> Array[ShaderMaterial]:
	var tous: Array[ShaderMaterial] = [_mat_sol, _mat_mur]
	tous.append_array(_mat_corps)
	return tous


# ---------------------------------------------------------------------------
# ENTRÉES — la pâte à chaud, la visée souris
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _actif:
		return
	var touche := event as InputEventKey
	if touche != null and touche.pressed and not touche.echo:
		var choisie := -2
		if TOUCHES_DIRECTES.has(touche.physical_keycode):
			choisie = TOUCHES_DIRECTES[touche.physical_keycode]
		elif touche.physical_keycode == TOUCHE_PATE or touche.keycode == TOUCHE_PATE:
			# A → B → C → D → brute → A
			choisie = IsoPate.BRUTE if style_pate == IsoPate.LAVIS else \
				(IsoPate.GRAVURE if style_pate == IsoPate.BRUTE else style_pate + 1)
		if choisie >= IsoPate.BRUTE:
			style_pate = choisie
			print("[iso] pâte %s" % IsoPate.NOMS[style_pate])
			get_viewport().set_input_as_handled()
			return
	var souris := event as InputEventMouseMotion
	if souris != null:
		_viser_a_la_souris(souris)


## La souris vise le point du SOL sous le curseur, et non le point de l'écran.
##
## `LocalInputProvider` lit la position de la souris dans la vue et la ramène au monde
## par la transformation de canevas. On lui pousse donc, en coordonnées de sa vue,
## l'image du point où le rayon de la caméra 3D coupe le sol (patron du banc ISO0.b).
## La vraie reprojection des entrées est l'affaire d'ISO5.
func _viser_a_la_souris(souris: InputEventMouseMotion) -> void:
	var origine := _camera.project_ray_origin(souris.position)
	var direction := _camera.project_ray_normal(souris.position)
	if absf(direction.y) < 1e-5:
		return
	var sol := origine + direction * (-origine.y / direction.y)
	var poussee := souris.duplicate() as InputEventMouseMotion
	poussee.position = _vue.canvas_transform * Vector2(sol.x, sol.z)
	poussee.global_position = poussee.position
	_vue.push_input(poussee, true)
