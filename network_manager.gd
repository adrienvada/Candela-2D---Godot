extends Node


enum GameMode { LOCAL_SPLITSCREEN, ONLINE_HOST, ONLINE_CLIENT }
var current_mode: GameMode = GameMode.LOCAL_SPLITSCREEN

## Transport de la partie en ligne.
##
## EOS traverse les NAT par le réseau d'Epic (code de salon) ; ENET reste le
## mode LAN/debug, seul moyen de déboguer le netcode sans dépendre d'un service
## tiers. Tout ce qui est au-dessus (RPC, MultiplayerAPI, signaux ci-dessous)
## est rigoureusement identique dans les deux cas : aucun `if transport == ...`
## ne doit exister hors de ce fichier et de l'UI de lobby.
enum Transport { EOS, ENET }
var transport: Transport = Transport.EOS

## Cycle de vie de la session Epic, reflété par le menu.
enum EosState { UNCONFIGURED, INITIALIZING, READY, FAILED }
var eos_state: EosState = EosState.UNCONFIGURED

const DEFAULT_PORT := 7777
const MAX_CLIENTS  := 1 # Only 1v1 (1 Host + 1 Client)

var peer: MultiplayerPeer

# --- EOS ---------------------------------------------------------------------
const EOS_CREDENTIALS_PATH := "res://eos_credentials.gd"
## Cloisonne les recherches de salon : sans lui, un code tiré par un autre jeu
## (ou une version incompatible de celui-ci) répondrait à notre recherche.
const EOS_BUCKET_ID := "candela2d-1v1-v1"
const EOS_CODE_ATTRIBUTE := "CODE"
## Contrainte du SDK : alphanumérique strict, 32 caractères maximum.
const EOS_SOCKET_ID := "candela2d"
## Le temps qu'EOS cherche le salon, ouvre le socket puis perce le NAT — parfois
## via un relais Epic. Sans commune mesure avec le timeout d'un connect ENet.
const EOS_JOIN_TIMEOUT := 20.0
const ENET_JOIN_TIMEOUT := 5.0
## Trois tirages suffisent : sur 32^6 combinaisons, une collision est déjà une
## curiosité, deux d'affilée un accident statistique.
const EOS_CODE_ATTEMPTS := 3
## Sondages de l'index d'Epic, côté hôte, avant d'annoncer le code au joueur.
## Une recherche qui ne trouve rien coûte ~3,1 s : c'est trop cher pour la
## répéter côté client, où elle allongerait d'autant l'annonce d'un code mal
## tapé. L'attente est donc supportée par l'hôte, qui patiente déjà.
const EOS_CODE_VISIBLE_ATTEMPTS := 4

## Reprises côté client. Une recherche infructueuse coûte déjà ~3 s : trois
## tentatives espacées tiennent dans l'échéance de 20 s tout en couvrant la
## latence de publication de l'index Epic.
const EOS_JOIN_SEARCH_ATTEMPTS := 3
const EOS_JOIN_SEARCH_DELAY := 1.5

var eos_puid: String = ""
var lobby_code: String = ""
## Dernier échec en clair, à afficher par l'UI. Vidé à chaque nouvelle tentative.
var last_error: String = ""
## EOS.P2P.NetworkType du lien courant, -1 tant que le SDK ne l'a pas rapporté.
var eos_network_type: int = -1
var eos_nat_type: int = -1

var _eos_lobby = null              # HLobby, ou null
var _eos_peer: EOSGMultiplayerPeer = null
var _eos_ephemeral: bool = false
var _eos_shutting_down: bool = false
## Vrai dès que la plateforme EOS existe — et donc qu'il faut la relâcher avant
## de quitter. Un échec d'initialisation laisse ce drapeau faux : appeler
## release() sur une plateforme jamais créée planterait à la fermeture.
var _eos_platform_created: bool = false
## MultiplayerAPI n'émet pas connected_to_server / server_disconnected de façon
## fiable avec EOSGMultiplayerPeer : ces jetons évitent d'émettre deux fois si
## les deux chemins (API et signaux du pair) se déclenchent tous les deux.
var _connection_success_emitted: bool = false
var _host_disconnected_emitted: bool = false
## Pairs fermés mais pas encore relâchés — voir _retire_peer.
var _retired_peers: Array[MultiplayerPeer] = []

