// La lightmap de la vue isométrique (ISO1) — la sous-vue 2D regardée, lue au point
// du monde qu'elle a rendu.
//
// La lecture passe par la transformation de canevas de cette vue, exactement celle
// qui l'a rendue : aucune hypothèse sur la caméra 2D, secousse et zoom compris. Même
// formule, côté processeur : `CameraIso.uv_de()`. Hors du rectangle couvert, du noir :
// ce que la vue de dessus ne montre pas, l'iso ne l'invente pas.
//
// `source_color` : la texture de la vue est en sRGB, la sortie 3D aussi ; l'aller-retour
// a été vérifié au pixel à 90° contre la vue de dessus (banc ISO0.b).
//
// Exige `iso_pate.gdshaderinc` inclus AVANT.

uniform sampler2D lumiere : source_color, filter_linear, repeat_disable;
uniform vec2 canevas_x = vec2(1.0, 0.0);
uniform vec2 canevas_y = vec2(0.0, 1.0);
uniform vec2 canevas_o = vec2(0.0);
uniform vec2 taille_2d = vec2(1920.0, 1080.0);

// Pas de la pente lue par la pâte, en pixels de monde.
const float LIGHTMAP_PAS_PX = 3.0;

// La couche 3D que seule la caméra de J2 voit (`Presentation3D.CALQUE_VUE_2`) — nom et
// valeur repris tels quels d'ISO2 (`iso2-vues`, `iso_lightmap.gdshaderinc`). Ce fichier,
// ici, garde encore l'interface à une seule lightmap qu'utilisent `mur_iso.gdshader` et
// `sol_projete.gdshader` (hors périmètre ISO3 : ne pas y toucher) ; `lightmap_de_j2()`
// est ajoutée À CÔTÉ, sans rien renommer ni retirer, pour que `corps_iso.gdshader` (ISO3
// vague 2) puisse choisir sa vue exactement comme le corps grossier d'ISO2 le fait déjà —
// sans capteur par joueur ici, seulement le sélecteur de vue. La fusion de la lightmap
// double par joueur (ISO2) dans ce fichier reste un travail à part, hors ISO3.
const uint LIGHTMAP_CALQUE_VUE_2 = uint(4);

// La caméra qui dessine est-elle celle de J2 ? À appeler avec `CAMERA_VISIBLE_LAYERS`.
bool lightmap_de_j2(uint calques_camera) {
	return (calques_camera & LIGHTMAP_CALQUE_VUE_2) != uint(0);
}

vec3 lire_lightmap(vec2 px) {
	vec2 uv = (canevas_x * px.x + canevas_y * px.y + canevas_o) / taille_2d;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	return texture(lumiere, uv).rgb;
}

// La lumière du point `px`, passée à la pâte. `motif` : là où hachure, trame ou lavis
// s'accrochent. `aa` se calcule dans fragment(), hors de tout branchement : une
// dérivée prise sous un `if` n'est pas définie.
vec3 lightmap_pateuse(vec2 px, vec2 motif, float aa) {
	vec3 c = lire_lightmap(px);
	if (style == PATE_BRUTE) {
		return c;
	}
	float l = pate_luminance(c);
	if (l <= 0.0) {
		return vec3(0.0);
	}
	float lx_0 = pate_luminance(lire_lightmap(px - vec2(LIGHTMAP_PAS_PX, 0.0)));
	float lx_1 = pate_luminance(lire_lightmap(px + vec2(LIGHTMAP_PAS_PX, 0.0)));
	float ly_0 = pate_luminance(lire_lightmap(px - vec2(0.0, LIGHTMAP_PAS_PX)));
	float ly_1 = pate_luminance(lire_lightmap(px + vec2(0.0, LIGHTMAP_PAS_PX)));
	vec2 pente = vec2(lx_1 - lx_0, ly_1 - ly_0) / (2.0 * LIGHTMAP_PAS_PX);
	float decalee = pate_luminance(lire_lightmap(px + vec2(3.0, 2.0)));
	return pate(c, l, style, motif, pente, decalee, aa);
}
