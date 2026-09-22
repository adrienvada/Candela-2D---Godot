// ISO12 v27 — LE RELIEF NORMALISÉ. La 2D donne l'intensité, la 3D ne donne que le modelé :
//
//     couleur = albédo × L2D × R,    R = Σᵢ LIGHT_COLORᵢ · ATTENUATIONᵢ · max(N·Lᵢ, 0)  /  Σᵢ π · Iᵢ · attᵢ · côneᵢ · max(haut·Lᵢ, ε)
//
// Le numérateur est ce que `light()` accumule, l'ombre portée par ATTENUATION. Le dénominateur est ce que les MÊMES lampes
// donneraient au même point sur un sol plat, SANS ombre : il se calcule dans `fragment()` depuis la liste fermée du miroir
// (`LumieresIso.decrire_pour_relief`) et passe à `light()` par un varying. Une moyenne pondérée, jamais une somme : deux lampes
// sur un sol plat donnent 1, pas 2.
//
// ⚠️ **LA PREMIÈRE VERSION (b5fbf3a → 72a2364) N'ÉTAIT APPLIQUÉE NULLE PART** — revue d'ISO7 Beauté, arbitrée par la session
// cloud le 2026-09-22. Deux défauts l'éteignaient chacun à lui seul, trois autres l'auraient faussée :
//   1. le dénominateur voyageait par SPECULAR → SPECULAR_AMOUNT, et ce canal n'existe pas : dans `light()`, SPECULAR_AMOUNT
//      vaut 2 × `light_specular` de la LAMPE (documentation de Godot 4, table des entrées de `light()`), et le miroir pose 0.
//      Le dénominateur valait donc 0 partout, la garde rendait le Lambert brut : la v27 affichait la v26 ;
//   2. la liste des lampes n'était posée qu'à la bascule du drapeau (vide) et à la pose d'un corps (figée) ;
//   3. la décroissance était celle de Godot 3, (1 − d/r)^decay — R variait d'un facteur 12 le long d'un cône ;
//   4. le cône était un smoothstep — un anneau au plafond sur le bord de chaque cône de torche ;
//   5. le π de LIGHT_COLOR manquait — un sol plat aurait lu ≈ 2,8, écrêté.
// **Aucune suite ne pouvait le voir** : elles vérifient le TEXTE des shaders, pas l'image. Les « 1,0000 » et « 1,659 » écrits
// avant ce correctif étaient des calculs hors machine, sur des formules qui n'étaient pas celles du moteur.
//
// Le dénominateur recopie donc le moteur MOT POUR MOT (`scene.glsl` du rendu Compatibility, Godot 4.7) :
//   get_omni_spot_attenuation(d, 1/r, decay) = max(1 − (d/r)⁴, 0)² × max(d, 0,0001)^(−decay)
//   cône d'un spot : scos = max(dot(−L̂, dir), cosA) ; rim = max(0,0001, (1 − scos)/(1 − cosA)) ; × (1 − rim^exposant)
//   LIGHT_COLOR = couleur LINÉAIRE × énergie × π — le π est porté ici aussi.
// L'intensité Iᵢ est posée par le miroir : énergie × luminance, aux poids de la pâte (`PATE_POIDS`), de la couleur
// LINÉARISÉE — la luminance même avec laquelle la pâte lit la lumière, pour que R vaille 1 en luminance sur un sol plat.
//
// ⚠️ Huit lampes au plus, triées par intensité : le moteur, lui, apparie ses lampes PAR MAILLAGE. L'écart se chiffre au banc
// (`--v27-cadrage=neuf_lampes`) avant toute décision (défaut 7 de la revue).

