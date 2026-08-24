extends Node2D

## Comparer les tuiles peintes aux tuiles d'aujourd'hui, dans l'arène, à la
## torche (DA2.6 sols, DA2.7 murs).
##
## ## Pourquoi un banc et pas une planche de contact
##
## **Une tuile de Candela fait 35 pixels.** Les planches générées font 1024² par
## tuile : vingt-neuf fois trop. Une planche de contact montrerait donc un détail
## que le jeu n'affichera jamais — elle ne mentirait pas un peu, elle mentirait
## sur tout. Ce qui compte est ce qui SURVIT à la réduction, et ça ne se juge
## qu'à la taille finale, sur un vrai sol, éclairé par une vraie torche.
##
## Trois propriétés rendent la comparaison honnête :
##
## 1. **Le point de vue ne bouge pas au basculement.** On appuie, la matière
##    change, la caméra reste. L'œil compare la même surface — c'est la seule
##    façon de voir une couture de tuilage ou un motif qui se répète.
## 2. **Deux zooms, dont le 1:1.** Le mode de défaillance à 35 px s'appelle « le
##    détail est devenu de la bouillie », et il ne se voit qu'à l'échelle réelle.
## 3. **La torche s'éteint.** ⚠️ C'est la touche la plus importante du banc, et
##    elle répond à une question de conception, pas de goût : la couche des murs
##    est en **fondu additif**, et une matière peinte à 0,19 de luminance
##    s'ajoute au noir du monde en permanence. Si les murs se voient torche
##    éteinte, **on lit le plan de la carte gratuitement** — et la promesse du
##    jeu, « la seule information est la lumière », tombe.
##
## Touches : **F** sol · **M** mur · **T** torche · **Z** zoom · **R** rotations
## · flèches déplacer · souris viser · Échap quitter.

const Charte := preload("res://charte.gd")

## Les variantes comparées. La première est TOUJOURS ce que le jeu affiche
## aujourd'hui : la question n'est pas « est-ce joli » mais « est-ce mieux que
## ça », et il faut pouvoir y revenir d'une touche.
## Le sol : variante 1 choisie par Adrien le 2026-08-25, déclinée en quatre
## forces de damier. Le damier n'est pas décoratif — dans le noir absolu, c'est
## la seule référence spatiale du joueur — mais Adrien l'a trouvé trop marqué.
const SOLS := ["actuel", "faible"]
## ⚠️ **Le mur n'a plus qu'une entrée, et c'est le résultat d'une mesure.**
## DA2.7 a été essayée puis ABANDONNÉE par Adrien le 2026-08-25 : la matière
## peinte d'un mur porte un écart-type de 0,032 quand son arête halogène en
## porte 0,30. Étirée jusqu'à 0,118, elle devenait visible — mais amplifiait le
## grain de redimensionnement autant que la structure, et n'apportait rien qu'un
## mur noir cerné d'un filament ne donnait déjà. Les tuiles ont été retirées ;
## l'axe reste ici pour que le banc dise ce qui a été essayé.
const MURS := ["actuel"]
const DOSSIER := "res://assets/tuiles/"

const VITESSE := 600.0
## Le zoom du jeu : chaque joueur voit un `SubViewport` de 960 px de large sur
## les 1920 du projet. Juger à zoom 1 montrerait la matière deux fois trop
## petite ; juger à 1:1 montre un pixel de tuile pour un pixel d'écran.
const ZOOM_JEU := 2.0
const ZOOM_PIXEL := 1.0

var _sol: TileMapLayer
var _murs: TileMapLayer
var _porteur: Node2D
var _torche: PointLight2D
var _camera: Camera2D
var _etiquette: Label
var _carte: Dictionary = {}

## Démarre sur le sol RETENU, pas sur l'ancien : le banc sert désormais à
## vérifier ce qui est intégré, plus à choisir.
var _i_sol := 1
var _i_mur := 0
var _torche_allumee := true
var _zoom_pixel := false
var _rotations := true
var _absents: Array[String] = []


func _ready() -> void:
	_monter_arene()
	_monter_porteur()
	_monter_interface()
	_appliquer()


func _monter_arene() -> void:
	_carte = MapData.get_selected()
	if _carte.is_empty():
		push_error("apercu_matiere : aucune carte sélectionnée")
		return

	var mod := CanvasModulate.new()
	mod.color = Charte.NOIR
	add_child(mod)
	RenderingServer.set_default_clear_color(Charte.NOIR)

	_sol = TileMapLayer.new()
	_sol.name = "Sol"
	_sol.z_index = -1
	add_child(_sol)

	_murs = TileMapLayer.new()
	_murs.name = "Murs"
	_murs.z_index = 0
	add_child(_murs)
	# Le fondu additif du jeu, reproduit tel quel : c'est lui qui fait qu'une
	# matière claire sur un mur BRILLE au lieu de se dessiner.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_murs.material = mat

	MapGeometry.build_collisions(_carte, self)


