extends "res://tools/photographe.gd"
## Q33 — LA PLANCHE DES PERSONNAGES DÉTAILLÉS AU DUEL (session cloud q33, 2026-09-27).
##
## Les dix classes EN JEU, avec et sans `--corps-detaille`, au même instant et au même cadrage : le vrai `main.tscn`,
## la vraie présentation iso (45° B, cadrage ×1,5 du jeu), la vraie torche de J1, les vrais capteurs de corps. Seul le
## personnage détaillé bascule, dans le MÊME processus (`VoxelCatalogue.forcer_detail`, corps reconstruits sur place).
##
##   GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
##     /usr/local/bin/godot --fixed-fps 60 --path . res://tools/planche_q33.tscn -- --sortie=user://q33 --led-murs-fige=0.5
##
## Hérite du photographe pour sa fenêtre, son horloge, ses marionnettes et sa carte du duel ; ne touche à AUCUN de
## ses plans (son `_ready` est remplacé, son catalogue n'est pas lu).
##
## ## Les scènes, pour chaque classe X
## - J1 est le Parasite (pistolet) pour toutes les prises de l'adversaire : la MÊME torche éclaire les dix classes, aux
##   mêmes positions (trouvées une fois). J2 (classe X), torche éteinte, dans l'axe du cône de J1 :
##   `mi` à la moitié de la portée ; `b15` et `b10` au bord de la lumière, là où le capteur du corps lit 0,15 et 0,10
##   (le seuil commun des dix classes, Q32) ; `noir` au-delà de la portée, où le capteur lit 0.
## - `soi` : J1 est de la classe X, sous sa propre torche ; J2 loin, hors du cadre.
##
## ## Trois images par scène et par mode (détail éteint `d0`, allumé `d1`)
## - `reel` : ce que le jeu montre ;
## - `sil` : le même instant, le corps regardé forcé à la pleine lumière (`capteur_actif` coupé, `lumiere_recue` 1,
##   opacité 1) — sa SILHOUETTE, pour compter ses pixels et comparer son contour avec et sans détail ;
## - une fois par scène (sans corps) `vide` : le corps regardé caché — le sol seul.
##
## ## Le même instant
## Deux choses du jeu bougent seules entre deux prises, et les deux sont figées ici, pour les deux modes :
## - la respiration des corps (`VoxelCorps._poser_repos`, lue sur l'horloge murale `Time.get_ticks_msec`) : reposée à t = 0
##   juste avant chaque rendu (`frame_pre_draw`), comme le banc des corps le fait avec `--temps-fixe` ;
## - le souffle de la torche (±3 %, `player.gd`, un bruit à graine aléatoire) : sa fréquence posée à 0, énergie constante.
## - la respiration du bandeau LED des murs, qui éclaire aussi les marquages du sol : tenue par le drapeau du jeu
##   `--led-murs-fige=0.5` (à passer sur la ligne de commande, voir plus haut) ;
## - la poussière du faisceau, tirée au hasard à chaque image : la graine reposée avant chaque prise.
## Un contrôle (`ctl`) reprend la scène `mi` deux fois dans le même mode : l'écart entre ces deux prises est le bruit de fond.
##
## ## Le niveau de lumière
## Lu dans le capteur du corps dans la vue de J1 (`CapteurCorps`, 256 texels pour 128 px) : la moyenne, sur l'anneau où
## le shader des corps lit (`lecture_au_bord`, `rayon_lu_px`), du plus fort des trois canaux. C'est l'équivalent en jeu du
## `lumiere_recue` du banc des corps, pas une identité : le corps lit chaque fragment dans SA direction, et au bord du
## cône l'anneau n'est pas uniforme. Le rapport imprime aussi le maximum de l'anneau.

const SLUGS := ["pistolet", "fusil", "pompe", "arbalete", "occulteur", "fumiste", "incendiaire", "sentinelle",
	"allumeur", "spectre"]
const NIVEAUX := {"b15": 0.15, "b10": 0.10}
const IMAGES_POSE := 6

