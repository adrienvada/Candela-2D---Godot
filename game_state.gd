extends Node
class_name GameState

const Charte := preload("res://charte.gd")

const SHADER_GHOST := preload("res://ghost_unshaded.gdshader")
const BulletCasingScript := preload("res://bullet_casing.gd")
const ArenaDecorScript := preload("res://arena_decor.gd")

## Un match = UNE manche de 5 minutes (BO1). Le format n'est pas en dur : il
## transite par MatchRecord.Format pour qu'un BO3/BO5 puisse s'ajouter sans
## refonte. Seul le BO1 est implémenté.
const MATCH_FORMAT := MatchRecord.Format.BO1

@export var round_time: float = MatchRecord.ROUND_DURATION

var time_left: float = MatchRecord.ROUND_DURATION
var round_active: bool = false
var sandbox_mode: bool = false

## PE2.1 — le relevé de cadence de la manche en cours, archivé avec le match
## (voir `conditions_de_match.gd`). Commencé au départ de la manche, arrêté à
## la mort — avant la killcam.
var _conditions := ConditionsDeMatch.new()
## PE3.1 — le dernier régime signalé à `GameSettings`, pour ne le dire qu'au
## changement et non à chaque image.
var _arene_signalee := false

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

## DA4.7 — la marge du dernier tir fatal **connue sur cette machine**, en pixels.
##
## `-1` = inconnue, et l'écran de fin se tait alors plutôt que d'inventer un
## nombre. Ce n'est pas un cas rare ni un défaut : V2.9 pose cette valeur sur la
## machine qui a SIMULÉ la balle fatale. En ligne, le vainqueur ne l'a donc
## souvent pas — et c'est cohérent, puisque c'est au perdant que « j'y étais
## presque » s'adresse.
##
## ⚠️ **Cosmétique, jamais arbitrale.** Chez le client c'est la prédiction locale
## qui parle et non l'hôte : deux machines peuvent afficher deux marges
## légèrement différentes pour le même tir, exactement comme les deux killcams
## peuvent légitimement différer. Rien de ce qui compte au score n'en dépend.
var dernier_effleurement: float = -1.0

# Score de session : nombre de matchs gagnés depuis le lancement de la série.
# Remis à zéro au retour au menu, pas entre deux matchs.
var p1_session_wins: int = 0
var p2_session_wins: int = 0

## DA6.3 — le repère de « ce soir ». L'historique persiste entre deux
## lancements ; une soirée est une séance devant l'écran, pas une date. Posé une
## fois, à la construction, et jamais recalculé : le relire à chaque fin de match
## ferait glisser la fenêtre et la carte oublierait le début de la soirée.
var _debut_de_seance: String = Time.get_datetime_string_from_system(true, true)

## La carte de fin de soirée ne se pose qu'UNE fois par séance. Le retour au menu
## arrive après chaque match : reposée à chaque fois, elle cesserait d'être une
## fin de soirée pour devenir un écran de plus à congédier.
var _soiree_montree: bool = false

## DA4.7 — un joueur vient de tomber, et sa machine sait de combien.
##
## Appelée par `player.gd` via le groupe `game_state`, comme `player_died`. Elle
## écrase sans condition : c'est **la dernière** qui compte, celle du tir qui
## vient de clore la manche.
func noter_effleurement(px: float) -> void:
	dernier_effleurement = maxf(px, 0.0)


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
## V3.3 — la derniere seconde entiere annoncee. -1 tant qu'aucune ne l'a ete.
var _dernier_tic_decompte: int = -1
## V3.4 — le tic-tac sous 10 s : la dernière seconde entière pour laquelle le tic a joué.
var _dernier_tic_chrono: int = -1
var _countdown_ready_local: bool = false
var _countdown_ready_peer: bool = false
## Ce match vient-il de l'appariement automatique (amical ou classé) ? Décide du
## tirage de carte — voir `_lancer_match_apparie()`.
var _matchmade_round: bool = false
## Le match apparié ci-dessus est-il classé ? C'est CETTE question, et non
## `_matchmade_round` seul, qui décide de la fenêtre de choix : la règle du
## miroir n'existe qu'en compétitif (« Absent de l'amical », décision d'Adrien
## du 2026-08-18), donc l'arsenal commun n'y est inconnu qu'en classé. En
## amical, l'arme est déjà choisie au menu — Adrien l'a demandé le 2026-09-09,
## après l'essai à deux machines où la fenêtre de dix secondes ne s'abrégeait
## que côté hôte : le client restait planté sur son décompte pendant que
## l'hôte avait déjà lancé la manche. Sans fenêtre à abréger, le défaut ne
## peut plus se produire en amical — le classé le garde, lui, tel quel.
var _matchmade_ranked: bool = false
## [Hôte] Un match apparié attend son invité. Armé à `match_ready`, consommé à
## l'arrivée de son arme — voir `_on_match_ready()` pour la raison d'être de ce
## report.
var _matchmade_start_pending: bool = false
## Jeton du départ apparié courant, même idée que `_round_token` : l'échéance d'un
## appariement abandonné vit encore vingt secondes, et sans lui elle annulerait le
## SUIVANT si le joueur repart en file entretemps.
var _matchmade_token: int = 0
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

## L'affiche de victoire/défaite en cours, tant qu'elle vit — voir
## `_poser_affiche_de_fin()`. `null` hors de cette fenêtre.
var _affiche_de_fin: AfficheDeFin = null

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

# [Hôte] Arme choisie par le client pendant la séquence de fin, retenue jusqu'à
# sa fin : la killcam de chaque machine a sa propre durée, le client peut donc se
# déclarer alors que l'hôte est encore au ralenti.
#
# Ce commentaire couvrait aussi `_pending_client_start` — « ou arriver » —, qui
# armait un départ de manche sans PRÊT. Le champ a été retiré le 2026-08-26 ; la
# phrase qui le décrivait part avec lui, sous peine de faire chercher un
# mécanisme qui n'existe plus.
var _pending_p2_weapon_idx: int = -1

## Les quatre armes historiques, devenues des CLASSES — chantier CLASSES.
##
## ⚠️ Le type change, les quatre blocs impératifs de `_ready()` NON : ils sont
## restés mot pour mot, seul `WeaponData.new()` est devenu `ClassData.new()`.
## Recopier leurs valeurs dans un catalogue neuf aurait garanti que deux jeux de
## nombres restent égaux, jamais qu'ils veuillent dire la même chose.
var weapon_pistolet: ClassData
var weapon_fusil: ClassData
var weapon_pompe: ClassData
var weapon_arbalete: ClassData

## Le catalogue des dix classes, indexé de 0 à 9 — l'index qui circule sur le
## fil et dans les râteliers. Bâti en fin de `_ready()`, après les quatre blocs.
var _classes: Array[ClassData] = []

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

## Chantier R (b) — le duel est-il rendu par le viewport racine plutôt que par un
## `SubViewport` ? Voir `_rendre_dans_la_racine()`.
var _rendu_racine := false

## ## Le brouillage de l'éblouissement — un appareil par vue rendue
##
## **Option 3, retenue par Adrien le 2026-08-26** : le flou et le halo vivent à
## l'intérieur de la vue qui rend, plutôt qu'un appareil global découpé en
## moitiés. À l'intérieur d'un viewport, la conversion monde → écran est celle
## du viewport : on ne peut plus poser l'effet sur la mauvaise moitié, et c'est
## un défaut qu'aucun test automatique ne verrait.
##
## Index 0 = la vue de J1, index 1 = celle de J2. Ils suivent le même bascule
## que le rendu : dans les `SubViewport` en écran scindé, dans la RACINE en vue
## unique — où les `SubViewport` sont arrêtés et n'ont plus rien à porter.
var _brouillages: Array = []
## Interrupteur du chantier R, public et volontairement simple.
##
## À `false`, la vue unique repasse par son `SubViewport` comme avant le
## 2026-08-25. Deux usages, et le second est le plus important : **il permet à un
## banc de mesurer l'AVANT et l'APRÈS dans la même exécution**, au lieu de
## comparer deux commits sur deux lancements — ce qui laisserait la machine, la
## charge et le focus varier entre les deux moitiés de la mesure. Il sert aussi
## de recours si le rendu racine se révélait mauvais sur une machine donnée.
var rendu_racine_autorise := true
## Le `World2D` propre de la fenêtre, mémorisé avant qu'on lui prête celui du jeu.
## Sans lui, revenir à l'écran scindé laisserait la racine sur le monde du duel.
var _monde_racine: World2D = null
## Masque de cull « tout visible », valeur d'origine d'un viewport.
const MASQUE_CULL_TOUT := 0xFFFFFFFF

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
	# DA4.13 — la caméra revient à sa place : ENTREE, ce qui s'installe.
	Charte.animer(tw, cam, "zoom", Vector2(0.98, 0.98), Vector2.ONE, 0.12,
		Charte.Courbe.ENTREE)

func _ready():
	add_to_group("game_state")
	# L'intro ne se joue qu'ici, au lancement. Les retours au menu passent par
	# `play_music`, qui bascule sans redémarrer le flux.
	AudioManager.demarrer_musique_au_lancement()

	
	# Le pistolet garde les valeurs par défaut de `WeaponData` — cookie
	# « pistolet », 35° de demi-angle, échelle 1,6, 2,2 s de recharge — SAUF son
	# chargeur : 6 balles et non 10 (décision d'Adrien, 2026-09-09).
	#
	# ⚠️ C'est la seule valeur du Parasite qui soit écrite ici, et il faut qu'elle
	# le reste : le reste vient de `WeaponData`, et un jour où quelqu'un changera
	# une valeur par défaut, le pistolet suivra. C'est voulu — il EST l'arme de
	# référence, celle dont les autres se comparent.
	weapon_pistolet = ClassData.new()
	weapon_pistolet.max_ammo = 6
	
	weapon_fusil = ClassData.new()
	weapon_fusil.name = "Fusil"
	weapon_fusil.cooldown = 0.24
	weapon_fusil.max_ammo = 4
	weapon_fusil.reload_time = 3.5
	weapon_fusil.spread_bloom_per_shot_deg = 3.5
	weapon_fusil.max_spread_bloom_deg = 20.0
	weapon_fusil.spread_recovery_speed_deg = 40.0
	weapon_fusil.bullet_speed = 15000.0
	weapon_fusil.bullet_max_distance = 15000.0
	weapon_fusil.damage_center = 60.0
	weapon_fusil.damage_edge = 25.0
	weapon_fusil.max_bounces = 2
	weapon_fusil.damages_shooter = true
	weapon_fusil.torch_cookie = "fusil"
	weapon_fusil.torch_angle_deg = 10.0
	# 3,5 auparavant. Portées arbitrées par Adrien le 2026-08-24 : chaque joueur
	# voit 480 unités devant lui, et seule l'arbalète a le droit d'éclairer plus
	# loin que ce qu'elle montre. Le fusil tombe à 0,96 écran, le pistolet à 0,85.
	weapon_fusil.torch_scale = 1.8
	
	weapon_pompe = ClassData.new()
	weapon_pompe.name = "Pompe"
	weapon_pompe.cooldown = 0.45  # 1,11 → 2,22 tirs/s (doublé)
	weapon_pompe.max_ammo = 6
	weapon_pompe.reload_time = 5.6
	weapon_pompe.recharge_par_cartouche = true  # 0,93 s la cartouche, et on tire dès la première
	weapon_pompe.spread_bloom_per_shot_deg = 0.0
	weapon_pompe.max_spread_bloom_deg = 0.0
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
	
	weapon_arbalete = ClassData.new()
	weapon_arbalete.name = "Arbalète"
	weapon_arbalete.cooldown = 0.3
	weapon_arbalete.max_ammo = 1
	weapon_arbalete.reload_time = 4.5
	weapon_arbalete.spread_bloom_per_shot_deg = 0.0
	weapon_arbalete.max_spread_bloom_deg = 0.0
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

	_batir_catalogue()

	ReplaySystem.replay_spawn_bullet.connect(_on_replay_spawn_bullet)
	ui.replay_requested.connect(_on_replay_requested)
	ui.join_requested.connect(_on_join_requested)
	ui.training_requested.connect(_on_training_requested)
	ui.intro_requested.connect(_on_intro_requested)
	ui.pick_window_cancelled.connect(_on_pick_window_cancelled)
	ui.quit_requested.connect(_on_quit_requested)
	ui.main_menu_requested.connect(_on_main_menu_requested)
	ui.quit_match_requested.connect(_on_quit_match_requested)
	
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
	
	# ⚠️ L'intro (DA6.6) et la séquence power-on (DA6.5) occupent toutes deux
	# l'écran entier au démarrage, et se passent toutes deux à la première
	# touche. Les jouer ensemble — ce que la fusion a produit sans le moindre
	# conflit textuel — donne un premier lancement illisible. L'une OU l'autre.
	if not _ouvrir_sur_intro_ou_menu():
		_allumage()

## DA6.6 — l'intro en planches précède le menu, au premier lancement seulement.
##
## Le menu n'est PAS monté derrière : il s'affiche quand l'intro rend la main.
## Sinon le joueur verrait le hub une fraction de seconde avant que les planches
## le recouvrent, et une introduction qui commence par montrer la fin
## n'introduit rien.
##
## ⚠️ **Le drapeau s'écrit au démarrage de l'intro, pas à sa fin.** Fermer le jeu
## pendant les quinze secondes la ferait revenir au lancement suivant, et
## indéfiniment pour qui n'a pas la patience de la voir en entier.
## Ouvre sur l'intro si elle a lieu d'être, sinon sur le menu.
##
## Rend **vrai si l'intro joue** — c'est ce qui décide si la séquence power-on
## doit se jouer aussi. Voir `_allumage()` pour le partage entre les deux.
func _ouvrir_sur_intro_ou_menu() -> bool:
	# `preload` plutôt que le `class_name` : il résout par le CHEMIN et ne dépend
	# donc pas de `.godot/global_script_class_cache.cfg`, qui n'est pas versionné
	# et qu'un arbre neuf n'a pas encore. La vraie parade reste `--import` (voir
	# « Pièges connus ») ; ceci n'est qu'une ceinture, et elle ne coûte rien.
	var Intro := preload("res://intro_planches.gd")
	if GameSettings.intro_vue or not Intro.disponible():
		ui.show_main_menu()
		return false
	GameSettings.marquer_intro_vue()
	var intro: CanvasLayer = Intro.new()
	add_child(intro)
	intro.terminee.connect(func() -> void:
		ui.show_main_menu()
		intro.queue_free())
	intro.jouer()
	return true


## Rejoue la cinématique d'introduction sur demande explicite du joueur.
func _on_intro_requested() -> void:
	var Intro := preload("res://intro_planches.gd")
	if not Intro.disponible():
		return
	AudioManager.play_music("music_intro")
	var intro: CanvasLayer = Intro.new()
	add_child(intro)
	intro.terminee.connect(func() -> void:
		AudioManager.play_music("music_menu")
		ui.show_main_menu()
		intro.queue_free())
	intro.jouer()

## DA6.5 — le lancement du jeu comme un allumage. APRÈS `show_main_menu()`, et
## c'est la décision d'origine : le menu est monté, vivant et prêt sous le voile
## pendant toute la séquence. Le faire attendre l'aurait fait apparaître d'un
## bloc à la fin — un à-coup, juste après une animation soignée. Elle se saute à
## la première touche ; voir `power_on.gd`.
##
## ⚠️ **Ne se joue PAS au tout premier lancement**, où l'intro en planches prend
## sa place. Deux cérémonies plein écran à la suite feraient de la découverte du
## jeu une attente, et l'intro se termine déjà sur le wordmark en braise —
## c'est-à-dire sur un allumage. Chacune est ainsi à son meilleur moment :
## l'histoire une fois, l'allumage toutes les autres fois.
func _allumage() -> void:
	PowerOn.lancer(self)

## V6.8 — les deux moities d'ecran s'allument. Le son marque le moment ou l'on
## cesse d'etre seul ; il vaut aussi sans la moitie visuelle de l'item, parce que
## c'est l'EVENEMENT qui compte, pas l'effet.
func _on_peer_connected(id: int):
	AudioManager.play_ui("ui_power_on")
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

		# **Une arrivée pendant une killcam ne prépare plus rien non plus.**
		#
		# Elle armait `_pending_client_start`, que la fin de la séquence
		# consommait en lançant `rpc_start_round` — une manche qui partait donc
		# sans qu'aucun « PRÊT » ait été échangé. Reste d'avant la porte PRÊT, et
		# **Adrien a tranché le 2026-08-26 : ce départ automatique n'est pas
		# voulu.** Le seul chemin de départ est celui des deux engagements.
		#
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
##
## ⚠️ **Cette fonction faisait DEUX MÉTIERS sous un seul nom**, et c'est ce qui a
## tenu la famille 4.1 rouge : *solder le match* — killcam soldée, score à zéro,
## retour au salon — et *signaler une absence* — dialogue, écran d'attente, et
## désarmement de ce que l'adversaire avait engagé.
##
## Le premier vaut toujours. Le second ne vaut que si personne n'est là. Un
## drapeau `revenu` avait été ajouté pour taire le **dialogue**, et le dialogue
## seulement ; tout le reste du script « parti » continuait de s'appliquer à
## quelqu'un qui venait de revenir — dont son « PRÊT », effacé sans que rien ne
## le lui dise. Les deux joueurs se retrouvaient devant un « prêt » qui ne
## produisait rien, pour toujours.
##
## **Un drapeau posé à l'entrée d'une fonction ne protège que la ligne qu'on a
## pensé à garder.** Ce que la fonction fait d'autre le traverse en silence. Le
## partage en trois est ce qui rend le tri visible : chaque geste vit désormais
## sous le nom de la situation qui le justifie, et il n'y a plus de « reste ».
func _annoncer_deconnexion() -> void:
	_deconnexion_differee = false
	# **Quelqu'un a pu revenir pendant la killcam**, et c'est la seule question
	# posée ici. Le report a créé une fenêtre où le monde change ; le code
	# différé la traversait sans regarder, et jouait le script « parti » sur
	# quelqu'un qui venait précisément de revenir.
	var revenu := not multiplayer.get_peers().is_empty()
	_solder_le_match()
	if revenu:
		_accueillir_le_revenant()
	else:
		_signaler_adversaire_parti()


