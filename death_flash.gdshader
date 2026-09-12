shader_type canvas_item;

// Le flash de mort en PALIERS — refonte roman graphique, lot 3 (2026-09-10).
//
// La version d'origine relisait l'écran pour le blanchir en dégradé avec une
// frange RVB (aberration chromatique) : un objectif de caméra qui sature. Elle
// lisait en outre un tampon d'écran que rien ne lui garantissait — voir
// « Le tampon d'écran n'a pas de propriétaire » dans la ROADMAP, signalé le
// 2026-09-07 et jamais corrigé. Cette version ne lit plus l'écran du tout :
// c'est un lecteur de `hint_screen_texture` en moins.
//
// Ce qu'elle dessine : une case BLANCHE, franche, qui recule en trois paliers
// au lieu de fondre. Le blanc pur est assumé (DA5.2 l'avait examiné et gardé :
// « une surexposition n'a pas de teinte à choisir »). `aberration_amount` est
// conservé pour que les appelants qui le poussent ne cassent pas ; il est sans
// effet.
//
// Ressource préchargée : compilée au démarrage, la première mort ne déclenche
// plus de compilation à chaud.
uniform float flash_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float aberration_amount = 0.05;

void fragment() {
	float a = 0.0;
	if (flash_intensity >= 0.66) {
		a = 1.0;
	} else if (flash_intensity >= 0.33) {
		a = 0.55;
	} else if (flash_intensity >= 0.04) {
		a = 0.22;
	}
	COLOR = vec4(1.0, 1.0, 1.0, a);
}
