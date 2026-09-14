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
