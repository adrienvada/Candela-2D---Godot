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
##   • la vue de dessus (`--2d`), sans capteur : les étoiles y restent visibles de `vp2` et de la racine ;
##   • **Q55, le capteur de SOI** (Adrien, 2026-09-29 : « on suit ton avis » — que les murs assombrissent le corps de soi pour
##     les deux) : chez J1 comme chez J2, il porte `JOUEUR_LOCAL` et la couche d'ombre de son corps, donc il reçoit les ombres
##     de la torche d'en face — un mur l'assombrit, en écran scindé comme en vue unique (J1 puis J2 regardés), le leurre vu par
##     son poseur compris —, et il lit ce que lit le capteur croisé du même corps. Le même calcul avec le masque d'AVANT
##     (`JOUEUR_LOCAL` seul) retrouve le défaut : le mur ignoré chez J2. Aucune lumière n'a le bit 8 dans sa portée ;
##   • **Q65, la rétrodiffusion d'en face** (Adrien, 2026-09-29 : « ferme-la dans la 0.8.0 ») : elle éclairait le capteur de soi À
##     TRAVERS un mur (0,667 à 70 px), parce que son masque d'ombre ne croisait celui d'aucun capteur de soi. Chaque capteur de soi
##     porte désormais le bit récepteur de son joueur (`CanauxLumiere.recepteur_retro`, 128 et 256), que la rétrodiffusion de
##     l'ADVERSAIRE — et d'elle seule — porte dans son masque d'ombre : un mur l'arrête, chez J1 comme chez J2, le leurre vu par
##     son poseur compris ; le capteur de soi ne reçoit jamais les ombres de SA propre rétrodiffusion (la lumière propre ne
##     bouge pas) ; le même calcul avec le masque de Q55 retrouve la fuite ; aucune lumière n'a l'un de ces bits dans sa portée.
##   • **OMBRES, OM0 — le culling et l'enroulement de chaque étoile** (chantier OMBRES, 2026-10-04) : pour les dix classes, chez
##     J1 comme chez J2, et pour le leurre, l'étoile porte le mode de culling attendu (`CULL_ETOILE_ATTENDU`) et tourne dans le
##     sens que ce culling suppose — aire signée POSITIVE dans le repère du jeu (y vers le bas), donc « anti-horaire » au sens de
##     `Geometry2D.is_polygon_clockwise`. La combinaison n'a de sens qu'avec le bon enroulement : un culling des arêtes tournées
##     vers la lampe fait partir l'ombre du bord arrière du corps (prouvé à l'image par `tools/planche_ombres.gd`, sonde
##     « dedans / dehors ») ; le même culling sur une étoile tournée à l'envers cullerait les arêtes ARRIÈRE, et l'ombre
##     partirait de nouveau devant les pieds, sans un mot. Le contrôle prouve qu'il voit un enroulement inversé.
##
## Lancer : godot --headless --path . --script res://tools/test_ombre_propre.gd
extends SceneTree

const ORIENTATIONS := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
## Les trois classes que le rapport `cloud-ombre-orientation` a vues noires, torche du côté de l'arme.
const CLASSES_NOIRES := ["occulteur", "fumiste", "incendiaire"]
const ANNEAU := 64
## OMBRES — le mode de culling des étoiles de corps : `CULL_COUNTER_CLOCKWISE` depuis OM1 (`Charte.occulteur_d_etoile`), l'ombre
## part du bord arrière du corps ; c'était `CULL_DISABLED` jusque-là, l'intérieur de l'étoile dans l'ombre.
const CULL_ETOILE_ATTENDU := OccluderPolygon2D.CULL_COUNTER_CLOCKWISE

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
	print("=== Q42 : LE CORPS IGNORE SA PROPRE OMBRE — Q55 / Q65 : LE CAPTEUR DE SOI RECOIT LES OMBRES DES LUMIÈRES D'EN FACE ===")
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
	_culling_et_enroulement()
	await _suivi()
	_la_regle_scindee()
	await _l_effet()
	await _l_autre_et_le_mur()
	await _le_soi_et_les_murs()
	await _le_leurre()
	await _le_leurre_de_soi()
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
		# OMBRES, OM2 (Q82) — l'étoile du CORPS VOXEL de sa classe (`VoxelCatalogue.etoile_d_ombre`), plus la silhouette du sprite.
		_check("J%d : sa forme est l'étoile de 32 rayons de son corps voxel, une ressource à elle" % (j + 1),
			occ.occluder != null and occ.occluder.polygon.size() == 32 and occ.occluder.cull_mode == CULL_ETOILE_ATTENDU
			and occ.occluder.polygon == VoxelCatalogue.etoile_d_ombre(joueur.current_weapon.slug()))
		var torse := joueur.get_node_or_null("OccluderTorse") as LightOccluder2D
		_check("J%d : le disque de torse (rétrodiffusion) est resté dans le monde, à sa couche" % (j + 1),
			torse != null and torse.get_canvas() == monde and torse.occluder_light_mask == joueur.COUCHE_TORSE)
	_check("les deux étoiles ont chacune leur canvas", _main.p1.etoile().get_canvas() != _main.p2.etoile().get_canvas())


