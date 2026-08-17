## Test headless de l'écran de classement (`screen_leaderboard.gd`).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • LA propriété à ne jamais laisser régresser — **aucun état n'affiche un
##     chiffre que le serveur n'a pas donné**. Un joueur identifié mais jamais
##     classé n'a pas « 1000 points » : le classement de départ n'est attribué
##     qu'au premier match concordant, et l'afficher avant serait faux d'une
##     manière parfaitement plausible, donc invisible ;
##   • les six états réels se distinguent à l'écran — non configuré,
##     identification, échec, lecture, non classé, classé — parce que c'est là
##     que vit un écran de classement, pas dans le cas heureux ;
##   • `refresh()` est idempotent dans chacun d'eux, y compris avant toute
##     construction, et c'est bien lui qui relance la lecture ;
##   • le rang n'est jamais recalculé ici : l'échelle a un seul propriétaire, et
##     c'est le serveur ;
##   • un joueur hors des dix premiers voit sa ligne à part.
##
## Le réseau n'est pas joignable en headless, et `supabase_config.gd` n'est même
## pas versionné : c'est précisément pourquoi l'identité est simulée. Les états
## dégradés SONT le sujet — ce sont eux que le vrai serveur ne montrera jamais.
##
## Lancer : godot --headless --path . --script res://tools/test_screen_leaderboard.gd
extends SceneTree

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, `_init()`
## s'exécute avant les autoloads ET avant le cache des classes globales. Un
## `class_name` référencé trop tôt rend un objet nu, les SCRIPT ERROR
## n'incrémentent aucun compteur, et la suite annonce « tous les tests passent »
## sans avoir rien exécuté.
var _screen_script: GDScript
var _identity_script: GDScript
## `ScreenLeaderboard.Display`, relu de la table des constantes plutôt que du
## `class_name`.
var _display: Dictionary = {}

# ---------------------------------------------------------------------------
# IDENTITÉ SIMULÉE
# ---------------------------------------------------------------------------
#
# Deux doublures, et la différence entre elles est le sujet d'un test à part
# entière : `Ancienne` reproduit `ranked_identity.gd` TEL QU'IL EST AUJOURD'HUI
# — il ne garde de la réponse du serveur que la ligne du joueur, et jette le
# `top`. `Complete` y ajoute la méthode que l'écran attend. L'écran doit rester
# honnête avec l'une comme avec l'autre.

class Ancienne extends Node:
	enum State { UNCONFIGURED, INITIALIZING, READY, FAILED }

	signal state_changed(state: int)
	signal standing_changed

	var state: int = State.UNCONFIGURED
	var profile_id: String = ""
	var nickname: String = ""
	var last_error: String = ""
	var rating: int = 0
	var rank: int = 0
	var matches_played: int = 0
	var wins: int = 0
	var losses: int = 0
	var draws: int = 0
	var is_ranked: bool = false

	## Compté pour vérifier que `refresh()` relance bien la lecture.
	var refresh_calls: int = 0

	func refresh_standing() -> void:
		refresh_calls += 1

class Complete extends Ancienne:
	var loaded: bool = false
	var error: String = ""
	var top: Array = []

	func standing_snapshot() -> Dictionary:
		return {"loaded": loaded, "error": error, "top": top}

# ---------------------------------------------------------------------------

