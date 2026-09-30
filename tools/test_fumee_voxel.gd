## Chantier « Gadgets en volume » — la fumée en voxels, LE RENDU PAR DÉFAUT depuis GV1bis.
##
## Adrien, 2026-09-30 : « J'aimerais également que tous les gadgets (je me souviens de la fumée occultante) soient
## davantage en 3D. » GV1 a mis la suie, la poussière et la fumée de la fusée en cubes, à l'essai (`IsoNuageVoxel`,
## `nuage_voxel_iso.gdshader`) ; GV1bis en fait le défaut (Q67 : « Oui la fumée en gros »), avec l'encre du roman
## graphique sur les cubes (Q67 : « des traits sombres comme le faisait le style roman graphique ») et le relief tiré de la
## clarté des volutes du dessin (Q69), l'un et l'autre à l'horloge du nuage.
##
## Ce que cette suite prouve, sans fenêtre, sur une vraie manche iso en écran scindé, nuages posés par le VRAI chemin
## (`GameState._do_spawn_gadget`, une vraie fusée posée) :
##
## **Le défaut** — sans drapeau, les trois nuages sont en voxels « gros », relief du dessin, encre du roman graphique.
## **Le retour aux couches** (`--fumee-couches`, pour les bancs et les suites) : le jeu d'avant — les couches (4, 3 et 4),
## aucun nœud de voxels, le shader des voxels jamais chargé, la masse avec son dessin.
##
## **Les voxels** —
## - chaque nuage a UNE grille de cubes par vue (un `MultiMesh` : un appel de dessin), sur le calque 3D de la caméra de
##   cette vue, qui lit SA lightmap ; les grilles sont partagées entre nuages du même type ;
## - les deux vues ont le même jeu de cellules, chacune rangée du plus loin au plus proche pour SA caméra (l'ordre du
##   peintre, sans tri) ; chacune n'a que les trois faces que sa caméra voit ;
## - dessinées AVANT les corps, sans écrire la profondeur, non éclairées, sous le pochoir du masque de la fumée, avec leur
##   juge (le plan qui écrit le pochoir) posé juste avant elles et couvrant le cylindre du nuage ;
## - la densité suit le nuage 2D : la forme et l'angle de la masse, sa vie ; pour la fusée, son voile et ses nappes (les
##   planches réduites), panache d'extinction compris ;
## - LE RELIEF ET L'ENCRE viennent du DESSIN d'origine (`IsoNuageVoxel.relief` : son alpha, la clarté de ses volutes, ses
##   traits) — la masse reste en aplat (Q68) ;
## - ÉQUITÉ : les deux vues reçoivent les mêmes réglages, au choix de la vue près ; L'HORLOGE : l'âge du nuage, le même
##   dans les deux vues, rejoué par la killcam (une copie de killcam prend l'âge rejoué) — jamais TIME, jamais une graine
##   tirée d'un identifiant d'instance ;
## - noir absolu dans le monde : la couleur d'un cube n'est que la lightmap lue sous lui, assombrie par ses faces et son
##   encre (facteurs ≤ 1) ; aucune `Light3D` ; et « ALLUMÉ RESTE ALLUMÉ » : sur un trait, une face ne descend jamais sous le
##   plancher des murs, et plus sombre que lui elle n'a pas de trait (vérifié sur le miroir de la pâte) ;
## - les encres et le relief basculent sur place (les bancs comparent dans la même image) ;
## - **les images ne sont que des images** : couper les images ne change aucune lumière 2D, aucun capteur, aucun joueur ;
##   rendre les couches rend la masse et son dessin.
##
## Ce qu'elle ne prouve pas : le noir À L'ÉCRAN, « allumé reste allumé » à l'écran et le coût, qui ne se mesurent qu'au
## rendu — le banc `tools/banc_gadgets_volume.gd` (`--mode=noir`, `--mode=cout`) les mesure en vraie fenêtre.
##
## Lancée TROIS fois par `run_suites.sh` : sans drapeau (le défaut, puis les couches et chaque encre par la bascule des
## bancs), sous `--fumee-couches` (le jeu d'avant, lu au lancement), et sous `--fumee-voxels=fin --fumee-encre=hachures
## --fumee-relief=bruit` (les trois choix lus au lancement).
extends SceneTree

const PLANCHER := 100
const PLANCHER_DRAPEAUX := 60
const CARTE := "res://tools/cartes/murs_bas_essai.json"
const NUAGES := ["cartouche_suie", "poussiere"]

var _failures := 0
var _verifications := 0
## Ce que les drapeaux de la prise demandent, lu comme le jeu les lit.
var _attendu := {}
var _drapeaux := false


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
	_attendu = {"voxel": true, "variante": IsoNuageVoxel.VARIANTE_PAR_DEFAUT, "encre": IsoNuageVoxel.ENCRE_PAR_DEFAUT,
		"relief": IsoNuageVoxel.RELIEF_PAR_DEFAUT}
	for arg in DrapeauxDeLancement.arguments():
		if arg == IsoVolumes.DRAPEAU_FUMEE_COUCHES:
			_attendu["voxel"] = false
			_drapeaux = true
		for cle: Array in [[IsoVolumes.DRAPEAU_FUMEE_VOXELS, "variante"], [IsoVolumes.DRAPEAU_FUMEE_ENCRE, "encre"],
				[IsoVolumes.DRAPEAU_FUMEE_RELIEF, "relief"]]:
			if arg.begins_with(String(cle[0]) + "="):
				_attendu[cle[1]] = arg.get_slice("=", 1)
				_drapeaux = true
	print("=== LA FUMÉE EN VOXELS (GV1bis, le défaut) — %s ===" % (("drapeaux : %s" % str(_attendu)) if _drapeaux
		else "sans drapeau"))
	await process_frame
	_le_drapeau()
	_la_grille()
	# La manche AVANT le shader : sous `--fumee-couches`, elle vérifie que le shader des voxels n'a jamais été chargé — les
	# contrôles du shader, eux, le chargent.
	await _dans_la_manche()
	_le_shader()
	_l_encre_n_eteint_rien()
	_le_relief_du_dessin()
	_les_parametres_existent()
	var plancher := PLANCHER_DRAPEAUX if _drapeaux else PLANCHER
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, plancher], _verifications >= plancher)
	_sortir()


