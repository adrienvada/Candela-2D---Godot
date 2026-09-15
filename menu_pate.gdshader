shader_type canvas_item;

// La pâte d'interface — chantier Habillage iso (2026-09-15).
//
// Pose un grain de lavis sur ce qu'un Control dessine LUI-MÊME : sa StyleBox,
// ou son _draw pour les panneaux du HUD. Le matériau d'un Control ne peint pas
// ses enfants (piège de la vague M) : le texte, les icônes et les jauges posés
// dans le panneau restent nets, seule la plaque prend la matière.
//
// En espace LOCAL (VERTEX) et non en UV : une StyleBoxFlat n'a pas d'UV utiles,
// et un grain tiré de l'UV s'étirerait avec la taille du panneau. En pixels
// locaux, une tuile garde sa taille quel que soit le cadre.
//
// Le grain est AJOUTÉ, pas multiplié : sur l'encre (0,075), une matière
// multipliée ne se verrait pas. L'alpha n'est jamais touché — la plaque garde
// exactement la transparence que la charte lui donne.
//
// ⚠️ `hint_default_white` : sans texture, `g` vaut 0,5 et le fond s'éclaircit
// uniformément d'une demi-force, sans aucune erreur. C'est le repli muet de
// `hint_default_black` sous une autre couleur ; `tools/test_habillage.gd` exige
// donc que le matériau partagé porte bien sa texture.
uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float echelle = 256.0;
uniform float force = 0.10;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float g = texture(grain, local / echelle).r - 0.5;
	// Chaud : le grain monte vers le papier, pas vers le gris.
	COLOR.rgb = max(COLOR.rgb + g * force * vec3(1.0, 0.9, 0.78), vec3(0.0));
}