func _init() -> void:
	print("=== Test de l'écran de classement ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : l'écran de classement est absent ou incomplet")
		quit(1)
		return

	_test_contrat()
	_test_non_configure()
	_test_identification()
	_test_echec()
	_test_lecture()
	_test_pas_encore_classe()
	_test_tableau_vide()
	_test_dans_le_top()
	_test_hors_du_top()
	_test_etats_distincts()
	_test_idempotence()
	_test_relance()
	_test_flottants()
	_test_rang_non_recalcule()
	_test_sans_tableau()

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
# la ROADMAP, il a déjà été payé une fois.
func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	_screen_script = load("res://screen_leaderboard.gd") as GDScript
	_identity_script = load("res://ranked_identity.gd") as GDScript

	var ok := true
	for pair in [["screen_leaderboard.gd", _screen_script],
			["ranked_identity.gd", _identity_script]]:
		if pair[1] == null:
			printerr("  ✗ script introuvable ou non compilé : ", pair[0])
			ok = false
	if not ok:
		return false

	if String(_screen_script.get_global_name()) != "ScreenLeaderboard":
		printerr("  ✗ class_name attendu : ScreenLeaderboard, obtenu : ",
			_screen_script.get_global_name())
		ok = false

	var base: Script = _screen_script.get_base_script()
	if base == null or base.resource_path != "res://hub_screen.gd":
		printerr("  ✗ l'écran doit hériter de hub_screen.gd")
		ok = false

	var probe: Object = _screen_script.new()
	for method in ["screen_title", "build", "refresh", "focus_seed", "display_state",
			"table_reachable", "table_is_empty", "is_outside_top"]:
		if not probe.has_method(method):
			printerr("  ✗ ScreenLeaderboard : méthode manquante : ", method)
			ok = false
	probe.free()

	var constants: Dictionary = _screen_script.get_script_constant_map()
	for key in ["Display", "Identity", "SNAPSHOT_METHOD", "TIER_KEY", "TOP_ROWS"]:
		if not constants.has(key):
			printerr("  ✗ ScreenLeaderboard : constante manquante : ", key)
			ok = false
	if not ok:
		return false

	_display = constants["Display"]
	if _display.size() != 6:
		printerr("  ✗ Display doit porter les six états réels, il en porte ",
			_display.size())
		ok = false

	# Le miroir de `RankedIdentity.State` est une copie, donc une dette : si
	# l'autoload réordonne son énumération, l'écran lirait « prêt » là où le
	# serveur dit « échec », sans la moindre erreur pour le signaler.
	var mirrored: Dictionary = constants["Identity"]
	var real: Variant = _identity_script.get_script_constant_map().get("State", null)
	if not real is Dictionary:
		printerr("  ✗ RankedIdentity.State introuvable")
		ok = false
	elif mirrored != real:
		printerr("  ✗ le miroir de RankedIdentity.State a dérivé : ",
			str(mirrored), " ≠ ", str(real))
		ok = false

	# La doublure doit refléter le vrai autoload, sinon elle prouverait tout.
	var stub_states := {
		"UNCONFIGURED": Ancienne.State.UNCONFIGURED,
		"INITIALIZING": Ancienne.State.INITIALIZING,
		"READY": Ancienne.State.READY,
		"FAILED": Ancienne.State.FAILED,
	}
	if real is Dictionary and stub_states != real:
		printerr("  ✗ la doublure ne reproduit pas RankedIdentity.State")
		ok = false
	for field in ["profile_id", "nickname", "last_error", "rating", "rank",
			"matches_played", "wins", "losses", "draws", "is_ranked", "state"]:
		if not _identity_has(field):
			printerr("  ✗ RankedIdentity : propriété attendue absente : ", field)
			ok = false

	if ok:
		print("  ✓ l'écran, son contrat et le miroir d'état sont en place")
	return ok

## Le vrai autoload porte-t-il bien cette propriété ? On instancie le script
## détaché de l'arbre : `_ready()` n'est pas appelé, donc rien ne part sur le
## réseau et aucun profil n'est créé dans la vraie base.
func _identity_has(property: String) -> bool:
	var probe: Node = _identity_script.new()
	var found := false
	for entry in probe.get_property_list():
		if String(entry.get("name", "")) == property:
			found = true
			break
	probe.free()
	return found

# ---------------------------------------------------------------------------
# OUTILLAGE
# ---------------------------------------------------------------------------

