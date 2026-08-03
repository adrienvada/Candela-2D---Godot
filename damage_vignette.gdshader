shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float intensity = 0.0;
uniform float smoothness = 0.8;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.5 - smoothness * 0.5, 0.5 + smoothness * 0.5, d);
	COLOR = vignette_color;
	COLOR.a = v * intensity;
}
