extends Node2D

## Aperçu de torche — juger un cookie là où il se juge : dans le noir, sur des
## murs, avec ses ombres.
##
## **Une planche à plat ne dit rien d'un masque de lumière.** Le cookie est
## multiplié par l'énergie de la `PointLight2D` (2,5), découpé par les occluders,
## additionné au néon des murs, puis regardé à travers un `CanvasModulate` noir.
## Ce que l'œil juge sur une vignette — le grain, les arcs, la douceur du bord —
## survit ou disparaît à cette chaîne, et rien d'autre qu'un rendu ne le dit.
##
## Ce banc reproduit **exactement** le montage de `player.gd` : même énergie,
## même teinte (posée sur la lumière, le cookie restant un masque), mêmes
## réglages d'ombre, même décalage de 30 px devant le porteur, même
## `texture_scale` par arme. Il ne simule pas la torche, il la monte.
##
## ## ## Un bruit d'erreur qui n'en est pas un
##
## Chaque changement de cookie fait écrire à Godot `Parameter "t" is null` depuis
## le setter de `PointLight2D.texture`. **La texture posée n'est pourtant jamais
## nulle** : l'étiquette affiche la largeur réelle lue sur l'objet chargé
## (`1024²`), et les quatre rendus diffèrent visiblement à l'écran. C'est du
## bruit interne au moteur sur la réaffectation, pas un échec de chargement.
## Vérifié plutôt que supposé — et noté ici pour que personne ne parte le
## chercher deux fois.
##
## ## Ce qu'il ne montre pas
##
## Pas de rétrodiffusion de lentille, pas de lumière ambiante, pas d'écran
## partagé, pas de poussière dans le faisceau. **C'est délibéré :** on compare
## des cookies, et tout ce qui s'ajoute par-dessus s'ajoute pareil à tous. Un
## banc qui montre tout ne permet plus d'attribuer ce qu'on voit.
##
## ## Lancer
##
## ```
## godot --path . res://tools/apercu_torche.tscn
## ```
##
## Souris : viser · Flèches : se déplacer · **1-4 : variante** · Espace : arme
## suivante · Échap : quitter.
##
## `-- --captures` photographie les seize combinaisons et sort. ⚠️ **La fenêtre
## doit rester au premier plan** : macOS bride une fenêtre en arrière-plan,
## `frame_post_draw` cesse d'arriver et les captures sortent vides.

const Charte := preload("res://charte.gd")
const WD := preload("res://weapon_data.gd")

## Les variantes comparées. `etiquette` vide = le cookie fabriqué par le code,
## c'est-à-dire ce que le jeu affiche aujourd'hui — la référence doit être dans
## la comparaison, sinon on choisit entre trois nouveautés sans savoir laquelle
## bat l'existant.
const VARIANTES := [
	{"nom": "ACTUEL (code)", "etiquette": ""},
	{"nom": "bis04", "etiquette": "bis04"},
	{"nom": "bis01", "etiquette": "bis01"},
	{"nom": "bis02", "etiquette": "bis02"},
]

## La table vient de `tools/torches.gd`, partagée avec la cuisson.
const Torches := preload("res://tools/torches.gd")

const VITESSE := 600.0

## Dossier des captures, et nombre d'images laissées passer avant de
## photographier. Une seule ne suffit pas : la texture change au moment où on la
## pose, mais l'ombre et le rendu de la lumière n'arrivent qu'à la frame
## suivante — on photographierait la variante précédente avec le nom de la
## nouvelle. C'est le même piège que le `REPOS` de la planche de contact.
const DOSSIER_CAPTURES := "user://apercu_torche"
const IMAGES_DE_REPOS := 4

var _porteur: Node2D
var _torche: PointLight2D
var _camera: Camera2D
var _etiquette: Label
var _variante := 1
var _arme := 2  # la pompe : le cône le plus large montre le plus de matière


var _en_capture := false


func _ready() -> void:
	_monter_arene()
	_monter_porteur()
	_monter_interface()
	_appliquer()
	if OS.get_cmdline_user_args().has("--captures"):
		_en_capture = true
		_capturer.call_deferred()


