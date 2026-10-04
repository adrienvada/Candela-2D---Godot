## Rien ne reste d'une salle à l'autre, et le bandeau rouge est au JcJ (Adrien, 2026-10-04).
##
## Relevé par Adrien en jouant : « le tracé de la balle en killcam ainsi que la mention "Pistolet" quand on tue quelqu'un restent
## imprimés entre chaque salle […] il ne faut pas jouer le carton rouge "pistolet" quand on est contre des PNJ. Ces mécaniques sont
## propres au JcJ ».
##
## Deux défauts, et c'est le second qui laissait les traces :
##
## - **la règle** : `Player.die()` posait « FATAL — PISTOLET » et la marge « à N px du centre » à chaque mort, PNJ compris. Ils
##   signent un duel ; contre la machine ils n'ont rien à dire. `Player.kill_entre_joueurs()` décide désormais ;
## - **la durée de vie** : le fondu qui libère ces étiquettes était lié au CORPS mort (`create_tween()` du joueur), alors que les
##   étiquettes vivent chez son parent. Un PNJ retiré au passage à la salle suivante emportait son tween — et laissait ses
##   étiquettes, pleinement visibles, dans l'arène pour toujours. Aucune erreur, aucune suite rouge.
##
## Le dernier essai vérifie le second défaut SANS la règle : un bandeau de duel posé par un corps libéré aussitôt doit s'éteindre
## quand même. Sans lui, la règle seule masquerait le défaut jusqu'au prochain corps libéré tôt.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_aventure_restes.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")
const SOLO_DE_LA_SUITE := "user://test_aventure_restes.cfg"

var _echecs := 0
var main: Node


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_echecs += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _images(n: int) -> void:
	for i in n:
		await physics_frame


## Les étiquettes de mort encore dans l'arbre : le bandeau, sa marge, le calque du flash.
func _restes() -> Array[String]:
	var r: Array[String] = []
	for n in root.find_children("*", "", true, false):
		var s := String(n.name)
		if s.begins_with("BandeauFatal") or s.begins_with("MargeFatal") or s.begins_with("CalqueFlashMort"):
			r.append(s)
	return r


func _bandeaux() -> Array[String]:
	return _restes().filter(func(s: String) -> bool: return not s.begins_with("CalqueFlashMort"))


func _run() -> void:
	print("=== RIEN NE RESTE D'UNE SALLE À L'AUTRE ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe,
		"lancer avec --fixed-fps 60 : sans lui les délais de la salle ne mesureraient rien")
	if not horloge_fixe:
		_sortir()
		return
	_effacer(SOLO_DE_LA_SUITE)
	Format.oublier_le_cache()
	var chapitre: Dictionary = Format.charger_chapitre("res://assets/solo/chapitre_00", 0)
	_check("le chapitre 0 se charge", not chapitre.is_empty())
	if chapitre.is_empty():
		_sortir()
		return
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	main.archiver_les_matchs = false

	await _un_pnj_abattu_ne_laisse_rien(chapitre)
	await _la_regle()
	await _un_corps_libere_ne_laisse_pas_son_bandeau()
	_sortir()


func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