var _iso: Presentation3D
var _cache_corps := [false, false]      # le corps j caché au prochain rendu
var _sil_corps := [false, false]        # le corps j forcé à la pleine lumière au prochain rendu
var _journal: Array = []
var _j1 := Vector2.ZERO
var _axe := Vector2.RIGHT
var _positions := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_q33 : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://q33")
	var seules := _valeur(args, "--classes", "").strip_edges()
	var slugs: Array = SLUGS if seules == "" else Array(seules.split(","))
	print("=== Planche Q33 ===")
	_poser_la_fenetre()
	await _lire_l_horloge()
	AudioServer.set_bus_mute(0, true)
	VoxelCatalogue.forcer_detail = 0
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = true
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	# L'intro en planches (premier lancement d'un conteneur neuf) et l'allumage, rendus à la main : la première se
	# posait PAR-DESSUS le duel, et la première image de l'essai 1 était une planche d'intro.
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.terminee.emit()
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
		await _attendre_disparition(allumage, 3.0)

	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 20.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	_prendre_les_commandes()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0):
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_torches(true)
	_vue_unique()
	_sans_hud = true
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	await _passer_sur_la_carte_des_murs_bas()
	_iso = Presentation3D.instance()
	if _iso == null:
		printerr("✗ aucune Presentation3D : la vue iso n'est pas en place")
		_sortir(1)
		return
	RenderingServer.frame_pre_draw.connect(_avant_le_rendu)
	for j in [_main.p1, _main.p2]:
		(j.noise as FastNoiseLite).frequency = 0.0

	_equiper(0, "pistolet")
	_equiper(1, "pistolet")
	var arme = _main.p1.current_weapon
	var portee: float = float(arme.portee_torche())
	var demi := float(arme.torch_angle_deg)
	if not _choisir_j1(portee):
		_sortir(1)
		return
	print("  J1 %s, axe %s, portée %.0f px, demi-cône %.0f°, zoom caméra %s" % [str(_j1), str(_axe), portee, demi,
		str(_main.cam1.zoom)])
	await _trouver_les_positions(portee)

	for slug in slugs:
		print("\n--- %s ---" % slug)
		_equiper(1, slug)
		for mode in [0, 1]:
			await _basculer_detail(mode)
			for scene in ["mi", "b15", "b10", "noir"]:
				await _prises_adversaire(slug, mode, scene)
			if mode == 0:
				await _prises_adversaire(slug, mode, "mi", "ctl")
		_equiper(1, "pistolet")
		_equiper(0, slug)
		for mode in [0, 1]:
			await _basculer_detail(mode)
			await _prises_soi(slug, mode)
		_equiper(0, "pistolet")
	await _basculer_detail(0)

	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"j1": [_j1.x, _j1.y], "axe": [_axe.x, _axe.y], "positions": _positions,
		"fenetre": [_taille.x, _taille.y], "commit": _commit(), "prises": _journal}, "  "))
	f.close()
	print("\n%d prise(s) dans %s" % [_journal.size(), ProjectSettings.globalize_path(_dossier)])
	_sortir(0)


# ---------------------------------------------------------------------------
# LA MISE EN SCÈNE
# ---------------------------------------------------------------------------

func _equiper(pid: int, slug: String) -> void:
	var joueur = _main.p1 if pid == 0 else _main.p2
	var i := SLUGS.find(slug)
	for k in 10:
		var c = _main.weapon_for_index(k)
		if c is ClassData and String((c as ClassData).slug()) == slug:
			i = k
			break
	joueur.equip_weapon(_main.weapon_for_index(i))


## Le personnage détaillé allumé (1) ou éteint (0), les deux corps reconstruits sur place par la présentation.
func _basculer_detail(mode: int) -> void:
	VoxelCatalogue.forcer_detail = mode
	for j in 2:
		_iso._mat_corps[j] = null
		_iso._accorder_la_classe(j, _main.p1 if j == 0 else _main.p2)
	await _attendre_images(3)


## Un J1 sur la carte du duel d'où l'axe de visée traverse du sol libre, sans mur ni muret, sur toute la portée et au-delà.
func _choisir_j1(portee: float) -> bool:
	var t := MursBas.TUILE
	_axe = _la_visee()
	var grille := Vector2(MapCodec.get_grid_size(MapData.current_map_data)) * t
	var meilleur := Vector2.INF
	var y := 4.0 * t
	while y < grille.y - 4.0 * t:
		var x := 4.0 * t
		while x < grille.x - 4.0 * t:
			var p := Vector2(x, y)
			if _ligne_libre(p, p + _axe * (portee + 160.0)):
				var d := p.distance_to(grille * 0.5 - _axe * portee * 0.5)
				if meilleur == Vector2.INF or d < meilleur.distance_to(grille * 0.5 - _axe * portee * 0.5):
					meilleur = p
			x += t * 0.5
		y += t * 0.5
	if meilleur == Vector2.INF:
		printerr("✗ aucune ligne de sol libre de %.0f px sur la carte du duel" % (portee + 160.0))
		return false
	_j1 = meilleur
	return true


func _ligne_libre(a: Vector2, b: Vector2) -> bool:
	if not _sol_libre(a) or _mur_entre(a, b):
		return false
	var n := int(a.distance_to(b) / 8.0) + 1
	for m in _main.murs_bas as Array:
		var r := (m as Rect2).grow(24.0)
		for k in n + 1:
			if r.has_point(a.lerp(b, float(k) / float(n))):
				return false
	return true


