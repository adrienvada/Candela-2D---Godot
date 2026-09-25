// ISO13, Q31 voie A — CE QUE LE PIXEL MONTRE, pour le masque de la fumée (allumé par défaut, voir `volume_iso.gdshader`).
// Inclus par la seule variante FUMEE_MASQUE du shader des volumes ; avec `--sans-fumee-masque`, le jeu ne le compile pas.
//
// Une couche de fumée à la hauteur h se voit devant ce que le rayon de vue, prolongé au-delà d'elle, rencontre d'abord :
// le sol, la face d'un mur, ou le dessus d'un mur. La couche se tait là où CE QUE LE PIXEL MONTRE s'affiche noir, jugé
// comme son propre shader le calcule :
// - le SOL (`sol_iso.gdshader`) : sa couleur écrite, ligne pour ligne — la pâte de la lumière au point (glissée près des
//   joints), × la matière et le joint des dalles, la température, × le contact des corps ;
// - une FACE (`mur_iso.gdshader`) : la lumière moyennée au pied de la face, divisée par la peinture, passée à la pâte, ×
//   la matière de la face et le contact à son pied, puis la température ; le lambert vaut 1 (`LAMBERT_PLANCHER`) et
//   l'encre ne rend jamais noire une face qui ne l'est pas sans elle ;
// - le DESSUS d'un muret : la pâte de la lumière à sa case, puis la température ; d'un mur haut : noir strict (le liseré
//   est un trait de 2,4 px, l'exception déclarée).
// « NOIR », C'EST CE QUE L'ÉCRAN MONTRE À 0 — et l'écran n'affiche pas la valeur écrite. La sortie 3D de ce renderer
// (gl_compatibility) écrase le pied de la courbe : tout canal ÉCRIT à 7/255 ou moins s'affiche 0, 8 → 1, 9 → 2, 11 → 5,
// 16 → 10, 32 → 27. Mesuré le 2026-09-25 par des rampes connues, écrites puis relues : canal par canal, sans mélange à
// ces niveaux (rouge, vert, bleu et la couleur d'un sol éclairé suivent la même courbe) ; la même pour la fumée
// transparente et pour le sol opaque ; AUCUNE pour la 2D (une rampe de canevas ressort k → k) ; ni l'anticrénelage, ni
// un Environment (il n'y en a pas), ni le point noir de `presentation_3d.gd` (0 depuis le 23/09), ni la calibration de
// luminosité (branchée nulle part en jeu) ne la font. Elle vient du moteur ; la rampe est donc la RÉFÉRENCE, et la garde
// en fenêtre `loupe-rampe-3d` la refait et échoue si elle change.
// Un pixel est noir à l'écran si et seulement si TOUS ses canaux écrits sont sous le point noir : la couche se tait là
// où ce que le pixel montre, calculé comme son propre shader l'ÉCRIT, a tous ses canaux sous `POINT_NOIR_ECRIT`. Pris à
// 8/255 et non 7,5 : au bord, la marge va à la fumée perdue, jamais à la fuite.
// ⚠️ Deux versions l'ont d'abord cru autrement, chacune sur la foi d'un point isolé : la valeur « décodée » (elle taisait
// l'anneau des LED, 109 097 pixels), puis la valeur écrite telle quelle, seuil 0,5/255 (« 43 → 43 » ne valait qu'en un
// endroit de la courbe : 127 pixels de fuite à la lisière du noir). Une courbe se mesure par une rampe, jamais par un point.
//
// ⚠️ LES CINQ FONCTIONS CI-DESSOUS SONT CELLES DE `mur_iso.gdshader`, au caractère près : les déplacer dans un include
// commun aurait touché le mur du jeu et ses gardes d'identité (`tools/test_banc.gd`). `tools/test_iso_gadgets.gd` vérifie
// qu'elles n'ont pas divergé ; toute retouche du mur se reporte ici. Leurs uniformes portent les noms du mur, et
// `IsoVolumes._poser_masque` les recopie depuis le matériau même des murs : les mêmes valeurs, pas des valeurs voisines.

