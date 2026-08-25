## Banc de dosage du son — S2 (portée) et S3 (occlusion par les murs).
##
## **Pourquoi ce banc existe, et pourquoi il n'est pas optionnel.** Doser un
## réglage sonore en éditant une constante, relançant le jeu et rejouant une
## manche, c'est une itération par minute et une mémoire d'oreille perdue entre
## deux essais — l'oreille ne juge pas dans l'absolu, elle juge des ÉCARTS. Ce
## régime est exactement celui qui a laissé l'éblouissement non fonctionnel
## pendant deux mois sans que personne s'en aperçoive. La règle inscrite en
## feuille de route en découle : **aucun dosage n'est demandé à Adrien sans le
## moyen de l'entendre.**
##
## Ce que le banc reproduit fidèlement, et c'est la seule chose qui compte : il
## appelle `AudioManager` lui-même. Il ne recopie ni le mixage, ni le choix de
## bus, ni la portée. Un banc qui réimplémente ce qu'il mesure fait régler
## quelque chose qui n'est pas le jeu — `apercu_torche` l'a payé le 2026-08-25
## avec un repli qui imitait ce qu'il remplaçait.
##
## Lancer : godot --path . tools/banc_audio.tscn
extends Node2D

const PAS_SOURCE := 240.0
const PERIODE_PAS := 0.42

## L'arène du banc est la carte que le jeu charge par défaut, construite par le
## même `MapGeometry` : mêmes murs, même couche de collision, donc la même
## réponse au rayon d'occlusion que pendant une manche.
var _grille: Vector2i = Vector2i(20, 20)
var _source: Node2D
var _oreille_porteur: Node2D
var _etiquette: Label
var _minuteur: float = 0.0
var _son_courant: String = "footstep"
var _auto: bool = true

## L'A/B : le réglage mis de côté, et celui qu'on écoute. Comparer, c'est
## revenir — un réglage jugé sans son prédécesseur immédiat est jugé contre un
## souvenir.
var _memoire := {}

func _ready() -> void:
	var data: Dictionary = MapData.get_selected()
	if data.is_empty():
		MapData.select_map(MapData.DEFAULT_MAP_ID)
		data = MapData.get_selected()
	_grille = MapCodec.get_grid_size(data)
	MapGeometry.build_collisions(data, self)
	AudioManager.accorder_a_la_carte(_grille, CandelaTileSet.TILE_SIZE)

	var centre := Vector2(_grille) * Vector2(CandelaTileSet.TILE_SIZE) * 0.5

	# Le porteur d'oreille tient lieu de joueur. `poser_oreille` reparente le
	# pool sur SON PARENT : il lui en faut donc un, comme `Players` en jeu.
	_oreille_porteur = Node2D.new()
	_oreille_porteur.name = "PorteurOreille"
	add_child(_oreille_porteur)
	var tete := Node2D.new()
	tete.name = "Tete"
	tete.global_position = centre
	_oreille_porteur.add_child(tete)
	AudioManager.poser_oreille(tete)

	_source = Node2D.new()
	_source.name = "Source"
	_source.global_position = centre + Vector2(300, 0)
	add_child(_source)

	var cam := Camera2D.new()
	cam.global_position = centre
	cam.zoom = Vector2(0.75, 0.75)
	add_child(cam)
	cam.make_current()

	var couche := CanvasLayer.new()
	add_child(couche)
	_etiquette = Label.new()
	_etiquette.position = Vector2(16, 12)
	_etiquette.add_theme_font_size_override("font_size", 15)
	couche.add_child(_etiquette)
	_memoriser()

func _process(delta: float) -> void:
	_deplacer_source(delta)
	if _auto:
		_minuteur -= delta
		if _minuteur <= 0.0:
			_minuteur = PERIODE_PAS
			_jouer()
	queue_redraw()
	_etiquette.text = _texte()

func _deplacer_source(delta: float) -> void:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
	if Input.is_key_pressed(KEY_UP): d.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN): d.y += 1.0
	if d != Vector2.ZERO:
		_source.global_position += d.normalized() * PAS_SOURCE * delta

func _jouer() -> void:
	AudioManager.play_sfx_2d_random_pitch(_son_courant, _source.global_position,
		0.95, 1.05)

## Le dessin dit ce que l'oreille ne peut pas prouver : où est le rayon, et s'il
## touche un mur. Sans lui, un son occulté et un son lointain se ressemblent, et
## on doserait l'un en croyant régler l'autre.
func _draw() -> void:
	var tete := _tete()
	if tete == null:
		return
	var occulte := AudioManager.est_occulte(_source.global_position)
	var couleur := Charte.ROUGE if occulte else Charte.ACIER
	draw_line(_source.global_position, tete.global_position, couleur, 2.0)
	draw_circle(tete.global_position, 9.0, Charte.BLEU)
	draw_circle(_source.global_position, 7.0, couleur)
	var portee: float = AudioManager.portee_absolue(_son_courant,
		AudioManager.portee_carte(), AudioManager.facteur_portee)
	draw_arc(tete.global_position, portee, 0.0, TAU, 96, couleur, 1.0)

