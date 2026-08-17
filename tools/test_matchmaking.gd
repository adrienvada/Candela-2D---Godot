## Test headless de l'appariement automatique (`matchmaking.gd` et les primitives
## de file de `network_manager.gd`) — Phase 8, étapes 8.2 à 8.5.
##
## EOS n'est pas joignable en headless : l'effort porte sur ce qui est décidable
## sans réseau, et c'est justement là que se trouve le risque.
##
##   • LA propriété à ne jamais laisser régresser — la désignation de l'hôte est
##     déterministe, symétrique (les deux machines la calculent séparément et
##     doivent tomber d'accord) et sans biais. En P2P l'hôte joue à 0 ms : un
##     tirage biaisé distribuerait un avantage en silence, et personne ne le
##     verrait avant longtemps.
##   • l'identifiant de match est le même des deux côtés, et l'engagement de
##     tirage publié dans le ticket est vérifié : un annonceur ne peut pas
##     révéler un autre nonce après avoir vu celui d'en face.
##   • les paliers d'élargissement, et le fait que l'état dise TOUJOURS quelle
##     fourchette il cherche.
##   • les délais d'expiration : « accepte puis ferme le jeu » vaut refus, et
##     l'attente ne se termine jamais par l'attente d'un signal qui ne viendra
##     pas.
##   • le retour en file sans perdre son tour, et le délai de garde qui empêche
##     de reproposer aussitôt un fantôme.
##   • la dégradation propre quand Epic n'est pas configuré.
##
## Lancer : godot --headless --path . --script res://tools/test_matchmaking.gd
extends SceneTree

## Nombre de tirages des contrôles de biais. Assez pour qu'un biais de 1 % soit
## hors d'atteinte du hasard, assez peu pour que la suite reste instantanée.
const DRAWS := 20000
## Tolérance sur les familles d'identifiants DÉTERMINISTES : leur résultat est
## fixé une fois pour toutes, la marge ne couvre donc aucun aléa de course.
const TOLERANCE := 0.01
## Les identifiants cryptographiques changent à chaque exécution : la marge doit
## y couvrir l'écart-type (√DRAWS / 2 ≈ 71 tirages, soit 0,35 %).
const TOLERANCE_CRYPTO := 0.025

var _failures: int = 0

## Chargé dans `_run`, jamais dans `_init` : en mode --script, `_init` s'exécute
## avant les autoloads ET avant le cache des classes globales. Un `class_name`
## référencé trop tôt rend un objet nu, les SCRIPT ERROR n'incrémentent aucun
## compteur, et la suite annonce « tous les tests passent » sans rien exécuter.
## Volontairement sans type : les fonctions pures sont statiques, et un appel
## statique passé par une variable typée `GDScript` serait refusé à l'analyse.
var _mm
var _net

var IDLE: int = 0
var SEARCHING: int = 1
var FOUND: int = 2
var AWAITING: int = 3
var FAILED: int = 4
var CASUAL: int = 0
var RANKED: int = 1
var OPEN: int = -1
var RENDEZVOUS_TIMEOUT: float = 0.0
var ACCEPT_TIMEOUT: float = 0.0
var COOLDOWN: float = 0.0
var SWEEP: float = 0.0

var _seq: int = 0

# ===========================================================================
# FAUX BACKEND
# ===========================================================================
#
# Il porte exactement le contrat que `network_manager.gd` expose, et rien de
# plus : c'est ce qui permet d'exercer la machine à états sans Epic, et de
# vérifier au passage que le contrat ne dérive pas d'un côté sans l'autre.
class FauxBackend extends Node:
	signal queue_peer_state_changed(state: Dictionary)
	signal queue_ticket_lost()

	## Une publication et une jointure durent chacune un aller-retour chez Epic.
	## Les rendre suspendables est le seul moyen d'exercer ce qui se passe quand
	## le joueur annule pendant.
	signal debloque()
	var slow_publish: bool = false
	var slow_join: bool = false

	var key: String = "ZZZZ"
	var supported: bool = true
	var publish_ok: bool = true
	var join_ok: bool = true
	var catalogue: Array = []

	var journal: Array[String] = []
	var declared: Array[Dictionary] = []
	var searches: Array[Dictionary] = []
	var commitments: Array[String] = []
	var published: int = 0
	var closed: int = 0
	var hosted: int = 0
	var joined_host: String = ""

	func matchmaking_supported() -> bool:
		return supported

	func local_identity_key() -> String:
		return key

	func queue_publish_async(mode_tag: String, rating: int, commitment: String) -> bool:
		if slow_publish:
			await debloque
		if not publish_ok:
			journal.append("publish-refusé")
			return false
		published += 1
		commitments.append(commitment)
		journal.append("publish:%s:%d" % [mode_tag, rating])
		return true

	func queue_search_async(mode_tag: String, min_rating: int, max_rating: int) -> Array:
		searches.append({ mode = mode_tag, low = min_rating, high = max_rating })
		journal.append("search")
		return catalogue.duplicate(true)

	func queue_join_async(id: String) -> bool:
		journal.append("join:%s" % id)
		if slow_join:
			await debloque
		return join_ok

	func queue_declare_async(state: Dictionary) -> bool:
		declared.append(state.duplicate())
		journal.append("declare")
		return true

	func queue_close_async() -> void:
		closed += 1
		journal.append("close")

	func host_matched_game() -> bool:
		hosted += 1
		journal.append("host")
		return true

	func join_matched_game(host_key: String) -> bool:
		joined_host = host_key
		journal.append("join-match")
		return true

	func count(prefix: String) -> int:
		var n := 0
		for line in journal:
			if line.begins_with(prefix):
				n += 1
		return n

# ===========================================================================
# CYCLE DE LA SUITE
# ===========================================================================

