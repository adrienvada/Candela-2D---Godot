extends SceneTree

## Chaque curseur d'`EffectPolicy` a-t-il un lecteur en production ?
##
## L'audit DA5.1 (2026-09-09) a trouvé quinze identifiants sur trente-quatre
## sans aucun site d'appel : le curseur bougeait, l'écran ne changeait pas, et
## rien ne le disait. Adrien, le 2026-09-11 : « il faut que les quinze curseurs
## fonctionnent ». Cette suite tient la règle pour l'avenir : **tout
## identifiant de la table doit être lu, en littéral, par un fichier du jeu**.
##
## Contrôle sur le TEXTE, comme `test_torches` et `test_charte` : c'est par le
## texte que le défaut reviendrait — un effet réécrit sans son curseur, ou un
## curseur ajouté à la table sans site d'appel. Les lecteurs reconnus :
## `EffectPolicy.curseur("id")`, `current_effect("id")`,
## `effective_effect("id", …)`, `_intensite_vitrine("id")`. `tools/`, `effect_policy.gd` et
## `settings_manager.gd` sont exclus : ils parcourent la table génériquement
## et ne prouvent rien sur l'application réelle.

const Politique := preload("res://effect_policy.gd")

const EXCLUS := ["effect_policy.gd", "settings_manager.gd"]

var _echecs := 0
var _controles := 0


func _init() -> void:
	var textes := _textes_du_jeu()
	_check("des fichiers de jeu ont été lus (%d)" % textes.size(), textes.size() >= 20)
	var tout := "\n".join(textes.values())
	for id in Politique.ids():
		var motifs := ['curseur("%s")' % id, 'current_effect("%s")' % id,
			'effective_effect("%s"' % id, '_intensite_vitrine("%s")' % id]
		var lu := false
		for m in motifs:
			if tout.contains(m):
				lu = true
				break
		_check("%-26s est lu par le jeu" % id, lu)

	# Le chemin commun rend 1,0 sans réglages : un effet ne cesse pas de se
	# dessiner parce qu'un autoload manque (suite, banc, outil).
	_check("sans GameSettings, curseur() rend DEFAULT",
		is_equal_approx(Politique.curseur("secousse_camera"), Politique.DEFAULT))

	print("\n%d contrôles, %d échec(s)" % [_controles, _echecs])
	if _echecs == 0:
		print("✓ Tous les tests passent")
	else:
		printerr("✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Le texte de chaque `.gd` et `.gdshader` de la racine du projet.
func _textes_du_jeu() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://")
	if dir == null:
		return out
	for nom in dir.get_files():
		if not (nom.ends_with(".gd") or nom.ends_with(".gdshader")):
			continue
		if EXCLUS.has(nom):
			continue
		out[nom] = FileAccess.get_file_as_string("res://" + nom)
	return out


func _check(nom: String, ok: bool) -> void:
	_controles += 1
	if ok:
		print("  ✓ " + nom)
	else:
		_echecs += 1
		printerr("  ✗ " + nom)
