extends RefCounted
## L'ALLÈGEMENT DE LA 0.8.0 À L'IMAGE : le plan `loupe-faisceau-taille` de la loupe (Adrien, 2026-09-30 : « Oui allège d'abord
## avant de publier la 0.8 »).
##
## Le rayon dans l'air de Q41 (`IsoVolumes._suivre_faisceau_air`) basculé SUR PLACE entre les carrés d'avant (A,
## `faisceau_taille` faux) et les couches taillées au cône (B, le défaut), dans un même lancement, la scène tenue : caméras
## posées, éblouissements et lampes immobiles, respiration de la torche et grain du rayon figés (`age_faisceau_fige`, un
## instrument de preuve), bandeau LED figé (`--led-murs-fige`), puis le jeu EN PAUSE pendant les prises (l'interface arrêtée,
## les volumes iso suivis à la main : voir `_bloc`). Dans chaque bloc : A B A B A, puis J — l'OPTION du juge taillé
## (`faisceau_juge_taille`), qui n'est pas le défaut —, puis S, sans le rayon (ce qu'il ajoute lui-même, pour que le zéro ne
## soit pas vide). Critère écrit d'avance, jugé par `tools/faisceau_taille/preuve.py` : **chaque B vaut ses A voisines à
## 1/255 près** — l'arrondi de l'interpolation, qui suit les triangles —, et les A valent entre elles au pixel près (sinon la
## scène a bougé et le bloc ne se juge pas), sous la torche comme dans le noir. J se mesure, il ne se juge pas.
##
## Les blocs, tous à la classe du défaut du photographe (le Terrassier, le cône le plus large) :
## - `sien` : vue unique (J1), la lampe de J1 seule — son propre rayon ;
## - `adv` : vue unique, la lampe de J2 seule — le rayon ADVERSE vu de J1 ;
## - `deux` : vue unique, les deux lampes — les deux rayons, qui se croisent ;
## - `s1` / `s2` : écran scindé, la lampe de J1 (puis de J2) seule — chaque rayon vu des deux vues (J1 à 45°, J2 à 225°) ;
## - `fusee` : vue unique, les deux lampes et une fusée posée entre les deux joueurs — la fumée de la fusée lit le pochoir que
##   tous les juges écrivent, celui du rayon compris : c'est là que le juge taillé (J) change la fumée ;
## - `eq` : l'équité — J2 derrière un pilier, lampe allumée, hors de vue de J1 ; J1 lampe éteinte.
## Chaque prise imprime `FAISCEAU_TAILLE <prise> mode <…>` ; les images vont dans `user://photos/` (suffixes 1a, 2b, 3a, 4b,
## 5a, 6j, 7s).
##
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tools/photographe.tscn -- --plan=loupe-faisceau-taille \
##         --led-murs-fige --taille=1920x1080

const ID := "loupe-faisceau-taille"
## L'âge figé du grain du rayon pendant la preuve (secondes) : n'importe lequel, le même pour A et B.
const AGE_FIGE := 12.5
const AGE_FUSEE := 9.0

