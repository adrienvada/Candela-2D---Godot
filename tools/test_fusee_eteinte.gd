extends SceneTree

## Une fusée qui s'éteint cesse-t-elle d'éblouir ?
##
## Adrien, le 2026-09-11 : « je suis ébloui par une fusée éclairante même quand
## elle est éteinte, quand elle clignote sur la fin notamment ». La source
## d'éblouissement de la fusée ne regardait que « posée et pas éteinte » et lui
## donnait son rayon plein : une braise, un creux d'agonie ou un résidu
## aveuglaient comme le plein feu.
##
## Deux contrôles, sans ouvrir de fenêtre :
## 1. Le MODÈLE : au creux de l'agonie et au résidu, l'énergie vaut une fraction
##    faible du plein feu — c'est cette fraction que `Fusee.energie_relative()`
##    rend et que `game_state` multiplie au plafond de la source.
## 2. Le TEXTE : `game_state.gd` lit bien `energie_relative` pour la source
##    fusée et `gain` dans `_plafond_de_source` — c'est par le texte que le
##    défaut reviendrait, une source réécrite sans son gain.

const Modele := preload("res://fusee_modele.gd")

var _echecs := 0
var _controles := 0


func _init() -> void:
	var fenetres: Array = Modele.fenetres_agonie(7)
	var plein := Modele.ENERGIE_PLEIN_FEU
	var plein_feu: float = Modele.energie_a(0.5, fenetres)
	_check("au plein feu, l'énergie est celle du plein feu (%.2f)" % plein_feu,
		plein_feu >= Modele.ENERGIE_BRAISE)
	_check("le creux d'agonie brûle sous 10 %% du plein feu (%.2f / %.2f)"
		% [Modele.ENERGIE_CREUX, plein], Modele.ENERGIE_CREUX / plein < 0.10)
	_check("le résidu brûle sous 10 %% du plein feu (%.2f / %.2f)"
		% [Modele.ENERGIE_RESIDU, plein], Modele.ENERGIE_RESIDU / plein < 0.10)

	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	var fusee := FileAccess.get_file_as_string("res://fusee.gd")
	_check("fusee.gd expose energie_relative()", fusee.contains("func energie_relative()"))
	_check("energie_relative() lit la lumière RÉELLE (_lumiere.energy)",
		fusee.contains("_lumiere.energy / FuseeModele.ENERGIE_PLEIN_FEU"))
	_check("la source fusée de game_state porte un gain lu sur energie_relative",
		gs.contains("energie_relative") and gs.contains('"gain": gain'))
	_check("_plafond_de_source multiplie par le gain de la source",
		gs.contains('src.get("gain", 1.0)'))

	print("\n%d contrôles, %d échec(s)" % [_controles, _echecs])
	if _echecs == 0:
		print("✓ Tous les tests passent")
	else:
		printerr("✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _check(nom: String, ok: bool) -> void:
	_controles += 1
	if ok:
		print("  ✓ " + nom)
	else:
		_echecs += 1
		printerr("  ✗ " + nom)
