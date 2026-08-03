shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float rim = smoothstep(0.42, 0.48, d);
	float boost = mix(0.1, 4.0, rim); // Slightly brighter center so they are visible
	COLOR = vec4(COLOR.rgb * boost, COLOR.a);
}
