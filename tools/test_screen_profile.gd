## Test headless de l'écran « Profil » (`screen_profile.gd`).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • LA propriété à ne jamais laisser régresser — aucun état n'affiche un code
##     de récupération qui n'existe pas. Un joueur qui noterait un gabarit
##     perdrait son classement en changeant de machine, et personne ne pourrait
##     le lui rendre ;
##   • un rattachement réussi change bien le profil à l'écran, alors même que
##     `RankedIdentity` n'émet AUCUN `state_changed` dans ce cas (l'état était
##     déjà « prêt ») ;
##   • les six situations sont tenues, et « non configuré » ne se peint pas
##     comme une panne : sans `supabase_config.gd` — fichier non versionné, donc
##     absent ici même — le jeu se joue normalement ;
##   • le champ de saisie refuse à la frappe, plutôt que d'accepter puis rejeter ;
##   • `refresh()` est idempotent, y compris avant toute construction.
##
## Lancer : godot --headless --path . --script res://tools/test_screen_profile.gd
extends SceneTree

## Code d'essai valide : douze caractères de l'alphabet des codes (ni I, ni O,
## ni 0, ni 1). Sa forme lisible est « ABCD-EFGH-JKLM ».
const CODE_A := "ABCDEFGHJKLM"
const CODE_A_LISIBLE := "ABCD-EFGH-JKLM"
## Le profil récupéré après un rattachement réussi.
const CODE_B := "NPQRSTUV2345"
const CODE_B_LISIBLE := "NPQR-STUV-2345"

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, `_init()`
## s'exécute avant les autoloads ET avant le cache des classes globales. Un
## `class_name` référencé trop tôt rend un objet nu, les SCRIPT ERROR
## n'incrémentent aucun compteur, et la suite annonce « tous les tests passent »
## sans avoir rien exécuté.
var _screen_script: GDScript
var _identity_script: GDScript
var _theme: GDScript
var _codes: GDScript

## Grammaire d'états relue dans `ranked_identity.gd` plutôt que recopiée ici :
## une énumération recopiée dans une suite finit par tester autre chose que ce
## que le jeu exécute.
var _S: Dictionary = {}

## Tout ce qui a été instancié, à libérer à la fin — un test qui fuit finit par
## masquer une vraie fuite.
var _trash: Array[Node] = []

func _init() -> void:
	print("=== Test de l'écran Profil ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : l'écran Profil est absent ou incomplet")
		quit(1)
		return

	_test_avant_construction()
	_test_non_configure()
	_test_identification_en_cours()
	_test_prete()
	_test_echec_reseau()
	_test_rattachement_refuse()
	_test_rattachement_reussi()
	_test_jamais_de_code_inexistant()
	_test_saisie()
	_test_copie()
	_test_idempotence()

	for node in _trash:
		if is_instance_valid(node):
			node.free()

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
# Rien ne sert de conclure sur un écran qui n'a pas compilé : sans ce contrôle,
# une classe absente du catalogue global se solderait par une suite qui
# « passe » sans avoir rien exercé.

