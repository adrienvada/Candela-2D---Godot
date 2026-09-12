extends Node2D

## L'APERÇU DES PETITES TRACES — empreintes, douilles, cible, nappe de braises.
##
## Le photographe ne les montre pas : aucun plan ne fait marcher un joueur, et
## une douille fait cinq pixels. Cet aperçu les pose sur un fond gris uni, sans
## lumière ni `CanvasModulate`, à un grossissement de 6, et écrit UNE image :
## à gauche l'ancien dessin (reproduit ici tel qu'il était, ellipse et disques
## sans trait), à droite le dessin d'encre du lot 5 et la nappe du lot 6.
##
## ⚠️ Exige une VRAIE fenêtre, comme le photographe (`frame_post_draw`).
##
##     godot --path . res://tools/apercu_traces.tscn -- --sortie=/chemin/apercu.png
##
## Une SCÈNE et non un `--script` : en mode script, ni la fenêtre ni un
## SubViewport ne rastérisent (image noire, constaté), c'est le patron du
## photographe qui vaut.

const Charte := preload("res://charte.gd")
const FootprintScript := preload("res://footprint.gd")
const CasingScript := preload("res://bullet_casing.gd")
const CibleScript := preload("res://training_target_visual.gd")

const GROSSISSEMENT := 6.0


## L'ancien dessin, reproduit : l'ellipse de l'empreinte et les trois disques.
class Ancien extends Node2D:
	const Charte := preload("res://charte.gd")
	func _draw() -> void:
		# Empreinte : ellipse de douze sommets, 10 × 4.
		var pts := PackedVector2Array()
		for i in 12:
			var a := TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * 5.0, sin(a) * 2.0))
		for k in 3:
			var d := Vector2(-40.0 + 14.0 * k, -68.0 + (5.0 if k % 2 == 0 else -5.0))
			draw_set_transform(d, 0.35)
			draw_colored_polygon(pts, Color(Charte.SOL_A * 0.6, 0.55))
		draw_set_transform(Vector2.ZERO)
		# Cible : trois disques.
		var c := Vector2(-20.0, -8.0)
		draw_circle(c, 22.0, Charte.ACIER * 0.72)
		draw_circle(c, 22.0 * 0.66, Charte.ACIER)
		draw_circle(c, 22.0 * 0.33, Charte.ROUGE)
		# Douille de pistolet : aplats et reflet.
		draw_set_transform(Vector2(-45.0, -42.0), 0.6)
		draw_rect(Rect2(-1.8, -0.9, 0.6, 1.8), Charte.LINE)
		draw_rect(Rect2(-1.2, -0.9, 3.0, 1.8), Charte.AMBRE)
		draw_line(Vector2(-1.2, -0.6), Vector2(1.8, -0.6), Charte.HALOGENE * 0.85, 0.5)
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	var sortie := "user://apercu_traces.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
	# Dans un SubViewport, comme le photographe : la texture de la fenêtre
	# elle-même n'est pas lisible sous gl_compatibility (image noire).
	var vue := SubViewport.new()
	vue.size = Vector2i(1920, 1080)
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(vue)
	var scene := Node2D.new()
	vue.add_child(scene)
	var fond := Polygon2D.new()
	fond.polygon = PackedVector2Array([Vector2(-400, -200), Vector2(400, -200),
		Vector2(400, 200), Vector2(-400, 200)])
	fond.color = Charte.SOL_B
	fond.visibility_layer = 2
	scene.add_child(fond)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * GROSSISSEMENT
	scene.add_child(cam)
	cam.make_current()

	# À gauche : l'ancien.
	var ancien := Ancien.new()
	ancien.position = Vector2(-45.0, 0.0)
	ancien.visibility_layer = 2
	scene.add_child(ancien)

	# À droite : le nouveau, par les vrais scripts.
	var arene := Node2D.new()
	arene.position = Vector2(60.0, 0.0)
	scene.add_child(arene)
	for k in 3:
		FootprintScript.spawn(arene, Vector2(-40.0 + 14.0 * k, -68.0 + (5.0 if k % 2 == 0 else -5.0)), 0.35, 1 if k % 2 == 0 else -1)
	var cible := CibleScript.new()
	cible.position = Vector2(-20.0, -8.0)
	cible.visibility_layer = 2
	arene.add_child(cible)
	var d := 0
	for slug in ["pistolet", "fusil", "pompe"]:
		var c = CasingScript.eject(arene, Vector2(-48.0 + 8.0 * d, -42.0), Vector2.RIGHT, slug)
		c.velocity = Vector2.ZERO
		c.angular_velocity = 0.0
		c.rotation = 0.6
		c.at_rest = true
		c.set_process(false)
		d += 1
	# La nappe de braises : source à gauche, encrée à droite, à leur taille.
	for paire in [["res://assets/sources/encre/gadget_nappe_braises_source.png", Vector2(-125.0, 52.0)],
			["res://assets/sprites/gadget_nappe_braises.png", Vector2(-20.0, 52.0)]]:
		if ResourceLoader.exists(paire[0]):
			var s := Sprite2D.new()
			s.texture = load(paire[0])
			s.scale = Vector2.ONE * (60.0 / float(s.texture.get_width()))
			s.position = paire[1] + Vector2(60.0, 0.0)
			s.visibility_layer = 2
			scene.add_child(s)

	for i in 4:
		await get_tree().process_frame
	# Les copies J2 des empreintes et des douilles se superposent à l'original :
	# on les retire plutôt que de filtrer par masque de vue.
	for grp in ["footprint_p2", "casing_p2"]:
		for n in get_tree().get_nodes_in_group(grp):
			n.free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vue.get_texture().get_image()
	img.save_png(sortie)
	print("aperçu écrit : ", ProjectSettings.globalize_path(sortie))
	get_tree().quit(0)