## Photographie les quatre variantes pour les quatre armes, puis sort. Le porteur
## est figé face à la droite : comparer deux cookies photographiés sous deux
## orientations ne compare rien.
func _capturer() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER_CAPTURES))
	_porteur.rotation = 0.0
	var faites := 0
	for ia in range(Torches.ARMES.size()):
		_arme = ia
		for iv in range(VARIANTES.size()):
			_variante = iv
			_appliquer()
			for _i in range(IMAGES_DE_REPOS):
				await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			if img == null:
				push_error("apercu_torche : aucune image — la fenêtre est-elle au premier plan ?")
				_sortir()
				return
			var nom := "%s_%d-%s.png" % [Torches.ARMES[ia]["fichier"], iv,
				str(VARIANTES[iv]["etiquette"]) if VARIANTES[iv]["etiquette"] != "" else "actuel"]
			img.save_png("%s/%s" % [ProjectSettings.globalize_path(DOSSIER_CAPTURES), nom])
			faites += 1
	print("apercu_torche : %d captures dans %s"
		% [faites, ProjectSettings.globalize_path(DOSSIER_CAPTURES)])
	_sortir()


func _monter_arene() -> void:
	var data: Dictionary = MapData.get_selected()
	if data.is_empty():
		push_error("apercu_torche : aucune carte sélectionnée")
		return

	var mod := CanvasModulate.new()
	mod.color = Charte.NOIR
	add_child(mod)

	# Un `CanvasModulate` ne teinte que les éléments dessinés : le vide autour de
	# la carte reste à la couleur d'effacement du viewport, grise par défaut. Sur
	# une carte de 700 unités vue dans une fenêtre plus large, ce gris occupe la
	# moitié de l'écran — et on juge un masque de lumière sur un fond qui n'est
	# pas celui du jeu.
	RenderingServer.set_default_clear_color(Charte.NOIR)

	var tileset := CandelaTileSet.create_tileset()

	var sol := TileMapLayer.new()
	sol.name = "Sol"
	sol.tile_set = tileset
	sol.z_index = -1
	add_child(sol)

	var murs := TileMapLayer.new()
	murs.name = "Murs"
	murs.tile_set = tileset
	murs.z_index = 0
	add_child(murs)

	var spawns := Node2D.new()
	spawns.name = "SpawnPoints"
	add_child(spawns)
	for n in ["P1Spawn", "P2Spawn"]:
		var m := Marker2D.new()
		m.name = n
		spawns.add_child(m)

	MapData.apply_to_layers(sol, murs, spawns, data)

	# Collisions ET occluders ensemble : sans occluder, la torche traverse les
	# murs et il n'y a plus rien à juger.
	MapGeometry.build_collisions(data, self)

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	murs.material = mat


func _monter_porteur() -> void:
	_porteur = Node2D.new()
	_porteur.name = "Porteur"
	var depart := get_node_or_null("SpawnPoints/P1Spawn")
	_porteur.global_position = (depart as Marker2D).global_position if depart else Vector2.ZERO
	add_child(_porteur)

	# Copie conforme de la configuration de `player.gd`.
	_torche = PointLight2D.new()
	_torche.name = "Torche"
	_torche.enabled = true
	_torche.shadow_enabled = true
	_torche.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	_torche.shadow_item_cull_mask = 1
	_torche.range_item_cull_mask = 1
	_torche.energy = 2.5
	_torche.offset = Vector2.ZERO
	_torche.position = Vector2(30, 0)
	# La teinte vit sur la LUMIÈRE, le cookie n'est qu'un masque.
	_torche.color = Charte.HALOGENE
	_porteur.add_child(_torche)

	_camera = Camera2D.new()
	# ⚠️ Pas `Vector2.ONE`, et c'est une question de fidélité, pas de confort.
	# Le jeu est en écran partagé : chaque joueur voit un `SubViewport` de
	# 960 px de large sur les 1920 du projet. Une caméra à zoom 1 dans une
	# fenêtre pleine largeur montrerait le faisceau **deux fois plus petit**
	# qu'en partie — donc un cookie jugé au mauvais grandissement.
	_camera.zoom = Vector2.ONE * 2.0
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
	_etiquette.add_theme_font_size_override("font_size", 19)
	_etiquette.add_theme_color_override("font_color", Charte.ACIER)
	couche.add_child(_etiquette)


