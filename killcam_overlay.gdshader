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

// DA4.5 — **le grain vient d'une texture, plus d'un calcul.**
//
// `fract(sin(dot(...)))` produit un bruit blanc, c'est-à-dire un bruit qui n'a
// aucune structure : chaque pixel est indépendant de son voisin. Une bande vidéo
// usée ne fait pas ça — elle porte de la poussière, des rayures verticales, des
// zones plus fatiguées que d'autres. **Le hasard uniforme ne ressemble à aucune
// matière**, et c'est ce qui donnait à la killcam son air de filtre plutôt que
// d'archive.
//
// La texture est tuilable et échantillonnée en `repeat` : elle défile sur le
// temps, donc le grain bouge sans que le motif se devine.
uniform sampler2D grain : filter_linear, repeat_enable;
// Combien de fois la planche se répète sur la largeur de l'écran. Assez pour que
// la structure se lise, pas au point qu'on reconnaisse le carreau.
uniform float grain_echelle = 3.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float scanline = sin(uv.y * 800.0) * (0.04 + tension * 0.05);
	// Le grain défile en diagonale, à deux vitesses différentes sur les deux axes :
	// un défilement pur vertical se lirait comme un déroulé de bande, ce qui est
	// un autre défaut vidéo — et deux vitesses premières entre elles retardent
	// longtemps le moment où la boucle se répète à l'identique.
	vec2 guv = uv * grain_echelle + vec2(time * 0.11, time * 0.07);
	// Centré sur zéro : la planche est un masque clair, et l'ajouter telle quelle
	// éclaircirait toute l'image au lieu de la grener.
	float noise = texture(grain, guv).r - 0.5;
	float ecart = 0.003 + tension * 0.006;
	float r = texture(screen_texture, uv + vec2(ecart, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(ecart, 0.0)).b;
	// Le facteur double celui du bruit blanc d'avant : une texture centrée sur
	// zéro n'a que la moitié de l'amplitude d'un `fract()` qui va de 0 à 1, et
	// garder l'ancien coefficient aurait fait disparaître le grain sans que
	// personne comprenne pourquoi.
	vec3 col = vec3(r, g, b) + noise * (0.10 + tension * 0.20) - scanline;
	col *= smoothstep(0.8, 0.2, distance(uv, vec2(0.5)) * 1.2);
	// Le négatif s'applique APRÈS la vignette : inverser avant rendrait les bords
	// sombres éclatants, et le cadrage de l'image partirait avec.
	col = mix(col, vec3(1.0) - col, clamp(negatif, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
