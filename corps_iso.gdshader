shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled, blend_mix, depth_draw_always;

// Le matériau d'équité des corps voxel — chantier ISO, étape ISO3 (vague 0 : aplat
// et noir strict ; vague 2 : capteur par fragment, pâte plafonnée, effacement,
// silhouette de soi).
//
// **L'interface est celle d'ISO2** (`corps_grossier_iso.gdshader`, commit `02f6c28`,
// transmise par ISO2 nom pour nom) : ce shader n'invente rien de son côté, il reprend
// telle quelle la seule vérité déjà écrite et vérifiée par `tools/test_iso_vues.gd` et
// `tools/banc_iso.gd --effacement`. La seule différence : `monde.xz` peut être en
// tuiles (le repère de `voxel_corps.gd`, banc compris) OU déjà en pixels (ISO3a, qui
// accrochera le corps sous un `Node3D` mis à l'échelle de `TILE_SIZE.x`) — voir
// `pixels_par_unite`, réglé par l'appelant, jamais deviné ici.
//
// `unshaded`, et c'est la règle qui compte, pas un choix de style : le noir absolu du
// jeu interdit toute ambiante et toute émission (CLAUDE.md, « Trois règles d'Adrien »).
//
// ## Le capteur, fragment par fragment — pas au centre
//
// `capteur_1`/`capteur_2` sont les textures 256² d'ISO2 (`CapteurCorps`), une par vue —
// `lightmap_de_j2(CAMERA_VISIBLE_LAYERS)` (`iso_lightmap.gdshaderinc`) dit laquelle la
// caméra qui dessine doit lire. `centre` est la position 2D du joueur, posée à chaque
// image ; `monde_capteur_px`/`rayon_lu_px` bornent la lecture au disque, loin de son bord
// adouci. Un seul échantillon au centre donnerait un corps à teinte plate ; le modelé
// qu'Adrien a jugé « parfait » au jalon H-ISO2 (côté lampe clair, dos sombre) vient de
// lire CE capteur à la position de CHAQUE fragment. `capteur_actif` retombe sur
// `lumiere_recue` (repli scalaire, vague 0/1) quand aucun capteur n'est fourni — le banc
// de cette étape, en l'absence d'ISO3a.
//
// ## La pâte, plafonnée
//
// `#include "iso_pate.gdshaderinc"` : la fonction de style d'ISO1, partagée par le sol,
// les murs et maintenant les corps. `min(pate(...), couleur_fiche.rgb)`, canal par
// canal : sans ce plafond, la pâte D pousse un corps gris éclairé au blanc (bug réel,
// déjà payé par ISO2 en `465700a` avant même que ce shader existe).
//
// ## Effacement et silhouette — composées ensemble, comme la vue de dessus
//
// `opacite_N` (0..1) est l'opacité RENDUE du sprite que ce corps remplace (le
// brouillage du regardeur, la suie) : le corps se fond par transparence dans ce que la
// vue montre derrière lui, jamais un assombrissement — une silhouette noire sur un sol
// éclairé serait une information de PLUS, pas de moins. `silhouette_N` (vec4, SANS
// `source_color` : la couleur y est déjà en valeurs affichées) est la même chose que
// `visual_dim` empilé sur le sprite en vue de dessus — la couleur du joueur à son
// opacité, chez lui seulement. Les deux se composent par un alpha combiné
// (`a = 1 - (1-o)(1-s)`), pas l'un après l'autre : c'est la formule d'ISO2, reprise
// telle quelle plutôt que réinventée avec un risque de diverger.
//
// ## Pas de conversion sRGB
//
// Sous `gl_compatibility`, ce shader travaille déjà en valeurs AFFICHÉES — une bascule
// vers le linéaire pour « composer comme la 2D » a déjà coûté un aller-retour faux à
// ISO2 (silhouette sortie à 21/39/52 pour 87/111/126 attendus, l'attendu à la puissance
// 2,2 — leur banc l'a mesuré). Composé tel quel, sans rien convertir.
//
// ## La passe de profondeur
//
// Neuf boîtes se recouvrent par corps ; sans une passe de profondeur, deux boîtes
// semi-transparentes superposées s'assombrissent deux fois au lieu d'une (mesuré par
// ISO2 sur son propre corps à une seule pièce mobile : 0,75 d'opacité effective pour
// 0,5 demandé). `voxel_corps.gd` construit, pour chaque boîte visible, un double en
// `corps_iso_profondeur.gdshader` — même maillage, `render_priority -1`, `ALPHA 0` — sans
// qu'aucun appelant n'ait à le demander.
//
// ## L'encre des arêtes (ISO3 vague 5, contrat d'« ISO7 Beauté Opus »)
//
// `pate_encre_boite()` (`iso_pate.gdshaderinc`) donne, pour chaque fragment, un facteur dans
// `[encre_reste, 1]` sur les quatre bords de la face rendue — 1 loin d'un bord. Posé par
// `pate_facteur(c, f)`, PAS `c *= f` : un facteur écrit dans ce shader se VOIT à l'écran comme
// f^2,4 (mesuré au banc par ISO7 Beauté, 2026-09-15 — une encre de 0,25 tombait un pixel à
// 28/255 jusqu'à 1/255, pas 7/255) ; `pate_facteur` passe par la valeur affichée pour que le
// facteur se voie tel qu'il est écrit. `encre_arete = 0.0` (le défaut) rend le facteur
// toujours 1 : rien ne change tant que personne ne règle une largeur — ce banc, la suite et
// tout appelant déjà écrit restent identiques à avant cette vague. `demi = abs(VERTEX)` est
// correct ici parce que `voxel_corps.gd`/`voxel_objets.gd` posent des `BoxMesh` à leur vraie
// taille (jamais un cube unité mis à l'échelle) et ne les subdivisent jamais — tous les sommets
// sont des coins. Posé APRÈS le plafond de fiche et AVANT la composition opacité/silhouette :
// l'encre touche la couleur rendue, jamais `silhouette_N` (la couleur du joueur à son opacité,
// chez lui, ne doit rien à la pâte).

