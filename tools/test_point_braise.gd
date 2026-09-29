## LE POINT DE BRAISE DE LA FUSÉE, AUSSI LUMINEUX QUE SA LUMIÈRE ET TOUJOURS ROUGE (Adrien, 2026-09-29).
##
## ## La demande
##
## « Le point rouge de la fusée, quand elle retombe en braise, est 3,6 fois moins lumineux que l'ancien point orange, et le repère se
## perd. Le rendre aussi lumineux que sa lumière, en gardant le rouge ? » — « Le point rouge : oui, dans la 0.8.0 ». Le 3,6 est la
## luminance (Rec. 709, sur les valeurs affichées) de (82, 55, 26) sur celle de (39, 10, 12), au résidu (16 s), lues par la session
## « fusée-point » le 27/09. Avant la correction de `78fb380` (Q34 = C), le point était de la couleur de la LUMIÈRE et s'ADDITIONNAIT au
## sol ; il est depuis du rouge de détresse, en MÉLANGE, à l'éclat de la lumière (`énergie / 0,8 × opacité du cœur 2D`) : rouge, mais
## trois à quatre fois plus sombre au résidu, et plus sombre que le sol qu'éclaire la fusée.
##
## ## La règle, et pourquoi elle est celle-là
##
## À chaque âge après le plein feu, la luminance du point (`rouge × min(éclat, 1)`, ce que son halo écrit au cœur) vaut au moins :
##
##     luminance(sa lumière)  +  luminance(ce que l'ancien point y ajoutait)
##     = luma(couleur de la lumière) × (min(énergie, 1) + min(éclat d'avant, 1))
##
## bornée par ce qu'un rouge peut porter : `luma(rouge du point)`, c'est-à-dire l'éclat 1. Deux raisons à la somme. (1) « Aussi
## lumineux que sa lumière » : le point ne peut pas être plus sombre que la lumière qu'il figure. (2) L'ancien point orange s'ADDITIONNAIT
## au sol, que la fusée éclaire d'au plus sa propre lumière (un sol n'est jamais plus clair que la lumière qui le frappe) : il valait donc
## au plus « sa lumière + son ajout ». Un point qui COUVRE le sol et vaut cette somme n'est donc plus sombre que l'ancien point orange
## sur AUCUN sol — la mesure de la session « fusée-point » (un sol de 30 de luminance) comme celle de la planche de cette session
## (`docs/iso/braise/`, un sol de 4). Au résidu (l'ambre : 0,715 de luminance, l'éclat d'avant valant énergie / 1,2), la somme est
## 1,633 × (1 + 1/1,2) = 2,994 fois l'énergie, en éclat du point : d'où `PLANCHER_ECLAT_PAR_ENERGIE` = 3,5 (17 % de marge).
##
## **Le rouge borne.** Au braise et à un sursaut d'agonie, la lumière (l'ambre × 1,2 : 0,715) est plus lumineuse que ne peut l'être un
## rouge saturé (0,438 pour le rouge de détresse ; au mieux 0,57 à saturation 0,6 et 8° de teinte). Le point y est déjà à son éclat
## plein : c'est le maximum du rouge qu'Adrien a choisi (Q34 = C), et rien ne s'y ajoute — « en gardant le rouge » l'emporte, là.
##
## ## Ce que la suite prouve, sans fenêtre, sur le modèle et sur la fonction que le jeu appelle (`IsoVolumes.eclat_coeur_fusee`)
##
## - la règle, à chaque pas de 1/60 s des 20 s de la fusée, pour le plein feu de 2 s et de 4 s (le rouge long), pour quatre graines de
##   sursauts et pour le strobe entier comme pour l'agonie aplatie (le réglage de photosensibilité) ;
## - **le rouge** : teinte de 350° à 15°, saturation d'au moins 0,6, à tout éclat ;
## - **jamais plus sombre qu'avant**, et **le même à l'éclat plein** : le plein feu et le braise (énergie ≥ 1,2) ne changent pas, au
##   pixel — le plein feu reste presque blanc (Q34 = C) ;
## - le point vit avec sa lumière : pas de lumière, pas de point de plus (le plancher suit l'énergie, qui tombe à 0 avec elle) ;
## - la fonction est monotone : plus la fusée brûle, plus le point est clair ;
## - **la garde rougit sans la correction** : le même calcul, refait avec l'éclat d'AVANT (sans plancher), échoue au résidu et au creux
##   de l'agonie — c'est le défaut que la suite est là pour attraper, gardé ici comme témoin ;
## - le jeu appelle bien cette fonction (`_suivre_coeur_fusee`), et non une copie de la formule.
##
## Ce qu'elle ne prouve pas : l'image. `tools/planche_braise.gd` (sous Xvfb) mesure le point à chaque âge, dans les deux vues, avant et
## après — `docs/iso/braise/`. La suite `test_iso_gadgets` lit, elle, les paramètres du VRAI halo d'une VRAIE fusée posée.
##
## Lancer : godot --headless --path . --script res://tools/test_point_braise.gd
extends SceneTree

