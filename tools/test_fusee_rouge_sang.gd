## La garde de l'ESSAI du rouge sang (`--fusee-rouge-sang`, éteint par défaut ; session cloud « fusée-rouge », 2026-09-27).
##
##   godot --headless --path . --script res://tools/test_fusee_rouge_sang.gd
##
## Éteint : la couleur de la lumière est celle d'avant, au bit près, à chaque âge. Allumé : LA RÈGLE, fixée avant les
## mesures (docs/iso/cloud/fusee-rouge/RAPPORT.md), à chaque âge (défaut et rouge long) et à chaque distance :
##  (a) la lecture du capteur ADVERSE (max(R, G, B) × énergie × masque, `capteur_adverse.gdshader`), du capteur LOCAL et du
##      seuil de Q32 (luminance × énergie × masque, `capteur_local.gdshader` → `pate_luminance`) à 1 % près ; les durées
##      lisibles au seuil 0,10 de 50 à 200 px, égales ;
##  (b) l'énergie (donc l'éblouissement, `Fusee.energie_relative`) : ne dépend pas du drapeau ;
##  (c) le sol éclairé (le brun des tuiles, ROADMAP « Les 8° vers l'orange ») : luminance à ±3 %, teinte à 353° ± 3 ;
##  (e) la lumière reste rouge (FU2.1) : le rouge est le canal maximal, saturation ≥ 0,5 ; la pâte la compte colorée
##      (poids de neutralité nul, comme la détresse) ; `Protocol.VERSION` reste 18.
## Le noir absolu (d) se prouve à l'image (le photographe), pas ici : voir le rapport.
## Ne nomme pas `Fusee` (autoloads) : la couleur de détresse se lit dans le TEXTE de fusee.gd, comme `test_iso_beaute.gd`.
extends SceneTree

const Modele := preload("res://fusee_modele.gd")
const Couleur := preload("res://fusee_couleur.gd")
const Ch := preload("res://charte.gd")
const Pate := preload("res://iso_pate.gd")

const EMPREINTE_LUMIERE := 440.0     # `fusee.gd`
const SEUIL_LISIBLE := 0.10          # Q32
const BRUN_TUILES := Vector3(1.0, 0.94, 0.62)  # la lightmap divisée par la lumière (ROADMAP, ISO13)
const TEINTE_ILLUSTRATION := 353.3
const DT := 1.0 / 120.0
const GRAINE := 4242
const DISTANCES := [50.0, 100.0, 125.0, 150.0, 200.0]

var _failures := 0
var _alpha: PackedFloat32Array = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _max(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b))


func _masque(d: float) -> float:
	var r := d / (EMPREINTE_LUMIERE * 0.5)
	if r >= 1.0:
		return 0.0
	return _alpha[mini(int(r * _alpha.size()), _alpha.size() - 1)]


func _detresse() -> Color:
	var lu := RegEx.create_from_string("const COULEUR_DETRESSE := Color\\(([0-9.]+), ([0-9.]+), ([0-9.]+)\\)").search(
		FileAccess.get_file_as_string("res://fusee.gd"))
	if lu == null:
		return Color.BLACK
	return Color(lu.get_string(1).to_float(), lu.get_string(2).to_float(), lu.get_string(3).to_float())


