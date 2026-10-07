extends SceneTree

## Cuit `assets/decals/aiguille.png`, la texture de l'aiguille de balle (chantier TIR, étape A, 2026-10-05).
##
## Lancer : godot --headless --path . --script res://tools/fabrique_aiguille.gd
## puis   : godot --headless --path . --import
##
## ## Ce que la planche porte
##
## L'aiguille vue de dessus, la tête à DROITE, la queue à gauche : `bullet.gd` étire le sprite derrière la balle (son +X
## local est l'avant), si bien que le bord droit de la planche tombe sur la tête. Trois couches, additionnées comme le
## moteur les additionnerait si on les posait l'une sur l'autre :
##   • la GAINE ambrée, 6,8 px de large à la tête, 1,2 à la queue, opacité 0,34 qui s'éteint vers l'arrière ;
##   • le CORPS, 2,3 px à la tête, 0,4 à la queue, dont la couleur suit `Charte.feu()` : blanc à la tête, ambre au
##     milieu, carmin à la queue — le refroidissement est dans la forme ;
##   • la POINTE, une ellipse halogène de 10 × 2,6 px posée 2 px derrière la tête.
## Ces largeurs sont celles de la maquette qu'Adrien a validée le 2026-10-05, en pixels de monde : la hauteur de la
## planche couvre `HAUTEUR_MONDE` px, sa longueur `LONGUEUR_REFERENCE` (le pistolet à 28 ms de persistance). Une arme
## plus rapide étire la planche, elle ne la recuit pas.
##
## ⚠️ **La couleur est DANS la planche, et c'est l'exception du dossier.** Les masques de `assets/halo/` et la traçante
## sont blancs, teintés par `modulate` : une seule teinte par objet. L'aiguille en demande trois le long d'un même trait
## (blanc, ambre, carmin), qu'aucun `modulate` ne peut donner. `bullet.gd` la pose donc avec un `modulate` neutre.
##
## ⚠️ **Deux fichiers, comme tout masque d'effet depuis RR5.** Le jeu charge le jumeau FONDU (`CHEMIN_FONDU`, l'opacité en
## dégradé, telle que la cuisson la sort) ; le masque ENCRÉ (`CHEMIN`) reste celui de `--sans-fondu` et de l'encre :
## `EncrerMasques.encrer` y ramène l'opacité à trois paliers (`PALIERS`). `tools/test_encrage.gd` refuse tout fichier de
## `assets/decals/` au-dessus de 25 % de « part molle » — la première cuisson, lisse, y a rougi (0,84). La COULEUR,
## elle, garde son dégradé de feu : l'encrage ne touche que l'alpha.
##
## ⚠️ **Un pourtour d'un texel TRANSPARENT, sur les quatre bords.** Le miroir iso (`miroirs_iso.gd`) échantillonne les
## textures de balle avec `repeat_enable` et un filtre linéaire : sans ce pourtour, le texel blanc de la tête « bave » sur
## la queue, et une lueur parasite naît à l'arrière de chaque aiguille en vue iso. `tools/test_aiguille.gd` l'exige.

const Charte_ := preload("res://charte.gd")
const Encre := preload("res://tools/encrer_masques.gd")

const CHEMIN := "res://assets/decals/aiguille.png"
## Le jumeau FONDU que le jeu charge (chantier RR, RR5 : les effets en jeu passent du palier au fondu, `IsoMateriaux.masque_d_effet`) ;
## le masque encré ci-dessus reste celui de `--sans-fondu` et de `test_encrage`.
const CHEMIN_FONDU := "res://assets/fondu/decals/aiguille.png"
const LARGEUR := 256   # texels, le long du trait
const HAUTEUR := 20    # texels, en travers
## Ce que couvrent ces texels dans le monde, à la longueur de référence.
const HAUTEUR_MONDE := 10.0
const LONGUEUR_REFERENCE := 336.0

## Demi-largeurs en pixels de monde, à la tête puis à la queue.
const GAINE := Vector2(3.4, 0.6)
const CORPS := Vector2(1.15, 0.2)
const OPACITE_GAINE := 0.34
## L'encrage : sous 0,05 rien ; puis la queue (0,18), la gaine et le corps tiède (0,34), le cœur (1).
const BORNES := [0.05, 0.25, 0.7]
const PALIERS := [0.18, 0.34, 1.0]
## L'ellipse de la pointe : demi-longueur, demi-largeur, et son recul derrière la tête, en pixels de monde.
const POINTE := Vector3(5.0, 1.3, 2.0)


func _init() -> void:
	var img := Image.create_empty(LARGEUR, HAUTEUR, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var texel_y := HAUTEUR_MONDE / float(HAUTEUR)
	var tete := float(LARGEUR - 2)
	for x in range(1, LARGEUR - 1):
		# s : 0 à la tête (bord droit), 1 à la queue.
		var s := clampf((tete - float(x)) / (tete - 1.0), 0.0, 1.0)
		var le_long := s * LONGUEUR_REFERENCE
		for y in range(1, HAUTEUR - 1):
			var d := absf((float(y) + 0.5) - float(HAUTEUR) * 0.5) * texel_y
			var somme := Vector3.ZERO
			var a_gaine := OPACITE_GAINE * pow(1.0 - s, 1.4) * _couverture(d, lerpf(GAINE.x, GAINE.y, s), texel_y)
			somme += _rgb(Charte_.AMBRE) * a_gaine
			var chaleur := pow(1.0 - s, 1.5)
			var a_corps := minf(1.0, chaleur * 1.4) * _couverture(d, lerpf(CORPS.x, CORPS.y, s), texel_y)
			somme += _rgb(Charte_.feu(chaleur)) * a_corps
			var e := pow((le_long - POINTE.z) / POINTE.x, 2.0) + pow(d / POINTE.y, 2.0)
			if e < 1.0:
				somme += _rgb(Charte_.HALOGENE) * clampf((1.0 - e) * 3.0, 0.0, 1.0)
			# Une addition, rendue en couleur + opacité : le moteur ajoutera `rgb × a`, soit exactement `somme`
			# tant qu'aucun canal ne dépasse 1 — au-delà, il aurait saturé lui aussi.
			var a := minf(1.0, maxf(somme.x, maxf(somme.y, somme.z)))
			if a <= 0.0:
				continue
			var c := somme / a
			img.set_pixel(x, y, Color(minf(c.x, 1.0), minf(c.y, 1.0), minf(c.z, 1.0), a))
	var err_fondu := img.save_png(ProjectSettings.globalize_path(CHEMIN_FONDU))
	if err_fondu != OK:
		printerr("fabrique_aiguille : écriture impossible (%d) — %s" % [err_fondu, CHEMIN_FONDU])
		quit(1)
		return
	Encre.encrer(img, PackedFloat32Array(BORNES), PackedFloat32Array(PALIERS))
	var err := img.save_png(ProjectSettings.globalize_path(CHEMIN))
	if err != OK:
		printerr("fabrique_aiguille : écriture impossible (%d) — %s" % [err, CHEMIN])
		quit(1)
		return
	print("fabrique_aiguille : %s et %s (%d × %d) écrites. Importer : godot --headless --path . --import" % [CHEMIN_FONDU, CHEMIN, LARGEUR, HAUTEUR])
	quit(0)


## La part d'un texel de `pas` px couverte par un trait de demi-largeur `demi`, à `d` px de l'axe : un bord net,
## lissé sur un texel, comme le remplissage antialiasé de la maquette.
func _couverture(d: float, demi: float, pas: float) -> float:
	return clampf((demi - d) / pas + 0.5, 0.0, 1.0)


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
