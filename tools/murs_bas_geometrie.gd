## La géométrie des murs bas — chantier MURS BAS ET ACCROUPI, étape MB0.
##
## **Une seule fonction décide si une source franchit un mur bas pour atteindre
## une cible : `franchit()`.** La lumière (dans le prototype, le shader de
## `proto_murs_bas.gdshader` en est la traduction ligne à ligne) et la balle
## l'interrogent toutes les deux, ce qui est la règle d'Adrien du 2026-09-14 :
## « balles et lumière debout franchissent le mur bas selon un même angle ».
##
## ## La règle, en une figure
##
## Un rayon qui passe par-dessus un mur bas de hauteur `h` redescend derrière lui
## selon l'angle `α` : il se trouve à la hauteur `c` à la distance
## `(h − c) / tan α` de la face de sortie du mur. Donc, derrière un mur bas :
##
##   - le **sol** (`c = 0`) est dans l'ombre sur `L_sol = h / tan α`, puis se
##     rallume ;
##   - un **accroupi** (`c = h_accroupi < h`) est caché — ni éclairé ni touché —
##     sur `L_accroupi = (h − h_accroupi) / tan α`, puis redevient visible et
##     touchable ;
##   - une **tête debout** (`c ≥ h`) n'est jamais cachée : `L = 0`.
##
## La longueur ne dépend PAS de la distance entre la source et le mur : c'est ce
## que « un même angle » veut dire, et c'est ce qui la rend lisible (une bande
## d'ombre de largeur constante derrière chaque mur bas). La distance se compte
## **le long du rayon**, depuis le point où il sort du mur.
##
## Une source **plus basse que le mur** (torche ou canon d'un accroupi) ne franchit
## jamais : c'est « la torche d'un accroupi bute sur le mur ».
##
## ## Pourquoi ce fichier est sans `class_name` et sans autoload
##
## Il est chargé par `preload` depuis la suite headless (`--script`) et depuis le
## prototype. Un `class_name` neuf exige un réimport avant le lot (Pièges connus,
## « un class_name NEUF exige un réimport ») ; en MB0 rien du jeu ne le nomme, un
## chemin suffit. **En MB1, les hauteurs déménagent dans `map_geometry.gd`** —
## contrat avec la session ISO1 : `HAUTEUR_MUR_HAUT`, `HAUTEUR_MUR_BAS`,
## `HAUTEUR_ACCROUPI`, `HAUTEUR_DEBOUT`, en tuiles, en un seul endroit.
##
## Unités : tout est en PIXELS de monde ici (une tuile vaut 35 px,
## `CandelaTileSet.TILE_SIZE`), sauf les constantes `HAUTEUR_*`, en tuiles comme
## le contrat l'exige. `en_pixels()` fait la conversion.
extends RefCounted

## Côté d'une tuile, recopié de `candela_tileset.gd` (`TILE_SIZE`) pour rester
## chargeable sans le registre des classes. `tools/test_murs_bas.gd` vérifie
## l'égalité : une copie qu'aucun contrôle ne relie à l'original dérive.
const TUILE := 35.0

## Valeurs proposées pour le jalon H-MB0 — à fixer par Adrien au prototype.
## Le pourquoi de chaque nombre est dans `docs/MURS_BAS.md`, § 1.
const HAUTEUR_MUR_HAUT := 1.25
const HAUTEUR_MUR_BAS := 0.5
const HAUTEUR_ACCROUPI := 0.25
const HAUTEUR_DEBOUT := 1.0
## L'angle de franchissement, en degrés au-dessus de l'horizontale. Ce n'est PAS
## le tangage de la caméra iso (52°) : c'est une règle de jeu, pas un cadrage.
const ANGLE_FRANCHISSEMENT := 9.5

## Bornes de l'angle. En dessous, la zone morte dépasserait toute carte ; au-dessus
## de 89°, `tan` explose et la zone morte s'annule — autant ne pas avoir de mur.
const ANGLE_MIN := 1.0
const ANGLE_MAX := 89.0

## Marge flottante des comparaisons de distance — un seuil atteint par des
## calculs flottants tombe sinon d'un côté ou de l'autre selon l'ordre des
## opérations (Pièges connus, « un seuil atteint par une somme de pas… »).
const EPSILON := 1e-4


## Convertit une hauteur en tuiles vers des pixels de monde.
static func en_pixels(tuiles: float) -> float:
	return tuiles * TUILE


## Longueur de la zone morte derrière un mur bas, dans l'unité de `h_mur`.
##
## `h_mur` et `h_cible` dans la même unité ; `angle_deg` borné à
## [ANGLE_MIN, ANGLE_MAX]. Rend 0 si la cible dépasse le mur (tête debout).
static func longueur_zone_morte(h_mur: float, h_cible: float, angle_deg: float) -> float:
	var ecart := h_mur - h_cible
	if ecart <= 0.0:
		return 0.0
	var a := deg_to_rad(clampf(angle_deg, ANGLE_MIN, ANGLE_MAX))
	return ecart / tan(a)


