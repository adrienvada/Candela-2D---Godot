extends Node2D

const Charte := preload("res://charte.gd")

## Éclat persistant laissé par une balle sur un mur (DA2.9).
##
## Déposé par `bullet.gd` (`_spawn_wall_effects`) à chaque impact sur la
## géométrie, en enfant direct de l'arène. Même cycle de vie que
## `blood_stain.gd` — persistance sur toute la session, plafond à la source,
## copie pour le viewport J2 — et **ce n'est pas une coïncidence** : les deux
## répondent au même problème, une marque qui reste sur un écran partagé.
##
## ⚠️ **La machinerie est DUPLIQUÉE depuis `blood_stain.gd`, sciemment.**
## L'extraire aujourd'hui obligerait à refondre un système en service dont les
## cas limites sont subtils : l'éviction avant enregistrement, la copie J2
## différée qui ne doit ni compter dans le plafond ni engendrer la sienne, le
## retrait de groupe immédiat parce que `queue_free()` n'agit qu'en fin de
## frame. **Deux occurrences ne font pas encore un motif ; trois, oui.** Le jour
## où un troisième décal apparaît — les douilles, les traces de pas peintes —
## c'est la refonte qu'il faudra faire, pas une troisième copie.
##
## ## Ce qui le distingue du sang
##
## Le sang tombe au sol et raconte une direction : il est tourné dans l'axe du
## tir. **Un éclat sur un mur n'a pas d'axe** — la balle a frappé de face, la
## fissure part en étoile. Sa rotation est donc tirée au sort, ce qui casse en
## prime la répétition : douze éclats sous huit orientations font quatre-vingt-
## seize marques qu'on ne reconnaît pas.

const IMPACTS := "res://assets/decals/"
## Les douze éclats cuits. ⚠️ Quatre des seize panneaux de la planche sont
## absents de cette liste, et ce n'est pas un oubli : c'étaient les brûlures,
## dessinées en sombre sur noir. L'alpha d'un décal vient de sa luminance, donc
## une brûlure noire est un décal transparent. Elles n'ont pas été commitées —
## un bouche-trou qui traîne finit par être pris pour une intention.
const ECLATS := [1, 2, 3, 4, 7, 8, 11, 12, 13, 14, 15, 16]

## Plafond d'éclats simultanés. Plus bas que celui du sang (120) parce qu'un
## impact mural coûte un tir MANQUÉ : dans un duel serré, ils sont bien plus
## nombreux que les touches. `static var` et non `const` : un banc peut
## l'abaisser pour exercer l'éviction sans tirer cent fois dans un mur.
static var MAX_ECLATS := 90

static var _next_order := 0

var _texture: Texture2D = null
var _echelle := 1.0
var _order := 0
var _p2_copy: Node2D = null


## `pos` en coordonnées monde. Rend `false` si aucun éclat n'est chargeable —
## l'appelant renonce alors sans rien poser plutôt que d'ajouter un nœud vide.
func setup(pos: Vector2) -> bool:
	position = pos
	z_index = 1 # Au-dessus du mur (0), sous la killcam (2) et les joueurs (10)

	# Viewport J1 (2) : torche (1) + ambiance personnelle J1 (16). Sans le
	# masque de torche, l'éclat serait visible dans le noir absolu — une marque
	# qui se voit sans être éclairée trahirait la carte gratuitement.
	visibility_layer = 2
	light_mask = 1 | 16

	var n: int = ECLATS[randi() % ECLATS.size()]
	var chemin := IMPACTS + "impact_%d.png" % n
	if not ResourceLoader.exists(chemin):
		push_error("wall_impact : eclat absent — %s " % chemin
			+ "(cuire avec tools/fabrique_decals.gd, puis : "
			+ "godot --headless --path . --import)")
		return false
	_texture = load(chemin)

	# Une planche de 96 px pour un éclat de balle sur une tuile de 35 : il faut
	# le rapetisser franchement, sinon un seul tir marbre un mur entier.
	_echelle = randf_range(0.22, 0.34)
	rotation = randf() * TAU
	queue_redraw()
	return true


func _draw() -> void:
	if _texture == null:
		return
	var t := _texture.get_size() * _echelle
	# `ACIER` et non `HALOGENE` : un éclat est du métal mis à nu, une matière
	# froide que la torche révèle — pas une source chaude.
	draw_texture_rect(_texture, Rect2(-t * 0.5, t), false, Color(Charte.ACIER, 0.85))


func _ready() -> void:
	# La copie J2 repasse par _ready : elle ne doit ni compter dans le plafond
	# ni engendrer sa propre copie — l'original répond pour deux.
	if is_in_group("wall_impact_p2"):
		return

	_order = _next_order
	_next_order += 1

	# Éviction AVANT enregistrement : le total en jeu ne dépasse jamais
	# MAX_ECLATS, même quand une rafale de pompe en dépose plusieurs dans la
	# même frame.
	while get_tree().get_nodes_in_group("wall_impact").size() >= MAX_ECLATS:
		_evict_oldest()
	add_to_group("wall_impact")

	call_deferred("_create_p2_duplicate")


func _evict_oldest() -> void:
	var oldest: Node = null
	for e in get_tree().get_nodes_in_group("wall_impact"):
		if oldest == null or e._order < oldest._order:
			oldest = e
	if oldest == null:
		return
	oldest.release()


## Libère l'éclat ET sa copie J2. Le retrait du groupe est immédiat parce que
## `queue_free()` n'agit qu'en fin de frame : sans lui, N impacts dans la même
## frame évinceraient chacun le même doyen moribond et le total dépasserait le
## plafond de N-1.
func release() -> void:
	remove_from_group("wall_impact")
	if is_instance_valid(_p2_copy):
		_p2_copy.queue_free()
	queue_free()


func _create_p2_duplicate() -> void:
	if is_queued_for_deletion():
		return
	if get_parent() and not is_in_group("wall_impact_p2"):
		var copie := duplicate()
		# `duplicate()` recopie aussi les groupes : la copie doit sortir de
		# "wall_impact", sinon le plafond compterait chaque éclat deux fois.
		copie.remove_from_group("wall_impact")
		copie.add_to_group("wall_impact_p2")
		copie.visibility_layer = 4 # Viewport J2
		copie.light_mask = 1 | 32  # Torche (1) + ambiance personnelle J2 (32)
	# ⚠️ **`duplicate()` NE RECOPIE PAS les variables de script**, et il faut donc
	# reporter l'état à la main. Mesuré le 2026-08-25 : un nœud dont `_drops`
	# contient deux gouttes rend une copie dont `_texture` est NULLE. Seules les
	# propriétés natives suivent — `rotation` passe, `position` passe, rien de ce
	# que le script déclare ne passe.
	#
	# **Le défaut est antérieur au sang peint** : `blood_stain.gd` en souffre depuis toujours — sa copie
	# J2 naissait avec zéro goutte, donc **le joueur 2 n'a jamais vu une seule
	# tache de sang**. Rien ne le signalait — la copie existait, elle était au
	# bon endroit, aux bons masques, et elle dessinait le vide. Une sortie
	# plausible de plus.
		copie.set("_texture", _texture)
		copie.set("_echelle", _echelle)
		copie.queue_redraw()
		get_parent().add_child(copie)
		_p2_copy = copie
