shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, blend_mix, depth_draw_never;

// ISO13, lot B — LE CONTOUR DES PERSONNAGES (essai d'ISO7 Beauté, 2026-09-24, derrière `--encre-essai`, éteint).
//
// La session cloud (00:56) : « à l'échelle du jeu, c'est le CONTOUR des personnages qui portera la lecture, plus que des lignes
// intérieures ». L'encre d'arête d'ISO3 trace toutes les arêtes des boîtes, à l'intérieur de la silhouette ; ce shader
// trace la silhouette elle-même, par une COQUE : chaque boîte est redessinée, faces arrière seules, agrandie de
// `contour_unites` de chaque côté, en noir. Le corps, dessiné devant, en cache l'intérieur ; il n'en reste qu'un liseré noir
// autour de la silhouette et de chaque membre qui passe devant un autre (le coude sur le torse : l'articulation des
// mannequins). Passe suivante (`next_pass`) de la matière des corps : même maillage, même transform, aucun nœud de plus.
//
// ⚠️ **Les faces verticales de la coque seulement** (planche du 2026-09-24, 01:49) : sa face DE DESSOUS débordait sous le torse,
// devant les jambes, moins profondes que lui, et traçait vue d'en haut une ceinture noire en travers du corps — 20 à 34 % des
// pixels visibles perdus au bord de la lumière. Sans les faces horizontales, le liseré reste autour de la silhouette (les
// faces verticales, agrandies en hauteur, dépassent au-dessus des épaules et sous les pieds) et ne passe plus devant une
// autre boîte du corps.
// ⚠️ **Même opacité que le corps, formule pour formule** (`corps_iso_profondeur.gdshader`) : un adversaire effacé par
// l'éblouissement du regardeur (opacité 0) ne doit pas réapparaître par son contour. Noir, jamais rien d'éclairé : dans le
// noir, un liseré noir sur du noir ne montre rien.

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

// L'épaisseur du liseré, en unités du modèle (tuiles) ; 0 : rien.
uniform float contour_unites = 0.0;
uniform float opacite_1 = 1.0;
uniform float opacite_2 = 1.0;

varying vec3 normale_coque;

void vertex() {
	normale_coque = NORMAL;
	// Nos boîtes sont centrées sur leur nœud : pousser chaque sommet de `contour_unites` vers l'extérieur, axe par axe, agrandit
	// la boîte sans ouvrir ses coins (une poussée le long des normales, dupliquées par face, les ouvrirait).
	VERTEX += sign(VERTEX) * contour_unites;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	float o = clamp(deux ? opacite_2 : opacite_1, 0.0, 1.0);
	if (contour_unites <= 0.0 || o <= 0.0001 || abs(normale_coque.y) > 0.5) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = o;
}
