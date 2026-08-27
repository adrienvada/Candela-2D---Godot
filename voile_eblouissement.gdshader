shader_type canvas_item;

// Le VOILE d'éblouissement — une caméra qui prend une lampe dans l'objectif.
//
// ## L'image de départ, et elle décide de toute la construction
//
// « Imagine que notre vue, notre UI, c'est entièrement une caméra éblouie par
// une lampe » (Adrien, 2026-08-27). Ce n'est pas une forme posée sur du noir :
// c'est **tout le cadre qui blanchit**, plus fort au centre, avec des lueurs et
// des flares qui bougent dedans.
//
// ⚠️ **Un premier jet a fabriqué l'inverse**, et l'erreur est instructive : un
// cœur en `(1 − r)^n` qui tombe à zéro laissait les tiers gauche et droit de
// l'écran **rigoureusement noirs**. Le résultat se lisait comme une décoration
// centrée, pas comme un aveuglement. La borne « nul au bord » est juste pour un
// halo — un halo est un objet DANS le monde et doit cesser quelque part. Elle
// est fausse pour un voile, qui est l'état de l'ŒIL et n'a pas de bord.
//
// ## D'où la structure : un SOL, et ce qui se pose dessus
//
//     alpha = niveau × [ mélange(plancher, cime, creux) + lueurs + flares + fantômes ]
//
// `plancher` est l'aplat d'aujourd'hui — 0,30, arbitré par Adrien le
// 2026-08-25. **Il ne descend jamais en dessous**, nulle part sur l'écran. Le
// voile actuel est donc le plancher du nouveau, littéralement : la refonte ne
// peut pas alléger la mécanique par accident, elle ne peut que l'appuyer.
// `cime` dit jusqu'où le centre monte au-dessus.
//
// ## Pourquoi des TEXTURES et non des formules
//
// « Ne peut-on pas prendre une texture qui génère comme une lumière, et
// l'animer d'une façon maline et pas chère » (Adrien). Trois textures — une
// lueur ronde, une traînée, un fantôme d'objectif — et tout le reste n'est que
// des matrices : on les échantillonne à des échelles, des angles et des
// décalages qui dérivent lentement. Une douzaine de lectures de texture pour
// toute la gerbe, contre une trentaine d'opérations trigonométriques par pixel
// dans la première version.
//
// Les fantômes sont ce qui fait basculer l'image de « effet » à « photo » : un
// ŒIL n'a pas de fantômes, un OBJECTIF en a — et c'est l'objectif qu'on demande
// au joueur de croire.
//
// Et surtout : **une texture se remplace.** Le jour où une vraie photo de flare
// arrive, elle se substitue à celle qu'on fabrique, sans toucher au shader.
//
// ## L'invariant, posé par Adrien contre une première lecture
//
// ⚠️ **Le voile reste CENTRÉ sur la caméra du joueur.** Le cœur ne se déplace
// jamais vers l'éblouisseur. Ce qui penche est le CARACTÈRE — les lueurs
// glissent de son côté, les flares s'y étirent. Un cœur déplacé ferait du voile
// une boussole et rendrait en grand l'information que `ALLONGEMENT_HALO` passe
// son temps à effacer.
//
// `flares_penche` et `lueurs_derive` portent seuls cette inclinaison : à zéro,
// le voile redevient rigoureusement non directionnel sans rien défaire d'autre.
//
// ## Le repère
//
// `relevement` = l'angle de l'éblouisseur vu du joueur, en radians, `0` = à
// droite, croissant dans le sens des aiguilles d'une montre — l'axe Y descend
// en UV **comme** dans le monde 2D de Godot, donc **aucun retournement de signe
// à faire**. Les `Camera2D` du duel ne tournant jamais (`game_state.gd`), le
// relèvement du monde EST celui de l'écran : ce shader ne reçoit qu'un scalaire,
// et ne peut donc pas se tromper de caméra.

uniform int mode : hint_range(0, 1) = 1;

// --- la dose ---------------------------------------------------------------

/// L'éblouissement du joueur, `0` à `1` — c'est `player.dazzle_amount`.
uniform float niveau : hint_range(0.0, 1.0) = 0.0;