uniform float pied = 8.0;
uniform sampler2D texture_face : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float periode_face_px = 70.0;
uniform float force_matiere : hint_range(0.0, 1.0) = 0.0;
uniform float contact_px = 0.0;
uniform float contact_reste : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D grille_murs : filter_nearest, repeat_disable;
uniform bool grille_active = false;
uniform vec2 grille_origine_px = vec2(0.0);
uniform vec2 grille_cases = vec2(1.0);
uniform float tuile_px = 35.0;
uniform sampler2D peinture : source_color, filter_linear, repeat_disable;
uniform bool peinture_active = false;
uniform vec2 peinture_origine_px = vec2(0.0);
uniform vec2 peinture_taille_px = vec2(1.0);
uniform vec2 peinture_etalon_px = vec2(0.0);
uniform vec2 peinture_plancher_px = vec2(0.0);
// Les hauteurs des deux murs, en pixels de monde (`MapGeometry.HAUTEUR_MUR_HAUT`, `HAUTEUR_MUR_BAS` × la tuile).
uniform float mur_haut_px = 43.75;
uniform float muret_px = 14.0;
// Le SOL tel que `sol_iso.gdshader` l'écrit : ses réglages, préfixés `sol_` (le mur et la fumée ont déjà une matière et une
// température à eux), recopiés du matériau du sol ; le contact des corps garde ses noms et se recopie à chaque image.
uniform sampler2D sol_texture_sol : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float sol_periode_sol_px = 140.0;
uniform float sol_force_matiere : hint_range(0.0, 1.0) = 0.0;
uniform float sol_dalle_px = 70.0;
uniform float sol_joint_dalle_px = 1.2;
uniform float sol_joint_dalle_reste : hint_range(0.0, 1.0) = 0.6;
uniform float sol_temperature : hint_range(0.0, 1.0) = 0.0;
uniform float sol_temperature_seuil_bas : hint_range(0.0, 1.0) = 0.0;
uniform float sol_temperature_seuil_haut : hint_range(0.0, 1.0) = 0.0;
uniform float sol_neutre_avant_pate : hint_range(0.0, 1.0) = 0.0;
uniform vec3 contact_corps_1 = vec3(0.0);
uniform vec3 contact_corps_2 = vec3(0.0);
uniform float contact_corps_rayon_px = 0.0;
uniform float contact_corps_reste : hint_range(0.0, 1.0) = 1.0;
// La température des MURS (`mur_iso.gdshader`), préfixée `mur_`, recopiée du matériau des murs.
uniform float mur_temperature : hint_range(0.0, 1.0) = 0.0;
uniform float mur_temperature_seuil_bas : hint_range(0.0, 1.0) = 0.0;
uniform float mur_temperature_seuil_haut : hint_range(0.0, 1.0) = 0.0;
uniform float mur_neutre_avant_pate : hint_range(0.0, 1.0) = 0.0;
#ifdef USURE_ESSAI
// L'USURE, sous le MÊME interrupteur que le sol et les murs (`IsoMateriaux.usure_essai_active`, `--usure-essai`) : la
// variante masquée porte USURE_ESSAI si et seulement si le sol la porte (garde de parité, `tools/test_iso_gadgets.gd`).
// L'include sans `USURE_SOL` : la grille des murs est déjà déclarée ici ; la lecture de la proximité est recopiée plus bas.
#include "res://iso_usure.gdshaderinc"
uniform sampler2D usure_proximite : filter_nearest, repeat_disable;
// Le plus sombre que l'usure rende AU SOL : le cœur d'un gravat (`usure_sol` : `mix(1.0, 0.45, …)`, le grain ne descend
// pas sous 0,84 ; `USURE_RESTE` ne joue qu'aux murs). Lu dans le code avec ISO7 Beauté, gardé par la suite.
const float USURE_SOL_PLUS_SOMBRE = 0.45;
#endif
// Le point noir de l'écran 3D, en valeur ÉCRITE (voir l'en-tête) : 7/255 → 0, 8/255 → 1 ; pris à 8 (vers le silence).
const float POINT_NOIR_ECRIT = 8.0 / 255.0;
// Le glissement de la lecture du sol près des joints de tuile (`sol_iso.gdshader`, `px_lu`) : recopiés du matériau du sol.
uniform float dalles : hint_range(0.0, 1.0) = 0.0;
uniform float joint_2d_px = 1.0;

