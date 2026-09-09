class_name CadrePhoto
extends Control

## Le cadre qui fait d'un écran une IMAGE — DA6, socle commun aux trois.
##
## Un filet d'un pixel en retrait des bords, et quatre repères de coupe aux
## angles. C'est tout, et c'est exactement le geste que demande DA6.2 : « le
## cadrer ». Un écran de jeu montre un monde qui continue hors champ ; une image
## affirme un bord. Le filet est cette affirmation, les repères disent qu'elle a
## été décidée par quelqu'un.
##
## **Les repères de coupe ne sont pas un ornement rétro.** Ils sont la seule
## marque qui distingue une capture d'une composition — et le chantier DA existe
## parce qu'« un jeu paraît pro quand chaque pixel semble décidé ». Quatre traits
## de douze pixels coûtent une fonction `_draw()` et signent tout le reste.
##
## ⚠️ **Dessiné, pas `StyleBoxFlat`.** Une bordure de `StyleBox` s'épaissit avec
## la mise à l'échelle du contenu et ne sait pas faire de repères. Surtout, elle
## se pose sur un `Panel` qui peint un fond : ici il ne faut RIEN peindre entre
## les traits — l'image du jeu est dessous, et c'est elle le sujet.

## Le retrait du filet, en fraction de la plus petite dimension. 3,2 % : à
## 1080 px de haut cela fait 35 px, soit la marge d'un tirage. En valeur absolue,
## le même cadre paraîtrait serré en 4K et lâche en 720p.
const RETRAIT := 0.032

## La longueur d'un repère de coupe, même échelle et même raison.
const REPERE := 0.022

## L'écart entre le repère et l'angle du filet — le blanc qui fait qu'un repère
## se lit comme un repère et non comme un angle mal fermé.
const JOUR := 0.006

@export var teinte: Color = Charte.LINE
@export var epaisseur: float = 1.0
## Les repères se taisent quand le cadre est petit : sous cette hauteur, quatre
## traits de six pixels ne sont plus des repères, ce sont des poussières.
@export var reperes_sous: float = 420.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var taille := size
	if taille.x <= 0.0 or taille.y <= 0.0:
		return
	var base: float = minf(taille.x, taille.y)
	var m: float = base * RETRAIT
	var cadre := Rect2(Vector2(m, m), taille - Vector2(m, m) * 2.0)
	if cadre.size.x <= 0.0 or cadre.size.y <= 0.0:
		return
	draw_rect(cadre, teinte, false, epaisseur)

	if taille.y < reperes_sous:
		return
	var l: float = base * REPERE
	var j: float = base * JOUR
	# Quatre angles, deux traits chacun : un horizontal, un vertical, tous deux
	# tournés vers l'EXTÉRIEUR du filet. Vers l'intérieur, ils entreraient dans
	# l'image et se liraient comme une réticule de visée — ce que ce jeu emploie
	# déjà pour tout autre chose.
	for angle in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = cadre.position + cadre.size * angle
		var sx: float = -1.0 if angle.x > 0.5 else 1.0
		var sy: float = -1.0 if angle.y > 0.5 else 1.0
		draw_line(p + Vector2(-sx * j, 0.0), p + Vector2(-sx * (j + l), 0.0),
			teinte, epaisseur)
		draw_line(p + Vector2(0.0, -sy * j), p + Vector2(0.0, -sy * (j + l)),
			teinte, epaisseur)

func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_RESIZED:
		queue_redraw()


## La marge intérieure qu'un cadre impose au contenu, pour une taille donnée.
##
## Le contenu ne doit pas frôler le filet : il se poserait dessus. La marge est
## donc le retrait du filet PLUS une gouttière, et cette fonction est le seul
## endroit qui le sache — trois compositions l'appellent, aucune ne recalcule.
static func marge_pour(taille: Vector2) -> float:
	var base: float = minf(taille.x, taille.y)
	return base * (RETRAIT + 0.028)
