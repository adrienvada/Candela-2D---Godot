// Les murs de la vue isométrique (ISO1, habillés par ISO7) : faces allumées par la lightmap lue
// AU PIED du mur, matière et encre d'arête ; sommet des murs hauts noir cerné d'un liseré ;
// dessus des murets lu à sa propre case.
//
// Une face verticale prend la lumière du sol à `pied` pixels devant elle — pas zéro :
// la case du mur est noire dans la lightmap et son liseré d'encre en occupe le bord
// (occluders rentrés de 3 px, `MapGeometry.OCCLUDER_INSET`). C'est ce qui rend la face
// SYMÉTRIQUE entre les deux joueurs : elle s'allume si et seulement si le sol à son
// pied s'allume, là où une vraie lumière 3D ne dessinerait que chez le joueur côté
// caméra (étude ISO0, § 5.2). Hors du rectangle couvert par la vue 2D, du noir.
//
// ISO2 : les murs sont COMMUNS aux deux caméras de l'écran scindé ; chaque caméra lit
// la lightmap de son joueur (`lightmap_de_j2`). Une face vue par J1 s'allume avec la
// lumière de J1 seulement — jamais avec le halo de J2.
//
// ## ISO7 — l'habillage, et pourquoi il ne dit rien de plus que la lightmap
//
// Tout ce qui s'ajoute ici MULTIPLIE une lumière lue dans la lightmap du joueur :
// - **la matière** (`texture_face`) : un facteur dans [0,43 ; 1] accroché aux coordonnées du
//   MONDE (identique pour les deux joueurs), jamais une couleur ;
// - **l'encre des arêtes** : un facteur `encre_arete_reste` sur un trait le long des bords de
//   la face — « un mur n'est pas une surface, c'est une masse cernée d'un filament » (Adrien,
//   2026-08-25) ;
// - **le liseré du sommet** d'un mur haut : la lumière de la face qu'il couronne, sur un trait
//   de `lisere_sommet_px` ; l'intérieur du sommet reste noir strict, la masse ;
// - **le dessus d'un muret** : la lightmap À SA CASE — les hachures que la vue de dessus y
//   dessine sous la lumière (dessin gardé au jalon H-MB0).
// Donc 0 à lumière 0, partout (prouvé au pixel par `tools/banc_iso_beaute.gd`).
//
// ⚠️ **Une boîte n'est pas un mur.** `merge_rects` découpe une masse en plusieurs rectangles
// jointifs : une arête verticale de boîte peut tomber au milieu d'une face continue, et un bord
// de sommet au milieu d'un sommet. La grille des murs (`grille_murs`, une case par tuile, posée
// par `IsoMateriaux.accorder_grille`) dit si la masse continue au-delà du bord : si oui, ni
// encre ni liseré. Sans elle, chaque mur en L portait un trait noir en travers de sa face.
//
// ⚠️ Les dérivées (mipmaps de la matière, `fwidth`) se prennent HORS de tout branchement.
//
// Défauts : force de matière 0, aucune encre, aucun liseré, grille inactive — le mur d'ISO1.
// `unshaded`, aucune Light3D.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform float pied = 8.0;

uniform sampler2D texture_face : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float periode_face_px = 70.0;
uniform float force_matiere : hint_range(0.0, 1.0) = 0.0;
uniform float encre_arete_px = 0.0;
uniform float encre_arete_reste : hint_range(0.0, 1.0) = 0.12;
// Sous ce plancher (valeur affichée), l'encre n'éteint rien : une face à peine éclairée garde sa lumière.
uniform float encre_plancher_affiche : hint_range(0.0, 1.0) = 0.0;
// ISO7b — la face prend la DIRECTION de la lumière (gradient de la lightmap devant elle) : plancher 1 = éteint.
uniform float lambert_plancher : hint_range(0.0, 1.0) = 1.0;
uniform float lambert_pas_px = 35.0;
// ISO7b — l'ombre de contact au pied de la face : hauteur en px de monde, et ce qu'elle garde au ras du sol.
uniform float contact_px = 0.0;
uniform float contact_reste : hint_range(0.0, 1.0) = 1.0;
uniform float lisere_sommet_px = 0.0;
uniform float seuil_muret_px = 26.0;
// ISO7, étape 6 — la teinte chaude de la lumière neutre, luminance gardée (`pate_temperature`).
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
// ISO7b — la température graduée par la luminance affichée (chaude au bord du bain, neutre au centre).
uniform float temperature_seuil_bas : hint_range(0.0, 1.0) = 0.0;
uniform float temperature_seuil_haut : hint_range(0.0, 1.0) = 0.0;
// ISO7b — 1 : la neutralité qui dose la chaleur se lit sur la lightmap AVANT la pâte (`pate_poids_neutre`), et une
// lumière colorée garde sa teinte. 0 : mesurée après la pâte, comme au commit db26c43 (le halo de fusée jaunissait).
uniform float neutre_avant_pate : hint_range(0.0, 1.0) = 0.0;

