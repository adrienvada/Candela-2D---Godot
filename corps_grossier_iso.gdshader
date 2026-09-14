// Les corps GROSSIERS de la vue isométrique (ISO1) — les cylindres gris du banc
// ISO0.b, en attendant les corps voxel d'ISO3 (qui auront leur propre shader,
// `corps_iso.gdshader`, à la session iso-corps).
//
// « Gris plafonné, noir hors lumière » : la lumière lue sous les pieds du corps.
// ⚠️ Ce n'est PAS la lumière reçue par le corps : le halo de proximité révèle un
// ennemi collé en n'éclairant que son sprite, le sol reste noir, et ce corps
// disparaît là où la vue de dessus le montre (constaté au banc ISO0.b). Les capteurs
// de corps d'ISO2 lèvent ce défaut ; ISO1 ne le corrige pas.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform vec2 pied_corps = vec2(0.0);
uniform vec3 gris : source_color = vec3(0.5);
uniform float seuil_bas = 0.01;
uniform float seuil_haut = 0.08;

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 motif = vec2(monde.x + monde.z, -monde.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	float recue = pate_luminance(lire_lightmap(pied_corps));
	vec3 c = gris * smoothstep(seuil_bas, seuil_haut, recue);
	ALBEDO = pate(c, pate_luminance(c), style, motif, vec2(0.0), recue, aa);
}
