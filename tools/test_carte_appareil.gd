## Le clavier dessiné dit-il la vérité des doigts ? (DA4.11)
##
## **Ce banc mesure ce qu'aucune relecture ne peut voir.** Un clavier dessiné est
## un objet dont chaque capuchon paraît juste isolément : ni le langage, ni le
## rendu, ni l'œil ne distinguent un capuchon allumé au bon endroit d'un
## capuchon allumé à côté. C'est exactement la famille du libellé faux réparé la
## veille — *un libellé faux reste un libellé valide*.
##
## ## Les quatre propriétés
##
## 1. **La disposition ne se recouvre pas.** Trente capuchons posés en unités de
##    touche : deux qui se chevaucheraient donneraient un clavier illisible, et
##    un décalage de rangée mal réglé le produit sans rien casser.
##
## 2. **Les touches allumées viennent de l'`InputMap`, pas d'une table.** Le
##    contrôle relit les liaisons réelles et exige que le dessin les suive. Une
##    table recopiée serait juste le jour de son écriture et mentirait à la
##    première réassignation — **sur l'écran même qui sert à réassigner.**
##
## 3. **Une collision est nommée.** Deux joueurs sur la même touche, c'est deux
##    joueurs qui ne peuvent pas jouer ensemble. Ce n'est pas un détail
##    d'affichage : c'est la seule question que se posent deux personnes devant
##    un clavier partagé, et le dessin existe pour y répondre.
##
## 4. **Le libellé est traduit, jamais supposé.** Le jeu lie par position ;
##    afficher la lettre du QWERTY à un joueur AZERTY serait exact du point de
##    vue du code et faux du point de vue de sa main.
##
## ⚠️ **La classe est chargée par son CHEMIN, jamais nommée.** Nommer une classe
## dans un banc lancé par `--script` en fait une dépendance de **compilation** :
## Godot la compilerait avant qu'aucun autoload existe. Piège payé le 2026-08-26
## par `tools/test_bandeau_fatal.gd`.

extends SceneTree

var _ok := 0
var _ko := 0


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


# ---------------------------------------------------------------------------
# 1. LA DISPOSITION
# ---------------------------------------------------------------------------

func _test_aucun_capuchon_n_en_recouvre_un_autre(carte: GDScript) -> void:
	var d: Dictionary = carte.disposition_clavier()
	var touches: Array = d["touches"]
	_check(touches.size() >= 28,
		"seulement %d capuchons : la disposition a perdu une rangée"
			% touches.size())

	var vus := {}
	var chevauchements: Array[String] = []
	for i in touches.size():
		var a: Rect2 = (touches[i] as Dictionary)["r"]
		var code_a: int = (touches[i] as Dictionary)["code"]
		# ⚠️ Un même code physique posé deux fois serait un clavier à deux
		# touches « O » : le dessin allumerait les deux, et le joueur ne saurait
		# pas laquelle presser.
		_check(not vus.has(code_a),
			"le code physique %d apparaît deux fois dans la disposition" % code_a)
		vus[code_a] = true
		for j in range(i + 1, touches.size()):
			var b: Rect2 = (touches[j] as Dictionary)["r"]
			# Les capuchons font 0,92 u dans une maille de 1 u : ils ne doivent
			# jamais se croiser, même d'un cheveu.
			if a.intersects(b) and chevauchements.size() < 6:
				chevauchements.append("%d/%d" % [code_a,
					(touches[j] as Dictionary)["code"]])
	_check(chevauchements.is_empty(),
		"des capuchons se recouvrent : %s" % ", ".join(chevauchements))

	# Tout tient dans le cadre annoncé, sinon le dessin déborde du panneau.
	for t: Dictionary in touches:
		var r: Rect2 = t["r"]
		_check(r.position.x >= -0.001 and r.end.x <= float(d["largeur"]) + 0.001,
			"le capuchon %d sort de la largeur annoncée" % t["code"])
		_check(r.position.y >= -0.001 and r.end.y <= float(d["hauteur"]) + 0.001,
			"le capuchon %d sort de la hauteur annoncée" % t["code"])


## ⚠️ **Toutes les touches que le jeu emploie doivent être DESSINÉES.**
## Une action liée à une touche absente de la disposition ne s'allumerait nulle
## part : le joueur la chercherait sur le dessin et ne la trouverait pas, sans
## qu'aucune erreur ne le dise. C'est le contrôle qui relie les deux fichiers.
func _test_le_clavier_porte_toutes_les_touches_du_jeu(carte: GDScript,
		toutes: Dictionary) -> void:
	var d: Dictionary = carte.disposition_clavier()
	var dessinees := {}
	for t: Dictionary in d["touches"]:
		dessinees[t["code"]] = true

	var absentes: Array[String] = []
	for j: int in toutes.keys():
		for action: String in toutes[j]:
			var code: int = carte.code_physique_de(action)
			if code != 0 and not dessinees.has(code):
				absentes.append("%s (%d)" % [action, code])
	_check(absentes.is_empty(),
		"ces actions sont liées à une touche que le clavier ne dessine pas : %s"
			% ", ".join(absentes))


# ---------------------------------------------------------------------------
# 2. CE QUI EST ALLUMÉ VIENT DE L'INPUT MAP
# ---------------------------------------------------------------------------

