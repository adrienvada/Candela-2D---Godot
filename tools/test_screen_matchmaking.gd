## Test headless de l'écran de recherche de match (`screen_matchmaking.gd`).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • **une recherche dit toujours ce qu'elle cherche**. C'est la raison d'être
##     de l'écran : une attente qui n'annonce ni son temps ni sa fourchette passe
##     pour cassée au bout de vingt secondes, et le joueur quitte en croyant à un
##     défaut ;
##   • **rien n'est inventé** — ni fourchette, ni classement, ni hôte. Une
##     fourchette recomposée à l'écran serait fausse d'une manière parfaitement
##     plausible, donc invisible ; un hôte deviné serait juste une fois sur deux ;
##   • **l'appariement n'existe pas encore** : `matchmaking.gd` s'écrit en
##     parallèle. L'écran doit annoncer « indisponible » au lieu de planter, et
##     c'est le test le plus important de la suite tant que le fichier manque ;
##   • les six états se distinguent à l'écran — indisponible, repos, recherche,
##     trouvé, attente, refus adverse — parce que c'est là que vit l'écran, pas
##     dans le cas heureux ;
##   • **l'abandon reste atteignable au curseur** dans tout état engagé, et aucun
##     bouton n'est jamais désactivé : le jeu se joue à la manette, et un contrôle
##     qui sort du parcours du curseur en pleine action ressemble à un défaut ;
##   • `refresh()` est idempotent, y compris avant construction, et **ne lance
##     rien** : un rafraîchissement qui mettrait en file engagerait le joueur dans
##     un match classé au simple passage sur l'écran ;
##   • le temps écoulé se réétiquette **seul**, sans repeindre le reste.
##
## Le réseau n'est pas joignable en headless, et `eos_credentials.gd` n'est même
## pas versionné : c'est précisément pourquoi l'appariement est simulé. Les états
## dégradés SONT le sujet — ce sont eux que le vrai service ne montrera jamais.
##
## Lancer : godot --headless --path . --script res://tools/test_screen_matchmaking.gd
extends SceneTree

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, `_init()`
## s'exécute avant les autoloads ET avant le cache des classes globales. Un
## `class_name` référencé trop tôt rend un objet nu, les SCRIPT ERROR
## n'incrémentent aucun compteur, et la suite annonce « tous les tests passent »
## sans avoir rien exécuté. Le piège est consigné dans la ROADMAP.
var _screen_script: GDScript
## `ScreenMatchmaking.Display`, relu de la table des constantes plutôt que du
## `class_name`.
var _display: Dictionary = {}
var _consts: Dictionary = {}

# ---------------------------------------------------------------------------
# APPARIEMENT SIMULÉ
# ---------------------------------------------------------------------------
#
# Trois doublures, et la différence entre elles est le sujet de trois tests à
# part entière :
#
#   • RIEN DU TOUT — l'état d'aujourd'hui : `matchmaking.gd` n'existe pas ;
#   • `Partiel` — un instantané lisible, mais pas les commandes. C'est la version
#     décalée : l'écran saurait afficher « match trouvé » et son bouton
#     CONFIRMER ne ferait rien ;
#   • `Complet` — l'API attendue en entier.

## Instantané lisible, aucune commande. Reproduit une divergence de version entre
## le jeu et l'appariement.
class Partiel extends Node:
	func search_snapshot() -> Dictionary:
		return {"configured": true, "phase": "searching", "elapsed": 30.0,
			"bracket": [950, 1120]}

## L'API attendue. Les clés facultatives sont **omises** quand la valeur est
## inconnue, et non mises à zéro : c'est toute la différence que l'écran doit
## savoir lire.
class Complet extends Node:
	signal state_changed

	var configured: bool = true
	var phase: String = "idle"
	var reason: String = ""
	var notice: String = ""
	## Négatif → la clé est absente de l'instantané.
	var elapsed: float = -1.0
	var remaining: float = -1.0
	## Vide → la clé est absente.
	var bracket: Array = []
	var me: Dictionary = {}
	var opponent: Dictionary = {}
	## Faux → la clé `host_is_me` est absente : l'hôte n'est pas encore désigné.
	var host_set: bool = false
	var host_is_me: bool = false

	## Journal des commandes reçues. Sert à prouver que l'affichage n'en émet
	## aucune, et que les boutons émettent les bonnes.
	var starts: Array[bool] = []
	var cancels: int = 0
	var accepts: int = 0
	var declines: int = 0

	func search_snapshot() -> Dictionary:
		var snap: Dictionary = {
			"configured": configured, "phase": phase, "reason": reason,
			"notice": notice, "me": me, "opponent": opponent,
		}
		if elapsed >= 0.0:
			snap["elapsed"] = elapsed
		if remaining >= 0.0:
			snap["remaining"] = remaining
		if not bracket.is_empty():
			snap["bracket"] = bracket
		if host_set:
			snap["host_is_me"] = host_is_me
		return snap

	func start_search(mode: int, _rating: int = -1, _resume: bool = false) -> void:
		starts.append(mode == 1)

	func cancel() -> void:
		cancels += 1

	func accept() -> void:
		accepts += 1

	func refuse() -> void:
		declines += 1

	func commands() -> int:
		return starts.size() + cancels + accepts + declines

# ---------------------------------------------------------------------------

