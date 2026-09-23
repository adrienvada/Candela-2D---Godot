// ISO12 — L'ASPECT DES CORPS D'APRÈS LES DIX PORTRAITS DE CLASSE (chantier d'ISO7 Beauté, 2026-09-22, brief de la
// session cloud).
//
// Les corps voxel étaient des aplats gris ; les dix portraits (ISO Assets, `docs/iso/planches_gemini/habillage/
// portrait_<classe>.png`) montrent un plâtre OCRE patiné de rouille et de brun sur les arêtes et vers le bas, l'encre
// sombre des arêtes, une bandoulière, une ceinture et une poche, une bouteille dans le dos pour six classes, des
// cartouches grises (le Fumiste) ou rouges (l'Incendiaire). Cet include rend cette peinture en ALBÉDO SEUL :
//
// - `portrait_fiche()` rend la couleur du portrait AU FRAGMENT ; `portrait_teindre()` la pose sur la lumière que le
//   fragment a DÉJÀ rendue sur le gris de sa classe (pâte, plafond, modelé et encre compris), en dernier : la couleur rendue
//   prend la teinte du portrait, et sa clarté à l'écran est celle du gris, pixel par pixel.
// - ⚠️ **Le portrait ne décide jamais OÙ la lumière se voit.** Une première forme posait la couleur du portrait À LA
//   PLACE du gris, avant la pâte : un plâtre plus clair que le gris franchissait plus tôt les seuils de la pâte D, et au
//   banc des corps (2026-09-23, 00:34) un Spectre sous 0,06 de lumière se voyait peint là où le gris était noir, tandis
//   qu'à 0,15 le Braconnier et le Parasite sortaient plus sombres qu'aujourd'hui (0,97 et 0,93). Teinte après la pâte,
//   un corps est visible exactement où il l'était, à toute lumière — la rétrodiffusion des furtifs comprise.
// - Noir absolu : une lumière rendue nulle reste nulle (le rapport multiplie 0). Albédo seul : aucune émission, aucun
//   `light()` ; le relief d'ISO12 n'est pas touché (`tools/test_corps_portraits.gd`).
// - ⚠️ **La peinture change la COULEUR, jamais la VISIBILITÉ** (session cloud, 2026-09-23 01:49). Toutes les couleurs
//   d'une classe arrivent de `VoxelCatalogue.palette_portrait()` à la clarté exacte de son gris : la patine, la
//   rouille, les sangles et les cartouches ne jouent que sur la teinte et la saturation, et le rapport portrait / gris vaut
//   1 en chaque pixel, à toute lumière. Et sous `PORTRAIT_SEUIL_NOIR` (10/255), la teinte ne s'applique pas du tout, puis
//   arrive en fondu jusqu'à 24/255 : un pixel noir au gris l'est peint, sans que l'arrondi à quelques niveaux en décide.
// - `portrait = 0` (le défaut, et `--corps=portraits` absent) : `portrait_teindre` rend la couleur telle quelle.
//
// Les pièces se reconnaissent à la taille de leur maillage : `demi` (abs(VERTEX), la demi-taille d'une `BoxMesh`, en
// tuiles) comparé aux demi-tailles posées par `VoxelCorps`. Une seule matière pour toutes les boîtes, comme avant.

uniform float portrait : hint_range(0.0, 1.0) = 0.0;
uniform vec4 portrait_ocre : source_color = vec4(1.0);
uniform vec4 portrait_rouille : source_color = vec4(1.0);
uniform vec4 portrait_brun : source_color = vec4(1.0);
uniform vec4 portrait_bouteille : source_color = vec4(1.0);
uniform vec4 portrait_arme : source_color = vec4(1.0);
// a > 0 : la classe porte des cartouches sur sa bandoulière (grises, rouges).
uniform vec4 portrait_cartouche : source_color = vec4(0.0);
// 0 : la patine des portraits clairs ; 1 : le pistolet, l'occulteur et le spectre, plus usés.
uniform float portrait_usure : hint_range(0.0, 1.0) = 0.0;
// La hauteur d'un corps debout, en pixels du monde : la rouille monte depuis le sol.
uniform float portrait_hauteur_px = 35.0;
uniform vec3 portrait_demi_torse = vec3(0.0);
uniform vec3 portrait_demi_bouteille = vec3(0.0);
uniform vec3 portrait_demi_arme = vec3(0.0);

bool portrait_est(vec3 demi, vec3 ref) {
	return ref.x > 0.0 && all(lessThan(abs(demi - ref), vec3(0.0005)));
}

// Le masque d'un rectangle [a, b] dans les coordonnées de face.
float portrait_rect(vec2 f, vec2 a, vec2 b) {
	return step(a.x, f.x) * step(f.x, b.x) * step(a.y, f.y) * step(f.y, b.y);
}

