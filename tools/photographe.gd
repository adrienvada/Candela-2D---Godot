extends Node

## LE PHOTOGRAPHE — l'outil qui sort les images du jeu, pour en parler dehors.
##
## ## Ce qu'il fait, et à qui il sert
##
## Il ouvre le jeu, le met en scène état par état, et écrit un dossier d'images
## nommées, numérotées, accompagnées d'un **manifeste** (ce que montre chaque
## image, à quoi elle sert) et d'une **planche HTML** qu'on ouvre d'un
## double-clic. C'est le fournisseur d'images de toute la communication :
## captures de jeu, menus, illustrations, phases de duel, écrans de fin.
##
## Il est la suite outillée du chantier DA6 « Les moments qu'on screenshote » :
## DA6.1 (l'écran de victoire), DA6.2 (le gel fatal signé), DA6.4 (le bilan de
## session) ont chacun leur plan ici — non pour les composer, mais pour qu'on
## puisse enfin les REGARDER hors du jeu, côte à côte, avant de les composer.
##
## ## Pourquoi il ne remplace pas `planche_contact.gd`, et l'inverse non plus
##
## La planche de contact **diagnostique** : elle balaie les états à la taille de
## la fenêtre, efface ses images à chaque passage, et n'affirme rien pour que
## l'œil trouve ce à quoi personne n'avait pensé. Le photographe **produit** :
## il vise une résolution choisie, garde ses images, les décrit, et sait faire
## des choses qu'aucun diagnostic ne demande — le duel sans HUD, les découpes
## carrée et verticale, le catalogue des cartes.
##
## Ils partagent en revanche les leçons déjà payées, et c'est pour ça qu'elles
## sont rappelées ici plutôt que réinventées :
##
## - **`grab_focus()` ne remplit pas le cadre de droite.** Il se remplit par
##   `MenuHub.reveal_entry()`. Un outil qui ne prend pas ce chemin photographie
##   un écran que personne ne voit (payé le 2026-08-25).
## - **Un outil d'observation ne produit rien dans le monde.** Entrer dans les
##   écrans de salon EST la décision de mode : `_on_hub_screen_changed` y écrit
##   le transport et ouvrirait de vrais salons EOS. On atteint donc le CONTENU
##   sans prendre l'itinéraire (`show_panel`, `montrer_texte`, un `MenuEngraver`
##   posé à part).
## - **macOS bride le rendu d'une fenêtre au second plan** au point que
##   `frame_post_draw` cesse d'être émis. La fenêtre est remise devant avant
##   chaque prise, une prise manquée est retentée une fois, puis déclarée
##   perdue — jamais attendue indéfiniment.
## - **Le tir tue le sujet.** Les deux joueurs sont maintenus en vie de force
##   pendant les plans qui tirent, sans quoi la manche se termine au milieu de
##   la séance et tout ce qui suit sort noir sans rien dire.
##
## ## Deux sources d'image, et c'est le cœur de l'outil
##
## - `ecran` — la fenêtre entière, telle que le joueur la voit : HUD compris,
##   menus, écrans de fin. C'est la capture « honnête ».
## - `vue` — la texture de `SubViewport1` seule : **le duel sans le HUD**, au
##   même cadrage et à la même résolution. C'est l'image d'affiche.
##
## ⚠️ **`rendu_racine_autorise` est mis à faux pendant toute la séance**, et ce
## n'est pas un détail. Depuis le chantier R, une vue unique se rend DANS LA
## RACINE et les deux `SubViewport` s'arrêtent : `vp1` n'a alors plus de texture
## à donner, et la source `vue` rendrait une image gelée ou vide. On repasse
## donc par le chemin sous-vue le temps des photos. Ce que voit le joueur est
## identique — le conteneur étire une texture de la taille de la fenêtre, donc
## sans étirement réel ; seul le coût change, et il n'a aucune importance ici.
##
## ## Lancer
##
##     ./tools/run_photos.sh                      tout, en 1920×1080
##     ./tools/run_photos.sh --liste              le catalogue, sans ouvrir le jeu
##     ./tools/run_photos.sh --famille=jeu,fins   deux familles
##     ./tools/run_photos.sh --plan=gel-fatal     un seul plan
##     ./tools/run_photos.sh --taille=3840x2160   en 4K (si l'écran le permet)
##     ./tools/run_photos.sh --decoupes           + les recadrages carré et 9:16
##     ./tools/run_photos.sh --sans-hud           le HUD retiré des plans `ecran`
##     ./tools/run_photos.sh --zoom=1.6           cadrage serré (déclaré au manifeste)
##     ./tools/run_photos.sh --sortie=user://presse  ailleurs que dans `user://photos`
##
## Les images sortent dans `user://photos/`, dont le chemin réel est imprimé à
## la fin. **C'est `planche.html` qu'on ouvre**, pas le dossier.

const Commun := preload("res://tools/rendu_commun.gd")

## Le temps laissé au jeu avant une prise : les fondus se terminent, les shaders
## se compilent, la vitrine s'installe. Plus court, on photographie une
## transition et le manifeste ment sur l'état qu'il annonce.
const REPOS_DEFAUT := 0.6

## 1920×1080 par défaut : le format que toute plateforme accepte, et qui tient
## sur n'importe quel écran. `--taille` monte plus haut quand l'écran suit — une
## image se réduit sans perte, elle ne s'agrandit pas.
const TAILLE_DEFAUT := Vector2i(1920, 1080)

const DOSSIER_DEFAUT := "user://photos"


## LA MARIONNETTE — un `InputProvider` que le photographe tient à la main.
##
## **Sans elle, le cadrage dépendait de la position de la SOURIS.** J1 vise le
## curseur (`LocalInputProvider.get_aim_direction`), si bien que le faisceau
## pointait ailleurs à chaque séance, et J2 — piloté par un stick qui n'existe
## pas — gardait la rotation qu'il avait. Deux passages donnaient deux
## compositions, et aucune n'était celle qu'on avait choisie.
##
## Elle remplace le fournisseur des deux joueurs le temps des photos. C'est le
## point d'entrée prévu par le jeu (`GameState._set_player_input_provider`), et
## la raison d'être du patron : `player.gd` ne sait pas d'où viennent ses
## commandes, donc il ne s'aperçoit de rien.
class Marionnette extends InputProvider:
	var visee := Vector2.RIGHT
	var torche := false

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_shoot_pressed() -> bool:
		return false

	func is_flashlight_pressed() -> bool:
		return torche

	func is_flare_pressed() -> bool:
		return false

	func is_reload_pressed() -> bool:
		return false

## Distance entre les deux joueurs sur les plans de duel. 260 px : assez près
## pour que les deux corps tiennent dans le cadre et que les faisceaux se
## croisent, assez loin pour qu'on lise deux silhouettes et non une mêlée.
const ECART_DUEL := 260.0

## L'axe de visée imposé à J1. Une diagonale douce plutôt que l'horizontale : le
## cône traverse alors le cadre en biais, ce qui se compose mieux et se recadre
## en carré sans perdre sa pointe.
const VISEE := Vector2(1.0, 0.36)

## L'ordre des familles EST l'ordre de la séance, et il n'est pas alphabétique :
## chaque famille laisse le jeu dans un état, et la suivante part de là. Les
## menus d'abord (état de démarrage), les familles pures ensuite (elles ne
## touchent pas au jeu), le duel enfin, et la mort en dernier — on ne rouvre pas
## un menu propre après avoir tué quelqu'un.
const FAMILLES: Array[String] = ["menus", "illustrations", "cartes", "jeu", "fins"]

var _main: Node
var _ui: Node
var _dossier := DOSSIER_DEFAUT
var _taille := TAILLE_DEFAUT
var _repos := REPOS_DEFAUT
var _decoupes := false
var _sans_hud := false
var _zoom := 1.0
var _photos: Array[Dictionary] = []
var _perdues := 0
var _rangs: Dictionary = {}
var _mute_avant := false
var _pantins: Array[Marionnette] = []


# ---------------------------------------------------------------------------
# LE CATALOGUE
#
# Statique, et lisible sans ouvrir de fenêtre — `--liste` s'en sert, et
# `tools/test_photographe.gd` le vérifie en headless. Un outil qui ouvre une
# fenêtre ne peut être dans aucune suite ; ce qu'il DÉCLARE, si.
#
# `pourquoi` n'est pas de la décoration : c'est ce qui distingue une image utile
# d'une image jolie. Il est recopié dans le manifeste et sous chaque vignette de
# la planche, pour qu'on sache six mois plus tard à quoi cette image servait.
# ---------------------------------------------------------------------------

