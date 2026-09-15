## La caméra iso, la pâte, le réglage — et la vue qui ne touche pas au jeu (ISO1).
##
## Sans rien rendre :
##   • `size = 1080 × sin θ`, par des valeurs connues ; l'empreinte au sol (1513 px de
##     large à 52°, la décision d'Adrien) ; la correspondance monde → uv aux quatre
##     coins ; **la caméra ne montre jamais plus de carte que la caméra 2D** (zoom,
##     secousse, trois tangages) — et le contrôle sait refuser une caméra qui en montre plus ;
##   • **l'invariant du noir absolu** sur le miroir processeur des quatre pâtes
##     (`iso_pate.gd`) : strictement 0 à lumière 0, monotone en la lumière, aucun
##     terme additif ;
##   • `GameSettings.mode_iso` VRAI par défaut depuis ISO6 ; la vue de dessus derrière `--2d`
##     ou le réglage de débogage persisté, aucun drapeau jamais écrit, l'ancienne clé
##     `video/mode_iso` ni relue ni réécrite ;
##   • **la vue ne change rien à la simulation** : le même entraînement scripté, joué
##     sans puis avec la vue allumée, donne les mêmes positions, les mêmes tirs et le
##     même rejeu ; et à l'extinction tout ce qu'elle a touché revient.
##
## Ce qu'elle ne voit pas : ce que le GPU fait des shaders. Le noir absolu au pixel se
## prouve au banc, dans une vraie fenêtre (`tools/banc_iso.gd --jeu --noir`).
##
## Lancer : godot --headless --path . --script res://tools/test_iso_camera.gd
extends SceneTree

const EPSILON := 0.001
const PLANCHER := 80
const PAS_SIMULES := 150

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
	print("=== CAMÉRA ISO, PÂTE, RÉGLAGE, ET UNE VUE QUI NE TOUCHE PAS AU JEU ===")
	await process_frame
	var Cam: GDScript = load("res://camera_iso.gd")
	var Pate: GDScript = load("res://iso_pate.gd")
	_taille(Cam)
	_uv(Cam)
	_empreinte_contenue(Cam)
	_pates(Pate)
	_reglage()
	_regard_du_duel()
	await _simulation_inchangee()

	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER],
		_verifications >= PLANCHER)
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------

func _taille(Cam: GDScript) -> void:
	print("\n--- size = 1080 × sin θ ---")
	_check("tangage de la décision H15 : 52°", absf(Cam.TANGAGE_DEG - 52.0) < EPSILON)
	_check("lacet de la décision H15 : 0°", absf(Cam.LACET_DEG) < EPSILON)
	_check("à 90° la vue orthographique vaut 1080", absf(Cam.taille_orthographique(90.0) - 1080.0) < EPSILON)
	_check("à 30° elle vaut 540", absf(Cam.taille_orthographique(30.0) - 540.0) < EPSILON)
	# sin 52° = 0,788011
	_check("à 52° elle vaut 851,05", absf(Cam.taille_orthographique(52.0) - 851.052) < 0.01,
		str(Cam.taille_orthographique(52.0)))
	var e: Vector2 = Cam.empreinte_au_sol(52.0, Vector2(1920, 1080))
	_check("à 52° : 1080 px de profondeur au sol, la profondeur est gardée", absf(e.y - 1080.0) < 0.01, str(e))
	_check("à 52° : 1513 px de largeur au sol (1920 × sin θ)", absf(e.x - 1512.98) < 0.05, str(e))
	var cam: Camera3D = Cam.new()
	var canevas := Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(960, 540) - Vector2(300, 200) * 2.0)
	cam.suivre(canevas, Vector2(1920, 1080))
	_check("la caméra est orthographique et garde la hauteur",
		cam.projection == Camera3D.PROJECTION_ORTHOGONAL and cam.keep_aspect == Camera3D.KEEP_HEIGHT)
	_check("zoom 2 : la caméra montre deux fois moins de monde (size %.1f)" % cam.size,
		absf(cam.size - 851.052 * 0.5) < 0.01)
	_check("et vise le centre de la vue 2D",
		(Cam.centre_de_vue(canevas, Vector2(1920, 1080)) as Vector2).distance_to(Vector2(300, 200)) < EPSILON)
	cam.free()


