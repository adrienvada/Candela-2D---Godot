## Q42 — le corps ignore sa propre ombre (Adrien, 2026-09-29).
##
## Sans rien rendre — `--headless` ne rastérise pas, et ce que le GPU met dans un capteur se prouve au banc
## (`tools/planche_q42.gd`, sous Xvfb : niveaux du capteur avant/après, lightmaps identiques au pixel). Ici, la RÈGLE, lue
## sur les objets vivants du jeu, et son effet, calculé par la règle du moteur sur les vraies formes :
##   • **la structure** : l'étoile de chaque joueur vit dans SA canvas (`EtoileDeCorps`), enfant du joueur, avec le masque de
##     sa couche et sa forme ; elle suit le corps (position, rotation) et sa visibilité ;
##   • **la règle** : chaque étoile est rattachée à `vp2` et à tous les capteurs SAUF ceux de son propre corps — les quatre
##     capteurs de l'écran scindé, les deux de la vue unique ; miroir exact entre J1 et J2 ; un leurre a la sienne, et son
##     capteur à lui ne la voit pas ;
##   • **l'effet, par la règle du moteur** (une lumière ombre un point si le segment lampe → point coupe un occluder de son
##     masque d'ombre que la sous-vue compte — intérieur compris) : sous la torche du porteur, l'anneau où le corps lit sa
##     lumière est ÉCLAIRÉ en entier, pour les dix classes, huit orientations, dans les deux sens (J1 porte et regarde J2,
##     puis J2 porte et regarde J1) ; le même calcul, avec l'étoile dans le monde partagé (l'état d'avant), laisse le
##     Fumiste, l'Incendiaire et l'Occulteur noirs torche du côté de l'arme — le contrôle qui prouve que le calcul VOIT le
##     défaut ;
##   • **ce qui doit rester** : un mur entre la torche et le corps l'ombre toujours ; l'étoile de l'AUTRE joueur aussi ;
##     l'ombre au sol (les vues du duel voient toutes les étoiles) et le disque de torse ne bougent pas ;
##   • la vue de dessus (`--2d`), sans capteur : les étoiles y restent visibles de `vp2` et de la racine.
##
## Lancer : godot --headless --path . --script res://tools/test_ombre_propre.gd
extends SceneTree

const ORIENTATIONS := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
## Les trois classes que le rapport `cloud-ombre-orientation` a vues noires, torche du côté de l'arme.
const CLASSES_NOIRES := ["occulteur", "fumiste", "incendiaire"]
const ANNEAU := 64

var _failures := 0
var _verifications := 0
var _main: Node
var _pres: Node
var _Pres: GDScript
var _Capteur: GDScript


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Q42 : LE CORPS IGNORE SA PROPRE OMBRE ===")
	await process_frame
	_Pres = load("res://presentation_3d.gd")
	_Capteur = load("res://capteur_corps.gd")
	var reglages := root.get_node("GameSettings")
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_main.ui._intended_mode = _mode_local()
	_main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(_main))
	for i in 3:
		await process_frame
	_pres = root.get_node_or_null("Presentation3D")
	_check("la vue iso est allumée en écran scindé (quatre capteurs)",
		_pres != null and bool(_pres.get("_actif")) and bool(_pres.get("_scinde")) and _capteurs().size() == 4)
	if _pres == null or _capteurs().size() != 4:
		_sortir()
		return

	_structure()
	await _suivi()
	_la_regle_scindee()
	await _l_effet()
	await _l_autre_et_le_mur()
	await _le_leurre()
	await _vue_unique()
	await _vue_de_dessus(reglages)
	_sortir()


# ---------------------------------------------------------------------------
# LA STRUCTURE
# ---------------------------------------------------------------------------

