// UN NUAGE EN VOXELS de la vue iso — chantier « Gadgets en volume » (GV1), À L'ESSAI : `--fumee-voxel-essai`, éteint par
// défaut. Sans le drapeau, personne ne charge ce fichier : le jeu dessine les couches de `volume_iso.gdshader`.
//
// Adrien, 2026-09-30 : « tous les gadgets (je me souviens de la fumée occultante) […] davantage en 3D. Là on est pris
// entre le graphisme BD et la 3D voxel. » La suie, la poussière et la fumée de la fusée deviennent un tas de CUBES, dans
// la langue des corps et des murs : des boîtes, le dessus clair et deux côtés plus sombres, les côtés encrés, la lumière de
// la vue de dessus posée dessus.
//
// ## Un seul maillage par nuage et par vue : une grille de cubes instanciés
//
// `IsoNuageVoxel` pose une grille de cellules (un `MultiMesh`, un appel de dessin) sur le cylindre du nuage ; ce shader
// décide, SOMMET par sommet, ce que porte chaque case (`cube_de`) : rien hors du nuage (le cube s'écrase en un point et ne
// dessine rien), un cube plein dans son corps. Tout part de la densité du nuage 2D, lue au pied de la cellule :
// - suie et poussière : l'alpha de leur image (`masque`), tournée comme elle, jusqu'à son bord ;
// - fumée de la fusée (`NUAGE_FUSEE`) : ce que la vue de dessus y peint — le voile à trous de `fumee_fusee.gdshader`
//   (volutes, masses, sillage, tunnels) et les nappes tournantes de `nappe_fusee.gdshader` (planche, paliers), composés
//   comme la 2D les compose (couverture 1 − Π(1 − a)) ;
// - le DÔME des couches : en montant, le rayon se resserre (× 1 − 0,22 f) ;
// - la VIE : l'opacité rendue de la masse (naissance, dissipation) ; pour la fusée, déjà dans les alphas qu'elle peint.
// La TAILLE d'un cube suit la densité (son côté croît du seuil jusqu'à la case pleine) : un nuage qui se dissipe rapetisse
// ses cubes jusqu'à rien, un trou du sillage vide sa colonne. Sa HAUTEUR suit le relief des BOUFFÉES : chaque colonne
// monte jusqu'à un sommet tiré d'un bruit attaché au nuage, sous la densité et la vie — le dessus du nuage fait des
// marches, et leurs côtés sombres disent le volume.
//
// ## Le coût, tenu par construction
//
// Seule la PEAU du nuage rastérise : une face d'un cube plein collée à un voisin plein s'écrase (`LES FACES CACHÉES`), un
// cube vide sort avant de lire la lumière. Un pixel ne voit donc que les deux ou trois premières faces du nuage, et non une
// par cube traversé ; les couches, elles, couvrent toutes leur quad entier. Le banc le compte (`--mode=cout`).
//
// ## Trois règles, et comment elles tiennent
//
// - **Noir absolu dans le monde** : un cube vaut la lightmap de la vue qui le dessine, lue sous lui (lissée comme celle
//   des couches : la lumière du nuage, pas le dessin de sa volute), passée à la pâte comme le sol ; ses faces ne font que
//   l'assombrir (dessus 1, côtés < 1, encre < 1, en valeur affichée par `pate_facteur`). Aucune lumière de plus : 0 sous
//   lui, 0 sur lui.
// - **Noir absolu à l'écran** (la parallaxe, piège du 2026-09-24) : un cube en hauteur est dessiné sur des pixels qui
//   montrent un autre sol que le sien. Le PAREMENT est le masque de la fumée (Q31) sous sa forme pochoir : le juge du nuage
//   (`volume_iso.gdshader`, `MASQUE_POCHOIR_JUGE`), dessiné juste avant, écrit 1 dans le pochoir là où ce que le pixel
//   montre derrière est affiché noir ; aucun cube ne s'y dessine (le test du pochoir précède ce shader). Sans juge (masque
//   coupé en débogage), le pochoir vaut 0 partout et le test passe partout.
// - **Jamais plus caché qu'en vue de dessus** : dessiné AVANT les corps (`render_priority` du volume), sans écrire la
//   profondeur ; un corps dans le nuage se dessine par-dessus, et ne s'y efface que par son opacité (ISO2b), que décide la
//   règle 2D (`occultation_pour`).
//
// ## Chaque vue a son maillage
//
// Des cubes à moitié opaques, sans profondeur écrite, se composent dans l'ordre où on les dessine : il faut peindre du
// plus loin au plus proche (l'algorithme du peintre). Une caméra orthographique et une grille régulière le permettent sans
// tri (Frieder, Gordon et Reynolds, 1985 : chaque axe parcouru du côté loin vers le côté proche). Mais J1 (lacet 45°) et
// J2 (225°) regardent de deux côtés opposés : un ordre juste pour l'un est l'inverse pour l'autre. Chaque vue a donc SA
// grille (le même jeu de cellules, dans son ordre), sur le calque 3D de sa caméra, et lit SA lightmap (`vue_deux`) ; ses
// cubes n'ont que les trois faces que sa caméra voit. Les deux vues voient le même nuage, chacune de son côté.
//
// Non éclairé ; mélange normal ; profondeur lue, jamais écrite ; aucune `Light3D`.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
// Le masque de la fumée, forme pochoir : lu, jamais écrit (c'est le juge du nuage qui l'écrit).
stencil_mode read, compare_not_equal, 1;

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"

