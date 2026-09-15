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

const CADRAGES := ["mur", "planche", "e1"]
## ISO7b — la carte d'essai des murs bas (murs de face, de profil, murets), celle de `tools/banc_murs_bas.gd`.
const CARTE_ESSAI := "res://tools/cartes/murs_bas_essai.json"
## Seuils des mesures, en niveaux sur 255.
const SEUIL_CLAIR := 24
const SEUIL_NOIR := 2
## La part des pixels de l'écran qu'un habillage peut allumer là où l'avant était noir (liserés et
## dessus de murets). Au-delà, ce n'est plus un liseré : c'est une surface qui s'allume.
const PART_NEUVE_MAX := 0.02
const IMAGES_APPELS := 30

var _beaute := false
var _cadrage := "mur"
## ISO7b — `--carte-essai` : la carte d'essai des murs bas ; `--fusee` : une fusée posée devant J1.
var _carte_essai := false
var _fusee := false
## ISO7b — le milieu de la face SUD d'un mur haut de la carte chargée : la seule face qu'une caméra au lacet 0
## montre. Posé une fois par `_poser_le_cadrage`, tenu ensuite.
var _face_e1 := Vector2.INF


func _lire_arguments(args: PackedStringArray) -> bool:
	if not super._lire_arguments(args):
		return false
	_beaute = args.has("--beaute")
	_cadrage = _value(args, "--cadrage", "mur")
	_carte_essai = args.has("--carte-essai")
	_fusee = args.has("--fusee")
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
	if _carte_essai:
		# Même chemin que `tools/banc_murs_bas.gd` : la carte posée sous la manche lancée, puis `rebuild_arena`.
		var json := JSON.new()
		json.parse(FileAccess.get_file_as_string(CARTE_ESSAI))
		MapData.current_map_data = MapCodec.validate(json.data as Dictionary)["data"]
		_main.rebuild_arena()
		for i in 10:
			await get_tree().process_frame
		print("Carte : « %s » (carte d'essai)" % String(MapData.current_map_data.get("name", "?")))
		# ⚠️ **`rebuild_arena` éteint les torches, et l'action reste « appuyée »** : le jeu ne voit aucun nouvel appui,
		# rien ne les rallume — toutes les captures du 2026-09-15 à 11:35 sont sorties sans un cône. Relâcher, une
		# image, puis appuyer : l'appui est de nouveau un appui.
		for action in ["p1_torch", "p2_torch"]:
			if InputMap.has_action(action):
				Input.action_release(action)
		for i in 3:
			await get_tree().process_frame
		_tenir_les_torches()
	_poser_le_cadrage()
	if _fusee:
		var p1: Node2D = _main.p1
		var axe := (_mur_le_plus_proche(p1.global_position) - p1.global_position).normalized()
		if _cadrage == "e1" and _face_e1 != Vector2.INF:
			axe = Vector2(0.0, -1.0)
			_main._do_spawn_fusee(0, _face_e1 + Vector2(150.0, 90.0), 0.0, 951)
		else:
			_main._do_spawn_fusee(0, p1.global_position + axe * 90.0 + axe.orthogonal() * 60.0, 0.0, 951)
	# 240 images : le halo d'une fusée grandit à son allumage (anneau de 7 221 pixels « éteints » entre deux
	# captures à 40 images d'écart, le 2026-09-15).
	for i in 240:
		_tenir_le_cadrage()
		await get_tree().process_frame
	if _cadrage == "e1" and _face_e1 != Vector2.INF:
		# Où la face visée tombe à l'écran (vue de J1), pour que les gros plans la cadrent sans la deviner.
		var projecteur := presentation.projecteur_ecran(0)
		if projecteur.is_valid():
			var ecran: Vector2 = projecteur.call(_face_e1)
			print("BANC_ISO_BEAUTE face_e1 monde=%s ecran=(%d, %d)" % [str(_face_e1), roundi(ecran.x), roundi(ecran.y)])

	# ⚠️ **Avant, après, avant bis.** Ce qui change entre les deux « avant » n'est pas l'habillage : c'est le jeu qui
	# bouge (torche qui bascule, fusée qui grandit, bandeau qui respire). Ces pixels-là sortent de la mesure.
	var materiaux := _materiaux_iso(presentation)
	var gardes := _eteindre_la_beaute(materiaux, NEUTRES_ISO7B if _avant_iso7 else NEUTRES)
	for i in 10:
		_tenir_le_cadrage()
		await get_tree().process_frame
	var avant := await _capture_et_appels()
	_rendre_la_beaute(materiaux, gardes)
	for i in 10:
		_tenir_le_cadrage()
		await get_tree().process_frame
	var apres := await _capture_et_appels()
	gardes = _eteindre_la_beaute(materiaux, NEUTRES_ISO7B if _avant_iso7 else NEUTRES)
	for i in 10:
		_tenir_le_cadrage()
		await get_tree().process_frame
	var avant_bis := await _capture_et_appels()
	if _isoler and avant["image"] != null:
		await _isoler_les_parametres(materiaux, gardes, avant["image"])
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

	var derive: Image = masque_de_derive(avant["image"], avant_bis["image"]) if avant_bis["image"] != null else null
	var m := mesurer(avant["image"], apres["image"], derive)
	print("BANC_ISO_BEAUTE derive pixels=%d (écartés des mesures : le jeu a bougé entre les deux avant)" % m["derive"])
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


