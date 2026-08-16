extends Node
## Identité classée du joueur — le « qui est qui » du futur classement.
##
## Le PUID Epic seul ne prouve rien : n'importe qui pourrait en poster un. Le jeu
## joint donc à chaque appel le jeton signé par Epic
## (`EOS.Connect.ConnectInterface.copy_id_token`), qu'une Edge Function vérifie
## contre les clés publiques d'Epic avant d'écrire quoi que ce soit. Aucune
## écriture directe en base depuis ici : la clé publiable embarquée dans le jeu
## se heurte à une Row Level Security qui refuse tout.
##
## Cet autoload ne bloque jamais le menu. Il s'identifie en tâche de fond et
## expose son état exactement comme NetworkManager le fait pour EOS — non
## configuré / en cours / prêt / échec.
##
## **Sans `supabase_config.gd`, le jeu démarre et se joue normalement** : le
## classement reste « non configuré », et rien d'autre ne change.

const CONFIG_PATH := "res://supabase_config.gd"
const FUNCTIONS_PATH := "/functions/v1/"

const ENDPOINT_IDENTIFY := "identify"
const ENDPOINT_LINK := "link"
const ENDPOINT_REPORT := "report"

## Reprises d'un rapport de match. Le classement ne vaut pas de faire attendre
## le joueur, mais un résultat perdu sur un hoquet de réseau est un match
## effacé : trois tentatives espacées valent mieux qu'une.
##
## Le filet de sécurité reste `user://match_history.json`, écrit avant tout
## envoi : ce qui n'atteint pas le serveur n'est pas perdu pour autant, et une
## étape ultérieure pourra rejouer le journal.
const REPORT_ATTEMPTS := 3
const REPORT_RETRY_DELAY := 4.0

## Une Edge Function froide met quelques secondes à démarrer ; au-delà, c'est
## qu'elle ne répondra pas.
const REQUEST_TIMEOUT := 20.0

## Échéance d'attente d'EOS. NetworkManager n'émet aucun signal s'il reste
## « non configuré » — c'est son état initial, et changer d'état est ce qui
## déclenche l'émission. Sans cette échéance, l'identification attendrait pour
## toujours un signal qui ne viendra jamais.
const EOS_WAIT_TIMEOUT := 45.0

## Mêmes états que ceux d'EOS, et pour la même raison : l'UI n'a qu'une seule
## grammaire à connaître.
enum State { UNCONFIGURED, INITIALIZING, READY, FAILED }
var state: State = State.UNCONFIGURED

var profile_id: String = ""
var nickname: String = ""
## Forme canonique, sans séparateur. L'affichage passe par RecoveryCode.format().
var recovery_code: String = ""
## Dernier échec en clair, à afficher par l'UI. Vidé à chaque nouvelle tentative.
var last_error: String = ""

signal state_changed(state: State)
## Issue d'un rattachement demandé par le joueur, avec le message à lui montrer.
signal link_completed(success: bool, message: String)

var _project_url: String = ""
var _publishable_key: String = ""
var _http: HTTPRequest
## Appel en cours (ENDPOINT_*), vide sinon. Un seul à la fois : les deux chemins
## ne se croisent pas, l'UI n'ouvrant le rattachement qu'une fois l'état connu.
var _pending: String = ""
var _waiting_for_eos: bool = false
## Rapports de match à envoyer, dans l'ordre. Un seul part à la fois : le
## transport n'accepte qu'une requête, et rien ici ne presse.
var _report_queue: Array[Dictionary] = []
var _report_attempts: int = 0

# ===========================================================================
# CYCLE DE VIE
# ===========================================================================

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)

	if _flag_present("--no-supabase"):
		return
	# Les suites de tests tournent en headless. S'y identifier créerait un profil
	# de plus dans la vraie base à chaque exécution, et ferait dépendre des tests
	# hors-ligne d'un service distant.
	if DisplayServer.get_name() == "headless":
		return
	if not _load_config():
		print("RankedIdentity: classement non configuré (%s absent ou incomplet)" % CONFIG_PATH)
		return
	_start_when_eos_ready()

func state_label() -> String:
	match state:
		State.INITIALIZING: return "Classement : identification…"
		State.READY: return "Classement : %s" % nickname
		State.FAILED: return "Classement : indisponible"
		_: return "Classement : non configuré"

func is_ready() -> bool:
	return state == State.READY

# ===========================================================================
# IDENTIFICATION
# ===========================================================================

## L'identité classée s'appuie sur celle d'Epic : sans PUID, rien à prouver.
func _start_when_eos_ready() -> void:
	_set_state(State.INITIALIZING)

	match NetworkManager.eos_state:
		NetworkManager.EosState.READY:
			_identify()
			return
		NetworkManager.EosState.FAILED:
			_fail("Epic est injoignable : le classement attend une identité Epic.")
			return

	_waiting_for_eos = true
	NetworkManager.eos_state_changed.connect(_on_eos_state_changed)
	get_tree().create_timer(EOS_WAIT_TIMEOUT).timeout.connect(_on_eos_wait_expired)

