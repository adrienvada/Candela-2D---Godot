extends RefCounted
## Q75 À L'IMAGE (Adrien, 2026-09-30 20:17 : « A+d ») : le plan `loupe-faisceau-q75` de la loupe.
##
## AVANT (le jeu de `34370f74` : juge du rayon en disque, rayon sur toute la portée — `faisceau_juge_taille` et
## `faisceau_air_court` faux, qui rendent ce code-là octet pour octet) contre APRÈS (A+D, le défaut), basculés SUR PLACE dans
## un même lancement, à cadrage identique : la méthode de `loupe_faisceau_taille.gd` — scène tenue, grain du rayon figé
## (`age_faisceau_fige`), bandeau LED figé (`--led-murs-fige`), puis le jeu EN PAUSE pendant les prises (l'interface arrêtée,
## les volumes iso suivis à la main). Dans chaque bloc : av ap av ap (deux fois chacun : la scène tenue se vérifie), puis s,
## sans le rayon (le noir de référence). Jugé par `tools/faisceau_q75/preuve.py`, qui fait aussi la planche.
##
## Les blocs, en écran scindé à 45° B (J1 à gauche, J2 à droite), pour trois classes aux deux joueurs — le Terrassier
## (192 px dans la 0.7.1), la Sentinelle (499 px) et le Braconnier (672 px) ; la portée d'aujourd'hui est le plancher, 728 px :
## - `<classe>-j1` : la lampe de J1 seule — sa vue SOUS SA TORCHE, et celle de J2 DANS LE NOIR, qui voit le rayon adverse ;
## - `<classe>-j2` : la lampe de J2 seule — l'inverse ;
## - `fusee` (vue unique, le Terrassier) : les deux lampes et une fusée posée entre les joueurs — ce que A rend à la fumée ;
## - `pixel` : le cadrage du bloc `s1` de `loupe-faisceau-taille`, pour le pixel où le juge taillé s'écartait de 15/255
##   (rayon long, comme alors) : b (juge en disque), j (taillé), n (sans juge : les couches seules, au pochoir vide), n0 n1 n2
##   (une couche seule, sans juge), j30 (le juge taillé dilaté de 30 px de plus), s (sans le rayon), ap (A+D).
## Chaque prise imprime `FAISCEAU_Q75 <bloc>-<mode> …` ; les images vont dans `user://photos/`.
##
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tools/photographe.tscn -- --plan=loupe-faisceau-q75 \
##         --led-murs-fige --taille=1920x1080

const ID := "loupe-faisceau-q75"
## L'âge figé du grain du rayon pendant la preuve (secondes) : celui de `loupe-faisceau-taille`, le même pour chaque prise.
const AGE_FIGE := 12.5
const AGE_FUSEE := 9.0
## Les trois classes de la planche : les deux bouts de l'échelle des longueurs et le milieu.
const CLASSES := ["pompe", "sentinelle", "arbalete"]
## Le juge du bloc `pixel`, dilaté de plus (pixels de monde) : si le pixel tient, ce n'est pas la couverture.
const DILATATION_EN_PLUS := 30.0

var l: RefCounted   # la loupe (`tools/loupe.gd`)
var p: Node         # le photographe
var volumes: Object
var _pos := [Vector2.ZERO, Vector2.ZERO]
var _visee := [Vector2.UP, Vector2.RIGHT]
var _torche := [false, false]
## Ce que le mode de la prise impose aux volumes juste après leur suivi (sans juge, une couche seule, un juge plus large).
var _apres_suivi := Callable()


