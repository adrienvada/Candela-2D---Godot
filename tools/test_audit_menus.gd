## Audit du hub : **aucune entrée ne laisse le cadre de droite vide.**
##
## Demandé par Adrien le 2026-08-18, et écrit comme une suite plutôt que comme
## une inspection : une vérification à la main vaut pour le jour où on la fait,
## un test vaut pour toutes les entrées qui seront ajoutées ensuite. Le hub compte
## des dizaines d'entrées réparties sur une vingtaine d'écrans — les parcourir à
## l'œil une fois ne garantit rien sur la suivante.
##
## La règle : survoler ou sélectionner une entrée doit **montrer quelque chose**.
## Un cadre qui reste vide se lit comme un défaut d'affichage, et il apprend au
## joueur à ne plus regarder à droite — après quoi les entrées qui, elles, ont
## quelque chose à dire ne sont plus lues non plus.
##
## « Quelque chose » veut dire un texte **ou** un panneau. Une entrée qui ouvre la
## galerie de cartes n'a pas besoin de phrase : le panneau parle pour elle.
##
## Lancer : godot --headless --path . --script res://tools/test_audit_menus.gd
extends SceneTree

var _failures: int = 0
var _ui: Node

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== AUDIT DU CADRE DE DROITE ===")
	# Après une frame : les autoloads référencés par `ui.gd` n'existent pas encore
	# au moment de `_init`, et la scène rendrait un nœud nu dont les erreurs
	# n'incrémentent aucun compteur.
	await process_frame
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		printerr("✗ main.tscn introuvable")
		quit(1)
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_ui = main.get_node_or_null("UI")
	if _ui == null or not _ui.has_method("show_pick_window"):
		printerr("✗ l'interface n'a pas son script")
		quit(1)
		return

	_audit_entrees()
	_audit_panneaux_declares()
	_audit_personnalisation()
	_audit_carte_appartient_a_l_hote()
	await _audit_la_colonne_de_lecture()
	await _audit_le_cadre_montre_vraiment()
	await _audit_on_peut_lancer_une_recherche()
	_audit_aucun_cadre_vide()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	main.queue_free()
	quit(1 if _failures > 0 else 0)

## **Peut-on cliquer sur ce qui cherche un adversaire ?**
##
## ⚠️ Le bouton du cadre était grisé en 1v1 amical et en compétitif — relevé par
## Adrien à l'écran le 2026-08-26. La règle « pas de second joueur, pas de
## départ » s'y appliquait, alors qu'elle n'a de sens que pour un salon privé :
## **chercher un adversaire, c'est très exactement ne pas en avoir.** Le bouton
## se grisait donc pour la raison même qui justifiait de s'en servir, et
## l'appariement devenait inatteignable à la souris comme à la manette.
##
## Aucun banc ne pouvait l'attraper : ils vérifiaient tous qu'une entrée EXISTE
## et qu'elle porte un libellé. **Un bouton présent, nommé, et désactivé passe
## tous ces contrôles** — c'est la troisième forme du même motif, après le cadre
## de droite vide et la souris masquée.
## **Aucune entrée, nulle part, ne laisse le cadre de droite noir.**
##
## ⚠️ Ce fichier porte ce titre depuis le 2026-08-18 et ne le vérifiait pas. Son
## premier contrôle lit `_entry_details` et exige un texte **ou** un panneau —
## or le texte va désormais au pied du cadre, pas dans le cadre. Une entrée sans
## panneau le laisse donc noir tout en passant ce contrôle.
##
## L'audit du 2026-08-26 en a trouvé **dix**, sur cinq écrans : les cinq
## « RETOUR », « QUITTER », « CRÉER » et « REJOINDRE » des deux écrans de salon,
## et un bouton de l'écran de mise à jour. Aucune n'était exotique — ce sont les
## entrées qu'on ne pense jamais à survoler pour vérifier une image.
##
## **Ce contrôle-ci RÉSOUT ce que le cadre montrerait** — le panneau de l'entrée,
## ou à défaut celui de l'écran — au lieu de lire les dictionnaires. C'est la
## troisième fois que la distinction tranche : on ne vérifie pas qu'il y a de
## quoi montrer, on vérifie ce qui serait montré.
func _audit_aucun_cadre_vide() -> void:
	print("\n[Aucune entrée ne laisse le cadre de droite noir]")
	var hub = _ui.hub
	var vides: Array[String] = []
	for ecran: String in hub._lists.keys():
		var defaut: String = hub.screen_panel(ecran)
		var liste: Node = hub.list_of(ecran)
		if liste == null:
			continue
		for enfant in liste.get_children():
			var btn := enfant as Button
			if btn == null:
				continue
			var d: Variant = hub._entry_details.get(btn, null)
			var panneau := ""
			var nom := "(sans nom)"
			if d is Dictionary:
				panneau = String((d as Dictionary).get("panneau", ""))
				nom = String((d as Dictionary).get("titre", nom))
			var montre: String = panneau if panneau != "" else defaut
			if montre == "":
				vides.append("%s / %s" % [ecran, nom])
	_check("aucune entrée ne laisse le cadre noir", vides.is_empty(),
		", ".join(vides))


