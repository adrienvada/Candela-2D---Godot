// Une LUEUR de la vue iso, ADDITIVE : la comète, les points de la nappe de braises, la lentille de la torche fantôme,
// l'éclat de bouche, l'éclair de la mine. Le corps et son histoire : `halo_iso.gdshaderinc` ; la variante en mélange
// (la lueur au sol de la fusée) : `halo_iso_melange.gdshader`.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://halo_iso.gdshaderinc"