func _poser(p2: Vector2, j2_dans_le_cadre := true) -> void:
	_main.p1.global_position = _j1
	_viser(0, _axe)
	_main.p2.global_position = p2 if j2_dans_le_cadre else _j1 - _axe * 3000.0
	# J2 regarde de côté, torche éteinte : braquée sur J1, elle l'éblouirait (règle de `_duel`).
	_viser(1, _axe.orthogonal())
	if _pantins.size() > 1:
		_pantins[0].torche = true
		_pantins[1].torche = false
	Input.action_release("p2_torch")
	_main.p2.flashlight_on = false
	_vivants()


func _tenir(p2: Vector2, n: int, j2_dans_le_cadre := true) -> void:
	for i in n:
		_poser(p2, j2_dans_le_cadre)
		await get_tree().process_frame


## Le niveau que lit le corps j dans la vue de J1 : [moyenne de l'anneau, maximum de l'anneau].
func _niveau(j: int) -> Array:
	var c = _iso._capteurs[0][j]
	if c == null:
		return [-1.0, -1.0]
	var img: Image = (c as CapteurCorps).get_texture().get_image()
	var texels_par_px := float(CapteurCorps.TAILLE) / CapteurCorps.MONDE_PX
	var r := minf(Presentation3D.RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0) * texels_par_px
	var centre := Vector2(img.get_width(), img.get_height()) * 0.5
	var somme := 0.0
	var n := 0
	var haut := 0.0
	for a in 64:
		var q := centre + Vector2.from_angle(TAU * float(a) / 64.0) * r
		var px := img.get_pixelv(Vector2i(q))
		var v := maxf(px.r, maxf(px.g, px.b))
		somme += v
		haut = maxf(haut, v)
		n += 1
	return [somme / float(n), haut]


func _niveau_a(p2: Vector2, j := 1) -> Array:
	await _tenir(p2, 4)
	return _niveau(j)


## `mi` à la moitié de la portée ; `b15`, `b10` là où le capteur de J2 lit 0,15 et 0,10 en s'éloignant dans l'axe ;
## `noir` 60 px au-delà du premier point où il lit 0.
func _trouver_les_positions(portee: float) -> void:
	_positions["mi"] = _vers(_j1 + _axe * portee * 0.5)
	var releve := []
	var d := portee * 0.5
	# Le premier relevé suivait un saut de J2 : le capteur n'avait pas encore suivi (0,65 lu, 0,26 juste après).
	await _tenir(_j1 + _axe * d, 20)
	var precedent := (await _niveau_a(_j1 + _axe * d))[0] as float
	releve.append([d, precedent])
	var cibles := NIVEAUX.keys()
	var zero := -1.0
	while d < portee + 400.0:
		var d2 := d + 8.0
		var v := (await _niveau_a(_j1 + _axe * d2))[0] as float
		releve.append([d2, v])
		for cle in cibles.duplicate():
			var cible: float = NIVEAUX[cle]
			if precedent > cible and v <= cible:
				# Dichotomie entre d et d2.
				var lo := d
				var hi := d2
				for k in 5:
					var m := (lo + hi) * 0.5
					var vm := (await _niveau_a(_j1 + _axe * m))[0] as float
					if vm > cible:
						lo = m
					else:
						hi = m
				var mid := (lo + hi) * 0.5
				_positions[cle] = _vers(_j1 + _axe * mid)
				cibles.erase(cle)
		if v <= 0.0 and zero < 0.0:
			zero = d2
		precedent = v
		d = d2
		if cibles.is_empty() and zero > 0.0:
			break
	if zero < 0.0:
		zero = d
	_positions["noir"] = _vers(_j1 + _axe * (zero + 60.0))
	var texte := []
	for r in releve:
		texte.append("%.0f:%.3f" % [r[0], r[1]])
	print("  relevé du capteur de J2 le long de l'axe (distance:niveau) : ", " ".join(texte))
	_positions["releve"] = releve
	for cle in ["mi", "b15", "b10", "noir"]:
		if not _positions.has(cle):
			printerr("  ✗ position %s introuvable" % cle)
			continue
		var p := _de(_positions[cle])
		var niv := await _niveau_a(p)
		print("  %s : %s, à %.1f px de J1, capteur %.3f (max %.3f)" % [cle, str(p), p.distance_to(_j1), niv[0], niv[1]])


func _vers(v: Vector2) -> Array:
	return [v.x, v.y]