func _audit_on_peut_lancer_une_recherche() -> void:
	print("\n[Le bouton qui cherche un adversaire est cliquable]")
	var hub = _ui.hub
	# ⚠️ **Tous les écrans qui portent un lanceur, pas les deux qu'Adrien a
	# signalés.** La table `LANCEURS` fait foi : elle est la déclaration, et la
	# parcourir garantit qu'un écran ajouté demain sera couvert du seul fait de
	# s'y inscrire.
	#
	# Ce contrôle a été écrit deux fois. La première version ne visait que les
	# deux écrans d'appariement ; le défaut est réapparu **le lendemain sur
	# l'écran scindé**, par un troisième retour anticipé que personne n'avait
	# regardé. Corriger — et vérifier — cas par cas est ce qui a échoué.
	for ecran: String in _ui.LANCEURS.keys():
		if not hub.has_screen(ecran):
			continue
		hub.reset()
		hub.push(ecran)
		# ⚠️ **Il faut reproduire la CONDITION, pas seulement l'écran.**
		#
		# Premier jet de ce contrôle : il entrait dans l'écran et lisait le bouton.
		# Il passait au vert **même en remettant la règle fautive** — parce qu'au
		# repos le mode réseau vaut `LOCAL_SPLITSCREEN`, et que le grisage ne
		# s'arme qu'en ligne. Le banc regardait le bon bouton dans le mauvais état,
		# ce qui est la définition d'un contrôle décoratif.
		#
		# On pose donc le mode en ligne sans pair connecté : très exactement ce
		# qu'est un joueur qui arrive sur l'écran pour chercher un adversaire.
		# Par le CHEMIN d'autoload : `NetworkManager` n'est pas un identifiant à la
		# compilation dans un banc lancé en `--script`, et le nommer empêche le
		# fichier de compiler. Même idiome que `match_banner.gd`. **Par `root` et non
		# par `self`** : ce banc étend `SceneTree`, qui n'est pas un `Node` et n'a
		# donc pas `get_node_or_null()`.
		var reseau: Node = root.get_node_or_null(^"NetworkManager")
		if reseau == null:
			_check("NetworkManager joignable", false)
			continue
		# 1 = `GameMode.ONLINE_HOST`. Le littéral est commenté parce qu'une
		# énumération d'autoload n'est pas atteignable depuis un `--script` — et un
		# nombre nu ici serait exactement la valeur absolue qu'on chasse ailleurs.
		reseau.current_mode = 1
		# ⚠️ **On reproduit le CHEMIN, pas seulement l'écran.** Le défaut ne se
		# déclenche pas si l'on arrive directement : il faut d'abord passer par un
		# écran de salon, qui grise le bouton faute de second joueur. C'est ce
		# passage-là qui laissait l'état collé — et c'est pourquoi le premier jet
		# de ce contrôle passait au vert même avec la règle fautive en place.
		_ui._refresh_lobby_block()
		if _ui.panel_launch != null:
			_ui.panel_launch.disabled = true
		await process_frame
		_ui._refresh_lobby_block()
		await process_frame
		await process_frame
		var b = _ui.panel_launch
		if b == null:
			_check("le bouton du cadre existe (%s)" % ecran, false)
			continue
		_check("« %s » est visible (%s)" % [b.text, ecran], b.visible)
		# **Le contrôle attend le bon état, pas « toujours cliquable ».** Un salon
		# privé sans second joueur DOIT être grisé : partir seul n'aurait pas de
		# sens, et le bouton reste visible pour dire « il manque quelqu'un » plutôt
		# que « il n'y a rien à lancer ici ». Ce qui ne doit jamais l'être, c'est
		# ce qui n'attend personne.
		var action := String((_ui.LANCEURS[ecran] as Array)[1])
		# **L'écran scindé lance à deux sur la même machine** : il porte l'action
		# `lancer` et n'attend pourtant personne. Le banc lit donc le mode, comme
		# le code — sans quoi il exigerait un grisage qui serait un défaut.
		var en_ligne: bool = _ui.selected_network_mode() != 0
		if action == "lancer" and en_ligne:
			_check("« %s » attend un second joueur, donc grisé (%s)" % [b.text, ecran],
				b.disabled, "cliquable alors qu'il manque quelqu'un")
		else:
			_check("« %s » est CLIQUABLE (%s)" % [b.text, ecran], not b.disabled,
				"grisé alors qu'il n'attend personne : inatteignable")
		# Le libellé n'est vérifié que là où il promet une recherche : ailleurs, le
		# lanceur dit « PRÊT » et c'est très bien.
		if String((_ui.LANCEURS[ecran] as Array)[1]) == "chercher":
			_check("son libellé dit qu'on cherche (%s)" % ecran,
				b.text.to_upper().contains("RECHERCHE"), b.text)
	var reseau_fin: Node = root.get_node_or_null(^"NetworkManager")
	if reseau_fin != null:
		reseau_fin.current_mode = 0  # LOCAL_SPLITSCREEN : on rend l'état trouvé.
	hub.reset()


