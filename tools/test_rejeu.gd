## `ReplaySystem` — la killcam, et les deux défauts qu'elle a déjà coûtés.
##
## L'étude de robustesse du 2026-08-16 le relevait : « `ReplaySystem` n'a pas de
## test unitaire ; seule `test_online_match` compte des balles rejouées ». Or ce
## système a produit **deux défauts réels**, tous deux invisibles à la lecture :
##
## 1. **Le tampon était dimensionné en NOMBRE D'IMAGES.** Les fps étant
##    déplafonnés pour la latence EOS, une machine à 492 fps remplissait la
##    fenêtre huit fois plus vite : la killcam tombait à 0,9 seconde. Le remède
##    fut la cadence fixe à 60 Hz — que rien ne vérifie depuis.
## 2. **`impact_frame` repassait par sa propre sentinelle.** Quand la mort sortait
##    de la fenêtre, l'indice décrémentait jusqu'à -1, qui signifie « aucun
##    impact » : la killcam se recalait alors sur la fin de l'enregistrement,
##    c'est-à-dire après la mort, sans la balle qui l'avait causée.
##
## Les deux se ressemblent : une grandeur juste, exprimée dans la mauvaise unité,
## ou franchissant une valeur qui a un autre sens. Aucune ne lève d'erreur.
##
## ## Étape 28, lot F — la killcam rejoue les GADGETS (2026-09-12)
##
## Un troisième défaut, de la même famille que les deux ci-dessus : la killcam
## montrait la mort **sans sa cause**. Une mine consumée, un leurre abattu ou une
## nappe éteinte en étaient absents, et les gadgets encore debout y figuraient dans
## leur état PRÉSENT — une mine posée après la mort brûlait dans une image où elle
## n'existait pas. Là encore, aucune erreur.
##
## ⚠️ **La dernière section monte `main.tscn`** (patron de `tools/test_classes.gd`) :
## tout ce qui précède reste pur, et c'est ce qui permet à la suite de tourner en
## `--script`. Aucun autoload n'est nommé à la compilation — `ReplaySystem` s'atteint
## par `root.get_node()`.
##
## Lancer : godot --headless --path . --script res://tools/test_rejeu.gd
extends SceneTree

## ⚠️ **`preload` par CHEMIN, jamais l'identifiant global** (patron de
## `tools/test_classes.gd`) : en `--script`, le cache des classes globales n'est pas
## encore peuplé, et nommer un autoload ferait cesser le fichier ENTIER de compiler.
const Rejeu := preload("res://replay_system.gd")
const GadgetMine := preload("res://gadget_mine.gd")
const GadgetBraises := preload("res://gadget_braises.gd")
const GadgetVoile := preload("res://gadget_voile.gd")
const GadgetPoudre := preload("res://gadget_poudre.gd")
const MapGeometry := preload("res://map_geometry.gd")

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

## Un joueur d'essai : juste ce que `record_frame` va lire chez lui.
##
## Une vraie classe et non un `Node2D` sur lequel on poserait des propriétés au
## vol : `Object.set()` sur un nom inconnu ne crée rien, il échoue — et comme
## l'échec n'interrompt que la fonction en cours, la suite continue et annonce
## des résultats sur un objet vide. Le piège du jour, une troisième fois.
class FauxJoueur extends Node2D:
	var hp: float = 100.0
	var flashlight_on: bool = false
	var visual: Node2D
	var current_weapon = null
	## Étape 28, lot F — le facteur de lampe rendu, que `record_frame` lit désormais.
	## ⚠️ Sans ce champ, l'accès échoue, la fonction en cours s'arrête, et **toute**
	## la suite annonce des résultats sur des instantanés jamais remplis : le piège
	## décrit juste au-dessus, une quatrième fois. (Vu rouge le 2026-09-11 : 3 014
	## `SCRIPT ERROR` et dix contrôles en échec, avant l'ajout de cette ligne.)
	var facteur_de_lampe_rendu: float = 1.0

func _faux_joueur() -> FauxJoueur:
	var n := FauxJoueur.new()
	n.visual = Node2D.new()
	n.visual.name = "Visual"
	n.add_child(n.visual)
	var flash := PointLight2D.new()
	flash.name = "MuzzleFlash"
	flash.enabled = false
	n.add_child(flash)
	return n

func _run() -> void:
	print("=== REJEU (KILLCAM) ===")
	_test_cadence()
	_test_fenetre_en_duree()
	_test_impact_unique()
	_test_sentinelle()
	_test_ancrage()
	_test_trajectoire()
	_test_ancre_dans_le_tampon()
	# Étape 28, lot F — les gadgets, d'abord sans rien monter…
	_test_gadgets_enregistres()
	_test_age_en_secondes()
	_test_melange_gadgets()
	_test_lampe_rendue()
	_test_traces_enregistrees()
	_mesure_cout_enregistrement()
	# … puis sur le vrai jeu.
	await _test_killcam_gadgets()
	await _test_killcam_par_le_process()
	await _test_dix_gadgets()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

## Un système prêt à enregistrer, avec ses deux joueurs et son conteneur.
func _banc() -> Array:
	var r: Node = Rejeu.new()
	root.add_child(r)
	var p1 := _faux_joueur()
	var p2 := _faux_joueur()
	var balles := Node2D.new()
	root.add_child(p1)
	root.add_child(p2)
	root.add_child(balles)
	r.start_recording()
	return [r, p1, p2, balles]

func _liberer(banc: Array) -> void:
	for n in banc:
		(n as Node).queue_free()

# ---------------------------------------------------------------------------