func _init() -> void:
	print("=== Test de l'écran de recherche de match ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : l'écran de recherche est absent ou incomplet")
		quit(1)
		return

	_test_contrat()
	_test_api_absente()
	_test_api_partielle()
	_test_non_configure()
	_test_service_injoignable()
	_test_phase_inconnue()
	_test_repos()
	_test_recherche()
	_test_fourchette_absente()
	_test_trouve()
	_test_qui_heberge()
	_test_attente()
	_test_refus_adverse()
	_test_etats_distincts()
	_test_abandon_atteignable()
	_test_idempotence()
	_test_affichage_ne_lance_rien()
	_test_commandes()
	_test_file_classee()
	_test_horloge()
	_test_aucun_chiffre_invente()
	_test_porte_de_sortie()
	_test_signal()

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
# ---------------------------------------------------------------------------
#
# Rien ne sert de conclure sur un écran qui n'a pas compilé : un script absent
# rend `null`, une instance nue avale tous les appels, et la suite annoncerait
# « tous les tests passent » sans avoir rien exercé. Le piège est consigné dans
# la ROADMAP, il a déjà été payé deux fois.
func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	_screen_script = load("res://screen_matchmaking.gd") as GDScript
	if _screen_script == null:
		printerr("  ✗ script introuvable ou non compilé : screen_matchmaking.gd")
		return false

	var ok := true
	if String(_screen_script.get_global_name()) != "ScreenMatchmaking":
		printerr("  ✗ class_name attendu : ScreenMatchmaking, obtenu : ",
			_screen_script.get_global_name())
		ok = false

	var base: Script = _screen_script.get_base_script()
	if base == null or base.resource_path != "res://hub_screen.gd":
		printerr("  ✗ l'écran doit hériter de hub_screen.gd")
		ok = false

	# `has_method()` sur un `GDScript` ne rendrait que les méthodes statiques :
	# les méthodes d'instance se cherchent sur une instance.
	var probe: Object = _screen_script.new()
	for method in ["screen_title", "build", "refresh", "focus_seed", "display_state",
			"matchmaking_reachable", "matchmaking_configured", "is_alarming",
			"bracket_shown", "host_known", "cancel_reachable", "queue_is_ranked",
			"set_ranked_queue"]:
		if not probe.has_method(method):
			printerr("  ✗ ScreenMatchmaking : méthode manquante : ", method)
			ok = false
	probe.free()

	_consts = _screen_script.get_script_constant_map()
	for key in ["Display", "MATCHMAKER_PATH", "SNAPSHOT_METHOD", "START_METHOD",
			"CANCEL_METHOD", "ACCEPT_METHOD", "DECLINE_METHOD", "CHANGED_SIGNAL",
			"REQUIRED_METHODS", "FRIENDLY_SCREEN", "PHASE_IDLE", "PHASE_SEARCHING",
			"PHASE_FOUND", "PHASE_AWAITING", "PHASE_DECLINED", "PHASE_UNAVAILABLE"]:
		if not _consts.has(key):
			printerr("  ✗ ScreenMatchmaking : constante manquante : ", key)
			ok = false
	if not ok:
		return false

	_display = _consts["Display"]
	if _display.size() != 6:
		printerr("  ✗ Display doit porter les six états réels, il en porte ",
			_display.size())
		ok = false

	# Le vocabulaire de phases est le contrat entre l'écran et l'appariement. Deux
	# phases qui se confondraient rendraient deux situations indiscernables.
	var vocabulary: Array[String] = []
	for key in ["PHASE_IDLE", "PHASE_SEARCHING", "PHASE_FOUND", "PHASE_AWAITING",
			"PHASE_DECLINED", "PHASE_UNAVAILABLE"]:
		vocabulary.append(String(_consts[key]))
	var unique: Dictionary = {}
	for word in vocabulary:
		unique[word] = true
	if unique.size() != vocabulary.size():
		printerr("  ✗ le vocabulaire de phases a des doublons : ", str(vocabulary))
		ok = false

	# La porte de sortie de l'état « indisponible » est un identifiant d'écran du
	# hub. `MenuHub.push()` refuse un identifiant inconnu **sans rien dire** : une
	# dérive donnerait un bouton qui n'a l'air de rien faire, et un bouton mort ne
	# se distingue pas d'un jeu cassé. Les deux valeurs sont donc verrouillées
	# l'une contre l'autre.
	var ui_script: GDScript = load("res://ui.gd") as GDScript
	if ui_script == null:
		printerr("  ✗ ui.gd introuvable : l'identifiant d'écran ne peut être vérifié")
		ok = false
	else:
		var expected: Variant = ui_script.get_script_constant_map().get("SCREEN_FRIENDLY", null)
		if expected == null:
			printerr("  ✗ ui.gd:SCREEN_FRIENDLY introuvable")
			ok = false
		elif String(expected) != String(_consts["FRIENDLY_SCREEN"]):
			printerr("  ✗ FRIENDLY_SCREEN a dérivé de ui.gd:SCREEN_FRIENDLY : ",
				String(_consts["FRIENDLY_SCREEN"]), " ≠ ", String(expected))
			ok = false

	# La doublure complète doit porter tout ce que l'écran exige, sinon elle
	# prouverait tout. Et l'écran exige tout ou rien : un instantané sans les
	# commandes n'est pas un point de contact utilisable.
	var stub := Complet.new()
	for method in _consts["REQUIRED_METHODS"]:
		if not stub.has_method(String(method)):
			printerr("  ✗ la doublure ne reproduit pas l'API attendue : ", method)
			ok = false
	if not stub.has_signal(String(_consts["CHANGED_SIGNAL"])):
		printerr("  ✗ la doublure n'émet pas ", _consts["CHANGED_SIGNAL"])
		ok = false
	stub.free()

	# Le fait du jour, et la raison d'être du test `[API absente]`.
	if ResourceLoader.exists("res://matchmaking.gd"):
		print("  · matchmaking.gd existe : l'écran est raccordable, le test " \
			+ "d'absence reste utile pour une version décalée")
	else:
		print("  · matchmaking.gd n'existe pas encore — l'écran est exercé " \
			+ "contre des doublures, comme prévu")

	if ok:
		print("  ✓ l'écran, son contrat et le vocabulaire de phases sont en place")
	return ok

# ---------------------------------------------------------------------------
# OUTILLAGE
# ---------------------------------------------------------------------------

## Un écran construit, branché sur l'appariement donné — ou sur rien. L'appelant
## libère les deux.
func _make_screen(mm: Node) -> Control:
	var screen: Control = _screen_script.new()
	screen.matchmaker_override = mm
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	return screen

func _dispose(screen: Control, mm: Node) -> void:
	screen.free()
	if mm != null:
		mm.free()

## Une file en recherche, fourchette annoncée. Aucun classement n'est à 1000 :
## c'est ce qui rend la suite capable de distinguer un chiffre venu du service
## d'un chiffre inventé par l'écran.
func _searching() -> Complet:
	var mm := Complet.new()
	mm.phase = String(_consts["PHASE_SEARCHING"])
	mm.elapsed = 24.0
	mm.bracket = [950, 1120]
	return mm

## Un appariement conclu : deux identités, un hôte désigné, un délai.
func _found(host_is_me: bool) -> Complet:
	var mm := Complet.new()
	mm.phase = String(_consts["PHASE_FOUND"])
	mm.remaining = 8.0
	mm.me = {"nickname": "Vada", "rating": 1181, "rank_label": "Bougie II"}
	mm.opponent = {"nickname": "Ombre", "rating": 1248, "rank_label": "Lanterne I"}
	mm.host_set = true
	mm.host_is_me = host_is_me
	return mm

func _awaiting() -> Complet:
	var mm := _found(false)
	mm.phase = String(_consts["PHASE_AWAITING"])
	mm.remaining = 6.0
	return mm

func _declined() -> Complet:
	var mm := _searching()
	mm.phase = String(_consts["PHASE_DECLINED"])
	mm.elapsed = 41.0
	mm.notice = "Votre adversaire n'a pas confirmé à temps."
	return mm

func _idle() -> Complet:
	return Complet.new()

## Une doublure par état, dans l'ordre où le jeu les rencontre.
func _stub_for(state_name: String) -> Complet:
	match state_name:
		"IDLE":
			return _idle()
		"SEARCHING":
			return _searching()
		"FOUND":
			return _found(true)
		"AWAITING_PEER":
			return _awaiting()
		"PEER_DECLINED":
			return _declined()
		_:
			# UNAVAILABLE : le cas de tout dépôt frais, sans identifiants EOS.
			var mm := Complet.new()
			mm.configured = false
			return mm

## Tout le texte que le joueur lit, et rien d'autre.
func _texts(screen: Control, skip: Array) -> String:
	var texts := PackedStringArray()
	_collect_text(screen, texts, skip)
	return "¦".join(texts)

func _collect_text(node: Node, out: PackedStringArray, skip: Array) -> void:
	var control := node as Control
	if control != null and not control.visible:
		return
	if skip.has(node):
		return
	var label := node as Label
	if label != null and label.text != "":
		out.append(label.text)
	for child in node.get_children():
		_collect_text(child, out, skip)

