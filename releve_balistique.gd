## Le relevé balistique de la killcam — DA4.6.
##
## **Ce que le relevé mesure a changé le 2026-08-27**, sur relecture d'Adrien à
## l'écran. Le premier jet cotait la distance entre le tireur et sa victime :
## exact, et **hors sujet**. Une killcam n'existe pas pour dire de combien de
## mètres on s'est fait tuer — elle existe pour montrer *pourquoi c'était
## imparable*.
##
## Le sujet est donc **l'écart au tir parfait**. La chute de dégâts de
## `bullet.gd` est gouvernée par une seule grandeur : la distance
## perpendiculaire entre l'axe de la balle et le centre de la victime. Il existe
## donc, pour chaque tir, **une trajectoire idéale** — celle qui passe pile par
## ce centre — et le tir réel s'en écarte d'un angle. C'est ce couple que le
## relevé dessine : l'idéal, le réel, et ce qui les sépare.
##
## ⚠️ **La différence n'est pas cosmétique, elle décide de tout le dessin.** Coter
## une distance de tir demande une ligne de cote ; coter un ÉCART demande deux
## axes, un arc, et une lecture qui dit « il s'en est fallu de tant ». Le premier
## se lit en un chiffre, le second se comprend en une image.
##
## ## Le registre : dessin d'exécution, pas infographie
##
## Les traits sont **très déportés** — une cote collée à son objet se lit comme
## une étiquette, une cote déportée se lit comme une mesure. S'y ajoutent
## l'appareillage qui fait qu'un plan *ressemble* à un plan : axes en trait
## mixte, lignes d'attache qui débordent, obliques ISO, mire de calage sur la
## cible, et un cartouche d'informations dont **aucune n'est nécessaire**.
##
## ⚠️ **« Inutile » ne veut pas dire « faux ».** Chaque ligne du cartouche est une
## valeur réellement calculée — arme, portée, écart angulaire, écart
## perpendiculaire, part des dégâts maximaux atteinte. Un relevé qui afficherait
## des nombres décoratifs serait un faux document, et le jour où quelqu'un s'y
## fierait il aurait raison de le faire.
##
## ## Ce qui est à la balle, et ce qui est au relevé
##
## La balle garde **ses pointillés derrière elle** — c'est V6.2, le trajet
## effectivement parcouru, qui se dessine au fil du vol. Le relevé, lui, ne
## dessine **aucun pointillé** : ses axes sont en trait mixte, précisément pour
## qu'on ne confonde jamais l'annonce avec le trajet.

class_name ReleveBalistique
extends Node2D

const Charte := preload("res://charte.gd")
const Echelle := preload("res://echelle.gd")

## L'axe idéal : ce que le relevé affirme.
const IDEAL_COULEUR := Color(Charte.HALOGENE, 0.62)
## L'axe réellement suivi : plus discret, la balle le dit déjà.
const REEL_COULEUR := Color(Charte.HALOGENE, 0.34)
## L'appareillage — attaches, obliques, mire, cartouche.
const APPAREIL_COULEUR := Color(Charte.HALOGENE, 0.44)
## L'écart, seule valeur qui porte un jugement : ambre s'il est coûteux.
const ECART_COULEUR := Color(Charte.AMBRE, 0.70)

## Le rayon au-delà duquel une balle ne fait plus que des dégâts de bord.
## Repris de `bullet.gd::_hit_player`, où il vaut 15 px.
const RAYON_LETAL := 15.0

# --- Dimensions d'annotation, en pixels ÉCRAN (multipliées par 1/zoom) -------
#
# ⚠️ **Beaucoup plus déportées que le premier jet** (26 px), relevé par Adrien :
# « il faut que les traits de cote soient beaucoup moins ramassés ». Une cote
# collée à son objet se lit comme une étiquette ; c'est le déport qui la fait
# lire comme une mesure.
const COTE_ECART := 78.0
const COTE_DEBORD := 14.0
const COTE_PATTE := 7.0
const COTE_TEXTE_AIR := 7.0
const AXE_DEBORD := 34.0
const ARC_RAYON := 62.0
const MIRE_COTE := 26.0
const MIRE_AIR := 9.0
const CARTOUCHE_ECART := 46.0
const CARTOUCHE_LIGNE := 15.0