func _test_cadence() -> void:
	print("\n[La cadence ne suit pas les fps]")
	var b := _banc()
	var r: Node = b[0]
	# Une machine à 492 fps, une seconde de jeu. Le tampon doit contenir des
	# soixantièmes de seconde, pas des images de rendu.
	var pas := 1.0 / 492.0
	for i in 492:
		r.record_frame(b[1], b[2], b[3], pas)
	var n: int = r.snapshots.size()
	_check("une seconde à 492 fps donne ~60 images", n >= 58 and n <= 62,
		"%d images enregistrées" % n)

	# Et une machine lente ne doit pas enregistrer MOINS d'une seconde de jeu :
	# la période est soustraite et non remise à zéro, justement pour ça.
	var b2 := _banc()
	var r2: Node = b2[0]
	for i in 61:
		r2.record_frame(b2[1], b2[2], b2[3], 1.0 / 61.0)
	var n2: int = r2.snapshots.size()
	_check("une seconde à 61 fps donne ~60 images aussi", n2 >= 58 and n2 <= 62,
		"%d images enregistrées" % n2)
	_liberer(b)
	_liberer(b2)

func _test_fenetre_en_duree() -> void:
	print("\n[Le tampon se mesure en secondes]")
	var b := _banc()
	var r: Node = b[0]
	var duree: float = float(r.max_snapshots) / r.RECORD_HZ
	_check("le tampon vaut 7,5 s de jeu", is_equal_approx(duree, 7.5),
		"%.2f s (%d images à %.0f Hz)" % [duree, r.max_snapshots, r.RECORD_HZ])
	# Et il tient sa borne quoi qu'il arrive : trois fois trop d'images
	# enregistrées ne doivent pas faire enfler la mémoire.
	for i in int(r.max_snapshots * 3):
		r.record_frame(b[1], b[2], b[3], 1.0 / 60.0)
	_check("le tampon ne déborde jamais", r.snapshots.size() <= r.max_snapshots,
		"%d > %d" % [r.snapshots.size(), r.max_snapshots])
	_liberer(b)

func _test_impact_unique() -> void:
	print("\n[La mort ne se produit qu'une fois]")
	var b := _banc()
	var r: Node = b[0]
	var p1: FauxJoueur = b[1]
	var p2: FauxJoueur = b[2]
	for i in 30:
		r.record_frame(p1, p2, b[3], 1.0 / 60.0)
	p1.hp = 0.0
	r.record_frame(p1, p2, b[3], 1.0 / 60.0)
	var premier: int = r.impact_frame
	_check("la mort pose l'ancre", premier > 0, str(premier))

	# L'autre joueur meurt juste après — mort simultanée, ou dégâts de zone. La
	# killcam doit rester calée sur la PREMIÈRE : c'est celle qui a fini la
	# manche, et déplacer l'ancre montrerait la mauvaise balle.
	p2.hp = 0.0
	for i in 20:
		r.record_frame(p1, p2, b[3], 1.0 / 60.0)
	_check("une seconde mort ne déplace pas l'ancre", r.impact_frame == premier,
		"%d → %d" % [premier, r.impact_frame])
	_liberer(b)

func _test_sentinelle() -> void:
	print("\n[L'ancre ne repasse pas par sa sentinelle]")
	var b := _banc()
	var r: Node = b[0]
	var p1: FauxJoueur = b[1]
	# La mort survient tôt, puis on enregistre bien au-delà du tampon : l'ancre
	# recule à chaque image jetée. C'est là que le défaut vivait — arrivée à 0,
	# elle continuait vers -1, qui veut dire « aucun impact ».
	p1.hp = 0.0
	r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	for i in int(r.max_snapshots * 2):
		r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	_check("l'ancre s'arrête à zéro, jamais à -1", r.impact_frame >= 0,
		"impact_frame = %d" % r.impact_frame)
	_check("le départ du ralenti aussi", r.slow_mo_start_frame >= 0,
		"slow_mo_start_frame = %d" % r.slow_mo_start_frame)
	_liberer(b)

func _test_ancrage() -> void:
	print("\n[La fenêtre se cale sur l'impact, pas sur la fin]")
	var b := _banc()
	var r: Node = b[0]
	var p1: FauxJoueur = b[1]
	for i in 240:
		r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	p1.hp = 0.0
	r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	var ancre: int = r.impact_frame
	# L'enregistrement CONTINUE après la mort — le sang, la réaction. Une fenêtre
	# calée sur la fin laisserait le tir fatal hors champ.
	p1.hp = 100.0
	for i in 90:
		r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	r.start_playback()
	var attendu := maxf(0.0, float(ancre) - r.PRE_IMPACT_FRAMES)
	# Le tir fatal est plus ancien que trois secondes ici : c'est lui qui décide.
	if r.slow_mo_start_frame != -1:
		attendu = minf(attendu, float(r.slow_mo_start_frame) - r.PRE_SHOT_MARGIN)
		attendu = maxf(0.0, attendu)
	_check("le rejeu démarre avant l'impact, pas avant la fin",
		is_equal_approx(r.playback_index, attendu),
		"index %.1f, attendu %.1f, ancre %d, total %d"
		% [r.playback_index, attendu, ancre, r.snapshots.size()])
	_check("et il démarre bien AVANT l'ancre", r.playback_index < float(ancre))
	_liberer(b)

