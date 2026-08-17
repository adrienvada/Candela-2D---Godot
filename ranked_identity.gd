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
const ENDPOINT_STANDING := "standing"

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

## Classement du joueur, tel que le serveur le rend. Vide tant qu'aucun match
## concordant ne le concerne : s'identifier ne suffit pas, il faut avoir joué.
var rating: int = 0
var rank: int = 0
var matches_played: int = 0
var wins: int = 0
var losses: int = 0
var draws: int = 0
var is_ranked: bool = false

## Ce que la dernière lecture du classement a rendu au-delà de ma propre ligne.
##
## `_standing_loaded` n'est pas redondant avec un tableau vide : sans lui,
## « personne n'a encore joué » et « la lecture n'a jamais abouti » sont
## indistinguables, et un écran resterait sur « Lecture… » pour toujours après un
## échec. C'est le genre de défaut qui ne se voit qu'avec un réseau coupé.
var _standing_top: Array = []
var _standing_loaded: bool = false
var _standing_error: String = ""

## Nature du prochain match rapporté. **Amical par défaut** : un oubli de
## déclaration ne doit jamais ajouter un match au classement.
var _ranked_context: bool = false

signal state_changed(state: State)
## Émis quand le classement du joueur a été relu.
signal standing_changed

## Le profil lui-même a changé : pseudo, code de récupération, identifiant.
## Distinct de `state_changed`, qui ne dit que le passage d'un état à l'autre —
## un rattachement réussi change tout le profil sans changer l'état.
signal profile_changed
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
	# La nature du match voyage avec le rapport, et le serveur ne compte que ce qui
	# est déclaré classé — un match amical qui alimenterait le classement serait
	# impossible à démêler après coup, faute d'avoir été écrit.
	payload["ranked"] = _ranked_context
	_report_queue.append(payload)
	_drain_reports()

## Déclare la nature du prochain match rapporté : classé ou amical.
##
## **Le menu décide, pas le jeu.** C'est en entrant dans « en ligne compétitif »
## ou dans un salon amical que la nature est choisie ; `game_state.gd` ne fait que
## rapporter une issue et n'a pas à connaître cette distinction. Poser l'intention
## ici évite aussi de faire dépendre le rapport d'un état d'interface — la même
## erreur que celle corrigée à l'étape 3b sur le mode réseau.
##
## Le défaut est **amical**, et ce sens-là n'est pas arbitraire : un oubli de
## déclaration ne doit jamais *ajouter* un match au classement. L'inverse se
## rattrape par un rejeu de l'historique, celui-là non.
func set_ranked_context(ranked: bool) -> void:
	_ranked_context = ranked

## Relit le classement du joueur. Sans effet si rien n'est prêt ; l'issue arrive
## par `standing_changed`.
##
## Appelé après l'identification et après chaque rapport de match : ce sont les
## deux seuls moments où il peut avoir bougé.
func refresh_standing() -> void:
	if state != State.READY or _pending != "":
		return
	var token := _copy_id_token()
	if token.is_empty():
		return
	_post(ENDPOINT_STANDING, {"id_token": token})

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

## Retire le rapport en tête et le clôt dans le journal local : il n'y a plus
## rien à en attendre, que le serveur ait accusé réception ou refusé.
func _settle_front() -> void:
	if _report_queue.is_empty():
		return
	var done: Dictionary = _report_queue.pop_front()
	_report_attempts = 0
	MatchRecord.mark_reported(String(done.get("match_id", "")))

## Renvoie les matchs classés que le serveur n'a jamais accusé réception.
##
## Trois chemins les perdaient définitivement, tous silencieux : identité pas
## encore prête au moment du rapport (`report_match` sort sans rien faire), jeton
## Epic indisponible (`_drain_reports` **vide la file entière**), et trois échecs
## réseau d'affilée. Le match était pourtant archivé — il ne manquait que le
## renvoi, et le classement avait des trous que personne ne pouvait voir.
##
## Le rejeu est sûr parce que le serveur est idempotent par construction : un
## match déjà complet est refusé en 4xx, et un 4xx clôt l'enregistrement. Un
## rapport de trop ne coûte donc qu'un aller-retour, là où un rapport manquant
## fausse un classement pour toujours.
##
## La nature classée vient de l'**enregistrement**, jamais de `_ranked_context` :
## celui-ci décrit le match qu'on s'apprête à jouer, pas celui qu'on rejoue.
func replay_local_journal() -> int:
	if state != State.READY:
		return 0
	var en_attente := MatchRecord.pending_reports(MatchRecord.load_history())
	if en_attente.is_empty():
		return 0
	var deja := {}
	for p in _report_queue:
		deja[String((p as Dictionary).get("match_id", ""))] = true
	var repris := 0
	for entry in en_attente:
		var e: Dictionary = entry
		var id := String(e["match_id"])
		if deja.has(id):
			continue
		_report_queue.append({
			"match_id": id,
			"outcome": String(e["issue"]),
			"ranked": true,
			"forfeit": bool(e.get("forfait", false)),
			"duree": float(e.get("duree", 0.0)),
		})
		repris += 1
	if repris > 0:
		print("RankedIdentity: %d match(s) du journal local remis en file" % repris)
		_drain_reports()
	return repris