## `--isoler` (avec `--beaute`) : l'ATTRIBUTION. En partant de l'avant (tout neutre), un seul paramètre
## d'habillage reprend sa valeur, capture, mesure contre l'avant — pour chaque paramètre, plus un témoin
## où rien ne reprend (le bruit d'une image à l'autre). Dit lequel éteint des pixels ou assombrit la
## lumière, au lieu de le deviner (verdict « HABILLAGE ROMPU » du 2026-09-15 sur une seule ligne d'écran).
var _isoler := OS.get_cmdline_user_args().has("--isoler")


## ⚠️ **Un témoin PAR essai, pris juste avant lui.** Le premier `--isoler` comparait chaque essai à l'avant
## du début : cent images plus tard, la torche de J1 avait basculé (`_tenir_les_torches` rejoue l'appui), et
## le « liseré seul » comptait 17 672 pixels éteints — le cône du sol, pas un liseré.
func _isoler_les_parametres(materiaux: Array[ShaderMaterial], _gardes: Array, _avant: Image) -> void:
	# Chaque essai : les valeurs qu'il pose sur la base neutre. Les deux dernières sondent l'encre elle-même.
	var gardes_mur: Dictionary = _gardes[0] if not _gardes.is_empty() else {}
	var essais := {}
	for p in NEUTRES:
		var valeur = null
		for g: Dictionary in _gardes:
			if g.has(p):
				valeur = g[p]
		essais[p] = {p: valeur}
	essais["encre_reste_1"] = {"encre_arete_px": gardes_mur.get("encre_arete_px", 1.6), "encre_arete_reste": 1.0}
	essais["encre_reste_0.25"] = {"encre_arete_px": gardes_mur.get("encre_arete_px", 1.6), "encre_arete_reste": 0.25}
	for nom: String in essais:
		var temoin: Image = await _capture_posee(materiaux, {})
		var image: Image = await _capture_posee(materiaux, essais[nom])
		if temoin == null or image == null:
			print("BANC_ISO_BEAUTE isoler %s : aucune image" % nom)
			continue
		temoin.save_png(_capture.get_basename() + "_temoin_%s.png" % nom)
		image.save_png(_capture.get_basename() + "_seul_%s.png" % nom)
		var m := mesurer(temoin, image)
		print("BANC_ISO_BEAUTE isoler %-18s eteints=%d neufs=%d changes=%d moyenne_eclairee %.1f -> %.1f"
			% [nom, m["eteints"], m["neufs"], m["changes"], m["moy_avant"], m["moy_apres"]])


## Pose `valeurs` sur les matériaux qui déclarent chaque paramètre, capture, puis remet ces paramètres à leur
## valeur neutre (ou d'origine pour ceux hors de `NEUTRES`).
func _capture_posee(materiaux: Array[ShaderMaterial], valeurs: Dictionary) -> Image:
	var avant_pose := []
	for mat in materiaux:
		var g := {}
		for p in valeurs:
			var v = mat.get_shader_parameter(p)
			if v != null and valeurs[p] != null:
				g[p] = v
				mat.set_shader_parameter(p, valeurs[p])
		avant_pose.append(g)
	for k in 10:
		_tenir_le_cadrage()
		await get_tree().process_frame
	var image: Image = await RenduCommun.capturer(get_tree(), 15000)
	for i in materiaux.size():
		for p in avant_pose[i]:
			materiaux[i].set_shader_parameter(p, avant_pose[i][p])
	return image


func _poser_le_cadrage() -> void:
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var cible := _mur_le_plus_proche(p1.global_position)
	var axe := (cible - p1.global_position).normalized()
	if _cadrage == "planche":
		# J2 contre le mur, dans le faisceau de J1 : la planche E1 (« la promesse du jeu en iso »).
		p2.global_position = cible - axe * 26.0
	elif _cadrage == "e1":
		# ISO7b — la caméra regarde le nord (lacet 0) : seules les faces SUD se voient. J1, 160 px au sud d'une face
		# sud, l'éclaire DE FACE ; J2, à 45 px de la même face et décalé, la rase torche parallèle (lumière de
		# profil). ⚠️ Le mur se choisit dans la carte CHARGÉE (`current_map_data`) : `_mur_le_plus_proche` lit le
		# catalogue (`get_selected`), et le cadrage tombait à côté sur la carte d'essai.
		_face_e1 = _face_sud_de_mur_haut(p1.global_position)
		p1.global_position = _face_e1 + Vector2(0.0, 160.0)
		p2.global_position = _face_e1 + Vector2(-150.0, 45.0)
	else:
		p2.global_position = p1.global_position + axe.orthogonal() * 70.0
	_tenir_les_torches()