const PLANCHER := 20
const PAS := 1.0 / 60.0
const GRAINES := [0, 1, 4242, 99991]

var _echecs := 0
var _verifications := 0
var _ambre: Color
var _rouge: Color


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ %s" % label)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LE POINT DE BRAISE, AUSSI LUMINEUX QUE SA LUMIÈRE ET TOUJOURS ROUGE ===")
	await process_frame
	var Couleur: GDScript = load("res://fusee_couleur.gd")
	_ambre = Charte.AMBRE
	_rouge = IsoVolumes.COULEUR_COEUR_ROUGE
	var detresse := _rouge   # `Fusee.COULEUR_DETRESSE` : l'égalité est gardée par `test_iso_gadgets`

	print("\n— la règle, à chaque pas des vingt secondes de la fusée")
	for long in [false, true]:
		FuseeModele.poser_rouge_long(long)
		var nom := "plein feu de 4 s (rouge long)" if long else "plein feu de 2 s"
		var trop_sombre: Array = []
		var pas_rouge: Array = []
		var plus_sombre_qu_avant: Array = []
		var change_a_l_eclat_plein: Array = []
		var sans_point: Array = []
		var echantillons := 0
		var sursauts := 0
		for graine: int in GRAINES:
			var fenetres := FuseeModele.fenetres_agonie(graine)
			for intensite: float in [1.0, 0.0]:
				var age := 0.0
				while age <= FuseeModele.duree_combustion() + 1e-9:
					var acte := FuseeModele.acte_a(age)
					var e_modele := FuseeModele.energie_a(age, fenetres, intensite)
					var allumee := e_modele > 0.005
					var energie := e_modele if allumee else 0.0
					var opacite := clampf(e_modele / FuseeModele.ENERGIE_BRAISE, 0.0, 1.0)
					var eclat := IsoVolumes.eclat_coeur_fusee(energie, opacite)
					var avant := _eclat_d_avant(energie, opacite)
					var lumiere: Color = Couleur.couleur_a(FuseeModele.temperature_a(age), detresse)
					if acte == FuseeModele.Acte.AGONIE and e_modele > 2.0:
						sursauts += 1
					if acte in [FuseeModele.Acte.BRAISE, FuseeModele.Acte.AGONIE, FuseeModele.Acte.RESIDU]:
						echantillons += 1
						var etiquette := "%.3f s (%s), énergie %.3f" % [age, FuseeModele.Acte.keys()[acte], energie]
						# La règle.
						var requis := minf(_luma(lumiere) * (minf(energie, 1.0) + minf(avant, 1.0)), _luma(_rouge))
						var vaut := _luma(_rouge) * minf(eclat, 1.0)
						if allumee and vaut < requis - 1e-6:
							trop_sombre.append("%s : %.4f pour %.4f requis" % [etiquette, vaut, requis])
						# Le rouge, à tout éclat.
						if eclat > 0.002:
							var c := Color(_rouge.r * minf(eclat, 1.0), _rouge.g * minf(eclat, 1.0), _rouge.b * minf(eclat, 1.0))
							var h := fposmod(c.h * 360.0, 360.0)
							if not ((h >= 350.0 or h <= 15.0) and c.s >= 0.6):
								pas_rouge.append("%s : %.1f° sat. %.2f" % [etiquette, h, c.s])
						# Jamais plus sombre qu'avant ; le même quand la lumière brûle au moins comme au braise.
						if eclat < avant - 1e-9:
							plus_sombre_qu_avant.append("%s : %.4f contre %.4f" % [etiquette, eclat, avant])
						if energie >= FuseeModele.ENERGIE_BRAISE and absf(eclat - avant) > 1e-9:
							change_a_l_eclat_plein.append("%s : %.4f contre %.4f" % [etiquette, eclat, avant])
						# Pas de lumière, pas de point : le plancher tombe avec l'énergie.
						if not allumee and eclat > opacite + 1e-9:
							sans_point.append("%s : %.4f pour une opacité de %.4f" % [etiquette, eclat, opacite])
					age += PAS
		_check("%s : au moins aussi lumineux que sa lumière plus l'ancien point, borné par le rouge — %d instants, %d sursauts" % [nom, echantillons, sursauts],
			trop_sombre.is_empty() and echantillons > 1000 and sursauts > 0, str(trop_sombre.slice(0, 3)) + (" … %d en tout" % trop_sombre.size() if trop_sombre.size() > 3 else ""))
		_check("%s : rouge à tout éclat — teinte de 350° à 15°, saturation d'au moins 0,6" % nom, pas_rouge.is_empty(), str(pas_rouge.slice(0, 3)))
		_check("%s : jamais plus sombre qu'avant" % nom, plus_sombre_qu_avant.is_empty(), str(plus_sombre_qu_avant.slice(0, 3)))
		_check("%s : le braise et le plein feu (énergie ≥ %.1f) ne changent pas, à l'éclat près" % [nom, FuseeModele.ENERGIE_BRAISE],
			change_a_l_eclat_plein.is_empty(), str(change_a_l_eclat_plein.slice(0, 3)))
		_check("%s : lumière éteinte, le plancher ne tient pas le point allumé" % nom, sans_point.is_empty(), str(sans_point.slice(0, 3)))
	FuseeModele.poser_rouge_long(true)

	print("\n— le plein feu reste presque blanc, à l'éclat de toujours")
	var eclat_plein := IsoVolumes.eclat_coeur_fusee(FuseeModele.ENERGIE_PLEIN_FEU, 1.0)
	_check("plein feu : éclat 1,5 (celui de la comète), inchangé", is_equal_approx(eclat_plein, 1.5), str(eclat_plein))
	_check("plein feu : presque blanc ; braise, agonie et résidu : le rouge de détresse (Q34 = C)",
		IsoVolumes.couleur_coeur_fusee(2, FuseeModele.Acte.PLEIN_FEU, _ambre) == IsoVolumes.COULEUR_COEUR_BLANC
		and IsoVolumes.couleur_coeur_fusee(2, FuseeModele.Acte.BRAISE, _ambre) == _rouge
		and IsoVolumes.couleur_coeur_fusee(2, FuseeModele.Acte.AGONIE, _ambre) == _rouge
		and IsoVolumes.couleur_coeur_fusee(2, FuseeModele.Acte.RESIDU, _ambre) == _rouge)

	print("\n— le résidu, les chiffres de la demande")
	# Le résidu à 16 s : énergie 0,2, opacité du cœur 0,1667. L'éclat d'avant valait 0,1667 : le point à 0,1667 × le rouge, soit
	# (39, 10, 12) une fois affiché. Il vaut maintenant 0,7 : (172, 52, 60) affiché, au-dessus de ce qu'était l'ancien point orange.
	var e16 := FuseeModele.energie_a(16.0, FuseeModele.fenetres_agonie(0))
	var o16 := clampf(e16 / FuseeModele.ENERGIE_BRAISE, 0.0, 1.0)
	var eclat_16 := IsoVolumes.eclat_coeur_fusee(e16, o16)
	var avant_16 := _eclat_d_avant(e16, o16)
	_check("à 16 s : énergie %.3f, éclat d'avant %.4f, éclat maintenant %.4f" % [e16, avant_16, eclat_16],
		is_equal_approx(e16, 0.2) and is_equal_approx(avant_16, 1.0 / 6.0) and is_equal_approx(eclat_16, 0.7))
	var ancien_orange := Color(_ambre.r * avant_16, _ambre.g * avant_16, _ambre.b * avant_16)   # l'ancien point, seul sur le noir
	_check("à 16 s : le point vaut %.1f de luminance (sur 255), l'ancien point orange seul en valait %.1f, avant : %.1f" % [
		255.0 * _luma(_rouge) * eclat_16, 255.0 * _luma(ancien_orange), 255.0 * _luma(_rouge) * avant_16],
		_luma(_rouge) * eclat_16 > _luma(ancien_orange) * 2.0 and _luma(_rouge) * avant_16 < _luma(ancien_orange))

	print("\n— la fonction est monotone : plus la fusée brûle, plus le point est clair")
	var recule: Array = []
	var precedent := -1.0
	var e := 0.0
	while e <= 3.0 + 1e-9:
		var k := IsoVolumes.eclat_coeur_fusee(e, clampf(e / FuseeModele.ENERGIE_BRAISE, 0.0, 1.0))
		if k < precedent - 1e-9:
			recule.append("énergie %.3f : %.4f après %.4f" % [e, k, precedent])
		precedent = k
		e += 0.005
	_check("éclat non décroissant de l'énergie 0 à 3", recule.is_empty(), str(recule.slice(0, 3)))
	_check("énergie nulle : le plancher vaut 0", is_equal_approx(IsoVolumes.eclat_coeur_fusee(0.0, 0.0), 0.0))

	print("\n— la garde rougit sans la correction")
	# Le témoin : la MÊME règle, appliquée à l'éclat d'AVANT (sans plancher). Elle doit échouer au résidu et au creux de l'agonie.
	var fenetres_temoin := FuseeModele.fenetres_agonie(4242)
	var echecs_avant := 0
	var premier := ""
	for age in [12.25, 13.5, 15.0, 15.5, 16.0, 17.0, 18.0, 19.0]:
		var en := FuseeModele.energie_a(age, fenetres_temoin)
		var op := clampf(en / FuseeModele.ENERGIE_BRAISE, 0.0, 1.0)
		var lumiere: Color = Couleur.couleur_a(FuseeModele.temperature_a(age), detresse)
		var av := _eclat_d_avant(en, op)
		var requis := minf(_luma(lumiere) * (minf(en, 1.0) + minf(av, 1.0)), _luma(_rouge))
		if _luma(_rouge) * minf(av, 1.0) < requis - 1e-6:
			echecs_avant += 1
			if premier == "":
				premier = "%.2f s : %.4f pour %.4f requis" % [age, _luma(_rouge) * minf(av, 1.0), requis]
	_check("sans plancher, la règle échoue à %d des 8 âges de la fin de vie (le premier : %s)" % [echecs_avant, premier], echecs_avant >= 6)
	# Et une correction trop mince ne suffit pas : à 1,0 × l'énergie, elle échoue encore (la règle demande 2,994).
	var trop_mince := 0
	for age in [15.0, 16.0, 17.0]:
		var en := FuseeModele.energie_a(age, fenetres_temoin)
		var op := clampf(en / FuseeModele.ENERGIE_BRAISE, 0.0, 1.0)
		var lumiere: Color = Couleur.couleur_a(FuseeModele.temperature_a(age), detresse)
		var av := _eclat_d_avant(en, op)
		var requis := minf(_luma(lumiere) * (minf(en, 1.0) + minf(av, 1.0)), _luma(_rouge))
		if _luma(_rouge) * minf(maxf(av, en), 1.0) < requis - 1e-6:
			trop_mince += 1
	_check("un plancher de 1 × l'énergie ne suffirait pas non plus (%d des 3 âges du résidu échouent)" % trop_mince, trop_mince == 3)
	_check("la constante du jeu (%.1f) passe la règle avec de la marge : au moins %.3f exigés à l'ambre" % [
		IsoVolumes.PLANCHER_ECLAT_PAR_ENERGIE, _luma(_ambre) * (1.0 + 1.0 / 1.2) / _luma(_rouge)],
		IsoVolumes.PLANCHER_ECLAT_PAR_ENERGIE > _luma(_ambre) * (1.0 + 1.0 / 1.2) / _luma(_rouge) * 1.1)

	print("\n— le jeu appelle cette fonction, et non une copie de la formule")
	var src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("`_suivre_coeur_fusee` prend son éclat de `eclat_coeur_fusee`", src.contains("var eclat := eclat_coeur_fusee(energie, opacite)"))
	_check("la fonction est l'ancienne formule, plus le plancher : `max(ancien, clamp(3,5 × énergie))`",
		src.contains("var ancien := maxf(clampf(energie / 0.8, 0.0, 1.5) * opacite, opacite)")
		and src.contains("return maxf(ancien, clampf(PLANCHER_ECLAT_PAR_ENERGIE * energie, 0.0, 1.0))"))

	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


## L'éclat du point AVANT la correction : l'énergie de la lumière / 0,8 × l'opacité du cœur 2D, jamais sous cette opacité.
func _eclat_d_avant(energie: float, opacite: float) -> float:
	return maxf(clampf(energie / 0.8, 0.0, 1.5) * opacite, opacite)


## La luminance de Rec. 709 d'une couleur, en 0..1.
func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