## Le match est fini : on rend l'écran au salon. **Inconditionnel** — c'est la
## moitié qui vaut que l'adversaire soit parti, revenu, ou remplacé par un autre.
func _solder_le_match() -> void:
	# Toute séquence de fin en vol devient caduque : sans ce jeton elle
	# reviendrait afficher un écran de victoire par-dessus l'attente.
	_round_token += 1
	_end_sequence_active = false
	# Un départ interrompu en plein 3-2-1 laisserait countdown_left figé, donc
	# l'hôte immobile pour toujours dans son bac à sable.
	countdown_left = 0.0
	ui.set_countdown(0.0)
	ui.force_close_pause()
	_abort_killcam()
	_restore_viewports()
	round_active = false
	_conditions.arreter()
	# `sandbox_mode` ne parle PAS de l'adversaire, il parle de l'absence de
	# manche : sans lui, `player.gd` cesse de traiter les commandes et l'hôte se
	# retrouve immobile derrière son menu. Il reste donc des deux côtés du
	# partage — c'est ce que demande la ligne 4.4 de la checklist.
	sandbox_mode = true
	# L'engagement de l'HÔTE ne franchit pas la fin du match : le score vient
	# d'être remis à zéro, ce qui commence n'est plus une revanche. Un « ✓ PRÊT »
	# resté armé engagerait pour un match auquel personne n'a redit oui.
	p1_ready_for_rematch = false
	_hote_pret = false
	local_ready_for_rematch = false
	ui.btn_replay.text = "REJOUER"
	ui.btn_replay.remove_theme_color_override("font_color")
	# La déconnexion remet le match à zéro — ligne 4.3 de la checklist, « aucun
	# double comptage, le score repart de 0-0 ».
	p1_session_wins = 0
	p2_session_wins = 0
	serie_porteur = -1
	serie_longueur = 0
	_mot_de_serie = ""
	dernier_effleurement = -1.0
	p1_round_wins = 0
	p2_round_wins = 0
	# **C'est CETTE ligne qui ramène le menu.** Un commentaire a longtemps
	# affirmé que `show_waiting_for_opponent()` s'en chargeait ; elle n'allume
	# qu'un label du HUD de match, et le panneau restait éteint — l'hôte se
	# retrouvait dans son arène sans aucun moyen de se déclarer prêt. Trois
	# sondes ont été nécessaires pour l'établir, contre un mécanisme concurrent
	# parfaitement cohérent et faux.
	ui.rouvrir_le_salon()
	game_over = false


## Personne en face : on le dit, et on désarme ce que l'absent avait engagé.
##
## **Rien de ce qui suit ne doit atteindre quelqu'un qui est là** — c'est toute
## la raison d'être de cette fonction séparée, et le défaut qu'elle referme.
func _signaler_adversaire_parti() -> void:
	ui.show_dialog_message("Déconnexion", "Le Joueur 2 s'est déconnecté.",
		UI.Registre.ATTENTION)
	# Un « ✓ PRÊT » resté armé attendrait un adversaire qui n'existe plus.
	p2_ready_for_rematch = false
	_pending_p2_weapon_idx = -1
	# L'hôte simule P2 : le laisser dans l'arène y planterait le corps solide
	# d'un joueur qui n'est plus connecté.
	p2.hide()
	p2.set_collision_layer_value(1, false)
	p2.set_collision_mask_value(1, false)
	_set_training_target_active(true)
	ui.show_waiting_for_opponent()
	ui.time_label.text = "EN ATTENTE DU JOUEUR 2..."


## Quelqu'un est arrivé pendant la killcam : le salon l'accueille avec ce qu'il a
## déjà engagé.
##
## **Son « PRÊT » survit à la fin de la killcam d'en face, et c'est la propriété
## que vérifie la famille 4.1.** L'effacer laissait les deux joueurs devant un
## « prêt » qui ne produisait rien : lui croyait s'être déclaré — son bouton
## affichait « ✓ PRÊT » —, l'hôte ne le voyait plus, aucune manche ne démarrait
## plus jamais, et rien ne le disait à personne. Mesuré au banc le 2026-08-26 :
## soixante appuis de l'hôte, zéro départ.
##
## L'arme retenue pendant le ralenti se pose ici : c'est le seul instant où la
## séquence de fin est close ET où l'on sait qu'il y a quelqu'un pour la porter.
##
## ⚠️ **Aucune manche ne part d'ici.** `_check_rematch_start()` exige les deux
## engagements — le départ automatique sans PRÊT a été retiré le même jour, sur
## décision d'Adrien. Ce qui est rendu au revenant, c'est son tour de parole, pas
## le match.
func _accueillir_le_revenant() -> void:
	if _pending_p2_weapon_idx >= 0:
		_set_p2_weapon_button(_pending_p2_weapon_idx)
		_pending_p2_weapon_idx = -1
	# Ni dialogue ni écran d'attente : on n'annonce pas une absence à quelqu'un
	# dont l'adversaire est déjà là.
	ui.time_label.text = "PRÊT ?"
	# Sous condition, parce que la branche « personne n'est prêt » de
	# `_check_rematch_start()` écrit « EN ATTENTE D'UN ADVERSAIRE… » — vrai quand
	# il n'y a personne, faux ici, et c'est le message qui disait déjà l'inverse
	# de la vérité une fois dans ce fichier.
	if p2_ready_for_rematch:
		_check_rematch_start()


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
	_matchmade_ranked = false
	_matchmade_start_pending = false

	game_over = false
	ui.hide_game_over()
	_restore_viewports()
	# On passe par le démarrage ordinaire : arène, joueurs, armes, vues et
	# caméras sont posés par le chemin que le jeu emprunte déjà, plutôt que par
	# un second qui finirait par en diverger. La manche est désarmée juste après.
	# ⚠️ La classe de l'ENTRAÎNEMENT est celle du menu, pas `_hosted_weapon_1_idx`.
	# Ce chemin lisait la variable de l'hébergement EN LIGNE, qui vaut 0 par défaut
	# et n'est écrite que sur les chemins d'hébergement : l'entraînement partait
	# donc toujours en Parasite, quelle que soit la classe choisie. Adrien,
	# 2026-09-10 : « je n'arrive pas à choisir d'autres classes en mode
	# entraînement ». Le menu marchait ; c'est ce lancement qui l'ignorait.
	# On ne réécrit PAS `_hosted_weapon_1_idx` d'ici : c'est un état d'hôte,
	# celui que `rpc_start_round` envoie.
	_do_start_round(ui.selected_weapon_index(0), 0)

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
		CandelaTileSet.TILE_SIZE, data)
	# V5.10 — la presence de la salle se pose sur la MEME carte, au meme endroit
	# et pour la meme raison : les ponctuels doivent tomber DANS l'arene, et
	# c'est ici qu'on sait ou elle commence et ou elle finit. Une zone ecrite en
	# dur enverrait les sons d'ambiance derriere les murs a la premiere carte
	# d'une autre taille — audible comme un defaut de panoramique, introuvable
	# comme une constante.
	var _grille := MapCodec.get_grid_size(data)
	AudioManager.demarrer_ambiance(Rect2(Vector2.ZERO,
		Vector2(_grille) * Vector2(CandelaTileSet.TILE_SIZE)))

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
			"CustomWalls_P1", "CustomWalls_P2", "CustomWallBodies",
			"ArenaDecor", "ArenaDecor_P1", "ArenaDecor_P2"]:
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

	# V5.8 — Rendu Shimmer et spécularité du liseré des murs sous la torche.
	var wall_mat := CandelaTileSet.creer_materiau_mur()
	walls_layer.material = wall_mat

	# Écran partagé : chaque joueur reçoit sa copie des calques, éclairée par
	# sa seule lumière ambiante. Sans ça, le halo d'un joueur révélerait sa
	# position sur l'écran de l'autre.
	_duplicate_layer_for_player(floor_layer, 2, 1 | 16)
	_duplicate_layer_for_player(floor_layer, 4, 1 | 32)
	_duplicate_layer_for_player(walls_layer, 2, 1 | 16)
	_duplicate_layer_for_player(walls_layer, 4, 1 | 32)
	# ⚠️ **L'original reste éclairé après sa propre duplication, et c'est un
	# défaut — pas la copie qui manque.** `floor_layer`/`walls_layer` gardent
	# leur `visibility_layer` par défaut (1), visible dans les DEUX vues au
	# même titre que les deux copies : toute lumière qui touche la couche
	# décor (1) — la torche des deux joueurs y compris, `range_item_cull_mask`
	# à l'appui — éclaire donc le sol/les murs DEUX FOIS, l'original en mix
	# normal PUIS la copie du joueur par-dessus en additif. Peu visible sur un
	# halo blanc ; flagrant sur un halo saturé (la fusée) où le doublage pousse
	# les canaux vers l'écrêtage. Trouvé le 2026-09-09 en diagnostiquant le
	# carré signalé par Adrien près d'une fusée — ce n'en est PAS la cause
	# (vérifié : le carré persiste identique une fois ce doublage corrigé),
	# mais c'est un vrai défaut distinct. `hide()` et non `queue_free()` :
	# l'original reste le porteur des données (`MapData.apply_to_layers()`,
	# `MapGeometry.build_collisions()` y lisent la géométrie) — le détruire
	# casserait la collision, pas seulement le rendu.
	floor_layer.hide()
	walls_layer.hide()
	# Habillage d'atelier & décors de l'arène (marquages danger, pochoirs, mobilier)
	var decor := ArenaDecorScript.build(data, arena)
	if decor:
		decor.hide()

	# Chantier FUSÉE : textures de volutes et shader du voile se paient ICI,
	# pas à l'image du premier lancer (hoquet pile sur l'action — la classe de
	# défaut de la texture de torche, weapon_data.gd).
	Fusee.prechauffer(arena)

## Duplique un calque pour un seul viewport, avec son masque de lumière propre.
func _duplicate_layer_for_player(layer: TileMapLayer, visibility: int, light_mask: int) -> void:
	var copy := layer.duplicate() as TileMapLayer
	copy.name = "%s_P%d" % [layer.name, 1 if visibility == 2 else 2]
	copy.visibility_layer = visibility
	copy.light_mask = light_mask
	if layer.material is ShaderMaterial:
		copy.material = layer.material.duplicate()
	else:
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
	# ⚠️ **`selected_weapon_index()` et plus `get_pressed_button().get_index()`.**
	# L'index de l'arme était la POSITION du bouton dans son râtelier ; depuis que
	# la liste des classes s'ordonne par rang, la position et l'index ne sont plus
	# le même nombre — et un désaccord n'aurait levé aucune erreur, il aurait
	# simplement fait partir le joueur avec une autre classe que celle affichée.
	var w1_idx = ui.selected_weapon_index(0)
	var w2_idx = ui.selected_weapon_index(1)

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
	p1.reset_flashlight_latch()
	p2.reset_flashlight_latch()

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
	# tir fatal repartent de zéro (pas fantôme et « à N px » périmé sinon), et
	# le cran plein d'un bouton à deux crans ne doit pas rallumer la torche
	# tout seul (voir `Player.reset_flashlight_latch()`).
	p1.reset_step_tracker()
	p2.reset_step_tracker()
	p1.reset_flashlight_latch()
	p2.reset_flashlight_latch()
	time_left = round_time
	round_active = true
	game_over = false
	_conditions.commencer()
	# Le chrono repart en blanc : sans ça, une manche qui suit une fin de match
	# hérite de l'or ou du rouge de la précédente jusqu'au premier passage de
	# seuil — soit pendant ses quatre premières minutes.
	ui.reinitialiser_chrono()
	Engine.time_scale = 1.0
	_liberer_le_releve()
	# Départ figé des deux côtés : le décompte absorbe le trajet de rpc_start_round.
	# Les dix secondes sont la fenêtre de choix du classé — voir
	# `_matchmade_ranked`. Un match apparié amical garde les trois secondes
	# ordinaires : rien n'y reste à choisir une fois l'adversaire trouvé.
	countdown_left = COUNTDOWN_MATCHMADE if (_matchmade_round and _matchmade_ranked) \
		else COUNTDOWN_DURATION
	# V3.3 — le suivi des secondes entieres. **Le sentinelle -1 n'est pas une
	# precaution, il est necessaire** : un decompte arme a 3,0 est DEJA a trois
	# des la premiere image, il n'y a donc aucune transition « vers 3 » a
	# attraper. Sans lui, `count_3` ne sortirait jamais — et son absence
	# passerait pour une intention.
	_dernier_tic_decompte = -1
	_dernier_tic_chrono = -1
	_countdown_ready_local = false
	_countdown_ready_peer = false
	# La fenêtre de choix s'ouvre avec le décompte, et seulement pour un match
	# apparié CLASSÉ : ailleurs l'arme est déjà choisie, un panneau modal ne
	# ferait qu'arrêter le joueur devant une question déjà répondue.
	if _matchmade_round and _matchmade_ranked:
		ui.show_pick_window(matchmade_arsenal(), matchmade_arsenal_reason())
	else:
		ui.hide_pick_window()
	ui.set_countdown(countdown_left)
	_time_sync_accum = 0.0
	_predicted_shots.clear()
	_pos_history.clear()
	# Le stock de fusées repart avec la manche — exécuté chez les deux pairs,
	# comme tout _do_start_round. Les nœuds, eux, sont purgés avec les balles.
	_fusees_restantes = [_stock_fusees(p1), _stock_fusees(p2)]
	_fusees_accumulateur = [0.0, 0.0]
	_fusees_profil = [_profil_fusees(p1), _profil_fusees(p2)]
	# Ce qu'on remet à zéro est le nombre de gadgets POSÉS, pas un stock restant.
	# Voir `gadget_disponible()` : le plafond se relit à chaque appui.
	_gadgets_poses_par = [0, 0]
	_gadget_attente = [0.0, 0.0]
	_batterie = [1.0, 1.0]
	_purger_fusees_killcam()
	# FU5 — le piétinement ne doit rien hériter de la manche précédente : un
	# joueur déjà immobile au dernier « FIGHT ! » ne doit pas repartir avec
	# 0,7 s déjà acquises sur une fusée qui vient d'apparaître.
	_pietinement_temps = [0.0, 0.0]
	_pietinement_fusee = [null, null]
	ghost_p1.hide()
	ghost_p2.hide()
	for c in bullet_container.get_children():
		c.queue_free()
	ReplaySystem.start_recording()
	
	# Entre deux manches : le même bilan, sans la série — elle ne se proclame
	# qu'une fois le match joué.
	ui.poser_bilan(p1_session_wins, p2_session_wins)

func _process(delta):
	# PE2.1 — une image rendue, et le lien du moment. Négatif = pas de lien.
	_conditions.echantillonner(NetworkManager.rtt_ms if NetworkManager.has_rtt else -1.0)
	# PE3.1 — le régime de rendu suit l'arène : manche comptée, entraînement ou
	# salon d'attente sont « en arène » ; tout le reste est menu.
	var en_arene := round_active or sandbox_mode
	if en_arene != _arene_signalee:
		_arene_signalee = en_arene
		GameSettings.signaler_arene(en_arene)

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		_record_position_history()

	_maj_brouillage()

	if round_active:
		if countdown_left > 0.0:
			# Les deux prêts abrègent la fenêtre. L'hôte tranche seul : il porte le
			# chronomètre, et laisser chaque camp décider produirait deux départs
			# décalés d'un aller-retour. N'existe qu'en classé — un match amical
			# n'ouvre plus cette fenêtre du tout (`_matchmade_ranked`), donc ces
			# drapeaux y restent à `false` et cette branche ne s'y déclenche jamais.
			#
			# ⚠️ **Longtemps vrai à moitié seulement.** L'hôte collapsait bien SON
			# propre décompte ici, mais rien n'en informait le client — measured
			# à deux machines le 2026-09-09 (v0.3.1) : la manche partait pour
			# l'hôte seul, le client restant planté sur ses dix secondes. Le
			# `rpc_id` ci-dessous est le canal qui manquait, symétrique de
			# `rpc_countdown_ready` (qui informe déjà l'hôte que le CLIENT est
			# prêt) — voir « Deux prêts, un seul départ » aux Pièges connus, qui
			# documentait le défaut sans le fermer côté classé.
			if _matchmade_round and _matchmade_ranked and _countdown_ready_local \
					and _countdown_ready_peer \
					and NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
				countdown_left = 0.0
				# `client_peer_id` reste à 0 en écran partagé — pas de pair à
				# prévenir, et c'est ce qui laisse `_run_fenetre()` exercer ce
				# chemin sans réseau ni appariement, comme conçu.
				if client_peer_id != 0:
					rpc_id(client_peer_id, "rpc_countdown_launch")
			countdown_left = maxf(0.0, countdown_left - delta)
			ui.set_countdown(countdown_left)
			# V3.3 — une note par seconde entiere, et seulement les trois
			# dernieres : un depart apparie ouvre a dix secondes, et compter de
			# dix a un ferait du decompte une attente au lieu d'un depart.
			var _tic := int(ceil(countdown_left))
			if _tic != _dernier_tic_decompte:
				_dernier_tic_decompte = _tic
				if _tic >= 1 and _tic <= 3:
					AudioManager.play_count(_tic)
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
			# V3.4 — le tic-tac sous 10 s : un tic sec par seconde entière quand le
			# chrono passe en rouge et bat.
			if time_left < 10.0 and time_left > 0.0:
				var tic_chrono := int(ceil(time_left))
				if tic_chrono != _dernier_tic_chrono:
					_dernier_tic_chrono = tic_chrono
					AudioManager.play_ui("ui_tick", -4.0)
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

	# **Même piège que le regard, et il a fallu le payer deux fois.** Ce suivi
	# vivait dans `if round_active:`, alors que le lancer de fusée s'autorise
	# explicitement hors manche (`if not round_active and not sandbox_mode:
	# return`). À l'entraînement, qui désarme la manche, on pouvait donc
	# allumer une fusée et **jamais l'éteindre au pied** : la mécanique était
	# muette, sans erreur, dans le seul mode où l'on vient l'essayer.
	# La garde suit désormais celle du lancer, pas celle du score.
	if round_active or sandbox_mode:
		_maj_extinction_fusees(delta)

	# Même raison, un cran plus loin : la RÉCUPÉRATION de l'éblouissement doit
	# continuer pendant la killcam et l'écran de fin, sinon un joueur ébloui à la
	# dernière seconde d'une manche la termine blanc et rouvre les yeux au
	# « FIGHT ! » suivant. Le faisceau, lui, ne verse plus rien : les gardes de
	# `_maj_eblouissement` s'en chargent.
	_maj_eblouissement(delta)
	_maj_gadgets(delta)
	_accorder_fusees(delta)
	_maj_reserves_gadgets(delta)

	# V4.12 — le recul de tir décroît de lui-même et s'additionne au shake.
	_cam_kick[0] = _cam_kick[0].move_toward(Vector2.ZERO, delta * 60.0)
	_cam_kick[1] = _cam_kick[1].move_toward(Vector2.ZERO, delta * 60.0)

	if cam1 != null:
		if cam1_shake_time > 0:
			cam1_shake_time -= delta
			cam1.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 15.0 + _cam_kick[0]
		else:
			cam1.offset = _cam_kick[0]

	if cam2 != null:
		if cam2_shake_time > 0:
			cam2_shake_time -= delta
			cam2.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 15.0 + _cam_kick[1]
		else:
			cam2.offset = _cam_kick[1]
		
	if ReplaySystem.recording:
		ReplaySystem.record_frame(p1, p2, bullet_container, delta)
			
	if ReplaySystem.playing_back:
		current_snap = ReplaySystem.get_next_frame(delta)
		_suivre_le_releve()
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

			# Les fusées du passé, reconstruites à l'âge lu dans l'instantané.
			_maj_fusees_killcam(current_snap)
			
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
				_liberer_le_releve()
		if Input.is_action_just_pressed("p2_skip_killcam"):
			if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
				ReplaySystem.playing_back = false
				Engine.time_scale = 1.0
				_liberer_le_releve()

	elif not _end_sequence_active and not _fusees_killcam.is_empty():
		# Le rejeu vient de finir (ou d'être passé) : ses fusées partent avec
		# lui — mais PAS pendant l'arrêt sur image de fin, qui prolonge la
		# dernière image du rejeu : une fusée qui s'y évapore d'une image se
		# lirait comme un bug d'affichage.
		_purger_fusees_killcam()

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

	# ── PASSE 1 : lire, et retenir la source GAGNANTE ────────────────────────
	#
	# ⚠️ **Le MAX doit faire remonter la SOURCE, pas seulement sa valeur.**
	# `ui._poser_voile(rect, victime, source)` dérive le penchant du voile de la
	# POSITION de la source ; le shader ne reçoit qu'un scalaire de relèvement.
	# Un max qui ne retiendrait qu'un niveau laisserait le voile pencher vers
	# l'adversaire pendant qu'une lumière posée brûle derrière — et **aucune
	# suite ne le verrait**, rien ne teste le relèvement. Relevé par la session
	# « retouche éblouissement », 2026-09-09.
	#
	# ⚠️ **Deux passes strictes, jamais une intégration au fil de la lecture** :
	# le résultat dépendrait sinon de l'ordre des sources, c'est-à-dire de
	# l'ordre du groupe de scène. C'est la raison pour laquelle le calcul à deux
	# termes lisait déjà les deux plafonds avant d'intégrer.
	#
	# ⚠️ **Le MAX, jamais la somme** (décision d'Adrien, 2026-09-09). Le modèle
	# est un PLAFOND, pas une intégrale — c'est ce qui l'empêche de dériver, et
	# le max préserve strictement cette propriété : deux torches faibles ne
	# peuvent pas aveugler à force d'être deux.
	var gagnante := {p1: null, p2: null}
	var plafond := {p1: 0.0, p2: 0.0}
	for src in _sources_eblouissantes():
		for cible in [p1, p2]:
			var v := _plafond_de_source(espace, src, cible)
			if v > plafond[cible]:
				plafond[cible] = v
				gagnante[cible] = src["noeud"]

	# ── PASSE 2 : intégrer ───────────────────────────────────────────────────
	p1.integrer_eblouissement(plafond[p1], delta)
	p2.integrer_eblouissement(plafond[p2], delta)
	p1.source_eblouissante = gagnante[p1]
	p2.source_eblouissante = gagnante[p2]


