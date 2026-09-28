## La peinture iso suit la carte posée, vue allumée (session cloud « peinture périmée », 2026-09-28).
##
## ## Pourquoi
##
## Les faces et les liserés des murs iso divisent leur lumière par la PEINTURE de la carte (`peinture_iso.gd`,
## `mur_iso.gdshader`, `lire_lumiere` : `l × réf ÷ max(peinture, plancher)`, jusqu'à ×3,3). Cette peinture est faite de
## COPIES des calques de l'arène, posées par `_allumer`. Quand `rebuild_arena()` rappelait le crochet pendant que la vue
## tenait, la présentation refaisait ses murs et PAS sa peinture : les murs de la nouvelle carte lisaient la peinture de
## l'ancienne (son cadre, ses murs, son encre, ses marques). Mesuré à l'image, torches éteintes : des pans de faces allumés
## dans le noir, jusqu'à 255/255 (RAPPORT sol-marque-2 § 1 ; RAPPORT peinture-perimee pour les chemins du jeu qui y
## mènent : l'écran de fin d'un match fini au temps, puis CHANGER DE CARTE et REJOUER ; le salon en ligne).
##
## ## Ce que la garde vérifie, sans rien rendre
##
## Une partie locale en écran scindé, vue iso allumée, sur le Cloître ; puis une manche neuve par le démarrage du jeu
## (`_start_round`, celui de REJOUER), les vues inchangées (aucune bascule : sinon `_allumer` referait la peinture et la
## garde ne prouverait rien) :
##   • sur la Croisée : la peinture en place est cadrée sur la Croisée, et c'est elle que lisent les murs et les sols ;
##   • sur la même carte (la revanche) : la peinture ne garde aucune copie d'un calque libéré — sa source de décor est le
##     décor de l'arène reconstruite.
##
## Lancer : godot --headless --path . --script res://tools/test_iso_peinture_carte.gd
extends SceneTree

const CLOITRE := "map_001"
const CROISEE := "map_003"

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
	print("=== LA PEINTURE ISO SUIT LA CARTE, VUE ALLUMÉE ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	var cartes := root.get_node("MapData")
	reglages.mode_iso = true
	_check("la carte de départ (le Cloître) est au catalogue", cartes.select_map(CLOITRE))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	main._on_replay_requested()
	_check("la première manche démarre", await _depart_fini(main))
	await _images(4)
	var p: Node = root.get_node_or_null("Presentation3D")
	_check("la présentation iso est posée", p != null)
	if p == null:
		_sortir()
		return
	_check("elle est allumée (écran scindé)", bool(p.get("_actif")) and bool(p.get("_scinde")))
	_peinture_de_la_carte(main, p, "manche 1, le Cloître")

	var bascules := int(p.get("bascules"))
	_check("la carte d'arrivée (la Croisée) est au catalogue", cartes.select_map(CROISEE))
	main._start_round()
	_check("la manche sur la Croisée démarre", await _depart_fini(main))
	await _images(4)
	_check("la vue a tenu sans bascule (sinon `_allumer` referait la peinture, et la garde ne prouverait rien)",
		bool(p.get("_actif")) and int(p.get("bascules")) == bascules, "bascules %d → %d" % [bascules, int(p.get("bascules"))])
	_peinture_de_la_carte(main, p, "manche 2, la Croisée")

	main._start_round()
	_check("la revanche sur la Croisée démarre", await _depart_fini(main))
	await _images(4)
	_check("la vue a tenu sans bascule", bool(p.get("_actif")) and int(p.get("bascules")) == bascules)
	_peinture_de_la_carte(main, p, "revanche, la Croisée")

	_sortir()


## La peinture en place couvre la carte posée, c'est elle que lisent les murs et les sols, et aucune de ses copies de
## calques n'a perdu sa source (un calque de l'arène libéré par `rebuild_arena`).
func _peinture_de_la_carte(main: Node, p: Node, etape: String) -> void:
	var peinture: SubViewport = p.peinture()
	_check("%s : une peinture est posée" % etape, peinture != null)
	if peinture == null:
		return
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var grille := Vector2(MapCodec.get_grid_size(root.get_node("MapData").get_selected()))
	var attendu := Rect2(-tuile, (grille + Vector2(2, 2)) * tuile)
	_check("%s : la peinture est cadrée sur la carte posée" % etape, peinture.cadre == attendu,
		"cadre %s, carte %s" % [str(peinture.cadre), str(attendu)])
	var mat_mur: ShaderMaterial = p.get("_mat_mur")
	_check("%s : les murs lisent CETTE peinture, à son cadre" % etape, mat_mur != null
		and mat_mur.get_shader_parameter("peinture") == peinture.get_texture()
		and mat_mur.get_shader_parameter("peinture_taille_px") == peinture.cadre.size,
		"taille lue %s" % str(mat_mur.get_shader_parameter("peinture_taille_px") if mat_mur != null else null))
	var sols_ok := true
	for m in p.get("_mat_sols"):
		sols_ok = sols_ok and (m as ShaderMaterial).get_shader_parameter("peinture") == peinture.get_texture()
	_check("%s : les sols lisent CETTE peinture" % etape, sols_ok)
	var decor: Node = main.arena.get_node_or_null("ArenaDecor_P1")
	var source = peinture.get("_decor_source")
	_check("%s : la copie du décor vient du décor de l'arène EN PLACE, pas d'un calque libéré" % etape,
		decor != null and is_instance_valid(source) and source == decor,
		"source %s" % ("libérée" if not is_instance_valid(source) else str(source)))


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
	return main.round_active


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