func _tete() -> Node2D:
	if _oreille_porteur.get_child_count() == 0:
		return null
	return _oreille_porteur.get_child(0) as Node2D

func _texte() -> String:
	var tete := _tete()
	var dist := 0.0 if tete == null else _source.global_position.distance_to(tete.global_position)
	var portee: float = AudioManager.portee_absolue(_son_courant,
		AudioManager.portee_carte(), AudioManager.facteur_portee)
	var occulte := AudioManager.est_occulte(_source.global_position)
	var lignes := [
		"BANC AUDIO — dosage S2 (portée) et S3 (occlusion)",
		"",
		"  flèches : déplacer la source      W/S : facteur de portée   %.2f" % AudioManager.facteur_portee,
		"  1 pas · 2 tir · 3 impact mur      X/C : courbe              %.2f" % AudioManager.courbe_distance,
		"  ESPACE : jouer une fois           O   : occlusion           %s" % ("ON" if AudioManager.occlusion_active else "OFF"),
		"  A : auto (%s)                      M   : mémoriser  ·  B : comparer" % ("ON" if _auto else "OFF"),
		"",
		"  son                  %s" % _son_courant,
		"  distance             %5.0f px" % dist,
		"  portée de ce son     %5.0f px   (diagonale carte %.0f × relative %.2f × facteur %.2f)" % [
			portee, AudioManager.portee_carte(),
			AudioManager.portee_relative_de(_son_courant), AudioManager.facteur_portee],
		"  atténuation estimée  %s" % _db_estime(dist, portee),
		"  mur entre les deux   %s" % ("OUI — bus SFX_Occlus" if occulte else "non — bus SFX"),
		"  replis hors physique %d" % AudioManager.occlusions_hors_frame,
		"",
		"  mémoire : %s" % _texte_memoire(),
	]
	return "\n".join(lignes)

## L'atténuation que Godot appliquera, en décibels — la même formule que le
## moteur, écrite ici pour être LUE, pas pour être appliquée. C'est un afficheur,
## jamais une source de vérité : le son qui sort reste celui d'`AudioManager`.
func _db_estime(dist: float, portee: float) -> String:
	if dist >= portee:
		return "silence (hors portée)"
	var lineaire: float = pow(1.0 - dist / portee, AudioManager.courbe_distance)
	if lineaire <= 0.0001:
		return "silence"
	return "%.1f dB" % (20.0 * (log(lineaire) / log(10.0)))

func _memoriser() -> void:
	_memoire = {
		"facteur": AudioManager.facteur_portee,
		"courbe": AudioManager.courbe_distance,
		"occlusion": AudioManager.occlusion_active,
	}

func _texte_memoire() -> String:
	if _memoire.is_empty():
		return "(vide)"
	return "facteur %.2f · courbe %.2f · occlusion %s" % [
		_memoire["facteur"], _memoire["courbe"],
		"ON" if _memoire["occlusion"] else "OFF"]

func _comparer() -> void:
	if _memoire.is_empty():
		return
	var f := AudioManager.facteur_portee
	var c := AudioManager.courbe_distance
	var o := AudioManager.occlusion_active
	AudioManager.facteur_portee = _memoire["facteur"]
	AudioManager.courbe_distance = _memoire["courbe"]
	AudioManager.occlusion_active = _memoire["occlusion"]
	_memoire = {"facteur": f, "courbe": c, "occlusion": o}

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_W: AudioManager.facteur_portee = clampf(AudioManager.facteur_portee + 0.05, 0.1, 4.0)
		KEY_S: AudioManager.facteur_portee = clampf(AudioManager.facteur_portee - 0.05, 0.1, 4.0)
		KEY_X: AudioManager.courbe_distance = clampf(AudioManager.courbe_distance - 0.1, 0.2, 6.0)
		KEY_C: AudioManager.courbe_distance = clampf(AudioManager.courbe_distance + 0.1, 0.2, 6.0)
		KEY_O: AudioManager.occlusion_active = not AudioManager.occlusion_active
		KEY_1: _son_courant = "footstep"
		KEY_2: _son_courant = "shoot"
		KEY_3: _son_courant = "wall_impact"
		KEY_A: _auto = not _auto
		KEY_M: _memoriser()
		KEY_B: _comparer()
		KEY_SPACE: _jouer()
		KEY_ESCAPE: get_tree().quit()
