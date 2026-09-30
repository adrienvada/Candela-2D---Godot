## Chantier « Gadgets en volume », GV1 — la fumée en voxels, À L'ESSAI (`--fumee-voxel-essai`, éteinte par défaut).
##
## Adrien, 2026-09-30 : « J'aimerais également que tous les gadgets (je me souviens de la fumée occultante) soient
## davantage en 3D. » La suie, la poussière et la fumée de la fusée deviennent un tas de cubes (`IsoNuageVoxel`,
## `nuage_voxel_iso.gdshader`) au lieu des couches de `volume_iso.gdshader`.
##
## Ce que cette suite prouve, sans fenêtre, sur une vraie manche iso en écran scindé, nuages posés par le VRAI chemin
## (`GameState._do_spawn_gadget`, une vraie fusée posée) :
##
## **Sans le drapeau, le jeu est celui d'avant** — les trois nuages ont leurs couches (4, 3 et 4), aucun nœud de voxels
## n'existe, et le shader des voxels n'a jamais été chargé ; le chemin des voxels n'est atteint que sous le drapeau.
##
## **Avec l'essai** —
## - chaque nuage a UNE grille de cubes par vue (un `MultiMesh` : un appel de dessin), sur le calque 3D de la caméra de
##   cette vue, qui lit SA lightmap ; les grilles sont partagées entre nuages du même type ;
## - les deux vues ont le même jeu de cellules, chacune rangée du plus loin au plus proche pour SA caméra (l'ordre du
##   peintre, sans tri) ; chacune n'a que les trois faces que sa caméra voit ;
## - dessinées AVANT les corps, sans écrire la profondeur, non éclairées, sous le pochoir du masque de la fumée, avec leur
##   juge (le plan qui écrit le pochoir) posé juste avant elles et couvrant le cylindre du nuage ;
## - la densité suit le nuage 2D : l'image et l'angle de la masse, sa vie (naissance, dissipation) ; pour la fusée, son
##   voile (volutes, trous, masses, tunnels) et ses nappes, recopiés de leur matériau, panache d'extinction compris ;
## - noir absolu dans le monde : la couleur d'un cube n'est que la lightmap lue sous lui, assombrie par ses faces et son
##   encre (facteurs ≤ 1) ; aucune `Light3D` ;
## - rejeu : une fusée de killcam a ses voxels ;
## - **les images ne sont que des images** : couper les images ne change aucune lumière 2D, aucun capteur, aucun joueur ;
##   éteindre l'essai rend les couches.
##
## Ce qu'elle ne prouve pas : le noir À L'ÉCRAN et le coût, qui ne se mesurent qu'au rendu — le banc
## `tools/banc_gadgets_volume.gd` (`--mode=noir`, `--mode=cout`) les mesure en vraie fenêtre.
##
## Lancée DEUX fois par `run_suites.sh` : sans drapeau (le défaut, puis l'essai par la bascule des bancs), et sous
## `--fumee-voxel-essai=fin` (le drapeau lu au lancement, la variante fine).
extends SceneTree

const PLANCHER := 70
const CARTE := "res://tools/cartes/murs_bas_essai.json"
const NUAGES := ["cartouche_suie", "poussiere"]

var _failures := 0
var _verifications := 0
var _drapeau := false
var _variante_du_drapeau := ""


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Le drapeau, sous toutes ses formes : nu (la variante par défaut) ou `=<variante>`.
	for arg in DrapeauxDeLancement.arguments():
		if arg == IsoVolumes.DRAPEAU_FUMEE_VOXEL:
			_variante_du_drapeau = IsoNuageVoxel.VARIANTE_PAR_DEFAUT
		elif arg.begins_with(IsoVolumes.DRAPEAU_FUMEE_VOXEL + "="):
			_variante_du_drapeau = arg.get_slice("=", 1)
	_drapeau = _variante_du_drapeau != ""
	print("=== LA FUMÉE EN VOXELS (GV1, à l'essai) — %s ===" % (("sous le drapeau, variante « %s »" % _variante_du_drapeau)
		if _drapeau else "sans drapeau"))
	await process_frame
	_le_drapeau()
	_la_grille()
	# La manche AVANT le shader : sans le drapeau, elle vérifie que le shader des voxels n'a jamais été chargé — les deux
	# contrôles du shader, eux, le chargent.
	await _dans_la_manche()
	_le_shader()
	_les_parametres_existent()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER if not _drapeau else 30],
		_verifications >= (PLANCHER if not _drapeau else 30))
	_sortir()


# ---------------------------------------------------------------------------
# LE DRAPEAU
# ---------------------------------------------------------------------------

func _le_drapeau() -> void:
	print("\n[Le drapeau : éteint par défaut, lu par la porte commune]")
	var v := IsoVolumes.new()
	if _drapeau:
		_check("sous le drapeau, l'essai est allumé dans la variante demandée (« %s »)" % _variante_du_drapeau,
			v.fumee_voxel and v.variante_voxel == _variante_du_drapeau, "%s / %s" % [str(v.fumee_voxel), v.variante_voxel])
	else:
		_check("SANS drapeau, la fumée en voxels est ÉTEINTE (le jeu d'avant)", not v.fumee_voxel)
		_check("sa variante par défaut est celle des voxels d'un quart de tuile", v.variante_voxel == "gros"
			and is_equal_approx(IsoNuageVoxel.cote_voxel("gros"), IsoVolumes.TUILE / 4.0)
			and is_equal_approx(IsoNuageVoxel.cote_voxel("fin"), IsoVolumes.TUILE / 8.0))
	v.free()
	var src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("le drapeau se lit par la porte commune des drapeaux (avant comme après --)",
		src.contains("for arg in DrapeauxDeLancement.arguments():")
		and src.contains("elif arg == DRAPEAU_FUMEE_VOXEL:\n\t\t\tfumee_voxel = true"))
	_check("le drapeau dit ce qu'il allume (une prise prouve son bras par le journal)",
		src.contains("[fumée voxel] essai allumé — voxels"))
	var gadget := _fonction_gd(src, "_suivre_gadget")
	var fusee := _fonction_gd(src, "_suivre_fusee")
	_check("le chemin des voxels n'est atteint QUE sous le drapeau (suie et poussière)",
		gadget.contains("\tif fumee_voxel and VOLUMES.has(slug) and IsoNuageVoxel.NUAGES.has(slug):\n\t\t_suivre_gadget_en_voxels(g, slug, vus)\n\telif VOLUMES.has(slug):")
		and gadget.count("_suivre_gadget_en_voxels(") == 1)
	_check("… et pour la fumée de la fusée",
		fusee.contains("\tif volumes_actifs and alpha > 0.0 and fumee_voxel:\n\t\t_suivre_fusee_en_voxels(f, vus)\n\telif volumes_actifs and alpha > 0.0:")
		and fusee.count("_suivre_fusee_en_voxels(") == 1)
	_check("aucun autre appelant des voxels dans le jeu", src.count("_suivre_nuage_voxel(") == 3
		and src.count("_suivre_gadget_en_voxels(") == 2 and src.count("_suivre_fusee_en_voxels(") == 2)
	var nuage := FileAccess.get_file_as_string("res://iso_nuage_voxel.gd")
	_check("le shader des voxels n'est chargé qu'au premier nuage en voxels (aucun preload, aucun chargement ailleurs)",
		not nuage.contains("preload(") and not src.contains('load("res://nuage_voxel_iso')
		and nuage.contains("static var _shader: Shader = null") and nuage.count("load(CHEMIN_SHADER)") == 1)


