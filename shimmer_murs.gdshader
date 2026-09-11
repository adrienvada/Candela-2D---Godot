shader_type canvas_item;
render_mode blend_add;

// Shimmer et spécularité du liseré de mur (V5.8 — Chantier 2) — Candela 2D
// Fait vibrer et scintiller subtilement les bordures et arêtes lorsqu'elles sont
// balayées par la torche des joueurs (accroche métallique ou rugueuse de la lumière rasante).
// L'intérieur du mur reste STRICTEMENT en noir d'encre absolu (Charte.NOIR).

uniform float intensite_shimmer : hint_range(0.0, 2.0) = 0.85;
uniform float frequence_scintillement : hint_range(0.5, 10.0) = 4.5;
uniform float rugosite_arete : hint_range(0.5, 20.0) = 8.0;
uniform vec4 couleur_lisere : source_color = vec4(0.98, 0.91, 0.80, 1.0); // Charte.HALOGENE
uniform vec4 couleur_reflet : source_color = vec4(0.96, 0.69, 0.24, 1.0); // Charte.AMBRE

varying vec2 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Bruit pseudo-aléatoire léger et déterministe pour simuler les micro-aspérités d'acier/béton
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);

	// Masquage absolu : l'intérieur du mur doit rester du NOIR D'ENCRE PUR (Charte.NOIR).
	// Seul le liseré halogène extérieur (luminance > 0.2) reçoit le shimmer.
	float lum = max(base_color.r, max(base_color.g, base_color.b));
	float is_lisere = smoothstep(0.12, 0.45, lum);

	if (is_lisere <= 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// Échantillonnage continu sur coordonnées monde (pas de discontinuité aux jointures de tuiles)
		vec2 p = v_world_pos * (rugosite_arete * 0.1);
		float n1 = hash21(floor(p));
		float n2 = hash21(floor(p * 1.618 + vec2(0.5, 0.5)));

		// Scintillement dynamique temporel
		float t = TIME * frequence_scintillement;
		float pulse = sin(t + v_world_pos.x * 0.15 + v_world_pos.y * 0.2) * 0.5 + 0.5;
		float grain = mix(n1, n2, pulse);

		// Pic spéculaire tranché (style roman graphique brut)
		float glint = pow(grain, 3.5) * intensite_shimmer;

		// Teinte du liseré : Halogène enrichi d'éclats ambrés sur les micro-facettes
		vec3 teinte_active = mix(couleur_lisere.rgb, couleur_reflet.rgb, glint * 0.4);
		vec3 final_rgb = base_color.rgb * (1.0 + glint * 0.7) + teinte_active * (glint * 0.35);

		COLOR = vec4(final_rgb * is_lisere, base_color.a * is_lisere);
	}
}

void light() {
	// Réaction directe à la lumière des torches :
	// En obscurité totale ou hors du faisceau, LIGHT reste rigoureusement nul.
	float light_lum = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), LIGHT_COLOR.b) * LIGHT_ENERGY;
	if (light_lum > 0.001 && COLOR.r > 0.02) {
		// Accroche métallique en lumière rasante :
		// LIGHT_VERTEX représente la position du fragment par rapport à la source de lumière.
		vec2 dir_to_light = -normalize(LIGHT_VERTEX.xy);
		// Détection de l'incidence rasante sur les axes orthogonaux des murs (horizontal/vertical)
		float rasant = max(abs(dir_to_light.x), abs(dir_to_light.y));
		float spec_boost = 1.0 + pow(rasant, 2.0) * 0.6;

		vec3 specular = LIGHT_COLOR.rgb * COLOR.rgb * spec_boost;
		LIGHT = vec4(specular, LIGHT_COLOR.a);
	} else {
		LIGHT = vec4(0.0);
	}
}