## Un plan : `id`, `famille`, `titre`, `pourquoi`, `source` (`ecran` ou `vue`),
## `ancre` (le point d'intérêt, en UV, autour duquel les découpes se centrent),
## et `lot` (vrai si le plan se déplie en plusieurs images à l'exécution).
static func catalogue() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		# --- menus ---------------------------------------------------------
		{"id": "accueil", "famille": "menus", "source": "ecran",
		 "titre": "L'accueil",
		 "pourquoi": "La première image du jeu : titre, torche du curseur, illustration vivante."},
		{"id": "salon-local", "famille": "menus", "source": "ecran",
		 "titre": "Le salon 1v1 local",
		 "pourquoi": "Le choix des armes et de la carte — l'écran d'avant-match d'une soirée."},
		{"id": "personnalisation", "famille": "menus", "source": "ecran",
		 "titre": "La personnalisation",
		 "pourquoi": "Montre que le jeu se règle : profondeur perçue sans une ligne de texte."},
		{"id": "reglages", "famille": "menus", "source": "ecran", "lot": true,
		 "titre": "Les rubriques de réglage",
		 "pourquoi": "Une image par rubrique du cadre de droite — captures de fiche technique."},
		{"id": "cadre-rang", "famille": "menus", "source": "ecran",
		 "titre": "Le cadre de droite, rang poussé",
		 "pourquoi": "Le classé sans ouvrir de file : ELO, série de la soirée."},
		{"id": "cadre-profil", "famille": "menus", "source": "ecran",
		 "titre": "Le panneau de profil",
		 "pourquoi": "L'identité du joueur — pour parler de progression."},
		{"id": "cadre-historique", "famille": "menus", "source": "ecran",
		 "titre": "L'historique des matchs",
		 "pourquoi": "La trace d'une soirée jouée : matière du bilan de session (DA6.4)."},
		{"id": "power-on", "famille": "menus", "source": "ecran",
		 "titre": "L'allumage",
		 "pourquoi": "DA6.5 — la première seconde du jeu : le filament monte, le mot est révélé. La première image d'un trailer."},
		{"id": "code-de-salon", "famille": "menus", "source": "ecran", "lot": true,
		 "titre": "Le bloc de gravure du code de salon",
		 "pourquoi": "Trois états — vide, chasse large, chasse étroite. L'image qu'on montre pour dire « jouez à deux »."},

		# --- illustrations -------------------------------------------------
		{"id": "artworks", "famille": "illustrations", "source": "propre", "lot": true,
		 "titre": "Les illustrations de menu, à travers le shader",
		 "pourquoi": "Les planches telles que le jeu les éclaire — torche, effet vivant — et non le fichier brut. Matière première de toute mise en page."},

		# --- cartes --------------------------------------------------------
		{"id": "plans", "famille": "cartes", "source": "propre", "lot": true,
		 "titre": "Le plan de chaque carte",
		 "pourquoi": "Une arène lue d'un coup d'œil : murs, sol, les deux départs. Pour parler des cartes sans les décrire."},

		# --- jeu -----------------------------------------------------------
		{"id": "decompte", "famille": "jeu", "source": "ecran",
		 "titre": "Le décompte d'avant-manche",
		 "pourquoi": "La seconde où les deux joueurs se taisent. Ouverture naturelle d'un trailer (DA7.2)."},
		# ⚠️ **Ce que cette image montre exactement, et il a fallu lire le code
		# pour le dire juste.** Deux faisceaux SONT visibles dans une même vue :
		# l'arène est dupliquée par joueur, mais les deux copies portent la
		# couche de lumière 1 et toute torche l'éclaire
		# (`flashlight.range_item_cull_mask = 1|2|4`). Voir le faisceau d'en face
		# balayer le sol est même la moitié « trahit » de la mécanique.
		# Ce qu'on ne voit pas, c'est le CORPS de l'adversaire : son sprite
		# d'écran ennemi n'est allumé que par NOS lumières.
		{"id": "duel", "famille": "jeu", "source": "vue", "ancre": [0.5, 0.5],
		 "titre": "Deux faisceaux dans le même noir",
		 "pourquoi": "L'image du jeu en une : le faisceau d'en face balaie le sol (il trahit), et le corps n'apparaît que dans le nôtre (il révèle)."},
		{"id": "torche", "famille": "jeu", "source": "vue", "ancre": [0.5, 0.5],
		 "titre": "La torche seule dans le noir",
		 "pourquoi": "La promesse du jeu sans adversaire : la seule information est la lumière."},
		{"id": "retrodiffusion", "famille": "jeu", "source": "vue", "ancre": [0.5, 0.5],
		 "titre": "Le mur qui renvoie la lumière",
		 "pourquoi": "La mécanique que personne ne devine sur une capture de menu : éclairer trahit."},
		{"id": "flash-de-tir", "famille": "jeu", "source": "vue", "ancre": [0.5, 0.5],
		 "titre": "L'éclat de bouche",
		 "pourquoi": "Le tir comme source de lumière. L'image la plus violente que le jeu produise."},
		# `ecran` et non `vue` : **le voile est peint par l'interface**
		# (`ui.gd::_poser_voile`), donc il vit dans un `CanvasLayer` que la
		# texture de la vue ne contient pas. Pris en `vue`, ce plan rendait un
		# duel parfaitement normal — un éblouissement invisible, c'est-à-dire le
		# contraire du sujet.
		{"id": "eblouissement", "famille": "jeu", "source": "ecran", "ancre": [0.5, 0.5],
		 "titre": "Le voile de l'éblouissement",
		 "pourquoi": "Ce que subit celui qu'on éclaire — un état de jeu qu'aucune capture neutre ne montre."},
		{"id": "fusee", "famille": "jeu", "source": "vue", "ancre": [0.5, 0.5],
		 "titre": "La fusée éclairante",
		 "pourquoi": "Le moment où le noir cède : la seule lumière du jeu que personne ne tient."},
		{"id": "sang", "famille": "jeu", "source": "vue", "ancre": [0.5, 0.5],
		 "titre": "Le sang au sol",
		 "pourquoi": "La trace laissée par un échange — ce qui reste quand la lumière repasse."},
		{"id": "armes", "famille": "jeu", "source": "vue", "lot": true,
		 "titre": "Le cône des quatre armes",
		 "pourquoi": "Une image par arme : le choix d'arme EST un choix de champ de vision. Se montre, ne se raconte pas."},
		{"id": "hud", "famille": "jeu", "source": "ecran",
		 "titre": "Le duel tel qu'il se joue, HUD compris",
		 "pourquoi": "La capture honnête : munitions, chrono, vie. Celle qu'attend une fiche de boutique."},
		{"id": "ecran-scinde", "famille": "jeu", "source": "ecran",
		 "titre": "Les deux vues côte à côte",
		 "pourquoi": "Le mode canapé, et lui seul : deux joueurs, deux mondes noirs, un seul écran."},
		{"id": "entrainement", "famille": "jeu", "source": "ecran",
		 "titre": "L'entraînement",
		 "pourquoi": "Le mode solo : la cible, la vue unique, le chrono remplacé par un mot."},
		# --- refonte roman graphique (2026-09-10) : les événements qu'on juge ---
		# Quatre plans ajoutés pour comparer AVANT/APRÈS chaque lot de la refonte
		# des effets en jeu. Ils montrent des effets qui ne durent qu'une
		# fraction de seconde : le repos est nul ou presque, comme pour l'éclat
		# de bouche.
		{"id": "impacts", "famille": "jeu", "source": "vue", "ancre": [0.5, 0.5],
		 "titre": "Les éclats sur un mur",
		 "pourquoi": "Trois tirs manqués dans un mur : la seule trace qu'un tir raté laisse au monde, et ses étincelles."},
		{"id": "vignette", "famille": "jeu", "source": "ecran", "ancre": [0.5, 0.5],
		 "titre": "La vignette de dégâts",
		 "pourquoi": "L'écran de celui qui vient d'encaisser : le rouge aux bords, l'instant d'après le coup."},

		# --- fins ----------------------------------------------------------
		{"id": "mort", "famille": "fins", "source": "ecran", "ancre": [0.5, 0.5],
		 "titre": "Le flash de mort",
		 "pourquoi": "L'écran du mort, une image après le coup fatal : le blanc et sa frange. Pris sur une manche sacrifiée avant la séquence de fin."},
		# `ecran` et non `vue` : pendant le gel de 150 ms qui suit le coup fatal,
		# les SubViewport sont en UPDATE_DISABLED et la source `vue` rendrait
		# l'image figée d'avant l'onde (contrainte relevée par la session
		# photographe, 2026-09-10).
		{"id": "onde-de-choc", "famille": "fins", "source": "ecran", "ancre": [0.5, 0.5],
		 "titre": "L'onde de choc du kill",
		 "pourquoi": "L'anneau qui part du corps et traverse l'arène : la seule lumière autorisée à tout éclairer, parce que le duel est tranché."},
		{"id": "killcam", "famille": "fins", "source": "ecran",
		 "titre": "La killcam",
		 "pourquoi": "Le rejeu de sa propre mort. Une mécanique qui ne se comprend qu'en image."},
		{"id": "gel-fatal", "famille": "fins", "source": "ecran",
		 "titre": "L'arrêt sur image signé",
		 "pourquoi": "DA6.2 — le gel du kill, tamponné de l'heure. L'image que le joueur veut envoyer."},
		{"id": "affiche", "famille": "fins", "source": "ecran",
		 "titre": "L'affiche de fin",
		 "pourquoi": "DA6.1 — le verdict composé comme un poster : le mot, le filet, la légende, la ligne de session."},
		{"id": "soiree", "famille": "fins", "source": "ecran",
		 "titre": "La carte de fin de soirée",
		 "pourquoi": "DA6.3 / DA6.4 — ce que la soirée a produit, dans le format 4:5 qu'on exporte et qu'on envoie."},
		{"id": "verdict-victoire", "famille": "fins", "source": "ecran",
		 "titre": "VICTOIRE",
		 "pourquoi": "DA6.1 — l'écran de fin composé comme une affiche."},
		{"id": "verdict-defaite", "famille": "fins", "source": "ecran",
		 "titre": "DÉFAITE",
		 "pourquoi": "DA6.1 — le pendant sombre, à juger avec son contraire sous les yeux."},
		{"id": "verdict-egalite", "famille": "fins", "source": "ecran",
		 "titre": "ÉGALITÉ",
		 "pourquoi": "DA6.1 — le verdict gris, « parce que le blanc est la couleur de ce qui s'affirme »."},
		{"id": "bilan", "famille": "fins", "source": "ecran",
		 "titre": "Le bilan de session, bandeau plein",
		 "pourquoi": "DA6.4 — score de session, série brisée, marge du dernier coup. La carte de fin de soirée, dans son état le plus chargé."},
	]
	return out