## Le cadre MONTRE-t-il, ou a-t-il seulement de quoi montrer ?
##
## ⚠️ **Ce banc s'intitule « aucune entrée ne laisse le cadre de droite vide » et
## il était vert pendant que le cadre était noir.** Tout ce qui précède lit
## `_entry_details` : la donnée existe, elle a toujours existé. L'affichage, lui,
## n'avait jamais été regardé — les deux `Control` qui portent le texte étaient
## cachés depuis leur construction et rien ne les rallumait (DA4.18).
##
## **La règle qui en sort, et elle vaut au-delà d'ici : quand un contrôle porte
## sur de l'affichage, l'assertion finale lit une propriété du NŒUD RENDU** —
## `visible`, `size` — et jamais le dictionnaire qui l'a alimenté. Les deux sont à
## un appel de distance, et un seul dit la vérité.
##
## La largeur est vérifiée autant que la visibilité : au moment du diagnostic, le
## `RichTextLabel` naissait à **un pixel** de large dans son panneau caché. Visible
## mais large d'un pixel, il aurait produit exactement le même écran noir.
## **La colonne de lecture tient-elle, et l'exception est-elle une exception ?**
##
## Le cadre de droite fait près de 900 px. DA4.18 y a posé une colonne large de
## `Charte.MESURE` signes pour que les paragraphes cessent de s'étaler — mais un
## plafond d'étirement est **invisible tant qu'on ne le mesure pas** : rien à
## l'écran ne dit qu'une colonne aurait pu être plus large. Il disparaîtrait
## sous n'importe quel `SIZE_EXPAND_FILL` posé demain dans un écran, sans une
## erreur ni un pixel de différence ailleurs.
##
## ⚠️ **On mesure le nœud RENDU, jamais le réglage.** `size_flags_horizontal`
## dit ce qu'on a demandé ; `size.x` dit ce qu'on a obtenu. Le dépôt a déjà payé
## trois fois la différence — `EXPAND_KEEP_SIZE`, `icon_max_width`, et le
## `RichTextLabel` large d'un pixel qui rendait le même écran noir qu'un nœud
## caché.
##
## Les deux versants comptent. Sans le second, mettre `pleine_largeur()` à `true`
## partout ferait passer le contrôle au vert en supprimant ce qu'il protège.
func _audit_la_colonne_de_lecture() -> void:
	print("\n[La colonne de lecture plafonne l'étirement, sauf là où c'est dit]")
	var hub = _ui.hub
	var large: float = hub._detail_host.size.x
	if large <= 0.0:
		_check("le cadre de droite a une largeur mesurable", false,
			"%.0f px" % large)
		return

	# La mesure attendue, relevée sur la fonte réelle comme le fait le code.
	var plafond: float = Charte.mesure_px()

	# ⚠️ **L'attendu est écrit ICI, et surtout pas demandé à l'écran.**
	#
	# Le premier jet de ce contrôle lisait `ecran.pleine_largeur()` puis
	# vérifiait que la largeur rendue correspondait. **Il passait au vert avec
	# la règle entièrement désactivée** — mettre le défaut du contrat à `true`
	# faisait s'étaler les quatre panneaux ET changeait l'attendu avec eux.
	# Vérifié en le sabotant : quatre ✓ franchement faux.
	#
	# C'est la quatrième fois de ce chantier qu'un banc mesure la cohérence d'un
	# objet avec lui-même au lieu de le confronter à une décision. Un banc dont
	# l'oracle sort du code testé ne teste rien : il paraphrase.
	#
	# Cette table EST la décision de DA4.18. Un écran qui change de camp doit
	# faire rougir ce fichier — c'est le but, pas une gêne.
	var attendu := {
		_ui.PANEL_PROFILE: false,
		_ui.PANEL_AUDIO: false,
		_ui.PANEL_EFFECTS: false,
		_ui.PANEL_HISTORY: true,
	}
	for cle: String in attendu.keys():
		var boite: Control = hub.panneau(cle)
		if boite == null:
			_check("le panneau %s existe" % cle, false)
			continue
		hub._apply_panel(cle)
		await process_frame
		await process_frame
		var veut_tout: bool = bool(attendu[cle])
		# Et le contrat doit dire la même chose que la table : sans ce contrôle,
		# on pourrait satisfaire la largeur par accident — un enfant assez
		# exigeant remplit le cadre sans que personne l'ait décidé.
		var ecran: HubScreen = _ui._screens.get(cle)
		_check("%s déclare ce que la charte attend de lui" % cle,
			ecran != null and ecran.pleine_largeur() == veut_tout,
			"déclaré %s, attendu %s" % [
				"plein" if ecran != null and ecran.pleine_largeur() else "colonne",
				"plein" if veut_tout else "colonne"])
		if veut_tout:
			# L'historique est un tableau : il doit atteindre les bords.
			_check("%s prend bien toute la largeur" % cle,
				boite.size.x >= large - 1.0,
				"%.0f px sur %.0f" % [boite.size.x, large])
		else:
			# Le plafond retire l'étirement, pas la place : un enfant plus
			# exigeant a le droit d'élargir la colonne. Ce qu'on interdit, c'est
			# de remplir le cadre faute d'avoir été bridé.
			_check("%s ne s'étale pas sur tout le cadre" % cle,
				boite.size.x < large - 1.0,
				"%.0f px sur %.0f (plafond visé %.0f)"
					% [boite.size.x, large, plafond])

	# Et la mesure elle-même doit rester un rapport, pas un nombre : elle grandit
	# avec la taille de fonte. Une valeur figée serait juste pour un seul cran de
	# l'échelle typographique et fausse pour les cinq autres.
	_check("la mesure suit la taille de fonte",
		Charte.mesure_px(Charte.T_APPUI) > Charte.mesure_px(Charte.T_COURANT),
		"%.0f px puis %.0f px" % [Charte.mesure_px(Charte.T_COURANT),
			Charte.mesure_px(Charte.T_APPUI)])


