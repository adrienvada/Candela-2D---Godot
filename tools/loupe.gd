extends RefCounted
## LA LOUPE — la famille `loupe` du photographe : des recadrages 1:1 du jeu, pour juger la finition.
##
## Ordre 40 de la session cloud (pas 4 bis de la séquence de fin, 2026-09-15), sur le mot d'Adrien de
## 15:2x : « confronter vraiment les images en jeu aux images générées par Gemini […] sans pixels
## voyants ». Une capture réduite cache justement ce qu'on veut juger. Chaque loupe est donc un
## recadrage de 800×450 pris dans la fenêtre NATIVE (2560×1440 sur le Mac d'Adrien), SANS aucun
## redimensionnement, au cadrage par défaut du jeu (×1,8, décalage 0,25, portée ×0,75).
##
##     ./tools/run_photos.sh --famille=loupe --taille=2560x1440
##
## La carte par défaut est le Cloître (murs hauts intérieurs) ; `--carte-duel=<chemin>` en pose une autre.
## J1 se tient à 3,5 tuiles de la face sud d'un pilier, la torche braquée dessus. J2 est dans son cône,
## torche ÉTEINTE : braquée sur J1, elle l'éblouirait, et le voile couvrirait toutes les loupes.
##
## ⚠️ **La bande de fluidité veut des images CONSÉCUTIVES à 60 Hz.** Lire la texture fige le jeu le
## temps de la lecture ; en temps réel, la caméra rattraperait ce retard d'un bond à l'image suivante.
## Les trente images se prennent donc dans une séance lancée SEULE sous `--fixed-fps 60`, où chaque
## image avance le jeu d'exactement 1/60 s :
##
##     godot --path . --fixed-fps 60 res://tools/photographe.tscn -- --plan=loupe-fluidite --taille=2560x1440
##
## Sans ce drapeau, le plan ne relève que les temps d'image (sans capture, donc sans les fausser).
## Le panneau F3 affiche des images par seconde, pas de temps d'image ; ce sont ces relevés-ci qui les donnent.

const CARTE_DEFAUT := "res://assets/maps/map_001_le_cloitre.json"
const TAILLE_LOUPE := Vector2i(800, 450)
const FENETRE_NATIVE := Vector2i(2560, 1440)
## Hauteurs visées, en pixels de monde (la caméra iso compte la hauteur dans l'unité du sol). Le pied d'une
## face de mur haute de 1,25 tuile, bande d'encre et contact avec le sol compris ; le milieu d'un corps.
const HAUTEUR_PIED_DE_FACE := 14.0
const HAUTEUR_CORPS := 16.0
const IMAGES_FLUIDITE := 30

var p: Node
var _j1 := Vector2.ZERO
var _j2 := Vector2.ZERO
var _visee_j1 := Vector2.UP
var _pilier := Rect2()


static func catalogue() -> Array[Dictionary]:
	var c: Array[Dictionary] = []
	for e in [
		["loupe-pilier", "La face sud d'un pilier",
			"Sa bande d'encre au pied et son contact avec le sol, sous la torche : la matière du mur à 1:1."],
		["loupe-sol", "Le sol du cône et une trace",
			"Les dalles sous la torche et une tache de sang : le texel du sol et des traces à 1:1."],
		["loupe-corps", "Les deux corps",
			"J1 sous sa torche, J2 dans le cône : les arêtes des voxels, l'encre, le modelé."],
		["loupe-bord-cone", "Le bord du cône sur le sol",
			"Un bord de lumière qui marche en escalier ou qui glisse : la lightmap à ce zoom."],
		["loupe-ombre", "Le bord de l'ombre portée d'un pilier",
			"L'ombre de l'occluder, crénelée ou propre à ×1,8."],
		["loupe-hud", "Le HUD et le viseur",
			"Le texte et les cadres du HUD à la fenêtre native, le viseur posé au sol."],
		["loupe-led", "Le bandeau LED et sa lumière sur le mur",
			"Le dégradé du bandeau au sommet de sa respiration, loin de toute torche : bandes visibles ou non."],
		["loupe-balle", "Une balle en vol et son impact",
			"La traçante à l'image qui suit le tir, puis l'éclat et les étincelles sur le mur."],
		["loupe-fusee-suie", "Une fusée posée, un nuage de suie dedans",
			"Le halo de la fusée au sol et la fumée qui prend sa lumière."],
		["loupe-torche-fantome", "La torche fantôme posée, allumée",
			"Le sprite du gadget et son faisceau, dans le noir."],
		["loupe-torche-braconnier", "La torche fantôme à côté d'un vrai Braconnier",
			"ISO10, 1e : le leurre et l'original côte à côte, même arme, même visée, même nuit — les deux cônes doivent se confondre."],
		["loupe-scinde", "Pilier, corps et bord du cône en écran scindé",
			"Les loupes 1, 3 et 4 dans la vue 3D de J1."],
		["loupe-fluidite", "Trente images consécutives à 60 Hz",
			"J1 avance et tourne sa visée, la caméra glisse : un saut ou un hoquet se voit d'une image à l'autre."],
		["loupe-corps-msaa", "Les deux corps sans MSAA 3D, à ×2 et à ×4, et le coût de chaque niveau",
			"ISO10, 1d : l'escalier des arêtes des voxels contre ce que l'anticrénelage 3D de la fenêtre coûte par image."],
		["loupe-peinture", "La lumière qu'une face lirait en divisant la lightmap par la peinture seule",
			"ISO10, 1f, voie (E) : lightmap et peinture (lumières coupées), sans puis avec une tache de sang au pied de la face sud du pilier, et la bande que la face lit."],
		["loupe-face-sang", "La face sud du pilier avec du sang à son pied, lumière divisée par la peinture puis non",
			"ISO10, 1f : la face ne rougit plus du sang ; et la texture de peinture de la carte au même lieu (le CanvasModulate ne l'éteint pas)."],
		["loupe-peinture-cout", "Le coût d'un rendu de peinture à chaque image (mesure, sans image)",
			"ISO10, 1f : temps d'image avec la peinture refaite à chaque image, contre sans, en vue unique puis en écran scindé."],
		["loupe-cout-voile", "Le coût du voile plein au repos (mesure, sans image)",
			"ISO10, 1a : temps d'image avec la copie plein cadre et le voile plein forcés, contre le voile calme, en blocs alternés."],
	]:
		c.append({"id": e[0], "famille": "loupe", "source": "ecran", "titre": e[1], "pourquoi": e[2]})
	return c


