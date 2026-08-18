## Appariement automatique — Phase 8, étapes 8.2 à 8.5.
##
## La file d'attente vit dans les salons EOS, pas dans une base : un joueur en
## attente publie un **ticket** — un salon portant son classement en attribut —
## et le chercheur filtre dessus. Aucun service de plus à héberger, et la
## traversée de NAT est déjà résolue par ce mécanisme (arbitrage de l'étape 8.2).
##
## Ce fichier ne connaît PAS le transport. Tout ce qui touche à Epic passe par
## une poignée de primitives de file portées par `network_manager.gd` — le
## « backend » décrit ci-dessous. C'est la même contrainte que partout ailleurs
## dans le dépôt, et c'est aussi ce qui rend la machine à états exerçable en
## headless : la suite de tests lui substitue un faux backend et pilote
## l'horloge (`autotick = false` puis `tick(dt)`), là où EOS est injoignable.
##
## Contrat du backend, dans le vocabulaire du jeu et non celui d'Epic :
##   matchmaking_supported() -> bool
##   local_identity_key() -> String
##   queue_publish_async(mode_tag: String, rating: int, commitment: String,
##                        tier: int) -> bool
##   queue_search_async(mode_tag: String, min_rating: int, max_rating: int) -> Array
##   queue_join_async(id: String) -> bool
##   queue_declare_async(state: Dictionary) -> bool
##   queue_close_async() -> void
##   host_matched_game() -> bool
##   join_matched_game(host_key: String) -> bool
##   signal queue_peer_state_changed(state: Dictionary)
##   signal queue_ticket_lost()
##
## Un candidat rendu par `queue_search_async` porte les clés `id`, `key`,
## `rating` et `commitment`. L'état d'un pair porte `key`, `nonce`, `rating` et
## `accepted` — vide quand l'autre a quitté le rendez-vous.
class_name Matchmaking
extends Node

## Lisible de l'extérieur : l'écran ne fait que lire et afficher.
##
## Un rendez-vous engagé mais encore incomplet — on sait avec qui, pas encore
## qui héberge — reste `SEARCHING`. Annoncer « match trouvé » avant que le
## tirage de l'hôte soit calculable obligerait à corriger l'affichage une
## seconde plus tard, et c'est précisément l'information que le joueur attend.
enum State { IDLE, SEARCHING, FOUND, AWAITING_ACCEPT, FAILED }

## L'appariement classé filtre sur la fourchette de classement, l'amical non.
## Les deux files sont étanches : un joueur ne peut pas tomber en amical sur
## quelqu'un qui cherche un match classé, et réciproquement.
enum Mode { CASUAL, RANKED }

const QUEUE_TAGS := { Mode.CASUAL: "CASUAL", Mode.RANKED: "RANKED" }

## Demi-largeur qui signifie « aucune borne ».
const OPEN := -1

## Paliers d'élargissement, en points de classement autour du sien.
##
## Les valeurs viennent de l'échelle réelle (`supabase/functions/_shared/elo.ts`) :
## une division vaut 40 points, une catégorie en compte trois — 120 points — et
## la bande active va de 700 à 1780. D'où :
##   ±60  : une demi-catégorie, le voisinage immédiat, le match le plus juste ;
##   ±120 : une catégorie de part et d'autre ;
##   ±240 : deux catégories, on sent la différence sans que ce soit perdu ;
##   ±480 : quatre catégories, match déséquilibré mais encore jouable ;
##   OPEN : plus aucun filtre.
##
## Le dernier palier est le point laissé à l'arbitrage d'Adrien par l'étape 8.5
## (« y a-t-il un plafond au-delà duquel on refuse d'apparier ? »). Il est ouvert
## par défaut parce qu'avec la population réelle du jeu, ne pas jouer est un pire
## match que jouer contre plus fort — et le remplacer par une borne ne coûte
## qu'une valeur dans cette table.
const WIDENING := [
	{ after = 0.0, half_width = 60 },
	{ after = 15.0, half_width = 120 },
	{ after = 35.0, half_width = 240 },
	{ after = 60.0, half_width = 480 },
	{ after = 90.0, half_width = OPEN },
]

