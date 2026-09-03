## Suite du modèle de la fusée éclairante (chantier FUSÉE, FU1-FU2).
##
## Ne teste QUE `fusee_modele.gd`, sans dépendance — le nœud `fusee.gd`, lui,
## nomme des autoloads et ne compile pas sous `--script` (règle du dépôt, même
## partage que brouillage/vision : le modèle est pur, l'habillage est un nœud).
##
## Lancer : godot --headless --path . --script res://tools/test_fusee.gd
extends SceneTree

const Modele := preload("res://fusee_modele.gd")

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
	print("=== LA FUSÉE ÉCLAIRANTE ===")
	_test_vol()
	_test_rebond()
	_test_actes()
	_test_agonie_deterministe()
	_test_agonie_bornee()
	_test_energie()
	_test_photosensibilite()
	_test_temperature()
	_test_fumee()
	_test_sillage()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# LE VOL — frottement qui freine, rebond qui amortit (FU2.1 : la fusée
# rebondit sur les murs, elle ne les survole plus — décision d'Adrien)
# ---------------------------------------------------------------------------
func _test_vol() -> void:
	print("\n— le vol —")
	_check("le frottement freine",
		Modele.vitesse_apres(Modele.VITESSE_LANCER, 0.2) < Modele.VITESSE_LANCER)
	_check("et ne rend jamais une vitesse négative",
		is_zero_approx(Modele.vitesse_apres(10.0, 100.0)))
	_check("la vitesse décroît linéairement",
		is_equal_approx(Modele.vitesse_apres(900.0, 0.1),
			900.0 - Modele.FROTTEMENT_VOL * 0.1))
	# Intégration discrète à 60 Hz : la distance parcourue doit retrouver la
	# portée dérivée, à l'épaisseur d'un pas près.
	var vitesse := Modele.VITESSE_LANCER
	var distance := 0.0
	while vitesse > 0.0:
		distance += vitesse / 60.0
		vitesse = Modele.vitesse_apres(vitesse, 1.0 / 60.0)
	_check("la portée intégrée retrouve la portée dérivée (~%.0f px)" % Modele.portee_libre(),
		absf(distance - Modele.portee_libre()) < Modele.VITESSE_LANCER / 60.0 + 1.0,
		"intégrée %.1f" % distance)


func _test_rebond() -> void:
	print("\n— le rebond —")
	var v := Vector2(300.0, 100.0)
	var r := Modele.rebondir(v, Vector2(-1.0, 0.0))
	_check("un mur vertical inverse la composante horizontale",
		r.x < 0.0 and is_equal_approx(r.y, v.y * Modele.REBOND_AMORTI))
	_check("chaque rebond amortit",
		r.length() < v.length())
	_check("de la part déclarée exactement",
		is_equal_approx(r.length(), v.length() * Modele.REBOND_AMORTI))
	_check("le rebond est pur : deux appels, même réponse",
		Modele.rebondir(v, Vector2(0.0, 1.0)) == Modele.rebondir(v, Vector2(0.0, 1.0)))


# ---------------------------------------------------------------------------
# LES ACTES — l'horloge publique
# ---------------------------------------------------------------------------
func _test_actes() -> void:
	print("\n— les actes —")
	_check("avant l'atterrissage : le vol", Modele.acte_a(-0.1) == Modele.Acte.VOL)
	_check("0 s : le plein feu", Modele.acte_a(0.0) == Modele.Acte.PLEIN_FEU)
	_check("la frontière plein feu→braise est à DUREE_PLEIN_FEU",
		Modele.acte_a(Modele.DUREE_PLEIN_FEU - 0.001) == Modele.Acte.PLEIN_FEU
		and Modele.acte_a(Modele.DUREE_PLEIN_FEU) == Modele.Acte.BRAISE)
	var debut_agonie := Modele.DUREE_PLEIN_FEU + Modele.DUREE_BRAISE
	_check("la frontière braise→agonie",
		Modele.acte_a(debut_agonie - 0.001) == Modele.Acte.BRAISE
		and Modele.acte_a(debut_agonie) == Modele.Acte.AGONIE)
	_check("après tout : morte",
		Modele.acte_a(Modele.duree_combustion()) == Modele.Acte.MORTE)
	_check("la durée totale est la somme des actes",
		is_equal_approx(Modele.duree_combustion(),
			Modele.DUREE_PLEIN_FEU + Modele.DUREE_BRAISE + Modele.DUREE_AGONIE + Modele.DUREE_RESIDU))


