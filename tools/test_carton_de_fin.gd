extends SceneTree

## LE CARTON DE FIN — ce qu'il nomme, et comment on le passe.
##
## Adrien, 2026-09-29 vers 15:26 : « Oui pour le carton de fin affiche la classe, et fais en sorte que ce carton
## soit skippable avec n'importe quelle touche. » Deux demandes, une suite, et le même montage : le VRAI chemin
## de fin de match (`GameState._poser_affiche_de_fin`, derrière `ui.show_game_over`), sans rien de recomposé ici.
##
## ## Ce que la suite tient
##
## 1. **Le carton nomme la CLASSE de chacun des deux joueurs**, pas leur arme — dans les trois modes de jeu (écran
##    scindé, hôte, client : chacun affiche les deux classes, dans le même ordre J1 / J2). Avant, il écrivait
##    `WeaponData.name`, le nom de l'ARME : « PISTOLET / PISTOLET » pour deux Parasites, « FUSIL » pour
##    l'Illusionniste — jamais ce que le joueur a choisi au salon.
## 2. **N'importe quel appui le congédie** : touche du clavier (celles de J1 comme de J2), bouton de souris, bouton
##    de manette de l'un ou l'autre joueur, et les deux gâchettes — L2 et R2 sont des AXES, que l'ancien
##    `_unhandled_input` ne voyait pas, alors que R2 est le tir de la manette.
## 3. **Le geste tenu ne le passe pas** : la gâchette de tir déjà enfoncée quand le carton apparaît ne le congédie
##    pas, même si sa valeur bouge ; il faut la relâcher, puis la presser de nouveau. Une touche qui répète
##    (`echo`), un relâchement, un mouvement de souris, la molette, un stick : rien de tout cela n'est un appui.
## 4. **Une courte garde** : tant que le carton n'a pas fini d'entrer, un appui ne compte pas — on ne congédie pas
##    ce qui n'est pas encore lisible. Elle vaut la durée de l'entrée elle-même, pas un nombre de plus à tenir.
## 5. **Le geste qui congédie ne fuit pas dessous.** L'ancien carton écoutait APRÈS l'interface : L1 et R1
##    (« onglet suivant » du salon) étaient mangés par `ui._input`, ne congédiaient rien et faisaient remonter le
##    salon d'un cran sous l'affiche ; toute autre touche congédiait ET déplaçait un curseur du salon.
## 6. **À l'entraînement il n'y a pas de carton** : aucune manche n'y est armée, donc aucune mort n'y clôt un match.
##
## ## Ce que la suite ne prouve pas
##
## **Le clic de souris.** Sans fenêtre, l'interface ne traite aucun clic (un `Button` sous la souris n'émet même
## pas `pressed`, mesuré le 2026-09-29) : le fond opaque du carton, qui AVALE le clic avant `_unhandled_input`, n'y
## existe pas. Ici, le clic congédie par l'un ou l'autre chemin ; le défaut d'origine ne se voit que dans une vraie
## fenêtre. C'est `tools/test_carton_transition.gd`, lancé sous Xvfb, qui l'éprouve — et le contrôle du chemin
## d'écoute (`is_processing_input`) est ici le seul garde headless de cette cause.
##
## Lancer : godot --headless --path . --script res://tools/test_carton_de_fin.gd

## Par `preload` : en `--script`, le registre des classes globales n'est pas toujours là.
const ArmeT := preload("res://weapon_data.gd")

## Ce que la suite doit avoir exécuté pour valoir quoi que ce soit : une exécution qui n'en aurait fait que la moitié
## ne passerait pas pour verte.
const PLANCHER := 90

var _echecs := 0
var _verifications := 0
var _main: Node
var _ui: Node
var _reseau: Node


