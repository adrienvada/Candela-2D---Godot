## Ce que l'aventure dit pendant le jeu (`AventureHud`, 2026-10-04) : les consignes de l'initiation, le compteur, le tampon.
##
## Adrien : « il faut que chaque niveau soit hyper gratifiant, que le jeu nous indique sur quelle touche appuyer à chaque étape du
## didacticiel pour nous introduire les mécaniques ».
##
## Ce que le banc tient, et pourquoi chaque point :
##
## - **chaque salle de l'initiation sauf 0.9 a sa consigne**, chaque geste est connu et chaque action existe dans l'`InputMap` —
##   une action mal orthographiée afficherait « SOURIS » pour une touche, sans erreur ;
## - **la touche affichée est celle de l'`InputMap`**, lue comme l'écran des contrôles la lit (`UI.libelle_du_geste`) : une
##   réassignation doit se voir dans la consigne ;
## - **une consigne ne s'allume que sur le geste FAIT** : torche allumée, puis éteinte ; accroupi ; déplacement ;
##   visée. Un faux joueur rend la validation déterministe, et chaque geste est d'abord vérifié NON fait ;
## - **le compteur répond à chaque abattu, et le tampon claque à la salle gagnée**, dans le vrai jeu, d'une vraie balle ;
## - **le record** ne tombe que s'il bat un temps connu : le premier passage n'a rien battu.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_aventure_hud.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")
const Hud := preload("res://aventure_hud.gd")
const SOLO_DE_LA_SUITE := "user://test_aventure_hud.cfg"

var _echecs := 0
var main: Node


## Un corps de joueur réduit à ce que le HUD lit.
class FauxJoueur:
	extends Node2D
	var dead := false
	var flashlight_on := false
	var accroupi := false


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_echecs += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _images(n: int) -> void:
	for _i in n:
		await physics_frame


func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


func _run() -> void:
	print("=== CE QUE L'AVENTURE DIT PENDANT LE JEU ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60)", horloge_fixe, "lancer avec --fixed-fps 60")
	if not horloge_fixe:
		_sortir()
		return
	_effacer(SOLO_DE_LA_SUITE)
	_les_consignes_sont_completes()
	_le_record()
	await _les_gestes()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	main.archiver_les_matchs = false
	await _dans_le_jeu()
	_effacer(SOLO_DE_LA_SUITE)
	_sortir()


func _les_consignes_sont_completes() -> void:
	print("\n[Les consignes de l'initiation]")
	for numero in range(1, 11):
		var c: Array = Hud.consignes_de(0, numero)
		if numero == 9:
			_check("0.9, « La salle pleine », n'a pas de consigne : on s'y passe d'aide", c.is_empty(), str(c))
		else:
			_check("0.%d a sa consigne" % numero, not c.is_empty())
		for ligne: Array in c:
			var geste := String(ligne[0])
			_check("0.%d : le geste « %s » est connu" % [numero, geste], Hud.ACTIONS_DU_GESTE.has(geste))
			for action: String in Hud.ACTIONS_DU_GESTE.get(geste, []):
				_check("0.%d : l'action « %s » existe dans l'InputMap" % [numero, action], InputMap.has_action(action))
			_check("0.%d : la consigne « %s » a un texte" % [numero, geste], String(ligne[1]).strip_edges() != "")
	_check("hors de l'initiation, aucune consigne (chapitre 1, salle 1)", Hud.consignes_de(1, 1).is_empty())
	_check("aucune consigne ne demande d'enjamber : le geste est retiré du jeu", not Hud.ACTIONS_DU_GESTE.has("enjamber")
		and not InputMap.has_action("p1_enjamber"))


