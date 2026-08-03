shader_type canvas_item;

void light() {
	float light_val = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), LIGHT_COLOR.b);
	if (light_val > 0.001) {
		// Boost incoming light slightly so the enemy is uniformly gray anywhere in the torch cone,
		// but clamp to COLOR.rgb so it NEVER overexposes to white!
		vec3 lit = COLOR.rgb * (light_val * 4.0);
		LIGHT = vec4(min(lit, COLOR.rgb), LIGHT_COLOR.a);
	} else {
		LIGHT = vec4(0.0); // Pitch black in shadow / unlit
	}
}