## Tout ce que l'écran montre effectivement : le texte visible, plus l'état des
## deux boutons et des cartes d'identité. Deux états qui rendent la même
## empreinte sont indiscernables pour le joueur, quelles que soient les
## différences internes.
func _imprint(screen: Control) -> String:
	return "%s | engager=%s | abandonner=%s | cartes=%s" % [
		_texts(screen, []), _button_state(screen._engage),
		_button_state(screen._withdraw), str(screen._cards.visible)]

## La même empreinte, **privée des deux étiquettes vivantes**. Sert à prouver que
## la seconde qui passe ne repeint rien d'autre.
func _imprint_hors_horloge(screen: Control) -> String:
	return "%s | engager=%s | abandonner=%s | cartes=%s" % [
		_texts(screen, [screen._clock, screen._bracket]),
		_button_state(screen._engage), _button_state(screen._withdraw),
		str(screen._cards.visible)]

func _button_state(btn: Button) -> String:
	return btn.text if btn.visible else "(masqué)"

func _contains(screen: Control, needle: String) -> bool:
	return _texts(screen, []).find(needle) >= 0

func _has_digit(text: String) -> bool:
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			return true
	return false

## Aucun bouton visible ne doit jamais être désactivé : un bouton grisé sort du
## parcours du curseur, et le jeu se joue à la manette.
func _no_disabled_button(screen: Control) -> bool:
	return not screen._engage.disabled and not screen._withdraw.disabled

# ---------------------------------------------------------------------------
# LE CONTRAT DE HubScreen
# ---------------------------------------------------------------------------

func _test_contrat() -> void:
	print("\n[Contrat d'écran]")

	# Le hub appelle `refresh()` avant le premier affichage, parfois avant même
	# que `build()` ait eu lieu. Sans cette garantie, l'ordre d'ouverture des
	# écrans devient une dépendance cachée — celles qui ne se voient que sur la
	# machine de quelqu'un d'autre.
	var orphelin: Control = _screen_script.new()
	orphelin.refresh()
	orphelin.refresh()
	_check("rafraîchir avant construction ne plante pas", true)
	_check("l'écran a un titre", String(orphelin.screen_title()).strip_edges() != "")
	_check("aucune amorce de curseur avant construction", orphelin.focus_seed() == null)
	_check("l'abandon n'est pas annoncé atteignable avant construction",
		not orphelin.cancel_reachable())
	# Même sans nœuds, l'état doit être renseigné : c'est lui que le hub lira pour
	# décider s'il vaut la peine d'afficher l'écran.
	_check("et l'état est déjà celui de l'absence d'appariement",
		int(orphelin.display_state()) == int(_display["UNAVAILABLE"]),
		str(orphelin.display_state()))
	orphelin.free()

	var mm := _searching()
	var screen := _make_screen(mm)
	var seed: Control = screen.focus_seed()
	_check("le curseur a où se poser une fois construit", seed != null)
	_check("et cette cible est atteignable à la manette",
		seed != null and seed.focus_mode != Control.FOCUS_NONE)
	_check("elle n'est pas désactivée", seed != null and not (seed as Button).disabled)

	# Construire deux fois ne doit rien empiler : le hub peut reremplir un écran
	# en plusieurs passes.
	var body: VBoxContainer = screen.get_child(0)
	var before: int = body.get_child_count()
	screen.build(body)
	_check("construire deux fois ne duplique rien", body.get_child_count() == before,
		"%d puis %d" % [before, body.get_child_count()])
	_dispose(screen, mm)

# ---------------------------------------------------------------------------
# L'APPARIEMENT N'EXISTE PAS — le test du jour
# ---------------------------------------------------------------------------

## LE test tant que `matchmaking.gd` n'est pas écrit. L'écran n'a personne à
## interroger : il doit le dire, sans planter, et sans prendre l'air d'une panne
## — un match amical par code reste jouable.
func _test_api_absente() -> void:
	print("\n[API absente : matchmaking.gd n'existe pas]")

	var screen := _make_screen(null)
	_check("l'écran se construit quand même", screen != null)
	_check("état indisponible", int(screen.display_state()) == int(_display["UNAVAILABLE"]),
		str(screen.display_state()))
	_check("le point de contact est déclaré injoignable", not screen.matchmaking_reachable())
	_check("ce n'est pas présenté comme une panne", not screen.is_alarming())
	_check("l'écran dit que cette version ne sait pas apparier",
		_contains(screen, "ne sait pas encore apparier"), _imprint(screen))
	_check("et il indique la porte de sortie",
		_contains(screen, "match amical par code"), _imprint(screen))
	_check("aucune fourchette n'est promise", not screen.bracket_shown())
	_check("aucun hôte n'est prétendu", not screen.host_known())
	_check("aucune carte d'identité", not screen._cards.visible)
	_check("et aucun chiffre inventé", not _has_digit(_texts(screen, [])),
		_texts(screen, []))
	screen.refresh()
	screen.refresh()
	_check("deux rafraîchissements de plus n'y changent rien",
		int(screen.display_state()) == int(_display["UNAVAILABLE"]))
	# Le bouton restant doit mener quelque part : un écran sans issue à la manette
	# n'a pas d'issue du tout.
	_check("le curseur a tout de même où se poser", screen.focus_seed() != null)
	_check("et rien n'est désactivé", _no_disabled_button(screen))
	screen.free()

## Version décalée : l'instantané se lit, les commandes manquent. Un écran
## « match trouvé » dont CONFIRMER ne fait rien est pire qu'un écran qui explique
## qu'il ne sait pas apparier.
func _test_api_partielle() -> void:
	print("\n[API partielle : l'instantané sans les commandes]")

	var mm := Partiel.new()
	var screen := _make_screen(mm)
	_check("état indisponible malgré un instantané lisible",
		int(screen.display_state()) == int(_display["UNAVAILABLE"]),
		str(screen.display_state()))
	_check("le point de contact est refusé en bloc", not screen.matchmaking_reachable())
	_check("la recherche annoncée par l'instantané n'est pas affichée",
		not _contains(screen, "Recherche d'un adversaire"), _imprint(screen))
	_check("et sa fourchette n'est pas reprise", not _contains(screen, "950"),
		_imprint(screen))
	_dispose(screen, mm)

# ---------------------------------------------------------------------------
# LES SIX ÉTATS
# ---------------------------------------------------------------------------

## Le cas de tout dépôt frais : `eos_credentials.gd` n'est pas versionné. Le jeu
## démarre normalement et se joue — l'écran doit le dire, et surtout ne pas
## ressembler à une panne de serveur qu'un contributeur irait chercher.
func _test_non_configure() -> void:
	print("\n[Appariement non configuré sur cette installation]")

	var mm := Complet.new()
	mm.configured = false
	var screen := _make_screen(mm)
	_check("état indisponible", int(screen.display_state()) == int(_display["UNAVAILABLE"]),
		str(screen.display_state()))
	_check("le point de contact est là, lui", screen.matchmaking_reachable())
	_check("mais l'appariement n'est pas praticable", not screen.matchmaking_configured())
	_check("ton neutre : ce n'est pas une panne", not screen.is_alarming())
	_check("l'écran parle d'identifiants manquants",
		_contains(screen, "identifiants"), _imprint(screen))
	_check("et laisse le match par code accessible",
		_contains(screen, "match amical par code"), _imprint(screen))
	_check("aucun chiffre inventé", not _has_digit(_texts(screen, [])),
		_texts(screen, []))
	_dispose(screen, mm)