## Un écran construit, branché sur l'identité donnée. L'appelant libère les deux.
func _make_screen(identity: Node) -> Control:
	var screen: Control = _screen_script.new()
	screen.identity_override = identity
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	return screen

## Identité prête, classée ou non, avec un tableau lu.
func _ready_identity(top: Array, ranked: bool) -> Complete:
	var identity := Complete.new()
	identity.state = Ancienne.State.READY
	identity.nickname = "Vada"
	identity.profile_id = "moi"
	identity.loaded = true
	identity.top = top
	identity.is_ranked = ranked
	return identity

## Un tableau de tête plausible. **Aucun classement à 1000** : c'est ce qui rend
## le test capable de distinguer un chiffre venu du serveur d'un chiffre inventé
## par l'écran.
func _sample_top() -> Array:
	return [
		{"player_id": "a", "nickname": "Ombre", "rating": 1248, "rank": 1,
			"matches": 22, "wins": 16, "losses": 5, "draws": 1},
		{"player_id": "b", "nickname": "Cierge", "rating": 1181, "rank": 2,
			"matches": 19, "wins": 12, "losses": 7, "draws": 0},
		{"player_id": "c", "nickname": "Suie", "rating": 1094, "rank": 3,
			"matches": 14, "wins": 7, "losses": 6, "draws": 1},
	]

## Tout le texte que le joueur lit, et rien d'autre — sans quoi les chiffres de
## la forme du tableau se mêleraient aux chiffres affichés, et le contrôle
## « aucun chiffre inventé » ne voudrait plus rien dire.
func _texts(screen: Control) -> String:
	var texts := PackedStringArray()
	_collect_text(screen, texts)
	return "¦".join(texts)

## Tout ce que l'écran montre effectivement : le texte visible, plus la forme du
## tableau. Deux états qui rendent la même empreinte sont indiscernables pour le
## joueur, quelles que soient les différences internes.
func _imprint(screen: Control) -> String:
	return "%s | lignes=%d | maligne=%s" % [
		_texts(screen), _visible_rows(screen), _mine_visible(screen)]

func _collect_text(node: Node, out: PackedStringArray) -> void:
	var control := node as Control
	if control != null and not control.visible:
		return
	var label := node as Label
	if label != null and label.text != "":
		out.append(label.text)
	for child in node.get_children():
		_collect_text(child, out)

func _visible_rows(screen: Control) -> int:
	var count := 0
	for row in screen._rows:
		if (row["panel"] as Control).visible:
			count += 1
	return count

func _mine_visible(screen: Control) -> bool:
	return (screen._mine_row["panel"] as Control).visible

func _contains(screen: Control, needle: String) -> bool:
	return _texts(screen).find(needle) >= 0

func _has_digit(text: String) -> bool:
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			return true
	return false

func _dispose(screen: Control, identity: Node) -> void:
	screen.free()
	identity.free()

# ---------------------------------------------------------------------------
# LE CONTRAT DE HubScreen
# ---------------------------------------------------------------------------

func _test_contrat() -> void:
	print("\n[Contrat d'écran]")

	# Le hub appelle `refresh()` avant le premier affichage, parfois avant même
	# que `build()` ait eu lieu. Sans cette garantie, l'ordre d'ouverture des
	# écrans devient une dépendance cachée.
	var orphelin: Control = _screen_script.new()
	orphelin.refresh()
	orphelin.refresh()
	_check("rafraîchir avant construction ne plante pas", true)
	_check("l'écran a un titre", String(orphelin.screen_title()).strip_edges() != "")
	_check("aucune amorce de curseur avant construction", orphelin.focus_seed() == null)
	orphelin.free()

	var identity := _ready_identity(_sample_top(), false)
	var screen := _make_screen(identity)
	var seed: Control = screen.focus_seed()
	_check("le curseur a où se poser une fois construit", seed != null)
	_check("et cette cible est atteignable à la manette",
		seed != null and seed.focus_mode != Control.FOCUS_NONE)

	# Construire deux fois ne doit pas empiler un second tableau : le hub peut
	# reremplir un écran en plusieurs passes.
	var before: int = screen._rows.size()
	screen.build(screen.get_child(0))
	_check("construire deux fois ne duplique rien", screen._rows.size() == before,
		"%d puis %d" % [before, screen._rows.size()])
	_dispose(screen, identity)