# Écho applicatif plutôt que le RTT interne d'ENet : c'est le délai réellement
# subi par la boucle de jeu (files d'attente, cadence de traitement) qui sert
# à compenser les tirs, et lui seul est comparable des deux côtés.
const PING_INTERVAL := 1.0
const RTT_SMOOTHING := 0.3

var rtt_ms: float = 0.0
var has_rtt: bool = false
var _ping_accum: float = 0.0

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed
signal connection_success
signal host_disconnected

## Émis quand l'état de la session Epic change (menu, panneau F3).
signal eos_state_changed(state: EosState)
## Émis côté hôte quand le code du salon est publié et donc communicable.
signal lobby_code_ready(code: String)

# ===========================================================================
# CYCLE DE VIE
# ===========================================================================

func _ready() -> void:
	_eos_ephemeral = _ephemeral_requested()
	if _flag_present("--no-eos"):
		return
	_init_eos_async()

## Délai au-delà duquel une tentative de connexion est déclarée perdue.
func join_timeout() -> float:
	return EOS_JOIN_TIMEOUT if transport == Transport.EOS else ENET_JOIN_TIMEOUT

## Vrai quand le jeu tourne sous une identité Epic jetable (tests à deux
## instances locales). L'UI doit le dire à l'écran : c'est un mode de mise au
## point, pas un état normal.
func is_ephemeral_identity() -> bool:
	return _eos_ephemeral

func eos_state_label() -> String:
	match eos_state:
		EosState.INITIALIZING: return "Connexion à Epic…"
		EosState.READY: return "Epic : connecté"
		EosState.FAILED: return "Epic : indisponible"
		_: return "Epic : non configuré"

# ===========================================================================
# HÉBERGEMENT / JOINTURE
# ===========================================================================

## Renvoie faux si la partie n'a pas pu être lancée ; l'appelant ne doit alors
## surtout pas enchaîner sur le démarrage de la manche.
func host_game(port: int = DEFAULT_PORT) -> bool:
	last_error = ""
	return _host_enet(port) if transport == Transport.ENET else _host_eos()

## `address` est une IP en ENet, un code de salon à 6 caractères en EOS.
## Vrai signifie « tentative engagée » : l'issue arrive par connection_success
## ou connection_failed.
func join_game(address: String, port: int = DEFAULT_PORT) -> bool:
	last_error = ""
	return _join_enet(address, port) if transport == Transport.ENET else _join_eos(address)

func disconnect_from_game() -> void:
	# Pendant l'arrêt, plus aucun appel à EOS : la plateforme est en cours de
	# libération et toute interface qu'on lui redemanderait est déjà nulle.
	if _eos_shutting_down:
		return
	_retire_peer(peer)
	peer = null
	_eos_peer = null
	multiplayer.multiplayer_peer = null
	current_mode = GameMode.LOCAL_SPLITSCREEN
	lobby_code = ""
	eos_network_type = -1
	_connection_success_emitted = false
	_host_disconnected_emitted = false
	_leave_lobby_async()
	_reset_rtt()

# --- ENet --------------------------------------------------------------------

func _host_enet(port: int) -> bool:
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, MAX_CLIENTS)
	if err != OK:
		last_error = "Impossible d'ouvrir le port %d." % port
		push_error("NetworkManager: create_server failed — error %d" % err)
		connection_failed.emit()
		return false
	peer = enet
	multiplayer.multiplayer_peer = enet
	current_mode = GameMode.ONLINE_HOST
	_connect_signals()
	print("NetworkManager: hosting on port %d (ENet)" % port)
	return true

func _join_enet(address: String, port: int) -> bool:
	if address.is_empty():
		address = "127.0.0.1"
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(address, port)
	if err != OK:
		last_error = "Adresse invalide : %s" % address
		push_error("NetworkManager: create_client failed — error %d" % err)
		connection_failed.emit()
		return false
	peer = enet
	multiplayer.multiplayer_peer = enet
	current_mode = GameMode.ONLINE_CLIENT
	_connect_signals()
	print("NetworkManager: connecting to %s:%d (ENet)" % [address, port])
	return true

