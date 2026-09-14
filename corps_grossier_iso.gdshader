// Les corps GROSSIERS de la vue isométrique (ISO1, ISO2) — les cylindres gris du banc
// ISO0.b, en attendant les corps voxel d'ISO3 (qui auront leur propre shader,
// `corps_iso.gdshader`, à la session iso-corps).
//
// « Gris plafonné, noir hors lumière » — mais depuis ISO2 la lumière est celle que le
// corps REÇOIT, lue dans son capteur (`CapteurCorps`), et non celle du sol sous ses
// pieds. La différence est la règle d'équité du jeu : le halo de proximité révèle un
// ennemi collé en n'éclairant que son sprite, le sol reste noir (constaté au banc
// ISO0.b) — un corps qui lisait le sol disparaissait là où la vue de dessus le montre.
//
// Un capteur par VUE : `capteur_1` est ce que J1 reçoit de ce corps dans SA lightmap
// (masque de lumière du sprite que J1 voit : le sien s'il s'agit de son corps, le sprite
// « ennemi » sinon), `capteur_2` la même chose chez J2. La caméra qui dessine choisit
// (`lightmap_de_j2`) : le corps de J2 vu par J1 s'allume avec la lumière de J1
// seulement. **Noir absolu** : un capteur noir donne un corps à 0/255 — la pâte
// multiplie, elle n'ajoute rien.
//
// ⚠️ **Pour ISO3** : la hauteur d'un corps voxel n'est pas sa hauteur de jeu. Les
// constantes de simulation que le chantier des murs bas pose dans `map_geometry.gd`
// (`HAUTEUR_DEBOUT` 1,00, `HAUTEUR_ACCROUPI` 0,10 tuile) décident de ce qu'une balle ou
// une lumière franchit ; un corps accroupi de 0,10 tuile extrudé tel quel ferait 3,5 px.
// Le rendu iso a ses propres hauteurs (comme `IsoGeometrie.H_HAUT` pour les murs) : un
// corps voxel se dessine lisible, et se lit accroupi à sa silhouette, pas à sa cote.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

uniform sampler2D capteur_1 : source_color, filter_linear, repeat_disable;
uniform sampler2D capteur_2 : source_color, filter_linear, repeat_disable;
uniform vec3 gris : source_color = vec3(0.5);
uniform float seuil_bas = 0.01;
uniform float seuil_haut = 0.08;

// Cinq lectures dans le disque du capteur (centre et quatre points à un quart de sa
// largeur) : la lumière reçue est une moyenne sur le corps, pas un pixel.
const vec2 PRISES[5] = {vec2(0.5, 0.5), vec2(0.4, 0.5), vec2(0.6, 0.5), vec2(0.5, 0.4), vec2(0.5, 0.6)};

varying vec3 monde;

vec3 lumiere_recue(bool deux) {
	vec3 somme = vec3(0.0);
	for (int i = 0; i < 5; i++) {
		somme += deux ? texture(capteur_2, PRISES[i]).rgb : texture(capteur_1, PRISES[i]).rgb;
	}
	return somme / 5.0;
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 motif = vec2(monde.x + monde.z, -monde.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	float recue = pate_luminance(lumiere_recue(deux));
	vec3 c = gris * smoothstep(seuil_bas, seuil_haut, recue);
	ALBEDO = pate(c, pate_luminance(c), style, motif, vec2(0.0), recue, aa);
}
