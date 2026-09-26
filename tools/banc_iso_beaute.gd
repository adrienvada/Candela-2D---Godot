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
##       [--cadrage mur|planche|e1|rasante] [--scinde] [--taille 1920x1080] [--carte <slug>]
##       [--avant nom=valeur,...] [--pose nom=valeur,...] [--torches j1]
##
## ISO7b — `--avant` remplace les valeurs neutres de l'avant ; `--pose` règle les matériaux dès le départ (l'après).
## Avec `--fusee`, la teinte du halo et du cône avant/après (`mesurer_teintes`). `--cadrage rasante` (avec
## `--torches j1`) : la paire face / rasante sur une longue face sud (`_controler_la_rasante`).
##
## Vraie fenêtre, jamais headless. Ses appuis sont vérifiés par `tools/test_iso_beaute.gd`.
extends "res://tools/banc_iso.gd"

const CADRAGES := ["mur", "planche", "e1", "rasante", "corps"]
## ISO7b — la scène rasante : J1 à une tuile de la face, mesurée sur quatre tuiles de part et d'autre de lui.
const RASANTE_DISTANCE_PX := 35.0
const RASANTE_DEMI_FACE_PX := 280.0
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
## ISO7b — `--avant` : les valeurs de l'avant, à la place de `NEUTRES` ; `--pose` : posées dès le départ, l'après.
var _avant_valeurs := {}
var _pose := {}
## ISO7b — `--cadrage rasante` : la visée de J1, le long du mur (« rasante ») ou face à lui (« face »).
var _visee := "rasante"
## ISO7b — `--distances 1,3` : les distances de J1 à la face, en tuiles, mesurées l'une après l'autre.
var _distances: Array[float] = [1.0]
## La portion de face mesurée (x : son étendue, clippée ; y : la face).
var _face_rect := Rect2()
## ISO12 — `--distance-corps N` : J2 à N px devant J1, dans son faisceau (90 par défaut ; plus loin, une lampe plus faible).
var _distance_corps := 90.0
## ISO12 — `--decalage-corps N` : J2 décalé de N px de côté, vers le bord du cône (une lampe plus faible sur lui).
var _decalage_corps := 0.0
## ISO12 — `--toutes-classes` (cadrage « corps », avec `--corps=portraits`) : la peinture de chacune des dix classes posée tour
## à tour sur le matériau de J2 — même corps, même lampe, même point de sol —, prise peinte puis grise.
var _toutes_classes := OS.get_cmdline_user_args().has("--toutes-classes")
## ISO12, tenues sombres — `--toutes-tenues` (avec `--toutes-classes` et une tenue peinte) : chaque classe prise dans chacune
## des tenues sombres, en plus de son gris, toujours sur le matériau de J2 et contre la même image sans corps.
var _toutes_tenues := OS.get_cmdline_user_args().has("--toutes-tenues")
## `--toutes-teintes` (avec `--toutes-tenues`) : chaque tenue dans chaque teinte (`VoxelCatalogue.TEINTES`), même partie.
var _toutes_teintes := OS.get_cmdline_user_args().has("--toutes-teintes")