# --- EOS ---------------------------------------------------------------------

## Le socket P2P s'ouvre tout de suite : `multiplayer_peer` est en place au
## retour de l'appel, exactement comme en ENet, et la suite du jeu démarre la
## manche sans savoir qu'un salon se crée en tâche de fond. Seul le code de
## salon arrive plus tard, par `lobby_code_ready`.
func _host_eos() -> bool:
	if not _require_eos_ready():
		return false
	var p := EOSGMultiplayerPeer.new()
	_watch_eos_peer(p)
	p.set_auto_accept_connection_requests(true)
	var err = p.create_server(EOS_SOCKET_ID)
	if err != OK:
		last_error = "Impossible d'ouvrir le socket P2P."
		push_error("NetworkManager: EOS create_server failed — %s" % err)
		connection_failed.emit()
		return false
	_eos_peer = p
	peer = p
	multiplayer.multiplayer_peer = p
	current_mode = GameMode.ONLINE_HOST
	_connect_signals()
	print("NetworkManager: hosting (EOS), socket %s" % EOS_SOCKET_ID)
	_publish_lobby_async()
	return true

func _join_eos(raw_code: String) -> bool:
	if not _require_eos_ready():
		return false
	var code := LobbyCode.sanitize(raw_code)
	if not LobbyCode.is_valid(code):
		last_error = "Code incomplet : %d caractères sur %d." % [code.length(), LobbyCode.LENGTH]
		connection_failed.emit()
		return false
	# Le mode bascule avant l'attente : l'échéance de connexion posée par
	# l'appelant teste `current_mode`, et la recherche prend ~200 ms.
	current_mode = GameMode.ONLINE_CLIENT
	_join_eos_async(code)
	return true

## L'hôte cherche à ne publier qu'un code déjà trouvable, mais il y renonce
## après quelques tentatives et l'annonce quand même (« publié sans
## confirmation de l'index Epic »). Cette prémisse tombant, une recherche
## unique condamnait le client à échouer sur un code pourtant valide : on
## réessaie, l'index d'Epic mettant parfois plusieurs secondes à publier un
## salon tout juste créé.
func _join_eos_async(code: String) -> void:
	var results = null
	for attempt in EOS_JOIN_SEARCH_ATTEMPTS:
		results = await _search_code(code)
		if current_mode != GameMode.ONLINE_CLIENT:
			return # annulé pendant la recherche (retour au menu)
		if results != null and not results.is_empty():
			break
		if attempt < EOS_JOIN_SEARCH_ATTEMPTS - 1:
			await get_tree().create_timer(EOS_JOIN_SEARCH_DELAY).timeout
			if current_mode != GameMode.ONLINE_CLIENT:
				return

	if results == null:
		_fail_join("Recherche impossible : Epic ne répond pas.")
		return
	if results.is_empty():
		_fail_join("Aucun salon au code %s." % code)
		return

	var candidate = results[0]
	var lobby = await HLobbies.join_async(candidate)
	if current_mode != GameMode.ONLINE_CLIENT:
		return
	if not lobby:
		# Le message unique d'avant — « introuvable ou déjà complet » — couvrait
		# deux causes opposées et faisait croire à un salon plein alors que
		# l'hôte attendait. Les compter rend le défaut instruisible.
		var seen: int = candidate.members.size()
		var capacity: int = candidate.max_members
		if capacity > 0 and seen >= capacity:
			_fail_join("Le salon %s est complet (%d/%d)." % [code, seen, capacity])
		else:
			_fail_join("Epic a refusé l'entrée dans le salon %s. Réessaie dans quelques secondes." % code)
		return
	_eos_lobby = lobby
	lobby_code = code

	var host_puid: String = lobby.owner_product_user_id
	var p := EOSGMultiplayerPeer.new()
	_watch_eos_peer(p)
	var err = p.create_client(EOS_SOCKET_ID, host_puid)
	if err != OK:
		_fail_join("Connexion au salon refusée.")
		return
	_eos_peer = p
	peer = p
	multiplayer.multiplayer_peer = p
	_connect_signals()
	print("NetworkManager: joining (EOS) code %s, host puid %s" % [code, host_puid])