func _init() -> void:
	print("=== Test de l'appariement automatique ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : l'appariement automatique est absent")
		quit(1)
		return

	_test_paliers()
	_test_engagement_de_tirage()
	_test_identifiant_partage()
	_test_tirage_deterministe()
	_test_tirage_sans_biais()
	_test_revanche()
	await _test_annonceur()
	await _test_rejoignant()
	await _test_fourchette_annoncee()
	await _test_choix_du_candidat()
	await _test_soi_meme_et_role()
	await _test_expiration_rendezvous()
	await _test_accepte_puis_ferme()
	await _test_refus()
	await _test_engagement_non_tenu()
	await _test_garde_apres_echec()
	await _test_ticket_perdu()
	await _test_annulation_et_reprise()
	await _test_annulation_pendant_l_attente()
	await _test_sans_eos()
	_test_primitives_reseau()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

# ---------------------------------------------------------------------------
# CONTRÔLE PRÉALABLE
#
# Rien ne sert de conclure sur un appariement qui n'a pas compilé : on vérifie
# que tout ce qu'on s'apprête à exercer existe avant de compter le moindre
# succès. Une erreur de script n'échoue PAS un test — seul un `_check` le fait.
# ---------------------------------------------------------------------------

func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	_mm = load("res://matchmaking.gd") as GDScript
	_net = load("res://network_manager.gd") as GDScript
	if _mm == null or _net == null:
		printerr("  ✗ script introuvable ou non compilé")
		return false

	var consts: Dictionary = _mm.get_script_constant_map()
	for name in ["State", "Mode", "WIDENING", "OPEN", "QUEUE_TAGS", "UNRATED_PRIOR",
			"RENDEZVOUS_TIMEOUT", "ACCEPT_TIMEOUT", "CANDIDATE_COOLDOWN", "SWEEP_INTERVAL"]:
		if not consts.has(name):
			printerr("  ✗ Matchmaking : constante manquante : ", name)
			return false
	var states: Dictionary = consts["State"]
	var modes: Dictionary = consts["Mode"]
	for name in ["IDLE", "SEARCHING", "FOUND", "AWAITING_ACCEPT", "FAILED"]:
		if not states.has(name):
			printerr("  ✗ Matchmaking.State : état manquant : ", name)
			return false
	IDLE = states["IDLE"]
	SEARCHING = states["SEARCHING"]
	FOUND = states["FOUND"]
	AWAITING = states["AWAITING_ACCEPT"]
	FAILED = states["FAILED"]
	CASUAL = modes["CASUAL"]
	RANKED = modes["RANKED"]
	OPEN = consts["OPEN"]
	RENDEZVOUS_TIMEOUT = consts["RENDEZVOUS_TIMEOUT"]
	ACCEPT_TIMEOUT = consts["ACCEPT_TIMEOUT"]
	COOLDOWN = consts["CANDIDATE_COOLDOWN"]
	SWEEP = consts["SWEEP_INTERVAL"]
	print("  ✓ 5 états, 2 modes, %d paliers" % (consts["WIDENING"] as Array).size())

	# `has_method` posé sur un GDScript ne rend que les méthodes STATIQUES : la
	# logique pure se contrôle donc sur le script, l'API d'instance sur une
	# instance.
	var ok := true
	for method in ["step_for_elapsed", "half_width_at", "new_nonce", "commit",
			"verify_reveal", "match_id_from", "designate_host", "host_for_series"]:
		if not _mm.has_method(method):
			printerr("  ✗ Matchmaking : fonction pure manquante : ", method)
			ok = false

	var probe: Node = _mm.new()
	for method in ["start_search", "cancel", "accept", "refuse", "tick", "is_supported",
			"elapsed", "step_index", "step_count", "range_low", "range_high",
			"range_is_open", "range_label", "handshake_remaining", "state_label",
			"search_snapshot", "pairing_snapshot"]:
		if not probe.has_method(method):
			printerr("  ✗ Matchmaking : méthode manquante : ", method)
			ok = false
	for sig in ["state_changed", "range_changed", "match_found", "handshake_failed",
			"match_ready", "search_failed"]:
		if not probe.has_signal(sig):
			printerr("  ✗ Matchmaking : signal manquant : ", sig)
			ok = false
	probe.free()

	# Le contrat de file, des deux côtés : le vrai gestionnaire de réseau et le
	# faux backend doivent porter exactement les mêmes primitives, sinon la suite
	# exerce une interface qui n'existe plus.
	var faux := FauxBackend.new()
	var net: Node = _net.new()
	for method in _contract_methods():
		if not net.has_method(method):
			printerr("  ✗ NetworkManager : primitive de file manquante : ", method)
			ok = false
		if not faux.has_method(method):
			printerr("  ✗ FauxBackend : primitive de file manquante : ", method)
			ok = false
	for sig in ["queue_peer_state_changed", "queue_ticket_lost"]:
		if not net.has_signal(sig):
			printerr("  ✗ NetworkManager : signal de file manquant : ", sig)
			ok = false
		if not faux.has_signal(sig):
			printerr("  ✗ FauxBackend : signal de file manquant : ", sig)
			ok = false
	faux.free()
	net.free()

	if ok:
		print("  ✓ l'API de l'appariement et le contrat de file sont en place")
	return ok

func _contract_methods() -> Array:
	return ["matchmaking_supported", "local_identity_key", "queue_publish_async",
		"queue_search_async", "queue_join_async", "queue_declare_async",
		"queue_close_async", "host_matched_game", "join_matched_game"]

# ---------------------------------------------------------------------------
# OUTILLAGE
# ---------------------------------------------------------------------------

## L'appariement est monté avec son faux backend et l'horloge coupée : sans quoi
## un test d'expiration de quinze secondes durerait quinze secondes.
func _make(local_key: String = "ZZZZ") -> Array:
	_seq += 1
	var faux := FauxBackend.new()
	faux.name = "FauxBackend%d" % _seq
	faux.key = local_key
	var mm: Node = _mm.new()
	mm.name = "Matchmaking%d" % _seq
	mm.backend = faux
	mm.autotick = false
	root.add_child(faux)
	root.add_child(mm)
	return [mm, faux]