func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	_screen_script = load("res://screen_profile.gd") as GDScript
	_identity_script = load("res://ranked_identity.gd") as GDScript
	_theme = load("res://menu_theme.gd") as GDScript
	_codes = load("res://recovery_code.gd") as GDScript

	var ok := true
	for pair in [["screen_profile.gd", _screen_script], ["ranked_identity.gd", _identity_script],
			["menu_theme.gd", _theme], ["recovery_code.gd", _codes]]:
		if pair[1] == null:
			printerr("  ✗ script introuvable ou non compilé : ", pair[0])
			ok = false
	if not ok:
		return false

	var declared := ""
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == "ScreenProfile":
			declared = String(entry.get("path", ""))
	_check("ScreenProfile est au catalogue des classes globales", declared != "",
		"catalogue vide ou classe absente — lancer : Godot --headless --path . --import")
	_check("déclarée à la racine", declared == "res://screen_profile.gd", declared)
	if declared == "":
		return false

	# Les méthodes d'instance se cherchent sur une instance : `has_method` posé
	# sur le script lui-même ne rend que les fonctions statiques.
	var probe: Node = _screen_script.new()
	var missing := ""
	for method in ["screen_title", "build", "refresh", "focus_seed", "can_rename",
			"has_recovery_code", "is_alarming"]:
		if not probe.has_method(method):
			missing += method + " "
	if not _screen_script.has_method("caret_for"):
		missing += "caret_for(statique) "
	_check("l'écran porte tout ce que la suite exerce", missing == "", missing)
	_check("le titre de l'écran est renseigné",
		String(probe.screen_title()).strip_edges() != "")
	probe.free()
	if missing != "":
		return false

	var states: Variant = _identity_script.State
	if not states is Dictionary:
		printerr("  ✗ RankedIdentity.State n'est pas une énumération lisible")
		return false
	_S = states as Dictionary
	for name in ["UNCONFIGURED", "INITIALIZING", "READY", "FAILED"]:
		if not _S.has(name):
			missing += name + " "
	_check("les quatre états de RankedIdentity sont là", missing == "", missing)

	return missing == ""

# ---------------------------------------------------------------------------
# OUTILLAGE
# ---------------------------------------------------------------------------

## Une identité neuve, dans l'arbre pour que son `_ready()` s'exécute — en
## headless il renonce de lui-même à s'identifier, donc aucun appel réseau ne
## part d'ici et aucun profil n'est créé dans la vraie base.
func _make_identity() -> Node:
	var identity: Node = _identity_script.new()
	identity.name = "IdentiteEssai%d" % _trash.size()
	root.add_child(identity)
	_trash.append(identity)
	return identity

## Un écran construit, branché sur `identity`. Jamais ajouté à l'arbre : c'est
## le contrat de `HubScreen` — un écran se construit seul, sans hub.
func _make_screen(identity: Node) -> Control:
	var screen: Control = _screen_script.new()
	screen.identity_override = identity
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	_trash.append(screen)
	return screen

## Passe l'identité dans un état donné et prévient l'écran comme le ferait
## `_set_state()`.
func _set_state(identity: Node, state_name: String) -> void:
	identity.state = int(_S[state_name])
	identity.state_changed.emit(identity.state)

## Empreinte de tout ce que l'écran montre. Deux empreintes égales, c'est le
## même écran — c'est la mesure de l'idempotence.
func _signature(screen: Control) -> String:
	return "|".join(PackedStringArray([
		screen._status.text, screen._explain.text, str(screen._explain.visible),
		screen._nickname.text, str(screen._nickname.visible),
		screen._standing.text, str(screen._standing.visible),
		screen._code.text, str(screen._btn_copy.disabled),
		screen._copy_feedback.text, str(screen._hint.visible),
		screen._link_progress.text, str(screen._btn_link.disabled),
		screen._link_feedback.text, str(screen._btn_rename.visible)]))

func _color_of(node: Label) -> Color:
	return node.get_theme_color(&"font_color")

# ---------------------------------------------------------------------------
# AVANT TOUTE CONSTRUCTION
# ---------------------------------------------------------------------------
#
# Le hub appelle `refresh()` sur des écrans qu'il n'a pas encore montrés, et
# parfois jamais construits. Un plantage ici ne se verrait qu'à l'ouverture d'un
# autre écran, ce qui est le pire endroit pour chercher la cause.

