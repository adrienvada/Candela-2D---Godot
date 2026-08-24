## L'éblouissement dans le temps — le test qui manquait, et qui aurait tout dit.
##
## `test_vision` couvrait le cône et l'occlusion, c'est-à-dire les deux seules
## parties de la mécanique qui FONCTIONNAIENT. L'intégration de
## `dazzle_amount`, elle, n'était couverte nulle part : la montée valait
## `+0,5/s` et la descente, écrite dans un autre fichier et inconditionnelle,
## `−2,0/s`. Sous un faisceau tenu en pleine face le bilan était négatif, la
## valeur n'a jamais dépassé 0,008 — et trente suites annonçaient « tous les
## tests passent » pendant que la mécanique centrale du jeu ne faisait rien.
##
## D'où le premier contrôle de ce fichier, qui a l'air trop bête pour être
## écrit : **sous une lumière, la valeur monte.** C'est exactement celui qui
## manquait.
##
## Lancer : godot --headless --path . --script res://tools/test_eblouissement.gd
extends SceneTree

const Eblouissement := preload("res://eblouissement.gd")

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
	print("=== L'ÉBLOUISSEMENT ===")
	_test_montee()
	_test_courbe()
	_test_plafond()
	_test_descente()
	_test_cadence()
	_test_flash()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

## Intègre `duree` secondes sous une lumière constante, par pas de `pas`.
func _integre(depart: float, plafond: float, duree: float, pas: float = 1.0 / 60.0) -> float:
	var v := depart
	var t := 0.0
	while t < duree - 1e-9:
		var d: float = minf(pas, duree - t)
		v = Eblouissement.integrer(v, plafond, d)
		t += d
	return v

# ---------------------------------------------------------------------------
# LA MONTÉE
# ---------------------------------------------------------------------------

func _test_montee() -> void:
	print("\n[La montée]")
	# LE contrôle qui manquait. Une seule image sous un faisceau doit laisser
	# une trace : c'est tout ce qu'il fallait pour voir le défaut de 2026-08-18.
	_check("une image sous la lumière fait monter la valeur",
		Eblouissement.integrer(0.0, 1.0, 1.0 / 60.0) > 0.0)

	# Et elle doit monter VITE : « rapide, quasi immédiat » (Adrien, 2026-08-18).
	# Un dixième de seconde de faisceau saturant se voit déjà.
	_check("un dixième de seconde se voit", _integre(0.0, 1.0, 0.1) > 0.1,
		str(_integre(0.0, 1.0, 0.1)))

	var plein := 1.0 / Eblouissement.MONTEE_PAR_S
	_check("saturation atteinte en %.2f s" % plein,
		is_equal_approx(_integre(0.0, 1.0, plein), 1.0), str(_integre(0.0, 1.0, plein)))
	# Le contre-test : sans lui, une montée cent fois trop rapide passerait.
	_check("mais pas à la moitié du temps", _integre(0.0, 1.0, plein * 0.5) < 0.9,
		str(_integre(0.0, 1.0, plein * 0.5)))

# ---------------------------------------------------------------------------
# LA COURBE — de la lumière reçue à la pénalité
# ---------------------------------------------------------------------------