func _test_l_occupation_suit_l_input_map(carte: GDScript,
		toutes: Dictionary) -> void:
	var occupe: Dictionary = carte.occupation(toutes)
	_check(occupe.size() >= 12,
		"seulement %d touches occupées : la lecture de l'InputMap a raté"
			% occupe.size())

	# Chaque touche allumée doit correspondre à une action réellement liée —
	# l'oracle est l'InputMap, jamais la fonction qu'on teste.
	for code: int in occupe.keys():
		var joueur: int = occupe[code]
		var trouvee := false
		for action: String in toutes[joueur]:
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey:
					var t: InputEventKey = ev
					var c: int = t.physical_keycode if t.physical_keycode != 0 \
						else t.keycode
					if c == code:
						trouvee = true
		_check(trouvee,
			"la touche %d est allumée pour J%d sans liaison correspondante"
				% [code, joueur + 1])

	# ⚠️ **Et le versant qui compte : une réassignation DÉPLACE la lumière.**
	# Sans lui, une occupation figée à l'ouverture passerait au vert.
	var avant: Dictionary = carte.occupation(toutes)
	var ancienne := InputMap.action_get_events("p2_shoot")
	var neuve := InputEventKey.new()
	neuve.physical_keycode = KEY_G
	InputMap.action_erase_events("p2_shoot")
	InputMap.action_add_event("p2_shoot", neuve)
	var apres: Dictionary = carte.occupation(toutes)
	_check(apres.has(KEY_G),
		"après réassignation sur G, le dessin n'allume pas G")
	_check(avant.has(KEY_O) and not apres.has(KEY_O),
		"après réassignation, l'ancienne touche reste allumée")

	# Remis en place : un banc ne laisse pas le monde différent de comme il l'a
	# trouvé, sinon les suivants mesurent son passage.
	InputMap.action_erase_events("p2_shoot")
	for ev in ancienne:
		InputMap.action_add_event("p2_shoot", ev)
	_check(carte.occupation(toutes).has(KEY_O),
		"la remise en état n'a pas restauré la liaison d'origine")


# ---------------------------------------------------------------------------
# 3. LES COLLISIONS SONT NOMMÉES
# ---------------------------------------------------------------------------

func _test_une_touche_partagee_est_nommee(carte: GDScript,
		toutes: Dictionary) -> void:
	_check((carte.collisions(toutes) as Array).is_empty(),
		"les touches par défaut se marchent dessus : %s"
			% str(carte.collisions(toutes)))

	# On force le cas : J1 tire avec la touche de torche de J2.
	var ancienne := InputMap.action_get_events("p1_shoot")
	var neuve := InputEventKey.new()
	neuve.physical_keycode = KEY_P
	InputMap.action_erase_events("p1_shoot")
	InputMap.action_add_event("p1_shoot", neuve)

	var heurts: Array = carte.collisions(toutes)
	_check(heurts.has(KEY_P),
		"deux joueurs sur la touche P et la collision n'est pas nommée")

	InputMap.action_erase_events("p1_shoot")
	for ev in ancienne:
		InputMap.action_add_event("p1_shoot", ev)
	_check((carte.collisions(toutes) as Array).is_empty(),
		"la remise en état laisse une collision")


# ---------------------------------------------------------------------------
# 4. LE LIBELLÉ EST TRADUIT, ET LE HEADLESS NE HURLE PAS
# ---------------------------------------------------------------------------

func _test_les_libelles(carte: GDScript) -> void:
	_check(String(carte.libelle_de(KEY_UP)) == "▲",
		"la flèche du haut n'a pas son signe")
	_check(String(carte.libelle_de(KEY_SPACE)) == "ESPACE",
		"la barre d'espace n'est pas nommée en toutes lettres")

	# Chaque touche dessinée doit rendre un libellé non vide : un capuchon muet
	# est un capuchon que le joueur ne peut pas nommer à voix haute.
	var d: Dictionary = carte.disposition_clavier()
	var muets: Array[String] = []
	for t: Dictionary in d["touches"]:
		if String(carte.libelle_de(t["code"])).strip_edges() == "":
			muets.append(str(t["code"]))
	_check(muets.is_empty(), "capuchons sans libellé : %s" % ", ".join(muets))

	# ⚠️ **Le contrôle qui a une histoire.** `keyboard_get_keycode_from_physical`
	# n'existe pas sous le serveur d'affichage headless : appelée quand même,
	# elle journalise une erreur par touche. Un banc qui imprime des erreurs
	# apprend à les ignorer, ce qui coûte le jour où l'une d'elles compte.
	var source := FileAccess.get_file_as_string("res://carte_appareil.gd")
	_check(source.contains("DisplayServer.get_name() == \"headless\""),
		"la traduction de disposition n'est pas gardée contre le headless")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== La carte des appareils ===")
	await process_frame
	var carte: GDScript = load("res://carte_appareil.gd")
	if carte == null:
		printerr("✗ carte_appareil.gd introuvable")
		quit(1)
		return

	# Les actions réelles du jeu, relues depuis `ui.gd` plutôt que recopiées :
	# une liste en double diverge, et c'est le motif du dépôt.
	var source := FileAccess.get_file_as_string("res://ui.gd")
	_check(source.contains("const TOUTES_ACTIONS"),
		"ui.gd ne déclare plus TOUTES_ACTIONS")
	var toutes := {
		0: ["p1_move_up", "p1_move_left", "p1_move_down", "p1_move_right",
			"p1_shoot", "p1_torch"],
		1: ["p2_move_up", "p2_move_left", "p2_move_down", "p2_move_right",
			"p2_aim_up", "p2_aim_left", "p2_aim_down", "p2_aim_right",
			"p2_shoot", "p2_torch"],
	}

	_test_aucun_capuchon_n_en_recouvre_un_autre(carte)
	_test_le_clavier_porte_toutes_les_touches_du_jeu(carte, toutes)
	_test_l_occupation_suit_l_input_map(carte, toutes)
	_test_une_touche_partagee_est_nommee(carte, toutes)
	_test_les_libelles(carte)

	print("--- %d contrôles, %d échec(s) ---" % [_ok + _ko, _ko])
	quit(1 if _ko > 0 else 0)