func _structure() -> void:
	print("\n--- L'étoile de chaque joueur vit dans SA canvas ---")
	var monde: RID = _main.vp1.world_2d.get_canvas()
	for j in 2:
		var joueur: Node2D = _main.p1 if j == 0 else _main.p2
		var e := joueur.get_node_or_null("OmbreDuCorps") as EtoileDeCorps
		_check("J%d : un calque « OmbreDuCorps » enfant du joueur, propriétaire = J%d" % [j + 1, j + 1],
			e != null and e.proprietaire == joueur)
		if e == null:
			continue
		var occ: LightOccluder2D = joueur.etoile()
		_check("J%d : etoile() rend l'occluder du calque, celui-là même que le calque porte" % (j + 1),
			occ != null and occ == e.occluder and occ.get_parent() == e)
		_check("J%d : sa canvas n'est PAS celle du monde partagé (les capteurs ne la voient pas d'office)" % (j + 1),
			occ.get_canvas() != monde and e.get_canvas() == occ.get_canvas())
		_check("J%d : le masque de sa couche est intact (celui que la torche d'en face lit)" % (j + 1),
			occ.occluder_light_mask == joueur.COUCHE_OCCLUDER_SIENNE
			and (joueur.COUCHE_OCCLUDER_ADVERSE != joueur.COUCHE_OCCLUDER_SIENNE))
		_check("J%d : la torche d'en face l'ombre toujours (couche de l'étoile dans son masque d'ombre)" % (j + 1),
			((_main.p2 if j == 0 else _main.p1).flashlight.shadow_item_cull_mask & occ.occluder_light_mask) != 0)
		_check("J%d : sa forme est l'étoile de 32 rayons de sa silhouette, une ressource à elle" % (j + 1),
			occ.occluder != null and occ.occluder.polygon.size() == 32 and occ.occluder.cull_mode == OccluderPolygon2D.CULL_DISABLED)
		var torse := joueur.get_node_or_null("OccluderTorse") as LightOccluder2D
		_check("J%d : le disque de torse (rétrodiffusion) est resté dans le monde, à sa couche" % (j + 1),
			torse != null and torse.get_canvas() == monde and torse.occluder_light_mask == joueur.COUCHE_TORSE)
	_check("les deux étoiles ont chacune leur canvas", _main.p1.etoile().get_canvas() != _main.p2.etoile().get_canvas())


## L'étoile suit son corps — position et rotation, avant le rendu — et sa visibilité.
func _suivi() -> void:
	print("\n--- Elle suit son corps ---")
	for j in 2:
		var joueur: Node2D = _main.p1 if j == 0 else _main.p2
		var occ: LightOccluder2D = joueur.etoile()
		joueur.global_position += Vector2(123.0, -57.0)
		joueur.global_rotation = 1.234
		for i in 2:
			await process_frame
		_check("J%d : après un déplacement et une rotation, l'étoile est là où est le corps" % (j + 1),
			occ.global_position.distance_to(joueur.global_position) < 0.01
			and absf(angle_difference(occ.global_rotation, joueur.global_rotation)) < 1e-4,
			"étoile %s / %s, corps %s / %s" % [occ.global_position, occ.global_rotation, joueur.global_position, joueur.global_rotation])
		_check("J%d : l'étoile est active tant que le corps est visible" % (j + 1), occ.is_visible_in_tree())
		joueur.hide()
		await process_frame
		_check("J%d : le corps caché, l'étoile cesse d'ombrer (comme quand elle était son enfant direct)" % (j + 1),
			not occ.is_visible_in_tree())
		joueur.show()
		await process_frame
		_check("J%d : le corps revenu, l'étoile revient" % (j + 1), occ.is_visible_in_tree())
		# La suie coupe l'étoile ET le disque de torse : le nœud reste le même, seul `visible` change.
		joueur._couper_l_ombre(true)
		_check("J%d : dans la suie, l'étoile et le disque de torse sont coupés" % (j + 1),
			not occ.visible and not (joueur.get_node("OccluderTorse") as LightOccluder2D).visible)
		joueur._couper_l_ombre(false)
		_check("J%d : hors de la suie, ils reviennent" % (j + 1), occ.visible and (joueur.get_node("OccluderTorse") as LightOccluder2D).visible)


