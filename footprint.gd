extends Node2D
class_name Footprint

const Charte := preload("res://charte.gd")

## Empreinte de pas éphémère (module D1).
##
## Une petite semelle sombre posée au sol à chaque pas. Elle n'est PAS unshaded :
## dans le noir absolu le CanvasModulate la rend invisible, et seule une lumière
## (torche, flash de tir) la révèle — exactement le contrat de rendu du décor.
## C'est le cœur du module : la trace est une information de pistage, elle ne
## doit jamais se trahir sans lumière.
##
## Coût pendant la manche : deux Node2D (original + duplicata J2), un polygone
## de 12 sommets dessiné une seule fois, deux Tween. Ni texture, ni lumière,
## ni ombre, ni matériau — indolore sous gl_compatibility.

## Durée de vie totale. Le fondu d'alpha couvre TOUTE la durée : la fraîcheur
## de la trace se lit directement à son intensité (« il vient de passer »).
const FOOTPRINT_TTL := 2.0

## Sombre et semi-transparente : sous la torche elle se lit comme une salissure
## du sol, pas comme un marqueur de HUD.
const SOLE_COLOR := Color(Charte.SOL_A * 0.6, 0.55)
## Le trait qui cerne la semelle — refonte roman graphique, lot 5 (2026-09-11).
## L'empreinte était une ellipse de douze sommets, un aplat sans bord : sous la
## torche, une tache. Une empreinte de planche est DESSINÉE : une semelle et un
## talon cernés d'encre, deux crampons en travers. Même surface, même fondu.
const TRAIT_COLOR := Color(Charte.NOIR, 0.85)
const TRAIT_LARGEUR := 0.8

## Décalage latéral gauche/droite (px). Sans lui les pas s'alignent en pointillé
## de métronome ; avec, la trace évoque une vraie démarche.
const SIDE_OFFSET := 5.0

## La semelle, en pixels : de -5 (talon) à +5,5 (pointe) dans l'axe du regard,
## 2,2 de demi-largeur à l'avant, 1,8 au talon.
const SOLE_HALF_LONG := 5.0
const SOLE_HALF_WIDE := 2.0

## Polygones partagés par toutes les empreintes : construits une seule fois au
## chargement du script — rien n'est recalculé pendant la manche.
static var _sole_points: PackedVector2Array = _build_sole_points()
static var _talon_points: PackedVector2Array = _build_talon_points()

## L'avant du pied : un galbe fermé, plus large à la pointe qu'au cou-de-pied.
static func _build_sole_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-1.2, -1.6), Vector2(1.5, -2.2), Vector2(4.2, -2.0),
		Vector2(5.5, -0.8), Vector2(5.5, 0.8), Vector2(4.2, 2.0),
		Vector2(1.5, 2.2), Vector2(-1.2, 1.6)])

## Le talon, séparé de l'avant par un jour d'un pixel : c'est ce jour qui fait
## lire une chaussure plutôt qu'une tache.
static func _build_talon_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-5.0, -1.4), Vector2(-2.4, -1.8), Vector2(-2.4, 1.8),
		Vector2(-5.0, 1.4)])

## Pose une empreinte dans `arena`. `side` vaut +1 ou -1 (pied droit/gauche) :
## l'alternance appartient à l'appelant (état par joueur), Footprint est sans
## état — c'est ce qui permet le `static func` sans instance pilote.
static func spawn(arena: Node2D, pos: Vector2, rot: float, side: int) -> void:
	if arena == null:
		return
	var fp := Footprint.new()
	# Décalage perpendiculaire au regard : les deux pieds encadrent la
	# trajectoire au lieu de se superposer.
	fp.position = pos + Vector2.from_angle(rot).orthogonal() * (SIDE_OFFSET * float(side))
	fp.rotation = rot
	fp.z_index = 1 # Au-dessus du sol (0), sous les joueurs (10) — comme blood_stain

	# Viewport J1 (2) : torche/décor (1) + ambiance personnelle J1 (16).
	# Le duplicata J2 est créé dans _ready (idiome blood_stain.gd).
	fp.visibility_layer = 2
	fp.light_mask = 1 | 16

	arena.add_child(fp)

func _ready() -> void:
	# Idiome blood_stain.gd:53-62 : un duplicata pour le second viewport, créé
	# en différé (le parent doit être en place). Le groupe marque le duplicata
	# pour qu'il ne se re-duplique pas quand son propre _ready s'exécute.
	call_deferred("_create_p2_duplicate")

	# Chaque nœud — original COMME duplicata, puisque le duplicata rejoue ce
	# _ready — gère son propre fondu puis se libère seul. Aucune référence
	# croisée : si l'arène est reconstruite en plein fondu (rebuild_arena
	# libère tous ses enfants), rien ne pointe vers un nœud mort ; le Tween est
	# lié à son nœud et meurt avec lui.
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FOOTPRINT_TTL)
	tw.tween_callback(queue_free)

func _create_p2_duplicate() -> void:
	if get_parent() and not is_in_group("footprint_p2"):
		var fp_p2 = duplicate()
		fp_p2.add_to_group("footprint_p2")
		fp_p2.visibility_layer = 4 # Viewport J2
		fp_p2.light_mask = 1 | 32  # Torche/décor (1) + ambiance J2 (32)
		get_parent().add_child(fp_p2)

func _draw() -> void:
	# Aucun matériau : le rendu éclairé par défaut fait tout le travail
	# (invisible sous le CanvasModulate noir, révélé par toute Light2D dont le
	# cull mask couvre le décor). _draw n'est appelé qu'une fois : le fondu
	# passe par modulate, qui ne déclenche pas de redraw.
	draw_colored_polygon(_sole_points, SOLE_COLOR)
	draw_colored_polygon(_talon_points, SOLE_COLOR)
	# Le cerne d'encre, puis deux crampons en travers de l'avant.
	var contour := _sole_points.duplicate()
	contour.append(_sole_points[0])
	draw_polyline(contour, TRAIT_COLOR, TRAIT_LARGEUR)
	var talon := _talon_points.duplicate()
	talon.append(_talon_points[0])
	draw_polyline(talon, TRAIT_COLOR, TRAIT_LARGEUR)
	draw_line(Vector2(1.6, -1.6), Vector2(1.6, 1.6), TRAIT_COLOR, TRAIT_LARGEUR)
	draw_line(Vector2(3.4, -1.5), Vector2(3.4, 1.5), TRAIT_COLOR, TRAIT_LARGEUR)
