// Q40 — LA LAMPE CLAIRE, À L'ESSAI (`--lampe-claire`, éteint par défaut ; session cloud « lampe-claire », 2026-09-28).
//
// Les illustrations éclairent le sol et les murs d'une lampe en CRÈME, vers 200-240/255 ; le jeu, en OCRE, vers 126. Cet
// essai relève ce que la lampe éclaire, et le pâlit vers la couleur de la lampe elle-même, SANS rien changer de ce que le
// jeu LIT de la lumière. D'où l'endroit : la SORTIE des matériaux du sol et des murs de la vue iso, après toute lecture de
// la lightmap. En amont, rien ne bouge : ni la `PointLight2D` de la torche (couleur, énergie, texture, portée), ni la 2D,
// ni les capteurs des corps (leur propre sous-vue, leur propre shader), ni l'éblouissement (géométrie et énergie), ni le
// point noir de la lightmap. Personne ne relit ce que le sol et les murs écrivent — sauf le masque de la fumée, qui ne se
// demande que « noir ou pas » : la courbe est l'IDENTITÉ sous son genou (bien au-dessus du point noir), donc « noir ou pas »
// ne change pour aucun pixel.
//
// La courbe, sur la luminance ÉCRITE x (0..1, les poids de la pâte). La valeur écrite est celle que l'écran montre, hors
// du pied de la sortie 3D (7 → 0, 16 → 10, 32 → 27 : voir `volume_masque.gdshaderinc`), très sous le genou. ⚠️ Un
// premier jet la posait sur la valeur « affichée » de la pâte (`pate_vers_affiche`, linéarisée) : le cœur du cône (126
// à l'écran) y vaut ~0,21, au pied du genou, et l'essai n'y montait qu'à 163 (Cloître, 2026-09-28, 03:05).
//   w = force × smoothstep(genou.x, genou.y, x) × neutralité de la lumière reçue ;
//   y = x + w × (h(x) − x), h(x) = max(x, plafond × (1 − (1 − x)^gamma)) — une épaule, jamais sous x ;
//   la couleur : celle d'avant portée à la luminance y, mêlée de `paleur × w` de la crème portée à la même luminance.
// Garanties : éteint (force 0) ou sous le genou, `c` rendu TEL QUEL (au bit) ; 0 → 0 ;
// y monotone en x (dy/dx ≥ 1 − w + w·h' > 0) ; jamais plus sombre qu'avant ; luminance écrite = y exactement, hors
// plafond d'un canal à 1. Une lumière COLORÉE (fusée, LED ambre, carmin : neutralité 0,21 à 0,31) garde sa couleur et sa
// clarté : le poids de neutralité est nul sous `neutre.x`.
//
// Symétrique : la courbe ne lit que la lumière du point, jamais la vue ni le joueur ; la même pour J1 et J2, à tout lacet.
//
// Exige `iso_pate.gdshaderinc` (`pate_luminance`) et `iso_lightmap.gdshaderinc` (`lire_lightmap`) inclus AVANT.

uniform float lampe_claire : hint_range(0.0, 1.0) = 0.0;
uniform vec2 lampe_claire_genou = vec2(0.08, 0.40);
uniform float lampe_claire_gamma = 3.0;
uniform float lampe_claire_plafond : hint_range(0.0, 1.0) = 0.96;
uniform float lampe_claire_paleur : hint_range(0.0, 1.0) = 0.8;
// La crème, en valeurs écrites (seule sa teinte compte : elle est portée à la luminance y).
uniform vec3 lampe_claire_creme = vec3(0.98, 0.91, 0.80);
// La neutralité de la lumière REÇUE (1 − (max − min) / max) qui ouvre l'essai : 0 dessous, 1 dessus.
uniform vec2 lampe_claire_neutre = vec2(0.36, 0.50);

// La neutralité de la lumière reçue, en poids 0..1 (voir `pate_poids_neutre`, mêmes mesures, seuils plus bas : le sol
// sous une torche, lu dans la lightmap, porte déjà le brun des tuiles).
float lampe_claire_poids_neutre(vec3 brute) {
	float mx = max(brute.r, max(brute.g, brute.b));
	if (mx <= 0.0) {
		return 0.0;
	}
	float mn = min(brute.r, min(brute.g, brute.b));
	return smoothstep(lampe_claire_neutre.x, lampe_claire_neutre.y, 1.0 - (mx - mn) / mx);
}

// `c` : la couleur que le matériau allait écrire ; `brute` : la lumière reçue (la lightmap lue au point).
vec3 lampe_claire_sur(vec3 c, vec3 brute) {
	if (lampe_claire <= 0.0) {
		return c;
	}
	vec3 a = max(c, vec3(0.0));
	float x = pate_luminance(a);
	float w = lampe_claire * smoothstep(lampe_claire_genou.x, lampe_claire_genou.y, x)
		* lampe_claire_poids_neutre(brute);
	if (w <= 0.0 || x <= 0.0) {
		return c;
	}
	float h = max(x, lampe_claire_plafond * (1.0 - pow(1.0 - clamp(x, 0.0, 1.0), lampe_claire_gamma)));
	float y = x + w * (h - x);
	vec3 relevee = a * (y / x);
	vec3 creme = lampe_claire_creme * (y / max(pate_luminance(lampe_claire_creme), 0.0001));
	vec3 sortie = clamp(mix(relevee, creme, clamp(lampe_claire_paleur * w, 0.0, 1.0)), 0.0, 1.0);
	return sortie;
}

// Le sol : la lumière reçue n'y est pas encore lue quand la température est simple — elle ne l'est ici que si l'essai
// est allumé (éteint, aucune lecture de plus).
vec3 lampe_claire_au_sol(vec3 c, vec2 px, bool deux) {
	if (lampe_claire <= 0.0) {
		return c;
	}
	return lampe_claire_sur(c, lire_lightmap(px, deux));
}