## Classement prêté à un joueur qui n'en a pas encore, POUR PUBLICATION SEULE :
## c'est la valeur de départ de l'ELO (`START_RATING` dans `elo.ts`), donc le
## seul a priori que le système possède. Il ne doit jamais être affiché comme un
## rang — un joueur sans ligne au classement n'a pas de catégorie (Phase 6).
const UNRATED_PRIOR := 1000

## Une recherche EOS infructueuse coûte déjà ~3 s : la cadence utile est celle du
## repos entre deux passes, pas celle des passes elles-mêmes.
const SWEEP_INTERVAL := 2.0

## Du moment où deux joueurs se rencontrent à celui où l'appariement est complet.
## Purement réseau, aucun humain dans la boucle : deux écritures d'attribut et
## leur propagation.
const RENDEZVOUS_TIMEOUT := 8.0

## Puis de l'annonce à la double acceptation. Un humain doit lire l'écran et
## appuyer. C'est l'échéance qui traite le cas « il accepte puis ferme le jeu » :
## on n'attend jamais un signal qui ne viendra pas.
const ACCEPT_TIMEOUT := 15.0

## Un adversaire qui vient d'échouer la poignée de main ne doit pas être
## reproposé tout de suite : son salon survit à sa fermeture du jeu, et sans ce
## délai de garde la recherche le retrouverait toutes les deux secondes, pour
## toujours.
const CANDIDATE_COOLDOWN := 45.0

const NONCE_BYTES := 16

## Recul avant de republier un ticket, après un échec.
##
## Sans lui, un échec enchaîne immédiatement : `queue_join_async` **détruit notre
## propre ticket avant** de tenter la jointure — pour qu'un troisième joueur ne
## s'installe pas pendant la négociation — si bien qu'une jointure qui expire nous
## laisse sans ticket. Le ticket perdu déclenche une republication, qui relance
## une recherche, qui retente une jointure. Chaque tour détruit et crée un salon
## chez Epic.
##
## Observé à deux fenêtres le 2026-08-18 : cinq tickets publiés d'un côté, trois
## de l'autre, puis `create_lobby: TimedOut`, `join_lobby: TimedOut` et
## `search_for_lobbies: NoConnection`. Epic cesse de suivre bien avant que le jeu
## s'en aperçoive.
##
## Le recul double à chaque échec consécutif et se remet à zéro dès qu'un ticket
## tient. Il **suspend la recherche** au lieu de la faire tourner à vide : mieux
## vaut deux secondes d'attente annoncée qu'un service qui se ferme.
const REPUBLISH_BACKOFF := 2.0
const REPUBLISH_BACKOFF_MAX := 16.0

signal state_changed(state: State)
## Fourchette cherchée à l'instant : une recherche qui ne dit pas ce qu'elle
## cherche paraît cassée au bout de vingt secondes.
signal range_changed(step: int, low: int, high: int)
## Appariement complet : les deux identités sont connues et l'hôte est désigné.
signal match_found(pairing: Dictionary)
## Refus ou expiration. L'appelant n'a rien à faire : on est déjà retourné en
## file, et le tour n'est pas perdu.
signal handshake_failed(reason: String)
## Les deux ont accepté ; le lien est lancé. La suite est l'affaire ordinaire de
## `connection_success` / `connection_failed` du gestionnaire de réseau.
signal match_ready(pairing: Dictionary)
signal search_failed(reason: String)

var state: State = State.IDLE
var last_error: String = ""

## Vrai : la double acceptation est automatique dès l'appariement complet.
## Faux : l'écran doit appeler `accept()` ou `refuse()` avant l'échéance.
var auto_accept: bool = false

## Faux : l'horloge est pilotée de l'extérieur par `tick(delta)` (bancs d'essai).
var autotick: bool = true

## Objet portant le contrat de file. Renseigné au `_ready` avec le gestionnaire
## de réseau, remplaçable avant pour les tests.
var backend: Object = null

var _mode: Mode = Mode.CASUAL
var _rating: int = UNRATED_PRIOR
var _rating_known: bool = false
## Ma catégorie de rang, telle que le SERVEUR l'a rendue. Elle voyage dans le
## ticket et dans l'état de membre : la règle du miroir a besoin de celle des DEUX
## camps, et le jeu ne sait pas la dériver d'un classement — `rankOf` vit dans
## `elo.ts`, par une décision actée pour que l'échelle n'ait qu'un propriétaire.
var _tier: int = 0
var _elapsed: float = 0.0
var _step: int = -1
var _sweep_accum: float = 0.0
var _busy: bool = false
var _handshakes_lost: int = 0
## Secondes restantes avant de republier, et recul courant. Pilotés par `tick()`
## comme le reste : un `create_timer` échapperait à l'horloge des bancs.
var _republish_wait: float = 0.0
var _republish_backoff: float = 0.0

