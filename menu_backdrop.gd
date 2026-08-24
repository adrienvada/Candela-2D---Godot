class_name MenuBackdrop
extends Node

## M12 « La brume d'abysse » et M5 « Le bruit de l'œil ». Vague M, « la vitrine ».
##
## Porte le matériau de fond des menus et lui pousse ce qu'il ne peut pas savoir :
## où sont les torches, et de combien le décor doit glisser.
##
## ## Pourquoi un nœud sans rien à dessiner
##
## Les deux effets vivent **dans le shader** ; il n'y a donc aucun `_draw` ici.
## Ce qui reste en GDScript est le seul morceau que le GPU ne peut pas faire :
## l'amortissement de la parallaxe, qui est un état qui se souvient de l'image
## précédente. Le mettre dans `ui.gd` aurait ajouté trois variables d'état à un
## fichier de trois mille lignes pour un effet qui se coupe d'une ligne.
##
## ## Un seul matériau pour les deux fonds
##
## Le menu et la pause partagent le même `ShaderMaterial` : ils ne sont jamais
## visibles ensemble, ils couvrent le même cadre, et deux matériaux auraient
## demandé de pousser chaque uniforme deux fois — donc, un jour, de les pousser
## une fois.
##
## ## Coût nul au repos
##
## Le traitement s'arrête dès que la parallaxe a rejoint sa cible. Le shader,
## lui, ne coûte que lorsqu'un fond est dessiné : panneau caché, quad non
## dessiné, zéro coût en match. C'est la règle commune de la vitrine.

const SHADER := preload("res://menu_backdrop.gdshader")

## Amplitude de la parallaxe, en UV. Quatre pixels sur une largeur de 1280 : on
## ne la voit pas, on la sent — c'est la réponse tactile permanente qui rend un
## menu magnétique, et au-delà elle deviendrait un mouvement, donc une gêne.
const PARALLAXE := 0.003
## Vitesse de rattrapage. Donne un placement complet en ~1,5 s.
const AMORTI := 3.0
## En deçà, la cible est atteinte : plus rien à calculer.
const SEUIL := 0.00002

var _materiau: ShaderMaterial
var _parallaxe := Vector2.ZERO
var _cible := Vector2.ZERO
var _brume: float = 1.0
var _bruit: float = 1.0

func _init() -> void:
	name = "FondDeMenu"
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER
	# Les deux territoires viennent de la charte, une fois pour toutes : ils
	# étaient écrits en dur dans le shader, où la passe de palette ne les a pas
	# vus. Un `.gdshader` est un endroit où une couleur se cache bien — et le
	# fond du menu est justement l'endroit où on la remarque le moins.
	_materiau.set_shader_parameter("territoire_p1",
		Vector3(MenuTheme.P1.r, MenuTheme.P1.g, MenuTheme.P1.b))
	_materiau.set_shader_parameter("territoire_p2",
		Vector3(MenuTheme.P2.r, MenuTheme.P2.g, MenuTheme.P2.b))
	_appliquer()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

## Pose le matériau sur un aplat de fond. Appelé une fois par panneau.
func adopter(rect: ColorRect) -> void:
	if rect != null:
		rect.material = _materiau

func set_brume(valeur: float) -> void:
	_brume = clampf(valeur, 0.0, 1.0)
	if _brume <= 0.0:
		# À zéro, l'aplat statique d'avant l'effet — et la parallaxe s'arrête avec
		# la brume : c'est le décor qui glissait, pas le panneau.
		_parallaxe = Vector2.ZERO
		_cible = Vector2.ZERO
		set_process(false)
	_appliquer()

func set_bruit(valeur: float) -> void:
	_bruit = clampf(valeur, 0.0, 1.0)
	_appliquer()

## Où se trouve la torche d'un joueur, et sur quel cadre. `null` l'éteint.
##
## Le rayon est celui de la torche du curseur (M9) : le bruit de l'œil vit à SA
## lisière, et le déduire ailleurs le décrocherait de la lumière qu'il borde.
func viser(joueur: int, centre: Variant, rayon: float, taille: Vector2) -> void:
	if _materiau == null or taille.x <= 0.0 or taille.y <= 0.0:
		return
	_materiau.set_shader_parameter("ratio", taille.x / taille.y)
	var cle := "torche_p1" if joueur == 0 else "torche_p2"
	if centre == null:
		_materiau.set_shader_parameter(cle, Vector4(0.5, 0.5, 0.0, 0.0))
		if joueur == 0:
			_cible = Vector2.ZERO
			set_process(true)
		return
	var uv := (centre as Vector2) / taille
	_materiau.set_shader_parameter(cle,
		Vector4(uv.x, uv.y, 0.0, rayon / taille.y))
	# Le décor glisse à l'OPPOSÉ du curseur : c'est ce qui donne l'impression que
	# la plaque du menu flotte devant un monde plus lointain. Dans le même sens,
	# tout partirait d'un bloc et le relief disparaîtrait.
	if joueur == 0 and _brume > 0.0:
		_cible = -(uv - Vector2(0.5, 0.5)) * PARALLAXE
		set_process(true)

func _process(delta: float) -> void:
	# Lerp exponentiel : le jeu tourne déplafonné, et un lissage par image
	# donnerait une inertie différente à 60 et à 240 images.
	var k := 1.0 - exp(-AMORTI * delta)
	_parallaxe = _parallaxe.lerp(_cible, k)
	if _parallaxe.distance_squared_to(_cible) < SEUIL:
		_parallaxe = _cible
		set_process(false)
	_materiau.set_shader_parameter("parallaxe", _parallaxe)

func _appliquer() -> void:
	if _materiau == null:
		return
	_materiau.set_shader_parameter("intensite_brume", _brume)
	_materiau.set_shader_parameter("intensite_bruit", _bruit)
	_materiau.set_shader_parameter("parallaxe", _parallaxe)
