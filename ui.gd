## UI — HUD de match, menus et navigation deux joueurs.
##
## Navigation : plus aucune table de voisinage codée à la main. Les contrôles
## focusables sont découverts dans l'arbre du panneau actif, et le voisin dans
## une direction est calculé géométriquement (voir `_closest_in_direction`).
## Ajouter un bouton ne demande donc aucune mise à jour de navigation.
##
## Deux curseurs indépendants coexistent (J1 et J2 naviguent simultanément).
## Un contrôle peut être réservé à un joueur via la métadonnée `nav_owner`,
## et désigné comme point d'entrée du focus via `nav_seed`.

extends CanvasLayer
class_name UI

const SHADER_KILLCAM := preload("res://killcam_overlay.gdshader")

signal replay_requested
signal quit_requested
signal main_menu_requested
## Rejoindre un salon n'est plus lancer un match : les deux gestes sont
## séparés depuis que le départ attend les deux « PRÊT ».
signal join_requested
## Entraînement solitaire demandé. Le hub ne sait pas ce que c'est ; il demande.
signal training_requested
## Le joueur quitte la fenêtre de choix : cela annule l'appariement ET la
## recherche. Renoncer à choisir son arme, c'est renoncer au match.
signal pick_window_cancelled

# ---------------------------------------------------------------------------
# CHARTE VISUELLE
# ---------------------------------------------------------------------------
#
# **Ce bloc portait la seconde copie de la palette du dépôt** — l'autre étant
# dans `menu_theme.gd`, dont le commentaire promettait de les réunir « le temps
# de l'étape 3 ». Elles avaient divergé, et personne ne pouvait le voir : chaque
# moitié paraissait juste chez elle.
#
# Tout descend maintenant de `charte.gd`. Les noms restent parce que des
# centaines de lignes les emploient ; les valeurs, elles, n'ont plus qu'un
# domicile.

const Charte := preload("res://charte.gd")

const COLOR_P1 := Charte.BLEU
const COLOR_P2 := Charte.ROUGE
const COLOR_GOLD := Charte.AMBRE
const COLOR_DIM := Charte.DIM
## L'accent d'interface — celui qui n'appartient à aucun des deux joueurs.
const COLOR_ACCENT := Charte.ACIER
## Avertissement qui n'est pas une erreur ; le succès et l'échec ont désormais
## leurs propres couleurs (`Charte.ETAT_OK` / `Charte.ETAT_FAUTE`).
const COLOR_WARN := Charte.ETAT_ATTENTION
const COLOR_LINE := Charte.LINE
const COLOR_SURFACE := Charte.SURFACE
## Le blanc cassé de la lumière : il remplace chaque blanc pur de l'interface.
const COLOR_LUMIERE := Charte.HALOGENE

## Espacements : la grille de 8, et son unique demi-pas.
const GAP_XXS := Charte.GAP_XXS
const GAP_XS := Charte.GAP_XS
const GAP_S := Charte.GAP_S
const GAP_M := Charte.GAP_M
const GAP_L := Charte.GAP_L

## L'échelle typographique. Six tailles, et plus une seule arbitraire.
const T_MENTION := Charte.T_MENTION
const T_COURANT := Charte.T_COURANT
const T_APPUI := Charte.T_APPUI
const T_TITRE := Charte.T_TITRE
const T_VERDICT := Charte.T_VERDICT
const T_ENSEIGNE := Charte.T_ENSEIGNE
## Le décompte 3-2-1 : deux fois l'enseigne, par construction et non par choix.
const T_DECOMPTE := Charte.T_DECOMPTE
## Largeur d'un bouton de choix dans le cadre de droite. La colonne y est plus
## étroite qu'un écran plein : à 220 px, les cinq paliers d'images par seconde se
## repliaient sur trois lignes en fenêtré.
const BOUTON_CHOIX_L := 168

## Transitions d'onglet : court, juste assez pour lier deux écrans.
const TAB_FADE := Charte.D_MOYEN
const TAB_SLIDE := 32.0

## Métadonnées de navigation posées sur les contrôles.
const META_NAV_OWNER := "nav_owner"
const META_NAV_SEED := "nav_seed"
## Valeur de `nav_seed` qui attire les deux curseurs sur la même entrée, au lieu
## d'un joueur nommé. Négative à dessein : un indice de joueur est un entier
## positif, et l'écrire 2 aurait fait d'un troisième joueur imaginaire une
## graine valide.
const NAV_SEED_LES_DEUX := -2
## Libellé d'origine d'une entrée de lancement, à restaurer hors écran de fin.
const META_LAUNCH_BASE := "launch_base"
## L'action que le bouton du cadre déclenche sur l'écran courant.
const META_LAUNCH_ACTION := "launch_action"
## M10 — opacité de nuit d'un rideau, et colonne que la cascade rallume.
const META_ALPHA_NUIT := "alpha_nuit"
const META_CASCADE := "cascade"

## Identifiants des écrans du hub (Phase 5, structure B).
##
## Les anciens `TAB_*` ont disparu avec la barre d'onglets. Ces identifiants ne
## sont pas des libellés : ils servent de clés de navigation et ne s'affichent
## jamais — le titre lisible est donné à `add_screen`.
const SCREEN_LOCAL := "salon_local"
const SCREEN_FRIENDLY := "en_ligne_amical"
const SCREEN_FRIENDLY_ONLINE := "amical_en_ligne"
const SCREEN_FRIENDLY_LOCAL := "amical_local"
const SCREEN_HOST := "salon_hote"
const SCREEN_JOIN := "salon_invite"
const SCREEN_LOCAL_HOST := "local_hote"
const SCREEN_LOCAL_JOIN := "local_invite"
const SCREEN_RANKED := "en_ligne_competitif"
const SCREEN_MATCHMAKING := "recherche"
const SCREEN_TRAINING := "entrainement"
## ⚠️ **Ces deux-là ne sont plus des écrans, ce sont des panneaux** (DA4.18) —
## voir `PANEL_PROFILE` et `PANEL_HISTORY`. Les constantes restent pour que
## `_on_hub_screen_changed` et les bancs n'aient pas à deviner un identifiant
## disparu, mais **plus aucune entrée ne pousse vers elles**.
const SCREEN_PROFILE := "profil"
const SCREEN_HISTORY := "historique"
const SCREEN_CUSTOM := "personnalisation"
## Personnalisation n'a plus AUCUN écran sous elle.
##
## Ses quatre rubriques — contrôles, affichage, effets, audio — étaient quatre
## écrans à pousser, chacun redistribuant ses réglages en une nouvelle liste à
## gauche. Réassigner une touche coûtait deux descentes et deux remontées, et le
## cadre de droite — la moitié de l'écran — ne servait qu'à commenter le niveau
## du dessus. **Un réglage n'est pas une destination** : il se déplie sur place.
##
## `SCREEN_CALIBRATION` survit comme nom de la chose mesurée et non comme écran :
## le garde-fou des effets s'en sert pour retrouver le champ à rafraîchir.
const SCREEN_CALIBRATION := "calibration"
const SCREEN_UPDATE := "mise_a_jour"

## Clés des affichages riches du panneau de droite. Ce ne sont pas des écrans : on
## ne s'y déplace pas, ils se montrent à droite de la liste sous le curseur.
##
## « Cartes » en était un écran, et c'était un aller-retour de trop : choisir
## l'arène demandait de descendre d'un cran, choisir, puis ressortir — alors que la
## place de droite était vide et attendait exactement ça.
const PANEL_SALON := "salon"
const PANEL_MAPS := "cartes"
## Une rubrique de réglages = un panneau, entier. Ce qui était réparti sur
## plusieurs entrées (résolution, vsync, images par seconde, calibration) tient
## désormais dans un seul cadre : on lit sa configuration d'un regard au lieu de
## la parcourir ligne à ligne.
const PANEL_CONTROLS := "panneau_controles"
const PANEL_DISPLAY := "panneau_affichage"
const PANEL_EFFECTS := "panneau_effets"
const PANEL_AUDIO := "panneau_audio"
## DA4.18 — le profil et l'historique se regardent à droite, comme les réglages.
const PANEL_PROFILE := "panneau_profil"
const PANEL_HISTORY := "panneau_historique"
## DA4.18 — le lit d'ambiance : la carte sélectionnée, révélée par une torche.
const PANEL_ARENE := "panneau_arene"

## Phrase portée par une entrée grisée. Dire « pas encore fait » vaut mieux que
## masquer : une entrée absente laisse croire que la fonction n'existera jamais,
## et une entrée retirée du parcours du curseur fait douter du bouton d'à côté.
const NOT_YET := "Pas encore disponible."

# ---------------------------------------------------------------------------
# CLASSES INTERNES
# ---------------------------------------------------------------------------

class CircularCooldown extends Control:
	var progress: float = 1.0
	var color: Color = Charte.HALOGENE
	## V4.4 — secousse du tir à sec, en secondes restantes. Le tremblement est
	## dessiné et non appliqué à `position` : ce widget vit dans un conteneur, qui
	## lui réimposerait sa place à la frame suivante.
	var secousse: float = 0.0

	func _process(delta: float) -> void:
		if secousse > 0.0:
			secousse = maxf(0.0, secousse - delta)
			queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		if secousse > 0.0:
			# Amplitude décroissante : un tremblement constant ressemblerait à un
			# défaut d'affichage, pas à un refus.
			var a := secousse * 9.0
			center += Vector2(randf_range(-a, a), randf_range(-a, a))
		var radius := minf(size.x, size.y) / 2.0 - 4.0
		draw_arc(center, radius, 0, TAU, 32, Charte.LINE, 4.0, true)
		if progress > 0.0:
			draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + progress * TAU, 32, color, 4.0, true)

	func set_progress(p: float) -> void:
		if p != progress:
			progress = p
			queue_redraw()


## Liseré néon animé qui matérialise le focus d'un joueur.
## Il suit sa cible en douceur : le déplacement du curseur devient lisible même
## quand deux joueurs bougent en même temps.
class NeonFocusRing extends Panel:
	var neon: Color = Charte.ACIER
	var target_rect: Rect2 = Rect2()

	var _style: StyleBoxFlat
	var _time: float = 0.0
	var _snap: bool = true

	func _init(tint: Color = Charte.ACIER) -> void:
		neon = tint
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_style = StyleBoxFlat.new()
		_style.draw_center = false
		_style.set_border_width_all(3)
		_style.border_color = tint
		_style.set_corner_radius_all(10)
		_style.shadow_size = 10
		_style.shadow_color = Color(tint.r, tint.g, tint.b, 0.4)
		add_theme_stylebox_override("panel", _style)

	func _ready() -> void:
		set_as_top_level(true)

	## Définit la zone à encadrer. `snap` téléporte au lieu d'interpoler.
	func aim(rect: Rect2, snap: bool = false) -> void:
		target_rect = rect
		if snap:
			_snap = true

	func _process(delta: float) -> void:
		_time += delta
		var wave := 0.5 + 0.5 * sin(_time * 6.0)
		_style.border_color = neon.lerp(Charte.HALOGENE, 0.45 * wave)
		_style.shadow_size = int(roundf(lerpf(6.0, 16.0, wave)))
		_style.shadow_color = Color(neon.r, neon.g, neon.b, 0.22 + 0.33 * wave)

		if _snap:
			_snap = false
			global_position = target_rect.position
			size = target_rect.size
			return

		var t := clampf(delta * 22.0, 0.0, 1.0)
		global_position = global_position.lerp(target_rect.position, t)
		size = size.lerp(target_rect.size, t)

# ---------------------------------------------------------------------------
# HUD DE MATCH
# ---------------------------------------------------------------------------

## Conteneur racine du HUD de match (jauges, chrono, indicateurs).
## Masqué hors match : sans ça les panneaux joueurs restent visibles
## derrière le menu, dans les coins que la fenêtre de menu ne couvre pas.
var match_hud: MarginContainer
## Les deux panneaux de HUD et leur rangée, pour pouvoir n'en montrer qu'un et le
## déplacer. Voir `disposer_hud()`.
var hud_panneau_p1: Control
var hud_panneau_p2: Control
var hud_rangee: HBoxContainer
var p1_panel: PanelContainer
var p2_panel: PanelContainer

var p1_hp: ProgressBar
var p1_hp_bg: ProgressBar
var p1_cd: CircularCooldown
var p1_cd_label: Label
var p1_torch: PanelContainer
var p1_dazzle: ColorRect

var p2_hp: ProgressBar
var p2_hp_bg: ProgressBar
var p2_cd: CircularCooldown
var p2_cd_label: Label
var p2_torch: PanelContainer
var p2_dazzle: ColorRect

var time_label: Label
var waiting_label: Label
var center_line: Panel
var network_status_label: Label
var ping_label: Label
var countdown_label: Label

# Dernier chiffre affiché par le décompte : sert à ne rejouer l'animation qu'au
# changement de seconde.
var _countdown_shown: int = -1
var _local_ip_cache: String = ""

var p1_shake_time: float = 0.0
var p2_shake_time: float = 0.0
var shake_intensity: float = 10.0

var p1_target_hp: float = 100.0
var p2_target_hp: float = 100.0
var p1_bg_hp: float = 100.0
var p2_bg_hp: float = 100.0

# ---------------------------------------------------------------------------
# DIALOGUE MODAL
# ---------------------------------------------------------------------------

## DA4.17 — la gravité d'un message, qui décide de sa teinte.
enum Registre {
	## Ce qui se dit sans que rien n'aille mal : un appariement, un état.
	INFORMATION,
	## Ce qui interrompt sans être une faute : une déconnexion, un refus.
	ATTENTION,
	## Ce qui a échoué et empêche de continuer.
	FAUTE,
}

var dialog_panel: PanelContainer
var _dialog_style: StyleBoxFlat
var dialog_title: Label
var dialog_message: Label
var dialog_btn: Button
var _previous_focus: Control

# ---------------------------------------------------------------------------
# MENU
# ---------------------------------------------------------------------------

var game_over_panel: PanelContainer
var game_over_title: Label
var game_over_score: Label
## DA4.7 — le bilan composé de fin de match. Partage la boîte de `game_over_score` :
## les deux ne coexistent jamais.
var bilan: HBoxContainer
var bilan_p1: Label
var bilan_p2: Label
var bilan_serie: Label

## Ossature de navigation. Elle a remplacé la barre d'onglets à la Phase 5 :
## un écran, un sujet.
var hub: MenuHub
## Écrans autonomes (`HubScreen`) par identifiant. Ils ne se connaissent pas.
var _screens: Dictionary = {}
## Le classement vit hors de l'arborescence : il se lit dans le panneau de droite.
var _leaderboard: ScreenLeaderboard

# --- Onglet PROFIL ---

## Vague M — la vitrine. Deux effets de menu, chacun dans son fichier : ils
## n'ont rien à faire dans un `ui.gd` de trois mille lignes, et chacun se coupe
## seul par sa ligne d'`effect_policy`.
var menu_gnomon: MenuGnomon
## L'enseigne dessinée qui recouvre le titre quand il porte le nom du jeu.
var menu_enseigne: TextureRect
var menu_after_image: MenuAfterImage
var menu_torch: MenuTorch
var menu_watcher: MenuWatcher
var menu_passerby: MenuPasserby
var menu_tracer: MenuTracer
var menu_backdrop: MenuBackdrop
var menu_title: MenuTitle
var menu_veil: MenuVeil
var menu_glass: MenuGlass
## DA4.18 — le lit d'ambiance du cadre de droite : la carte sous la torche.
var menu_arene: MenuArene
var pause_veil: MenuVeil

## Les deux effets de la vitrine qui RELISENT L'ÉCRAN — le voile d'objectif (M15)
## et le second étage du verre fumé (M14) — sont coupés depuis le 2026-08-19.
##
## **Adrien a vu le cadre de droite entièrement noir.** Ce sont les deux seuls
## effets qui lisent `hint_screen_texture` dans les menus, et les deux seuls que
## j'ai validés **au banc sans jamais les regarder** : j'ai mesuré ce qu'ils
## coûtaient, jamais ce qu'ils montraient. Une mesure de coût ne dit rien d'une
## image — c'est la version « rendu » de tout ce que la veille a démonté sur les
## chiffres, et je l'ai commise le lendemain.
##
## Repasser à `true` remet les deux d'un coup ; ils se rallumeront **un par un**,
## et cette fois quelqu'un regardera l'écran avant de conclure.
const RELECTURE_ECRAN := false

## Vrai tant que l'écran de calibration est affiché.
##
## **Aucun effet de la vitrine n'y ajoute de lumière.** Le joueur y règle son
## point de noir sur un champ mesuré ; trois centièmes de luminance parasite
## décaleraient ce réglage — pour lui, et donc pour tous ceux qui calibrent de la
## même façon. Ce n'est pas une question d'esthétique, c'est la mesure.
var _calibration := false

## M10 — panneaux en cours d'extinction, et le tween qui les éteint.
##
## Un panneau qui s'éteint est **déjà fermé** pour tout ce qui décide quelque
## chose : le joueur a repris la main à l'instant où il a appuyé, et les dix
## centièmes de fondu ne sont plus qu'une image. Sans cette distinction,
## `is_pause_menu_open()` resterait vrai pendant le fondu et le joueur ne
## pourrait pas agir pendant un dixième de seconde après avoir repris — en
## ligne, où le monde n'a jamais cessé de tourner, c'est une mort.
var _extinction: Array[Control] = []
var _tweens_lumiere: Dictionary = {}
var _m10: float = 1.0

## Bandeau de recherche d'adversaire, au bord haut de l'écran. Hors du menu :
## la recherche continue quel que soit l'écran regardé.
var match_banner: MatchBanner
var map_gallery: MapGallery
var map_card: PanelContainer
var map_card_thumb: TextureRect
var map_card_name: Label
var map_card_meta: Label

var p1_weapon_group: ButtonGroup
var p2_weapon_group: ButtonGroup
var p1_vbox: VBoxContainer
var p2_vbox: VBoxContainer
var weapon_hbox: HBoxContainer

var p1_btn1: Button
var p1_btn2: Button
var p1_btn3: Button
var p1_btn4: Button
var p2_btn1: Button
var p2_btn2: Button
var p2_btn3: Button
var p2_btn4: Button

var mode_group: ButtonGroup
## Intention de mode, posée par la navigation. Elle a remplacé la lecture de
## `button_pressed` sur des bascules : un état d'interface tenait lieu de
## décision, et six connexions de boutons n'arrivaient plus à le garder cohérent.
var _intended_mode: NetworkManager.GameMode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
var transport_hbox: HBoxContainer
var btn_transport_eos: Button
var btn_transport_lan: Button
var lobby_status_label: Label
var host_ip_row: HBoxContainer
## M7 aussi — l'adresse IP se grave comme le code de salon. C'est le même objet
## social : celui qu'on transmet à quelqu'un pour qu'il vienne jouer. En **mesure
## libre** : la longueur d'une IPv4 n'est pas connue d'avance, et un point dans
## une case de chiffre laisserait un trou.
var host_ip_engraver: MenuEngraver
var host_ip_prefix: Label
var lobby_code_row: HBoxContainer
## M7 — le code de salon se frappe caractère par caractère. Ce n'est plus un
## Label : six cases de largeur fixe, plus la coche de copie.
var lobby_code_engraver: MenuEngraver
var btn_copy_code: Button
var join_input: LineEdit
var ephemeral_banner: Label

var lobby_players_box: VBoxContainer
var lobby_player_host: Label
var lobby_player_guest: Label
var btn_open_lobby: Button
var btn_paste_code: Button
var btn_join_lobby: Button
var join_box: VBoxContainer
## Les entrées « PRÊT » des quatre salons, grisées tant qu'un second joueur
## est nécessaire et absent.
## **Le geste qui engage, et il vit dans le CADRE DE DROITE.**
##
## Arbitrage d'Adrien du 2026-08-24 : la colonne de gauche porte des
## destinations, le cadre porte ce qu'on y prépare **et l'action qui le
## consomme**. Un bouton « JOUER » à gauche pendant que le choix d'arme dont il
## dépend est à droite séparait le geste de son objet.
##
## **Un seul bouton pour huit écrans**, parce que le panneau lui-même est unique
## et partagé : c'est déjà `_refresh_lobby_block()` qui décide de ce qui s'y voit
## selon le mode. Son libellé et son action suivent l'écran, par `LANCEURS`.
##
## Ce que ça simplifie au passage, et ce n'est pas rien : `_ready_entries` et
## `_relance_entries` **disparaissent**. Le commentaire qui justifiait d'en tenir
## deux disait qu'elles existaient parce que les lanceurs étaient éparpillés sous
## des noms différents — « PRÊT » ici, « JOUER » là, et l'une des deux listes
## sautait le mode le plus joué. Un seul bouton, plus de liste à tenir d'accord.
var panel_launch: Button

## Ce que le bouton du cadre dit et fait, par écran : libellé de repos, action.
##
## Le libellé de repos n'est pas toujours celui qu'on lit — sur l'écran de fin,
## `_sync_launch_entries()` le remplace par celui de `btn_replay`, qui reste la
## source de vérité (« ✓ PRÊT », « Connexion au salon… »).
## Les clés sont les CONSTANTES d'écran, jamais leurs chaînes recopiées : un
## identifiant mal orthographié ne lèverait rien — `MenuHub.push()` refuse un
## écran inconnu en silence, et la table rendrait simplement un bouton muet.
const LANCEURS := {
	SCREEN_LOCAL: ["JOUER", "lancer"],
	SCREEN_HOST: ["PRÊT", "lancer"],
	SCREEN_JOIN: ["PRÊT", "lancer"],
	SCREEN_LOCAL_HOST: ["PRÊT", "lancer"],
	SCREEN_LOCAL_JOIN: ["PRÊT", "lancer"],
	SCREEN_FRIENDLY: ["CHERCHER UN MATCH", "chercher"],
	SCREEN_RANKED: ["CHERCHER UN MATCH", "chercher"],
	SCREEN_TRAINING: ["LANCER L'ENTRAÎNEMENT", "entrainement"],
}


## La respiration V3.1, vivante seulement sur l'écran de fin.
var _souffle_relance: Tween = null
## L'annonce du score V3.6. Retenue pour la même raison que la respiration : une
## animation qui survit à son écran se bat avec la suivante, et c'est la première
## qui gagne — le score restait teinté du vainqueur précédent.
var _annonce_score: Tween = null

## La file visée par l'écran courant. Le grisage des armes en dépend : hors
## compétitif le socle entier est offert, en compétitif la sélection du rang.
var _weapon_context_ranked: bool = false

## La fenêtre de choix d'un match apparié : panneau centré, modal, par-dessus ce
## que le joueur avait sous les yeux.
var pick_panel: PanelContainer
var _pick_row: HBoxContainer
var _pick_reason: Label
var _pick_ready: Button
var _pick_buttons: Array[Button] = []
## Écran qui a ouvert le salon, pour savoir quand on le quitte. Vide = fermé.
var _lobby_screen: String = ""

## Panneau de pause — distinct du menu à onglets depuis la Phase 5.
##
## Trois rôles partageaient `game_over_panel` : menu principal, pause et écran de
## fin. Chaque différence se réglait en masquages à la volée, et tout écran ajouté
## en coûtait un de plus. La pause vit désormais dans son propre panneau, court,
## qui ne connaît ni les onglets ni la préparation de match.
var pause_panel: PanelContainer
var pause_title: Label
var pause_score_label: Label
var pause_time_label: Label
var btn_pause_resume: Button
var btn_pause_options: Button
var btn_pause_menu: Button
var btn_pause_quit: Button

## Les réglages restent joignables en cours de match : la pause emprunte l'onglet
## CONTRÔLES du menu, seul onglet montré dans ce cas. Ce détour disparaît à
## l'étape 4 de la Phase 5, quand les options auront leur propre écran.
var _options_from_pause: bool = false

var btn_actions: HBoxContainer
var btn_back: Button
var btn_replay: Button
var btn_main_menu: Button
var btn_quit: Button

var _is_rebinding: bool = false
var _action_to_rebind: String = ""
var _button_to_update: Button = null

var debug_panel: PanelContainer
var fps_label: Label
var net_debug_label: Label
## DA4.16 — les valeurs de la grille de diagnostic. Toutes en registre appareil,
## donc tabulaires : elles se remplacent quatre fois par seconde.
var dbg_ping: Label
var dbg_lumieres: Label
var dbg_particules: Label
var dbg_noeuds: Label
var dbg_cartes: Label
var debug_mode_active: bool = false
var _f3_was_pressed: bool = false

const DEBUG_SCAN_INTERVAL := 0.25
var _debug_scan_accum: float = 0.0
var _debug_light_count: int = 0
var _debug_arena_nodes: int = 0
## Inventaire des ressources absentes, rafraîchi au même rythme que les comptages
## de nœuds : la détection des bouche-trous ouvre des fichiers pour en lire la
## taille, ce qui ne doit pas arriver à chaque frame.
var _assets_summary: String = ""

var _is_main_menu: bool = true

# ---------------------------------------------------------------------------
# KILLCAM
# ---------------------------------------------------------------------------

var killcam_overlay: ColorRect
## V6.1 — tension courante de la bande, lissée vers sa cible.
var _killcam_tension: float = 0.0
## V6.5 — images d'inversion restantes. Compté en IMAGES et non en secondes,
## parce que l'effet est un clignement du rendu : à 60 comme à 240 fps, ce sont
## deux images qui doivent basculer, pas une durée qui en couvrirait huit.
var _killcam_negatif: int = 0
## L'image de rejeu vue au passage précédent, pour ne déclencher qu'au
## FRANCHISSEMENT de l'impact. Le rejeu peut piétiner sur une image pendant le
## ralenti extrême — comparer une position à un seuil déclencherait alors à
## chaque frame.
var _killcam_derniere_image: int = -1
var killcam_container: Control
var killcam_label_shadow1: Label
var killcam_label_shadow2: Label
var killcam_timecode: Label
var killcam_label: Label
var _killcam_glitch_timer: float = 0.0

# ---------------------------------------------------------------------------
# NAVIGATION
# ---------------------------------------------------------------------------

var p1_focus: Control
var p2_focus: Control
var p1_cursor: NeonFocusRing
var p2_cursor: NeonFocusRing


# ===========================================================================
# CYCLE DE VIE
# ===========================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_disable_ui_joystick()
	_build_hud()
	_build_killcam()
	_build_menu()
	_build_pause_menu()
	_build_pick_panel()
	_build_dialog()
	_build_status_bar()
	_build_countdown()
	_build_debug_panel()

	p1_cursor = NeonFocusRing.new(COLOR_P1)
	add_child(p1_cursor)
	p2_cursor = NeonFocusRing.new(COLOR_P2)
	add_child(p2_cursor)

	MapData.map_selected.connect(func(_id: String) -> void: _refresh_map_card())
	MapData.catalog_changed.connect(_refresh_map_card)
	_refresh_map_card()

	_wire_buttons(self)

## Le stick gauche pilote les curseurs joueurs : il ne doit pas déplacer en plus
## le focus natif de Godot, sous peine de double déplacement.
func _disable_ui_joystick() -> void:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadMotion:
					InputMap.action_erase_event(action, event)

## Branche le son et l'à-coup d'échelle sur tous les boutons du menu, ainsi que
## le survol souris qui déplace la sélection principale (J1).
## La galerie est exclue : elle gère ses propres retours, y compris sur les
## tuiles créées dynamiquement après ce parcours.
func _wire_buttons(node: Node) -> void:
	if node is MapGallery:
		return
	var btn := node as BaseButton
	if btn != null:
		btn.pressed.connect(_on_any_button_pressed.bind(btn))
		btn.mouse_entered.connect(_on_button_hovered.bind(btn))
	for child in node.get_children():
		_wire_buttons(child)

func _on_any_button_pressed(btn: BaseButton) -> void:
	# M9 — la flamme monte d'un cran à chaque appui. Tant que les sons d'interface
	# manquent, c'est la seule conséquence sensible d'un geste.
	if menu_torch != null:
		menu_torch.palpiter()
	# M8 — seul le geste qui engage une partie tire. Si tout tirait, plus rien ne
	# serait décisif : c'est la marque posée par `make_entry`, pas le hasard du
	# bouton, qui décide.
	if menu_tracer != null and bool(btn.get_meta(MenuHub.META_LAUNCHER, false)):
		var zone := (btn as Control).get_global_rect()
		# Au bord droit, là où les entrées de destination portent leur chevron :
		# le lanceur n'en a pas, mais c'est de là que part le mouvement.
		menu_tracer.tirer(Vector2(zone.end.x - GAP_S, zone.get_center().y),
			1.0, COLOR_P1)
	AudioManager.play_button_click()
	_pulse_press(btn)

## La souris pilote toujours la sélection principale (J1), jamais celle de J2 —
## sans quoi un simple passage de curseur volerait un bouton réservé à J2 (le
## râtelier d'armes en 1v1 local écran partagé).
func _on_button_hovered(btn: BaseButton) -> void:
	if not _is_focus_usable(btn):
		return
	var owner_id := int(btn.get_meta(META_NAV_OWNER, -1))
	if owner_id >= 0 and owner_id != 0:
		return
	_set_focus(0, btn)

