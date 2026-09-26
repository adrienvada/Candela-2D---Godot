extends RefCounted

## LA FUSÉE PAR ÂGES, EN TEMPS DE JEU (session cloud « fusée », 2026-09-27) — la planche de Q34 = C et Q35 = B.
##
## Un outil : aucun code du jeu ne change. UNE fusée posée dans le noir, à l'écran de J1, vieillit par son propre
## `_physics_process` (sous `--fixed-fps 60`, un pas de physique = 1/60 s de jeu) ; à chaque âge demandé, on l'arrête
## (`set_physics_process(false)`) le temps des prises, puis on la relance. L'âge n'est donc jamais écrit : il est LU
## (`age_combustion()`), et imprimé à côté de l'âge demandé. `--fusee-rouge-long` se passe au photographe (après `--`) :
## c'est le vrai drapeau, lu par `FuseeModele` au chargement, pas `poser_rouge_long`.
##
## Quatre prises par âge, fenêtre entière :
## - `joueur` : ce que voit J1, torche allumée — l'image de la planche ;
## - `noir-sans-fumee`, `noir`, `noir-sans-fumee-bis` : torches ÉTEINTES (sans elles, aucun voile de rétrodiffusion ne
##   soulève le noir), la fumée coupée (`IsoVolumes.volumes_actifs`, qui ne touche ni aux lueurs ni au point de braise),
##   rétablie, recoupée — le patron de `loupe-fusee-masque-preuve`. Un pixel noir dans les DEUX prises coupées et allumé
##   dans la rétablie est un pixel que la fumée allume HORS DE LA LUMIÈRE ; exiger les deux coupées écarte ce qui bouge
##   seul d'une image à l'autre (le voile d'éblouissement que la fusée pose sur J1 n'est pas figé : premier passage,
##   des dizaines de milliers de « fuites » au bord de ses taches noires, partout dans l'écran, loin de toute fumée).
##
## Chaque âge imprime une ligne `FUSEE_AGES {json}` : âges, acte, énergie, fumée, et la géométrie à l'écran (centre, point de
## braise, anneau du sol, disque de fumée — des cercles du monde projetés par la caméra de J1). `docs/iso/cloud/fusee/mesurer.py`
## fait le reste.

const ID := "loupe-fusee-ages"
const AGES := [0.5, 1.5, 2.5, 3.0, 3.5, 4.0, 5.0, 8.0]
## L'anneau du sol éclairé, en px du monde : au-delà du voxel et de son ombre, en deçà du bord de la flaque rouge.
const ANNEAU := Vector2(24.0, 64.0)
## Le temps laissé à la rétrodiffusion de J1 pour s'éteindre ou revenir, en pas de physique (`_tenir_sans_torches`).
const PAS_TORCHE := 40

var l: Object        # la loupe (`tools/loupe.gd`)


func _init(loupe: Object) -> void:
	l = loupe


