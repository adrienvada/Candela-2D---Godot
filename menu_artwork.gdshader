shader_type canvas_item;

// =============================================================================
// SHADER D'ARTWORK DE MENU — Candela 2D
// =============================================================================
// 1. Rendu sombre par défaut & Révélation dynamique par la torche du curseur
// 2. Transition de fondu doux et organique
// 3. Effets vivants d'ambiance calés avec précision sur les éléments réels :
//    - Terminaux CRT & phosphore vert
//    - Baies réseau, câbles et diodes LED
//    - Cadrans électriques, voltmètres et voyants
//    - Halos de poussières et brumes volumétriques lentes
//    - Lueur diffuse des fusées de détresse
// 4. Mode flou d'arrière-plan pour les panneaux interactifs
// =============================================================================

// --- Flou d'arrière-plan pour panneaux interactifs ---
uniform float mode_flou_total : hint_range(0.0, 1.0) = 0.0;
uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;
uniform float darken : hint_range(0.0, 1.0) = 0.70;
uniform vec4 tint : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform float pied_debut : hint_range(0.0, 1.0) = 0.55;
uniform float pied_fin : hint_range(0.0, 1.0) = 0.88;

// --- Sombre par défaut & Torche interactive ---
uniform float ambient_exposure : hint_range(0.0, 1.0) = 0.28;
uniform vec2 torch_pos = vec2(0.5, 0.5);
uniform float torch_radius : hint_range(0.0, 1.5) = 0.45;
uniform float torch_intensity : hint_range(0.0, 2.0) = 1.0;

// --- Transition de fondu doux (0.0 = masqué, 1.0 = pleinement révélé) ---
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;

// --- Effets vivants spécifiques ---
// 0: Aucun, 1: Accueil (Poussière dorée & torche), 2: Compétitif (Tableau électrique froid & brume),
// 3: Écran Scindé (Faisceaux croisés & poussières), 4: Amical (Brume volumétrique),
// 5: Amical Ligne (Diodes boîtiers réseau & câbles), 6: Amical Local (Écrans CRT phosphore & baie),
// 7: Entraînement (Cible bois & poussière), 8: Personnalisation (Cadrans 440V & voyants),
// 9: Mise à jour (Lumière de brèche porte), 10: Quitter (Torche au sol & braise),
// 11: Créer Ligne (Fusée rouge diffuse & fumée), 12: Créer Local (Fusée sol droite & écrans CRT),
// 13: Rejoindre Ligne (Balise lointaine & diodes câbles), 14: Rejoindre Local (Balise & borne CRT),
// 15: Retour (Abysse couloir)
uniform int effect_mode = 0;
uniform float effect_time = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

