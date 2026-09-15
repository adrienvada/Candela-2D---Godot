extends Node
## Préférences persistées du joueur : vsync, plafond d'images par seconde,
## résolution, volumes audio, intensité des effets et remappage des touches.
##
## Norme du jeu compétitif : vsync désactivé, aucun plafond par défaut — voir
## la décision « Images par seconde déplafonnées » dans docs/ROADMAP.md.
##
## Cet autoload est déclaré APRÈS InputSetup dans project.godot, et c'est ce qui
## rend le remappage persistant possible : les liaisons enregistrées s'appliquent
## par-dessus les liaisons par défaut, jamais l'inverse.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_VIDEO := "video"
const SECTION_DISPLAY := "display"
const SECTION_INPUT := "input"
const SECTION_AUDIO := "audio"
const SECTION_EFFECTS := "effets"

## 0 = déplafonné.
const FPS_CAPS: Array[int] = [0, 60, 120, 144, 240]

## Les trois modes proposés par le menu : fenêtré 1280, fenêtré 1920, plein
## écran.
const RESOLUTION_COUNT := 3

## Facteur appliqué à la taille de la fenêtre en débogage, et à elle seule.
##
## Mesuré le 2026-08-25 : macOS compte les fenêtres en pixels NATIFS, et l'écran
## de développement est un Retina à l'échelle 2 — 3840×2486 pixels pour 1920×1243
## points. Une fenêtre de 1280×720 pixels n'y occupe donc que 640×360 points, un
## tiers de la largeur de l'écran : c'est toute l'explication du « ça s'ouvre
## dans une petite fenêtre », et rien n'y paraît côté résolution.
##
## Le jeu exporté ne double pas : l'écran d'un joueur n'est pas forcément Retina,
## et le même facteur y déborderait de l'écran.
const DEBUG_WINDOW_FACTOR := 2

## Noms exacts des bus de `default_bus_layout.tres`, tels qu'`audio_manager.gd`
## les adresse. Toute divergence se traduit par un index -1, traité comme une
## absence et non comme une erreur : voir `_apply_bus_volume()`.
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_SPEAKER := "Speaker"

## Les volumes sont mémorisés en **amplitude linéaire** (0 = muet, 1 = le niveau
## nominal du bus tel qu'il est mixé dans `default_bus_layout.tres`). C'est ce
## que doit exposer un curseur : brancher un curseur droit sur des décibels
## rend le réglage inutilisable, tout le changement perçu se tassant dans les
## derniers pourcents de la course. La conversion se fait à l'application.
const VOLUME_MIN := 0.0
const VOLUME_MAX := 1.0
const VOLUME_DEFAULT := 1.0

## `linear_to_db(0)` vaut moins l'infini, valeur qu'`AudioServer` ne doit jamais
## recevoir : elle contamine le mixage au lieu de le taire. En dessous du seuil,
## on coupe franchement (mute) et on plafonne les décibels à ce plancher.
const SILENCE_DB := -80.0
## Équivalent linéaire de SILENCE_DB : plus personne n'entend rien en dessous.
const SILENCE_LINEAR := 0.0001

## Émis à chaque réglage d'effet, avec l'intensité BRUTE choisie. Le rendu peut
## s'y brancher pour prendre la nouvelle valeur en cours de partie plutôt qu'à
## la manche suivante — mais il doit repasser par `current_effect()` pour
## obtenir la valeur applicable : le plancher du classé n'est pas dans le signal.
signal effect_changed(id: String, intensity: float)

var vsync_enabled := false

## DA6.6 — l'intro en planches n'est jouée qu'au PREMIER lancement.
##
## Elle est passable à tout moment, mais ça ne suffit pas : une intro qu'il faut
## passer à chaque fois est une taxe, pas une introduction. Le drapeau est écrit
## dès qu'elle DÉMARRE, jamais à sa fin — sans quoi un joueur qui ferme le jeu
## pendant l'intro la reverrait au lancement suivant, et ainsi de suite.
var intro_vue := false
var fps_cap := 0
var resolution_index := 0

