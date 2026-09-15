// La pâte de roman graphique de la vue isométrique (ISO1).
//
// Une fonction de style, partagée par tous les matériaux iso — sol, faces de murs,
// corps ; le shader des corps voxel d'ISO3 l'inclura. Quatre pâtes, à trancher par
// Adrien sur planche et en jeu (jalon H-ISO1) :
//   0  A — gravure à l'encre : hachures qui suivent la lumière ;
//   1  B — ligne claire : aplats, contour seulement là où c'est éclairé ;
//   2  C — trame et encre décalée ;
//   3  D — lavis et pochoir.
//  -1  brute : la lightmap telle quelle (comparaison avec la vue de dessus).
//
// ⚠️ INVARIANT NON NÉGOCIABLE — le contrat du noir absolu.
// pate() est MONOTONE en la lumière et vaut STRICTEMENT 0 à lumière 0. Tout ce que
// la pâte fait MULTIPLIE la couleur reçue : aucun terme additif, donc ni contour, ni
// rim, ni ambiance, ni grain, ni brouillard dans le noir. Une encre noircit, elle
// n'éclaire jamais. Les tons « normalisés » (B, C, D) divisent par max(l, 0,25) et
// non par l : à lumière faible, la pâte ne REHAUSSE pas un reliquat de lumière qui
// dévoilerait ce que la vue de dessus laisse dans le noir.
//
// ⚠️ **POUR UN CORPS (ISO3), plafonner à la couleur d'entrée : `min(pate(c, …), c)`.** La
// pâte B, C et D normalise les tons : pensée pour la LUMIÈRE projetée au sol, elle pousse au
// blanc une couleur de corps déjà éclairée. Les corps grossiers d'ISO2 sont sortis à
// 255/246/227 pour un gris plafonné à 191/177/156 (retour d'Adrien au jalon H-ISO2). La vue
// de dessus plafonne l'ennemi à son gris ; la vue iso doit en faire autant.
//
// Miroir processeur, formule pour formule : `iso_pate.gd`. La suite
// `tools/test_iso_camera.gd` y vérifie l'invariant sur les quatre pâtes ; le banc
// (`tools/banc_iso.gd --jeu --noir`) le vérifie au pixel dans une vraie fenêtre.
// Toute retouche se fait DANS LES DEUX fichiers.

uniform int style = 0;

const int PATE_BRUTE = -1;
const int PATE_GRAVURE = 0;
const int PATE_LIGNE_CLAIRE = 1;
const int PATE_TRAME = 2;
const int PATE_LAVIS = 3;

const vec3 PATE_POIDS = vec3(0.2126, 0.7152, 0.0722);
const float PATE_PLANCHER = 0.25;

float pate_luminance(vec3 c) {
	return dot(c, PATE_POIDS);
}

float pate_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Bruit de valeur, statique : il ne dépend que du lieu, jamais de la lumière.
float pate_bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = pate_hash(i);
	float b = pate_hash(i + vec2(1.0, 0.0));
	float c = pate_hash(i + vec2(0.0, 1.0));
	float d = pate_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 1 sur un trait d'encre, 0 sur le papier. Croît avec la demi-largeur ; nul à
// demi-largeur nulle (le « + aa » dans la distance).
float pate_trait(float coord, float periode, float demi_largeur, float aa) {
	float s = abs(fract(coord / periode) - 0.5) * 2.0;
	return 1.0 - smoothstep(demi_largeur - aa, demi_largeur + aa, s + aa);
}

// ---------------------------------------------------------------------------
// ISO7 — l'ENCRE DES ARÊTES, partagée par les murs, les objets et les corps
// ---------------------------------------------------------------------------
// « Un mur n'est pas une surface, c'est une masse cernée d'un filament » (Adrien, 2026-08-25) :
// en iso, le filament est l'arête. Ces deux fonctions rendent un FACTEUR dans [reste, 1] que
// l'appelant multiplie à sa couleur déjà passée à la pâte — jamais un terme additif : sur du noir,
// l'encre reste du noir. Aucune dérivée à l'intérieur : `px_monde` (pixels de monde par pixel
// d'écran, `max(fwidth(monde.x), fwidth(monde.y), fwidth(monde.z))`) se calcule dans fragment(),
// hors de tout branchement, et se passe ici.

// 1 sur le trait (à moins de `largeur` du bord), 0 au-delà ; `aa` en unités de `distance`.
float pate_trait_de_bord(float distance, float largeur, float aa) {
	return 1.0 - smoothstep(largeur - aa, largeur + aa, distance);
}