## Petit à-coup d'échelle : retour visuel immédiat sur chaque appui.
func _pulse_press(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size / 2.0
	# L'enfoncement part vite (SORTIE, durée courte), le retour rebondit une fois
	# (REBOND). Les deux durées viennent de la charte : un appui qui répond en
	# moins de 90 ms paraît ignoré, au-delà de 180 il paraît mou.
	var tween := create_tween()
	Charte.animer(tween, control, "scale", Vector2.ONE, Vector2(0.94, 0.94),
		Charte.D_COURT, Charte.Courbe.SORTIE)
	Charte.animer(tween, control, "scale", Vector2(0.94, 0.94), Vector2.ONE,
		Charte.D_MOYEN, Charte.Courbe.REBOND)

# ===========================================================================
# BOUCLE
# ===========================================================================

func _process(delta: float) -> void:
	_update_network_status()
	_sync_launch_entries()
	_update_focus_rings()
	_update_health_trails(delta)
	_update_shake(delta)
	_update_debug(delta)
	_update_killcam(delta)

func _update_network_status() -> void:
	var connected := false
	var connecting := false
	if multiplayer.has_multiplayer_peer():
		var status := multiplayer.multiplayer_peer.get_connection_status()
		connected = status == MultiplayerPeer.CONNECTION_CONNECTED
		connecting = status == MultiplayerPeer.CONNECTION_CONNECTING

	# Le voyant du lien, sur la triade d'instrument. Il portait `Color.RED`,
	# `Color.GREEN` et `Color.YELLOW` — trois primaires pures, c'est-à-dire trois
	# fois « personne n'a choisi », sur le seul indicateur qui dit si le match
	# tient.
	var tint := Charte.ETAT_FAUTE
	if connected:
		tint = Charte.ETAT_OK
	elif connecting:
		tint = Charte.ETAT_ATTENTION
	network_status_label.add_theme_color_override("font_color", tint)

	# Le format technique n'est plus lisible que par un développeur : il reste
	# accessible en mode debug (F3), le joueur voit des états compréhensibles.
	if debug_mode_active:
		network_status_label.text = _technical_network_status(connected, connecting)
	else:
		network_status_label.text = _human_network_status(connected, connecting)

	_update_ping_label()

func _technical_network_status(connected: bool, connecting: bool) -> String:
	var mode_str := "[LOCAL]"
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		mode_str = "[ONLINE_HOST]"
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		mode_str = "[ONLINE_CLIENT]"

	var conn_str := "Déconnecté"
	if connected:
		conn_str = "Connecté (Peers: %d)" % multiplayer.get_peers().size()
	elif connecting:
		conn_str = "En attente (Connexion...)"

	var gs := get_tree().get_first_node_in_group("game_state")
	var situation := "Menu"
	if gs:
		if gs.sandbox_mode:
			situation = "Sandbox (Attente J2)"
		elif gs.round_active:
			situation = "Match en cours"
		elif gs.game_over:
			situation = "Attente Rematch"
		elif ReplaySystem.playing_back:
			situation = "Killcam"

	return "%s | %s | %s" % [mode_str, conn_str, situation]

## Statut destiné au joueur : ce qu'il doit faire ou attendre, rien d'autre.
## Vide en local, où il n'y a rien à signaler.
func _human_network_status(connected: bool, connecting: bool) -> String:
	var gs := get_tree().get_first_node_in_group("game_state")
	var in_round: bool = gs != null and gs.round_active

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		if not connected or multiplayer.get_peers().is_empty():
			if NetworkManager.transport == NetworkManager.Transport.ENET:
				return "Salon créé — en attente d'un adversaire  ·  IP : %s" % local_ipv4()
			var code: String = NetworkManager.lobby_code
			if code.is_empty():
				return "Création du salon…"
			return "Salon créé — en attente d'un adversaire  ·  code : %s" % code
		if in_round:
			return "En jeu"
		if ReplaySystem.playing_back:
			return "Killcam"
		return "Adversaire trouvé !"

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		if connecting:
			return "Connexion au salon…"
		if not connected:
			return "Salon quitté"
		if in_round:
			return "En jeu"
		if ReplaySystem.playing_back:
			return "Killcam"
		return "Salon rejoint — en attente du lancement"

	return ""

## Pastille de latence : verte sous 60 ms, jaune sous 120, rouge au-delà.
func _update_ping_label() -> void:
	if not NetworkManager.has_rtt:
		ping_label.hide()
		return

	var rtt := int(round(NetworkManager.rtt_ms))
	var tint := Charte.ETAT_OK
	if rtt >= 120:
		tint = Charte.ETAT_FAUTE
	elif rtt >= 60:
		tint = Charte.ETAT_ATTENTION

	ping_label.text = "● %d ms" % rtt
	ping_label.add_theme_color_override("font_color", tint)
	ping_label.show()

## Place les deux liserés de focus. Un curseur dont la cible a disparu est
## réamorcé plutôt que masqué : le joueur n'est jamais bloqué.
func _update_focus_rings() -> void:
	if game_over_panel == null or p1_cursor == null or p2_cursor == null:
		return

	var menu_open := _panneau_ouvert(game_over_panel) \
		or _panneau_ouvert(pause_panel) \
		or (dialog_panel != null and dialog_panel.visible)
	if not menu_open:
		p1_cursor.hide()
		p2_cursor.hide()
		return

	if not _is_focus_usable(p1_focus):
		_seed_focus(0)
	if not _is_focus_usable(p2_focus):
		_seed_focus(1)

	# En ligne, chaque machine ne pilote qu'un joueur, et toujours avec les
	# commandes de J1 — le client compris, dont le P2 lit le périphérique 0.
	# C'est donc le curseur 0 qui reste visible des deux côtés ; la rangée qu'il
	# peut atteindre est fixée par _assign_weapon_nav_owner.
	var show_p1 := true
	var show_p2 := true
	if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		show_p2 = false
	elif _is_main_menu and _intended_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		show_p2 = false
	# Le curseur J2 n'existe que pour choisir son arme : ailleurs (carte,
	# lancer, retour…), la sélection de J1 suffit et reste seule visible.
	if show_p2 and not (p2_focus in [p2_btn1, p2_btn2, p2_btn3, p2_btn4]):
		show_p2 = false

	if show_p1 and _is_focus_usable(p1_focus):
		if not p1_cursor.visible:
			p1_cursor.show()
			p1_cursor.aim(p1_focus.get_global_rect(), true)
		else:
			p1_cursor.aim(p1_focus.get_global_rect())
	else:
		p1_cursor.hide()

	if show_p2 and _is_focus_usable(p2_focus):
		var rect := p2_focus.get_global_rect()
		# Les deux joueurs sur la même cible : on décale J2 pour que les deux
		# liserés restent lisibles.
		if p1_focus == p2_focus and p1_cursor.visible:
			rect = rect.grow(4.0)
		if not p2_cursor.visible:
			p2_cursor.show()
			p2_cursor.aim(rect, true)
		else:
			p2_cursor.aim(rect)
	else:
		p2_cursor.hide()

func _update_health_trails(delta: float) -> void:
	if p1_bg_hp > p1_target_hp:
		p1_bg_hp = maxf(p1_target_hp, p1_bg_hp - 30.0 * delta)
		p1_hp_bg.value = p1_bg_hp
	elif p1_bg_hp < p1_target_hp:
		p1_bg_hp = p1_target_hp
		p1_hp_bg.value = p1_bg_hp

	if p2_bg_hp > p2_target_hp:
		p2_bg_hp = maxf(p2_target_hp, p2_bg_hp - 30.0 * delta)
		p2_hp_bg.value = p2_bg_hp
	elif p2_bg_hp < p2_target_hp:
		p2_bg_hp = p2_target_hp
		p2_hp_bg.value = p2_bg_hp

func _update_shake(delta: float) -> void:
	if p1_shake_time > 0.0:
		p1_shake_time -= delta
		p1_panel.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		p1_panel.position = Vector2.ZERO

	if p2_shake_time > 0.0:
		p2_shake_time -= delta
		p2_panel.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		p2_panel.position = Vector2.ZERO

func _update_debug(_delta: float) -> void:
	var f3_pressed := Input.is_physical_key_pressed(KEY_F3)
	if f3_pressed and not _f3_was_pressed:
		debug_mode_active = not debug_mode_active
		debug_panel.visible = debug_mode_active
	_f3_was_pressed = f3_pressed

	if not debug_mode_active:
		return

	# Le comptage des nœuds parcourt l'arbre : à 4 Hz il est indolore, à chaque
	# frame il fausserait la mesure qu'il sert à faire.
	_debug_scan_accum += _delta
	if _debug_scan_accum >= DEBUG_SCAN_INTERVAL:
		_debug_scan_accum = 0.0
		_rescan_debug_counts()
		_assets_summary = AssetManifest.summary()

	var gs := get_parent()
	var particles := 0
	var cap := 0
	if gs is GameState and is_instance_valid(gs.particle_pool):
		particles = gs.particle_pool.active_count()
		cap = ParticlePool.MAX_ACTIVE

	# **Les deux seuils du jeu, et ils ne sont pas choisis ici.** 120 images/s est
	# la cible du banc de cadence (`bench_framerate`, « 1 % bas ≥ 120 fps ») ; 60
	# et 120 ms sont exactement les paliers que `_update_ping_label()` emploie déjà
	# pour le HUD. Un panneau de diagnostic qui aurait ses propres seuils dirait
	# « ça va » pendant que le HUD dit « attention ».
	var fps: int = Engine.get_frames_per_second()
	fps_label.text = str(fps)
	fps_label.add_theme_color_override("font_color",
		_teinte_de_mesure(float(fps), 120.0, 60.0))

	if NetworkManager.has_rtt:
		var rtt: float = round(NetworkManager.rtt_ms)
		dbg_ping.text = "%d ms" % int(rtt)
		dbg_ping.add_theme_color_override("font_color",
			_teinte_de_mesure(rtt, 60.0, 120.0, false))
	else:
		dbg_ping.text = "—"
		dbg_ping.add_theme_color_override("font_color", COLOR_DIM)

	dbg_lumieres.text = str(_debug_light_count)
	# La saturation du bassin de particules est la seule de ces valeurs qui puisse
	# dégrader le jeu sans qu'on le voie : elle se teinte donc, comme les images
	# par seconde.
	dbg_particules.text = "%d / %d" % [particles, cap]
	dbg_particules.add_theme_color_override("font_color",
		_teinte_de_mesure(float(particles), float(cap) * 0.6, float(cap) * 0.9, false)
		if cap > 0 else COLOR_ACCENT)
	dbg_noeuds.text = str(_debug_arena_nodes)
	dbg_cartes.text = str(MapData.list_maps().size())
	net_debug_label.text = _network_debug_line()
	var p2_path := _p2_path_label()
	if p2_path != "":
		net_debug_label.text += "\n" + p2_path

	# Ressources manquantes. Le code qui joue ces sons est écrit et reste
	# silencieux quand le fichier n'est pas là : sans cette ligne, un son absent
	# serait indiscernable d'un son qu'on a choisi de ne pas jouer.
	# Recalculé à 4 Hz comme le reste — la détection des bouche-trous ouvre les
	# fichiers pour en lire la taille, ce qui n'a rien à faire dans une frame.
	if _assets_summary != "":
		net_debug_label.text += "\n" + _assets_summary

## Ligne réseau du panneau F3 : de quoi diagnostiquer une session en ligne sans
## sortir du jeu — par où passe le lien, à travers quel NAT, sous quelle identité.
func _network_debug_line() -> String:
	if NetworkManager.transport == NetworkManager.Transport.ENET:
		return "RÉSEAU | Transport ENet (LAN) | Pairs %d" % multiplayer.get_peers().size()

	var parts: Array[String] = ["RÉSEAU | Transport EOS"]
	parts.append(NetworkManager.eos_state_label())
	if not NetworkManager.lobby_code.is_empty():
		parts.append("Salon %s" % NetworkManager.lobby_code)
	parts.append("Lien %s" % _eos_network_type_label())
	parts.append("NAT %s" % _eos_nat_label())
	var puid: String = NetworkManager.eos_puid
	if not puid.is_empty():
		parts.append("PUID %s…%s" % [puid.substr(0, 6), puid.right(4)])
	if NetworkManager.is_ephemeral_identity():
		parts.append("ÉPHÉMÈRE")
	parts.append(_input_relay_label())
	return " | ".join(parts)

## Santé de la remontée des commandes du client, côté hôte.
##
## Deux gardes peuvent rejeter ces paquets sans le dire — un identifiant de pair
## qui ne correspond pas, un numéro de séquence qui ne progresse pas — et le
## symptôme est le même dans les deux cas : l'adversaire figé sur son point
## d'apparition, alors que le lien et le ping restent parfaitement sains.
func _network_input_health() -> String:
	var gs := get_parent()
	if not (gs is GameState) or not is_instance_valid(gs.p2):
		return ""
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST:
			return "CMD J2 pair=%d reçues=%d rejetées=%d" % [
				gs.client_peer_id, gs.p2.inputs_accepted, gs.p2.inputs_rejected,
			]
		NetworkManager.GameMode.ONLINE_CLIENT:
			# `visé` est l'identifiant réel de l'hôte vu d'ici. Les commandes
			# partent, elles, vers l'identifiant 1 codé en dur : si les deux
			# diffèrent, elles s'adressent à un pair qui n'existe pas.
			return "CMD envoyées=%d visé=%d moi=%d" % [
				gs.p2.inputs_sent, gs.p2.inputs_target, multiplayer.get_unique_id(),
			]
	return ""

## Chemin du nœud J2 dans l'arbre. Un RPC de scène ne se route que par ce
## chemin : s'il diffère d'une machine à l'autre, le message est jeté à
## l'arrivée sans jamais atteindre la fonction visée.
func _p2_path_label() -> String:
	var gs := get_parent()
	if not (gs is GameState) or not is_instance_valid(gs.p2):
		return ""
	if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		return ""
	return "CHEMIN J2 %s" % String(gs.p2.get_path())

func _input_relay_label() -> String:
	var health := _network_input_health()
	return health if health != "" else "—"

## Direct ou relayé : la différence se paie en latence, et seul le SDK la connaît.
func _eos_network_type_label() -> String:
	match NetworkManager.eos_network_type:
		EOS.P2P.NetworkType.DirectConnection: return "DIRECT"
		EOS.P2P.NetworkType.RelayedConnection: return "RELAYÉ"
		EOS.P2P.NetworkType.NoConnection: return "AUCUN"
	return "—"

func _eos_nat_label() -> String:
	match NetworkManager.eos_nat_type:
		EOS.P2P.NATType.Open: return "ouvert"
		EOS.P2P.NATType.Moderate: return "modéré"
		EOS.P2P.NATType.Strict: return "strict"
	return "inconnu"

## Recompte les PointLight2D actives et les nœuds de l'arène.
func _rescan_debug_counts() -> void:
	_debug_light_count = 0
	_debug_arena_nodes = 0
	var gs := get_parent()
	if not (gs is GameState) or not is_instance_valid(gs.arena):
		return
	var world: Node = (gs.arena as Node).get_parent()
	if world == null:
		return
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		_debug_arena_nodes += 1
		if node is PointLight2D and (node as PointLight2D).is_visible_in_tree() \
				and (node as PointLight2D).enabled:
			_debug_light_count += 1
		for child in node.get_children():
			stack.append(child)

func _update_killcam(delta: float) -> void:
	if killcam_container == null or not killcam_container.visible:
		return

	var ms := Time.get_ticks_msec()
	var sec := (ms / 1000) % 60
	var mins := (ms / 60000) % 60
	var frames := Engine.get_frames_drawn() % 60

	if (ms / 500) % 2 == 0:
		killcam_timecode.text = "REC •\n%02d:%02d:%02d" % [mins, sec, frames]
		killcam_timecode.add_theme_color_override("font_color", Color(Charte.ROUGE, 0.8))
	else:
		killcam_timecode.text = "REC  \n%02d:%02d:%02d" % [mins, sec, frames]
		killcam_timecode.add_theme_color_override("font_color", Color(Charte.HALOGENE, 0.8))

	if killcam_overlay.material:
		killcam_overlay.material.set_shader_parameter("time", ms / 1000.0)
		# V6.1 — la bande souffre pendant le ralenti et se calme à l'impact.
		# Lissée vers sa cible plutôt que posée : le ralenti accélère par paliers
		# (courbe de V2.1), et suivre `time_scale` au pixel ferait clignoter le
		# grain à chaque changement de palier.
		var cible := tension_killcam(Engine.time_scale)
		_killcam_tension = lerpf(_killcam_tension, cible, clampf(delta * 6.0, 0.0, 1.0))
		killcam_overlay.material.set_shader_parameter("tension", _killcam_tension)
		# V6.5 — deux images de négatif au franchissement de l'impact.
		var rejeu := get_node_or_null(^"/root/ReplaySystem")
		if rejeu != null:
			var image := int(rejeu.get("playback_index"))
			var impact := int(rejeu.get("impact_frame"))
			if impact >= 0 and _killcam_derniere_image < impact and image >= impact:
				_killcam_negatif = 2
			_killcam_derniere_image = image
		if _killcam_negatif > 0:
			_killcam_negatif -= 1
			killcam_overlay.material.set_shader_parameter("negatif", 1.0)
		else:
			killcam_overlay.material.set_shader_parameter("negatif", 0.0)

	_killcam_glitch_timer -= delta
	if _killcam_glitch_timer <= 0.0:
		if randf() > 0.8:
			killcam_label_shadow1.position = Vector2(randf_range(-10, 10), randf_range(-5, 5))
			killcam_label_shadow2.position = Vector2(randf_range(-10, 10), randf_range(-5, 5))
			killcam_label.position = Vector2(randf_range(-3, 3), 0)
			_killcam_glitch_timer = randf_range(0.05, 0.1)
		else:
			killcam_label_shadow1.position = Vector2(-3, 0)
			killcam_label_shadow2.position = Vector2(3, 0)
			killcam_label.position = Vector2.ZERO
			_killcam_glitch_timer = randf_range(0.1, 0.3)
		killcam_label.modulate.a = 0.8 + 0.2 * sin(ms * 0.01)

# ===========================================================================
# NAVIGATION — RÉSOLVEUR GÉOMÉTRIQUE
# ===========================================================================
#
# Choix d'implémentation : un résolveur maison plutôt que focus_neighbor_*.
#   • Le focus natif de Godot est unique par viewport ; le jeu a deux curseurs
#     simultanés, il est donc inutilisable tel quel.
#   • La galerie de cartes est une grille dont le nombre de colonnes dépend de
#     la largeur de la fenêtre et dont le contenu change à chaque import : tout
#     câblage explicite serait à refaire en permanence.
# Le résolveur ne lit que la position à l'écran des contrôles visibles : il
# s'adapte donc automatiquement à n'importe quelle disposition.

## Contrôles focusables offerts à un joueur dans l'état courant du menu.
func _nav_candidates(player: int) -> Array[Control]:
	var out: Array[Control] = []
	if dialog_panel != null and dialog_panel.visible:
		if dialog_btn != null:
			out.append(dialog_btn)
		return out
	# La pause est modale : tant qu'elle est ouverte, elle est le seul terrain de
	# navigation. Sans ce retour anticipé, le curseur filerait dans les onglets du
	# menu, cachés mais toujours dans l'arbre.
	# La fenêtre de choix prend le pas sur TOUT, pause comprise : elle vit sur un
	# décompte de dix secondes, et laisser le curseur ailleurs pendant ce temps
	# reviendrait à choisir son arme à l'aveugle.
	if pick_panel != null and pick_panel.visible:
		_collect_focusables(pick_panel, player, out)
		return out
	if _panneau_ouvert(pause_panel):
		_collect_focusables(pause_panel, player, out)
		return out
	# Le terrain de navigation est le corps de l'écran courant. Les autres sont
	# cachés, donc hors d'atteinte : c'est l'ossature du hub qui le garantit.
	var body := hub.body_of(hub.current_id()) if hub != null else null
	if body != null:
		_collect_focusables(body, player, out)
	# ET le panneau de droite, qui n'est pas dans le corps de l'écran mais dans
	# l'autre colonne. Il en était absent : tout ce qui y vivait — le choix d'arme,
	# le champ où l'on tape le code du salon — se cliquait à la souris et restait
	# hors d'atteinte des deux curseurs. Seuls les panneaux visibles remontent,
	# `_collect_focusables` s'arrêtant sur un contrôle caché.
	if hub != null and hub.detail_host() != null:
		_collect_focusables(hub.detail_host(), player, out)
	if btn_actions != null:
		_collect_focusables(btn_actions, player, out)
	# Le bandeau de recherche vit hors du menu, collé au bord haut : il n'est dans
	# aucun des deux terrains ci-dessus. Sans cette ligne, annuler une recherche ne
	# serait possible qu'à la souris.
	if match_banner != null and player == 0:
		out.append_array(match_banner.focusables())
	return out

func _collect_focusables(node: Node, player: int, out: Array[Control]) -> void:
	var control := node as Control
	if control != null:
		if not control.visible:
			return
		if control.focus_mode != Control.FOCUS_NONE:
			var owner_id := int(control.get_meta(META_NAV_OWNER, -1))
			var reserved := owner_id >= 0 and owner_id != player
			var btn := control as BaseButton
			var locked := btn != null and btn.disabled
			if not reserved and not locked:
				out.append(control)
			# Un contrôle focusable n'héberge jamais d'autre contrôle focusable.
			return
	for child in node.get_children():
		_collect_focusables(child, player, out)

## Voisin le plus proche dans une direction.
## `strict` impose un cône à 45° ; un second passage l'élargit pour ne jamais
## laisser un curseur bloqué dans un coin de l'écran.
func _closest_in_direction(from: Control, dir: Vector2,
		candidates: Array[Control], strict: bool) -> Control:
	var from_rect := from.get_global_rect()
	var origin := from_rect.get_center()
	var perp := Vector2(dir.y, -dir.x)
	var horizontal := absf(dir.x) > 0.5

	var best: Control = null
	var best_score := INF

	for candidate in candidates:
		if candidate == from:
			continue
		var rect := candidate.get_global_rect()
		var delta := rect.get_center() - origin
		var along := delta.dot(dir)
		if along <= 1.0:
			continue
		var side := absf(delta.dot(perp))
		if strict and side >= along:
			continue

		# Écart perpendiculaire réel entre les deux rectangles : deux contrôles
		# de la même colonne ont un écart nul, donc la priorité absolue.
		var gap := 0.0
		if horizontal:
			gap = maxf(0.0, maxf(from_rect.position.y - rect.end.y, rect.position.y - from_rect.end.y))
		else:
			gap = maxf(0.0, maxf(from_rect.position.x - rect.end.x, rect.position.x - from_rect.end.x))

		var score := along + gap * 4.0 + side * 0.25
		if score < best_score:
			best_score = score
			best = candidate

	return best

func _navigate(player: int, dir: Vector2) -> void:
	var from := p1_focus if player == 0 else p2_focus
	if not _is_focus_usable(from):
		_seed_focus(player)
		return

	var candidates := _nav_candidates(player)
	var next := _closest_in_direction(from, dir, candidates, true)
	if next == null:
		next = _closest_in_direction(from, dir, candidates, false)
	if next == null:
		return
	_set_focus(player, next)

func _set_focus(player: int, control: Control, snap: bool = false) -> void:
	if control == null:
		return
	var precedent: Control = p1_focus if player == 0 else p2_focus
	if player == 0:
		p1_focus = control
		if p1_cursor != null:
			p1_cursor.aim(control.get_global_rect(), snap)
	else:
		p2_focus = control
		if p2_cursor != null:
			p2_cursor.aim(control.get_global_rect(), snap)

	# M9 — la torche suit la cible, et M3 referme les yeux : tout mouvement de
	# curseur est un signe de vie, et c'est le même signe pour les deux.
	var centre := control.get_global_rect().get_center()
	if menu_torch != null:
		menu_torch.viser(player, centre, COLOR_P1 if player == 0 else COLOR_P2)
	# M5 borde la lumière de M9 : il lui faut donc SON rayon, pas un autre. Le
	# déduire ailleurs décrocherait le grain du halo qu'il est censé ourler.
	if menu_backdrop != null:
		# `ui.gd` est un CanvasLayer : il n'a pas de rect à lui, il faut demander
		# la vue.
		var vue := get_viewport()
		if vue != null:
			menu_backdrop.viser(player, centre, MenuTorch.RAYON,
				vue.get_visible_rect().size)
	if menu_watcher != null:
		menu_watcher.reveiller()

	# M2 — la rémanence. La position **quittée** est confiée à la couche avant que
	# le curseur ne bouge, avec sa seule géométrie : le contrôle, lui, peut
	# disparaître pendant que son fantôme s'éteint.
	if menu_after_image != null and precedent != null and precedent != control \
			and is_instance_valid(precedent) and precedent.is_visible_in_tree():
		menu_after_image.laisser(precedent.get_global_rect(),
			COLOR_P1 if player == 0 else COLOR_P2)

	# Les deux curseurs sont maison : ils n'appellent pas `grab_focus()`, donc
	# `focus_entered` ne part jamais pour eux. Sans ce relais, le panneau de droite
	# et la description sous le titre ne suivraient que la souris — et la galerie
	# de cartes serait hors d'atteinte de qui joue à la manette.
	if hub != null and player == 0:
		hub.reveal_entry(control)

	if map_gallery != null and map_gallery.is_ancestor_of(control):
		map_gallery.reveal(control)

func _is_focus_usable(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree():
		return false
	var btn := control as BaseButton
	if btn != null and btn.disabled:
		return false
	return true

## Point d'entrée du focus pour un joueur, par ordre de priorité :
## métadonnée `nav_seed`, carte sélectionnée dans la galerie, puis le contrôle
## le plus en haut à gauche.
func _seed_focus(player: int) -> void:
	var candidates := _nav_candidates(player)
	if candidates.is_empty():
		if player == 0:
			p1_focus = null
		else:
			p2_focus = null
		return

	for candidate in candidates:
		var graine := int(candidate.get_meta(META_NAV_SEED, -1))
		if graine == player or graine == NAV_SEED_LES_DEUX:
			_set_focus(player, candidate, true)
			return

	# La galerie n'est plus un écran mais un panneau : c'est sa visibilité, et non
	# l'écran courant, qui dit si l'on est en train de choisir une arène.
	if map_gallery != null and map_gallery.is_visible_in_tree():
		var tile := map_gallery.selected_tile()
		if tile != null and candidates.has(tile):
			_set_focus(player, tile, true)
			return

	candidates.sort_custom(func(a: Control, b: Control) -> bool:
		var ra := a.get_global_rect().position
		var rb := b.get_global_rect().position
		if absf(ra.y - rb.y) > 4.0:
			return ra.y < rb.y
		return ra.x < rb.x
	)
	_set_focus(player, candidates[0], true)

## Déclenche le contrôle sous le curseur d'un joueur.
func _activate(player: int) -> void:
	var target := p1_focus if player == 0 else p2_focus
	if not _is_focus_usable(target):
		return

	var line_edit := target as LineEdit
	if line_edit != null:
		line_edit.grab_focus()
		return

	var btn := target as BaseButton
	if btn == null:
		return

	if btn.toggle_mode:
		if btn.button_group != null:
			btn.button_pressed = true
		else:
			btn.button_pressed = not btn.button_pressed
	# Le son et l'à-coup d'échelle sont branchés sur `pressed` (voir _wire_buttons).
	btn.pressed.emit()

# ===========================================================================
# CONSTRUCTION — HUD
# ===========================================================================

func _build_hud() -> void:
	var scanline := ColorRect.new()
	scanline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanline.color = Color(Charte.NOIR, 0.1)
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scanline)

	center_line = Panel.new()
	center_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center_line.size = Vector2(4, 2000)
	center_line.position = Vector2(-2, 0)
	var line_style := StyleBoxFlat.new()
	line_style.bg_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.8)
	line_style.shadow_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.5)
	line_style.shadow_size = 20
	center_line.add_theme_stylebox_override("panel", line_style)
	add_child(center_line)

	# Le voile d'éblouissement, une moitié d'écran chacun. Blanc plat et pas
	# pulsé : décision du 2026-08-18 (V5.3) — sous `gl_compatibility` il n'y a
	# pas de bloom, et faire battre l'alpha brouillerait la lecture du NIVEAU
	# d'éblouissement, qui est une information de duel, pas une décoration.
	# Son opacité passe par le curseur « Éblouissement » de l'écran des effets
	# (famille Monde, plancher 0,8 en classé) ; la pénalité de vitesse et de
	# visée, elle, n'est pas réglable — un curseur qui l'allégerait serait un
	# avantage compétitif déguisé en confort.
	#
	# **Il est monté AVANT le HUD, et l'ordre est la décision.** Ajouté après,
	# il peignait par-dessus la barre de vie, le cooldown et le chrono : à
	# saturation on ne lisait plus son PROPRE état. Or l'éblouissement doit
	# coûter la lecture du monde — c'est-à-dire de l'adversaire et de sa
	# lumière —, jamais celle de sa propre fiche : la première est le jeu, la
	# seconde n'est qu'une punition de plus, et elle ne se rattrape par aucune
	# compétence. Vu à l'écran le 2026-08-24, tranché par Adrien le jour même.
	#
	# Aucun test ne tient cet ordre, et il ne le peut pas facilement : ce qui
	# se voit n'a pas de nom dans le code (piège consigné le 2026-08-19). Ce
	# commentaire est donc le seul garde-fou — le voile doit rester au-dessus
	# de l'arène et au-dessous du HUD.
	var dazzle_hbox := HBoxContainer.new()
	dazzle_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dazzle_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dazzle_hbox.add_theme_constant_override("separation", 0)
	add_child(dazzle_hbox)

	p1_dazzle = ColorRect.new()
	p1_dazzle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1_dazzle.color = Color(Charte.HALOGENE, 0.0)
	p1_dazzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dazzle_hbox.add_child(p1_dazzle)

	p2_dazzle = ColorRect.new()
	p2_dazzle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p2_dazzle.color = Color(Charte.HALOGENE, 0.0)
	p2_dazzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dazzle_hbox.add_child(p2_dazzle)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", GAP_M)
	margin.add_theme_constant_override("margin_left", GAP_M)
	margin.add_theme_constant_override("margin_right", GAP_M)
	margin.add_theme_constant_override("margin_bottom", GAP_M)
	add_child(margin)
	match_hud = margin

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	hud_panneau_p1 = _build_player_hud(0)
	hud_panneau_p2 = _build_player_hud(1)
	hbox.add_child(hud_panneau_p1)
	hbox.add_child(_build_center_hud())
	hbox.add_child(hud_panneau_p2)
	hud_rangee = hbox