## Chantier ISO — la vue isométrique du duel (`presentation_3d.gd`).
##
## **ISO6 : l'iso EST le jeu, vraie par défaut** (Adrien, 2026-09-14 à 23:33 : « l'iso
## devient la vue du jeu » ; mandat du 2026-09-15 à 05:00). Désactivée par défaut d'ISO1 à
## ISO5, c'était alors une consigne : elle était expérimentale. La vue de dessus reste dans
## le code jusqu'à ISO9 — elle est aussi le moteur de lumière que l'iso projette — mais
## derrière un DRAPEAU DE DÉBOGAGE : `--2d` pour une exécution, ou le réglage
## `debogage/vue_de_dessus`, que les réglages ne proposent qu'en build de débogage.
##
## `mode_iso` est ce qui S'APPLIQUE ; ce qui s'ENREGISTRE est le seul choix de débogage
## (`_vue_de_dessus_choisie`). Aucun drapeau ne s'écrit dans `settings.cfg` : sans cette
## séparation, le premier volume touché pendant une suite lancée en `--2d` aurait persisté la
## vue de dessus chez le joueur. Préséance : `--2d`, puis `--iso` (le drapeau d'ISO1 à ISO5,
## toujours accepté : sans effet, sauf à l'emporter sur un réglage de débogage oublié — un
## banc qui dit « iso » mesure l'iso), puis le réglage, puis l'iso.
##
## ⚠️ **L'ancienne clé `video/mode_iso` n'est plus lue, et c'est voulu.** Chaque
## `settings.cfg` écrit avant ISO6 la porte à `false` — la valeur par défaut d'alors, écrite
## à la première sauvegarde de n'importe quel réglage. La relire aurait gardé la vue de
## dessus chez tous les joueurs existants, Adrien compris. Elle disparaît du fichier au
## premier `_save()`, qui réécrit le fichier entier.
var mode_iso := true
var _vue_de_dessus_choisie := false
const DRAPEAU_ISO := "--iso"
const DRAPEAU_2D := "--2d"
const SECTION_DEBOGAGE := "debogage"
## Le nom du rendu dans F3, F6 et `ConditionsDeMatch` : un relevé qui ne dit pas quelle
## vue il a mesurée ne se compare à rien.
const MODE_RENDU_ISO := "iso"
const MODE_RENDU_DESSUS := "dessus"

## Chantier ISO, étape ISO8 — la caméra serrée (brief de la session cloud, 2026-09-15 12:25 ; Adrien, 12:20 :
## « zoomer dans le jeu, réduire la taille des cônes de lumière pour le rendre plus claustrophobique »).
## `zoom_duel` : le zoom des deux caméras du duel, 1,0 étant la vue d'avant ISO8. `decalage_visee` : la part
## de la hauteur visible dont la caméra avance vers la visée (`RegardDuel`), 0 la laissant sur le joueur.
##
## **Défauts choisis par la session cloud sur la planche des variantes** (2026-09-15, 12:50 : « à ×1,8 la
## face du pilier, le corps et le cône se lisent enfin […] ×2,2 ne montre presque plus de carte » ; « un quart
## de la hauteur visible, comme le brief »). Préparés d'abord sur des défauts neutres (1,0 et 0), pour que
## l'étape 1 ne change pas le jeu. `--zoom=2.2` et `--decalage=0` valent pour une exécution et ne s'écrivent
## jamais. Le zoom choisi au réglage de débogage s'enregistre, **mais seulement
## s'il a été réglé** : un `settings.cfg` qui porterait 1,0 par défaut garderait l'ancien cadrage le jour où
## le défaut passera à 1,8 — le piège exact de `video/mode_iso` (ISO6).
const ZOOM_DUEL_DEFAUT := 1.8
const DECALAGE_VISEE_DEFAUT := 0.25
const ZOOM_DUEL_MIN := 1.0
const ZOOM_DUEL_MAX := 3.0
const DECALAGE_VISEE_MAX := 0.4
const DRAPEAU_ZOOM := "--zoom="
const DRAPEAU_DECALAGE := "--decalage="
## ISO8, étape 3 — la portée de toutes les torches, en un facteur global (choix de la session cloud, 12:50 :
## « portée ×0,75 […] comme un FACTEUR GLOBAL posé une seule fois »). Posé sur `WeaponData.facteur_portee`
## au démarrage ; `--torche=1.0` rend les portées d'avant ISO8 pour une exécution, sans jamais s'écrire.
const FACTEUR_PORTEE_DEFAUT := 0.75
const FACTEUR_PORTEE_MIN := 0.5
const FACTEUR_PORTEE_MAX := 1.5
const DRAPEAU_TORCHE := "--torche="
var facteur_portee := FACTEUR_PORTEE_DEFAUT
var zoom_duel := ZOOM_DUEL_DEFAUT
## ISO8 — EN LIGNE, les trois valeurs du duel sont les constantes, des deux côtés (décision de la session cloud,
## 2026-09-15 à 13:58 : « le cadrage serré non plus n'est pas neutre, un flash ou un cône hors champ n'est pas
## vu, donc un joueur à --zoom=1.0 voit plus qu'un joueur à ×1,8 »). `zoom_duel`, `decalage_visee` et
## `facteur_portee` sont ce qui S'APPLIQUE ; ces trois-là, ce que la machine voudrait en local (drapeaux de
## débogage, réglage enregistré). `accorder_au_mode` tranche, appelé par `GameState` à chaque départ de manche.
var _zoom_local := ZOOM_DUEL_DEFAUT
var _decalage_local := DECALAGE_VISEE_DEFAUT
var _facteur_local := FACTEUR_PORTEE_DEFAUT
var decalage_visee := DECALAGE_VISEE_DEFAUT
var _zoom_duel_choisi := ZOOM_DUEL_DEFAUT
var _zoom_duel_regle := false