func _drop(pair: Array) -> void:
	for node: Node in pair:
		root.remove_child(node)
		node.free()

## Laisse les coroutines du backend se dénouer. Elles sont synchrones ici, mais
## une assertion qui n'attend pas serait vraie par accident.
func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _step(mm: Node, dt: float) -> void:
	mm.tick(dt)
	await _settle()

func _ticket(id: String, key: String, rating: int, nonce: String) -> Dictionary:
	return { id = id, key = key, rating = rating, commitment = _mm.commit(nonce) }

# ---------------------------------------------------------------------------
# PALIERS
# ---------------------------------------------------------------------------

func _test_paliers() -> void:
	print("\n[Paliers d'élargissement]")
	var expected := [[0.0, 0], [14.9, 0], [15.0, 1], [34.9, 1], [35.0, 2],
		[59.9, 2], [60.0, 3], [89.9, 3], [90.0, 4], [3600.0, 4]]
	var all := true
	for row in expected:
		if _mm.step_for_elapsed(float(row[0])) != int(row[1]):
			all = false
			printerr("      %.1f s → palier %d, attendu %d" % [
				row[0], _mm.step_for_elapsed(float(row[0])), row[1]])
	_check("chaque seuil fait changer de palier au bon moment", all)

	var table: Array = _mm.get_script_constant_map()["WIDENING"]
	var widths: Array[int] = []
	for i in table.size():
		widths.append(_mm.half_width_at(i))
	_check("la fourchette ne se resserre jamais avec l'attente",
		widths == [60, 120, 240, 480, OPEN], str(widths))
	# Un palier hors bornes ne doit pas planter : `_step` vaut -1 avant la
	# première recherche.
	_check("un palier hors bornes est ramené dans la table",
		_mm.half_width_at(-1) == 60 and _mm.half_width_at(99) == OPEN)

# ---------------------------------------------------------------------------
# TIRAGE DE L'HÔTE — le cœur
# ---------------------------------------------------------------------------

func _test_engagement_de_tirage() -> void:
	print("\n[Engagement de tirage]")
	var nonce: String = _mm.new_nonce()
	var other: String = _mm.new_nonce()
	_check("un nonce fait 32 caractères hexadécimaux",
		nonce.length() == 32 and nonce.is_valid_hex_number(false), nonce)
	_check("deux nonces diffèrent", nonce != other)
	_check("l'engagement se vérifie", _mm.verify_reveal(_mm.commit(nonce), nonce))
	_check("un autre nonce ne le satisfait pas",
		not _mm.verify_reveal(_mm.commit(nonce), other))
	# Le condensé ne dit rien de la valeur : c'est ce qui rend le chercheur
	# aveugle à l'issue du tirage au moment où il s'engage.
	_check("l'engagement ne contient pas le nonce", not _mm.commit(nonce).contains(nonce))
	_check("un engagement ou un nonce vide est refusé",
		not _mm.verify_reveal("", nonce) and not _mm.verify_reveal(_mm.commit(nonce), ""))

func _test_identifiant_partage() -> void:
	print("\n[Identifiant de match]")
	var forme := true
	var accord := true
	for i in 500:
		var a: String = _mm.new_nonce()
		var b: String = _mm.new_nonce()
		# Chaque camp appelle avec SON nonce en premier : l'ordre des arguments
		# diffère d'une machine à l'autre, le résultat ne doit pas.
		var id_a: String = _mm.match_id_from(a, b)
		var id_b: String = _mm.match_id_from(b, a)
		if id_a != id_b:
			accord = false
		# La forme exigée par `match_reports.match_id` côté Supabase.
		if id_a.length() != 32 or not id_a.is_valid_hex_number(false) or id_a != id_a.to_lower():
			forme = false
	_check("les deux camps calculent le même identifiant", accord)
	_check("32 caractères hexadécimaux minuscules", forme)
	_check("deux nonces différents donnent des identifiants différents",
		_mm.match_id_from("aa", "bb") != _mm.match_id_from("aa", "cc"))

func _test_tirage_deterministe() -> void:
	print("\n[Désignation de l'hôte — déterminisme et symétrie]")
	var id: String = _mm.match_id_from(_mm.new_nonce(), _mm.new_nonce())
	var first: String = _mm.designate_host(id, "PUID-A", "PUID-B")
	var stable := true
	for i in 100:
		if _mm.designate_host(id, "PUID-A", "PUID-B") != first:
			stable = false
	_check("mêmes entrées, même réponse cent fois de suite", stable)

	var symetrique := true
	var dans_le_couple := true
	for i in 2000:
		var mid: String = _mm.match_id_from(_mm.new_nonce(), _mm.new_nonce())
		var ka := "PUID-%d" % randi()
		var kb := "PUID-%d" % randi()
		if ka == kb:
			continue
		var vu_de_a: String = _mm.designate_host(mid, ka, kb)
		var vu_de_b: String = _mm.designate_host(mid, kb, ka)
		if vu_de_a != vu_de_b:
			symetrique = false
		if vu_de_a != ka and vu_de_a != kb:
			dans_le_couple = false
	# Chaque machine se met en premier argument : sans cette symétrie les deux
	# désigneraient un hôte différent et personne n'ouvrirait le socket.
	_check("l'ordre des arguments ne change rien", symetrique)
	_check("l'hôte est toujours l'un des deux", dans_le_couple)
	_check("deux identités identiques ne plantent pas",
		_mm.designate_host(id, "PUID-A", "PUID-A") == "PUID-A")

