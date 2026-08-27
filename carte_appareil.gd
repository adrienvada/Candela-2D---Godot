## L'appareil d'un joueur, dessiné — DA4.11.
##
## **Une liste de noms de touches demande une traduction que personne ne fait.**
## Lire « O » et retrouver l'endroit où poser le doigt est un travail ; le voir
## allumé sur un clavier n'en est pas un. Et surtout, la question que se posent
## deux joueurs devant un seul clavier n'est pas « quelle touche tire ? » mais
## **« nos mains vont-elles se rentrer dedans ? »** — à laquelle une liste ne
## peut pas répondre.
##
## ## Le dessin est POSITIONNEL, les libellés sont LOCALISÉS
##
## ⚠️ **C'est la propriété centrale de ce fichier, et elle vient du jeu.**
## `project.godot` lie ses touches par `physical_keycode` : la touche « haut » de
## J1 est le `W` d'un QWERTY, qui est **physiquement le Z** d'un AZERTY. Le
## clavier est donc dessiné aux positions physiques — invariantes — et chaque
## capuchon demande son libellé à
## `DisplayServer.keyboard_get_keycode_from_physical()`.
##
## Le même dessin montre donc `ZQSD` à Adrien et `WASD` à un joueur américain,
## **sans qu'une ligne ne change**, et les deux voient la vérité de leurs propres
## doigts. Une planche générée n'aurait pu montrer qu'une disposition.
##
## ## Dessiné par le code, jamais généré
##
## Décidé avec Adrien le 2026-08-27. Une touche assignée doit s'allumer dans le
## bleu de J1 ou le rouge de J2, et **une image ne s'allume pas**. C'est la
## discipline DA1.5 poussée à son terme : l'image fournit la matière, le code
## garde la couleur — ici il n'y a même pas de matière à fournir, seulement des
## capuchons et des libellés.
##
## ## Ce qui est lu, jamais recopié
##
## ⚠️ **Les touches allumées viennent de l'`InputMap`**, pas d'une table écrite
## dans ce fichier. Une table recopiée serait juste le jour de son écriture et
## mentirait à la première réassignation — sans erreur, et sur l'écran même qui
## sert à réassigner.

class_name CarteAppareil
extends Control

const Charte := preload("res://charte.gd")

## Les trois rangées de lettres, en **codes physiques** : ce sont les valeurs
## `KEY_*` de Godot, qui décrivent la position et non la lettre imprimée.
##
## Le pavé numérique et la rangée des chiffres sont absents : le jeu n'en emploie
## aucun, et un clavier dessiné en entier ne tiendrait pas dans la rubrique.
const RANGEES := [
	{"decal": 0.0, "codes": [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T,
		KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]},
	{"decal": 0.28, "codes": [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G,
		KEY_H, KEY_J, KEY_K, KEY_L, KEY_M]},
	{"decal": 0.72, "codes": [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N]},
]

## Le bloc directionnel, posé à droite du bloc de lettres.
const FLECHES := [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]

## Écart entre le bloc de lettres et le bloc de flèches, en unités de touche.
const ECART_BLOCS := 0.65

enum Appareil { CLAVIER, MANETTE }

## Les couleurs de rôle, dans l'ordre des joueurs.
const TEINTES := [Charte.BLEU, Charte.ROUGE]

@export var appareil: Appareil = Appareil.CLAVIER
## Le joueur dont on montre l'appareil — décide de la teinte principale.
var joueur: int = 0
## Les actions à éclairer, par joueur : `{0: PackedStringArray, 1: ...}`.
##
## ⚠️ **Seules celles du joueur de la colonne sont DESSINÉES.** Le premier jet
## montrait le clavier entier avec les deux jeux de touches allumés dessus —
## l'idée de la proposition A gardée dans la B. Vu à l'écran par Adrien le
## 2026-08-27 : *« c'est beaucoup trop le bordel »*. Il a raison, et la raison
## est instructive : **vingt-six capuchons dont quatre comptent, ce n'est pas
## montrer un contexte, c'est enfouir l'information dans du décor.** Le
## chevauchement gagné ne payait pas la lisibilité perdue.
##
## Les deux joueurs restent transmis — `collisions()` en a besoin, et une touche
## partagée se signale toujours en ambre. Mais on ne dessine que la sienne.
var actions: Dictionary = {}
## Les actions réassignables, marquées d'un point ambre.
var reassignables: PackedStringArray = []
## L'action en cours de réassignation, ou "" — son capuchon bat.
var en_attente: String = ""