func _test_service_injoignable() -> void:
	print("\n[Service d'appariement injoignable]")

	var mm := Complet.new()
	mm.phase = String(_consts["PHASE_UNAVAILABLE"])
	mm.reason = "Le service d'appariement ne répond pas."
	var screen := _make_screen(mm)
	_check("état indisponible", int(screen.display_state()) == int(_display["UNAVAILABLE"]),
		str(screen.display_state()))
	# Deux registres : l'absence de configuration est un fait, un service muet est
	# un ennui. Les peindre pareil ferait passer l'un pour l'autre.
	_check("celui-là, en revanche, mérite l'avertissement", screen.is_alarming())
	_check("la phrase du service est reprise telle quelle",
		_contains(screen, "ne répond pas"), _imprint(screen))
	_check("et la porte de sortie reste ouverte",
		_contains(screen, "match amical par code"), _imprint(screen))
	_dispose(screen, mm)

	# Sans phrase fournie, l'écran en a une à lui : un cadre vide passerait pour
	# un défaut de mise en page.
	var muet := Complet.new()
	muet.phase = String(_consts["PHASE_UNAVAILABLE"])
	var ecran := _make_screen(muet)
	_check("sans raison fournie, l'écran en donne une",
		_contains(ecran, "injoignable"), _imprint(ecran))
	_dispose(ecran, muet)

## Divergence de version : l'appariement annonce une phase que cette version du
## jeu ne connaît pas. La traiter comme « au repos » offrirait un bouton CHERCHER
## alors qu'une recherche tourne peut-être déjà.
func _test_phase_inconnue() -> void:
	print("\n[Phase inconnue]")

	var mm := Complet.new()
	mm.phase = "reserving_lobby"
	var screen := _make_screen(mm)
	_check("état indisponible", int(screen.display_state()) == int(_display["UNAVAILABLE"]),
		str(screen.display_state()))
	_check("et signalé comme un ennui", screen.is_alarming())
	_check("aucun bouton ne propose de chercher",
		not _contains(screen, "CHERCHER") and screen._engage.text.find("CHERCHER") < 0,
		_imprint(screen))
	_dispose(screen, mm)

func _test_repos() -> void:
	print("\n[Au repos]")

	var mm := _idle()
	var screen := _make_screen(mm)
	_check("état repos", int(screen.display_state()) == int(_display["IDLE"]),
		str(screen.display_state()))
	_check("une entrée invite à chercher", screen._engage.visible
		and screen._engage.text == "CHERCHER UN MATCH", _button_state(screen._engage))
	_check("elle est atteignable au curseur",
		screen._engage.focus_mode != Control.FOCUS_NONE and not screen._engage.disabled)
	_check("rien à abandonner tant que rien n'est lancé", not screen.cancel_reachable())
	_check("aucune horloge", screen._clock.text == "", screen._clock.text)
	_check("aucune fourchette", not screen.bracket_shown() and screen._bracket.text == "",
		screen._bracket.text)
	_check("aucune carte d'identité", not screen._cards.visible)
	_check("l'écran annonce que la fourchette s'élargira",
		_contains(screen, "élargit"), _imprint(screen))
	_check("et n'invente aucun chiffre", not _has_digit(_texts(screen, [])),
		_texts(screen, []))
	# Un simple affichage ne met personne en file.
	_check("l'affichage n'a lancé aucune recherche", mm.commands() == 0,
		str(mm.commands()))
	_dispose(screen, mm)

## LE test de l'écran. Une recherche qui ne dit pas ce qu'elle cherche paraît
## cassée au bout de vingt secondes : le temps écoulé et la fourchette courante
## sont donc au même rang d'importance, et tous deux viennent du service.
func _test_recherche() -> void:
	print("\n[En recherche]")

	var mm := _searching()
	var screen := _make_screen(mm)
	_check("état recherche", int(screen.display_state()) == int(_display["SEARCHING"]),
		str(screen.display_state()))
	_check("le temps écoulé est affiché", _contains(screen, "24 s"), _imprint(screen))
	_check("la fourchette cherchée est affichée", screen.bracket_shown())
	_check("avec ses deux bornes, telles que données",
		_contains(screen, "950") and _contains(screen, "1120"), _imprint(screen))
	_check("l'abandon est atteignable au curseur", screen.cancel_reachable())
	_check("et il dit ce qu'il annule", screen._withdraw.text.find("ANNULER") >= 0,
		screen._withdraw.text)
	_check("aucune carte d'identité sans adversaire", not screen._cards.visible)
	_check("aucun hôte prétendu", not screen.host_known())
	_check("l'écran dit que la recherche survit à la navigation",
		_contains(screen, "parcourir les menus"), _imprint(screen))
	_check("rien n'a été commandé par l'affichage", mm.commands() == 0, str(mm.commands()))
	_dispose(screen, mm)

	# Le temps se lit en minutes passé la minute, et la seconde entamée n'est pas
	# comptée : un compteur qui avance avant l'heure est un compteur faux.
	var longue := _searching()
	longue.elapsed = 84.7
	var ecran := _make_screen(longue)
	_check("passé la minute, le temps se lit en minutes",
		_contains(ecran, "1 min 24 s"), _imprint(ecran))
	_dispose(ecran, longue)

## L'appariement peut très bien ne pas communiquer sa fourchette — en file
## amicale, il n'y en a pas. L'écran doit alors le dire au lieu de laisser un
## blanc, et surtout ne pas en recomposer une : une fourchette fausse reste
## plausible, personne ne la verrait.
func _test_fourchette_absente() -> void:
	print("\n[Recherche sans fourchette communiquée]")

	var mm := _searching()
	mm.bracket = []
	var screen := _make_screen(mm)
	_check("état recherche quand même",
		int(screen.display_state()) == int(_display["SEARCHING"]),
		str(screen.display_state()))
	_check("aucune fourchette n'est affichée", not screen.bracket_shown())
	_check("le manque est écrit, la place n'est pas laissée vide",
		screen._bracket.text.find("ne communique pas") >= 0, screen._bracket.text)
	_check("et aucun chiffre n'y figure", not _has_digit(screen._bracket.text),
		screen._bracket.text)
	_check("le temps écoulé, lui, reste affiché", _contains(screen, "24 s"),
		_imprint(screen))
	_check("l'abandon reste atteignable", screen.cancel_reachable())
	_dispose(screen, mm)

	# Une borne au lieu de deux n'est pas une fourchette : la moitié d'une
	# information est une information fausse.
	var boiteux := _searching()
	boiteux.bracket = [950]
	var ecran := _make_screen(boiteux)
	_check("une seule borne ne fait pas une fourchette", not ecran.bracket_shown())
	_check("et elle n'est pas affichée à moitié", not _contains(ecran, "950"),
		_imprint(ecran))
	_dispose(ecran, boiteux)

