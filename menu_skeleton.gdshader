shader_type canvas_item;
render_mode blend_mix, unshaded;

// M13 — Les squelettes de lumière. Vague M, « la vitrine ».
//
// Une bande de lumière douce et inclinée balaie les barres fantômes d'un tableau
// qui attend le réseau — une torche qui fouille des étagères dans le noir.
//
// L'attente réseau est l'endroit où les menus bon marché meurent : un texte gelé
// ou un sablier ne disent rien de ce qui se passe. Ici l'attente est diégétique
// — chercher un classement, c'est promener une lumière dans le noir.
//
// **Le balayage est en phase sur toutes les lignes** : une seule diagonale
// traverse le tableau entier, ce qui n'est possible que parce qu'un seul nœud
// dessine toutes les barres. Un matériau par ligne aurait demandé une phase par
// ligne, donc un uniforme par ligne, donc un jour un uniforme oublié.
//
// La bande n'existe que là où quelque chose est dessiné : elle s'ajoute à la
// couleur de la barre et hérite de son alpha. Une barre déjà fondue dans son
// texte n'accroche donc plus rien, sans qu'on ait à le lui dire.

uniform float intensite : hint_range(0.0, 1.0) = 1.0;
// À zéro, la bande s'arrête et les barres se posent. L'échec n'est pas une
// panne : il ne doit pas continuer à faire semblant de chercher.
uniform float balayage : hint_range(0.0, 1.0) = 1.0;
uniform vec2 taille = vec2(600.0, 300.0);

// Un passage toutes les 1,1 s.
const float PERIODE = 1.1;
// Largeur de la bande, en pixels.
const float LARGEUR = 120.0;
// Ce que la bande ajoute au plus fort.
const float ECLAT = 0.06;
// Inclinaison, en radians (20°).
const float PENTE = 0.349;

void fragment() {
	if (intensite > 0.0 && balayage > 0.0) {
		// Projection sur l'axe de la bande : c'est l'inclinaison qui fait qu'une
		// torche balaie des étagères plutôt qu'un scanner qui passe.
		vec2 p = UV * taille;
		float axe = p.x * cos(PENTE) + p.y * sin(PENTE);
		// La course couvre la diagonale entière, plus une largeur de bande de
		// chaque côté : sinon la bande apparaîtrait et disparaîtrait dans le
		// cadre au lieu d'entrer et de sortir.
		float course = taille.x * cos(PENTE) + taille.y * sin(PENTE) + LARGEUR * 2.0;
		float tete = fract(TIME / PERIODE) * course - LARGEUR;
		float d = abs(axe - tete) / LARGEUR;
		float bande = max(0.0, 1.0 - d);
		// Au carré : un dégradé linéaire donne un bord visible, celui-ci fond.
		COLOR.rgb += vec3(ECLAT * bande * bande * balayage * intensite);
	}
}
