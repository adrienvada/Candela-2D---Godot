shader_type canvas_item;
render_mode unshaded;

// Les fantômes de killcam en APLAT — refonte roman graphique, lot 6 (2026-09-10).
// Même retrait que `player_rim_light.gdshader` : le bord quatre fois plus
// clair que le centre (0,1 → 4,0) faisait un anneau ; le sprite peint se
// suffit. L'alpha (0,5, posé par `game_state._setup_ghosts`) ne bouge pas.
void fragment() {
	COLOR = vec4(COLOR.rgb, COLOR.a);
}
