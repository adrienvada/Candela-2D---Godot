shader_type canvas_item;

// Le FLOU de la zone d'émission — ce qui empêche le cône de trahir son apex.
//
// ## Pourquoi ce shader existe
//
// Effacer la silhouette de l'émetteur ne suffit pas : son faisceau part
// toujours d'un point, et **deux arêtes qui convergent se prolongent à l'œil**.
// On ne voit plus l'homme, on voit où sa lampe commence, et ça suffit pour
// viser. Relevé par Adrien au banc le 2026-08-25, après le premier essai du
// mode « lampe » — et c'était le point que la feuille de route signalait dès
// l'ouverture du chantier sans savoir encore qu'il déciderait de tout.
//
// Le flou attaque la convergence elle-même : brouillées, les deux arêtes ne se
// prolongent plus vers un point mais vers une région.
//
// ## Ce qu'il n'est PAS
//
// Il ne déplace rien et n'invente rien. Il rend illisible une zone qui reste à
// sa place — même règle que tout le reste du chantier : dégrader la lecture est
// un coût de perception, déplacer serait un mensonge.
//
// ## Le seul piège, et il est dans le fondu
//
// Le rayon du noyau **doit tomber à zéro sur le bord du disque**. À rayon
// constant, la bordure du rectangle mélangerait des pixels flous et nets côte à
// côte : on verrait un disque de flou POSÉ sur l'image, c'est-à-dire une forme
// nette de plus — exactement l'inverse du but, et un repère aussi bon que celui
// qu'on efface. Le `smoothstep` ci-dessous fait tendre le pas vers 0 ; au bord,
// les dix-sept prélèvements retombent tous sur le même texel et le shader rend
// l'image d'origine, à l'identique.

uniform sampler2D ecran : hint_screen_texture, repeat_disable, filter_linear;

// Rayon du noyau de flou au centre, en pixels d'écran. Ce n'est PAS la taille
// de la zone : celle-ci est portée par la taille du rectangle, côté GDScript.
uniform float rayon_noyau : hint_range(0.0, 48.0) = 14.0;

// 0 = pas de flou du tout, 1 = plein effet. Suit l'éblouissement.
uniform float force : hint_range(0.0, 1.0) = 1.0;

// **Le trou autour de SOI.** `exclusion_centre` est la position du joueur qui
// subit l'éblouissement, en UV d'écran ; le flou est nul en deçà de
// `exclusion_pres` et plein au-delà de `exclusion_loin`, en pixels d'écran.
//
// « Il ne faut pas que notre propre personnage devienne flou » (Adrien,
// 2026-08-25). La zone floue est poussée vers la victime, donc à distance de
// duel elle atteignait son propre corps. Ce n'est pas qu'une gêne : une
// décision actée veut que l'éblouissement coûte la lecture DU MONDE, jamais
// celle de sa propre fiche.
//
// **Le fondu entre les deux rayons n'est pas un ornement.** Un disque net au
// milieu du flou serait une forme de plus à lire, donc un repère — le défaut
// même que le halo en traînée vient de corriger. À rayon unique, on aurait
// remplacé un cercle par un autre.
uniform vec2 exclusion_centre = vec2(0.5, 0.5);
uniform float exclusion_pres = 44.0;
uniform float exclusion_loin = 104.0;

// Deux anneaux de huit, plus le centre. Huit directions plutôt que quatre :
// à quatre, un contour droit reste droit — le faisceau a précisément deux
// arêtes droites, donc ce sont elles qu'on manquerait.
const vec2 ANNEAU[16] = {
	vec2( 1.000,  0.000), vec2( 0.707,  0.707), vec2( 0.000,  1.000), vec2(-0.707,  0.707),
	vec2(-1.000,  0.000), vec2(-0.707, -0.707), vec2( 0.000, -1.000), vec2( 0.707, -0.707),
	vec2( 0.924,  0.383), vec2( 0.383,  0.924), vec2(-0.383,  0.924), vec2(-0.924,  0.383),
	vec2(-0.924, -0.383), vec2(-0.383, -0.924), vec2( 0.383, -0.924), vec2( 0.924, -0.383)
};

void fragment() {
	// 0 au centre du rectangle, 1 sur le cercle inscrit.
	float d = length(UV - vec2(0.5)) * 2.0;
	if (d >= 1.0) {
		discard;
	}
	// Plein au centre, nul au bord — voir la note sur le fondu plus haut.
	float k = force * (1.0 - smoothstep(0.0, 1.0, d));

	// Puis le trou autour de soi. La distance se mesure en PIXELS et non en UV :
	// un écran n'est pas carré, et une distance en UV rendrait le trou
	// elliptique — donc une forme, une fois de plus.
	vec2 ecart_px = (SCREEN_UV - exclusion_centre) / SCREEN_PIXEL_SIZE;
	k *= smoothstep(exclusion_pres, exclusion_loin, length(ecart_px));

	vec2 pas = rayon_noyau * k * SCREEN_PIXEL_SIZE;

	// ⚠️ **`FRAGCOORD.xy * SCREEN_PIXEL_SIZE` et non `SCREEN_UV`.** Les deux
	// devraient coïncider ; sous ce projet ils ne coïncident pas, et le disque
	// rendait une copie DÉPLACÉE et AGRANDIE de l'écran. Le contrôle qui l'a
	// établi : à rayon de noyau nul, les dix-sept prélèvements tombent sur le
	// même texel, donc le disque doit devenir invisible — il restait visible.
	// Ce n'était donc pas le flou qui était faux, c'était l'adressage.
	vec2 uv = FRAGCOORD.xy * SCREEN_PIXEL_SIZE;

	vec3 somme = texture(ecran, uv).rgb;
	for (int i = 0; i < 8; i++) {
		somme += texture(ecran, uv + ANNEAU[i] * pas).rgb;
	}
	for (int i = 8; i < 16; i++) {
		somme += texture(ecran, uv + ANNEAU[i] * pas * 0.55).rgb;
	}
	// **Aucune correction de gamma ici, et l'absence est le résultat.**
	//
	// La zone a longtemps rendu l'image juste, à la bonne place, et beaucoup
	// trop claire. J'en ai conclu à un sRGB appliqué deux fois et j'ai posé un
	// `pow(c, 2,2)` — qui l'a rendue beaucoup trop SOMBRE. Un balayage de
	// l'exposant contre une référence sans disque n'a rien trouvé qui colle :
	// 1,0 donnait +19 % de luminance, 1,4 en donnait −43 %. **Aucun exposant ne
	// collait parce qu'aucun exposant n'était le problème.**
	//
	// Ce qui l'a dit : la luminance n'était qu'à +19 % pendant que le contraste
	// était à **+226 %**. Un décalage colorimétrique déplace les deux ensemble ;
	// cet excès de VARIANCE seul désignait autre chose — le rectangle lisait un
	// tampon qu'on écrivait dans la même passe de canevas. Le flou déplacé sur
	// sa propre couche, l'exposant 1,0 colle à la référence à **0,000 %** près
	// sur les deux mesures.
	//
	// **La leçon, et elle vaut plus que ce shader : un facteur de correction qui
	// « marche à peu près » est le meilleur moyen de cimenter un défaut
	// ailleurs.** Sans la mesure contre une référence, le 2,2 serait resté —
	// plausible, documenté, et faux.
	COLOR = vec4(somme / 17.0, 1.0);
}