## Charge le cookie de la variante et de l'arme courantes. L'étiquette vide
## renvoie au cookie fabriqué par `WeaponData`, ce que le jeu affiche
## aujourd'hui.
func _appliquer() -> void:
	var arme: Dictionary = Torches.ARMES[_arme]
	var v: Dictionary = VARIANTES[_variante]
	var origine := ""

	if v["etiquette"] == "":
		var w = WD.new()
		w.torch_angle_deg = arme["angle"]
		w.torch_brightness = arme["brillance"]
		_torche.texture = w.get_torch_texture()
		origine = "fabriqué à l'exécution, 512²"
	else:
		var chemin := "res://assets/torche/cookie_%s_%s.png" % [arme["fichier"], v["etiquette"]]
		if not ResourceLoader.exists(chemin):
			_etiquette.text = "MANQUANT : %s\n(cuire la variante d'abord)" % chemin
			return
		var tex: Texture2D = load(chemin)
		_torche.texture = tex
		origine = "%s, %d²" % [chemin.get_file(), tex.get_width()]

	# ⚠️ **`texture_scale` multiplie la taille PROPRE de la texture.** Le cookie
	# d'origine fait 512² ; un cookie cuit en fait 1024. Posé tel quel, le même
	# `torch_scale` couvre alors **deux fois plus d'unités de monde** — le
	# faisceau porte deux fois plus loin, sans qu'une seule valeur de gameplay
	# ait bougé. C'est le défaut qu'Adrien a vu en premier, avant toute mesure :
	# « ça éclaire beaucoup trop loin. »
	#
	# On ramène donc l'échelle à l'empreinte de la référence. La résolution
	# décide de la finesse, jamais de la portée.
	var largeur := float(_torche.texture.get_width()) if _torche.texture else 512.0
	_torche.texture_scale = arme["echelle"] * 512.0 / largeur
	# La portée s'affiche en demi-écrans : « 0,85 écran » se juge, « 410 unités »
	# ne se juge pas. Au-delà de 1,00 la torche éclaire hors du champ du joueur.
	var ecrans := Torches.portee_ecrans(arme)
	_etiquette.text = (
		"VARIANTE  %s        ARME  %s  (demi-angle %.0f°, échelle %.1f)\n"
		+ "portée %.0f unités = %.2f écran%s        %s        [%s]\n"
		+ "1-4 variante · Espace arme · flèches déplacer · souris viser · Échap quitter\n"
		+ "valeurs d'essai — game_state.gd porte encore les anciennes") % [
			v["nom"], arme["nom"], arme["angle"], arme["echelle"],
			Torches.portee(arme), ecrans, "  (HORS CHAMP)" if ecrans > 1.0 else "",
			origine, str(arme["origine"])]


func _process(delta: float) -> void:
	if _en_capture:
		return
	var d := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if d != Vector2.ZERO:
		_porteur.global_position += d.normalized() * VITESSE * delta
	_porteur.rotation = (get_global_mouse_position() - _porteur.global_position).angle()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var touche := (event as InputEventKey).physical_keycode
	if touche == KEY_ESCAPE:
		_sortir()
	elif touche == KEY_SPACE:
		_arme = (_arme + 1) % Torches.ARMES.size()
		_appliquer()
	elif touche >= KEY_1 and touche <= KEY_4:
		var i := touche - KEY_1
		if i < VARIANTES.size():
			_variante = i
			_appliquer()


## Sortir par la porte du jeu. Les autoloads EOS sont montés même ici : quitter
## sec ré-entre dans `EOS_Platform_Tick()` et segfault. Vérifié sur ce banc
## même — un `--quit-after` a produit exactement ce crash, pile 11, avec la pile
## d'appel dans `libEOSSDK-Mac-Shipping`.
func _sortir() -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(0)
		return
	get_tree().quit(0)