func _build_player_hud(player: int) -> Control:
	var tint := COLOR_P1 if player == 0 else COLOR_P2

	var wrapper := Control.new()
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if player == 0 else Control.SIZE_SHRINK_END
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.custom_minimum_size = Vector2(352, 152)

	var panel := _create_glow_panel(tint)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top", GAP_S)
	inner.add_theme_constant_override("margin_left", GAP_M)
	inner.add_theme_constant_override("margin_right", GAP_M)
	inner.add_theme_constant_override("margin_bottom", GAP_S)
	panel.add_child(inner)

	var hud := VBoxContainer.new()
	hud.add_theme_constant_override("separation", GAP_XS)
	inner.add_child(hud)

	var header := HBoxContainer.new()
	hud.add_child(header)

	var name_label := Label.new()
	name_label.text = "JOUEUR 1" if player == 0 else "JOUEUR 2"
	name_label.add_theme_font_size_override("font_size", T_TITRE)
	name_label.add_theme_color_override("font_color", tint)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if player == 1:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(name_label)

	var hp_label := Label.new()
	hp_label.text = "SANTÉ"
	hp_label.add_theme_font_size_override("font_size", T_MENTION)
	hp_label.add_theme_color_override("font_color", COLOR_DIM)
	hud.add_child(hp_label)

	var bars := _create_health_bars(tint)
	hud.add_child(bars["container"])

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", GAP_S)
	hud.add_child(bottom)

	var weapon := _create_weapon_indicator(tint)
	var torch := _create_torch_indicator()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if player == 0:
		bottom.add_child(weapon["container"])
		bottom.add_child(spacer)
		bottom.add_child(torch)
		p1_panel = panel
		p1_hp = bars["fg"]
		p1_hp_bg = bars["bg"]
		p1_cd = weapon["circle"]
		p1_cd_label = weapon["label"]
		p1_torch = torch
	else:
		bottom.add_child(torch)
		bottom.add_child(spacer)
		bottom.add_child(weapon["container"])
		p2_panel = panel
		p2_hp = bars["fg"]
		p2_hp_bg = bars["bg"]
		p2_cd = weapon["circle"]
		p2_cd_label = weapon["label"]
		p2_torch = torch

	return wrapper

func _build_center_hud() -> Control:
	var center_hud := VBoxContainer.new()
	center_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hud.alignment = BoxContainer.ALIGNMENT_BEGIN

	var panel := _create_glow_panel(Charte.ACIER * 0.42)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(208, 0)
	center_hud.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top", GAP_XS)
	inner.add_theme_constant_override("margin_left", GAP_S)
	inner.add_theme_constant_override("margin_right", GAP_S)
	inner.add_theme_constant_override("margin_bottom", GAP_XS)
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	inner.add_child(vbox)

	var title := Label.new()
	title.text = "CANDELA 2D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", T_MENTION)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	time_label = Label.new()
	time_label.text = "05:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# DA4.2 — **le compteur le plus exposé du jeu, et le seul qui bat.** Sous dix
	# secondes il pulse à la seconde ; une fonte non tabulaire ferait respirer sa
	# boîte en même temps que la pulsation, et les deux mouvements se
	# confondraient. Il reste donc à l'appareil, et `tools/test_habillage.gd`
	# mesure ses dix chiffres pour que ça ne dépende plus de ce commentaire.
	Charte.appareil(time_label, T_VERDICT)
	vbox.add_child(time_label)

	waiting_label = Label.new()
	waiting_label.text = "EN ATTENTE DU JOUEUR 2..."
	waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_label.add_theme_font_size_override("font_size", T_TITRE)
	waiting_label.add_theme_color_override("font_color", Charte.ETAT_OK)
	waiting_label.hide()
	vbox.add_child(waiting_label)

	return center_hud

func _create_glow_panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.SURFACE, 0.9)
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(12)
	style.shadow_color = color
	style.shadow_size = 15
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_health_bars(color: Color) -> Dictionary:
	var container := MarginContainer.new()
	container.custom_minimum_size = Vector2(0, 12)

	var bg_bar := ProgressBar.new()
	bg_bar.max_value = 100
	bg_bar.value = 100
	bg_bar.show_percentage = false
	bg_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(Charte.LINE, 0.5)
	bg_style.set_corner_radius_all(6)
	bg_bar.add_theme_stylebox_override("background", bg_style)

	var bg_fill := StyleBoxFlat.new()
	bg_fill.bg_color = Charte.ROUGE
	bg_fill.set_corner_radius_all(6)
	bg_bar.add_theme_stylebox_override("fill", bg_fill)

	var fg_bar := ProgressBar.new()
	fg_bar.max_value = 100
	fg_bar.value = 100
	fg_bar.show_percentage = false
	fg_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fg_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())

	var fg_fill := StyleBoxFlat.new()
	fg_fill.bg_color = color
	fg_fill.set_corner_radius_all(6)
	fg_fill.shadow_color = color
	fg_fill.shadow_size = 8
	fg_bar.add_theme_stylebox_override("fill", fg_fill)

	container.add_child(bg_bar)
	container.add_child(fg_bar)

	return {"container": container, "fg": fg_bar, "bg": bg_bar}

func _create_weapon_indicator(color: Color) -> Dictionary:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", GAP_S)

	var circle_container := MarginContainer.new()
	circle_container.custom_minimum_size = Vector2(40, 40)

	var circle := CircularCooldown.new()
	circle.color = color
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	circle_container.add_child(circle)

	var label := Label.new()
	label.text = "PRÊT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", T_MENTION)
	circle_container.add_child(label)

	var title := Label.new()
	title.text = "ARME"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", T_MENTION)
	title.add_theme_color_override("font_color", Charte.ACIER)

	container.add_child(circle_container)
	container.add_child(title)

	return {"container": container, "circle": circle, "label": label}

func _create_torch_indicator() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GAP_XS)
	margin.add_theme_constant_override("margin_right", GAP_XS)
	margin.add_theme_constant_override("margin_top", GAP_XXS)
	margin.add_theme_constant_override("margin_bottom", GAP_XXS)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", GAP_XS)
	margin.add_child(hbox)

	var icon := Label.new()
	icon.text = "🔦"
	icon.add_theme_font_size_override("font_size", T_MENTION)
	hbox.add_child(icon)

	var label := Label.new()
	label.text = "TORCHE"
	label.add_theme_font_size_override("font_size", T_MENTION)
	hbox.add_child(label)

	_set_torch_style(panel, false, Charte.HALOGENE)
	return panel

func _set_torch_style(panel: PanelContainer, active: bool, player_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)

	if active:
		style.bg_color = Color(Charte.LINE, 0.9)
		style.border_color = player_color
		style.shadow_color = player_color
		style.shadow_size = 5
	else:
		style.bg_color = Color(Charte.SURFACE, 0.8)
		style.border_color = Color(Charte.LINE, 1.0)
		style.shadow_size = 0

	panel.add_theme_stylebox_override("panel", style)

	var hbox := panel.get_child(0).get_child(0)
	var label := hbox.get_child(1) as Label
	if active:
		label.add_theme_color_override("font_color", Charte.HALOGENE)
	else:
		label.add_theme_color_override("font_color", Charte.DIM)

# ===========================================================================
# CONSTRUCTION — ANNEXES
# ===========================================================================

func _build_status_bar() -> void:
	network_status_label = Label.new()
	network_status_label.z_index = 100
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	network_status_label.add_theme_font_size_override("font_size", T_COURANT)
	network_status_label.add_theme_color_override("font_outline_color", Charte.NOIR)
	network_status_label.add_theme_constant_override("outline_size", 4)

	ping_label = Label.new()
	# DA4.2 — l'appareil, explicitement. Un compteur : il se réécrit à chaque
	# relevé de RTT, au milieu d'une rangée centrée dont il déplacerait les
	# voisins en changeant de largeur.
	Charte.appareil(ping_label, T_COURANT)
	ping_label.add_theme_color_override("font_outline_color", Charte.NOIR)
	ping_label.add_theme_constant_override("outline_size", 4)
	ping_label.hide()

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", GAP_S)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(network_status_label)
	status_row.add_child(ping_label)

	var status_margin := MarginContainer.new()
	status_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_margin.add_theme_constant_override("margin_bottom", GAP_XS)
	status_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_margin.add_child(status_row)
	add_child(status_margin)

## Décompte de départ, plein écran : il doit rester lisible par-dessus le HUD
## comme par-dessus l'arène.
func _build_countdown() -> void:
	countdown_label = Label.new()
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# DA4 — l'enseigne, et c'est le cas le plus net du jeu. Un chiffre seul qui
	# occupe l'écran n'est pas du texte, c'est un élément graphique : la charte le
	# dit déjà en faisant de `T_DECOMPTE` une dérivée plutôt qu'un septième cran.
	#
	# Aucun risque de tremblement malgré une fonte non tabulaire : le `Label` est
	# ancré en plein cadre et centré, donc chaque chiffre est cadré sur lui-même.
	# `3`, `2` et `1` n'ont pas à faire la même largeur — ils ne se comparent
	# jamais, ils se succèdent au même endroit.
	Charte.enseigne(countdown_label, T_DECOMPTE)
	countdown_label.add_theme_color_override("font_color", COLOR_GOLD)
	countdown_label.add_theme_color_override("font_outline_color", Charte.NOIR)
	countdown_label.add_theme_constant_override("outline_size", 16)
	countdown_label.z_index = 120
	countdown_label.hide()
	add_child(countdown_label)

## Piloté par GameState, qui tient le décompte partagé.
func set_countdown(value: float) -> void:
	if countdown_label == null:
		return
	if value <= 0.0:
		if _countdown_shown != -1:
			_countdown_shown = -1
			countdown_label.hide()
		return

	countdown_label.show()
	var n := ceili(value)
	if n == _countdown_shown:
		return
	_countdown_shown = n
	countdown_label.text = str(n)
	countdown_label.pivot_offset = countdown_label.size / 2.0
	countdown_label.scale = Vector2(1.7, 1.7)
	var tween := create_tween()
	tween.tween_property(countdown_label, "scale", Vector2.ONE, Charte.D_LONG) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## L'attente d'un adversaire est le moment où l'hôte a besoin de quoi l'inviter :
## son code de salon sur Internet, son adresse IP en réseau local.
func show_waiting_for_opponent() -> void:
	waiting_label.text = "EN ATTENTE DU JOUEUR 2…"
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		if NetworkManager.transport == NetworkManager.Transport.EOS:
			var code: String = NetworkManager.lobby_code
			waiting_label.text += "\nCODE DU SALON : %s" % (code if not code.is_empty() else "…")
		else:
			waiting_label.text += "\nVotre IP : %s" % local_ipv4()
	waiting_label.show()

## Première IPv4 non-loopback : l'adresse à communiquer sur un réseau local.
## Les adresses d'auto-configuration (169.254) sont écartées, elles ne servent
## à rien pour un adversaire.
func local_ipv4() -> String:
	if _local_ip_cache != "":
		return _local_ip_cache
	_local_ip_cache = "127.0.0.1"
	for addr in IP.get_local_addresses():
		var a := String(addr)
		if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		_local_ip_cache = a
		break
	return _local_ip_cache

## Ce que le joueur a saisi pour rejoindre. Le champ est unique, son sens
## dépend du transport : un code de salon sur Internet, une adresse IP en LAN.
func lobby_join_text() -> String:
	return join_input.text

func _build_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	debug_panel.offset_left = GAP_S
	debug_panel.offset_top = GAP_S
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_panel.hide()

	# DA4.16 — **le panneau de diagnostic passe à la couleur de l'instrument.**
	#
	# Il était bordé d'`AMBRE`, et `AMBRE` veut dire *ce qui appelle* : c'est la
	# couleur du feu, de la mise en garde, du chrono de dernière minute. Un cadre
	# de diagnostic ouvert en permanence pendant qu'on joue n'appelle rien — il
	# se consulte. Il emprunte donc `LINE` et `ACIER`, la couleur que l'interface
	# s'est donnée en DA1.4 précisément pour cesser d'emprunter celles des autres.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.NOIR, 0.75)
	style.set_border_width_all(1)
	style.border_color = COLOR_LINE
	style.set_corner_radius_all(6)
	style.content_margin_left = GAP_S
	style.content_margin_right = GAP_S
	style.content_margin_top = GAP_XS
	style.content_margin_bottom = GAP_XS
	debug_panel.add_theme_stylebox_override("panel", style)

	var debug_vbox := VBoxContainer.new()
	debug_vbox.add_theme_constant_override("separation", GAP_XXS)

	# **Une grille de deux colonnes, et non une ligne à barres verticales.**
	# `DEBUG | FPS 120 | Ping 42 ms | Lumières 8 | …` à 12 px dans le noir n'est
	# pas seulement laid : il oblige à relire toute la ligne pour trouver une
	# valeur, à l'instant précis où l'on veut vérifier une seule chose. Les
	# libellés à gauche en `DIM`, les valeurs à droite alignées et tabulaires : on
	# lit une colonne, pas une phrase.
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", GAP_S)
	grille.add_theme_constant_override("v_separation", 2)
	debug_vbox.add_child(grille)

	fps_label = _make_ligne_debug(grille, "IMAGES/S")
	dbg_ping = _make_ligne_debug(grille, "PING")
	dbg_lumieres = _make_ligne_debug(grille, "LUMIÈRES")
	dbg_particules = _make_ligne_debug(grille, "PARTICULES")
	dbg_noeuds = _make_ligne_debug(grille, "NŒUDS ARÈNE")
	dbg_cartes = _make_ligne_debug(grille, "CARTES")

	# La ligne réseau garde toute la largeur : elle est faite de phrases courtes
	# (transport, lien direct ou relayé, NAT) et non de nombres à aligner.
	net_debug_label = Label.new()
	net_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_debug_label.custom_minimum_size = Vector2(320, 0)
	Charte.appareil(net_debug_label, T_MENTION)
	net_debug_label.add_theme_color_override("font_color", COLOR_DIM)
	debug_vbox.add_child(net_debug_label)

	debug_panel.add_child(debug_vbox)
	add_child(debug_panel)

	# Mission C : l'identité jetable ne peut s'armer qu'en build debug, mais tant
	# qu'elle est active elle doit se voir sans avoir à ouvrir un log.
	ephemeral_banner = Label.new()
	ephemeral_banner.text = "⚠ IDENTITÉ EPIC ÉPHÉMÈRE (test) — profil non persistant"
	ephemeral_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	ephemeral_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ephemeral_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ephemeral_banner.add_theme_font_size_override("font_size", T_COURANT)
	ephemeral_banner.add_theme_color_override("font_color", Charte.ETAT_ATTENTION)
	ephemeral_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ephemeral_banner.visible = NetworkManager.is_ephemeral_identity()
	add_child(ephemeral_banner)

## Une ligne du panneau F3 : le libellé à gauche, la valeur à droite.
##
## Rend la valeur, seule chose que l'appelant ait à tenir. Le libellé est posé
## une fois pour toutes et ne change jamais — un diagnostic dont les intitulés
## bougeraient serait à relire à chaque coup d'œil.
func _make_ligne_debug(grille: GridContainer, libelle: String) -> Label:
	var l := Label.new()
	l.text = libelle
	Charte.appareil(l, T_MENTION)
	l.add_theme_color_override("font_color", COLOR_DIM)
	grille.add_child(l)

	var v := Label.new()
	v.text = "—"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Appareil, donc tabulaire : ces valeurs se remplacent quatre fois par seconde
	# et une largeur qui bouge ferait respirer toute la grille.
	Charte.appareil(v, T_MENTION)
	v.add_theme_color_override("font_color", COLOR_ACCENT)
	grille.add_child(v)
	return v


## La teinte d'une mesure, selon la triade d'instrument.
##
## **Le vert n'entre jamais dans l'arène — mais le panneau F3 EST de
## l'interface**, et la règle 3 de la charte ne s'applique qu'au monde. C'est
## même le lieu le plus légitime de la triade : un tableau de bord existe pour
## dire d'un coup d'œil si la valeur va, alerte, ou faute.
func _teinte_de_mesure(valeur: float, bon: float, moyen: float,
		plus_haut_vaut_mieux: bool = true) -> Color:
	var ok := valeur >= bon if plus_haut_vaut_mieux else valeur <= bon
	if ok:
		return Charte.ETAT_OK
	var passable := valeur >= moyen if plus_haut_vaut_mieux else valeur <= moyen
	return Charte.ETAT_ATTENTION if passable else Charte.ETAT_FAUTE


func _build_dialog() -> void:
	dialog_panel = PanelContainer.new()
	dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# DA4.17 — **le cadre porte le registre du message.** Sa teinte est posée par
	# `show_dialog_message()`, pas ici : elle change à chaque ouverture.
	_dialog_style = StyleBoxFlat.new()
	_dialog_style.bg_color = Color(Charte.SURFACE, 0.97)
	_dialog_style.set_border_width_all(2)
	_dialog_style.border_color = COLOR_ACCENT
	_dialog_style.set_corner_radius_all(12)
	_dialog_style.content_margin_left = GAP_L
	_dialog_style.content_margin_right = GAP_L
	_dialog_style.content_margin_top = GAP_M
	_dialog_style.content_margin_bottom = GAP_M
	dialog_panel.add_theme_stylebox_override("panel", _dialog_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", GAP_S)
	dialog_panel.add_child(vbox)

	dialog_title = Label.new()
	dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# L'enseigne : « DÉCONNEXION », « ARÈNE REFUSÉE » sont des mots qu'on assène
	# une fois, jamais des valeurs qui se remplacent. Même registre que les
	# verdicts, et pour la même raison.
	Charte.enseigne(dialog_title, T_TITRE)
	vbox.add_child(dialog_title)

	dialog_message = Label.new()
	dialog_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# ⚠️ **Le corps du message reste TOUJOURS en `HALOGENE`, quel que soit le
	# registre.** La charte l'écrit noir sur blanc à propos de `ROUGE` : son
	# contraste sur `SURFACE` vaut 4,9:1 — « suffisant pour un libellé de bouton ou
	# un verdict en gros, insuffisant pour une phrase ». Teinter le paragraphe en
	# rouge rendrait l'explication plus dure à lire au moment précis où elle est le
	# plus utile. Seuls le titre et le filet portent la couleur.
	dialog_message.custom_minimum_size = Vector2(520, 0)
	Charte.appareil(dialog_message, T_COURANT)
	dialog_message.add_theme_color_override("font_color", COLOR_LUMIERE)
	vbox.add_child(dialog_message)

	# **Le bouton ne prend jamais la couleur du registre**, et c'est délibéré : il
	# ne détruit rien, il ferme. Un « OK » rouge se lit comme une action
	# dangereuse alors qu'il n'y a plus rien à décider.
	dialog_btn = _make_button("OK", COLOR_ACCENT, true)
	dialog_btn.custom_minimum_size = Vector2(160, 48)
	dialog_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog_btn.pressed.connect(_on_dialog_closed)
	vbox.add_child(dialog_btn)

	dialog_panel.hide()
	add_child(dialog_panel)

func _build_killcam() -> void:
	killcam_overlay = ColorRect.new()
	killcam_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	killcam_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killcam_overlay.hide()

	var material := ShaderMaterial.new()
	material.shader = SHADER_KILLCAM
	killcam_overlay.material = material
	# killcam_overlay n'est PAS ajouté ici : GameState le reparente dans l'arène.

	killcam_container = Control.new()
	killcam_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	killcam_container.offset_top = 100
	killcam_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killcam_container.hide()
	add_child(killcam_container)

	killcam_label_shadow1 = _make_killcam_label(Color(Charte.BLEU, 0.5))
	killcam_container.add_child(killcam_label_shadow1)
	killcam_label_shadow2 = _make_killcam_label(Color(Charte.AMBRE, 0.5))
	killcam_container.add_child(killcam_label_shadow2)
	killcam_label = _make_killcam_label(Charte.ROUGE)
	killcam_container.add_child(killcam_label)

	killcam_timecode = Label.new()
	# DA4.2 — l'appareil. Le timecode défile image par image ; il est en outre
	# ancré en HAUT À DROITE, donc une largeur qui varie décolle le texte du bord
	# au lieu de le laisser aligné. C'est le seul compteur du jeu où le
	# tremblement se verrait comme un défaut de marge plutôt que de chiffre.
	Charte.appareil(killcam_timecode, T_TITRE)
	killcam_timecode.add_theme_color_override("font_color", Color(Charte.HALOGENE, 0.8))
	killcam_timecode.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	killcam_timecode.offset_right = -40
	killcam_timecode.offset_top = 40
	killcam_timecode.hide()
	add_child(killcam_timecode)

func _make_killcam_label(tint: Color) -> Label:
	var label := Label.new()
	label.text = "KILLCAM"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# DA4 — l'enseigne. Un mot fixe, écrit une fois, jamais remplacé : le cas
	# exact que la fonte d'affichage existe pour porter. Le timecode juste à côté
	# reste à l'appareil, lui, parce qu'il défile — les deux registres se voient
	# donc côte à côte à l'écran, ce qui est la meilleure démonstration de la
	# frontière.
	Charte.enseigne(label, T_VERDICT)
	label.add_theme_color_override("font_color", tint)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label

# ===========================================================================
# CONSTRUCTION — MENU
# ===========================================================================

func _build_menu() -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.hide()
	add_child(game_over_panel)

	var backdrop := ColorRect.new()
	backdrop.name = "Rideau"
	backdrop.color = Charte.BACKDROP
	# M10 lit ici l'opacité de nuit du panneau : elle est la valeur d'arrivée du
	# rideau, et la relire dans le code de l'effet en ferait une seconde vérité
	# qui finirait par diverger de celle-ci.
	backdrop.set_meta(META_ALPHA_NUIT, backdrop.color.a)
	game_over_panel.add_child(backdrop)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_top", GAP_L)
	outer.add_theme_constant_override("margin_bottom", GAP_L)
	outer.add_theme_constant_override("margin_left", GAP_L + GAP_S)
	outer.add_theme_constant_override("margin_right", GAP_L + GAP_S)
	game_over_panel.add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP_M)
	outer.add_child(root)
	# M10 rallume CES enfants-là, en cascade. Le désigner ici plutôt que de le
	# deviner évite un effet qui se tairait le jour où l'on glisse un conteneur
	# de plus entre le panneau et sa colonne.
	game_over_panel.set_meta(META_CASCADE, root)

	root.add_child(_build_menu_header())

	# Le hub remplace la barre d'onglets (Phase 5, structure B). Son propre titre
	# est masqué : l'en-tête ci-dessus le porte déjà, et deux titres empilés
	# mangeraient la hauteur utile de l'écran.
	hub = MenuHub.new()
	hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub.screen_changed.connect(_on_hub_screen_changed)
	# La description de l'entrée survolée s'affiche sous le titre du jeu — là où le
	# regard passe déjà — au lieu d'attendre dans le panneau de droite.
	hub.detail_changed.connect(_on_hub_detail_changed)
	root.add_child(hub)

	_build_hub_screens()

	root.add_child(_build_actions_bar())

	# Ajouté APRÈS le panneau du menu, et non dedans : il doit se coller au bord
	# haut de l'écran, au-dessus du titre, alors que le panneau garde une marge.
	# Un enfant de plus dans le panneau aurait été poussé sous cette marge.
	match_banner = MatchBanner.new()
	add_child(match_banner)

	# M2 — la couche de rémanence est `top_level` et couvre l'écran : elle vit donc
	# au même niveau que les curseurs qu'elle prolonge, pas dans le menu.
	menu_after_image = MenuAfterImage.new()
	add_child(menu_after_image)

	# M9 — la torche suit les curseurs, donc elle vit à leur niveau et **sous** eux :
	# le liseré doit rester net par-dessus sa propre flaque.
	menu_torch = MenuTorch.new()
	add_child(menu_torch)
	move_child(menu_torch, 0)

	# M3 — le regard vit au même niveau : il se pose dans les marges de l'écran,
	# pas dans le menu, et n'a donc rien à faire dans sa hiérarchie.
	menu_watcher = MenuWatcher.new()
	add_child(menu_watcher)

	# M4 — le passant, lui, va **derrière les panneaux** : c'est toute l'idée,
	# et c'est ce qui donne enfin un sens visible à leur translucidité.
	menu_passerby = MenuPasserby.new()
	game_over_panel.add_child(menu_passerby)
	game_over_panel.move_child(menu_passerby, 1)

	# M8 — la traçante passe PAR-DESSUS tout, curseurs compris : une balle qui
	# disparaîtrait derrière un panneau ne serait plus une balle.
	menu_tracer = MenuTracer.new()
	add_child(menu_tracer)

	# M12 + M5 — la brume et le bruit de l'œil vivent dans le matériau du fond,
	# pas dans un nœud qui dessine. Ce porteur ne fait qu'amortir la parallaxe,
	# seul morceau que le GPU ne peut pas tenir tout seul.
	menu_backdrop = MenuBackdrop.new()
	add_child(menu_backdrop)
	menu_backdrop.adopter(backdrop)

	# M14 — la matière des surfaces qu'on manipule. Posé après `_build_hub_screens()`,
	# qui a construit les rangées de réglage : vitrer avant reviendrait à parcourir
	# un arbre vide.
	menu_glass = MenuGlass.new()
	add_child(menu_glass)
	# Le second étage — la brume défocalisée — n'est donné qu'au cadre de droite :
	# c'est une copie d'écran par image, et c'est la seule surface assez grande
	# pour qu'on voie la profondeur qu'elle achète.
	menu_glass.vitrer(hub.right_panel(), COLOR_P1, RELECTURE_ECRAN)
	menu_glass.vitrer_rangees(hub)

	# M15 — le voile passe APRÈS tout ce qu'il filme, donc en dernier dans le
	# panneau. Il y reste, plutôt que de monter au niveau des curseurs : un liseré
	# de sélection grainé serait moins net, et la netteté du curseur est de
	# l'information, pas de la décoration.
	if RELECTURE_ECRAN:
		menu_veil = MenuVeil.new()
		game_over_panel.add_child(menu_veil)
		game_over_panel.move_child(menu_veil, -1)

	# Une ligne d'`effect_policy` sans lecture donnerait un curseur qui ne pilote
	# rien — le défaut le plus vicieux d'un écran de réglages, puisqu'il ressemble
	# trait pour trait à un réglage qui marche. On applique l'intensité mémorisée
	# maintenant, et à chaque fois que le joueur la change.
	# Sans filtre sur la clé, et c'est délibéré depuis la quatorzième entrée.
	#
	# Il y avait ici la liste des effets de la vitrine, à tenir d'accord avec
	# `_apply_menu_effects()`. Une liste de clés recopiée est un endroit où le
	# prochain effet manquera — et il manquera SANS RIEN CASSER : le réglage
	# n'aurait simplement pas d'effet tant qu'on ne quitte pas l'écran, ce qui
	# ressemble trait pour trait à un curseur qui ne pilote rien. Tout réappliquer
	# coûte une quinzaine d'affectations d'uniformes, à l'instant où un humain
	# bouge un curseur : c'est gratuit, et ça ne peut plus diverger.
	GameSettings.effect_changed.connect(func(_id: String, _v: float) -> void:
		_apply_menu_effects()
	)
	_apply_menu_effects()