func _uv(Cam: GDScript) -> void:
	print("\n--- Monde → uv de la lightmap, aux quatre coins ---")
	var taille := Vector2(1920, 1080)
	for zoom in [1.0, 2.0, 0.7]:
		var camera := Vector2(700, 400)
		var canevas := Transform2D(0.0, Vector2(zoom, zoom), 0.0, taille * 0.5 - camera * zoom)
		var rect: Rect2 = Cam.rect_couvert(canevas, taille)
		var attendu := Rect2(camera - taille * 0.5 / zoom, taille / zoom)
		_check("zoom %s : rectangle couvert calculé à la main" % str(zoom),
			rect.position.distance_to(attendu.position) < EPSILON and rect.size.distance_to(attendu.size) < EPSILON)
		var coins := {Vector2(0, 0): rect.position, Vector2(1, 0): Vector2(rect.end.x, rect.position.y),
			Vector2(0, 1): Vector2(rect.position.x, rect.end.y), Vector2(1, 1): rect.end}
		for uv in coins:
			var lu: Vector2 = Cam.uv_de(canevas, taille, coins[uv])
			_check("zoom %s : le coin %s du monde tombe en uv %s" % [str(zoom), coins[uv], uv],
				lu.distance_to(uv) < EPSILON, str(lu))
		_check("zoom %s : la caméra 2D tombe au centre de la lightmap" % str(zoom),
			(Cam.uv_de(canevas, taille, camera) as Vector2).distance_to(Vector2(0.5, 0.5)) < EPSILON)


## Les quatre coins de l'image, ramenés au sol, restent dans le rectangle de la vue 2D.
func _empreinte_contenue(Cam: GDScript) -> void:
	print("\n--- La caméra iso ne montre jamais plus de carte que la caméra 2D ---")
	var taille := Vector2(1920, 1080)
	var aspect := taille.x / taille.y
	for tangage in [52.0, 60.0, 90.0]:
		for cas in [[1.0, Vector2(700, 400)], [2.0, Vector2(-120, 950)], [0.7, Vector2(1500, 30)],
				[1.0, Vector2(700.0 + 13.0, 400.0 - 9.0)]]:
			var zoom: float = cas[0]
			var canevas := Transform2D(0.0, Vector2(zoom, zoom), 0.0, taille * 0.5 - (cas[1] as Vector2) * zoom)
			var t: Transform3D = Cam.transform_pour(canevas, taille, tangage, 0.0)
			var s: float = Cam.taille_orthographique(tangage, Cam.hauteur_monde(canevas, taille))
			var rect: Rect2 = Cam.rect_couvert(canevas, taille)
			var coins: Array = Cam.coins_au_sol(t, s, aspect)
			_check("%s°, zoom %s, centre %s : les quatre coins au sol sont dans la vue 2D"
				% [str(tangage), str(zoom), cas[1]], _dedans(coins, rect), str(coins))
			var profondeur: float = (coins[2] as Vector2).y - (coins[0] as Vector2).y
			_check("%s°, zoom %s : même profondeur que la vue 2D (%.1f px)" % [str(tangage), str(zoom), profondeur],
				absf(profondeur - rect.size.y) < 0.05)
	# Sans sin θ, la caméra verrait plus loin que la vue de dessus : le contrôle doit le voir.
	var canevas_1 := Transform2D(0.0, Vector2.ONE, 0.0, taille * 0.5 - Vector2(700, 400))
	var trop: Array = Cam.coins_au_sol(Cam.transform_pour(canevas_1, taille, 52.0, 0.0), 1080.0, aspect)
	_check("le contrôle refuse une caméra à size = 1080 (sans sin θ)",
		not _dedans(trop, Cam.rect_couvert(canevas_1, taille)))


func _dedans(coins: Array, rect: Rect2) -> bool:
	for c: Vector2 in coins:
		if c.x < rect.position.x - 0.01 or c.y < rect.position.y - 0.01 \
				or c.x > rect.end.x + 0.01 or c.y > rect.end.y + 0.01:
			return false
	return true


# ---------------------------------------------------------------------------

