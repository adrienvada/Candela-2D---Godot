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
void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb, LIGHT_COLOR.a);
}
