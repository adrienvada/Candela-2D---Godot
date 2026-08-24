extends SceneTree

## Découpe une planche générée en tuiles de jeu (DA2.6 sols, DA2.7 murs).
##
## ## Pourquoi un outil, et pas un recadrage à la main
##
## Une tuile de Candela fait **35 pixels**. Les planches livrées font 2048² pour
## quatre panneaux, soit 1024² par tuile : **vingt-neuf fois trop.** Presque tout
## ce qu'on voit sur la planche n'existera pas dans le jeu, et ce qui compte est
## ce qui SURVIT à la réduction. Un outil rend cette réduction reproductible et
## la met sous les yeux avant qu'on ne choisisse.
##
## ## Ce qu'il retire, et pourquoi mécaniquement
##
## La feuille de contraintes validée par Adrien le 2026-08-25 dit « à plat,
## aucune lumière cuite » : l'arène est éclairée par des `Light2D` en temps réel,
## et toute lumière peinte se bat contre elles. **Le prompt le demande ; cet
## outil le GARANTIT.** On divise chaque panneau par sa propre luminance basse
## fréquence — le dégradé d'éclairage que le modèle a peint — et il ne reste que
## la matière. C'est exactement le geste des cookies de torche, où la planche est
## divisée par son profil pour n'en garder que la structure.
##
## Une consigne qu'on ne peut pas vérifier est une consigne qu'on ne tient pas.
##
## ## ⚠️ Les murs se dessinent en FONDU ADDITIF
##
## `apercu_torche.gd` et le jeu posent `BLEND_MODE_ADD` sur la couche des murs.
## Une tuile de mur claire ne se dessine donc pas : elle **s'ajoute** au noir du
## monde, et le mur se met à briller. C'est voulu pour l'arête halogène actuelle
## — deux pixels de filament que la torche accroche — mais ça veut dire qu'une
## tuile de mur peinte doit rester **majoritairement noire**. `--plafond` borne
## la luminance de sortie pour l'imposer.
##
##     godot --headless --path . --script res://tools/fabrique_tuiles.gd -- \
##       --source floor_tiles --planche F1_01.jpg --nom sol --panneaux 2x2
##
##     ... --source wall_tiles --planche W1_01.jpg --nom mur --plafond 0.35

const RACINE_SOURCES := "res://assets/sources/"
const SORTIE := "res://assets/tuiles/"
## Taille d'une tuile, reprise de `CandelaTileSet.TILE_SIZE`. Elle n'est pas
## paramétrable : une tuile d'une autre taille ne rentrerait pas dans l'atlas.
const TAILLE := 35
## Rayon du flou qui estime la lumière peinte, en pixels de tuile. À 35 px, 8
## couvre le vignetage d'un panneau sans manger la matière.
const RAYON_LUMIERE := 8


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var famille := _arg(args, "--source", "")
	var planche := _arg(args, "--planche", "")
	var nom := _arg(args, "--nom", "")
	if famille == "" or planche == "" or nom == "":
		printerr("fabrique_tuiles : --source, --planche et --nom sont obligatoires")
		quit(1)
		return
	var grille := _arg(args, "--panneaux", "2x2").split("x")
	var nx := int(grille[0])
	var ny := int(grille[1]) if grille.size() > 1 else nx
	var plafond := float(_arg(args, "--plafond", "1.0"))
	## Luminance moyenne visée. Sert à IMPOSER l'écart du damier : les quatre
	## panneaux d'une planche sortent tous vers 0,28, alors que le damier
	## d'aujourd'hui oppose 0,111 à 0,231. Sans cet écart, les deux cases du
	## damier deviennent indiscernables — et dans le noir absolu, le damier est
	## la seule référence spatiale du joueur.
	var cible := float(_arg(args, "--luminance", "0"))
	## Arête lumineuse, en couleur de la charte. ⚠️ **Sur un mur, elle n'est pas
	## un ornement : c'est toute sa lisibilité.** Le mur actuel a un écart-type de
	## 0,377 grâce à ses deux pixels d'halogène ; une plaque peinte sans arête
	## tombe à 0,05, et les murs disparaissent dans le noir. Mesuré le 2026-08-25.
	var arete := _arg(args, "--arete", "")
	## Étirement du contraste de la matière autour de sa moyenne.
	##
	## ⚠️ **Il existe parce que deux hypothèses fausses l'ont précédé.** Les murs
	## peints ne se distinguaient pas des murs actuels : j'ai d'abord accusé le
	## fondu additif (faux — le `CanvasModulate` noir éteint tout ce que la torche
	## n'éclaire pas, Adrien l'a vérifié à l'écran), puis le plafond de luminance
	## (faux aussi — les chiffres sont restés identiques en le triplant).
	##
	## La mesure a fini par le dire : la matière du mur porte un écart-type de
	## **0,05**, son arête halogène en porte **0,30**. L'intérieur est six fois
	## plus faible que son bord. Il n'était ni bridé ni éteint : il était NOYÉ.
	##
	## Étirer amplifie le bruit autant que la structure — c'est le prix, et il se
	## juge à l'écran, pas ici.
	var contraste := float(_arg(args, "--contraste", "1.0"))

	var img := _charger(RACINE_SOURCES + famille + "/" + planche)
	if img == null:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))

	var pw := img.get_width() / nx
	var ph := img.get_height() / ny
	print("Planche %s : %dx%d, %d panneaux de %dx%d -> tuiles de %d²"
		% [planche, img.get_width(), img.get_height(), nx * ny, pw, ph, TAILLE])
	print("Plafond de luminance : %.2f%s" % [plafond,
		"  (fondu additif : le mur brillerait au-dela)" if plafond < 1.0 else ""])

	var n := 0
	for j in ny:
		for i in nx:
			n += 1
			var panneau := img.get_region(Rect2i(i * pw, j * ph, pw, ph))
			panneau.resize(TAILLE, TAILLE, Image.INTERPOLATE_LANCZOS)
			var avant := _moyenne(panneau)
			_retirer_lumiere_peinte(panneau, plafond)
			if contraste != 1.0:
				_etirer(panneau, contraste)
			if cible > 0.0:
				_viser_luminance(panneau, cible)
			if arete != "":
				_poser_arete(panneau, arete)
			var apres := _moyenne(panneau)
			var fichier := "%s_%d.png" % [nom, n]
			var err := panneau.save_png(ProjectSettings.globalize_path(SORTIE + fichier))
			if err != OK:
				printerr("fabrique_tuiles : ecriture impossible (%d)" % err)
				quit(1)
				return
			print("  %-10s  luminance %.3f -> %.3f  ecart-type %.3f  ->  %s"
				% [fichier, avant, apres, _ecart_type(panneau), fichier])
	quit(0)