# ---------------------------------------------------------------------------
# LES SIX ÉTATS
# ---------------------------------------------------------------------------

## Le cas du nouveau contributeur, et celui de toute exécution headless :
## `supabase_config.gd` est ignoré par git. Le jeu se joue normalement — l'écran
## doit le dire, et surtout ne pas ressembler à une panne.
func _test_non_configure() -> void:
	print("\n[Non configuré]")

	var identity := Ancienne.new()
	var screen := _make_screen(identity)
	_check("état non configuré", int(screen.display_state()) == int(_display["UNCONFIGURED"]),
		str(screen.display_state()))
	_check("aucun tableau n'est promis", not screen.table_reachable())
	_check("aucune ligne affichée", _visible_rows(screen) == 0)
	_check("l'écran dit que le jeu se joue quand même",
		_contains(screen, "jeu se joue"), _imprint(screen))
	_check("et il n'invente aucun chiffre", not _has_digit(_texts(screen)),
		_texts(screen))
	_dispose(screen, identity)

	# Sans autoload du tout — l'écran hors de l'arbre — la conclusion est la
	# même, et c'est la seule honnête. C'est aussi le chemin qui construit tout
	# le tableau sans personne à qui le comparer : il a déjà levé une erreur de
	# script, qui n'a fait échouer aucun test parce qu'aucune ne les compte.
	var seul: Control = _screen_script.new()
	var body := VBoxContainer.new()
	seul.add_child(body)
	seul.build(body)
	_check("sans identité joignable, même conclusion",
		int(seul.display_state()) == int(_display["UNCONFIGURED"]))
	_check("et le tableau se construit sans personne à comparer",
		_visible_rows(seul) == 0 and not _mine_visible(seul))
	seul.refresh()
	_check("un rafraîchissement de plus n'y change rien",
		int(seul.display_state()) == int(_display["UNCONFIGURED"]))
	seul.free()

func _test_identification() -> void:
	print("\n[Identification en cours]")

	var identity := Complete.new()
	identity.state = Ancienne.State.INITIALIZING
	var screen := _make_screen(identity)
	_check("état identification", int(screen.display_state()) == int(_display["IDENTIFYING"]),
		str(screen.display_state()))
	_check("aucune ligne tant qu'on ne sait pas qui demande", _visible_rows(screen) == 0)
	_check("aucun chiffre inventé pendant l'attente", not _has_digit(_texts(screen)),
		_texts(screen))
	_dispose(screen, identity)

func _test_echec() -> void:
	print("\n[Échec]")

	# Échec d'identification : la phrase du serveur est déjà rédigée pour le
	# joueur, la reformuler perdrait la cause exacte du refus.
	var identity := Complete.new()
	identity.state = Ancienne.State.FAILED
	identity.last_error = "Epic est injoignable : le classement attend une identité Epic."
	var screen := _make_screen(identity)
	_check("état échec", int(screen.display_state()) == int(_display["FAILED"]),
		str(screen.display_state()))
	_check("la cause exacte est reprise telle quelle",
		_contains(screen, "Epic est injoignable"), _imprint(screen))
	_dispose(screen, identity)

	# Identifié, mais la lecture du tableau a échoué. C'est un autre chemin, et
	# il ne doit pas laisser l'écran en « lecture… » pour toujours.
	var lu := _ready_identity([], true)
	lu.error = "Classement momentanément indisponible."
	var apres := _make_screen(lu)
	_check("une lecture refusée n'est pas une lecture en cours",
		int(apres.display_state()) == int(_display["FAILED"]), str(apres.display_state()))
	_check("et la raison s'affiche", _contains(apres, "momentanément indisponible"),
		_imprint(apres))
	_dispose(apres, lu)

