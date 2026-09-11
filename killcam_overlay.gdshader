shader_type canvas_item;

// La killcam DESSINÉE — refonte roman graphique, lot 4 bis (2026-09-11).
//
// Le premier lot 4 remplaçait le grain vidéo par une trame de demi-teinte ;
// Adrien : « je ne vois pas la différence. Propose un graphisme de killcam
// plus marqué […] que tout soit dessiné. » Le rejeu devient donc une PLANCHE
// DE RECONSTITUTION : l'image est réduite à trois tons, ses contours sont
// tirés à l'encre (un trait clair partout où la lumière change brusquement —
// le bord d'un faisceau, la silhouette d'un corps, l'arête d'un mur), et les
// demi-tons reçoivent une trame de points dont le pas se resserre avec la
// tension du ralenti. Ce n'est plus une bande qui souffre, c'est un dessin
// qui se fait sous les yeux.
//
// Ce qui ne change pas, et pourquoi : les uniforms (`time`, `tension`,
// `negatif`, `grain`, `grain_echelle`) — `ui.gd` les pousse ; le négatif V6.5
// garde ses deux images ; la vignette reste. `intensite` est le curseur
// CONFORT « Grain de la killcam » : à zéro, ni trame, ni contours, ni tons —
// l'image nue du rejeu, et le contrat « à zéro, l'image d'avant » tient.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;
uniform float tension = 0.0;
uniform float negatif = 0.0;
uniform sampler2D grain : filter_linear, repeat_enable;
uniform float grain_echelle = 3.0;
uniform float intensite : hint_range(0.0, 1.0) = 1.0;

// Adrien, le 2026-09-11, sur le rendu : « réduis de moitié l'effet ». Le
// dessin (tons, contours, trame, papier) se mélange à l'image nue à cette
// force au maximum du curseur ; le curseur garde toute sa course en dessous.
const float FORCE_DESSIN = 0.5;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_texture, uv).rgb;
	float lum = luma(col);

	// Les contours : gradient de luminance sur quatre voisins à 1,5 px. Un
	// seuil franc (step) et non un dégradé — un trait de plume a un bord.
	vec2 d = SCREEN_PIXEL_SIZE * 1.5;
	float gx = luma(texture(screen_texture, uv + vec2(d.x, 0.0)).rgb)
		- luma(texture(screen_texture, uv - vec2(d.x, 0.0)).rgb);
	float gy = luma(texture(screen_texture, uv + vec2(0.0, d.y)).rgb)
		- luma(texture(screen_texture, uv - vec2(0.0, d.y)).rgb);
	float contour = step(0.045, length(vec2(gx, gy)));

	// Trois tons : noir, gris, clair. La couleur survit (le carmin du sang
	// reste du carmin), seule sa valeur est quantifiée.
	float tons = floor(lum * 3.0 + 0.5) / 3.0;
	vec3 postere = col * (tons / max(lum, 0.004));

	// La trame de demi-teinte sur le ton du milieu, en quinconce dans
	// l'espace écran ; plus serrée quand la bande ralentit.
	vec2 px = uv / SCREEN_PIXEL_SIZE;
	float pas = mix(7.0, 5.0, clamp(tension, 0.0, 1.0));
	vec2 r = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / pas;
	vec2 c = fract(r) - vec2(0.5);
	float milieu = step(0.2, tons) * step(tons, 0.5);
	float encre = step(length(c), 0.30) * milieu;
	postere = mix(postere, vec3(0.0), encre * 0.55);

	// Le trait, par-dessus : halogène, pas blanc pur.
	vec3 dessin = mix(postere, vec3(0.98, 0.91, 0.80), contour * (0.55 + 0.35 * tension));

	// Le grain de papier : centré sur zéro, faible, immobile.
	float papier = texture(grain, uv * grain_echelle).r - 0.5;
	dessin += papier * 0.05;

	col = mix(col, dessin, intensite * FORCE_DESSIN);
	col *= smoothstep(0.8, 0.2, distance(uv, vec2(0.5)) * 1.2);
	// Le négatif s'applique APRÈS la vignette : inverser avant rendrait les bords
	// sombres éclatants, et le cadrage de l'image partirait avec.
	col = mix(col, vec3(1.0) - col, clamp(negatif, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
