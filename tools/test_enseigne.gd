extends SceneTree

## DA7.8 — l'enseigne qui s'éteint.
##
## Quatre défauts sont possibles ici, et **aucun ne se voit en jouant** : il
## faudrait rester une minute devant le menu sans bouger, puis recommencer.
##
## 1. **Elle descend à zéro.** Le logo disparaît, et ça se lit comme une panne.
## 2. **Elle ne se rallume pas**, ou pas à fond : le joueur revient devant un
##    menu à moitié éteint sans savoir pourquoi.
## 3. **Elle meurt pendant qu'on lit le menu**, parce que le mouvement de souris
##    n'aurait pas compté comme un geste.
## 4. **Elle relâche une enseigne à mi-extinction** : le verdict de fin de match
##    s'afficherait à moitié transparent.

const Enseigne := preload("res://enseigne_qui_meurt.gd")

var _echecs := 0

func _init() -> void:
	print("=== TestEnseigne ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await _test_cycle_complet()
	await _test_reveil_souris()
	await _test_relachement()
	await _test_cachee_ne_vieillit_pas()
	if _echecs == 0:
		print("✓ Tous les tests de l'enseigne passent")
	else:
		printerr("✗ %d échec(s) dans TestEnseigne" % _echecs)
	quit(1 if _echecs > 0 else 0)

func _check(libelle: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ %s" % libelle)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [libelle, "" if detail == "" else " — " + detail])

func _monter() -> Array:
	var cible := ColorRect.new()
	cible.name = "EnseigneFactice"
	root.add_child(cible)
	var veilleur: Node = Enseigne.new()
	root.add_child(veilleur)
	veilleur.surveiller(cible)
	return [veilleur, cible]

func _demonter(veilleur: Node, cible: Node) -> void:
	root.remove_child(veilleur); veilleur.free()
	root.remove_child(cible); cible.free()

## Fait tourner le temps par pas fins : les états s'enchaînent dans `_process`,
## et un seul grand pas les sauterait.
func _avancer(veilleur: Node, secondes: float, pas: float = 0.05) -> void:
	var reste := secondes
	while reste > 0.0:
		veilleur._process(minf(pas, reste))
		reste -= pas

func _test_cycle_complet() -> void:
	var m := _monter()
	var v: Node = m[0]
	var c: CanvasItem = m[1]

	_check("pleine lumière au départ", is_equal_approx(c.self_modulate.a, 1.0),
		"alpha %.3f" % c.self_modulate.a)

	_avancer(v, Enseigne.SEUIL_VEILLE - 1.0)
	_check("intacte juste avant le seuil de veille", not v.est_entamee())

	_avancer(v, 2.0)
	_check("elle bat après le seuil de veille", v.est_entamee())

	# Jusqu'au bout : veille, sursaut, extinction.
	_avancer(v, (Enseigne.SEUIL_AGONIE - Enseigne.SEUIL_VEILLE)
		+ Enseigne.DUREE_SURSAUT + Enseigne.DUREE_EXTINCTION + 1.0)
	_check("elle finit sur la braise",
		is_equal_approx(v.luminosite(), Enseigne.BRAISE),
		"luminosité %.3f" % v.luminosite())
	# LE contrôle qui compte : jamais éteinte pour de bon.
	_check("elle ne descend JAMAIS à zéro", v.luminosite() > 0.0)
	_check("la braise reste trouvable", v.luminosite() >= 0.05,
		"%.3f — en dessous, le logo passe pour absent" % v.luminosite())

	# Le rallumage doit ABOUTIR, et pas s'arrêter à mi-chemin.
	var touche := InputEventKey.new()
	touche.keycode = KEY_SPACE
	touche.pressed = true
	v._input(touche)
	_avancer(v, Enseigne.DUREE_RALLUMAGE + 0.3)
	_check("elle se rallume à FOND", is_equal_approx(v.luminosite(), 1.0),
		"luminosité %.3f" % v.luminosite())
	_check("et l'alpha de la cible suit", is_equal_approx(c.self_modulate.a, 1.0),
		"alpha %.3f" % c.self_modulate.a)
	_check("jamais au-dessus de 1", v.luminosite() <= 1.0)

	_demonter(v, c)
	await process_frame

func _test_reveil_souris() -> void:
	var m := _monter()
	var v: Node = m[0]
	var c: CanvasItem = m[1]
	_avancer(v, Enseigne.SEUIL_VEILLE + 2.0)
	_check("entamée avant le geste", v.est_entamee())
	# Le cas réel : on LIT le menu, la souris à la main. Ça doit compter.
	var bouge := InputEventMouseMotion.new()
	bouge.position = Vector2(10, 10)
	v._input(bouge)
	_avancer(v, 0.1)
	_check("un mouvement de souris la réveille", not v.est_entamee())
	_demonter(v, c)
	await process_frame

func _test_relachement() -> void:
	var m := _monter()
	var v: Node = m[0]
	var c: CanvasItem = m[1]
	_avancer(v, Enseigne.SEUIL_AGONIE + Enseigne.DUREE_SURSAUT + 1.0)
	_check("l'alpha a bien baissé avant le relâchement", c.self_modulate.a < 1.0,
		"alpha %.3f" % c.self_modulate.a)
	v.surveiller(null)
	_check("relâcher rend la pleine lumière", is_equal_approx(c.self_modulate.a, 1.0),
		"alpha %.3f — un verdict s'afficherait à moitié transparent" % c.self_modulate.a)
	_demonter(v, c)
	await process_frame

func _test_cachee_ne_vieillit_pas() -> void:
	var m := _monter()
	var v: Node = m[0]
	var c: CanvasItem = m[1]
	c.visible = false
	_avancer(v, Enseigne.SEUIL_AGONIE + 10.0)
	_check("une enseigne cachée ne meurt pas", not v.est_entamee())
	_demonter(v, c)
	await process_frame