## Écart entre deux chevrons, en pixels **monde**.
##
## ⚠️ **Monde, et pas écran, contrairement à tout le reste de l'annotation.** Leur
## densité à l'écran devient alors proportionnelle à la distance réellement
## parcourue : c'est ce qu'un relevé doit dire.
const CHEVRON_PAS := 46.0
const CHEVRON_MAX := 48
const CHEVRON_L := 8.0
const CHEVRON_H := 5.5

## En deçà, une cote est du bruit : le trait ne tient pas ses propres obliques.
const COTE_MINIMUM := 64.0

## Ce qu'il reste de vivacité une fois l'action reprise. Le relevé ne disparaît
## pas — le joueur doit pouvoir comparer la balle à l'axe — mais il cesse d'être
## le sujet.
const ATTENUATION := 0.55

var origine: Vector2 = Vector2.ZERO
var cible: Vector2 = Vector2.ZERO
var angle_reel: float = 0.0
var nom_arme: String = ""
var part_bord: float = 0.5

## 0 pendant que le relevé se dessine, 1 quand il est entier.
var progression: float = 0.0
## Vrai une fois l'action reprise : le relevé s'atténue et cesse de grandir.
var en_arriere_plan: bool = false


func _ready() -> void:
	# Additif non éclairé, comme la traînée de `bullet.gd` : sans quoi le
	# `CanvasModulate` noir de l'arène avale le trait.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 9
	top_level = true


## Arme le relevé. Rend `false` s'il n'y a rien à relever.
##
## `angle_tir` est la direction RÉELLE du tir, telle qu'enregistrée ; l'idéal se
## déduit de la position de la cible et n'est jamais fourni de l'extérieur.
func poser(depart: Vector2, centre_cible: Vector2, angle_tir: float,
		arme: String = "", degats_bord: float = 0.5) -> bool:
	if depart.distance_to(centre_cible) < 1.0:
		return false
	origine = depart
	cible = centre_cible
	angle_reel = angle_tir
	nom_arme = arme
	part_bord = clampf(degats_bord, 0.0, 1.0)
	progression = 0.0
	en_arriere_plan = false
	global_position = depart
	rotation = (centre_cible - depart).angle()
	queue_redraw()
	return true


func avancer(t: float) -> void:
	var neuf := clampf(t, 0.0, 1.0)
	if is_equal_approx(neuf, progression):
		return
	progression = neuf
	queue_redraw()


func passer_derriere() -> void:
	if en_arriere_plan:
		return
	en_arriere_plan = true
	progression = 1.0
	queue_redraw()


## Le zoom de la caméra qui regarde ce relevé, ou 1,0 si personne ne regarde.
##
## ⚠️ **Lu sur le viewport, jamais demandé à `GameState`.** En écran scindé chaque
## vue a sa propre caméra : demander « le » zoom n'aurait même pas de sens.
func _zoom_de_la_vue() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var cam := vp.get_camera_2d()
	if cam == null:
		return 1.0
	return maxf(0.05, minf(cam.zoom.x, cam.zoom.y))


## Ce que le tir a fait, comparé à ce qu'il pouvait faire.
##
## ⚠️ **La chute de dégâts n'est pas paraphrasée, elle est reprise.**
## `bullet.gd::_hit_player` interpole entre `damage_center` et `damage_edge` sur
## la distance perpendiculaire normalisée par 15 px. Écrire ici une seconde
## formule « équivalente » ferait afficher au relevé une part de dégâts que le
## jeu n'applique pas — un document faux, et personne ne le saurait.
##
## `part_bord` est `damage_edge / damage_center`, calculé par l'appelant qui
## tient l'arme : ce fichier n'a aucune raison de connaître `WeaponData`.
static func analyse(depart: Vector2, centre_cible: Vector2, angle_tir: float,
		part_bord_arme: float) -> Dictionary:
	var vers := centre_cible - depart
	var portee := vers.length()
	var ideal := vers.angle()
	var reel := Vector2.RIGHT.rotated(angle_tir)
	# L'écart SIGNÉ : le sens compte, l'arc se dessine d'un côté ou de l'autre.
	var ecart_angle := angle_difference(angle_tir, ideal)
	# Distance perpendiculaire du centre à l'axe réel — la seule grandeur dont
	# dépendent les dégâts.
	var ecart_perp := absf(vers.cross(reel))
	var t := clampf(ecart_perp / RAYON_LETAL, 0.0, 1.0)
	return {
		"portee": portee,
		"angle_ideal": ideal,
		"ecart_angle": ecart_angle,
		"ecart_perp": ecart_perp,
		"part_degats": lerpf(1.0, clampf(part_bord_arme, 0.0, 1.0), t),
		# Le point de l'axe réel le plus proche du centre : c'est là que la
		# balle est passée, et donc là que l'écart se cote.
		"passage": depart + reel * vers.dot(reel),
	}