#include "res://iso_pate.gdshaderinc"
#include "res://iso_lightmap.gdshaderinc"
#include "res://iso_corps_portrait.gdshaderinc"
#include "res://iso_corps_mannequin.gdshaderinc"
// ISO13 — le personnage détaillé à l'essai (`--corps-detaille`) : compilé seulement dans la variante CORPS_DETAIL.
#include "res://iso_corps_detail.gdshaderinc"

uniform vec4 couleur_fiche : source_color = vec4(0.5, 0.53, 0.57, 1.0);
uniform float lumiere_recue : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D capteur_1 : source_color, filter_linear, repeat_disable;
uniform sampler2D capteur_2 : source_color, filter_linear, repeat_disable;
uniform bool capteur_actif = false;
uniform vec2 centre = vec2(0.0);           // position 2D du joueur, en PIXELS, posée à chaque image
uniform float monde_capteur_px = 128.0;    // CapteurCorps.MONDE_PX
uniform float rayon_lu_px = 15.0;          // RAYON_CORPS_PX + 1, plafonné à RAYON_PX - 3
// Trouvé par ISO2 au banc du jeu réel (ISO3a, H-ISO2 après-coup) : la rétrodiffusion
// qui trahit le porteur sous sa PROPRE torche vit dans un anneau étroit du disque du
// capteur (~12-18 px pour leur corps grossier), pas au centre — le torse l'arrête. Un
// corps voxel, large de 5-6 px seulement, reste alors entièrement DANS l'ombre de son
// propre torse : chaque fragment lit trop près du centre pour jamais atteindre l'anneau
// éclairé, et le porteur reste noir dans sa propre vue — un vrai écart d'équité, pas un
// défaut de ce shader (`corps_grossier_iso.gdshader` d'ISO2 lit le même capteur et
// sort à 191 dans la même scène). `echelle_lecture` (identité à 1.0, jamais devinée ici)
// dilate le DÉCALAGE lu — donc l'empreinte du disque que chaque fragment couvre — sans
// toucher `centre` ni `rayon_lu_px` : l'appelant la règle d'après le rapport entre le
// rayon réellement éclairé et le demi-encombrement au sol de SON corps (le banc la
// laisse à 1.0, chaque classe y a un encombrement différent, jamais deviné ici).
uniform float echelle_lecture = 1.0;
// ISO3a (iso2-vues, 2026-09-15) — où, dans le disque du capteur, un fragment lit sa lumière : 0, à sa
// propre distance du centre (dilatée par `echelle_lecture`) ; 1, AU BORD DU DISQUE LU, dans sa
// direction — là où le sprite de la vue de dessus montre son croissant éclairé. ⚠️ `echelle_lecture` n'a
// pas suffi au banc du jeu réel : à 1,81, le porteur restait à 0/0/0 sous sa propre torche dans la vue
// adverse — la tête et le torse, près de l'axe, lisent encore l'ombre centrale, et les flancs que la
// caméra voit sont ceux du dos quand la torche regarde au nord. Lu au bord, chaque point de la surface
// prend la lumière du sprite dans sa direction : côté lampe clair, dos sombre, et la rétrodiffusion
// trahit le porteur comme en vue de dessus. Indépendant de `echelle_lecture` à 1 (la direction ne change
// pas sous une dilatation).
uniform float lecture_au_bord : hint_range(0.0, 1.0) = 0.0;