func jouer(loupe: RefCounted, plans: Array[Dictionary]) -> void:
	l = loupe
	p = loupe.p
	var m: Node = p._main
	var pres := Presentation3D.instance()
	var miroirs: Object = pres.get("_miroirs") if pres != null else null
	volumes = miroirs.get("volumes") if miroirs != null else null
	if volumes == null:
		printerr("  ✗ %s : volumes iso introuvables" % ID)
		return
	var avant := [volumes.get("faisceau_taille"), volumes.get("faisceau_juge_taille"), volumes.get("faisceau_air_court")]
	volumes.set("age_faisceau_fige", AGE_FIGE)
	var armes_avant := [m.p1.current_weapon, m.p2.current_weapon]
	var j1: Vector2 = l.get("_j1")
	var t := MursBas.TUILE
	MurLed.est_actif()
	print("  · %s : J1 %s ; bandeau LED %s ; plancher de portée %.1f px" % [ID, str(j1),
		"figé à %.2f de son sommet" % MurLed._fige if MurLed._fige >= 0.0 else "qui RESPIRE (--led-murs-fige manque)",
		WeaponData.portee_plancher])
	var a_cote := j1 + Vector2(-3.0 * t, 0.0)
	p._deux_vues()
	# Le pixel de l'allègement d'abord : le cadrage du bloc `s1` de `loupe-faisceau-taille` (le Terrassier aux deux joueurs,
	# la lampe de J1 seule, visée au nord-ouest), le rayon long comme alors.
	_equiper(m, "pompe")
	_poser(j1, a_cote, Vector2(-0.6, -1.0), Vector2(-0.6, -1.0), true, false)
	await _bloc_pixel(plans)
	for slug: String in CLASSES:
		_equiper(m, slug)
		_poser(j1, a_cote, Vector2(-0.6, -1.0), Vector2(-0.6, -1.0), true, false)
		await _bloc(plans, "%s-j1" % slug)
		_poser(j1, a_cote, Vector2(-0.6, -1.0), Vector2(-0.6, -1.0), false, true)
		await _bloc(plans, "%s-j2" % slug)
	p._vue_unique()
	# La fumée d'une fusée posée entre les deux joueurs, les deux lampes allumées (le bloc `fusee` de l'allègement).
	_equiper(m, "pompe")
	var fusee := _poser_la_fusee(m, (j1 + a_cote) * 0.5 + Vector2(0.0, -1.2 * t))
	_poser(j1, a_cote, Vector2(-0.3, -1.0), Vector2(0.3, -1.0), true, true)
	await _bloc(plans, "fusee")
	if fusee != null and is_instance_valid(fusee):
		fusee.queue_free()
	await p._ranger_les_gadgets()

	volumes.set("faisceau_taille", avant[0])
	volumes.set("faisceau_juge_taille", avant[1])
	volumes.set("faisceau_air_court", avant[2])
	volumes.set("age_faisceau_fige", -1.0)
	m.set("_killcam_cadrage_tenu", false)
	for k in 2:
		if armes_avant[k] != null:
			(m.p1 if k == 0 else m.p2).equip_weapon(armes_avant[k])


func _equiper(m: Node, slug: String) -> void:
	for c in m.classes():
		if c != null and String(c.slug()) == slug:
			m.p1.equip_weapon(c)
			m.p2.equip_weapon(c)
	var arme: WeaponData = m.p1.current_weapon
	print("  · %s : classe %s aux deux joueurs — longueur de la 0.7.1 %.1f px, portée %.1f px" % [ID, slug,
		arme.portee_sans_plancher(), arme.portee_torche()])


func _poser(pos1: Vector2, pos2: Vector2, visee1: Vector2, visee2: Vector2, torche1: bool, torche2: bool) -> void:
	_pos = [pos1, pos2]
	_visee = [visee1.normalized(), visee2.normalized()]
	_torche = [torche1, torche2]


## Une fusée posée, figée à `AGE_FUSEE` de sa combustion (sa physique coupée : ni l'âge ni la fumée ne bougent entre les prises).
func _poser_la_fusee(m: Node, lieu: Vector2) -> Node2D:
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", lieu)
	f.set("direction", Vector2.DOWN)
	f.set("joueurs", [m.p1, m.p2])
	m.bullet_container.add_child(f)
	f.set_physics_process(false)
	f.global_position = lieu
	f.call("forcer_age", AGE_FUSEE)
	print("  · %s : fusée posée en %s, figée à %.1f s" % [ID, str(lieu), AGE_FUSEE])
	return f


## La scène tenue à chaque image (positions, visées, lampes voulues, respiration de la torche à zéro).
func _tenir() -> void:
	var m: Node = p._main
	if not is_instance_valid(m.p1) or not is_instance_valid(m.p2):
		return
	m.p1.global_position = _pos[0]
	m.p2.global_position = _pos[1]
	for k in 2:
		(m.p1 if k == 0 else m.p2).set("_torch_breath_t", 0.0)
		p._viser(k, _visee[k])
		if k < p._pantins.size():
			p._pantins[k].torche = _torche[k]
		var action := "p%d_torch" % (k + 1)
		if _torche[k]:
			Input.action_press(action)
		else:
			Input.action_release(action)
			(m.p1 if k == 0 else m.p2).flashlight_on = false
	p._vivants()


