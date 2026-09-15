shader_type canvas_item;

// ISO10, 1a (2026-09-15) — le voile d'éblouissement CALME : le même voile, sans lecture d'écran ni
// aberration. `ui.gd` le pose tant que l'éblouissement reste sous `aberration_debut` — la rétrodiffusion de
// sa propre torche suffit à l'y tenir en permanence — et éteint alors la copie plein cadre (`_voile_bb`).
//
// ⚠️ **Un seul shader avec un `if` n'aurait rien éteint** : Godot copie l'écran pour tout objet dont le
// shader DÉCLARE `hint_screen_texture`, qu'il la lise ou non à cette image. D'où deux shaders, un corps.
#include "res://voile_eblouissement.gdshaderinc"