func _lire_arguments(args: PackedStringArray) -> bool:
	if not super._lire_arguments(args):
		return false
	_beaute = args.has("--beaute")
	_cadrage = _value(args, "--cadrage", "mur")
	_carte_essai = args.has("--carte-essai")
	_fusee = args.has("--fusee")
	_avant_valeurs = lire_valeurs(_value(args, "--avant", ""))
	_pose = lire_valeurs(_value(args, "--pose", ""))
	_distance_corps = float(_value(args, "--distance-corps", "90"))
	_decalage_corps = float(_value(args, "--decalage-corps", "0"))
	_distances.clear()
	for d in _value(args, "--distances", "1").split(",", false):
		_distances.append(maxf(0.5, d.to_float()))
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
	var materiaux := _materiaux_iso(presentation)
	for mat in materiaux:
		for p in _pose:
			if mat.get_shader_parameter(p) != null:
				mat.set_shader_parameter(p, _pose[p])
	if _cadrage == "rasante":
		await _controler_la_rasante(presentation, materiaux)
		return
	if _cadrage == "corps":
		await _controler_le_contraste(presentation)
		return
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

	# ISO7b — les nuages n'existent qu'une fois la fusée posée : leurs matériaux se relisent après la chauffe.
	materiaux = _materiaux_iso(presentation, 2 if _volumes_seuls else 1)
	print("BANC_ISO_BEAUTE materiaux=%d dont nuages=%d" % [materiaux.size(), _compter_volumes(materiaux)])
	# ⚠️ **Avant, après, avant bis.** Ce qui change entre les deux « avant » n'est pas l'habillage : c'est le jeu qui
	# bouge (torche qui bascule, fusée qui grandit, bandeau qui respire). Ces pixels-là sortent de la mesure.
	var gardes := _eteindre_la_beaute(materiaux, _neutres())
	for i in 10:
		_tenir_le_cadrage()
		await get_tree().process_frame
	var avant := await _capture_et_appels()
	_rendre_la_beaute(materiaux, gardes)
	for i in 10:
		_tenir_le_cadrage()
		await get_tree().process_frame
	var apres := await _capture_et_appels()
	gardes = _eteindre_la_beaute(materiaux, _neutres())
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
	if _fusee:
		var t := mesurer_teintes(avant["image"], apres["image"], derive)
		print("BANC_ISO_BEAUTE teintes halo n=%d teinte %.1f° -> %.1f° r/g %.2f -> %.2f | cône n=%d teinte %.1f° -> %.1f° r/g %.2f -> %.2f b/g %.2f -> %.2f"
			% [t["halo_n"], t["halo_teinte_avant"], t["halo_teinte_apres"], t["halo_rg_avant"], t["halo_rg_apres"],
			t["cone_n"], t["cone_teinte_avant"], t["cone_teinte_apres"], t["cone_rg_avant"], t["cone_rg_apres"],
			t["cone_bg_avant"], t["cone_bg_apres"]])
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
	elif _cadrage == "corps":
		# ISO12 — le contraste corps / sol : J1 éclaire la face sud de 160 px (comme « e1 »), J2 debout 90 px devant lui,
		# dans son faisceau, sur le sol. `--torches j1` : J2 n'ajoute pas sa lumière.
		_face_e1 = _face_sud_de_mur_haut(p1.global_position)
		p1.global_position = _face_e1 + Vector2(0.0, 160.0)
		p2.global_position = _face_e1 + Vector2(_decalage_corps, 160.0 - _distance_corps)
	elif _cadrage == "rasante":
		# J1 à une tuile d'une longue face sud ; J2 écarté, torche éteinte (`--torches j1`) : seule la lampe de J1 compte.
		_face_e1 = _face_sud_longue(p1.global_position)
		if _face_e1 != Vector2.INF:
			p1.global_position = _face_e1 + Vector2(0.0, _distances[0] * RASANTE_DISTANCE_PX)
			if p2.global_position.distance_to(_face_e1) < 600.0:
				p2.global_position = _face_e1 + Vector2(0.0, 900.0)
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


## ISO7b — `--fusee-plein-feu` : la fusée tenue à 1 s de combustion (plein feu, rouge de détresse). ⚠️ Libre, elle passe
## à l'ambre en quelques secondes, et l'âge atteint à la capture dépend de la cadence : au banc du 2026-09-15 (13:40), le
## halo était rouge dans une passe et ambre dans la suivante — une teinte comparée entre deux passes ne disait rien.
var _fusee_plein_feu := OS.get_cmdline_user_args().has("--fusee-plein-feu")
## ISO7b — `--volumes-seuls` : l'avant et l'après ne règlent que les nuages (la teinte d'un nuage près d'une fusée).
var _volumes_seuls := OS.get_cmdline_user_args().has("--volumes-seuls")


func _tenir_le_cadrage() -> void:
	if _fusee_plein_feu:
		# Par nom de méthode : nommer la classe `Fusee` compile `fusee.gd`, qui dépend d'un autoload absent de la suite.
		for c in _main.bullet_container.get_children():
			if c.has_method("appliquer_age"):
				c.call("appliquer_age", 1.0)
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	var axe := (_mur_le_plus_proche(p1.global_position) - p1.global_position).normalized()
	p1.rotation = axe.angle()
	if _cadrage == "rasante":
		# Visée au stick (voir plus bas, « e1 ») : vers l'est le long du mur, ou vers le nord face à lui.
		var voulue := "p1_aim_right" if _visee == "rasante" else "p1_aim_up"
		p1.rotation = 0.0 if _visee == "rasante" else -PI / 2.0
		for action in ["p1_aim_up", "p1_aim_down", "p1_aim_left", "p1_aim_right",
				"p2_aim_up", "p2_aim_down", "p2_aim_left", "p2_aim_right"]:
			if action != voulue and InputMap.has_action(action) and Input.is_action_pressed(action):
				Input.action_release(action)
		if InputMap.has_action(voulue):
			Input.action_press(voulue, 1.0)
		_tenir_les_torches()
		return
	if _cadrage == "e1" or _cadrage == "corps":
		p1.rotation = -PI / 2.0
		p2.rotation = 0.0
		# ⚠️ **La visée se tient par le stick, pas par `rotation`** : `LocalInputProvider.get_aim_direction` rend la
		# direction du stick s'il est poussé, sinon celle de la SOURIS — au banc du 2026-09-15 (12:31), la torche de J1
		# ne visait pas au même endroit dans l'avant et l'après, et la face de face contre la face rasée restait non
		# départagée. Pousser le stick à chaque image fixe la torche d'une capture à l'autre.
		for action in ["p1_aim_down", "p1_aim_left", "p1_aim_right", "p2_aim_up", "p2_aim_down", "p2_aim_left"]:
			if InputMap.has_action(action) and Input.is_action_pressed(action):
				Input.action_release(action)
		for action in ["p1_aim_up", "p2_aim_right"]:
			if InputMap.has_action(action):
				Input.action_press(action, 1.0)
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