## La famille entière, dans l'ordre : chaque loupe laisse le jeu dans un état que la suivante supporte
## (le sang reste au sol, la fusée et les gadgets partent avant l'écran scindé).
func famille(photographe: Node, plans: Array[Dictionary]) -> void:
	p = photographe
	var m: Node = p._main
	var fenetre := DisplayServer.window_get_size()
	if fenetre != FENETRE_NATIVE:
		printerr("  ! loupe : fenêtre %dx%d, pas %dx%d — chaque loupe reste 1:1, mais de CETTE fenêtre" % [
			fenetre.x, fenetre.y, FENETRE_NATIVE.x, FENETRE_NATIVE.y])
	p._ui.hub.reset()
	p._ui.hub.push(p._ui.SCREEN_LOCAL)
	m._on_replay_requested()
	if not await p._attendre(func() -> bool: return m.round_active, 20.0):
		printerr("  ✗ loupe : la manche n'a jamais démarré")
		return
	p._prendre_les_commandes()
	if not await p._attendre(func() -> bool: return m.countdown_left <= 0.0, 20.0):
		printerr("  ✗ loupe : le décompte n'a jamais fini")
		return
	p._torches(true)
	p._vue_unique()
	if String(p._carte_duel).ends_with("murs_bas_essai.json"):
		p._carte_duel = CARTE_DEFAUT
	await p._passer_sur_la_carte_des_murs_bas()
	var scene: Dictionary = p._scene_duel
	if not scene.has("rect"):
		printerr("  ✗ loupe : %s n'a aucun mur haut intérieur (%s)" % [p._carte_duel, scene.get("mur", "?")])
		await p._revenir_a_la_carte()
		return
	var t := MursBas.TUILE
	_pilier = scene["rect"]
	_j1 = scene["p1"]
	_j2 = _j1 + Vector2(48.0, -2.0 * t)
	_visee_j1 = Vector2.UP
	var arme = m.p1.current_weapon
	var demi := deg_to_rad(float(arme.torch_angle_deg)) if arme != null else deg_to_rad(35.0)
	var portee: float = float(arme.portee_torche()) if arme != null else 300.0
	print("  · loupe : pilier %s, J1 %s, J2 %s, demi-cône %.0f°, portée %.0f px" % [
		str(_pilier), str(_j1), str(_j2), rad_to_deg(demi), portee])

	var face := Vector2(_pilier.get_center().x, _pilier.end.y)
	await _prise(plans, "loupe-pilier", [["", func(img: Image) -> Vector2:
		return _pixel(img, face, HAUTEUR_PIED_DE_FACE)]], false, 1.2)

	# Le sang posé comme `bullet.gd` le pose (la tache et sa gerbe), sans tirer sur J2 : un tir le tuerait
	# peut-être, et la séance entière sortirait dans l'état d'après la mort (vu au Cloître, 15:20).
	var tache := _j1 + Vector2(-22.0, -1.8 * t)
	if p._demande(plans, "loupe-sol"):
		_poser_du_sang(tache)
	await _prise(plans, "loupe-sol", [["", func(img: Image) -> Vector2: return _pixel(img, tache)]])

	await _prise(plans, "loupe-corps", [
		["j1", func(img: Image) -> Vector2: return _pixel(img, _j1, HAUTEUR_CORPS)],
		["j2", func(img: Image) -> Vector2: return _pixel(img, _j2, HAUTEUR_CORPS)]])
	if p._demande(plans, "loupe-corps-msaa"):
		await _corps_msaa(plans)

	# Le bord OUEST du cône : à l'est, le pilier et le bloc voisin le coupent.
	var bord := _j1 + _visee_j1.rotated(-demi) * minf(170.0, portee * 0.55)
	await _prise(plans, "loupe-bord-cone", [["", func(img: Image) -> Vector2: return _pixel(img, bord)]])

	# L'ombre du pilier : le rayon de J1 par son coin sud-ouest, prolongé derrière lui dans la portée.
	var coin := Vector2(_pilier.position.x, _pilier.end.y)
	# ×1,6 et pas plus loin : à ×2,1 (premier essai), l'ombre tombait au bout de la portée, trop sombre pour juger.
	var ombre := _j1 + (coin - _j1) * minf(1.6, portee * 0.9 / maxf(_j1.distance_to(coin), 1.0))
	await _prise(plans, "loupe-ombre", [["", func(img: Image) -> Vector2: return _pixel(img, ombre)]])

	await _prise(plans, "loupe-hud", [
		["hud", func(_img: Image) -> Vector2: return Vector2(TAILLE_LOUPE) * 0.5],
		["viseur", func(img: Image) -> Vector2: return _pixel(img, _viseur_monde())]])

	if p._demande(plans, "loupe-led"):
		await _loupe_led(plans, portee, demi)
	if p._demande(plans, "loupe-balle"):
		await _loupe_balle(plans)

	# La caméra doit être posée AVANT de choisir des lieux « à l'écran » : lancé seul, un plan arrive ici sans que les
	# prises précédentes aient laissé le regard se poser, et la fusée tombait hors du cadre (ISO10, 1c, 17:35).
	for n in 30:
		_tenir_scene()
		await p.get_tree().process_frame
	var lieux := _lieux_dans_le_noir(portee)
	var fusee: Node = null
	if p._demande(plans, "loupe-fusee-suie"):
		if lieux.is_empty():
			printerr("  ✗ loupe-fusee-suie : aucun sol dégagé à l'écran hors de la torche")
		else:
			fusee = await _loupe_fusee_suie(plans, lieux[0])
	if p._demande(plans, "loupe-torche-fantome"):
		var lieu := Vector2.INF
		for l in lieux:
			if lieux.is_empty() or l.distance_to(lieux[0]) > 320.0:
				lieu = l
				break
		if lieu == Vector2.INF:
			printerr("  ✗ loupe-torche-fantome : aucun second lieu dégagé à l'écran")
		else:
			await _loupe_torche_fantome(plans, lieu)
	if p._demande(plans, "loupe-torche-braconnier"):
		await _loupe_torche_braconnier(plans, lieux)
	if fusee != null and is_instance_valid(fusee):
		fusee.queue_free()
	await p._ranger_les_gadgets()

	if p._demande(plans, "loupe-scinde"):
		p._deux_vues()
		await _prise(plans, "loupe-scinde", [
			["pilier", func(img: Image) -> Vector2: return _pixel(img, face, HAUTEUR_PIED_DE_FACE)],
			["corps-j1", func(img: Image) -> Vector2: return _pixel(img, _j1, HAUTEUR_CORPS)],
			["corps-j2", func(img: Image) -> Vector2: return _pixel(img, _j2, HAUTEUR_CORPS)],
			["bord-cone", func(img: Image) -> Vector2: return _pixel(img, bord)]], true, 1.0)
		p._vue_unique()

	# Après tout le reste : la tache posée au pied du pilier resterait dans les loupes qui suivent.
	if p._demande(plans, "loupe-peinture"):
		await _loupe_peinture(plans, face)
	if p._demande(plans, "loupe-face-sang"):
		await _loupe_face_sang(plans, face)
	if p._demande(plans, "loupe-peinture-cout"):
		await _cout_peinture()

	if p._demande(plans, "loupe-cout-voile"):
		await _cout_du_voile()

	if p._demande(plans, "loupe-fluidite"):
		await _fluidite(plans)

	p._viser_par_defaut()
	await p._revenir_a_la_carte()