func _audit_le_cadre_montre_vraiment() -> void:
	print("\n[Le cadre de droite montre, il n'a pas seulement de quoi montrer]")
	var hub = _ui.hub

	hub.montrer_texte("MON RANG", "Argent II — 1240 ELO")
	await process_frame
	await process_frame

	_check("montrer_texte allume bien le panneau de texte",
		hub.shown_panel() == hub.PANNEAU_TEXTE, hub.shown_panel())
	_check("le titre du cadre est visible", hub._detail_title.visible)
	_check("le corps du cadre est visible", hub._detail_text.visible)
	# Un `RichTextLabel` de un pixel de large rend un écran noir aussi sûrement
	# qu'un nœud caché.
	_check("le corps du cadre a une largeur utile",
		hub._detail_text.size.x > 200.0, "%.0f px" % hub._detail_text.size.x)

	# Et le versant inverse : une simple description d'entrée ne doit PAS
	# s'emparer du cadre. Elle part dans l'en-tête, sous le titre — décision du
	# 2026-08-18, « lire l'explication d'une entrée ne devrait pas demander de
	# traverser l'écran du regard ». Sans ce contrôle, la corriger d'un côté la
	# ferait réapparaître en double de l'autre.
	hub.show_detail("Une entrée", "Sa description appartient à l'en-tête.")
	await process_frame
	_check("une description d'entrée ne s'empare pas du cadre",
		hub.shown_panel() != hub.PANNEAU_TEXTE, hub.shown_panel())


