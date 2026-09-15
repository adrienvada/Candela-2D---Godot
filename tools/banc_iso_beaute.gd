## Banc ISO7 Beauté — l'habillage de la vue iso, AVANT et APRÈS, dans la même fenêtre.
##
## ## La question
##
## L'habillage (matière des murs et du sol, encre d'arête, liseré du sommet, dessus des murets)
## embellit-il SANS rien dire de plus que la lightmap ? La suite `tools/test_iso_beaute.gd` le prouve
## sur les formules ; ce banc le mesure au pixel, sur l'image que le GPU dessine.
##
## ## Ce qu'il fait
##
## Hérite de `tools/banc_iso.gd` (même lancement, mêmes appuis, même sortie par `quit_game`) et
## remplace sa capture quand `--beaute` est donné :
## 1. deux joueurs, torches braquées sur le mur le plus proche (`--cadrage mur`), ou J2 debout contre
##    ce mur dans le faisceau de J1 (`--cadrage planche`, le cadrage de la planche E1 du DA) ;
## 2. **après** : capture avec l'habillage, médiane des appels de dessin sur 30 images ;
## 3. **avant** : les mêmes matériaux ramenés à ISO1-ISO5 (force, encre, liseré, muret à zéro — les
##    valeurs de `--sans-beaute`), SUR LA MÊME IMAGE du jeu, capture et appels ;
## 4. les mesures :
##    - **allumé reste allumé** : aucun pixel clair avant (> 24/255) ne tombe au noir après ;
##    - **allumés neufs** : les pixels noirs avant et allumés après (liserés et dessus de murets —
##      une lumière déjà dans la lightmap, reprojetée), comptés et bornés à `PART_NEUVE_MAX` ;
##    - **histogrammes** de luminance avant/après (huit classes), sur la moitié la plus éclairée ;
##    - **appels de dessin** avant/après : l'habillage n'en ajoute aucun.
##
## Le noir absolu, lui, se prend par le chemin existant du banc, habillage allumé :
##   godot --path . res://tools/banc_iso_beaute.tscn -- --jeu --capture x.png --noir
##
## ## Lancer
##
##   godot --path . res://tools/banc_iso_beaute.tscn -- --jeu --beaute --capture chemin.png
##       [--cadrage mur|planche] [--scinde] [--taille 1920x1080] [--carte <slug>]
##
## Vraie fenêtre, jamais headless. Ses appuis sont vérifiés par `tools/test_iso_beaute.gd`.
extends "res://tools/banc_iso.gd"

const CADRAGES := ["mur", "planche"]
## Seuils des mesures, en niveaux sur 255.
const SEUIL_CLAIR := 24
const SEUIL_NOIR := 2
## La part des pixels de l'écran qu'un habillage peut allumer là où l'avant était noir (liserés et
## dessus de murets). Au-delà, ce n'est plus un liseré : c'est une surface qui s'allume.
const PART_NEUVE_MAX := 0.02
const IMAGES_APPELS := 30

var _beaute := false
var _cadrage := "mur"


func _lire_arguments(args: PackedStringArray) -> bool:
	if not super._lire_arguments(args):
		return false
	_beaute = args.has("--beaute")
	_cadrage = _value(args, "--cadrage", "mur")
	if not CADRAGES.has(_cadrage):
		printerr("✗ --cadrage attend %s (reçu « %s »)" % [" | ".join(CADRAGES), _cadrage])
		return false
	if _beaute and (not _jeu or _capture == "" or _noir):
		printerr("✗ banc_iso_beaute : --beaute se prend avec --jeu et --capture (le noir : --noir sans --beaute)")
		return false
	return true


func _capturer() -> void:
	if not _beaute:
		await super._capturer()
		return
	await _controler_la_beaute()


# ---------------------------------------------------------------------------
# AVANT / APRÈS
# ---------------------------------------------------------------------------

func _controler_la_beaute() -> void:
	var presentation := Presentation3D.instance()
	if presentation == null:
		printerr("✗ la vue iso n'est pas allumée")
		_sortir(1)
		return
	_poser_le_cadrage()
	for i in 90:
		_tenir_le_cadrage()
		await get_tree().process_frame

	var apres := await _capture_et_appels()
	var materiaux := _materiaux_iso(presentation)
	var gardes := _eteindre_la_beaute(materiaux)
	for i in 10:
		_tenir_le_cadrage()
		await get_tree().process_frame
	var avant := await _capture_et_appels()
	_rendre_la_beaute(materiaux, gardes)
	if apres["image"] == null or avant["image"] == null:
		printerr("✗ aucune image rendue en 15 s")
		_sortir(4)
		return

	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	var chemin_apres := _capture.get_basename() + "_apres.png"
	var chemin_avant := _capture.get_basename() + "_avant.png"
	(apres["image"] as Image).save_png(chemin_apres)
	(avant["image"] as Image).save_png(chemin_avant)
	(apres["image"] as Image).save_png(_capture)

	var m := mesurer(avant["image"], apres["image"])
	print("BANC_ISO_BEAUTE cadrage=%s vue=%s appels_avant=%d appels_apres=%d" % [_cadrage,
		"scinde" if _scinde else "unique", avant["appels"], apres["appels"]])
	print("BANC_ISO_BEAUTE pixels=%d clairs_avant=%d eteints_apres=%d allumes_neufs=%d (%.3f %%) changes=%d"
		% [m["pixels"], m["clairs_avant"], m["eteints"], m["neufs"], 100.0 * m["part_neuve"], m["changes"]])
	print("BANC_ISO_BEAUTE histogramme_avant=%s" % str(m["histo_avant"]))
	print("BANC_ISO_BEAUTE histogramme_apres=%s" % str(m["histo_apres"]))
	print("BANC_ISO_BEAUTE max_avant=%d max_apres=%d moyenne_eclairee_avant=%.1f moyenne_eclairee_apres=%.1f"
		% [m["max_avant"], m["max_apres"], m["moy_avant"], m["moy_apres"]])
	var tenu: bool = m["eteints"] == 0 and m["part_neuve"] <= PART_NEUVE_MAX \
		and int(apres["appels"]) <= int(avant["appels"])
	print("BANC_ISO_BEAUTE verdict=%s images=%s %s" % ["HABILLAGE HONNÊTE" if tenu else "HABILLAGE ROMPU",
		chemin_avant, chemin_apres])
	_sortir(0 if tenu else 8)