func _test_avant_construction() -> void:
	print("\n[Avant construction]")

	var screen: Control = _screen_script.new()
	_trash.append(screen)

	screen.refresh()
	screen.refresh()
	_check("rafraîchir un écran jamais construit ne plante pas", true)
	_check("aucun contrôle à viser", screen.focus_seed() == null)
	_check("aucun code à montrer", not screen.has_recovery_code())
	_check("et ce n'est pas une alerte", not screen.is_alarming())

	screen.build(null)
	_check("construire sans corps ne plante pas", true)

	# Sans identité du tout — ni autoload, ni doublure — l'écran doit tenir : ce
	# sera le cas de tout contributeur qui n'a pas `supabase_config.gd`.
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	screen.refresh()
	var count := body.get_child_count()
	_check("un écran sans identité s'affiche quand même", count > 0, str(count))
	_check("il annonce l'absence de classement, pas une panne", not screen.is_alarming())

	screen.build(body)
	_check("construire deux fois ne double pas le contenu",
		body.get_child_count() == count, "%d puis %d" % [count, body.get_child_count()])

# ---------------------------------------------------------------------------
# ÉTAT 1 — NON CONFIGURÉ
# ---------------------------------------------------------------------------
#
# `supabase_config.gd` est ignoré par git : il est absent chez tout nouveau
# contributeur et pendant cette suite. C'est un état NORMAL, pas un incident, et
# l'écran doit le dire sur ce ton-là — sans quoi la première impression du jeu
# est celle d'un service en rade.

func _test_non_configure() -> void:
	print("\n[Non configuré]")

	var identity := _make_identity()
	var screen := _make_screen(identity)

	_check("l'état de départ est bien « non configuré »",
		int(identity.state) == int(_S["UNCONFIGURED"]), str(identity.state))
	_check("l'écran reprend le vocabulaire de RankedIdentity",
		screen._status.text == String(identity.state_label()), screen._status.text)
	_check("ce n'est pas une alerte", not screen.is_alarming())
	_check("et ça ne s'écrit pas en couleur d'alerte",
		_color_of(screen._status) != _theme.WARN)
	_check("la couleur est celle du texte secondaire",
		_color_of(screen._status) == _theme.DIM)
	_check("une phrase explique que le jeu se joue quand même",
		screen._explain.visible and screen._explain.text.length() > 20, screen._explain.text)

	_check("aucun pseudo à montrer", not screen._nickname.visible)
	_check("aucun classement à montrer", not screen._standing.visible)
	_check("aucun code", not screen.has_recovery_code())
	_check("la copie est fermée", screen._btn_copy.disabled)
	# Rien à noter, donc pas de consigne de notation : elle n'aurait aucun sens.
	_check("la consigne « à noter » est retirée", not screen._hint.visible)

	# `RankedIdentity.link()` refuse de toute façon dans cet état : le champ le
	# dit d'avance plutôt que de laisser le joueur taper douze caractères pour
	# rien.
	_check("le champ de rattachement est fermé", not screen._link_input.editable)
	_check("le bouton aussi", screen._btn_link.disabled)
	_check("et la raison est écrite", screen._link_progress.text.length() > 10,
		screen._link_progress.text)
	# Un contrôle désactivé est hors d'atteinte du curseur (`_collect_focusables`
	# de ui.gd) : le proposer comme point de départ y planterait le curseur.
	_check("aucun contrôle désactivé n'est offert au curseur", screen.focus_seed() == null)

# ---------------------------------------------------------------------------
# ÉTAT 2 — IDENTIFICATION EN COURS
# ---------------------------------------------------------------------------

func _test_identification_en_cours() -> void:
	print("\n[Identification en cours]")

	var identity := _make_identity()
	var screen := _make_screen(identity)

	# Aucun `refresh()` explicite : c'est le branchement des signaux qu'on vérifie
	# ici. Sans lui, l'écran resterait figé sur ce qu'il a vu à la construction.
	_set_state(identity, "INITIALIZING")

	_check("le changement d'état seul suffit à rafraîchir l'écran",
		screen._status.text == String(identity.state_label()), screen._status.text)
	_check("une attente n'est pas une alerte", not screen.is_alarming())
	_check("écrit en texte secondaire", _color_of(screen._status) == _theme.DIM)
	_check("l'écran dit que rien n'est bloqué", screen._explain.text.length() > 20)

	_check("toujours aucun code tant que le serveur n'a pas répondu",
		not screen.has_recovery_code() and screen._btn_copy.disabled)

	# Dès qu'un classement existe, le rattachement s'ouvre : c'est précisément la
	# manœuvre d'un joueur qui débarque sur une machine neuve et n'attend pas le
	# profil vierge que l'identification est en train de lui fabriquer.
	_check("le rattachement s'ouvre", screen._link_input.editable
		and not screen._btn_link.disabled)
	_check("le décompte de saisie repart de zéro",
		screen._link_progress.text.begins_with("0 caractère"), screen._link_progress.text)

