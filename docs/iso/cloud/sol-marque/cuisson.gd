## Le sol marqué — la preuve « éteint : rien ne change au bit ».
##
## Cuit le décor de chaque carte livrée (`ArenaDecor.build`, la cuisson dans un SubViewport, comme en jeu) et imprime
## l'empreinte md5 des texels de la texture cuite, carte par carte. Lancé sur cette branche SANS le drapeau, puis sur la
## base (f4039a0) : les empreintes doivent être identiques — c'est la seule texture que l'essai touche. Avec
## `--sol-marque-essai`, elles changent (le témoin que la preuve voit quelque chose).
##
## Il EXIGE une vraie fenêtre (la cuisson ne rastérise rien en headless) :
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --script res://docs/iso/cloud/sol-marque/cuisson.gd \
##         [-- --sol-marque-essai] [-- --sortie=/chemin]   # --sortie : écrit aussi les textures en PNG
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sortie := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	var fichiers := Array(DirAccess.get_files_at("res://assets/maps")).filter(func(f): return String(f).ends_with(".json"))
	fichiers.sort()
	var echecs := 0
	for f in fichiers:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
		if not (d is Dictionary):
			continue
		var parent := Node2D.new()
		root.add_child(parent)
		var decor = (load("res://arena_decor.gd") as GDScript).call("build", d, parent)
		var cuit: Texture2D = null
		for i in 60:
			await process_frame
			cuit = decor.get("_cuit")
			if cuit != null:
				break
		if cuit == null:
			printerr("CUISSON %s : jamais cuite" % f)
			echecs += 1
		else:
			var img := cuit.get_image()
			var h := HashingContext.new()
			h.start(HashingContext.HASH_MD5)
			h.update(img.get_data())
			print("CUISSON %s %dx%d %s md5 %s" % [f, img.get_width(), img.get_height(), img.get_format(), h.finish().hex_encode()])
			if sortie != "":
				img.save_png(sortie.path_join(String(f).get_basename() + ".png"))
		parent.queue_free()
		await process_frame
	quit(1 if echecs > 0 else 0)