func _on_eos_state_changed(eos_state: int) -> void:
	if not _waiting_for_eos:
		return
	match eos_state:
		NetworkManager.EosState.READY:
			_waiting_for_eos = false
			_identify()
		NetworkManager.EosState.FAILED:
			_waiting_for_eos = false
			_fail("Epic est injoignable : le classement attend une identité Epic.")

func _on_eos_wait_expired() -> void:
	if not _waiting_for_eos:
		return
	_waiting_for_eos = false
	_fail("%s — le classement attend une identité Epic." % NetworkManager.eos_state_label())

func _identify() -> void:
	var token := _copy_id_token()
	if token.is_empty():
		_fail("Epic n'a pas délivré de jeton d'identité.")
		return
	if not _post(ENDPOINT_IDENTIFY, {"id_token": token}):
		_fail("Requête d'identification impossible.")

## Rattache cette machine à un profil existant, sur présentation du code.
##
## Le code seul ne suffit pas : la fonction distante exige aussi un jeton Epic
## valide. Rend faux si la demande n'a même pas pu partir ; l'issue réelle arrive
## par `link_completed`.
func link(raw_code: String) -> bool:
	var code := RecoveryCode.sanitize(raw_code)
	if not RecoveryCode.is_valid(code):
		link_completed.emit(false, "Code incomplet : %d caractères sur %d."
			% [code.length(), RecoveryCode.LENGTH])
		return false
	if state == State.UNCONFIGURED:
		link_completed.emit(false, "Classement non configuré sur cette installation.")
		return false
	if _pending != "":
		link_completed.emit(false, "Une demande est déjà en cours.")
		return false

	var token := _copy_id_token()
	if token.is_empty():
		link_completed.emit(false, "Epic n'a pas délivré de jeton d'identité.")
		return false
	if not _post(ENDPOINT_LINK, {"id_token": token, "recovery_code": code}):
		link_completed.emit(false, "Requête de rattachement impossible.")
		return false
	return true

## Dépose le résultat d'un match. Ne bloque jamais, n'échoue jamais bruyamment :
## le journal local a déjà été écrit, et c'est lui qui fait foi.
##
## `outcome` ne parle que du joueur local — « win », « loss » ou « draw ». Le
## sort de l'adversaire ne se déclare pas : le serveur l'apprendra de son propre
## rapport, et confrontera les deux.
func report_match(match_id: String, outcome: String, data: Dictionary) -> void:
	if state != State.READY or match_id.is_empty():
		return
	var payload := data.duplicate()
	payload["match_id"] = match_id
	payload["outcome"] = outcome
	_report_queue.append(payload)
	_drain_reports()

## Envoie le rapport en tête de file, s'il y en a un et que la voie est libre.
func _drain_reports() -> void:
	if _pending != "" or _report_queue.is_empty():
		return
	var token := _copy_id_token()
	if token.is_empty():
		# Sans jeton, rien ne partira : inutile d'user les tentatives.
		push_warning("RankedIdentity: rapport de match abandonné, jeton Epic indisponible")
		_report_queue.clear()
		_report_attempts = 0
		return
	var payload: Dictionary = _report_queue[0].duplicate()
	payload["id_token"] = token
	if not _post(ENDPOINT_REPORT, payload):
		_retry_or_drop("requête impossible")

## Un envoi a échoué : on réessaie, puis on renonce en le disant.
func _retry_or_drop(reason: String) -> void:
	_report_attempts += 1
	if _report_attempts < REPORT_ATTEMPTS:
		get_tree().create_timer(REPORT_RETRY_DELAY).timeout.connect(_drain_reports)
		return
	push_warning("RankedIdentity: rapport de match perdu après %d tentatives — %s"
		% [REPORT_ATTEMPTS, reason])
	_report_queue.pop_front()
	_report_attempts = 0
	_drain_reports()

## Jeton d'identité signé par Epic, à joindre à chaque appel.
##
## Il est redemandé à chaque fois plutôt que gardé : il expire, et le coût de
## l'appel est nul comparé à celui d'un rattachement refusé pour péremption.
func _copy_id_token() -> String:
	if NetworkManager.eos_state != NetworkManager.EosState.READY:
		return ""
	var opts := EOS.Connect.CopyIdTokenOptions.new()
	opts.local_user_id = NetworkManager.eos_puid
	var ret: Variant = EOS.Connect.ConnectInterface.copy_id_token(opts)
	if typeof(ret) != TYPE_DICTIONARY or not (ret as Dictionary).has("result_code"):
		push_warning("RankedIdentity: copy_id_token n'a rien rendu d'exploitable")
		return ""
	if not EOS.is_success(ret):
		push_warning("RankedIdentity: copy_id_token — %s" % EOS.result_str(ret))
		return ""
	# Le SDK enveloppe le jeton dans une structure IdToken ; le repli couvre une
	# version du plugin qui l'aplatirait.
	var wrapper: Variant = (ret as Dictionary).get("id_token", null)
	if wrapper is Dictionary:
		return String((wrapper as Dictionary).get("json_web_token", ""))
	return String((ret as Dictionary).get("json_web_token", ""))

# ===========================================================================
# TRANSPORT HTTP
# ===========================================================================

