shader_type canvas_item;
render_mode blend_mix;

// Voile de fumée de la fusée éclairante — chantier FUSÉE, étape FU2.
//
// Peint au-dessus des nappes tournantes : il porte la densité fine (bruit FBM),
// la MASSE SOMBRE qui remplace la silhouette d'un joueur pris dans la fumée
// (on voit qu'il y a quelqu'un — ni qui, ni dans quel sens il vise), et les
// couloirs de SILLAGE qu'une traversée creuse et qui se referment.
//
// Il est ÉCLAIRÉ, comme les nappes : c'est la lumière de la fusée (et les
// torches) qui le révèle, donc l'occlusion des murs et l'extinction dans le
// noir sont gratuites. Une première version UNSHADED brillait dans le noir
// complet et se peignait par-dessus les murs — attrapée à la revue du lot.
//
// Le temps est un UNIFORM (l'âge de la fusée), jamais TIME : la killcam rejoue
// un âge arbitraire, et les volutes doivent dériver avec lui.
//
// FU3 — les TUNNELS : le segment qu'une balle creuse en traversant la fumée.
// Incandescent pour une arme qui émet de la lumière (elle accuse le tireur) ;
// SOMBRE pour l'arbalète, seule trace au monde de l'arme sans lumière. Même
// famille que les trous du sillage — un segment plutôt qu'un point — mais
// jamais mêlés au même tampon : un trou EFFACE la densité en permanence tant
// qu'un corps y est, un tunnel s'ÉTEINT tout seul en 0,4 s quoi qu'il arrive.

uniform vec4 teinte : source_color = vec4(0.72, 0.70, 0.68, 1.0);
uniform float alpha_globale : hint_range(0.0, 1.0) = 0.0;
uniform float age = 0.0;
uniform float graine = 0.0;
uniform int nb_masses = 0;
uniform vec2 masses[2];
uniform float masse_rayon_uv = 0.065;
uniform float masse_opacite = 0.55;
uniform int nb_trous = 0;
uniform vec3 trous[16]; // xy = position UV, z = rayon UV

// Deux tableaux de points plutôt qu'un tableau de segments : même patron que
// `masses`/`trous` ci-dessus (Vector2/Vector3 déjà éprouvés côté GDScript),
// jamais de vec4[] — non vérifiable par les suites headless, qui ne rendent
// rien (piège consigné : une erreur de shader ne rougit aucune suite).
uniform int nb_tunnels = 0;
uniform vec2 tunnels_entree[6];
uniform vec2 tunnels_sortie[6];
uniform float tunnel_force[6];  // 0..1, décroît sur TUNNEL_DUREE
uniform float tunnel_sombre[6]; // 0.0 = incandescent, 1.0 = sombre (arbalète)
uniform float tunnel_largeur_uv = 0.03;

float valeur(vec2 i) {
	return fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = valeur(i);
	float b = valeur(i + vec2(1.0, 0.0));
	float c = valeur(i + vec2(0.0, 1.0));
	float d = valeur(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float somme = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		somme += amp * bruit(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return somme;
}

// Distance d'un point à un segment — le tunnel est un TRAIT, pas un point.
float distance_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 centre = UV - vec2(0.5);
	float d = length(centre) * 2.0; // 0 au centre, 1 au bord du quad

	// Volutes qui dérivent lentement ; la graine décale le champ par fusée pour
	// que deux fusées ne montrent jamais la même fumée.
	vec2 q = UV * 3.0 + vec2(graine * 0.013, graine * 0.007);
	q += vec2(age * 0.03, -age * 0.02);
	float n = fbm(q);

	// Dense au centre, claire aux bords : le gradient spatial de la cachette —
	// se cacher au cœur est efficace mais prévisible.
	float bord = 1.0 - smoothstep(0.30, 1.0, d);
	float densite = bord * mix(0.45, 1.0, n);

	// Les couloirs de sillage : des trous circulaires qui se referment.
	for (int i = 0; i < 16; i++) {
		if (i < nb_trous) {
			float dt = distance(UV, trous[i].xy);
			densite *= smoothstep(trous[i].z * 0.35, trous[i].z, dt);
		}
	}

	float alpha = densite * alpha_globale;
	vec3 rgb = teinte.rgb;

	// La masse sombre : la fumée devant un corps s'épaissit et s'assombrit.
	// Elle SUIT l'opacité de la fumée — jamais d'invisibilité dans la lumière,
	// une fumée qui se dissipe rend d'abord sa silhouette.
	for (int i = 0; i < 2; i++) {
		if (i < nb_masses) {
			float dm = distance(UV, masses[i]);
			float m = 1.0 - smoothstep(masse_rayon_uv * 0.45, masse_rayon_uv, dm);
			m *= masse_opacite * alpha_globale * bord;
			rgb = mix(rgb, vec3(0.03), clamp(m * 1.8, 0.0, 1.0));
			alpha = max(alpha, m);
		}
	}

	// FU3 — les tunnels de balle : un trait qui traverse la fumée, incandescent
	// ou sombre selon l'arme. Rendus APRÈS les masses : un tir traversant une
	// silhouette doit rester lisible par-dessus elle, pas dessous.
	for (int i = 0; i < 6; i++) {
		if (i < nb_tunnels) {
			float dseg = distance_segment(UV, tunnels_entree[i], tunnels_sortie[i]);
			float t = (1.0 - smoothstep(tunnel_largeur_uv * 0.35, tunnel_largeur_uv, dseg))
				* tunnel_force[i];
			if (tunnel_sombre[i] > 0.5) {
				// Le carreau d'arbalète : creuse la densité comme un couloir noir.
				alpha *= (1.0 - t);
				rgb = mix(rgb, vec3(0.02), t * 0.85);
			} else {
				// La balle qui accuse : un trait chaud, plus clair que la braise.
				rgb = mix(rgb, vec3(1.0, 0.85, 0.55), t);
				alpha = max(alpha, t * 0.9);
			}
		}
	}

	COLOR = vec4(rgb, alpha);
}