# ---------------------------------------------------------------------------
# ÉTAT 3 — IDENTITÉ PRÊTE
# ---------------------------------------------------------------------------

func _test_prete() -> void:
	print("\n[Identité prête]")

	var identity := _make_identity()
	var screen := _make_screen(identity)

	identity.nickname = "Vada"
	identity.recovery_code = CODE_A
	_set_state(identity, "READY")

	_check("le pseudo est affiché", screen._nickname.visible
		and screen._nickname.text == "Vada", screen._nickname.text)
	_check("le code est affiché en clair et groupé",
		screen._code.text == CODE_A_LISIBLE, screen._code.text)
	_check("la copie est ouverte", not screen._btn_copy.disabled)
	_check("le libellé du bouton est stable",
		screen._btn_copy.text == _screen_script.COPY_LABEL, screen._btn_copy.text)
	_check("la consigne « à noter » est visible", screen._hint.visible)
	_check("plus rien à expliquer", not screen._explain.visible)
	_check("aucune alerte", not screen.is_alarming())

	# Le curseur se pose sur la mise à l'abri du code : c'est la seule action de
	# cet écran qu'on ne peut pas refaire plus tard.
	_check("le curseur vise la copie", screen.focus_seed() == screen._btn_copy)

	# Pas encore classé : le serveur ne rend un classement qu'après un match
	# concordant. Afficher un nombre de points ici serait un chiffre inventé.
	_check("l'écran dit qu'aucun match n'a encore compté",
		screen._standing.visible and screen._standing.text == String(identity.standing_label()),
		screen._standing.text)
	_check("et il n'est pas peint comme un classement acquis",
		_color_of(screen._standing) == _theme.DIM)

	# Le classement arrive plus tard, par son propre signal.
	identity.is_ranked = true
	identity.rating = 1042
	identity.rank = 7
	identity.matches_played = 3
	identity.wins = 2
	identity.losses = 1
	identity.standing_changed.emit()
	_check("le classement relu s'affiche sans qu'on redemande rien",
		screen._standing.text == String(identity.standing_label()), screen._standing.text)
	_check("et prend la couleur du joueur", _color_of(screen._standing) == _theme.P1)

	# **Ce contrôle a été retourné le 2026-08-18.** Il affirmait l'inverse — « le
	# renommage se sait indisponible », « son bouton reste hors d'atteinte » —
	# parce qu'aucun point d'entrée serveur n'existait, et qu'un bouton visible qui
	# échoue vaut moins que pas de bouton du tout.
	#
	# La fonction `rename` est déployée depuis. La raison d'origine reste juste,
	# elle ne s'applique simplement plus : ce qui la faisait tenir a disparu.
	# L'écrire ici plutôt que de supprimer le contrôle, parce qu'un test qui
	# disparaît emporte la raison qu'il protégeait.
	_check("le renommage est offert sur un profil prêt", screen.can_rename())
	_check("et son bouton est atteignable", screen._btn_rename.visible)

	# La condition, elle, tient toujours : sans identité prête, pas de pseudo à
	# changer. C'est ce qui empêche le bouton de réapparaître pour rien.
	_set_state(identity, "INITIALIZING")
	_check("mais pas sur un profil qui s'identifie encore", not screen.can_rename())
	_set_state(identity, "READY")

