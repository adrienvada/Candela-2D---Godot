shader_type canvas_item;

// Le voile d'éblouissement PLEIN — celui qui lit l'écran pour son aberration chromatique (DA5.5).
// Son corps, ses réglages et leur histoire vivent dans `voile_eblouissement.gdshaderinc` ;
// `voile_eblouissement_calme.gdshader` est le même voile sans lecture d'écran (ISO10, 1a).
#define VOILE_LIT_L_ECRAN
#include "res://voile_eblouissement.gdshaderinc"
