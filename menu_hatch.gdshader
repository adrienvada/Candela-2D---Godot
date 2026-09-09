shader_type canvas_item;
render_mode blend_mix, unshaded;

// =============================================================================
// SHADER DE TRAME & HACHURES (« Roman Graphique Brutaliste ») — Candela 2D
// =============================================================================
// Étape 2 : Matière, trames d'encrage & grain (Shaders légers & Sérigraphie)
//
// Reproduit le rendu graphique des comics noir & blanc et de la sérigraphie :
// 1. Hachures simples à 45° (hachures d'ombrage manuelles)
// 2. Hachures croisées (cross-hatching pour ombres denses et fonds inactifs)
// 3. Trame de demi-teinte (halftone dots / points d'imprimerie en quinconce)
// 4. Encrage manuel Rotring / plume (aspérités, micro-ondulations de tracé)
// 5. Bordures physiques au trait de plume avec bavures subtiles sur papier canson
// 6. Mode alerte dynamique (pulsation / défilement pour PV / munitions critiques)
// =============================================================================

// --- Modes de motif ---
// 0: Hachures simples (Single Hatching)
// 1: Hachures croisées (Cross-Hatching)
// 2: Trame de demi-teinte (Halftone Screenprint Dots)
// 3: Hachures d'encrage manuel expressif (Rotring Ink Hatching)
uniform int pattern_mode : hint_range(0, 3) = 0;

// --- Géométrie & Espacement ---
uniform float spacing : hint_range(2.0, 64.0) = 10.0;
uniform float line_width : hint_range(0.5, 16.0) = 1.6;
uniform float angle_deg : hint_range(-180.0, 180.0) = 45.0;
uniform float density : hint_range(0.0, 1.0) = 0.5;

// --- Couleurs de la Charte ---
// Fond d'encre profond (Charte.NOIR ou Charte.SURFACE)
uniform vec4 color_ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Trait ou point d'encre (Charte.LINE, Charte.AMBRE, Charte.HALOGENE, Charte.ROUGE)
uniform vec4 color_line : source_color = vec4(0.189, 0.2052, 0.2214, 1.0);

// --- Matière & Texture de papier ---
// Aspérité / micro-ondulation du trait (tracé à la main)
uniform float roughness : hint_range(0.0, 1.0) = 0.0;
// Grain du papier canson / bruit de sérigraphie
uniform float grain_intensity : hint_range(0.0, 0.25) = 0.035;
// Mix d'opacité globale (1.0 = opaque, < 1.0 = transparent / overlay)
uniform float alpha_mix : hint_range(0.0, 1.0) = 1.0;

// --- Bordure au trait de plume / Rotring ---
uniform float border_width : hint_range(0.0, 20.0) = 0.0;
uniform vec4 border_color : source_color = vec4(0.189, 0.2052, 0.2214, 1.0);
uniform float border_roughness : hint_range(0.0, 1.0) = 0.4;

// --- Animation & Alerte de jeu ---
// Facteur de pulsation d'alerte (0.0 = repos, 1.0 = alerte critique)
uniform float alert_pulse : hint_range(0.0, 1.0) = 0.0;
// Vitesse d'animation / défilement
uniform float speed : hint_range(-10.0, 10.0) = 0.0;

// --- Coordonnées & Dimensions ---
uniform bool use_local_coords = true;
uniform vec2 rect_size = vec2(100.0, 100.0);

varying vec2 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

