// Prototype MURS BAS (étape MB0) — la zone morte FINIE derrière un mur bas.
//
// Un `LightOccluder2D` ne sait projeter qu'une ombre infinie. La règle d'Adrien
// (2026-09-14) en demande une finie : derrière un mur bas, la lumière d'une
// source debout redescend selon l'angle α, et la bande d'ombre a une longueur
// constante L. Ce shader la calcule dans `light()`, lumière par lumière, pour
// chaque pixel qui la reçoit — la traduction ligne à ligne de
// `MursBasGeometrie.franchit()` (tools/murs_bas_geometrie.gd). Les deux doivent
// rester identiques : c'est ce que le contrôle d'accord du prototype mesure au
// pixel (touche V).
//
// Tout est en ESPACE ÉCRAN (pixels de la cible de rendu) : LIGHT_POSITION et
// LIGHT_VERTEX y vivent, le prototype y convertit les murs et la zone morte à
// chaque image. La géométrie est invariante par similitude, donc l'échelle de
// la fenêtre ne change pas le résultat.
//
// Ce que le shader NE fait pas : la torche d'un accroupi qui bute. Une source
// plus basse que le mur ne franchit jamais — c'est une ombre infinie, donc un
// vrai occluder sur son propre bit, que seules les lumières accroupies activent.
shader_type canvas_item;

// Un mur bas = un rectangle (xmin, ymin, xmax, ymax), écran.
uniform int nb_murs = 0;
uniform vec4 murs[64];
// Longueur de la zone morte POUR LA HAUTEUR DE CE QUI REÇOIT la lumière :
// L_sol pour le sol, L_accroupi pour un corps accroupi, 0 pour une tête debout.
uniform float zone_morte = 0.0;
// Un corps se juge en son CENTRE, comme la balle : il est éclairé en entier ou
// pas du tout. Le sol se juge pixel par pixel.
uniform bool au_centre = false;
uniform vec2 centre = vec2(0.0);
uniform bool actif = true;

uniform vec3 albedo = vec3(0.5);
// 0 : uni. 1 : hachures (le dessus d'un mur bas).
uniform int motif = 0;

varying vec2 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 c = albedo;
	if (motif == 1) {
		float h = mod(monde.x + monde.y, 9.0);
		c *= (h < 3.0) ? 1.0 : 0.5;
	}
	COLOR = vec4(c, 1.0);
}

// Paramètre t où le segment a → b sort du rectangle, ou -1. Méthode des dalles,
// mêmes cas limites que `sortie_du_rect()`.
float sortie(vec2 a, vec2 b, vec4 r) {
	vec2 d = b - a;
	float te = -1e20;
	float ts = 1e20;
	for (int axe = 0; axe < 2; axe++) {
		float o = axe == 0 ? a.x : a.y;
		float v = axe == 0 ? d.x : d.y;
		float lo = axe == 0 ? r.x : r.y;
		float hi = axe == 0 ? r.z : r.w;
		if (abs(v) < 1e-6) {
			if (o < lo || o > hi) {
				return -1.0;
			}
			continue;
		}
		float t1 = (lo - o) / v;
		float t2 = (hi - o) / v;
		te = max(te, min(t1, t2));
		ts = min(ts, max(t1, t2));
	}
	if (te > ts || ts <= 0.0 || ts >= 1.0) {
		return -1.0;
	}
	return ts;
}

void light() {
	bool cache = false;
	if (actif && zone_morte > 0.0) {
		vec2 cible = au_centre ? centre : LIGHT_VERTEX.xy;
		vec2 src = LIGHT_POSITION.xy;
		float longueur = length(cible - src);
		for (int i = 0; i < nb_murs; i++) {
			float t = sortie(src, cible, murs[i]);
			if (t >= 0.0 && (1.0 - t) * longueur < zone_morte) {
				cache = true;
				break;
			}
		}
	}
	LIGHT = cache ? vec4(0.0) : vec4(LIGHT_COLOR.rgb * COLOR.rgb, LIGHT_COLOR.a);
}