var l: RefCounted   # la loupe (`tools/loupe.gd`)
var p: Node         # le photographe
var volumes: Object
var _pos := [Vector2.ZERO, Vector2.ZERO]
var _visee := [Vector2.UP, Vector2.RIGHT]
var _torche := [false, false]


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
	var taille_avant: bool = volumes.get("faisceau_taille")
	var juge_avant: bool = volumes.get("faisceau_juge_taille")
	volumes.set("age_faisceau_fige", AGE_FIGE)
	# Le Terrassier aux deux joueurs : le cône le plus large (60°), donc l'éventail le plus grand.
	var armes_avant := [m.p1.current_weapon, m.p2.current_weapon]
	for c in m.classes():
		if c != null and String(c.slug()) == "pompe":
			m.p1.equip_weapon(c)
			m.p2.equip_weapon(c)
	var pilier: Rect2 = l.get("_pilier")
	var j1: Vector2 = l.get("_j1")
	var t := MursBas.TUILE
	MurLed.est_actif()
	print("  · %s : pilier %s, J1 %s ; bandeau LED %s ; classe J1 %s, J2 %s" % [ID, str(pilier), str(j1),
		"figé à %.2f de son sommet" % MurLed._fige if MurLed._fige >= 0.0 else "qui RESPIRE (--led-murs-fige manque)",
		m.p1.current_weapon.slug() if m.p1.current_weapon != null else "?",
		m.p2.current_weapon.slug() if m.p2.current_weapon != null else "?"])
	var a_cote := j1 + Vector2(-3.0 * t, 0.0)
	# Son propre rayon, vue unique : la lampe de J1 seule, visée au nord-ouest, loin du pilier.
	_poser(j1, a_cote, Vector2(-0.6, -1.0), Vector2.DOWN, true, false)
	await _bloc(plans, "sien", false)
	# Le rayon adverse vu de J1 : J2 vise le nord-ouest, J1 le nord, lampe éteinte.
	_poser(j1, a_cote, Vector2.UP, Vector2(-0.6, -1.0), false, true)
	await _bloc(plans, "adv", false)
	# Les deux rayons, qui se croisent devant J1 : J2 vise le nord-est, J1 le nord-ouest.
	_poser(j1, a_cote, Vector2(-0.6, -1.0), Vector2(0.7, -1.0), true, true)
	await _bloc(plans, "deux", false)
	# L'écran scindé : chaque lampe seule, vue des deux moitiés.
	p._deux_vues()
	_poser(j1, a_cote, Vector2(-0.6, -1.0), Vector2(-0.6, -1.0), true, false)
	await _bloc(plans, "s1", true)
	_poser(j1, a_cote, Vector2(-0.6, -1.0), Vector2(-0.6, -1.0), false, true)
	await _bloc(plans, "s2", true)
	p._vue_unique()
	# La fumée d'une fusée posée entre les deux joueurs, les deux lampes allumées.
	var fusee := _poser_la_fusee(m, (j1 + a_cote) * 0.5 + Vector2(0.0, -1.2 * t))
	_poser(j1, a_cote, Vector2(-0.3, -1.0), Vector2(0.3, -1.0), true, true)
	await _bloc(plans, "fusee", false)
	if fusee != null and is_instance_valid(fusee):
		fusee.queue_free()
	await p._ranger_les_gadgets()
	# L'équité : J2 derrière le pilier, hors de vue de J1, lampe allumée ; J1 lampe éteinte.
	var derriere := Vector2(pilier.get_center().x, pilier.position.y - 0.8 * t)
	_poser(j1, derriere, Vector2.UP, Vector2.RIGHT, false, true)
	await _bloc(plans, "eq", false)

	volumes.set("faisceau_taille", taille_avant)
	volumes.set("faisceau_juge_taille", juge_avant)
	volumes.set("age_faisceau_fige", -1.0)
	m.set("_killcam_cadrage_tenu", false)
	for k in 2:
		if armes_avant[k] != null:
			(m.p1 if k == 0 else m.p2).equip_weapon(armes_avant[k])


func _poser(pos1: Vector2, pos2: Vector2, visee1: Vector2, visee2: Vector2, torche1: bool, torche2: bool) -> void:
	_pos = [pos1, pos2]
	_visee = [visee1.normalized(), visee2.normalized()]
	_torche = [torche1, torche2]


## Une fusée posée, figée à `AGE_FUSEE` de sa combustion (sa physique coupée : ni l'âge ni la fumée ne bougent entre A et B).
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


## La scène tenue à chaque image (positions, visées, lampes voulues, respiration de la torche à zéro) — comme
## `loupe_faisceau_air.gd`.
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