# ---------------------------------------------------------------------------
# L'AGONIE — même graine, mêmes flashs, partout (c'est ce qui rend la killcam
# et la synchro gratuites : le strobe n'est jamais un état, c'est une formule)
# ---------------------------------------------------------------------------
func _test_agonie_deterministe() -> void:
	print("\n— l'agonie, déterministe —")
	var a := Modele.fenetres_agonie(12345)
	var b := Modele.fenetres_agonie(12345)
	_check("même graine → mêmes fenêtres", str(a) == str(b))
	var c := Modele.fenetres_agonie(54321)
	_check("autre graine → autres fenêtres", str(a) != str(c))


func _test_agonie_bornee() -> void:
	print("\n— l'agonie, bornée —")
	for graine in [0, 1, 999983, -7]:
		var fen := Modele.fenetres_agonie(graine)
		var ok_nb: bool = fen.size() >= Modele.AGONIE_FLASHS_MIN \
			and fen.size() <= Modele.AGONIE_FLASHS_MAX
		var ok_bornes := true
		var ok_ordre := true
		var precedent := -1.0
		for f in fen:
			if f[0] < 0.0 or f[1] > Modele.DUREE_AGONIE:
				ok_bornes = false
			if f[0] <= precedent:
				ok_ordre = false
			precedent = f[1]
		_check("graine %d : nombre borné, fenêtres dans l'agonie, jamais deux collées" % graine,
			ok_nb and ok_bornes and ok_ordre,
			str(fen))
	var fen := Modele.fenetres_agonie(42)
	var debut_agonie := Modele.DUREE_PLEIN_FEU + Modele.DUREE_BRAISE
	var centre_0: float = (fen[0][0] + fen[0][1]) * 0.5
	_check("un sursaut culmine au centre de sa fenêtre",
		Modele.flash_actif(debut_agonie + centre_0, fen)
		and is_equal_approx(Modele.lueur_agonie(debut_agonie + centre_0, fen), 1.0))
	_check("hors agonie, jamais de sursaut",
		not Modele.flash_actif(1.0, fen) and not Modele.flash_actif(debut_agonie - 0.5, fen))
	# L'enveloppe est un RALLUMAGE, pas un créneau (retour d'Adrien, FU2.1) :
	# continue partout — d'un millième de seconde à l'autre, jamais de saut.
	var lisse := true
	var t := 0.0
	var precedent := Modele.energie_a(debut_agonie, fen, 1.0)
	while t < Modele.DUREE_AGONIE:
		t += 0.001
		var e := Modele.energie_a(debut_agonie + t, fen, 1.0)
		if absf(e - precedent) > 0.06:
			lisse = false
			break
		precedent = e
	_check("l'agonie est continue : pas un créneau, des rallumages", lisse,
		"saut à t=%.3f" % t)


# ---------------------------------------------------------------------------
# L'ÉNERGIE — la courbe qui raconte les actes
# ---------------------------------------------------------------------------
func _test_energie() -> void:
	print("\n— l'énergie —")
	var fen := Modele.fenetres_agonie(7)
	_check("en vol : la comète", is_equal_approx(Modele.energie_a(-0.2, fen), Modele.ENERGIE_VOL))
	_check("le plein feu éclaire à pleine énergie",
		is_equal_approx(Modele.energie_a(1.0, fen), Modele.ENERGIE_PLEIN_FEU))
	_check("le raccord part de l'énergie du plein feu",
		is_equal_approx(Modele.energie_a(Modele.DUREE_PLEIN_FEU, fen), Modele.ENERGIE_PLEIN_FEU))
	_check("et atteint celle de la braise",
		is_equal_approx(Modele.energie_a(Modele.DUREE_PLEIN_FEU + Modele.RACCORD_PLEIN_FEU_BRAISE, fen),
			Modele.ENERGIE_BRAISE))
	_check("morte : plus rien",
		is_zero_approx(Modele.energie_a(Modele.duree_combustion() + 1.0, fen)))
	var fin_residu := Modele.duree_combustion()
	_check("le résidu s'éteint en fondu jusqu'à zéro",
		Modele.energie_a(fin_residu - 0.01, fen) < Modele.ENERGIE_RESIDU * 0.1)


