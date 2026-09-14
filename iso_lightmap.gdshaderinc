// Les lightmaps de la vue isométrique (ISO1, puis ISO2) — la sous-vue 2D de CHAQUE
// joueur, lue au point du monde qu'elle a rendu.
//
// La lecture passe par la transformation de canevas de la vue, exactement celle qui
// l'a rendue : aucune hypothèse sur la caméra 2D, secousse et zoom compris. Même
// formule, côté processeur : `CameraIso.uv_de()`. Hors du rectangle couvert, du noir :
// ce que la vue de dessus ne montre pas, l'iso ne l'invente pas.
//
// ## Deux lightmaps, une par joueur (ISO2)
//
// `lumiere_1` est la sous-vue de J1 (masque de cull ~4 : tout sauf les corps de J2),
// `lumiere_2` celle de J2 (~2). **C'est la règle d'équité du jeu** : chaque lightmap ne
// contient que les lumières que son joueur a le droit de voir — son halo de proximité,
// pas celui de l'autre. La 3D ne mélange jamais les deux : murs et corps, communs aux
// deux caméras de l'écran scindé, choisissent la lightmap par la caméra qui les dessine —
// `CAMERA_VISIBLE_LAYERS` porte la couche 4 dans la vue de J2 seulement (voir
// `lightmap_de_j2()`). En vue unique, la caméra de la racine porte la couche du joueur
// regardé, et la même règle s'applique. Vérifié en `gl_compatibility` par le banc ISO0.b.
//
// `source_color` : la texture de la vue est en sRGB, la sortie 3D aussi ; l'aller-retour
// a été vérifié au pixel à 90° contre la vue de dessus (banc ISO0.b).
//
// ⚠️ `CAMERA_VISIBLE_LAYERS` n'est lisible que dans `fragment()` : chaque shader le
// convertit là, une fois, et passe le booléen aux fonctions d'ici.
//
// Exige `iso_pate.gdshaderinc` inclus AVANT.

uniform sampler2D lumiere_1 : source_color, filter_linear, repeat_disable;
uniform vec2 canevas_1_x = vec2(1.0, 0.0);
uniform vec2 canevas_1_y = vec2(0.0, 1.0);
uniform vec2 canevas_1_o = vec2(0.0);
uniform vec2 taille_1 = vec2(1920.0, 1080.0);
uniform sampler2D lumiere_2 : source_color, filter_linear, repeat_disable;
uniform vec2 canevas_2_x = vec2(1.0, 0.0);
uniform vec2 canevas_2_y = vec2(0.0, 1.0);
uniform vec2 canevas_2_o = vec2(0.0);
uniform vec2 taille_2 = vec2(1920.0, 1080.0);

// La couche 3D que seule la caméra de J2 voit (`Presentation3D.CALQUE_VUE_2`).
const uint LIGHTMAP_CALQUE_VUE_2 = uint(4);

// Pas de la pente lue par la pâte, en pixels de monde.
const float LIGHTMAP_PAS_PX = 3.0;

// La caméra qui dessine est-elle celle de J2 ? À appeler avec `CAMERA_VISIBLE_LAYERS`.
bool lightmap_de_j2(uint calques_camera) {
	return (calques_camera & LIGHTMAP_CALQUE_VUE_2) != uint(0);
}

vec3 lire_lightmap(vec2 px, bool deux) {
	vec2 uv = deux
		? (canevas_2_x * px.x + canevas_2_y * px.y + canevas_2_o) / taille_2
		: (canevas_1_x * px.x + canevas_1_y * px.y + canevas_1_o) / taille_1;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	return deux ? texture(lumiere_2, uv).rgb : texture(lumiere_1, uv).rgb;
}

// La lumière du point `px`, passée à la pâte. `motif` : là où hachure, trame ou lavis
// s'accrochent. `aa` se calcule dans fragment(), hors de tout branchement : une
// dérivée prise sous un `if` n'est pas définie.
vec3 lightmap_pateuse(vec2 px, vec2 motif, float aa, bool deux) {
	vec3 c = lire_lightmap(px, deux);
	if (style == PATE_BRUTE) {
		return c;
	}
	float l = pate_luminance(c);
	if (l <= 0.0) {
		return vec3(0.0);
	}
	float lx_0 = pate_luminance(lire_lightmap(px - vec2(LIGHTMAP_PAS_PX, 0.0), deux));
	float lx_1 = pate_luminance(lire_lightmap(px + vec2(LIGHTMAP_PAS_PX, 0.0), deux));
	float ly_0 = pate_luminance(lire_lightmap(px - vec2(0.0, LIGHTMAP_PAS_PX), deux));
	float ly_1 = pate_luminance(lire_lightmap(px + vec2(0.0, LIGHTMAP_PAS_PX), deux));
	vec2 pente = vec2(lx_1 - lx_0, ly_1 - ly_0) / (2.0 * LIGHTMAP_PAS_PX);
	float decalee = pate_luminance(lire_lightmap(px + vec2(3.0, 2.0), deux));
	return pate(c, l, style, motif, pente, decalee, aa);
}
