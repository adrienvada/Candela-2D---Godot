shader_type canvas_item;
render_mode blend_mix, unshaded;

// M12 « La brume d'abysse » et M5 « Le bruit de l'œil », dans un seul matériau.
//
// Les deux fiches le prévoyaient : ils vivent sur le même quad — l'aplat de fond
// du menu — et un second matériau plein écran aurait doublé le coût pour
// dessiner au même endroit.
//
// Ce que la brume raconte : le noir du menu n'est pas un #000 vide, c'est une
// pénombre habitée. La première seconde du menu enseigne déjà la grammaire du
// jeu — le noir est une matière, la lumière est une présence.
//
// Ce que le bruit de l'œil raconte : à la frontière exacte entre le halo de la
// torche et le noir, une granulation fourmille, comme la rétine d'un œil qui
// force dans l'obscurité. Nulle part ailleurs — ni dans la lumière pleine, ni
// dans le noir profond.
//
// **Le noir doit rester noir.** Toute la luminance ajoutée ici est bornée à
// LUM_MAX. Au-delà, le fond cesserait d'être noir et le jeu ne parlerait plus de
// la même chose.
//
// 100 % ALU : aucune lecture de texture, aucun `screen_texture`. Un quad, une
// poignée de hash. `gl_compatibility` sans réserve.

// --- Ce que l'interface pousse ---------------------------------------------
uniform float intensite_brume : hint_range(0.0, 1.0) = 1.0;
uniform float intensite_bruit : hint_range(0.0, 1.0) = 1.0;
// Décalage de parallaxe, en UV. Amorti côté GDScript.
uniform vec2 parallaxe = vec2(0.0);
// Centres des torches en UV, et leur rayon. w <= 0 éteint la torche.
uniform vec4 torche_p1 = vec4(0.5, 0.5, 0.0, 0.0);
uniform vec4 torche_p2 = vec4(0.5, 0.5, 0.0, 0.0);
// Rapport largeur/hauteur, pour que les anneaux soient ronds.
uniform float ratio = 1.777;
// Les couleurs des deux territoires, poussées par `menu_backdrop.gd`.
uniform vec3 territoire_p1 = vec3(0.29, 0.72, 0.97);
uniform vec3 territoire_p2 = vec3(0.95, 0.29, 0.33);

// Bornes de luminance de la brume. Le plafond n'est pas un réglage : c'est le
// contrat du jeu.
const float LUM_MIN = 0.010;
const float LUM_MAX = 0.035;
// Les territoires : le bleu de J1 à gauche, le rouge de J2 à droite. Quasi
// subliminal.
//
// ⚠️ **Les deux teintes sont POUSSÉES depuis `charte.gd`, plus écrites ici.**
// Elles y étaient en dur — `vec3(0.0, 0.62, 0.72)` et `vec3(0.72, 0.10, 0.24)`,
// c'est-à-dire l'ancien cyan d'arcade et l'ancien carmin — et la passe de
// palette de DA1.4 ne les a pas vues : elle ne balayait que les `.gd`. Un
// shader est un endroit où une couleur se cache bien.
const float TERRITOIRE = 0.020;
// Amplitude du bruit rétinien, en luminance.
const float GRAIN = 0.028;
// Le scintillement est quantifié : à chaque image, il ferait « vidéo ». À douze
// pas par seconde, il fait « organique ».
const float GRAIN_HZ = 12.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Bruit de valeur, interpolé en douceur. Deux octaves suffisent : au-delà, on
// paie du détail que 3 % de luminance ne montrent pas.
float valeur(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float nappe(vec2 uv) {
	return valeur(uv * 3.0) * 0.65 + valeur(uv * 7.0) * 0.35;
}

void fragment() {
	vec2 uv = UV + parallaxe;
	vec3 ajout = vec3(0.0);

	if (intensite_brume > 0.0) {
		// Deux nappes en sens opposés : le brouillard se déforme au lieu de
		// défiler. Une seule nappe se lirait comme un défilement de texture.
		float a = nappe(uv + vec2(TIME * 0.008, TIME * -0.005));
		float b = nappe(uv * 1.4 + vec2(TIME * -0.013, TIME * 0.009));
		float brume = mix(LUM_MIN, LUM_MAX, clamp(a * 0.6 + b * 0.4, 0.0, 1.0));

		// Une torche lointaine derrière un verre dépoli, décentrée vers le haut,
		// qui respire sur neuf secondes.
		vec2 vers = (uv - vec2(0.5, 0.34)) * vec2(ratio, 1.0);
		float halo = 1.0 - smoothstep(0.0, 0.85, length(vers));
		float souffle = 1.0 + 0.02 * sin(TIME * (6.2831853 / 9.0));
		brume *= (0.75 + 0.45 * halo) * souffle;

		// Les territoires. La gauche est à P1, la droite à P2 — la même
		// convention que l'écran partagé, apprise sans un mot.
		vec3 teinte = mix(territoire_p1, territoire_p2,
			smoothstep(0.3, 0.7, uv.x));
		ajout += vec3(brume) + teinte * TERRITOIRE * intensite_brume;
		ajout *= intensite_brume;
	}

	if (intensite_bruit > 0.0) {
		// Le bruit ne vit qu'à la LISIÈRE : deux smoothstep en anneau. Dans la
		// lumière pleine il n'a rien à dire, et dans le noir profond il ferait du
		// bruit de capteur.
		float anneau = 0.0;
		vec2 p = uv * vec2(ratio, 1.0);
		if (torche_p1.w > 0.0) {
			float d = length(p - torche_p1.xy * vec2(ratio, 1.0)) / torche_p1.w;
			anneau = max(anneau, smoothstep(0.45, 0.80, d) * (1.0 - smoothstep(0.80, 1.20, d)));
		}
		if (torche_p2.w > 0.0) {
			float d = length(p - torche_p2.xy * vec2(ratio, 1.0)) / torche_p2.w;
			anneau = max(anneau, smoothstep(0.45, 0.80, d) * (1.0 - smoothstep(0.80, 1.20, d)));
		}
		if (anneau > 0.0) {
			float pas = floor(TIME * GRAIN_HZ);
			float g = hash12(floor(FRAGCOORD.xy) + vec2(pas * 17.0, pas * 31.0));
			ajout += vec3((g - 0.5) * GRAIN * anneau * intensite_bruit);
		}
	}

	// L'alpha n'est jamais touché : c'est lui qui dit combien d'arène passe au
	// travers, et le modifier changerait ce que le joueur voit du monde.
	COLOR.rgb = clamp(COLOR.rgb + ajout, vec3(0.0), vec3(1.0));
}