func _test_lecture() -> void:
	print("\n[Lecture en cours]")

	var identity := Complete.new()
	identity.state = Ancienne.State.READY
	identity.nickname = "Vada"
	identity.loaded = false
	var screen := _make_screen(identity)
	_check("état lecture", int(screen.display_state()) == int(_display["LOADING"]),
		str(screen.display_state()))
	_check("un tableau vide non lu n'est pas un tableau vide",
		not screen.table_is_empty())
	_check("aucun chiffre pendant la lecture", not _has_digit(_texts(screen)),
		_texts(screen))
	_dispose(screen, identity)

## LE test de la suite. Un profil existe, il est reconnu, il n'a jamais joué de
## match classé. Le serveur ne lui donne AUCUN chiffre — le classement de départ
## n'est attribué qu'au premier match concordant — et l'écran ne doit pas en
## fabriquer un pour remplir la case.
func _test_pas_encore_classe() -> void:
	print("\n[Profil connu, jamais classé]")

	var identity := _ready_identity(_sample_top(), false)
	var screen := _make_screen(identity)
	_check("état non classé", int(screen.display_state()) == int(_display["UNRANKED"]),
		str(screen.display_state()))
	_check("aucune ligne à part pour un joueur sans classement",
		not screen.is_outside_top() and not _mine_visible(screen))
	_check("la phrase d'état ne porte aucun chiffre",
		not _has_digit(screen._status.text), screen._status.text)
	_check("le classement de départ n'est PAS affiché",
		not _contains(screen, "1000"), _imprint(screen))
	# Le tableau des autres, lui, reste visible : leurs chiffres viennent du
	# serveur et n'ont rien à voir avec l'absence des miens.
	_check("le tableau des autres reste affiché", _visible_rows(screen) == 3,
		str(_visible_rows(screen)))
	_dispose(screen, identity)

func _test_tableau_vide() -> void:
	print("\n[Tableau vide]")

	var identity := _ready_identity([], false)
	var screen := _make_screen(identity)
	_check("le tableau est lu et vide", screen.table_is_empty())
	_check("aucune ligne", _visible_rows(screen) == 0)
	_check("l'écran l'explique", _contains(screen, "Personne n'a encore joué"),
		_imprint(screen))
	_check("et n'invente toujours pas de chiffre", not _contains(screen, "1000"),
		_imprint(screen))
	_dispose(screen, identity)

func _test_dans_le_top() -> void:
	print("\n[Le joueur est dans les dix]")

	var top := _sample_top()
	top[1]["player_id"] = "moi"
	top[1]["nickname"] = "Vada"
	var identity := _ready_identity(top, true)
	identity.rating = 1181
	identity.rank = 2
	identity.matches_played = 19
	identity.wins = 12
	identity.losses = 7
	var screen := _make_screen(identity)

	_check("état classé", int(screen.display_state()) == int(_display["RANKED"]),
		str(screen.display_state()))
	_check("pas de ligne à part quand on est déjà dans le tableau",
		not screen.is_outside_top() and not _mine_visible(screen))
	_check("les chiffres affichés sont ceux du serveur",
		_contains(screen, "1181") and _contains(screen, "2e"), _imprint(screen))
	_dispose(screen, identity)

