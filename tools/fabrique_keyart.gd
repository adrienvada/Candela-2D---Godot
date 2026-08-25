extends SceneTree

## Ramène une planche de key art sur la charte (DA2.10).
##
## ## Ce que la mesure a dit, et pourquoi cet outil est si petit
##
## La décision actée du 2026-08-24 annonçait « key art : génération **fortement
## retravaillée** ». Mesuré le 2026-08-25 sur les trois planches livrées :
##
## ```
## planche    noir    mediane   teinte des hautes lumieres
## K1_01     0.000     0.048    1.00 / 0.93 / 0.79
## K1_02     0.000     0.043    1.00 / 0.92 / 0.76
## K1_03     0.000     0.004    1.00 / 0.91 / 0.74
## HALOGENE                     1.00 / 0.93 / 0.82
## ```
##
## **Le noir est déjà absolu — 0,000 exactement**, ce que la promesse du jeu
## exige et qu'aucune retouche n'aurait à corriger. Et la teinte des faisceaux
## tombe à 1 à 8 % de l'halogène de la charte : le modèle a décrit un tungstène
## et a atterri presque pile sur la lumière du jeu.
##
## Il reste **un seul écart réel** : le bleu, à 0,74-0,79 contre 0,82. Les
## faisceaux sont un rien plus sépia que l'halogène. C'est une correction de
## canal, pas une reprise — et prétendre le contraire serait fabriquer du
## travail que la mesure ne demande pas.
##
## ⚠️ **La correction ne porte QUE sur les hautes lumières.** Corriger la teinte
## de toute l'image remonterait aussi le bleu des ombres, et un noir bleuté n'est
## plus le noir absolu : on perdrait la seule chose que ces planches avaient
## déjà juste. Le poids de la correction suit donc la luminance.
##
##     godot --headless --path . --script res://tools/fabrique_keyart.gd -- \
##       --planche K1_01.jpg --nom keyart_faisceaux

const Charte := preload("res://charte.gd")
const SOURCES := "res://assets/sources/key_art/"
const SORTIE := "res://assets/keyart/"
## Au-dessus de cette luminance, un pixel est « une haute lumière » : il porte
## la couleur du faisceau, donc la teinte qu'on corrige.
const SEUIL_HAUTE := 0.55


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var planche := _arg(args, "--planche", "")
	var nom := _arg(args, "--nom", "")
	if planche == "" or nom == "":
		printerr("fabrique_keyart : --planche et --nom sont obligatoires")
		quit(1)
		return
	var largeur := int(_arg(args, "--largeur", "1920"))

	var img := _charger(SOURCES + planche)
	if img == null:
		quit(1)
		return

	# Teinte visée : `HALOGENE` normalisé sur son canal le plus fort.
	var h := Charte.HALOGENE
	var hm: float = maxf(h.r, maxf(h.g, h.b))
	var vise := Vector3(h.r / hm, h.g / hm, h.b / hm)

	# Teinte constatée : moyenne des hautes lumières, normalisée pareil.
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if _lum(c) > SEUIL_HAUTE:
				sr += c.r
				sg += c.g
				sb += c.b
				n += 1
	if n == 0:
		printerr("fabrique_keyart : aucune haute lumiere — planche trop sombre ?")
		quit(1)
		return
	var m: float = maxf(sr, maxf(sg, sb))
	var avant := Vector3(sr / m, sg / m, sb / m)
	var gain := Vector3(vise.x / avant.x, vise.y / avant.y, vise.z / avant.z)

	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			# Le poids suit la luminance : plein sur les faisceaux, nul dans le
			# noir. Corriger partout bleuirait les ombres et tuerait le noir
			# absolu, la seule chose que ces planches avaient deja juste.
			var p: float = smoothstep(0.10, SEUIL_HAUTE, _lum(c))
			img.set_pixel(x, y, Color(
				clampf(c.r * lerpf(1.0, gain.x, p), 0.0, 1.0),
				clampf(c.g * lerpf(1.0, gain.y, p), 0.0, 1.0),
				clampf(c.b * lerpf(1.0, gain.z, p), 0.0, 1.0), 1.0))

	var hauteur := int(round(img.get_height() * float(largeur) / float(img.get_width())))
	img.resize(largeur, hauteur, Image.INTERPOLATE_LANCZOS)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))
	var f := "%s.png" % nom
	if img.save_png(ProjectSettings.globalize_path(SORTIE + f)) != OK:
		printerr("fabrique_keyart : ecriture impossible")
		quit(1)
		return

	print("%-20s teinte %.2f/%.2f/%.2f -> %.2f/%.2f/%.2f   %dx%d   (%s)"
		% [nom, avant.x, avant.y, avant.z, vise.x, vise.y, vise.z,
			largeur, hauteur, f])
	quit(0)


func _lum(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


func _charger(chemin: String) -> Image:
	var reel := ProjectSettings.globalize_path(chemin)
	if not FileAccess.file_exists(reel):
		printerr("fabrique_keyart : planche introuvable — %s" % reel)
		return null
	var octets := FileAccess.get_file_as_bytes(reel)
	var img := Image.new()
	var err := img.load_png_from_buffer(octets) if chemin.to_lower().ends_with(".png") \
		else img.load_jpg_from_buffer(octets)
	if err != OK:
		printerr("fabrique_keyart : lecture impossible (%d)" % err)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	for i in range(args.size() - 1):
		if args[i] == nom:
			return args[i + 1]
	return defaut
