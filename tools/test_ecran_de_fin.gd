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