## Les sources qui peuvent éblouir, cette image.
##
## ⚠️ **Deux familles EXCLUES, explicitement, avec leur raison** — une exclusion
## subie par oubli est un défaut, une exclusion écrite est une décision :
##
##   • **les particules** (240 pré-allouées, sang 64 px, étincelles 32 px). Elles
##     sont tirées au sort à chaque émission, donc ABSENTES chez l'autre pair :
##     le résultat serait non reproductible d'une machine à l'autre, donc
##     indébogable. Et 200 sources × 2 cibles coûteraient ~1,3 ms par image,
##     **dix fois la marge de cadence entière** (139 µs).
##   • **l'ambiance personnelle** (`range_item_cull_mask` 16 pour J1, 32 pour
##     J2). Elle n'éclaire que les décals de son propre joueur : elle n'existe
##     pas dans le monde partagé, et l'adversaire ne la voit jamais.
##
## ⚠️ **Une carte ne peut pas porter de lumière**, et c'est ce qui rend cette
## liste bornée. Le format v3 ne contient que sol, murs et points d'apparition ;
## l'outil « lumière » de l'éditeur n'est qu'un bouton d'aperçu. Une arène
## aveuglante n'est donc pas fabricable — c'était un acquis, ça devient une
## garantie d'équité, et il faudra l'écrire le jour où le format bougera.
func _sources_eblouissantes() -> Array:
	var out: Array = []
	for j in [p1, p2]:
		if _en_jeu(j) and j.flashlight_on:
			out.append({
				"noeud": j,
				# Le PORTEUR : une source portée n'éblouit son porteur que par
				# rétrodiffusion. Une source posée n'a pas de porteur, et
				# éblouit tout le monde pareil, poseur compris.
				"porteur": j,
				"dirigee": true,
				"rayon": j.current_weapon.portee_torche() if j.current_weapon else 0.0,
				"arme": j.current_weapon,
			})

	# ── Les fusées éclairantes ───────────────────────────────────────────────
	#
	# Elles referment la ligne « la fusée n'alimente pas l'éblouissement » : la
	# lumière la plus violente du jeu n'aveuglait personne.
	#
	# ⚠️ **Régime de PROXIMITÉ, sans axe** : une fusée au sol crache dans toutes
	# les directions. Et **pas de porteur** — on s'éblouit avec sa propre fusée,
	# décision d'Adrien : on ne la lance pas à ses pieds impunément.
	#
	# ⚠️ **Rayon d'ÉBLOUISSEMENT ≠ empreinte de RENDU.** La fusée posée éclaire
	# sur 440 px, mais la torche cesse d'éblouir au-delà de ~400 px (mesuré :
	# 0,81 à 140 px dans l'axe, 0,00 à 460). Lui donner une portée d'aveuglement
	# plus grande que la torche ferait que le MAX la choisit presque toujours, et
	# la torche cesserait d'être une menace. On la borne donc sur la torche.
	#
	# ⚠️ **Un rejeu n'éblouit personne** — règle déjà écrite pour le flash de
	# tir. Les fusées de killcam sont dans le même groupe que les vraies ; le
	# filtre est ici, jamais dans `Fusee`, dont le groupe doit rester non filtré
	# pour l'occultation des sprites et des sons.
	for f in get_tree().get_nodes_in_group("fusees"):
		if not is_instance_valid(f) or not (f is Node2D):
			continue
		if f.get("is_replay"):
			continue
		if f.has_method("est_allumee_au_sol") and not f.est_allumee_au_sol():
			continue
		out.append({
			"noeud": f,
			"porteur": null,
			"dirigee": false,
			"rayon": RAYON_EBLOUISSEMENT_FUSEE,
			"arme": null,
		})

	# ── Les gadgets posés ────────────────────────────────────────────────────
	#
	# C'est ce que l'étape 6a préparait, et la torche fantôme du Braconnier est
	# la raison pour laquelle elle a été faite : *si elle n'éblouit pas, il
	# suffit à l'adversaire de la regarder en face pour savoir que c'est un
	# faux.* Le mensonge n'est complet que si elle aveugle comme une vraie.
	#
	# ⚠️ **Aucun porteur, jamais** — y compris pour celui qui l'a posée. Une
	# lampe qu'on a plantée soi-même reste une lampe : marcher devant coûte les
	# yeux. C'est la même règle que pour la fusée, arbitrée par Adrien — *« on ne
	# la lance pas à ses pieds impunément »*.
	for g in get_tree().get_nodes_in_group("gadgets"):
		if not is_instance_valid(g) or not (g is Node2D):
			continue
		if not g.eblouit or g.is_queued_for_deletion():
			continue
		out.append({
			"noeud": g,
			"porteur": null,
			"dirigee": g.eblouissement_dirige,
			"rayon": g.rayon_eblouissement,
			# La classe du poseur porte le cookie : c'est elle qu'on
			# échantillonne, exactement comme on échantillonne l'arme d'un joueur.
			"arme": g.classe_du_poseur,
		})
	return out


## Jusqu'où une fusée posée peut aveugler, en pixels de monde.
##
## Volontairement PLUS PETIT que son empreinte de rendu (440 px) : elle éclaire
## plus loin qu'elle n'aveugle, ce qui est vrai d'une vraie fusée de détresse et
## ce qui la garde comparable à la torche. À doser au banc, jamais à l'aveugle.
const RAYON_EBLOUISSEMENT_FUSEE := 400.0


## Ce qu'une source verse dans les yeux d'une cible, entre 0 et 1.
func _plafond_de_source(espace: PhysicsDirectSpaceState2D, src: Dictionary,
		cible: Node2D) -> float:
	if not _en_jeu(cible):
		return 0.0
	var noeud: Node2D = src["noeud"]
	if not is_instance_valid(noeud):
		return 0.0

	# ── Le cas de SOI ────────────────────────────────────────────────────────
	if src["porteur"] == cible:
		# Une source PORTÉE : on ne se tient pas dans son propre faisceau, on
		# reçoit ce qui revient des murs. Lire le cookie ici échantillonnerait
		# son centre — la valeur maximale — et allumer sa lampe saturerait
		# l'éblouissement d'un coup.
		# ⚠️ Et une torche que le grésillement éteint ne revient pas des murs non
		# plus : le halo rendu en dérive (`player.gd`), la pénalité doit suivre.
		# Linéaire, comme le halo — surtout pas de `plafond_pour` ici.
		return Eblouissement.RETRODIFFUSION * Eblouissement.gain_taille(src["rayon"]) \
			* facteur_de_lampe_a(noeud.global_position)

	if src["dirigee"]:
		# Le chemin historique, inchangé : on LIT le pixel du faisceau.
		if src["porteur"] != null:
			return _lumiere_recue(espace, noeud, cible)
		# Une source dirigée SANS porteur : une lumière posée qui a un axe — la
		# torche fantôme. Elle passe par le même échantillonnage, sans les
		# préconditions qui ne valent que pour un joueur (`_en_jeu`, `flashlight_on`).
		return _lumiere_du_faisceau(espace, src["arme"], noeud, cible)

	# ── PROXIMITÉ ────────────────────────────────────────────────────────────
	var d := noeud.global_position.distance_to(cible.global_position)
	var i := Eblouissement.intensite_proximite(d, src["rayon"])
	if i <= 0.0:
		return 0.0
	if not _ligne_de_vue_depuis(espace, noeud.global_position, cible, RID()):
		return 0.0
	return Eblouissement.plafond_pour(i) * Eblouissement.gain_taille(src["rayon"])

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
	# ⚠️ **Une torche éteinte par le grésillement n'éblouit plus** (Adrien,
	# 2026-09-10). Le facteur est celui-là même que `player.gd` applique à
	# l'énergie rendue — le MINIMUM des bobines —, lu ici chez l'hôte, qui seul
	# calcule l'éblouissement. Il porte sur la lumière qui ARRIVE, avant sa
	# conversion en pénalité : une lampe à moitié éteinte verse moitié moins, et la
	# courbe de `plafond_pour` fait le reste.
	return _lumiere_du_faisceau(espace, source.current_weapon, source, cible,
		facteur_de_lampe_a(source.global_position))


## Le facteur de lampe à une position : le MINIMUM des gadgets, exactement comme
## `player.gd` le calcule pour l'énergie rendue — deux bobines n'éteignent pas deux
## fois. Une seule règle pour ce que l'écran montre et ce que l'éblouissement coûte.
func facteur_de_lampe_a(pos: Vector2) -> float:
	var f := 1.0
	for g in get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and g.has_method("facteur_de_lampe"):
			f = minf(f, g.facteur_de_lampe(pos))
	return f


## Ce qu'un FAISCEAU verse dans les yeux d'une cible, quel que soit ce qui le
## porte — un joueur, ou une lampe posée.
##
## ⚠️ **Extrait de `_lumiere_recue()` pour qu'il n'y ait qu'un échantillonnage.**
## La torche fantôme avait besoin des cinq lignes du milieu sans les
## préconditions du dessus (`_en_jeu`, `flashlight_on`), qui n'ont de sens que
## pour un joueur. Les recopier aurait donné une seconde définition du même
## faisceau — la faute exacte que le commentaire ci-dessus passe vingt lignes à
## expliquer.
func _lumiere_du_faisceau(espace: PhysicsDirectSpaceState2D, arme: WeaponData,
		source: Node2D, cible: Node2D, facteur: float = 1.0) -> float:
	if arme == null or not is_instance_valid(source):
		return 0.0
	# L'arme sait à quelle échelle son faisceau est étalé ; on ne la lui demande
	# plus. Voir `WeaponData.lumiere_recue()` pour les trois fois où ce choix,
	# laissé à l'appelant, s'est trompé le même jour.
	var intensite := arme.lumiere_recue(source.global_transform.x,
		source.global_position, cible.global_position) * facteur
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
	return _ligne_de_vue_depuis(espace, source.global_position, cible,
		source.get_rid())


## La même, depuis un POINT plutôt qu'un corps.
##
## ⚠️ La surcharge ci-dessus est conservée parce que
## `tools/planche_eblouissement.gd` la NOMME dans ses préconditions, et que
## `tools/test_banc.gd` vérifie qu'elle existe. Un garde-fou qui nomme un symbole
## se périme EN VERT le jour où on le renomme — piège déjà consigné.
func _ligne_de_vue_depuis(espace: PhysicsDirectSpaceState2D, depuis: Vector2,
		cible: Node2D, exclure: RID) -> bool:
	# ⚠️ **Les gadgets arrêtent le regard de la lumière autant que les murs**, et
	# ils ne le faisaient pas. Le voile du Spectre coupait le faisceau à l'écran —
	# son occluder le fait — pendant que l'éblouissement, lui, traversait la bâche
	# comme si elle n'existait pas : on voyait le noir et on prenait la lumière.
	# Défaut introduit par la pose à l'étape 10, trouvé en branchant la torche
	# fantôme, corrigé ici parce que c'est le même sujet.
	#
	# Ce masque repose sur un invariant, et il faut qu'il le reste : **tout gadget
	# porte un occluder**, `GadgetBase._monter_occluder()` étant appelé sans
	# condition. Le jour où l'un d'eux n'en portera plus, il arrêterait
	# l'éblouissement sans arrêter la lumière — l'inverse du défaut d'aujourd'hui.
	var q := PhysicsRayQueryParameters2D.create(depuis, cible.global_position,
		MapGeometry.WALL_LAYER | MapGeometry.GADGET_LAYER)
	# ⚠️ **Les gadgets qui n'arrêtent pas la lumière sont retirés du rayon.** Le
	# masque ne sait pas les distinguer — ils partagent tous la même couche
	# physique, parce que c'est elle qui décide ce qu'une BALLE touche. Sans cette
	# exclusion, la mine au magnésium, qui est un boîtier plat sans occluder,
	# arrêterait l'aveuglement sans arrêter le faisceau : l'inverse exact du
	# défaut corrigé à l'étape 11, et tout aussi muet.
	var exclus: Array[RID] = []
	if exclure.is_valid():
		exclus.append(exclure)
	for g in get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and g is CollisionObject2D and not g.occulte_la_lumiere:
			exclus.append(g.get_rid())
	q.exclude = exclus
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

## L'index de classe d'une arme, pour le fil — les DIX, et non les quatre d'origine.
##
## ⚠️ **Il ne codait que quatre armes** et rendait 0 pour tout le reste : les six
## classes neuves voyageaient sur le fil comme le Parasite, et le client simulait
## les balles de l'hôte avec la mauvaise arme — vitesse, portée, lumière, dégâts
## infligés aux gadgets. Trouvé le 2026-09-10 par le contre-examen d'une enquête
## sur le mode de tir. Invisible hors ligne : en local et à l'entraînement, la
## balle ne passe jamais par le fil, et les deux bouts n'ont jamais divergé.
func _get_weapon_idx(w: WeaponData) -> int:
	var idx := _classes.find(w)
	return idx if idx >= 0 else 0

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

# ── Fusée éclairante — chantier FUSÉE, étape FU1 ───────────────────────────
# Même architecture que la balle : l'objet n'est pas répliqué, seul le spawn
# transite (RPC fiable de l'hôte), et chaque machine simule localement une
# trajectoire déterministe. PAS de prédiction client : un objet utilitaire à
# une charge tolère un demi-RTT de latence, contrairement au tir — le bit de
# fusée voyage dans la commande numérotée et c'est l'hôte, en simulant P2, qui
# détecte le front et spawne pour tout le monde.

## La réserve de fusées de chaque joueur ; illimitée en bac à sable.
##
## ⚠️ **Elle ne vient plus d'une constante mais de la CLASSE** — chantier CLASSES,
## étape 18. `FuseeModele.STOCK_PAR_MANCHE` valait un pour tout le monde ; le
## Spectre n'en a aucune (« la seule classe qui n'éclaire jamais »), le
## Terrassier en a trois et l'Allumeur deux qui se rechargent. Les profils
## portaient ces valeurs depuis l'étape 1 et personne ne les lisait.
var _fusees_restantes: Array[int] = [0, 0]

## Le temps capitalisé vers la prochaine fusée, par joueur. **Hôte seul** :
## `FlareProfile.avancer()` dit pourquoi — deux accumulateurs locaux dériveraient
## d'un demi-RTT à chaque consommation, ce qui est inoffensif à stock 1 et
## mordant à stock 3.
var _fusees_accumulateur: Array[float] = [0.0, 0.0]

## Le profil suivi par joueur, pour détecter un CHANGEMENT DE CLASSE.
##
## ⚠️ Même piège que le stock de gadgets : la fenêtre de choix d'un match apparié
## s'ouvre avec le décompte, donc APRÈS `_do_start_round`, et
## `pick_countdown_weapon()` change l'arme équipée pendant ces dix secondes. Un
## stock semé avant le choix donnerait à qui change de classe la réserve de celle
## qu'il vient de quitter — sans erreur, et invisible tant que les deux en ont
## autant.
var _fusees_profil: Array = [null, null]
## Fusées reconstruites par la killcam, par graine.
var _fusees_killcam: Dictionary = {}

# FU5 — piétinement, par joueur (index 0/1 = p1/p2). Hôte seul : voir
# `_maj_extinction_fusees`. `_pietinement_pos` est réévaluée CHAQUE tick (pas
# seulement au début du piétinement) : c'est une VITESSE qu'on mesure, comme
# le sillage de la fusée elle-même (`fusee.gd`), pas une distance à un point
# fixe — sinon le moindre tremblement d'input humain ne tiendrait jamais 0,7 s.
var _pietinement_temps: Array[float] = [0.0, 0.0]
var _pietinement_fusee: Array = [null, null]
var _pietinement_pos: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

func fusee_disponible(pid: int) -> bool:
	if pid < 0 or pid >= _fusees_restantes.size():
		return false
	# ⚠️ **L'entraînement COMPTE, depuis le 2026-09-10.** Adrien : « je pouvais
	# lancer un nombre illimité de fusées avec le Parasite ». La gratuité datait
	# du chantier FUSÉE (`dccdaf6`, 2026-09-02), d'avant les classes : elle
	# servait à éprouver LA fusée. Depuis que chaque classe a sa propre économie,
	# elle masquait exactement ce qu'on vient tester à l'entraînement.
	#
	# Le reste du bac à sable garde sa gratuité, et ce n'est pas un oubli :
	# `sandbox_mode` couvre aussi l'hôte qui attend seul et le partage d'après-
	# match, deux chemins qui ne passent pas par `_do_start_round` et donc ne
	# réamorcent pas le compteur. Y compter ferait attendre une minute à zéro un
	# hôte qui aurait tiré sa fusée pendant le match précédent.
	if sandbox_mode and not training_mode:
		return _stock_fusees(p1 if pid == 0 else p2) > 0
	return _fusees_restantes[pid] > 0


## Le profil de fusées d'un joueur, ou `null` s'il n'en a pas encore.
func _profil_fusees(joueur: Node):
	if joueur == null:
		return null
	var classe := joueur.current_weapon as ClassData
	return classe.fusees if classe != null else null


