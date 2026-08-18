## Test headless du nettoyage de pseudo — Phase 5, étape 6.
##
## Le nettoyage existe en **deux exemplaires**, ici et dans `sanitizeNickname`
## côté serveur, et c'est voulu : le client nettoie pour que le joueur voie ce
## qu'il obtiendra, le serveur nettoie parce qu'il ne fait confiance à personne.
## Mais deux nettoyages qui divergent donnent un pseudo différent de celui qu'on
## a montré — le joueur se croit appelé autrement qu'il ne l'est, et ne s'en
## aperçoit que sur l'écran de fin de son adversaire.
##
## Ces assertions sont donc le **miroir exact** de `recovery_code_test.ts`. Toute
## divergence future se verra ici avant de se voir en jeu.
##
## Lancer : godot --headless --path . --script res://tools/test_pseudo.gd
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test du nettoyage de pseudo ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_miroir_du_serveur()
	_test_bornes()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _propre(raw: String) -> String:
	return RecoveryCode.sanitize_nickname(raw)

## Les six cas de `recovery_code_test.ts`, rejoués à l'identique.
func _test_miroir_du_serveur() -> void:
	print("\n[Miroir du nettoyage serveur]")
	_check("les bords sont rognés", _propre("  Vada  ") == "Vada", _propre("  Vada  "))
	# Un caractère de contrôle traverserait jusqu'à l'écran de l'adversaire, qui
	# n'a rien demandé.
	#
	# Le cas serveur utilise U+0000 ; **GDScript ne sait pas l'écrire** — son
	# analyseur remplace `\u0000` dans un littéral par U+FFFD, le caractère de
	# remplacement, qui n'est pas un caractère de contrôle. On exerce donc U+0001,
	# qui passe par exactement la même branche. À savoir avant de recopier le test
	# serveur mot pour mot et de conclure à un défaut.
	_check("un caractère de contrôle devient une espace",
		_propre("Va\u0001da") == "Va da", _propre("Va\u0001da"))
	_check("les espaces multiples se replient",
		_propre("Va\ndouble  espace") == "Va double espace", _propre("Va\ndouble  espace"))
	_check("la longueur est plafonnée",
		_propre("a".repeat(80)).length() == RecoveryCode.NICKNAME_MAX,
		str(_propre("a".repeat(80)).length()))
	_check("une chaîne vide reste vide", _propre("") == "")
	_check("des espaces seuls ne font pas un pseudo", _propre("   ") == "")

func _test_bornes() -> void:
	print("\n[Bornes]")
	# Le plafond ne doit pas mordre sur un pseudo qui tient tout juste.
	var pile := "a".repeat(RecoveryCode.NICKNAME_MAX)
	_check("un pseudo exactement à la limite passe entier", _propre(pile) == pile)
	_check("un caractère de plus est coupé net",
		_propre(pile + "b").length() == RecoveryCode.NICKNAME_MAX)
	# Les accents comptent pour un caractère et non pour leurs octets : tronquer en
	# octets couperait un caractère en deux et rendrait du charabia.
	_check("les accents comptent pour un caractère",
		_propre("éééé") == "éééé", _propre("éééé"))
	_check("la tabulation est un caractère de contrôle",
		_propre("Va\tda") == "Va da", _propre("Va\tda"))
