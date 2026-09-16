// ISO12, lot 0 — LE SOL ÉCLAIRÉ : `sol_iso.gdshader` passé à la lumière 3D, derrière le drapeau `Presentation3D.lumiere_3d`.
//
// L'albédo du sol n'est plus la lightmap (« sol peint × lumière ») : c'est la PEINTURE de la carte sans lumière
// (`peinture_iso.gd` — sol, décor, encre, sang, douilles), rapportée à son étalon (1 sur un sol propre) et ramenée au ton
// sombre du damier comme ISO7b, × la matière et les dalles d'ISO7. La lumière vient des Light3D, et l'albédo porte la BRIDE :
// `smoothstep(bride_bas, bride_haut, L2D)`, L2D = lightmap ÷ peinture (la même division que les faces, ISO10 1f). L2D = 0 ⇒ 0.
// Variantes : `variante_pate` 0 = (a) la bride en paliers ; 1 = (c) continue. `masque_preuve` 1 = blanc là où L2D > 0.
// `contact_des_corps` reste en variante (`contact_corps_rayon_px` à 0 l'éteint).
//
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
render_mode cull_back, fog_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"
#include "res://iso_relief.gdshaderinc"

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

// ISO12 — la bride, ses variantes, et la peinture de la carte (mêmes uniformes que `mur_iso`, posés par
// `IsoMateriaux.accorder_peinture` ; L2 d'ISO12 les rangera dans un include commun).
uniform float bride_bas : hint_range(0.0, 1.0) = 0.0;
uniform float bride_haut : hint_range(0.0, 1.0) = 0.05;
uniform int variante_pate = 0;
uniform int masque_preuve = 0;
// ISO12, lot 0 ter — la bride SUIT LE GRADIENT 2D (session cloud, 00:25). 0 : smoothstep(bride_bas, bride_haut, L2D) ; 1 : identité,
// L2D × bride_echelle plafonné à 1 — l'intensité de la 3D suit celle de la 2D, l'énergie 3D étant recalibrée derrière.
uniform int bride_mode = 0;
uniform float bride_echelle = 1.0;

float bride_valeur(float l) {
	if (bride_mode == 1) {
		return clamp(l * bride_echelle, 0.0, 1.0);
	}
	return smoothstep(bride_bas, bride_haut, l);
}
// ISO12, lot 0 ter — le pied de la lampe de chaque joueur en émission au sol, les DEUX vues, bridé : la texture de sa
// rétrodiffusion (`BodyLight`) sous lui (xy : position en px de monde, z : énergie). Le spot de la torche ne couvre pas son pied.
uniform sampler2D pied_lampe_texture : filter_linear, repeat_disable;
uniform vec3 pied_lampe_1 = vec3(0.0);
uniform vec3 pied_lampe_2 = vec3(0.0);
uniform float pied_lampe_empreinte_px = 96.0;
uniform vec3 pied_lampe_couleur = vec3(1.0);
uniform float pied_lampe_gain = 0.0;

vec3 lire_pied_lampe(vec2 px) {
	vec3 somme = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		vec3 h = k == 0 ? pied_lampe_1 : pied_lampe_2;
		if (h.z <= 0.0) {
			continue;
		}
		vec2 uv = (px - h.xy) / pied_lampe_empreinte_px + vec2(0.5);
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			continue;
		}
		somme += texture(pied_lampe_texture, uv).a * pied_lampe_couleur * h.z * pied_lampe_gain;
	}
	return somme;
}
// ISO12 — le bandeau de LED des murs (`MurLed`) en émission : la texture cuite de la lumière 2D, en coordonnées du monde
// (`led_origine_px`, `led_taille_px` : le rectangle de la carte bordure comprise), sa couleur courante (0 quand il est
// éteint) et un gain calibré au banc. Commun aux deux vues, comme la lumière 2D.
uniform sampler2D led_texture : filter_linear, repeat_disable;
uniform bool led_active = false;
uniform vec2 led_origine_px = vec2(0.0);
uniform vec2 led_taille_px = vec2(1.0);
uniform vec3 led_couleur = vec3(0.0);
uniform float led_gain = 1.0;
// ISO12 — le halo de proximité de chaque joueur (`ambient_light`), qui n'éclaire que la vue de son porteur : une émission PAR VUE,
// comme la silhouette de soi. La vue 1 lit le halo de J1, la vue 2 celui de J2 (xy : position en px de monde, z : énergie, 0 éteint).
uniform sampler2D halo_soi_texture : filter_linear, repeat_disable;
uniform vec3 halo_soi_1 = vec3(0.0);
uniform vec3 halo_soi_2 = vec3(0.0);
uniform float halo_soi_empreinte_px = 150.0;
uniform vec3 halo_soi_couleur = vec3(1.0);
uniform float halo_soi_gain = 0.25;

