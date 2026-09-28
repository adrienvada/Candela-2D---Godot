// Q39 — SON PROPRE CORPS, SOMBRE AVEC UN LISERÉ (essai de la session cloud corps-sombre, 2026-09-28), derrière
// `--corps-soi-sombre`, éteint par défaut. Compilé SEULEMENT dans la variante CORPS_SOI_SOMBRE du shader des corps
// (`IsoMateriaux.accorder_corps`) : drapeau éteint, le préprocesseur retire tout et le shader compilé est le code d'avant,
// au bit (le piège de l'ordre 255 : un test d'uniforme par pixel se paie drapeau éteint).
//
// Aujourd'hui, son propre corps est, dans SA vue, moitié corps éclairé, moitié couleur du joueur (la silhouette de soi
// d'ISO2b, `visual_dim` de la vue de dessus) : bleu glacier uni, à toute lumière. Seize illustrations sur vingt montrent au
// contraire des personnages SOMBRES cernés d'un liseré clair du côté de la lumière (manque n° 2 de la session « écart aux
// illustrations »). L'essai, pour qu'Adrien voie l'autre voie (Q39) :
// - **le corps éclairé, assombri** (`soi_sombre_facteur`, en valeur affichée par `pate_facteur`) : il garde le modelé du
//   capteur — plus clair côté lampe, noir dans le noir — mais ne dépasse plus ~50 ;
// - **un liseré du côté d'où vient la lumière réelle** : sur une bande de `soi_lisere_px` pixels d'écran au bord de chaque
//   face, le corps retrouve sa lumière d'aujourd'hui (celle du capteur, lue au bord du disque dans la direction du fragment —
//   jamais plus claire que la fiche), pondérée par l'orientation du bord vers `soi_lumiere` : la direction horizontale vers
//   la lumière qui éclaire vraiment ce corps, calculée par `MannequinIso.direction_dominante()` (torche, rétrodiffusion,
//   fusée, torche adverse, murs compris) — la même que le mannequin, réutilisée telle quelle. Pas de lumière, pas de liseré ;
// - **dans le noir complet, un repère** : la même bande, sur les bords des dessus, à la valeur de la silhouette de soi
//   d'aujourd'hui (`silhouette.rgb × s`, aucune constante neuve pour la couleur) — le joueur se retrouve toujours, par un
//   trait et non plus par une tache.
//
// ⚠️ **Il ne change QUE ce que le joueur voit de lui-même.** L'appelant ne l'applique que là où `silhouette_N` est non
// nulle, c'est-à-dire le corps de soi dans sa propre vue (et le fantôme de killcam dans les vues qui voient sa couche, la
// règle d'ISO5). Dans la vue d'en face, `s = 0` : ce code n'est pas atteint, l'adversaire voit exactement le corps d'hier.
// Noir absolu : rien ne sort du corps ; le seul terme qui n'est pas un facteur sur la lumière rendue est le repère, qui
// remplace la silhouette de soi d'aujourd'hui (même valeur, sur une bande au lieu de tout le corps : moins de pixels).

#ifdef CORPS_SOI_SOMBRE
// Direction horizontale (x, z du monde) vers la lumière dominante ; longueur 0..1 = sa netteté.
uniform vec2 soi_lumiere = vec2(0.0);
// Le corps éclairé, en valeur affichée : 0,4 met la fiche (~128 en pleine lumière) vers ~50, la clarté des illustrations.
uniform float soi_sombre_facteur : hint_range(0.0, 1.0) = 0.4;
// La largeur du liseré et du repère, en PIXELS D'ÉCRAN (le liseré d'une illustration est un trait, pas une bande de monde).
uniform float soi_lisere_px = 1.5;

// La distance du fragment au bord de sa face, en unités du monde, et la direction HORIZONTALE (monde) de ce bord, vers
// l'extérieur. Une face latérale : sa normale (tous ses bords sont du même côté du corps). Un dessus : le bord le plus proche.
float soi_bord(vec3 lp, vec3 d, vec3 ech, vec3 n) {
	vec3 r = max(d - abs(lp), vec3(0.0)) * ech;
	vec3 an = abs(n);
	return an.x > 0.5 ? min(r.y, r.z) : (an.y > 0.5 ? min(r.x, r.z) : min(r.x, r.y));
}

vec2 soi_direction_du_bord(vec3 lp, vec3 d, vec3 ech, vec3 n_locale, vec3 n_monde, vec2 axe_x, vec2 axe_z) {
	if (abs(n_locale.y) <= 0.5) {
		float l = length(n_monde.xz);
		return l > 0.001 ? n_monde.xz / l : vec2(0.0);
	}
	vec3 r = max(d - abs(lp), vec3(0.0)) * ech;
	return r.x < r.z ? axe_x * sign(lp.x) : axe_z * sign(lp.z);
}

