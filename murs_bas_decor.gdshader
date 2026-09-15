// Les marques peintes au sol (`arena_decor.gd`), avec la zone morte des murs bas —
// chantier MURS BAS, MB3c.
//
// Même règle que le sol (`murs_bas_sol.gdshader`), mélange normal : le décor n'a
// plus de matériau additif depuis le lot 4 de la refonte roman graphique. Sans
// lui, un chevron peint dans la zone morte s'allumerait sur un sol resté noir.
shader_type canvas_item;

#include "res://murs_bas_zone.gdshaderinc"

void light() {
	if (mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)) {
		LIGHT = vec4(0.0);
	} else {
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY, LIGHT_COLOR.a);
	}
}