func _le_record() -> void:
	print("\n[Le record]")
	var prog = Progression.new(SOLO_DE_LA_SUITE)
	_check("aucun temps connu au départ", prog.meilleur_temps(0, 0) == 0.0)
	_check("le premier passage n'est pas un record (il n'a rien battu)", not prog.noter_temps(0, 0, 20.0))
	_check("… mais son temps est gardé", is_equal_approx(prog.meilleur_temps(0, 0), 20.0), str(prog.meilleur_temps(0, 0)))
	_check("plus lent : pas de record, le meilleur temps ne bouge pas", not prog.noter_temps(0, 0, 25.0)
		and is_equal_approx(prog.meilleur_temps(0, 0), 20.0))
	_check("plus rapide : RECORD", prog.noter_temps(0, 0, 12.5) and is_equal_approx(prog.meilleur_temps(0, 0), 12.5))
	_check("le temps est écrit dans le fichier", is_equal_approx(Progression.new(SOLO_DE_LA_SUITE).meilleur_temps(0, 0), 12.5))
	_effacer(SOLO_DE_LA_SUITE)


## Chaque geste : d'abord NON fait, puis fait. Un faux joueur, et le HUD hors de tout jeu.
func _les_gestes() -> void:
	print("\n[Une consigne ne s'allume que sur le geste fait]")
	var hud: AventureHud = Hud.new()
	root.add_child(hud)
	var j := FauxJoueur.new()
	root.add_child(j)
	# 0.6 : la torche allumée, puis éteinte — l'ordre compte.
	hud.entrer_dans_la_salle(0, 6, 1, j)
	hud.commencer()
	hud.suivre([], 1.0 / 60.0)
	_check("0.6 : rien n'est fait au départ", not _fait(hud, 0) and not _fait(hud, 1))
	j.flashlight_on = true
	hud.suivre([], 1.0 / 60.0)
	_check("0.6 : torche allumée → la première ligne s'allume, pas encore la seconde", _fait(hud, 0) and not _fait(hud, 1))
	j.flashlight_on = false
	hud.suivre([], 1.0 / 60.0)
	_check("0.6 : puis éteinte → la seconde aussi", _fait(hud, 1))

	# 0.6 rejouée : éteinte SANS avoir été allumée ne compte pas.
	hud.entrer_dans_la_salle(0, 6, 1, j)
	hud.commencer()
	hud.suivre([], 1.0 / 60.0)
	_check("0.6 rejouée : une torche jamais allumée n'a pas été « éteinte »", not _fait(hud, 1))

	# 0.4 : s'accroupir. (L'enjambement n'est plus un geste du jeu : Adrien, 2026-10-04.)
	hud.entrer_dans_la_salle(0, 4, 2, j)
	hud.commencer()
	hud.suivre([], 1.0 / 60.0)
	_check("0.4 : rien au départ", not _fait(hud, 0))
	j.accroupi = true
	hud.suivre([], 1.0 / 60.0)
	_check("0.4 : l'accroupi allume « S'accroupir »", _fait(hud, 0))
	j.accroupi = false

	# 0.1 : se déplacer, viser — mesurés depuis le retrait du carton.
	j.global_position = Vector2(100, 100)
	j.rotation = 0.0
	hud.entrer_dans_la_salle(0, 1, 1, j)
	hud.commencer()
	j.global_position = Vector2(120, 100)
	j.rotation = 0.3
	hud.suivre([], 1.0 / 60.0)
	_check("0.1 : 20 px et 0,3 rad ne suffisent pas", not _fait(hud, 0) and not _fait(hud, 1))
	j.global_position = Vector2(160, 100)
	j.rotation = 1.0
	hud.suivre([], 1.0 / 60.0)
	_check("0.1 : 60 px allument « Se déplacer », 1 rad allume « Viser »", _fait(hud, 0) and _fait(hud, 1))
	_check("0.1 : « Tirer » attend un tir", not _fait(hud, 2))
	Input.action_press("p1_shoot")
	await physics_frame
	hud.suivre([], 1.0 / 60.0)
	Input.action_release("p1_shoot")
	_check("0.1 : l'appui sur la détente allume « Tirer »", _fait(hud, 2))

	# Le compteur suit les abattus.
	var a := FauxJoueur.new()
	var b := FauxJoueur.new()
	hud.entrer_dans_la_salle(1, 1, 2, j)
	_check("le compteur part de zéro", String(hud.etat()["compteur"]) == "SILHOUETTES  0 / 2", String(hud.etat()["compteur"]))
	_check("une salle hors de l'initiation n'a pas de consigne", (hud.etat()["consignes"] as Array).is_empty())
	a.dead = true
	hud.suivre([a, b], 1.0 / 60.0)
	_check("un abattu : 1 / 2", String(hud.etat()["compteur"]) == "SILHOUETTES  1 / 2", String(hud.etat()["compteur"]))
	a.free()
	b.free()
	j.queue_free()
	hud.queue_free()
	await process_frame


