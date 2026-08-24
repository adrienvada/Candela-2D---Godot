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

## ## Les masques peints de DA2.2 et DA2.3
##
## Choisis par Adrien le 2026-08-24 dans `tools/apercu_torche.tscn`, cuits par
## `tools/fabrique_cookies.gd --mode radial`. Les noms de fichiers portent la
## variante retenue : recuire une autre variante et changer ces trois lignes
## suffit à en changer.
const RETRODIFFUSION := "res://assets/halo/retrodiffusion_corona.png"
const AMBIANTE := "res://assets/halo/ambiante_braise.png"
const ECLAT := "res://assets/halo/eclat_poudre.png"

## Les trois images du flash de bouche, dans l'ordre du temps : amorce,
## épanouissement, dissipation. Voir `player.gd::trigger_shoot_visuals`.
const FLASH := [
	"res://assets/flash/flash_1.png",
	"res://assets/flash/flash_2.png",
	"res://assets/flash/flash_3.png",
]

## Les empreintes au sol que chaque masque doit tenir, en unités de monde —
## celles des dégradés qu'ils remplacent. Elles vivent à côté des chemins parce
## qu'un chemin sans son empreinte est un piège : voir `poser()`.
const EMPREINTE_RETRODIFFUSION := 256.0
const EMPREINTE_AMBIANTE := 150.0
## 128² à `texture_scale` 0,5 dans l'ancien code. Les frames sont cuites en 256²,
## donc quatre fois plus de texels sur le même terrain.
const EMPREINTE_FLASH := 64.0

static var _masques: Dictionary = {}


## Un masque peint, chargé une fois.
##
## ⚠️ **Rend `null` et CRIE si le fichier manque, au lieu de se rabattre en
## silence.** Un PNG cuit mais pas encore importé par Godot est invisible à
## `ResourceLoader` : c'est l'état normal d'un asset frais. Le 2026-08-24, le
## banc d'aperçu se rabattait alors sur le dégradé sans rien dire — et comme le
## dégradé est exactement ce que le masque remplace, l'écran était identique.
## Le seul diagnostic possible pour Adrien était « les touches ne marchent pas ».
static func masque(chemin: String) -> Texture2D:
	if _masques.has(chemin):
		return _masques[chemin]
	var t: Texture2D = null
	if ResourceLoader.exists(chemin):
		t = load(chemin)
	else:
		push_error("LightTextures : masque de lumiere absent — %s. "
			% chemin + "Cuire avec tools/fabrique_cookies.gd --mode radial, "
			+ "puis : godot --headless --path . --import")
	_masques[chemin] = t
	return t


## Pose un masque sur une lumière **pour une empreinte au sol donnée**, en unités
## de monde.
##
## ⚠️ **C'est le seul endroit du code qui calcule cette échelle, et c'est
## délibéré.** `PointLight2D.texture_scale` multiplie la taille PROPRE de la
## texture : un masque de 256² posé là où vivait un dégradé de 128² éclaire deux
## fois plus loin, sans qu'aucune valeur de jeu ait bougé. Le défaut s'est
## produit sur DA2.1 et Adrien l'a vu à l'écran avant toute mesure — « ça éclaire
## beaucoup trop loin ». La leçon a été refermée là-bas par
## `WeaponData.echelle_torche()` ; ici elle l'est par cette fonction.
##
## **Personne d'autre ne doit écrire `texture_scale` sur une lumière peinte.**
## `tools/test_lumieres.gd` l'exige.
##
## Le repli sur le dégradé procédural n'est pas muet : `masque()` a déjà crié.
## Il existe parce qu'une texture nulle rendrait un CARRÉ lumineux — pire que
## l'ancien rendu, et sans rapport visible avec la cause.
static func poser(lumiere: PointLight2D, chemin: String, empreinte: float) -> void:
	var t := masque(chemin)
	if t == null:
		lumiere.texture = radial(int(empreinte))
		lumiere.texture_scale = 1.0
		return
	lumiere.texture = t
	lumiere.texture_scale = empreinte / float(t.get_width())

## Dégradé blanc opaque au centre, transparent au bord, de `size` pixels.
##
## ⚠️ **Les `Color(1, 1, 1)` de ce fichier échappent à la règle « jamais de blanc
## pur », et ce n'est pas un oubli.** Ce ne sont pas des couleurs : ce sont des
## MASQUES, multipliés par la teinte de la `Light2D` qui les porte. Y mettre le
## blanc cassé de la charte teinterait une seconde fois une lumière déjà teintée
## — la torche deviendrait deux fois plus chaude que voulu, et personne ne
## saurait dire pourquoi.
##
## La règle porte sur ce que le joueur lit comme une couleur, pas sur un facteur
## neutre. C'est la même distinction que `Color(1, 1, 1, 0)` employé comme
## « transparent » plutôt que comme « blanc ».
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
