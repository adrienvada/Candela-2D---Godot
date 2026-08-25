extends Node
class_name GameState

const Charte := preload("res://charte.gd")

const SHADER_GHOST := preload("res://ghost_unshaded.gdshader")

## Un match = UNE manche de 5 minutes (BO1). Le format n'est pas en dur : il
## transite par MatchRecord.Format pour qu'un BO3/BO5 puisse s'ajouter sans
## refonte. Seul le BO1 est implémenté.
const MATCH_FORMAT := MatchRecord.Format.BO1

@export var round_time: float = MatchRecord.ROUND_DURATION

var time_left: float = MatchRecord.ROUND_DURATION
var round_active: bool = false
var sandbox_mode: bool = false

## Entraînement solitaire en cours.
##
## Distinct de `sandbox_mode`, qui couvre aussi l'hôte en ligne resté seul : ces
## deux-là partagent « aucune manche, mais on peut tirer », et rien d'autre. Le
## drapeau existe surtout pour `_restore_viewports()` — sans lui, l'entraînement
## se déroule en mode écran partagé et rouvre donc les deux vues, alors qu'il n'y
## a qu'un joueur.
var training_mode: bool = false
var game_over: bool = false
var _first_replay_frame: bool = false
var p1_ready_for_rematch: bool = false
## Côté CLIENT seulement : ce que l'hôte a annoncé de lui-même. Voir
## `rpc_host_ready`.
var _hote_pret: bool = false
var p2_ready_for_rematch: bool = false
# Bascule locale « prêt à rejouer ». État canonique : le libellé du bouton
# REJOUER n'en est qu'un reflet — l'ancienne logique comparait le texte du
# bouton, que la moindre reformulation aurait cassée en silence.
var local_ready_for_rematch: bool = false
var _hosted_weapon_1_idx: int = 0

# Score de session : nombre de matchs gagnés depuis le lancement de la série.
# Remis à zéro au retour au menu, pas entre deux matchs.
var p1_session_wins: int = 0
var p2_session_wins: int = 0
## V3.9 — la série de victoires consécutives de la session, et qui la porte.
##
## Le score de session dit déjà « 3 - 2 », mais pas dans quel ORDRE : trois
## victoires puis deux défaites et une alternance stricte donnent le même
## affichage, alors qu'on ne se sent pas du tout dans la même partie. La série
## est ce que le score ne peut pas dire.
##
## `-1` en porteur = personne, ce qui est l'état d'une session neuve comme celui
## d'une session qui vient de connaître une égalité.
var serie_porteur: int = -1
var serie_longueur: int = 0
## Ce que la série a à dire du match qui vient de finir, retenu entre le moment
## où l'état avance et celui où l'écran de fin s'affiche. Sans ce report, il
## faudrait comparer l'avant et l'après une fois l'avant déjà écrasé.
var _mot_de_serie: String = ""
## Le pair est parti pendant une killcam : l'annonce attend qu'elle se termine.
var _deconnexion_differee: bool = false
## La comptabilité de la série vit dans son propre fichier : elle ne dépend ni du
## réseau ni de l'audio, et doit rester testable sans eux.
const SerieDeSession := preload("res://serie_de_session.gd")
## La règle du faisceau vit à part pour la même raison : elle doit se tester sans
## le reste du jeu.
const Vision := preload("res://vision.gd")
const Eblouissement := preload("res://eblouissement.gd")

# Manches gagnées dans le match en cours. En BO1 elles retombent à zéro à
# chaque fin de match ; elles existent pour que les formats longs s'ajoutent
# sans toucher à la fin de manche.
var p1_round_wins: int = 0
var p2_round_wins: int = 0

# Réserve de particules d'impact, partagée par toutes les balles.
var particle_pool: ParticlePool
# Cible d'échauffement, visible en bac à sable uniquement.
var training_target: TrainingTarget

var p1: Player
var p2: Player

# Peer de l'unique client (0 si aucun). L'autorité réseau de P2 reste l'hôte,
# c'est donc cet id qui sert de garde pour tout ce qui vient du client.
var client_peer_id: int = 0

# Décompte de départ, joué à l'identique des deux côtés : il donne au client le
# temps de recevoir la manche et évite les départs décalés.
## Torche des fantômes pendant la killcam : moitié de l'intensité de jeu
## (2,5). À pleine puissance le halo passait par-dessus la balle, qui est le
## sujet même de la séquence — on regarde le tir, pas l'éclairage.
const KILLCAM_TORCH_ENERGY := 1.25

const COUNTDOWN_DURATION := 3.0

## Décompte d'un match issu de l'appariement automatique — dix secondes au lieu
## de trois (décision d'Adrien, 2026-08-18).
##
## **Ce n'est pas un décompte plus long, c'est une fenêtre de choix.** L'arsenal
## commun n'est connu qu'une fois l'adversaire trouvé : la règle du miroir
## l'aligne sur le moins bien classé des deux, et personne ne peut donc choisir
## son arme avant. Le décompte cesse d'être du temps mort et devient le moment où
## l'on choisit.
##
## Les autres matchs gardent trois secondes : en salon comme en écran partagé,
## l'arme est déjà choisie au menu, et allonger l'attente ne donnerait rien à
## faire de plus.
const COUNTDOWN_MATCHMADE := 10.0

## Les deux camps peuvent abréger cette fenêtre en se déclarant prêts — c'est ce
## qui évite d'imposer dix secondes à qui a déjà choisi. Un seul « prêt » ne
## suffit pas : l'autre choisit peut-être encore.
var _countdown_ready_local: bool = false
var _countdown_ready_peer: bool = false
## Ce match vient-il de l'appariement automatique ? C'est la seule question qui
## décide de la durée : elle distingue « l'arme n'est pas encore choisie » de
## « elle l'est depuis le menu ».
var _matchmade_round: bool = false
## Les deux catégories du match apparié, retenues à l'appariement. La règle du
## miroir s'applique dessus, et l'écran les relit pour dire pourquoi l'arsenal a
## rétréci. Retenues ICI plutôt que relues chez l'appariement : celui-ci retombe
## au repos dès le lien ouvert, et son instantané n'est plus garanti.
var _mirror_local_tier: int = 0
var _mirror_opponent_tier: int = 0
var countdown_left: float = 0.0

## V2.1 — L'instant fatal : image figée ~150 ms. Seul le RENDU est suspendu
## (render_target_update_mode des deux viewports) — jamais time_scale ni
## l'arbre : un gel d'arbre en ligne est un piège connu, et la simulation doit
## continuer à capturer le sang derrière l'image figée.
const KILL_FREEZE_DURATION := 0.15
## V2.2 — Puis le noir gagne : rétrodiffusion du vainqueur d'abord, faisceau
## ensuite — sa torche est la dernière lumière à mourir.
const KILL_DARKNESS_BODY := 0.15
const KILL_DARKNESS_TORCH := 0.25

# [Client] Tirs rendus localement avant l'accord de l'hôte, retenus pour être
# dédupliqués à l'arrivée de la balle officielle. Chaque entrée porte son instant
# ET son angle : l'ordre seul confond deux tirs rapprochés, et une durée de vie
# fixe rendait la balle en double dès que le lien dépassait la seconde.
# Comptabilité dans `prediction_tir.gd`, sans dépendance, donc testable à froid.
const PredictionTir := preload("res://prediction_tir.gd")
var _predicted_shots: Array[Dictionary] = []

# [Hôte] Historique des positions pour la compensation de latence. La fenêtre
# couvre le recul maximal avec de la marge, sans conserver davantage.
const POS_HISTORY_WINDOW := 0.4
const LAG_COMP_MAX := 0.2
var _pos_history: Array[Dictionary] = []

# Recalage du chronomètre : le client décrémente localement entre deux envois.
const TIME_SYNC_INTERVAL := 5.0
var _time_sync_accum: float = 0.0

# Échéance de connexion du client, à neutraliser dès que l'issue est connue.
var _join_deadline_active: bool = false

# Séquence de fin de manche : _do_end_round est une coroutine longue (attente du
# sang, killcam, arrêt sur image). Tout ce qui survient entretemps — nouvelle
# manche, déconnexion, retour au menu — incrémente le jeton, ce qui fait
# abandonner la coroutine en vol au lieu de la laisser écraser l'état neuf.
var _round_token: int = 0
var _end_sequence_active: bool = false

# Vrai entre le début d'un match EN LIGNE et son archivage. Décision actée :
# quitter un match en cours vaut forfait — le joueur resté gagne, celui qui part
# perd. Ce jeton dit qu'il reste un résultat à écrire, et il n'y en a qu'un :
# l'abandon emprunte plusieurs chemins de retour au menu, qui se croisent.
var _forfeit_pending: bool = false

# Identifiant du match en cours, tiré par l'hôte et transmis au client. Il ne
# sert qu'à apparier les deux rapports côté classement : les deux machines
# envoient chacune le sien, sans se reparler. Ni secret, ni autorité.
#
# Tiré par manche, ce qui coïncide avec le match en BO1 — le seul format
# implémenté. Un BO3 devra le tirer à l'ouverture du MATCH, pas de la manche.
var _match_id: String = ""

# [Hôte] Effets différés jusqu'à la fin de la séquence : la killcam de chaque
# machine a sa propre durée, le client peut donc être prêt — ou arriver — alors
# que l'hôte est encore au ralenti.
var _pending_client_start: bool = false
var _pending_p2_weapon_idx: int = -1

var weapon_pistolet: WeaponData
var weapon_fusil: WeaponData
var weapon_pompe: WeaponData
var weapon_arbalete: WeaponData

@onready var ui = $UI
@onready var vp1 = $SplitScreen/ViewportContainer1/SubViewport1
@onready var vp2 = $SplitScreen/ViewportContainer2/SubViewport2
@onready var arena = $SplitScreen/ViewportContainer1/SubViewport1/Arena
@onready var players_node = $SplitScreen/ViewportContainer1/SubViewport1/Players
@onready var bullet_container = $SplitScreen/ViewportContainer1/SubViewport1/Bullets

@onready var player_scene = preload("res://player.tscn")
@onready var bullet_scene = preload("res://bullet.tscn")

var ghost_p1: Node2D
var ghost_p2: Node2D

var cam1: Camera2D
var cam2: Camera2D
var current_snap

var cam1_shake_time: float = 0.0
var cam2_shake_time: float = 0.0

## V4.12 — Recul directionnel : la caméra du tireur encaisse quelques pixels
## dans le dos du tir, résorbés en ~100 ms. S'additionne au shake aléatoire.
var _cam_kick: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

func camera_shot_kick(pid: int, dir: Vector2) -> void:
	if pid < 0 or pid > 1: return
	_cam_kick[pid] = -dir * 6.0

