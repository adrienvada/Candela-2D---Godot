extends SceneTree
## Répétition : quels drapeaux le jeu entend-il, selon qu'ils sont passés avant ou après `--` ?
## godot --headless --path . --script res://tools/cloud_repetition/drapeaux.gd --sans-usure --lacet=0
## godot --headless --path . --script res://tools/cloud_repetition/drapeaux.gd -- --sans-usure --lacet=0

func _init() -> void:
	var tous := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	print("args moteur : ", OS.get_cmdline_args())
	print("args utilisateur : ", OS.get_cmdline_user_args())
	print("usure (IsoMateriaux.usure_essai_active) : ", IsoMateriaux.usure_essai_active())
	print("beauté (IsoMateriaux.beaute_active) : ", IsoMateriaux.beaute_active())
	print("pochoirs (ArenaDecor.pochoirs_actifs) : ", ArenaDecor.pochoirs_actifs())
	print("lacet (settings_manager.gd lit les deux listes) : ", load("res://settings_manager.gd").lacet_applique(tous))
	quit(0)
