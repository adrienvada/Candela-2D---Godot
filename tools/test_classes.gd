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

	_check("sans scène, le gadget n'est pas livré", not g.est_livre())
	g.scene = "res://gadget_voile.tscn"
	_check("avec une scène, le gadget est livré", g.est_livre())

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