# ---------------------------------------------------------------------------
# LES DRAPEAUX
# ---------------------------------------------------------------------------

func _le_drapeau() -> void:
	print("\n[Les drapeaux : les voxels « gros » par défaut, les couches et les variantes pour les bancs]")
	var v := IsoVolumes.new()
	_check("l'état lu au lancement est celui que demandent les drapeaux de la prise (%s)" % str(_attendu),
		v.fumee_voxel == bool(_attendu["voxel"]) and v.variante_voxel == String(_attendu["variante"])
		and v.encre_voxel == String(_attendu["encre"]) and v.relief_voxel == String(_attendu["relief"]),
		"%s / %s / %s / %s" % [str(v.fumee_voxel), v.variante_voxel, v.encre_voxel, v.relief_voxel])
	if not _drapeaux:
		_check("SANS drapeau, la fumée est EN VOXELS « gros » (Q67 : « Oui la fumée en gros »), au relief du dessin (Q69), à l'encre du roman graphique",
			v.fumee_voxel and v.variante_voxel == "gros" and v.relief_voxel == "dessin"
			and IsoNuageVoxel.ENCRES_GV1BIS.has(v.encre_voxel)
			and is_equal_approx(IsoNuageVoxel.cote_voxel("gros"), IsoVolumes.TUILE / 4.0)
			and is_equal_approx(IsoNuageVoxel.cote_voxel("fin"), IsoVolumes.TUILE / 8.0))
	v.free()
	_check("les trois encres du roman graphique, le trait de GV1 et « aucune » ; deux reliefs",
		IsoNuageVoxel.ENCRES_GV1BIS == ["aretes", "volutes", "hachures"]
		and IsoNuageVoxel.ENCRES_GV1BIS.all(func(e): return int(IsoNuageVoxel.ENCRES[e]) >= 1)
		and int(IsoNuageVoxel.ENCRES["cotes"]) == 0 and int(IsoNuageVoxel.ENCRES["aucune"]) == -1
		and IsoNuageVoxel.RELIEFS.has("dessin") and IsoNuageVoxel.RELIEFS.has("bruit"))
	var src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("les drapeaux se lisent par la porte commune des drapeaux (avant comme après --)",
		src.contains("for arg in DrapeauxDeLancement.arguments():")
		and src.contains("elif arg == DRAPEAU_FUMEE_COUCHES:\n\t\t\tfumee_voxel = false")
		and src.contains("elif arg.begins_with(DRAPEAU_FUMEE_ENCRE + \"=\"):")
		and src.contains("elif arg.begins_with(DRAPEAU_FUMEE_RELIEF + \"=\"):"))
	_check("le jeu dit ce qu'il dessine, dans les deux états (une prise prouve son bras par le journal)",
		src.contains("[fumée voxel] voxels « %s » de %.2f px (%s de tuile), encre « %s », relief « %s »")
		and src.contains("[fumée voxel] éteinte (%s) — les couches d'avant"))
	var gadget := _fonction_gd(src, "_suivre_gadget")
	var fusee := _fonction_gd(src, "_suivre_fusee")
	_check("le chemin des voxels n'est atteint QUE si la fumée est en voxels (suie et poussière)",
		gadget.contains("\tif fumee_voxel and VOLUMES.has(slug) and IsoNuageVoxel.NUAGES.has(slug):\n\t\t_suivre_gadget_en_voxels(g, slug, vus)\n\telif VOLUMES.has(slug):")
		and gadget.count("_suivre_gadget_en_voxels(") == 1)
	_check("… et pour la fumée de la fusée",
		fusee.contains("\tif volumes_actifs and alpha > 0.0 and fumee_voxel:\n\t\t_suivre_fusee_en_voxels(f, vus)\n\telif volumes_actifs and alpha > 0.0:")
		and fusee.count("_suivre_fusee_en_voxels(") == 1)
	_check("aucun autre appelant des voxels dans le jeu", src.count("_suivre_nuage_voxel(") == 3
		and src.count("_suivre_gadget_en_voxels(") == 2 and src.count("_suivre_fusee_en_voxels(") == 2)
	var nuage := FileAccess.get_file_as_string("res://iso_nuage_voxel.gd")
	_check("le shader des voxels n'est chargé qu'au préchauffage ou au premier nuage (aucun preload, aucun chargement ailleurs)",
		not nuage.contains("preload(") and not src.contains('load("res://nuage_voxel_iso')
		and nuage.contains("static var _shader: Shader = null") and nuage.count("load(CHEMIN_SHADER)") == 1)
	_check("… et le préchauffage ne se fait que si la fumée est en voxels",
		_fonction_gd(src, "_init").contains("\tif fumee_voxel:\n\t\tprint(\"[fumée voxel] voxels")
		and _fonction_gd(src, "_init").count("IsoNuageVoxel.prechauffer()") == 1)


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
		and not _a_l_uniforme(sh, "trous") and _a_l_uniforme(sh, "encre_style") and _a_l_uniforme(sf, "relief_style"))
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
	_check("… passée à la pâte comme le sol, 0 → 0 (aucun terme additif), et NOIRE si le sol sous elle l'est",
		sans.contains("vec3 col = (l <= 0.0 || pate_luminance(brute) <= 0.0) ? vec3(0.0)")
		and sans.contains(": (style == PATE_BRUTE ? lu : pate(lu, l, style, c.xz, vec2(0.0), l, 0.1));")
		and sans.contains("v_couleur = pate_facteur(col, face);"))
	# L'ENCRE — un assombrissement, sous la règle des murs : le trait du roman graphique est `pate_matiere_et_encre` au
	# plancher des murs ; celui de GV1 un facteur de plus ; et le fragment ne fait que mélanger la face et son trait.
	_check("l'encre du roman graphique obéit à « allumé reste allumé » (`pate_matiere_et_encre`, le plancher des murs) ; celle de GV1 est un facteur",
		sans.contains("v_encre = encre_style == 0 ? pate_facteur(col, face * encre_reste)")
		and sans.contains(": pate_matiere_et_encre(col, face, trait_reste, 1.0, trait_plancher);")
		and sans.count("ALBEDO =") == 1 and sans.contains("ALBEDO = mix(v_couleur, v_encre, trait);")
		and sans.count("v_encre =") == 2)
	_check("les faces et les encres ne font qu'assombrir (facteurs ≤ 1)", IsoNuageVoxel.FACE_DESSUS <= 1.0
		and IsoNuageVoxel.FACE_GAUCHE <= 1.0 and IsoNuageVoxel.FACE_DROITE <= 1.0 and IsoNuageVoxel.ENCRE_RESTE <= 1.0
		and IsoNuageVoxel.TRAIT_RESTE <= 1.0)
	for chemin in [IsoNuageVoxel.CHEMIN_SHADER, "res://iso_nuage_voxel.gd"]:
		var s := FileAccess.get_file_as_string(chemin)
		_check("%s : aucune Light3D" % chemin.get_file(), not s.contains("Light3D.new") and not s.contains("OmniLight3D")
			and not s.contains("SpotLight3D"))
	# L'HORLOGE et les GRAINES — la même pour les deux vues et la killcam : l'âge du nuage, son centre.
	_check("rien ne lit TIME : tout ce qui bouge suit l'âge du nuage (la killcam rejoue un âge)",
		not sans.contains("TIME") and sans.contains("vec2(0.09, -0.06) * age") and sans.contains("vec2(0.13, -0.09) * age")
		and sans.contains("age * 0.1;") and sans.contains("vec2(0.05, -0.035) * age"))
	_check("les graines viennent du CENTRE du nuage (ou de la graine de la fusée), jamais d'un identifiant d'instance",
		sans.contains("return vec2(pate_hash(floor(nuage_centre)), pate_hash(floor(nuage_centre) + vec2(7.0, 3.0))) * 40.0;")
		and not sans.contains("instance") and not sans.contains("INSTANCE_ID")
		and not _poses_du_nuage().contains("get_instance_id"))
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
	_check("les volutes du voile : mêmes graines, même dérive (la graine et l'âge au même poids) — pour sa densité et pour sa clarté",
		voile.contains("vec2 q = UV * 3.0 + vec2(graine * 0.013, graine * 0.007);")
		and code.count("vec2 q = uv * 3.0 + vec2(voile_graine * 0.013, voile_graine * 0.007);") == 2
		and voile.contains("q += vec2(age * 0.03, -age * 0.02);") and code.count("q += vec2(voile_age * 0.03, -voile_age * 0.02);") == 2)
	var nappe := FileAccess.get_file_as_string("res://nappe_fusee.gdshader")
	_check("les nappes : les trois paliers de nappe_fusee.gdshader (0,15 / 0,45 / 0,75 pour 0,35 / 0,30 / 0,35)",
		nappe.contains("smoothstep(0.15 - w, 0.15 + w, densite) * 0.35") and nappe.contains("smoothstep(0.45 - w, 0.45 + w, densite) * 0.30")
		and nappe.contains("smoothstep(0.75 - w, 0.75 + w, densite) * 0.35")
		and code.contains("step(0.15, densite) * 0.35 + step(0.45, densite) * 0.30 + step(0.75, densite) * 0.35"))
	# LE RELIEF (Q69) : la clarté des volutes du dessin, au point dérivé ; le bruit de GV1 sous `relief_style` 0.
	_check("le relief des bouffées : la clarté des volutes du DESSIN (le rouge du relief, au point dérivé ; le voile de la fusée), le bruit de GV1 sinon",
		sans.contains("if (relief_style == 1) {") and sans.contains("return clarte_du_voile(p);")
		and sans.contains("return avec_masque ? texture(masque, uv_dessin(p)).r : 0.5;")
		and sans.contains("return 0.65 * pate_bruit(q) + 0.35 * pate_bruit(q * 2.13 + vec2(5.2, 1.3));"))
	_check("… et la dérive du dessin est BORNÉE (± `derive_dessin` du rayon) : le dessin ondule, il ne s'en va pas",
		sans.contains("d += (vec2(pate_bruit(q), pate_bruit(q + vec2(5.3, 1.7))) - vec2(0.5)) * 2.0 * derive_dessin;")
		and IsoNuageVoxel.DERIVE_DESSIN > 0.0 and IsoNuageVoxel.DERIVE_DESSIN <= 0.1)
	# Le dôme : le rayon se resserre en montant comme celui des couches ; la densité qui s'allège en montant (× 1 − 0,45 f
	# sur les couches) devient, sur les cubes, le SOMMET de chaque colonne (les bouffées) — un cube plein ou rien.
	_check("le dôme des couches : le rayon se resserre de 22 % en montant, et le sommet des colonnes suit la densité, le relief et la vie",
		code.contains("float d2 = densite_2d(c.xz, 1.0 - 0.22 * f);") and code.contains("float rho = d2 * nuage_vie;")
		and code.contains("float bosse = 0.3 + 0.9 * bouffees(c.xz);")
		and code.contains("float sommet = nuage_hauteur_px * clamp(d2 * bosse, 0.0, 1.0) * vie;")
		and FileAccess.get_file_as_string("res://iso_volumes.gd").contains("var r := rayon * (1.0 - 0.22 * f)"))
	# LES ENCRES : leurs règles, dans le texte.
	_check("les arêtes : un trait là où la surface se rompt d'une case entière, jamais entre deux dessus de même hauteur ni sur une demi-marche",
		sans.count("encre = (v.x >= 1.0 && abs(marche(v.z) - marche(monte)) < 1.0) ? 0.0 : 1.0;") == 2
		and sans.contains("moins = (vm.x >= 1.0 && marche(monte) - marche(vm.z) < 1.0) ? 0.0 : 1.0;")
		and sans.contains("float dessus = ((haut < 1.0 || monte < 1.25) && mur >= 1.0) ? 1.0 : 0.0;")
		and sans.contains("if (s < 1.0) {\n\t\treturn vec4(0.0);\n\t}")
		and sans.contains("if (encre_style == 1) {") and sans.contains("v_aretes = aretes_de(c, s, haut, cube.z, NORMAL, fond, devant);"))
	_check("les volutes : le trait du dessin, drapé (le point lu déplié depuis le sommet de la colonne sur un côté) ; la fusée, les lignes de niveau des volutes de son voile",
		sans.contains("p += v_normale.xz * max(v_sommet - v_monde.y, 0.0);")
		and sans.contains("trait = avec_masque ? smoothstep(0.25, 0.75, texture(masque, uv_dessin(p)).g) : 0.0;")
		and sans.contains("float n = clarte_du_voile(p);")
		and sans.contains("trait = max(l1, l2) * clamp(voile_alpha_globale * 2.0, 0.0, 1.0);"))
	_check("les hachures : dosées par la clarté de la face, croisées plus bas, et rien sur une face claire",
		sans.contains("float c1 = clamp((0.5 - v_ton) / 0.3, 0.0, 1.0) * 0.35 * souffle;")
		and sans.contains("float c2 = clamp((0.25 - v_ton) / 0.15, 0.0, 1.0) * 0.3 * souffle;")
		and sans.contains("trait = max(h1 * step(0.001, c1), h2 * step(0.001, c2));"))
	# Le coût tenu par construction : une face collée à un voisin plein s'écrase ; seule la peau du nuage rastérise.
	_check("les faces cachées s'écrasent : un cube de pleine largeur collé à un voisin qui le couvre (dessus, ou devant)",
		sans.contains("if (!cachee && s >= 1.0) {") and sans.contains("vec3 voisin = c + NORMAL * voxel_px;")
		and sans.contains("devant = cube_de(voisin);")
		and sans.contains("cachee = NORMAL.y > 0.5 ? (haut >= 1.0 && devant.x >= 1.0) : (devant.x >= 1.0 && devant.y >= haut);")
		and sans.contains("VERTEX = vec3(0.0);"))
	# La sortie avant la densité ne change aucun cube : le sommet possible le plus haut (densité pleine, d2 = 1) borne le
	# vrai sommet (d2 ≤ 1), et la même comparaison au quart de case décide des deux (sous un quart, la marche vaut 0).
	_check("… une case au-dessus du plus haut sommet possible sort AVANT de lire la densité (la part chère), sans changer un cube",
		sans.contains("if (nuage_hauteur_px * clamp(bosse, 0.0, 1.0) * vie - bas < 0.25 * voxel_px) {")
		and sans.find("if (nuage_hauteur_px * clamp(bosse, 0.0, 1.0) * vie - bas < 0.25 * voxel_px) {")
			< sans.find("float d2 = densite_2d(c.xz, 1.0 - 0.22 * f);")
		and sans.contains("haut = haut < 0.25 ? 0.0 : (haut < 0.75 ? 0.5 : 1.0);")
		and sans.contains("return haut <= 0.0 ? vec3(0.0) : vec3(s, haut, monte);"))
	_check("… un cube vide ou caché ne lit ni la lumière ni ses voisins d'encre (tout est dans la branche des faces vues)",
		sans.find("if (cachee) {") >= 0 and sans.find("if (cachee) {") < sans.find("vec3 brute = lire_lightmap(c.xz, vue_deux);")
		and sans.find("if (cachee) {") < sans.find("v_aretes = aretes_de("))
	var mat := IsoNuageVoxel.materiau("fusee", 0, 8.75, 35.0, -2)
	_check("… et un voisin hors de la grille ne cache rien et n'est rien : la portée posée borne toutes les rangées (rayon + 1,5 voxel)",
		is_equal_approx(float(mat.get_shader_parameter("grille_portee")), 250.0 + 1.5 * 8.75)
		and FileAccess.get_file_as_string("res://iso_nuage_voxel.gd").contains(
			"var portee := rayon * (1.0 - RESSERRE * (float(iy) + 0.5) / float(rangs)) + voxel * 1.5")
		and sans.contains("if (length(voisin.xz - nuage_centre) <= grille_portee - 0.75 * voxel_px) {")
		and sans.contains("if (length(v.xz - nuage_centre) > grille_portee - 0.75 * voxel_px) {"))