// --- Utilitaires de bruit et formes géométriques lissées ---
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Boîte rectangulaire adoucie
float smooth_box(vec2 p, vec2 center, vec2 half_size, float edge) {
	vec2 d = abs(p - center) - half_size;
	return smoothstep(edge, -edge, max(d.x, d.y));
}

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	float aspect = tex_size.x / max(tex_size.y, 1.0);
	
	// --- 1. Échantillonnage avec flou conditionnel ---
	float k_pied = smoothstep(pied_debut, pied_fin, UV.y);
	float k_effet_flou = mix(k_pied * 0.35, 1.0, mode_flou_total);
	float blur_actuel = blur_amount * k_effet_flou;
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
	
	// --- 2. Rendu sombre par défaut & Révélation torche ---
	vec2 delta_torch = (UV - torch_pos) * vec2(aspect, 1.0);
	float dist_torch = length(delta_torch);
	float torch_light = smoothstep(torch_radius, 0.0, dist_torch) * torch_intensity;
	
	float exposure = mix(ambient_exposure, 1.0, torch_light);
	vec3 base_rgb = col.rgb * exposure;
	
	// --- 3. Effets vivants d'ambiance (lueurs diffuses, sporadiques, calées) ---
	vec3 effect_add = vec3(0.0);
	float t = effect_time;
	
	if (effect_mode == 1) {
		// Accueil : Lueur ambre diffuse sur le pilier central + poussières flottantes
		float pillar_glow = smoothstep(0.45, 0.0, length((UV - vec2(0.50, 0.45)) * vec2(aspect * 0.6, 1.0)));
		float dust = noise2d(UV * 25.0 + vec2(t * 0.03, -t * 0.05)) * noise2d(UV * 50.0 - vec2(t * 0.02, t * 0.04));
		dust = smoothstep(0.45, 0.80, dust) * pillar_glow * 0.18;
		float breathe = 0.85 + 0.15 * sin(t * 1.8);
		effect_add += vec3(0.96, 0.75, 0.35) * (pillar_glow * 0.08 * breathe + dust);
	}
	else if (effect_mode == 2) {
		// Compétitif : Tableau électrique froid à gauche (0.29, 0.42) & brume couloir
		float panel_mask = smooth_box(UV, vec2(0.295, 0.425), vec2(0.105, 0.275), 0.04);
		float meters_glow = smooth_box(UV, vec2(0.370, 0.320), vec2(0.025, 0.080), 0.015);
		float meter_pulse = 0.8 + 0.2 * sin(t * 2.2 + sin(t * 5.0) * 0.3);
		float mist = noise2d(UV * 5.0 + vec2(t * 0.04, -t * 0.02)) * smoothstep(0.6, 0.0, length(UV - vec2(0.63, 0.48)));
		effect_add += vec3(0.25, 0.65, 0.95) * (panel_mask * 0.06 + meters_glow * 0.25 * meter_pulse + mist * 0.10);
	}
	else if (effect_mode == 3) {
		// Écran scindé : Faisceaux croisés gauche (0.28, 0.41) et droite (0.72, 0.43)
		vec2 p_left = UV - vec2(0.28, 0.41);
		vec2 p_right = UV - vec2(0.72, 0.43);
		float beam_l = smoothstep(0.35, 0.0, length(p_left * vec2(aspect * 0.7, 1.0)));
		float beam_r = smoothstep(0.35, 0.0, length(p_right * vec2(aspect * 0.7, 1.0)));
		float dust_l = noise2d(UV * 20.0 + vec2(t * 0.03, -t * 0.04)) * beam_l;
		float dust_r = noise2d(UV * 20.0 - vec2(t * 0.03, t * 0.04)) * beam_r;
		float breathe_l = 0.9 + 0.1 * sin(t * 2.0);
		float breathe_r = 0.9 + 0.1 * cos(t * 2.3);
		effect_add += vec3(0.96, 0.78, 0.40) * (beam_l * 0.08 * breathe_l + beam_r * 0.08 * breathe_r + (dust_l + dust_r) * 0.12);
	}
	else if (effect_mode == 4) {
		// Amical : Brume volumétrique chaude et poussières dans le faisceau
		float center_haze = smoothstep(0.7, 0.1, length((UV - vec2(0.50, 0.50)) * vec2(aspect * 0.8, 1.0)));
		float mist = noise2d(UV * 7.0 + vec2(t * 0.04, -t * 0.02)) * center_haze;
		float slow_pulse = 0.85 + 0.15 * sin(t * 1.4);
		effect_add += vec3(0.95, 0.70, 0.28) * (mist * 0.15 * slow_pulse);
	}
	else if (effect_mode == 5 || effect_mode == 8) {
		// Baies Serveurs / Personnalisation : Diodes cyan scintillantes et poussières dans le faisceau
		float led_racks_r = smooth_box(UV, vec2(0.85, 0.45), vec2(0.12, 0.35), 0.05);
		float led_racks_l = smooth_box(UV, vec2(0.10, 0.45), vec2(0.08, 0.35), 0.05);
		float spark_r = noise2d(UV * 40.0 + vec2(0.0, t * 2.0));
		float spark_l = noise2d(UV * 40.0 - vec2(0.0, t * 2.5));
		float led_pulse_r = smoothstep(0.60, 0.90, spark_r) * (0.7 + 0.3 * sin(t * 5.0));
		float led_pulse_l = smoothstep(0.60, 0.90, spark_l) * (0.7 + 0.3 * sin(t * 6.0 + 1.5));
		
		vec2 to_uv = UV - vec2(0.55, 0.42);
		float beam_mask = smoothstep(0.55, 0.0, length(to_uv * vec2(aspect * 0.7, 1.0)));
		float dust = noise2d(UV * 30.0 + vec2(t * 0.03, -t * 0.05)) * beam_mask * 0.16;
		
		vec3 col_cyan = vec3(0.20, 0.85, 0.95);
		effect_add += col_cyan * (led_racks_r * 0.25 * led_pulse_r + led_racks_l * 0.25 * led_pulse_l + dust);
	}
	else if (effect_mode == 6) {
		// Amical Local : Poussières ambrées dans l'arène Zone 4
		float beam_spot = smoothstep(0.40, 0.0, length((UV - vec2(0.70, 0.60)) * vec2(aspect * 0.8, 1.0)));
		float dust = noise2d(UV * 28.0 + vec2(t * 0.03, -t * 0.05)) * beam_spot * 0.16;
		float slow_pulse = 0.88 + 0.12 * sin(t * 1.6);
		effect_add += vec3(0.98, 0.78, 0.35) * (beam_spot * 0.06 * slow_pulse + dust);
	}
	else if (effect_mode == 7) {
		// Entraînement : Faisceau de torche blanc-or découpant la pénombre
		vec2 to_uv = UV - vec2(0.42, 0.58);
		float beam_mask = smoothstep(0.45, 0.0, length(to_uv * vec2(aspect * 0.7, 1.0)));
		float dust = noise2d(UV * 30.0 + vec2(t * 0.03, -t * 0.05)) * beam_mask * 0.18;
		effect_add += vec3(0.98, 0.88, 0.65) * dust;
	}
	else if (effect_mode == 9) {
		// Mise à jour : Rayon d'or éclatant sortant de la chambre forte (0.46, 0.50)
		float breach = smoothstep(0.50, 0.0, length((UV - vec2(0.46, 0.50)) * vec2(aspect * 0.5, 1.0)));
		float rays = noise2d(UV * 8.0 + vec2(t * 0.05, -t * 0.03)) * breach;
		float slow_glow = 0.88 + 0.12 * sin(t * 1.5);
		effect_add += vec3(0.98, 0.82, 0.35) * (breach * 0.10 * slow_glow + rays * 0.15);
	}
	else if (effect_mode == 10) {
		// Quitter : Braise mourante dans le hall
		float lamp_ground = smoothstep(0.45, 0.0, length((UV - vec2(0.35, 0.65)) * vec2(aspect, 1.0)));
		float dying_pulse = 0.85 + 0.15 * sin(t * 1.2);
		effect_add += vec3(0.90, 0.60, 0.25) * (lamp_ground * 0.08 * dying_pulse);
	}
	else if (effect_mode >= 11) {
		// Autres sous-menus : Ambiance douce adaptée
		float center_haze = smoothstep(0.65, 0.1, length((UV - vec2(0.50, 0.50)) * vec2(aspect * 0.8, 1.0)));
		float dust = noise2d(UV * 25.0 + vec2(t * 0.03, -t * 0.04)) * center_haze * 0.12;
		effect_add += vec3(0.90, 0.75, 0.40) * dust;
	}
	
	base_rgb += effect_add * effect_strength;
	
	// --- 4. Transition de fondu doux et organique ---
	base_rgb *= smoothstep(0.0, 1.0, reveal_progress);
	
	// --- 5. Application finale du flou et assombrissement de pied de page ---
	float darken_actuel = mix(k_pied * 0.85, darken, mode_flou_total);
	vec3 final_rgb = mix(base_rgb, tint.rgb, darken_actuel);
	
	COLOR = vec4(max(vec3(0.0), final_rgb), col.a);
}
