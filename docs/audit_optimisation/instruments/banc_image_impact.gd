## « L'image d'impact » d'une volée de pompe — mesure CPU headless (audit M, protocole de V_V3 § 5, version réduite) — INSTRUMENT
## TEMPORAIRE, jamais commité.
##
## Monte une manche locale (vue unique), le pompe pour les deux joueurs, J1 et J2 immobiles, et tire une volée par seconde de jeu
## (`Player.shoot()` : le vrai geste — cadence, plombs, douille, flash, rejeu), LANCÉ DEPUIS LE `_physics_process` D'UN NŒUD ASSISTANT
## posé après `main` (V3 § 5 : le tir part de `Player._physics_process`, en cours de passe — les plombs ne sont traités qu'au tick
## suivant ; lancé depuis le signal `physics_frame` ils le seraient dans le même, ce que le jeu ne fait pas ; et `Engine.is_in_physics_frame()`
## est vrai, donc les rayons d'occlusion sonores partent comme en jeu).
##
## Relevé par image : horloge murale entre deux `physics_frame` (début de la passe de physique k → début de la passe k+1 : physique des
## nœuds + pas du serveur de physique + `_process` + dessin factice + audio). Les compteurs sont pris au début de chaque passe.
## IMAGE DU TIR = celle où `shoot()` a tourné ; IMAGE D'IMPACT = la première image où des traces d'impact (éclats de mur, taches de sang)
## sont créées ; FOND = médiane des images hors de [tir, tir + 11]. SURCOÛT = image − fond (par volée), puis médiane / p90 / max.
##
##   --scenario=mur    un mur de test (StaticBody2D, WALL_LAYER) à `--distance` px du canon (40 → 5 plombs, 120 → 3, 165 → 1)
##   --scenario=corps  J2 posé à `--distance` px du canon (50 / 75 / 150), vie portée à 1e9 à chaque volée (il ne meurt jamais)
##   --scenario=vide   rien devant le canon sur 400 px : le tir sans impact (le témoin)
##   --volees=40 (après 10 de chauffe, comptées en plus) · --iso=1|0 (défaut 1)
##   --sans=particules|liseres|rayons|iso   variantes par soustraction (le banc imprime ce que chacune retire)
##   --plafond=1        les plafonds de traces (éclats 90, taches 120, douilles) abaissés à 8 : « au plafond »
##   --detail=1         une ligne par volée
##
## godot --headless --path . --fixed-fps 60 --script res://tools/banc_image_impact.gd -- --no-eos --scenario=mur --distance=40
extends SceneTree

const GROUPES_IMPACT := ["blood_stain", "blood_p2", "wall_impact", "wall_impact_p2"]
const GROUPES_DOUILLES := ["bullet_casing", "casing_p2"]

var _o: Dictionary = {}
var _main: Node = null
var _stamps: Array[int] = []      # instant (µs) du début de chaque passe de physique
var _compteurs: Array = []        # par passe : [particules, noeuds, sons, traces d'impact, douilles, tweens]
var _pool: Node = null
var _audio: Node = null


## Le nœud assistant : tire depuis sa propre passe de physique, une fois toutes les 60.
class Tireur extends Node:
	var p1: Node
	var p2: Node
	var pompe: Variant
	var tirs: Array[int] = []
	var cible_immortelle := false
	var _n := 0

	func _physics_process(_d: float) -> void:
		_n += 1
		if _n % 60 == 5:
			p1.set("current_ammo", int(pompe.max_ammo))
			p1.set("shoot_cooldown", 0.0)
			p1.set("is_reloading", false)
			if cible_immortelle:
				p2.set("hp", 1.0e9)
			tirs.append(_n - 1)       # l'indice de la passe, dans le même repère que `_stamps`
			p1.shoot()


func _init() -> void:
	call_deferred("_run")


func _options() -> Dictionary:
	var o := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if not s.begins_with("--"):
			continue
		var i := s.find("=")
		if i < 0:
			o[s.substr(2)] = "1"
		else:
			o[s.substr(2, i - 2)] = s.substr(i + 1)
	return o


func _effectif(groupes: Array) -> int:
	var n := 0
	for g in groupes:
		n += get_nodes_in_group(g).size()
	return n


