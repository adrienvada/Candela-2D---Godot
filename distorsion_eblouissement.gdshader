shader_type canvas_item;

// Distorsion & Bloom d'éblouissement (V5.3) — Candela 2D
// Aberration chromatique radiale et ondulation thermique d'objectif ébloui.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float niveau_eblouissement : hint_range(0.0, 1.0) = 0.0;
uniform float aberration_chromatique : hint_range(0.0, 0.05) = 0.015;
uniform float force_ondulation : hint_range(0.0, 0.05) = 0.008;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center_offset = uv - vec2(0.5);
	float dist_center = length(center_offset);
	
	// Ondulation thermique / réfraction d'air chaud
	float wave = sin(uv.y * 40.0 + TIME * 8.0) * cos(uv.x * 30.0 + TIME * 6.0);
	vec2 distorted_uv = uv + center_offset * wave * force_ondulation * niveau_eblouissement;
	
	// Séparation des canaux RGB (aberration chromatique radiale)
	vec2 shift = center_offset * aberration_chromatique * niveau_eblouissement * (dist_center + 0.2);
	
	float r = texture(screen_texture, distorted_uv + shift).r;
	float g = texture(screen_texture, distorted_uv).g;
	float b = texture(screen_texture, distorted_uv - shift).b;
	
	vec4 col = vec4(r, g, b, 1.0);
	
	// Voile chaud additif sur forte exposition
	vec4 bloom_chaud = vec4(0.98, 0.91, 0.80, 1.0) * pow(niveau_eblouissement, 1.5) * 0.4;
	
	COLOR = col + bloom_chaud;
}
