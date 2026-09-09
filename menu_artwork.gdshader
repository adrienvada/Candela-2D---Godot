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
	
	// --- 2. Rendu sombre par défaut & Révélation torche interactive ---
	vec2 delta_torch = (UV - torch_pos) * vec2(aspect, 1.0);
	float dist_torch = length(delta_torch);
	float torch_light = smoothstep(torch_radius, 0.0, dist_torch) * torch_intensity;
	
	// Les hautes lumières du dessin percent naturellement la pénombre
	float luma = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
	float breakthrough = smoothstep(0.35, 0.75, luma) * 0.30;
	
	float exposure = mix(ambient_exposure + breakthrough, 1.0, torch_light);
	vec3 base_rgb = col.rgb * exposure;
	
	// --- 3. Isolation pure des zones claires dessinées (Luma-Keying) ---
	// Seuls les pixels portant déjà du dessin lumineux reçoivent l'effet vivant.
	// L'encre noire, les ombres profondes et le béton sombre reçoivent 0.0.
	float k_highlight = smoothstep(0.22, 0.65, luma);
	
	vec3 effect_color = vec3(0.0);
	float effect_boost = 0.0;
	float t = effect_time;
	
	if (effect_mode == 1) {
		// Accueil : Respiration dorée sur le panneau ARENA et le faisceau
		float breathe = 0.85 + 0.25 * sin(t * 2.2);
		effect_color = vec3(0.98, 0.80, 0.40) * (breathe * 0.35);
		effect_boost = (breathe - 0.85) * 0.40;
	}
	else if (effect_mode == 2) {
		// Compétitif : Diodes cyan et étincelles froides sur les zones claires
		float spark = step(0.85, fract(sin(dot(UV * 50.0, vec2(12.9898, 78.233)) + t * 4.0) * 43758.5453));
		float pulse = 0.75 + 0.25 * sin(t * 3.5 + sin(t * 8.0) * 0.6);
		effect_color = vec3(0.25, 0.80, 1.0) * (pulse * 0.35 + spark * 0.40);
		effect_boost = (pulse - 0.75) * 0.50;
	}
	else if (effect_mode == 3) {
		// Écran scindé : Balancement ambre à gauche et bleu froid à droite
		float is_right = smoothstep(0.48, 0.52, UV.x);
		float pulse_l = 0.80 + 0.20 * sin(t * 2.5);
		float pulse_r = 0.80 + 0.20 * cos(t * 2.8);
		vec3 col_l = vec3(0.98, 0.78, 0.40) * (pulse_l * 0.35);
		vec3 col_r = vec3(0.35, 0.75, 1.00) * (pulse_r * 0.35);
		effect_color = mix(col_l, col_r, is_right);
		effect_boost = mix(pulse_l - 0.80, pulse_r - 0.80, is_right) * 0.45;
	}
	else if (effect_mode == 4) {
		// Amical : Respiration ambrée chaude sur les silhouettes et le pilier
		float pulse = 0.80 + 0.20 * sin(t * 1.8);
		effect_color = vec3(0.98, 0.75, 0.35) * (pulse * 0.30);
		effect_boost = (pulse - 0.80) * 0.35;
	}
	else if (effect_mode == 5) {
		// Amical Ligne : Scintillement des diodes LED cyan des serveurs
		float led_flicker = 0.70 + 0.30 * sin(t * 6.0 + sin(t * 14.0));
		effect_color = vec3(0.20, 0.88, 1.0) * (led_flicker * 0.45);
		effect_boost = (led_flicker - 0.70) * 0.60;
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
		// Les rayons dessinés pulsent de l'intérieur avec une intensité éclatante
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