## Les matériaux iso que l'habillage règle : les murs et les sols de la présentation. ISO7b — `volumes` : 1 y ajoute
## les nuages d'`IsoVolumes` présents à l'instant de l'appel, 2 ne rend QUE les nuages (`--volumes-seuls`).
static func _materiaux_iso(presentation: Node, volumes := 0) -> Array[ShaderMaterial]:
	var tous: Array[ShaderMaterial] = []
	if volumes != 2:
		var mur = presentation.get("_mat_mur")
		if mur is ShaderMaterial:
			tous.append(mur)
		for s in presentation.get("_mat_sols"):
			if s is ShaderMaterial:
				tous.append(s)
	if volumes > 0:
		var miroirs = presentation.get("_miroirs")
		var vol = miroirs.get("volumes") if miroirs != null else null
		if vol != null:
			for e in vol.call("suivis"):
				for m in (e as Dictionary).get("mats", []):
					# Par le chemin du shader : nommer `IsoVolumes` compilerait ses dépendances dans la suite.
					if m is ShaderMaterial and _est_volume((m as ShaderMaterial).shader):
						tous.append(m)
	return tous


static func _compter_volumes(materiaux: Array[ShaderMaterial]) -> int:
	var n := 0
	for m in materiaux:
		if _est_volume(m.shader):
			n += 1
	return n


## Le shader d'une couche de fumée : `volume_iso.gdshader`, ou sa variante masquée — allumée par défaut depuis le
## 2026-09-25, un Shader NEUF sans chemin, qui se reconnaît à son `#define` (comparer le chemin seul la sautait en silence).
static func _est_volume(sh: Shader) -> bool:
	return sh != null and (sh.resource_path == "res://volume_iso.gdshader" or sh.code.contains("#define FUMEE_MASQUE\n"))


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


## `_neutres()` : les valeurs de l'avant — `--avant` s'il est donné, sinon celles d'ISO7 (`--avant-iso7`) ou d'ISO1-ISO5.
func _neutres() -> Dictionary:
	if not _avant_valeurs.is_empty():
		return _avant_valeurs
	return NEUTRES_ISO7B if _avant_iso7 else NEUTRES


## « nom=valeur,nom=valeur » → {nom: valeur}. Vide → {}.
static func lire_valeurs(texte: String) -> Dictionary:
	var valeurs := {}
	for paire in texte.split(",", false):
		var nom := paire.get_slice("=", 0).strip_edges()
		if nom != "" and paire.contains("="):
			valeurs[nom] = paire.get_slice("=", 1).to_float()
	return valeurs


# ---------------------------------------------------------------------------
# ISO7b — LA TEINTE DU HALO
# ---------------------------------------------------------------------------

## La teinte du halo d'une fusée et celle du cône d'une torche, avant/après. Les classes se lisent sur l'AVANT, à
## prendre SANS chaleur (`--avant temperature=0`) : la couleur de la lumière elle-même. Halo : pixel éclairé saturé
## à dominante rouge ; cône : pixel éclairé presque neutre. Teinte de la couleur MOYENNE de chaque classe, en degrés
## (0 rouge, 30 orange, 60 jaune ; un rose passe sous 0).
const SATURATION_HALO := 0.45
const SATURATION_CONE := 0.25
const SEUIL_TEINTE := 40


static func mesurer_teintes(avant: Image, apres: Image, derive: Image = null) -> Dictionary:
	var w := mini(avant.get_width(), apres.get_width())
	var h := mini(avant.get_height(), apres.get_height())
	var halo_avant := Vector3.ZERO
	var halo_apres := Vector3.ZERO
	var cone_avant := Vector3.ZERO
	var cone_apres := Vector3.ZERO
	var n_halo := 0
	var n_cone := 0
	for y in h:
		for x in w:
			if derive != null and derive.get_pixel(x, y).r > 0.5:
				continue
			var a := avant.get_pixel(x, y)
			var mx := maxf(a.r, maxf(a.g, a.b))
			if mx * 255.0 <= SEUIL_TEINTE:
				continue
			var saturation := (mx - minf(a.r, minf(a.g, a.b))) / mx
			var b := apres.get_pixel(x, y)
			# Rouge seulement (−25° à 20°) : les LED ambre des murs (38°) sont saturées elles aussi, et diluaient la classe.
			var teinte_a := a.h * 360.0
			if saturation > SATURATION_HALO and a.r >= mx and (teinte_a <= 20.0 or teinte_a >= 335.0):
				n_halo += 1
				halo_avant += Vector3(a.r, a.g, a.b)
				halo_apres += Vector3(b.r, b.g, b.b)
			elif saturation < SATURATION_CONE:
				n_cone += 1
				cone_avant += Vector3(a.r, a.g, a.b)
				cone_apres += Vector3(b.r, b.g, b.b)
	return {
		"halo_n": n_halo, "halo_teinte_avant": teinte_deg(halo_avant), "halo_teinte_apres": teinte_deg(halo_apres),
		"halo_rg_avant": halo_avant.x / maxf(halo_avant.y, 1e-6), "halo_rg_apres": halo_apres.x / maxf(halo_apres.y, 1e-6),
		"cone_n": n_cone, "cone_teinte_avant": teinte_deg(cone_avant), "cone_teinte_apres": teinte_deg(cone_apres),
		"cone_rg_avant": cone_avant.x / maxf(cone_avant.y, 1e-6), "cone_rg_apres": cone_apres.x / maxf(cone_apres.y, 1e-6),
		"cone_bg_avant": cone_avant.z / maxf(cone_avant.y, 1e-6), "cone_bg_apres": cone_apres.z / maxf(cone_apres.y, 1e-6),
	}