# ---------------------------------------------------------------------------
# LA PRISE
# ---------------------------------------------------------------------------

## Tient la scène `repos` secondes, prend UNE image et en écrit chaque recadrage. `recadrages` est une
## liste de [suffixe, centre], où `centre` est une `Callable(img) -> Vector2` en pixels de l'image, appelée
## APRÈS la prise (projetée par la caméra de l'image prise, à la taille de l'image prise).
func _prise(plans: Array[Dictionary], id: String, recadrages: Array, scinde := false,
		repos := 0.6, tenir := Callable()) -> void:
	var plan: Dictionary = p._plan(plans, id)
	if plan.is_empty():
		return
	var garde: Callable = tenir if tenir.is_valid() else _tenir_scene
	var fin := Time.get_ticks_msec() + int(repos * 1000.0)
	while Time.get_ticks_msec() < fin:
		garde.call()
		await p.get_tree().process_frame
	garde.call()
	var img: Image = await _capturer(scinde)
	if img == null:
		p._perdues += 1
		printerr("  ✗ loupe %s : prise perdue" % id)
		return
	for r in recadrages:
		var sous: Dictionary = plan if String(r[0]) == "" else p._derive(plans, id, String(r[0]), "")
		var centre: Vector2 = (r[1] as Callable).call(img)
		# Un centre hors de l'image donne une loupe recadrée contre le bord, qui ne montre pas son sujet : le dire.
		if centre.x < 0.0 or centre.y < 0.0 or centre.x > img.get_width() or centre.y > img.get_height():
			printerr("  ! loupe %s : centre (%.0f, %.0f) HORS de l'image %dx%d — la loupe ne montre pas son sujet" % [
				String(plan["id"]) if String(r[0]) == "" else "%s-%s" % [id, r[0]], centre.x, centre.y,
				img.get_width(), img.get_height()])
		# ISO10, 1a — l'éblouissement de J1 à la prise : la rétrodiffusion de sa propre torche le tient
		# au-dessus de 0 au repos, et l'aberration du voile en dépend (planche de loupe, tour 1).
		print("  MESURE %s centre %.0f %.0f image %dx%d eblouissement_j1 %.3f" % [sous["id"], centre.x,
			centre.y, img.get_width(), img.get_height(), float(p._main.p1.dazzle_amount)])
		p._ecrire(sous, recadrer(img, centre))


## La fenêtre entière en vue unique (HUD compris) ; en écran scindé, la sous-vue 3D de J1 telle
## qu'elle est rendue, sans rien de l'interface.
func _capturer(scinde: bool) -> Image:
	p._au_premier_plan()
	if not scinde:
		return await RenduCommun.capturer(p.get_tree(), 4000)
	await RenderingServer.frame_post_draw
	var pres := Presentation3D.instance()
	var vue: Viewport = pres.viewport_ecran(0) if pres != null else null
	return vue.get_texture().get_image() if vue != null else null


## Un rectangle de `taille` centré sur `centre` et tenu dans l'image — sans redimensionnement.
static func recadrer(img: Image, centre: Vector2, taille := TAILLE_LOUPE) -> Image:
	var w := mini(taille.x, img.get_width())
	var h := mini(taille.y, img.get_height())
	var x := clampi(int(round(centre.x)) - w / 2, 0, img.get_width() - w)
	var y := clampi(int(round(centre.y)) - h / 2, 0, img.get_height() - h)
	return img.get_region(Rect2i(x, y, w, h))


## Le point `monde` (à `hauteur`) dans les pixels de `img`, par la caméra iso de J1.
func _pixel(img: Image, monde: Vector2, hauteur := 0.0) -> Vector2:
	return _pixel_taille(Vector2(img.get_size()), monde, hauteur)


func _pixel_taille(taille: Vector2, monde: Vector2, hauteur := 0.0) -> Vector2:
	var pres := Presentation3D.instance()
	var vue: Viewport = pres.viewport_ecran(0) if pres != null else null
	var cam = pres._camera_de(0) if pres != null else null
	if vue == null or cam == null:
		return taille * 0.5
	# Unités logiques du viewport → pixels de l'image : en vue unique, la fenêtre native est plus grande
	# que son aire logique (1920×1080 étirée).
	var logique := vue.get_visible_rect().size
	return cam.vers_ecran(monde, logique, hauteur) * taille / logique


func _tenir_scene() -> void:
	var m: Node = p._main
	if not is_instance_valid(m.p1) or not is_instance_valid(m.p2):
		return
	m.p1.global_position = _j1
	m.p2.global_position = _j2
	p._viser(0, _visee_j1)
	p._viser(1, Vector2.RIGHT)
	if p._pantins.size() > 1:
		p._pantins[0].torche = true
		p._pantins[1].torche = false
	Input.action_release("p2_torch")
	m.p2.flashlight_on = false
	p._vivants()


# ---------------------------------------------------------------------------
# LES MISES EN SCÈNE
# ---------------------------------------------------------------------------

## `direction` : l'axe du tir, où l'éclaboussure s'étire. Vers le haut par défaut (les loupes du tour 1).
func _poser_du_sang(pos: Vector2, direction := Vector2.UP) -> void:
	var arene: Node = p._main.arena
	if arene == null:
		return
	# ISO10, 1b — la même tache à chaque séance : `blood_stain` tire sa planche au hasard, et deux séances
	# posaient deux taches de tailles différentes (tour 1 contre 1b). Une loupe « avant / après » qui change de
	# sujet ne compare plus rien.
	seed(40)
	for gerbe in [false, true]:
		var tache := Node2D.new()
		tache.set_script(preload("res://blood_stain.gd"))
		arene.add_child(tache)
		tache.setup(pos, direction, INF, gerbe)


func _viseur_monde() -> Vector2:
	var v := p._main.p1.get_node_or_null("Viseur") as Node2D
	return v.global_position if v != null else _j1 + _visee_j1 * 110.0


## Le bandeau tenu au sommet de sa respiration, sur la face sud d'un mur loin de toute torche.
func _loupe_led(plans: Array[Dictionary], portee: float, demi: float) -> void:
	var arene: Node = p._main.arena
	var led: Node = arene.get_node_or_null(MurLed.NOM) if arene != null else null
	if led == null:
		printerr("  ! loupe-led : aucun bandeau posé sur cette carte")
	var mur := _mur_dans_le_noir(portee, demi)
	var tenir := func() -> void:
		_tenir_scene()
		if led != null and is_instance_valid(led):
			led.regler(1.0)
	await _prise(plans, "loupe-led", [["", func(img: Image) -> Vector2:
		return _pixel(img, mur, HAUTEUR_PIED_DE_FACE)]], false, 0.8, tenir)


