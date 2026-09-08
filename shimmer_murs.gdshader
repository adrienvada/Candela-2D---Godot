shader_type canvas_item;

// Shimmer du liseré de mur (V5.8) — Candela 2D
// Fait scintiller les arêtes et bordures de murs exposées à la torche.

uniform float intensite_shimmer : hint_range(0.0, 2.0) = 0.8;
uniform float frequence_scintillement : hint_range(0.5, 10.0) = 4.0;
uniform vec4 couleur_lisere : source_color = vec4(0.98, 0.91, 0.80, 1.0); // Halogène
uniform vec4 couleur_reflet : source_color = vec4(0.96, 0.69, 0.24, 1.0); // Ambre

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = dot(i, vec2(1.0, 57.0));
	return mix(
		mix(fract(sin(n + 0.0) * 43758.5453), fract(sin(n + 1.0) * 43758.5453), f.x),
		mix(fract(sin(n + 57.0) * 43758.5453), fract(sin(n + 58.0) * 43758.5453), f.x),
		f.y
	);
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	
	// Échantillonnage du bruit de micro-aspérités sur les arêtes
	vec2 world_pos = UV * 120.0;
	float n = noise(world_pos + vec2(TIME * frequence_scintillement * 0.2, 0.0));
	
	// Pics de brillance spéculaire
	float glint = pow(n, 4.0) * intensite_shimmer;
	
	// Scintillement dynamique modulé
	float pulse = sin(TIME * frequence_scintillement + world_pos.x * 2.0) * 0.5 + 0.5;
	glint *= mix(0.5, 1.5, pulse);
	
	vec4 final_glow = mix(couleur_lisere, couleur_reflet, glint * 0.5) * glint;
	COLOR = base_color + final_glow * base_color.a;
}