// La vue qui dessine CE maillage (son calque 3D n'est vu que de sa caméra) : J2 lit `lumiere_2`, J1 `lumiere_1`.
uniform bool vue_deux = false;
// Le nuage : son centre et son rayon en pixels de monde, la hauteur de son dôme, le côté d'un voxel.
uniform vec2 nuage_centre = vec2(0.0);
uniform float nuage_rayon = 100.0;
uniform float nuage_hauteur_px = 28.0;
uniform float voxel_px = 8.75;
// La vie du nuage (l'opacité rendue de sa masse) × sa densité de voxels (`IsoNuageVoxel.NUAGES`).
uniform float nuage_vie = 1.0;
// Le cœur plein du profil radial, en fraction du rayon. Les couches prennent 0,45 (leur bord s'adoucit sur plus de la
// moitié du rayon) ; les cubes prennent 1, AUCUN profil (`IsoNuageVoxel.COEUR`) : leur taille adoucit déjà le bord, et un
// profil qui s'éteint avant le bord de l'image laissait la masse, dessinée au sol, déborder en liseré autour des cubes.
uniform float nuage_coeur = 0.45;
// Le rayon de la lumière LISSÉE que lit un cube, en pixels de monde : comme les couches (ISO10, 1c), un cube montre la
// lumière du nuage, pas le dessin de sa volute — lue au point, la lightmap faisait de chaque trait d'encre de la masse une
// rangée de cubes noirs (premier passage du banc). `IsoNuageVoxel` le pose à 0,18 × le rayon du nuage, au moins un voxel.
uniform float lissage_px = 16.0;
// Sous ce seuil de densité, aucun cube ; au-dessus, le cube grandit, et remplit sa case entière dès `plein_taille` : le
// corps du nuage est fait de cubes pleins et jointifs, seuls ses bords et sa dissipation en ont de plus petits (des cubes
// tous un peu rétrécis laissaient des jours entre eux partout, et le nuage se lisait comme du papier bulle : deuxième
// passage du banc).
uniform float seuil_taille = 0.1;
uniform float plein_taille = 0.45;
// La portée de la grille autour du centre, en pixels de monde (`IsoNuageVoxel.cellules`) : au-delà, aucune case n'est
// dessinée, et un voisin qui y tomberait ne cache rien.
uniform float grille_portee = 1000.0;
// L'opacité d'un cube (la suie est dense, la poussière mince).
uniform float alpha_voxel = 0.85;
// L'âge du nuage : une respiration lente de chaque cube (jamais TIME : la killcam rejoue un âge).
uniform float age = 0.0;
// La teinte chaude du sol et des murs (ISO7), comme les couches.
uniform float temperature = 0.0;
// Le modelé des faces, en valeur affichée : le dessus porte la lumière lue, les deux côtés que la caméra voit
// l'assombrissent (à gauche et à droite de l'écran : la même règle dans les deux vues).
uniform float face_dessus = 1.0;
uniform float face_gauche = 0.8;
uniform float face_droite = 0.62;
// L'encre des arêtes : largeur en pixels de monde (bornée par la taille du cube), et ce qu'elle garde de la lumière.
uniform float encre_px = 0.9;
uniform float encre_reste = 0.5;

