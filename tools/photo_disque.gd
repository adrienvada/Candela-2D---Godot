extends "res://tools/photo_ecart.gd"

## LE DISQUE VIOLACÉ DE L'ÉCRAN SCINDÉ — l'enquête. Héritière de `photo_ecart.gd` : elle en garde toute la mise en scène
## (`--scenes=equite` : l'écran scindé, J1 et J2 symétriques par le centre du Cloître, lacet 45° B) et remplace la seule
## prise de la scène `equite` par une enquête, sans rien changer au jeu :
##   1. la dérive — six prises, jeu EN MARCHE, espacées de 20 images : le disque bouge-t-il d'une image à l'autre ?
##   2. l'élimination — jeu en pause, une descente dans l'arbre : à chaque niveau, on cache un à un les enfants qui
##      dessinent (CanvasItem, CanvasLayer, Node3D), on reprend l'image, et on descend dans celui dont l'absence éteint
##      le disque. Le dernier nœud trouvé est celui qui le dessine.
## Le disque se compte dans le jeu même (`_compter`) : pixels « violacés » faibles (R ≥ V + 2, B ≥ V + 2, 8 ≤ max < 60),
## une case sur trois, moitié de J1 et moitié de J2 séparément.
##
##     XDG_DATA_HOME=$PWD/.xdg xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_disque.tscn -- --no-eos --led-murs-fige --sortie=user://disque/enquete --scenes=equite
##
## `--profondeur-max=N` borne la descente ; `--sans-descente` ne fait que la dérive.

const PAS := 3
## Sous cette fraction du compte de référence, le disque est tenu pour éteint.
const ETEINT := 0.15

var _reference := 0
var _essais := 0


func _geler_et_prendre(nom: String, source: String, sans_corps := false) -> void:
	if nom != "equite":
		await super(nom, source, sans_corps)
		return
	if OS.get_cmdline_user_args().has("--prises"):
		await _prises()
	else:
		await _enquete()


## `--prises` : les images avant/après, sans enquête. `equite` telle que la prend `photo_ecart.gd` (jeu gelé), puis
## `eblouis` : l'éblouissement LÉGITIME — J1 et J2 face à face sur la rangée 7 du Cloître (dégagée d'un mur à l'autre),
## à 5 cases (175 px : la torche cesse d'éblouir vers 400 px, `Eblouissement.intensite_proximite`), miroir gauche-droite
## l'un de l'autre, chacun dans le faisceau de l'autre. Aucune position symétrique par le CENTRE ne
## se voit : le pilier central coupe toutes les droites qui y passent.
func _prises() -> void:
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	var img: Image = await _capturer("ecran")
	_ecrire_prise(img, "equite")
	var c := _compter(img)
	print("PRISE_MESURE equite j1=%d j2=%d dazzle_j1=%.3f dazzle_j2=%.3f" % [c.x, c.y,
		float(_main.p1.dazzle_amount), float(_main.p2.dazzle_amount)])
	get_tree().paused = false
	var t := float(CandelaTileSet.TILE_SIZE.x)
	_poser(Vector2(12.5 * t, 7.5 * t), Vector2.RIGHT, Vector2(17.5 * t, 7.5 * t), Vector2.LEFT)
	for i in REPOS_IMAGES:
		_tenir()
		await get_tree().process_frame
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	var img2: Image = await _capturer("ecran")
	_ecrire_prise(img2, "eblouis")
	var c2 := _compter(img2)
	print("PRISE_MESURE eblouis j1=%d j2=%d dazzle_j1=%.3f dazzle_j2=%.3f voile_j1=%s voile_j2=%s" % [c2.x, c2.y,
		float(_main.p1.dazzle_amount), float(_main.p2.dazzle_amount),
		str(_ui.p1_dazzle.visible), str(_ui.p2_dazzle.visible)])
	get_tree().paused = false