## ISO2 — la taille de la lightmap, la cible 2D que la vue iso projette : `1080p`, l'aire
## logique de la vue (ce que le jeu rendait avant le chantier R), ou `plein`, les pixels de
## la fenêtre. H15 l'a laissée ouverte, et ce n'est pas une décision d'agent : Adrien
## tranche au relevé de fin de chantier, sur les appels de dessin et les tailles de cibles
## que le banc imprime. Même partage que `mode_iso` : `iso_lightmap` est ce qui S'APPLIQUE,
## `_iso_lightmap_choisi` ce qui s'enregistre ; `--lightmap plein|1080p` vaut pour une
## exécution et ne s'écrit jamais.
const LIGHTMAPS_ISO := ["1080p", "plein"]
const DRAPEAU_LIGHTMAP := "--lightmap"
var iso_lightmap := "1080p"
var _iso_lightmap_choisi := "1080p"

## PE3.1 — le GPU brûlait pour rien hors match.
##
## Les menus tournaient déplafonnés, vers 200 images par seconde (relevé
## `--menus` du 2026-08-18), et une fenêtre reléguée au second plan continuait
## de dessiner à pleine cadence : sur un portable, c'est ce qui fait souffler
## les ventilateurs — la première plainte d'un testeur, et elle ne parle même
## pas du jeu. Deux plafonds, donc, qui ne s'appliquent QUE hors arène :
##
## - `PLAFOND_MENU` quand on est dans les menus, fenêtre au premier plan ;
## - `PLAFOND_HORS_FOCUS` quand la fenêtre a perdu le focus, hors arène.
##
## ⚠️ **Jamais en arène, quel que soit le focus.** La médiane déplafonnée
## commande le RTT d'EOS (Phase 3 : 60 fps plafonnés doublent la latence
## réseau), et un hôte qui passe une seconde sur une autre fenêtre simule
## toujours pour l'adversaire. Le régime est signalé par `game_state.gd`
## (`round_active or sandbox_mode`, donc l'entraînement et le salon d'attente
## aussi), et par `NOTIFICATION_APPLICATION_FOCUS_IN/OUT` pour le focus.
##
## Un choix du joueur plus BAS que le plafond l'emporte ; plus haut, il est
## ramené au plafond hors arène et s'applique tel quel en arène.
##
## Ces deux nombres sont des VALEURS DE DÉPART, pas des décisions : 120 tient
## un écran à 120 Hz sans qu'un curseur paraisse sauter, 30 suffit à un salon
## qui attend et à une recherche d'appariement en arrière-plan.
const PLAFOND_MENU := 120
const PLAFOND_HORS_FOCUS := 30

## Vrai quand un BANC règle `Engine.max_fps` lui-même (`bench_framerate`,
## `banc_pics`) : les réglages ne touchent alors plus au moteur, sans quoi le
## relevé `--menus` mesurerait ce plafond et non la charge.
var pilotage_externe := false
var _en_arene := false
var _fenetre_au_premier_plan := true

var master_volume := VOLUME_DEFAULT
var music_volume := VOLUME_DEFAULT
var sfx_volume := VOLUME_DEFAULT
var speaker_volume := VOLUME_DEFAULT

## identifiant d'effet -> intensité choisie, entre 0 et 1.
##
## Seuls les identifiants **réglables** d'`EffectPolicy` y entrent — Menus et
## Confort. Un effet retiré de la table, ou passé au Monde, cesse d'exister ici
## à la première relecture : garder une valeur que plus rien n'applique, c'est
## garder un réglage qui ment.
##
## Il n'y a plus d'intensité « brute » distincte de l'appliquée : les planchers
## sont partis avec le réglage du Monde (2026-09-12), et ce qui est retenu ici
## est exactement ce que le rendu lit.
var _effects: Dictionary = {}

## action -> description sérialisable de l'événement de manette assigné.
var _bindings: Dictionary = {}

## Une résolution n'est appliquée au démarrage que si elle a été choisie une
## fois : sans ça, une installation neuve verrait sa fenêtre recentrée d'office.
var _has_saved_resolution := false

## Variable, et non constante, pour une seule raison : les tests headless
## partagent le `user://` du jeu installé. Sans ce point de dérivation, la
## moindre suite qui appelle un `set_*` réécrirait les préférences réelles
## d'un joueur avec les valeurs par défaut du test.
var _settings_path := SETTINGS_PATH