## Déclare l'arborescence et y installe le contenu.
##
## Les blocs existants sont **réemployés tels quels** : `_build_mode_block()`,
## `_build_weapon_block()` et la galerie rendent déjà des `Control`. L'étape ne
## déplace donc que leur point d'accrochage — c'est ce qui permet de savoir que ce
## qui casse vient du déplacement, et de rien d'autre.
func _build_hub_screens() -> void:
	# Les pièces du salon sont créées d'abord, orphelines : les panneaux qui suivent
	# les rangent, et rien ne les crée deux fois.
	_build_lobby_widgets()

	var accueil := hub.add_screen(MenuHub.ROOT, "Menu principal")
	var scinde := hub.add_screen(SCREEN_LOCAL, "1v1 écrans scindés")
	var amical := hub.add_screen(SCREEN_FRIENDLY, "1v1 amical")
	var prive_ligne := hub.add_screen(SCREEN_FRIENDLY_ONLINE, "Match privé en ligne")
	var prive_local := hub.add_screen(SCREEN_FRIENDLY_LOCAL, "Match privé en local")
	var hote := hub.add_screen(SCREEN_HOST, "Créer — en ligne")
	var invite := hub.add_screen(SCREEN_JOIN, "Rejoindre — en ligne")
	var hote_lan := hub.add_screen(SCREEN_LOCAL_HOST, "Créer — réseau local")
	var invite_lan := hub.add_screen(SCREEN_LOCAL_JOIN, "Rejoindre — réseau local")
	var classe := hub.add_screen(SCREEN_RANKED, "1v1 compétitif")
	var entrainement := hub.add_screen(SCREEN_TRAINING, "S'entraîner")
	var custom := hub.add_screen(SCREEN_CUSTOM, "Personnalisation")

	# --- Accueil --------------------------------------------------------------
	accueil.add_child(hub.make_entry("1V1 ÉCRANS SCINDÉS",
		"Deux joueurs sur ce poste, écran partagé. Rien n'est en jeu : toutes les "
		+ "armes sont accessibles.", SCREEN_LOCAL))
	accueil.add_child(hub.make_entry("1V1 AMICAL",
		"Contre quelqu'un d'autre, en ligne ou en local. Le résultat ne compte pas "
		+ "au classement.", SCREEN_FRIENDLY))
	accueil.add_child(hub.make_entry("1V1 COMPÉTITIF",
		"Match classé : le résultat compte, et l'arsenal s'aligne sur le moins bien "
		+ "classé des deux.", SCREEN_RANKED, COLOR_GOLD))
	accueil.add_child(hub.make_entry("S'ENTRAÎNER",
		"Seul, contre une cible. De quoi prendre une arme en main sans enjeu.",
		SCREEN_TRAINING))
	accueil.add_child(hub.make_entry("PERSONNALISATION",
		"Contrôles, affichage, effets, audio, calibration.", SCREEN_CUSTOM, COLOR_DIM))
	accueil.add_child(hub.make_entry("MISE À JOUR",
		"Vérifie si une nouvelle version est publiée, et l'installe. Rien ne se "
		+ "télécharge sans que vous le demandiez.", SCREEN_UPDATE, COLOR_DIM))
	# Style ordinaire, pas celui des lanceurs de match : fermer le jeu ne doit pas
	# crier plus fort que ce qui engage une partie. Décision du 2026-08-17, perdue
	# à l'arrivée dans le hub et rétablie ici.
	#
	# Conséquence utile, découverte des deux côtés le même jour : sans la marque
	# de lanceur, M8 ne tire pas non plus sur QUITTER. La traçante sacralise le
	# geste qui engage une partie ; la tirer pour fermer le jeu la viderait de son
	# sens — et personne n'en verrait la fin.
	accueil.add_child(hub.make_entry("QUITTER",
		"Ferme le jeu proprement — la plateforme Epic est relâchée avant la sortie.",
		"", COLOR_P2, "quitter"))
	hub.set_aside(MenuHub.ROOT, "Candela 2D",
		"Duel 1v1 dans le noir absolu. La seule information est la lumière : votre "
		+ "torche, qui révèle mais trahit, le flash d'un tir, la rétrodiffusion sur "
		+ "un mur.\n\n[b]Être vu, c'est être mort.[/b]\n\nQuitter le jeu : le bouton "
		+ "en bas de l'écran.")

	# --- 1v1 écrans scindés ---------------------------------------------------
	scinde.add_child(hub.make_entry("PRÉPARER LE MATCH",
		"Carte et armes à droite. Le bouton qui lance la manche est là-bas aussi, "
		+ "sous les râteliers — près de ce qu'il consomme.",
		"", COLOR_GOLD, "", "", false, PANEL_SALON))
	scinde.add_child(hub.make_entry("CHANGER DE CARTE",
		"Les arènes s'affichent à droite : choisissez-y directement.",
		"", COLOR_P1, "", "", false, PANEL_MAPS))
	_wire_salon_back(hub.add_back_entry(SCREEN_LOCAL))

	# --- 1v1 amical -----------------------------------------------------------
	amical.add_child(hub.make_entry("PRÉPARER LE MATCH",
		"Choisissez votre arme à droite — après l'appui, le match part tout seul. "
		+ "La recherche vous rend la main : elle continue pendant que vous "
		+ "parcourez les menus, et le bandeau du haut dit où elle en est. Carte "
		+ "tirée au hasard, résultat hors classement.",
		"", COLOR_GOLD, "", "", false, PANEL_SALON))
	amical.add_child(hub.make_entry("MATCH PRIVÉ EN LIGNE",
		"Par Internet, avec un code de salon à six caractères.",
		SCREEN_FRIENDLY_ONLINE))
	amical.add_child(hub.make_entry("MATCH PRIVÉ EN LOCAL",
		"Par le réseau local, avec l'IP de l'hôte — marche même sans Epic.",
		SCREEN_FRIENDLY_LOCAL))
	hub.add_back_entry(SCREEN_FRIENDLY)

	# Le transport n'est plus une bascule : « en ligne » et « en local » SONT le
	# choix, et entrer dans l'un des deux écrans le pose. Même raisonnement que
	# l'étape 3b sur le mode réseau — un état d'interface ne doit pas tenir lieu de
	# décision.
	for spec in [
			[prive_ligne, SCREEN_FRIENDLY_ONLINE, SCREEN_HOST, SCREEN_JOIN,
				"Un code à six caractères, à transmettre à votre adversaire.",
				"Le code que votre adversaire vous a donné."],
			[prive_local, SCREEN_FRIENDLY_LOCAL, SCREEN_LOCAL_HOST, SCREEN_LOCAL_JOIN,
				"Votre adresse IP, à transmettre à votre adversaire.",
				"L'adresse IP de l'hôte."]]:
		var liste: VBoxContainer = spec[0]
		liste.add_child(hub.make_entry("CRÉER", String(spec[4]), String(spec[2])))
		liste.add_child(hub.make_entry("REJOINDRE", String(spec[5]), String(spec[3])))
		hub.add_back_entry(String(spec[1]))

	# --- Les quatre salons ----------------------------------------------------
	# L'hôte choisit la carte des deux joueurs ; laisser l'invité en choisir une lui
	# ferait croire à un choix qui sera écrasé au lancement.
	for h in [hote, hote_lan]:
		h.add_child(hub.make_entry("PRÉPARER LE MATCH",
			"Ouvrez le salon à droite et transmettez ce qu'il affiche. Le bouton "
			+ "PRÊT y attend, sous la liste des joueurs : le match part quand les "
			+ "deux se sont déclarés.",
			"", COLOR_GOLD, "", "", false, PANEL_SALON))
		h.add_child(hub.make_entry("CHANGER DE CARTE",
			"L'hôte choisit l'arène des deux joueurs — les vignettes sont à droite.",
			"", COLOR_P1, "", "", false, PANEL_MAPS))
	for j in [invite, invite_lan]:
		j.add_child(hub.make_entry("PRÉPARER LE MATCH",
			"Rejoignez le salon à droite ; le bouton PRÊT y attend. Le match part "
			+ "quand les deux joueurs se sont déclarés, et la carte est celle de "
			+ "l'hôte.",
			"", COLOR_GOLD, "", "", false, PANEL_SALON))
	for id in [SCREEN_HOST, SCREEN_JOIN, SCREEN_LOCAL_HOST, SCREEN_LOCAL_JOIN]:
		_wire_salon_back(hub.add_back_entry(id,
			"Ferme le salon et coupe le lien. L'adversaire en est averti."))

	# --- 1v1 compétitif -------------------------------------------------------
	classe.add_child(hub.make_entry("PRÉPARER LE MATCH",
		"Votre arme se choisit à droite, avant l'appui : après, le match part tout "
		+ "seul. La fourchette de classement s'élargit avec l'attente ; le bandeau "
		+ "du haut montre celle qui est cherchée. Le résultat compte.",
		"", COLOR_GOLD, "", "", false, PANEL_SALON))
	classe.add_child(hub.make_entry("MON RANG",
		"Votre classement et votre catégorie, affichés à droite.", "", COLOR_GOLD,
		"mon_rang"))
	classe.add_child(hub.make_entry("TOP 10",
		"Le haut du tableau, affiché à droite — sans quitter cet écran.", "",
		COLOR_GOLD, "top10"))
	classe.add_child(hub.make_entry("INFORMATIONS PROFIL",
		"Identité, code de récupération, pseudo — affichés à droite.",
		"", COLOR_GOLD, "", "", false, PANEL_PROFILE))
	classe.add_child(hub.make_entry("HISTORIQUE DES MATCHS",
		"Vos derniers matchs, et le bilan de la soirée en cours, à droite.",
		"", COLOR_GOLD, "", "", false, PANEL_HISTORY))
	hub.add_back_entry(SCREEN_RANKED)
	hub.set_aside(SCREEN_RANKED, "1v1 compétitif",
		"Le classement est [b]déployé et vérifié[/b] : les matchs remontent, l'ELO "
		+ "se recalcule, les rangs existent. Ce qui manque est l'appariement — de "
		+ "quoi trouver un adversaire de niveau proche sans échanger un code.\n\n"
		+ "En attendant, un match privé vous fait jouer ; il ne compte pas.")

	# --- S'entraîner ----------------------------------------------------------
	entrainement.add_child(hub.make_entry("PRÉPARER L'ENTRAÎNEMENT",
		"Seul, contre une cible fixe, sur la carte par défaut. Choisissez votre "
		+ "arme à droite ; le bouton qui lance est sous le râtelier. Rien n'est "
		+ "enregistré ni classé. Échap pour revenir.",
		"", COLOR_GOLD, "", "", false, PANEL_SALON))
	entrainement.add_child(hub.make_entry("CIBLE",
		"Réglages de la cible.", "", COLOR_DIM, "",
		NOT_YET + " La cible est fixe, au point d'apparition du joueur 2. Ses "
		+ "réglages viendront avec la cible mouvante."))
	entrainement.add_child(hub.make_entry("CHANGER DE CARTE",
		"Les arènes s'affichent à droite : choisissez-y directement.",
		"", COLOR_P1, "", "", false, PANEL_MAPS))
	hub.add_back_entry(SCREEN_TRAINING)

	# --- Personnalisation -----------------------------------------------------
	# Aucune de ces quatre entrées n'est une destination : pas de chevron, pas de
	# descente. Chacune déplie sa page complète à droite, au survol comme à la
	# sélection — et la sélection la fige, pour qu'on puisse y amener le curseur.
	custom.add_child(hub.make_entry("CONTRÔLES",
		"Les trois actions réassignables, pour les deux joueurs à la fois.",
		"", COLOR_GOLD, "", "", false, PANEL_CONTROLS))
	custom.add_child(hub.make_entry("AFFICHAGE",
		"Fenêtre, vsync, images par seconde, calibration.",
		"", COLOR_GOLD, "", "", false, PANEL_DISPLAY))
	custom.add_child(hub.make_entry("EFFETS",
		"Ce qui se règle librement, et ce qui garde un plancher en classé.",
		"", COLOR_GOLD, "", "", false, PANEL_EFFECTS))
	custom.add_child(hub.make_entry("AUDIO",
		"Général, musique, effets, annonceur — chaque réglage s'entend en le faisant.",
		"", COLOR_GOLD, "", "", false, PANEL_AUDIO))
	hub.add_back_entry(SCREEN_CUSTOM)

	# --- Cartes, contrôles, affichage, effets ---------------------------------
	# La galerie n'est plus un écran : elle est le panneau de droite d'une entrée
	# d'information, partagée par les quatre listes qui laissent choisir l'arène.
	map_gallery = MapGallery.new()
	map_gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Dans une colonne alignée en haut, un enfant qui s'étire n'obtient que sa
	# taille minimale : sans ce plancher la galerie se réduirait à sa barre d'outils.
	map_gallery.custom_minimum_size = Vector2(0, 470)
	map_gallery.map_chosen.connect(_on_map_chosen)
	hub.register_panel(PANEL_MAPS, map_gallery)

	hub.register_panel(PANEL_CONTROLS, _build_controls_panel())
	hub.register_panel(PANEL_DISPLAY, _build_display_panel())
	# Effets et audio n'ont pas eu à être réécrits pour descendre d'un étage : le
	# contrat `HubScreen` interdit à un écran de connaître sa place dans
	# l'arborescence, et c'est exactement la liberté qu'on encaisse ici.
	_attach_panel(PANEL_EFFECTS, ScreenEffects.new())
	_attach_panel(PANEL_AUDIO, ScreenAudio.new())
	# Le garde-fou suit le PANNEAU, pas l'écran courant.
	hub.panel_changed.connect(func(_k: String) -> void: _refresh_calibration_guard())

	_attach_screen(SCREEN_UPDATE, "Mise à jour", ScreenUpdate.new())
	hub.add_back_entry(SCREEN_UPDATE)

	# DA4.18 — **le profil et l'historique descendent d'un étage, comme les effets
	# et l'audio avant eux.** Demande d'Adrien : « mon profil doit s'afficher à
	# droite, comme l'historique, comme les scores, comme le top 10 ».
	#
	# Ils étaient les seuls écrans de méta à REMPLACER la colonne de gauche
	# pendant que les quatre écrans de réglages remplissaient le cadre. Rien ne
	# justifiait la différence : consulter son rang ou son historique est
	# exactement le geste que le cadre de droite existe pour servir — « ceci se
	# regarde, sans descendre d'un cran ».
	#
	# Aucun des deux n'a été réécrit, et c'est la démonstration du contrat
	# `HubScreen` : un écran n'a pas le droit de connaître sa position dans
	# l'arborescence, précisément pour qu'on puisse l'en changer.
	_attach_panel(PANEL_PROFILE, ScreenProfile.new())
	_attach_panel(PANEL_HISTORY, ScreenHistory.new())

	# DA4.18 — le lit d'ambiance. **C'est le panneau PAR DÉFAUT de l'accueil et
	# des écrans qui n'en avaient aucun**, donc le cadre n'est plus jamais noir.
	#
	# Il est posé en dernier : `register_panel` refuse une clé déjà prise, et un
	# panneau ajouté après coup se placerait au-dessus des autres dans la pile —
	# ici sans conséquence puisqu'un seul est visible à la fois, mais l'ordre
	# reste celui de la déclaration et il vaut mieux qu'il soit lisible.
	menu_arene = MenuArene.new()
	hub.register_panel(PANEL_ARENE, menu_arene)
	# La carte peut changer pendant qu'on est dans les menus — c'est même tout
	# l'objet de la galerie. Sans ce branchement, le cadre continuerait de montrer
	# l'arène précédente jusqu'à la prochaine navigation.
	MapData.map_selected.connect(func(_id: String) -> void:
		if menu_arene != null:
			menu_arene.rafraichir())
	for ecran in [MenuHub.ROOT, SCREEN_LOCAL, SCREEN_FRIENDLY, SCREEN_RANKED,
			SCREEN_TRAINING, SCREEN_CUSTOM]:
		if hub.has_screen(ecran) and hub.screen_panel(ecran) == "":
			hub.set_screen_panel(ecran, PANEL_ARENE)

	# L'écran de recherche N'EST PAS dans l'arborescence, et c'est une décision :
	# chercher un adversaire ne doit pas immobiliser le joueur devant un compte à
	# rebours qu'il ne peut pas accélérer. La recherche part en arrière-plan et
	# `match_banner.gd` la montre en haut de l'écran, quel que soit le menu où l'on
	# se trouve. `screen_matchmaking.gd` reste au dépôt, inutilisé — voir ROADMAP.

	# Le même panneau sert les cinq écrans de préparation : ce qui s'y voit dépend
	# du mode et du transport retenus, pas de l'écran.
	hub.register_panel(PANEL_SALON, _build_salon_aside())
	# Les deux écrans qui lancent une recherche l'utilisent aussi, mais n'en gardent
	# que le râtelier : ni carte à choisir (elle est tirée au sort), ni code à
	# transmettre (c'est la file qui trouve l'adversaire). Le choix d'arme, lui,
	# doit être fait AVANT d'appuyer — après, le match part tout seul.
	for id in [SCREEN_LOCAL, SCREEN_HOST, SCREEN_JOIN, SCREEN_LOCAL_HOST,
			SCREEN_LOCAL_JOIN, SCREEN_TRAINING, SCREEN_FRIENDLY, SCREEN_RANKED]:
		hub.set_screen_panel(id, PANEL_SALON)

	# Le classement vit hors de l'arborescence : il se lit dans le panneau de droite
	# depuis l'écran compétitif.
	_leaderboard = ScreenLeaderboard.new()
	_leaderboard.hide()
	add_child(_leaderboard)

	hub.action_requested.connect(_on_hub_action)
	hub.back_at_root.connect(func() -> void: pass)
	hub.reset()


## Panneau de droite des trois salons — local, hôte, invité — et il n'y en a
## qu'un seul.
##
## Un nœud n'a qu'un parent : donner `transport_hbox` à trois panneaux le
## déplacerait simplement dans le dernier. Et `_build_weapon_block()` réassigne
## `weapon_hbox` à chaque appel — trois appels laisseraient deux râteliers
## orphelins dans l'arbre, la sélection d'arme ne lisant plus que le dernier.
##
## Le panneau est donc unique, et `_refresh_lobby_block()` décide de ce qui s'y
## voit selon `_intended_mode` : c'est ce qu'il faisait déjà pour les quatre
## combinaisons de mode et de transport.
func _build_salon_aside() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP_S)
	box.add_child(_build_map_card())
	# Rangée hors de vue dans un conteneur caché : elle doit rester dans l'arbre
	# pour que son état soit lisible, sans être proposée au joueur.
	var cachette := Control.new()
	cachette.hide()
	cachette.add_child(transport_hbox)
	box.add_child(cachette)
	box.add_child(_build_weapon_block())
	# Le bloc du salon ferme le panneau, dans l'ordre où on s'en sert : qui est
	# là, par quoi on les fait venir, et le geste qui ouvre la porte.
	box.add_child(_build_player_list())
	box.add_child(lobby_code_row)
	box.add_child(host_ip_row)
	box.add_child(_build_join_row())
	box.add_child(lobby_status_label)
	box.add_child(_build_open_lobby_row())
	# **Le geste qui engage ferme le panneau**, dans l'ordre où on s'en sert :
	# on regarde la carte, on choisit son arme, on voit qui est là, on ouvre la
	# porte — et on part. En écran partagé les rangées de salon sont masquées, et
	# le bouton se retrouve donc directement sous les râteliers d'armes.
	box.add_child(_build_launch_row())
	return box


## Le bouton de lancement du cadre de droite.
##
## Il porte le **style plein**, qui vient de perdre sa place dans la colonne de
## gauche — et il la retrouve ici sans le défaut qui l'avait fait retirer le
## 2026-08-18 : à gauche, un fond teinté entrait en concurrence avec le liseré du
## curseur ; dans le cadre, rien ne le lui dispute.
func _build_launch_row() -> Control:
	panel_launch = _make_button("JOUER", COLOR_GOLD, true)
	panel_launch.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel_launch.pressed.connect(func() -> void:
		var action := String(panel_launch.get_meta(META_LAUNCH_ACTION, ""))
		if action != "":
			_on_hub_action(action))
	return panel_launch

## Le champ de code, son bouton COLLER, et le geste qui rejoint — dans cet ordre.
##
## Rejoindre est la conséquence de ce qu'on vient de coller : le bouton se place
## donc sous le champ. Dans la liste de gauche il passait pour un lancement de
## match, ce qu'il n'est plus — le match attend maintenant les deux « PRÊT ».
func _build_join_row() -> Control:
	join_box = VBoxContainer.new()
	join_box.add_theme_constant_override("separation", GAP_XS)

	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", GAP_XS)
	ligne.add_child(join_input)
	btn_paste_code = _make_button("COLLER", COLOR_P1)
	btn_paste_code.add_theme_font_size_override("font_size", T_MENTION)
	btn_paste_code.pressed.connect(_paste_lobby_code)
	ligne.add_child(btn_paste_code)
	join_box.add_child(ligne)

	var centre := CenterContainer.new()
	btn_join_lobby = _make_button("REJOINDRE LE SALON", COLOR_P1, true)
	btn_join_lobby.custom_minimum_size = Vector2(280, 44)
	btn_join_lobby.pressed.connect(func() -> void:
		_abandon_search("salon rejoint")
		join_requested.emit()
	)
	centre.add_child(btn_join_lobby)
	join_box.add_child(centre)
	return join_box

## Colle le presse-papiers dans le champ de code, nettoyé comme la saisie l'est
## déjà : un code recopié depuis une messagerie arrive avec des espaces ou des
## tirets, et les refuser sans rien dire ferait douter du code lui-même.
func _paste_lobby_code() -> void:
	var brut := DisplayServer.clipboard_get()
	join_input.text = LobbyCode.sanitize(brut) \
		if NetworkManager.transport == NetworkManager.Transport.EOS \
		else brut.strip_edges()
	join_input.caret_column = join_input.text.length()

## Qui est dans le salon. L'hôte s'y voit lui-même : une liste où l'on ne figure
## pas laisse douter d'être bien connecté à quoi que ce soit.
func _build_player_list() -> Control:
	lobby_players_box = VBoxContainer.new()
	lobby_players_box.add_theme_constant_override("separation", GAP_XXS)

	var titre := Label.new()
	titre.text = "JOUEURS"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", T_MENTION)
	titre.add_theme_color_override("font_color", COLOR_DIM)
	lobby_players_box.add_child(titre)

	lobby_player_host = Label.new()
	lobby_player_host.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_player_host.add_theme_font_size_override("font_size", T_COURANT)
	lobby_player_host.add_theme_color_override("font_color", COLOR_P1)
	lobby_players_box.add_child(lobby_player_host)

	lobby_player_guest = Label.new()
	lobby_player_guest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_player_guest.add_theme_font_size_override("font_size", T_COURANT)
	lobby_players_box.add_child(lobby_player_guest)

	return lobby_players_box

## Le geste qui ouvre le salon. Il n'existait pas : le salon s'ouvrait au
## lancement du match, si bien que le code à transmettre n'apparaissait qu'une
## fois l'hôte seul dans l'arène — il fallait le lire par-dessus l'écran
## d'attente, puis espérer que l'adversaire arrive avant de s'ennuyer.
func _build_open_lobby_row() -> Control:
	btn_open_lobby = _make_button("CRÉER LE SALON", COLOR_P1, true)
	btn_open_lobby.custom_minimum_size = Vector2(280, 52)
	btn_open_lobby.pressed.connect(_open_lobby)
	var center := CenterContainer.new()
	center.add_child(btn_open_lobby)
	return center

## Ouvre le salon depuis le menu, sans lancer la manche.
##
## En EOS le code arrive plus tard, par `lobby_code_ready` ; en réseau local il
## n'y a rien à publier, l'IP était déjà affichée — mais le port, lui, doit être
## ouvert pour que l'adversaire puisse se présenter avant le début du match.
func _open_lobby() -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		return
	_abandon_search("salon ouvert")
	if not NetworkManager.host_game():
		lobby_status_label.text = NetworkManager.last_error if NetworkManager.last_error != "" \
			else "Impossible d'ouvrir le salon."
		return
	_lobby_screen = hub.current_id()
	_refresh_lobby_block()

## Referme le salon quand on quitte l'écran qui l'a ouvert. Un code publié
## derrière soi ferait attendre un adversaire devant une porte que plus personne
## ne garde — et rejoindre un salon en étant soi-même hôte n'a aucun sens.
func _close_lobby_if_left(id: String) -> void:
	if _lobby_screen == "" or id == _lobby_screen:
		return
	# Un pair connecté veut dire qu'une partie est en cours, ou vient de finir.
	#
	# Sans ce contrôle, chaque fin de match en ligne faisait s'annoncer les deux
	# joueurs mutuellement déconnectés, et le coupable était l'HÔTE :
	#
	#   show_game_over() → hub.reset() → screen_changed.emit("accueil")
	#                    → ici, "accueil" != SCREEN_HOST → disconnect_from_game()
	#
	# `reset()` émet **avant** le `push()` qui suit : c'est la remise à zéro de la
	# pile qui coupe, pas la destination. Le client, lui, n'arme jamais
	# `_lobby_screen` — `_open_lobby()` n'est atteignable que par un bouton réservé
	# à l'hôte — et ne fait donc que constater le départ.
	#
	# **Ne pas simplifier en ne testant que l'écran d'arrivée du `push`** : la
	# destination est bonne depuis `_screen_for_current_mode()`, ce qui rend le
	# raccourci tentant et ferait revenir le défaut sans le moindre bruit.
	#
	# Le salon suit l'écran plutôt que de se fermer : quitter *ensuite* vers autre
	# chose le refermera normalement, une fois le pair réellement parti.
	# `has_multiplayer_peer()` et non `multiplayer != null` : le second n'est jamais
	# faux sur un nœud de l'arbre, et `get_peers()` sans pair assigné fait crier
	# Godot — « No multiplayer peer is assigned » — à chaque retour au menu.
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		_lobby_screen = id
		return
	_lobby_screen = ""
	NetworkManager.disconnect_from_game()

## L'écran de salon qui correspond au rôle réellement joué. Renvoyer tout le monde
## sur `SCREEN_HOST` après un match envoyait le client sur l'écran de l'hôte — et
## comme ce n'était pas l'écran qui avait ouvert son salon, il s'y déconnectait.
func _screen_for_current_mode() -> String:
	var lan := NetworkManager.transport == NetworkManager.Transport.ENET
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST:
			return SCREEN_LOCAL_HOST if lan else SCREEN_HOST
		NetworkManager.GameMode.ONLINE_CLIENT:
			return SCREEN_LOCAL_JOIN if lan else SCREEN_JOIN
		_:
			return SCREEN_LOCAL

## Reflète la présence des deux joueurs et l'état du bouton d'ouverture.
func _refresh_player_list() -> void:
	if lobby_players_box == null:
		return
	var mode := selected_network_mode()
	var ouvert := NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST
	# `has_multiplayer_peer()` et non `multiplayer != null` : cette fonction est
	# appelée sur le chemin de la déconnexion, quand il n'y a justement plus de
	# pair, et `get_peers()` fait alors crier Godot.
	var lie := multiplayer.has_multiplayer_peer() \
		and not multiplayer.get_peers().is_empty()

	# **La liste se lit depuis la place de celui qui la regarde.** Elle était
	# rédigée du seul point de vue de l'hôte : le client y voyait « L'hôte » puis
	# « Adversaire — connecté », deux lignes pour la même personne — l'hôte étant
	# son unique pair — et ne s'y voyait jamais. Une liste de joueurs où l'on ne
	# figure pas laisse douter d'être connecté à quoi que ce soit, ce qu'elle
	# devait précisément lever.
	#
	# L'ordre ne change pas — l'hôte d'abord, l'invité ensuite — parce que c'est
	# l'ordre du salon et non celui des personnes présentes.
	if mode == NetworkManager.GameMode.ONLINE_HOST:
		lobby_player_host.text = "Vous — hôte"
		lobby_player_host.add_theme_color_override("font_color", COLOR_P1)
		lobby_player_guest.text = "Adversaire — connecté" if lie \
			else ("En attente d'un adversaire…" if ouvert else "—")
		lobby_player_guest.add_theme_color_override("font_color",
			COLOR_P2 if lie else COLOR_DIM)
	else:
		lobby_player_host.text = "L'hôte — connecté" if lie else "L'hôte — non rejoint"
		lobby_player_host.add_theme_color_override("font_color",
			COLOR_P2 if lie else COLOR_DIM)
		lobby_player_guest.text = "Vous"
		lobby_player_guest.add_theme_color_override("font_color", COLOR_P1)

	btn_open_lobby.visible = mode == NetworkManager.GameMode.ONLINE_HOST
	btn_open_lobby.disabled = ouvert
	btn_open_lobby.text = "SALON OUVERT" if ouvert else "CRÉER LE SALON"

	# Rejoindre et coller n'ont de sens que chez l'invité : l'hôte publie un code,
	# il n'en saisit pas.
	var cote_invite := mode == NetworkManager.GameMode.ONLINE_CLIENT
	if btn_join_lobby != null:
		btn_join_lobby.visible = cote_invite
		btn_join_lobby.disabled = lie
		btn_join_lobby.text = "SALON REJOINT" if lie else "REJOINDRE LE SALON"
	if btn_paste_code != null:
		btn_paste_code.visible = cote_invite

	# « PRÊT » reste visible et grisé tant qu'un second joueur est nécessaire et
	# absent — masquer laisserait croire que le match ne peut pas partir du tout.
	# Le lancement solo en bac à sable a été retiré avec ce grisage (décision
	# d'Adrien) : un bouton qui lance tantôt un duel, tantôt une partie contre
	# personne, ne dit pas ce qu'il fait.
	var manque_un_joueur := mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN \
		and not lie
	if panel_launch != null and is_instance_valid(panel_launch):
		panel_launch.disabled = manque_un_joueur
		panel_launch.modulate = Color(1.0, 1.0, 1.0, 0.45) if manque_un_joueur \
			else Color.WHITE

## Quitter un salon **ferme le salon**, il ne fait pas que remonter d'un cran.
##
## Sans cela, `current_mode` restait « hôte » après le départ : le bouton affichait
## « SALON OUVERT » grisé et **plus aucun autre salon ne pouvait s'ouvrir**, tandis
## que l'en-tête gardait le score d'un match terminé. Relevé par Adrien à l'usage.
##
## Le démontage passe par `main_menu_requested`, donc par `game_state`, qui sait
## seul archiver un abandon s'il y a lieu, relâcher le salon EOS et remettre le
## menu à plat. Le dupliquer ici en ferait une seconde vérité.
## Applique aux effets de menu ce que le joueur a réglé.
##
## Les menus ne sont jamais « classés » : le plancher de la politique n'a donc
## rien à imposer ici, et `false` est la bonne réponse — pas une simplification.
func _apply_menu_effects() -> void:
	if menu_gnomon != null:
		menu_gnomon.set_intensite(_intensite_vitrine("cadran_titre"))
	if menu_after_image != null:
		menu_after_image.set_intensite(_intensite_vitrine("remanence_curseur"))
	if menu_torch != null:
		menu_torch.set_intensite(_intensite_vitrine("torche_menu"))
	if menu_watcher != null:
		menu_watcher.set_intensite(_intensite_vitrine("regard_du_noir"))
	if menu_passerby != null:
		menu_passerby.set_intensite(_intensite_vitrine("passant_vitre"))
	if menu_tracer != null:
		menu_tracer.set_intensite(_intensite_vitrine("depart_au_tir"))
	if hub != null and hub.ink() != null:
		hub.ink().set_intensite(_intensite_vitrine("encre_coulee"))
	var gravure := _intensite_vitrine("gravure_code")
	if lobby_code_engraver != null:
		lobby_code_engraver.set_intensite(gravure)
	if host_ip_engraver != null:
		host_ip_engraver.set_intensite(gravure)
	if menu_title != null:
		menu_title.set_intensite(_intensite_vitrine("titre_vivant"))
	if menu_glass != null:
		menu_glass.set_intensite(_intensite_vitrine("verre_panneaux"))
	var voile := _intensite_vitrine("voile_menu")
	if menu_veil != null:
		menu_veil.set_intensite(voile)
	if pause_veil != null:
		pause_veil.set_intensite(voile)
	if menu_backdrop != null:
		menu_backdrop.set_brume(_intensite_vitrine("brume_menu"))
		menu_backdrop.set_bruit(_intensite_vitrine("bruit_de_l_oeil"))
	if menu_arene != null:
		menu_arene.set_intensite(_intensite_vitrine("arene_au_repos"))
	# M10 n'a pas de nœud à lui : il vit dans les chemins show/hide des deux
	# panneaux, et son intensité est donc une simple valeur retenue ici.
	_m10 = _intensite_vitrine("extinction_menu")

