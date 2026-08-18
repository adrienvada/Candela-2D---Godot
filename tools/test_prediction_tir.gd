## La déduplication des tirs prédits — le doublon que voyait un joueur lent.
##
## Relevé par l'étude de robustesse du 2026-08-16 et resté ouvert : la file ne
## retenait que des horodatages, défilait en aveugle, et son TTL était fixé à une
## seconde. **Au-delà d'une seconde de latence, la prédiction expire avant que la
## balle officielle n'arrive, et le joueur voit sa balle en double.** C'est le cas
## d'un joueur sur réseau mobile saturé — exactement celui pour qui la prédiction
## a été écrite.
##
## Ce que la suite protège avant tout : **l'appariement par angle n'a pas le droit
## de faire apparaître un doublon là où l'ancienne version n'en faisait pas.** Une
## amélioration du choix qui dégraderait le nombre serait un mauvais échange, et
## c'est le genre de régression qu'on ne verrait qu'en jeu, chez quelqu'un d'autre.
##
## Lancer : godot --headless --path . --script res://tools/test_prediction_tir.gd
extends SceneTree

const P := preload("res://prediction_tir.gd")

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	print("=== PRÉDICTION DES TIRS ===")
	_test_ttl()
	_test_purge()
	_test_appariement()
	_test_jamais_de_doublon_en_plus()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _tir(t: int, angle: float) -> Dictionary:
	return {"t": t, "angle": angle}

func _test_ttl() -> void:
	print("\n[La durée de vie suit le lien]")
	# Le défaut d'origine, en une ligne : sur un lien à 1,2 s d'aller-retour, une
	# durée de vie d'une seconde périme la prédiction AVANT le retour de la balle.
	_check("un lien lent garde ses prédictions plus longtemps",
		P.ttl_ms(1200.0, true) > 1200,
		"%d ms pour un RTT de 1200" % P.ttl_ms(1200.0, true))
	_check("un lien rapide ne garde pas de fantômes une seconde",
		P.ttl_ms(40.0, true) < P.TTL_DEFAUT_MS,
		"%d ms pour un RTT de 40" % P.ttl_ms(40.0, true))
	# Tant que rien n'est mesuré, on ne fait pas pire qu'avant.
	_check("sans mesure, on garde l'ancienne constante",
		P.ttl_ms(0.0, false) == P.TTL_DEFAUT_MS)
	_check("un RTT nul est traité comme non mesuré",
		P.ttl_ms(0.0, true) == P.TTL_DEFAUT_MS)
	# Bornes : un lien catastrophique ne doit pas retenir des fantômes une minute.
	_check("la durée de vie reste bornée",
		P.ttl_ms(999999.0, true) == P.TTL_PLAFOND_MS
		and P.ttl_ms(1.0, true) == P.TTL_PLANCHER_MS)

func _test_purge() -> void:
	print("\n[Les prédictions refusées s'effacent]")
	var f: Array = [_tir(0, 0.0), _tir(100, 1.0), _tir(900, 2.0)]
	P.purger(f, 1000, 500)
	_check("les trop vieilles partent, les autres restent", f.size() == 1,
		"%d restante(s)" % f.size())
	_check("et c'est bien la plus récente qui reste",
		f.size() == 1 and int(f[0]["t"]) == 900)
	# Sans purge, une prédiction jamais confirmée — tir refusé par l'hôte,
	# paquet d'entrée perdu — décalerait la file pour toujours.
	var vide: Array = []
	P.purger(vide, 5000, 100)
	_check("purger une file vide ne casse rien", vide.is_empty())

func _test_appariement() -> void:
	print("\n[L'angle départage, l'ancienneté tranche]")
	var f: Array = [_tir(0, 0.0), _tir(10, 1.5), _tir(20, 3.0)]
	_check("la balle officielle retrouve SON tir", P.choisir(f, 1.5) == 1)
	_check("même avec un arrondi de sérialisation", P.choisir(f, 1.5 + 0.02) == 1)
	# Deux tirs rapprochés dans le temps mais séparés dans l'espace : c'est le cas
	# que l'ordre seul confond, et celui où l'angle sert vraiment.
	_check("l'ordre d'arrivée ne décide plus seul", P.choisir(f, 3.0) == 2)
	# Le passage par ±π ne doit pas casser la comparaison.
	var bord: Array = [_tir(0, PI - 0.01)]
	_check("l'angle se compare en passant par ±π",
		P.choisir(bord, -PI + 0.01) == 0)
	_check("une file vide ne confirme rien", P.choisir([], 0.0) == -1)

func _test_jamais_de_doublon_en_plus() -> void:
	print("\n[L'appariement n'ajoute jamais de doublon]")
	# LE point de la suite. Si aucun angle ne correspond — hôte qui recalcule,
	# arme à dispersion, angle altéré en route — l'ancienne version consommait
	# quand même la plus ancienne et ne dessinait pas de seconde balle. On garde
	# ce repli : améliorer le CHOIX ne doit pas dégrader le NOMBRE.
	var f: Array = [_tir(0, 0.0), _tir(10, 0.1)]
	_check("aucun angle ne correspond : on confirme quand même la plus ancienne",
		P.choisir(f, 2.9) == 0)
	# Et la propriété qui compte vraiment : tant qu'il reste une prédiction, une
	# balle officielle en consomme exactement une. Jamais zéro, jamais deux.
	var file: Array = [_tir(0, 0.0), _tir(1, 1.0), _tir(2, 2.0)]
	var consommees := 0
	for angle in [2.0, 0.0, 1.0, 0.5]:
		var i: int = P.choisir(file, angle)
		if i >= 0:
			file.remove_at(i)
			consommees += 1
	_check("trois prédictions absorbent exactement trois balles",
		consommees == 3 and file.is_empty(),
		"%d consommée(s), %d restante(s)" % [consommees, file.size()])
