shader_type canvas_item;

// Le VOILE d'éblouissement — le flare de lampe torche qui arrive dans l'œil.
//
// ## Ce que ce shader remplace
//
// Un aplat blanc. `ui.gd` pose aujourd'hui deux `ColorRect` de couleur
// `HALOGENE` et d'alpha `dazzle × 0,3`, plat et non pulsé — décision du
// 2026-08-18, prise quand le voile faisait DEUX métiers (dire « tu es ébloui »
// et cacher l'adversaire). Le halo et le flou de `brouillage.gd` lui ont pris le
// second, et **localement** ; il ne lui reste que le premier. C'est ce qui
// rouvre la question de son apparence : un aplat était le bon choix pour un
// voile qui devait rester lisible en tant que JAUGE ; il n'a plus à l'être.
//
// ## L'invariant qui tient tout : le voile reste CENTRÉ
//
// ⚠️ **Le cœur ne se déplace jamais vers l'éblouisseur.** Le voile est posé sur
// la caméra du joueur ébloui, point. Ce qui penche du côté de l'éblouisseur,
// c'est le CARACTÈRE du flare — la longueur des aigrettes, l'axe des fantômes,
// le côté d'où vient le ressac. Un cœur déplacé ferait du voile une boussole, et
// rendrait en grand l'information que le halo de `brouillage.gd` passe son temps
// à effacer (voir `ALLONGEMENT_HALO` : le cœur du halo a été étiré exprès pour
// cesser de désigner un point).
//
// `anisotropie` est le seul réglage qui porte cette inclinaison. **Le mettre à
// zéro rend le voile rigoureusement non directionnel**, sans rien défaire
// d'autre : c'est la porte de sortie si le couplage se révèle trop bavard.
//
// ## Le repère
//
// `relevement` est l'angle de l'éblouisseur vu du joueur ébloui, en radians,
// `0` = à droite, et il croît dans le sens des aiguilles d'une montre parce que
// l'axe Y descend — en UV comme dans le monde 2D de Godot. **Les deux
// descendent, donc il n'y a AUCUN retournement de signe à faire**, et c'est
// exactement le genre d'évidence qui se paie deux heures quand elle est fausse.
//
// Les `Camera2D` du duel ne tournent jamais (`game_state.gd`), donc le
// relèvement du monde EST le relèvement de l'écran. C'est ce qui permet à ce
// shader de ne recevoir qu'un scalaire au lieu d'une transformée de vue — et
// donc de ne pas pouvoir se tromper de caméra, qui est le défaut nommé en tête
// de `brouillage_vue.gd`.
//
// ## Les trois candidats
//
// Trois propositions vivent dans un seul shader, choisies par `mode`. Un shader
// par candidat aurait fait diverger le socle commun — le cœur, le grain, la
// dose — et on aurait comparé trois socles au lieu de trois idées.
//
//   1 = « la gerbe penchée » + « les éclats »  (P1+P4)
//   2 = « la chaîne de fantômes »              (P2)
//   3 = « le ressac »                          (P3)
//   0 = rien : l'aplat d'aujourd'hui, le témoin contre lequel les trois se jugent.

uniform int mode : hint_range(0, 3) = 1;

// --- la dose ---------------------------------------------------------------

/// L'éblouissement du joueur, `0` à `1`. C'est `player.dazzle_amount`.
uniform float niveau : hint_range(0.0, 1.0) = 0.0;

/// `Brouillage.VOILE_FACTEUR` — l'opacité du voile à saturation. **0,3, arbitré
/// par Adrien au banc le 2026-08-25**, et ce shader n'a pas à le rejuger.
uniform float facteur : hint_range(0.0, 1.0) = 0.3;

/// Le gain de forme. L'aplat de 0,3 valait 0,3 PARTOUT ; un voile creusé qui
/// culminerait à 0,3 en son centre serait, en moyenne, beaucoup plus faible que
/// ce qui a été jugé. Le gain rattrape cet écart.
///
/// ⚠️ **2,5 est un point de départ, pas une mesure.** La valeur qui rend au
/// voile son opacité MOYENNE de 0,3 se relève au banc (touche `E`), qui rend le
/// voile sur du noir pur et lit l'image. Tant que ce relevé n'a pas eu lieu,
/// personne ne sait si le nouveau voile pèse plus ou moins lourd que l'ancien —
/// et « il a l'air pareil » n'est pas une réponse pour une mécanique qui coûte
/// 40 % de vitesse.
uniform float gain : hint_range(0.0, 6.0) = 2.5;

/// La teinte du voile — `Charte.HALOGENE`.
uniform vec3 teinte = vec3(0.98, 0.91, 0.80);

