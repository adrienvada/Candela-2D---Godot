shader_type canvas_item;
render_mode blend_add;

// Poussière dans le faisceau (V5.5) — Candela 2D
// Particules minuscules, sans lumière propre, révélées par la lumière directe.

uniform float intensite_base : hint_range(0.0, 1.0) = 0.45;
uniform float vitesse_derivation : hint_range(0.0, 2.0) = 0.35;
uniform float taille_grain : hint_range(0.5, 5.0) = 1.2;
uniform vec4 teinte_halogene : source_color = vec4(0.98, 0.91, 0.80, 1.0);
uniform sampler2D texture_particule : hint_default_black, filter_linear, repeat_disable;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * vitesse_derivation;
	
	// Grille de poussières flottantes
	vec2 grid = uv * 30.0 * taille_grain;
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - 0.5;
	
	float h = hash21(id);
	
	// Mouvement brownien lent
	vec2 offset = vec2(
		sin(t * 1.3 + h * 6.28),
		cos(t * 0.9 + h * 6.28)
	) * 0.25;
	
	float d = length(gv - offset);
	// DA5.3 — chaque particule était un cercle analytique parfait.
	// Volet S : perturbation du rayon par hash21 décorrélé pour casser la rondeur.
	// Volet G : texture peinte (particule_poussiere.png) échantillonnée dans la cellule.
	d *= 1.0 + 0.4 * (hash21(id * 7.0) - 0.5);

	vec2 part_uv = (gv - offset) / 0.36 + vec2(0.5);
	float tex_alpha = 0.0;
	if (part_uv.x >= 0.0 && part_uv.x <= 1.0 && part_uv.y >= 0.0 && part_uv.y <= 1.0) {
		tex_alpha = texture(texture_particule, part_uv).a;
	}

	// Particule douce : texture peinte si présente (volet G), sinon repli cassé (volet S)
	float spark = (tex_alpha > 0.0) ? tex_alpha : smoothstep(0.18, 0.0, d);
	
	// Scintillement d'interférence
	float flicker = sin(t * 2.5 + h * 12.56) * 0.5 + 0.5;
	spark *= mix(0.4, 1.0, flicker);
	
	COLOR = teinte_halogene * spark * intensite_base;
}