func _test_tirage_sans_biais() -> void:
	print("\n[Désignation de l'hôte — absence de biais]")

	# Famille 1 : des identifiants qui se DEVINENT (un compteur). C'est le cas
	# pathologique : lire directement les bits de l'identifiant donnerait ici un
	# tirage systématique, et le condensé est ce qui l'en empêche.
	var compteur := 0
	for i in DRAWS:
		if _mm.designate_host("%032x" % i, "PUID-A", "PUID-B") == "PUID-A":
			compteur += 1
	_check_equilibre("un identifiant séquentiel ne penche pas", compteur, DRAWS, TOLERANCE)

	# Famille 2 : identifiants pseudo-aléatoires mais reproductibles, donc un
	# résultat fixé une fois pour toutes.
	var chaine := "candela"
	var pseudo := 0
	for i in DRAWS:
		chaine = chaine.sha256_text()
		if _mm.designate_host(chaine.substr(0, 32), "PUID-A", "PUID-B") == "PUID-A":
			pseudo += 1
	_check_equilibre("une chaîne de condensés ne penche pas", pseudo, DRAWS, TOLERANCE)

	# Famille 3 : le cas réel, deux nonces cryptographiques.
	var vrai := 0
	for i in DRAWS:
		var mid: String = _mm.match_id_from(_mm.new_nonce(), _mm.new_nonce())
		if _mm.designate_host(mid, "PUID-A", "PUID-B") == "PUID-A":
			vrai += 1
	_check_equilibre("un identifiant cryptographique ne penche pas", vrai, DRAWS,
		TOLERANCE_CRYPTO)

	# L'erreur qu'il serait le plus facile de commettre : renvoyer la plus petite
	# des deux identités. Elle passerait déterminisme ET symétrie sans broncher.
	var petite := 0
	for i in DRAWS:
		var mid: String = _mm.match_id_from(_mm.new_nonce(), _mm.new_nonce())
		var ka := "PUID-%08d" % randi()
		var kb := "PUID-%08d" % randi()
		if ka == kb:
			continue
		var low := ka if ka < kb else kb
		if _mm.designate_host(mid, ka, kb) == low:
			petite += 1
	_check_equilibre("ce n'est pas la plus petite identité qui héberge", petite, DRAWS,
		TOLERANCE_CRYPTO)

	# À identifiant FIXE, deux couples différents doivent tirer indépendamment :
	# sinon un joueur dont l'identité est toujours la plus petite se retrouverait
	# du même côté à tous ses matchs de la journée.
	var fixe: String = _mm.match_id_from(_mm.new_nonce(), _mm.new_nonce())
	var cote := 0
	for i in DRAWS:
		var ka := "PUID-%08d" % randi()
		var kb := "PUID-%08d" % randi()
		if ka == kb:
			continue
		var low := ka if ka < kb else kb
		if _mm.designate_host(fixe, ka, kb) == low:
			cote += 1
	_check_equilibre("à identifiant fixe, les couples tirent indépendamment", cote, DRAWS,
		TOLERANCE_CRYPTO)

func _check_equilibre(label: String, hits: int, total: int, tolerance: float) -> void:
	var ecart: float = abs(float(hits) / float(total) - 0.5)
	_check("%s (%.2f %%)" % [label, 100.0 * float(hits) / float(total)],
		ecart <= tolerance, "écart de %.2f points sur %d tirages" % [100.0 * ecart, total])

func _test_revanche() -> void:
	print("\n[Revanches]")
	var id: String = _mm.match_id_from(_mm.new_nonce(), _mm.new_nonce())
	var premier: String = _mm.host_for_series(id, "PUID-A", "PUID-B", 0)
	_check("le premier match reprend le tirage",
		premier == _mm.designate_host(id, "PUID-A", "PUID-B"))
	_check("la première revanche change d'hôte",
		_mm.host_for_series(id, "PUID-A", "PUID-B", 1) != premier)
	_check("la deuxième revient au premier",
		_mm.host_for_series(id, "PUID-A", "PUID-B", 2) == premier)
	_check("l'alternance reste symétrique",
		_mm.host_for_series(id, "PUID-B", "PUID-A", 3)
			== _mm.host_for_series(id, "PUID-A", "PUID-B", 3))
	# Un index négatif serait un compteur mal initialisé : il ne doit pas
	# inverser l'hôte du premier match.
	_check("un index négatif vaut le premier match",
		_mm.host_for_series(id, "PUID-A", "PUID-B", -3) == premier)

# ---------------------------------------------------------------------------
# MACHINE À ÉTATS
# ---------------------------------------------------------------------------

