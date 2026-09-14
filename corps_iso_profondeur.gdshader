shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled, blend_mix, depth_draw_always;

// La passe de PROFONDEUR des corps voxel — chantier ISO, étape ISO3, vague 2.
//
// Miroir de `corps_profondeur_iso.gdshader` (ISO2, commit `02f6c28`) : neuf boîtes se
// recouvrent par corps, bien plus qu'un corps grossier à une seule pièce mobile — sans
// cette passe, deux boîtes semi-transparentes superposées à l'écran s'assombriraient
// deux fois au lieu d'une (0,75 d'opacité effective pour 0,5 demandé, mesuré par ISO2
// sur SON corps à une seule pièce ; le risque est pire ici). Chaque boîte visible de
// `voxel_corps.gd` reçoit un double en ce matériau, même maillage, même transform,
// `render_priority -1` : il écrit la profondeur, sans couleur, avant que la couleur
// (`corps_iso.gdshader`, priorité 0) ne passe sur la seule surface la plus proche.
//
// Même règle d'opacité que la couleur, formule pour formule — un corps effacé ne doit
// rien cacher, pas même en profondeur.

// `lightmap_de_j2()` vient de `iso_lightmap.gdshaderinc`, qui exige lui-même
// `iso_pate.gdshaderinc` inclus avant — ce shader n'appelle pas `pate()`, mais le
// fichier entier doit compiler.
#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform float opacite_1 = 1.0;
uniform float opacite_2 = 1.0;
uniform vec4 silhouette_1 = vec4(0.0);
uniform vec4 silhouette_2 = vec4(0.0);

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	float o = clamp(deux ? opacite_2 : opacite_1, 0.0, 1.0);
	vec4 silhouette = deux ? silhouette_2 : silhouette_1;
	float s = clamp(silhouette.a, 0.0, 1.0);
	float a = 1.0 - (1.0 - o) * (1.0 - s);
	if (a <= 0.0001) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