## OMBRES, OM0 — le culling et l'enroulement de l'étoile, pour les dix classes, chez J1 comme chez J2. Sans rendu : ce qui se voit,
## le banc des ombres le mesure (`tools/planche_ombres.gd`) ; ici, la combinaison que ce banc a prouvée, et qu'aucun geste ne doit
## défaire en silence.
func _culling_et_enroulement() -> void:
	print("\n--- OMBRES : le culling et l'enroulement de chaque étoile (dix classes, J1 et J2) ---")
	var classes := _classes()
	var mauvais_cull: Array[String] = []
	var mauvais_sens: Array[String] = []
	for j in 2:
		var joueur: Node2D = _main.p1 if j == 0 else _main.p2
		for slug in classes:
			joueur.equip_weapon(_main.weapon_for_index(_index_de(slug)))
			var occ: LightOccluder2D = joueur.etoile()
			if occ == null or occ.occluder == null:
				mauvais_cull.append("J%d %s : pas d'étoile" % [j + 1, slug])
				continue
			var forme: PackedVector2Array = occ.occluder.polygon
			if occ.occluder.cull_mode != CULL_ETOILE_ATTENDU:
				mauvais_cull.append("J%d %s (%d)" % [j + 1, slug, occ.occluder.cull_mode])
			if not _sens_attendu(forme):
				mauvais_sens.append("J%d %s (aire %.1f)" % [j + 1, slug, _aire_signee(forme)])
	_check("les vingt étoiles (dix classes, J1 et J2) portent le culling attendu (%d)" % CULL_ETOILE_ATTENDU,
		mauvais_cull.is_empty(), ", ".join(mauvais_cull))
	_check("et tournent toutes dans le sens que le culling suppose (aire signée positive, y vers le bas)",
		mauvais_sens.is_empty(), ", ".join(mauvais_sens))
	# Le contrôle : la même forme, retournée, doit être refusée — sans quoi « toutes dans le bon sens » ne dirait rien.
	var forme_j1: PackedVector2Array = _main.p1.etoile().occluder.polygon
	var retournee := forme_j1.duplicate()
	retournee.reverse()
	_check("le contrôle voit un enroulement inversé (la même étoile retournée est refusée)",
		_sens_attendu(forme_j1) and not _sens_attendu(retournee))
	_main.p1.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))
	_main.p2.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))