func lancer(plans: Array[Dictionary], lieux: Array[Vector2]) -> void:
	var p: Node = l.p
	var m: Node = p._main
	var pres := Presentation3D.instance()
	var miroirs: Object = pres.get("_miroirs") if pres != null else null
	var volumes: Object = miroirs.get("volumes") if miroirs != null else null
	if volumes == null:
		printerr("  ✗ %s : volumes iso introuvables" % ID)
		return
	var lieu: Vector2 = lieux[0]
	print("  · %s : plein feu %.1f s, braise %.1f s, vie %.1f s ; point de braise %d ; masque de la fumée %s ; fusée en %s"
		% [ID, FuseeModele.duree_plein_feu, FuseeModele.duree_braise, FuseeModele.duree_combustion(),
		int(volumes.get("coeur_fusee")), "allumé" if volumes.get("masque_fumee") else "éteint", str(lieu)])
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", lieu)
	f.set("direction", Vector2.DOWN)
	f.set("joueurs", [m.p1, m.p2])
	m.bullet_container.add_child(f)
	await p.get_tree().process_frame
	f.set_physics_process(false)
	f.global_position = lieu
	# Posée, âge 0 : l'atterrissage. Le vieillissement qui suit est celui du jeu.
	f.call("forcer_age", 0.0)
	var pas: float = 1.0 / float(Engine.physics_ticks_per_second)
	var pas_total := 0
	for age: float in AGES:
		f.set_physics_process(true)
		# On s'arrête au pas de physique le plus proche de l'âge demandé (à un demi-pas près).
		while float(f.call("age_combustion")) < age - pas * 0.5:
			l._tenir_scene()
			await p.get_tree().physics_frame
			pas_total += 1
		f.set_physics_process(false)
		var lu: float = float(f.call("age_combustion"))
		var nom := "a%s" % String.num(age, 1).replace(".", "_")
		await _prendre(plans, "%s-joueur" % nom, 6, l._tenir_scene)
		for i in PAS_TORCHE:
			l._tenir_sans_torches()
			await p.get_tree().physics_frame
		volumes.set("volumes_actifs", false)
		await _prendre(plans, "%s-noir-sans-fumee" % nom, 6, l._tenir_sans_torches)
		volumes.set("volumes_actifs", true)
		await _prendre(plans, "%s-noir" % nom, 6, l._tenir_sans_torches)
		volumes.set("volumes_actifs", false)
		await _prendre(plans, "%s-noir-sans-fumee-bis" % nom, 6, l._tenir_sans_torches)
		volumes.set("volumes_actifs", true)
		for i in PAS_TORCHE:
			l._tenir_scene()
			await p.get_tree().physics_frame
		var acte: int = FuseeModele.acte_a(lu)
		print("  FUSEE_AGES %s" % JSON.stringify({
			"nom": nom, "age_demande": age, "age_lu": lu, "pas_de_vieillissement": pas_total,
			"acte": FuseeModele.Acte.keys()[acte], "energie_relative": snappedf(float(f.call("energie_relative")), 0.001),
			"alpha_fumee": snappedf(float(f.call("alpha_fumee")), 0.001), "rayon_fumee": snappedf(float(f.call("rayon_fumee")), 0.1),
			"duree_plein_feu": FuseeModele.duree_plein_feu, "coeur_fusee": int(volumes.get("coeur_fusee")),
			"masque_fumee": bool(volumes.get("masque_fumee")),
			"eblouissement_j1": snappedf(float(m.p1.dazzle_amount), 0.001),
			"geometrie": _geometrie(lieu, float(f.call("rayon_fumee"))),
			"ids": ["%s-%s-joueur" % [ID, nom], "%s-%s-noir-sans-fumee" % [ID, nom], "%s-%s-noir" % [ID, nom],
				"%s-%s-noir-sans-fumee-bis" % [ID, nom]],
		}))
	f.queue_free()
	await p.get_tree().process_frame


## Tient la scène `images` images de jeu, prend la fenêtre entière, l'écrit sous `ID-suffixe`.
func _prendre(plans: Array[Dictionary], suffixe: String, images: int, tenir: Callable) -> void:
	var p: Node = l.p
	for i in images:
		tenir.call()
		await p.get_tree().process_frame
	tenir.call()
	var img: Image = await l._capturer(false)
	if img == null:
		p._perdues += 1
		printerr("  ✗ %s-%s : prise perdue" % [ID, suffixe])
		return
	p._ecrire(p._derive(plans, ID, suffixe, ""), img)


## La géométrie à l'écran, en pixels de la fenêtre : le centre au sol, le point de braise à sa hauteur, et trois cercles du
## monde projetés (48 sommets chacun) : l'anneau du sol (intérieur, extérieur) et le disque de la fumée.
func _geometrie(lieu: Vector2, rayon_fumee: float) -> Dictionary:
	var taille := Vector2(DisplayServer.window_get_size())
	var cercle := func(r: float) -> Array:
		var pts := []
		for k in 48:
			var q: Vector2 = l._pixel_taille(taille, lieu + Vector2.RIGHT.rotated(TAU * float(k) / 48.0) * r)
			pts.append([snappedf(q.x, 0.1), snappedf(q.y, 0.1)])
		return pts
	var c: Vector2 = l._pixel_taille(taille, lieu)
	var point: Vector2 = l._pixel_taille(taille, lieu, IsoVolumes.HAUTEUR_COEUR_FUSEE_PX)
	return {
		"taille": [taille.x, taille.y], "centre": [c.x, c.y], "point": [point.x, point.y],
		"anneau_int": cercle.call(ANNEAU.x), "anneau_ext": cercle.call(ANNEAU.y),
		"fumee": cercle.call(maxf(rayon_fumee, 1.0)),
	}
