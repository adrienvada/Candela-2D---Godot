// Les corps GROSSIERS de la vue isométrique (ISO1, ISO2) — les cylindres gris du banc
// ISO0.b, en attendant les corps voxel d'ISO3 (qui auront leur propre shader,
// `corps_iso.gdshader`, à la session iso-corps).
//
// « Gris plafonné, noir hors lumière, et entre les deux la courbe du sprite » — depuis ISO2
// la lumière est celle que le corps REÇOIT, lue dans son capteur (`CapteurCorps`), et non celle du sol sous ses
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
// Le centre du corps dans le monde 2D — (x, y) du joueur, soit (X, Z) en 3D —, posé à chaque
// image avec le capteur qui le suit (`Presentation3D._suivre`).
uniform vec2 centre = vec2(0.0);
// Le monde qu'un capteur couvre, en pixels (`CapteurCorps.MONDE_PX`), et le rayon jusqu'où on
// y lit : dans le disque (`CapteurCorps.RAYON_PX`), loin de son bord adouci.
uniform float monde_capteur_px = 128.0;
uniform float rayon_lu_px = 15.0;

varying vec3 monde;

// ⚠️ **Chaque fragment lit le capteur À SA PLACE, et c'est ce qui fait le volume** (jalon
// H-ISO2). Le disque est éclairé comme le sprite, ombres comprises : sous la torche d'en face,
// son corps masque la moitié arrière (`flashlight.shadow_item_cull_mask` porte le corps adverse).
// Le flanc tourné vers la lampe lit la moitié éclairée, le dos la moitié dans l'ombre, le dessus
// tout le disque. Avant, le corps prenait la MOYENNE de cinq prises au centre, uniforme sur tout
// le cylindre : un disque à demi éclairé donnait un corps entier à demi-teinte, et le seuil
// d'alors cachait l'écart en le mettant au gris plein (26/255 sous la torche, mesuré sans lui).
// Aucune lumière 3D : c'est la lumière du sprite, posée sur un volume. Le nez, hors du disque,
// lit à son bord.
vec3 lumiere_recue(bool deux, vec2 decalage) {
	float r = length(decalage);
	if (r > rayon_lu_px) {
		decalage *= rayon_lu_px / r;
	}
	vec2 uv = vec2(0.5) + decalage / monde_capteur_px;
	return deux ? texture(capteur_2, uv).rgb : texture(capteur_1, uv).rgb;
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 motif = vec2(monde.x + monde.z, -monde.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	vec3 lumiere = lumiere_recue(deux, monde.xz - centre);
	float recue = pate_luminance(lumiere);
	// ⚠️ **Sans seuil : la courbe est celle du sprite remplacé, déjà appliquée dans le capteur**
	// (`capteur_adverse.gdshader`, `capteur_local.gdshader`). Le corps vaut le gris fois ce que le
	// sprite recevrait — le capteur est lu en sRGB, et le gris aussi : à l'écran, le gris de la vue
	// de dessus fois sa lumière. L'ancien `smoothstep(0,01 ; 0,08)` mettait le corps au gris plein
	// dès 8 % de lumière reçue : un interrupteur, là où la vue de dessus monte avec la lampe
	// (Adrien, jalon H-ISO2 : « pourquoi ça n'éclaire pas aussi progressivement que l'intensité »).
	vec3 c = gris * lumiere;
	// ⚠️ **Plafonnée au gris d'entrée, et c'est la règle de la vue de dessus.** Le sprite
	// ennemi y est `min(lit, COLOR)` (`player_enemy_light.gdshader`) : éclairé, il ne dépasse
	// jamais `Charte.ADVERSAIRE`. La pâte, elle, ramène un ton vers une luminance pleine — faite
	// pour relever une lueur au sol, elle poussait au BLANC un corps pleinement éclairé :
	// 255/246/227 mesurés contre un plafond de 191/177/156 (Adrien, jalon H-ISO2 : « il devient
	// tout blanc », sous la torche comme sous la LED des murs). Le `min` garde tout ce que la
	// pâte assombrit (lavis, grain) et retire seulement ce qu'elle ajoutait. Le noir absolu tient :
	// le résultat ne dépasse jamais `c`, qui est nul sans lumière. Contrôlé au pixel par
	// `tools/banc_iso.gd --jeu` (« BANC_ISO corps »).
	ALBEDO = min(pate(c, pate_luminance(c), style, motif, vec2(0.0), recue, aa), c);
}
