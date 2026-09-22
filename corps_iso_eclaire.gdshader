shader_type spatial;
render_mode cull_back, fog_disabled, blend_mix, depth_draw_always;

// ISO12, lot 0 — LE CORPS ÉCLAIRÉ : `corps_iso.gdshader` passé à la lumière 3D, derrière le drapeau `Presentation3D.lumiere_3d`.
//
// La couleur n'est plus « la fiche × le capteur, passée à la pâte » mais `lumière 3D × albédo`, et l'albédo porte la BRIDE :
// `smoothstep(bride_bas, bride_haut, L2D)`, L2D étant le capteur d'ISO2/ISO3 lu au fragment, comme avant. Un corps que la
// lightmap de la vue ne montre pas reste noir, quelle que soit la lumière 3D. Le modelé d'ISO7b tenu par la caméra n'a
// plus d'objet (la matière pose `modele` à 0) : les faces prennent la direction de la vraie lampe.
// ⚠️ **La silhouette de soi et l'effacement restent un terme d'ÉMISSION par vue** (décision de la session cloud, 22:15) :
// `silhouette_N` passe en EMISSION, jamais par light(). Dans le noir complet, torche éteinte, ma silhouette se voit dans ma
// vue et pas dans celle de l'autre — le banc le prouve par une case.
// Variantes : `variante_pate` 0 = (a) la bride en paliers ; 1 = (c) continue. `masque_preuve` 1 = blanc là où L2D > 0.
// Le texte d'ISO3 à ISO7b suit, inchangé sauf au calcul de la couleur et à la composition finale.

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
#include "res://iso_relief.gdshaderinc"
#include "res://iso_corps_portrait.gdshaderinc"

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

// ISO12 — la bride et ses variantes.
uniform float bride_bas : hint_range(0.0, 1.0) = 0.0;
uniform float bride_haut : hint_range(0.0, 1.0) = 0.05;
uniform int variante_pate = 0;
uniform int masque_preuve = 0;
// ISO12, lot 0 ter — la bride SUIT LE GRADIENT 2D (session cloud, 00:25). 0 : smoothstep(bride_bas, bride_haut, L2D) ; 1 : identité,
// L2D × bride_echelle plafonné à 1 — l'intensité de la 3D suit celle de la 2D, l'énergie 3D étant recalibrée derrière.
uniform int bride_mode = 0;
uniform float bride_echelle = 1.0;

float bride_valeur(float l) {
	if (bride_mode == 1) {
		return clamp(l * bride_echelle, 0.0, 1.0);
	}
	return smoothstep(bride_bas, bride_haut, l);
}
// ISO12, lot 0 ter — la lumière du corps par sa PROPRE lampe, en émission : la couleur bridée du corps (qui lit son capteur, donc
// sa rétrodiffusion telle que la 2D la montre), × ce gain, visible des deux vues. Une light() posée dans le corps l'éclairait par
// l'intérieur, dot(N, L) négatif sur toutes ses faces : J2 vu de loin restait noir en 3D, gris en 2D.
uniform float gain_corps_propre = 0.0;
// ISO12, lot 0 quater — LE COUP UN du diagnostic : la bride du corps forcée à 1, éteinte par défaut, jamais une règle.
// `bride_mode`/`bride_echelle` ne savent pas le faire : quand le capteur est noir, L2D vaut 0 et tout multiple de 0 reste
// 0. Si le corps s'allume ainsi, c'est la LECTURE de L2D qui est en cause, pas la lumière 3D.
uniform bool bride_forcee = false;

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

	// ISO12 — la lumière reçue au fragment (le capteur, ou son repli scalaire), puis sa bride.
	float recue;
	if (capteur_actif) {
		vec2 monde_px = monde.xz * pixels_par_unite;
		// Nommée `capteur_rgb` et non `lumiere` : `iso_lightmap.gdshaderinc` déclare déjà un uniform `lumiere`.
		vec3 capteur_rgb = lumiere_du_capteur(deux, (monde_px - centre) * echelle_lecture);
		recue = pate_luminance(capteur_rgb);
	} else {
		recue = lumiere_recue;
	}
	float b = bride_forcee ? 1.0 : bride_valeur(recue);
	vec3 base = couleur_fiche.rgb * b;
	vec3 c = (variante_pate == 1 || b <= 0.0) ? base
		: min(pate(base, pate_luminance(base), style, motif, vec2(0.0), b, aa), base);
	// Le plafond général : jamais plus clair que la fiche, quelle que soit la pâte.
	c = min(c, couleur_fiche.rgb);
	// ISO7b — le modelé : la lumière du capteur répartie sur les faces que la caméra voit. Re-plafonné à la fiche : le
	// dessus monte à 1,15, jamais au-delà de la couleur de la classe.
	if (modele > 0.5) {
		c = min(pate_facteur(c, modele_du_corps(normale_monde)), couleur_fiche.rgb);
	}
	// ISO12 — le portrait TEINT la lumière que la pâte a rendue sur le gris de la classe, sans jamais décider où elle se voit
	// (`portrait_teindre`) : les seuils de visibilité restent ceux d'hier, à toute lumière.
	c = portrait_teindre(c, fiche, couleur_fiche.rgb);
	// L'encre des arêtes (ISO3 vague 5) : `pate_facteur`, jamais `c *=` nu — mesuré
	// au banc par ISO7 Beauté (2026-09-15), un facteur écrit ici se VOIT à l'écran
	// comme f^2,4 (une encre de 0,25 tombait à 1/255, pas à 7/255) ; `pate_facteur`
	// passe par la valeur affichée pour que le facteur se voie tel qu'il est écrit.
	// Un noir déjà nul le reste (0 → 0, garanti par `pate_facteur`). Jamais sur
	// `silhouette_N`, composée après, plus bas.
	c = pate_facteur(c, pate_encre_boite(local, demi, echelle, normale_locale, encre_arete, encre_reste, px_monde));

	float o = clamp(deux ? opacite_2 : opacite_1, 0.0, 1.0);
	vec4 silhouette = deux ? silhouette_2 : silhouette_1;
	float s = clamp(silhouette.a, 0.0, 1.0);
	float a = 1.0 - (1.0 - o) * (1.0 - s);
	if (a <= 0.0001) {
		discard;
	}
	if (masque_preuve == 1) {
		// La silhouette de soi est visible en 2D sans lumière (`visual_dim`) : le masque la montre, sinon la preuve la compte
		// comme une fuite (premier banc complet, 23:25).
		ALBEDO = vec3(0.0);
		EMISSION = vec3(max(step(0.0005, recue), step(0.0001, s)));
		// Le même alpha que le rendu : un corps qui s'efface laisse voir le sol derrière lui, et le masque de ce sol avec lui
		// (troisième preuve rejouée, 23:55).
		ALPHA = a;
	} else {
		// La couleur éclairée par la lampe, la silhouette de soi en émission : les deux composées par le même alpha
		// qu'avant (`a = 1 - (1-o)(1-s)`), mais seule la première passe par light().
		ALBEDO = c * o * (1.0 - s) / a;
		EMISSION = (silhouette.rgb * s + c * o * (1.0 - s) * gain_corps_propre) / a;
		ALPHA = a;
	}

	// ISO12 v27 — le dénominateur du relief : calculé ici (sans ombre, sur la liste fermée des lampes) parce que `light()` ne
	// voit aucune variable de `fragment()`, et transporté vers lui par ce canal. Posé après les deux branches, donc dans les
	// deux cas.
	SPECULAR = relief_encoder(monde);
}