## V4.6 — Encaisser se sent au ventre : bref dézoom de la caméra du blessé,
## déclenché par la perte de PV autoritaire (rpc_update_hp), jamais prédite.
func camera_hit_kick(pid: int) -> void:
	if not round_active: return
	var cam: Camera2D = cam1 if pid == 0 else cam2
	if cam == null: return
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(0.98, 0.98), 0.04)
	tw.tween_property(cam, "zoom", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _ready():
	add_to_group("game_state")
	# L'intro ne se joue qu'ici, au lancement. Les retours au menu passent par
	# `play_music`, qui bascule sans redémarrer le flux.
	AudioManager.demarrer_musique_au_lancement()

	
	# Le pistolet garde les valeurs par défaut de `WeaponData` — cookie
	# « pistolet », 35° de demi-angle, échelle 1,6. Elles y sont écrites une fois
	# et pas recopiées ici : une valeur posée deux fois finit par différer.
	weapon_pistolet = WeaponData.new()
	
	weapon_fusil = WeaponData.new()
	weapon_fusil.name = "Fusil"
	weapon_fusil.cooldown = 1.3
	weapon_fusil.bullet_speed = 15000.0
	weapon_fusil.bullet_max_distance = 15000.0
	weapon_fusil.damage_center = 50.0
	weapon_fusil.damage_edge = 25.0
	weapon_fusil.max_bounces = 2
	weapon_fusil.damages_shooter = true
	weapon_fusil.torch_cookie = "fusil"
	weapon_fusil.torch_angle_deg = 10.0
	# 3,5 auparavant. Portées arbitrées par Adrien le 2026-08-24 : chaque joueur
	# voit 480 unités devant lui, et seule l'arbalète a le droit d'éclairer plus
	# loin que ce qu'elle montre. Le fusil tombe à 0,96 écran, le pistolet à 0,85.
	weapon_fusil.torch_scale = 1.8
	
	weapon_pompe = WeaponData.new()
	weapon_pompe.name = "Pompe"
	weapon_pompe.cooldown = 1.2
	weapon_pompe.bullet_speed = 10000.0
	weapon_pompe.bullet_max_distance = 180.0
	weapon_pompe.damage_center = 20.0
	weapon_pompe.damage_edge = 15.0
	weapon_pompe.max_bounces = 0
	weapon_pompe.projectile_count = 5
	weapon_pompe.spread_angles_deg = [0.0, 20.0, -20.0, 60.0, -60.0]
	weapon_pompe.torch_cookie = "pompe"
	weapon_pompe.torch_angle_deg = 60.0
	weapon_pompe.torch_scale = 1.0
	
	weapon_arbalete = WeaponData.new()
	weapon_arbalete.name = "Arbalète"
	weapon_arbalete.cooldown = 1.5
	weapon_arbalete.bullet_speed = 12000.0
	weapon_arbalete.bullet_max_distance = 10000.0
	weapon_arbalete.damage_center = 80.0
	weapon_arbalete.damage_edge = 80.0
	weapon_arbalete.max_bounces = 0
	weapon_arbalete.damages_shooter = false
	weapon_arbalete.emits_light = false
	weapon_arbalete.torch_cookie = "arbalete"
	weapon_arbalete.torch_angle_deg = 5.0 # Très fin
	weapon_arbalete.torch_scale = 3.5     # Aussi loin que le fusil
	weapon_arbalete.torch_brightness = 0.3 # Plus discret / moins lumineux
	
	weapon_arbalete.muzzle_flash_intensity = 0.1
	weapon_arbalete.muzzle_flash_duration = 0.05
	weapon_arbalete.backlight_multiplier = 0.1
	weapon_arbalete.movement_speed_while_reloading = 0.5
	weapon_arbalete.can_run_while_reloading = false
	# L'arbalète est la seule arme qui n'émet pas de lumière : son carreau est de
	# l'acier froid, jamais du feu. C'est ce qui la rend furtive, et la charte le
	# dit maintenant au lieu de le laisser à un gris anonyme.
	weapon_arbalete.bullet_color = Color(Charte.ACIER, 1.0)
	weapon_arbalete.bullet_width = 3.0
	weapon_arbalete.bullet_light_energy = 0.0
	
	ReplaySystem.replay_spawn_bullet.connect(_on_replay_spawn_bullet)
	ui.replay_requested.connect(_on_replay_requested)
	ui.join_requested.connect(_on_join_requested)
	ui.training_requested.connect(_on_training_requested)
	ui.pick_window_cancelled.connect(_on_pick_window_cancelled)
	ui.quit_requested.connect(_on_quit_requested)
	ui.main_menu_requested.connect(_on_main_menu_requested)
	
	# Set global clear color to black to fix gray areas
	RenderingServer.set_default_clear_color(Charte.NOIR)
	
	# Share the world_2d for split screen
	vp2.world_2d = vp1.world_2d
	
	NetworkManager.player_connected.connect(_on_peer_connected)
	NetworkManager.player_disconnected.connect(_on_peer_disconnected)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connection_success.connect(_on_connection_success)

	# L'appariement établit le lien lui-même, puis annonce. Sans cet abonnement il
	# n'annonçait à personne : les deux machines se connectaient et restaient dans
	# leurs menus, l'appariement « marchant » sans qu'aucune manche ne démarre.
	var appariement := get_node_or_null(^"/root/Matchmaker")
	if appariement != null and appariement.has_signal("match_ready"):
		appariement.match_ready.connect(_on_match_ready)

	rebuild_arena()
	_setup_players()
	_setup_ghosts()
	_setup_particle_pool()
	_setup_training_target()
	
	# Setup Killcam Overlay to sit between background and players/bullets
	var killcam_bb = BackBufferCopy.new()
	killcam_bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	killcam_bb.z_index = 2
	killcam_bb.name = "KillcamBB"
	killcam_bb.hide()
	arena.add_child(killcam_bb)
	
	ui.killcam_overlay.z_index = 2
	ui.killcam_overlay.name = "KillcamOverlay"
	ui.killcam_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.killcam_overlay.size = Vector2(20000, 20000)
	ui.killcam_overlay.position = Vector2(-10000, -10000)
	arena.add_child(ui.killcam_overlay)
	
	ui.show_main_menu()

func _on_peer_connected(id: int):
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		client_peer_id = id
		p2.reset_network_input()
		# Celui qui arrive a manqué l'annonce : on la lui refait. Sans ça, un
		# client qui rejoint un hôte déjà prêt attendrait sans jamais l'apprendre.
		_annoncer_etat_hote()
		# **L'hôte reste dans son salon.** Il y voit « Adversaire — connecté »
		# apparaître dans la liste, et le match attend que les deux appuient sur
		# PRÊT.
		#
		# Ce n'était pas le cas avant : cette fonction faisait quitter le menu, dans
		# un temps où `rpc_client_weapon` lançait la manche dans la foulée. La porte
		# PRÊT a retiré ce lancement — à juste titre — et les deux changements
		# combinés laissaient l'hôte **dans l'arène sans manche démarrée**. Comme il
		# simule les deux joueurs et porte le chrono, les DEUX fenêtres se figeaient.
		# Aucun des deux changements n'était fautif seul ; c'est leur rencontre qui
		# l'était, et le commentaire d'ici énonçait l'hypothèse que l'autre venait
		# d'invalider.
		#
		# Rien à préparer ici, donc : `_apply_network_mode()` est appelé par
		# `_enter_hosted_game()` au moment du départ, et lui seul sait quand il a
		# vraiment lieu.

		# Arrivée pendant une killcam ou l'écran de fin : lancer la manche ici
		# couperait la séquence en cours des deux côtés.
		if _end_sequence_active:
			_pending_client_start = true
			return
		# La manche n'est PAS lancée ici : elle attend rpc_client_weapon. Partir
		# avant l'arrivée de ce paquet imposait le pistolet à P2 pour tout le
		# match — en BO1 aucun rematch ne vient rattraper le choix.

## Le pair a disparu. **Sa killcam en cours, elle, va jusqu'au bout.**
##
## Décision d'Adrien (2026-08-19) : « on laisse terminer sa killcam même si
## l'autre joueur se déconnecte ». La checklist le demandait depuis toujours —
## « ni coupée, ni accélérée, ni recouverte par un écran d'attente » — et le code
## faisait l'inverse.
##
## **Ce n'était pas une ligne à retirer.** Cinq gestes de ce chemin écrasaient la
## killcam qu'on veut préserver : le jeton qui rend la séquence caduque,
## `_end_sequence_active = false`, la restauration des vues, le dialogue qui la
## recouvre, et le passage en bac à sable sous elle. La forme juste est de
## **différer** tout ce qui touche à l'écran.
##
## **Reste immédiat, et doit le rester** : l'archivage du forfait — il lit des
## valeurs que la suite efface — et la purge de P2, sans laquelle l'hôte
## continuerait à le simuler sur sa dernière commande, torche allumée, pendant
## toute la killcam. Un adversaire parti ne doit pas continuer d'éclairer.
func _on_peer_disconnected(id: int):
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		# Avant toute remise à zéro : l'enregistrement lit les armes, le chrono et
		# le mode, que la suite de cette fonction efface.
		_archive_forfeit(0)
		if id == client_peer_id:
			client_peer_id = 0
		# L'hôte simule P2 : sans purge il continuerait à courir sur la dernière
		# commande reçue. Immédiat même pendant une killcam — c'est de la
		# simulation, pas de l'affichage.
		p2.reset_network_input()
		p2.velocity = Vector2.ZERO
		p2.is_sprinting = false
		p2.flashlight_on = false
		if _end_sequence_active:
			# Une killcam est en cours : on ne touche à rien de ce qu'elle montre.
			# La suite se déroulera à sa fin, dans `_annoncer_deconnexion()`.
			_deconnexion_differee = true
			return
		_annoncer_deconnexion()
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		# Côté client, c'est l'HÔTE qui est parti : il n'y a plus de partie à
		# préserver, seulement un menu où retourner.
		_on_main_menu_requested()

## La partie « écran » de la déconnexion, différée si une killcam la couvrait.
func _annoncer_deconnexion() -> void:
	_deconnexion_differee = false
	# **Quelqu'un a pu revenir pendant la killcam.** L'annonce est différée
	# jusqu'à sa fin ; entre-temps, le joueur peut avoir relancé son jeu et
	# rejoint — c'est le scénario 4.1 de la checklist. Annoncer alors « le
	# Joueur 2 s'est déconnecté » et repasser en attente **coupe le lien qu'on
	# vient d'accepter** : le nouveau venu se retrouve sans pair, et son premier
	# RPC échoue.
	#
	# Défaut introduit par le report lui-même, et trouvé par le banc de la
	# famille 4.1 — le report a créé une fenêtre où le monde peut changer, et le
	# code différé la traversait sans regarder.
	var revenu := not multiplayer.get_peers().is_empty()
	# Toute séquence de fin en vol devient caduque : sans ce jeton elle
	# reviendrait afficher un écran de victoire par-dessus l'attente.
	_round_token += 1
	_end_sequence_active = false
	_pending_client_start = false
	_pending_p2_weapon_idx = -1
	# Un départ interrompu en plein 3-2-1 laisserait countdown_left figé, donc
	# l'hôte immobile pour toujours dans son bac à sable.
	countdown_left = 0.0
	ui.set_countdown(0.0)
	ui.force_close_pause()
	_abort_killcam()
	_restore_viewports()
	if not revenu:
		ui.show_dialog_message("Déconnexion", "Le Joueur 2 s'est déconnecté.",
			UI.Registre.ATTENTION)
	round_active = false
	sandbox_mode = true
	p2_ready_for_rematch = false
	# Un « ✓ PRÊT » resté armé attendrait un adversaire qui n'existe plus.
	p1_ready_for_rematch = false
	_hote_pret = false
	local_ready_for_rematch = false
	ui.btn_replay.text = "REJOUER"
	ui.btn_replay.remove_theme_color_override("font_color")
	p1_session_wins = 0
	p2_session_wins = 0
	serie_porteur = -1
	serie_longueur = 0
	_mot_de_serie = ""
	p1_round_wins = 0
	p2_round_wins = 0
	p2.hide()
	p2.set_collision_layer_value(1, false)
	p2.set_collision_mask_value(1, false)
	_set_training_target_active(true)
	# **Le retour au salon a lieu dans TOUS les cas.** C'est lui qui ramène le
	# menu ; le sauter laissait l'hôte dans l'arène sans salon, donc sans aucun
	# moyen de se déclarer prêt — un joueur revenu trouvait la porte fermée.
	# Défaut introduit en voulant justement épargner l'attente à qui n'attendait
	# plus, et attrapé par le banc de la famille 4.1.
	#
	# Seul le MESSAGE dépend de la situation : on n'annonce pas une attente à
	# quelqu'un dont l'adversaire est déjà là.
	ui.show_waiting_for_opponent()
	ui.time_label.text = "EN ATTENTE DU JOUEUR 2..." if not revenu else "PRÊT ?"
	# **Et c'est CETTE ligne qui ramène le menu, pas celle du dessus.** Le
	# commentaire ci-dessus a longtemps affirmé que `show_waiting_for_opponent()`
	# s'en chargeait ; elle n'allume qu'un label du HUD de match, et le panneau
	# restait éteint — l'hôte se retrouvait dans son arène sans aucun moyen de se
	# déclarer prêt. Trois sondes ont été nécessaires pour l'établir, contre un
	# mécanisme concurrent parfaitement cohérent et faux.
	ui.rouvrir_le_salon()
	game_over = false



## Entraînement solitaire : une arène, une cible, aucun adversaire.
##
## Trois propriétés que rien ne doit venir contredire :
##
## **Rien n'est archivé ni rapporté.** Un entraînement n'est pas un match : il
## n'entre ni dans le journal local, ni dans le classement. C'est la seule
## propriété non négociable ici — le reste n'est que confort.
##
## **Le lien réseau tombe d'abord.** Sans cela, un hôte qui s'entraîne ferait
## apparaître une cible chez un adversaire qui n'a rien demandé, et le forfait de
## départ s'appliquerait à un match qui n'a jamais commencé.
##
## **La carte est celle par défaut** (décision d'Adrien) : on s'entraîne sur le
## terrain de référence, pas sur la dernière carte custom essayée.
func _on_training_requested() -> void:
	get_tree().paused = false
	# Avant toute chose : un match en cours doit se solder normalement, forfait
	# compris, plutôt que de se dissoudre dans un entraînement.
	if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		_archive_forfeit(0)
		NetworkManager.disconnect_from_game()
	_apply_network_mode()
	MapData.select_map(MapData.DEFAULT_MAP_ID)
	_matchmade_round = false

	game_over = false
	ui.hide_game_over()
	_restore_viewports()
	# On passe par le démarrage ordinaire : arène, joueurs, armes, vues et
	# caméras sont posés par le chemin que le jeu emprunte déjà, plutôt que par
	# un second qui finirait par en diverger. La manche est désarmée juste après.
	_do_start_round(_hosted_weapon_1_idx, 0)

	round_active = false
	sandbox_mode = true
	# Après `_do_start_round`, qui le remet à faux : c'est lui qui vient de poser
	# l'arène, et il ne peut pas savoir qu'on l'a appelé pour un entraînement.
	training_mode = true
	_restore_viewports()
	# Aucun forfait ne peut naître d'un entraînement : il n'y a personne en face.
	_forfeit_pending = false
	_match_id = ""
	time_left = round_time
	ui.set_countdown(0.0)
	countdown_left = 0.0
	ui.reinitialiser_chrono()
	ui.time_label.text = "ENTRAÎNEMENT"

	# J2 quitte la scène sans être détruit : il reprendra sa place au prochain
	# vrai match, et le détruire demanderait de le reconstruire.
	p2.hide()
	p2.set_collision_layer_value(1, false)
	p2.set_collision_mask_value(1, false)
	_set_training_target_active(true)

	# L'oreille se repose ICI, et pas seulement dans `_do_start_round` : c'est le
	# premier endroit de ce chemin où `training_mode` est enfin vrai. Sans ce
	# second appel, l'entraînement — seul mode solo du jeu, donc le seul où l'on
	# puisse doser un réglage sonore sans monter deux instances — resterait sur
	# l'oreille fixe. Voir `_accorder_oreille`.
	_accorder_oreille()

func _on_debug_light_toggled(toggled_on: bool):
	var mod = arena.get_node_or_null("CanvasModulate")
	if mod:
		mod.color = Charte.NOIR.lerp(Charte.ACIER, 0.38) if toggled_on else Charte.NOIR

## Construit l'arène depuis la carte sélectionnée.
##
## Tout passe par le pipeline JSON, y compris l'arène standard : le double
## chemin « géométrie codée en dur / carte custom » de la version précédente
## était la source des divergences (murs sans occluder, tuiles invisibles en
## écran partagé). Un seul chemin, donc un seul comportement à garantir.
##
## Appelable à volonté — chaque manche la rappelle, ce qui permet de changer
## de carte depuis le menu sans redémarrer la partie.
func rebuild_arena() -> void:
	var data: Dictionary = MapData.get_selected()
	if data.is_empty():
		push_error("GameState: aucune carte à charger")
		return

	# S2 — la portée des sons se dérive de la carte qu'on vient de choisir, ici
	# et nulle part ailleurs : c'est le seul endroit qui connaît sa taille et qui
	# est rappelé à chaque manche, donc le seul qui suive un changement de carte
	# depuis le menu. Une portée écrite en dur redeviendrait fausse à la première
	# carte d'une autre taille, et rien ne le dirait.
	AudioManager.accorder_a_la_carte(MapCodec.get_grid_size(data),
		CandelaTileSet.TILE_SIZE)

	# La géométrie historique de arena.tscn ne sert plus qu'à documenter le
	# format ; elle est neutralisée pour ne pas doubler la carte JSON.
	var static_geom := arena.get_node_or_null("StaticGeometry")
	if static_geom:
		static_geom.hide()
		static_geom.process_mode = Node.PROCESS_MODE_DISABLED
		for child in static_geom.get_children():
			if child is CollisionObject2D:
				child.process_mode = Node.PROCESS_MODE_DISABLED
	var ground := arena.get_node_or_null("Ground")
	if ground:
		ground.hide()

	# Purge de la construction précédente (rematch, changement de carte).
	for node_name in ["CustomFloor", "CustomWalls", "CustomFloor_P1", "CustomFloor_P2",
			"CustomWalls_P1", "CustomWalls_P2", "CustomWallBodies"]:
		var previous := arena.get_node_or_null(node_name)
		if previous:
			arena.remove_child(previous)
			previous.queue_free()

	var tileset := CandelaTileSet.create_tileset()

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "CustomFloor"
	floor_layer.tile_set = tileset
	floor_layer.z_index = -1
	arena.add_child(floor_layer)

	var walls_layer := TileMapLayer.new()
	walls_layer.name = "CustomWalls"
	walls_layer.tile_set = tileset
	walls_layer.z_index = 0
	arena.add_child(walls_layer)

	var spawns := arena.get_node_or_null("SpawnPoints")
	if spawns == null:
		spawns = Node2D.new()
		spawns.name = "SpawnPoints"
		arena.add_child(spawns)
	_ensure_spawn_marker(spawns, "P1Spawn")
	_ensure_spawn_marker(spawns, "P2Spawn")

	MapData.apply_to_layers(floor_layer, walls_layer, spawns, data)

	# Collisions ET occluders produits ensemble à partir des mêmes rectangles.
	# Sans les occluders, la torche traverse les murs et le jeu perd son sujet.
	MapGeometry.build_collisions(data, arena)

	# Écran partagé : chaque joueur reçoit sa copie des calques, éclairée par
	# sa seule lumière ambiante. Sans ça, le halo d'un joueur révélerait sa
	# position sur l'écran de l'autre.
	_duplicate_layer_for_player(floor_layer, 2, 1 | 16)
	_duplicate_layer_for_player(floor_layer, 4, 1 | 32)
	_duplicate_layer_for_player(walls_layer, 2, 1 | 16)
	_duplicate_layer_for_player(walls_layer, 4, 1 | 32)

	# Rendu néon des murs (l'original reste visible des deux viewports).
	var wall_mat := CanvasItemMaterial.new()
	wall_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	walls_layer.material = wall_mat

## Duplique un calque pour un seul viewport, avec son masque de lumière propre.
func _duplicate_layer_for_player(layer: TileMapLayer, visibility: int, light_mask: int) -> void:
	var copy := layer.duplicate() as TileMapLayer
	copy.name = "%s_P%d" % [layer.name, 1 if visibility == 2 else 2]
	copy.visibility_layer = visibility
	copy.light_mask = light_mask
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	copy.material = mat
	arena.add_child(copy)

func _ensure_spawn_marker(spawns: Node2D, marker_name: String) -> void:
	if spawns.get_node_or_null(marker_name) == null:
		var marker := Marker2D.new()
		marker.name = marker_name
		spawns.add_child(marker)


## Les nœuds ajoutés ici portent des noms EXPLICITES, et c'est une contrainte
## réseau, pas une coquetterie.
##
## Sans nom, Godot en fabrique un depuis un compteur global d'objets créés
## (« @CharacterBody2D@269 »), dont la valeur dépend de tout ce qui a été
## instancié avant — jusqu'au nombre de cartes dans la bibliothèque, la galerie
## construisant un panneau par carte. Deux machines aux bibliothèques
## différentes donnaient donc deux noms différents au même joueur.
##
## Or un RPC de scène ne se route que par le chemin du nœud : les commandes du
## client désignaient chez l'hôte un nœud inexistant et étaient jetées sans le
## moindre message — l'adversaire restait figé sur son apparition alors que le
## lien, le ping et les identifiants de pairs étaient tous parfaitement sains.
func _setup_players():
	p1 = player_scene.instantiate()
	p1.name = "Player1"
	p1.player_id = 0
	players_node.add_child(p1)

	p2 = player_scene.instantiate()
	p2.name = "Player2"
	p2.player_id = 1
	players_node.add_child(p2)

	# Cameras (Top Level so they can follow ghosts during replay)
	cam1 = Camera2D.new()
	cam1.name = "Camera1"
	cam1.custom_viewport = vp1
	players_node.add_child(cam1)

	cam2 = Camera2D.new()
	cam2.name = "Camera2"
	cam2.custom_viewport = vp2
	players_node.add_child(cam2)
	
	# Restrict viewports so they don't see each other's private layers
	vp1.canvas_cull_mask = ~4 # Hide layer 3 (value 4) which belongs to P2
	vp2.canvas_cull_mask = ~2 # Hide layer 2 (value 2) which belongs to P1

func _set_player_input_provider(player: Player, provider: InputProvider, device: int = 0) -> void:
	if is_instance_valid(player.input_provider):
		player.input_provider.queue_free()
	if provider is LocalInputProvider:
		provider.device_id = device
	player.input_provider = provider
	player.add_child(provider)

func _apply_network_mode():
	if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN or not multiplayer.has_multiplayer_peer():
		p1.set_multiplayer_authority(1)
		p2.set_multiplayer_authority(1)
		
		_set_player_input_provider(p1, LocalInputProvider.new(), 0)
		_set_player_input_provider(p2, LocalInputProvider.new(), 1)
		
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		# L'hôte simule les deux joueurs : il garde l'autorité sur P1 ET P2, et
		# ne fait que consommer les inputs du client pour P2.
		p1.set_multiplayer_authority(1)
		p2.set_multiplayer_authority(1)

		_set_player_input_provider(p1, LocalInputProvider.new(), 0)
		_set_player_input_provider(p2, NetworkInputProvider.new(), 1)

		var peers = multiplayer.get_peers()
		client_peer_id = peers[0] if peers.size() > 0 else 0

	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		# Tout est répliqué depuis l'hôte ; le provider local de P2 ne sert plus
		# qu'à échantillonner les commandes envoyées via rpc_send_inputs.
		p1.set_multiplayer_authority(1)
		p2.set_multiplayer_authority(1)
		client_peer_id = 0

		_set_player_input_provider(p1, NetworkInputProvider.new(), 0)
		_set_player_input_provider(p2, LocalInputProvider.new(), 0)

func _setup_ghosts():
	var unshaded_mat = ShaderMaterial.new()
	unshaded_mat.shader = SHADER_GHOST
	
	ghost_p1 = Node2D.new()
	ghost_p1.name = "GhostP1"
	ghost_p1.z_index = 10
	var g1_vis = p1.get_node("VisualColored").duplicate()
	g1_vis.material = unshaded_mat
	g1_vis.color.a = 0.5
	g1_vis.visibility_layer = 1 # Force visible to all cameras
	ghost_p1.add_child(g1_vis)
	var l1 = p1.get_node("Flashlight").duplicate()
	l1.name = "Light"
	ghost_p1.add_child(l1)
	var f1 = p1.get_node("MuzzleFlash").duplicate()
	f1.name = "Flash"
	ghost_p1.add_child(f1)
	players_node.add_child(ghost_p1)
	ghost_p1.hide()
	
	ghost_p2 = Node2D.new()
	ghost_p2.name = "GhostP2"
	ghost_p2.z_index = 10
	var g2_vis = p2.get_node("VisualColored").duplicate()
	g2_vis.material = unshaded_mat
	g2_vis.color.a = 0.5
	g2_vis.visibility_layer = 1 # Force visible to all cameras
	ghost_p2.add_child(g2_vis)
	var l2 = p2.get_node("Flashlight").duplicate()
	l2.name = "Light"
	ghost_p2.add_child(l2)
	var f2 = p2.get_node("MuzzleFlash").duplicate()
	f2.name = "Flash"
	ghost_p2.add_child(f2)
	players_node.add_child(ghost_p2)
	ghost_p2.hide()



## Réserve de particules. Placée hors de l'arène et hors du conteneur de
## balles : ces deux nœuds sont purgés à chaque manche et au retour au menu.
func _setup_particle_pool() -> void:
	particle_pool = ParticlePool.new()
	particle_pool.name = "ParticlePool"
	arena.get_parent().add_child(particle_pool)

func _setup_training_target() -> void:
	training_target = TrainingTarget.new()
	training_target.name = "TrainingTarget"
	arena.get_parent().add_child(training_target)
	training_target.hide()
	training_target.process_mode = Node.PROCESS_MODE_DISABLED

## Affiche ou masque la cible d'échauffement. Elle n'existe qu'en bac à sable —
## en manche, elle bloquerait les balles.
func _set_training_target_active(active: bool) -> void:
	if not is_instance_valid(training_target): return
	training_target.visible = active
	training_target.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	training_target.set_collision_layer_value(1, active)
	training_target.reset_damage()
	if active:
		training_target.global_position = _training_target_position()

## La cible se tient exactement là où l'adversaire se tiendrait — au point
## d'apparition de J2.
##
## C'est ce qui rend l'entraînement transférable : la distance, l'angle et la
## ligne de vue qu'on y travaille sont ceux du premier échange d'un vrai duel. Un
## décalage devant J1, ou une recherche de sol libre au plus proche, donnerait un
## placement plausible mais qui n'existe dans aucun match.
##
## La cible mouvante viendra plus tard, avec ses réglages (décision d'Adrien) ;
## jusque-là elle est fixe, et fixe à cet endroit-là.
func _training_target_position() -> Vector2:
	# Exactement le point d'apparition, sans recherche de sol libre : c'est une
	# case où un joueur apparaît, donc praticable par construction. Chercher « au
	# plus proche » déplacerait la cible de quelques dizaines de pixels et
	# ruinerait la seule propriété qu'on lui demande — se tenir là où l'adversaire
	# se tiendra.
	return _get_spawn_position(1)

func _get_spawn_position(player_id: int) -> Vector2:
	var spawn_node_name := "P1Spawn" if player_id == 0 else "P2Spawn"

	if is_instance_valid(arena):
		var spawns = arena.get_node_or_null("SpawnPoints")
		if is_instance_valid(spawns):
			var node = spawns.get_node_or_null(spawn_node_name)
			# Un marqueur parqué hors écran signale une apparition non posée.
			if is_instance_valid(node) and node.global_position.x > -500.0:
				return node.global_position

		# Repli : on relit directement la carte plutôt que d'inventer une
		# position en dur, qui atterrirait probablement dans un mur.
		var layer := arena.get_node_or_null("CustomFloor") as TileMapLayer
		if is_instance_valid(layer):
			return MapData.get_spawn_world_position(player_id, layer)

	return Vector2(200, 200) if player_id == 0 else Vector2(800, 600)

func _start_round():
	var w1_idx = 0
	if ui.p1_weapon_group.get_pressed_button():
		w1_idx = ui.p1_weapon_group.get_pressed_button().get_index()
	var w2_idx = 0
	if ui.p2_weapon_group.get_pressed_button():
		w2_idx = ui.p2_weapon_group.get_pressed_button().get_index()

	_restore_viewports()
	p1.global_position = _get_spawn_position(0)
	p2.global_position = _get_spawn_position(1)
	p1.rotation = 0
	p2.rotation = PI
	p1.show_all_visuals()
	p2.show_all_visuals()
	p1.get_node("VisualColored").show()
	p1.get_node("VisualDim").show()
	p1.get_node("VisualReveal").show()
	p2.get_node("VisualColored").show()
	p2.get_node("VisualDim").show()
	p2.get_node("VisualReveal").show()
	cam1.global_position = p1.global_position
	cam2.global_position = p2.global_position
	p1.reset_step_tracker()
	p2.reset_step_tracker()

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		if multiplayer.get_peers().size() == 0:
			round_active = false
			sandbox_mode = true
			ui.time_label.text = MatchRecord.format_clock(round_time)
			_set_training_target_active(true)
			ui.show_waiting_for_opponent()
			ui.hide_game_over()
			p2.hide()
			p2.set_collision_layer_value(1, false)
			p2.set_collision_mask_value(1, false)
			_hosted_weapon_1_idx = w1_idx
			return
		else:
			rpc_start_round.rpc(w1_idx, w2_idx, _host_map_code(), _new_match_id())
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return # Client ne démarre pas la logique locale
	else:
		_do_start_round(w1_idx, w2_idx)

@rpc("authority", "call_local", "reliable")
func rpc_start_round(w1_idx: int, w2_idx: int, map_code: String = "", match_id: String = ""):
	_match_id = match_id
	# Le client adopte la carte de l'hôte : sans ça les deux joueurs
	# s'affronteraient sur des géométries différentes.
	#
	# Et s'il n'y arrive pas, **la manche ne commence pas.** Le code affichait
	# auparavant un message puis démarrait quand même : chacun jouait alors sur sa
	# propre arène, les balles traversant des murs absents chez l'un, la torche
	# éclairant une géométrie que l'autre n'a pas. Les deux machines restent
	# cohérentes avec elles-mêmes — aucun plantage, aucune erreur — et les deux
	# joueurs se croient trichés. Mieux vaut refuser à la porte.
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		var err := _adopt_host_map(map_code)
		if err != "":
			_refuse_match_on_map(err)
			return
	_do_start_round(w1_idx, w2_idx)

## Adopte la carte annoncée par l'hôte. Rend la raison de l'échec, ou "".
##
## Un code vide **est** un échec, et c'était le cas le plus sournois : la garde
## `if map_code != ""` le traitait comme « rien à faire », donc l'invité entrait
## dans la manche sur sa carte précédente sans même un message. Une absence de
## carte ne veut pas dire « garde la tienne », elle veut dire « je ne sais pas sur
## quoi je joue ».
func _adopt_host_map(map_code: String) -> String:
	if map_code.is_empty():
		return "l'hôte n'a annoncé aucune carte"
	return MapData.adopt_shared_map(map_code)

## [Client] Sort du match parce que l'arène est illisible, sans le compter comme
## un abandon.
##
## `_forfeit_pending` n'est armé que par `_do_start_round`, et on n'y est jamais
## arrivé : `_on_main_menu_requested()` peut donc faire le ménage habituel sans
## rien archiver. Compter un forfait ici punirait un joueur d'un écart de version.
##
## L'hôte est prévenu **avant** la déconnexion, qui coupe le lien : sans ce
## paquet il resterait seul dans son arène à attendre un adversaire déjà parti,
## et finirait par lui compter la victoire.
func _refuse_match_on_map(reason: String) -> void:
	if multiplayer.has_multiplayer_peer():
		rpc_id(1, "rpc_map_refused", reason)
	_on_main_menu_requested()
	ui.show_dialog_message("Arène incompatible",
		("Impossible de lire l'arène de l'hôte : %s.\n\nLa partie n'a pas démarré — "
		+ "mieux vaut cela que deux joueurs sur deux terrains différents. La cause "
		+ "la plus courante est un écart de version entre les deux jeux.") % reason,
		UI.Registre.FAUTE)

## [Hôte] L'adversaire a refusé la carte et s'en va. Le lui dire, sinon l'hôte
## attribue son départ à une déconnexion et lui compte le match.
@rpc("any_peer", "reliable")
func rpc_map_refused(reason: String):
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
		return
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id:
		return
	# Le départ qui suit ne doit pas être archivé comme un abandon de l'adversaire.
	_forfeit_pending = false
	ui.show_dialog_message("Arène refusée",
		("Votre adversaire n'a pas pu lire l'arène (%s) et a quitté.\n\nEssayez une "
		+ "carte livrée avec le jeu, ou vérifiez que vous avez la même version.") % reason,
		UI.Registre.ATTENTION)

## [Hôte] Tire l'identifiant du match qui commence.
##
## 16 octets d'un générateur cryptographique, en hexadécimal. Pas parce qu'il
## faudrait un secret — il transite en clair — mais parce qu'un compteur ou une
## horloge se devinerait, et qu'un tiers pourrait alors déposer son propre récit
## sur le match de deux inconnus.
func _new_match_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

## Code compact de la carte active, à joindre au démarrage de manche.
## Vide hors mode hôte : personne d'autre n'a autorité sur la carte.
func _host_map_code() -> String:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		return MapData.get_map_share_code()
	return ""

func _do_start_round(w1_idx: int, w2_idx: int):
	# Une vraie manche met fin à l'entraînement : sans cela, la vue resterait
	# unique dans un duel en écran partagé.
	training_mode = false
	# Toute séquence de fin encore en vol doit lâcher la main ici.
	_round_token += 1
	_end_sequence_active = false
	_pending_client_start = false
	_pending_p2_weapon_idx = -1
	_abort_killcam()
	ui.force_close_pause()

	# Reconstruit l'arène à chaque manche : c'est ce qui rend effectif un
	# changement de carte depuis le menu, sans redémarrer le jeu.
	rebuild_arena()
	sandbox_mode = false
	# Un vrai match en ligne commence ici, et ici seulement : l'hôte resté seul
	# n'atteint jamais ce point, il repart en bac à sable plus haut. À partir de
	# maintenant, partir coûte le match.
	_forfeit_pending = NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_set_training_target_active(false)
	if is_instance_valid(particle_pool):
		particle_pool.clear_all()
	p2.show()
	p2.set_collision_layer_value(1, true)
	p2.set_collision_mask_value(1, true)
	ui.waiting_label.hide()
	ui.hide_game_over()
	local_ready_for_rematch = false
	ui.btn_replay.text = "REJOUER"
	ui.btn_replay.remove_theme_color_override("font_color")
	game_over = false
	_restore_viewports()
	ui.hide_killcam()
	AudioManager.set_in_match(true)
	_accorder_oreille()
	AudioManager.reset_low_health()
	AudioManager.play_music("music_match")

	p1.show_all_visuals()
	p2.show_all_visuals()

	p1.hp = 100.0
	p2.hp = 100.0
	p1.dead = false
	p2.dead = false
	# Les yeux repartent neufs : un éblouissement pris à la dernière seconde
	# d'une manche n'a rien à faire dans la suivante.
	p1.dazzle_amount = 0.0
	p2.dazzle_amount = 0.0
	
	p1.equip_weapon(weapon_for_index(w1_idx))
	p2.equip_weapon(weapon_for_index(w2_idx))
	
	p1.get_node("VisualColored").show()
	p1.get_node("VisualDim").show()
	p1.get_node("VisualReveal").show()
	p2.get_node("VisualColored").show()
	p2.get_node("VisualDim").show()
	p2.get_node("VisualReveal").show()
	
	p1.global_position = _get_spawn_position(0)
	p2.global_position = _get_spawn_position(1)
	p1.rotation = 0
	p2.rotation = PI
	# Après la téléportation au spawn : le détecteur de pas et la distance du
	# tir fatal repartent de zéro (pas fantôme et « à N px » périmé sinon).
	p1.reset_step_tracker()
	p2.reset_step_tracker()
	time_left = round_time
	round_active = true
	game_over = false
	# Le chrono repart en blanc : sans ça, une manche qui suit une fin de match
	# hérite de l'or ou du rouge de la précédente jusqu'au premier passage de
	# seuil — soit pendant ses quatre premières minutes.
	ui.reinitialiser_chrono()
	Engine.time_scale = 1.0
	# Départ figé des deux côtés : le décompte absorbe le trajet de rpc_start_round.
	countdown_left = COUNTDOWN_MATCHMADE if _matchmade_round else COUNTDOWN_DURATION
	_countdown_ready_local = false
	_countdown_ready_peer = false
	# La fenêtre de choix s'ouvre avec le décompte, et seulement pour un match
	# apparié : ailleurs l'arme est déjà choisie, un panneau modal ne ferait
	# qu'arrêter le joueur devant une question déjà répondue.
	if _matchmade_round:
		ui.show_pick_window(matchmade_arsenal(), matchmade_arsenal_reason())
	else:
		ui.hide_pick_window()
	ui.set_countdown(countdown_left)
	_time_sync_accum = 0.0
	_predicted_shots.clear()
	_pos_history.clear()
	ghost_p1.hide()
	ghost_p2.hide()
	for c in bullet_container.get_children():
		c.queue_free()
	ReplaySystem.start_recording()
	
	# Entre deux manches : le même bilan, sans la série — elle ne se proclame
	# qu'une fois le match joué.
	ui.poser_bilan(p1_session_wins, p2_session_wins)

func _process(delta):
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		_record_position_history()

	if round_active:
		if countdown_left > 0.0:
			# Les deux prêts abrègent la fenêtre. L'hôte tranche seul : il porte le
			# chronomètre, et laisser chaque camp décider produirait deux départs
			# décalés d'un aller-retour.
			if _matchmade_round and _countdown_ready_local and _countdown_ready_peer \
					and NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
				countdown_left = 0.0
			countdown_left = maxf(0.0, countdown_left - delta)
			ui.set_countdown(countdown_left)
			if countdown_left <= 0.0:
				# Le décompte fini, l'arme est celle avec laquelle on joue : la
				# fenêtre se referme d'elle-même, sans rien demander.
				ui.hide_pick_window()
				AudioManager.play_speaker("spk_fight")
				# Le décompte du client a démarré un demi aller-retour plus tard :
				# on recale son chronomètre dès le départ plutôt que d'attendre
				# le prochain envoi périodique.
				if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
					rpc_sync_time.rpc(time_left)
		else:
			time_left -= delta
			if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
				_time_sync_accum += delta
				if _time_sync_accum >= TIME_SYNC_INTERVAL:
					_time_sync_accum = 0.0
					rpc_sync_time.rpc(time_left)
			if time_left <= 0:
				time_left = 0
				if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
					rpc_end_round.rpc(-1)
				elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
					pass
				else:
					_do_end_round(-1)

		_update_music_intensity()

		
	# **Le regard suit le joueur, pas le score.** Ce suivi vivait dans
	# `if round_active:` — c'est-à-dire « une manche COMPTÉE est en cours ». Or
	# l'entraînement désarme volontairement cette manche : la caméra n'était donc
	# jamais mise à jour de toute la session, et le joueur sortait du cadre.
	# Suivre quelqu'un du regard n'a rien à voir avec le fait que ça compte au
	# classement ; c'est l'entraînement, le seul mode qui sépare les deux, qui a
	# révélé la confusion.
	if p1 != null:
		cam1.global_position = p1.global_position
	if p2 != null:
		cam2.global_position = p2.global_position

	# Même raison, un cran plus loin : la RÉCUPÉRATION de l'éblouissement doit
	# continuer pendant la killcam et l'écran de fin, sinon un joueur ébloui à la
	# dernière seconde d'une manche la termine blanc et rouvre les yeux au
	# « FIGHT ! » suivant. Le faisceau, lui, ne verse plus rien : les gardes de
	# `_maj_eblouissement` s'en chargent.
	_maj_eblouissement(delta)

	# V4.12 — le recul de tir décroît de lui-même et s'additionne au shake.
	_cam_kick[0] = _cam_kick[0].move_toward(Vector2.ZERO, delta * 60.0)
	_cam_kick[1] = _cam_kick[1].move_toward(Vector2.ZERO, delta * 60.0)

	if cam1_shake_time > 0:
		cam1_shake_time -= delta
		cam1.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 15.0 + _cam_kick[0]
	else:
		cam1.offset = _cam_kick[0]

	if cam2_shake_time > 0:
		cam2_shake_time -= delta
		cam2.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 15.0 + _cam_kick[1]
	else:
		cam2.offset = _cam_kick[1]
		
	if ReplaySystem.recording:
		ReplaySystem.record_frame(p1, p2, bullet_container, delta)
			
	if ReplaySystem.playing_back:
		current_snap = ReplaySystem.get_next_frame(delta)
		if current_snap:
			ghost_p1.show()
			ghost_p2.show()
			p1.hide_all_visuals()
			p2.hide_all_visuals()
			
			ghost_p1.global_position = current_snap.p1_pos
			ghost_p1.rotation = current_snap.p1_rot
			ghost_p1.visible = current_snap.p1_visible
			ghost_p1.get_node("Light").enabled = current_snap.p1_light
			ghost_p1.get_node("Light").energy = KILLCAM_TORCH_ENERGY
			ghost_p1.get_node("Flash").enabled = current_snap.p1_flash > 0.0
			ghost_p1.get_node("Flash").energy = current_snap.p1_flash
			if current_snap.p1_weapon:
				ghost_p1.get_node("Light").texture = current_snap.p1_weapon.get_torch_texture()
				ghost_p1.get_node("Light").texture_scale = current_snap.p1_weapon.echelle_torche()
			
			ghost_p2.global_position = current_snap.p2_pos
			ghost_p2.rotation = current_snap.p2_rot
			ghost_p2.visible = current_snap.p2_visible
			ghost_p2.get_node("Light").enabled = current_snap.p2_light
			ghost_p2.get_node("Light").energy = KILLCAM_TORCH_ENERGY
			ghost_p2.get_node("Flash").enabled = current_snap.p2_flash > 0.0
			ghost_p2.get_node("Flash").energy = current_snap.p2_flash
			if current_snap.p2_weapon:
				ghost_p2.get_node("Light").texture = current_snap.p2_weapon.get_torch_texture()
				ghost_p2.get_node("Light").texture_scale = current_snap.p2_weapon.echelle_torche()
			
			# Sync real players physical positions for accurate replay collisions
			p1.global_position = current_snap.p1_pos
			p1.rotation = current_snap.p1_rot
			p2.global_position = current_snap.p2_pos
			p2.rotation = current_snap.p2_rot
			
			# Dynamic Camera Zoom & Tracking
			# Cinematic smooth tracking throughout the entire killcam
			var unscaled_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
			var midpoint = (ghost_p1.global_position + ghost_p2.global_position) / 2.0
			var viewport_size = get_viewport().get_visible_rect().size
			var margin = 250.0 # Larger margin so players are visible and not hidden by UI
			
			var dx = max(abs(ghost_p1.global_position.x - ghost_p2.global_position.x), 200.0)
			var dy = max(abs(ghost_p1.global_position.y - ghost_p2.global_position.y), 200.0)
			
			# Only apply extreme cinematic zoom during bullet time!
			var target_zoom_val = 1.0
			var target_pos = midpoint
			
			if Engine.time_scale < 0.9:
				# We are in bullet time! Zoom in hard.
				var zoom_x = viewport_size.x / (dx + margin * 2)
				var zoom_y = viewport_size.y / (dy + margin * 2)
				target_zoom_val = clamp(min(zoom_x, zoom_y), 1.2, 2.8) # Push zoom further
			else:
				# Normal playback: stay zoomed out to see the action
				var zoom_x = viewport_size.x / (dx + margin * 2.5)
				var zoom_y = viewport_size.y / (dy + margin * 2.5)
				target_zoom_val = clamp(min(zoom_x, zoom_y), 0.7, 1.3)
				
			var target_zoom = Vector2(target_zoom_val, target_zoom_val)
			
			if _first_replay_frame:
				cam1.global_position = target_pos
				cam1.zoom = target_zoom
				cam2.global_position = target_pos
				cam2.zoom = target_zoom
				_first_replay_frame = false
			else:
				# Exponential smoothing prevents overshoot and jumping when delta scales wildly in bullet time
				var lerp_speed = 3.0 if Engine.time_scale >= 0.9 else 6.0
				var weight = 1.0 - exp(-lerp_speed * unscaled_delta)
				cam1.global_position = cam1.global_position.lerp(target_pos, weight)
				cam1.zoom = cam1.zoom.lerp(target_zoom, weight)
				cam2.global_position = cam2.global_position.lerp(target_pos, weight)
				cam2.zoom = cam2.zoom.lerp(target_zoom, weight)
			
		# Allow skipping killcam (Indépendant)
		if Input.is_action_just_pressed("p1_skip_killcam"):
			if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
				ReplaySystem.playing_back = false
				Engine.time_scale = 1.0
		if Input.is_action_just_pressed("p2_skip_killcam"):
			if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
				ReplaySystem.playing_back = false
				Engine.time_scale = 1.0
			
	# **Le joueur local passe en PREMIER.** Les deux panneaux ne sont pas « J1 » et
	# « J2 » mais « moi » et « l'autre » : le premier est bleu, le second rouge.
	# Décision d'Adrien (2026-08-19) — « le client devient bleu, c'est l'adversaire
	# qui doit apparaître rouge pour lui ». La couleur suit donc le RÔLE, pas le
	# numéro ; le numéro garde ce qui lui appartient vraiment, le point
	# d'apparition.
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		ui.update_hud(p2, p1, time_left, not training_mode)
	else:
		ui.update_hud(p1, p2, time_left, not training_mode)

## L'éblouissement des deux joueurs, une fois par image et en un seul endroit.
##
## En un seul endroit, c'est le cœur de la correction du 2026-08-18 : la montée
## vivait ici et la descente dans `player._process`, sans condition, quatre fois
## plus forte. Personne n'avait jamais additionné les deux, et l'effet ne
## dépassait pas 0,008 (voir `eblouissement.gd`).
##
## **Autorité : l'hôte**, comme le reste de la simulation. La valeur est
## répliquée (`net_dazzle`) et le client ne la recalcule PAS : il la calculerait
## sur un adversaire interpolé, donc avec 100 ms de retard, et comme
## l'éblouissement pénalise vitesse ET visée, sa prédiction divergerait en
## permanence de l'arbitrage. Prix assumé : le voile blanc arrive chez le client
## avec un demi aller-retour de retard, sur un effet qui dure une seconde.
func _maj_eblouissement(delta: float) -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		return
	var espace := p1.get_world_2d().direct_space_state
	# Les deux plafonds sont lus AVANT d'intégrer : intégrer au fil de la
	# lecture ferait dépendre le résultat de l'ordre des deux joueurs.
	var sur_p1 := _lumiere_recue(espace, p2, p1)
	var sur_p2 := _lumiere_recue(espace, p1, p2)
	p1.integrer_eblouissement(sur_p1, delta)
	p2.integrer_eblouissement(sur_p2, delta)

## Un joueur qui compte : présent, vivant, et sur le terrain.
##
## `visible` n'est pas un détail d'affichage ici, c'est le drapeau « hors jeu » :
## à l'entraînement, J2 est masqué et sorti des collisions mais son nœud continue
## de tourner, manette comprise. Sans ce garde, une touche de torche pressée à
## côté du clavier éblouirait le joueur qui s'entraîne, depuis un adversaire
## invisible — le genre de défaut qu'on passe une soirée à ne pas croire.
func _en_jeu(joueur: Node2D) -> bool:
	return is_instance_valid(joueur) and joueur.visible and not joueur.dead

## Ce que la torche de `source` verse dans les yeux de `cible`, entre 0 et 1.
func _lumiere_recue(espace: PhysicsDirectSpaceState2D, source: Node2D,
		cible: Node2D) -> float:
	if not _en_jeu(source) or not _en_jeu(cible):
		return 0.0
	if not source.flashlight_on:
		return 0.0
	# **On LIT le faisceau, on ne le recalcule pas.** L'image échantillonnée est
	# celle-là même que la lumière projette : elle porte l'angle de l'arme, sa
	# portée, sa luminosité et la matière du cookie, sans qu'aucune de ces
	# quatre choses ait à être recopiée ici. Voir `Vision.intensite_texture`
	# pour les trois divergences que la copie avait produites.
	#
	# **Et pas de faisceau, pas de pénalité** (décision d'Adrien, 2026-08-24).
	# Il y avait ici un repli sur la formule analytique, défendu par un
	# commentaire qui disait qu'une arme sans texture « doit éblouir quand
	# même », sans quoi une torche sans cookie deviendrait silencieusement
	# inoffensive. **C'était le raisonnement à l'envers.** `equip_weapon` pose
	# `flashlight.texture = get_torch_texture()` : sans cookie, la torche ne
	# rend AUCUNE lumière. Le repli faisait donc payer une pénalité pour un
	# faisceau que personne ne voit — très exactement l'incohérence que tout ce
	# chantier a passé sa journée à retirer, et le dernier endroit du jeu qui
	# calculait l'éblouissement depuis autre chose que l'écran.
	#
	# `lumiere_recue()` rend zéro quand l'arme n'a pas d'image, et ce zéro-là
	# est la règle : on ne peut pas être aveuglé par une lampe éteinte.
	#
	# ⚠️ **CE ZÉRO N'EST ACCEPTABLE QUE PARCE QU'IL CRIE AILLEURS, et il ne crie
	# que grâce à UNE ligne** — le `push_error` de
	# `WeaponData.get_torch_texture()` quand le fichier de cookie est
	# introuvable. C'est la seule chose qui distingue « cette arme n'éblouit
	# pas » d'un défaut d'installation.
	#
	# Relevé par la session « assets visuels » le 2026-08-24, et elle a raison :
	# en retirant le repli j'ai rendu sa ligne **porteuse** sans que rien ne le
	# dise. Le jour où quelqu'un la dégrade en `print()` pour nettoyer la
	# console, ou la retire parce qu'« elle ne sert à rien, les cookies sont
	# versionnés », la torche silencieusement inoffensive que le repli
	# prétendait empêcher revient — et cette fois sans repli du tout.
	#
	# **Ne pas retirer ce `push_error` sans le remplacer par plus bruyant.**
	# C'est écrit ici plutôt que là-bas parce que c'est ici que la dépendance
	# existe : le fichier qui lève l'erreur n'a aucune raison de savoir que
	# l'éblouissement s'y adosse.
	var arme: WeaponData = source.current_weapon
	if arme == null:
		return 0.0
	# L'arme sait à quelle échelle son faisceau est étalé ; on ne la lui demande
	# plus. Voir `WeaponData.lumiere_recue()` pour les trois fois où ce choix,
	# laissé à l'appelant, s'est trompé le même jour.
	var intensite := arme.lumiere_recue(source.global_transform.x,
		source.global_position, cible.global_position)
	if intensite <= 0.0:
		return 0.0
	if not _ligne_de_vue(espace, source, cible):
		return 0.0
	# La lumière qui ARRIVE n'est pas la pénalité qu'elle COÛTE. `Vision` rend
	# la première — le pixel du faisceau lui-même ; `Eblouissement.plafond_pour`
	# la convertit en seconde. Sans cette courbe, le dernier tiers du faisceau
	# éclairait visiblement sans presque rien coûter (relevé à l'écran le
	# 2026-08-24, arbitré par Adrien).
	return Eblouissement.plafond_pour(intensite)

## Ligne de vue franche entre deux joueurs. Le rayon suit la LUMIÈRE, pas le
## déplacement : il ne teste que les murs et les joueurs (couche 1). Une fosse
## laisse donc passer le faisceau — on peut éblouir son adversaire par-dessus un
## gouffre, décision de conception couverte par `test_vision`.
func _ligne_de_vue(espace: PhysicsDirectSpaceState2D, source: Node2D,
		cible: Node2D) -> bool:
	var q := PhysicsRayQueryParameters2D.create(source.global_position,
		cible.global_position, MapGeometry.WALL_LAYER)
	q.exclude = [source.get_rid()]
	var res := espace.intersect_ray(q)
	return res and res.collider == cible

## Le flash de tir éblouit celui d'en face (décision du 2026-08-18, avec
## Adrien). Pic instantané, qui passe par-dessus le plafond de la torche et se
## résorbe en un peu plus de deux dixièmes de seconde depuis que la descente a
## été accélérée (2026-08-24) — le modèle de `eblouissement.gd` le permet
## sans cas particulier.
##
## Pas de cône : un canon crache dans toutes les directions. Une ligne de vue,
## en revanche, oui — un mur arrête un flash comme il arrête un faisceau.
func _flash_de_tir(tireur: Node2D) -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return # L'hôte tranche, la valeur est répliquée.
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		return
	var cible: Node2D = null
	if tireur == p1:
		cible = p2
	elif tireur == p2:
		cible = p1
	if cible == null or not _en_jeu(cible) or not _en_jeu(tireur):
		return
	var eclat := 1.0
	var arme: WeaponData = tireur.current_weapon
	if arme:
		eclat = arme.muzzle_flash_intensity
	var pic := Eblouissement.pic_de_flash(
		tireur.global_position.distance_to(cible.global_position), eclat)
	if pic <= 0.0:
		return
	if not _ligne_de_vue(p1.get_world_2d().direct_space_state, tireur, cible):
		return
	cible.apply_dazzle(pic)

func _get_weapon_idx(w: WeaponData) -> int:
	if w == weapon_arbalete: return 3
	if w == weapon_pompe: return 2
	if w == weapon_fusil: return 1
	return 0

## V1.2 — Intensité musicale verticale. Les stems montent avec la tension :
## la dernière minute ajoute la batterie, le double danger de mort ajoute
## l'arpège. Idempotent côté AudioManager : appel chaque frame sans coût.
## Chaque machine évalue localement (les HP des deux joueurs y sont connus),
## c'est cosmétique — aucune autorité en jeu.
const MUSIC_LAST_MINUTE := 60.0
## Aligné sur le seuil du stem « battement de cœur » (update_low_health).
const MUSIC_CLIMAX_HP := 30.0

func _update_music_intensity() -> void:
	var level := 0
	if countdown_left <= 0.0:
		if p1.hp <= MUSIC_CLIMAX_HP and p2.hp <= MUSIC_CLIMAX_HP \
				and not p1.dead and not p2.dead:
			level = 2
		elif time_left <= MUSIC_LAST_MINUTE:
			level = 1
	AudioManager.set_music_intensity(level)

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bullet(shooter_id: int, pos: Vector2, rot: float, weapon_idx: int):
	var shooter = p1 if shooter_id == 0 else p2
	var weapon = weapon_arbalete if weapon_idx == 3 else (weapon_pompe if weapon_idx == 2 else (weapon_fusil if weapon_idx == 1 else weapon_pistolet))
	# Tir déjà rendu par la prédiction locale : seul l'enregistrement killcam
	# reste à faire, sur la trajectoire arbitrée par l'hôte.
	var already_shown := shooter_id == 1 and _consume_predicted_shot(rot)
	_do_spawn_bullet(shooter, pos, rot, weapon, not already_shown)

func spawn_bullet(shooter: Node2D, pos: Vector2, rot: float, weapon: WeaponData):
	if not round_active and not sandbox_mode: return

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		# Le client rend son propre tir sans attendre l'hôte, qui reste seul
		# juge des dégâts et de la cadence réelle.
		if shooter == p2:
			_predicted_shots.append({"t": Time.get_ticks_msec(), "angle": rot})
			_do_spawn_bullet(shooter, pos, rot, weapon, true, false)
		return

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		var w_idx = _get_weapon_idx(weapon)
		rpc_spawn_bullet.rpc(shooter.player_id, pos, rot, w_idx)
	else:
		_do_spawn_bullet(shooter, pos, rot, weapon)

## `spawn_nodes` à faux : la balle a déjà été rendue par la prédiction client,
## on ne garde que l'enregistrement. `record` à faux : balle prédite, elle sera
## enregistrée quand le tir officiel arrivera.
func _do_spawn_bullet(shooter: Node2D, pos: Vector2, rot: float, weapon: WeaponData,
		spawn_nodes: bool = true, record: bool = true):
	if not round_active and not sandbox_mode: return
	var count = weapon.projectile_count if weapon else 1
	var angles = weapon.spread_angles_deg if weapon else [0.0]

	# Les tirs du client sont arbitrés sur ce qu'il voyait : son adversaire est
	# testé à sa position d'alors. Calculé une fois pour toute la volée, le vol
	# d'une balle durant quelques dizaines de millisecondes.
	var lag_center := Vector2.ZERO
	var lag_compensated := spawn_nodes \
		and NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST \
		and shooter == p2
	if lag_compensated:
		lag_center = _rewound_position(p1, _lag_comp_delay())

	for i in range(count):
		var ang_offset = deg_to_rad(angles[i]) if i < angles.size() else 0.0
		var final_rot = rot + ang_offset

		if spawn_nodes:
			var b = bullet_scene.instantiate()
			b.global_position = pos
			b.rotation = final_rot
			b.direction = Vector2(cos(final_rot), sin(final_rot))
			b.source_player = shooter
			if weapon:
				b.weapon = weapon
			if lag_compensated:
				b.lag_target = p1
				b.lag_center = lag_center
			bullet_container.add_child(b)

		if record and ReplaySystem.recording:
			ReplaySystem.record_bullet_fired(shooter.player_id, pos, final_rot, weapon)

	if not spawn_nodes: return

	# D5 (drapeau --fx-shockwave) : onde de distorsion d'air du pompe. UNE par
	# VOLÉE — la boucle des plombs est déjà déroulée — et `count > 1` est la
	# signature même du pompe (projectile_count = 5, seule arme à volée). Placé
	# après le garde spawn_nodes : chez le client, la volée officielle déjà
	# rendue par la prédiction ne rejoue pas l'onde. La killcam passe par
	# _on_replay_spawn_bullet, jamais ici. Hors drapeau, l'appel ne fait rien.
	if count > 1:
		PumpShockwave.spawn_if_enabled(arena, pos)

	if shooter == p1:
		cam1_shake_time = 0.1
		camera_shot_kick(0, Vector2(cos(rot), sin(rot)))
	elif shooter == p2:
		cam2_shake_time = 0.1
		camera_shot_kick(1, Vector2(cos(rot), sin(rot)))

	if shooter.has_method("trigger_shoot_visuals"):
		shooter.trigger_shoot_visuals()

	# Le flash de tir éblouit. Ici et pas dans `trigger_shoot_visuals` : ce site
	# est déjà celui qui ne joue qu'UNE fois par volée (la boucle des plombs du
	# pompe est déroulée au-dessus) et jamais pour la balle officielle d'un tir
	# que le client a déjà rendu — c'est ce que garde `spawn_nodes`. La killcam,
	# elle, passe par `_on_replay_spawn_bullet` : un rejeu n'éblouit personne.
	_flash_de_tir(shooter)

## [Client] Un tir officiel correspond-il à une balle déjà prédite ? Les
## prédictions non confirmées (paquet d'input perdu, tir refusé par l'hôte)
## expirent d'elles-mêmes pour ne pas décaler la file.
func _consume_predicted_shot(angle: float) -> bool:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT: return false
	var ttl := PredictionTir.ttl_ms(NetworkManager.rtt_ms, NetworkManager.has_rtt)
	PredictionTir.purger(_predicted_shots, Time.get_ticks_msec(), ttl)
	var i := PredictionTir.choisir(_predicted_shots, angle)
	if i < 0:
		return false
	_predicted_shots.remove_at(i)
	return true

## [Hôte] Archive la position des deux joueurs pour la compensation de latence.
func _record_position_history() -> void:
	if not is_instance_valid(p1) or not is_instance_valid(p2): return
	var now := Time.get_ticks_msec() / 1000.0
	_pos_history.append({"t": now, "p1": p1.global_position, "p2": p2.global_position})
	while _pos_history.size() > 1 and now - _pos_history[0]["t"] > POS_HISTORY_WINDOW:
		_pos_history.remove_at(0)

## [Hôte] Position d'un joueur telle qu'elle était il y a `back` secondes.
func _rewound_position(player: Player, back: float) -> Vector2:
	if _pos_history.is_empty(): return player.global_position
	var key := "p1" if player == p1 else "p2"
	var t := Time.get_ticks_msec() / 1000.0 - back
	if t >= float(_pos_history[-1]["t"]): return player.global_position
	if t <= float(_pos_history[0]["t"]): return _pos_history[0][key]
	for i in range(_pos_history.size() - 1):
		var a: Dictionary = _pos_history[i]
		var b: Dictionary = _pos_history[i + 1]
		if t <= float(b["t"]):
			var span: float = float(b["t"]) - float(a["t"])
			var w: float = 0.0 if span <= 0.0001 else (t - float(a["t"])) / span
			return (a[key] as Vector2).lerp(b[key], w)
	return player.global_position

## Recul appliqué aux tirs du client : ce qu'il voyait était en retard d'un
## demi aller-retour, plus le retard d'interpolation de son adversaire.
func _lag_comp_delay() -> float:
	return clampf(NetworkManager.rtt_ms / 2000.0 + Player.INTERP_DELAY, 0.0, LAG_COMP_MAX)

## L'hôte est la seule horloge de manche : sans recalage les deux chronomètres
## dérivent (hoquets de rendu, pause) et la manche ne finit pas ensemble.
@rpc("authority", "call_remote", "reliable")
func rpc_sync_time(value: float) -> void:
	time_left = value

func _on_replay_spawn_bullet(shooter_id: int, pos: Vector2, rot: float, weapon: WeaponData):
	var b = bullet_scene.instantiate()
	b.is_replay = true
	b.global_position = pos
	b.rotation = rot
	b.direction = Vector2(cos(rot), sin(rot))
	var shooter = p1 if shooter_id == 0 else p2
	b.source_player = shooter
	if weapon:
		b.weapon = weapon
	bullet_container.add_child(b)
	
	# --- REPLAY / KILLCAM AUDIO ---
	# Joue le son du tir lors du rejeu d'une balle pendant la Killcam.
	# AudioManager applique automatiquement le ralenti dynamique basé sur Engine.time_scale (ex: 0.03x pendant le bullet time).
	AudioManager.play_weapon_shot(weapon.slug() if weapon else "pistolet", pos)

func player_died(dead_id: int, _killer_id: int):
	if not round_active: return
	
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
		
	var w = 1 if dead_id == 0 else 0
	
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		rpc_end_round.rpc(w)
	else:
		_do_end_round(w)

@rpc("authority", "call_local", "reliable")
func rpc_end_round(winner_id: int):
	_do_end_round(winner_id)

func _do_end_round(winner_id: int):
	# Une seconde fin arrivée pendant la première (mort simultanée, RPC en
	# double) recompterait le kill et relancerait la killcam.
	if _end_sequence_active: return
	_round_token += 1
	var token := _round_token
	_end_sequence_active = true

	# Manches gagnées dans le match en cours. En BO1 une seule suffit, mais le
	# décompte passe par le format : un BO3 n'aurait rien à changer ici.
	if winner_id == 0:
		p1_round_wins += 1
	elif winner_id == 1:
		p2_round_wins += 1

	var match_over := winner_id == -1 \
		or MatchRecord.is_match_over(MATCH_FORMAT, p1_round_wins, p2_round_wins)
	if match_over:
		# Le score cumulé est un score de SESSION (série de matchs), pas un score
		# de manches : il ne bouge qu'à la fin d'un match.
		if winner_id == 0:
			p1_session_wins += 1
		elif winner_id == 1:
			p2_session_wins += 1
		# Le mot de la série est calculé AVANT que l'état n'avance : il compare
		# ce qui vient de tomber à ce qui commence.
		_mot_de_serie = SerieDeSession.mot(serie_porteur, serie_longueur,
			winner_id, _local_player_index())
		var suite := SerieDeSession.apres(serie_porteur, serie_longueur, winner_id)
		serie_porteur = suite.x
		serie_longueur = suite.y
		_archive_match_result(winner_id)
		p1_round_wins = 0
		p2_round_wins = 0

	round_active = false
	countdown_left = 0.0
	ui.set_countdown(0.0)
	# Le menu pause ne gèle plus rien en ligne : il resterait affiché par-dessus
	# la killcam, y compris sur une égalité.
	ui.force_close_pause()
	_predicted_shots.clear()
	AudioManager.set_in_match(false)
	AudioManager.rendre_oreille()
	AudioManager.play_music("music_victory")

	# V2.3 / V3.7 / V3.8 — la ponctuation de fin. `_do_end_round` tourne sur les
	# DEUX machines (`call_local`), et `stinger_de_fin` decide ce que chacune
	# entend depuis sa place. Un fichier absent ne joue rien, sans erreur.
	var _sting := AudioManager.stinger_de_fin(winner_id, match_over,
		_local_player_index())
	if _sting != "":
		AudioManager.play_sfx(_sting)

	# V1.3 — l'annonceur. `voix_de_fin` decide ce que CETTE machine entend : en
	# ecran scindé elle nomme le vainqueur, ailleurs elle s'adresse a celui qui
	# ecoute (« tu as gagne », « sans faute », « de justesse », « perdu »).
	var _pv_vainqueur := 0.0
	if winner_id == 0 and p1 != null:
		_pv_vainqueur = p1.hp
	elif winner_id == 1 and p2 != null:
		_pv_vainqueur = p2.hp
	var _voix := AudioManager.voix_de_fin(winner_id, _local_player_index(),
		training_mode, _pv_vainqueur)
	if _voix != "":
		AudioManager.play_speaker(_voix)

	if winner_id != -1:
		# V2.1 — attendre que la frame de l'impact soit DESSINÉE avant de geler.
		# Piège vérifié en revue : `process_frame` est émis en début de phase
		# process, AVANT le rendu — geler là fige la frame d'avant l'impact
		# (balle en vol, victime debout). `frame_post_draw` reprend juste après
		# le draw de la frame qui contient le trait sur-exposé (V2.6).
		# Sans rendu, ce signal n'est JAMAIS émis : en headless l'attente ne se
		# résout pas, et toute la séquence de fin reste suspendue — écran de fin
		# jamais posé, enregistrement jamais arrêté, `_end_sequence_active` collé
		# à vrai. Le banc `test_online_match` échouait là, et le défaut était
		# invisible en jeu puisqu'une fenêtre dessine.
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
		if token != _round_token: return
		vp1.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# Temps réel : le gel ne dépend pas d'un éventuel time_scale résiduel.
		await get_tree().create_timer(KILL_FREEZE_DURATION, true, false, true).timeout
		# Rétablir AVANT le test de jeton : une manche relancée pendant le gel
		# ne doit jamais hériter d'un viewport éteint.
		# Rendre ce qui était affiché, et non « les deux » : rallumer d'office
		# ferait dessiner en ligne la vue que personne ne regarde.
		_accorder_rendu_aux_vues()
		if token != _round_token: return

		# V2.2 — le noir gagne. La victime est déjà éteinte par die() ; la
		# lumière du vainqueur meurt en deux temps — rétrodiffusion, puis
		# faisceau — et l'arène retombe dans le noir total avant la killcam.
		# Les énergies remontent seules à la manche suivante : la boucle
		# physique du joueur les fait converger vers leur valeur de jeu.
		var winner: Player = p1 if winner_id == 0 else p2
		if is_instance_valid(winner):
			var tw_dark := create_tween()
			tw_dark.tween_property(winner.body_light, "energy", 0.0, KILL_DARKNESS_BODY)
			tw_dark.tween_property(winner.flashlight, "energy", 0.0, KILL_DARKNESS_TORCH)
			tw_dark.tween_callback(func():
				if is_instance_valid(winner):
					winner.flashlight.enabled = false
					winner.body_light.enabled = false)

		# V2.4 — l'onde de choc du kill traverse l'arène depuis le corps, dans
		# le noir fraîchement gagné. Autonome : elle s'anime et se libère seule.
		var victim: Player = p2 if winner_id == 0 else p1
		if is_instance_valid(victim):
			var shock := KillShockwave.new()
			shock.global_position = victim.global_position
			arena.add_child(shock)

	if winner_id != -1:
		# Wait 1.5 seconds to capture blood physics and reaction!
		await get_tree().create_timer(1.5).timeout
		if token != _round_token: return

	ReplaySystem.stop_recording()

	if winner_id != -1:
		# Enter Fullscreen Killcam mode
		var mod = arena.get_node_or_null("CanvasModulate")
		if mod:
			mod.color = Charte.NOIR.lerp(Charte.ACIER, 0.38)
		
		if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
			vp2.get_parent().hide()
		ui.center_line.hide()
		ui.show_killcam()
		
		_first_replay_frame = true
		ReplaySystem.start_playback()
		
		# Wait for replay to finish or be skipped
		while ReplaySystem.playing_back:
			await get_tree().process_frame
			if token != _round_token: return

		# Le ralenti est global : quelle que soit la façon dont la lecture s'est
		# arrêtée, la vitesse normale doit être rétablie ici.
		Engine.time_scale = 1.0

		# Hide killcam UI but KEEP the freeze frame
		ui.hide_killcam()

		# V2.7 — le tampon du kill claque sur l'arrêt sur image.
		_spawn_kill_stamp(round_time - time_left)

		# Attendre 2 secondes supplémentaires sur l'arrêt sur image avant d'afficher le menu de fin
		await get_tree().create_timer(2.0).timeout
		if token != _round_token: return

		# DO NOT restore split screen or reset cameras here!
		# It freezes the screen perfectly on the death frame behind the menu.

	_end_sequence_active = false
	# **`game_over` est posé APRÈS la bifurcation, et c'est le sujet.** Il voulait
	# dire « l'écran de fin est affiché » ; posé une ligne avant qu'on décide de
	# l'afficher, il mentait dans cet intervalle — et le chemin différé le lisait
	# précisément là. Une valeur qui décrivait un état s'était mise à décrire une
	# intention, en gardant son nom.
	# La killcam est allée à son terme. Si le pair est parti pendant qu'elle
	# jouait, c'est MAINTENANT qu'on l'annonce — avant l'écran de fin, et non
	# après : proposer un « REJOUER » à quelqu'un dont l'adversaire n'existe plus
	# serait une promesse d'une demi-seconde.
	if _deconnexion_differee:
		_annoncer_deconnexion()
		return
	game_over = true
	# show_game_over remet le bouton sur « REJOUER » : l'état suit le libellé.
	local_ready_for_rematch = false
	ui.show_game_over(winner_id)
	# DA4.7 — le bilan est COMPOSÉ par l'interface, plus concaténé ici.
	#
	# Cette ligne écrivait `SESSION : 2 - 1   ·   3 D'AFFILÉE` dans
	# `game_over_score`, c'est-à-dire dans le label des **descriptions d'entrées**.
	# Deux défauts en un : trois informations de rangs différents aplaties par des
	# points médians, et un emprunt de nœud qui obligeait `show_lobby_again()` à
	# effacer le score à la main pour qu'il ne survive pas au match suivant.
	#
	# `game_state` reste la seule source des deux valeurs — il est le seul à
	# connaître le score de session et la série — mais il ne décide plus de leur
	# mise en forme.
	ui.poser_bilan(p1_session_wins, p2_session_wins, _mot_de_serie)
	_apply_deferred_rematch()

## Archive le résultat du match dans user://. Fondation de l'envoi ELO à venir :
## chaque machine journalise le match qu'elle vient de jouer, y compris le
## client — il n'y a aucun échange réseau ici.
func _archive_match_result(winner_id: int, forfeit: bool = false) -> void:
	# Le match est résolu : plus rien à forfaire dessus.
	_forfeit_pending = false
	var record := MatchRecord.build(
		winner_id,
		round_time - time_left,
		p1.current_weapon.name if p1 and p1.current_weapon else "",
		p2.current_weapon.name if p2 and p2.current_weapon else "",
		MapData.selected_map_id,
		_mode_label(),
		MATCH_FORMAT,
		forfeit,
		# Ce que le rejeu du journal a besoin de savoir pour renvoyer un rapport
		# perdu : à quel match il se rattache, s'il comptait, et ce que cette
		# machine a déclaré. Sans eux l'enregistrement décrit un match sans
		# pouvoir le rapporter — ce que le journal prétendait déjà faire.
		_match_id,
		RankedIdentity.is_ranked_context() if is_instance_valid(RankedIdentity) else false,
		_local_outcome(winner_id))
	MatchRecord.append_to_history(record)
	# Le journal local d'abord, l'envoi ensuite : si le second échoue, le premier
	# garde la trace, et une étape ultérieure pourra rejouer ce qui manque.
	_report_to_ranking(winner_id, forfeit)

## L'issue du match du point de vue de CETTE machine, dans le vocabulaire du
## serveur.
##
## Une seule fonction la calcule, et c'est ce qui compte : le journal local et
## l'envoi au classement doivent dire la même chose. Deux calculs séparés
## finiraient par diverger, et un journal rejoué contredirait alors un rapport
## déjà accepté — sans que rien ne le signale, puisque chacun serait cohérent
## avec lui-même.
##
## Chaîne vide quand cette machine n'a pas de camp — écran partagé,
## entraînement : il n'y a alors personne dont ce serait l'issue.
func _local_outcome(winner_id: int) -> String:
	var local_idx := _local_player_index()
	if local_idx < 0:
		return ""
	if winner_id < 0:
		return "draw"
	return "win" if winner_id == local_idx else "loss"

## Dépose le résultat auprès du classement, du point de vue de CETTE machine.
##
## Chaque pair ne déclare que son propre sort ; le serveur apparie les deux
## rapports par leur identifiant de match et confronte les récits. Rien n'est
## envoyé hors ligne — un match en écran partagé n'oppose aucune identité.
func _report_to_ranking(winner_id: int, forfeit: bool) -> void:
	var local_idx := _local_player_index()
	if local_idx < 0 or _match_id.is_empty():
		return

	var outcome := _local_outcome(winner_id)

	var mine: Player = p1 if local_idx == 0 else p2
	var theirs: Player = p2 if local_idx == 0 else p1
	RankedIdentity.report_match(_match_id, outcome, {
		"forfeit": forfeit,
		"duration": round_time - time_left,
		"map": MapData.selected_map_id,
		"weapon_self": mine.current_weapon.name if mine and mine.current_weapon else "",
		"weapon_opponent": theirs.current_weapon.name if theirs and theirs.current_weapon else "",
		"format": MatchRecord.FORMAT_NAMES.get(MATCH_FORMAT, "BO1"),
	})

## Archive un match gagné par abandon de l'adversaire.
##
## Le jeton `_forfeit_pending` est ce qui rend l'opération sûre : abandonner
## emprunte plusieurs chemins de retour au menu, qui se croisent — signal du
## transport, dialogue de déconnexion, bouton MENU PRINCIPAL — et sans lui le
## même match serait archivé deux ou trois fois.
##
## À appeler AVANT `NetworkManager.disconnect_from_game()` : celui-ci remet le
## mode en local, et l'enregistrement ne saurait plus dire s'il vient d'un hôte
## ou d'un client.
func _archive_forfeit(winner_id: int) -> void:
	if not _forfeit_pending:
		return
	_archive_match_result(winner_id, true)

## Indice du joueur incarné par CETTE machine, -1 hors ligne.
## Pose (ou retire) l'oreille sur le joueur que cette machine regarde.
##
## **Appelée à DEUX endroits, et il le faut** : à la fin de `_do_start_round`, et
## de nouveau à la fin de `_on_training_requested`. L'entraînement passe par le
## démarrage ordinaire, mais il ne pose `training_mode = true` qu'**après** son
## retour — `_do_start_round` le remet à faux, c'est écrit dans son propre
## commentaire. Une règle qui interroge `training_mode` depuis l'intérieur du
## démarrage lit donc toujours « non », et le correctif serait posé sans effet :
## exactement le mode de défaillance que ce chantier documente.
##
## `poser_oreille` commence par `rendre_oreille` : l'appeler deux fois est sans
## conséquence, et c'est ce qui permet au second appel de corriger le premier.
func _accorder_oreille() -> void:
	var idx := _local_player_index()
	if AudioManager.oreille_suit(idx, training_mode):
		AudioManager.poser_oreille(p2 if AudioManager.index_porteur(idx) == 1 else p1)
		return
	# Écran partagé : deux joueurs, une seule paire d'enceintes, donc **deux
	# oreilles dont le moteur fait la somme** (décision d'Adrien, 2026-08-25). Le
	# plus proche l'emporte tout seul, sa copie étant plus forte. Prix assumé et
	# tranché avec lui : **l'occlusion n'existe pas dans ce mode** — étouffer la
	# copie de J1 sans toucher à celle de J2 demanderait deux voix par son.
	AudioManager.poser_deux_oreilles(p1, p2, vp1, vp2)

func _local_player_index() -> int:
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST: return 0
		NetworkManager.GameMode.ONLINE_CLIENT: return 1
		_: return -1

func _mode_label() -> String:
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST: return "en_ligne_hote"
		NetworkManager.GameMode.ONLINE_CLIENT: return "en_ligne_client"
		_: return "local"

## V2.7 — Tampon « KILL — mm:ss » qui claque sur l'arrêt sur image de fin de
## killcam. CanvasLayer à part : ui.gd appartient à l'autre session, et ce
## tampon vit exactement le temps de l'arrêt sur image.
var _kill_stamp: CanvasLayer

func _spawn_kill_stamp(elapsed: float) -> void:
	_clear_kill_stamp()
	_kill_stamp = CanvasLayer.new()
	_kill_stamp.layer = 95
	add_child(_kill_stamp)

	var lbl := Label.new()
	lbl.text = "KILL — %s" % MatchRecord.format_clock(elapsed)
	var settings := LabelSettings.new()
	settings.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	settings.font_size = Charte.T_ENSEIGNE
	settings.font_color = Charte.ROUGE
	settings.outline_size = 10
	settings.outline_color = Charte.NOIR
	lbl.label_settings = settings
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	lbl.rotation = -0.06
	_kill_stamp.add_child(lbl)

	# Le claquement : gros, puis en place — l'inertie d'un tampon encreur.
	lbl.scale = Vector2(2.6, 2.6)
	lbl.modulate.a = 0.0
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.03)
	tw.parallel().tween_property(lbl, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.15)
	tw.tween_callback(_clear_kill_stamp)

