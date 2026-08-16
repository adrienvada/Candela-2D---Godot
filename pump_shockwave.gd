extends Node2D
class_name PumpShockwave

## D5 — Onde de distorsion d'air du pompe, DERRIÈRE UN DRAPEAU DEBUG.
##
## Au tir du pompe, un anneau de distorsion (~0,25 s) part de la bouche du
## canon : un BackBufferCopy recopie le viewport (même mécanique que le
## KillcamBB de game_state.gd) et un ColorRect relit ce tampon avec un
## déplacement radial (pump_shockwave.gdshader). Le nœud s'anime seul dans
## _process puis se libère : rien ne persiste, rien ne tourne hors de la
## fenêtre de l'effet.
##
## Arbitrage acté (ROADMAP, D5) : l'effet ne s'active QUE si le jeu a été
## lancé avec `--fx-shockwave`. La recopie plein viewport a un coût rendu réel
## sous gl_compatibility ; l'activation par défaut attend la mesure sur le Mac
## d'Adrien (cible : 1 % bas ≥ 120 fps). Le drapeau vit ICI, dans
## spawn_if_enabled : l'appelant n'a pas à le connaître.

## Préchargé en const : un Shader.new() à la volée compile au moment exact du
## premier tir, donc un hoquet visible en pleine manche — même piège que le
## premier mort (voir player.gd et le commentaire de death_flash.gdshader).
const SHADER := preload("res://pump_shockwave.gdshader")

## Durée totale de l'onde. Courte : c'est un accent sur le coup de feu, pas un
## écran de fumée qui masquerait la lecture du duel.
const DURATION := 0.25
## Rayon final de l'anneau, en pixels monde — environ la moitié de la portée
## du pompe (bullet_max_distance = 180) : l'onde « appartient » au cône de tir.
const RADIUS_MAX := 96.0
## Déplacement maximal des pixels au départ (spéc : ~4-6 px), décroît vers 0.
const AMPLITUDE_START := 6.0
## Demi-côté du quad porteur, en pixels. Doit couvrir RADIUS_MAX plus la
## demi-épaisseur d'anneau du shader (ring_half_px = 20), et rester égal à
## l'uniform quad_half_px : c'est lui qui reconvertit l'UV local en distance.
const QUAD_HALF := 128.0

## Verdict du drapeau, lu une seule fois puis figé : OS.get_cmdline_*_args()
## reconstruit un tableau à chaque appel, et la ligne de commande ne change
## jamais en cours de vie du processus. Même idiome que _flag_present /
## --eos-ephemeral dans network_manager.gd, mémorisé en static parce que le
## test est fait à chaque volée de pompe.
static var _flag_checked := false
static var _flag_enabled := false

var _age := 0.0
var _mat: ShaderMaterial

## Unique point d'entrée. Instancie l'onde sous `parent` (l'arène) à
## `global_pos` (bouche du canon) — ou ne fait STRICTEMENT rien si le jeu n'a
## pas été lancé avec --fx-shockwave : hors drapeau le coût se réduit à ce
## test, aucun nœud, aucune copie d'écran.
static func spawn_if_enabled(parent: Node, global_pos: Vector2) -> void:
	if not _fx_requested():
		return
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var wave := PumpShockwave.new()
	# Nom explicite par convention du dépôt. Aucun RPC ne se route par ce nœud
	# (effet purement local, spawné par chaque machine depuis son propre
	# _do_spawn_bullet) : si deux ondes coexistent, le renommage automatique de
	# la seconde est sans enjeu réseau.
	wave.name = "PumpShockwave"
	parent.add_child(wave)
	wave.global_position = global_pos

func _ready() -> void:
	# Au-dessus de tout ce qui compose l'image de jeu (décor 0, sang 1, killcam
	# 2, joueurs/balles/particules 10) : la copie doit contenir la scène
	# COMPLÈTE pour que l'anneau déforme aussi l'éclair de bouche et les plombs.
	# Les chiffres de dégâts (z 100) restent au-dessus, non déformés : de l'UI.
	z_index = 20

	# Même mécanique que le KillcamBB : recopie du viewport entier. La copie
	# s'exécute à la position de l'item dans l'ordre de rendu (c'est ce que le
	# z_index 2 du KillcamBB exploite déjà) ; à z égal, l'ordre de l'arbre fait
	# passer la copie AVANT la lecture du rect ajouté ensuite. Chaque
	# SubViewport exécute sa propre copie : chaque écran relit son tampon.
	var bb := BackBufferCopy.new()
	bb.name = "ShockBB"
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	# Visible des deux viewports (2 = vue J1, 4 = vue J2) : l'onde est un fait
	# du monde, pas une ambiance personnelle. Sur l'écran adverse elle ne
	# déplace que des pixels déjà rendus — dans le noir elle est invisible et ne
	# révèle donc rien que l'éclair de bouche n'ait déjà montré.
	bb.visibility_layer = 2 | 4
	add_child(bb)

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("quad_half_px", QUAD_HALF)
	_apply_uniforms(0.0)

	var rect := ColorRect.new()
	rect.name = "DistortRect"
	rect.position = Vector2(-QUAD_HALF, -QUAD_HALF)
	rect.size = Vector2(QUAD_HALF * 2.0, QUAD_HALF * 2.0)
	# La visée passe par la souris : aucun Control de l'effet ne doit gober un
	# événement (même précaution que la vignette de dégâts de player.gd).
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visibility_layer = 2 | 4
	rect.material = _mat
	add_child(rect)

func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	_apply_uniforms(_age / DURATION)

## t dans [0, 1[. Rayon en décélération (TRANS_QUAD / EASE_OUT, comme les
## fondus du dépôt) : l'onde part vite puis s'essouffle, c'est ce qui vend
## l'impulsion. L'amplitude meurt linéairement : à l'approche de la fin le
## déplacement est déjà nul, la libération ne produit aucun « pop » visible.
func _apply_uniforms(t: float) -> void:
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	_mat.set_shader_parameter("radius_px", RADIUS_MAX * eased)
	_mat.set_shader_parameter("amplitude_px", AMPLITUDE_START * (1.0 - t))

## Drapeau --fx-shockwave, accepté dans les arguments utilisateur (après `--`)
## comme dans les arguments moteur — même tolérance que --eos-ephemeral
## (network_manager.gd). Pas de verrou is_debug_build ici : le verrou d'EOS
## protège l'identité en ligne, un enjeu qui n'existe pas pour un effet
## cosmétique purement local — et Adrien mesurera sur un build export aussi.
static func _fx_requested() -> bool:
	if not _flag_checked:
		_flag_checked = true
		_flag_enabled = "--fx-shockwave" in OS.get_cmdline_user_args() \
			or "--fx-shockwave" in OS.get_cmdline_args()
	return _flag_enabled