## La scène tenue jusqu'à ce que caméras, éblouissements et lampes ne bougent plus (trente pas de suite), puis le jeu en
## pause et l'interface arrêtée (voir `loupe_faisceau_taille.gd` : le voile respire avec son propre temps). Rend le mode
## d'avant de l'interface, à rendre par `_reprendre`.
func _figer(nom: String) -> int:
	var m: Node = p._main
	volumes.set("faisceau_taille", true)
	volumes.set("faisceau_juge_taille", false)
	volumes.set("faisceau_air_court", false)
	_apres_suivi = Callable()
	m.set("_killcam_cadrage_tenu", false)
	var reperes := []
	var tenues := 0
	var images := 0
	while tenues < 30 and images < 900:
		_tenir()
		await p.get_tree().physics_frame
		await p.get_tree().process_frame
		images += 1
		var o := [(m.vp1 as SubViewport).canvas_transform.origin, (m.vp2 as SubViewport).canvas_transform.origin,
			snappedf(float(m.p1.dazzle_amount), 0.0001), snappedf(float(m.p2.dazzle_amount), 0.0001),
			(m.p1.get_node(^"Flashlight") as PointLight2D).energy, (m.p2.get_node(^"Flashlight") as PointLight2D).energy]
		tenues = tenues + 1 if o == reperes else 0
		reperes = o
	m.set("_killcam_cadrage_tenu", true)
	print("  · %s-%s : scène %s après %d pas ; éblouissement J1 %.4f J2 %.4f ; lampes J1 %s J2 %s" % [ID, nom,
		"tenue" if tenues >= 30 else "ENCORE EN MOUVEMENT", images, float(m.p1.dazzle_amount), float(m.p2.dazzle_amount),
		_torche[0], _torche[1]])
	var interface: Node = m.get("ui")
	var mode_interface := interface.process_mode if interface != null else Node.PROCESS_MODE_INHERIT
	_tenir()
	p.get_tree().paused = true
	if interface != null:
		interface.process_mode = Node.PROCESS_MODE_DISABLED
	return mode_interface


func _reprendre(mode_interface: int) -> void:
	volumes.set("faisceau_air", true)
	volumes.set("faisceau_taille", true)
	volumes.set("faisceau_juge_taille", true)
	volumes.set("faisceau_air_court", true)
	_apres_suivi = Callable()
	var interface: Node = p._main.get("ui")
	if interface != null:
		interface.process_mode = mode_interface
	p.get_tree().paused = false


## Un bloc : av ap av ap (avant, après), puis s (sans le rayon).
func _bloc(plans: Array[Dictionary], nom: String) -> void:
	var mode_interface: int = await _figer(nom)
	var n := 0
	for apres in [false, true, false, true]:
		n += 1
		await _prise(plans, nom, "%d%s" % [n, "ap" if apres else "av"], apres, apres, apres,
			"après (A+D)" if apres else "avant (34370f74)")
	await _sans_rayon(plans, nom, "5s")
	_reprendre(mode_interface)


## Le pixel de l'allègement (écran scindé, lampe de J1, le Terrassier) : les modes de diagnostic, rayon long.
func _bloc_pixel(plans: Array[Dictionary]) -> void:
	var nom := "pixel"
	var mode_interface: int = await _figer(nom)
	await _prise(plans, nom, "1b", true, false, false, "juge en disque, rayon long (le B de l'allègement)")
	await _prise(plans, nom, "2j", true, true, false, "juge taillé, rayon long (le J de l'allègement)")
	_apres_suivi = _sans_juge.bind(-1)
	await _prise(plans, nom, "3n", true, true, false, "sans juge : les trois couches, pochoir vide")
	for k in 3:
		_apres_suivi = _sans_juge.bind(k)
		await _prise(plans, nom, "%dn%d" % [4 + k, k], true, true, false, "sans juge, la couche %d seule" % k)
	_apres_suivi = _juge_plus_large
	await _prise(plans, nom, "7j30", true, true, false, "juge taillé dilaté de %.0f px de plus" % DILATATION_EN_PLUS)
	_apres_suivi = Callable()
	await _prise(plans, nom, "8b", true, false, false, "juge en disque, rayon long (encore : la scène tenue)")
	await _prise(plans, nom, "9ap", true, true, true, "après (A+D)")
	await _sans_rayon(plans, nom, "10s")
	_reprendre(mode_interface)