## Chaque entrée du hub porte-t-elle de quoi remplir la droite ?
func _audit_entrees() -> void:
	print("\n[Chaque entrée a quelque chose à montrer]")
	var details: Dictionary = _ui.hub._entry_details
	_check("le hub a bien des entrées", details.size() > 10, str(details.size()))

	var muettes: Array[String] = []
	for btn: Variant in details.keys():
		if not is_instance_valid(btn):
			continue
		var d: Dictionary = details[btn]
		var texte := String(d.get("texte", "")).strip_edges()
		var panneau := String(d.get("panneau", "")).strip_edges()
		if texte.is_empty() and panneau.is_empty():
			muettes.append(_nom(details, btn))
	_check("aucune entrée ne laisse le cadre vide", muettes.is_empty(),
		", ".join(muettes))

	# Une entrée grisée doit dire POURQUOI, sans quoi le joueur ne peut pas
	# distinguer « pas encore » de « cassé ». `make_entry` met la raison à la
	# place du détail — on vérifie qu'aucune n'est grisée sans raison.
	var sans_raison: Array[String] = []
	for btn: Variant in details.keys():
		if not is_instance_valid(btn):
			continue
		var b: Button = btn
		if not b.disabled:
			continue
		if String((details[btn] as Dictionary).get("texte", "")).strip_edges().is_empty():
			sans_raison.append(_nom(details, b))
	_check("aucune entrée grisée ne tait sa raison", sans_raison.is_empty(),
		", ".join(sans_raison))

