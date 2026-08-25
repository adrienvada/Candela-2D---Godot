## Test headless de l'ossature de navigation du hub — Phase 5, étape 2.
##
## L'ossature porte tout le risque de la refonte : si la pile se trompe d'un
## cran, le joueur atterrit au mauvais endroit, et c'est le genre de défaut qu'on
## met longtemps à croire parce qu'il ressemble à une erreur de manipulation.
## Elle est donc exercée seule, avant qu'un seul écran ne soit rempli.
##
## Lancer : godot --headless --path . --script res://tools/test_menu_hub.gd
extends SceneTree

var _failures: int = 0
var _hub: MenuHub

func _init() -> void:
	print("=== Test de l'ossature du hub ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_hub = MenuHub.new()
	root.add_child(_hub)

	# L'arborescence cible de la structure B, réduite à ce qui se navigue.
	_hub.add_screen(MenuHub.ROOT, "Candela 2D")
	_hub.add_screen("mode", "Jouer")
	_hub.add_screen("prep", "1v1 local")
	_hub.add_screen("online", "1v1 en ligne")
	_hub.add_screen("salon", "Salon")
	_hub.add_screen("cartes", "Cartes")
	_hub.add_screen("options", "Options")
	_hub.add_screen("audio", "Options — audio")
	_hub.reset()
	await process_frame

	_test_depart()
	_test_descente()
	_test_retour()
	_test_racine()
	_test_visibilite()
	_test_deux_chemins()
	_test_reset()
	_test_ecran_inconnu()
	_test_signal()
	_test_panneaux()
	_test_panneau_entree()
	_test_panneau_indisponible()
	_test_style_lanceur()

	root.remove_child(_hub)
	_hub.free()

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

func _test_depart() -> void:
	print("\n[Départ]")
	_check("on démarre à l'accueil", _hub.current_id() == MenuHub.ROOT, _hub.current_id())
	_check("profondeur nulle", _hub.depth() == 0, str(_hub.depth()))

func _test_descente() -> void:
	print("\n[Descente]")
	_hub.reset()
	_check("Jouer accepte", _hub.push("mode"))
	_check("on y est", _hub.current_id() == "mode", _hub.current_id())
	_check("profondeur 1", _hub.depth() == 1, str(_hub.depth()))

	_check("1v1 en ligne accepte", _hub.push("online"))
	_check("Salon accepte", _hub.push("salon"))
	_check("profondeur 3", _hub.depth() == 3, str(_hub.depth()))

	# Sans ce refus, un double appui sur une entrée obligerait à deux retours
	# pour un seul aller — et le joueur croirait le bouton cassé.
	_check("réempiler l'écran courant ne fait rien", not _hub.push("salon"))
	_check("la profondeur n'a pas bougé", _hub.depth() == 3, str(_hub.depth()))

func _test_retour() -> void:
	print("\n[Retour]")
	_hub.reset()
	_hub.push("mode")
	_hub.push("online")
	_hub.push("salon")

	_check("le retour accepte", _hub.back())
	_check("il ramène d'un cran exactement", _hub.current_id() == "online", _hub.current_id())
	_hub.back()
	_check("puis au précédent", _hub.current_id() == "mode", _hub.current_id())
	_hub.back()
	_check("puis à l'accueil", _hub.current_id() == MenuHub.ROOT, _hub.current_id())

func _test_racine() -> void:
	print("\n[Fond de pile]")
	_hub.reset()
	var vu := [false]
	_hub.back_at_root.connect(func() -> void: vu[0] = true)

	_check("le retour à l'accueil est refusé", not _hub.back())
	_check("l'accueil est toujours là", _hub.current_id() == MenuHub.ROOT)
	_check("et il le signale à l'appelant", vu[0])

	# Dix retours de rang ne doivent pas vider la pile : `current_id` lit le
	# dernier élément et planterait sur une pile vide.
	for i in 10:
		_hub.back()
	_check("dix retours n'ont pas vidé la pile", _hub.current_id() == MenuHub.ROOT)

func _test_visibilite() -> void:
	print("\n[Un seul écran visible]")
	_hub.reset()
	_hub.push("mode")
	_hub.push("prep")

	var visibles: Array[String] = []
	for id in ["accueil", "mode", "prep", "online", "salon", "cartes", "options", "audio"]:
		var body := _hub.body_of(id)
		if body != null and body.visible:
			visibles.append(id)

	# Un corps caché est hors d'atteinte du curseur : c'est ce qui empêche la
	# navigation de sortir de l'écran courant.
	_check("exactement un corps est visible", visibles.size() == 1, str(visibles))
	_check("et c'est le courant", visibles.size() == 1 and visibles[0] == "prep", str(visibles))

## Le cas qui justifie une pile plutôt qu'un parent déclaré : la galerie de
## cartes s'ouvre depuis la préparation locale comme depuis le salon en ligne.
func _test_deux_chemins() -> void:
	print("\n[Un écran, deux chemins]")
	_hub.reset()
	_hub.push("mode")
	_hub.push("prep")
	_hub.push("cartes")
	_hub.back()
	_check("depuis la préparation locale, on y revient",
		_hub.current_id() == "prep", _hub.current_id())

	_hub.reset()
	_hub.push("mode")
	_hub.push("online")
	_hub.push("salon")
	_hub.push("cartes")
	_hub.back()
	_check("depuis le salon, on revient au salon",
		_hub.current_id() == "salon", _hub.current_id())

func _test_reset() -> void:
	print("\n[Réinitialisation]")
	_hub.push("mode")
	_hub.push("online")
	_hub.reset()
	_check("on est ramené à l'accueil", _hub.current_id() == MenuHub.ROOT)
	_check("la pile est à plat", _hub.depth() == 0, str(_hub.depth()))
	# Un menu rouvert doit repartir de l'accueil, jamais de l'écran où on l'avait
	# laissé trois crans plus bas.
	_check("le retour est de nouveau refusé", not _hub.back())

func _test_ecran_inconnu() -> void:
	print("\n[Écran inconnu]")
	_hub.reset()
	_check("empiler un identifiant qui n'existe pas est refusé",
		not _hub.push("ecran_qui_nexiste_pas"))
	_check("et ne déplace rien", _hub.current_id() == MenuHub.ROOT)
	_check("la profondeur reste nulle", _hub.depth() == 0, str(_hub.depth()))

func _test_signal() -> void:
	print("\n[Signal]")
	_hub.reset()
	var vus: Array[String] = []
	_hub.screen_changed.connect(func(id: String) -> void: vus.append(id))

	_hub.push("options")
	_hub.push("audio")
	_hub.back()

	_check("chaque changement est annoncé, retours compris",
		vus == ["options", "audio", "options"], str(vus))

# ---------------------------------------------------------------------------
# PANNEAUX DU PANNEAU DE DROITE
# ---------------------------------------------------------------------------

## Un panneau et un seul. La règle est visuelle avant d'être technique : deux
## affichages riches superposés ne se lisent ni l'un ni l'autre.
func _test_panneaux() -> void:
	print("\n[Panneaux — un seul à la fois]")
	var salon := Control.new()
	var galerie := Control.new()
	_hub.register_panel("p_salon", salon)
	_hub.register_panel("p_cartes", galerie)
	_hub.set_screen_panel("salon", "p_salon")

	_check("un panneau enregistré est parenté au panneau de droite",
		salon.get_parent() == _hub.detail_host())
	_check("et il commence caché", not salon.visible)

	# Le nœud est unique par construction : le salon sert cinq écrans, et un
	# second `register_panel` sous la même clé le reparenterait — c'est-à-dire le
	# retirerait du premier endroit.
	var intrus := Control.new()
	_hub.register_panel("p_salon", intrus)
	_check("réenregistrer une clé n'écrase rien",
		_hub.detail_host().get_children().has(salon))
	_check("et l'intrus reste hors de l'arbre", intrus.get_parent() == null)
	intrus.free()

	_hub.reset()
	_hub.push("salon")
	_check("entrer dans l'écran montre son panneau", salon.visible)
	_check("et lui seul", not galerie.visible)

	_hub.show_panel("p_cartes")
	_check("montrer la galerie cache le salon", galerie.visible and not salon.visible)

func _test_panneau_entree() -> void:
	print("\n[Panneaux — portés par une entrée]")
	_hub.reset()
	_hub.push("salon")

	var pret := _hub.make_entry("PRÊT", "Lance le match.", "", Color.WHITE, "lancer")
	var cartes := _hub.make_entry("CHANGER DE CARTE", "Choisir l'arène.",
		"", Color.WHITE, "", "", false, "p_cartes")
	_hub.list_of("salon").add_child(pret)
	_hub.list_of("salon").add_child(cartes)

	var salon: Control = _hub.panneau("p_salon")

	# Le geste que la refonte devait rendre possible : montrer les vignettes sans
	# descendre d'un cran.
	cartes.mouse_entered.emit()
	_check("survoler l'entrée montre son panneau",
		_hub.panneau("p_cartes").visible)
	_check("sans changer d'écran", _hub.current_id() == "salon", _hub.current_id())

	# Et le repli, qui est la moitié du travail : une entrée sans panneau ne vide
	# pas la droite, elle rend l'écran à son panneau par défaut. Sans cela le
	# salon disparaîtrait dès que le curseur se pose sur « PRÊT ».
	pret.mouse_entered.emit()
	_check("une entrée sans panneau rend l'écran à son défaut", salon.visible)
	_check("et la galerie se retire",
		not _hub.panneau("p_cartes").visible)

## Une entrée grisée n'emmène nulle part, panneau compris : afficher la galerie
## sous une entrée indisponible laisserait croire qu'elle est utilisable.
func _test_panneau_indisponible() -> void:
	print("\n[Panneaux — entrée indisponible]")
	_hub.reset()
	_hub.push("salon")
	var salon: Control = _hub.panneau("p_salon")
	var galerie: Control = _hub.panneau("p_cartes")

	var grise := _hub.make_entry("CHANGER DE CARTE", "Choisir l'arène.",
		"", Color.WHITE, "", "Pas encore disponible.", false, "p_cartes")
	_hub.list_of("salon").add_child(grise)

	grise.mouse_entered.emit()
	_check("le panneau d'une entrée grisée ne s'ouvre pas", not galerie.visible)
	_check("et l'écran garde le sien", salon.visible)

	# Le relais des curseurs maison. Il ne double pas la souris par confort : les
	# deux curseurs du jeu dessinent un liseré sans appeler `grab_focus()`, donc
	# `focus_entered` ne part jamais à la manette. Sans lui, tout ce chapitre ne
	# marcherait qu'à la souris.
	var cartes := _hub.make_entry("CHANGER DE CARTE", "Choisir l'arène.",
		"", Color.WHITE, "", "", false, "p_cartes")
	_hub.list_of("salon").add_child(cartes)
	_check("le relais reconnaît une entrée du hub", _hub.reveal_entry(cartes))
	_check("et ouvre son panneau sans souris ni focus", galerie.visible)

	# Une vignette de carte, un bouton d'arme : on est en train de s'en servir,
	# le panneau de droite ne doit surtout pas changer sous les doigts.
	var etranger := Button.new()
	_check("un contrôle étranger au hub est ignoré", not _hub.reveal_entry(etranger))
	_check("et le panneau ne bouge pas", galerie.visible)
	etranger.free()

## Le style d'une entrée « lanceur », et pourquoi ce banc existe.
##
## Le correctif du 2026-08-18 est arrivé avec sa propre note d'honnêteté : « ce
## banc ne teste que la navigation, jamais le style, et ne peut donc pas garantir
## ce correctif à lui seul ». C'est ce trou-là qu'on comble.
##
## Le défaut relevé par Adrien à l'usage : JOUER, PRÊT, CHERCHER UN MATCH et
## LANCER L'ENTRAÎNEMENT peignaient leur fond et leur cadre au repos avec
## `MenuTheme.P1`/`.P2` — **la couleur du liseré des curseurs**. Un lanceur
## portait donc en permanence la teinte qu'un curseur ne devrait porter qu'en le
## visant, et l'œil croyait voir la sélection là où elle n'était pas.
##
## Ce qui est vérifié n'est donc pas « c'est joli » mais **une couleur ne dit
## qu'une chose** : au repos, aucune entrée ne porte la couleur d'un curseur.
func _test_style_lanceur() -> void:
	print("\n[Le style d'un lanceur]")
	var ordinaire := _hub.make_entry("ORDINAIRE", "", "", MenuTheme.P1)
	var lanceur := _hub.make_entry("LANCEUR", "", "", MenuTheme.P1, "lancer", "", true)

	var s_ord := ordinaire.get_theme_stylebox("normal") as StyleBoxFlat
	var s_lan := lanceur.get_theme_stylebox("normal") as StyleBoxFlat
	_check("les deux ont bien un style au repos", s_ord != null and s_lan != null)
	if s_ord == null or s_lan == null:
		return

	_check("au repos, le lanceur a le fond commun", s_lan.bg_color == s_ord.bg_color,
		"%s contre %s" % [s_lan.bg_color, s_ord.bg_color])
	_check("et le cadre commun", s_lan.border_color == s_ord.border_color,
		"%s contre %s" % [s_lan.border_color, s_ord.border_color])
	# LE test. Ni P1 ni P2 au repos, sur aucune entrée : ces deux teintes
	# appartiennent aux curseurs et à personne d'autre.
	for couple in [[s_ord, "ordinaire"], [s_lan, "lanceur"]]:
		var st: StyleBoxFlat = couple[0]
		_check("l'entrée %s ne porte la couleur d'aucun curseur" % couple[1],
			st.border_color != MenuTheme.P1 and st.border_color != MenuTheme.P2
			and st.bg_color != MenuTheme.P1 and st.bg_color != MenuTheme.P2,
			"fond %s, cadre %s" % [st.bg_color, st.border_color])

	# Ce qui distingue un lanceur a remplacé la couleur : le gras.
	_check("le lanceur se reconnaît à son gras",
		_gras(lanceur) and not _gras(ordinaire))

	# Et la marque que M8 lit — désormais le SEUL moyen de retrouver un lanceur au
	# code, puisqu'il n'a plus de style à lui.
	_check("le lanceur porte la marque, l'ordinaire non",
		bool(lanceur.get_meta(MenuHub.META_LAUNCHER, false))
		and not bool(ordinaire.get_meta(MenuHub.META_LAUNCHER, false)))

	# Une entrée indisponible n'est pas un lanceur, quoi qu'on demande : elle
	# n'engage rien, et la mettre en gras la ferait crier plus fort que les
	# entrées qui marchent.
	var grise := _hub.make_entry("GRISÉ", "", "", MenuTheme.P1, "lancer",
		"pas encore", true)
	_check("une entrée grisée ne passe pas en gras", not _gras(grise))

	ordinaire.free()
	lanceur.free()
	grise.free()

func _gras(btn: Button) -> bool:
	for row in btn.get_children():
		for child in row.get_children():
			if child is Label:
				var f := (child as Label).get_theme_font("font")
				if f is FontVariation and (f as FontVariation).variation_embolden > 0.0:
					return true
	return false