// `fiche` : la couleur de la classe (le repli, rendu tel quel sans portrait) ; `local`, `demi`, `echelle`, `n` : ceux
// de `pate_encre_boite` ; `monde_px` : la position du fragment en pixels du monde ; `px_par_unite` : pixels par unité
// du monde (1 en jeu, 35 au banc des corps).
vec3 portrait_fiche(vec3 fiche, vec3 local, vec3 demi, vec3 echelle, vec3 n, vec3 monde_px, float px_par_unite) {
	if (portrait < 0.5) {
		return fiche;
	}
	vec3 u = local / max(demi, vec3(0.00001));
	vec3 an = abs(n);
	// Coordonnées de la face dans [-1, 1] : horizontale, verticale (sur un dessus, les deux axes du sol).
	vec2 f = an.x > 0.5 ? vec2(u.z, u.y) : (an.y > 0.5 ? vec2(u.x, u.z) : vec2(u.x, u.y));
	// La distance au bord de la face, en pixels du monde (même mesure que l'encre des arêtes).
	vec3 d = max(demi - abs(local), vec3(0.0)) * echelle * px_par_unite;
	float bord = an.x > 0.5 ? min(d.y, d.z) : (an.y > 0.5 ? min(d.x, d.z) : min(d.x, d.y));

	// LA PATINE : la rouille monte du sol et borde les arêtes, par taches (un grain accroché au monde, jamais à l'écran).
	float h = clamp(monde_px.y / max(portrait_hauteur_px, 0.001), 0.0, 1.0);
	float grain = pate_bruit(vec2(monde_px.x + monde_px.z, monde_px.y) * 0.45);
	float tache = pate_bruit(vec2(monde_px.x - monde_px.z, monde_px.y) * 0.18 + vec2(7.3, 1.9));
	float bas = 1.0 - smoothstep(0.0, mix(0.38, 0.62, portrait_usure), h);
	float au_bord = 1.0 - smoothstep(0.4, mix(2.2, 3.4, portrait_usure), bord);
	float rouille = clamp(max(bas * 0.85, au_bord * 0.75) * (0.45 + 0.9 * grain), 0.0, 1.0);
	rouille = max(rouille, smoothstep(mix(0.78, 0.62, portrait_usure), 0.95, tache) * 0.8);
	vec3 c = mix(portrait_ocre.rgb, portrait_rouille.rgb, rouille * mix(0.75, 1.0, portrait_usure));

	if (portrait_est(demi, portrait_demi_arme)) {
		// L'arme : bois et métal bruns, sans la rouille du plâtre.
		c = portrait_arme.rgb;
	} else if (portrait_est(demi, portrait_demi_bouteille)) {
		// La bouteille : pâle, cerclée de brun aux deux bouts, la vanne sombre sur le dessus, rouillée par le bas.
		c = mix(portrait_bouteille.rgb, portrait_rouille.rgb, bas * 0.4 + au_bord * 0.35);
		if (an.y <= 0.5 && abs(f.x) > 0.72) {
			c = portrait_brun.rgb;
		}
		if (an.y > 0.5 && n.y > 0.0 && length(f) < 0.35) {
			c = portrait_brun.rgb;
		}
	} else if (portrait_est(demi, portrait_demi_torse) && an.y <= 0.5) {
		// La ceinture, sur tout le tour du torse.
		float sangle = step(f.y, -0.72);
		// La bandoulière, en diagonale de l'épaule à la hanche, devant et derrière.
		float diagonale = an.z > 0.5 ? abs(f.x * 0.9 + f.y) : 9.0;
		sangle = max(sangle, step(diagonale, 0.24));
		c = mix(c, portrait_brun.rgb, sangle);
		if (portrait_cartouche.a > 0.0 && an.z > 0.5 && diagonale < 0.17) {
			// Les cartouches, en rang le long de la bandoulière.
			float s = (f.x - f.y) * 0.5;
			c = mix(c, portrait_cartouche.rgb, step(fract(s * 3.2 + 0.25), 0.55));
		}
		if (n.z < -0.5) {
			// La poche, devant, sur la hanche.
			c = mix(c, portrait_brun.rgb, portrait_rect(f, vec2(0.28, -0.7), vec2(0.82, -0.3)));
		}
	}
	return c;
}

// La lumière rendue `c` (calculée sur le gris `gris` de la classe) prend la teinte du portrait `fiche`, dans l'espace BRUT du
// fragment : c' = fiche × clarté(c) / clarté(gris). Ce shader travaille en valeurs AFFICHÉES (voir l'en-tête de
// `corps_iso.gdshader`) : l'écran montre `c` tel quel (au banc des corps, le gris d'un corps passe de 70,6 à 13,2 niveaux
// quand la lumière va de 0,8 à 0,2 — proportionnel, pâte comprise). À l'écran, la clarté du corps peint est donc celle du
// gris, pixel par pixel, à toute lumière, et le seuil du noir se lit sur la valeur que l'écran montre.
// ⚠️ **Deux autres espaces essayés, et faux au pied de l'échelle.** Dans l'espace encodé (`pate_depuis_affiche`), qui
// multiplie les petites valeurs par 12,92, le seuil ne gardait gris que les pixels déjà noirs, et 8 000 à 15 000 pixels noirs
// au gris sortaient peints de (1, 0, 0) à (8, 0, 0) à 0,1-0,2 de lumière (banc des corps, même partie, 2026-09-23 05:56 :
// l'encre et le modelé y amenaient les pixels — encre coupée, 146 au lieu de 8 894 ; corps opaque, rien de changé ; palette
// grise, 0 à 139). Dans l'espace décodé (`pate_vers_affiche`), un corps gris à pleine lumière aurait valu 3 niveaux sur 255.
// 0 reste 0 ; c ≤ gris ⇒ résultat ≤ fiche.
const float PORTRAIT_SEUIL_NOIR = 10.0 / 255.0;
const float PORTRAIT_SEUIL_TEINTE = 24.0 / 255.0;

vec3 portrait_teindre(vec3 c, vec3 fiche, vec3 gris) {
	if (portrait < 0.5) {
		return c;
	}
	float l = pate_luminance(max(c, vec3(0.0)));
	if (l < PORTRAIT_SEUIL_NOIR) {
		return c;
	}
	vec3 teinte = fiche * (l / max(pate_luminance(gris), 0.000001));
	return mix(c, teinte, smoothstep(PORTRAIT_SEUIL_NOIR, PORTRAIT_SEUIL_TEINTE, l));
}