# ---------------------------------------------------------------------------
# LA GRILLE : les mêmes cellules pour les deux vues, chacune dans son ordre
# ---------------------------------------------------------------------------

func _la_grille() -> void:
	print("\n[La grille : même nuage pour les deux vues, l'ordre du peintre pour chacune]")
	var avant_j1 := IsoNuageVoxel.avant_de_lacet(45.0)
	var avant_j2 := IsoNuageVoxel.avant_de_lacet(225.0)
	var c1 := IsoNuageVoxel.cote_camera(avant_j1)
	var c2 := IsoNuageVoxel.cote_camera(avant_j2)
	_check("J1 (45°) et J2 (225°) regardent de deux côtés opposés", c1 == -c2 and c1.x != 0 and c1.y != 0,
		"%s / %s" % [str(c1), str(c2)])
	_check("au lacet 0, la caméra regarde de profil en x (aucune face x)", IsoNuageVoxel.cote_camera(IsoNuageVoxel.avant_de_lacet(0.0)).x == 0)
	for variante in ["gros", "fin"]:
		var v := IsoNuageVoxel.cote_voxel(variante)
		var rangs := IsoNuageVoxel.rangees(35.0, v)
		var a := IsoNuageVoxel.cellules(250.0, rangs, v, c1)
		var b := IsoNuageVoxel.cellules(250.0, rangs, v, c2)
		var sa := Array(a)
		var sb := Array(b)
		sa.sort_custom(_ordre_fixe)
		sb.sort_custom(_ordre_fixe)
		_check("%s : les deux vues ont le MÊME jeu de cellules (%d)" % [variante, a.size()], a.size() > 0 and sa == sb)
		_check("%s : chaque vue range ses cellules du plus loin au plus proche pour SA caméra" % variante,
			_peintre(a, avant_j1, v) and _peintre(b, avant_j2, v))
		_check("%s : l'ordre de J1 n'est pas celui de J2 (sans quoi l'un des deux peindrait à l'envers)" % variante, a != b)
		_check("%s : le dôme monte à %d rangées, jamais au-dessus d'une tuile (le masque ne parcourt que quatre cases)"
			% [variante, rangs], float(rangs) * v <= IsoVolumes.TUILE + 0.001)
		var hors := 0
		for p in a:
			if Vector2(p.x, p.z).length() > 250.0 + v * 1.5 + 0.001:
				hors += 1
		_check("%s : aucune cellule hors du cylindre du nuage" % variante, hors == 0)
		# LE DÔME : chaque rangée ne garde que son disque, celui où la densité du shader peut vivre (rayon resserré de
		# 22 % au sommet) — et le garde ENTIER : une case dont le centre y tombe est dans la grille.
		var hors_dome := 0
		var par_rangee := {}
		for p in a:
			var f := p.y / (float(rangs) * v)
			if Vector2(p.x, p.z).length() > 250.0 * (1.0 - 0.22 * f) + v * 1.5 + 0.001:
				hors_dome += 1
			par_rangee[p.y] = int(par_rangee.get(p.y, 0)) + 1
		var manquantes := 0
		var n := ceili(250.0 / v) + 1
		for iy in rangs:
			var y := (float(iy) + 0.5) * v
			var f := y / (float(rangs) * v)
			var attendues := 0
			for iz in range(-n, n):
				for ix in range(-n, n):
					if Vector2((float(ix) + 0.5) * v, (float(iz) + 0.5) * v).length() <= 250.0 * (1.0 - 0.22 * f) + v * 1.5:
						attendues += 1
			manquantes += absi(attendues - int(par_rangee.get(y, 0)))
		_check("%s : la grille est un DÔME — chaque rangée garde son disque resserré, entier, et rien au-delà (%d cases)"
			% [variante, a.size()], hors_dome == 0 and manquantes == 0 and is_equal_approx(IsoNuageVoxel.RESSERRE, 0.22),
			"%d hors du dôme, %d d'écart" % [hors_dome, manquantes])
	# La maille : les trois faces que la caméra voit, tournées vers elle.
	for cas in [[c1, avant_j1], [c2, avant_j2]]:
		var m := IsoNuageVoxel.maille(cas[0])
		var normales: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		# ⚠️ Les normales d'un `ArrayMesh` sont compressées (octaèdre) : relues à 1e-5 près, jamais à l'égalité.
		var faces: Array[Vector3] = []
		var vers_elle := true
		for n in normales:
			if not faces.any(func(f: Vector3) -> bool: return f.is_equal_approx(n) or f.distance_to(n) < 1e-3):
				faces.append(n)
			vers_elle = vers_elle and n.dot(cas[1]) < 0.0
		_check("la maille de la caméra %s : trois faces (le dessus et deux côtés), toutes tournées vers elle"
			% str(cas[0]), faces.size() == 3 and faces.any(func(f: Vector3) -> bool: return f.distance_to(Vector3.UP) < 1e-3)
			and vers_elle, str(faces))
	# Les rayons maximaux, recopiés du jeu (la grille les couvre).
	var fm := (load("res://fusee_modele.gd") as GDScript).get_script_constant_map()
	_check("le rayon maximal de la fumée de fusée est celui du modèle (RAYON_FUMEE × FUMEE_GONFLE)",
		is_equal_approx(float(IsoNuageVoxel.NUAGES["fusee"]["rayon_max"]), float(fm["RAYON_FUMEE"]) * float(fm["FUMEE_GONFLE"])))
	_check("ceux de la suie et de la poussière sont leurs rayons (92 et 168 px)",
		is_equal_approx(float(IsoNuageVoxel.NUAGES["cartouche_suie"]["rayon_max"]),
			float((load("res://gadget_suie.gd") as GDScript).get_script_constant_map()["RAYON"]))
		and is_equal_approx(float(IsoNuageVoxel.NUAGES["poussiere"]["rayon_max"]),
			float((load("res://gadget_poussiere.gd") as GDScript).get_script_constant_map()["RAYON"])))


