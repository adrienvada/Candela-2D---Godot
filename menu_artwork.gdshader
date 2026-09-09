shader_type canvas_item;

// =============================================================================
// SHADER D'ARTWORK DE MENU — Candela 2D (Style Roman Graphique Brutaliste)
// =============================================================================
// 1. Rendu sombre par défaut & Révélation dynamique par la torche du curseur
// 2. Transition de fondu doux et organique
// 3. Effets vivants d'ambiance STRICTEMENT asservis à la luminance du dessin
//    (Luma-Keying) : les traits d'encre noire et le béton brut ne sont JAMAIS
//    bavés ni dénaturés par des formes géométriques procédurales.
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

// --- Effets vivants spécifiques (asservis au dessin) ---
uniform int effect_mode = 0;
uniform float effect_time = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

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
	
	// Percée éclatante des hautes lumières du dessin (faisceaux, lampes, néons)
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float highlight_breakthrough = smoothstep(0.35, 0.78, luma);
	
	float exposure = mix(mix(ambient_exposure, 1.0, highlight_breakthrough), 1.0, torch_light);
	vec3 base_rgb = col.rgb * exposure;
	
	// --- 3. Effets vivants d'ambiance — LUMA-KEYED (zéro boîte ni masque procédural) ---
	// Seules les zones claires du dessin sont modulées en intensité et en teinte.
	float k_highlight = smoothstep(0.20, 0.65, luma);
	vec3 effect_color = vec3(0.0);
	float effect_boost = 0.0;
	float t = effect_time;
	
	if (effect_mode == 1) {
		// Accueil : Scintillement chaud de l'enseigne ARENA et de la lampe
		float pulse = 0.80 + 0.20 * sin(t * 2.5);
		effect_color = vec3(0.98, 0.82, 0.40) * (pulse * 0.35);
		effect_boost = (pulse - 0.80) * 0.40;
	}
	else if (effect_mode == 2) {
		// Compétitif : Éclats électriques froids et diodes cyan sur l'armoire
		float electric = 0.80 + 0.20 * sin(t * 4.0 + sin(t * 11.0) * 0.5);
		effect_color = vec3(0.20, 0.80, 1.0) * (electric * 0.40);
		effect_boost = (electric - 0.80) * 0.50;
	}
	else if (effect_mode == 3) {
		// Écran Scindé : Affrontement lumineux bi-ton ambre et bleu
		float pulse_ab = 0.80 + 0.20 * sin(t * 2.2);
		effect_color = vec3(0.85, 0.88, 1.0) * (pulse_ab * 0.35);
		effect_boost = (pulse_ab - 0.80) * 0.45;
	}
	else if (effect_mode == 4) {
		// Amical : Lueur ambrée respirante autour des combattants
		float breathe = 0.82 + 0.18 * sin(t * 1.8);
		effect_color = vec3(0.98, 0.78, 0.35) * (breathe * 0.30);
		effect_boost = (breathe - 0.82) * 0.35;
	}
	else if (effect_mode == 5) {
		// Amical Ligne : Scintillement des diodes de baies réseau
		float network = 0.80 + 0.20 * sin(t * 6.0 + sin(t * 18.0) * 0.4);
		effect_color = vec3(0.20, 0.85, 1.0) * (network * 0.40);
		effect_boost = (network - 0.80) * 0.50;
	}
	else if (effect_mode == 6) {
		// Amical Local : Phosphore vert cathodique & balayage sur les écrans CRT
		float scan = 0.85 + 0.15 * sin(UV.y * 360.0 + t * 18.0);
		float crt_flicker = 0.80 + 0.20 * sin(t * 5.0 + sin(t * 12.0));
		effect_color = vec3(0.25, 1.0, 0.45) * (scan * crt_flicker * 0.45);
		effect_boost = (crt_flicker - 0.80) * 0.50;
	}
	else if (effect_mode == 7) {
		// Entraînement : Projecteur industriel et éclats d'impacts sur la cible
		float lamp_vibe = 0.82 + 0.18 * sin(t * 3.0);
		effect_color = vec3(1.0, 0.88, 0.65) * (lamp_vibe * 0.35);
		effect_boost = (lamp_vibe - 0.82) * 0.40;
	}
	else if (effect_mode == 8) {
		// Personnalisation : Filament d'atelier et reflets ambrés sur les pièces
		float filament = 0.85 + 0.15 * sin(t * 7.0 + sin(t * 19.0));
		effect_color = vec3(0.98, 0.78, 0.35) * (filament * 0.35);
		effect_boost = (filament - 0.85) * 0.40;
	}
	else if (effect_mode == 9) {
		// Mise à jour : Énergie solaire dorée pure jaillissant des rayons de VAULT 07
		float vault_pulse = 0.80 + 0.35 * sin(t * 2.5);
		effect_color = vec3(1.0, 0.88, 0.42) * (vault_pulse * 0.55);
		effect_boost = (vault_pulse - 0.80) * 0.75;
	}
	else if (effect_mode == 10) {
		// Quitter : Lampe au sol vacillante en fin de batterie
		float dying = 0.65 + 0.35 * sin(t * 2.0 + sin(t * 11.0) * 0.5);
		effect_color = vec3(0.95, 0.68, 0.32) * (dying * 0.35);
		effect_boost = (dying - 0.65) * 0.40;
	}
	else if (effect_mode == 11) {
		// Créer Ligne : Incandescence vive et pulsations rouges de la fusée
		float flare = 0.75 + 0.25 * sin(t * 9.0 + sin(t * 23.0));
		effect_color = vec3(1.0, 0.25, 0.18) * (flare * 0.50);
		effect_boost = (flare - 0.75) * 0.65;
	}
	else if (effect_mode == 12) {
		// Créer Local : Écran CRT ambre-vert de la console
		float crt = 0.80 + 0.20 * sin(UV.y * 360.0 + t * 16.0);
		effect_color = vec3(0.88, 0.95, 0.35) * (crt * 0.45);
		effect_boost = (crt - 0.80) * 0.50;
	}
	else if (effect_mode == 13) {
		// Rejoindre Ligne : Balise radio bleue au fond du couloir
		float flash = pow(max(0.0, sin(t * 3.5)), 4.0);
		effect_color = vec3(0.20, 0.75, 1.0) * (0.35 + 0.55 * flash);
		effect_boost = flash * 0.70;
	}
	else if (effect_mode == 14) {
		// Rejoindre Local : Voyant d'autorisation vert émeraude du sas
		float beacon = 0.75 + 0.25 * sin(t * 3.0);
		effect_color = vec3(0.25, 1.0, 0.50) * (beacon * 0.45);
		effect_boost = (beacon - 0.75) * 0.55;
	}
	else if (effect_mode == 15) {
		// Retour : Faisceau d'or plongeant dans l'escalier en colimaçon
		float descend = 0.80 + 0.20 * sin(t * 2.0);
		effect_color = vec3(0.98, 0.80, 0.40) * (descend * 0.35);
		effect_boost = (descend - 0.80) * 0.40;
	}
	
	// Application strictement asservie à la luminance du dessin
	vec3 effect_add = effect_color * k_highlight * effect_strength;
	base_rgb = base_rgb * (1.0 + effect_boost * k_highlight * effect_strength) + effect_add;
	
	// --- 4. Transition de fondu doux et organique ---
	base_rgb *= smoothstep(0.0, 1.0, reveal_progress);
	
	// --- 5. Application finale du flou et assombrissement de pied de page ---
	float darken_actuel = mix(k_pied * 0.85, darken, mode_flou_total);
	vec3 final_rgb = mix(base_rgb, tint.rgb, darken_actuel);
	
	COLOR = vec4(max(vec3(0.0), final_rgb), col.a);
}
