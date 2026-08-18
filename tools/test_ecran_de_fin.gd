## L'écran de fin, là où « encore une » se décide (V3.1).
##
## Ce que la suite protège n'est pas l'animation — c'est qu'elle **s'arrête**.
## Une respiration qui survit à la fermeture de l'écran laisse une entrée du menu
## principal enfler toute seule, et cette entrée-là n'est plus « rejouer » mais
## « prêt » ou « jouer » : le menu se met à insister pour lancer une partie que
## personne n'a demandée. Une boucle infinie ne se signale jamais d'elle-même.
##
## Lancer : godot --headless --path . --script res://tools/test_ecran_de_fin.gd
extends SceneTree

var _failures: int = 0
var _ui: Node
var _main: Node

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== ÉCRAN DE FIN ===")
	await process_frame
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_ui = _main.get_node_or_null("UI")
	if _ui == null or not _ui.has_method("show_game_over"):
		printerr("✗ l'interface n'a pas son script")
		quit(1)
		return

	_test_souffle()
	await _test_ouverture_fermeture()
	_test_graine()
	await _test_pression_du_pret()
	_test_chrono()
	await _test_verdict()
	_test_tension_killcam()
	_test_negatif_killcam()
	_test_disposition_hud()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	_main.queue_free()
	quit(1 if _failures > 0 else 0)

## La courbe d'enflure, sur tout un battement.
func _test_souffle() -> void:
	print("\n[La respiration reste une respiration]")
	var entrees: Array = _ui._relance_entries
	_check("les entrées de relance sont recensées", entrees.size() >= 5,
		"%d trouvée(s) — 4 salons + l'écran partagé" % entrees.size())

	# On applique la courbe à la main sur tout un cycle : c'est le seul moyen de
	# vérifier l'amplitude sans dépendre du moment où le tween est échantillonné.
	var mini := 9.0
	var maxi := 0.0
	for pas in 41:
		_ui._appliquer_souffle(float(pas) / 40.0)
		for btn: Button in entrees:
			if btn.is_visible_in_tree():
				mini = minf(mini, btn.scale.x)
				maxi = maxf(maxi, btn.scale.x)
	if mini > maxi:
		# Aucune entrée visible hors écran de fin : la courbe n'a rien à montrer.
		mini = 1.0
		maxi = 1.0
	_check("l'enflure ne descend jamais sous la taille normale", mini >= 0.999,
		"minimum %.4f" % mini)
	_check("l'enflure ne dépasse pas trois pour cent", maxi <= 1.0301,
		"maximum %.4f" % maxi)
	# La boucle doit se refermer : mêmes bornes au départ et à l'arrivée, sinon
	# chaque battement marque une couture d'une frame.
	_ui._appliquer_souffle(0.0)
	var depart := (entrees[0] as Button).scale.x
	_ui._appliquer_souffle(1.0)
	var arrivee := (entrees[0] as Button).scale.x
	_check("le cycle se referme sans couture", is_equal_approx(depart, arrivee),
		"%.5f puis %.5f" % [depart, arrivee])

## Ouvrir puis fermer l'écran de fin ne doit rien laisser derrière.
func _test_ouverture_fermeture() -> void:
	print("\n[Ce qui s'ouvre se referme]")
	_ui.show_game_over(0)
	await process_frame
	_check("la respiration tourne", _ui._souffle_relance != null
		and _ui._souffle_relance.is_valid())
	var graines := 0
	for btn: Button in _ui._relance_entries:
		if int(btn.get_meta(_ui.META_NAV_SEED, -1)) == _ui.NAV_SEED_LES_DEUX:
			graines += 1
	_check("chaque entrée de relance attire les deux curseurs",
		graines == _ui._relance_entries.size(),
		"%d sur %d" % [graines, _ui._relance_entries.size()])

	_ui.hide_game_over()
	await process_frame
	_check("la respiration s'arrête", _ui._souffle_relance == null)
	var reste := 0
	var enflees := 0
	for btn: Button in _ui._relance_entries:
		if btn.has_meta(_ui.META_NAV_SEED):
			reste += 1
		if not is_equal_approx(btn.scale.x, 1.0):
			enflees += 1
	# Le point qui compte : hors écran de fin, « PRÊT » et « JOUER » ne doivent
	# ni enfler ni aimanter. Le menu n'a pas à insister pour lancer une partie.
	_check("plus aucune graine ne subsiste", reste == 0, "%d restante(s)" % reste)
	_check("les entrées ont repris leur taille", enflees == 0,
		"%d encore enflée(s)" % enflees)

