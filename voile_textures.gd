extends RefCounted

## Les trois TEXTURES du voile d'éblouissement — la lueur, la traînée, le fantôme.
##
## ⚠️ **Ce fichier existe parce que la production ne les avait PAS.** Elles
## vivaient dans `tools/banc_voile.gd` : le banc les fabriquait, les posait sur le
## shader, et tout s'y voyait. `ui.gd`, lui, ne les fournissait jamais — et
## `hint_default_black` fait qu'un `sampler2D` non fourni rend du NOIR, sans une
## erreur, sans un avertissement. Le jeu affichait donc le lavis SEUL, amputé de
## ses lueurs, de ses flares et de ses fantômes. Adrien, écran scindé en main :
## « où est passé le flare central ? les fantômes ? je ne vois que le flou ».
##
## **La leçon est la règle que ce dépôt a déjà payée trois fois** : une formule
## qui sert à deux endroits vit dans UN fichier, et les deux la lisent. Ici le
## banc fabriquait ce que la production n'avait pas — il montrait donc un effet
## que le jeu ne pouvait pas produire. Un banc ment d'autant mieux qu'il est joli.
##
## ⚠️ **Les trois textures DOIVENT être noires sur tout leur pourtour.** Le shader
## les échantillonne hors de leurs bornes en permanence, et `repeat_disable` étire
## le texel du bord à l'infini : un bord non nul peindrait une bande sur la moitié
## de l'écran. D'où la ceinture — elle a déjà servi une fois.

## Fabriquées UNE fois et gardées : une texture recalculée coûterait un hoquet
## pile au moment où l'effet se déclenche, la faute déjà payée par les shaders
## compilés au premier mort.
static var _cache: Dictionary = {}

## Les trois textures prêtes à poser : clés `lueur`, `flare`, `fantome`.
static func toutes() -> Dictionary:
	if _cache.is_empty():
		_cache = {
			"lueur": _forger_lueur(),
			"flare": _forger_flare(),
			"fantome": _forger_fantome(),
		}
	return _cache


## La CEINTURE : le pourtour d'une texture, forcé à noir.
##
## ⚠️ **Ce n'est pas de la prudence, c'est un garde-fou payé.** Le shader
## échantillonne les trois textures largement hors de leurs bornes, et
## `repeat_disable` y étire le texel du bord. Un seul texel non nul sur un bord
## se répand donc sur une moitié d'écran — c'est arrivé au fantôme, et l'image
## est sortie ENTIÈREMENT BLANCHE, ce qui ne ressemble à aucun défaut de forme et
## n'oriente donc vers rien.
##
## Une formule peut oublier de s'annuler au bord ; deux pixels de ceinture, non.
static func _ceinture(img: Image) -> Image:
	var l := img.get_width()
	var h := img.get_height()
	for x in l:
		for y in [0, 1, h - 2, h - 1]:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in h:
		for x in [0, 1, l - 2, l - 1]:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


## Une lueur ronde : blanche au centre, rigoureusement noire au bord.
##
## Deux termes et non un : un cœur serré `(1−r)^4` pour la brûlure, et un halo
## large `(1−r)^1,4` pour ce qui bave autour. Une seule puissance donne soit une
## bille dure, soit une tache molle — jamais les deux, et c'est les deux qu'on
## voit d'une lampe braquée dans un objectif.
static func _forger_lueur(taille: int = 256) -> ImageTexture:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var c := float(taille - 1) * 0.5
	for y in taille:
		for x in taille:
			var r := Vector2(float(x) - c, float(y) - c).length() / c
			var t := clampf(1.0 - r, 0.0, 1.0)
			var v := pow(t, 4.0) * 0.75 + pow(t, 1.4) * 0.35
			img.set_pixel(x, y, Color(1, 1, 1, 1) * minf(v, 1.0))
	return ImageTexture.create_from_image(_ceinture(img))


## Une traînée horizontale : vive sur l'axe, éteinte partout ailleurs.
##
## ⚠️ **Le profil EN TRAVERS est beaucoup plus creusé que le profil EN
## LONG** — `^6` contre `^1,8`. C'est ce rapport qui fait une traînée plutôt
## qu'une ellipse : l'œil lit une traînée à sa finesse, pas à sa longueur.
##
## L'irrégularité vient d'un peigne de sinus le long de l'axe. Sans elle, la
## traînée est un trait parfait — donc un trait DESSINÉ, pas une aberration
## d'optique. C'est le même défaut de fond que le halo qui était un cercle
## parfait : ce qui est trop régulier se lit comme une forme, et une forme est
## une chose de plus à lire.


## Une traînée horizontale : vive sur l'axe, éteinte partout ailleurs.
##
## ⚠️ **Le profil EN TRAVERS est beaucoup plus creusé que le profil EN
## LONG** — `^6` contre `^1,8`. C'est ce rapport qui fait une traînée plutôt
## qu'une ellipse : l'œil lit une traînée à sa finesse, pas à sa longueur.
##
## L'irrégularité vient d'un peigne de sinus le long de l'axe. Sans elle, la
## traînée est un trait parfait — donc un trait DESSINÉ, pas une aberration
## d'optique. C'est le même défaut de fond que le halo qui était un cercle
## parfait : ce qui est trop régulier se lit comme une forme, et une forme est
## une chose de plus à lire.
static func _forger_flare(larg: int = 512, haut: int = 64) -> ImageTexture:
	var img := Image.create(larg, haut, false, Image.FORMAT_RGBA8)
	for y in haut:
		var v := absf(float(y) / float(haut - 1) * 2.0 - 1.0)
		var travers := pow(clampf(1.0 - v, 0.0, 1.0), 6.0)
		for x in larg:
			var u := float(x) / float(larg - 1) * 2.0 - 1.0
			var long := pow(clampf(1.0 - absf(u), 0.0, 1.0), 1.8)
			var peigne := 0.72 + 0.28 * sin(u * 37.0) * sin(u * 11.3 + 1.7)
			img.set_pixel(x, y, Color(1, 1, 1, 1) * clampf(long * travers * peigne, 0.0, 1.0))
	return ImageTexture.create_from_image(_ceinture(img))