/// Le relèvement de l'éblouisseur, en radians. `0` = à droite.
uniform float relevement = 0.0;

/// Largeur / hauteur du rectangle. **Sans lui le cœur est un OVALE**, et un
/// ovale différent en écran scindé (957×1080, donc écrasé) et en vue unique
/// (1916×1080, donc étiré). Le défaut ne se voit que sur une capture des deux
/// modes côte à côte, c'est-à-dire jamais.
uniform float aspect = 1.0;

/// Le temps, en secondes. Un uniforme et non `TIME` : le banc doit pouvoir
/// figer l'animation pour juger une image fixe, et une suite doit pouvoir poser
/// un instant précis. `TIME` ne se pilote pas.
uniform float temps = 0.0;

// --- le cœur, commun aux trois ---------------------------------------------

/// Rayon du cœur, en fraction de la DEMI-HAUTEUR de l'écran. 1,0 = le cœur
/// meurt pile en haut et en bas de l'écran.
uniform float rayon_coeur : hint_range(0.1, 3.0) = 1.15;

/// L'exposant qui creuse le cœur : `(1 − r) ^ nettete`. Même famille que
/// `Brouillage.NETTETE_HALO` et `Eblouissement.COURBURE_LUMIERE`, et pour la
/// même raison — **les deux bornes ne bougent pas** (plein au centre,
/// rigoureusement nul au bord) quel que soit l'exposant. Un seuil ou un décalage
/// casserait l'une des deux, et celle du bord est la seule chose qui empêche le
/// voile d'avoir un CONTOUR. Un contour est une forme de plus à lire.
uniform float nettete_coeur : hint_range(0.5, 6.0) = 2.2;

// --- P1 : la gerbe penchée -------------------------------------------------

/// Portée des aigrettes, en fraction de la demi-hauteur.
uniform float portee_aigrettes : hint_range(0.0, 3.0) = 1.6;

/// **Le seul réglage qui fait pencher le voile.** La longueur d'une aigrette est
/// multipliée par `1 + anisotropie · cos(θ − relevement)` : du côté de
/// l'éblouisseur elles s'étirent, du côté opposé elles se rétractent. À 0, la
/// gerbe est parfaitement symétrique et le voile ne dit plus rien de personne.
uniform float anisotropie : hint_range(0.0, 1.0) = 0.55;

/// Tours par seconde de la rosette. Très lent à dessein : les pointes doivent
/// RAMPER. Même leçon que `Brouillage.DERIVE_HZ_*` — ce qui tremble vite est
/// intégré par l'œil et cesse d'exister ; ce qui rampe reste visible.
uniform float rotation_rosette : hint_range(0.0, 0.5) = 0.035;

/// Amplitude du scintillement de chaque aigrette, en fraction.
uniform float scintillement : hint_range(0.0, 1.0) = 0.30;

/// Le poids de la gerbe par rapport au cœur.
uniform float intensite_aigrettes : hint_range(0.0, 2.0) = 0.55;

// --- P4 : les éclats -------------------------------------------------------

/// Secondes entre deux éclats. Trois éclats se partagent la période, donc un
/// éclat naît toutes les `periode / 3` secondes.
uniform float eclats_periode : hint_range(0.05, 4.0) = 1.1;

/// Longueur et largeur d'un éclat, en fraction de la demi-hauteur. L'un très
/// supérieur à l'autre : un éclat est une traînée, pas une tache.
uniform float eclats_longueur : hint_range(0.01, 1.5) = 0.42;
uniform float eclats_largeur : hint_range(0.002, 0.4) = 0.030;

/// D'où l'éclat part, en fraction de la demi-hauteur. Au-delà de ~1,4 il naît
/// hors champ et l'on ne voit que sa fin.
uniform float eclats_depart : hint_range(0.5, 3.0) = 1.7;

/// L'ouverture, en radians, du secteur d'où les éclats arrivent. Zéro les
/// aligne tous sur le relèvement exact, ce qui se lit comme un rail.
uniform float eclats_dispersion : hint_range(0.0, 3.14) = 0.75;

uniform float eclats_intensite : hint_range(0.0, 2.0) = 0.65;

// --- P2 : la chaîne de fantômes --------------------------------------------

uniform int fantomes_nombre : hint_range(0, 6) = 4;

/// Écart entre deux fantômes, en fraction de la demi-hauteur.
uniform float fantomes_ecart : hint_range(0.05, 1.5) = 0.34;

uniform float fantomes_rayon : hint_range(0.02, 1.0) = 0.20;
uniform float fantomes_intensite : hint_range(0.0, 2.0) = 0.55;