# ---------------------------------------------------------------------------
# LA RÈGLE
# ---------------------------------------------------------------------------

func _capteurs() -> Array:
	var out: Array = []
	for ligne in _pres.capteurs():
		for c in ligne:
			if c != null and is_instance_valid(c):
				out.append(c)
	return out


## Écran scindé : quatre capteurs, quatre vues du duel (`vp1`, `vp2`) ; chaque étoile ne manque qu'aux capteurs de son corps.
func _la_regle_scindee() -> void:
	print("\n--- La règle : chaque étoile est rattachée à tout, SAUF aux capteurs de son propre corps ---")
	var capteurs: Array = _pres.capteurs()
	var proprios_ok := true
	for v in 2:
		for j in 2:
			var c = capteurs[v][j]
			proprios_ok = proprios_ok and c != null and c.proprietaire == (_main.p1 if j == 0 else _main.p2)
	_check("chaque capteur sait quel corps il lit (vue × corps : quatre sur quatre)", proprios_ok)
	for j in 2:
		var joueur: Node2D = _main.p1 if j == 0 else _main.p2
		var e: EtoileDeCorps = joueur.get_node("OmbreDuCorps")
		var vues := e.vues_rattachees()
		_check("étoile de J%d : le viewport où elle vit est vp1 (rattaché par le moteur), et vp2 s'y ajoute" % (j + 1),
			e.get_viewport() == _main.vp1 and vues.has(_main.vp2.get_instance_id()) and not vues.has(_main.vp1.get_instance_id()))
		for v in 2:
			for k in 2:
				var c = capteurs[v][k]
				var voit: bool = vues.has(c.get_instance_id())
				_check("étoile de J%d : le capteur de la vue J%d sous le corps J%d %s" % [j + 1, v + 1, k + 1,
					"NE la voit PAS (c'est son propre corps)" if k == j else "la voit (c'est l'autre corps)"],
					voit == (k != j))
	# L'équité, en une phrase : chaque capteur compte exactement UNE étoile — celle de l'autre corps.
	var comptes := []
	for c in _capteurs():
		var n := 0
		for e in get_nodes_in_group(EtoileDeCorps.GROUPE):
			if (e as EtoileDeCorps).vues_rattachees().has(c.get_instance_id()):
				n += 1
		comptes.append(n)
	_check("chacun des quatre capteurs compte exactement une étoile, celle de l'autre corps : %s" % str(comptes),
		comptes == [1, 1, 1, 1])


# ---------------------------------------------------------------------------
# L'EFFET, PAR LA RÈGLE DU MOTEUR
# ---------------------------------------------------------------------------

## Les occluders qu'une sous-vue compte : ceux du monde partagé, plus les étoiles dont la canvas lui est rattachée. Avec
## `avant`, toutes les étoiles : l'état d'avant Q42, où elles vivaient dans le monde.
func _occluders_vus(sous_vue: Viewport, avant: bool) -> Array:
	var monde: RID = _main.vp1.world_2d.get_canvas()
	var out: Array = []
	for occ in root.find_children("*", "LightOccluder2D", true, false):
		var o := occ as LightOccluder2D
		if o.is_visible_in_tree() and o.get_canvas() == monde:
			out.append(o)
	for e in get_nodes_in_group(EtoileDeCorps.GROUPE):
		var etoile := e as EtoileDeCorps
		if not etoile.occluder.is_visible_in_tree():
			continue
		if avant or etoile.get_viewport() == sous_vue or etoile.vues_rattachees().has(sous_vue.get_instance_id()):
			out.append(etoile.occluder)
	return out


## La forme d'un occluder dans le monde. Celle d'une étoile passe par la transformation de son CORPS : c'est ce que le
## calque recopie avant le rendu, et `_suivi()` vérifie qu'il le fait.
func _forme_monde(occ: LightOccluder2D) -> PackedVector2Array:
	var t: Transform2D = occ.global_transform
	if occ.get_parent() is EtoileDeCorps:
		t = ((occ.get_parent() as EtoileDeCorps).proprietaire as Node2D).global_transform
	return t * occ.occluder.polygon