// ISO12 v27 — le relief normalisé, sans spéculaire.
void light() {
	// ISO12 v27 — LE RELIEF : le numérateur (ce qu'on accumulait ici, l'ombre portée par ATTENUATION) divisé par le
	// dénominateur commun, calculé sans ombre dans `fragment()` et transporté par SPECULAR. Le rapport vaut 1 sur un sol plat,
	// quel que soit le nombre de lampes, et moins dans l'ombre : l'intensité vient de la 2D (ALBEDO porte déjà albédo × L2D),
	// la 3D n'apporte que le modelé.
	//
	// ⚠️ **« Plus sur une face tournée vers la lampe » n'est vrai que sous une lampe RASANTE** (calculé, 2026-09-16). Le mur
	// croise le sol à dot(haut, L) ≈ 0,707 — exactement le régime d'une torche visant le sol à 45°. Sous une lampe plus haute
	// le mur lit MOINS que le sol (0,667 à 150 px de hauteur, 0,500 à 200), et sous une lampe basse il sature : R brut 4,98 à
	// 10 px, 4,00 à 25, 2,00 à 50, tous ramenés à `relief_max`. L'écrêtage n'est donc pas théorique, et il s'applique PAR
	// LAMPE — et ce dépassement est CHIFFRÉ : sur le cadrage cumulé (fusée posée entre deux torches), un mur face à la fusée
	// rend 0,16 + 1,50 (écrêté de 4,04) + 0,00 = **1,659**, soit ~11 % au-dessus de `relief_max`. Le maximum visible suit donc
	// le plafond sans lui être égal.
	//
	// Qu'un mur lise MOINS que le sol sous une lampe haute est le MODELÉ VOULU (tranché le 2026-09-16) : une face tournée de
	// côté reçoit moins d'une lampe placée au-dessus, c'est Lambert, et c'est ce que la 2D ne sait pas dire. La « flaque » du
	// défaut deux était un sol trop CLAIR, jamais un mur trop sombre.
	//
	// ⚠️ Ce `light()` n'écrit JAMAIS SPECULAR_LIGHT, et c'est ce qui éteint la passe spéculaire du moteur maintenant que
	// `specular_disabled` a sauté. Le supprimer rallumerait les reflets.
	DIFFUSE_LIGHT += relief_contribution(LIGHT_COLOR, ATTENUATION, dot(NORMAL, LIGHT), SPECULAR_AMOUNT);
}