func _test_courbe() -> void:
	print("\n[La courbe lumière → pénalité]")
	# Les deux bornes sont la mécanique du jeu, pas des cas limites.
	#
	# **Celle du bas d'abord**, parce qu'elle est la plus chère à casser : hors
	# du faisceau on ne prend RIEN. Une courbe qui relèverait le zéro — un
	# seuil, un décalage, un `max()` mal placé — rendrait le noir absolu
	# éblouissant, et le jeu entier repose sur le fait que le noir ne coûte
	# rien. Le contrôle a l'air trivial ; il est le seul qui protège la
	# proposition de départ du jeu.
	_check("le noir ne coûte rien",
		is_zero_approx(Eblouissement.plafond_pour(0.0)))
	_check("une lumière saturante sature toujours",
		is_equal_approx(Eblouissement.plafond_pour(1.0), 1.0))

	# Monotone : plus de lumière ne peut jamais coûter moins. Sans ce contrôle,
	# un exposant négatif passerait les deux bornes et inverserait le jeu — se
	# rapprocher d'une torche soulagerait.
	var precedent := -1.0
	var monotone := true
	for i in range(0, 21):
		var x := float(i) / 20.0
		var y: float = Eblouissement.plafond_pour(x)
		if y < precedent:
			monotone = false
		precedent = y
	_check("plus de lumière ne coûte jamais moins", monotone)

	# Elle RELÈVE, elle n'abaisse jamais : c'est le sens du correctif. Une
	# courbure supérieure à 1 creuserait au lieu de redresser, et aggraverait
	# très exactement le défaut qu'elle est censée corriger.
	var releve := true
	for i in range(1, 20):
		var x := float(i) / 20.0
		if Eblouissement.plafond_pour(x) < x - 1e-6:
			releve = false
	_check("la courbe relève le milieu, jamais l'inverse", releve)

	# LE cas qui l'a motivée, mesuré à l'écran le 2026-08-24 : à 95 % de la
	# portée du pistolet, `Vision` rend 0,050 — un voile invisible — pour un
	# joueur qui se tient dans une plaque de lumière franchement visible.
	# Le chiffre attendu n'est pas rond parce qu'il vient d'une mesure, pas
	# d'un souhait.
	var bout := Eblouissement.plafond_pour(0.05)
	_check("le bout du faisceau se sent enfin (0,05 de lumière → %.2f)" % bout,
		bout > 0.2, str(bout))
	# Et le contre-test : il se sent, il n'assomme pas. Sans cette borne, une
	# courbure plus agressive rendrait le simple fait d'être à portée aussi
	# coûteux que d'être dans l'axe, et la torche cesserait de se viser.
	_check("mais il n'assomme pas", bout < 0.4, str(bout))

	# Bornes : une intensité aberrante ne doit pas sortir de [0, 1]. `pow()`
	# sur un négatif rend NAN, qui se propagerait dans `dazzle_amount` et
	# empoisonnerait la vitesse ET la visée sans lever la moindre erreur.
	_check("une lumière > 1 est ramenée",
		is_equal_approx(Eblouissement.plafond_pour(4.0), 1.0))
	_check("une lumière négative vaut le noir",
		is_zero_approx(Eblouissement.plafond_pour(-2.0)))
	_check("et rien ne rend NAN",
		not is_nan(Eblouissement.plafond_pour(-2.0)))

# ---------------------------------------------------------------------------
# LE PLAFOND
# ---------------------------------------------------------------------------

func _test_plafond() -> void:
	print("\n[Le plafond]")
	# La lumière reçue plafonne, elle ne s'additionne pas : une torche lointaine
	# ou rasante ne peut pas aveugler à force d'insister. Sans cette propriété,
	# rester dix secondes dans le halo d'un faisceau vaudrait un flash à bout
	# portant, et l'éblouissement cesserait de dire quelque chose de la position.
	_check("une lumière faible ne dépasse jamais son plafond",
		is_equal_approx(_integre(0.0, 0.3, 10.0), 0.3), str(_integre(0.0, 0.3, 10.0)))
	_check("et elle l'atteint quand même",
		_integre(0.0, 0.3, 1.0) > 0.29, str(_integre(0.0, 0.3, 1.0)))
	# Le plafond qui baisse fait redescendre : sortir du faisceau soulage
	# immédiatement, même en restant dans un reste de halo.
	_check("un plafond qui baisse fait redescendre",
		_integre(1.0, 0.2, 0.5) < 1.0)
	_check("jusqu'au nouveau plafond, pas plus bas",
		is_equal_approx(_integre(1.0, 0.2, 5.0), 0.2), str(_integre(1.0, 0.2, 5.0)))
	# Bornes : une intensité aberrante ne doit pas sortir de [0, 1].
	_check("un plafond > 1 est ramené à 1",
		is_equal_approx(_integre(0.0, 4.0, 10.0), 1.0))
	_check("un plafond négatif vaut le noir",
		is_equal_approx(_integre(0.5, -2.0, 10.0), 0.0))

# ---------------------------------------------------------------------------
# LA DESCENTE
# ---------------------------------------------------------------------------

