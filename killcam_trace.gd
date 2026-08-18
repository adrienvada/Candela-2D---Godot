## V6.2 — la trajectoire du tir fatal, tracée en pointillé pendant la killcam.
##
## **La killcam montrait la mort sans l'expliquer.** On voyait tomber, pas d'où
## le coup venait — et dans un jeu où l'on meurt de ce qu'on n'a pas vu, c'est
## précisément l'information qui manque pour apprendre. La ligne complète répond
## à la seule question que se pose la victime : *il était où ?*
##
## Pas de fuite possible : la manche est finie, chacun rejoue **son propre**
## enregistrement, et la trajectoire est celle de la balle qui l'a tué — un fait
## déjà consommé.
##
## En pointillé et non en trait plein : un trait continu se lirait comme une
## balle encore en vol, alors que c'est une trace d'après-coup. Le pointillé dit
## « ceci s'est passé », le trait dirait « ceci se passe ».
extends Node2D

const LONGUEUR_TIRET := 18.0
const ESPACE := 12.0
const EPAISSEUR := 2.0

var depart: Vector2 = Vector2.ZERO
var arrivee: Vector2 = Vector2.ZERO
var teinte: Color = Color(1.0, 0.85, 0.2, 0.75)

## Avancement du tracé, de 0 à 1 — la ligne se dessine vers l'impact plutôt que
## d'apparaître entière. Elle raconte alors le trajet, et non le résultat.
var avancement: float = 0.0

func _process(delta: float) -> void:
	if avancement < 1.0:
		# Temps réel : le tracé ne doit pas ramper pendant le bullet-time, qui
		# étire tout le reste. C'est un commentaire sur la scène, pas un élément
		# de la scène.
		avancement = minf(1.0, avancement + delta / (Engine.time_scale if Engine.time_scale > 0.0 else 1.0) * 1.6)
		queue_redraw()

func _draw() -> void:
	var total := depart.distance_to(arrivee)
	if total <= 0.0:
		return
	var direction := (arrivee - depart) / total
	var visible_jusqua := total * avancement
	var d := 0.0
	while d < visible_jusqua:
		var fin := minf(d + LONGUEUR_TIRET, visible_jusqua)
		draw_line(depart + direction * d, depart + direction * fin, teinte, EPAISSEUR)
		d = fin + ESPACE
	# Le point d'impact, marqué une fois la ligne arrivée : c'est là que la
	# question « il était où ? » trouve sa réponse, pas au départ du trait.
	if avancement >= 1.0:
		draw_circle(arrivee, 5.0, Color(teinte.r, teinte.g, teinte.b, 0.5))