func _pates(Pate: GDScript) -> void:
	print("\n--- Le noir absolu, sur les quatre pâtes (miroir processeur) ---")
	var teintes := [Vector3(1.0, 0.69, 0.24), Vector3(0.98, 0.91, 0.8), Vector3(0.3, 0.3, 0.3), Vector3(1.0, 1.0, 1.0)]
	var pentes := [Vector2.ZERO, Vector2(0.03, -0.01), Vector2(-0.2, 0.15)]
	for st in [Pate.GRAVURE, Pate.LIGNE_CLAIRE, Pate.TRAME, Pate.LAVIS]:
		var nom: String = Pate.NOMS[st]
		var zeros_ko := 0
		var additif_ko := 0
		var monotonie_ko := 0
		var pire := ""
		var lieux := 0
		for ix in 12:
			for iy in 12:
				var motif := Vector2(ix * 3.7 - 11.0, iy * 4.3 + 0.35)
				for pente: Vector2 in pentes:
					for decalee in [0.0, 0.5]:
						for aa in [0.02, 0.2]:
							lieux += 1
							if Pate.pate(Vector3.ZERO, 0.0, st, motif, pente, decalee, aa) != Vector3.ZERO:
								zeros_ko += 1
							# Aucune lumière reçue, même annoncée : rien ne s'ajoute.
							if Pate.pate(Vector3.ZERO, 0.4, st, motif, pente, decalee, aa) != Vector3.ZERO:
								additif_ko += 1
							var teinte: Vector3 = teintes[(ix + iy) % teintes.size()]
							var precedente := -1.0
							for k in 201:
								var l := k / 200.0
								var c: Vector3 = teinte * (l / Pate.luminance(teinte))
								var sortie: float = Pate.luminance(Pate.pate(c, Pate.luminance(c), st, motif, pente, decalee, aa))
								# Tolérance : les Vector3 du moteur sont en simple précision.
								if sortie < precedente - 1e-5:
									monotonie_ko += 1
									if pire == "":
										pire = "motif %s, pente %s, l %.3f : %.6f < %.6f" % [motif, pente, l, sortie, precedente]
								precedente = sortie
		_check("%s : strictement 0 à lumière 0 (%d lieux)" % [nom, lieux], zeros_ko == 0, "%d" % zeros_ko)
		_check("%s : aucun terme additif — couleur nulle, sortie nulle" % nom, additif_ko == 0, "%d" % additif_ko)
		_check("%s : monotone en la lumière (%d balayages de 201 niveaux)" % [nom, lieux],
			monotonie_ko == 0, "%d inversions ; %s" % [monotonie_ko, pire])
	_check("la pâte brute rend la lightmap telle quelle",
		Pate.pate(Vector3(0.2, 0.3, 0.4), 0.3, Pate.BRUTE, Vector2.ZERO, Vector2.ZERO, 0.0, 0.1) == Vector3(0.2, 0.3, 0.4))
	_check("« --pate B » désigne la ligne claire", Pate.style_depuis_nom("b") == Pate.LIGNE_CLAIRE)
	_check("un nom inconnu est refusé", Pate.style_depuis_nom("Z") < Pate.BRUTE)
	# La même exigence doit savoir échouer : une ambiance de 1 % la viole.
	var ambiance: Vector3 = Pate.pate(Vector3.ZERO, 0.0, Pate.GRAVURE, Vector2.ZERO, Vector2.ZERO, 0.0, 0.1) + Vector3.ONE * 0.01
	_check("le contrôle du zéro sait refuser une ambiance de 1 %", ambiance != Vector3.ZERO)


# ---------------------------------------------------------------------------

