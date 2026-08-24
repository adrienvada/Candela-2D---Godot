extends SceneTree

## Détoure un sprite généré et le ramène à sa taille de jeu (DA2.4 + DA2.5).
##
## ## Le fond magenta n'est pas un caprice
##
## Un casque presque noir sur fond noir est indétourable : les deux ont la même
## luminance. Le magenta pur `#FF00FF` n'existe nulle part dans la charte de
## Candela — aucun pixel du personnage ne peut lui ressembler par accident. C'est
## la version « découpe » du même principe que le « no rim, no outline » des
## masques de lumière : **on choisit un fond que la mesure peut distinguer.**
##
## ## L'échelle, et pourquoi elle est mesurée et pas devinée
##
## Le joueur est aujourd'hui un `Polygon2D` de rayon 18 : **36 pixels d'épaule à
## épaule.** Un sprite qui tiendrait 36 pixels EN TOUT aurait des épaules de 20
## et une arme illisible. `--epaules` fixe donc la largeur du CORPS, et la toile
## s'étend autour pour laisser l'arme dépasser — ce qui est précisément ce que
## DA2.5 demande : *le pompe se reconnaît à sa forme avant son son*.
##
## ## Ce qu'il vérifie sans qu'on le lui demande
##
## Il mesure la lumière peinte restante — la variation basse fréquence de
## luminance à l'intérieur du corps. La feuille de contraintes du 2026-08-25 dit
## « à plat, aucune lumière cuite », et une consigne qu'on ne mesure pas est une
## consigne qu'on ne tient pas. Le chiffre est imprimé, pas corrigé : sur un
## sprite, contrairement à une tuile, retirer le modelé retirerait le dessin.
##
##     godot --headless --path . --script res://tools/fabrique_sprites.gd -- \
##       --source player --planche S_shotgun_01.jpg --nom pompe --epaules 36

const RACINE_SOURCES := "res://assets/sources/"
const SORTIE := "res://assets/sprites/"
## Tolérance de détourage, en distance RGB au magenta pur. Assez large pour
## attraper le halo de compression JPEG, assez étroite pour ne pas mordre.
const TOLERANCE := 0.34


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var famille := _arg(args, "--source", "player")
	var planche := _arg(args, "--planche", "")
	var nom := _arg(args, "--nom", "")
	if planche == "" or nom == "":
		printerr("fabrique_sprites : --planche et --nom sont obligatoires")
		quit(1)
		return
	var epaules := float(_arg(args, "--epaules", "36"))

	var img := _charger(RACINE_SOURCES + famille + "/" + planche)
	if img == null:
		quit(1)
		return

	var n := img.get_width()
	# 1. Détourage : le magenta devient transparent.
	var oteMagenta := 0
	for y in n:
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var d := Vector3(c.r - 1.0, c.g, c.b - 1.0).length()
			if d < TOLERANCE:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				oteMagenta += 1

	# 2. Boîte de l'opaque, et largeur des ÉPAULES — la ligne la plus large du
	#    tiers supérieur du corps, là où l'arme ne dépasse pas encore.
	var b := _boite(img)
	if b.size.x <= 0:
		printerr("fabrique_sprites : rien d'opaque apres detourage")
		quit(1)
		return
	var larg_epaules := _largeur_epaules(img, b)

	# 3. Échelle : ce sont les ÉPAULES qui valent `--epaules`, pas la boîte.
	var k := epaules / float(larg_epaules)
	var cible_x := int(round(b.size.x * k))
	var cible_y := int(round(b.size.y * k))
	var coupe := img.get_region(b)
	coupe.resize(maxi(cible_x, 1), maxi(cible_y, 1), Image.INTERPOLATE_LANCZOS)

	# 4. Toile carrée, sprite centré : le joueur tourne autour de son centre.
	var cote: int = maxi(cible_x, cible_y)
	var toile := Image.create_empty(cote, cote, false, Image.FORMAT_RGBA8)
	toile.fill(Color(0, 0, 0, 0))
	toile.blit_rect(coupe, Rect2i(0, 0, cible_x, cible_y),
		Vector2i((cote - cible_x) / 2, (cote - cible_y) / 2))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))
	var fichier := "%s.png" % nom
	var err := toile.save_png(ProjectSettings.globalize_path(SORTIE + fichier))
	if err != OK:
		printerr("fabrique_sprites : ecriture impossible (%d)" % err)
		quit(1)
		return

	print("%-10s  planche %dx%d, %.0f%% de fond ote" % [nom, n, n,
		100.0 * oteMagenta / float(n * n)])
	print("            epaules %d px sur la planche -> %.0f px en jeu (facteur %.3f)"
		% [larg_epaules, epaules, k])
	print("            toile %d² — l'arme depasse de %d px au-dela des epaules"
		% [cote, int((cote - epaules) / 2.0)])
	print("            lumiere peinte restante : %.3f  (0 = parfaitement a plat)"
		% _lumiere_peinte(coupe))
	quit(0)


## Boîte englobante de ce qui n'est pas transparent.
func _boite(img: Image) -> Rect2i:
	var n := img.get_width()
	var h := img.get_height()
	var x0 := n
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in n:
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## La ligne opaque la plus large du tiers HAUT de la boîte.
##
## Le corps y est seul : en vue de dessus, les avant-bras et l'arme partent vers
## l'avant, donc plus bas. Mesurer la largeur sur la boîte entière donnerait la
## longueur du fusil, et le pistolet sortirait deux fois plus gros que l'arbalète
## — l'inverse de ce qu'on veut comparer.
func _largeur_epaules(img: Image, b: Rect2i) -> int:
	var pire := 1
	for y in range(b.position.y, b.position.y + int(b.size.y / 3.0)):
		var g := -1
		var d := -1
		for x in range(b.position.x, b.position.x + b.size.x):
			if img.get_pixel(x, y).a > 0.5:
				if g < 0:
					g = x
				d = x
		if d > g and d - g + 1 > pire:
			pire = d - g + 1
	return pire


## Variation basse fréquence de la luminance : ce qui reste d'éclairage peint.
func _lumiere_peinte(img: Image) -> float:
	var n := img.get_width()
	var h := img.get_height()
	var pas: int = maxi(1, n / 8)
	var vals := PackedFloat32Array()
	for by in range(0, h - pas, pas):
		for bx in range(0, n - pas, pas):
			var s := 0.0
			var c := 0
			for y in range(by, mini(by + pas, h)):
				for x in range(bx, mini(bx + pas, n)):
					var p := img.get_pixel(x, y)
					if p.a > 0.5:
						s += p.r * 0.2126 + p.g * 0.7152 + p.b * 0.0722
						c += 1
			if c > pas * pas / 4:
				vals.append(s / float(c))
	if vals.size() < 2:
		return 0.0
	var m := 0.0
	for v in vals:
		m += v
	m /= float(vals.size())
	var q := 0.0
	for v in vals:
		q += (v - m) * (v - m)
	return sqrt(q / float(vals.size()))


func _charger(chemin: String) -> Image:
	var reel := ProjectSettings.globalize_path(chemin)
	if not FileAccess.file_exists(reel):
		printerr("fabrique_sprites : planche introuvable — %s" % reel)
		return null
	var octets := FileAccess.get_file_as_bytes(reel)
	var img := Image.new()
	var err := img.load_png_from_buffer(octets) if chemin.to_lower().ends_with(".png") \
		else img.load_jpg_from_buffer(octets)
	if err != OK:
		printerr("fabrique_sprites : lecture impossible (%d)" % err)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	for i in range(args.size() - 1):
		if args[i] == nom:
			return args[i + 1]
	return defaut