vec3 lire_etalon(vec2 px) {
	return texture(peinture, (px - peinture_origine_px) / peinture_taille_px).rgb;
}

vec3 lire_lumiere(vec2 px, bool deux, vec3 ref, float plancher) {
	vec3 l = lire_lightmap(px, deux);
	if (!peinture_active) {
		return l;
	}
	vec2 uv = (px - peinture_origine_px) / peinture_taille_px;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return l;
	}
	vec3 p = max(texture(peinture, uv).rgb, vec3(plancher));
	return min(l * ref / p, vec3(1.0));
}

vec3 lire_lumiere_moyenne(vec2 p, vec2 le_long, bool deux, vec3 ref, float plancher) {
	return 0.25 * (lire_lumiere(p - le_long * 1.875, deux, ref, plancher) + lire_lumiere(p - le_long * 0.625, deux, ref, plancher)
		+ lire_lumiere(p + le_long * 0.625, deux, ref, plancher) + lire_lumiere(p + le_long * 1.875, deux, ref, plancher));
}

vec3 lightmap_pateuse_lue(vec3 c, vec2 motif, float aa) {
	if (style == PATE_BRUTE) {
		return c;
	}
	float l = pate_luminance(c);
	if (l <= 0.0) {
		return vec3(0.0);
	}
	return pate(c, l, style, motif, vec2(0.0), l, aa);
}

vec2 occupe(vec2 px) {
	if (!grille_active) {
		return vec2(0.0);
	}
	vec2 uv = (px - grille_origine_px) / (tuile_px * grille_cases);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec2(0.0);
	}
	return textureLod(grille_murs, uv, 0.0).rg;
}

// Le contact des corps, RECOPIÉ de `sol_iso.gdshader` au caractère près (gardé par `tools/test_iso_gadgets.gd`).
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

#ifdef USURE_ESSAI
// La proximité des murs, RECOPIÉE de `iso_usure.gdshaderinc` (sa partie `USURE_SOL`) au caractère près.
float usure_mur_pres(vec2 px) {
	vec2 uv = (px - grille_origine_px) / (tuile_px * grille_cases);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	float v = textureLod(usure_proximite, uv, 0.0).r;
	return v >= 0.75 ? 1.0 : (v >= 0.25 ? 0.5 : 0.0);
}
#endif

// V1d — le niveau de mipmap qu'un `texture()` hors branche prendrait, calculé de dérivées EXPLICITES (`g_x`, `g_y`, en
// unités de texture) : log2 du plus long des deux gradients, en texels. `textureGrad` fait la même chose, mais coûtait,
// avec le reste de V1c, +0,7 ms par image de plus que V1b (série du 2026-09-25, 0,930) ; `textureLod` est la lecture la
// moins chère. V1e : la taille des deux matières (`assets/iso/sol.png`, `face_mur.png`, 512 px, dix niveaux de mipmap)
// est une constante — `textureSize` coûtait une requête par lecture ; `tools/test_iso_gadgets.gd` garde la taille.
const vec2 TAILLE_MATIERE = vec2(512.0);
float niveau_mip(vec2 g_x, vec2 g_y) {
	return max(0.0, log2(max(length(g_x * TAILLE_MATIERE), length(g_y * TAILLE_MATIERE))));
}

// Un pixel noir à l'écran : tous ses canaux ÉCRITS sous le point noir (voir l'en-tête).
bool ecran_noir(vec3 c) {
	return max(c.r, max(c.g, c.b)) < POINT_NOIR_ECRIT;
}