## V6.2 — d'où venait le coup, et quand on ne peut pas le dire.
##
## Le contrôle qui compte est le second : **une trajectoire fausse enseignerait
## une leçon fausse**, ce qui est pire que de ne rien enseigner. La killcam sert
## à comprendre d'où le coup est parti ; une ligne qui désignerait le mauvais
## endroit ferait apprendre une position qui n'a jamais existé.
func _test_trajectoire() -> void:
	print("\n[La trajectoire du tir fatal]")
	var b := _banc()
	var r: Node = b[0]
	var p1: FauxJoueur = b[1]
	var p2: FauxJoueur = b[2]

	# Sans mort, rien à tracer : l'enregistrement n'a pas d'ancre d'impact.
	for i in 10:
		r.record_frame(p1, p2, b[3], 1.0 / 60.0)
	_check("sans mort, aucune trajectoire", r.trajectoire_fatale().is_empty())

	# P2 tire, puis P1 meurt : la ligne va du tir vers la victime.
	r.record_bullet_fired(1, Vector2(100, 50), 0.0, null)
	for i in 5:
		r.record_frame(p1, p2, b[3], 1.0 / 60.0)
	p1.global_position = Vector2(400, 50)
	p1.hp = 0.0
	r.record_frame(p1, p2, b[3], 1.0 / 60.0)
	var t: PackedVector2Array = r.trajectoire_fatale()
	_check("la ligne part du tir du tueur", t.size() == 2 and t[0] == Vector2(100, 50),
		str(t))
	_check("et arrive sur la victime", t.size() == 2 and t[1] == Vector2(400, 50),
		str(t))
	_liberer(b)

	# Un tir de la VICTIME juste avant sa mort ne doit pas être pris pour le tir
	# fatal : c'est l'erreur qu'un simple « dernier tir enregistré » commettrait,
	# et elle désignerait la position du mort comme origine du coup.
	var c := _banc()
	var r2: Node = c[0]
	var q1: FauxJoueur = c[1]
	var q2: FauxJoueur = c[2]
	r2.record_bullet_fired(1, Vector2(10, 10), 0.0, null)
	for i in 3:
		r2.record_frame(q1, q2, c[3], 1.0 / 60.0)
	r2.record_bullet_fired(0, Vector2(900, 900), 0.0, null)
	q1.global_position = Vector2(500, 500)
	q1.hp = 0.0
	r2.record_frame(q1, q2, c[3], 1.0 / 60.0)
	var t2: PackedVector2Array = r2.trajectoire_fatale()
	_check("le dernier tir de la victime n'est pas le tir fatal",
		t2.size() == 2 and t2[0] == Vector2(10, 10), str(t2))
	_liberer(c)

## L'ancre d'impact désigne-t-elle une image qui existe encore ?
##
## Hypothèse à écarter ou confirmer, née de l'instrumentation du 2026-08-18 : le
## rejeu s'arrêtait à l'index ~185 alors que `impact_frame` valait 203. La borne
## de `get_next_frame` est `idx1 >= snapshots.size() - 1` — donc un tampon plus
## COURT que l'ancre expliquerait tout : la lecture s'arrêterait à la fin du
## tampon, avant d'atteindre l'impact, sans la moindre erreur.
func _test_ancre_dans_le_tampon() -> void:
	print("\n[L'ancre d'impact tombe-t-elle dans le tampon ?]")
	var b := _banc()
	var r: Node = b[0]
	var p1: FauxJoueur = b[1]
	for i in 200:
		r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	p1.hp = 0.0
	r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	# L'enregistrement CONTINUE après la mort — le sang, la réaction — puis
	# s'arrête. C'est ce qui doit donner au rejeu de quoi atteindre l'impact.
	p1.hp = 100.0
	for i in 40:
		r.record_frame(p1, b[2], b[3], 1.0 / 60.0)
	r.stop_recording()

	_check("l'ancre est dans le tampon",
		r.impact_frame < r.snapshots.size(),
		"impact=%d, tampon=%d" % [r.impact_frame, r.snapshots.size()])
	# Et il doit rester des images APRÈS l'impact : la borne d'arrêt étant
	# `size - 1`, une ancre posée sur la dernière image ferait cesser la lecture
	# au moment précis où elle devrait montrer la mort.
	_check("il reste des images après l'impact",
		r.snapshots.size() - 1 > r.impact_frame,
		"impact=%d, dernière=%d" % [r.impact_frame, r.snapshots.size() - 1])
	_liberer(b)


# ---------------------------------------------------------------------------
# ÉTAPE 28, LOT F — LES GADGETS DANS LA KILLCAM
# ---------------------------------------------------------------------------

## T1 — ce qui est debout dans le conteneur entre dans l'instantané, et rien d'autre.
func _test_gadgets_enregistres() -> void:
	print("\n[Les gadgets debout entrent dans l'instantané]")
	var b := _banc()
	var r: Node = b[0]
	var balles: Node2D = b[3]
	r.record_frame(b[1], b[2], balles, 0.0)
	_check("témoin : avant la pose, l'instantané ne porte aucun gadget",
		r.snapshots[-1].gadgets.is_empty(), str(r.snapshots[-1].gadgets.size()))

	var mine := GadgetMine.new()
	mine.name = "GadgetJ1_1"
	mine.slug = "mine_magnesium"
	balles.add_child(mine)
	mine.allumer()
	r.record_frame(b[1], b[2], balles, 0.0)
	var gadgets: Array = r.snapshots[-1].gadgets
	_check("un gadget posé, une entrée", gadgets.size() == 1, str(gadgets.size()))
	if gadgets.size() == 1:
		var d: Dictionary = gadgets[0]
		_check("il dit son nom", String(d["nom"]) == "GadgetJ1_1", String(d["nom"]))
		# C'est ce champ qui rebâtit la copie : sans lui, il faudrait une table à
		# tenir d'accord avec le catalogue, et un second chemin de choix de classe.
		_check("et son SCRIPT, qui rebâtira la même classe", d["script"] == GadgetMine,
			str(d["script"]))
		_check("le slug voyage pour le diagnostic",
			String(d["slug"]) == "mine_magnesium", String(d["slug"]))
		_check("une mine allumée le dit", bool(d["allumee"]))
		_check("et elle brûle à plein", is_equal_approx(float(d["energie"]), 1.0),
			str(d["energie"]))

	# ⚠️ Le rejeu ne doit jamais s'enregistrer lui-même : une copie de killcam reste
	# hors du groupe « gadgets », et c'est la seule chose qui l'en empêche.
	var copie := GadgetMine.new()
	copie.is_replay = true
	copie.name = "Rejeu_GadgetJ1_1"
	balles.add_child(copie)
	r.record_frame(b[1], b[2], balles, 0.0)
	_check("une copie de killcam n'entre pas dans l'enregistrement",
		r.snapshots[-1].gadgets.size() == 1, str(r.snapshots[-1].gadgets.size()))
	_liberer(b)