## La règle de la Light2D : un point est dans l'ombre si le segment lampe → point coupe le bord d'un occluder dont la couche
## est dans le masque d'ombre de la lampe — un point DANS la forme aussi (il faut en franchir le bord pour l'atteindre).
static func _ombre(lampe: Vector2, point: Vector2, forme: PackedVector2Array) -> bool:
	for i in forme.size():
		if Geometry2D.segment_intersects_segment(lampe, point, forme[i], forme[(i + 1) % forme.size()]) != null:
			return true
	return false


## La part de l'anneau où le corps lit sa lumière (64 points, décalés d'un demi-pas pour ne jamais tomber pile sur un
## sommet de l'étoile) que la lampe éclaire, vue par `sous_vue`.
func _part_eclairee(lampe: Light2D, centre: Vector2, sous_vue: Viewport, avant: bool) -> float:
	var rayon: float = minf(float(_Pres.RAYON_CORPS_PX) + 1.0, float(_Capteur.RAYON_PX) - 3.0)
	var formes: Array = []
	for occ in _occluders_vus(sous_vue, avant):
		if ((occ as LightOccluder2D).occluder_light_mask & lampe.shadow_item_cull_mask) != 0:
			formes.append(_forme_monde(occ))
	var eclaires := 0
	for k in ANNEAU:
		var p := centre + Vector2.from_angle(TAU * (float(k) + 0.5) / float(ANNEAU)) * rayon
		var ombree := false
		for f in formes:
			if _ombre(lampe.global_position, p, f):
				ombree = true
				break
		if not ombree:
			eclaires += 1
	return float(eclaires) / float(ANNEAU)


## Les vrais murs sortent du calcul (ils sont testés à part, avec un mur posé exprès) : la scène est le sol nu.
func _murs_du_monde() -> Array:
	var monde: RID = _main.vp1.world_2d.get_canvas()
	var out: Array = []
	for occ in root.find_children("*", "LightOccluder2D", true, false):
		var o := occ as LightOccluder2D
		if o.get_canvas() == monde and o.occluder_light_mask == 1 and not o.get_parent().has_method("etoile"):
			out.append(o)
	return out