## Un bloc : la scène tenue jusqu'à ce que caméras, éblouissements et lampes ne bougent plus (trente pas de suite), puis, jeu
## en pause : A B A B A (carrés, éventails), J (l'option du juge taillé, `faisceau_juge_taille`) et S (sans le rayon), chaque
## prise après trois images au nouveau maillage.
func _bloc(plans: Array[Dictionary], nom: String, scinde: bool) -> void:
	var m: Node = p._main
	volumes.set("faisceau_taille", false)
	volumes.set("faisceau_juge_taille", false)
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
	print("  · %s-%s : %s ; scène %s après %d pas ; éblouissement J1 %.4f J2 %.4f ; lampes J1 %s J2 %s" % [ID, nom,
		"écran scindé" if scinde else "vue unique", "tenue" if tenues >= 30 else "ENCORE EN MOUVEMENT", images,
		float(m.p1.dazzle_amount), float(m.p2.dazzle_amount), _torche[0], _torche[1]])
	# ⚠️ **Le jeu EN PAUSE pour les prises** (premier lancement, 2026-09-30 15:00 : les trois A d'un même bloc différaient sur 70
	# à 90 % des pixels). La scène « tenue » bougeait encore : le voile d'éblouissement respire avec son propre temps
	# (`_voile_temps` de l'interface, qui tourne même en pause) et soulève tout l'écran de 2 à 4/255 dès que la torche de J1 est
	# allumée (sa rétrodiffusion le tient à 0,06) ; le chronomètre change ; les corps respirent. Donc l'arbre en pause (corps,
	# éblouissement, chronomètre, présentation iso), l'interface arrêtée (le voile garde ses derniers paramètres), et les
	# volumes iso — ce qui pose les couches du rayon, carrées ou taillées — suivis À LA MAIN à chaque image (`_tenir_en_pause`).
	# Laisser tourner toute la présentation iso (deuxième lancement) laissait respirer les corps : du bruit sur leurs bords.
	var interface: Node = m.get("ui")
	var mode_interface := interface.process_mode if interface != null else Node.PROCESS_MODE_INHERIT
	_tenir()
	p.get_tree().paused = true
	if interface != null:
		interface.process_mode = Node.PROCESS_MODE_DISABLED
	var n := 0
	for taille in [false, true, false, true, false]:
		n += 1
		await _prise(plans, nom, "%d%s" % [n, "b" if taille else "a"], taille, false, "taillé" if taille else "carré")
	# L'option du juge taillé : ce qu'elle change, pour la mettre sous les yeux d'Adrien (elle n'est pas le défaut).
	await _prise(plans, nom, "6j", true, true, "taillé, juge taillé (option)")
	# Et une prise SANS le rayon (`faisceau_air` coupé sur place) : ce que le rayon ajoute à l'image, pour le mettre en regard
	# de ce que l'allègement y change.
	volumes.set("faisceau_air", false)
	for k in 3:
		_tenir_en_pause()
		await p.get_tree().process_frame
	await l._prise_entiere(plans, ID, "%s-7s" % nom, 0.4, _tenir_en_pause)
	print("  FAISCEAU_TAILLE %s-%s-7s mode sans rayon" % [ID, nom])
	volumes.set("faisceau_air", true)
	volumes.set("faisceau_taille", true)
	volumes.set("faisceau_juge_taille", false)
	if interface != null:
		interface.process_mode = mode_interface
	p.get_tree().paused = false


## Une prise du rayon, dans un mode : couches taillées ou non, juge taillé ou non.
func _prise(plans: Array[Dictionary], nom: String, suffixe: String, taille: bool, juge_taille: bool, mode: String) -> void:
	volumes.set("faisceau_taille", taille)
	volumes.set("faisceau_juge_taille", juge_taille)
	for k in 3:
		_tenir_en_pause()
		await p.get_tree().process_frame
	await l._prise_entiere(plans, ID, "%s-%s" % [nom, suffixe], 0.4, _tenir_en_pause)
	var couches := 0
	var eventails := 0
	var juges_tailles := 0
	for s: Dictionary in volumes.call("suivis"):
		if String(s["genre"]) == "faisceau_air":
			for mi: MeshInstance3D in s["noeuds"]:
				couches += 1
				if not (mi.mesh is PlaneMesh):
					eventails += 1
			# Le disque ajusté d'avant est lui aussi un ArrayMesh : c'est l'éventail du juge qu'on cherche.
			var juge: MeshInstance3D = s.get("juge")
			if juge != null and juge.mesh != volumes.call("_disque") and not (juge.mesh is PlaneMesh):
				juges_tailles += 1
	print("  FAISCEAU_TAILLE %s-%s-%s mode %s : %d couche(s) de rayon, dont %d en éventail ; %d juge(s) taillé(s)" % [ID, nom,
		suffixe, mode, couches, eventails, juges_tailles])


## La scène tenue, jeu en pause : et les volumes iso suivis à la main, comme `Presentation3D._process` le fait en jeu.
func _tenir_en_pause() -> void:
	_tenir()
	var pres: Node = Presentation3D.instance()
	if pres == null or volumes == null:
		return
	var ids := []
	for vue: SubViewport in pres.get("_vues"):
		ids.append(pres.call("_id_de", vue))
	volumes.call("suivre", p._main, ids, int(pres.get("style_pate")), pres)