vec3 lire_halo_soi(vec2 px, bool deux) {
	vec3 h = deux ? halo_soi_2 : halo_soi_1;
	if (h.z <= 0.0) {
		return vec3(0.0);
	}
	vec2 uv = (px - h.xy) / halo_soi_empreinte_px + vec2(0.5);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	return texture(halo_soi_texture, uv).a * halo_soi_couleur * h.z * halo_soi_gain;
}

vec3 lire_led(vec2 px) {
	if (!led_active) {
		return vec3(0.0);
	}
	vec2 uv = (px - led_origine_px) / led_taille_px;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	return texture(led_texture, uv).a * led_couleur * led_gain;
}
uniform sampler2D peinture : source_color, filter_linear, repeat_disable;
uniform bool peinture_active = false;
uniform vec2 peinture_origine_px = vec2(0.0);
uniform vec2 peinture_taille_px = vec2(1.0);
uniform vec2 peinture_etalon_px = vec2(0.0);
uniform vec2 peinture_plancher_px = vec2(0.0);
// ISO12 — les deux aplats du damier de la peinture (`CandelaTileSet.SOL_DESSIN_A` et `_B`), en LINÉAIRE : l'albédo est la
// peinture divisée par l'aplat de SA case, 1 sur un sol propre, quelle que soit la case ; le sang et les douilles gardent
// leur écart. ⚠️ Deux essais par le rapport des tons (`ton_du_sol`, puis le même porté à 2,2) laissaient le damier franc
// sous la lampe (deuxième et troisième passes du banc, 2026-09-15).
uniform vec2 peinture_aplat_a_px = vec2(0.0);
uniform vec2 peinture_aplat_b_px = vec2(0.0);
// 0 : la case (x + y) paire prend l'aplat A ; 1 : l'inverse.
uniform int aplat_parite = 0;

varying vec3 monde;

vec3 lire_etalon(vec2 px) {
	return texture(peinture, (px - peinture_origine_px) / peinture_taille_px).rgb;
}

// La peinture au point `px`, rapportée à la référence : 1 sur le sol dessiné moyen. Hors de la carte peinte, 1.
vec3 albedo_peint(vec2 px, vec3 ref) {
	vec2 uv = (px - peinture_origine_px) / peinture_taille_px;
	if (!peinture_active || uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec3(1.0);
	}
	return texture(peinture, uv).rgb / max(ref, vec3(0.001));
}

// ISO12 — le ton du damier pour l'ALBÉDO, en LINÉAIRE : la peinture est lue par un échantillonneur `source_color`, donc
// linéarisée, et le rapport des deux tons (valeurs affichées) doit y être porté à la puissance 2,2. ⚠️ Avec `ton_du_sol`
// (dont l'exposant est réglé pour la lecture de la lightmap), le damier revenait franc sur le sol éclairé (deuxième passe
// du banc, 2026-09-15 22:50).
float ton_du_sol_lineaire(vec2 p) {
	vec2 case_sol = floor(p / tuile_px);
	float claire = mod(case_sol.x + case_sol.y, 2.0);
	return mix(1.0, pow(ton_a / ton_b, 2.2), claire * dalles);
}

