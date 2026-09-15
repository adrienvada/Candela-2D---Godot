// Un quad additif posé au sol de la vue iso (ISO4, `MiroirsIso`) : la traçante et l'aura de la balle.
//
// Le miroir de `Bullet._additive_material()` : non éclairé, en addition. Mêmes règles que
// `quad_iso.gdshader` — valeurs affichées, profondeur testée.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D texture_quad : filter_linear, repeat_enable;
uniform bool avec_texture = true;
uniform vec4 couleur = vec4(1.0);
uniform vec2 repetition = vec2(1.0);

void fragment() {
	vec4 t = avec_texture ? texture(texture_quad, UV * repetition) : vec4(1.0);
	ALBEDO = t.rgb * couleur.rgb;
	ALPHA = t.a * couleur.a;
}
