class_name RegardDuel
extends RefCounted

## Chantier ISO, étape ISO8 — où la caméra d'un joueur regarde pendant le duel.
##
## Brief de la session cloud (2026-09-15, 12:25), sur mandat d'Adrien de 12:20 : « zoomer dans le jeu […]
## pour le rendre plus claustrophobique ». Un zoom serré n'est jouable que si la caméra montre ce qu'on vise :
## elle avance donc dans la direction de la visée, d'une part de la hauteur visible, et s'arrête aux bords de
## la carte au lieu de montrer le hors-carte noir.
##
## **Calcul pur, sans nœud ni autoload** : `game_state.gd` l'appelle pour ses deux caméras, et une suite
## `--script` le vérifie sans monter le jeu (une suite en `--script` ne peut pas charger `game_state.gd`,
## « Pièges connus »). Présentation locale : chaque machine le calcule pour la caméra de son joueur ; aucune
## donnée réseau, la même règle pour les deux joueurs.

## Combien de monde la caméra montre, en pixels : l'aire 2D de sa vue divisée par le zoom.
static func etendue_visible(vue_px: Vector2, zoom: float) -> Vector2:
	return vue_px / maxf(zoom, 0.01)


## Le décalage VISÉ : la direction de la visée fois `decalage` fois la hauteur visible. Lissé par l'appelant.
static func decalage_vise(visee: Vector2, decalage: float, vue_px: Vector2, zoom: float) -> Vector2:
	if visee == Vector2.ZERO or decalage <= 0.0:
		return Vector2.ZERO
	return visee.normalized() * etendue_visible(vue_px, zoom).y * decalage


## Le centre de la caméra : le joueur plus le décalage (déjà lissé), borné à la carte.
##
## Les bornes n'agissent que sur un axe où la vue est plus petite que la carte, et **seulement au-delà d'un
## zoom de 1,0** : au zoom d'avant ISO8, la vue de 1920×1080 couvre la largeur des cartes livrées et presque
## leur hauteur, et borner l'axe vertical déplacerait le cadrage de toutes les parties d'aujourd'hui. Sur un
## axe borné, la caméra peut montrer au plus une `tuile` de hors-carte (le mur de bordure et sa marge).
static func centre_du_regard(joueur: Vector2, decalage_lisse: Vector2, vue_px: Vector2, zoom: float,
		carte: Rect2, tuile: float) -> Vector2:
	var c := joueur + decalage_lisse
	if zoom <= 1.0 or carte.size == Vector2.ZERO:
		return c
	var visible := etendue_visible(vue_px, zoom)
	for axe in 2:
		if visible[axe] < carte.size[axe] + 2.0 * tuile:
			var demi := visible[axe] * 0.5
			c[axe] = clampf(c[axe], carte.position[axe] + demi - tuile, carte.end[axe] - demi + tuile)
	return c


## Le lissage du décalage, indépendant de la cadence (exponentiel) : ~120 ms pour faire le chemin aux deux tiers.
static func lisser(actuel: Vector2, vise: Vector2, delta: float) -> Vector2:
	return actuel.lerp(vise, 1.0 - exp(-8.0 * maxf(delta, 0.0)))