func _l_effet() -> void:
	print("\n--- L'effet : sous la torche du porteur, l'anneau du corps est éclairé en entier ---")
	var murs := _murs_du_monde()
	_check("les vrais murs de la carte sont dans le monde partagé (des occluders à la couche du décor)", murs.size() >= 4,
		"%d" % murs.size())
	var visibles := []
	for m in murs:
		visibles.append((m as LightOccluder2D).visible)
		(m as LightOccluder2D).visible = false
	var classes := _classes()
	var capteurs: Array = _pres.capteurs()
	var pires_avant := {}
	var tout_a_1 := true
	var pire_apres := 1.0
	var n_prises := 0
	for porteur in 2:
		var cible := 1 - porteur
		var p_porteur: Node2D = _main.p1 if porteur == 0 else _main.p2
		var p_cible: Node2D = _main.p2 if porteur == 0 else _main.p1
		var sous_vue: Viewport = capteurs[porteur][cible]
		var axe := Vector2.RIGHT.rotated(0.4)
		p_porteur.global_position = Vector2(500.0, 500.0)
		p_porteur.global_rotation = axe.angle()
		p_cible.global_position = p_porteur.global_position + axe * 153.6
		p_porteur.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))
		for slug in classes:
			p_cible.equip_weapon(_main.weapon_for_index(_index_de(slug)))
			var pire_avant_ici := 1.0
			for theta in ORIENTATIONS:
				p_cible.global_rotation = (-axe).rotated(deg_to_rad(theta)).angle()
				var apres := _part_eclairee(p_porteur.flashlight, p_cible.global_position, sous_vue, false)
				var avant := _part_eclairee(p_porteur.flashlight, p_cible.global_position, sous_vue, true)
				n_prises += 1
				tout_a_1 = tout_a_1 and is_equal_approx(apres, 1.0)
				pire_apres = minf(pire_apres, apres)
				pire_avant_ici = minf(pire_avant_ici, avant)
			var cle := "J%d porte / %s" % [porteur + 1, slug]
			pires_avant[cle] = pire_avant_ici
	_check("APRÈS : l'anneau du corps est éclairé à 100 %% dans les %d prises (dix classes × huit orientations × deux sens)"
		% n_prises, tout_a_1, "pire part éclairée : %.3f" % pire_apres)
	# Le contrôle : le même calcul, avec les étoiles dans le monde, VOIT le défaut. Sans lui, « 100 % » ne prouverait rien.
	for porteur in 2:
		for slug in CLASSES_NOIRES:
			var v: float = pires_avant["J%d porte / %s" % [porteur + 1, slug]]
			_check("AVANT (étoile dans le monde) : J%d porte, %s — torche du côté de l'arme, l'anneau tombe à %.0f %%"
				% [porteur + 1, slug, v * 100.0], v < 0.05)
	var au_moins_une_partielle := false
	for cle in pires_avant:
		au_moins_une_partielle = au_moins_une_partielle or (pires_avant[cle] < 0.999)
	_check("AVANT : l'ombre propre existait, pour au moins une classe et une orientation", au_moins_une_partielle)
	# L'équité : la même part, aux deux sens.
	var difference := 0.0
	for slug in classes:
		difference = maxf(difference, absf(float(pires_avant["J1 porte / %s" % slug]) - float(pires_avant["J2 porte / %s" % slug])))
	_check("le défaut d'avant est le même dans les deux sens (J1 porte / J2 porte), écart %.3f" % difference,
		difference < 0.05)
	for i in murs.size():
		(murs[i] as LightOccluder2D).visible = visibles[i]


func _classes() -> Array:
	return ["pistolet", "fusil", "pompe", "arbalete", "occulteur", "fumiste", "incendiaire", "sentinelle", "allumeur", "spectre"]


func _index_de(slug: String) -> int:
	for k in 10:
		var c = _main.weapon_for_index(k)
		if c != null and c.has_method("slug") and String(c.slug()) == slug:
			return k
	return 0


