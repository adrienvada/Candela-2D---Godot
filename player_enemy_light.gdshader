shader_type canvas_item;

void light() {
	// ⚠️ × LIGHT_ENERGY : l'intensité d'une lampe est dans son énergie, la forme
	// dans l'alpha de son masque blanc (décision d'Adrien, 2026-09-10). Sans elle,
	// une torche à 0 mais allumée (grésillement) dessinait encore l'adversaire, et
	// la rétrodiffusion révélait son porteur à pleine valeur quel que soit son
	// `backlight_multiplier`. Sous la torche rien ne change : ×4 puis plafond à
	// COLOR, donc saturé dès une énergie de ~0,26.
	float light_val = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), LIGHT_COLOR.b) * LIGHT_ENERGY;
	if (light_val > 0.001) {
		// Boost incoming light slightly so the enemy is uniformly gray anywhere in the torch cone,
		// but clamp to COLOR.rgb so it NEVER overexposes to white!
		vec3 lit = COLOR.rgb * (light_val * 4.0);
		LIGHT = vec4(min(lit, COLOR.rgb), LIGHT_COLOR.a);
	} else {
		LIGHT = vec4(0.0); // Pitch black in shadow / unlit
	}
}