// La couleur que `sol_iso.gdshader` ÉCRIT au point `px` : ses lignes, RECOPIÉES dans leur ordre, les réglages préfixés
// `sol_` (gardé par `tools/test_iso_gadgets.gd`, qui compare ligne à ligne après ce préfixe). Deux écarts, déclarés :
// la pâte ne lit pas la pente de la lumière (le LAVIS, style du jeu, ne s'en sert pas) ; la neutralité se lit sur la
// lumière DÉJÀ LUE (`lu`, la même adresse que la ligne `lire_lightmap(px_lu, deux)` du sol : la même valeur, sans seconde
// lecture) ; le ton du damier vaut 1 (`IsoMateriaux.TON_EXPOSANT` à 0) ; et la matière se lit par `textureLod`, au
// niveau de mipmap (`niveau_mip`) des dérivées du sol lui-même (`g_x`, `g_y`, voir `derivee_sur_plan`) : lue ici dans une branche, `texture()` prendrait des
// dérivées implicites que le GPU ne définit pas, donc un niveau de mipmap qui n'est pas celui du sol. L'usure d'essai
// (`USURE_ESSAI`) est reprise telle quelle. `aa`, `px_monde` : ceux que le sol calcule (`fwidth` de son point).
vec3 sol_ecrit(vec2 px, bool deux, float aa, float px_monde, vec2 g_x, vec2 g_y) {
	float matiere = mix(1.0, textureLod(sol_texture_sol, px / sol_periode_sol_px,
		niveau_mip(g_x / sol_periode_sol_px, g_y / sol_periode_sol_px)).r, sol_force_matiere);
	vec2 dans_tuile = fract(px / tuile_px) * tuile_px;
	float marge = joint_2d_px + 0.5;
	vec2 glisse = step(dans_tuile, vec2(marge)) * marge - step(vec2(tuile_px - marge), dans_tuile) * marge;
	vec2 px_lu = px + glisse * dalles;
	vec2 dans_dalle = abs(fract(px / sol_dalle_px) - 0.5) * sol_dalle_px;
	float au_bord = sol_dalle_px * 0.5 - max(dans_dalle.x, dans_dalle.y);
	float joint = dalles * pate_trait_de_bord(au_bord, max(sol_joint_dalle_px, px_monde), px_monde);
	float dalle = mix(1.0, sol_joint_dalle_reste, joint);
	vec3 lu = lire_lightmap(px_lu, deux);
	float l = pate_luminance(lu);
	vec3 c = l <= 0.0 ? vec3(0.0) : pate(lu, l, style, px, vec2(0.0), l, aa);
	c = pate_facteur(c, matiere * dalle);
	if (sol_temperature_seuil_haut <= 0.0) {
		c = pate_temperature(c, sol_temperature);
	} else if (sol_neutre_avant_pate > 0.5) {
		vec3 brute = lu;
		c = pate_temperature_graduee_neutre(c, sol_temperature, sol_temperature_seuil_bas, sol_temperature_seuil_haut,
			pate_poids_neutre(brute));
	} else {
		c = pate_temperature_graduee(c, sol_temperature, sol_temperature_seuil_bas, sol_temperature_seuil_haut);
	}
#ifdef USURE_ESSAI
	c = pate_facteur(c, usure_poids(c, usure_sol(px, usure_mur_pres(px), px_monde)));
#endif
	c = pate_facteur(c, contact_des_corps(px));
	return c;
}

