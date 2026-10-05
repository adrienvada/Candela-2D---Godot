// Chantier OMBRES, OM5 (Q88, décision d'Adrien du 2026-10-05 : « Ombre ») — l'ombre FINIE d'un corps sous un plafonnier, au
// rendu.
//
// Pourquoi ici et pas par l'étoile : un `LightOccluder2D` ne projette qu'une ombre INFINIE, comme si la lampe était posée au
// sol ; le plafonnier pend à 1,5 tuile, au-dessus des têtes (une tuile debout). Son ombre a une longueur, D · H / (h − H) — D la
// distance de la lampe au corps, H la hauteur du corps, h celle de la lampe —, et c'est la règle de la zone morte des murets
// (`murs_bas_zone.gdshaderinc`) avec un cylindre à la place du rectangle.
//
// Le corps est un CYLINDRE vertical (`Presentation3D.RAYON_CORPS_PX`, « le corps grossier ») : un disque de rayon r au sol,
// haut de la hauteur de sa posture (`MursBas.hauteur_de_posture`, celle de la règle des murets — une lumière qui passe
// au-dessus d'un accroupi pour l'éclairer derrière un muret passe aussi au-dessus de lui pour éclairer le sol). Le rayon qui va
// de la lampe (s, à la hauteur h) au point p du sol passe sous la hauteur H sur la dernière fraction H / h de son trajet ; il
// touche le corps si ce dernier bout, vu de dessus, passe à moins de r de son centre. Sur l'axe lampe → corps, l'ombre court
// jusqu'à D · H / (h − H) derrière lui, et elle s'élargit en s'éloignant (le haut du cylindre se projette × h / (h − H)).
//
// Tout est en ESPACE ÉCRAN (pixels de la cible de rendu), là où vivent LIGHT_POSITION et LIGHT_VERTEX, comme la zone morte :
// `OmbresCorps` (ombres_corps.gd) y convertit corps et lampes pour chaque vue, à chaque image
// (`GameState._pousser_ombres_des_corps`). Sa jumelle GDScript : `OmbresCorps.ombre`.
//
// ⚠️ **Les plafonniers, et eux seuls** (Q88). `om_lampes` les nomme par leur position à l'écran : une fusée en vol passe par
// la même hauteur, et la lumière d'aucune autre lampe n'est touchée — l'étoile ombre déjà les torches, et les lumières posées
// n'ont pas d'ombre de corps (Q87).
// ⚠️ **L'ombre ne montre d'un corps que ce que la vue en montre** — le patron du contact au sol
// (`Presentation3D.opacite_du_corps`) : `om_corps_force` est l'opacité du corps dans CETTE vue. Un corps effacé par le
// brouillage, la suie ou la mort ne trahit rien par son ombre.

uniform int om_nb_lampes = 0;
uniform vec2 om_lampes[8];
uniform int om_nb_corps = 0;
// xy : le centre du corps à l'écran ; z : son rayon à l'écran ; w : sa hauteur à l'écran.
uniform vec4 om_corps[12];
uniform float om_corps_force[12];

// La distance (pixels d'écran) en deçà de laquelle une lumière EST un plafonnier : la même transformation porte les deux
// positions, l'écart n'est que d'arrondi.
const float OM_TOLERANCE_LAMPE = 0.75;

// Ce que l'ombre des corps retire de la lumière venue de `source` au point `sommet` du sol : 0 (rien) à 1 (toute), la plus
// forte des ombres qui le couvrent — deux corps ne noircissent pas deux fois.
float om_ombre_des_corps(vec3 source, vec3 sommet) {
	if (om_nb_corps == 0 || om_nb_lampes == 0 || source.z <= 0.0) {
		return 0.0;
	}
	bool plafonnier = false;
	for (int l = 0; l < om_nb_lampes; l++) {
		if (distance(om_lampes[l], source.xy) < OM_TOLERANCE_LAMPE) {
			plafonnier = true;
			break;
		}
	}
	if (!plafonnier) {
		return 0.0;
	}
	float ombre = 0.0;
	for (int i = 0; i < om_nb_corps; i++) {
		vec4 c = om_corps[i];
		float f = om_corps_force[i];
		// Une lampe au ras de la tête ou plus bas ne donnerait pas une ombre finie : aucun plafonnier n'y pend.
		if (f <= ombre || c.w <= 0.0 || source.z <= c.w) {
			continue;
		}
		// Le bout du rayon qui passe sous la tête : de `a` au point du sol.
		vec2 a = source.xy + (sommet.xy - source.xy) * (1.0 - c.w / source.z);
		vec2 ab = sommet.xy - a;
		float t = clamp(dot(c.xy - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		if (distance(c.xy, a + ab * t) < c.z) {
			ombre = f;
		}
	}
	return ombre;
}