func _ready() -> void:
	_load()
	_apply_video()
	# En débogage, la fenêtre est posée même sans choix enregistré : c'est le seul
	# chemin qui applique `DEBUG_WINDOW_FACTOR` dès le lancement. Hors débogage la
	# règle d'origine tient — une installation neuve garde la fenêtre de
	# `project.godot` au lieu de se voir recentrée d'office.
	if _has_saved_resolution or OS.is_debug_build():
		_apply_resolution()
	mode_iso = iso_applique(_vue_de_dessus_choisie, _arguments())
	iso_lightmap = _lightmap_appliquee()
	_zoom_local = zoom_applique(_zoom_duel_choisi, _arguments_de_reglage())
	_decalage_local = decalage_applique(_arguments_de_reglage())
	_facteur_local = facteur_portee_applique(_arguments_de_reglage())
	# Hors match, les valeurs locales ; `GameState` accorde au mode à chaque départ (`accorder_au_mode`).
	accorder_au_mode(false)
	# Les bus existent dès le chargement de la disposition audio, bien avant les
	# autoloads : aucune dépendance à l'ordre de démarrage d'AudioManager ici.
	_apply_audio()
	_apply_bindings()

# ---------------------------------------------------------------------------
# API publique
# ---------------------------------------------------------------------------

## Retient que l'intro a été jouée. Appelé à son DÉMARRAGE — voir `intro_vue`.
func marquer_intro_vue() -> void:
	if intro_vue:
		return
	intro_vue = true
	_save()

## Refait jouer l'intro au prochain lancement. Pour le menu, et pour les bancs.
func oublier_intro() -> void:
	if not intro_vue:
		return
	intro_vue = false
	_save()

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_video()
	_save()

## Le réglage de DÉBOGAGE, enregistré : la vue de dessus au lieu de l'iso. La quitter prend
## effet à l'image suivante ; revenir à l'iso, au prochain duel (`GameState.rebuild_arena()`
## est le seul crochet de la vue).
func set_vue_de_dessus(actif: bool) -> void:
	_vue_de_dessus_choisie = actif
	mode_iso = iso_applique(actif, _arguments())
	_save()

func vue_de_dessus_choisie() -> bool:
	return _vue_de_dessus_choisie

## `iso` ou `dessus` — ce qui s'applique, pour les diagnostics.
func mode_rendu() -> String:
	return MODE_RENDU_ISO if mode_iso else MODE_RENDU_DESSUS

## La préséance de l'en-tête : `--2d`, puis `--iso`, puis le réglage de débogage, puis l'iso.
static func iso_applique(vue_de_dessus: bool, args: PackedStringArray) -> bool:
	if deux_d_par_argument(args):
		return false
	if iso_par_argument(args):
		return true
	return not vue_de_dessus

static func iso_par_argument(args: PackedStringArray) -> bool:
	return args.has(DRAPEAU_ISO)

static func deux_d_par_argument(args: PackedStringArray) -> bool:
	return args.has(DRAPEAU_2D)

static func _arguments() -> PackedStringArray:
	return OS.get_cmdline_user_args() + OS.get_cmdline_args()

## ISO8 — le zoom du duel choisi au réglage de débogage, enregistré (et marqué comme réglé).
func set_zoom_duel(zoom: float) -> void:
	_zoom_duel_choisi = clampf(zoom, ZOOM_DUEL_MIN, ZOOM_DUEL_MAX)
	_zoom_duel_regle = true
	_zoom_local = zoom_applique(_zoom_duel_choisi, _arguments_de_reglage())
	zoom_duel = _zoom_local
	_save()

func zoom_duel_choisi() -> float:
	return _zoom_duel_choisi

## `--zoom=X` l'emporte sur le choix ; une valeur illisible est ignorée ; le résultat reste dans les bornes.
static func zoom_applique(choisi: float, args: PackedStringArray) -> float:
	var arg := valeur_par_argument(args, DRAPEAU_ZOOM)
	var z := arg.to_float() if arg.is_valid_float() else choisi
	return clampf(z, ZOOM_DUEL_MIN, ZOOM_DUEL_MAX)

## ISO8 — les valeurs du duel pour ce mode : les constantes EN LIGNE, quoi que disent les drapeaux ou
## `settings.cfg` ; les valeurs locales en écran scindé et à l'entraînement. Aucun état réseau : ce sont les mêmes
## constantes dans le même code, sur les deux machines, et `Protocol.VERSION` ne bouge pas.
func accorder_au_mode(en_ligne: bool) -> void:
	var v := valeurs_du_duel(en_ligne, _zoom_local, _decalage_local, _facteur_local)
	zoom_duel = v[0]
	decalage_visee = v[1]
	facteur_portee = v[2]
	WeaponData.facteur_portee = facteur_portee

## `[zoom, décalage, facteur de portée]` — calcul pur, vérifié en `--script` par `test_iso_camera`.
static func valeurs_du_duel(en_ligne: bool, zoom_local: float, decalage_local: float, facteur_local: float) -> Array:
	if en_ligne:
		return [ZOOM_DUEL_DEFAUT, DECALAGE_VISEE_DEFAUT, FACTEUR_PORTEE_DEFAUT]
	return [zoom_local, decalage_local, facteur_local]