func _test_annonceur() -> void:
	print("\n[Parcours de l'annonceur]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	var etats: Array[int] = []
	mm.state_changed.connect(func(s: int) -> void: etats.append(s))
	var annonces: Array[Dictionary] = []
	mm.match_found.connect(func(p: Dictionary) -> void: annonces.append(p))
	var prets: Array[Dictionary] = []
	mm.match_ready.connect(func(p: Dictionary) -> void: prets.append(p))

	_check("la recherche démarre", mm.start_search(CASUAL, 1000))
	await _settle()
	_check("état : en recherche", mm.state == SEARCHING, str(mm.state))
	_check("un ticket est publié", faux.published == 1, str(faux.published))
	_check("l'engagement de tirage part avec le ticket",
		faux.commitments.size() == 1 and faux.commitments[0].length() == 64)

	# Quelqu'un s'assied dans notre ticket, sans avoir encore rien déclaré.
	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = "", rating = 1010, accepted = false })
	await _settle()
	_check("un rendez-vous incomplet reste « en recherche »", mm.state == SEARCHING)
	_check("mais il se signale comme engagé", mm.search_snapshot().engaged)
	_check("et l'échéance court", mm.handshake_remaining() > 0.0)
	_check("l'annonceur ne révèle RIEN avant d'avoir reçu le nonce d'en face",
		faux.declared.is_empty(), str(faux.declared))

	var nonce_adverse: String = _mm.new_nonce()
	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = nonce_adverse,
		rating = 1010, accepted = false })
	await _settle()
	_check("l'annonceur révèle alors son nonce",
		faux.declared.size() == 1 and String(faux.declared[0].nonce).length() == 32,
		str(faux.declared))
	_check("état : match trouvé", mm.state == FOUND, str(mm.state))
	_check("l'appariement est annoncé une fois", annonces.size() == 1)

	var pairing: Dictionary = mm.pairing_snapshot()
	_check("l'annonce porte l'identifiant de match",
		String(pairing.get("match_id", "")).length() == 32, str(pairing))
	_check("elle porte l'adversaire et son classement",
		pairing.get("opponent_key") == "AAAA" and pairing.get("opponent_rating") == 1010)
	_check("elle dit qui héberge", typeof(pairing.get("local_hosts")) == TYPE_BOOL)
	_check("et elle est d'accord avec la fonction pure",
		bool(pairing.local_hosts)
			== (_mm.designate_host(String(pairing.match_id), "ZZZZ", "AAAA") == "ZZZZ"))

	_check("rien ne part tant que les deux n'ont pas accepté",
		faux.hosted == 0 and faux.joined_host == "")
	mm.accept()
	await _settle()
	_check("état : en attente de l'adversaire", mm.state == AWAITING, str(mm.state))
	_check("notre acceptation est déclarée",
		faux.declared.size() >= 2 and bool(faux.declared[-1].accepted))
	_check("toujours rien de lancé", faux.hosted == 0 and faux.joined_host == "")

	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = nonce_adverse,
		rating = 1010, accepted = true })
	await _settle()
	_check("le match est prêt", prets.size() == 1, str(prets.size()))
	_check("le lien est ouvert du bon côté",
		(bool(pairing.local_hosts) and faux.hosted == 1 and faux.joined_host == "")
			or (not bool(pairing.local_hosts) and faux.hosted == 0 and faux.joined_host == "AAAA"),
		"hosted=%d joined=%s hosts=%s" % [faux.hosted, faux.joined_host, pairing.local_hosts])
	_check("le ticket est retiré de la file", faux.closed >= 1)
	_check("retour au repos", mm.state == IDLE, str(mm.state))
	_check("la suite des états est celle attendue",
		etats == [SEARCHING, FOUND, AWAITING, IDLE], str(etats))
	_drop(pair)

func _test_rejoignant() -> void:
	print("\n[Parcours du rejoignant]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	var nonce_annonceur: String = _mm.new_nonce()
	faux.catalogue = [_ticket("T1", "AAAA", 1000, nonce_annonceur)]

	mm.start_search(RANKED, 1000)
	await _settle()
	await _step(mm, 0.1)
	_check("la première passe part sans attendre", faux.count("search") == 1,
		str(faux.journal))
	_check("le ticket trouvé est rejoint", faux.count("join:T1") == 1, str(faux.journal))
	_check("le rejoignant déclare son nonce tout de suite",
		faux.declared.size() == 1 and String(faux.declared[0].nonce).length() == 32,
		str(faux.declared))
	_check("il s'engage donc à l'aveugle, sans connaître celui d'en face",
		mm.pairing_snapshot().is_empty())

	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = nonce_annonceur,
		rating = 1000, accepted = true })
	await _settle()
	_check("la révélation conforme complète l'appariement", mm.state == FOUND, str(mm.state))
	var pairing: Dictionary = mm.pairing_snapshot()
	# LA propriété : les deux machines, chacune de son côté, doivent tomber sur
	# le même identifiant et le même hôte.
	var vu_par_ladversaire: String = _mm.match_id_from(nonce_annonceur,
		String(faux.declared[0].nonce))
	_check("les deux camps ont le même identifiant de match",
		String(pairing.match_id) == vu_par_ladversaire,
		"%s ≠ %s" % [pairing.match_id, vu_par_ladversaire])
	_check("et le même hôte",
		bool(pairing.local_hosts)
			== (_mm.designate_host(vu_par_ladversaire, "AAAA", "ZZZZ") == "ZZZZ"))
	_drop(pair)