func _clear_kill_stamp() -> void:
	if is_instance_valid(_kill_stamp):
		_kill_stamp.queue_free()
	_kill_stamp = null

## Sortie inconditionnelle de la killcam. Le ralenti est un réglage global du
## moteur : l'oublier sur un chemin de sortie laisse tout le jeu à 3 % de sa
## vitesse, menus compris.
func _abort_killcam() -> void:
	ReplaySystem.playing_back = false
	Engine.time_scale = 1.0
	# Ceinture V2.1 : aucun chemin de sortie ne doit laisser un viewport gelé —
	# mais on rétablit l'état réel des vues, pas les deux d'office.
	_accorder_rendu_aux_vues()
	_clear_kill_stamp()
	ui.hide_killcam()

## [Hôte] Rejoue ce qui a été reçu pendant la séquence de fin, une fois l'écran
## de fin affiché et l'état redevenu stable.
func _apply_deferred_rematch() -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST: return
	if _pending_p2_weapon_idx >= 0:
		_set_p2_weapon_button(_pending_p2_weapon_idx)
		_pending_p2_weapon_idx = -1
		# Le client s'était déclaré pendant la killcam : son intention a été
		# retenue, elle se signale maintenant. Sans cette ligne, le seul cas où
		# l'adversaire est prêt AVANT nous serait le seul à ne rien montrer.
		if p2_ready_for_rematch and not p1_ready_for_rematch:
			ui.time_label.text = "L'ADVERSAIRE EST PRÊT"
			ui.signaler_adversaire_pret()
	if _pending_client_start:
		_pending_client_start = false
		if client_peer_id != 0:
			rpc_start_round.rpc(_hosted_weapon_1_idx, _local_p2_weapon_idx(), _host_map_code(),
				_new_match_id())
			return
	if p2_ready_for_rematch:
		_check_rematch_start()

