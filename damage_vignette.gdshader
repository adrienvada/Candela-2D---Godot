shader_type canvas_item;

// La vignette de dégâts en HACHURES — refonte roman graphique, lot 5 (2026-09-10).
//
// La version d'origine posait un rouge radial doux aux bords de l'écran : de
// l'aérographe. Ici le coup encaissé fait entrer des HACHURES rouges par les
// bords — la même trame à 45° que l'alerte des barres de vie sous 30 PV
// (`MenuHatchRect`, mode alerte), pour que l'écran et le HUD disent la même
// chose avec le même trait. Le bord de la zone hachurée est franc, et il
// recule vers les coins à mesure que `intensity` retombe (0,6 s, courbe
// EXTINCTION, poussée par `player.gd`) ; à zéro, rien.
//
// DA5.2 — le rouge de la charte, recopié à la main : un `.gdshader` ne peut
// pas `preload("res://charte.gd")`. Valeur = Charte.ROUGE ; `player.gd` la
// pousse aussi explicitement.
uniform vec4 vignette_color : source_color = vec4(0.95, 0.29, 0.33, 1.0);
uniform float intensity = 0.0;
uniform float smoothness = 0.8;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5));
	// À pleine intensité (1,5 au coup), la zone commence à 0,36 du centre ;
	// elle recule jusqu'à 0,62 (au-delà des coins) quand l'intensité s'éteint.
	float k = clamp(intensity / 1.5, 0.0, 1.0);
	float bord = mix(0.62, 0.36, k);
	float zone = step(bord, d);
	// Hachures à 45° dans l'espace écran : 10 px de pas, trait de 4 px.
	vec2 px = uv / SCREEN_PIXEL_SIZE;
	float h = step(0.6, fract((px.x + px.y) / 10.0));
	COLOR = vignette_color;
	COLOR.a = vignette_color.a * zone * h * step(0.03, intensity);
}