## Les panneaux désignés par les entrées existent-ils vraiment ?
##
## `_apply_panel()` retombe silencieusement sur le panneau par défaut de l'écran
## quand la clé est inconnue : une entrée qui viserait un panneau mal orthographié
## montrerait donc autre chose que ce qu'elle annonce, **sans erreur**. C'est le
## même défaut que `push()` sur un identifiant inconnu, déjà consigné.
func _audit_panneaux_declares() -> void:
	print("\n[Les panneaux visés existent]")
	var details: Dictionary = _ui.hub._entry_details
	var connus: Dictionary = _ui.hub._panels
	var fantomes: Array[String] = []
	for btn: Variant in details.keys():
		if not is_instance_valid(btn):
			continue
		var panneau := String((details[btn] as Dictionary).get("panneau", ""))
		if panneau.is_empty():
			continue
		if not connus.has(panneau):
			fantomes.append("%s → %s" % [_nom(details, btn), panneau])
	_check("aucune entrée ne vise un panneau inexistant", fantomes.is_empty(),
		", ".join(fantomes))
	print("    %d panneaux enregistrés" % connus.size())

## Personnalisation ne descend nulle part : ses quatre rubriques se règlent dans
## le cadre.
##
## Demandé par Adrien le 2026-08-18, après une première tentative qui n'avait
## déplacé que la calibration : « Je ne dois pas rentrer dans un autre menu en
## dessous de personnalisation ». Le test l'écrit sous sa forme vérifiable — aucune
## entrée ne vise un écran, chacune vise un panneau, et ce panneau porte de quoi
## régler quelque chose.
##
## Le dernier point est celui qui compte. Un panneau enregistré mais vide passerait
## les deux contrôles précédents : l'entrée aurait bien un panneau, ce panneau
## existerait bien, et la rubrique n'afficherait rien.
func _audit_personnalisation() -> void:
	print("\n[Personnalisation ne descend nulle part]")
	var liste: VBoxContainer = _ui.hub.list_of(_ui.SCREEN_CUSTOM)
	if liste == null:
		_check("l'écran de personnalisation existe", false)
		return
	var details: Dictionary = _ui.hub._entry_details
	# Ce qu'on compte : des commandes ACTIONNABLES, pas des boutons. Les effets se
	# règlent au curseur et l'audio au bouton ; exiger des boutons partout aurait
	# fait passer une rubrique entière pour vide alors qu'elle est complète.
	# ⚠️ **CONTRÔLES se DÉDUIT, il ne se chiffre plus.** Ce seuil valait `6` avec
	# le commentaire « trois actions × deux joueurs » — les trois étant Tirer,
	# Torche et Courir. Le sprint supprimé le 2026-08-26, la rubrique est tombée
	# à 4 et ce banc a rougi **en accusant la rubrique des contrôles**, un écran
	# qui n'avait rien fait. DA2 l'a remis à `4`, ce qui était juste.
	#
	# **Mais un nombre écrit à la main redeviendra faux à la prochaine action
	# ajoutée ou retirée**, et il rougira encore au nom d'un innocent. Pire :
	# `grep sprint` ne pouvait pas trouver ce `6`. Le seuil COMPTAIT le sprint
	# sans jamais le NOMMER — même piège qu'un argument passé en littéral, qui
	# ne porte plus le nom de ce qu'il transmet.
	#
	# Dérivé de `BINDABLE`, il suit tout seul. Et il vérifie une propriété plus
	# forte que « au moins quatre commandes » : **chaque action déclarée produit
	# bien ses deux colonnes de joueur.** Une action ajoutée sans ligne d'écran,
	# ou une colonne perdue, le fait rougir — ce qu'un nombre figé ne voyait pas.
	#
	# Ce n'est pas l'oracle-tiré-du-code-testé de la colonne de lecture : la
	# table déclare, l'écran construit, et ce sont deux chemins distincts. On
	# vérifie que le second honore la première.
	var attendus := {
		"CONTRÔLES": _ui.BINDABLE.size() * 2,
		"AFFICHAGE": 9,  # 3 résolutions + 2 vsync + 5 cadences, au moins
		"EFFETS": 4,
		"AUDIO": 4,
	}
	var vus: Array[String] = []
	for enfant in liste.get_children():
		if not enfant is Button:
			continue
		var btn: Button = enfant
		var libelle := _nom(details, btn)
		if not attendus.has(libelle):
			continue
		vus.append(libelle)
		var d: Dictionary = details.get(btn, {})
		var cle := String(d.get("panneau", ""))
		# Une rubrique de réglages ne doit PAS être une destination. `make_entry`
		# ne garde pas la cible d'une entrée : on la reconnaît à ce qu'elle n'a
		# pas de panneau — une entrée qui pousse un écran laisse la clé vide.
		_check("%s ne pousse aucun écran" % libelle, cle != "")
		_check("%s a un panneau" % libelle, cle != "")
		if cle == "":
			continue
		var contenu: Control = _ui.hub._panels.get(cle, null)
		var commandes := _compte_commandes(contenu)
		_check("%s montre ses réglages dans le cadre (%d commandes)" % [libelle, commandes],
			commandes >= int(attendus[libelle]),
			"attendu au moins %d" % int(attendus[libelle]))
	for libelle: String in attendus.keys():
		_check("la rubrique %s est présente" % libelle, vus.has(libelle))

