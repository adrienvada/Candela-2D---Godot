extends RefCounted
## Q41 — LE RAYON DANS L'AIR À L'IMAGE (session cloud « faisceau-air », 2026-09-28) : le plan `loupe-faisceau-air` de la loupe.
##
## Le rayon de `--faisceau-air` (`IsoVolumes._suivre_faisceau_air`) basculé SUR PLACE (`faisceau_air`, relu à chaque image),
## dans un même lancement, la caméra posée, le bandeau LED figé (`--led-murs-fige`), aucune fusée, aucun gadget. Une seule
## lampe allumée par bloc : celle dont on juge le rayon. Dans chaque bloc, A (sans rayon) CINQ fois — deux avant, une au
## milieu, deux après — et B, le rayon, à plusieurs densités (`densite_faisceau_air`). Critères écrits d'avance, jugés par
## `tools/faisceau_air/preuve.py` : là où TOUTES les A sont noires, chaque B l'est (0 pixel allumé dans le noir par le rayon) ;
## et le zéro n'est pas vide (les A contiennent du noir autour du cône).
##
## Les blocs :
## - `adv` : vue unique (J1), la lampe de J2 allumée, celle de J1 éteinte — le rayon ADVERSE vu de J1, sans le voile
##   d'éblouissement que sa propre torche poserait (il soulève tout l'écran de J1 à quelques /255 : aucun pixel noir) ;
## - `sien` : vue unique, la lampe de J1 allumée — son propre rayon, voile compris ;
## - `s1` / `s2` : écran scindé, la lampe de J1 (puis de J2) seule allumée — le rayon de chacun, vu des deux moitiés ;
## - `eq` : l'équité — J2 derrière un pilier, hors de vue de J1, lampe allumée ; J1 lampe éteinte. Ce que J1 voit sans le
##   rayon et avec, pour deux visées de J2.
## Chaque prise imprime une ligne `FAISCEAU <prise> vue <k> lampe x y milieu x y bord x y` : les points du cône à l'écran
## (pixels de l'image), où `preuve.py` mesure la densité en /255 (au milieu du cône et à son bord) et recadre ses loupes.

const ID := "loupe-faisceau-air"
const DENSITES := [0.15, 0.3, 0.45, 0.8]

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
	var faisceau_avant: bool = volumes.get("faisceau_air")
	var densite_avant: float = volumes.get("densite_faisceau_air")
	volumes.set("faisceau_air", false)
	var pilier: Rect2 = l.get("_pilier")
	var j1: Vector2 = l.get("_j1")
	var t := MursBas.TUILE
	print("  · %s : pilier %s, J1 %s ; lacet J1 %.1f°" % [ID, str(pilier), str(j1),
		float(m.call("lacet_de_la_vue", 0)) if m.has_method("lacet_de_la_vue") else 0.0])
	MurLed.est_actif()
	print("  · %s : bandeau LED %s" % [ID, "figé à %.2f de son sommet" % MurLed._fige if MurLed._fige >= 0.0
		else "qui RESPIRE — l'instant ne sera pas figé (--led-murs-fige)"])

	# LE RAYON ADVERSE, VU DE J1 (vue unique). J2 à trois tuiles à l'ouest de J1, visée vers le nord-ouest : loin de J1, pour
	# qu'il n'en soit pas ébloui ; J1 visée au nord, lampe éteinte.
	_poser(j1, j1 + Vector2(-3.0 * t, 0.0), Vector2.UP, Vector2(-0.6, -1.0), false, true)
	await _bloc(plans, "adv", false, true)
	# SON PROPRE RAYON (vue unique) : la lampe de J1 seule, visée au nord-ouest, loin du pilier (sa rétrodiffusion).
	_poser(j1, j1 + Vector2(-3.0 * t, 0.0), Vector2(-0.6, -1.0), Vector2.DOWN, true, false)
	await _bloc(plans, "sien", false, true)
	# L'ÉCRAN SCINDÉ : la lampe de J1 seule, puis celle de J2 seule — chaque moitié voit les deux rayons tour à tour.
	p._deux_vues()
	_poser(j1, j1 + Vector2(-3.0 * t, 0.0), Vector2(-0.6, -1.0), Vector2(-0.6, -1.0), true, false)
	await _bloc(plans, "s1", true, true)
	_poser(j1, j1 + Vector2(-3.0 * t, 0.0), Vector2(-0.6, -1.0), Vector2(-0.6, -1.0), false, true)
	await _bloc(plans, "s2", true, true)
	p._vue_unique()
	# L'ÉQUITÉ : J2 derrière le pilier (au nord de sa face nord), hors de vue de J1 ; deux visées.
	var derriere := Vector2(pilier.get_center().x, pilier.position.y - 0.8 * t)
	for v in [["eq-est", Vector2.RIGHT], ["eq-sud-ouest", Vector2(-1.0, 0.35)]]:
		_poser(j1, derriere, Vector2.UP, v[1], false, true)
		await _bloc(plans, String(v[0]), false, false)

	volumes.set("faisceau_air", faisceau_avant)
	volumes.set("densite_faisceau_air", densite_avant)
	m.set("_killcam_cadrage_tenu", false)


func _poser(pos1: Vector2, pos2: Vector2, visee1: Vector2, visee2: Vector2, torche1: bool, torche2: bool) -> void:
	_pos = [pos1, pos2]
	_visee = [visee1.normalized(), visee2.normalized()]
	_torche = [torche1, torche2]


