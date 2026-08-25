extends SceneTree

## Transforme une planche peinte en masque de decal (DA2.8 sang, DA2.9 impacts).
##
## ## La luminance EST l'alpha, et c'est pour ça que la polarité comptait
##
## Un decal est une forme opaque posée sur le sol ou un mur : ce qu'on garde
## d'une planche, c'est **où il y a de la matière**, pas sa couleur — la teinte
## vient du code (`Charte.CARMIN` pour le sang). Une planche blanche sur fond
## noir se convertit donc directement : `alpha = luminance`, RGB = blanc.
##
## ⚠️ **La première planche de sang livrée était en polarité INVERSE** — encre
## noire sur halo clair. On ne peut pas la retourner : l'encre et le fond de la
## planche sont tous deux quasi noirs, et le seul signal qui les sépare est le
## halo que l'encre occulte. J'ai essayé de l'estimer anneau par anneau, et **ça
## échoue par construction au centre** : les anneaux intérieurs sont entièrement
## couverts d'encre, il n'y a plus rien à comparer. Le cœur de la tache — là où
## le sang devrait être le plus dense — sortait en trou noir. La planche a été
## regénérée, pas rattrapée.
##
##     godot --headless --path . --script res://tools/fabrique_decals.gd -- \
##       --source blood_decals --planche B2_01.jpg --nom sang_1 --taille 160

const RACINE_SOURCES := "res://assets/sources/"
const SORTIE := "res://assets/decals/"
## En deçà, un pixel est du fond et non de la matière. Assez bas pour garder les
## gouttelettes fines, assez haut pour ne pas ramasser le bruit du JPEG.
const SEUIL_FOND := 0.06


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var famille := _arg(args, "--source", "")
	var planche := _arg(args, "--planche", "")
	var nom := _arg(args, "--nom", "")
	if famille == "" or planche == "" or nom == "":
		printerr("fabrique_decals : --source, --planche et --nom sont obligatoires")
		quit(1)
		return
	var taille := int(_arg(args, "--taille", "160"))
	## Retourne la planche horizontalement.
	##
	## ⚠️ **Nécessaire pour la traçante, et le sens n'est pas evident.** La
	## `Line2D` de la balle va de `Vector2.ZERO` — la balle elle-même — vers
	## `Vector2(-longueur, 0)`, la queue. En mode étiré, la texture se pose donc
	## de gauche à droite le long de ce trajet : son bord GAUCHE tombe sur la
	## balle. Une planche dense à droite mettrait le plus lumineux sur la queue
	## et l'extinction sur le projectile — une traînée qui s'allume derrière au
	## lieu de s'éteindre.
	var miroir := _arg(args, "--miroir", "non") == "oui"
	## Découpe en grille. ⚠️ **Une planche de decals n'en contient pas forcément
	## un seul.** La planche d'impacts muraux livrée le 2026-08-25 en portait
	## SEIZE en grille 4×4 ; traitée d'un bloc, elle donnait un decal unique
	## montrant tous les impacts à la fois. Rien n'échoue dans ce cas — le
	## fichier sort, il est simplement absurde.
	var grille := _arg(args, "--panneaux", "1x1").split("x")
	var nx := int(grille[0])
	var ny := int(grille[1]) if grille.size() > 1 else nx

	var img := _charger(RACINE_SOURCES + famille + "/" + planche)
	if img == null:
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))
	var pw := img.get_width() / nx
	var ph := img.get_height() / ny
	if nx * ny > 1:
		print("Planche %s : %dx%d, %d panneaux de %dx%d"
			% [planche, img.get_width(), img.get_height(), nx * ny, pw, ph])
	if miroir:
		img.flip_x()
	var rang := 0
	var code := 0
	for j in ny:
		for i in nx:
			rang += 1
			var suffixe := "" if nx * ny == 1 else "_%d" % rang
			if not _un_decal(img.get_region(Rect2i(i * pw, j * ph, pw, ph)),
					nom + suffixe, taille):
				code = 1
	quit(code)


