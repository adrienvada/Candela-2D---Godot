// ISO12 v27 — LE DÉNOMINATEUR DU RELIEF : ce que les lampes donneraient AU MÊME POINT SUR UN SOL PLAT, sans ombre.
//
// `light()` accumule le numérateur (LIGHT_COLOR × ATTENUATION × dot(NORMAL, LIGHT), l'ombre étant portée par ATTENUATION).
// Le dénominateur, lui, ignore les ombres et se calcule ici, dans `fragment()`, depuis la liste FERMÉE du miroir
// (`LumieresIso.decrire_pour_relief`). Le rapport des deux est le relief : 1 sur un sol plat, plus sur une face tournée vers la
// lampe, moins dans l'ombre.
//
// ⚠️ Le dénominateur doit porter sur LES MÊMES lampes que celles que le moteur fait passer dans `light()` — huit au plus par
// objet (`rendering/limits/opengl/max_lights_per_object`). L'appelant trie par intensité décroissante et n'en pose que huit.
//
// La courbe d'atténuation recopie celle de Godot à quelques pour cent près : R doit valoir « environ 1 » sur un sol plat, pas
// exactement 1. Une erreur de courbe se voit comme un modelé un peu plus ou un peu moins marqué, jamais comme une fuite.

uniform int relief_nb = 0;
uniform vec4 relief_pos_intensite[8];   // xyz : position monde ; w : énergie × luminance de la couleur
uniform vec4 relief_portee_cone[8];     // x : portée ; y : cos(demi-angle), < 0 pour une omni ; z : exposant d'atténuation ; w : exposant de cône
uniform vec4 relief_direction[8];       // xyz : direction du spot (vers l'avant)
// ⚠️ Sans ce plancher, une lampe rasante (dot(haut, L) proche de 0) ferait exploser R. 0,2 : les torches visent le sol à 45°,
// où dot(haut, L) vaut environ 0,7 en régime.
uniform float relief_epsilon = 0.2;
// « Ni plus » borné sur les faces ; « ni moins » reste libre dans les ombres.
uniform float relief_max = 1.5;
// L'ÉCHELLE DU CANAL : le dénominateur voyage de `fragment()` à `light()` dans SPECULAR, qui vit dans [0 ; 1] — il faut donc
// le diviser par une borne, et tout ce qui la dépasse se lit COMME ELLE.
//
// ⚠️ **Ce n'est pas un réglage d'image, c'est une borne d'encodage, et la choisir trop basse fabrique le défaut qu'on
// soigne.** Première valeur : 8,0, posée avant d'avoir les grandeurs. Or `LumieresIso.energie_par_type` donne 52,0 à une fusée
// (3,6 à une torche), soit un pic de dénominateur d'environ **36 pour une seule fusée** contre 2,5 pour une torche. À 8,0,
// `light()` aurait donc divisé par 8 au lieu de 36 autour de chaque fusée : un relief multiplié par 4,5, collé au plafond
// `relief_max`, **un disque blanc et plat — le défaut même que la v27 doit guérir**. Et invisible en recette : les cadrages à
// la seule torche auraient mesuré (a) ≈ 1,0 et conclu au succès.
//
// 256 et non 36 : le dénominateur ADDITIONNE les lampes, et c'est là où elles se cumulent (la flaque, le halo de fusée) que
// tout se joue. Il reste sept fois le pic d'une fusée. Le canal garde sa précision : une torche seule vaut 2,5/256 ≈ 0,01,
// soit plus de trois chiffres utiles.
uniform float relief_denominateur_max = 256.0;

float relief_denominateur(vec3 monde_px) {
	vec3 haut = vec3(0.0, 1.0, 0.0);
	float d_total = 0.0;
	for (int i = 0; i < relief_nb; i++) {
		vec3 vers = relief_pos_intensite[i].xyz - monde_px;
		float d = length(vers);
		float portee = relief_portee_cone[i].x;
		if (d > portee) {
			continue;
		}
		vec3 L = vers / max(d, 0.0001);
		float att = pow(max(1.0 - d / max(portee, 0.0001), 0.0), max(relief_portee_cone[i].z, 0.01));
		float cone = 1.0;
		float cos_demi = relief_portee_cone[i].y;
		if (cos_demi >= 0.0) {
			float c = dot(-L, normalize(relief_direction[i].xyz));
			cone = c < cos_demi ? 0.0 : pow(smoothstep(cos_demi, 1.0, c), max(relief_portee_cone[i].w, 0.01));
		}
		d_total += relief_pos_intensite[i].w * att * cone * max(dot(haut, L), relief_epsilon);
	}
	return d_total;
}

// Le canal : `fragment()` encode D dans SPECULAR, `light()` le relit dans SPECULAR_AMOUNT.
// ⚠️ Les shaders doivent alors PERDRE `specular_disabled`, sinon SPECULAR n'est pas transmis. Aucun reflet ne revient pour
// autant, mais **pas** parce que SPECULAR est écrit partout : c'est le `light()` PERSONNALISÉ, qui n'écrit jamais
// SPECULAR_LIGHT, qui éteint la passe spéculaire du moteur. Qui supprimerait `light()` rallumerait les reflets du même geste.
float relief_encoder(vec3 monde_px) {
	return clamp(relief_denominateur(monde_px) / max(relief_denominateur_max, 0.0001), 0.0, 1.0);
}

// Dans `light()` : la contribution d'une lampe, déjà divisée par le dénominateur commun.
// ⚠️ Le plafond s'applique PAR LAMPE et non à R total : un shader spatial n'offre aucun point après la boucle des lampes. À
// vérifier au banc sur une face très inclinée sous deux lampes.
vec3 relief_contribution(vec3 lumiere, float attenuation, float n_dot_l, float specular_amount) {
	vec3 lambert = lumiere * attenuation * max(n_dot_l, 0.0);
	// ⚠️ DÉNOMINATEUR VIDE : le miroir ne connaît aucune lampe ici (hors de toutes les portées, ou `relief_nb == 0`) alors que
	// le moteur éclaire quand même ce fragment. Sans cette garde, `d_total` tomberait sur son plancher et CHAQUE lampe rendrait
	// le plafond — un aplat blanc à `relief_max`, qu'on lirait comme un relief cassé au lieu d'une liste vide. Le neutre est le
	// Lambert d'avant la v27 : le rendu redevient celui d'hier, jamais un débordement.
	float d_total = specular_amount * relief_denominateur_max;
	if (d_total <= 0.0001) {
		return lambert;
	}
	return min(lambert / d_total, vec3(relief_max));
}
