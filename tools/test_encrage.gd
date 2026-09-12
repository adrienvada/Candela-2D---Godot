extends SceneTree

## Les masques en jeu sont-ils encrés ? (refonte roman graphique, lot 1)
##
## La règle du chantier : **tout masque de lumière ou de matière en jeu passe
## sous 0,25 de part molle** — la part de ses pixels non nuls qui ont un voisin
## d'alpha proche mais différent, signature d'un dégradé (voir
## `tools/encrer_masques.gd`). Les halos d'août mesuraient 0,98, les taches de
## sang 0,90 ; encrés, 0,08 et 0,00.
##
## Pourquoi une suite et pas une consigne : l'encrage est une PASSE, séparée de
## la cuisson. Une recuisson (`fabrique_cookies.gd`, `fabrique_decals.gd`) qui
## l'oublierait remettrait un dégradé en production sans qu'aucun fichier de
## code ne change — rien ne rougirait. Ici, si.
##
## Les images sont lues SUR LE DISQUE, jamais à travers le cache d'import : un
## cache périmé validerait le fichier d'hier (piège du 2026-08-25, planches de
## marche).
##
## Ce que la suite ne juge pas : si les paliers sont beaux. Adrien les a vus
## côte à côte avec l'ancien rendu ; ce banc n'a d'avis que sur la mesure.

const Encre := preload("res://tools/encrer_masques.gd")

## Les dossiers dont tout PNG est un masque de jeu. Le cookie de torche n'y est
## pas : `Vision` lit son alpha, l'encrer est une décision de jeu qui attend
## Adrien (ROADMAP, chantier « refonte roman graphique », lot 1).
const DOSSIERS := ["res://assets/halo/", "res://assets/flash/", "res://assets/decals/"]

const PLAFOND := 0.25

var _echecs := 0
var _controles := 0


func _init() -> void:
	var vus := 0
	for dossier in DOSSIERS:
		var reel := ProjectSettings.globalize_path(dossier)
		var dir := DirAccess.open(reel)
		if dir == null:
			_check("dossier lisible : " + dossier, false, reel)
			continue
		for nom in dir.get_files():
			if not nom.ends_with(".png"):
				continue
			var img := _lire(reel + nom)
			if img == null:
				_check("%s se lit sur le disque" % nom, false)
				continue
			vus += 1
			var part := Encre.part_molle(img)
			_check("%-30s part molle %.2f <= %.2f" % [nom, part, PLAFOND], part <= PLAFOND)
	_check("au moins vingt masques examinés (%d)" % vus, vus >= 20)

	# L'encrage est idempotent : repassé sur un masque déjà encré, il ne change
	# rien. Sans cette propriété on ne pourrait pas le relancer après une
	# recuisson sans se demander s'il a déjà eu lieu.
	var temoin := _lire(ProjectSettings.globalize_path("res://assets/decals/sang_1.png"))
	if temoin != null:
		var avant := temoin.duplicate()
		Encre.encrer(temoin, PackedFloat32Array([0.45]), PackedFloat32Array([1.0]))
		var identiques := true
		for y in temoin.get_height():
			for x in temoin.get_width():
				if temoin.get_pixel(x, y) != avant.get_pixel(x, y):
					identiques = false
					break
			if not identiques:
				break
		_check("l'encrage est idempotent sur sang_1", identiques)

	# La mesure elle-même : un dégradé est mou, un aplat ne l'est pas, un bord
	# franc anticrénelé non plus. Si un jour on la change, ces trois cas disent
	# ce qu'elle doit encore savoir dire.
	var degrade := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var aplat := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			degrade.set_pixel(x, y, Color(1, 1, 1, float(x) / 63.0))
			aplat.set_pixel(x, y, Color(1, 1, 1, 1.0 if x < 32 else 0.0))
	_check("un dégradé est mou (%.2f)" % Encre.part_molle(degrade),
		Encre.part_molle(degrade) > 0.9)
	_check("un aplat à bord franc ne l'est pas (%.2f)" % Encre.part_molle(aplat),
		Encre.part_molle(aplat) < 0.01)

	print("\n%d contrôles, %d échec(s)" % [_controles, _echecs])
	if _echecs == 0:
		print("✓ Tous les tests passent")
	else:
		printerr("✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _lire(chemin: String) -> Image:
	if not FileAccess.file_exists(chemin):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(chemin)) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _check(nom: String, ok: bool, detail: String = "") -> void:
	_controles += 1
	if ok:
		print("  ✓ " + nom)
	else:
		_echecs += 1
		printerr("  ✗ " + nom + ("" if detail == "" else " — " + detail))
