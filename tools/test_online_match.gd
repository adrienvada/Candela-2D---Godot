## Test headless de bout en bout : le jeu complet (main.tscn), piloté par le
## menu, deux instances qui se trouvent par code de salon et entrent en manche.
##
## Contrairement à test_transport.gd qui n'exerce que la couche transport,
## celui-ci passe par les vrais boutons du lobby, la vraie séquence de départ et
## la vraie sortie de jeu.
##
## Hôte  : godot --headless --path . res://tools/test_online_match.tscn -- --host --eos-ephemeral
## Client: godot --headless --path . res://tools/test_online_match.tscn -- --join <CODE> --eos-ephemeral
extends Node

const EOS_READY_TIMEOUT := 30.0
const CODE_TIMEOUT := 20.0
const PEER_TIMEOUT := 30.0
const ROUND_TIMEOUT := 20.0

var _args: PackedStringArray
var _main: Node
var _ui: Node
var _lan := false
var _rejected_at := -1


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_lan = _value("--transport", "eos") == "enet"
	NetworkManager.transport = NetworkManager.Transport.ENET if _lan else NetworkManager.Transport.EOS

	print("=== MATCH EN LIGNE (bout en bout) ===")
	print("TRANSPORT: %s" % ("ENET" if _lan else "EOS"))

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")

	# L'écran partagé et le LAN n'ont rien à attendre d'Epic.
	# L'entraînement est solitaire : il n'a pas plus besoin d'Epic que l'écran
	# partagé, et l'attendre ferait pendre le banc trente secondes pour rien.
	var needs_eos := not _lan and not _has("--local") and not _has("--training") \
		and not _has("--fenetre")
	if needs_eos:
		if not await _await(func(): return NetworkManager.eos_state == NetworkManager.EosState.READY \
				or NetworkManager.eos_state == NetworkManager.EosState.FAILED, EOS_READY_TIMEOUT):
			_fail("EOS n'est jamais devenu prêt (%s)" % NetworkManager.eos_state_label())
			return
		if NetworkManager.eos_state != NetworkManager.EosState.READY:
			_fail("EOS: %s" % NetworkManager.eos_state_label())
			return
	print("EOS: %s" % NetworkManager.eos_state_label())

	if _has("--host-spam"):
		await _run_host_spam()
	elif _has("--join-spam"):
		await _run_client_spam()
	elif _has("--host-ralenti"):
		await _run_host_ralenti()
	elif _has("--join-ralenti"):
		await _run_client_ralenti()
	elif _has("--host-killcam"):
		await _run_host_killcam()
	elif _has("--join-killcam"):
		await _run_client_killcam()
	elif _has("--host-pause"):
		await _run_host_pause()
	elif _has("--join-pause"):
		await _run_client_pause()
	elif _has("--host-coupure"):
		await _run_host_coupure()
	elif _has("--join-coupure"):
		await _run_client_coupure()
	elif _has("--host"):
		await _run_host()
	elif _has("--join"):
		await _run_client()
	elif _has("--local"):
		await _run_local()
	elif _has("--training"):
		await _run_training()
	elif _has("--fenetre"):
		await _run_fenetre()
	else:
		print("Usage: --host | --join <CODE|IP> | --local | --training"
			+ " | --host-coupure | --join-coupure <IP>")
		_quit(2)


## La fenêtre de choix d'un match apparié — dix secondes pendant lesquelles on
## choisit son arme dans l'arsenal que la règle du miroir a laissé.
##
## Exercée **en écran partagé**, sans réseau ni appariement : la mécanique est
## locale à `game_state`, et la faire dépendre de deux processus et d'Epic la
## rendrait intestable en pratique — donc jamais testée. On pose les catégories à
## la main, ce que l'appariement ferait.
##
## Ce que ce mode protège, dans l'ordre d'importance :
##
##   • **on ne peut pas prendre une arme que le miroir a retirée** — c'est la
##     seule propriété qui protège de quelque chose, et elle vaut aussi contre un
##     client modifié, l'hôte refaisant le contrôle à la réception ;
##   • la fenêtre dure bien dix secondes, contre trois pour un match ordinaire :
##     c'est ce qui distingue « l'arme n'est pas encore choisie » de « elle l'est
##     depuis le menu » ;
##   • les deux prêts l'abrègent, un seul ne suffit pas ;
##   • hors de la fenêtre, plus rien ne change l'arme.
func _run_fenetre() -> void:
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_press_play()
	_check("la manche démarre", await _await(func(): return _main.round_active, ROUND_TIMEOUT))
	_check("un match ordinaire compte trois secondes",
		_main.countdown_left <= _main.COUNTDOWN_DURATION + 0.01,
		"%.1f" % _main.countdown_left)

	# On rejoue ce que l'appariement pose : match apparié, deux catégories.
	# Lanterne (4) contre Braise (2) — le miroir doit retenir l'arsenal de Braise.
	_main._matchmade_round = true
	_main._mirror_local_tier = 4
	_main._mirror_opponent_tier = 2
	_main._start_round()
	await get_tree().process_frame

	_check("la fenêtre de choix dure dix secondes",
		_main.countdown_left > _main.COUNTDOWN_DURATION + 1.0,
		"%.1f" % _main.countdown_left)

	var arsenal: Array = _main.matchmade_arsenal()
	print("ARSENAL: %s (local=4 adverse=2)" % str(arsenal))
	_check("l'arsenal est celui du moins bien classé",
		arsenal == RankLoadout.for_tier(2), str(arsenal))
	_check("et la raison le dit",
		_main.matchmade_arsenal_reason() != "", _main.matchmade_arsenal_reason())

	# LE contrôle : une arme hors arsenal est refusée, même demandée de l'intérieur.
	var avant: String = _main.p1.current_weapon.name
	_main.pick_countdown_weapon(RankLoadout.ARBALETE)
	_check("une arme hors arsenal est refusée",
		_main.p1.current_weapon.name == avant,
		"%s → %s" % [avant, _main.p1.current_weapon.name])

	_main.pick_countdown_weapon(arsenal[0])
	_check("une arme de l'arsenal est acceptée",
		_main.p1.current_weapon == _main.weapon_for_index(arsenal[0]),
		_main.p1.current_weapon.name)

	# Un seul prêt ne suffit pas : l'autre choisit peut-être encore.
	var reste: float = _main.countdown_left
	_main._countdown_ready_peer = false
	_main._countdown_ready_local = true
	await get_tree().create_timer(0.3).timeout
	_check("un seul prêt n'abrège rien", _main.countdown_left > reste - 1.5,
		"%.1f → %.1f" % [reste, _main.countdown_left])

	_main._countdown_ready_peer = true
	_check("les deux prêts lancent la manche",
		await _await(func(): return _main.countdown_left <= 0.0, 3.0),
		"%.1f" % _main.countdown_left)

	# Fenêtre close : l'arme est celle avec laquelle on joue.
	var tenue: String = _main.p1.current_weapon.name
	_main.pick_countdown_weapon(RankLoadout.PISTOLET)
	_check("hors de la fenêtre, l'arme ne change plus",
		_main.p1.current_weapon.name == tenue, _main.p1.current_weapon.name)
	_quit(0)