## [Hôte] Arme choisie par le client, envoyée dès la connexion établie. C'est
## ce paquet, et non `peer_connected`, qui déclenche la première manche : il est
## le seul moment où l'hôte connaît le choix de P2.
@rpc("any_peer", "reliable")
func rpc_client_weapon(idx: int):
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST: return
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id: return
	# Le client n'émet ce paquet qu'à la connexion : le recevoir pendant une
	# manche (ou son décompte) ne peut être qu'une ré-émission illégitime —
	# l'accepter réinitialiserait le duel en cours.
	if round_active or countdown_left > 0.0: return
	_set_p2_weapon_button(idx)
	# Ce paquet dit désormais « voici mon arme », plus « lance le match ». Le
	# départ appartient à `_check_rematch_start()`, qui attend les deux « PRÊT » —
	# sans quoi le duel commençait à la seconde où le client se connectait, et
	# celui qui hébergeait le découvrait en se retrouvant en jeu.
	if _end_sequence_active:
		_pending_p2_weapon_idx = idx

## Index de l'arme choisie par le joueur local pour P2 (client, ou écran partagé).
func _local_p2_weapon_idx() -> int:
	var pressed: BaseButton = ui.p2_weapon_group.get_pressed_button()
	return pressed.get_index() if pressed else 0