// V1b — LA BANDE : le sol exact ne se calcule que là où il peut basculer. Hors de la bande, deux certitudes suffisent :
// - NOIR à coup sûr si le canal le plus fort de la pâte × 1,4 reste sous le point noir : aucun facteur du sol ne le relève
//   (`pate_facteur(x, f) ≤ x` pour f ≤ 1), et la température le relève au plus de ×1,384 (un gris sous la teinte braise
//   pleine, force et poids à 1 ; calculé sur 21³ couleurs × 21 teintes × 21 forces, 2026-09-25) ;
// - VISIBLE à coup sûr si la luminance de la pâte × le plancher de la matière (1 − sa force : la tache la plus sombre de
//   `texture_sol` vaut 0) × le joint des dalles × le contact des corps, ces deux-là calculés exactement, atteint le point
//   noir : chaque facteur garde au moins sa part (`pate_facteur(x, f) ≥ f·x`, l'encodage sRGB étant concave et nul en 0),
//   la température garde la luminance, et un canal vaut au moins la luminance.
// Pile sur un seuil : au bas, « < » — l'égalité tombe dans la bande et se calcule ; en haut, « ≥ » — l'égalité donne une
// luminance au point noir, donc un canal à 8/255 au moins, que la rampe montre à 1. Entre les deux, `sol_ecrit`.
const float SOL_HAUSSE_MAX = 1.4;
bool sol_montre_noir_au_point(vec2 px, bool deux, float aa, float px_monde, vec2 g_x, vec2 g_y) {
	vec2 dans_tuile = fract(px / tuile_px) * tuile_px;
	float marge = joint_2d_px + 0.5;
	vec2 glisse = step(dans_tuile, vec2(marge)) * marge - step(vec2(tuile_px - marge), dans_tuile) * marge;
	vec3 lu = lire_lightmap(px + glisse * dalles, deux);
	float l = pate_luminance(lu);
	if (l <= 0.0) {
		return true;
	}
	vec3 c = pate(lu, l, style, px, vec2(0.0), l, aa);
	if (max(c.r, max(c.g, c.b)) * SOL_HAUSSE_MAX < POINT_NOIR_ECRIT) {
		return true;
	}
	vec2 dans_dalle = abs(fract(px / sol_dalle_px) - 0.5) * sol_dalle_px;
	float au_bord = sol_dalle_px * 0.5 - max(dans_dalle.x, dans_dalle.y);
	float joint = dalles * pate_trait_de_bord(au_bord, max(sol_joint_dalle_px, px_monde), px_monde);
	float dalle = mix(1.0, sol_joint_dalle_reste, joint);
	float plancher_sol = (1.0 - sol_force_matiere) * dalle * contact_des_corps(px);
#ifdef USURE_ESSAI
	plancher_sol *= mix(1.0, USURE_SOL_PLUS_SOMBRE, usure * smoothstep(USURE_SEUILS.x, USURE_SEUILS.y, pate_luminance(c)));
#endif
	if (pate_luminance(c) * plancher_sol >= POINT_NOIR_ECRIT) {
		return false;
	}
	return ecran_noir(sol_ecrit(px, deux, aa, px_monde, g_x, g_y));
}

// V1c — LES COUTURES DU SOL. Le sol n'est pas continu partout : `glisse` saute au bord de chaque tuile et à `marge` de
// part et d'autre (la lecture de la lumière passe d'un côté du joint 2D à l'autre), et l'usure d'essai tire ses éclats
// cellule de 6 px par cellule. Le sol et la couche calculent le même point à un millième de pixel près, pas au bit près :
// une rangée d'écran qui tombe PILE sur une couture — la caméra posée sur des coordonnées rondes en fait tomber des
// rangées entières — lit un côté au sol et l'autre dans le masque. Preuves du 2026-09-25 : rangées y = 313 et 361 (bords
// de tuile ou marges), 16 pixels de fuite sur deux lancements. MESURÉ (instrument, 18:27) : le point que la couche calcule
// est en retrait de 0,0026 px de monde en z sur celui du sol, partout, et de moins en x. À moins de `SOL_COUTURE_PX` d'une
// couture, la règle juge les deux points à ±`SOL_COUTURE_PX`, de part et d'autre, et le noir l'emporte (elle penche vers le
// silence) ; ailleurs, un seul point, comme avant. Pas plus loin : à 0,04 px, un pixel au bord du seuil (le sol y
// écrit 7/255, la rangée voisine 14) se jugeait déjà autrement que le sol — une fuite gardée, (1512, 313).
const float SOL_COUTURE_PX = 0.008;
// `d` : la position dans la tuile ; `x` : la coordonnée elle-même (les cellules de l'usure se comptent depuis 0).
float sol_couture(float d, float x, float marge) {
	float c = min(min(d, tuile_px - d), min(abs(d - marge), abs(d - (tuile_px - marge))));
#ifdef USURE_ESSAI
	float u = mod(x, 6.0);
	c = min(c, min(u, 6.0 - u));
#endif
	return c;
}
bool sol_montre_noir(vec2 px, bool deux, float aa, float px_monde, vec2 g_x, vec2 g_y) {
	vec2 dans_tuile = fract(px / tuile_px) * tuile_px;
	float marge = joint_2d_px + 0.5;
	vec2 e = vec2(sol_couture(dans_tuile.x, px.x, marge) < SOL_COUTURE_PX ? SOL_COUTURE_PX : 0.0,
		sol_couture(dans_tuile.y, px.y, marge) < SOL_COUTURE_PX ? SOL_COUTURE_PX : 0.0);
	if (e.x == 0.0 && e.y == 0.0) {
		return sol_montre_noir_au_point(px, deux, aa, px_monde, g_x, g_y);
	}
	return sol_montre_noir_au_point(px + e, deux, aa, px_monde, g_x, g_y)
		|| sol_montre_noir_au_point(px - e, deux, aa, px_monde, g_x, g_y)
		|| sol_montre_noir_au_point(px + vec2(e.x, -e.y), deux, aa, px_monde, g_x, g_y)
		|| sol_montre_noir_au_point(px + vec2(-e.x, e.y), deux, aa, px_monde, g_x, g_y);
}

