// Le sol de la vue isométrique, habillé (ISO7, ISO7b) : la lightmap projetée, passée à la pâte, fois la
// matière du sol — en DALLES, pas en quadrillage.
//
// Successeur de `sol_projete.gdshader` (ISO1), formule pour formule, plus des FACTEURS en valeur affichée
// (`pate_facteur`) : la matière `texture_sol` (niveau de gris accroché aux coordonnées du MONDE), et —
// ISO7b — la neutralisation de la trame de 35 px peinte dans la lightmap, remplacée par des dalles.
// **Voie (b) du brief ISO7** (voir ROADMAP, section ISO7) : la lumière reste celle que la vue de dessus
// rend, et la 3D la multiplie par sa matière.
//
// ## ISO7b — des dalles, pas une grille
//
// La lightmap porte le sol de la vue de dessus : un damier à deux tons (0,148 et 0,178, `CandelaTileSet`,
// `(x + y) % 2`) et un joint d'encre d'un pixel sur les quatre bords de chaque tuile. Projeté en iso, il se
// lit comme un quadrillage au pas de la tuile — la planche E1 du DA montre de larges dalles. Ici :
// - **le joint de 35 px** est enjambé : un fragment tombé sur le joint lit la lightmap `joint_2d_px + 0,5` px
//   plus loin, vers le centre de sa tuile. La lumière lue est celle d'un point à 2 px — aucune lumière n'est
//   inventée, un point noir reste noir ;
// - **le damier** est ramené au ton sombre AVANT la pâte (`lightmap_pateuse_sol`) : la case claire est
//   ASSOMBRIE de `(ton_a / ton_b)^ton_exposant`, jamais la sombre éclaircie ;
// - **les dalles** tombent tous les `dalle_px` (deux tuiles), avec un joint fin qui garde `joint_dalle_reste`
//   de la lumière. Leur pas tombe sur un joint de tuile sur deux : la référence spatiale du joueur reste une
//   grille, deux fois plus large.
//
// ⚠️ `unshaded`, et ce n'est pas une facilité : un sol Lambert éteint le cône d'une torche rasante
// (piège du 2026-09-13). Il n'y a rien à éclairer ici — la lumière EST la lightmap. Aucune Light3D.
//
// ISO2 : un sol PAR JOUEUR (`Sol1` sur la couche 3D 2, `Sol2` sur la 4), chacun ne voyant que la
// caméra de son joueur ; la lightmap se choisit par cette caméra. La matière et les dalles, elles, ne lisent
// que le monde : identiques dans les deux vues.
//
// Défauts : force 0, dalles éteintes — le sol d'ISO1 exactement.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform sampler2D texture_sol : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float periode_sol_px = 140.0;
uniform float force_matiere : hint_range(0.0, 1.0) = 0.0;
// ISO7, étape 6 — la teinte chaude de la lumière neutre, luminance gardée (`pate_temperature`).
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
// ISO7b — la température graduée par la luminance affichée (chaude au bord du bain, neutre au centre).
uniform float temperature_seuil_bas : hint_range(0.0, 1.0) = 0.0;
uniform float temperature_seuil_haut : hint_range(0.0, 1.0) = 0.0;
// ISO7b — 1 : la neutralité qui dose la chaleur se lit sur la lightmap AVANT la pâte (`pate_poids_neutre`), et une
// lumière colorée garde sa teinte. 0 : mesurée après la pâte, comme au commit db26c43 (le halo de fusée jaunissait).
uniform float neutre_avant_pate : hint_range(0.0, 1.0) = 0.0;
// ISO7b — des dalles, pas une grille. `dalles` à 0 : le sol d'ISO7 exactement.
uniform float dalles : hint_range(0.0, 1.0) = 0.0;
uniform float tuile_px = 35.0;
uniform float joint_2d_px = 1.0;
uniform float ton_a = 0.148;
uniform float ton_b = 0.178;
// L'exposant du rapport des tons dans l'espace où la lightmap est lue : 1 si la lecture est en valeurs
// affichées, ~2,2 si elle est linéarisée par `source_color`. Tranché au banc sur le contraste du damier.
uniform float ton_exposant = 1.0;
uniform float dalle_px = 70.0;
uniform float joint_dalle_px = 1.2;
uniform float joint_dalle_reste : hint_range(0.0, 1.0) = 0.6;
// ISO10, 1d — l'ombre de contact des corps, par vue. xy : le pied du corps en px de monde ; z : sa force, l'opacité
// du corps DANS cette vue (0 l'éteint — un corps qu'une vue ne voit pas n'y pose aucune ombre). Rayon 0 : aucune.
uniform vec3 contact_corps_1 = vec3(0.0);
uniform vec3 contact_corps_2 = vec3(0.0);
uniform float contact_corps_rayon_px = 0.0;
uniform float contact_corps_reste : hint_range(0.0, 1.0) = 1.0;

varying vec3 monde;

// ISO7b — le ton de la case du damier sous le point `p` : 1 pour la sombre, (ton_a/ton_b)^exposant pour la claire.
float ton_du_sol(vec2 p) {
	vec2 case_sol = floor(p / tuile_px);
	float claire = mod(case_sol.x + case_sol.y, 2.0);
	return mix(1.0, pow(ton_a / ton_b, ton_exposant), claire * dalles);
}