// ---------------------------------------------------------------------------
// ISO7 — un facteur d'habillage s'applique à la valeur AFFICHÉE
// ---------------------------------------------------------------------------
// ⚠️ **Mesuré au banc le 2026-09-15, et c'est ce qui décide de tout facteur ISO7.** La valeur que ces
// shaders écrivent n'est pas celle que l'écran montre, à une conversion sRGB près : une encre de 0,25
// posée par `c *= 0.25` faisait passer un pixel de 28/255 à 1/255 (et non à 7), un reste de 1 ne
// changeait rien. Un facteur f posé dans l'espace du shader se voyait donc comme ≈ f^2,4 — le plancher
// de 0,25 promis par les suites tombait à 0,036 à l'écran, et la matière de 0,8 assombrissait comme 0,6.
// `pate_facteur(c, f)` passe la couleur à sa valeur affichée (décodage sRGB), la multiplie, et la rend :
// le facteur se VOIT tel qu'il est écrit. 0 reste 0 ; monotone en c comme en f.
vec3 pate_vers_affiche(vec3 c) {
	vec3 s = max(c, vec3(0.0));
	return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), s));
}

vec3 pate_depuis_affiche(vec3 a) {
	vec3 s = max(a, vec3(0.0));
	return mix(s * 12.92, 1.055 * pow(s, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), s));
}

vec3 pate_facteur(vec3 c, float f) {
	return pate_depuis_affiche(pate_vers_affiche(c) * max(f, 0.0));
}

// La matière ET l'encre d'une arête, en valeur affichée. L'encre (`t` ∈ [0, 1] sur le trait) ne se
// cumule pas avec la matière (le plus petit des deux facteurs, jamais leur produit) et ne descend
// jamais sous `plancher` : **une face à peine éclairée garde sa lumière**, le filament n'apparaît
// qu'au-dessus du plancher. Au banc, une face à 21/255 tombait à 1/255 sous une encre de 0,25 — une
// lumière réelle effacée, exactement ce que la règle « allumé reste allumé » interdit.
// Garanties : 0 → 0 ; monotone en la lumière ; jamais plus clair que la matière seule ; au-dessus du
// plancher, jamais sous lui ; sous lui, la matière seule.
vec3 pate_matiere_et_encre(vec3 c, float matiere, float reste, float t, float plancher) {
	vec3 a = pate_vers_affiche(c);
	float s = pate_luminance(a);
	if (s <= 0.0) {
		return vec3(0.0);
	}
	float m = max(matiere, 0.0);
	float avec_encre = max(s * min(m, reste), min(s * m, plancher));
	float cible = mix(s * m, min(s * m, avec_encre), clamp(t, 0.0, 1.0));
	return pate_depuis_affiche(a * (cible / s));
}

// ---------------------------------------------------------------------------
// ISO7 — la TEMPÉRATURE de la lumière vue (étape 6)
// ---------------------------------------------------------------------------
// Les planches du DA peignent la lumière chaude (ambre sur béton). La température change la TEINTE
// d'une lumière neutre, jamais sa quantité : la luminance rendue est celle reçue, donc aucune bande de
// la pâte ne bascule et aucun seuil n'est franchi. Une lumière déjà colorée (fusée rouge, LED) garde
// sa teinte : la force est pondérée par la neutralité de la couleur. 0 → 0.
const vec3 PATE_TEINTE_CHAUDE = vec3(1.10, 0.97, 0.80);

vec3 pate_temperature(vec3 c, float force) {
	float l = pate_luminance(c);
	if (l <= 0.0 || force <= 0.0) {
		return c;
	}
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float neutre = 1.0 - clamp((mx - mn) / max(mx, 0.0001), 0.0, 1.0);
	vec3 teinte = PATE_TEINTE_CHAUDE / pate_luminance(PATE_TEINTE_CHAUDE);
	vec3 chaude = c * mix(vec3(1.0), teinte, clamp(force, 0.0, 1.0) * neutre);
	return chaude * (l / max(pate_luminance(chaude), 0.000001));
}

// L'encre des arêtes d'une BOÎTE, quelle que soit la façon dont elle est construite — cube unité
// mis à l'échelle (les murs) ou `BoxMesh` à sa vraie taille sous une échelle identité (les voxels,
// jambes comprimées en Y à l'accroupi) — et quelle que soit sa rotation (un corps tourne) :
// - `local`  : VERTEX, repère du modèle ;
// - `demi`   : la demi-taille du maillage, repère du modèle. ⚠️ Pour une `BoxMesh` SANS subdivision,
//              tous les sommets sont des coins : `abs(VERTEX)` posé en varying dans vertex() vaut la
//              demi-taille à chaque sommet, donc aussi après interpolation. (Découvert avec ISO Corps le
//              2026-09-15 : `length(MODEL_MATRIX[i])` seul lisait l'échelle 1 des voxels, jamais leur taille.)
// - `echelle`: `vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz))` ;
// - `normale`: NORMAL, repère du MODÈLE (alignée sur les axes de la boîte même si le corps tourne).
// Distances en unités du monde. Le trait longe les quatre bords de la face ; jamais sous un pixel
// d'écran. Facteur 1 si `largeur` <= 0.
float pate_encre_boite(vec3 local, vec3 demi, vec3 echelle, vec3 normale, float largeur, float reste,
		float px_monde) {
	if (largeur <= 0.0) {
		return 1.0;
	}
	vec3 d = max(demi - abs(local), vec3(0.0)) * echelle;
	vec3 an = abs(normale);
	float bord = an.x > 0.5 ? min(d.y, d.z) : (an.y > 0.5 ? min(d.x, d.z) : min(d.x, d.y));
	float w = max(largeur, px_monde);
	return mix(1.0, clamp(reste, 0.0, 1.0), pate_trait_de_bord(bord, w, px_monde));
}