## Un envoi a échoué : on réessaie, puis on renonce en le disant.
func _retry_or_drop(reason: String) -> void:
	_report_attempts += 1
	if _report_attempts < REPORT_ATTEMPTS:
		get_tree().create_timer(REPORT_RETRY_DELAY).timeout.connect(_drain_reports)
		return
	push_warning("RankedIdentity: rapport de match perdu après %d tentatives — %s"
		% [REPORT_ATTEMPTS, reason])
	# `pop_front()` et **surtout pas** `_settle_front()` : c'est toute la
	# dissymétrie du dispositif. Le serveur a répondu — accusé ou refus — le match
	# est clos ; le réseau a échoué — il ne sait rien de ce match, l'enregistrement
	# reste ouvert et `replay_local_journal()` le reprendra au prochain démarrage.
	# Le clore ici perdrait définitivement ce que l'étape entière cherche à sauver.
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

	if endpoint == ENDPOINT_STANDING:
		_on_standing_completed(result, code, _parse(body))
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
		_settle_front()
		_drain_reports()
		# Le match vient peut-être de régler le classement : on le relit, mais
		# seulement une fois la file vidée, pour ne pas se couper la parole.
		if _report_queue.is_empty():
			refresh_standing()
		return

	# 4xx : le serveur a compris et refuse. Réessayer ne changera rien — un
	# rapport malformé le restera, et un match déjà complet aussi.
	if result == HTTPRequest.RESULT_SUCCESS and code >= 400 and code < 500:
		push_warning("RankedIdentity: rapport de match refusé (%d) — %s"
			% [code, String(payload.get("raison", "sans raison"))])
		# Refus définitif : le serveur a compris et tranché. Le match est clos dans
		# le journal au même titre qu'un accusé de réception — sans quoi le rejeu
		# le représenterait à chaque démarrage, indéfiniment.
		_settle_front()
		_drain_reports()
		return

	_retry_or_drop("code %d" % code if result == HTTPRequest.RESULT_SUCCESS
		else "transport %d" % result)

## Issue d'une relecture du classement. Un échec est silencieux : le classement
## est un ornement du menu, pas une condition pour jouer.
func _on_standing_completed(result: int, code: int, payload: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("RankedIdentity: classement illisible (code %d)" % code)
		# L'échec doit être annoncé, pas seulement journalisé : sans ce signal, un
		# écran branché ici reste sur « Lecture… » indéfiniment. Le classement
		# reste un ornement du menu — l'échec n'empêche pas de jouer, il doit
		# seulement cesser de se faire attendre.
		_standing_error = "classement illisible (code %d)" % code
		standing_changed.emit()
		return

	_standing_error = ""
	_standing_loaded = true
	_standing_top = _flatten_tiers(payload.get("top", []))

	var mine: Variant = payload.get("standing", null)
	if not mine is Dictionary:
		# Profil connu mais jamais classé : aucun match concordant à son nom.
		is_ranked = false
		standing_changed.emit()
		return
	var d: Dictionary = mine
	rating = int(d.get("rating", 0))
	rank = int(d.get("rank", 0))
	matches_played = int(d.get("matches", 0))
	wins = int(d.get("wins", 0))
	losses = int(d.get("losses", 0))
	draws = int(d.get("draws", 0))
	is_ranked = true
	standing_changed.emit()

## Aplatit la catégorie que le serveur rend sous forme d'objet.
##
## Le serveur expose `tier` (catégorie, division, libellé, points au rang
## suivant) parce que ces informations serviront ; l'affichage n'a besoin que du
## libellé. L'aplatissement se fait **ici** et nulle part ailleurs : c'est la
## couche qui adapte le serveur à l'interface, et la faire dans chaque écran
## garantirait qu'un écran finisse par lire une clé qui n'existe plus.
func _flatten_tiers(rows: Variant) -> Array:
	var out: Array = []
	if not rows is Array:
		return out
	for row in rows:
		if not row is Dictionary:
			continue
		var d: Dictionary = (row as Dictionary).duplicate()
		var tier: Variant = d.get("tier", null)
		if tier is Dictionary:
			d["rank_label"] = String((tier as Dictionary).get("label", ""))
		out.append(d)
	return out

## Ce que la dernière lecture du classement a rendu au-delà de ma propre ligne.
##
## Une méthode plutôt que trois propriétés : un seul point à sonder pour un écran,
## un seul à simuler dans un test.
func standing_snapshot() -> Dictionary:
	return {
		"loaded": _standing_loaded,
		"error": _standing_error,
		"top": _standing_top.duplicate(true),
	}

## Résumé du classement, pour le menu.
func standing_label() -> String:
	if state != State.READY:
		return ""
	if not is_ranked:
		return "Pas encore classé — jouez un match en ligne"
	return "%d points · %de · %d match%s (%dV %dD %dN)" % [
		rating, rank, matches_played, "s" if matches_played > 1 else "",
		wins, losses, draws]

## Adopte un profil : identification initiale, ou rattachement d'une machine.
##
## `profile_changed` est émis **inconditionnellement**, et c'est le point à ne pas
## simplifier. Un rattachement réussi appelle `_set_state(READY)` sur une identité
## déjà READY ; `_set_state` sort alors sans rien émettre, puisque l'état n'a pas
## bougé. Or le pseudo et le code, eux, viennent de changer. Un écran branché sur
## le seul `state_changed` continuerait d'afficher le code d'un profil que la
## machine vient d'abandonner — un code périmé, présenté comme la seule chose que
## le joueur ait à conserver.
func _adopt(profile: Dictionary) -> void:
	profile_id = String(profile.get("id", ""))
	nickname = String(profile.get("nickname", ""))
	recovery_code = String(profile.get("recovery_code", ""))
	last_error = ""
	_set_state(State.READY)
	# L'identité vient d'être acceptée : c'est le premier instant où un rapport
	# peut partir, donc le bon moment pour rattraper ceux qui ne sont jamais
	# partis. Après `_set_state`, sans quoi `replay_local_journal()` sortirait sur
	# son propre garde-fou.
	replay_local_journal()
	profile_changed.emit()

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
		refresh_standing()
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