## Un index hors bornes ferait tomber l'hôte sur un paquet client malformé.
func _set_p2_weapon_button(idx: int) -> void:
	var buttons: Array = ui.p2_weapon_group.get_buttons()
	if idx < 0 or idx >= buttons.size(): return
	buttons[idx].button_pressed = true

## [Appariement] Les deux joueurs se sont trouvés et le lien est ouvert.
##
## Seul l'hôte a quelque chose à faire ici : le client entre par
## `connection_success`, qui fait déjà tout — et le faire entrer deux fois
## relancerait sa manche par-dessus elle-même.
##
## La carte est tirée au sort **avant** `_start_round()`, parce que c'est cet
## appel qui reconstruit l'arène et que `_host_map_code()` la joindra au paquet de
## départ du client. Tirer après donnerait deux arènes différentes aux deux
## joueurs — le défaut le plus coûteux à diagnostiquer de tout le jeu, chacun
## voyant un monde cohérent.
## Le joueur quitte la fenêtre de choix. Renoncer à choisir son arme, c'est
## renoncer au match : on annule l'appariement et la recherche, et on rentre au
## menu. Le pair, lui, verra une déconnexion ordinaire — il n'y a pas de « l'autre
## a renoncé » à lui montrer que le retour au menu ne dise déjà.
func _on_pick_window_cancelled() -> void:
	var appariement := get_node_or_null(^"/root/Matchmaker")
	if appariement != null and appariement.has_method("cancel"):
		appariement.cancel()
	_matchmade_round = false
	_on_main_menu_requested()

