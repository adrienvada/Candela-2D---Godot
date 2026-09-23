// ISO13, lot A — LES CORPS LUS COMME LES MANNEQUINS DES ILLUSTRATIONS (chantier d'ISO7 Beauté, 2026-09-24, ordre de la
// session cloud après la décision d'Adrien : « le visuel du jeu doit ressembler au plus proche aux visuels générés pour
// illustrer le jeu dans les menus »). Derrière `--mannequin`, éteint par défaut, indépendant de la tenue.
//
// Les illustrations montrent un mannequin articulé — tête cube, plaques du torse, coudes et genoux marqués —, éclairé d'un
// côté et noir de l'autre, cerné d'encre. À l'échelle du jeu (quelques dizaines de pixels), il en reste trois indices :
// - **les segments** : une ligne d'encre sous la poitrine et à la ceinture du torse, une au coude et une au genou
//   (`mannequin_segments`), posées comme l'encre des arêtes — aucune boîte de plus, donc ni l'empreinte, ni la zone de
//   touche, ni le nombre de maillages ne bougent ;
// - **le côté de la lumière** (`mannequin_modeler`) : `mannequin_lumiere` est la direction HORIZONTALE vers la lumière qui
//   éclaire vraiment ce corps, calculée sur le processeur par `MannequinIso.direction_dominante()` depuis les Light2D du
//   jeu (position, intensité, cône, murs) ; sa longueur dit à quel point cette lumière vient d'un seul côté. La face
//   tournée vers elle garde la lumière d'aujourd'hui, celle qui lui tourne le dos s'assombrit ;
// - **le contour** : une seconde encre d'arête, plus large et plus sombre, par-dessus celle d'ISO3.
//
// ⚠️ **Pourquoi pas le gradient de la lightmap** : c'est lui qu'ISO7b avait éteint, parce qu'il lit le BORD d'une tache de
// lumière et non la direction de sa source — il s'inversait au passage d'un cône. Ici la direction est géométrique (du
// corps vers chaque lampe, pondérée), et une face tournée vers une lampe ne peut pas s'assombrir à cause d'elle.
// ⚠️ **L'équité nord / sud, et le mannequin n'éclaire jamais.** La caméra au lacet 0 ne voit que les dessus et les faces
// tournées vers le sud. Assombrir seule la face sud d'un corps éclairé depuis le nord le rendrait moins visible qu'un corps
// éclairé depuis le sud : un adversaire plus facile à voir selon qu'il est au-dessus ou au-dessous de vous à l'écran.
// Lumière au sud, ce sont donc les DESSUS qui s'assombrissent (une lumière rasante venue de la caméra), d'autant plus que
// leur aire vue est petite (`mannequin_report`) : la perte vue est la même dans les deux cas. Une première forme
// RÉPARTISSAIT (les dessus montaient de ce que perdait la face sud) : l'écran écrasant les valeurs sombres, la part montée
// ne compensait plus la part descendue en lumière faible (équité 0,42 à 0,1), et elle sortait du noir des pixels que
// l'écran arrondissait à 0. Un facteur ≤ 1 ne peut ni l'un ni l'autre : aucun pixel voyant, aucun noir rallumé.
// Noir absolu : tout passe par des facteurs sur la lumière rendue ; 0 reste 0.
// ⚠️ **Et rien sous le seuil** (`mannequin_seuils`, en fondu de 12/255 à 32/255 de la lumière reçue par le corps — la même
// pour ses dessus et ses faces, pour que le fondu ne pèse pas plus sur les unes que sur les autres), mesuré au banc des corps
// (2026-09-24, 00:37) : posé à toute lumière, le mannequin sortait du noir 1 848 pixels que l'écran arrondissait à 0 (le
// dessus monté à ×1,64 lumière au nord), l'équité nord/sud tombait de 0,96 à 0,8 de lumière à 0,42 à 0,1 (l'écran écrase les
// valeurs sombres : ce que perd la face sud ne revient plus par les dessus), et l'encre retirait un tiers des pixels
// visibles à 0,15. Sous le seuil, là où l'on commence à voir un adversaire, le corps est exactement celui d'aujourd'hui.

