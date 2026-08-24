class_name MenuVeil
extends ColorRect

## M15 — Le voile d'objectif. Vague M, « la vitrine ».
##
## Un aplat plein cadre qui relit l'écran sous lui et le rend filmé : grain,
## frange chromatique dans les coins, vignette optique.
##
## ## Pourquoi il est le dernier enfant, et seulement du menu
##
## Il doit passer **après** tout ce qu'il filme, donc en dernier dans le panneau.
## Mais il reste dans le panneau, et non au niveau des curseurs : un liseré de
## sélection grainé serait moins net, et la netteté du curseur est de
## l'information, pas de la décoration.
##
## Panneau caché = quad non dessiné = coût nul en match. C'est aussi ce qui
## garantit qu'aucune passe plein écran ne tourne pendant un duel.

const SHADER := preload("res://menu_veil.gdshader")

var _materiau: ShaderMaterial

func _init() -> void:
	name = "VoileObjectif"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# La couleur ne sert à rien — le shader écrit `COLOR` de bout en bout — mais un
	# `ColorRect` transparent ne dessinerait pas de quad, donc pas de passe.
	# Neutre du matériau : ce `ColorRect` ne montre jamais sa propre couleur, le
	# shader peint à sa place. Un blanc y est l'unité d'un produit, pas une teinte.
	color = Color.WHITE
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER
	material = _materiau

func _ready() -> void:
	resized.connect(_mesurer)
	_mesurer()

func set_intensite(valeur: float) -> void:
	var v := clampf(valeur, 0.0, 1.0)
	_materiau.set_shader_parameter("intensite", v)
	# À zéro, le voile relirait l'écran pour le rendre identique : une copie
	# d'écran et trois lectures pour rien. On le retire du dessin.
	visible = v > 0.0

func _mesurer() -> void:
	# La frange se mesure en pixels : sans la taille réelle, elle vaudrait un
	# pixel et demi d'une image imaginaire, donc rien de constant à l'écran.
	_materiau.set_shader_parameter("taille", size)