## L'arme correspondant à un index de râtelier. Une seule table de résolution :
## la dupliquer ferait diverger le démarrage de manche et le changement d'arme
## pendant le décompte, et la divergence porterait sur ce que le joueur tient.
func weapon_for_index(idx: int) -> WeaponData:
	match idx:
		3: return weapon_arbalete
		2: return weapon_pompe
		1: return weapon_fusil
		_: return weapon_pistolet

## L'arsenal commun de ce match, règle du miroir appliquée. Vide hors match
## apparié : ailleurs, l'arme est choisie au menu et rien n'est à aligner.
func matchmade_arsenal() -> Array[int]:
	if not _matchmade_round:
		return []
	return RankLoadout.mirrored(_mirror_local_tier, _mirror_opponent_tier)

## Pourquoi l'arsenal est celui-là, en langage joueur — vide s'il n'a pas rétréci.
## L'écran ne reconstruit pas le raisonnement : il affiche ce que la table rend.
func matchmade_arsenal_reason() -> String:
	if not _matchmade_round or _mirror_opponent_tier >= maxi(_mirror_local_tier, 1):
		return ""
	return RankLoadout.reason_for(RankLoadout.ARBALETE, true,
		_mirror_local_tier, _mirror_opponent_tier)

## Le joueur local change d'arme pendant la fenêtre de choix.
##
## Refusé hors de cette fenêtre et hors de l'arsenal commun : l'hôte est
## l'autorité, et un client au jeu modifié ne doit pas pouvoir s'équiper de ce
## que la règle du miroir lui a retiré.
func pick_countdown_weapon(idx: int) -> void:
	if not _matchmade_round or countdown_left <= 0.0:
		return
	if not idx in matchmade_arsenal():
		return
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		p2.equip_weapon(weapon_for_index(idx))
		rpc_id(1, "rpc_countdown_weapon", idx)
		return
	p1.equip_weapon(weapon_for_index(idx))
	_hosted_weapon_1_idx = idx

