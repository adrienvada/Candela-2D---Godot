class_name PorteeEcran
extends RefCounted

## Chantier des lumières de la 0.8.0, étape L1 — jusqu'où une torche doit porter pour atteindre le BORD DE L'ÉCRAN
## de son porteur (Q45, Adrien, 2026-09-29 : « Portée des lumières : ça doit au moins aller au bout de l'écran de
## chaque joueur »).
##
## **Une portée DÉRIVÉE du cadrage, jamais un nombre calé sur le zoom du jour.** Q15 fait passer le zoom du duel de
## ×1,5 à ×1,25 à l'essai (branche `claude/v080-q15-q42`) : une constante en pixels aurait été juste un jour, puis
## trop courte le lendemain, sans que rien le dise. Ici tout part de ce qui fait le cadrage — la vue, le zoom, le
## décalage vers la visée (`RegardDuel`), le tangage de la caméra iso (`CameraIso`).
##
## **La géométrie.** La caméra iso garde la profondeur de la vue 2D (`CameraIso.taille_orthographique`) : au sol, elle
## montre un rectangle de `D = vue.y / zoom` en profondeur et de `D × sin θ × vue.x / vue.y` en largeur, dans les axes
## de l'écran — donc tourné du lacet, ce qui ne change AUCUNE distance : J1 à 45° et J2 à 225° (option B) ont le même
## rectangle, orienté autrement. Son centre est avancé vers la visée de `decalage × D` (`RegardDuel.decalage_vise`).
## Le joueur est donc à `−decalage × D × u` du centre, et le bord de l'écran, dans la direction `u` de sa visée, est à
##     t(u) = min(demi_largeur / |u.x|, demi_profondeur / |u.y|) + decalage × D
## (u exprimé dans les axes de l'écran). Le pire cas, vers un COIN, vaut `|demi-rectangle| + decalage × D`.
##
## ⚠️ **Ce que la formule suppose, et que `tools/test_portee_ecran.gd` vérifie sur les vraies caméras** : un regard
## posé (le décalage lissé a rejoint sa cible) et une caméra LIBRE. Près d'un bord de carte, la caméra s'arrête
## (`RegardDuel.centre_du_regard`) et le joueur peut viser un bord d'écran plus lointain, jusqu'à la largeur entière :
## la règle ne le couvre pas (question posée à Adrien, `docs/iso/cloud/lumieres-080/RAPPORT.md`).
##
## Calcul pur, sans nœud ni autoload : `GameSettings` l'appelle, une suite `--script` le vérifie sans monter le jeu.

## La vue de référence, en unités logiques : la vue unique (en ligne, entraînement), l'aire `stretch = keep` de la
## fenêtre. C'est la plus exigeante — l'écran scindé montre moins large (957 × 1080) pour la même profondeur.
const VUE_UNIQUE := Vector2(1920.0, 1080.0)


## Le demi-rectangle de sol que montre une vue iso : (demi-largeur, demi-profondeur), en pixels du monde.
static func demi_empreinte(vue: Vector2, zoom: float, tangage_deg: float) -> Vector2:
	var profondeur := vue.y / maxf(zoom, 0.01)
	var largeur := profondeur * sin(deg_to_rad(tangage_deg)) * vue.x / maxf(vue.y, 1.0)
	return Vector2(largeur, profondeur) * 0.5


## La distance au sol, depuis le joueur, jusqu'au bord de SON écran quand il vise dans la direction `visee` : une
## direction DU SOL, exprimée dans les axes de la caméra (x vers la droite de l'écran, y vers son bas — le signe
## n'importe pas). ⚠️ Pas la direction qu'on lit À L'ÉCRAN : celle-là a sa profondeur raccourcie de sin θ (la première
## garde s'y est trompée de 26 px). Regard posé, caméra libre.
static func distance_au_bord(visee: Vector2, vue: Vector2, zoom: float, decalage: float,
		tangage_deg: float) -> float:
	var u := visee.normalized()
	var h := demi_empreinte(vue, zoom, tangage_deg)
	var t := INF
	if absf(u.x) > 1e-6:
		t = minf(t, h.x / absf(u.x))
	if absf(u.y) > 1e-6:
		t = minf(t, h.y / absf(u.y))
	return t + decalage * vue.y / maxf(zoom, 0.01)


## La plus petite portée qui atteint le bord de l'écran dans TOUTES les directions : celle qui va au coin.
static func portee_minimale(vue: Vector2, zoom: float, decalage: float, tangage_deg: float) -> float:
	return demi_empreinte(vue, zoom, tangage_deg).length() + decalage * vue.y / maxf(zoom, 0.01)