/// **Le SOL du voile : ce qu'il vaut partout, même dans les coins.** 0,30, et
/// c'est exactement l'aplat d'aujourd'hui (`Brouillage.VOILE_FACTEUR`, arbitré
/// par Adrien au banc le 2026-08-25). Le nouveau voile part de l'ancien.
uniform float plancher : hint_range(0.0, 1.0) = 0.30;

/// Ce que vaut le voile au CENTRE. L'écart avec le plancher est tout l'effet.
/// **0,34, relevé au banc par Adrien le 2026-08-27** — « les valeurs de plancher
/// et de cime me semblent pas mal là ». Elle valait 0,88 à l'ouverture, et
/// l'écart dit quelque chose : à 0,34 le lavis est presque PLAT (0,30 aux bords,
/// 0,34 au centre), et toute la structure visible vient des lueurs et des flares
/// qui s'y ajoutent. Le voile blanchit ; ce sont les lueurs qui le sculptent.
uniform float cime : hint_range(0.0, 1.0) = 0.34;

/// Sur quelle distance le lavis descend de `cime` vers `plancher`, en fractions
/// de la DEMI-HAUTEUR. **1,9 : le lavis est encore à mi-course dans les coins**
/// d'un 16/9. C'est ce qui fait un aveuglement plutôt qu'une tache.
uniform float largeur : hint_range(0.2, 5.0) = 1.9;

/// La courbe du lavis. Sous 1, le centre s'aplatit et l'écran blanchit presque
/// uniformément ; au-dessus, le centre se creuse.
uniform float courbe : hint_range(0.2, 4.0) = 1.5;

/// La teinte du voile — `Charte.HALOGENE`.
uniform vec3 teinte = vec3(0.98, 0.91, 0.80);

uniform float relevement = 0.0;

/// Largeur / hauteur du rectangle. **Sans lui le voile est un OVALE**, et un
/// ovale différent en écran scindé (957×1080) et en vue unique (1916×1080) —
/// un défaut qui ne se voit que sur une capture des deux modes côte à côte.
uniform float aspect = 1.0;

/// Le temps, en secondes. Un uniforme et non `TIME` : le banc doit pouvoir
/// figer l'animation pour juger une image fixe, et une suite doit pouvoir poser
/// un instant précis. `TIME` ne se pilote pas.
uniform float temps = 0.0;

// --- les deux textures -----------------------------------------------------

/// Une lueur ronde, blanche au centre et noire au bord.
uniform sampler2D lueur_tex : hint_default_black, filter_linear, repeat_disable;

/// Une traînée horizontale, vive sur l'axe et éteinte partout ailleurs.
///
/// ⚠️ **Les deux textures DOIVENT être noires sur tout leur pourtour.** On les
/// échantillonne hors de leurs bornes en permanence, et `repeat_disable` étire
/// le texel du bord à l'infini : un bord non nul peindrait une bande sur la
/// moitié de l'écran.
uniform sampler2D flare_tex : hint_default_black, filter_linear, repeat_disable;

// --- les lueurs ------------------------------------------------------------

uniform int lueurs_n : hint_range(0, 4) = 3;
uniform float lueurs_intensite : hint_range(0.0, 1.5) = 0.42;

/// Taille de la première lueur, en demi-hauteurs. Les suivantes sont plus
/// grandes et plus faibles.
uniform float lueurs_echelle : hint_range(0.1, 4.0) = 1.25;

/// **De combien les lueurs glissent VERS l'éblouisseur**, en demi-hauteurs.
/// C'est l'une des deux poignées de l'inclinaison. À zéro, elles restent
/// centrées et ne disent plus rien de personne.
uniform float lueurs_derive : hint_range(0.0, 1.5) = 0.34;

/// Amplitude de leur respiration, en fraction de leur taille.
uniform float lueurs_souffle : hint_range(0.0, 0.6) = 0.14;

// --- les flares ------------------------------------------------------------

uniform int flares_n : hint_range(0, 8) = 5;
uniform float flares_intensite : hint_range(0.0, 1.5) = 0.38;