## La teinte d'une couleur (somme de pixels acceptée), en degrés dans ]-180, 180].
static func teinte_deg(c: Vector3) -> float:
	var mx := maxf(c.x, maxf(c.y, c.z))
	if mx <= 0.0:
		return 0.0
	var teinte := Color(c.x / mx, c.y / mx, c.z / mx).h * 360.0
	return teinte - 360.0 if teinte > 180.0 else teinte


# ---------------------------------------------------------------------------
# ISO7b — LA PAIRE FACE / RASANTE
# ---------------------------------------------------------------------------

## `--cadrage rasante` : la paire face / rasante sur UNE scène (brief de la session cloud, 13:20). J1 seul, à une tuile
## d'une longue face sud ; visée le long du mur, puis face au mur ; pour chacune, le Lambert allumé, éteint (plancher
## 1), rallumé (la dérive du jeu). Mesure : la luminance de la face à l'écran, corps de J1 exclu.
func _controler_la_rasante(presentation: Node, materiaux: Array[ShaderMaterial]) -> void:
	_poser_le_cadrage()
	var mur: ShaderMaterial = materiaux[0] if not materiaux.is_empty() else null
	var cam = presentation.call("_camera_de", 0)
	var ecran: Viewport = presentation.viewport_ecran(0)
	if _face_e1 == Vector2.INF or mur == null or mur.get_shader_parameter("lambert_plancher") == null \
			or cam == null or ecran == null:
		printerr("✗ rasante : aucune longue face sud libre, aucun matériau de mur ou aucune caméra")
		_sortir(4)
		return
	var plancher: float = mur.get_shader_parameter("lambert_plancher")
	print("BANC_ISO_RASANTE face monde=%s j1=%s plancher=%.2f" % [str(_face_e1), str((_main.p1 as Node2D).global_position), plancher])
	var resultats := {}
	var premiere := true
	# ⚠️ **À une tuile, la torche braquée sur le mur n'éclaire presque rien de la face** (banc du 2026-09-15 13:40 :
	# 471 pixels éclairés contre 3 934 le long du mur), et le corps de J1 occupe la lecture un pas devant le pied. La
	# même scène se prend donc à plusieurs distances, et le gradient se juge pixel à pixel : Lambert contre sans Lambert,
	# sur les pixels que la lumière atteint.
	for distance in _distances:
		(_main.p1 as Node2D).global_position = _face_e1 + Vector2(0.0, distance * RASANTE_DISTANCE_PX)
		var t := roundi(distance)
		for visee in ["rasante", "face"]:
			_visee = visee
			for i in (240 if premiere else 120):
				_tenir_le_cadrage()
				await get_tree().process_frame
			var images := {}
			for etat in ["lambert", "sans", "lambert_bis"]:
				mur.set_shader_parameter("lambert_plancher", 1.0 if etat == "sans" else plancher)
				for i in 10:
					_tenir_le_cadrage()
					await get_tree().process_frame
				var image: Image = await RenduCommun.capturer(get_tree(), 15000)
				if image == null:
					printerr("✗ aucune image rendue en 15 s")
					_sortir(4)
					return
				var cle := "%s_%dt_%s" % [visee, t, etat]
				image.save_png(_capture.get_basename() + "_%s.png" % cle)
				if premiere:
					image.save_png(_capture)
					premiere = false
				images[etat] = image
				var zone := _zone_de_la_face(cam, ecran.get_visible_rect().size, image)
				var m := mesurer_face(image, zone["face"], zone["corps"])
				resultats[cle] = m
				print("BANC_ISO_RASANTE distance=%dt visee=%s etat=%s moyenne=%.1f eclairee=%.1f (%d/%d pixels > %d) r/g=%.2f zone=%s corps=%s"
					% [t, visee, etat, m["moyenne"], m["eclairee"], m["eclaires"], m["pixels"], SEUIL_CLAIR, m["rg"],
					str(zone["face"]), str(zone["corps"])])
			var zone_l := _zone_de_la_face(cam, ecran.get_visible_rect().size, images["lambert"])
			var r := rapport_sur_eclaires(images["lambert"], images["sans"], zone_l["face"], zone_l["corps"])
			resultats["%s_%dt_rapport" % [visee, t]] = r
		var ras: float = resultats["rasante_%dt_lambert" % t]["moyenne"]
		var face: float = resultats["face_%dt_lambert" % t]["moyenne"]
		var ras_sans: float = resultats["rasante_%dt_sans" % t]["moyenne"]
		var face_sans: float = resultats["face_%dt_sans" % t]["moyenne"]
		print("BANC_ISO_RASANTE distance=%dt rasante/face %.2f avec Lambert, %.2f sans ; Lambert/sans sur les pixels éclairés : rasante %.2f (%d px), face %.2f (%d px) ; dérive rasante %.1f, face %.1f"
			% [t, ras / maxf(face, 0.001), ras_sans / maxf(face_sans, 0.001),
			resultats["rasante_%dt_rapport" % t]["rapport"], resultats["rasante_%dt_rapport" % t]["pixels"],
			resultats["face_%dt_rapport" % t]["rapport"], resultats["face_%dt_rapport" % t]["pixels"],
			absf(ras - float(resultats["rasante_%dt_lambert_bis" % t]["moyenne"])),
			absf(face - float(resultats["face_%dt_lambert_bis" % t]["moyenne"]))])
	mur.set_shader_parameter("lambert_plancher", plancher)
	_sortir(0)


