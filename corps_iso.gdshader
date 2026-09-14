shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Le matériau d'équité des corps voxel — chantier ISO, étape ISO3.
//
// `unshaded`, et c'est la règle qui compte ici, pas un choix de style : le noir
// absolu du jeu interdit toute ambiante et toute émission (CLAUDE.md, « Trois
// règles d'Adrien »). Un shader `spatial` par défaut resterait noir tant
// qu'aucune `Light3D` n'existe — et ISO3 n'en pose aucune — mais un
// `WorldEnvironment` avec une ambiante non nulle, posé un jour par une autre
// étape, ferait fuir de la lumière sur un corps qui ne devrait pas en recevoir.
// `unshaded` ferme cette porte pour de bon : la seule source de lumière du
// corps est `lumiere_recue`, jamais l'environnement.
//
// `lumiere_recue` est pour ISO3 un simple curseur (le banc le règle) : ISO2
// posera les capteurs qui l'alimenteront depuis la lightmap 2D existante — la
// même vérité que le halo et la torche du jeu 2D, jamais recalculée ici.

uniform vec4 couleur_fiche : source_color = vec4(0.5, 0.53, 0.57, 1.0);
uniform float lumiere_recue : hint_range(0.0, 1.0) = 0.0;

// Réservé à la fonction de style d'ISO1 (contours, hachures, trame — décision
// d'Adrien à prendre sur planche, pas en code). 0 = aplat, le seul mode que
// cette étape implémente.
uniform float style : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = couleur_fiche.rgb * lumiere_recue;
}
