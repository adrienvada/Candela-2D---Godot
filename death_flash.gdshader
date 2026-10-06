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
// Chantier RR, RR5 — le flash FONDU (le jeu ; `IsoMateriaux.effets_fondus`, posé par `player.gd`) : la case blanche suit
// l'intensité en continu, le geste d'origine — son extinction est celle que règle `player.gd` (DA4.13, l'`expo out`) —, toujours
// sans relire l'écran. Les paliers n'en étaient que l'arrondi (1 dès 0,66, puis 0,55, puis 0,22, rien sous 0,04). Faux
// (`--sans-fondu`, l'encre) : les trois paliers de la refonte.
uniform bool fondu = false;

void fragment() {
	float a = 0.0;
	if (fondu) {
		a = flash_intensity;
	} else if (flash_intensity >= 0.66) {
		a = 1.0;
	} else if (flash_intensity >= 0.33) {
		a = 0.55;
	} else if (flash_intensity >= 0.04) {
		a = 0.22;
	}
	COLOR = vec4(1.0, 1.0, 1.0, a);
}