func _ordre_fixe(a: Vector3, b: Vector3) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


## L'ordre du peintre sur une grille, pour une caméra orthographique de direction `avant` : chaque axe parcouru de son côté
## loin vers son côté proche, les rangées d'abord (Frieder, Gordon et Reynolds). Une cellule plus loin qu'une cellule déjà
## peinte, sur un axe où l'ordre la dit plus proche, serait peinte par-dessus elle.
func _peintre(cells: PackedVector3Array, avant: Vector3, v: float) -> bool:
	var sx := 0.0 if absf(avant.x) < 0.05 else signf(avant.x)
	var sz := 0.0 if absf(avant.z) < 0.05 else signf(avant.z)
	for i in range(1, cells.size()):
		var p := cells[i - 1]
		var q := cells[i]
		# La clé : rangée (du bas vers le haut : la caméra regarde vers le bas), puis z, puis x, chacun du côté loin.
		var kp := Vector3(roundf(p.y / v), -sz * roundf(p.z / v), -sx * roundf(p.x / v))
		var kq := Vector3(roundf(q.y / v), -sz * roundf(q.z / v), -sx * roundf(q.x / v))
		if kq < kp:
			return false
	return true


# ---------------------------------------------------------------------------
# LE SHADER
# ---------------------------------------------------------------------------

