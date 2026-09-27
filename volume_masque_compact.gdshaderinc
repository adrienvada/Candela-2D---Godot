// ISO13, Q31 — LES FORMES MOINS CHÈRES DU MASQUE DE LA FUMÉE (session cloud « masque-fumée », 2026-09-27). Inclus par
// `volume_masque.gdshaderinc` sous `MASQUE_COMPACT` seulement : ni le jeu par défaut (masque éteint) ni `--fumee-masque`
// (le masque de Gadgets tel quel) ne compilent une ligne de ce fichier. Un drapeau, éteint par défaut
// (voir `IsoVolumes.FORMES_MASQUE`) ; les formes suivantes s'ajouteront à celle-ci, pour qu'une série attribue le prix à chaque idée.
// Aucune ne change la RÈGLE de Gadgets (« la couche se tait là où ce que le pixel montre s'affiche noir »), ni ses
// certitudes, ni le point noir : seulement combien de fois, et avec combien de code, on la calcule.
//
// - `--fumee-masque-compact` (MASQUE_COMPACT) : LA MÊME RÉPONSE, CALCULÉE PAR LE MÊME CODE, MAIS ÉCRITE UNE FOIS.
//   Un compilateur GLSL recopie une fonction à CHAQUE appel. Le masque de Gadgets appelle `sol_montre_noir_au_point` cinq
//   fois (le point, puis quatre côtés d'une couture), `face_montre_noir` trois fois et `dessus_montre_noir` deux fois :
//   compté dans le GLSL que Godot génère (session cloud, 2026-09-27, `tools/masque_fumee/compter_glsl.py`), le fragment de
//   la fumée passe de ~1 960 instructions sans masque à ~14 600 avec, dont plus de la moitié pour les cinq copies du sol.
//   Ici le parcours NOMME la surface rencontrée (sol, face ou dessus) et chacune n'est jugée qu'à un seul endroit ; les
//   côtés d'une couture passent par une boucle à nombre de tours variable (1 ou 4), qu'un compilateur ne peut pas dérouler
//   en quatre copies. Les expressions sont celles de Gadgets, dans le même ordre.


// Le sol à la manière de `sol_montre_noir` (V1c, les coutures), le point jugé à UN seul endroit : les côtés d'une couture,
// dans l'ordre de Gadgets (+e, −e, (e.x, −e.y), (−e.x, e.y)), le noir l'emporte au premier trouvé. Hors couture, un seul
// tour, sur le point lui-même (`px + 0` vaut `px` au bit près).
bool sol_montre_noir_compact(vec2 px, bool deux, float aa, float px_monde, vec2 g_x, vec2 g_y) {
	vec2 dans_tuile = fract(px / tuile_px) * tuile_px;
	float marge = joint_2d_px + 0.5;
	vec2 e = vec2(sol_couture(dans_tuile.x, px.x, marge) < SOL_COUTURE_PX ? SOL_COUTURE_PX : 0.0,
		sol_couture(dans_tuile.y, px.y, marge) < SOL_COUTURE_PX ? SOL_COUTURE_PX : 0.0);
	int n = (e.x == 0.0 && e.y == 0.0) ? 1 : 4;
	for (int k = 0; k < n; k++) {
		vec2 o = n == 1 ? vec2(0.0) : (k == 0 ? e : (k == 1 ? -e : (k == 2 ? vec2(e.x, -e.y) : vec2(-e.x, e.y))));
		if (sol_montre_noir_au_point(px + o, deux, aa, px_monde, g_x, g_y)) {
			return true;
		}
	}
	return false;
}

