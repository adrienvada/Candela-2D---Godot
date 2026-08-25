extends Node2D

const Charte := preload("res://charte.gd")

## Tache de sang permanente au sol.
##
## Déposée par bullet.gd (_spawn_hit_effects) à chaque impact sur un joueur,
## en enfant direct de l'arène. Persistance voulue sur toute la session :
## rebuild_arena() ne purge que ses calques nommés et _do_start_round() ne
## touche pas aux enfants anonymes de l'arène — les taches racontent donc le
## match entier, manche après manche, rematch compris. Seul le retour au menu
## principal les balaie (game_state.gd, _on_main_menu_requested, liste
## ARENA_KEEP).
##
## Cette accumulation sans fin est plafonnée ici, à la source : au-delà de
## MAX_STAINS, la doyenne s'efface AVANT que la nouvelle n'apparaisse. Un
## match qui s'éternise ne peut ainsi pas empiler des centaines de Node2D
## redessinés dans les deux viewports.
##
## Écran partagé : l'original n'est visible que du viewport J1 ; une copie
## aux masques J2 est créée une frame plus tard. Seul l'original vit dans le
## groupe "blood_stain" et garde la référence vers sa copie — le plafond
## compte des taches, pas des nœuds.

## Shader préchargé en const : une compilation à la volée provoquerait un
## hoquet pile au moment d'un impact.
const BLOOD_SHADER := preload("res://blood_shader.gdshader")

## Plafond de taches simultanées (duplicatas J2 non comptés — ils suivent
## leur original). `static var` et non `const` : un banc d'essai peut
## l'abaisser pour exercer l'éviction sans devoir déposer 120 taches.
static var MAX_STAINS := 120

## Rang d'arrivée global, strictement croissant sur toute la session : la
## doyenne est la tache au plus petit rang. Un compteur partagé suffit — nul
## besoin d'horodater, seul l'ordre de dépôt compte. Jamais remis à zéro :
## aucun risque de collision de rang entre deux matchs.
static var _next_order := 0

## ## Les éclaboussures peintes (DA2.8)
##
## Cuites par `tools/fabrique_decals.gd` depuis des planches blanches sur noir :
## la luminance devient l'alpha, la teinte reste au code. Deux fichiers par
## éclaboussure — la forme entière, et son **cœur**, la partie franchement
## opaque.
##
## ⚠️ **Le cœur n'est pas un ornement.** `blood_shader.gdshader` dit de lui-même
## qu'il « préserve le centre noir et les bords rouges » : sa réflexion
## spéculaire multiplie la couleur du sang, donc un aplat uniforme ne lui donne
## rien à réfléchir. Le dessin procédural qu'on remplace produisait ce contraste
## en deux passes — liseré carmin, puis cœur presque noir un pixel et demi plus
## petit. Les deux textures reproduisent exactement ce geste.
const ECLABOUSSURES := ["res://assets/decals/sang_1.png", "res://assets/decals/sang_2.png"]

var _texture: Texture2D = null
var _coeur: Texture2D = null
var _echelle := 1.0
var _drops = []
var color = Color(Charte.CARMIN, 0.9) # Sang séché, sombre
## Rang de cette tache, figé à l'entrée dans l'arbre (voir _next_order).
var _order := 0
## Copie J2, tenue par l'original pour être libérée d'un seul geste.
var _p2_copy: Node2D = null

func setup(base_pos: Vector2, direction: Vector2):
	position = base_pos
	z_index = 1 # Au-dessus du sol (0), sous la killcam (2) et les joueurs (10)
	
	# Viewport J1 (2) : torche (1) + ambiance personnelle J1 (16)
	visibility_layer = 2
	light_mask = 1 | 16
	
	# Rendu « liquide » : la brillance vient du shader, pas du dessin.
	material = ShaderMaterial.new()
	material.shader = BLOOD_SHADER
	
	# DA2.8 — une éclaboussure peinte, tournée dans l'axe du tir.
	#
	# La rotation porte sur le NŒUD : l'éclaboussure est dessinée pointant vers
	# la droite, et `direction` la met dans l'axe de la balle. Une tache de sang
	# raconte d'où le coup venait ; la faire tourner est ce qui distingue une
	# scène de crime d'un semis de losanges.
	_choisir_eclaboussure()
	if _texture != null:
		rotation = direction.angle()
		_echelle = randf_range(0.75, 1.25)
		queue_redraw()
		return

	# Repli procédural. ⚠️ Il CRIE avant d'arriver ici — voir
	# `_choisir_eclaboussure()`. Il existe parce qu'une tache absente serait un
	# tir sans conséquence visible, pire qu'une tache moins belle.
	var num_drops = randi_range(15, 30)
	
	# Flaque centrale au point d'impact
	_drops.append({
		"pos": Vector2.ZERO,
		"radius": randf_range(5.0, 10.0)
	})
	
	# Projections directionnelles
	for i in range(num_drops):
		var dist = randf_range(5.0, 70.0)
		var angle = direction.angle() + randf_range(-PI/5, PI/5)
		
		# Cône plus resserré pour les gouttes qui portent loin
		if dist > 30.0:
			angle = direction.angle() + randf_range(-PI/10, PI/10)
			
		var r = randf_range(1.5, 6.0) * (1.0 - (dist / 80.0))
		
		_drops.append({
			"pos": Vector2(cos(angle), sin(angle)) * dist,
			"radius": max(1.0, r)
		})
	
	queue_redraw()