func _enquete() -> void:
	var args := OS.get_cmdline_user_args()
	print("=== ENQUÊTE disque violacé ===")
	# 1. La dérive, jeu en marche.
	for i in 6:
		for k in 20:
			_tenir()
			await get_tree().process_frame
		var img: Image = await _capturer("ecran")
		var c := _compter(img)
		_ecrire_prise(img, "derive_%d" % i)
		print("DERIVE %d j1=%d j2=%d centre_j1=%s dazzle_j1=%.3f dazzle_j2=%.3f" % [i, c.x, c.y,
			str(_centre(img)), float(_main.p1.dazzle_amount), float(_main.p2.dazzle_amount)])
	if args.has("--sans-descente"):
		return
	# 2. L'élimination, jeu en pause.
	_tenir()
	get_tree().paused = true
	var iso := Presentation3D.instance()
	var suivait := iso != null and iso.is_processing()
	if iso != null:
		iso.set_process(false)
	await _attendre_images(3)
	var img0: Image = await _capturer("ecran")
	_ecrire_prise(img0, "reference")
	_reference = _compter(img0).x
	print("REFERENCE j1=%d j2=%d" % [_reference, _compter(img0).y])
	var suspect := _valeur(args, "--suspect", "")
	if suspect != "":
		var n := get_node_or_null(NodePath(suspect))
		if n == null:
			printerr("✗ suspect introuvable : %s" % suspect)
		else:
			var reste := await _essayer([n], n)
			print("SUSPECT %s caché → j1=%d (référence %d)" % [suspect, reste, _reference])
			_decrire(n)
			# La teinte : la même flaque en rouge pur, pour voir ce que la chaîne de rendu fait de la couleur posée.
			var cibles: Dictionary = n.get("_cibles") if "_cibles" in n else {}
			for j in cibles.keys():
				print("  teinte posée J%d : %s" % [j + 1, str(cibles[j]["teinte"])])
			for essai_teinte in [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]:
				for j in cibles.keys():
					cibles[j]["teinte"] = essai_teinte
				n.queue_redraw()
				await _attendre_images(3)
				var im: Image = await _capturer("ecran")
				var ctr := _centre(img0)
				if ctr != Vector2.INF:
					var px := im.get_pixelv(Vector2i(ctr))
					var p0 := img0.get_pixelv(Vector2i(ctr))
					print("  teinte %s → pixel au centre %d,%d,%d (référence %d,%d,%d)" % [str(essai_teinte),
						px.r8, px.g8, px.b8, p0.r8, p0.g8, p0.b8])
	elif _reference < 30:
		printerr("✗ pas de disque à la référence : rien à chercher")
	else:
		var noeud: Node = get_tree().root
		var chemin: Array[String] = []
		var prof_max := int(_valeur(args, "--profondeur-max", "40"))
		for prof in prof_max:
			var coupable: Node = null
			for enfant in noeud.get_children(true):
				if not _cachable(enfant) and enfant.get_child_count(true) == 0:
					continue
				if not _cachable(enfant):
					# Un Viewport, un Node nu : on regarde s'il contient le coupable en cachant tous ses enfants cachables.
					var sous := _descendants_cachables(enfant)
					if sous.is_empty():
						continue
					var n := await _essayer(sous, enfant)
					if n < _reference * ETEINT:
						coupable = enfant
						break
					continue
				var n2 := await _essayer([enfant], enfant)
				if n2 < _reference * ETEINT:
					coupable = enfant
					break
			if coupable == null:
				print("COUPABLE (feuille de la descente) : %s" % str(noeud.get_path()))
				_decrire(noeud)
				break
			chemin.append(String(coupable.name))
			noeud = coupable
		print("CHEMIN : %s" % " > ".join(chemin))
	if iso != null:
		iso.set_process(suivait)
	get_tree().paused = false


func _cachable(n: Node) -> bool:
	return n is CanvasItem or n is CanvasLayer or n is Node3D


## Les premiers nœuds cachables sous `n` (sans descendre sous un nœud cachable).
func _descendants_cachables(n: Node) -> Array:
	var sortie: Array = []
	for e in n.get_children(true):
		if _cachable(e):
			if bool(e.get("visible")):
				sortie.append(e)
		else:
			sortie.append_array(_descendants_cachables(e))
	return sortie


