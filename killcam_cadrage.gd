## La killcam CALME — chantier ISO11, L2 (retour d'Adrien au test 1, 2026-09-15 : « la killcam : les zooms sont
## intempestifs et chaotiques »).
##
## ## Ce qui la rendait chaotique, lu dans le code
##
## - **Le regard du duel continuait pendant le rejeu.** `GameState._suivre_du_regard` repose chaque caméra sur son
##   joueur, avancée vers la visée (`RegardDuel`, un quart de la hauteur visible), à CHAQUE image — killcam comprise,
##   et AVANT le bloc de la killcam. Le lissage de la killcam repartait donc à chaque image de la position du regard
##   et non de la sienne : la caméra suivait les rotations rejouées du joueur réel au lieu du cadrage.
## - **Deux cibles de zoom qui se relayaient.** Au ralenti (`Engine.time_scale < 0,9`), une cible serrée bornée à
##   1,2–2,8 × le zoom du duel ; hors ralenti, une cible large bornée à 0,7–1,3 ×. Le rejeu fait passer ce seuil
##   plusieurs fois (ralenti du tir, 0,03 à l'impact, puis une accélération jusqu'à ×6) : la cible sautait d'une
##   plage à l'autre, et la vitesse de lissage avec elle (3 ↔ 6).
## - **Une cible recalculée à chaque image** sur l'écart des deux fantômes : le zoom respirait à chaque pas.
## - **Un saut à la première image** : la caméra était posée d'un coup sur le milieu des deux fantômes.
##
## ## Ce qui la remplace
##
## Un seul cadrage, calculé UNE fois au début du rejeu sur toutes les positions que les deux joueurs occuperont dans
## la fenêtre de lecture (`ReplaySystem.positions_de_la_fenetre`) ; puis un seul mouvement lent, en temps RÉEL
## (le ralenti ne le hache pas), de la caméra du duel vers ce cadrage, adouci aux deux bouts ; puis plus rien ne
## bouge. Aucun décalage de visée, aucune secousse pendant le rejeu.
##
## Pas de `class_name` : chargé par son chemin (`preload`), il reste lisible par les suites en `--script` sans
## import préalable.
extends RefCounted

## La marge autour des deux joueurs, en pixels de monde au zoom 1 — celle de la lecture d'avant.
const MARGE_PX := 250.0
## La plus petite boîte cadrée : deux joueurs collés ne font pas zoomer à l'infini.
const BOITE_MIN_PX := 200.0
## Les bornes du zoom de killcam, relatives au zoom du duel — la plage de la lecture « normale » d'avant ; la
## plage serrée du ralenti (jusqu'à ×2,8) a disparu avec lui.
const ZOOM_MIN_RELATIF := 0.7
const ZOOM_MAX_RELATIF := 1.3
## La durée du mouvement, en secondes réelles.
const DUREE_S := 1.6


## Le cadrage qui contient toutes les positions : `{centre, zoom}`, vide sans position.
##
## ISO14 — `lacet_deg` : la caméra 2D tournée (r = −L, `GameState.orienter_camera_2d`), la boîte se prend dans SES
## axes — positions tournées de +L, boîte, centre ramené de −L. À 0° c'est le calcul d'avant, à l'identique.
static func cible(positions: PackedVector2Array, vue: Vector2, z_duel: float, lacet_deg: float = 0.0) -> Dictionary:
	if positions.is_empty():
		return {}
	var a := deg_to_rad(lacet_deg)
	var boite := Rect2(positions[0].rotated(a) if lacet_deg != 0.0 else positions[0], Vector2.ZERO)
	for p in positions:
		boite = boite.expand(p.rotated(a) if lacet_deg != 0.0 else p)
	var taille := Vector2(maxf(boite.size.x, BOITE_MIN_PX), maxf(boite.size.y, BOITE_MIN_PX))
	var z := minf(vue.x / (taille.x + MARGE_PX * 2.0), vue.y / (taille.y + MARGE_PX * 2.0))
	var centre := boite.get_center()
	return {"centre": centre.rotated(-a) if lacet_deg != 0.0 else centre,
		"zoom": clampf(z, ZOOM_MIN_RELATIF * z_duel, ZOOM_MAX_RELATIF * z_duel)}


## Le mouvement d'une killcam, depuis la caméra du duel telle qu'elle est à la première image du rejeu.
static func preparer(centre: Vector2, zoom: float, positions: PackedVector2Array, vue: Vector2,
		z_duel: float, lacet_deg: float = 0.0) -> Dictionary:
	var c := cible(positions, vue, z_duel, lacet_deg)
	if c.is_empty():
		c = {"centre": centre, "zoom": zoom}
	return {"depart_centre": centre, "depart_zoom": zoom,
		"cible_centre": c["centre"], "cible_zoom": c["zoom"], "t": 0.0}


## Avance le mouvement de `delta_reel` secondes RÉELLES et rend `[centre, zoom]`. Arrivé au bout, il n'en bouge plus.
static func avancer(cadre: Dictionary, delta_reel: float) -> Array:
	if cadre.is_empty():
		return []
	cadre["t"] = minf(1.0, float(cadre["t"]) + maxf(delta_reel, 0.0) / DUREE_S)
	var e := smoothstep(0.0, 1.0, float(cadre["t"]))
	var centre: Vector2 = (cadre["depart_centre"] as Vector2).lerp(cadre["cible_centre"], e)
	var zoom := lerpf(float(cadre["depart_zoom"]), float(cadre["cible_zoom"]), e)
	return [centre, zoom]