## T2 — l'âge d'un gadget se compte en SECONDES DE JEU, pas en images de rendu.
##
## C'est ce qui garantit que la copie rejoue la mine à la bonne vitesse : le premier
## défaut de ce fichier — un tampon dimensionné en images — se reproduirait ici sur
## la combustion, et une mine brûlerait huit fois trop vite sur une machine rapide.
func _test_age_en_secondes() -> void:
	print("\n[L'âge d'un gadget avance en secondes de jeu]")
	var b := _banc()
	var r: Node = b[0]
	var balles: Node2D = b[3]
	var mine := GadgetMine.new()
	mine.name = "GadgetJ1_1"
	balles.add_child(mine)
	# Une machine à 492 fps, une seconde de jeu : l'âge du gadget avance du pas de
	# rendu, l'enregistrement ne doit retenir que des soixantièmes de seconde.
	var pas := 1.0 / 492.0
	for i in 492:
		mine._age += pas
		r.record_frame(b[1], b[2], balles, pas)
	var n: int = r.snapshots.size()
	_check("une seconde à 492 fps donne ~60 instantanés", n >= 58 and n <= 62, str(n))
	var portent := n > 0
	for s in r.snapshots:
		if s.gadgets.size() != 1:
			portent = false
			break
	_check("et chacun porte le gadget", portent)
	if portent:
		var pire := 0.0
		for i in range(1, r.snapshots.size()):
			var a: float = float(r.snapshots[i - 1].gadgets[0]["age"])
			var c: float = float(r.snapshots[i].gadgets[0]["age"])
			pire = maxf(pire, absf((c - a) - r.RECORD_PERIOD))
		_check("deux instantanés consécutifs sont écartés d'une période d'enregistrement",
			pire <= pas + 1e-6, "écart maximal %.6f s (toléré %.6f)" % [pire, pas])
	_liberer(b)


## T3 — le mélange de deux instantanés emporte les gadgets, la lampe et les traces.
##
## ⚠️ Il se fait dans `_melanger()` et nulle part ailleurs : le pré-tracé de DA4.6
## l'appelle directement pour figer une image, et un mélange posé au site d'appel
## rendrait une demi-seconde de killcam SANS gadgets, sans la moindre erreur.
func _test_melange_gadgets() -> void:
	print("\n[Le mélange de deux instantanés porte les gadgets]")
	var b := _banc()
	var r: Node = b[0]
	var s1 = Rejeu.Snapshot.new()
	var s2 = Rejeu.Snapshot.new()
	s1.gadgets = [{"nom": "G", "script": GadgetMine, "poseur": 0, "rot": 0.0,
		"energie": 0.2, "age": 1.0, "allumee": false}]
	s2.gadgets = [{"nom": "G", "script": GadgetMine, "poseur": 0, "rot": 0.2,
		"energie": 0.6, "age": 1.0 + r.RECORD_PERIOD, "allumee": true}]
	s1.p1_lampe = 0.25
	s2.p1_lampe = 1.0
	s1.traces = PackedFloat32Array([1.0, 2.0, 3.0, 0.5])
	var out = Rejeu.Snapshot.new()
	r._melanger(out, s1, s2, 0.5)
	# ⚠️ La taille d'abord : une égalité sur du vide passerait toujours.
	_check("le mélange porte le gadget", out.gadgets.size() == 1,
		str(out.gadgets.size()))
	if out.gadgets.size() == 1:
		var m: Dictionary = out.gadgets[0]
		_check("l'angle s'interpole", is_equal_approx(float(m["rot"]), 0.1), str(m["rot"]))
		_check("l'énergie aussi", is_equal_approx(float(m["energie"]), 0.4),
			str(m["energie"]))
		_check("l'âge avance d'une demi-période, EN SECONDES",
			absf(float(m["age"]) - (1.0 + r.RECORD_PERIOD * 0.5)) < 1e-6, str(m["age"]))
		_check("un allumage ne se fait pas à moitié", not bool(m["allumee"]))
		_check("le poseur reste un entier", typeof(m["poseur"]) == TYPE_INT)
		_check("et le script reste le même objet", m["script"] == GadgetMine)
	_check("la lampe rendue s'interpole", is_equal_approx(out.p1_lampe, 0.625),
		str(out.p1_lampe))
	_check("les traces sont recopiées",
		out.traces.size() == 4 and is_equal_approx(out.traces[3], 0.5), str(out.traces))

	# Absent de la seconde image — il meurt entre les deux : il garde son état et
	# vieillit de la fraction d'image, comme une fusée.
	s2.gadgets = []
	var out2 = Rejeu.Snapshot.new()
	r._melanger(out2, s1, s2, 0.5)
	_check("un gadget mort entre deux images vieillit d'une demi-période",
		out2.gadgets.size() == 1
			and absf(float(out2.gadgets[0]["age"]) - (1.0 + r.RECORD_PERIOD * 0.5)) < 1e-6,
		str(out2.gadgets))
	_liberer(b)


