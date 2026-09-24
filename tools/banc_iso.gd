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
const IsoPate_ := preload("res://iso_pate.gd")

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
## Quelles torches une capture allume : `toutes`, `j1`, `j2` ou `aucune`. La planche
## d'ISO2 se fait à torche de J1 seule puis de J2 seule — on doit y voir que chaque vue
## n'a que sa lumière.
## `eblouir` : J1 braque sa torche sur J2, qui a la sienne éteinte et regarde J1 — pour
## comparer l'éblouissement de J2 dans sa propre vue, en vue de dessus et en iso.
const TORCHES := ["toutes", "j1", "j2", "aucune", "eblouir"]
var _torches := "toutes"
## Pendant le contrôle du noir : les lumières s'éteignent à chaque image.
var _noir_en_cours := false
## `--canaux` : le contrôle des canaux des capteurs (voir `_controler_les_canaux`).
var _canaux := false
## ISO14 — `--lacet-identique` : les capteurs des corps et l'éblouissement lisent les mêmes valeurs à 0° et à 45°,
## pour les deux joueurs et les trois options (voir `_controler_le_lacet`). Avec `--jeu --scinde --capture`.
var _lacet_identique := false
## `--effacement` : le contrôle du fondu des corps iso (ISO2b, voir `_controler_l_effacement`).
var _effacement := false
## ISO4 — `--objets` : un objet voxel posé devant un corps ne lui cache ni la tête ni le torse (voir
## `_controler_les_objets`). Avec `--jeu --scinde --torches j2 --capture`.
var _objets := false
## ISO5 — `--killcam` : une killcam complète en iso, par `_do_end_round` (voir `_controler_la_killcam`).
## Avec `--jeu --scinde --capture` ; `--vue j2` la regarde par la vue de J2 (la configuration du client).
var _killcam := false
var _vue_killcam := "j1"
## ISO2b — les opacités des sprites AU RENDU, relevées sur `RenderingServer.frame_pre_draw`, après
## tous les traitements de l'image : `player.gd` écrit l'opacité du sprite ennemi dans
## `_physics_process` (brouillage) ET dans `_process` (suie), et un relevé pris ailleurs — après une
## capture, par exemple — peut lire l'autre valeur que celle qui a été dessinée.
var _opacites_au_rendu := {}
## Les lumières que le jeu avait rallumées depuis l'image précédente — nommées au relevé.
var _rallumees: PackedStringArray = []

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
	if _noir and (_capture == "" or not (_jeu or _base) or (_scinde and not _jeu)):
		printerr("✗ banc_iso : --noir se prend avec --capture, et --jeu (vue unique ou --scinde) ou --base (vue unique)")
		_sortir(2)
		return
	if _effacement and (_capture == "" or not (_jeu or (_base and _scinde))):
		printerr("✗ banc_iso : --effacement se prend avec --capture, et --jeu ou --base --scinde (et --torches j2 : J2 éclairé chez J1)")
		_sortir(2)
		return
	if _canaux and (_capture == "" or not _jeu):
		printerr("✗ banc_iso : --canaux se prend avec --capture et --jeu (vue unique ou --scinde)")
		_sortir(2)
		return
	if _lacet_identique and (_capture == "" or not _jeu or not _scinde):
		printerr("✗ banc_iso : --lacet-identique se prend avec --capture, --jeu et --scinde")
		_sortir(2)
		return
	if _killcam and (_capture == "" or not _jeu or not ["j1", "j2"].has(_vue_killcam)):
		printerr("✗ banc_iso : --killcam se prend avec --capture et --jeu (--vue j1 | j2)")
		_sortir(2)
		return
	if _jeu and _lightmap == "demi":
		printerr("✗ banc_iso : le jeu ne connaît que les lightmaps plein et 1080p (--lightmap est lu par GameSettings)")
		_sortir(2)
		return
	GameSettings.pilotage_externe = true
	# Pour cette exécution seulement : `mode_iso` n'est pas `set_vue_de_dessus()`, rien ne s'écrit
	# dans settings.cfg. ISO6 : posé dans les DEUX sens — l'iso étant le défaut, le banc `--base`
	# mesurerait sinon l'iso sous le nom de la vue de dessus.
	GameSettings.mode_iso = _jeu
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
		# La classe du banc de cadence, par son index de catalogue (`BancCadence.CLASSE_PAR_DEFAUT`, le pompe) : la place 2 du
		# râtelier était le fusil depuis que la liste suit le rang d'affichage (ISO12, 2026-09-23).
		var idx_classe := BancCadence.index_de_classe(_main, BancCadence.CLASSE_PAR_DEFAUT)
		_ui.set_weapon_selection(0, idx_classe)
		_ui.set_weapon_selection(1, idx_classe)
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
	RenderingServer.frame_pre_draw.connect(_relever_les_opacites)
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
	_torches = _value(args, "--torches", "toutes")
	if not TORCHES.has(_torches):
		printerr("✗ --torches attend %s (reçu « %s »)" % [" | ".join(TORCHES), _torches])
		return false
	_jeu = args.has("--jeu")
	_noir = args.has("--noir")
	_canaux = args.has("--canaux")
	_lacet_identique = args.has("--lacet-identique")
	_effacement = args.has("--effacement")
	_objets = args.has("--objets")
	_killcam = args.has("--killcam")
	_vue_killcam = _value(args, "--vue", "j1")
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
		return "JEU (Presentation3D), %s, lightmap %s, tangage %s°, murs %s tuile, pâte %s%s" % [vue,
			GameSettings.iso_lightmap, str(CameraIso.TANGAGE_DEG),
			str(_mur if _mur_donne else IsoGeometrie.hauteur_mur_haut()),
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
	# Le contrôle du noir éteint les lumières À CHAQUE IMAGE jusqu'à sa dernière capture : le
	# jeu en rallume au pas de physique (le capteur d'un corps, en « lumière seule », valait
	# 31/255 en vue unique et 58 en scindé quand le banc ne les éteignait que trente images
	# avant de capturer). Ce `_process` passe après la physique et avant le rendu.
	if _noir_en_cours:
		_rallumees = _eteindre_et_nommer(get_tree().root)
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
		if _scinde and p != null:
			for sv in p.get("_vues3d"):
				print("  %-12s: cible 3D %d×%d" % [(sv as SubViewport).name, (sv as SubViewport).size.x, (sv as SubViewport).size.y])
		else:
			print("  %-12s: cible 3D %d×%d (la fenêtre)" % ["Racine", fenetre.x, fenetre.y])
		var capteurs := 0
		if p != null:
			for id in 2:
				for j in 2:
					if p.capteurs()[id][j] != null:
						capteurs += 1
		print("  %-12s: %d × %d×%d" % ["Capteurs", capteurs, CapteurCorps.TAILLE, CapteurCorps.TAILLE])
		print("Jeu           : Presentation3D — %s" % (p.etat.replace("\n", " | ") if p != null else "ABSENTE"))
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
			print("  Reposés en jeu   : %d nœud(s) de corps, %d lightmap(s), %d masque(s) ; %d bascule(s) de vues (Presentation3D)"
				% [p.corps_recaches, p.lightmaps_reposees, p.masques_reposes, p.bascules])
	elif not _base:
		print("  Reposés en jeu   : %d nœud(s) de corps, %d vue(s) relancée(s)"
			% [_corps_recaches, _vues_relancees])
	# Une ligne à recopier dans un tableau, tous réglages compris.
	print("BANC_ISO mode=%s vue=%s lightmap=%s tangage=%s lacet=%s mur=%s charge=%s carte=%s "
		% ["base" if _base else ("jeu-" + _pate_nommee().left(1) if _jeu else "iso"), "scinde" if _scinde else "unique",
		"-" if _base else (GameSettings.iso_lightmap if _jeu else _lightmap),
		# En --jeu, ce sont les valeurs du JEU qui sont rendues, pas les défauts du banc :
		# la première série d'ISO1 (2026-09-14) imprimait 60° et 0,45 pour une vue à 52° et 0,65.
		str(CameraIso.TANGAGE_DEG) if _jeu else str(_tangage),
		str(CameraIso.LACET_DEG) if _jeu else str(_lacet),
		str(_mur if _mur_donne else IsoGeometrie.hauteur_mur_haut()) if _jeu else str(_mur), str(_charge),
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
	if _killcam:
		await _controler_la_killcam()
		return
	if _noir:
		await _capturer_le_noir()
		return
	if _canaux:
		await _controler_les_canaux()
		return
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var cible := _mur_le_plus_proche(p1.global_position)
	var axe := (cible - p1.global_position).normalized()
	p2.global_position = p1.global_position + axe.orthogonal() * 70.0
	if _torches in ["j1", "j2"]:
		# ISO2 — la planche des canaux. Les deux joueurs à mi-chemin du mur et écartés de
		# 110 px, torches vers le mur : chaque vue montre l'autre joueur, et aucun n'est dans
		# le cône de l'autre (sans quoi le voile d'éblouissement couvrirait sa moitié). Ce qui
		# doit se lire : le halo de proximité de chaque joueur dans SA vue seulement ; le
		# faisceau, lui, éclaire le sol des deux vues — règle du jeu, conservée par l'iso.
		var avance := minf(p1.global_position.distance_to(cible) * 0.5, 150.0)
		p2.global_position = p1.global_position + axe * avance + axe.orthogonal() * 110.0
	if _torches == "eblouir":
		# J2 dans l'axe du faisceau de J1, à mi-chemin du mur, face à J1.
		p2.global_position = p1.global_position + axe * minf(p1.global_position.distance_to(cible) * 0.6, 200.0)
	_tenir_les_torches()
	for i in 90:
		for p in [p1, p2]:
			p.rotation = axe.angle()
		if _torches == "eblouir":
			p2.rotation = (-axe).angle()
		await get_tree().process_frame
	if _effacement:
		await _controler_l_effacement()
		return
	if _lacet_identique:
		await _controler_le_lacet(axe)
		return
	if _objets:
		await _controler_les_objets()
		return
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
	if _jeu and Presentation3D.instance() != null:
		# Ce que chaque corps lit : la texture de son capteur, à côté de la capture.
		for id in 2:
			for j in 2:
				var cap = Presentation3D.instance().capteurs()[id][j]
				if cap != null:
					var lu: Image = (cap as SubViewport).get_texture().get_image()
					if lu != null:
						lu.save_png(_capture.get_basename() + "_capteur_vue%d_corps%d.png" % [id + 1, j + 1])
	if _base and _scinde:
		_mesurer_les_sprites(image)
	if _jeu and _controler_les_corps(image) > 0:
		_sortir(7)
		return
	_sortir(0)


## ISO5 — `--killcam` : une killcam complète en iso, par le vrai chemin de fin de manche
## (`GameState._do_end_round`), regardée par la vue de J1 (`--vue j1`, le local et l'hôte) ou de J2 (`--vue
## j2`, la configuration du client). Le jeu est suspendu pendant les mesures (`set_process(false)` sur
## `GameState`, qui fait avancer le rejeu) : chaque paire de captures montre la même image du rejeu.
##
## Quatre contrôles :
## 1. **Les corps des fantômes** — capture sans voile, puis silhouettes des fantômes mises à zéro : les
##    pixels qui changent dans la boîte de chaque fantôme sont son corps voxel.
## 2. **Le voile lit la vue iso** — avec et sans voile : dans les pixels du corps, l'image voilée ressemble
##    plus à l'image AVEC corps qu'à l'image sans corps. Un voile qui lirait la lightmap ne verrait pas le
##    corps voxel.
## 3. **Le noir absolu** — lumières éteintes, teinte d'ambiance noire, voile, quads et calques d'écran
##    retirés : hors des boîtes des fantômes, aucun pixel allumé hors du support de la projection brute
##    (la LED des murs est du décor, dans les deux vues).
## 4. **L'étalon contre la vue de dessus (information)** — lumières éteintes, sous la teinte de killcam
##    puis sous une teinte noire : la médiane des pixels allumés du fantôme en iso, celle du fantôme 2D
##    (vue iso éteinte, `GameSettings.mode_iso = false`), et la silhouette attendue.
const TOLERANCE_ETALON_KILLCAM := 6
const SEUIL_PIXEL_CHANGE := 6

func _controler_la_killcam() -> void:
	var p := Presentation3D.instance()
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var cible := _mur_le_plus_proche(p1.global_position)
	var axe := (cible - p1.global_position).normalized()
	p2.global_position = p1.global_position + axe.orthogonal() * 160.0
	_tenir_les_torches()
	for i in 90:
		p1.rotation = (p2.global_position - p1.global_position).angle()
		p2.rotation = (p1.global_position - p2.global_position).angle()
		await get_tree().process_frame
	p1.shoot()
	for i in 30:
		await get_tree().process_frame
	var rejeu := get_node(^"/root/ReplaySystem")
	_main._do_end_round(0)
	if not await _attendre(func() -> bool:
			return bool(rejeu.get("playing_back")) and _main.current_snap != null and _main.ghost_p1.visible, 15.0):
		printerr("✗ --killcam : la killcam n'a pas démarré")
		_sortir(1)
		return
	var pid := 1 if _vue_killcam == "j2" else 0
	if pid == 1:
		(_main.vp1.get_parent() as Control).hide()
		(_main.vp2.get_parent() as Control).show()
		_main._accorder_rendu_aux_vues()
	if not await _attendre(func() -> bool:
			return bool(p.get("_actif")) and not bool(p.get("_scinde")) and p._vue_de(pid) != null, 5.0):
		printerr("✗ --killcam : la vue iso ne tient pas en vue unique sur la vue de J%d (%s)" % [pid + 1, p.raison_des_vues()])
		_sortir(1)
		return
	for i in 20:
		await get_tree().process_frame
	_main.set_process(false)
	# ⚠️ **Les calques d'écran se posent par-dessus les DEUX vues** — halo et voile d'éblouissement,
	# séparation des couleurs du brouillage, interface. Jeu suspendu, l'éblouissement ne retombe plus quand
	# les lumières s'éteignent : au premier passage, le « noir » valait 255 sur 3,6 millions de pixels, et
	# l'étalon comparait le halo. Ils sont retirés pour toute la mesure ; l'interface cesse aussi de
	# repousser les uniformes du voile (`ui.gd` réécrit `negatif` et `tension` à chaque image).
	_ui.set_process(false)
	var calques_caches := _cacher_les_calques_d_ecran()
	for i in 6:
		await get_tree().process_frame
	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	var base := _capture.get_basename()
	var voile_2d := _ui.killcam_overlay as CanvasItem
	var voile_iso := p.voile_de_killcam(pid)
	print("BANC_ISO killcam vue=j%d voile_iso=%s voile_2d_couche=%d zoom=%.2f taille_camera=%.1f capteurs=%s"
		% [pid + 1, voile_iso != null and voile_iso.visible, voile_2d.visibility_layer, _main.cam1.zoom.x,
		float((p._camera_de(pid) as CameraIso).size), str(_max_capteurs())])

	print("BANC_ISO killcam calques_d_ecran_retires=%d" % calques_caches)
	var capture_voilee: Image = await RenduCommun.capturer(get_tree(), 15000)
	if capture_voilee != null:
		capture_voilee.save_png(_capture)
	# Le voile en NÉGATIF PUR (sans dessin, sans tension) : sur le corps, l'image voilée doit valoir le négatif
	# vignetté de l'image AVEC corps. Un voile qui lirait autre chose que la vue iso ne verrait pas le corps.
	var matiere := voile_2d.material as ShaderMaterial
	matiere.set_shader_parameter("intensite", 0.0)
	matiere.set_shader_parameter("tension", 0.0)
	matiere.set_shader_parameter("negatif", 1.0)
	for i in 6:
		await get_tree().process_frame
	var image_a: Image = await RenduCommun.capturer(get_tree(), 15000)
	image_a.save_png(base + "_voile_negatif.png")
	voile_2d.hide()
	for i in 6:
		await get_tree().process_frame
	var image_b: Image = await RenduCommun.capturer(get_tree(), 15000)
	var traces := {}
	var boites := {}
	for j in 2:
		var fantome: Node2D = _main.ghost_p1 if j == 0 else _main.ghost_p2
		if fantome.visible:
			traces[j] = fantome.get_node("VisualColored") as Polygon2D
			boites[j] = _boite_iso_du_fantome(p, pid, j, fantome.global_position)
	for j in traces:
		var eteinte: Polygon2D = traces[j]
		eteinte.color.a = 0.0
	for i in 6:
		await get_tree().process_frame
	var image_c: Image = await RenduCommun.capturer(get_tree(), 15000)
	for j in traces:
		var rendue: Polygon2D = traces[j]
		rendue.color.a = 0.5
	if image_a == null or image_b == null or image_c == null:
		printerr("✗ aucune image rendue en 15 s")
		_sortir(4)
		return
	image_b.save_png(base + "_sans_voile.png")

	# 1 et 2.
	var corps_tenus := not boites.is_empty()
	var voile_lit := not boites.is_empty()
	var details: PackedStringArray = []
	for j in boites:
		var zone: Rect2i = boites[j]
		var mesure := _corps_et_voile(image_a, image_b, image_c, zone)
		corps_tenus = corps_tenus and int(mesure["corps"]) >= 30
		voile_lit = voile_lit and int(mesure["corps"]) > 0 and float(mesure["ecart_avec"]) < float(mesure["ecart_sans"]) \
			and float(mesure["ecart_avec"]) < 20.0
		details.append("fantôme J%d : %d pixels de corps dans %s ; négatif voilé contre négatif avec corps %.1f, contre sans corps %.1f"
			% [j + 1, mesure["corps"], str(zone), mesure["ecart_avec"], mesure["ecart_sans"]])
	print("BANC_ISO killcam corps vue=j%d verdict=%s — %s" % [pid + 1,
		"CORPS DES FANTÔMES TENUS" if corps_tenus else "CORPS DES FANTÔMES ABSENTS", " ; ".join(details)])
	voile_lit = voile_lit and voile_2d.visibility_layer == Presentation3D.COUCHE_HORS_VUE
	print("BANC_ISO killcam voile vue=j%d verdict=%s" % [pid + 1,
		"LE VOILE LIT LA VUE ISO" if voile_lit else "LE VOILE NE LIT PAS LA VUE ISO"])

	# 3 et 4. Lumières éteintes, voile et quads retirés.
	var miroirs = p.get("_miroirs")
	if miroirs != null:
		miroirs.masquer_les_quads(true)
	var ambiance := _main.arena.get_node_or_null("CanvasModulate") as CanvasModulate
	var teinte_killcam: Color = ambiance.color if ambiance != null else Color.WHITE
	var iso := {}
	var plat := {}
	for teinte in ["killcam", "noire"]:
		if ambiance != null:
			ambiance.color = teinte_killcam if teinte == "killcam" else Color.BLACK
		for i in 20:
			_eteindre_les_lumieres(get_tree().root)
			await get_tree().process_frame
		iso[teinte] = await RenduCommun.capturer(get_tree(), 15000)
	(iso["noire"] as Image).save_png(base + "_noir.png")
	# La projection BRUTE (pâte retirée), même image : ce que la vue iso montre ne doit rien allumer hors de
	# son support — la LED des murs et le sol qu'elle éclaire sont du décor, présents dans les deux vues.
	var style_pate: int = p.style_pate
	p.style_pate = -1
	for i in 10:
		_eteindre_les_lumieres(get_tree().root)
		await get_tree().process_frame
	var brute: Image = await RenduCommun.capturer(get_tree(), 15000)
	p.style_pate = style_pate
	var hors_max := _valeur_max(_sans_zones(iso["noire"], boites.values()))
	var hors := _allumes_hors_du_support(_sans_zones(iso["noire"], boites.values()), _sans_zones(brute, boites.values()))
	GameSettings.mode_iso = false
	for i in 20:
		_eteindre_les_lumieres(get_tree().root)
		await get_tree().process_frame
	for teinte in ["noire", "killcam"]:
		if ambiance != null:
			ambiance.color = teinte_killcam if teinte == "killcam" else Color.BLACK
		for i in 20:
			_eteindre_les_lumieres(get_tree().root)
			await get_tree().process_frame
		plat[teinte] = await RenduCommun.capturer(get_tree(), 15000)
	(plat["killcam"] as Image).save_png(base + "_vue_de_dessus.png")
	var noir_tenu := hors == 0
	# L'étalon est une INFORMATION, pas un verdict : le fantôme 2D est un sprite texturé à l'encre (couleur ×
	# texture × 0,5), le corps iso porte la silhouette de soi d'ISO2b (couleur × 0,5) — deux dessins, pas
	# deux mesures d'une même chose. Médianes des pixels allumés : le maximum tombe sur les arêtes où deux
	# boîtes du voxel se recouvrent (0,75 de la couleur au premier passage, pour une médiane à 0,5).
	var lignes: PackedStringArray = []
	for j in boites:
		var fantome: Node2D = _main.ghost_p1 if j == 0 else _main.ghost_p2
		var zone_2d := _boite_2d_du_fantome(pid, fantome.global_position)
		var trace: Polygon2D = traces[j]
		for teinte in ["killcam", "noire"]:
			var a := _mediane_allumee(iso[teinte], boites[j])
			var b := _mediane_allumee(plat[teinte], zone_2d)
			lignes.append("J%d, teinte %s : iso %d/%d/%d, vue de dessus %d/%d/%d" % [j + 1, teinte, a[0], a[1], a[2], b[0], b[1], b[2]])
		# ISO6 — la silhouette porte l'atténuation alignée sur le fantôme 2D (`ATTENUATION_FANTOME`).
		var k := Presentation3D.ATTENUATION_FANTOME
		lignes.append("J%d, silhouette attendue %d/%d/%d" % [j + 1, roundi(trace.color.r * k * trace.color.a * 255.0),
			roundi(trace.color.g * k * trace.color.a * 255.0), roundi(trace.color.b * k * trace.color.a * 255.0)])
	print("BANC_ISO killcam noir vue=j%d verdict=%s (hors des fantômes : %d pixel(s) allumé(s) hors du support de la brute, max %d/255 ; teinte de killcam %s)"
		% [pid + 1, "NOIR ABSOLU TENU" if noir_tenu else "NOIR ABSOLU ROMPU", hors, hors_max, str(teinte_killcam)])
	print("BANC_ISO killcam etalon vue=j%d (information, médianes des pixels allumés) — %s" % [pid + 1, " ; ".join(lignes)])
	var tenue := corps_tenus and voile_lit and noir_tenu
	print("BANC_ISO killcam vue=j%d verdict=%s" % [pid + 1, "KILLCAM TENUE" if tenue else "KILLCAM ROMPUE"])
	_sortir(0 if tenue else 8)


## La boîte, en pixels de la capture, d'un corps posé en `pos` et vu par la caméra iso de la vue `pid`.
func _boite_iso_du_fantome(p: Presentation3D, pid: int, j: int, pos: Vector2) -> Rect2i:
	var cam := p._camera_de(pid) as CameraIso
	var taille := p.viewport_ecran(pid).get_visible_rect().size
	var e := _etirement()
	var pied := cam.vers_ecran(pos, taille)
	var tete := cam.vers_ecran(pos, taille, _hauteur_du_corps_px(p, j))
	var echelle := taille.y / cam.size
	var demi := 12.0 * echelle
	var r := Rect2(Vector2(minf(pied.x, tete.x) - demi, minf(pied.y, tete.y) - demi * 0.5), Vector2.ZERO)
	r = r.expand(Vector2(maxf(pied.x, tete.x) + demi, maxf(pied.y, tete.y) + demi * 0.5))
	return Rect2i(Vector2i((r.position * e).floor()), Vector2i((r.size * e).ceil()))


## La boîte, en pixels de la capture, du fantôme 2D en `pos`, vue iso éteinte (rendu par la racine ou par la
## sous-vue, selon `GameState._rendu_racine`).
func _boite_2d_du_fantome(pid: int, pos: Vector2) -> Rect2i:
	var vue: SubViewport = _main.vp1 if pid == 0 else _main.vp2
	var e := _etirement()
	var ecran: Vector2
	var zoom := vue.canvas_transform.x.length()
	if bool(_main.get("_rendu_racine")):
		ecran = get_tree().root.canvas_transform * pos
		zoom = get_tree().root.canvas_transform.x.length()
	else:
		ecran = (vue.get_parent() as Control).get_global_rect().position + vue.canvas_transform * pos
	var demi := 24.0 * zoom
	return Rect2i(Vector2i(((ecran - Vector2(demi, demi)) * e).floor()), Vector2i((Vector2(demi, demi) * 2.0 * e).ceil()))


## Dans `zone` : les pixels qui changent entre `b` (sans voile) et `c` (sans voile ni silhouettes) sont le
## corps ; sur eux, l'écart moyen de `a` (voile en négatif pur) au négatif vignetté de `b` et de `c`.
static func _corps_et_voile(a: Image, b: Image, c: Image, zone: Rect2i) -> Dictionary:
	var cadre := Rect2i(Vector2i.ZERO, b.get_size()).intersection(zone)
	var taille := Vector2(b.get_size())
	var corps := 0
	var avec := 0.0
	var sans := 0.0
	for y in range(cadre.position.y, cadre.end.y):
		for x in range(cadre.position.x, cadre.end.x):
			var cb := b.get_pixel(x, y)
			var cc := c.get_pixel(x, y)
			if _ecart_255(cb, cc) < SEUIL_PIXEL_CHANGE:
				continue
			corps += 1
			var ca := a.get_pixel(x, y)
			avec += _ecart_255(ca, _negatif_vignette(cb, Vector2(x, y) / taille))
			sans += _ecart_255(ca, _negatif_vignette(cc, Vector2(x, y) / taille))
	return {"corps": corps, "ecart_avec": avec / maxf(1.0, corps), "ecart_sans": sans / maxf(1.0, corps)}


## Ce que `killcam_overlay.gdshader` rend d'un pixel à intensité 0 et négatif 1 : la vignette, puis le négatif.
static func _negatif_vignette(c: Color, uv: Vector2) -> Color:
	var t := clampf((0.8 - uv.distance_to(Vector2(0.5, 0.5)) * 1.2) / 0.6, 0.0, 1.0)
	var v := t * t * (3.0 - 2.0 * t)
	return Color(1.0 - c.r * v, 1.0 - c.g * v, 1.0 - c.b * v)


## Cache tous les calques d'écran du jeu (éblouissement, brouillage, interface…), sauf le voile de killcam
## iso, que la présentation montre elle-même. Rend leur nombre.
func _cacher_les_calques_d_ecran() -> int:
	var n := 0
	for calque in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(calque.name).begins_with("VoileKillcamIso"):
			continue
		if (calque as CanvasLayer).visible:
			(calque as CanvasLayer).visible = false
			n += 1
	return n


static func _ecart_255(u: Color, v: Color) -> float:
	return maxf(maxf(absf(u.r - v.r), absf(u.g - v.g)), absf(u.b - v.b)) * 255.0


static func _max_rgb_zone(image: Image, zone: Rect2i) -> Array[int]:
	var sortie: Array[int] = [0, 0, 0]
	if image == null:
		return [-1, -1, -1]
	var cadre := Rect2i(Vector2i.ZERO, image.get_size()).intersection(zone)
	for y in range(cadre.position.y, cadre.end.y):
		for x in range(cadre.position.x, cadre.end.x):
			var px := image.get_pixel(x, y)
			sortie[0] = maxi(sortie[0], roundi(px.r * 255.0))
			sortie[1] = maxi(sortie[1], roundi(px.g * 255.0))
			sortie[2] = maxi(sortie[2], roundi(px.b * 255.0))
	return sortie


## Une copie de l'image, les zones données mises au noir ; `null` sans image.
static func _sans_zones(image: Image, zones: Array) -> Image:
	if image == null:
		return null
	var copie := image.duplicate() as Image
	copie.convert(Image.FORMAT_RGB8)
	for zone: Rect2i in zones:
		var cadre := Rect2i(Vector2i.ZERO, copie.get_size()).intersection(zone)
		if cadre.size.x > 0 and cadre.size.y > 0:
			copie.fill_rect(cadre, Color.BLACK)
	return copie


## La médiane, canal par canal, des pixels allumés (plus haut canal au-dessus de 8) d'une zone.
static func _mediane_allumee(image: Image, zone: Rect2i) -> Array[int]:
	if image == null:
		return [-1, -1, -1]
	var cadre := Rect2i(Vector2i.ZERO, image.get_size()).intersection(zone)
	var canaux := [[], [], []]
	for y in range(cadre.position.y, cadre.end.y):
		for x in range(cadre.position.x, cadre.end.x):
			var px := image.get_pixel(x, y)
			if maxf(maxf(px.r, px.g), px.b) * 255.0 <= 8.0:
				continue
			canaux[0].append(roundi(px.r * 255.0))
			canaux[1].append(roundi(px.g * 255.0))
			canaux[2].append(roundi(px.b * 255.0))
	var sortie: Array[int] = [0, 0, 0]
	for k in 3:
		var valeurs: Array = canaux[k]
		if not valeurs.is_empty():
			valeurs.sort()
			sortie[k] = int(valeurs[valeurs.size() / 2])
	return sortie


## Le plafond des corps — premier retour d'Adrien au jalon H-ISO2 (2026-09-14) : « quand le
## joueur ennemi est éclairé, par la torche ou par la LED des murs, il devient tout blanc ».
##
## Un corps éclairé ne doit jamais dépasser le gris de l'ennemi, `Charte.ADVERSAIRE` : c'est le
## plafond que la vue de dessus impose au sprite ennemi (`player_enemy_light.gdshader`,
## `min(lit, COLOR)`). La pâte D le poussait à 255/246/227. Mesuré sur le flanc de chaque corps
## visible, dans chaque vue dont le joueur n'est pas ébloui : le halo du brouillage s'ajoute à
## l'image par-dessus le corps, et ce n'est pas le corps qu'il faut juger alors.
##
## Rend le nombre de corps au-dessus du plafond ; imprime chaque mesure, et dit si le corps
## était éclairé — un contrôle passé sur des corps noirs ne prouverait rien.
const TOLERANCE_PLAFOND := 3
## Au-delà, la vue est ignorée : le voile et le halo du brouillage recouvrent l'image. En deçà
## mais non nul — sa propre torche allumée éblouit son porteur à 0,06 —, seul le
## corps de l'AUTRE est mesuré : le halo se pose sur la source, ici le joueur lui-même.
const EBLOUI_IGNORE := 0.1

func _controler_les_corps(image: Image) -> int:
	var p := Presentation3D.instance()
	if p == null or image == null or not bool(p.get("_actif")):
		return 0
	var plafond := [roundi(Charte.ADVERSAIRE.r * 255.0), roundi(Charte.ADVERSAIRE.g * 255.0),
		roundi(Charte.ADVERSAIRE.b * 255.0)]
	var joueurs := [_main.p1, _main.p2]
	var depassements := 0
	var mesures := 0
	for id in 2:
		var ecran: Viewport = p.viewport_ecran(id)
		if ecran == null:
			continue
		var ebloui := float(joueurs[id].get("dazzle_amount"))
		if ebloui > EBLOUI_IGNORE:
			print("BANC_ISO corps vue=J%d ignorée (joueur ébloui à %.2f : halo du brouillage par-dessus) ; corps d'en face opacite_au_rendu=%.2f"
				% [id + 1, ebloui, float(_opacites_au_rendu.get("ennemi%d" % (1 - id), -1.0))])
			continue
		var cam: CameraIso = p._camera_de(id)
		var taille := ecran.get_visible_rect().size
		var origine: Vector2 = p._cadre(id).position if bool(p.get("_scinde")) else Vector2.ZERO
		for j in 2:
			var corps: Node2D = joueurs[j]
			if not corps.visible or not corps.visual.visible:
				continue
			if j == id and ebloui > 0.01:
				print("BANC_ISO corps vue=J%d corps=J%d ignoré (son porteur est ébloui à %.2f)" % [id + 1, j + 1, ebloui])
				continue
			if j == id:
				# ISO2b : son propre corps porte la silhouette de la vue de dessus, à sa couleur — le
				# plafond est la règle du sprite ENNEMI (`min(lit, COLOR)`), pas la sienne.
				print("BANC_ISO corps vue=J%d corps=J%d le sien : silhouette à sa couleur, hors du plafond de l'ennemi" % [id + 1, j + 1])
				continue
			# Le flanc ET le dessus : depuis que chaque fragment lit le capteur à sa place, le côté
			# tourné vers la lampe est clair et le dos sombre — le centre du flanc seul peut tomber
			# dans l'ombre d'un corps bien éclairé. Deux boîtes dans la silhouette, jamais le sol.
			# Tailles tirées de la caméra : un pixel de monde vaut `echelle` pixels d'écran, le dessus
			# du cylindre se projette en ellipse de demi-axes R et R·sin(tangage), le flanc sur
			# H·cos(tangage). Les boîtes en couvrent 65 % : dans la silhouette, jamais le sol — et
			# assez pour attraper le côté tourné vers la lampe, où qu'elle soit.
			var echelle := taille.y / cam.size if cam.size > 0.0 else 1.0
			var tangage := deg_to_rad(CameraIso.TANGAGE_DEG)
			var hauteur := _hauteur_du_corps_px(p, j)
			var flanc: Array
			var dessus: Array
			if bool(p.get("corps_voxel")):
				# ISO3a : un corps voxel est humanoïde — des boîtes étroites dans le torse et la tête, pour ne
				# jamais mesurer le sol entre les jambes ou autour du cou.
				flanc = _max_rgb_dans(image, origine + cam.vers_ecran(corps.global_position, taille, hauteur * 0.6),
					4.0 * echelle, 4.0 * echelle)
				dessus = _max_rgb_dans(image, origine + cam.vers_ecran(corps.global_position, taille, hauteur * 0.88),
					2.5 * echelle, 2.5 * echelle)
			else:
				var rayon := Presentation3D.RAYON_CORPS_PX * echelle * 0.65
				flanc = _max_rgb_dans(image, origine + cam.vers_ecran(corps.global_position, taille,
					hauteur * 0.5), rayon, hauteur * echelle * cos(tangage) * 0.3)
				dessus = _max_rgb_dans(image, origine + cam.vers_ecran(corps.global_position, taille,
					hauteur), rayon, rayon * sin(tangage))
			if flanc.is_empty() and dessus.is_empty():
				continue
			var m := [0, 0, 0]
			for boite in [flanc, dessus]:
				for c in (boite as Array).size():
					m[c] = maxi(m[c], boite[c])
			if bool(p.get("corps_voxel")):
				# ISO3a : le plafond d'un corps voxel est la couleur de sa classe (`couleur_fiche`), que sa pâte
				# plafonne canal par canal — la règle du sprite ennemi, à la couleur de la fiche.
				var fiche: Color = ((p.get("_voxels") as Array)[j] as VoxelCorps).couleur()
				plafond = [roundi(fiche.r * 255.0), roundi(fiche.g * 255.0), roundi(fiche.b * 255.0)]
			var au_dessus: bool = m[0] > plafond[0] + TOLERANCE_PLAFOND \
				or m[1] > plafond[1] + TOLERANCE_PLAFOND or m[2] > plafond[2] + TOLERANCE_PLAFOND
			mesures += 1
			if au_dessus:
				depassements += 1
			print("BANC_ISO corps vue=J%d corps=J%d opacite_au_rendu=%.2f" % [id + 1, j + 1,
				float(_opacites_au_rendu.get(("soi%d" if id == j else "ennemi%d") % j, -1.0))])
			print("BANC_ISO corps vue=J%d corps=J%d position=%s rotation=%.3f opacite=%.2f lumieres : %s" % [id + 1, j + 1,
				str(corps.global_position.round()), corps.rotation,
				float(((p.get("_mat_corps") as Array)[j] as ShaderMaterial).get_shader_parameter("opacite_%d" % (id + 1))),
				" | ".join(_lumieres_sur(corps.global_position, Presentation3D.masque_capteur(id, j)))])
			print("BANC_ISO corps vue=J%d corps=J%d max=%d/%d/%d plafond=%d/%d/%d eclaire=%s verdict=%s"
				% [id + 1, j + 1, m[0], m[1], m[2], plafond[0], plafond[1], plafond[2],
				"oui" if maxi(m[0], maxi(m[1], m[2])) > 40 else "non",
				"AU-DESSUS DU PLAFOND" if au_dessus else "sous le plafond"])
	# ⚠️ Zéro mesure n'est pas un plafond tenu : la première scène « J1 éblouit J2 » ignorait les
	# deux vues et concluait « tenu » sur rien.
	var verdict := "PLAFOND ROMPU" if depassements > 0 else ("PLAFOND TENU" if mesures > 0 else "AUCUN CORPS MESURÉ")
	print("BANC_ISO corps verdict=%s (%d corps mesurés, %d au-dessus du gris de l'ennemi)"
		% [verdict, mesures, depassements])
	return depassements


func _relever_les_opacites() -> void:
	var joueurs := [_main.p1, _main.p2]
	for j in 2:
		if is_instance_valid(joueurs[j]):
			_opacites_au_rendu["ennemi%d" % j] = Presentation3D.opacite_rendue(joueurs[j].get("visual_enemy"))
			_opacites_au_rendu["soi%d" % j] = Presentation3D.opacite_rendue(joueurs[j].get("visual"))


## La plus haute valeur de chaque canal dans une boîte de ±`demi_x` × ±`demi_y` pixels
## logiques autour d'un point logique de l'écran ; vide hors de l'image.
func _max_rgb_dans(image: Image, logique: Vector2, demi_x: float, demi_y: float) -> Array:
	var e := _etirement()
	var centre := Vector2i((logique * e).round())
	var demi := Vector2i(maxi(2, roundi(demi_x * e)), maxi(2, roundi(demi_y * e)))
	var zone := Rect2i(centre - demi, demi * 2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if zone.size.x <= 0 or zone.size.y <= 0:
		return []
	var region := image.get_region(zone)
	region.convert(Image.FORMAT_RGB8)
	var donnees := region.get_data()
	var m := [0, 0, 0]
	for k in range(0, donnees.size(), 3):
		for c in 3:
			m[c] = maxi(m[c], donnees[k + c])
	return m


## ISO2b — l'effacement (brief d'Adrien) : un corps iso à l'opacité `o` de son sprite se FOND dans ce
## que la vue montre derrière lui ; à `o = 0`, il est indiscernable du décor. Contrôlé dans la vue de
## J1, sur le corps de J2 éclairé (`--torches j2` : sa rétrodiffusion le trahit chez J1), par trois
## captures de la même scène : opacité forcée à 1, forcée à 0, et corps retiré du rendu. Dans la boîte
## du corps, l'écart entre « à 0 » et « retiré » doit rester sous la tolérance ; l'écart entre « à 1 »
## et « retiré » doit dépasser le seuil de visibilité — sans quoi le contrôle ne prouverait rien.
## Code 9 sinon.
##
## L'opacité est forcée SUR LE SPRITE (`ForceurOpacite`, priorité 9999) : après `player.gd` (priorité
## 0), avant `Presentation3D` (10000) qui la lit. Le corps iso ne lit qu'elle, comme en jeu.
const EFFACEMENT_TOLERANCE := 8
const EFFACEMENT_VISIBLE := 30
## L'étalon du fondu : à opacité 0,5, le contraste du corps contre le décor vaut la moitié de celui
## à opacité 1, dans la vue de dessus comme en iso (le mélange est le même). Tolérance sur le rapport.
const FONDU_TOLERANCE := 0.06
## ISO2b — tolérance de la silhouette de soi dans le noir, par canal (l'arrondi du fondu sRGB).
const SILHOUETTE_TOLERANCE := 8


class ForceurOpacite extends Node:
	var sprite: CanvasItem
	var valeur := -1.0
	## Les lumières qui changent d'elles-mêmes d'une image à l'autre, éteintes pendant le contrôle.
	var lumieres_eteintes: Array[Light2D] = []

	func _process(_delta: float) -> void:
		if valeur >= 0.0 and is_instance_valid(sprite):
			sprite.modulate.a = valeur
		for l in lumieres_eteintes:
			if is_instance_valid(l):
				l.enabled = false


func _controler_l_effacement() -> void:
	var p := Presentation3D.instance()
	var iso := not _base
	if iso and (p == null or not bool(p.get("_actif")) or p.viewport_ecran(0) == null):
		printerr("✗ --effacement : la vue iso de J1 n'est pas allumée")
		_sortir(4)
		return
	var p2: Node2D = _main.p2
	var forceur := ForceurOpacite.new()
	forceur.name = "ForceurOpacite"
	forceur.process_priority = 9999
	forceur.sprite = p2.get("visual_enemy")
	# ⚠️ Le bandeau LED des murs RESPIRE (≈ 8,5 s) : entre la première capture et les suivantes, le mur
	# derrière J2 changeait de valeur — 60 pixels « hors norme » au premier essai, sans rapport avec le
	# corps (noirs à opacité 1, identiques à 0,5 et à 0). Il est éteint à chaque image du contrôle.
	var led := get_tree().root.find_child("MurLed", true, false) as Light2D
	if led != null:
		forceur.lumieres_eteintes.append(led)
	add_child(forceur)
	var maillages: Array = ((p.get("_corps") as Array)[1] as Node3D).get_children() if iso else []
	# [nom, opacité forcée sur le sprite, corps iso rendu]. ⚠️ **L'image à opacité 0 est prise deux
	# fois, en premier et en dernier** : un élément du décor qui change pendant le contrôle (un arc clair
	# apparu après la première capture, à un essai du 2026-09-14) se trahit entre les deux, et ses pixels
	# sont écartés au lieu d'être pris pour un défaut de fondu.
	var etats := [["a0", 0.0, true], ["a05", 0.5, true], ["a1", 1.0, true]]
	if iso:
		etats.append(["retire", 0.0, false])
	etats.append(["a0bis", 0.0, true])
	var images := {}
	var au_rendu := {}
	for etat in etats:
		forceur.valeur = etat[1]
		for m in maillages:
			(m as Node3D).visible = etat[2]
		for i in 12:
			await get_tree().process_frame
		var image: Image = await RenduCommun.capturer(get_tree(), 15000)
		if image == null:
			printerr("✗ aucune image rendue en 15 s")
			_sortir(4)
			return
		images[etat[0]] = image
		au_rendu[etat[0]] = float(_opacites_au_rendu.get("ennemi1", -1.0))
		image.save_png(_capture.get_basename() + "_%s.png" % etat[0])
	for m in maillages:
		(m as Node3D).visible = true
	forceur.valeur = -1.0
	var zone := _zone_du_corps(p, 0, p2) if iso else _zone_du_sprite(0, p2)
	var f := _mesurer_le_fondu(images, zone, iso)
	var rapport := float(f["contraste_a_05"]) / float(f["contraste_a_1"]) if int(f["contraste_a_1"]) > 0 else -1.0
	# Le rapport des maxima dit le pire pixel ; le rapport médian, pixel par pixel, dit le corps entier.
	# Les deux doivent tenir : un double fondu local (le nez sur le tronc) ne se voyait que dans le premier.
	var fondu_tenu := int(f["contraste_a_1"]) >= EFFACEMENT_VISIBLE and absf(rapport - 0.5) <= FONDU_TOLERANCE \
		and absf(float(f["rapport_median"]) - 0.5) <= FONDU_TOLERANCE
	print("BANC_ISO fondu rendu=%s vue=J1 corps=J2 zone=%s opacite_au_rendu=%.2f/%.2f/%.2f contraste_a_1=%d contraste_a_0.5=%d rapport=%.2f rapport_median=%.2f hors_norme=%d/%d mouvants_ecartes=%d (attendu 0,50 ± %.2f)"
		% ["iso" if iso else "base", str(zone), au_rendu["a1"], au_rendu["a05"], au_rendu["a0"],
		int(f["contraste_a_1"]), int(f["contraste_a_05"]), rapport, float(f["rapport_median"]),
		int(f["hors_norme"]), int(f["pixels"]), int(f["mouvants"]), FONDU_TOLERANCE])
	var tenu := fondu_tenu
	if iso:
		# À opacité 0, le corps iso est indiscernable du décor seul (corps retiré du rendu).
		print("BANC_ISO effacement vue=J1 corps=J2 ecart_a_0=%d (tolérance %d) ecart_a_1=%d (visible dès %d)"
			% [int(f["ecart_a_0"]), EFFACEMENT_TOLERANCE, int(f["ecart_a_1"]), EFFACEMENT_VISIBLE])
		tenu = tenu and int(f["ecart_a_0"]) <= EFFACEMENT_TOLERANCE and int(f["ecart_a_1"]) >= EFFACEMENT_VISIBLE
	print("BANC_ISO effacement rendu=%s verdict=%s" % ["iso" if iso else "base", "EFFACEMENT TENU" if tenu else "EFFACEMENT ROMPU"])
	_sortir(0 if tenu else 9)


## ISO4 — l'équité des objets debout : « un objet voxel ne doit jamais cacher un corps que la vue de dessus
## laisse voir » (brief). Chaque objet de la vague 3 est posé devant J2, du côté de la caméra de J1, au
## contact (son rayon plus celui d'un corps), J2 éclairé par sa propre torche ; l'image est prise son voxel
## caché, puis montré. Tenu si la tête et le torse de J2 — les boîtes du plafond, `_controler_les_corps` —
## ne changent pas ; les pixels changés dans la zone du corps se relèvent à côté. La fusée est lancée puis
## forcée à l'état posé. Le leurre est un corps : il se mesure de même, pour information, sans verdict.
##
## ISO6 — les clés sont les slugs du JEU (`GameState.IMPLEMENTATIONS`), plus ceux du catalogue des
## voxels : posés sous `mine` et `ombre`, la mine et l'ombre habitée recevaient ici un voxel qu'elles
## n'avaient pas en match (voir `MiroirsIso.SLUG_DU_CATALOGUE`), et le banc les jugeait sur un chemin
## que le jeu ne prend pas.
const OBJETS_BANC := {
	"mine_magnesium": "res://gadget_mine.gd",
	"torche_fantome": "res://gadget_torche_fantome.gd",
	"voile": "res://gadget_voile.gd",
	"ombre_habitee": "res://gadget_ombre.gd",
	"gresillement": "res://gadget_gresillement.gd",
	"fusee": "",
	"leurre": "res://gadget_leurre.gd",
}
const OBJET_TOLERANCE := 3


func _controler_les_objets() -> void:
	var p := Presentation3D.instance()
	if not _jeu or _capture == "" or p == null or not bool(p.get("_actif")) or p.viewport_ecran(0) == null:
		printerr("✗ --objets : il faut --jeu --capture, et la vue iso de J1 allumée")
		_sortir(4)
		return
	var miroirs = p.get("_miroirs")
	var p2: Node2D = _main.p2
	var led := get_tree().root.find_child("MurLed", true, false) as Light2D
	if led != null:
		led.enabled = false
	var cam: CameraIso = p._camera_de(0)
	var taille := p.viewport_ecran(0).get_visible_rect().size
	var origine: Vector2 = p._cadre(0).position if bool(p.get("_scinde")) else Vector2.ZERO
	var echelle := taille.y / cam.size if cam.size > 0.0 else 1.0
	var hauteur := _hauteur_du_corps_px(p, 1)
	# La caméra regarde depuis le sud (lacet 0) : « devant » J2, c'est vers le bas de l'écran, +y en 2D.
	var vers_camera := Vector2(0.0, 1.0)
	var tenus := 0
	var juges := 0
	var numero := 950
	for slug in OBJETS_BANC:
		var cle := String(MiroirsIso.SLUG_DU_CATALOGUE.get(slug, slug))
		var rayon := float(VoxelCatalogueObjets.OBJETS[cle]["rayon_px"]) if VoxelCatalogueObjets.OBJETS.has(cle) \
			else Presentation3D.RAYON_CORPS_PX
		var pos := p2.global_position + vers_camera * (rayon + Presentation3D.RAYON_CORPS_PX)
		var g: Node2D = null
		if slug == "fusee":
			_main._do_spawn_fusee(0, pos, PI / 2.0, numero)
			g = _main.bullet_container.get_node_or_null(NodePath("FuseeJ1_%d" % numero)) as Node2D
			if g != null:
				g.call("forcer_age", 0.5)
				g.global_position = pos
		else:
			g = (load(OBJETS_BANC[slug]) as GDScript).new()
			g.set("slug", slug)
			g.name = "GadgetJ1_%d" % numero
			g.set("poseur_id", 0)
			g.set("classe_du_poseur", _main.p1.current_weapon)
			g.position = pos
			_main.bullet_container.add_child(g)
		numero += 1
		if g == null:
			printerr("  ✗ %s : objet non posé" % slug)
			continue
		for i in 20:
			await get_tree().process_frame
		var voxel: Node3D = miroirs.miroir_de(g)
		if voxel == null:
			printerr("  ✗ %s : aucun miroir" % slug)
			g.queue_free()
			continue
		voxel.visible = false
		for i in 8:
			await get_tree().process_frame
		var sans: Image = await RenduCommun.capturer(get_tree(), 15000)
		voxel.visible = true
		for i in 8:
			await get_tree().process_frame
		var avec: Image = await RenduCommun.capturer(get_tree(), 15000)
		if sans == null or avec == null:
			printerr("✗ aucune image rendue en 15 s")
			_sortir(4)
			return
		avec.save_png(_capture.get_basename() + "_objet_%s.png" % slug)
		var boites := []
		for image in [sans, avec]:
			var flanc := _max_rgb_dans(image, origine + cam.vers_ecran(p2.global_position, taille, hauteur * 0.6),
				4.0 * echelle, 4.0 * echelle)
			var tete := _max_rgb_dans(image, origine + cam.vers_ecran(p2.global_position, taille, hauteur * 0.88),
				2.5 * echelle, 2.5 * echelle)
			boites.append([flanc, tete])
		var ecart := 0
		for b in 2:
			for c in 3:
				ecart = maxi(ecart, absi(int(boites[0][b][c]) - int(boites[1][b][c])))
		var zone := _zone_du_corps(p, 0, p2).intersection(Rect2i(Vector2i.ZERO, avec.get_size()))
		var changes := 0
		if zone.size.x > 0 and zone.size.y > 0:
			var a := sans.get_region(zone)
			var b2 := avec.get_region(zone)
			a.convert(Image.FORMAT_RGB8)
			b2.convert(Image.FORMAT_RGB8)
			var da := a.get_data()
			var db := b2.get_data()
			for k in range(0, da.size(), 3):
				if absi(int(da[k]) - int(db[k])) > 30 or absi(int(da[k + 1]) - int(db[k + 1])) > 30 \
						or absi(int(da[k + 2]) - int(db[k + 2])) > 30:
					changes += 1
		var eclaire := maxi(maxi(int(boites[0][0][0]), int(boites[0][0][1])), maxi(int(boites[0][1][0]), int(boites[0][1][1]))) > 40
		var tenu := ecart <= OBJET_TOLERANCE and eclaire
		# `slug` vient d'une clé de dictionnaire, sans type : l'inférence refuse la comparaison.
		var info: bool = String(slug) == "leurre"
		if not info:
			juges += 1
			if tenu:
				tenus += 1
		print("BANC_ISO objet slug=%s zone=%d,%d,%d,%d devant_J2=%.0f px tete=%s/%s torse=%s/%s ecart=%d pixels_changes=%d/%d eclaire=%s verdict=%s"
			% [slug, zone.position.x, zone.position.y, zone.size.x, zone.size.y, rayon + Presentation3D.RAYON_CORPS_PX, str(boites[0][1]), str(boites[1][1]), str(boites[0][0]),
			str(boites[1][0]), ecart, changes, zone.size.x * zone.size.y, "oui" if eclaire else "non",
			"information (un corps)" if info else ("TÊTE ET TORSE INTACTS" if tenu else "CACHE LE CORPS")])
		g.queue_free()
		for i in 6:
			await get_tree().process_frame
	var verdict := tenus == juges and juges > 0
	print("BANC_ISO objets verdict=%s (%d/%d objets laissent voir la tête et le torse d'un corps collé derrière)"
		% ["OBJETS ÉQUITABLES" if verdict else "UN OBJET CACHE UN CORPS", tenus, juges])
	var image: Image = await RenduCommun.capturer(get_tree(), 15000)
	if image != null:
		image.save_png(_capture)
	_sortir(0 if verdict else 9)


## Les mesures du fondu dans une zone, sur les seuls pixels STABLES (même valeur à opacité 0 en début
## et en fin de contrôle) : contraste contre le décor à opacité 1 et 0,5 (maxima), rapport médian pixel
## par pixel là où le corps se voit (écart ≥ 40), pixels hors tolérance, pixels mouvants écartés ; et,
## en iso, l'écart au corps retiré à opacité 0 et 1.
static func _mesurer_le_fondu(images: Dictionary, zone: Rect2i, iso: bool) -> Dictionary:
	var z := zone.intersection(Rect2i(Vector2i.ZERO, (images["a1"] as Image).get_size()))
	var r := {"contraste_a_1": 0, "contraste_a_05": 0, "rapport_median": -1.0, "hors_norme": 0, "pixels": 0,
		"mouvants": 0, "ecart_a_0": 255, "ecart_a_1": 0}
	if z.size.x <= 0 or z.size.y <= 0:
		return r
	var d := {}
	for nom in images:
		var region := (images[nom] as Image).get_region(z)
		region.convert(Image.FORMAT_RGB8)
		d[nom] = region.get_data()
	var rapports: Array[float] = []
	var ecart_a_0 := 0
	for k in (d["a1"] as PackedByteArray).size():
		var v0 := int(d["a0"][k])
		var v0b := int(d["a0bis"][k])
		if absi(v0 - v0b) > 4:
			r["mouvants"] = int(r["mouvants"]) + 1
			continue
		var v1 := int(d["a1"][k])
		var v5 := int(d["a05"][k])
		r["contraste_a_1"] = maxi(int(r["contraste_a_1"]), absi(v1 - v0b))
		r["contraste_a_05"] = maxi(int(r["contraste_a_05"]), absi(v5 - v0b))
		if absi(v1 - v0b) >= 40:
			var q := float(v5 - v0b) / float(v1 - v0b)
			rapports.append(q)
			if absf(q - 0.5) > FONDU_TOLERANCE:
				r["hors_norme"] = int(r["hors_norme"]) + 1
		if iso:
			var vr := int(d["retire"][k])
			ecart_a_0 = maxi(ecart_a_0, absi(v0b - vr))
			r["ecart_a_1"] = maxi(int(r["ecart_a_1"]), absi(v1 - vr))
	if iso:
		r["ecart_a_0"] = ecart_a_0
	r["pixels"] = rapports.size()
	if not rapports.is_empty():
		rapports.sort()
		r["rapport_median"] = rapports[rapports.size() / 2]
	return r


## La boîte d'un sprite dans la vue de dessus (écran scindé), en pixels de fenêtre.
func _zone_du_sprite(id: int, corps: Node2D) -> Rect2i:
	var vue: SubViewport = _main.vp1 if id == 0 else _main.vp2
	var conteneur := vue.get_parent() as Control
	var echelle := conteneur.size / vue.get_visible_rect().size
	var logique := conteneur.global_position + (vue.get_canvas_transform() * corps.global_position) * echelle
	var r := 32.0 * echelle.y
	var e := _etirement()
	return Rect2i(Vector2i(((logique - Vector2(r, r)) * e).round()), Vector2i((Vector2(r, r) * 2.0 * e).round()))


## La boîte d'un corps iso à l'écran, en pixels de fenêtre : du pied au sommet du cylindre, élargie de
## son rayon et de son nez.
func _zone_du_corps(p: Presentation3D, id: int, corps: Node2D) -> Rect2i:
	var ecran: Viewport = p.viewport_ecran(id)
	var cam: CameraIso = p._camera_de(id)
	if ecran == null or cam == null:
		return Rect2i()
	var taille := ecran.get_visible_rect().size
	var origine: Vector2 = p._cadre(id).position if bool(p.get("_scinde")) else Vector2.ZERO
	var echelle := taille.y / cam.size if cam.size > 0.0 else 1.0
	var bas := origine + cam.vers_ecran(corps.global_position, taille, 0.0)
	var haut := origine + cam.vers_ecran(corps.global_position, taille,
		_hauteur_du_corps_px(p, 0 if corps == _main.p1 else 1))
	var r := (Presentation3D.RAYON_CORPS_PX + 12.0) * echelle
	var coin := Vector2(minf(bas.x, haut.x), minf(bas.y, haut.y)) - Vector2(r, r)
	var etendue := Vector2(absf(bas.x - haut.x), absf(bas.y - haut.y)) + Vector2(r, r) * 2.0
	var e := _etirement()
	return Rect2i(Vector2i((coin * e).round()), Vector2i((etendue * e).round()))


## La hauteur d'un corps iso en pixels de monde : le sommet de la tête d'un corps voxel (ISO3a), sinon
## la hauteur du cylindre.
func _hauteur_du_corps_px(p: Presentation3D, j: int) -> float:
	if bool(p.get("corps_voxel")):
		return ((p.get("_voxels") as Array)[j] as VoxelCorps).sommet_tete()
	return Presentation3D.HAUTEUR_CORPS_PX


## La plus haute valeur de chaque canal dans un rectangle de pixels ; vide hors de l'image.
static func _max_rgb_rect(image: Image, zone: Rect2i) -> Array:
	if image == null:
		return []
	var z := zone.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if z.size.x <= 0 or z.size.y <= 0:
		return []
	var region := image.get_region(z)
	region.convert(Image.FORMAT_RGB8)
	var d := region.get_data()
	var m := [0, 0, 0]
	for k in range(0, d.size(), 3):
		for c in 3:
			m[c] = maxi(m[c], d[k + c])
	return m


## ISO2b — la silhouette de soi (brief d'Adrien) : dans le noir, chaque joueur voit son propre corps à
## la moitié de sa couleur (`visual_dim`, comme en vue de dessus), et JAMAIS celui de l'autre. Dans
## chaque vue, la boîte de son corps doit valoir sa silhouette, celle du corps d'en face 0. Rend le
## verdict et une copie de l'image où les boîtes de soi sont noircies, pour le reste du contrôle du noir.
func _controler_la_silhouette(image: Image) -> Dictionary:
	var p := Presentation3D.instance()
	if image == null or p == null or not bool(p.get("_actif")):
		return {"tenue": false, "sans_soi": image}
	var sans_soi := image.duplicate() as Image
	var joueurs := [_main.p1, _main.p2]
	var fautes := 0
	var mesures := 0
	for id in 2:
		if p.viewport_ecran(id) == null:
			continue
		for j in 2:
			var corps: Node2D = joueurs[j]
			if not corps.visible or not corps.visual.visible:
				continue
			var zone := _zone_du_corps(p, id, corps)
			var m := _max_rgb_rect(image, zone)
			if m.is_empty():
				continue
			mesures += 1
			var attendu := [0, 0, 0]
			if j == id:
				var dim: Polygon2D = corps.get("visual_dim")
				var s := dim.color.a * Presentation3D.opacite_rendue(dim)
				attendu = [roundi(dim.color.r * s * 255.0), roundi(dim.color.g * s * 255.0), roundi(dim.color.b * s * 255.0)]
				sans_soi.fill_rect(zone.intersection(Rect2i(Vector2i.ZERO, image.get_size())), Color.BLACK)
			var juste := true
			for c in 3:
				if absi(int(m[c]) - int(attendu[c])) > (SILHOUETTE_TOLERANCE if j == id else 0):
					juste = false
			if not juste:
				fautes += 1
			print("BANC_ISO silhouette vue=J%d corps=J%d max=%d/%d/%d attendu=%d/%d/%d verdict=%s"
				% [id + 1, j + 1, m[0], m[1], m[2], attendu[0], attendu[1], attendu[2], "juste" if juste else "FAUX"])
	var tenue := fautes == 0 and mesures > 0
	print("BANC_ISO silhouette verdict=%s (%d corps mesurés, %d faux ; la sienne à la moitié de sa couleur, celle d'en face à 0)"
		% ["SILHOUETTE TENUE" if tenue else ("AUCUN CORPS MESURÉ" if mesures == 0 else "SILHOUETTE ROMPUE"), mesures, fautes])
	return {"tenue": tenue, "sans_soi": sans_soi}


## Les lumières allumées qui peuvent atteindre un point pour ce masque de lumière : canal croisé,
## et portée de leur texture. Pour dire QUI éclaire un corps, pas seulement combien.
func _lumieres_sur(point: Vector2, masque: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for n in get_tree().root.find_children("*", "Light2D", true, false):
		var l := n as Light2D
		if not l.enabled or not l.is_visible_in_tree() or (l.range_item_cull_mask & masque) == 0:
			continue
		var d := l.global_position.distance_to(point)
		if l is PointLight2D and (l as PointLight2D).texture != null:
			var pl := l as PointLight2D
			var portee := pl.texture.get_width() * pl.texture_scale * 0.5 * maxf(absf(pl.global_scale.x), absf(pl.global_scale.y))
			if d > portee + 20.0:
				continue
		out.append("%s/%s masque=%d energie=%.2f ombre=%s(%d) d=%.0f" % [String(l.get_parent().name), String(l.name),
			l.range_item_cull_mask, l.energy, "oui" if l.shadow_enabled else "non", l.shadow_item_cull_mask, d])
	return out


## L'étalon de la vue de dessus (jalon H-ISO2) : dans la même scène, en `--base --scinde`, le
## sprite de chaque corps mesuré comme le corps iso l'est — mêmes vues ignorées, mêmes corps
## écartés. Adrien : le corps doit s'éclairer « aussi progressivement que l'intensité ». Ce qui
## s'y compare, c'est la valeur la plus haute sur le corps, dans les deux vues : aucune lumière ne
## doit montrer en iso un corps que la vue de dessus laisse noir, ni le cacher. Mesure seule,
## sans verdict — c'est l'étalon.
func _mesurer_les_sprites(image: Image) -> void:
	var joueurs := [_main.p1, _main.p2]
	for id in 2:
		var vue: SubViewport = _main.vp1 if id == 0 else _main.vp2
		var conteneur := vue.get_parent() as Control
		if not conteneur.is_visible_in_tree():
			continue
		var ebloui := float(joueurs[id].get("dazzle_amount"))
		if ebloui > EBLOUI_IGNORE:
			print("BANC_ISO sprite vue=J%d ignorée (joueur ébloui à %.2f : halo du brouillage par-dessus) ; corps d'en face opacite_au_rendu=%.2f"
				% [id + 1, ebloui, float(_opacites_au_rendu.get("ennemi%d" % (1 - id), -1.0))])
			continue
		var echelle := conteneur.size / vue.get_visible_rect().size
		for j in 2:
			var corps: Node2D = joueurs[j]
			if not corps.visible or not corps.visual.visible:
				continue
			if j == id and ebloui > 0.01:
				print("BANC_ISO sprite vue=J%d corps=J%d ignoré (son porteur est ébloui à %.2f)" % [id + 1, j + 1, ebloui])
				continue
			var logique := conteneur.global_position + (vue.get_canvas_transform() * corps.global_position) * echelle
			var m := _max_rgb_dans(image, logique, 12.0, 12.0)
			if m.is_empty():
				continue
			print("BANC_ISO sprite vue=J%d corps=J%d max=%d/%d/%d eclaire=%s" % [id + 1, j + 1, m[0], m[1], m[2],
				"oui" if maxi(m[0], maxi(m[1], m[2])) > 40 else "non"])
			var sprite: CanvasItem = corps.get("visual") if id == j else corps.get("visual_enemy")
			print("BANC_ISO sprite vue=J%d corps=J%d opacite_au_rendu=%.2f" % [id + 1, j + 1,
				float(_opacites_au_rendu.get(("soi%d" if id == j else "ennemi%d") % j, -1.0))])
			print("BANC_ISO sprite vue=J%d corps=J%d position=%s rotation=%.3f opacite=%.2f lumieres : %s" % [id + 1, j + 1,
				str(corps.global_position.round()), corps.rotation, Presentation3D.opacite_rendue(sprite),
				" | ".join(_lumieres_sur(corps.global_position, Presentation3D.masque_capteur(id, j)))])


## Les canaux des capteurs — second retour d'Adrien au jalon H-ISO2 (2026-09-14) : en écran
## scindé, J2 s'allumait dans la vue de J1 « alors même que les LED sont éteintes », et le
## corps de J1 restait noir sous son propre halo, dans sa propre vue.
##
## Un capteur doit recevoir exactement les lumières que recevrait le sprite qu'il remplace, et
## rien d'autre. Le contrôle éteint toutes les lumières du jeu à chaque image, pose sur un
## corps une sonde d'UN seul canal, et lit chaque capteur vivant en son centre, là où le corps
## lit : il doit s'allumer si le masque de son disque croise ce canal et s'il est posé sous ce
## corps, rester noir sinon. Quatre canaux (joueur local, ennemi, vue de J1, vue de J2) sur
## chacun des deux corps : huit cas, chacun jugé sur tous les capteurs. Code 8 à la moindre fuite.
##
## ⚠️ Ce que le contrôle du plafond ne pouvait pas voir : un corps allumé par la MAUVAISE
## lumière reste sous le gris de l'ennemi. Et une torche éclaire tous les canaux à la fois
## (1|2|4) : sous elle, un capteur qui lit le disque d'un autre répond juste par hasard.
const SONDE_ECLAIREE := 20
const SONDE_NOIRE := 2
## Le diamètre de la sonde, en pixels de monde : elle couvre un corps (rayon 18 px) et
## n'atteint jamais l'autre, posé à 110 px.
const SONDE_EMPREINTE_PX := 60

func _controler_les_canaux() -> void:
	var p := Presentation3D.instance()
	if p == null or not bool(p.get("_actif")):
		printerr("✗ --canaux : la vue iso n'est pas allumée")
		_sortir(4)
		return
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	# Les deux corps à 110 px l'un de l'autre, comme sur la planche : ni la sonde (rayon 30 px)
	# ni la fenêtre d'un capteur (±64 px) ne touchent l'autre corps.
	var cible := _mur_le_plus_proche(p1.global_position)
	var axe := (cible - p1.global_position).normalized()
	var avance := minf(p1.global_position.distance_to(cible) * 0.5, 150.0)
	p2.global_position = p1.global_position + axe * avance + axe.orthogonal() * 110.0
	var sonde := PointLight2D.new()
	sonde.name = "BancSondeCanal"
	sonde.set_meta("banc_iso_sonde", true)
	sonde.texture = LightTextures.radial(SONDE_EMPREINTE_PX)
	sonde.color = Color(1, 1, 1)
	sonde.energy = 1.0
	sonde.shadow_enabled = false
	p1.get_parent().add_child(sonde)
	_noir_en_cours = true
	var joueurs: Array[Node2D] = [p1, p2]
	var canaux: Array[int] = [CanauxLumiere.JOUEUR_LOCAL, CanauxLumiere.ENNEMI,
		CanauxLumiere.canal_de_vue(0), CanauxLumiere.canal_de_vue(1)]
	var faux := 0
	var cas := 0
	for sur in 2:
		for canal in canaux:
			sonde.range_item_cull_mask = canal
			sonde.enabled = true
			for i in 15:
				sonde.global_position = joueurs[sur].global_position
				await get_tree().process_frame
			var lus: PackedStringArray = []
			var bon := true
			for id in 2:
				for j in 2:
					var c = p.capteurs()[id][j]
					if c == null:
						continue
					var v: int = _valeur_au_centre(c as SubViewport)
					var doit: bool = j == sur and (canal & Presentation3D.masque_capteur(id, j)) != 0
					var juste: bool = (v >= SONDE_ECLAIREE) if doit else (v <= SONDE_NOIRE)
					if not juste:
						bon = false
					lus.append("vueJ%d/corpsJ%d=%d%s%s" % [id + 1, j + 1, v, "(doit)" if doit else "",
						"" if juste else "(FAUX)"])
			cas += 1
			if not bon:
				faux += 1
			print("BANC_ISO canaux sonde=%d sur=J%d %s verdict=%s"
				% [canal, sur + 1, " ".join(lus), "juste" if bon else "FUITE"])
	_noir_en_cours = false
	sonde.queue_free()
	print("BANC_ISO canaux rallumees_par_le_jeu=%s"
		% (", ".join(_rallumees_vues.keys()) if not _rallumees_vues.is_empty() else "aucune"))
	print("BANC_ISO canaux vue=%s verdict=%s (%d cas, %d faux ; « doit » : ce capteur doit s'allumer)"
		% ["scinde" if _scinde else "unique", "CANAUX TENUS" if faux == 0 else "CANAUX ROMPUS", cas, faux])
	_sortir(0 if faux == 0 else 8)


## La valeur la plus haute au centre d'un capteur, sur ±16 px de monde : là où le corps lit.
## ISO14 — la condition de la voie (b) (session cloud, 2026-09-24, 01:35) : tourner la caméra 2D du lacet ne change
## RIEN à ce que lisent les capteurs des corps ni à l'éblouissement, pour les deux joueurs. Les capteurs ont leur propre
## Camera2D, qui ne tourne pas (`capteur_corps.gd`) ; l'éblouissement se calcule dans le monde (`_maj_eblouissement`) :
## c'est ce que le banc vérifie au lieu de le supposer. Pour chaque réglage — 0° A, puis 45° A, B et C —, 40 images
## de pose, puis la moyenne sur 20 images des quatre capteurs (valeur max au centre, `_valeur_au_centre`) et de
## `dazzle_amount` des deux joueurs. Tolérance : 3 niveaux sur 255 et 0,02 d'éblouissement (la torche pulse d'une
## image à l'autre, et les deux relevés ne tombent pas au même instant). Le noir absolu à 45° se prouve à part, par
## `--noir` avec `-- --lacet=45 --lacet-j2=B|C` (le même contrôle qu'à 0°).
## Mise en scène : celle de `--torches eblouir` (J2 dans le faisceau de J1, face à lui).
func _controler_le_lacet(axe: Vector2) -> void:
	var p := Presentation3D.instance()
	if p == null or not bool(p.get("_actif")):
		printerr("✗ --lacet-identique : la vue iso n'est pas allumée")
		_sortir(4)
		return
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var reglages: Array = [[0.0, "A"], [45.0, "A"], [45.0, "B"], [45.0, "C"]]
	var releves: Array = []
	for r in reglages:
		GameSettings.lacet_duel = float(r[0])
		GameSettings.option_lacet = String(r[1])
		var somme := PackedFloat32Array([0, 0, 0, 0, 0, 0])
		for i in 60:
			p1.rotation = axe.angle()
			p2.rotation = (-axe).angle() if _torches == "eblouir" else axe.angle()
			await get_tree().process_frame
			if i < 40:
				continue
			var k := 0
			for id in 2:
				for j in 2:
					var c = p.capteurs()[id][j]
					somme[k] += float(_valeur_au_centre(c as SubViewport)) if c != null else -1.0
					k += 1
			somme[4] += float(p1.get("dazzle_amount"))
			somme[5] += float(p2.get("dazzle_amount"))
		for k in 6:
			somme[k] /= 20.0
		var cams: Array = []
		for id in 2:
			var c2d: Camera2D = _main.cam1 if id == 0 else _main.cam2
			cams.append("J%d cam2D %.1f° iso %.1f°" % [id + 1, rad_to_deg(c2d.rotation), GameSettings.lacet_de(id)])
		releves.append(somme)
		print("BANC_ISO lacet %s° %s : capteurs vueJ1/J1=%.1f vueJ1/J2=%.1f vueJ2/J1=%.1f vueJ2/J2=%.1f · éblouissement J1=%.3f J2=%.3f · %s"
			% [str(r[0]), r[1], somme[0], somme[1], somme[2], somme[3], somme[4], somme[5], " · ".join(cams)])
	GameSettings.lacet_duel = GameSettings.LACET_DEFAUT
	GameSettings.option_lacet = GameSettings.OPTION_LACET_DEFAUT
	for i in 5:
		await get_tree().process_frame
	var faux := 0
	var ref: PackedFloat32Array = releves[0]
	for n in range(1, releves.size()):
		var v: PackedFloat32Array = releves[n]
		for k in 4:
			if absf(v[k] - ref[k]) > 3.0:
				faux += 1
		for k in [4, 5]:
			if absf(v[k] - ref[k]) > 0.02:
				faux += 1
	var revenues := absf(rad_to_deg((_main.cam1 as Camera2D).rotation)) < 1e-3 \
		and absf(rad_to_deg((_main.cam2 as Camera2D).rotation)) < 1e-3
	print("BANC_ISO lacet verdict=%s (%d écart(s) hors tolérance ; caméras 2D revenues à 0° : %s)"
		% ["LACET SANS EFFET SUR LES CAPTEURS ET L'ÉBLOUISSEMENT" if faux == 0 else "LE LACET CHANGE CE QUI EST LU",
		faux, "oui" if revenues else "NON"])
	_sortir(0 if faux == 0 else 8)


func _valeur_au_centre(capteur: SubViewport) -> int:
	var t := capteur.size
	return _valeur_max_dans(capteur.get_texture().get_image(), Rect2i(t / 2 - Vector2i(32, 32), Vector2i(64, 64)))


## Les torches allumées par leur BOUTON, le premier cran tenu — celles que `--torches`
## demande (toutes, hors capture).
##
## ⚠️ **Écrire `flashlight_on` ne suffit pas** : `player.gd` le relit dans
## `input_provider.is_flashlight_pressed()` à chaque pas de physique (« la torche
## n'obéit qu'au bouton »). La première mise en scène du 2026-09-14 l'écrivait à
## chaque image, et les captures sont sorties torches éteintes. Tenir l'action,
## c'est passer par le chemin qu'un joueur emprunte.
func _tenir_les_torches() -> void:
	var voulues := {"p1_torch": _torches in ["toutes", "j1", "eblouir"] or _capture == "",
		"p2_torch": _torches in ["toutes", "j2"] or _capture == ""}
	for action in voulues:
		if not InputMap.has_action(action):
			continue
		if voulues[action] and not Input.is_action_pressed(action):
			Input.action_press(action, 0.5)
		elif not voulues[action] and Input.is_action_pressed(action):
			Input.action_release(action)


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
	_vues.assign([_main.vp1] if not _scinde else [_main.vp1, _main.vp2])
	var allumee := await _attendre(func() -> bool:
		var p := Presentation3D.instance()
		return p != null and bool(p.get("_actif")) and bool(p.get("_scinde")) == _scinde, 5.0)
	if not allumee:
		printerr("✗ --jeu : la vue isométrique du jeu ne s'est pas allumée %s "
			% ("en écran scindé" if _scinde else "en vue unique")
			+ "(GameSettings.mode_iso, crochet de rebuild_arena, vues regardées ?)")
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
	# Sans --pate, celle du jeu : D, décision d'Adrien du 2026-09-14.
	return args[i + 1].to_upper() if i >= 0 and i + 1 < args.size() else \
		str(IsoPate_.LETTRES[Presentation3D.PATE_PAR_DEFAUT]) if Presentation3D.PATE_PAR_DEFAUT >= 0 else "BRUTE"


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
	_noir_en_cours = true
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
	var rendu := "base" if _base else "jeu-" + _pate_nommee()
	if _base:
		print("BANC_ISO noir-a rendu=%s max_ecran=%d/255 lumieres_eteintes=%d image=%s"
			% [rendu, max_a, eteintes, _capture])
		_sortir(0)
		return
	# ISO2 : une lightmap PAR VUE regardée, et une moitié d'écran par vue en scindé.
	var max_lightmaps_a: Array[int] = []
	for i in _vues.size():
		var lumiere_a := _vues[i].get_texture().get_image()
		max_lightmaps_a.append(_valeur_max(lumiere_a))
		if lumiere_a != null:
			lumiere_a.save_png(_capture.get_basename() + "_lightmap%d.png" % (i + 1))
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
	print("BANC_ISO noir-a rendu=%s vue=%s max_ecran=%d/255 max_brute=%d/255 max_lightmaps=%s max_capteurs=%s allumes_hors_support=%d lumieres_eteintes=%d image=%s"
		% [rendu, "scinde" if _scinde else "unique", max_a, _valeur_max(brute), str(max_lightmaps_a),
		str(_max_capteurs()), hors_support, eteintes, _capture])

	# (a) prouve aussi le corps : **toutes lumières éteintes, chaque capteur doit valoir 0** —
	# un corps ne s'allume que par son capteur.
	var max_capteurs_a := _max_capteurs()
	var capteurs_noirs := max_capteurs_a.all(func(v): return v == 0)
	var masques: Array[int] = []
	for vue in _vues:
		masques.append(vue.canvas_cull_mask)
		vue.canvas_cull_mask = 0
	# ISO4 : le viseur, la ligne de visée et la balle sont passés de la lightmap à des quads 3D au sol. Ce
	# sont toujours des dessins 2D SANS LUMIÈRE (voir plus haut, en-tête du contrôle) : (b) les retire avec
	# le reste de la 2D, comme il les retirait avec leur lightmap — sans quoi le viseur de chacun ressortait
	# ici à 179/255 et la ligne de visée faussait une silhouette. (a) les juge toujours contre la brute.
	var miroirs = presentation.get("_miroirs")
	if miroirs != null:
		miroirs.masquer_les_quads(true)
	# « La vue 2D ne dessine plus rien » vaut pour les capteurs aussi : ils sont de la 2D.
	var capteurs_vivants := _capteurs_vivants()
	var masques_capteurs: Array[int] = []
	for c in capteurs_vivants:
		masques_capteurs.append(c.canvas_cull_mask)
		c.canvas_cull_mask = 0
	for i in 20:
		_eteindre_les_lumieres(get_tree().root)
		await get_tree().process_frame
	var image_b: Image = await RenduCommun.capturer(get_tree(), 15000)
	# ISO2b : dans le noir, chacun voit son propre corps à la moitié de sa couleur — et jamais celui de
	# l'autre. Mesuré d'abord ; puis ses boîtes sont retirées de ce qui doit valoir 0 partout ailleurs.
	var silhouette := _controler_la_silhouette(image_b)
	var image_b_hors_soi: Image = silhouette["sans_soi"]
	var max_lightmaps_b: Array[int] = []
	var max_moities_b: Array[int] = []
	for i in _vues.size():
		max_lightmaps_b.append(_valeur_max(_vues[i].get_texture().get_image()))
		max_moities_b.append(_valeur_max_dans(image_b_hors_soi, _cadre_pixels(i)))
		_vues[i].canvas_cull_mask = masques[i]
	var max_capteurs_b := _max_capteurs()
	for k in capteurs_vivants.size():
		capteurs_vivants[k].canvas_cull_mask = masques_capteurs[k]
	if miroirs != null:
		miroirs.masquer_les_quads(false)
	var chemin_b := _capture.get_basename() + "_lightmap_noire.png"
	if image_b != null:
		image_b.save_png(chemin_b)
	var max_b := _valeur_max(image_b_hors_soi)
	var max_lightmap_b: int = max_lightmaps_b.max() if not max_lightmaps_b.is_empty() else -1
	var tenu := max_b == 0 and max_lightmap_b == 0 and hors_support == 0 and capteurs_noirs and bool(silhouette["tenue"])
	print("BANC_ISO noir-b rendu=%s vue=%s max_ecran=%d/255 max_moities=%s max_lightmaps=%s max_capteurs=%s image=%s"
		% [rendu, "scinde" if _scinde else "unique", max_b, str(max_moities_b), str(max_lightmaps_b),
		str(max_capteurs_b), chemin_b])
	_noir_en_cours = false
	print("BANC_ISO noir rallumees_par_le_jeu=%s" % ", ".join(_rallumees_vues.keys()) if not _rallumees_vues.is_empty() else "BANC_ISO noir rallumees_par_le_jeu=aucune")
	print("BANC_ISO noir pate=%s vue=%s verdict=%s (a : %d pixel(s) allumé(s) hors du support de la brute, écran max %d, capteurs %s ; b : écran %d sur lightmap %d ; moitiés %s)"
		% [_pate_nommee(), "scinde" if _scinde else "unique", "NOIR ABSOLU TENU" if tenu else "NOIR ABSOLU ROMPU",
		hors_support, max_a, str(max_capteurs_a), max_b, max_lightmap_b, str(max_moities_b)])
	_sortir(0 if tenu else 6)


## La valeur maximale de chaque capteur de corps vivant (ISO2), vue par vue, corps par corps.
## Un corps ne peut s'allumer que par son capteur : c'est le premier endroit où regarder quand
## un corps sort du noir.
func _max_capteurs() -> Array[int]:
	var out: Array[int] = []
	for c in _capteurs_vivants():
		out.append(_valeur_max(c.get_texture().get_image()))
	return out


func _capteurs_vivants() -> Array[SubViewport]:
	var out: Array[SubViewport] = []
	var p := Presentation3D.instance()
	if p == null:
		return out
	for id in 2:
		for j in 2:
			var c = p.capteurs()[id][j]
			if c != null:
				out.append(c as SubViewport)
	return out


## Le cadre de la vue `i` en PIXELS de fenêtre, à l'étirement près : celui que la vue iso
## lui donne (`Presentation3D._cadre`) — en lightmap `plein`, le conteneur sans `stretch`
## grandit jusqu'à sa vue et ne dit plus où elle s'affiche.
func _cadre_pixels(i: int) -> Rect2i:
	var p := Presentation3D.instance()
	var cadre: Rect2 = p._cadre(1 if _vues[i] == _main.vp2 else 0) if p != null and bool(p.get("_actif")) \
		else (_vues[i].get_parent() as Control).get_global_rect()
	var e := _etirement()
	return Rect2i(Vector2i((cadre.position * e).round()), Vector2i((cadre.size * e).round()))


## La valeur de canal la plus haute dans une région de l'image, alpha exclu.
static func _valeur_max_dans(image: Image, zone: Rect2i) -> int:
	if image == null:
		return -1
	var cadre := Rect2i(Vector2i.ZERO, image.get_size()).intersection(zone)
	if cadre.size.x <= 0 or cadre.size.y <= 0:
		return -1
	return _valeur_max(image.get_region(cadre))


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


## Toutes celles que le jeu a rallumées pendant le contrôle, par nom de nœud (pour la ROADMAP).
var _rallumees_vues := {}


## Éteint toutes les `Light2D` et rend le chemin de celles qui étaient allumées.
func _eteindre_et_nommer(noeud: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	# La sonde du contrôle des canaux reste allumée : c'est la seule lumière qu'il veut.
	if noeud is Light2D and (noeud as Light2D).enabled and not noeud.has_meta("banc_iso_sonde"):
		(noeud as Light2D).enabled = false
		out.append(String(noeud.name))
		_rallumees_vues[String(noeud.get_parent().name) + "/" + String(noeud.name)] = true
	for enfant in noeud.get_children():
		out.append_array(_eteindre_et_nommer(enfant))
	return out


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
	for prop in ["rendu_racine_autorise", "_rendu_racine", "vp1", "vp2", "ui", "countdown_left",
			"ghost_p1", "ghost_p2", "current_snap", "arena"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	if not main.has_method("_accorder_rendu_aux_vues"):
		absents.append("GameState._accorder_rendu_aux_vues() a disparu")
	# ISO5 — `--killcam` passe par le vrai chemin de fin de manche.
	if not main.has_method("_do_end_round"):
		absents.append("GameState._do_end_round() a disparu (variante --killcam)")
	if not "killcam_overlay" in ui:
		absents.append("UI.killcam_overlay a disparu (variante --killcam)")
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