func _check(libelle: String, condition: bool, detail: String = "") -> void:
	_verifications += 1
	if condition:
		print("  ✓ %s" % libelle)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [libelle, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LE CARTON DE FIN ===")
	# Un foyer neuf est un joueur neuf : l'intro se jouerait par-dessus le menu et le rendrait sourd.
	root.get_node("GameSettings").intro_vue = true
	await process_frame
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_ui = _main.get_node_or_null("UI")
	_reseau = root.get_node_or_null(^"/root/NetworkManager")
	if _ui == null or _reseau == null or not _main.has_method("_poser_affiche_de_fin"):
		printerr("✗ le jeu n'a pas ses pièces (UI, NetworkManager, _poser_affiche_de_fin)")
		quit(1)
		return
	var allumage: Node = _main.get_node_or_null("PowerOn")
	if allumage != null:
		allumage.call("terminer")
		await create_timer(0.7).timeout

	await _test_classes()
	await _test_touches_qui_congedient()
	await _test_ce_qui_n_est_pas_un_appui()
	await _test_gachette_tenue()
	await _test_garde_d_entree()
	await _test_pas_de_fuite_vers_le_salon()
	await _test_entrainement_sans_carton()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)

	_reseau.current_mode = _reseau.GameMode.LOCAL_SPLITSCREEN
	Engine.time_scale = 1.0
	_main.queue_free()
	if _echecs == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


# ---------------------------------------------------------------------------
# LE MONTAGE
# ---------------------------------------------------------------------------

## Pose l'écran de fin comme `_do_end_round` le pose — le salon, le bilan, puis le carton — et rend le carton.
func _poser_carton(vainqueur: int = 0) -> Node:
	_main.game_over = true
	_ui.show_game_over(vainqueur)
	_ui.poser_bilan(0, 0, "", -1.0)
	_main._poser_affiche_de_fin(vainqueur)
	return _main.get_node_or_null("AfficheDeFin")


## Le carton est-il encore là ET actif (ni congédié, ni libéré) ?
##
## ⚠️ **Jamais d'accès direct à un carton dont on ne sait pas s'il existe encore, ni de paramètre typé `Node` pour le
## porter.** Un carton congédié quitte l'arbre au bout de 0,26 s de jeu ; sur une machine à-coups (un lot partagé, un hôte
## chargé) cela arrive ENTRE le geste et la lecture qu'on en fait. Or passer un nœud libéré à un paramètre typé, ou l'appeler,
## est une `SCRIPT ERROR` — qui n'échoue AUCUN contrôle, emporte avec elle ceux qui suivent dans la fonction, et laisse la
## suite sortir avec le code 0 en ayant sauté une partie de ce qu'elle doit prouver (constaté le 2026-09-29 : 128 contrôles
## au lieu de 130 et une erreur de script, une fois sur une trentaine ; reproduit à volonté en gelant le processus quelques
## dixièmes de seconde, `SIGSTOP`). Les paramètres du carton sont donc sans type, et chaque lecture passe par ici.
func _actif(affiche) -> bool:
	return is_instance_valid(affiche) and bool(affiche.call("est_active"))


## L'entrée du carton est-elle finie ? Faux d'un carton libéré.
func _armee(affiche) -> bool:
	return is_instance_valid(affiche) and bool(affiche.call("est_armee"))


## Le texte d'un nœud nommé du carton, ou une chaîne vide.
func _texte_de(affiche, nom: String) -> String:
	var n: Node = affiche.find_child(nom, true, false) if is_instance_valid(affiche) else null
	return String(n.get("text")) if n != null else ""


## Retire le carton et rend au salon son état d'avant : `tree_exited` doit relâcher le verrou de REJOUER.
func _ranger(affiche) -> void:
	if is_instance_valid(affiche):
		affiche.queue_free()
	await process_frame
	await process_frame
	_ui.hide_game_over()
	_main.game_over = false
	await process_frame


