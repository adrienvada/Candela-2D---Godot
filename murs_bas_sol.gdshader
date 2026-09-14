// Le sol de chaque vue, avec la zone morte des murs bas — chantier MURS BAS, MB3c.
//
// Remplace le `CanvasItemMaterial` additif que `_duplicate_layer_for_player()`
// posait sur les copies du sol : même mélange (`blend_add`), même éclairage par
// défaut, plus la règle. Hors d'une zone morte, le pixel est celui d'avant —
// vérifié au banc `tools/banc_murs_bas.tscn`.
shader_type canvas_item;
render_mode blend_add;

#include "res://murs_bas_zone.gdshaderinc"

void light() {
	if (mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)) {
		LIGHT = vec4(0.0);
	} else {
		// L'éclairage par défaut de Godot, écrit tel quel.
		LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY, LIGHT_COLOR.a);
	}
}
