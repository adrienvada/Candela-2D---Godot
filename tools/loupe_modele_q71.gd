extends RefCounted
## Q71 À L'IMAGE : le modelé des corps suit la caméra qui dessine (Adrien, 2026-09-30 : « Q71 : corrige »). Le plan
## `loupe-modele-q71` de la loupe.
##
## Le modelé (`modele_du_corps`, `corps_iso.gdshader`) assombrissait la face qui regarde le SUD DU MONDE ; au lacet 45° B,
## J1 (45°) et J2 (225°) regardent de deux côtés opposés : un seul des deux voyait cette face. La preuve de l'équité : MÊME
## CORPS, MÊME LUMIÈRE, vu par J1 puis par J2 — chacun regarde l'ADVERSAIRE (son propre corps est « sombre » chez lui, Q39,
## et ne se compare pas). Écran scindé, les deux joueurs de la même classe, face à face à trois tuiles (J2 à l'ouest de J1 ;
## J1 vise l'ouest, J2 l'est ; torches éteintes) : J1 voit le corps de J2 exactement comme J2 voit celui de J1, tourné d'un
## demi-tour avec sa caméra — et aucun mur entre chaque caméra et le corps qu'elle regarde. Jeu en pause, interface
## arrêtée ; sur les deux corps, la MÊME lumière posée (`capteur_actif` coupé, `lumiere_recue` = `LUMIERE`), l'opacité à 1
## et la silhouette à 0 (des instruments de preuve : le capteur et le brouillage ne se comparent pas ici, le modelé si).
## Cinq prises :
## - `m1` : le modelé allumé (le jeu) ; `m0` : le modelé coupé (`modele` = 0) — leur rapport, pixel par pixel, EST le
##   facteur de modelé de la face (`pate_facteur` le rend tel qu'il est écrit) ;
## - `id1` / `id2` : le corps de J1 (puis de J2) seul, peint de sa normale MONDE (`n × 0,5 + 0,5`) — quelle face est quel
##   pixel ; `fond` : sans les deux corps.
## Chaque prise imprime `MODELE_Q71 <prise>` ; les deux caméras, leur direction horizontale (`CAMERA_Q71 vue <i> : x z`).
## `tools/modele_q71/mesurer.py` rend, face par face, la moyenne et le facteur vus par J1 et par J2.
##
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tools/photographe.tscn -- --plan=loupe-modele-q71 \
##         --led-murs-fige --taille=1920x1080

const ID := "loupe-modele-q71"
## La lumière posée sur les deux corps (capteur coupé) : moyenne, pour qu'aucune face — le dessus à 1,15 — ne bute sur la
## couleur de la classe.
const LUMIERE := 0.55
const NORMALES := """shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;
varying vec3 n_monde;
void vertex() {
	n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	ALBEDO = n_monde * 0.5 + 0.5;
}
"""

var l: RefCounted   # la loupe (`tools/loupe.gd`)
var p: Node         # le photographe
var _pos := [Vector2.ZERO, Vector2.ZERO]
var _visee := [Vector2.LEFT, Vector2.RIGHT]