## La graine « les deux » attire bien les deux curseurs, et non un seul.
func _test_graine() -> void:
	print("\n[Une graine pour deux curseurs]")
	var cible: Button = _ui._relance_entries[0]
	cible.set_meta(_ui.META_NAV_SEED, _ui.NAV_SEED_LES_DEUX)
	# Une graine nommée ne doit toujours attirer QUE son joueur : la nouvelle
	# valeur s'ajoute au comportement d'origine, elle ne le remplace pas.
	var autre: Button = _ui._relance_entries[1]
	autre.set_meta(_ui.META_NAV_SEED, 1)
	_check("la valeur commune se distingue d'un indice de joueur",
		_ui.NAV_SEED_LES_DEUX != 0 and _ui.NAV_SEED_LES_DEUX != 1
		and _ui.NAV_SEED_LES_DEUX < 0)
	cible.remove_meta(_ui.META_NAV_SEED)
	autre.remove_meta(_ui.META_NAV_SEED)

## V3.2 — l'éclat qui dit que l'autre vient de se déclarer.
##
## Ce qui se vérifie ici, c'est la COHABITATION avec V3.1. Les deux effets vivent
## sur les mêmes boutons ; s'ils partageaient une propriété, l'un couperait
## l'autre — et le défaut serait invisible en test unitaire, puisque chacun
## fonctionne seul.
func _test_pression_du_pret() -> void:
	print("\n[La pression du prêt]")
	_ui.show_game_over(0)
	await process_frame
	var avant_echelle := (_ui._relance_entries[0] as Button).scale.x

	_ui.signaler_adversaire_pret()
	var eclaire := 0
	for btn: Button in _ui._relance_entries:
		if btn.is_visible_in_tree() and btn.self_modulate.r > 1.0:
			eclaire += 1
	_check("l'entrée visible s'allume", eclaire >= 1, "%d allumée(s)" % eclaire)

	# Le point qui compte : la respiration tourne toujours, et sur sa propre
	# propriété. Un éclat écrit sur `scale` l'aurait écrasée ; écrit sur
	# `modulate`, il aurait rallumé un bouton grisé faute de joueur.
	_check("la respiration n'est pas coupée", _ui._souffle_relance != null
		and _ui._souffle_relance.is_valid())
	_ui._appliquer_souffle(0.5)
	var apres_echelle := (_ui._relance_entries[0] as Button).scale.x
	_check("l'éclat et la respiration n'écrivent pas au même endroit",
		not is_equal_approx(avant_echelle, apres_echelle)
		or _ui._relance_entries[0].self_modulate.r > 1.0)

	_ui.hide_game_over()
	await process_frame
	var restants := 0
	for btn: Button in _ui._relance_entries:
		if btn.self_modulate != Color.WHITE:
			restants += 1
	_check("l'éclat ne survit pas à la fermeture", restants == 0,
		"%d entrée(s) encore allumée(s)" % restants)

## V3.4 — la dernière minute se voit, et l'entraînement n'a pas d'horloge.
func _test_chrono() -> void:
	print("\n[Le chrono de la dernière minute]")
	_ui.reinitialiser_chrono()
	_ui.update_hud(null, null, 120.0)
	_check("au-delà d'une minute, le chrono reste neutre",
		not _ui.time_label.has_theme_color_override("font_color"))

	_ui.update_hud(null, null, 45.0)
	_check("sous une minute, il passe à l'or",
		_ui.time_label.get_theme_color("font_color") == _ui.COLOR_GOLD)

	_ui.update_hud(null, null, 7.4)
	_check("sous dix secondes, il vire à l'alerte",
		_ui.time_label.get_theme_color("font_color") == _ui.COLOR_P2)
	_check("et il bat", _ui.time_label.scale.x > 1.0,
		"échelle %.3f" % _ui.time_label.scale.x)
	# Le battement naît du temps lui-même : juste avant une seconde pleine il est
	# retombé, juste après il frappe. Un tween redémarré chaque frame tremblerait.
	_ui.update_hud(null, null, 7.02)
	var creux: float = _ui.time_label.scale.x
	_ui.update_hud(null, null, 6.99)
	var pic: float = _ui.time_label.scale.x
	_check("le coup tombe sur la seconde", pic > creux,
		"%.3f avant, %.3f après" % [creux, pic])

	# Une manche qui repart derrière une fin de match hériterait sinon du rouge
	# pendant ses quatre premières minutes.
	_ui.reinitialiser_chrono()
	_ui.update_hud(null, null, 300.0)
	_check("une nouvelle manche repart en blanc",
		not _ui.time_label.has_theme_color_override("font_color")
		and is_equal_approx(_ui.time_label.scale.x, 1.0))

	# L'entraînement écrivait « ENTRAÎNEMENT » et le voyait effacé à la frame
	# suivante : la ligne existait et ne servait à rien.
	_ui.time_label.text = "ENTRAÎNEMENT"
	_ui.update_hud(null, null, 42.0, false)
	_check("sans horloge, le HUD n'écrase pas le libellé",
		_ui.time_label.text == "ENTRAÎNEMENT", _ui.time_label.text)