## La géométrie du relevé, en espace local — l'origine en zéro, la cible en
## `(portee, 0)`, l'axe idéal confondu avec +X.
##
## ⚠️ **Ce calcul a un nom parce qu'un `_draw()` n'en a pas.** Rien ne peut
## mesurer une cote dessinée : il faudrait tuer un joueur, lancer une killcam et
## lire des pixels au bon instant. `tools/test_releve_balistique.gd` s'y branche.
##
## ⚠️ **Tout ce qui est ANNOTATION se compense du zoom ; ce qui est GÉOMÉTRIE suit
## le monde.** La caméra de killcam va de 0,7× à 2,8× — un facteur quatre. Une
## cote posée en pixels locaux serait illisible à 8 px au dézoom et grosse comme
## un titre au zoom serré, sur le même tir. Sixième occurrence du motif du
## 2026-08-19 : *une valeur absolue là où il fallait un rapport*.
static func geometrie_du_releve(portee: float, zoom: float,
		angle: float, ecart_angle: float = 0.0) -> Dictionary:
	var k := 1.0 / maxf(zoom, 0.05)
	var fin := Vector2(portee, 0.0)

	var chevrons: Array[Vector2] = []
	var n := int(portee / CHEVRON_PAS)
	for i in range(1, mini(n, CHEVRON_MAX) + 1):
		chevrons.append(Vector2(float(i) * CHEVRON_PAS, 0.0))

	# ⚠️ **De quel côté poser la cote ?** Toujours du côté qui est EN HAUT à
	# l'écran, quel que soit le sens du tir — sinon la cote passe sous le trait
	# dès qu'on tire vers la gauche, et le relevé se retourne en cours de
	# killcam. On demande donc au monde, pas au repère local.
	var s := 1.0 if Vector2(0.0, -1.0).rotated(angle).y > 0.0 else -1.0
	var ecart := s * COTE_ECART * k
	var cote_a := Vector2(0.0, ecart)
	var cote_b := fin + Vector2(0.0, ecart)
	var debord := Vector2(0.0, s * COTE_DEBORD * k)
	var oblique := (Vector2.RIGHT + Vector2(0.0, s)).normalized() * (COTE_PATTE * k)

	# L'axe idéal déborde de part et d'autre : c'est ce qui en fait un AXE de
	# construction et non un segment mesuré.
	var db := AXE_DEBORD * k

	return {
		"cible": fin,
		"axe_ideal": [Vector2(-db, 0.0), fin + Vector2(db, 0.0)],
		"axe_reel": [Vector2.ZERO,
			Vector2.RIGHT.rotated(ecart_angle) * (portee + db)],
		"chevrons": chevrons,
		"chevron_l": CHEVRON_L * k,
		"chevron_h": CHEVRON_H * k,
		"cote": [cote_a, cote_b],
		"attaches": [
			[Vector2.ZERO, cote_a + debord],
			[fin, cote_b + debord],
		],
		"obliques": [
			[cote_a - oblique, cote_a + oblique],
			[cote_b - oblique, cote_b + oblique],
		],
		"ancre_texte": (cote_a + cote_b) * 0.5
			+ Vector2(0.0, s * COTE_TEXTE_AIR * k),
		"arc_rayon": ARC_RAYON * k,
		"mire": MIRE_COTE * k,
		"mire_air": MIRE_AIR * k,
		"cartouche": fin + Vector2(0.0, -s * CARTOUCHE_ECART * k),
		"ligne": CARTOUCHE_LIGNE * k,
		"cote_cote": s,
		"epaisseur": maxf(1.0, 1.4 * k),
		"cote_visible": portee >= COTE_MINIMUM,
		"echelle_texte": k,
	}


## La part d'une phase déjà jouée, dans une progression globale de 0 à 1.
##
## Le relevé ne pousse pas d'un bloc : les axes d'abord, l'angle ensuite, la cote
## puis le cartouche. **Un plan se lit dans l'ordre où il se construit** — tout
## faire apparaître ensemble donnerait une image, pas un tracé.
static func phase(p: float, debut: float, fin: float) -> float:
	if fin <= debut:
		return 1.0 if p >= fin else 0.0
	return clampf((p - debut) / (fin - debut), 0.0, 1.0)