## ISO8 — les drapeaux `--zoom=`, `--decalage=` et `--torche=` ne valent qu'en build de DÉBOGAGE : un export
## release les ignore, comme `--eos-ephemeral` (`network_manager.gd`). Sans quoi un joueur lancerait sa partie
## locale avec la carte entière à l'écran — et, avant la règle en ligne, en ligne aussi.
func _arguments_de_reglage() -> PackedStringArray:
	return arguments_de_reglage(_arguments(), OS.is_debug_build())

static func arguments_de_reglage(args: PackedStringArray, debug: bool) -> PackedStringArray:
	if debug:
		return args
	for a in args:
		if a.begins_with(DRAPEAU_ZOOM) or a.begins_with(DRAPEAU_DECALAGE) or a.begins_with(DRAPEAU_TORCHE):
			push_warning("GameSettings : %s ignoré hors build debug" % a)
	return PackedStringArray()

## `--torche=X` l'emporte sur le défaut ; une valeur illisible est ignorée ; le résultat reste dans les bornes.
static func facteur_portee_applique(args: PackedStringArray) -> float:
	var arg := valeur_par_argument(args, DRAPEAU_TORCHE)
	var f := arg.to_float() if arg.is_valid_float() else FACTEUR_PORTEE_DEFAUT
	return clampf(f, FACTEUR_PORTEE_MIN, FACTEUR_PORTEE_MAX)

static func decalage_applique(args: PackedStringArray) -> float:
	var arg := valeur_par_argument(args, DRAPEAU_DECALAGE)
	var d := arg.to_float() if arg.is_valid_float() else DECALAGE_VISEE_DEFAUT
	return clampf(d, 0.0, DECALAGE_VISEE_MAX)

## `--nom=valeur` → `valeur` ; sinon une chaîne vide.
static func valeur_par_argument(args: PackedStringArray, prefixe: String) -> String:
	for a in args:
		if a.begins_with(prefixe):
			return a.substr(prefixe.length())
	return ""

## Le choix du joueur pour la taille de la lightmap, enregistré ; une valeur inconnue
## retombe sur `1080p`. Prend effet à l'image suivante (la vue iso repose ses lightmaps).
func set_iso_lightmap(variante: String) -> void:
	_iso_lightmap_choisi = variante if LIGHTMAPS_ISO.has(variante) else "1080p"
	iso_lightmap = _lightmap_appliquee()
	_save()

func iso_lightmap_choisi() -> String:
	return _iso_lightmap_choisi

func _lightmap_appliquee() -> String:
	var arg := lightmap_par_argument(OS.get_cmdline_user_args() + OS.get_cmdline_args())
	return arg if arg != "" else _iso_lightmap_choisi

## `--lightmap plein` ou `--lightmap 1080p` → la variante ; sinon une chaîne vide.
static func lightmap_par_argument(args: PackedStringArray) -> String:
	var i := args.find(DRAPEAU_LIGHTMAP)
	if i >= 0 and i + 1 < args.size() and LIGHTMAPS_ISO.has(args[i + 1]):
		return args[i + 1]
	return ""

func set_fps_cap(cap: int) -> void:
	fps_cap = cap if FPS_CAPS.has(cap) else 0
	_apply_video()
	_save()

func set_resolution(index: int) -> void:
	resolution_index = index if index >= 0 and index < RESOLUTION_COUNT else 0
	_has_saved_resolution = true
	_apply_resolution()
	_save()

## Volume général (bus Master). Attendu entre 0 et 1 ; toute valeur hors bornes
## est écrêtée plutôt que refusée, un curseur mal calibré ne doit pas pouvoir
## fabriquer un niveau que le mixage ne sait pas rendre.
func set_master_volume(linear: float) -> void:
	master_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_MASTER, master_volume)
	_save()

func set_music_volume(linear: float) -> void:
	music_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_save()

func set_sfx_volume(linear: float) -> void:
	sfx_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_save()

## Voix de l'annonceur (bus Speaker), séparée des effets : elle porte de
## l'information de match, on doit pouvoir la garder audible sans le reste.
func set_speaker_volume(linear: float) -> void:
	speaker_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_SPEAKER, speaker_volume)
	_save()

static func clamp_volume(linear: float) -> float:
	return clampf(linear, VOLUME_MIN, VOLUME_MAX)

## Conversion à destination d'AudioServer. Le zéro n'est pas converti : il rend
## le plancher, jamais moins l'infini.
static func volume_to_db(linear: float) -> float:
	var v := clamp_volume(linear)
	if v <= SILENCE_LINEAR:
		return SILENCE_DB
	return linear_to_db(v)

## Réciproque de `volume_to_db()`, exacte aux deux extrémités : le plancher
## redonne un silence franc et non un résidu inaudible mais non nul.
static func db_to_volume(db: float) -> float:
	if db <= SILENCE_DB:
		return VOLUME_MIN
	return clamp_volume(db_to_linear(db))

## Confort pour les curseurs gradués de 0 à 100 : l'échelle affichée reste
## linéaire, seule la conversion en décibels ne l'est pas.
static func volume_to_percent(linear: float) -> int:
	return int(round(clamp_volume(linear) * 100.0))

