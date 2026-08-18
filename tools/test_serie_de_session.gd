## La série de victoires consécutives d'une session (V3.9).
##
## Le score de session dit déjà « 3 - 2 », mais pas dans quel ORDRE : trois
## victoires puis deux défaites, ou une alternance stricte, donnent le même
## affichage — alors qu'on ne se sent pas du tout dans la même partie. La série
## est exactement ce que le score ne peut pas dire.
##
## Vérifiée sur ses deux fonctions pures. Une série est de la comptabilité, et la
## comptabilité se relit à froid : la faire dépendre d'un match joué aurait rendu
## intestable la seule chose qui puisse y être fausse — le compte.
##
## Première version : elle chargeait `game_state.gd`, qui référence des autoloads
## par leur nom. En `--script` ces noms ne résolvent pas, le fichier ne compile
## pas, chaque appel échoue — et l'erreur avorte la fonction de test **sans
## incrémenter le compteur**, si bien que la suite annonçait « tous les tests
## passent » sur quatre appels morts. Le contrôle `SCRIPT ERROR` du lanceur est
## le seul garde-fou qui l'attrape ; d'où le fichier séparé, sans dépendance.
##
## Lancer : godot --headless --path . --script res://tools/test_serie_de_session.gd
extends SceneTree

const GS := preload("res://serie_de_session.gd")

const PERSONNE := -1
const J1 := 0
const J2 := 1
const NUL := -1

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== SÉRIE DE SESSION ===")
	_test_comptage()
	_test_mot_ecran_partage()
	_test_mot_en_ligne()
	_test_rupture()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _test_comptage() -> void:
	print("\n[Le compte]")
	_check("une session neuve n'a pas de porteur",
		GS.apres(PERSONNE, 0, J1) == Vector2i(J1, 1))
	_check("gagner deux fois d'affilée fait deux",
		GS.apres(J1, 1, J1) == Vector2i(J1, 2))
	_check("l'adversaire qui gagne repart à un, pour lui",
		GS.apres(J1, 4, J2) == Vector2i(J2, 1))
	# Une série est faite de VICTOIRES consécutives. Laisser une nulle la
	# prolonger reviendrait à dire qu'on n'a pas perdu — ce n'est pas la même
	# fierté, et ce n'est pas ce que le mot promet.
	_check("une égalité fait tomber la série, elle ne la prolonge pas",
		GS.apres(J1, 5, NUL) == Vector2i(PERSONNE, 0))
	_check("une égalité sur une session neuve ne crée rien",
		GS.apres(PERSONNE, 0, NUL) == Vector2i(PERSONNE, 0))

func _test_mot_ecran_partage() -> void:
	print("\n[Ce qui s'affiche — écran partagé]")
	# Une « série de 1 » n'est pas une série, c'est un match gagné. L'annoncer à
	# chaque fin de match viderait le mot de son sens avant qu'il ait servi.
	_check("un premier match ne dit rien",
		GS.mot(PERSONNE, 0, J1, -1) == "",
		GS.mot(PERSONNE, 0, J1, -1))
	_check("deux d'affilée nomment leur joueur",
		GS.mot(J1, 1, J1, -1) == "SÉRIE J1 : 2",
		GS.mot(J1, 1, J1, -1))
	_check("le second joueur est nommé J2",
		GS.mot(J2, 2, J2, -1) == "SÉRIE J2 : 3",
		GS.mot(J2, 2, J2, -1))

func _test_mot_en_ligne() -> void:
	print("\n[Ce qui s'affiche — en ligne]")
	# En ligne il y a un « toi » : la série se dit à la première personne, ou
	# comme une menace.
	_check("ma série se dit sans me nommer",
		GS.mot(J1, 1, J1, J1) == "SÉRIE : 2",
		GS.mot(J1, 1, J1, J1))
	_check("celle d'en face se dit adverse",
		GS.mot(J2, 1, J2, J1) == "SÉRIE ADVERSE : 2",
		GS.mot(J2, 1, J2, J1))
	_check("côté client, les rôles s'inversent",
		GS.mot(J2, 1, J2, J2) == "SÉRIE : 2",
		GS.mot(J2, 1, J2, J2))

func _test_rupture() -> void:
	print("\n[La rupture]")
	# Perdre une série de quatre est l'événement du match. Annoncer « SÉRIE : 1 »
	# au vainqueur passerait à côté de ce qui vient de se produire.
	_check("briser une série se dit avant d'en ouvrir une",
		GS.mot(J1, 4, J2, -1) == "SÉRIE BRISÉE",
		GS.mot(J1, 4, J2, -1))
	_check("une égalité brise aussi",
		GS.mot(J1, 3, NUL, -1) == "SÉRIE BRISÉE",
		GS.mot(J1, 3, NUL, -1))
	# Mais on ne brise pas ce qui n'existait pas : une série de 1 qui tombe n'est
	# qu'un match perdu, et le dire ferait du mot un bruit de fond.
	_check("une série de un ne se brise pas, elle passe",
		GS.mot(J1, 1, J2, -1) == "",
		GS.mot(J1, 1, J2, -1))
	_check("perdre sa propre série se dit pareil des deux côtés",
		GS.mot(J1, 3, J2, J1) == "SÉRIE BRISÉE")
