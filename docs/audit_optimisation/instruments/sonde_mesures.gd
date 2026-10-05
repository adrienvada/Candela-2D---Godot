## Sonde de mesure de l'audit M (2026-10-04) — INSTRUMENT TEMPORAIRE, jamais commité.
##
## Échantillonne, image par image, le temps réel d'une image (horloge murale) et les moniteurs `Performance`
## TIME_PROCESS / TIME_PHYSICS_PROCESS ; tous les `palier` images, les compteurs d'objets et de mémoire (la DÉRIVE : une
## croissance = une fuite). Rend des statistiques (moyenne, p50, p99, max), une table par fenêtre de temps simulé, et la
## pente par minute de chaque compteur.
##
## Sans `class_name` : on l'obtient par `preload("res://tools/sonde_mesures.gd")`.
extends RefCounted

const MONITEURS_PALIER := {
	"objets": Performance.OBJECT_COUNT,
	"ressources": Performance.OBJECT_RESOURCE_COUNT,
	"noeuds": Performance.OBJECT_NODE_COUNT,
	"orphelins": Performance.OBJECT_ORPHAN_NODE_COUNT,
	"mem_statique": Performance.MEMORY_STATIC,
	"phys2d_actifs": Performance.PHYSICS_2D_ACTIVE_OBJECTS,
	"phys2d_paires": Performance.PHYSICS_2D_COLLISION_PAIRS,
	"phys2d_iles": Performance.PHYSICS_2D_ISLAND_COUNT,
}

## Un palier toutes les `palier` images (300 = 5 s de jeu à 60 images par seconde).
var palier := 300
var etiquette := ""
## Le pas de temps simulé d'une image, en secondes (sous `--fixed-fps 60`, 1/60) : sert à dater les paliers.
var pas := 1.0 / 60.0

var dt_ms: PackedFloat64Array = PackedFloat64Array()
var proc_ms: PackedFloat64Array = PackedFloat64Array()
var phys_ms: PackedFloat64Array = PackedFloat64Array()
var nav_ms: PackedFloat64Array = PackedFloat64Array()
## Les deux moniteurs de physique 2D, relevés à CHAQUE image (objets actifs, paires en collision).
## Sous `--fixed-fps` (un pas de physique par image) : le coût du pas de physique (du début de `physics_frame` au début de `process_frame` :
## le serveur de physique + tous les `_physics_process`) et « le reste » (du début de `process_frame` au début du `physics_frame` suivant :
## tous les `_process`, la synchronisation des serveurs, le dessin, l'audio de l'image).
var pas_phys_ms: PackedFloat64Array = PackedFloat64Array()
var reste_ms: PackedFloat64Array = PackedFloat64Array()
## Les images les plus lentes, avec leur rang : [durée ms, rang].
var _t_phys := -1
var _t_process_prec := -1
var p2d_actifs: PackedFloat64Array = PackedFloat64Array()
var p2d_paires: PackedFloat64Array = PackedFloat64Array()
## Les paliers : [{t, objets, …, rss_ko, extras…}]
var paliers: Array[Dictionary] = []

var _t_prec_us := -1
var _n := 0
var _extras: Callable = Callable()


## `extras` : appelée à chaque palier, rend un Dictionary de compteurs supplémentaires (balles, particules, groupes…).
func configurer(un_nom: String, une_etendue_palier: int, un_pas: float, des_extras: Callable = Callable()) -> void:
	etiquette = un_nom
	palier = une_etendue_palier
	pas = un_pas
	_extras = des_extras


## À appeler une fois pour armer la séparation physique / reste (un pas de physique par image exigé : `--fixed-fps`).
func armer_physique(arbre: SceneTree) -> void:
	arbre.physics_frame.connect(_sur_physique)


func _sur_physique() -> void:
	_t_phys = Time.get_ticks_usec()
	if _t_process_prec >= 0:
		reste_ms.append((_t_phys - _t_process_prec) / 1000.0)


