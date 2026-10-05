// Le sol de chaque vue, avec la zone morte des murs bas — chantier MURS BAS, MB3c.
//
// Remplace le `CanvasItemMaterial` additif que `_duplicate_layer_for_player()`
// posait sur les copies du sol : même mélange (`blend_add`), même éclairage par
// défaut, plus la règle. Hors d'une zone morte, le pixel est celui d'avant —
// vérifié au banc `tools/banc_murs_bas.tscn`.
shader_type canvas_item;
render_mode blend_add;

#include "res://murs_bas_zone.gdshaderinc"
// OMBRES, OM5 (Q88) — l'ombre finie des corps sous les plafonniers.
#include "res://ombres_corps_zone.gdshaderinc"

void light() {
	if (mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)) {
		LIGHT = vec4(0.0);
	} else {
		// L'éclairage par défaut de Godot, écrit tel quel — moins l'ombre des corps sous un plafonnier (OM5), nulle ailleurs.
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY
			* (1.0 - om_ombre_des_corps(LIGHT_POSITION, LIGHT_VERTEX)), LIGHT_COLOR.a);
	}
}
