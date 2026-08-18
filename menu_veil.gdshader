shader_type canvas_item;
render_mode blend_mix, unshaded;

// M15 — Le voile d'objectif. Vague M, « la vitrine ».
//
// Une unique passe de finition sur les menus : grain de film, frange chromatique
// dans les coins, vignette optique. Le menu semble filmé en basse lumière par
// une très bonne optique.
//
// C'est le dix pour cent invisible qui sépare une interface plate et propre
// d'une image : le cadre gagne une texture photographique, et le noir devient un
// noir de film au lieu d'un #000 vide.
//
// **Et c'est aussi un correctif.** Le grain dissout le banding des dégradés
// sombres — un artefact réel du 8 bits sous `gl_compatibility`, que la brume de
// M12 révélerait sans lui.
//
// Vocabulaire volontairement distinct de la killcam : ni scanline, ni glitch, ni
// dérive. Du cinéma, pas de la VHS.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensite : hint_range(0.0, 1.0) = 1.0;
// Taille du cadre en pixels : la frange se mesure en pixels, pas en UV.
uniform vec2 taille = vec2(1280.0, 720.0);

// Écart maximal entre R et B, en pixels, atteint pile dans les coins.
const float FRANGE = 1.5;
// Part extérieure du cadre où la frange existe. Au centre, exactement zéro : un
// bel objectif, pas une panne.
const float BORD = 0.88;
// Grain : un pour cent et demi de luminance, renouvelé à chaque image.
const float GRAIN = 0.015;
// Vignette : six pour cent perdus dans les angles, qui respirent sur sept
// secondes.
const float VIGNETTE = 0.06;
const float RESPIRATION = 0.01;
const float PERIODE = 7.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float ratio = taille.x / max(taille.y, 1.0);
	// Distance au centre, ramenée à 1 dans les coins quel que soit le format.
	vec2 vers = (uv - vec2(0.5)) * vec2(ratio, 1.0);
	float d = clamp(length(vers) / (0.5 * length(vec2(ratio, 1.0))), 0.0, 1.0);

	vec3 col;
	float bord = smoothstep(BORD, 1.0, d) * intensite;
	if (bord > 0.0) {
		// La frange s'écarte le long du rayon : c'est ainsi qu'une lentille
		// disperse, et c'est ce qui la distingue d'un décalage horizontal, lequel
		// se lirait comme une panne d'affichage.
		vec2 ecart = normalize(vers + vec2(1e-6)) * bord * FRANGE / taille;
		col = vec3(
			texture(screen_texture, uv + ecart).r,
			texture(screen_texture, uv).g,
			texture(screen_texture, uv - ecart).b);
	} else {
		// Au centre, une seule lecture : les trois seraient identiques.
		col = texture(screen_texture, uv).rgb;
	}

	// Vignette optique, qui respire.
	float creux = VIGNETTE + RESPIRATION * sin(TIME * (6.2831853 / PERIODE));
	col *= 1.0 - creux * d * d * intensite;

	// Grain monochrome, un pixel, renouvelé à chaque image.
	float g = hash12(floor(FRAGCOORD.xy) + vec2(TIME * 60.0, TIME * 97.0));
	col += (g - 0.5) * GRAIN * intensite;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