## Ferme un pair sans le détruire tout de suite.
##
## Le SDK d'Epic continue de rappeler ses callbacks sur le pair après sa
## fermeture. Or c'est justement l'un d'eux (connexion distante fermée) qui fait
## revenir le jeu au menu, donc appeler disconnect_from_game — et libérer le
## pair depuis l'intérieur du callback qui s'exécute dessus. Le SDK écrivait
## alors dans un objet détruit : segfault côté client dès que l'hôte quittait.
## Garder une référence le temps que le tick en cours se termine suffit.
func _retire_peer(p: MultiplayerPeer) -> void:
	if p == null:
		return
	p.close()
	_retired_peers.append(p)
	await get_tree().process_frame
	await get_tree().process_frame
	_retired_peers.erase(p)

func _fail_join(message: String) -> void:
	last_error = message
	push_warning("NetworkManager: %s" % message)
	current_mode = GameMode.LOCAL_SPLITSCREEN
	connection_failed.emit()

## Publie le code en attribut de salon. Un code déjà pris rendrait la recherche
## ambiguë des deux côtés : on retire au lieu de le garder.
## `preferred_code` sert à la reconstruction d'un salon : le code a déjà été
## communiqué à l'adversaire, le changer pour rien lui ferait perdre sa partie.
## Il n'est qu'une préférence — s'il est entretemps occupé, on en tire un autre.
func _publish_lobby_async(preferred_code := "") -> void:
	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = EOS_BUCKET_ID
	# Le 1v1 se ferme aussi ici : un troisième joueur n'atteint même pas le
	# salon, donc n'apprend jamais le PUID de l'hôte.
	opts.max_lobby_members = 2
	opts.presence_enabled = false
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.allow_invites = true

	var lobby = await HLobbies.create_lobby_async(opts)
	if lobby == null:
		last_error = "Création du salon refusée par Epic."
		push_warning("NetworkManager: EOS create_lobby failed")
		connection_failed.emit()
		return
	if current_mode != GameMode.ONLINE_HOST:
		# Retour au menu pendant la création : on ne laisse pas un salon fantôme.
		lobby.destroy_async()
		return
	_eos_lobby = lobby

	var code := ""
	for attempt in EOS_CODE_ATTEMPTS:
		code = preferred_code if attempt == 0 and not preferred_code.is_empty() \
			else LobbyCode.generate()
		lobby.add_attribute(EOS_CODE_ATTRIBUTE, code)
		await lobby.update_async()
		if current_mode != GameMode.ONLINE_HOST:
			lobby.destroy_async()
			return
		var owner := await _await_code_owner(code, lobby.lobby_id)
		if current_mode != GameMode.ONLINE_HOST:
			lobby.destroy_async()
			return
		if owner != CodeOwner.OTHER:
			# Trouvable et à nous, ou index muet : dans les deux cas on ne
			# retirera pas un meilleur numéro au tirage suivant.
			if owner == CodeOwner.UNKNOWN:
				push_warning("NetworkManager: code %s publié sans confirmation de l'index Epic" % code)
			break

	lobby_code = code
	print("NetworkManager: lobby code %s" % code)
	lobby_code_ready.emit(code)

enum CodeOwner { MINE, OTHER, UNKNOWN }

## Interroge l'index d'Epic jusqu'à ce qu'il rende NOTRE salon pour ce code.
##
## Deux choses se règlent d'un coup : la collision (l'index rend le salon de
## quelqu'un d'autre → il faut retirer un code) et la latence de propagation
## (l'index ne rend rien pendant quelques secondes → annoncer le code tout de
## suite ferait échouer un client trop rapide sur un code pourtant valide).
func _await_code_owner(code: String, my_lobby_id: String) -> CodeOwner:
	for attempt in EOS_CODE_VISIBLE_ATTEMPTS:
		var found = await _search_code(code)
		if current_mode != GameMode.ONLINE_HOST:
			return CodeOwner.UNKNOWN
		if found != null and not found.is_empty():
			for entry in found:
				if entry.lobby_id == my_lobby_id:
					return CodeOwner.MINE
			return CodeOwner.OTHER
	return CodeOwner.UNKNOWN

