shader_type canvas_item;

void fragment() {
	// Keep the original color drawn by _draw
}

void light() {
	// Diffuse (base color darkened by light)
	vec3 diffuse = LIGHT_COLOR.rgb * COLOR.rgb;
	
	// Glossy liquid specular reflection
	float intensity = length(LIGHT_COLOR.rgb);
	
	// Create a sharp, intense reflection curve
	float spec = smoothstep(0.3, 1.5, intensity) * 2.5;
	
	// To prevent it from turning white, we multiply the specular reflection by the blood's own color.
	// This ensures it only reflects bright RED light, even if the incoming light is white.
	// It preserves the black center and the red edges.
	vec3 spec_color = COLOR.rgb * LIGHT_COLOR.rgb * spec;
	
	LIGHT = vec4(diffuse + spec_color, LIGHT_COLOR.a);
}