func _draw() -> void:
	var a := analyse(origine, cible, angle_reel, part_bord)
	var portee: float = a["portee"]
	if portee < 4.0:
		return
	var p := progression
	var g := geometrie_du_releve(portee, _zoom_de_la_vue(), rotation,
		a["ecart_angle"])
	var att := ATTENUATION if en_arriere_plan else 1.0
	var e: float = g["epaisseur"]

	_tracer_axes(g, p, att, e)
	_tracer_angle(g, a, p, att, e)
	if g["cote_visible"]:
		_tracer_cote(g, a, p, att, e)
	_tracer_mire(g, p, att, e)
	_tracer_cartouche(g, a, p, att)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Phase 1 — les deux axes poussent depuis le tireur.
func _tracer_axes(g: Dictionary, p: float, att: float, e: float) -> void:
	var t := phase(p, 0.0, 0.40)
	if t <= 0.0:
		return
	var ideal: Array = g["axe_ideal"]
	var reel: Array = g["axe_reel"]

	# ⚠️ **Trait mixte, jamais pointillé.** Le pointillé appartient à la balle —
	# c'est le trajet PARCOURU. Un axe de construction se dessine en trait
	# d'axe : c'est la convention du dessin technique, et ici elle empêche
	# surtout de confondre ce qu'on annonce avec ce qui a eu lieu.
	_trait_d_axe(ideal[0], (ideal[0] as Vector2).lerp(ideal[1], t),
		Color(IDEAL_COULEUR, IDEAL_COULEUR.a * att), e)
	_trait_d_axe(reel[0], (reel[0] as Vector2).lerp(reel[1], t),
		Color(REEL_COULEUR, REEL_COULEUR.a * att), e * 0.8)

	var cl: float = g["chevron_l"]
	var ch: float = g["chevron_h"]
	var limite: float = (ideal[0] as Vector2).lerp(ideal[1], t).x
	var c := Color(APPAREIL_COULEUR, APPAREIL_COULEUR.a * att)
	for pt: Vector2 in g["chevrons"]:
		if pt.x > limite:
			continue
		draw_polyline(PackedVector2Array([
			pt + Vector2(-cl, -ch), pt, pt + Vector2(-cl, ch),
		]), c, e)


