## Banc ISO0.b — la vue isométrique « B-projection », posée sur le VRAI duel.
##
## ## La question
##
## L'étude ISO0 (`docs/ETUDE_ISO.md`, § 3.2) recommande de garder la lumière 2D
## comme seule vérité et de la PROJETER sur un sol 3D : la sous-vue 2D d'un joueur
## devient sa « lightmap », et la 3D n'ajoute que le relief. Aucun des deux
## prototypes de l'étude ne montre cette voie — ils refont la lumière en 3D. Et
## elle a un prix que l'étude nomme sans le chiffrer : elle **réintroduit la
## cible de rendu intermédiaire** que le chantier R avait supprimée pour +15 % de
## cadence — et l'écran scindé en paie deux.
##
## Ce banc produit ce chiffre, et l'image qui va avec, dans le jeu tel qu'il est :
## vraies lumières, vrais masques, vraie carte, deux joueurs jouables. **Il ne
## décide rien** : le jalon H15 appartient à Adrien, sur des relevés pris fenêtre
## au premier plan.
##
## ## Ce qu'il pose, à l'exécution — aucun fichier du jeu n'est modifié
##
## - le vrai duel local (`main.tscn`, « 1v1 écrans scindés »), jouable pendant la
##   mesure au clavier/souris et à la manette ; les joueurs ne meurent pas, pour
##   que la minute mesurée soit un duel et non une killcam ;
## - les sprites de corps (`visual*` de `player.gd`) déplacés sur une couche de
##   visibilité qu'aucune vue ne lit — **jamais `visible = false`**, que le rejeu
##   lit (`replay_system.gd`) ; tout le reste (sol, murs, LED, décals, nappes,
##   torches, flashs, vignette) reste dans la lightmap ;
## - le rendu par `SubViewport` (`rendu_racine_autorise = false`), la texture de
##   la vue 2D projetée sur un sol plan 3D, les murs extrudés, deux corps
##   grossiers, une caméra orthographique inclinée ;
## - en `--scinde`, deux `SubViewport` 3D qui partagent un `World3D`.
##
## ## Lancer
##
##   godot --path . res://tools/banc_iso.tscn -- [--base] [--scinde]
##       [--lightmap plein|1080p|demi] [--tangage 60] [--lacet 0] [--mur 0.45]
##       [--carte <slug>] [--seconds 60] [--charge]
##       [--capture chemin.png [--flash] [--noir]] [--taille 1920x1080]
##       [--jeu [--pate A|B|C|D|brute] [--sans-hud]]
##
## `--charge` : l'échange au pompe de `bench_framerate.gd`, pour des relevés
## comparables. `--capture` : une image (et la lightmap de chaque vue à côté),
## torches braquées côte à côte sur le mur le plus proche ; `--flash` y ajoute un
## tir de J1 — et la secousse de caméra qui va avec.
##
## `--jeu` (ISO1) : la vue iso n'est plus construite par le banc mais par le JEU —
## `GameSettings.mode_iso` allumé pour l'exécution, `Presentation3D` posée par le crochet
## de `rebuild_arena()`. C'est le chemin qu'Adrien joue, donc celui qu'on mesure. Tangage
## et lacet sont ceux du jeu (`CameraIso`) ; `--mur` y retaille les boîtes pour une
## planche, sans toucher au jeu ; F2 fait défiler les pâtes. Vue unique seulement : l'écran
## scindé iso est ISO2. `--noir` (avec `--capture`) éteint TOUTES les lumières et le HUD,
## puis imprime la valeur maximale de l'image et de la lightmap : le contrôle du noir
## absolu, au pixel, pour la pâte passée en `--pate`. `--sans-hud` retire le HUD d'une capture.
##
## Pendant la partie : **F8** fait défiler le tangage, **F9** le lacet, **F10** la
## hauteur des murs. Le protocole de relevé est dans `docs/ROADMAP.md`, section ISO.
##
## Ce banc ouvre une vraie fenêtre : il ne peut rejoindre aucune suite headless.
## Ses appuis sur le jeu sont vérifiés par `tools/test_banc_iso.gd`.
extends Node

const BancCadence := preload("res://tools/bench_framerate.gd")
const ProtoIso := preload("res://tools/proto_iso.gd")

## Les valeurs que l'étude demande de voir (§ 9.4), dans l'ordre où F8/F9/F10
## les font défiler. Une valeur hors liste reste acceptée en option : c'est un
## banc, pas une règle.
const TANGAGES := [52.0, 55.0, 60.0, 65.0, 70.0, 75.0]
const LACETS := [0.0, 45.0]
const MURS := [0.3, 0.45, 0.7]
## La taille de la cible intermédiaire — le poste que le chantier R avait
## supprimé. `plein` : les pixels de la fenêtre ; `1080p` : l'aire logique
## (1920×1080 en vue unique, ce que rendait le jeu avant R) ; `demi` : la moitié.
const LIGHTMAPS := ["plein", "1080p", "demi"]

## La couche de visibilité où partent les sprites de corps : AUCUNE.
##
## ⚠️ **`main.tscn` dit 3 et 5, et c'est faux dès la première image.** Le jeu
## réécrit les masques à l'exécution en « tout sauf la couche des corps de
## l'autre » — `~4` pour la vue de J1, `~2` pour celle de J2 (`game_state.gd`,
## juste avant `_setup_players`, ligne 1085 au 2026-09-14 ; relu
## par `test_banc_iso.gd` le 2026-09-14, qui a rougi sur la vingtième couche
## qu'on croyait libre). Aucun bit non nul n'échappe donc aux DEUX vues ; zéro,
## lui, ne partage rien avec aucun masque, racine comprise.
const COUCHE_HORS_VUE := 0
const CHEMIN_VUE_1 := "SplitScreen/ViewportContainer1/SubViewport1"
const CHEMIN_VUE_2 := "SplitScreen/ViewportContainer2/SubViewport2"

## Les dix nœuds qui dessinent un corps, dans les deux vues. Tous portent le
## sprite du joueur (`_poser_sprite()`) ou son nez de direction.
const APPUIS_JOUEUR := ["visual", "visual_ptr", "visual_reveal", "visual_reveal_ptr",
	"visual_dim", "visual_dim_ptr", "visual_enemy", "visual_enemy_ptr",
	"visual_reveal_enemy", "visual_reveal_enemy_ptr"]

## La hauteur logique d'une vue : l'aire 2D est 1920×1080 (`stretch = keep`).
const HAUTEUR_VUE := 1080.0
## Recul de la caméra le long de son axe. En orthographique il ne change pas
## l'image ; il doit seulement laisser la scène entre `near` et `far`.
const RECUL := 5000.0
## Où la face d'un mur lit sa lumière : à ce nombre de pixels DEVANT elle, sur le
## sol. Pas zéro — la case du mur est noire dans la lightmap, et son liseré
## d'encre en occupe le bord (les occluders sont rentrés de 3 px,
## `MapGeometry.OCCLUDER_INSET`).
const PIED_PX := 8.0
## Le corps grossier : 0,4 tuile de rayon, une tuile de haut, comme le prototype.
const RAYON_CORPS_PX := 14.0
const HAUTEUR_CORPS_PX := 35.0

const ROLE_SOL := 0
const ROLE_MUR := 1
const ROLE_CORPS := 2