## Ce qui reste : un mur, l'étoile de l'autre corps.
func _l_autre_et_le_mur() -> void:
	print("\n--- Ce qui reste : un mur ombre toujours le corps, l'autre joueur aussi ---")
	var capteurs: Array = _pres.capteurs()
	var axe := Vector2.RIGHT
	var murs := _murs_du_monde()
	var visibles := []
	for m in murs:
		visibles.append((m as LightOccluder2D).visible)
		(m as LightOccluder2D).visible = false
	_main.p1.global_position = Vector2(500.0, 500.0)
	_main.p1.global_rotation = 0.0
	_main.p2.global_position = Vector2(500.0, 500.0) + axe * 153.6
	_main.p2.global_rotation = PI
	_main.p1.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))
	_main.p2.equip_weapon(_main.weapon_for_index(_index_de("fumiste")))
	var torche: Light2D = _main.p1.flashlight
	var c_j2: Viewport = capteurs[0][1]
	_check("sol nu : le corps de J2 est éclairé en entier par la torche de J1",
		is_equal_approx(_part_eclairee(torche, _main.p2.global_position, c_j2, false), 1.0))
	# Un mur, posé comme ceux de la carte (couche du décor, dans le monde partagé), entre la torche et le corps.
	var mur := LightOccluder2D.new()
	var forme := OccluderPolygon2D.new()
	forme.polygon = PackedVector2Array([Vector2(-6, -80), Vector2(6, -80), Vector2(6, 80), Vector2(-6, 80)])
	forme.cull_mode = OccluderPolygon2D.CULL_DISABLED
	mur.occluder = forme
	mur.occluder_light_mask = 1
	mur.position = Vector2(500.0, 500.0) + axe * 90.0
	_main.arena.add_child(mur)
	await process_frame
	_check("un mur entre la torche et le corps : l'anneau est dans l'ombre (0 %), comme avant Q42",
		_part_eclairee(torche, _main.p2.global_position, c_j2, false) < 0.02
		and _part_eclairee(torche, _main.p2.global_position, c_j2, true) < 0.02,
		"%.3f" % _part_eclairee(torche, _main.p2.global_position, c_j2, false))
	_check("et le mur ombre aussi le capteur de J2 dans SA vue (l'ombre du mur ne dépend pas de la vue)",
		_part_eclairee(torche, _main.p2.global_position, capteurs[1][1], false) < 0.02)
	mur.queue_free()
	await process_frame
	# L'autre joueur : la torche de J2 éclaire son propre corps depuis 30 px devant lui ; J1, posé entre les deux, porte son
	# étoile sur cette ligne. Le capteur de J2 (qui voit l'étoile de J1) reste dans l'ombre de J1 ; celui de J1 ne voit
	# pas SA propre étoile (elle n'est pas dans le masque d'ombre de la torche de J2 pour son corps à lui).
	_main.p2.global_position = Vector2(500.0, 500.0) + axe * 153.6
	_main.p2.global_rotation = PI
	_main.p1.global_position = _main.p2.global_position + Vector2.LEFT * 14.0
	_main.p1.global_rotation = 0.0
	_main.p1.equip_weapon(_main.weapon_for_index(_index_de("pompe")))
	var torche_j2: Light2D = _main.p2.flashlight
	var part_j2 := _part_eclairee(torche_j2, _main.p2.global_position, capteurs[0][1], false)
	var part_j2_avant := _part_eclairee(torche_j2, _main.p2.global_position, capteurs[0][1], true)
	_check("J1 devant la torche de J2 : le capteur du corps de J2 reste ombré par l'étoile de J1 (l'autre joueur)",
		part_j2 < 0.9 and absf(part_j2 - part_j2_avant) < 0.001, "%.3f (avant Q42 %.3f)" % [part_j2, part_j2_avant])
	var part_j1 := _part_eclairee(torche_j2, _main.p1.global_position, capteurs[1][0], false)
	_check("et le capteur du corps de J1 ne compte pas l'étoile de J1 : la torche de J2 l'éclaire à 100 %",
		part_j1 > 0.99, "%.3f" % part_j1)
	for i in murs.size():
		(murs[i] as LightOccluder2D).visible = visibles[i]
	_main.p1.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))
	_main.p2.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))


# ---------------------------------------------------------------------------
# LE LEURRE
# ---------------------------------------------------------------------------