/// ⚠️ **`+1` = du côté de l'éblouisseur, `−1` = du côté opposé.**
///
/// L'optique dit `−1` : dans un vrai flare, les fantômes tombent de l'autre côté
/// du centre par rapport à la source. C'est juste, c'est joli, **et ça se lit à
/// l'envers** — « le flare est à gauche, donc il est à gauche » est faux dans ce
/// cas-là. Le réglage existe pour que ce compromis soit tranché à l'œil et non
/// sur le papier ; il n'a pas de bonne valeur *a priori*.
uniform float fantomes_cote : hint_range(-1.0, 1.0) = -1.0;

// --- P3 : le ressac --------------------------------------------------------

/// Où commence le lavis, en fraction de la demi-hauteur mesurée le long de
/// l'axe du relèvement. Plus c'est haut, plus le lavis se serre contre le bord.
uniform float ressac_seuil : hint_range(0.0, 2.0) = 0.35;

uniform float ressac_intensite : hint_range(0.0, 2.0) = 0.85;

/// Amplitude de la respiration du seuil, en fraction de la demi-hauteur. Deux
/// fréquences bancales, comme la dérive du brouillage : une sinusoïde seule est
/// un balancier, et un balancier s'anticipe.
uniform float ressac_respiration : hint_range(0.0, 0.5) = 0.10;

// --- le grain, commun aux trois --------------------------------------------

/// Le grain d'optique sale. **C'est lui qui fera la différence entre « propre »
/// et « photographique »** : sur la référence d'Adrien, la moitié de ce qui se
/// lit comme une vraie photo est du bruit dans les demi-tons.
uniform float grain_force : hint_range(0.0, 1.0) = 0.35;
uniform float grain_echelle : hint_range(1.0, 400.0) = 90.0;

/// Une texture de salissure d'objectif, si on en a une. À défaut, un bruit de
/// valeur procédural — moins irrégulier, mais il ne manque jamais.
uniform sampler2D salissure : hint_default_black, filter_linear_mipmap,
	repeat_enable;
uniform bool a_salissure = false;

const float TAU_ = 6.28318530718;

// --- outils ----------------------------------------------------------------

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// Le profil radial commun : plein au centre, rigoureusement nul au-delà de
/// `rayon`. Une seule forme pour le cœur, les aigrettes et les fantômes — trois
/// profils différents auraient donné trois familles de bord à régler séparément.
float profil(float r, float rayon, float nettete) {
	return pow(max(1.0 - r / max(rayon, 1e-4), 0.0), nettete);
}

/// La longueur d'aigrette dans la direction `ang`, entre 0 et 1.
///
/// Somme d'harmoniques à fréquences premières entre elles : la rosette ne se
/// referme pas avant très longtemps, alors que l'effet dure moins de deux
/// secondes. Même principe que `Brouillage.derive` — déterministe, sans état,
/// donc reproductible d'une machine à l'autre et jugeable au banc.
float rosette(float ang) {
	float a = ang - temps * rotation_rosette * TAU_;
	float s = 0.50 * sin(a * 7.0);
	s += 0.30 * sin(a * 13.0 + 1.7);
	s += 0.20 * sin(a * 23.0 + 4.1);
	s += 0.12 * sin(a * 41.0 + 2.3);
	return smoothstep(-0.25, 0.95, s);
}

