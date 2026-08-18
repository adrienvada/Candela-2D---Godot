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
## Lancer : godot --headless --path . --script res://tools/test_rejeu.gd
extends SceneTree

const Rejeu := preload("res://replay_system.gd")

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
