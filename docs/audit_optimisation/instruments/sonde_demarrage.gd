## Scène principale de la « ferme » de démarrage (audit M, étape 3) — INSTRUMENT TEMPORAIRE, jamais commité.
##
## Les autoloads sont enveloppés (voir `faire_ferme.py`) : chacun imprime `[AL] init <nom> <µs>` et `[AL] ready <nom> <µs>` sur
## l'horloge du moteur (µs depuis le démarrage du processus). Cette scène imprime ensuite ses propres jalons, charge la scène principale
## du jeu en trois temps (load, instantiate, add_child = tous les `_ready` en cascade) et date les premières images.
extends Node

const IMAGES := 150


func _ready() -> void:
	var t_pret := Time.get_ticks_usec()
	print("[AL] scene_sonde_ready %d" % t_pret)
	# --scripts=a.gd,b.gd : le coût INCRÉMENTAL du chargement de chacun (compilation + dépendances encore non chargées), dans cet ordre.
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--scripts="):
			for chemin in String(a).substr(10).split(","):
				var ts := Time.get_ticks_usec()
				var _r: Resource = ResourceLoader.load("res://" + String(chemin))
				print("[AL] script %s %d" % [chemin, Time.get_ticks_usec() - ts])
	var t0 := Time.get_ticks_usec()
	var ps: PackedScene = load("res://main.tscn")
	var t1 := Time.get_ticks_usec()
	var inst := ps.instantiate()
	var t2 := Time.get_ticks_usec()
	add_child(inst)
	var t3 := Time.get_ticks_usec()
	print("[AL] main.tscn load %d" % (t1 - t0))
	print("[AL] main.tscn instantiate %d" % (t2 - t1))
	print("[AL] main.tscn add_child %d" % (t3 - t2))
	var ts: Array[float] = []
	var depart := Time.get_ticks_usec()
	for i in IMAGES:
		var a := Time.get_ticks_usec()
		await get_tree().process_frame
		ts.append((Time.get_ticks_usec() - a) / 1000.0)
	var premieres := ""
	for i in 12:
		premieres += "%.1f " % ts[i]
	var reste := ts.slice(12)
	reste.sort()
	print("[AL] images 1-12 (ms) : %s" % premieres)
	print("[AL] images 13-%d (ms) : médiane %.2f, p99 %.2f, max %.2f" % [IMAGES, reste[reste.size() / 2], reste[int(reste.size() * 0.99)], reste[-1]])
	print("[AL] fin_mesures %d (instant, µs depuis le démarrage du processus)" % Time.get_ticks_usec())
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(0)
	else:
		get_tree().quit(0)