static func percent_to_volume(percent: int) -> float:
	return clamp_volume(float(percent) / 100.0)

# ---------------------------------------------------------------------------
# Effets visuels
# ---------------------------------------------------------------------------
#
# La politique — familles, phrases, ce qui se règle et ce qui ne se règle pas —
# est dans `effect_policy.gd`. Ici on ne fait que retenir un choix et le rendre
# applicable.

## Retient l'intensité choisie pour un effet, entre 0 et 1.
##
## Deux refus silencieux, et ce ne sont pas les mêmes :
##
## - un identifiant **absent de la table** est ignoré comme une liaison de touche
##   illisible — le fichier de préférences ne doit pas se remplir de réglages qui
##   ne pilotent plus rien ;
## - un effet du **Monde** est ignoré parce qu'il n'appartient à personne
##   (décision du 2026-09-12). Le refuser ICI, et pas seulement dans l'écran,
##   est ce qui garantit qu'aucune route — banc, outil, écran futur — ne peut
##   écrire une préférence que le rendu n'appliquera jamais : une valeur retenue
##   mais jamais rendue est exactement le genre de réglage qui ment.
func set_effect(id: String, intensity: float) -> void:
	if not EffectPolicy.reglable(id):
		return
	var value := clamp_intensity(intensity)
	_effects[id] = value
	_save()
	effect_changed.emit(id, value)

## Intensité mémorisée. C'est ce qu'affiche un curseur des paramètres avancés.
##
## Un effet du Monde n'a pas de préférence à rendre : il vaut `DEFAULT`, et la
## réponse est la même que celle du rendu — il n'y a plus, depuis le 2026-09-12,
## de valeur « brute » qui différerait de la valeur appliquée.
func get_effect(id: String) -> float:
	if not EffectPolicy.reglable(id):
		return EffectPolicy.DEFAULT
	if not _effects.has(id):
		return EffectPolicy.DEFAULT
	return clamp_intensity(float(_effects[id]))

## Ce que le rendu doit lire, depuis n'importe où, en une seule réponse.
##
## ⚠️ **Il y avait ici un `effective_effect(id, ranked)` et un
## `is_ranked_context()`**, et ils sont partis avec les planchers : un paramètre
## qui ne décide plus rien est pire qu'absent, parce qu'il laisse croire qu'il
## reste un cas où la réponse change. Les deux sites d'appel qui passaient
## `false` en dur — la vitrine des menus dans `ui.gd`, le balayage d'attente du
## classement — appellent maintenant celui-ci.
func current_effect(id: String) -> float:
	return EffectPolicy.clamp_value(id, get_effect(id))

static func clamp_intensity(intensity: float) -> float:
	if is_nan(intensity):
		return EffectPolicy.DEFAULT
	return clampf(intensity, EffectPolicy.MIN, EffectPolicy.MAX)

## Enregistre la liaison choisie pour une action. L'événement a déjà été posé
## dans l'InputMap par l'appelant ; on ne fait que le retenir pour le prochain
## lancement.
func set_binding(action: String, event: InputEvent) -> void:
	var desc := _event_to_dict(event)
	if desc.is_empty():
		return
	_bindings[action] = desc
	_save()

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

func _apply_video() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	if pilotage_externe:
		return
	Engine.max_fps = plafond_effectif()

## PE3.1 — le régime change (arène ou menus) : appelé par `game_state.gd` à
## chaque bascule, jamais à chaque image.
func signaler_arene(en_arene: bool) -> void:
	if en_arene == _en_arene:
		return
	_en_arene = en_arene
	_apply_video()

## Le plafond réellement posé sur le moteur — voir `PLAFOND_MENU`.
func plafond_effectif() -> int:
	if _en_arene:
		return fps_cap
	var plafond := PLAFOND_MENU if _fenetre_au_premier_plan else PLAFOND_HORS_FOCUS
	if fps_cap > 0 and fps_cap < plafond:
		return fps_cap
	return plafond

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_fenetre_au_premier_plan = false
		_apply_video()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_fenetre_au_premier_plan = true
		_apply_video()

func _apply_audio() -> void:
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_apply_bus_volume(BUS_SPEAKER, speaker_volume)

## Un bus renommé ou une disposition audio remplacée rend un index -1. Le cas se
## traverse en silence : un réglage de confort n'a aucune raison d'empêcher le
## jeu de démarrer, et les autres bus doivent quand même recevoir leur niveau.
static func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var v := clamp_volume(linear)
	# Le mute double le plancher en décibels : à zéro le joueur veut un silence
	# franc, pas un -80 dB qu'un casque poussé laisserait encore deviner.
	AudioServer.set_bus_mute(idx, v <= SILENCE_LINEAR)
	AudioServer.set_bus_volume_db(idx, volume_to_db(v))

