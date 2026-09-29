extends SceneTree

## Chantier des lumières de la 0.8.0, L1bis — RESSERRE les cookies de torche sur leur nouveau demi-angle (faisceaux
## concentrés, `WeaponData.ouverture_concentree`), sans toucher à leur matière.
##
## ## Pourquoi pas une recuisson par `fabrique_cookies.gd`
##
## Le demi-angle est CUIT dans le cookie, et la voie naturelle serait de recuire la planche `bis04` à l'angle neuf. Mais
## **les curseurs de la cuisson retenue ne sont consignés nulle part** (ROADMAP, « Les réglages qui ont produit les assets
## validés ») : recuire changerait la matière en plus de l'angle, au hasard de curseurs devinés — et « une recuisson
## partielle est pire que pas de recuisson ». Ici, on part du cookie livré lui-même.
##
## ## Ce que l'outil fait
##
## Une déformation POLAIRE exacte : chaque pixel de sortie, à la distance `r` et à l'écart `θ` de l'axe, lit le cookie
## d'origine à la même distance et à l'écart `θ × avant / neuf` (échantillonnage bilinéaire). La portée, le profil le long
## de l'axe, la matière et la luminosité sont les mêmes ; seule l'ouverture se resserre — et avec elle, dans la même
## proportion, le fondu du bord ; le halo court de l'émetteur (ouvert à 80° à la cuisson) est gardé tel qu'il était (voir
## `_resserrer`). L'arbalète (5°, inchangée) n'est pas touchée.
##
## ## Une seule fois, et vérifié
##
## Le demi-angle réellement cuit se MESURE (`Torches.demi_angle_cuit`, au seuil de 1 %, à 0,3° près sur les dix cookies
## d'avant). L'outil ne resserre que si le cookie est encore à l'angle d'avant (`angle_avant` de `tools/torches.gd`), passe
## s'il est déjà à l'angle neuf, et s'arrête en erreur sinon : relancé, il ne resserre jamais deux fois.
## `tools/test_faisceaux_concentres.gd` vérifie que chaque cookie livré a le demi-angle du jeu.
##
##   godot --headless --path . --script res://tools/concentrer_cookies.gd
##   puis : godot --headless --path . --import

const Torches := preload("res://tools/torches.gd")
## L'écart toléré entre le demi-angle mesuré et l'attendu, en degrés (mesure à 0,3° près, plus le fondu du bord).
const TOLERANCE_DEG := 0.6
const SEUIL_MESURE := 0.01


func _init() -> void:
	var erreurs := 0
	for t in Torches.ARMES:
		var fichier: String = t["fichier"]
		var avant: float = t["angle_avant"]
		var neuf: float = t["angle"]
		var chemin := "res://assets/torche/cookie_%s.png" % fichier
		var img := Image.load_from_file(ProjectSettings.globalize_path(chemin))
		if img == null or img.is_empty():
			printerr("✗ %s : illisible" % chemin)
			erreurs += 1
			continue
		img.convert(Image.FORMAT_RGBA8)
		var cuit := Torches.demi_angle_cuit(img, SEUIL_MESURE)
		if absf(cuit - neuf) <= TOLERANCE_DEG:
			print("· %-12s déjà à %.2f° (mesuré %.2f°) : rien à faire" % [fichier, neuf, cuit])
			continue
		if absf(cuit - avant) > TOLERANCE_DEG:
			printerr("✗ %-12s mesuré %.2f°, ni l'angle d'avant (%.2f°) ni le neuf (%.2f°) : je ne touche à rien"
				% [fichier, cuit, avant, neuf])
			erreurs += 1
			continue
		var sortie := _resserrer(img, avant / neuf, avant)
		var mesure := Torches.demi_angle_cuit(sortie, SEUIL_MESURE)
		if absf(mesure - neuf) > TOLERANCE_DEG:
			printerr("✗ %-12s resserré à %.2f° au lieu de %.2f° : non écrit" % [fichier, mesure, neuf])
			erreurs += 1
			continue
		sortie.save_png(ProjectSettings.globalize_path(chemin))
		print("✓ %-12s %.2f° → %.2f° (mesuré %.2f° → %.2f°)" % [fichier, avant, neuf, cuit, mesure])
	quit(1 if erreurs > 0 else 0)


## Au-delà du cône d'avant, de ce nombre de degrés, le cookie d'origine ne porte plus que le halo court de l'émetteur.
const MARGE_HALO_DEG := 2.0


## La déformation polaire : l'écart à l'axe multiplié par `rapport` (> 1 : resserre) à la lecture — puis le halo court de
## l'émetteur REMIS tel qu'il était. ⚠️ Premier jet sans lui : le halo (20 % de la portée, ouvert à 80° à la cuisson) se
## resserrait avec le cône, et « quelqu'un de collé à une torche allumée EST vu, même hors du faisceau » cessait d'être vrai
## (`test_vision`, qui le garde, a rougi). Le halo ne dépend presque pas de l'angle : sa valeur à une distance se lit juste
## hors du cône d'avant (`demi_avant` + `MARGE_HALO_DEG`), où le cookie ne porte que lui, et vaut dans tout le cône d'avant ;
## au-delà, le cookie d'origine tel quel. La sortie garde le plus fort des deux.
static func _resserrer(img: Image, rapport: float, demi_avant: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var sortie := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(w, h) * 0.5
	for y in h:
		for x in w:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5) - c
			var r := d.length()
			var a := d.angle()
			var a_source := signf(a) * minf(absf(a) * rapport, PI)
			var p := c + Vector2(cos(a_source), sin(a_source)) * r - Vector2(0.5, 0.5)
			var resserre := _bilineaire(img, p)
			var a_halo := signf(a) * maxf(absf(a), deg_to_rad(demi_avant + MARGE_HALO_DEG))
			var halo := _bilineaire(img, c + Vector2(cos(a_halo), sin(a_halo)) * r - Vector2(0.5, 0.5))
			sortie.set_pixel(x, y, resserre if resserre.a >= halo.a else halo)
	return sortie


static func _bilineaire(img: Image, p: Vector2) -> Color:
	var x0 := floori(p.x)
	var y0 := floori(p.y)
	var fx := p.x - float(x0)
	var fy := p.y - float(y0)
	var c00 := _pixel(img, x0, y0)
	var c10 := _pixel(img, x0 + 1, y0)
	var c01 := _pixel(img, x0, y0 + 1)
	var c11 := _pixel(img, x0 + 1, y0 + 1)
	return c00.lerp(c10, fx).lerp(c01.lerp(c11, fx), fy)


static func _pixel(img: Image, x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return Color(1.0, 1.0, 1.0, 0.0)
	return img.get_pixel(x, y)
