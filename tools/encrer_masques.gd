extends SceneTree

## L'ENCRAGE — une passe qui durcit le bord d'un masque de lumière ou de matière.
##
## ## Pourquoi cette passe existe (refonte roman graphique, 2026-09-10)
##
## Les masques cuits les 24 et 25 août — halos, flash de bouche, taches, gouttes,
## impacts, traçante — sortent de planches PHOTOGRAPHIQUES (lait projeté, halo
## d'objectif, souffle aérographe) : leur alpha est un dégradé continu. Mesuré
## sur les fichiers livrés, 60 à 80 % de leurs pixels non nuls sont
## intermédiaires. Un dégradé mou est un style, celui de la photo ; l'encre en a
## un autre : un aplat, un bord franc, et au plus deux ou trois valeurs.
##
## La feuille de route disait qu'un masque monochrome « n'a pas de style, c'est
## le code qui le colore ». C'est vrai de sa FORME et faux de son BORD. Cette
## passe ne touche qu'au bord : elle ramène l'alpha à quelques paliers, sans
## déplacer la forme, sans changer l'empreinte au sol (elle vit dans le code,
## voir `LightTextures.poser()`), sans recuire la planche.
##
## **Elle est idempotente** : encrer un masque déjà encré ne change rien, donc
## on peut la relancer après toute recuisson sans se demander si elle a déjà
## eu lieu. `tools/test_encrage.gd` vérifie que chaque masque de production
## reste sous 25 % de pixels intermédiaires — une recuisson qui oublierait
## l'encrage rougit.
##
## ## Deux modes
##
##     # Encrer en place un masque déjà cuit (alpha → paliers) :
##     godot --headless --path . --script res://tools/encrer_masques.gd -- \
##       --fichier res://assets/halo/retrodiffusion_corona.png --bornes 0.10,0.40,0.78
##
##     # Faire un masque depuis une planche blanc-sur-noir (luminance → alpha),
##     # sans recadrage — pour une frame de flash, qui doit rester centrée :
##     godot --headless --path . --script res://tools/encrer_masques.gd -- \
##       --planche res://assets/sources/encre/flash_amorce.png \
##       --sortie res://assets/flash/flash_1.png --taille 256 --bornes 0.5
##
## `--bornes b1,b2,…,bN` (croissantes) découpe l'alpha : sous b1 → 0 ; entre
## b_k et b_{k+1} → la k-ième valeur de `--valeurs v1,…,vN` (défaut : k/N, donc
## une seule borne donne un masque binaire). `--sortie` écrit ailleurs qu'en
## place. `--rapport` imprime la part molle sans rien écrire.
##
## `--ceinture N` force les N pixels du pourtour à zéro. ⚠️ **Obligatoire pour
## un masque de LUMIÈRE** : `test_lumieres` exige un coin noir, parce qu'un
## masque radial est lu tel quel et qu'un coin clair fait un CARRÉ lumineux en
## plein jeu. Payé le 2026-09-10 : les pointes de l'éclat de bouche touchaient
## le bord de la toile, et deux frames sortaient à 1,0 d'alpha dans les coins.
##
## ⚠️ **Le cookie de torche n'est PAS un candidat de cette passe sans décision
## d'Adrien** : `Vision.intensite_texture` lit son alpha pour calculer la
## pénalité d'éblouissement, donc un cookie en paliers rend une pénalité en
## paliers. C'est un changement de jeu, pas de rendu.