func _monter_porteur() -> void:
	_porteur = Node2D.new()
	_porteur.name = "Porteur"
	add_child(_porteur)

	# Copie conforme de `player.gd`, cookie compris : juger une matière sous une
	# lumière qui n'est pas celle du jeu ne juge rien.
	_torche = PointLight2D.new()
	_torche.name = "Torche"
	_torche.enabled = true
	_torche.shadow_enabled = true
	_torche.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	_torche.shadow_item_cull_mask = 1
	_torche.range_item_cull_mask = 1
	_torche.energy = 2.5
	_torche.color = Charte.HALOGENE
	_torche.position = Vector2(30, 0)
	var cookie := "res://assets/torche/cookie_pompe.png"
	if ResourceLoader.exists(cookie):
		var tex: Texture2D = load(cookie)
		_torche.texture = tex
		# La compensation d'échelle du piège de DA2.1 : l'empreinte au sol vaut
		# `512 x torch_scale`, quelle que soit la résolution du fichier.
		_torche.texture_scale = 1.0 * 512.0 / float(tex.get_width())
	else:
		_absents.append(cookie.get_file())

	_porteur.add_child(_torche)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * ZOOM_JEU
	_porteur.add_child(_camera)
	_camera.make_current()


func _monter_interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	_etiquette = Label.new()
	_etiquette.position = Vector2(24, 18)
	var fonte := "res://assets/fonts/Oxanium.ttf"
	if ResourceLoader.exists(fonte):
		_etiquette.add_theme_font_override("font", load(fonte))
	_etiquette.add_theme_font_size_override("font_size", 18)
	_etiquette.add_theme_color_override("font_color", Charte.ACIER)
	couche.add_child(_etiquette)


## Construit un TileSet à la mise en page de `CandelaTileSet` — sol A en (0,0),
## sol B en (0,1), mur en (1,0) — en piochant CHAQUE tuile indépendamment.
##
## ⚠️ **L'indépendance est tout l'objet de cette fonction, et son absence était
## un défaut réel.** Le premier jet basculait sol ET mur ensemble dès qu'une des
## deux variantes n'était plus « actuel ». Adrien a donc comparé quatre murs
## peints entre eux — quatre panneaux de la même plaque, donc quasi identiques —
## en croyant comparer le peint à l'actuel, et a conclu « aucune différence ».
## **Un banc de comparaison qui couple deux axes ne compare rien.**
func _tuile_actuelle(atlas: Image, coord: Vector2i) -> Image:
	var n := CandelaTileSet.TILE_SIZE.x
	return atlas.get_region(Rect2i(coord.x * n, coord.y * n, n, n))


func _tuile_peinte(fichier: String) -> Image:
	var c := DOSSIER + fichier
	if not ResourceLoader.exists(c):
		if not _absents.has(fichier):
			_absents.append(fichier)
		return null
	var t: Texture2D = load(c)
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _construire_tileset(v_sol: String, v_mur: String) -> TileSet:
	var proc := CandelaTileSet.create_tileset()
	var src_proc := proc.get_source(0) as TileSetAtlasSource
	var atlas_proc := src_proc.texture.get_image()
	if atlas_proc.is_compressed():
		atlas_proc.decompress()

	var n := CandelaTileSet.TILE_SIZE.x
	var sol_a := _tuile_actuelle(atlas_proc, CandelaTileSet.FLOOR_ATLAS_A)
	var sol_b := _tuile_actuelle(atlas_proc, CandelaTileSet.FLOOR_ATLAS_B)
	var mur := _tuile_actuelle(atlas_proc, CandelaTileSet.WALL_ATLAS)

	if v_sol != "actuel":
		var a := _tuile_peinte("solA_%s_1.png" % v_sol)
		var b2 := _tuile_peinte("solB_%s_1.png" % v_sol)
		if a != null and b2 != null:
			sol_a = a
			sol_b = b2
	if v_mur != "actuel":
		var m := _tuile_peinte("murc%s_1.png" % v_mur.substr(1))
		if m != null:
			mur = m

	var atlas := Image.create_empty(n * 2, n * 2, false, Image.FORMAT_RGBA8)
	atlas.blit_rect(sol_a, Rect2i(0, 0, n, n), Vector2i(0, 0))
	atlas.blit_rect(sol_b, Rect2i(0, 0, n, n), Vector2i(0, n))
	atlas.blit_rect(mur, Rect2i(0, 0, n, n), Vector2i(n, 0))

	var ts := TileSet.new()
	ts.tile_size = CandelaTileSet.TILE_SIZE
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas)
	src.texture_region_size = CandelaTileSet.TILE_SIZE
	src.create_tile(CandelaTileSet.FLOOR_ATLAS_A)
	src.create_tile(CandelaTileSet.FLOOR_ATLAS_B)
	src.create_tile(CandelaTileSet.WALL_ATLAS)
	ts.add_source(src, 0)
	return ts