var _local_key: String = ""
var _local_nonce: String = ""

## Rendez-vous en cours : la recherche est suspendue, l'échéance court.
var _engaged: bool = false
var _as_joiner: bool = false
var _deadline: float = 0.0
var _peer_key: String = ""
var _peer_rating: int = 0
var _peer_tier: int = 0
var _peer_commitment: String = ""
var _peer_nonce: String = ""
var _peer_accepted: bool = false
var _local_accepted: bool = false
var _match_id: String = ""
var _local_hosts: bool = false
var _declaring: bool = false
var _declare_again: bool = false

## Clé d'adversaire → secondes de garde restantes.
var _cooldowns: Dictionary = {}

func _init() -> void:
	# Un nœud ajouté dynamiquement se nomme explicitement : un nom auto-généré
	# dépend de tout ce qui a été instancié avant, diverge entre machines, et les
	# RPC routés par chemin de nœud sont alors jetés sans aucune erreur console.
	name = "Matchmaking"
	# Le menu de pause met l'arbre en pause ; une file gelée d'un seul côté
	# laisserait filer l'échéance de l'autre et passerait pour un abandon.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	# L'autoload reste inerte en headless — même raison que `RankedIdentity`, et
	# même piège : se brancher au transport pendant une suite de tests ferait
	# dépendre des essais hors ligne d'un service distant, et l'extinction croisait
	# le tic d'EOS (segfault à la sortie, code 139, alors que tous les tests
	# passaient). Les suites instancient leur propre `Matchmaking` avec une
	# doublure de transport : elles n'ont pas besoin de celui-ci.
	# L'autoload reste inerte en headless, mais **pas** les instances que les suites
	# fabriquent : celles-ci se reconnaissent à ce qu'un transport leur a déjà été
	# assigné. Un garde-fou posé sur le seul mode headless les neutralisait aussi,
	# et dix-neuf tests tombaient d'un coup — l'instance n'avait plus de transport.
	#
	# Pourquoi neutraliser l'autoload : se brancher au transport pendant une suite
	# ferait dépendre des essais hors ligne d'un service distant, et son `_process`
	# croisait l'extinction d'EOS — segfault à la sortie (code 139) alors que tous
	# les tests passaient.
	if backend == null and DisplayServer.get_name() == "headless":
		set_process(false)
		return
	if backend == null:
		backend = get_node_or_null("/root/NetworkManager")
		# Armé **dans cette branche seulement** : c'est elle qui distingue
		# l'autoload réel d'une instance fabriquée par une suite, laquelle reçoit
		# son transport avant `_ready()` et a besoin d'observer FOUND avant
		# l'acceptation. Placé une ligne plus bas, il neutralisait dix-neuf
		# contrôles d'un coup.
		auto_accept = true
	# **Aucune confirmation demandée au joueur** (décision d'Adrien, 2026-08-18).
	# Il a lancé une recherche : trouver quelqu'un est ce qu'il a demandé, le lui
	# redemander n'apporte rien et fait perdre l'appariement à qui hésite — Adrien
	# a vu passer une fenêtre de sept secondes sans avoir le temps de cliquer.
	#
	# Le drapeau reste faux par défaut pour les suites, qui pilotent l'horloge et
	# ont besoin d'observer l'état FOUND avant l'acceptation. Ce n'est que l'autoload
	# réel, celui qui a un vrai transport, qui l'arme.
	_bind_backend()

func _process(delta: float) -> void:
	if autotick:
		tick(delta)

# ===========================================================================
# CE QUE L'ÉCRAN APPELLE
# ===========================================================================

## Vrai quand le transport courant sait apparier. Faux sans Epic configuré : le
## jeu démarre alors normalement, seul ENet reste disponible, et l'appariement
## automatique doit se dire indisponible plutôt que d'échouer plus tard.
func is_supported() -> bool:
	if backend == null or not backend.has_method("matchmaking_supported"):
		return false
	return backend.matchmaking_supported()