func _test_hors_du_top() -> void:
	print("\n[Le joueur est hors des dix]")

	var identity := _ready_identity(_sample_top(), true)
	identity.rating = 812
	identity.rank = 47
	identity.matches_played = 9
	identity.wins = 2
	identity.losses = 6
	identity.draws = 1
	var screen := _make_screen(identity)

	_check("l'écran sait qu'il est hors du tableau", screen.is_outside_top())
	_check("sa ligne se montre à part", _mine_visible(screen))
	_check("avec son rang réel, pas une place dans les dix",
		_contains(screen, "47"), _imprint(screen))
	_check("et son bilan", _contains(screen, "2 · 6 · 1"), _imprint(screen))
	_check("le tableau reste à trois lignes", _visible_rows(screen) == 3,
		str(_visible_rows(screen)))
	_dispose(screen, identity)

## Six états, six affichages. Deux états qui se ressemblent à l'écran sont deux
## états que le joueur confondra — c'est exactement ce qui fait passer une
## installation non configurée pour une panne de serveur.
func _test_etats_distincts() -> void:
	print("\n[Six états, six affichages]")

	var imprints: Dictionary = {}
	for name in ["UNCONFIGURED", "IDENTIFYING", "FAILED", "LOADING", "UNRANKED", "RANKED"]:
		var identity := _identity_for(String(name))
		var screen := _make_screen(identity)
		_check("l'état %s est bien celui qu'on croit" % name,
			int(screen.display_state()) == int(_display[name]), str(screen.display_state()))
		imprints[name] = _imprint(screen)
		_dispose(screen, identity)

	var seen: Dictionary = {}
	var collisions := ""
	for name in imprints:
		var imprint: String = imprints[name]
		if seen.has(imprint):
			collisions += "%s = %s ; " % [seen[imprint], name]
		seen[imprint] = name
	_check("les six affichages sont distincts", collisions == "", collisions)

## Une identité par état, dans l'ordre où le jeu les rencontre.
func _identity_for(state_name: String) -> Ancienne:
	if state_name == "UNCONFIGURED":
		return Ancienne.new()
	if state_name == "UNRANKED":
		return _ready_identity(_sample_top(), false)
	if state_name == "RANKED":
		var classe := _ready_identity(_sample_top(), true)
		classe.rating = 812
		classe.rank = 47
		classe.matches_played = 9
		classe.wins = 2
		classe.losses = 6
		classe.draws = 1
		return classe

	var identity := Complete.new()
	identity.nickname = "Vada"
	match state_name:
		"IDENTIFYING":
			identity.state = Ancienne.State.INITIALIZING
		"FAILED":
			identity.state = Ancienne.State.FAILED
			identity.last_error = "Serveur du classement injoignable."
		_:
			# LOADING : identifié, le tableau n'est pas encore arrivé.
			identity.state = Ancienne.State.READY
	return identity

# ---------------------------------------------------------------------------
# IDEMPOTENCE ET RELANCE
# ---------------------------------------------------------------------------

func _test_idempotence() -> void:
	print("\n[Idempotence de refresh()]")

	for name in ["UNCONFIGURED", "IDENTIFYING", "FAILED", "LOADING", "UNRANKED", "RANKED"]:
		var identity := _identity_for(String(name))
		var screen := _make_screen(identity)
		var once := _imprint(screen)
		screen.refresh()
		screen.refresh()
		screen.refresh()
		_check("état %s : trois rafraîchissements ne changent rien" % name,
			_imprint(screen) == once, "%s ≠ %s" % [_imprint(screen), once])
		_dispose(screen, identity)

