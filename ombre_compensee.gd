class_name OmbreCompensee
extends RefCounted
## ESSAI (session cloud ombre-orientation, 2026-09-27) — `--ombre-compensee=1|2` : la voie (d) de l'ombre des classes.
##
## **Le constat** (session ombre-classes, `docs/iso/cloud/ombre-classes/RAPPORT.md`) : sous la torche adverse, chaque corps
## jette sur son PROPRE capteur une ombre à la forme de sa silhouette (l'étoile de `Charte.ombre_de_silhouette`, décision
## d'Adrien du 2026-08-26). Le corps lit ce capteur sur un anneau de 15 px ; une arme large en cache une plus grande part,
## et la lumière lue diffère d'une classe à l'autre au même endroit — et, pour une même classe, d'une orientation à l'autre.
##
## **La voie (d)** : garder l'ombre (la forme de l'arme, au sol et sur le corps) et multiplier la lumière que le corps LIT
## par un facteur, pour que chaque classe lise ce que lirait le Parasite (la classe de référence) :
##   facteur = part de l'anneau éclairée pour le Parasite / part éclairée pour cette classe.
## - `1` (d1) : un facteur CONSTANT par classe — les deux parts en moyenne sur toutes les directions de la torche (aucune
##   orientation n'est privilégiée ; le rapport dit pourquoi pas le profil seul) ;
## - `2` (d2) : le facteur de la direction RÉELLE de la torche adverse dans le repère du corps, relu à chaque image.
## Le Parasite garde 1 par construction, dans les deux variantes : son image et son seuil d'apparition ne bougent pas.
##
## **La géométrie** : les rayons de la torche sont pris parallèles (la torche est à plus de 50 px, l'anneau fait 15 px ;
## mesuré au banc, la part cachée est la même à 154 et à 285 px). Un point de l'anneau est dans l'ombre si l'occluder
## s'étend, sur la ligne qui le relie à la torche, plus près de la torche que lui (intérieur compris) — la règle d'une
## Light2D (`analyse_ombre.py` fait le même calcul avec la vraie torche). 64 points, comme le banc et le corps.
## La part se range dans une table de 64 directions par forme d'occluder, remplie À LA DEMANDE (une direction coûte
## 64 × 32 tests) puis interpolée : une image ordinaire ne fait que lire deux cases.
##
## ⚠️ **Débogage seulement, et jamais en ligne** : même règle que `--ombre-ronde` et `--zoom`. Éteint (défaut), la
## présentation ne pose RIEN et l'uniforme `compensation_ombre` des shaders des corps reste à 1,0 : la lecture du capteur
## est celle d'avant au bit près (garde : `tools/test_ombre_compensee.gd`). Aucun masque de lumière de `player.gd`, aucune
## simulation, `Protocol.VERSION` inchangé : le facteur ne touche que la couleur d'un corps à l'écran.

const DRAPEAU := "--ombre-compensee"
const RAYON_LU := 15.0
const POINTS := 64
const DIRECTIONS := 64
## Un facteur borné : une classe dont l'anneau serait presque entièrement dans l'ombre ne s'allume pas d'un coup.
const FACTEUR_MIN := 0.25
const FACTEUR_MAX := 4.0
const SILHOUETTE_REFERENCE := "res://assets/sprites/pistolet_silhouette.png"

## Posé par un outil pour basculer dans le même processus ; négatif = la ligne de commande décide. Mêmes verrous.
static var mode_force := -1
static var _mode_ligne := -2
## Tables des parts éclairées, par forme d'occluder (`hash` du polygone) : Array de DIRECTIONS flottants, -1 = à calculer.
static var _tables := {}
static var _reference := PackedVector2Array()


## Le mode d'essai : 0 (éteint), 1 ou 2. Calcul pur, vérifié en `--script`.
static func mode(args: PackedStringArray, debug: bool, en_ligne: bool, force: int = -1) -> int:
	if not debug or en_ligne:
		return 0
	if force >= 0:
		return force if force in [1, 2] else 0
	for a in args:
		if a == DRAPEAU:
			return 2
		if a.begins_with(DRAPEAU + "="):
			var v := a.substr(DRAPEAU.length() + 1)
			return int(v) if v in ["1", "2"] else 0
	return 0


## Le mode de ce lancement (la ligne de commande n'est lue qu'une fois).
static func mode_du_lancement(en_ligne: bool) -> int:
	if _mode_ligne == -2:
		_mode_ligne = mode(OS.get_cmdline_user_args() + OS.get_cmdline_args(), true, false)
	return mode(PackedStringArray(), OS.is_debug_build(), en_ligne, mode_force if mode_force >= 0 else _mode_ligne)