## `rating` négatif signifie « classement inconnu » : on ne bride alors aucune
## fourchette, faute de savoir où placer le joueur.
## `resume` conserve le temps déjà attendu — c'est ce qui permet de repartir en
## file sans perdre son tour après un échec de lien.
func start_search(p_mode: Mode, rating: int = -1, resume: bool = false,
		tier: int = 0) -> bool:
	if state == State.SEARCHING or state == State.FOUND or state == State.AWAITING_ACCEPT:
		last_error = "Une recherche est déjà en cours."
		return false
	if not is_supported():
		_fail("L'appariement automatique demande une session Epic active.")
		return false

	_mode = p_mode
	_rating_known = rating >= 0
	_rating = rating if _rating_known else UNRATED_PRIOR
	_tier = maxi(tier, 0)
	if not resume:
		_elapsed = 0.0
		_handshakes_lost = 0
		_cooldowns.clear()
	_clear_engagement()
	_local_key = String(backend.local_identity_key())
	last_error = ""
	_step = -1
	_refresh_step()
	_set_state(State.SEARCHING)
	# Première passe sans attendre : le joueur vient d'appuyer.
	_sweep_accum = SWEEP_INTERVAL
	_publish_async()
	return true

func cancel() -> void:
	if state == State.IDLE:
		return
	_clear_engagement()
	_elapsed = 0.0
	_step = -1
	_set_state(State.IDLE)
	if backend != null:
		backend.queue_close_async()

## Accepte l'appariement annoncé. Le match ne part que quand les DEUX ont
## accepté.
func accept() -> bool:
	if state != State.FOUND and state != State.AWAITING_ACCEPT:
		return false
	if not _local_accepted:
		_local_accepted = true
		_set_state(State.AWAITING_ACCEPT)
		_declare_async()
	_try_launch()
	return true

## Refuse l'appariement. Les deux repartent en file, chacun avec son tour.
func refuse() -> void:
	if not _engaged:
		return
	_abandon("refusé")

# --- lecture pure, pour l'affichage ---------------------------------------

func elapsed() -> float:
	return _elapsed

func step_index() -> int:
	return maxi(_step, 0)

func step_count() -> int:
	return WIDENING.size()

func range_is_open() -> bool:
	return _half_width() == OPEN

func range_low() -> int:
	return -1 if range_is_open() else maxi(0, _rating - _half_width())

func range_high() -> int:
	return -1 if range_is_open() else _rating + _half_width()

## Ce que la recherche cherche à cet instant, en clair.
func range_label() -> String:
	if _mode == Mode.CASUAL:
		return "sans filtre de classement"
	if not _rating_known:
		return "classement inconnu — sans filtre"
	if range_is_open():
		return "toutes catégories"
	return "%d – %d" % [range_low(), range_high()]

## Secondes restantes à l'échéance courante, 0 hors rendez-vous.
func handshake_remaining() -> float:
	return maxf(_deadline, 0.0) if _engaged else 0.0

func state_label() -> String:
	match state:
		State.SEARCHING: return "Négociation…" if _engaged else "Recherche d'un adversaire…"
		State.FOUND: return "Adversaire trouvé"
		State.AWAITING_ACCEPT: return "En attente de l'adversaire…"
		State.FAILED: return "Appariement indisponible"
		_: return "Au repos"

func search_snapshot() -> Dictionary:
	return {
		state = state,
		state_label = state_label(),
		mode = _mode,
		ranked = _mode == Mode.RANKED,
		supported = is_supported(),
		elapsed = _elapsed,
		step = step_index(),
		step_count = step_count(),
		range_low = range_low(),
		range_high = range_high(),
		range_open = range_is_open(),
		range_label = range_label(),
		rating = _rating,
		rating_known = _rating_known,
		engaged = _engaged,
		handshake_remaining = handshake_remaining(),
		handshakes_lost = _handshakes_lost,
		last_error = last_error,
	}