// Le parcours de `masque_montre_noir`, ligne pour ligne, qui NOMME la surface rencontrée au lieu de la juger sur place :
// `cible` 0 le sol, 1 une face (point `q`, normale `n_cible`), 2 un dessus (point `q`) ; `h_cible`, la hauteur du mur.
bool masque_compact_montre_noir(vec3 monde, vec3 vue, bool deux, vec3 d_x, vec3 d_y) {
	float t_sol = monde.y / max(-vue.y, 1e-3);
	vec2 a0 = (monde.xz - grille_origine_px) / tuile_px;
	vec2 dc = vue.xz * t_sol / tuile_px;
	vec2 cellule = floor(a0);
	vec2 pas = vec2(dc.x >= 0.0 ? 1.0 : -1.0, dc.y >= 0.0 ? 1.0 : -1.0);
	vec2 prochain = vec2(
		abs(dc.x) > 1e-6 ? ((dc.x > 0.0 ? cellule.x + 1.0 : cellule.x) - a0.x) / dc.x : 2.0,
		abs(dc.y) > 1e-6 ? ((dc.y > 0.0 ? cellule.y + 1.0 : cellule.y) - a0.y) / dc.y : 2.0);
	vec2 delta = vec2(abs(dc.x) > 1e-6 ? 1.0 / abs(dc.x) : 2.0, abs(dc.y) > 1e-6 ? 1.0 / abs(dc.y) : 2.0);
	vec3 haut_n = vec3(0.0, 1.0, 0.0);
	vec2 g_x = derivee_sur_plan(d_x, vue, haut_n).xz;
	vec2 g_y = derivee_sur_plan(d_y, vue, haut_n).xz;
	float aa_sol = clamp((abs(g_x.x) + abs(g_y.x) + abs(g_x.y) + abs(g_y.y)) / 6.0, 0.02, 0.5);
	float px_monde_sol = max(abs(g_x.x) + abs(g_y.x), abs(g_x.y) + abs(g_y.y));
	float s = 0.0;
	int axe = -1;
	int cible = 0;
	vec3 q = vec3(0.0);
	vec2 n_cible = vec2(0.0);
	float h_cible = 0.0;
	for (int i = 0; i < 4; i++) {
		float s_fin = min(min(prochain.x, prochain.y), 1.0);
		vec2 o = occupe(grille_origine_px + (cellule + 0.5) * tuile_px);
		float haut = o.r > 0.5 ? mur_haut_px : (o.g > 0.5 ? muret_px : 0.0);
		if (haut > 0.0) {
			float y_entree = monde.y * (1.0 - s);
			if (y_entree < haut) {
				h_cible = haut;
				if (axe < 0) {
					vec2 s_face = vec2(
						abs(dc.x) > 1e-6 ? ((dc.x > 0.0 ? cellule.x : cellule.x + 1.0) - a0.x) / dc.x : -1e9,
						abs(dc.y) > 1e-6 ? ((dc.y > 0.0 ? cellule.y : cellule.y + 1.0) - a0.y) / dc.y : -1e9);
					float s_haut = 1.0 - haut / max(monde.y, 1e-3);
					if (s_haut >= max(s_face.x, s_face.y)) {
						cible = 2;
						q = monde + vue * (t_sol * s_haut);
						break;
					}
					bool par_x = s_face.x >= s_face.y;
					cible = 1;
					n_cible = par_x ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);
					q = monde + vue * (t_sol * (par_x ? s_face.x : s_face.y));
					break;
				}
				cible = 1;
				n_cible = axe == 0 ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);
				q = monde + vue * (t_sol * s);
				break;
			}
			float s_dessus = 1.0 - haut / max(monde.y, 1e-3);
			if (s_dessus <= s_fin) {
				cible = 2;
				h_cible = haut;
				q = monde + vue * (t_sol * s_dessus);
				break;
			}
		}
		if (s_fin >= 1.0) {
			break;
		}
		if (prochain.x < prochain.y) {
			s = prochain.x;
			cellule.x += pas.x;
			prochain.x += delta.x;
			axe = 0;
		} else {
			s = prochain.y;
			cellule.y += pas.y;
			prochain.y += delta.y;
			axe = 1;
		}
	}
	if (cible == 0) {
		vec2 p_sol = monde.xz + vue.xz * t_sol;
		vec2 c_fin = floor((p_sol - grille_origine_px) / tuile_px);
		vec2 o_fin = occupe(grille_origine_px + (c_fin + 0.5) * tuile_px);
		if (!(max(o_fin.r, o_fin.g) > 0.5)) {
			return sol_montre_noir_compact(p_sol, deux, aa_sol, px_monde_sol, g_x, g_y);
		}
		vec2 bord = grille_origine_px + c_fin * tuile_px;
		float dx = pas.x > 0.0 ? p_sol.x - bord.x : bord.x + tuile_px - p_sol.x;
		float dz = pas.y > 0.0 ? p_sol.y - bord.y : bord.y + tuile_px - p_sol.y;
		cible = 1;
		n_cible = dx < dz ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);
		q = vec3(p_sol.x, 0.0, p_sol.y);
		h_cible = o_fin.r > 0.5 ? mur_haut_px : muret_px;
	}
	if (cible == 2) {
		return dessus_montre_noir(q, h_cible, deux, aa_sol);
	}
	return face_montre_noir(q, n_cible, deux, aa_sol, h_cible, px_monde_sol);
}