uniform int relief_nb = 0;
uniform vec4 relief_pos_intensite[8];   // xyz : position monde ; w : énergie × luminance linéaire de la couleur
uniform vec4 relief_portee_cone[8];     // x : portée ; y : cos(demi-angle), < 0 pour une omni ; z : décroissance ; w : exposant de cône
uniform vec4 relief_direction[8];       // xyz : direction du spot (vers l'avant) ; w : ε de la lampe (0 = non fourni)
// LE PLANCHER DU DÉNOMINATEUR, contre une lampe rasante (dot(haut, L) proche de 0). Il valait 0,2 et faisait manquer la règle
// à sa promesse sous une fusée posée ; à 0,02 il ne mord plus que sous 1,15° au-dessus de l'horizon (session cloud).
// ⚠️ ε est désormais PAR LAMPE (L4, ISO7 Gadgets) : min(h / portée, 0,02), porté par `relief_direction[i].w`. Cet uniforme
// n'est plus que le repli (w = 0) et le plafond. À 0,02 pour tous, braises et mine — posées à 1,75 px — voyaient le plancher
// mordre dès 87,5 px et le bord de leur halo tomber à 0,515 et 0,337.
uniform float relief_epsilon = 0.02;
// « Ni plus » borné, PAR LAMPE : un shader spatial n'offre aucun point après la boucle des lampes, donc une face sous deux lampes
// fortes peut dépasser ce plafond (le cadrage `recouvrement` du banc le chiffre). « Ni moins » reste libre dans les ombres.
uniform float relief_max = 1.5;

// LE CANAL, cette fois réel : écrit dans `fragment()`, lu dans `light()`. La documentation de Godot 4 le prévoit — un varying
// donne à `light()` l'accès à ce que `fragment()` a calculé. Aucun encodage, donc aucune borne.
varying float relief_d;

// En dessous, aucune lampe connue n'éclaire ce point : la garde prend la main (voir `relief_vide`).
const float RELIEF_D_MIN = 1e-7;

// INSTRUMENT DE BANC, comme `masque_preuve` — jamais posé en jeu. 1 : `light()` rend le NUMÉRATEUR brut (le Lambert du moteur,
// × gain) ; 2 : `fragment()` émet ALBEDO × DÉNOMINATEUR × gain et `light()` ne rend rien. Les deux prises, divisées pixel par
// pixel, donnent R sans passer par le relief lui-même : c'est ainsi qu'on voit LEQUEL des deux termes s'écarte du moteur.
uniform int relief_diagnostic = 0;
uniform float relief_diagnostic_gain = 1.0;

float relief_denominateur(vec3 monde_px) {
	vec3 haut = vec3(0.0, 1.0, 0.0);
	float d_total = 0.0;
	for (int i = 0; i < relief_nb; i++) {
		vec3 vers = relief_pos_intensite[i].xyz - monde_px;
		float d = length(vers);
		float portee = max(relief_portee_cone[i].x, 0.0001);
		if (d >= portee) {
			continue;
		}
		vec3 L = vers / max(d, 0.0001);
		// get_omni_spot_attenuation, mot pour mot.
		float nd = d / portee;
		nd *= nd;
		nd *= nd;
		nd = max(1.0 - nd, 0.0);
		nd *= nd;
		float att = nd * pow(max(d, 0.0001), -relief_portee_cone[i].z);
		float cone = 1.0;
		float cos_demi = relief_portee_cone[i].y;
		if (cos_demi >= 0.0) {
			// Le cône du spot, mot pour mot : hors du cône, scos = cosA, rim = 1, et le facteur tombe à 0 sans seuil.
			float scos = max(dot(-L, normalize(relief_direction[i].xyz)), cos_demi);
			float rim = max(0.0001, (1.0 - scos) / max(1.0 - cos_demi, 0.0001));
			cone = 1.0 - pow(rim, relief_portee_cone[i].w);
		}
		// ε PAR LAMPE (L4), porté par direction.w ; 0 = non fourni, on retombe sur l'uniforme global.
		float eps = relief_direction[i].w > 0.0 ? relief_direction[i].w : relief_epsilon;
		d_total += PI * relief_pos_intensite[i].w * att * cone * max(dot(haut, L), eps);
	}
	return d_total;
}