## La face sud d'un mur à l'écran que la torche de J1 n'atteint pas (hors de sa portée, ou à plus de
## 15° hors de son cône), la plus proche du centre de l'écran.
##
## ⚠️ **« Hors de portée » seul ne trouvait rien au Cloître** (premier essai de la loupe) : à ×1,8, tout mur à
## l'écran est à moins de 370 px de J1, et la loupe retombait sur la face du pilier SOUS la torche.
func _mur_dans_le_noir(portee: float, demi: float) -> Vector2:
	var t := MursBas.TUILE
	var taille := Vector2(DisplayServer.window_get_size())
	var marge := Vector2(TAILLE_LOUPE) * 0.5
	var meilleur := Vector2(_pilier.get_center().x, _pilier.end.y)
	var ecart := INF
	for r in IsoGeometrie.rects_px(MapData.current_map_data, MapGeometry.Kind.WALLS, Vector2(t, t)):
		var x := r.position.x + t
		while x <= r.end.x - t + 0.5:
			var pt := Vector2(x, r.end.y)
			var q := _pixel_taille(taille, pt, HAUTEUR_PIED_DE_FACE)
			var hors_torche := pt.distance_to(_j1) > portee + 30.0 \
					or absf(_visee_j1.angle_to(pt - _j1)) > demi + deg_to_rad(15.0)
			if q.x > marge.x and q.x < taille.x - marge.x and q.y > marge.y and q.y < taille.y - marge.y \
					and hors_torche and p._sol_libre(pt + Vector2(0.0, 1.5 * t)):
				var d := q.distance_to(taille * 0.5)
				if d < ecart:
					ecart = d
					meilleur = pt
			x += t
	print("  · loupe-led : face sud en %s" % str(meilleur))
	return meilleur


## Une balle tirée le long de la ligne libre la plus longue qui reste à l'écran, loin de J2 : la
## traçante à l'image qui suit le tir, puis l'éclat sur le mur.
func _loupe_balle(plans: Array[Dictionary]) -> void:
	var m: Node = p._main
	var ligne := _ligne_de_tir_libre()
	var dir: Vector2 = ligne["dir"]
	var impact: Vector2 = ligne["impact"]
	print("  · loupe-balle : direction %s, impact %s à %.0f px" % [str(dir), str(impact), float(ligne["l"])])
	_visee_j1 = dir
	for n in 30:
		_tenir_scene()
		await p.get_tree().process_frame
	m.p1.shoot()
	await _prise(plans, "loupe-balle", [["vol", func(img: Image) -> Vector2:
		return _pixel(img, _j1 + dir * 170.0, 10.0)]], false, 0.0)
	await _prise(plans, "loupe-balle", [["impact", func(img: Image) -> Vector2:
		return _pixel(img, impact, 10.0)]], false, 0.12)
	_visee_j1 = Vector2.UP


func _ligne_de_tir_libre() -> Dictionary:
	var m: Node = p._main
	var espace := (m.p1 as Node2D).get_world_2d().direct_space_state
	var vers_j2 := (_j2 - _j1).normalized()
	var choix := {"dir": Vector2(-0.707, -0.707), "impact": _j1 + Vector2(-0.707, -0.707) * 300.0, "l": 300.0}
	var ecart := INF
	var taille := Vector2(DisplayServer.window_get_size())
	var marge := Vector2(TAILLE_LOUPE) * 0.5
	for k in 32:
		var d := Vector2.RIGHT.rotated(TAU * float(k) / 32.0)
		if d.dot(vers_j2) > 0.2:
			continue
		var q := PhysicsRayQueryParameters2D.create(_j1, _j1 + d * 1200.0, MapGeometry.WALL_LAYER)
		q.exclude = [m.p1.get_rid(), m.p2.get_rid()]
		var r := espace.intersect_ray(q)
		if r.is_empty():
			continue
		var l := _j1.distance_to(r["position"])
		# L'impact ENTIER dans une loupe à l'écran, sous le HUD (premier essai de la loupe : contre le bord gauche,
		# recadré sous le panneau du joueur) ; et la ligne assez longue pour voir la balle en vol.
		var ecran := _pixel_taille(taille, r["position"], 10.0)
		if ecran.x < marge.x or ecran.x > taille.x - marge.x or ecran.y < marge.y * 2.0 \
				or ecran.y > taille.y - marge.y or l < 200.0:
			continue
		if absf(l - 380.0) < ecart:
			ecart = absf(l - 380.0)
			choix = {"dir": d, "impact": r["position"], "l": l}
	return choix


## Des points de sol dégagé à l'écran, hors de la portée de J1 et loin de J2, du plus proche au plus loin.
func _lieux_dans_le_noir(portee: float) -> Array[Vector2]:
	var t := MursBas.TUILE
	var taille := Vector2(DisplayServer.window_get_size())
	var marge := Vector2(TAILLE_LOUPE) * 0.5 + Vector2(40.0, 40.0)
	var grille := Vector2(MapCodec.get_grid_size(MapData.current_map_data)) * t
	var out: Array[Vector2] = []
	var y := t * 1.5
	while y < grille.y:
		var x := t * 1.5
		while x < grille.x:
			var pt := Vector2(x, y)
			var q := _pixel_taille(taille, pt)
			if q.x > marge.x and q.x < taille.x - marge.x and q.y > marge.y and q.y < taille.y - marge.y \
					and pt.distance_to(_j1) > portee + 60.0 and pt.distance_to(_j2) > 160.0 and p._sol_libre(pt):
				out.append(pt)
			x += t
		y += t
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(_j1) < b.distance_to(_j1))
	return out


## La fusée posée comme le banc des gadgets la pose (`forcer_age`), et la cartouche de suie de J2
## dans son halo. Rend la fusée, que la famille retire avant l'écran scindé.
func _loupe_fusee_suie(plans: Array[Dictionary], lieu: Vector2) -> Node:
	var m: Node = p._main
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", lieu)
	f.set("direction", Vector2.DOWN)
	f.set("joueurs", [m.p1, m.p2])
	m.bullet_container.add_child(f)
	await p.get_tree().process_frame
	f.set_physics_process(false)
	f.global_position = lieu
	f.call("forcer_age", 1.0)
	m._do_spawn_gadget(1, lieu + Vector2(20.0, 10.0), 0.0, "cartouche_suie", 9501)
	print("  · loupe-fusee-suie : fusée et suie en %s" % str(lieu))
	await _prise(plans, "loupe-fusee-suie", [["", func(img: Image) -> Vector2:
		return _pixel(img, lieu, 8.0)]], false, 1.6)
	# ISO10, 1c — la même fusée, volumes iso COUPÉS (`IsoVolumes.images_actives`, le geste du banc des gadgets) : les
	# « anneaux » du tour 1 ressemblent aux copies décalées d'une même volute, une par couche de fumée empilée. Si
	# elles disparaissent sans les volumes, la cause est là.
	var pres := Presentation3D.instance()
	var miroirs: Object = pres.get("_miroirs") if pres != null else null
	var volumes: Object = miroirs.get("volumes") if miroirs != null else null
	if volumes != null:
		volumes.set("images_actives", false)
		await _prise(plans, "loupe-fusee-suie", [["sans-volumes", func(img: Image) -> Vector2:
			return _pixel(img, lieu, 8.0)]], false, 0.4)
		volumes.set("images_actives", true)
	else:
		printerr("  ! loupe-fusee-suie : volumes iso introuvables, pas de prise sans volumes")
	# ISO10, 1c — la même fusée passée à la BRAISE (8 s de combustion : pleine flamme 2 s, braise 10 s), pour juger ses
	# deux phases (consigne de la session cloud, 16:42) : juste posée, rouge de détresse ; puis orange de braise.
	f.call("forcer_age", 8.0)
	await _prise(plans, "loupe-fusee-suie", [["braise", func(img: Image) -> Vector2:
		return _pixel(img, lieu, 8.0)]], false, 0.8)
	return f


