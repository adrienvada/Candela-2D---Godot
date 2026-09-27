## LA lecture des drapeaux de lancement, pour tout le jeu : ceux passés avant `--` ET
## ceux passés après.
##
## ⚠️ **Le jeu les a lus de deux façons, et en silence** (répétition du test d'Adrien, D3,
## 2026-09-27). `settings_manager.gd` lisait `get_cmdline_user_args() +
## get_cmdline_args()` — `--lacet=0` marchait donc avant comme après `--` — alors que
## `iso_materiaux.gd`, `arena_decor.gd`, `iso_volumes.gd` et d'autres ne lisaient que ce
## qui suit `--`. `godot --path . --lacet=0 --sans-usure` donnait le lacet 0 AVEC les murs
## abîmés, sans un mot ; même piège dans les « Main Run Args » de l'éditeur Godot.
##
## Tout drapeau du jeu passe donc par ici ; `tools/test_drapeaux.gd` échoue si un script
## de la racine relit la ligne de commande lui-même, et vérifie qu'une même liste de
## drapeaux, avant et après `--`, donne le même état. Aucun nom ni aucun sens de drapeau
## n'a changé : seul l'endroit où on peut les écrire s'est élargi.
##
## L'ordre (après `--` d'abord, puis le reste) est celui que `settings_manager.gd` a
## toujours eu ; un script qui lit « le dernier l'emporte » garde donc son comportement.
class_name DrapeauxDeLancement
extends RefCounted


static func arguments() -> PackedStringArray:
	return OS.get_cmdline_user_args() + OS.get_cmdline_args()


static func present(drapeau: String) -> bool:
	return arguments().has(drapeau)