## Le facteur que le Lambert pose, pixel à pixel : somme avec Lambert sur somme sans, sur les pixels de `zone` que la
## lumière atteint sans Lambert (> `SEUIL_CLAIR`), `exclu` retiré.
static func rapport_sur_eclaires(avec: Image, sans: Image, zone: Rect2, exclu: Rect2 = Rect2()) -> Dictionary:
	var w := mini(avec.get_width(), sans.get_width())
	var h := mini(avec.get_height(), sans.get_height())
	var dedans := Rect2i(zone).intersection(Rect2i(0, 0, w, h))
	var somme_avec := 0.0
	var somme_sans := 0.0
	var pixels := 0
	for y in range(dedans.position.y, dedans.end.y):
		for x in range(dedans.position.x, dedans.end.x):
			if exclu.has_area() and exclu.has_point(Vector2(x + 0.5, y + 0.5)):
				continue
			var s := sans.get_pixel(x, y)
			var vs := maxf(s.r, maxf(s.g, s.b)) * 255.0
			if vs <= SEUIL_CLAIR:
				continue
			var a := avec.get_pixel(x, y)
			somme_avec += maxf(a.r, maxf(a.g, a.b)) * 255.0
			somme_sans += vs
			pixels += 1
	return {"rapport": somme_avec / maxf(somme_sans, 1.0), "pixels": pixels}


## Le milieu de la plus longue face sud (au moins 8 tuiles) dont le devant est libre jusqu'à une tuile au-delà de la
## plus grande distance ; à longueur égale, la plus proche de `depuis`. Pose `_face_rect` (l'étendue mesurée, clippée à
## `RASANTE_DEMI_FACE_PX` de part et d'autre). `Vector2.INF` s'il n'y en a aucune.
func _face_sud_longue(depuis: Vector2) -> Vector2:
	var data: Dictionary = MapData.current_map_data if not MapData.current_map_data.is_empty() else MapData.get_selected()
	var rects: Array = IsoGeometrie.rects_px(data, MapGeometry.Kind.WALLS)
	var profondeur: float = (float(_distances.max()) + 1.0) * RASANTE_DISTANCE_PX
	var meilleure := Vector2.INF
	var longueur := 0.0
	var distance := INF
	for r: Rect2 in rects:
		if r.size.x < 280.0:
			continue
		var face := Vector2(r.get_center().x, r.end.y)
		var x0 := maxf(r.position.x, face.x - RASANTE_DEMI_FACE_PX)
		var x1 := minf(r.end.x, face.x + RASANTE_DEMI_FACE_PX)
		var devant := Rect2(x0, face.y + 1.0, x1 - x0, profondeur)
		var libre := true
		for autre: Rect2 in rects:
			if autre.intersects(devant):
				libre = false
				break
		if not libre:
			continue
		if x1 - x0 > longueur + 0.5 or (absf(x1 - x0 - longueur) <= 0.5 and face.distance_to(depuis) < distance):
			longueur = x1 - x0
			distance = face.distance_to(depuis)
			meilleure = face
			_face_rect = Rect2(x0, face.y, x1 - x0, 0.0)
	return meilleure