func _search_code(code: String):
	return await HLobbies.search_by_attribute_async([
		{ key = EOS.Lobby.SEARCH_BUCKET_ID, value = EOS_BUCKET_ID, comparison = EOS.ComparisonOp.Equal },
		{ key = EOS_CODE_ATTRIBUTE, value = code, comparison = EOS.ComparisonOp.Equal },
	])

## [Hôte] Reconstruit le salon après le départ d'un invité.
##
## L'adhésion à un salon EOS survit à la rupture du lien P2P : l'invité parti
## reste compté, le salon demeure à 2/2 et refuse pour de bon la jointure
## suivante — pendant que le jeu, lui, affiche « en attente du joueur 2 ».
## Le plugin n'expose aucune expulsion, on reconstruit donc, en gardant le code
## déjà communiqué pour que l'adversaire puisse revenir avec.
func _republish_lobby_async() -> void:
	if current_mode != GameMode.ONLINE_HOST or _eos_shutting_down:
		return
	var previous_code := lobby_code
	var lobby = _eos_lobby
	_eos_lobby = null
	if lobby != null:
		await lobby.destroy_async()
	# Le départ peut avoir été suivi d'un retour au menu : ne pas ressusciter
	# un salon que plus personne n'attend.
	if current_mode != GameMode.ONLINE_HOST or _eos_shutting_down:
		return
	await _publish_lobby_async(previous_code)

func _leave_lobby_async() -> void:
	var lobby = _eos_lobby
	_eos_lobby = null
	if lobby == null:
		return
	if lobby.is_owner():
		await lobby.destroy_async()
	else:
		await lobby.leave_async()

func _require_eos_ready() -> bool:
	if eos_state == EosState.READY:
		return true
	last_error = {
		EosState.INITIALIZING: "Connexion à Epic en cours, réessayez dans un instant.",
		EosState.FAILED: "Epic est injoignable. Basculez en LAN ou réessayez plus tard.",
	}.get(eos_state, "Epic n'est pas configuré sur cette installation.")
	connection_failed.emit()
	return false

## Les signaux propres au pair EOS : ils portent le type de lien (direct ou
## relayé) et servent de filet quand la MultiplayerAPI ne rapporte rien.
func _watch_eos_peer(p: EOSGMultiplayerPeer) -> void:
	p.peer_connection_established.connect(func(data):
		if typeof(data) == TYPE_DICTIONARY and data.has("network_type"):
			eos_network_type = data.network_type
	)
	p.peer_connection_closed.connect(func(_data):
		_on_eos_link_lost()
	)
	p.peer_connection_interrupted.connect(func(_data):
		push_warning("NetworkManager: lien EOS interrompu")
	)

func _on_eos_link_lost() -> void:
	if current_mode == GameMode.ONLINE_CLIENT:
		_emit_host_disconnected()

# ===========================================================================
# INITIALISATION EOS
# ===========================================================================