## Le milieu de la face sud du mur haut (au moins deux tuiles de large) le plus proche de `depuis`, dans la
## carte chargée.
func _face_sud_de_mur_haut(depuis: Vector2) -> Vector2:
	var data: Dictionary = MapData.current_map_data if not MapData.current_map_data.is_empty() else MapData.get_selected()
	var meilleure := depuis
	var distance := INF
	for r: Rect2 in IsoGeometrie.rects_px(data, MapGeometry.Kind.WALLS):
		if r.size.x < 70.0:
			continue
		var face := Vector2(r.get_center().x, r.end.y)
		var d := face.distance_to(depuis)
		if d < distance:
			distance = d
			meilleure = face
	return meilleure


func _tenir_le_cadrage() -> void:
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var axe := (_mur_le_plus_proche(p1.global_position) - p1.global_position).normalized()
	p1.rotation = axe.angle()
	if _cadrage == "e1":
		p1.rotation = -PI / 2.0
		p2.rotation = 0.0
	else:
		p2.rotation = axe.angle() if _cadrage == "mur" else (-axe).angle()
	# ⚠️ **La torche ne reste allumée que tenue** : sans cet appui à chaque image, le banc du 2026-09-15 11:15 a tout
	# capturé torches éteintes. Tenue, elle bascule parfois d'une capture à l'autre : ce bruit-là est MESURÉ par le
	# second « avant » (voir `_controler_la_beaute`) et retiré des mesures, au lieu d'être supposé absent.
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


## ISO7b — `--avant-iso7` : l'avant est l'habillage d'ISO7 (le jeu de ce matin, a5ac4b8), et seuls les réglages
## d'ISO7b sont neutralisés — Lambert, contact, dalles, température graduée (rendue à la force d'ISO7).
const NEUTRES_ISO7B := {"lambert_plancher": 1.0, "contact_px": 0.0, "dalles": 0.0, "temperature_seuil_haut": 0.0,
	"temperature": 0.5, "pied": 8.0}
var _avant_iso7 := OS.get_cmdline_user_args().has("--avant-iso7")


static func _eteindre_la_beaute(materiaux: Array[ShaderMaterial], neutres: Dictionary = NEUTRES) -> Array:
	var gardes := []
	for mat in materiaux:
		var g := {}
		for p in neutres:
			var v = mat.get_shader_parameter(p)
			if v != null:
				g[p] = v
				mat.set_shader_parameter(p, neutres[p])
		gardes.append(g)
	return gardes


static func _rendre_la_beaute(materiaux: Array[ShaderMaterial], gardes: Array) -> void:
	for i in materiaux.size():
		for p in gardes[i]:
			materiaux[i].set_shader_parameter(p, gardes[i][p])


## Les mesures avant/après, sur deux images de même taille. Statique : la suite l'éprouve sur des
## images fabriquées (un habillage honnête, un habillage qui éteint, un qui allume une surface).
## Les pixels qui changent de plus de 6/255 entre deux captures du même état : blanc = dérive du jeu.
static func masque_de_derive(a: Image, b: Image) -> Image:
	var w := mini(a.get_width(), b.get_width())
	var h := mini(a.get_height(), b.get_height())
	var masque := Image.create_empty(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var u := a.get_pixel(x, y)
			var v := b.get_pixel(x, y)
			if absf(maxf(u.r, maxf(u.g, u.b)) - maxf(v.r, maxf(v.g, v.b))) * 255.0 > 6.0:
				masque.set_pixel(x, y, Color.WHITE)
	return masque


static func mesurer(avant: Image, apres: Image, derive: Image = null) -> Dictionary:
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
	var derives := 0
	for y in h:
		for x in w:
			if derive != null and derive.get_pixel(x, y).r > 0.5:
				derives += 1
				continue
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
		"derive": derives, "pixels": total, "clairs_avant": clairs, "eteints": eteints, "neufs": neufs,
		"part_neuve": float(neufs) / float(maxi(1, total)), "changes": changes,
		"histo_avant": histo_avant, "histo_apres": histo_apres,
		"max_avant": max_avant, "max_apres": max_apres,
		"moy_avant": somme_avant / maxf(1.0, eclaires), "moy_apres": somme_apres / maxf(1.0, eclaires),
	}
