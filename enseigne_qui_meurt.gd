class_name EnseigneQuiMeurt
extends Node

## DA7.8 — l'enseigne du menu s'éteint si personne ne joue.
##
## Le wordmark est un **pochoir rétroéclairé** : les lettres sont pleines, et
## c'est la lumière derrière elles qui les dessine. La « bougie » de la fiche
## DA7.8 n'est donc pas un objet à ajouter — **elle est déjà là**, c'est cette
## lumière. Il n'y avait qu'à la laisser mourir.
##
## ## Pourquoi ça vaut plus qu'un clin d'œil
##
## Le jeu tient en une règle : *la seule information est la lumière, et toute
## lumière se paie*. Un menu qu'on abandonne et qui s'éteint tout seul dit cette
## règle **avant la première partie**, sans une ligne de texte. C'est le même
## geste que l'intro (DA6.6), à ceci près qu'ici c'est l'inaction du joueur qui
## le déclenche.
##
## ## Les quatre temps, et pourquoi ils sont dans cet ordre
##
## 1. **La veille** — après `SEUIL_VEILLE`, la lumière commence à *battre* :
##    de courtes chutes irrégulières, comme une flamme dans un courant d'air.
##    Rien n'est encore perdu, mais quelque chose a changé.
## 2. **Le sursaut** — juste avant de mourir, elle remonte au maximum et s'y
##    tient un instant. Une bougie flambe avant de s'éteindre ; sans ce temps,
##    la disparition ressemble à un fondu d'interface.
## 3. **L'extinction** — une longue descente jusqu'à `BRAISE`.
## 4. **Le rallumage** — au premier geste, deux ratés puis la pleine lumière.
##    Une allumette ne prend pas du premier coup.
##
## ⚠️ **Elle ne descend JAMAIS à zéro.** `BRAISE` vaut 0,07 : l'enseigne reste
## trouvable. Un logo qui disparaît complètement ne se lit pas comme une
## intention mais comme une panne — et ce serait l'inverse du but.
##
## ⚠️ **Le mouvement de souris compte comme un geste.** Ne réveiller que sur une
## touche donnerait une enseigne qui meurt pendant qu'on lit le menu, la souris
## à la main.

## Sans geste pendant ce temps, la lumière commence à battre.
const SEUIL_VEILLE := 40.0

## Sans geste pendant ce temps, elle sursaute puis s'éteint.
const SEUIL_AGONIE := 58.0

## Le sursaut : court, sinon il ressemble à un défaut d'affichage.
const DUREE_SURSAUT := 0.55

## La descente. Longue exprès : c'est elle qu'on regarde.
const DUREE_EXTINCTION := 3.4

## Ce qui reste. Jamais zéro — voir l'avertissement en tête.
const BRAISE := 0.07

## Le rallumage, ratés compris.
const DUREE_RALLUMAGE := 0.42

enum Etat { VIVE, VEILLE, SURSAUT, EXTINCTION, BRAISE_SEULE, RALLUMAGE }

var _cible: CanvasItem = null
var _etat: int = Etat.VIVE
var _repos := 0.0        ## temps écoulé sans geste
var _dans_etat := 0.0    ## temps écoulé dans l'état courant
var _luminosite := 1.0
var _depart_transition := 1.0
var _prochain_battement := 0.0
var _creux := 0.0        ## profondeur du battement en cours

func _init() -> void:
	name = "EnseigneQuiMeurt"

func _ready() -> void:
	# ALWAYS : le menu peut être affiché pendant une pause, et une enseigne qui
	# se figerait à mi-extinction serait un défaut visible.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

## Prend en charge une enseigne. Passer `null` la relâche.
##
## ⚠️ Relâcher REND la pleine lumière. Sans ça, une enseigne lâchée en pleine
## extinction — le menu bascule sur un verdict pendant que la lumière descend —
## garderait son alpha à mi-course, et le verdict s'afficherait à moitié éteint
## sans que rien ne l'explique.
func surveiller(cible: CanvasItem) -> void:
	if _cible != null and is_instance_valid(_cible) and _cible != cible:
		_cible.self_modulate.a = 1.0
	_cible = cible
	_luminosite = 1.0
	_etat = Etat.VIVE
	_dans_etat = 0.0
	_reveiller()
	set_process(cible != null)

## Vrai quand la lumière n'est plus au maximum. Pour les bancs et les suites.
func est_entamee() -> bool:
	return _etat != Etat.VIVE

