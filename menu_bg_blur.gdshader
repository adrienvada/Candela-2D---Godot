shader_type canvas_item;

// Shader d'arrière-plan pour le cadre droit du MenuHub : flou et assombrissement
// pour poser les panneaux interactifs (salons, réglages, classements, historique)
// sur une illustration d'ambiance tout en garantissant une lisibilité parfaite.

uniform float blur_amount : hint_range(0.0, 10.0) = 4.0;
uniform float darken : hint_range(0.0, 1.0) = 0.65;
uniform vec4 tint : source_color = vec4(0.04, 0.04, 0.06, 1.0);

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 ps = 1.0 / max(tex_size, vec2(1.0)) * blur_amount;
	
	vec4 col = texture(TEXTURE, UV) * 0.227027;
	col += texture(TEXTURE, UV + vec2(ps.x, 0.0)) * 0.1945946;
	col += texture(TEXTURE, UV - vec2(ps.x, 0.0)) * 0.1945946;
	col += texture(TEXTURE, UV + vec2(0.0, ps.y)) * 0.1945946;
	col += texture(TEXTURE, UV - vec2(0.0, ps.y)) * 0.1945946;
	
	col += texture(TEXTURE, UV + vec2(ps.x, ps.y) * 0.707) * 0.1216216;
	col += texture(TEXTURE, UV - vec2(ps.x, ps.y) * 0.707) * 0.1216216;
	col += texture(TEXTURE, UV + vec2(-ps.x, ps.y) * 0.707) * 0.1216216;
	col += texture(TEXTURE, UV + vec2(ps.x, -ps.y) * 0.707) * 0.1216216;
	
	vec3 final_rgb = mix(col.rgb, tint.rgb, darken);
	COLOR = vec4(final_rgb, col.a);
}