## T4 — la lampe TELLE QU'ELLE A ÉTÉ RENDUE. Sans elle, le fantôme rejoue une torche
## toujours pleine, et une mort par bobine reste sans cause à l'écran.
func _test_lampe_rendue() -> void:
	print("\n[La lampe rendue entre dans l'instantané]")
	var b := _banc()
	var r: Node = b[0]
	# ⚠️ **Deux valeurs distinctes, et aucune égale au défaut.** `Snapshot.p2_lampe` et
	# `FauxJoueur.facteur_de_lampe_rendu` valent 1.0 tous les deux : un contrôle sur
	# `p2_lampe == 1.0` passe que la ligne d'enregistrement existe ou non, et la lampe
	# de J2 n'était donc gardée par rien — un fantôme sur deux aurait retrouvé sa
	# torche toujours pleine sans qu'un seul contrôle rougisse. (Trouvé en revue le
	# 2026-09-12, sabotage à l'appui : la ligne retirée, la suite restait verte.)
	b[1].facteur_de_lampe_rendu = 0.25
	b[2].facteur_de_lampe_rendu = 0.75
	r.record_frame(b[1], b[2], b[3], 0.0)
	var s = r.snapshots[-1]
	_check("le facteur de J1 est enregistré", is_equal_approx(s.p1_lampe, 0.25),
		str(s.p1_lampe))
	_check("et celui de J2, qui n'est pas le même", is_equal_approx(s.p2_lampe, 0.75),
		str(s.p2_lampe))
	_liberer(b)


## T5 — les traces de poudre, qui vivent dans l'ARÈNE et non dans le gadget.
func _test_traces_enregistrees() -> void:
	print("\n[Les traces de poudre sont enregistrées]")
	var b := _banc()
	var r: Node = b[0]
	var attendues := {}
	var posees: Array[Node] = []
	for i in 3:
		var m := GadgetPoudre.nouvelle_trace()
		m.global_position = Vector2(100.0 + i * 10.0, 50.0 - i * 4.0)
		m.rotation = 0.3 * float(i + 1)
		m.modulate.a = 0.5
		m.add_to_group("traces_de_poudre")
		root.add_child(m)
		attendues[m.global_position] = m.rotation
		posees.append(m)
	# Une trace éteinte : elle n'informe plus personne, elle ne doit rien coûter.
	var eteinte := GadgetPoudre.nouvelle_trace()
	eteinte.global_position = Vector2(-999.0, -999.0)
	eteinte.modulate.a = 0.0
	eteinte.add_to_group("traces_de_poudre")
	root.add_child(eteinte)
	posees.append(eteinte)

	r.record_frame(b[1], b[2], b[3], 0.0)
	var t: PackedFloat32Array = r.snapshots[-1].traces
	_check("témoin : la trace éteinte est exclue — trois traces font douze flottants",
		t.size() == 12, str(t.size()))
	if t.size() == 12:
		var toutes := true
		for i in 3:
			var p := Vector2(t[i * 4], t[i * 4 + 1])
			if not attendues.has(p) \
					or not is_equal_approx(float(attendues[p]), t[i * 4 + 2]) \
					or not is_equal_approx(t[i * 4 + 3], 0.5):
				toutes = false
		_check("chacune porte son lieu, son cap et son alpha", toutes, str(t))
	for m in posees:
		m.queue_free()
	_liberer(b)


## M1 — ce que l'enregistrement COÛTE, relevé IMPRIMÉ et jamais contrôlé.
##
## ⚠️ **Un relevé, pas une borne.** Un chronomètre en suite serait instable d'une
## machine et d'une charge à l'autre, et une suite qui rougit au hasard finit par
## être ignorée. Le chiffre est ici pour être lu et consigné dans la ROADMAP : c'est
## ce que le lot coûte en COMPÉTITION, à 60 Hz, dans chaque manche.
func _mesure_cout_enregistrement() -> void:
	print("\n[M1 — coût de `record_frame`, relevé imprimé]")
	var b := _banc()
	var r: Node = b[0]
	var balles: Node2D = b[3]
	var mine := GadgetMine.new()
	mine.name = "GadgetJ1_1"
	balles.add_child(mine)
	mine.allumer()
	var braises := GadgetBraises.new()
	braises.name = "GadgetJ2_1"
	balles.add_child(braises)
	var traces: Array[Node] = []
	for i in 144:
		var m := GadgetPoudre.nouvelle_trace()
		m.global_position = Vector2(float(i), float(i))
		m.modulate.a = 0.5
		m.add_to_group("traces_de_poudre")
		root.add_child(m)
		traces.append(m)

	var t0 := Time.get_ticks_usec()
	for i in 600:
		r.record_frame(b[1], b[2], balles, 0.0)
	var charge := float(Time.get_ticks_usec() - t0) / 600.0

	mine.free()
	braises.free()
	for m in traces:
		m.free()
	var t1 := Time.get_ticks_usec()
	for i in 600:
		r.record_frame(b[1], b[2], balles, 0.0)
	var nu := float(Time.get_ticks_usec() - t1) / 600.0

	print("  MESURE record_frame : %.1f µs avec 2 gadgets et 144 traces, %.1f µs sans (écart %.1f µs)"
		% [charge, nu, charge - nu])
	print("  (marge de cadence d'une image à 60 fps tenue : 139 µs)")
	_liberer(b)