func _test_trouve() -> void:
	print("\n[Match trouvé]")

	var mm := _found(true)
	var screen := _make_screen(mm)
	_check("état trouvé", int(screen.display_state()) == int(_display["FOUND"]),
		str(screen.display_state()))
	_check("les deux cartes d'identité sont montrées", screen._cards.visible)
	_check("la mienne", _contains(screen, "Vada"), _imprint(screen))
	_check("celle de l'adversaire", _contains(screen, "Ombre"), _imprint(screen))
	_check("avec les classements donnés par le service",
		_contains(screen, "1181") and _contains(screen, "1248"), _imprint(screen))
	_check("et leurs catégories, telles quelles",
		_contains(screen, "Bougie II") and _contains(screen, "Lanterne I"),
		_imprint(screen))
	_check("le délai restant est affiché", _contains(screen, "8 s"), _imprint(screen))
	_check("confirmer est atteignable au curseur", screen._engage.visible
		and screen._engage.focus_mode != Control.FOCUS_NONE
		and not screen._engage.disabled, _button_state(screen._engage))
	# Refuser EST l'abandon dans cet état : il ne doit pas disparaître du parcours
	# du curseur au moment où le joueur en a le plus besoin.
	_check("refuser reste atteignable", screen.cancel_reachable())
	_check("les deux boutons ne se confondent pas",
		screen._engage.text != screen._withdraw.text,
		"%s / %s" % [screen._engage.text, screen._withdraw.text])
	_check("rien n'a été commandé par l'affichage", mm.commands() == 0, str(mm.commands()))
	_dispose(screen, mm)

	# Le délai s'arrondit vers le haut : afficher zéro alors qu'il reste une
	# fraction de seconde pour confirmer ferait perdre le match sur un affichage.
	var reste := _found(true)
	reste.remaining = 0.2
	var ecran := _make_screen(reste)
	_check("une fraction de seconde restante ne s'affiche pas zéro",
		_contains(ecran, "1 s") and not _contains(ecran, "0 s"), _imprint(ecran))
	_dispose(ecran, reste)

## En P2P, l'hôte simule tout et joue à 0 ms. Tant que ce n'est pas écrit,
## l'asymétrie devient une rumeur — et une rumeur ne se corrige pas.
func _test_qui_heberge() -> void:
	print("\n[Qui héberge]")

	var mien := _found(true)
	var chez_moi := _make_screen(mien)
	_check("l'hôte est connu", chez_moi.host_known())
	_check("l'écran dit que j'héberge", _contains(chez_moi, "Vous hébergez"),
		_imprint(chez_moi))
	_check("et pourquoi cela compte", _contains(chez_moi, "sans latence"),
		_imprint(chez_moi))

	var sien := _found(false)
	var chez_lui := _make_screen(sien)
	_check("l'hôte est connu aussi dans l'autre sens", chez_lui.host_known())
	_check("l'écran nomme l'hôte", _contains(chez_lui, "Ombre héberge"),
		_imprint(chez_lui))
	# La même explication des deux côtés : l'asymétrie est une propriété du P2P,
	# pas un reproche à celui qui en profite.
	_check("l'explication est la même des deux côtés",
		chez_moi._host_why.text == chez_lui._host_why.text,
		"%s / %s" % [chez_moi._host_why.text, chez_lui._host_why.text])
	_check("mais les deux annonces se distinguent",
		chez_moi._host.text != chez_lui._host.text)
	_dispose(chez_moi, mien)
	_dispose(chez_lui, sien)

	# Hôte pas encore désigné : le deviner à partir de qui cherchait donnerait une
	# réponse juste une fois sur deux, ce qui est pire que pas de réponse.
	var inconnu := _found(true)
	inconnu.host_set = false
	var ecran := _make_screen(inconnu)
	_check("sans désignation, l'écran ne devine pas", not ecran.host_known())
	_check("il l'écrit", _contains(ecran, "pas encore désigné"), _imprint(ecran))
	_check("et ne nomme personne", not _contains(ecran, "Vous hébergez")
		and not _contains(ecran, "Ombre héberge"), _imprint(ecran))
	# Les identités, elles, sont bien là : c'est le seul point qui manque.
	_check("les deux identités restent affichées",
		_contains(ecran, "Vada") and _contains(ecran, "Ombre"), _imprint(ecran))
	_dispose(ecran, inconnu)

	# Un adversaire sans pseudo n'empêche pas de dire qui héberge.
	var anonyme := _found(false)
	anonyme.opponent = {}
	var sans_nom := _make_screen(anonyme)
	_check("un adversaire sans pseudo est nommé « votre adversaire »",
		_contains(sans_nom, "Votre adversaire héberge"), _imprint(sans_nom))
	_dispose(sans_nom, anonyme)

func _test_attente() -> void:
	print("\n[En attente de l'autre]")

	var mm := _awaiting()
	var screen := _make_screen(mm)
	_check("état attente", int(screen.display_state()) == int(_display["AWAITING_PEER"]),
		str(screen.display_state()))
	_check("l'écran dit que c'est à lui de confirmer",
		_contains(screen, "à lui de confirmer"), _imprint(screen))
	_check("le délai restant est affiché", _contains(screen, "6 s"), _imprint(screen))
	# Confirmer une seconde fois n'a aucun sens : le bouton d'engagement disparaît,
	# et c'est le joueur lui-même qui a produit ce changement en confirmant.
	_check("plus rien à confirmer", not screen._engage.visible,
		_button_state(screen._engage))
	# Sans cela, un adversaire qui ne répond jamais retiendrait le joueur jusqu'à
	# expiration du délai — l'étape 8.4 exige l'annulation pendant l'attente.
	_check("renoncer reste atteignable au curseur", screen.cancel_reachable())
	_check("le curseur se pose sur ce seul contrôle",
		screen.focus_seed() == screen._withdraw)
	_check("les deux identités restent lisibles",
		_contains(screen, "Vada") and _contains(screen, "Ombre"), _imprint(screen))
	_check("et qui héberge aussi", screen.host_known())
	_dispose(screen, mm)

## Le refus adverse doit se lire comme un contretemps, pas comme un échec de son
## propre fait, et annoncer le retour en file — la garantie de l'étape 8.4.
func _test_refus_adverse() -> void:
	print("\n[Refus ou expiration de l'adversaire]")

	var mm := _declined()
	var screen := _make_screen(mm)
	_check("état refus", int(screen.display_state()) == int(_display["PEER_DECLINED"]),
		str(screen.display_state()))
	_check("la phrase du service est reprise telle quelle",
		_contains(screen, "n'a pas confirmé à temps"), _imprint(screen))
	_check("le retour en file est annoncé", _contains(screen, "sans perdre votre tour"),
		_imprint(screen))
	# On est de nouveau en file : le temps et la fourchette reprennent leur place,
	# sans quoi le joueur croirait la recherche arrêtée.
	_check("on est bien de nouveau en file", _contains(screen, "41 s"), _imprint(screen))
	_check("avec la fourchette cherchée", screen.bracket_shown())
	_check("l'abandon reste atteignable", screen.cancel_reachable())
	_check("aucune carte d'identité d'un match qui n'a pas eu lieu",
		not screen._cards.visible)
	_check("et aucun hôte pour un match sans adversaire", not screen.host_known())
	_dispose(screen, mm)

	# Sans phrase fournie, l'écran en a une — et elle n'accuse pas le joueur.
	var muet := _declined()
	muet.notice = ""
	var ecran := _make_screen(muet)
	_check("sans phrase fournie, l'écran en donne une",
		_contains(ecran, "confirmation"), _imprint(ecran))
	_check("le retour en file est annoncé quand même",
		_contains(ecran, "sans perdre votre tour"), _imprint(ecran))
	_dispose(ecran, muet)

