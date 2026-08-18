class_name MenuTracer
extends Control

## M8 — Le départ au tir. Vague M, « la vitrine ».
##
## Presser une entrée **lanceur** — le style plein, le geste qui engage une
## partie — tire réellement : une étoile de bouche au chevron, puis une balle
## traçante qui file dans le sens du glissement d'écran entrant. L'écran suivant
## paraît tracté par la balle.
##
## Réservé au lanceur, l'effet sacralise l'instant décisif : JOUER n'est pas un
## clic, c'est un coup de feu. Le vocabulaire du duel — flash de bouche,
## traçante — est réutilisé tel quel là où le joueur s'engage, et le lien visuel
## balle → glissement donne à la navigation une causalité physique. Les push
## ordinaires gardent leur seul à-coup d'échelle : si tout tirait, plus rien ne
## serait décisif.
##
## ## Un seul nœud, réutilisé
##
## Un tir n'alloue rien : le même Control sert tous les départs, dessine à la
## demande et coupe son traitement dès l'extinction. Une partie ne se lance pas
## assez souvent pour qu'un second tir chevauche le premier ; s'il arrive, le
## nouveau remplace l'ancien, ce qui est aussi ce que le joueur attend.
##
## ## La portée n'est pas celle du glissement
##
## La feuille de route donne « le sens exact du _slide entrant (±32 px) » : ce
## sont les 32 px du glissement, dont la traçante prend le **signe**. Sa course à
## elle est plus longue — une traînée de 32 px vivant 15 centièmes serait
## invisible. C'est l'écran qui glisse de 32 px ; la balle, elle, s'en va.

## Durée de vie de la traçante.
const VOL := 0.15
## Durée de l'étoile de bouche. Deux images à 120 fps : on ne la voit pas, on la
## reçoit.
const BOUCHE := 0.035
## Course de la balle, dans le sens du glissement.
const PORTEE := 210.0
## Demi-longueur du fût qui traîne derrière le cœur.
const FUT := 70.0
## Rayons de l'étoile de bouche.
const BRANCHES := 6
const RAYON_BOUCHE := 26.0

var _intensite: float = 1.0
var _t: float = -1.0
var _origine: Vector2 = Vector2.ZERO
var _sens: float = 1.0
var _teinte: Color = Color.WHITE

func _init() -> void:
	name = "TraceanteMenu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_t = -1.0
		set_process(false)
		queue_redraw()

## Tire depuis `origine` (coordonnées globales), dans le sens `sens` (+1 pour un
## push, -1 pour un retour), à la couleur `teinte`.
func tirer(origine: Vector2, sens: float, teinte: Color) -> void:
	if _intensite <= 0.0:
		return
	_origine = origine
	_sens = signf(sens) if not is_zero_approx(sens) else 1.0
	_teinte = teinte
	_t = 0.0
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _t < 0.0:
		set_process(false)
		return
	_t += delta
	if _t >= VOL:
		_t = -1.0
		set_process(false)
	queue_redraw()

func _draw() -> void:
	if _intensite <= 0.0 or _t < 0.0:
		return
	var vie := clampf(_t / VOL, 0.0, 1.0)
	# Sortie rapide puis décélération : une balle part vite et l'œil ne suit que
	# le début. Linéaire, elle aurait l'air d'un curseur qu'on déplace.
	var avance := PORTEE * (1.0 - pow(1.0 - vie, 3.0))
	var mort := 1.0 - vie

	var tete := _origine + Vector2(avance * _sens, 0.0)
	var queue := tete - Vector2(FUT * _sens, 0.0)

	# Faux HDR : un fût large et sourd teinté à l'accent, puis un cœur blanc
	# étroit par-dessus. C'est la seule façon d'obtenir une impression de
	# sur-luminosité sous `gl_compatibility`, et c'est déjà la technique du laser.
	for i in 4:
		var part := float(i) / 4.0
		var c := _teinte
		c.a = 0.22 * (1.0 - part) * mort * _intensite
		draw_line(queue, tete, c, 1.0 + 7.0 * part)
	draw_line(queue, tete, Color(1.0, 1.0, 1.0, 0.9 * mort * _intensite), 1.0)

	# L'étoile de bouche reste au départ : c'est la marque du coup, pas la balle.
	if _t <= BOUCHE:
		var eclat := 1.0 - _t / BOUCHE
		var blanc := Color(1.0, 1.0, 1.0, 0.85 * eclat * _intensite)
		for i in BRANCHES:
			var angle := TAU * float(i) / float(BRANCHES)
			var rayon := RAYON_BOUCHE * eclat * (0.55 if i % 2 == 1 else 1.0)
			draw_line(_origine, _origine + Vector2.RIGHT.rotated(angle) * rayon,
				blanc, 2.0)
		var halo := _teinte
		halo.a = 0.30 * eclat * _intensite
		draw_circle(_origine, RAYON_BOUCHE * 0.45 * eclat, halo)