## L'intensité réelle d'un effet de la vitrine, ici et maintenant.
##
## Deux choses s'y ajoutent au réglage du joueur, et elles ne sont pas du même
## ordre :
##
## - **Les menus ne sont jamais classés.** Le plancher de la politique n'a donc
##   rien à imposer ici, et `false` est la bonne réponse — pas une simplification.
## - **L'écran de calibration éteint tout.** Voir `_calibration` : le joueur y
##   règle son point de noir sur un champ mesuré, et la moindre lumière ajoutée
##   fausserait la mesure. Ce n'est pas un choix de goût, et c'est pour cette
##   raison que le garde-fou est ici — au seul endroit par lequel passent les
##   onze effets — plutôt que répété dans chacun d'eux, où il finirait par
##   manquer au douzième.
func _intensite_vitrine(cle: String) -> float:
	if _calibration:
		return 0.0
	return GameSettings.effective_effect(cle, false)

# ===========================================================================
# M10 — L'EXTINCTION DES FEUX
# ===========================================================================
#
# Le menu et la pause ne s'affichent plus : le monde s'éteint, puis le menu se
# rallume. Ouvrir un menu est le geste le plus répété du jeu, et c'était un
# show/hide sec. Entrer au menu = éteindre sa torche, en sortir = la rallumer :
# le battement de noir absolu entre deux mondes rappelle le contrat à chaque
# traversée, sans un pixel de déplacement — zéro vertige, zéro gêne manette.
#
# **Seules les quatre traversées arène ↔ menu s'animent.** Les bascules internes
# — la pause qui ouvre ses options, les options qui rendent la pause — restent
# sèches : ce ne sont pas des traversées, et les fondre reviendrait à éteindre la
# lampe pour la rallumer sans avoir bougé.

## Battement de noir vrai entre les deux mondes.
const M10_BATTEMENT := 0.05
## Chute du rideau de nuit.
const M10_RIDEAU := 0.10
## Écart entre la première surface rallumée et la dernière.
##
## Le hub ne compte que TROIS blocs — en-tête, liste, barre du bas. Un étalement
## large n'y fait pas une cascade, il y fait trois apparitions successives, dont
## une porte à elle seule presque tout l'écran. Neuf centièmes : les trois
## chevauchent, et l'œil lit une vague au lieu de trois pas.
const M10_ETALEMENT := 0.09
## Rallumage d'une surface. Plus long que l'étalement, exprès : c'est ce
## chevauchement qui fait la vague.
const M10_SURFACE := 0.16
## Part du rideau posée avant qu'une surface commence à se rallumer.
##
## **Le réglage qui faisait passer l'effet pour un défaut.** Les surfaces sont des
## silhouettes noires ; tant que le rideau n'est pas tombé, ce sont des blocs
## noirs posés sur l'arène en train de se jouer — et ça ne ressemble à rien
## d'autre qu'à un panneau qui a raté son dessin. La nuit tombe d'abord ; le
## menu se rallume dedans.
const M10_ANCRAGE := 0.7
## Fermeture. Sous le seuil d'agacement : au-delà, on attend son jeu.
const M10_FERMETURE := 0.14
## Ce que la pause retranche aux durées, dans les deux sens.
const M10_COURT := 0.6

## Un panneau compte-t-il comme ouvert ? Voir `_extinction` : pendant le fondu de
## fermeture, la réponse est non, alors que `visible` est encore vrai.
func _panneau_ouvert(panneau: Control) -> bool:
	return panneau != null and panneau.visible and not _extinction.has(panneau)

func _rideau_de(panneau: Control) -> ColorRect:
	return panneau.get_node_or_null(^"Rideau") as ColorRect if panneau != null else null

func _surfaces_de(panneau: Control) -> Array[Control]:
	var out: Array[Control] = []
	if panneau == null:
		return out
	var hote := panneau.get_meta(META_CASCADE, null) as Control
	if hote == null or not is_instance_valid(hote):
		return out
	for enfant in hote.get_children():
		var c := enfant as Control
		if c != null:
			out.append(c)
	return out

## Remet le panneau à sa lumière pleine, sans animation.
##
## Appelé à chaque bout de chemin — allumage, extinction, fermeture sèche. C'est
## la même discipline que l'encre coulée : un panneau dont les surfaces
## resteraient à `modulate` noir serait un menu invisible mais navigable, et le
## joueur n'aurait aucun moyen de comprendre ce qui se passe.
func _m10_remettre(panneau: Control) -> void:
	var rideau := _rideau_de(panneau)
	if rideau != null:
		rideau.color.a = float(rideau.get_meta(META_ALPHA_NUIT, rideau.color.a))
	for s in _surfaces_de(panneau):
		s.modulate = Color.WHITE

func _m10_tuer(panneau: Control) -> void:
	var t: Variant = _tweens_lumiere.get(panneau, null)
	if t is Tween and (t as Tween).is_valid():
		(t as Tween).kill()
	_tweens_lumiere.erase(panneau)

## Ferme un panneau sur-le-champ, sans fondu.
##
## Pour tout ce qui n'est pas une traversée : la construction, les bascules
## internes, et surtout `force_close_pause()` — la killcam ne peut pas attendre
## un dixième de seconde derrière un panneau qui s'efface.
func _fermer_sec(panneau: Control) -> void:
	if panneau == null:
		return
	_m10_tuer(panneau)
	_extinction.erase(panneau)
	_m10_remettre(panneau)
	panneau.hide()

## Ouvre un panneau sur-le-champ, sans fondu. Même rôle que `_fermer_sec` : les
## bascules internes passent par ici, et l'état d'extinction reste cohérent.
func _ouvrir_sec(panneau: Control) -> void:
	if panneau == null:
		return
	_m10_tuer(panneau)
	_extinction.erase(panneau)
	_m10_remettre(panneau)
	panneau.show()

## Le monde s'éteint, puis le menu se rallume.
func _allumer(panneau: Control, court: bool = false) -> void:
	if panneau == null:
		return
	_m10_tuer(panneau)
	_extinction.erase(panneau)
	panneau.show()
	if _m10 <= 0.0:
		# À zéro : le show sec d'avant l'effet, pixel pour pixel.
		_m10_remettre(panneau)
		return

	var facteur := M10_COURT if court else 1.0
	var rideau := _rideau_de(panneau)
	var surfaces := _surfaces_de(panneau)
	var nuit := 0.96
	if rideau != null:
		nuit = float(rideau.get_meta(META_ALPHA_NUIT, rideau.color.a))
		rideau.color.a = 0.0
	# Silhouettes noires : les contrôles gardent taille, position et visibilité.
	# Rien ne disparaît sous le curseur, et le résolveur de navigation les trouve
	# dès la première image.
	for s in surfaces:
		s.modulate = Color(Charte.NOIR, 1.0)

	var battement := M10_BATTEMENT * facteur
	var t_rideau := M10_RIDEAU * facteur
	var etalement := M10_ETALEMENT * facteur
	var t_surface := M10_SURFACE * facteur
	# Voir M10_ANCRAGE : rien ne se rallume avant que la nuit soit là.
	var ancre := battement + t_rideau * M10_ANCRAGE

	var tw := create_tween()
	tw.set_parallel(true)
	if rideau != null:
		tw.tween_property(rideau, "color:a", nuit, t_rideau).set_delay(battement)
	var n := surfaces.size()
	for i in n:
		# Réparti sur n-1 intervalles, pas sur n : la dernière surface part
		# exactement à la fin de l'étalement, au lieu d'un cran avant — sans quoi
		# la durée réelle dépendrait du nombre de blocs de l'écran.
		var part := float(i) / float(maxi(n - 1, 1))
		tw.tween_property(surfaces[i], "modulate", Color.WHITE, t_surface) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
			.set_delay(ancre + etalement * part)
	# Le titre reprend vie en dernier — mais c'est M11 qui s'en charge, pas M10.
	#
	# Il portait ici un éclat de blanc, qui faisait double emploi dès que le titre
	# incandescent est arrivé : deux effets qui rallument le même objet ne se
	# composent pas, ils se disputent (leçon du 2026-08-18). M10 se contente donc
	# de rendre sa lumière au bloc d'en-tête ; l'embrasement de gauche à droite,
	# qui est ce qui fait vraiment revenir le titre EN DERNIER, appartient à M11.
	if panneau == game_over_panel and menu_title != null:
		menu_title.embraser()
	_tweens_lumiere[panneau] = tw

## Les surfaces se noient dans le noir, PUIS le rideau se lève sur l'arène.
##
## Cet ordre est l'effet lui-même : lever le rideau d'abord ferait apparaître
## l'arène derrière un menu encore lisible, ce qui est exactement le basculement
## sec qu'on remplace.
func _eteindre(panneau: Control, court: bool = false) -> void:
	if panneau == null:
		return
	_m10_tuer(panneau)
	if not panneau.visible or _m10 <= 0.0:
		_fermer_sec(panneau)
		return
	if not _extinction.has(panneau):
		_extinction.append(panneau)

	var duree := M10_FERMETURE * (M10_COURT if court else 1.0)
	var rideau := _rideau_de(panneau)
	var tw := create_tween()
	tw.set_parallel(true)
	for s in _surfaces_de(panneau):
		tw.tween_property(s, "modulate", Color(Charte.NOIR, 1.0), duree * 0.7)
	if rideau != null:
		# Le rideau commence à se lever AVANT que les surfaces aient fini de se
		# noyer : bout à bout, il resterait un écran entièrement noir entre les
		# deux, et ce trou-là se lit comme une image perdue.
		tw.tween_property(rideau, "color:a", 0.0, duree * 0.55).set_delay(duree * 0.45)
	tw.chain().tween_callback(func() -> void: _fermer_sec(panneau))
	_tweens_lumiere[panneau] = tw

func _wire_salon_back(btn: Button) -> void:
	if btn == null:
		return
	btn.pressed.connect(func() -> void:
		if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
			main_menu_requested.emit()
	)

## Le libellé du lanceur suit l'état du match, pas l'écran.
##
## Une seule entrée porte les deux gestes — « PRÊT » avant le match, « REJOUER »
## après — parce que **c'est le même geste au même endroit** : s'engager dans la
## manche suivante. Les avoir séparés en deux boutons, l'un dans la liste et
## l'autre dans une barre du bas, obligeait à deviner lequel comptait.
##
## `btn_replay` reste la source de vérité et devient invisible : plusieurs
## endroits écrivent son texte (« ✓ PRÊT », « Connexion au salon… »), et les
## recenser pour les rerouter créerait autant d'occasions d'en oublier un.
func _sync_launch_entries() -> void:
	if btn_replay == null or panel_launch == null \
			or not is_instance_valid(panel_launch):
		return
	var base := String(panel_launch.get_meta(META_LAUNCH_BASE, "PRÊT"))
	panel_launch.text = base if _is_main_menu else btn_replay.text

## Accorde le bouton du cadre à l'écran courant : libellé, action, présence.
##
## **Absent des écrans qui ne lancent rien** plutôt que grisé : un bouton
## d'engagement sur l'accueil ou sur le profil ne dirait pas « pas maintenant »,
## il dirait « il y a quelque chose à lancer ici », ce qui est faux.
func _accorder_lanceur(id: String) -> void:
	if panel_launch == null or not is_instance_valid(panel_launch):
		return
	var spec: Variant = LANCEURS.get(id, null)
	if not spec is Array:
		panel_launch.hide()
		panel_launch.remove_meta(META_LAUNCH_ACTION)
		return
	var couple: Array = spec
	panel_launch.show()
	panel_launch.set_meta(META_LAUNCH_BASE, String(couple[0]))
	panel_launch.set_meta(META_LAUNCH_ACTION, String(couple[1]))
	_sync_launch_entries()


func _on_hub_action(action: String) -> void:
	match action:
		"lancer":
			get_tree().paused = false
			replay_requested.emit()
		"quitter":
			get_tree().paused = false
			quit_requested.emit()
		"chercher":
			_start_search()
		"entrainement":
			get_tree().paused = false
			training_requested.emit()
		# DA4.18 — `montrer_texte` et non `show_detail` : ces deux entrées
		# promettent le cadre de droite dans leur propre libellé (« affichés à
		# droite », « sans quitter cet écran »), et `show_detail` envoie à
		# l'en-tête. La promesse était donc affichée au joueur et contredite à
		# chaque clic.
		"mon_rang":
			hub.montrer_texte("MON RANG", _my_rank_text())
		"top10":
			hub.montrer_texte("TOP 10", _top_ten_text())

## Ouvrir ou rejoindre un salon met fin à la recherche automatique.
##
## Les deux gestes disent la même chose : « j'ai trouvé mon adversaire ». Laisser
## la file tourner derrière donnerait un joueur apparié pendant qu'il joue déjà —
## et son ticket resterait annoncé, à proposer un adversaire injoignable à tous
## les autres.
##
## Le geste de sortie est explicite plutôt que déduit d'un état : la recherche
## vit **hors** des écrans, elle continue pendant qu'on parcourt les menus. C'est
## précisément ce qui fait qu'elle ne s'arrêterait pas toute seule.
func _abandon_search(raison: String) -> void:
	var core := get_node_or_null(^"/root/Matchmaker")
	if core == null or not core.has_method("cancel"):
		return
	# `cancel()` est sans effet au repos ; on ne l'annonce que si une recherche
	# tournait vraiment, sous peine d'une ligne de journal à chaque clic.
	var tournait := false
	if core.has_method("search_snapshot"):
		var snap: Variant = core.call("search_snapshot")
		tournait = snap is Dictionary and int((snap as Dictionary).get("state", 0)) != 0
	core.cancel()
	if tournait:
		print("UI: recherche d'adversaire interrompue — %s" % raison)

## Lance la recherche d'adversaire et rend la main.
##
## L'écran d'où l'on appuie décide de la file : « 1v1 amical » et « 1v1
## compétitif » portent la même entrée, et c'est le seul endroit où la différence
## se lit sans ambiguïté. Aucun état intermédiaire à tenir d'accord — le chemin
## emprunté EST la décision, comme pour le mode réseau et le transport.
##
## Un refus se dit. Sans Epic configuré, l'appariement est simplement impossible,
## et une entrée qui n'aurait rien fait passerait pour un bouton cassé.
func _start_search() -> void:
	var classe := hub.current_id() == SCREEN_RANKED
	_apply_queue_kind(classe)

	var core := get_node_or_null(^"/root/Matchmaker")
	if core == null or not core.has_method("start_search"):
		# Une installation sans Epic n'est pas en faute : le jeu se joue
		# normalement, seul l'appariement manque. `ATTENTION` et non `FAUTE`.
		show_dialog_message("Appariement indisponible",
			"L'appariement automatique n'est pas disponible sur cette installation.",
			Registre.ATTENTION)
		return

	# Un joueur non classé n'est pas estimé : le cœur ne le bride sur aucune
	# fourchette plutôt que de lui inventer un niveau.
	var note := -1
	# La CATÉGORIE part avec le ticket, à côté du classement. Le jeu ne sait pas
	# la dériver — `rankOf` vit côté serveur — et la règle du miroir en a besoin
	# des deux camps : sans cette ligne le transport existe mais publie zéro, et
	# l'arsenal commun serait toujours celui d'un joueur sans rang.
	var categorie := 0
	if is_instance_valid(RankedIdentity) and RankedIdentity.is_ranked:
		note = RankedIdentity.rating
		categorie = int(RankedIdentity.rank_tier_index)
	if not core.start_search(1 if classe else 0, note, false, categorie):
		var raison := String(core.last_error) if core.get("last_error") != null else ""
		show_dialog_message("Recherche impossible",
			raison if raison != "" else "La recherche n'a pas pu démarrer.",
			Registre.FAUTE)

## Le classement, en texte, pour le panneau de droite. Aucun chiffre inventé : un
## joueur sans ligne au classement n'a pas de rang, et on le dit.
func _my_rank_text() -> String:
	if not is_instance_valid(RankedIdentity):
		return "Classement non configuré sur cette installation."
	var label := RankedIdentity.standing_label()
	if label.is_empty():
		return "Classement indisponible pour l'instant."

	var rang: Dictionary = RankedIdentity.rank_snapshot() \
		if RankedIdentity.has_method("rank_snapshot") else {}
	# Sans rang connu, on n'en fabrique pas : un joueur jamais classé n'a pas de
	# catégorie, et « Aveugle I » serait aussi inventé que des points qu'il n'a
	# pas gagnés.
	if not bool(rang.get("connu", false)):
		return label

	var lignes: Array[String] = [String(rang.get("libelle", ""))]
	lignes.append(label)
	if bool(rang.get("au_sommet", false)):
		# Le sommet n'a pas de « prochain rang » : le dire vaut mieux qu'un blanc,
		# qui ressemblerait à une lecture qui n'a pas abouti.
		lignes.append("Sommet de l'échelle — plus rien au-dessus.")
	else:
		var reste := int(rang.get("points_restants", -1))
		var suivant := String(rang.get("suivant", ""))
		if reste >= 0 and not suivant.is_empty():
			lignes.append("%d point%s pour atteindre %s." % [reste,
				"s" if reste > 1 else "", suivant])
	return "\n\n".join(lignes)

func _top_ten_text() -> String:
	var snap: Dictionary = RankedIdentity.standing_snapshot() \
		if RankedIdentity.has_method("standing_snapshot") else {}
	if not bool(snap.get("loaded", false)):
		var err := String(snap.get("error", ""))
		return err if err != "" else "Lecture du classement en cours…"
	var top: Array = snap.get("top", [])
	if top.is_empty():
		return "Personne n'a encore joué de match classé."
	var out := PackedStringArray()
	for row in top:
		if not row is Dictionary:
			continue
		var d: Dictionary = row
		out.append("[b]%d.[/b]  %s  —  %d pts  ·  %s" % [
			int(d.get("rank", 0)), String(d.get("nickname", "—")),
			int(d.get("rating", 0)), String(d.get("rank_label", ""))])
	return "\n".join(out)

## Installe un `HubScreen` autonome dans un écran du hub.
##
## L'écran ne connaît ni le hub ni `ui.gd` : il demande la navigation par signal,
## et c'est ici — le seul endroit qui connaisse l'arborescence — qu'on décide si
## la demande est honorée.
func _attach_screen(id: String, title: String, screen: HubScreen) -> void:
	var body := hub.add_screen(id, title)
	screen.name = "Screen" + id.capitalize()
	body.add_child(screen)
	screen.build(body)
	screen.navigate_requested.connect(func(target: String) -> void: hub.push(target))
	_screens[id] = screen

## Un écran autonome monté en PANNEAU de droite, et non en écran à part.
##
## Rien à réécrire chez lui : le contrat `HubScreen` interdit à un écran de
## connaître sa position dans l'arborescence, précisément pour qu'on puisse l'y
## déplacer. On l'enveloppe dans un conteneur qui MESURE — un `Control` nu rend
## une taille minimale nulle même plein d'enfants.
func _attach_panel(key: String, screen: HubScreen) -> void:
	var boite := VBoxContainer.new()
	boite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.name = "Panneau" + key.capitalize()
	boite.add_child(screen)
	screen.build(boite)
	screen.navigate_requested.connect(func(target: String) -> void: hub.push(target))
	_screens[key] = screen
	hub.register_panel(key, boite)

## La calibration, en panneau de droite.
##
## L'écran autonome savait déjà tout faire ; seul son point d'accrochage change.
## On l'enveloppe dans un conteneur qui MESURE — un `Control` nu rend une taille
## minimale nulle même plein d'enfants, et la cible se poserait sous les entrées
## d'à côté.
func _build_calibration_panel() -> Control:
	var boite := VBoxContainer.new()
	boite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ecran := ScreenCalibration.new()
	ecran.name = "PanneauCalibration"
	boite.add_child(ecran)
	ecran.build(boite)
	_screens[SCREEN_CALIBRATION] = ecran
	return boite

## Les effets de vitrine s'éteignent **quand le champ de mesure est à l'écran**,
## et non quand un écran nommé « calibration » est ouvert.
##
## La nuance a coûté un déplacement : la calibration est devenue un panneau, et un
## garde-fou branché sur l'écran courant ne se serait plus levé du tout. Le champ
## se serait retrouvé grainé, embrumé et vignetté — sans que rien paraisse
## anormal, et en décalant le réglage de tous ceux qui calibrent de la même façon.
##
## Ce n'est pas un réglage de confort mais un contrat : trois centièmes de
## luminance parasite sur un champ mesuré faussent la mesure.
func _refresh_calibration_guard() -> void:
	var mesure := hub != null and hub.shown_panel() == PANEL_DISPLAY
	if mesure == _calibration:
		return
	_calibration = mesure
	_apply_menu_effects()
	if mesure and _screens.has(SCREEN_CALIBRATION):
		_screens[SCREEN_CALIBRATION].refresh()

## Chaque écran se remet en accord avec l'état du jeu au moment où il s'affiche,
## et jamais avant : rafraîchir un écran caché coûte des requêtes réseau que
## personne ne regarde.
## La description de l'entrée sous le curseur, affichée sous le titre du jeu.
##
## Le texte arrive en BBCode — le panneau de droite savait le rendre, une `Label`
## non. On le nettoie plutôt que d'imposer un `RichTextLabel` à l'en-tête, qui
## sert aussi à annoncer VICTOIRE et DÉFAITE.
func _on_hub_detail_changed(_title: String, text: String) -> void:
	if not _is_main_menu or game_over_score == null:
		return
	var propre := text.replace("[b]", "").replace("[/b]", "").replace("\n\n", "  ")
	game_over_score.text = propre
	# DA4.7 — **le bilan cède à toute description**, et la règle est dans ce sens
	# et pas dans l'autre. Les deux partagent la boîte ; ils ne peuvent donc pas
	# s'afficher ensemble. Le bilan est l'instantané du match qui vient de finir,
	# la description répond à un geste que le joueur fait **maintenant** — et ce
	# qu'on demande passe toujours avant ce qu'on nous montre.
	if propre != "":
		effacer_bilan()

func _on_hub_screen_changed(id: String) -> void:
	if _screens.has(id):
		var screen: HubScreen = _screens[id]
		screen.refresh()
	# Avant toute chose : quitter l'écran qui a ouvert un salon le referme. Cela
	# doit précéder la décision de mode ci-dessous, qui va justement changer.
	_close_lobby_if_left(id)
	# La visibilité des panneaux de droite appartient désormais au hub : elle suit
	# l'entrée sous le curseur, pas seulement l'écran. Ce qui se décidait ici se
	# décide dans `MenuHub._apply_panel()`.
	# Entrer dans un salon EST la décision de mode. Une seule affectation, à un
	# seul endroit — là où six bascules se contredisaient.
	match id:
		SCREEN_LOCAL:
			_intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
		SCREEN_LOCAL_HOST:
			_apply_lobby_intent(NetworkManager.GameMode.ONLINE_HOST,
				NetworkManager.Transport.ENET)
		SCREEN_LOCAL_JOIN:
			_apply_lobby_intent(NetworkManager.GameMode.ONLINE_CLIENT,
				NetworkManager.Transport.ENET)
		SCREEN_HOST:
			_apply_lobby_intent(NetworkManager.GameMode.ONLINE_HOST,
				NetworkManager.Transport.EOS)
		SCREEN_JOIN:
			_apply_lobby_intent(NetworkManager.GameMode.ONLINE_CLIENT,
				NetworkManager.Transport.EOS)

	# La nature du match se décide au menu, pas en jeu : entrer dans « 1V1
	# compétitif » est la seule façon de jouer classé. Tout le reste — écran
	# partagé, salon amical, entraînement — ne compte pas.
	#
	# `SCREEN_FRIENDLY` est dans cette liste et il a fallu l'y mettre : sans lui,
	# passer par « compétitif » puis revenir chercher un match amical laissait le
	# contexte à « classé », et un match sans enjeu serait remonté au classement.
	match id:
		SCREEN_RANKED: _apply_queue_kind(true)
		SCREEN_FRIENDLY, SCREEN_LOCAL, SCREEN_LOCAL_HOST, SCREEN_LOCAL_JOIN, \
		SCREEN_HOST, SCREEN_JOIN, SCREEN_TRAINING:
			_apply_queue_kind(false)
	_accorder_lanceur(id)
	if id in [SCREEN_LOCAL, SCREEN_HOST, SCREEN_JOIN, SCREEN_LOCAL_HOST,
			SCREEN_LOCAL_JOIN, SCREEN_FRIENDLY, SCREEN_RANKED]:
		_refresh_map_card()
		_refresh_lobby_block()
		_update_weapon_panels_visibility()
	if id == SCREEN_TRAINING and _leaderboard != null:
		_leaderboard.refresh()
	_seed_focus(0)
	_seed_focus(1)

## Pose le mode ET le transport d'un salon, en un seul geste.
##
## Les deux écrans de salon local se déclaraient **écran partagé**. Tout le bloc
## réseau se masquait donc — pas de bouton « créer le salon », pas d'adresse IP,
## pas de liste de joueurs — et « lancer le match » y démarrait un écran partagé
## au lieu d'héberger : les deux écrans étaient des doublons de « 1v1 écrans
## scindés » sous d'autres libellés.
##
## Et le transport n'était posé par personne. La feuille de route affirmait depuis
## le 17 août qu'entrer par « en local » posait `Transport.ENET` ; c'était une
## intention écrite au passé, jamais implémentée. Elle l'est ici, au seul endroit
## qui connaisse l'arborescence.
func _apply_lobby_intent(mode: NetworkManager.GameMode,
		transport: NetworkManager.Transport) -> void:
	_intended_mode = mode
	NetworkManager.transport = transport
	# Les deux bascules retirées de la vue ne sont plus qu'un MIROIR : plus rien
	# ne les lit pour décider. Le banc `test_online_match.tscn` les pilotait
	# encore pour choisir son transport ; depuis qu'il passe par les écrans, c'est
	# l'entrée dans le salon qui écrit le transport, et la bascule arrivait une
	# image trop tard — le chemin LAN repartait sur EOS (trouvé par le duo ENet,
	# 2026-08-18). On les tient à jour parce qu'elles s'affichent, pas parce
	# qu'elles décident. Sans signal, sous peine de rappeler
	# `_refresh_lobby_block()` en pleine reconstruction.
	if btn_transport_eos != null:
		btn_transport_eos.set_pressed_no_signal(transport == NetworkManager.Transport.EOS)
		btn_transport_lan.set_pressed_no_signal(transport != NetworkManager.Transport.EOS)

## Pose la nature du match — classé ou non — aux deux endroits qui doivent
## s'accorder : l'archivage, qui décide si le résultat remonte au classement, et
## l'écran de recherche, qui décide dans quelle file publier son ticket.
##
## Les deux en un seul geste, parce qu'un désaccord entre eux serait silencieux et
## coûteux : chercher dans la file classée et archiver en amical (ou l'inverse)
## ne lève aucune erreur, cela fausse simplement le classement.
func _apply_queue_kind(ranked: bool) -> void:
	if is_instance_valid(RankedIdentity) and RankedIdentity.has_method("set_ranked_context"):
		RankedIdentity.set_ranked_context(ranked)
	var recherche = _screens.get(SCREEN_MATCHMAKING, null)
	if recherche != null and recherche.has_method("set_ranked_queue"):
		recherche.set_ranked_queue(ranked)
	_weapon_context_ranked = ranked
	_refresh_weapon_locks()

## Grise les armes que le contexte ne permet pas, et dit pourquoi.
##
## **Grisées, jamais masquées** : un joueur doit voir ce qu'il possède même quand
## il ne peut pas s'en servir. Masquer laisserait croire que l'arme n'existe pas,
## et un râtelier dont la longueur change d'un écran à l'autre se lit comme un
## défaut.
##
## La règle vit dans `RankLoadout` et **nulle part ailleurs** : l'écran ne
## reconstruit pas le raisonnement, il affiche la phrase que la table lui rend.
## Deux explications du même refus finiraient par diverger, et c'est celle qui est
## affichée qui aurait tort.
##
## Le rang de l'adversaire est inconnu ici — rien ne l'échange encore. On montre
## donc sa propre sélection, qui ne peut que **rétrécir** à l'arrivée de l'autre
## sous la règle du miroir, jamais s'élargir : rien de ce qui est annoncé ne sera
## repris à tort.
func _refresh_weapon_locks() -> void:
	if p1_btn1 == null:
		return
	var tier := 0
	if is_instance_valid(RankedIdentity) and RankedIdentity.is_ranked:
		tier = int(RankedIdentity.rank_tier_index)
	# `RankedIdentity` est l'identité du POSTE, pas celle d'un râtelier. Elle ne
	# vaut donc que pour le joueur assis devant — et lui seul. En écran partagé,
	# appliquer ce rang au second joueur lui prêterait celui du premier ; face à un
	# adversaire en ligne, cela lui prêterait le nôtre, alors que son rang n'est
	# pas encore échangé.
	#
	# Le client tient P2 (`_local_p2_weapon_idx` lit son groupe), tout le reste
	# tient P1. Les autres râteliers gardent le socle : ne rien verrouiller vaut
	# mieux que verrouiller d'après le mauvais joueur, une arme retirée à tort
	# étant plus fâcheuse qu'une arme offerte à tort — la seconde se rattrape à
	# l'arrivée de l'adversaire par la règle du miroir.
	#
	# Inerte aujourd'hui : hors compétitif le socle est entier de toute façon.
	# Signalé par une session voisine, corrigé avant que ça morde — le jour où une
	# arme sera réservée au classé.
	var rateau_local := 1 if selected_network_mode() \
		== NetworkManager.GameMode.ONLINE_CLIENT else 0
	for cote in [0, 1]:
		var groupe: ButtonGroup = p1_weapon_group if cote == 0 else p2_weapon_group
		var boutons: Array = [p1_btn1, p1_btn2, p1_btn3, p1_btn4] if cote == 0 \
			else [p2_btn1, p2_btn2, p2_btn3, p2_btn4]
		var tier_du_cote := tier if cote == rateau_local else 0
		var premier_libre := -1
		for i in boutons.size():
			var btn: Button = boutons[i]
			if btn == null:
				continue
			var libre := RankLoadout.is_available(i, _weapon_context_ranked,
				tier_du_cote)
			btn.disabled = not libre
			btn.modulate = Color.WHITE if libre else Color(1.0, 1.0, 1.0, 0.4)
			btn.tooltip_text = RankLoadout.reason_for(i, _weapon_context_ranked,
				tier_du_cote)
			if libre and premier_libre < 0:
				premier_libre = i
		# Une arme verrouillée qui reste SÉLECTIONNÉE partirait au match : le
		# bouton est grisé, mais le groupe garde son choix. On rabat sur la
		# première arme disponible plutôt que de laisser jouer ce qui est refusé.
		var choisi: BaseButton = groupe.get_pressed_button()
		if premier_libre >= 0 and (choisi == null or choisi.disabled):
			(boutons[premier_libre] as Button).button_pressed = true

