## Test headless du prototype de vue isométrique 3D (`tools/proto_iso.gd`).
##
## Ce qu'il garantit, pour CHAQUE carte livrée dans `assets/maps/` :
##   • les murs, les fosses et le sol partitionnent la grille, bordure comprise ;
##   • une boîte par rectangle de mur fusionné, ni plus ni moins ;
##   • les dalles couvrent exactement les cases de sol — chaque case praticable
##     (sol sans mur) une fois, et aucune autre ;
##   • les deux apparitions tombent sur une case de sol, hors de toute boîte ;
##   • toute boîte tient dans la grille + bordure ;
##   • chaque lumière porte des ombres, la caméra est orthographique et active,
##     et son cadrage contient bien la carte ;
##   • le nombre total de `MeshInstance3D` reste sous `PLAFOND_MESH`.
##
## Les comptes sont refaits ICI depuis les nœuds — parcours de l'arbre, boîtes
## englobantes transformées — et non lus dans les compteurs du prototype, qui
## pourraient compter juste et construire faux.
##
## Rien n'est rendu : en headless les nœuds 3D existent, se mesurent, et c'est
## tout ce dont ces contrôles ont besoin. Les captures, elles, se font sous une
## vraie fenêtre (voir l'en-tête du prototype).
##
## Lancer : godot --headless --path . --script res://tools/test_proto_iso.gd
extends SceneTree

## Plafond de `MeshInstance3D` pour une carte. Un `MeshInstance3D` est un appel de
## dessin ; la plus grande carte livrée compte 900 cases de mur et de sol, et
## une boîte par CASE en ferait autant. La fusion doit en laisser un ordre de
## grandeur de moins : mesuré le 2026-09-13, la plus chargée (« L Usine »,
## 32×26) tient en **32** mesh, joueurs compris — 11 murs, 17 dalles, 4 pour
## les joueurs. 200 laisse six fois cette marge à une carte plus tortueuse, et
## reste cinq fois sous le pavage naïf : au-delà, c'est la fusion qui a cessé de
## fusionner, pas la carte qui a grandi.
const PLAFOND_MESH := 200
## Nombre de vérifications en dessous duquel la suite ne peut pas être verte :
## une suite qui n'a rien vérifié doit échouer, pas se taire.
const PLANCHER := 60
const EPSILON := 0.001

var _failures: int = 0
var _verifications: int = 0

