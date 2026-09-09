shader_type canvas_item;
render_mode blend_add;

// Poussière dans le faisceau (V5.5) — Candela 2D
// Particules minuscules, sans lumière propre, révélées par la lumière directe.

uniform float intensite_base : hint_range(0.0, 1.0) = 0.45;
uniform float vitesse_derivation : hint_range(0.0, 2.0) = 0.35;
uniform float taille_grain : hint_range(0.5, 5.0) = 1.2;
uniform vec4 teinte_halogene : source_color = vec4(0.98, 0.91, 0.80, 1.0);

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
	// DA5.3 — chaque particule était un cercle analytique parfait. Un second
	// hash (décorrélé de `h`, qui pilote déjà la dérive et le scintillement)
	// casse la rondeur sans changer le coût : une lecture de plus, aucune
	// texture. `id * 7.0` évite que la déformation ne suive le même rythme que
	// le mouvement brownien.
	d *= 1.0 + 0.4 * (hash21(id * 7.0) - 0.5);

	// Particule douce
	float spark = smoothstep(0.18, 0.0, d);
	
	// Scintillement d'interférence
	float flicker = sin(t * 2.5 + h * 12.56) * 0.5 + 0.5;
	spark *= mix(0.4, 1.0, flicker);
	
	COLOR = teinte_halogene * spark * intensite_base;
}