# ---------------------------------------------------------------------------
# ⚠️ CETTE SECTION MONTE main.tscn — patron de `tools/test_classes.gd`
# ---------------------------------------------------------------------------

func _monter_le_jeu() -> Node:
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		return null
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	return main


## Le compte des lumières ALLUMÉES sous un nœud — le critère exact du compteur F3
## (`ui.gd`) : `is_visible_in_tree()` ET `enabled`. C'est lui qui dit si le rejeu
## tient le budget de lumières, le moteur n'en gardant que quinze par item.
func _lumieres_visibles(racine: Node) -> int:
	var n := 0
	var pile: Array[Node] = [racine]
	while not pile.is_empty():
		var x: Node = pile.pop_back()
		var l := x as PointLight2D
		if l != null and l.is_visible_in_tree() and l.enabled:
			n += 1
		for e in x.get_children():
			pile.append(e)
	return n


func _est_une_source(main: Node, noeud: Node) -> bool:
	for s in main._sources_eblouissantes():
		if s["noeud"] == noeud:
			return true
	return false


## T6 — la demande d'Adrien, mot pour mot : le gadget MORT se rejoue, le gadget
## VIVANT s'efface, et le rejeu n'ajoute que les lumières de ses propres copies.
func _test_killcam_gadgets() -> void:
	print("\n[La killcam rejoue les gadgets, et masque le présent]")
	var main: Node = await _monter_le_jeu()
	if main == null:
		_check("main.tscn se charge", false)
		return
	var bc: Node = main.bullet_container

	# ── Le PRÉSENT : un voile, une nappe de braises, une trace ───────────────
	var voile = GadgetVoile.new()
	voile.name = "GadgetJ2_1"
	voile.poseur_id = 1
	bc.add_child(voile)
	var couche_voile: int = voile.collision_layer
	_check("témoin : le voile vivant porte les DEUX couches",
		couche_voile == MapGeometry.GADGET_LAYER | MapGeometry.GADGET_BLOQUANT_LAYER,
		str(couche_voile))
	var braises = GadgetBraises.new()
	braises.name = "GadgetJ1_2"
	braises.poseur_id = 0
	bc.add_child(braises)
	var trace := GadgetPoudre.nouvelle_trace()
	trace.name = "TraceVivante"
	trace.global_position = Vector2(400.0, 400.0)
	trace.modulate.a = 0.5
	trace.add_to_group("traces_de_poudre")
	main.arena.add_child(trace)
	await process_frame
	_check("témoin : une seule lumière allumée sous les balles, celle de la braise",
		_lumieres_visibles(bc) == 1, str(_lumieres_visibles(bc)))
	_check("témoin : la braise vivante est une source d'éblouissement",
		_est_une_source(main, braises))

	# ── Le PASSÉ : une mine allumée, puis consumée ───────────────────────────
	var mine = GadgetMine.new()
	mine.name = "GadgetJ1_1"
	mine.slug = "mine_magnesium"
	mine.poseur_id = 0
	bc.add_child(mine)
	mine.allumer()
	var etat: Dictionary = mine.etat_de_rejeu()
	mine.free()

	var snap = Rejeu.Snapshot.new()
	snap.gadgets = [etat]
	snap.traces = PackedFloat32Array([300.0, 300.0, 0.0, 0.4, 340.0, 300.0, 1.0, 0.2])
	main._maj_gadgets_killcam(snap)

	var copie: Node = bc.get_node_or_null("Rejeu_GadgetJ1_1")
	_check("(a) la copie du gadget mort existe", copie != null)
	if copie != null:
		_check("(a) elle se sait rejeu", copie.is_replay)
		_check("(a) elle reste HORS du groupe des gadgets",
			not copie.is_in_group("gadgets"))
		_check("(a) et sans physique : l'instantané fait foi",
			not copie.is_physics_processing())
		var feu = copie.get_node_or_null("Embrasement")
		var brule: bool = feu is PointLight2D and feu.enabled and feu.is_visible_in_tree() \
			and feu.energy > 0.0 \
			and is_equal_approx(feu.energy, GadgetMine.ENERGIE * float(etat["energie"]))
		_check("(b) la mine consumée se rejoue ALLUMÉE, à l'énergie enregistrée",
			brule, str(feu.energy) if feu is PointLight2D else "aucun Embrasement")
	_check("(c) le voile vivant est masqué", not voile.is_visible_in_tree())
	_check("(c) et sort de toute couche de collision", voile.collision_layer == 0,
		str(voile.collision_layer))
	_check("(c) la braise vivante est masquée aussi", not braises.is_visible_in_tree())
	_check("(d) le rejeu n'ajoute que les lumières de SES copies",
		_lumieres_visibles(bc) == 1, str(_lumieres_visibles(bc)))
	_check("(e) ni la copie ni la braise masquée n'éblouissent",
		not _est_une_source(main, braises)
			and (copie == null or not _est_une_source(main, copie)))
	var tk = main._traces_killcam
	_check("(f) les deux traces du passé sont posées",
		tk != null and tk.get_child_count() == 2,
		str(tk.get_child_count()) if tk != null else "aucun conteneur")
	if tk != null and tk.get_child_count() == 2:
		_check("(f) à leurs alphas d'instantané",
			is_equal_approx(tk.get_child(0).modulate.a, 0.4)
				and is_equal_approx(tk.get_child(1).modulate.a, 0.2),
			"%.2f / %.2f" % [tk.get_child(0).modulate.a, tk.get_child(1).modulate.a])
	_check("(f) et la trace VIVANTE est cachée", not trace.visible)

	# Image suivante : la mine n'est plus dans l'instantané, sa copie part.
	var snap2 = Rejeu.Snapshot.new()
	main._maj_gadgets_killcam(snap2)
	_check("un gadget absent de l'image suivante : sa copie part",
		copie == null or copie.is_queued_for_deletion())
	await process_frame

	main._purger_gadgets_killcam()
	_check("le voile vivant revient", voile.is_visible_in_tree())
	_check("et retrouve sa couche EXACTE", voile.collision_layer == couche_voile,
		str(voile.collision_layer))
	_check("la lueur de la braise est de nouveau comptée",
		_lumieres_visibles(bc) == 1, str(_lumieres_visibles(bc)))
	_check("la trace vivante revient", trace.visible)
	_check("le conteneur des traces du passé est libéré",
		not is_instance_valid(main._traces_killcam))
	_check("et le rejeu se sait terminé", not main._rejeu_gadgets_en_cours)

	# ⚠️ **Témoin de discrimination** : sans lui, (b) passerait pour n'importe quelle
	# copie, allumée ou non — c'est l'ALLUMAGE qu'il juge, pas la présence.
	var eteint: Dictionary = etat.duplicate()
	eteint["nom"] = "GadgetJ1_9"
	eteint["allumee"] = false
	eteint["energie"] = 0.0
	var snap3 = Rejeu.Snapshot.new()
	snap3.gadgets = [eteint]
	main._maj_gadgets_killcam(snap3)
	var froide: Node = bc.get_node_or_null("Rejeu_GadgetJ1_9")
	_check("témoin : une mine ÉTEINTE se rejoue sans flamme",
		froide != null and froide.get_node_or_null("Embrasement") == null)

	main._abort_killcam()
	await process_frame
	main.queue_free()