uniform float opacite_1 = 1.0;
uniform float opacite_2 = 1.0;
uniform vec4 silhouette_1 = vec4(0.0);
uniform vec4 silhouette_2 = vec4(0.0);

// Le pont entre le repère de `monde.xz` (tuiles ou pixels selon qui pose le corps) et
// celui du capteur (toujours des pixels 2D) — jamais une constante en dur : ISO3a
// accroche le corps sous un `Node3D` déjà à l'échelle des pixels (`monde.xz` y est
// donc déjà en pixels, d'où le défaut 1.0, l'identité) ; ce banc, lui, garde ses
// corps en tuiles et pose 35.0 (`CandelaTileSet.TILE_SIZE.x`) explicitement. Une
// conversion écrite ici aurait doublé l'échelle le jour où ISO3a l'aurait appliquée
// une seconde fois par-dessus la sienne (signalé par ISO2 avant que ça n'arrive).
uniform float pixels_par_unite : hint_range(0.0, 1000.0) = 1.0;

// ISO3 vague 5 — largeur de l'encre d'arête, en unités de `monde` (des pixels sous
// l'ancre de Presentation3D, des tuiles ici). 0.0 = aucun effet (défaut). `encre_reste` :
// la valeur du facteur SUR le trait — voir `pate_encre_boite()`.
uniform float encre_arete = 0.0;
uniform float encre_reste = 0.35;

// ISO7b — le MODELÉ des corps, tenu par la CAMÉRA : dessus 1,15, face sud 0,9, toutes les autres faces à 1. Au lacet 0
// seuls le dessus et la face sud se voient, et leur écart donne le volume ; la moyenne des faces vues reste la lumière du
// capteur, qui reste la seule vérité d'équité (un corps noir reste noir). Posé par `pate_facteur`, après le plafond de
// fiche et avant l'encre — jamais sur l'opacité ni la silhouette. `modele = 0` (défaut) : aucun effet.
// ⚠️ **Plus aucune lecture du gradient de la lightmap** (décision de la session cloud, 2026-09-15 14:21). Le côté lampe
// à 1,25 et le dos au plancher venaient de ce gradient, qui lit le BORD d'une tache de lumière et non la direction de
// sa source (au banc des faces : 0,67 rasante contre 0,70 de face à 3 tuiles, inversé à 1 tuile) — un corps qui
// traversait un cône voyait son côté clair sauter.
uniform float modele : hint_range(0.0, 1.0) = 0.0;