// La dérivée d'écran du point où le rayon touche un plan de normale `n3`, tirée de celle de son origine sur la couche
// (`d` : le pas d'un pixel d'écran, tiré de la caméra ; toute composante le long de la vue s'annule ici). Caméra
// orthographique : le pixel voisin est le
// même rayon décalé de `d`, qui touche le plan décalé de `d` ramené le long de `vue`. Ce sont les dérivées que le sol ou
// le mur prennent eux-mêmes (`fwidth`, niveau de mipmap) — le masque, qui les lit dans une branche, les calcule.
vec3 derivee_sur_plan(vec3 d, vec3 vue, vec3 n3) {
	return d - vue * (dot(d, n3) / dot(vue, n3));
}

// La température des MURS sur une couleur de mur, comme `mur_iso.gdshader` la pose en dernier (réglages préfixés `mur_`).
vec3 mur_temperature_de(vec3 c, vec3 brute) {
	if (mur_temperature_seuil_haut <= 0.0) {
		return pate_temperature(c, mur_temperature);
	} else if (mur_neutre_avant_pate > 0.5) {
		return pate_temperature_graduee_neutre(c, mur_temperature, mur_temperature_seuil_bas, mur_temperature_seuil_haut,
			pate_poids_neutre(brute));
	}
	return pate_temperature_graduee(c, mur_temperature, mur_temperature_seuil_bas, mur_temperature_seuil_haut);
}

// La couleur qu'une FACE de mur ÉCRIT au point `e`, de normale `n` (vers le rayon) : la lumière moyennée à son pied, divisée
// par la peinture, passée à la pâte, × la matière de la face et le contact à son pied, puis la température — comme
// `mur_iso.gdshader`. Le lambert vaut 1 (`LAMBERT_PLANCHER`) ; l'encre ne rend jamais noire une face qui ne l'est pas sans
// elle (sous son plancher, `pate_matiere_et_encre` rend la matière seule ; au-dessus, elle ne descend pas sous lui).
// V1f — l'ÉCART DÉCLARÉ de la face : `aa` et `px_monde` sont ceux du SOL (le plan horizontal), et la matière se lit au
// niveau 0 de ses mipmaps, là où `mur_iso.gdshader` prend les siens par `fwidth` sur son propre point. V1e, qui les
// tirait des dérivées de la face, est sortie à 0,966, sous la règle des 3 % ; V1f, celle-ci, à 0,977 — mais avec la
// MÊME médiane masquée (84) : la différence est dans la référence, et ce que la face coûte n'est pas établi. V1e reste la
// meilleure candidate si une mesure plus fine la place sous 3 %. Aucune preuve à l'image n'a trouvé de faute sur une
// face lue ainsi (V1b, V1f), hors de la rangée où une couche démarre dans le mur, que le parcours corrige.
vec3 face_ecrite(vec3 e, vec2 n, bool deux, float aa, float haut, float px_monde) {
	vec2 tangente = vec2(-n.y, n.x);
	vec2 motif = vec2(dot(e.xz, tangente), -e.y);
	vec3 ref = lire_etalon(peinture_etalon_px);
	float plancher = lire_etalon(peinture_plancher_px).g;
	vec3 brute = lire_lumiere_moyenne(e.xz + n * pied, tangente, deux, ref, plancher);
	float matiere = mix(1.0, textureLod(texture_face, motif / periode_face_px, 0.0).r, force_matiere);
	float contact = contact_px > 0.0 ? mix(contact_reste, 1.0, smoothstep(0.0, contact_px, e.y)) : 1.0;
	vec3 c = pate_facteur(lightmap_pateuse_lue(brute, motif, aa), matiere * contact);
#ifdef USURE_ESSAI
	c = pate_facteur(c, usure_poids(c, usure_face(e.xz, n, tangente, e.y, haut, px_monde)));
#endif
	return mur_temperature_de(c, brute);
}