## Le titre du menu porte tantôt le nom du jeu, tantôt un verdict. Un seul
## endroit tranche, sinon un chemin oublié laisserait le logo sur « DÉFAITE ».
## `self_modulate` et non `modulate` : le second effacerait aussi l'enfant.
func _poser_titre(texte: String) -> void:
	game_over_title.text = texte
	if menu_enseigne == null or not is_instance_valid(menu_enseigne):
		return
	var enseigne := texte == "CANDELA 2D"
	menu_enseigne.visible = enseigne
	game_over_title.self_modulate.a = 0.0 if enseigne else 1.0

func _build_menu_header() -> Control:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", GAP_XS)

	game_over_title = Label.new()
	_poser_titre("CANDELA 2D")
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# DA4 — l'enseigne, et elle referme une incohérence entre l'arène et
	# l'interface. `player.gd` écrit déjà FATAL en fonte d'affichage à
	# `T_ENSEIGNE` ; ce nœud-ci écrivait VICTOIRE et DÉFAITE en fonte
	# d'interface. **Les deux mots tombent à quelques secondes d'intervalle sur le
	# même temps fort**, l'un dans l'arène, l'autre sur l'écran de fin — et ils ne
	# se ressemblaient pas.
	#
	# Rien ne tremble ici : les cinq textes de ce `Label` sont des mots, pas des
	# compteurs, et le seul qui contient un chiffre (« CANDELA 2D ») est de toute
	# façon recouvert par l'enseigne dessinée de DA1.6.
	Charte.enseigne(game_over_title, T_ENSEIGNE)
	game_over_title.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(game_over_title)

	# DA1.6 — l'enseigne dessinée, posée PAR-DESSUS le `Label` et non à sa place.
	# Le même nœud porte cinq textes : le nom du jeu, « OPTIONS », et trois
	# verdicts. Seul le premier a un logo ; les autres restent du texte, avec la
	# braise M11 et l'ombre M1 intactes. Enfant du `Label`, donc calé sur son
	# rectangle : le gnomon s'y ancre déjà, il n'a rien à réapprendre.
	menu_enseigne = TextureRect.new()
	menu_enseigne.name = "Enseigne"
	menu_enseigne.texture = load(Charte.CHEMIN_ENSEIGNE)
	# Centrée dans le rectangle du `Label`, à une taille CALCULÉE et non choisie :
	# l'encre du fichier occupe 482 px sur 508 de haut, on vise 80 px d'encre à
	# l'écran — la hauteur du titre qu'elle remplace. Ancrer en plein cadre
	# donnait un logo pleine page, le rectangle du `Label` faisant toute la
	# largeur de l'en-tête.
	const ENCRE_VISEE := 80.0
	const ENCRE_DU_FICHIER := 482.0 / 508.0
	var h := ENCRE_VISEE / ENCRE_DU_FICHIER
	var l := h * 1600.0 / 508.0
	menu_enseigne.anchor_left = 0.5
	menu_enseigne.anchor_right = 0.5
	menu_enseigne.anchor_top = 0.5
	menu_enseigne.anchor_bottom = 0.5
	menu_enseigne.offset_left = -l * 0.5
	menu_enseigne.offset_right = l * 0.5
	menu_enseigne.offset_top = -h * 0.5
	menu_enseigne.offset_bottom = h * 0.5
	menu_enseigne.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Sans ceci, la taille MINIMALE du contrôle est celle de la texture (1600 px) :
	# elle écrase les offsets ci-dessus et le logo déborde de l'écran. Le défaut
	# de `TextureRect` est `EXPAND_KEEP_SIZE`, ce qui ne se voit pas dans le code
	# qui pose une taille — il se voit à l'écran, en grand.
	menu_enseigne.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_enseigne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_title.add_child(menu_enseigne)
	_poser_titre("CANDELA 2D")

	# M1 — le cadran. Derrière le titre, hors du flux : ancré en plein cadre sur
	# l'en-tête, il ne pousse rien et ne rétrécit rien. `move_child` le place sous
	# le `Label`, sinon l'ombre couvrirait le mot qu'elle projette.
	menu_gnomon = MenuGnomon.new(game_over_title)
	header.add_child(menu_gnomon)
	header.move_child(menu_gnomon, 0)

	# M11 — le titre lui-même devient une braise. Le matériau vit sur le `Label` ;
	# ce nœud ne porte que ce que le shader ne peut pas savoir : la largeur du
	# bloc, le moment de l'embrasement, et l'issue du match.
	menu_title = MenuTitle.new()
	header.add_child(menu_title)
	menu_title.adopter(game_over_title)

	game_over_score = Label.new()
	game_over_score.text = ""
	game_over_score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_score.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	game_over_score.add_theme_font_size_override("font_size", T_APPUI)
	game_over_score.add_theme_color_override("font_color", COLOR_DIM)
	game_over_score.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# La description de l'écran courant tient sur une ou deux lignes selon
	# l'entrée survolée. Sans ce conteneur, le `Label` grandit avec son texte —
	# un `custom_minimum_size` n'est qu'un plancher — et tout ce qui suit dans
	# le menu saute d'un cran à chaque survol plus long. Le conteneur, lui, est
	# un `Control` nu (pas un `Container`) : sa taille ne suit pas celle de son
	# enfant, elle reste fixée à deux lignes, texte plus long ou non.
	var desc_box := Control.new()
	desc_box.custom_minimum_size = Vector2(0, 60)
	desc_box.clip_contents = true
	desc_box.add_child(game_over_score)
	desc_box.add_child(_build_bilan())
	header.add_child(desc_box)

	return header


## DA4.7 — le bilan de fin de match, composé au lieu d'être empilé.
##
## **Ce que la fin de match affichait : une seule ligne grise.**
## `SESSION : 2 - 1   ·   3 D'AFFILÉE`, à 19 px, en `DIM`, écrite par
## `game_state.gd` **dans le label des descriptions d'entrées**. Trois
## informations de nature différente — un score qui se compare, une série qui
## s'exalte, un mode — séparées par des points médians et toutes du même poids.
## C'est la définition d'un empilement : rien n'y a de rang, donc l'œil n'a pas
## d'entrée.
##
## Composé, chaque chose reprend son registre :
##
## - **le score de session** est un COMPTEUR — appareil, tabulaire, et les deux
##   nombres sont teintés de la couleur de leur joueur, ce qui les rend lisibles
##   sans lire le libellé ;
## - **la série** est un CRI — enseigne, ambre, et elle n'apparaît que
##   lorsqu'elle existe. Une ligne « série : aucune » serait une ligne qui
##   occupe la place d'une ligne qui aurait quelque chose à dire.
##
## **Il vit dans la même boîte que la description, et c'est délibéré.** Les deux
## ne coexistent jamais : le bilan appartient à l'écran de fin, la description au
## survol d'une entrée. Partager la boîte garantit qu'ils ne se poussent pas —
## et le défaut inverse existait déjà, `show_lobby_again()` devant effacer à la
## main un score qui restait affiché sous un salon attendant le match suivant.
func _build_bilan() -> Control:
	bilan = HBoxContainer.new()
	bilan.name = "Bilan"
	bilan.alignment = BoxContainer.ALIGNMENT_CENTER
	bilan.add_theme_constant_override("separation", GAP_L)
	bilan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bilan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bilan.hide()

	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 0)
	bilan.add_child(colonne)

	var legende := Label.new()
	legende.text = "SESSION"
	legende.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Charte.appareil(legende, T_MENTION)
	legende.add_theme_color_override("font_color", COLOR_DIM)
	colonne.add_child(legende)

	# Le score en trois `Label` et non en un seul : c'est le seul moyen de teinter
	# chaque nombre de la couleur de son joueur. Une chaîne unique obligerait au
	# bbcode, donc à un `RichTextLabel`, donc à perdre l'alignement tabulaire que
	# `T_TITRE` en appareil garantit ici.
	var score := HBoxContainer.new()
	score.alignment = BoxContainer.ALIGNMENT_CENTER
	score.add_theme_constant_override("separation", GAP_XXS)
	colonne.add_child(score)

	bilan_p1 = _make_chiffre_de_bilan(COLOR_P1)
	score.add_child(bilan_p1)
	var tiret := Label.new()
	tiret.text = "–"
	Charte.appareil(tiret, T_TITRE)
	tiret.add_theme_color_override("font_color", COLOR_LINE)
	score.add_child(tiret)
	bilan_p2 = _make_chiffre_de_bilan(COLOR_P2)
	score.add_child(bilan_p2)

	bilan_serie = Label.new()
	bilan_serie.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# L'enseigne : une série est une chose qu'on annonce, pas une valeur qu'on
	# relève. Elle ne se remplace jamais sur place — elle apparaît, elle s'en va —
	# donc la fonte d'affichage n'y pose aucun risque de tremblement.
	Charte.enseigne(bilan_serie, T_TITRE)
	bilan_serie.add_theme_color_override("font_color", COLOR_GOLD)
	bilan_serie.hide()
	bilan.add_child(bilan_serie)

	return bilan


func _make_chiffre_de_bilan(teinte: Color) -> Label:
	var l := Label.new()
	l.text = "0"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Appareil : ces deux nombres se remplacent sur place à chaque manche.
	Charte.appareil(l, T_TITRE)
	l.add_theme_color_override("font_color", teinte)
	return l


## Pose le bilan de fin de match. Appelée par `game_state.gd`, qui seul connaît
## le score de session et la série.
##
## `serie` vide = pas de série en cours, et la ligne disparaît **entièrement**
## plutôt que d'afficher une absence.
func poser_bilan(p1_wins: int, p2_wins: int, serie: String = "") -> void:
	if bilan == null:
		return
	bilan_p1.text = str(p1_wins)
	bilan_p2.text = str(p2_wins)
	var mot := serie.strip_edges()
	bilan_serie.text = mot.to_upper()
	bilan_serie.visible = mot != ""
	# La description et le bilan partagent la boîte : montrer l'un efface l'autre.
	game_over_score.text = ""
	bilan.show()


## Rend la boîte à la description d'entrée. Sans cela, le bilan du match écoulé
## resterait sous un salon qui attend le suivant — défaut déjà corrigé une fois
## sur `game_over_score`, et qui se serait rouvert sur le bloc composé.
func effacer_bilan() -> void:
	if bilan != null:
		bilan.hide()

## Bouton générique du menu. `primary` remplit le fond avec la teinte donnée.
func _make_button(label: String, accent: Color, primary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", T_APPUI)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.85) if primary else COLOR_SURFACE
	normal.set_border_width_all(2)
	normal.border_color = accent if primary else Color(accent.r, accent.g, accent.b, 0.4)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = GAP_M
	normal.content_margin_right = GAP_M
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Charte.HALOGENE
	hover.bg_color = accent if primary else Color(accent.r, accent.g, accent.b, 0.16)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.shadow_size = 8
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = accent
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(Charte.SURFACE, 0.8)
	disabled.border_color = COLOR_LINE
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Charte.DIM * 0.68)

	if primary:
		btn.add_theme_color_override("font_color", Charte.NOIR)
		btn.add_theme_color_override("font_hover_color", Charte.NOIR)
		btn.add_theme_color_override("font_pressed_color", Charte.NOIR)
		btn.add_theme_color_override("font_hover_pressed_color", Charte.NOIR)
		btn.add_theme_color_override("font_focus_color", Charte.NOIR)

	return btn

## Bouton à bascule d'un groupe de choix (mode de jeu, résolution…).
func _make_choice_button(label: String, accent: Color, group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(200, 48)
	btn.add_theme_font_size_override("font_size", T_COURANT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_SURFACE
	normal.set_border_width_all(2)
	normal.border_color = COLOR_LINE
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var active := normal.duplicate() as StyleBoxFlat
	active.bg_color = Color(accent.r, accent.g, accent.b, 0.9)
	active.border_color = Charte.HALOGENE
	active.shadow_color = Color(accent.r, accent.g, accent.b, 0.4)
	active.shadow_size = 10
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("hover_pressed", active)

	btn.add_theme_color_override("font_pressed_color", Charte.NOIR)
	btn.add_theme_color_override("font_hover_pressed_color", Charte.NOIR)
	return btn

func _make_section_label(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", T_MENTION)
	label.add_theme_color_override("font_color", tint)
	return label

## Carte sélectionnée, affichée dans le panneau du salon : on sait toujours sur
## quoi on s'apprête à jouer.
##
## Ce n'était plus une carte mais un bouton, qui poussait vers l'écran des cartes.
## Il ouvrait un second chemin vers la galerie, à côté de l'entrée « CHANGER DE
## CARTE » de la liste — et deux gestes pour une décision, c'est un de trop : la
## galerie s'affiche maintenant à droite, exactement là où ce bouton se trouvait.
## Il redevient donc ce qu'il annonce, un état, et sort du parcours du curseur.
func _build_map_card() -> Control:
	map_card = PanelContainer.new()
	map_card.custom_minimum_size = Vector2(400, 104)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_SURFACE
	normal.set_border_width_all(2)
	normal.border_color = COLOR_LINE
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	map_card.add_theme_stylebox_override("panel", normal)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_card.add_child(row)

	map_card_thumb = TextureRect.new()
	map_card_thumb.custom_minimum_size = Vector2(80, 80)
	map_card_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_card_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_card_thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_card_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(map_card_thumb)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", GAP_XXS)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)

	var kicker := Label.new()
	kicker.text = "CARTE"
	kicker.add_theme_font_size_override("font_size", T_MENTION)
	kicker.add_theme_color_override("font_color", COLOR_DIM)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(kicker)

	map_card_name = Label.new()
	map_card_name.text = "—"
	map_card_name.add_theme_font_size_override("font_size", T_APPUI)
	map_card_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	map_card_name.clip_text = true
	map_card_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(map_card_name)

	map_card_meta = Label.new()
	map_card_meta.text = ""
	map_card_meta.add_theme_font_size_override("font_size", T_MENTION)
	map_card_meta.add_theme_color_override("font_color", COLOR_DIM)
	map_card_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(map_card_meta)

	return map_card

func _refresh_map_card() -> void:
	if map_card == null:
		return
	var entry := MapData.get_map(MapData.selected_map_id)
	if entry.is_empty():
		map_card_name.text = "Aucune carte"
		map_card_meta.text = ""
		map_card_thumb.texture = null
		return

	var grid: Vector2i = entry["grid_size"]
	var origin := "Officielle" if String(entry["source"]) == "builtin" else "Perso"
	map_card_name.text = String(entry["name"])
	map_card_meta.text = "%d×%d  ·  %d murs  ·  %s" % [
		grid.x, grid.y, int(entry["wall_count"]), origin,
	]
	map_card_thumb.texture = MapThumbnail.render_fit(entry["data"], 80)

## Construit les pièces du salon, sans les rattacher : ce sont les écrans du hub
## qui décident où elles s'affichent.
##
## Les bascules « 1V1 LOCAL / EN LIGNE » et « CRÉER / REJOINDRE » ont disparu.
## Elles portaient l'intention de mode, que `selected_network_mode()` lisait dans
## leur `button_pressed` — un état d'interface tenant lieu de décision, que six
## connexions de boutons n'arrivaient plus à garder cohérent. L'intention vit
## désormais dans `_intended_mode`, posée par la navigation : entrer dans le salon
## local, c'est vouloir jouer en local, et ça se dit une fois.
##
## Le choix du transport reste un bouton, lui : Internet ou réseau local est une
## vraie alternative offerte au joueur, pas une conséquence de sa navigation.
func _build_lobby_widgets() -> void:
	# Le réseau local reste accessible : c'est le seul mode qui permette de jouer
	# (et de déboguer) quand Epic est injoignable.
	var transport_group := ButtonGroup.new()
	transport_hbox = HBoxContainer.new()
	transport_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	transport_hbox.add_theme_constant_override("separation", GAP_S)
	btn_transport_eos = _make_choice_button("INTERNET", COLOR_P1, transport_group)
	btn_transport_eos.button_pressed = NetworkManager.transport == NetworkManager.Transport.EOS
	btn_transport_lan = _make_choice_button("RÉSEAU LOCAL", COLOR_P1, transport_group)
	btn_transport_lan.button_pressed = not btn_transport_eos.button_pressed
	transport_hbox.add_child(btn_transport_eos)
	transport_hbox.add_child(btn_transport_lan)

	lobby_status_label = Label.new()
	lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status_label.add_theme_font_size_override("font_size", T_MENTION)
	lobby_status_label.add_theme_color_override("font_color", COLOR_GOLD)
	lobby_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Le code n'existe qu'une fois le salon ouvert, c'est-à-dire au lancement du
	# match : d'ici là cette ligne annonce ce qui va se passer.
	lobby_code_row = HBoxContainer.new()
	lobby_code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lobby_code_row.add_theme_constant_override("separation", GAP_XS)

	lobby_code_engraver = MenuEngraver.new()
	lobby_code_row.add_child(lobby_code_engraver)

	btn_copy_code = _make_button("COPIER", COLOR_GOLD)
	btn_copy_code.add_theme_font_size_override("font_size", T_MENTION)
	btn_copy_code.pressed.connect(_copy_lobby_code)
	lobby_code_row.add_child(btn_copy_code)

	# Sans son adresse sous les yeux, l'hôte LAN n'a rien à transmettre à l'autre
	# joueur : elle est affichée dès l'entrée dans le salon.
	host_ip_row = HBoxContainer.new()
	host_ip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	host_ip_row.add_theme_constant_override("separation", GAP_XS)

	# Le libellé reste un libellé : graver « VOTRE IP » caractère par caractère
	# serait long et n'a rien d'un objet qu'on transmet. Seule l'adresse se grave.
	host_ip_prefix = Label.new()
	host_ip_prefix.text = "VOTRE IP"
	host_ip_prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host_ip_prefix.add_theme_font_size_override("font_size", T_MENTION)
	host_ip_prefix.add_theme_color_override("font_color", COLOR_DIM)
	host_ip_row.add_child(host_ip_prefix)

	host_ip_engraver = MenuEngraver.new(0, 20, COLOR_GOLD)
	host_ip_row.add_child(host_ip_engraver)

	var btn_copy_ip := _make_button("COPIER", COLOR_GOLD)
	btn_copy_ip.add_theme_font_size_override("font_size", T_MENTION)
	btn_copy_ip.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(local_ipv4())
		host_ip_engraver.marquer_copie()
	)
	host_ip_row.add_child(btn_copy_ip)

	join_input = LineEdit.new()
	join_input.custom_minimum_size = Vector2(216, 40)
	join_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Le champ n'accepte que ce qu'un code peut contenir : le joueur ne peut pas
	# taper une saisie invalide, il n'y a donc rien à lui refuser après coup.
	join_input.text_changed.connect(func(text: String) -> void:
		if NetworkManager.transport != NetworkManager.Transport.EOS:
			return
		var clean := LobbyCode.sanitize(text)
		if clean == text:
			return
		var caret := join_input.caret_column - (text.length() - clean.length())
		join_input.text = clean
		join_input.caret_column = maxi(caret, 0)
	)

	btn_transport_eos.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			return
		NetworkManager.transport = NetworkManager.Transport.EOS
		join_input.text = LobbyCode.sanitize(join_input.text)
		_refresh_lobby_block()
	)
	btn_transport_lan.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			return
		NetworkManager.transport = NetworkManager.Transport.ENET
		_refresh_lobby_block()
	)

	# Le rang arrive en tâche de fond, après l'identification : les armes doivent
	# se déverrouiller à ce moment-là sans que le joueur ait à ressortir de
	# l'écran. Sans ce branchement, un joueur classé verrait le râtelier d'un
	# joueur sans rang jusqu'à sa prochaine navigation.
	if is_instance_valid(RankedIdentity) and RankedIdentity.has_signal("standing_changed"):
		RankedIdentity.standing_changed.connect(_refresh_weapon_locks)
	NetworkManager.lobby_code_ready.connect(_on_lobby_code_ready)
	NetworkManager.eos_state_changed.connect(func(_state) -> void: _refresh_lobby_block())
	# La liste des joueurs se tient à jour d'elle-même : l'hôte qui attend dans son
	# salon doit voir l'adversaire arriver sans avoir à toucher à quoi que ce soit.
	NetworkManager.player_connected.connect(func(_id: int) -> void: _refresh_player_list())
	NetworkManager.player_disconnected.connect(func(_id: int) -> void: _refresh_player_list())

## Applique l'état du bloc lobby en un seul endroit : quatre combinaisons
## (local / hôte / client) × (Internet / LAN) que six connexions de boutons
## indépendantes n'arrivaient plus à tenir cohérentes.
func _refresh_lobby_block() -> void:
	if lobby_status_label == null:
		return

	# La carte se remontre à chaque passage : la branche de l'appariement la cache,
	# et sans cette remise à zéro elle resterait cachée dans tous les salons visités
	# ensuite — un défaut qui ne se voit qu'après un détour par la file.
	map_card.show()

	# L'appariement n'a ni carte à choisir ni code à transmettre. Le seul choix qui
	# reste au joueur est son arme, et c'est tout ce que le panneau garde.
	if hub != null and hub.current_id() in [SCREEN_FRIENDLY, SCREEN_RANKED]:
		map_card.hide()
		transport_hbox.hide()
		lobby_players_box.hide()
		lobby_code_row.hide()
		host_ip_row.hide()
		join_box.hide()
		btn_open_lobby.hide()
		lobby_status_label.show()
		lobby_status_label.text = "Choisissez votre arme avant de lancer la recherche — l'arène est tirée au sort"
		return

	var mode := selected_network_mode()
	var is_eos := NetworkManager.transport == NetworkManager.Transport.EOS
	# La barre d'actions est construite après ce bloc : au premier passage le
	# bouton n'existe pas encore, show_main_menu le rattrapera.
	if btn_replay != null:
		btn_replay.text = "REJOINDRE LE SALON" if mode == NetworkManager.GameMode.ONLINE_CLIENT \
			else "LANCER LE MATCH"

	if mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		transport_hbox.hide()
		lobby_status_label.hide()
		lobby_code_row.hide()
		host_ip_row.hide()
		join_box.hide()
		lobby_players_box.hide()
		btn_open_lobby.hide()
		return

	lobby_players_box.show()
	_refresh_player_list()

	# La bascule de transport ne se remontre JAMAIS : entrer par « en ligne » ou par
	# « en local » EST le choix, et le reproposer ici remettrait en question une
	# décision déjà prise. Elle reste dans l'arbre, cachée, parce que cette fonction
	# lit encore son état — le retirer demanderait de réécrire les quatre
	# combinaisons de mode et de transport.
	lobby_status_label.show()

	if mode == NetworkManager.GameMode.ONLINE_HOST:
		join_box.hide()
		host_ip_row.visible = not is_eos
		lobby_code_row.visible = is_eos
		var ouvert := NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST
		if is_eos:
			_update_lobby_code_label()
			lobby_status_label.text = "%s  ·  %s" % [NetworkManager.eos_state_label(),
				"transmettez ce code à votre adversaire" if ouvert
				else "créez le salon pour obtenir un code"]
		else:
			host_ip_engraver.set_code(local_ipv4())
			lobby_status_label.text = "Réseau local — communiquez votre IP à votre adversaire" \
				if ouvert else "Réseau local — créez le salon, puis communiquez votre IP"
		return

	# Client — il n'y a pas de salon à ouvrir de ce côté, seulement un à rejoindre.
	host_ip_row.hide()
	lobby_code_row.hide()
	join_box.show()
	btn_open_lobby.hide()
	if is_eos:
		join_input.placeholder_text = "CODE À %d CARACTÈRES" % LobbyCode.LENGTH
		join_input.max_length = LobbyCode.LENGTH
		join_input.text = LobbyCode.sanitize(join_input.text)
		lobby_status_label.text = "%s  ·  entrez le code communiqué par l'hôte" \
			% NetworkManager.eos_state_label()
	else:
		join_input.placeholder_text = "127.0.0.1"
		join_input.max_length = 0
		lobby_status_label.text = "Réseau local — entrez l'IP de l'hôte"

func _on_lobby_code_ready(_code: String) -> void:
	_update_lobby_code_label()
	# Le code peut arriver alors qu'on est encore au menu — c'est même désormais
	# le cas ordinaire, « CRÉER LE SALON » ouvrant le salon sans lancer la manche.
	if _is_main_menu:
		_refresh_lobby_block()
	# Sinon l'hôte est déjà dans l'arène : c'est l'écran d'attente qui porte le
	# code, pas le menu qu'il vient de quitter.
	elif waiting_label.visible:
		show_waiting_for_opponent()

func _update_lobby_code_label() -> void:
	var code: String = NetworkManager.lobby_code
	var known := not code.is_empty()
	# Chaîne vide = pas de salon : les six cases gardent leur tiret, et rien ne se
	# grave. `set_code` est idempotent, donc les rafraîchissements du bloc salon —
	# nombreux et sans rapport — ne rejouent pas la gravure.
	lobby_code_engraver.set_code(code if known else "")
	btn_copy_code.disabled = not known

func _copy_lobby_code() -> void:
	if NetworkManager.lobby_code.is_empty():
		return
	DisplayServer.clipboard_set(NetworkManager.lobby_code)
	lobby_code_engraver.marquer_copie()

func _build_weapon_block() -> Control:
	weapon_hbox = HBoxContainer.new()
	weapon_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_hbox.add_theme_constant_override("separation", GAP_L + GAP_XS)

	p1_weapon_group = ButtonGroup.new()
	p2_weapon_group = ButtonGroup.new()

	p1_vbox = VBoxContainer.new()
	p1_vbox.add_theme_constant_override("separation", GAP_XS)
	p1_vbox.add_child(_make_section_label("ARME — JOUEUR 1", COLOR_P1))

	# Contrat : l'index de l'arme est l'index du bouton dans son conteneur.
	# Ce HBox ne doit donc contenir QUE les quatre boutons d'arme, dans l'ordre.
	var p1_row := HBoxContainer.new()
	p1_row.add_theme_constant_override("separation", GAP_XS)
	p1_btn1 = _create_weapon_btn("🔫 Pistolet", p1_weapon_group, COLOR_P1, 0)
	p1_btn2 = _create_weapon_btn("💥 Fusil", p1_weapon_group, COLOR_P1, 0)
	p1_btn3 = _create_weapon_btn("☄️ Pompe", p1_weapon_group, COLOR_P1, 0)
	p1_btn4 = _create_weapon_btn("🏹 Arbalète", p1_weapon_group, COLOR_P1, 0)
	p1_btn1.button_pressed = true
	p1_btn1.set_meta(META_NAV_SEED, 0)
	p1_row.add_child(p1_btn1)
	p1_row.add_child(p1_btn2)
	p1_row.add_child(p1_btn3)
	p1_row.add_child(p1_btn4)
	p1_vbox.add_child(p1_row)
	weapon_hbox.add_child(p1_vbox)

	p2_vbox = VBoxContainer.new()
	p2_vbox.add_theme_constant_override("separation", GAP_XS)
	p2_vbox.add_child(_make_section_label("ARME — JOUEUR 2", COLOR_P2))

	var p2_row := HBoxContainer.new()
	p2_row.add_theme_constant_override("separation", GAP_XS)
	p2_btn1 = _create_weapon_btn("🔫 Pistolet", p2_weapon_group, COLOR_P2, 1)
	p2_btn2 = _create_weapon_btn("💥 Fusil", p2_weapon_group, COLOR_P2, 1)
	p2_btn3 = _create_weapon_btn("☄️ Pompe", p2_weapon_group, COLOR_P2, 1)
	p2_btn4 = _create_weapon_btn("🏹 Arbalète", p2_weapon_group, COLOR_P2, 1)
	p2_btn1.button_pressed = true
	p2_btn1.set_meta(META_NAV_SEED, 1)
	p2_row.add_child(p2_btn1)
	p2_row.add_child(p2_btn2)
	p2_row.add_child(p2_btn3)
	p2_row.add_child(p2_btn4)
	p2_vbox.add_child(p2_row)
	weapon_hbox.add_child(p2_vbox)

	return weapon_hbox

## `nav_owner` réserve le bouton au joueur concerné : le curseur de J1 ne peut
## pas entrer dans la rangée de J2, et réciproquement.
func _create_weapon_btn(text: String, group: ButtonGroup, tint: Color, owner_id: int) -> Button:
	var btn := _make_choice_button(text, tint, group)
	btn.text = text
	btn.custom_minimum_size = Vector2(136, 80)
	btn.add_theme_font_size_override("font_size", T_COURANT)
	btn.set_meta(META_NAV_OWNER, owner_id)
	return btn

# ---------------------------------------------------------------------------
# PANNEAU DE PAUSE
# ---------------------------------------------------------------------------