func _test_descente() -> void:
	print("\n[La descente]")
	var plein := 1.0 / Eblouissement.DESCENTE_PAR_S
	_check("dans le noir, retour à zéro en %.2f s" % plein,
		is_equal_approx(_integre(1.0, 0.0, plein), 0.0), str(_integre(1.0, 0.0, plein)))
	_check("et pas avant", _integre(1.0, 0.0, plein * 0.5) > 0.1,
		str(_integre(1.0, 0.0, plein * 0.5)))
	# La récupération est plus LENTE que la montée : c'est ce décalage qui fait
	# de l'éblouissement une ouverture exploitable plutôt qu'une gêne qui passe
	# avant qu'on en profite. Réglage de jeu, gardé par un test parce que
	# l'inverser ne casserait rien de visible.
	_check("récupérer prend plus longtemps qu'être ébloui",
		Eblouissement.DESCENTE_PAR_S < Eblouissement.MONTEE_PAR_S)

# ---------------------------------------------------------------------------
# LA CADENCE
# ---------------------------------------------------------------------------

func _test_cadence() -> void:
	print("\n[La cadence]")
	# Les images ne sont pas plafonnées dans ce jeu (décision de rendu) : une
	# machine tourne à 120 fps, une autre à 492. Un modèle qui dépendrait du
	# nombre d'images donnerait deux éblouissements différents pour la même
	# scène — et le défaut ne se verrait que sur la machine la plus rapide.
	# Un tampon dimensionné en images a déjà tronqué la killcam à 0,9 s.
	var a := _integre(0.0, 1.0, 0.5, 1.0 / 60.0)
	var b := _integre(0.0, 1.0, 0.5, 1.0 / 492.0)
	var c := _integre(0.0, 1.0, 0.5, 1.0 / 15.0)
	_check("60, 492 et 15 fps donnent le même éblouissement",
		absf(a - b) < 1e-4 and absf(a - c) < 1e-4, "%f / %f / %f" % [a, b, c])
	var d := _integre(1.0, 0.0, 0.5, 1.0 / 60.0)
	var e := _integre(1.0, 0.0, 0.5, 1.0 / 492.0)
	_check("et la même récupération", absf(d - e) < 1e-4, "%f / %f" % [d, e])

# ---------------------------------------------------------------------------
# LE FLASH DE TIR
# ---------------------------------------------------------------------------

func _test_flash() -> void:
	print("\n[Le flash de tir]")
	_check("à bout portant, le pic est maximal",
		is_equal_approx(Eblouissement.pic_de_flash(0.0, 1.0), Eblouissement.PIC_FLASH))
	_check("au-delà de la portée, rien",
		is_zero_approx(Eblouissement.pic_de_flash(Eblouissement.PORTEE_FLASH, 1.0)))
	_check("et rien non plus bien au-delà",
		is_zero_approx(Eblouissement.pic_de_flash(10000.0, 1.0)))
	_check("le pic décroît avec la distance",
		Eblouissement.pic_de_flash(100.0, 1.0) > Eblouissement.pic_de_flash(400.0, 1.0))
	# L'arbalète est l'arme discrète (`muzzle_flash_intensity` = 0,1) : son
	# carreau ne révèle presque rien, il serait incohérent qu'il aveugle comme
	# le fusil. Le réglage servait au rendu, il sert maintenant deux fois.
	_check("une arme discrète éblouit dix fois moins",
		is_equal_approx(Eblouissement.pic_de_flash(0.0, 0.1),
			Eblouissement.pic_de_flash(0.0, 1.0) * 0.1))

	# Le pic passe AU-DESSUS du plafond de la torche, puis s'y résorbe. C'est
	# la propriété qui rend le flash lisible : on est aveuglé d'un coup, pas
	# progressivement, et l'effet retombe au niveau du faisceau qui reste.
	var apres_pic: float = minf(1.0, 0.1 + Eblouissement.pic_de_flash(0.0, 1.0))
	_check("un flash dépasse le plafond de la torche", apres_pic > 0.1)
	_check("puis s'y résorbe",
		is_equal_approx(_integre(apres_pic, 0.1, 5.0), 0.1),
		str(_integre(apres_pic, 0.1, 5.0)))
