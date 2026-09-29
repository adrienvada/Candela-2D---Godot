extends SceneTree

## Q54 — le clic à vide s'entend chez l'adversaire (Adrien, 2026-09-29 : « oui on le
## rend audible »), et son RETOUR reste à celui qui a pressé.
## Lancer : godot --headless --path . --script res://tools/test_clic_a_vide.gd
##
## Ce qu'elle garde, en mode hôte (sans pair réel : le pair hors ligne de Godot) :
## - le joueur du client, que l'hôte simule, fait entendre son clic chez l'hôte ;
##   l'hôte ne fait PAS trembler sa cartouche (`tir_a_sec`) : le tremblement se voit
##   hors de portée d'oreille, il apprendrait l'essai à l'hôte ;
## - un second appui dans les 220 ms ne claque pas deux fois ;
## - le joueur de l'hôte fait entendre le sien ET reçoit son retour.
## Le relais de l'hôte vers le client (S6) est gardé par `test_son_visible_jeu`.

var _failures := 0
var _recus: Array[Dictionary] = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _noter(evenement: Dictionary) -> void:
	_recus.append(evenement)


func _clics(emetteur: int) -> int:
	var n := 0
	for ev in _recus:
		if String(ev.get("famille", "")) == "weapon_dry" and int(ev.get("emetteur", -9)) == emetteur:
			n += 1
	return n


func _joueur(id: int) -> Node:
	var p: Node = load("res://player.tscn").instantiate()
	p.name = "Joueur%d" % id
	p.set("player_id", id)
	var fournisseur := NetworkInputProvider.new()
	fournisseur.name = "Entrees"
	p.add_child(fournisseur)
	p.set("input_provider", fournisseur)
	p.set("global_position", Vector2(200 + 400 * id, 300))
	root.add_child(p)
	return p


func _presser(p: Node, presse: bool) -> void:
	(p.get("input_provider") as NetworkInputProvider).update_input_state(
		Vector2.ZERO, Vector2.RIGHT, presse, false, false)


func _run() -> void:
	print("=== Q54 : le clic à vide s'entend chez l'adversaire ===")
	await process_frame
	var reseau := root.get_node("NetworkManager")
	var audio := root.get_node("AudioManager")
	var modes: Dictionary = reseau.get_script().get_script_constant_map()["GameMode"]
	var avant: int = reseau.current_mode
	reseau.current_mode = int(modes["ONLINE_HOST"])
	audio.son_localise.connect(_noter)
	var p1 := _joueur(0)
	var p2 := _joueur(1)
	await physics_frame
	await physics_frame

	# Le joueur du client, simulé chez l'hôte, presse à vide.
	p2.set("current_ammo", 0)
	_recus.clear()
	_presser(p2, true)
	for i in 3:
		await physics_frame
	_check("chez l'hôte, le clic à vide du client s'entend (et se voit)", _clics(1) == 1, str(_clics(1)))
	_check("… sans faire trembler SA cartouche chez l'hôte", is_zero_approx(float(p2.get("tir_a_sec"))),
		str(p2.get("tir_a_sec")))
	# Relâché puis repressé aussitôt : la fenêtre de 220 ms tient.
	_presser(p2, false)
	await physics_frame
	_presser(p2, true)
	await physics_frame
	_check("un second appui dans les 220 ms ne claque pas deux fois", _clics(1) == 1, str(_clics(1)))

	# Le joueur de l'hôte presse à vide : il s'entend, et son retour est le sien.
	p1.set("current_ammo", 0)
	_recus.clear()
	_presser(p1, true)
	for i in 3:
		await physics_frame
	_check("le clic à vide du joueur de l'hôte s'entend", _clics(0) == 1, str(_clics(0)))
	_check("… et son retour (la cartouche qui tremble) reste le sien", float(p1.get("tir_a_sec")) > 0.0)

	audio.son_localise.disconnect(_noter)
	reseau.current_mode = avant
	p1.queue_free()
	p2.queue_free()
	await process_frame
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
