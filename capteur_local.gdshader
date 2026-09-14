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
shader_type canvas_item;
render_mode light_only;

void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb, LIGHT_COLOR.a);
}