## `refresh()` est aussi ce qui relance la récupération : c'est le seul moment
## où l'écran peut savoir que le classement a bougé. Relancer ne contrevient pas
## à l'idempotence — `refresh_standing()` se refuse lui-même tant qu'une requête
## est en vol ou que le profil n'est pas prêt.
func _test_relance() -> void:
	print("\n[refresh() relance la lecture]")

	var identity := _ready_identity(_sample_top(), true)
	var screen := _make_screen(identity)
	var apres_build := identity.refresh_calls
	_check("la construction a déjà demandé le classement", apres_build >= 1,
		str(apres_build))
	screen.refresh()
	_check("et chaque rafraîchissement le redemande",
		identity.refresh_calls == apres_build + 1, str(identity.refresh_calls))
	_dispose(screen, identity)

	# La réponse du serveur arrive bien après l'appel. Sans liaison aux signaux
	# de l'autoload, le joueur devrait appuyer deux fois sur RAFRAÎCHIR — une
	# pour demander, une pour voir — et croirait le premier appui perdu.
	var tardive := _ready_identity([], false)
	var ecran_tardif := _make_screen(tardive)
	var avant := _imprint(ecran_tardif)
	var requetes: int = tardive.refresh_calls
	tardive.top = _sample_top()
	tardive.is_ranked = true
	tardive.rating = 812
	tardive.rank = 47
	tardive.standing_changed.emit()
	_check("une réponse tardive rafraîchit l'écran toute seule",
		_imprint(ecran_tardif) != avant)
	_check("et elle affiche bien le tableau reçu",
		_visible_rows(ecran_tardif) == 3, str(_visible_rows(ecran_tardif)))
	# Rebrancher la réponse sur `refresh()` produirait une requête par réponse,
	# donc une boucle sur une Edge Function facturée à l'appel.
	_check("sans déclencher une requête de plus", tardive.refresh_calls == requetes,
		"%d puis %d" % [requetes, tardive.refresh_calls])
	_dispose(ecran_tardif, tardive)

	# Demander le classement d'un profil qui n'existe pas encore n'a pas de sens,
	# et coûterait une requête vouée au refus à chaque passage sur l'écran.
	for name in ["UNCONFIGURED", "IDENTIFYING", "FAILED"]:
		var muet := _identity_for(String(name))
		var ecran := _make_screen(muet)
		ecran.refresh()
		_check("état %s : aucune requête tentée" % name, muet.refresh_calls == 0,
			str(muet.refresh_calls))
		_dispose(ecran, muet)

# ---------------------------------------------------------------------------
# CE QUI VIENT DU SERVEUR, ET RIEN D'AUTRE
# ---------------------------------------------------------------------------

## Tout nombre relu d'un JSON revient en flottant : un rang `1` vaut `1.0`.
## Recopié tel quel, il s'afficherait « 1.0e » — et personne ne l'aurait vu
## avant un vrai serveur, puisque les doublures écrivent des entiers.
func _test_flottants() -> void:
	print("\n[Les nombres du JSON sont des flottants]")

	var identity := _ready_identity([
		{"player_id": "a", "nickname": "Ombre", "rating": 1248.0, "rank": 1.0,
			"matches": 22.0, "wins": 16.0, "losses": 5.0, "draws": 1.0},
	], false)
	var screen := _make_screen(identity)
	var imprint := _imprint(screen)
	_check("aucun « .0 » à l'écran", imprint.find(".0") < 0, imprint)
	_check("le classement s'affiche en entier", imprint.find("1248") >= 0, imprint)
	_check("le rang aussi", (screen._rows[0]["rank"] as Label).text == "1",
		(screen._rows[0]["rank"] as Label).text)
	_dispose(screen, identity)

	# Une colonne absente n'est pas un zéro. Les deux ne se ressemblent que dans
	# le code : à l'écran, « 0 point » est une affirmation, et elle serait fausse.
	var creux := _ready_identity([{"player_id": "a", "nickname": "Ombre"}], false)
	var ecran := _make_screen(creux)
	_check("une colonne absente rend un tiret, pas un zéro",
		(ecran._rows[0]["rating"] as Label).text == "—",
		(ecran._rows[0]["rating"] as Label).text)
	_check("un bilan incomplet aussi",
		(ecran._rows[0]["record"] as Label).text == "—",
		(ecran._rows[0]["record"] as Label).text)
	_dispose(ecran, creux)