func _fait(hud: AventureHud, i: int) -> bool:
	var lignes: Array = hud.etat()["consignes"]
	return i < lignes.size() and bool(lignes[i]["fait"])


## La salle 0.1 dans le vrai jeu : ses consignes portent les VRAIES touches, le compteur suit l'abattu, le tampon claque.
func _dans_le_jeu() -> void:
	print("\n[Dans le jeu : la salle 0.1]")
	Format.oublier_le_cache()
	var chapitre: Dictionary = Format.charger_chapitre("res://assets/solo/chapitre_00", 0)
	var prog = Progression.new(SOLO_DE_LA_SUITE)
	_check("l'aventure démarre", main.demarrer_l_aventure(chapitre, 0, "pistolet", prog))
	var hud: AventureHud = main.get_node_or_null("HudAventure")
	_check("le HUD de l'aventure est posé (`HudAventure`)", hud != null)
	if hud == null:
		return
	_check("sous le carton, il ne se montre pas", not bool(hud.etat()["visible"]))
	await _images(300)
	var e: Dictionary = hud.etat()
	_check("le carton retiré, il se montre", bool(e["visible"]))
	var lignes: Array = e["consignes"]
	_check("0.1 : trois consignes (se déplacer, viser, tirer)", lignes.size() == 3, str(lignes.size()))
	var ui = main.ui
	for l: Dictionary in lignes:
		var attendu := String(ui.libelle_du_geste(Hud.ACTIONS_DU_GESTE[l["geste"]]))
		_check("« %s » montre la touche de l'InputMap : %s" % [l["texte"], attendu], String(l["touches"]) == attendu and attendu != "",
			String(l["touches"]))
	_check("le compteur : 0 / 1", String(e["compteur"]) == "SILHOUETTES  0 / 1", String(e["compteur"]))

	var partie = main.aventure
	var cible = partie.pnj[0]
	cible.hp = 1.0
	var d: Vector2 = cible.global_position - main.p1.global_position
	main.spawn_bullet(main.p1, cible.global_position - d.normalized() * 60.0, d.angle(), main.p1.current_weapon)
	await _images(10)
	e = hud.etat()
	_check("l'abattu se compte : 1 / 1", String(e["compteur"]) == "SILHOUETTES  1 / 1", String(e["compteur"]))
	_check("le tampon claque : SALLE RÉUSSIE", bool(e["tampon"]) and String(e["tampon_titre"]) == "SALLE RÉUSSIE", str(e))
	_check("… avec le temps et l'essai", String(e["tampon_detail"]).contains(" s") and String(e["tampon_detail"]).contains("premier essai"),
		String(e["tampon_detail"]))
	_check("… sans RECORD au premier passage", not String(e["tampon_detail"]).contains("RECORD"))
	_check("le temps de la salle est gardé", prog.meilleur_temps(0, 0) > 0.0, str(prog.meilleur_temps(0, 0)))
	await _images(200)
	_check("la salle suivante (0.2) : une consigne, la torche", (hud.etat()["consignes"] as Array).size() == 1
		and String((hud.etat()["consignes"] as Array)[0]["geste"]) == "torche_allumer")
	_check("… et le tampon est parti", not bool(hud.etat()["tampon"]))
	main._on_main_menu_requested()
	await _images(5)
	_check("au retour au menu, le HUD part avec la partie", main.get_node_or_null("HudAventure") == null)


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