## Ce avec quoi la classe d'un joueur commence la manche.
##
## ⚠️ **Zéro quand la classe n'en porte pas, jamais un repli à un.** Le Spectre
## est à zéro par conception ; un repli plausible lui rendrait la seule chose que
## sa classe lui retire.
func _stock_fusees(joueur: Node) -> int:
	var profil = _profil_fusees(joueur)
	return maxi(0, profil.stock) if profil != null else 0


## La réserve d'un joueur, pour le HUD. Lue par les deux pairs : le stock est
## répliqué à chaque changement.
func fusees_restantes(pid: int) -> int:
	if pid < 0 or pid >= _fusees_restantes.size():
		return 0
	return _fusees_restantes[pid]


## Secondes avant la prochaine fusée, ou -1 s'il n'y en aura pas.
##
## ⚠️ **Juste chez l'hôte seul**, l'accumulateur n'étant pas répliqué. Le client
## voit donc le compte changer sans le décompte qui l'annonce — un manque, pas un
## mensonge, et le prix d'un octet par tick économisé. À reprendre le jour où
## Adrien jugera l'attente illisible.
func attente_fusee(pid: int) -> float:
	if pid < 0 or pid >= _fusees_restantes.size():
		return -1.0
	var profil = _profil_fusees(p1 if pid == 0 else p2)
	if profil == null:
		return -1.0
	return profil.attente_restante(_fusees_restantes[pid], _fusees_accumulateur[pid])


## [Hôte] La réserve avance, et se resème si la classe a changé.
##
## ⚠️ **L'arithmétique est chez l'hôte, le RÉSULTAT est répliqué.** Le client ne
## recharge rien de lui-même : `FlareProfile.avancer()` explique pourquoi — deux
## accumulateurs locaux dérivent d'un demi-RTT à chaque consommation. Mais il a
## besoin du compte, sans quoi sa prédiction du désarmement se tromperait au
## premier lancer d'une fusée regagnée. Un paquet toutes les douze à dix-huit
## secondes, et seulement pour les deux classes qui rechargent.
func _accorder_fusees(delta: float) -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	for pid in 2:
		var joueur: Node = p1 if pid == 0 else p2
		var profil = _profil_fusees(joueur)
		if profil != _fusees_profil[pid]:
			# Changement de classe : on resème, y compris pendant le décompte.
			_fusees_profil[pid] = profil
			_annoncer_stock_fusees(pid, maxi(0, profil.stock) if profil != null else 0)
			_fusees_accumulateur[pid] = 0.0
			continue
		if profil == null or not profil.recharge_active():
			continue
		if not round_active and not sandbox_mode:
			continue
		var avance: Array = profil.avancer(_fusees_restantes[pid],
			_fusees_accumulateur[pid], delta)
		_fusees_accumulateur[pid] = float(avance[1])
		if int(avance[0]) != _fusees_restantes[pid]:
			_annoncer_stock_fusees(pid, int(avance[0]))


func _annoncer_stock_fusees(pid: int, stock: int) -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		rpc_stock_fusees.rpc(pid, stock)
	else:
		rpc_stock_fusees(pid, stock)


@rpc("authority", "call_local", "reliable")
func rpc_stock_fusees(pid: int, stock: int) -> void:
	if pid >= 0 and pid < _fusees_restantes.size():
		_fusees_restantes[pid] = maxi(0, stock)

func spawn_fusee(shooter: Node2D, pos: Vector2, rot: float):
	if not round_active and not sandbox_mode: return
	# Le client ne demande rien : son appui voyage déjà dans sa commande
	# numérotée, et l'hôte détecte le front en simulant P2. Le désarmement,
	# lui, est prédit localement par player.gd — comme le cooldown de tir.
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	if not fusee_disponible(shooter.player_id): return
	var graine := randi()
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		rpc_spawn_fusee.rpc(shooter.player_id, pos, rot, graine)
	else:
		_do_spawn_fusee(shooter.player_id, pos, rot, graine)

# FU2.1 : plus aucune cible pré-calculée — la fusée REBONDIT sur les murs
# (décision d'Adrien au premier essai, elle les survolait). Le vol se simule
# localement chez les deux pairs, à l'identique : mêmes murs, mêmes pas de
# physique — le patron des ricochets de bullet.gd.
@rpc("authority", "call_local", "reliable")
func rpc_spawn_fusee(shooter_id: int, pos: Vector2, rot: float, graine: int):
	_do_spawn_fusee(shooter_id, pos, rot, graine)

func _do_spawn_fusee(shooter_id: int, pos: Vector2, rot: float, graine: int):
	if not round_active and not sandbox_mode: return
	if (not sandbox_mode or training_mode) and shooter_id >= 0 and shooter_id < _fusees_restantes.size():
		_fusees_restantes[shooter_id] = maxi(0, _fusees_restantes[shooter_id] - 1)
	var f := Fusee.new()
	# Nom explicite ET unique : la graine, partagée par le RPC, l'est aussi —
	# deux fusées en bac à sable ne se disputent jamais un nom auto-généré.
	f.name = "FuseeJ%d_%d" % [shooter_id + 1, graine]
	f.depart = pos
	f.direction = Vector2(cos(rot), sin(rot))
	f.graine = graine
	f.shooter_id = shooter_id
	f.joueurs = [p1, p2]
	bullet_container.add_child(f)

# ---------------------------------------------------------------------------
# LES GADGETS DE CLASSE — chantier CLASSES, étape 10
#
# Même autorité que la fusée, et pour la même raison : le bit de pose voyage
# dans la commande numérotée, l'hôte en détecte le front en simulant P2, et
# c'est lui qui spawne pour tout le monde. **Aucune prédiction client** — un
# objet posé, immobile, à une charge par manche, tolère un demi-RTT ; le tir
# non.
#
# ⚠️ **La POSITION FINALE voyage dans le RPC, elle ne se recalcule pas.** Le
# gadget se plante devant le poseur, et « devant » peut tomber dans un mur : la
# rectification demande une requête de physique, donc l'état de la carte, donc
# deux mondes qui pourraient répondre différemment. L'hôte tranche une fois et
# envoie le point. C'est plus court que le raisonnement qui justifierait de
# refaire le calcul des deux côtés, et ça ne peut pas diverger.
# ---------------------------------------------------------------------------

## Gadgets déjà posés par joueur dans la manche en cours.
##
## ⚠️ **On compte les poses, on ne décompte pas un stock — et la nuance a une
## cause précise.** Un « restant » se sème à l'ouverture de la manche ; or la
## fenêtre de choix d'un match apparié s'ouvre AVEC le décompte, donc *après*
## `_do_start_round`, et `pick_countdown_weapon()` change l'arme équipée pendant
## ces dix secondes. Un stock semé avant le choix aurait donné à qui change de
## classe le stock de la classe qu'il vient de quitter — sans erreur, et
## invisible tant que les deux classes en ont autant.
##
## En comptant les poses, le plafond se relit à chaque appui sur la classe
## RÉELLEMENT équipée. Il n'y a plus rien à resemer.
var _gadgets_poses_par: Array[int] = [0, 0]

## Les secondes avant que chaque joueur puisse reposer son gadget — décision
## d'Adrien du 2026-09-10 : une minute de recharge, pour TOUS les gadgets.
##
## ⚠️ **Un minuteur et non un compteur**, et le compteur ci-dessus reste : il dit
## combien de gadgets ont été posés, pas combien il en reste. La disponibilité se
## lit ici.
##
## Posé dans `_do_spawn_gadget`, qui tourne chez les DEUX pairs : chacun démarre
## son minuteur à la pose qu'il voit, le client un demi-aller-retour après l'hôte.
## L'écart joue dans le sens prudent — le client ne prédit jamais une pose que
## l'hôte refuserait.
var _gadget_attente: Array[float] = [0.0, 0.0]

## La batterie du grésillement, par joueur, de 0 à 1. Elle appartient au JOUEUR :
## une bobine détruite ne la vide pas, une bobine reposée la retrouve.
var _batterie: Array[float] = [1.0, 1.0]

const PERIODE_RECHARGE_GADGET := 60.0

## Compteur de poses, pour donner un nom UNIQUE à chaque nœud.
##
## ⚠️ Ce n'est pas du rangement : un RPC de scène se route par le chemin du nœud,
## et un nom auto-généré diverge entre machines — les RPC sont alors jetés sans
## aucune erreur console. Le compteur voyage dans le RPC, comme la graine de la
## fusée, pour que les deux pairs nomment le même objet pareil.
var _gadgets_poses: int = 0


## Le stock de gadgets que la classe d'un joueur lui donne, 0 si elle n'en a pas
## ou si son gadget n'est pas encore écrit.
func _stock_gadget(joueur: Node) -> int:
	if joueur == null:
		return 0
	var classe := joueur.current_weapon as ClassData
	if classe == null or classe.gadget == null or not classe.gadget.est_livre():
		return 0
	return maxi(0, classe.gadget.stock)


## Ce joueur peut-il poser un gadget maintenant ?
##
## ⚠️ **Plus illimité à l'entraînement, depuis le 2026-09-10.** « L'entraînement
## sert à éprouver un geste » était vrai d'un gadget par manche ; avec une recharge
## d'une minute, c'est le RYTHME qu'on vient éprouver, et le rendre gratuit l'aurait
## caché — la leçon exacte des fusées, payée le même jour. Le reste du bac à sable
## (l'hôte qui attend seul, le partage d'après-match) garde sa gratuité : ces deux
## chemins ne réamorcent pas le minuteur.
func gadget_disponible(pid: int) -> bool:
	if pid < 0 or pid >= _gadgets_poses_par.size():
		return false
	var stock := _stock_gadget(p1 if pid == 0 else p2)
	if stock <= 0:
		return false
	if sandbox_mode and not training_mode:
		return true
	return _gadget_attente[pid] <= 0.0


## [Hôte] Le joueur pose son gadget. Le client ne demande rien : son appui est
## déjà dans sa commande numérotée.
func spawn_gadget(poseur: Node2D, pos: Vector2, rot: float) -> void:
	if not round_active and not sandbox_mode:
		return
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	var pid: int = poseur.player_id
	if not gadget_disponible(pid):
		return
	var classe := poseur.current_weapon as ClassData
	if classe == null or classe.gadget == null or not classe.gadget.est_livre():
		return

	_gadgets_poses += 1
	var point := _point_de_pose(pos, rot)
	# La graine de ce qui est aléatoire dans le gadget — l'onde du grésillement.
	# Tirée ICI, chez l'hôte, et portée par le RPC : deux pairs qui tireraient
	# chacun la leur verraient deux pannes différentes.
	var graine := randi()
	var actif_initial := _batterie[pid] >= GadgetGresillement.SEUIL_RALLUMAGE
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		rpc_spawn_gadget.rpc(pid, point, rot, classe.gadget.slug, _gadgets_poses, graine,
			actif_initial, _batterie[pid])
	else:
		_do_spawn_gadget(pid, point, rot, classe.gadget.slug, _gadgets_poses, graine,
			actif_initial, _batterie[pid])


## Où le gadget se plante réellement : devant le poseur, ramené en deçà du
## premier mur rencontré.
##
## Sans cette rectification, un joueur dos au mur planterait son gadget DANS la
## pierre : le nœud existerait, son occluder aussi, et rien à l'écran ne dirait
## pourquoi la manche vient de consommer une charge sans rien produire.
func _point_de_pose(depuis: Vector2, rot: float) -> Vector2:
	var direction := Vector2(cos(rot), sin(rot))
	var cible := depuis + direction * GadgetBase.PORTEE_POSE
	# ⚠️ `p1.get_world_2d()` et non `get_world_2d()` : `GameState` étend `Node`,
	# il n'a pas de monde 2D à lui. C'est la forme que les deux autres requêtes de
	# ce fichier emploient déjà.
	if p1 == null:
		return cible
	var espace := p1.get_world_2d().direct_space_state
	if espace == null:
		return cible
	var requete := PhysicsRayQueryParameters2D.create(depuis, cible)
	requete.collision_mask = MapGeometry.WALL_LAYER
	requete.collide_with_areas = false
	var touche := espace.intersect_ray(requete)
	if touche.is_empty():
		return cible
	# Une marge, sinon le gadget naît exactement sur la surface et son occluder
	# se confond avec celui du mur.
	return Vector2(touche["position"]) - direction * 6.0


## [Hôte] Les gadgets qui demandent à s'allumer — la mine, aujourd'hui seule.
##
## ⚠️ **La boucle est chez l'hôte et nulle part ailleurs.** Un gadget qui
## déciderait lui-même s'allumerait deux fois, une chez chaque pair, à deux
## instants différents — et l'éblouissement, calculé par l'hôte, ne
## correspondrait alors plus à ce que le client voit brûler.
func _maj_gadgets(delta: float) -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	if not round_active and not sandbox_mode:
		return
	var joueurs := [p1, p2]
	for g in get_tree().get_nodes_in_group("gadgets"):
		if not is_instance_valid(g) or g.is_queued_for_deletion():
			continue
		if g.veut_s_allumer(joueurs):
			allumer_gadget(g)
		# ⚠️ **Les effets aussi passent par l'hôte**, et pas seulement
		# l'allumage : une nappe de braises qui brûlerait de son côté chez le
		# client ferait descendre sa barre deux fois plus vite que l'arbitrage.
		g.appliquer_effets(joueurs, delta)


## [Hôte] Ordonne l'allumage d'un gadget, chez les deux pairs.
##
## ⚠️ **Le nom du nœud est la clé, et c'est pour ça qu'il est explicite.** Un RPC
## de scène se route par le chemin du nœud ; ici c'est le nom lui-même qui
## voyage, et il ne désigne le même objet des deux côtés que parce que
## `_do_spawn_gadget()` le construit à partir de données répliquées — le joueur
## et un compteur — au lieu de le laisser à Godot.
func allumer_gadget(g: Node) -> void:
	if g == null or not is_instance_valid(g):
		return
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		rpc_allumer_gadget.rpc(String(g.name))
	else:
		g.allumer()


@rpc("authority", "call_local", "reliable")
func rpc_allumer_gadget(nom: String) -> void:
	var g := bullet_container.get_node_or_null(NodePath(nom))
	if g != null and g.has_method("allumer"):
		g.allumer()


@rpc("authority", "call_local", "reliable")
func rpc_spawn_gadget(pid: int, pos: Vector2, rot: float, slug: String, numero: int,
		graine: int, actif_initial: bool, batterie_poseur: float) -> void:
	_do_spawn_gadget(pid, pos, rot, slug, numero, graine, actif_initial, batterie_poseur)


## Le gadget de ce joueur qui s'allume et s'éteint, s'il en a un debout — ou null.
func gadget_basculable_de(pid: int) -> Node:
	for g in get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion() \
				and g.poseur_id == pid and g.has_method("est_basculable") \
				and g.est_basculable():
			return g
	return null


## La batterie d'un joueur, pour le HUD, de 0 à 1.
func batterie(pid: int) -> float:
	return _batterie[pid] if pid >= 0 and pid < _batterie.size() else 0.0


## Les secondes avant que ce joueur puisse reposer son gadget, pour le HUD.
func attente_gadget(pid: int) -> float:
	return _gadget_attente[pid] if pid >= 0 and pid < _gadget_attente.size() else 0.0


## [Hôte] Le poseur appuie sur sa touche alors que son gadget basculable est
## debout : on l'allume ou on l'éteint.
##
## Aucune prédiction client : l'appui voyage déjà dans la commande numérotée,
## l'hôte le relit en simulant ce joueur, et c'est lui qui ordonne — comme pour la
## pose. Un client qui basculerait de lui-même le ferait un demi-aller-retour trop
## tôt, et se ferait contredire par l'ordre de l'hôte.
func basculer_gadget(joueur: Node2D) -> void:
	if not round_active and not sandbox_mode:
		return
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	var pid: int = joueur.player_id
	var g = gadget_basculable_de(pid)
	if g == null:
		return
	var allume: bool = not bool(g.get("actif"))
	if allume and _batterie[pid] < GadgetGresillement.SEUIL_RALLUMAGE:
		return
	_annoncer_etat_gadget(pid, String(g.name), allume)


func _annoncer_etat_gadget(pid: int, nom: String, actif: bool) -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		rpc_etat_gadget.rpc(pid, nom, actif, _batterie[pid])
	else:
		rpc_etat_gadget(pid, nom, actif, _batterie[pid])


## L'état d'un gadget basculable, et la batterie de son poseur, chez les deux pairs.
##
## ⚠️ **Deux volets, et le premier s'applique toujours.** La batterie est un état
## du JOUEUR : elle se recopie même si la bobine n'existe plus chez ce pair —
## détruite localement par une balle, puisque la destruction ne voyage pas. Sans
## cette séparation, le HUD du client resterait figé sur une batterie périmée.
## L'allumage, lui, ne s'applique qu'à un nœud qui existe encore.
@rpc("authority", "call_local", "reliable")
func rpc_etat_gadget(pid: int, nom: String, actif: bool, batterie_joueur: float) -> void:
	if pid >= 0 and pid < _batterie.size():
		_batterie[pid] = clampf(batterie_joueur, 0.0, 1.0)
	var g := bullet_container.get_node_or_null(NodePath(nom))
	if g != null and "actif" in g:
		g.set("actif", actif)


## [Hôte] Un gadget vient de mourir chez l'hôte — balle ou fin de vie : on le dit
## au client, qui ne détruit plus rien de lui-même.
##
## ⚠️ **La destruction ne voyageait pas.** Chaque pair détruisait ses gadgets avec
## ses propres balles, à des instants que la prédiction décalait : une bobine
## pouvait mourir chez l'hôte et survivre chez le client, qui voyait alors
## éteintes des torches que l'hôte laissait éblouir. Trouvé par la revue du
## 2026-09-10 — et c'était vrai de tous les gadgets, pas du seul grésillement.
func _sur_gadget_detruit(g: GadgetBase) -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
		return
	rpc_detruire_gadget.rpc(String(g.name))


## L'ordre de retrait d'un gadget, chez le client. `get_node_or_null` et jamais un
## accès direct : le nœud a pu disparaître de lui-même chez ce pair — fin de vie,
## remplacement par « un gadget debout », purge de manche.
@rpc("authority", "call_remote", "reliable")
func rpc_detruire_gadget(nom: String) -> void:
	var g := bullet_container.get_node_or_null(NodePath(nom))
	if g != null and not g.is_queued_for_deletion():
		g.queue_free()


## Les réserves de gadget, à chaque image, chez les DEUX pairs : le minuteur de
## pose descend, la batterie se vide allumée et se remplit éteinte.
##
## ⚠️ **Le client intègre, mais ne DÉCIDE rien.** Il fait avancer ses deux compteurs
## pour que son HUD vive entre deux ordres de l'hôte, qui les recale en valeur
## absolue à chaque bascule. L'extinction à batterie vide se décide chez l'hôte
## seul : un client qui la déciderait un demi-aller-retour plus tôt éteindrait
## une bobine que l'hôte tient encore allumée.
func _maj_reserves_gadgets(delta: float) -> void:
	if not round_active and not sandbox_mode:
		return
	for pid in 2:
		if _gadget_attente[pid] > 0.0:
			_gadget_attente[pid] = maxf(0.0, _gadget_attente[pid] - delta)
		var g = gadget_basculable_de(pid)
		var allume: bool = g != null and bool(g.get("actif"))
		if allume:
			_batterie[pid] = maxf(0.0, _batterie[pid] - delta / GadgetGresillement.DUREE_ACTIVE_MAX)
		else:
			_batterie[pid] = minf(1.0, _batterie[pid] + delta / GadgetGresillement.RECHARGE_BATTERIE)
		if allume and _batterie[pid] <= 0.0 \
				and NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
			_annoncer_etat_gadget(pid, String(g.name), false)


