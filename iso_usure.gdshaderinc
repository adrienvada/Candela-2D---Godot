// ISO13, lot C — L'USURE EN ESSAI (`--usure-essai`, éteint par défaut ; essai d'ISO7 Beauté, 2026-09-24).
//
// L'ordre de la session cloud (2026-09-23, 23:58) : des murs abîmés — fissures, taches, impacts de balles qui RESTENT — et
// un sol jonché — douilles qui restent, gravats —, **visibles seulement dans la lumière, sans jamais cacher un joueur**,
// écrits pour n'importe quel lacet de caméra.
//
// Trois garanties, par construction :
// - **Un FACTEUR, jamais un terme** : chaque fonction rend un facteur dans [USURE_RESTE, 1] que l'appelant pose par
//   `pate_facteur` sur sa couleur déjà éclairée. 0 reste 0 : dans le noir, l'usure n'existe pas. Rien n'est jamais plus
//   clair que sans elle.
// - **Aucune géométrie** : l'usure se peint sur les faces et le sol déjà dessinés. Elle ne se lève pas devant un corps et
//   ne peut en masquer aucun ; au sol, sous un corps, le corps est dessiné par-dessus.
// - **Aucune face en dur** : tout se lit dans le repère de la face elle-même (sa normale, sa tangente, sa hauteur),
//   jamais « sud ». Une face que la caméra ne voit pas n'est pas dessinée (`cull_back`) ; au lacet de 45° (Q14), les
//   faces vues changent et leur usure avec elles, sans une ligne à reprendre.
//
// Les douilles, elles, existent déjà (`bullet_casing.gd`, 120 au plus) : la peinture de la carte (`peinture_iso.gd`) les
// copie une fois immobiles, et le sol iso les montre là où la lumière tombe. Ce fichier n'y ajoute que les gravats.
//
// Compilé seulement dans la variante USURE_ESSAI des shaders de murs et de sols (`IsoMateriaux.variante_definie`) : sans
// `--usure-essai`, le jeu n'exécute pas une instruction de plus.

#ifdef USURE_ESSAI

// 1 : l'usure s'applique ; 0 : la variante compilée rend l'image d'avant (bascule des bancs dans la même partie).
uniform float usure = 0.0;

// Les impacts de balles sur les murs, au plus USURE_IMPACTS_MAX (les plus récents) : xy le point d'impact en pixels de
// monde (le plan du sol, là où la balle a touché), z sa hauteur sur la face, w son rayon. Posés par la présentation à
// chaque éclat neuf (`wall_impact.gd`), jamais à chaque image.
const int USURE_IMPACTS_MAX = 48;
uniform vec4 usure_impacts[48];
uniform int usure_impacts_n = 0;

// Le plus sombre que l'usure rende, en valeur affichée : le cœur d'un impact.
const float USURE_RESTE = 0.22;

// La fissure d'une travée de face : au plus une par travée de `USURE_TRAVEE_PX`, une travée sur trois fissurée.
const float USURE_TRAVEE_PX = 46.0;

// Le facteur d'usure d'une FACE VERTICALE. `xz` : le fragment en pixels de monde (plan du sol) ; `n`, `tangente` : la
// normale de la face et sa tangente, dans ce plan ; `y` : la hauteur du fragment sur la face, `h` : celle de la face ;
// `px_monde` : pixels de monde par pixel d'écran (le trait ne descend jamais sous un pixel d'écran).
float usure_face(vec2 xz, vec2 n, vec2 tangente, float y, float h, float px_monde) {
	if (usure <= 0.0) {
		return 1.0;
	}
	float u = dot(xz, tangente);
	// Chaque face tire son propre bruit : sa normale décale la graine, deux faces d'un même coin ne se répètent pas.
	vec2 graine = n * 17.0;
	float f = 1.0;

	// Les TACHES : de larges plaques, et le salissement qui monte du pied (l'eau, la suie).
	float tache = smoothstep(0.58, 0.82, pate_bruit(vec2(u, y) / 24.0 + graine));
	float salissure = (1.0 - smoothstep(0.0, h * 0.4, y)) * pate_bruit(vec2(u, y) / 7.0 + graine.yx);
	f *= 1.0 - 0.2 * max(tache, 0.8 * salissure);
	// Les coulures : de minces traînées verticales sous le haut de la face.
	float coulure = smoothstep(0.7, 0.9, pate_bruit(vec2(u / 2.5, 0.0) + graine));
	coulure *= smoothstep(h * 0.2, h * 0.95, y) * pate_bruit(vec2(u / 2.5, y / 30.0) + graine.yx);
	f *= 1.0 - 0.14 * coulure;

	// Les FISSURES : une travée sur trois en porte une, qui descend en serpentant d'une hauteur au hasard.
	float travee = floor(u / USURE_TRAVEE_PX);
	float tirage = pate_hash(vec2(travee, dot(n, vec2(3.1, 7.7))));
	if (tirage < 0.34) {
		float t2 = pate_hash(vec2(tirage * 91.0, travee));
		float haut = h * mix(0.55, 1.0, t2);
		float bas = haut - h * mix(0.25, 0.6, pate_hash(vec2(travee, t2 * 53.0)));
		if (y < haut && y > bas) {
			float x0 = (travee + 0.3 + 0.4 * t2) * USURE_TRAVEE_PX;
			float x = x0 + (pate_bruit(vec2(y / 6.0, travee * 3.7)) - 0.5) * 9.0 + (haut - y) * (t2 - 0.5) * 0.35;
			// Plus fine vers sa pointe : le bas de la fissure.
			float largeur = mix(0.35, 0.9, (y - bas) / max(haut - bas, 1.0));
			float trait = pate_trait_de_bord(abs(u - x), max(largeur, px_monde * 0.5), px_monde);
			f = min(f, mix(1.0, 0.4, trait));
		}
	}

	// Les IMPACTS : un cœur noir, une étoile d'éclats. Seulement DEVANT la face qu'ils ont touchée : l'impact est posé
	// hors du mur, à quelques pixels de sa surface ; la face arrière d'un mur mince ne le reçoit pas.
	for (int i = 0; i < USURE_IMPACTS_MAX; i++) {
		if (i >= usure_impacts_n) {
			break;
		}
		vec4 p = usure_impacts[i];
		vec2 dp = p.xy - xz;
		float devant = dot(dp, n);
		if (devant < -1.5 || devant > 9.0) {
			continue;
		}
		vec2 q = vec2(dot(dp, tangente), p.z - y);
		float r = length(q);
		if (r > p.w * 2.4) {
			continue;
		}
		float angle = atan(q.y, q.x);
		float rayons = pow(abs(sin(angle * 3.5 + p.x * 0.37)), 6.0);
		float coeur = 1.0 - smoothstep(p.w * 0.45 - px_monde, p.w * 0.45 + px_monde, r);
		float eclats = (1.0 - smoothstep(p.w * 0.8, p.w * 2.4, r)) * rayons;
		float aureole = 1.0 - smoothstep(p.w * 0.5, p.w * 1.3, r);
		f = min(f, mix(1.0, USURE_RESTE, max(coeur, max(0.75 * eclats, 0.35 * aureole))));
	}
	return mix(1.0, max(f, USURE_RESTE), usure);
}

