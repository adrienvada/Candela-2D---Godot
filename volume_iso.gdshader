// Une couche d'un VOLUME de la vue iso (Gadgets et lumières, étape 3) : suie, poussière, fumée de
// fusée, nappe de braises, poudre — et la toile du voile, debout (étape 5).
//
// ## Ce qu'elle montre : la lightmap SOUS elle, rien d'autre
//
// Le volume est déjà dans la lightmap 2D, à plat : la masse de la suie telle que la lampe l'allume,
// les nappes et le voile de la fusée tels que sa lumière les révèle. Chaque couche est un plan
// horizontal posé à sa hauteur, qui lit la lightmap au point du monde juste en dessous d'elle et le
// montre, découpé par la forme du nuage. Empilées, les couches élèvent le nuage éclairé en colonne.
//
// Pourquoi horizontales et pas face à la caméra : un plan vertical lirait la lightmap le long d'une
// ligne, et la tirerait en stries. Un plan horizontal a, en chaque point, exactement un point de sol
// sous lui — la lumière qu'il montre est celle que la vue de dessus y dessine.
//
// ## Ce qui en découle, sans rien ajouter
//
// - **Le noir absolu** : sans lumière, la lightmap vaut 0 sous la couche, et la couche vaut 0.
// - **L'équité** : la couche lit la lightmap de la caméra qui la dessine (`lightmap_de_j2`), comme le
//   sol ; elle ne voit que les lumières que ce joueur a le droit de voir.
// - **Jamais plus claire que la source** : elle recopie un texel déjà rendu, sans gain.
//
// Non éclairée (la lumière EST la texture) ; mélange normal ; profondeur lue, jamais écrite. Le
// matériau est dessiné AVANT les corps (`render_priority`, voir `IsoVolumes`) : une couche ne cache
// jamais un corps plus que la vue de dessus, où l'effacement dans un nuage passe par l'opacité du
// corps (ISO2b), pas par la masse posée dessus.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

// La forme du nuage : l'alpha de son image 2D (tournée comme elle), sinon un disque bruité.
uniform sampler2D masque : filter_linear, repeat_disable;
uniform bool avec_masque = false;
// Centre et rayon du nuage, en pixels de monde ; angle de son image.
uniform vec2 centre = vec2(0.0);
uniform float rayon = 100.0;
uniform float angle = 0.0;
// L'opacité de CETTE couche au cœur du nuage.
uniform float densite = 0.3;
// Le bord adouci, en fraction du rayon (0,45 : le cœur plein occupe presque la moitié).
uniform float coeur = 0.45;
// Le grain qui empêche les couches de se lire comme des disques identiques empilés.
uniform float graine = 0.0;
uniform float age = 0.0;
// Un ruban (la toile du voile) : ni disque ni bord, une densité pleine le long du maillage.
uniform bool ruban = false;
// Raccords de la vague — la température de la lumière (ISO7, `pate_temperature`) : le nuage posé sur le sol
// chaud en prend la teinte, luminance gardée. 0 : la lightmap telle quelle. Réglé par `IsoVolumes`.
uniform float temperature = 0.0;
// ISO10, 1c (2026-09-15) — **une couche montre la lumière du nuage, pas le dessin de sa volute.** Chaque couche relisait
// la lightmap NETTE sous elle, volutes des nappes 2D comprises : empilées à quatre hauteurs et vues par la caméra
// inclinée, les quatre copies nettes de la même volute se décalaient à l'écran en arcs parallèles — les « anneaux » de
// la loupe (tour 1). Prouvé : la même fusée, volumes coupés, n'en a aucun. La couche relit maintenant une MOYENNE sur
// `lissage_rayon` × rayon : les copies n'ont plus de détail à répéter, et le dessin de la volute reste celui des
// nappes, au sol, une seule fois. Le ruban (la toile du voile, debout) garde sa lecture nette. Noir absolu tenu : une
// moyenne de lectures nulles est nulle ; jamais plus clair que la plus claire des lectures.
uniform float lissage_rayon = 0.18;

varying vec3 monde;

// La lightmap moyennée autour de `p` : le point et huit lectures sur un cercle de `r` pixels de monde.
vec3 lire_lightmap_lissee(vec2 p, float r, bool deux) {
	vec3 s = lire_lightmap(p, deux);
	for (int k = 0; k < 8; k++) {
		float t = float(k) * 0.785398163;
		s += lire_lightmap(p + vec2(cos(t), sin(t)) * r, deux);
	}
	return s / 9.0;
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 px = monde.xz;
	float aa = clamp((fwidth(px.x) + fwidth(px.y)) / 6.0, 0.02, 0.5);
	// Hors de tout branchement, comme `aa` : la taille d'un pixel d'écran en pixels de monde.
	float px_ecran = max(max(fwidth(px.x), fwidth(px.y)), 1e-3);
	vec3 lue = ruban ? lire_lightmap(px, deux) : lire_lightmap_lissee(px, max(rayon * lissage_rayon, 1.0), deux);
	vec3 c;
	if (ruban) {
		c = lightmap_pateuse(px, px, aa, deux);
	} else {
		// Pente nulle et lumière décalée égale à la lumière lue : un nuage n'a pas de bord de lumière à dessiner, il
		// montre la teinte qu'il reçoit.
		float l_lue = pate_luminance(lue);
		c = l_lue <= 0.0 ? vec3(0.0) : (style == PATE_BRUTE ? lue : pate(lue, l_lue, style, px, vec2(0.0), l_lue, aa));
	}
	float a = densite;
	if (!ruban) {
		vec2 d = (px - centre) / max(rayon, 1.0);
		float r = length(d);
		a *= 1.0 - smoothstep(coeur, 1.0, r);
		if (avec_masque) {
			float ca = cos(angle);
			float sa = sin(angle);
			// L'image 2D tourne de `angle` : on lit son repère propre, donc la rotation inverse.
			vec2 local = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y);
			a *= texture(masque, local * 0.5 + vec2(0.5)).a;
		}
		// ISO10, 1c — le grain du bord à l'échelle de l'ÉCRAN (cellules de trois pixels), plus en cellules de 20 px de
		// monde grossies 2,4 fois : c'étaient les « blocs » de la fumée. Ancré dans le monde (px divisé par une
		// constante de zoom) : il ne glisse pas avec la caméra.
		a *= 0.7 + 0.3 * pate_bruit(px / (3.0 * px_ecran) + vec2(graine * 13.1, age * 0.35));
	}
	a = clamp(a, 0.0, 1.0);
	if (a <= 0.003) {
		discard;
	}
	// ISO7b (ligne posée par ISO7 Beauté sur l'ordre de la session cloud, 2026-09-15 14:21 — Gadgets clos) : la neutralité
	// qui dose la chaleur se lit sur la lightmap AVANT la pâte, comme au sol et sur les murs. Mesurée après elle, un nuage
	// dans le halo d'une fusée prenait la chaleur des torches. Seuils 0 : la teinte chaude d'ISO7, sans graduation.
	c = pate_temperature_graduee_neutre(c, temperature, 0.0, 0.0, pate_poids_neutre(lire_lightmap(px, deux)));
	ALBEDO = c;
	ALPHA = a;
}