func _do_spawn_gadget(pid: int, pos: Vector2, rot: float, slug: String, numero: int,
		graine: int = 0, actif_initial: bool = true, batterie_poseur: float = -1.0) -> void:
	if not round_active and not sandbox_mode:
		return
	var fiche: Dictionary = IMPLEMENTATIONS.get(slug, {})
	var chemin := String(fiche.get("script", ""))
	if chemin.is_empty():
		# ⚠️ On CRIE, on ne se rabat pas. Poser un gadget générique à la place
		# d'un gadget inconnu donnerait un objet plausible — et un objet plausible
		# se prend pour une intention.
		push_error("GameState : gadget « %s » sans implémentation" % slug)
		return
	var script: GDScript = load(chemin)
	if script == null:
		push_error("GameState : implémentation illisible — %s" % chemin)
		return
	var g: GadgetBase = script.new()
	g.name = "GadgetJ%d_%d" % [pid + 1, numero]
	g.poseur_id = pid
	g.global_position = pos
	# `angle_pose` est posé par le constructeur de la sous-classe : on lit donc
	# l'objet, on ne redit pas ici ce qu'il sait déjà de lui-même.
	g.rotation = rot + g.angle_pose
	var classe := (p1 if pid == 0 else p2).current_weapon as ClassData
	if classe != null and classe.gadget != null:
		# Le drapeau d'éblouissement et la durée de vie viennent du PROFIL, par
		# instance — décision d'Adrien du 2026-09-09 : on doit pouvoir éteindre
		# l'éblouissement d'un gadget sans toucher aux autres.
		g.eblouit = classe.gadget.eblouit
		g.duree_vie = classe.gadget.duree_vie
		# La classe elle-même, pour les gadgets qui portent SA lumière — la
		# torche fantôme emprunte le cookie du Braconnier, et c'est tout ce qui
		# fait d'elle un mensonge plutôt qu'une lampe.
		g.classe_du_poseur = classe
	# ⚠️ **Un gadget debout par joueur.** Avec une recharge d'une minute, un gadget
	# sans durée de vie — le voile, l'ombre, la mine, la POUDRE, la bobine —
	# s'accumulerait à raison d'un par minute et finirait par fermer la carte.
	# Reposer DÉPLACE donc le précédent au lieu de l'ajouter : on garde l'empreinte
	# d'avant, un objet par joueur, avec le droit de le déplacer. Proposé en codant,
	# puis TRANCHÉ par Adrien le 2026-09-10 — deux fois, parce que la première
	# question oubliait la poudre de la Sentinelle, faite pour veiller un passage
	# toute la manche : même règle pour tous. Sans effet sur les gadgets qui durent
	# moins d'une minute.
	for ancien in get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(ancien) and ancien.poseur_id == pid:
			ancien.queue_free()
	if "graine" in g:
		g.set("graine", graine)
	# L'état initial et la batterie viennent de l'HÔTE, portés par le RPC. Relus
	# chez chaque pair, ils pouvaient différer — la batterie intégrée localement
	# dérive d'un demi-aller-retour — et la bobine naissait allumée chez l'un,
	# éteinte chez l'autre, sans rien pour les réaligner. Revue du 2026-09-10.
	if batterie_poseur >= 0.0 and pid >= 0 and pid < _batterie.size():
		_batterie[pid] = batterie_poseur
	if g.est_basculable():
		# Posée ALLUMÉE si la batterie le permet : la pose est le premier allumage.
		g.set("actif", actif_initial)
	# L'hôte dira au client chaque mort de ce gadget — balle ou fin de vie.
	g.detruit.connect(_sur_gadget_detruit)
	# Le même conteneur que les balles et les fusées : c'est lui que la manche
	# purge, et le rejoindre suffit donc à ne pas survivre à la manche.
	bullet_container.add_child(g)
	if pid >= 0 and pid < _gadgets_poses_par.size():
		_gadgets_poses_par[pid] += 1
		_gadget_attente[pid] = PERIODE_RECHARGE_GADGET
		# ⚠️ Chez le CLIENT, une recharge RACCOURCIE d'un aller-retour. Il reçoit la
		# pose un demi-aller-retour après l'hôte, et sa prochaine commande mettra un
		# demi-aller-retour de plus à arriver : pour que les deux pairs jugent le
		# même appui de la même façon, il doit tenir le gadget pour prêt un
		# aller-retour AVANT l'hôte. Sans ça, l'hôte acceptait une pose que le client
		# n'avait pas prédite, et le désarmement manquait à sa prédiction.
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
			_gadget_attente[pid] = maxf(0.0,
				PERIODE_RECHARGE_GADGET - NetworkManager.rtt_ms / 1000.0)


## La killcam reconstruit les fusées depuis les instantanés — un événement de
## lancer ne suffirait pas : la fusée vit ~20 s, le tampon de rejeu 7,5.
func _maj_fusees_killcam(snap) -> void:
	# Les fusées vivantes se taisent pendant le rejeu : l'état visible vient
	# des instantanés, pas du présent.
	for c in bullet_container.get_children():
		if c is Fusee and not c.is_replay:
			c.queue_free()
	var vus: Dictionary = {}
	for d in snap.fusees:
		var cle: int = d["graine"]
		vus[cle] = true
		var f: Fusee = _fusees_killcam.get(cle)
		if f == null or not is_instance_valid(f):
			f = Fusee.new()
			f.is_replay = true
			f.name = "FuseeKillcam_%d" % cle
			f.depart = d["pos"]
			f.graine = cle
			f.shooter_id = d["shooter"]
			f.joueurs = [ghost_p1, ghost_p2]
			bullet_container.add_child(f)
			_fusees_killcam[cle] = f
		# Le vol rebondit : sa position ne se dérive pas de l'âge, elle voyage
		# dans l'instantané — l'âge, lui, reconstruit lumière et fumée.
		f.global_position = d["pos"]
		f.appliquer_age(d["age"])
	for cle in _fusees_killcam.keys():
		if not vus.has(cle):
			var f = _fusees_killcam[cle]
			if is_instance_valid(f):
				f.queue_free()
			_fusees_killcam.erase(cle)

func _purger_fusees_killcam() -> void:
	for f in _fusees_killcam.values():
		if is_instance_valid(f):
			f.queue_free()
	_fusees_killcam.clear()

## FU5 — éteindre une fusée passe par le MÊME arbitrage que son lancer :
## l'hôte tranche, le client demande. Deux appelants : le piétinement
## (`_maj_extinction_fusees`, hôte seul — SANS ce détour, chaque machine
## déciderait de son propre chronomètre d'immobilité, avec l'écart
## d'interpolation de l'adversaire entre les deux, et les deux écrans
## diraient une fusée éteinte à des instants différents) ; et une balle qui
## touche une fusée posée (`bullet.gd`, tous pairs — leur propre simulation
## déterministe suffirait en principe, mais un seul chemin d'arbitrage pour un
## même état répliqué évite deux logiques à maintenir en accord).
func demander_extinction_fusee(graine: int) -> void:
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_CLIENT:
			return # la balle du client est une prédiction ; l'officielle, côté hôte, redemandera
		NetworkManager.GameMode.ONLINE_HOST:
			rpc_eteindre_fusee.rpc(graine)
		_:
			_do_eteindre_fusee(graine)

@rpc("authority", "call_local", "reliable")
func rpc_eteindre_fusee(graine: int) -> void:
	_do_eteindre_fusee(graine)

func _do_eteindre_fusee(graine: int) -> void:
	for c in bullet_container.get_children():
		if c is Fusee and c.graine == graine and not c.is_replay:
			c.eteindre()

## FU5 — piétiner une fusée POSÉE l'éteint : 0,7 s immobile dessus. HÔTE SEUL :
## contrairement aux dégâts (où le SHOOTER doit être compensé pour la latence
## de sa PROPRE vue de l'adversaire), ici il n'y a pas de perspective à
## compenser — l'hôte simule déjà les DEUX joueurs en direct depuis leurs
## commandes, sans délai à rattraper. Ce qu'il faut éviter, c'est l'INVERSE :
## si chaque machine décidait seule, le client jugerait son propre piétinement
## à travers le délai d'interpolation de l'AUTRE joueur (100 ms, voir
## `Player.NetRole.INTERPOLATED`) — deux écrans pourraient alors éteindre la
## fusée à des instants différents. Un seul juge, comme partout ailleurs dans
## ce fichier (`_maj_eblouissement`, `_flash_de_tir`) : l'hôte tranche, le
## résultat se réplique via `demander_extinction_fusee`.
func _maj_extinction_fusees(delta: float) -> void:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		return
	for i in 2:
		var joueur: Player = p1 if i == 0 else p2
		if joueur.dead:
			_pietinement_temps[i] = 0.0
			_pietinement_fusee[i] = null
			continue
		var sous: Fusee = null
		for c in bullet_container.get_children():
			if c is Fusee and not c.is_replay and c.est_allumee_au_sol() \
					and joueur.global_position.distance_to(c.global_position) \
						<= FuseeModele.EXTINCTION_RAYON:
				sous = c
				break
		if sous == null:
			_pietinement_temps[i] = 0.0
			_pietinement_fusee[i] = null
			continue
		if sous != _pietinement_fusee[i]:
			# On vient d'arriver sur cette fusée (ou sur une autre) : le
			# chronomètre repart, et la position de référence aussi.
			_pietinement_fusee[i] = sous
			_pietinement_temps[i] = 0.0
			_pietinement_pos[i] = joueur.global_position
			continue
		var vitesse := joueur.global_position.distance_to(_pietinement_pos[i]) / delta
		_pietinement_pos[i] = joueur.global_position
		if vitesse > FuseeModele.EXTINCTION_VITESSE_MAX:
			_pietinement_temps[i] = 0.0
			continue
		_pietinement_temps[i] += delta
		if _pietinement_temps[i] >= FuseeModele.EXTINCTION_PIETINEMENT:
			demander_extinction_fusee(sous.graine)
			_pietinement_temps[i] = 0.0
			_pietinement_fusee[i] = null

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bullet(shooter_id: int, pos: Vector2, rot: float, weapon_idx: int):
	var shooter = p1 if shooter_id == 0 else p2
	var weapon := weapon_for_index(weapon_idx)
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

	# Éjection de douille d'atelier persistante au sol (DA Roman Graphique Brutaliste)
	if weapon and weapon.slug() != "arbalete" and arena:
		var shoot_dir := Vector2(cos(rot), sin(rot))
		BulletCasingScript.eject(arena, pos, shoot_dir, weapon.slug())

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

	# FU3 — un tir parti DE L'INTÉRIEUR d'une fumée fait pulser tout le nuage,
	# pour diluer la position du tireur. Même site que le flash de tir : une
	# fois par volée, jamais pour un tir déjà rendu, jamais en killcam. Chaque
	# machine décide localement, depuis sa propre simulation de la fusée — la
	# même confiance que le reste de FU1-FU2 lui accorde déjà.
	for f in bullet_container.get_children():
		if f is Fusee and not f.is_replay and f.occultation_pour(pos) > 0.0:
			f.diffuser_flash()

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

## DA4.6 — le relevé balistique de la killcam, ou `null` s'il n'y a rien à
## relever.
var _releve: ReleveBalistique = null

## Arme le relevé sur la trajectoire fatale, avant que la lecture commence.
##
## ⚠️ **Rien quand la trajectoire est vide, et c'est voulu.** Mort par chrono, tir
## sorti de la fenêtre d'enregistrement, impact inconnu : `trajectoire_fatale()`
## rend un tableau vide *plutôt qu'approximatif*, et un relevé faux enseignerait
## une leçon fausse — pire que de ne rien enseigner. Le pré-tracé de
## `ReplaySystem` a lieu quand même : il suspend l'action une demi-seconde, sans
## rien dessiner. Le supprimer dans ce cas ferait deux rythmes de killcam selon
## la façon dont on est mort.
func _armer_le_releve() -> void:
	_liberer_le_releve()
	var d := ReplaySystem.releve_du_tir_fatal()
	if d.is_empty():
		return

	# ⚠️ **La part de dégâts de bord se calcule ICI**, et pas dans le relevé :
	# `releve_balistique.gd` n'a aucune raison de connaître `WeaponData`, et le
	# jour où la chute de dégâts changera, elle changera dans `bullet.gd` et dans
	# cette ligne — pas dans un fichier de dessin.
	var arme: WeaponData = d["arme"]
	var nom := ""
	var part_bord := 0.5
	if arme != null:
		nom = arme.name
		if arme.damage_center > 0.0:
			part_bord = arme.damage_edge / arme.damage_center

	_releve = ReleveBalistique.new()
	_releve.name = "ReleveBalistique"
	arena.add_child(_releve)
	if not _releve.poser(d["origine"], d["cible"], d["angle"], nom, part_bord):
		_liberer_le_releve()


func _liberer_le_releve() -> void:
	if is_instance_valid(_releve):
		_releve.queue_free()
	_releve = null


## Fait avancer le pré-tracé, puis le laisse en arrière-plan pendant l'action.
##
## ⚠️ **Trois branches, pas deux.** AVANT le pré-tracé, le relevé ne doit rien
## montrer : la killcam s'ouvre trois secondes avant le tir fatal, et une ligne
## posée dès la première image annoncerait la trajectoire pendant tout le
## contexte, puis se redessinerait par-dessus elle-même au moment prévu. C'est
## exactement ce qu'un `else` produisait — voir `ReplaySystem.Pretrace`.
func _suivre_le_releve() -> void:
	if not is_instance_valid(_releve):
		return
	match ReplaySystem.pretrace_etat():
		ReplaySystem.Pretrace.PENDANT:
			_releve.avancer(ReplaySystem.pretrace_t)
		ReplaySystem.Pretrace.APRES:
			_releve.passer_derriere()
		_:
			# AVANT : rien. Le relevé existe, armé, et reste invisible.
			_releve.avancer(0.0)


func _on_replay_spawn_bullet(shooter_id: int, pos: Vector2, rot: float,
		weapon: WeaponData, fatal: bool = false):
	var b = bullet_scene.instantiate()
	b.is_replay = true
	# DA4.6 — seul le tir fatal laisse sa traînée. Les tirs manqués gardent leur
	# lumière et leur traçante, mais plus de pointillé : deux traits presque
	# parallèles font croire qu'on lit le bon.
	b.est_le_tir_fatal = fatal
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
	# PE2.1 — la manche est jouée : le relevé s'arrête AVANT le ralenti de la
	# killcam, qui n'est pas une saccade.
	_conditions.arreter()

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
	# V5.10 — la salle se tait avec la manche. Elle vit dans un Timer de
	# l'autoload, qui survit a l'arene : sans cet arret, des ponctuels
	# continueraient de tomber aux coordonnees d'une carte qui n'existe plus,
	# par-dessus la killcam et le menu.
	AudioManager.arreter_ambiance()
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
		_armer_le_releve()
		ReplaySystem.start_playback()
		
		# Wait for replay to finish or be skipped
		while ReplaySystem.playing_back:
			await get_tree().process_frame
			if token != _round_token: return

		# Le ralenti est global : quelle que soit la façon dont la lecture s'est
		# arrêtée, la vitesse normale doit être rétablie ici.
		Engine.time_scale = 1.0
		_liberer_le_releve()

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
	# DA4.7 — la marge n'est passée QU'ICI, à la fin du match.
	#
	# L'appel d'entre-deux-manches (plus haut) la laisse à `-1` volontairement :
	# l'arène vient d'écrire « à N px du centre » au-dessus du corps, et la
	# répéter trois secondes plus tard dans le bandeau ferait dire deux fois la
	# même chose au même moment. À la fin du match, la scène est effacée et le
	# joueur choisit s'il rejoue — c'est là que le chiffre travaille.
	ui.poser_bilan(p1_session_wins, p2_session_wins, _mot_de_serie,
		dernier_effleurement)
	# DA6.1 — l'affiche, par-dessus le salon que ces deux lignes viennent de
	# poser. Elle LIT le verdict sur le titre du menu plutôt que de le
	# recalculer : le mot dépend du mode et d'un arbitrage sur l'égalité, et deux
	# calculs finiraient par se contredire à l'écran. Voir `affiche_de_fin.gd`.
	_poser_affiche_de_fin(winner_id)
	_apply_deferred_rematch()

# ---------------------------------------------------------------------------
# V6.10 A ÉTÉ ÉCRITE DEUX FOIS, ET ADRIEN A TRANCHÉ LE 2026-09-09
#
# Deux sessions ont lu la même fiche le même jour, sur deux branches, et l'ont
# livrée deux fois : une LIGNE de texte sur l'écran de fin
# (`SerieDeSession.carte_soiree()`, comptée sur le score de session en mémoire)
# et une CARTE au retour au menu (`BilanDeSoiree`, comptée sur
# `match_history.json`). C'est la deuxième fois que ce motif se produit ici —
# V6.2, le 2026-08-18. Détail et leçon aux « Pièges connus ».
#
# **La carte l'emporte, parce qu'elle couvre aussi DA6.3 et DA6.4** : illustrée
# et exportable en image, ce qu'une ligne de texte ne peut pas être. La ligne est
# retirée d'ici, de `serie_de_session.gd` et de sa suite. Ce qui disparaît avec
# elle : `session_ties` et `_session_weapons`, qui ne servaient qu'à la nourrir —
# le décompte des égalités et des armes vit désormais dans `BilanDeSoiree`, lu
# depuis le journal des matchs.
#
# ⚠️ **Il reste une moitié dans `ui.gd`** : le paramètre `carte_soiree` de
# `poser_bilan()` et le label `bilan_soiree` qu'il alimentait. Plus personne ne
# les nourrit, le paramètre a un défaut vide, rien ne s'affiche. **Signalé et non
# retiré : `ui.gd` appartient à la session « menus »**, et sept mille lignes ne
# se touchent pas pour retirer trois des siennes.
# ---------------------------------------------------------------------------