## Le texte des fonctions qui posent les réglages d'un nuage (`materiau`, `poser_style`, `poser_gadget`, `poser_fusee`).
func _poses_du_nuage() -> String:
	var src := FileAccess.get_file_as_string("res://iso_nuage_voxel.gd")
	var out := ""
	for nom in ["materiau", "poser_style", "poser_gadget", "poser_fusee"]:
		out += _fonction_gd(src, nom, true)
	return out


## « ALLUMÉ RESTE ALLUMÉ » — la règle des murs et des corps, sur le trait du roman graphique, vérifiée sur le MIROIR de la
## pâte (`iso_pate.gd`, la même formule) : pour des lumières de 0 à 1, trois teintes et les trois faces, le trait n'est
## jamais plus clair que la face, jamais sous le plancher quand la face est au-dessus, et n'existe pas sous lui ; 0 → 0.
## Le plancher et le reste sont ceux que `materiau` pose.
func _l_encre_n_eteint_rien() -> void:
	print("\n[L'encre du roman graphique : un assombrissement, et « allumé reste allumé »]")
	var miroir := load("res://iso_pate.gd") as GDScript
	var mat := IsoNuageVoxel.materiau("cartouche_suie", 0, 8.75, 28.0, -2)
	var plancher := float(mat.get_shader_parameter("trait_plancher"))
	var reste := float(mat.get_shader_parameter("trait_reste"))
	_check("le plancher du trait est celui des murs (`ENCRE_PLANCHER_AFFICHE`), son reste celui de l'encre d'essai des murs (0,12)",
		is_equal_approx(plancher, IsoMateriaux.ENCRE_PLANCHER_AFFICHE) and is_equal_approx(reste, IsoNuageVoxel.TRAIT_RESTE)
		and plancher > 0.0 and reste > 0.0)
	var plus_clair := 0
	var sous_plancher := 0
	var trait_sous_plancher := 0
	var noir := 0
	var sombres := 0
	var n := 0
	for k in 41:
		for teinte: Vector3 in [Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.8, 0.55), Vector3(0.6, 0.7, 1.0)]:
			var c := teinte * (float(k) / 40.0)
			for face: float in [IsoNuageVoxel.FACE_DESSUS, IsoNuageVoxel.FACE_GAUCHE, IsoNuageVoxel.FACE_DROITE]:
				n += 1
				var sf := float(miroir.call("luminance", miroir.call("vers_affiche", miroir.call("facteur", c, face))))
				var e: Vector3 = miroir.call("matiere_et_encre", c, face, reste, 1.0, plancher)
				var se := float(miroir.call("luminance", miroir.call("vers_affiche", e)))
				if se > sf + 1e-6:
					plus_clair += 1
				if sf > plancher and se < plancher - 1e-6:
					sous_plancher += 1
				if sf <= plancher:
					sombres += 1
					if absf(se - sf) > 1e-6:
						trait_sous_plancher += 1
				if c == Vector3.ZERO and e != Vector3.ZERO:
					noir += 1
	_check("sur %d lumières × faces : le trait n'est jamais plus clair que la face" % n, plus_clair == 0, str(plus_clair))
	_check("… ne descend jamais sous le plancher quand la face est au-dessus", sous_plancher == 0, str(sous_plancher))
	_check("… n'existe pas sur une face plus sombre que le plancher (%d cas) : elle garde sa lumière" % sombres,
		sombres > 0 and trait_sous_plancher == 0, str(trait_sous_plancher))
	_check("… et noir reste noir", noir == 0)