func _sur_physique() -> void:
	_stamps.append(Time.get_ticks_usec())
	_compteurs.append([_pool.active_count() if _pool != null else 0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(_audio.get("_sons_2d_lances")) if _audio != null and _audio.get("_sons_2d_lances") != null else 0, _effectif(GROUPES_IMPACT),
		_effectif(GROUPES_DOUILLES), get_processed_tweens().size()])


func _run() -> void:
	_o = _options()
	await process_frame
	var f0 := Engine.get_physics_frames()
	for _i in 30:
		await process_frame
	if absi(int(Engine.get_physics_frames() - f0) - 30) > 1:
		printerr("✗ l'horloge n'est pas fixe : lancer avec --fixed-fps 60")
		quit(1)
		return
	var scenario := String(_o.get("scenario", "mur"))
	var distance := float(_o.get("distance", "40"))
	var iso := String(_o.get("iso", "1")) != "0" and String(_o.get("sans", "")) != "iso"
	var volees := int(_o.get("volees", "40"))
	var chauffe := 10
	root.get_node("GameSettings").mode_iso = iso
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for _i in 3:
		await process_frame
	var ui: Node = _main.ui
	var modes: Dictionary = (root.get_node("NetworkManager").get_script() as Script).get_script_constant_map()["GameMode"]
	ui._intended_mode = int(modes["LOCAL_SPLITSCREEN"])
	var idx := 0
	for i in _main.classes().size():
		if String(_main.classes()[i].slug()) == "pompe":
			idx = i
	ui.set_weapon_selection(0, idx)
	ui.set_weapon_selection(1, idx)
	_main._on_replay_requested()
	var n := 0
	while not (bool(_main.round_active) and float(_main.countdown_left) <= 0.0):
		await process_frame
		n += 1
		if n > 1200:
			printerr("✗ la manche n'a pas démarré")
			quit(1)
			return
	_main.vp2.get_parent().hide()
	_main.ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	var pres: Node = null
	if iso:
		var cls: GDScript = load("res://presentation_3d.gd") as GDScript
		for _i in 300:
			await process_frame
			pres = cls.call("instance")
			if pres != null and bool(pres.get("_actif")):
				break
		if pres == null or not bool(pres.get("_actif")):
			printerr("✗ la vue iso ne tient pas : chiffre refusé")
			quit(1)
			return
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	for p: Node2D in [p1, p2]:
		p.set_physics_process(false)
		p.set("velocity", Vector2.ZERO)
		p.set("dazzle_amount", 0.0)
	p1.rotation = 0.0
	_pool = _main.particle_pool
	_audio = root.get_node("AudioManager")
	# ── la mise en scène
	var canon: Vector2 = p1.get("muzzle").global_position
	if scenario == "mur":
		var mur := StaticBody2D.new()
		mur.name = "MurDeTest"
		mur.collision_layer = 1
		mur.collision_mask = 0
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40.0, 600.0)
		cs.shape = rect
		mur.add_child(cs)
		mur.global_position = canon + Vector2(distance + 20.0, 0.0)
		_main.arena.add_child(mur)
	elif scenario == "corps":
		p2.global_position = canon + Vector2(distance + 18.0, 0.0)
		p2.set("velocity", Vector2.ZERO)
	for _i in 3:
		await physics_frame
	# Ce que le canon voit devant lui, sur 400 px : sans mur de test, le premier obstacle du décor (le témoin « vide » le veut à plus de 180).
	var espace: PhysicsDirectSpaceState2D = p1.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(canon, canon + Vector2(400.0, 0.0), 1)
	var coup: Dictionary = espace.intersect_ray(q)
	var d_obstacle := canon.distance_to(coup["position"]) if not coup.is_empty() else 400.0
	print("=== L'IMAGE D'IMPACT — scénario %s, distance %.0f px, %s, sans=%s, %d volées (+%d de chauffe) ===" % [scenario, distance, "iso" if iso else "vue de dessus", String(_o.get("sans", "—")), volees, chauffe])
	print("  premier obstacle devant le canon : %.0f px ; moteur %s ; rendu %s" % [d_obstacle, Engine.get_version_info()["string"], DisplayServer.get_name()])
	# ── les variantes par soustraction
	match String(_o.get("sans", "")):
		"particules":
			_pool.remove_from_group("particle_pool")
		"liseres":
			for c in _audio.son_localise.get_connections():
				_audio.son_localise.disconnect(c["callable"])
		"rayons":
			_audio.occlusion_active = false
	if _o.has("plafond"):
		var we: GDScript = load("res://wall_impact.gd") as GDScript
		var bs: GDScript = load("res://blood_stain.gd") as GDScript
		var bc: GDScript = load("res://bullet_casing.gd") as GDScript
		we.set("MAX_ECLATS", 8)
		bs.set("MAX_STAINS", 8)
		bc.set("MAX_CASINGS", 8)
		print("  plafonds posés (relus) : éclats %s, taches %s, douilles %s" % [str(we.get("MAX_ECLATS")), str(bs.get("MAX_STAINS")), str(bc.get("MAX_CASINGS"))])
	# ── la boucle : une volée toutes les 60 images, tirée depuis la passe de physique d'un nœud assistant (après `main` dans l'arbre)
	var tireur := Tireur.new()
	tireur.name = "TireurDeBanc"
	tireur.p1 = p1
	tireur.p2 = p2
	tireur.pompe = p1.get("current_weapon")
	tireur.cible_immortelle = scenario == "corps"
	physics_frame.connect(_sur_physique)
	root.add_child(tireur)
	var total := (volees + chauffe) * 60 + 30
	while _stamps.size() < total:
		await physics_frame
	physics_frame.disconnect(_sur_physique)
	print(_rapport(tireur.tirs, chauffe))
	quit(0)