// Vrai si le pixel de la couche au point `monde`, vue le long de `vue` (caméra orthographique, vers la scène), montre du
// noir. Le rayon prolongé de la couche jusqu'au sol traverse la grille des murs CASE PAR CASE (un pas par frontière
// franchie) : la première case de mur où il passe sous la hauteur du mur dit que le pixel montre ce mur — par sa face,
// à la frontière exacte, ou par son dessus. Une couche monte au plus à une tuile (`VOLUME_FUSEE`) : son rayon parcourt
// moins d'une case au sol et franchit au plus deux frontières ; quatre cases suffisent.
// (Une première version échantillonnait le rayon en huit points fixes : huit lectures de la grille par pixel de fumée et
// par couche, souvent dans la même case, et l'entrée d'un mur connue à un pas près — +0,57 ms par image, contre +0,14.)
// Le dessus d'un mur de hauteur `haut` au point `q` : noir strict pour un mur haut (le liseré, un trait de 2,4 px, est
// l'exception déclarée) ; pour un muret, la pâte de la lumière à sa case, puis la température (`mur_iso.gdshader`).
bool dessus_montre_noir(vec3 q, float haut, bool deux, float aa) {
	if (haut >= mur_haut_px - 0.5) {
		return true;
	}
	vec3 l = lire_lightmap(q.xz, deux);
	float lum = pate_luminance(l);
	return lum <= 0.0 || ecran_noir(mur_temperature_de(pate(l, lum, style, q.xz, vec2(0.0), lum, aa), l));
}