## Attend que l'entrée du carton soit finie. Le temps de jeu est accéléré le temps de l'attente : l'entrée dure une
## demi-seconde, et une trentaine de gestes à éprouver en feraient un quart de minute. Sans manche en cours,
## rien d'autre ne dépend de l'horloge.
##
## Quatre fois et non douze : un à-coup de la machine pendant l'attente compte AUTANT de fois de temps de jeu, et le carton
## se congédie de lui-même à `DUREE_MAX` (six secondes). À douze, un gel d'une demi-seconde suffisait à le faire disparaître
## avant le geste ; à quatre, il en faut un et demi. Rend vrai si le carton est armé ET encore actif : un carton que sa
## sécurité a déjà retiré n'a pas « fini d'entrer », et le dire évite de juger un geste sur un carton qui n'est plus là.
func _attendre_arme(affiche, maxi_ms: int = 6000) -> bool:
	var fin := Time.get_ticks_msec() + maxi_ms
	Engine.time_scale = 4.0
	while _actif(affiche) and not _armee(affiche):
		if Time.get_ticks_msec() > fin:
			break
		await process_frame
	Engine.time_scale = 1.0
	return _actif(affiche) and _armee(affiche)


## Un événement par le VRAI chemin des entrées (`Input` → arbre), puis deux images pour qu'il ait tout traversé.
func _envoyer(evenement: InputEvent) -> void:
	Input.parse_input_event(evenement)
	Input.flush_buffered_events()
	await process_frame
	await process_frame


## Le même geste, relâché : l'`Input` du processus ne doit garder aucune touche enfoncée d'un contrôle au suivant.
func _relacher(evenement: InputEvent) -> void:
	var fin: InputEvent = evenement.duplicate()
	if fin is InputEventKey or fin is InputEventMouseButton or fin is InputEventJoypadButton:
		fin.set("pressed", false)
	elif fin is InputEventJoypadMotion:
		fin.set("axis_value", 0.0)
	else:
		return
	Input.parse_input_event(fin)
	Input.flush_buffered_events()
	await process_frame


