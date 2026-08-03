extends RefCounted
class_name LightTextures

## Dégradés radiaux blancs partagés par toutes les lumières ponctuelles
## éphémères (balles, impacts, particules).
##
## Chaque effet créait auparavant son propre Gradient + GradientTexture2D : une
## rafale de pompe allouait plusieurs dizaines de textures, toutes identiques à
## la teinte près. La teinte passe désormais par `PointLight2D.color`, qui
## multiplie la texture — même rendu, une seule texture par taille.

static var _cache: Dictionary = {}

## Dégradé blanc opaque au centre, transparent au bord, de `size` pixels.
static func radial(size: int) -> GradientTexture2D:
	if _cache.has(size):
		return _cache[size]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	_cache[size] = tex
	return tex

## Variante dont le dégradé s'éteint au bord du carré (fill_to vertical) : c'est
## le profil utilisé par la traînée de balle, plus concentrée.
static func radial_tight(size: int) -> GradientTexture2D:
	var key := -size
	if _cache.has(key):
		return _cache[key]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(0, 0, 0, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size
	tex.height = size
	_cache[key] = tex
	return tex
