// Le disque du capteur de SON PROPRE corps (ISO2, `CapteurCorps`).
//
// ⚠️ **MIROIR de `player_rim_light.gdshader`**, le shader du sprite du joueur tel qu'il se
// voit : l'aplat teinté par la lampe. Même raison et même contrôle que
// `capteur_adverse.gdshader` : `tools/test_iso_vues.gd` compare les deux `light()`.
//
// Hors de `light()`, « lumière seule » : zéro sans lumière. ⚠️ Le sprite du joueur, lui, a en
// dessous une silhouette sans lumière à demi-opacité (`visual_dim`) : en vue de dessus on se
// voit toujours. Le capteur ne la reproduit pas : c'est le corps iso qui la compose par-dessus
// sa lumière, dans la vue de son joueur seulement (ISO2b, `Presentation3D.silhouette_du_corps`).
//
// ⚠️ **Fusion de `main` (murs bas, 2026-09-15) : le miroir suit sa source.**
// `player_rim_light.gdshader` a pris la zone morte des murs bas dans `light()` (MB3c) ; sans elle
// ici, un corps caché derrière un muret en vue de dessus resterait éclairé dans ce capteur, donc
// sur son corps iso. Inerte tant que ses uniformes ne sont pas posés (`mb_zone_morte` à 0,
// `mb_dans_la_zone_morte` rend faux) : ISO3b les pose, dans le repère du capteur
// (`Presentation3D`).
shader_type canvas_item;
render_mode light_only;

#include "res://murs_bas_zone.gdshaderinc"

void light() {
	if (mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)) {
		LIGHT = vec4(0.0);
	} else {
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb, LIGHT_COLOR.a);
	}
}