## Panneau court, sans onglet et sans préparation de match : on est déjà en jeu.
##
## Le fond est volontairement moins opaque que celui du menu (0,88 contre 0,96) :
## en ligne la simulation continue derrière, et masquer complètement un monde qui
## bouge encore ment sur ce qui se passe.
func _build_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.hide()
	add_child(pause_panel)

	var backdrop := ColorRect.new()
	backdrop.name = "Rideau"
	backdrop.color = Color(Charte.BACKDROP, 0.88)
	backdrop.set_meta(META_ALPHA_NUIT, backdrop.color.a)
	pause_panel.add_child(backdrop)
	# Le même matériau que le menu : les deux fonds ne sont jamais visibles
	# ensemble et couvrent le même cadre.
	if menu_backdrop != null:
		menu_backdrop.adopter(backdrop)
	if RELECTURE_ECRAN:
		pause_veil = MenuVeil.new()
		pause_panel.add_child(pause_veil)

	var center := CenterContainer.new()
	pause_panel.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", GAP_S)
	center.add_child(column)
	pause_panel.set_meta(META_CASCADE, column)

	pause_title = Label.new()
	pause_title.text = "PAUSE"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", T_VERDICT)
	column.add_child(pause_title)

	pause_score_label = Label.new()
	pause_score_label.text = "SESSION : 0 - 0"
	pause_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_score_label.add_theme_font_size_override("font_size", T_TITRE)
	pause_score_label.add_theme_color_override("font_color", COLOR_DIM)
	column.add_child(pause_score_label)

	pause_time_label = Label.new()
	pause_time_label.text = "TEMPS RESTANT : 00:00"
	pause_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_time_label.add_theme_font_size_override("font_size", T_TITRE)
	pause_time_label.add_theme_color_override("font_color", COLOR_DIM)
	column.add_child(pause_time_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, GAP_M)
	column.add_child(spacer)

	# Colonne plutôt que rangée : c'est la forme qui se parcourt le plus
	# naturellement au curseur, et la pause n'a que quatre issues.
	btn_pause_resume = _make_pause_button("REPRENDRE", COLOR_P1, true)
	btn_pause_resume.pressed.connect(_resume_game)
	column.add_child(btn_pause_resume)

	btn_pause_options = _make_pause_button("OPTIONS", COLOR_GOLD)
	btn_pause_options.pressed.connect(_open_pause_options)
	column.add_child(btn_pause_options)

	btn_pause_menu = _make_pause_button("MENU PRINCIPAL", COLOR_DIM)
	btn_pause_menu.pressed.connect(func() -> void:
		get_tree().paused = false
		main_menu_requested.emit()
	)
	column.add_child(btn_pause_menu)

	btn_pause_quit = _make_pause_button("QUITTER", COLOR_P2)
	btn_pause_quit.pressed.connect(func() -> void:
		get_tree().paused = false
		quit_requested.emit()
	)
	column.add_child(btn_pause_quit)

func _make_pause_button(label: String, accent: Color, primary: bool = false) -> Button:
	var btn := _make_button(label, accent, primary)
	btn.custom_minimum_size = Vector2(320, 56)
	btn.add_theme_font_size_override("font_size", T_APPUI)
	return btn

## Ouvre la pause. `_pause_freezes_world` décide du gel : en ligne il figerait la
## simulation des deux joueurs, ce panneau se superpose donc à un monde qui court.
func _open_pause() -> void:
	if _pause_freezes_world():
		get_tree().paused = true

	var gs := get_parent()
	if gs and gs is GameState:
		pause_score_label.text = "SESSION : %d - %d" % [gs.p1_session_wins, gs.p2_session_wins]
		var m := floori(gs.time_left) / 60
		var s := floori(gs.time_left) % 60
		pause_time_label.text = "TEMPS RESTANT : %02d:%02d" % [m, s]

	_allumer(pause_panel, true)
	_seed_focus(0)
	_seed_focus(1)

## Les réglages en cours de match, empruntés au menu à onglets faute d'écran
## propre — voir `_options_from_pause`. Seul CONTRÔLES est montré : la pause
## n'ouvre pas le menu, elle ouvre les options.
func _open_pause_options() -> void:
	_options_from_pause = true
	_fermer_sec(pause_panel)

	btn_replay.hide()
	btn_main_menu.hide()
	btn_quit.hide()
	btn_back.show()

	_poser_titre("OPTIONS")
	game_over_title.add_theme_color_override("font_color", Charte.HALOGENE)
	game_over_score.text = ""

	hub.reset()
	hub.push(SCREEN_CUSTOM)
	_ouvrir_sec(game_over_panel)

func _close_pause_options() -> void:
	_options_from_pause = false
	btn_back.hide()
	_fermer_sec(game_over_panel)
	_remettre_la_navigation_a_l_accueil()
	_open_pause()

## Ramène la navigation à l'accueil, en vidant la pile du hub.
##
## **Elle s'appelait `_restore_all_tabs()` et ne rendait aucun onglet.** Le nom
## datait d'une barre d'onglets disparue à la Phase 5 ; son corps entier est
## `hub.reset()` depuis. Renommée le 2026-08-19 parce que le nom a réellement
## trompé quelqu'un : `rouvrir_le_salon()` l'appelait trois lignes au-dessus d'un
## commentaire jurant qu'elle ne remettait pas la pile à zéro — et cette remise à
## zéro démontait le serveur de l'hôte, qui ne pouvait alors plus jamais être
## rejoint.
##
## **Ce n'est pas un geste anodin : `reset()` émet `screen_changed("accueil")`,
## et `_close_lobby_if_left()` écoute.** N'appeler cette fonction que si l'on veut
## vraiment repartir de la racine.
func _remettre_la_navigation_a_l_accueil() -> void:
	if hub != null:
		hub.reset()

func _on_map_chosen(_map_id: String) -> void:
	_refresh_map_card()

# ---------------------------------------------------------------------------
# CONTRÔLES
# ---------------------------------------------------------------------------

## Une action réassignable par entrée, ses deux touches à droite.
##
## L'écran déversait auparavant une grille de neuf cases dans la colonne de
## gauche — plus une copie des réglages d'affichage, qui vivent déjà dans leur
## propre écran. Deux jeux de boutons radio prétendaient chacun dire la
## résolution en cours : changer l'une laissait l'autre mentir.
const BINDABLE := [
	["Tirer", "shoot", "Le tir. Un flash qui révèle votre position à tout le monde."],
	["Torche", "torch", "L'allumage de la torche : elle montre, et elle trahit."],
	["Courir", "sprint", "Le sprint. Rapide, bruyant, et la torche décroche."],
]