## Divise la tuile par sa propre luminance basse fréquence, puis la ramène à sa
## moyenne d'origine. Ce qui reste est la matière, sans le dégradé d'éclairage.
func _retirer_lumiere_peinte(img: Image, plafond: float) -> void:
	var n := img.get_width()
	var flou := PackedFloat32Array()
	flou.resize(n * n)
	for y in n:
		for x in n:
			var somme := 0.0
			var compte := 0
			for dy in range(-RAYON_LUMIERE, RAYON_LUMIERE + 1):
				for dx in range(-RAYON_LUMIERE, RAYON_LUMIERE + 1):
					var sx: int = clampi(x + dx, 0, n - 1)
					var sy: int = clampi(y + dy, 0, n - 1)
					somme += _lum(img.get_pixel(sx, sy))
					compte += 1
			flou[y * n + x] = somme / float(compte)
	var moy := _moyenne(img)
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			var f: float = maxf(flou[y * n + x], 0.02)
			# Le rapport, recentre sur la moyenne d'origine.
			var k: float = moy / f
			var sortie := Color(
				minf(c.r * k, plafond), minf(c.g * k, plafond), minf(c.b * k, plafond), c.a)
			img.set_pixel(x, y, sortie)


## Écarte chaque pixel de la moyenne, d'un facteur. La moyenne ne bouge pas.
func _etirer(img: Image, k: float) -> void:
	var moy := _moyenne(img)
	var n := img.get_width()
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(
				clampf(moy + (c.r - moy) * k, 0.0, 1.0),
				clampf(moy + (c.g - moy) * k, 0.0, 1.0),
				clampf(moy + (c.b - moy) * k, 0.0, 1.0), c.a))


## Ramène la luminance moyenne sur `cible`, par un facteur unique. La MATIÈRE
## n'est pas touchée — seul son niveau bouge, donc l'écart-type suit le même
## facteur. C'est délibéré : une case sombre doit avoir moins de contraste
## absolu qu'une case claire, comme sur un vrai sol.
func _viser_luminance(img: Image, cible: float) -> void:
	var moy := _moyenne(img)
	if moy <= 0.001:
		return
	var k := cible / moy
	var n := img.get_width()
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0),
				minf(c.b * k, 1.0), c.a))


## Deux pixels de bord, à la couleur nommée de la charte.
func _poser_arete(img: Image, nom: String) -> void:
	var couleurs := {
		"halogene": Color(0.98, 0.91, 0.80),
		"sol_a_arete": Color(0.149, 0.149, 0.161),
		"sol_b_arete": Color(0.282, 0.282, 0.302),
	}
	if not couleurs.has(nom):
		printerr("fabrique_tuiles : arete inconnue — %s (%s)"
			% [nom, ", ".join(PackedStringArray(couleurs.keys()))])
		return
	var c: Color = couleurs[nom]
	var n := img.get_width()
	for y in n:
		for x in n:
			if x <= 1 or y <= 1 or x >= n - 2 or y >= n - 2:
				img.set_pixel(x, y, c)


func _lum(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


func _moyenne(img: Image) -> float:
	var s := 0.0
	var n := img.get_width()
	for y in n:
		for x in n:
			s += _lum(img.get_pixel(x, y))
	return s / float(n * n)


## L'ecart-type de luminance : combien de MATIERE la tuile porte encore apres
## reduction. C'est le chiffre qui dit si une planche a survecu a 35 pixels.
func _ecart_type(img: Image) -> float:
	var moy := _moyenne(img)
	var s := 0.0
	var n := img.get_width()
	for y in n:
		for x in n:
			var d := _lum(img.get_pixel(x, y)) - moy
			s += d * d
	return sqrt(s / float(n * n))


func _charger(chemin: String) -> Image:
	var reel := ProjectSettings.globalize_path(chemin)
	if not FileAccess.file_exists(reel):
		printerr("fabrique_tuiles : planche introuvable — %s" % reel)
		return null
	var octets := FileAccess.get_file_as_bytes(reel)
	var img := Image.new()
	var err := OK
	if chemin.to_lower().ends_with(".png"):
		err = img.load_png_from_buffer(octets)
	else:
		err = img.load_jpg_from_buffer(octets)
	if err != OK:
		printerr("fabrique_tuiles : lecture impossible (%d)" % err)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	for i in range(args.size() - 1):
		if args[i] == nom:
			return args[i + 1]
	return defaut