## Vide tant qu'aucun appariement n'a été complété. `local_hosts` est la seule
## information que le joueur ne doit pas avoir à deviner : en P2P l'hôte joue à
## 0 ms, et une asymétrie qu'on n'affiche pas devient une rumeur.
func pairing_snapshot() -> Dictionary:
	if _match_id.is_empty():
		return {}
	return {
		match_id = _match_id,
		local_key = _local_key,
		opponent_key = _peer_key,
		opponent_rating = _peer_rating,
		# Les DEUX catégories : le miroir a besoin des deux pour désigner le moins
		# bien classé, et l'écran de la sienne pour dire pourquoi l'arsenal a
		# rétréci.
		local_tier = _tier,
		opponent_tier = _peer_tier,
		ranked = _mode == Mode.RANKED,
		local_hosts = _local_hosts,
		local_accepted = _local_accepted,
		opponent_accepted = _peer_accepted,
		rematch_index = 0,
	}

# ===========================================================================
# HORLOGE
# ===========================================================================

func tick(delta: float) -> void:
	if state != State.SEARCHING and state != State.FOUND and state != State.AWAITING_ACCEPT:
		return
	# Le temps d'attente court aussi pendant un rendez-vous : une poignée de main
	# qui échoue ne doit pas rétrécir la fourchette de celui qui la subit.
	_elapsed += delta
	_expire_cooldowns(delta)
	_refresh_step()

	# Recul en cours : on ne cherche pas, et surtout on ne republie pas. C'est le
	# seul moment où une file qui tourne ne parle pas à Epic.
	if _republish_wait > 0.0:
		_republish_wait -= delta
		if _republish_wait <= 0.0:
			_republish_wait = 0.0
			_publish_async()
		return

	if _engaged:
		_deadline -= delta
		if _deadline <= 0.0:
			_abandon("sans réponse" if _match_id.is_empty() else "acceptation non conclue")
		return

	_sweep_accum += delta
	if _sweep_accum >= SWEEP_INTERVAL and not _busy:
		_sweep_accum = 0.0
		_sweep_async()

func _expire_cooldowns(delta: float) -> void:
	for key: String in _cooldowns.keys():
		var left: float = _cooldowns[key] - delta
		if left <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = left

func _refresh_step() -> void:
	var next := step_for_elapsed(_elapsed)
	if next == _step:
		return
	_step = next
	range_changed.emit(_step, range_low(), range_high())

func _half_width() -> int:
	if _mode == Mode.CASUAL or not _rating_known:
		return OPEN
	return half_width_at(_step)

# ===========================================================================
# RECHERCHE
# ===========================================================================

func _publish_async() -> void:
	_local_nonce = new_nonce()
	var ok: bool = await backend.queue_publish_async(
		QUEUE_TAGS[_mode], _rating, commit(_local_nonce), _tier)
	if state != State.SEARCHING:
		# Annulé pendant la publication — elle dure le temps d'un aller-retour
		# chez Epic. Un ticket abandonné là resterait annoncé et apparierait
		# quelqu'un à un joueur déjà parti.
		if ok:
			backend.queue_close_async()
		return
	if not ok:
		_fail("Impossible d'entrer en file d'attente.")
		return
	# Un ticket qui tient remet le recul à zéro : la prochaine difficulté repart
	# de deux secondes, pas de seize.
	_republish_backoff = 0.0

## `_busy` couvre la passe ENTIÈRE, jointure comprise : une recherche EOS et une
## jointure durent chacune le temps d'un aller-retour, et deux passes qui se
## chevaucheraient rejoindraient deux adversaires pour un seul joueur.
func _sweep_async() -> void:
	_busy = true
	var found: Array = await backend.queue_search_async(
		QUEUE_TAGS[_mode], range_low(), range_high())
	if state == State.SEARCHING and not _engaged:
		var pick := _pick(found)
		if not pick.is_empty():
			if await backend.queue_join_async(String(pick.get("id", ""))):
				if state == State.SEARCHING:
					_engage(String(pick.get("key", "")), int(pick.get("rating", 0)),
						true, String(pick.get("commitment", "")),
						int(pick.get("tier", 0)))
				else:
					# Annulé pendant la jointure : on occupe le rendez-vous de
					# quelqu'un qui attend une poignée de main. Se lever tout de
					# suite le renvoie en file.
					backend.queue_close_async()
			else:
				# Un ticket qui refuse l'entrée est déjà pris, ou son propriétaire
				# est parti : le mettre de côté évite d'y revenir toutes les deux
				# secondes.
				_cooldowns[String(pick.get("key", ""))] = CANDIDATE_COOLDOWN
	_busy = false