## L'aire signée d'un polygone (formule du lacet), dans le repère du jeu : positive quand les sommets tournent comme l'angle de
## `Vector2.from_angle` croissant — le sens de `Charte.ombre_de_silhouette`.
static func _aire_signee(forme: PackedVector2Array) -> float:
	var a := 0.0
	for i in forme.size():
		var p := forme[i]
		var q := forme[(i + 1) % forme.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Le sens que le culling d'une étoile suppose : aire positive ET « anti-horaire » au sens de `Geometry2D` (qui compte y vers le
## haut) — les deux lectures disent la même chose, et le moteur ne connaît que la seconde.
static func _sens_attendu(forme: PackedVector2Array) -> bool:
	return forme.size() >= 3 and _aire_signee(forme) > 0.0 and not Geometry2D.is_polygon_clockwise(forme)


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


## La règle de la Light2D : un point est dans l'ombre si le segment lampe → point coupe une arête d'un occluder dont la couche
## est dans le masque d'ombre de la lampe — et, sous un culling, une arête que ce culling GARDE. Sans culling, toutes : un point
## DANS la forme est dans l'ombre (il faut en franchir le bord pour l'atteindre). Sous `CULL_COUNTER_CLOCKWISE` (les étoiles
## depuis OM1), le moteur écarte les arêtes que la lampe voit tourner dans un sens — celles dont le produit vectoriel
## (a − lampe) × (b − lampe) est NÉGATIF, ce qui, pour une étoile d'aire signée positive, sont les arêtes tournées vers la lampe
## (la règle mesurée au banc des ombres, OM0 : l'intérieur côté lampe éclairé, l'ombre derrière). `CULL_CLOCKWISE`, l'inverse.
static func _ombre(lampe: Vector2, point: Vector2, forme: PackedVector2Array,
		cull: int = OccluderPolygon2D.CULL_DISABLED) -> bool:
	for i in forme.size():
		var a := forme[i]
		var b := forme[(i + 1) % forme.size()]
		if cull != OccluderPolygon2D.CULL_DISABLED:
			var sens := (a - lampe).cross(b - lampe)
			if (cull == OccluderPolygon2D.CULL_COUNTER_CLOCKWISE and sens < 0.0) \
					or (cull == OccluderPolygon2D.CULL_CLOCKWISE and sens > 0.0):
				continue
		if Geometry2D.segment_intersects_segment(lampe, point, a, b) != null:
			return true
	return false


## La part de l'anneau où le corps lit sa lumière (64 points, décalés d'un demi-pas pour ne jamais tomber pile sur un
## sommet de l'étoile) que la lampe éclaire, vue par `sous_vue`.
func _part_eclairee(lampe: Light2D, centre: Vector2, sous_vue: Viewport, avant: bool) -> float:
	var rayon: float = minf(float(_Pres.RAYON_CORPS_PX) + 1.0, float(_Capteur.RAYON_PX) - 3.0)
	var formes: Array = []
	for occ in _occluders_vus(sous_vue, avant):
		if ((occ as LightOccluder2D).occluder_light_mask & lampe.shadow_item_cull_mask) != 0:
			formes.append([_forme_monde(occ), (occ as LightOccluder2D).occluder.cull_mode])
	var eclaires := 0
	for k in ANNEAU:
		var p := centre + Vector2.from_angle(TAU * (float(k) + 0.5) / float(ANNEAU)) * rayon
		var ombree := false
		for f in formes:
			if _ombre(lampe.global_position, p, f[0], f[1]):
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
	# ⚠️ Son seuil suit le culling des étoiles (OM1) : quand chaque arête jetait son ombre, le corps qui voyait sa propre étoile
	# tombait sous 5 % ; sous `CULL_COUNTER_CLOCKWISE`, l'avant de l'anneau reste éclairé et seule la moitié arrière tombe dans
	# l'ombre — 44 à 50 % pour les trois classes. Puis OM2 (Q82, 2026-10-05) : l'étoile est celle du CORPS VOXEL, sans l'arme,
	# plus petite que celle du sprite — l'anneau ne tombe plus qu'à 61-67 % pour les trois classes (mesuré). Toujours un défaut
	# net contre les 100 % exigés : sous 80 %.
	var seuil_avant := 0.05 if CULL_ETOILE_ATTENDU == OccluderPolygon2D.CULL_DISABLED else 0.8
	for porteur in 2:
		for slug in CLASSES_NOIRES:
			var v: float = pires_avant["J%d porte / %s" % [porteur + 1, slug]]
			_check("AVANT (étoile dans le monde) : J%d porte, %s — torche du côté de l'arme, l'anneau tombe à %.0f %% (sous %.0f %%)"
				% [porteur + 1, slug, v * 100.0, seuil_avant * 100.0], v < seuil_avant)
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
# Q55 — LE CAPTEUR DE SOI ET LES MURS
# ---------------------------------------------------------------------------

## Ce que la règle du moteur donne à un disque : il ne reçoit les ombres d'une lumière que si son masque de lumière croise le
## `shadow_item_cull_mask` de cette lumière — sinon AUCUNE, les murs non plus. Mesuré sous Godot 4.7 (`tools/planche_q42.gd --mur`,
## un mur entre la torche adverse et la cible, avant Q55) : le corps de J1 vu par J1 lisait 0,000, celui de J2 vu par J2 0,494 — le mur
## ignoré, parce que 4 croise le masque d'ombre de la torche de J2 (`1 | 2 | 4`) et pas celui de la torche de J1 (`1 | 2 | 8`).
## `masque_du_disque` est passé en argument : le contrôle y met l'ancien masque du capteur de soi.
func _part_eclairee_recue(lampe: Light2D, centre: Vector2, capteur: Viewport, masque_du_disque: int) -> float:
	if (masque_du_disque & lampe.shadow_item_cull_mask) == 0:
		return 1.0
	return _part_eclairee(lampe, centre, capteur, false)


## Un mur d'essai posé comme ceux de la carte : la couche du décor, dans le monde partagé, en travers de l'axe.
func _mur_d_essai(position_du_mur: Vector2) -> LightOccluder2D:
	var mur := LightOccluder2D.new()
	var forme := OccluderPolygon2D.new()
	forme.polygon = PackedVector2Array([Vector2(-6, -80), Vector2(6, -80), Vector2(6, 80), Vector2(-6, 80)])
	forme.cull_mode = OccluderPolygon2D.CULL_DISABLED
	mur.occluder = forme
	mur.occluder_light_mask = 1
	mur.position = position_du_mur
	_main.arena.add_child(mur)
	return mur


## Le corps `id` dans SA vue (son capteur de soi), sous la torche de l'ADVERSAIRE à mi-portée : la part de l'anneau que le
## capteur reçoit sans mur, avec un mur entre la torche et le corps, et — le contrôle — avec le masque d'AVANT Q55 (`JOUEUR_LOCAL`
## seul). `croise` : le capteur du même corps dans la vue de l'adversaire, quand cette vue est regardée (écran scindé).
func _le_soi_derriere_un_mur(id: int) -> Dictionary:
	var murs := _murs_du_monde()
	var visibles := []
	for m in murs:
		visibles.append((m as LightOccluder2D).visible)
		(m as LightOccluder2D).visible = false
	var corps: Node2D = _main.p1 if id == 0 else _main.p2
	var ennemi: Node2D = _main.p2 if id == 0 else _main.p1
	var capteurs: Array = _pres.capteurs()
	var soi = capteurs[id][id]
	var croise = capteurs[1 - id][id]
	var axe := Vector2.RIGHT
	ennemi.global_position = Vector2(500.0, 500.0)
	ennemi.global_rotation = 0.0
	corps.global_position = ennemi.global_position + axe * 153.6
	corps.global_rotation = PI
	var torche: Light2D = ennemi.flashlight
	# Q65 — la rétrodiffusion de l'adversaire, elle aussi : à 18 px devant lui, donc en deçà du mur d'essai.
	var retro: Light2D = ennemi.body_light
	var masque_soi: int = soi.masque_lumiere()
	# Le masque du capteur de soi AVANT Q65 (celui de Q55), pour le contrôle de la rétrodiffusion.
	var masque_q55: int = CanauxLumiere.JOUEUR_LOCAL | CanauxLumiere.couche_ombre_corps(id)
	var r := {"masque_soi": masque_soi, "recoit": (masque_soi & torche.shadow_item_cull_mask) != 0,
		"sans_mur": _part_eclairee_recue(torche, corps.global_position, soi, masque_soi),
		"retro_recoit": (masque_soi & retro.shadow_item_cull_mask) != 0,
		"retro_propre_recue": (masque_soi & corps.body_light.shadow_item_cull_mask) != 0,
		"retro_sans_mur": _part_eclairee_recue(retro, corps.global_position, soi, masque_soi)}
	if croise != null:
		r["sans_mur_croise"] = _part_eclairee_recue(torche, corps.global_position, croise, croise.masque_lumiere())
		r["retro_sans_mur_croise"] = _part_eclairee_recue(retro, corps.global_position, croise, croise.masque_lumiere())
	var mur := _mur_d_essai(ennemi.global_position + axe * 90.0)
	await process_frame
	r["avec_mur"] = _part_eclairee_recue(torche, corps.global_position, soi, masque_soi)
	r["avec_mur_avant"] = _part_eclairee_recue(torche, corps.global_position, soi, CanauxLumiere.JOUEUR_LOCAL)
	r["retro_avec_mur"] = _part_eclairee_recue(retro, corps.global_position, soi, masque_soi)
	r["retro_avec_mur_avant"] = _part_eclairee_recue(retro, corps.global_position, soi, masque_q55)
	if croise != null:
		r["avec_mur_croise"] = _part_eclairee_recue(torche, corps.global_position, croise, croise.masque_lumiere())
		r["retro_avec_mur_croise"] = _part_eclairee_recue(retro, corps.global_position, croise, croise.masque_lumiere())
	mur.queue_free()
	await process_frame
	for i in murs.size():
		(murs[i] as LightOccluder2D).visible = visibles[i]
	return r


## Les vérifications d'UN capteur de soi : c'est la garde de Q55. Elle rougit si le capteur de soi de J1 OU de J2 ignore les murs —
## et le contrôle prouve qu'elle VOIT le défaut : avec le masque d'avant Q55, le mur était ignoré chez J2 seulement.
func _verifier_le_soi(r: Dictionary, id: int, contexte: String) -> void:
	_check("%s : le capteur de soi de J%d porte JOUEUR_LOCAL, la couche d'ombre de son corps et son bit récepteur (masque %d)" % [
		contexte, id + 1, r["masque_soi"]], r["masque_soi"] == CanauxLumiere.masque_de_soi(id))
	_check("%s : ce masque croise le masque d'ombre de la torche d'en face — il en reçoit les ombres" % contexte, r["recoit"])
	_check("%s : sans mur, la torche d'en face éclaire l'anneau du corps en entier" % contexte,
		is_equal_approx(r["sans_mur"], 1.0), "%.3f" % r["sans_mur"])
	_check("%s : un mur entre la torche d'en face et le corps l'assombrit — l'anneau tombe à %.0f %% éclairé" % [contexte,
		100.0 * r["avec_mur"]], r["avec_mur"] < 0.02, "%.3f" % r["avec_mur"])
	if r.has("avec_mur_croise"):
		_check("%s : il lit ce que lit le capteur croisé du même corps, sans mur (%.2f) comme avec un mur (%.2f)" % [contexte,
			r["sans_mur_croise"], r["avec_mur_croise"]],
			is_equal_approx(r["sans_mur"], r["sans_mur_croise"]) and is_equal_approx(r["avec_mur"], r["avec_mur_croise"]))
	if id == 0:
		_check("%s — AVANT Q55 (masque JOUEUR_LOCAL seul) : J1 était déjà assombri par le mur" % contexte, r["avec_mur_avant"] < 0.02,
			"%.3f" % r["avec_mur_avant"])
	else:
		_check("%s — AVANT Q55 (masque JOUEUR_LOCAL seul) : le mur était IGNORÉ chez J2, l'anneau restait éclairé à %.0f %%" % [contexte,
			100.0 * r["avec_mur_avant"]], r["avec_mur_avant"] > 0.99, "%.3f" % r["avec_mur_avant"])
	# Q65 — la rétrodiffusion de l'adversaire : mêmes règles, et la sienne ne l'ombre jamais.
	_check("%s : ce masque croise le masque d'ombre de la rétrodiffusion d'en face — il en reçoit les ombres" % contexte, r["retro_recoit"])
	_check("%s : il ne croise JAMAIS le masque d'ombre de SA propre rétrodiffusion — la lumière propre reste ce qu'elle était" % contexte,
		not r["retro_propre_recue"])
	_check("%s : un mur entre la rétrodiffusion d'en face et le corps l'assombrit — l'anneau tombe à %.0f %% éclairé" % [contexte,
		100.0 * r["retro_avec_mur"]], r["retro_avec_mur"] < 0.02, "%.3f" % r["retro_avec_mur"])
	if r.has("retro_avec_mur_croise"):
		_check("%s : et il lit ce que lit le capteur croisé sous cette rétrodiffusion, sans mur (%.2f) comme avec un mur (%.2f)" % [
			contexte, r["retro_sans_mur_croise"], r["retro_avec_mur_croise"]],
			is_equal_approx(r["retro_sans_mur"], r["retro_sans_mur_croise"])
			and is_equal_approx(r["retro_avec_mur"], r["retro_avec_mur_croise"]))
	_check("%s — AVANT Q65 (masque de Q55) : la rétrodiffusion traversait le mur, l'anneau restait éclairé à %.0f %% (J1 comme J2)" % [
		contexte, 100.0 * r["retro_avec_mur_avant"]], r["retro_avec_mur_avant"] > 0.99, "%.3f" % r["retro_avec_mur_avant"])


func _le_soi_et_les_murs() -> void:
	print("\n--- Q55 : le capteur de SOI reçoit les ombres de la torche d'en face, chez J2 comme chez J1 ---")
	var r0: Dictionary = await _le_soi_derriere_un_mur(0)
	var r1: Dictionary = await _le_soi_derriere_un_mur(1)
	_verifier_le_soi(r0, 0, "écran scindé, J1")
	_verifier_le_soi(r1, 1, "écran scindé, J2")
	_check("l'équité : J1 et J2 reçoivent la même part, sans mur (%.2f / %.2f) et avec un mur (%.2f / %.2f)" % [r0["sans_mur"],
		r1["sans_mur"], r0["avec_mur"], r1["avec_mur"]],
		is_equal_approx(r0["sans_mur"], r1["sans_mur"]) and is_equal_approx(r0["avec_mur"], r1["avec_mur"]))
	_check("le sprite de soi reste sur JOUEUR_LOCAL : la vue de dessus ne bouge pas",
		_main.p1.visual.light_mask == CanauxLumiere.JOUEUR_LOCAL and _main.p2.visual.light_mask == CanauxLumiere.JOUEUR_LOCAL)
	_aucune_portee_n_a_un_bit_recepteur()


## Les bits de plus des capteurs de soi — le 8 de J2 (la couche d'ombre de son corps, Q55) et les bits récepteurs de la rétrodiffusion
## (128, 256, Q65) — ne doivent être dans la portée d'AUCUNE lumière : elle n'éclairerait que le capteur de soi d'UN joueur (le 4 de J1
## est déjà dans toutes les portées). Les lumières vivantes du duel, puis les sources — une lumière qui naît plus tard (un gadget,
## une fusée) ne se voit pas dans l'arbre d'une manche. Et le bit récepteur de la rétrodiffusion ne vit que dans le masque d'ombre
## de la rétrodiffusion de l'ADVERSAIRE.
func _aucune_portee_n_a_un_bit_recepteur() -> void:
	var bits := {"le bit 8 (couche d'ombre du corps de J2)": CanauxLumiere.couche_ombre_corps(1),
		"le bit récepteur de J1 (128)": CanauxLumiere.recepteur_retro(0), "le bit récepteur de J2 (256)": CanauxLumiere.recepteur_retro(1)}
	var n := 0
	var fautives := []
	for lumiere in root.find_children("*", "Light2D", true, false):
		n += 1
		for nom in bits:
			if ((lumiere as Light2D).range_item_cull_mask & int(bits[nom])) != 0:
				fautives.append("%s : %s" % [str(lumiere.get_path()), nom])
	_check("aucune des %d lumières vivantes du duel n'a l'un de ces trois bits dans sa portée" % n, n > 4 and fautives.is_empty(), str(fautives))
	var suspectes := []
	var chiffres := RegEx.create_from_string("\\b(8|128|256)\\b")
	var scripts := 0
	for f in DirAccess.get_files_at("res://"):
		if not (f.ends_with(".gd") or f.ends_with(".tscn")):
			continue
		scripts += 1
		for ligne in FileAccess.get_file_as_string("res://" + f).split("\n"):
			var nette: String = ligne.strip_edges()
			if nette.begins_with("#") or not nette.contains("range_item_cull_mask") or not nette.contains("="):
				continue
			var droite: String = nette.substr(nette.find("=") + 1).split("#")[0]
			if chiffres.search(droite) != null or droite.contains("couche_ombre_corps") or droite.contains("COUCHE_OCCLUDER") \
					or droite.contains("recepteur_retro"):
				suspectes.append("%s : %s" % [f, nette])
	_check("aucune source (%d fichiers) ne met l'un de ces bits, ni une couche d'ombre de corps, dans une portée" % scripts,
		scripts > 50 and suspectes.is_empty(), str(suspectes))
	# Le bit récepteur de la rétrodiffusion : celui de l'ADVERSAIRE dans le masque d'ombre de la rétrodiffusion, jamais le sien.
	for v in 2:
		var joueur = _main.p1 if v == 0 else _main.p2
		var masque: int = joueur.body_light.shadow_item_cull_mask
		_check("la rétrodiffusion de J%d porte le bit récepteur de l'ADVERSAIRE (%d), jamais le sien (%d)" % [v + 1,
			CanauxLumiere.recepteur_retro(1 - v), CanauxLumiere.recepteur_retro(v)],
			(masque & CanauxLumiere.recepteur_retro(1 - v)) != 0 and (masque & CanauxLumiere.recepteur_retro(v)) == 0, str(masque))
		for lumiere in [joueur.flashlight, joueur.ambient_light, joueur.muzzle_flash]:
			_check("et aucune autre lumière de J%d (%s) ne porte l'un des bits récepteurs dans son masque d'ombre" % [v + 1, lumiere.name],
				(lumiere.shadow_item_cull_mask & (CanauxLumiere.recepteur_retro(0) | CanauxLumiere.recepteur_retro(1))) == 0)


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
	_check("OMBRES : son étoile porte le même culling que celle d'un joueur, et tourne dans le même sens (le même trou)",
		e != null and e.occluder.occluder.cull_mode == CULL_ETOILE_ATTENDU
		and e.occluder.occluder.cull_mode == _main.p1.etoile().occluder.cull_mode
		and _sens_attendu(e.occluder.occluder.polygon),
		"cull %d, aire %.1f" % [e.occluder.occluder.cull_mode if e != null else -1,
			_aire_signee(e.occluder.occluder.polygon) if e != null else 0.0])
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


## Q55 — le leurre vu par son poseur est un corps de soi : même masque que le capteur du corps de ce poseur, mêmes ombres. Un mur
## entre la torche adverse et le leurre l'assombrit chez J1 comme chez J2 ; et le leurre vu par l'adversaire ne change pas.
func _le_leurre_de_soi() -> void:
	print("\n--- Q55 : le leurre vu par son poseur, chez J1 comme chez J2 ---")
	var murs := _murs_du_monde()
	var visibles := []
	for m in murs:
		visibles.append((m as LightOccluder2D).visible)
		(m as LightOccluder2D).visible = false
	for poseur in 2:
		var joueur: Node2D = _main.p1 if poseur == 0 else _main.p2
		var ennemi: Node2D = _main.p2 if poseur == 0 else _main.p1
		_main.round_active = true
		_main.sandbox_mode = false
		joueur.equip_weapon(_main.weapon_for_index(1))
		_main._gadgets_poses_par.fill(0)
		# La recharge du gadget (une minute) a démarré à la pose précédente : on la rend.
		_main._gadget_attente.fill(0.0)
		joueur.global_position = Vector2(700.0, 400.0)
		joueur.global_rotation = 0.0
		_main.spawn_gadget(joueur, joueur.global_position + Vector2(90.0, 0.0), 0.0)
		await process_frame
		var leurre = null
		for c in _main.bullet_container.get_children():
			if c is GadgetLeurre and int(c.get("poseur_id")) == poseur:
				leurre = c
		_check("un leurre de J%d est posé" % (poseur + 1), leurre != null)
		if leurre == null:
			continue
		for i in 4:
			await process_frame
		# Le poseur s'écarte : son corps n'est pas entre la torche adverse et son leurre.
		joueur.global_position = Vector2(300.0, 900.0)
		var capteurs: Array = _pres.get("_miroirs").capteurs_de(leurre)
		var soi = capteurs[poseur]
		var croise = capteurs[1 - poseur]
		_check("le capteur du leurre chez son poseur J%d porte le masque de soi de J%d, celui de l'adversaire le masque d'en face"
			% [poseur + 1, poseur + 1], soi != null and croise != null
			and soi.masque_lumiere() == CanauxLumiere.masque_de_soi(poseur)
			and croise.masque_lumiere() == CanauxLumiere.masque_vue_adverse(poseur))
		if soi == null:
			continue
		ennemi.global_position = leurre.global_position + Vector2(-153.6, 0.0)
		ennemi.global_rotation = 0.0
		var torche: Light2D = ennemi.flashlight
		_check("ce masque croise le masque d'ombre de la torche d'en face — il en reçoit les ombres",
			(soi.masque_lumiere() & torche.shadow_item_cull_mask) != 0)
		var sans_mur := _part_eclairee_recue(torche, leurre.global_position, soi, soi.masque_lumiere())
		var mur := _mur_d_essai(ennemi.global_position + Vector2(90.0, 0.0))
		await process_frame
		var avec_mur := _part_eclairee_recue(torche, leurre.global_position, soi, soi.masque_lumiere())
		var avant := _part_eclairee_recue(torche, leurre.global_position, soi, CanauxLumiere.JOUEUR_LOCAL)
		var avec_mur_croise := _part_eclairee_recue(torche, leurre.global_position, croise, croise.masque_lumiere())
		_check("leurre de J%d : sans mur l'anneau est éclairé en entier (%.2f), un mur l'assombrit (%.2f), comme chez l'adversaire (%.2f)"
			% [poseur + 1, sans_mur, avec_mur, avec_mur_croise],
			is_equal_approx(sans_mur, 1.0) and avec_mur < 0.02 and avec_mur_croise < 0.02)
		if poseur == 1:
			_check("AVANT Q55 (masque JOUEUR_LOCAL seul) : le mur était ignoré par le leurre de J2 vu par J2 (%.2f)" % avant, avant > 0.99)
		# Q65 — et la rétrodiffusion de l'adversaire : le mur l'arrête aussi, chez J1 comme chez J2 ; celle du poseur ne l'ombre pas.
		var retro: Light2D = ennemi.body_light
		var retro_avec_mur := _part_eclairee_recue(retro, leurre.global_position, soi, soi.masque_lumiere())
		var retro_avant := _part_eclairee_recue(retro, leurre.global_position, soi,
			CanauxLumiere.JOUEUR_LOCAL | CanauxLumiere.couche_ombre_corps(poseur))
		var retro_croise := _part_eclairee_recue(retro, leurre.global_position, croise, croise.masque_lumiere())
		_check("leurre de J%d : sous la rétrodiffusion d'en face, un mur l'assombrit (%.2f), comme chez l'adversaire (%.2f) ; avant Q65 il la laissait passer (%.2f)"
			% [poseur + 1, retro_avec_mur, retro_croise, retro_avant],
			(soi.masque_lumiere() & retro.shadow_item_cull_mask) != 0 and retro_avec_mur < 0.02 and retro_croise < 0.02
			and retro_avant > 0.99)
		_check("et le capteur du leurre chez son poseur ne reçoit jamais les ombres de la rétrodiffusion de son poseur",
			(soi.masque_lumiere() & joueur.body_light.shadow_item_cull_mask) == 0)
		mur.queue_free()
		leurre.queue_free()
		for i in 3:
			await process_frame
	for i in murs.size():
		(murs[i] as LightOccluder2D).visible = visibles[i]
	_main.p1.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))
	_main.p2.equip_weapon(_main.weapon_for_index(_index_de("pistolet")))


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
		# Q55 — et le capteur de soi de la vue regardée reçoit les ombres de la torche d'en face : un mur l'assombrit.
		var soi_r: Dictionary = await _le_soi_derriere_un_mur(id)
		_verifier_le_soi(soi_r, id, "vue unique (J%d)" % (id + 1))
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