## Un panneau : seuillage, détourage, mise à l'échelle, écriture.
func _un_decal(img: Image, nom: String, taille: int) -> bool:
	var n := img.get_width()
	var h := img.get_height()
	var sortie := Image.create_empty(n, h, false, Image.FORMAT_RGBA8)
	var couvert := 0
	for y in h:
		for x in n:
			var c := img.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			if l < SEUIL_FOND:
				sortie.set_pixel(x, y, Color(1, 1, 1, 0))
			else:
				# Le fond est retranché puis la plage réétalée : sans ça, un fond
				# à 0,05 laisserait un voile opaque sur toute la planche.
				var a: float = clampf((l - SEUIL_FOND) / (1.0 - SEUIL_FOND), 0.0, 1.0)
				sortie.set_pixel(x, y, Color(1, 1, 1, a))
				if a > 0.5:
					couvert += 1

	var b := _boite(sortie)
	if b.size.x <= 0:
		printerr("fabrique_decals : %s vide apres seuillage — polarite inverse ?" % nom)
		return false
	var coupe := sortie.get_region(b)
	var k := float(taille) / float(maxi(b.size.x, b.size.y))
	coupe.resize(maxi(int(round(b.size.x * k)), 1), maxi(int(round(b.size.y * k)), 1),
		Image.INTERPOLATE_LANCZOS)

	var fichier := "%s.png" % nom
	if coupe.save_png(ProjectSettings.globalize_path(SORTIE + fichier)) != OK:
		printerr("fabrique_decals : ecriture de %s impossible" % nom)
		return false

	# ## Le cœur, et pourquoi il n'est pas décoratif
	#
	# `blood_shader.gdshader` dit de lui-même qu'il « préserve le centre noir et
	# les bords rouges » : sa réflexion spéculaire multiplie la couleur du sang,
	# donc un dessin uniforme ne réfléchit rien d'intéressant. Le dessin
	# procédural qu'on remplace lui donnait ce contraste en DEUX PASSES — liseré
	# carmin, puis cœur presque noir un pixel et demi plus petit.
	#
	# Une texture unique perdrait ce contraste et le rendu « liquide » avec lui.
	# On cuit donc la partie DENSE de l'éclaboussure à part : là où la peinture
	# est franchement opaque, c'est-à-dire la flaque et non les gouttelettes.
	var coeur := Image.create_empty(coupe.get_width(), coupe.get_height(), false,
		Image.FORMAT_RGBA8)
	for y in coupe.get_height():
		for x in coupe.get_width():
			var a2 := coupe.get_pixel(x, y).a
			# Seuil doux : franc au-dessus de 0,80, éteint sous 0,55.
			coeur.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.55, 0.80, a2)))
	if coeur.save_png(ProjectSettings.globalize_path(SORTIE + "%s_coeur.png" % nom)) != OK:
		printerr("fabrique_decals : ecriture du coeur de %s impossible" % nom)
		return false

	print("  %-12s matiere sur %5.1f%%  ->  %dx%d"
		% [fichier, 100.0 * couvert / float(n * h), coupe.get_width(), coupe.get_height()])
	return true


func _boite(img: Image) -> Rect2i:
	var n := img.get_width()
	var h := img.get_height()
	var x0 := n
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in n:
			if img.get_pixel(x, y).a > 0.08:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _charger(chemin: String) -> Image:
	var reel := ProjectSettings.globalize_path(chemin)
	if not FileAccess.file_exists(reel):
		printerr("fabrique_decals : planche introuvable — %s" % reel)
		return null
	var octets := FileAccess.get_file_as_bytes(reel)
	var img := Image.new()
	var err := img.load_png_from_buffer(octets) if chemin.to_lower().ends_with(".png") \
		else img.load_jpg_from_buffer(octets)
	if err != OK:
		printerr("fabrique_decals : lecture impossible (%d)" % err)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	for i in range(args.size() - 1):
		if args[i] == nom:
			return args[i + 1]
	return defaut