## V3.6 et V3.8 — l'écran de fin dit ce qui vient de se passer.
func _test_verdict() -> void:
	print("\n[Le verdict et le score]")
	# V3.8 : l'égalité en gris, pas en blanc. Le blanc est la couleur de ce qui
	# s'affirme ; une égalité n'affirme rien.
	_ui.show_game_over(-1)
	await process_frame
	_check("une égalité s'écrit en gris",
		_ui.game_over_title.get_theme_color("font_color") == _ui.COLOR_DIM,
		str(_ui.game_over_title.get_theme_color("font_color")))
	# Et le silence sec n'a pas laissé la musique coupée derrière lui.
	var audio: Node = root.get_node_or_null(^"/root/AudioManager")
	if audio != null:
		_check("le silence sec se déclare terminé un jour",
			audio.has_method("silence_sec"))
	_ui.hide_game_over()
	await process_frame

	# V3.6 : le score prend la couleur de qui vient de marquer, puis revient.
	#
	# Lu SANS laisser passer de frame : la teinte est une valeur de départ, et le
	# fondu vers le blanc commence dès la frame suivante. Attendre ici mesurerait
	# le fondu, pas l'annonce — et l'assertion dépendrait de la charge de la
	# machine, défaut consigné le même jour.
	_ui.show_game_over(0)
	_check("le score s'annonce dans la couleur du gagnant",
		_ui.game_over_score.modulate.is_equal_approx(_ui.COLOR_P1),
		str(_ui.game_over_score.modulate))
	_ui.hide_game_over()

	_ui.show_game_over(1)
	_check("et dans celle de l'autre joueur quand c'est lui",
		_ui.game_over_score.modulate.is_equal_approx(_ui.COLOR_P2),
		str(_ui.game_over_score.modulate))
	# Une égalité ne teinte personne : il n'y a personne à teinter.
	_ui.hide_game_over()
	_ui.show_game_over(-1)
	_check("une égalité ne colore le score pour personne",
		_ui.game_over_score.modulate.is_equal_approx(_ui.COLOR_DIM),
		str(_ui.game_over_score.modulate))

	# Et ce qui compte le plus : refermer l'écran rend au libellé sa teinte de
	# repos. Sans ça l'annonce survit, se bat avec la suivante, et le score reste
	# aux couleurs du vainqueur précédent — trouvé par cette suite, pas à la
	# lecture.
	_ui.hide_game_over()
	await process_frame
	_check("refermer rend au score sa teinte de repos",
		_ui.game_over_score.modulate.is_equal_approx(Color.WHITE),
		str(_ui.game_over_score.modulate))

## V6.1 — la bande de la killcam souffre pendant le ralenti.
func _test_tension_killcam() -> void:
	print("\n[La tension de la bande]")
	# À vitesse normale, l'image doit être EXACTEMENT celle d'avant l'effet :
	# une killcam d'après-impact qui grésillerait un peu plus qu'hier serait une
	# régression que personne ne saurait nommer.
	_check("à vitesse normale, aucune tension",
		is_zero_approx(_ui.tension_killcam(1.0)))
	# 1 − 0,005 = 0,995 : la première version de ce contrôle attendait 1,0 rond et
	# tombait. C'est l'attente qui était fausse, pas la courbe — l'échelle de
	# ralenti la plus forte du jeu vaut 0,005, jamais zéro.
	_check("au plus fort du ralenti, tension quasi pleine",
		_ui.tension_killcam(0.005) > 0.99,
		str(_ui.tension_killcam(0.005)))
	_check("elle monte quand le temps ralentit",
		_ui.tension_killcam(0.2) > _ui.tension_killcam(0.8))
	# Bornée des deux côtés : un `time_scale` supérieur à 1 (accéléré) ou négatif
	# ne doit pas produire une tension hors de [0, 1] et détruire l'image.
	_check("elle reste bornée",
		_ui.tension_killcam(2.0) == 0.0 and _ui.tension_killcam(-5.0) == 1.0)