## Les appuis du photographe sur le jeu, sous une forme qu'une suite headless
## peut vérifier. **Un outil qui ouvre une fenêtre ne peut être dans aucune
## suite, donc rien ne surveille sa péremption** — c'est la leçon du banc de
## cadence, resté cassé une semaine sans que personne le sache. Il déclare donc
## ce dont il dépend le jour de sa naissance, plutôt qu'après la première panne.
static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents

	for prop in ["p1", "p2", "vp1", "vp2", "arena", "round_active",
			"countdown_left", "sandbox_mode", "rendu_racine_autorise",
			"archiver_les_matchs"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	# `_accorder_rendu_aux_vues` est privée et l'outil l'appelle quand même :
	# c'est le seul point du jeu qui sache accorder le rendu au nombre de vues
	# regardées, et le dupliquer serait s'engager à le suivre.
	for methode in ["_on_replay_requested", "_on_training_requested",
			"_on_main_menu_requested", "weapon_for_index",
			"_accorder_rendu_aux_vues", "spawn_fusee",
			"_set_player_input_provider"]:
		if not main.has_method(methode):
			absents.append("GameState.%s() a disparu" % methode)

	for prop in ["hub", "match_hud", "center_line", "hud_panneau_p2",
			"_voile_scinde"]:
		if not prop in ui:
			absents.append("UI.%s a disparu" % prop)
	for methode in ["show_main_menu", "show_game_over", "poser_bilan",
			"set_countdown", "disposer_hud"]:
		if not ui.has_method(methode):
			absents.append("UI.%s() a disparu" % methode)
	for constante in ["SCREEN_LOCAL", "SCREEN_CUSTOM", "PANEL_PROFILE",
			"PANEL_HISTORY"]:
		if not constante in ui:
			absents.append("UI.%s a disparu" % constante)

	var hub = ui.get("hub") if "hub" in ui else null
	if hub == null:
		absents.append("UI.hub est nul")
	else:
		# `reveal_entry` est le relais SANS LEQUEL le cadre de droite reste vide :
		# les curseurs maison ne déclenchent jamais `focus_entered`. Son absence
		# ne casserait rien visiblement — elle rendrait des images d'un écran que
		# personne ne voit. C'est exactement le défaut du 2026-08-25.
		for methode in ["push", "reset", "has_screen", "list_of", "show_panel",
				"montrer_texte", "reveal_entry"]:
			if not hub.has_method(methode):
				absents.append("MenuHub.%s() a disparu" % methode)

	# Le joueur est interrogé sur son SCRIPT : au moment où la suite regarde, la
	# manche n'a pas commencé et `p1` peut être nul.
	var script_joueur := load("res://player.gd") as GDScript
	if script_joueur == null:
		absents.append("player.gd est introuvable")
	else:
		var noms := {}
		for m in script_joueur.get_script_method_list():
			noms[m["name"]] = true
		for methode in ["equip_weapon", "shoot", "take_damage", "apply_dazzle",
				"lancer_fusee", "trigger_shoot_visuals"]:
			if not noms.has(methode):
				absents.append("Player.%s() a disparu" % methode)

	# Les deux touches que le photographe presse. Retirées de l'Input Map, les
	# torches ne s'allumeraient jamais : toute la famille `jeu` sortirait noire.
	for action in ["p1_torch", "p2_torch"]:
		if not InputMap.has_action(action):
			absents.append("l'action « %s » a disparu de l'Input Map" % action)

	# DA6 — les quatre compositions que le photographe pilote depuis l'extérieur.
	# Elles sont neuves et vivent dans leurs propres fichiers ; ce qui les rend
	# fragiles ici, c'est que l'outil les atteint par des méthodes qu'aucun autre
	# appelant n'utilise (`congedier`, `terminer`, `fermer`).
	for cas in [["res://power_on.gd", "terminer"], ["res://power_on.gd", "figer"],
			["res://affiche_de_fin.gd", "congedier"],
			["res://panneau_de_soiree.gd", "fermer"]]:
		var sc := load(String(cas[0])) as GDScript
		if sc == null:
			absents.append("%s est introuvable" % cas[0])
			continue
		var noms := {}
		for m in sc.get_script_method_list():
			noms[m["name"]] = true
		if not noms.has(String(cas[1])):
			absents.append("%s::%s() a disparu" % [cas[0], cas[1]])

	# La source `vue` lit la texture de vp1 ; le shader des illustrations et la
	# miniature de carte sont les deux familles « pures ».
	if not ResourceLoader.exists("res://menu_artwork.gdshader"):
		absents.append("menu_artwork.gdshader est introuvable")
	if load("res://map_thumbnail.gd") == null:
		absents.append("map_thumbnail.gd est introuvable")
	return absents


# ---------------------------------------------------------------------------
# LA SÉANCE
# ---------------------------------------------------------------------------

func _ready() -> void:
	var args := OS.get_cmdline_user_args()

	# `--liste` AVANT le refus headless : lire le catalogue ne demande pas
	# d'écran, et c'est la première chose qu'on veut pouvoir faire.
	if _drapeau(args, "--liste"):
		_imprimer_catalogue()
		_sortir(0)
		return

	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ le photographe ne peut pas travailler ici : ", refus)
		printerr("  Lancer SANS --headless : ./tools/run_photos.sh")
		_sortir(1)
		return

	var choisis := _selection(args)
	if choisis.is_empty():
		printerr("✗ aucun plan ne correspond à la sélection demandée.")
		printerr("  `--liste` imprime le catalogue.")
		_sortir(1)
		return

	_dossier = _valeur(args, "--sortie", DOSSIER_DEFAUT)
	_repos = float(_valeur(args, "--repos", str(REPOS_DEFAUT)))
	_decoupes = _drapeau(args, "--decoupes")
	_sans_hud = _drapeau(args, "--sans-hud")
	_zoom = maxf(0.2, float(_valeur(args, "--zoom", "1.0")))
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))

	print("=== Le photographe ===")
	_poser_la_fenetre()
	# Une séance dure une minute et tire une trentaine de coups de feu. On coupe
	# le son au niveau du serveur audio et non des réglages : `GameSettings`
	# écrit dans `user://settings.cfg`, et un outil n'a pas à laisser le jeu
	# muet derrière lui.
	_mute_avant = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")

	var manquants: Array[String] = Commun.preconditions_manquantes(_ui, _main)
	manquants.append_array(preconditions_manquantes(_ui, _main))
	if not manquants.is_empty():
		printerr("✗ le photographe ne peut pas démarrer — le jeu a changé sous lui :")
		for m in manquants:
			printerr("    · ", m)
		_sortir(1)
		return

	# Voir l'en-tête : la source `vue` exige que vp1 dessine encore.
	_main.rendu_racine_autorise = false

	# ⚠️ **Et l'historique des matchs n'est pas à nous.** Chaque plan de la
	# famille `fins` tue un joueur, et une manche terminée s'archive dans
	# `user://match_history.json` — le VRAI, celui d'Adrien, plafonné à deux
	# cents entrées. Jusqu'au 2026-09-10, chaque séance y déposait un faux match
	# et en poussait un vrai dehors. L'en-tête promettait pourtant qu'« un outil
	# d'observation ne produit rien dans le monde » : la promesse tenait pour les
	# salons EOS, pas pour l'historique. `cineaste.gd` appelle `super()` et en
	# hérite.
	_main.archiver_les_matchs = false

	_preparer_le_dossier()

	# ⚠️ **L'allumage (DA6.5) part tout seul au démarrage du jeu**, et il tient
	# trois secondes par-dessus tout. Sans ce passage, il se serait invité sur la
	# première image de la famille `menus` — un accueil voilé, sans que rien
	# n'explique pourquoi. On le photographie s'il est demandé, puis on le
	# congédie ; sinon on le congédie tout de suite.
	#
	# ⚠️ **APRÈS `_preparer_le_dossier()`, et le premier jet l'avait avant.** Le
	# nettoyage efface les PNG de la séance précédente : placé après la prise, il
	# emportait l'image de l'allumage, seule image écrite avant lui. Elle était
	# annoncée à la console et absente du dossier — la pire des deux moitiés.
	await _traiter_l_allumage(_plans_de(choisis, "menus"))

	for famille in FAMILLES:
		var plans := _plans_de(choisis, famille)
		if plans.is_empty():
			continue
		print("\n--- %s ---" % famille)
		match famille:
			"menus": await _famille_menus(plans)
			"illustrations": await _famille_illustrations(plans)
			"cartes": await _famille_cartes(plans)
			"jeu": await _famille_jeu(plans)
			"fins": await _famille_fins(plans)

	_ecrire_le_manifeste()
	_ecrire_la_planche()

	print("\n%d image(s) écrite(s) dans :\n  %s" % [
		_photos.size(), ProjectSettings.globalize_path(_dossier)])
	print("Ouvrez `planche.html` : c'est la planche, pas le dossier.")
	if _perdues > 0:
		printerr("⚠ %d prise(s) perdue(s) — fenêtre passée au second plan" % _perdues)
	AudioServer.set_bus_mute(0, _mute_avant)
	_sortir(0)


# ---------------------------------------------------------------------------
# LES FAMILLES
# ---------------------------------------------------------------------------

## L'allumage : il est déjà en cours quand le photographe prend la main.
func _traiter_l_allumage(plans: Array[Dictionary]) -> void:
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage == null:
		if _demande(plans, "power-on"):
			printerr("  ! l'allumage a déjà fini — plan `power-on` sans sujet")
		return
	if _demande(plans, "power-on"):
		print("\n--- menus (l'allumage) ---")
		# ⚠️ **On lui demande de tenir la pose plutôt que de viser le bon
		# instant.** Le premier jet attendait 1,6 s, ce qui tombait pile — sur
		# une machine. La séquence dure deux secondes et part au lancement du
		# jeu ; le temps de monter `main.tscn`, de vérifier les appuis et de
		# préparer le dossier, l'outil arrive parfois APRÈS la fin, et la prise
		# rend alors le menu d'accueil sous le nom « power-on ». Un cadrage qui
		# dépend de la vitesse de la machine n'est pas un cadrage.
		if allumage.has_method("figer"):
			allumage.figer()
		await _prendre(_plan(plans, "power-on"), Callable(), 0.25)
	if is_instance_valid(allumage) and allumage.has_method("terminer"):
		allumage.terminer()
	# La séquence de sortie dure `D_SORTIE` : la couper à la hache laisserait un
	# voile noir à moitié effacé sur la première image des menus.
	await _attendre_disparition(allumage, 3.0)


