shader_type canvas_item;

// Flash + aberration chromatique de la mort. Ressource préchargée : compilée au
// démarrage, la première mort ne déclenche plus de compilation à chaud.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float flash_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float aberration_amount = 0.05;

void fragment() {
	float offset = aberration_amount * flash_intensity;
	float r = texture(screen_texture, SCREEN_UV + vec2(offset, 0.0)).r;
	float g = texture(screen_texture, SCREEN_UV).g;
	float b = texture(screen_texture, SCREEN_UV - vec2(offset, 0.0)).b;
	vec3 color = mix(vec3(r, g, b), vec3(1.0), flash_intensity);
	COLOR = vec4(color, 1.0);
}
