// ISO12 v27 — LE RELIEF NORMALISÉ. La 2D donne l'intensité, la 3D ne donne que le modelé :
//
//     couleur = albédo × L2D × R,    R = Σᵢ LIGHT_COLORᵢ · ATTENUATIONᵢ · max(N·Lᵢ, 0)  /  Σᵢ π · Iᵢ · attᵢ · côneᵢ · max(haut·Lᵢ, ε)
//
// Le numérateur est ce que `light()` accumule, l'ombre portée par ATTENUATION. Le dénominateur est ce que les MÊMES lampes
// donneraient au même point sur un sol plat, SANS ombre : il se calcule dans `fragment()` depuis la liste fermée du miroir
// (`LumieresIso.decrire_pour_relief`) et passe à `light()` par un varying. Une moyenne pondérée, jamais une somme : deux lampes
// sur un sol plat donnent 1, pas 2.
//
// ⚠️ **LA PREMIÈRE VERSION (b5fbf3a → 72a2364) N'ÉTAIT APPLIQUÉE NULLE PART** — revue d'ISO7 Beauté, arbitrée par la session
// cloud le 2026-09-22. Deux défauts l'éteignaient chacun à lui seul, trois autres l'auraient faussée :
//   1. le dénominateur voyageait par SPECULAR → SPECULAR_AMOUNT, et ce canal n'existe pas : dans `light()`, SPECULAR_AMOUNT
//      vaut 2 × `light_specular` de la LAMPE (documentation de Godot 4, table des entrées de `light()`), et le miroir pose 0.
//      Le dénominateur valait donc 0 partout, la garde rendait le Lambert brut : la v27 affichait la v26 ;
//   2. la liste des lampes n'était posée qu'à la bascule du drapeau (vide) et à la pose d'un corps (figée) ;
//   3. la décroissance était celle de Godot 3, (1 − d/r)^decay — R variait d'un facteur 12 le long d'un cône ;
//   4. le cône était un smoothstep — un anneau au plafond sur le bord de chaque cône de torche ;
//   5. le π de LIGHT_COLOR manquait — un sol plat aurait lu ≈ 2,8, écrêté.
// **Aucune suite ne pouvait le voir** : elles vérifient le TEXTE des shaders, pas l'image. Les « 1,0000 » et « 1,659 » écrits
// avant ce correctif étaient des calculs hors machine, sur des formules qui n'étaient pas celles du moteur.
//
// Le dénominateur recopie donc le moteur MOT POUR MOT (`scene.glsl` du rendu Compatibility, Godot 4.7) :
//   get_omni_spot_attenuation(d, 1/r, decay) = max(1 − (d/r)⁴, 0)² × max(d, 0,0001)^(−decay)
//   cône d'un spot : scos = max(dot(−L̂, dir), cosA) ; rim = max(0,0001, (1 − scos)/(1 − cosA)) ; × (1 − rim^exposant)
//   LIGHT_COLOR = couleur LINÉAIRE × énergie × π — le π est porté ici aussi.
// L'intensité Iᵢ est posée par le miroir : énergie × luminance, aux poids de la pâte (`PATE_POIDS`), de la couleur
// LINÉARISÉE — la luminance même avec laquelle la pâte lit la lumière, pour que R vaille 1 en luminance sur un sol plat.
//
// ⚠️ Huit lampes au plus, triées par intensité : le moteur, lui, apparie ses lampes PAR MAILLAGE. L'écart se chiffre au banc
// (`--v27-cadrage=neuf_lampes`) avant toute décision (défaut 7 de la revue).