func _famille_menus(plans: Array[Dictionary]) -> void:
	_ui.show_main_menu()
	await _peut_etre(plans, "accueil")

	# On traverse par `push()` comme le ferait un joueur : un écran atteint
	# autrement n'est pas dans l'état où on le verra jamais. Les écrans de salon
	# et d'appariement restent écartés — y entrer EST la décision de mode.
	for cas in [["salon-local", _ui.SCREEN_LOCAL],
			["personnalisation", _ui.SCREEN_CUSTOM]]:
		if not _demande(plans, String(cas[0])):
			continue
		if not _ui.hub.has_screen(String(cas[1])):
			continue
		_ui.hub.reset()
		_ui.hub.push(String(cas[1]))
		await _peut_etre(plans, String(cas[0]))

	if _demande(plans, "reglages") and _ui.hub.has_screen(_ui.SCREEN_CUSTOM):
		_ui.hub.reset()
		_ui.hub.push(_ui.SCREEN_CUSTOM)
		var liste = _ui.hub.list_of(_ui.SCREEN_CUSTOM)
		if liste != null:
			var i := 0
			for enfant in liste.get_children():
				var btn := enfant as Button
				if btn == null or btn.disabled:
					continue
				i += 1
				# Les DEUX gestes : le focus de Godot pour le liseré, et
				# `reveal_entry` pour le contenu. Le second seul remplit le cadre.
				btn.grab_focus()
				_ui.hub.reveal_entry(btn)
				var nom := _libelle(btn)
				# L'entrée de retour n'est pas une rubrique : son cadre de
				# droite est vide, et elle sortait sous le nom « retour » au
				# milieu des cinq écrans de réglage.
				if nom.begins_with("‹") or nom.to_upper().ends_with("RETOUR"):
					i -= 1
					continue
				await _prendre(_derive(plans, "reglages",
					"%02d-%s" % [i, _ardoise(nom)], nom))

	_ui.hub.reset()
	if _demande(plans, "cadre-rang"):
		_ui.hub.montrer_texte("MON RANG",
			"[b]Argent II[/b] — 1240 ELO\nSérie de la soirée : 3 victoires")
		await _peut_etre(plans, "cadre-rang")
	for cas in [["cadre-profil", _ui.PANEL_PROFILE],
			["cadre-historique", _ui.PANEL_HISTORY]]:
		if not _demande(plans, String(cas[0])):
			continue
		_ui.hub.show_panel(String(cas[1]))
		await _peut_etre(plans, String(cas[0]))
	_ui.hub.show_panel("")

	if _demande(plans, "code-de-salon"):
		await _code_de_salon(plans)


## Le bloc de gravure, photographié SANS ouvrir de salon.
##
## ⚠️ **Un `CanvasLayer`, et pas un `Control` posé dans l'arbre.** `ui.gd` vit
## dans un `CanvasLayer`, et une couche passe devant tout ce qui n'en est pas
## une, quel que soit l'ordre des frères : un simple `ColorRect` ajouté après
## `_main` photographierait le menu, parfaitement lisible et hors sujet.
func _code_de_salon(plans: Array[Dictionary]) -> void:
	var couche := CanvasLayer.new()
	couche.layer = 200
	add_child(couche)
	var cadre := ColorRect.new()
	cadre.color = Charte.BACKDROP
	cadre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	couche.add_child(cadre)
	var bloc := MenuEngraver.new()
	bloc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bloc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bloc.grow_vertical = Control.GROW_DIRECTION_BOTH
	cadre.add_child(bloc)

	await _prendre(_derive(plans, "code-de-salon", "1-vide", "cases vides"))
	# `WXYZW3` et `JT7JT7` : les deux extrêmes de chasse de l'alphabet des codes.
	bloc.set_code("WXYZW3")
	await _prendre(_derive(plans, "code-de-salon", "2-large", "chasse large"))
	bloc.set_code("JT7JT7")
	await _prendre(_derive(plans, "code-de-salon", "3-etroit", "chasse étroite"))

	couche.queue_free()
	await get_tree().process_frame


## Les illustrations de menu, éclairées comme le jeu les éclaire.
##
## Elles ne se capturent pas à l'écran mais dans un `SubViewport` à part : le
## menu les affiche derrière un verre fumé et un voile, et c'est la planche
## ÉCLAIRÉE qu'on veut, pas le décor du menu. Le dosage est celui de
## `menu_hub.gd` — le recopier ailleurs serait s'engager à le suivre, donc il est
## lu au même endroit que la production le pose.
func _famille_illustrations(plans: Array[Dictionary]) -> void:
	var plan := _plan(plans, "artworks")
	if plan.is_empty():
		return
	var taille := Vector2i(2048, 1280)  # 1024×640 ×2 : le format des planches
	var vue := SubViewport.new()
	vue.size = taille
	vue.transparent_bg = false
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(vue)
	var rect := TextureRect.new()
	rect.size = Vector2(taille)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	vue.add_child(rect)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://menu_artwork.gdshader") as Shader
	rect.material = mat

	# ⚠️ **Deux fichiers pour une même clé.** `ill_creer.png` et
	# `ill_creer_ligne.png` se ramènent tous deux à `ill_creer_ligne` par
	# `cle_canonique()` — c'est l'alias que le jeu emploie. Sans ce garde, la
	# seconde planche écrasait la première EN SILENCE : deux lignes de manifeste,
	# un seul fichier, et personne pour s'en apercevoir.
	var vues := {}
	for chemin in _illustrations():
		var tex := load(chemin) as Texture2D
		if tex == null:
			continue
		if vues.has(MenuArtwork.cle_canonique(chemin)):
			continue
		vues[MenuArtwork.cle_canonique(chemin)] = true
		rect.texture = tex
		var cle := MenuArtwork.cle_canonique(chemin)
		mat.set_shader_parameter("ambient_exposure", 0.28)
		mat.set_shader_parameter("torch_pos", MenuArtwork.poi_pour(chemin))
		mat.set_shader_parameter("torch_radius", 0.45)
		mat.set_shader_parameter("torch_intensity", 1.0)
		mat.set_shader_parameter("reveal_progress", 1.0)
		mat.set_shader_parameter("effect_mode", MenuArtwork.effet_pour(chemin))
		# Un temps figé et non zéro : à zéro, la plupart des effets vivants sont
		# à leur point mort et la planche montre l'illustration au repos, c'est-
		# à-dire l'état qu'on voit le moins en jouant.
		mat.set_shader_parameter("effect_time", 2.0)
		mat.set_shader_parameter("effect_strength", 1.0)
		mat.set_shader_parameter("mode_flou_total", 0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = vue.get_texture().get_image()
		_ecrire(_derive(plans, "artworks", cle, cle), img)
	vue.queue_free()


## Le plan de chaque carte du catalogue, peint par le code.
##
## `MapThumbnail` et non une capture : une miniature de carte est une donnée, pas
## une scène. Elle n'a besoin ni de fenêtre, ni d'arène montée, ni d'un joueur
## posé quelque part — et elle sort identique à chaque passage.
func _famille_cartes(plans: Array[Dictionary]) -> void:
	var plan := _plan(plans, "plans")
	if plan.is_empty():
		return
	var cartes: Array[Dictionary] = MapData.list_maps()
	if cartes.is_empty():
		printerr("  ! catalogue de cartes vide")
		return
	for carte in cartes:
		var data: Dictionary = carte.get("data", {})
		if data.is_empty():
			continue
		var tex: ImageTexture = MapThumbnail.render_fit(data, 1024)
		if tex == null:
			continue
		var nom := _ardoise(String(carte.get("slug", carte.get("id", "carte"))))
		_ecrire(_derive(plans, "plans", nom,
			String(carte.get("name", nom))), tex.get_image())


## Le duel. Une vraie manche en écran partagé — aucun réseau, une seule
## instance — puis la vue de J1 seule, comme en ligne et à l'entraînement.
func _famille_jeu(plans: Array[Dictionary]) -> void:
	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 20.0):
		printerr("  ✗ la manche n'a jamais démarré")
		return
	_prendre_les_commandes()

	# Le décompte se photographie PENDANT qu'il tourne, et il est épinglé le
	# temps de la prise : sans ça, les 0,6 s de repos le feraient tomber d'un
	# cran et l'image montrerait un chiffre qu'on n'a pas demandé.
	if _demande(plans, "decompte"):
		var fige := func() -> void:
			_main.countdown_left = 3.0
			_ui.set_countdown(3.0)
		await _prendre(_plan(plans, "decompte"), fige)

	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0):
		printerr("  ✗ le décompte n'a jamais fini")
		return

	# **Les torches AVANT l'écran scindé, et c'est une réparation.** Le premier
	# jet les allumait juste après, et le plan de l'écran scindé sortait
	# entièrement noir : deux HUD, un trait de séparation, et rien entre les
	# deux. Une image d'un jeu qui n'éclaire pas est une image d'aucun jeu.
	_torches(true)

	# Les deux joueurs plus loin l'un de l'autre que partout ailleurs : chaque
	# demi-écran doit contenir un faisceau ENTIER, et à 260 px les deux flaques
	# de lumière se chevauchaient de part et d'autre du trait de séparation.
	if _demande(plans, "ecran-scinde"):
		_deux_vues()
		await _prendre(_plan(plans, "ecran-scinde"), _duel.bind(560.0, 0.4))

	_vue_unique()

	if _demande(plans, "duel"):
		await _prendre(_plan(plans, "duel"), _duel.bind(ECART_DUEL, 0.0))
	if _demande(plans, "hud"):
		await _prendre(_plan(plans, "hud"), _duel.bind(ECART_DUEL, 0.0))

	# La torche seule : J2 sort du cadre et éteint la sienne. On ne le détruit
	# pas — il reprend sa place trois plans plus loin.
	if _demande(plans, "torche"):
		var seul := func() -> void:
			_vivants()
			Input.action_release("p2_torch")
			if is_instance_valid(_main.p2):
				_main.p2.flashlight_on = false
				_main.p2.global_position = _main.p1.global_position \
					+ _main.p1.global_transform.x * 4000.0
		await _prendre(_plan(plans, "torche"), seul)
		Input.action_press("p2_torch")

	# La rétrodiffusion : on cherche le mur le plus proche dans l'axe et on s'en
	# approche. Sans cette recherche, l'image dépend de la carte et du hasard du
	# point de départ — c'est-à-dire qu'elle ne montre rien de fiable.
	if _demande(plans, "retrodiffusion"):
		_approcher_un_mur()
		await _prendre(_plan(plans, "retrodiffusion"), _duel.bind(120.0, 0.9))

	if _demande(plans, "flash-de-tir"):
		_duel(ECART_DUEL, 0.0)
		await _attendre_images(2)
		_vivants()
		_main.p1.shoot()
		# Repos nul : l'éclat de bouche dure un dixième de seconde. Attendre,
		# c'est photographier ce qu'il en reste, c'est-à-dire rien.
		await _prendre(_plan(plans, "flash-de-tir"), Callable(), 0.0)

	if _demande(plans, "sang"):
		# Le sang naît des balles, pas des dégâts : c'est `bullet.gd` qui pose la
		# tache à l'impact. On tire donc pour de vrai — et on maintient la cible
		# en vie, sans quoi la manche se termine au milieu de la séance.
		var reste := 1.6
		while reste > 0.0:
			_duel(160.0, 0.0)
			if is_instance_valid(_main.p1):
				_main.p1.shoot()
			await get_tree().process_frame
			reste -= get_process_delta_time()
		await _prendre(_plan(plans, "sang"), _duel.bind(160.0, 0.0))

	# Refonte roman graphique — trois tirs dans le mur le plus proche. J2 est
	# rangé DERRIÈRE J1 : une balle qui le toucherait poserait du sang au lieu
	# d'un éclat, et le plan montrerait l'autre effet.
	if _demande(plans, "impacts"):
		_face_a_un_mur()
		var salve := 3
		var reste_tir := 0.0
		while salve > 0:
			_duel(120.0, PI)
			if reste_tir <= 0.0 and is_instance_valid(_main.p1):
				_main.p1.shoot()
				salve -= 1
				reste_tir = 0.35
			await get_tree().process_frame
			reste_tir -= get_process_delta_time()
		# Les étincelles vivent 0,3 à 0,8 s : on prend l'image tout de suite,
		# éclats posés ET étincelles encore en l'air.
		await _prendre(_plan(plans, "impacts"), _duel.bind(120.0, PI), 0.05)
		for pantin in _pantins:
			pantin.visee = VISEE.normalized()

	# Refonte roman graphique — J1 encaisse un coup, sans mourir. La vignette
	# retombe en 0,6 s : repos court, puis `_vivants()` le remet à 100.
	if _demande(plans, "vignette"):
		_duel(ECART_DUEL, 0.0)
		if is_instance_valid(_main.p1):
			_main.p1.take_damage(10.0, _main.p2)
		await _prendre(_plan(plans, "vignette"), _duel.bind(ECART_DUEL, 0.0), 0.08)

	if _demande(plans, "eblouissement"):
		var ebloui := func() -> void:
			_duel(ECART_DUEL, 0.0)
			# Posé à chaque image : le modèle redescend seul, et une valeur
			# écrite une fois aurait fondu pendant le repos.
			if is_instance_valid(_main.p1):
				_main.p1.apply_dazzle(1.0)
		await _prendre(_plan(plans, "eblouissement"), ebloui)

	if _demande(plans, "fusee"):
		_duel(ECART_DUEL, 0.0)
		if is_instance_valid(_main.p1):
			_main.p1.lancer_fusee()
		# La fusée s'allume en vol : on la laisse arriver avant de la regarder.
		await _prendre(_plan(plans, "fusee"), _duel.bind(ECART_DUEL, 0.0), 1.2)

	if _demande(plans, "armes"):
		for idx in range(4):
			var arme: WeaponData = _main.weapon_for_index(idx)
			if arme == null:
				continue
			_main.p1.equip_weapon(arme)
			await _prendre(_derive(plans, "armes", arme.slug(),
				"%s — demi-cône %.0f°, portée %.0f px" % [
					_nom_arme(arme), arme.torch_angle_deg, arme.portee_torche()]),
				_duel.bind(ECART_DUEL, 0.0))
		_main.p1.equip_weapon(_main.weapon_for_index(0))

	if _demande(plans, "entrainement"):
		_torches(false)
		_main._on_training_requested()
		_prendre_les_commandes()
		_vue_unique()
		_torches(true)
		await _prendre(_plan(plans, "entrainement"), _vivants)

	_torches(false)


