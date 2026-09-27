// Les tuyaux et les câbles des murs de la vue isométrique, EN ESSAI (`--tuyaux-essai`, éteint par défaut) — le maillage
// fusionné de `tuyaux_iso.gd`, un par carte, un appel de dessin par vue 3D.
//
// ## La lumière : celle du pixel de face que le tuyau recouvre, et aucune autre
//
// Un tuyau n'a pas de lumière à lui. Chaque fragment prolonge le rayon de la caméra jusqu'au plan de la face qui porte le
// tuyau (`couvert`) : c'est le point de face que CE pixel montrerait sans le tuyau. Il y relit la lumière exactement comme la
// face (`mur_iso.gdshader` : `lire_lumiere_moyenne` au pied de la face, puis `lightmap_pateuse_lue` — mêmes fonctions, copiées
// mot pour mot, et `tools/test_iso_tuyaux.gd` rougit si elles divergent), puis ne fait que la MULTIPLIER, en valeur affichée,
// par un facteur ≤ 1 (`pate_matiere_et_encre`) : sa matière, son modelé, son encre. D'où, à l'ÉCRAN :
// - **noir absolu** : là où la face serait noire, le tuyau l'est — 0 × facteur = 0 ;
// - **le bord de l'ombre reste net** : il passe au même pixel que sur la face derrière ;
// - **jamais plus clair que la face qu'il recouvre** : sa matière est plafonnée par la plus sombre qu'une face porte
//   (`matiere_max`), et il ne descend jamais sous le sol à son pied (`TuyauxIso.hauteur_bas_px`) — la règle de l'usure,
//   « rien n'est jamais plus clair qu'avant ». Seules exceptions : l'encre des arêtes de la face et l'usure, qui assombrissent
//   la face là où un tuyau passe devant.
// ⚠️ Lire au point d'attache du tuyau, dans le monde, ne suffisait pas : à 45° de lacet, le tuyau couvre à l'écran un point
// de face décalé de sa saillie le long de la face (la parallaxe des volumes, « Pièges connus », 2026-09-24).
//
// ## Seulement sur les faces que la caméra voit
//
// `INV_VIEW_MATRIX[2]` est la direction vers la caméra qui dessine (chaque vue a la sienne : l'écran scindé dessine deux
// fois). Une face vue à plus de 60° de biais (`seuil_face`), de profil ou de dos : ses tuyaux sont écrasés en un point
// (triangles d'aire nulle, rien n'est tramé). Rien ne se dessine donc hors du dessin de la face : le tuyau ne cache que le
// mur. Le miroir processeur de ce tri est `TuyauxIso.face_dessinee`.
//
// Données par sommet (`tuyaux_iso.gd`) : UV.x le plan de la face (`n · p = d`), UV.y la matière, UV2 la normale de la face.
// `unshaded`, aucune Light3D, aucune ombre.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform float pied = 12.0;
// cos 60° : sous ce produit scalaire entre la normale de la face et la direction de la caméra, rien ne se dessine.
uniform float seuil_face = 0.5;
// Le modelé par la caméra : combien d'encre prend le corps du tuyau hors de son reflet (0 : aucun, 1 : tout le reste).
uniform float corps_sombre : hint_range(0.0, 1.0) = 0.9;
// L'encre du contour et du corps : ce qu'elle garde, et le plancher sous lequel elle n'éteint rien (« allumé reste allumé »).
uniform float encre_reste : hint_range(0.0, 1.0) = 0.25;
// La matière la plus sombre qu'une face puisse porter (`TuyauxIso.matiere_max`) : le plafond de celle des tuyaux.
uniform float matiere_max : hint_range(0.0, 1.0) = 1.0;
uniform float encre_plancher_affiche : hint_range(0.0, 1.0) = 0.0;
// Le contact au pied de la face, celui des murs, lu à la hauteur du point de face couvert.
uniform float contact_px = 0.0;
uniform float contact_reste : hint_range(0.0, 1.0) = 1.0;
// La température, celle des murs (`IsoMateriaux.accorder_mur`).
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform float temperature_seuil_bas : hint_range(0.0, 1.0) = 0.0;
uniform float temperature_seuil_haut : hint_range(0.0, 1.0) = 0.0;
uniform float neutre_avant_pate : hint_range(0.0, 1.0) = 0.0;
// Instrument de banc (voir la fin de `fragment`).
uniform bool emprise_preuve = false;

