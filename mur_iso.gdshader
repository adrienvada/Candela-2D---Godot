// Les murs de la vue isométrique (ISO1) : sommet noir strict, faces allumées par la
// lightmap lue AU PIED du mur.
//
// Une face verticale prend la lumière du sol à `pied` pixels devant elle — pas zéro :
// la case du mur est noire dans la lightmap et son liseré d'encre en occupe le bord
// (occluders rentrés de 3 px, `MapGeometry.OCCLUDER_INSET`). C'est ce qui rend la face
// SYMÉTRIQUE entre les deux joueurs : elle s'allume si et seulement si le sol à son
// pied s'allume, là où une vraie lumière 3D ne dessinerait que chez le joueur côté
// caméra (étude ISO0, § 5.2). Hors du rectangle couvert par la vue 2D, du noir.
//
// `unshaded`, aucune Light3D.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform float pied = 8.0;

varying vec3 monde;
varying vec3 normale;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Boîtes alignées sur les axes : l'échelle non uniforme ne tourne pas une normale
	// d'axe, la normaliser suffit.
	normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 n = normale.xz;
	float longueur = length(n);
	n = longueur > 0.0001 ? n / longueur : vec2(0.0, 1.0);
	// Le motif court le long de la face et en hauteur : une hachure de mur se lit
	// debout, pas couchée.
	vec2 motif = vec2(dot(monde.xz, vec2(-n.y, n.x)), -monde.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	vec3 c = lightmap_pateuse(monde.xz + n * pied, motif, aa);
	// Sommet (et dessous) : noir strict.
	ALBEDO = abs(normale.y) < 0.5 ? c : vec3(0.0);
}