## Choisit parmi les candidats rendus. EOS ne sait pas trier par proximité de
## classement, mais rien n'empêche de le faire sur la poignée de résultats qu'il
## rend — c'est gratuit et strictement meilleur que « le premier venu ».
func _pick(found: Array) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for entry: Variant in found:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = entry
		var key := String(candidate.get("key", ""))
		if key.is_empty() or String(candidate.get("id", "")).is_empty():
			continue
		# Notre propre ticket répond à notre propre recherche : sans ce filtre,
		# un joueur seul en file s'apparie avec lui-même. (Deux instances sur la
		# même machine partagent leur PUID : les tests à deux fenêtres exigent
		# `--eos-ephemeral`, sinon chacune prend l'autre pour elle-même.)
		if key == _local_key:
			continue
		if _cooldowns.has(key):
			continue
		# Dans un couple donné, un seul des deux a le droit de rejoindre l'autre.
		# Sans cette règle les deux se rejoignent en même temps : deux
		# appariements pour deux joueurs, et personne pour désigner le bon.
		if not _may_join(key):
			continue
		if _mode == Mode.RANKED and not _in_range(int(candidate.get("rating", 0))):
			continue
		eligible.append(candidate)

	if eligible.is_empty():
		return {}
	var mine := _rating
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absi(int(a.get("rating", 0)) - mine) < absi(int(b.get("rating", 0)) - mine))
	return eligible[0]

func _may_join(other_key: String) -> bool:
	return _local_key > other_key

func _in_range(rating: int) -> bool:
	if range_is_open():
		return true
	return rating >= range_low() and rating <= range_high()

# ===========================================================================
# POIGNÉE DE MAIN
# ===========================================================================

func _engage(peer_key: String, peer_rating: int, as_joiner: bool,
		peer_commitment: String, peer_tier: int = 0) -> void:
	_engaged = true
	_as_joiner = as_joiner
	_peer_key = peer_key
	_peer_rating = peer_rating
	_peer_tier = peer_tier
	_peer_commitment = peer_commitment
	_peer_nonce = ""
	_peer_accepted = false
	_local_accepted = false
	_match_id = ""
	_local_hosts = false
	_deadline = RENDEZVOUS_TIMEOUT
	# Le rejoignant révèle tout de suite : il ignore encore le nonce de l'autre,
	# donc il s'engage à l'aveugle — c'est ce qui l'empêche de choisir l'issue du
	# tirage. L'annonceur, lui, ne révèle qu'après avoir reçu ce nonce.
	if _as_joiner:
		_declare_async()

func _on_peer_state_changed(peer: Dictionary) -> void:
	if state != State.SEARCHING and state != State.FOUND and state != State.AWAITING_ACCEPT:
		return
	if peer.is_empty():
		# Parti du rendez-vous : c'est un refus, pas une acceptation en attente.
		if _engaged:
			_abandon("adversaire parti")
		return

	var key := String(peer.get("key", ""))
	if not _engaged:
		# Quelqu'un s'est assis dans notre ticket : nous sommes l'annonceur.
		# L'annonceur n'a jamais lu le ticket de celui qui s'assied : sa catégorie
		# arrive par l'état de MEMBRE, pas par l'attribut de salon.
		_engage(key, int(peer.get("rating", 0)), false, "",
			int(peer.get("tier", 0)))
	elif key != _peer_key:
		return

	_peer_rating = int(peer.get("rating", _peer_rating))
	_peer_tier = int(peer.get("tier", _peer_tier))
	_peer_accepted = bool(peer.get("accepted", false))
	# Le PREMIER nonce déclaré fait foi. Sans cette règle, l'autre camp pourrait
	# en redéclarer un après avoir vu le nôtre, et choisir qui héberge.
	var nonce := String(peer.get("nonce", ""))
	if _peer_nonce.is_empty() and not nonce.is_empty():
		_peer_nonce = nonce
		if not _as_joiner:
			_declare_async()
		_try_complete()
	elif not _match_id.is_empty():
		_try_launch()