## Six états, six affichages. Deux états qui se ressemblent à l'écran sont deux
## états que le joueur confondra — c'est exactement ce qui fait passer une
## installation sans identifiants pour une panne de serveur.
func _test_etats_distincts() -> void:
	print("\n[Six états, six affichages]")

	var imprints: Dictionary = {}
	for name in ["UNAVAILABLE", "IDLE", "SEARCHING", "FOUND", "AWAITING_PEER",
			"PEER_DECLINED"]:
		var mm := _stub_for(String(name))
		var screen := _make_screen(mm)
		_check("l'état %s est bien celui qu'on croit" % name,
			int(screen.display_state()) == int(_display[name]),
			str(screen.display_state()))
		imprints[name] = _imprint(screen)
		_dispose(screen, mm)

	var seen: Dictionary = {}
	var collisions := ""
	for name in imprints:
		var imprint: String = imprints[name]
		if seen.has(imprint):
			collisions += "%s = %s ; " % [seen[imprint], name]
		seen[imprint] = name
	_check("les six affichages sont distincts", collisions == "", collisions)

	# Les trois causes d'indisponibilité mènent au même état, et doivent pourtant
	# se lire différemment : envoyer un contributeur chercher une panne de serveur
	# qui n'existe pas coûte une soirée.
	var causes: Dictionary = {}
	var absent := _make_screen(null)
	causes["api absente"] = _imprint(absent)
	absent.free()

	var non_configure := Complet.new()
	non_configure.configured = false
	var e1 := _make_screen(non_configure)
	causes["non configuré"] = _imprint(e1)
	_dispose(e1, non_configure)

	var injoignable := Complet.new()
	injoignable.phase = String(_consts["PHASE_UNAVAILABLE"])
	injoignable.reason = "Le service d'appariement ne répond pas."
	var e2 := _make_screen(injoignable)
	causes["service muet"] = _imprint(e2)
	_dispose(e2, injoignable)

	var vus: Dictionary = {}
	var doublons := ""
	for cause in causes:
		if vus.has(causes[cause]):
			doublons += "%s = %s ; " % [vus[causes[cause]], cause]
		vus[causes[cause]] = cause
	_check("les trois causes d'indisponibilité se lisent différemment",
		doublons == "", doublons)

# ---------------------------------------------------------------------------
# LA MANETTE
# ---------------------------------------------------------------------------

## L'invariant du pouce : dans tout état engagé, il existe un contrôle d'abandon
## visible, focalisable et non désactivé. Un écran dont on ne peut pas sortir à la
## manette est un écran dont on ne peut pas sortir.
func _test_abandon_atteignable() -> void:
	print("\n[Abandon atteignable au curseur]")

	for name in ["SEARCHING", "FOUND", "AWAITING_PEER", "PEER_DECLINED"]:
		var mm := _stub_for(String(name))
		var screen := _make_screen(mm)
		_check("état %s : l'abandon est atteignable" % name, screen.cancel_reachable(),
			_button_state(screen._withdraw))
		_check("état %s : aucun bouton désactivé" % name, _no_disabled_button(screen))
		_dispose(screen, mm)

	# Aucun état, engagé ou non, ne doit produire un bouton grisé : un contrôle
	# désactivé sort du parcours du curseur, et le voir sortir en pleine action
	# ressemble exactement à un défaut.
	for name in ["UNAVAILABLE", "IDLE", "SEARCHING", "FOUND", "AWAITING_PEER",
			"PEER_DECLINED"]:
		var mm := _stub_for(String(name))
		var screen := _make_screen(mm)
		_check("état %s : le curseur a toujours où se poser" % name,
			screen.focus_seed() != null)
		_dispose(screen, mm)

	# Le contrôle d'abandon garde sa place quand le match est trouvé pendant la
	# recherche. Un unique bouton passant de ANNULER à CONFIRMER confirmerait un
	# match à qui appuyait pour sortir de la file — c'est la raison pour laquelle
	# les deux emplacements sont rangés par intention et non par importance.
	var mm := _searching()
	var screen := _make_screen(mm)
	var abandon_avant: Button = screen._withdraw
	_check("l'emplacement d'abandon est le seul visible en recherche",
		not screen._engage.visible and screen._withdraw.visible)
	mm.phase = String(_consts["PHASE_FOUND"])
	mm.remaining = 8.0
	mm.me = {"nickname": "Vada"}
	mm.opponent = {"nickname": "Ombre"}
	mm.host_set = true
	mm.host_is_me = false
	screen.refresh()
	_check("il reste le même contrôle après l'appariement",
		screen._withdraw == abandon_avant)
	_check("et il abandonne toujours, il ne confirme pas",
		screen._withdraw.text == "REFUSER", screen._withdraw.text)
	screen._withdraw.pressed.emit()
	_check("un appui y refuse, sans jamais confirmer",
		mm.declines == 1 and mm.accepts == 0,
		"refus=%d confirmations=%d" % [mm.declines, mm.accepts])
	_dispose(screen, mm)

# ---------------------------------------------------------------------------
# IDEMPOTENCE, ET L'AFFICHAGE QUI NE COMMANDE RIEN
# ---------------------------------------------------------------------------

func _test_idempotence() -> void:
	print("\n[Idempotence de refresh()]")

	for name in ["UNAVAILABLE", "IDLE", "SEARCHING", "FOUND", "AWAITING_PEER",
			"PEER_DECLINED"]:
		var mm := _stub_for(String(name))
		var screen := _make_screen(mm)
		var once := _imprint(screen)
		screen.refresh()
		screen.refresh()
		screen.refresh()
		_check("état %s : trois rafraîchissements ne changent rien" % name,
			_imprint(screen) == once, "%s ≠ %s" % [_imprint(screen), once])
		_dispose(screen, mm)

	# Sans appariement du tout, l'idempotence doit tenir aussi : c'est l'état de
	# tout dépôt frais, donc celui que tout le monde rencontre en premier.
	var seul := _make_screen(null)
	var avant := _imprint(seul)
	seul.refresh()
	seul.refresh()
	_check("sans appariement, l'affichage est stable lui aussi",
		_imprint(seul) == avant)
	seul.free()

## `refresh()` lit et met en page ; il ne commande rien. Le contraire mettrait le
## joueur en file au simple passage sur l'écran — et en classé, l'engagerait dans
## un match qu'il n'a pas demandé.
func _test_affichage_ne_lance_rien() -> void:
	print("\n[L'affichage ne commande rien]")

	for name in ["UNAVAILABLE", "IDLE", "SEARCHING", "FOUND", "AWAITING_PEER",
			"PEER_DECLINED"]:
		var mm := _stub_for(String(name))
		var screen := _make_screen(mm)
		screen.refresh()
		screen.refresh()
		_check("état %s : aucune commande émise par l'affichage" % name,
			mm.commands() == 0, str(mm.commands()))
		_dispose(screen, mm)

	# Y compris quand le hub annonce la nature de la file : cet appel rafraîchit,
	# il n'engage pas.
	var mm := _idle()
	var screen := _make_screen(mm)
	screen.set_ranked_queue(true)
	screen.set_ranked_queue(false)
	_check("annoncer la nature de la file n'engage rien", mm.commands() == 0,
		str(mm.commands()))
	_dispose(screen, mm)

# ---------------------------------------------------------------------------
# LES COMMANDES
# ---------------------------------------------------------------------------