func _init_eos_async() -> void:
	# HPlatform et consorts sont déclarés après NetworkManager dans la liste des
	# autoloads : attendre une frame garantit que leur _ready est passé.
	await get_tree().process_frame

	# Trace conservée : un build exporté n'a pas de console, et c'est
	# précisément là que ce chemin a déjà échoué en silence.
	print("NetworkManager: init EOS — lecture de %s (exists=%s)" % [
		EOS_CREDENTIALS_PATH, ResourceLoader.exists(EOS_CREDENTIALS_PATH)])

	var creds := _load_credentials()
	if creds == null:
		_set_eos_state(EosState.UNCONFIGURED)
		print("NetworkManager: EOS non configuré (%s absent ou incomplet)" % EOS_CREDENTIALS_PATH)
		return

	_set_eos_state(EosState.INITIALIZING)
	HLog.log_level = HLog.LogLevel.INFO if _flag_present("--eos-verbose") else HLog.LogLevel.WARN

	if _eos_ephemeral:
		# Chaque instance jetable a son propre dossier de cache, sinon deux
		# processus se disputent les mêmes fichiers EOS sur la même machine.
		HPlatform.cache_directory = ProjectSettings.globalize_path(
			"user://eosg-cache-ephemeral-%d" % OS.get_process_id())

	if not await HPlatform.setup_eos_async(creds):
		_set_eos_state(EosState.FAILED)
		push_warning("NetworkManager: initialisation EOS en échec")
		return

	_eos_platform_created = true
	# Sans cette interception, l'arbre se termine avant que la plateforme EOS
	# soit relâchée — et le processus meurt sur un segfault (voir
	# _shutdown_eos_and_quit).
	get_tree().auto_accept_quit = false

	var logged_in := false
	if _eos_ephemeral:
		logged_in = await _login_ephemeral_async()
	else:
		logged_in = await _login_persistent_async()
	if not logged_in:
		_set_eos_state(EosState.FAILED)
		push_warning("NetworkManager: connexion Epic en échec")
		return

	eos_puid = HAuth.product_user_id
	_set_eos_state(EosState.READY)
	print("NetworkManager: EOS prêt (puid %s…%s)" % [eos_puid.substr(0, 4), eos_puid.right(4)])
	_query_nat_type_async()

## Identité durable : le Device ID doit survivre aux relances, sinon le joueur
## change de PUID à chaque lancement et perd tout ce qui y est rattaché.
## `HAuth.login_anonymous_async` est proscrit ici : il détruit puis recrée ce
## Device ID à chaque appel.
func _login_persistent_async() -> bool:
	var create_opts := EOS.Connect.CreateDeviceIdOptions.new()
	create_opts.device_model = " ".join(PackedStringArray([OS.get_name(), OS.get_model_name()]))
	EOS.Connect.ConnectInterface.create_device_id(create_opts)

	var ret: Dictionary = await IEOS.connect_interface_create_device_id_callback
	# DuplicateNotAllowed = un Device ID existe déjà : c'est le cas nominal dès
	# le deuxième lancement, surtout pas une erreur.
	if not EOS.is_success(ret) and ret.result_code != EOS.Result.DuplicateNotAllowed:
		push_warning("NetworkManager: create_device_id — %s" % EOS.result_str(ret.result_code))
		return false

	var opts := EOS.Connect.LoginOptions.new()
	opts.credentials = EOS.Connect.Credentials.new()
	opts.credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken
	opts.credentials.token = null
	opts.user_login_info = EOS.Connect.UserLoginInfo.new()
	opts.user_login_info.display_name = "Candela"
	# login_game_services_async traite lui-même InvalidUser en créant le produit
	# utilisateur via jeton de continuation (premier lancement).
	return await HAuth.login_game_services_async(opts)

## Identité jetable, réservée aux tests : le Device ID est lié à la MACHINE, si
## bien que deux instances locales partagent le même PUID et ne peuvent pas
## jouer l'une contre l'autre. Ce détruire-recréer casse ce lien — au prix de
## l'identité durable, d'où le verrouillage en build debug uniquement.
func _login_ephemeral_async() -> bool:
	push_warning("NetworkManager: identité EOS ÉPHÉMÈRE (mode test)")
	return await HAuth.login_anonymous_async("CandelaTest-%d" % Time.get_ticks_usec())

func _query_nat_type_async() -> void:
	eos_nat_type = await HP2P.get_nat_type_async()

func _set_eos_state(state: EosState) -> void:
	if eos_state == state:
		return
	eos_state = state
	eos_state_changed.emit(state)