## V6.5 — deux images de négatif au franchissement de l'impact.
##
## Ce qui se vérifie ici est le **rearmement**, pas l'effet. Le déclenchement se
## fait au franchissement d'une image de rejeu : si l'état n'était pas remis à
## neuf, la seconde killcam de la partie trouverait le seuil déjà dépassé et
## **ne clignerait jamais**. Le premier kill serait parfait, tous les suivants
## muets — un défaut qui ne se voit qu'à la deuxième mort.
func _test_negatif_killcam() -> void:
	print("\n[Le négatif se réarme à chaque killcam]")
	_ui._killcam_derniere_image = 400
	_ui._killcam_negatif = 0
	_ui._killcam_tension = 0.9
	_ui.show_killcam()
	_check("l'image de rejeu repart d'avant tout impact",
		_ui._killcam_derniere_image < 0, str(_ui._killcam_derniere_image))
	_check("la tension repart de zéro", is_zero_approx(_ui._killcam_tension))
	_check("aucun négatif en attente", _ui._killcam_negatif == 0)
	_ui.hide_killcam()

## Décision d'Adrien du 2026-08-19 : **en ligne, on ne voit plus le HUD de
## l'adversaire**, et le panneau du joueur local passe à gauche.
##
## Ce que ça retirait : ses points de vie, et surtout **son cercle de recharge** —
## l'instant exact où son arme redevient prête. Dans un jeu dont la règle est
## « la seule information est la lumière », c'était un renseignement gratuit.
##
## Les trois propriétés se vérifient ensemble parce qu'elles peuvent se contredire :
## cacher le bon panneau **et** le mettre à gauche **et** garder les deux en écran
## partagé. Vérifier l'une sans les autres laisserait passer un panneau caché du
## mauvais côté, ou un écran partagé amputé de moitié.
func _test_disposition_hud() -> void:
	print("\n[Qui voit quel HUD, et de quel côté]")
	# `NetworkManager` par le NŒUD et non par son nom : en mode `--script` le nom
	# d'autoload ne résout pas à la compilation, et le fichier entier cesse de se
	# charger. Piège consigné, rencontré une fois de plus ici.
	var reseau: Node = root.get_node_or_null(^"/root/NetworkManager")
	if reseau == null:
		_check("NetworkManager est joignable", false)
		return
	var mode_avant = reseau.current_mode

	reseau.current_mode = reseau.GameMode.LOCAL_SPLITSCREEN
	_ui.disposer_hud()
	_check("écran partagé : les deux panneaux restent",
		_ui.hud_panneau_p1.visible and _ui.hud_panneau_p2.visible)
	_check("écran partagé : J1 reste à gauche",
		_ui.hud_rangee.get_child(0) == _ui.hud_panneau_p1)

	reseau.current_mode = reseau.GameMode.ONLINE_HOST
	_ui.disposer_hud()
	_check("hôte : le panneau adverse disparaît", not _ui.hud_panneau_p2.visible)
	_check("hôte : le sien reste visible", _ui.hud_panneau_p1.visible)
	_check("hôte : et il est à gauche",
		_ui.hud_rangee.get_child(0) == _ui.hud_panneau_p1)

	reseau.current_mode = reseau.GameMode.ONLINE_CLIENT
	_ui.disposer_hud()
	_check("client : le panneau adverse disparaît", not _ui.hud_panneau_p1.visible)
	_check("client : le sien reste visible", _ui.hud_panneau_p2.visible)
	# LE point de la décision : le client est disposé comme l'hôte.
	_check("client : son panneau passe à GAUCHE",
		_ui.hud_rangee.get_child(0) == _ui.hud_panneau_p2)
	_check("client : et il s'aligne à gauche, pas au milieu",
		_ui.hud_panneau_p2.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN)

	# Retour en écran partagé : rien ne doit rester déplacé.
	reseau.current_mode = reseau.GameMode.LOCAL_SPLITSCREEN
	_ui.disposer_hud()
	_check("retour en écran partagé : J1 retrouve la gauche",
		_ui.hud_rangee.get_child(0) == _ui.hud_panneau_p1)
	_check("retour en écran partagé : J2 retrouve la droite",
		_ui.hud_panneau_p2.size_flags_horizontal == Control.SIZE_SHRINK_END)
	reseau.current_mode = mode_avant
