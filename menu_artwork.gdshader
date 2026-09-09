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
		// Accueil : Lueur ambre diffuse sur le panneau ARENA (0.62, 0.25) et poussières d'or flottantes
		float sign_glow = smoothstep(0.45, 0.0, length((UV - vec2(0.62, 0.25)) * vec2(aspect * 0.7, 1.0)));
		float dust1 = noise2d(UV * 30.0 + vec2(t * 0.05, -t * 0.08));
		float dust2 = noise2d(UV * 60.0 - vec2(t * 0.04, t * 0.06));
		float dust = smoothstep(0.40, 0.75, dust1 * dust2) * sign_glow * 0.35;
		float breathe = 0.75 + 0.25 * sin(t * 2.2);
		effect_add += vec3(0.98, 0.80, 0.40) * (sign_glow * 0.16 * breathe + dust);
	}
	else if (effect_mode == 2) {
		// Compétitif : Tableau électrique froid à gauche (0.18, 0.35) & brume couloir
		float panel_mask = smooth_box(UV, vec2(0.18, 0.35), vec2(0.11, 0.28), 0.04);
		float meters_glow = smooth_box(UV, vec2(0.18, 0.32), vec2(0.08, 0.18), 0.015);
		float meter_pulse = 0.65 + 0.35 * sin(t * 3.5 + sin(t * 8.0) * 0.6);
		float spark = step(0.88, noise2d(UV * 40.0 + vec2(t * 3.0, -t * 4.0))) * panel_mask;
		float mist = noise2d(UV * 6.0 + vec2(t * 0.08, -t * 0.04)) * smoothstep(0.65, 0.0, length(UV - vec2(0.65, 0.55)));
		effect_add += vec3(0.20, 0.75, 1.0) * (panel_mask * 0.10 + meters_glow * 0.40 * meter_pulse + spark * 0.30 + mist * 0.18);
	}
	else if (effect_mode == 3) {
		// Écran scindé : Faisceaux croisés gauche (0.20, 0.55) et droite (0.75, 0.45)
		vec2 p_left = UV - vec2(0.20, 0.55);
		vec2 p_right = UV - vec2(0.75, 0.45);
		float beam_l = smoothstep(0.40, 0.0, length(p_left * vec2(aspect * 0.7, 1.0)));
		float beam_r = smoothstep(0.40, 0.0, length(p_right * vec2(aspect * 0.7, 1.0)));
		float dust_l = smoothstep(0.45, 0.80, noise2d(UV * 25.0 + vec2(t * 0.06, -t * 0.08))) * beam_l * 0.25;
		float dust_r = smoothstep(0.45, 0.80, noise2d(UV * 25.0 - vec2(t * 0.06, t * 0.08))) * beam_r * 0.25;
		float breathe_l = 0.80 + 0.20 * sin(t * 2.5);
		float breathe_r = 0.80 + 0.20 * cos(t * 2.8);
		effect_add += vec3(0.98, 0.78, 0.40) * (beam_l * 0.15 * breathe_l + dust_l);
		effect_add += vec3(0.35, 0.70, 1.00) * (beam_r * 0.15 * breathe_r + dust_r);
	}
	else if (effect_mode == 4) {
		// Amical : Brume volumétrique chaude et poussières autour du pilier ZONE 4 (0.48, 0.40)
		float center_haze = smoothstep(0.65, 0.1, length((UV - vec2(0.48, 0.40)) * vec2(aspect * 0.8, 1.0)));
		float mist = noise2d(UV * 7.0 + vec2(t * 0.07, -t * 0.05)) * center_haze;
		float dust = smoothstep(0.50, 0.85, noise2d(UV * 35.0 + vec2(t * 0.04, -t * 0.06))) * center_haze * 0.30;
		float slow_pulse = 0.75 + 0.25 * sin(t * 1.8);
		effect_add += vec3(0.98, 0.75, 0.32) * (mist * 0.22 * slow_pulse + dust);
	}
	else if (effect_mode == 5) {
		// Amical Ligne : Baies serveurs (gauche 0.12, droite 0.88), diodes cyan scintillantes
		float led_racks_r = smooth_box(UV, vec2(0.88, 0.45), vec2(0.10, 0.40), 0.05);
		float led_racks_l = smooth_box(UV, vec2(0.12, 0.45), vec2(0.10, 0.40), 0.05);
		float spark_r = noise2d(UV * 45.0 + vec2(0.0, t * 3.5));
		float spark_l = noise2d(UV * 45.0 - vec2(0.0, t * 4.0));
		float led_pulse_r = smoothstep(0.50, 0.85, spark_r) * (0.6 + 0.4 * sin(t * 6.0));
		float led_pulse_l = smoothstep(0.50, 0.85, spark_l) * (0.6 + 0.4 * sin(t * 7.0 + 1.5));
		
		vec2 to_uv = UV - vec2(0.55, 0.50);
		float beam_mask = smoothstep(0.55, 0.0, length(to_uv * vec2(aspect * 0.7, 1.0)));
		float dust = smoothstep(0.45, 0.80, noise2d(UV * 30.0 + vec2(t * 0.05, -t * 0.07))) * beam_mask * 0.25;
		
		vec3 col_cyan = vec3(0.20, 0.85, 0.98);
		effect_add += col_cyan * (led_racks_r * 0.40 * led_pulse_r + led_racks_l * 0.40 * led_pulse_l + dust);
	}
	else if (effect_mode == 6) {
		// Amical Local : Phosphore vert des écrans CRT (0.25, 0.40) & balayage
		float crt_bank = smooth_box(UV, vec2(0.25, 0.40), vec2(0.20, 0.25), 0.05);
		float crt_scan = 0.80 + 0.20 * sin(UV.y * 350.0 + t * 20.0);
		float crt_flicker = 0.85 + 0.15 * sin(t * 5.5 + sin(t * 15.0));
		float green_glow = smoothstep(0.60, 0.0, length((UV - vec2(0.25, 0.40)) * vec2(aspect * 0.8, 1.0)));
		
		vec3 col_green = vec3(0.25, 0.98, 0.45);
		effect_add += col_green * (crt_bank * 0.35 * crt_scan * crt_flicker + green_glow * 0.14);
	}
	else if (effect_mode == 7) {
		// Entraînement : Projecteur au plafond (0.80, 0.08) éclairant la cible (0.82, 0.50)
		vec2 to_target = UV - vec2(0.82, 0.50);
		float beam_mask = smoothstep(0.48, 0.0, length(to_target * vec2(aspect * 0.7, 1.0)));
		float dust = smoothstep(0.40, 0.75, noise2d(UV * 35.0 + vec2(t * 0.06, -t * 0.09))) * beam_mask * 0.30;
		float spot_pulse = 0.82 + 0.18 * sin(t * 2.2);
		effect_add += vec3(0.98, 0.88, 0.65) * (beam_mask * 0.14 * spot_pulse + dust);
	}
	else if (effect_mode == 8) {
		// Personnalisation : Lampe d'établi ambrée (0.45, 0.20) & cadrans (0.22, 0.25)
		float lamp_cone = smoothstep(0.52, 0.0, length((UV - vec2(0.55, 0.60)) * vec2(aspect * 0.8, 1.0)));
		float dials_glow = smooth_box(UV, vec2(0.22, 0.25), vec2(0.12, 0.15), 0.03);
		float filament_flicker = 0.88 + 0.12 * sin(t * 8.0 + sin(t * 22.0));
		float dust = smoothstep(0.45, 0.80, noise2d(UV * 40.0 + vec2(t * 0.04, -t * 0.06))) * lamp_cone * 0.25;
		
		effect_add += vec3(0.98, 0.78, 0.35) * (lamp_cone * 0.18 * filament_flicker + dials_glow * 0.12 + dust);
	}
	else if (effect_mode == 9) {
		// Mise à jour : Rayons d'or éclatants sortant de la chambre forte (0.62, 0.45)
		float breach = smoothstep(0.55, 0.0, length((UV - vec2(0.62, 0.45)) * vec2(aspect * 0.5, 1.0)));
		float rays = noise2d(UV * 10.0 + vec2(t * 0.10, -t * 0.06)) * breach;
		float dust = smoothstep(0.40, 0.75, noise2d(UV * 40.0 + vec2(t * 0.08, -t * 0.12))) * breach * 0.35;
		float pulse = 0.75 + 0.25 * sin(t * 2.5);
		effect_add += vec3(1.0, 0.86, 0.40) * (breach * 0.25 * pulse + rays * 0.28 + dust);
	}
	else if (effect_mode == 10) {
		// Quitter : Lampe au sol (0.35, 0.80) & faisceau rasant la flaque de sang (0.65, 0.80)
		float lamp_ground = smoothstep(0.42, 0.0, length((UV - vec2(0.45, 0.78)) * vec2(aspect * 0.8, 1.0)));
		float dying_pulse = 0.70 + 0.30 * sin(t * 2.0 + sin(t * 9.0) * 0.4);
		float spark = step(0.92, noise2d(UV * 50.0 + vec2(t * 5.0, 0.0))) * lamp_ground * 0.3;
		effect_add += vec3(0.95, 0.68, 0.32) * (lamp_ground * 0.18 * dying_pulse + spark);
	}
	else if (effect_mode == 11) {
		// Créer Ligne : Fusée de détresse rouge au sol (0.42, 0.65) & fumée dense
		float flare_center = smoothstep(0.45, 0.0, length((UV - vec2(0.42, 0.65)) * vec2(aspect * 0.8, 1.0)));
		float smoke = noise2d(UV * 7.0 + vec2(t * 0.10, -t * 0.14)) * smoothstep(0.65, 0.1, length(UV - vec2(0.65, 0.40)));
		float flare_pulse = 0.75 + 0.25 * sin(t * 10.0 + sin(t * 25.0));
		effect_add += vec3(1.0, 0.22, 0.18) * (flare_center * 0.30 * flare_pulse + smoke * 0.24);
	}
	else if (effect_mode == 12) {
		// Créer Local : Écran CRT ambre-vert de la console (0.78, 0.35) & balayage
		float crt_box = smooth_box(UV, vec2(0.78, 0.35), vec2(0.12, 0.12), 0.03);
		float crt_scan = 0.82 + 0.18 * sin(UV.y * 360.0 + t * 18.0);
		float crt_pulse = 0.80 + 0.20 * sin(t * 4.0 + sin(t * 14.0));
		float crt_halo = smoothstep(0.45, 0.0, length((UV - vec2(0.78, 0.35)) * vec2(aspect * 0.8, 1.0)));
		
		vec3 col_amber_green = vec3(0.88, 0.95, 0.35);
		effect_add += col_amber_green * (crt_box * 0.40 * crt_scan * crt_pulse + crt_halo * 0.15);
	}
	else if (effect_mode == 13) {
		// Rejoindre Ligne : Balise radio bleue au fond du couloir (0.41, 0.35)
		float beacon_pt = smoothstep(0.38, 0.0, length((UV - vec2(0.41, 0.35)) * vec2(aspect, 1.0)));
		float beacon_flash = pow(max(0.0, sin(t * 3.5)), 4.0);
		float mist = noise2d(UV * 8.0 + vec2(t * 0.06, -t * 0.04)) * beacon_pt;
		vec3 col_blue = vec3(0.20, 0.75, 1.0);
		effect_add += col_blue * (beacon_pt * 0.45 * (0.4 + 0.6 * beacon_flash) + mist * 0.20);
	}
	else if (effect_mode == 14) {
		// Rejoindre Local : Voyant d'autorisation vert émeraude au-dessus du sas (0.72, 0.10)
		float green_lamp = smoothstep(0.32, 0.0, length((UV - vec2(0.72, 0.10)) * vec2(aspect * 0.8, 1.0)));
		float lamp_pulse = 0.80 + 0.20 * sin(t * 3.0);
		float green_cone = smoothstep(0.58, 0.0, length((UV - vec2(0.72, 0.35)) * vec2(aspect * 0.7, 1.0)));
		
		vec3 col_emerald = vec3(0.25, 1.0, 0.50);
		effect_add += col_emerald * (green_lamp * 0.45 * lamp_pulse + green_cone * 0.15);
	}
	else if (effect_mode == 15) {
		// Retour : Faisceau plongeant dans l'abysse de l'escalier en colimaçon (0.50, 0.50)
		float abyss_cone = smoothstep(0.52, 0.0, length((UV - vec2(0.50, 0.50)) * vec2(aspect * 0.8, 1.0)));
		float dust = smoothstep(0.40, 0.80, noise2d(UV * 35.0 + vec2(t * 0.03, t * 0.07))) * abyss_cone * 0.25;
		float slow_glow = 0.80 + 0.20 * sin(t * 2.0);
		effect_add += vec3(0.98, 0.80, 0.40) * (abyss_cone * 0.14 * slow_glow + dust);
	}
	else {
		// Ambiance douce par défaut
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
