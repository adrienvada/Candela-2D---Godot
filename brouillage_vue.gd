extends Node

## L'appareil de brouillage d'UNE vue qui rend.
##
## ## Pourquoi un par vue, et non un pour l'écran
##
## **Option 3, retenue par Adrien le 2026-08-26.** L'autre voie était un seul
## appareil global découpé en deux moitiés, sur le modèle du voile
## (`p1_dazzle` / `p2_dazzle`). Elle coûtait moins cher en apparence — une seule
## photocopie — et l'arbitrage a basculé pour deux raisons :
##
## 1. **La copie ne coûte plus l'écran.** Depuis le passage en
##    `COPY_MODE_RECT`, on ne photocopie que l'ellipse : 0,375 Mpx au lieu de
##    3,69. L'argument de prix s'est évaporé, et le choix est redevenu une
##    question de justesse.
## 2. ⚠️ **Un appareil global doit convertir monde → écran avec la caméra de la
##    BONNE moitié.** Chaque vue a la sienne ; se tromper place le flou sur un
##    joueur qui n'éblouit personne. Un tel défaut ne casse rien, ne lève aucune
##    erreur, et **aucun test automatique ne peut le voir** — il faut deux
##    joueurs et un œil. À l'intérieur d'un viewport, la conversion est celle du
##    viewport : il n'y a plus de mauvais choix possible.
##
## En vue unique (chantier R), les `SubViewport` s'arrêtent et la racine rend :
## `GameState` déplace alors l'appareil dans la racine. Un seul chemin de code,
## un seul appareil par vue **effectivement rendue**.
##
## ## L'ordre des couches, et il décide du rendu
##
## monde (0) → flou (1) → halo (2).
##
## ⚠️ **Le flou DOIT vivre sur sa propre couche.** Posé dans le monde, il lit un
## tampon qu'on écrit dans la même passe et rend n'importe quoi — image à la
## bonne place, luminance à +19 %, contraste à +226 %. Le symptôme fait croire à
## un problème d'espace colorimétrique ; c'est un problème d'ORDRE. Une couche à
## part force le monde à être entièrement dessiné avant la recopie, seul état où
## une lecture d'écran a un sens.
##
## ⚠️ **Et le halo passe APRÈS le flou** : il représente la lumière qui arrive
## dans l'œil, pas une chose du monde qu'on brouillerait.

const Brouillage := preload("res://brouillage.gd")
const Charte := preload("res://charte.gd")
const SHADER_FLOU := preload("res://brouillage_flou.gdshader")

var _couche_flou: CanvasLayer
var _copie: BackBufferCopy
var _flou: ColorRect
var _mat_flou: ShaderMaterial
var _couche_halo: CanvasLayer
var _halo: TextureRect


func _ready() -> void:
	_couche_flou = CanvasLayer.new()
	_couche_flou.name = "CoucheFlou"
	_couche_flou.layer = 1
	add_child(_couche_flou)

	_copie = BackBufferCopy.new()
	_copie.name = "CopieEcran"
	# On photocopie l'ellipse, pas l'écran — voir `banc_brouillage.gd` pour le
	# calcul de l'emprise et `Brouillage.emprise_copie()` pour sa géométrie.
	_copie.copy_mode = BackBufferCopy.COPY_MODE_RECT
	_copie.visible = false
	_couche_flou.add_child(_copie)

	_flou = ColorRect.new()
	_flou.name = "Flou"
	_flou.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flou.visible = false
	_mat_flou = ShaderMaterial.new()
	_mat_flou.shader = SHADER_FLOU
	_flou.material = _mat_flou
	_couche_flou.add_child(_flou)

	_couche_halo = CanvasLayer.new()
	_couche_halo.name = "CoucheHalo"
	_couche_halo.layer = 2
	add_child(_couche_halo)

	_halo = TextureRect.new()
	_halo.name = "Halo"
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.texture = Brouillage.texture_halo(Brouillage.NETTETE_HALO,
		Charte.HALOGENE)
	# ⚠️ **Sans ceci le halo se pose À CÔTÉ de sa cible.** `EXPAND_KEEP_SIZE`,
	# le défaut, fait de la taille de la TEXTURE (512²) la taille minimale du
	# contrôle : toute demande plus petite est relevée à 512 pendant que
	# `position` reste calculée sur le rayon voulu. Le centre dessiné dérive
	# alors d'une centaine de pixels. Défaut vu au banc par Adrien — et il avait
	# survécu à une vérification par l'image, parce que la capture de contrôle
	# plaçait l'émetteur pile au-dessus du canon, le seul endroit où l'erreur
	# horizontale s'annule.
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.visible = false
	_couche_halo.add_child(_halo)