// La grille des murs : R = mur haut, G = muret ; un texel par tuile, bordure comprise.
uniform sampler2D grille_murs : filter_nearest, repeat_disable;
uniform bool grille_active = false;
uniform vec2 grille_origine_px = vec2(0.0);
uniform vec2 grille_cases = vec2(1.0);
uniform float tuile_px = 35.0;

varying vec3 monde;
varying vec3 normale;
varying vec3 local;
varying vec3 taille;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Boîtes alignées sur les axes : l'échelle non uniforme ne tourne pas une normale
	// d'axe, la normaliser suffit.
	normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Le cube unité (`IsoGeometrie.build_meshes`) : VERTEX dans [-0,5 ; 0,5], l'échelle porte la
	// taille de la boîte en pixels de monde.
	local = VERTEX;
	taille = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}

// ISO7b — la lumière d'un pied de face : `lightmap_pateuse` (iso_lightmap.gdshaderinc) sur une lecture MOYENNÉE
// le long de la face, sur une période des hachures de `MurEncre`. ⚠️ Lue en un seul point à 8 px devant la face,
// la lumière tombait dans la bande de hachures d'encre dessinée au pied de chaque mur (45°, pas de 5 px, portée
// jusqu'à 9,6 px) : chaque colonne de la face lisait tour à tour une hachure et un creux, et la face portait des
// rayures verticales régulières (période mesurée : 6 px d'écran, amplitude 30 niveaux, 2026-09-15). Pied porté à
// 12 px (au-delà des hachures) et quatre lectures sur une période : la moyenne ne déplace aucune ombre de plus
// de 2 px le long du mur. La pente est nulle (la pâte D, celle du jeu, ne la lit pas).
// La lecture et la pâte sont deux fonctions : la lumière lue sert aussi à la neutralité de la chaleur, sans relire.
//
// ISO10, 1f — **la face lit la LUMIÈRE, pas le sol peint.** La lightmap est le sol peint × la lumière : une tache de sang
// au pied d'un mur y est rouge, et la face la lisait rouge. `peinture` est la peinture de la carte sans lumière
// (`peinture_iso.gd`), en espace MONDE : une texture pour toute la carte, la même pour les deux vues.
uniform sampler2D peinture : source_color, filter_linear, repeat_disable;
uniform bool peinture_active = false;
uniform vec2 peinture_origine_px = vec2(0.0);
uniform vec2 peinture_taille_px = vec2(1.0);
// Les deux étalons PEINTS dans la peinture (`peinture_iso.gd`) : la couleur moyenne du sol dessiné, et le gris du plancher
// (0,05 affiché). Lus par la même texture que la peinture, ils sont dans le même espace de couleur qu'elle — une référence
// calculée côté processeur en linéaire assombrissait les faces de six fois (troisième passage en jeu).
uniform vec2 peinture_etalon_px = vec2(0.0);
uniform vec2 peinture_plancher_px = vec2(0.0);

vec3 lire_etalon(vec2 px) {
	return texture(peinture, (px - peinture_origine_px) / peinture_taille_px).rgb;
}

// La lumière d'un point du sol sans sa peinture : lightmap × référence ÷ max(peinture, plancher), canal par canal. La
// référence rend à la face sa valeur d'avant sur un sol propre ; sous une tache, la même. Noir absolu : une lightmap nulle
// rend 0. Une lumière rouge (fusée) reste au numérateur, donc rouge. Plafonnée à 1 : une peinture plus sombre que la
// référence sous une forte lumière n'éclaircit pas au-delà du blanc.
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

// Chaque lecture est divisée AVANT la moyenne : un rapport de moyennes n'est pas une moyenne de rapports, et l'écart se
// lisait aux coins (mesure de 1f : 64 à 72 % au bout de la bande, où le bord du cône et l'encre du mur se mêlent).
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