## La part des POINTS de l'anneau (rayon RAYON_LU, centré sur l'origine de l'occluder) que la lumière venue de la
## direction `vers_torche` (repère de l'occluder) atteint sans traverser l'occluder.
static func part_eclairee(poly: PackedVector2Array, vers_torche: Vector2) -> float:
	var n := poly.size()
	if n < 3:
		return 1.0
	var w := vers_torche.normalized()
	var o := w.orthogonal()
	var ts := PackedFloat64Array()
	var ss := PackedFloat64Array()
	ts.resize(n)
	ss.resize(n)
	for i in n:
		ts[i] = poly[i].dot(o)
		ss[i] = poly[i].dot(w)
	var eclaires := 0
	for k in POINTS:
		# Décalés d'un demi-pas : aux angles k/64, les points tombent sur les rayons de l'étoile (k/32), et un sommet à 15 px
		# pile est SUR l'anneau — un point ni éclairé ni dans l'ombre, que les arrondis tranchaient au hasard.
		var p := Vector2.from_angle(TAU * (float(k) + 0.5) / float(POINTS)) * RAYON_LU
		var t := p.dot(o)
		var s := p.dot(w)
		var ombre := false
		for i in n:
			var j := (i + 1) % n
			var ta := ts[i]
			var tb := ts[j]
			if (ta <= t) == (tb <= t):
				continue
			# Le bord de l'occluder qui coupe la ligne de ce point vers la torche : plus près de la torche que lui ?
			var s_bord := ss[i] + (ss[j] - ss[i]) * (t - ta) / (tb - ta)
			if s_bord > s:
				ombre = true
				break
		if not ombre:
			eclaires += 1
	return float(eclaires) / float(POINTS)


## La part éclairée pour une direction quelconque, interpolée dans la table de cette forme (remplie à la demande).
static func part_table(poly: PackedVector2Array, vers_torche: Vector2) -> float:
	var t := _table(poly)
	var x := fposmod(vers_torche.angle() / TAU * float(DIRECTIONS) - 0.5, float(DIRECTIONS))
	var i := int(floorf(x)) % DIRECTIONS
	var f := x - floorf(x)
	var j := (i + 1) % DIRECTIONS
	return lerpf(_case(poly, t, i), _case(poly, t, j), f)


## La part moyenne sur les DIRECTIONS directions (la table entière, calculée si besoin).
static func part_moyenne(poly: PackedVector2Array) -> float:
	var t := _table(poly)
	var somme := 0.0
	for i in DIRECTIONS:
		somme += _case(poly, t, i)
	return somme / float(DIRECTIONS)


## La direction de la case i : décalée d'un demi-pas. ⚠️ Sans ce décalage, les directions de la table tombent pile sur
## les rayons de l'étoile et sur des points de l'anneau (même pas angulaire, 32 et 64) : des égalités exactes, que
## l'arrondi tranchait d'un côté en 32 bits et de l'autre en 64 — jusqu'à 0,05 d'écart sur un facteur (Braconnier 0,893
## ici, 0,920 dans l'analyse Python, même polygone au millième). Projections en 64 bits pour la même raison.
static func direction_de_case(i: int) -> Vector2:
	return Vector2.from_angle(TAU * (float(i) + 0.5) / float(DIRECTIONS))


static func _table(poly: PackedVector2Array) -> Array:
	var cle := hash(poly)
	if not _tables.has(cle):
		var t := []
		t.resize(DIRECTIONS)
		t.fill(-1.0)
		_tables[cle] = t
	return _tables[cle]


static func _case(poly: PackedVector2Array, t: Array, i: int) -> float:
	if float(t[i]) < 0.0:
		t[i] = part_eclairee(poly, direction_de_case(i))
	return float(t[i])


## L'étoile du Parasite, la classe de référence.
static func forme_reference() -> PackedVector2Array:
	if _reference.is_empty():
		_reference = Charte.ombre_de_silhouette(load(SILHOUETTE_REFERENCE) as Texture2D)
	return _reference


## Le rapport référence / forme, borné. Une part nulle (anneau tout à l'ombre) rend 1 : rien à compenser.
static func _rapport(ref: float, forme: float) -> float:
	if forme <= 0.0:
		return 1.0
	return clampf(ref / forme, FACTEUR_MIN, FACTEUR_MAX)


## (d1) Le facteur constant d'une forme d'occluder.
static func facteur_constant(poly: PackedVector2Array) -> float:
	if poly == forme_reference():
		return 1.0
	return _rapport(part_moyenne(forme_reference()), part_moyenne(poly))


## (d2) Le facteur d'une forme d'occluder pour la direction `vers_torche` (repère de l'occluder).
static func facteur_direction(poly: PackedVector2Array, vers_torche: Vector2) -> float:
	if poly == forme_reference():
		return 1.0
	return _rapport(part_table(forme_reference(), vers_torche), part_table(poly, vers_torche))


## Le facteur du corps `joueur` sous la torche de `adversaire`, dans le mode donné (1 si rien à faire).
static func facteur_du_joueur(mode_essai: int, joueur: Node2D, adversaire: Node2D) -> float:
	if mode_essai == 0 or joueur == null or not joueur.has_node("LightOccluder2D"):
		return 1.0
	var occ := joueur.get_node("LightOccluder2D") as LightOccluder2D
	if occ.occluder == null:
		return 1.0
	var poly := occ.occluder.polygon
	if mode_essai == 1:
		return facteur_constant(poly)
	if adversaire == null:
		return 1.0
	var lampe: Node2D = adversaire.get("flashlight") as Node2D
	var source := lampe.global_position if lampe != null else adversaire.global_position
	var locale := occ.global_transform.affine_inverse() * source
	if locale.length() < 0.001:
		return 1.0
	return facteur_direction(poly, locale)