void fragment() {
	// Coordonnées centrées, en fraction de la DEMI-HAUTEUR. L'aspect est corrigé
	// ici, une fois, pour que tout ce qui suit raisonne en unités rondes.
	vec2 d = (UV - vec2(0.5)) * vec2(aspect, 1.0) * 2.0;
	float r = length(d);
	float ang = atan(d.y, d.x);
	vec2 vers = vec2(cos(relevement), sin(relevement));

	float v = 0.0;

	if (mode == 0) {
		// Le témoin : l'aplat d'aujourd'hui. Il ne passe ni par `gain` ni par le
		// grain — sinon ce ne serait plus le témoin, ce serait un quatrième
		// candidat déguisé en référence.
		COLOR = vec4(teinte, clamp(niveau, 0.0, 1.0) * facteur);
	} else {
		float coeur = profil(r, rayon_coeur, nettete_coeur);
		v = coeur;

		if (mode == 1) {
			// ── P1 — la gerbe penchée.
			float l = rosette(ang);
			// L'inclinaison, et c'est tout ce qui dit où est l'éblouisseur : les
			// aigrettes de son côté s'étirent, celles d'en face se rétractent.
			float pente = 1.0 + anisotropie * cos(ang - relevement);
			float portee = portee_aigrettes * l * pente;
			// Le scintillement est propre à chaque direction : une pulsation
			// commune se lirait comme un clignotement de l'écran entier.
			float sc = 1.0 + scintillement
				* sin(temps * (3.1 + 1.7 * sin(ang * 11.0)) + ang * 17.0);
			v += profil(r, portee, 1.4) * l * sc * intensite_aigrettes;

			// ── P4 — les éclats qui traversent.
			//
			// Trois traînées se partagent la période, chacune décalée d'un tiers.
			// Toute la vie d'un éclat tient dans `fract()` : aucune variable
			// d'état, donc rien à réinitialiser entre deux manches et rien qui
			// puisse diverger entre deux machines.
			float somme = 0.0;
			for (int i = 0; i < 3; i++) {
				float fi = float(i);
				float ph = fract(temps / max(eclats_periode, 1e-3) + fi / 3.0);
				// Un cap tiré au sort par éclat ET par tour : sans le numéro de
				// tour dans le hachage, les trois mêmes éclats repasseraient
				// indéfiniment sur les trois mêmes rails.
				float tour = floor(temps / max(eclats_periode, 1e-3) + fi / 3.0);
				float tirage = hash21(vec2(fi * 7.13, tour)) - 0.5;
				float a = relevement + tirage * eclats_dispersion;
				vec2 u = vec2(cos(a), sin(a));
				vec2 centre = u * mix(eclats_depart, 0.0, ph);
				vec2 rel = d - centre;
				float le = dot(rel, u);
				float tr = dot(rel, vec2(-u.y, u.x));
				float g = exp(-(le * le) / (2.0 * eclats_longueur * eclats_longueur)
					- (tr * tr) / (2.0 * eclats_largeur * eclats_largeur));
				// Naît de rien, meurt de rien : un éclat qui apparaît à pleine
				// intensité se lit comme un défaut d'affichage.
				somme += g * sin(ph * 3.14159265);
			}
			v += somme * eclats_intensite;

		} else if (mode == 2) {
			// ── P2 — la chaîne de fantômes.
			//
			// Le cœur reste au centre ; c'est l'AXE de la chaîne qui porte la
			// direction. Voir `fantomes_cote` pour le piège de lecture.
			for (int i = 0; i < 6; i++) {
				if (i >= fantomes_nombre) { break; }
				float fi = float(i) + 1.0;
				vec2 centre = vers * (fantomes_ecart * fi) * fantomes_cote;
				// Des rayons irréguliers : quatre disques identiques se lisent
				// comme une règle graduée, donc comme une mesure.
				float rayon = fantomes_rayon * (0.55 + 0.45 * sin(fi * 2.31));
				rayon *= 1.0 + 0.12 * sin(temps * 0.9 + fi * 1.7);
				float dd = length(d - centre) / max(rayon, 1e-4);
				float disque = profil(dd, 1.0, 2.0) * 0.55;
				// L'anneau : c'est lui qui fait « optique » plutôt que « tache ».
				//
				// ⚠️ **`t * t` et non `pow(t, 2.0)`.** `t` passe par des valeurs
				// NÉGATIVES en deçà du rayon de l'anneau, et `pow()` d'une base
				// négative est *undefined* en GLSL : selon le pilote on obtient
				// zéro, un NaN, ou le bon résultat. Un défaut qui dépend de la
				// machine ne se reproduit pas sur celle où on le cherche.
				float t = (dd - 0.78) / 0.13;
				float anneau = exp(-t * t) * 0.45;
				v += (disque + anneau) * fantomes_intensite / fi;
			}

		} else {
			// ── P3 — le ressac.
			//
			// Aucune forme, aucune pointe : un lavis qui bave du bord, du côté de
			// l'éblouisseur, et qui respire. Deux fréquences bancales pour que la
			// respiration ne s'anticipe pas.
			float souffle = ressac_respiration
				* (0.6 * sin(temps * TAU_ * 0.19) + 0.4 * sin(temps * TAU_ * 0.31 + 1.3));
			float proj = dot(d, vers);
			v += smoothstep(ressac_seuil + souffle, ressac_seuil + souffle + 1.0,
				proj) * ressac_intensite;
		}

		// ── Le grain. Multiplicatif, et il épargne le cœur saturé : une salissure
		// qui mordrait le blanc plein se lirait comme du bruit de compression.
		if (grain_force > 0.001) {
			vec2 p = UV * vec2(aspect, 1.0) * grain_echelle
				+ vec2(temps * 0.9, temps * -0.6);
			float n = a_salissure
				? texture(salissure, p / grain_echelle * 1.4).r
				: bruit(p);
			v *= mix(1.0, 0.45 + 1.1 * n, grain_force * (1.0 - min(v, 1.0)));
		}

		COLOR = vec4(teinte,
			clamp(v * gain, 0.0, 1.0) * clamp(niveau, 0.0, 1.0) * facteur);
	}
}