// La masse continue-t-elle au point `px` du sol ? R : mur haut, G : muret. Hors de la grille,
// rien (la ceinture de la carte est une fosse, pas un mur).
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

// ISO13, lot C — l'usure en essai (`--usure-essai`) : compilée seulement dans la variante USURE_ESSAI.
#include "res://iso_usure.gdshaderinc"

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec3 an = abs(normale);
	vec2 n = normale.xz;
	float longueur = length(n);
	n = longueur > 0.0001 ? n / longueur : vec2(0.0, 1.0);
	vec2 tangente = vec2(-n.y, n.x);
	// Le motif court le long de la face et en hauteur : une hachure de mur se lit
	// debout, pas couchée. Sur un dessus, il se couche avec le sol.
	vec2 motif = normale.y > 0.5 ? monde.xz : vec2(dot(monde.xz, tangente), -monde.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	// Pixels de monde par pixel d'écran : le trait ne descend jamais sous un pixel d'écran.
	float px_monde = max(max(fwidth(monde.x), fwidth(monde.y)), fwidth(monde.z));
	float matiere = mix(1.0, texture(texture_face, vec2(dot(monde.xz, tangente), -monde.y) / periode_face_px).r,
		force_matiere);
	// Distance aux bords de la boîte, axe par axe, en pixels de monde.
	vec3 d = (0.5 - abs(local)) * taille;

	vec3 c = vec3(0.0);
	// La lumière REÇUE, avant la pâte : elle seule dit si la lumière est neutre (voir `pate_poids_neutre`).
	vec3 brute = vec3(0.0);
	// ISO10, 1f — les étalons de la peinture, lus une fois par fragment, hors de tout branchement.
	vec3 peinture_ref = lire_etalon(peinture_etalon_px);
	float peinture_min = lire_etalon(peinture_plancher_px).g;
	if (normale.y < -0.5) {
		// Dessous : jamais vu, noir.
		c = vec3(0.0);
	} else if (normale.y > 0.5) {
		// Le bord le plus proche du sommet, et la direction qui en sort.
		bool bord_x = d.x < d.z;
		float d_bord = bord_x ? d.x : d.z;
		vec2 sortie = bord_x ? vec2(sign(local.x), 0.0) : vec2(0.0, sign(local.z));
		vec2 au_dela = occupe(monde.xz + sortie * (d_bord + tuile_px * 0.5));
		if (taille.y < seuil_muret_px) {
			// Dessus de muret : la lightmap à sa case, cernée d'encre là où le muret finit.
			brute = lire_lightmap(monde.xz, deux);
			c = lightmap_pateuse(monde.xz, motif, aa, deux);
			float fin = 1.0 - max(au_dela.r, au_dela.g);
			float largeur = max(encre_arete_px, px_monde);
			c = pate_matiere_et_encre(c, 1.0, encre_arete_reste, fin * pate_trait_de_bord(d_bord, largeur, px_monde), encre_plancher_affiche);
		} else {
			// Sommet de mur haut : noir strict, sauf le liseré — la lumière de la face qu'il couronne.
			float fin = 1.0 - au_dela.r;
			float largeur = max(lisere_sommet_px, px_monde);
			float lisere = fin * pate_trait_de_bord(d_bord, largeur, px_monde);
			if (lisere > 0.0) {
				brute = lire_lumiere_moyenne(monde.xz + sortie * (d_bord + pied), vec2(-sortie.y, sortie.x), deux, peinture_ref, peinture_min);
				c = pate_facteur(lightmap_pateuse_lue(brute, motif, aa), lisere);
			}
		}
	} else {
		// Face verticale : la lumière au pied, la matière, l'encre des arêtes.
		// ⚠️ **L'encre ne se CUMULE pas avec la matière.** Multipliées, 12 % d'encre sur une tache à 43 %
		// laissaient 5 % de la lumière : au banc, 1 237 pixels éclairés (25 à 40/255) tombaient au noir
		// sur les arêtes d'une face à peine allumée — une lumière réelle effacée. Sur le trait, le facteur
		// est le plus petit des deux, jamais leur produit : plancher `encre_arete_reste`.
		brute = lire_lumiere_moyenne(monde.xz + n * pied, tangente, deux, peinture_ref, peinture_min);
		c = lightmap_pateuse_lue(brute, motif, aa);
		// ISO7b — **la direction de la lumière se lit dans la lightmap elle-même** (aucune Light3D) : son
		// gradient DEVANT la face et le long d'elle, jamais derrière — derrière, c'est l'ombre du mur lui-même,
		// qui ferait croire que toute face regarde la lampe. Composante « vers l'avant » positive : la lumière
		// monte en s'éloignant du mur, la source est en face. Le facteur ne fait qu'assombrir une face de profil
		// (plancher `lambert_plancher`), et seulement quand la direction est franche (`certitude`) : sous une
		// lumière uniforme, la face garde sa lumière. La lightmap reste la seule vérité de visibilité : une face
		// que la lumière n'atteint pas est noire, quel que soit ce facteur.
		float lambert = 1.0;
		if (lambert_plancher < 1.0) {
			vec2 pied_px = monde.xz + n * pied;
			float l_0 = pate_luminance(lire_lightmap(pied_px, deux));
			float l_avant = pate_luminance(lire_lightmap(pied_px + n * lambert_pas_px, deux));
			float l_t1 = pate_luminance(lire_lightmap(pied_px + tangente * lambert_pas_px, deux));
			float l_t2 = pate_luminance(lire_lightmap(pied_px - tangente * lambert_pas_px, deux));
			vec2 g = vec2(l_avant - l_0, 0.5 * (l_t1 - l_t2));
			float norme = length(g);
			float face_lampe = norme > 0.00001 ? clamp(g.x / norme, 0.0, 1.0) : 1.0;
			float certitude = smoothstep(0.05, 0.3, norme / max(max(l_0, l_avant), 0.02));
			lambert = mix(1.0, max(lambert_plancher, face_lampe), certitude);
		}
		// ISO7b — le contact : une bande qui s'assombrit vers le pied de la face.
		float hauteur_face = (local.y + 0.5) * taille.y;
		float contact = contact_px > 0.0 ? mix(contact_reste, 1.0, smoothstep(0.0, contact_px, hauteur_face)) : 1.0;
		// L'arête verticale de CETTE face : sur l'axe tangent à la face.
		bool face_x = an.x > 0.5;
		float d_vert = face_x ? d.z : d.x;
		vec2 axe = face_x ? vec2(0.0, sign(local.z)) : vec2(sign(local.x), 0.0);
		// Une demi-tuile au-delà du bord, une demi-tuile DANS le mur : une case de masse, ou non.
		vec2 au_dela = occupe(monde.xz + axe * (d_vert + tuile_px * 0.5) - n * tuile_px * 0.5);
		float largeur = max(encre_arete_px, px_monde);
		float encre_h = encre_arete_px > 0.0 ? pate_trait_de_bord(d.y, largeur, px_monde) : 0.0;
		float encre_v = encre_arete_px > 0.0
			? (1.0 - max(au_dela.r, au_dela.g)) * pate_trait_de_bord(d_vert, largeur, px_monde) : 0.0;
		// Le facteur se pose sur la valeur AFFICHÉE (`pate_facteur`) : posé dans l'espace du shader, un
		// reste de 0,25 se voyait à 0,036 (mesuré au banc).
		c = pate_matiere_et_encre(c, matiere * lambert * contact, encre_arete_reste, max(encre_h, encre_v),
			encre_plancher_affiche);
#ifdef USURE_ESSAI
		c = pate_facteur(c, usure_poids(c, usure_face(monde.xz, n, tangente, hauteur_face, taille.y, px_monde)));
#endif
	}
	// ISO7, étape 6 — la teinte chaude de la lumière neutre, luminance gardée : 0 reste 0.
	// ISO7b — graduée : `temperature_seuil_haut` à 0 rend la température d'ISO7 (teinte chaude partout) ; la
	// neutralité lue avant la pâte (`neutre_avant_pate`) garde sa teinte à une lumière colorée.
	if (temperature_seuil_haut <= 0.0) {
		c = pate_temperature(c, temperature);
	} else if (neutre_avant_pate > 0.5) {
		c = pate_temperature_graduee_neutre(c, temperature, temperature_seuil_bas, temperature_seuil_haut,
			pate_poids_neutre(brute));
	} else {
		c = pate_temperature_graduee(c, temperature, temperature_seuil_bas, temperature_seuil_haut);
	}
	ALBEDO = c;
}