## Le facteur de lumière courant, entre `BRAISE` et 1.
func luminosite() -> float:
	return _luminosite

func _process(delta: float) -> void:
	if _cible == null or not is_instance_valid(_cible):
		set_process(false)
		return
	# Une enseigne cachée ne meurt pas : le compteur ne tourne que sur le menu,
	# là où elle est réellement à l'écran.
	if not _cible.visible:
		_repos = 0.0
		return

	_repos += delta
	_dans_etat += delta

	match _etat:
		Etat.VIVE:
			if _repos >= SEUIL_VEILLE:
				_changer(Etat.VEILLE)
		Etat.VEILLE:
			_battre(delta)
			if _repos >= SEUIL_AGONIE:
				_changer(Etat.SURSAUT)
		Etat.SURSAUT:
			# Pleine lumière, tenue. C'est le temps qui rend la suite lisible.
			_luminosite = 1.0
			if _dans_etat >= DUREE_SURSAUT:
				_depart_transition = _luminosite
				_changer(Etat.EXTINCTION)
		Etat.EXTINCTION:
			var t: float = clampf(_dans_etat / DUREE_EXTINCTION, 0.0, 1.0)
			# Départ lent, chute franche, arrivée douce : une flamme ne décroît
			# pas linéairement, elle tient puis lâche.
			var courbe: float = t * t * (3.0 - 2.0 * t)
			_luminosite = lerpf(_depart_transition, BRAISE, courbe)
			if t >= 1.0:
				_changer(Etat.BRAISE_SEULE)
		Etat.BRAISE_SEULE:
			_luminosite = BRAISE
		Etat.RALLUMAGE:
			_luminosite = _lumiere_de_rallumage(_dans_etat)
			if _dans_etat >= DUREE_RALLUMAGE:
				_luminosite = 1.0
				_changer(Etat.VIVE)

	_cible.self_modulate.a = _luminosite

## Le battement de la veille : des chutes brèves, espacées au hasard. Le hasard
## est ici le sujet — un clignotement régulier serait une diode, pas une flamme.
func _battre(delta: float) -> void:
	_prochain_battement -= delta
	if _prochain_battement <= 0.0:
		_prochain_battement = randf_range(0.35, 1.6)
		_creux = randf_range(0.12, 0.34)
	_creux = maxf(0.0, _creux - delta * 2.6)
	_luminosite = clampf(1.0 - _creux, 0.0, 1.0)

## Deux ratés, puis la pleine lumière. Une allumette ne prend pas du premier coup.
func _lumiere_de_rallumage(t: float) -> float:
	if t < 0.06:
		return 0.85
	if t < 0.12:
		return BRAISE
	if t < 0.19:
		return 0.95
	if t < 0.24:
		return 0.25
	return lerpf(0.25, 1.0, clampf((t - 0.24) / maxf(0.001, DUREE_RALLUMAGE - 0.24), 0.0, 1.0))

func _changer(etat: int) -> void:
	_etat = etat
	_dans_etat = 0.0

## Tout geste réveille l'enseigne.
##
## `_input` et non `_unhandled_input` : les boutons du menu consomment leurs
## événements, et une enseigne qui ne se réveillerait pas quand on clique dans
## le menu serait absurde. On ne marque rien comme traité — on écoute, c'est tout.
func _input(evenement: InputEvent) -> void:
	if _cible == null:
		return
	var geste := evenement is InputEventKey \
		or evenement is InputEventMouseButton \
		or evenement is InputEventMouseMotion \
		or evenement is InputEventJoypadButton \
		or evenement is InputEventJoypadMotion \
		or evenement is InputEventScreenTouch
	if geste:
		_reveiller()

func _reveiller() -> void:
	_repos = 0.0
	if _etat == Etat.VIVE or _etat == Etat.RALLUMAGE:
		return
	# Depuis la veille, la lumière était déjà presque pleine : la rallumer par
	# des ratés serait un effet gratuit. Seule une enseigne réellement éteinte
	# se rallume en trébuchant.
	if _etat == Etat.VEILLE or _etat == Etat.SURSAUT:
		_luminosite = 1.0
		_changer(Etat.VIVE)
		if _cible != null and is_instance_valid(_cible):
			_cible.self_modulate.a = 1.0
		return
	_changer(Etat.RALLUMAGE)
