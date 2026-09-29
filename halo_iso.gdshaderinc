// Une LUEUR de la vue iso (Gadgets et lumières, étape 4) : la comète d'une fusée en vol, sa lueur au
// sol, les points de la nappe de braises, la lentille de la torche fantôme, l'éclat de bouche, l'éclair
// de la mine.
//
// ## Ce qu'elle est, et ce qu'elle n'est pas
//
// Une IMAGE : elle ne verse aucune lumière, ni dans la lightmap ni sur un corps (aucune `Light3D`,
// jamais). Chaque lueur est l'image d'une source qui brûle déjà dans la vue de dessus — un cœur non
// éclairé, une lentille, un éclat dessiné —, posée à la hauteur où cette source brûle. Son intensité
// est celle de SA lumière 2D (`IsoVolumes`) : lumière éteinte, lueur éteinte — le noir absolu tient.
//
// En valeurs affichées, comme les quads d'ISO4 : le spatial ne convertit pas sous `gl_compatibility`.
// Non éclairée, profondeur lue : un mur 3D la cache.
//
// ISO10, 1c (2026-09-15) — **le corps d'une lueur, inclus par deux shaders**, parce que le mode de mélange est un
// `render_mode`, fixé à la compilation : `halo_iso.gdshader` (ADDITIVE, toutes les lueurs d'origine) et
// `halo_iso_melange.gdshader` (MÉLANGE, la lueur au sol de la fusée posée). Additionné à un sol déjà éclairé par la
// même lumière rouge, le rouge de détresse saturait canal par canal : le rouge plafonnait, le vert et le bleu
// montaient encore — rose, puis blanc (loupe, tour 1). En mélange, la lueur tend VERS sa couleur et ne la dépasse
// jamais : « jamais de blanc, c'est une fusée de marine » (FU2.1).

uniform vec4 couleur = vec4(1.0);
uniform float intensite = 1.0;
// 0 : lueur douce (décroissance quadratique) ; 1 : point franc à bord adouci (braise, lentille, comète).
uniform int forme = 0;
// Face à la caméra (une lueur debout), ou couchée sur son plan (une lueur au ras du sol).
uniform bool face_camera = true;
// Chantier des lumières de la 0.8.0, L3 (Q46) — une LENTILLE orientée (le point lumineux d'une torche tenue) : la lueur est
// pesée par l'orientation du verre face à la caméra QUI DESSINE — de face, pleine ; de dos, rien. Faux pour toutes les autres
// lueurs. `LENTILLE_DOS` / `LENTILLE_FACE` : recopiés de `IsoVolumes` (même nom), et comparés par `tools/test_point_lumineux.gd`.
uniform bool lentille_orientee = false;
uniform vec3 direction_lentille = vec3(0.0, 0.0, -1.0);
const float LENTILLE_DOS = -0.1;
const float LENTILLE_FACE = 0.3;

void vertex() {
	if (face_camera) {
		// Le quad garde sa position et son échelle, et prend l'orientation de la caméra.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	float r = length(UV * 2.0 - vec2(1.0));
	if (r >= 1.0) {
		discard;
	}
	float a = forme == 0 ? (1.0 - r) * (1.0 - r) : 1.0 - smoothstep(0.55, 1.0, r);
	a *= clamp(intensite, 0.0, 4.0) * couleur.a;
	if (lentille_orientee) {
		// `INV_VIEW_MATRIX[2]` : l'axe arrière de la caméra, vers elle (orthographique : le même pour tout le cadre).
		a *= smoothstep(LENTILLE_DOS, LENTILLE_FACE, dot(normalize(direction_lentille), normalize(INV_VIEW_MATRIX[2].xyz)));
	}
	if (a <= 0.002) {
		discard;
	}
	ALBEDO = couleur.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