## La face à l'écran (de 6 px au-dessus du sol — la bande de contact exclue — à 3 px sous le sommet) et le corps de J1,
## en pixels de l'image capturée.
func _zone_de_la_face(cam, taille: Vector2, image: Image) -> Dictionary:
	var echelle := Vector2(image.get_width(), image.get_height()) / taille
	var hauteur := IsoGeometrie.hauteur_mur_haut() * float(CandelaTileSet.TILE_SIZE.y)
	var a: Vector2 = cam.vers_ecran(Vector2(_face_rect.position.x, _face_e1.y), taille, 6.0) * echelle
	var b: Vector2 = cam.vers_ecran(Vector2(_face_rect.end.x, _face_e1.y), taille, hauteur - 3.0) * echelle
	var p1: Vector2 = (_main.p1 as Node2D).global_position
	var c: Vector2 = cam.vers_ecran(p1 + Vector2(-26.0, 26.0), taille, 0.0) * echelle
	var d: Vector2 = cam.vers_ecran(p1 + Vector2(26.0, -26.0), taille, Presentation3D.HAUTEUR_CORPS_PX + 12.0) * echelle
	return {"face": Rect2(a, Vector2.ZERO).expand(b), "corps": Rect2(c, Vector2.ZERO).expand(d)}


## Luminance (canal max, sur 255) d'une zone de l'image, `exclu` retiré : moyenne de tous les pixels, moyenne des
## pixels éclairés (> `SEUIL_CLAIR`) et leur r/g.
static func mesurer_face(image: Image, zone: Rect2, exclu: Rect2 = Rect2()) -> Dictionary:
	var dedans := Rect2i(zone).intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
	var somme := 0.0
	var somme_eclairee := 0.0
	var pixels := 0
	var eclaires := 0
	var r := 0.0
	var g := 0.0
	for y in range(dedans.position.y, dedans.end.y):
		for x in range(dedans.position.x, dedans.end.x):
			if exclu.has_area() and exclu.has_point(Vector2(x + 0.5, y + 0.5)):
				continue
			var p := image.get_pixel(x, y)
			var v := maxf(p.r, maxf(p.g, p.b)) * 255.0
			pixels += 1
			somme += v
			if v > SEUIL_CLAIR:
				eclaires += 1
				somme_eclairee += v
				r += p.r
				g += p.g
	return {"moyenne": somme / maxf(1.0, pixels), "eclairee": somme_eclairee / maxf(1.0, eclaires),
		"eclaires": eclaires, "pixels": pixels, "rg": r / maxf(g, 1e-6)}


# ---------------------------------------------------------------------------
# ISO12 — LE CONTRASTE D'UN CORPS SUR LE SOL
# ---------------------------------------------------------------------------

## `--cadrage corps` : J2 dans le faisceau de J1, capturé avec son corps, puis sans (le voxel de J2 masqué, rien d'autre
## ne bouge), puis avec encore (la dérive). Le corps = les pixels qui changent ; le sol = un anneau de 6 à 30 px autour,
## hors du corps. Mesure : luminance moyenne du corps et du sol autour (Rec. 709 sur les valeurs affichées), leur rapport,
## et la teinte moyenne du corps. À lancer avec et sans `--corps=portraits`.
func _controler_le_contraste(presentation: Node) -> void:
	_poser_le_cadrage()
	var voxels: Array = presentation.get("_voxels")
	var corps: Node3D = voxels[1] if voxels.size() > 1 else null
	if corps == null:
		printerr("✗ contraste : aucun corps voxel pour J2")
		_sortir(4)
		return
	for i in 240:
		_tenir_le_cadrage()
		await get_tree().process_frame
	# ⚠️ **Gris et peint dans la MÊME partie, à la même image près.** Pris dans deux lancements, le sol autour du corps lisait
	# 79 dans l'un et 39 dans l'autre au bord du cône (2026-09-23 03:26) : la comparaison mesurait la partie, pas la peinture.
	# Avec `--corps=portraits`, J2 est pris peint, puis gris (le portrait éteint sur son matériau, rien d'autre), puis sans son
	# corps, puis peint de nouveau (la dérive).
	var mat: ShaderMaterial = (corps as VoxelCorps).materiau() if corps is VoxelCorps else null
	var peint := VoxelCatalogue.portraits_actifs() and mat != null
	var etats: Array = [["avec", 1.0], ["gris", 0.0], ["sans", 1.0], ["avec_bis", 1.0]] if peint \
		else [["avec", 0.0], ["sans", 0.0], ["avec_bis", 0.0]]
	var images := {}
	for e in etats:
		corps.visible = e[0] != "sans"
		if peint:
			mat.set_shader_parameter("portrait", e[1])
		for i in 10:
			_tenir_le_cadrage()
			await get_tree().process_frame
		var image: Image = await RenduCommun.capturer(get_tree(), 15000)
		if image == null:
			printerr("✗ aucune image rendue en 15 s")
			_sortir(4)
			return
		images[e[0]] = image
	corps.visible = true
	if peint:
		mat.set_shader_parameter("portrait", 1.0)
	(images["avec"] as Image).save_png(_capture)
	(images["sans"] as Image).save_png(_capture.get_basename() + "_sans_corps.png")
	if peint and _toutes_classes:
		await _contraste_par_classe(corps, mat, images["sans"], images["avec_bis"], images["avec"])
		_sortir(0)
		return
	var mesures := {"peint" if peint else "gris": mesurer_contraste(images["avec"], images["sans"], images["avec_bis"])}
	if peint:
		(images["gris"] as Image).save_png(_capture.get_basename() + "_gris.png")
		mesures["gris"] = mesurer_contraste(images["gris"], images["sans"], images["avec_bis"])
	for nom in mesures:
		var m: Dictionary = mesures[nom]
		print("BANC_ISO_CONTRASTE %s distance=%d décalage=%d corps=%d px lum=%.1f teinte=%.1f° r/g=%.2f | sol autour=%d px lum=%.1f | rapport corps/sol=%.2f | ΔE76 corps/sol=%.1f (Lab corps %s, sol %s) | dérive=%d"
			% [nom, roundi(_distance_corps), roundi(_decalage_corps), m["corps_n"], m["corps_lum"], m["corps_teinte"], m["corps_rg"],
			m["sol_n"], m["sol_lum"], m["rapport"], m["delta_e"], _lab_texte(m["corps_lab"]), _lab_texte(m["sol_lab"]), m["derive"]])
	_sortir(0)