## Deux déclarations qui se chevauchent s'attendraient l'une l'autre sur le même
## rappel d'Epic, et l'une des deux serait perdue — typiquement l'acceptation,
## qui passerait alors pour une expiration. On n'en laisse donc jamais deux en
## vol : celle qui arrive pendant reprend la main à la fin de la précédente.
func _declare_async() -> void:
	if backend == null:
		return
	if _declaring:
		_declare_again = true
		return
	_declaring = true
	# On ne révèle son nonce que lorsqu'on y a droit : l'annonceur qui révélerait
	# avant d'avoir reçu celui du rejoignant lui donnerait l'issue du tirage
	# avant qu'il s'engage.
	var reveal := _local_nonce if (_as_joiner or not _peer_nonce.is_empty()) else ""
	await backend.queue_declare_async({
		nonce = reveal,
		rating = _rating,
		# Sans elle, l'annonceur ignore la catégorie de celui qui vient de
		# s'asseoir : il n'a jamais lu son ticket. La règle du miroir ne tiendrait
		# alors que d'un côté — et le camp qui la calcule mal est celui qui
		# afficherait un arsenal faux.
		tier = _tier,
		accepted = _local_accepted,
	})
	_declaring = false
	if _declare_again:
		_declare_again = false
		if _engaged:
			_declare_async()

func _try_complete() -> void:
	if not _engaged or not _match_id.is_empty() or _peer_nonce.is_empty():
		return
	# Le rejoignant a vu l'engagement de l'annonceur avant d'entrer : il vérifie
	# que le nonce révélé est bien celui-là. Sinon l'annonceur aurait pu en
	# choisir un autre après coup, en toute connaissance du résultat.
	if _as_joiner and not verify_reveal(_peer_commitment, _peer_nonce):
		_abandon("engagement de tirage non tenu")
		return
	_match_id = match_id_from(_local_nonce, _peer_nonce)
	_local_hosts = designate_host(_match_id, _local_key, _peer_key) == _local_key
	_deadline = ACCEPT_TIMEOUT
	_set_state(State.FOUND)
	match_found.emit(pairing_snapshot())
	if auto_accept:
		accept()
	else:
		_try_launch()

func _try_launch() -> void:
	if _match_id.is_empty() or not _local_accepted or not _peer_accepted:
		return
	var pairing := pairing_snapshot()
	var host_key := _peer_key
	var hosting := _local_hosts
	_engaged = false
	_set_state(State.IDLE)
	if hosting:
		backend.host_matched_game()
	else:
		backend.join_matched_game(host_key)
	# Le ticket part APRÈS le lien : il n'a plus rien à annoncer, et le laisser
	# publié afficherait en file un joueur déjà en match.
	backend.queue_close_async()
	match_ready.emit(pairing)

## Retour en file. Le tour n'est pas perdu : `_elapsed` n'est pas remis à zéro,
## donc la fourchette reste celle que l'attente avait déjà gagnée.
func _abandon(reason: String) -> void:
	var lost := _peer_key
	_clear_engagement()
	_handshakes_lost += 1
	if not lost.is_empty():
		_cooldowns[lost] = CANDIDATE_COOLDOWN
	handshake_failed.emit(reason)
	if state != State.SEARCHING and state != State.FOUND and state != State.AWAITING_ACCEPT:
		return
	_set_state(State.SEARCHING)
	_sweep_accum = 0.0
	_republish_async()

## Le ticket est RECONSTRUIT, jamais réutilisé : l'adhésion à un salon EOS
## survit à la rupture du lien, le siège reste occupé et la jointure suivante est
## refusée pour de bon — le même piège que sur le salon à code, déjà payé une
## fois.
func _republish_async() -> void:
	await backend.queue_close_async()
	if state != State.SEARCHING:
		return
	# Le recul croît tant que les échecs s'enchaînent, et la republication passe
	# par `tick()` plutôt que d'être immédiate.
	_republish_backoff = REPUBLISH_BACKOFF if _republish_backoff <= 0.0 \
		else minf(_republish_backoff * 2.0, REPUBLISH_BACKOFF_MAX)
	_republish_wait = _republish_backoff

func _on_ticket_lost() -> void:
	if _engaged:
		_abandon("rendez-vous rompu")
		return
	if state != State.SEARCHING:
		return
	_republish_async()

func _clear_engagement() -> void:
	_engaged = false
	_as_joiner = false
	_deadline = 0.0
	_peer_key = ""
	_peer_rating = 0
	_peer_tier = 0
	_peer_commitment = ""
	_peer_nonce = ""
	_peer_accepted = false
	_local_accepted = false
	_match_id = ""
	_local_hosts = false
	_declare_again = false