## La mort, et ce qui vient après. Le seul bloc où l'on LAISSE le jeu faire :
## la séquence de fin est une chorégraphie de temporisations (gel, killcam,
## tampon, écran de fin) et la piloter à la main reviendrait à en écrire une
## seconde, qui divergerait. On l'ouvre, on la suit, on photographie au passage.
func _famille_fins(plans: Array[Dictionary]) -> void:
	# Refonte roman graphique — le flash de mort et l'onde de choc se prennent
	# sur J1 qui MEURT, donc sur une manche qu'on sacrifie : le flash n'existe
	# que sur l'écran du mort, et la séquence de fin qui suit tue J2. On laisse
	# cette fin se dérouler jusqu'à l'écran de fin, puis le bloc ci-dessous
	# relance une manche comme il le fait déjà depuis les menus.
	if _demande(plans, "mort") or _demande(plans, "onde-de-choc"):
		await _manche_sacrifiee(plans)
	if _main.training_mode or not _main.round_active:
		_ui.hub.reset()
		_ui.hub.push(_ui.SCREEN_LOCAL)
		_main._on_replay_requested()
		if not await _attendre(func() -> bool: return _main.round_active, 20.0):
			printerr("  ✗ la manche n'a jamais démarré")
			return
		await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0)
	_prendre_les_commandes()
	_vue_unique()
	_torches(true)

	# **On laisse la manche respirer avant de tuer.** Le tampon du gel affiche
	# l'heure du kill (`round_time - time_left`) : abattu à la première image,
	# il annonce `KILL — 00:00`, ce qui se lit comme un défaut d'affichage plutôt
	# que comme une signature. Quelques secondes, et il dit quelque chose.
	var respire := 5.0
	while respire > 0.0:
		_duel(ECART_DUEL, 0.0)
		await get_tree().process_frame
		respire -= get_process_delta_time()

	if not is_instance_valid(_main.p2):
		printerr("  ✗ pas d'adversaire à faire tomber")
		return
	_main.p2.take_damage(9999.0, _main.p1)

	if _demande(plans, "killcam"):
		if await _attendre(func() -> bool: return ReplaySystem.playing_back, 15.0):
			await _prendre(_plan(plans, "killcam"), Callable(), 0.5)
		else:
			printerr("  ✗ la killcam n'a pas démarré")

	# Le tampon claque juste après la fin du rejeu, et il ne tient que deux
	# secondes avant l'écran de fin. On guette donc la FIN de la lecture, pas une
	# durée : `_spawn_kill_stamp` suit `hide_killcam` dans la même image.
	if _demande(plans, "gel-fatal"):
		if await _attendre(func() -> bool: return not ReplaySystem.playing_back, 40.0):
			await _prendre(_plan(plans, "gel-fatal"), Callable(), 0.35)
		else:
			printerr("  ✗ le rejeu ne s'est jamais arrêté")

	if not await _attendre(func() -> bool: return _main.game_over, 20.0):
		printerr("  ✗ l'écran de fin n'est jamais venu")
		return

	# DA6.1 — l'affiche se pose par-dessus le salon dès que l'écran de fin
	# arrive, et elle se retire seule au bout de six secondes. On la
	# photographie d'abord, puis on la congédie : **tous les plans qui suivent
	# sont dessous**, et sans ce congé ils rendraient trois fois la même
	# affiche sous trois noms différents.
	var affiche := _main.get_node_or_null(^"AfficheDeFin")
	if affiche != null and _demande(plans, "affiche"):
		await _peut_etre(plans, "affiche")
	if is_instance_valid(affiche) and affiche.has_method("congedier"):
		affiche.congedier()
		await _attendre_disparition(affiche, 3.0)

	# **Le bilan et les verdicts ne portent pas les mêmes valeurs, et c'est tout
	# l'intérêt.** Posés identiques, les quatre images étaient quatre fois la
	# même : le bandeau de session survit à `show_game_over`, si bien que le plan
	# « bilan » et le plan « victoire » ne se distinguaient par rien.
	#
	# Le bilan montre donc le bandeau PLEIN — une soirée serrée, une série
	# brisée, un dernier coup à 6 cm —, et les trois verdicts le montrent NU.
	# C'est ce que DA6.4 doit arbitrer : ce que devient la composition quand le
	# bandeau se remplit.
	if _demande(plans, "bilan"):
		_ui.poser_bilan(4, 3, "SÉRIE BRISÉE", 6.0)
		await _peut_etre(plans, "bilan")

	for cas in [["verdict-victoire", 0], ["verdict-defaite", 1],
			["verdict-egalite", -1]]:
		if not _demande(plans, String(cas[0])):
			continue
		_ui.show_game_over(int(cas[1]))
		_ui.poser_bilan(1, 0, "", -1.0)
		await _peut_etre(plans, String(cas[0]))

	if _demande(plans, "soiree"):
		await _carte_de_soiree(plans)


## DA6.3 — la carte de fin de soirée, posée sur un bilan COMPOSÉ.
##
## Elle n'apparaît en jeu qu'après trois matchs dans la même séance, au retour au
## menu. Un outil d'observation ne va pas jouer trois matchs pour voir un écran —
## et surtout, le bilan qu'il obtiendrait serait celui d'une soirée fictive de
## trois matchs identiques, c'est-à-dire une carte qui ne montre aucune de ses
## lignes. Les valeurs ci-dessous sont celles d'une vraie soirée : une série, une
## arme qui domine sans écraser, une arène revue plusieurs fois.
##
## C'est le même geste que `montrer_texte("MON RANG", …)` pour le cadre de
## droite : atteindre le CONTENU sans prendre l'itinéraire.
func _carte_de_soiree(plans: Array[Dictionary]) -> void:
	var panneau = PanneauDeSoiree.poser(_main, {
		"matchs": 7, "assez": true,
		"victoires": 4, "defaites": 3, "nulles": 0,
		"duree_totale": 2840.0, "plus_court": 96.0, "plus_long": 300.0,
		"arme": "Pompe", "arme_n": 4,
		"carte": "Le Cloître", "carte_n": 3,
		"serie": 3, "local_idx": 0,
	})
	await _peut_etre(plans, "soiree")
	if is_instance_valid(panneau) and panneau.has_method("fermer"):
		panneau.fermer()
		await _attendre_disparition(panneau, 3.0)


## Refonte roman graphique — une manche qu'on tue pour photographier la mort
## de J1 : le flash de mort (écran, 0,6 s) puis l'onde de choc (vue, ~1 s).
## Rend la main une fois l'écran de fin arrivé ; l'appelant relance.
func _manche_sacrifiee(plans: Array[Dictionary]) -> void:
	if not _main.round_active:
		_ui.hub.reset()
		_ui.hub.push(_ui.SCREEN_LOCAL)
		_main._on_replay_requested()
		if not await _attendre(func() -> bool: return _main.round_active, 20.0):
			printerr("  ✗ la manche sacrifiée n'a jamais démarré")
			return
		await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0)
	_prendre_les_commandes()
	_vue_unique()
	_torches(true)
	var respire := 1.0
	while respire > 0.0:
		_duel(ECART_DUEL, 0.0)
		await get_tree().process_frame
		respire -= get_process_delta_time()
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2):
		printerr("  ✗ pas de joueur à sacrifier")
		return
	_main.p1.take_damage(9999.0, _main.p2)
	if _demande(plans, "mort"):
		await _prendre(_plan(plans, "mort"), Callable(), 0.08)
	if _demande(plans, "onde-de-choc"):
		# L'onde vit 0,4 s et atteint 1200 px ; le gel fige la vue les 150
		# premières ms. À 160 ms, le front est à ~940 px du corps : visible aux
		# bords du cadre, et la vue vient de se remettre à dessiner.
		await _prendre(_plan(plans, "onde-de-choc"), Callable(), 0.16)
	if not await _attendre(func() -> bool: return _main.game_over, 40.0):
		printerr("  ✗ la manche sacrifiée ne s'est jamais terminée")
	# L'affiche de fin se retire seule ; on la congédie pour que la vraie
	# séquence parte d'un écran propre.
	var affiche := _main.get_node_or_null(^"AfficheDeFin")
	if is_instance_valid(affiche) and affiche.has_method("congedier"):
		affiche.congedier()
		await _attendre_disparition(affiche, 3.0)


