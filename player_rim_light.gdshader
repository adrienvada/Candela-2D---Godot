shader_type canvas_item;

// Ressource partagée par les deux joueurs : compilée une fois au chargement,
// jamais pendant une manche.
void light() {
	// UV center is (0.5, 0.5). We calculate distance to center.
	float d = distance(UV, vec2(0.5));
	// Rim is strictly confined to the extreme outer edge
	float rim = smoothstep(0.42, 0.48, d);
	// Center is dark (0.4), edge is brightly illuminated (4.0). This creates a solid 3D effect instead of a hollow ring!
	float boost = mix(0.4, 4.0, rim);
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * boost, LIGHT_COLOR.a);
}