func _bind_backend() -> void:
	if backend == null:
		return
	if backend.has_signal("queue_peer_state_changed") \
			and not backend.queue_peer_state_changed.is_connected(_on_peer_state_changed):
		backend.queue_peer_state_changed.connect(_on_peer_state_changed)
	if backend.has_signal("queue_ticket_lost") \
			and not backend.queue_ticket_lost.is_connected(_on_ticket_lost):
		backend.queue_ticket_lost.connect(_on_ticket_lost)

func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(state)

func _fail(reason: String) -> void:
	last_error = reason
	_clear_engagement()
	_set_state(State.FAILED)
	search_failed.emit(reason)

# ===========================================================================
# LOGIQUE PURE — c'est ici que se prouve l'équité
# ===========================================================================

## Palier d'élargissement atteint après `elapsed` secondes d'attente.
static func step_for_elapsed(elapsed: float) -> int:
	var step := 0
	for i in WIDENING.size():
		if elapsed >= float(WIDENING[i].after):
			step = i
	return step

static func half_width_at(step: int) -> int:
	return int(WIDENING[clampi(step, 0, WIDENING.size() - 1)].half_width)

static func new_nonce() -> String:
	return Crypto.new().generate_random_bytes(NONCE_BYTES).hex_encode()

## Engagement publié dans le ticket : le chercheur voit ce condensé, jamais la
## valeur. Il ne peut donc pas savoir qui hébergerait avant de s'engager.
static func commit(nonce: String) -> String:
	return nonce.sha256_text()

static func verify_reveal(commitment: String, nonce: String) -> bool:
	if commitment.is_empty() or nonce.is_empty():
		return false
	return commit(nonce) == commitment.to_lower()

## Identifiant de match : 16 octets qu'aucun des deux joueurs ne contrôle.
##
## Chacun y verse la moitié. L'annonceur a publié son engagement avant de savoir
## qui viendrait ; le rejoignant a déclaré son nonce sans connaître celui de
## l'annonceur. Ni l'un ni l'autre ne peut donc viser un résultat.
##
## Ordre canonique : les deux camps appellent avec leur propre nonce en premier
## et doivent obtenir le même identifiant.
static func match_id_from(nonce_a: String, nonce_b: String) -> String:
	var low := nonce_a if nonce_a <= nonce_b else nonce_b
	var high := nonce_b if nonce_a <= nonce_b else nonce_a
	# 32 caractères hexadécimaux minuscules : la forme qu'exige déjà
	# `match_reports.match_id` côté Supabase.
	return ("%s|%s" % [low, high]).sha256_buffer().slice(0, 16).hex_encode()

## Désigne qui héberge. Pure, déterministe, symétrique.
##
## En P2P l'hôte simule tout et joue à 0 ms : la désignation distribue un
## avantage, elle ne peut pas être un effet de bord de « qui attendait déjà ».
## Le tirage vient donc de l'identifiant de match, que personne ne contrôle.
##
## Le condensé porte aussi les deux identités, dans l'ordre canonique : deux
## couples différents partageant un identifiant obtiennent des tirages
## indépendants, et un joueur dont la clé est toujours la plus petite ne se
## retrouve pas du même côté à chaque fois.
static func designate_host(match_id: String, key_a: String, key_b: String) -> String:
	if key_a == key_b:
		return key_a
	var low := key_a if key_a < key_b else key_b
	var high := key_b if key_a < key_b else key_a
	# On condense au lieu de lire les bits de l'identifiant : celui-ci n'est
	# aléatoire que par convention, et un appelant qui y mettrait un compteur
	# obtiendrait sans cela un tirage systématiquement biaisé.
	var bit := int(("%s|%s|%s" % [match_id, low, high]).sha256_buffer()[0]) & 1
	return high if bit == 1 else low

## Revanches : le tirage est fait une fois, pour le premier match de la série,
## puis on alterne. Quand les revanches s'enchaînent, c'est la seule règle qui
## répartisse l'avantage exactement.
static func host_for_series(first_match_id: String, key_a: String, key_b: String,
		rematch_index: int) -> String:
	var first := designate_host(first_match_id, key_a, key_b)
	if maxi(rematch_index, 0) % 2 == 0:
		return first
	return key_b if first == key_a else key_a
