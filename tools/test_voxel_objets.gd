## Test headless des objets debout voxel (`voxel_objets.gd` +
## `voxel_catalogue_objets.gd`) — chantier ISO, étape ISO3, vague 3.
##
## Ce que la suite garantit :
##   • chaque objet du catalogue se construit (neuf/plusieurs boîtes selon
##     l'objet, jamais zéro) ;
##   • hauteur totale ≤ `VoxelCatalogueObjets.HAUTEUR_MAX` (0,25 tuile),
##     allumé/éteint compris (l'état le plus haut est mesuré) ;
##   • empreinte au sol ≤ rayon de collision réel de l'objet × la marge posée
##     par le brief (10 % au plus) ;
##   • couleur nulle (noir strict) à `lumiere_recue = 0` ;
##   • `poser(etat)` est déterministe : même état → même pose ;
##   • `boites()` cohérent — même compte que `nombre_de_boites()`, chaque
##     boîte visible porte son double en profondeur, en enfant ;
##   • ni `voxel_objets.gd` ni `voxel_catalogue_objets.gd` n'appellent
##     `randi`/`randf` ;
##   • deux instances construites côte à côte restent indépendantes (poser
##     l'une ne change rien à l'autre) ;
##   • le leurre (`VoxelCorps` posé avec `arme_baissee: true`, voir l'en-tête
##     de `voxel_objets.gd`) porte bien la classe du poseur et abaisse
##     réellement l'arme.
##
## Lancer : godot --headless --path . --script res://tools/test_voxel_objets.gd
extends SceneTree

const PLANCHER := 20

var _failures: int = 0
var _verifications: int = 0


func _init() -> void:
	print("=== Test des objets debout voxel (ISO3 vague 3) ===")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var VoxelObjetT: GDScript = load("res://voxel_objets.gd")
	var VoxelCatalogueObjetsT: GDScript = load("res://voxel_catalogue_objets.gd")
	var VoxelCorpsT: GDScript = load("res://voxel_corps.gd")
	_check("voxel_objets.gd se charge", VoxelObjetT != null)
	_check("voxel_catalogue_objets.gd se charge", VoxelCatalogueObjetsT != null)
	if VoxelObjetT == null or VoxelCatalogueObjetsT == null:
		_terminer()
		return

	_test_aucun_hasard()

	var slugs: PackedStringArray = VoxelCatalogueObjetsT.slugs()
	_check("au moins un objet dans le catalogue (%d)" % slugs.size(), slugs.size() > 0)

	for slug in slugs:
		_test_objet(VoxelObjetT, VoxelCatalogueObjetsT, slug)

	_test_instances_independantes(VoxelObjetT)
	_test_leurre(VoxelCorpsT)

	_check("au moins %d vérifications ont réellement tourné" % PLANCHER,
		_verifications >= PLANCHER, "%d" % _verifications)
	_terminer()


func _terminer() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	_verifications += 1
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


# ---------------------------------------------------------------------------
# UN OBJET
# ---------------------------------------------------------------------------

func _test_objet(VoxelObjetT: GDScript, VoxelCatalogueObjetsT: GDScript, slug: String) -> void:
	print("\n[%s]" % slug)
	var objet: Node3D = VoxelObjetT.new()
	root.add_child(objet)

	var ok: bool = objet.construire(slug)
	_check("construction réussie", ok)
	if not ok:
		root.remove_child(objet)
		objet.free()
		return

	_check("au moins une boîte (%d)" % objet.nombre_de_boites(), objet.nombre_de_boites() > 0,
		"%d" % objet.nombre_de_boites())
	_check("boites() a le même compte que nombre_de_boites()",
		objet.boites().size() == objet.nombre_de_boites())

	var mat_p: ShaderMaterial = objet.materiau_profondeur()
	var toutes_ont_leur_double := true
	var meme_maillage := true
	for b in objet.boites():
		var boite: MeshInstance3D = b
		var double: Node = boite.get_node_or_null(boite.name + "Profondeur")
		if double == null or not (double is MeshInstance3D):
			toutes_ont_leur_double = false
			continue
		var mi: MeshInstance3D = double
		if mi.mesh != boite.mesh:
			meme_maillage = false
		if mi.material_override != mat_p:
			toutes_ont_leur_double = false
	_check("chaque boîte a son double en profondeur, en enfant", toutes_ont_leur_double)
	_check("le double partage le même maillage que la boîte visible", meme_maillage)
	_check("le double est à la priorité de rendu -1", mat_p.render_priority == -1)

	# Hauteur : mesurée dans les DEUX états d'un repère animé (allumé/éteint),
	# jamais un seul — l'état le plus haut est celui qui compte pour l'équité.
	var h_max := 0.0
	for allumee in [false, true]:
		for eteinte in [false, true]:
			objet.poser({"position": Vector2.ZERO, "orientation": Vector2.DOWN,
				"allumee": allumee, "eteinte": eteinte})
			h_max = maxf(h_max, objet.hauteur_totale())
	var plafond: float = VoxelCatalogueObjetsT.HAUTEUR_MAX
	_check("hauteur ≤ %.2f tuile (plafond d'équité, mesuré %.4f)" % [plafond, h_max],
		h_max <= plafond + 0.0001, "%.4f" % h_max)

	# Empreinte : comparée au rayon de collision RÉEL de l'objet, recopié du
	# gadget (jamais réinventé) — voir `VoxelCatalogueObjets.OBJETS`.
	var rayon_reel: float = VoxelCatalogueObjetsT.rayon_collision_tuiles(slug)
	var marge: float = VoxelCatalogueObjetsT.MARGE_EMPREINTE
	var empreinte: float = objet.rayon_empreinte()
	_check("empreinte au sol ≤ rayon de collision réel × %.2f (%.4f ≤ %.4f)"
			% [marge, empreinte, rayon_reel * marge],
		empreinte <= rayon_reel * marge + 0.0001, "%.4f" % empreinte)

	# Noir absolu : la couleur de la fiche multipliée par une lumière nulle
	# doit rendre un facteur strictement nul — même contrat que les corps.
	var mat: ShaderMaterial = objet.materiau()
	_check("lumiere_recue à 0 par défaut",
		mat.get_shader_parameter("lumiere_recue") == 0.0)
	var couleur: Color = mat.get_shader_parameter("couleur_fiche")
	_check("la couleur de la fiche n'est pas déjà noire (sinon le test ne prouve rien)",
		couleur.r + couleur.g + couleur.b > 0.01)
	objet.definir_lumiere(0.6)
	objet.definir_lumiere(0.0)
	_check("definir_lumiere(0.0) ramène bien lumiere_recue à 0",
		mat.get_shader_parameter("lumiere_recue") == 0.0)

	# Déterminisme : même état → même pose, sur la position de chaque boîte.
	var etat := {"position": Vector2(70.0, -35.0), "orientation": Vector2(1.0, 0.3),
		"allumee": true, "eteinte": false}
	objet.poser(etat)
	var avant: Array = objet.boites().map(func(b): return b.global_transform)
	objet.poser({"position": Vector2.ZERO, "orientation": Vector2.DOWN})
	objet.poser(etat)
	var apres: Array = objet.boites().map(func(b): return b.global_transform)
	var identiques := avant.size() == apres.size()
	if identiques:
		for i in avant.size():
			if not avant[i].is_equal_approx(apres[i]):
				identiques = false
				break
	_check("même état → même pose", identiques)

	root.remove_child(objet)
	objet.free()