## La torche fantôme posée par J1, équipé le temps de la pose de la classe qui la porte :
## `_do_spawn_gadget` prend son profil (cookie, durée de vie) à la classe ÉQUIPÉE.
func _loupe_torche_fantome(plans: Array[Dictionary], lieu: Vector2) -> void:
	var m: Node = p._main
	var classe = p._classe_du_gadget("torche_fantome")
	var arme_avant = m.p1.current_weapon
	if classe != null:
		m.p1.equip_weapon(classe)
	m._do_spawn_gadget(0, lieu, -PI / 2.0, "torche_fantome", 9502)
	var g = p._gadget_de(0)
	if g == null:
		printerr("  ✗ loupe-torche-fantome : la torche fantôme n'a pas été posée")
	else:
		g.duree_vie = 0.0
	print("  · loupe-torche-fantome : posée en %s" % str(lieu))
	await _prise(plans, "loupe-torche-fantome", [["", func(img: Image) -> Vector2:
		return _pixel(img, lieu + Vector2(0.0, -40.0), 8.0)]], false, 1.0)
	if arme_avant != null:
		m.p1.equip_weapon(arme_avant)


## ISO10, 1e — la torche fantôme contre l'original. Sa spécification (chantier CLASSES, étape 11) : « même
## faisceau, même température, même découpe des corps » qu'un Braconnier qui fouille la pièce. La loupe du tour 1
## la montrait à côté du PISTOLET de J1 (35°) ; ici J1 est un vrai Braconnier (arbalète, 5°), torche allumée,
## et sa torche fantôme est posée 150 px à l'est, même visée, dans le noir.
##
## ⚠️ **Son balayage est FIGÉ dans l'axe de pose le temps de la prise** (`_physics_process` coupé,
## `rotation = _angle_depart`) : elle balaie comme une main, et deux cônes à des angles différents ne se
## comparent pas. Le figer ne change rien au faisceau lui-même.
func _loupe_torche_braconnier(plans: Array[Dictionary], lieux: Array[Vector2]) -> void:
	var m: Node = p._main
	var classe = p._classe_du_gadget("torche_fantome")
	if classe == null:
		printerr("  ✗ loupe-torche-braconnier : aucune classe ne porte la torche fantôme")
		return
	var ecart := Vector2(150.0, 0.0)
	var devant := Vector2(0.0, -120.0)
	# Un coin sombre où les DEUX lampes ont du sol dégagé devant elles, et où leurs DEUX loupes tiennent entières
	# dans l'écran : au premier essai, la loupe du leurre butait contre le bord droit, son fond tombait sur un
	# mur éclairé et la mesure ne comparait plus rien. On essaie le leurre à l'est, puis à l'ouest.
	var taille := Vector2(DisplayServer.window_get_size())
	var marge := Vector2(TAILLE_LOUPE) * 0.5 + Vector2(20.0, 20.0)
	var dans_l_ecran := func(pt: Vector2) -> bool:
		var q := _pixel_taille(taille, pt)
		return q.x > marge.x and q.x < taille.x - marge.x and q.y > marge.y and q.y < taille.y - marge.y
	var depart := Vector2.INF
	for l in lieux:
		for sens in [1.0, -1.0]:
			var e: Vector2 = ecart * sens
			if p._sol_libre(l + e) and p._sol_libre(l + devant) and p._sol_libre(l + e + devant) \
					and dans_l_ecran.call(l + devant) and dans_l_ecran.call(l + e + devant):
				depart = l
				ecart = e
				break
		if depart != Vector2.INF:
			break
	if depart == Vector2.INF:
		printerr("  ✗ loupe-torche-braconnier : aucun coin sombre avec du sol dégagé devant les deux lampes")
		return
	var arme_avant = m.p1.current_weapon
	var j1_avant := _j1
	var visee_avant := _visee_j1
	m.p1.equip_weapon(classe)
	_j1 = depart
	_visee_j1 = Vector2.UP
	for n in 20:
		_tenir_scene()
		await p.get_tree().process_frame
	m._do_spawn_gadget(0, _j1 + ecart, -PI / 2.0, "torche_fantome", 9503)
	var g = p._gadget_de(0)
	if g == null:
		printerr("  ✗ loupe-torche-braconnier : la torche fantôme n'a pas été posée")
	else:
		g.duree_vie = 0.0
		g.set_physics_process(false)
		g.rotation = float(g.get("_angle_depart"))
	print("  · loupe-torche-braconnier : J1 %s, torche fantôme %s, demi-cône %.0f°, portée %.0f px" % [
		str(_j1), str(_j1 + ecart), float(classe.torch_angle_deg), float(classe.portee_torche())])
	# Premier essai : le leurre rendait 0,68 de la lumière de l'original loin de la lampe, à énergie et cookie
	# égaux dans le code. Les deux lumières, propriété par propriété, telles qu'elles sont à la prise.
	for _k in 3:
		_tenir_scene()
		await p.get_tree().process_frame
	var lumieres := {"original": m.p1.get("flashlight"), "leurre": g.get("_lumiere") if g != null else null}
	for nom in lumieres:
		var l: Light2D = lumieres[nom]
		if l == null:
			print("  MESURE lumiere %s absente" % nom)
			continue
		var tex_chemin: String = l.texture.resource_path if l.texture != null else "aucune"
		var tex_taille: Vector2 = l.texture.get_size() if l.texture != null else Vector2.ZERO
		print("  MESURE lumiere %s texture %s %s echelle %.4f energie %.3f couleur %s hauteur %.2f ombre %s filtre %d lissage %.2f masque_portee %d masque_ombre %d melange %d decalage %s position %s rotation %.3f active %s" % [
			nom, tex_chemin, str(tex_taille), float(l.get("texture_scale")), l.energy, str(l.color), l.height,
			str(l.shadow_enabled), int(l.shadow_filter), l.shadow_filter_smooth, l.range_item_cull_mask,
			l.shadow_item_cull_mask, int(l.blend_mode), str(l.get("offset")), str(l.global_position),
			l.global_rotation, str(l.enabled)])
	await _prise(plans, "loupe-torche-braconnier", [
		["original", func(img: Image) -> Vector2: return _pixel(img, _j1 + devant)],
		["leurre", func(img: Image) -> Vector2: return _pixel(img, _j1 + ecart + devant)]], false, 1.0)
	await p._ranger_les_gadgets()
	_j1 = j1_avant
	_visee_j1 = visee_avant
	if arme_avant != null:
		m.p1.equip_weapon(arme_avant)