// Le facteur d'usure à poser sur une couleur déjà éclairée, par `pate_facteur` chez l'appelant (la garde de `test_iso_beaute`
// n'admet sur la couleur d'un mur que des `c = pate_facteur(c, …)` : l'appel reste lisible). **Allumé reste allumé** :
// l'usure s'efface sous 32/255 et n'existe plus sous 12/255 — les seuils du mannequin (ISO13, lot A). Un pixel à peine
// éclairé, multiplié par le cœur d'un impact (0,22), tomberait à 0 à l'écran : une lumière réelle effacée par un décor.
const vec2 USURE_SEUILS = vec2(0.0470588, 0.1254902);

float usure_poids(vec3 c, float f) {
	float w = smoothstep(USURE_SEUILS.x, USURE_SEUILS.y, pate_luminance(c));
	return mix(1.0, f, w);
}

#ifdef USURE_SOL
// La proximité des murs, préparée UNE FOIS par carte (`IsoMateriaux.image_proximite_usure`, levier 1 du 2026-09-25) : une
// lecture par pixel de sol au lieu de huit lectures de la grille. Un texel par pixel du monde, sur l'origine de la grille des
// murs ; trois niveaux (0, 0,5, 1), relus par seuils : la valeur exacte d'avant, au pixel près. Hors de la grille : 1 (le vide
// hors sol est solide, comme avant).
uniform sampler2D usure_proximite : filter_nearest, repeat_disable;
uniform vec2 grille_origine_px = vec2(0.0);
uniform vec2 grille_cases = vec2(1.0);

float usure_mur_pres(vec2 px) {
	vec2 uv = (px - grille_origine_px) / (tuile_px * grille_cases);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	float v = textureLod(usure_proximite, uv, 0.0).r;
	return v >= 0.75 ? 1.0 : (v >= 0.25 ? 0.5 : 0.0);
}
#endif

// Le facteur d'usure du SOL : les gravats, plus denses au pied des murs, et la poussière qui s'y dépose. `mur_pres` ∈
// [0, 1] : la présence d'un mur tout près (1 au pied), lue par l'appelant dans la grille des murs.
float usure_sol(vec2 px, float mur_pres, float px_monde) {
	if (usure <= 0.0) {
		return 1.0;
	}
	float f = 1.0 - 0.16 * mur_pres * pate_bruit(px / 6.0);
	// Les gravats : un éclat au plus par cellule de 6 px, au hasard, presque jamais loin d'un mur.
	vec2 cellule = floor(px / 6.0);
	float tirage = pate_hash(cellule + vec2(0.37, 5.1));
	if (tirage < 0.025 + 0.4 * mur_pres) {
		vec2 centre = (cellule + 0.2 + 0.6 * vec2(pate_hash(cellule + 1.3), pate_hash(cellule + 7.9))) * 6.0;
		float rayon = mix(0.7, 1.9, pate_hash(cellule + 4.2));
		vec2 d = px - centre;
		// Un éclat anguleux, pas un disque : la distance « en losange » tournée au hasard.
		float a = pate_hash(cellule + 2.6) * 6.2831;
		vec2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * d;
		float forme = abs(r.x) * 0.8 + abs(r.y) * 1.3;
		float eclat = 1.0 - smoothstep(rayon - px_monde * 0.5, rayon + px_monde * 0.5, forme);
		// Son liseré d'ombre, tout autour : un gravat est un volume, même vu de dessus. Autour et non décalée : un décalage
		// fixe dirait une lumière venue d'une direction du monde, qu'aucune lampe ne garantit.
		float ombre = 1.0 - smoothstep(rayon, rayon + 1.0, length(d));
		f = min(f, mix(1.0, 0.45, max(eclat, 0.5 * ombre)));
	}
	return mix(1.0, max(f, USURE_RESTE), usure);
}

#endif