func _post(endpoint: String, payload: Dictionary) -> bool:
	if _pending != "":
		return false
	var headers := PackedStringArray([
		"Content-Type: application/json",
		# La clé publiable est faite pour vivre dans le client : ce qui protège
		# les tables, c'est la RLS, pas le secret de cette clé.
		"apikey: %s" % _publishable_key,
		"Authorization: Bearer %s" % _publishable_key,
	])
	last_error = ""
	var err := _http.request(_project_url + FUNCTIONS_PATH + endpoint, headers,
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		push_warning("RankedIdentity: requête %s impossible — erreur %d" % [endpoint, err])
		return false
	_pending = endpoint
	return true

func _on_request_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	var endpoint := _pending
	_pending = ""
	if endpoint.is_empty():
		return

	if endpoint == ENDPOINT_REPORT:
		_on_report_completed(result, code, _parse(body))
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_report(endpoint, false, "Serveur du classement injoignable.")
		return

	var payload := _parse(body)
	if code != 200:
		# Nos deux fonctions rendent toujours `raison` ET `message`, ce dernier
		# déjà rédigé pour le joueur : on ne le reformule pas, sous peine de
		# perdre la cause exacte du refus. Une réponse SANS `raison` vient de la
		# passerelle Supabase et non de nous — « Requested function was not
		# found » n'apprendrait rien à personne.
		var message := String(payload.get("message", ""))
		var ours := payload.has("raison") and not message.is_empty()
		if not ours:
			push_warning("RankedIdentity: %s a répondu %d — %s" % [endpoint, code, message])
		_report(endpoint, false, message if ours
			else "Le classement a refusé la demande (code %d)." % code)
		return

	var profile: Variant = payload.get("profile", null)
	# Un profil sans identifiant utilisable n'en est pas un. Le contrôle a servi :
	# une réponse d'objet vide, prise pour un profil valide, faisait afficher un
	# rattachement réussi là où le code était inconnu.
	if not profile is Dictionary or String((profile as Dictionary).get("id", "")).is_empty():
		_report(endpoint, false, "Réponse du classement illisible.")
		return

	_adopt(profile as Dictionary)
	_report(endpoint, true, "Profil %s rattaché à cette machine." % nickname)

## Issue d'un rapport de match. Rien n'est montré au joueur : le classement se
## tient à jour tout seul, et le journal local a déjà enregistré le match.
func _on_report_completed(result: int, code: int, payload: Dictionary) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_report_queue.pop_front()
		_report_attempts = 0
		_drain_reports()
		return

	# 4xx : le serveur a compris et refuse. Réessayer ne changera rien — un
	# rapport malformé le restera, et un match déjà complet aussi.
	if result == HTTPRequest.RESULT_SUCCESS and code >= 400 and code < 500:
		push_warning("RankedIdentity: rapport de match refusé (%d) — %s"
			% [code, String(payload.get("raison", "sans raison"))])
		_report_queue.pop_front()
		_report_attempts = 0
		_drain_reports()
		return

	_retry_or_drop("code %d" % code if result == HTTPRequest.RESULT_SUCCESS
		else "transport %d" % result)

func _adopt(profile: Dictionary) -> void:
	profile_id = String(profile.get("id", ""))
	nickname = String(profile.get("nickname", ""))
	recovery_code = String(profile.get("recovery_code", ""))
	last_error = ""
	_set_state(State.READY)

func _report(endpoint: String, success: bool, message: String) -> void:
	if endpoint == ENDPOINT_LINK:
		if not success:
			# Un rattachement raté ne détruit pas l'identité déjà obtenue : le
			# joueur reste sur son profil courant, avec le code qu'il connaît.
			last_error = message
			push_warning("RankedIdentity: rattachement refusé — %s" % message)
		link_completed.emit(success, message)
		return
	if success:
		print("RankedIdentity: profil %s prêt" % nickname)
	else:
		_fail(message)

func _parse(body: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}

func _fail(message: String) -> void:
	last_error = message
	push_warning("RankedIdentity: %s" % message)
	_set_state(State.FAILED)

func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(next)

# ===========================================================================
# CONFIGURATION
# ===========================================================================

## Le fichier de configuration n'est pas versionné : son absence doit dégrader le
## classement vers « non configuré », jamais empêcher le jeu de démarrer.
func _load_config() -> bool:
	if not ResourceLoader.exists(CONFIG_PATH):
		return false
	var script: GDScript = load(CONFIG_PATH)
	if script == null:
		return false
	var values: Dictionary = script.get_script_constant_map()
	for key in ["PROJECT_URL", "PUBLISHABLE_KEY"]:
		if not values.has(key) or String(values[key]).is_empty():
			push_warning("RankedIdentity: %s incomplet (%s manquant)" % [CONFIG_PATH, key])
			return false
	# Une barre oblique finale recopiée du tableau de bord donnerait une URL à
	# double barre, que la passerelle Supabase rejette.
	_project_url = String(values["PROJECT_URL"]).rstrip("/")
	_publishable_key = String(values["PUBLISHABLE_KEY"])
	return true

func _flag_present(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args() or flag in OS.get_cmdline_args()
