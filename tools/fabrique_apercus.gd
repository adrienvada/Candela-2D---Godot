extends Node

## Cuit les aperçus de mode du cadre de droite — de VRAIES captures du jeu.
##
## **Demande d'Adrien, 2026-08-25.** Le cadre montre le mode tel qu'il est une
## fois lancé : écran scindé pour le duel local, écran seul pour le duel en
## ligne, la cible pour l'entraînement. Pas des illustrations — des captures.
##
## ## Pourquoi une capture plutôt qu'une image générée
##
## **Une illustration d'un mode de jeu est une promesse ; une capture est un
## constat.** Le jour où le jeu change — une arme, un HUD, une palette —,
## l'illustration ment sans prévenir. La capture, elle, se recuit en trente
## secondes et redevient vraie. C'est le même raisonnement que la vignette de
## carte, qui n'est pas dessinée mais rendue.
##
## ## Ce que l'outil met en scène, et pourquoi il triche un peu
##
## Adrien demande « une bonne action, type tir, quelques gouttes de sang ». Un
## match laissé à lui-même ne produit pas ça sur commande : les deux joueurs
## restent immobiles, personne ne tire, et la capture montre deux points dans le
## noir. **On met donc la scène en place** — on rapproche les joueurs, on les
## fait se viser, on tire, on attend l'impact — puis on photographie.
##
## ⚠️ **Ce n'est pas de la mise en scène gratuite : c'est le mode réel, à
## l'instant qui le décrit le mieux.** Rien n'est ajouté qui ne puisse arriver en
## jeu. La seule liberté prise est le CHOIX de l'instant.
##
## Lancer : ./tools/run_apercus.sh
## Les images sortent dans `user://apercus/`, à copier dans `assets/ui/`.

const Commun := preload("res://tools/rendu_commun.gd")

## Laissé au jeu avant de photographier : les lumières s'installent, la balle
## parcourt sa distance, le sang se pose.
const REPOS := 0.9

var _main: Node
var _ui: Node
var _dossier := "user://apercus"
var _n := 0


func _ready() -> void:
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la fabrique d'aperçus ne peut pas travailler ici : ", refus)
		printerr("  Lancer SANS --headless : godot --path . res://tools/fabrique_apercus.tscn")
		_sortir(1)
		return

	print("=== Fabrique des aperçus de mode ===")
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	if _ui == null:
		printerr("✗ l'interface est introuvable")
		_sortir(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))

	await _duel_local()
	await _entrainement()

	print("\n%d image(s) écrite(s) dans :\n  %s" % [
		_n, ProjectSettings.globalize_path(_dossier)])
	print("Copier dans assets/ui/ après les avoir regardées.")
	_sortir(0)


## Le duel : deux joueurs, une torche allumée, un tir, du sang.
##
## Sert DEUX aperçus d'une seule mise en scène — l'écran scindé pour le mode
## local, et la moitié gauche seule pour le duel en ligne. **Le jeu ne rend
## qu'une image ; la différence entre les deux modes est un cadrage**, et la
## produire deux fois à partir de la même scène garantit qu'elles montrent le
## même instant, donc la même vérité.
func _duel_local() -> void:
	# `_on_replay_requested()` est le chemin de « REJOUER » : il lance une manche
	# dans le mode courant, qui est `LOCAL_SPLITSCREEN` au démarrage. C'est le
	# même départ que celui du joueur, et non une mise en place parallèle qui
	# pourrait diverger du jeu réel.
	if not _main.has_method("_on_replay_requested"):
		printerr("  ! le jeu n'expose plus de départ de manche — aperçu de duel sauté")
		return
	_main._on_replay_requested()
	await get_tree().process_frame
	await get_tree().process_frame

	var p1: Node = _main.get("p1")
	var p2: Node = _main.get("p2")
	if p1 == null or p2 == null:
		printerr("  ! les deux joueurs ne sont pas là — aperçus de duel sautés")
		return

	# On les rapproche et on les fait se regarder : à leurs points d'apparition
	# ils sont aux deux bouts de l'arène, hors de portée de leurs torches, et la
	# capture ne montrerait rien de ce que le mode a d'intéressant.
	var centre: Vector2 = (p1.global_position + p2.global_position) * 0.5
	var ecart := Vector2(150.0, -40.0)
	p1.global_position = centre - ecart
	p2.global_position = centre + ecart
	if "flashlight_on" in p1:
		p1.flashlight_on = true
	if "flashlight_on" in p2:
		p2.flashlight_on = true
	_viser(p1, p2)
	_viser(p2, p1)
	await get_tree().process_frame

	# Le tir, et l'impact qui suit. `shoot()` est le chemin réel du jeu : on ne
	# fabrique pas de balle à la main, sans quoi l'image montrerait un projectile
	# que le jeu ne produit pas.
	if p1.has_method("shoot"):
		p1.shoot()
	await _laisser(0.10)
	if p2.has_method("shoot"):
		p2.shoot()

	await _poser("apercu_ecran_scinde")
	print("  · l'écran scindé est pris ; le duel en ligne se recadre à la main")


## L'entraînement : un joueur, une cible.
func _entrainement() -> void:
	if not _main.has_method("_on_training_requested"):
		printerr("  ! l'entraînement n'est plus lançable — aperçu sauté")
		return
	_main._on_training_requested()
	await get_tree().process_frame
	var p1: Node = _main.get("p1")
	if p1 != null and "flashlight_on" in p1:
		p1.flashlight_on = true
	# Le joueur tire sur la cible : un entraînement immobile ne montre pas ce
	# qu'on y fait.
	await _laisser(0.3)
	if p1 != null and p1.has_method("shoot"):
		p1.shoot()
	await _poser("apercu_entrainement")


## Tourne `qui` vers `vers`, par le chemin que le jeu emploie s'il en a un.
func _viser(qui: Node, vers: Node) -> void:
	var d: Vector2 = (vers.global_position - qui.global_position).normalized()
	if "aim_direction" in qui:
		qui.aim_direction = d
	if qui is Node2D:
		(qui as Node2D).rotation = d.angle()


func _laisser(secondes: float) -> void:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame


func _poser(nom: String) -> void:
	await _laisser(REPOS)
	var img: Image = await Commun.capturer(get_tree())
	if img == null:
		# Presque toujours une fenêtre passée à l'arrière-plan, que macOS bride.
		# On le DIT : une fabrique qui écrit une image noire est pire qu'une qui
		# n'écrit rien, parce qu'on intègre l'image noire sans la regarder.
		printerr("  ✗ %s : aucune image (fenêtre au premier plan ?)" % nom)
		return
	img.save_png("%s/%s.png" % [_dossier, nom])
	_n += 1
	print("  · %s" % nom)


## Sortir par la porte du jeu : `main.tscn` instancie les autoloads EOS, et
## quitter sec ré-entre dans `EOS_Platform_Tick()` — segfault documenté.
func _sortir(code: int) -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
		return
	get_tree().quit(code)
