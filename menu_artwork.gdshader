shader_type canvas_item;

// =============================================================================
// SHADER D'ARTWORK DE MENU — Candela 2D
// =============================================================================
// 1. Rendu sombre par défaut & Révélation dynamique par la torche du curseur
// 2. Front d'embrasement thermique / flamme depuis un Point d'Intérêt (POI)
// 3. 12 modes d'effets vivants uniques par artwork
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

// --- Embrasement / Transition depuis le POI ---
uniform vec2 poi_pos = vec2(0.5, 0.5);
uniform float reveal_progress : hint_range(0.0, 1.2) = 1.0;
uniform float flame_width : hint_range(0.01, 0.3) = 0.08;
uniform float flame_intensity : hint_range(0.0, 3.0) = 1.5;
uniform vec3 flame_color : source_color = vec3(2.496, 1.794, 0.624); // AMBRE_INCANDESCENT

// --- Effets vivants spécifiques ---
// 0: Aucun, 1: Accueil (Flicker/Poussière), 2: Compétitif (Heartbeat/Flare),
// 3: Écran Scindé (Clash/CRT), 4: Amical (Brume/Respiration), 5: Amical Ligne (LEDs Switch),
// 6: Amical Local (CRT Phosphore), 7: Entraînement (Mire/Impacts), 8: Personnalisation (Arc 440V),
// 9: Mise à jour (Rayons porte), 10: Quitter (Braises mourantes), 11: Créer (Fusée rouge vive),
// 12: Rejoindre (Balise rouge distante), 13: Retour (Abysse)
uniform int effect_mode = 0;
uniform float effect_time = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