/// Longueur d'une traînée, en demi-hauteurs — bien au-delà de l'écran : une
/// traînée qui s'arrête dans le cadre a un BOUT, donc une forme.
uniform float flares_longueur : hint_range(0.2, 6.0) = 2.6;
uniform float flares_largeur : hint_range(0.02, 1.0) = 0.20;

/// **De combien les traînées du côté de l'éblouisseur s'allongent.** Seconde
/// poignée de l'inclinaison : `1 + penche · cos(θ − relèvement)`.
uniform float flares_penche : hint_range(0.0, 1.0) = 0.55;

/// **LE TREMBLEMENT — l'amplitude, en radians, dont toute la gerbe vacille.**
///
/// ⚠️ **Ceci a d'abord été une ROTATION CONTINUE, et c'était le mauvais geste.**
/// « La rotation continue de l'effet d'éblouissement, je ne suis pas sûr […] on
/// remplace le mouvement de rotation continue par un léger wiggle, comme si la
/// torche de celui qui nous éblouit n'est pas stable » (Adrien, 2026-08-27).
///
/// Une rosette qui tourne n'a aucune cause dans le monde : rien ne tourne, ni la
/// lampe, ni la tête. Elle se lit comme un effet de moteur. **Un vacillement, si :
/// c'est une main qui tient une torche.** Le mouvement est du même ordre de
/// grandeur, il coûte le même prix, et il raconte quelque chose au lieu de ne
/// rien raconter.
///
/// Il fait vaciller le RELÈVEMENT, donc tout ce qui en dépend d'un bloc — les
/// lueurs, les flares, l'axe des fantômes. Faire trembler chaque couche
/// séparément aurait donné trois choses qui bougent, pas une lampe qui tremble.
uniform float tremble_ampl : hint_range(0.0, 0.6) = 0.085;

/// Les deux fréquences du tremblement, en hertz. Deux et pas une, et le rapport
/// est volontairement bancal : une sinusoïde seule est un balancier, et un
/// balancier s'anticipe en trois secondes. Même raison que
/// `Brouillage.DERIVE_HZ_LENTE` / `_RAPIDE`.
uniform float tremble_hz_a : hint_range(0.0, 4.0) = 0.41;
uniform float tremble_hz_b : hint_range(0.0, 8.0) = 1.13;

/// Amplitude du scintillement de chaque traînée.
uniform float flares_scintille : hint_range(0.0, 1.0) = 0.32;

// --- les fantômes ----------------------------------------------------------

/// Un fantôme d'objectif : le disque a iris, avec son liseré.
uniform sampler2D fantome_tex : hint_default_black, filter_linear, repeat_disable;

/// « Il faudrait vraiment une texture qui fasse réel par-dessus tout, avec des
/// fantômes, qui augmentent le réalisme » (Adrien, 2026-08-27).
///
/// Ce sont eux qui font qu'une image se lit comme une PHOTO plutôt que comme un
/// effet : un œil n'a pas de fantômes, un objectif en a, et c'est justement
/// l'objectif qu'on demande au joueur de croire — « notre vue, notre UI, c'est
/// entièrement une caméra éblouie ».
uniform int fantomes_n : hint_range(0, 6) = 4;
uniform float fantomes_intensite : hint_range(0.0, 1.5) = 0.24;

/// Écart entre deux fantômes le long de l'axe, en demi-hauteurs.
uniform float fantomes_ecart : hint_range(0.05, 1.5) = 0.42;
uniform float fantomes_taille : hint_range(0.02, 1.0) = 0.22;

/// ⚠️ **`−1` = du côté OPPOSÉ à l'éblouisseur, `+1` = de son côté.**
///
/// L'optique dit `−1` : dans un vrai flare, les fantômes tombent de l'autre côté
/// du centre par rapport à la source, parce qu'ils sont les reflets internes de
/// l'objectif. C'est ce que veut « augmenter le réalisme ».
///
/// **Le prix, et il faut le connaître avant de juger :** ça se lit à l'envers
/// pour qui l'ignore — « le flare est à gauche, donc il est à gauche » devient
/// faux. Le voile ne ment pas pour autant : les LUEURS et les FLARES, eux,
/// penchent du bon côté et sont beaucoup plus lisibles. Les fantômes ne portent
/// pas la direction, ils portent la matière.
uniform float fantomes_cote : hint_range(-1.0, 1.0) = -1.0;