## Les trois actions et leurs deux colonnes de joueurs, d'un seul bloc.
##
## Chaque action avait son entrée et son panneau : la configuration complète
## n'était jamais visible d'un coup, et un doublon entre deux actions — la même
## touche pour tirer et pour sprinter — ne se repérait qu'en faisant l'aller-retour
## de mémoire. Une grille de trois lignes le montre.
##
## Chaque bouton reste réservé à son joueur par `META_NAV_OWNER` : le curseur de
## P1 ne peut pas réassigner la manette de P2.
func _build_controls_panel() -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", GAP_S)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GAP_L)
	grid.add_theme_constant_override("v_separation", GAP_XS)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	block.add_child(grid)

	grid.add_child(_make_grid_header("", COLOR_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	grid.add_child(_make_grid_header("JOUEUR 1", COLOR_P1, HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(_make_grid_header("JOUEUR 2", COLOR_P2, HORIZONTAL_ALIGNMENT_CENTER))

	for rang in BINDABLE.size():
		var spec: Array = BINDABLE[rang]
		var nom := _make_grid_header(String(spec[0]).to_upper(), COLOR_GOLD,
			HORIZONTAL_ALIGNMENT_RIGHT)
		nom.add_theme_font_size_override("font_size", T_COURANT)
		nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(nom)
		for player in 2:
			var btn := _make_rebind_button("p%d_%s" % [player + 1, String(spec[1])], player)
			# La graine ne se pose que sur la PREMIÈRE ligne : elle dit où le
			# curseur d'un joueur atterrit en entrant dans le cadre, et trois
			# réponses valides pour une question en font une réponse au hasard.
			if rang == 0:
				btn.set_meta(META_NAV_SEED, player)
			var holder := CenterContainer.new()
			holder.add_child(btn)
			grid.add_child(holder)

	var hint := Label.new()
	hint.text = "Activez une touche, puis appuyez sur la nouvelle."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", T_MENTION)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	block.add_child(hint)

	return block

# ---------------------------------------------------------------------------
# AFFICHAGE
# ---------------------------------------------------------------------------

## Trois réglages, trois entrées, chacune montrant ses choix à droite. Les
## bascules restent des boutons plutôt qu'un `OptionButton`, dont le popup est
## impraticable à la manette.
## Les quatre réglages d'affichage, empilés dans un seul cadre.
##
## Le tout défile : la calibration porte un champ de mesure haut, et une fenêtre
## en 720 n'a pas la place des quatre rubriques. `follow_focus` fait suivre le
## curseur — sans lui, un réglage hors du champ serait atteignable sans être
## visible, ce qui est pire que de ne pas l'atteindre.
func _build_display_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true

	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", GAP_S)
	scroll.add_child(block)

	block.add_child(_make_reglage_titre("RÉSOLUTION", "Fenêtré ou plein écran."))
	block.add_child(_build_resolution_panel())
	block.add_child(_make_reglage_titre("VSYNC",
		"Désactivé par défaut : la synchronisation verticale ajoute une image de "
		+ "retard, et le jeu se joue sur la lumière d'une fraction de seconde."))
	block.add_child(_build_vsync_panel())
	block.add_child(_make_reglage_titre("IMAGES PAR SECONDE",
		"Déplafonné par défaut : EOS coûte d'autant plus de latence que la cadence "
		+ "est basse."))
	block.add_child(_build_fps_panel())
	block.add_child(_make_reglage_titre("CALIBRATION",
		"Cible perceptive : ce qui doit se voir apparaît à peine, le reste reste "
		+ "invisible."))
	block.add_child(_build_calibration_panel())
	return scroll

## Le nom d'un réglage et ce qu'il coûte, au-dessus de ses boutons.
##
## La phrase explicative vivait dans le détail de l'entrée, à droite ; le cadre
## de droite étant devenu le réglage lui-même, elle n'avait plus où se poser.
func _make_reglage_titre(titre: String, explication: String) -> Control:
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", GAP_XXS)
	var t := Label.new()
	t.text = titre
	t.add_theme_font_size_override("font_size", T_COURANT)
	t.add_theme_color_override("font_color", COLOR_GOLD)
	bloc.add_child(t)
	var x := Label.new()
	x.text = explication
	x.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	x.add_theme_font_size_override("font_size", T_MENTION)
	x.add_theme_color_override("font_color", COLOR_DIM)
	bloc.add_child(x)
	return bloc

func _build_resolution_panel() -> Control:
	var row := _make_rangee_de_choix()

	var group := ButtonGroup.new()
	var labels: Array[String] = ["FENÊTRÉ 1280", "FENÊTRÉ 1920", "PLEIN ÉCRAN"]
	for i in labels.size():
		var btn := _make_choice_button(labels[i], COLOR_GOLD, group)
		btn.custom_minimum_size = Vector2(BOUTON_CHOIX_L, 42)
		btn.add_theme_font_size_override("font_size", T_COURANT)
		btn.pressed.connect(_on_res_selected.bind(i))
		# Cocher le choix enregistré. `button_pressed` n'émet que `toggled` :
		# régler l'état ici ne redéclenche donc pas `_on_res_selected`.
		btn.button_pressed = i == GameSettings.resolution_index
		row.add_child(btn)

	return row

func _build_vsync_panel() -> Control:
	var row := _make_rangee_de_choix()
	var group := ButtonGroup.new()
	var btn_off := _make_choice_button("VSYNC DÉSACTIVÉ", COLOR_GOLD, group)
	var btn_on := _make_choice_button("VSYNC ACTIVÉ", COLOR_GOLD, group)
	for btn in [btn_off, btn_on]:
		btn.custom_minimum_size = Vector2(BOUTON_CHOIX_L, 42)
		btn.add_theme_font_size_override("font_size", T_COURANT)
	btn_off.button_pressed = not GameSettings.vsync_enabled
	btn_on.button_pressed = GameSettings.vsync_enabled
	btn_off.pressed.connect(func() -> void: GameSettings.set_vsync(false))
	btn_on.pressed.connect(func() -> void: GameSettings.set_vsync(true))
	row.add_child(btn_off)
	row.add_child(btn_on)
	return row

func _build_fps_panel() -> Control:
	var row := _make_rangee_de_choix()
	var group := ButtonGroup.new()
	for cap in GameSettings.FPS_CAPS:
		var label := "DÉPLAFONNÉ" if cap == 0 else str(cap)
		var btn := _make_choice_button(label, COLOR_GOLD, group)
		btn.custom_minimum_size = Vector2(BOUTON_CHOIX_L, 42)
		btn.add_theme_font_size_override("font_size", T_COURANT)
		btn.button_pressed = (cap == GameSettings.fps_cap)
		btn.pressed.connect(func() -> void: GameSettings.set_fps_cap(cap))
		row.add_child(btn)
	return row

## Les choix d'un réglage, côte à côte et repliés si la largeur manque.
##
## Empilés verticalement, les cinq paliers d'images par seconde à eux seuls
## dépassaient la hauteur du cadre. Un `HFlowContainer` ne fige aucune largeur :
## il tient en fenêtré comme en plein écran, quel que soit le nombre de choix.
func _make_rangee_de_choix() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", GAP_XS)
	row.add_theme_constant_override("v_separation", GAP_XS)
	return row

func _make_grid_header(text: String, tint: Color, align: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", T_MENTION)
	label.add_theme_color_override("font_color", tint)
	return label

func _make_rebind_button(action: String, player: int) -> Button:
	var btn := _make_button("", COLOR_P1 if player == 0 else COLOR_P2)
	btn.custom_minimum_size = Vector2(72, 64)
	btn.set_meta(META_NAV_OWNER, player)
	_apply_btn_info(btn, _get_action_btn_info(action))
	btn.pressed.connect(_on_rebind_btn_pressed.bind(btn, action))
	return btn

# ---------------------------------------------------------------------------
# BARRE D'ACTIONS
# ---------------------------------------------------------------------------

func _build_actions_bar() -> Control:
	btn_actions = HBoxContainer.new()
	btn_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_actions.add_theme_constant_override("separation", GAP_S)

	# « REPRENDRE » a quitté cette barre avec la séparation de la pause : le menu à
	# onglets ne s'affiche plus jamais par-dessus un match en cours, sauf pour la
	# parenthèse des options, qui a son propre retour.
	btn_back = _make_button("RETOUR", COLOR_P1)
	btn_back.custom_minimum_size = Vector2(208, 56)
	btn_back.pressed.connect(_close_pause_options)
	btn_back.hide()
	btn_actions.add_child(btn_back)

	btn_replay = _make_button("REJOUER", COLOR_P1, true)
	btn_replay.custom_minimum_size = Vector2(264, 56)
	btn_replay.add_theme_font_size_override("font_size", T_APPUI)
	btn_replay.pressed.connect(func() -> void:
		get_tree().paused = false
		replay_requested.emit()
	)
	btn_actions.add_child(btn_replay)

	btn_main_menu = _make_button("MENU PRINCIPAL", COLOR_DIM)
	btn_main_menu.custom_minimum_size = Vector2(240, 56)
	btn_main_menu.pressed.connect(func() -> void:
		get_tree().paused = false
		main_menu_requested.emit()
	)
	btn_actions.add_child(btn_main_menu)

	btn_quit = _make_button("QUITTER", COLOR_P2)
	btn_quit.custom_minimum_size = Vector2(184, 56)
	btn_quit.pressed.connect(func() -> void:
		get_tree().paused = false
		quit_requested.emit()
	)
	btn_actions.add_child(btn_quit)

	return btn_actions

func _resume_game() -> void:
	get_tree().paused = false
	_options_from_pause = false
	btn_back.hide()
	_remettre_la_navigation_a_l_accueil()
	# La reprise ne perd JAMAIS un battement : l'arbre est dé-pausé au-dessus, et
	# seul le visuel s'éteint encore. Voir `_extinction` — pour tout ce qui décide,
	# les deux panneaux sont déjà fermés.
	_eteindre(pause_panel, true)
	_eteindre(game_over_panel, true)

## Mode que le menu lancera au prochain « JOUER ».
##
## « CRÉER SALON » et « REJOINDRE » forment un groupe de boutons distinct de
## « 1V1 LOCAL / 1V1 EN LIGNE » : repasser en local ne les décoche pas. Le sous-
## mode en ligne ne compte donc que si « 1V1 EN LIGNE » est bien sélectionné —
## c'est cette lecture, et elle seule, qui fait foi.
func selected_network_mode() -> NetworkManager.GameMode:
	return _intended_mode

## Panneau d'arme du joueur que CETTE machine incarne.
##
## Dans le menu, le peer n'existe pas encore : `NetworkManager.current_mode`
## vaut toujours LOCAL, et s'y fier montrait au client le panneau « JOUEUR 1 ».
## Son choix atterrissait alors dans `p1_weapon_group`, que personne ne lit pour
## P2 — d'où un client condamné au pistolet. C'est le mode *choisi* qui fait foi.
func _update_weapon_panels_visibility() -> void:
	# En file, le rôle n'est pas encore décidé : la désignation de l'hôte n'a lieu
	# qu'une fois l'adversaire trouvé. Montrer les deux râteliers laisserait croire
	# qu'on choisit pour deux ; en montrer un seul et le reporter sur l'autre au
	# moment de partir (`mirror_weapon_choice`) dit la vérité — un joueur, une arme,
	# quel que soit le côté où il tombe.
	if _is_main_menu and hub != null and hub.current_id() in [SCREEN_FRIENDLY, SCREEN_RANKED]:
		_assign_weapon_nav_owner(false)
		p1_vbox.show()
		p2_vbox.hide()
		return

	var mode := selected_network_mode() if _is_main_menu else NetworkManager.current_mode
	var local_is_p2 := mode == NetworkManager.GameMode.ONLINE_CLIENT
	_assign_weapon_nav_owner(local_is_p2)

	if mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		p1_vbox.show()
		p2_vbox.show()
	elif local_is_p2:
		p1_vbox.hide()
		p2_vbox.show()
	else:
		p1_vbox.show()
		p2_vbox.hide()

## Reporte le choix d'arme du râtelier de J1 sur celui de J2.
##
## L'appariement automatique fait choisir son arme **avant** de savoir de quel
## côté on tombera : l'hôte lit le râtelier de J1, l'invité celui de J2, et la
## désignation n'a lieu qu'une fois l'adversaire trouvé. Sans ce report, un joueur
## sur deux partait au pistolet — en BO1, aucun rematch ne vient rattraper le
## choix.
func mirror_weapon_choice() -> void:
	var choisi: BaseButton = p1_weapon_group.get_pressed_button()
	if choisi == null:
		return
	var cible: Array = p2_weapon_group.get_buttons()
	var index := choisi.get_index()
	if index >= 0 and index < cible.size():
		cible[index].button_pressed = true

## Réserve la rangée d'armes au curseur qui peut réellement l'atteindre.
##
## En ligne, la machine ne pilote qu'un joueur et toujours avec les commandes de
## J1 (côté client, P2 lit le périphérique 0). La rangée « JOUEUR 2 » doit donc
## appartenir au curseur 0 chez le client, sans quoi elle serait affichée mais
## inatteignable à la manette.
func _assign_weapon_nav_owner(local_is_p2: bool) -> void:
	var p1_owner := 1 if local_is_p2 else 0
	var p2_owner := 0 if local_is_p2 else 1
	for btn in [p1_btn1, p1_btn2, p1_btn3, p1_btn4]:
		btn.set_meta(META_NAV_OWNER, p1_owner)
	for btn in [p2_btn1, p2_btn2, p2_btn3, p2_btn4]:
		btn.set_meta(META_NAV_OWNER, p2_owner)
	p1_btn1.set_meta(META_NAV_SEED, p1_owner)
	p2_btn1.set_meta(META_NAV_SEED, p2_owner)

# ===========================================================================
# REMAPPAGE DES TOUCHES
# ===========================================================================

func _get_joypad_btn_info(btn_index: int) -> Dictionary:
	match btn_index:
		JOY_BUTTON_A: return {"text": "Croix (X)", "icon": "cross.svg"}
		JOY_BUTTON_B: return {"text": "Rond (O)", "icon": "circle.svg"}
		JOY_BUTTON_X: return {"text": "Carré", "icon": "square.svg"}
		JOY_BUTTON_Y: return {"text": "Triangle", "icon": "triangle.svg"}
		JOY_BUTTON_BACK: return {"text": "Share", "icon": "share.svg"}
		JOY_BUTTON_GUIDE: return {"text": "PS", "icon": "ps.svg"}
		JOY_BUTTON_START: return {"text": "Options", "icon": "options.svg"}
		JOY_BUTTON_LEFT_STICK: return {"text": "L3", "icon": "l3.svg"}
		JOY_BUTTON_RIGHT_STICK: return {"text": "R3", "icon": "r3.svg"}
		JOY_BUTTON_LEFT_SHOULDER: return {"text": "L1", "icon": "l1.svg"}
		JOY_BUTTON_RIGHT_SHOULDER: return {"text": "R1", "icon": "r1.svg"}
		JOY_BUTTON_DPAD_UP: return {"text": "Flèche Haut", "icon": "dpad_up.svg"}
		JOY_BUTTON_DPAD_DOWN: return {"text": "Flèche Bas", "icon": "dpad_down.svg"}
		JOY_BUTTON_DPAD_LEFT: return {"text": "Flèche Gauche", "icon": "dpad_left.svg"}
		JOY_BUTTON_DPAD_RIGHT: return {"text": "Flèche Droite", "icon": "dpad_right.svg"}
		JOY_BUTTON_MISC1: return {"text": "Touchpad", "icon": ""}
		_: return {"text": "Bouton " + str(btn_index), "icon": ""}

func _apply_btn_info(btn: Button, info: Dictionary) -> void:
	if String(info.get("icon", "")) != "":
		var path_svg := "res://assets/ui/prompts/" + String(info["icon"])
		if ResourceLoader.exists(path_svg):
			btn.icon = load(path_svg)
			btn.text = ""
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
			return
	btn.icon = null
	btn.text = String(info.get("text", ""))

func _get_action_btn_info(action: String) -> Dictionary:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return _get_joypad_btn_info(ev.button_index)
		elif ev is InputEventJoypadMotion:
			if ev.axis == JOY_AXIS_TRIGGER_LEFT:
				return {"text": "Gâchette L2", "icon": "l2.svg"}
			elif ev.axis == JOY_AXIS_TRIGGER_RIGHT:
				return {"text": "Gâchette R2", "icon": "r2.svg"}
			else:
				return {"text": "Axe " + str(ev.axis), "icon": ""}
	return {"text": "Non assigné", "icon": ""}

func _on_rebind_btn_pressed(btn: Button, action: String) -> void:
	if _is_rebinding:
		return
	_is_rebinding = true
	_action_to_rebind = action
	_button_to_update = btn
	btn.text = "Appuyez..."
	btn.icon = null
	btn.add_theme_color_override("font_color", COLOR_GOLD)

# ===========================================================================
# ENTRÉES
# ===========================================================================

func _input(event: InputEvent) -> void:
	# En ligne, la seconde manette locale ne pilote rien.
	if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		if event.is_action("p2_menu_right") or event.is_action("p2_menu_left") \
				or event.is_action("p2_menu_up") or event.is_action("p2_menu_down") \
				or event.is_action("p2_menu_select") or event.is_action("p2_menu_prev_tab") \
				or event.is_action("p2_menu_next_tab"):
			return

	if _is_rebinding:
		_handle_rebind_input(event)
		return

	if event.is_action_pressed("sys_pause"):
		if _handle_pause_input():
			return

	var pause_open: bool = _panneau_ouvert(pause_panel)
	if not _panneau_ouvert(game_over_panel) and not pause_open:
		return

	# La pause n'a pas d'onglets : les gâchettes n'y font rien plutôt que de
	# feuilleter un menu invisible.
	if not pause_open:
		if event.is_action_pressed("p1_menu_prev_tab") or event.is_action_pressed("p2_menu_prev_tab"):
			# M6 coule depuis le geste : ici il n'y a pas de bouton pressé, mais il
			# y a bien un joueur qui agit et un curseur quelque part.
			hub.noter_geste(p1_focus)
			hub.back()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("p1_menu_next_tab") or event.is_action_pressed("p2_menu_next_tab"):
			hub.back()
			get_viewport().set_input_as_handled()
			return

	for player in 2:
		var prefix := "p1_menu_" if player == 0 else "p2_menu_"
		if event.is_action_pressed(prefix + "right"):
			_navigate(player, Vector2.RIGHT)
		elif event.is_action_pressed(prefix + "left"):
			_navigate(player, Vector2.LEFT)
		elif event.is_action_pressed(prefix + "up"):
			_navigate(player, Vector2.UP)
		elif event.is_action_pressed(prefix + "down"):
			_navigate(player, Vector2.DOWN)
		elif event.is_action_pressed(prefix + "select"):
			_activate(player)

func _handle_rebind_input(event: InputEvent) -> void:
	var new_event: InputEvent = null
	var display_info := {}

	if event is InputEventJoypadButton and event.is_pressed():
		var joy_btn := InputEventJoypadButton.new()
		joy_btn.button_index = (event as InputEventJoypadButton).button_index
		new_event = joy_btn
		display_info = _get_joypad_btn_info(joy_btn.button_index)
	elif event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis_value > 0.5:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			var joy_axis := InputEventJoypadMotion.new()
			joy_axis.axis = motion.axis
			joy_axis.axis_value = 1.0
			new_event = joy_axis
			display_info = {"text": "Gâchette L2", "icon": "l2.svg"} \
				if motion.axis == JOY_AXIS_TRIGGER_LEFT \
				else {"text": "Gâchette R2", "icon": "r2.svg"}

	if new_event == null:
		return

	var old_events := InputMap.action_get_events(_action_to_rebind)
	for ev in old_events:
		var is_trigger := ev is InputEventJoypadMotion \
			and ((ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT
				or (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT)
		if ev is InputEventJoypadButton or is_trigger:
			InputMap.action_erase_event(_action_to_rebind, ev)

	new_event.device = old_events[0].device if old_events.size() > 0 else 0
	InputMap.action_add_event(_action_to_rebind, new_event)
	# Sans ça, le joueur retrouvait les touches par défaut au lancement suivant.
	GameSettings.set_binding(_action_to_rebind, new_event)

	_apply_btn_info(_button_to_update, display_info)
	_button_to_update.remove_theme_color_override("font_color")
	_is_rebinding = false
	get_viewport().set_input_as_handled()

## Le gel de l'arbre n'a de sens qu'en local : en ligne il figerait la
## simulation des deux joueurs (hôte) ou désynchroniserait le client d'un monde
## qui continue. En ligne le menu se superpose au jeu, qui poursuit sa course.
## Qui voit quel panneau de HUD, et de quel côté.
##
## **Décision d'Adrien (2026-08-19) : en ligne, on ne voit plus le HUD de
## l'adversaire.** Il montrait ses points de vie — donc s'il est à 20 ou à 100 —
## et surtout **son cercle de recharge**, c'est-à-dire l'instant exact où son arme
## redevient prête. Dans un jeu dont la règle est « la seule information est la
## lumière », c'était un renseignement que personne n'avait payé en s'éclairant.
## Le cercle est le plus cher des deux : sans lui, on doit **compter** après avoir
## entendu un tir ; avec lui, on **lit**.
##
## En écran partagé, les deux restent : les joueurs voient l'écran l'un de l'autre
## de toute façon, et se cacher mutuellement une barre serait arbitraire.
##
## **Le panneau du joueur local va toujours à GAUCHE**, hôte comme client. Sa
## place ne dépend donc plus de son numéro. Ce qui reste attaché au numéro :
## **sa couleur** — le client demeure rouge, la teinte identifie le joueur et non
## la place — et **son point d'apparition**, qui reste celui de J2.
func disposer_hud(entrainement: bool = false) -> void:
	if hud_panneau_p1 == null or hud_panneau_p2 == null or hud_rangee == null:
		return
	var mode := NetworkManager.current_mode
	var en_ligne := mode == NetworkManager.GameMode.ONLINE_HOST \
		or mode == NetworkManager.GameMode.ONLINE_CLIENT

	# L'entraînement est du LOCAL_SPLITSCREEN pour le transport — aucun pair,
	# aucune autorité distante — mais **il n'a qu'un joueur**, et J2 est retiré de
	# la scène. Son panneau annonçait donc la santé et la torche de quelqu'un qui
	# n'est pas là, avec une barre de vie pleine et immobile. Le mode réseau ne
	# peut pas le savoir : c'est l'appelant qui sait qu'on s'entraîne.
	if entrainement:
		hud_panneau_p1.visible = true
		hud_panneau_p2.visible = false
		hud_panneau_p1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if hud_rangee.get_child(0) != hud_panneau_p1:
			hud_rangee.move_child(hud_panneau_p1, 0)
		return

	# **Les deux panneaux ne sont pas « J1 » et « J2 » : ce sont « moi » et
	# « l'autre ».** Le premier est bleu et à gauche, le second rouge et à droite —
	# et `GameState` alimente le premier avec le joueur LOCAL, quel que soit son
	# numéro. Décision d'Adrien du 2026-08-19 : « le client devient bleu, c'est
	# l'adversaire qui doit apparaître rouge pour lui ». La couleur suit le rôle ;
	# le numéro garde ce qui lui appartient vraiment, le point d'apparition.
	#
	# Conséquence heureuse : en ligne il n'y a plus rien à déplacer. On cache le
	# second panneau, et le premier est déjà au bon endroit avec la bonne teinte.
	hud_panneau_p1.visible = true
	hud_panneau_p2.visible = not en_ligne
	if hud_rangee.get_child(0) != hud_panneau_p1:
		hud_rangee.move_child(hud_panneau_p1, 0)
	hud_panneau_p1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hud_panneau_p2.size_flags_horizontal = Control.SIZE_SHRINK_END

func _pause_freezes_world() -> bool:
	return NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN

## Le menu pause est-il ouvert ? En ligne il ne gèle rien : le joueur local doit
## quand même cesser d'agir pendant qu'il navigue — y compris dans la parenthèse
## des options, qui reste une pause du point de vue du joueur.
func is_pause_menu_open() -> bool:
	return _panneau_ouvert(pause_panel) or _options_from_pause

## Retourne true si l'événement de pause a été consommé.
##
## Trois cas, dans cet ordre : les options ouvertes depuis la pause s'y referment,
## une pause ouverte se lève, et sinon on ouvre la pause — à condition d'être bien
## en match, c'est-à-dire ni dans le menu principal ni sur l'écran de fin.
## Le panneau de choix, centré et par-dessus tout le reste.
##
## Volontairement pauvre : les armes en haut, « PRÊT » juste dessous, rien
## d'autre. Dix secondes ne laissent pas le temps de lire, et un panneau qui
## expliquerait longuement se lirait après le départ du match.
func _build_pick_panel() -> void:
	pick_panel = PanelContainer.new()
	pick_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pick_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pick_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var fond := StyleBoxFlat.new()
	fond.bg_color = COLOR_SURFACE
	fond.set_border_width_all(2)
	fond.border_color = COLOR_P1
	fond.set_corner_radius_all(12)
	fond.set_content_margin_all(GAP_M)
	pick_panel.add_theme_stylebox_override("panel", fond)
	pick_panel.hide()
	add_child(pick_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP_S)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	pick_panel.add_child(col)

	var titre := _make_section_label("VOTRE ARME", COLOR_P1)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titre)

	_pick_row = HBoxContainer.new()
	_pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pick_row.add_theme_constant_override("separation", GAP_XS)
	col.add_child(_pick_row)

	_pick_reason = Label.new()
	_pick_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_reason.add_theme_font_size_override("font_size", T_MENTION)
	_pick_reason.add_theme_color_override("font_color", COLOR_GOLD)
	_pick_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pick_reason.custom_minimum_size = Vector2(420, 0)
	col.add_child(_pick_reason)

	var centre := CenterContainer.new()
	_pick_ready = _make_button("PRÊT", COLOR_P1, true)
	_pick_ready.custom_minimum_size = Vector2(240, 48)
	_pick_ready.pressed.connect(_on_pick_ready)
	centre.add_child(_pick_ready)
	col.add_child(centre)

## Ouvre la fenêtre sur l'arsenal commun. Une seule arme s'affiche quand même :
## le joueur doit voir ce avec quoi il part, et un panneau qui n'apparaîtrait pas
## laisserait croire à un oubli.
func show_pick_window(arsenal: Array, reason: String) -> void:
	if pick_panel == null:
		return
	for b in _pick_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_pick_buttons.clear()

	var groupe := ButtonGroup.new()
	for idx in arsenal:
		var i := int(idx)
		var btn := _make_choice_button(_weapon_label(i), COLOR_P1, groupe)
		btn.custom_minimum_size = Vector2(150, 84)
		btn.pressed.connect(func() -> void: _on_pick_weapon(i))
		_pick_row.add_child(btn)
		_pick_buttons.append(btn)
	if not _pick_buttons.is_empty():
		_pick_buttons[0].button_pressed = true

	_pick_reason.text = reason
	_pick_reason.visible = reason != ""
	_pick_ready.text = "PRÊT"
	_pick_ready.disabled = false
	pick_panel.show()
	# Le curseur se pose sur l'arme, pas sur « PRÊT » : c'est le choix qui est
	# demandé, et démarrer sur le bouton de sortie inviterait à ne pas choisir.
	# La graine est portée par le bouton lui-même — `_seed_focus` la cherche —
	# plutôt que posée de force, pour que les deux curseurs y arrivent chacun.
	if not _pick_buttons.is_empty():
		for j in [0, 1]:
			_pick_buttons[0].set_meta(META_NAV_SEED, j)
	_seed_focus(0)
	_seed_focus(1)

func hide_pick_window() -> void:
	if pick_panel != null:
		pick_panel.hide()

func _weapon_label(idx: int) -> String:
	match idx:
		RankLoadout.ARBALETE: return "🏹 Arbalète"
		RankLoadout.POMPE: return "☄️ Pompe"
		RankLoadout.FUSIL: return "💥 Fusil"
		_: return "🔫 Pistolet"

func _on_pick_weapon(idx: int) -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs != null and gs.has_method("pick_countdown_weapon"):
		gs.pick_countdown_weapon(idx)

## « PRÊT » ne referme pas la fenêtre : le match ne part que si l'autre l'est
## aussi, et refermer laisserait croire que c'est parti.
func _on_pick_ready() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs != null and gs.has_method("declare_countdown_ready"):
		gs.declare_countdown_ready()
	_pick_ready.text = "✓ PRÊT — en attente"
	_pick_ready.disabled = true

func _handle_pause_input() -> bool:
	# Renoncer à choisir, c'est renoncer au match : la fenêtre se ferme, et
	# l'appariement comme la recherche sont annulés. Traité AVANT la pause, dont
	# elle prend le pas.
	if pick_panel != null and pick_panel.visible:
		hide_pick_window()
		pick_window_cancelled.emit()
		get_viewport().set_input_as_handled()
		return true

	if _options_from_pause:
		_close_pause_options()
		get_viewport().set_input_as_handled()
		return true

	if _panneau_ouvert(pause_panel):
		_resume_game()
		get_viewport().set_input_as_handled()
		return true

	if not _is_main_menu and not _panneau_ouvert(game_over_panel):
		_open_pause()
		get_viewport().set_input_as_handled()
		return true

	# Dans le menu, Échap remonte d'un cran. L'étiquette « ÉCHAP · RETOUR » a
	# longtemps annoncé un geste que rien n'implémentait : elle est devenue une
	# entrée cliquable, et la touche la double enfin pour de vrai.
	if _is_main_menu and hub != null and hub.depth() > 0:
		hub.noter_geste(p1_focus)
		hub.back()
		get_viewport().set_input_as_handled()
		return true

	return false

# ===========================================================================
# API PUBLIQUE — consommée par game_state.gd
# ===========================================================================

## V3.4 — les deux seuils de la dernière minute, et l'état courant du chrono.
##
## `-1` = pas encore calculé, pour qu'un premier passage pose la couleur même
## quand le match commence déjà sous un seuil (une manche reprise, un chrono
## resynchronisé).
const CHRONO_OR_S := 60.0
const CHRONO_URGENT_S := 10.0
var _chrono_etat: int = -1

func update_hud(p1, p2, time_left: float, horloge: bool = true) -> void:
	# Lu une fois pour les deux moitiés d'écran : `current_effect` dérive
	# lui-même le contexte classé, on ne le lui souffle pas.
	var voile := GameSettings.current_effect("eblouissement")
	if p1:
		if p1.hp < p1_target_hp:
			p1_shake_time = 0.2
		p1_target_hp = p1.hp
		p1_hp.value = p1.hp

		var p1_max_cd = p1.current_weapon.cooldown if p1.current_weapon else 1.0
		p1_cd.set_progress(1.0 - (p1.shoot_cooldown / p1_max_cd))
		if p1.shoot_cooldown <= 0:
			p1_cd_label.text = "PRÊT"
		else:
			p1_cd_label.text = "%.1fs" % p1.shoot_cooldown

		if p1_cd.secousse < float(p1.get("tir_a_sec")):
			p1_cd.secousse = float(p1.get("tir_a_sec"))
		_set_torch_style(p1_torch, p1.flashlight_on, COLOR_P1)
		p1_dazzle.color = Color(Charte.HALOGENE, p1.dazzle_amount * 0.8 * voile)

	if p2:
		if p2.hp < p2_target_hp:
			p2_shake_time = 0.2
		p2_target_hp = p2.hp
		p2_hp.value = p2.hp

		var p2_max_cd = p2.current_weapon.cooldown if p2.current_weapon else 1.0
		p2_cd.set_progress(1.0 - (p2.shoot_cooldown / p2_max_cd))
		if p2.shoot_cooldown <= 0:
			p2_cd_label.text = "PRÊT"
		else:
			p2_cd_label.text = "%.1fs" % p2.shoot_cooldown

		if p2_cd.secousse < float(p2.get("tir_a_sec")):
			p2_cd.secousse = float(p2.get("tir_a_sec"))
		_set_torch_style(p2_torch, p2.flashlight_on, COLOR_P2)
		p2_dazzle.color = Color(Charte.HALOGENE, p2.dazzle_amount * 0.8 * voile)

	# `horloge` faux = ce label ne porte pas un chrono, et personne d'autre ne
	# doit l'écrire. **L'entraînement posait « ENTRAÎNEMENT » et le voyait effacé
	# à la frame suivante** : la ligne existait, ne servait à rien, et rien ne le
	# signalait — un HUD qui écrase inconditionnellement gagne toujours contre
	# celui qui écrit une fois.
	if not horloge:
		return
	time_label.text = MatchRecord.format_clock(time_left)
	_teindre_chrono(time_left)
	# Sous dix secondes, le chrono bat à la seconde. Le battement naît du temps
	# lui-même et non d'un tween : un tween redémarré à chaque frame ne bat pas,
	# il tremble, et un chrono resynchronisé par le réseau saute d'une fraction
	# de seconde sans casser la pulsation.
	if time_left <= CHRONO_URGENT_S and time_left > 0.0:
		var depuis_tic := 1.0 - fmod(time_left, 1.0)
		var coup := 1.0 + 0.16 * exp(-7.0 * depuis_tic)
		time_label.pivot_offset = time_label.size / 2.0
		time_label.scale = Vector2(coup, coup)
	elif time_label.scale != Vector2.ONE:
		time_label.scale = Vector2.ONE

## La couleur du chrono suit le temps qui reste, et ne s'écrit qu'aux passages
## de seuil : poser un override de thème à chaque frame coûte pour rien.
func _teindre_chrono(time_left: float) -> void:
	var etat := 0
	if time_left <= CHRONO_URGENT_S:
		etat = 2
	elif time_left <= CHRONO_OR_S:
		etat = 1
	if etat == _chrono_etat:
		return
	_chrono_etat = etat
	match etat:
		2: time_label.add_theme_color_override("font_color", COLOR_P2)
		1: time_label.add_theme_color_override("font_color", COLOR_GOLD)
		_: time_label.remove_theme_color_override("font_color")

## Remet le chrono à neuf entre deux manches — sans quoi une manche qui commence
## hériterait de l'or ou du rouge de la précédente jusqu'au premier passage de
## seuil, c'est-à-dire pendant les quatre premières minutes.
func reinitialiser_chrono() -> void:
	_chrono_etat = -1
	if time_label != null:
		time_label.scale = Vector2.ONE
		time_label.remove_theme_color_override("font_color")

## Rouvre le SALON là où il est, sans l'habillage de fin de match.
##
## Née le 2026-08-19 d'un défaut du scénario 4.1 : l'adversaire meurt, quitte
## pendant la killcam, revient. Le hub restait bien sur son écran de salon, avec
## son entrée « PRÊT » — **dans un panneau que plus rien ne rallumait**. Le bon
## écran, et pas de menu.
##
## ## Pourquoi ni l'une ni l'autre des deux fonctions voisines ne convenait
##
## **`show_waiting_for_opponent()` n'ouvre aucun menu, et ne doit pas en ouvrir.**
## Son `waiting_label` vit dans le HUD de match, pas dans le panneau : c'est
## l'attente **dans l'arène**, et le dépôt le dit ailleurs en toutes lettres —
## « l'hôte est déjà dans l'arène : c'est l'écran d'attente qui porte le code,
## pas le menu qu'il vient de quitter ». Lui faire rallumer le panneau
## contredirait cette décision et casserait ses deux autres appelants, dont un
## qui appelle `hide_game_over()` juste après, exprès.
##
## **`show_main_menu()` fait trop.** Elle remet le hub à l'accueil : un joueur
## qui attendait dans son salon serait ramené à la racine et devrait redescendre
## deux crans pour retrouver le « PRÊT » qu'il regardait.
##
## Ce qu'on veut est entre les deux, et n'existait pas : **rallumer le panneau
## sur l'écran courant**, sans titre de victoire, sans score, sans réinitialiser
## la navigation.
func rouvrir_le_salon() -> void:
	# On redevient « dans le menu » : c'est ce qui rend au lanceur son libellé de
	# base — « PRÊT » et non « REJOUER » — car il n'y a plus de match à rejouer.
	_is_main_menu = true
	if is_instance_valid(match_hud):
		match_hud.hide()
	_options_from_pause = false
	btn_back.hide()
	btn_actions.hide()
	if pause_panel != null:
		_fermer_sec(pause_panel)

	# **Pas de `hub.reset()`, et surtout pas par la porte de derrière** — c'est
	# toute la différence avec `show_main_menu()`, et je l'avais écrit ici avant
	# d'appeler trois lignes plus haut la fonction qui le fait.
	#
	# J'appelais ici `_restore_all_tabs()`, dont le nom promettait des onglets et
	# **dont le corps entier était `hub.reset()`**. Elle s'appelle désormais
	# `_remettre_la_navigation_a_l_accueil()`, ce qu'elle a toujours fait.
	# L'appeler remettait la pile à l'accueil, `screen_changed("accueil")`
	# partait, et `_close_lobby_if_left()` démontait le serveur — un hôte dont
	# l'adversaire venait de quitter ne pouvait plus jamais être rejoint, l'écran
	# continuant d'afficher un code de salon qui ne menait nulle part.
	#
	# Rien n'est perdu à ne pas l'appeler : ce que cette fonction servait à
	# défaire — la parenthèse « options depuis la pause », qui masque trois
	# rubriques — est déjà défait deux lignes plus haut par `_options_from_pause`
	# et `btn_back.hide()`.
	_allumer(game_over_panel)
	_poser_titre("CANDELA 2D")
	game_over_title.add_theme_color_override("font_color", COLOR_GOLD)
	# Cette ligne porte la description de l'entrée survolée : un score de match
	# terminé y resterait affiché sous un salon qui attend le suivant.
	game_over_score.text = ""
	effacer_bilan()

	# Le bloc salon se remet en accord avec l'état réel du lien — c'est lui qui
	# grise ou dégrise « PRÊT » selon qu'un second joueur est là.
	_refresh_lobby_block()
	_refresh_player_list()
	_sync_launch_entries()
	_seed_focus(0)


func show_main_menu() -> void:
	_is_main_menu = true
	if is_instance_valid(match_hud):
		match_hud.hide()
	_options_from_pause = false
	btn_back.hide()
	if pause_panel != null:
		_fermer_sec(pause_panel)
	# Plus aucun bouton en bas du menu : « Jouer », « Prêt » et « Chercher un
	# match » lancent déjà le bon type de match depuis leur propre écran, et
	# « Quitter » est une entrée de l'accueil. Une barre qui doublait tout ça
	# obligeait à deviner lequel des deux gestes comptait.
	btn_actions.hide()

	weapon_hbox.show()
	map_card.show()
	# Le retour au menu ne rejoue pas les bascules de mode : sans ce rappel, le
	# panneau resterait celui de la partie précédente.
	_update_weapon_panels_visibility()
	_remettre_la_navigation_a_l_accueil()

	hub.reset()
	_allumer(game_over_panel)
	_poser_titre("CANDELA 2D")
	game_over_title.add_theme_color_override("font_color", COLOR_GOLD)
	# Vide, et non « PRÊT À JOUER ? » : cette ligne porte la description de l'entrée
	# survolée, et un texte de remplissage la remplacerait au premier retour au menu.
	game_over_score.text = ""

	# Rétablit d'un coup libellé du bouton, champ de saisie et ligne de statut :
	# le retour au menu ne rejoue pas les bascules de mode.
	_refresh_lobby_block()
	if selected_network_mode() == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		btn_replay.text = "JOUER"
	btn_replay.remove_theme_color_override("font_color")

	_refresh_map_card()

func show_game_over(winner_id: int) -> void:
	_is_main_menu = false
	if is_instance_valid(match_hud):
		match_hud.hide()
	_options_from_pause = false
	btn_back.hide()
	if pause_panel != null:
		_fermer_sec(pause_panel)
	# **Plus de barre du bas, même ici.** REJOUER a désormais son entrée dans la
	# liste, à la place exacte de PRÊT — même geste, même endroit. MENU PRINCIPAL
	# et QUITTER disparaissent : le retour de la liste ferme le salon, et quitter
	# le jeu est une entrée de l'accueil. Trois boutons qui doublaient la liste
	# obligeaient à deviner lequel comptait.
	btn_actions.hide()
	weapon_hbox.show()
	map_card.show()

	_update_weapon_panels_visibility()
	_remettre_la_navigation_a_l_accueil()
	# La carte de la manche suivante est celle de l'hôte : laisser le client en
	# choisir une lui ferait croire à un choix qui sera écrasé au lancement.
	# Après un match, on repart du salon correspondant au mode joué : c'est là que
	# « rejouer » a un sens.
	hub.reset()
	hub.push(_screen_for_current_mode())
	_allumer(game_over_panel)
	game_over_score.text = ""
	btn_replay.text = "REJOUER"
	# Après le `push` : la graine est lue au moment où l'écran s'ouvre, et la
	# poser ensuite n'aurait déplacé aucun curseur.
	_respirer_relance(true)
	_seed_focus(0)
	_seed_focus(1)
	# V3.6 — le score ne se contente pas d'être juste, il dit qu'il vient de
	# changer. Il monte de dix pixels en prenant la couleur de celui qui a gagné,
	# puis retombe à sa teinte de repos. `game_state` écrit son texte juste après
	# cet appel : l'animation porte donc bien la ligne définitive.
	_annoncer_score(winner_id)

	# Fin de MATCH (format BO1). En ligne chaque machine annonce l'issue du point
	# de vue de son joueur ; en écran partagé les deux joueurs partagent l'écran,
	# il n'y a pas de « toi » à désigner.
	var local_idx := -1
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST: local_idx = 0
		NetworkManager.GameMode.ONLINE_CLIENT: local_idx = 1

	if winner_id == -1:
		# V3.8 — l'égalité pèse. Gris et non blanc : le blanc est la couleur de ce
		# qui s'affirme, et une égalité n'affirme rien. Le silence sec qui
		# l'accompagne fait le reste — le mot arrive dans un vide, au lieu de se
		# poser sur une musique qui continue comme si de rien n'était.
		_poser_titre("ÉGALITÉ")
		game_over_title.add_theme_color_override("font_color", COLOR_DIM)
		var audio := get_node_or_null(^"/root/AudioManager")
		if audio != null and audio.has_method("silence_sec"):
			audio.silence_sec(1.0)
	elif local_idx == -1:
		_poser_titre("JOUEUR 1 GAGNE" if winner_id == 0 else "JOUEUR 2 GAGNE")
		game_over_title.add_theme_color_override("font_color",
			COLOR_P1 if winner_id == 0 else COLOR_P2)
	elif winner_id == local_idx:
		_poser_titre("VICTOIRE")
		game_over_title.add_theme_color_override("font_color", Charte.ETAT_OK)
	else:
		_poser_titre("DÉFAITE")
		game_over_title.add_theme_color_override("font_color", Charte.ETAT_FAUTE)

	# M11 — le même shader porte la température de l'issue : la victoire flambe
	# une fois, la défaite voit son onde tomber de moitié. L'écran de fin est
	# signé sans qu'un seul contrôle bouge. Une égalité ou un match observé de
	# l'extérieur n'a pas de vainqueur local : on ne flambe pour personne.
	if menu_title != null:
		menu_title.verdict(local_idx >= 0 and winner_id == local_idx)

	_refresh_map_card()

## V3.1 — l'entrée qui relance respire au tempo du jeu, et attire les curseurs.
##
## L'écran de fin est l'endroit où « encore une » se décide, et c'est le seul de
## tout le jeu où une entrée mérite d'attirer l'œil : après un match, on ne
## cherche pas dans une liste, on redemande. Elle enfle de 3 % à 170 BPM — le
## tempo des stems et du pouls haptique, un seul cœur pour l'image, la main et
## la musique.
##
## **Trois pour cent, et pas davantage.** L'entrée vit dans une colonne dont les
## voisines ne bougent pas : au-delà, elle cesse d'être une entrée qui respire
## pour devenir une entrée qui saute, et la liste entière paraît instable.
##
## La graine attire les DEUX curseurs, pas un joueur : après un match en écran
## partagé, les deux joueurs redemandent, et faire chercher le second serait lui
## faire payer le fait de ne pas être le premier.
## Les boutons qu'une animation de relance a le droit de toucher.
##
## Il n'y en a qu'un — celui du cadre de droite — mais la fonction rend un
## tableau plutôt que le bouton seul : les trois animations qui l'appellent
## (respiration V3.1, éclat de déclaration V3.2, remise à plat) itèrent déjà, et
## le jour où l'écran de fin en portera un second, rien à réécrire chez elles.
func _lanceurs_vivants() -> Array[Button]:
	if panel_launch != null and is_instance_valid(panel_launch):
		return [panel_launch]
	return []


func _respirer_relance(actif: bool) -> void:
	if _souffle_relance != null and _souffle_relance.is_valid():
		_souffle_relance.kill()
	_souffle_relance = null
	for btn in _lanceurs_vivants():
		btn.scale = Vector2.ONE
		btn.self_modulate = Color.WHITE
		if actif:
			btn.pivot_offset = btn.size / 2.0
			btn.set_meta(META_NAV_SEED, NAV_SEED_LES_DEUX)
		else:
			btn.remove_meta(META_NAV_SEED)
	if not actif:
		return
	var periode: float = 60.0 / 170.0
	var audio := get_node_or_null(^"/root/AudioManager")
	if audio != null:
		periode = float(audio.get("PERIODE_BEAT"))
	_souffle_relance = create_tween().set_loops()
	_souffle_relance.tween_method(_appliquer_souffle, 0.0, 1.0, periode)

## Une enflure lisse par battement : 1,00 → 1,03 → 1,00.
##
## Un cosinus plutôt qu'un aller-retour de tween : la courbe se referme sur
## elle-même, donc la boucle ne marque aucune couture au passage d'un battement
## au suivant. Deux tweens enchaînés auraient laissé un arrêt d'une frame.
func _appliquer_souffle(t: float) -> void:
	var enflure := 1.0 + 0.015 - 0.015 * cos(t * TAU)
	for btn in _lanceurs_vivants():
		if btn.is_visible_in_tree():
			btn.pivot_offset = btn.size / 2.0
			btn.scale = Vector2(enflure, enflure)

## V3.2 — l'adversaire vient de se déclarer prêt : l'entrée de relance s'allume
## une fois, et un ping la double.
##
## **Sur `self_modulate`, pas sur `scale` ni `modulate`.** La respiration V3.1
## occupe déjà `scale` sur ces mêmes entrées, et `modulate` porte le grisage
## quand il manque un joueur : écrire sur l'un ou l'autre ferait clignoter un
## bouton grisé, ou couperait la respiration à chaque fois que l'autre se
## déclare. Trois intentions, trois propriétés.
##
## Un éclat unique et court, pas une boucle : l'information est « il vient de se
## déclarer », pas « il est prêt ». La seconde est déjà écrite en toutes lettres
## au-dessus du chrono, et deux façons de dire la même chose se contredisent le
## jour où l'une se désynchronise.
func signaler_adversaire_pret() -> void:
	var audio := get_node_or_null(^"/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		# La clé existe, le fichier pas encore : `play_sfx` rend null en silence.
		# Le geste est câblé, il s'entendra le jour où le son arrive.
		audio.play_sfx("ui_ready_ping")
	for btn in _lanceurs_vivants():
		if not btn.is_visible_in_tree():
			continue
		var tw := create_tween()
		# Surexposition passagère, pas une teinte : `self_modulate` multiplie ce qui
		# est déjà peint. Comme `Color.WHITE` employé plus bas pour « aucune
		# teinte », ces valeurs échappent à la règle « pas de valeur pure » — elles
		# sont l'unité d'un produit, pas une couleur que le joueur lit.
		btn.self_modulate = Color(1.9, 1.9, 1.9)
		tw.tween_property(btn, "self_modulate", Color.WHITE, 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## V3.6 — le score de session se remplit au lieu d'apparaître.
##
## Une ligne de texte qui change sans bouger ne se lit pas : l'œil est encore sur
## le verdict. Dix pixels et une teinte suffisent à la faire remarquer — et la
## teinte dit **qui** vient de marquer, ce que « 3 - 2 » ne dit pas tout seul.
##
## Sur `position` et `modulate` du seul libellé de score : aucune des trois
## propriétés déjà prises sur les entrées de relance n'est touchée.
func _annoncer_score(winner_id: int) -> void:
	# ⚠️ **DA4.7 — l'annonce porte désormais sur le BILAN, et il fallait la
	# déplacer, pas la laisser.** Le score de session a quitté `game_over_score`
	# pour le bloc composé ; l'animation serait restée branchée sur un `Label`
	# vide et invisible. Elle aurait continué de tourner, sans erreur, sans rien
	# animer — V3.6 se serait éteinte en silence, et c'est précisément la forme
	# de panne que ce dépôt paie le plus souvent.
	if bilan == null:
		return
	var teinte := COLOR_DIM
	if winner_id == 0:
		teinte = COLOR_P1
	elif winner_id == 1:
		teinte = COLOR_P2
	# Tuer la précédente AVANT de poser la nouvelle valeur : sans ça, l'ancienne
	# continue de tirer `modulate` vers le blanc et écrase la teinte qu'on vient
	# d'écrire. Défaut trouvé par la suite, pas à la lecture.
	_arreter_annonce_score()
	var repos := bilan.position
	bilan.position = repos + Vector2(0, 10)
	bilan.modulate = teinte
	_annonce_score = create_tween().set_parallel()
	_annonce_score.tween_property(bilan, "position", repos, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_annonce_score.tween_property(bilan, "modulate", Color.WHITE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Coupe l'annonce en cours et rend au libellé sa teinte de repos.
func _arreter_annonce_score() -> void:
	if _annonce_score != null and _annonce_score.is_valid():
		_annonce_score.kill()
	_annonce_score = null
	if bilan != null:
		bilan.modulate = Color.WHITE

func hide_game_over() -> void:
	_is_main_menu = false
	_respirer_relance(false)
	_arreter_annonce_score()
	_eteindre(game_over_panel)
	# Retour au jeu : le HUD de match reprend sa place.
	if is_instance_valid(match_hud):
		match_hud.show()

## V6.1 — combien la bande souffre, d'après le ralenti en cours.
##
## Zéro à vitesse normale : la killcam d'après-impact garde exactement l'image
## qu'elle avait avant l'ajout de cet effet. Un au plus fort du ralenti — c'est le
## moment où le joueur regarde la balle arriver, et où l'image a le droit de dire
## que quelque chose ne va pas.
##
## Pure et nommée pour être vérifiable : un effet piloté par `Engine.time_scale`
## se règle autrement à l'œil, une frame à la fois, sur une machine donnée.
func tension_killcam(time_scale: float) -> float:
	return clampf(1.0 - time_scale, 0.0, 1.0)

## Remet l'orchestration de la killcam à neuf. Sans ça, une seconde killcam
## hériterait de l'image de rejeu de la précédente et **ne déclencherait jamais**
## son négatif — le franchissement ayant déjà eu lieu, du point de vue du
## compteur.
func reinitialiser_killcam() -> void:
	_killcam_tension = 0.0
	_killcam_negatif = 0
	_killcam_derniere_image = -1

func show_killcam() -> void:
	reinitialiser_killcam()
	killcam_overlay.show()
	killcam_container.show()
	killcam_timecode.show()
	var bb := get_node_or_null("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB")
	if bb:
		bb.show()

func hide_killcam() -> void:
	killcam_overlay.hide()
	killcam_container.hide()
	killcam_timecode.hide()
	var bb := get_node_or_null("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB")
	if bb:
		bb.hide()

func set_split_screen_visible(is_visible: bool) -> void:
	center_line.visible = is_visible

## [UI] Affiche une boîte de dialogue modale au centre de l'écran.
##
## DA4.17 — **le registre décide de la teinte du titre et du filet.**
##
## Les textes de ce jeu étaient déjà humains : « Impossible de lire l'arène de
## l'hôte… la cause la plus courante est un écart de version entre les deux
## jeux » explique et propose un remède. Ce qui manquait n'était pas la langue,
## c'était que **tout se ressemblait** : « Déconnexion », « Appariement » et
## « Erreur » sortaient dans le même or, le même cadre, le même bouton. Le
## joueur ne pouvait pas savoir avant de lire s'il venait de perdre sa partie ou
## de recevoir une information.
##
## La triade d'instrument le dit en une teinte, avant la première syllabe.
func show_dialog_message(title: String, message: String,
		registre: Registre = Registre.INFORMATION) -> void:
	dialog_title.text = title.to_upper()
	var teinte := COLOR_ACCENT
	match registre:
		Registre.ATTENTION: teinte = Charte.ETAT_ATTENTION
		Registre.FAUTE: teinte = Charte.ETAT_FAUTE
	dialog_title.add_theme_color_override("font_color", teinte)
	if _dialog_style != null:
		_dialog_style.border_color = teinte
	dialog_message.text = message
	dialog_panel.show()
	_previous_focus = p1_focus
	_set_focus(0, dialog_btn, true)
	_set_focus(1, dialog_btn, true)

## [UI] Ferme la boîte de dialogue et restaure le focus.
func _on_dialog_closed() -> void:
	dialog_panel.hide()
	if _is_focus_usable(_previous_focus):
		_set_focus(0, _previous_focus, true)
		_set_focus(1, _previous_focus, true)
	else:
		_seed_focus(0)
		_seed_focus(1)
	_previous_focus = null

## [UI] Force la fermeture du menu pause s'il est ouvert, pour ne pas gêner la Killcam.
## Le panneau lui-même doit disparaître : le laisser visible masquait la killcam
## derrière un menu « PAUSE » que plus rien ne fermait.
func force_close_pause() -> void:
	if pause_panel != null and pause_panel.visible:
		_fermer_sec(pause_panel)
	# La parenthèse des options emprunte le menu à onglets : il faut la refermer
	# elle aussi, sans quoi la killcam resterait derrière un panneau « OPTIONS ».
	if _options_from_pause:
		_options_from_pause = false
		btn_back.hide()
		_remettre_la_navigation_a_l_accueil()
		_fermer_sec(game_over_panel)
	# Sans condition de mode : une pause locale ouverte au moment où l'on bascule
	# en ligne laisserait l'arbre gelé.
	get_tree().paused = false

## L'application vit dans GameSettings, qui doit rejouer le même choix au
## prochain lancement : deux implémentations divergeraient.
func _on_res_selected(index: int) -> void:
	GameSettings.set_resolution(index)