## T7 — par le VRAI chemin : `start_playback()` puis `_process`. Un test qui force
## l'état ne voit pas l'état réel ; celui-ci éprouve le branchement lui-même.
func _test_killcam_par_le_process() -> void:
	print("\n[Par le vrai chemin : start_playback et _process]")
	var main: Node = await _monter_le_jeu()
	if main == null:
		_check("main.tscn se charge", false)
		return
	var bc: Node = main.bullet_container
	var voile = GadgetVoile.new()
	voile.name = "GadgetJ2_1"
	voile.poseur_id = 1
	bc.add_child(voile)
	var mine = GadgetMine.new()
	mine.name = "GadgetJ1_1"
	mine.slug = "mine_magnesium"
	mine.poseur_id = 0
	bc.add_child(mine)
	mine.allumer()
	var etat: Dictionary = mine.etat_de_rejeu()
	mine.free()

	# ⚠️ Jamais l'identifiant d'autoload : le fichier entier cesserait de compiler
	# en `--script`.
	var rs: Node = root.get_node("ReplaySystem")
	# ⚠️ Les tirs qui traînaient dans l'autoload seraient rejoués ici : on repart net.
	rs.bullet_events = []
	var snap = Rejeu.Snapshot.new()
	snap.p1_pos = main.p1.global_position
	snap.p2_pos = main.p2.global_position
	snap.gadgets = [etat]
	rs.snapshots = [snap, snap, snap]
	rs.impact_frame = -1
	rs.slow_mo_start_frame = -1
	main._end_sequence_active = false
	rs.start_playback()
	await process_frame
	await process_frame
	_check("la copie naît par le chemin du jeu",
		bc.get_node_or_null("Rejeu_GadgetJ1_1") != null)
	_check("et le gadget vivant est masqué", not voile.is_visible_in_tree())

	rs.playing_back = false
	await process_frame
	_check("le rejeu fini, le gadget vivant revient", voile.is_visible_in_tree())

	# Fermeture, TOUJOURS : les fantômes montrés, les visuels cachés, les corps
	# téléportés et le ralenti global ne doivent pas fuir hors de ce test.
	main._abort_killcam()
	Engine.time_scale = 1.0
	await process_frame
	main.queue_free()