## Le fichier d'identifiants n'est pas versionné : son absence doit dégrader le
## jeu vers « EOS non configuré », jamais le faire planter au démarrage.
func _load_credentials() -> HCredentials:
	if not ResourceLoader.exists(EOS_CREDENTIALS_PATH):
		return null
	var script: GDScript = load(EOS_CREDENTIALS_PATH)
	if script == null:
		return null
	var values: Dictionary = script.get_script_constant_map()
	const REQUIRED := ["PRODUCT_NAME", "PRODUCT_VERSION", "PRODUCT_ID", "SANDBOX_ID",
		"DEPLOYMENT_ID", "CLIENT_ID", "CLIENT_SECRET", "ENCRYPTION_KEY"]
	for key in REQUIRED:
		if not values.has(key) or String(values[key]).is_empty():
			push_warning("NetworkManager: %s incomplet (%s manquant)" % [EOS_CREDENTIALS_PATH, key])
			return null

	var creds := HCredentials.new()
	creds.product_name = values["PRODUCT_NAME"]
	creds.product_version = values["PRODUCT_VERSION"]
	creds.product_id = values["PRODUCT_ID"]
	creds.sandbox_id = values["SANDBOX_ID"]
	creds.deployment_id = values["DEPLOYMENT_ID"]
	creds.client_id = values["CLIENT_ID"]
	creds.client_secret = values["CLIENT_SECRET"]
	creds.encryption_key = values["ENCRYPTION_KEY"]
	return creds

# ===========================================================================
# ARRÊT PROPRE
# ===========================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

## Unique porte de sortie du jeu : relâcher la plateforme EOS avant de quitter
## est obligatoire, et ne peut pas se faire depuis n'importe où (voir
## _shutdown_eos).
func quit_game(exit_code: int = 0) -> void:
	if _eos_shutting_down:
		return
	_eos_shutting_down = true
	_shutdown_eos_and_quit(exit_code)

func _shutdown_eos_and_quit(exit_code: int) -> void:
	if not _eos_platform_created:
		get_tree().quit(exit_code)
		return
	# Le pair part en premier : sa fermeture pendant le release ferait remonter
	# des déconnexions dans le jeu, qui redemanderait EOS au pire moment. Il
	# reste référencé jusqu'à la fin du processus : le SDK peut encore le
	# rappeler pendant qu'on relâche la plateforme.
	if peer:
		peer.close()
		_retired_peers.append(peer)
	peer = null
	_eos_peer = null
	_eos_lobby = null
	multiplayer.multiplayer_peer = null
	# EOSGRuntime._process appelle IEOS.tick(), qui exécute EOS_Platform_Tick().
	# Les `await` sur les callbacks EOS reprennent SYNCHRONEMENT depuis
	# l'intérieur de ce tick natif : relâcher la plateforme ici reviendrait à
	# ré-entrer dans le SDK depuis sa propre pile d'appel — segfault immédiat.
	# Couper le tick puis laisser la frame se dérouler entièrement règle ça.
	EOSGRuntime.set_process(false)
	await get_tree().process_frame
	EOS.Platform.PlatformInterface.release()
	var res := EOS.Platform.PlatformInterface.shutdown()
	if not EOS.is_success(res):
		printerr("NetworkManager: shutdown EOS — ", EOS.result_str(res))
	get_tree().quit(exit_code)

# ===========================================================================
# PING APPLICATIF
# ===========================================================================

func _process(delta: float) -> void:
	var target := _remote_peer()
	if target == 0:
		_reset_rtt()
		return
	_ping_accum += delta
	if _ping_accum < PING_INTERVAL:
		return
	_ping_accum = 0.0
	rpc_id(target, "rpc_ping", Time.get_ticks_msec())

## Unique interlocuteur (1v1) : l'hôte pour le client, le client pour l'hôte.
func _remote_peer() -> int:
	if current_mode == GameMode.LOCAL_SPLITSCREEN or not multiplayer.has_multiplayer_peer():
		return 0
	var peers := multiplayer.get_peers()
	return peers[0] if peers.size() > 0 else 0

func _reset_rtt() -> void:
	rtt_ms = 0.0
	has_rtt = false
	_ping_accum = 0.0

## L'horodatage repart tel quel : seul l'émetteur l'interprète, aucune horloge
## commune n'est nécessaire.
@rpc("any_peer", "unreliable")
func rpc_ping(stamp: int) -> void:
	if multiplayer.get_remote_sender_id() != _remote_peer(): return
	rpc_id(multiplayer.get_remote_sender_id(), "rpc_pong", stamp)