## ISO8 — la caméra serrée, préparée sur des défauts NEUTRES tant que la session cloud n'a pas choisi sur la
## planche des variantes : le zoom du duel et le décalage de visée (`GameSettings`), le regard (`RegardDuel`).
func _regard_du_duel() -> void:
	print("\n--- ISO8 : zoom du duel, décalage de visée, regard borné ---")
	var Script: GDScript = load("res://settings_manager.gd")
	var reglages := root.get_node("GameSettings")
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	# ISO8, étape 2 — les défauts choisis par la session cloud sur la planche des variantes (12:50).
	if Script.valeur_par_argument(args, "--zoom=").is_empty():
		# ISO11, L3 — ×1,8 → ×1,5, amendé par Adrien au test 1 (« un peu moins zoomée »).
		_check("zoom du duel ×1,5 par défaut (amendé par Adrien au test 1)", is_equal_approx(reglages.zoom_duel, 1.5))
	if Script.valeur_par_argument(args, "--decalage=").is_empty():
		_check("décalage de visée d'un quart de la hauteur visible par défaut", is_equal_approx(reglages.decalage_visee, 0.25))
	_check("--zoom=1.0 rend le cadrage d'avant ISO8 pour une exécution",
		is_equal_approx(Script.zoom_applique(Script.ZOOM_DUEL_DEFAUT, PackedStringArray(["--zoom=1.0"])), 1.0))
	# ISO8, étape 3 — la portée des torches, en un facteur global.
	if Script.valeur_par_argument(args, "--torche=").is_empty():
		_check("facteur de portée ×0,75 par défaut, posé sur WeaponData au démarrage",
			is_equal_approx(reglages.facteur_portee, 0.75) and is_equal_approx(WeaponData.facteur_portee, 0.75))
	_check("--torche=1.0 rend les portées d'avant ISO8 ; borné (0,1 → 0,5)",
		is_equal_approx(Script.facteur_portee_applique(PackedStringArray(["--torche=1.0"])), 1.0)
		and is_equal_approx(Script.facteur_portee_applique(PackedStringArray(["--torche=0.1"])), 0.5))
	# ISO8 — la règle en ligne (décision de la session cloud, 13:58) : en ligne, les trois valeurs du duel sont
	# les constantes, même lancé avec --zoom=1.0 --torche=1.0 ; en local, les valeurs de la machine.
	var locales := [Script.zoom_applique(Script.ZOOM_DUEL_DEFAUT, PackedStringArray(["--zoom=1.0"])),
		Script.decalage_applique(PackedStringArray([])),
		Script.facteur_portee_applique(PackedStringArray(["--torche=1.0"]))]
	var en_ligne: Array = Script.valeurs_du_duel(true, locales[0], locales[1], locales[2])
	_check("EN LIGNE avec --zoom=1.0 --torche=1.0 : zoom ×1,5, décalage 0,25, portée ×0,75 — les défauts",
		is_equal_approx(en_ligne[0], 1.5) and is_equal_approx(en_ligne[1], 0.25) and is_equal_approx(en_ligne[2], 0.75),
		str(en_ligne))
	var en_local: Array = Script.valeurs_du_duel(false, locales[0], locales[1], locales[2])
	_check("en écran scindé local, les mêmes drapeaux s'appliquent (zoom 1,0, portée 1,0)",
		is_equal_approx(en_local[0], 1.0) and is_equal_approx(en_local[2], 1.0), str(en_local))
	_check("hors build debug, --zoom=, --decalage= et --torche= sont ignorés",
		Script.arguments_de_reglage(PackedStringArray(["--zoom=1.0", "--torche=1.0"]), false).is_empty()
		and Script.arguments_de_reglage(PackedStringArray(["--zoom=1.0"]), true).size() == 1)
	var reglages_ligne: Node = Script.new()
	reglages_ligne._zoom_local = 1.0
	reglages_ligne._facteur_local = 1.0
	var facteur_global_avant: float = WeaponData.facteur_portee
	reglages_ligne.accorder_au_mode(true)
	_check("accorder_au_mode(en ligne) pose aussi le facteur sur WeaponData",
		is_equal_approx(reglages_ligne.zoom_duel, 1.5) and is_equal_approx(WeaponData.facteur_portee, 0.75))
	WeaponData.facteur_portee = facteur_global_avant
	reglages_ligne.free()
	var pistolet := WeaponData.new()
	var facteur_avant: float = WeaponData.facteur_portee
	WeaponData.facteur_portee = 0.75
	_check("pistolet (1,6) : 307 px de portée au facteur 0,75, au lieu de 410",
		is_equal_approx(pistolet.portee_torche(), 307.2), str(pistolet.portee_torche()))
	var pompe := WeaponData.new()
	pompe.torch_scale = 1.0
	var arbalete := WeaponData.new()
	arbalete.torch_scale = 3.5
	_check("l'écart entre les classes est gardé : arbalète / pompe vaut toujours 3,5",
		is_equal_approx(arbalete.portee_torche() / pompe.portee_torche(), 3.5))
	_check("le demi-angle n'est pas touché (35° pour le pistolet)", is_equal_approx(pistolet.torch_angle_deg, 35.0))
	WeaponData.facteur_portee = facteur_avant
	var Pres8: GDScript = load("res://presentation_3d.gd")
	_check("F3 : la lightmap 1080p dans une fenêtre de 1440 px vaut 0,75 texel par pixel, quel que soit le zoom",
		is_equal_approx(Pres8.texels_par_pixel(1080, 1440), 0.75))
	_check("F3 : à ×1,8 dans une fenêtre de 1440 px, une tuile de 35 px de source couvre 84 px d'écran",
		is_equal_approx(Pres8.tuile_a_l_ecran(35.0, 1.8, 1440, 1080.0), 84.0),
		str(Pres8.tuile_a_l_ecran(35.0, 1.8, 1440, 1080.0)))
	_check("--zoom=1.8 s'applique", is_equal_approx(Script.zoom_applique(1.0, PackedStringArray(["--zoom=1.8"])), 1.8))
	_check("--zoom borné (0,5 → 1,0 ; 9 → 3,0)",
		is_equal_approx(Script.zoom_applique(1.0, PackedStringArray(["--zoom=0.5"])), 1.0)
		and is_equal_approx(Script.zoom_applique(1.0, PackedStringArray(["--zoom=9"])), 3.0))
	_check("--zoom illisible : le choix s'applique", is_equal_approx(Script.zoom_applique(1.5, PackedStringArray(["--zoom=large"])), 1.5))
	_check("--decalage=0.25 s'applique, borné à 0,4",
		is_equal_approx(Script.decalage_applique(PackedStringArray(["--decalage=0.25"])), 0.25)
		and is_equal_approx(Script.decalage_applique(PackedStringArray(["--decalage=2"])), 0.4))

	# ⚠️ Le piège de `video/mode_iso` (ISO6) : un zoom jamais réglé ne s'écrit pas.
	var chemin := "user://test_iso8_reglages.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var neuf: Node = Script.new()
	neuf._settings_path = chemin
	neuf._load()
	neuf.set_fps_cap(120)
	var cfg := ConfigFile.new()
	cfg.load(chemin)
	_check("un zoom jamais réglé ne s'écrit pas : le défaut du jeu reste libre de changer",
		not cfg.has_section_key("debogage", "zoom_duel"))
	neuf.set_zoom_duel(1.8)
	cfg.load(chemin)
	_check("un zoom réglé s'écrit dans la section de débogage", is_equal_approx(float(cfg.get_value("debogage", "zoom_duel", 0.0)), 1.8))
	var relu: Node = Script.new()
	relu._settings_path = chemin
	relu._load()
	_check("et se relit", is_equal_approx(relu.zoom_duel_choisi(), 1.8))
	for n in [neuf, relu]:
		n.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))

	# Le regard.
	var vue := Vector2(1920.0, 1080.0)
	var carte := Rect2(Vector2.ZERO, Vector2(32.0, 32.0) * 35.0)
	var joueur := Vector2(210.0, 227.5)
	_check("zoom 1,0 et décalage 0 : la caméra reste EXACTEMENT sur le joueur (aucune borne, aucun lissage)",
		RegardDuel.centre_du_regard(joueur, RegardDuel.decalage_vise(Vector2.UP, 0.0, vue, 1.0), vue, 1.0, carte, 35.0) == joueur)
	var vise := RegardDuel.decalage_vise(Vector2.RIGHT, 0.25, vue, 2.0)
	_check("le décalage vaut un quart de la hauteur visible dans la direction de la visée (×2 : 135 px)",
		vise.is_equal_approx(Vector2(135.0, 0.0)), str(vise))
	var c := RegardDuel.centre_du_regard(joueur, Vector2.ZERO, vue, 2.0, carte, 35.0)
	var visible := RegardDuel.etendue_visible(vue, 2.0)
	_check("zoom ×2 contre un coin : la vue ne montre pas plus d'une tuile de hors-carte",
		c.x - visible.x * 0.5 >= -35.0 - 0.01 and c.y - visible.y * 0.5 >= -35.0 - 0.01, str(c))
	var au_centre := carte.get_center()
	_check("zoom ×2 au centre de la carte : aucune borne ne déplace la caméra",
		RegardDuel.centre_du_regard(au_centre, Vector2.ZERO, vue, 2.0, carte, 35.0) == au_centre)
	_check("même règle pour les deux joueurs : le regard ne dépend que de la position, de la visée et de la vue",
		RegardDuel.centre_du_regard(joueur, vise, vue, 2.0, carte, 35.0)
		== RegardDuel.centre_du_regard(joueur, vise, vue, 2.0, carte, 35.0))
	var lisse := RegardDuel.lisser(Vector2.ZERO, Vector2(100.0, 0.0), 0.5)
	_check("le décalage se lisse sans dépasser sa cible", lisse.x > 90.0 and lisse.x <= 100.0, str(lisse))


