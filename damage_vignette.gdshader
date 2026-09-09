shader_type canvas_item;

// DA5.2 — le rouge de la charte, recopié à la main : un `.gdshader` ne peut
// pas `preload("res://charte.gd")`. C'était vec4(1.0, 0.0, 0.0, 1.0), un rouge
// primaire pur, et le seul appelant (`player.gd`) ne pousse jamais
// `vignette_color` — seule `intensity` l'est. La vignette de dégâts affichait
// donc ce défaut à chaque coup encaissé depuis toujours. Valeur = Charte.ROUGE.
uniform vec4 vignette_color : source_color = vec4(0.95, 0.29, 0.33, 1.0);
uniform float intensity = 0.0;
uniform float smoothness = 0.8;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.5 - smoothness * 0.5, 0.5 + smoothness * 0.5, d);
	COLOR = vignette_color;
	COLOR.a = v * intensity;
}