## Paramètre `t` ∈ [0, 1] où le segment `a → b` SORT du rectangle, ou -1 s'il ne
## le traverse pas.
##
## « Traverser » veut dire entrer puis sortir avant `b` : une cible posée SUR le
## mur (dedans) n'est pas derrière lui, et un segment qui n'entre jamais n'a pas
## de sortie. Méthode des dalles, la même que le shader.
static func sortie_du_rect(a: Vector2, b: Vector2, r: Rect2) -> float:
	var d := b - a
	var t_entree := -INF
	var t_sortie := INF
	for axe in 2:
		var o: float = a[axe]
		var v: float = d[axe]
		var lo: float = r.position[axe]
		var hi: float = r.end[axe]
		if absf(v) < 1e-9:
			if o < lo or o > hi:
				return -1.0
			continue
		var t1 := (lo - o) / v
		var t2 := (hi - o) / v
		t_entree = maxf(t_entree, minf(t1, t2))
		t_sortie = minf(t_sortie, maxf(t1, t2))
	if t_entree > t_sortie:
		return -1.0
	# Sortie avant la source, ou cible encore dedans : pas « derrière ».
	if t_sortie <= 0.0 or t_sortie >= 1.0:
		return -1.0
	return t_sortie


## Le segment `a → b` touche-t-il un mur HAUT ? Un mur haut arrête tout, quelle
## que soit la hauteur de la source ou de la cible.
static func coupe_un_mur_haut(a: Vector2, b: Vector2, murs_hauts: Array) -> bool:
	for r: Rect2 in murs_hauts:
		if _segment_touche_rect(a, b, r):
			return true
	return false


## LA règle. Une source à `h_source` en `source` franchit-elle les murs bas pour
## atteindre `cible` à la hauteur `h_cible` ?
##
## Hauteurs et `murs_bas` en pixels de monde ; `h_mur` idem. Ne regarde QUE les
## murs bas : `visible()` y ajoute les murs hauts.
static func franchit(source: Vector2, cible: Vector2, h_source: float, h_cible: float,
		murs_bas: Array, h_mur: float, angle_deg: float) -> bool:
	var longueur := (cible - source).length()
	var zone := longueur_zone_morte(h_mur, h_cible, angle_deg)
	for r: Rect2 in murs_bas:
		var t := sortie_du_rect(source, cible, r)
		if t < 0.0:
			continue
		# La torche d'un accroupi bute : une source qui ne dépasse pas le mur
		# ne passe jamais, à aucune distance.
		if h_source <= h_mur:
			return false
		if (1.0 - t) * longueur < zone - EPSILON:
			return false
	return true


## Franchit les murs bas ET ne touche aucun mur haut.
static func visible(source: Vector2, cible: Vector2, h_source: float, h_cible: float,
		murs_hauts: Array, murs_bas: Array, h_mur: float, angle_deg: float) -> bool:
	if coupe_un_mur_haut(source, cible, murs_hauts):
		return false
	return franchit(source, cible, h_source, h_cible, murs_bas, h_mur, angle_deg)


## Où se termine l'ombre d'un mur bas le long d'un rayon — pour dessiner et pour
## tester. Rend la distance depuis la source (pixels) au-delà de laquelle une
## cible de hauteur `h_cible` redevient visible, ou -1 si le rayon `source →
## source + direction × portee` ne traverse pas `mur`.
static func fin_de_zone_morte(source: Vector2, direction: Vector2, portee: float,
		mur: Rect2, h_mur: float, h_cible: float, angle_deg: float) -> float:
	var b := source + direction.normalized() * portee
	var t := sortie_du_rect(source, b, mur)
	if t < 0.0:
		return -1.0
	return t * portee + longueur_zone_morte(h_mur, h_cible, angle_deg)


## Une empreinte stable d'un résultat de balayage — pour le contrôle de
## déterminisme : deux exécutions, deux ordres de murs, la même empreinte.
static func empreinte_balayage(sources: Array, cibles: Array, h_source: float,
		h_cible: float, murs_bas: Array, h_mur: float, angle_deg: float) -> String:
	var bits := PackedByteArray()
	for s: Vector2 in sources:
		for c: Vector2 in cibles:
			bits.append(1 if franchit(s, c, h_source, h_cible, murs_bas, h_mur, angle_deg) else 0)
	return bits.hex_encode().sha256_text()


static func _segment_touche_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var d := b - a
	var t_entree := 0.0
	var t_sortie := 1.0
	for axe in 2:
		var o: float = a[axe]
		var v: float = d[axe]
		var lo: float = r.position[axe]
		var hi: float = r.end[axe]
		if absf(v) < 1e-9:
			if o < lo or o > hi:
				return false
			continue
		var t1 := (lo - o) / v
		var t2 := (hi - o) / v
		t_entree = maxf(t_entree, minf(t1, t2))
		t_sortie = minf(t_sortie, maxf(t1, t2))
		if t_entree > t_sortie:
			return false
	return true