# ---------------------------------------------------------------------------
# LE COÛT DU VOILE AU REPOS (ISO10, 1a)
# ---------------------------------------------------------------------------

## Ce que coûtaient la copie plein cadre et le voile plein tant que la rétrodiffusion les tenait allumés au
## repos. Même scène, même image : huit blocs de 120 images, alternés A/B pour que la dérive (chauffe du GPU,
## mise au premier plan) se partage entre les deux. A = `_voile_bb` visible et voile plein posés à chaque
## image, comme avant 1a ; B = le jeu tel qu'il est (voile calme, copie éteinte). Les temps d'image se lisent
## entre deux `frame_post_draw`, sans capture.
## ISO10, 1f, voie (E) — MESURE, jamais le jeu : la lumière qu'une face lirait en divisant la lightmap par la PEINTURE
## seule. La peinture est prise dans la lightmap même (même cadrage, même filtrage) : une image les Light2D coupées et
## le `CanvasModulate` caché, soit l'albédo de tout ce qui se dessine. Quatre images — lightmap et peinture, sans puis
## avec une tache de sang au pied de la face sud du pilier — et la bande que la face lit, en texels de la lightmap.
## ⚠️ Pas une copie des calques dans une vue à part : `duplicate()` perd les variables de script, et le décor comme
## l'encre des murs ne s'y redessineraient pas. Les lumières restent coupées deux images, le temps d'une prise.
func _loupe_peinture(plans: Array[Dictionary], face: Vector2) -> void:
	var m: Node = p._main
	var vue: SubViewport = m.vp1
	var pied := IsoMateriaux.PIED_FACE_PX
	var bande_a := face + Vector2(-_pilier.size.x * 0.5, pied)
	var bande_b := face + Vector2(_pilier.size.x * 0.5, pied)
	# « sans-sang-bis » : la même scène reprise, sans rien changer — le bruit entre deux prises (la torche respire, ±3 %),
	# sous lequel aucun écart de la voie (E) ne se lit. Deuxième passage : 11 % d'écart sans que la tache touche la bande.
	for etat in ["sans-sang", "sans-sang-bis", "avec-sang"]:
		if etat == "avec-sang":
			# ⚠️ Vers le BAS, depuis le pied de la face : posée vers le haut (deuxième passage), l'éclaboussure filait
			# sous le pilier et une seule traînée croisait la bande — la rougeur lue changeait à peine (1,15 → 1,17).
			_poser_du_sang(face + Vector2(0.0, 4.0), Vector2.DOWN)
		for n in 30:
			_tenir_scene()
			await p.get_tree().process_frame
		var lightmap: Image = await _image_de_vue(vue)
		var coupees := _couper_les_lumieres(m)
		var peinture: Image = await _image_de_vue(vue, coupees)
		_rendre_les_lumieres(coupees)
		print("  · loupe-peinture %s : %d lumières et modulations coupées le temps de la prise" % [etat, coupees.size()])
		for paire in [["lightmap", lightmap], ["peinture", peinture]]:
			p._ecrire(p._derive(plans, "loupe-peinture", "%s-%s" % [etat, paire[0]], ""), paire[1])
	var ct: Transform2D = vue.canvas_transform
	var logique := Vector2(vue.size_2d_override) if vue.size_2d_override != Vector2i.ZERO else Vector2(vue.size)
	var echelle := Vector2(vue.size) / logique
	var a := (ct * bande_a) * echelle
	var b := (ct * bande_b) * echelle
	var j1 := (ct * _j1) * echelle
	print("  MESURE loupe-peinture bande %.1f %.1f %.1f %.1f j1 %.1f %.1f lightmap %dx%d pied %.0f" % [a.x, a.y, b.x, b.y,
		j1.x, j1.y, vue.size.x, vue.size.y, pied])


## ISO10, 1f — la face sud du pilier avec du sang à son pied, vue par la vue iso : la lumière divisée par la peinture
## (le jeu), puis la lightmap relue telle quelle (`peinture_active` coupé le temps d'une prise). Et la texture de peinture
## de la carte recadrée au même lieu : si le `CanvasModulate` l'éteignait, elle serait noire.
func _loupe_face_sang(plans: Array[Dictionary], face: Vector2) -> void:
	var pres := Presentation3D.instance()
	var pe: SubViewport = pres.peinture() if pres != null else null
	var mat: ShaderMaterial = pres.get("_mat_mur") if pres != null else null
	if pe == null or mat == null:
		printerr("  ✗ loupe-face-sang : la peinture ou le matériau des murs est absent (vue iso éteinte ?)")
		return
	_poser_du_sang(face + Vector2(0.0, 4.0), Vector2.DOWN)
	var centre := func(img: Image) -> Vector2: return _pixel(img, face, HAUTEUR_PIED_DE_FACE)
	await _prise(plans, "loupe-face-sang", [["peinture", centre]], false, 1.0)
	mat.set_shader_parameter("peinture_active", false)
	await _prise(plans, "loupe-face-sang", [["lightmap-seule", centre]], false, 0.4)
	mat.set_shader_parameter("peinture_active", true)
	await RenderingServer.frame_post_draw
	var img: Image = pe.get_texture().get_image()
	var cadre: Rect2 = pe.get("cadre")
	var echelle := float(pe.get("echelle"))
	var texel := (face - cadre.position) * echelle
	var morceau := recadrer(img, texel)
	var somme := 0.0
	for y in range(0, morceau.get_height(), 4):
		for x in range(0, morceau.get_width(), 4):
			somme += morceau.get_pixel(x, y).get_luminance()
	var n := float((morceau.get_height() / 4) * (morceau.get_width() / 4))
	p._ecrire(p._derive(plans, "loupe-face-sang", "texture-peinture", ""), morceau)
	print("  MESURE loupe-face-sang peinture %dx%d texels, %.2f texel/px, %.1f Mo, %d rendus, %d traces peintes, luminance moyenne au lieu %.3f"
		% [pe.size.x, pe.size.y, echelle, float(pe.call("memoire_mo")), int(pe.get("rendus")),
		(pe.get("_copies") as Dictionary).size(), somme / maxf(n, 1.0)])


