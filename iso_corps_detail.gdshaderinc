// ISO13 — LE PERSONNAGE DÉTAILLÉ À L'ESSAI (`--corps-detaille`, éteint par défaut ; essai d'ISO7 Beauté, 2026-09-24, une
// classe : le pistolet, d'après son portrait V3 froide).
//
// Deux choses, sur la COULEUR DE FICHE seulement (celle que `portrait_teindre` pose ensuite sur la lumière rendue au gris) :
// - **les accessoires modelés** (`VoxelCorps._detailler`) — sangle, cartouches, étui, robinet, manomètres, crosse — sont des
//   boîtes de la même matière, reconnues à leur demi-taille comme le torse ou la bouteille, et prennent la couleur de leur
//   rôle : cuir, laiton, métal ;
// - **la matière peinte du portrait** : un marbrage large et des pores, accrochés à la boîte (ils suivent le corps, jamais
//   l'écran), qui ne font qu'ASSOMBRIR la fiche.
//
// Garanties, par construction :
// - **La couleur, jamais la visibilité** : toutes les couleurs des rôles sont à un rapport ≤ 1 du gris de la classe
//   (`VoxelCatalogue.palette_details`), et les pores comme le marbrage multiplient la fiche par ≤ 1. Or `portrait_teindre`
//   rend une clarté proportionnelle à celle de la fiche : rien ne sort plus clair qu'aujourd'hui, rien ne s'allume dans le
//   noir (0 reste 0), l'adversaire n'apparaît pas plus tôt.
// - **Aucun pixel voyant à la taille du duel** : les pores s'effacent quand un pixel d'écran couvre plus d'un demi-pixel du
//   monde (le duel, à ×1,5, en couvre 0,67) et reviennent entiers sous 0,3 (killcam, menus, bancs). Le marbrage, large de
//   plusieurs pixels, reste partout : il ne scintille pas.
// - Albédo seul : ni émission, ni `light()`, ni relief. Compilé dans la seule variante CORPS_DETAIL de `corps_iso` (et de son
//   jumeau éclairé) : sans le drapeau, le jeu n'exécute pas une instruction de plus.

#ifdef CORPS_DETAIL

uniform float detail = 0.0;
// Les demi-tailles des accessoires (tuiles) et leur rôle : 0 cuir, 1 laiton, 2 métal. `detail_n` : combien sont posés.
uniform vec3 detail_demi[10];
uniform int detail_role[10];
uniform int detail_n = 0;
uniform vec4 detail_cuir : source_color = vec4(1.0);
uniform vec4 detail_laiton : source_color = vec4(1.0);
uniform vec4 detail_metal : source_color = vec4(1.0);
// La force des pores et du marbrage : 0 les éteint (la bascule des bancs, même partie).
uniform float detail_matiere = 1.0;

// Le pire assombrissement de la matière peinte : un pore au plus profond, sur un marbrage sombre.
const float DETAIL_PORE = 0.62;
const float DETAIL_MARBRE = 0.86;

vec3 detail_fiche(vec3 fiche, vec3 lp, vec3 d, vec3 ech, vec3 n, float px_par_unite, float px_monde) {
	if (detail < 0.5 || portrait < 0.5) {
		return fiche;
	}
	vec3 c = fiche;
	for (int i = 0; i < 10; i++) {
		if (i >= detail_n) {
			break;
		}
		if (portrait_est(d, detail_demi[i])) {
			c = detail_role[i] == 0 ? detail_cuir.rgb : (detail_role[i] == 1 ? detail_laiton.rgb : detail_metal.rgb);
			break;
		}
	}
	// Les coordonnées de la face, en pixels du monde, accrochées à la boîte : horizontale, verticale.
	vec3 q = lp * ech * px_par_unite;
	vec3 an = abs(n);
	vec2 f = an.x > 0.5 ? q.zy : (an.y > 0.5 ? q.xz : q.xy);
	// Chaque face tire sa propre graine : deux faces d'une boîte ne se répètent pas.
	vec2 graine = n.xz * 13.1 + vec2(n.y * 7.7, d.x * 91.0 + d.y * 37.0);
	// Le marbrage : large (7 px), doux, toujours là.
	float marbre = mix(1.0, DETAIL_MARBRE, smoothstep(0.35, 0.85, pate_bruit(f / 7.0 + graine)));
	// Les pores : au plus un par cellule de 2,4 px, un sur quatre, un disque d'un demi-pixel du monde au plus.
	float ecran = px_monde * px_par_unite;
	float fondu = 1.0 - smoothstep(0.3, 0.5, ecran);
	float pore = 0.0;
	if (fondu > 0.0) {
		vec2 cellule = floor(f / 2.4);
		float tirage = pate_hash(cellule + graine);
		if (tirage < 0.25) {
			vec2 milieu = (cellule + 0.25 + 0.5 * vec2(pate_hash(cellule + graine + 3.1), pate_hash(cellule + graine + 8.3))) * 2.4;
			float r = mix(0.3, 0.55, pate_hash(cellule + graine + 5.7));
			pore = (1.0 - smoothstep(r * 0.6, r, length(f - milieu))) * fondu;
		}
	}
	float k = marbre * mix(1.0, DETAIL_PORE, pore);
	return c * mix(1.0, k, detail_matiere);
}

#endif