## L'échelle des rangs (Aveugle … Candela) a un seul propriétaire, `elo.ts`, et
## le rang y est une fonction pure du classement. Un second calcul ici finirait
## par diverger du premier, et un classement faux reste plausible : personne ne
## le verrait. L'écran affiche donc le libellé si on le lui donne, et rien du
## tout sinon.
func _test_rang_non_recalcule() -> void:
	print("\n[Le rang ne se recalcule pas ici]")

	var tier_key: String = _screen_script.get_script_constant_map()["TIER_KEY"]

	# 1000 points : le centre exact de Bougie II selon l'échelle du serveur. Si
	# l'écran savait la calculer, c'est ici qu'il le montrerait.
	var muet := _ready_identity([
		{"player_id": "a", "nickname": "Ombre", "rating": 1000, "rank": 1,
			"matches": 4, "wins": 2, "losses": 2, "draws": 0},
	], false)
	var screen := _make_screen(muet)
	_check("sans libellé serveur, la colonne reste vide",
		(screen._rows[0]["tier"] as Label).text == "",
		(screen._rows[0]["tier"] as Label).text)
	var deduced := ""
	for tier in ["Aveugle", "Braise", "Bougie", "Lanterne", "Torche", "Brasier",
			"Phare", "Aurore", "Zénith", "Candela"]:
		if _contains(screen, String(tier)):
			deduced = String(tier)
			break
	_check("aucune catégorie n'est déduite du classement", deduced == "", deduced)
	_dispose(screen, muet)

	# Et quand le serveur enrichira ses lignes, le libellé s'affiche tel quel.
	var row: Dictionary = {"player_id": "a", "nickname": "Ombre", "rating": 1000,
		"rank": 1, "matches": 4, "wins": 2, "losses": 2, "draws": 0}
	row[tier_key] = "Bougie II"
	var enrichi := _ready_identity([row], false)
	var ecran := _make_screen(enrichi)
	_check("un libellé fourni s'affiche mot pour mot",
		(ecran._rows[0]["tier"] as Label).text == "Bougie II",
		(ecran._rows[0]["tier"] as Label).text)
	_dispose(ecran, enrichi)

## `ranked_identity.gd` ne rend pas encore le tableau de tête : il ne garde de
## la réponse du serveur que la ligne du joueur. L'écran doit rester honnête
## dans cet état — montrer ce qu'il a, dire ce qui lui manque, et surtout ne pas
## laisser un cadre vide qui passerait pour un défaut.
func _test_sans_tableau() -> void:
	print("\n[L'autoload ne rend pas encore le tableau]")

	var identity := Ancienne.new()
	identity.state = Ancienne.State.READY
	identity.nickname = "Vada"
	identity.profile_id = "moi"
	identity.is_ranked = true
	identity.rating = 812
	identity.rank = 47
	identity.matches_played = 9
	identity.wins = 2
	identity.losses = 6
	identity.draws = 1
	var screen := _make_screen(identity)

	_check("le tableau est déclaré injoignable", not screen.table_reachable())
	_check("ce n'est pas un tableau vide", not screen.table_is_empty())
	_check("l'écran ne reste pas bloqué en lecture",
		int(screen.display_state()) == int(_display["RANKED"]), str(screen.display_state()))
	_check("ma ligne s'affiche quand même", _contains(screen, "812"), _imprint(screen))
	_check("et le manque est écrit", _contains(screen, "indisponible"), _imprint(screen))
	_dispose(screen, identity)

	# Même autoload, joueur jamais classé : toujours aucun chiffre inventé.
	var neuf := Ancienne.new()
	neuf.state = Ancienne.State.READY
	neuf.nickname = "Vada"
	neuf.profile_id = "moi"
	var ecran := _make_screen(neuf)
	_check("un profil neuf n'a toujours pas 1000 points",
		not _contains(ecran, "1000"), _imprint(ecran))
	_check("ni le moindre chiffre", not _has_digit(_texts(ecran)), _texts(ecran))
	_dispose(ecran, neuf)