## Place J1 à 85 px du mur le plus proche ET le fait viser ce mur. Le cousin de
## `_approcher_un_mur()`, qui rapproche sans tourner : ici les tirs doivent
## FRAPPER le mur, donc la marionnette prend l'axe trouvé.
func _face_a_un_mur() -> void:
	if not is_instance_valid(_main.p1):
		return
	var depart: Vector2 = _main.p1.global_position
	var espace: PhysicsDirectSpaceState2D = _main.p1.get_world_2d().direct_space_state
	var meilleur := depart
	var axe := VISEE.normalized()
	var plus_court := INF
	for i in 24:
		var a := TAU * float(i) / 24.0
		var dir := Vector2.RIGHT.rotated(a)
		var q := PhysicsRayQueryParameters2D.create(depart, depart + dir * 900.0,
			MapGeometry.WALL_LAYER)
		q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
		var coup: Dictionary = espace.intersect_ray(q)
		if coup.is_empty():
			continue
		var d: float = depart.distance_to(coup["position"])
		if d < plus_court and d > 90.0:
			plus_court = d
			meilleur = coup["position"] - dir * 85.0
			axe = dir
	if plus_court < INF:
		_main.p1.global_position = meilleur
	for pantin in _pantins:
		pantin.visee = axe


# ---------------------------------------------------------------------------
# LA MISE EN SCÈNE
# ---------------------------------------------------------------------------

## Une seule vue, comme en ligne et à l'entraînement — et le duel occupe alors
## toute la fenêtre. C'est le chemin qu'emprunte déjà la killcam.
##
## ⚠️ **Cacher une vue ne suffit pas : l'INTERFACE ne suit pas.** Elle se range
## sur le MODE RÉSEAU (`ui.disposer_hud`), pas sur le nombre de vues affichées —
## et le mode reste « écran scindé » ici, puisqu'on ne peut pas monter un lien
## réseau depuis un outil. Sans les deux lignes qui suivent, on obtenait un monde
## en vue unique sous un HUD à deux panneaux, et surtout **un voile
## d'éblouissement large d'une demi-fenêtre planté au milieu du cadre** — une
## configuration qui n'existe nulle part dans le jeu.
##
## Ce qu'on reproduit ici est donc la configuration du duel EN LIGNE, à la main.
## Le risque est nommé : un réglage d'interface ajouté demain et dérivé du mode
## réseau ne suivra pas non plus, et il faudra l'ajouter ici.
func _vue_unique() -> void:
	var c2 := _main.vp2.get_parent() as Control
	if c2 != null:
		c2.hide()
	_ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	_ui._voile_scinde = false
	if _ui.hud_panneau_p2 != null:
		_ui.hud_panneau_p2.visible = false
	if _sans_hud and _ui.match_hud != null:
		_ui.match_hud.hide()

## Le retour à l'écran scindé passe par `disposer_hud()` et non par des lignes
## symétriques : c'est le jeu qui sait comment se ranger, et le lui redemander
## coûte moins qu'entretenir une seconde version de son rangement.
func _deux_vues() -> void:
	var c2 := _main.vp2.get_parent() as Control
	if c2 != null:
		c2.show()
	_ui.center_line.show()
	_main._accorder_rendu_aux_vues()
	_ui.disposer_hud(false)
	if _sans_hud and _ui.match_hud != null:
		_ui.match_hud.hide()

## Installe les marionnettes sur les deux joueurs. À rappeler après CHAQUE
## démarrage de manche : `_do_start_round` repose les fournisseurs du mode, et
## une marionnette posée avant serait remplacée sans bruit.
func _prendre_les_commandes() -> void:
	_pantins.clear()
	for j in [_main.p1, _main.p2]:
		if not is_instance_valid(j):
			continue
		var pantin := Marionnette.new()
		pantin.name = "MarionnetteDuPhotographe"
		pantin.visee = VISEE.normalized()
		_main._set_player_input_provider(j, pantin)
		_pantins.append(pantin)


func _torches(actives: bool) -> void:
	for pantin in _pantins:
		pantin.torche = actives
	# Les actions restent pressées en plus des marionnettes : l'entraînement et
	# la killcam peuvent reposer un `LocalInputProvider` sous nos pieds, et une
	# torche qui s'éteint au milieu d'un plan ne se voit qu'à l'image.
	for action in ["p1_torch", "p2_torch"]:
		if actives:
			Input.action_press(action)
		else:
			Input.action_release(action)
	for j in [_main.p1, _main.p2]:
		if is_instance_valid(j) and not actives:
			j.flashlight_on = false


## Replace J2 à `rayon` px de J1, à `ecart` radians de son axe de visée — pour
## UNE image.
##
## Replacé à chaque image et non orienté une fois : la visée de J1 retombe sur la
## souris, qui bouge le joueur à chaque image. On suit sa direction au lieu de la
## combattre — le cadrage ne dépend alors ni de la carte ni du curseur.
## ⚠️ **J2 ne regarde PAS J1, et c'est une décision de mise en scène.** Le
## premier jet le retournait face à face (`+ PI`) : deux torches braquées à bout
## portant, donc **deux joueurs éblouis à saturation**, donc un écran scindé
## entièrement laiteux et un duel noyé de blanc. C'était du jeu authentique, et
## une image illisible. J2 regarde donc de côté — la situation qu'on montre est
## celle où l'on surprend quelqu'un, ce qui est aussi la plus juste : la fiche du
## jeu dit « être vu, c'est être mort », pas « se regarder ».
func _duel(rayon: float, ecart: float, cap: float = PI * 0.55) -> void:
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2):
		return
	var axe: Vector2 = _main.p1.global_transform.x.rotated(ecart)
	_main.p2.global_position = _main.p1.global_position + axe * rayon
	_main.p2.rotation = _main.p1.rotation + cap
	_vivants()


## Les deux joueurs restent debout de force. Une séance qui perd son sujet en
## route rend des images noires sans jamais dire pourquoi.
func _vivants() -> void:
	for j in [_main.p1, _main.p2]:
		if is_instance_valid(j) and not j.dead:
			j.hp = 100.0
	# Le cadrage choisi par le photographe, réappliqué à CHAQUE image et non posé
	# une fois : encaisser un coup dézoome brièvement la caméra du blessé (V4.6),
	# et une valeur posée d'avance aurait fondu au premier tir du plan « sang ».
	#
	# ⚠️ Par défaut il vaut 1,0, c'est-à-dire le cadrage du joueur. `--zoom` est
	# un geste de photographe, pas un réglage du jeu : le manifeste l'inscrit
	# pour qu'une image serrée ne se fasse jamais passer pour une capture.
	if not is_equal_approx(_zoom, 1.0):
		for cam in [_main.cam1, _main.cam2]:
			if is_instance_valid(cam):
				cam.zoom = Vector2(_zoom, _zoom)


## Rapproche J1 du mur le plus proche dans son axe, pour que la rétrodiffusion
## ait quelque chose à éclairer.
func _approcher_un_mur() -> void:
	if not is_instance_valid(_main.p1):
		return
	var depart: Vector2 = _main.p1.global_position
	var espace: PhysicsDirectSpaceState2D = _main.p1.get_world_2d().direct_space_state
	var meilleur := depart
	var plus_court := INF
	for i in 24:
		var a := TAU * float(i) / 24.0
		var vers: Vector2 = depart + Vector2.RIGHT.rotated(a) * 900.0
		var q := PhysicsRayQueryParameters2D.create(depart, vers, MapGeometry.WALL_LAYER)
		q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
		var coup: Dictionary = espace.intersect_ray(q)
		if coup.is_empty():
			continue
		var d: float = depart.distance_to(coup["position"])
		if d < plus_court and d > 90.0:
			plus_court = d
			meilleur = coup["position"] - Vector2.RIGHT.rotated(a) * 85.0
	if plus_court < INF:
		_main.p1.global_position = meilleur


# ---------------------------------------------------------------------------
# LA PRISE
# ---------------------------------------------------------------------------

## Photographie l'état courant. `tenir` est appelée à CHAQUE image du repos :
## c'est par elle qu'on garde une position, un éblouissement ou un décompte.
##
## Un repos nul saute l'attente entièrement — pour les états qui ne durent qu'un
## dixième de seconde, comme l'éclat de bouche.
func _prendre(plan: Dictionary, tenir := Callable(), repos := -1.0) -> void:
	if plan.is_empty():
		return
	var duree: float = _repos if repos < 0.0 else repos
	var fin := Time.get_ticks_msec() + int(duree * 1000.0)
	while Time.get_ticks_msec() < fin:
		if tenir.is_valid():
			tenir.call()
		await get_tree().process_frame
	if tenir.is_valid():
		tenir.call()
	var img: Image = await _capturer(String(plan.get("source", "ecran")))
	if img == null:
		printerr("  ✗ %s : aucune image (fenêtre au second plan ?)" % plan["id"])
		_perdues += 1
		return
	_ecrire(plan, img)


## Prend le plan `id` s'il est demandé — le raccourci des états déjà en place.
func _peut_etre(plans: Array[Dictionary], id: String) -> void:
	await _prendre(_plan(plans, id))


## L'image de la frame réellement affichée, dans la source demandée.
##
## L'attente porte toujours sur l'ÉCRAN, même quand on veut la vue : c'est le
## seul signal qui dise « une image vient d'être dessinée », et c'est aussi lui
## qui détecte une fenêtre bridée par macOS. Une prise manquée est retentée une
## fois — la fenêtre remise devant entre les deux — puis abandonnée.
func _capturer(source: String) -> Image:
	if source == "vue":
		return await _capturer_la_vue()
	_au_premier_plan()
	var ecran: Image = await Commun.capturer(get_tree(), 3000)
	if ecran == null:
		_au_premier_plan()
		await _attendre_images(4)
		ecran = await Commun.capturer(get_tree(), 4000)
	return ecran


