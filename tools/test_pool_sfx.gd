## Le pool de sons cesse de laisser les pas couper le récit (V4.16), et les pas
## reculent sous le coup de feu (V4.15).
##
## L'arbitrage est vérifié par sa **fonction pure**, sans nœud ni serveur audio :
## en headless le pilote est muet et `AudioStreamPlayer.playing` ne dit pas la
## vérité. Un arbitrage qu'on ne peut pas tester est un arbitrage dont on
## découvre les défauts à l'oreille, en match, une seule fois — et sans savoir
## ce qu'on vient d'entendre.
##
## Le duck, lui, s'exerce sur une vraie instance : c'est un calcul de volume,
## lisible sur le lecteur rendu, qui ne demande pas qu'un son sorte.
##
## Lancer : godot --headless --path . --script res://tools/test_pool_sfx.gd
extends SceneTree

const AM := preload("res://audio_manager.gd")

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== POOL DE SONS ===")
	_test_bareme()
	_test_arbitrage()
	_test_duck()
	_test_torches()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _test_bareme() -> void:
	print("\n[Le barème classe par ce que le son apprend]")
	_check("le pas est au plus bas", AM.priorite_de("footstep") == 0)
	_check("le coup au but est au plus haut",
		AM.priorite_de("flesh_impact") > AM.priorite_de("shoot"))
	_check("le tir passe devant l'impact de mur",
		AM.priorite_de("shoot") > AM.priorite_de("wall_impact"))
	# Un flux passé directement, ou une clé inconnue, ne doit ni être privilégié
	# ni pouvoir être coupé par un pas.
	_check("un son anonyme se place au-dessus des pas",
		AM.priorite_de(null) > AM.priorite_de("footstep"))
	_check("une clé inconnue vaut le défaut",
		AM.priorite_de("clé_qui_n_existe_pas") == AM.SFX_PRIORITE_DEFAUT)

func _pool(occupees: Array[bool], prios: Array[int], debuts: Array[float]) -> Array:
	return [occupees, PackedInt32Array(prios), PackedFloat64Array(debuts)]

func _test_arbitrage() -> void:
	print("\n[L'arbitrage des voix]")

	# 1. Une voix libre passe avant tout vol, même pour le son le plus humble.
	var libre := _pool([true, false, true], [3, 0, 3], [1.0, 0.0, 2.0])
	_check("une voix libre est préférée au vol",
		AM.choisir_voix(libre[0], libre[1], libre[2], 0) == 1)

	# 2. Tout est pris : on prend la moins prioritaire, pas la plus ancienne.
	#    C'est TOUTE la correction — l'anneau prenait la plus ancienne, point.
	var plein := _pool([true, true, true], [3, 0, 2], [0.0, 5.0, 1.0])
	_check("on vole la moins prioritaire, pas la plus ancienne",
		AM.choisir_voix(plein[0], plein[1], plein[2], 3) == 1,
		"la voix 0 est la plus ancienne mais porte le récit")

	# 3. À égalité de priorité, l'anneau reprend ses droits : la plus ancienne.
	var egal := _pool([true, true, true], [2, 2, 2], [9.0, 1.0, 4.0])
	_check("à priorité égale, la plus ancienne cède",
		AM.choisir_voix(egal[0], egal[1], egal[2], 2) == 1)

	# 4. Le cœur de V4.16 : un pas ne coupe JAMAIS un coup au but.
	var recit := _pool([true, true], [3, 3], [0.0, 1.0])
	_check("un pas renonce plutôt que de couper le récit",
		AM.choisir_voix(recit[0], recit[1], recit[2], 0) == -1)

	# 5. Un son peut voler son égal, mais pas son supérieur.
	var mixte := _pool([true, true], [2, 3], [0.0, 1.0])
	_check("un tir vole un tir", AM.choisir_voix(mixte[0], mixte[1], mixte[2], 2) == 0)
	var sup := _pool([true, true], [3, 3], [0.0, 1.0])
	_check("un tir ne vole pas un coup au but",
		AM.choisir_voix(sup[0], sup[1], sup[2], 2) == -1)

	# 6. Un pool vide ne rend pas 0 par accident : il n'a aucune voix à donner.
	var vide: Array[bool] = []
	_check("un pool sans voix renonce",
		AM.choisir_voix(vide, PackedInt32Array(), PackedFloat64Array(), 9) == -1)

	# 7. Seize pas d'affilée ne doivent pas se déloger les uns les autres au point
	#    de tout occuper : le seizième trouve encore une voix libre, le
	#    dix-septième vole le plus ancien pas. C'est le comportement d'anneau,
	#    conservé DANS une même classe de son.
	var occ: Array[bool] = []
	var pr: Array[int] = []
	var db: Array[float] = []
	for i in 16:
		occ.append(true)
		pr.append(0)
		db.append(float(i))
	_check("entre pas, le plus ancien cède encore",
		AM.choisir_voix(occ, PackedInt32Array(pr), PackedFloat64Array(db), 0) == 0)

