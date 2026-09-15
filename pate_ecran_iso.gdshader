// ISO12, lot 0 — la pâte (b) en VUE UNIQUE : la pâte appliquée à l'image entière de la vue iso, après la lumière 3D.
//
// Variante demandée au plan-delta (session cloud, 22:15) : les paliers de la pâte rangent la luminance TOTALE, ce que
// `light()` ne permet pas (appelée lumière par lumière). Ici, les matériaux rendent la lumière continue (`variante_pate` 1)
// et cette passe range l'image en paliers. En vue unique la 3D est rendue par la fenêtre : la passe lit donc l'écran.
// ⚠️ Déclarer `hint_screen_texture` fait COPIER l'écran à chaque image (piège ISO10) : c'est le coût de cette variante, et
// il se mesure au banc. En écran scindé, `pate_vue_iso.gdshader` lit la texture des vues, sans copie.
// Invariant de la pâte : 0 reste 0 (voir `iso_pate.gdshaderinc`).
shader_type canvas_item;

#include "res://iso_pate.gdshaderinc"

uniform sampler2D ecran : hint_screen_texture, filter_linear;

void fragment() {
	vec3 c = textureLod(ecran, SCREEN_UV, 0.0).rgb;
	float l = pate_luminance(c);
	if (style != PATE_BRUTE && l > 0.0) {
		c = pate(c, l, style, FRAGCOORD.xy, vec2(0.0), l, 0.25);
	}
	COLOR = vec4(c, 1.0);
}
