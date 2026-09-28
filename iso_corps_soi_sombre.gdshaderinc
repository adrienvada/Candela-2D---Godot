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
#endif