// ISO7b — `lightmap_pateuse` (iso_lightmap.gdshaderinc), formule pour formule, avec la lumière lue ramenée au
// ton sombre du damier AVANT la pâte. ⚠️ Après la pâte, c'était faux : la pâte D range la lumière en bandes
// par seuils de luminance, les deux tons du damier tombaient de part et d'autre d'un seuil, et assombrir la
// case claire après coup REFAISAIT un damier dans les zones bien éclairées.
vec3 lightmap_pateuse_sol(vec2 p, vec2 motif, float aa, bool deux) {
	vec3 c = lire_lightmap(p, deux) * ton_du_sol(p);
	if (style == PATE_BRUTE) {
		return c;
	}
	float l = pate_luminance(c);
	if (l <= 0.0) {
		return vec3(0.0);
	}
	vec2 dx = vec2(LIGHTMAP_PAS_PX, 0.0);
	vec2 dy = vec2(0.0, LIGHTMAP_PAS_PX);
	float lx_0 = pate_luminance(lire_lightmap(p - dx, deux) * ton_du_sol(p - dx));
	float lx_1 = pate_luminance(lire_lightmap(p + dx, deux) * ton_du_sol(p + dx));
	float ly_0 = pate_luminance(lire_lightmap(p - dy, deux) * ton_du_sol(p - dy));
	float ly_1 = pate_luminance(lire_lightmap(p + dy, deux) * ton_du_sol(p + dy));
	vec2 pente = vec2(lx_1 - lx_0, ly_1 - ly_0) / (2.0 * LIGHTMAP_PAS_PX);
	float decalee = pate_luminance(lire_lightmap(p + vec2(3.0, 2.0), deux) * ton_du_sol(p + vec2(3.0, 2.0)));
	return pate(c, l, style, motif, pente, decalee, aa);
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Le facteur des deux ombres de contact en `p` : plein (`contact_corps_reste`) sous le pied jusqu'à 35 % du rayon,
// puis un fondu jusqu'à 1 au rayon. Aucune direction : la lumière directionnelle reste pour après le test final.
float contact_des_corps(vec2 p) {
	if (contact_corps_rayon_px <= 0.0) {
		return 1.0;
	}
	float f = 1.0;
	for (int k = 0; k < 2; k++) {
		vec3 corps = k == 0 ? contact_corps_1 : contact_corps_2;
		if (corps.z <= 0.0) {
			continue;
		}
		float d = length(p - corps.xy) / contact_corps_rayon_px;
		f *= mix(1.0, contact_corps_reste, clamp(corps.z, 0.0, 1.0) * (1.0 - smoothstep(0.35, 1.0, d)));
	}
	return f;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 px = monde.xz;
	float aa = clamp((fwidth(px.x) + fwidth(px.y)) / 6.0, 0.02, 0.5);
	float px_monde = max(fwidth(px.x), fwidth(px.y));
	// Hors de tout branchement : les mipmaps prennent leurs dérivées ici.
	float matiere = mix(1.0, texture(texture_sol, px / periode_sol_px).r, force_matiere);

	// Le joint de 35 px enjambé : la lecture glisse vers le centre de la tuile.
	vec2 dans_tuile = fract(px / tuile_px) * tuile_px;
	float marge = joint_2d_px + 0.5;
	vec2 glisse = step(dans_tuile, vec2(marge)) * marge - step(vec2(tuile_px - marge), dans_tuile) * marge;
	vec2 px_lu = px + glisse * dalles;

	// Le joint des dalles.
	vec2 dans_dalle = abs(fract(px / dalle_px) - 0.5) * dalle_px;
	float au_bord = dalle_px * 0.5 - max(dans_dalle.x, dans_dalle.y);
	float joint = dalles * pate_trait_de_bord(au_bord, max(joint_dalle_px, px_monde), px_monde);
	float dalle = mix(1.0, joint_dalle_reste, joint);

	vec3 c = lightmap_pateuse_sol(px_lu, px, aa, deux);
	// Sur la valeur AFFICHÉE (`pate_facteur`) : posée dans l'espace du shader, une matière de 0,5 se voyait
	// comme ~0,2 (mesuré au banc, 2026-09-15).
	c = pate_facteur(c, matiere * dalle);
	// ISO7b — graduée : `temperature_seuil_haut` à 0 rend la température d'ISO7 (teinte chaude partout) ; la
	// neutralité lue avant la pâte (`neutre_avant_pate`) garde sa teinte à une lumière colorée. Le ton du damier
	// est un facteur gris : il ne change pas la neutralité, la lecture brute suffit.
	if (temperature_seuil_haut <= 0.0) {
		c = pate_temperature(c, temperature);
	} else if (neutre_avant_pate > 0.5) {
		vec3 brute = lire_lightmap(px_lu, deux);
		c = pate_temperature_graduee_neutre(c, temperature, temperature_seuil_bas, temperature_seuil_haut,
			pate_poids_neutre(brute));
	} else {
		c = pate_temperature_graduee(c, temperature, temperature_seuil_bas, temperature_seuil_haut);
	}
	// ISO10, 1d — sur la valeur affichée, comme la matière : un sol noir reste noir sous un corps.
	c = pate_facteur(c, contact_des_corps(px));
	ALBEDO = c;
}