## L'adversaire a changé d'arme pendant la fenêtre. Reçu par l'hôte seul, qui
## refait le même contrôle : un index reçu n'est pas un droit.
@rpc("any_peer", "reliable")
func rpc_countdown_weapon(idx: int) -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
		return
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id:
		return
	if not _matchmade_round or countdown_left <= 0.0:
		return
	if not idx in matchmade_arsenal():
		return
	p2.equip_weapon(weapon_for_index(idx))

func _on_match_ready(_pairing: Dictionary) -> void:
	# Ce match ouvre une fenêtre de choix : l'arsenal commun n'est connu que
	# maintenant, la règle du miroir l'alignant sur le moins bien classé. Posé des
	# DEUX côtés — le client ne passe pas par `_start_round()`, il reçoit
	# `rpc_start_round`, et sans ce drapeau son décompte durerait trois secondes
	# pendant que l'hôte en compte dix.
	_matchmade_round = true
	_mirror_local_tier = int(_pairing.get("local_tier", 0))
	_mirror_opponent_tier = int(_pairing.get("opponent_tier", 0))
	# Le joueur a choisi son arme sans savoir s'il hébergerait : la désignation
	# vient tout juste d'avoir lieu. Le choix est donc reporté sur les deux
	# râteliers, l'hôte lisant celui de J1 et l'invité celui de J2.
	ui.mirror_weapon_choice()
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
		return
	MapData.select_random_map()
	_enter_hosted_game()
	_start_round()

## Quitte le menu pour la partie hébergée : autorités, fournisseurs d'entrées,
## vues. Trois chemins y mènent — l'hôte qui appuie sur PRÊT, l'adversaire qui
## arrive dans un salon ouvert depuis le menu, et l'appariement qui vient
## d'établir le lien. Ils doivent préparer exactement la même chose, sous peine
## d'une partie où l'un des deux joueurs est mal branché.
func _enter_hosted_game() -> void:
	_apply_network_mode()
	game_over = false
	ui.hide_game_over()
	_restore_viewports()

func _on_replay_requested():
	if ui._is_main_menu:
		# Un match lancé depuis le menu n'ouvre pas de fenêtre de choix : l'arme y
		# est déjà choisie. Sans cette remise à zéro, un salon ouvert après un
		# match apparié hériterait de ses dix secondes — et le décompte durerait
		# trois fois trop longtemps sans que rien ne l'explique.
		_matchmade_round = false
		# Le mode lancé est celui qu'affiche le menu. Tester directement
		# « CRÉER SALON » ne suffit pas : ce bouton appartient à un autre groupe
		# que « 1V1 LOCAL / EN LIGNE » et reste coché après une partie en ligne,
		# si bien qu'un 1v1 local relançait un salon.
		var mode: NetworkManager.GameMode = ui.selected_network_mode()
		if mode == NetworkManager.GameMode.ONLINE_HOST:
			# Le salon est peut-être déjà ouvert : « CRÉER LE SALON » l'ouvre depuis
			# le menu. Réhéberger remplacerait le pair vivant, donc la connexion
			# déjà établie avec l'adversaire qui attend dans la liste.
			if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
				# Un hébergement refusé (Epic injoignable, port déjà pris) a déjà
				# ramené au menu : enchaîner sur la manche lancerait une partie
				# solo par-dessus l'écran d'erreur.
				if not NetworkManager.host_game():
					return
			# `_apply_network_mode()` seul, et surtout **pas** `_enter_hosted_game()` :
			# celui-ci quitte le menu, or se déclarer prêt n'est pas partir. L'hôte
			# se retrouvait sinon dans l'arène pendant que la porte attendait encore
			# l'autre camp — arène sans manche, donc chrono figé et commandes mortes.
			# C'est `_do_start_round()`, déclenché par `rpc_start_round`, qui referme
			# le menu — et lui seul sait quand les deux sont d'accord.
			_apply_network_mode()
			# Le match ne part plus à l'appui : il attend que les DEUX camps se
			# soient déclarés prêts. C'est la machinerie du rematch, réemployée
			# telle quelle — et c'est ce qui supprime le démarrage automatique à
			# l'arrivée du client, que personne n'avait demandé.
			p1_ready_for_rematch = true
			if ui.p1_weapon_group.get_pressed_button():
				_hosted_weapon_1_idx = ui.p1_weapon_group.get_pressed_button().get_index()
			_annoncer_etat_hote()
			_check_rematch_start()
		elif mode == NetworkManager.GameMode.ONLINE_CLIENT:
			# Le client est déjà dans le salon : « PRÊT » ne fait que le déclarer.
			rpc_id(1, "rpc_client_ready", _local_p2_weapon_idx())
		else:
			NetworkManager.disconnect_from_game()
			_apply_network_mode()
			game_over = false
			ui.hide_game_over()
			_restore_viewports()
			_start_round()
	else:
		if local_ready_for_rematch:
			local_ready_for_rematch = false
			ui.btn_replay.text = "REJOUER"
			ui.btn_replay.remove_theme_color_override("font_color")
			if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
				rpc_id(1, "rpc_client_unready")
			elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
				p1_ready_for_rematch = false
				_annoncer_etat_hote()
				ui.time_label.text = "EN ATTENTE D'UN ADVERSAIRE..."
			return

		var w2_idx = 0
		if ui.p2_weapon_group.get_pressed_button():
			w2_idx = ui.p2_weapon_group.get_pressed_button().get_index()

		local_ready_for_rematch = true
		ui.btn_replay.text = "✓ PRÊT"
		ui.btn_replay.add_theme_color_override("font_color", Charte.ETAT_OK)
		
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
			rpc_id(1, "rpc_client_ready", w2_idx)
		elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
			p1_ready_for_rematch = true
			if ui.p1_weapon_group.get_pressed_button():
				_hosted_weapon_1_idx = ui.p1_weapon_group.get_pressed_button().get_index()
			_annoncer_etat_hote()
			_check_rematch_start()
		else:
			_start_round()

