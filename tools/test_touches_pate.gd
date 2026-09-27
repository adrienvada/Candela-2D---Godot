## Test headless du garde des touches de pâte (répétition du test d'Adrien, D4).
##
## Les touches 1, 2, 3, 4, 0 et F2 changent la pâte du rendu iso. Elles ne doivent le
## faire qu'en build de débogage : en build publié, et donc en ligne, une pâte choisie
## contre l'autre joueur montrerait autrement la lumière faible (équité).
##
## ⚠️ **Le build publié ne se simule pas ici** : ce binaire est un build de débogage, donc
## `OS.is_debug_build()` y vaut toujours vrai. Le test vérifie donc les deux maillons que
## rien d'autre ne verrait disparaître : la fonction qui dit si les touches sont actives
## rend `OS.is_debug_build()`, et `_input` la consulte AVANT de lire une touche.
##
## Lancer : godot --headless --path . --script res://tools/test_touches_pate.gd
extends SceneTree

var _failures := 0

func _init() -> void:
	print("=== Test du garde des touches de pâte (D4) ===")
	_check("touches_de_pate_actives() rend OS.is_debug_build()",
		Presentation3D.touches_de_pate_actives() == OS.is_debug_build())

	var source := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("presentation_3d.gd se lit", source != "")
	var corps_garde := _corps_de(source, "static func touches_de_pate_actives(")
	_check("le garde rend OS.is_debug_build(), et rien d'autre",
		corps_garde.strip_edges() == "return OS.is_debug_build()", corps_garde)
	var corps_input := _corps_de(source, "func _input(")
	var i_garde := corps_input.find("touches_de_pate_actives()")
	var i_touches := corps_input.find("TOUCHES_DIRECTES")
	_check("_input consulte le garde", i_garde >= 0)
	_check("… avant de lire les touches directes et F2",
		i_garde >= 0 and i_touches >= 0 and i_garde < i_touches
		and i_garde < corps_input.find("TOUCHE_PATE"))

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

## Le corps d'une fonction de premier niveau : de sa signature à la prochaine ligne qui
## ne commence ni par une tabulation ni par rien (fin de fonction).
func _corps_de(source: String, signature: String) -> String:
	var debut := source.find(signature)
	if debut < 0:
		return ""
	var lignes := source.substr(debut).split("\n")
	var corps := PackedStringArray()
	for i in range(1, lignes.size()):
		var l: String = lignes[i]
		if l != "" and not l.begins_with("\t"):
			break
		corps.append(l)
	return "\n".join(corps)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")
