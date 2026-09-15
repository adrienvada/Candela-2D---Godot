// ISO12, lot 0 — la pâte (b) en ÉCRAN SCINDÉ : la même passe que `pate_ecran_iso.gdshader`, posée sur l'affichage de chaque
// vue iso (`AffichageIso1/2`, un TextureRect de la texture de sa sous-vue). Elle lit `TEXTURE`, donc aucune copie d'écran.
// Invariant de la pâte : 0 reste 0.
shader_type canvas_item;

#include "res://iso_pate.gdshaderinc"

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.rgb;
	float l = pate_luminance(c);
	if (style != PATE_BRUTE && l > 0.0) {
		c = pate(c, l, style, FRAGCOORD.xy, vec2(0.0), l, 0.25);
	}
	COLOR = vec4(c, t.a);
}
