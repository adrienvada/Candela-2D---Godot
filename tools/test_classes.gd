## Test headless des profils de classe — chantier CLASSES, étape 1.
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • **le root rend 1,0 hors de sa fenêtre**, jamais autre chose. Un facteur
##     supérieur à 1 accélérerait le joueur, ce qu'aucune décision n'a voulu, et
##     `player.gd` avertit juste au-dessus de son point d'accroche que rien ne
##     doit accélérer un joueur sans que l'adversaire puisse le voir venir ;
##   • **la rampe de reprise vit DANS la durée annoncée**, pas après : un root de
##     0,10 s dure 0,10 s. Sans ce contrôle, toutes les durées de la grille
##     mentiraient d'un quart de seconde ;
##   • **la recharge de fusées ne capitalise rien contre un plafond** — du temps
##     accumulé à réserve pleine offrirait une fusée instantanée après le premier
##     tir, c'est-à-dire une réserve cachée, invisible à l'écran ;
##   • **zéro fusée est une valeur légitime**, pas un cas dégradé : le Spectre
##     n'éclaire jamais, et c'est sa classe ;
##   • **l'index de classe n'est plus une POSITION** — c'est le contrôle le plus
##     cher de la section « écran », parce que le défaut qu'il attrape est
##     silencieux : la liste s'ordonne par rang, `get_pressed_button().get_index()`
##     rendait la place dans le conteneur, et le joueur serait parti avec une
##     autre classe que celle affichée, sans une erreur ;
##   • **les trois profils n'ont AUCUNE dépendance** — c'est ce qui permet à
##     cette suite de tourner en `--script`, et le jour où l'un d'eux nommera un
##     autoload, elle cessera de compiler. C'est voulu : voir `fusee_modele.gd`.
##
## Lancer : godot --headless --path . --script res://tools/test_classes.gd
extends SceneTree

## ⚠️ **`preload` par CHEMIN, jamais l'identifiant global.** En mode `--script`,
## le cache des classes globales n'existe pas encore : `RootProfile` et ses
## voisins ne sont pas déclarés, et le fichier ne compile même pas. Le piège est
## déjà consigné dans `tools/test_arsenal.gd`, qui le contourne autrement — et
## c'est aussi la raison pour laquelle ces quatre fichiers ne doivent nommer
## aucun autoload : ils seraient inchargeables ici.
const RootProfile := preload("res://root_profile.gd")
const FlareProfile := preload("res://flare_profile.gd")
const GadgetProfile := preload("res://gadget_profile.gd")
const ClassData := preload("res://class_data.gd")
const WeaponData := preload("res://weapon_data.gd")
const MapGeometry := preload("res://map_geometry.gd")
const GadgetBase := preload("res://gadget_base.gd")
const GadgetVoile := preload("res://gadget_voile.gd")
const GadgetOmbre := preload("res://gadget_ombre.gd")

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== PROFILS DE CLASSE ===")
	_test_root()
	_test_fusees()
	_test_gadget()
	_test_class_data()
	_test_catalogue_declare()
	_test_cablage_root()
	_test_bit_gadget()
	# ⚠️ **`await`, et il n'est pas décoratif.** Cette section monte des nœuds,
	# donc elle attend des images. Sans l'attendre ici, `_run()` imprimait son
	# verdict et sortait AVANT que les contrôles ne tournent : le lot annonçait
	# « tous les tests passent » pendant que la moitié de la section n'avait pas
	# encore été exécutée, et l'autre moitié ne l'a jamais été. Un garde-fou qui
	# ne peut pas échouer est pire qu'un garde-fou absent — on le croit tenu.
	await _test_socle_gadgets()
	_test_lecture_de_l_arme()
	_test_cablage_pose()
	await _test_ecran_de_classes()
	await _test_pose_de_gadget()
	await _test_torche_fantome()
	await _test_mine()
	await _test_braises()
	await _test_volumes()
	await _test_leurre()
	_test_gresillement()
	_test_ancrage_des_effets()
	await _test_poudre()
	await _test_fusees_par_classe()
	_test_archive()
	await _test_gresillement_en_jeu()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_root() -> void:
	print("\n[Le root : une coupure de vitesse, avec une reprise lissée]")
	var R := RootProfile

	# Hors fenêtre : le facteur vaut EXACTEMENT 1, pour que l'appelant puisse
	# multiplier sans condition.
	_check("hors root, le facteur vaut 1", is_equal_approx(R.facteur(0.0), 1.0))
	_check("un restant négatif rend 1 et n'accélère pas",
		is_equal_approx(R.facteur(-0.5), 1.0), str(R.facteur(-0.5)))

	# Pendant l'arrêt franc : zéro.
	_check("en plein root, le facteur vaut 0", is_equal_approx(R.facteur(0.50), 0.0))
	_check("au seuil de la rampe, encore 0",
		is_equal_approx(R.facteur(R.RECUPERATION), 0.0))

	# La rampe : monotone, bornée, et elle atteint bien ses deux extrémités.
	var mi := R.facteur(R.RECUPERATION * 0.5)
	_check("à mi-rampe, le facteur est strictement entre 0 et 1",
		mi > 0.0 and mi < 1.0, str(mi))
	_check("la rampe est monotone décroissante en « restant »",
		R.facteur(0.01) > R.facteur(0.05) and R.facteur(0.05) > R.facteur(0.07))

	# La rampe vit DANS la durée. C'est le contrôle qui empêche les dix durées
	# de la grille de mentir.
	var court := RootProfile.new()
	court.duree = 0.08
	_check("un root de 0,08 s est entièrement rampe (aucun arrêt franc)",
		is_equal_approx(court.duree_arret_franc(), 0.0), str(court.duree_arret_franc()))
	_check("un root de 0,08 s est déclaré imperceptible", court.est_imperceptible())

	var long := RootProfile.new()
	long.duree = 0.60
	_check("un root de 0,60 s garde 0,52 s d'arrêt franc",
		is_equal_approx(long.duree_arret_franc(), 0.52), str(long.duree_arret_franc()))
	_check("un root de 0,60 s n'est pas imperceptible", not long.est_imperceptible())

	# Le cas de l'Occulteur, seul à s'immobiliser après la rafale.
	var rafale := RootProfile.new()
	rafale.apres_rafale = true
	_check("le drapeau « après rafale » existe et se lit", rafale.apres_rafale)

	# ⚠️ **Le plafond de l'échelle, arbitré par Adrien le 2026-09-09** : 0,60 s
	# pour l'arbalète, et personne au-dessus. C'est une borne de conception — un
	# root plus long rendrait une arme injouable pour une raison que le joueur ne
	# peut pas lire à l'écran.
	#
	# Le contrôle lit le TEXTE de `game_state.gd` plutôt que le catalogue, qui
	# demande la scène et les autoloads. Il attrape donc un `_root(0.75)` écrit à
	# la main, ce qui est le geste qu'on veut empêcher.
	var f2 := FileAccess.open("res://game_state.gd", FileAccess.READ)
	if f2 != null:
		var t2 := f2.get_as_text()
		f2.close()
		var trop_longs: Array[String] = []
		var i := 0
		while true:
			i = t2.find("_root(", i)
			if i < 0:
				break
			var j := t2.find(")", i)
			var args := t2.substr(i + 6, j - i - 6)
			var duree := float(args.split(",")[0])
			if duree > RootProfile.PLAFOND + 0.0001:
				trop_longs.append(args)
			i = j
		_check("aucun root ne dépasse le plafond de 0,60 s",
			trop_longs.is_empty(), str(trop_longs))
		_check("le plafond est bien celui qu'Adrien a arrêté",
			is_equal_approx(RootProfile.PLAFOND, 0.60), str(RootProfile.PLAFOND))


func _test_fusees() -> void:
	print("\n[Les fusées : une réserve, et une recharge qui ne triche pas]")

	# Le cas de loin le plus fréquent : pas de recharge du tout.
	var sans := FlareProfile.new()
	sans.stock = 1
	_check("sans période, la recharge est inactive", not sans.recharge_active())
	var r0: Array = sans.avancer(0, 0.0, 100.0)
	_check("sans recharge, cent secondes ne rendent aucune fusée",
		int(r0[0]) == 0, str(r0))
	_check("sans recharge, l'attente restante vaut -1",
		is_equal_approx(sans.attente_restante(0, 0.0), -1.0))

	# Le Spectre : zéro fusée est une valeur légitime.
	var aucune := FlareProfile.new()
	aucune.stock = 0
	_check("zéro fusée : le plafond effectif vaut zéro", aucune.plafond_effectif() == 0)
	var zero_avec_periode := FlareProfile.new()
	zero_avec_periode.stock = 0
	zero_avec_periode.periode_recharge = 5.0
	_check("zéro fusée : la recharge reste inactive même avec une période",
		not zero_avec_periode.recharge_active())

	# Le Terrassier : trois fusées, recharge rapide.
	var vite := FlareProfile.new()
	vite.stock = 3
	vite.periode_recharge = 10.0
	_check("avec une période, la recharge est active", vite.recharge_active())

	var r1: Array = vite.avancer(0, 0.0, 4.0)
	_check("4 s sur 10 ne rendent rien mais capitalisent",
		int(r1[0]) == 0 and is_equal_approx(float(r1[1]), 4.0), str(r1))

	var r2: Array = vite.avancer(0, 4.0, 7.0)
	_check("4 s puis 7 s rendent une fusée et gardent le reste",
		int(r2[0]) == 1 and is_equal_approx(float(r2[1]), 1.0), str(r2))

	# Le reste est CONSERVÉ : sans ça, consommer au mauvais moment perdrait une
	# fraction de progression que rien à l'écran n'expliquerait.
	var r3: Array = vite.avancer(1, 9.9, 0.2)
	_check("le reliquat n'est pas perdu d'une image à l'autre",
		int(r3[0]) == 2, str(r3))

	# Plusieurs fusées d'un coup, si le delta est gros.
	var r4: Array = vite.avancer(0, 0.0, 25.0)
	_check("25 s rendent deux fusées, pas une", int(r4[0]) == 2, str(r4))

	# ⚠️ Le contrôle qui compte : rien ne se capitalise contre un plafond.
	var r5: Array = vite.avancer(3, 0.0, 60.0)
	_check("à réserve pleine, le stock ne dépasse pas le plafond",
		int(r5[0]) == 3, str(r5))
	_check("à réserve pleine, l'accumulateur est remis à zéro",
		is_equal_approx(float(r5[1]), 0.0), str(r5))

	var r6: Array = vite.avancer(2, 0.0, 60.0)
	_check("l'écrêtage au plafond ne garde aucun reliquat",
		int(r6[0]) == 3 and is_equal_approx(float(r6[1]), 0.0), str(r6))

	# L'attente affichée au HUD.
	_check("l'attente restante décroît avec l'accumulateur",
		is_equal_approx(vite.attente_restante(0, 4.0), 6.0),
		str(vite.attente_restante(0, 4.0)))
	_check("à réserve pleine, plus d'attente à afficher",
		is_equal_approx(vite.attente_restante(3, 5.0), -1.0))

	# Un delta négatif ne doit pas remonter le temps.
	var r7: Array = vite.avancer(0, 5.0, -3.0)
	_check("un delta négatif est ignoré, il ne recule pas la recharge",
		is_equal_approx(float(r7[1]), 5.0), str(r7))