## Un pixel est « mou » quand un de ses quatre voisins a un alpha PROCHE mais
## différent du sien : c'est la signature d'un dégradé, où chaque pixel diffère
## un peu du suivant. Un aplat n'a que des voisins identiques ; un bord franc
## n'a que des sauts grands. Le premier jet comptait les pixels d'alpha
## intermédiaire, ce qui déclarait mou un masque en trois paliers — la mesure
## disait l'inverse de ce qu'elle devait dire.
const PAS_MOU_MAX := 24


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var fichier := _arg(args, "--fichier", "")
	var planche := _arg(args, "--planche", "")
	var sortie := _arg(args, "--sortie", "")
	var rapport := args.has("--rapport")
	if fichier == "" and planche == "":
		printerr("encrer_masques : --fichier ou --planche est obligatoire")
		quit(1)
		return

	var bornes := _liste(_arg(args, "--bornes", "0.5"))
	var valeurs := _liste(_arg(args, "--valeurs", ""))
	if valeurs.is_empty():
		for k in bornes.size():
			valeurs.append(float(k + 1) / float(bornes.size()))
	if valeurs.size() != bornes.size():
		printerr("encrer_masques : --valeurs doit compter autant d'entrées que --bornes")
		quit(1)
		return

	var img: Image
	if planche != "":
		img = _masque_depuis_planche(planche, int(_arg(args, "--taille", "256")))
		if sortie == "":
			printerr("encrer_masques : --planche exige --sortie")
			quit(1)
			return
	else:
		img = _charger(fichier)
		if sortie == "":
			sortie = fichier
	if img == null:
		quit(1)
		return

	var avant := part_molle(img)
	if rapport:
		print("  %-44s part molle %.2f" % [(fichier if fichier != "" else planche).get_file(), avant])
		quit(0)
		return

	encrer(img, bornes, valeurs)
	var ceinture := int(_arg(args, "--ceinture", "0"))
	if ceinture > 0:
		_ceinturer(img, ceinture)
	var apres := part_molle(img)
	var reel := ProjectSettings.globalize_path(sortie)
	DirAccess.make_dir_recursive_absolute(reel.get_base_dir())
	if img.save_png(reel) != OK:
		printerr("encrer_masques : écriture impossible — %s" % reel)
		quit(1)
		return
	print("  %-36s part molle %.2f -> %.2f  bornes %s  ->  %s"
		% [sortie.get_file(), avant, apres, str(bornes), sortie])
	quit(0)


## Ramène l'alpha de `img` à des paliers. En place.
static func encrer(img: Image, bornes: PackedFloat32Array, valeurs: PackedFloat32Array) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var a := 0.0
			for k in range(bornes.size() - 1, -1, -1):
				if c.a >= bornes[k]:
					a = valeurs[k]
					break
			# Le RVB d'un masque est blanc : on ne le touche pas, seule
			# l'opacité change. Un pixel éteint reste (1, 1, 1, 0) — c'est ce
			# que `fabrique_decals` écrit, et une couleur nulle sous alpha nul
			# donne un liseré sombre au filtrage linéaire.
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))


## Force à zéro l'alpha des `n` pixels du pourtour. En place.
static func _ceinturer(img: Image, n: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if x < n or y < n or x >= w - n or y >= h - n:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))


## Part des pixels non nuls qui ont un voisin d'alpha proche mais différent
## (1 à `PAS_MOU_MAX` sur 255). C'est la mesure du bilan du 2026-09-10 : 0,9 et
## plus pour les halos d'août, moins de 0,1 pour les sprites de septembre.
static func part_molle(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var alphas := PackedInt32Array()
	alphas.resize(w * h)
	for y in h:
		for x in w:
			alphas[y * w + x] = int(round(img.get_pixel(x, y).a * 255.0))
	var non_nuls := 0
	var mous := 0
	for y in h:
		for x in w:
			var a := alphas[y * w + x]
			if a == 0:
				continue
			non_nuls += 1
			var mou := false
			for v in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + v[0]
				var ny: int = y + v[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var d: int = absi(alphas[ny * w + nx] - a)
				if d >= 1 and d <= PAS_MOU_MAX:
					mou = true
					break
			if mou:
				mous += 1
	if non_nuls == 0:
		return 0.0
	return float(mous) / float(non_nuls)


## Une planche blanc-sur-noir devient un masque : la luminance est l'alpha, le
## RVB est blanc. Pas de recadrage (une frame de flash est centrée sur la bouche
## du canon), redimensionnée au carré demandé.
static func _masque_depuis_planche(chemin: String, taille: int) -> Image:
	var src := _charger(chemin)
	if src == null:
		return null
	var out := Image.create_empty(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			out.set_pixel(x, y, Color(1, 1, 1, l))
	out.resize(taille, taille, Image.INTERPOLATE_LANCZOS)
	return out


static func _charger(chemin: String) -> Image:
	var reel := ProjectSettings.globalize_path(chemin)
	if not FileAccess.file_exists(reel):
		printerr("encrer_masques : fichier introuvable — %s" % reel)
		return null
	var octets := FileAccess.get_file_as_bytes(reel)
	var img := Image.new()
	var bas := chemin.to_lower()
	var err := img.load_png_from_buffer(octets) if bas.ends_with(".png") \
		else img.load_jpg_from_buffer(octets)
	if err != OK:
		printerr("encrer_masques : lecture impossible (%d) — %s" % [err, chemin])
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _liste(texte: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if texte.strip_edges() == "":
		return out
	for morceau in texte.split(","):
		out.append(float(morceau.strip_edges()))
	return out


static func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	for i in range(args.size() - 1):
		if args[i] == nom:
			return args[i + 1]
	return defaut
