shader_type canvas_item;
render_mode unshaded;

// V5.9 — Streaks de sprint : traits de vitesse radiaux, confinés aux bords de
// la vue du sprinteur et filant vers l'extérieur. Le rect porteur a le
// visibility_layer du joueur : chacun ne voit que sa propre vitesse — aucune
// information pour l'adversaire. intensity 0 = strictement invisible.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hachage(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float a = atan(c.y, c.x);

	// 18 secteurs angulaires ; un trait fin au centre de chacun, décalé d'un
	// bruit par secteur pour casser la régularité de roue de vélo.
	float pos_secteur = (a / 6.28318 + 0.5) * 18.0;
	float secteur = floor(pos_secteur);
	float t = fract(pos_secteur + hachage(secteur) * 0.4);
	float trait = 1.0 - smoothstep(0.02, 0.07, abs(t - 0.5));

	// Pointillé radial qui file vers l'extérieur — c'est lui qui vend la
	// vitesse, pas la présence des traits.
	float fuite = step(0.55, fract(r * 2.5 - TIME * 3.0 + hachage(secteur)));

	// Confinés au bord : le centre de la vue — là où on vise — reste propre.
	float bord = smoothstep(0.70, 1.05, r);

	COLOR = vec4(1.0, 1.0, 1.0, trait * fuite * bord * 0.12 * intensity);
}