## La vue seule, SURÉCHANTILLONNÉE pour rendre la même définition que l'écran.
##
## ⚠️ **Sans ce détour, `--taille=3840x2160` rendait des plans `vue` en
## 1920×1080, et rien ne le disait.** Découvert le 2026-09-09 en fournissant des
## images à la session DA7 : le manifeste portait bien les deux tailles — il
## n'invente rien — mais la ligne « fenêtre : 3840x2160 » de la console laissait
## croire que tout sortait en 4K. **Le pire des trois états connus : ni faux, ni
## dit.**
##
## La cause tient au mode d'étirement du jeu. En `canvas_items`, la mise en page
## vit à la résolution de RÉFÉRENCE (1920×1080) et la fenêtre n'est qu'un facteur
## d'échelle appliqué au dessin. Un `SubViewportContainer` en `stretch` accorde
## donc sa sous-vue à sa taille de *Control* — 1920×1080 — quelle que soit la
## fenêtre. La racine, elle, rastérise pour de bon à 3840×2160.
##
## Le remède est celui d'un photographe qui change d'objectif : on coupe
## l'accord automatique, on agrandit la sous-vue du facteur manquant, **et on
## multiplie le zoom de la caméra d'autant** — sans quoi on ne gagnerait pas de
## définition, on verrait seulement plus de monde. Le temps de deux images, puis
## tout est remis en place.
func _capturer_la_vue() -> Image:
	var vue: SubViewport = _main.vp1
	var conteneur := vue.get_parent() as SubViewportContainer
	var cam: Camera2D = _main.cam1
	var facteur := _facteur_de_vue(vue)

	var taille_avant := vue.size
	var stretch_avant := conteneur.stretch if conteneur != null else true
	var zoom_avant: Vector2 = cam.zoom if is_instance_valid(cam) else Vector2.ONE
	if facteur > 1 and conteneur != null:
		conteneur.stretch = false
		vue.size = taille_avant * facteur
		if is_instance_valid(cam):
			cam.zoom = zoom_avant * float(facteur)
		await _attendre_images(2)

	_au_premier_plan()
	var ecran: Image = await Commun.capturer(get_tree(), 3000)
	if ecran == null:
		_au_premier_plan()
		await _attendre_images(4)
		ecran = await Commun.capturer(get_tree(), 4000)

	var img: Image = null
	if ecran != null:
		var t: ViewportTexture = vue.get_texture()
		img = t.get_image() if t != null else null

	# Rendu AVANT tout retour, y compris sur une prise perdue : une sous-vue
	# laissée en 4K sans étirement afficherait le quart supérieur gauche du duel
	# pour tous les plans suivants.
	if facteur > 1 and conteneur != null:
		vue.size = taille_avant
		conteneur.stretch = stretch_avant
		if is_instance_valid(cam):
			cam.zoom = zoom_avant
		await _attendre_images(1)
	return img if img != null else ecran


## De combien la sous-vue est en retard sur la fenêtre. Entier : un facteur
## fractionnaire rééchantillonnerait la carte au lieu de la rendre plus fin, ce
## qui est l'inverse du but.
func _facteur_de_vue(vue: SubViewport) -> int:
	if vue == null or vue.size.y <= 0:
		return 1
	var fenetre := DisplayServer.window_get_size()
	return clampi(int(round(float(fenetre.y) / float(vue.size.y))), 1, 4)


## macOS bride le rendu d'une fenêtre au second plan, au point que
## `frame_post_draw` cesse d'être émis. On la remet devant plutôt que d'attendre
## une image qui ne viendra pas.
func _au_premier_plan() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()


## Écrit l'image, ses découpes, et la ligne de manifeste qui va avec.
func _ecrire(plan: Dictionary, img: Image) -> void:
	if plan.is_empty() or img == null:
		return
	var famille := String(plan["famille"])
	var rang: int = int(_rangs.get(famille, 0)) + 1
	_rangs[famille] = rang
	var base := "%02d-%s" % [rang, plan["id"]]
	var dossier := "%s/%s" % [_dossier, famille]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	img.save_png("%s/%s.png" % [dossier, base])

	var fiche := {
		"id": plan["id"], "famille": famille,
		"titre": plan.get("titre", plan["id"]),
		"pourquoi": plan.get("pourquoi", ""),
		"note": plan.get("note", ""),
		"source": plan.get("source", "ecran"),
		"fichier": "%s/%s.png" % [famille, base],
		"largeur": img.get_width(), "hauteur": img.get_height(),
		"decoupes": {},
	}
	if _decoupes:
		var ancre := Vector2(0.5, 0.5)
		if plan.has("ancre"):
			var a: Array = plan["ancre"]
			ancre = Vector2(float(a[0]), float(a[1]))
		for cas in [["carre", 1.0], ["vertical", 9.0 / 16.0]]:
			var coupe := _decouper(img, float(cas[1]), ancre)
			if coupe == null:
				continue
			var nom := "%s@%s.png" % [base, cas[0]]
			coupe.save_png("%s/%s" % [dossier, nom])
			fiche["decoupes"][cas[0]] = "%s/%s" % [famille, nom]
	_photos.append(fiche)
	var note := String(plan.get("note", ""))
	print("  · %-34s %s" % [base, note])


## Le plus grand rectangle du rapport demandé qui tienne dans l'image, centré sur
## l'ancre puis ramené dans le cadre. **Recadrer plutôt que rendre à un autre
## rapport**, et ce n'est pas de la paresse : le jeu s'étire en `canvas_items`
## depuis une référence 16:9, et lui demander un format carré ajouterait des
## bandes noires ou déformerait le monde. Un photographe recadre.
func _decouper(img: Image, rapport: float, ancre: Vector2) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return null
	var lw := w
	var lh := h
	if float(w) / float(h) > rapport:
		lw = int(round(float(h) * rapport))
	else:
		lh = int(round(float(w) / rapport))
	var x := clampi(int(round(ancre.x * float(w))) - lw / 2, 0, w - lw)
	var y := clampi(int(round(ancre.y * float(h))) - lh / 2, 0, h - lh)
	return img.get_region(Rect2i(x, y, lw, lh))


# ---------------------------------------------------------------------------
# LE MANIFESTE ET LA PLANCHE
# ---------------------------------------------------------------------------

## Ce que chaque image montre, à quoi elle sert, et de quel code elle sort.
##
## **L'empreinte git n'est pas de la coquetterie** : une image de communication
## survit des mois à la version qui l'a produite, et « de quand date cette
## capture » est la première question posée quand elle finit par jurer avec le
## jeu. Elle est lue, jamais inventée — et son absence est dite plutôt que
## remplacée par un blanc.
func _ecrire_le_manifeste() -> void:
	var manifeste := {
		"format": 1,
		"genere_le": Time.get_datetime_string_from_system(true),
		"version_du_jeu": ProjectSettings.get_setting("application/config/version", "?"),
		"commit": _commit(),
		"taille_demandee": [_taille.x, _taille.y],
		"decoupes": _decoupes,
		"sans_hud": _sans_hud,
		"zoom": _zoom,
		"photos": _photos,
	}
	var f := FileAccess.open("%s/manifeste.json" % _dossier, FileAccess.WRITE)
	if f == null:
		printerr("  ! manifeste non écrit : ", error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(manifeste, "\t"))
	f.close()


func _commit() -> String:
	var sortie: Array = []
	var code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"),
		"rev-parse", "--short", "HEAD"], sortie, true)
	if code != 0 or sortie.is_empty():
		return ""
	return String(sortie[0]).strip_edges()


## La planche : une page qu'on ouvre d'un double-clic, pas un dossier qu'on trie.
##
## C'est la même conviction que la planche de contact — **ce qui change tout,
## c'est le coût de regarder**. Trente images dans un dossier se regardent une
## par une ; les mêmes sur une page se comparent d'un coup d'œil, et c'est la
## comparaison qui fait choisir.
func _ecrire_la_planche() -> void:
	var h := "<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\">"
	h += "<title>Candela — planche photo</title><style>"
	h += "body{background:#0b0b0d;color:#e8e4dc;font:14px/1.5 system-ui,sans-serif;margin:0;padding:32px}"
	h += "h1{font-size:22px;letter-spacing:.14em;text-transform:uppercase;margin:0 0 4px}"
	h += ".meta{color:#8a8378;font-size:12px;margin-bottom:32px}"
	h += "h2{font-size:13px;letter-spacing:.2em;text-transform:uppercase;color:#c9a227;"
	h += "border-bottom:1px solid #2a2a2e;padding-bottom:8px;margin:40px 0 16px}"
	h += ".g{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:20px}"
	h += "figure{margin:0;background:#141416;border:1px solid #24242a;border-radius:4px;overflow:hidden}"
	h += "img{width:100%;display:block;background:#000}"
	h += "figcaption{padding:10px 12px}"
	h += ".t{font-weight:600}.p{color:#9a9389;font-size:12px;margin-top:4px}"
	h += ".f{color:#5f5b54;font-size:11px;margin-top:6px;font-family:ui-monospace,monospace}"
	h += "</style></head><body>"
	# Le zoom est DIT sur la planche quand il n'est pas neutre. Une image serrée
	# n'est plus tout à fait une capture, et rien d'autre ne le signalerait.
	var mention := ""
	if not is_equal_approx(_zoom, 1.0):
		mention = " · cadrage serré ×%.2f" % _zoom
	if _sans_hud:
		mention += " · sans HUD"
	h += "<h1>Candela — planche photo</h1><div class=\"meta\">%s · version %s%s%s · %d image(s)</div>" % [
		Time.get_datetime_string_from_system(),
		ProjectSettings.get_setting("application/config/version", "?"),
		(" · " + _commit()) if _commit() != "" else "",
		mention, _photos.size()]
	for famille in FAMILLES:
		var lot: Array[Dictionary] = []
		for p in _photos:
			if p["famille"] == famille:
				lot.append(p)
		if lot.is_empty():
			continue
		h += "<h2>%s</h2><div class=\"g\">" % famille
		for p in lot:
			var titre := String(p["titre"])
			if String(p.get("note", "")) != "":
				titre += " — " + String(p["note"])
			h += "<figure><img src=\"%s\" alt=\"%s\" loading=\"lazy\">" % [
				p["fichier"], titre.xml_escape()]
			h += "<figcaption><div class=\"t\">%s</div>" % titre.xml_escape()
			h += "<div class=\"p\">%s</div>" % String(p["pourquoi"]).xml_escape()
			h += "<div class=\"f\">%s · %d×%d</div></figcaption></figure>" % [
				p["fichier"], p["largeur"], p["hauteur"]]
		h += "</div>"
	h += "</body></html>"
	var f := FileAccess.open("%s/planche.html" % _dossier, FileAccess.WRITE)
	if f == null:
		printerr("  ! planche non écrite : ", error_string(FileAccess.get_open_error()))
		return
	f.store_string(h)
	f.close()


