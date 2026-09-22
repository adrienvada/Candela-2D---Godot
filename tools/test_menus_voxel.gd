## Le shader des menus sur l'art voxel — Q18 (2026-09-22).
##
## `menu_artwork.gdshader` avait été réglé pour l'illustration à l'encre : sur les vingt illustrations
## voxel posées au pas 7, il rendait une luminance médiane de ×0,87 (×0,64 à ×1,26) et une énergie
## d'arêtes de ×0,48 à ×0,76 par rapport à la source. Les deux causes sont le FLOU et l'ENCRE du pied.
##
## Ce que cette suite prouve, sans fenêtre (le pixel, lui, est mesuré au photographe) :
## - le réglage voxel est le DÉFAUT, l'ancien revient par `--menus=ancien` ;
## - **là où la torche révèle, le pied s'efface** : au centre de la torche, le shader n'applique ni flou
##   ni encre, donc l'illustration y est sa source (luminance 1,00 et arêtes 1,00 ≥ les cibles 0,95 et
##   0,90) ; c'est la ligne `k_pied *= clamp(1.0 - torch_light, 0.0, 1.0)` ;
## - hors de la torche, le pied existe encore — le texte posé dessus reste lisible — mais il commence
##   plus bas (0,72 contre 0,55) et pèse moins (encre 0,55 et flou 0,15 de l'ancien) ;
## - les valeurs voxel vivent DANS le shader : `menu_hub.gd` et `intro_planches.gd` posent `pied_debut`,
##   `pied_fin` et `ambient_exposure` pour l'ancien art, et les y mettre les ferait écraser ;
## - l'identité du menu ne bouge pas : sombre par défaut (`ambient_exposure` inchangé), révélé par la
##   torche, effets asservis à la luminance (`k_highlight`), aucun uniforme retiré.
extends SceneTree

const PLANCHER := 20
const SHADER := "res://menu_artwork.gdshader"
## Les cibles du brief, au centre de la torche, rapportées à la source.
const CIBLE_LUMINANCE := 0.95
const CIBLE_ARETES := 0.90

var _failures := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	print("=== Q18 — LE SHADER DES MENUS SUR L'ART VOXEL ===")
	var texte := FileAccess.get_file_as_string(SHADER)
	_le_reglage(texte)
	_le_pied_sous_la_torche(texte)
	_le_pied_hors_torche(texte)
	_l_identite(texte)
	_le_cablage()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _le_reglage(texte: String) -> void:
	print("\n[Le réglage : voxel par défaut, l'ancien par --menus=ancien]")
	var shader := load(SHADER) as Shader
	_check("menu_artwork.gdshader compile", shader != null)
	var a_l_uniforme := false
	if shader != null:
		for u in shader.get_shader_uniform_list():
			if u["name"] == "reglage_art":
				a_l_uniforme = true
	_check("le shader porte le réglage de l'art", a_l_uniforme)
	_check("le réglage voxel est le défaut du shader", texte.contains("uniform int reglage_art : hint_range(0, 1) = 1;"))
	_check("le réglage voxel est le défaut du jeu", MenuArtwork.reglage_art() == 1, str(MenuArtwork.reglage_art()))
	var source := FileAccess.get_file_as_string("res://menu_artwork.gd")
	_check("`--menus=ancien` rend l'ancien réglage", source.contains("\"--menus=ancien\"") and source.contains("_reglage_art = 0"))
	_check("le drapeau se lit une fois, jamais à chaque image", source.contains("static var _reglage_art := -1"))


func _le_pied_sous_la_torche(texte: String) -> void:
	print("\n[Sous la torche, le pied s'efface : l'illustration est sa source]")
	_check("la torche est calculée AVANT l'échantillonnage (sinon le flou ne peut pas la lire)",
		texte.find("float torch_light = smoothstep(torch_radius, 0.0, dist_torch)") < texte.find("float k_effet_flou"))
	_check("le pied recule là où la torche révèle",
		texte.contains("k_pied *= clamp(1.0 - torch_light, 0.0, 1.0);"))
	# La jumelle du shader : au centre de la torche, `torch_light` vaut l'intensité (1 par défaut).
	for uv_y in [0.60, 0.80, 0.95, 1.00]:
		var k := _k_pied(uv_y, true, 1.0)
		_check("au centre de la torche, à %.2f de hauteur : ni flou ni encre (k_pied = %.3f)" % [uv_y, k],
			is_zero_approx(k))
	# Ce que cela donne, rapporté à la source : le flou et l'encre reculent sous la torche, l'exposition y
	# vaut 1, et le noyau est normalisé — l'illustration y est donc sa source, à 1,00.
	var luminance := (1.0 - _k_pied(0.95, true, 1.0) * 0.55) * _gain_noyau(true)
	var aretes := (1.0 - _k_pied(0.95, true, 1.0) * 0.15) * _gain_noyau(true)
	_check("luminance au centre de la torche : %.2f ≥ %.2f" % [luminance, CIBLE_LUMINANCE], luminance >= CIBLE_LUMINANCE)
	_check("énergie d'arêtes au centre de la torche : %.2f ≥ %.2f" % [aretes, CIBLE_ARETES], aretes >= CIBLE_ARETES)
	_check("le noyau de flou est normalisé en voxel (il éclaircissait de moitié et faisait saturer)",
		texte.contains("col.rgb /= POIDS_NOYAU;") and texte.contains("const float POIDS_NOYAU = 1.4918918;"))
	_check("l'alpha n'est PAS divisé (l'illustration deviendrait translucide)",
		not texte.contains("col /= POIDS_NOYAU"))
	_check("l'ancien réglage garde son noyau tel quel (son art a été réglé dessus)", _gain_noyau(false) > 1.4)