## Le RTT nourrit la compensation de tir : seul l'écho de notre unique
## interlocuteur fait foi, et un horodatage forgé ne doit produire ni RTT
## négatif ni valeur aberrante.
@rpc("any_peer", "unreliable")
func rpc_pong(stamp: int) -> void:
	if multiplayer.get_remote_sender_id() != _remote_peer(): return
	var sample := clampf(float(Time.get_ticks_msec() - stamp), 0.0, 10_000.0)
	rtt_ms = sample if not has_rtt else lerpf(rtt_ms, sample, RTT_SMOOTHING)
	has_rtt = true

# ===========================================================================
# SIGNAUX MULTIPLAYERAPI
# ===========================================================================

func _connect_signals() -> void:
	# Avoid connecting multiple times
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		multiplayer.connection_failed.connect(_on_connection_failed)

func _on_peer_connected(id: int) -> void:
	if _eos_shutting_down:
		return
	print("NetworkManager: peer connected — id %d" % id)
	if peer is ENetMultiplayerPeer:
		var p = (peer as ENetMultiplayerPeer).get_peer(id)
		if p:
			p.set_timeout(0, 1500, 3000)
	elif _eos_peer != null and current_mode == GameMode.ONLINE_HOST:
		# Le salon est plein : les demandes suivantes restent en attente au lieu
		# d'entrer dans un 1v1 déjà commencé.
		_eos_peer.set_auto_accept_connection_requests(false)
	# Côté client, l'arrivée de l'hôte (id 1) vaut connexion établie : c'est le
	# seul évènement dont le pair EOS garantisse l'émission.
	if current_mode == GameMode.ONLINE_CLIENT and id == 1:
		_emit_connection_success()
	player_connected.emit(id)

## Fermer le jeu fait tomber le lien P2P, donc remonter ce signal jusqu'au jeu,
## qui rappellerait EOS pour quitter le salon — sur une plateforme déjà relâchée.
## Le garde d'arrêt coupe cette boucle.
func _on_peer_disconnected(id: int) -> void:
	if _eos_shutting_down:
		return
	print("NetworkManager: peer disconnected — id %d" % id)
	if _eos_peer != null and current_mode == GameMode.ONLINE_HOST:
		_eos_peer.set_auto_accept_connection_requests(true)
		_republish_lobby_async()
	if current_mode == GameMode.ONLINE_CLIENT and id == 1:
		_emit_host_disconnected()
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("NetworkManager: connected to server — my id is %d" % multiplayer.get_unique_id())
	_emit_connection_success()

func _on_connection_failed() -> void:
	push_error("NetworkManager: connection failed")
	if last_error.is_empty():
		last_error = "Salon injoignable."
	current_mode = GameMode.LOCAL_SPLITSCREEN
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("NetworkManager: server disconnected")
	_emit_host_disconnected()

func _emit_connection_success() -> void:
	if _connection_success_emitted or _eos_shutting_down:
		return
	_connection_success_emitted = true
	connection_success.emit()

func _emit_host_disconnected() -> void:
	if _host_disconnected_emitted or _eos_shutting_down or current_mode != GameMode.ONLINE_CLIENT:
		return
	_host_disconnected_emitted = true
	current_mode = GameMode.LOCAL_SPLITSCREEN
	host_disconnected.emit()

# ===========================================================================
# ARGUMENTS DE LIGNE DE COMMANDE
# ===========================================================================

func _flag_present(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args() or flag in OS.get_cmdline_args()

## Verrou de la Mission C : l'identité jetable est un outil de mise au point.
## `OS.is_debug_build()` est faux dans un export release, donc le drapeau y est
## purement et simplement ignoré — il ne peut pas s'armer chez un joueur.
func _ephemeral_requested() -> bool:
	if not _flag_present("--eos-ephemeral"):
		return false
	if not OS.is_debug_build():
		push_warning("NetworkManager: --eos-ephemeral ignoré hors build debug")
		return false
	return true
