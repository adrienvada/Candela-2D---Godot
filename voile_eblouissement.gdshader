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
//     alpha = niveau × [ mélange(plancher, cime, creux)  +  lueurs + flares ]
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
// l'animer d'une façon maline et pas chère » (Adrien). Deux textures suffisent —
// une lueur ronde, une traînée — et tout le reste n'est que des matrices : on
// les échantillonne à des échelles, des angles et des décalages qui dérivent
// lentement. Sept lectures de texture pour toute la gerbe, contre une trentaine
// d'opérations trigonométriques par pixel dans la version précédente.
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
uniform float cime : hint_range(0.0, 1.0) = 0.88;

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

/// Tours par seconde de la rosette entière. Très lent : les traînées doivent
/// RAMPER. Même leçon que `Brouillage.DERIVE_HZ_*` — ce qui tremble vite est
/// intégré par l'œil et cesse d'exister.
uniform float flares_rotation : hint_range(0.0, 0.3) = 0.022;

/// Amplitude du scintillement de chaque traînée.
uniform float flares_scintille : hint_range(0.0, 1.0) = 0.32;

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


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


void fragment() {
	// Coordonnées centrées, en fractions de la DEMI-HAUTEUR. L'aspect est
	// corrigé ici, une fois, pour que tout ce qui suit raisonne en unités rondes.
	vec2 d = (UV - vec2(0.5)) * vec2(aspect, 1.0) * 2.0;
	vec2 vers = vec2(cos(relevement), sin(relevement));

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
			float ang = PI_ * fi / float(max(flares_n, 1))
				+ temps * flares_rotation * PI_ * 2.0;
			float co = cos(-ang);
			float si = sin(-ang);
			vec2 q = vec2(d.x * co - d.y * si, d.x * si + d.y * co);
			// L'inclinaison : `cos` de l'écart d'angle. Le `abs` est nécessaire
			// parce qu'une traînée n'a pas de sens — celle qui pointe vers
			// l'éblouisseur pointe aussi à l'opposé, et les deux doivent
			// s'allonger ensemble, sinon la rosette se déchire.
			float pente = 1.0 + flares_penche * abs(cos(ang - relevement));
			vec2 uv = vec2(q.x / max(flares_longueur * pente, 1e-3),
				q.y / max(flares_largeur, 1e-3)) * 0.5 + vec2(0.5);
			float sc = 1.0 + flares_scintille * sin(temps * (1.7 + 0.53 * fi) + fi * 2.7);
			ajout += texture(flare_tex, uv).r * flares_intensite * sc;
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
