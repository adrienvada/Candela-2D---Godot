shader_type canvas_item;

// La killcam en TRAME — refonte roman graphique, lot 4 (2026-09-10).
//
// La version d'origine faisait souffrir une bande vidéo : grain de pellicule,
// lignes de balayage, frange RVB, tous asservis à `tension`. C'est un moniteur.
// Ici le rejeu est une PLANCHE IMPRIMÉE : une trame de demi-teinte (points
// d'encre en quinconce, plus gros là où l'image est sombre) recouvre l'image,
// et c'est la trame qui se resserre avec la tension du ralenti — l'encre
// s'épaissit quand la bande ralentit, comme le grain montait avant. Le grain
// devient un grain de PAPIER, faible et fixe (la planche `grain_video.png`
// sert de matière, elle ne défile plus).
//
// Ce qui ne change pas, et pourquoi : les uniforms (`time`, `tension`,
// `negatif`, `grain`, `grain_echelle`) — `ui.gd` les pousse, et le contrat
// « à zéro, l'image est celle d'avant » tient toujours pour `tension`. Le
// négatif V6.5 garde ses deux images : une inversion noir/blanc est déjà le
// geste le plus encre du jeu. La vignette reste, parce qu'un cadre affirme un
// bord.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;
uniform float tension = 0.0;
uniform float negatif = 0.0;
uniform sampler2D grain : filter_linear, repeat_enable;
uniform float grain_echelle = 3.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_texture, uv).rgb;

	// La trame : grille tournée de 45° dans l'ESPACE ÉCRAN (en pixels, pas en
	// UV, sinon les points s'ovalisent avec le rapport d'écran). Le pas se
	// resserre avec la tension ; le rayon du point suit la luminance : plus
	// c'est sombre, plus l'encre couvre.
	vec2 px = uv / SCREEN_PIXEL_SIZE;
	float pas = mix(7.0, 5.0, clamp(tension, 0.0, 1.0));
	vec2 r = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / pas;
	vec2 c = fract(r) - vec2(0.5);
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float rayon = (1.0 - lum) * 0.62;
	float encre = step(length(c), rayon);
	float force = 0.28 + tension * 0.30;
	col = mix(col, vec3(0.0), encre * force);

	// Le grain de papier : centré sur zéro, faible, immobile.
	float papier = texture(grain, uv * grain_echelle).r - 0.5;
	col += papier * 0.05;

	col *= smoothstep(0.8, 0.2, distance(uv, vec2(0.5)) * 1.2);
	// Le négatif s'applique APRÈS la vignette : inverser avant rendrait les bords
	// sombres éclatants, et le cadrage de l'image partirait avec.
	col = mix(col, vec3(1.0) - col, clamp(negatif, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