## Le relief et l'encre d'un dessin (`IsoNuageVoxel.relief`), les planches réduites de la fusée (`planche`).
func _le_relief_du_dessin() -> void:
	print("\n[Le relief et l'encre viennent du DESSIN : sa forme, la clarté de ses volutes, ses traits]")
	for nom in NUAGES:
		var o := load("res://assets/sprites/gadget_%s.png" % nom) as Texture2D
		var r := IsoNuageVoxel.relief(o)
		_check("« %s » : un relief par dessin, gardé (le même objet d'un appel à l'autre)" % nom, r != null and r == IsoNuageVoxel.relief(o))
		if r == null:
			continue
		var io := o.get_image()
		var ir := r.get_image()
		io.convert(Image.FORMAT_RGBA8)
		ir.convert(Image.FORMAT_RGBA8)
		var do := io.get_data()
		var dr := ir.get_data()
		var meme_alpha := io.get_size() == ir.get_size() and do.size() == dr.size()
		var encre_ok := 0
		var encre_ko := 0
		var clair := [0.0, 0]
		var sombre := [0.0, 0]
		if meme_alpha:
			for k in range(0, do.size(), 4):
				if do[k + 3] != dr[k + 3]:
					meme_alpha = false
					break
				if do[k + 3] < 128:
					continue
				var lum := (0.2126 * do[k] + 0.7152 * do[k + 1] + 0.0722 * do[k + 2]) / 255.0
				if lum < 0.03:
					if dr[k + 1] >= 230:
						encre_ok += 1
					else:
						encre_ko += 1
					sombre[0] += dr[k]
					sombre[1] += 1
				elif lum > 0.15:
					if dr[k + 1] <= 25:
						encre_ok += 1
					else:
						encre_ko += 1
				if lum > 0.5:
					clair[0] += dr[k]
					clair[1] += 1
		_check("« %s » : même taille et même alpha que le dessin (la forme du nuage ne bouge pas)" % nom, meme_alpha)
		_check("« %s » : l'encre (vert) est le noir des traits du dessin, et rien d'autre (%d pixels justes, %d faux)"
			% [nom, encre_ok, encre_ko], encre_ok > 1000 and encre_ko <= encre_ok / 50)
		var moy_clair: float = clair[0] / maxf(clair[1], 1.0)
		var moy_sombre: float = sombre[0] / maxf(sombre[1], 1.0)
		_check("« %s » : le relief (rouge) monte sur les volutes claires du dessin (%.0f) et creuse sous ses traits (%.0f)"
			% [nom, moy_clair, moy_sombre], clair[1] > 100 and sombre[1] > 100 and moy_clair > moy_sombre + 60.0)
	# Les planches de la fusée, réduites.
	for chemin in ["res://assets/sprites/fusee_volute_2.png", "res://assets/sprites/fusee_volute.png"]:
		if not ResourceLoader.exists(chemin):
			continue
		var t := load(chemin) as Texture2D
		var red := IsoNuageVoxel.planche(t)
		_check("%s : réduite à %d px au plus, même cadre (%s → %s)" % [chemin.get_file(), IsoNuageVoxel.PLANCHE_PX,
			str(t.get_size()), str(red.get_size())], red != null and red.get_width() <= IsoNuageVoxel.PLANCHE_PX
			and red.get_width() == red.get_height() and t.get_width() == t.get_height() and red == IsoNuageVoxel.planche(t))
		# Les paliers survivent : la part de la planche au-dessus du palier du milieu (0,45), pondérée par l'alpha.
		_check("%s : ses paliers survivent à la réduction (part au-dessus de 0,45 : %.3f contre %.3f)" % [chemin.get_file(),
			_part_palier(red), _part_palier(t)], absf(_part_palier(red) - _part_palier(t)) < 0.03)