func _test_gadget() -> void:
	print("\n[Le gadget : des chemins dérivés d'une seule clé]")
	var g := GadgetProfile.new()
	g.slug = "voile"
	g.libelle = "Le voile"

	_check("sans implémentation, le gadget n'est pas livré", not g.est_livre())
	g.implementation = "res://gadget_voile.gd"
	_check("avec une implémentation, le gadget est livré", g.est_livre())

	_check("le sprite se dérive du slug",
		g.chemin_sprite() == "res://assets/sprites/gadget_voile.png", g.chemin_sprite())
	_check("l'icône se dérive du MÊME slug",
		g.chemin_icone() == "res://assets/ui/icones/gadget_voile.png", g.chemin_icone())

	# Le drapeau d'éblouissement : faux par défaut, parce que la plupart des
	# gadgets n'émettent aucune lumière.
	_check("par défaut, un gadget n'éblouit pas", not GadgetProfile.new().eblouit)


func _test_class_data() -> void:
	print("\n[La classe : un seul slug pour tous ses fichiers]")
	var c := ClassData.new()
	c.libelle = "Le Spectre"
	c.torch_cookie = "spectre"

	_check("le slug hérité de WeaponData est celui du cookie", c.slug() == "spectre")
	_check("le cookie se dérive du slug",
		c.chemin_cookie() == "res://assets/torche/cookie_spectre.png", c.chemin_cookie())
	_check("le sprite se dérive du MÊME slug",
		c.chemin_sprite() == "res://assets/sprites/spectre.png", c.chemin_sprite())

	_check("sans profil, la classe se déclare incomplète", not c.est_complete())
	c.root = RootProfile.new()
	c.fusees = FlareProfile.new()
	c.gadget = GadgetProfile.new()
	_check("avec ses trois profils, la classe est complète", c.est_complete())

	# Une classe EST une arme : c'est ce qui permet à `equip_weapon()` et à
	# `weapon_for_index()` de ne pas changer d'une ligne.
	_check("une ClassData est une WeaponData", c is WeaponData)

	# Les quatre classes historiques ont leurs assets ; c'est la seule chose que
	# ce contrôle peut affirmer sans monter une scène.
	var pistolet := ClassData.new()  # cookie « pistolet » par défaut
	_check("les assets du pistolet sont présents", pistolet.assets_presents(),
		pistolet.chemin_cookie() + " / " + pistolet.chemin_sprite())