varying vec3 monde;
varying vec3 local;             // VERTEX, repère du modèle — voir `pate_encre_boite()`
varying vec3 demi;              // abs(VERTEX), constant par sommet sur nos BoxMesh
varying vec3 echelle;           // longueur des colonnes de MODEL_MATRIX
varying vec3 normale_locale;    // NORMAL, repère du modèle
varying vec3 normale_monde;     // ISO7b — NORMAL dans le monde : un corps tourne

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
	demi = abs(VERTEX);
	echelle = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	normale_locale = NORMAL;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// ISO7b — le facteur de modelé d'une face de normale `n` (monde). Miroir : `IsoMateriaux.modele_du_corps`.
// ⚠️ **Le modelé RÉPARTIT la lumière du capteur, il ne la retire pas** (session cloud, 12:30 puis 12:50) : un modelé
// qui laissait dessus et face sud à 1 ne se voyait pas (75 → 75), la caméra au lacet 0 ne voyant QUE ces deux faces.
float modele_du_corps(vec3 n) {
	if (n.y > 0.5) {
		return 1.15;
	}
	if (n.z > 0.5 && abs(n.y) <= 0.5) {
		return 0.9;
	}
	return 1.0;
}

// Miroir de `lumiere_recue()` dans `corps_grossier_iso.gdshader` — même borne au
// disque, même lecture par vue.
vec3 lumiere_du_capteur(bool deux, vec2 decalage_px) {
	float r0 = length(decalage_px);
	if (r0 > 0.0001) {
		decalage_px *= mix(r0, rayon_lu_px, lecture_au_bord) / r0;
	}
	float r = length(decalage_px);
	if (r > rayon_lu_px) {
		decalage_px *= rayon_lu_px / r;
	}
	vec2 uv = vec2(0.5) + decalage_px / monde_capteur_px;
	return deux ? texture(capteur_2, uv).rgb : texture(capteur_1, uv).rgb;
}

void fragment() {
	bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);
	vec2 motif = vec2(monde.x + monde.z, -monde.y);
	float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);
	float px_monde = max(max(fwidth(monde.x), fwidth(monde.y)), fwidth(monde.z));
	// ISO12 — l'aspect des corps d'après les dix portraits (`iso_corps_portrait.gdshaderinc`) : la couleur du portrait AU
	// fragment, posée plus bas sur la lumière déjà rendue (`portrait_teindre`). Sans portrait, rien ne change.
	vec3 fiche = portrait_fiche(couleur_fiche.rgb, local, demi, echelle, normale_locale, monde * pixels_par_unite,
		pixels_par_unite);
#ifdef CORPS_DETAIL
	// ISO13 — les accessoires modelés et la matière peinte : la fiche seule, assombrie jamais éclaircie.
	fiche = detail_fiche(fiche, local, demi, echelle, normale_locale, pixels_par_unite, px_monde);
