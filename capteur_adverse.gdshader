// Le disque du capteur d'un corps vu D'EN FACE (ISO2, `CapteurCorps`).
//
// ⚠️ **MIROIR de `player_enemy_light.gdshader`, `light()` pour `light()`.** Le capteur rend au
// corps 3D la lumière que recevrait le sprite ennemi qu'il remplace : il doit la recevoir par la
// même courbe — × l'énergie de la lampe, ×4 puis plafond, × la forme de son masque. Jusqu'au
// jalon H-ISO2 (2026-09-14), le disque prenait la lumière par défaut du moteur et le corps
// tranchait par un seuil : 8 % de lumière reçue le mettaient au gris plein, là où le sprite de
// la vue de dessus monte avec la lampe. `tools/test_iso_vues.gd` compare les deux `light()`,
// commentaires et blancs retirés : en changer un sans l'autre fait échouer la suite.
//
// Seule différence, hors de `light()` : « lumière seule ». Le disque blanc ne vaut que ce que
// les lumières lui apportent — zéro sans lumière, quel que soit le `CanvasModulate` de l'arène,
// qui ne l'éteignait pas dans la sous-vue du capteur (13 à 17/255 mesurés au banc ISO2).
//
// ⚠️ **Fusion de `main` (murs bas, 2026-09-15) : le miroir suit sa source.**
// `player_enemy_light.gdshader` a pris la zone morte des murs bas dans `light()` (MB3c) ; sans elle
// ici, un corps caché derrière un muret en vue de dessus resterait éclairé dans ce capteur, donc
// sur son corps iso. Inerte tant que ses uniformes ne sont pas posés (`mb_zone_morte` à 0,
// `mb_dans_la_zone_morte` rend faux) : ISO3b les pose, dans le repère du capteur
// (`Presentation3D`).
shader_type canvas_item;
render_mode light_only;

#include "res://murs_bas_zone.gdshaderinc"

void light() {
	float light_val = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), LIGHT_COLOR.b) * LIGHT_ENERGY;
	if (mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)) {
		LIGHT = vec4(0.0);
	} else if (light_val > 0.001) {
		vec3 lit = COLOR.rgb * (light_val * 4.0);
		LIGHT = vec4(min(lit, COLOR.rgb), LIGHT_COLOR.a);
	} else {
		LIGHT = vec4(0.0);
	}
}