// `c` : le corps tel que le jeu le rend aujourd'hui, avant la silhouette (lumière du capteur, pâte, fiche, encre). `sil`,
// `s` : la silhouette de soi (couleur affichée, opacité). Rend la couleur du corps de soi à l'essai.
vec3 soi_sombre_composer(vec3 c, vec3 sil, float s, vec3 lp, vec3 d, vec3 ech, vec3 n_locale, vec3 n_monde, vec2 axe_x,
		vec2 axe_z, float px_monde) {
	float w = soi_lisere_px * px_monde;
	float bord = soi_bord(lp, d, ech, n_locale);
	float bande = 1.0 - smoothstep(w - 0.5 * px_monde, w + 0.5 * px_monde, bord);
	float nette = min(length(soi_lumiere), 1.0);
	float face = 0.0;
	if (nette > 0.001) {
		vec2 l = soi_lumiere / length(soi_lumiere);
		face = nette * max(dot(soi_direction_du_bord(lp, d, ech, n_locale, n_monde, axe_x, axe_z), l), 0.0);
	}
	vec3 corps = pate_facteur(c, soi_sombre_facteur);
	corps = mix(corps, c, bande * face);
	// Le repère sur les bords des DESSUS seulement : posé sur toutes les arêtes, il dessinait le corps en fil de fer (première
	// prise, 2026-09-28) ; les dessus, vus d'en haut, en font le contour.
	float dessus = step(0.5, n_locale.y);
	return max(corps, sil * s * bande * dessus);
}

#ifdef CORPS_SOI_FONDU
// Q39, DEUXIÈME TOUR — L'ESSAI B, « FONDU » (avis de jeu de Beauté, 2026-09-28 ; session cloud corps-sombre-2), derrière
// `--corps-soi-sombre=fondu`, éteint par défaut. L'essai A perd le plus là où le joueur a le plus besoin de se trouver (sous
// sa propre torche, au bord du cône adverse, ébloui) ; il ne gagne franchement que là où le corps d'aujourd'hui se FOND dans
// le sol (la fusée, les sols éclairés). B n'assombrit donc QUE là : il mêle le corps d'aujourd'hui et celui de l'essai A,
// avec un poids qui dit « le corps d'aujourd'hui se fond-il dans le sol autour de lui ? ».
//
// Ce que le shader lit pour en décider, et pourquoi c'est juste pour les deux joueurs :
// - **le sol autour du corps** : la lightmap de LA VUE QUI DESSINE (`lire_lightmap(px, deux)`, la même que lisent le sol et
//   les murs iso), en huit points d'un cercle de `soi_fondu_rayon_px` autour de la position 2D du joueur (`centre`). La
//   lightmap d'une vue ne contient que les lumières que son joueur a le droit de voir (règle d'équité d'ISO2) : chacun juge
//   son propre corps sur son propre sol, avec la même règle ; le cercle est posé dans le MONDE 2D, pas à l'écran, donc le
//   lacet de la caméra (0°, 45°, le côté B de J2) ne change pas la décision ;
// - **le corps d'aujourd'hui, estimé pour le corps entier** (et non fragment par fragment, qui marbrerait le corps) : la
//   fiche × la lumière du capteur lue en quatre points au rayon lu (celle qui éclaire le corps aujourd'hui), composée avec la
//   silhouette de soi exactement comme aujourd'hui ;
// - **le contraste relatif** des deux luminances (|corps − sol| / la plus grande) : sous `soi_fondu_bas`, le corps se fond,
//   il prend l'essai A en entier ; au-dessus de `soi_fondu_haut`, il reste celui d'aujourd'hui ; entre les deux, un fondu.
// Rien d'autre : ni la position de l'adversaire, ni le réseau, ni l'état du jeu. Le calcul ne tourne que dans la vue de soi
// (sous `s > 0`, comme l'essai A) et ne sort jamais du corps. Noir absolu et règle des pochoirs tenus par construction : la
// couleur rendue est un mélange de celle d'aujourd'hui et de celle de l'essai A, jamais plus claire que la plus claire.
uniform float soi_fondu_rayon_px = 30.0;
uniform float soi_fondu_bas = 0.3;
uniform float soi_fondu_haut = 0.5;

// La luminance moyenne du sol autour du joueur, dans la lightmap de la vue qui dessine.
float soi_sol_autour(vec2 centre_px, bool deux) {
	float somme = 0.0;
	for (int i = 0; i < 8; i++) {
		float t = float(i) * 0.785398;
		somme += pate_luminance(lire_lightmap(centre_px + vec2(cos(t), sin(t)) * soi_fondu_rayon_px, deux));
	}
	return somme * 0.125;
}

// Le poids de l'essai A : 1 quand le corps d'aujourd'hui (`hier`, estimé pour le corps entier) se fond dans le sol.
float soi_fondu_poids(vec3 hier, float sol) {
	float l = pate_luminance(hier);
	float contraste = abs(l - sol) / max(max(l, sol), 0.0001);
	return 1.0 - smoothstep(soi_fondu_bas, soi_fondu_haut, contraste);
}
#endif
#endif