func _test_duck() -> void:
	print("\n[Les pas reculent sous le coup de feu]")
	var am: Node = AM.new()
	am.name = "AudioManagerDeTest"
	root.add_child(am)

	var pas: AudioStreamPlayer2D = am.play_sfx_2d("footstep", Vector2.ZERO)
	if pas == null:
		_check("un pas se joue hors tir", false, "le son est introuvable")
		am.queue_free()
		return
	var repos := pas.volume_db
	_check("hors tir, le pas garde son volume", is_zero_approx(repos), str(repos))

	am.play_sfx_2d("shoot", Vector2.ZERO)
	var apres: AudioStreamPlayer2D = am.play_sfx_2d("footstep", Vector2.ZERO)
	_check("juste après un tir, le pas recule de six décibels",
		apres != null and is_equal_approx(apres.volume_db, repos + am.DUCK_TIR_DB),
		"volume = %s" % (str(apres.volume_db) if apres != null else "aucune voix"))

	# Le duck ne touche que les pas : effacer l'impact reviendrait à effacer
	# l'information qu'on vient de payer d'un tir.
	var impact: AudioStreamPlayer2D = am.play_sfx_2d("flesh_impact", Vector2.ZERO)
	_check("le coup au but ne recule pas, lui",
		impact != null and is_zero_approx(impact.volume_db),
		"volume = %s" % (str(impact.volume_db) if impact != null else "aucune voix"))

	# Et il n'écrase pas le volume demandé par l'appelant : il s'y ajoute.
	var doux: AudioStreamPlayer2D = am.play_sfx_2d("footstep", Vector2.ZERO, 1.0, -3.0)
	_check("le recul s'ajoute au volume demandé",
		doux != null and is_equal_approx(doux.volume_db, -3.0 + am.DUCK_TIR_DB),
		"volume = %s" % (str(doux.volume_db) if doux != null else "aucune voix"))

	am.queue_free()


## V5.2 — ce que la torche fait entendre, et ce qu'elle ne doit PAS trahir.
func _test_torches() -> void:
	print("\n[La torche s'entend, mais seulement la sienne]")

	# Le point qui compte, et qui était faux : en ligne, la torche de l'adversaire
	# ouvrait le passe-bas musical local. Le jeu repose sur le fait qu'allumer est
	# un aveu payé de sa position ; le bus musical le donnait gratuitement, sans
	# même regarder. Une fuite d'information par un canal que personne ne surveille.
	_check("en ligne, la torche adverse ne compte pas",
		not AM.torche_comptee(1, 0) and not AM.torche_comptee(0, 1))
	_check("en ligne, la sienne compte",
		AM.torche_comptee(0, 0) and AM.torche_comptee(1, 1))
	# En écran partagé les deux joueurs voient le même écran et s'entendent par la
	# même sortie : il n'y a rien à cacher, et masquer serait arbitraire.
	_check("en écran partagé, les deux comptent",
		AM.torche_comptee(0, -1) and AM.torche_comptee(1, -1))

	# L'écart doit s'ENTENDRE. De 300 à 600 Hz, c'est une octave qu'on ne remarque
	# pas en jouant ; le rapport est ce qui compte, pas la différence.
	var noir := AM.coupure_pour(0)
	var une := AM.coupure_pour(1)
	var deux := AM.coupure_pour(2)
	_check("allumer ouvre franchement le filtre", une / noir >= 2.0,
		"%.0f Hz → %.0f Hz, rapport %.2f" % [noir, une, une / noir])
	_check("la coupure monte avec le nombre de torches", noir < une and une < deux)
	# Un compte négatif ne doit pas produire une coupure sous le plancher : le
	# dictionnaire des torches est nettoyé entre deux matchs, et un état bancal
	# vaut mieux muet que sur-filtré.
	_check("un compte aberrant retombe sur le plancher",
		is_equal_approx(AM.coupure_pour(-3), noir), str(AM.coupure_pour(-3)))
