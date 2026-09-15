// Chantier MURS BAS, étape MB3c — la zone morte FINIE derrière un mur bas, au rendu.
//
// La traduction ligne à ligne de `MursBas.franchit()` (murs_bas.gd), reprise du
// prototype MB0 (`tools/proto_murs_bas.gdshader`), où l'accord au pixel avec la
// règle a été mesuré. Les deux doivent rester identiques : la balle et la lumière
// franchissent un mur bas « selon un même angle » (Adrien, 2026-09-14).
//
// Pourquoi dans `light()` et pas par un occluder : un `LightOccluder2D` ne sait
// projeter qu'une ombre INFINIE, et la règle en demande une finie, de longueur
// constante L derrière le mur (`docs/MURS_BAS.md`, piste C).
//
// Tout est en ESPACE ÉCRAN (pixels de la cible de rendu), là où vivent
// LIGHT_POSITION et LIGHT_VERTEX. `MursBasRendu` (murs_bas_rendu.gd) y convertit
// murs et longueurs pour chaque vue, à chaque image.
//
// Ce que l'include NE fait pas : la torche d'un accroupi qui bute. Une source plus
// basse que le mur ne franchit jamais — ombre infinie, donc un vrai occluder sur
// `CanauxLumiere.COUCHE_OMBRE_MUR_BAS`. La zone morte qu'on calcule ici tombe
// alors DANS cette ombre : elle n'y change rien.

// Un mur bas = un rectangle (xmin, ymin, xmax, ymax), écran, rentré comme son
// occluder (`MapGeometry.OCCLUDER_INSET`).
uniform int mb_nb_murs = 0;
uniform vec4 mb_murs[64];
// Longueur de la zone morte POUR LA HAUTEUR DE CE QUI REÇOIT la lumière : L_sol
// pour le sol, L_accroupi pour un corps accroupi, 0 pour une tête debout (rien à
// calculer).
uniform float mb_zone_morte = 0.0;
// Un corps se juge en son CENTRE, comme la balle : éclairé en entier ou pas du
// tout. Le sol se juge pixel par pixel.
uniform bool mb_au_centre = false;
uniform vec2 mb_centre = vec2(0.0);

// Paramètre t où le segment a → b sort du rectangle, ou -1. Méthode des dalles,
// mêmes cas limites que `MursBas.sortie_du_rect()`.
float mb_sortie(vec2 a, vec2 b, vec4 r) {
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

// Gadgets et lumières (2026-09-15) — la HAUTEUR DE LA SOURCE, pour les sources qui
// en déclarent une (`MursBasRendu.poser_hauteur_source`). Toutes en pixels d'ÉCRAN :
// Godot porte `Light2D.height` dans LIGHT_POSITION.z à l'échelle de la cible de
// rendu, comme la position (`MursBasRendu.uniformes_de_vue` pose la même échelle).
uniform float mb_h_mur = 14.0;
// La hauteur de ce qui reçoit : 0 pour le sol, celle de la posture pour un corps.
uniform float mb_h_cible = 0.0;
// Au-delà, une lampe n'a pas de point d'origine (le bandeau LED) : aucune règle.
uniform float mb_z_sans_origine = 2048.0;

// Vrai si la lumière venue de `source` tombe dans la zone morte d'un mur bas.
//
// ⚠️ `source.z` est la HAUTEUR de la lampe (`Light2D.height`), et elle choisit la
// règle. Trois cas :
//
// - **z = 0 : la règle du jeu**, celle de la balle — « un même angle » (Adrien,
//   2026-09-14), une bande de longueur constante `mb_zone_morte` derrière chaque
//   muret. Les lampes portées par un joueur, la torche fantôme qui les imite, la
//   balle et ses éclats : elles ne posent aucune hauteur, et ce chemin est celui
//   de MB3c, inchangé.
// - **0 < z < `mb_z_sans_origine` : une source qui a une hauteur** (fusée, braises,
//   mine…). Le rayon qui rase l'arête de sortie du muret, à la distance D de la
//   source, redescend à la hauteur de la cible `c` après `D · (h_mur − c) / (z − h_mur)`.
//   Plus la source est haute, plus la zone est courte ; elle s'allonge avec D. Une
//   source au ras du muret ou plus basse ne le franchit jamais : c'est l'occluder
//   de `CanauxLumiere.COUCHE_OMBRE_MUR_BAS` qui l'arrête (ombre infinie), et que
//   `poser_hauteur_source` lui donne — ce shader n'a rien à calculer pour elle.
// - **z ≥ `mb_z_sans_origine` : une lampe sans point d'origine**, le bandeau LED des
//   murs (`mur_led.gd`), une seule lumière cuite pour toute la carte, posée en son
//   centre. Lui appliquer une règle ombrerait le sol derrière chaque muret vu depuis
//   ce centre — un rayon qui n'existe pas.
//
// Sans carte de normales, la hauteur n'a aucun autre effet sur le rendu
// (`tools/test_murs_bas_rendu.gd` garde les deux).
bool mb_dans_la_zone_morte(vec3 source, vec3 sommet) {
	if (source.z >= mb_z_sans_origine) {
		return false;
	}
	bool par_hauteur = source.z > 0.0;
	float k = 0.0;
	if (par_hauteur) {
		// Au ras ou sous le muret : l'occluder s'en charge. Cible plus haute que le
		// muret : il ne cache rien à une source qui le dépasse.
		if (source.z <= mb_h_mur || mb_h_cible >= mb_h_mur) {
			return false;
		}
		k = (mb_h_mur - mb_h_cible) / (source.z - mb_h_mur);
	} else if (mb_zone_morte <= 0.0) {
		return false;
	}
	vec2 cible = mb_au_centre ? mb_centre : sommet.xy;
	vec2 src = source.xy;
	float longueur = length(cible - src);
	// Borne de la zone : la constante du jeu, ou `longueur · k` (D ≤ longueur).
	float borne = par_hauteur ? longueur * k : mb_zone_morte;
	float borne2 = borne * borne;
	for (int i = 0; i < mb_nb_murs; i++) {
		vec4 r = mb_murs[i];
		// Sortie anticipée EXACTE, et c'est elle qui paie le coût : un point de la
		// zone morte est à moins de L de la sortie du rayon, qui est sur le bord du
		// mur — donc à moins de L du rectangle. Plus loin, le mur ne peut rien.
		float dx = max(max(r.x - cible.x, cible.x - r.z), 0.0);
		float dy = max(max(r.y - cible.y, cible.y - r.w), 0.0);
		if (dx * dx + dy * dy >= borne2) {
			continue;
		}
		float t = mb_sortie(src, cible, r);
		if (t < 0.0) {
			continue;
		}
		float zone = par_hauteur ? t * longueur * k : mb_zone_morte;
		if ((1.0 - t) * longueur < zone) {
			return true;
		}
	}
	return false;
}