func _init() -> void:
	print("=== Test prototype isométrique 3D ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var Proto: GDScript = load("res://tools/proto_iso.gd")
	var scene: PackedScene = load("res://tools/proto_iso.tscn")
	_check("proto_iso.tscn se charge", scene != null)
	if scene == null or Proto == null:
		_terminer()
		return
	var proto: Node3D = scene.instantiate()
	_check("la scène porte le script du prototype", proto.get_script() == Proto)
	root.add_child(proto)

	var slugs: PackedStringArray = Proto.cartes_livrees()
	_check("au moins quatre cartes livrées trouvées (%d)" % slugs.size(), slugs.size() >= 4)
	for slug in slugs:
		_test_carte(Proto, proto, slug)

	_test_flash(Proto, proto)
	_test_presets(proto)

	root.remove_child(proto)
	proto.free()
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
# UNE CARTE
# ---------------------------------------------------------------------------

func _test_carte(Proto: GDScript, proto: Node3D, slug: String) -> void:
	print("\n[%s]" % slug)
	var data: Dictionary = Proto.charger_carte_livree(slug)
	_check("carte lisible", not data.is_empty())
	if data.is_empty():
		return
	proto.carte_slug = slug
	proto.flash = false
	proto.construire(data)

	var grille := MapCodec.get_grid_size(data)
	var b: int = MapGeometry.BORDER
	var largeur: int = grille.x + 2 * b
	var hauteur: int = grille.y + 2 * b

	# --- Partition de la grille -------------------------------------------
	var rects: Dictionary = Proto.rectangles_de(data)
	_check("dimensions de grille = carte + bordure", rects["grille"] == Vector2i(largeur, hauteur),
		str(rects["grille"]))
	var cases := 0
	for cle in ["murs", "fosses", "sol"]:
		for r: Rect2i in rects[cle]:
			cases += r.size.x * r.size.y
	_check("murs + fosses + sol pavent la grille (%d cases)" % cases, cases == largeur * hauteur,
		"%d attendues" % (largeur * hauteur))

	# --- Les murs : une boîte par rectangle --------------------------------
	var murs: Array[MeshInstance3D] = []
	_collecter(proto.get_node("Decor/Murs"), murs)
	var nb_rect_murs: int = (rects["murs"] as Array).size()
	_check("une boîte par rectangle de mur (%d)" % nb_rect_murs, murs.size() == nb_rect_murs,
		"%d boîtes" % murs.size())
	_check("le compteur du prototype dit la même chose", proto.nombre_de_boites_murs() == murs.size())

	# --- Le sol : les dalles couvrent exactement les cases praticables ------
	var praticables := _cases_praticables(data)
	var dalles: Array[MeshInstance3D] = []
	_collecter(proto.get_node("Decor/Sol"), dalles)
	var couvertes := {}
	var doublons := 0
	var hors_sol := 0
	var dalle_immesurable := 0
	for dalle in dalles:
		var boite := _boite_monde(dalle)
		if boite.size.x < EPSILON or boite.size.z < EPSILON:
			dalle_immesurable += 1
			continue
		var x0 := roundi(boite.position.x)
		var z0 := roundi(boite.position.z)
		var l := roundi(boite.size.x)
		var p := roundi(boite.size.z)
		for cx in range(x0, x0 + l):
			for cz in range(z0, z0 + p):
				var c := Vector2i(cx, cz)
				if couvertes.has(c):
					doublons += 1
				couvertes[c] = true
				if not praticables.has(c):
					hors_sol += 1
	_check("chaque dalle se mesure (AABB non vide)", dalle_immesurable == 0, "%d" % dalle_immesurable)
	_check("les dalles couvrent %d cases praticables" % praticables.size(),
		couvertes.size() == praticables.size(), "%d couvertes" % couvertes.size())
	_check("aucune case couverte deux fois", doublons == 0, "%d" % doublons)
	_check("aucune dalle hors du sol praticable", hors_sol == 0, "%d cases" % hors_sol)
	_check("le compteur de dalles est juste", proto.nombre_de_dalles_sol() == dalles.size())

	# --- Les apparitions -------------------------------------------------
	for idx in 2:
		var spawn := MapCodec.get_spawn(data, idx)
		_check("J%d apparaît sur une case de sol %s" % [idx + 1, str(spawn)], praticables.has(spawn))
		var joueur := proto.get_node_or_null("Decor/Joueurs/J%d" % (idx + 1)) as Node3D
		_check("J%d est construit" % (idx + 1), joueur != null)
		if joueur == null:
			continue
		var pied := joueur.global_position + Vector3(0.0, 0.45, 0.0)
		var dans_un_mur := false
		for mur in murs:
			if _boite_monde(mur).has_point(pied):
				dans_un_mur = true
				break
		_check("J%d n'est dans aucune boîte de mur" % (idx + 1), not dans_un_mur)

	# --- Tout tient dans la grille + bordure --------------------------------
	var bornes: AABB = proto.bornes_monde()
	var toutes: Array[MeshInstance3D] = []
	_collecter(proto, toutes)
	var dehors := 0
	for mesh in toutes:
		var boite := _boite_monde(mesh)
		if not bornes.grow(EPSILON).encloses(boite):
			dehors += 1
	_check("toutes les boîtes tiennent dans la grille + bordure", dehors == 0, "%d dehors" % dehors)
	_check("bornes : la grille bordure comprise", roundi(bornes.size.x) == largeur
		and roundi(bornes.size.z) == hauteur, str(bornes))

	# --- Lumières et caméra ----------------------------------------------
	var lumieres: Array[Light3D] = []
	_collecter_lumieres(proto, lumieres)
	_check("quatre lumières sans flash (torche + halo par joueur)", lumieres.size() == 4,
		"%d" % lumieres.size())
	var sans_ombre := 0
	for l in lumieres:
		if not l.shadow_enabled:
			sans_ombre += 1
	_check("toutes les lumières portent des ombres", sans_ombre == 0, "%d sans ombre" % sans_ombre)
	var torches := 0
	for l in lumieres:
		if l is SpotLight3D:
			torches += 1
	_check("deux torches (SpotLight3D)", torches == 2, "%d" % torches)

	var cameras: Array[Camera3D] = []
	_collecter_cameras(proto, cameras)
	_check("une seule caméra", cameras.size() == 1, "%d" % cameras.size())
	if cameras.size() == 1:
		var cam := cameras[0]
		_check("caméra orthographique", cam.projection == Camera3D.PROJECTION_ORTHOGONAL)
		_check("caméra active", cam.current)
		_check("cadrage : la carte entière est dans l'image", _carte_dans_le_cadre(cam, bornes, proto.aspect()))

	# --- Le plafond ------------------------------------------------------
	var total: int = proto.nombre_de_mesh_instances()
	_check("%d MeshInstance3D comptés = %d trouvés" % [total, toutes.size()], total == toutes.size())
	_check("sous le plafond de %d MeshInstance3D (%d)" % [PLAFOND_MESH, total], total <= PLAFOND_MESH)
	print("  · murs=%d fosses=%d sol=%d mesh=%d" % [nb_rect_murs, (rects["fosses"] as Array).size(),
		(rects["sol"] as Array).size(), total])

# ---------------------------------------------------------------------------
# LE FLASH ET LES PRÉRÉGLAGES
# ---------------------------------------------------------------------------

func _test_flash(Proto: GDScript, proto: Node3D) -> void:
	print("\n[Flash de tir]")
	var data: Dictionary = Proto.charger_carte_livree("default")
	proto.flash = true
	proto.construire(data)
	var lumieres: Array[Light3D] = []
	_collecter_lumieres(proto, lumieres)
	_check("cinq lumières avec le flash", lumieres.size() == 5, "%d" % lumieres.size())
	var eclair := proto.get_node_or_null("Decor/Joueurs/J1/Flash") as OmniLight3D
	_check("le flash est un OmniLight3D sur J1", eclair != null)
	if eclair != null:
		_check("le flash porte des ombres", eclair.shadow_enabled)
		_check("le flash est bien une lumière allumée", eclair.visible and eclair.light_energy > 0.0)
	_check("J2 n'a pas de flash", proto.get_node_or_null("Decor/Joueurs/J2/Flash") == null)
	proto.flash = false
	proto.construire(data)
	_collecter_lumieres(proto, lumieres)
	_check("reconstruire sans flash le retire (%d lumières)" % lumieres.size(), lumieres.size() == 4)

func _test_presets(proto: Node3D) -> void:
	print("\n[Préréglages de caméra]")
	var attendus := {
		"unrailed": Vector2(52.0, 45.0),
		"iso": Vector2(35.264, 45.0),
		"dessus_incline": Vector2(70.0, 45.0),
		"dessus": Vector2(90.0, 0.0),
	}
	proto.pitch_deg = NAN
	proto.yaw_deg = NAN
	for nom: String in attendus:
		proto.preset = nom
		var angles: Vector2 = proto.angles_camera()
		_check("preset %s → pitch %.3f / yaw %.0f" % [nom, attendus[nom].x, attendus[nom].y],
			angles.is_equal_approx(attendus[nom]), str(angles))
	proto.preset = "unrailed"
	proto.pitch_deg = 61.0
	_check("un pitch libre recouvre le préréglage", is_equal_approx(proto.angles_camera().x, 61.0))
	_check("le yaw reste celui du préréglage", is_equal_approx(proto.angles_camera().y, 45.0))
	proto.pitch_deg = NAN
	# La caméra à la verticale ne doit pas se perdre : pas de `look_at`, donc
	# aucune dégénérescence quand « haut » et l'axe de vue sont parallèles.
	proto.preset = "dessus"
	proto.construire(proto.charger_carte_livree("default"))
	var cam: Camera3D = proto.camera()
	_check("à 90° la caméra regarde vers le bas", cam != null and (-cam.basis.z).is_equal_approx(Vector3.DOWN),
		str(-cam.basis.z) if cam != null else "pas de caméra")
	_check("à 90° le haut de l'image est le nord de la carte (-z)",
		cam != null and cam.basis.y.is_equal_approx(Vector3(0.0, 0.0, -1.0)),
		str(cam.basis.y) if cam != null else "pas de caméra")
	_check("le cadrage à la verticale contient la carte", cam != null
		and _carte_dans_le_cadre(cam, proto.bornes_monde(), proto.aspect()))
	proto.preset = "unrailed"

# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

## Cases sur lesquelles on marche : du sol, dans la grille, sans mur dessus —
## la définition de `MapCodec.check_playable()`.
func _cases_praticables(data: Dictionary) -> Dictionary:
	var grille := MapCodec.get_grid_size(data)
	var out := {}
	for c in MapCodec.get_floor_cells(data):
		if c.x >= 0 and c.y >= 0 and c.x < grille.x and c.y < grille.y:
			out[c] = true
	for c in MapCodec.get_wall_cells(data):
		out.erase(c)
	return out

## Boîte englobante d'un maillage dans le repère monde.
func _boite_monde(mesh: MeshInstance3D) -> AABB:
	return mesh.global_transform * mesh.get_aabb()

func _collecter(noeud: Node, out: Array[MeshInstance3D]) -> void:
	out.clear()
	_collecter_rec(noeud, out)

func _collecter_rec(noeud: Node, out: Array[MeshInstance3D]) -> void:
	if noeud is MeshInstance3D:
		out.append(noeud)
	for enfant in noeud.get_children():
		_collecter_rec(enfant, out)

func _collecter_lumieres(noeud: Node, out: Array[Light3D]) -> void:
	out.clear()
	_collecter_lumieres_rec(noeud, out)

func _collecter_lumieres_rec(noeud: Node, out: Array[Light3D]) -> void:
	if noeud is Light3D:
		out.append(noeud)
	for enfant in noeud.get_children():
		_collecter_lumieres_rec(enfant, out)

func _collecter_cameras(noeud: Node, out: Array[Camera3D]) -> void:
	if noeud is Camera3D:
		out.append(noeud)
	for enfant in noeud.get_children():
		_collecter_cameras(enfant, out)

## Les huit coins de `bornes`, projetés dans le repère de la caméra, tiennent-ils
## dans le rectangle de vue (`size` en hauteur, `size × ratio` en largeur) ?
func _carte_dans_le_cadre(cam: Camera3D, bornes: AABB, ratio: float) -> bool:
	var inverse := cam.global_transform.affine_inverse()
	var demi_h := cam.size * 0.5
	var demi_l := demi_h * ratio
	for i in 8:
		var local := inverse * bornes.get_endpoint(i)
		if absf(local.x) > demi_l + EPSILON or absf(local.y) > demi_h + EPSILON:
			return false
		# Et entre les deux plans de coupe, sinon la caméra tronque la carte.
		if -local.z < cam.near or -local.z > cam.far:
			return false
	return true