# ---------------------------------------------------------------------------
# LA PHOTOSENSIBILITÉ — à intensité nulle, plus un seul saut : le strobe
# s'aplatit sur le fondu, le tempo reste au SON (règle d'effect_policy)
# ---------------------------------------------------------------------------
func _test_photosensibilite() -> void:
	print("\n— la variante photosensibilité —")
	var fen := Modele.fenetres_agonie(99)
	var debut_agonie := Modele.DUREE_PLEIN_FEU + Modele.DUREE_BRAISE
	var t_sursaut: float = debut_agonie + (fen[0][0] + fen[0][1]) * 0.5
	_check("à pleine intensité, le sursaut domine largement le fondu",
		Modele.energie_a(t_sursaut, fen, 1.0) > Modele.energie_a(t_sursaut, fen, 0.0) + 1.0)
	# À intensité nulle, l'agonie EST le fondu : la même valeur au sursaut et
	# loin de lui, à la pente du fondu près.
	var fondu_a: float = Modele.energie_a(t_sursaut, fen, 0.0)
	var t_rel: float = t_sursaut - debut_agonie
	var fondu_attendu := lerpf(Modele.ENERGIE_BRAISE, Modele.ENERGIE_RESIDU,
		t_rel / Modele.DUREE_AGONIE)
	_check("à intensité nulle, le sursaut s'aplatit sur le fondu",
		absf(fondu_a - fondu_attendu) < 0.01, "écart %f" % absf(fondu_a - fondu_attendu))


func _test_temperature() -> void:
	print("\n— la température —")
	_check("rouge de détresse au début (température 0)", is_zero_approx(Modele.temperature_a(0.5)))
	_check("braise une fois le raccord passé",
		is_equal_approx(Modele.temperature_a(Modele.DUREE_PLEIN_FEU + Modele.RACCORD_PLEIN_FEU_BRAISE + 0.1), 1.0))
	_check("le raccord est progressif",
		Modele.temperature_a(Modele.DUREE_PLEIN_FEU + Modele.RACCORD_PLEIN_FEU_BRAISE * 0.5) > 0.0
		and Modele.temperature_a(Modele.DUREE_PLEIN_FEU + Modele.RACCORD_PLEIN_FEU_BRAISE * 0.5) < 1.0)


# ---------------------------------------------------------------------------
# LA FUMÉE — elle s'épaissit (le plein feu reste un scan), règne, et meurt AVEC la
# lumière : pas de nuage orphelin en v1, c'est une décision non actée
# ---------------------------------------------------------------------------
func _test_fumee() -> void:
	print("\n— la fumée —")
	_check("rien pendant le vol", is_zero_approx(Modele.alpha_fumee_a(-0.5)))
	_check("elle monte pendant le plein feu : le scan reste un scan",
		Modele.alpha_fumee_a(Modele.DUREE_PLEIN_FEU * 0.5) < 1.0)
	_check("pleine densité en croisière",
		is_equal_approx(Modele.alpha_fumee_a(Modele.FUMEE_MONTEE + 1.0), 1.0))
	_check("morte avec la lumière",
		is_zero_approx(Modele.alpha_fumee_a(Modele.duree_combustion())))
	_check("les nappes gonflent de ×1 vers le plafond",
		is_equal_approx(Modele.echelle_fumee_a(0.0), 1.0)
		and is_equal_approx(Modele.echelle_fumee_a(Modele.duree_combustion()), Modele.FUMEE_GONFLE))


# ---------------------------------------------------------------------------
# LE SILLAGE — l'endroit qui cache le mieux est celui qui enregistre le mieux
# ---------------------------------------------------------------------------
func _test_sillage() -> void:
	print("\n— le sillage —")
	var points := [
		{"pos": Vector2.ZERO, "t": 0.0},
		{"pos": Vector2.ONE, "t": 3.0},
	]
	var vivants := Modele.filtrer_sillage(points, 3.5)
	_check("un point plus vieux que la refermeture disparaît",
		vivants.size() == 1 and vivants[0]["t"] == 3.0)
	var beaucoup: Array = []
	for i in 20:
		beaucoup.append({"pos": Vector2(i, 0), "t": 10.0})
	_check("le tampon est borné, les plus récents gagnent",
		Modele.filtrer_sillage(beaucoup, 10.0).size() == Modele.SILLAGE_POINTS_MAX)
	_check("un couloir frais est ouvert en grand",
		is_equal_approx(Modele.rayon_sillage(0.0), Modele.SILLAGE_RAYON))
	_check("et refermé au bout de sa vie",
		is_zero_approx(Modele.rayon_sillage(Modele.SILLAGE_DUREE)))
	_check("la refermeture est monotone",
		Modele.rayon_sillage(0.5) > Modele.rayon_sillage(1.0))