# ---------------------------------------------------------------------------
# LA MENUISERIE
# ---------------------------------------------------------------------------

func _poser_la_fenetre() -> void:
	_au_premier_plan()
	var ecran := DisplayServer.screen_get_size()
	var voulue := _taille
	if ecran.x > 0 and ecran.y > 0:
		voulue = Vector2i(mini(voulue.x, ecran.x), mini(voulue.y, ecran.y))
	if voulue != _taille:
		printerr("  ! %dx%d ne tient pas sur cet écran (%dx%d) : ramené à %dx%d" % [
			_taille.x, _taille.y, ecran.x, ecran.y, voulue.x, voulue.y])
	DisplayServer.window_set_size(voulue)
	var reelle := DisplayServer.window_get_size()
	print("  fenêtre : %dx%d (demandé %dx%d)" % [reelle.x, reelle.y, _taille.x, _taille.y])
	# La mise en page du jeu vit à la résolution de référence ; au-delà, les
	# plans `vue` sont suréchantillonnés pour rejoindre l'écran. On le DIT, parce
	# que c'est le genre d'écart qu'un manifeste porte sans que personne le lise.
	var reference: Vector2i = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))
	if reelle.y > reference.y:
		print("  la mise en page vit en %dx%d : les plans `vue` sont suréchantillonnés ×%d"
			% [reference.x, reference.y,
			clampi(int(round(float(reelle.y) / float(reference.y))), 1, 4)])
	_taille = reelle


func _preparer_le_dossier() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	# On efface la séance précédente : deux passages superposés donneraient un
	# dossier où la moitié des images date d'une autre version du jeu, sans que
	# rien ne le dise. Le manifeste, lui, ne décrirait que les nouvelles.
	for famille in FAMILLES:
		var d := DirAccess.open("%s/%s" % [_dossier, famille])
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".png"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(
					"%s/%s/%s" % [_dossier, famille, f]))


func _attendre(predicat: Callable, plafond: float) -> bool:
	var fin := Time.get_ticks_msec() + int(plafond * 1000.0)
	while Time.get_ticks_msec() < fin:
		# ⚠️ **Un `Callable` dont une capture a été libérée n'est plus
		# appelable**, et l'appeler quand même tue la coroutine SUR PLACE : pas
		# d'exception qu'on puisse rattraper, pas de valeur de retour, la
		# fonction ne reprend simplement jamais après son `await`. Le garde ne
		# répare rien — il transforme une mort silencieuse en refus visible, et
		# c'est la seule chose qui distingue un outil cassé d'un outil muet.
		if not predicat.is_valid():
			printerr("  ! attente abandonnée : la condition a perdu une de ses "
				+ "captures (voir `_attendre_disparition`)")
			return false
		if predicat.call():
			return true
		await get_tree().process_frame
	return false


## Attendre qu'un nœud DISPARAISSE — sans le capturer.
##
## ⚠️ **C'est le piège le plus retors de ce fichier, et il s'est payé le
## 2026-09-09 sur la famille `fins`.** Écrire l'attente comme on la pense :
##
## ```gdscript
## await _attendre(func() -> bool: return not is_instance_valid(affiche), 3.0)
## ```
##
## capture `affiche` dans la lambda. Quand le nœud est enfin libéré — c'est-à-dire
## **au moment précis où la condition devient vraie** — Godot invalide le
## `Callable` entier :
##
## ```
## ERROR: Lambda capture at index 0 was freed. Passed "null" instead.
## ```
##
## et la coroutine meurt là, sans un mot. **La condition attendue détruit le
## moyen de la tester.** L'attente ne rend jamais faux, ne rend jamais vrai : la
## fonction appelante ne reprend pas, et tout ce qui suit dans la famille n'est
## jamais photographié. Symptôme observé : le repère de début imprimé, jamais
## celui de fin ; `affiche` et les trois verdicts absents du dossier sans un
## seul message d'erreur du photographe.
##
## Le remède tient à ce qu'on capture : **un identifiant d'instance est un
## entier**, et un entier ne se libère pas.
func _attendre_disparition(noeud: Object, plafond: float) -> bool:
	if noeud == null or not is_instance_valid(noeud):
		return true
	var id := noeud.get_instance_id()
	return await _attendre(func() -> bool: return not is_instance_id_valid(id), plafond)


func _attendre_images(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Les plans retenus, sous forme d'ensemble d'identifiants.
func _selection(args: PackedStringArray) -> Array[Dictionary]:
	var familles := _valeur(args, "--famille", "").strip_edges()
	var ids := _valeur(args, "--plan", "").strip_edges()
	var out: Array[Dictionary] = []
	for plan in catalogue():
		var garde := true
		if familles != "":
			garde = familles.split(",").has(String(plan["famille"]))
		if garde and ids != "":
			garde = ids.split(",").has(String(plan["id"]))
		if garde:
			out.append(plan)
	return out


func _plans_de(choisis: Array[Dictionary], famille: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in choisis:
		if p["famille"] == famille:
			out.append(p)
	return out


func _plan(plans: Array[Dictionary], id: String) -> Dictionary:
	for p in plans:
		if p["id"] == id:
			return p
	return {}


func _demande(plans: Array[Dictionary], id: String) -> bool:
	return not _plan(plans, id).is_empty()


## Une image d'un lot : même fiche que le plan, un identifiant suffixé et une
## note qui dit ce qu'on regarde. Sans la note, un lot de quinze images oblige à
## deviner laquelle est laquelle.
func _derive(plans: Array[Dictionary], id: String, suffixe: String,
		note: String) -> Dictionary:
	var base := _plan(plans, id)
	if base.is_empty():
		return {}
	var copie := base.duplicate(true)
	copie["id"] = "%s-%s" % [id, suffixe]
	copie["note"] = note
	return copie


## Le libellé d'une entrée de menu. **Il n'est pas dans `Button.text`** : le hub
## compose chaque entrée d'une rangée de `Label` (le nom, le chevron « › », le
## tiret des entrées désactivées), et le bouton lui-même reste muet. Sans ce
## détour, toutes les rubriques sortaient sous le nom « sans-nom » — cinq
## fichiers qu'il fallait ouvrir un par un pour savoir lequel montrait quoi.
##
## La traversée est celle de `MenuHub.set_entry_label()`, et pour cause : c'est
## elle qui écrit ce qu'on relit ici.
func _libelle(btn: Button) -> String:
	if btn == null:
		return ""
	for rangee in btn.get_children():
		for enfant in rangee.get_children():
			var lbl := enfant as Label
			if lbl != null and not String(lbl.text) in ["›", "—", ""]:
				return String(lbl.text).strip_edges()
	return String(btn.text).strip_edges()


## Un nom de fichier sûr : minuscules, accents retirés, tout le reste en tirets.
func _ardoise(texte: String) -> String:
	var s := texte.strip_edges().to_lower()
	var avant := "àâäáãçéèêëíìîïñóòôöõúùûüýÿ"
	var apres := "aaaaaceeeeiiiinooooouuuuyy"
	var out := ""
	for c in s:
		var i := avant.find(c)
		if i >= 0:
			out += apres[i]
		elif (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		else:
			out += "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	out = out.trim_prefix("-").trim_suffix("-")
	return out if out != "" else "sans-nom"


## Les illustrations livrées, lues sur le disque et non recopiées dans une liste.
## Une liste écrite ici se périmerait à la première planche ajoutée, en silence.
func _illustrations() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open("res://assets/ui")
	if d == null:
		return out
	for f in d.get_files():
		var nom := f.get_basename()
		# `.import` et `.png` désignent le même fichier : on ne garde qu'une clé.
		if not f.ends_with(".png"):
			continue
		if nom.begins_with("ill_") or nom == "apercu_personnalisation":
			out.append("res://assets/ui/%s" % f)
	out.sort()
	return out


func _nom_arme(arme: WeaponData) -> String:
	return arme.name if arme != null and arme.name != "" else "Pistolet"


func _lire_taille(texte: String) -> Vector2i:
	var bouts := texte.to_lower().split("x")
	if bouts.size() != 2 or not bouts[0].is_valid_int() or not bouts[1].is_valid_int():
		printerr("  ! --taille=%s illisible : %dx%d retenu" % [
			texte, TAILLE_DEFAUT.x, TAILLE_DEFAUT.y])
		return TAILLE_DEFAUT
	return Vector2i(maxi(320, int(bouts[0])), maxi(240, int(bouts[1])))


func _drapeau(args: PackedStringArray, nom: String) -> bool:
	for a in args:
		if a == nom:
			return true
	return false


func _valeur(args: PackedStringArray, nom: String, defaut: String) -> String:
	for i in args.size():
		if args[i] == nom and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with(nom + "="):
			return args[i].substr(nom.length() + 1)
	return defaut


func _imprimer_catalogue() -> void:
	print("=== Le photographe — catalogue ===\n")
	for famille in FAMILLES:
		print("--- %s ---" % famille)
		for plan in catalogue():
			if plan["famille"] != famille:
				continue
			var marque := " (lot)" if plan.get("lot", false) else ""
			print("  %-20s [%s]%s  %s" % [plan["id"], plan["source"], marque,
				plan["titre"]])
			print("  %-20s %s" % ["", plan["pourquoi"]])
		print("")
	print("--famille=<%s>" % "|".join(FAMILLES))
	print("--plan=<identifiant>[,<identifiant>…]")


## Sortir par la porte du jeu : `main.tscn` instancie les autoloads EOS, et
## quitter sec ré-entre dans `EOS_Platform_Tick()` — segfault documenté.
func _sortir(code: int) -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
		return
	get_tree().quit(code)