func _le_shader() -> void:
	print("\n[Le shader des voxels : une image, jamais une lumière]")
	var sh := IsoNuageVoxel.shader(false)
	var sf := IsoNuageVoxel.shader(true)
	_check("le shader se lit (ses uniformes existent) : gadget et fusée", _a_l_uniforme(sh, "masque")
		and _a_l_uniforme(sh, "lumiere_1") and _a_l_uniforme(sf, "trous") and _a_l_uniforme(sf, "nappe_1")
		and not _a_l_uniforme(sh, "trous"))
	var code := FileAccess.get_file_as_string(IsoNuageVoxel.CHEMIN_SHADER)
	var sans := _sans_commentaires(code)
	_check("non éclairé, mélange normal, faces arrière retirées, profondeur jamais écrite (un corps n'est jamais caché)",
		sans.contains("render_mode unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;"))
	_check("sous le pochoir du masque de la fumée, lu et jamais écrit", sans.contains("stencil_mode read, compare_not_equal, 1;")
		and not sans.contains("stencil_mode write"))
	_check("la couleur d'un cube n'est que la lightmap de SA vue lue sous lui, lissée comme celle des couches",
		sans.contains("vec3 brute = lire_lightmap(c.xz, vue_deux);") and sans.contains("vec3 lu = lumiere_lissee(c.xz, brute);")
		and sans.count("lire_lightmap(") == 2 and sans.contains("s += lire_lightmap(p + vec2(cos(t), sin(t)) * lissage_px, vue_deux);")
		and sans.contains("return s / 9.0;") and not sans.contains("CAMERA_VISIBLE_LAYERS"))
	_check("… passée à la pâte comme le sol, 0 → 0 (aucun terme additif), et NOIRE si le sol sous elle l'est (le lissage ne répand rien dans l'ombre)",
		sans.contains("vec3 col = (l <= 0.0 || pate_luminance(brute) <= 0.0) ? vec3(0.0)")
		and sans.contains(": (style == PATE_BRUTE ? lu : pate(lu, l, style, c.xz, vec2(0.0), l, 0.1));")
		and sans.contains("v_couleur = pate_facteur(col, face);") and sans.contains("v_encre = pate_facteur(col, face * encre_reste);")
		and sans.contains("ALBEDO = mix(v_couleur, v_encre, trait);"))
	_check("les faces et l'encre ne font qu'assombrir (facteurs ≤ 1)", IsoNuageVoxel.FACE_DESSUS <= 1.0
		and IsoNuageVoxel.FACE_GAUCHE <= 1.0 and IsoNuageVoxel.FACE_DROITE <= 1.0 and IsoNuageVoxel.ENCRE_RESTE <= 1.0)
	for chemin in [IsoNuageVoxel.CHEMIN_SHADER, "res://iso_nuage_voxel.gd"]:
		var s := FileAccess.get_file_as_string(chemin)
		_check("%s : aucune Light3D" % chemin.get_file(), not s.contains("Light3D.new") and not s.contains("OmniLight3D")
			and not s.contains("SpotLight3D"))
	# Le voile et les nappes, recopiés de la 2D : les lignes qui font leur alpha.
	var voile := FileAccess.get_file_as_string("res://fumee_fusee.gdshader")
	var manque: Array = []
	for ligne in ["float bord = 1.0 - smoothstep(0.30, 1.0, d);", "float densite = bord * mix(0.45, 1.0, n);",
			"densite *= smoothstep(trous[i].z * 0.35, trous[i].z, dt);",
			"float m = 1.0 - smoothstep(masse_rayon_uv * 0.45, masse_rayon_uv, dm);",
			"alpha *= (1.0 - t);", "alpha = max(alpha, t * 0.9);", "p *= 2.03;"]:
		if not voile.contains(ligne) or not code.contains(ligne):
			manque.append(ligne)
	_check("le voile de la fusée : ses lignes d'alpha, telles que fumee_fusee.gdshader les écrit", manque.is_empty(), str(manque))
	_check("les volutes du voile : mêmes graines, même dérive (la graine et l'âge au même poids)",
		voile.contains("vec2 q = UV * 3.0 + vec2(graine * 0.013, graine * 0.007);")
		and code.contains("vec2 q = uv * 3.0 + vec2(voile_graine * 0.013, voile_graine * 0.007);")
		and voile.contains("q += vec2(age * 0.03, -age * 0.02);") and code.contains("q += vec2(voile_age * 0.03, -voile_age * 0.02);"))
	var nappe := FileAccess.get_file_as_string("res://nappe_fusee.gdshader")
	_check("les nappes : les trois paliers de nappe_fusee.gdshader (0,15 / 0,45 / 0,75 pour 0,35 / 0,30 / 0,35)",
		nappe.contains("smoothstep(0.15 - w, 0.15 + w, densite) * 0.35") and nappe.contains("smoothstep(0.45 - w, 0.45 + w, densite) * 0.30")
		and nappe.contains("smoothstep(0.75 - w, 0.75 + w, densite) * 0.35")
		and code.contains("step(0.15, densite) * 0.35 + step(0.45, densite) * 0.30 + step(0.75, densite) * 0.35"))
	# Le dôme : le rayon se resserre en montant comme celui des couches ; la densité qui s'allège en montant (× 1 − 0,45 f
	# sur les couches) devient, sur les cubes, le SOMMET de chaque colonne (les bouffées) — un cube plein ou rien, pas un
	# cube à demi transparent.
	_check("le dôme des couches : le rayon se resserre de 22 % en montant, et le sommet des colonnes suit la densité et la vie",
		code.contains("float d2 = densite_2d(c.xz, 1.0 - 0.22 * f);") and code.contains("float rho = d2 * nuage_vie;")
		and code.contains("float bosse = 0.3 + 0.9 * bouffees(c.xz);")
		and code.contains("float sommet = nuage_hauteur_px * clamp(d2 * bosse, 0.0, 1.0) * vie;")
		and FileAccess.get_file_as_string("res://iso_volumes.gd").contains("var r := rayon * (1.0 - 0.22 * f)"))
	_check("le dessus des cubes n'a pas d'encre (seuls les côtés en portent)",
		code.contains("float trait = an.y > 0.5 ? 0.0 : 1.0 - smoothstep(w - aa, w + aa, bord);"))
	_check("les bouffées ne lisent jamais TIME (la killcam rejoue un âge)",
		not _sans_commentaires(code).contains("TIME") and code.contains("vec2(0.05, -0.03) * age"))
	# Le coût tenu par construction : une face collée à un voisin plein s'écrase ; seule la peau du nuage rastérise.
	_check("les faces cachées s'écrasent : un cube de pleine largeur collé à un voisin qui le couvre (dessus, ou devant)",
		sans.contains("if (!cachee && s >= 1.0) {") and sans.contains("vec3 voisin = c + NORMAL * voxel_px;")
		and sans.contains("cachee = NORMAL.y > 0.5 ? (haut >= 1.0 && v.x >= 1.0) : (v.x >= 1.0 && v.y >= haut);")
		and sans.contains("VERTEX = vec3(0.0);"))
	# La sortie avant la densité ne change aucun cube : le sommet possible le plus haut (densité pleine, d2 = 1) borne le
	# vrai sommet (d2 ≤ 1), et la même comparaison au quart de case décide des deux (sous un quart, la marche vaut 0).
	_check("… une case au-dessus du plus haut sommet possible sort AVANT de lire la densité (la part chère), sans changer un cube",
		sans.contains("if (nuage_hauteur_px * clamp(bosse, 0.0, 1.0) * vie - bas < 0.25 * voxel_px) {")
		and sans.find("if (nuage_hauteur_px * clamp(bosse, 0.0, 1.0) * vie - bas < 0.25 * voxel_px) {")
			< sans.find("float d2 = densite_2d(c.xz, 1.0 - 0.22 * f);")
		and sans.contains("haut = haut < 0.25 ? 0.0 : (haut < 0.75 ? 0.5 : 1.0);")
		and sans.contains("return haut <= 0.0 ? vec2(0.0) : vec2(s, haut);"))
	_check("… un cube vide ou caché ne lit pas la lumière (la lightmap n'est lue que dans la branche des faces vues)",
		sans.find("if (cachee) {") >= 0 and sans.find("if (cachee) {") < sans.find("vec3 brute = lire_lightmap(c.xz, vue_deux);"))
	var mat := IsoNuageVoxel.materiau("fusee", 0, 8.75, 35.0, -2)
	_check("… et un voisin hors de la grille ne cache rien : la portée posée borne toutes les rangées (rayon + 1,5 voxel)",
		is_equal_approx(float(mat.get_shader_parameter("grille_portee")), 250.0 + 1.5 * 8.75)
		and FileAccess.get_file_as_string("res://iso_nuage_voxel.gd").contains(
			"var portee := rayon * (1.0 - RESSERRE * (float(iy) + 0.5) / float(rangs)) + voxel * 1.5")
		and sans.contains("if (length(voisin.xz - nuage_centre) <= grille_portee - 0.75 * voxel_px) {"))


## `set_shader_parameter` sur un nom qu'aucun uniforme ne porte ne dit RIEN (piège du 2026-09-25) : chaque nom posé en dur
## par `iso_nuage_voxel.gd` est un uniforme du shader qui le reçoit.
func _les_parametres_existent() -> void:
	print("\n[Chaque paramètre posé sur un nuage existe dans son shader]")
	var src := FileAccess.get_file_as_string("res://iso_nuage_voxel.gd")
	var manque: Array = []
	var vus := 0
	for f: Array in [["materiau", false], ["poser_gadget", false], ["poser_fusee", true]]:
		var corps := _fonction_gd(src, String(f[0]), true)
		if corps.is_empty():
			manque.append("fonction introuvable : " + String(f[0]))
			continue
		for m in RegEx.create_from_string('set_shader_parameter\\("([A-Za-z_0-9]+)"').search_all(corps):
			vus += 1
			if not _a_l_uniforme(IsoNuageVoxel.shader(bool(f[1])), m.get_string(1)):
				manque.append("%s : %s" % [f[0], m.get_string(1)])
	for nom in IsoNuageVoxel.VOILE_MEME_NOM + IsoNuageVoxel.VOILE_PREFIXE.values() + ["nappe_1", "nappe_2", "nappe_3",
			"nappes", "nb_nappes", "voile_diametre"]:
		vus += 1
		if not _a_l_uniforme(IsoNuageVoxel.shader(true), String(nom)):
			manque.append("fusée : " + String(nom))
	for nom in IsoNuageVoxel.VOILE_MEME_NOM + IsoNuageVoxel.VOILE_PREFIXE.keys():
		vus += 1
		if not _a_l_uniforme(load("res://fumee_fusee.gdshader") as Shader, String(nom)):
			manque.append("voile 2D : " + String(nom))
	for nom in ["lumiere_1", "lumiere_2", "canevas_1_x", "canevas_1_y", "canevas_1_o", "canevas_2_x", "canevas_2_y",
			"canevas_2_o", "taille_1", "taille_2", "style"]:
		vus += 1
		if not _a_l_uniforme(IsoNuageVoxel.shader(false), nom) or not _a_l_uniforme(IsoNuageVoxel.shader(true), nom):
			manque.append("_pousser_lightmaps : " + nom)
	_check("les %d paramètres posés sur les nuages sont des uniformes de leur shader" % vus, vus >= 40 and manque.is_empty(),
		str(manque))