## DA6.1 — les faits du match qui vient de finir, tels que l'affiche les montre.
##
## Rassemblés ici parce que `game_state` est le seul à tous les avoir : la carte
## vient de `MapData`, les armes des joueurs, la durée du chrono, le score de
## session et la série de cet objet, la marge du dernier coup de `V2.9`.
func _poser_affiche_de_fin(winner_id: int) -> void:
	var carte: Dictionary = MapData.get_selected()
	_affiche_de_fin = AfficheDeFin.poser(self, {
		"vainqueur": winner_id,
		"local_idx": _local_player_index(),
		"carte": String(carte.get("name", "")),
		"duree": round_time - time_left,
		"arme_j1": p1.current_weapon.name if is_instance_valid(p1) and p1.current_weapon else "",
		"arme_j2": p2.current_weapon.name if is_instance_valid(p2) and p2.current_weapon else "",
		"mode": _mode_label(),
		"session_j1": p1_session_wins,
		"session_j2": p2_session_wins,
		"serie": _mot_de_serie,
		"marge_px": dernier_effleurement,
	}, ui.game_over_title if "game_over_title" in ui else null)
	# L'affiche est opaque et avale ses propres clics, mais REJOUER vit
	# DESSOUS, dans le salon qu'elle recouvre — un joueur pressé la voit
	# disparaître (elle se congédie sur tout geste) et presse REJOUER dans la
	# foulée avant d'avoir rien lu. `set_launch_locked` grise le bouton pendant
	# que l'affiche vit ; `tree_exited` le relâche à sa disparition, quel que
	# soit le chemin de sortie (délai écoulé ou geste du joueur).
	ui.set_launch_locked(true)
	_affiche_de_fin.tree_exited.connect(_on_affiche_de_fin_partie)


## L'affiche de fin a quitté l'arbre — délai écoulé ou geste du joueur, peu
## importe lequel : une seule porte de sortie, `AfficheDeFin.congedier()`.
func _on_affiche_de_fin_partie() -> void:
	_affiche_de_fin = null
	ui.set_launch_locked(false)


## DA6.3 — la carte de fin de soirée, au retour au menu.
##
## Le seuil et le calcul sont dans `BilanDeSoiree` ; ce qui est décidé ici est le
## MOMENT. Pas pendant un match, pas après un forfait subi en pleine manche —
## au retour au menu, quand la soirée s'arrête vraiment.
##
## ⚠️ **Une seule fois par séance.** Le retour au menu arrive après chaque
## match : reposée à chaque fois, la carte deviendrait un écran de plus à
## congédier, et à la quatrième on ne la lirait plus.
func _peut_etre_la_soiree() -> void:
	if _soiree_montree:
		return
	var bilan := BilanDeSoiree.de_la_soiree(MatchRecord.load_history(),
		_local_player_index(), _debut_de_seance)
	if not bool(bilan.get("assez", false)):
		return
	_soiree_montree = true
	PanneauDeSoiree.poser(self, bilan)


## Archive le résultat du match dans user://. Fondation de l'envoi ELO à venir :
## chaque machine journalise le match qu'elle vient de jouer, y compris le
## client — il n'y a aucun échange réseau ici.
func _archive_match_result(winner_id: int, forfeit: bool = false) -> void:
	# Le match est résolu : plus rien à forfaire dessus.
	_forfeit_pending = false
	# Schéma 5 : les CONDITIONS de la manche — cadence par image, lien,
	# machine. Calculées une fois : l'archive locale et le rapport au serveur
	# (PE2.3) doivent porter le même relevé.
	var conditions := _conditions.resume()
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
		_local_outcome(winner_id),
		# Schéma 4 : QUELLE CLASSE, et pas seulement quelle arme. `arme_j1` porte
		# le nom de l'arme — « Pistolet silencieux » — qui ne désigne plus le
		# joueur depuis que dix classes se partagent dix armes.
		_slug_de_classe(p1),
		_slug_de_classe(p2),
		conditions)
	MatchRecord.append_to_history(record)
	# Le journal local d'abord, l'envoi ensuite : si le second échoue, le premier
	# garde la trace, et une étape ultérieure pourra rejouer ce qui manque.
	_report_to_ranking(winner_id, forfeit, conditions)

## Le slug de la classe d'un joueur, ou une chaîne vide.
##
## ⚠️ **Vide plutôt qu'un repli**, comme partout dans ce chantier : un journal qui
## inventerait « pistolet » pour un joueur sans classe fausserait la seule
## statistique que ces clés existent pour porter.
func _slug_de_classe(joueur: Node) -> String:
	if joueur == null:
		return ""
	var classe := joueur.current_weapon as ClassData
	return String(classe.slug()) if classe != null else ""


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
func _report_to_ranking(winner_id: int, forfeit: bool, conditions: Dictionary = {}) -> void:
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
		# PE2.3 (décision d'Adrien, 2026-09-10) — les conditions voyagent avec le
		# rapport des matchs EN LIGNE, amicaux et classés : le serveur les passe
		# au tamis et ne refuse jamais un rapport pour elles. L'écran scindé et
		# l'entraînement ne passent pas par ici, donc n'envoient rien.
		"conditions": conditions,
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

## V2.7 + DA6.2 — le tampon du kill, devenu une PHOTO.
##
## La composition (cadre, ligne de tête, légende, tampon) vit dans
## `estampe_de_kill.gd`. Ce qui reste ici est ce que `game_state` est seul à
## savoir : quand poser l'image, et avec quels faits.
func _spawn_kill_stamp(elapsed: float) -> void:
	_clear_kill_stamp()
	var carte: Dictionary = MapData.get_selected()
	_kill_stamp = EstampeDeKill.poser(self, {
		"temps": elapsed,
		"carte": String(carte.get("name", "")),
		# L'arme du VAINQUEUR : c'est elle qui a fait l'image.
		"arme": _arme_du_vainqueur(),
		"mode": _mode_label(),
	}, [ui.match_hud] if "match_hud" in ui else [])

## Le nom de l'arme qui vient de tuer. La victime est morte, le survivant est
## celui dont la lumière est encore allumée une demi-seconde plus tôt — mais on
## ne devine pas : `player_died` a déjà décidé du vainqueur, et `p1_round_wins`
## vient d'être incrémenté par `_do_end_round`. On lit donc les points de vie,
## seule information qui ne dépend d'aucun ordre d'appel.
func _arme_du_vainqueur() -> String:
	var vivant: Player = null
	if is_instance_valid(p1) and not p1.dead:
		vivant = p1
	elif is_instance_valid(p2) and not p2.dead:
		vivant = p2
	if vivant == null or vivant.current_weapon == null:
		return ""
	return String(vivant.current_weapon.name)

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
	_liberer_le_releve()
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

	# **Sauf pour un match apparié, qui n'a pas de porte PRÊT à attendre.** Là,
	# ce paquet redevient ce qu'il était : le signal de départ. Il est le premier
	# instant où l'hôte a à la fois un pair connecté — sans quoi `_start_round()`
	# repart en bac à sable — et l'arme que ce pair tient, sans quoi P2 jouerait
	# tout le match au pistolet.
	if _matchmade_start_pending:
		_matchmade_start_pending = false
		_lancer_match_apparie()

## Index de l'arme choisie par le joueur local pour P2 (client, ou écran partagé).
func _local_p2_weapon_idx() -> int:
	return ui.selected_weapon_index(1)

## Un index hors bornes ferait tomber l'hôte sur un paquet client malformé.
func _set_p2_weapon_button(idx: int) -> void:
	# ⚠️ **Par index de classe, plus par position dans `get_buttons()`.** L'ordre
	# d'un `ButtonGroup` est celui de l'INSCRIPTION des boutons : il coïncidait
	# avec les index d'armes tant que les quatre étaient créées dans l'ordre du
	# catalogue, et il n'a plus aucune raison de coïncider depuis que la liste
	# s'ordonne par rang. L'interface refuse d'elle-même un index qu'elle ne
	# propose pas — un index reçu du réseau n'est pas un droit.
	ui.set_weapon_selection(1, idx)

## Le joueur quitte la fenêtre de choix. Renoncer à choisir son arme, c'est
## renoncer au match : on annule l'appariement et la recherche, et on rentre au
## menu. Le pair, lui, verra une déconnexion ordinaire — il n'y a pas de « l'autre
## a renoncé » à lui montrer que le retour au menu ne dise déjà.
func _on_pick_window_cancelled() -> void:
	var appariement := get_node_or_null(^"/root/Matchmaker")
	if appariement != null and appariement.has_method("cancel"):
		appariement.cancel()
	_matchmade_round = false
	_matchmade_ranked = false
	_on_main_menu_requested()

## L'arme correspondant à un index de râtelier. Une seule table de résolution :
## la dupliquer ferait diverger le démarrage de manche et le changement d'arme
## pendant le décompte, et la divergence porterait sur ce que le joueur tient.
## ⚠️ **Ce `match` ne connaissait que 0 à 3, et sa branche par défaut rendait le
## PISTOLET.** Tant que l'arsenal comptait quatre armes, cette branche ne servait
## que de garde-fou. Depuis que la table rang → classe rend des index jusqu'à 9,
## elle serait devenue le chemin normal pour six classes sur dix : un Spectre
## aurait tiré avec la balistique du pistolet, porté son cookie et joué ses sons,
## **sans qu'une seule erreur ne se lève** — le jeu restant parfaitement jouable.
##
## La résolution passe donc par le catalogue, qui EST la table. Elle reste unique :
## `classe_pour_index()` lit le même tableau, et c'est cette fonction-ci qui garde
## le contrat historique — une `WeaponData`, jamais `null`.
##
## Le repli sur le pistolet est conservé pour un index hors bornes, et c'est
## délibéré : « rendre vide donnerait un joueur sans arme, ce qu'aucun appelant ne
## sait afficher et qu'aucune partie ne peut jouer ». Mais il CRIE désormais,
## parce qu'un index hors bornes n'est plus un cas de figure attendu.
func weapon_for_index(idx: int) -> WeaponData:
	if idx >= 0 and idx < _classes.size():
		return _classes[idx]
	push_error("GameState : index de classe hors bornes — %d (catalogue de %d)"
		% [idx, _classes.size()])
	return weapon_pistolet


## Le catalogue des dix classes — chantier CLASSES, étape 1.
##
## ## Les index NE BOUGENT PAS, et c'est tout l'objet de cette étape
##
## Les quatre premiers gardent exactement le sens qu'ils avaient : 0 pistolet,
## 1 fusil, 2 pompe, 3 arbalète. Les six neufs s'ajoutent à la suite, de 4 à 9.
## **Rien de ce qui circule aujourd'hui ne change de sens** — ni `RankLoadout`,
## ni les râteliers de l'interface, ni `rpc_spawn_bullet(..., weapon_idx)`.
## L'étape est délibérément INERTE : elle ajoute une structure, elle ne rebranche
## rien. Le jour où la table rang → classe entrera en vigueur, ce sera un lot à
## part, avec sa montée de version de protocole.
##
## ## Les chiffres des quatre existantes ne sont pas retouchés
##
## Leurs blocs impératifs plus haut sont la vérité, et ils portent des décisions
## actées — les temps de recharge du chantier MUNITIONS, les portées de torche
## arbitrées le 2026-08-24. Cette fonction ne fait que leur ATTACHER trois
## profils.
##
## ## L'écart de contenu, et son arbitrage
##
## Ce commentaire signalait un écart en attente : la spécification voulait un
## pistolet à 6 balles là où le jeu en avait 10, et il n'appartenait pas au code
## de trancher. **Adrien a tranché le 2026-09-09**, et sa décision porte plus
## loin que le pistolet :
##
##   • Le Parasite passe à 6 munitions ; l'Illusionniste à 4, et à 60/25 ;
##   • L'Occulteur tombe à 10-15 par balle — il tue par rafale, pas au coup ;
##   • Le Terrassier recharge **cartouche par cartouche** ;
##   • Et **toutes les cadences faibles doublent, sans dépasser 3 tirs/s**.
##
## ⚠️ Cette dernière règle porte sur les cadences FAIBLES, c'est-à-dire celles
## qui étaient sous 3 tirs/s — quatre classes. Les six autres y étaient déjà et
## ne bougent pas ; le Parasite en particulier garde sa « cadence doublée », qui
## est son identité de classe et non un réglage.
##
## ⚠️ **Conséquence à connaître : deux classes ont désormais un root plus long
## que leur cadence.** La Sentinelle tire toutes les 0,425 s pour un root de
## 0,50 s, l'Incendiaire toutes les 0,333 s pour 0,40 s. Qui garde la détente
## enfoncée y reste immobile en continu. C'est cohérent avec « tirer coûte sa
## mobilité » — mais c'est un effet de bord de deux décisions prises séparément,
## et il se signale plutôt qu'il ne se corrige tout seul.
func _batir_catalogue() -> void:
	# ── Les quatre existantes reçoivent leurs profils ────────────────────────
	weapon_pistolet.libelle = "Le Parasite"
	weapon_pistolet.description = "Il ne prend rien : il corrompt ce que l'autre reçoit. Cadence doublée, et un grésillement qui fait douter d'une lumière qui marche encore."
	weapon_pistolet.rang = 1
	weapon_pistolet.root = _root(0.10)
	weapon_pistolet.fusees = _fusees(1, PERIODE_RECHARGE_FUSEE)
	weapon_pistolet.gadget = _gadget("gresillement", "Le grésillement",
		"Une batterie qu'on allume et coupe : les torches proches sautent jusqu'au noir.")

	weapon_fusil.libelle = "L'Illusionniste"
	weapon_fusil.description = "Il fait croire à un corps qui n'est pas là. Le fusil est fin et net ; le leurre, lui, ne se distingue d'un joueur que trop tard."
	weapon_fusil.rang = 3
	weapon_fusil.root = _root(0.25)
	weapon_fusil.fusees = _fusees(1, PERIODE_RECHARGE_FUSEE)
	weapon_fusil.gadget = _gadget("leurre", "Le leurre inerte",
		"Un faux corps : même silhouette, même trou dans la lumière.")

	weapon_pompe.libelle = "Le Terrassier"
	weapon_pompe.description = "Il terrasse, et il lève la poussière. Le faisceau le plus large du jeu, et une zone où plus personne ne voit loin. Il recharge cartouche par cartouche, et tire dès la première."
	weapon_pompe.rang = 5
	weapon_pompe.root = _root(0.35)
	weapon_pompe.fusees = _fusees(3, 18.0)
	weapon_pompe.gadget = _gadget("poussiere", "La poussière",
		"Un nuage de poussière où plus personne ne voit loin.")

	weapon_arbalete.libelle = "Le Braconnier"
	weapon_arbalete.description = "Il chasse à l'arbalète parce qu'elle est silencieuse, et il appâte à la lampe. Sa fausse torche balaie comme une vraie — et aveugle comme une vraie."
	weapon_arbalete.rang = 4
	weapon_arbalete.root = _root(0.60)
	weapon_arbalete.fusees = _fusees(1, PERIODE_RECHARGE_FUSEE)
	weapon_arbalete.gadget = _gadget("torche_fantome", "La torche fantôme",
		"Une lampe sur trépied qui balaie comme un joueur qui cherche.", true)

	# ── Les six neuves ───────────────────────────────────────────────────────
	# ⚠️ Leurs assets n'existent pas encore : ni cookie de torche, ni sprite. Le
	# catalogue les déclare quand même, et `ClassData.assets_presents()` dit
	# lesquelles sont jouables. Rien ne les équipe tant que l'étape 3 n'a pas
	# rebranché la table — donc rien ne crie, et rien ne se tait non plus.
	var fumiste := _classe("fumiste", "Le Fumiste", 2, 30.0, 1.5)
	fumiste.name = "Pistolet lourd"
	fumiste.description = "Il travaille la fumée, et c'est aussi un imposteur. Un coup lourd, trois balles, et un rideau de suie où l'on voit qu'il y a quelqu'un sans voir qui."
	fumiste.cooldown = 0.3333  # 2,38 → 3,00 tirs/s (doublé, PLAFONNÉ)
	fumiste.max_ammo = 3
	fumiste.reload_time = 2.8
	fumiste.damage_center = 70.0
	fumiste.damage_edge = 45.0
	fumiste.muzzle_flash_intensity = 1.0  # ⚠️ plafonné à 1 par `pic_de_flash`
	fumiste.muzzle_flash_duration = 0.16
	fumiste.root = _root(0.30)
	fumiste.fusees = _fusees(1, PERIODE_RECHARGE_FUSEE)
	fumiste.gadget = _gadget("cartouche_suie", "La cartouche de suie",
		"Un rideau de suie : on voit qu'il y a quelqu'un, pas qui.")

	var incendiaire := _classe("incendiaire", "L'Incendiaire", 6, 40.0, 1.4)
	incendiaire.name = "Fusil de détresse"
	incendiaire.description = "Le feu au rang du feu. Deux cartouches paraboliques, deux fusées incendiaires, et un sol qu'on ne traverse plus."
	incendiaire.cooldown = 0.3333  # 1,82 → 3,00 tirs/s (doublé, PLAFONNÉ)
	incendiaire.max_ammo = 2
	incendiaire.reload_time = 3.2
	incendiaire.damage_center = 55.0
	incendiaire.damage_edge = 35.0
	incendiaire.bullet_speed = 6000.0
	incendiaire.root = _root(0.40)
	incendiaire.fusees = _fusees(2, PERIODE_RECHARGE_FUSEE)
	incendiaire.gadget = _gadget("nappe_braises", "La nappe de braises",
		"Des braises au sol qui brûlent qui s'y attarde.", true)

	var sentinelle := _classe("sentinelle", "La Sentinelle", 7, 8.0, 2.6)
	sentinelle.name = "Fusil à verrou"
	sentinelle.description = "Elle ne cherche pas : elle veille. Perforant à longue portée, une fusée qui dure, et une poudre qui écrit les pas de qui passe."
	sentinelle.cooldown = 0.425  # 1,18 → 2,35 tirs/s (doublé)
	sentinelle.max_ammo = 2
	sentinelle.reload_time = 4.0
	sentinelle.damage_center = 75.0
	sentinelle.damage_edge = 60.0
	sentinelle.bullet_speed = 16000.0
	sentinelle.root = _root(0.50)
	sentinelle.fusees = _fusees(1, PERIODE_RECHARGE_FUSEE)
	sentinelle.gadget = _gadget("poudre_contact", "La poudre de contact",
		"Une poudre où les pas restent écrits, lisibles à la lumière.")

	var occulteur := _classe("occulteur", "L'Occulteur", 8, 25.0, 1.3)
	occulteur.name = "Pistolet-mitrailleur"
	occulteur.description = "Il masque la lumière au lieu d'en faire. Rafale courte, et une découpe d'acier qui projette l'ombre d'un homme qui n'existe pas."
	occulteur.cooldown = 0.09
	occulteur.max_ammo = 8
	occulteur.reload_time = 2.6
	# 10-15 (Adrien, 2026-09-09) : le pistolet-mitrailleur ne tue plus par
	# cartouche mais par RAFALE — huit balles à 15 font 120, un corps et demi.
	occulteur.damage_center = 15.0
	occulteur.damage_edge = 10.0
	occulteur.spread_bloom_per_shot_deg = 3.0
	occulteur.max_spread_bloom_deg = 16.0
	occulteur.muzzle_flash_intensity = 0.6
	occulteur.root = _root(0.15, true)  # rafale : l'immobilisation vient APRÈS
	occulteur.fusees = _fusees(1, PERIODE_RECHARGE_FUSEE)
	occulteur.automatique = true  # la SEULE arme qui tire détente tenue (Adrien, 2026-09-10)
	occulteur.gadget = _gadget("ombre_habitee", "L'ombre habitée",
		"Une découpe d'acier qui projette l'ombre d'un homme absent.")

	var allumeur := _classe("allumeur", "L'Allumeur", 9, 45.0, 1.2)
	allumeur.name = "Carabine double"
	allumeur.description = "Il allume — la mine, les cartouches vives, les deux fusées. La lumière maximale, celle qui ne laisse aucune ombre où se mettre."
	allumeur.cooldown = 0.20
	allumeur.max_ammo = 2
	allumeur.reload_time = 2.4
	allumeur.damage_center = 60.0
	allumeur.damage_edge = 40.0
	allumeur.muzzle_flash_intensity = 1.0
	allumeur.root = _root(0.20)
	allumeur.fusees = _fusees(2, 12.0)
	allumeur.gadget = _gadget("mine_magnesium", "La mine au magnésium",
		"Une mine qui n'explose pas : elle aveugle et révèle.", true)

	var spectre := _classe("spectre", "Le Spectre", 10, 20.0, 1.4)
	spectre.name = "Pistolet silencieux"
	spectre.description = "Au sommet de l'échelle de la lumière, celui qui n'en émet aucune. Zéro fusée, zéro flash, et une bâche qui arrête les rayons sans arrêter les balles."
	spectre.cooldown = 0.22
	spectre.max_ammo = 4
	spectre.reload_time = 2.6
	spectre.damage_center = 45.0
	spectre.damage_edge = 30.0
	# Zéro flash, comme l'arbalète : c'est ce qui fait la classe furtive.
	spectre.muzzle_flash_intensity = 0.0
	spectre.muzzle_flash_duration = 0.0
	spectre.backlight_multiplier = 0.1
	spectre.root = _root(0.08)
	spectre.fusees = _fusees(0, 0.0)  # la seule classe qui n'éclaire jamais
	spectre.gadget = _gadget("voile", "Le voile",
		"Une bâche qui arrête la lumière et les joueurs, pas les balles.")

	_classes = [
		weapon_pistolet, weapon_fusil, weapon_pompe, weapon_arbalete,
		fumiste, incendiaire, sentinelle, occulteur, allumeur, spectre,
	]

	# ⚠️ Le catalogue CRIE si un profil manque, il ne se répare pas. Une classe
	# sans profil n'est pas un cas dégradé : c'est un crash différé, au premier
	# `classe.root.duree` lu sur un `null`, en pleine manche.
	for c in _classes:
		if not c.est_complete():
			push_error("GameState : classe « %s » sans profil complet" % c.slug())