## Rejoindre le salon, et rien d'autre. Séparé du lancement pour qu'un joueur qui
## arrive ne fasse pas commencer le match à celui qui attend : c'est le défaut
## qu'Adrien a rencontré à deux fenêtres, où le duel démarrait à la connexion.
func _on_join_requested() -> void:
	if not ui._is_main_menu:
		return
	if not NetworkManager.join_game(ui.lobby_join_text()):
		return
	# L'échéance doit être neutralisée dès que l'issue est connue : sinon elle
	# renvoie au menu une partie déjà commencée.
	_join_deadline_active = true
	var timer = get_tree().create_timer(NetworkManager.join_timeout())
	timer.timeout.connect(func():
		if not _join_deadline_active:
			return
		_join_deadline_active = false
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT and multiplayer.get_peers().size() == 0:
			_on_connection_failed()
	)

## Le joueur local a fini de choisir pendant le décompte.
##
## Appelé par l'interface. Chez le client, l'intention part à l'hôte : lui seul
## porte le chronomètre, et laisser chaque camp abréger de son côté produirait
## deux départs décalés d'un aller-retour.
func declare_countdown_ready() -> void:
	if not _matchmade_round or countdown_left <= 0.0:
		return
	_countdown_ready_local = true
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		rpc_id(1, "rpc_countdown_ready")
	else:
		# En écran partagé il n'y a personne en face : se déclarer prêt suffit.
		if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
			_countdown_ready_peer = true

## L'adversaire a fini de choisir. Reçu par l'hôte seul.
@rpc("any_peer", "reliable")
func rpc_countdown_ready() -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
		return
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id:
		return
	_countdown_ready_peer = true

## L'hôte annonce au client s'il est prêt, ou s'il ne l'est plus.
##
## **Il n'existait aucun chemin pour cette information.** Le client pressait
## PRÊT, voyait « ✓ PRÊT », et attendait ensuite sans savoir s'il attendait
## l'hôte ou le réseau — deux situations qu'on ne vit pas de la même façon. Le
## sens inverse était câblé depuis toujours (`rpc_client_ready`) : le salon
## n'était renseigné que d'un côté.
##
## `call_remote` et non `call_local` : l'hôte connaît déjà son propre état, et
## `_check_rematch_start()` écrit son écran à lui. Se le rejouer ferait passer
## deux fois sur le même libellé.
@rpc("authority", "call_remote", "reliable")
func rpc_host_ready(pret: bool) -> void:
	# Seul l'hôte parle ici, et seulement à un client. Un pair qui n'est ni l'un
	# ni l'autre n'a pas d'état d'hôte à annoncer.
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	_appliquer_hote_pret(pret)

## Ce que le client fait de l'état de l'hôte. Symétrique de ce que
## `_check_rematch_start()` écrit chez l'hôte, et pour la même raison : un salon
## qui ne dit pas qui attend qui fait attendre les deux.
func _appliquer_hote_pret(pret: bool) -> void:
	var monte := pret and not _hote_pret
	_hote_pret = pret
	if ui == null:
		return
	if pret and local_ready_for_rematch:
		# Les deux sont prêts : la manche part, `rpc_start_round` est en route.
		# Annoncer une attente ici la ferait clignoter avant le départ.
		return
	ui.time_label.text = "L'ADVERSAIRE EST PRÊT" if pret \
		else "EN ATTENTE D'UN ADVERSAIRE..."
	if monte:
		ui.signaler_adversaire_pret()

## Dit au client où en est l'hôte. Appelé à chaque changement, et à l'arrivée du
## client : sans ce rappel, quelqu'un qui rejoint un hôte déjà prêt ne
## l'apprendrait jamais — l'événement a eu lieu avant lui.
func _annoncer_etat_hote() -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
		return
	if client_peer_id == 0:
		return
	rpc_id(client_peer_id, "rpc_host_ready", p1_ready_for_rematch)

@rpc("any_peer", "reliable")
func rpc_client_ready(w2_idx: int):
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id: return
	p2_ready_for_rematch = true
	# Le client a fini sa killcam avant l'hôte : on retient son intention, on
	# n'écrit ni son arme ni le libellé du chrono au milieu du ralenti.
	if _end_sequence_active:
		_pending_p2_weapon_idx = w2_idx
		return
	_set_p2_weapon_button(w2_idx)
	_check_rematch_start()

func _check_rematch_start():
	# Un départ pendant la séquence de fin couperait la killcam de l'hôte.
	if _end_sequence_active: return
	if p1_ready_for_rematch and p2_ready_for_rematch:
		p1_ready_for_rematch = false
		p2_ready_for_rematch = false
		var w2_idx = 0
		if ui.p2_weapon_group.get_pressed_button():
			w2_idx = ui.p2_weapon_group.get_pressed_button().get_index()
		rpc_start_round.rpc(_hosted_weapon_1_idx, w2_idx, _host_map_code(), _new_match_id())
	elif p2_ready_for_rematch:
		# **Le message disait l'inverse de la vérité.** Quand le client s'était
		# déclaré et pas l'hôte, l'écran de l'hôte affichait « en attente d'un
		# adversaire » — alors que l'adversaire était là, prêt, et attendait
		# précisément celui qui lisait la phrase. On ne peut pas se dépêcher pour
		# quelqu'un qu'on croit absent.
		ui.time_label.text = "L'ADVERSAIRE EST PRÊT"
		ui.signaler_adversaire_pret()
	elif not p1_ready_for_rematch:
		ui.time_label.text = "EN ATTENTE D'UN ADVERSAIRE..."

## Une vue cachée ne doit pas RENDRE. C'est la moitié du coût du duel.
##
## **Cacher un `SubViewportContainer` ne suspend pas son `SubViewport`** : celui-ci
## continue de dessiner la scène dans une texture que personne n'affiche. Le
## `render_target_update_mode` n'était jamais mis à `UPDATE_DISABLED` en dehors du
## gel du kill (V2.1), et toujours rétabli à `UPDATE_ALWAYS` derrière — donc en
## ligne comme à l'entraînement, la moitié invisible de l'écran était rendue à
## chaque image.
##
## Ce que ça coûte est mesuré, pas supposé : la décomposition du 2026-08-18 donne
## **1,52 à 1,60 ms pour le second rendu**, soit la totalité de l'écart entre le
## duel et un socle sans lui. En écran partagé cette seconde vue est légitime,
## quelqu'un la regarde. **En ligne et à l'entraînement, personne ne la regarde.**
##
## La convergence vaut d'être notée : la cible de cadence vient de la latence EOS,
## c'est-à-dire du mode **en ligne** — et c'est précisément là que ce coût ne
## servait à rien.
func _accorder_rendu_aux_vues() -> void:
	for vue in [vp1, vp2]:
		var conteneur := vue.get_parent() as Control
		var vu := conteneur != null and conteneur.visible
		vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS if vu \
			else SubViewport.UPDATE_DISABLED

func _restore_viewports():
	# L'entraînement passe avant le mode réseau : il tourne en écran partagé du
	# point de vue du transport — aucun pair, aucune autorité distante — mais un
	# seul joueur le regarde. Couper l'écran en deux pour une moitié vide était le
	# défaut relevé par Adrien à l'essai.
	if training_mode:
		vp1.get_parent().show()
		vp2.get_parent().hide()
		ui.center_line.hide()
		_accorder_rendu_aux_vues()
		# Cette branche sort en `return` AVANT la fin de la fonction : tout ce qui
		# s'y ajoute doit donc être répété ici. Deux défauts en ont découlé et
		# Adrien les a vus le 2026-08-19 — les deux panneaux de HUD affichés pour
		# un seul joueur, et le joueur en bas de l'écran parce que la caméra
		# n'avait jamais été placée.
		ui.disposer_hud(true)
		cam1.global_position = p1.global_position
		cam1.zoom = Vector2(1.0, 1.0)
		cam2.zoom = Vector2(1.0, 1.0)
		return
	if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		vp1.get_parent().show()
		vp2.get_parent().show()
		ui.center_line.show()
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		vp1.get_parent().show()
		vp2.get_parent().hide()
		ui.center_line.hide()
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		vp1.get_parent().hide()
		vp2.get_parent().show()
		ui.center_line.hide()
	_accorder_rendu_aux_vues()
	ui.disposer_hud()
	cam1.zoom = Vector2(1.0, 1.0)
	cam2.zoom = Vector2(1.0, 1.0)
	cam1.global_position = p1.global_position
	cam2.global_position = p2.global_position
	var mod = arena.get_node_or_null("CanvasModulate")
	if mod:
		mod.color = Charte.NOIR


func _on_main_menu_requested():
	# Départ volontaire en plein match : c'est un abandon, et il se paie. Le
	# vainqueur est l'adversaire — celui qui reste. Archivé AVANT la déconnexion,
	# qui repasse le mode en local et rendrait l'enregistrement muet sur son
	# origine. Si un signal du transport est déjà passé par là, le jeton a été
	# consommé et cet appel ne fait rien.
	var local_idx := _local_player_index()
	if local_idx >= 0:
		_archive_forfeit(1 - local_idx)

	NetworkManager.disconnect_from_game()

	client_peer_id = 0
	_join_deadline_active = false
	countdown_left = 0.0
	ui.set_countdown(0.0)
	# Retour au menu depuis une killcam : sans ça le menu tourne au ralenti et
	# une séquence de fin en vol reviendrait afficher un écran de victoire.
	_round_token += 1
	_end_sequence_active = false
	_pending_client_start = false
	_pending_p2_weapon_idx = -1
	_abort_killcam()
	ui.force_close_pause()
	_predicted_shots.clear()
	_pos_history.clear()
	round_active = false
	sandbox_mode = false
	game_over = true
	p1_ready_for_rematch = false
	p2_ready_for_rematch = false
	# Sans ça, un client verrait « L'ADVERSAIRE EST PRÊT » au début du salon
	# suivant sur la foi d'une annonce du match précédent.
	_hote_pret = false
	local_ready_for_rematch = false
	
	if ReplaySystem:
		ReplaySystem.stop_recording()
		ReplaySystem.playing_back = false
		
	for c in bullet_container.get_children():
		c.queue_free()
		
	if is_instance_valid(p1):
		p1.hp = 100.0
		p1.dead = false
		p1.dazzle_amount = 0.0
		p1.global_position = _get_spawn_position(0)
	if is_instance_valid(p2):
		p2.hp = 100.0
		p2.dead = false
		p2.dazzle_amount = 0.0
		p2.global_position = _get_spawn_position(1)
		
	# Le score de session ne survit pas au retour au menu : une nouvelle série
	# repart de 0 - 0.
	p1_session_wins = 0
	p2_session_wins = 0
	serie_porteur = -1
	serie_longueur = 0
	_mot_de_serie = ""
	p1_round_wins = 0
	p2_round_wins = 0
	_set_training_target_active(false)
	if is_instance_valid(particle_pool):
		particle_pool.clear_all()

	# Purge les traces de sang et autres entités dynamiques de l'arène.
	# NB : "SpawnPoints" doit figurer ici — l'ancienne liste testait "SpawnP1"
	# et "SpawnP2", des noms qui n'existent pas, si bien qu'un retour au menu
	# détruisait définitivement les points d'apparition de arena.tscn.
	const ARENA_KEEP := ["Ground", "StaticGeometry", "SpawnPoints", "KillcamOverlay"]
	for child in arena.get_children():
		if child.name in ARENA_KEEP:
			continue
		if child is CanvasModulate or child is BackBufferCopy or child is Camera2D:
			continue
		child.queue_free()
	
	ui.show_main_menu()
	AudioManager.play_music("music_menu")

func _on_quit_requested():
	# Quitter le jeu en plein match est un abandon comme un autre : il se paie.
	var local_idx := _local_player_index()
	if local_idx >= 0:
		_archive_forfeit(1 - local_idx)

	# quit() ne prend effet qu'en fin de frame : sortir depuis une killcam
	# étirerait ces dernières frames au ralenti.
	Engine.time_scale = 1.0
	# Passe par NetworkManager : la plateforme EOS doit être relâchée avant que
	# l'arbre se termine, sous peine de segfault à la fermeture.
	NetworkManager.quit_game()

## [Client Uniquement] Appelé quand l'hôte ferme le serveur ou plante.
func _on_host_disconnected():
	# L'hôte est parti en cours de match : le client encaisse la victoire.
	_archive_forfeit(1)
	ui.show_dialog_message("Déconnexion",
		"L'hôte a fermé la partie. Retour au menu principal.",
		UI.Registre.ATTENTION)
	_on_main_menu_requested()

## [Client Uniquement] Intercepte un échec de connexion (timeout ou serveur plein).
func _on_connection_failed():
	_join_deadline_active = false
	# Le transport sait pourquoi ça a échoué (code introuvable, Epic injoignable,
	# adresse morte) ; ce message générique ne sert que s'il n'a rien dit.
	var reason: String = NetworkManager.last_error
	if reason.is_empty():
		reason = "Impossible de rejoindre le salon (adresse injoignable ou salon complet)."
	# « Erreur » ne disait rien : le joueur sait déjà que ça a raté, il veut
	# savoir QUOI. Le titre nomme le geste qui a échoué.
	ui.show_dialog_message("Connexion impossible", reason, UI.Registre.FAUTE)
	_on_main_menu_requested()

## [Client Uniquement] Appelé quand la connexion au serveur réussit.
func _on_connection_success():
	_join_deadline_active = false
	# Lu avant que l'écran de fin ne se referme, tant que le panneau du lobby
	# reflète encore le choix du joueur.
	var w2_idx := _local_p2_weapon_idx()
	# Le câblage des entrées, oui — il ne coûte rien et doit précéder la manche.
	# Mais **le client reste dans son salon** : il vient seulement de se connecter,
	# il n'a pas encore dit PRÊT.
	#
	# Ces trois lignes le faisaient quitter le menu et entrer dans l'arène à la
	# seconde où la connexion s'établissait — sans jamais pouvoir appuyer sur PRÊT,
	# le bouton étant resté derrière lui. C'était le pendant client du départ
	# automatique que la porte PRÊT avait supprimé côté hôte, et il avait survécu.
	_apply_network_mode()
	game_over = false
	# L'arme part dès maintenant pour que l'hôte l'ait avant même le PRÊT ; c'est
	# `rpc_client_ready` qui la confirmera au moment de se déclarer.
	rpc_id(1, "rpc_client_weapon", w2_idx)

@rpc("any_peer", "reliable")
func rpc_client_unready():
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id: return
	p2_ready_for_rematch = false
	_pending_p2_weapon_idx = -1
	if not _end_sequence_active:
		ui.time_label.text = "EN ATTENTE D'UN ADVERSAIRE..."