## ISO10, 1f — le coût d'un rendu de peinture : blocs alternés de 120 images, la peinture redemandée à chaque image
## (le pire cas d'une rafale : les demandes d'une même image n'en font qu'un) contre aucune, en vue unique puis en
## écran scindé. Le changement de vue rallume la vue iso et refait la peinture : elle est relue après.
func _cout_peinture() -> void:
	for scinde in [false, true]:
		if scinde:
			p._deux_vues()
		for n in 60:
			_tenir_scene()
			await p.get_tree().process_frame
		var pres := Presentation3D.instance()
		var pe: SubViewport = pres.peinture() if pres != null else null
		if pe == null:
			printerr("  ✗ loupe-peinture-cout : pas de peinture (%s)" % ("scindé" if scinde else "vue unique"))
			continue
		var sommes := {"A": 0.0, "B": 0.0}
		var comptes := {"A": 0, "B": 0}
		var rendus_avant := int(pe.get("rendus"))
		for bloc in 8:
			var force := bloc % 2 == 0
			var cle := "A" if force else "B"
			await RenderingServer.frame_post_draw
			var avant := Time.get_ticks_usec()
			for k in 120:
				_tenir_scene()
				if force:
					pe.call("salir")
				await RenderingServer.frame_post_draw
				var maintenant := Time.get_ticks_usec()
				sommes[cle] += float(maintenant - avant) / 1000.0
				comptes[cle] += 1
				avant = maintenant
		var a: float = float(sommes["A"]) / maxf(float(comptes["A"]), 1.0)
		var b: float = float(sommes["B"]) / maxf(float(comptes["B"]), 1.0)
		print("  MESURE loupe-peinture-cout %s : peinture à chaque image %.3f ms, sans %.3f ms, écart %.3f ms (%d rendus pour %d images forcées, %dx%d texels)"
			% ["écran scindé" if scinde else "vue unique", a, b, a - b, int(pe.get("rendus")) - rendus_avant, comptes["A"],
			pe.size.x, pe.size.y])
		if scinde:
			p._vue_unique()


## Trois images rendues, puis la texture de la vue : la première peut encore être celle d'avant le changement.
## `coupees` : recoupées JUSTE AVANT chaque rendu. ⚠️ Premier passage : coupées une seule fois, la torche
## revenait dans la « peinture » — `player.gd` repose `flashlight.enabled = true` à chaque image tant qu'elle est
## allumée, et le cône se lisait en clair sur l'albédo.
func _image_de_vue(vue: SubViewport, coupees: Array = []) -> Image:
	for k in 3:
		_tenir_scene()
		await RenderingServer.frame_pre_draw
		_recouper(coupees)
		await RenderingServer.frame_post_draw
	return vue.get_texture().get_image()


func _recouper(coupees: Array) -> void:
	for o in coupees:
		if not is_instance_valid(o):
			continue
		if o is Light2D:
			(o as Light2D).enabled = false
		else:
			(o as CanvasItem).visible = false


func _couper_les_lumieres(racine: Node) -> Array:
	var coupees := []
	for n in racine.find_children("*", "Light2D", true, false):
		var l := n as Light2D
		if l.enabled:
			l.enabled = false
			coupees.append(l)
	for n in racine.find_children("*", "CanvasModulate", true, false):
		var c := n as CanvasModulate
		if c.visible:
			c.visible = false
			coupees.append(c)
	return coupees


func _rendre_les_lumieres(coupees: Array) -> void:
	for o in coupees:
		if not is_instance_valid(o):
			continue
		if o is Light2D:
			(o as Light2D).enabled = true
		else:
			(o as CanvasItem).visible = true


## ISO10, 1d — l'anticrénelage 3D des corps, mesuré avant d'être posé. En vue unique la 3D est rendue par la
## fenêtre elle-même (`Presentation3D.viewport_ecran`) : c'est donc son `msaa_3d` qu'on règle. Trois niveaux pris
## à l'image, puis leur coût en blocs alternés de 120 images ; le réglage d'origine est rendu à la fin.
## Premier essai : sur une seule ligne, le bord du corps sautait de 22 à 103 à ×4 comme sans — une arête DROITE, qu'aucun
## anticrénelage ne peut adoucir. D'où la mesure sur toutes les transitions fortes du centre, et deux prises de plus :
## le FXAA de la fenêtre (sans effet sous `gl_compatibility`) et le MSAA ×4 de la sous-vue scindée, changé en cours de
## partie (sans effet non plus : le jeu le pose à la création, `Presentation3D.ANTICRENELAGE_3D`). Le jeu pose ×4 sur la
## fenêtre à l'allumage de la vue iso : la prise « x0 » le coupe le temps de la prise, puis le réglage est rendu.
func _corps_msaa(plans: Array[Dictionary]) -> void:
	var fenetre: Window = p.get_window()
	var origine := fenetre.msaa_3d
	var origine_ssaa := fenetre.screen_space_aa
	var niveaux := [[Viewport.MSAA_DISABLED, "x0"], [Viewport.MSAA_2X, "x2"], [Viewport.MSAA_4X, "x4"]]
	for n in niveaux:
		fenetre.msaa_3d = n[0]
		var suffixe: String = n[1]
		await _prise(plans, "loupe-corps-msaa", [
			["j1-" + suffixe, func(img: Image) -> Vector2: return _pixel(img, _j1, HAUTEUR_CORPS)],
			["j2-" + suffixe, func(img: Image) -> Vector2: return _pixel(img, _j2, HAUTEUR_CORPS)]], false, 0.8)
	fenetre.msaa_3d = Viewport.MSAA_DISABLED
	fenetre.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	await _prise(plans, "loupe-corps-msaa", [
		["j1-fxaa", func(img: Image) -> Vector2: return _pixel(img, _j1, HAUTEUR_CORPS)],
		["j2-fxaa", func(img: Image) -> Vector2: return _pixel(img, _j2, HAUTEUR_CORPS)]], false, 0.8)
	fenetre.screen_space_aa = origine_ssaa
	p._deux_vues()
	var pres := Presentation3D.instance()
	var vue: Viewport = pres.viewport_ecran(0) if pres != null else null
	if vue == null:
		printerr("  ✗ loupe-corps-msaa : sous-vue 3D de J1 introuvable en écran scindé")
	else:
		var origine_vue := vue.msaa_3d
		for n in [[Viewport.MSAA_DISABLED, "scinde-x0"], [Viewport.MSAA_4X, "scinde-x4"]]:
			vue.msaa_3d = n[0]
			var suffixe: String = n[1]
			await _prise(plans, "loupe-corps-msaa", [
				["j1-" + suffixe, func(img: Image) -> Vector2: return _pixel(img, _j1, HAUTEUR_CORPS)]], true, 1.0)
		vue.msaa_3d = origine_vue
	p._vue_unique()
	niveaux.append([Viewport.MSAA_DISABLED, "fxaa"])
	var sommes := [0.0, 0.0, 0.0, 0.0]
	var comptes := [0, 0, 0, 0]
	for bloc in 12:
		var i := bloc % 4
		fenetre.msaa_3d = niveaux[i][0]
		fenetre.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if i == 3 else origine_ssaa
		# Le premier bloc de chaque niveau paie l'allocation du tampon multi-échantillons : trente images de pose.
		for k in 30:
			_tenir_scene()
			await RenderingServer.frame_post_draw
		var avant := Time.get_ticks_usec()
		for k in 120:
			_tenir_scene()
			await RenderingServer.frame_post_draw
			var maintenant := Time.get_ticks_usec()
			sommes[i] += float(maintenant - avant) / 1000.0
			comptes[i] += 1
			avant = maintenant
	fenetre.msaa_3d = origine
	fenetre.screen_space_aa = origine_ssaa
	var moyennes: Array[float] = []
	for i in 4:
		moyennes.append(float(sommes[i]) / maxf(float(comptes[i]), 1.0))
	print("  MESURE loupe-corps-msaa image moyenne : sans %.3f ms, ×2 %.3f ms (+%.3f), ×4 %.3f ms (+%.3f), FXAA %.3f ms (+%.3f), %d images par niveau, fenêtre %s"
		% [moyennes[0], moyennes[1], moyennes[1] - moyennes[0], moyennes[2], moyennes[2] - moyennes[0], moyennes[3],
		moyennes[3] - moyennes[0], comptes[0], str(DisplayServer.window_get_size())])