#ifdef NUAGE_FUSEE
// LE VOILE de la fusée (`fumee_fusee.gdshader`), mêmes noms, mêmes valeurs — recopiées depuis son matériau à chaque image.
uniform float voile_alpha_globale = 0.0;
uniform float voile_graine = 0.0;
uniform float voile_age = 0.0;
uniform int nb_masses = 0;
uniform vec2 masses[2];
uniform float masse_rayon_uv = 0.065;
uniform float masse_opacite = 0.55;
uniform int nb_trous = 0;
uniform vec3 trous[16];
uniform int nb_tunnels = 0;
uniform vec2 tunnels_entree[6];
uniform vec2 tunnels_sortie[6];
uniform float tunnel_force[6];
uniform float tunnel_sombre[6];
uniform float tunnel_largeur_uv = 0.03;
// Le diamètre du voile (son quad), en pixels de monde.
uniform float voile_diametre = 400.0;
// LES NAPPES (`nappe_fusee.gdshader`) : trois au plus (deux en écran scindé). Pour chacune : x la rotation du sprite, y son
// diamètre en pixels de monde, z son opacité (`modulate.a`).
uniform int nb_nappes = 0;
uniform sampler2D nappe_1 : filter_linear, repeat_disable;
uniform sampler2D nappe_2 : filter_linear, repeat_disable;
uniform sampler2D nappe_3 : filter_linear, repeat_disable;
uniform vec3 nappes[3];
#else
// La forme du nuage d'un gadget : l'alpha de son image 2D, tournée comme elle.
uniform sampler2D masque : filter_linear, repeat_disable;
uniform bool avec_masque = false;
uniform float nuage_angle = 0.0;
#endif

varying flat vec3 v_couleur;
varying flat vec3 v_encre;
varying flat float v_alpha;
varying flat float v_cote;
varying flat float v_haut;
varying flat vec3 v_normale;
varying vec3 v_local;

#ifdef NUAGE_FUSEE
// Le bruit du voile, recopié de `fumee_fusee.gdshader` (préfixé : `iso_pate` a déjà son bruit).
float voile_valeur(vec2 i) {
	return fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
}

float voile_bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = voile_valeur(i);
	float b = voile_valeur(i + vec2(1.0, 0.0));
	float c = voile_valeur(i + vec2(0.0, 1.0));
	float d = voile_valeur(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float voile_fbm(vec2 p) {
	float somme = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		somme += amp * voile_bruit(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return somme;
}

float voile_distance_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	return length(pa - ba * h);
}

// L'alpha du voile au point `uv` de son quad : `fumee_fusee.gdshader`, ligne pour ligne, la couleur en moins.
float voile_alpha(vec2 uv) {
	vec2 centre = uv - vec2(0.5);
	float d = length(centre) * 2.0;
	vec2 q = uv * 3.0 + vec2(voile_graine * 0.013, voile_graine * 0.007);
	q += vec2(voile_age * 0.03, -voile_age * 0.02);
	float n = voile_fbm(q);
	float bord = 1.0 - smoothstep(0.30, 1.0, d);
	float densite = bord * mix(0.45, 1.0, n);
	for (int i = 0; i < 16; i++) {
		if (i < nb_trous) {
			float dt = distance(uv, trous[i].xy);
			densite *= smoothstep(trous[i].z * 0.35, trous[i].z, dt);
		}
	}
	float alpha = densite * voile_alpha_globale;
	for (int i = 0; i < 2; i++) {
		if (i < nb_masses) {
			float dm = distance(uv, masses[i]);
			float m = 1.0 - smoothstep(masse_rayon_uv * 0.45, masse_rayon_uv, dm);
			m *= masse_opacite * voile_alpha_globale * bord;
			alpha = max(alpha, m);
		}
	}
	for (int i = 0; i < 6; i++) {
		if (i < nb_tunnels) {
			float dseg = voile_distance_segment(uv, tunnels_entree[i], tunnels_sortie[i]);
			float t = (1.0 - smoothstep(tunnel_largeur_uv * 0.35, tunnel_largeur_uv, dseg)) * tunnel_force[i];
			if (tunnel_sombre[i] > 0.5) {
				alpha *= (1.0 - t);
			} else {
				alpha = max(alpha, t * 0.9);
			}
		}
	}
	return clamp(alpha, 0.0, 1.0);
}

// L'alpha d'une nappe au point `p` du monde : `nappe_fusee.gdshader` (la planche, ses trois paliers de luminance) sous
// l'opacité du sprite, lu dans le repère du sprite tourné. Le sommet n'a pas de dérivées : les marches des paliers sont
// franches (la 2D les adoucit d'un pixel d'écran).
float nappe_alpha(sampler2D t, vec2 p, vec3 n) {
	vec2 d = (p - nuage_centre) / max(n.y, 1.0);
	float ca = cos(n.x);
	float sa = sin(n.x);
	vec2 uv = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y) + vec2(0.5);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	vec4 planche = texture(t, uv);
	float densite = max(planche.r, max(planche.g, planche.b));
	float palier = step(0.15, densite) * 0.35 + step(0.45, densite) * 0.30 + step(0.75, densite) * 0.35;
	return clamp(n.z * planche.a * palier, 0.0, 1.0);
}
#endif

