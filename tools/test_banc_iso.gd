## Le banc ISO0.b peut-il démarrer, et sa géométrie tient-elle ?
##
## `tools/banc_iso.gd` ouvre une vraie fenêtre : aucune suite ne peut l'exécuter,
## et un banc hors couverture se périme en silence (la leçon de `test_banc.gd`).
## Cette suite vérifie sans rien rendre :
##   • ses appuis sur le jeu — nœuds de corps `visual*`, `rendu_racine_autorise`,
##     `p1`/`p2`, `SubViewport1`/`SubViewport2` et leurs masques ;
##   • que la couche où il cache les corps n'est lue par AUCUN des deux masques ;
##   • une boîte par rectangle de `merge_rects` sur chaque carte livrée, posée
##     exactement sur le corps de collision que le jeu construit ;
##   • `size = 1080 × sin θ`, par des valeurs connues et non par la formule ;
##   • la correspondance monde → uv de la lightmap aux quatre coins, calculée
##     analytiquement depuis une caméra 2D.
##
## Ce qu'elle ne peut pas voir : ce que le GPU fait de la formule. Ça se vérifie
## à l'image, contre `--base` à 90° de tangage (voir la ROADMAP, section ISO).
##
## Lancer : godot --headless --path . --script res://tools/test_banc_iso.gd
extends SceneTree

const EPSILON := 0.001
## Une suite qui n'a presque rien vérifié doit échouer, pas se taire.
const PLANCHER := 60

