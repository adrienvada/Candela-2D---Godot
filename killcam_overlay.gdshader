shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;
// V6.1 — tension de la bande, 0 au repos et 1 au plus fort du ralenti.
//
// Les trois défauts d'image montent ENSEMBLE : grain, aberration chromatique et
// balayage. C'est ce qui fait lire « la bande souffre » plutôt que « le grain a
// augmenté » — un seul des trois donnerait un réglage, les trois donnent un
// état. À zéro, l'image est exactement celle d'avant l'ajout de cet uniforme.
uniform float tension = 0.0;
// V6.5 — inversion vidéo au moment fatal. 0 = image normale, 1 = négatif plein.
//
// Deux images, pas plus : c'est un clignement, pas un effet. Au-delà on cesse de
// lire « quelque chose vient de casser » pour lire « le rendu est cassé ».
uniform float negatif = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float scanline = sin(uv.y * 800.0) * (0.04 + tension * 0.05);
	float noise = fract(sin(dot(uv + time, vec2(12.9898, 78.233))) * 43758.5453);
	float ecart = 0.003 + tension * 0.006;
	float r = texture(screen_texture, uv + vec2(ecart, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(ecart, 0.0)).b;
	vec3 col = vec3(r, g, b) + noise * (0.05 + tension * 0.10) - scanline;
	col *= smoothstep(0.8, 0.2, distance(uv, vec2(0.5)) * 1.2);
	// Le négatif s'applique APRÈS la vignette : inverser avant rendrait les bords
	// sombres éclatants, et le cadrage de l'image partirait avec.
	col = mix(col, vec3(1.0) - col, clamp(negatif, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