func _cout_du_voile() -> void:
	var ui: Node = p._ui
	var rect: ColorRect = ui.get("p1_dazzle")
	var bb: Node = ui.get("_voile_bb")
	if rect == null or bb == null or not rect.has_meta("voile_plein"):
		printerr("  ✗ loupe-cout-voile : voile de J1 ou copie plein cadre introuvables")
		return
	var plein: ShaderMaterial = rect.get_meta("voile_plein")
	var sommes := {"A": 0.0, "B": 0.0}
	var comptes := {"A": 0, "B": 0}
	for n in 60:
		_tenir_scene()
		await p.get_tree().process_frame
	for bloc in 8:
		var force := bloc % 2 == 0
		var cle := "A" if force else "B"
		await RenderingServer.frame_post_draw
		var avant := Time.get_ticks_usec()
		for k in 120:
			_tenir_scene()
			if force:
				# Après le `_process` de l'UI de cette image : `process_frame` passe avant le rendu.
				rect.material = plein
				bb.visible = true
			await RenderingServer.frame_post_draw
			var maintenant := Time.get_ticks_usec()
			sommes[cle] += float(maintenant - avant) / 1000.0
			comptes[cle] += 1
			avant = maintenant
	var a: float = float(sommes["A"]) / maxf(float(comptes["A"]), 1.0)
	var b: float = float(sommes["B"]) / maxf(float(comptes["B"]), 1.0)
	print("  MESURE loupe-cout-voile image moyenne : copie et voile plein %.3f ms, voile calme %.3f ms, écart %.3f ms (%d + %d images, éblouissement J1 %.3f)"
		% [a, b, a - b, comptes["A"], comptes["B"], float(p._main.p1.dazzle_amount)])


# ---------------------------------------------------------------------------
# LA FLUIDITÉ
# ---------------------------------------------------------------------------

## Trente images : J1 avance vers le nord-ouest à sa vitesse de marche et balaie sa visée de 80°, la
## caméra glisse. D'abord les temps d'image, sans capture ; puis, sous `--fixed-fps` seulement, les images.
func _fluidite(plans: Array[Dictionary]) -> void:
	var plan: Dictionary = p._plan(plans, "loupe-fluidite")
	if plan.is_empty():
		return
	var m: Node = p._main
	var depart := _j1 + Vector2(0.0, 1.5 * MursBas.TUILE)
	var vitesse: float = float(m.p1.speed)
	for n in 40:
		_poser_fluidite(0, depart, vitesse)
		await p.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var temps: Array[float] = []
	# ⚠️ **`--fixed-fps` ne se lit pas dans `OS.get_cmdline_args()`** : le moteur consomme ce drapeau avant
	# le script (premier essai de la bande : séance lancée sous le drapeau, aucune image prise). Il se lit à son
	# EFFET : sous horloge fixe, chaque image avance le jeu d'exactement 1/60 s, quel que soit le temps réel.
	var fixe := true
	var avant := Time.get_ticks_usec()
	for k in IMAGES_FLUIDITE:
		_poser_fluidite(k, depart, vitesse)
		await RenderingServer.frame_post_draw
		var maintenant := Time.get_ticks_usec()
		temps.append(float(maintenant - avant) / 1000.0)
		avant = maintenant
		if absf(p.get_process_delta_time() - 1.0 / 60.0) > 0.0005:
			fixe = false
	var somme := 0.0
	for x in temps:
		somme += x
	var note := "temps d'image sur %d images : min %.2f ms, moyen %.2f ms, max %.2f ms (%s)" % [
		temps.size(), temps.min(), somme / float(temps.size()), temps.max(),
		"--fixed-fps" if fixe else "temps réel"]
	print("  MESURE loupe-fluidite %s" % note)
	if not fixe:
		printerr("  ! loupe-fluidite : sans --fixed-fps 60, les captures retarderaient l'horloge — images "
			+ "non prises. Relancer seul : godot --path . --fixed-fps 60 res://tools/photographe.tscn -- "
			+ "--plan=loupe-fluidite --taille=2560x1440")
		return
	for n in 40:
		_poser_fluidite(0, depart, vitesse)
		await p.get_tree().process_frame
	for k in IMAGES_FLUIDITE:
		_poser_fluidite(k, depart, vitesse)
		var img: Image = await _capturer(false)
		if img == null:
			p._perdues += 1
			continue
		p._ecrire(p._derive(plans, "loupe-fluidite", "%02d" % k, note if k == 0 else ""), img)


func _poser_fluidite(k: int, depart: Vector2, vitesse: float) -> void:
	var m: Node = p._main
	if not is_instance_valid(m.p1) or not is_instance_valid(m.p2):
		return
	m.p1.global_position = depart + Vector2(-0.35, -1.0).normalized() * vitesse * float(k) / 60.0
	p._viser(0, Vector2.UP.rotated(deg_to_rad(-40.0 + 80.0 * float(k) / float(IMAGES_FLUIDITE - 1))))
	m.p2.global_position = _j2
	p._viser(1, Vector2.RIGHT)
	if p._pantins.size() > 1:
		p._pantins[0].torche = true
		p._pantins[1].torche = false
	m.p2.flashlight_on = false
	p._vivants()