func _essayer(noeuds: Array, pour: Node) -> int:
	var caches: Array = []
	for n in noeuds:
		if _cachable(n) and bool(n.get("visible")):
			n.set("visible", false)
			caches.append(n)
	if caches.is_empty():
		return _reference
	await _attendre_images(3)
	var img: Image = await _capturer("ecran")
	for n in caches:
		n.set("visible", true)
	var c := _compter(img)
	_essais += 1
	print("ESSAI %d %s (%s, %d caché(s)) → j1=%d j2=%d" % [_essais, str(pour.get_path()), pour.get_class(),
		caches.size(), c.x, c.y])
	if c.x < _reference * ETEINT:
		_ecrire_prise(img, "eteint_%d" % _essais)
	return c.x


func _decrire(n: Node) -> void:
	print("  classe : %s · script : %s" % [n.get_class(), str(n.get_script().resource_path) if n.get_script() else "—"])
	for p in ["visible", "global_position", "position", "z_index", "light_mask", "visibility_layer", "range_item_cull_mask",
			"color", "energy", "texture_scale", "blend_mode", "layers", "cull_mask", "light_color", "light_energy",
			"omni_range", "light_cull_mask", "modulate", "self_modulate", "size", "material", "material_override"]:
		if p in n:
			print("  %s = %s" % [p, str(n.get(p))])
	# Les variables du script, telles qu'au moment de la prise.
	for p in n.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			print("  [script] %s = %s" % [p["name"], str(n.get(p["name"]))])
	if n is CanvasItem:
		print("  visible_dans_l_arbre = %s · top_level = %s · process = %s" % [str((n as CanvasItem).is_visible_in_tree()),
			str((n as CanvasItem).top_level), str(n.is_processing())])
	for f in ["p1_focus", "p2_focus"]:
		var c: Variant = _ui.get(f)
		if c is Control and is_instance_valid(c):
			print("  UI.%s = %s · rect %s · centre %s · visible %s" % [f, str((c as Control).get_path()),
				str((c as Control).get_global_rect()), str((c as Control).get_global_rect().get_center()),
				str((c as Control).is_visible_in_tree())])
	print("  souris : %s" % str(get_viewport().get_mouse_position()))
	# Quel contrôle a son centre sous la flaque : le dernier bouton visé avant la manche.
	var positions: Dictionary = n.get("_positions") if "_positions" in n else {}
	for j in positions.keys():
		for c in _ui.find_children("*", "Control", true, false):
			var r := (c as Control).get_global_rect()
			if r.size.x > 4.0 and r.get_center().distance_to(positions[j]) < 1.5:
				var texte := str(c.get("text")) if "text" in c else ""
				print("  sous la flaque J%d : %s · rect %s · « %s » · visible %s" % [j + 1, str(c.get_path()), str(r),
					texte, str((c as Control).is_visible_in_tree())])
	if n.get("material") is ShaderMaterial:
		var m: ShaderMaterial = n.get("material")
		print("  shader : %s" % m.shader.resource_path)
		for u in m.shader.get_shader_uniform_list():
			print("    %s = %s" % [u["name"], str(m.get_shader_parameter(u["name"]))])


## Pixels violacés faibles : x = moitié de J1, y = moitié de J2.
func _compter(img: Image) -> Vector2i:
	if img == null:
		return Vector2i(-1, -1)
	var w := img.get_width()
	var h := img.get_height()
	var j1 := 0
	var j2 := 0
	for y in range(0, h, PAS):
		for x in range(0, w, PAS):
			var c := img.get_pixel(x, y)
			var r := int(c.r8)
			var g := int(c.g8)
			var b := int(c.b8)
			var m := maxi(r, maxi(g, b))
			if r - g >= 2 and b - g >= 2 and m >= 8 and m < 60:
				if x < w / 2:
					j1 += 1
				else:
					j2 += 1
	return Vector2i(j1, j2)


func _centre(img: Image) -> Vector2:
	if img == null:
		return Vector2.INF
	var s := Vector2.ZERO
	var n := 0
	for y in range(0, img.get_height(), PAS):
		for x in range(0, img.get_width() / 2, PAS):
			var c := img.get_pixel(x, y)
			var m := maxi(c.r8, maxi(c.g8, c.b8))
			if c.r8 - c.g8 >= 2 and c.b8 - c.g8 >= 2 and m >= 8 and m < 60:
				s += Vector2(x, y)
				n += 1
	return s / n if n > 0 else Vector2.INF
