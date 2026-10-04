## Les tirs des PNJ s'entendent de partout dans la salle (Adrien, 2026-10-04 : « je n'entends pas les tirs de PNJ. Augmente la portée des
## sons de tirs de PNJ au max : ça doit s'entendre de partout dans les salles »).
##
## Relevé avant la correction, salle 0.9 (« La salle pleine ») : la portée n'y était pour rien — 1818 px pour une diagonale de 1188 —,
## c'était l'OCCLUSION. Presque chaque tir de PNJ partait sur `SFX_Occlus` (direct retiré, passe-bas, jusqu'à −5 dB), même celui d'un PNJ à
## 175 px. Ce banc tient donc trois choses :
##
## - **chaque tir de PNJ part en direct** (`SFX`, aucune part occultée), à son niveau, avec une portée d'au moins trois fois la diagonale ;
## - **le témoin** : le MÊME tir, au même endroit, joué comme un tir ordinaire, est encore étouffé par au moins un mur — sans lui, une salle
##   sans recoin ferait passer ce banc sans rien prouver ;
## - **le duel n'est pas touché** : le tir du joueur garde la portée ordinaire.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_aventure_tirs_pnj.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")
const SOLO_DE_LA_SUITE := "user://test_aventure_tirs_pnj.cfg"

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
	for _i in n:
		await physics_frame


func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


func _run() -> void:
	print("=== LES TIRS DES PNJ S'ENTENDENT DE PARTOUT ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60)", horloge_fixe, "lancer avec --fixed-fps 60")
	if not horloge_fixe:
		_sortir()
		return
	var audio: Node = root.get_node("AudioManager")
	_effacer(SOLO_DE_LA_SUITE)
	Format.oublier_le_cache()
	var chapitre: Dictionary = Format.charger_chapitre("res://assets/solo/chapitre_00", 0)
	var prog = Progression.new(SOLO_DE_LA_SUITE)
	for i in 8:
		prog.reussir_niveau(0, i)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	main.archiver_les_matchs = false
	_check("la salle 0.9 démarre", main.demarrer_l_aventure(chapitre, 8, "pistolet", prog))
	await _images(200)
	var pnj: Array = main.aventure.pnj
	_check("elle a plusieurs PNJ", pnj.size() >= 3, str(pnj.size()))
	var diagonale: float = audio.portee_carte()
	var etouffes_sans := 0
	for p in pnj:
		p.current_ammo = 6
		p.shoot_cooldown = 0.0
		p.shoot()
		await physics_frame
		var tir: Dictionary = audio._dernier_tir_2d
		_check("%s (à %.0f px) : le tir part en direct, rien ne l'étouffe" % [p.name, p.global_position.distance_to(main.p1.global_position)],
			String(tir.get("bus", "")) == "SFX" and float(tir.get("part_occultee", 1.0)) == 0.0, str(tir))
		_check("%s : portée d'au moins trois diagonales de la salle (%.0f px pour %.0f)" % [p.name, float(tir.get("portee", 0.0)), diagonale],
			float(tir.get("portee", 0.0)) >= 3.0 * diagonale)
		# Le témoin : le même tir, au même endroit, joué comme un tir ordinaire.
		audio.play_weapon_shot("pistolet", p.global_position, 1)
		if float(audio._dernier_tir_2d.get("part_occultee", 0.0)) > 0.0:
			etouffes_sans += 1
		await physics_frame
	_check("le témoin : sans la règle des PNJ, au moins un de ces tirs serait étouffé par un mur (%d sur %d)" % [etouffes_sans, pnj.size()],
		etouffes_sans >= 1)

	main.p1.current_ammo = 6
	main.p1.shoot_cooldown = 0.0
	main.p1.shoot()
	await physics_frame
	var du_joueur: Dictionary = audio._dernier_tir_2d
	_check("le tir du joueur garde la portée ordinaire (%.0f px)" % float(du_joueur.get("portee", 0.0)),
		float(du_joueur.get("portee", 0.0)) < 3.0 * diagonale and float(du_joueur.get("portee", 0.0)) > 0.0)
	main._on_main_menu_requested()
	await _images(5)
	_effacer(SOLO_DE_LA_SUITE)
	_sortir()


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