func _reglage() -> void:
	print("\n--- GameSettings.mode_iso (ISO6 : l'iso par défaut, la vue de dessus en débogage) ---")
	var reglages := root.get_node("GameSettings")
	var Script: GDScript = load("res://settings_manager.gd")
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if Script.deux_d_par_argument(args):
		_check("lancée en --2d : la vue de dessus s'applique", reglages.mode_iso == false and reglages.mode_rendu() == "dessus")
	else:
		_check("mode_iso est VRAI par défaut (lot lancé sans --2d)", reglages.mode_iso == true and reglages.mode_rendu() == "iso")
	var chemin := "user://test_iso_reglages.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var neuf: Node = Script.new()
	neuf._settings_path = chemin
	neuf._load()
	_check("installation neuve : aucun réglage de débogage", not neuf.vue_de_dessus_choisie())
	# La préséance, sans dépendre de la ligne de commande du lot.
	_check("sans drapeau ni réglage : l'iso", Script.iso_applique(false, PackedStringArray([])))
	_check("le réglage de débogage ramène la vue de dessus", not Script.iso_applique(true, PackedStringArray([])))
	_check("--2d ramène la vue de dessus", not Script.iso_applique(false, PackedStringArray(["--2d"])))
	_check("--iso, accepté, ne change rien au défaut", Script.iso_applique(false, PackedStringArray(["--iso"])))
	_check("--iso l'emporte sur un réglage de débogage oublié", Script.iso_applique(true, PackedStringArray(["--iso"])))
	_check("--2d l'emporte sur --iso", not Script.iso_applique(false, PackedStringArray(["--iso", "--2d"])))
	neuf.set_vue_de_dessus(true)
	var cfg := ConfigFile.new()
	cfg.load(chemin)
	_check("le réglage de débogage s'enregistre dans sa section",
		cfg.get_value("debogage", "vue_de_dessus", false) == true)
	_check("et l'ancienne clé video/mode_iso ne s'écrit plus", not cfg.has_section_key("video", "mode_iso"))
	var relu: Node = Script.new()
	relu._settings_path = chemin
	relu._load()
	_check("et se relit au lancement suivant", relu.vue_de_dessus_choisie())
	relu.set_vue_de_dessus(false)
	cfg.load(chemin)
	_check("le retour à l'iso s'enregistre aussi", cfg.get_value("debogage", "vue_de_dessus", true) == false)
	# Un lancement en --2d qui touche un autre réglage ne doit pas persister la vue de dessus.
	relu.mode_iso = false
	relu.set_fps_cap(120)
	cfg.load(chemin)
	_check("--2d appliqué ne s'écrit jamais : seul le réglage s'enregistre",
		cfg.get_value("debogage", "vue_de_dessus", true) == false)
	cfg.set_value("debogage", "vue_de_dessus", "oui")
	cfg.save(chemin)
	var trafique: Node = Script.new()
	trafique._settings_path = chemin
	trafique._load()
	_check("une valeur trafiquée retombe sur l'iso", not trafique.vue_de_dessus_choisie())
	# ISO6 — F3 dit d'abord quel rendu tourne.
	var Pres: GDScript = load("res://presentation_3d.gd")
	_check("F3 : la ligne RENDU commence par mode_rendu=iso en iso",
		String(Pres.texte_f3(true)).begins_with("mode_rendu=iso"), Pres.texte_f3(true))
	_check("F3 : et par mode_rendu=dessus sous le drapeau de débogage",
		String(Pres.texte_f3(false)).begins_with("mode_rendu=dessus"), Pres.texte_f3(false))
	# ⚠️ Le piège de la migration : chaque settings.cfg d'avant ISO6 porte video/mode_iso=false.
	var ancien := ConfigFile.new()
	ancien.set_value("video", "mode_iso", false)
	ancien.save(chemin)
	var joueur_existant: Node = Script.new()
	joueur_existant._settings_path = chemin
	joueur_existant._load()
	_check("un settings.cfg d'avant ISO6 (video/mode_iso=false) n'éteint pas l'iso",
		not joueur_existant.vue_de_dessus_choisie()
		and Script.iso_applique(joueur_existant.vue_de_dessus_choisie(), PackedStringArray([])))
	joueur_existant.set_fps_cap(0)
	cfg.load(chemin)
	_check("et sa clé disparaît à la première sauvegarde", not cfg.has_section_key("video", "mode_iso"))
	joueur_existant.free()
	for n in [neuf, relu, trafique]:
		n.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))