# ---------------------------------------------------------------------------
# DEUX INSTANCES INDÉPENDANTES
# ---------------------------------------------------------------------------

func _test_instances_independantes(VoxelObjetT: GDScript) -> void:
	var a: Node3D = VoxelObjetT.new()
	var b: Node3D = VoxelObjetT.new()
	root.add_child(a)
	root.add_child(b)
	a.construire("mine")
	b.construire("mine")

	a.poser({"position": Vector2(140.0, 0.0), "orientation": Vector2.DOWN, "allumee": true})
	b.poser({"position": Vector2.ZERO, "orientation": Vector2.DOWN, "allumee": false})

	_check("deux instances gardent des positions distinctes",
		not a.position.is_equal_approx(b.position))
	_check("allumer l'une ne change pas la hauteur de l'autre",
		not is_equal_approx(a.hauteur_totale(), b.hauteur_totale()))

	b.poser({"position": Vector2.ZERO, "orientation": Vector2.DOWN, "allumee": true})
	_check("l'autre instance peut ensuite s'allumer à son tour, sans dépendre de la première",
		is_equal_approx(a.hauteur_totale(), b.hauteur_totale()))

	root.remove_child(a)
	root.remove_child(b)
	a.free()
	b.free()


# ---------------------------------------------------------------------------
# LE LEURRE — un VoxelCorps, pas un objet neuf
# ---------------------------------------------------------------------------

func _test_leurre(VoxelCorpsT: GDScript) -> void:
	var corps: Node3D = VoxelCorpsT.new()
	root.add_child(corps)
	var classe_du_poseur := "spectre"
	var ok: bool = corps.construire(classe_du_poseur)
	_check("le leurre construit un VoxelCorps de la classe du poseur", ok)
	if not ok:
		root.remove_child(corps)
		corps.free()
		return
	_check("le leurre porte la bonne classe (%s)" % classe_du_poseur,
		corps.slug() == classe_du_poseur)

	# Debout, arme levée (garde), pour mesurer l'angle de référence.
	corps.poser({
		"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
		"torche": false, "arme": classe_du_poseur, "tir": false, "touche": false,
		"mort": false, "arme_baissee": false, "t": 0.0,
	})
	var arme_pivot_leve: Node3D = corps.get_node("Torse/Arme")
	var angle_leve := arme_pivot_leve.rotation.x

	corps.poser({
		"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
		"torche": false, "arme": classe_du_poseur, "tir": false, "touche": false,
		"mort": false, "arme_baissee": true, "t": 0.0,
	})
	var arme_pivot_baisse: Node3D = corps.get_node("Torse/Arme")
	var angle_baisse := arme_pivot_baisse.rotation.x
	_check("arme_baissee: true abaisse réellement l'arme (%.3f → %.3f rad)"
			% [angle_leve, angle_baisse],
		angle_baisse < angle_leve - 0.5, "%.3f puis %.3f" % [angle_leve, angle_baisse])

	_check("le leurre n'allume pas de torche (torche: false masque le maillage)",
		not corps.get_node("Torse/Torche/Boite").visible)

	root.remove_child(corps)
	corps.free()


# ---------------------------------------------------------------------------
# AUCUN HASARD
# ---------------------------------------------------------------------------

func _test_aucun_hasard() -> void:
	for chemin in ["res://voxel_objets.gd", "res://voxel_catalogue_objets.gd"]:
		var src := FileAccess.get_file_as_string(chemin)
		_check("%s lisible" % chemin, not src.is_empty())
		var suspect := false
		for ligne in src.split("\n"):
			var code := ligne.strip_edges().split("#")[0]
			if code.contains("randi") or code.contains("randf") or code.contains("randomize"):
				suspect = true
				break
		_check("%s n'appelle aucun hasard" % chemin, not suspect)