func _poser_le_cadrage() -> void:
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var cible := _mur_le_plus_proche(p1.global_position)
	var axe := (cible - p1.global_position).normalized()
	if _cadrage == "planche":
		# J2 contre le mur, dans le faisceau de J1 : la planche E1 (« la promesse du jeu en iso »).
		p2.global_position = cible - axe * 26.0
	else:
		p2.global_position = p1.global_position + axe.orthogonal() * 70.0
	_tenir_les_torches()


func _tenir_le_cadrage() -> void:
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var axe := (_mur_le_plus_proche(p1.global_position) - p1.global_position).normalized()
	p1.rotation = axe.angle()
	p2.rotation = axe.angle() if _cadrage == "mur" else (-axe).angle()
	_tenir_les_torches()


func _capture_et_appels() -> Dictionary:
	var appels: Array[int] = []
	for i in IMAGES_APPELS:
		_tenir_le_cadrage()
		await get_tree().process_frame
		appels.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	var image: Image = await RenduCommun.capturer(get_tree(), 15000)
	return {"image": image, "appels": _mediane(appels)}


## Les matériaux iso que l'habillage règle : les murs et les sols de la présentation.
static func _materiaux_iso(presentation: Node) -> Array[ShaderMaterial]:
	var tous: Array[ShaderMaterial] = []
	var mur = presentation.get("_mat_mur")
	if mur is ShaderMaterial:
		tous.append(mur)
	for s in presentation.get("_mat_sols"):
		if s is ShaderMaterial:
			tous.append(s)
	return tous


## Les paramètres de l'habillage, et la valeur qui rend ISO1-ISO5.
const NEUTRES := {"force_matiere": 0.0, "encre_arete_px": 0.0, "lisere_sommet_px": 0.0, "seuil_muret_px": 0.0,
	"temperature": 0.0}


static func _eteindre_la_beaute(materiaux: Array[ShaderMaterial]) -> Array:
	var gardes := []
	for mat in materiaux:
		var g := {}
		for p in NEUTRES:
			var v = mat.get_shader_parameter(p)
			if v != null:
				g[p] = v
				mat.set_shader_parameter(p, NEUTRES[p])
		gardes.append(g)
	return gardes


static func _rendre_la_beaute(materiaux: Array[ShaderMaterial], gardes: Array) -> void:
	for i in materiaux.size():
		for p in gardes[i]:
			materiaux[i].set_shader_parameter(p, gardes[i][p])


## Les mesures avant/après, sur deux images de même taille. Statique : la suite l'éprouve sur des
## images fabriquées (un habillage honnête, un habillage qui éteint, un qui allume une surface).
static func mesurer(avant: Image, apres: Image) -> Dictionary:
	var w := mini(avant.get_width(), apres.get_width())
	var h := mini(avant.get_height(), apres.get_height())
	var clairs := 0
	var eteints := 0
	var neufs := 0
	var changes := 0
	var histo_avant := [0, 0, 0, 0, 0, 0, 0, 0]
	var histo_apres := [0, 0, 0, 0, 0, 0, 0, 0]
	var max_avant := 0
	var max_apres := 0
	var somme_avant := 0.0
	var somme_apres := 0.0
	var eclaires := 0
	for y in h:
		for x in w:
			var a := avant.get_pixel(x, y)
			var b := apres.get_pixel(x, y)
			var va := int(round(maxf(a.r, maxf(a.g, a.b)) * 255.0))
			var vb := int(round(maxf(b.r, maxf(b.g, b.b)) * 255.0))
			max_avant = maxi(max_avant, va)
			max_apres = maxi(max_apres, vb)
			if va > SEUIL_CLAIR:
				clairs += 1
				if vb <= SEUIL_NOIR:
					eteints += 1
			if va <= SEUIL_NOIR and vb > SEUIL_CLAIR:
				neufs += 1
			if absi(va - vb) > 6:
				changes += 1
			if va > SEUIL_NOIR or vb > SEUIL_NOIR:
				eclaires += 1
				somme_avant += va
				somme_apres += vb
				histo_avant[mini(7, va / 32)] += 1
				histo_apres[mini(7, vb / 32)] += 1
	var total := w * h
	return {
		"pixels": total, "clairs_avant": clairs, "eteints": eteints, "neufs": neufs,
		"part_neuve": float(neufs) / float(maxi(1, total)), "changes": changes,
		"histo_avant": histo_avant, "histo_apres": histo_apres,
		"max_avant": max_avant, "max_apres": max_apres,
		"moy_avant": somme_avant / maxf(1.0, eclaires), "moy_apres": somme_apres / maxf(1.0, eclaires),
	}