func _de(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# ---------------------------------------------------------------------------
# LES PRISES
# ---------------------------------------------------------------------------

## Juste avant le rendu, après le `_process` de la présentation : respiration figée, corps caché ou forcé en pleine lumière.
func _avant_le_rendu() -> void:
	if _iso == null or not is_instance_valid(_iso):
		return
	for j in 2:
		var voxel := _iso._voxels[j] as VoxelCorps
		if voxel != null and _iso._corps[j].visible:
			voxel._poser_repos(0.0, 0.0)
		if _cache_corps[j]:
			_iso._corps[j].visible = false
		var mat := _iso._mat_corps[j] as ShaderMaterial
		if mat == null:
			continue
		if _sil_corps[j]:
			mat.set_shader_parameter("capteur_actif", false)
			mat.set_shader_parameter("lumiere_recue", 1.0)
			for k in [1, 2]:
				mat.set_shader_parameter("opacite_%d" % k, 1.0)
				mat.set_shader_parameter("silhouette_%d" % k, Color(0, 0, 0, 0))
		else:
			mat.set_shader_parameter("capteur_actif", true)


func _prise(nom: String, p2: Vector2, j2_dans_le_cadre: bool, regarde: int, info: Dictionary) -> void:
	# La poussière du faisceau de J1 (`player.gd`, `randf_range` à chaque image) : la même graine avant chaque prise, pour
	# que deux prises du même instant tirent les mêmes grains. Premier essai sans elle : 184 pixels différaient autour du
	# corps entre deux prises identiques.
	seed(33)
	await _tenir(p2, IMAGES_POSE, j2_dans_le_cadre)
	var niv := _niveau(regarde)
	var img: Image = await _capturer("vue")
	if img == null:
		printerr("  ✗ prise perdue : ", nom)
		return
	var chemin := "%s/%s.png" % [_dossier, nom]
	img.save_png(chemin)
	var cam := _iso._camera_de(0)
	var logique := _iso.viewport_ecran(0).get_visible_rect().size
	var taille := Vector2(img.get_size())
	var cible: Vector2 = _j1 if regarde == 0 else p2
	var ecran: Vector2 = cam.vers_ecran(cible, logique, 16.0) * taille / logique
	var ligne := info.duplicate()
	ligne.merge({"fichier": nom + ".png", "niveau": niv[0], "niveau_max": niv[1], "ecran": [ecran.x, ecran.y],
		"corps": [cible.x, cible.y], "taille": [img.get_width(), img.get_height()]})
	_journal.append(ligne)
	print("  · %s  capteur %.3f  écran (%.0f, %.0f)" % [nom, niv[0], ecran.x, ecran.y])


func _prises_adversaire(slug: String, mode: int, scene: String, suffixe := "") -> void:
	if not _positions.has(scene):
		return
	var p2 := _de(_positions[scene])
	var base := "%s_%s_d%d%s" % [slug, scene, mode, ("_" + suffixe) if suffixe != "" else ""]
	var info := {"classe": slug, "scene": scene, "detail": mode, "regarde": 1, "controle": suffixe != ""}
	var i_reel := info.duplicate()
	i_reel["type"] = "reel"
	await _prise(base + "_reel", p2, true, 1, i_reel)
	if suffixe != "":
		return
	_sil_corps[1] = true
	var i_sil := info.duplicate()
	i_sil["type"] = "sil"
	await _prise(base + "_sil", p2, true, 1, i_sil)
	_sil_corps[1] = false
	# Le sol seul, une fois par scène : sans corps, la classe et le mode ne changent rien.
	var vide := "vide_%s" % scene
	if not _journal.any(func(l: Dictionary) -> bool: return l["fichier"] == vide + ".png"):
		_cache_corps[1] = true
		await _prise(vide, p2, true, 1, {"classe": "", "scene": scene, "detail": -1, "regarde": 1, "type": "vide"})
		_cache_corps[1] = false


func _prises_soi(slug: String, mode: int) -> void:
	var p2 := _j1 - _axe * 3000.0
	var base := "%s_soi_d%d" % [slug, mode]
	var info := {"classe": slug, "scene": "soi", "detail": mode, "regarde": 0}
	var i_reel := info.duplicate()
	i_reel["type"] = "reel"
	await _prise(base + "_reel", p2, false, 0, i_reel)
	_sil_corps[0] = true
	var i_sil := info.duplicate()
	i_sil["type"] = "sil"
	await _prise(base + "_sil", p2, false, 0, i_sil)
	_sil_corps[0] = false
	# Le sol seul sous la torche de CETTE classe : son cône n'est pas celui du Parasite.
	_cache_corps[0] = true
	await _prise("vide_soi_%s_d%d" % [slug, mode], p2, false, 0,
		{"classe": slug, "scene": "soi", "detail": mode, "regarde": 0, "type": "vide"})
	_cache_corps[0] = false