// INSTRUMENT DE BANC (modes 3 à 7) : un terme du dénominateur pour la lampe 0, émis tel quel pour être comparé au calcul.
// 3 : distance / 400 ; 4 : fenêtre de portée (1 − (d/r)⁴)² ; 5 : d^(−décroissance) × 50 ; 6 : cône ; 7 : max(haut·L, ε).
float relief_diag_terme(int mode, vec3 monde_px) {
	if (mode == 8) {
		// Une CONSTANTE : ce que la capture en rend dit si le chemin de l'émission jusqu'à l'image est linéaire.
		return relief_diagnostic_gain;
	}
	vec3 vers = relief_pos_intensite[0].xyz - monde_px;
	float d = length(vers);
	vec3 L = vers / max(d, 0.0001);
	float portee = max(relief_portee_cone[0].x, 0.0001);
	if (mode == 3) {
		return d / 400.0;
	}
	if (mode == 4) {
		float nd = d / portee;
		nd *= nd;
		nd *= nd;
		nd = max(1.0 - nd, 0.0);
		return nd * nd;
	}
	if (mode == 5) {
		return pow(max(d, 0.0001), -relief_portee_cone[0].z) * 50.0;
	}
	if (mode == 6) {
		float cos_demi = relief_portee_cone[0].y;
		float scos = max(dot(-L, normalize(relief_direction[0].xyz)), cos_demi);
		float rim = max(0.0001, (1.0 - scos) / max(1.0 - cos_demi, 0.0001));
		return 1.0 - pow(rim, relief_portee_cone[0].w);
	}
	float eps0 = relief_direction[0].w > 0.0 ? relief_direction[0].w : relief_epsilon;
	return max(dot(vec3(0.0, 1.0, 0.0), L), eps0);
}

// LA GARDE. Aucune lampe connue ici alors que la 2D peut y être éclairée : R vaut 1, c'est-à-dire LA 2D SEULE (arbitrage de
// la session cloud) — jamais le Lambert brut de la v26, qui ressusciterait l'éclairage qu'on remplace, jamais du noir.
// `fragment()` émet alors ALBEDO tel quel, et `light()` n'ajoute rien.
bool relief_vide(float d_total) {
	return d_total <= RELIEF_D_MIN;
}

// Dans `light()` : la contribution d'une lampe, déjà divisée par le dénominateur commun et plafonnée.
//
// ⚠️ **R ACHROMATIQUE** (session cloud, 2026-09-22, 23:46). La contribution se calcule sur la LUMINANCE de LIGHT_COLOR, aux poids
// PATE_POIDS du dénominateur, et rend ce scalaire sur les trois canaux. Calculée par canal, elle teignait l'image DEUX fois — la
// 2D porte déjà la couleur : sur un sol plat, une lampe donnait R = c_lin / lum(c_lin), soit (1,16 ; 0,98 ; 0,73) pour
// l'halogène et (3,64 ; 0,28 ; 0,36) pour la couleur de détresse, écrêtée à (1,50 ; 0,28 ; 0,36) : un halo de fusée vers 10° au
// lieu des 25° de la 2D. La 2D donne l'intensité ET la couleur ; la 3D ne donne que le relief.
vec3 relief_contribution(vec3 lumiere, float attenuation, float n_dot_l, float d_total) {
	float lum_lampe = dot(lumiere, PATE_POIDS);
	if (relief_diagnostic == 1) {
		return vec3(lum_lampe * attenuation * max(n_dot_l, 0.0) * relief_diagnostic_gain);
	}
	if (relief_diagnostic == 9) {
		// Instrument : ce que `light()` REÇOIT du varying, à comparer à ce que `fragment()` y a écrit (mode 2).
		return vec3(d_total * relief_diagnostic_gain);
	}
	if (relief_diagnostic >= 2) {
		return vec3(0.0);
	}
	if (relief_vide(d_total)) {
		return vec3(0.0);
	}
	return vec3(min(lum_lampe * attenuation * max(n_dot_l, 0.0) / d_total, relief_max));
}