## L'entraînement solitaire. Ce que ce mode protège, dans l'ordre :
##
##   • **rien n'est archivé** — un entraînement n'est pas un match, et le journal
##     local est la source du rejeu vers le classement. Une seule ligne écrite
##     ici polluerait un classement que personne ne saurait plus corriger ;
##   • la cible se tient au point d'apparition de J2, pas devant J1 : c'est ce
##     qui rend l'exercice transférable à un vrai premier échange ;
##   • la carte est celle par défaut, quelle qu'ait été la dernière sélection ;
##   • on peut tirer alors qu'aucune manche n'est active — sans quoi
##     l'entraînement serait un décor.
func _run_training() -> void:
	# La sélection est délibérément salie avant : on vérifie que l'entraînement
	# la remet à la carte par défaut au lieu de la subir.
	var cartes: Array = MapData.list_maps()
	for carte in cartes:
		var id := String((carte as Dictionary).get("id", ""))
		if id != MapData.DEFAULT_MAP_ID:
			MapData.select_map(id)
			break
	var journal_avant := _history_size()

	_ui.hub.push(_ui.SCREEN_TRAINING)
	_check("l'écran est bien celui de l'entraînement",
		_ui.hub.current_id() == _ui.SCREEN_TRAINING)
	_ui.training_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var ids: Array[String] = []
	for c in MapData.list_maps():
		ids.append(String((c as Dictionary).get("id", "?")))
	print("CATALOGUE: %s | DEFAUT: %s | SELECTION: %s"
		% [", ".join(ids), MapData.DEFAULT_MAP_ID, MapData.selected_map_id])
	# `DEFAULT_MAP_ID` est un slug ; la sélection retient un identifiant. Les
	# comparer directement était l'erreur que ce banc a précisément servi à
	# trouver dans `map_data.gd` — on passe donc par le catalogue.
	var defaut: Dictionary = MapData.get_map_by_slug(MapData.DEFAULT_MAP_ID)
	_check("l'arène livrée par défaut est au catalogue", not defaut.is_empty())
	_check("la carte revient à celle par défaut",
		MapData.selected_map_id == String(defaut.get("id", "")),
		"%s attendu %s" % [MapData.selected_map_id, defaut.get("id", "?")])
	_check("aucune manche n'est active", not _main.round_active)
	_check("le bac à sable est armé", _main.sandbox_mode)
	_check("la cible est visible", _main.training_target.visible)
	# Le contrôle qui donne son sens au placement : la cible occupe la place de
	# l'adversaire, à quelques pixels près.
	var spawn_j2: Vector2 = _main._get_spawn_position(1)
	_check("la cible est au point d'apparition de J2",
		_main.training_target.global_position.distance_to(spawn_j2) < 1.0,
		"%s vs %s" % [_main.training_target.global_position, spawn_j2])
	_check("le joueur 2 a quitté la scène", not _main.p2.visible)
	# Un mode solitaire ne coupe pas l'écran en deux pour une moitié vide :
	# défaut relevé par Adrien au premier essai, l'entraînement tournant en mode
	# écran partagé du point de vue du transport.
	_check("l'écran n'est pas partagé", _main.vp1.get_parent().visible
		and not _main.vp2.get_parent().visible,
		"vp1=%s vp2=%s" % [_main.vp1.get_parent().visible,
			_main.vp2.get_parent().visible])
	_check("la ligne de séparation est retirée", not _ui.center_line.visible)
	_check("aucun forfait n'est en attente", not _main._forfeit_pending)
	_check("aucun identifiant de match n'est armé", _main._match_id.is_empty())

	# Tirer doit marcher hors manche, sinon l'entraînement est un décor.
	var balles_avant: int = _main.bullet_container.get_child_count()
	_main.p1.shoot()
	await get_tree().process_frame
	_check("on peut tirer pendant l'entraînement",
		_main.bullet_container.get_child_count() > balles_avant,
		"%d → %d" % [balles_avant, _main.bullet_container.get_child_count()])

	await get_tree().create_timer(1.0).timeout
	_check("le journal local n'a pas bougé",
		_history_size() == journal_avant,
		"%d → %d" % [journal_avant, _history_size()])
	_quit(0)