## Un fantôme d'objectif : le disque à IRIS, avec son liseré.
##
## ⚠️ **Il est HEXAGONAL, et ce n'est pas de la coquetterie.** Un fantôme rond
## est une bulle ; un fantôme à six côtés est le diaphragme de l'objectif qu'on
## regarde à travers. C'est le détail qui fait dire « photo » plutôt que
## « effet » — et c'est précisément ce qu'Adrien demande aux fantômes
## d'apporter (2026-08-27).
##
## Trois termes : un intérieur presque plat et faible, un liseré vif au bord, et
## une chute franche au-delà. Le liseré est le plus important des trois : sans
## lui on obtient une tache, et une tache de plus ne fait pas un objectif.


## Un fantôme d'objectif : le disque à IRIS, avec son liseré.
##
## ⚠️ **Il est HEXAGONAL, et ce n'est pas de la coquetterie.** Un fantôme rond
## est une bulle ; un fantôme à six côtés est le diaphragme de l'objectif qu'on
## regarde à travers. C'est le détail qui fait dire « photo » plutôt que
## « effet » — et c'est précisément ce qu'Adrien demande aux fantômes
## d'apporter (2026-08-27).
##
## Trois termes : un intérieur presque plat et faible, un liseré vif au bord, et
## une chute franche au-delà. Le liseré est le plus important des trois : sans
## lui on obtient une tache, et une tache de plus ne fait pas un objectif.
static func _forger_fantome(taille: int = 256) -> ImageTexture:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var c := float(taille - 1) * 0.5
	for y in taille:
		for x in taille:
			var p := Vector2(float(x) - c, float(y) - c) / c
			# Rayon HEXAGONAL : on ramène l'angle dans un sixième de tour et on
			# divise par l'apothème. `r = 1` est alors le bord de l'hexagone,
			# quel que soit l'angle.
			var ang := fposmod(p.angle(), PI / 3.0) - PI / 6.0
			# ⚠️ **Le `/ 0,78` est ce qui garde le pourtour NOIR, et son absence a
			# blanchi tout l'écran.** Sans lui, les côtés plats de l'hexagone
			# tombent pile sur le bord de la texture : le liseré y vaut encore
			# 0,27, et `repeat_disable` étire ce texel à l'infini — quatre
			# fantômes ajoutaient donc 0,27 chacun SUR TOUTE L'IMAGE.
			#
			# Le shader porte l'avertissement en toutes lettres (« les textures
			# DOIVENT être noires sur tout leur pourtour »). Je l'ai écrit pour
			# les deux premières et violé sur la troisième — un avertissement ne
			# protège que ce qu'on pense à relire.
			var r := p.length() * cos(ang) / cos(PI / 6.0) / 0.78
			# ⚠️ **Un fantôme est un disque REMPLI à liseré, pas un fil de fer.**
			# Le premier jet donnait 0,22 d'intérieur contre 0,85 de liseré : à
			# l'écran, une chaîne de contours hexagonaux nets, qui se lit comme
			# du dessin vectoriel et non comme une photo. C'est l'inverse du but,
			# puisque les fantômes n'ont été ajoutés que pour « augmenter le
			# réalisme » (Adrien, 2026-08-27).
			#
			# Trois termes désormais, et l'ordre de leurs poids est le réglage :
			# un intérieur franc, un liseré plus discret que lui, et un léger
			# dégradé qui empêche l'intérieur d'être un aplat — un aplat parfait
			# est aussi peu photographique qu'un contour parfait.
			var interieur := 0.34 * (1.0 - smoothstep(0.72, 1.0, r))
			var degrade := 0.10 * clampf(1.0 - r, 0.0, 1.0)
			var lisere := 0.46 * exp(-pow((r - 0.95) / 0.055, 2.0))
			var v := clampf(interieur + degrade + lisere, 0.0, 1.0) \
				* (1.0 - smoothstep(1.0, 1.08, r))
			img.set_pixel(x, y, Color(1, 1, 1, 1) * v)
	return ImageTexture.create_from_image(_ceinture(img))



## La CEINTURE : le pourtour d'une texture, forcé à noir.
##
## ⚠️ **Ce n'est pas de la prudence, c'est un garde-fou payé.** Le shader
## échantillonne les trois textures largement hors de leurs bornes, et
## `repeat_disable` y étire le texel du bord. Un seul texel non nul sur un bord
## se répand donc sur une moitié d'écran — c'est arrivé au fantôme, et l'image
## est sortie ENTIÈREMENT BLANCHE, ce qui ne ressemble à aucun défaut de forme et
## n'oriente donc vers rien.
##
## Une formule peut oublier de s'annuler au bord ; deux pixels de ceinture, non.
