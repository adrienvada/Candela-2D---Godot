extends SceneTree
## Micro-banc V10 / ISO-03 — le coût du parcours « tous les enfants de l'arène » d'`IsoVolumes.suivre`
## (`iso_volumes.gd:427-429`), contre la lecture d'un groupe vide (`get_nodes_in_group`).
##
## NON LANCÉ par son auteur (consigne : ne pas lancer Godot pendant la mesure de cadence) — à copier dans `tools/` d'un
## arbre jetable et à lancer par l'agent de mesure :
##   Godot_v4.7.1-stable_linux.x86_64 --headless --path <arbre> --script res://tools/micro_onde.gd
## Aucun rendu, aucun GPU, aucune scène du jeu, aucun autoload : un parcours GDScript pur, donc un coût CPU de script.
##
## Les enfants sont des `Node2D` PORTANT UN SCRIPT (comme les douilles, taches et éclats, qui sont des `Node2D` à script) :
## `get_script()` rend alors un vrai `GDScript`, comme dans le jeu. Le « script de l'onde » est un autre `GDScript` jetable.
## Pas de `preload("res://kill_shockwave.gd")` : il tire `charte.gd`, que ce banc n'a aucune raison de charger.
##
## Sortie : une ligne par taille d'arène — µs par image du parcours actuel (médiane de trois passes), de la lecture du
## groupe, et leur rapport. L'écart entre les passes affichées dit le bruit ; la première réchauffe les caches.
## Convention de motif : même gabarit que les suites `--script` du dépôt (`_init` + `call_deferred("_run")`).

const TAILLES := [0, 100, 300, 700]
const APPELS := 3000
const PASSES := 3

var _trouvees := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var script_trace := GDScript.new()
	script_trace.source_code = "extends Node2D\n"
	script_trace.reload()
	var script_onde := GDScript.new()
	script_onde.source_code = "extends Node2D\n"
	script_onde.reload()

	print("[micro_onde] %d appels par passe, %d passes ; chaque nombre est un coût PAR IMAGE, en µs" % [APPELS, PASSES])
	for n: int in TAILLES:
		var arene := Node2D.new()
		arene.name = "ArenaEssai"
		root.add_child(arene)
		for i in n:
			var t := Node2D.new()
			t.set_script(script_trace)
			arene.add_child(t)
		# Une onde de mort, comme celle des 0,4 dernières secondes d'une manche (une seule, ou aucune le reste du temps).
		var onde := Node2D.new()
		onde.set_script(script_onde)
		arene.add_child(onde)

		var parcours: Array[float] = []
		var groupe: Array[float] = []
		for passe in PASSES:
			var t0 := Time.get_ticks_usec()
			for k in APPELS:
				# Le code de `IsoVolumes.suivre`, mot pour mot (hors l'appel de `_suivre_onde`).
				for noeud in arene.get_children():
					if noeud.get_script() == script_onde:
						_trouvees += 1
			parcours.append(float(Time.get_ticks_usec() - t0) / APPELS)
			var t1 := Time.get_ticks_usec()
			for k in APPELS:
				# Le remède proposé : un groupe, vide (le cas de 99,9 % des images).
				for o in get_nodes_in_group("onde_de_mort"):
					_trouvees += 1000000
			groupe.append(float(Time.get_ticks_usec() - t1) / APPELS)
		var med_p := _mediane(parcours)
		var med_g := _mediane(groupe)
		print("[micro_onde] enfants=%4d : parcours actuel %8.2f µs/image (passes %s) | groupe vide %6.3f µs/image | rapport %.0f×"
			% [n + 1, med_p, str(parcours), med_g, med_p / maxf(med_g, 0.001)])
		arene.queue_free()
		await process_frame
	# `_trouvees` n'a servi qu'à empêcher qu'une boucle soit jugée sans effet : une onde par parcours attendue, rien ailleurs.
	print("[micro_onde] trouvées=%d (attendu %d)" % [_trouvees, TAILLES.size() * PASSES * APPELS])
	quit()


static func _mediane(valeurs: Array[float]) -> float:
	var copie: Array[float] = []
	copie.assign(valeurs)
	copie.sort()
	return copie[copie.size() >> 1]
