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
## **Les deux joueurs, même dans la colonne d'un seul.** C'est ce qui reste de la
## proposition A dans la B : les touches de l'adversaire s'affichent en creux, à
## leur vraie place, pour qu'un chevauchement se voie sans changer d'écran.
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
	return OS.get_keycode_string(_dans_la_disposition(code_physique))


## Le code tel que la disposition du joueur l'imprime sur son capuchon.
##
## ⚠️ **Sans serveur d'affichage, il n'y a pas de disposition à traduire.**
## `keyboard_get_keycode_from_physical()` n'existe pas en headless : appelée
## quand même, elle rend zéro **et journalise une erreur à chaque touche**. Six
## lignes rouges par lancement de banc pour une situation parfaitement normale —
## et un banc qui imprime des erreurs apprend à les ignorer, ce qui coûte le
## jour où l'une d'elles compte. On demande donc d'abord s'il y a un clavier à
## interroger.
static func _dans_la_disposition(code_physique: int) -> int:
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


# ---------------------------------------------------------------------------
# LE DESSIN
# ---------------------------------------------------------------------------

func _draw() -> void:
	if appareil == Appareil.MANETTE:
		_dessiner_manette()
	else:
		_dessiner_clavier()


func _dessiner_clavier() -> void:
	var d := disposition_clavier()
	var lu: float = d["largeur"]
	var hu: float = d["hauteur"]
	# La souris tient à droite du clavier : on lui réserve sa part avant de
	# choisir l'unité, sinon elle déborderait du cadre.
	var largeur_totale: float = lu + 2.2
	_u = minf(size.x / maxf(largeur_totale, 1.0), size.y / maxf(hu + 0.6, 1.0))
	var ox := (size.x - largeur_totale * _u) * 0.5
	var oy := (size.y - hu * _u) * 0.5

	var occupe := occupation(actions)
	var heurts := collisions(actions)
	var marques := {}
	for a: String in reassignables:
		var c := code_physique_de(a)
		if c != 0:
			marques[c] = true
	var bat := code_physique_de(en_attente) if en_attente != "" else 0

	for t: Dictionary in d["touches"]:
		var r: Rect2 = t["r"]
		var code: int = t["code"]
		var boite := Rect2(Vector2(ox, oy) + r.position * _u, r.size * _u)
		var qui: int = occupe.get(code, -1)
		_capuchon(boite, code, qui, heurts.has(code), marques.has(code),
			code == bat)

	_souris(Vector2(ox + (lu + 0.35) * _u, oy + 0.1 * _u), _u)


## Un capuchon de touche.
##
## ⚠️ **Les touches de l'ADVERSAIRE restent visibles, en creux.** C'est ce qui
## reste de la proposition A : une colonne par joueur pour la structure, mais les
## deux mains sur le même plan pour que le chevauchement se voie. Les effacer
## aurait rendu la question invisible — et c'est la seule que le joueur se pose.
func _capuchon(boite: Rect2, code: int, qui: int, heurte: bool, marquee: bool,
		bat: bool) -> void:
	var sien := qui == joueur
	var teinte: Color = Charte.LINE
	var encre: Color = Charte.DIM
	var fond := 0.0

	if heurte:
		# Deux joueurs sur la même touche : ambre, la couleur de ce qui appelle.
		teinte = Charte.AMBRE
		encre = Charte.AMBRE
		fond = 0.22
	elif qui >= 0:
		teinte = TEINTES[qui]
		encre = teinte
		# Le sien plein, celui d'en face en creux — même place, deux poids.
		fond = 0.16 if sien else 0.05
		if not sien:
			encre = Color(teinte, 0.45)
	if bat:
		fond = 0.30
		teinte = Charte.AMBRE
		encre = Charte.AMBRE

	if fond > 0.0:
		draw_rect(boite, Color(teinte, fond), true)
	else:
		draw_rect(boite, Color(Charte.SOL_A, 0.6), true)
	draw_rect(boite, Color(teinte, 1.0 if qui >= 0 else 0.75), false,
		maxf(1.0, _u * 0.035))

	var f := Charte.police_ui(Charte.POIDS_APPUI if qui >= 0
		else Charte.POIDS_COURANT)
	if f == null:
		return
	var mot := "…" if bat else libelle_de(code)
	var taille := int(maxf(8.0, _u * 0.38))
	var l := f.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, taille)
	draw_string(f, boite.position + Vector2((boite.size.x - l.x) * 0.5,
		boite.size.y * 0.5 + taille * 0.36), mot,
		HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre)

	if marquee:
		var p := boite.position + Vector2(boite.size.x - _u * 0.17, _u * 0.10)
		draw_circle(p, maxf(2.0, _u * 0.055), Charte.AMBRE)


