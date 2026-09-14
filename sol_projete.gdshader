// Le sol de la vue isométrique (ISO1) : la lightmap projetée, passée à la pâte.
//
// ⚠️ `unshaded`, et ce n'est pas une facilité : un sol Lambert éteint le cône d'une
// torche rasante (piège du 2026-09-13). Il n'y a rien à éclairer ici — la lumière EST
// la texture, rendue par le pipeline 2D qui décide du jeu. Aucune Light3D, jamais.
//
// ISO2 : un sol PAR JOUEUR (`Sol1` sur la couche 3D 2, `Sol2` sur la 4), chacun ne
// voyant que la caméra de son joueur ; la lightmap se choisit par cette caméra.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 px = monde.xz;
	float aa = clamp((fwidth(px.x) + fwidth(px.y)) / 6.0, 0.02, 0.5);
	ALBEDO = lightmap_pateuse(px, px, aa, deux);
}
