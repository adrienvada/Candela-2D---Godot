class_name OmbresCorps
## Chantier OMBRES, OM5 (Q88, décision d'Adrien du 2026-10-05 : « Ombre ») — l'ombre FINIE des corps sous les plafonniers.
##
## La règle se dessine dans le matériau du sol et du décor (`ombres_corps_zone.gdshaderinc`), comme la zone morte des murets :
## ce fichier la PORTE aux matériaux — corps et plafonniers convertis dans l'espace écran d'une vue — et en garde la jumelle
## (`ombre`), que `tools/test_ombres_plafonniers.gd` vérifie en headless et que le banc des ombres confronte au pixel.
##
## Aucun autoload, aucun nœud : un `--script` peut le nommer.

## Ce qu'un matériau reçoit au plus (les tableaux de l'include) : 8 plafonniers par salle (`AventureFormat.PLAFONNIERS_MAX`),
## et les corps d'une salle — le joueur, au plus 8 PNJ (`Presentation3D.FIGURANTS_MAX`), et leurs leurres.
const LAMPES_MAX := 8
const CORPS_MAX := 12

## Le rayon du cylindre d'un corps, en pixels de monde : « le corps grossier » de la présentation, 0,4 tuile
## (`Presentation3D.RAYON_CORPS_PX` — recopié et non lu : la présentation nomme des autoloads, une suite en `--script` ne
## compilerait plus ; `tools/test_ombres_plafonniers.gd` vérifie l'égalité).
const RAYON_CORPS := 14.0


## LA règle, jumelle de `om_ombre_des_corps()` : ce que les corps retirent de la lumière d'une lampe en `source` (x, y : sa
## position ; z : sa hauteur) au point `point` du sol — 0 (rien) à 1 (toute), la plus forte des ombres qui le couvrent.
## `corps` : des `Vector4(x, y, rayon, hauteur)` ; `forces` : leur opacité dans la vue, dans le même ordre. Unités libres, mais
## les mêmes partout (le monde pour les suites, l'écran pour le matériau).
static func ombre(source: Vector3, point: Vector2, corps: Array, forces: Array) -> float:
	var o := 0.0
	if source.z <= 0.0:
		return 0.0
	var s := Vector2(source.x, source.y)
	for i in corps.size():
		var c: Vector4 = corps[i]
		var f := float(forces[i])
		if f <= o or c.w <= 0.0 or source.z <= c.w:
			continue
		var a := s + (point - s) * (1.0 - c.w / source.z)
		var ab := point - a
		var centre := Vector2(c.x, c.y)
		var t := clampf((centre - a).dot(ab) / maxf(ab.dot(ab), 1e-6), 0.0, 1.0)
		if centre.distance_to(a + ab * t) < c.z:
			o = f
	return o


## La longueur de l'ombre d'un corps sur l'axe de la lampe, comptée depuis son centre : D · H / (h − H), où D est la distance de
## la lampe au corps (au sol), H la hauteur du corps, h celle de la lampe. `INF` si la lampe ne dépasse pas le corps. (Le bord
## de l'ombre, lui, est encore à un rayon de corps plus loin : le cylindre a une épaisseur.)
static func longueur(d: float, h_corps: float, h_lampe: float) -> float:
	if h_lampe <= h_corps:
		return INF
	return d * h_corps / (h_lampe - h_corps)


## Les plafonniers ALLUMÉS de l'arbre, en positions de monde. Lus par leur groupe et leur `halo`, sans nommer `Plafonnier`.
static func lampes_allumees(arbre: SceneTree) -> Array[Vector2]:
	var sortie: Array[Vector2] = []
	if arbre == null:
		return sortie
	for p in arbre.get_nodes_in_group("plafonniers"):
		if not (p is Node2D) or not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
			continue
		var halo: Variant = p.get("halo")
		if halo is Light2D and is_instance_valid(halo) and (halo as Light2D).enabled and (halo as Light2D).is_visible_in_tree():
			sortie.append((halo as Light2D).global_position)
	return sortie


## Les uniformes d'une vue. `monde_vers_ecran` : la transformation du monde vers les pixels de la cible de rendu (celle de la
## zone morte, `GameState._pousser_zone_morte`). `lampes` : positions de monde (`lampes_allumees`). `corps` : des dictionnaires
## `{position: Vector2, hauteur: float (pixels de monde), force: float}`. Au-delà des tableaux, le reste est perdu et
## `debordement` le dit.
static func uniformes_de_vue(monde_vers_ecran: Transform2D, lampes: Array, corps: Array) -> Dictionary:
	var echelle := monde_vers_ecran.get_scale().x
	var t_lampes := PackedVector2Array()
	var debordement := 0
	for l: Vector2 in lampes:
		if t_lampes.size() >= LAMPES_MAX:
			debordement += 1
			continue
		t_lampes.append(monde_vers_ecran * l)
	var t_corps := PackedVector4Array()
	var t_forces := PackedFloat32Array()
	for c: Dictionary in corps:
		if float(c["force"]) <= 0.0:
			continue
		if t_corps.size() >= CORPS_MAX:
			debordement += 1
			continue
		var e: Vector2 = monde_vers_ecran * (c["position"] as Vector2)
		t_corps.append(Vector4(e.x, e.y, RAYON_CORPS * echelle, float(c["hauteur"]) * echelle))
		t_forces.append(clampf(float(c["force"]), 0.0, 1.0))
	var nb_lampes := t_lampes.size()
	var nb_corps := t_corps.size()
	t_lampes.resize(LAMPES_MAX)
	t_corps.resize(CORPS_MAX)
	t_forces.resize(CORPS_MAX)
	return {"lampes": t_lampes, "nb_lampes": nb_lampes, "corps": t_corps, "forces": t_forces, "nb_corps": nb_corps,
		"echelle": echelle, "debordement": debordement}


## Remplit un matériau de sol ou de décor (`murs_bas_sol.gdshader`, `murs_bas_decor.gdshader`).
static func poser(m: ShaderMaterial, u: Dictionary) -> void:
	if m == null:
		return
	m.set_shader_parameter("om_nb_lampes", u["nb_lampes"])
	m.set_shader_parameter("om_lampes", u["lampes"])
	m.set_shader_parameter("om_nb_corps", u["nb_corps"])
	m.set_shader_parameter("om_corps", u["corps"])
	m.set_shader_parameter("om_corps_force", u["forces"])