## La souris de J1 : il vise avec, et tire avec ses deux boutons.
func _souris(coin: Vector2, u: float) -> void:
	var l := u * 1.35
	var h := u * 2.1
	var corps := Rect2(coin, Vector2(l, h))
	var mienne := joueur == 0
	var teinte: Color = TEINTES[0] if mienne else Charte.LINE
	draw_rect(corps, Color(Charte.SOL_A, 0.6), true)
	# Le contour, en quatre segments : `draw_rect` ne sait pas arrondir.
	draw_rect(corps, Color(teinte, 0.9), false, maxf(1.0, u * 0.035))
	# Les deux boutons, séparés — c'est eux que le joueur cherche.
	var mi := coin + Vector2(l * 0.5, 0.0)
	draw_line(mi, mi + Vector2(0.0, h * 0.42), Color(teinte, 0.55),
		maxf(1.0, u * 0.03))
	draw_line(coin + Vector2(0.0, h * 0.42), coin + Vector2(l, h * 0.42),
		Color(teinte, 0.55), maxf(1.0, u * 0.03))
	if mienne:
		draw_rect(Rect2(coin, Vector2(l * 0.5, h * 0.42)),
			Color(teinte, 0.18), true)
		draw_rect(Rect2(coin + Vector2(l * 0.5, 0.0), Vector2(l * 0.5, h * 0.42)),
			Color(teinte, 0.10), true)


## La manette, quand le joueur en tient une.
func _dessiner_manette() -> void:
	var teinte: Color = TEINTES[joueur]
	var u := minf(size.x / 7.4, size.y / 3.4)
	var c := size * 0.5
	var l := u * 6.0
	var h := u * 2.6
	var corps := Rect2(c - Vector2(l, h) * 0.5, Vector2(l, h))
	draw_rect(corps, Color(Charte.SOL_A, 0.6), true)
	draw_rect(corps, Color(teinte, 0.9), false, maxf(1.0, u * 0.04))

	var e := maxf(1.0, u * 0.035)
	# Les deux sticks.
	for s in [-1.0, 1.0]:
		draw_arc(c + Vector2(s * l * 0.19, h * 0.16), u * 0.44, 0.0, TAU, 28,
			Color(teinte, 0.7), e)
	# Les quatre boutons de face — celui du tir plein.
	var bc := c + Vector2(l * 0.30, -h * 0.12)
	var d := u * 0.42
	var places := [Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)]
	for i in places.size():
		draw_arc(bc + places[i], u * 0.18, 0.0, TAU, 18, Color(teinte, 0.5), e)
	# La croix directionnelle, en deux barres.
	var dc := c + Vector2(-l * 0.30, -h * 0.12)
	var br := u * 0.55
	draw_rect(Rect2(dc - Vector2(br, br * 0.32), Vector2(br * 2.0, br * 0.64)),
		Color(teinte, 0.4), false, e)
	draw_rect(Rect2(dc - Vector2(br * 0.32, br), Vector2(br * 0.64, br * 2.0)),
		Color(teinte, 0.4), false, e)
	# R1, la gâchette du tir : la seule chose pleine du dessin.
	var g := Rect2(c + Vector2(l * 0.16, -h * 0.72), Vector2(u * 1.1, u * 0.34))
	draw_rect(g, Color(teinte, 0.26), true)
	draw_rect(g, Color(teinte, 0.85), false, e)
