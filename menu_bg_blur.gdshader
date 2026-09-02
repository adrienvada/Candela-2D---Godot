shader_type canvas_item;

// Shader d'arrière-plan pour le cadre droit du MenuHub :
// - Mode flou total (mode_flou_total = 1.0) pour les panneaux interactifs
// - Mode illustration nette pleine hauteur (mode_flou_total = 0.0) : net en haut/milieu,
//   avec transition progressive vers un flou et assombrissement en bas sous la description.

uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;
uniform float darken : hint_range(0.0, 1.0) = 0.70;
uniform vec4 tint : source_color = vec4(0.03, 0.03, 0.05, 1.0);

uniform float mode_flou_total : hint_range(0.0, 1.0) = 1.0;
uniform float pied_debut : hint_range(0.0, 1.0) = 0.55;
uniform float pied_fin : hint_range(0.0, 1.0) = 0.88;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	
	// En mode illustration nette, le haut reste 100% net et seul le bas (sous la description)
	// reçoit un flou et un assombrissement pour la lisibilité du texte.
	float k_pied = smoothstep(pied_debut, pied_fin, UV.y);
	float k_effet = mix(k_pied, 1.0, mode_flou_total);
	
	float blur_actuel = blur_amount * k_effet;
	vec2 ps = 1.0 / max(tex_size, vec2(1.0)) * blur_actuel;
	
	vec4 col = texture(TEXTURE, UV) * 0.227027;
	col += texture(TEXTURE, UV + vec2(ps.x, 0.0)) * 0.1945946;
	col += texture(TEXTURE, UV - vec2(ps.x, 0.0)) * 0.1945946;
	col += texture(TEXTURE, UV + vec2(0.0, ps.y)) * 0.1945946;
	col += texture(TEXTURE, UV - vec2(0.0, ps.y)) * 0.1945946;
	
	col += texture(TEXTURE, UV + vec2(ps.x, ps.y) * 0.707) * 0.1216216;
	col += texture(TEXTURE, UV - vec2(ps.x, ps.y) * 0.707) * 0.1216216;
	col += texture(TEXTURE, UV + vec2(-ps.x, ps.y) * 0.707) * 0.1216216;
	col += texture(TEXTURE, UV + vec2(ps.x, -ps.y) * 0.707) * 0.1216216;
	
	float darken_actuel = mix(k_pied * 0.85, darken, mode_flou_total);
	vec3 final_rgb = mix(col.rgb, tint.rgb, darken_actuel);
	
	COLOR = vec4(final_rgb, col.a);
}
