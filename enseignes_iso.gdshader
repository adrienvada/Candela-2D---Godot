// Les enseignes et les panneaux muraux de la vue isométrique, EN ESSAI (`--enseignes-essai`, éteint par défaut) — le
// maillage fusionné de `enseignes_iso.gd` (un quadrilatère par enseigne), un par carte, un appel de dessin par vue 3D.
//
// ## La lumière : celle du pixel de face que l'enseigne recouvre, et aucune autre
//
// La lecture des tuyaux (`tuyaux_iso.gdshader`), sans leur modelé : chaque fragment prolonge le rayon de la caméra jusqu'au
// plan de la face qui porte l'enseigne (`couvert`), y relit la lumière exactement comme la face (`mur_iso.gdshader`, fonctions
// copiées mot pour mot, comparées par `tools/test_iso_enseignes.gd`), puis la MULTIPLIE, en valeur affichée, par le facteur
// de l'atlas (tôle, rouille, rivets, lettres, peinture : tous ≤ 1) plafonné par la matière la plus sombre d'une face
// (`matiere_max`). D'où, à l'écran : noir là où la face serait noire ; jamais plus clair que la face ; le bord d'une ombre au
// même pixel que sur la face derrière.
//
// Hors des lettres peintes, l'atlas est transparent : le fragment est jeté, la face se voit.
//
// ## Seulement sur les faces que la caméra voit
//
// Le tri des tuyaux : une face vue à plus de 60° de biais, de profil ou de dos, et son enseigne est écrasée en un point.
// Une enseigne ne cache donc que son mur, et n'est jamais vue de dos : jamais en miroir.
//
// Données par sommet (`enseignes_iso.gd`) : UV la place dans l'atlas, UV2 la normale de la face, CUSTOM0.x le plan de la
// face (`n · p = d`). `unshaded`, aucune Light3D, aucune ombre.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform float pied = 12.0;
uniform float seuil_face = 0.5;
// La matière la plus sombre qu'une face puisse porter (`TuyauxIso.matiere_max`) : le plafond de celle des enseignes.
uniform float matiere_max : hint_range(0.0, 1.0) = 1.0;
// Le contact au pied de la face, celui des murs, lu à la hauteur du point de face couvert.
uniform float contact_px = 0.0;
uniform float contact_reste : hint_range(0.0, 1.0) = 1.0;
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform float temperature_seuil_bas : hint_range(0.0, 1.0) = 0.0;
uniform float temperature_seuil_haut : hint_range(0.0, 1.0) = 0.0;
uniform float neutre_avant_pate : hint_range(0.0, 1.0) = 0.0;
// Instrument de banc (voir la fin de `fragment`).
uniform bool emprise_preuve = false;
// L'atlas des enseignes (`EnseignesIso.atlas_image`) : R le facteur (≤ 1), A la présence.
uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;

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
varying vec2 place;

void vertex() {
	vec2 n = UV2;
	face_n = n;
	place = UV;
	vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vers_camera = INV_VIEW_MATRIX[2].xyz;
	float horizontale = length(vers_camera.xz);
	float vue = horizontale > 0.0001 ? dot(n, vers_camera.xz / horizontale) : 0.0;
	float ecart = dot(monde.xz, n) - CUSTOM0.x;
	float approche = max(dot(vers_camera.xz, n), 0.0001);
	couvert = monde - vers_camera * (ecart / approche);
	if (vue < seuil_face) {
		// Face de profil ou de dos pour CETTE caméra : toute l'enseigne en un point, aucun pixel.
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec4 texel = texture(atlas, place);
	if (texel.a < 0.5) {
		// Hors des lettres peintes : le mur.
		discard;
	}
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 n = face_n;
	vec2 tangente = vec2(-n.y, n.x);
	vec2 motif = vec2(dot(couvert.xz, tangente), -couvert.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	vec3 peinture_ref = lire_etalon(peinture_etalon_px);
	float peinture_min = lire_etalon(peinture_plancher_px).g;
	vec3 brute = lire_lumiere_moyenne(couvert.xz + n * pied, tangente, deux, peinture_ref, peinture_min);
	vec3 c = lightmap_pateuse_lue(brute, motif, aa);
	float contact = contact_px > 0.0 ? mix(contact_reste, 1.0, smoothstep(0.0, contact_px, couvert.y)) : 1.0;
	// Le facteur de l'atlas plafonné par la matière la plus sombre d'une face : jamais plus clair que la face derrière.
	// Sans encre (t = 0) : `pate_matiere_et_encre` ne fait que multiplier la valeur affichée.
	c = pate_matiere_et_encre(c, min(texel.r, 1.0) * matiere_max * contact, 1.0, 0.0, 0.0);
	if (temperature_seuil_haut <= 0.0) {
		c = pate_temperature(c, temperature);
	} else if (neutre_avant_pate > 0.5) {
		c = pate_temperature_graduee_neutre(c, temperature, temperature_seuil_bas, temperature_seuil_haut,
			pate_poids_neutre(brute));
	} else {
		c = pate_temperature_graduee(c, temperature, temperature_seuil_bas, temperature_seuil_haut);
	}
	ALBEDO = c;
	// INSTRUMENT DE BANC : l'emprise des enseignes à l'écran, en blanc, pour que la planche compte le noir SUR elles. Jamais
	// vrai en jeu : `EnseignesIso.accorder` le pose à faux, et la garde le vérifie.
	if (emprise_preuve) {
		ALBEDO = vec3(1.0);
	}
}