var _failures := 0
var _verifications := 0


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
	print("=== LE BANC ISO PEUT-IL DÉMARRER ===")
	await process_frame
	# `load` et non `preload` : le banc nomme les autoloads, qui n'existent pas
	# encore quand ce fichier est compilé (voir test_banc.gd).
	var Banc: GDScript = load("res://tools/banc_iso.gd")
	var Proto: GDScript = load("res://tools/proto_iso.gd")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: Node = main.get_node_or_null("UI")

	# --- Les appuis sur le jeu -------------------------------------------------
	var manquants: Array[String] = Banc.preconditions_manquantes(ui, main)
	_check("tous les appuis du banc iso existent encore", manquants.is_empty(),
		"; ".join(manquants))
	_check("et il sait dire quand ils manquent",
		not (Banc.preconditions_manquantes(null, null) as Array).is_empty())

	var joueur: Node = (load("res://player.tscn") as PackedScene).instantiate()
	var absents_joueur: Array[String] = Banc.appuis_joueur_manquants(joueur)
	_check("les dix nœuds de corps existent sur Player", absents_joueur.is_empty(),
		"; ".join(absents_joueur))
	_check("et leur absence se dit",
		not (Banc.appuis_joueur_manquants(Object.new()) as Array).is_empty())
	# Les quatre nœuds de la scène que `@onready` relie : un renommage dans
	# player.tscn laisserait la variable exister et valoir null.
	for chemin in ["VisualColored", "VisualColored/DirPointer", "VisualDim",
			"VisualDim/DirPointerDim", "VisualReveal", "VisualReveal/DirPointerReveal"]:
		_check("player.tscn porte %s" % chemin, joueur.get_node_or_null(chemin) is CanvasItem)
	joueur.free()

	# --- La couche de visibilité ----------------------------------------------
	# Les masques sont lus APRÈS deux images : le jeu réécrit ceux de main.tscn
	# à l'exécution, et ce sont les vrais qui décident de ce qui se dessine.
	var couche: int = Banc.COUCHE_HORS_VUE
	_check("la couche cachée tient dans les vingt couches de visibilité",
		couche >= 0 and couche < (1 << 20), str(couche))
	for chemin in [Banc.CHEMIN_VUE_1, Banc.CHEMIN_VUE_2]:
		var vue := main.get_node_or_null(chemin) as SubViewport
		_check("%s existe" % chemin, vue != null)
		if vue == null:
			continue
		_check("le masque de %s (%d) ne lit pas la couche %d" % [vue.name,
			vue.canvas_cull_mask, couche], (vue.canvas_cull_mask & couche) == 0)
		# Le masque doit lire QUELQUE CHOSE des corps d'aujourd'hui, sinon le
		# contrôle précédent passerait sur un masque vide.
		_check("et lit la couche des corps de sa vue", (vue.canvas_cull_mask & (2 | 4)) != 0)
	_check("le contrôle de couche sait refuser un masque qui la lit",
		not Banc.couche_absente_du_masque(0xFFFFF, 4))

	# --- La caméra : size = 1080 × sin θ --------------------------------------
	_check("à 90° la vue orthographique vaut 1080",
		absf(Banc.taille_orthographique(90.0) - 1080.0) < EPSILON)
	_check("à 30° elle vaut 540",
		absf(Banc.taille_orthographique(30.0) - 540.0) < EPSILON)
	for t in Banc.TANGAGES:
		var size: float = Banc.taille_orthographique(t)
		_check("tangage %s° : size = 1080 × sin θ (%.2f)" % [str(t), size],
			absf(size - 1080.0 * sin(deg_to_rad(t))) < EPSILON)
		var empreinte: Vector2 = Banc.empreinte_au_sol(t, Vector2(1920, 1080))
		_check("tangage %s° : 1080 px de profondeur au sol" % str(t),
			absf(empreinte.y - 1080.0) < 0.01, str(empreinte))
	var a_plat: Vector2 = Banc.empreinte_au_sol(90.0, Vector2(1920, 1080))
	_check("à 90° l'empreinte est la vue de dessus", a_plat.distance_to(Vector2(1920, 1080)) < 0.01)
	var incline: Vector2 = Banc.empreinte_au_sol(60.0, Vector2(1920, 1080))
	_check("à 60° la largeur au sol n'est plus que 1920 × sin θ (%.0f)" % incline.x,
		absf(incline.x - 1920.0 * sin(deg_to_rad(60.0))) < 0.01)

	# --- Lightmap : tailles des trois variantes -------------------------------
	_check("lightmap plein = aire × étirement",
		Banc.taille_lightmap("plein", Vector2i(1920, 1080), 2.0) == Vector2i(3840, 2160))
	_check("lightmap 1080p = aire logique",
		Banc.taille_lightmap("1080p", Vector2i(957, 1080), 2.0) == Vector2i(957, 1080))
	_check("lightmap demi = moitié",
		Banc.taille_lightmap("demi", Vector2i(1920, 1080), 2.0) == Vector2i(960, 540))

	# --- Monde → uv, aux quatre coins -----------------------------------------
	# Une caméra 2D posée en (700, 400), zoom 1 puis 2 : écran = (monde − caméra)
	# × zoom + taille / 2. Les quatre coins du rectangle couvert doivent tomber
	# sur les quatre coins de la texture.
	var taille := Vector2(1920, 1080)
	for zoom in [1.0, 2.0]:
		var camera := Vector2(700, 400)
		var canevas := Transform2D(0.0, Vector2(zoom, zoom), 0.0, taille * 0.5 - camera * zoom)
		var rect: Rect2 = Banc.rect_couvert(canevas, taille)
		var attendu := Rect2(camera - taille * 0.5 / zoom, taille / zoom)
		_check("zoom %s : rectangle couvert calculé à la main" % str(zoom),
			rect.position.distance_to(attendu.position) < EPSILON
			and rect.size.distance_to(attendu.size) < EPSILON, "%s ≠ %s" % [rect, attendu])
		var coins := {
			Vector2(0, 0): rect.position,
			Vector2(1, 0): rect.position + Vector2(rect.size.x, 0),
			Vector2(0, 1): rect.position + Vector2(0, rect.size.y),
			Vector2(1, 1): rect.end,
		}
		for uv in coins:
			var lu: Vector2 = Banc.uv_de(canevas, taille, coins[uv])
			_check("zoom %s : le coin %s du monde tombe en uv %s" % [str(zoom), coins[uv], uv],
				lu.distance_to(uv) < EPSILON, str(lu))
		var centre: Vector2 = Banc.uv_de(canevas, taille, camera)
		_check("zoom %s : la caméra 2D tombe au centre de la lightmap" % str(zoom),
			centre.distance_to(Vector2(0.5, 0.5)) < EPSILON, str(centre))
	# Une vue tournée : la boîte englobante n'est plus la vue, mais les coins
	# ramenés par l'inverse retombent toujours sur les coins de la texture.
	var tourne := Transform2D(0.3, Vector2(1.5, 1.5), 0.0, Vector2(123, -45))
	for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var monde: Vector2 = tourne.affine_inverse() * (uv * taille)
		_check("vue tournée : uv %s aller-retour" % uv,
			(Banc.uv_de(tourne, taille, monde) as Vector2).distance_to(uv) < EPSILON)

	# --- Une boîte par rectangle, sur le corps de collision du jeu ------------
	var slugs: PackedStringArray = Proto.cartes_livrees()
	_check("six cartes livrées (%d)" % slugs.size(), slugs.size() == 6)
	for slug in slugs:
		var data: Dictionary = Proto.charger_carte_livree(slug)
		_check("%s se lit" % slug, not data.is_empty())
		if data.is_empty():
			continue
		var rects: Array = MapGeometry.merge_rects(
			MapGeometry.build_grid(data, MapGeometry.Kind.WALLS))
		var murs: Node3D = Banc.construire_murs(data, 15.75, null)
		_check("%s : une boîte par rectangle de merge_rects (%d)" % [slug, rects.size()],
			murs.get_child_count() == rects.size() and rects.size() > 0,
			"%d boîtes" % murs.get_child_count())
		# La référence n'est pas le banc : ce sont les formes que le JEU pose.
		var hote := Node2D.new()
		MapGeometry.build_collisions(data, hote)
		var formes := hote.get_node("%s/Murs" % MapGeometry.BODY_NAME).get_children() \
			.filter(func(n): return n is CollisionShape2D)
		var decalees := 0
		for i in mini(formes.size(), murs.get_child_count()):
			var forme: CollisionShape2D = formes[i]
			var boite := murs.get_child(i) as MeshInstance3D
			var taille_forme: Vector2 = (forme.shape as RectangleShape2D).size
			var au_sol := Vector2(boite.position.x, boite.position.z)
			var emprise := Vector2(boite.scale.x, boite.scale.z)
			if au_sol.distance_to(forme.position) > EPSILON \
					or emprise.distance_to(taille_forme) > EPSILON \
					or absf(boite.position.y - boite.scale.y * 0.5) > EPSILON:
				decalees += 1
		_check("%s : chaque boîte recouvre la collision du jeu, posée au sol" % slug,
			decalees == 0 and formes.size() == murs.get_child_count(),
			"%d décalée(s), %d formes" % [decalees, formes.size()])
		hote.free()
		murs.free()

	main.queue_free()
	await process_frame
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER],
		_verifications >= PLANCHER)
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