## Le joueur abat le PNJ de la salle 0.1 d'une vraie balle, la salle passe à la suivante : aucune étiquette de mort ne doit
## paraître, et rien ne doit rester.
func _un_pnj_abattu_ne_laisse_rien(chapitre: Dictionary) -> void:
	print("\n[Un PNJ abattu, puis la salle suivante]")
	var prog = Progression.new(SOLO_DE_LA_SUITE)
	_check("l'aventure démarre", main.demarrer_l_aventure(chapitre, 0, "pistolet", prog))
	# Le carton de la salle, puis le jeu.
	await _images(300)
	var partie = main.aventure
	_check("la salle 0.1 se joue, avec un PNJ", partie != null and partie.index == 0 and not partie.pnj.is_empty())
	if partie == null or partie.pnj.is_empty():
		return
	var cible = partie.pnj[0]
	cible.hp = 1.0
	var d: Vector2 = cible.global_position - main.p1.global_position
	main.spawn_bullet(main.p1, cible.global_position - d.normalized() * 60.0, d.angle(), main.p1.current_weapon)
	await _images(10)
	_check("le PNJ est abattu par la balle du joueur", bool(cible.dead))
	_check("aucun bandeau « FATAL — PISTOLET » ni marge sur un PNJ abattu (le bandeau est au JcJ)", _bandeaux().is_empty(),
		str(_bandeaux()))
	await _images(400)
	_check("la salle suivante est posée", main.aventure != null and main.aventure.index == 1,
		str(main.aventure.index) if main.aventure != null else "aucune partie")
	_check("rien de la salle d'avant ne reste dans l'arène (bandeau, marge, calque du flash)", _restes().is_empty(), str(_restes()))

	# Le joueur abattu par un PNJ : pas de bandeau non plus, et rien ne reste après la reprise.
	if main.aventure != null and not main.aventure.pnj.is_empty():
		main.p1.die(main.aventure.pnj[0])
		await _images(10)
		_check("le joueur abattu par un PNJ ne reçoit pas de bandeau", _bandeaux().is_empty(), str(_bandeaux()))
		await _images(400)
		_check("… et rien ne reste après la reprise de la salle", _restes().is_empty(), str(_restes()))
	main._on_main_menu_requested()
	await _images(5)
	_effacer(SOLO_DE_LA_SUITE)


## `kill_entre_joueurs()` : vrai seulement entre deux joueurs, hors entraînement.
func _la_regle() -> void:
	print("\n[La règle : le bandeau est au JcJ]")
	var p1 = main.p1
	var p2 = main.p2
	main.training_mode = false
	_check("en duel, un joueur abattu par l'autre : JcJ", p2.kill_entre_joueurs(p1))
	_check("… sans tueur connu (chrono, zone) : JcJ aussi — le mot FATAL seul", p2.kill_entre_joueurs(null))
	main.training_mode = true
	_check("à l'entraînement (bot, aventure) : pas JcJ", not p2.kill_entre_joueurs(p1))
	main.training_mode = false
	p2.est_pnj = true
	_check("une victime PNJ : pas JcJ", not p2.kill_entre_joueurs(p1))
	p2.est_pnj = false
	p1.est_pnj = true
	_check("un tueur PNJ : pas JcJ", not p2.kill_entre_joueurs(p1))
	p1.est_pnj = false


## Le défaut de durée de vie, isolé de la règle : en duel, un corps posé puis libéré AVANT la fin du fondu de son bandeau. Le
## bandeau doit s'éteindre quand même, puisque son tween lui appartient.
func _un_corps_libere_ne_laisse_pas_son_bandeau() -> void:
	print("\n[Un corps libéré avant la fin du fondu]")
	main.training_mode = false
	var cobaye: Node2D = (load("res://player.tscn") as PackedScene).instantiate()
	cobaye.name = "Cobaye"
	cobaye.player_id = 1
	main.p2.get_parent().add_child(cobaye)
	cobaye.global_position = main.p1.global_position + Vector2(120, 0)
	await _images(2)
	cobaye.die(main.p1)
	await _images(2)
	_check("en duel, le bandeau se pose", not _bandeaux().is_empty(), "aucun bandeau : l'essai ne mesurerait rien")
	cobaye.queue_free()
	# Le fondu dure 1,5 s : on en attend 3.
	await _images(180)
	_check("le corps libéré n'a pas laissé son bandeau dans l'arène", _bandeaux().is_empty(), str(_bandeaux()))
	await _images(60)
	_check("… ni le calque de son flash", _restes().is_empty(), str(_restes()))


func _effacer(chemin: String) -> void:
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))


func _sortir() -> void:
	if is_instance_valid(main):
		main.queue_free()
	if _echecs == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)