## Choisit une éclaboussure et son cœur, ou laisse `_texture` à `null`.
##
## Rend la main en criant si les fichiers manquent : un décal cuit mais pas
## encore importé par Godot est invisible à `ResourceLoader`, et c'est l'état
## normal d'un asset frais. Sans ce cri, le jeu retomberait sur les cercles et
## personne ne saurait dire pourquoi les éclaboussures n'ont pas changé.
func _choisir_eclaboussure() -> void:
	var i := randi() % ECLABOUSSURES.size()
	var chemin: String = ECLABOUSSURES[i]
	var coeur := chemin.replace(".png", "_coeur.png")
	if not ResourceLoader.exists(chemin) or not ResourceLoader.exists(coeur):
		push_error("blood_stain : eclaboussure absente — %s " % chemin
			+ "(cuire avec tools/fabrique_decals.gd, puis : "
			+ "godot --headless --path . --import). Repli sur les cercles.")
		return
	_texture = load(chemin)
	_coeur = load(coeur)


func _draw():
	# Liseré carmin, puis cœur presque noir : une goutte est plus sombre en son
	# centre qu'à son bord, où la lumière rasante l'attrape.
	if _texture != null:
		var t := _texture.get_size() * _echelle
		draw_texture_rect(_texture, Rect2(-t * 0.5, t), false,
			Color(Charte.CARMIN, 0.8))
		var c := _coeur.get_size() * _echelle
		draw_texture_rect(_coeur, Rect2(-c * 0.5, c), false,
			Color(Charte.CARMIN * 0.16, 0.95))
		return
	for d in _drops:
		draw_circle(d["pos"], d["radius"], Color(Charte.CARMIN, 0.8))
	for d in _drops:
		draw_circle(d["pos"], max(d["radius"] - 1.5, 0.0),
			Color(Charte.CARMIN * 0.16, 0.95))

func _ready():
	# La copie J2 repasse par _ready : elle ne doit ni compter dans le plafond
	# ni engendrer sa propre copie — l'original répond pour deux.
	if is_in_group("blood_p2"):
		return
	
	_order = _next_order
	_next_order += 1
	
	# Éviction AVANT enregistrement : le total en jeu ne dépasse jamais
	# MAX_STAINS, même quand une volée de pompe dépose plusieurs taches dans
	# la même frame. Boucle par prudence (MAX_STAINS peut avoir été abaissé
	# en cours de route) ; en régime normal, une itération au plus.
	while get_tree().get_nodes_in_group("blood_stain").size() >= MAX_STAINS:
		_evict_oldest()
	add_to_group("blood_stain")
	
	call_deferred("_create_p2_duplicate")

## Évince la doyenne du groupe. Parcours linéaire sans tri : O(MAX_STAINS)
## comparaisons par impact au pire — arbitré négligeable devant le son et les
## particules que le même impact déclenche déjà.
func _evict_oldest() -> void:
	var oldest: Node = null
	for stain in get_tree().get_nodes_in_group("blood_stain"):
		if oldest == null or stain._order < oldest._order:
			oldest = stain
	if oldest == null:
		return # Groupe vide : rien à évincer, la boucle appelante s'arrête
	oldest.release()

## Libère la tache ET sa copie J2. Le retrait du groupe est immédiat parce
## que queue_free() n'agit qu'en fin de frame : sans lui, N impacts dans la
## même frame évinceraient chacun la même doyenne moribonde et le total
## dépasserait le plafond de N-1.
func release() -> void:
	remove_from_group("blood_stain")
	if is_instance_valid(_p2_copy):
		_p2_copy.queue_free()
	queue_free()

func _create_p2_duplicate():
	# Évincée dans la frame même de sa naissance (cas limite) : créer la
	# copie maintenant laisserait un duplicata orphelin, invisible du
	# plafond, qui traînerait jusqu'au retour menu.
	if is_queued_for_deletion():
		return
	if get_parent() and not is_in_group("blood_p2"):
		var stain_p2 = duplicate()
		# duplicate() recopie aussi les groupes : la copie doit sortir de
		# "blood_stain", sinon le plafond compterait chaque tache deux fois
		# et l'éviction pourrait tomber sur un duplicata sans original.
		stain_p2.remove_from_group("blood_stain")
		stain_p2.add_to_group("blood_p2")
		stain_p2.visibility_layer = 4 # Viewport J2
		stain_p2.light_mask = 1 | 32  # Torche (1) + ambiance personnelle J2 (32)
		get_parent().add_child(stain_p2)
		_p2_copy = stain_p2