# ---------------------------------------------------------------------------
# ÉTAT 4 — ÉCHEC RÉSEAU
# ---------------------------------------------------------------------------

func _test_echec_reseau() -> void:
	print("\n[Échec réseau]")

	var identity := _make_identity()
	var screen := _make_screen(identity)

	identity.last_error = "Serveur du classement injoignable."
	_set_state(identity, "FAILED")

	_check("la cause exacte est affichée, pas une formule générique",
		screen._status.text == identity.last_error, screen._status.text)
	_check("là, c'est une alerte", screen.is_alarming())
	_check("et elle en a la couleur", _color_of(screen._status) == _theme.WARN)
	_check("l'écran rappelle que les matchs restent jouables",
		screen._explain.visible and screen._explain.text.length() > 20)

	# Le rattachement reste ouvert : un joueur qui arrive sur une machine neuve
	# voit très exactement cet écran, et c'est ici qu'il tape son code.
	_check("le rattachement reste offert", screen._link_input.editable
		and not screen._btn_link.disabled)
	_check("le curseur se rabat dessus", screen.focus_seed() == screen._btn_link)

	_check("aucun code inventé pour meubler",
		screen._code.text != CODE_A_LISIBLE and screen._btn_copy.disabled, screen._code.text)

	# Nuance qui compte : une identification réussie PUIS une relecture ratée
	# laisse un code parfaitement valide. Le retirer de l'écran parce que le
	# réseau a hoqueté priverait le joueur de la seule chose qu'il doive noter.
	identity.recovery_code = CODE_A
	screen.refresh()
	_check("un code déjà connu survit à la panne",
		screen._code.text == CODE_A_LISIBLE and not screen._btn_copy.disabled,
		screen._code.text)

# ---------------------------------------------------------------------------
# ÉTAT 5 — RATTACHEMENT REFUSÉ
# ---------------------------------------------------------------------------

func _test_rattachement_refuse() -> void:
	print("\n[Rattachement refusé]")

	var identity := _make_identity()
	var screen := _make_screen(identity)
	identity.nickname = "Vada"
	identity.recovery_code = CODE_A
	_set_state(identity, "READY")

	# Refus LOCAL : douze caractères sont exigés, et `RankedIdentity.link()`
	# tranche sans rien envoyer. Rien ne part sur le réseau depuis cette suite.
	screen._link_input.text = "ABCD"
	screen._request_link()
	_check("un code trop court est refusé sur place",
		screen._link_feedback.text.begins_with("Code incomplet"), screen._link_feedback.text)
	_check("le refus n'est pas laissé sous un « en cours » qui ne finit jamais",
		screen._link_feedback.text != _screen_script.LINK_PENDING)
	_check("et il est peint comme un refus",
		_color_of(screen._link_feedback) == _theme.WARN)
	# On ne vide pas le champ : le joueur a un caractère à corriger, pas douze à
	# retaper.
	_check("la saisie est conservée", screen._link_input.text == "ABCD",
		screen._link_input.text)

	_check("le profil courant est intact",
		screen._nickname.text == "Vada" and screen._code.text == CODE_A_LISIBLE)

	# Refus VENU DU SERVEUR : `_report()` renseigne `last_error` au passage. Si
	# l'écran affichait `last_error` sans regarder l'état, un profil parfaitement
	# valide passerait pour un profil en panne à cause d'un code mal recopié.
	identity.last_error = "Code de récupération inconnu."
	identity.link_completed.emit(false, "Code de récupération inconnu.")
	_check("le message du serveur est rendu tel quel",
		screen._link_feedback.text == "Code de récupération inconnu.")
	_check("mais l'identité reste annoncée comme prête",
		screen._status.text == String(identity.state_label()), screen._status.text)
	_check("et rien ne vire à l'alerte", not screen.is_alarming()
		and _color_of(screen._status) == _theme.DIM)
	_check("le code affiché n'a pas bougé", screen._code.text == CODE_A_LISIBLE)