// --- le grain --------------------------------------------------------------

/// ⚠️ **Ce grain valait 0,35 sur un bruit de valeur à basse fréquence, et
/// Adrien l'a vu comme « un gros paquet pixellisé dans les sombres ».** Il
/// l'était : des blobs de seize pixels, appliqués le plus fort là où l'image est
/// sombre — c'est-à-dire exactement là où l'œil les isole.
///
/// Le grain d'une photo est **par pixel**, pas par blob, et il est **faible**.
/// Il est ici multiplicatif et proportionnel à ce qui est déjà peint : il
/// n'existe pas là où le voile n'existe pas.
uniform float grain_force : hint_range(0.0, 0.5) = 0.055;

/// Rafraîchissements du grain par seconde. 12 : le grain d'une pellicule, pas
/// le scintillement d'un écran cassé. À 60 il papillote.
uniform float grain_hz : hint_range(0.0, 60.0) = 12.0;

const float PI_ = 3.14159265359;
const float TAU_ = 6.28318530718;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


void fragment() {
	// Coordonnées centrées, en fractions de la DEMI-HAUTEUR. L'aspect est
	// corrigé ici, une fois, pour que tout ce qui suit raisonne en unités rondes.
	vec2 d = (UV - vec2(0.5)) * vec2(aspect, 1.0) * 2.0;

	// ⚠️ **LE TREMBLEMENT S'APPLIQUE AU RELÈVEMENT, UNE SEULE FOIS.** Tout ce qui
	// suit en dépend — les lueurs, les flares, l'axe des fantômes —, et c'est ce
	// qui fait qu'on lit UNE lampe qui vacille et non trois couches qui bougent
	// chacune dans son coin. Faire trembler chaque couche séparément aurait coûté
	// le même prix pour un résultat qui ne raconte rien.
	float rel = relevement + tremble_ampl
		* (0.62 * sin(temps * TAU_ * tremble_hz_a)
			+ 0.38 * sin(temps * TAU_ * tremble_hz_b + 1.7));
	vec2 vers = vec2(cos(rel), sin(rel));

	if (mode == 0) {
		// Le témoin : l'aplat d'aujourd'hui, sans grain et sans rien. C'est la
		// touche qui permet de répondre « non », et elle doit rester pure.
		COLOR = vec4(teinte, clamp(niveau, 0.0, 1.0) * plancher);
	} else {
		// ── LE LAVIS. Il couvre TOUT l'écran et ne descend jamais sous
		// `plancher` — c'est ce qui fait un aveuglement et non une tache.
		float creux = pow(clamp(1.0 - length(d) / max(largeur, 1e-3), 0.0, 1.0),
			max(courbe, 0.01));
		float a = mix(plancher, cime, creux);

		// ── LES LUEURS. Une seule texture, lue à trois échelles, décalées vers
		// l'éblouisseur et respirant chacune à son rythme.
		float ajout = 0.0;
		for (int i = 0; i < 4; i++) {
			if (i >= lueurs_n) { break; }
			float fi = float(i) + 1.0;
			float ech = lueurs_echelle * (0.75 + 0.55 * fi)
				* (1.0 + lueurs_souffle * sin(temps * (0.31 + 0.17 * fi) + fi * 2.1));
			// Le glissement vers l'éblouisseur, plus une errance lente : sans
			// elle les trois lueurs restent empilées et ne font qu'une.
			vec2 centre = vers * (lueurs_derive * (0.45 + 0.35 * fi))
				+ vec2(sin(temps * 0.13 * fi + fi), cos(temps * 0.11 * fi + fi * 2.3)) * 0.09;
			vec2 uv = (d - centre) / max(ech, 1e-3) * 0.5 + vec2(0.5);
			ajout += texture(lueur_tex, uv).r * lueurs_intensite / fi;
		}

		// ── LES FLARES. La même traînée, tournée, et plus longue du côté de
		// l'éblouisseur.
		for (int i = 0; i < 8; i++) {
			if (i >= flares_n) { break; }
			float fi = float(i);
			// Réparties sur un demi-tour, pas un tour : une traînée est
			// symétrique, elle sort des deux côtés du centre.
			// Les traînées sont solidaires du relèvement : c'est ainsi qu'elles
			// vacillent AVEC lui. Le petit déphasage par traînée empêche la
			// rosette de bouger comme un bloc rigide — une main qui tremble ne
			// déplace pas une figure, elle la déforme.
			float ang = rel + PI_ * fi / float(max(flares_n, 1))
				+ tremble_ampl * 0.5 * sin(temps * (0.7 + 0.23 * fi) + fi * 1.9);
			float co = cos(-ang);
			float si = sin(-ang);
			vec2 q = vec2(d.x * co - d.y * si, d.x * si + d.y * co);
			// L'inclinaison : `cos` de l'écart d'angle. Le `abs` est nécessaire
			// parce qu'une traînée n'a pas de sens — celle qui pointe vers
			// l'éblouisseur pointe aussi à l'opposé, et les deux doivent
			// s'allonger ensemble, sinon la rosette se déchire.
			float pente = 1.0 + flares_penche * abs(cos(ang - rel));
			vec2 uv = vec2(q.x / max(flares_longueur * pente, 1e-3),
				q.y / max(flares_largeur, 1e-3)) * 0.5 + vec2(0.5);
			float sc = 1.0 + flares_scintille * sin(temps * (1.7 + 0.53 * fi) + fi * 2.7);
			ajout += texture(flare_tex, uv).r * flares_intensite * sc;
		}

		// ── LES FANTÔMES. Alignés sur l'axe du relèvement, du côté que dit
		// `fantomes_cote`. Ils ne portent pas la direction — les lueurs et les
		// flares s'en chargent, et bien mieux — ils portent la MATIÈRE.
		for (int i = 0; i < 6; i++) {
			if (i >= fantomes_n) { break; }
			float fi = float(i) + 1.0;
			vec2 centre = vers * (fantomes_ecart * fi * fantomes_cote);
			// Des tailles irrégulières : six disques identiques se lisent comme
			// une règle graduée, donc comme une mesure — et une mesure est un
			// repère de plus à lire.
			float taille = fantomes_taille * (0.55 + 0.5 * abs(sin(fi * 2.31)));
			// ⚠️ **Et une ROTATION propre à chacun.** Sans elle, six hexagones
			// partagent la même orientation : l'œil lit alors un motif répété,
			// c'est-à-dire un dessin. Un objectif empile des éléments qui n'ont
			// aucune raison d'être alignés. Deux multiplications pour ça.
			float ga = fi * 1.13 + rel * 0.25;
			float gc = cos(ga);
			float gs = sin(ga);
			vec2 q = d - centre;
			q = vec2(q.x * gc - q.y * gs, q.x * gs + q.y * gc);
			vec2 uv = q / max(taille, 1e-3) * 0.5 + vec2(0.5);
			// L'intensité tombe vite et irrégulièrement : les fantômes lointains
			// sont des restes, pas des copies.
			ajout += texture(fantome_tex, uv).r * fantomes_intensite
				* (0.45 + 0.55 * abs(sin(fi * 1.77))) / sqrt(fi);
		}

		a += ajout;

		// ── LE GRAIN. Par pixel, faible, et PROPORTIONNEL à ce qui est déjà
		// peint : il n'existe pas là où le voile n'existe pas.
		if (grain_force > 0.001) {
			float pas = floor(temps * max(grain_hz, 0.001));
			float n = hash21(floor(FRAGCOORD.xy) + vec2(pas, pas * 1.7));
			a *= 1.0 + (n - 0.5) * grain_force;
		}

		COLOR = vec4(teinte, clamp(a, 0.0, 1.0) * clamp(niveau, 0.0, 1.0));
	}
}