#endif

	vec3 c;
	// ISO13 — la lumière reçue par le corps (fiche × lumière, avant la pâte) : le fondu du mannequin.
	float niveau = 0.0;
	if (capteur_actif) {
		vec2 monde_px = monde.xz * pixels_par_unite;
		// Nommée `capteur_rgb` et non `lumiere` : `iso_lightmap.gdshaderinc` (inclus plus
		// haut) déclare déjà un uniform `lumiere` pour son usage propre (sol/murs) — une
		// variable locale du même nom lève une erreur de compilation shader (trouvée à
		// cette étape, silencieuse dans le reste de la suite headless).
		vec3 capteur_rgb = lumiere_du_capteur(deux, (monde_px - centre) * echelle_lecture);
		float recue = pate_luminance(capteur_rgb);
		vec3 base = couleur_fiche.rgb * capteur_rgb;
		niveau = pate_luminance(base);
		c = min(pate(base, pate_luminance(base), style, motif, vec2(0.0), recue, aa), base);
	} else {
		vec3 base = couleur_fiche.rgb * lumiere_recue;
		float l = pate_luminance(base);
		niveau = l;
		c = (l <= 0.0) ? vec3(0.0) : pate(base, l, style, motif, vec2(0.0), l, aa);
		c = min(c, base);
	}
	// Le plafond général : jamais plus clair que la fiche, quelle que soit la pâte.
	c = min(c, couleur_fiche.rgb);
	// ISO7b — le modelé : la lumière du capteur répartie sur les faces que la caméra voit. Re-plafonné à la fiche : le
	// dessus monte à 1,15, jamais au-delà de la couleur de la classe.
	if (modele > 0.5) {
		c = min(pate_facteur(c, modele_du_corps(normale_monde)), couleur_fiche.rgb);
	}
	// ISO13 — le mannequin (`iso_corps_mannequin.gdshaderinc`) : le côté dos à la lumière qui éclaire vraiment ce corps
	// s'assombrit, jamais rien ne s'éclaire, et rien sous le seuil de lumière. Sans `--mannequin`, rien ne change.
	// La caméra dit quelles faces elle voit (ISO13, 04:38) : `INV_VIEW_MATRIX[2]` pointe vers elle, jamais « sud » en dur.
	c = mannequin_modeler(c, normale_monde, niveau, INV_VIEW_MATRIX[2].xz);
	// L'encre des arêtes (ISO3 vague 5) : `pate_facteur`, jamais `c *=` nu — mesuré
	// au banc par ISO7 Beauté (2026-09-15), un facteur écrit ici se VOIT à l'écran
	// comme f^2,4 (une encre de 0,25 tombait à 1/255, pas à 7/255) ; `pate_facteur`
	// passe par la valeur affichée pour que le facteur se voie tel qu'il est écrit.
	// Un noir déjà nul le reste (0 → 0, garanti par `pate_facteur`). Jamais sur
	// `silhouette_N`, composée après, plus bas.
	c = pate_facteur(c, pate_encre_boite(local, demi, echelle, normale_locale, encre_arete, encre_reste, px_monde));
	// Gardé : sans le drapeau, même un facteur de 1 ferait un aller-retour par l'espace affiché (exact à 1e-7, pas au bit ;
	// remarque d'Iso 1, 00:58). Le jeu par défaut est inchangé par construction.
	if (mannequin >= 0.5) {
		c = pate_facteur(c, mannequin_segments(local, demi, echelle, normale_locale, pixels_par_unite, px_monde, niveau));
	}
	// ISO12 — le portrait TEINT la lumière que la pâte a rendue sur le gris de la classe, encre comprise, sans jamais décider où
	// elle se voit (`portrait_teindre`) : les seuils de visibilité restent ceux d'hier, à toute lumière. ⚠️ APRÈS l'encre :
	// posée avant, la teinte laissait l'encre (un facteur en valeur décodée, canal par canal) assombrir moins le rouge d'un ocre
	// que le gris, aux faibles lumières — un bord gris à (3, 4, 5) sortait peint à (9, 3, 0) (banc des corps, 2026-09-23 03:26).
	c = portrait_teindre(c, fiche, couleur_fiche.rgb);
	c = mannequin_borner(c);

	float o = clamp(deux ? opacite_2 : opacite_1, 0.0, 1.0);
	vec4 silhouette = deux ? silhouette_2 : silhouette_1;
	float s = clamp(silhouette.a, 0.0, 1.0);
	float a = 1.0 - (1.0 - o) * (1.0 - s);
	if (a <= 0.0001) {
		discard;
	}
	ALBEDO = (c * o * (1.0 - s) + silhouette.rgb * s) / a;
	ALPHA = a;
}
