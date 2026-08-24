shader_type canvas_item;
render_mode blend_mix, unshaded;

// M14 — Le verre fumé. Vague M, « la vitrine ».
//
// Le panneau de droite et les rangées de réglage cessent d'être des aplats
// peints : un filet lumineux le long du bord haut, une luisance qui retombe au
// tiers de la hauteur, une strie spéculaire qui dérive lentement. Au focus, une
// lueur interne prend l'arête — le verre qui accroche la torche du curseur.
//
// C'est diégétique autant que décoratif : les surfaces deviennent des vitres que
// le noir traverse — les mêmes vitres derrière lesquelles passe quelqu'un, au
// rang 4. Le menu se met à coûter cher à l'œil parce que la MATIÈRE a changé,
// pas parce qu'on a ajouté de la décoration.
//
// ## Le matériau ne descend pas dans les enfants
//
// Posé sur un `PanelContainer`, il ne peint que le dessin propre du conteneur —
// sa `StyleBox`. Les enfants ont leur propre matériau, ou aucun : **le texte
// reste net**. C'est ce qui rend l'effet gratuit en lisibilité.
//
// ## La position vient de VERTEX, pas de UV
//
// Une `StyleBoxFlat` à coins arrondis n'est pas un quad : Godot la découpe, et
// `UV` n'y couvre pas proprement le rectangle. `VERTEX` est en espace local du
// contrôle quelle que soit la découpe — même piège, même parade que sur le
// `Label` du titre (M11).

uniform float intensite : hint_range(0.0, 1.0) = 1.0;
uniform vec2 taille = vec2(400.0, 200.0);
// 1 quand la rangée porte le focus. La lueur interne ne vit que là.
uniform float focus : hint_range(0.0, 1.0) = 0.0;
// Défaut de secours seulement : `menu_glass.vitrer()` pousse toujours la vraie
// teinte, prise sur la charte. Il portait l'ancien cyan d'arcade — un défaut
// périmé se lit comme une intention.
uniform vec4 teinte_focus : source_color = vec4(0.29, 0.72, 0.97, 1.0);
// Second étage : la brume qu'on voit à travers la vitre est DÉFOCALISÉE. À zéro,
// le verre est un simple aplat teinté et rien n'est relu à l'écran.
uniform float flou : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// Filet du bord haut : un pixel de lumière, comme l'arête d'une vitre.
const float FILET = 1.5;
const float FILET_ALPHA = 0.05;
// Luisance verticale, éteinte au tiers de la hauteur.
const float LUISANCE = 0.03;
const float LUISANCE_FIN = 0.30;
// Strie spéculaire : inclinaison, largeur, éclat, et sa dérive.
const float PENTE = 0.209;
const float STRIE_LARGEUR = 90.0;
const float STRIE_ALPHA = 0.02;
const float DERIVE = 20.0;
const float DERIVE_PERIODE = 12.0;
// Lueur interne au focus : six pixels depuis l'arête.
const float LUEUR = 6.0;
const float LUEUR_ALPHA = 0.10;
// Rayon du flou, en fraction d'écran. Volontairement petit : on défocalise une
// brume, pas une image — un rayon large la transformerait en aplat gris.
const float FLOU_RAYON = 0.006;
// Part de la couleur du panneau remplacée par la brume défocalisée.
const float FLOU_PART = 0.45;

varying vec2 pos;

void vertex() {
	pos = VERTEX;
}

// Gaussienne à neuf prises, séparée en croix plutôt qu'en carré : neuf lectures
// au lieu de quatre-vingt-une pour un résultat que l'œil ne distingue pas à ce
// rayon. C'est ce qui garde l'étage payable — mesuré, pas supposé.
vec3 brume_defocalisee(vec2 uv) {
	vec3 acc = texture(screen_texture, uv).rgb * 0.24;
	acc += texture(screen_texture, uv + vec2(FLOU_RAYON, 0.0)).rgb * 0.15;
	acc += texture(screen_texture, uv - vec2(FLOU_RAYON, 0.0)).rgb * 0.15;
	acc += texture(screen_texture, uv + vec2(0.0, FLOU_RAYON)).rgb * 0.15;
	acc += texture(screen_texture, uv - vec2(0.0, FLOU_RAYON)).rgb * 0.15;
	acc += texture(screen_texture, uv + vec2(FLOU_RAYON, FLOU_RAYON) * 0.7).rgb * 0.04;
	acc += texture(screen_texture, uv - vec2(FLOU_RAYON, FLOU_RAYON) * 0.7).rgb * 0.04;
	acc += texture(screen_texture, uv + vec2(FLOU_RAYON, -FLOU_RAYON) * 0.7).rgb * 0.04;
	acc += texture(screen_texture, uv - vec2(FLOU_RAYON, -FLOU_RAYON) * 0.7).rgb * 0.04;
	return acc;
}

void fragment() {
	if (intensite > 0.0) {
		vec2 dim = max(taille, vec2(1.0));

		// Le filet du bord haut.
		float filet = (1.0 - smoothstep(0.0, FILET, pos.y)) * FILET_ALPHA;

		// La luisance : la lumière entre par le haut et meurt vite.
		float luisance = (1.0 - smoothstep(0.0, LUISANCE_FIN * dim.y, pos.y)) * LUISANCE;

		// La strie, qui dérive au lieu de balayer : une vitre ne défile pas, elle
		// bouge à peine quand la source se déplace derrière.
		float axe = pos.x * cos(PENTE) + pos.y * sin(PENTE);
		float centre = dim.x * 0.35 + DERIVE * sin(TIME * (6.2831853 / DERIVE_PERIODE));
		float strie = max(0.0, 1.0 - abs(axe - centre) / STRIE_LARGEUR);
		strie = strie * strie * STRIE_ALPHA;

		// La brume défocalisée passe SOUS le filet et la luisance : c'est ce qu'on
		// voit à travers la vitre, pas ce qui brille dessus. Densifiée plutôt que
		// simplement floutée — un panneau qui flotte DANS le brouillard, et non
		// devant lui.
		if (flou > 0.0) {
			vec3 fond = brume_defocalisee(SCREEN_UV) * 1.6;
			COLOR.rgb = mix(COLOR.rgb, fond, FLOU_PART * flou * intensite);
		}

		COLOR.rgb += vec3(filet + luisance + strie) * intensite;

		// La lueur interne : l'arête du verre accroche la torche du curseur.
		if (focus > 0.0) {
			float bord = min(min(pos.x, dim.x - pos.x), min(pos.y, dim.y - pos.y));
			float lueur = 1.0 - smoothstep(0.0, LUEUR, bord);
			COLOR.rgb += teinte_focus.rgb * lueur * LUEUR_ALPHA * focus * intensite;
		}
	}
}