func _test_commandes() -> void:
	print("\n[Les boutons commandent ce qu'ils annoncent]")

	var repos := _idle()
	var e1 := _make_screen(repos)
	e1._engage.pressed.emit()
	_check("au repos, l'engagement lance une recherche", repos.starts.size() == 1,
		str(repos.starts))
	_dispose(e1, repos)

	var file := _searching()
	var e2 := _make_screen(file)
	file.cancels = 0
	e2._withdraw.pressed.emit()
	_check("en recherche, l'abandon annule la recherche", file.cancels == 1,
		str(file.cancels))
	_check("et ne refuse aucun match", file.declines == 0, str(file.declines))
	_dispose(e2, file)

	var trouve := _found(true)
	var e3 := _make_screen(trouve)
	e3._engage.pressed.emit()
	_check("sur un match trouvé, l'engagement confirme", trouve.accepts == 1,
		str(trouve.accepts))
	_check("et ne relance pas de recherche", trouve.starts.is_empty(),
		str(trouve.starts))
	_dispose(e3, trouve)

	var attente := _awaiting()
	var e4 := _make_screen(attente)
	e4._withdraw.pressed.emit()
	_check("pendant l'attente, l'abandon quitte la file", attente.cancels == 1,
		str(attente.cancels))
	_dispose(e4, attente)

	var refuse := _declined()
	var e5 := _make_screen(refuse)
	e5._withdraw.pressed.emit()
	_check("après un refus adverse, l'abandon quitte la file", refuse.cancels == 1,
		str(refuse.cancels))
	_dispose(e5, refuse)

	# Un emplacement masqué ne porte aucune action : un appui déclenché autrement
	# qu'au curseur — un signal rejoué, un test — ne doit rien engager.
	var masque := _searching()
	var e6 := _make_screen(masque)
	e6._engage.pressed.emit()
	_check("un emplacement masqué ne commande rien", masque.commands() == 0,
		str(masque.commands()))
	_dispose(e6, masque)

	# API partielle : les boutons ne peuvent rien commander, et l'écran est déjà
	# passé en « indisponible » — c'est ce qui évite un bouton mort.
	var partiel := Partiel.new()
	var e7 := _make_screen(partiel)
	e7._engage.pressed.emit()
	_check("avec une API partielle, aucun appui ne plante", true)
	_dispose(e7, partiel)

## L'amical est le défaut, le classé est explicite. L'étape 8.1 le tranche : un
## bogue de branchement ne doit pas pouvoir *ajouter* des matchs au classement —
## l'inverse se rattrape par un rejeu, pas celui-là.
func _test_file_classee() -> void:
	print("\n[File classée ou amicale]")

	var amical := _idle()
	var e1 := _make_screen(amical)
	_check("par défaut, la file est amicale", not e1.queue_is_ranked())
	_check("et l'écran le dit", _contains(e1, "ne comptera pas"), _imprint(e1))
	e1._engage.pressed.emit()
	_check("la recherche lancée est amicale", amical.starts == [false],
		str(amical.starts))
	_dispose(e1, amical)

	var classe := _idle()
	var e2 := _make_screen(classe)
	e2.set_ranked_queue(true)
	_check("le hub peut annoncer une file classée", e2.queue_is_ranked())
	_check("et l'écran l'affiche", _contains(e2, "comptera pour votre classement"),
		_imprint(e2))
	e2._engage.pressed.emit()
	_check("la recherche lancée est classée", classe.starts == [true],
		str(classe.starts))
	# Idempotent : le rappeler avec la même valeur ne coûte qu'un rafraîchissement.
	var avant := _imprint(e2)
	e2.set_ranked_queue(true)
	_check("le redire ne change rien", _imprint(e2) == avant)
	_dispose(e2, classe)

# ---------------------------------------------------------------------------
# L'HORLOGE
# ---------------------------------------------------------------------------

## Le temps écoulé change chaque seconde ; le reste ne change que sur événement.
## Repeindre tout l'écran à la seconde le ferait scintiller et déplacerait le
## focus du curseur — sur un écran qu'on regarde parfois une minute d'affilée,
## c'est intenable.
func _test_horloge() -> void:
	print("\n[L'horloge, et ce qu'elle ne touche pas]")

	var mm := _searching()
	var screen := _make_screen(mm)
	var hors_horloge := _imprint_hors_horloge(screen)
	var horloge: String = screen._clock.text

	# Sous la cadence, rien ne bouge : l'écran ne se réétiquette pas à chaque
	# image, sinon les fps déplafonnés du jeu le repeindraient des centaines de
	# fois par seconde.
	mm.elapsed = 90.0
	screen._tick(0.4)
	_check("un battement partiel ne réétiquette rien", screen._clock.text == horloge,
		screen._clock.text)

	screen._tick(0.7)
	_check("passé la seconde, l'horloge avance", screen._clock.text != horloge,
		screen._clock.text)
	_check("et affiche le temps du service", _contains(screen, "1 min 30 s"),
		_imprint(screen))
	_check("rien d'autre n'a bougé", _imprint_hors_horloge(screen) == hors_horloge,
		"%s ≠ %s" % [_imprint_hors_horloge(screen), hors_horloge])
	_dispose(screen, mm)

	# Un palier de fourchette non plus : c'est pour cela que la fourchette est
	# exclue de l'empreinte qui décide d'un repeint complet.
	var palier := _searching()
	var e2 := _make_screen(palier)
	var fixe := _imprint_hors_horloge(e2)
	palier.bracket = [820, 1250]
	palier.elapsed = 60.0
	e2._tick(1.0)
	_check("l'élargissement de la fourchette s'affiche",
		_contains(e2, "820") and _contains(e2, "1250"), _imprint(e2))
	_check("sans repeindre le reste", _imprint_hors_horloge(e2) == fixe,
		"%s ≠ %s" % [_imprint_hors_horloge(e2), fixe])
	_dispose(e2, palier)

	# Filet de sécurité : un appariement qui n'émettrait aucun signal doit tout de
	# même voir son changement de phase pris en compte à la seconde suivante,
	# sinon le joueur reste devant « en recherche » alors qu'un adversaire
	# l'attend, jusqu'à expiration du délai.
	var muet := _searching()
	var e3 := _make_screen(muet)
	muet.phase = String(_consts["PHASE_FOUND"])
	muet.remaining = 9.0
	muet.me = {"nickname": "Vada", "rating": 1181}
	muet.opponent = {"nickname": "Ombre", "rating": 1248}
	muet.host_set = true
	muet.host_is_me = true
	e3._tick(1.0)
	_check("un changement de phase est vu même sans signal",
		int(e3.display_state()) == int(_display["FOUND"]), str(e3.display_state()))
	_check("et l'écran est repeint en entier", e3._cards.visible
		and _contains(e3, "Vous hébergez"), _imprint(e3))
	_dispose(e3, muet)

	# Au repos, rien ne tourne : un écran de menu n'a pas à relire l'appariement
	# une fois par seconde pendant toute la partie.
	var repos := _idle()
	var e4 := _make_screen(repos)
	_check("au repos, l'horloge ne tourne pas", not e4.is_processing())
	_dispose(e4, repos)

	var file := _searching()
	var e5 := _make_screen(file)
	_check("en recherche, elle tourne", e5.is_processing())
	file.phase = String(_consts["PHASE_IDLE"])
	e5.refresh()
	_check("et elle s'arrête quand la file se vide", not e5.is_processing())
	_dispose(e5, file)

	# Sans clé `elapsed`, aucune durée n'est affichée : un temps recomposé ici
	# diverge de celui de la file, et deux compteurs qui se contredisent valent
	# moins qu'un seul absent.
	var sans_temps := _searching()
	sans_temps.elapsed = -1.0
	var e6 := _make_screen(sans_temps)
	_check("sans temps communiqué, aucune durée n'est affichée",
		e6._clock.text == "", e6._clock.text)
	_check("mais la fourchette reste annoncée", e6.bracket_shown())
	_dispose(e6, sans_temps)