// Bruit pseudo-aléatoire 2D ultra-léger
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Rotation 2D d'un vecteur
vec2 rot(vec2 p, float rad) {
	float c = cos(rad);
	float s = sin(rad);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Calcul d'une famille de hachures à un angle donné avec aspérités
float eval_hatch_line(vec2 pos, float theta, float spc, float w, float rough) {
	vec2 p_rot = rot(pos, theta);
	
	// Micro-ondulation manuelle (irrégularité du poignet et du papier)
	if (rough > 0.001) {
		float wave = sin(p_rot.y * 0.18) * 0.65 + sin(p_rot.y * 0.42 + 1.3) * 0.35;
		p_rot.x += wave * rough * (spc * 0.22);
		// Micro-variation de l'épaisseur du trait
		w *= (1.0 + (hash12(vec2(floor(p_rot.x / spc), floor(p_rot.y * 0.05))) - 0.5) * 0.35 * rough);
	}
	
	// Distance au centre du segment de hachure le plus proche
	float d = abs(mod(p_rot.x + spc * 0.5, spc) - spc * 0.5);
	
	// Anti-aliasing sous-pixel précis
	float half_w = max(0.2, w * 0.5);
	return 1.0 - smoothstep(half_w - 0.75, half_w + 0.75, d);
}

// Trame de demi-teinte (halftone dots) en quinconce
float eval_halftone(vec2 pos, float theta, float spc, float dens, float rough) {
	vec2 p_rot = rot(pos, theta);
	
	// Grille en quinconce (décalage une rangée sur deux)
	float row = floor(p_rot.y / spc);
	if (mod(row, 2.0) != 0.0) {
		p_rot.x += spc * 0.5;
	}
	
	if (rough > 0.001) {
		p_rot += (vec2(hash12(p_rot * 0.05), hash12(p_rot * 0.05 + 7.7)) - vec2(0.5)) * rough * 1.5;
	}
	
	vec2 cell = mod(p_rot + spc * 0.5, spc) - spc * 0.5;
	float dist_center = length(cell);
	
	// Rayon du point proportionnel à la densité de trame
	float max_radius = spc * 0.48;
	float radius = max_radius * clamp(dens, 0.08, 0.95);
	
	return 1.0 - smoothstep(radius - 0.75, radius + 0.75, dist_center);
}

// Évaluation de la bordure au trait de plume / rotring le long des arêtes
float eval_rotring_border(vec2 pos, vec2 size, float b_width, float b_rough) {
	if (b_width <= 0.001 || size.x <= 0.0 || size.y <= 0.0) {
		return 0.0;
	}
	
	// Distance minimale au bord le plus proche (rectangle 2D)
	float d_edge = min(min(pos.x, size.x - pos.x), min(pos.y, size.y - pos.y));
	
	// Aspérités d'encrage manuel le long des arêtes
	if (b_rough > 0.001) {
		float micro_bump = sin(pos.x * 0.25 + pos.y * 0.25) * 0.65;
		micro_bump += (hash12(floor(pos * 0.5)) - 0.5) * 0.75;
		d_edge += micro_bump * b_rough * 1.4;
	}
	
	return 1.0 - smoothstep(b_width - 0.75, b_width + 0.75, d_edge);
}

void fragment() {
	// 1. Détermination des coordonnées locales ou d'écran
	vec2 size = (rect_size.x > 0.0 && rect_size.y > 0.0) ? rect_size : vec2(100.0, 100.0);
	vec2 pos = use_local_coords ? v_local_pos : FRAGCOORD.xy;
	if (use_local_coords && length(v_local_pos) < 0.001 && (UV.x > 0.0 || UV.y > 0.0)) {
		// Repli de sécurité si VERTEX n'était pas injecté par le conteneur
		pos = UV * size;
	}

	// 2. Défilement / animation temporelle
	if (abs(speed) > 0.001) {
		pos += rot(vec2(TIME * speed * 25.0, 0.0), radians(angle_deg));
	}

	// 3. Modulation d'alerte critique (pulsation du trait et de la lumière)
	float effective_width = line_width;
	float effective_density = density;
	float pulse_factor = 0.0;
	if (alert_pulse > 0.001) {
		pulse_factor = 0.5 + 0.5 * sin(TIME * (speed != 0.0 ? speed * 8.0 : 9.0));
		effective_width += pulse_factor * alert_pulse * 1.5;
		effective_density = mix(density, clamp(density * 1.6, 0.1, 0.95), pulse_factor * alert_pulse);
	}

	// 4. Calcul du motif principal
	float rad = radians(angle_deg);
	float pattern_val = 0.0;
	
	if (pattern_mode == 0) {
		// Hachures simples à 45°
		pattern_val = eval_hatch_line(pos, rad, spacing, effective_width, roughness);
	} else if (pattern_mode == 1) {
		// Hachures croisées (angle principal + angle perpendiculaire à 90°)
		float line1 = eval_hatch_line(pos, rad, spacing, effective_width, roughness);
		float line2 = eval_hatch_line(pos, rad + 1.5707963, spacing, effective_width, roughness);
		pattern_val = max(line1, line2);
	} else if (pattern_mode == 2) {
		// Trame de demi-teinte (halftone dots)
		pattern_val = eval_halftone(pos, rad, spacing, effective_density, roughness);
	} else if (pattern_mode == 3) {
		// Hachures d'encrage manuel expressif (Rotring / Canson)
		float rough_ink = max(0.35, roughness);
		float line_ink = eval_hatch_line(pos, rad, spacing, effective_width, rough_ink);
		if (density > 0.55) {
			// Deuxième passe croisée plus fine pour les zones sombres
			float cross_ink = eval_hatch_line(pos, rad + 1.5707963, spacing * 1.2, effective_width * 0.7, rough_ink);
			pattern_val = max(line_ink, cross_ink * (density - 0.55) * 2.2);
		} else {
			pattern_val = line_ink;
		}
	}

	// 5. Couleur de base : interpolation Encre (fond) -> Trait
	vec4 current_line_col = color_line;
	if (alert_pulse > 0.001) {
		// En mode alerte critique, le trait gagne en brillance incandescente
		current_line_col = mix(color_line, color_line * (1.2 + pulse_factor * 0.4), alert_pulse);
	}
	vec4 final_color = mix(color_ink, current_line_col, pattern_val);

	// 6. Bordure au trait de plume / Rotring
	if (border_width > 0.001) {
		float border_val = eval_rotring_border(pos, size, border_width, border_roughness);
		final_color = mix(final_color, border_color, border_val);
	}

	// 7. Grain de matière (papier Canson / tirage sérigraphique)
	if (grain_intensity > 0.001) {
		float grain = (hash12(floor(pos * 0.8) + vec2(17.3, 43.1)) - 0.5) * grain_intensity;
		final_color.rgb = clamp(final_color.rgb + vec3(grain), vec3(0.0), vec3(1.0));
	}

	// 8. Sortie finale avec respect de modulate COLOR et alpha_mix
	vec4 tex_color = texture(TEXTURE, UV);
	final_color.a *= tex_color.a * COLOR.a * alpha_mix;
	final_color.rgb *= COLOR.rgb;
	COLOR = final_color;
}