// La densité du nuage 2D au point `p` du sol, pour une couche du dôme dont le rayon est resserré de `resserre`.
float densite_2d(vec2 p, float resserre) {
	// Le point lu, écarté du centre : la couche haute montre une copie resserrée du nuage.
	vec2 q = nuage_centre + (p - nuage_centre) / max(resserre, 0.05);
#ifdef NUAGE_FUSEE
	float vide = 1.0 - voile_alpha((q - nuage_centre) / max(voile_diametre, 1.0) + vec2(0.5));
	if (nb_nappes > 0) {
		vide *= 1.0 - nappe_alpha(nappe_1, q, nappes[0]);
	}
	if (nb_nappes > 1) {
		vide *= 1.0 - nappe_alpha(nappe_2, q, nappes[1]);
	}
	if (nb_nappes > 2) {
		vide *= 1.0 - nappe_alpha(nappe_3, q, nappes[2]);
	}
	return 1.0 - vide;
#else
	vec2 d = (q - nuage_centre) / max(nuage_rayon, 1.0);
	// `min` : sans profil (cœur 1), `smoothstep(1, 1, x)` divise par zéro — indéfini en GLSL.
	float forme = 1.0 - smoothstep(min(nuage_coeur, 0.99), 1.0, length(d));
	if (forme <= 0.0) {
		return 0.0;
	}
	if (avec_masque) {
		float ca = cos(nuage_angle);
		float sa = sin(nuage_angle);
		vec2 local = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y);
		forme *= texture(masque, local * 0.5 + vec2(0.5)).a;
	}
	return forme;
#endif
}

// LES BOUFFÉES — le relief du dessus du nuage : un bruit doux ATTACHÉ AU NUAGE, en bosses d'un tiers de son rayon (entre
// 28 et 80 pixels de monde). Il tourne avec le dessin d'un gadget ; sa graine est tirée de son centre, donc la même dans les
// deux vues et sur les deux machines ; il dérive lentement avec l'âge (jamais TIME : la killcam rejoue un âge).
float bouffees(vec2 p) {
	vec2 d = p - nuage_centre;
#ifndef NUAGE_FUSEE
	float ca = cos(nuage_angle);
	float sa = sin(nuage_angle);
	d = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y);
#endif
	vec2 graine = vec2(pate_hash(floor(nuage_centre)), pate_hash(floor(nuage_centre) + vec2(7.0, 3.0))) * 40.0;
	vec2 q = d / clamp(0.3 * nuage_rayon, 28.0, 80.0) + graine + vec2(0.05, -0.03) * age;
	return 0.65 * pate_bruit(q) + 0.35 * pate_bruit(q * 2.13 + vec2(5.2, 1.3));
}

