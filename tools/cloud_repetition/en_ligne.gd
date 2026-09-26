extends "res://tools/test_online_match.gd"
## Répétition : le banc `test_online_match` tel quel, EN FENÊTRE (Xvfb), plus une photo toutes les
## ~3 s de jeu dans `--photos=<dossier absolu>`. Rien du banc n'est changé : `super()` joue son rôle
## (hôte ou invité), et la boucle de photos tourne à côté sans l'attendre.

const CommunRendu := preload("res://tools/rendu_commun.gd")


func _ready() -> void:
	var dossier := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--photos="):
			dossier = a.substr(9)
	if dossier != "" and CommunRendu.refus_headless() == "":
		DirAccess.make_dir_recursive_absolute(dossier)
		_photographier(dossier)
	super()


func _photographier(dossier: String) -> void:
	var n := 0
	while true:
		for i in 180:
			await get_tree().process_frame
		var img: Image = await CommunRendu.capturer(get_tree(), 20000)
		if img == null:
			continue
		n += 1
		img.convert(Image.FORMAT_RGB8)
		var etat := "menu"
		if is_instance_valid(_main):
			etat = "manche" if _main.round_active else ("killcam" if ReplaySystem.playing_back else "hors_manche")
		img.save_jpg(dossier.path_join("%02d_%s.jpg" % [n, etat]), 0.85)
		print("[en_ligne] photo %02d (%s)" % [n, etat])