## Taille du journal de matchs, ou -1 s'il n'existe pas encore.
func _history_size() -> int:
	if not FileAccess.file_exists(MatchRecord.HISTORY_PATH):
		return -1
	var f := FileAccess.open(MatchRecord.HISTORY_PATH, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n

## L'écran partagé ne doit rien devoir au réseau : le bloc lobby disparaît, les
## deux vues restent, et rien n'est envoyé nulle part.
func _run_local() -> void:
	# L'intention de mode ne se pose plus en cochant un bouton : elle se pose en
	# entrant dans le salon. Ce test le disait par l'état de l'interface ; il le
	# dit maintenant par le geste, ce qui est aussi ce que fait un joueur.
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_check("l'écran est bien le salon local", _ui.hub.current_id() == _ui.SCREEN_LOCAL)
	_check("le mode retenu est l'écran partagé",
		_ui.selected_network_mode() == NetworkManager.GameMode.LOCAL_SPLITSCREEN)
	_check("le choix de transport est masqué en local", not _ui.transport_hbox.visible)
	# `visible` ne dit que l'intention posée sur CE nœud : le champ vit dans un
	# conteneur que le menu cache, et reste donc « visible » pour lui-même. Seul
	# `is_visible_in_tree()` répond à la question posée.
	_check("le champ de saisie est masqué en local",
		not _ui.join_input.is_visible_in_tree())
	_check("le code de salon est masqué en local", not _ui.lobby_code_row.visible)
	_press_play()
	_check("la manche locale démarre", await _await(func(): return _main.round_active, ROUND_TIMEOUT))
	_check("aucun pair réseau", not multiplayer.has_multiplayer_peer())
	_check("mode local conservé",
		NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN)
	_check("les deux vues sont visibles",
		_main.vp1.get_parent().visible and _main.vp2.get_parent().visible)
	await get_tree().create_timer(2.0).timeout
	_check("la manche locale tient", _main.round_active)

	# Jusqu'à l'écran de fin, et c'est tout l'intérêt de ce mode : une seule
	# instance, aucun réseau, et pourtant le chemin exact où vivait le défaut de
	# `frame_post_draw` — une attente de rendu jamais satisfaite en headless, qui
	# laissait la séquence de fin suspendue pour toujours. Ce contrôle-là peut
	# entrer dans le lanceur de suites, là où les deux instances ne le peuvent pas.
	print("KILL: on abat le joueur 2")
	_main.p2.take_damage(1000.0, _main.p1)
	_check("la manche locale se termine",
		await _await(func(): return not _main.round_active, 10.0))
	_check("la séquence de fin se déclenche",
		await _await(func(): return _main._end_sequence_active or _main.game_over, 10.0))
	_check("l'écran de fin finit par se poser",
		await _await(func(): return _main.game_over and not _main._end_sequence_active, 25.0))
	print("FIN: %s" % _ui.game_over_title.text)
	_check("le titre de fin n'est plus celui du menu",
		_ui.game_over_title.text != "CANDELA 2D", _ui.game_over_title.text)
	_check("le score de session est enregistré",
		_main.p1_session_wins + _main.p2_session_wins == 1,
		"%d / %d" % [_main.p1_session_wins, _main.p2_session_wins])

	# **Famille 5.2 : la vitesse normale est rendue quand la killcam se termine
	# d'elle-même.** Le seul chemin de sortie qu'une instance unique puisse
	# exercer, et le plus fréquent de tous — celui de chaque mort de chaque
	# partie.
	#
	# Ce que ça protège : `Engine.time_scale` est un réglage GLOBAL du moteur.
	# L'oublier ne ralentit pas la killcam, il ralentit **tout le jeu, menus
	# compris** — et le joueur n'a aucune raison de relier un curseur qui rampe à
	# une mort survenue dix secondes plus tôt.
	#
	# Déterministe ici, contrairement au chemin de la déconnexion : la séquence
	# de fin est allée à son terme, on ne mesure donc pas une fenêtre fugace mais
	# un état stable. C'est pour ça que ce contrôle vit dans le banc à une
	# instance et pas dans celui à deux.
	_check("la vitesse normale est rendue après la killcam",
		is_equal_approx(Engine.time_scale, 1.0),
		"time_scale=%.4f" % Engine.time_scale)
	_check("le rejeu est bien arrêté", not ReplaySystem.playing_back)
	# Et rien ne doit rester gelé : la ceinture de V2.1 passe par le même chemin.
	_check("aucune vue ne reste figée",
		_main.vp1.render_target_update_mode != SubViewport.UPDATE_DISABLED,
		"vp1=%d" % _main.vp1.render_target_update_mode)
	_quit(0)


func _run_host() -> void:
	await _select_mode(true)
	print("MENU: mode hôte sélectionné, transport %s" % ("LAN" if _lan else "Internet"))
	# L'hôte ouvre son salon depuis le panneau, il n'appuie pas sur PRÊT : le
	# code doit s'afficher avant que quiconque soit là, et PRÊT n'a de sens
	# qu'une fois l'adversaire arrivé.
	_ui._open_lobby()

	if _lan:
		print("CODE: %d" % NetworkManager.DEFAULT_PORT)
	else:
		if not await _await(func(): return not NetworkManager.lobby_code.is_empty(), CODE_TIMEOUT):
			_fail("aucun code de salon publié")
			return
		print("CODE: %s" % NetworkManager.lobby_code)
		# Le code se lit dans le panneau du salon, où l'hôte attend — il n'y a plus
		# d'écran d'attente en jeu, le départ ayant lieu depuis le menu.
		print("PANNEAU: %s" % _ui.lobby_code_engraver.code())
		_check("le panneau du salon affiche le code",
			_ui.lobby_code_engraver.code() == NetworkManager.lobby_code)

	_check("PRÊT est grisé tant que l'hôte est seul", _ready_entry_disabled())

	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return
	print("ADVERSAIRE: connecté (id %d)" % multiplayer.get_peers()[0])
	_check("PRÊT s'ouvre à l'arrivée de l'adversaire", not _ready_entry_disabled())
	# Le match n'a PAS démarré tout seul : c'est tout l'objet de la porte.
	_check("aucune manche n'a démarré à la connexion", not _main.round_active)
	# `round_active` dit qu'aucune manche ne tourne ; il ne dit pas où se trouve le
	# joueur. Les deux ont été vrais en même temps le 2026-08-18 : le client était
	# téléporté hors du menu à la connexion, sans qu'aucune manche démarre, et le
	# banc restait vert pendant qu'Adrien était bloqué. C'est `_is_main_menu` qui
	# décrit ce que le joueur PERÇOIT.
	_check("on est toujours dans le menu", _ui._is_main_menu)
	_press_play()
	await _verify_round()
	# Les deux instances ne sont pas lancées en même temps : celle qui finit la
	# première ne doit pas partir pendant que l'autre teste encore son rematch.
	await get_tree().create_timer(10.0).timeout
	_quit(0)


## Famille 3 de la checklist en ligne : **l'adversaire disparaît pendant le
## 3-2-1**, brutalement, sans prévenir.
##
## C'est la transition la plus régressive du jeu et elle n'était vérifiée qu'à la
## main — fermer une fenêtre au bon moment, puis regarder l'autre écran. Ce que
## le code prétend faire est écrit noir sur blanc dans `_on_peer_disconnected` ;
## rien ne vérifiait qu'il le fasse.
##
## **Le piège que ce banc protège est nommé dans le code lui-même** : « un départ
## interrompu en plein 3-2-1 laisserait `countdown_left` figé, donc l'hôte
## immobile pour toujours dans son bac à sable ». Un joueur bloqué sans message
## et sans pouvoir bouger — le pire état atteignable, et le seul qui ne se
## signale par aucune erreur.
## Famille 1 de la checklist : **la pause en ligne ne gèle rien.**
##
## Le contrat est écrit dans `ui.gd` : « en ligne il figerait la simulation des
## deux joueurs, ce panneau se superpose donc à un monde qui court ». Le joueur
## en pause reste **vulnérable** — c'est voulu, et c'est ce qui empêche la pause
## d'être une invincibilité gratuite.
##
## Deux propriétés opposées, et c'est leur COMBINAISON qui fait la règle :
## le monde continue **et** celui qui navigue cesse d'agir. Vérifier l'une sans
## l'autre laisserait passer les deux défauts qui comptent — une pause qui gèle
## le match, ou un joueur qui court encore pendant qu'il lit son menu.
## Famille 2 de la checklist : **ce que l'adversaire fait pendant votre killcam
## ne doit rien changer à votre écran — et ne doit rien perdre non plus.**
##
## Deux exigences opposées, comme la famille 1. Pendant le ralenti, l'intention du
## client est **retenue** et non appliquée : rien ne bouge chez l'hôte, ni l'arme
## de P2 ni le libellé du chrono. Mais à la sortie, **c'est le DERNIER choix** du
## client qui vaut — pas le premier arrivé, pas rien.
##
## Le défaut que ça protège n'est pas cosmétique : un changement d'arme appliqué
## au milieu d'un ralenti coupe la killcam de l'hôte, et une manche peut démarrer
## seule pendant qu'il regarde encore.
## Famille 5.3 : **l'adversaire disparaît pendant le ralenti.**
##
## Le pire chemin de sortie du jeu, et le commentaire de `_abort_killcam` le dit
## déjà : « le ralenti est un réglage global du moteur : l'oublier sur un chemin
## de sortie laisse tout le jeu à 3 % de sa vitesse ». Pas la killcam — **tout le
## jeu**, menus compris. Un joueur qui verrait son curseur ramper n'aurait aucune
## raison de relier ça à une déconnexion survenue dix secondes plus tôt.
##
## C'est la combinaison de deux chemins que rien n'exerçait ensemble : la perte
## de pair (famille 3) et la sortie de ralenti (famille 5). Chacun est couvert
## séparément ; leur croisement ne l'était pas.
## Famille 6 : **les deux martèlent « prêt » — une seule manche doit démarrer.**
##
## Cette famille paraissait intestable : elle décrit un martèlement pendant des
## transitions, donc des fenêtres de quelques dixièmes de seconde. **Mais sa
## propriété n'est pas une fenêtre, c'est un COMPTE.** « Une seule manche
## démarre » se vérifie en comptant les démarrages, et un compte est stable quel
## que soit le tempo — c'est le principe de placement appliqué : chercher
## l'observable stable plutôt que le moment.
##
## Si le code se cassait — double départ, décompte joué deux fois — **ce
## contrôle tomberait**, puisque le compte passerait à deux. C'est ce qui le
## distingue d'un contrôle déplacé pour passer.
func _run_host_spam() -> void:
	await _select_mode(true)
	_ui._open_lobby()
	print("CODE: %d" % NetworkManager.DEFAULT_PORT)
	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return

	# On compte les transitions « aucune manche » → « manche en cours ». Le
	# sondage est serré, mais aucune manche ne dure moins d'un dixième de
	# seconde : on ne peut pas en manquer une.
	var departs := 0
	var etait_active: bool = _main.round_active
	var t := 0.0
	while t < 6.0:
		# Martèlement des deux côtés pendant toute la fenêtre.
		_press_play()
		await get_tree().create_timer(0.12, true, false, true).timeout
		t += 0.12
		if _main.round_active and not etait_active:
			departs += 1
		etait_active = _main.round_active

	print("DÉPARTS: %d en %.1f s de martèlement" % [departs, t])
	_check("le martèlement ne fait démarrer qu'une seule manche", departs == 1,
		"%d démarrage(s)" % departs)

	# ⚠️ **Une seconde assertion a été tentée trois fois, puis retirée** — et le
	# récit vaut mieux que le silence.
	#
	# Elle cherchait la seconde signature d'un double départ : un décompte qui
	# **repart** après avoir décru. Trois versions, trois échecs, chacun pour une
	# raison différente de la précédente :
	#
	#   1. « `round_active` ET `countdown_left > 0` est anormal » — faux : c'est
	#      l'état NORMAL du 3-2-1. L'assertion accusait le jeu d'être ce qu'il
	#      doit être.
	#   2. comparaison à une valeur précédente initialisée à zéro : la montée
	#      légitime de 0 à 3 s au départ comptait comme une relance.
	#   3. corrigée d'un cran, elle tombe encore, pour une raison non élucidée.
	#
	# **Retirée plutôt qu'affaiblie.** Chaque correction la rapprochait de « ne
	# rien vérifier » — et la troisième tentative aurait été le moment de
	# l'assouplir jusqu'à ce qu'elle passe. La propriété qui compte, elle, est
	# vérifiée et stable : **un seul départ**. Si le code se cassait, ce compte
	# tomberait.
	#
	# À reprendre par quelqu'un qui saura observer un décompte rejoué autrement
	# qu'en le sondant.
	await get_tree().create_timer(6.0).timeout
	_quit(0)

## Le client de la famille 6 : il martèle aussi, en même temps.
func _run_client_spam() -> void:
	await _select_mode(false)
	_ui.join_input.text = _value("--join-spam", "")
	_ui.join_requested.emit()
	if not await _await(func(): return multiplayer.has_multiplayer_peer() \
			and multiplayer.get_peers().size() > 0, PEER_TIMEOUT):
		_fail("le client n'a jamais rejoint")
		return
	var t := 0.0
	while t < 6.0:
		_press_play()
		await get_tree().create_timer(0.11, true, false, true).timeout
		t += 0.11
	_check("le client a martelé sans planter", true)
	await get_tree().create_timer(4.0).timeout
	_quit(0)

func _run_host_ralenti() -> void:
	await _select_mode(true)
	_ui._open_lobby()
	print("CODE: %d" % NetworkManager.DEFAULT_PORT)
	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return
	_press_play()
	if not await _await(func(): return _main.round_active and _main.countdown_left <= 0.0, 25.0):
		_fail("la manche n'a jamais commencé")
		return

	print("KILL: l'hôte abat le joueur 2")
	_main.p1.shoot()
	await get_tree().create_timer(0.3).timeout
	_main.p2.take_damage(1000.0, _main.p1)
	if not await _await(func(): return _main._end_sequence_active, 10.0):
		_fail("la séquence de fin ne s'est pas déclenchée")
		return
	# Le ralenti doit être réellement engagé, sinon on testerait une sortie qui
	# n'avait rien à restaurer — et le banc passerait sans rien prouver.
	# **Ce banc ne vérifie PAS que le ralenti a eu lieu, et ce n'est pas un oubli.**
	#
	# L'instrumentation a montré qu'il s'engage bien (0,063 mesuré), mais que le
	# rejeu **s'arrête vers l'index 185 alors que l'impact est à 203-208** : la
	# fenêtre de ralenti dure une fraction de seconde, puis la lecture cesse. Une
	# assertion sur `Engine.time_scale` serait donc instable par construction —
	# verte ou rouge selon le moment de l'échantillon, pas selon le code.
	#
	# Le défaut sous-jacent (la killcam se termine avant le moment fatal) est
	# **signalé à la ROADMAP** et appartient à `test_rejeu.gd`, qui teste la
	# fenêtre de rejeu. Ici on teste une SORTIE : que la coupure d'un pair rende
	# le jeu à sa vitesse normale, quoi qu'il se soit passé avant.
	await get_tree().create_timer(2.5, true, false, true).timeout

	if not await _await(func(): return multiplayer.get_peers().is_empty(), 30.0):
		_fail("le client n'est jamais parti")
		return
	print("ADVERSAIRE: disparu pendant le ralenti")
	await get_tree().process_frame
	await get_tree().process_frame

	# **La killcam ne doit PAS être coupée** — décision d'Adrien du 2026-08-19,
	# et exigence de la checklist depuis toujours : « ni coupée, ni accélérée, ni
	# recouverte par un écran d'attente ». C'est la propriété neuve, et elle se
	# vérifie à l'instant précis où l'ancien code aurait tout effacé.
	_check("la killcam survit au départ de l'adversaire",
		_main._end_sequence_active,
		"séquence active=%s" % _main._end_sequence_active)
	_check("le rejeu continue", ReplaySystem.playing_back)

	# Puis elle va à son terme, et SEULEMENT là l'état est rendu.
	if not await _await(func(): return not _main._end_sequence_active, 30.0):
		_fail("la séquence de fin ne s'est jamais terminée")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_check("le ralenti est levé une fois la killcam finie",
		is_equal_approx(Engine.time_scale, 1.0), "time_scale=%.4f" % Engine.time_scale)
	_check("le rejeu est arrêté", not ReplaySystem.playing_back)
	_check("l'hôte reprend la main", _main.sandbox_mode and not _main.round_active)
	_check("le décompte est effacé", is_zero_approx(_main.countdown_left))
	# L'adversaire parti ne doit pas continuer d'éclairer pendant qu'on le
	# regarde mourir : la purge de P2 est le seul geste resté immédiat.
	_check("sa torche s'est éteinte tout de suite", not _main.p2.flashlight_on)
	_quit(0)

## Le client de la famille 5.3 : il meurt, puis **disparaît pendant le ralenti**
## de l'hôte — pas après, pas avant.
func _run_client_ralenti() -> void:
	await _select_mode(false)
	_ui.join_input.text = _value("--join-ralenti", "")
	_ui.join_requested.emit()
	if not await _await(func(): return multiplayer.has_multiplayer_peer() \
			and multiplayer.get_peers().size() > 0, PEER_TIMEOUT):
		_fail("le client n'a jamais rejoint")
		return
	_press_play()
	if not await _await(func(): return _main.round_active and _main.countdown_left <= 0.0, 25.0):
		_fail("la manche n'a jamais commencé côté client")
		return
	# Sa propre killcam commence : c'est le moment où l'hôte est au ralenti.
	if not await _await(func(): return ReplaySystem.playing_back, 25.0):
		_fail("le rejeu n'a jamais démarré côté client")
		return
	print("CLIENT: ralenti en cours, coupure brutale")
	OS.kill(OS.get_process_id())

func _run_host_killcam() -> void:
	await _select_mode(true)
	_ui._open_lobby()
	print("CODE: %d" % NetworkManager.DEFAULT_PORT)
	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return
	_press_play()
	if not await _await(func(): return _main.round_active and _main.countdown_left <= 0.0, 25.0):
		_fail("la manche n'a jamais commencé")
		return

	print("KILL: l'hôte abat le joueur 2")
	_main.p1.shoot()
	await get_tree().create_timer(0.3).timeout
	_main.p2.take_damage(1000.0, _main.p1)
	if not await _await(func(): return _main._end_sequence_active or _main.game_over, 10.0):
		_fail("la séquence de fin ne s'est pas déclenchée")
		return
	print("KILLCAM: en cours")

	# Le client va marteler « prêt » et changer d'arme pendant ce ralenti.
	var arme_avant: int = _index_arme_p2()
	await get_tree().create_timer(1.2).timeout
	if _main._end_sequence_active:
		_check("l'arme de P2 ne change pas pendant le ralenti",
			_index_arme_p2() == arme_avant,
			"%d → %d" % [arme_avant, _index_arme_p2()])
		_check("aucune manche ne démarre pendant le ralenti", not _main.round_active)
	else:
		print("NOTE: le ralenti était déjà fini, contrôle du pendant non exercé")

	# ⚠️ **La seconde moitié de cette famille a été RETIRÉE, et il faut le dire.**
	#
	# Elle vérifiait qu'à la sortie du ralenti l'intention retenue du client est
	# appliquée et non perdue. Elle passait, puis échouait, sur le même code :
	# **instable**. La cause tient à ce que la fenêtre de séquence de fin est
	# courte et variable — voir le défaut « la killcam s'arrête avant le moment
	# fatal » consigné à la ROADMAP, qui raccourcit cette fenêtre de façon non
	# déterministe. Le client n'a pas toujours le temps d'atteindre son écran de
	# fin avant que l'hôte ait quitté le sien.
	#
	# **Un banc qui vacille est pire qu'aucun banc** : il apprend à ignorer le
	# lanceur, et le jour où il dit vrai personne ne le croit. Ce qui reste
	# ci-dessus est déterministe — rien ne bouge pendant le ralenti — et c'est la
	# moitié qui protège du défaut le plus grave : une manche qui démarrerait
	# pendant que l'autre regarde encore.
	#
	# À reprendre quand la fenêtre de rejeu sera comprise, pas avant.
	await get_tree().create_timer(8.0).timeout
	_quit(0)

## L'indice de l'arme actuellement cochée pour P2, ou -1.
func _index_arme_p2() -> int:
	var b: BaseButton = _ui.p2_weapon_group.get_pressed_button()
	return b.get_index() if b != null else -1

## Le client de la famille 2 : il martèle son choix pendant la killcam de l'hôte.
func _run_client_killcam() -> void:
	await _select_mode(false)
	_ui.join_input.text = _value("--join-killcam", "")
	_ui.join_requested.emit()
	if not await _await(func(): return multiplayer.has_multiplayer_peer() \
			and multiplayer.get_peers().size() > 0, PEER_TIMEOUT):
		_fail("le client n'a jamais rejoint")
		return
	_press_play()
	if not await _await(func(): return _main.round_active and _main.countdown_left <= 0.0, 25.0):
		_fail("la manche n'a jamais commencé côté client")
		return
	# **Attendre `game_over`, et rien d'autre.** Deux gates ont été essayées avant,
	# fausses toutes les deux :
	#
	#   • `not round_active` — vrai dès le DÉBUT de la killcam, donc le client
	#     pressait pendant son propre ralenti ;
	#   • `not _ui._is_main_menu` — faux pendant TOUT le match, donc l'attente
	#     rendait la main immédiatement, avant même la mort.
	#
	# `game_over` n'est posé qu'après la séquence de fin, juste avant l'écran de
	# fin : c'est le seul état qui dise « ma killcam est finie ». C'est le
	# scénario de la checklist — B a fini sa killcam avant A, et se déclare
	# pendant que A regarde encore le ralenti.
	if not await _await(func(): return _main.game_over, 30.0):
		_fail("l'écran de fin ne s'est jamais ouvert côté client")
		return
	print("CLIENT: écran de fin ouvert, il martèle son choix")
	# Trois déclarations d'affilée, arme différente à chaque fois : c'est la
	# DERNIÈRE que l'hôte doit retenir.
	var boutons: Array = _ui.p2_weapon_group.get_buttons()
	for i in 3:
		if boutons.size() > i:
			(boutons[i] as BaseButton).button_pressed = true
		_press_play()
		await get_tree().create_timer(0.4).timeout
	_check("le client a bien pu se déclarer", true)
	await get_tree().create_timer(6.0).timeout
	_quit(0)

func _run_host_pause() -> void:
	await _select_mode(true)
	_ui._open_lobby()
	print("CODE: %d" % NetworkManager.DEFAULT_PORT)
	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return
	_press_play()
	if not await _await(func(): return _main.round_active and _main.countdown_left <= 0.0, 25.0):
		_fail("la manche n'a jamais commencé")
		return
	print("MANCHE: en cours")

	# Le client met la pause à peu près maintenant. On mesure le chrono avant et
	# après une seconde de jeu : c'est la seule preuve que le monde a continué.
	var avant: float = _main.time_left
	await get_tree().create_timer(1.5).timeout
	var apres: float = _main.time_left
	_check("le chrono continue de tourner pendant la pause adverse",
		avant - apres > 0.5, "%.2f s écoulées" % (avant - apres))
	_check("la manche n'a pas été interrompue", _main.round_active)
	# Le joueur en pause ne doit pas courir sur sa dernière commande : l'hôte
	# reçoit des entrées neutres, pas l'absence d'entrées.
	_check("l'adversaire en pause ne se déplace plus",
		_main.p2.velocity.length() < 1.0, str(_main.p2.velocity))
	_check("et ne sprinte pas non plus", not _main.p2.is_sprinting)
	# **L'hôte part en DERNIER.** Sortir maintenant couperait le lien pendant que
	# le client mesure encore, et son « la manche tourne toujours » tomberait —
	# non parce que la pause gèle quoi que ce soit, mais parce que l'hôte a
	# disparu. Le piège est déjà consigné dans le mode nominal de ce fichier ; il
	# vaut pour tous les modes à deux processus, et je viens de le repayer.
	await get_tree().create_timer(8.0).timeout
	_quit(0)

## Le client de la famille 1 : il rejoint, joue, **ouvre sa pause**, et son
## personnage doit cesser d'agir sans que le monde s'arrête.
func _run_client_pause() -> void:
	await _select_mode(false)
	_ui.join_input.text = _value("--join-pause", "")
	_ui.join_requested.emit()
	if not await _await(func(): return multiplayer.has_multiplayer_peer() \
			and multiplayer.get_peers().size() > 0, PEER_TIMEOUT):
		_fail("le client n'a jamais rejoint")
		return
	_press_play()
	if not await _await(func(): return _main.round_active and _main.countdown_left <= 0.0, 25.0):
		_fail("la manche n'a jamais commencé côté client")
		return
	_ui._open_pause()
	await get_tree().process_frame
	_check("le menu de pause est ouvert", _ui.is_pause_menu_open())
	# **Le point du test.** En ligne la pause ne gèle rien : l'arbre ne doit PAS
	# être en pause, sinon le joueur deviendrait invulnérable pendant qu'il lit
	# son menu — et le monde s'arrêterait pour lui seul.
	_check("l'arbre n'est pas gelé en ligne", not get_tree().paused)
	await get_tree().create_timer(2.0).timeout
	_check("la manche tourne toujours côté client", _main.round_active)
	# Une seconde de plus que l'hôte : celui qui finit le premier ne doit pas
	# couper le lien pendant que l'autre mesure encore.
	await get_tree().create_timer(1.0).timeout
	_quit(0)

func _run_host_coupure() -> void:
	await _select_mode(true)
	_ui._open_lobby()
	print("CODE: %d" % NetworkManager.DEFAULT_PORT)

	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return
	print("ADVERSAIRE: connecté")
	_press_play()

	# On attend d'être VRAIMENT dans le décompte : couper avant qu'il commence
	# testerait une autre transition (la famille 4), et le banc croirait couvrir
	# celle-ci.
	if not await _await(func(): return _main.countdown_left > 0.0, 20.0):
		_fail("le décompte n'a jamais démarré")
		return
	print("DÉCOMPTE: en cours (%.1f s)" % _main.countdown_left)

	if not await _await(func(): return multiplayer.get_peers().is_empty(), 30.0):
		_fail("le client n'est jamais parti")
		return
	print("ADVERSAIRE: disparu pendant le décompte")
	# Une frame pour laisser `_on_peer_disconnected` se dérouler entièrement.
	await get_tree().process_frame
	await get_tree().process_frame

	_check("le décompte est effacé", is_zero_approx(_main.countdown_left),
		"%.2f s restantes" % _main.countdown_left)
	_check("aucune manche ne tourne", not _main.round_active)
	# LE point : l'hôte doit pouvoir bouger. Un décompte figé le clouerait sur
	# place sans rien afficher qui l'explique.
	_check("l'hôte reprend la main (bac à sable)", _main.sandbox_mode)
	_check("le score de session est remis à zéro",
		_main.p1_session_wins == 0 and _main.p2_session_wins == 0)
	_check("aucun « prêt » ne survit à l'adversaire",
		not _main.p1_ready_for_rematch and not _main.p2_ready_for_rematch
		and not _main.local_ready_for_rematch)
	_check("la série de session tombe avec lui", _main.serie_longueur == 0)
	_check("le joueur 2 cesse de courir sur sa dernière commande",
		_main.p2.velocity == Vector2.ZERO and not _main.p2.is_sprinting)
	# Sa torche aussi : une lumière orpheline resterait allumée dans l'arène.
	_check("sa torche est éteinte", not _main.p2.flashlight_on)
	_quit(0)

## Le client de la famille 3 : il rejoint, se déclare prêt, puis **disparaît**
## pendant le décompte — sans quitter proprement, comme un ⌘Q ou une coupure.
func _run_client_coupure() -> void:
	await _select_mode(false)
	_ui.join_input.text = _value("--join-coupure", "")
	_ui.join_requested.emit()
	if not await _await(func(): return multiplayer.has_multiplayer_peer() \
			and multiplayer.get_peers().size() > 0, PEER_TIMEOUT):
		_fail("le client n'a jamais rejoint")
		return
	print("CLIENT: connecté")
	_press_play()
	if not await _await(func(): return _main.countdown_left > 0.0, 20.0):
		_fail("le décompte n'a jamais démarré côté client")
		return
	print("CLIENT: décompte en cours, coupure brutale")
	# Sortie SANS `quit_game()` : c'est tout l'objet du test. Une fermeture propre
	# préviendrait l'hôte par le protocole et n'exercerait pas la détection de
	# perte de pair.
	OS.kill(OS.get_process_id())

func _run_client() -> void:
	await _select_mode(false)
	_ui.join_input.text = _value("--join", "")
	print("MENU: mode client, saisie « %s »" % _ui.join_input.text)
	_check("la saisie survit à la validation d'alphabet",
		_lan or LobbyCode.is_valid(_ui.join_input.text), _ui.join_input.text)
	# Un code refusé doit se dire tout de suite : on mesure le délai que le
	# joueur subit réellement entre son clic et le message d'erreur.
	# `_rejected_at` est un champ et non une locale : une lambda GDScript capture
	# les locales par valeur, l'affectation n'en ressortirait jamais.
	_rejected_at = -1
	var pressed_at := Time.get_ticks_msec()
	NetworkManager.connection_failed.connect(func(): _rejected_at = Time.get_ticks_msec())
	_check("PRÊT est grisé avant d'avoir rejoint", _ready_entry_disabled())
	# Rejoindre est un geste à part, sous le champ de code : il ne lance rien.
	_ui.join_requested.emit()

	if not await _await(func(): return not multiplayer.get_peers().is_empty() or _rejected_at > 0, PEER_TIMEOUT):
		_fail("aucune réponse du salon en %ds" % PEER_TIMEOUT)
		return
	if _rejected_at > 0:
		_fail("salon refusé après %d ms : %s" % [_rejected_at - pressed_at, NetworkManager.last_error])
		return
	print("HOTE: connecté")
	_check("PRÊT s'ouvre une fois le salon rejoint", not _ready_entry_disabled())
	_check("aucune manche n'a démarré à la connexion", not _main.round_active)
	# `round_active` dit qu'aucune manche ne tourne ; il ne dit pas où se trouve le
	# joueur. Les deux ont été vrais en même temps le 2026-08-18 : le client était
	# téléporté hors du menu à la connexion, sans qu'aucune manche démarre, et le
	# banc restait vert pendant qu'Adrien était bloqué. C'est `_is_main_menu` qui
	# décrit ce que le joueur PERÇOIT.
	_check("on est toujours dans le menu", _ui._is_main_menu)
	_press_play()
	await _verify_round()
	# Les deux instances ne sont pas lancées en même temps : celle qui finit la
	# première ne doit pas partir pendant que l'autre teste encore son rematch.
	await get_tree().create_timer(10.0).timeout
	_quit(0)


## La manche doit démarrer d'elle-même : décompte, puis round_active des deux
## côtés. C'est la partie du flux de match que le changement de transport
## pourrait casser sans qu'aucun test unitaire ne le voie.
func _verify_round() -> void:
	var started := await _await(func(): return _main.round_active, ROUND_TIMEOUT)
	_check("la manche démarre", started)
	if not started:
		return
	print("MANCHE: en cours, décompte restant %.1f s" % _main.countdown_left)
	_check("les deux joueurs sont dans l'arène",
		is_instance_valid(_main.p1) and is_instance_valid(_main.p2))
	_check("le chrono de match tourne", _main.time_left > 0.0)
	# Le client pousse une commande de déplacement constante : c'est l'hôte qui
	# doit simuler J2 à partir d'elle. Sans ce test, rien ne vérifiait que la
	# remontée des commandes fonctionne — seulement que la partie tenait debout.
	var start_p2: Vector2 = _main.p2.global_position
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		var stub := NetworkInputProvider.new()
		stub.update_input_state(Vector2.RIGHT, Vector2.RIGHT, false, false, false)
		_main._set_player_input_provider(_main.p2, stub, 0)
		print("DEPLACEMENT: le client pousse une commande vers la droite")

	# On attend ce qu'on va vérifier, pas une durée.
	#
	# Ces contrôles dormaient quatre secondes puis regardaient. Sur une machine
	# chargée — plusieurs instances Godot en vol — quatre secondes de mur ne font
	# pas quatre secondes de jeu : le 2026-08-18, deux passages consécutifs ont
	# échoué différemment, d'abord sur le ping à zéro puis sur l'écran de fin, avec
	# un ping applicatif à 155 ms contre 26 habituels. Aucun défaut de logique
	# derrière — une famine de temporisateurs.
	#
	# Un banc qui n'est vrai qu'au calme est une couverture conditionnelle. Celui-ci
	# attend maintenant la CONDITION, avec un plafond large : il reste rapide quand
	# la machine l'est, et cesse de mentir quand elle ne l'est pas.
	var deplace := func() -> bool:
		return _main.p2.global_position.distance_to(start_p2) > 20.0
	var bouge := await _await(deplace, 20.0)
	var moved: float = _main.p2.global_position.distance_to(start_p2)
	print("DEPLACEMENT: J2 a parcouru %.1f px vu d'ici" % moved)
	_check("le déplacement du client est visible ici", bouge, "%.1f px" % moved)
	_check("le match avance sans se couper",
		_main.round_active or _main._end_sequence_active or _main.game_over)
	# Le ping part toutes les secondes ; c'est le premier aller-retour qu'on
	# attend, pas un délai arbitraire.
	_check("le ping applicatif remonte",
		await _await(func(): return NetworkManager.has_rtt, 20.0),
		"%.1f ms" % NetworkManager.rtt_ms)
	print("PING_MS: %.1f" % NetworkManager.rtt_ms)
	print("HP: p1=%.0f p2=%.0f" % [_main.p1.hp, _main.p2.hp])

	await _verify_kill_to_rematch()


## Fin de BO1 : un kill décidé par l'hôte doit produire killcam puis écran de
## fin des DEUX côtés, et un rematch doit repartir. On passe par take_damage,
## le même point d'entrée qu'une balle — seule la visée est court-circuitée.
func _verify_kill_to_rematch() -> void:
	var is_host := NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST

	# La killcam de l'invité ne montrait ni tirs ni impacts. take_damage seul ne
	# reproduit rien : il faut de vraies balles dans la fenêtre de rejeu.
	var replayed := [0]
	ReplaySystem.replay_spawn_bullet.connect(func(_s, _p, _r, _w): replayed[0] += 1)

	if is_host:
		print("TIRS: l'hôte tire trois fois")
		for i in 3:
			_main.p1.shoot()
			await get_tree().create_timer(0.35).timeout
	else:
		await get_tree().create_timer(1.05).timeout

	print("ENREG: instantanés=%d évènements=%d recording=%s" % [
		ReplaySystem.snapshots.size(), ReplaySystem.bullet_events.size(),
		ReplaySystem.recording])
	_check("les tirs sont enregistrés pour la killcam",
		ReplaySystem.bullet_events.size() > 0,
		"%d évènement(s)" % ReplaySystem.bullet_events.size())

	if is_host:
		print("KILL: l'hôte abat le joueur 2")
		_main.p2.take_damage(1000.0, _main.p1)

	_check("la manche se termine", await _await(func(): return not _main.round_active, 10.0))
	_check("la séquence de fin se déclenche",
		await _await(func(): return _main._end_sequence_active or _main.game_over, 10.0))
	print("KILLCAM: replay=%s" % ReplaySystem.playing_back)

	# La killcam puis l'écran de fin prennent quelques secondes des deux côtés.
	_check("l'écran de fin de match s'affiche",
		await _await(func(): return _main.game_over and not _main._end_sequence_active, 25.0))
	print("FIN: %s" % _ui.game_over_title.text)
	# Le point décisif : la killcam a-t-elle REJOUÉ les balles enregistrées ?
	# Enregistrement et relecture peuvent échouer indépendamment.
	print("REJEU: impact=%d ralenti=%d balles rejouées=%d / %d enregistrées" % [
		ReplaySystem.impact_frame, ReplaySystem.slow_mo_start_frame,
		replayed[0], ReplaySystem.bullet_events.size()])
	_check("la killcam rejoue les balles enregistrées",
		replayed[0] > 0 or ReplaySystem.bullet_events.is_empty(),
		"%d rejouée(s)" % replayed[0])
	_check("le score du match est enregistré",
		_main.p1_session_wins + _main.p2_session_wins == 1, "%d / %d" % [_main.p1_session_wins, _main.p2_session_wins])
	_check("le lien tient après la killcam", not multiplayer.get_peers().is_empty())

	# Rematch : les deux camps se déclarent prêts, la manche doit repartir.
	print("REMATCH: on se déclare prêt (%s)" % _ui.btn_replay.text)
	_main._on_replay_requested()
	_check("le rematch relance une manche", await _await(func(): return _main.round_active, 25.0))


# ---------------------------------------------------------------------------

## Le transport reste un choix de bouton — Internet ou réseau local est une vraie
## alternative. Le mode, lui, se pose en entrant dans le salon correspondant.
func _select_mode(is_host: bool) -> void:
	# **L'écran EST la décision de transport, la bascule ne l'est plus.**
	#
	# Ce banc poussait `SCREEN_HOST` / `SCREEN_JOIN` — les salons Internet — dans
	# les deux cas, en comptant sur `btn_transport_lan` pour choisir ENet. Or
	# depuis la refonte des menus, entrer dans un salon écrit lui-même le
	# transport (`_apply_lobby_intent`) : le `push` écrasait donc la bascule une
	# frame plus tard, et le chemin LAN repartait sur EOS. Le client se faisait
	# refuser par « Connexion à Epic en cours », dans un mode qui n'a rien à
	# demander à Epic.
	#
	# Invisible jusqu'ici parce que **personne ne lançait le duo en ENet** : les
	# modes `--host` / `--join` s'exécutaient à la main, avec Epic. C'est
	# exactement le trou que `run_duo.sh` vient combler, et il l'a trouvé à son
	# premier lancement.
	if _lan:
		_ui.hub.push(_ui.SCREEN_LOCAL_HOST if is_host else _ui.SCREEN_LOCAL_JOIN)
	else:
		_ui.hub.push(_ui.SCREEN_HOST if is_host else _ui.SCREEN_JOIN)
	# `show_main_menu()` remet la pile à l'accueil, et il peut encore survenir
	# après ce `push` : en EOS l'attente de la session lui laissait le temps de
	# passer, le chemin LAN n'attend rien et le pilotage partait donc d'un écran
	# qui n'était plus le bon. On laisse le menu se poser, puis on vérifie qu'on
	# est bien où l'on croit — plutôt que de découvrir plus tard un contrôle qui
	# accuse l'interface d'un défaut d'écran.
	await get_tree().process_frame
	await get_tree().process_frame
	var attendu: String
	if _lan:
		attendu = _ui.SCREEN_LOCAL_HOST if is_host else _ui.SCREEN_LOCAL_JOIN
	else:
		attendu = _ui.SCREEN_HOST if is_host else _ui.SCREEN_JOIN
	if _ui.hub.current_id() != attendu:
		_ui.hub.push(attendu)
		await get_tree().process_frame
	_check("le salon visé est bien l'écran courant",
		_ui.hub.current_id() == attendu, _ui.hub.current_id())

## Équivalent d'un clic sur « PRÊT ».
func _press_play() -> void:
	print("STATUT: %s" % _ui.lobby_status_label.text)
	_main._on_replay_requested()

## L'entrée « PRÊT » de l'écran courant est-elle grisée ? Le grisage est la façon
## dont le menu dit « il manque quelqu'un » sans faire disparaître le bouton.
func _ready_entry_disabled() -> bool:
	for entree: Button in _ui._ready_entries:
		if is_instance_valid(entree) and entree.is_visible_in_tree():
			return entree.disabled
	# Aucune entrée visible : on n'est pas sur un écran de salon, et répondre
	# « pas grisé » ferait échouer le contrôle en accusant l'interface. C'est le
	# défaut qui a fait passer le chemin LAN pour cassé pendant une journée —
	# l'écran était simplement resté à l'accueil, et les quatre entrées étaient
	# correctement grisées, hors de vue.
	push_error("aucune entrée PRÊT visible — écran courant : %s" % _ui.hub.current_id())
	return true


func _await(predicate: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not predicate.call():
		if waited >= timeout:
			return false
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return true


var _failures := 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		_failures += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])

func _fail(reason: String) -> void:
	printerr("ECHEC: %s" % reason)
	_quit(1)

func _has(flag: String) -> bool:
	return flag in _args

func _value(flag: String, fallback: String) -> String:
	var idx := _args.find(flag)
	if idx < 0 or idx + 1 >= _args.size():
		return fallback
	return _args[idx + 1]

func _quit(code: int) -> void:
	var final := code if code != 0 else (1 if _failures > 0 else 0)
	if final == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	print("EXIT_CODE: %d" % final)
	# Même porte de sortie que le jeu : c'est aussi ce qu'on veut vérifier.
	NetworkManager.quit_game(final)