## Une classe neuve, avec ce que toutes partagent. Les valeurs propres à l'arme
## se posent par-dessus, comme les quatre blocs historiques le font déjà.
func _classe(slug: String, libelle: String, rang: int,
		demi_angle: float, echelle: float) -> ClassData:
	var c := ClassData.new()
	c.libelle = libelle
	c.rang = rang
	c.torch_cookie = slug  # une seule clé : cookie, sprite, sons, icône
	c.torch_angle_deg = demi_angle
	c.torch_scale = echelle
	return c


func _root(duree: float, apres_rafale: bool = false) -> RootProfile:
	var r := RootProfile.new()
	r.duree = duree
	r.apres_rafale = apres_rafale
	return r


## La recharge commune des fusées, en secondes — décision d'Adrien du
## 2026-09-10 : « une fusée par minute ». Elle vaut pour les SEPT classes qui ne
## rechargeaient pas du tout ; le Terrassier (18 s) et l'Allumeur (12 s) gardent
## leur recharge rapide, qui est leur identité de classe, et le Spectre reste à
## zéro — `recharge_active()` exige un plafond non nul, il ne regagnera jamais
## rien. Une constante et non sept littéraux : la règle ne peut plus diverger
## d'une classe à l'autre sans qu'on l'ait écrit.
const PERIODE_RECHARGE_FUSEE := 60.0


func _fusees(stock: int, periode: float) -> FlareProfile:
	var f := FlareProfile.new()
	f.stock = stock
	f.periode_recharge = periode
	return f


## Les gadgets DÉJÀ ÉCRITS, par slug. Les autres n'ont pas d'entrée, donc pas
## d'implémentation, donc `est_livre()` rend faux et la touche ne pose rien.
##
## ⚠️ **Une table, et non un argument de plus à `_gadget()`.** Écrire le chemin à
## la main sur chaque ligne du catalogue en ferait dix occasions de se tromper de
## slug — et un chemin qui ne correspond pas au slug est exactement le genre
## d'erreur que ce dépôt paie en silence : le gadget d'une classe se poserait
## sous le nom d'une autre.
## ⚠️ **La durée de vie est ICI et non dans le nœud**, contrairement aux points
## de vie ou au fait d'arrêter les balles. C'est la règle posée par Adrien le
## 2026-09-09 pour l'éblouissement, et elle vaut pour les deux : ce qui doit
## pouvoir se régler par INSTANCE sans toucher au type vit dans le profil. Une
## torche fantôme qui durerait deux fois moins longtemps est un réglage
## d'équilibrage ; qu'elle arrête les balles est ce qu'elle EST.
const IMPLEMENTATIONS := {
	"voile": {"script": "res://gadget_voile.gd", "duree_vie": 0.0},
	"ombre_habitee": {"script": "res://gadget_ombre.gd", "duree_vie": 0.0},
	# 16 s : de quoi faire traverser une pièce à un adversaire qui la croit
	# occupée, sans qu'un couloir reste éclairé toute la manche. À doser en jeu.
	"torche_fantome": {"script": "res://gadget_torche_fantome.gd", "duree_vie": 16.0},
	# La mine n'a pas de durée de vie : elle attend. C'est son embrasement qui la
	# tue, et il pose lui-même son échéance (`GadgetMine.allumer()`).
	"mine_magnesium": {"script": "res://gadget_mine.gd", "duree_vie": 0.0},
	# 10 s : assez pour interdire un passage le temps d'une décision, pas assez
	# pour qu'un couloir soit fermé toute la manche.
	"nappe_braises": {"script": "res://gadget_braises.gd", "duree_vie": 10.0},
	# Les deux volumes. La suie est dense et courte, la poussière large et un peu
	# plus brève encore : un nuage large qui durerait longtemps fermerait la
	# carte au lieu de la trouver.
	"cartouche_suie": {"script": "res://gadget_suie.gd", "duree_vie": 9.0},
	"poussiere": {"script": "res://gadget_poussiere.gd", "duree_vie": 7.5},
	# 18 s : assez pour qu'un adversaire le croise, hésite, et paie un tir. Un
	# leurre éternel finirait par être connu et cesserait de tromper.
	"leurre": {"script": "res://gadget_leurre.gd", "duree_vie": 18.0},
	# 0 : la bobine RESTE AU SOL (décision d'Adrien, 2026-09-10). Ce n'est plus sa
	# durée de vie qui borne la zone mais la BATTERIE de son poseur — quatorze
	# secondes allumée —, et une balle. Elle valait 14 s, et la table n'a pas été
	# relue quand la batterie est arrivée : la bobine mourait donc même éteinte,
	# ce que trois relecteurs sur quatre ont trouvé séparément.
	"gresillement": {"script": "res://gadget_gresillement.gd", "duree_vie": 0.0},
	# ⚠️ **Pas de durée de vie : la poudre reste la manche entière.** La
	# Sentinelle « ne cherche pas, elle veille » — un relevé qui s'effacerait tout
	# seul obligerait à repasser vite, c'est-à-dire à chercher.
	"poudre_contact": {"script": "res://gadget_poudre.gd", "duree_vie": 0.0},
}

## `description` : ce que le gadget fait, en une phrase courte, pour la fiche de
## sélection (Adrien, 2026-09-10). Obligatoire, et c'est voulu : un gadget sans
## phrase afficherait un trou sous son nom, `tools/test_classes.gd` le refuse.
func _gadget(slug: String, libelle: String, description: String,
		eblouit: bool = false) -> GadgetProfile:
	var g := GadgetProfile.new()
	g.slug = slug
	g.libelle = libelle
	g.description = description
	g.eblouit = eblouit
	var fiche: Dictionary = IMPLEMENTATIONS.get(slug, {})
	g.implementation = String(fiche.get("script", ""))
	g.duree_vie = float(fiche.get("duree_vie", 0.0))
	return g


## Le catalogue, en lecture. Rend une copie du tableau : le contenu reste
## partagé, mais personne ne réordonne la liste de l'extérieur.
func classes() -> Array[ClassData]:
	var copie: Array[ClassData] = []
	copie.assign(_classes)
	return copie


## La classe d'un index d'arme, ou `null` hors bornes.
##
## ⚠️ **Ne double PAS `weapon_for_index()`** : celle-là reste la seule table de
## résolution pour les quatre armes historiques, et son commentaire dit pourquoi.
## Celle-ci lit le catalogue, qui les contient. Deux chemins vers la même vérité
## sont exactement ce que le dépôt a payé trois fois le 2026-08-24 — d'où le
## contrôle croisé dans `tools/test_classes.gd`, qui exige que les deux
## répondent la même chose sur 0 à 3.
func classe_pour_index(idx: int) -> ClassData:
	if idx < 0 or idx >= _classes.size():
		return null
	return _classes[idx]

## L'arsenal commun de ce match, règle du miroir appliquée. Vide hors match
## apparié CLASSÉ : ailleurs — amical compris —, l'arme est choisie au menu et
## rien n'est à aligner, la règle du miroir n'existant pas en amical.
func matchmade_arsenal() -> Array[int]:
	if not _matchmade_round or not _matchmade_ranked:
		return []
	return RankLoadout.mirrored(_mirror_local_tier, _mirror_opponent_tier)

## Pourquoi l'arsenal est celui-là, en langage joueur — vide s'il n'a pas rétréci.
## L'écran ne reconstruit pas le raisonnement : il affiche ce que la table rend.
func matchmade_arsenal_reason() -> String:
	if not _matchmade_round or not _matchmade_ranked \
			or _mirror_opponent_tier >= maxi(_mirror_local_tier, 1):
		return ""
	# ⚠️ **L'index n'est plus l'arbalète en dur.** Il l'était parce qu'elle est la
	# dernière du socle, donc la première écartée — vrai tant que l'arsenal
	# comptait quatre armes rangées par rang croissant, faux dès qu'il en compte
	# dix. On demande donc la raison sur une arme EFFECTIVEMENT écartée : la
	# première du socle absente de l'arsenal commun.
	#
	# Sans ce changement, la phrase affichée au joueur — la mesure d'atténuation
	# que la règle du miroir EXIGE, faute de quoi le rétrécissement « sera vécu
	# comme un bug » — parlerait d'une arme qu'il a peut-être encore.
	var commun := matchmade_arsenal()
	for idx in RankLoadout.SOCLE:
		if not idx in commun:
			return RankLoadout.reason_for(idx, true,
				_mirror_local_tier, _mirror_opponent_tier)
	# Rien d'écarté : le premier test l'a déjà dit, mais un chemin muet vaut
	# mieux qu'un index inventé.
	return ""

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

## [Appariement] Les deux joueurs se sont trouvés et le lien vient d'être ouvert
## — ouvert, pas établi : c'est la nuance qui a coûté le défaut du 2026-09-09.
##
## Les deux camps passent ici, et chacun y pose ce que seul l'appariement sait :
## que ce match ouvre une fenêtre de choix d'arme, et les deux catégories de la
## règle du miroir. L'hôte, lui, ARME son départ ; il ne part pas.
func _on_match_ready(_pairing: Dictionary) -> void:
	# Posé des DEUX côtés — le client ne passe pas par `_start_round()`, il
	# reçoit `rpc_start_round`, et sans ces deux drapeaux son décompte durerait
	# trois secondes pendant que l'hôte en compte dix (ou l'inverse).
	_matchmade_round = true
	# `Matchmaking.pairing_snapshot()` pose déjà `ranked` — c'est le mode dans
	# lequel la recherche a été lancée, connu AVANT l'appariement. Seul ce match
	# classé ouvre une fenêtre de choix : l'arsenal commun n'y est connu qu'une
	# fois l'adversaire trouvé, la règle du miroir l'alignant sur le moins bien
	# classé. En amical elle ne s'applique pas (« Absent de l'amical », décision
	# d'Adrien du 2026-08-18) : l'arme est déjà celle choisie au menu.
	_matchmade_ranked = bool(_pairing.get("ranked", false))
	_mirror_local_tier = int(_pairing.get("local_tier", 0))
	_mirror_opponent_tier = int(_pairing.get("opponent_tier", 0))
	# Le joueur a choisi son arme sans savoir s'il hébergerait : la désignation
	# vient tout juste d'avoir lieu. Le choix est donc reporté sur les deux
	# râteliers, l'hôte lisant celui de J1 et l'invité celui de J2.
	ui.mirror_weapon_choice()
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
		# [Client] Symétrique de l'échéance hôte ci-dessous : `join_matched_game()`
		# vient de tenter la connexion, mais « tentative engagée » n'est pas
		# « connexion établie ». Sans échéance ici, un lien P2P qui reste bloqué
		# (NAT hostile, hôte qui a lui-même expiré sans que le signal de
		# déconnexion se propage) laisserait le client attendre indéfiniment un
		# `rpc_start_round` qui ne viendra jamais — le même défaut que
		# `_on_join_requested()` corrige déjà pour un salon à code, jamais porté
		# jusqu'ici.
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
			_armer_echeance_connexion_appariee()
		return
	# ⚠️ **La manche ne part PAS ici, et c'est tout l'objet du report.**
	#
	# `match_ready` est émis dans la foulée de `host_matched_game()` : la socket
	# vient d'ouvrir, l'invité n'a pas encore eu une seule image pour s'y
	# connecter — il ne le peut pas. `_start_round()` appelé maintenant trouve
	# donc `multiplayer.get_peers()` VIDE et prend sa branche « hôte resté seul » :
	# bac à sable, cible d'entraînement, « EN ATTENTE D'UN ADVERSAIRE… ».
	#
	# Et plus rien ne l'en sort. La porte PRÊT a retiré le départ automatique de
	# `_on_peer_connected` et de `rpc_client_weapon` — à juste titre pour un salon
	# à code, où deux humains se déclarent — mais l'appariement n'a pas de porte
	# PRÊT : Adrien a demandé qu'il n'en ait pas (2026-08-18). Résultat mesuré à
	# deux machines le 2026-09-09 : l'hôte seul dans son arène pour toujours,
	# l'invité connecté mais resté dans son menu, faute de `rpc_start_round`.
	# Aucun des deux changements n'était fautif seul ; c'est leur rencontre.
	#
	# Le départ appartient donc à `rpc_client_weapon` — le premier instant où
	# l'hôte a À LA FOIS un pair connecté et l'arme qu'il tient.
	_matchmade_start_pending = true
	_matchmade_token += 1
	_armer_echeance_appariement(_matchmade_token)

## [Hôte] L'invité apparié ne s'est pas connecté à temps.
##
## Sans cette échéance le report ci-dessus déplace le blocage au lieu de le
## supprimer : l'hôte attendrait dans son menu, indéfiniment et sans rien dire,
## un invité qu'Epic n'a jamais fait arriver.
##
## Sa propre constante, et non `NetworkManager.join_timeout()`, qui vaut cinq
## secondes en ENet. Ce n'est pas une jointure manuelle : les deux camps viennent
## de se négocier chez Epic, la connexion suit à la seconde. Vingt secondes est
## large partout — et surtout, la durée ne dépend plus d'un transport dont
## l'appariement n'a pas à connaître le nom.
const DELAI_INVITE_APPARIE := 20.0

func _armer_echeance_appariement(jeton: int) -> void:
	var timer := get_tree().create_timer(DELAI_INVITE_APPARIE)
	timer.timeout.connect(func() -> void:
		if not _matchmade_start_pending or jeton != _matchmade_token:
			return
		_matchmade_start_pending = false
		_on_main_menu_requested()
		ui.show_dialog_message("Adversaire injoignable",
			("Votre adversaire a bien été trouvé, mais la connexion ne s'est jamais "
			+ "établie. Vous pouvez relancer une recherche."),
			UI.Registre.ATTENTION)
	)

## [Client] Le lien vers l'hôte apparié ne s'établit jamais.
##
## Réutilise `_join_deadline_active` et `_on_connection_failed()` — le même
## couple que `_on_join_requested()` arme déjà pour un salon à code, et pour la
## même raison : « tentative engagée » (`join_matched_game()` a renvoyé vrai)
## n'est pas « connexion établie », et rien ne garantit que `connection_failed`
## se déclenche de lui-même sur un P2P qui reste bloqué. Même durée que
## l'échéance hôte symétrique : c'est le même rendez-vous EOS des deux côtés.
func _armer_echeance_connexion_appariee() -> void:
	_join_deadline_active = true
	var timer := get_tree().create_timer(DELAI_INVITE_APPARIE)
	timer.timeout.connect(func() -> void:
		if not _join_deadline_active:
			return
		_join_deadline_active = false
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT \
				and multiplayer.get_peers().is_empty():
			_on_connection_failed()
	)

## [Hôte] Le départ d'un match apparié, une fois l'invité vraiment là.
##
## La carte est choisie **avant** `_start_round()`, parce que c'est cet appel
## qui reconstruit l'arène et que `_host_map_code()` la joindra au paquet de
## départ du client. Choisir après donnerait deux arènes différentes aux deux
## joueurs — le défaut le plus coûteux à diagnostiquer de tout le jeu, chacun
## voyant un monde cohérent.
##
## **Classé et amical divergent ici, décision d'Adrien du 2026-09-09.** Le
## classé garde le tirage au sort dans tout le catalogue — la question
## d'équité qu'il ouvre (une carte importée par l'adversaire) reste ouverte,
## « à trancher par Adrien » selon la ROADMAP, et cette session ne la tranche
## pas. L'amical, lui, prend systématiquement la carte par défaut : même choix
## que l'entraînement (`_on_training_requested`), pour la même raison — un
## terrain connu plutôt qu'une arène surprise pour un match sans enjeu.
func _lancer_match_apparie() -> void:
	_poser_la_carte_appariee()
	_enter_hosted_game()
	_start_round()

## [Hôte] L'arène d'un match apparié : tirée au sort en classé, l'arène standard
## en amical.
##
## Sortie de `_lancer_match_apparie()` le 2026-09-10 pour être éprouvée seule :
## Adrien a redit ce jour-là que *« le match amical en ligne doit prendre l'arène
## classique »*, et la règle, posée la veille, n'était gardée par aucun banc.
## `tools/test_online_match.gd --appariement` l'appelle sans réseau ni pair.
func _poser_la_carte_appariee() -> void:
	if _matchmade_ranked:
		MapData.select_random_map()
	else:
		MapData.select_map(MapData.DEFAULT_MAP_ID)

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
	# L'affiche de victoire/défaite est opaque et devrait déjà avaler le clic —
	# mais elle se congédie sur N'IMPORTE QUEL geste (`AfficheDeFin._unhandled_input`),
	# donc un joueur qui clique EN MÊME TEMPS la referme et presse REJOUER dans le
	# même geste si les deux réagissent au même événement. Ce garde est la
	# deuxième porte : tant qu'elle est visible, REJOUER ne fait rien.
	if is_instance_valid(_affiche_de_fin) and _affiche_de_fin.est_active():
		return
	if ui._is_main_menu:
		# Un match lancé depuis le menu n'ouvre pas de fenêtre de choix : l'arme y
		# est déjà choisie. Sans cette remise à zéro, un salon ouvert après un
		# match apparié hériterait de ses dix secondes — et le décompte durerait
		# trois fois trop longtemps sans que rien ne l'explique.
		_matchmade_round = false
		_matchmade_ranked = false
		_matchmade_start_pending = false
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
			_hosted_weapon_1_idx = ui.selected_weapon_index(0)
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

		var w2_idx = ui.selected_weapon_index(1)

		local_ready_for_rematch = true
		ui.btn_replay.text = "✓ PRÊT"
		ui.btn_replay.add_theme_color_override("font_color", Charte.ETAT_OK)
		
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
			rpc_id(1, "rpc_client_ready", w2_idx)
		elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
			p1_ready_for_rematch = true
			_hosted_weapon_1_idx = ui.selected_weapon_index(0)
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
	# Un match apparié encore en cours de connexion laisse `_is_main_menu` à
	# vrai (« l'hôte apparié attend son invité dans le menu ») avec un
	# `current_mode` déjà engagé : sans ce contrôle, `join_game()` ouvrirait un
	# second lien par-dessus celui, encore vivant, que l'appariement tient.
	if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
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
	if not _matchmade_round or not _matchmade_ranked or countdown_left <= 0.0:
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