# ---------------------------------------------------------------------------
# DANS UNE VRAIE MANCHE
# ---------------------------------------------------------------------------

func _dans_la_manche() -> void:
	var reglages := root.get_node("GameSettings")
	var json := JSON.new()
	var lu: Dictionary = MapCodec.validate(json.data as Dictionary) \
		if json.parse(FileAccess.get_file_as_string(CARTE)) == OK else {}
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	reglages.mode_iso = true
	main._on_replay_requested()
	_check("la manche iso démarre", await _depart_fini(main))
	root.get_node("MapData").current_map_data = lu.get("data", {})
	main.rebuild_arena()
	for i in 4:
		await process_frame
	var p := root.get_node_or_null("Presentation3D")
	_check("la vue iso est allumée en écran scindé", p != null and bool(p.get("_actif")) and bool(p.get("_scinde")))
	if p == null:
		return
	var volumes: IsoVolumes = (p.get("_miroirs") as Node).get("volumes")
	if not _drapeau:
		await _sans_le_drapeau(main, p, volumes)
		volumes.poser_fumee_voxel(true, "gros")
	await _avec_l_essai(main, p, volumes)
	reglages.mode_iso = false
	main.queue_free()
	await process_frame


func _sans_le_drapeau(main: Node, p: Node, volumes: IsoVolumes) -> void:
	print("\n[Sans le drapeau : les couches d'avant, rien des voxels]")
	_check("la manche tourne sans l'essai", not volumes.fumee_voxel)
	var attendues := {"cartouche_suie": 4, "poussiere": 3}
	for i in NUAGES.size():
		var slug: String = NUAGES[i]
		var g := await _poser(main, 1, main.p2.global_position + Vector2(-140.0, 0.0), slug, 9700 + i)
		var e: Dictionary = volumes.suivi_de(g) if g != null else {}
		_check("« %s » : un volume de %d couches, comme avant" % [slug, int(attendues[slug])], not e.is_empty()
			and e["genre"] == "volume" and (e["noeuds"] as Array).size() == int(attendues[slug])
			and (e["noeuds"] as Array).all(func(n): return n is MeshInstance3D and not (n is MultiMeshInstance3D)))
	var suie_avant: Node2D = main.bullet_container.get_children().filter(
		func(n): return "slug" in n and String(n.get("slug")) == "poussiere").back()
	_check("sans le drapeau, la masse garde son dessin", suie_avant != null
		and (suie_avant.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_poussiere.png"))
	var f := await _fusee_posee(main, main.p1.global_position + Vector2(0.0, 200.0), 5.0)
	var ef: Dictionary = volumes.suivi_de(f)
	_check("la fumée de la fusée : un volume de 4 couches, comme avant", not ef.is_empty() and ef["genre"] == "fumee"
		and (ef["noeuds"] as Array).size() == 4)
	_check("aucun nœud de voxels nulle part", root.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
	_check("le shader des voxels n'a jamais été chargé", not IsoNuageVoxel.shader_charge()
		and not ResourceLoader.has_cached(IsoNuageVoxel.CHEMIN_SHADER))
	f.queue_free()
	await process_frame


func _avec_l_essai(main: Node, p: Node, volumes: IsoVolumes) -> void:
	print("\n[Avec l'essai : les nuages en voxels]")
	var voxel := IsoNuageVoxel.cote_voxel(volumes.variante_voxel)
	await process_frame
	await process_frame
	var poses := {}
	for i in NUAGES.size():
		var slug: String = NUAGES[i]
		var g := await _poser(main, 1, main.p2.global_position + Vector2(-140.0, 0.0), slug, 9750 + i)
		poses[slug] = g
		_le_nuage(main, p, volumes, g, slug, voxel)
		if slug == "cartouche_suie":
			await _la_vie_de_la_suie(main, p, volumes, g)
	# La grille est partagée : une seconde suie (de J1) prend la même.
	var s1: Node2D = await _poser(main, 1, main.p2.global_position + Vector2(-140.0, 0.0), "cartouche_suie", 9760)
	var s2: Node2D = await _poser(main, 0, main.p1.global_position + Vector2(140.0, 0.0), "cartouche_suie", 9761)
	var e1: Dictionary = volumes.suivi_de(s1) if s1 != null else {}
	var e2: Dictionary = volumes.suivi_de(s2) if s2 != null else {}
	_check("deux suies partagent leurs grilles (un nuage neuf ne coûte qu'un nœud)", not e1.is_empty() and not e2.is_empty()
		and (e1["noeuds"][0] as MultiMeshInstance3D).multimesh == (e2["noeuds"][0] as MultiMeshInstance3D).multimesh
		and (e1["noeuds"][1] as MultiMeshInstance3D).multimesh == (e2["noeuds"][1] as MultiMeshInstance3D).multimesh)
	await _la_fusee(main, p, volumes, voxel)
	await _le_rejeu(main, p, volumes)
	await _des_images_seulement(main, p, volumes)


func _le_nuage(main: Node, p: Node, volumes: IsoVolumes, g: Node2D, slug: String, voxel: float) -> void:
	_check("« %s » posé par le vrai chemin" % slug, g != null)
	if g == null:
		return
	# Figé le temps des contrôles : un nuage qui naît change d'opacité à chaque pas de physique, et la copie se fait à l'image.
	g.set_physics_process(false)
	p.call("_suivre")
	var e: Dictionary = volumes.suivi_de(g)
	var ok: bool = not e.is_empty() and e["genre"] == "nuage_voxel" and (e["noeuds"] as Array).size() == 2
	_check("« %s » : une grille de cubes PAR VUE (deux en écran scindé), plus son juge — trois nœuds, pas un par cube" % slug,
		ok and (e["noeuds"] as Array).all(func(n): return n is MultiMeshInstance3D) and e.get("juge") != null)
	if not ok:
		return
	for k in 2:
		var mmi := e["noeuds"][k] as MultiMeshInstance3D
		var mat := e["mats"][k] as ShaderMaterial
		var calque := Presentation3D.CALQUE_VUE_1 if k == 0 else Presentation3D.CALQUE_VUE_2
		_check("« %s », vue de J%d : sur le calque 3D de SA caméra, et lit SA lightmap" % [slug, k + 1],
			mmi.layers == calque and bool(mat.get_shader_parameter("vue_deux")) == (k == 1)
			and mat.get_shader_parameter("lumiere_1") == main.vp1.get_texture()
			and mat.get_shader_parameter("lumiere_2") == main.vp2.get_texture())
		_check("« %s », vue de J%d : dessiné avant les corps (priorité %d < 0), des milliers de cubes en un maillage"
			% [slug, k + 1, mat.render_priority], mat.render_priority == IsoVolumes.PRIORITE_VOLUME and mat.render_priority < 0
			and mmi.multimesh != null and mmi.multimesh.instance_count > 100 and mmi.material_override == mat
			and IsoNuageVoxel.est_un_shader_de_nuage(mat.shader))
		var cam: Variant = p.call("_camera_de", k)
		var cote := IsoNuageVoxel.cote_camera(-(cam as Camera3D).global_transform.basis.z) if cam is Camera3D else Vector2i(9, 9)
		_check("« %s », vue de J%d : la grille rangée pour SA caméra (côté %s)" % [slug, k + 1, str(cote)],
			mmi.multimesh == IsoNuageVoxel.grille(slug, float(IsoVolumes.VOLUMES[slug]["hauteur"]) * IsoVolumes.TUILE, voxel, cote))
		_check("« %s », vue de J%d : calée sur la grille du monde (un multiple du voxel)" % [slug, k + 1],
			is_equal_approx(fposmod(mmi.position.x, voxel), 0.0) or is_equal_approx(fposmod(mmi.position.x, voxel), voxel))
	var visuel := g.get_node(^"Visuel") as Sprite2D
	var mat0 := e["mats"][0] as ShaderMaterial
	var mat1 := e["mats"][1] as ShaderMaterial
	var origine: Texture2D = load("res://assets/sprites/gadget_%s.png" % slug)
	_check("« %s » : pendant l'essai, la masse est en APLAT — même taille, même alpha, une seule couleur (sans le dessin encré)"
		% slug, visuel.texture != origine and _aplat_de(visuel.texture, origine), str(visuel.texture))
	_check("« %s » : la forme est l'image de la masse, tournée comme elle, à son centre" % slug,
		mat0.get_shader_parameter("masque") == visuel.texture and bool(mat0.get_shader_parameter("avec_masque"))
		and is_equal_approx(float(mat0.get_shader_parameter("nuage_angle")), visuel.global_rotation)
		and (mat0.get_shader_parameter("nuage_centre") as Vector2).is_equal_approx(g.global_position))
	_check("« %s » : sa vie est l'opacité rendue de la masse, × sa densité" % slug,
		is_equal_approx(float(mat0.get_shader_parameter("nuage_vie")),
			Presentation3D.opacite_rendue(visuel) * float(IsoNuageVoxel.NUAGES[slug]["densite"])))
	_check("« %s » : les deux vues reçoivent le même nuage (mêmes réglages de forme et de vie)" % slug,
		mat0.get_shader_parameter("nuage_vie") == mat1.get_shader_parameter("nuage_vie")
		and mat0.get_shader_parameter("nuage_centre") == mat1.get_shader_parameter("nuage_centre")
		and mat0.get_shader_parameter("masque") == mat1.get_shader_parameter("masque"))
	var juge := e["juge"] as MeshInstance3D
	var mj := juge.material_override as ShaderMaterial
	var rayons: Vector4 = mj.get_shader_parameter("juge_rayons")
	var hauteurs: Vector4 = mj.get_shader_parameter("juge_hauteurs")
	var haut := float(e["haut_px"])
	var demi := visuel.texture.get_width() * absf(visuel.global_scale.x) * 0.5
	_check("« %s » : son juge écrit le pochoir, juste avant les cubes, au sommet des cubes" % slug,
		juge.visible and mj.shader.code.contains("#define MASQUE_POCHOIR_JUGE\n")
		and mj.render_priority == IsoVolumes.PRIORITE_JUGE and mj.render_priority < IsoVolumes.PRIORITE_VOLUME
		and is_equal_approx(juge.position.y, haut) and haut >= float(IsoNuageVoxel.rangees(
			float(IsoVolumes.VOLUMES[slug]["hauteur"]) * IsoVolumes.TUILE, voxel)) * voxel - 0.001)
	_check("« %s » : il couvre le cylindre du nuage, du sol au sommet (rayon %.0f ≥ %.0f + un cube)" % [slug, rayons.x, demi],
		rayons.x >= demi + voxel and rayons.x == rayons.w and hauteurs.x == 0.0 and is_equal_approx(hauteurs.w, haut)
		and juge.scale.x >= 2.0 * (rayons.x + haut) - 0.01)
	g.set_physics_process(true)


## La suie à sa naissance, puis dissipée : sa vie règle ses cubes (le jeu ne bouge pas).
func _la_vie_de_la_suie(main: Node, p: Node, volumes: IsoVolumes, g: Node2D) -> void:
	var e: Dictionary = volumes.suivi_de(g)
	if e.is_empty():
		return
	var mat := e["mats"][0] as ShaderMaterial
	var naissance := float(mat.get_shader_parameter("nuage_vie"))
	var age_ne := float(g.call("age"))
	for k in 90:
		await physics_frame
	await process_frame
	var pleine := float(mat.get_shader_parameter("nuage_vie"))
	g.set("_age", float(g.get("duree_vie")) * 0.95)
	await physics_frame
	await process_frame
	await process_frame
	var fin := float(mat.get_shader_parameter("nuage_vie"))
	_check("la suie NAÎT (%.2f à %.2f s), puis est pleine (%.2f), puis se DISSIPE (%.2f à 95 %% de sa vie)" % [naissance,
		age_ne, pleine, fin], naissance < pleine and fin < pleine * 0.5 and pleine > 0.9)


func _la_fusee(main: Node, p: Node, volumes: IsoVolumes, voxel: float) -> void:
	print("\n[La fumée de la fusée en voxels : son voile et ses nappes, panache compris]")
	var f := await _fusee_posee(main, main.p1.global_position + Vector2(0.0, 220.0), 5.0)
	var e: Dictionary = volumes.suivi_de(f)
	var ok: bool = not e.is_empty() and e["genre"] == "nuage_voxel" and (e["noeuds"] as Array).size() == 2
	_check("posée, sa fumée est une grille de cubes par vue", ok)
	if ok:
		# Figée : le voile bouge à chaque pas de physique, et la copie se fait à l'image — on compare un état tenu.
		f.set_physics_process(false)
		await process_frame
		await process_frame
		var mat := e["mats"][1] as ShaderMaterial
		var voile := f.get_node(^"Voile") as Sprite2D
		var mv := voile.material as ShaderMaterial
		_check("le shader de la fusée (NUAGE_FUSEE) : son voile et ses nappes", mat.shader.code.contains("#define NUAGE_FUSEE\n"))
		_check("le voile est recopié de son matériau : opacité, graine, âge, trous, masses",
			mat.get_shader_parameter("voile_alpha_globale") == mv.get_shader_parameter("alpha_globale")
			and mat.get_shader_parameter("voile_graine") == mv.get_shader_parameter("graine")
			and mat.get_shader_parameter("voile_age") == mv.get_shader_parameter("age")
			and mat.get_shader_parameter("nb_masses") == mv.get_shader_parameter("nb_masses")
			and is_equal_approx(float(mat.get_shader_parameter("voile_diametre")), float(f.call("rayon_fumee")) * 2.0))
		var nappes: Array = []
		for n in f.get_children():
			if n is Sprite2D and String(n.name).begins_with("Nappe") and (n as Sprite2D).is_visible_in_tree():
				nappes.append(n)
		var reglages: PackedVector3Array = mat.get_shader_parameter("nappes")
		_check("ses %d nappes visibles (une de moins en écran scindé), leur rotation, leur taille, leur opacité" % nappes.size(),
			int(mat.get_shader_parameter("nb_nappes")) == nappes.size() and nappes.size() >= 2
			and is_equal_approx(reglages[0].x, (nappes[0] as Sprite2D).global_rotation)
			and is_equal_approx(reglages[0].z, Presentation3D.opacite_rendue(nappes[0]))
			and mat.get_shader_parameter("nappe_1") == (nappes[0] as Sprite2D).texture)
		# Un sillage : J2 traverse la fumée ; ses trous passent au voxel comme au voile.
		var depart: Vector2 = main.p2.global_position
		f.set_physics_process(true)
		for k in 40:
			main.p2.global_position = f.global_position + Vector2(-150.0 + 7.5 * float(k), 20.0)
			await physics_frame
		f.set_physics_process(false)
		await process_frame
		await process_frame
		_check("le sillage d'un corps qui traverse (%d trous) passe aux voxels" % int(mv.get_shader_parameter("nb_trous")),
			int(mv.get_shader_parameter("nb_trous")) > 0
			and mat.get_shader_parameter("nb_trous") == mv.get_shader_parameter("nb_trous")
			and mat.get_shader_parameter("trous") == mv.get_shader_parameter("trous"))
		_check("la masse d'un corps dans la fumée passe aux voxels", int(mat.get_shader_parameter("nb_masses")) >= 1
			and mat.get_shader_parameter("masses") == mv.get_shader_parameter("masses"))
		main.p2.global_position = depart
	f.set_physics_process(true)
	f.call("eteindre")
	for k in 12:
		await physics_frame
	f.set_physics_process(false)
	await process_frame
	await process_frame
	var ep: Dictionary = volumes.suivi_de(f)
	var mv2 := (f.get_node(^"Voile") as Sprite2D).material as ShaderMaterial
	_check("éteinte, son panache noir est encore en voxels (%.2f)" % float(f.call("alpha_fumee")),
		float(f.call("alpha_fumee")) > 0.0 and not ep.is_empty() and ep["genre"] == "nuage_voxel"
		and (ep["mats"][0] as ShaderMaterial).get_shader_parameter("voile_alpha_globale") == mv2.get_shader_parameter("alpha_globale"))
	f.queue_free()
	await process_frame


func _le_rejeu(main: Node, p: Node, volumes: IsoVolumes) -> void:
	print("\n[Le rejeu : une fusée de killcam a ses voxels]")
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("is_replay", true)
	f.set("depart", main.p1.global_position + Vector2(0.0, 220.0))
	f.set("graine", 4242)
	f.set("joueurs", [main.p1, main.p2])
	f.name = "FuseeKillcam_4242"
	main.bullet_container.add_child(f)
	await process_frame
	f.call("appliquer_age", 6.0)
	await process_frame
	await process_frame
	var e: Dictionary = volumes.suivi_de(f)
	_check("une fusée de rejeu (is_replay) a sa fumée en voxels", not e.is_empty() and e["genre"] == "nuage_voxel")
	f.queue_free()
	await process_frame


func _des_images_seulement(main: Node, p: Node, volumes: IsoVolumes) -> void:
	print("\n[Les voxels ne sont que des images]")
	var suie := await _poser(main, 1, main.p2.global_position + Vector2(-140.0, 0.0), "cartouche_suie", 9790)
	var f := await _fusee_posee(main, main.p1.global_position + Vector2(0.0, 220.0), 6.0)
	# La fusée figée : ses lumières ne bougent plus d'elles-mêmes, seul ce qu'on coupe pourrait les bouger.
	f.set_physics_process(false)
	await process_frame
	var avant := _instantane(main)
	var noeuds := _noeuds_voxels(p)
	_check("il y a bien des voxels à couper (%d grilles)" % noeuds.size(), noeuds.size() >= 4, str(volumes.suivi_de(f).get("genre")))
	volumes.images_actives = false
	p.call("_suivre")
	var sans := _instantane(main)
	_check("sans les images, plus aucun voxel ni juge", _noeuds_voxels(p).all(
		func(n): return (n as Node).is_queued_for_deletion()) and volumes.nombre_de_suivis() == 0)
	_check("sans les images, les lumières 2D sont les mêmes (énergie, hauteur, masques, couleur)",
		sans["lumieres"] == avant["lumieres"], _ecart(avant["lumieres"], sans["lumieres"]))
	_check("sans les images, les capteurs sont les mêmes", sans["capteurs"] == avant["capteurs"])
	_check("sans les images, les joueurs sont les mêmes", sans["joueurs"] == avant["joueurs"])
	_check("sans les images, la masse de la suie a repris son dessin", suie != null
		and (suie.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_cartouche_suie.png"))
	volumes.images_actives = true
	p.call("_suivre")
	var apres := _instantane(main)
	_check("les images rendues, les lumières 2D n'ont pas bougé", apres["lumieres"] == avant["lumieres"])
	# Éteindre l'essai : les couches reviennent, les voxels partent.
	volumes.poser_fumee_voxel(false)
	p.call("_suivre")
	var sans_essai := _instantane(main)
	var es: Dictionary = volumes.suivi_de(suie) if suie != null else {}
	var ef: Dictionary = volumes.suivi_de(f)
	_check("l'essai éteint, la suie et la fumée reprennent leurs couches", not es.is_empty() and es["genre"] == "volume"
		and not ef.is_empty() and ef["genre"] == "fumee")
	await process_frame
	_check("… et aucun nœud de voxels ne reste", _noeuds_voxels(p).is_empty())
	_check("… et la masse de la suie a repris son dessin", suie != null
		and (suie.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_cartouche_suie.png"))
	_check("l'essai éteint, les lumières 2D, les capteurs et les joueurs sont ceux de l'essai allumé",
		sans_essai["lumieres"] == avant["lumieres"] and sans_essai["capteurs"] == avant["capteurs"]
		and sans_essai["joueurs"] == avant["joueurs"])
	volumes.poser_fumee_voxel(true)
	f.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

## ⚠️ `_do_spawn_gadget` prend la durée de vie dans le profil de la CLASSE DU POSEUR, pas dans le catalogue du slug : une
## suie posée par un joueur qui n'est pas Fumiste vivrait éternellement (sa vie, `_fondu`, resterait à 1). La suite lui rend
## celle du catalogue (`GameState.IMPLEMENTATIONS`), celle qu'elle a en jeu sous la main du Fumiste.
func _poser(main: Node, pid: int, pos: Vector2, slug: String, numero: int) -> Node2D:
	var avant: Array = main.bullet_container.get_children()
	main._do_spawn_gadget(pid, pos, 0.0, slug, numero)
	var neuf: Node2D = null
	for n in main.bullet_container.get_children():
		if not avant.has(n) and "slug" in n and String(n.get("slug")) == slug:
			neuf = n
	var catalogue: Dictionary = main.get_script().get_script_constant_map()["IMPLEMENTATIONS"]
	if neuf != null and catalogue.has(slug):
		neuf.set("duree_vie", float((catalogue[slug] as Dictionary).get("duree_vie", 0.0)))
	for k in 3:
		await process_frame
	return neuf if is_instance_valid(neuf) else null


## Une fusée posée comme en jeu (`_atterrir` : la lumière à l'empreinte du sol), figée à l'âge `age`.
func _fusee_posee(main: Node, pos: Vector2, age: float) -> Node2D:
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", pos)
	f.set("direction", Vector2.RIGHT)
	f.set("joueurs", [main.p1, main.p2])
	main.bullet_container.add_child(f)
	await process_frame
	f.set_physics_process(false)
	f.global_position = pos
	f.call("_atterrir")
	f.call("forcer_age", age)
	f.set_physics_process(true)
	for k in 3:
		await process_frame
	return f


## `aplat` est-il l'aplat de `origine` : même taille, même alpha partout, une seule couleur là où il se voit ?
func _aplat_de(aplat: Texture2D, origine: Texture2D) -> bool:
	if aplat == null or origine == null or aplat.get_size() != origine.get_size():
		return false
	var a := aplat.get_image()
	var o := origine.get_image()
	a.convert(Image.FORMAT_RGBA8)
	o.convert(Image.FORMAT_RGBA8)
	var da := a.get_data()
	var do := o.get_data()
	var couleur := Vector3i(-1, -1, -1)
	for i in range(0, da.size(), 4):
		if da[i + 3] != do[i + 3]:
			return false
		if couleur.x < 0:
			couleur = Vector3i(da[i], da[i + 1], da[i + 2])
		elif Vector3i(da[i], da[i + 1], da[i + 2]) != couleur:
			return false
	return true


## Les grilles de voxels vivantes sous la présentation.
func _noeuds_voxels(p: Node) -> Array:
	return p.find_children("*", "MultiMeshInstance3D", true, false).filter(
		func(n): return String((n as Node).name).begins_with("NuageVoxel") and not (n as Node).is_queued_for_deletion())


func _instantane(main: Node) -> Dictionary:
	var lumieres := {}
	for n in main.find_children("*", "Light2D", true, false):
		var l := n as Light2D
		lumieres[str(main.get_path_to(l))] = [l.enabled, snappedf(l.energy, 0.0001), l.height,
			l.shadow_item_cull_mask, l.range_item_cull_mask, l.color, l.shadow_enabled]
	var capteurs := {}
	for c in main.get_tree().root.find_children("Capteur*", "SubViewport", true, false):
		capteurs[c.name] = (c as SubViewport).canvas_cull_mask
	var joueurs := []
	for j in [main.p1, main.p2]:
		joueurs.append([j.global_position, j.rotation, j.get("hp")])
	return {"lumieres": lumieres, "capteurs": capteurs, "joueurs": joueurs}


static func _ecart(a: Dictionary, b: Dictionary) -> String:
	for k in a:
		if not b.has(k) or b[k] != a[k]:
			return "%s : %s → %s" % [k, str(a[k]), str(b.get(k))]
	return ""


## Le corps d'une fonction GDScript de premier niveau (`statique` : `static func`), jusqu'à la suivante.
func _fonction_gd(code: String, nom: String, statique := false) -> String:
	var debut := code.find(("\nstatic func %s(" if statique else "\nfunc %s(") % nom)
	if debut < 0:
		return ""
	var fin := code.length()
	for marque in ["\nfunc ", "\nstatic func ", "\nconst ", "\n## "]:
		var k := code.find(marque, debut + 1)
		if k > 0 and k < fin:
			fin = k
	return code.substr(debut, fin - debut)


func _sans_commentaires(code: String) -> String:
	return RegEx.create_from_string("//[^\\n]*").sub(code, "", true)


func _a_l_uniforme(shader: Shader, nom: String) -> bool:
	if shader == null:
		return false
	for u in shader.get_shader_uniform_list():
		if u["name"] == nom:
			return true
	return false


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			printerr("    la manche n'a pas démarré (round_active=%s, décompte=%s)" % [main.round_active, main.countdown_left])
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	for i in 4:
		await physics_frame
	return main.round_active


func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