func _apply_resolution() -> void:
	match resolution_index:
		0: _apply_windowed(Vector2i(1280, 720))
		1: _apply_windowed(Vector2i(1920, 1080))
		2:
			# N'active le plein écran que sur le jeu final exporté : en débogage
			# il masquerait l'éditeur et la console.
			if not OS.is_debug_build():
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				# **Ne rien faire ici rendait `DEBUG_WINDOW_FACTOR` inopérant, et
				# précisément chez celui qui l'avait demandé.**
				#
				# Mesuré le 2026-08-25, par le banc et pas par la lecture : le
				# poste de développement a `resolution_index = 2` enregistré dans
				# `user://settings.cfg`. Le doublement vit dans
				# `_apply_windowed()`, que cette branche n'atteignait jamais — la
				# fenêtre restait donc celle de `project.godot`, 1280×720, soit
				# 640×360 points sur un Retina. Le réglage était juste, le code
				# était juste, et le chemin entre les deux n'existait pas.
				#
				# Un plein écran refusé se rend en **la plus large fenêtre que le
				# débogage autorise**, pas en silence : le joueur a demandé le
				# maximum, on lui doit une réponse et non un statu quo.
				_apply_windowed(Vector2i(1280, 720))

func _apply_windowed(size: Vector2i) -> void:
	var cible := size * DEBUG_WINDOW_FACTOR if OS.is_debug_build() else size
	# Doubler ne doit jamais déborder : une fenêtre plus haute que la zone utile
	# glisse sa barre de titre sous la barre de menus, donc hors d'atteinte — on
	# ne peut plus ni la déplacer ni la fermer à la souris.
	var utile := DisplayServer.screen_get_usable_rect().size
	if utile.x > 0 and utile.y > 0:
		cible = Vector2i(mini(cible.x, utile.x), mini(cible.y, utile.y))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(cible)
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x > 0 and screen_size.y > 0:
		DisplayServer.window_set_position((screen_size - cible) / 2)

func _apply_bindings() -> void:
	for action in _bindings:
		var name := String(action)
		if not InputMap.has_action(name):
			continue
		_erase_joypad_events(name)
		var event := _event_from_dict(_bindings[action])
		if event != null:
			InputMap.action_add_event(name, event)

## Ne retire que les événements de manette : le clavier et la souris définis
## dans project.godot doivent survivre au remappage, sinon rebinder une action
## à la manette la rendrait injouable au clavier.
func _erase_joypad_events(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		var is_trigger := ev is InputEventJoypadMotion \
			and ((ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT
				or (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT)
		if ev is InputEventJoypadButton or is_trigger:
			InputMap.action_erase_event(action, ev)

# ---------------------------------------------------------------------------
# Sérialisation des liaisons
# ---------------------------------------------------------------------------

## Seuls les deux types produits par le remappage sont représentés : bouton de
## manette et gâchette analogique.
static func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadButton:
		var btn := event as InputEventJoypadButton
		return {"type": "button", "code": btn.button_index, "device": btn.device}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {
			"type": "axis", "code": motion.axis,
			"value": motion.axis_value, "device": motion.device,
		}
	return {}

## Un fichier de préférences trafiqué ou issu d'une version antérieure ne doit
## pas empêcher le jeu de démarrer : une description illisible est ignorée.
static func _event_from_dict(desc: Variant) -> InputEvent:
	if not desc is Dictionary:
		return null
	var d: Dictionary = desc
	match String(d.get("type", "")):
		"button":
			var btn := InputEventJoypadButton.new()
			btn.button_index = int(d.get("code", 0))
			btn.device = int(d.get("device", 0))
			return btn
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(d.get("code", 0))
			motion.axis_value = float(d.get("value", 1.0))
			motion.device = int(d.get("device", 0))
			return motion
	return null

# ---------------------------------------------------------------------------
# Persistance
# ---------------------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path) != OK:
		return

	vsync_enabled = cfg.get_value(SECTION_VIDEO, "vsync_enabled", false)
	intro_vue = cfg.get_value(SECTION_DISPLAY, "intro_vue", false)
	var loaded_cap: int = cfg.get_value(SECTION_VIDEO, "fps_cap", 0)
	fps_cap = loaded_cap if FPS_CAPS.has(loaded_cap) else 0
	# Seul un VRAI `true` ramène la vue de dessus : une valeur trafiquée retombe sur l'iso.
	# `video/mode_iso` n'est plus lu — voir l'en-tête.
	_vue_de_dessus_choisie = cfg.get_value(SECTION_DEBOGAGE, "vue_de_dessus", false) is bool \
		and cfg.get_value(SECTION_DEBOGAGE, "vue_de_dessus", false)
	# ISO8 — relu seulement s'il a été réglé ; sinon le défaut du jeu s'applique (voir l'en-tête).
	# `has_section_key` d'abord : `get_value` avec `null` pour défaut vaut « aucun défaut » et imprime une
	# ERREUR à chaque lancement d'un foyer où le zoom n'a jamais été réglé.
	var zoom_lu: Variant = cfg.get_value(SECTION_DEBOGAGE, "zoom_duel") \
		if cfg.has_section_key(SECTION_DEBOGAGE, "zoom_duel") else null
	_zoom_duel_regle = zoom_lu is float or zoom_lu is int
	_zoom_duel_choisi = clampf(float(zoom_lu), ZOOM_DUEL_MIN, ZOOM_DUEL_MAX) if _zoom_duel_regle \
		else ZOOM_DUEL_DEFAUT
	var lightmap: Variant = cfg.get_value(SECTION_VIDEO, "iso_lightmap", "1080p")
	_iso_lightmap_choisi = lightmap if lightmap is String and LIGHTMAPS_ISO.has(lightmap) else "1080p"

	master_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "master", VOLUME_DEFAULT))
	music_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "music", VOLUME_DEFAULT))
	sfx_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "sfx", VOLUME_DEFAULT))
	speaker_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "speaker", VOLUME_DEFAULT))

	if cfg.has_section_key(SECTION_DISPLAY, "resolution_index"):
		var idx: int = cfg.get_value(SECTION_DISPLAY, "resolution_index", 0)
		resolution_index = idx if idx >= 0 and idx < RESOLUTION_COUNT else 0
		_has_saved_resolution = true

	# Relecture par la table, jamais par le fichier : un identifiant inconnu
	# vient d'une version plus récente ou d'une main sur le fichier, et n'a plus
	# de politique. Le garder serait garder un réglage que plus personne
	# n'arbitre.
	#
	# ⚠️ **Et le filtre porte sur « réglable », pas sur « existe ».** Tout
	# `settings.cfg` écrit avant le 2026-09-12 porte les douze effets du Monde,
	# le plus souvent à leur ancien plancher — celui d'Adrien les avait TOUS au
	# plancher. Les relire ici les laisserait à 25 % de sang et 20 % de poussière
	# pour toujours, sans qu'aucun écran ne puisse plus les remonter, et le jeu
	# ne serait pas le même chez lui que chez un joueur neuf. Ils sont donc
	# écartés à la lecture, et disparaissent du fichier au premier `_save()`.
	_effects.clear()
	if cfg.has_section(SECTION_EFFECTS):
		for key in cfg.get_section_keys(SECTION_EFFECTS):
			var id := String(key)
			if not EffectPolicy.reglable(id):
				continue
			_effects[id] = _sanitize_intensity(
				cfg.get_value(SECTION_EFFECTS, id, EffectPolicy.DEFAULT))

	if cfg.has_section(SECTION_INPUT):
		for action in cfg.get_section_keys(SECTION_INPUT):
			var desc: Variant = cfg.get_value(SECTION_INPUT, action, {})
			if desc is Dictionary and not (desc as Dictionary).is_empty():
				_bindings[action] = desc