## Huit orientations, tirées d'un hachage de la position.
##
## **Coût mesuré : nul.** Godot porte les transformations dans l'identifiant de
## tuile alternative — pas une texture de plus, pas une tuile alternative à
## créer, un calcul entier par cellule à la construction de la carte. Vérifié le
## 2026-08-25 : les huit combinaisons de `FLIP_H`, `FLIP_V` et `TRANSPOSE` sont
## acceptées telles quelles par `set_cell`.
##
## Le hachage est déterministe sur la position : la même carte rend le même sol
## sur les deux machines d'un match, et d'une partie à l'autre.
func _orientation(cell: Vector2i) -> int:
	if not _rotations:
		return 0
	var h := int(cell.x) * 73856093 ^ int(cell.y) * 19349663
	h = (h ^ (h >> 13)) & 0x7fffffff
	var i := h % 8
	var alt := 0
	if i & 1:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if i & 2:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if i & 4:
		alt |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return alt


func _appliquer() -> void:
	var ts := _construire_tileset(SOLS[_i_sol], MURS[_i_mur])
	_sol.tile_set = ts
	_murs.tile_set = ts

	_sol.clear()
	_murs.clear()
	for cell in MapCodec.get_floor_cells(_carte):
		_sol.set_cell(cell, 0, CandelaTileSet.get_floor_atlas(cell), _orientation(cell))
	for cell in MapCodec.get_wall_cells(_carte):
		_murs.set_cell(cell, 0, CandelaTileSet.WALL_ATLAS, _orientation(cell))

	if _porteur.global_position == Vector2.ZERO:
		var depart := MapCodec.get_spawn(_carte, 0)
		if depart.x >= 0:
			_porteur.global_position = _sol.to_global(_sol.map_to_local(depart))

	_torche.enabled = _torche_allumee
	_camera.zoom = Vector2.ONE * (ZOOM_PIXEL if _zoom_pixel else ZOOM_JEU)
	_etiqueter()


func _etiqueter() -> void:
	_etiquette.text = ("SOL  %s        MUR  %s        tuiles de %d px\n"
		+ "F sol · M mur · T torche (%s) · Z zoom (%s) · R rotations (%s)"
		+ " · flèches déplacer · souris viser · Échap quitter\n"
		+ "⚠️  la couche des murs est en fondu ADDITIF : eteins la torche (T)"
		+ " — si les murs restent visibles, le plan de la carte est gratuit%s") % [
			SOLS[_i_sol], MURS[_i_mur], CandelaTileSet.TILE_SIZE.x,
			"allumée" if _torche_allumee else "ÉTEINTE",
			"1:1" if _zoom_pixel else "jeu",
			"oui" if _rotations else "non",
			"" if _absents.is_empty() else
				"\n\n⚠️  NON CHARGÉ, tuiles d'origine affichées : %s"
				% ", ".join(_absents)
				+ "\n    decouper avec tools/fabrique_tuiles.gd, puis :"
				+ " godot --headless --path . --import"]


func _process(delta: float) -> void:
	var d := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if d != Vector2.ZERO:
		_porteur.global_position += d.normalized() * VITESSE * delta
	_porteur.rotation = (get_global_mouse_position() - _porteur.global_position).angle()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_ESCAPE:
			_sortir()
		KEY_F:
			_i_sol = (_i_sol + 1) % SOLS.size()
			_appliquer()
		KEY_M:
			_i_mur = (_i_mur + 1) % MURS.size()
			_appliquer()
		KEY_T:
			_torche_allumee = not _torche_allumee
			_appliquer()
		KEY_Z:
			_zoom_pixel = not _zoom_pixel
			_appliquer()
		KEY_R:
			_rotations = not _rotations
			_appliquer()


## Sortir par la porte du jeu : les autoloads EOS sont montés même ici, et
## quitter sec ré-entre dans `EOS_Platform_Tick()` — segfault vérifié sur le banc
## de torche.
func _sortir() -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(0)
		return
	get_tree().quit(0)