func _le_leurre() -> void:
	print("\n--- Le leurre : un corps à part entière ---")
	_main.round_active = true
	_main.sandbox_mode = false
	_main.p1.equip_weapon(_main.weapon_for_index(1))
	_main._gadgets_poses_par.fill(0)
	_main.p1.global_position = Vector2(700.0, 400.0)
	_main.p1.global_rotation = 0.0
	_main.spawn_gadget(_main.p1, _main.p1.global_position + Vector2(90.0, 0.0), 0.0)
	await process_frame
	var leurre = null
	for c in _main.bullet_container.get_children():
		if c is GadgetLeurre:
			leurre = c
	_check("un leurre est posé", leurre != null)
	if leurre == null:
		return
	for i in 4:
		await process_frame
	var e := leurre.get_node_or_null("OmbreDuCorps") as EtoileDeCorps
	_check("son étoile vit dans SA canvas, comme celle d'un joueur, avec la même forme et la même couche",
		e != null and e.proprietaire == leurre and e.occluder == leurre._occluder
		and e.occluder.occluder.polygon == _main.p1.etoile().occluder.polygon
		and e.occluder.occluder_light_mask == _main.p1.etoile().occluder_light_mask)
	var torse := leurre.get_node_or_null("OccluderTorse") as LightOccluder2D
	_check("son disque de torse reste dans le monde partagé, comme celui d'un joueur",
		torse != null and torse.get_canvas() == _main.vp1.world_2d.get_canvas())
	if e == null:
		return
	# Ses capteurs (un par vue regardée) ne voient pas SON étoile ; ils voient celles des deux joueurs.
	var capteurs_du_leurre: Array = []
	for c in _pres.get("_miroirs").capteurs_de(leurre):
		if c != null and is_instance_valid(c):
			capteurs_du_leurre.append(c)
	_check("le leurre a un capteur par vue regardée (deux en écran scindé)", capteurs_du_leurre.size() == 2,
		"%d" % capteurs_du_leurre.size())
	var vues := e.vues_rattachees()
	var etoile_j1: EtoileDeCorps = _main.p1.get_node("OmbreDuCorps")
	var etoile_j2: EtoileDeCorps = _main.p2.get_node("OmbreDuCorps")
	for c in capteurs_du_leurre:
		_check("un capteur du leurre : il porte le leurre, ne voit pas l'étoile du leurre, voit celles de J1 et de J2",
			c.proprietaire == leurre and not vues.has(c.get_instance_id())
			and etoile_j1.vues_rattachees().has(c.get_instance_id()) and etoile_j2.vues_rattachees().has(c.get_instance_id()))
	# Et le leurre ombre les capteurs des joueurs, comme tout autre corps.
	var capteurs: Array = _pres.capteurs()
	var tous := true
	for v in 2:
		for j in 2:
			tous = tous and vues.has(capteurs[v][j].get_instance_id())
	_check("l'étoile du leurre est rattachée aux quatre capteurs de joueurs (il ombre le corps qu'il imite comme tout autre corps)", tous)
	_check("et à vp2, comme les étoiles des joueurs", vues.has(_main.vp2.get_instance_id()))
	leurre.queue_free()
	for i in 3:
		await process_frame
	_check("le leurre libéré, plus aucune vue ne garde sa canvas (aucun rattachement fantôme)",
		_main.p1.get_node("OmbreDuCorps").vues_rattachees().size() == 5, str(_main.p1.get_node("OmbreDuCorps").vues_rattachees().size()))


# ---------------------------------------------------------------------------
# LA VUE UNIQUE, LA VUE DE DESSUS
# ---------------------------------------------------------------------------

func _vue_unique() -> void:
	# La vue regardée est celle de J1 (l'hôte, l'entraînement) ou celle de J2 (le client) : la même règle des deux côtés.
	for id in 2:
		print("\n--- Vue unique, celle de J%d : deux capteurs, la même règle ---" % (id + 1))
		var autre := (_main.vp2 if id == 0 else _main.vp1).get_parent() as Control
		autre.hide()
		_main._accorder_rendu_aux_vues()
		for i in 6:
			await process_frame
		var capteurs: Array = _pres.capteurs()
		var vivants := _capteurs()
		_check("vue unique (J%d) : deux capteurs vivants, ceux de la vue de J%d seulement" % [id + 1, id + 1],
			vivants.size() == 2 and capteurs[id][0] != null and capteurs[id][1] != null
			and capteurs[1 - id][0] == null and capteurs[1 - id][1] == null)
		for j in 2:
			var joueur: Node2D = _main.p1 if j == 0 else _main.p2
			var e: EtoileDeCorps = joueur.get_node("OmbreDuCorps")
			var vues := e.vues_rattachees()
			var attendu_ok := true
			for c in vivants:
				attendu_ok = attendu_ok and (vues.has(c.get_instance_id()) == (c.proprietaire != joueur))
			_check("vue unique (J%d) : l'étoile de J%d est rattachée au capteur de l'autre corps seulement" % [id + 1, j + 1],
				attendu_ok)
			var perime := false
			for k in vues:
				perime = perime or not is_instance_id_valid(k)
			_check("vue unique (J%d) : aucun rattachement périmé (les capteurs de l'autre vue sont partis)" % (id + 1),
				not perime, str(vues.keys()))
		var comptes := []
		for c in vivants:
			var n := 0
			for e in get_nodes_in_group(EtoileDeCorps.GROUPE):
				if (e as EtoileDeCorps).vues_rattachees().has(c.get_instance_id()):
					n += 1
			comptes.append(n)
		_check("vue unique (J%d) : chaque capteur compte exactement une étoile, celle de l'autre corps : %s" % [id + 1, str(comptes)],
			comptes == [1, 1])
		autre.show()
		_main._accorder_rendu_aux_vues()
		for i in 6:
			await process_frame
	_check("l'écran scindé revenu : les quatre capteurs et la règle avec eux", _capteurs().size() == 4)
	var e1: EtoileDeCorps = _main.p1.get_node("OmbreDuCorps")
	var comptes_scinde := []
	for c in _capteurs():
		var n := 0
		for e in get_nodes_in_group(EtoileDeCorps.GROUPE):
			if (e as EtoileDeCorps).vues_rattachees().has(c.get_instance_id()):
				n += 1
		comptes_scinde.append(n)
	_check("et chaque capteur recompte une seule étoile : %s" % str(comptes_scinde), comptes_scinde == [1, 1, 1, 1])
	_check("l'étoile de J1 garde vp2", e1.vues_rattachees().has(_main.vp2.get_instance_id()))