func jouer(loupe: RefCounted, plans: Array[Dictionary]) -> void:
	l = loupe
	p = loupe.p
	var m: Node = p._main
	var pres: Node = Presentation3D.instance()
	if pres == null:
		printerr("  ✗ %s : pas de présentation iso" % ID)
		return
	var t := MursBas.TUILE
	var j1: Vector2 = l.get("_j1")
	# J2 à l'OUEST de J1 : à l'est (premier essai), un mur au sud-est cachait le bas du corps de J2 à la caméra de J1.
	_pos = [j1, j1 + Vector2(-3.0 * t, 0.0)]
	# La même classe aux deux joueurs.
	var armes_avant := [m.p1.current_weapon, m.p2.current_weapon]
	for c in m.classes():
		if c != null and String(c.slug()) == "pompe":
			m.p1.equip_weapon(c)
			m.p2.equip_weapon(c)
	p._deux_vues()
	for k in 40:
		_tenir()
		await p.get_tree().physics_frame
		await p.get_tree().process_frame
	for id in 2:
		var cam: Node3D = pres.call("_camera_de", id)
		if cam != null:
			var z := cam.global_transform.basis.z
			var v := Vector2(z.x, z.z).normalized()
			print("  CAMERA_Q71 vue %d : %.4f %.4f (lacet %.1f°)" % [id + 1, v.x, v.y, float(cam.get("lacet_deg"))])
	# Le jeu en pause, l'interface arrêtée (le voile garde ses derniers paramètres) : rien ne bouge entre les prises.
	var interface: Node = m.get("ui")
	var mode_interface := interface.process_mode if interface != null else Node.PROCESS_MODE_INHERIT
	_tenir()
	p.get_tree().paused = true
	if interface != null:
		interface.process_mode = Node.PROCESS_MODE_DISABLED
	var mats: Array = pres.get("_mat_corps")
	var profondeurs: Array = pres.get("_mat_profondeur")
	var corps: Array = pres.get("_corps")
	var gardes := []
	for j in 2:
		var mat := mats[j] as ShaderMaterial
		var garde := {"shader": mat.shader}
		for nom in ["capteur_actif", "lumiere_recue", "modele", "opacite_1", "opacite_2", "silhouette_1", "silhouette_2"]:
			garde[nom] = mat.get_shader_parameter(nom)
		gardes.append(garde)
		mat.set_shader_parameter("capteur_actif", false)
		mat.set_shader_parameter("lumiere_recue", LUMIERE)
		for m2: ShaderMaterial in [mat, profondeurs[j] as ShaderMaterial]:
			if m2 == null:
				continue
			m2.set_shader_parameter("opacite_1", 1.0)
			m2.set_shader_parameter("opacite_2", 1.0)
			m2.set_shader_parameter("silhouette_1", Vector4.ZERO)
			m2.set_shader_parameter("silhouette_2", Vector4.ZERO)
	for modele in [1.0, 0.0]:
		for j in 2:
			(mats[j] as ShaderMaterial).set_shader_parameter("modele", modele)
		await _prise(plans, "m%d" % int(modele))
	for j in 2:
		(mats[j] as ShaderMaterial).set_shader_parameter("modele", gardes[j]["modele"])
	# Quelle face est quel pixel : un corps à la fois, peint de sa normale monde, l'autre caché.
	var normales := Shader.new()
	normales.code = NORMALES
	for j in 2:
		(corps[1 - j] as Node3D).visible = false
		(mats[j] as ShaderMaterial).shader = normales
		await _prise(plans, "id%d" % (j + 1))
		(mats[j] as ShaderMaterial).shader = gardes[j]["shader"]
		(corps[1 - j] as Node3D).visible = true
	for c: Node3D in corps:
		c.visible = false
	await _prise(plans, "fond")
	for c: Node3D in corps:
		c.visible = true
	for j in 2:
		var mat := mats[j] as ShaderMaterial
		for nom in ["capteur_actif", "lumiere_recue", "opacite_1", "opacite_2", "silhouette_1", "silhouette_2"]:
			mat.set_shader_parameter(nom, gardes[j][nom])
	if interface != null:
		interface.process_mode = mode_interface
	p.get_tree().paused = false
	for k in 2:
		if armes_avant[k] != null:
			(m.p1 if k == 0 else m.p2).equip_weapon(armes_avant[k])


func _prise(plans: Array[Dictionary], suffixe: String) -> void:
	for k in 3:
		_tenir()
		await p.get_tree().process_frame
	await l._prise_entiere(plans, ID, suffixe, 0.4, _tenir)
	print("  MODELE_Q71 %s-%s" % [ID, suffixe])


## La scène tenue : positions, visées, torches éteintes.
func _tenir() -> void:
	var m: Node = p._main
	if not is_instance_valid(m.p1) or not is_instance_valid(m.p2):
		return
	m.p1.global_position = _pos[0]
	m.p2.global_position = _pos[1]
	for k in 2:
		p._viser(k, _visee[k])
		if k < p._pantins.size():
			p._pantins[k].torche = false
		Input.action_release("p%d_torch" % (k + 1))
		(m.p1 if k == 0 else m.p2).flashlight_on = false
	p._vivants()
