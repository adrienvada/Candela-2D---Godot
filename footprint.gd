extends Node2D
class_name Footprint

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
const SOLE_COLOR := Color(0.06, 0.06, 0.08, 0.55)

## Décalage latéral gauche/droite (px). Sans lui les pas s'alignent en pointillé
## de métronome ; avec, la trace évoque une vraie démarche.
const SIDE_OFFSET := 5.0

## Demi-axes de la semelle (px) : ellipse ~10×4, allongée dans l'axe du regard.
const SOLE_HALF_LONG := 5.0
const SOLE_HALF_WIDE := 2.0
const SOLE_SEGMENTS := 12

## Polygone partagé par toutes les empreintes : construit une seule fois au
## chargement du script — rien n'est recalculé pendant la manche.
static var _sole_points: PackedVector2Array = _build_sole_points()

static func _build_sole_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in SOLE_SEGMENTS:
		var a := TAU * float(i) / float(SOLE_SEGMENTS)
		pts.append(Vector2(cos(a) * SOLE_HALF_LONG, sin(a) * SOLE_HALF_WIDE))
	return pts

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