## Sans iso, il n'y a pas de capteur : les étoiles ne doivent manquer à AUCUNE vue du duel (l'ombre au sol, sur les murs, sur les
## sprites), ni à la racine quand elle adopte le monde en vue unique.
func _vue_de_dessus(reglages: Node) -> void:
	print("\n--- Vue de dessus (--2d) : aucun capteur, toutes les vues voient toutes les étoiles ---")
	reglages.mode_iso = false
	_main._start_round()
	_check("la manche de la vue de dessus démarre", await _depart_fini(_main))
	for i in 4:
		await process_frame
	_check("la vue iso est éteinte : plus aucun capteur", _capteurs().is_empty() and get_nodes_in_group(EtoileDeCorps.GROUPE_CAPTEURS).is_empty())
	for j in 2:
		var joueur: Node2D = _main.p1 if j == 0 else _main.p2
		var e: EtoileDeCorps = joueur.get_node("OmbreDuCorps")
		_check("étoile de J%d : vp2 la voit (écran scindé en vue de dessus, comme avant)" % (j + 1),
			e.vues_rattachees().has(_main.vp2.get_instance_id()))
	var c2 := _main.vp2.get_parent() as Control
	c2.hide()
	_main._accorder_rendu_aux_vues()
	for i in 4:
		await process_frame
	var racine_adopte := bool(_main.get("_rendu_racine"))
	_check("en vue unique, la racine adopte le monde du duel", racine_adopte)
	if racine_adopte:
		for j in 2:
			var e: EtoileDeCorps = (_main.p1 if j == 0 else _main.p2).get_node("OmbreDuCorps")
			_check("étoile de J%d : la racine, qui rend maintenant le duel, la voit" % (j + 1),
				e.vues_rattachees().has(root.get_instance_id()))
	c2.show()
	_main.set("rendu_racine_autorise", false)
	_main._accorder_rendu_aux_vues()
	for i in 4:
		await process_frame
	for j in 2:
		var e: EtoileDeCorps = (_main.p1 if j == 0 else _main.p2).get_node("OmbreDuCorps")
		_check("écran scindé de retour : la racine ne rend plus le duel, son rattachement part avec l'adoption",
			not e.vues_rattachees().has(root.get_instance_id()))
	reglages.mode_iso = true


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			printerr("    la manche n'a pas démarré (round_active=%s, décompte=%s)" % [main.round_active, main.countdown_left])
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	for i in 4:
		await physics_frame
	return main.round_active


## `NetworkManager.GameMode.LOCAL_SPLITSCREEN`, lu par l'arbre : nommer l'autoload dans une suite `--script` la ferait
## compiler avant qu'il existe (piège consigné).
func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