// couleur          la lumière reçue (lightmap), déjà colorée ;
// lumiere          sa luminance ;
// st               la pâte ;
// motif            où le motif s'accroche : le MONDE, jamais l'écran ;
// pente            gradient de luminance au même point (par pixel de monde) ;
// lumiere_decalee  luminance lue à côté — l'encre décalée de C ;
// aa               largeur d'anticrénelage, en fraction de période.
vec3 pate(vec3 couleur, float lumiere, int st, vec2 motif, vec2 pente,
		float lumiere_decalee, float aa) {
	if (st == PATE_BRUTE) {
		return couleur;
	}
	if (lumiere <= 0.0) {
		return vec3(0.0);
	}
	float l = clamp(lumiere, 0.0, 1.0);
	if (st == PATE_GRAVURE) {
		// Plus il y a de lumière, plus les traits s'amincissent ; au-dessus de 0,45
		// le papier est nu. Sous 0,5 de clarté, une seconde passe croise la première.
		float t = clamp(l * 2.2, 0.0, 1.0);
		float angle = 0.785398;
		if (length(pente) > 0.0001) {
			angle = atan(pente.y, pente.x);
		}
		// Huit directions : un burin ne tourne pas au pixel près.
		angle = floor(angle / 0.392699 + 0.5) * 0.392699;
		vec2 n = vec2(cos(angle), sin(angle));
		float trait_1 = pate_trait(dot(motif, n), 6.0, 1.0 - t, aa);
		float trait_2 = pate_trait(dot(motif, vec2(-n.y, n.x)), 6.0,
			clamp(1.0 - 2.0 * t, 0.0, 1.0), aa);
		return couleur * (1.0 - trait_1) * (1.0 - trait_2);
	}
	vec3 teinte = couleur / max(l, PATE_PLANCHER);
	if (st == PATE_LIGNE_CLAIRE) {
		float a = 0.012;
		float q = 0.22 * smoothstep(0.02 - a, 0.02 + a, l)
			+ 0.33 * smoothstep(0.2 - a, 0.2 + a, l)
			+ 0.45 * smoothstep(0.5 - a, 0.5 + a, l);
		// Le contour ne dépend que de la pente : il ne peut qu'assombrir un aplat,
		// et un aplat nul reste nul.
		float bord = smoothstep(0.02, 0.06, length(pente));
		return teinte * q * (1.0 - 0.9 * bord);
	}
	if (st == PATE_TRAME) {
		vec2 p = vec2(motif.x + motif.y, motif.y - motif.x) * 0.70710678 / 5.0;
		vec2 f = fract(p) - 0.5;
		float d = length(f) * 1.41421356;
		float rayon = sqrt(l) * 1.15;
		float point = 1.0 - smoothstep(rayon - aa, rayon + aa, d + aa);
		float encre = 1.0 - 0.55 * (1.0 - smoothstep(0.0, 0.06, lumiere_decalee));
		return teinte * point * encre;
	}
	// PATE_LAVIS
	float b = pate_bruit(motif / 23.0);
	float grain = pate_bruit(motif / 3.0);
	float a = 0.01;
	float e_1 = 0.02 + 0.03 * b;
	float e_2 = 0.16 + 0.08 * b;
	float e_3 = 0.42 + 0.1 * b;
	float q = 0.3 * smoothstep(e_1 - a, e_1 + a, l)
		+ 0.3 * smoothstep(e_2 - a, e_2 + a, l)
		+ 0.4 * smoothstep(e_3 - a, e_3 + a, l);
	// Désaturé vers la luminance de la COULEUR reçue, pas vers `l` : une couleur nulle
	// reste nulle, quelle que soit la lumière annoncée.
	vec3 lave = mix(couleur, vec3(pate_luminance(couleur)), 0.35) / max(l, PATE_PLANCHER);
	return lave * q * (0.82 + 0.18 * grain);
}