## Une matière pour tout ce que la 3D dessine, et une seule formule de projection.
##
## ⚠️ **`unshaded`, et ce n'est pas une facilité.** Un sol Lambert éteint le cône
## d'une torche rasante (piège du 2026-09-13) ; ici il n'y a de toute façon rien
## à éclairer : la lumière EST la texture.
##
## Le monde 3D est en pixels du monde 2D : `x` → `x`, `y` → `z`. La lightmap se
## lit par la transformation de canevas de sa vue — exactement celle qui l'a
## rendue —, donc sans hypothèse sur la caméra 2D, secousse et zoom compris.
## `source_color` : la texture de la vue est en sRGB, la sortie 3D aussi ;
## l'aller-retour se vérifie au pixel à 90° de tangage contre `--base`.
##
## En écran scindé, murs et corps sont COMMUNS aux deux caméras : la vue qui les
## dessine se lit dans `CAMERA_VISIBLE_LAYERS` (la caméra de J2 voit la couche 3).
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform sampler2D lumiere_1 : source_color, filter_linear, repeat_disable;
uniform sampler2D lumiere_2 : source_color, filter_linear, repeat_disable;
uniform vec2 canevas_1_x = vec2(1.0, 0.0);
uniform vec2 canevas_1_y = vec2(0.0, 1.0);
uniform vec2 canevas_1_o = vec2(0.0);
uniform vec2 taille_1 = vec2(1.0);
uniform vec2 canevas_2_x = vec2(1.0, 0.0);
uniform vec2 canevas_2_y = vec2(0.0, 1.0);
uniform vec2 canevas_2_o = vec2(0.0);
uniform vec2 taille_2 = vec2(1.0);
uniform int role = 0;
uniform int vue = 0;
uniform float pied = 8.0;
uniform vec2 pied_corps = vec2(0.0);
uniform vec3 gris : source_color = vec3(0.5);
uniform float seuil_bas = 0.01;
uniform float seuil_haut = 0.08;

varying vec3 monde;
varying vec3 normale;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 lire(vec2 px, bool deux) {
	vec2 uv = deux
		? (canevas_2_x * px.x + canevas_2_y * px.y + canevas_2_o) / taille_2
		: (canevas_1_x * px.x + canevas_1_y * px.y + canevas_1_o) / taille_1;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	return deux ? texture(lumiere_2, uv).rgb : texture(lumiere_1, uv).rgb;
}

