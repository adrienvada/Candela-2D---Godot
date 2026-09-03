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
	_test_cible()
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
# LE VOL — durée bornée, trajectoire qui part et qui arrive
# ---------------------------------------------------------------------------
func _test_vol() -> void:
	print("\n— le vol —")
	_check("un jet dans ses pieds vole quand même un instant",
		is_equal_approx(Modele.duree_vol(1.0), Modele.DUREE_VOL_MIN))
	_check("la durée croît avec la distance",
		Modele.duree_vol(400.0) > Modele.duree_vol(150.0))
	_check("la durée plafonne",
		Modele.duree_vol(100000.0) <= Modele.DUREE_VOL_MAX + 0.0001)
	var a := Vector2(100, 100)
	var b := Vector2(400, 250)
	_check("t=0 part du départ", Modele.position_vol(a, b, 0.0).is_equal_approx(a))
	_check("t=1 arrive à la cible", Modele.position_vol(a, b, 1.0).is_equal_approx(b))
	_check("la cloche est au sol aux deux bouts",
		is_zero_approx(Modele.hauteur_vol(0.0)) and is_zero_approx(Modele.hauteur_vol(1.0)))
	_check("et culmine au milieu", is_equal_approx(Modele.hauteur_vol(0.5), 1.0))


func _test_cible() -> void:
	print("\n— la cible —")
	var d := Vector2(500, 500)
	var trop_pres := Modele.borner_cible(d, d + Vector2(10, 0))
	_check("une cible trop proche est repoussée à la portée minimale",
		is_equal_approx(trop_pres.distance_to(d), Modele.PORTEE_MIN))
	var trop_loin := Modele.borner_cible(d, d + Vector2(9999, 0))
	_check("une cible trop lointaine est ramenée à la portée maximale",
		is_equal_approx(trop_loin.distance_to(d), Modele.PORTEE_MAX))
	var sur_place := Modele.borner_cible(d, d)
	_check("une cible confondue avec le départ ne rend pas le départ",
		sur_place.distance_to(d) >= Modele.PORTEE_MIN - 0.001)


# ---------------------------------------------------------------------------
# LES ACTES — l'horloge publique
# ---------------------------------------------------------------------------
func _test_actes() -> void:
	print("\n— les actes —")
	_check("avant l'atterrissage : le vol", Modele.acte_a(-0.1) == Modele.Acte.VOL)
	_check("0 s : le blanc", Modele.acte_a(0.0) == Modele.Acte.BLANC)
	_check("la frontière blanc→braise est à DUREE_BLANC",
		Modele.acte_a(Modele.DUREE_BLANC - 0.001) == Modele.Acte.BLANC
		and Modele.acte_a(Modele.DUREE_BLANC) == Modele.Acte.BRAISE)
	var debut_agonie := Modele.DUREE_BLANC + Modele.DUREE_BRAISE
	_check("la frontière braise→agonie",
		Modele.acte_a(debut_agonie - 0.001) == Modele.Acte.BRAISE
		and Modele.acte_a(debut_agonie) == Modele.Acte.AGONIE)
	_check("après tout : morte",
		Modele.acte_a(Modele.duree_combustion()) == Modele.Acte.MORTE)
	_check("la durée totale est la somme des actes",
		is_equal_approx(Modele.duree_combustion(),
			Modele.DUREE_BLANC + Modele.DUREE_BRAISE + Modele.DUREE_AGONIE + Modele.DUREE_RESIDU))


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
	var debut_agonie := Modele.DUREE_BLANC + Modele.DUREE_BRAISE
	_check("un flash est bien vu allumé pendant sa fenêtre",
		Modele.flash_actif(debut_agonie + fen[0][0] + 0.001, fen))
	_check("hors agonie, jamais de flash",
		not Modele.flash_actif(1.0, fen) and not Modele.flash_actif(debut_agonie - 0.5, fen))


# ---------------------------------------------------------------------------
# L'ÉNERGIE — la courbe qui raconte les actes
# ---------------------------------------------------------------------------
func _test_energie() -> void:
	print("\n— l'énergie —")
	var fen := Modele.fenetres_agonie(7)
	_check("en vol : la comète", is_equal_approx(Modele.energie_a(-0.2, fen), Modele.ENERGIE_VOL))
	_check("le blanc éclaire à pleine énergie",
		is_equal_approx(Modele.energie_a(1.0, fen), Modele.ENERGIE_BLANC))
	_check("le raccord part de l'énergie du blanc",
		is_equal_approx(Modele.energie_a(Modele.DUREE_BLANC, fen), Modele.ENERGIE_BLANC))
	_check("et atteint celle de la braise",
		is_equal_approx(Modele.energie_a(Modele.DUREE_BLANC + Modele.RACCORD_BLANC_BRAISE, fen),
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
	var debut_agonie := Modele.DUREE_BLANC + Modele.DUREE_BRAISE
	var t_flash: float = debut_agonie + fen[0][0] + 0.001
	var t_creux: float = debut_agonie + fen[0][1] + 0.001
	_check("à pleine intensité, le flash saute au-dessus du creux",
		Modele.energie_a(t_flash, fen, 1.0) > Modele.energie_a(t_creux, fen, 1.0) + 1.0)
	var saut: float = abs(Modele.energie_a(t_flash, fen, 0.0) - Modele.energie_a(t_creux, fen, 0.0))
	_check("à intensité nulle, flash et creux se confondent (fondu continu)",
		saut < 0.05, "saut résiduel %f" % saut)


func _test_temperature() -> void:
	print("\n— la température —")
	_check("blanc magnésium au début", is_zero_approx(Modele.temperature_a(0.5)))
	_check("braise une fois le raccord passé",
		is_equal_approx(Modele.temperature_a(Modele.DUREE_BLANC + Modele.RACCORD_BLANC_BRAISE + 0.1), 1.0))
	_check("le raccord est progressif",
		Modele.temperature_a(Modele.DUREE_BLANC + Modele.RACCORD_BLANC_BRAISE * 0.5) > 0.0
		and Modele.temperature_a(Modele.DUREE_BLANC + Modele.RACCORD_BLANC_BRAISE * 0.5) < 1.0)


# ---------------------------------------------------------------------------
# LA FUMÉE — elle s'épaissit (le blanc reste un scan), règne, et meurt AVEC la
# lumière : pas de nuage orphelin en v1, c'est une décision non actée
# ---------------------------------------------------------------------------
func _test_fumee() -> void:
	print("\n— la fumée —")
	_check("rien pendant le vol", is_zero_approx(Modele.alpha_fumee_a(-0.5)))
	_check("elle monte pendant le blanc : le scan reste un scan",
		Modele.alpha_fumee_a(Modele.DUREE_BLANC * 0.5) < 1.0)
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
