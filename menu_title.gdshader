shader_type canvas_item;

// M11 — Le titre incandescent. Vague M, « la vitrine ».
//
// CANDELA 2D cesse d'être un aplat or : une onde de luminance traverse les
// lettres de gauche à droite, comme des braises sous un courant d'air. Aucun
// glyphe ne bouge — luminance seule.
//
// Le titre est le premier pixel lu à chaque session et après chaque match. Le
// rendre vivant raconte le jeu : une lumière qui brûle tant que ça joue.
//
// ## La phase se prend sur VERTEX.x, jamais sur UV
//
// Sur un `Label`, chaque glyphe est un quad découpé dans un atlas : `UV` couvre
// **la lettre**, pas le bloc. Une onde calculée en UV repartirait de zéro à
// chaque caractère et donnerait un scintillement par lettre — pas une vague.
// `VERTEX` est en espace local du contrôle, donc continu d'un bout à l'autre du
// mot ; il faut seulement lui donner la largeur du bloc, que le shader ne peut
// pas connaître.
//
// ## Tout est multiplicatif
//
// On ne pose jamais une couleur absolue : on multiplie celle qui arrive. C'est
// ce qui laisse M10 éteindre le titre en même temps (son `modulate` est déjà
// dans `COLOR`) sans que les deux effets se battent — la leçon du 2026-08-18.
// L'alpha n'est jamais touché : c'est lui qui porte la forme de la lettre.

uniform float intensite : hint_range(0.0, 1.0) = 1.0;
// Largeur du bloc en pixels locaux, posée au redimensionnement.
uniform float largeur = 600.0;
// 0 = braise presque noire, 1 = plein or. Balayé de gauche à droite.
uniform float embrasement : hint_range(0.0, 1.0) = 1.0;
// Dépassement lumineux qui suit le front d'embrasement.
uniform float depassement : hint_range(0.0, 1.0) = 0.0;
// Amplitude de l'onde continue. Divisée par deux sur une défaite.
uniform float amplitude : hint_range(0.0, 2.0) = 1.0;
// Vers quoi la flambée de victoire tire. Poussée depuis la charte : c'est le
// VERT de la triade d'instrument, tiré vers le blanc pour rester un glacis et
// non un repeint.
uniform vec3 teinte_verdict = vec3(0.827, 1.0, 0.867);
// La température de la crête de l'onde. Poussée elle aussi — c'est l'halogène
// de la charte, normalisé pour teinter sans assombrir.
uniform vec3 teinte_crete = vec3(1.0, 0.929, 0.816);
uniform float flambee : hint_range(0.0, 1.0) = 0.0;

// Période de l'onde continue, en secondes.
const float PERIODE = 5.0;
// Écart de luminance de l'onde, en part de la couleur d'origine.
const float ECART = 0.08;
// Ce qui reste d'une lettre pas encore embrasée.
const float BRAISE = 0.12;
// Largeur du front d'embrasement, en part du bloc.
const float FRONT = 0.35;
// (La crête vit dans `teinte_crete`, poussée par `menu_title.gd`. Elle était
// ici en `const`, donc invisible à la passe de palette, qui ne lisait que les
// `.gd` — c'est le même angle mort que les territoires du fond.)

varying float pos_x;

void vertex() {
	pos_x = VERTEX.x;
}

void fragment() {
	if (intensite <= 0.0) {
		// À zéro, l'aplat or d'avant l'effet, pixel pour pixel.
	} else {
		float phase = clamp(pos_x / max(largeur, 1.0), 0.0, 1.0);

		// L'onde continue : des braises sous un courant d'air.
		float onde = sin((phase * 2.2 - TIME / PERIODE) * 6.2831853);
		float lum = 1.0 + ECART * onde * amplitude * intensite;
		// Plus chaud à la crête, et seulement à la crête.
		lum = max(lum, 0.0);
		vec3 col = COLOR.rgb * lum;
		col = mix(col, col * teinte_crete, max(onde, 0.0) * 0.25 * intensite);

		// L'embrasement balaie de gauche à droite : le C prend feu, « 2D » en
		// dernier. Hors embrasement (valeur 1), le front est passé partout et
		// cette partie ne fait plus rien.
		float front = embrasement * (1.0 + FRONT) - FRONT;
		float allume = 1.0 - smoothstep(front, front + FRONT, phase);
		col = mix(col * BRAISE, col, mix(1.0, allume, intensite));
		// Un dépassement qui suit le front, et qui meurt avec lui.
		col += COLOR.rgb * depassement * intensite
			* exp(-abs(phase - front) * 9.0);

		// Le verdict : la victoire flambe une fois vers le blanc-vert.
		col = mix(col, col * teinte_verdict, flambee * intensite);

		COLOR.rgb = col;
	}
}