func _test_fourchette_annoncee() -> void:
	print("\n[Fourchette annoncée]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	var vues: Array[Array] = []
	mm.range_changed.connect(func(step: int, low: int, high: int) -> void:
		vues.append([step, low, high]))

	mm.start_search(RANKED, 1000)
	await _settle()
	_check("la fourchette de départ est le voisinage immédiat",
		mm.range_low() == 940 and mm.range_high() == 1060,
		"%d–%d" % [mm.range_low(), mm.range_high()])
	_check("et elle se lit en clair", mm.range_label() == "940 – 1060", mm.range_label())
	_check("elle est annoncée dès le départ", vues.size() == 1, str(vues))

	await _step(mm, 0.1)
	_check("la recherche filtre bien sur elle", faux.searches.size() == 1
		and faux.searches[0].low == 940 and faux.searches[0].high == 1060,
		str(faux.searches))
	_check("et sur la file classée",
		faux.searches.size() == 1 and faux.searches[0].mode == "RANKED")

	await _step(mm, 16.0)
	_check("après quinze secondes elle s'élargit d'une catégorie",
		mm.range_low() == 880 and mm.range_high() == 1120,
		"%d–%d" % [mm.range_low(), mm.range_high()])
	_check("le changement est annoncé", vues.size() == 2, str(vues))
	await _step(mm, 20.0)
	await _step(mm, 25.0)
	await _step(mm, 30.0)
	_check("au dernier palier plus aucune borne", mm.range_is_open())
	_check("et l'écran a de quoi le dire", mm.range_label() == "toutes catégories",
		mm.range_label())
	_check("la recherche cesse alors de borner",
		faux.searches[-1].low == -1 and faux.searches[-1].high == -1, str(faux.searches[-1]))
	_check("chaque palier a été annoncé une fois", vues.size() == 5, str(vues))
	_check("le temps écoulé est lisible", mm.elapsed() > 90.0, str(mm.elapsed()))
	_drop(pair)

	# L'amical ne filtre rien : la fourchette n'a pas de sens, et l'écran doit
	# pouvoir le dire au lieu d'afficher des bornes inventées.
	var pair2 := _make("ZZZZ")
	var mm2: Node = pair2[0]
	var faux2: FauxBackend = pair2[1]
	mm2.start_search(CASUAL, 1000)
	await _settle()
	await _step(mm2, 0.1)
	_check("en amical, aucune borne", mm2.range_is_open()
		and faux2.searches[0].low == -1 and faux2.searches[0].high == -1)
	_check("et la file est distincte de la classée", faux2.searches[0].mode == "CASUAL")
	_check("l'écran l'annonce sans inventer de chiffres",
		mm2.range_label() == "sans filtre de classement", mm2.range_label())
	_drop(pair2)

	# Un joueur sans classement ne se voit pas prêter une fourchette : il n'a pas
	# de catégorie, et lui en fabriquer une serait un rang inventé.
	var pair3 := _make("ZZZZ")
	var mm3: Node = pair3[0]
	var faux3: FauxBackend = pair3[1]
	mm3.start_search(RANKED, -1)
	await _settle()
	await _step(mm3, 0.1)
	_check("classement inconnu : aucune fourchette", mm3.range_is_open()
		and faux3.searches[0].low == -1)
	_check("et le ticket porte l'a priori de départ, jamais un rang affiché",
		faux3.journal.has("publish:RANKED:%d" % int(_mm.get_script_constant_map()["UNRATED_PRIOR"])),
		str(faux3.journal))
	_check("l'écran le dit", mm3.range_label() == "classement inconnu — sans filtre",
		mm3.range_label())
	_drop(pair3)

func _test_choix_du_candidat() -> void:
	print("\n[Choix du candidat]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	faux.catalogue = [
		_ticket("loin", "AAAA", 1055, _mm.new_nonce()),
		_ticket("proche", "BBBB", 1005, _mm.new_nonce()),
		_ticket("moyen", "CCCC", 1030, _mm.new_nonce()),
	]
	mm.start_search(RANKED, 1010)
	await _settle()
	await _step(mm, 0.1)
	# EOS ne sait pas trier par proximité ; rien n'empêche de le faire sur les
	# quelques résultats qu'il rend, et c'est gratuit.
	_check("le plus proche au classement est choisi", faux.count("join:proche") == 1,
		str(faux.journal))
	_drop(pair)

	# Un ticket hors fourchette ne doit pas être rejoint même si l'index le
	# rendait : la borne d'Epic n'est pas la seule à faire foi.
	var pair2 := _make("ZZZZ")
	var mm2: Node = pair2[0]
	var faux2: FauxBackend = pair2[1]
	faux2.catalogue = [_ticket("trop-fort", "AAAA", 1600, _mm.new_nonce())]
	mm2.start_search(RANKED, 1000)
	await _settle()
	await _step(mm2, 0.1)
	_check("hors fourchette, on ne rejoint pas", faux2.count("join:") == 0, str(faux2.journal))
	await _step(mm2, 95.0)
	_check("au dernier palier, on le rejoint", faux2.count("join:trop-fort") == 1,
		str(faux2.journal))
	_drop(pair2)

func _test_soi_meme_et_role() -> void:
	print("\n[Soi-même et rôle]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	# Notre propre ticket répond à notre propre recherche : sans le filtre, un
	# joueur seul en file s'apparie avec lui-même.
	faux.catalogue = [_ticket("moi", "ZZZZ", 1000, _mm.new_nonce())]
	mm.start_search(RANKED, 1000)
	await _settle()
	await _step(mm, 0.1)
	_check("on ne rejoint pas son propre ticket", faux.count("join:") == 0, str(faux.journal))
	_check("et on reste en recherche", mm.state == SEARCHING)
	_drop(pair)

	# Dans un couple, un seul des deux a le droit de rejoindre : sinon les deux
	# se rejoignent en même temps et l'appariement se dédouble.
	var pair2 := _make("AAAA")
	var mm2: Node = pair2[0]
	var faux2: FauxBackend = pair2[1]
	faux2.catalogue = [_ticket("T1", "ZZZZ", 1000, _mm.new_nonce())]
	mm2.start_search(RANKED, 1000)
	await _settle()
	await _step(mm2, 0.1)
	_check("le mauvais côté du couple ne rejoint pas", faux2.count("join:") == 0,
		str(faux2.journal))
	_drop(pair2)

func _test_expiration_rendezvous() -> void:
	print("\n[Expiration avant appariement]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	var echecs: Array[String] = []
	mm.handshake_failed.connect(func(r: String) -> void: echecs.append(r))

	mm.start_search(RANKED, 1000)
	await _settle()
	await _step(mm, 40.0)
	var palier_avant: int = mm.step_index()
	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = "", rating = 1000, accepted = false })
	await _settle()
	_check("engagé", mm.search_snapshot().engaged)

	# Un joueur qui s'assied et ne déclare jamais rien ne doit pas immobiliser
	# l'autre : l'attente est bornée, pas suspendue à un signal.
	await _step(mm, RENDEZVOUS_TIMEOUT + 0.5)
	_check("l'échéance rend la main", not mm.search_snapshot().engaged)
	_check("et le signale", echecs.size() == 1, str(echecs))
	_check("on repart en recherche", mm.state == SEARCHING, str(mm.state))
	_check("sans perdre son tour : le palier ne recule pas",
		mm.step_index() >= palier_avant, "%d < %d" % [mm.step_index(), palier_avant])
	# Le ticket est RECONSTRUIT : l'adhésion au salon survit à la rupture, le
	# siège resterait occupé et la jointure suivante serait refusée pour de bon.
	_check("le ticket est reconstruit, pas réutilisé",
		faux.published == 2 and faux.closed >= 1,
		"publiés=%d fermés=%d" % [faux.published, faux.closed])
	_drop(pair)

func _test_accepte_puis_ferme() -> void:
	print("\n[« Il accepte puis ferme le jeu »]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	var nonce: String = _mm.new_nonce()
	mm.start_search(RANKED, 1000)
	await _settle()
	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = nonce, rating = 1000, accepted = true })
	await _settle()
	_check("appariement complet", mm.state == FOUND, str(mm.state))

	# Il a accepté, puis il disparaît. Son salon EOS lui survit : sans échéance,
	# on attendrait une acceptation déjà donnée et un lien qui ne viendra pas.
	faux.queue_peer_state_changed.emit({})
	await _settle()
	_check("son départ vaut refus, pas acceptation", mm.state == SEARCHING, str(mm.state))
	_check("accepter après coup ne lance rien",
		not mm.accept() and faux.hosted == 0 and faux.joined_host == "")
	_drop(pair)

	# Variante sans départ visible : il a accepté, il ne reste plus qu'à conclure,
	# et rien ne vient. Seule l'échéance débloque.
	var pair2 := _make("ZZZZ")
	var mm2: Node = pair2[0]
	var faux2: FauxBackend = pair2[1]
	mm2.start_search(RANKED, 1000)
	await _settle()
	faux2.queue_peer_state_changed.emit({ key = "AAAA", nonce = _mm.new_nonce(),
		rating = 1000, accepted = false })
	await _settle()
	mm2.accept()
	await _settle()
	_check("on attend l'adversaire", mm2.state == AWAITING, str(mm2.state))
	_check("l'échéance est lisible par l'écran", mm2.handshake_remaining() > 0.0)
	await _step(mm2, ACCEPT_TIMEOUT + 0.5)
	_check("l'attente est bornée", mm2.state == SEARCHING, str(mm2.state))
	_check("et aucun match n'a été lancé dans le vide",
		faux2.hosted == 0 and faux2.joined_host == "")
	_drop(pair2)