## À appeler UNE fois par image (n'importe où dans la boucle, toujours au même endroit).
func image() -> void:
	var maintenant := Time.get_ticks_usec()
	_t_process_prec = maintenant
	if _t_phys >= 0:
		pas_phys_ms.append((maintenant - _t_phys) / 1000.0)
	if _t_prec_us >= 0:
		dt_ms.append((maintenant - _t_prec_us) / 1000.0)
		proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		nav_ms.append(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)
		p2d_actifs.append(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
		p2d_paires.append(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
		_n += 1
		if _n % palier == 1:
			_palier(_n * pas)
	_t_prec_us = maintenant


func _palier(t: float) -> void:
	var p := {"t": t}
	for cle in MONITEURS_PALIER:
		p[cle] = float(Performance.get_monitor(MONITEURS_PALIER[cle]))
	p["rss_ko"] = _lire_statut("VmRSS")
	p["pic_ko"] = _lire_statut("VmHWM")
	if _extras.is_valid():
		var e: Variant = _extras.call()
		if e is Dictionary:
			for cle in e:
				p[cle] = float(e[cle])
	paliers.append(p)


## Les compteurs propres au jeu, pris à chaque palier : balles, particules, traces au sol, gadgets, fusées, tampon de rejeu, tweens,
## et le recensement du F3 (lumières allumées, à ombre, occulteurs, nœuds du monde), plus le nombre de sous-vues.
static func extras_du_jeu(arbre: SceneTree, main: Node) -> Dictionary:
	var e := {}
	if main == null or not is_instance_valid(main):
		return e
	e["balles"] = main.bullet_container.get_child_count()
	e["particules"] = main.particle_pool.active_count()
	var traces := 0
	for g in main.GROUPES_DES_TRACES:
		traces += arbre.get_nodes_in_group(g).size()
	e["traces_sol"] = traces
	e["gadgets"] = arbre.get_nodes_in_group("gadgets").size()
	e["fusees"] = arbre.get_nodes_in_group("fusees").size()
	var rs: Node = arbre.root.get_node("ReplaySystem")
	e["rejeu_instantanes"] = (rs.snapshots as Array).size()
	e["rejeu_evts_balles"] = (rs.bullet_events as Array).size()
	e["tweens"] = arbre.get_processed_tweens().size()
	var lum := 0
	var ombrees := 0
	var noeuds := 0
	var occ := 0
	var pile: Array[Node] = []
	if is_instance_valid(main.arena):
		pile.append(main.arena.get_parent())
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		noeuds += 1
		if n is PointLight2D and (n as PointLight2D).is_visible_in_tree() and (n as PointLight2D).enabled:
			lum += 1
			if (n as PointLight2D).shadow_enabled:
				ombrees += 1
		elif n is LightOccluder2D:
			occ += 1
		for c in n.get_children():
			pile.append(c)
	e["lumieres"] = lum
	e["lumieres_ombrees"] = ombrees
	e["occulteurs"] = occ
	e["noeuds_monde"] = noeuds
	e["sous_vues"] = arbre.root.find_children("*", "SubViewport", true, false).size()
	return e


static func _lire_statut(cle: String) -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	var v := -1.0
	while not f.eof_reached():
		var ligne := f.get_line()
		if ligne.begins_with(cle + ":"):
			var morceaux := ligne.substr(cle.length() + 1).strip_edges().split(" ", false)
			v = float(morceaux[0])
			break
	f.close()
	return v


static func moyenne(a: PackedFloat64Array, de: int = 0, a_: int = -1) -> float:
	var fin := a.size() if a_ < 0 else mini(a_, a.size())
	if fin <= de:
		return 0.0
	var s := 0.0
	for i in range(de, fin):
		s += a[i]
	return s / float(fin - de)


static func centile(a: PackedFloat64Array, q: float, de: int = 0, a_: int = -1) -> float:
	var fin := a.size() if a_ < 0 else mini(a_, a.size())
	if fin <= de:
		return 0.0
	var t := a.slice(de, fin)
	t.sort()
	return t[mini(t.size() - 1, int(q * t.size()))]


static func maximum(a: PackedFloat64Array, de: int = 0, a_: int = -1) -> float:
	var fin := a.size() if a_ < 0 else mini(a_, a.size())
	var m := 0.0
	for i in range(de, fin):
		m = maxf(m, a[i])
	return m


## Pente par minute (moindres carrés) d'une série {t, v}, sur les paliers dont t >= depuis.
func pente_par_minute(cle: String, depuis: float) -> float:
	var xs: Array[float] = []
	var ys: Array[float] = []
	for p in paliers:
		if float(p["t"]) >= depuis and p.has(cle):
			xs.append(float(p["t"]))
			ys.append(float(p[cle]))
	if xs.size() < 2:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i]
		my += ys[i]
	mx /= xs.size()
	my /= xs.size()
	var num := 0.0
	var den := 0.0
	for i in xs.size():
		num += (xs[i] - mx) * (ys[i] - my)
		den += (xs[i] - mx) * (xs[i] - mx)
	return 0.0 if den == 0.0 else 60.0 * num / den


func rapport(depuis_s: float = 30.0) -> String:
	var l: PackedStringArray = []
	var n := dt_ms.size()
	l.append("=== SONDE %s : %d images, %.1f s de jeu simulé ===" % [etiquette, n, n * pas])
	if n == 0:
		return "\n".join(l)
	var i0 := mini(n - 1, int(depuis_s / pas))
	l.append("  (statistiques hors des %.0f premières secondes simulées : images %d à %d)" % [depuis_s, i0, n])
	l.append("  %-34s %9s %9s %9s %9s %9s" % ["par image (ms)", "moyenne", "p50", "p99", "p99,9", "max"])
	var lignes_stats := [["temps réel d'une image (mur)", dt_ms]]
	if not pas_phys_ms.is_empty():
		lignes_stats.append(["  dont pas de physique (mur)", pas_phys_ms])
		lignes_stats.append(["  dont le reste (process, dessin, audio)", reste_ms])
	lignes_stats.append_array([["TIME_PROCESS (max/s, rafraîchi 1/s)", proc_ms], ["TIME_PHYSICS_PROCESS (max/s, 1/s)", phys_ms], ["TIME_NAVIGATION_PROCESS (max/s)", nav_ms]])
	for ligne in lignes_stats:
		var a: PackedFloat64Array = ligne[1]
		l.append("  %-34s %9.3f %9.3f %9.3f %9.3f %9.3f" % [ligne[0], moyenne(a, i0), centile(a, 0.5, i0), centile(a, 0.99, i0), centile(a, 0.999, i0), maximum(a, i0)])
	l.append("  %-34s %9s %9s %9s %9s %9s" % ["physique 2D par image (compte)", "moyenne", "p50", "p99", "p99,9", "max"])
	for ligne in [["PHYSICS_2D_ACTIVE_OBJECTS", p2d_actifs], ["PHYSICS_2D_COLLISION_PAIRS", p2d_paires]]:
		var a2: PackedFloat64Array = ligne[1]
		l.append("  %-34s %9.2f %9.0f %9.0f %9.0f %9.0f" % [ligne[0], moyenne(a2, i0), centile(a2, 0.5, i0), centile(a2, 0.99, i0), centile(a2, 0.999, i0), maximum(a2, i0)])
	l.append("  (les moniteurs TIME_* du moteur ne sont mis à jour qu'UNE fois par seconde et portent le MAXIMUM de la seconde écoulée : `main.cpp`, `if (frame > 1000000)` — ils disent la pire image de chaque seconde, pas l'image moyenne ; le « temps réel » ci-dessus est l'horloge murale par image)")
	var tri: Array = range(dt_ms.size())
	tri.sort_custom(func(a, b) -> bool: return dt_ms[a] > dt_ms[b])
	var pires: PackedStringArray = []
	for k in mini(14, tri.size()):
		pires.append("%d: %.1f ms (%.1f s)" % [tri[k], dt_ms[tri[k]], tri[k] * pas])
	l.append("  les 14 images les plus lentes (rang : durée, date de jeu) : " + " · ".join(pires))
	l.append("  cadence moyenne atteignable : %.0f images par seconde de jeu (1000 / moyenne du temps réel)" % (1000.0 / maxf(moyenne(dt_ms, i0), 0.0001)))
	# Par fenêtre d'une minute de temps simulé : la dérive du coût.
	var fenetre := int(60.0 / pas)
	l.append("  par minute simulée (ms) :   mur moyen / mur p99 / process / physique / mur max")
	var k := 0
	while k * fenetre < n:
		var a_ := k * fenetre
		var b_ := mini(n, (k + 1) * fenetre)
		l.append("    min %d (%d images) : %8.3f / %8.3f / %8.3f / %8.3f / %8.3f" % [k + 1, b_ - a_, moyenne(dt_ms, a_, b_), centile(dt_ms, 0.99, a_, b_),
			moyenne(proc_ms, a_, b_), moyenne(phys_ms, a_, b_), maximum(dt_ms, a_, b_)])
		k += 1
	# Les compteurs : premier palier utile, dernier, pente par minute.
	if paliers.size() >= 2:
		var cles: Array = []
		for cle in paliers[0]:
			if cle != "t":
				cles.append(cle)
		l.append("  compteurs aux paliers (t = %.0f s … %.0f s ; pente par minute = moindres carrés dès t >= %.0f s)" % [float(paliers[0]["t"]), float(paliers[-1]["t"]), depuis_s])
		l.append("    %-14s %14s %14s %14s %12s" % ["", "premier", "dernier", "max", "pente/min"])
		var premier_utile := paliers[0]
		for p in paliers:
			if float(p["t"]) >= depuis_s:
				premier_utile = p
				break
		for cle in cles:
			var mx := -INF
			for p in paliers:
				mx = maxf(mx, float(p[cle]))
			l.append("    %-14s %14.0f %14.0f %14.0f %12.1f" % [cle, float(premier_utile[cle]), float(paliers[-1][cle]), mx, pente_par_minute(cle, depuis_s)])
	return "\n".join(l)


## Écrit les séries brutes (pour un traitement ultérieur) : un JSON compact.
func ecrire_json(chemin: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		printerr("sonde : impossible d'écrire ", chemin)
		return
	f.store_string(JSON.stringify({"etiquette": etiquette, "pas": pas, "palier": palier,
		"dt_ms": Array(dt_ms), "proc_ms": Array(proc_ms), "phys_ms": Array(phys_ms), "paliers": paliers}))
	f.close()