# ---------------------------------------------------------------------------
# ÉTAT 6 — RATTACHEMENT RÉUSSI
# ---------------------------------------------------------------------------
#
# Le piège de cet état : `_adopt()` appelle `_set_state(READY)` sur une identité
# DÉJÀ prête, et `_set_state` n'émet rien quand l'état ne change pas. Un écran
# qui n'écouterait que `state_changed` garderait donc l'ancien pseudo et
# l'ancien code à l'affichage — c'est-à-dire le code d'un profil que la machine
# vient d'abandonner.

func _test_rattachement_reussi() -> void:
	print("\n[Rattachement réussi]")

	var identity := _make_identity()
	var screen := _make_screen(identity)
	identity.nickname = "Vada"
	identity.recovery_code = CODE_A
	_set_state(identity, "READY")

	screen._copy_recovery_code()
	screen._link_input.text = CODE_B_LISIBLE

	var etats: Array[int] = []
	identity.state_changed.connect(func(s: int) -> void: etats.append(s))

	# Ce que fait `_adopt()`, à l'identique : le profil change, l'état non.
	identity.nickname = "Ombre"
	identity.recovery_code = CODE_B
	identity.link_completed.emit(true, "Profil Ombre rattaché à cette machine.")

	_check("aucun changement d'état n'a été émis", etats.is_empty(), str(etats))
	_check("le nouveau pseudo est pourtant à l'écran",
		screen._nickname.text == "Ombre", screen._nickname.text)
	_check("et le nouveau code aussi",
		screen._code.text == CODE_B_LISIBLE, screen._code.text)
	_check("le message de réussite est affiché",
		screen._link_feedback.text.begins_with("Profil Ombre"), screen._link_feedback.text)
	_check("dans la couleur de ce qu'on veut lire", _color_of(screen._link_feedback) == _theme.GOLD)
	_check("le champ est vidé : le code a servi", screen._link_input.text == "",
		screen._link_input.text)
	# La confirmation de copie parlait du code d'AVANT. La laisser ferait croire
	# au joueur que le code désormais affiché est déjà à l'abri.
	_check("la confirmation de copie périmée a disparu",
		screen._copy_feedback.text == "", screen._copy_feedback.text)

# ---------------------------------------------------------------------------
# LA PROPRIÉTÉ À NE JAMAIS LAISSER RÉGRESSER
# ---------------------------------------------------------------------------
#
# Aucun état n'affiche un code qui n'existe pas. Un gabarit pris pour un code
# est un classement perdu pour de bon : le serveur ne peut rendre un profil qu'à
# qui présente le vrai code.

func _test_jamais_de_code_inexistant() -> void:
	print("\n[Jamais de code inexistant]")

	var identity := _make_identity()
	var screen := _make_screen(identity)

	var alphabet := String(_codes.ALPHABET)
	var faute := ""
	var gabarit := ""
	for name in ["UNCONFIGURED", "INITIALIZING", "READY", "FAILED"]:
		identity.recovery_code = ""
		_set_state(identity, name)
		screen.refresh()

		if screen.has_recovery_code():
			faute = "%s : l'écran prétend avoir un code" % name
			break
		if not screen._btn_copy.disabled:
			faute = "%s : la copie reste ouverte sans code" % name
			break
		# Le gabarit ne doit contenir aucun caractère de l'alphabet des codes :
		# recopié à la main, il ne ressemblerait pas à un code, il en SERAIT un.
		gabarit = screen._code.text
		for c in gabarit:
			if alphabet.contains(c):
				faute = "%s : le gabarit contient « %s »" % [name, c]
				break
		if faute != "":
			break
	_check("aucun état ne montre un code de récupération qui n'existe pas",
		faute == "", faute)

	# Et le gabarit occupe exactement la place du vrai code : sans cela la ligne
	# saute au moment où le code arrive, pile quand le joueur s'apprête à lire.
	_check("le gabarit a la longueur d'un vrai code",
		gabarit.length() == CODE_A_LISIBLE.length(), gabarit)