var _u: float = 30.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pose ce que la carte doit montrer, puis la redessine.
func poser(quel_joueur: int, quel_appareil: Appareil, par_joueur: Dictionary,
		a_reassigner: PackedStringArray) -> void:
	joueur = clampi(quel_joueur, 0, 1)
	appareil = quel_appareil
	actions = par_joueur
	reassignables = a_reassigner
	queue_redraw()


# ---------------------------------------------------------------------------
# CE QUE L'INPUT MAP DIT — jamais une table recopiée
# ---------------------------------------------------------------------------

## Le code physique lié à une action, ou `0` si elle n'est pas au clavier.
##
## ⚠️ **`physical_keycode` d'abord.** Une liaison posée par le joueur au
## réassignement peut n'avoir qu'un `keycode` ; on retombe dessus, mais l'ordre
## compte : lire `keycode` en premier ferait dessiner la lettre plutôt que la
## position, et le clavier mentirait sur un AZERTY.
static func code_physique_de(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var t: InputEventKey = ev
			return t.physical_keycode if t.physical_keycode != 0 else t.keycode
	return 0


## Quel joueur occupe quelle touche : `{code_physique: index_joueur}`.
##
## ⚠️ **Rend aussi les COLLISIONS.** Si deux joueurs se retrouvent sur la même
## touche, la seconde écrase la première dans le dictionnaire — et
## `collisions()` la nomme séparément, parce qu'une touche partagée n'est pas un
## détail d'affichage : c'est deux joueurs qui ne peuvent pas jouer ensemble.
static func occupation(par_joueur: Dictionary) -> Dictionary:
	var out := {}
	for j: int in par_joueur.keys():
		for action: String in par_joueur[j]:
			var code := code_physique_de(action)
			if code != 0:
				out[code] = j
	return out


## Les touches revendiquées par les DEUX joueurs. Vide = personne ne se gêne.
static func collisions(par_joueur: Dictionary) -> Array[int]:
	var vu := {}
	var fautives: Array[int] = []
	for j: int in par_joueur.keys():
		for action: String in par_joueur[j]:
			var code := code_physique_de(action)
			if code == 0:
				continue
			if vu.has(code) and vu[code] != j and not fautives.has(code):
				fautives.append(code)
			vu[code] = j
	return fautives


## Le libellé d'un capuchon, dans la disposition du joueur.
##
## ⚠️ **Traduit, jamais supposé.** `KEY_W` est une POSITION ; sur le clavier
## d'Adrien cette position porte un **Z**. Afficher « W » serait exact du point
## de vue du code et faux du point de vue de sa main.
static func libelle_de(code_physique: int) -> String:
	match code_physique:
		KEY_UP: return "▲"
		KEY_DOWN: return "▼"
		KEY_LEFT: return "◀"
		KEY_RIGHT: return "▶"
		KEY_SPACE: return "ESPACE"
	return OS.get_keycode_string(dans_la_disposition(code_physique))


## Le code tel que la disposition du joueur l'imprime sur son capuchon.
##
## ⚠️ **Sans serveur d'affichage, il n'y a pas de disposition à traduire.**
## `keyboard_get_keycode_from_physical()` n'existe pas en headless : appelée
## quand même, elle rend zéro **et journalise une erreur à chaque touche**. Six
## lignes rouges par lancement de banc pour une situation parfaitement normale —
## et un banc qui imprime des erreurs apprend à les ignorer, ce qui coûte le
## jour où l'une d'elles compte. On demande donc d'abord s'il y a un clavier à
## interroger.
static func dans_la_disposition(code_physique: int) -> int:
	if DisplayServer.get_name() == "headless":
		return code_physique
	var local := DisplayServer.keyboard_get_keycode_from_physical(code_physique)
	return local if local != 0 else code_physique


# ---------------------------------------------------------------------------
# LA GÉOMÉTRIE — nommée, donc mesurable
# ---------------------------------------------------------------------------

## La disposition du clavier en **unités de touche**, indépendante de l'écran.
##
## ⚠️ **Ce calcul a un nom parce qu'un `_draw()` n'en a pas.** Rien ne peut
## mesurer un capuchon dessiné : il faudrait ouvrir la rubrique et lire des
## pixels. Cinquième occurrence du motif du 2026-08-19 — *ce qu'on voit n'a pas
## de nom, donc rien ne le tient*. `tools/test_carte_appareil.gd` s'y branche.
##
## Rend `{"touches": [{code, r}], "largeur": u, "hauteur": u}`.
static func disposition_clavier() -> Dictionary:
	var touches: Array[Dictionary] = []
	var largeur := 0.0
	for r in RANGEES.size():
		var rangee: Dictionary = RANGEES[r]
		var decal: float = rangee["decal"]
		var codes: Array = rangee["codes"]
		for i in codes.size():
			touches.append({
				"code": codes[i],
				"r": Rect2(decal + float(i), float(r), 0.92, 0.92),
			})
		largeur = maxf(largeur, decal + float(codes.size()))

	# Le bloc directionnel, en croix, à droite du bloc de lettres.
	var fx := largeur + ECART_BLOCS
	touches.append({"code": KEY_UP, "r": Rect2(fx + 1.0, 1.0, 0.92, 0.92)})
	touches.append({"code": KEY_LEFT, "r": Rect2(fx, 2.0, 0.92, 0.92)})
	touches.append({"code": KEY_DOWN, "r": Rect2(fx + 1.0, 2.0, 0.92, 0.92)})
	touches.append({"code": KEY_RIGHT, "r": Rect2(fx + 2.0, 2.0, 0.92, 0.92)})

	return {
		"touches": touches,
		"largeur": fx + 3.0,
		"hauteur": float(RANGEES.size()),
	}


## Écart entre deux groupes de touches, une fois le clavier recadré.
const ECART_GROUPES := 0.6
## Au-delà de cet écart, deux touches appartiennent à deux groupes distincts.
const SEUIL_GROUPE := 1.6


## Les seules touches d'un joueur, recadrées et regroupées.
##
## ⚠️ **Recadré, pas filtré.** Garder les positions absolues laisserait un grand
## vide là où l'adversaire jouait ; les écraser toutes à gauche détruirait la
## forme de la main, qui est justement ce qu'on vient montrer. On conserve donc
## la forme INTERNE de chaque groupe — `ZQSD` garde son T renversé, les flèches
## leur croix — et on rapproche les groupes entre eux.
##
## Les groupes se détectent par les trous : au-delà de `SEUIL_GROUPE` unités sans
## rien, c'est un autre endroit du clavier et donc une autre main.
static func disposition_du_joueur(codes: Array) -> Dictionary:
	var pleines := disposition_clavier()["touches"] as Array
	var siennes: Array[Dictionary] = []
	for t: Dictionary in pleines:
		if codes.has(t["code"]):
			siennes.append(t)
	if siennes.is_empty():
		return {"touches": [], "largeur": 0.0, "hauteur": 0.0}

	siennes.sort_custom(func(a, b):
		return (a["r"] as Rect2).position.x < (b["r"] as Rect2).position.x)

	# Découpe en groupes sur les trous horizontaux.
	var groupes: Array = []
	var courant: Array[Dictionary] = [siennes[0]]
	var bord: float = (siennes[0]["r"] as Rect2).end.x
	for i in range(1, siennes.size()):
		var r: Rect2 = siennes[i]["r"]
		if r.position.x - bord > SEUIL_GROUPE:
			groupes.append(courant)
			courant = []
		courant.append(siennes[i])
		bord = maxf(bord, r.end.x)
	groupes.append(courant)

	# Chaque groupe est ramené à son propre bord gauche, puis posé à la suite.
	var out: Array[Dictionary] = []
	var x := 0.0
	var haut := INF
	var bas := -INF
	for g: Array in groupes:
		var mini := INF
		for t: Dictionary in g:
			mini = minf(mini, (t["r"] as Rect2).position.x)
		var maxi := -INF
		for t: Dictionary in g:
			var r: Rect2 = t["r"]
			out.append({"code": t["code"],
				"r": Rect2(r.position.x - mini + x, r.position.y, r.size.x, r.size.y)})
			maxi = maxf(maxi, r.end.x - mini + x)
			haut = minf(haut, r.position.y)
			bas = maxf(bas, r.end.y)
		x = maxi + ECART_GROUPES

	# Remonté au ras du haut : une rangée vide en tête serait du vide dessiné.
	for t: Dictionary in out:
		var r: Rect2 = t["r"]
		t["r"] = Rect2(r.position.x, r.position.y - haut, r.size.x, r.size.y)

	return {
		"touches": out,
		"largeur": maxf(x - ECART_GROUPES, 0.0),
		"hauteur": bas - haut,
	}


# ---------------------------------------------------------------------------
# LE DESSIN
# ---------------------------------------------------------------------------


## Un polygone au coin arrondi. Godot n'en a pas : `draw_rect` fait des angles
## droits, et un angle droit ne ressemble à aucun appareil réel.
##
## ⚠️ **C'est ce qui manquait au premier jet, et ça se voyait.** La souris et la
## manette y étaient des rectangles à barres — relevé par Adrien : *« assez
## laid »*. Une silhouette se reconnaît à son contour avant tout le reste ; un
## rectangle ne dit ni souris ni manette, il dit rectangle.
static func _arrondi(r: Rect2, rayon: float, pas: int = 5) -> PackedVector2Array:
	var q := minf(rayon, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var coins := [
		[Vector2(r.end.x - q, r.position.y + q), -PI * 0.5, 0.0],
		[Vector2(r.end.x - q, r.end.y - q), 0.0, PI * 0.5],
		[Vector2(r.position.x + q, r.end.y - q), PI * 0.5, PI],
		[Vector2(r.position.x + q, r.position.y + q), PI, PI * 1.5],
	]
	for c: Array in coins:
		for i in pas + 1:
			var a: float = lerpf(c[1], c[2], float(i) / float(pas))
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * q)
	return pts


static func _forme(cv: CanvasItem, pts: PackedVector2Array, fond: Color,
		contour: Color, e: float) -> void:
	if pts.size() < 3:
		return
	cv.draw_colored_polygon(pts, fond)
	var ferme := pts.duplicate()
	ferme.append(pts[0])
	cv.draw_polyline(ferme, contour, e, true)


func _draw() -> void:
	if appareil == Appareil.MANETTE:
		_dessiner_manette()
	else:
		_dessiner_clavier()


func _dessiner_clavier() -> void:
	# ⚠️ **Seules les touches de CE joueur.** Voir la note de `actions` : le
	# clavier entier avec les deux jeux allumés dessus enfouissait les quatre
	# touches qui comptent sous vingt-deux qui ne comptent pas.
	var miennes: Array = actions.get(joueur, [])
	var codes: Array[int] = []
	for a: String in miennes:
		var c := code_physique_de(a)
		if c != 0 and not codes.has(c):
			codes.append(c)

	var d := disposition_du_joueur(codes)
	var touches: Array = d["touches"]
	if touches.is_empty():
		return
	var lu: float = maxf(float(d["largeur"]), 1.0)
	var hu: float = maxf(float(d["hauteur"]), 1.0)
	# La souris tient à droite : sa part est réservée avant de choisir l'unité.
	var avec_souris := joueur == 0
	var reserve := 2.4 if avec_souris else 0.0
	_u = minf(size.x / (lu + reserve), size.y / (hu + 0.4))
	_u = minf(_u, 46.0)
	var largeur := (lu + reserve) * _u
	var ox := (size.x - largeur) * 0.5
	var oy := (size.y - hu * _u) * 0.5

	var heurts := collisions(actions)
	var marques := {}
	for a: String in reassignables:
		var c := code_physique_de(a)
		if c != 0:
			marques[c] = true
	var bat := code_physique_de(en_attente) if en_attente != "" else 0

	for t: Dictionary in touches:
		var r: Rect2 = t["r"]
		var code: int = t["code"]
		_capuchon(Rect2(Vector2(ox, oy) + r.position * _u, r.size * _u),
			code, heurts.has(code), marques.has(code), code == bat)

	if avec_souris:
		_souris(Vector2(ox + (lu + 0.5) * _u, oy), hu * _u)


## Un capuchon de touche. Il appartient toujours au joueur de la colonne.
func _capuchon(boite: Rect2, code: int, heurte: bool, marquee: bool,
		bat: bool) -> void:
	var teinte: Color = TEINTES[joueur]
	var fond := 0.14
	if heurte:
		# Deux joueurs sur la même touche : ambre, la couleur de ce qui appelle.
		teinte = Charte.AMBRE
		fond = 0.26
	if bat:
		teinte = Charte.AMBRE
		fond = 0.34

	var e := maxf(1.0, _u * 0.045)
	var pts := _arrondi(boite, _u * 0.16)
	_forme(self, pts, Color(teinte, fond), Color(teinte, 0.95), e)

	var f := Charte.police_ui(Charte.POIDS_APPUI)
	if f == null:
		return
	var mot := "…" if bat else libelle_de(code)
	var taille := int(maxf(9.0, _u * 0.40))
	# Un libellé trop long pour son capuchon rétrécit plutôt que de déborder.
	var l := f.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	while l > boite.size.x * 0.82 and taille > 7:
		taille -= 1
		l = f.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	draw_string(f, boite.position + Vector2((boite.size.x - l) * 0.5,
		boite.size.y * 0.5 + taille * 0.36), mot,
		HORIZONTAL_ALIGNMENT_LEFT, -1, taille, teinte)

	if marquee:
		draw_circle(boite.position + Vector2(boite.size.x - _u * 0.19, _u * 0.19),
			maxf(2.0, _u * 0.06), Charte.AMBRE)


## La souris de J1 : il vise avec, et tire avec ses deux boutons.
##
## Une silhouette, pas un rectangle : corps très arrondi en haut, deux boutons
## séparés par la molette. C'est le contour qui la fait reconnaître.
func _souris(coin: Vector2, hauteur: float) -> void:
	var teinte: Color = TEINTES[0]
	var h := minf(hauteur, _u * 3.0)
	var l := h * 0.62
	var corps := Rect2(coin + Vector2(0.0, (hauteur - h) * 0.5), Vector2(l, h))
	var e := maxf(1.0, _u * 0.045)

	# Le haut plus rond que le bas : c'est ce galbe qui dit « souris ».
	var pts := _arrondi(corps, l * 0.46, 7)
	_forme(self, pts, Color(teinte, 0.10), Color(teinte, 0.9), e)

	# Les deux boutons, pleins : ce sont eux, l'information.
	var hb := h * 0.40
	var gauche := Rect2(corps.position + Vector2(l * 0.06, h * 0.05),
		Vector2(l * 0.36, hb))
	var droite := Rect2(corps.position + Vector2(l * 0.58, h * 0.05),
		Vector2(l * 0.36, hb))
	_forme(self, _arrondi(gauche, l * 0.22, 5), Color(teinte, 0.30),
		Color(teinte, 0.8), e * 0.8)
	_forme(self, _arrondi(droite, l * 0.22, 5), Color(teinte, 0.30),
		Color(teinte, 0.8), e * 0.8)

	# La molette, entre les deux.
	var mol := Rect2(corps.position + Vector2(l * 0.44, h * 0.10),
		Vector2(l * 0.12, hb * 0.55))
	_forme(self, _arrondi(mol, l * 0.06, 3), Color(teinte, 0.55),
		Color(teinte, 0.85), e * 0.7)


## La manette, quand le joueur en tient une.
##
## Un corps arrondi et deux poignées qui descendent en oblique : sans elles, la
## silhouette est un rectangle et ne dit rien.
func _dessiner_manette() -> void:
	var teinte: Color = TEINTES[joueur]
	var u := minf(size.x / 7.2, size.y / 4.0)
	var c := size * 0.5
	var e := maxf(1.0, u * 0.05)
	var l := u * 5.4
	var h := u * 2.0

	# Les deux poignées d'abord : le corps se pose par-dessus, et la jonction
	# disparaît sans qu'on ait à découper un polygone.
	for s in [-1.0, 1.0]:
		var g := Rect2(c + Vector2(s * l * 0.30 - u * 0.62, h * 0.10),
			Vector2(u * 1.24, h * 1.15))
		var pts := _arrondi(g, u * 0.58, 7)
		var pivot := g.position + g.size * 0.5
		var tournes := PackedVector2Array()
		for p in pts:
			tournes.append(pivot + (p - pivot).rotated(s * 0.30))
		_forme(self, tournes, Color(teinte, 0.10), Color(teinte, 0.9), e)

	var corps := Rect2(c - Vector2(l, h) * 0.5, Vector2(l, h))
	_forme(self, _arrondi(corps, h * 0.42, 7), Color(teinte, 0.12),
		Color(teinte, 0.95), e)

	# La croix directionnelle, à gauche.
	var dc := c + Vector2(-l * 0.30, -h * 0.04)
	var br := u * 0.46
	var croix := PackedVector2Array([
		Vector2(-br * 0.32, -br), Vector2(br * 0.32, -br),
		Vector2(br * 0.32, -br * 0.32), Vector2(br, -br * 0.32),
		Vector2(br, br * 0.32), Vector2(br * 0.32, br * 0.32),
		Vector2(br * 0.32, br), Vector2(-br * 0.32, br),
		Vector2(-br * 0.32, br * 0.32), Vector2(-br, br * 0.32),
		Vector2(-br, -br * 0.32), Vector2(-br * 0.32, -br * 0.32),
	])
	var pose := PackedVector2Array()
	for p in croix:
		pose.append(dc + p)
	_forme(self, pose, Color(teinte, 0.16), Color(teinte, 0.6), e * 0.8)

	# Les quatre boutons de face, à droite. Celui du tir est plein.
	var bc := c + Vector2(l * 0.30, -h * 0.04)
	var d := u * 0.40
	var places := [Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)]
	for i in places.size():
		draw_circle(bc + places[i], u * 0.17, Color(teinte, 0.16))
		draw_arc(bc + places[i], u * 0.17, 0.0, TAU, 16, Color(teinte, 0.6), e * 0.8)

	# Les deux sticks, au centre-bas — là où les pouces tombent.
	for s in [-1.0, 1.0]:
		var p := c + Vector2(s * l * 0.13, h * 0.30)
		draw_circle(p, u * 0.36, Color(teinte, 0.10))
		draw_arc(p, u * 0.36, 0.0, TAU, 22, Color(teinte, 0.65), e)

	# R1, la gâchette du tir : posée SUR le bord haut, pas flottante au-dessus.
	var g := Rect2(c + Vector2(l * 0.14, -h * 0.62), Vector2(u * 1.05, u * 0.34))
	_forme(self, _arrondi(g, u * 0.16, 4), Color(teinte, 0.26),
		Color(teinte, 0.85), e * 0.8)