// `d_x`, `d_y` : le pas d'un pixel d'écran dans le monde, tiré de la caméra (voir `volume_iso.gdshader`) — chaque surface
// jugée en tire ses propres dérivées (`derivee_sur_plan`).
bool masque_montre_noir(vec3 monde, vec3 vue, bool deux, vec3 d_x, vec3 d_y) {
	float t_sol = monde.y / max(-vue.y, 1e-3);
	vec2 a0 = (monde.xz - grille_origine_px) / tuile_px;
	vec2 dc = vue.xz * t_sol / tuile_px;
	vec2 cellule = floor(a0);
	vec2 pas = vec2(dc.x >= 0.0 ? 1.0 : -1.0, dc.y >= 0.0 ? 1.0 : -1.0);
	vec2 prochain = vec2(
		abs(dc.x) > 1e-6 ? ((dc.x > 0.0 ? cellule.x + 1.0 : cellule.x) - a0.x) / dc.x : 2.0,
		abs(dc.y) > 1e-6 ? ((dc.y > 0.0 ? cellule.y + 1.0 : cellule.y) - a0.y) / dc.y : 2.0);
	vec2 delta = vec2(abs(dc.x) > 1e-6 ? 1.0 / abs(dc.x) : 2.0, abs(dc.y) > 1e-6 ? 1.0 / abs(dc.y) : 2.0);
	// Les dérivées d'un plan HORIZONTAL (le sol, le dessus d'un muret) : le sol les prend par `fwidth(px)`.
	vec3 haut_n = vec3(0.0, 1.0, 0.0);
	vec2 g_x = derivee_sur_plan(d_x, vue, haut_n).xz;
	vec2 g_y = derivee_sur_plan(d_y, vue, haut_n).xz;
	float aa_sol = clamp((abs(g_x.x) + abs(g_y.x) + abs(g_x.y) + abs(g_y.y)) / 6.0, 0.02, 0.5);
	float px_monde_sol = max(abs(g_x.x) + abs(g_y.x), abs(g_x.y) + abs(g_y.y));
	float s = 0.0;
	int axe = -1;
	for (int i = 0; i < 4; i++) {
		float s_fin = min(min(prochain.x, prochain.y), 1.0);
		vec2 o = occupe(grille_origine_px + (cellule + 0.5) * tuile_px);
		float haut = o.r > 0.5 ? mur_haut_px : (o.g > 0.5 ? muret_px : 0.0);
		if (haut > 0.0) {
			float y_entree = monde.y * (1.0 - s);
			if (y_entree < haut) {
				if (axe < 0) {
					// V1c — la couche DÉMARRE dans la case d'un mur. Elle n'y passe le test de profondeur que sur la surface
					// du mur : la ligne où son plan coupe une face (rangée y = 605 des preuves du 2026-09-25, 21 pixels de
					// fumée perdue devant une face éclairée, quand on rendait « caché » ici). Le pixel montre la surface par
					// où le rayon, remonté vers la caméra, sort de la case : la plus proche des deux faces côté caméra, ou
					// le dessus. (Paramètres négatifs : en arrière du point.)
					vec2 s_face = vec2(
						abs(dc.x) > 1e-6 ? ((dc.x > 0.0 ? cellule.x : cellule.x + 1.0) - a0.x) / dc.x : -1e9,
						abs(dc.y) > 1e-6 ? ((dc.y > 0.0 ? cellule.y : cellule.y + 1.0) - a0.y) / dc.y : -1e9);
					float s_haut = 1.0 - haut / max(monde.y, 1e-3);
					if (s_haut >= max(s_face.x, s_face.y)) {
						return dessus_montre_noir(monde + vue * (t_sol * s_haut), haut, deux, aa_sol);
					}
					bool par_x = s_face.x >= s_face.y;
					vec2 n_face = par_x ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);
					return ecran_noir(face_ecrite(monde + vue * (t_sol * (par_x ? s_face.x : s_face.y)), n_face, deux,
						aa_sol, haut, px_monde_sol));
				}
				// Par une FACE, à la frontière franchie : sa normale regarde d'où vient le rayon.
				vec2 n = axe == 0 ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);
				return ecran_noir(face_ecrite(monde + vue * (t_sol * s), n, deux, aa_sol, haut, px_monde_sol));
			}
			// Au-dessus du mur à son bord : il y descend sous sa hauteur avant d'en sortir ? Alors par son DESSUS.
			float s_dessus = 1.0 - haut / max(monde.y, 1e-3);
			if (s_dessus <= s_fin) {
				return dessus_montre_noir(monde + vue * (t_sol * s_dessus), haut, deux, aa_sol);
			}
		}
		if (s_fin >= 1.0) {
			break;
		}
		if (prochain.x < prochain.y) {
			s = prochain.x;
			cellule.x += pas.x;
			prochain.x += delta.x;
			axe = 0;
		} else {
			s = prochain.y;
			cellule.y += pas.y;
			prochain.y += delta.y;
			axe = 1;
		}
	}
	vec2 p_sol = monde.xz + vue.xz * t_sol;
	// Le rayon touche le sol dans la case d'un mur alors que le parcours ne l'a pas vu y entrer (l'arrondi au franchissement
	// de la dernière frontière) : le pixel montre le bas de la face, pas le sol noir de la case. On juge cette face — la
	// frontière la plus proche du côté d'où vient le rayon. (Garde de précision. Elle fut posée pour la rangée y = 605 du
	// 2026-09-25, qui venait en fait d'une couche démarrant dans le mur, plus haut.)
	vec2 c_fin = floor((p_sol - grille_origine_px) / tuile_px);
	vec2 o_fin = occupe(grille_origine_px + (c_fin + 0.5) * tuile_px);
	if (max(o_fin.r, o_fin.g) > 0.5) {
		vec2 bord = grille_origine_px + c_fin * tuile_px;
		float dx = pas.x > 0.0 ? p_sol.x - bord.x : bord.x + tuile_px - p_sol.x;
		float dz = pas.y > 0.0 ? p_sol.y - bord.y : bord.y + tuile_px - p_sol.y;
		vec2 n = dx < dz ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);
		return ecran_noir(face_ecrite(vec3(p_sol.x, 0.0, p_sol.y), n, deux, aa_sol, o_fin.r > 0.5 ? mur_haut_px : muret_px,
			px_monde_sol));
	}
	// Le SOL, au bout du rayon, tel que `sol_iso.gdshader` l'écrit — calculé exactement dans la bande seulement (V1b), ses
	// deux côtés jugés sur une couture (V1c).
	return sol_montre_noir(p_sol, deux, aa_sol, px_monde_sol, g_x, g_y);
}