// La lumière de la vue qui dessine, autour du pied du cube : le point (déjà lu, `centre_lu`) et huit lectures sur un cercle
// de `lissage_px` — la moyenne de `lire_lightmap_lissee` des couches (`volume_iso.gdshader`). Jamais plus claire que la
// plus claire des lectures ; nulle si toutes le sont.
vec3 lumiere_lissee(vec2 p, vec3 centre_lu) {
	vec3 s = centre_lu;
	for (int k = 0; k < 8; k++) {
		float t = float(k) * 0.785398163;
		s += lire_lightmap(p + vec2(cos(t), sin(t)) * lissage_px, vue_deux);
	}
	return s / 9.0;
}

// Ce que porte la case de centre `c` (monde) : x la taille de son cube, en fraction de la case (0 : rien) ; y sa hauteur,
// en fraction de sa taille (le sommet de sa colonne le coupe). Le même calcul pour un cube et pour son voisin.
vec2 cube_de(vec3 c) {
	// LES BOUFFÉES : chaque colonne monte jusqu'à son SOMMET — le relief des bouffées, sous la densité (bas au bord, haut au
	// cœur) et sous la vie (le nuage s'affaisse en se dissipant). Le cube que le sommet coupe est une marche basse, posée
	// au fond de sa case ; sous un quart de case, il n'est plus rien. Les côtés des marches, plus sombres, disent le
	// volume : sans elles, un nuage large et bas se lisait comme un dallage vu d'en haut (premier passage du banc).
	float bosse = 0.3 + 0.9 * bouffees(c.xz);
	float vie = sqrt(clamp(nuage_vie, 0.0, 1.0));
	float bas = c.y - 0.5 * voxel_px;
	// Au-dessus du plus haut sommet possible ici (densité pleine), aucun cube : on sort AVANT de lire la densité, la part
	// chère (le voile de la fusée, son bruit et ses trous). Même image, moins de travail par sommet.
	if (nuage_hauteur_px * clamp(bosse, 0.0, 1.0) * vie - bas < 0.25 * voxel_px) {
		return vec2(0.0);
	}
	float f = clamp(c.y / max(nuage_hauteur_px, 1.0), 0.0, 1.0);
	// La densité du nuage 2D sous la cellule, sur le dôme (le rayon se resserre en montant), sous la vie.
	float d2 = densite_2d(c.xz, 1.0 - 0.22 * f);
	float rho = d2 * nuage_vie;
	// Une respiration par cube, de phase tirée de sa case (la même dans les deux vues et sur les deux machines).
	vec3 cellule = floor(c / max(voxel_px, 0.001));
	float h = pate_hash(cellule.xz + vec2(cellule.y * 17.0, cellule.y * 3.0));
	rho *= 0.88 + 0.24 * (0.5 + 0.5 * sin(age * 1.3 + h * 6.2831853));
	float t = clamp((rho - seuil_taille) / max(plein_taille - seuil_taille, 0.001), 0.0, 1.0);
	float s = sqrt(t);
	float sommet = nuage_hauteur_px * clamp(d2 * bosse, 0.0, 1.0) * vie;
	float haut = clamp((sommet - bas) / max(voxel_px, 0.001), 0.0, 1.0);
	// Les marches, par DEMI-CASE : des colonnes voisines de hauteurs presque égales font un palier entier, et non une
	// dentelle de côtés d'un pixel, encrés partout — le « dallage » de la poussière, deuxième passage du banc.
	haut = haut < 0.25 ? 0.0 : (haut < 0.75 ? 0.5 : 1.0);
	return haut <= 0.0 ? vec2(0.0) : vec2(s, haut);
}