uniform int relief_nb = 0;
uniform vec4 relief_pos_intensite[8];   // xyz : position monde ; w : énergie × luminance linéaire de la couleur
uniform vec4 relief_portee_cone[8];     // x : portée ; y : cos(demi-angle), < 0 pour une omni ; z : décroissance ; w : exposant de cône, 1 / spot_angle_attenuation comme le moteur
uniform vec4 relief_direction[8];       // xyz : direction du spot (vers l'avant) ; w : ε de la lampe (0 = non fourni)
// LE PLANCHER DU DÉNOMINATEUR, contre une lampe rasante (dot(haut, L) proche de 0). Il valait 0,2 et faisait manquer la règle
// à sa promesse sous une fusée posée ; à 0,02 il ne mord plus que sous 1,15° au-dessus de l'horizon (session cloud).
// ⚠️ ε est désormais PAR LAMPE (L4, ISO7 Gadgets) : min(h / portée, 0,02), porté par `relief_direction[i].w`. Cet uniforme
// n'est plus que le repli (w = 0) et le plafond. À 0,02 pour tous, braises et mine — posées à 1,75 px — voyaient le plancher
// mordre dès 87,5 px et le bord de leur halo tomber à 0,515 et 0,337.
uniform float relief_epsilon = 0.02;
// « Ni plus » borné, PAR LAMPE : un shader spatial n'offre aucun point après la boucle des lampes, donc une face sous deux lampes
// fortes peut dépasser ce plafond (le cadrage `recouvrement` du banc le chiffre). « Ni moins » reste libre dans les ombres.
uniform float relief_max = 1.5;
// ISO12 v27 — LE RELIEF NE CACHE JAMAIS (décision d'équité de la session cloud, 2026-09-23, 01:11). Sans plancher, une face
// tournée à l'opposé de toute lampe a R = 0 — au banc, un quart de la silhouette d'un adversaire que la 2D éclaire en entier
// sortait noir en 3D, et les ombres 3D, plus longues que les 2D, éteignaient du sol que la 2D montre. La règle demandée est
// R_final = max(R ; r_min) partout où la L2D est non nulle ; mais un shader spatial n'a AUCUN point après la boucle des
// lampes, donc aucun max sur leur somme. Ce qui s'écrit : R_final = r_min + (1 − r_min) · R — r_min en émission
// (`ALBEDO × relief_plancher`, nul là où la L2D l'est) et chaque lampe pondérée de (1 − r_min). Mêmes bornes que le max
// (r_min dans l'ombre, 1 sur le sol plat), un modelé un peu plus doux entre les deux. 0 : aucun plancher.
uniform float relief_plancher = 0.0;
// ISO12 v27 — LA 2D DONNE L'INTENSITÉ ET LA COULEUR (décision (3) de la session cloud, 01:11). La L2D était réduite à sa seule
// luminance avant de toucher l'albédo, et R est achromatique : la couleur de la lumière 2D ne venait plus de nulle part — le
// halo de la fusée sortait beige (saturation 0,18 contre 0,41 en 2D). `relief_chroma` rend la couleur de la L2D par canal,
// à luminance 1 : la valeur bridée × chroma redonne la L2D elle-même en bride identité. Faux : l'ancienne L2D grise (banc).
uniform bool relief_couleur_l2d = true;
// ISO12 v27 — LE PRINCIPE D'IDENTITÉ (décision de la session cloud, 2026-09-23, 02:17) : la 3D = la couleur du rendu 2D × R_final.
// L'ALBEDO du sol, des murs et des corps est EXACTEMENT la couleur que `sol_iso`, `mur_iso` et `corps_iso` rendent — pâte,
// température, couleur de la lumière, capteur des corps —, calculée par les MÊMES fonctions, recopiées au caractère près dans
// chaque shader éclairé (une garde de `tools/test_banc.gd` le vérifie : l'extraction dans un include aurait touché les shaders
// de la vue d'ISO11 et ceux des corps, chantiers d'autres sessions). R_final, achromatique, ne fait que la multiplier.
// ⚠️ Pourquoi : la base « albédo peint × L2D » d'avant était GRISE là où la 2D est chaude (la torche : 30° de teinte et 0,39 à
// 0,48 de saturation en 2D, 0,01 à 0,04 en base), et le chemin 2D n'y passait pas. Contrôle : `relief_plancher` à 1, la vue 3D
// égale la 2D. Faux : l'ancien chemin (albédo peint × L2D bridée), gardé pour la bissection au banc.
uniform bool identite_2d = true;
// ISO12 v27 — LE PLANCHER EN LINÉAIRE (session cloud, 02:33). Faux : l'ancien plancher, `ALBEDO × r_min` en émission brute, gardé
// pour la mesure qui a confirmé l'erreur au banc.
uniform bool relief_plancher_lineaire = true;

