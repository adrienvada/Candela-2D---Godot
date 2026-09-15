// Le sol de la vue isométrique, habillé (ISO7) : la lightmap projetée, passée à la pâte, fois la
// matière du sol.
//
// Successeur de `sol_projete.gdshader` (ISO1), formule pour formule, plus UN facteur : la texture
// de matière `texture_sol`, un niveau de gris dans [0,43 ; 1] accroché aux coordonnées du MONDE.
// **Voie (b) du brief ISO7** (voir ROADMAP, section ISO7) : la lumière reste celle que la vue de
// dessus rend — dalles, joints, décor et lumières 2D compris — et la 3D la multiplie par sa matière.
// Le damier de 35 px, seule référence spatiale du joueur, n'est donc jamais redessiné ici : il vient
// de la lightmap, et la texture ne porte AUCUN joint (demandé à ISO Assets, 2026-09-15).
//
// ⚠️ `unshaded`, et ce n'est pas une facilité : un sol Lambert éteint le cône d'une torche rasante
// (piège du 2026-09-13). Il n'y a rien à éclairer ici — la lumière EST la lightmap. Aucune Light3D.
//
// ISO2 : un sol PAR JOUEUR (`Sol1` sur la couche 3D 2, `Sol2` sur la 4), chacun ne voyant que la
// caméra de son joueur ; la lightmap se choisit par cette caméra. La matière, elle, ne lit que le
// monde : identique dans les deux vues.
//
// Défaut : force 0 — le sol d'ISO1 exactement.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform sampler2D texture_sol : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float periode_sol_px = 140.0;
uniform float force_matiere : hint_range(0.0, 1.0) = 0.0;
// ISO7, étape 6 — la teinte chaude de la lumière neutre, luminance gardée (`pate_temperature`).
uniform float temperature : hint_range(0.0, 1.0) = 0.0;

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 px = monde.xz;
	float aa = clamp((fwidth(px.x) + fwidth(px.y)) / 6.0, 0.02, 0.5);
	// Hors de tout branchement : les mipmaps prennent leurs dérivées ici.
	float matiere = mix(1.0, texture(texture_sol, px / periode_sol_px).r, force_matiere);
	vec3 c = lightmap_pateuse(px, px, aa, deux);
	// Sur la valeur AFFICHÉE (`pate_facteur`) : posée dans l'espace du shader, une matière de 0,5 se voyait
	// comme ~0,2 (mesuré au banc, 2026-09-15).
	c = pate_facteur(c, matiere);
	c = pate_temperature(c, temperature);
	ALBEDO = c;
}
