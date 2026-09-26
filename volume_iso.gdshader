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
// Centre et rayon du nuage, en pixels de monde ; angle de son image. Préfixés `nuage_` (2026-09-25) : la variante
// masquée inclut l'usure du mur (`iso_usure.gdshaderinc`), dont les locales s'appellent `centre`, `rayon`, `angle`,
// `coeur` et `graine` — un uniforme du même nom et la variante ne compile plus (« Redefinition of … »), ce qui ne se
// voit qu'à l'image : elle ne dessine alors rien.
uniform vec2 nuage_centre = vec2(0.0);
uniform float nuage_rayon = 100.0;
uniform float nuage_angle = 0.0;
// L'opacité de CETTE couche au cœur du nuage.
uniform float densite = 0.3;
// Le bord adouci, en fraction du rayon (0,45 : le cœur plein occupe presque la moitié).
uniform float nuage_coeur = 0.45;
// Le grain qui empêche les couches de se lire comme des disques identiques empilés.
uniform float nuage_graine = 0.0;
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
#ifdef FUMEE_MASQUE
// ISO13, Q31 — ce que le pixel montre derrière la couche (sol, face ou dessus de mur), jugé comme son propre shader le calcule.
#include "res://volume_masque.gdshaderinc"
#endif

// ## Deux gestes qui font MOINS de travail pour la même image (2026-09-23)
//
// La décomposition du coût d'une fusée a montré que **78 % de ses 3,39 ms venaient de ce shader**, à
// DIX lectures de texture par pixel et par couche (neuf pour la lightmap lissée, une pour la
// neutralité) — quarante par pixel de fumée avec quatre couches. D'où l'ordre de `fragment()` :
//   1. **l'opacité d'abord, la couleur ensuite** : `a` ne dépend pas de `c` et vaut zéro hors du
//      disque inscrit (les 21,5 % de coins du quad). L'ordre inverse faisait payer dix lectures à des
//      pixels jetés juste après ; ce sont les MÊMES pixels qu'on jette, plus tôt ;
//   2. **le point central n'est lu qu'une fois** : le lissage le lit déjà avant de le noyer dans sa
//      moyenne, et la neutralité le relisait à l'identique.
//
// ⚠️ **Adoptés sur preuve de CONSTRUCTION, pas sur un gain mesuré.** Au banc, l'écart (0,2 à 0,4 ms)
// est resté SOUS l'écart entre deux passes d'une même variante (0,4 à 0,8) ; la direction est bonne
// (l'ancien chemin est le plus lent dans six comparaisons sur six, p = 0,031), la magnitude n'est pas
// mesurable là. Ce qui les justifie est qu'ils suppriment du travail inutile : ils ne peuvent pas
// être plus lents, et le shader est plus court qu'avant.

varying vec3 monde;

// La lightmap moyennée autour de `p` : le point — DÉJÀ LU par l'appelant, jamais relu — et huit
// lectures sur un cercle de `r` pixels de monde.
vec3 lire_lightmap_lissee(vec2 p, float r, bool deux, vec3 centre_lu) {
	vec3 s = centre_lu;
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
	// ⚠️ Et c'est aussi ce qui interdit de jeter le pixel PLUS TÔT que ci-dessous : `fwidth` lit ses
	// voisins, un `discard` qui le précéderait rendrait la dérivée fausse sur tout le bord du nuage.
	float px_ecran = max(max(fwidth(px.x), fwidth(px.y)), 1e-3);

	// L'OPACITÉ D'ABORD : elle ne dépend pas de la couleur, et elle décide
	// des pixels qu'on jette. Les calculer dans l'autre ordre faisait payer dix lectures de texture
	// à des pixels jetés juste après.
	float a = densite;
	if (!ruban) {
		vec2 d = (px - nuage_centre) / max(nuage_rayon, 1.0);
		float r = length(d);
		float forme = 1.0 - smoothstep(nuage_coeur, 1.0, r);
		// Au-delà du disque inscrit, la forme vaut zéro et le bruit ne peut pas la relever : on jette
		// avant même de le calculer.
		if (forme <= 0.0) {
			discard;
		}
		a *= forme;
		if (avec_masque) {
			float ca = cos(nuage_angle);
			float sa = sin(nuage_angle);
			// L'image 2D tourne de `angle` : on lit son repère propre, donc la rotation inverse.
			vec2 local = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y);
			a *= texture(masque, local * 0.5 + vec2(0.5)).a;
		}
		// ISO10, 1c — le grain du bord à l'échelle de l'ÉCRAN (cellules de trois pixels), plus en
		// cellules de 20 px de monde grossies 2,4 fois : c'étaient les « blocs » de la fumée. Ancré
		// dans le monde (px divisé par une constante de zoom) : il ne glisse pas avec la caméra.
		a *= 0.7 + 0.3 * pate_bruit(px / (3.0 * px_ecran) + vec2(nuage_graine * 13.1, age * 0.35));
	}
	a = clamp(a, 0.0, 1.0);
	if (a <= 0.003) {
		discard;
	}