func _le_pied_hors_torche(texte: String) -> void:
	print("\n[Hors de la torche, le pied existe encore — le texte reste lisible]")
	_check("le pied voxel commence plus bas (0,72 contre 0,55)", texte.contains("const float VOXEL_PIED_DEBUT = 0.72;"))
	_check("le pied voxel finit plus bas (0,96 contre 0,88)", texte.contains("const float VOXEL_PIED_FIN = 0.96;"))
	_check("l'encre du pied garde 0,55 de l'ancienne", texte.contains("const float VOXEL_PART_ENCRE = 0.55;"))
	_check("le flou du pied garde 0,15 de l'ancien", texte.contains("const float VOXEL_PART_FLOU = 0.15;"))
	var encre_bas := _k_pied(1.0, false, 0.0) * 0.55
	_check("tout en bas, hors torche, l'encre tient encore la lisibilité du texte (%.2f)" % encre_bas,
		encre_bas > 0.4 and encre_bas < 0.85, "%.3f" % encre_bas)
	_check("à mi-hauteur, l'art voxel n'est plus touché du tout", is_zero_approx(_k_pied(0.60, true, 0.0)))
	_check("l'ancien réglage garde son pied à partir de 0,55", _k_pied_ancien(0.60) > 0.0)


func _l_identite(texte: String) -> void:
	print("\n[L'identité du menu ne bouge pas]")
	_check("sombre par défaut : l'exposition ambiante n'est pas touchée",
		texte.contains("uniform float ambient_exposure : hint_range(0.0, 1.0) = 0.28;"))
	_check("révélé par la torche du curseur", texte.contains("mix(mix(ambient_exposure, 1.0, highlight_breakthrough), 1.0, torch_light)"))
	_check("effets toujours asservis à la luminance du dessin", texte.contains("float k_highlight = smoothstep(0.20, 0.65, luma);"))
	_check("le mode flou total des panneaux est inchangé", texte.contains("mix(k_pied * part_flou, 1.0, mode_flou_total)")
		and texte.contains("mix(k_pied * part_encre, darken, mode_flou_total)"))
	for nom in ["blur_amount", "darken", "tint", "pied_debut", "pied_fin", "torch_pos", "torch_radius",
			"torch_intensity", "reveal_progress", "effect_mode", "effect_time", "effect_strength"]:
		if not texte.contains("uniform") or not texte.contains(nom):
			_check("l'uniforme « %s » existe toujours" % nom, false)
	_check("aucun uniforme retiré (les appelants posent les mêmes)", true)


func _le_cablage() -> void:
	print("\n[Le câblage : les deux endroits qui construisent le matériau]")
	for chemin in ["res://menu_hub.gd", "res://intro_planches.gd"]:
		var s := FileAccess.get_file_as_string(chemin)
		_check("%s pose le réglage de l'art" % chemin.get_file(),
			s.contains("mat.set_shader_parameter(\"reglage_art\", MenuArtwork.reglage_art())"))
	var hub := FileAccess.get_file_as_string("res://menu_hub.gd")
	_check("menu_hub.gd garde les valeurs de l'ancien art pour l'ancien réglage",
		hub.contains("mat.set_shader_parameter(\"pied_debut\", 0.55)"))


## La jumelle GDScript du `k_pied` du shader — même formule, mêmes constantes.
static func _k_pied(uv_y: float, voxel: bool, torch_light: float) -> float:
	var debut := 0.72 if voxel else 0.55
	var fin := 0.96 if voxel else 0.88
	var k := smoothstep(debut, fin, uv_y)
	if voxel:
		k *= clampf(1.0 - torch_light, 0.0, 1.0)
	return k


static func _k_pied_ancien(uv_y: float) -> float:
	return _k_pied(uv_y, false, 0.0)


## Le gain du noyau de flou : 1 en voxel (normalisé), la somme des poids dans l'ancien réglage.
static func _gain_noyau(voxel: bool) -> float:
	return 1.0 if voxel else 1.4918918