// --- Fonctions utilitaires procédurales rapides ---
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
	// Calcul de la distance torche en espace corrigé d'aspect
	vec2 delta_torch = (UV - torch_pos) * vec2(aspect, 1.0);
	float dist_torch = length(delta_torch);
	float torch_light = smoothstep(torch_radius, 0.0, dist_torch) * torch_intensity;
	
	// L'éclairage de base est sombre (ambient_exposure) et monte sous la torche
	float exposure = mix(ambient_exposure, 1.0, torch_light);
	vec3 base_rgb = col.rgb * exposure;
	
	// --- 3. Effets vivants par artwork ---
	vec3 effect_add = vec3(0.0);
	float t = effect_time;
	
	if (effect_mode == 1) {
		// Accueil : micro-flicker de la lampe à (0.66, 0.72) + poussière dorée
		float flicker = sin(t * 7.3) * 0.04 + sin(t * 19.1) * 0.02 + sin(t * 43.7) * 0.01;
		vec2 cone_dir = UV - vec2(0.66, 0.72);
		float cone_mask = smoothstep(0.7, 0.1, length(cone_dir * vec2(aspect, 1.0)));
		float dust = noise2d(UV * 35.0 + vec2(t * 0.05, -t * 0.08)) * noise2d(UV * 70.0 - vec2(t * 0.04, t * 0.06));
		dust = smoothstep(0.4, 0.85, dust) * cone_mask * 0.25;
		effect_add += (vec3(flicker * 0.8, flicker * 0.6, flicker * 0.2) * cone_mask) + (vec3(0.96, 0.69, 0.24) * dust);
	}
	else if (effect_mode == 2) {
		// Compétitif : Battement de cœur (tension) + flare anamorphique
		float beat = pow(max(0.0, sin(t * 3.5)), 12.0) + 0.5 * pow(max(0.0, sin(t * 3.5 + 0.35)), 16.0);
		float flare_line = smoothstep(0.03, 0.0, abs(UV.y - 0.73)) * smoothstep(0.8, 0.0, abs(UV.x - 0.65));
		effect_add += vec3(0.29, 0.72, 0.97) * (flare_line * 0.35 + beat * 0.08);
	}
	else if (effect_mode == 3) {
		// Écran scindé : Choc thermique au centre (0.5, 0.5)
		vec2 c_pos = (UV - vec2(0.5, 0.5)) * vec2(aspect, 1.0);
		float c_dist = length(c_pos);
		float clash = smoothstep(0.25, 0.0, c_dist) * (0.15 + 0.08 * sin(t * 15.0 + noise2d(UV * 20.0 + t)));
		effect_add += vec3(0.98, 0.80, 0.40) * clash;
	}
	else if (effect_mode == 4) {
		// Amical : Brume volumétrique respirante
		float mist = noise2d(UV * 6.0 + vec2(t * 0.06, -t * 0.02)) * smoothstep(0.8, 0.2, length(UV - vec2(0.5, 0.6)));
		effect_add += vec3(0.96, 0.69, 0.24) * (mist * 0.12 * (0.7 + 0.3 * sin(t * 1.5)));
	}
	else if (effect_mode == 5) {
		// Amical ligne : Diodes switch réseau clignotantes (gauche)
		if (UV.x < 0.45 && UV.y > 0.35 && UV.y < 0.65) {
			float led_grid = step(0.85, sin(UV.y * 120.0)) * step(0.85, sin(UV.x * 60.0));
			float blink = step(0.4, fract(sin(floor(UV.y * 120.0) * 45.1 + floor(UV.x * 60.0) * 17.3 + t * 4.0) * 43758.5));
			effect_add += vec3(0.38, 0.90, 0.50) * (led_grid * blink * 0.6);
		}
	}
	else if (effect_mode == 6) {
		// Amical local : Phosphore vert & scanlines CRT (écrans)
		if ((UV.x > 0.18 && UV.x < 0.35 && UV.y > 0.30 && UV.y < 0.55) ||
		    (UV.x > 0.60 && UV.x < 0.78 && UV.y > 0.28 && UV.y < 0.50)) {
			float scan = sin(UV.y * 400.0 + t * 25.0) * 0.1;
			float crt_flicker = sin(t * 50.0) * 0.03;
			effect_add += vec3(0.15, 0.50, 0.20) * (0.2 + scan + crt_flicker);
		}
	}
	else if (effect_mode == 7) {
		// Entraînement : Mire laser rouge ambre + étincelle d'impact
		vec2 target_c = vec2(0.50, 0.48);
		vec2 laser_pos = target_c + vec2(sin(t * 1.2) * 0.04, cos(t * 1.8) * 0.06);
		float dot_dist = length((UV - laser_pos) * vec2(aspect, 1.0));
		float laser_dot = smoothstep(0.008, 0.002, dot_dist);
		float spark_t = fract(t * 0.8);
		float spark = step(0.88, spark_t) * smoothstep(0.02, 0.0, length((UV - target_c) * vec2(aspect, 1.0)));
		effect_add += vec3(0.95, 0.29, 0.33) * (laser_dot * 1.5) + vec3(2.49, 1.79, 0.62) * (spark * 2.0);
	}
	else if (effect_mode == 8) {
		// Personnalisation : Tableau électrique 440V & arc
		float dial_pulse = (0.5 + 0.5 * sin(t * 2.0)) * smoothstep(0.12, 0.0, length((UV - vec2(0.57, 0.42)) * vec2(aspect, 1.0)));
		float arc = step(0.96, fract(sin(t * 8.0) * 43758.5)) * smoothstep(0.08, 0.0, length((UV - vec2(0.48, 0.44)) * vec2(aspect, 1.0)));
		effect_add += vec3(0.96, 0.69, 0.24) * (dial_pulse * 0.3) + vec3(0.4, 0.8, 1.5) * (arc * 1.2);
	}
	else if (effect_mode == 9) {
		// Mise à jour : Rayons de lumière sous la porte blindée
		if (UV.x > 0.48 && UV.x < 0.75 && UV.y > 0.20 && UV.y < 0.70) {
			float ray = sin((UV.x - UV.y * 0.4) * 40.0 + t * 0.8) * 0.5 + 0.5;
			effect_add += vec3(0.98, 0.91, 0.80) * (ray * 0.08);
		}
	}
	else if (effect_mode == 10) {
		// Quitter : Lampe au sol agonisante & braise
		vec2 lamp_c = vec2(0.50, 0.72);
		float l_dist = length((UV - lamp_c) * vec2(aspect, 1.0));
		float dying = smoothstep(0.35, 0.0, l_dist) * (0.10 + 0.08 * sin(t * 0.8) * sin(t * 3.1));
		effect_add += vec3(0.85, 0.45, 0.15) * dying;
	}
	else if (effect_mode == 11) {
		// Créer : Fusée de détresse rouge vive au sol (0.58, 0.65)
		vec2 flare_c = (UV - vec2(0.58, 0.65)) * vec2(aspect, 1.0);
		float f_dist = length(flare_c);
		float flare_glow = smoothstep(0.55, 0.0, f_dist) * (0.6 + 0.25 * sin(t * 14.0 + noise2d(UV * 15.0 + t * 4.0)));
		float smoke_col = noise2d(UV * 8.0 - vec2(0.0, t * 0.3)) * smoothstep(0.5, 0.0, abs(UV.x - 0.60)) * smoothstep(0.8, 0.2, UV.y);
		effect_add += vec3(0.95, 0.20, 0.15) * (flare_glow * 0.85) + vec3(0.55, 0.17, 0.19) * (smoke_col * 0.25);
	}
	else if (effect_mode == 12) {
		// Rejoindre : Balise rouge distante clignotante (0.58, 0.40)
		vec2 beacon_c = (UV - vec2(0.58, 0.40)) * vec2(aspect, 1.0);
		float b_dist = length(beacon_c);
		float beacon_pulse = pow(max(0.0, sin(t * 2.5)), 8.0) * smoothstep(0.35, 0.0, b_dist);
		effect_add += vec3(0.95, 0.20, 0.20) * (beacon_pulse * 0.9);
	}
	else if (effect_mode == 13) {
		// Retour : Ténèbres respirantes au centre du tunnel
		float abyss = smoothstep(0.15, 0.65, length((UV - vec2(0.5, 0.45)) * vec2(aspect, 1.0)));
		effect_add -= vec3(0.05, 0.05, 0.05) * (abyss * (0.8 + 0.2 * sin(t * 1.0)));
	}
	
	base_rgb += effect_add * effect_strength;
	
	// --- 4. Transition par Embrasement depuis le POI ---
	if (reveal_progress < 1.0) {
		vec2 delta_poi = (UV - poi_pos) * vec2(aspect, 1.0);
		float dist_poi = length(delta_poi);
		
		// Rayon maximum pour couvrir l'écran entier depuis n'importe quel point
		float max_radius = 1.45;
		float current_radius = reveal_progress * max_radius;
		
		// Bruit procédural pour rendre le front de flamme turbulent et organique
		float noise_flame = (noise2d(UV * 16.0 + effect_time * 2.0) - 0.5) * 0.06;
		float dist_turbulent = dist_poi + noise_flame;
		
		// Front d'onde de feu
		float edge_dist = abs(dist_turbulent - current_radius);
		float flame_ring = smoothstep(flame_width, 0.0, edge_dist);
		
		// Tout ce qui est encore en avant de l'onde est sombre/masqué
		float revealed = smoothstep(current_radius + flame_width * 0.5, current_radius - flame_width * 0.2, dist_turbulent);
		
		// Combustion sur le front d'onde
		vec3 flame_burst = flame_color * (flame_ring * flame_intensity);
		
		base_rgb = mix(base_rgb * 0.15, base_rgb, revealed) + flame_burst;
	}
	
	// --- 5. Application finale du flou et assombrissement de pied de page ---
	float darken_actuel = mix(k_pied * 0.85, darken, mode_flou_total);
	vec3 final_rgb = mix(base_rgb, tint.rgb, darken_actuel);
	
	COLOR = vec4(max(vec3(0.0), final_rgb), col.a);
}