# ---------------------------------------------------------------------------
# LE CHAMP DE SAISIE
# ---------------------------------------------------------------------------
#
# Le champ refuse À LA FRAPPE : le joueur ne peut pas produire une saisie
# invalide, il n'y a donc rien à lui refuser après coup. Même procédé que le
# champ du code de salon dans ui.gd.

func _test_saisie() -> void:
	print("\n[Saisie du code]")

	var identity := _make_identity()
	var screen := _make_screen(identity)
	_set_state(identity, "READY")

	var minuscules := _tape(screen, "abcd")
	_check("les minuscules remontent en majuscules", minuscules == "ABCD", minuscules)

	var colle := _tape(screen, "abcd-efgh-jklm")
	_check("un collage lisible passe tel quel", colle == CODE_A_LISIBLE, colle)

	var sale := _tape(screen, "  abcd efgh!jklm  ")
	_check("espaces et ponctuation sont retirés", sale == CODE_A_LISIBLE, sale)

	# Les quatre caractères que l'alphabet exclut parce qu'ils se confondent deux
	# à deux à l'oral. Aucune substitution : « I » ne devient pas « J », sans quoi
	# le jeu rattacherait le profil de quelqu'un d'autre.
	var ambigus := _tape(screen, "IO01")
	_check("les caractères ambigus sont refusés, jamais devinés", ambigus == "", ambigus)

	var trop := _tape(screen, "ABCDEFGHJKLMNPQRST")
	_check("le trop-plein est coupé net", trop == CODE_A_LISIBLE, trop)

	# Les tirets s'insèrent pendant la frappe : la forme lue à voix haute et la
	# forme tapée sont alors la même, et il n'y a rien à convertir de tête.
	var groupe := _tape(screen, "ABCDE")
	_check("le groupement se fait pendant la frappe", groupe == "ABCD-E", groupe)

	# Le curseur suit les caractères significatifs, pas les tirets : un décompte
	# brut le ferait sauter d'un groupe dès la cinquième lettre.
	_check("le curseur reste où le joueur l'a laissé",
		_screen_script.caret_for(0) == 0 and _screen_script.caret_for(4) == 4
		and _screen_script.caret_for(5) == 6 and _screen_script.caret_for(8) == 9
		and _screen_script.caret_for(12) == 14,
		"%d %d %d" % [_screen_script.caret_for(5), _screen_script.caret_for(8),
			_screen_script.caret_for(12)])
	var _plein := _tape(screen, CODE_A)
	_check("le curseur ne sort jamais du texte",
		screen._link_input.caret_column <= screen._link_input.text.length(),
		"%d > %d" % [screen._link_input.caret_column, screen._link_input.text.length()])

	# Le décompte rend le refus prévisible plutôt que subi.
	var _court := _tape(screen, "ABC")
	_check("le décompte suit la frappe",
		screen._link_progress.text == "3 caractères sur %d" % int(_codes.LENGTH),
		screen._link_progress.text)
	var _complet := _tape(screen, CODE_A)
	_check("et annonce quand le code est complet",
		screen._link_progress.text.begins_with("Code complet"), screen._link_progress.text)

## Simule une frappe ou un collage : le champ reçoit le texte brut, le curseur
## est en bout comme après une saisie, puis on laisse l'écran nettoyer.
func _tape(screen: Control, raw: String) -> String:
	screen._link_input.text = raw
	screen._link_input.caret_column = raw.length()
	screen._on_link_text_changed(raw)
	return screen._link_input.text

# ---------------------------------------------------------------------------
# LA COPIE
# ---------------------------------------------------------------------------
#
# CE QUI N'EST PAS COUVERT ICI : le presse-papiers lui-même. En headless,
# `DisplayServer.clipboard_get()` rend toujours une chaîne vide — un test qui
# comparerait ce qu'on vient d'y écrire passerait aussi bien avec un
# `clipboard_set` supprimé. On vérifie donc ce qui est vérifiable : l'état du
# bouton, son libellé, et la confirmation montrée au joueur. Que le contenu
# arrive vraiment dans le presse-papiers reste une vérification manuelle.