static func _med(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := a.duplicate()
	t.sort()
	return float(t[t.size() / 2])


static func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var t := a.duplicate()
	t.sort()
	return float(t[mini(t.size() - 1, int(q * t.size()))])


func _rapport(tirs: Array[int], chauffe: int) -> String:
	var l: PackedStringArray = []
	var n := _stamps.size()
	# image_ms[j] = durée de l'image j (début de la passe j → début de la passe j+1)
	var image_ms: Array[float] = []
	for j in n - 1:
		image_ms.append((_stamps[j + 1] - _stamps[j]) / 1000.0)
	var fonds: Array[float] = []
	var surcouts_tir: Array[float] = []
	var surcouts_impact: Array[float] = []
	var impacts: Array[float] = []
	var offsets := {}
	var decalages: Dictionary = {}
	var cumuls: Array[float] = []
	var premieres: Array[String] = []
	var d_part_tir: Array[float] = []
	var d_part_imp: Array[float] = []
	var d_traces: Array[float] = []
	var d_douilles: Array[float] = []
	var d_sons_tir: Array[float] = []
	var d_sons_imp: Array[float] = []
	var d_noeuds_imp: Array[float] = []
	var detail := String(_o.get("detail", "0")) == "1"
	var lignes_detail: PackedStringArray = []
	for v in tirs.size():
		var k: int = tirs[v]
		if k + 59 >= image_ms.size():
			continue
		var fond_v: Array[float] = []
		for j in range(k + 12, k + 55):
			fond_v.append(image_ms[j])
		var fond := _med(fond_v)
		# L'image d'impact : la première image f (≥ k) pendant laquelle au moins 8 particules naissent d'un coup (une étincelle de mur en
		# donne 12, une goutte de sang 25 ; les grains de fumée de la bouche, 3) — ou, à défaut (variante sans particules), des traces
		# d'impact apparaissent. Les traces seules ne suffisent pas : au plafond (90 éclats, 120 taches), un éclat neuf en évince un ancien et
		# l'effectif ne bouge plus.
		var f_imp := -1
		for f in range(k, k + 9):
			if _compteurs[f + 1][0] - _compteurs[f][0] >= 8:
				f_imp = f
				break
		if f_imp < 0:
			for f in range(k, k + 9):
				if _compteurs[f + 1][3] > _compteurs[f][3]:
					f_imp = f
					break
		var cumul := 0.0
		for j in range(k, k + 10):
			cumul += image_ms[j] - fond
			if not offsets.has(j - k):
				offsets[j - k] = []
			(offsets[j - k] as Array).append(image_ms[j] - fond)
		if v < chauffe:
			premieres.append("volée %d : tir %.2f ms, impact %s, cumul 10 images %+.2f ms (fond %.2f)" % [v + 1, image_ms[k] - fond,
				("%.2f ms (image +%d)" % [image_ms[f_imp] - fond, f_imp - k]) if f_imp >= 0 else "aucun", cumul, fond])
			continue
		fonds.append(fond)
		surcouts_tir.append(image_ms[k] - fond)
		cumuls.append(cumul)
		d_part_tir.append(float(_compteurs[k + 1][0] - _compteurs[k][0]))
		d_sons_tir.append(float(_compteurs[k + 1][2] - _compteurs[k][2]))
		d_traces.append(float(_compteurs[k + 10][3] - _compteurs[k][3]))
		d_douilles.append(float(_compteurs[k + 10][4] - _compteurs[k][4]))
		if f_imp >= 0:
			surcouts_impact.append(image_ms[f_imp] - fond)
			impacts.append(image_ms[f_imp])
			decalages[f_imp - k] = int(decalages.get(f_imp - k, 0)) + 1
			d_part_imp.append(float(_compteurs[f_imp + 1][0] - _compteurs[f_imp][0]))
			d_sons_imp.append(float(_compteurs[f_imp + 1][2] - _compteurs[f_imp][2]))
			d_noeuds_imp.append(float(_compteurs[f_imp + 1][1] - _compteurs[f_imp][1]))
		if detail:
			lignes_detail.append("    volée %d : tir %.2f ms · impact %s · cumul %+.2f ms · fond %.2f ms" % [v + 1, image_ms[k], ("%.2f ms (tir + %d)" % [image_ms[f_imp], f_imp - k]) if f_imp >= 0 else "—", cumul, fond])
	l.append("  volées mesurées (hors chauffe) : %d ; avec une image d'impact repérée : %d" % [fonds.size(), surcouts_impact.size()])
	l.append("  FOND (médiane des images hors de [tir, tir+11]) : %.3f ms (p90 %.3f)" % [_med(fonds), _pct(fonds, 0.9)])
	l.append("  SURCOÛT de l'image du TIR    : médiane %+.3f ms · p90 %+.3f · max %+.3f" % [_med(surcouts_tir), _pct(surcouts_tir, 0.9), _pct(surcouts_tir, 1.0)])
	if not surcouts_impact.is_empty():
		l.append("  SURCOÛT de l'image d'IMPACT  : médiane %+.3f ms · p90 %+.3f · max %+.3f   (durée de l'image d'impact : médiane %.3f ms)" % [_med(surcouts_impact), _pct(surcouts_impact, 0.9), _pct(surcouts_impact, 1.0), _med(impacts)])
		l.append("  l'impact tombe à tir + N images : %s (la question 2 de V3 : N = 0 serait « même image que le tir »)" % str(decalages))
	else:
		l.append("  aucune image d'impact repérée (aucune trace d'impact n'est créée : le tir part dans le vide, ou la variante les a retirées)")
	l.append("  SURCOÛT CUMULÉ sur les 10 images [tir, tir+9] : médiane %+.3f ms · p90 %+.3f · max %+.3f" % [_med(cumuls), _pct(cumuls, 0.9), _pct(cumuls, 1.0)])
	var ligne := PackedStringArray()
	for j in 10:
		ligne.append("+%d: %+.2f" % [j, _med(offsets.get(j, []))])
	l.append("  surcoût médian par image après le tir (ms) : " + " · ".join(ligne))
	l.append("  AUTO-CONTRÔLE (médianes par volée) — image du tir : particules %+.0f, sons %+.0f · image d'impact : particules %+.0f, sons %+.0f, nœuds %+.0f · traces d'impact créées (10 images) %+.0f · douilles %+.0f" % [
		_med(d_part_tir), _med(d_sons_tir), _med(d_part_imp), _med(d_sons_imp), _med(d_noeuds_imp), _med(d_traces), _med(d_douilles)])
	l.append("  les chauffes : " + " | ".join(premieres.slice(0, 4)))
	if detail:
		l.append("\n".join(lignes_detail))
	return "\n".join(l)
