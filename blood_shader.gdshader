shader_type canvas_item;

// Sang MAT — refonte roman graphique, lot 2 (2026-09-10).
//
// La version d'origine ajoutait une réflexion spéculaire « liquide et
// brillante » (smoothstep(0.3, 1.5, intensité) × 2,5, multipliée par la
// couleur du sang pour ne jamais blanchir). C'est le vocabulaire de la photo :
// une flaque qui accroche la torche. Un sang de bande dessinée est un APLAT
// carmin cerné d'un cœur noir, et il reste mat sous n'importe quelle lumière.
//
// Le cœur noir n'était pas produit par ce shader mais par la seconde texture
// (`sang_N_coeur.png`, voir `blood_stain.gd`) : il survit intact au retrait de
// la spéculaire. Ce qui reste ici est la diffusion pure — la couleur de la
// tache, éclairée par ce qui l'éclaire, et rien de plus.

void fragment() {
	// La couleur posée par _draw() est conservée telle quelle.
}

void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb, LIGHT_COLOR.a);
}