func _touche(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _clic(bouton: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = bouton
	e.pressed = true
	e.position = Vector2(400.0, 300.0)
	e.global_position = e.position
	return e


func _bouton(bouton: JoyButton, manette: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = bouton
	e.device = manette
	e.pressed = true
	return e


func _gachette(axe: JoyAxis, valeur: float, manette: int) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axe
	e.axis_value = valeur
	e.device = manette
	return e


# ---------------------------------------------------------------------------
# 1. LA CLASSE, PAS L'ARME
# ---------------------------------------------------------------------------

func _test_classes() -> void:
	print("\n[Le carton nomme la CLASSE des deux joueurs, dans les trois modes]")
	var classes: Array = _main.classes()
	_check("dix classes au catalogue", classes.size() == 10, "%d" % classes.size())
	if classes.size() != 10:
		return

	# Les libellés d'Adrien, écrits ici à la main : lire le catalogue pour vérifier ce que le carton lit dans le
	# catalogue reviendrait à comparer le code à lui-même.
	var attendus := {0: "LE PARASITE", 1: "L'ILLUSIONNISTE", 2: "LE TERRASSIER", 3: "LE BRACONNIER"}
	for idx in attendus:
		_check("le catalogue nomme la classe %d « %s »" % [idx, attendus[idx]],
			String(classes[idx].libelle).to_upper() == attendus[idx], String(classes[idx].libelle))

	# Les paires : le Parasite contre le Terrassier ; deux classes neuves (dont les armes s'appellent « Pistolet lourd » et
	# « Pistolet silencieux » : trois classes se lisaient « pistolet ») ; deux fois la même ; puis deux autres.
	var i_fumiste := -1
	var i_spectre := -1
	for i in classes.size():
		if String(classes[i].slug()) == "fumiste":
			i_fumiste = i
		elif String(classes[i].slug()) == "spectre":
			i_spectre = i
	_check("le Fumiste et le Spectre sont au catalogue", i_fumiste >= 0 and i_spectre >= 0)
	var paires: Array = [[0, 2], [i_fumiste, i_spectre], [3, 3], [1, 4], [8, 7]]
	var modes := [
		["écran scindé", _reseau.GameMode.LOCAL_SPLITSCREEN, "JOUEUR 1 GAGNE"],
		["hôte", _reseau.GameMode.ONLINE_HOST, "VICTOIRE"],
		["client", _reseau.GameMode.ONLINE_CLIENT, "DÉFAITE"],
	]
	var nommees := 0
	for mode in modes:
		for paire in paires:
			var c1 = classes[int(paire[0])]
			var c2 = classes[int(paire[1])]
			_main.p1.equip_weapon(c1)
			_main.p2.equip_weapon(c2)
			# Le mode est posé le temps de la pose et lu tout de suite : aucune image ne passe avec un faux lien.
			_reseau.current_mode = mode[1]
			var affiche := _poser_carton(0)
			var legende := _texte_de(affiche, "Legende")
			var verdict := _texte_de(affiche, "Verdict")
			_reseau.current_mode = _reseau.GameMode.LOCAL_SPLITSCREEN
			var attendu := "%s / %s" % [String(c1.libelle).to_upper(), String(c2.libelle).to_upper()]
			var etiquette := "%s, %s contre %s" % [mode[0], c1.libelle, c2.libelle]
			_check("%s : le carton dit « %s »" % [etiquette, attendu], legende.contains(attendu), legende)
			var arme_nommee := legende.contains(String(c1.name).to_upper()) \
				or legende.contains(String(c2.name).to_upper())
			_check("%s : il ne nomme aucune arme" % etiquette, not arme_nommee, legende)
			# Le témoin : le montage joue bien le mode qu'il annonce, sinon les trois boucles n'en feraient qu'une.
			_check("%s : témoin, le verdict est « %s »" % [etiquette, mode[2]], verdict == mode[2], verdict)
			nommees += 1
			await _ranger(affiche)
	_check("quinze cartons nommés (trois modes, cinq paires)", nommees == 15, "%d" % nommees)

	# Une classe inconnue ne s'invente pas un nom : la mention disparaît, elle ne redit pas « Pistolet ».
	_main.p1.equip_weapon(classes[0])
	_main.p2.equip_weapon(ArmeT.new())
	var affiche_sans := _poser_carton(0)
	var legende_sans := _texte_de(affiche_sans, "Legende")
	_check("un joueur sans classe n'emprunte pas le nom de son arme",
		not legende_sans.contains("PISTOLET"), legende_sans)
	await _ranger(affiche_sans)
	_main.p2.equip_weapon(classes[1])


# ---------------------------------------------------------------------------
# 2. N'IMPORTE QUEL APPUI
# ---------------------------------------------------------------------------

func _test_touches_qui_congedient() -> void:
	print("\n[N'importe quel appui congédie le carton]")
	var gestes: Array = [
		["touche A (J1 se déplace)", _touche(KEY_A)],
		["touche Entrée", _touche(KEY_ENTER)],
		["barre d'espace", _touche(KEY_SPACE)],
		["Échap", _touche(KEY_ESCAPE)],
		["flèche haut (J2 se déplace)", _touche(KEY_UP)],
		["touche O (le tir de J2)", _touche(KEY_O)],
		["Tab", _touche(KEY_TAB)],
		["Maj", _touche(KEY_SHIFT)],
		["F5", _touche(KEY_F5)],
		["clic gauche (le tir de J1)", _clic(MOUSE_BUTTON_LEFT)],
		["clic droit (la torche de J1)", _clic(MOUSE_BUTTON_RIGHT)],
		["clic milieu", _clic(MOUSE_BUTTON_MIDDLE)],
		["bouton latéral de la souris", _clic(MOUSE_BUTTON_XBUTTON1)],
		["manette de J1 : Croix", _bouton(JOY_BUTTON_A, 0)],
		["manette de J1 : Rond", _bouton(JOY_BUTTON_B, 0)],
		["manette de J1 : L1", _bouton(JOY_BUTTON_LEFT_SHOULDER, 0)],
		["manette de J1 : R1", _bouton(JOY_BUTTON_RIGHT_SHOULDER, 0)],
		["manette de J1 : Start", _bouton(JOY_BUTTON_START, 0)],
		["manette de J1 : croix directionnelle", _bouton(JOY_BUTTON_DPAD_DOWN, 0)],
		["manette de J2 : Croix", _bouton(JOY_BUTTON_A, 1)],
		["manette de J2 : L1", _bouton(JOY_BUTTON_LEFT_SHOULDER, 1)],
		["manette de J2 : R1", _bouton(JOY_BUTTON_RIGHT_SHOULDER, 1)],
		["manette de J2 : clic du stick", _bouton(JOY_BUTTON_LEFT_STICK, 1)],
		["gâchette R2 de J1 (le tir de la manette)", _gachette(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0)],
		["gâchette L2 de J1 (la torche)", _gachette(JOY_AXIS_TRIGGER_LEFT, 1.0, 0)],
		["gâchette R2 de J2", _gachette(JOY_AXIS_TRIGGER_RIGHT, 0.8, 1)],
		["gâchette L2 de J2", _gachette(JOY_AXIS_TRIGGER_LEFT, 0.9, 1)],
	]
	var congedies := 0
	for geste in gestes:
		var affiche := _poser_carton(0)
		await process_frame
		var arme := await _attendre_arme(affiche)
		if not arme:
			_check("%s : le carton a fini d'entrer" % geste[0], false)
			await _ranger(affiche)
			continue
		await _envoyer(geste[1])
		var parti: bool = not _actif(affiche)
		_check("%s congédie le carton" % geste[0], parti)
		congedies += 1 if parti else 0
		await _relacher(geste[1])
		await _ranger(affiche)
	_check("%d gestes sur %d ont congédié le carton" % [congedies, gestes.size()], congedies == gestes.size())

	# Le verrou de REJOUER se relâche à la sortie, quel que soit le chemin — la seconde porte de l'ancien défaut.
	var affiche := _poser_carton(0)
	_check("tant que le carton vit, REJOUER est verrouillé", _ui.btn_replay.disabled)
	await _attendre_arme(affiche)
	await _envoyer(_touche(KEY_A))
	await _relacher(_touche(KEY_A))
	await create_timer(0.5).timeout
	_check("le carton congédié a quitté l'arbre", not is_instance_valid(affiche))
	_check("et REJOUER est de nouveau libre", not _ui.btn_replay.disabled and not _ui.panel_launch.disabled)
	_main.game_over = false
	_ui.hide_game_over()
	await process_frame

	# Le chemin d'écoute : AVANT l'interface. Un fond opaque (`MOUSE_FILTER_STOP`) avale le clic dans la phase de
	# l'interface, et ce qui n'écoute qu'`_unhandled_input` n'en voit jamais la couleur — mesuré sous Xvfb le
	# 2026-09-29, où aucun clic ne congédiait le carton. Le clic, lui, ne se prouve que fenêtré.
	var ecoute := _poser_carton(0)
	_check("le carton écoute les appuis AVANT l'interface",
		is_instance_valid(ecoute) and bool(ecoute.call("is_processing_input")))
	_check("… et pas après, où son propre fond les a déjà avalés",
		is_instance_valid(ecoute) and not bool(ecoute.call("is_processing_unhandled_input")))
	await _ranger(ecoute)


func _test_ce_qui_n_est_pas_un_appui() -> void:
	print("\n[Ce qui n'est pas un appui ne congédie pas]")
	var affiche := _poser_carton(0)
	var arme := await _attendre_arme(affiche)
	_check("le carton a fini d'entrer", arme)
	if not arme:
		await _ranger(affiche)
		return

	var relache_a := _touche(KEY_A)
	relache_a.pressed = false
	await _envoyer(relache_a)
	_check("le relâchement d'une touche ne congédie pas", _actif(affiche))

	var repetee := _touche(KEY_A)
	repetee.echo = true
	await _envoyer(repetee)
	_check("une touche qui répète (echo) ne congédie pas", _actif(affiche))

	var molette := _clic(MOUSE_BUTTON_WHEEL_UP)
	await _envoyer(molette)
	var molette_bas := _clic(MOUSE_BUTTON_WHEEL_DOWN)
	await _envoyer(molette_bas)
	_check("la molette ne congédie pas", _actif(affiche))

	var souris := InputEventMouseMotion.new()
	souris.position = Vector2(500.0, 500.0)
	souris.relative = Vector2(30.0, 30.0)
	await _envoyer(souris)
	_check("un mouvement de souris ne congédie pas", _actif(affiche))

	var relache_bouton := _bouton(JOY_BUTTON_A, 0)
	relache_bouton.pressed = false
	await _envoyer(relache_bouton)
	_check("le relâchement d'un bouton de manette ne congédie pas", _actif(affiche))

	await _envoyer(_gachette(JOY_AXIS_LEFT_X, 1.0, 0))
	await _envoyer(_gachette(JOY_AXIS_RIGHT_Y, -1.0, 1))
	_check("un stick poussé à fond ne congédie pas", _actif(affiche))
	await _envoyer(_gachette(JOY_AXIS_LEFT_X, 0.0, 0))
	await _envoyer(_gachette(JOY_AXIS_RIGHT_Y, 0.0, 1))

	await _envoyer(_gachette(JOY_AXIS_TRIGGER_RIGHT, 0.3, 0))
	_check("une gâchette à peine effleurée (0,3) ne congédie pas", _actif(affiche))
	await _envoyer(_gachette(JOY_AXIS_TRIGGER_RIGHT, 0.0, 0))

	# Le témoin : le même carton, lui, cède à un vrai appui — sans quoi tous les « ne congédie pas » ci-dessus
	# seraient vrais d'un carton qui ne cède à rien.
	var vrai := _touche(KEY_A)
	await _envoyer(vrai)
	_check("témoin : un vrai appui congédie ce même carton", not _actif(affiche))
	await _relacher(vrai)
	await _ranger(affiche)


# ---------------------------------------------------------------------------
# 3. LE GESTE TENU
# ---------------------------------------------------------------------------

func _test_gachette_tenue() -> void:
	print("\n[Le tir tenu au moment du coup fatal ne passe pas le carton]")
	var tir := _gachette(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0)
	# R2 est enfoncée AVANT que le carton n'existe : c'est le tir qui a tué. Une image pour que l'`Input` la sache.
	Input.parse_input_event(tir)
	Input.flush_buffered_events()
	await process_frame
	_check("témoin : le tir est bien tenu pour le processus", Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.9,
		"%.2f" % Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT))
	var affiche := _poser_carton(0)
	var arme := await _attendre_arme(affiche)
	_check("le carton a fini d'entrer, gâchette toujours tenue", arme)
	# Une gâchette tenue ne se tient pas immobile : la valeur tremble, et chaque tremblement est un événement.
	for valeur in [0.97, 1.0, 0.92, 0.99, 0.85]:
		await _envoyer(_gachette(JOY_AXIS_TRIGGER_RIGHT, valeur, 0))
	_check("le tir tenu, qui tremble, ne congédie pas le carton", _actif(affiche))
	# Relâchée, elle ne congédie pas davantage ; pressée de nouveau, si.
	await _envoyer(_gachette(JOY_AXIS_TRIGGER_RIGHT, 0.0, 0))
	_check("le tir relâché ne congédie pas", _actif(affiche))
	await _envoyer(_gachette(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0))
	_check("le tir pressé de nouveau congédie le carton", not _actif(affiche))
	await _relacher(tir)
	await _ranger(affiche)

	# L'autre gâchette, et l'autre joueur : la garde ne vaut pas que pour R2 de la première manette.
	var torche := _gachette(JOY_AXIS_TRIGGER_LEFT, 1.0, 1)
	Input.parse_input_event(torche)
	Input.flush_buffered_events()
	await process_frame
	var affiche_j2 := _poser_carton(0)
	await _attendre_arme(affiche_j2)
	await _envoyer(_gachette(JOY_AXIS_TRIGGER_LEFT, 0.9, 1))
	_check("la torche de J2, tenue, ne congédie pas non plus", _actif(affiche_j2))
	# Une gâchette de l'autre manette, elle, n'était pas tenue : son premier appui compte.
	await _envoyer(_gachette(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0))
	_check("mais la gâchette d'une autre manette, non tenue, congédie", not _actif(affiche_j2))
	await _relacher(torche)
	await _relacher(_gachette(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0))
	await _ranger(affiche_j2)


# ---------------------------------------------------------------------------
# 4. LA GARDE D'ENTRÉE
# ---------------------------------------------------------------------------

func _test_garde_d_entree() -> void:
	print("\n[Tant que le carton entre, un appui ne compte pas]")
	# L'état du carton est lu juste AVANT l'appui, et son effet juste APRÈS, dans la même image : `flush_buffered_events()`
	# livre l'événement sur-le-champ, aucune image — donc aucun à-coup de la machine — ne peut passer entre les deux. Si un
	# à-coup a laissé le carton finir d'entrer avant l'appui, la mise en place ne prouve rien : on la refait, carton neuf.
	# (Une mesure au chronomètre — « moins de 300 ms » — faisait rougir un lot chargé pour une raison qui n'était pas dans le
	# jeu.) Deux appuis, dans la même image : une touche, puis L1 (« onglet précédent » du salon).
	var affiche: Node = null
	var etait_arme := true
	var essais := 0
	var profondeur := 0
	var profondeur_apres := 0
	var actif_apres := false
	while etait_arme and essais < 5:
		essais += 1
		affiche = _poser_carton(0)
		await process_frame
		etait_arme = _armee(affiche)
		if etait_arme:
			await _ranger(affiche)
			continue
		profondeur = _ui.hub.depth()
		Input.parse_input_event(_touche(KEY_A))
		Input.parse_input_event(_bouton(JOY_BUTTON_LEFT_SHOULDER, 0))
		Input.flush_buffered_events()
		actif_apres = _actif(affiche)
		profondeur_apres = _ui.hub.depth()
	_check("témoin : l'appui est tombé pendant l'entrée, carton pas encore armé (essai %d)" % essais, not etait_arme,
		"armé dès la première image, à chacun des %d essais : plus de garde d'entrée, ou une machine à l'arrêt" % essais)
	if etait_arme:
		return
	_check("un appui pendant l'entrée ne congédie pas", actif_apres)
	# Il n'est pas perdu pour autant : le geste est consommé, il ne va pas agir sur le salon caché dessous.
	_check("un appui pendant l'entrée n'agit pas non plus sur le salon", profondeur_apres == profondeur,
		"%d puis %d" % [profondeur, profondeur_apres])
	await _relacher(_touche(KEY_A))
	await _relacher(_bouton(JOY_BUTTON_LEFT_SHOULDER, 0))
	_check("le carton attend toujours", _actif(affiche))
	var arme := await _attendre_arme(affiche)
	_check("l'entrée finie, le carton est armé", arme)
	await _envoyer(_touche(KEY_A))
	await _relacher(_touche(KEY_A))
	_check("et le même appui, à présent, le congédie", not _actif(affiche))
	await _ranger(affiche)

	# La durée de la garde est celle de l'entrée : ni un nombre de plus, ni une éternité. Mesurée en temps de jeu réel
	# (échelle 1) avec une marge large — un lot chargé, ou un hôte qui gèle un instant, n'est pas un carton qui se trompe.
	# Le plafond est celui de la sécurité du carton moins une marge (`DUREE_MAX`, six secondes) : une garde qui durerait
	# autant ne se lèverait jamais avant que le carton ne parte de lui-même.
	var neuf := _poser_carton(0)
	var debut := Time.get_ticks_msec()
	var tard := debut
	while _actif(neuf) and not _armee(neuf) and Time.get_ticks_msec() - debut < 6000:
		await process_frame
		tard = Time.get_ticks_msec()
	var duree := float(tard - debut) / 1000.0
	_check("la garde dure de 0,15 à 5,5 s (%.2f s), pas un instant, pas une éternité" % duree,
		duree >= 0.15 and duree <= 5.5)
	await _ranger(neuf)


# ---------------------------------------------------------------------------
# 5. RIEN NE FUIT VERS LE SALON
# ---------------------------------------------------------------------------

func _test_pas_de_fuite_vers_le_salon() -> void:
	print("\n[Le geste qui congédie ne fuit pas dans le salon]")
	# Le témoin d'abord : SANS carton, ces mêmes gestes agissent sur le salon. Sinon « rien ne bouge » ne prouverait
	# rien. L1 est « onglet précédent » : elle remonte le salon d'un cran.
	_ui.show_game_over(0)
	await process_frame
	var p_avant: int = _ui.hub.depth()
	await _envoyer(_bouton(JOY_BUTTON_LEFT_SHOULDER, 0))
	await _relacher(_bouton(JOY_BUTTON_LEFT_SHOULDER, 0))
	var p_apres: int = _ui.hub.depth()
	_check("témoin : sans carton, L1 remonte le salon (%d → %d)" % [p_avant, p_apres], p_apres < p_avant)
	var bouge := false
	for dir in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var f_avant: Variant = _ui.p1_focus
		await _envoyer(_bouton(dir, 0))
		await _relacher(_bouton(dir, 0))
		bouge = bouge or _ui.p1_focus != f_avant
	_check("témoin : sans carton, la croix directionnelle déplace le curseur du salon", bouge)
	_ui.hide_game_over()
	_main.game_over = false
	await process_frame

	# Puis AVEC le carton, armé : le geste le congédie, et le salon n'a rien senti.
	for manette in [0, 1]:
		for bouton in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			var affiche := _poser_carton(0)
			await _attendre_arme(affiche)
			var profondeur: int = _ui.hub.depth()
			await _envoyer(_bouton(bouton, manette))
			await _relacher(_bouton(bouton, manette))
			var nom := "L1" if bouton == JOY_BUTTON_LEFT_SHOULDER else "R1"
			_check("%s de la manette %d congédie le carton" % [nom, manette + 1],
				not _actif(affiche))
			_check("… et ne fait pas remonter le salon dessous (%d → %d)" % [profondeur, _ui.hub.depth()],
				_ui.hub.depth() == profondeur)
			await _ranger(affiche)

	for dir in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var affiche := _poser_carton(0)
		await _attendre_arme(affiche)
		var f_avant: Variant = _ui.p1_focus
		var g_avant: Variant = _ui.p2_focus
		await _envoyer(_bouton(dir, 0))
		await _relacher(_bouton(dir, 0))
		_check("la croix directionnelle (%d) congédie le carton, sans déplacer un curseur du salon" % dir,
			(not _actif(affiche))
			and _ui.p1_focus == f_avant and _ui.p2_focus == g_avant)
		await _ranger(affiche)


# ---------------------------------------------------------------------------
# 6. L'ENTRAÎNEMENT
# ---------------------------------------------------------------------------

func _test_entrainement_sans_carton() -> void:
	print("\n[À l'entraînement, il n'y a pas de carton]")
	_main._on_training_requested()
	await process_frame
	await process_frame
	_check("témoin : on est bien à l'entraînement, sans manche armée",
		_main.training_mode and not _main.round_active)
	# Une mort à l'entraînement : `player_died` rend la main tant qu'aucune manche n'est armée.
	_main.player_died(0, 1)
	await process_frame
	await process_frame
	_check("une mort à l'entraînement ne lance aucune fin de manche", not _main._end_sequence_active)
	_check("… aucun écran de fin", not _main.game_over)
	_check("… et aucun carton", _main.get_node_or_null("AfficheDeFin") == null)