## [Client] L'hôte a vu les deux « prêt » et abrège la fenêtre — ce paquet est
## ce qui manquait pour que le client suive. Sans lui, `_process()` ne
## collapse le décompte QUE côté hôte : la manche partait pour lui seul
## pendant que le client comptait ses dix secondes jusqu'au bout, mesuré à
## deux machines le 2026-09-09. `call_remote` et non `call_local` : l'hôte a
## déjà collapsé le sien juste avant d'envoyer ce paquet.
@rpc("authority", "call_remote", "reliable")
func rpc_countdown_launch() -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	countdown_left = 0.0

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
		var w2_idx = ui.selected_weapon_index(1)
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
## Le brouillage, une image à la fois.
##
## ⚠️ **L'intensité vient du REGARDEUR, la position de l'ÉMETTEUR.** Les
## intervertir donne un effet cohérent et faux : on se cacherait soi-même en
## éblouissant quelqu'un. Pour la vue de J1, c'est donc `maj(p1, p2)` — J1 subit,
## J2 est celui qu'on brouille.
##
## Hors manche, tout s'éteint : un `BackBufferCopy` visible recopie à chaque
## image, qu'on lise sa copie ou non.
func _maj_brouillage() -> void:
	if _brouillages.is_empty():
		return
	var actif: bool = round_active and is_instance_valid(p1) and is_instance_valid(p2)
	for i in 2:
		var app: Node = _brouillages[i]
		if app.get_parent() == null:
			continue
		if not actif:
			app.eteindre()
			continue
		# ⚠️ **L'adversaire N'EST PLUS passé en dur, et il l'était.** Le flou et le
		# halo du brouillage se posaient sur l'autre joueur quelle que soit la
		# cause de l'éblouissement — donc, dès qu'une lumière POSÉE éblouissait
		# (mine, braises, fusée), l'appareil censé masquer allait dessiner une
		# grande ellipse sur l'adversaire, à l'autre bout de la carte.
		#
		# À l'entraînement, ça donnait une ellipse flottant dans le noir sur un
		# J2 invisible resté à son point d'apparition — c'est ce qu'Adrien a
		# signalé le 2026-09-09, et qu'une session précédente avait cherché sans
		# le trouver. **En ligne c'est pire qu'un artefact : un effet dont le
		# métier est de MASQUER désignait la position de l'autre.**
		#
		# ⚠️ **C'est le JUMEAU exact du défaut corrigé le même jour sur le voile**
		# (`ui._source_du_voile`). La source d'éblouissement alimente deux
		# consommateurs ; le lot a réparé le premier et laissé le second, et rien
		# ne l'a dit parce que les deux restent plausibles à l'écran.
		var regardeur: Node2D = p1 if i == 0 else p2
		app.maj(regardeur, source_eblouissante_ou(regardeur, p2 if i == 0 else p1))


## Vers quoi un effet d'éblouissement doit se tourner : la source qui éblouit
## RÉELLEMENT cette victime, l'adversaire seulement à défaut.
##
## ⚠️ **Publique, et c'est l'objet du geste.** La règle existait déjà, en privé,
## dans `ui._source_du_voile()` — et le brouillage, qui en avait autant besoin,
## ne l'avait pas. Deux copies auraient fini par diverger ; il n'y en a plus
## qu'une, et elle vit là où `source_eblouissante` est ÉCRITE.
##
## Le repli sur l'adversaire n'est pas un bouche-trou : c'est le comportement
## d'avant, conservé pour l'instant où l'hôte n'a pas encore désigné de source —
## première image d'une manche, ou éblouissement nul.
func source_eblouissante_ou(victime: Node, defaut: Node) -> Node:
	if victime == null:
		return defaut
	var s = victime.get("source_eblouissante")
	return s if s != null and is_instance_valid(s) else defaut


func _accorder_rendu_aux_vues() -> void:
	var regardees: Array[SubViewport] = []
	for vue in [vp1, vp2]:
		var conteneur := vue.get_parent() as Control
		if conteneur != null and conteneur.visible:
			regardees.append(vue)

	# R3 (b) : une seule vue regardée ⇒ le duel se rend DANS LA RACINE.
	if regardees.size() == 1 and rendu_racine_autorise:
		_rendre_dans_la_racine(regardees[0])
	else:
		_rendre_dans_les_sous_vues()

	for vue in [vp1, vp2]:
		var conteneur := vue.get_parent() as Control
		# `_rendu_racine` l'emporte : la vue regardée n'a plus rien à dessiner,
		# c'est la racine qui la remplace.
		var vu: bool = conteneur != null and conteneur.visible and not _rendu_racine
		vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS if vu \
			else SubViewport.UPDATE_DISABLED

	_accorder_la_peinture_de_la_racine()
	_accorder_brouillage_aux_vues()


## Ce que la racine peint POUR ELLE-MÊME s'efface pendant qu'elle peint le duel.
##
## **Sans ça, R3 (b) livrait un écran entièrement noir**, et pas seulement à
## l'entraînement : en ligne aussi, des deux côtés du lien. Le duel était bien
## dessiné — puis recouvert.
##
## Prêter le `World2D` du duel à la racine y fait entrer ses PROPRES `CanvasItem`,
## qui cessent d'être en coordonnées d'écran pour passer en coordonnées de monde,
## sous la transformation de la caméra. Deux d'entre eux sont opaques et pleins
## cadre : le `Background` noir de `main.tscn`, et les deux `SubViewportContainer`
## qui peignent la texture **gelée** de vues que ce même chemin vient d'arrêter.
## Ils tombent donc pile sur la carte.
##
## Mesuré le 2026-08-27, noir du `CanvasModulate` levé pour chercher des tuiles
## et non un halo : luminance au centre **0,00098** telle quelle, **0,29545** ces
## trois nœuds éteints — soit exactement le rendu sous-vue (0,29543). Rien ne
## manquait, tout était masqué. En duel ENet le même jour : 0,036 → 0,280 chez
## l'hôte, 0,033 → 0,278 chez le client.
##
## ⚠️ **`modulate` et non `visible`, pour DEUX raisons mesurées.**
##
## La première est une question de propriété : le `visible` d'un conteneur de vue
## est la source de vérité de « quelle vue est regardée ». `_accorder_rendu_aux_vues()`
## y compte les vues, `_accorder_brouillage_aux_vues()` y lit où loger l'appareil
## de brouillage. Le cacher ferait basculer le rendu à chaque image et retirerait
## le brouillage.
##
## La seconde ne se devine pas : **`hide()` puis `show()` ne rend pas l'écran
## d'avant.** Montrer de nouveau un `SubViewportContainer` rafraîchit sa texture,
## et l'aller-retour laisse à l'écran une image que personne n'a demandée —
## relevé 0,048 au lieu des 0,001 de départ. L'aller-retour par l'alpha, lui,
## revient exactement (0,00129 → 0,29665 → 0,00134, mesuré le 2026-08-28). On
## retire donc la peinture, jamais l'existence.
##
## ⚠️ **Une RÈGLE, pas une liste de trois noms.** Le premier jet nommait le fond
## et les deux conteneurs. C'était juste et ça pourrissait : `SplitScreen` rejoint
## le même canvas et ne peint rien **aujourd'hui** — il n'a ni `_draw()` ni
## `StyleBox` —, mais le jour où quelqu'un lui pose un fond, il recouvre le duel
## et la liste ne l'attrape pas. On parcourt donc les enfants directs qui peignent,
## et `modulate` plutôt que `self_modulate` pour que la consigne descende aussi
## à ce qu'on ajoutera dessous.
##
## `UI` s'exclut tout seul, et c'est la raison de fond : c'est un `CanvasLayer`,
## pas un `CanvasItem`. Une couche s'attache au VIEWPORT et non au canvas du
## monde — elle ignore l'échange de `World2D`, reste en coordonnées d'écran, et
## doit continuer de peindre. Le HUD n'a jamais été en cause.
func _accorder_la_peinture_de_la_racine() -> void:
	var alpha := 0.0 if _rendu_racine else 1.0
	for enfant in get_children():
		var peintre := enfant as CanvasItem
		if peintre != null:
			peintre.modulate.a = alpha


## Chaque appareil de brouillage rejoint la vue qui le rend.
##
## ⚠️ **Il suit le rendu, pas l'affichage.** En vue unique, le conteneur de la
## vue regardée est bien visible, mais son `SubViewport` est ARRÊTÉ : y laisser
## l'appareil reviendrait à dessiner dans une texture que personne ne montre.
## C'est le même piège que `_restore_viewports()` avait payé sur le
## `render_target_update_mode` — 1,5 ms pour rien.
func _accorder_brouillage_aux_vues() -> void:
	if _brouillages.is_empty():
		for i in 2:
			var app: Node = preload("res://brouillage_vue.gd").new()
			app.name = "BrouillageVue%d" % (i + 1)
			_brouillages.append(app)
	for i in 2:
		var app: Node = _brouillages[i]
		var vue: SubViewport = vp1 if i == 0 else vp2
		var conteneur := vue.get_parent() as Control
		var regardee: bool = conteneur != null and conteneur.visible
		if not regardee:
			if app.get_parent() != null:
				app.get_parent().remove_child(app)
			continue
		var parent: Node = self if _rendu_racine else vue
		if app.get_parent() != parent:
			if app.get_parent() != null:
				app.get_parent().remove_child(app)
			parent.add_child(app)


## Rend le duel directement dans le viewport racine, à la résolution de la
## fenêtre. **Chantier R, étape R3 option (b), retenue par Adrien le 2026-08-25
## pour l'équité en compétition.**
##
## Le problème : un `SubViewport` rend à taille FIXE — 1916×1080 en vue unique —
## quel que soit la fenêtre, parce que `SubViewportContainer` ne lui répercute
## pas le facteur d'étirement. Le duel était donc dessiné en 1080p puis ÉTIRÉ.
##
## **Pourquoi la racine règle ça sans toucher aux caméras**, et c'est toute la
## raison du choix : le viewport racine est en `canvas_items` + `keep`, donc son
## aire 2D reste 1920×1080 quelle que soit la fenêtre pendant que le rendu, lui,
## se fait en pixels de fenêtre. Une caméra à `zoom = 1.0` y montre exactement le
## même monde qu'avant. L'autre voie — agrandir le `SubViewport` — aurait exigé
## de corriger le zoom du même facteur dans les cinq endroits où il est posé,
## dont la killcam, **et donc de rouvrir la question du champ de vision que le
## passage en `keep` venait de fermer.** C'est un sujet d'équité, pas de confort.
##
## On ne déplace AUCUN nœud : les joueurs, l'arène et les balles restent enfants
## de `vp1`. La racine adopte simplement le même `World2D`, le masque de cull de
## la vue regardée, et sa caméra.
func _rendre_dans_la_racine(vue: SubViewport) -> void:
	var racine := get_window()
	var cam: Camera2D = cam1 if vue == vp1 else cam2
	# **Sortir sans rien changer tant que les caméras n'existent pas.** Cette
	# fonction est appelée avant `_setup_players()` sur certains chemins ; basculer
	# le monde sans caméra donnerait un écran noir que rien ne signalerait. Le
	# rendu reste alors dans les `SubViewport`, et le prochain accord rattrape.
	if racine == null or cam == null:
		return
	if _monde_racine == null:
		_monde_racine = racine.world_2d
	racine.world_2d = vue.world_2d
	racine.canvas_cull_mask = vue.canvas_cull_mask
	cam.custom_viewport = racine
	cam.make_current()
	# **L'écoute ne se règle PAS ici, et c'est délibéré.**
	#
	# Prêter à la racine le `World2D` du duel en fait bien une seconde oreille —
	# un `AudioStreamPlayer2D` sort une fois par viewport auditeur, donc chaque
	# son sortirait deux fois. Ce fichier a d'abord corrigé ça lui-même, en
	# coupant `racine.audio_listener_enable_2d` juste ici. **C'était un second
	# gestionnaire du même drapeau, et le plus dangereux des deux :** il coupait
	# sans regarder où vit l'oreille, donc il produisait un SILENCE COMPLET dès
	# que l'oreille vivait dans la racine — mesuré ailleurs à -200 dB sur le bus.
	#
	# `AudioManager` possède ce drapeau et le tient correctement : `poser_oreille`
	# ne coupe la racine que si l'oreille est ailleurs (`if vue != root`), et
	# `rendre_oreille` la lui rend. Un invariant tenu à deux endroits finit par
	# diverger ; celui-ci a son propriétaire, et ce n'est pas le rendu.
	#
	# Ce qui reste vrai et vérifié par `tools/test_rendu_racine.gd` : après la
	# bascule ET l'oreille posée, **un seul viewport écoute le monde du duel**.
	_rendu_racine = true


## Remet le duel dans ses deux `SubViewport` — l'écran scindé, qui en a besoin :
## deux vues, deux masques de cull, deux caméras.
##
## Idempotente à dessein : appelée à chaque accord, elle ne fait rien tant que
## la racine n'a pas été détournée.
func _rendre_dans_les_sous_vues() -> void:
	if not _rendu_racine:
		return
	var racine := get_window()
	if racine != null:
		if _monde_racine != null:
			racine.world_2d = _monde_racine
		racine.canvas_cull_mask = MASQUE_CULL_TOUT
		# Pas de `audio_listener_enable_2d` ici non plus : `rendre_oreille()` rend
		# déjà l'écoute à la racine, et c'est son rôle. Voir plus haut.
	if cam1 != null:
		cam1.custom_viewport = vp1
		cam1.make_current()
	if cam2 != null:
		cam2.custom_viewport = vp2
		cam2.make_current()
	_rendu_racine = false

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


## `target_screen` : écran du hub à rouvrir une fois de retour à l'accueil,
## par-dessus le `hub.reset()` de `ui.show_main_menu()` — vide pour rester à
## l'accueil (le cas de tous les appelants existants, MENU PRINCIPAL compris).
## Seul `_on_quit_match_requested()` en passe un : c'est lui qui distingue
## « quitter le match » (retour au salon de départ) de « menu principal »
## (retour à l'accueil), les deux partageant sinon exactement le même ménage.
func _on_main_menu_requested(target_screen: String = ""):
	# Départ volontaire en plein match : c'est un abandon, et il se paie. Le
	# vainqueur est l'adversaire — celui qui reste. Archivé AVANT la déconnexion,
	# qui repasse le mode en local et rendrait l'enregistrement muet sur son
	# origine. Si un signal du transport est déjà passé par là, le jeton a été
	# consommé et cet appel ne fait rien.
	var local_idx := _local_player_index()
	if local_idx >= 0:
		_archive_forfeit(1 - local_idx)

	NetworkManager.disconnect_from_game()

	# DA6.3 — la soirée s'arrête ici, et nulle part ailleurs. Après le
	# désabonnement du transport : la carte lit l'historique, pas le réseau, et
	# la poser avant ferait apparaître une carte de bilan par-dessus une
	# déconnexion en cours.
	_peut_etre_la_soiree()

	client_peer_id = 0
	_join_deadline_active = false
	# Un départ apparié encore armé rouvrirait une arène par-dessus le menu, à
	# l'arrivée d'un paquet d'un lien qu'on vient de couper.
	_matchmade_start_pending = false
	countdown_left = 0.0
	ui.set_countdown(0.0)
	# Retour au menu depuis une killcam : sans ça le menu tourne au ralenti et
	# une séquence de fin en vol reviendrait afficher un écran de victoire.
	_round_token += 1
	_end_sequence_active = false
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
	dernier_effleurement = -1.0
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

	# **Quitter le duel, c'est aussi le rendre à ses vues.** Ce chemin ne repassait
	# par aucun accord de rendu : `_rendu_racine` restait VRAI sous les menus, la
	# racine gardant le `World2D` du duel — vérifié le 2026-08-28, au retour de
	# l'entraînement comme d'une partie en ligne. Personne ne le voyait parce que
	# le `Background` noir opaque recouvrait l'arène ; c'était juste par accident,
	# et l'accident vient de tomber : ce fond s'efface désormais pendant le rendu
	# racine, donc l'oubli montrerait l'arène sous les menus.
	#
	# `training_mode` tombe ici pour la même raison que `sandbox_mode` et
	# `round_active` plus haut : cette fonction a déjà démonté la session
	# d'entraînement — la cible est retirée, l'arène purgée. Le laisser vrai
	# enverrait l'accord ci-dessous dans la branche « une seule vue », donc
	# aussitôt de retour dans le rendu racine.
	training_mode = false
	vp1.get_parent().show()
	vp2.get_parent().show()
	_accorder_rendu_aux_vues()

	ui.show_main_menu()
	# `show_main_menu()` vient de remettre le hub à l'accueil (`hub.reset()`) —
	# un écran voulu descend d'un cran par-dessus, APRÈS coup : `hub.push()`
	# refuse silencieusement un identifiant inconnu ou déjà courant, donc un
	# `target_screen` vide (tous les appelants sauf « quitter le match ») ne
	# change rien ici.
	if target_screen != "":
		ui.hub.push(target_screen)
	AudioManager.play_music("music_menu")

## Retour à la pause vers « QUITTER LE MATCH » : le même abandon que MENU
## PRINCIPAL (forfait compris — c'est `_on_main_menu_requested()` qui le
## paie), mais qui rouvre le salon d'où le match est parti au lieu de
## l'accueil du hub. Cet écran n'est encore qu'une mémoire best-effort
## (`ui.match_origin_screen()`) : rien ne garantissait avant ce chantier
## qu'il existe un « salon de départ » à retrouver, donc un identifiant
## absent ou périmé retombe simplement sur l'accueil, comme MENU PRINCIPAL.
func _on_quit_match_requested():
	_on_main_menu_requested(ui.match_origin_screen())

func _on_quit_requested():
	# Quitter le jeu en plein match est un abandon comme un autre : il se paie.
	var local_idx := _local_player_index()
	if local_idx >= 0:
		_archive_forfeit(1 - local_idx)

	# quit() ne prend effet qu'en fin de frame : sortir depuis une killcam
	# étirerait ces dernières frames au ralenti.
	Engine.time_scale = 1.0
	_liberer_le_releve()
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