void fragment() {
	bool deux = vue == 1 || (vue < 0 && (CAMERA_VISIBLE_LAYERS & uint(4)) != uint(0));
	vec3 c = vec3(0.0);
	if (role == 0) {
		c = lire(monde.xz, deux);
	} else if (role == 1) {
		// Sommet noir strict ; une face verticale prend la lumière du sol à son pied.
		if (abs(normale.y) < 0.5) {
			c = lire(monde.xz + normalize(normale.xz) * pied, deux);
		}
	} else {
		// Gris plafonné, noir hors lumière : la lumière reçue sous les pieds.
		float lum = dot(lire(pied_corps, deux), vec3(0.2126, 0.7152, 0.0722));
		c = gris * smoothstep(seuil_bas, seuil_haut, lum);
	}
	ALBEDO = c;
}
"""

const WARMUP_SEC := 2.0

var _main: Node
var _ui: Node

var _base := false
var _scinde := false
var _charge := false
var _lightmap := "1080p"
var _tangage := 60.0
var _lacet := 0.0
var _mur := 0.45
var _carte := ""
var _seconds := 60.0
var _capture := ""
var _flash := false
var _taille := Vector2i.ZERO
var _jeu := false
var _noir := false
var _sans_hud := false
var _mur_donne := false

## Posé une fois la vue construite : `_process` ne touche à rien avant.
var _pret := false
var _vues: Array[SubViewport] = []
## Le cadre logique de chaque vue, relevé AVANT que le banc touche aux
## conteneurs — voir `_poser_la_vue()`.
var _cadres: Array[Rect2] = []
var _shader: Shader
var _materiaux: Array[ShaderMaterial] = []
var _mat_sols: Array[ShaderMaterial] = []
var _mat_corps: Array[ShaderMaterial] = []
var _murs: Node3D
var _sols: Array[MeshInstance3D] = []
var _corps: Array[Node3D] = []
var _cameras: Array[Camera3D] = []
var _vues3d: Array[SubViewport] = []
var _affichages: Array[TextureRect] = []

var _samples: Array[float] = []
var _appels: Array[int] = []
var _images_hors_focus := 0
var _images_hors_manche := 0
## Ce que le jeu a défait et que le banc a dû reposer pendant la partie. Un
## compteur à zéro ne prouve rien ; un compteur qui monte dit qu'un chemin du jeu
## repose des couches ou des modes de rendu, et qu'ISO2 devra le savoir.
var _corps_recaches := 0
var _vues_relancees := 0


func _ready() -> void:
	# Après la caméra 2D et l'interpolation des joueurs : sinon le sol et la
	# lightmap auraient une image d'écart, et le sol tremblerait à chaque pas.
	process_priority = 10000
	if not _lire_arguments(OS.get_cmdline_user_args()):
		_sortir(2)
		return
	var refus := RenduCommun.refus_headless()
	if refus != "":
		printerr("✗ banc_iso : ", refus)
		_sortir(3)
		return
	if _jeu and _scinde:
		printerr("✗ banc_iso : --jeu ne connaît que la vue unique (l'écran scindé iso est ISO2)")
		_sortir(2)
		return
	if _noir and (_capture == "" or not (_jeu or _base) or _scinde):
		printerr("✗ banc_iso : --noir se prend avec --capture, et --jeu ou --base (vue unique)")
		_sortir(2)
		return
	GameSettings.pilotage_externe = true
	if _jeu:
		# Pour cette exécution seulement : `mode_iso` n'est pas `set_mode_iso()`, rien ne
		# s'écrit dans settings.cfg.
		GameSettings.mode_iso = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_couper_le_son("avant la scène")
	_reclamer_le_premier_plan()
	if _taille != Vector2i.ZERO:
		# `Window.size` et non `window_set_size()` : voir « Pièges connus »
		# (2026-09-13), la vue ne suit pas toujours le second.
		get_window().size = _taille
	if _capture != "":
		# ⚠️ **Une fenêtre recouverte ne dessine plus**, et `frame_post_draw` ne
		# vient jamais : deux captures sur trois ont échoué le 2026-09-14 pendant
		# qu'Adrien travaillait à côté. Même remède que `photographe.gd`. Jamais
		# pendant une MESURE : ce drapeau change ce que le système fait de la fenêtre.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	print("=== Banc ISO0.b — B-projection dans le vrai duel ===")
	print("Rendu : %s" % _libelle())

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_couper_le_son("après la scène")
	_ui = _main.get_node("UI")

	var manquants := preconditions_manquantes(_ui, _main)
	if not manquants.is_empty():
		printerr("✗ le banc ne peut pas démarrer — le jeu a changé sous lui :")
		for m in manquants:
			printerr("    · ", m)
		printerr("  Voir tools/test_banc_iso.gd, qui vérifie ces appuis en headless.")
		_sortir(1)
		return

	if _carte != "":
		var entree: Dictionary = MapData.get_map_by_slug(_carte)
		if entree.is_empty():
			printerr("✗ carte « %s » introuvable" % _carte)
			_sortir(1)
			return
		MapData.select_map(String(entree["id"]))

	# Avant le lancement : la manche démarre déjà sur le chemin mesuré, sans
	# bascule racine → sous-vues au milieu de l'échauffement.
	if not _jeu:
		_main.rendu_racine_autorise = _base
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	if _charge:
		_select_shotgun(_ui.p1_weapon_group)
		_select_shotgun(_ui.p2_weapon_group)
	_main._on_replay_requested()
	if not await _attendre(func(): return _main.round_active, 15.0):
		printerr("✗ la manche n'a pas démarré")
		_sortir(1)
		return
	# La manche est « active » dès le décompte ; les joueurs, eux, attendent son
	# terme. La première capture du 2026-09-14 est tombée sur le « 1 ».
	await _attendre(func(): return _main.countdown_left <= 0.0, 10.0)
	print("Carte : « %s »" % String(MapData.get_selected().get("name", "?")))

	if not await _poser_la_vue():
		_sortir(1)
		return
	_pret = true
	_conditions()

	print("Échauffement %.0f s…" % WARMUP_SEC)
	await _jouer(WARMUP_SEC, false)
	if _capture != "":
		await _capturer()
		return
	print("Mesure sur %.0f s…" % _seconds)
	await _jouer(_seconds, true)
	_report()
	_sortir(0)


# ---------------------------------------------------------------------------
# ARGUMENTS
# ---------------------------------------------------------------------------

func _lire_arguments(args: PackedStringArray) -> bool:
	_base = args.has("--base")
	_scinde = args.has("--scinde")
	_charge = args.has("--charge")
	_seconds = maxf(1.0, float(_value(args, "--seconds", "60")))
	_lightmap = _value(args, "--lightmap", "1080p")
	_tangage = clampf(float(_value(args, "--tangage", "60")), 1.0, 90.0)
	_lacet = float(_value(args, "--lacet", "0"))
	_mur = maxf(0.05, float(_value(args, "--mur", "0.45")))
	_carte = _value(args, "--carte", "")
	_capture = _value(args, "--capture", "")
	_flash = args.has("--flash")
	_jeu = args.has("--jeu")
	_noir = args.has("--noir")
	_sans_hud = args.has("--sans-hud")
	_mur_donne = args.has("--mur")
	var taille := _value(args, "--taille", "")
	if taille != "":
		var parts := taille.to_lower().split("x")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			printerr("✗ --taille attend LxH (reçu « %s »)" % taille)
			return false
		_taille = Vector2i(int(parts[0]), int(parts[1]))
	if not LIGHTMAPS.has(_lightmap):
		printerr("✗ --lightmap attend %s (reçu « %s »)" % [" | ".join(LIGHTMAPS), _lightmap])
		return false
	for paire in [[_tangage, TANGAGES, "tangage"], [_lacet, LACETS, "lacet"], [_mur, MURS, "mur"]]:
		if not (paire[1] as Array).has(paire[0]):
			print("  note : %s %s hors des valeurs de l'étude %s" % [paire[2], str(paire[0]), str(paire[1])])
	return true


func _libelle() -> String:
	var vue := "écran scindé" if _scinde else "vue unique"
	if _jeu:
		return "JEU (Presentation3D), vue unique, tangage %s°, murs %s tuile, pâte %s%s" % [
			str(CameraIso.TANGAGE_DEG), str(_mur if _mur_donne else IsoGeometrie.hauteur_mur_haut()),
			_pate_nommee(), ", charge automatique" if _charge else ""]
	if _base:
		return "BASE (vue de dessus, telle qu'aujourd'hui), %s%s" % [vue,
			", rendu par la racine" if not _scinde else ""]
	return "ISO, %s, lightmap %s, tangage %s°, lacet %s°, murs %s tuile%s" % [vue, _lightmap,
		str(_tangage), str(_lacet), str(_mur), ", charge automatique" if _charge else ""]


# ---------------------------------------------------------------------------
# LA VUE
# ---------------------------------------------------------------------------

func _poser_la_vue() -> bool:
	if not _scinde:
		# Le geste de `_restore_viewports()` en ligne et à l'entraînement : cacher
		# le conteneur, laisser le jeu accorder le rendu. C'est lui qui arrête la
		# seconde vue (UPDATE_DISABLED) — un conteneur caché ne suffit pas.
		_main.vp2.get_parent().hide()
		_main.ui.center_line.hide()
		_main._accorder_rendu_aux_vues()
	# La mise en page doit avoir élargi la vue 1 avant qu'on lise sa taille.
	await get_tree().process_frame
	await get_tree().process_frame
	if _base:
		if _noir:
			_ui.visible = false
		return true
	if _jeu:
		return await _attendre_la_presentation()

	_vues.assign([_main.vp1] if not _scinde else [_main.vp1, _main.vp2])
	# Le fond noir plein cadre de `main.tscn` se dessine APRÈS la 3D de la racine.
	# `visible` et non `modulate` : c'est `modulate` que le jeu réécrit à chaque
	# accord (`_accorder_la_peinture_de_la_racine`).
	_main.get_node("Background").visible = false
	# ⚠️ **Les cadres se lisent AVANT la première lightmap.** Un
	# `SubViewportContainer` sans `stretch` prend la taille de sa vue comme taille
	# MINIMALE : dès que la lightmap `plein` dépasse l'aire logique, le conteneur
	# (invisible) grandit d'autant et pousse son voisin. Lus après, les cadres
	# appliquaient l'étirement deux fois — vues 3D de 1701×1920 au lieu de
	# 1276×1440 sur une fenêtre 2560×1440, et l'affichage de J2 hors de l'écran
	# (mesuré le 2026-09-14 ; invisible aux captures 1920×1080, étirement ×1).
	_cadres.clear()
	for vue in _vues:
		_cadres.append((vue.get_parent() as Control).get_global_rect())
	for vue in _vues:
		_poser_lightmap(vue)
	await get_tree().process_frame
	_construire_3d()

	var caches := 0
	for j in [_main.p1, _main.p2]:
		caches += _cacher_corps(j)
	# Une variante doit prouver qu'elle a changé quelque chose (leçon du
	# 2026-08-18) : zéro nœud déplacé, et le banc mesurerait le jeu avec ses
	# sprites en croyant les avoir retirés.
	if caches == 0:
		printerr("✗ aucun sprite de corps déplacé : la variante ne mesure rien")
		return false
	print("RETIRÉ : %d nœuds de corps sur la couche de visibilité %d, qu'aucune vue ne lit"
		% [caches, COUCHE_HORS_VUE])
	return true


## La vue 2D devient une lightmap : elle rend toujours, mais ne s'affiche plus.
##
## ⚠️ **Transparent, pas caché** — l'écart à la consigne est voulu, pour trois
## raisons lues dans le jeu. Le `visible` d'un conteneur est la source de vérité
## de « quelle vue est regardée » : caché, `_accorder_rendu_aux_vues()` l'arrête à
## chaque accord, `_accorder_brouillage_aux_vues()` retire son brouillage, et il
## ne transmet plus la souris dont `LocalInputProvider` tire la visée de J1.
## Transparent, il reste regardé ; c'est la 3D qui prend l'écran.
##
## La taille vient de `size_2d_override` : le monde 2D reste celui d'une vue
## 1920×1080 (caméras, zoom et champ inchangés) pendant que la texture prend la
## résolution de la variante.
func _poser_lightmap(vue: SubViewport) -> void:
	var conteneur := vue.get_parent() as SubViewportContainer
	var logique := Vector2i(_cadres[_vues.find(vue)].size.round())
	conteneur.stretch = false
	conteneur.modulate.a = 0.0
	# La visée souris est reprojetée par `_viser_a_la_souris()`.
	conteneur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vue.size_2d_override = logique
	vue.size_2d_override_stretch = true
	vue.size = taille_lightmap(_lightmap, logique, _etirement())


func _construire_3d() -> void:
	_shader = Shader.new()
	_shader.code = SHADER
	var data: Dictionary = MapData.get_selected()
	var parent_scene: Node = self
	if _scinde:
		# Deux vues 3D, un seul monde : murs et corps n'existent qu'une fois.
		var monde := World3D.new()
		for i in 2:
			var rect := _cadres[i]
			var sv := SubViewport.new()
			sv.name = "VueIso%d" % (i + 1)
			sv.own_world_3d = false
			sv.world_3d = monde
			# La 3D rend aux pixels de la fenêtre, comme la racine en vue unique :
			# seule la lightmap varie d'un relevé à l'autre.
			sv.size = Vector2i((rect.size * _etirement()).round())
			sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(sv)
			var affichage := TextureRect.new()
			affichage.name = "AffichageIso%d" % (i + 1)
			affichage.texture = sv.get_texture()
			affichage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			affichage.stretch_mode = TextureRect.STRETCH_SCALE
			affichage.mouse_filter = Control.MOUSE_FILTER_IGNORE
			affichage.position = rect.position
			affichage.size = rect.size
			add_child(affichage)
			_vues3d.append(sv)
			_affichages.append(affichage)
		parent_scene = _vues3d[0]

	var scene := Node3D.new()
	scene.name = "SceneIso"
	parent_scene.add_child(scene)

	_murs = construire_murs(data, _mur * CandelaTileSet.TILE_SIZE.y,
		_materiau(ROLE_MUR, -1 if _scinde else 0))
	scene.add_child(_murs)

	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE
	for i in _vues.size():
		var mat := _materiau(ROLE_SOL, i)
		_mat_sols.append(mat)
		var sol := MeshInstance3D.new()
		sol.name = "Sol%d" % (i + 1)
		sol.mesh = plan
		sol.material_override = mat
		sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _scinde:
			sol.layers = 2 if i == 0 else 4
		scene.add_child(sol)
		_sols.append(sol)

		var cam := Camera3D.new()
		cam.name = "CameraIso%d" % (i + 1)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.near = 1.0
		cam.far = RECUL * 3.0
		if _scinde:
			cam.cull_mask = 1 | (2 if i == 0 else 4)
			_vues3d[i].add_child(cam)
		else:
			add_child(cam)
		cam.current = true
		_cameras.append(cam)

	var cylindre := CylinderMesh.new()
	cylindre.top_radius = RAYON_CORPS_PX
	cylindre.bottom_radius = RAYON_CORPS_PX
	cylindre.height = HAUTEUR_CORPS_PX
	var nez := BoxMesh.new()
	nez.size = Vector3(6.0, 6.0, 12.0)
	for i in 2:
		var mat := _materiau(ROLE_CORPS, -1 if _scinde else 0)
		mat.set_shader_parameter("gris", Charte.ADVERSAIRE)
		_mat_corps.append(mat)
		var corps := Node3D.new()
		corps.name = "Corps%d" % (i + 1)
		for piece in [[cylindre, Vector3(0.0, HAUTEUR_CORPS_PX * 0.5, 0.0)],
				[nez, Vector3(0.0, HAUTEUR_CORPS_PX * 0.6, -(RAYON_CORPS_PX + 4.0))]]:
			var mi := MeshInstance3D.new()
			mi.mesh = piece[0]
			mi.position = piece[1]
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			corps.add_child(mi)
		scene.add_child(corps)
		_corps.append(corps)
	_suivre()


func _materiau(role: int, vue: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("role", role)
	m.set_shader_parameter("vue", vue)
	m.set_shader_parameter("pied", PIED_PX)
	m.set_shader_parameter("lumiere_1", _vues[0].get_texture())
	m.set_shader_parameter("lumiere_2", _vues[_vues.size() - 1].get_texture())
	_materiaux.append(m)
	return m


# ---------------------------------------------------------------------------
# À CHAQUE IMAGE
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _pret:
		return
	_tenir()
	if not _base and not _jeu:
		_suivre()


## Ce que le jeu peut défaire pendant la partie, reposé et compté.
func _tenir() -> void:
	if not _scinde and _main.vp2.get_parent().visible:
		_main.vp2.get_parent().hide()
		_main.ui.center_line.hide()
		_main._accorder_rendu_aux_vues()
	for j in [_main.p1, _main.p2]:
		if not is_instance_valid(j):
			continue
		j.hp = 100.0
		if not _base and not _jeu:
			_corps_recaches += _cacher_corps(j)
	if not _base and not _jeu:
		for vue in _vues:
			if vue.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
				vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				_vues_relancees += 1


func _suivre() -> void:
	for i in _vues.size():
		var vue := _vues[i]
		var canevas: Transform2D = vue.canvas_transform
		var taille_2d := Vector2(vue.size_2d_override)
		for m in _materiaux:
			m.set_shader_parameter("canevas_%d_x" % (i + 1), canevas.x)
			m.set_shader_parameter("canevas_%d_y" % (i + 1), canevas.y)
			m.set_shader_parameter("canevas_%d_o" % (i + 1), canevas.origin)
			m.set_shader_parameter("taille_%d" % (i + 1), taille_2d)
		var rect := rect_couvert(canevas, taille_2d)
		_sols[i].position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		_sols[i].scale = Vector3(rect.size.x, 1.0, rect.size.y)
		var centre := canevas.affine_inverse() * (taille_2d * 0.5)
		_poser_camera(_cameras[i], centre, taille_2d.y)
	var joueurs := [_main.p1, _main.p2]
	for i in 2:
		var j = joueurs[i]
		if not is_instance_valid(j):
			_corps[i].visible = false
			continue
		# Lu, jamais écrit : c'est l'état de mort que le rejeu enregistre.
		_corps[i].visible = j.visual.visible
		var p: Vector2 = j.global_position
		_corps[i].position = Vector3(p.x, 0.0, p.y)
		_corps[i].basis = Basis.looking_at(Vector3(cos(j.rotation), 0.0, sin(j.rotation)), Vector3.UP)
		_mat_corps[i].set_shader_parameter("pied_corps", p)


func _poser_camera(cam: Camera3D, centre_px: Vector2, hauteur_vue: float) -> void:
	# Ordre d'Euler YXZ : on incline (X), puis on tourne autour de la verticale
	# (Y). Pas de `look_at`, qui perd son « haut » à 90°.
	cam.rotation_degrees = Vector3(-_tangage, _lacet, 0.0)
	cam.size = taille_orthographique(_tangage, hauteur_vue)
	cam.position = Vector3(centre_px.x, 0.0, centre_px.y) + cam.basis.z * RECUL


func _cacher_corps(joueur: Node) -> int:
	if not is_instance_valid(joueur):
		return 0
	var n := 0
	for nom in APPUIS_JOUEUR:
		var noeud := joueur.get(nom) as CanvasItem
		if noeud != null and noeud.visibility_layer != COUCHE_HORS_VUE:
			noeud.visibility_layer = COUCHE_HORS_VUE
			n += 1
	return n


# ---------------------------------------------------------------------------
# ENTRÉES — réglages à chaud et visée souris
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _pret or _base or _jeu:
		return
	var touche := event as InputEventKey
	if touche != null and touche.pressed and not touche.echo:
		match touche.physical_keycode:
			KEY_F8:
				_tangage = _suivant(TANGAGES, _tangage)
			KEY_F9:
				_lacet = _suivant(LACETS, _lacet)
			KEY_F10:
				_mur = _suivant(MURS, _mur)
				var h := _mur * CandelaTileSet.TILE_SIZE.y
				for boite in _murs.get_children():
					(boite as Node3D).scale.y = h
					(boite as Node3D).position.y = h * 0.5
			_:
				return
		get_viewport().set_input_as_handled()
		print("[banc_iso] tangage %s°, lacet %s°, murs %s tuile — size %.1f, empreinte au sol %s"
			% [str(_tangage), str(_lacet), str(_mur), taille_orthographique(_tangage),
			str(empreinte_au_sol(_tangage, Vector2(_vues[0].size_2d_override)).round())])
		return
	var souris := event as InputEventMouseMotion
	if souris != null:
		_viser_a_la_souris(souris)


## La souris vise le point du SOL sous le curseur, et non le point de l'écran.
##
## `LocalInputProvider` lit `get_mouse_position()` de la vue de J1 et la ramène
## au monde par la transformation de canevas. On lui pousse donc, en coordonnées
## locales de sa vue, l'image par cette transformation du point où le rayon de
## la caméra 3D coupe le sol : la visée reste juste à tout tangage et à 45°.
func _viser_a_la_souris(souris: InputEventMouseMotion) -> void:
	var pos := souris.position
	if _scinde:
		var cadre := _affichages[0].get_global_rect()
		if not cadre.has_point(pos):
			return
		pos = (pos - cadre.position) * (Vector2(_vues3d[0].size) / cadre.size)
	var cam := _cameras[0]
	var origine := cam.project_ray_origin(pos)
	var direction := cam.project_ray_normal(pos)
	if absf(direction.y) < 1e-5:
		return
	var sol := origine + direction * (-origine.y / direction.y)
	var poussee := souris.duplicate() as InputEventMouseMotion
	poussee.position = _main.vp1.canvas_transform * Vector2(sol.x, sol.z)
	poussee.global_position = poussee.position
	_main.vp1.push_input(poussee, true)


func _suivant(valeurs: Array, courante: float) -> float:
	var i := valeurs.find(courante)
	return float(valeurs[(i + 1) % valeurs.size()])


# ---------------------------------------------------------------------------
# PARTIE, MESURE, RAPPORT
# ---------------------------------------------------------------------------

func _jouer(duree: float, echantillonner: bool) -> void:
	var ecoule := 0.0
	while ecoule < duree:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		ecoule += dt
		if _charge:
			_charger()
		if echantillonner and dt > 0.0:
			_samples.append(dt)
			_appels.append(int(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
			if not get_window().has_focus():
				_images_hors_focus += 1
			if not _main.round_active:
				_images_hors_manche += 1


## La charge de `bench_framerate.gd`, recopiée : un échange au pompe à bout
## portant, torches allumées. Sert aux relevés comparables ; sans `--charge`, ce
## sont les joueurs qui jouent.
func _charger() -> void:
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		return
	p2.global_position = p1.global_position + Vector2(BancCadence.DUEL_DISTANCE, 0.0)
	_tenir_les_torches()
	for p in [p1, p2]:
		if p.shoot_cooldown <= 0.0:
			p.shoot()
	p1.rotation = (p2.global_position - p1.global_position).angle()
	p2.rotation = (p1.global_position - p2.global_position).angle()


func _conditions() -> void:
	var fenetre := DisplayServer.window_get_size()
	var aire := get_viewport().get_visible_rect().size
	print("Fenêtre       : %d×%d pixels natifs (%.2f Mpx), aire 2D %.0f×%.0f, étirement ×%.2f"
		% [fenetre.x, fenetre.y, fenetre.x * fenetre.y / 1e6, aire.x, aire.y, _etirement()])
	for vue in [_main.vp1, _main.vp2]:
		var actif: bool = vue.render_target_update_mode != SubViewport.UPDATE_DISABLED
		var monde_2d := "" if vue.size_2d_override == Vector2i.ZERO \
			else ", monde 2D %d×%d" % [vue.size_2d_override.x, vue.size_2d_override.y]
		print("  %-12s: cible 2D %d×%d%s%s" % [vue.name, vue.size.x, vue.size.y, monde_2d,
			"" if actif else "  (ARRÊTÉE)"])
	if _base:
		if _main._rendu_racine:
			print("  %-12s: le duel est rendu par la RACINE (chantier R)" % "Racine")
		return
	if _jeu:
		var p := Presentation3D.instance()
		print("  %-12s: cible 3D %d×%d (la fenêtre)" % ["Racine", fenetre.x, fenetre.y])
		print("Jeu           : Presentation3D — %s" % (p.etat if p != null else "ABSENTE"))
		print("Murs          : %s tuile (%s)" % [str(_mur if _mur_donne else IsoGeometrie.hauteur_mur_haut()),
			"retaillés par le banc" if _mur_donne else IsoGeometrie.source_des_hauteurs()])
		return
	if _scinde:
		for sv in _vues3d:
			print("  %-12s: cible 3D %d×%d" % [sv.name, sv.size.x, sv.size.y])
	else:
		print("  %-12s: cible 3D %d×%d (la fenêtre)" % ["Racine", fenetre.x, fenetre.y])
	var empreinte := empreinte_au_sol(_tangage, Vector2(_vues[0].size_2d_override))
	print("Caméra        : orthographique, tangage %s°, lacet %s°, size %.1f px"
		% [str(_tangage), str(_lacet), taille_orthographique(_tangage)])
	# ⚠️ `size = 1080 × sin θ` garde la PROFONDEUR de la vue de dessus, pas sa
	# largeur : la largeur au sol est `largeur × sin θ`. Imprimé pour que personne
	# ne compare deux tangages en croyant comparer deux champs égaux.
	print("Empreinte     : %.0f×%.0f px de monde au sol (vue de dessus : %d×%d)"
		% [empreinte.x, empreinte.y, _vues[0].size_2d_override.x, _vues[0].size_2d_override.y])
	print("Murs          : %d boîtes, %s tuile ; sol : %d plan(s) ; corps : 2"
		% [_murs.get_child_count(), str(_mur), _sols.size()])


func _report() -> void:
	if _samples.is_empty():
		printerr("✗ aucun échantillon")
		return
	# **L'état du focus AVANT les chiffres.** Placé après, l'avertissement arrive
	# quand on a déjà lu le résultat qu'il invalide (leçon du 2026-08-26).
	print("\n=== RÉSULTAT (%s) ===" % _libelle())
	var n := _samples.size()
	if _images_hors_focus == 0:
		print("  Focus            : stable au premier plan — relevé comparable")
	elif _images_hors_focus == n:
		print("  Focus            : stable au SECOND PLAN — c'est un plancher, pas une mesure")
	else:
		print("  ⚠ FOCUS MIXTE : %d image(s) sur %d dans l'autre état — **RELEVÉ À JETER**"
			% [mini(_images_hors_focus, n - _images_hors_focus), n])
	if _images_hors_manche > 0:
		print("  ⚠ %d image(s) mesurées hors manche (fin de manche pendant la mesure)"
			% _images_hors_manche)
	var stats := ConditionsDeMatch.statistiques(PackedFloat32Array(_samples))
	print("  Images mesurées  : %d en %.1f s" % [stats["images"], stats["duree_s"]])
	print("  FPS médian       : %.0f" % stats["fps_median"])
	print("  FPS 1 %% bas      : %.0f" % stats["fps_1pc_bas"])
	print("  Image la plus lente : %.1f ms" % stats["pire_image_ms"])
	print("  Appels de dessin : %d (médiane par image)" % _mediane(_appels))
	print("  Cible 1 %% bas ≥ %.0f : %s" % [BancCadence.CIBLE_1_POURCENT_BAS,
		"tenue" if stats["fps_1pc_bas"] >= BancCadence.CIBLE_1_POURCENT_BAS else "NON TENUE"])
	if _jeu:
		var p := Presentation3D.instance()
		if p != null:
			print("  Reposés en jeu   : %d nœud(s) de corps, %d vue(s) relancée(s) (Presentation3D)"
				% [p.corps_recaches, p.vues_relancees])
	elif not _base:
		print("  Reposés en jeu   : %d nœud(s) de corps, %d vue(s) relancée(s)"
			% [_corps_recaches, _vues_relancees])
	# Une ligne à recopier dans un tableau, tous réglages compris.
	print("BANC_ISO mode=%s vue=%s lightmap=%s tangage=%s lacet=%s mur=%s charge=%s carte=%s "
		% ["base" if _base else ("jeu-" + _pate_nommee().left(1) if _jeu else "iso"), "scinde" if _scinde else "unique",
		"-" if _base else _lightmap, str(_tangage), str(_lacet), str(_mur), str(_charge),
		MapData.get_selected().get("name", "?")]
		+ "median=%.0f bas1=%.0f pire_ms=%.1f appels=%d focus=%s" % [stats["fps_median"],
		stats["fps_1pc_bas"], stats["pire_image_ms"], _mediane(_appels),
		"premier" if _images_hors_focus == 0 else ("second" if _images_hors_focus == n else "MIXTE")])


## Une image pour les planches : les deux torches braquées côte à côte sur le mur
## le plus proche, puis la capture — avec, sur `--flash`, un tir de J1 juste avant.
##
## ⚠️ **Côte à côte, et hors du cône l'un de l'autre.** L'éblouissement ne
## regarde pas où la victime regarde, seulement si elle est dans le faisceau
## (`eblouissement.gd`) : face à face, ou J2 dans le faisceau de J1, et le voile
## de J2 couvre sa moitié d'écran — que l'interface garde en vue unique, le mode
## restant « écrans scindés ». Les deux premières captures du 2026-09-14 ne
## montraient que lui.
##
## ⚠️ **Le tir secoue la caméra** (`cam1.offset`, ±15 px aléatoires plus le recul) :
## sans `--flash`, deux captures du même réglage se superposent au pixel, et c'est
## ce qui permet de comparer l'iso à 90° avec `--base`.
func _capturer() -> void:
	if _noir:
		await _capturer_le_noir()
		return
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var cible := _mur_le_plus_proche(p1.global_position)
	var axe := (cible - p1.global_position).normalized()
	p2.global_position = p1.global_position + axe.orthogonal() * 70.0
	_tenir_les_torches()
	for i in 90:
		for p in [p1, p2]:
			p.rotation = axe.angle()
		await get_tree().process_frame
	if _flash:
		p1.shoot()
		await get_tree().process_frame
	var image: Image = await RenduCommun.capturer(get_tree(), 15000)
	if image == null:
		printerr("✗ aucune image rendue en 15 s")
		_sortir(4)
		return
	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	if image.save_png(_capture) != OK:
		printerr("✗ écriture impossible : ", _capture)
		_sortir(5)
		return
	print("BANC_ISO capture %s %d×%d" % [_capture, image.get_width(), image.get_height()])
	# La lightmap de chaque vue, lue à la même image : comparer l'écran à sa propre
	# lightmap isole la projection 3D de tout le reste.
	for i in _vues.size():
		var lumiere := _vues[i].get_texture().get_image()
		var chemin := _capture.get_basename() + "_lightmap%d.png" % (i + 1)
		if lumiere != null and lumiere.save_png(chemin) == OK:
			print("BANC_ISO lightmap %s %d×%d" % [chemin, lumiere.get_width(), lumiere.get_height()])
	_sortir(0)


## Les deux torches allumées par leur BOUTON, le premier cran tenu.
##
## ⚠️ **Écrire `flashlight_on` ne suffit pas** : `player.gd` le relit dans
## `input_provider.is_flashlight_pressed()` à chaque pas de physique (« la torche
## n'obéit qu'au bouton »). La première mise en scène du 2026-09-14 l'écrivait à
## chaque image, et les captures sont sorties torches éteintes. Tenir l'action,
## c'est passer par le chemin qu'un joueur emprunte.
func _tenir_les_torches() -> void:
	for action in ["p1_torch", "p2_torch"]:
		if InputMap.has_action(action) and not Input.is_action_pressed(action):
			Input.action_press(action, 0.5)


## Le point de mur le plus proche de `depuis`, à plus de quatre tuiles : assez
## loin pour que le faisceau s'ouvre avant d'y arriver, assez près pour l'atteindre.
func _mur_le_plus_proche(depuis: Vector2) -> Vector2:
	var meilleur := depuis + Vector2(300.0, 0.0)
	var distance := INF
	for r in rects_murs_px(MapData.get_selected()):
		var point := depuis.clamp(r.position, r.end)
		var d := depuis.distance_to(point)
		if d >= 140.0 and d < distance:
			distance = d
			meilleur = point
	return meilleur


# ---------------------------------------------------------------------------
# --jeu : LA VUE DU JEU, ET LE NOIR ABSOLU
# ---------------------------------------------------------------------------

## Le banc ne construit rien : il attend que le JEU ait allumé sa vue iso, et le dit.
## Une variante doit prouver qu'elle a changé quelque chose (leçon du 2026-08-18).
func _attendre_la_presentation() -> bool:
	_vues.assign([_main.vp1])
	var allumee := await _attendre(func() -> bool:
		var p := Presentation3D.instance()
		return p != null and bool(p.get("_actif")), 5.0)
	if not allumee:
		printerr("✗ --jeu : la vue isométrique du jeu ne s'est pas allumée "
			+ "(GameSettings.mode_iso, crochet de rebuild_arena, vue unique ?)")
		return false
	if _mur_donne:
		var murs := Presentation3D.instance().get_node_or_null("SceneIso/Murs")
		var h := _mur * CandelaTileSet.TILE_SIZE.y
		for boite in murs.get_children():
			(boite as Node3D).scale.y = h
			(boite as Node3D).position.y = h * 0.5
	if _sans_hud or _noir:
		_ui.visible = false
	var couches := 0
	for nom in Presentation3D.APPUIS_JOUEUR:
		if (_main.p1.get(nom) as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE:
			couches += 1
	print("JEU : Presentation3D allumée — %s ; %d/10 sprites de J1 retirés ; racine autorisée=%s"
		% [Presentation3D.instance().etat, couches, str(_main.rendu_racine_autorise)])
	return true


func _pate_nommee() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--pate")
	return args[i + 1].to_upper() if i >= 0 and i + 1 < args.size() else "A"


## Le contrôle du noir absolu — deux mesures dans la même exécution, HUD retiré.
##
## **(a) Toutes les lumières éteintes** — le scénario du jeu. Éteintes par `enabled`, à
## chaque image pendant une demi-seconde : une balle née entre temps apporte la sienne.
## ⚠️ **Le jeu de dessus n'est pas noir dans ce cas, et ce n'est pas l'iso** (mesuré le
## 2026-09-14) : le viseur du joueur et le liseré des murs peignent sans lumière, dans la
## lightmap elle-même. Ce qui revient à l'iso se juge donc ici contre SA SOURCE : la même
## image est reprise en pâte brute (la lightmap projetée, sans rien), et **aucun pixel ne
## doit s'allumer hors de ce que la brute allume** (tolérance de 2 px pour le filtrage).
## ⚠️ Pas « l'écran ≤ la lightmap » : B, C et D normalisent leurs tons, un demi-ton y
## ressort plus clair — c'est un choix de style à juger (il rehausse ce qui est déjà
## éclairé), pas une lumière née dans le noir. En `--base`, la mesure donne le résidu
## de la vue de dessus, pour comparer.
##
## **(b) Lightmap noire** — l'invariant propre à la projection et à la pâte : la vue 2D ne
## dessine plus rien (`canvas_cull_mask = 0`), et l'écran doit valoir 0 PARTOUT. C'est
## ce que « strictement 0 à lumière 0 » veut dire au pixel, sans rien cacher du jeu.
func _capturer_le_noir() -> void:
	var eteintes := 0
	for i in 30:
		eteintes = _eteindre_les_lumieres(get_tree().root)
		await get_tree().process_frame
	var image_a: Image = await RenduCommun.capturer(get_tree(), 15000)
	if image_a == null:
		printerr("✗ aucune image rendue en 15 s")
		_sortir(4)
		return
	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	image_a.save_png(_capture)
	var max_a := _valeur_max(image_a)
	var vue: SubViewport = _main.vp1
	var lumiere_a := vue.get_texture().get_image()
	var max_lightmap_a := _valeur_max(lumiere_a)
	if lumiere_a != null and not _base:
		lumiere_a.save_png(_capture.get_basename() + "_lightmap1.png")
	var rendu := "base" if _base else "jeu-" + _pate_nommee()
	if _base:
		print("BANC_ISO noir-a rendu=%s max_ecran=%d/255 lumieres_eteintes=%d image=%s"
			% [rendu, max_a, eteintes, _capture])
		_sortir(0)
		return
	var presentation := Presentation3D.instance()
	var style: int = presentation.style_pate
	presentation.style_pate = -1
	for i in 10:
		_eteindre_les_lumieres(get_tree().root)
		await get_tree().process_frame
	var brute: Image = await RenduCommun.capturer(get_tree(), 15000)
	presentation.style_pate = style
	if brute != null:
		brute.save_png(_capture.get_basename() + "_brute.png")
	var hors_support := _allumes_hors_du_support(image_a, brute)
	print("BANC_ISO noir-a rendu=%s max_ecran=%d/255 max_brute=%d/255 max_lightmap=%d/255 allumes_hors_support=%d lumieres_eteintes=%d image=%s"
		% [rendu, max_a, _valeur_max(brute), max_lightmap_a, hors_support, eteintes, _capture])

	var masque := vue.canvas_cull_mask
	vue.canvas_cull_mask = 0
	for i in 20:
		_eteindre_les_lumieres(get_tree().root)
		await get_tree().process_frame
	var image_b: Image = await RenduCommun.capturer(get_tree(), 15000)
	var lumiere_b := vue.get_texture().get_image()
	vue.canvas_cull_mask = masque
	var chemin_b := _capture.get_basename() + "_lightmap_noire.png"
	if image_b != null:
		image_b.save_png(chemin_b)
	var max_b := _valeur_max(image_b)
	var max_lightmap_b := _valeur_max(lumiere_b)
	var tenu := max_b == 0 and max_lightmap_b == 0 and hors_support == 0
	print("BANC_ISO noir-b rendu=%s max_ecran=%d/255 max_lightmap=%d/255 image=%s"
		% [rendu, max_b, max_lightmap_b, chemin_b])
	print("BANC_ISO noir pate=%s verdict=%s (a : %d pixel(s) allumé(s) hors du support de la brute, écran max %d ; b : écran %d sur lightmap %d)"
		% [_pate_nommee(), "NOIR ABSOLU TENU" if tenu else "NOIR ABSOLU ROMPU", hors_support, max_a,
		max_b, max_lightmap_b])
	_sortir(0 if tenu else 6)


## Pixels allumés dans `image` là où `reference` est noire sur tout un voisinage 5×5.
## Rapide dans le noir : seuls les pixels allumés sont examinés.
static func _allumes_hors_du_support(image: Image, reference: Image) -> int:
	if image == null or reference == null or image.get_size() != reference.get_size():
		return -1
	var a := image.duplicate() as Image
	var r := reference.duplicate() as Image
	a.convert(Image.FORMAT_RGB8)
	r.convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var dr := r.get_data()
	var w := a.get_width()
	var h := a.get_height()
	var n := 0
	for i in range(0, da.size(), 3):
		if da[i] == 0 and da[i + 1] == 0 and da[i + 2] == 0:
			continue
		var p := i / 3
		var px := p % w
		var py := p / w
		var trouve := false
		for oy in range(maxi(0, py - 2), mini(h, py + 3)):
			for ox in range(maxi(0, px - 2), mini(w, px + 3)):
				var j := (oy * w + ox) * 3
				if dr[j] != 0 or dr[j + 1] != 0 or dr[j + 2] != 0:
					trouve = true
					break
			if trouve:
				break
		if not trouve:
			n += 1
	return n


func _eteindre_les_lumieres(noeud: Node) -> int:
	var n := 0
	if noeud is Light2D:
		(noeud as Light2D).enabled = false
		n += 1
	for enfant in noeud.get_children():
		n += _eteindre_les_lumieres(enfant)
	return n


## La valeur de canal la plus haute (0-255), alpha exclu — par la comparaison du moteur
## avec une image noire, et non par une boucle sur onze millions d'octets.
static func _valeur_max(image: Image) -> int:
	if image == null:
		return -1
	var rgb := image.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var noire := Image.create(rgb.get_width(), rgb.get_height(), false, Image.FORMAT_RGB8)
	noire.fill(Color.BLACK)
	return int(round(float(rgb.compute_image_metrics(noire, false)["max"])))


# ---------------------------------------------------------------------------
# CE QUE LA SUITE INTERROGE — statique, sans fenêtre
# ---------------------------------------------------------------------------

## Les appuis du banc sur le jeu. Ceux du banc de cadence d'abord — il lance le
## duel par le même chemin —, puis ceux que la projection ajoute.
static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = BancCadence.preconditions_manquantes(ui, main)
	if ui == null or main == null:
		return absents
	for prop in ["rendu_racine_autorise", "_rendu_racine", "vp1", "vp2", "ui", "countdown_left"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	if not main.has_method("_accorder_rendu_aux_vues"):
		absents.append("GameState._accorder_rendu_aux_vues() a disparu")
	if not "center_line" in ui:
		absents.append("UI.center_line a disparu")
	if main.get_node_or_null("Background") == null:
		absents.append("main.tscn n'a plus de Background")
	for chemin in [CHEMIN_VUE_1, CHEMIN_VUE_2]:
		var vue := main.get_node_or_null(chemin) as SubViewport
		if vue == null:
			absents.append("%s a disparu" % chemin)
			continue
		if not vue.get_parent() is SubViewportContainer:
			absents.append("%s n'est plus dans un SubViewportContainer" % chemin)
		if not couche_absente_du_masque(vue.canvas_cull_mask):
			absents.append("le masque de %s lit la couche où le banc cache les corps" % vue.name)
	return absents


## Les nœuds de corps que le banc déplace, présents sur ce joueur ?
static func appuis_joueur_manquants(joueur: Object) -> Array[String]:
	var absents: Array[String] = []
	if joueur == null:
		absents.append("aucun joueur")
		return absents
	for nom in APPUIS_JOUEUR:
		if not nom in joueur:
			absents.append("Player.%s a disparu" % nom)
	return absents


static func couche_absente_du_masque(masque: int, couche: int = COUCHE_HORS_VUE) -> bool:
	return (masque & couche) == 0


## `Camera3D.size` (hauteur de vue) qui garde, au sol, la profondeur d'une vue de
## dessus de `hauteur_vue` pixels : le sol se voit raccourci de sin θ.
static func taille_orthographique(tangage_deg: float, hauteur_vue: float = HAUTEUR_VUE) -> float:
	return hauteur_vue * sin(deg_to_rad(tangage_deg))


## Le rectangle de monde visible au sol, lacet nul, pour une vue logique donnée.
## La hauteur est gardée ; la largeur ne l'est pas — c'est le constat du banc.
static func empreinte_au_sol(tangage_deg: float, vue: Vector2) -> Vector2:
	var taille := taille_orthographique(tangage_deg, vue.y)
	return Vector2(taille * vue.x / vue.y, taille / sin(deg_to_rad(tangage_deg)))


static func taille_lightmap(variante: String, logique: Vector2i, etirement: float) -> Vector2i:
	match variante:
		"plein":
			return Vector2i((Vector2(logique) * etirement).round())
		"1080p":
			return logique
		"demi":
			return Vector2i((Vector2(logique) * 0.5).round())
	return Vector2i.ZERO


## Le rectangle de monde (boîte englobante) que couvre une vue 2D de `taille_2d`
## sous la transformation de canevas `canevas`.
static func rect_couvert(canevas: Transform2D, taille_2d: Vector2) -> Rect2:
	var inverse := canevas.affine_inverse()
	var r := Rect2(inverse * Vector2.ZERO, Vector2.ZERO)
	for coin in [Vector2(taille_2d.x, 0.0), Vector2(0.0, taille_2d.y), taille_2d]:
		r = r.expand(inverse * coin)
	return r


## Point du monde → uv de la lightmap. **La même formule que `lire()` dans
## `SHADER`** : colonnes x, y et origine de la transformation, divisées par la
## taille 2D. Le GPU, lui, se vérifie à l'image.
static func uv_de(canevas: Transform2D, taille_2d: Vector2, point: Vector2) -> Vector2:
	return (canevas.x * point.x + canevas.y * point.y + canevas.origin) / taille_2d


## Les rectangles de murs en pixels du monde 2D : `merge_rects` de la carte, par
## le prototype, la bordure retirée.
static func rects_murs_px(data: Dictionary) -> Array[Rect2]:
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var out: Array[Rect2] = []
	for r in (ProtoIso.rectangles_de(data)["murs"] as Array):
		var m: Rect2 = ProtoIso.rect_vers_monde(r)
		out.append(Rect2(m.position * tuile, m.size * tuile))
	return out


## Une boîte par rectangle de mur, un seul cube unitaire mis à l'échelle
## (patron `_boite()` du prototype), de 0 à `hauteur_px`.
static func construire_murs(data: Dictionary, hauteur_px: float, materiau: Material) -> Node3D:
	var murs := Node3D.new()
	murs.name = "Murs"
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var rects := rects_murs_px(data)
	for i in rects.size():
		var r := rects[i]
		var boite := MeshInstance3D.new()
		boite.name = "Mur%d" % i
		boite.mesh = cube
		boite.material_override = materiau
		boite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		boite.scale = Vector3(r.size.x, hauteur_px, r.size.y)
		boite.position = Vector3(r.get_center().x, hauteur_px * 0.5, r.get_center().y)
		murs.add_child(boite)
	return murs


# ---------------------------------------------------------------------------
# RECOPIÉ DE bench_framerate.gd (privé là-bas, et ce fichier n'est pas le mien)
# ---------------------------------------------------------------------------

func _etirement() -> float:
	var aire := get_viewport().get_visible_rect().size
	return float(DisplayServer.window_get_size().y) / aire.y if aire.y > 0.0 else 1.0


## Sortir par la porte du jeu : le banc instancie `main.tscn`, donc les autoloads
## EOS, et un `quit()` sec ré-entre dans `EOS_Platform_Tick()` (signal 11).
func _sortir(code: int) -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
		return
	get_tree().quit(code)


func _reclamer_le_premier_plan() -> void:
	DisplayServer.window_move_to_foreground()
	get_window().grab_focus()


func _couper_le_son(quand: String) -> void:
	var maitre := AudioServer.get_bus_index("Master")
	if maitre < 0:
		printerr("  ⚠ bus Master introuvable — le son n'a PAS pu être coupé")
		return
	AudioServer.set_bus_mute(maitre, true)
	AudioServer.set_bus_volume_db(maitre, -80.0)
	print("  son coupé (%s) : muet=%s" % [quand, AudioServer.is_bus_mute(maitre)])


func _select_shotgun(group: ButtonGroup) -> void:
	var buttons: Array = group.get_buttons()
	if BancCadence.SHOTGUN_INDEX < buttons.size():
		buttons[BancCadence.SHOTGUN_INDEX].button_pressed = true


func _attendre(predicat: Callable, delai: float) -> bool:
	var attendu := 0.0
	while not predicat.call():
		if attendu >= delai:
			return false
		await get_tree().create_timer(0.25).timeout
		attendu += 0.25
	return true


func _value(args: PackedStringArray, flag: String, fallback: String) -> String:
	var idx := args.find(flag)
	if idx < 0 or idx + 1 >= args.size():
		return fallback
	return args[idx + 1]


static func _mediane(valeurs: Array[int]) -> int:
	if valeurs.is_empty():
		return 0
	var tri := valeurs.duplicate()
	tri.sort()
	return tri[tri.size() / 2]