func _test_copie() -> void:
	print("\n[Copie du code]")

	var identity := _make_identity()
	var screen := _make_screen(identity)

	_check("sans code, le bouton est fermé", screen._btn_copy.disabled)
	screen._copy_recovery_code()
	_check("et un appui forcé n'annonce rien", screen._copy_feedback.text == "",
		screen._copy_feedback.text)

	identity.recovery_code = CODE_A
	_set_state(identity, "READY")
	_check("avec un code, le bouton s'ouvre", not screen._btn_copy.disabled)
	_check("son libellé n'a pas changé sous les yeux du joueur",
		screen._btn_copy.text == _screen_script.COPY_LABEL, screen._btn_copy.text)

	screen._copy_recovery_code()
	_check("la copie est confirmée",
		screen._copy_feedback.text == _screen_script.COPY_DONE, screen._copy_feedback.text)
	_check("le code affiché n'a pas été altéré au passage",
		screen._code.text == CODE_A_LISIBLE, screen._code.text)
	_check("le bouton reste atteignable pour recommencer", not screen._btn_copy.disabled)

	screen.refresh()
	screen.refresh()
	_check("la confirmation survit aux rafraîchissements",
		screen._copy_feedback.text == _screen_script.COPY_DONE)

	# Elle ne survit pas au changement de profil : elle parlerait d'un code qui
	# n'est plus celui de cette machine.
	identity.recovery_code = CODE_B
	screen.refresh()
	_check("mais pas au changement de code", screen._copy_feedback.text == "",
		screen._copy_feedback.text)

# ---------------------------------------------------------------------------
# IDEMPOTENCE
# ---------------------------------------------------------------------------
#
# Le hub rafraîchit à chaque fois qu'un écran redevient visible, et parfois
# avant. Un `refresh()` qui dériverait d'un appel à l'autre produirait un défaut
# qui dépend de l'ordre d'ouverture des écrans — c'est-à-dire un défaut qui ne
# se voit que sur la machine de quelqu'un d'autre.

func _test_idempotence() -> void:
	print("\n[Idempotence]")

	var identity := _make_identity()
	var screen := _make_screen(identity)
	identity.nickname = "Vada"

	var derive := ""
	for name in ["UNCONFIGURED", "INITIALIZING", "READY", "FAILED"]:
		identity.recovery_code = CODE_A if name == "READY" else ""
		identity.last_error = "Serveur du classement injoignable." if name == "FAILED" else ""
		_set_state(identity, name)

		var first := _signature(screen)
		screen.refresh()
		screen.refresh()
		screen.refresh()
		if _signature(screen) != first:
			derive = "%s :\n    %s\n    %s" % [name, first, _signature(screen)]
			break
	_check("trois rafraîchissements donnent le même écran, dans les quatre états",
		derive == "", derive)

	# Y compris après les deux issues d'un rattachement, qui repassent par
	# `refresh()` par un autre chemin.
	_set_state(identity, "READY")
	identity.recovery_code = CODE_A
	identity.link_completed.emit(false, "Code de récupération inconnu.")
	var apres_refus := _signature(screen)
	screen.refresh()
	_check("un refus de rattachement laisse un écran stable",
		_signature(screen) == apres_refus,
		"%s\n    %s" % [apres_refus, _signature(screen)])

	identity.nickname = "Ombre"
	identity.recovery_code = CODE_B
	identity.link_completed.emit(true, "Profil Ombre rattaché à cette machine.")
	var apres_reussite := _signature(screen)
	screen.refresh()
	screen.refresh()
	_check("une réussite aussi", _signature(screen) == apres_reussite,
		"%s\n    %s" % [apres_reussite, _signature(screen)])
