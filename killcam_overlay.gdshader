shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float scanline = sin(uv.y * 800.0) * 0.04;
	float noise = fract(sin(dot(uv + time, vec2(12.9898, 78.233))) * 43758.5453);
	float r = texture(screen_texture, uv + vec2(0.003, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(0.003, 0.0)).b;
	vec3 col = vec3(r, g, b) + noise * 0.05 - scanline;
	col *= smoothstep(0.8, 0.2, distance(uv, vec2(0.5)) * 1.2);
	COLOR = vec4(col, 1.0);
}
