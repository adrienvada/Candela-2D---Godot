// La passe de PROFONDEUR des corps grossiers de la vue isométrique (ISO2b).
//
// ⚠️ **Un corps transparent a plusieurs faces à l'écran, et elles ne doivent pas se fondre l'une dans
// l'autre.** Mesuré au banc ISO2b : à opacité 0,5, le corps suivait exactement le fondu de la vue de
// dessus, sauf là où le nez recouvre le tronc à l'écran — les deux pièces s'y mélangeaient l'une
// par-dessus l'autre et le corps y valait 0,75. Décaler le tri des pièces n'y a rien fait (26, 78 puis
// 582 pixels selon l'orientation du joueur). La réponse ne dépend d'aucun ordre : chaque pièce passe
// d'abord ICI, à la priorité de rendu -1, sans couleur (`ALPHA = 0`), et n'écrit que sa profondeur ;
// la couleur (`corps_grossier_iso.gdshader`, priorité 0) ne passe ensuite que sur la surface la plus
// proche. Un seul fondu par pixel, comme un sprite. Les corps voxel d'ISO3, bien plus riches en faces
// superposées, en auront besoin tout autant.
//
// Même règle d'opacité que la couleur, formule pour formule : à opacité nulle (sans silhouette),
// rien n'est écrit — un corps effacé ne cache rien, pas même en profondeur.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled, blend_mix, depth_draw_always;

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