## Une prise du rayon, dans un mode : couches taillées ou non, juge taillé ou non, rayon court ou non.
func _prise(plans: Array[Dictionary], nom: String, suffixe: String, taille: bool, juge_taille: bool, court: bool,
		mode: String) -> void:
	volumes.set("faisceau_air", true)
	volumes.set("faisceau_taille", taille)
	volumes.set("faisceau_juge_taille", juge_taille)
	volumes.set("faisceau_air_court", court)
	for k in 3:
		_tenir_en_pause()
		await p.get_tree().process_frame
	await l._prise_entiere(plans, ID, "%s-%s" % [nom, suffixe], 0.4, _tenir_en_pause)
	var details := []
	for s: Dictionary in volumes.call("suivis"):
		if String(s["genre"]) != "faisceau_air":
			continue
		var noeuds: Array = s["noeuds"]
		var mat := (noeuds[0] as MeshInstance3D).material_override as ShaderMaterial if not noeuds.is_empty() else null
		var juge: MeshInstance3D = s.get("juge")
		var forme_juge := "aucun"
		if juge != null and juge.visible:
			forme_juge = "disque" if juge.mesh == volumes.call("_disque") else ("plan" if juge.mesh is PlaneMesh else "éventail")
		details.append("rayon (portée %.1f, longueur de la couche basse %s, juge %s)" % [
			float(mat.get_shader_parameter("nuage_rayon")) if mat != null else 0.0,
			("%.1f" % float(mat.get_shader_parameter("longueur_air"))) if mat != null
				and float(mat.get_shader_parameter("longueur_air")) < 1.0e8 else "entière", forme_juge])
	print("  FAISCEAU_Q75 %s-%s mode %s : %s" % [nom, suffixe, mode, ", ".join(details) if not details.is_empty()
		else "aucun rayon"])


## Une prise SANS le rayon (`faisceau_air` coupé sur place) : le noir de référence.
func _sans_rayon(plans: Array[Dictionary], nom: String, suffixe: String) -> void:
	volumes.set("faisceau_air", false)
	_apres_suivi = Callable()
	for k in 3:
		_tenir_en_pause()
		await p.get_tree().process_frame
	await l._prise_entiere(plans, ID, "%s-%s" % [nom, suffixe], 0.4, _tenir_en_pause)
	print("  FAISCEAU_Q75 %s-%s mode sans rayon" % [nom, suffixe])
	volumes.set("faisceau_air", true)


## Diagnostic du bloc `pixel` : le juge caché (le pochoir reste vide), et toutes les couches ou la seule couche `seule`.
func _sans_juge(seule: int) -> void:
	for s: Dictionary in volumes.call("suivis"):
		if String(s["genre"]) != "faisceau_air":
			continue
		var juge: MeshInstance3D = s.get("juge")
		if juge != null:
			juge.visible = false
		if seule >= 0:
			for k in (s["noeuds"] as Array).size():
				(s["noeuds"][k] as MeshInstance3D).visible = k == seule


## Diagnostic du bloc `pixel` : le juge taillé, dilaté de `DILATATION_EN_PLUS` pixels de monde de plus que la parallaxe.
func _juge_plus_large() -> void:
	for s: Dictionary in volumes.call("suivis"):
		if String(s["genre"]) != "faisceau_air":
			continue
		var juge: MeshInstance3D = s.get("juge")
		var noeuds: Array = s["noeuds"]
		if juge == null or noeuds.is_empty():
			continue
		var mat := (noeuds[0] as MeshInstance3D).material_override as ShaderMaterial
		var tex := mat.get_shader_parameter("masque") as Texture2D
		var rayon := float(mat.get_shader_parameter("nuage_rayon"))
		var env: PackedFloat32Array = IsoVolumes.enveloppe_du_cookie(tex)
		juge.mesh = IsoVolumes.eventail(IsoVolumes.enveloppe_dilatee(env,
			(IsoVolumes.decalage_du_juge() + DILATATION_EN_PLUS) / maxf(rayon, 1.0)))


## La scène tenue, jeu en pause : et les volumes iso suivis à la main, comme `Presentation3D._process` le fait en jeu, puis le
## mode de diagnostic de la prise.
func _tenir_en_pause() -> void:
	_tenir()
	var pres: Node = Presentation3D.instance()
	if pres == null or volumes == null:
		return
	var ids := []
	for vue: SubViewport in pres.get("_vues"):
		ids.append(pres.call("_id_de", vue))
	volumes.call("suivre", p._main, ids, int(pres.get("style_pate")), pres)
	if _apres_suivi.is_valid():
		_apres_suivi.call()