// Le polynôme par lequel Godot 4.7 (Compatibility) LINÉARISE l'albédo et l'émission après `fragment()` — recopié de
// `drivers/gles3/shaders/tonemap_inc.glsl`, `srgb_to_linear`. Ce n'est pas l'inverse exact de son `linear_to_srgb` (une
// puissance 0,4167) : aux faibles niveaux, l'aller-retour ne se referme pas, d'où l'inverse ci-dessous plutôt que l'autre.
vec3 godot_srgb_vers_lineaire(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

// L'émission dont Godot fera EXACTEMENT la valeur linéaire `y` : l'inverse du polynôme ci-dessus, par Newton (croissant et
// convexe sur [0 ; 1], trois pas depuis l'approximation en puissance suffisent au 1/255 près).
vec3 emission_pour_lineaire(vec3 y) {
	vec3 x = max(vec3(1.055) * pow(max(y, vec3(0.0)), vec3(0.416666667)) - vec3(0.055), vec3(0.0));
	for (int k = 0; k < 3; k++) {
		vec3 f = godot_srgb_vers_lineaire(x) - y;
		vec3 df = x * (x * 0.915918033 + 1.364342222) + 0.012522878;
		x = max(x - f / max(df, vec3(1e-4)), vec3(0.0));
	}
	return x;
}

// Le plancher du relief ajouté à l'émission `emission` d'un fragment d'albédo `albedo` : en linéaire, r_min × lin(albédo),
// sommé à l'émission existante EN LINÉAIRE aussi (une somme d'octets n'est pas une somme de lumières).
vec3 relief_emission_plancher(vec3 emission, vec3 albedo) {
	if (relief_plancher <= 0.0) {
		return emission;
	}
	if (!relief_plancher_lineaire) {
		return emission + albedo * relief_plancher;
	}
	return emission_pour_lineaire(godot_srgb_vers_lineaire(emission) + relief_plancher * godot_srgb_vers_lineaire(albedo));
}

vec3 relief_chroma(vec3 l2d) {
	float l = pate_luminance(l2d);
	if (!relief_couleur_l2d || l <= 1e-5) {
		return vec3(1.0);
	}
	return l2d / l;
}

// LE CANAL, cette fois réel : écrit dans `fragment()`, lu dans `light()`. La documentation de Godot 4 le prévoit — un varying
// donne à `light()` l'accès à ce que `fragment()` a calculé. Aucun encodage, donc aucune borne.
varying float relief_d;

// En dessous, aucune lampe connue n'éclaire ce point : la garde prend la main (voir `relief_vide`).
const float RELIEF_D_MIN = 1e-7;

// INSTRUMENT DE BANC, comme `masque_preuve` — jamais posé en jeu. 1 : `light()` rend le NUMÉRATEUR brut (le Lambert du moteur,
// × gain) ; 2 : `fragment()` émet ALBEDO × DÉNOMINATEUR × gain et `light()` ne rend rien. Les deux prises, divisées pixel par
// pixel, donnent R sans passer par le relief lui-même : c'est ainsi qu'on voit LEQUEL des deux termes s'écarte du moteur.
uniform int relief_diagnostic = 0;
uniform float relief_diagnostic_gain = 1.0;

// L'atténuation × le cône de la lampe `i` au point `monde_px`, SANS ombre — le moteur mot pour mot — et sa direction unitaire.
// 0 hors de portée. Partagée par le dénominateur et par la lampe dominante : une seule écriture de la formule du moteur.
float relief_att_cone(int i, vec3 monde_px, out vec3 L) {
	vec3 vers = relief_pos_intensite[i].xyz - monde_px;
	float d = length(vers);
	float portee = max(relief_portee_cone[i].x, 0.0001);
	L = vers / max(d, 0.0001);
	if (d >= portee) {
		return 0.0;
	}
	// get_omni_spot_attenuation, mot pour mot.
	float nd = d / portee;
	nd *= nd;
	nd *= nd;
	nd = max(1.0 - nd, 0.0);
	nd *= nd;
	float att = nd * pow(max(d, 0.0001), -relief_portee_cone[i].z);
	float cone = 1.0;
	float cos_demi = relief_portee_cone[i].y;
	if (cos_demi >= 0.0) {
		// Le cône du spot, mot pour mot : hors du cône, scos = cosA, rim = 1, et le facteur tombe à 0 sans seuil.
		float scos = max(dot(-L, normalize(relief_direction[i].xyz)), cos_demi);
		float rim = max(0.0001, (1.0 - scos) / max(1.0 - cos_demi, 0.0001));
		cone = 1.0 - pow(rim, relief_portee_cone[i].w);
	}
	return att * cone;
}

// ε PAR LAMPE (L4), porté par direction.w ; 0 = non fourni, on retombe sur l'uniforme global.
float relief_eps(int i) {
	return relief_direction[i].w > 0.0 ? relief_direction[i].w : relief_epsilon;
}

float relief_denominateur(vec3 monde_px) {
	vec3 haut = vec3(0.0, 1.0, 0.0);
	float d_total = 0.0;
	for (int i = 0; i < relief_nb; i++) {
		vec3 L;
		float ac = relief_att_cone(i, monde_px, L);
		if (ac <= 0.0) {
			continue;
		}
		d_total += PI * relief_pos_intensite[i].w * ac * max(dot(haut, L), relief_eps(i));
	}
	return d_total;
}

// ISO12 v27 — PROTOTYPE DE BANC : LA LAMPE DOMINANTE (ordre 152 de la session cloud). Le rendu Compatibility dessine chaque
// lampe à ombre dans SA passe additive, encodée en sRGB puis additionnée à l'image déjà encodée : deux contributions non nulles
// sur un pixel s'additionnent APRÈS encodage, et l'encodage étant concave, l'image s'éclaircit (mesuré le 2026-09-23 : (a) 1,06
// à 1,24 avec ombres, 0,96 à 1,01 sans). Ici, en chaque point, UNE seule passe écrit — celle de la lampe qui y domine
// (intensité × atténuation × cône, ombres exclues) ; les autres rendent 0, et la passe de base n'émet la 2D que là où aucune
// lampe ne porte. Coût : une couture là où la dominance bascule (nulle sur un sol plat, où ρ vaut 1 pour toute lampe).
// ⚠️ Une lampe dominante que le moteur n'apparie pas à l'objet (plus de `max_lights_per_object` lampes) laisserait NOIR ce que
// la 2D éclaire : le banc compte les lampes. Faux par défaut : jamais posé en jeu avant le GO.
uniform bool relief_dominante = false;
varying float relief_dom;

// L'indice de la lampe qui domine en `monde_px`, ou −1 si aucune n'y porte.
float relief_index_dominant(vec3 monde_px) {
	float meilleur = 0.0;
	float indice = -1.0;
	for (int i = 0; i < relief_nb; i++) {
		vec3 L;
		float poids = relief_pos_intensite[i].w * relief_att_cone(i, monde_px, L);
		if (poids > meilleur) {
			meilleur = poids;
			indice = float(i);
		}
	}
	return indice;
}

// Dans `light()` : la contribution de CETTE passe. Elle reconnaît sa lampe à sa direction (`LIGHT`, ramenée au monde, contre
// la direction de chaque lampe connue) ; si ce n'est pas la dominante, 0. Sinon r_min + (1 − r_min)·ρ·s, en LINÉAIRE, où
// ρ = N·L / max(haut·L, ε) — la couleur, l'énergie et l'atténuation se simplifient dans le rapport — et s, l'ombre seule, =
// ATTENUATION ÷ (atténuation × cône recalculés).
vec3 relief_contribution_dominante(vec3 lumiere, vec3 L_monde, vec3 monde_px, float attenuation, float n_dot_l,
		float dominante) {
	if (dominante < 0.0) {
		return vec3(0.0);
	}
	// ⚠️ DÉPARTAGE DÉTERMINISTE (session cloud, 03:13) : deux lampes vues dans la même direction depuis un fragment (une
	// fusée devant une torche) se prendraient toutes deux pour la même, et DEUX passes écriraient au même pixel — l'erreur
	// même que la lampe dominante existe pour ôter. La direction choisit les candidates (cosinus > 0,999), l'INTENSITÉ tranche :
	// LIGHT_COLOR vaut couleur linéaire × énergie × π, donc sa luminance ÷ π est l'intensité que le miroir a posée. À égalité
	// exacte des deux (deux lampes identiques au même endroit), le plus petit indice — et les deux passes écriraient :
	// une géométrie que le jeu ne produit pas.
	float intensite_passe = dot(lumiere, PATE_POIDS) / PI;
	int ici = -1;
	float ecart = 1e30;
	for (int i = 0; i < relief_nb; i++) {
		vec3 L;
		relief_att_cone(i, monde_px, L);
		if (dot(L, L_monde) <= 0.999) {
			continue;
		}
		float e = abs(relief_pos_intensite[i].w - intensite_passe);
		if (e < ecart) {
			ecart = e;
			ici = i;
		}
	}
	if (ici < 0 || float(ici) != dominante) {
		return vec3(0.0);
	}
	vec3 L;
	float ac = relief_att_cone(ici, monde_px, L);
	float s = ac > 1e-6 ? clamp(attenuation / ac, 0.0, 1.0) : 0.0;
	float rho = min(max(n_dot_l, 0.0) / max(L.y, relief_eps(ici)), relief_max);
	return vec3(relief_plancher + (1.0 - relief_plancher) * rho * s);
}

// INSTRUMENT DE BANC (modes 3 à 7) : un terme du dénominateur pour la lampe 0, émis tel quel pour être comparé au calcul.
// 3 : distance / 400 ; 4 : fenêtre de portée (1 − (d/r)⁴)² ; 5 : d^(−décroissance) × 50 ; 6 : cône ; 7 : max(haut·L, ε).
float relief_diag_terme(int mode, vec3 monde_px) {
	if (mode == 8) {
		// Une CONSTANTE : ce que la capture en rend dit si le chemin de l'émission jusqu'à l'image est linéaire.
		return relief_diagnostic_gain;
	}
	vec3 vers = relief_pos_intensite[0].xyz - monde_px;
	float d = length(vers);
	vec3 L = vers / max(d, 0.0001);
	float portee = max(relief_portee_cone[0].x, 0.0001);
	if (mode == 3) {
		return d / 400.0;
	}
	if (mode == 4) {
		float nd = d / portee;
		nd *= nd;
		nd *= nd;
		nd = max(1.0 - nd, 0.0);
		return nd * nd;
	}
	if (mode == 5) {
		return pow(max(d, 0.0001), -relief_portee_cone[0].z) * 50.0;
	}
	if (mode == 6) {
		float cos_demi = relief_portee_cone[0].y;
		float scos = max(dot(-L, normalize(relief_direction[0].xyz)), cos_demi);
		float rim = max(0.0001, (1.0 - scos) / max(1.0 - cos_demi, 0.0001));
		return 1.0 - pow(rim, relief_portee_cone[0].w);
	}
	float eps0 = relief_direction[0].w > 0.0 ? relief_direction[0].w : relief_epsilon;
	return max(dot(vec3(0.0, 1.0, 0.0), L), eps0);
}

// LA GARDE. Aucune lampe connue ici alors que la 2D peut y être éclairée : R vaut 1, c'est-à-dire LA 2D SEULE (arbitrage de
// la session cloud) — jamais le Lambert brut de la v26, qui ressusciterait l'éclairage qu'on remplace, jamais du noir.
// `fragment()` émet alors ALBEDO tel quel, et `light()` n'ajoute rien.
bool relief_vide(float d_total) {
	return d_total <= RELIEF_D_MIN;
}

// Dans `light()` : la contribution d'une lampe, déjà divisée par le dénominateur commun et plafonnée.
//
// ⚠️ **R ACHROMATIQUE** (session cloud, 2026-09-22, 23:46). La contribution se calcule sur la LUMINANCE de LIGHT_COLOR, aux poids
// PATE_POIDS du dénominateur, et rend ce scalaire sur les trois canaux. Calculée par canal, elle teignait l'image DEUX fois — la
// 2D porte déjà la couleur : sur un sol plat, une lampe donnait R = c_lin / lum(c_lin), soit (1,16 ; 0,98 ; 0,73) pour
// l'halogène et (3,64 ; 0,28 ; 0,36) pour la couleur de détresse, écrêtée à (1,50 ; 0,28 ; 0,36) : un halo de fusée vers 10° au
// lieu des 25° de la 2D. La 2D donne l'intensité ET la couleur ; la 3D ne donne que le relief.
vec3 relief_contribution(vec3 lumiere, float attenuation, float n_dot_l, float d_total) {
	float lum_lampe = dot(lumiere, PATE_POIDS);
	if (relief_diagnostic == 1) {
		return vec3(lum_lampe * attenuation * max(n_dot_l, 0.0) * relief_diagnostic_gain);
	}
	if (relief_diagnostic == 9) {
		// Instrument : ce que `light()` REÇOIT du varying, à comparer à ce que `fragment()` y a écrit (mode 2).
		return vec3(d_total * relief_diagnostic_gain);
	}
	if (relief_diagnostic >= 2) {
		return vec3(0.0);
	}
	if (relief_vide(d_total)) {
		return vec3(0.0);
	}
	// × (1 − r_min) : le plancher est déjà en émission (voir `relief_plancher`).
	return vec3(min(lum_lampe * attenuation * max(n_dot_l, 0.0) / d_total, relief_max) * (1.0 - relief_plancher));
}