func _test_refus() -> void:
	print("\n[Refus]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	mm.start_search(RANKED, 1000)
	await _settle()
	await _step(mm, 20.0)
	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = _mm.new_nonce(),
		rating = 1000, accepted = false })
	await _settle()
	_check("appariement complet", mm.state == FOUND)
	mm.refuse()
	await _settle()
	_check("le refus renvoie en file", mm.state == SEARCHING, str(mm.state))
	_check("le tour est conservé", mm.elapsed() >= 20.0, str(mm.elapsed()))
	_check("l'appariement refusé n'est plus lisible", mm.pairing_snapshot().is_empty())
	# Un second appui sur « refuser » ne doit pas relancer une reconstruction de
	# ticket pour rien.
	var publies_avant: int = faux.published
	mm.refuse()
	await _settle()
	_check("refuser hors rendez-vous ne fait rien",
		mm.state == SEARCHING and faux.published == publies_avant)
	_drop(pair)

func _test_engagement_non_tenu() -> void:
	print("\n[Engagement de tirage non tenu]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	faux.catalogue = [_ticket("T1", "AAAA", 1000, _mm.new_nonce())]
	mm.start_search(RANKED, 1000)
	await _settle()
	await _step(mm, 0.1)
	_check("rendez-vous engagé", mm.search_snapshot().engaged)

	# L'annonceur révèle un nonce qui ne correspond pas à l'engagement publié :
	# il aurait choisi son tirage après avoir vu le nôtre.
	faux.queue_peer_state_changed.emit({ key = "AAAA", nonce = _mm.new_nonce(),
		rating = 1000, accepted = true })
	await _settle()
	_check("le rejoignant refuse l'appariement", mm.state == SEARCHING, str(mm.state))
	_check("aucun match n'est lancé", faux.hosted == 0 and faux.joined_host == "")
	_check("et rien n'est annoncé au joueur", mm.pairing_snapshot().is_empty())
	_drop(pair)

func _test_garde_apres_echec() -> void:
	print("\n[Délai de garde après un échec]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	var fantome := _ticket("T1", "AAAA", 1000, _mm.new_nonce())
	faux.catalogue = [fantome]
	mm.start_search(RANKED, 1000)
	await _settle()
	await _step(mm, 0.1)
	_check("premier essai", faux.count("join:T1") == 1, str(faux.journal))

	faux.queue_peer_state_changed.emit({})
	await _settle()
	_check("il a disparu, on repart en file", mm.state == SEARCHING)

	# Son salon lui survit : sans délai de garde, la recherche le retrouverait
	# toutes les deux secondes, pour toujours.
	await _step(mm, SWEEP + 0.1)
	await _step(mm, SWEEP + 0.1)
	_check("le fantôme n'est pas reproposé aussitôt", faux.count("join:T1") == 1,
		str(faux.journal))
	await _step(mm, COOLDOWN + 1.0)
	_check("mais il redevient éligible après le délai de garde",
		faux.count("join:T1") == 2, str(faux.journal))
	_drop(pair)

func _test_ticket_perdu() -> void:
	print("\n[Ticket perdu]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	mm.start_search(CASUAL, 1000)
	await _settle()
	faux.queue_ticket_lost.emit()
	await _settle()
	_check("un ticket perdu est republié", faux.published == 2, str(faux.published))
	_check("la recherche continue", mm.state == SEARCHING, str(mm.state))
	_drop(pair)

func _test_annulation_et_reprise() -> void:
	print("\n[Annulation et reprise]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	mm.start_search(RANKED, 1000)
	await _settle()
	_check("une deuxième recherche est refusée", not mm.start_search(RANKED, 1000))
	await _step(mm, 40.0)
	mm.cancel()
	await _settle()
	_check("l'annulation ramène au repos", mm.state == IDLE, str(mm.state))
	_check("et retire le ticket", faux.closed >= 1)
	_check("le temps est remis à zéro", mm.elapsed() == 0.0, str(mm.elapsed()))
	_check("la fourchette repart du voisinage immédiat", mm.step_index() == 0)
	_drop(pair)

	# La reprise sert après un lien manqué : l'état est revenu au repos sans que
	# le joueur ait rien annulé, son tour ne doit pas être perdu.
	var pair2 := _make("ZZZZ")
	var mm2: Node = pair2[0]
	var faux2: FauxBackend = pair2[1]
	mm2.start_search(RANKED, 1000)
	await _settle()
	await _step(mm2, 40.0)
	faux2.queue_peer_state_changed.emit({ key = "AAAA", nonce = _mm.new_nonce(),
		rating = 1000, accepted = true })
	await _settle()
	mm2.accept()
	await _settle()
	_check("match lancé", mm2.state == IDLE and mm2.elapsed() >= 40.0, str(mm2.elapsed()))
	mm2.start_search(RANKED, 1000, true)
	await _settle()
	_check("reprise : le palier gagné est conservé", mm2.step_index() == 2,
		str(mm2.step_index()))
	_drop(pair2)

## Le ticket n'est pas publié au retour de `start_search` : il l'est un
## aller-retour plus tard. Tout ce qui se décide pendant cet intervalle doit
## laisser la file propre — un ticket oublié annoncerait un joueur déjà parti.
func _test_annulation_pendant_l_attente() -> void:
	print("\n[Annulation pendant un aller-retour]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	faux.slow_publish = true
	mm.start_search(CASUAL, 1000)
	await _settle()
	_check("la publication est encore en vol", faux.published == 0)
	mm.cancel()
	await _settle()
	faux.debloque.emit()
	await _settle()
	_check("le ticket publié après l'annulation est retiré",
		faux.published == 1 and faux.closed == 2,
		"publiés=%d fermés=%d" % [faux.published, faux.closed])
	_check("et on reste au repos", mm.state == IDLE, str(mm.state))
	_drop(pair)

	var pair2 := _make("ZZZZ")
	var mm2: Node = pair2[0]
	var faux2: FauxBackend = pair2[1]
	faux2.catalogue = [_ticket("T1", "AAAA", 1000, _mm.new_nonce())]
	faux2.slow_join = true
	mm2.start_search(RANKED, 1000)
	await _settle()
	await _step(mm2, 0.1)
	_check("la jointure est en vol", faux2.count("join:T1") == 1, str(faux2.journal))
	mm2.cancel()
	await _settle()
	faux2.debloque.emit()
	await _settle()
	_check("on ne s'installe pas dans le rendez-vous d'un autre après l'annulation",
		not bool(mm2.search_snapshot().engaged) and mm2.state == IDLE)
	_check("et la place est rendue", faux2.closed == 2,
		"fermés=%d" % faux2.closed)
	_drop(pair2)

func _test_sans_eos() -> void:
	print("\n[Sans Epic configuré]")
	var pair := _make("ZZZZ")
	var mm: Node = pair[0]
	var faux: FauxBackend = pair[1]
	faux.supported = false
	var echecs: Array[String] = []
	mm.search_failed.connect(func(r: String) -> void: echecs.append(r))

	_check("l'appariement se déclare indisponible", not mm.is_supported())
	_check("la recherche est refusée", not mm.start_search(RANKED, 1000))
	_check("état : échec", mm.state == FAILED, str(mm.state))
	_check("avec un message pour le joueur", mm.last_error != "")
	_check("et un signal", echecs.size() == 1, str(echecs))
	_check("aucun ticket n'a été publié", faux.published == 0)
	# Une horloge qui tourne sur un état d'échec relancerait des recherches
	# impossibles.
	await _step(mm, 100.0)
	_check("l'horloge ne relance rien", faux.count("search") == 0, str(faux.journal))
	_drop(pair)

	# Publication refusée par le service : l'échec doit remonter, pas rester en
	# « recherche » silencieuse.
	var pair2 := _make("ZZZZ")
	var mm2: Node = pair2[0]
	var faux2: FauxBackend = pair2[1]
	faux2.publish_ok = false
	mm2.start_search(CASUAL)
	await _settle()
	_check("une publication refusée fait échouer la recherche", mm2.state == FAILED,
		str(mm2.state))
	_drop(pair2)

func _test_primitives_reseau() -> void:
	print("\n[Primitives de file du gestionnaire de réseau]")
	# L'autoload existe en mode --script après une frame : c'est le vrai
	# gestionnaire, avec le vrai état d'Epic de cette machine.
	var net: Node = root.get_node_or_null("/root/NetworkManager")
	if net == null:
		_check("l'autoload NetworkManager est joignable", false, "absent de /root")
		return
	_check("l'autoload NetworkManager est joignable", true)

	var transports: Dictionary = _net.get_script_constant_map()["Transport"]
	var states: Dictionary = _net.get_script_constant_map()["EosState"]
	var avant: int = net.transport
	net.transport = transports["ENET"]
	# ENet n'a ni index de salons ni traversée de NAT : l'appariement automatique
	# n'y est pas seulement dégradé, il n'y est pas.
	_check("en ENet, l'appariement se déclare indisponible", not net.matchmaking_supported())
	net.transport = avant

	if net.eos_state != states["READY"]:
		# Cas du poste sans `eos_credentials.gd` — et de ce worktree : le jeu
		# démarre normalement, EOS reste « non configuré », et l'appariement doit
		# le dire au lieu d'échouer plus tard.
		_check("sans session Epic prête, l'appariement se déclare indisponible",
			not net.matchmaking_supported(),
			"état EOS = %d" % net.eos_state)
	else:
		_check("session Epic prête : l'appariement est disponible", net.matchmaking_supported())

	_check("l'identité locale est vide sans session Epic",
		net.eos_state == states["READY"] or String(net.local_identity_key()).is_empty())
	# Sans EOS prêt, aucune primitive ne doit partir dans le vide.
	var publie: bool = await net.queue_publish_async("RANKED", 1000, "abc")
	_check("publier un ticket sans Epic échoue proprement",
		net.eos_state == states["READY"] or not publie)
	var trouves: Array = await net.queue_search_async("RANKED", -1, -1)
	_check("chercher sans Epic rend une liste vide",
		net.eos_state == states["READY"] or trouves.is_empty())
	_check("rejoindre un ticket inconnu échoue",
		not await net.queue_join_async("ticket-qui-nexiste-pas"))
	_check("déclarer hors rendez-vous échoue",
		not await net.queue_declare_async({ nonce = "a", rating = 1, accepted = true }))