#ifdef FUMEE_MASQUE
	// ISO13, Q31 voie A — LE MASQUE SANS COPIE D'ÉCRAN (allumé par défaut, `--sans-fumee-masque` l'éteint ; ISO7 Gadgets, 2026-09-25) : la couche se tait là
	// où ce que le pixel MONTRE derrière elle s'affiche noir (`masque_montre_noir`, `volume_masque.gdshaderinc`) — le sol,
	// la face ou le dessus d'un mur que le rayon de vue, prolongé au-delà de la couche, rencontre d'abord.
	// Pourquoi pas la lumière brute : le sol (`lightmap_pateuse_sol`) passe la lumière dans la pâte, et le lavis n'allume sa
	// première eau qu'au-dessus de 2 à 5 % — en dessous, le sol est noir sur une lumière qui ne l'est pas. La garde par la
	// lumière brute ne voyait donc rien (11 750 pixels fautifs contre 10 222 sans elle), et la couche, qui passe dans la
	// même pâte une lumière LISSÉE, plus claire au bord du disque, franchissait le seuil que le sol ne franchit pas.
	// Quatre fautes de la première journée, chacune vue à l'image et non par une suite :
	// - juger le point SOUS la couche au lieu du point montré (sans parallaxe 5 422 et 5 620 pixels fautifs, inversée
	//   7 665 et 5 861, au lieu de 120 et 2 512) ;
	// - la juger DÉCODÉE (`pate_vers_affiche`) alors que l'écran montre la valeur écrite : 109 097 pixels de fumée perdue sur
	//   l'anneau éclairé par les LED (preuve de 14:49 ; les « fuites » qui avaient inspiré ce faux remède, à 13:58, venaient
	//   d'une caméra qui glissait encore) ;
	// - juger sur le sol un pixel qui montre la face d'un mur : 12 114 pixels de fumée perdue devant les faces éclairées ;
	// - croire que l'écran montre la valeur écrite au-dessus de 0,5/255 : la sortie 3D écrase tout canal écrit sous 8/255
	//   (rampes du 2026-09-25) — 127 pixels de fuite à la lisière du noir, sur un sol écrit à quelques /255.
	// Sous `#ifdef` et non derrière un uniforme : masque éteint, le shader compilé est celui d'avant (piège de l'ordre 255).
	// V1e — les dérivées d'écran TIRÉES DE LA CAMÉRA, après le discard de l'opacité : caméra orthographique, un pixel
	// d'écran vaut dans le monde un vecteur constant par vue (la base de la caméra × la taille d'un pixel de projection).
	// Ce n'est pas `dFdx(monde)`, qui glisse le long de la couche ; les deux ne diffèrent que le long de la vue, composante
	// que `derivee_sur_plan` retire : les dérivées sur le sol et sur les faces sont les mêmes. Plus aucun dFdx vivant à
	// travers le shader (V1c et V1d les prenaient en tête du fragment, sur tous les fragments). Le signe de y peut différer
	// de `dFdy` : seules des longueurs et des valeurs absolues en dépendent (aa, px_monde, niveau de mipmap).
	if (!ruban && masque_montre_noir(monde, -INV_VIEW_MATRIX[2].xyz, deux,
			INV_VIEW_MATRIX[0].xyz * (2.0 / (VIEWPORT_SIZE.x * PROJECTION_MATRIX[0][0])),
			INV_VIEW_MATRIX[1].xyz * (2.0 / (VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1])))) {
		discard;
	}
#endif

	// LA COULEUR ENSUITE, le point central lu UNE fois pour ses deux usages.
	vec3 brute = lire_lightmap(px, deux);
	vec3 lue = ruban ? brute : lire_lightmap_lissee(px, max(nuage_rayon * lissage_rayon, 1.0), deux, brute);
	vec3 c;
	if (ruban) {
		c = lightmap_pateuse(px, px, aa, deux);
	} else {
		// Pente nulle et lumière décalée égale à la lumière lue : un nuage n'a pas de bord de lumière à
		// dessiner, il montre la teinte qu'il reçoit.
		float l_lue = pate_luminance(lue);
		c = l_lue <= 0.0 ? vec3(0.0) : (style == PATE_BRUTE ? lue : pate(lue, l_lue, style, px, vec2(0.0), l_lue, aa));
	}
	// ISO7b (ligne posée par ISO7 Beauté sur l'ordre de la session cloud, 2026-09-15 14:21 — Gadgets
	// clos) : la neutralité qui dose la chaleur se lit sur la lightmap AVANT la pâte, comme au sol et
	// sur les murs. Mesurée après elle, un nuage dans le halo d'une fusée prenait la chaleur des
	// torches. Seuils 0 : la teinte chaude d'ISO7, sans graduation.
	c = pate_temperature_graduee_neutre(c, temperature, 0.0, 0.0, pate_poids_neutre(brute));
	ALBEDO = c;
	ALPHA = a;
}