## Tient la scène à chaque image : positions, visées, et la lampe voulue — allumée par le pantin et l'action tenue, éteinte
## par les deux relâchés (écrire `flashlight_on` seul ne suffit pas, le jeu l'écrase).
func _tenir() -> void:
	var m: Node = p._main
	if not is_instance_valid(m.p1) or not is_instance_valid(m.p2):
		return
	m.p1.global_position = _pos[0]
	m.p2.global_position = _pos[1]
	for k in 2:
		# La respiration de la torche (±3 %, `TORCH_BREATH_AMP`) sur une horloge figée : sans quoi l'énergie de la lampe ne se
		# tient jamais, et deux A diffèrent tout le long du bord du cône (premier lancement : la scène jamais tenue).
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


## Un bloc : la scène tenue jusqu'à ce que les caméras et les éblouissements ne bougent plus (au bit près, trente pas de
## physique de suite), la caméra de J1 posée ; puis A a1 | B aux densités | a2 | B à la densité par défaut | a3 a4.
func _bloc(plans: Array[Dictionary], nom: String, scinde: bool, densites: bool) -> void:
	var m: Node = p._main
	volumes.set("faisceau_air", false)
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
	print("  · %s-%s : %s ; caméras, éblouissements et lampes %s après %d pas ; éblouissement J1 %.4f J2 %.4f ; lampes J1 %s J2 %s"
		% [ID, nom, "écran scindé" if scinde else "vue unique", "tenus" if tenues >= 30 else "ENCORE EN MOUVEMENT", images,
		float(m.p1.dazzle_amount), float(m.p2.dazzle_amount), _torche[0], _torche[1]])
	var etapes: Array = [["a", 0.0], ["a1", 0.0]]
	if densites:
		for d in DENSITES:
			etapes.append(["b%02d" % int(round(d * 100.0)), d])
		etapes.append(["a2", 0.0])
	etapes.append(["b", -1.0])
	etapes.append_array([["a3", 0.0], ["a4", 0.0]])
	for e in etapes:
		var d: float = e[1]
		volumes.set("faisceau_air", d != 0.0)
		volumes.set("densite_faisceau_air", maxf(d, 0.0))
		# Deux images pour que le rayon soit posé (ou retiré) et sa lightmap poussée avant la prise.
		for k in 3:
			_tenir()
			await p.get_tree().process_frame
		var suffixe := "%s-%s" % [nom, e[0]]
		await l._prise_entiere(plans, ID, suffixe, 0.4, _tenir)
		_imprimer_le_cone(suffixe, scinde)
		var poses := 0
		for s: Dictionary in volumes.call("suivis"):
			if String(s["genre"]) == "faisceau_air":
				poses += (s["noeuds"] as Array).filter(func(n): return (n as Node3D).visible).size()
		print("  · %s-%s : rayon %s, densité %.2f, %d couche(s) visibles" % [ID, suffixe, "oui" if d != 0.0 else "non",
			float(volumes.call("densite_du_faisceau_air")) if d != 0.0 else 0.0, poses])
	volumes.set("faisceau_air", false)


## Les points du cône de chaque lampe allumée, à l'écran : la lampe, le milieu du cône (à mi-portée sur l'axe) et son bord
## (à mi-portée, à 85 % du demi-angle), dans chaque vue montrée.
func _imprimer_le_cone(suffixe: String, scinde: bool) -> void:
	var m: Node = p._main
	var taille := Vector2(DisplayServer.window_get_size())
	for j in 2:
		if not _torche[j]:
			continue
		var joueur: Node2D = m.p1 if j == 0 else m.p2
		var lampe := joueur.get_node(^"Flashlight") as PointLight2D
		var arme = joueur.current_weapon
		var demi := deg_to_rad(float(arme.torch_angle_deg)) if arme != null else deg_to_rad(35.0)
		var portee: float = float(arme.portee_torche()) if arme != null else 300.0
		var o := lampe.global_position
		var axe := Vector2.from_angle(lampe.global_rotation)
		var mil := o + axe * portee * 0.5
		var bord := o + axe.rotated(demi * 0.85) * portee * 0.5
		for vue in ([0, 1] if scinde else [0]):
			var a := _ecran(vue, o, taille)
			var b := _ecran(vue, mil, taille)
			var c := _ecran(vue, bord, taille)
			print("  FAISCEAU %s-%s lampe_de J%d vue %d lampe %.0f %.0f milieu %.0f %.0f bord %.0f %.0f" % [ID, suffixe, j + 1,
				vue, a.x, a.y, b.x, b.y, c.x, c.y])


## Un point du sol dans les pixels de la fenêtre capturée, par la caméra de la vue `vue` (en écran scindé, par l'affichage de
## sa sous-vue dans la fenêtre).
func _ecran(vue: int, monde: Vector2, taille: Vector2) -> Vector2:
	var pres := Presentation3D.instance()
	var cam: CameraIso = pres._camera_de(vue)
	if cam == null:
		return Vector2(-1, -1)
	var racine := p.get_tree().root.get_visible_rect().size
	if not bool(pres.get("_scinde")):
		var logique := pres.viewport_ecran(vue).get_visible_rect().size
		return cam.vers_ecran(monde, logique) * taille / logique
	var sv: SubViewport = pres.viewport_ecran(vue)
	var r: Rect2 = (pres.get("_affichages")[vue] as Control).get_global_rect()
	return (r.position + cam.vers_ecran(monde, Vector2(sv.size)) * r.size / Vector2(sv.size)) * taille / racine
