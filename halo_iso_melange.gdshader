// ISO10, 1c (2026-09-15) — une LUEUR de la vue iso en MÉLANGE : la lueur au sol de la fusée posée. Additive, son rouge
// s'ajoutait au sol déjà rougi par la même lumière et saturait vers le rose puis le blanc ; en mélange, elle tend vers
// sa couleur sans jamais la dépasser. La lumière 2D (rayon, énergie) ne bouge pas : seule cette image change.
// Le corps : `halo_iso.gdshaderinc`.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://halo_iso.gdshaderinc"