// ISO10, 1f — la peinture de la carte sans lumière, posée comme sur le matériau des murs (`IsoMateriaux.accorder_peinture`).
uniform sampler2D peinture : source_color, filter_linear, repeat_disable;
uniform bool peinture_active = false;
uniform vec2 peinture_origine_px = vec2(0.0);
uniform vec2 peinture_taille_px = vec2(1.0);
uniform vec2 peinture_etalon_px = vec2(0.0);
uniform vec2 peinture_plancher_px = vec2(0.0);

// ---------------------------------------------------------------------------
// LA LECTURE DE LA FACE — copiée mot pour mot de `mur_iso.gdshader` (la garde compare les deux textes)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------

// Le point de face que le sommet recouvre à l'écran (le rayon de la caméra prolongé jusqu'au plan de la face). La caméra
// est orthographique : il est affine en la position, donc exact une fois interpolé.
varying vec3 couvert;
varying flat vec2 face_n;
varying float albedo;

void vertex() {
	vec2 n = UV2;
	face_n = n;
	albedo = UV.y;
	vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vers_camera = INV_VIEW_MATRIX[2].xyz;
	float horizontale = length(vers_camera.xz);
	float vue = horizontale > 0.0001 ? dot(n, vers_camera.xz / horizontale) : 0.0;
	// Devant la face de `ecart` ; le rayon s'en approche de `approche` par unité parcourue vers le fond de l'écran.
	float ecart = dot(monde.xz, n) - UV.x;
	float approche = max(dot(vers_camera.xz, n), 0.0001);
	couvert = monde - vers_camera * (ecart / approche);
	if (vue < seuil_face) {
		// Face de profil ou de dos pour CETTE caméra : tout le tuyau en un point, aucun pixel.
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 n = face_n;
	vec2 tangente = vec2(-n.y, n.x);
	// Le motif et l'anticrénelage de la face, au point qu'elle montrerait ici : la pâte tombe dans les mêmes bandes.
	vec2 motif = vec2(dot(couvert.xz, tangente), -couvert.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	// Les étalons de la peinture, lus une fois par fragment, hors de tout branchement (comme la face).
	vec3 peinture_ref = lire_etalon(peinture_etalon_px);
	float peinture_min = lire_etalon(peinture_plancher_px).g;
	vec3 brute = lire_lumiere_moyenne(couvert.xz + n * pied, tangente, deux, peinture_ref, peinture_min);
	vec3 c = lightmap_pateuse_lue(brute, motif, aa);
	// Le modelé et l'encre du tuyau, par la caméra : un reflet le long de l'axe tourné vers elle, un corps sombre, un trait
	// d'encre au contour — le tuyau des illustrations. Le corps passe par l'ENCRE et non par la matière : il profite de son
	// plancher (« allumé reste allumé » : au-dessus de `encre_plancher_affiche`, jamais sous lui). Un facteur, jamais une lumière.
	float face_camera = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float reflet = smoothstep(0.88, 0.99, face_camera);
	float contour = 1.0 - smoothstep(0.12, 0.38, face_camera);
	float encre = max(contour, corps_sombre * (1.0 - reflet));
	float contact = contact_px > 0.0 ? mix(contact_reste, 1.0, smoothstep(0.0, contact_px, couvert.y)) : 1.0;
	// La matière plafonnée par la plus sombre qu'une face puisse porter : le tuyau n'est jamais plus clair que la face derrière.
	c = pate_matiere_et_encre(c, min(albedo, matiere_max) * contact, encre_reste, encre, encre_plancher_affiche);
	// La température des murs, lue sur la même lumière reçue : 0 reste 0.
	if (temperature_seuil_haut <= 0.0) {
		c = pate_temperature(c, temperature);
	} else if (neutre_avant_pate > 0.5) {
		c = pate_temperature_graduee_neutre(c, temperature, temperature_seuil_bas, temperature_seuil_haut,
			pate_poids_neutre(brute));
	} else {
		c = pate_temperature_graduee(c, temperature, temperature_seuil_bas, temperature_seuil_haut);
	}
	ALBEDO = c;
	// INSTRUMENT DE BANC, comme `masque_preuve` des matériaux éclairés : l'emprise des tuyaux à l'écran, en blanc, pour que
	// la planche compte le noir SUR les tuyaux (un zéro doit être vérifié non vide). Jamais vrai en jeu : `TuyauxIso.accorder`
	// le pose à faux, et la garde le vérifie.
	if (emprise_preuve) {
		ALBEDO = vec3(1.0);
	}
}