## T8 — les dix gadgets savent se décrire et se refaire. Un onzième devra s'y ranger.
func _test_dix_gadgets() -> void:
	print("\n[Les dix gadgets savent se décrire et se refaire]")
	var main: Node = await _monter_le_jeu()
	if main == null:
		_check("main.tscn se charge", false)
		return
	var bc: Node = main.bullet_container
	var socle := ["nom", "slug", "script", "poseur", "classe", "graine", "actif",
		"pos", "rot", "rot_pose", "age", "duree_vie", "energie"]
	var refaits := 0
	var sans_cles: Array[String] = []
	var mal_copies: Array[String] = []
	var mal_rejoues: Array[String] = []
	var i := 0
	for classe in main.classes():
		if classe.gadget == null or not classe.gadget.est_livre():
			continue
		i += 1
		var g = load(classe.gadget.implementation).new()
		# Nommé, comme en jeu : un nom auto-généré serait assaini dans « Rejeu_… ».
		g.name = "GadgetJ1_%d" % (900 + i)
		g.slug = String(classe.gadget.slug)
		g.poseur_id = 0
		g.classe_du_poseur = classe
		bc.add_child(g)
		var etat: Dictionary = g.etat_de_rejeu()
		var complet := true
		for cle in socle:
			if not etat.has(cle):
				complet = false
		if not complet:
			sans_cles.append(String(classe.gadget.slug))
			continue
		var copie = main._copie_de_gadget(etat)
		if copie == null or not copie.is_replay or copie.is_in_group("gadgets") \
				or copie.is_physics_processing() \
				or (copie.collision_layer & MapGeometry.GADGET_BLOQUANT_LAYER) != 0 \
				or (copie.collision_layer & MapGeometry.GADGET_LAYER) \
					!= (g.collision_layer & MapGeometry.GADGET_LAYER):
			mal_copies.append(String(classe.gadget.slug))
			continue
		# Ce que `rejouer()` a réellement REPOSÉ, et non le simple fait qu'il n'ait pas
		# crié. On lui donne un état DÉCALÉ de celui que la copie a en naissant, puis on
		# relit ce qu'elle en a repris.
		var decale := _etat_decale(etat)
		copie.rejouer(decale)
		var oublis := _ce_qui_nest_pas_repose(etat, decale, copie.etat_de_rejeu())
		if not oublis.is_empty():
			mal_rejoues.append("%s → %s" % [classe.gadget.slug, ", ".join(oublis)])
			continue
		refaits += 1
	_check("chacun porte les treize clés du socle", sans_cles.is_empty(),
		", ".join(sans_cles) + " — un `super()` oublié dans `etat_de_rejeu()` ?")
	_check("chacun se refait : rejeu, hors groupe, sans physique, hors couche bloquante",
		mal_copies.is_empty(), ", ".join(mal_copies))
	_check("et chacun REPOSE ce qu'on lui donne : lieu, cap, âge, et son propre rendu",
		mal_rejoues.is_empty(), " ; ".join(mal_rejoues))
	# ⚠️ **Ce que ce compteur voit, et ce qu'il ne voit pas.** Une erreur d'exécution
	# dans un `rejouer()` n'interrompt QUE `rejouer()` : l'appelant reprend la main à la
	# ligne suivante, le compte atteint quand même dix (backtrace vérifiée le
	# 2026-09-12). Ce n'est donc pas un filet contre les erreurs — c'est le compte des
	# gadgets qui ont franchi TOUS les `continue` ci-dessus, et le seul contrôle qui
	# rougirait le jour où un onzième gadget arriverait sans savoir se décrire.
	_check("les DIX gadgets se sont décrits, refaits et reposés", refaits == 10,
		str(refaits))
	main.queue_free()


## Les clés que `GameState._copie_de_gadget()` pose à la CONSTRUCTION, et que
## `rejouer()` n'a donc pas à reposer. Les juger ici les jugerait deux fois, et trois
## d'entre elles sortiraient rouges pour une raison qui n'est pas celle du test :
## `graine` et `actif` sont posés avant l'entrée dans l'arbre, et `rot_pose` est l'axe
## de POSE (le trépied de la torche fantôme), pas le cap rendu.
const POSEES_A_LA_CONSTRUCTION := ["nom", "slug", "script", "poseur", "classe",
	"graine", "actif", "duree_vie", "rot_pose"]


## Un état DÉCALÉ de celui que la copie a en naissant.
##
## ⚠️ **C'est tout le test.** La copie se construit du MÊME script que le vivant et
## monte le même visuel : son état de naissance est déjà celui qu'on relit. Sans
## décalage, un `rejouer()` vidé passe vert — mesuré le 2026-09-12, corps de
## `GadgetVolume.rejouer()` remplacé par `pass` (le rejeu de la suie ET de la
## poussière) : 71 ✓, 0 ✗, pas une `SCRIPT ERROR`.
func _etat_decale(etat: Dictionary) -> Dictionary:
	var d := etat.duplicate()
	d["pos"] = (etat["pos"] as Vector2) + Vector2(37.0, -23.0)
	d["rot"] = float(etat["rot"]) + 0.4
	d["age"] = float(etat["age"]) + 1.25
	for cle in etat:
		if cle in POSEES_A_LA_CONSTRUCTION or cle in ["pos", "rot", "age"]:
			continue
		match typeof(etat[cle]):
			TYPE_FLOAT:
				d[cle] = 0.375
			TYPE_BOOL:
				d[cle] = not bool(etat[cle])
			TYPE_COLOR:
				d[cle] = Color(0.25, 0.5, 0.75, 0.6)
	return d


## Les clés que la copie n'a pas reprises, dites en clair. `avant` ne sert qu'à une
## exception, et elle est écrite en toutes lettres : le socle rend `energie` EN DUR à
## 0.0 pour les sept gadgets sans lampe, si bien que la juger chez eux serait rouge
## pour une raison qui n'a rien à voir avec `rejouer()`. On ne la juge donc que si le
## vivant en a rendu une — ce qui couvre la nappe de braises et la torche fantôme, la
## mine consumée restant jugée par T6-(b).
func _ce_qui_nest_pas_repose(avant: Dictionary, donne: Dictionary,
		apres: Dictionary) -> Array[String]:
	var oublis: Array[String] = []
	for cle in donne:
		if cle in POSEES_A_LA_CONSTRUCTION:
			continue
		if cle == "energie" and float(avant["energie"]) <= 0.0:
			continue
		if not _meme_valeur(apres.get(cle), donne[cle]):
			oublis.append("%s vaut %s au lieu de %s" % [cle, apres.get(cle), donne[cle]])
	return oublis


## Deux valeurs d'état sont-elles la même ? Flottants, points et couleurs à
## l'approximation près : une position qui fait l'aller-retour par la transformation
## globale ne revient pas au bit près.
func _meme_valeur(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false
	match typeof(a):
		TYPE_FLOAT:
			return is_equal_approx(float(a), float(b))
		TYPE_VECTOR2:
			return (a as Vector2).is_equal_approx(b)
		TYPE_COLOR:
			return (a as Color).is_equal_approx(b)
	return a == b