func _run() -> void:
	print("=== L'ESSAI DU ROUGE SANG (--fusee-rouge-sang) ===")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/halo/retrodiffusion_corona.png"))
	_check("le masque de la lumière se lit", img != null and not img.is_empty())
	if img == null or img.is_empty():
		quit(1)
		return
	for x in range(img.get_width() / 2, img.get_width()):
		_alpha.append(img.get_pixel(x, img.get_height() / 2).a)
	var d := _detresse()
	_check("la couleur de détresse se lit dans fusee.gd (%s)" % str(d), d.r > 0.5)
	_check("éteint par défaut (aucun drapeau sur la ligne de commande)", not Couleur.rouge_sang)
	_check("fusee.gd passe par FuseeCouleur partout où il posait la détresse",
		not FileAccess.get_file_as_string("res://fusee.gd").contains("COULEUR_DETRESSE.lerp")
		and not FileAccess.get_file_as_string("res://fusee.gd").contains("= COULEUR_DETRESSE\n"))
	var long_avant := Modele.duree_plein_feu > Modele.DUREE_PLEIN_FEU
	for long in [false, true]:
		Modele.poser_rouge_long(long)
		_eteint_identique(d, long)
		_regle(d, long)
	Modele.poser_rouge_long(long_avant)
	Couleur.poser_rouge_sang(false)
	_sol(d)
	_reste_rouge(d)
	_check("Protocol.VERSION reste 18", FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## Éteint : la même expression qu'avant, comparée au bit, à chaque pas d'âge.
func _eteint_identique(d: Color, long: bool) -> void:
	Couleur.poser_rouge_sang(false)
	var ecarts := 0
	var t := -0.5
	while t < Modele.duree_combustion() + 0.5:
		var temp := Modele.temperature_a(t)
		if Couleur.couleur_a(temp, d) != d.lerp(Ch.AMBRE, temp):
			ecarts += 1
		t += DT
	_check("éteint%s : la couleur d'avant au bit, à chaque âge (%d écart)" % [" (rouge long)" if long else "", ecarts],
		ecarts == 0)


## Allumé : la règle (a) et (b), âge par âge et distance par distance.
func _regle(d: Color, long: bool) -> void:
	var nom := " (rouge long)" if long else ""
	var fen := Modele.fenetres_agonie(GRAINE)
	var pire_max := 0.0
	var pire_lum := 0.0
	var energie_diff := 0
	var durees := {false: [0.0, 0.0, 0.0, 0.0, 0.0], true: [0.0, 0.0, 0.0, 0.0, 0.0]}
	var t := -0.5
	while t < Modele.duree_combustion() + 0.5:
		var temp := Modele.temperature_a(t)
		Couleur.poser_rouge_sang(false)
		var c0 := Couleur.couleur_a(temp, d)
		var e0 := Modele.energie_a(t, fen)
		Couleur.poser_rouge_sang(true)
		var c1 := Couleur.couleur_a(temp, d)
		var e1 := Modele.energie_a(t, fen)
		if e0 != e1:
			energie_diff += 1
		pire_max = maxf(pire_max, absf(_max(c1) / _max(c0) - 1.0))
		pire_lum = maxf(pire_lum, absf(_lum(c1) / _lum(c0) - 1.0))
		for i in DISTANCES.size():
			var m := _masque(DISTANCES[i])
			if _lum(c0) * e0 * m >= SEUIL_LISIBLE:
				durees[false][i] += DT
			if _lum(c1) * e1 * m >= SEUIL_LISIBLE:
				durees[true][i] += DT
		t += DT
	Couleur.poser_rouge_sang(false)
	_check("allumé%s : l'énergie (l'éblouissement) ne dépend pas du drapeau (%d écart)" % [nom, energie_diff],
		energie_diff == 0)
	# Les lectures sont linéaires en énergie × masque : un rapport de couleurs borné à chaque âge les borne à chaque distance.
	_check("allumé%s : capteur adverse (canal max) — pire écart %.3f %% (≤ 1 %%)" % [nom, pire_max * 100.0],
		pire_max <= 0.01)
	_check("allumé%s : capteur local et seuil de Q32 (luminance) — pire écart %.3f %% (≤ 1 %%)" % [nom, pire_lum * 100.0],
		pire_lum <= 0.01)
	for i in DISTANCES.size():
		var a: float = durees[false][i]
		var b: float = durees[true][i]
		_check("allumé%s : lisible au seuil 0,10 à %d px — %.3f s contre %.3f s" % [nom, DISTANCES[i], b, a],
			absf(a - b) <= DT + 1e-6)


## (c) Le sol éclairé : la lumière multiplie le brun des tuiles.
func _sol(d: Color) -> void:
	var sol := func(c: Color) -> Color:
		return Color(c.r * BRUN_TUILES.x, c.g * BRUN_TUILES.y, c.b * BRUN_TUILES.z)
	Couleur.poser_rouge_sang(false)
	var s0: Color = sol.call(Couleur.couleur_a(0.0, d))
	Couleur.poser_rouge_sang(true)
	var s1: Color = sol.call(Couleur.couleur_a(0.0, d))
	Couleur.poser_rouge_sang(false)
	var ecart := _lum(s1) / _lum(s0) - 1.0
	print("  sol au plein feu : défaut %.1f° sat %.2f, rouge sang %.1f° sat %.2f" % [s0.h * 360.0, s0.s, s1.h * 360.0, s1.s])
	_check("sol : luminance à ±3 %% (%+.2f %%)" % (ecart * 100.0), absf(ecart) <= 0.03)
	_check("sol : teinte à 353° ± 3 (%.1f°)" % (s1.h * 360.0), absf(s1.h * 360.0 - TEINTE_ILLUSTRATION) <= 3.0)
	_check("sol : le défaut, lui, tire vers l'orange (%.1f°)" % (s0.h * 360.0), s0.h * 360.0 < 15.0)


## (e) La lumière reste rouge, et la pâte la compte colorée comme avant.
func _reste_rouge(d: Color) -> void:
	Couleur.poser_rouge_sang(true)
	var tout_rouge := true
	for i in 21:
		var c := Couleur.couleur_a(float(i) / 20.0, d)
		if c.r < _max(c) or c.r != d.r:
			tout_rouge = false
	var s := Couleur.couleur_a(0.0, d)
	Couleur.poser_rouge_sang(false)
	_check("rouge : le canal rouge est le maximal et vaut %.2f à toute température" % d.r, tout_rouge)
	var teinte := s.h * 360.0
	_check("rouge : %.1f°, saturation %.2f — un rouge, jamais blanc (FU2.1)" % [teinte, s.s],
		(teinte >= 330.0 or teinte <= 15.0) and s.s >= 0.5)
	_check("pâte : comptée colorée comme la détresse (poids de neutralité %.2f)" % Pate.poids_neutre(Vector3(s.r, s.g, s.b)),
		Pate.poids_neutre(Vector3(s.r, s.g, s.b)) == 0.0 and Pate.poids_neutre(Vector3(d.r, d.g, d.b)) == 0.0)