## Le corps : pixels qui changent de plus de 6/255 entre « avec » et « sans », hors de la dérive (« avec » contre
## « avec bis »). Le sol : les pixels de l'image « avec » à 6-30 px d'un pixel du corps, hors du corps, éclairés (> 2).
## `impose` (tenues sombres) : le masque du corps donné d'avance — l'union des masques du gris et des tenues — au lieu de
## celui de cette image. Un corps sombre diffère moins du sol : son propre masque ne garde que ses pixels clairs, et sa
## clarté moyenne en sortait PLUS haute que celle du gris (V2 : 52 contre 30, 2026-09-23 20:58). `corps_n` reste compté
## sur cette image : le nombre de pixels où le corps se voit (plus de 6/255 d'écart avec le sol sans lui).
static func mesurer_contraste(avec: Image, sans: Image, avec_bis: Image, impose: Dictionary = {}) -> Dictionary:
	var w := avec.get_width()
	var h := avec.get_height()
	var masque := {}
	var x0 := w
	var y0 := h
	var x1 := 0
	var y1 := 0
	var derive := 0
	for y in h:
		for x in w:
			var a := avec.get_pixel(x, y)
			if absf(_lum(a) - _lum(avec_bis.get_pixel(x, y))) * 255.0 > 6.0:
				derive += 1
				continue
			if absf(_lum(a) - _lum(sans.get_pixel(x, y))) * 255.0 > 6.0:
				masque[Vector2i(x, y)] = true
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	var visibles := masque.size()
	if not impose.is_empty():
		masque = impose
		x0 = w
		y0 = h
		x1 = 0
		y1 = 0
		for p: Vector2i in masque:
			x0 = mini(x0, p.x)
			y0 = mini(y0, p.y)
			x1 = maxi(x1, p.x)
			y1 = maxi(y1, p.y)
	var somme := 0.0
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var lab_corps := Vector3.ZERO
	for p: Vector2i in masque:
		var c := avec.get_pixel(p.x, p.y)
		somme += _lum(c)
		r += c.r
		g += c.g
		b += c.b
		lab_corps += lab(c)
	var sol := 0.0
	var n_sol := 0
	var lab_sol := Vector3.ZERO
	for y in range(maxi(0, y0 - 30), mini(h, y1 + 31)):
		for x in range(maxi(0, x0 - 30), mini(w, x1 + 31)):
			if masque.has(Vector2i(x, y)):
				continue
			var dx := maxi(maxi(x0 - x, x - x1), 0)
			var dy := maxi(maxi(y0 - y, y - y1), 0)
			var d := sqrt(float(dx * dx + dy * dy))
			if d < 6.0 or d > 30.0:
				continue
			var c := avec.get_pixel(x, y)
			if _lum(c) * 255.0 <= 2.0:
				continue
			sol += _lum(c)
			n_sol += 1
			lab_sol += lab(c)
	var n := maxi(1, masque.size())
	var moy_corps := somme / float(n) * 255.0
	var moy_sol := sol / float(maxi(1, n_sol)) * 255.0
	lab_corps /= float(n)
	lab_sol /= float(maxi(1, n_sol))
	return {"corps_n": visibles, "masque": masque, "corps_lum": moy_corps, "sol_n": n_sol, "sol_lum": moy_sol,
		"corps_lab": lab_corps, "sol_lab": lab_sol, "delta_e": lab_corps.distance_to(lab_sol),
		"rapport": moy_corps / maxf(moy_sol, 0.001), "corps_rg": r / maxf(g, 0.0001),
		"corps_teinte": Color(r / n, g / n, b / n).h * 360.0, "derive": derive}


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## CIELAB (D65) d'un pixel sRGB : l'écart de couleur PERCEPTUEL, où une teinte compte autant qu'une clarté (ΔE76 = distance
## euclidienne). Une paire à ΔE ≈ 2,3 se distingue à peine ; au-delà de 10, deux couleurs se lisent comme différentes.
static func lab(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	var x := (0.4124 * l.r + 0.3576 * l.g + 0.1805 * l.b) / 0.95047
	var y := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	var z := (0.0193 * l.r + 0.1192 * l.g + 0.9505 * l.b) / 1.08883
	var fx := _f_lab(x)
	var fy := _f_lab(y)
	var fz := _f_lab(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _f_lab(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


static func _lab_texte(v: Vector3) -> String:
	return "%.1f/%.1f/%.1f" % [v.x, v.y, v.z]



## `--toutes-classes` : pour chaque classe, sa palette et son gris posés sur le matériau de J2 (la forme reste celle de J2 :
## la couleur seule change), une capture peinte, une grise ; mesurées contre la même image sans corps. Rend le matériau de J2.
## Avec `--toutes-tenues`, une capture par tenue sombre (`tenue=` dans la ligne imprimée) au lieu de la seule tenue lancée.
func _contraste_par_classe(corps: Node3D, mat: ShaderMaterial, sans: Image, bis: Image, avec: Image) -> void:
	var garde := {}
	for p in ["couleur_fiche", "portrait_ocre", "portrait_rouille", "portrait_brun", "portrait_bouteille", "portrait_arme",
			"portrait_cartouche", "portrait_usure", "portrait_tete", "portrait_arete", "portrait_arete_px", "portrait_sous_seuil", "portrait_seuils"]:
		garde[p] = mat.get_shader_parameter(p)
	var tenues: Array = []
	for nom in (VoxelCatalogue.TENUES_SOMBRES.keys() if _toutes_tenues else [VoxelCatalogue.tenue()]):
		for te in (VoxelCatalogue.TEINTES.keys() if _toutes_teintes else [VoxelCatalogue.teinte()]):
			tenues.append([nom, te])
	for slug in VoxelCatalogue.slugs():
		mat.set_shader_parameter("couleur_fiche", VoxelCatalogue.fiche(slug)["couleur"])
		var prises := {}
		mat.set_shader_parameter("portrait", 0.0)
		for i in 10:
			_tenir_le_cadrage()
			await get_tree().process_frame
		prises["gris"] = await RenduCommun.capturer(get_tree(), 15000)
		for paire in tenues:
			var nom := "%s/%s" % paire
			var pal := VoxelCatalogue.palette_tenue(slug, paire[0], paire[1])
			for cle in ["ocre", "rouille", "brun", "bouteille", "arme", "cartouche"]:
				mat.set_shader_parameter("portrait_%s" % cle, pal[cle])
			mat.set_shader_parameter("portrait_usure", pal["usure"])
			mat.set_shader_parameter("portrait_tete", pal.get("tete", Color(0, 0, 0, 0)))
			mat.set_shader_parameter("portrait_arete", pal.get("arete", Color(0, 0, 0, 0)))
			mat.set_shader_parameter("portrait_arete_px", float(pal.get("arete_px", 0.0)))
			mat.set_shader_parameter("portrait_sous_seuil", 1.0 if bool(pal.get("sous_seuil", true)) else 0.0)
			mat.set_shader_parameter("portrait_seuils", pal.get("seuils", Vector2(10.0, 24.0) / 255.0))
			mat.set_shader_parameter("portrait", 1.0)
			for i in 10:
				_tenir_le_cadrage()
				await get_tree().process_frame
			prises[nom] = await RenduCommun.capturer(get_tree(), 15000)
		if prises.values().has(null):
			printerr("✗ %s : aucune image" % slug)
			continue
		# Le masque commun : l'union des pixels où le gris ou l'une des tenues se voit (voir `mesurer_contraste`), moins la
		# DÉRIVE de la scène, lue une fois entre les deux prises de la tenue lancée (`avec`, `avec_bis`). ⚠️ Chaque prise se
		# compare à elle-même pour la dérive : contre `avec_bis`, peint dans la tenue lancée, les pixels du corps d'une AUTRE
		# tenue passaient pour une dérive et sortaient de la mesure (le gris de l'Occulteur n'y gardait que 180 pixels,
		# 2026-09-23 21:00).
		var derive: Dictionary = mesurer_contraste(avec, bis, avec)["masque"]
		var union := {}
		for cle in prises:
			union.merge(mesurer_contraste(prises[cle], sans, prises[cle])["masque"])
		for p in derive:
			union.erase(p)
		var mg := mesurer_contraste(prises["gris"], sans, prises["gris"], union)
		for paire in tenues:
			var nom := "%s/%s" % paire
			var mp := mesurer_contraste(prises[nom], sans, prises[nom], union)
			print("BANC_ISO_CONTRASTE_CLASSE %s tenue=%s distance=%d décalage=%d | ΔE76 peint %.1f gris %.1f | clarté corps/sol peint %.2f gris %.2f | corps %d/%d px | lum corps peint %.1f gris %.1f"
				% [slug, nom, roundi(_distance_corps), roundi(_decalage_corps), mp["delta_e"], mg["delta_e"], mp["rapport"],
				mg["rapport"], mp["corps_n"], mg["corps_n"], mp["corps_lum"], mg["corps_lum"]])
	for p in garde:
		mat.set_shader_parameter(p, garde[p])