func _part_palier(t: Texture2D) -> float:
	var img := t.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_data()
	var dessus := 0.0
	var total := 0.0
	var pas := maxi(1, img.get_width() / 256) * 4
	for k in range(0, d.size(), pas):
		var a := float(d[k + 3]) / 255.0
		total += 1.0
		if maxf(d[k], maxf(d[k + 1], d[k + 2])) / 255.0 >= 0.45:
			dessus += a
	return dessus / maxf(total, 1.0)


## `set_shader_parameter` sur un nom qu'aucun uniforme ne porte ne dit RIEN (piège du 2026-09-25) : chaque nom posé en dur
## par `iso_nuage_voxel.gd` est un uniforme du shader qui le reçoit.
func _les_parametres_existent() -> void:
	print("\n[Chaque paramètre posé sur un nuage existe dans son shader]")
	var src := FileAccess.get_file_as_string("res://iso_nuage_voxel.gd")
	var manque: Array = []
	var vus := 0
	for f: Array in [["materiau", false], ["materiau", true], ["poser_style", false], ["poser_style", true],
			["poser_gadget", false], ["poser_fusee", true]]:
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
	_check("les %d paramètres posés sur les nuages sont des uniformes de leur shader" % vus, vus >= 60 and manque.is_empty(),
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
	if not bool(_attendu["voxel"]):
		await _sous_les_couches(main, p, volumes)
		volumes.poser_fumee_voxel(true, "gros", IsoNuageVoxel.ENCRE_PAR_DEFAUT, "dessin")
	await _avec_les_voxels(main, p, volumes)
	reglages.mode_iso = false
	main.queue_free()
	await process_frame


func _sous_les_couches(main: Node, p: Node, volumes: IsoVolumes) -> void:
	print("\n[Sous --fumee-couches : les couches d'avant, rien des voxels]")
	_check("la manche tourne sans les voxels", not volumes.fumee_voxel)
	var attendues := {"cartouche_suie": 4, "poussiere": 3}
	for i in NUAGES.size():
		var slug: String = NUAGES[i]
		var g := await _poser(main, 1, main.p2.global_position + Vector2(-140.0, 0.0), slug, 9700 + i)
		var e: Dictionary = volumes.suivi_de(g) if g != null else {}
		_check("« %s » : un volume de %d couches, comme avant" % [slug, int(attendues[slug])], not e.is_empty()
			and e["genre"] == "volume" and (e["noeuds"] as Array).size() == int(attendues[slug])
			and (e["noeuds"] as Array).all(func(n): return n is MeshInstance3D and not (n is MultiMeshInstance3D)))
	var pous: Node2D = main.bullet_container.get_children().filter(
		func(n): return "slug" in n and String(n.get("slug")) == "poussiere").back()
	_check("sous les couches, la masse garde son dessin", pous != null
		and (pous.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_poussiere.png"))
	var f := await _fusee_posee(main, main.p1.global_position + Vector2(0.0, 200.0), 5.0)
	var ef: Dictionary = volumes.suivi_de(f)
	_check("la fumée de la fusée : un volume de 4 couches, comme avant", not ef.is_empty() and ef["genre"] == "fumee"
		and (ef["noeuds"] as Array).size() == 4)
	_check("aucun nœud de voxels nulle part", root.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
	_check("le shader des voxels n'a jamais été chargé", not IsoNuageVoxel.shader_charge()
		and not ResourceLoader.has_cached(IsoNuageVoxel.CHEMIN_SHADER))
	f.queue_free()
	await process_frame


func _avec_les_voxels(main: Node, p: Node, volumes: IsoVolumes) -> void:
	print("\n[Les nuages en voxels (%s, encre « %s », relief « %s »)]" % [volumes.variante_voxel, volumes.encre_voxel,
		volumes.relief_voxel])
	var voxel := IsoNuageVoxel.cote_voxel(volumes.variante_voxel)
	await process_frame
	await process_frame
	for i in NUAGES.size():
		var slug: String = NUAGES[i]
		var g := await _poser(main, 1, main.p2.global_position + Vector2(-140.0, 0.0), slug, 9750 + i)
		_le_nuage(main, p, volumes, g, slug, voxel)
		if slug == "cartouche_suie":
			await _la_vie_de_la_suie(main, p, volumes, g)
			await _les_encres_basculent(main, p, volumes, g)
			await _l_horloge_de_la_killcam(main, p, volumes, g)
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
	_check("« %s » : la masse est en APLAT (Q68) — même taille, même alpha, une seule couleur (sans le dessin encré)"
		% slug, visuel.texture != origine and _aplat_de(visuel.texture, origine), str(visuel.texture))
	_check("« %s » : la forme, le relief et l'encre viennent du DESSIN d'origine (son relief), tourné comme lui, à son centre" % slug,
		mat0.get_shader_parameter("masque") == IsoNuageVoxel.relief(origine) and bool(mat0.get_shader_parameter("avec_masque"))
		and is_equal_approx(float(mat0.get_shader_parameter("nuage_angle")), visuel.global_rotation)
		and (mat0.get_shader_parameter("nuage_centre") as Vector2).is_equal_approx(g.global_position))
	_check("« %s » : sa vie est l'opacité rendue de la masse, × sa densité" % slug,
		is_equal_approx(float(mat0.get_shader_parameter("nuage_vie")),
			Presentation3D.opacite_rendue(visuel) * float(IsoNuageVoxel.NUAGES[slug]["densite"])))
	_check("« %s » : l'encre et le relief sont ceux de la partie (« %s », « %s »)" % [slug, volumes.encre_voxel, volumes.relief_voxel],
		int(mat0.get_shader_parameter("encre_style")) == int(IsoNuageVoxel.ENCRES[volumes.encre_voxel])
		and int(mat0.get_shader_parameter("relief_style")) == int(IsoNuageVoxel.RELIEFS[volumes.relief_voxel]))
	# L'ÉQUITÉ : les deux vues reçoivent TOUS les mêmes réglages, au choix de la vue près.
	var ecarts := _ecarts_entre_vues(mat0, mat1)
	_check("« %s » : ÉQUITÉ — les deux vues reçoivent les mêmes réglages, au choix de leur vue près" % slug, ecarts.is_empty(),
		str(ecarts))
	# L'HORLOGE : l'âge du gadget, le même dans les deux vues.
	_check("« %s » : l'horloge est l'âge du gadget (%.3f s), la même dans les deux vues" % [slug, float(g.call("age"))],
		is_equal_approx(float(mat0.get_shader_parameter("age")), float(g.call("age")))
		and mat0.get_shader_parameter("age") == mat1.get_shader_parameter("age"))
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


## Les réglages qui diffèrent entre les matériaux des deux vues, hors `vue_deux` (le choix de la lightmap).
func _ecarts_entre_vues(a: ShaderMaterial, b: ShaderMaterial) -> Array:
	var out := []
	for u in a.shader.get_shader_uniform_list():
		var nom := String(u["name"])
		if nom == "vue_deux":
			continue
		if a.get_shader_parameter(nom) != b.get_shader_parameter(nom):
			out.append(nom)
	if a.shader != b.shader:
		out.append("shader")
	return out


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


## Les encres et le relief basculent SUR PLACE (les bancs comparent dans la même image) : les mêmes nœuds, les mêmes
## matériaux, l'uniforme change à l'image suivante ; sans beauté, aucune encre.
func _les_encres_basculent(main: Node, p: Node, volumes: IsoVolumes, g: Node2D) -> void:
	var e: Dictionary = volumes.suivi_de(g)
	if e.is_empty():
		return
	var noeuds: Array = (e["noeuds"] as Array).duplicate()
	var encre := volumes.encre_voxel
	var relief := volumes.relief_voxel
	var justes := 0
	for style: String in IsoNuageVoxel.ENCRES:
		volumes.poser_fumee_voxel(true, "", style, "")
		p.call("_suivre")
		var ee: Dictionary = volumes.suivi_de(g)
		if ee.get("noeuds", []) == noeuds and (ee["mats"] as Array).all(func(m): return int((m as ShaderMaterial).get_shader_parameter(
				"encre_style")) == int(IsoNuageVoxel.ENCRES[style])):
			justes += 1
	for r: String in IsoNuageVoxel.RELIEFS:
		volumes.poser_fumee_voxel(true, "", "", r)
		p.call("_suivre")
		var ee: Dictionary = volumes.suivi_de(g)
		if ee.get("noeuds", []) == noeuds and (ee["mats"] as Array).all(func(m): return int((m as ShaderMaterial).get_shader_parameter(
				"relief_style")) == int(IsoNuageVoxel.RELIEFS[r])):
			justes += 1
	volumes.poser_fumee_voxel(true, "", encre, relief)
	p.call("_suivre")
	_check("les %d encres et les %d reliefs basculent sur place, dans les deux vues, sans refaire le nuage" % [
		IsoNuageVoxel.ENCRES.size(), IsoNuageVoxel.RELIEFS.size()], justes == IsoNuageVoxel.ENCRES.size() + IsoNuageVoxel.RELIEFS.size(),
		"%d justes" % justes)
	_check("l'encre suit la beauté, comme celle des murs et des corps (`--sans-beaute` : aucune)",
		_fonction_gd(FileAccess.get_file_as_string("res://iso_nuage_voxel.gd"), "poser_style", true).contains(
			"if IsoMateriaux.beaute_active() else int(ENCRES[\"aucune\"]))"))


## L'HORLOGE DE LA KILLCAM : une copie de gadget, faite par la killcam (`GameState._copie_de_gadget`) et posée à un âge
## REJOUÉ, a ses voxels à cet âge-là — ses traits et son relief sont ceux de l'instant rejoué.
func _l_horloge_de_la_killcam(main: Node, p: Node, volumes: IsoVolumes, g: Node2D) -> void:
	var d: Dictionary = g.call("etat_de_rejeu")
	d["nom"] = "HorlogeKillcam"
	d["age"] = 3.25
	var copie: Node2D = main.call("_copie_de_gadget", d)
	if copie == null:
		_check("la killcam copie la suie", false)
		return
	copie.call("rejouer", d)
	copie.set_physics_process(false)
	await process_frame
	await process_frame
	var e: Dictionary = volumes.suivi_de(copie)
	_check("une copie de killcam (âge rejoué 3,25 s) a ses voxels, et leur horloge est l'âge REJOUÉ dans les deux vues",
		not e.is_empty() and e["genre"] == "nuage_voxel" and (e["mats"] as Array).size() == 2
		and (e["mats"] as Array).all(func(m): return is_equal_approx(float((m as ShaderMaterial).get_shader_parameter("age")), 3.25)),
		str(e.get("genre")))
	copie.queue_free()
	await process_frame


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
		var reduites := not IsoNuageVoxel.est_gv1(volumes.encre_voxel, volumes.relief_voxel)
		var t1: Texture2D = IsoNuageVoxel.planche((nappes[0] as Sprite2D).texture) if reduites and not nappes.is_empty() \
			else ((nappes[0] as Sprite2D).texture if not nappes.is_empty() else null)
		_check("ses %d nappes visibles (une de moins en écran scindé), leur rotation, leur taille, leur opacité ; la planche %s"
			% [nappes.size(), "RÉDUITE" if reduites else "entière (GV1)"],
			int(mat.get_shader_parameter("nb_nappes")) == nappes.size() and nappes.size() >= 2
			and is_equal_approx(reglages[0].x, (nappes[0] as Sprite2D).global_rotation)
			and is_equal_approx(reglages[0].z, Presentation3D.opacite_rendue(nappes[0]))
			and mat.get_shader_parameter("nappe_1") == t1)
		var m0 := e["mats"][0] as ShaderMaterial
		_check("la fusée : ÉQUITÉ — les deux vues reçoivent les mêmes réglages, au choix de leur vue près",
			_ecarts_entre_vues(m0, mat).is_empty(), str(_ecarts_entre_vues(m0, mat)))
		_check("la fusée : l'horloge est son âge de combustion, le même dans les deux vues",
			is_equal_approx(float(mat.get_shader_parameter("age")), maxf(float(f.call("age_combustion")), 0.0))
			and m0.get_shader_parameter("age") == mat.get_shader_parameter("age"))
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
	print("\n[Le rejeu : une fusée de killcam a ses voxels, à son âge rejoué]")
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
	_check("une fusée de rejeu (is_replay) a sa fumée en voxels, à l'horloge de son âge rejoué", not e.is_empty()
		and e["genre"] == "nuage_voxel" and (e["mats"] as Array).all(func(m): return is_equal_approx(
			float((m as ShaderMaterial).get_shader_parameter("age")), maxf(float(f.call("age_combustion")), 0.0))))
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
	# Le retour aux couches (la bascule des bancs, `--fumee-couches` au lancement) : les couches reviennent, les voxels partent.
	volumes.poser_fumee_voxel(false)
	p.call("_suivre")
	var couches := _instantane(main)
	var es: Dictionary = volumes.suivi_de(suie) if suie != null else {}
	var ef: Dictionary = volumes.suivi_de(f)
	_check("les couches rendues, la suie et la fumée reprennent leurs couches", not es.is_empty() and es["genre"] == "volume"
		and not ef.is_empty() and ef["genre"] == "fumee")
	await process_frame
	_check("… et aucun nœud de voxels ne reste", _noeuds_voxels(p).is_empty())
	_check("… et la masse de la suie a repris son dessin", suie != null
		and (suie.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_cartouche_suie.png"))
	_check("les couches rendues, les lumières 2D, les capteurs et les joueurs sont ceux des voxels",
		couches["lumieres"] == avant["lumieres"] and couches["capteurs"] == avant["capteurs"]
		and couches["joueurs"] == avant["joueurs"])
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
