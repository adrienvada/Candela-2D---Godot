## Le duel change de viewport selon le nombre de vues — et il doit savoir REVENIR.
##
## Chantier R, option (b) : en vue unique le duel est rendu par le viewport
## racine, à la résolution de la fenêtre, au lieu d'être dessiné à 957×1080 dans
## un `SubViewport` puis étiré. En écran scindé il repasse par ses deux vues, qui
## sont indispensables — deux masques de cull, deux caméras.
##
## **C'est un aller-RETOUR, et c'est le retour qui est dangereux.** L'aller est
## visible : si la vue unique n'était pas rendue, l'écran serait noir et
## quelqu'un le dirait dans la minute. Le retour ne se voit pas de la même façon :
## une racine laissée sur le monde du duel, un masque de cull jamais rétabli ou
## une caméra restée pointée sur la racine donnent un écran scindé **à moitié
## juste** — une vue correcte, l'autre vide ou montrant les lumières de l'autre
## joueur. Dans un jeu où être vu c'est être mort, cette dernière n'est pas un
## défaut d'affichage, c'est un défaut d'équité.
##
## Cette suite ne rend rien. Elle vérifie l'ÉTAT du montage après chaque bascule,
## ce qu'un banc à fenêtre ne fait pas et ce qu'aucun test ne faisait.
##
## Lancer : godot --headless --path . --script res://tools/test_rendu_racine.gd
extends SceneTree

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
	print("=== LE DUEL SAIT-IL CHANGER DE VIEWPORT, ET REVENIR ===")
	await process_frame
	# `load` et non `preload`, pour la raison consignée dans `test_banc.gd` : un
	# `preload` compilerait la scène avant que les autoloads existent.
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		_check("main.tscn se charge", false)
		_sortir()
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var racine: Window = root
	var monde_racine_avant: World2D = racine.world_2d
	var masque_avant: int = racine.canvas_cull_mask

	if main.cam1 == null or main.cam2 == null:
		_check("les caméras existent après le démarrage", false,
			"sans elles la bascule sort sans rien changer, par conception")
		_sortir()
		return

	# --- Aller : une seule vue regardée, comme en ligne et à l'entraînement ---
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()

	_check("vue unique : le duel est rendu par la racine", main._rendu_racine)
	_check("vue unique : la racine a adopté le monde du duel",
		racine.world_2d == main.vp1.world_2d)
	_check("vue unique : la racine porte le masque de cull de la vue regardée",
		racine.canvas_cull_mask == main.vp1.canvas_cull_mask,
		"racine %d vs vue %d" % [racine.canvas_cull_mask, main.vp1.canvas_cull_mask])
	_check("vue unique : la caméra locale rend dans la racine",
		main.cam1.custom_viewport == racine)
	# Le SubViewport ARRÊTÉ est la moitié du gain : une vue cachée qui dessine
	# encore coûte 1,5 ms pour une texture que personne n'affiche.
	for vue in [main.vp1, main.vp2]:
		_check("vue unique : %s est arrêté" % vue.name,
			vue.render_target_update_mode == SubViewport.UPDATE_DISABLED)

	# **Ce que la racine peint POUR ELLE-MÊME doit s'effacer.** Prêter le `World2D`
	# du duel à la racine y fait entrer ses propres `CanvasItem` : le `Background`
	# noir plein cadre et les conteneurs de vue, qui peignent la texture GELÉE de
	# vues que ce chemin vient d'arrêter. Livrés tels quels par R3 (b), ils
	# recouvraient l'arène — écran entièrement noir à l'entraînement comme en
	# ligne, des deux côtés du lien, du 2026-08-25 au 2026-08-28.
	#
	# ⚠️ **Cette suite est restée VERTE tout du long, et c'est sa leçon.** Chacun
	# des états qu'elle contrôle — mondes, masques, caméras, `update_mode` — était
	# juste. Ce qui manquait n'était pas un état mais une IMAGE, et elle n'en lit
	# aucune. Les deux contrôles ci-dessous ne réparent pas ça : ils verrouillent
	# l'invariant du correctif, pas son effet. **Ce qui a du sens vit ailleurs**,
	# dans `tools/test_rendu.gd` — « le sol du duel n'est pas recouvert », en
	# pixels, à fenêtre, hors de ce lot.
	# On interroge la RÈGLE — « aucun enfant peintre de la racine ne peint » — et
	# non trois noms : c'est ce que `_accorder_la_peinture_de_la_racine()` promet,
	# et un contrôle qui nommerait `Background` laisserait passer le fond que
	# quelqu'un poserait demain sur `SplitScreen`.
	_check("vue unique : plus aucun enfant de la racine ne peint",
		_peintres_bruyants(main).is_empty(),
		"peignent encore : %s" % str(_peintres_bruyants(main)))
	_check("vue unique : `UI` continue de peindre, c'est une CanvasLayer",
		main.get_node_or_null(^"UI") is CanvasLayer,
		"si le HUD devenait un Control, il suivrait la caméra")

	# **Le piège que la bascule du `world_2d` ouvre sur l'AUDIO, signalé par la
	# session « spatialisation du son » et mesuré par elle avant d'être écrit.**
	#
	# Un `AudioStreamPlayer2D` sort une fois PAR VIEWPORT AUDITEUR de son
	# `World2D`. La racine est auditrice par défaut ; si elle adopte le monde du
	# duel alors que `vp1` porte déjà l'`AudioListener2D`, **chaque son est joué
	# deux fois** : une fois depuis l'oreille du joueur, une fois depuis le repli
	# de la racine — c'est-à-dire le centre de son écran virtuel, le point fixe
	# hors de la carte qui était exactement le défaut d'origine de S1.
	#
	# Le symptôme est le pire de sa famille : **pas un silence, un son
	# parfaitement audible**, environ +3 dB, panoramique juste mêlé au faux. On
	# chercherait dans le mixage, pas ici.
	#
	# **On appelle le VRAI `poser_oreille`, on ne simule plus.** La première
	# version de ce contrôle posait `vp1.audio_listener_enable_2d = true` à la
	# main, puis vérifiait le compte — et elle validait donc l'invariant contre
	# une imitation. Elle serait restée verte le jour où le rendu a cessé de
	# gérer ce drapeau pour le laisser à `AudioManager`, qui en est le
	# propriétaire. Un contrôle qui simule la moitié du système ne mesure que
	# l'autre moitié.
	# **Par l'arbre, pas par le nom.** En mode `--script`, ce fichier est compilé
	# AVANT que les autoloads existent : nommer `AudioManager` directement donne
	# « Identifier not found » et la suite ne tourne pas du tout. Même piège que
	# `test_banc.gd`, autre déguisement.
	var audio: Node = root.get_node_or_null("AudioManager")
	if audio == null:
		_check("l'autoload AudioManager est là", false)
		_sortir()
		return
	audio.poser_oreille(main.p1)
	var auditeurs := _auditeurs_du_duel(main)
	_check("vue unique : un seul viewport écoute le monde du duel",
		auditeurs.size() == 1,
		"auditeurs : %s — deux, et chaque son sort deux fois" % str(auditeurs))

	# --- Retour : les deux vues, l'écran scindé local ---
	main.vp2.get_parent().show()
	main._accorder_rendu_aux_vues()

	_check("retour : le duel ne passe plus par la racine", not main._rendu_racine)
	_check("retour : la racine a retrouvé SON monde",
		racine.world_2d == monde_racine_avant,
		"une racine laissée sur le monde du duel dessine l'arène sous le HUD")
	_check("retour : le masque de cull de la racine est rétabli",
		racine.canvas_cull_mask == masque_avant,
		"racine %d vs %d attendu" % [racine.canvas_cull_mask, masque_avant])
	_check("retour : chaque caméra a retrouvé sa vue",
		main.cam1.custom_viewport == main.vp1 and main.cam2.custom_viewport == main.vp2)
	# **Et la racine doit REDEVENIR auditrice**, faute de quoi le jeu serait muet
	# partout ailleurs — menus compris — sans erreur et sans que ce lot-ci soit
	# soupçonné. C'est `rendre_oreille()` qui le fait, pas le rendu : on l'appelle
	# donc pour de vrai, comme la fin d'un match le ferait.
	audio.rendre_oreille()
	_check("retour : la racine réécoute, comme au démarrage",
		root.is_audio_listener_2d(),
		"les menus et tout ce qui joue hors match passent par elle")
	for vue in [main.vp1, main.vp2]:
		_check("retour : %s dessine de nouveau" % vue.name,
			vue.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	_check("retour : tous les enfants peintres de la racine repeignent",
		_peintres_muets(main).is_empty(),
		"restent muets : %s" % str(_peintres_muets(main)))

	# --- L'interrupteur de recours doit vraiment ramener l'ancien chemin ---
	main.rendu_racine_autorise = false
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()
	_check("interrupteur à false : la vue unique repasse par son SubViewport",
		not main._rendu_racine)
	_check("interrupteur à false : la vue regardée dessine encore",
		main.vp1.render_target_update_mode == SubViewport.UPDATE_ALWAYS)

	# --- QUITTER LE DUEL DOIT QUITTER LA RACINE ---
	#
	# **Ce chemin ne repassait par aucun accord de rendu**, et rien ne le disait :
	# `_rendu_racine` restait vrai sous les menus, la racine gardant le `World2D`
	# du duel — vérifié le 2026-08-28, au retour de l'entraînement comme d'une
	# partie en ligne. Personne ne le voyait parce que le `Background` noir opaque
	# recouvrait l'arène, c'est-à-dire par le défaut d'à côté.
	#
	# **C'est le retour qui est dangereux, encore une fois.** Le fond s'efface
	# désormais pendant le rendu racine : un oubli ici ne se paierait plus par un
	# invariant théorique mais par l'arène affichée sous les menus.
	main.rendu_racine_autorise = true
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()
	_check("préalable : on est bien reparti dans le rendu racine", main._rendu_racine)

	main._on_main_menu_requested()

	_check("retour au menu : le duel a quitté la racine", not main._rendu_racine)
	_check("retour au menu : la racine a retrouvé SON monde",
		racine.world_2d == monde_racine_avant)
	_check("retour au menu : les deux vues sont de nouveau montrées",
		main.vp1.get_parent().visible and main.vp2.get_parent().visible)
	_check("retour au menu : les enfants peintres de la racine repeignent",
		_peintres_muets(main).is_empty(),
		"restent muets sous les menus : %s" % str(_peintres_muets(main)))
	# Sans quoi le prochain accord repartirait aussitôt dans la branche « une
	# seule vue » — donc dans le rendu racine, sous les menus.
	_check("retour au menu : l'entraînement est refermé", not main.training_mode)

	_sortir()

## Les enfants directs de la racine qui peignent encore, nommés pour que l'échec
## soit lisible. Un `CanvasLayer` n'en est pas : il s'attache au viewport et non
## au canvas du monde, donc l'échange de `World2D` ne le concerne pas.
func _peintres_bruyants(main: Node) -> Array[String]:
	var noms: Array[String] = []
	for enfant in main.get_children():
		var peintre := enfant as CanvasItem
		if peintre != null and not is_zero_approx(peintre.modulate.a):
			noms.append("%s (alpha %.2f)" % [peintre.name, peintre.modulate.a])
	return noms

## L'inverse : ceux qu'on a laissés muets alors qu'ils devraient peindre.
func _peintres_muets(main: Node) -> Array[String]:
	var noms: Array[String] = []
	for enfant in main.get_children():
		var peintre := enfant as CanvasItem
		if peintre != null and not is_equal_approx(peintre.modulate.a, 1.0):
			noms.append("%s (alpha %.2f)" % [peintre.name, peintre.modulate.a])
	return noms

## Les viewports qui ÉCOUTENT le monde du duel, nommés pour que l'échec soit
## lisible. Trois candidats seulement : la racine et les deux vues partagent ce
## `World2D`, personne d'autre ne l'a.
func _auditeurs_du_duel(main: Node) -> Array[String]:
	var noms: Array[String] = []
	var monde: World2D = main.vp1.world_2d
	for vue in [root, main.vp1, main.vp2]:
		if vue.world_2d == monde and vue.is_audio_listener_2d():
			noms.append("racine" if vue == root else String(vue.name))
	return noms


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent")
		quit(0)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
		quit(1)