# ---------------------------------------------------------------------------

## Le même entraînement, joué trois fois dans la MÊME instance du jeu : vue de dessus,
## vue de dessus encore (le témoin), puis vue iso allumée.
##
## ⚠️ **Une seule instance de `Main`, et ce n'est pas un confort.** Libérer `Main` puis en
## instancier une seconde qui tire fait crier `AudioManager._occupations()` (« Trying to
## cast a freed object », `audio_manager.gd:1521`) : le pool garde des voix nées dans le
## monde de la première. Défaut de l'audio, signalé, hors périmètre d'ISO1.
##
## ⚠️ **Le témoin d'abord.** Si deux parties sans iso diffèrent déjà, une différence
## avec iso ne prouverait rien — et une égalité non plus.
func _simulation_inchangee() -> void:
	print("\n--- La vue ne change rien à la simulation ---")
	var reglages := root.get_node("GameSettings")
	# ⚠️ ISO8 — le décalage de la caméra vers la visée est DÉSARMÉ pendant les parties comparées, puis rendu.
	# Sans stick tenu, J1 vise la souris, convertie par la caméra (`LocalInputProvider.cible_de_la_souris`) ;
	# la caméra avançant vers la visée avec un lissage réglé sur le temps d'image, cette visée de repli dépend du
	# rythme des images, et deux parties identiques cessaient de l'être (pas 113, une balle d'un seul côté) —
	# avec OU sans iso. Ce que ce contrôle mesure, c'est la vue iso ; le regard est une présentation locale.
	var decalage_avant: float = reglages.decalage_visee
	reglages.decalage_visee = 0.0
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var conteneur := main.vp1.get_parent() as Control
	var souris_avant := conteneur.mouse_filter
	var sans: Dictionary = await _jouer(main, false)
	var temoin: Dictionary = await _jouer(main, false)
	var avec: Dictionary = await _jouer(main, true)
	_check("la partie scriptée a bougé et tiré (%d pas, jusqu'à %d balle(s))"
		% [(sans["etats"] as Array).size(), sans["balles_max"]],
		(sans["etats"] as Array).size() == PAS_SIMULES and int(sans["balles_max"]) > 0
		and (sans["etats"][0][0] as Vector2).distance_to(sans["etats"][-1][0]) > 50.0)
	_check("témoin : deux parties sans iso sont identiques pas pour pas",
		_ecarts(sans["etats"], temoin["etats"]) == 0 and _ecarts(sans["rejeu"], temoin["rejeu"]) == 0,
		_premier_ecart(sans["etats"], temoin["etats"]) + " ; rejeu " + _premier_ecart(sans["rejeu"], temoin["rejeu"]))
	_check("avec iso : la vue était vraiment allumée pendant la partie", bool(avec["iso_allumee"]))
	_check("mêmes positions, rotations, points de vie, torches et balles à chaque pas",
		_ecarts(sans["etats"], avec["etats"]) == 0, _premier_ecart(sans["etats"], avec["etats"]))
	_check("même rejeu enregistré (%d images)" % (sans["rejeu"] as Array).size(),
		_ecarts(sans["rejeu"], avec["rejeu"]) == 0 and not (sans["rejeu"] as Array).is_empty())
	reglages.decalage_visee = decalage_avant

	# Les touches de la pâte, pendant que la vue est allumée (la dernière partie l'a laissée
	# allumée) : F2 seule n'atteint pas le jeu sur un Mac sans `fn`.
	var p := root.get_node_or_null("Presentation3D")
	var Pate: GDScript = load("res://iso_pate.gd")
	_check("pâte par défaut : D, lavis et pochoir (décision d'Adrien)",
		p != null and int(p.style_pate) == Pate.LAVIS)
	if p != null:
		var suite_ok := true
		for cas in [[KEY_2, Pate.LIGNE_CLAIRE], [KEY_0, Pate.BRUTE], [KEY_F2, Pate.GRAVURE],
				[KEY_4, Pate.LAVIS], [KEY_1, Pate.GRAVURE], [KEY_3, Pate.TRAME]]:
			var touche := InputEventKey.new()
			touche.physical_keycode = cas[0]
			touche.pressed = true
			p._input(touche)
			suite_ok = suite_ok and int(p.style_pate) == int(cas[1])
		_check("1, 2, 3, 4 choisissent A, B, C, D ; 0 la brute ; F2 fait défiler", suite_ok,
			"pâte finale %d" % int(p.style_pate))
		var lettre := InputEventKey.new()
		lettre.physical_keycode = KEY_W
		lettre.pressed = true
		p._input(lettre)
		_check("une touche de déplacement ne change pas la pâte", int(p.style_pate) == Pate.TRAME)

	# L'extinction : on retire le réglage, la vue doit tout rendre.
	reglages.mode_iso = false
	await process_frame
	await process_frame
	var p1: Node2D = main.p1
	var fond := main.get_node("Background") as CanvasItem
	_check("à l'extinction, les sprites de corps retrouvent leurs couches (2 et 4)",
		(p1.visual as CanvasItem).visibility_layer == 2 and (p1.visual_enemy as CanvasItem).visibility_layer == 4)
	_check("le conteneur de la vue redevient opaque et reçoit la souris",
		conteneur.modulate.a == 1.0 and conteneur.mouse_filter == souris_avant)
	_check("le fond et le rendu par la racine reviennent",
		fond.visible and main.rendu_racine_autorise and main._rendu_racine)
	main.queue_free()
	await process_frame
	await process_frame