## Un trait d'axe : long tiret, point, long tiret. Godot n'en a pas, on le pose.
func _trait_d_axe(a: Vector2, b: Vector2, couleur: Color, e: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 1.0:
		return
	var u := d / l
	const LONG := 22.0
	const COURT := 3.0
	const AIR := 5.0
	var motif := LONG + AIR + COURT + AIR
	var x := 0.0
	while x < l:
		draw_line(a + u * x, a + u * minf(x + LONG, l), couleur, e)
		var q := x + LONG + AIR
		if q < l:
			draw_line(a + u * q, a + u * minf(q + COURT, l), couleur, e)
		x += motif


## Phase 2 — l'arc d'écart au tir parfait, près du tireur.
func _tracer_angle(g: Dictionary, a: Dictionary, p: float, att: float,
		e: float) -> void:
	var t := phase(p, 0.32, 0.62)
	if t <= 0.0:
		return
	var r: float = g["arc_rayon"]
	var ecart: float = a["ecart_angle"]
	var c := Color(ECART_COULEUR, ECART_COULEUR.a * att)

	# L'arc balaie de l'axe idéal (0) vers l'axe réel, dans le sens de l'écart.
	var fin_arc := ecart * t
	var pts := PackedVector2Array()
	var pas := maxi(3, int(absf(fin_arc) / 0.06) + 2)
	for i in pas + 1:
		pts.append(Vector2.RIGHT.rotated(fin_arc * float(i) / float(pas)) * r)
	if pts.size() >= 2:
		draw_polyline(pts, c, e)

	if t < 0.9:
		return
	var f := Charte.police_ui(Charte.POIDS_APPUI)
	if f == null:
		return
	# Le signe est retiré : « 0,4° » se lit, « -0,4° » demande de savoir de quel
	# côté compte le positif. L'arc, lui, montre déjà le côté.
	var texte := ("%.1f°" % absf(rad_to_deg(ecart))).replace(".", ",")
	_ecrire(g, Vector2.RIGHT.rotated(ecart * 0.5) * (r * 1.22), texte, c)


## Phase 3 — la cote de portée, très déportée.
func _tracer_cote(g: Dictionary, a: Dictionary, p: float, att: float,
		e: float) -> void:
	var t := phase(p, 0.50, 0.82)
	if t <= 0.0:
		return
	var c := Color(APPAREIL_COULEUR, APPAREIL_COULEUR.a * att)
	var cote: Array = g["cote"]
	for paire: Array in g["attaches"]:
		draw_line(paire[0], (paire[0] as Vector2).lerp(paire[1], t), c, e * 0.7)
	draw_line(cote[0], (cote[0] as Vector2).lerp(cote[1], t), c, e)
	if t < 0.85:
		return
	for paire: Array in g["obliques"]:
		draw_line(paire[0], paire[1], c, e)
	var f := Charte.police_ui(Charte.POIDS_APPUI)
	if f != null:
		_ecrire(g, g["ancre_texte"], Echelle.ecrire(a["portee"]), c)


## Phase 4 — la mire de calage sur la cible : quatre équerres de cadrage.
func _tracer_mire(g: Dictionary, p: float, att: float, e: float) -> void:
	var t := phase(p, 0.62, 0.86)
	if t <= 0.0:
		return
	var c := Color(APPAREIL_COULEUR, APPAREIL_COULEUR.a * att)
	var m: float = g["mire"] * t
	var air: float = g["mire_air"]
	var centre: Vector2 = g["cible"]
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var coin := centre + Vector2(sx * (air + m), sy * (air + m))
			draw_line(coin, coin - Vector2(sx * m * 0.55, 0.0), c, e)
			draw_line(coin, coin - Vector2(0.0, sy * m * 0.55), c, e)


## Phase 5 — le cartouche. Aucune de ses lignes n'est nécessaire ; toutes sont
## vraies.
func _tracer_cartouche(g: Dictionary, a: Dictionary, p: float,
		att: float) -> void:
	var t := phase(p, 0.72, 1.0)
	if t <= 0.0:
		return
	var f := Charte.police_ui(Charte.POIDS_APPUI)
	if f == null:
		return
	var c := Color(APPAREIL_COULEUR, APPAREIL_COULEUR.a * att)
	var vif := Color(ECART_COULEUR, ECART_COULEUR.a * att)

	var lignes: Array = [
		["TIR FATAL", nom_arme.to_upper(), c],
		["PORTÉE", Echelle.ecrire(a["portee"]), c],
		["ÉCART", Echelle.ecrire(a["ecart_perp"]), vif],
		["DÉGÂTS", "%d %%" % int(roundf(float(a["part_degats"]) * 100.0)), vif],
	]
	# Le cartouche se remplit ligne à ligne, comme on écrit.
	var visibles := int(ceilf(float(lignes.size()) * t))
	var h: float = g["ligne"]
	var ancre: Vector2 = g["cartouche"]
	for i in mini(visibles, lignes.size()):
		var l: Array = lignes[i]
		_ecrire_a_gauche(g, ancre + Vector2(0.0, float(i) * h),
			"%s  %s" % [l[0], l[1]], l[2])


## Un texte à l'horizontale et à taille d'écran constante, centré sur `ancre`.
##
## ⚠️ **La contre-rotation ET la contre-échelle passent par `draw_set_transform`,
## et pas par une taille de fonte calculée.** Godot rastérise un glyphe à la
## taille entière qu'on demande : passer `T_MENTION / zoom` donnerait 4 px à
## 2,8×, agrandis ensuite par la caméra — un texte en escalier. Ici le glyphe est
## gravé à sa taille finale d'écran, puis la transformation l'y ramène.
func _ecrire(g: Dictionary, ancre: Vector2, texte: String,
		couleur: Color) -> void:
	var f := Charte.police_ui(Charte.POIDS_APPUI)
	if f == null:
		return
	var l := f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Charte.T_MENTION).x
	var k: float = g["echelle_texte"]
	draw_set_transform(ancre, -rotation, Vector2(k, k))
	draw_string(f, Vector2(-l * 0.5, 0.0), texte, HORIZONTAL_ALIGNMENT_LEFT,
		-1, Charte.T_MENTION, couleur)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Idem, mais aligné à gauche : un cartouche s'aligne, il ne se centre pas.
func _ecrire_a_gauche(g: Dictionary, ancre: Vector2, texte: String,
		couleur: Color) -> void:
	var f := Charte.police_ui(Charte.POIDS_APPUI)
	if f == null:
		return
	var k: float = g["echelle_texte"]
	draw_set_transform(ancre, -rotation, Vector2(k, k))
	draw_string(f, Vector2.ZERO, texte, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Charte.T_MENTION, couleur)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
