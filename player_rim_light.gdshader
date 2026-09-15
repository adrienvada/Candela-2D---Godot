shader_type canvas_item;

// Le joueur éclairé en APLAT — refonte roman graphique, lot 6 (2026-09-10).
//
// La version d'origine faisait un « effet 3D solide » : le bord du disque
// éclairé quatre fois plus que le centre (0,4 → 4,0 en smoothstep). C'était
// juste tant que le joueur était un `Polygon2D` rond ; depuis DA2.4 c'est un
// sprite PEINT, qui porte son propre contour d'encre, et un dégradé radial
// par-dessus un dessin est un vernis. L'aplat rend le dessin tel qu'il est.
//
// Ressource partagée par les deux joueurs : compilée une fois au chargement,
// jamais pendant une manche.
//
// Chantier MURS BAS, MB3c : un accroupi derrière un mur bas ne reçoit pas la
// lumière venue de l'autre côté — jugé en son centre, comme la balle. Les
// uniformes viennent de `MursBasRendu.poser_corps()`, par vue. ⚠️ Le matériau
// est partagé par `visual` et `visual_ptr` d'UN joueur, pas entre joueurs : ils
// ont le même centre.
#include "res://murs_bas_zone.gdshaderinc"

void light() {
	if (mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)) {
		LIGHT = vec4(0.0);
	} else {
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb, LIGHT_COLOR.a);
	}
}
