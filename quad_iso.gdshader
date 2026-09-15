// Un quad posé au sol de la vue iso (ISO4, `MiroirsIso`) : le viseur et la ligne de visée.
//
// ⚠️ **En valeurs affichées, comme les corps iso** : sous `gl_compatibility`, le spatial ne convertit pas,
// et le sprite 2D qu'il remplace est dessiné non éclairé, à sa couleur. La texture est donc lue sans
// `source_color` et la couleur posée telle quelle — une conversion aurait assombri le viseur (ISO2b,
// « la silhouette à la puissance 2,2 »).
//
// Non éclairé, comme le sprite (`LIGHT_MODE_UNSHADED`), et testé en profondeur : un mur 3D le cache
// comme il cache le sol.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D texture_quad : filter_linear, repeat_enable;
uniform bool avec_texture = true;
uniform vec4 couleur = vec4(1.0);
uniform vec2 repetition = vec2(1.0);

void fragment() {
	vec4 t = avec_texture ? texture(texture_quad, UV * repetition) : vec4(1.0);
	ALBEDO = t.rgb * couleur.rgb;
	ALPHA = t.a * couleur.a;
}