uniform float mannequin : hint_range(0.0, 1.0) = 0.0;
// Direction horizontale (x, z du monde) vers la lumière dominante ; longueur 0..1 = sa netteté.
uniform vec2 mannequin_lumiere = vec2(0.0);
// Le contraste du modelé : une face latérale dos à la lumière × (1 − contraste) ; face à elle, × 1.
uniform float mannequin_contraste : hint_range(0.0, 1.0) = 0.4;
// L'aire vue des faces latérales sur celle des dessus : lumière au sud, les dessus perdent contraste × report.
uniform float mannequin_report = 1.6;
uniform vec3 mannequin_plafond = vec3(1.0);
// Les demi-tailles des boîtes (tuiles), pour reconnaître le torse, les bras et les jambes.
uniform vec3 mannequin_demi_torse = vec3(0.0);
uniform vec3 mannequin_demi_bras = vec3(0.0);
uniform vec3 mannequin_demi_jambe = vec3(0.0);
// Le facteur d'une ligne de segment (comme l'encre des arêtes) et sa demi-largeur en pixels du monde.
uniform float mannequin_encre = 0.5;
uniform float mannequin_trait_px = 0.5;
// Le contour : une seconde encre d'arête, plus large et plus sombre, par-dessus celle d'ISO3 (qui reste telle quelle).
uniform float mannequin_contour_px = 0.8;
uniform float mannequin_contour_reste = 0.7;
// Le fondu du mannequin selon la lumière reçue par le corps (clarté de la fiche × lumière, avant la pâte) : rien en dessous
// du premier seuil, entier au-dessus du second.
uniform vec2 mannequin_seuils = vec2(0.0470588, 0.1254902); // 12/255, 32/255 : un littéral (le défaut d'un uniforme)

float mannequin_poids(float niveau) {
	return mannequin < 0.5 ? 0.0 : smoothstep(mannequin_seuils.x, mannequin_seuils.y, niveau);
}

bool mannequin_est(vec3 d, vec3 ref) {
	return ref.x > 0.0 && all(lessThan(abs(d - ref), vec3(0.0005)));
}

// Le facteur de modelé d'une face de normale MONDE `n`.
float mannequin_facteur(vec3 n) {
	if (mannequin < 0.5) {
		return 1.0;
	}
	float nette = min(length(mannequin_lumiere), 1.0);
	if (nette < 0.001) {
		return 1.0;
	}
	vec2 l = mannequin_lumiere / length(mannequin_lumiere);
	if (n.y > 0.5) {
		// Le dessus : sombre quand la lumière vient du sud (+z), rasante depuis la caméra.
		return clamp(1.0 - mannequin_contraste * nette * max(l.y, 0.0) * mannequin_report, 0.0, 1.0);
	}
	vec2 h = n.xz;
	float lh = length(h);
	if (lh < 0.001) {
		return 1.0;
	}
	return clamp(1.0 - mannequin_contraste * nette * max(-dot(h / lh, l), 0.0), 0.0, 1.0);
}

vec3 mannequin_modeler(vec3 c, vec3 n, float niveau) {
	float w = mannequin_poids(niveau);
	if (w <= 0.0) {
		return c;
	}
	return pate_facteur(c, mix(1.0, mannequin_facteur(n), w));
}

// Le facteur des lignes de segment et du contour, au fragment : 1 hors d'une ligne, `mannequin_encre` sur un segment (faces
// latérales seulement : les dessus n'ont pas de plaque), `mannequin_contour_reste` au bord de chaque face.
float mannequin_segments(vec3 lp, vec3 d, vec3 ech, vec3 n, float px_par_unite, float px_monde, float niveau) {
	float w = mannequin_poids(niveau);
	if (w <= 0.0) {
		return 1.0;
	}
	// En pixels du monde, comme le trait : `pate_encre_boite` compte en unités du monde (1 px en jeu, une tuile au banc).
	float contour = pate_encre_boite(lp, d, ech, n, mannequin_contour_px / max(px_par_unite, 0.0001), mannequin_contour_reste,
		px_monde);
	if (abs(n.y) > 0.5) {
		return mix(1.0, contour, w);
	}
	float hauteur = d.y * 2.0;
	float y = lp.y + d.y;  // 0 en bas de la boîte, `hauteur` en haut
	float px = ech.y * px_par_unite;
	float trait = 1.0;
	if (mannequin_est(d, mannequin_demi_torse)) {
		// Sous la poitrine et à la ceinture : les plaques des illustrations.
		trait = min(step(mannequin_trait_px, abs(y - hauteur * 0.62) * px), step(mannequin_trait_px, abs(y - hauteur * 0.3) * px));
	} else if (mannequin_est(d, mannequin_demi_bras) || mannequin_est(d, mannequin_demi_jambe)) {
		// Le coude et le genou, à mi-longueur.
		trait = step(mannequin_trait_px, abs(y - hauteur * 0.5) * px);
	}
	return mix(1.0, min(mix(mannequin_encre, 1.0, trait), contour), w);
}

vec3 mannequin_borner(vec3 c) {
	return mannequin < 0.5 ? c : min(c, mannequin_plafond);
}