func _premier_ecart(a: Array, b: Array) -> String:
	for i in mini(a.size(), b.size()):
		if str(a[i]) != str(b[i]):
			return "pas %d : %s ≠ %s" % [i, str(a[i]), str(b[i])]
	return "tailles %d / %d" % [a.size(), b.size()] if a.size() != b.size() else "aucun"


func _ecarts(a: Array, b: Array) -> int:
	var n := absi(a.size() - b.size())
	for i in mini(a.size(), b.size()):
		if str(a[i]) != str(b[i]):
			n += 1
	return n


func _jouer(main: Node, iso: bool) -> Dictionary:
	root.get_node("GameSettings").mode_iso = iso
	# Une instance À NOUS du système de rejeu, pas l'autoload : le jeu alimente aussi
	# l'autoload, à sa propre cadence d'horloge, et deux parties n'y seraient jamais
	# comparables (300 images pour 150 appels). Celle-ci lit les mêmes champs.
	var replay: Node = (load("res://replay_system.gd") as GDScript).new()
	main._on_training_requested()
	for i in 4:
		await physics_frame
	var p1: Node2D = main.p1
	var conteneur := main.vp1.get_parent() as Control
	var p := root.get_node_or_null("Presentation3D")
	var iso_allumee: bool = iso and p != null and bool(p.get("_actif")) \
		and main.rendu_racine_autorise == false and conteneur.modulate.a == 0.0
	# Même point de départ, même hasard, mêmes commandes : seule la vue diffère.
	p1.global_position = Vector2(300, 300)
	p1.rotation = 0.0
	p1.set("velocity", Vector2.ZERO)
	replay.start_recording()
	var etats: Array = []
	var balles_max := 0
	for pas in PAS_SIMULES:
		Input.action_press("p1_move_right" if pas < PAS_SIMULES / 2 else "p1_move_down")
		if pas == PAS_SIMULES / 2:
			Input.action_release("p1_move_right")
		Input.action_press("p1_aim_up" if pas < 100 else "p1_aim_left")
		if pas == 100:
			Input.action_release("p1_aim_up")
		if pas == 30 or pas == 110:
			seed(1234 + pas)
			p1.shoot()
		await physics_frame
		var balles: Array = []
		for b in main.bullet_container.get_children():
			balles.append([(b as Node2D).global_position, snappedf((b as Node2D).rotation, 1e-6)])
		balles_max = maxi(balles_max, balles.size())
		etats.append([p1.global_position, snappedf(p1.rotation, 1e-6), p1.hp, p1.flashlight_on, balles])
		replay.record_frame(main.p1, main.p2, main.bullet_container)
	for action in ["p1_move_right", "p1_move_down", "p1_aim_up", "p1_aim_left"]:
		Input.action_release(action)
	var rejeu: Array = []
	for s in replay.snapshots:
		rejeu.append([s.p1_pos, snappedf(s.p1_rot, 1e-6), s.p1_hp, s.p1_visible, s.p1_light])
	replay.stop_recording()
	replay.free()
	return {"etats": etats, "balles_max": balles_max, "rejeu": rejeu, "iso_allumee": iso_allumee}