## Le libellé d'une entrée, tel qu'il s'affiche.
##
## `Button.text` est VIDE sur toutes les entrées du hub : le libellé vit dans un
## `Label` enfant, à côté du chevron. Une première version de cet audit nommait
## donc les entrées fautives par une chaîne vide — le test aurait bien échoué,
## mais sans dire sur quoi.
func _nom(details: Dictionary, btn: Button) -> String:
	return String((details.get(btn, {}) as Dictionary).get("titre", "")).strip_edges()

## Compte ce qu'un joueur peut réellement actionner dans un panneau.
##
## Le critère est la **focalisabilité**, pas le type : un bouton, un curseur de
## volume et une case à cocher se règlent tous, un `Label` non. C'est aussi le
## critère du système de navigation à deux curseurs — compter autre chose ici
## reviendrait à mesurer une propriété que personne n'utilise.
func _compte_commandes(racine: Control) -> int:
	if racine == null:
		return 0
	var n := 0
	for enfant in racine.get_children():
		if enfant is Control:
			var c: Control = enfant
			if c.focus_mode != Control.FOCUS_NONE:
				n += 1
			n += _compte_commandes(c)
	return n

## Famille 7.2 de la checklist en ligne : **la carte appartient à l'hôte.**
##
## L'invité ne doit pas se voir proposer d'en changer — non par avarice, mais
## parce que son choix serait **écrasé au lancement** : c'est la carte de l'hôte
## qui est envoyée. Un bouton qui laisse choisir puis n'en tient pas compte est
## pire qu'un bouton absent ; il fait croire à une décision qui n'existe pas.
##
## Vérifié ici plutôt que dans un banc à deux instances : c'est une propriété de
## structure du menu, elle ne demande ni réseau ni adversaire, et elle est
## déterministe — contrairement à tout ce qui s'échantillonne pendant une
## transition.
func _audit_carte_appartient_a_l_hote() -> void:
	print("\n[La carte appartient à l'hôte]")
	var details: Dictionary = _ui.hub._entry_details
	var avec_cartes := func(ecran: String) -> bool:
		var liste: VBoxContainer = _ui.hub.list_of(ecran)
		if liste == null:
			return false
		for enfant in liste.get_children():
			if not enfant is Button:
				continue
			var d: Dictionary = details.get(enfant, {})
			if String(d.get("panneau", "")) == _ui.PANEL_MAPS:
				return true
		return false

	for hote: String in [_ui.SCREEN_HOST, _ui.SCREEN_LOCAL_HOST]:
		_check("l'hôte peut changer de carte (%s)" % hote, avec_cartes.call(hote))
	for invite: String in [_ui.SCREEN_JOIN, _ui.SCREEN_LOCAL_JOIN]:
		_check("l'invité ne se voit pas proposer d'en changer (%s)" % invite,
			not avec_cartes.call(invite))
	# Et l'écran partagé, lui, l'offre : les deux joueurs sont du même côté.
	_check("l'écran partagé garde le choix de la carte",
		avec_cartes.call(_ui.SCREEN_LOCAL))