func _test_catalogue_declare() -> void:
	print("\n[Le catalogue : dix classes déclarées, dix slugs distincts]")

	# ⚠️ **Contrôle TEXTUEL, et il faut savoir ce qu'il ne prouve pas.** Le
	# catalogue vit dans `game_state.gd`, qui a besoin de la scène et des
	# autoloads : impossible à monter en `--script`. Ce contrôle lit donc le
	# fichier et vérifie que les dix slugs y sont DÉCLARÉS. Il ne dit rien de ce
	# que la fonction construit à l'exécution — c'est exactement le piège
	# « un contrôle textuel épingle un IDENTIFIANT, jamais un SENS » du
	# 2026-08-25, et il est assumé ici faute de mieux.
	var f := FileAccess.open("res://game_state.gd", FileAccess.READ)
	if f == null:
		_check("game_state.gd lisible", false)
		return
	var texte := f.get_as_text()
	f.close()

	var slugs := ["pistolet", "fusil", "pompe", "arbalete",
		"fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
	var manquants: Array[String] = []
	for s in slugs:
		if not texte.contains('"%s"' % s):
			manquants.append(s)
	_check("les dix slugs sont déclarés dans game_state.gd",
		manquants.is_empty(), str(manquants))

	_check("le catalogue est monté en fin de _ready()",
		texte.contains("_batir_catalogue()"))
	_check("le catalogue crie sur une classe incomplète plutôt que de la réparer",
		texte.contains("sans profil complet"))

	# ⚠️ **La résolution index → arme doit passer par le CATALOGUE.** Elle était un
	# `match` sur 0 à 3 dont la branche par défaut rendait le pistolet : avec dix
	# classes, six d'entre elles auraient tiré avec la balistique du pistolet,
	# porté son cookie et joué ses sons, sans qu'une seule erreur ne se lève.
	_check("weapon_for_index lit le catalogue, plus un match sur quatre index",
		texte.contains("return _classes[idx]"))
	_check("un index hors bornes crie au lieu de se taire",
		texte.contains("index de classe hors bornes"))

	# Les slugs doivent être distincts : deux classes qui partagent un slug
	# partagent leur cookie, leur sprite et leurs sons, sans qu'aucune erreur ne
	# se lève — le fichier existe, il est juste au mauvais joueur.
	var vus := {}
	var doublons: Array[String] = []
	for s in slugs:
		if vus.has(s):
			doublons.append(s)
		vus[s] = true
	_check("aucun slug en double", doublons.is_empty(), str(doublons))


func _test_cablage_root() -> void:
	print("\n[Le câblage du root dans player.gd]")

	# ⚠️ **Contrôle TEXTUEL, et il existe parce que le root ne RIEN qui se voie
	# en headless.** Aucune suite ne simule une manche : les sept modifications
	# de `player.gd` pourraient être défaites une à une sans qu'une seule ligne
	# ne rougisse. C'est le même raisonnement que `tools/test_planche_marche.gd`,
	# qui lit le TEXTE de `player.gd` pour la même raison — « le lot ne rend
	# rien, donc rien n'aurait vu un décâblage ».
	#
	# Ce qu'il ne prouve pas : que le root se COMPORTE bien. Ça se juge manette
	# en main, et c'est un jalon d'Adrien, pas un contrôle.
	var f := FileAccess.open("res://player.gd", FileAccess.READ)
	if f == null:
		_check("player.gd lisible", false)
		return
	var t := f.get_as_text()
	f.close()

	_check("le compteur de root existe", t.contains("var _root_restant: float"))
	_check("il se décrémente comme le rechargement",
		t.contains("_root_restant = maxf(0.0, _root_restant - delta)"))
	_check("il multiplie la vitesse par le facteur du profil",
		t.contains("current_speed *= RootProfile.facteur(_root_restant)"))
	_check("il s'arme dans shoot(), à côté du cooldown",
		t.contains("_root_restant = _cl.root.duree"))
	_check("la rafale s'immobilise au relâchement de la détente",
		t.contains("_root_restant = maxf(_root_restant, _cl_rafale.root.duree)"))
	_check("changer d'arme remet le root à zéro",
		t.contains("_root_restant = 0.0"))

	# ⚠️ **Le contrôle qui compte le plus : RIEN ne part sur le fil.** Le root est
	# simulé identiquement chez les deux pairs parce que `shoot()` tourne des deux
	# côtés — exactement le patron de `lancer_fusee()`. Le jour où quelqu'un
	# « corrigerait » ça en répliquant le compteur, il paierait un octet par tick
	# pour une valeur déjà juste, et créerait une divergence là où il n'y en a
	# aucune. Ce contrôle est là pour que cette correction-là soit impossible à
	# faire par inadvertance.
	_check("le root ne voyage PAS dans la config de réplication",
		not t.contains('add_property(NodePath(".:_root_restant")'))
	_check("le root n'est pas un argument de rpc_send_inputs",
		not t.contains("root: float") and not t.contains("_root_restant: float," ))

	# La parade d'interpénétration. Le défaut préexistait ; le root le rend
	# visible, parce qu'un joueur immobile ne se dégage plus seul au tick suivant.
	_check("la correction de prédiction passe par la collision",
		t.contains("move_and_collide(step)"))
	_check("le téléport de correction a bien disparu",
		not t.contains("global_position += step"))


func _test_bit_gadget() -> void:
	print("\n[Le bit de gadget : de la touche jusqu'au fil]")

	# Les actions doivent EXISTER dans l'Input Map. Un `Input.is_action_pressed`
	# sur une action absente ne lève rien et rend toujours faux : la touche ne
	# marcherait jamais, et le seul diagnostic possible depuis l'écran serait
	# « le gadget ne se pose pas ».
	_check("l'action p1_gadget existe", InputMap.has_action("p1_gadget"))
	_check("l'action p2_gadget existe", InputMap.has_action("p2_gadget"))
	_check("p1_gadget porte au moins une liaison",
		not InputMap.action_get_events("p1_gadget").is_empty())
	_check("p2_gadget porte au moins une liaison",
		not InputMap.action_get_events("p2_gadget").is_empty())

	# Le contrat du fournisseur, des trois côtés.
	var lu := func(chemin: String) -> String:
		var f := FileAccess.open(chemin, FileAccess.READ)
		if f == null:
			return ""
		var t := f.get_as_text()
		f.close()
		return t

	var base: String = lu.call("res://input_provider.gd")
	var local: String = lu.call("res://local_input_provider.gd")
	var reseau: String = lu.call("res://network_input_provider.gd")
	var joueur: String = lu.call("res://player.gd")

	_check("le contrat de base déclare is_gadget_pressed",
		base.contains("func is_gadget_pressed()"))
	_check("le fournisseur local lit l'action", local.contains("action_gadget"))
	_check("le fournisseur réseau porte le bit", reseau.contains("gadget_pressed"))

	# ⚠️ Le contrôle qui compte : le bit doit être remis au NEUTRE quand le
	# client disparaît. Un `gadget_pressed` resté à vrai ferait poser des gadgets
	# par un joueur qui n'est plus là — le paquet ne vient plus, mais le dernier
	# reçu survit. C'est le même défaut que `reset_input_state` répare déjà pour
	# le tir et la torche.
	var i := reseau.find("func reset_input_state()")
	_check("le bit est remis au neutre à la déconnexion",
		i >= 0 and reseau.substr(i).contains("gadget_pressed = false"))

	# Le fil.
	_check("rpc_send_inputs porte le huitième argument",
		joueur.contains("reload: bool = false, gadget: bool = false"))
	_check("le client l'envoie depuis son fournisseur",
		joueur.contains("input_provider.is_gadget_pressed()"))
	_check("l'hôte le transmet au fournisseur réseau",
		joueur.contains("update_input_state(mov, aim, shoot, torch, flare, reload, gadget)"))

	# Et le numéro de version, qui est une décision humaine mécanisée par le
	# témoin : le fil a changé, donc il doit avoir bougé.
	_check("Protocol.VERSION a été monté avec le fil", Protocol.VERSION >= 10)


func _test_socle_gadgets() -> void:
	print("\n[Le socle des gadgets : touchable par une balle, traversable par un joueur]")

	# ⚠️ **La propriété qui porte tout le socle.** Un gadget vit sur sa propre
	# couche, et le masque des JOUEURS ne la contient pas : c'est cette absence,
	# et rien d'autre, qui les laisse traverser. Si quelqu'un « simplifiait » en
	# posant les gadgets sur la couche des murs, le voile du Spectre deviendrait
	# un mur ordinaire — l'inverse exact de ce qu'il raconte — et rien ne le
	# signalerait, parce que le jeu resterait parfaitement jouable.
	_check("la couche des gadgets est distincte de celle des murs",
		MapGeometry.GADGET_LAYER != MapGeometry.WALL_LAYER)
	_check("le masque des joueurs ne contient PAS les gadgets",
		(MapGeometry.PLAYER_MASK & MapGeometry.GADGET_LAYER) == 0,
		str(MapGeometry.PLAYER_MASK))
	_check("le masque des balles contient les murs ET les gadgets",
		(MapGeometry.BULLET_MASK & MapGeometry.WALL_LAYER) != 0
			and (MapGeometry.BULLET_MASK & MapGeometry.GADGET_LAYER) != 0,
		str(MapGeometry.BULLET_MASK))

	# Le socle, monté pour de vrai.
	var g: Node2D = GadgetBase.new()
	g.name = "Gadget_Test"
	root.add_child(g)
	await process_frame
	_check("le gadget est sur la couche des gadgets",
		g.collision_layer == MapGeometry.GADGET_LAYER, str(g.collision_layer))
	_check("son masque est nul : il ne heurte personne", g.collision_mask == 0)
	_check("il rejoint le groupe « gadgets »", g.is_in_group("gadgets"))
	_check("il porte une forme de collision", g.get_node_or_null("Forme") != null)
	_check("il porte un occluder : un gadget n'est pas un trou de lumière",
		g.get_node_or_null("Occluder") != null)

	# Les points de vie : tout gadget est destructible à la balle.
	g.pv = 2.0
	_check("un coup insuffisant ne le détruit pas", not g.encaisser(1.0))
	_check("le coup suivant le détruit", g.encaisser(1.0))
	await process_frame

	# Les deux gadgets de la famille A : le MÊME nœud, deux polygones.
	var voile = GadgetVoile.new()
	var ombre = GadgetOmbre.new()
	voile._monter_occluder()
	ombre._monter_occluder()

	# ⚠️ Le contrôle qui distingue le voile d'un mur.
	_check("le voile n'arrête PAS les balles", not voile.arrete_les_balles)
	_check("l'ombre habitée, plaque d'acier, les arrête", ombre.arrete_les_balles)
	_check("ni l'un ni l'autre n'éblouit", not voile.eblouit and not ombre.eblouit)

	# Les ombres portées n'ont pas la même forme, et c'est tout leur intérêt.
	var occ_v: LightOccluder2D = voile.get_node_or_null("Occluder")
	var occ_o: LightOccluder2D = ombre.get_node_or_null("Occluder")
	_check("le voile projette une bande longue",
		occ_v != null and occ_v.occluder.polygon.size() == 4)
	_check("l'ombre habitée projette une silhouette de la largeur d'un corps",
		occ_o != null and absf(occ_o.occluder.polygon[1].x) == GadgetOmbre.DEMI_TORSE,
		str(occ_o.occluder.polygon[1]) if occ_o != null else "absent")
	_check("le voile est nettement plus long que l'ombre",
		GadgetVoile.DEMI_LONGUEUR > GadgetOmbre.DEMI_TORSE * 2.0)

	voile.free()
	ombre.free()

	# Le câblage dans bullet.gd, en TEXTE : aucune suite ne fait voler de balle.
	var f := FileAccess.open("res://bullet.gd", FileAccess.READ)
	if f == null:
		_check("bullet.gd lisible", false)
		return
	var t := f.get_as_text()
	f.close()
	_check("la balle voit explicitement les gadgets",
		t.contains("shape_cast.collision_mask = MapGeometry.BULLET_MASK"))
	_check("elle a une branche de dispatch pour eux", t.contains("collider is GadgetBase"))
	_check("elle les abîme avant de décider si elle s'arrête",
		t.contains("gadget.encaisser("))
	# ⚠️ Le renommage compte autant que le reste : `wall_first` décidait
	# « obstacle » en disant « mur », et depuis que le masque contient les
	# gadgets ce n'est plus la même chose.
	_check("le test d'antériorité ne s'appelle plus « mur » DANS LE CODE",
		not t.contains("var wall_first") and t.contains("var obstacle_avant"))
	_check("la traversée est bornée", t.contains("TRAVERSES_MAX"))


## L'écran de sélection de classe — chantier CLASSES, étape 7.
##
## ⚠️ **Cette section monte `main.tscn`.** Elle est donc la seule du fichier à
## dépendre des autoloads et du catalogue ; tout ce qui précède reste pur, et
## c'est ce qui permet à la suite de tourner en `--script`.
func _test_ecran_de_classes() -> void:
	print("\n[L'écran de sélection de classe]")
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		_check("main.tscn se charge", false)
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ui: Node = main.get_node_or_null("UI")
	var gs: Node = main
	if ui == null or not gs.has_method("classes"):
		_check("l'interface et le catalogue répondent", false)
		main.queue_free()
		return

	var catalogue: Array = gs.classes()

	# ── Le nombre de boutons ne se devine pas, il se compare ────────────────
	# `NB_CLASSES` est écrit en dur dans `ui.gd` parce que l'interface se monte
	# avant le catalogue. Sans ce contrôle, ajouter une onzième classe la
	# laisserait invisible dans l'écran qui sert à choisir — sans une erreur.
	_check("ui.NB_CLASSES vaut la taille du catalogue",
		int(ui.NB_CLASSES) == catalogue.size(),
		"%d vs %d" % [int(ui.NB_CLASSES), catalogue.size()])
	_check("le râtelier de J1 porte autant de boutons",
		ui.p1_weapon_buttons.size() == catalogue.size(),
		str(ui.p1_weapon_buttons.size()))
	_check("celui de J2 aussi",
		ui.p2_weapon_buttons.size() == catalogue.size(),
		str(ui.p2_weapon_buttons.size()))

	if ui.p1_weapon_buttons.is_empty():
		main.queue_free()
		return

	# ── L'ordre affiché est celui des RANGS ─────────────────────────────────
	var rangs: Array[int] = []
	var index_affiches: Array[int] = []
	for btn in ui.p1_weapon_buttons:
		var idx := int(btn.get_meta(ui.META_CLASSE_INDEX, -1))
		index_affiches.append(idx)
		rangs.append(int(catalogue[idx].rang) if idx >= 0 and idx < catalogue.size() else -1)
	var croissant := true
	for i in range(1, rangs.size()):
		if rangs[i] < rangs[i - 1]:
			croissant = false
	_check("les classes s'affichent par rang croissant", croissant, str(rangs))
	_check("les dix index sont tous présents une fois",
		index_affiches.size() == catalogue.size()
			and _tous_distincts(index_affiches)
			and index_affiches.min() == 0
			and index_affiches.max() == catalogue.size() - 1,
		str(index_affiches))

	# ⚠️ **LE contrôle de la section.** Si la place et l'index coïncidaient, la
	# lecture positionnelle d'avant marcherait encore et personne ne verrait le
	# jour où elle cesse de marcher. Il faut donc qu'ils DIFFÈRENT quelque part —
	# et c'est le cas dès que la table des rangs n'est pas l'ordre du catalogue.
	var au_moins_un_decale := false
	for place in index_affiches.size():
		if index_affiches[place] != place:
			au_moins_un_decale = true
	_check("la place d'un bouton n'est PAS son index de classe",
		au_moins_un_decale, str(index_affiches))

	# ── L'aller-retour de sélection ─────────────────────────────────────────
	var aller_retour := true
	var faute := ""
	for joueur in [0, 1]:
		for idx in catalogue.size():
			ui.set_weapon_selection(joueur, idx)
			var lu: int = ui.selected_weapon_index(joueur)
			if lu != idx:
				aller_retour = false
				faute = "J%d : posé %d, lu %d" % [joueur + 1, idx, lu]
	_check("ce qui est posé est ce qui est lu, pour les dix et les deux joueurs",
		aller_retour, faute)
	ui.set_weapon_selection(0, 0)
	ui.set_weapon_selection(1, 0)

	# ── La fiche dit quelque chose de chaque classe ─────────────────────────
	# ⚠️ **Une fiche par JOUEUR, et c'est le contrôle qui porte la demande
	# d'Adrien du 2026-09-09** : en écran partagé, les deux choisissent en même
	# temps, chacun son curseur. Une fiche unique était écrasée par le moindre
	# mouvement de l'autre, et J2 ne voyait jamais ce qu'il prenait.
	_check("il y a une fiche par joueur", ui._fiches_classe.size() == 2,
		str(ui._fiches_classe.size()))
	var fiche = ui._fiches_classe[0] if ui._fiches_classe.size() == 2 else null
	_check("la fiche est montée", fiche != null)
	if fiche != null:
		var muettes: Array[String] = []
		for idx in catalogue.size():
			fiche.montrer(catalogue[idx], catalogue)
			# Le nom, l'arme, la prose et le gadget : les quatre choses qu'Adrien a
			# demandées. Une seule vide, et la fiche affiche un trou là où le
			# joueur attend une réponse.
			if String(fiche._nom.text).is_empty() \
					or String(fiche._arme.text).is_empty() \
					or String(fiche._description.text).is_empty() \
					or String(fiche._gadget.text) == "—":
				muettes.append(String(catalogue[idx].slug()))
		_check("les dix fiches sont remplies", muettes.is_empty(), str(muettes))

		# Le zéro absolu se distingue de « la plus faible des dix » : le Spectre
		# n'a pas peu de fusées, il n'en a aucune, et sa ligne le dit.
		var spectre = null
		for c in catalogue:
			if String(c.slug()) == "spectre":
				spectre = c
		if spectre != null:
			fiche.montrer(spectre, catalogue)
			_check("le Spectre annonce zéro fusée",
				String(fiche._fusees.text) == "aucune", String(fiche._fusees.text))

	# ── Chaque râtelier écrit dans SA fiche, et pas dans celle de l'autre ───
	#
	# Le routage passe par le râtelier du bouton, jamais par le curseur qui
	# l'atteint : chez le client, le curseur 0 pilote le râtelier de J2, et router
	# sur le curseur aurait écrit dans la fiche de J1 ce que J2 choisit.
	if ui._fiches_classe.size() == 2 and not ui.p2_weapon_buttons.is_empty():
		var avant_j1 := String(ui._fiches_classe[0]._nom.text)
		# Un bouton de J2 dont la classe DIFFÈRE de ce que J1 affiche, sinon le
		# contrôle passerait au vert sans rien prouver.
		var cible: Button = null
		for btn in ui.p2_weapon_buttons:
			var c = ui._classe_du_catalogue(int(btn.get_meta(ui.META_CLASSE_INDEX, 0)))
			if c != null and String(c.libelle).to_upper() != avant_j1:
				cible = btn
				break
		if cible != null:
			ui._montrer_fiche_de(cible)
			_check("un survol chez J2 n'écrit pas dans la fiche de J1",
				String(ui._fiches_classe[0]._nom.text) == avant_j1,
				"%s → %s" % [avant_j1, String(ui._fiches_classe[0]._nom.text)])
			_check("il écrit dans celle de J2",
				String(ui._fiches_classe[1]._nom.text) != avant_j1,
				String(ui._fiches_classe[1]._nom.text))

	# ── Le panneau existe et l'entrée qui le nomme y mène ───────────────────
	var hub = ui.hub
	_check("le panneau de classes est enregistré",
		hub != null and hub.panneau(ui.PANEL_CLASSES) != null)

	main.queue_free()
	await process_frame


func _tous_distincts(valeurs: Array[int]) -> bool:
	var vus: Dictionary = {}
	for v in valeurs:
		if vus.has(v):
			return false
		vus[v] = true
	return true


## ⚠️ **Un contrôle TEXTUEL, et il vaut mieux qu'un contrôle de comportement.**
##
## Un `get_index()` réintroduit dans `game_state.gd` passerait tous les contrôles
## ci-dessus tant que l'ordre des rangs coïnciderait par hasard avec celui du
## catalogue sur la classe testée. Ce qu'on protège n'est pas un résultat, c'est
## un CHEMIN de lecture : il n'y en a qu'un, et il s'appelle
## `ui.selected_weapon_index()`.
func _test_lecture_de_l_arme() -> void:
	print("\n[L'arme choisie se lit par un seul chemin]")
	var src := FileAccess.get_file_as_string("res://game_state.gd")
	# ⚠️ **Les commentaires sont retirés avant de chercher.** La première version
	# de ce contrôle rougissait sur le commentaire qui EXPLIQUE le remplacement —
	# la troisième fois de ce chantier qu'un contrôle textuel interdit le mot dans
	# la phrase qui dit pourquoi il est interdit.
	var code := ""
	for ligne in src.split("\n"):
		if not ligne.strip_edges().begins_with("#"):
			code += ligne + "\n"
	_check("game_state.gd ne lit plus de position de bouton",
		not code.contains("get_pressed_button().get_index()"))
	_check("il passe par selected_weapon_index",
		src.contains("ui.selected_weapon_index("))
	var ui_src := FileAccess.get_file_as_string("res://ui.gd")
	_check("l'index de classe voyage en métadonnée",
		ui_src.contains("META_CLASSE_INDEX"))
	# La description est ce qui remplit la fiche : une classe sans prose afficherait
	# un bloc vide, et rien ne le signalerait.
	var gs_src := FileAccess.get_file_as_string("res://game_state.gd")
	var lignes := 0
	for ligne in gs_src.split("\n"):
		if ligne.strip_edges().begins_with("") and ligne.contains(".description = \""):
			lignes += 1
	_check("les dix classes portent une description", lignes == 10, str(lignes))


## Le câblage de la POSE, en texte — chantier CLASSES, étape 10.
##
## Aucune suite ne joue de manche complète : les sept lignes qui font exister la
## pose pourraient être défaites une à une sans qu'une seule rougisse. Même
## raison que pour le root, et même remède.
func _test_cablage_pose() -> void:
	print("\n[Le câblage de la pose de gadget]")
	var pl := FileAccess.get_file_as_string("res://player.gd")
	var gs := FileAccess.get_file_as_string("res://game_state.gd")

	_check("player.gd lit le bit de gadget", pl.contains("is_gadget_pressed()"))
	_check("il ne réagit qu'au FRONT montant", pl.contains("_gadget_pressee"))
	_check("il appelle poser_gadget()", pl.contains("poser_gadget()"))
	_check("la pose désarme, par le cooldown de tir",
		pl.contains("GadgetProfile.DESARMEMENT"))
	_check("l'arbitrage part chez game_state",
		pl.contains('call_group("game_state", "spawn_gadget"'))

	# ⚠️ Le contrôle qui protège l'autorité. Sans ce retour anticipé, le client
	# poserait son propre gadget EN PLUS de celui que l'hôte spawne pour lui —
	# deux objets là où le joueur en a posé un, et seulement chez lui.
	_check("le client ne spawne rien de lui-même",
		gs.contains("if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:\n\t\treturn\n\tvar pid: int = poseur.player_id"))
	_check("le RPC est autoritaire, local et fiable",
		gs.contains('@rpc("authority", "call_local", "reliable")\nfunc rpc_spawn_gadget'))
	# Un nom auto-généré diverge entre machines et les RPC de scène sont alors
	# jetés SANS erreur console — trois manches d'instrumentation en 2026-08-16.
	_check("le nœud posé porte un nom explicite et unique",
		gs.contains('g.name = "GadgetJ%d_%d"'))
	# La position finale voyage : elle ne se recalcule pas chez le client, sous
	# peine de deux mondes qui pourraient répondre différemment à la même requête.
	_check("la position rectifiée voyage dans le RPC",
		gs.contains("rpc_spawn_gadget.rpc(pid, point,"))
	_check("le plafond se relit au lieu de se semer",
		gs.contains("_gadgets_poses_par") and not gs.contains("_gadgets_restants"))


## La pose, éprouvée sur une vraie manche — chantier CLASSES, étape 10.
func _test_pose_de_gadget() -> void:
	print("\n[Poser un gadget]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	# Le Spectre est la classe dont le gadget est écrit : le voile.
	gs.round_active = true
	gs.sandbox_mode = false
	gs.p1.equip_weapon(gs.weapon_for_index(9))
	gs._gadgets_poses_par.fill(0)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0

	_check("avec une classe dont le gadget est écrit, la pose est possible",
		gs.gadget_disponible(0))

	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame

	var poses: Array = []
	for c in gs.bullet_container.get_children():
		if c is GadgetBase:
			poses.append(c)
	_check("un gadget est apparu", poses.size() == 1, str(poses.size()))

	if poses.size() == 1:
		var g = poses[0]
		_check("c'est le voile du Spectre", g is GadgetVoile)
		_check("son nom est explicite", String(g.name) == "GadgetJ1_1", String(g.name))
		_check("il connaît son poseur", g.poseur_id == 0)
		# ⚠️ DEVANT, jamais sous les pieds : un objet posé à l'endroit exact où
		# l'on se tient se confondrait avec le joueur — y compris dans l'ombre
		# qu'il découpe, qui est justement ce que ce gadget fabrique.
		var ecart: float = g.global_position.distance_to(gs.p1.global_position)
		_check("il est planté devant le poseur",
			is_equal_approx(ecart, GadgetBase.PORTEE_POSE), "%.1f px" % ecart)
		# En travers du regard : une bâche dans l'axe où l'on vise ne masque rien.
		_check("il est en travers du regard",
			is_equal_approx(g.rotation, PI / 2.0), str(g.rotation))
		_check("il porte un visuel — la pose se VOIT",
			g.get_node_or_null("Visuel") != null)

	# Le stock : une charge par manche, et le compteur la retient.
	_check("la charge est consommée", not gs.gadget_disponible(0))
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame
	var apres := 0
	for c in gs.bullet_container.get_children():
		if c is GadgetBase:
			apres += 1
	_check("un second appui ne pose rien", apres == 1, str(apres))

	# ⚠️ Une classe dont le gadget n'est PAS écrit ne pose rien et ne crie pas :
	# le bouton reste sans effet, ce qui est la vérité. Un gadget générique posé
	# à la place se prendrait pour une intention.
	#
	# ⚠️ **Le cas est FABRIQUÉ, plus emprunté à une classe réelle.** Il l'était,
	# et il est devenu faux le jour où cette classe-là a reçu son gadget : le
	# contrôle rougissait alors qu'il n'y avait rien à corriger. Un banc adossé à
	# l'état d'avancement du chantier se périme AVEC lui.
	var arme_sans_gadget = gs.weapon_for_index(0)
	var garde: String = arme_sans_gadget.gadget.implementation
	arme_sans_gadget.gadget.implementation = ""
	gs.p1.equip_weapon(arme_sans_gadget)
	gs._gadgets_poses_par.fill(0)
	_check("une classe sans gadget écrit ne peut rien poser",
		not gs.gadget_disponible(0))
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame
	var final := 0
	for c in gs.bullet_container.get_children():
		if c is GadgetBase:
			final += 1
	_check("et rien n'apparaît", final == 1, str(final))
	arme_sans_gadget.gadget.implementation = garde

	gs.queue_free()
	await process_frame


## La torche fantôme — chantier CLASSES, étape 11.
##
## ⚠️ **Le contrôle qui porte le gadget est celui de l'ÉBLOUISSEMENT**, pas celui
## du faisceau à l'écran. La feuille de route l'écrit depuis l'ouverture du
## chantier : *« si elle n'éblouit pas, il suffit à l'adversaire de la regarder
## en face pour savoir que c'est un faux »*. Une torche fantôme qui éclairerait
## sans aveugler serait un décor, et rien à l'écran ne le dirait — les deux
## faisceaux sont identiques.
func _test_torche_fantome() -> void:
	print("\n[La torche fantôme : elle aveugle comme une vraie]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	# Le Braconnier, index 3 : c'est SON cookie que le leurre emprunte.
	gs.round_active = true
	gs.sandbox_mode = false
	gs.p1.equip_weapon(gs.weapon_for_index(3))
	gs._gadgets_poses_par.fill(0)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.p1.visible = true
	gs.p2.visible = true

	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame

	var torche = null
	for c in gs.bullet_container.get_children():
		if c is GadgetTorcheFantome:
			torche = c
	_check("la torche fantôme est posée", torche != null)
	if torche == null:
		gs.queue_free()
		await process_frame
		return

	_check("elle porte la classe du poseur", torche.classe_du_poseur != null
		and String(torche.classe_du_poseur.slug()) == "arbalete",
		String(torche.classe_du_poseur.slug()) if torche.classe_du_poseur else "aucune")
	_check("elle éblouit", torche.eblouit)
	_check("et par son FAISCEAU, pas par la distance", torche.eblouissement_dirige)
	_check("elle a un faisceau monté", torche.get_node_or_null("Faisceau") != null)
	# ⚠️ Le cookie doit être CELUI de la classe : une torche fantôme au cookie
	# d'une autre arme serait démasquée d'un coup d'œil par qui connaît les dix.
	var faisceau: PointLight2D = torche.get_node_or_null("Faisceau")
	if faisceau != null:
		_check("son cookie est celui du Braconnier",
			faisceau.texture == torche.classe_du_poseur.get_torch_texture())
	# Elle ne dure pas la manche entière : la durée vient du PROFIL, réglable par
	# instance, jamais du type.
	_check("elle est périssable", torche.duree_vie > 0.0, str(torche.duree_vie))

	# ── Le balayage ──────────────────────────────────────────────────────────
	var avant: float = torche.rotation
	torche._age = GadgetTorcheFantome.PERIODE * 0.25
	torche._physics_process(0.0)
	_check("elle balaie", not is_equal_approx(torche.rotation, avant),
		"%.3f → %.3f" % [avant, torche.rotation])
	# Au quart de période, l'amplitude est à son maximum : c'est le seul point du
	# cycle dont la valeur soit connue sans recopier la formule.
	_check("son balayage tient l'amplitude annoncée",
		is_equal_approx(absf(torche.rotation), GadgetTorcheFantome.AMPLITUDE),
		str(torche.rotation))
	torche._age = 0.0
	torche._physics_process(0.0)

	# ── L'ÉBLOUISSEMENT, le contrôle qui compte ─────────────────────────────
	var espace: PhysicsDirectSpaceState2D = gs.p1.get_world_2d().direct_space_state
	var source := {}
	for src in gs._sources_eblouissantes():
		if src["noeud"] == torche:
			source = src
	_check("elle figure parmi les sources qui éblouissent", not source.is_empty())

	if not source.is_empty():
		# ⚠️ Elle n'a PAS de porteur, y compris celui qui l'a posée : marcher
		# devant son propre leurre coûte les yeux. Même règle que la fusée.
		_check("elle n'a pas de porteur", source["porteur"] == null)

		# ⚠️ **Le balayage est GELÉ pour ces trois mesures.** Sans ça, chaque pas
		# de physique — qu'il faut bien laisser passer pour que le serveur de
		# physique voie les corps déplacés — fait tourner le faisceau de deux
		# degrés, et les trois relevés ne parlent plus de la même géométrie.
		torche.set_physics_process(false)
		torche._age = 0.0
		torche.rotation = 0.0

		# Dans l'axe, à portée : ça doit aveugler.
		#
		# ⚠️ **Un seul corps sur le trajet à la fois.** Poser les deux joueurs au
		# même point faisait rendre zéro pour le second : le rayon de ligne de vue
		# touche le PREMIER corps rencontré, et `res.collider == cible` est alors
		# faux pour l'autre. Ce n'était pas un défaut du jeu, c'était un défaut de
		# la mesure — et il ressemblait trait pour trait à un vrai.
		gs.p2.global_position = torche.global_position + Vector2(150.0, 0.0)
		gs.p1.global_position = torche.global_position + Vector2(0.0, 900.0)
		gs.p2.visible = true
		# ⚠️ Un pas de PHYSIQUE, pas une image de rendu. `_ligne_de_vue` tire un
		# rayon ; tant que le serveur de physique n'a pas vu les corps à leur
		# nouvelle place, il ne touche rien et la ligne de vue est fausse. Le
		# premier jet attendait `process_frame` et rendait 0,000 partout.
		await physics_frame
		await physics_frame
		var devant: float = gs._plafond_de_source(espace, source, gs.p2)
		_check("un joueur dans son faisceau est ébloui", devant > 0.0,
			"%.3f" % devant)

		# Et le poseur, au même endroit, ne s'en tire pas mieux : les deux
		# joueurs échangent leurs places, et la valeur doit être la même.
		gs.p1.global_position = torche.global_position + Vector2(150.0, 0.0)
		gs.p2.global_position = torche.global_position + Vector2(0.0, 900.0)
		await physics_frame
		await physics_frame
		var poseur: float = gs._plafond_de_source(espace, source, gs.p1)
		_check("le poseur y est ébloui autant que l'autre",
			is_equal_approx(poseur, devant), "%.3f vs %.3f" % [poseur, devant])
		gs.p1.global_position = Vector2(400.0, 400.0)

		# Derrière elle : rien. Le faisceau a un axe, et c'est ce que « dirigée »
		# veut dire — sans quoi elle éblouirait à 360°, comme une fusée.
		gs.p2.global_position = torche.global_position - Vector2(150.0, 0.0)
		await physics_frame
		await physics_frame
		var derriere: float = gs._plafond_de_source(espace, source, gs.p2)
		_check("un joueur DERRIÈRE elle n'est pas ébloui", derriere <= 0.0,
			"%.3f" % derriere)

	gs.queue_free()
	await process_frame



## La mine au magnésium — chantier CLASSES, étape 12.
##
## ⚠️ **Ce qu'on protège ici n'est pas « la mine se déclenche » mais l'ARMEMENT
## et l'ABSENCE DE DÉGÂTS.** Sans armement, le poseur se déclenche sa propre mine
## à l'instant où il la pose — il se tient à 96 px du point, le rayon en fait 72,
## et il suffirait d'un pas. Et une mine qui blesserait ferait de l'Allumeur un
## piégeur ordinaire au lieu de celui qui fait de la lumière.
func _test_mine() -> void:
	print("\n[La mine au magnésium : elle n'explose pas, elle allume]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	# L'Allumeur, index 8.
	gs.round_active = true
	gs.sandbox_mode = false
	gs.p1.equip_weapon(gs.weapon_for_index(8))
	gs._gadgets_poses_par.fill(0)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.p1.visible = true
	gs.p2.visible = true
	# L'adversaire au loin : sinon il déclenche la mine avant qu'on l'observe.
	gs.p2.global_position = Vector2(400.0, 1600.0)

	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame

	var mine = null
	for c in gs.bullet_container.get_children():
		if c is GadgetMine:
			mine = c
	_check("la mine est posée", mine != null)
	if mine == null:
		gs.queue_free()
		await process_frame
		return

	_check("elle peut éblouir", mine.eblouit)
	_check("mais pas en dormant : son rayon d'éblouissement est nul",
		is_zero_approx(mine.rayon_eblouissement), str(mine.rayon_eblouissement))
	_check("sans axe : elle crache dans toutes les directions",
		not mine.eblouissement_dirige)
	_check("elle n'a pas de durée de vie propre",
		is_zero_approx(mine.duree_vie), str(mine.duree_vie))

	# ⚠️ **Deux moitiés d'une même vérité, et il faut les deux.** Un boîtier plat
	# ne masque pas la lumière ; il ne doit donc ni porter d'occluder — sa flamme
	# se retrouverait à l'intérieur, « ni ombre ni lumière mais du hasard » — ni
	# arrêter le rayon d'éblouissement, sous peine d'aveugler à travers ce qu'elle
	# n'assombrit pas. Vérifier l'un sans l'autre laisse passer la moitié.
	_check("elle ne porte pas d'occluder",
		mine.get_node_or_null("Occluder") == null)
	_check("et elle se déclare transparente à la lumière",
		not mine.occulte_la_lumiere)
	var voile_ref := GadgetVoile.new()
	_check("là où le voile, lui, se déclare opaque", voile_ref.occulte_la_lumiere)
	voile_ref.free()

	# ── L'ARMEMENT ───────────────────────────────────────────────────────────
	#
	# Le poseur est à `PORTEE_POSE` du point, donc DANS le rayon... non : 96 > 72.
	# Mais un seul pas l'y ramène, et c'est l'armement qui rend le geste jouable.
	_check("le poseur est hors du rayon de déclenchement au moment de poser",
		GadgetBase.PORTEE_POSE > GadgetMine.RAYON_DECLENCHEMENT,
		"%.0f vs %.0f" % [GadgetBase.PORTEE_POSE, GadgetMine.RAYON_DECLENCHEMENT])
	gs.p1.global_position = mine.global_position
	mine._age = 0.0
	_check("désarmée, un joueur dessus ne la déclenche pas",
		not mine.veut_s_allumer([gs.p1, gs.p2]))
	mine._age = GadgetMine.ARMEMENT + 0.01
	_check("armée, il la déclenche", mine.veut_s_allumer([gs.p1, gs.p2]))

	# ⚠️ Elle ne fait AUCUNE différence entre le poseur et l'autre. Même règle que
	# la fusée, arbitrée par Adrien : on ne la pose pas à ses pieds impunément.
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p2.global_position = mine.global_position
	_check("elle ne distingue pas son poseur de l'adversaire",
		mine.veut_s_allumer([gs.p1, gs.p2]))
	gs.p2.global_position = Vector2(400.0, 1600.0)

	# Un mort ne déclenche rien : son corps reste sur le terrain.
	gs.p2.global_position = mine.global_position
	gs.p2.dead = true
	_check("un mort ne la déclenche pas", not mine.veut_s_allumer([gs.p1, gs.p2]))
	gs.p2.dead = false
	gs.p2.global_position = Vector2(400.0, 1600.0)

	# ── L'EMBRASEMENT ────────────────────────────────────────────────────────
	var pv_avant: float = gs.p2.hp
	mine.allumer()
	await process_frame
	_check("allumée, elle aveugle", mine.rayon_eblouissement > 0.0,
		str(mine.rayon_eblouissement))
	_check("elle porte une flamme", mine.get_node_or_null("Embrasement") != null)
	_check("et elle se donne une échéance",
		mine.duree_vie > 0.0 and mine.duree_vie <= mine.age() + GadgetMine.DUREE_EMBRASEMENT + 0.01,
		str(mine.duree_vie))
	# ⚠️ **Aucun dégât, jamais.** C'est la classe : l'Allumeur fait de la lumière,
	# pas des trous. Une mine qui blesserait se jouerait comme n'importe quel
	# piège de n'importe quel jeu de tir.
	_check("elle ne blesse personne", is_equal_approx(gs.p2.hp, pv_avant))
	_check("un second ordre d'allumage ne la rallume pas",
		not mine.veut_s_allumer([gs.p1, gs.p2]))

	# ── ABATTUE, elle PART ───────────────────────────────────────────────────
	var autre := GadgetMine.new()
	autre.name = "MineTest"
	autre._age = GadgetMine.ARMEMENT + 0.01
	_check("une balle ne la désamorce pas : elle demande à s'allumer",
		autre.encaisser(999.0) and autre.veut_s_allumer([]))
	autre.free()

	gs.queue_free()
	await process_frame


## La nappe de braises — chantier CLASSES, étape 13.
##
## ⚠️ **Le contrôle qui compte est le DOSAGE**, pas l'existence des dégâts. Une
## nappe est calibrée pour *interdire*, pas pour tuer : la traverser en courant
## doit coûter une paille, y rester doit coûter cher. Un jour où quelqu'un
## doublera la valeur pour « rendre le gadget plus fort », c'est ce contrôle qui
## dira que la traversée est devenue mortelle.
func _test_braises() -> void:
	print("\n[La nappe de braises : un sol qu'on ne traverse plus]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	# L'Incendiaire, index 5.
	gs.round_active = true
	gs.sandbox_mode = false
	gs.p1.equip_weapon(gs.weapon_for_index(5))
	gs._gadgets_poses_par.fill(0)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.p1.visible = true
	gs.p2.visible = true
	gs.p2.global_position = Vector2(400.0, 1600.0)

	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame

	var nappe = null
	for c in gs.bullet_container.get_children():
		if c is GadgetBraises:
			nappe = c
	_check("la nappe est posée", nappe != null)
	if nappe == null:
		gs.queue_free()
		await process_frame
		return

	# Les trois propriétés qui font que ce n'est ni un mur ni une mine.
	_check("les balles la traversent", not nappe.arrete_les_balles)
	_check("la lumière aussi", not nappe.occulte_la_lumiere)
	_check("elle ne porte donc pas d'occluder",
		nappe.get_node_or_null("Occluder") == null)
	_check("elle éclaire", nappe.get_node_or_null("Lueur") != null)
	_check("et elle éblouit faiblement, de près",
		nappe.rayon_eblouissement > 0.0
			and nappe.rayon_eblouissement < GadgetMine.RAYON_EBLOUISSEMENT,
		str(nappe.rayon_eblouissement))
	_check("elle est périssable", nappe.duree_vie > 0.0, str(nappe.duree_vie))

	# ── LE DOSAGE ────────────────────────────────────────────────────────────
	#
	# Traverser au pas de course : la vitesse du joueur est celle du jeu, pas une
	# valeur inventée ici — sinon le contrôle mesurerait sa propre hypothèse.
	var vitesse: float = gs.p1.speed
	var traversee: float = (2.0 * GadgetBraises.RAYON) / vitesse
	var cout_traversee: float = GadgetBraises.DEGATS_PAR_SECONDE * traversee
	_check("traverser en courant coûte une paille", cout_traversee < 10.0,
		"%.1f PV" % cout_traversee)
	_check("y rester deux secondes coûte cher",
		GadgetBraises.DEGATS_PAR_SECONDE * 2.0 >= 25.0,
		"%.0f PV" % (GadgetBraises.DEGATS_PAR_SECONDE * 2.0))

	# ── ELLE BRÛLE, ET ELLE NE CONNAÎT PERSONNE ──────────────────────────────
	var pv_avant: float = gs.p2.hp
	gs.p2.global_position = nappe.global_position
	nappe.appliquer_effets([gs.p1, gs.p2], 1.0)
	await process_frame
	_check("un joueur dedans brûle",
		gs.p2.hp < pv_avant, "%.1f → %.1f" % [pv_avant, gs.p2.hp])

	# ⚠️ Le poseur ne fait pas exception : c'est la règle des choses posées, déjà
	# écrite pour la fusée et la mine.
	var pv_poseur: float = gs.p1.hp
	gs.p1.global_position = nappe.global_position
	nappe.appliquer_effets([gs.p1, gs.p2], 1.0)
	await process_frame
	_check("le poseur brûle comme les autres",
		gs.p1.hp < pv_poseur, "%.1f → %.1f" % [pv_poseur, gs.p1.hp])

	# Dehors, rien.
	gs.p1.global_position = nappe.global_position + Vector2(GadgetBraises.RAYON * 3.0, 0.0)
	var pv_dehors: float = gs.p1.hp
	nappe.appliquer_effets([gs.p1, gs.p2], 1.0)
	await process_frame
	_check("hors de la nappe, on ne brûle pas",
		is_equal_approx(gs.p1.hp, pv_dehors))

	# ── LES CHARBONS SONT DÉTERMINISTES ──────────────────────────────────────
	#
	# ⚠️ Un tirage local donnerait deux nappes différentes chez les deux pairs.
	# C'est la raison même pour laquelle les particules sont exclues du modèle
	# d'éblouissement — « tirées au sort, donc absentes chez l'autre pair ».
	var a1 := GadgetBraises.new()
	var b1 := GadgetBraises.new()
	a1._monter_visuel()
	b1._monter_visuel()
	var identiques := a1._charbons.size() == b1._charbons.size()
	for i in a1._charbons.size():
		if not a1._charbons[i].position.is_equal_approx(b1._charbons[i].position):
			identiques = false
	_check("deux nappes se dessinent à l'identique", identiques)
	a1.free()
	b1.free()

	gs.queue_free()
	await process_frame


## Les volumes — chantier CLASSES, étape 14.
##
## ⚠️ **Le contrôle qui porte les deux gadgets est qu'ils ne disent PAS la même
## chose.** La suie est dense et petite — on voit qu'il y a quelqu'un, pas qui ;
## la poussière est large et mince — personne ne voit loin, tout le monde voit un
## peu. Si un équilibrage les rapprochait, deux classes auraient le même gadget
## sous deux noms, et rien ne le signalerait.
func _test_volumes() -> void:
	print("\n[Les volumes : effacer la vue, sans arrêter la lumière]")

	var suie := GadgetSuie.new()
	var poussiere := GadgetPoussiere.new()

	# Ni l'un ni l'autre n'est un mur, ni un obstacle de lumière. C'est le motif
	# que la mine a introduit, et il tient la ligne de vue d'éblouissement
	# d'accord avec ce que l'œil voit.
	# ⚠️ `get_class()` rend « StaticBody2D » pour les deux : c'est le type NATIF,
	# pas le `class_name`. Les libellés seraient identiques et on ne saurait pas
	# lequel des deux a échoué.
	for spec in [["la suie", suie], ["la poussière", poussiere]]:
		var nom: String = spec[0]
		var v = spec[1]
		_check("%s laisse passer les balles" % nom, not v.arrete_les_balles)
		_check("%s laisse passer la lumière" % nom, not v.occulte_la_lumiere)
		_check("%s n'éblouit pas" % nom, not v.eblouit)

	# ── Elles ne racontent pas la même chose ────────────────────────────────
	_check("la suie est plus dense que la poussière",
		suie.opacite > poussiere.opacite,
		"%.2f vs %.2f" % [suie.opacite, poussiere.opacite])
	_check("la poussière couvre nettement plus large",
		poussiere.rayon > suie.rayon * 1.5,
		"%.0f vs %.0f" % [poussiere.rayon, suie.rayon])
	# ⚠️ La conséquence de conception, et c'est ELLE qu'on protège : dans la suie
	# on ne distingue plus personne, dans la poussière on distingue encore.
	suie.duree_vie = 0.0
	poussiere.duree_vie = 0.0
	_check("au cœur de la suie, un corps a presque disparu",
		suie.occultation_pour(Vector2.ZERO) > 0.8,
		"%.2f" % suie.occultation_pour(Vector2.ZERO))
	_check("au cœur de la poussière, il se devine encore",
		poussiere.occultation_pour(Vector2.ZERO) < 0.7,
		"%.2f" % poussiere.occultation_pour(Vector2.ZERO))

	# Dehors, rien — sinon un nuage effacerait toute la carte.
	_check("hors du volume, rien n'est effacé",
		is_zero_approx(suie.occultation_pour(Vector2(GadgetSuie.RAYON * 2.0, 0.0))))

	# ── Le socle répond pour TOUS, et c'est ce qui rend la boucle sûre ───────
	#
	# ⚠️ `player.gd` interroge tous les gadgets sans garde. Un gadget qui ne
	# saurait pas répondre ferait planter le jeu à chaque image — le défaut relevé
	# sur le groupe des fusées le 2026-09-09.
	var voile := GadgetVoile.new()
	_check("un gadget qui n'est pas un volume répond zéro",
		is_zero_approx(voile.occultation_pour(Vector2.ZERO)))
	voile.free()

	# ── Le contour est DÉTERMINISTE ─────────────────────────────────────────
	var a2 := GadgetSuie.new()
	var b2 := GadgetSuie.new()
	a2._monter_visuel()
	b2._monter_visuel()
	var identiques := a2._masse != null and b2._masse != null \
		and a2._masse.polygon.size() == b2._masse.polygon.size()
	if identiques:
		for i in a2._masse.polygon.size():
			if not a2._masse.polygon[i].is_equal_approx(b2._masse.polygon[i]):
				identiques = false
	_check("deux nuages se dessinent à l'identique", identiques)
	a2.free()
	b2.free()

	suie.free()
	poussiere.free()

	# ── Et le câblage : sans lui, les volumes n'effaceraient rien ────────────
	var src := FileAccess.get_file_as_string("res://player.gd")
	_check("player.gd interroge les gadgets, pas seulement les fusées",
		src.contains('for gadget in get_tree().get_nodes_in_group("gadgets"):')
			and src.contains("gadget.occultation_pour(global_position)"))


## Le leurre inerte — chantier CLASSES, étape 15.
##
## ⚠️ **Ce qu'on protège est qu'il fait LE MÊME TROU qu'un joueur.** Dans ce jeu
## on ne voit pas l'homme, on voit le trou qu'il fait dans la lumière : un leurre
## dont le rayon d'occlusion différerait de celui du joueur se démasquerait à
## l'ombre, sans qu'une seule erreur ne se lève. Et il emprunte l'asset du
## joueur, jamais un sprite à lui — deux images à tenir d'accord finiraient par
## diverger, et c'est le leurre qui aurait tort.
func _test_leurre() -> void:
	print("\n[Le leurre inerte : le même trou qu'un corps]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	# L'Illusionniste, index 1.
	gs.round_active = true
	gs.sandbox_mode = false
	gs.p1.equip_weapon(gs.weapon_for_index(1))
	gs._gadgets_poses_par.fill(0)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame

	var leurre = null
	for c in gs.bullet_container.get_children():
		if c is GadgetLeurre:
			leurre = c
	_check("le leurre est posé", leurre != null)
	if leurre == null:
		gs.queue_free()
		await process_frame
		return

	# ── LE TROU ──────────────────────────────────────────────────────────────
	#
	# 18 px : `player.gd` écrit « 18.0 is exactly the player radius » à côté de
	# son propre occluder. La valeur est donc reprise, pas choisie.
	_check("il occulte comme un corps", leurre.occulte_la_lumiere)
	_check("et sur le même rayon", is_equal_approx(leurre.rayon, 18.0),
		str(leurre.rayon))
	_check("il porte donc un occluder",
		leurre.get_node_or_null("Occluder") != null)
	_check("une balle s'y arrête, comme sur un corps", leurre.arrete_les_balles)
	_check("et une seule suffit à le démasquer", leurre.pv <= 1.0, str(leurre.pv))

	# ── L'ASSET EST CELUI DU JOUEUR ──────────────────────────────────────────
	var corps: Polygon2D = leurre.get_node_or_null("Visuel")
	_check("il porte un visuel", corps != null)
	if corps != null:
		# ⚠️ La silhouette est blanche et `Polygon2D.color` la MULTIPLIE : sans la
		# teinte d'adversaire, le leurre sort plus lumineux qu'un vrai corps sous
		# la même torche — reconnaissable du premier coup d'œil, donc inutile.
		# `player.gd` calibre cette teinte « en luminance pour l'équité ».
		_check("à la teinte d'un adversaire, pas en blanc",
			corps.color.is_equal_approx(Charte.ADVERSAIRE), str(corps.color))
	if corps != null:
		_check("et c'est la SILHOUETTE de la classe du poseur",
			corps.texture != null
				and String(corps.texture.resource_path).contains("fusil_silhouette"),
			String(corps.texture.resource_path) if corps.texture else "aucune")
		# ⚠️ Dimensionné par `empreinte_sprite()`, pas par la largeur brute : le
		# piège levé par le chantier R — recuire un asset redimensionnerait le
		# corps, et le leurre cesserait de faire la taille d'un joueur.
		var largeur: float = corps.polygon[1].x - corps.polygon[0].x
		_check("à l'empreinte du joueur, pas à la taille brute de la texture",
			is_equal_approx(largeur, Charte.empreinte_sprite(corps.texture.get_width())),
			"%.1f" % largeur)

	# ── IL EST INERTE ────────────────────────────────────────────────────────
	_check("il n'éblouit pas", not leurre.eblouit)
	_check("il n'efface rien autour de lui",
		is_zero_approx(leurre.occultation_pour(leurre.global_position)))
	_check("il ne demande jamais à s'allumer",
		not leurre.veut_s_allumer([gs.p1, gs.p2]))
	var pv_avant: float = gs.p2.hp
	gs.p2.global_position = leurre.global_position
	leurre.appliquer_effets([gs.p1, gs.p2], 1.0)
	_check("et il ne fait aucun dégât", is_equal_approx(gs.p2.hp, pv_avant))

	gs.queue_free()
	await process_frame


## Le grésillement — chantier CLASSES, étape 16.
##
## ⚠️ **Les deux contrôles qui comptent sont des NON-effets.** Le grésillement ne
## touche que ce que l'écran montre : s'il se mettait à modifier l'éblouissement,
## les trajectoires ou les dégâts, il cesserait d'être un coût de perception pour
## devenir un mensonge — la frontière que `brouillage.gd` s'est donnée. Et il ne
## doit **jamais éteindre franchement** : une lampe coupée est une information
## nette, donc utilisable ; ce qu'on vend est le doute.
func _test_gresillement() -> void:
	print("\n[Le grésillement : une lampe qui marche encore, mal]")
	var g := GadgetGresillement.new()
	g.global_position = Vector2.ZERO

	_check("il n'éblouit pas", not g.eblouit)
	_check("il n'efface rien", is_zero_approx(g.occultation_pour(Vector2.ZERO)))
	_check("il n'occulte pas la lumière", not g.occulte_la_lumiere)
	_check("il ne fait pas de dégâts et ne s'allume pas",
		not g.veut_s_allumer([]))

	# ── Hors de portée, RIEN. Exactement un, pas « presque un » ──────────────
	#
	# ⚠️ C'est l'invariant que `brouillage.gd` s'impose en premier : *« à
	# éblouissement nul, tout mode est l'identité. Pas presque : exactement. »*
	# Un facteur résiduel à distance dégraderait toutes les lampes de l'arène en
	# permanence, et **ne se verrait jamais dans un relevé**.
	_check("hors de portée, la lampe est intacte",
		is_equal_approx(g.facteur_de_lampe(Vector2(GadgetGresillement.RAYON + 1.0, 0.0)), 1.0),
		str(g.facteur_de_lampe(Vector2(GadgetGresillement.RAYON + 1.0, 0.0))))

	# ── Au cœur, ça papillote — et ça ne s'éteint jamais tout à fait ─────────
	var mini := 1.0
	var maxi := 0.0
	for i in 400:
		g._age = float(i) * 0.01
		var f: float = g.facteur_de_lampe(Vector2.ZERO)
		mini = minf(mini, f)
		maxi = maxf(maxi, f)
	_check("au cœur, la lampe faiblit vraiment", mini < 0.5, "%.2f" % mini)
	_check("mais ne s'éteint jamais franchement",
		mini >= GadgetGresillement.CREUX - 0.001, "%.3f" % mini)
	# Elle doit REVENIR : une lampe uniformément affaiblie serait un variateur,
	# pas un mauvais contact — et le joueur s'y habituerait en trois secondes.
	_check("et elle revient à sa pleine valeur", maxi > 0.98, "%.2f" % maxi)

	# ⚠️ **Déterministe** : deux pairs qui grésilleraient différemment
	# produiraient un défaut que personne ne pourrait reproduire.
	var h := GadgetGresillement.new()
	h.global_position = Vector2.ZERO
	var pareil := true
	for i in 50:
		g._age = float(i) * 0.037
		h._age = float(i) * 0.037
		if not is_equal_approx(g.facteur_de_lampe(Vector2.ZERO),
				h.facteur_de_lampe(Vector2.ZERO)):
			pareil = false
	_check("deux bobines grésillent à l'identique", pareil)
	h.free()
	g.free()

	# ── Le câblage, et le MINIMUM ───────────────────────────────────────────
	var src := FileAccess.get_file_as_string("res://player.gd")
	_check("player.gd applique le facteur à la torche",
		src.contains("gadget.facteur_de_lampe(global_position)")
			and src.contains("flashlight.energy = _energie_torche * lampe"))
	# ⚠️ **L'atténuation ne doit PAS être réinjectée dans l'état lissé.** C'est
	# exactement ce que faisait `flashlight.energy *= lampe` : elle se composait
	# d'image en image, six fois trop fort, et proportionnellement à la cadence.
	_check("et jamais en multipliant l'état lissé",
		not src.contains("flashlight.energy *= lampe"))
	# ⚠️ Le minimum, jamais le produit : deux bobines ne doivent pas éteindre deux
	# fois. Même règle que le MAX de l'éblouissement — un plafond, pas une somme.
	_check("il prend le MINIMUM, pas le produit",
		src.contains("lampe = minf(lampe, gadget.facteur_de_lampe"))
	# Et il doit s'appliquer AVANT la rétrodiffusion, qui s'en dérive : sinon le
	# halo du porteur resterait plein pendant que son faisceau s'éteint.
	var i_lampe := src.find("flashlight.energy = _energie_torche * lampe")
	var i_halo := src.find("body_light.energy = (flashlight.energy / 2.5)")
	_check("et avant la rétrodiffusion, qui en dérive",
		i_lampe > 0 and i_halo > i_lampe, "%d vs %d" % [i_lampe, i_halo])


## Le grésillement APPLIQUÉ — chantier CLASSES, étape 16.
##
## ⚠️ **Ce contrôle existe parce que le précédent ne suffisait pas.** Le facteur
## du gadget était juste, le câblage était juste, les deux étaient vérifiés — et
## l'effet réel valait **six fois** ce qu'il annonçait, parce que l'atténuation
## était réinjectée dans le lissage de l'image suivante et se composait sans fin.
## Pire : la valeur dépendait de la CADENCE, donc du matériel.
##
## Rien de ce qui se mesure sans jouer ne le voyait ; c'est le nombre imprimé par
## une capture qui l'a montré. Ce banc-ci fait tourner de vraies images de
## physique et lit l'énergie rendue, ce qui est la seule façon de fermer la porte.
func _test_gresillement_en_jeu() -> void:
	print("\n[Le grésillement, mesuré sur la lampe elle-même]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	# Le Parasite, index 0.
	gs.round_active = true
	gs.sandbox_mode = true
	gs.p1.equip_weapon(gs.weapon_for_index(0))
	gs._gadgets_poses_par.fill(0)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	Input.action_press("p1_torch")
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame

	var bobine = null
	for c in gs.bullet_container.get_children():
		if c is GadgetGresillement:
			bobine = c
	_check("la bobine est posée", bobine != null)
	if bobine == null:
		Input.action_release("p1_torch")
		gs.queue_free()
		await process_frame
		return

	# On cherche le creux réel de l'onde, puis on y FIGE l'appareil : sans ça, on
	# mesurerait un instant quelconque du papillotement.
	var creux := 1.0
	var age_creux := 0.0
	for i in 400:
		bobine._age = float(i) * 0.01
		var f: float = bobine.facteur_de_lampe(gs.p1.global_position)
		if f < creux:
			creux = f
			age_creux = bobine._age

	# Trente images de physique : assez pour que toute composition se voie.
	# C'est précisément ce que le défaut faisait — converger, image après image,
	# vers une valeur bien plus basse que celle annoncée.
	for i in 30:
		bobine._age = age_creux
		await physics_frame
	var rendue: float = gs.p1.flashlight.energy
	var attendue := 2.5 * creux

	_check("la torche du joueur est allumée", gs.p1.flashlight_on)
	# ±10 % : le souffle de la torche vaut ±3 %, et le `lerp` n'a pas tout à fait
	# convergé. Ce qu'on refuse est un ORDRE DE GRANDEUR, pas un dixième.
	_check("l'énergie rendue vaut ce que le gadget annonce",
		absf(rendue - attendue) < attendue * 0.10,
		"rendue %.3f, attendue %.3f" % [rendue, attendue])
	# ⚠️ Le garde-fou explicite contre le défaut d'origine : il rendait 0,094 là
	# où l'on attend 0,565. Un seuil franc dit *pourquoi* le contrôle existe.
	_check("elle ne s'effondre pas par composition", rendue > attendue * 0.6,
		"%.3f" % rendue)

	# Et hors de portée, la lampe revient EXACTEMENT à sa valeur.
	gs.p1.global_position = Vector2(400.0, 400.0) \
		+ Vector2(GadgetGresillement.RAYON * 2.0, 0.0)
	for i in 30:
		await physics_frame
	_check("hors de portée, la lampe est pleine",
		gs.p1.flashlight.energy > 2.2, "%.3f" % gs.p1.flashlight.energy)

	Input.action_release("p1_torch")
	gs.queue_free()
	await process_frame


## Vers quoi les effets d'éblouissement se tournent — correctif du 2026-09-09.
##
## ⚠️ **Le défaut que ce contrôle ferme a été trouvé À L'ŒIL, par Adrien, et il
## avait déjà été cherché sans succès dans une session précédente.** Le
## brouillage posait son flou sur l'adversaire EN DUR : dès qu'une lumière posée
## éblouissait, une grande ellipse allait se dessiner sur l'autre joueur, à
## l'autre bout de la carte. En ligne, un effet dont le métier est de MASQUER
## désignait la position de l'adversaire.
##
## ⚠️ Et c'était le **jumeau exact** d'un défaut corrigé le même jour sur le
## voile : la source d'éblouissement a deux consommateurs, le lot en a réparé un
## et laissé l'autre. Les deux restaient plausibles à l'écran, donc rien n'a
## parlé. Ce contrôle exige qu'il n'y ait **qu'une seule règle** pour les deux.
func _test_ancrage_des_effets() -> void:
	print("\n[Les effets d'éblouissement se tournent vers la VRAIE source]")
	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	var ui := FileAccess.get_file_as_string("res://ui.gd")

	_check("la règle est publique et vit dans game_state",
		gs.contains("func source_eblouissante_ou("))
	_check("le brouillage la consulte, au lieu de l'adversaire en dur",
		gs.contains("app.maj(regardeur, source_eblouissante_ou(regardeur,"))
	# ⚠️ La forme exacte du défaut, interdite nommément : c'est elle qu'une
	# relecture distraite remettrait en « simplifiant » l'appel.
	_check("l'adversaire n'est plus passé en dur au brouillage",
		not gs.contains("app.maj(p1 if i == 0 else p2, p2 if i == 0 else p1)"))
	_check("et le voile passe par la même règle",
		ui.contains("gs.source_eblouissante_ou(victime, defaut)"))

	# ── Et la FORME du brouillage suit ce que la source est ────────────────
	#
	# ⚠️ Seconde moitié du même défaut, corrigée sur demande d'Adrien : le flou et
	# le halo se couchaient sur `emetteur.rotation` et se poussaient devant lui.
	# Juste pour une torche, arbitraire pour une lumière POSÉE, dont la rotation
	# vaut ce que le hasard de la pose lui a laissé.
	var bv := FileAccess.get_file_as_string("res://brouillage_vue.gd")
	_check("le brouillage demande si la source a un axe",
		bv.contains("func _a_un_axe(") and bv.contains("var dirige := _a_un_axe(emetteur)"))
	_check("sans axe, ni allongement ni avance",
		bv.contains("if dirige else 1.0") and bv.contains("if dirige else 0.0"))
	# ⚠️ **Par ce que la source EXPOSE, jamais par son type** : nommer `Player`
	# depuis ce fichier le rendrait inchargeable par toute suite en `--script`,
	# `player.gd` nommant des autoloads. Piège payé par `fusee_modele.gd`.
	_check("et il le demande sans nommer aucune classe",
		bv.contains('emetteur.get("eblouissement_dirige")')
			and not bv.contains("is Player") and not bv.contains("is GadgetBase"))

	# Les trois familles répondent, et elles ne répondent pas pareil.
	var torche := GadgetTorcheFantome.new()
	var mine := GadgetMine.new()
	_check("une torche fantôme déclare un axe", torche.eblouissement_dirige)
	_check("une mine n'en déclare pas", not mine.eblouissement_dirige)
	torche.free()
	mine.free()


## La poudre de contact — chantier CLASSES, étape 17.
##
## ⚠️ **Les deux propriétés qui font le gadget, et elles sont fragiles toutes les
## deux.** Une trace VISIBLE DANS LE NOIR en ferait une alarme au lieu d'un relevé
## — le métier d'une autre classe. Et une trace qui disparaîtrait avec la nappe
## laisserait effacer son passage d'une balle, ce qui vide le gadget de son sens.
func _test_poudre() -> void:
	print("\n[La poudre de contact : un sol qui écrit]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	# La Sentinelle, index 6.
	gs.round_active = true
	gs.sandbox_mode = false
	gs.p1.equip_weapon(gs.weapon_for_index(6))
	gs._gadgets_poses_par.fill(0)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.p1.visible = true
	gs.p2.visible = true
	gs.p2.global_position = Vector2(400.0, 2000.0)
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame

	var poudre = null
	for c in gs.bullet_container.get_children():
		if c is GadgetPoudre:
			poudre = c
	_check("la poudre est posée", poudre != null)
	if poudre == null:
		gs.queue_free()
		await process_frame
		return

	_check("les balles la traversent", not poudre.arrete_les_balles)
	_check("la lumière aussi", not poudre.occulte_la_lumiere)
	_check("elle n'éblouit pas", not poudre.eblouit)
	_check("elle reste la manche entière", is_zero_approx(poudre.duree_vie))

	# ── ELLE ÉCRIT ───────────────────────────────────────────────────────────
	var avant: int = gs.arena.get_child_count()
	# Un joueur traverse la nappe de part en part, par pas de 10 px : plus court
	# que l'espacement des marques, donc c'est bien la DISTANCE cumulée qui
	# déclenche, et non le nombre d'appels.
	gs.p1.global_position = poudre.global_position - Vector2(GadgetPoudre.RAYON, 0.0)
	for i in 24:
		gs.p1.global_position += Vector2(10.0, 0.0)
		poudre._relever_les_pas()
	var posees: int = gs.arena.get_child_count() - avant
	_check("la traversée laisse une piste", posees > 0, str(posees))
	# ⚠️ Une marque tous les 26 px : 240 px parcourus dont ~220 dans la nappe en
	# donnent une petite dizaine. Ce qu'on refuse est une marque par APPEL — 24 —
	# qui trahirait une règle au temps au lieu d'une règle à la distance.
	_check("et pas une marque par image", posees < 14, str(posees))

	# ── ELLE NE SE LIT QUE SOUS LA LUMIÈRE ──────────────────────────────────
	var trace: Node2D = null
	for c in gs.arena.get_children():
		if String(c.name).begins_with("Trace"):
			trace = c
	_check("une trace existe dans l'arène", trace != null)
	if trace != null:
		# ⚠️ C'est CE réglage qui fait la classe : dans le noir, la trace n'existe
		# pas. Il faut revenir et éclairer. `light_mask = 0` en ferait une alarme.
		_check("elle n'est visible que sous une lumière",
			(trace as CanvasItem).light_mask == MapGeometry.WALL_LAYER,
			str((trace as CanvasItem).light_mask))
		# ⚠️ Enfant de l'ARÈNE : abattre la poudre ne doit pas effacer ce qu'elle
		# a déjà écrit, sinon une balle suffirait à nier son passage.
		_check("et elle survit à la nappe, car elle vit dans l'arène",
			trace.get_parent() == gs.arena)

	var restantes := 0
	poudre.detruire()
	await process_frame
	for c in gs.arena.get_children():
		if String(c.name).begins_with("Trace"):
			restantes += 1
	_check("la nappe abattue, la piste demeure", restantes > 0, str(restantes))

	# ── Sortir efface la mémoire, pas la piste ──────────────────────────────
	var p2 := GadgetPoudre.new()
	p2.global_position = Vector2.ZERO
	_check("un joueur hors nappe n'a pas de dernier pas",
		p2._dernier[0] == Vector2.INF)
	p2.free()

	gs.queue_free()
	await process_frame


## Les fusées par classe — chantier CLASSES, étape 18.
##
## ⚠️ **Ce qu'on protège est que ZÉRO reste zéro.** Le Spectre n'a aucune fusée,
## et c'est sa classe — « la seule qui n'éclaire jamais ». Un repli plausible,
## en jeu ou à l'entraînement, lui rendrait exactement la chose que sa classe lui
## retire, et rien à l'écran ne le dirait.
func _test_fusees_par_classe() -> void:
	print("\n[Les fusées viennent de la classe, pas d'une constante]")
	var scene: PackedScene = load("res://main.tscn")
	var gs: Node = scene.instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame

	var catalogue: Array = gs.classes()

	# ── Le catalogue dit des choses DIFFÉRENTES, sinon l'étape n'a rien fait ─
	var stocks: Array[int] = []
	for c in catalogue:
		stocks.append(int(c.fusees.stock) if c.fusees != null else -1)
	_check("les dix classes ne partent pas toutes avec le même stock",
		stocks.min() != stocks.max(), str(stocks))
	_check("au moins une classe n'en a aucune", stocks.has(0), str(stocks))
	var rechargent := 0
	for c in catalogue:
		if c.fusees != null and c.fusees.recharge_active():
			rechargent += 1
	_check("et au moins une recharge", rechargent > 0, str(rechargent))

	# ── La réserve suit la classe équipée ───────────────────────────────────
	gs.round_active = true
	gs.sandbox_mode = false
	# ⚠️ GDScript n'a pas de `for ... else` : le drapeau n'est pas de la
	# maladresse, c'est la seule forme disponible.
	var toutes_justes := true
	var faute := ""
	for idx in catalogue.size():
		gs.p1.equip_weapon(gs.weapon_for_index(idx))
		gs._accorder_fusees(0.0)
		var attendu := int(catalogue[idx].fusees.stock)
		var lu := int(gs.fusees_restantes(0))
		if lu != attendu:
			toutes_justes = false
			faute = "%s : %d au lieu de %d" % [String(catalogue[idx].slug()), lu, attendu]
			break
	_check("la réserve suit la classe équipée, pour les dix", toutes_justes, faute)

	# ── ZÉRO reste zéro, y compris en bac à sable ───────────────────────────
	#
	# ⚠️ `fusee_disponible()` rendait « toujours vrai » sans condition en bac à
	# sable. Le Spectre y aurait donc eu des fusées illimitées là où il n'en a
	# aucune en match : l'entraînement lui aurait appris un geste qui n'existe pas.
	var spectre_idx := -1
	for i in catalogue.size():
		if String(catalogue[i].slug()) == "spectre":
			spectre_idx = i
	gs.p1.equip_weapon(gs.weapon_for_index(spectre_idx))
	gs._accorder_fusees(0.0)
	_check("le Spectre part sans fusée", gs.fusees_restantes(0) == 0,
		str(gs.fusees_restantes(0)))
	_check("et il n'en a pas davantage en match", not gs.fusee_disponible(0))
	gs.sandbox_mode = true
	_check("ni à l'entraînement", not gs.fusee_disponible(0))
	gs.sandbox_mode = false

	# ── La RECHARGE avance, et s'arrête au plafond ──────────────────────────
	var terrassier := -1
	for i in catalogue.size():
		if catalogue[i].fusees != null and catalogue[i].fusees.recharge_active():
			terrassier = i
			break
	gs.p1.equip_weapon(gs.weapon_for_index(terrassier))
	gs._accorder_fusees(0.0)
	var profil = catalogue[terrassier].fusees
	var plein := int(gs.fusees_restantes(0))
	# On en consomme une, puis on laisse passer une période entière.
	gs.rpc_stock_fusees(0, plein - 1)
	_check("une fusée consommée manque", gs.fusees_restantes(0) == plein - 1)
	gs._accorder_fusees(profil.periode_recharge + 0.01)
	_check("elle revient après une période",
		gs.fusees_restantes(0) == plein, str(gs.fusees_restantes(0)))
	# ⚠️ Et rien ne se capitalise contre le plafond : laisser courir
	# l'accumulateur à réserve pleine offrirait une fusée instantanée au premier
	# tir suivant — une réserve cachée, que `flare_profile.gd` refuse nommément.
	gs._accorder_fusees(profil.periode_recharge * 3.0)
	_check("et la réserve ne dépasse jamais son plafond",
		gs.fusees_restantes(0) == plein, str(gs.fusees_restantes(0)))
	gs.rpc_stock_fusees(0, plein - 1)
	gs._accorder_fusees(0.01)
	_check("aucun temps n'a été capitalisé contre le plafond",
		gs.fusees_restantes(0) == plein - 1, str(gs.fusees_restantes(0)))

	# ── Le HUD les MONTRE ───────────────────────────────────────────────────
	#
	# ⚠️ Une réserve qui varie de zéro à trois selon la classe et qui se recharge
	# doit se compter à l'écran. `flare_profile.gd` le dit pour sa recharge : une
	# réserve cachée est le genre d'avantage que ce jeu refuse.
	var ui: Node = gs.get_node_or_null("UI")
	_check("le HUD porte un indicateur de réserves",
		ui != null and not ui.p1_reserves.is_empty())
	if ui != null and not ui.p1_reserves.is_empty():
		gs.p1.equip_weapon(gs.weapon_for_index(spectre_idx))
		gs._accorder_fusees(0.0)
		ui._maj_reserves(ui.p1_reserves, 0)
		_check("et il dit « aucune » plutôt que zéro",
			String(ui.p1_reserves["fusees"].text) == "FUSÉES —",
			String(ui.p1_reserves["fusees"].text))
		gs.p1.equip_weapon(gs.weapon_for_index(terrassier))
		gs._accorder_fusees(0.0)
		ui._maj_reserves(ui.p1_reserves, 0)
		_check("et il compte celles qu'on a",
			String(ui.p1_reserves["fusees"].text) == "FUSÉES %d" % plein,
			String(ui.p1_reserves["fusees"].text))

	gs.queue_free()
	await process_frame


## L'archive du match — chantier CLASSES, étape 19.
##
## ⚠️ **Le piège que ce contrôle garde est un piège de LECTURE, pas de code.** La
## clé `classe`, arrivée au schéma 3, est un booléen qui veut dire « ce match
## comptait au classement ». `classe_j1` et `classe_j2`, arrivées au schéma 4,
## portent le slug de la classe jouée. Les trois vivent dans le même
## dictionnaire ; confondre les deux premières avec la troisième ferait remonter
## au classement des matchs amicaux, ou l'inverse.
func _test_archive() -> void:
	print("\n[L'archive dit QUELLE CLASSE a été jouée]")
	var MR := load("res://match_record.gd")
	var MHV := load("res://match_history_view.gd")

	_check("le schéma est passé à 4", MR.SCHEMA_VERSION == 4,
		str(MR.SCHEMA_VERSION))

	var rec: Dictionary = MR.build(0, 42.0, "Pistolet silencieux", "Carabine double",
		"default", "local", MR.Format.BO1, false, "m-1", true, "victoire",
		"spectre", "allumeur")
	_check("l'enregistrement porte les deux classes",
		rec.get("classe_j1") == "spectre" and rec.get("classe_j2") == "allumeur",
		"%s / %s" % [rec.get("classe_j1"), rec.get("classe_j2")])
	# ⚠️ Le contrôle qui garde le piège de lecture : `classe` reste le booléen du
	# classement, et il ne doit surtout pas se mettre à porter un slug.
	_check("et `classe` reste le booléen du classement",
		rec.get("classe") is bool and bool(rec["classe"]))
	_check("le slug, jamais le libellé",
		String(rec.get("classe_j1")) == String(rec.get("classe_j1")).to_lower())

	# ⚠️ **Vide plutôt qu'un repli plausible.** Un journal d'avant les classes ne
	# doit pas se voir attribuer « pistolet » : ce serait fausser la seule
	# statistique que ces clés existent pour porter.
	var vieux: Dictionary = MR.build(0, 42.0, "Pompe", "Fusil", "default", "local")
	_check("sans classe déclarée, la clé reste vide",
		vieux.get("classe_j1") == "" and vieux.get("classe_j2") == "")

	# ── La vue la fait traverser, et n'invente rien ─────────────────────────
	var ligne: Dictionary = MHV.row_from(rec, 0)
	_check("la vue porte la classe des deux joueurs",
		ligne.get("classe_j1") == "spectre" and ligne.get("classe_j2") == "allumeur")
	_check("et celle du poste, comme pour l'arme",
		ligne.has("classe_moi") and ligne.has("classe_adverse"))
	var ligne_vieille: Dictionary = MHV.row_from(vieux, 0)
	_check("une entrée d'avant les classes n'en invente pas",
		ligne_vieille.get("classe_j1") == "" and ligne_vieille.get("classe_moi") == "")

	# ── Le bilan compte les classes SANS remplacer les armes ────────────────
	#
	# ⚠️ Remplacer la statistique effacerait tout l'historique d'un joueur au lieu
	# de l'enrichir : les journaux d'avant le schéma 4 n'ont pas de classe.
	# ⚠️ `summarize()` prend des LIGNES (`row_from`), pas des enregistrements
	# bruts : ce sont elles qui portent `moi` et `classe_moi`. Le premier jet lui
	# passait les enregistrements, et l'appel invalide **interrompait la fonction**
	# — les six contrôles suivants ne tournaient plus, en silence.
	var bilan: Dictionary = MHV.summarize([ligne, MHV.row_from(rec, 0), ligne_vieille])
	_check("le bilan garde l'arme favorite", bilan.has("arme_favorite"))
	_check("et gagne la classe favorite", bilan.has("classe_favorite"))
	_check("qui compte les matchs où elle est connue",
		int(bilan.get("classe_favorite_matchs", 0)) == 2,
		str(bilan.get("classe_favorite_matchs")))

	# ── Et le jeu la passe vraiment ────────────────────────────────────────
	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	_check("game_state archive le slug de classe des deux joueurs",
		gs.contains("_slug_de_classe(p1),") and gs.contains("_slug_de_classe(p2))"))
	_check("et il rend vide plutôt qu'un repli",
		gs.contains('return String(classe.slug()) if classe != null else ""'))