# ---------------------------------------------------------------------------
# RIEN N'EST INVENTÉ
# ---------------------------------------------------------------------------

func _test_aucun_chiffre_invente() -> void:
	print("\n[Aucun chiffre inventé]")

	# Les états sans information chiffrée n'en affichent aucune. Un « 1000 »
	# glissé là serait faux d'une manière parfaitement plausible.
	for name in ["UNAVAILABLE", "IDLE"]:
		var mm := _stub_for(String(name))
		var screen := _make_screen(mm)
		_check("état %s : aucun chiffre à l'écran" % name,
			not _has_digit(_texts(screen, [])), _texts(screen, []))
		_dispose(screen, mm)

	# Un adversaire dont on ne connaît pas le classement rend un tiret, pas un
	# zéro : les deux ne se ressemblent que dans le code. À l'écran, « 0 point »
	# est une affirmation, et elle serait fausse.
	var mm := _found(true)
	mm.opponent = {"nickname": "Ombre"}
	var screen := _make_screen(mm)
	_check("un classement absent rend un tiret",
		(screen._card_them["stats"] as Label).text == "—",
		(screen._card_them["stats"] as Label).text)
	_check("et surtout pas un zéro", not _contains(screen, "0 points"),
		_imprint(screen))
	_dispose(screen, mm)

	# Une catégorie ne se déduit pas d'un classement : l'échelle a un seul
	# propriétaire, et c'est le serveur. 1000 points est le centre exact de
	# Bougie II — si l'écran savait la calculer, c'est ici qu'il le montrerait.
	var brut := _found(true)
	brut.me = {"nickname": "Vada", "rating": 1000}
	brut.opponent = {"nickname": "Ombre", "rating": 1000}
	var ecran := _make_screen(brut)
	var deduced := ""
	for tier in ["Aveugle", "Braise", "Bougie", "Lanterne", "Torche", "Brasier",
			"Phare", "Aurore", "Zénith", "Candela"]:
		if _contains(ecran, String(tier)):
			deduced = String(tier)
			break
	_check("aucune catégorie n'est déduite du classement", deduced == "", deduced)
	_check("le classement fourni, lui, s'affiche", _contains(ecran, "1000"),
		_imprint(ecran))
	_dispose(ecran, brut)

	# Tout nombre relu d'un JSON revient en flottant : un classement `1181` vaut
	# `1181.0`, et le recopier tel quel afficherait « 1181.0 points ».
	var flottant := _found(true)
	flottant.me = {"nickname": "Vada", "rating": 1181.0}
	flottant.opponent = {"nickname": "Ombre", "rating": 1248.0}
	flottant.bracket = [950.0, 1120.0]
	flottant.remaining = 8.0
	var e2 := _make_screen(flottant)
	_check("aucun « .0 » à l'écran", _imprint(e2).find(".0") < 0, _imprint(e2))
	_check("les classements s'affichent en entiers",
		_contains(e2, "1181") and _contains(e2, "1248"), _imprint(e2))
	_dispose(e2, flottant)

	# Une fourchette en flottants passe par le même chemin.
	var borne := _searching()
	borne.bracket = [950.0, 1120.0]
	var e3 := _make_screen(borne)
	_check("les bornes de la fourchette non plus",
		e3._bracket.text.find(".0") < 0 and _contains(e3, "950"), e3._bracket.text)
	_dispose(e3, borne)

	# Un adversaire absent dans un état apparié : l'écran ne fabrique pas de
	# pseudo. Ce n'est pas censé arriver, et c'est exactement pourquoi il faut
	# savoir ce que l'écran en fait.
	var creux := _found(true)
	creux.me = {}
	creux.opponent = {}
	var e4 := _make_screen(creux)
	_check("sans identités, l'écran ne plante pas et n'invente rien",
		int(e4.display_state()) == int(_display["FOUND"]), str(e4.display_state()))
	_check("les deux cartes rendent un tiret",
		(e4._card_me["nickname"] as Label).text == "—"
		and (e4._card_them["nickname"] as Label).text == "—")
	_dispose(e4, creux)

## L'écran ne navigue pas : il demande, le hub tranche. Et l'identifiant demandé
## doit exister, sans quoi le hub refuse en silence et le bouton paraît mort.
func _test_porte_de_sortie() -> void:
	print("\n[La porte de sortie]")

	var mm := Complet.new()
	mm.configured = false
	var screen := _make_screen(mm)
	var vus: Array[String] = []
	screen.navigate_requested.connect(func(id: String) -> void: vus.append(id))
	screen._engage.pressed.emit()
	_check("l'écran demande la navigation, il ne la décide pas",
		vus == [String(_consts["FRIENDLY_SCREEN"])], str(vus))
	_check("et ne commande rien à l'appariement", mm.commands() == 0,
		str(mm.commands()))
	_dispose(screen, mm)

## La réponse du service arrive bien après la demande. Sans liaison, un
## appariement trouvé pendant que l'écran est affiché n'arriverait jamais jusqu'à
## lui : le joueur verrait « en recherche » alors que son adversaire l'attend.
func _test_signal() -> void:
	print("\n[Le signal de l'appariement]")

	var mm := _searching()
	var screen := _make_screen(mm)
	var avant := _imprint(screen)

	mm.phase = String(_consts["PHASE_FOUND"])
	mm.remaining = 10.0
	mm.me = {"nickname": "Vada", "rating": 1181}
	mm.opponent = {"nickname": "Ombre", "rating": 1248}
	mm.host_set = true
	mm.host_is_me = false
	mm.state_changed.emit(0)

	_check("un appariement trouvé rafraîchit l'écran tout seul",
		_imprint(screen) != avant)
	_check("et l'écran passe à l'état trouvé",
		int(screen.display_state()) == int(_display["FOUND"]), str(screen.display_state()))
	_check("avec les deux identités", _contains(screen, "Vada")
		and _contains(screen, "Ombre"), _imprint(screen))
	_check("et qui héberge", _contains(screen, "Ombre héberge"), _imprint(screen))
	# Rebrancher la réponse sur une commande produirait une commande par réponse,
	# donc une boucle.
	_check("sans commander quoi que ce soit", mm.commands() == 0, str(mm.commands()))

	# Un seul branchement : le hub construit ses écrans une fois pour toute la
	# partie, et un signal branché trois fois repeint trois fois.
	screen.refresh()
	screen.refresh()
	_check("le signal n'est branché qu'une fois",
		mm.get_signal_connection_list("state_changed").size() == 1,
		str(mm.get_signal_connection_list("state_changed").size()))
	_dispose(screen, mm)