## Un fichier trafiqué ou écrit par une version antérieure ne doit pas empêcher
## le jeu de démarrer : une valeur illisible retombe sur le niveau nominal.
static func _sanitize_volume(value: Variant) -> float:
	if not (value is float or value is int):
		return VOLUME_DEFAULT
	return clamp_volume(float(value))

## Même défense pour les effets : illisible retombe sur l'intensité d'origine,
## hors bornes est écrêté. Le plancher du classé, lui, n'intervient pas ici — il
## s'applique à la lecture, sur une valeur brute qu'on garde intacte.
static func _sanitize_intensity(value: Variant) -> float:
	if not (value is float or value is int):
		return EffectPolicy.DEFAULT
	return clamp_intensity(float(value))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_VIDEO, "vsync_enabled", vsync_enabled)
	cfg.set_value(SECTION_DISPLAY, "intro_vue", intro_vue)
	cfg.set_value(SECTION_VIDEO, "fps_cap", fps_cap)
	cfg.set_value(SECTION_DEBOGAGE, "vue_de_dessus", _vue_de_dessus_choisie)
	if _zoom_duel_regle:
		cfg.set_value(SECTION_DEBOGAGE, "zoom_duel", _zoom_duel_choisi)
	cfg.set_value(SECTION_VIDEO, "iso_lightmap", _iso_lightmap_choisi)
	if _has_saved_resolution:
		cfg.set_value(SECTION_DISPLAY, "resolution_index", resolution_index)
	cfg.set_value(SECTION_AUDIO, "master", master_volume)
	cfg.set_value(SECTION_AUDIO, "music", music_volume)
	cfg.set_value(SECTION_AUDIO, "sfx", sfx_volume)
	cfg.set_value(SECTION_AUDIO, "speaker", speaker_volume)
	# Seuls les effets réellement réglés sont écrits : une installation neuve
	# n'a pas de section `effets`, et les valeurs par défaut restent celles de la
	# table plutôt qu'une copie figée le jour de la première sauvegarde.
	for id in _effects:
		cfg.set_value(SECTION_EFFECTS, String(id), _effects[id])
	for action in _bindings:
		cfg.set_value(SECTION_INPUT, String(action), _bindings[action])
	cfg.save(_settings_path)