// La lumière d'un point du sol sans sa peinture (voir `mur_iso.gdshader`, ISO10 1f).
vec3 lire_lumiere_sol(vec2 px, bool deux, vec3 ref, float plancher) {
	vec3 l = lire_lightmap(px, deux);
	vec2 uv = (px - peinture_origine_px) / peinture_taille_px;
	if (!peinture_active || uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return l;
	}
	vec3 p = max(texture(peinture, uv).rgb, vec3(plancher));
	return min(l * ref / p, vec3(1.0));
}

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

	// ISO12 — la lumière sans peinture, sa bride, et l'albédo peint.
	vec3 ref = lire_etalon(peinture_etalon_px);
	float plancher = lire_etalon(peinture_plancher_px).g;
	vec3 brute = lire_lumiere_sol(px_lu, deux, ref, plancher);
	float b = bride_valeur(pate_luminance(brute));
	vec3 c = variante_pate == 1 ? vec3(b) : pate(vec3(b), b, style, px, vec2(0.0), b, aa);
	if (style == PATE_BRUTE || b <= 0.0) {
		c = vec3(b);
	}
	// Les facteurs d'ISO7 sur la valeur AFFICHÉE, comme avant (`pate_facteur`).
	c = pate_facteur(c, matiere * dalle);
	c = pate_facteur(c, contact_des_corps(px));
	// Le damier de la peinture ramené au ton sombre (ISO7b) : la case claire est assombrie, jamais la sombre éclaircie.
	vec2 case_albedo = floor(px_lu / tuile_px);
	float impaire = mod(case_albedo.x + case_albedo.y, 2.0);
	if (aplat_parite == 1) {
		impaire = 1.0 - impaire;
	}
	vec3 aplat = mix(lire_etalon(peinture_aplat_a_px), lire_etalon(peinture_aplat_b_px), impaire);
	vec3 albedo = albedo_peint(px_lu, aplat);
	if (masque_preuve == 1) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(step(0.0005, pate_luminance(brute)));
	} else {
		ALBEDO = c * albedo;
		EMISSION = c * albedo * (lire_led(px_lu) + lire_halo_soi(px_lu, deux) + lire_pied_lampe(px_lu));
	}

	// ISO12 v27 — le dénominateur du relief : calculé ici (sans ombre, sur la liste fermée des lampes) parce que `light()` ne
	// voit aucune variable de `fragment()`, et transporté vers lui par ce canal. Posé après les deux branches, donc dans les
	// deux cas.
	SPECULAR = relief_encoder(monde);
}

// ISO12 v27 — le relief normalisé, sans spéculaire.
void light() {
	// ISO12 v27 — LE RELIEF : le numérateur (ce qu'on accumulait ici, l'ombre portée par ATTENUATION) divisé par le
	// dénominateur commun, calculé sans ombre dans `fragment()` et transporté par SPECULAR. Le rapport vaut 1 sur un sol plat,
	// quel que soit le nombre de lampes, et moins dans l'ombre : l'intensité vient de la 2D (ALBEDO porte déjà albédo × L2D),
	// la 3D n'apporte que le modelé.
	//
	// ⚠️ **« Plus sur une face tournée vers la lampe » n'est vrai que sous une lampe RASANTE** (calculé, 2026-09-16). Le mur
	// croise le sol à dot(haut, L) ≈ 0,707 — exactement le régime d'une torche visant le sol à 45°. Sous une lampe plus haute
	// le mur lit MOINS que le sol (0,667 à 150 px de hauteur, 0,500 à 200), et sous une lampe basse il sature : R brut 4,98 à
	// 10 px, 4,00 à 25, 2,00 à 50, tous ramenés à `relief_max`. L'écrêtage n'est donc pas théorique, et il s'applique PAR
	// LAMPE — et ce dépassement est CHIFFRÉ : sur le cadrage cumulé (fusée posée entre deux torches), un mur face à la fusée
	// rend 0,16 + 1,50 (écrêté de 4,04) + 0,00 = **1,659**, soit ~11 % au-dessus de `relief_max`. Le maximum visible suit donc
	// le plafond sans lui être égal.
	//
	// Qu'un mur lise MOINS que le sol sous une lampe haute est le MODELÉ VOULU (tranché le 2026-09-16) : une face tournée de
	// côté reçoit moins d'une lampe placée au-dessus, c'est Lambert, et c'est ce que la 2D ne sait pas dire. La « flaque » du
	// défaut deux était un sol trop CLAIR, jamais un mur trop sombre.
	//
	// ⚠️ Ce `light()` n'écrit JAMAIS SPECULAR_LIGHT, et c'est ce qui éteint la passe spéculaire du moteur maintenant que
	// `specular_disabled` a sauté. Le supprimer rallumerait les reflets.
	DIFFUSE_LIGHT += relief_contribution(LIGHT_COLOR, ATTENUATION, dot(NORMAL, LIGHT), SPECULAR_AMOUNT);
}