void vertex() {
	// Le centre de la cellule, dans le monde : l'origine de l'instance (la transformation d'une instance de `MultiMesh` est
	// dans MODEL_MATRIX). Tout ce qui suit est le même pour les sommets d'une face : une couleur et une taille par cube.
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cube = cube_de(c);
	float s = cube.x;
	float haut = cube.y;
	// LES FACES CACHÉES — le coût tenu par construction. Une face d'un cube de pleine largeur collée à un voisin qui la
	// couvre (au-dessus pour le dessus ; devant, du côté de la caméra, pour un côté — les trois seules faces qu'a le
	// maillage) ne se voit pas : elle s'écrase en un point et ne rastérise rien. Il ne reste que la PEAU du nuage : un pixel n'y voit plus que ses deux ou
	// trois premières faces, au lieu d'une par cube traversé (huit et plus au cœur d'un nuage plein : le coût d'un volume
	// dessiné en entier). Un cube vide sort ici, avant la lumière et le voisin. Un voisin hors de la grille (à moins d'un
	// voxel de son bord) n'est pas dessiné : il ne cache rien.
	bool cachee = s <= 0.0;
	if (!cachee && s >= 1.0) {
		vec3 voisin = c + NORMAL * voxel_px;
		if (length(voisin.xz - nuage_centre) <= grille_portee - 0.75 * voxel_px) {
			vec2 v = cube_de(voisin);
			// Le dessus d'un cube entier sous un voisin de pleine largeur ; un côté devant un voisin de pleine largeur au
			// moins aussi haut que lui (une marche contre une marche égale).
			cachee = NORMAL.y > 0.5 ? (haut >= 1.0 && v.x >= 1.0) : (v.x >= 1.0 && v.y >= haut);
		}
	}
	v_local = VERTEX;
	v_normale = NORMAL;
	v_cote = voxel_px * s;
	v_haut = haut;
	v_alpha = alpha_voxel;
	if (cachee) {
		VERTEX = vec3(0.0);
		v_couleur = vec3(0.0);
		v_encre = vec3(0.0);
	} else {
		// Le cube : `s` de côté, centré dans sa case ; sa hauteur coupée à `haut`, son pied gardé.
		VERTEX.xz *= s;
		VERTEX.y = (VERTEX.y + 0.5) * s * haut - 0.5 * s;
		vec3 brute = lire_lightmap(c.xz, vue_deux);
		vec3 lu = lumiere_lissee(c.xz, brute);
		float l = pate_luminance(lu);
		// NOIR AU PIED : un cube dont le sol, sous lui, est noir est noir — le lissage ne répand pas la lumière des voisins
		// dans l'ombre (les couches, elles, ne s'éteignent que si les neuf lectures le sont). Au bord d'une tache de lumière,
		// un cube pâle posé sur du noir laissait 1/255 là où le juge du masque tranche au pixel (deuxième preuve du noir).
		vec3 col = (l <= 0.0 || pate_luminance(brute) <= 0.0) ? vec3(0.0)
			: (style == PATE_BRUTE ? lu : pate(lu, l, style, c.xz, vec2(0.0), l, 0.1));
		col = pate_temperature_graduee_neutre(col, temperature, 0.0, 0.0, pate_poids_neutre(brute));
		// La face : le dessus porte la lumière ; un côté est à gauche ou à droite de l'écran selon la caméra qui dessine.
		// NORMAL est dans le repère du modèle, qui est celui du monde (l'instance n'est qu'une échelle et une translation).
		float face = face_dessus;
		if (NORMAL.y < 0.5) {
			float cote = dot(NORMAL, INV_VIEW_MATRIX[0].xyz);
			face = cote > 0.3 ? face_droite : (cote < -0.3 ? face_gauche : 0.5 * (face_gauche + face_droite));
		}
		v_couleur = pate_facteur(col, face);
		v_encre = pate_facteur(col, face * encre_reste);
	}
}

void fragment() {
	// L'ENCRE, sur les CÔTÉS seulement : leurs quatre bords (le pli avec le dessus, les bords d'une marche, les cubes
	// empilés), la hauteur réelle d'un côté étant celle du cube coupé par le sommet. LE DESSUS N'EN A PAS : deux dessus
	// voisins à la même hauteur se lisent d'un seul tenant — encré, chaque dessus dessinait son carré, et le nuage devenait
	// une grille (deuxième passage du banc). Distances en pixels de monde ; le trait borné au cinquième du cube.
	vec3 an = abs(v_normale);
	float horizontal = an.x > 0.5 ? v_local.z : v_local.x;
	float bord = min((0.5 - abs(horizontal)) * v_cote, (0.5 - abs(v_local.y)) * v_cote * v_haut);
	float aa = max(fwidth(bord), 1e-3);
	float w = min(encre_px, 0.2 * v_cote * max(v_haut, 0.3));
	float trait = an.y > 0.5 ? 0.0 : 1.0 - smoothstep(w - aa, w + aa, bord);
	ALBEDO = mix(v_couleur, v_encre, trait);
	ALPHA = v_alpha;
}