## Rien à montrer : ni flou, ni halo, ni photocopie.
##
## ⚠️ **La photocopie s'éteint AVEC le flou.** Un `BackBufferCopy` visible
## recopie à chaque image, qu'on lise sa copie ou non : le laisser allumé hors
## éblouissement ferait payer l'effet en permanence, alors qu'il ne sert que
## quelques secondes par manche.
func eteindre() -> void:
	if _flou != null:
		_flou.visible = false
	if _copie != null:
		_copie.visible = false
	if _halo != null:
		_halo.visible = false


## Place le flou et le halo pour cette vue, à cette image.
##
## `regardeur` — le joueur devant cet écran, celui qui SUBIT l'éblouissement.
## `emetteur`  — celui dont la lampe éblouit, celui qu'on cache.
##
## ⚠️ **Les deux ne se déduisent pas l'un de l'autre.** L'intensité vient du
## `dazzle_amount` du regardeur ; la POSITION vient de l'émetteur. Les
## intervertir donne un effet cohérent et faux : on se cacherait soi-même en
## éblouissant quelqu'un.
func maj(regardeur: Node2D, emetteur: Node2D) -> void:
	if _flou == null or regardeur == null or emetteur == null:
		eteindre()
		return
	var dazzle := float(regardeur.get("dazzle_amount"))
	var vue := get_viewport()
	if vue == null:
		eteindre()
		return
	var vers_ecran := vue.get_canvas_transform()
	var axe := emetteur.rotation
	var avant := Vector2.RIGHT.rotated(axe)

	# ── LE FLOU — il empêche le cône de trahir son apex.
	var f := Brouillage.flou(dazzle)
	var rayon_flou := float(f["rayon"])
	var force := float(f["force"])
	_flou.visible = rayon_flou > 2.0 and force > 0.001
	_copie.visible = _flou.visible
	if _flou.visible:
		# **Une ELLIPSE couchée sur l'axe du faisceau, pas un disque.** Le
		# rectangle est la boîte de l'ellipse : le masque du shader est un
		# cercle en UV, donc une ellipse à l'écran dès que le rectangle cesse
		# d'être carré. C'est la géométrie qui porte la forme, pas le shader.
		var demi_long := rayon_flou * Brouillage.ALLONGEMENT_FLOU
		var taille := Vector2(demi_long, rayon_flou) * 2.0
		var centre := vers_ecran * emetteur.global_position \
			+ avant * (demi_long * Brouillage.AVANCE_FLOU)
		_flou.size = taille
		_flou.pivot_offset = taille * 0.5
		_flou.rotation = axe
		_flou.position = centre - taille * 0.5
		# L'emprise couvre ce que le shader LIT — le dessin plus le rayon de
		# noyau —, pas ce qu'il peint. Voir `Brouillage.emprise_copie()`.
		var demi_emprise := Brouillage.emprise_copie(taille, axe,
			Brouillage.NOYAU_FLOU + 2.0)
		_copie.rect = Rect2(centre - demi_emprise, demi_emprise * 2.0)
		_mat_flou.set_shader_parameter("rayon_noyau", Brouillage.NOYAU_FLOU)
		_mat_flou.set_shader_parameter("force", force)
		# ⚠️ **Le trou autour de soi : son centre est SA PROPRE position.**
		# Décision d'Adrien — l'éblouissement coûte la lecture du MONDE, jamais
		# celle de sa propre fiche. En vue unique comme en écran scindé, la
		# caméra suit le regardeur, donc ce point est le centre de sa vue ;
		# on le calcule quand même depuis lui, pour que ça reste vrai si la
		# caméra cessait un jour de le suivre.
		var taille_vue := vue.get_visible_rect().size
		var soi := vers_ecran * regardeur.global_position
		_mat_flou.set_shader_parameter("exclusion_centre", soi / taille_vue)
		_mat_flou.set_shader_parameter("exclusion_pres", Brouillage.EXCLUSION_PRES)
		_mat_flou.set_shader_parameter("exclusion_loin", Brouillage.EXCLUSION_LOIN)

	# ── LE HALO — la lumière qui envahit l'œil.
	var h := Brouillage.halo(dazzle)
	var rayon := float(h["rayon"])
	_halo.visible = rayon > 1.0
	if _halo.visible:
		# Étiré sur l'axe pour la même raison que le flou : un halo rond est une
		# forme, et son cœur lumineux en marque le centre — c'est-à-dire le point
		# qu'on veut rendre introuvable. Allongé, le cœur devient une traînée :
		# aussi vif, mais il ne désigne plus.
		var demi_h := rayon * Brouillage.ALLONGEMENT_HALO
		var taille_h := Vector2(demi_h, rayon) * 2.0
		var centre_h := vers_ecran * emetteur.global_position \
			+ avant * (demi_h * Brouillage.AVANCE_HALO)
		_halo.size = taille_h
		_halo.pivot_offset = taille_h * 0.5
		_halo.rotation = axe
		_halo.position = centre_h - taille_h * 0.5
		_halo.modulate.a = float(h["intensite"])
