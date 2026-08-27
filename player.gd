extends CharacterBody2D
class_name Player

const Charte := preload("res://charte.gd")

# Shaders partagés. Préchargés en ressource plutôt que compilés à la volée :
# un Shader.new() dans die() faisait compiler le programme au moment exact du
# premier mort, donc un hoquet visible pile sur l'action décisive.
const SHADER_RIM_LIGHT := preload("res://player_rim_light.gdshader")
const SHADER_ENEMY_LIGHT := preload("res://player_enemy_light.gdshader")
const SHADER_VIGNETTE := preload("res://damage_vignette.gdshader")
const SHADER_DEATH_FLASH := preload("res://death_flash.gdshader")
## Le modèle d'éblouissement, sans dépendance — voir `eblouissement.gd`.
const Eblouissement := preload("res://eblouissement.gd")
## ⚠️ **`brouillage.gd` n'a pas de `class_name`** — c'est un fichier sans
## dépendance, comme `vision.gd` et `eblouissement.gd`, et la maison les
## `preload` plutôt que de les déclarer globalement. Oublier ce `preload` ne
## produit pas une erreur à l'endroit fautif : `ui.gd` cesse de compiler, et
## **quatre suites de menus échouent** en désignant des écrans qui n'ont rien
## fait. Payé le 2026-08-25.
const Brouillage := preload("res://brouillage.gd")

@export var player_id: int = 0

## La couche d'occluder de CE joueur, et celle de l'autre.
##
## Deux couches distinctes — 4 pour J1, 8 pour J2 — parce qu'une torche doit
## ombrer le corps d'en face **sans ombrer le sien**. Une couche commune rendait
## les deux indissociables : on ne pouvait qu'ombrer les deux ou aucun, et le
## jeu avait choisi aucun.
var COUCHE_OCCLUDER_SIENNE: int:
	get: return 4 << player_id
var COUCHE_OCCLUDER_ADVERSE: int:
	get: return 4 << (1 - player_id)
## La couche du TORSE, réservée au rétroéclairage — 16 pour J1, 32 pour J2.
var COUCHE_TORSE: int:
	get: return 16 << player_id
var COUCHE_TORSE_ADVERSE: int:
	get: return 16 << (1 - player_id)
@export var speed: float = 260.0
@export var input_provider: InputProvider

var current_weapon: WeaponData

var hp: float = 100.0
var ghost_hp: float = 100.0

var shoot_cooldown: float = 0.0
var tw_reveal: Tween
var dazzle_amount: float = 0.0

## DA4.4 — la géométrie du bandeau FATAL, **nommée pour être vérifiable**.
##
## Elle vivait dispersée dans `die()` sous forme de quatre littéraux — offset
## `(100, 100)`, pivot `(100, 50)`, plaque `300 × 150`, agrandissement `1,5`.
## Tous calibrés pour le mot « FATAL » seul, tous faux dès qu'une arme signe le
## kill : `FATAL — ARBALÈTE` sortait de l'écran en écran scindé.
##
## ⚠️ **Le défaut a survécu parce que ce calcul n'avait pas de nom.** Aucun banc
## ne pouvait l'atteindre : il fallait tuer un joueur pour l'exécuter. C'est la
## quatrième occurrence du motif consigné le 2026-08-19 — *ce qu'on voit n'a pas
## de nom, donc rien ne le tient*. La correction est autant ce `static func` que
## les rapports qu'il contient.
##
## Rend `mot` (le rect du texte), `marge`, `plaque` et `enfle`.
static func geometrie_du_bandeau(texte: String, fonte: Font,
		corps: int) -> Dictionary:
	var largeur := 1.0
	var hauteur := float(corps)
	if fonte != null:
		largeur = fonte.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1,
			corps).x
		hauteur = fonte.get_height(corps)
	var mot := Vector2(largeur, hauteur)
	# ⚠️ **Une MARGE constante, pas un rapport.** Un cartouche se reconnaît à
	# l'épaisseur de sa bordure : la même plaque autour de « FATAL » et de
	# « FATAL — ARBALÈTE » doit montrer la même marge, pas la même proportion.
	# Les deux coefficients rendent exactement les 300 × 150 d'origine sur le mot
	# seul — la correction ne change rien à ce qui a été validé, elle le fait
	# seulement tenir sur le reste.
	var marge := Vector2(corps * 1.2, corps * 0.45)
	var plaque := mot + marge * 2.0
	# ⚠️ **L'agrandissement se borne sur la PLAQUE, pas sur le mot.**
	#
	# Premier jet : la borne divisait `LARGEUR_UTILE_BANDEAU` par la largeur du
	# TEXTE. Le banc l'a attrapée aussitôt — un libellé très long ressortait à
	# 518 px de chaque côté pour 478 disponibles. La raison est exactement celle
	# du défaut d'origine, un cran plus loin : **on mesurait le mot alors que
	# c'est la plaque qui est dessinée.** Elle est plus large de deux marges, et
	# ces deux marges suffisent à sortir du cadre.
	#
	# 1,5× reste la valeur voulue ; c'est l'ABSENCE de cette borne qui a laissé
	# le défaut invisible jusqu'à ce qu'une arme au nom long le révèle.
	return {
		"mot": mot,
		"marge": marge,
		"plaque": plaque,
		"enfle": minf(1.5, LARGEUR_UTILE_BANDEAU / maxf(plaque.x, 1.0)),
	}


## La largeur d'une vue en écran scindé, le cas le plus étroit du jeu (957 px),
## moins une marge de respiration. Le bandeau ne la dépasse jamais.
const LARGEUR_UTILE_BANDEAU := 900.0

## V2.9 — Distance à l'axe du dernier tir jugé fatal, écrite par la balle qui
## l'a simulé ici, consommée (et remise à -1) par die(). Cosmétique : chez le
## client c'est la simulation locale qui parle, pas l'arbitrage de l'hôte.
var last_fatal_perp: float = -1.0

var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var noise: FastNoiseLite
var shake_time: float = 0.0

var vignette_mat: ShaderMaterial

## V5.4 — respiration de la torche : ±3 % d'énergie au rythme d'un bruit lent.
const TORCH_BREATH_AMP := 0.03
var _torch_breath_t: float = 0.0
## V5.6 — la rétrodiffusion « respire » au pas : bosse brève, résorbée seule.
const BACKSCATTER_STEP_PULSE := 0.35
var _backscatter_pulse: float = 0.0
## V5.5 — cadence d'émission de la poussière du faisceau.
const DUST_INTERVAL := 0.12
var _dust_accum: float = 0.0

var flashlight_on: bool = false
var dead: bool = false

# Numérotation des paquets d'input client→hôte. Le canal est unreliable :
# sans compteur, un paquet en retard réécraserait un état plus récent.
var _input_seq: int = 0
var _last_input_seq: int = -1
## Diagnostic de la remontée des commandes, lu par le panneau F3 de l'hôte.
var inputs_accepted: int = 0
var inputs_rejected: int = 0
## Côté client : commandes émises, et identifiant visé.
var inputs_sent: int = 0
var inputs_target: int = 0

# Rôle de simulation du nœud sur CETTE machine. Le client prédit son propre
# joueur et se contente d'afficher l'autre ; partout ailleurs on simule.
enum NetRole { SIMULATED, PREDICTED, INTERPOLATED }

# Retard d'affichage du joueur distant : il doit couvrir un intervalle de
# réplication (1/30 s) plus la gigue, sinon le tampon se vide et on extrapole.
const INTERP_DELAY := 0.1
const EXTRAPOLATION_MAX := 0.05
const SNAPSHOT_BUFFER_MAX := 32
# Au-delà, l'écart entre deux instantanés ne peut pas être un déplacement :
# c'est une réapparition, qu'il ne faut surtout pas interpoler en glissade.
const TELEPORT_THRESHOLD := 300.0

# Correction de prédiction : sous la zone morte l'écart est invisible, au-delà
# du seuil de resynchronisation la convergence douce serait trop lente.
const PREDICT_DEADZONE := 4.0
const PREDICT_SNAP := 100.0
const PREDICT_CORRECTION_RATE := 12.0
const PREDICT_ROT_SNAP := 1.0
const PREDICT_HISTORY_MAX := 120

# État répliqué hôte→client. Il n'écrit jamais le nœud directement : chaque
# machine décide comment le consommer selon son rôle.
var net_position: Vector2 = Vector2.ZERO
var net_rotation: float = 0.0
var net_flashlight_on: bool = false
## Éblouissement arbitré par l'hôte. Répliqué parce que le client ne le calcule
## pas : voir `game_state._maj_eblouissement`.
var net_dazzle: float = 0.0
# Dernier input client appliqué par l'hôte. Sans lui, le client comparerait sa
# position prédite — en avance d'un aller-retour — à un état plus ancien, et
# se corrigerait en permanence vers le passé.
var net_ack_seq: int = -1

var _net_snapshots: Array[Dictionary] = []
var _predict_history: Dictionary = {}
var _predict_error: Vector2 = Vector2.ZERO
var _last_corrected_seq: int = -1

# La torche est répliquée, pas simulée, côté non-autoritaire : on détecte son
# changement ici pour que le son suive dans tous les modes.
var _torch_audio_state: bool = false

@onready var visual_dim = $VisualDim
@onready var visual_dim_ptr = $VisualDim/DirPointerDim
## ## Les sprites du joueur (DA2.4 + DA2.5, fusionnés)
##
## Choisis par Adrien le 2026-08-25, cuits par `tools/fabrique_sprites.gd` à
## **36 px d'épaules** — exactement le diamètre du `Polygon2D` qu'ils remplacent.
## L'arme dépasse au-delà : c'est une information NOUVELLE, elle ne prend la
## place de rien. L'occluder reste donc un cercle de rayon 18, qui correspond au
## CORPS : un canon fin n'arrête pas une lampe torche, un torse si.
##
## Deux fichiers par arme. Le peint pour la vue du porteur ; ⚠️ **la silhouette
## blanche pour la vue adverse et pour les révélations**, parce que
## `Polygon2D.color` MULTIPLIE la texture et que `Charte.ADVERSAIRE` est
## calibrée en luminance pour l'équité. Multiplier ce gris par un sprite peint
## assombrirait l'adversaire sans qu'aucune décision ne l'ait voulu.
const SPRITES := "res://assets/sprites/"

## ## La densité des sprites (chantier R, étape R6)
##
## **Texels par unité de monde.** Le quad d'un sprite ne se construit PAS à la
## taille de sa texture : il se construit à `taille_texture / DENSITE_SPRITES`.
##
## ⚠️ **Sans cette division, recuire un asset le redimensionne à l'écran.**
## C'est le blocage exact que R6 a rencontré : la décision du 2026-08-25 est de
## recuire toutes les familles à **×2**, parce qu'en vue unique le duel est
## rendu à la résolution de la fenêtre depuis le chantier R — une tuile de 35 px
## tombe à 0,5 texel par pixel en plein écran. Or `_poser_sprite()` bâtissait son
## quad à `texture.get_width()` : un `fusil.png` recuit de 82 à 164 px aurait
## **doublé la taille du joueur**, et personne n'aurait relié ça à une recuisson.
##
## ⚠️ **Et le dégât ne se serait pas arrêté à la taille.** Le roulis de marche
## de DA2.4 vaut `ROULIS_MARCHE` unités de MONDE : un joueur deux fois plus
## grand aurait gardé le même roulis, donc une démarche deux fois plus discrète,
## sans qu'une seule ligne de la marche ait bougé. Un réglage calibré à l'œil
## serait devenu faux à cause d'un paramètre de cuisson.
##
## Le geste est celui que `LightTextures.poser()` applique déjà aux lumières
## (`texture_scale = empreinte / largeur_texture`), et que `test_lumieres.gd`
## verrouille à quatre résolutions. **Là où c'est fait, recuire est gratuit ;
## là où ça ne l'est pas, recuire est un piège.** R6 n'avait plus que les
## sprites à traiter.
##
## ⚠️ **La valeur ne vit PAS ici : elle est dans `Charte.DENSITE_ASSETS`.** Quatre
## familles en dépendent — sprites, sang, éclats de mur, viseur — et la décision
## d'Adrien est « une fois, pour toutes les familles ». Quatre copies finiraient
## par diverger, et chacune paraîtrait juste.


## L'empreinte au sol d'un sprite, en unités de monde, depuis la largeur de sa
## texture. Statique et sans dépendance : c'est ce qui permet à un banc de
## l'éprouver à plusieurs résolutions sans monter un `Player` — et donc de
## prouver que recuire ne déplace rien.
static func empreinte_sprite(largeur_texture: int) -> float:
	return float(largeur_texture) / Charte.DENSITE_ASSETS

## ## Le viseur (DA2.11)
##
## ⚠️ **Ce n'est pas un habillage, c'est un MANQUE qu'on comble.** Le dépôt ne
## contenait aucun viseur et aucun `set_custom_mouse_cursor` : le jeu affichait
## **la flèche du système pendant les matchs**, dans un jeu dont toute la
## proposition est « la seule information est la lumière ». Personne ne l'avait
## relevé parce qu'on ne cherche pas une absence — il n'y a pas de nom à grep.
## Variante `C` — quatre chevrons vers l'intérieur — choisie par Adrien le
## 2026-08-25.
const VISEUR := "res://assets/viseur/viseur.png"

## Distance du viseur devant le joueur, en unités de monde.
##
## ⚠️ **Elle est fixe, et ce n'est pas un choix de confort.**
## `InputProvider.get_aim_direction()` rend une direction NORMALISÉE : la
## distance de la souris est jetée avant d'arriver ici, et c'est voulu — le
## joueur vise un cap, pas un point, et la manette ne peut rien dire d'autre.
## Poser le viseur à distance fixe dans l'axe est donc le seul placement qui
## traite les deux périphériques pareil. Aller chercher la souris ici
## rétablirait dans `player.gd` la connaissance du périphérique que tout le
## patron `InputProvider` existe pour lui retirer.
##
## 110 : devant le canon (28) et bien avant le bord du champ (478).
const DISTANCE_VISEUR := 110.0

## Empreinte du viseur, en unités de MONDE.
##
## ⚠️ **Un `Sprite2D` dessine à la taille de sa TEXTURE.** Le viseur livré ce
## matin n'avait pas de taille explicite : il occupait 48 unités parce que son
## fichier faisait 48 px, et une recuisson à ×2 l'aurait **doublé à l'écran**.
## Défaut trouvé le 2026-08-25 en relisant mon propre travail après que DA4 a
## nommé le motif — *une valeur absolue là où il fallait un rapport* —, qu'elle
## venait de rencontrer pour la quatrième fois en deux jours, dont deux fois sur
## des marges de 9-slice exprimées en pixels de texture.
##
## Le motif est le même que `DENSITE_SPRITES` et que `LightTextures.poser()`,
## et il vaut la peine d'être énoncé une bonne fois : **tout littéral qui
## multiplie ou mesure une dimension d'écran est suspect dans un chantier de
## densité.** Ici l'empreinte est déclarée, et l'échelle s'en déduit.
const EMPREINTE_VISEUR := 48.0

## Teinte du joueur, ramenée vers le blanc. À 0 le sprite prendrait la couleur
## pleine et le dessin serait écrasé ; à 1 les deux joueurs seraient identiques
## et on perdrait l'identification instantanée dont un duel a besoin.
const TEINTE_VERS_BLANC := 0.55


@onready var visual_reveal = $VisualReveal
@onready var visual_reveal_ptr = $VisualReveal/DirPointerReveal
@onready var visual = $VisualColored
@onready var visual_ptr = $VisualColored/DirPointer

var visual_enemy: Polygon2D
var visual_enemy_ptr: Polygon2D
var visual_reveal_enemy: Polygon2D
var visual_reveal_enemy_ptr: Polygon2D
@onready var flashlight = $Flashlight
var ambient_light: PointLight2D
@onready var body_light = $BodyLight
@onready var muzzle_flash = $MuzzleFlash
@onready var muzzle = $Muzzle

var aim_cast: RayCast2D
var aim_line: Line2D
@onready var shoot_sound = $ShootSound
@onready var hit_sound = $HitSound
var step_distance_accumulated: float = 0.0

## ## Le roulis de marche (DA2.4)
##
## Amplitude du balancement du corps, en unités de monde, mesurée au sommet du
## pas. Le corps fait environ 17 unités de large : 1,6 en représente un dixième,
## assez pour se lire à 36 px, trop peu pour qu'on croie à une glissade.
const ROULIS_MARCHE := 1.6
## Vitesse de retour au repos, en unités par seconde. Elle doit rester **au
## large** de ce que la démarche demande, sinon elle l'écrête au lieu de la
## lisser : à l'allure de marche un demi-pas dure ~0,11 s, soit ~0,23 unité par
## tick à 60 Hz ; 30 en autorise 0,50. Ce qu'elle sert vraiment, c'est l'arrêt —
## sans elle, s'immobiliser en plein pas laisserait le corps penché à demeure.
const ROULIS_RETOUR := 30.0
## Roulis courant, lissé. État par joueur, comme `_foot_side`.
var _roulis := 0.0
## D1 — alternance pied gauche/droit des empreintes : +1/-1, inversé à chaque
## pas. État PAR JOUEUR, tenu ici et non dans Footprint.
var _foot_side := 1
## Dernière position vue par le détecteur de pas (voir _physics_process).
var _last_step_pos := Vector2.ZERO


func _ready():
	z_index = 10
	scale = Vector2(1.0, 1.0)
	add_to_group("players")

	# Le joueur est arrêté par les murs (couche 1) ET par les fosses (couche 2).
	# Les balles, elles, ne testent que la couche 1 : on peut donc se tirer
	# dessus d'une rive à l'autre d'un gouffre.
	collision_mask = MapGeometry.PLAYER_MASK

	if not input_provider:
		var default_provider = LocalInputProvider.new()
		default_provider.device_id = player_id
		add_child(default_provider)
		input_provider = default_provider
		
	# Multiplayer Synchronizer
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	var rep_config = SceneReplicationConfig.new()
	rep_config.add_property(NodePath(".:net_position"))
	rep_config.add_property(NodePath(".:net_rotation"))
	rep_config.add_property(NodePath(".:net_flashlight_on"))
	rep_config.add_property(NodePath(".:net_dazzle"))
	rep_config.add_property(NodePath(".:net_ack_seq"))
	# L'hôte est autorité sur les deux joueurs : la réplication va toujours
	# hôte→client, y compris pour les HP.
	rep_config.add_property(NodePath(".:hp"))
	sync.replication_config = rep_config
	# Cadence explicite : c'est l'interpolation qui doit rendre les 30 Hz
	# invisibles, pas le débit réseau.
	sync.replication_interval = 1.0 / 30.0
	sync.synchronized.connect(_on_net_synchronized)
	add_child(sync)
	
	var p_color = (Charte.BLEU if player_id == 0 else Charte.ROUGE) \
		.lerp(Color.WHITE, TEINTE_VERS_BLANC)
	visual.color = p_color
	visual_ptr.color = p_color
	
	visual_dim.color = p_color
	visual_dim.color.a = 0.5
	visual_dim_ptr.color = p_color
	visual_dim_ptr.color.a = 0.5
	
	visual_reveal.color = p_color
	visual_reveal.color.a = 0.0
	visual_reveal_ptr.color = p_color
	visual_reveal_ptr.color.a = 0.0
	
	# ## Le nez de direction — supprimé le 2026-08-26, à la demande d'Adrien
	#
	# `DirPointer` disait où regardait un DISQUE, qui n'a pas d'avant. Depuis
	# DA2.4 le joueur porte un sprite, et un sprite porte une arme : l'arme
	# pointe. Le nez affichait donc la même information une seconde fois — et
	# avec un triangle blanc de dix pixels qui, dans le noir absolu, était la
	# chose la plus lumineuse de l'écran.
	#
	# ⚠️ **Un polygone VIDE, et non `visible = false`.** Le masquage a été essayé
	# d'abord : le nez revenait « par moments » (Adrien, le jour même), parce que
	# les cinq pointeurs traversent plusieurs chemins — révélation, mort,
	# duplication vers les vues ennemies — dont certains reposent la visibilité.
	# **Un garde qu'un autre code peut défaire n'est pas un garde.** Sans
	# sommets, un `Polygon2D` ne dessine rien, quoi qu'on lui demande ensuite.
	#
	# ⚠️ **Les nœuds RESTENT**, et ce n'est pas de la paresse : soixante-cinq
	# références leur assignent couches de visibilité, masques de lumière et
	# matériaux dans cinq fichiers. Les arracher serait un remaniement large pour
	# supprimer un dessin — le rapport risque/bénéfice ne le justifie pas
	# aujourd'hui. Signalé comme dette, pas fait en passant.
	var narrow_nose = PackedVector2Array()
	visual_ptr.polygon = narrow_nose
	visual_dim_ptr.polygon = narrow_nose
	visual_reveal_ptr.polygon = narrow_nose
	
	# Create grayscale versions for the enemy screen
	visual_enemy = visual.duplicate()
	visual_enemy_ptr = visual_ptr.duplicate()
	visual_reveal_enemy = visual_reveal.duplicate()
	visual_reveal_enemy_ptr = visual_reveal_ptr.duplicate()
	
	# La teinte de la lampe qui le révèle, à luminance strictement égale au gris
	# neutre d'avant — c'est la seule dérivée de la charte qui touche à l'équité,
	# et un banc compare les deux luminances.
	var gray = Charte.ADVERSAIRE
	visual_enemy.color = gray
	visual_enemy_ptr.color = gray
	visual_reveal_enemy.color = gray
	visual_reveal_enemy_ptr.color = gray
	visual_reveal_enemy.color.a = 0.0
	visual_reveal_enemy_ptr.color.a = 0.0
	
	visual_enemy.name = "VisualEnemy"
	visual_enemy_ptr.name = "VisualEnemyPtr"
	visual_reveal_enemy.name = "VisualRevealEnemy"
	visual_reveal_enemy_ptr.name = "VisualRevealEnemyPtr"
	
	add_child(visual_enemy)
	add_child(visual_enemy_ptr)
	add_child(visual_reveal_enemy)
	add_child(visual_reveal_enemy_ptr)
	
	# Make the reveal silhouettes unshaded so they glow independently of shadows
	var unshaded_mat = CanvasItemMaterial.new()
	unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	visual_reveal.material = unshaded_mat
	visual_reveal_ptr.material = unshaded_mat
	visual_reveal_enemy.material = unshaded_mat
	visual_reveal_enemy_ptr.material = unshaded_mat
	
	# =========================================================================
	# ARCHITECTURE DES COUCHES DE LUMIÈRE & DE VISIBILITÉ (GODOT 2D)
	# -------------------------------------------------------------------------
	# - VISIBILITY_LAYER : Détermine sur quel Viewport le sprite est dessiné.
	#     * Viewport 1 (Joueur 1) lit la couche 2.
	#     * Viewport 2 (Joueur 2) lit la couche 4.
	#
	# - LIGHT_MASK : Détermine quelle couche de lumière affecte ce sprite.
	#     * Layer 1 (1) : Décor / Environnement (Murs, Sol).
	#     * Layer 2 (2) : Sprites Ennemis (`visual_enemy`, gris).
	#     * Layer 3 (4) : Sprites Joueurs Locaux (`visual`, cyan/magenta).
	# =========================================================================
	visual.light_mask = 4          # Layer 3 : Joueur local (Rétrodiffusion & Torche)
	visual_ptr.light_mask = 4      # Layer 3 : Joueur local
	visual_dim.light_mask = 1
	visual_dim_ptr.light_mask = 1
	visual_reveal.light_mask = 1
	visual_reveal_ptr.light_mask = 1
	visual_enemy.light_mask = 2    # Layer 2 : Sprite Ennemi (Rétrodiffusion, Torche, Sparks, Balles)
	visual_enemy_ptr.light_mask = 2# Layer 2 : Sprite Ennemi
	visual_reveal_enemy.light_mask = 1
	visual_reveal_enemy_ptr.light_mask = 1
	
	if player_id == 0:
		visual.visibility_layer = 2
		visual_ptr.visibility_layer = 2
		visual_reveal.visibility_layer = 2
		visual_reveal_ptr.visibility_layer = 2
		visual_dim.visibility_layer = 2
		visual_dim_ptr.visibility_layer = 2
		
		visual_enemy.visibility_layer = 4
		visual_enemy_ptr.visibility_layer = 4
		visual_reveal_enemy.visibility_layer = 4
		visual_reveal_enemy_ptr.visibility_layer = 4
	else:
		visual.visibility_layer = 4
		visual_ptr.visibility_layer = 4
		visual_reveal.visibility_layer = 4
		visual_reveal_ptr.visibility_layer = 4
		visual_dim.visibility_layer = 4
		visual_dim_ptr.visibility_layer = 4
		
		visual_enemy.visibility_layer = 2
		visual_enemy_ptr.visibility_layer = 2
		visual_reveal_enemy.visibility_layer = 2
		visual_reveal_enemy_ptr.visibility_layer = 2
		
	# In Godot, a Polygon2D MUST have a texture, otherwise UVs are optimized out and always (0,0) in shaders!
	var dummy_img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dummy_img.fill(Color.WHITE)
	var dummy_tex = ImageTexture.create_from_image(dummy_img)
	
	visual.texture = dummy_tex
	visual_ptr.texture = dummy_tex
	visual_enemy.texture = dummy_tex
	visual_enemy_ptr.texture = dummy_tex
		
	# Calculate UVs so the rim light shader works correctly
	_calculate_uvs(visual)
	_calculate_uvs(visual_ptr)
	_calculate_uvs(visual_enemy)
	_calculate_uvs(visual_enemy_ptr)
		
	# Shader to boost lighting on the player's edges so they look like they have volume
	var light_boost_mat = ShaderMaterial.new()
	light_boost_mat.shader = SHADER_RIM_LIGHT

	# Smooth shader for the enemy: renders capped base gray color when illuminated, pitch black in shadow.
	var enemy_mat = ShaderMaterial.new()
	enemy_mat.shader = SHADER_ENEMY_LIGHT
	visual_enemy.material = enemy_mat
	visual_enemy_ptr.material = enemy_mat
	
	visual.material = light_boost_mat
	visual_ptr.material = light_boost_mat
		
	# Setup Camera Shake Noise
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 10.0 # Fast frequency for impact
	
	# Setup Damage Vignette UI
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	var vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Use the correct visibility layer so it only shows on the player's own viewport
	vignette_rect.visibility_layer = 2 if player_id == 0 else 4
	
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = SHADER_VIGNETTE
	vignette_rect.material = vignette_mat
	ui_layer.add_child(vignette_rect)

	# Configuration de la Lampe Torche Principale (Faisceau Avant)
	flashlight.enabled = false
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	# ⚠️ **Un corps bloque la torche de l'AUTRE, jamais la sienne.**
	#
	# Ce masque valait `1 | 2` : les murs, et rien d'autre. L'occluder des deux
	# joueurs vivant sur la couche 4, **aucun corps n'a jamais projeté d'ombre
	# depuis une torche** — relevé à l'écran par Adrien le 2026-08-26, deux fois
	# avant qu'on regarde au bon endroit.
	#
	# Ajouter simplement la couche 4 aurait été pire : les deux joueurs y étant,
	# chacun se serait ombragé lui-même, et on se serait tenu dans sa propre
	# ombre en permanence. C'est le « sans auto-ombrage » que l'ancien
	# commentaire protégeait, et il avait raison de le protéger.
	#
	# D'où **une couche par joueur** — 4 pour J1, 8 pour J2 (`4 << player_id`) —
	# et une torche qui ne regarde que celle de l'autre. Le corps adverse
	# découpe alors le faisceau, ce qui est exactement l'information que le jeu
	# vend : on ne voit pas l'homme, on voit le trou qu'il fait dans la lumière.
	flashlight.shadow_item_cull_mask = 1 | 2 | COUCHE_OCCLUDER_ADVERSE
	flashlight.range_item_cull_mask = 1 | 2 | 4 # Éclaire les murs (1), les ennemis (2) et le joueur local (4)
	flashlight.energy = 2.5
	# La température du faisceau. **Ici et pas dans `equip_weapon()` : elle n'est
	# pas une propriété de l'arme, c'est celle de la lumière.**
	#
	# Et le placement n'est pas qu'une question de rangement. Les fantômes de la
	# killcam ne créent pas leur torche, ils la **dupliquent**
	# (`game_state.gd:_setup_ghosts`) — un `duplicate()` n'emporte que ce qui est
	# déjà posé. Depuis `equip_weapon()`, la couleur ne survivait que parce que
	# `_setup_players()` précède `_setup_ghosts()` et que `_ready` appelle
	# `equip_weapon` avant de rendre la main : trois maillons, et intervertir deux
	# lignes rendait **les torches de killcam blanches**, ce que personne n'aurait
	# vu avant le premier mort. Posée à la construction, elle ne dépend plus de
	# rien. Fil repéré par la session « assets visuels ».
	flashlight.color = Charte.HALOGENE
	flashlight.offset = Vector2.ZERO
	flashlight.position = Vector2(30, 0)

	_monter_viseur()
	
	# Configuration de la Rétrodiffusion de Lentille (Halo autour du corps quand la torche est active)
	body_light.enabled = false
	body_light.shadow_enabled = true # Activé pour que les murs bloquent le rétroéclairage !
	body_light.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	# ⚠️ **Le dos du porteur reste dans le noir, et il lui faut son PROPRE
	# occluder.** Demande d'Adrien du 2026-08-26 : la rétrodiffusion éclairait le
	# joueur tout autour, dos compris, alors qu'un homme qui tient une lampe
	# devant lui se fait de l'ombre à lui-même.
	#
	# ⚠️ **Le grand occluder ne pouvait pas servir.** Il épouse la silhouette
	# depuis ce matin et atteint 24 unités vers l'avant, canon compris, alors que
	# `body_light` est posée à 18 : la lampe se serait retrouvée **à l'intérieur
	# de son propre occluder**, ce qui ne produit ni ombre ni lumière mais du
	# hasard. D'où un second occluder, un simple disque de torse, plus petit que
	# la distance de la lampe.
	#
	# Et la séparation dit quelque chose de juste : **le torse arrête la
	# rétrodiffusion, le canon non.** C'est exactement l'argument que
	# l'occlusion des torches avait tenu avant qu'Adrien le renverse — il reste
	# vrai ici, où la lumière est rasante et l'objet mince.
	body_light.shadow_item_cull_mask = 1 | 2 | COUCHE_TORSE | COUCHE_TORSE_ADVERSE
	body_light.range_item_cull_mask = 2 | 4  # Éclaire le joueur local (4) ET l'écran ennemi (2) quand en ligne de vue
	
	# DA2.2 — le halo peint remplace le dégradé parfait.
	#
	# ⚠️ **La teinte DÉMÉNAGE de la texture vers la lumière.** L'ancien dégradé
	# portait `HALOGENE` dans ses deux arrêts de couleur, et `body_light.color`
	# restait blanc. Un masque peint est blanc par construction — il ne porte que
	# de l'alpha —, donc sans cette ligne la rétrodiffusion virerait au blanc
	# franc, la seule lumière du jeu qui ne viendrait ni d'un feu ni d'un
	# filament. Même correction que celle déjà faite sur `ambient_light`.
	body_light.color = Charte.HALOGENE
	LightTextures.poser(body_light, LightTextures.RETRODIFFUSION,
		LightTextures.EMPREINTE_RETRODIFFUSION)
	body_light.energy = 0.6
	body_light.position = Vector2(18, 0)
	_monter_occluder_de_torse()
	
	if current_weapon:
		equip_weapon(current_weapon)
	else:
		equip_weapon(WeaponData.new())
	
	ambient_light = PointLight2D.new()
	# DA2.2 — masque peint. Sa teinte était déjà sur la lumière et pas dans la
	# texture, donc rien d'autre ne bouge ici.
	LightTextures.poser(ambient_light, LightTextures.AMBIANTE,
		LightTextures.EMPREINTE_AMBIANTE)
	# Sa couleur n'était jamais posée, donc blanche par défaut : la seule lumière
	# du jeu qui ne venait ni d'un feu ni d'un filament, sans que personne l'ait
	# décidé.
	ambient_light.color = Charte.HALOGENE
	ambient_light.energy = 0.8
	ambient_light.shadow_enabled = true
	ambient_light.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	if player_id == 0:
		ambient_light.range_item_cull_mask = 16
	else:
		ambient_light.range_item_cull_mask = 32
	add_child(ambient_light)
	
	# The main occluder is configured as a perfect circle on layer 3 (value 4).
	# This ensures it blocks the main flashlight (mask 1|4) and bullets.
	var pts = PackedVector2Array()
	for i in range(16):
		var ang = (i / 16.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 18.0) # 18.0 is exactly the player radius
		
	if has_node("LightOccluder2D"):
		var main_occ = get_node("LightOccluder2D")
		main_occ.occluder.polygon = pts
		main_occ.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
		# Une couche par joueur : c'est ce qui permet à une torche d'ombrer
		# l'autre corps sans ombrer le sien. Voir `flashlight.shadow_item_cull_mask`.
		main_occ.occluder_light_mask = COUCHE_OCCLUDER_SIENNE
		
	muzzle_flash.enabled = false
	muzzle_flash.shadow_enabled = true
	# Même règle que la torche : le flash de tir découpe le corps d'en face, pas
	# le sien. Il valait `1 | 4`, donc il ombrait le tireur lui-même — invisible
	# tant que les deux joueurs partageaient la couche 4, faux dès qu'ils la
	# quittent.
	muzzle_flash.shadow_item_cull_mask = 1 | COUCHE_OCCLUDER_ADVERSE
	muzzle_flash.range_item_cull_mask = 1 | 2 # Illuminates walls and players
	# Aim line setup
	aim_cast = RayCast2D.new()
	aim_cast.position = Vector2(28, 0)
	aim_cast.target_position = Vector2(2000, 0)
	aim_cast.collision_mask = 1
	add_child(aim_cast)
	aim_cast.add_exception(self)
	
	aim_line = Line2D.new()
	aim_line.width = 2.0
	aim_line.default_color = Color(Charte.HALOGENE, 0.25)
	aim_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	var dash_img = Image.create_empty(16, 2, false, Image.FORMAT_RGBA8)
	dash_img.fill_rect(Rect2(0, 0, 8, 2), Color.WHITE)
	dash_img.fill_rect(Rect2(8, 0, 8, 2), Color.TRANSPARENT)
	var dash_tex = ImageTexture.create_from_image(dash_img)
	
	aim_line.texture = dash_tex
	aim_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	add_child(aim_line)
	
	if player_id == 0:
		aim_line.visibility_layer = 2
	else:
		aim_line.visibility_layer = 4
	# DA2.3 — trois images peintes au lieu du disque. On pose la première ici ;
	# `trigger_shoot_visuals()` déroule les deux autres.
	LightTextures.poser(muzzle_flash, LightTextures.FLASH[0],
		LightTextures.EMPREINTE_FLASH)
	muzzle_flash.color = Charte.AMBRE
	muzzle_flash.offset = Vector2.ZERO

## Pose le sprite de l'arme sur les cinq vues du joueur.
##
## Le `Polygon2D` devient un QUAD à la taille du sprite : on garde ainsi tout le
## câblage existant — masques de lumière, couches de visibilité, alphas,
## matériau non éclairé des révélations — sans y toucher une ligne. `color`
## continue de faire ce qu'elle faisait, elle multiplie simplement une texture
## qui n'est plus un pixel blanc.
##
## Rend `false` et CRIE si le sprite manque : un repli muet redonnerait le
## disque, c'est-à-dire exactement ce qu'on remplace, et le seul diagnostic
## possible depuis l'écran serait « ça n'a pas changé ».
func _poser_sprite(slug: String) -> bool:
	var peint := SPRITES + slug + ".png"
	var silhouette := SPRITES + slug + "_silhouette.png"
	if not ResourceLoader.exists(peint) or not ResourceLoader.exists(silhouette):
		push_error("player : sprite absent — %s (cuire avec tools/fabrique_sprites.gd, "
			% peint + "puis : godot --headless --path . --import)")
		return false
	var t_peint: Texture2D = load(peint)
	var t_sil: Texture2D = load(silhouette)
	# ⚠️ Passe par `empreinte_sprite()` — voir `DENSITE_SPRITES`. Bâtir le quad
	# sur `get_width()` brut est le piège que R6 a levé : la recuisson d'un asset
	# redimensionnerait le joueur.
	var demi := Vector2(empreinte_sprite(t_peint.get_width()),
		empreinte_sprite(t_peint.get_height())) * 0.5
	var quad := PackedVector2Array([
		Vector2(-demi.x, -demi.y), Vector2(demi.x, -demi.y),
		Vector2(demi.x, demi.y), Vector2(-demi.x, demi.y)])

	for paire in [[visual, t_peint], [visual_dim, t_peint], [visual_reveal, t_sil],
			[visual_enemy, t_sil], [visual_reveal_enemy, t_sil]]:
		var poly: Polygon2D = paire[0]
		if poly == null:
			continue
		poly.polygon = quad
		poly.texture = paire[1]
		_calculate_uvs(poly)

	# Le nez de direction ne se cache pas ici : il n'a plus de sommets du tout.
	# Voir `narrow_nose` — un masquage se défait, un polygone vide non.
	_accorder_occluder_a_la_silhouette(t_sil)
	return true


## Le disque de torse qui arrête la rétrodiffusion.
##
## ⚠️ **Rayon 12, et le nombre n'est pas libre.** `body_light` est posée à 18
## unités devant le centre : l'occluder doit être STRICTEMENT plus petit, sinon
## la lampe tombe dedans et l'ombre devient indéfinie. 12 laisse six unités de
## marge et correspond à peu près au torse — la partie du corps qui, vue de
## dessus, arrête vraiment une lumière rasante.
##
## Il est monté à part du grand occluder parce qu'ils ne servent pas la même
## lumière : celui-ci ne doit JAMAIS voir une torche, sans quoi chaque joueur se
## tiendrait dans sa propre ombre.
func _monter_occluder_de_torse() -> void:
	if has_node("OccluderTorse"):
		return
	var occ := LightOccluder2D.new()
	occ.name = "OccluderTorse"
	var forme := OccluderPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var ang := (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 12.0)
	forme.polygon = pts
	forme.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = forme
	occ.occluder_light_mask = COUCHE_TORSE
	add_child(occ)


## L'ombre du joueur épouse sa silhouette, au lieu d'être un rond.
##
## ⚠️ **C'était un cercle de rayon 18, et c'était un choix — qu'Adrien a
## renversé.** Le commentaire d'origine le défendait ainsi : « un canon fin
## n'arrête pas une lampe torche, un torse si ». L'argument se tient en optique,
## mais il produit à l'écran une ombre ronde derrière un personnage qui n'est pas
## rond, et le mensonge se voit — verdict d'Adrien le 2026-08-26 : « c'est nul,
## l'occlusion ne se fait pas selon le sprite ».
##
## **La silhouette existe déjà** : `<arme>_silhouette.png` est cuite par
## `fabrique_sprites.gd` pour les vues « révélation ». On la relit ici plutôt que
## d'inventer une seconde vérité de forme.
##
## ⚠️ **Échantillonnage RADIAL, pas de tracé de contour.** Un vrai contour
## (marching squares) rendrait les concavités — l'espace entre les bras — mais
## il demande de gérer les trous, les îlots et les diagonales ambiguës, pour une
## ombre de trente pixels dans le noir. Trente-deux rayons depuis le centre
## donnent une étoile qui épouse le corps ET le canon, ne peut pas produire de
## polygone dégénéré, et se calcule une fois par changement d'arme.
func _accorder_occluder_a_la_silhouette(sil: Texture2D) -> void:
	if not has_node("LightOccluder2D") or sil == null:
		return
	var img := sil.get_image()
	if img == null:
		return
	var l := img.get_width()
	var h := img.get_height()
	var cx := float(l) * 0.5
	var cy := float(h) * 0.5
	# Du pixel vers le monde : le quad fait `empreinte_sprite(l)` de large.
	var vers_monde := empreinte_sprite(l) / float(l)
	var pts := PackedVector2Array()
	const RAYONS := 32
	for i in RAYONS:
		var ang := (float(i) / float(RAYONS)) * TAU
		var dir := Vector2(cos(ang), sin(ang))
		# On part du bord et on rentre : le premier pixel opaque rencontré est
		# le plus lointain dans cette direction.
		var portee := maxf(cx, cy) * 1.5
		var trouve := 0.0
		var r := portee
		while r > 1.0:
			var px := int(cx + dir.x * r)
			var py := int(cy + dir.y * r)
			if px >= 0 and px < l and py >= 0 and py < h \
					and img.get_pixel(px, py).a > 0.35:
				trouve = r
				break
			r -= 1.0
		# ⚠️ **Le plancher ne sert QU'À éviter un polygone dégénéré.**
		#
		# Il valait d'abord 18 — le rayon de l'ancien cercle — « par prudence ».
		# Mesuré ensuite : la silhouette du pistolet va de **5,8 à 24,8** unités
		# selon la direction, moyenne 12,8, et **28 directions sur 32 tombaient
		# sous 18**. Le plancher n'était donc pas une sécurité, c'était la forme :
		# il rendait exactement le cercle qu'on voulait remplacer, avec une petite
		# bosse devant. Adrien l'a vu à l'écran avant que je le mesure — « cela
		# fait toujours un cercle, non ? ».
		#
		# **Une prudence qui recouvre la donnée n'est plus une prudence.** Trois
		# unités suffisent à garantir un sommet non nul, et ne dominent jamais.
		pts.append(dir * maxf(trouve, 3.0 / vers_monde) * vers_monde)
	var occ := get_node("LightOccluder2D")
	occ.occluder.polygon = pts
	occ.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder_light_mask = COUCHE_OCCLUDER_SIENNE


## DA2.11 — le viseur, enfant du joueur donc porté par sa rotation.
##
## Il n'a besoin d'aucun code de suivi : `rotation` suit déjà la visée, et un
## enfant posé en `(DISTANCE_VISEUR, 0)` est par construction dans l'axe.
##
## ⚠️ **`visibility_layer` explicite, sinon il s'affiche DANS LES DEUX VUES.**
## L'écran partagé est permanent, y compris en ligne : 2 pour la vue de J1, 4
## pour celle de J2. C'est le défaut exact payé sur le flash de mort le
## 2026-08-17, et il est consigné.
##
## ⚠️ **Non éclairé, et c'est une décision.** Un viseur qui s'éteindrait dans le
## noir serait inutilisable là où le jeu se joue. Il ne fait pas partie du monde
## que la torche révèle : il est l'œil du joueur posé dessus.
func _monter_viseur() -> void:
	if not ResourceLoader.exists(VISEUR):
		push_error("player : viseur absent — %s " % VISEUR
			+ "(cuire avec tools/fabrique_decals.gd, puis : "
			+ "godot --headless --path . --import)")
		return
	var v := Sprite2D.new()
	v.name = "Viseur"
	var t: Texture2D = load(VISEUR)
	v.texture = t
	# L'empreinte commande, pas le fichier — voir `EMPREINTE_VISEUR`.
	if t != null and t.get_width() > 0:
		v.scale = Vector2.ONE * (EMPREINTE_VISEUR / float(t.get_width()))
	v.position = Vector2(DISTANCE_VISEUR, 0)
	v.modulate = Color(Charte.HALOGENE, 0.72)
	v.visibility_layer = 2 if player_id == 0 else 4
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	v.material = mat
	v.z_index = 9 # Sous le joueur (10), au-dessus de tout le reste
	add_child(v)


func equip_weapon(weapon: WeaponData):
	current_weapon = weapon
	# DA2.4 + DA2.5 — la silhouette du joueur change avec son arme.
	_poser_sprite(weapon.slug() if weapon.has_method("slug") else "pistolet")
	
	var tex = weapon.get_torch_texture()
	flashlight.texture = tex
	# La teinte n'est pas touchée ici : elle est posée une fois à la construction
	# de la torche, et une arme n'en change pas.
	flashlight.texture_scale = weapon.echelle_torche()


func _process(delta):
	# Publié ici et non dans _physics_process : les sorties anticipées (mort,
	# menu, round inactif) y laisseraient l'état répliqué figé sur du passé.
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		net_position = global_position
		net_rotation = rotation
		net_flashlight_on = flashlight_on
		net_dazzle = dazzle_amount
		net_ack_seq = _last_input_seq

	# Hors du bloc de simulation : côté client la torche est répliquée, et les
	# sorties anticipées de _physics_process ne doivent pas laisser le son bloqué.
	# La torche de l'adversaire ne se déclare PAS au bus musical en ligne : elle
	# ouvrirait le passe-bas local et dirait qu'il vient de s'allumer, hors de
	# vue. Voir `AudioManager.torche_comptee`.
	if flashlight_on != _torch_audio_state:
		_torch_audio_state = flashlight_on
		if AudioManager.torche_comptee(player_id, _index_joueur_local()):
			AudioManager.set_player_torch(player_id, flashlight_on)

	if dead: return

	# V1.5 — pouls haptique sous le seuil de santé basse, calé sur le ressenti
	# du stem « battement de cœur » (mi-temps de 170 BPM : un battement lourd
	# plutôt qu'un bourdonnement continu).
	if hp <= 30.0 and _is_locally_piloted():
		var state = get_tree().get_first_node_in_group("game_state")
		if state and state.round_active and state.countdown_left <= 0.0:
			_low_hp_pulse_accum += delta
			if _low_hp_pulse_accum >= RUMBLE_PULSE_PERIOD:
				_low_hp_pulse_accum = 0.0
				_rumble(RUMBLE_PULSE_WEAK, 0.0, 0.08)
				# V4.7 — la vignette bat au même cœur que la manette : un seul
				# battement pilote l'image, la main — et le stem heartbeat.
				if vignette_mat:
					vignette_mat.set_shader_parameter("intensity", 0.55)
					var tw_v = create_tween()
					tw_v.tween_method(func(v): vignette_mat.set_shader_parameter("intensity", v),
						0.55, 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_low_hp_pulse_accum = 0.0

	if shoot_cooldown > 0:
		shoot_cooldown -= delta
		if shoot_cooldown <= 0:
			shoot_cooldown = 0
			# Play ready sound here if desired
	
	# L'éblouissement n'est PAS intégré ici. `game_state` s'en charge, pour les
	# deux joueurs et en un seul endroit — c'est cette ligne-ci qui, jusqu'au
	# 2026-08-18, rabotait sans condition (−2,0/s) ce que `_check_dazzle`
	# ajoutait quatre fois plus lentement, sans que rien ne les additionne
	# jamais. Le client, lui, ne calcule rien : il porte ce que l'hôte a arbitré.
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		dazzle_amount = net_dazzle

	# V5.3 — l'acouphène suit l'éblouissement du joueur local. Chaque machine
	# n'écoute que ses propres yeux ; l'appel est idempotent côté AudioManager.
	if _is_locally_piloted():
		AudioManager.set_dazzle_level(player_id, dazzle_amount)

		
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		if shake_intensity < 0.5:
			shake_intensity = 0.0
		
		# Find the camera on this player
		for c in get_children():
			if c is Camera2D:
				if shake_intensity > 0:
					c.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
				else:
					c.offset = Vector2.ZERO

## [Hôte] Reçoit les commandes du client. Seul le peer propriétaire de P2 est
## accepté : sans cette garde, n'importe quel peer pourrait piloter P2.
@rpc("any_peer", "unreliable")
func rpc_send_inputs(seq: int, mov: Vector2, aim: Vector2, shoot: bool, torch: bool) -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST: return
	if player_id != 1: return
	var state = get_tree().get_first_node_in_group("game_state")
	if state == null or multiplayer.get_remote_sender_id() != state.client_peer_id:
		# Comptabilisé plutôt que tu : un rejet silencieux ici fige l'adversaire
		# sur son apparition, sans que rien d'autre ne trahisse le problème.
		inputs_rejected += 1
		return
	# Paquet arrivé après un plus récent : on le jette plutôt que de reculer.
	if seq <= _last_input_seq:
		inputs_rejected += 1
		return
	# L'hôte borne tout ce qu'il applique : un vecteur non fini ou démesuré
	# venu d'un client modifié deviendrait un téléporteur ou un speed hack.
	if not (mov.is_finite() and aim.is_finite()):
		inputs_rejected += 1
		return
	mov = mov.limit_length(1.0)
	aim = aim.limit_length(1.0)
	_last_input_seq = seq
	inputs_accepted += 1
	input_provider.update_input_state(mov, aim, shoot, torch)

## [Hôte] Purge l'état d'input à la déconnexion : sinon P2 resterait figé sur
## la dernière commande reçue (course en cours, torche allumée…).
func reset_network_input() -> void:
	_last_input_seq = -1
	if input_provider and input_provider.has_method("reset_input_state"):
		input_provider.reset_input_state()

## `neutral` : commandes vidées plutôt que tues. Cesser d'émettre laisserait
## l'hôte rejouer la dernière commande reçue, donc courir sans personne aux
## commandes.
func _send_inputs_to_host(neutral: bool = false) -> void:
	inputs_sent += 1
	var peers := multiplayer.get_peers()
	inputs_target = peers[0] if peers.size() > 0 else 0
	if neutral:
		_input_seq += 1
		rpc_id(1, "rpc_send_inputs", _input_seq, Vector2.ZERO, Vector2.ZERO, false, flashlight_on)
		return
	var mov := input_provider.get_movement_vector()
	var aim := input_provider.get_aim_direction(global_position)
	_input_seq += 1
	rpc_id(1, "rpc_send_inputs", _input_seq, mov, aim,
		input_provider.is_shoot_pressed(), input_provider.is_flashlight_pressed())

## Ce nœud est-il celui que pilote la personne assise devant cet écran ? En
## écran partagé la question ne se pose pas : la pause y gèle réellement l'arbre.
## L'indice du joueur local, ou -1 en écran partagé — où les deux joueurs
## partagent l'écran ET la sortie audio, donc n'ont rien à se cacher.
func _index_joueur_local() -> int:
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST:
			return 0
		NetworkManager.GameMode.ONLINE_CLIENT:
			return 1
	return -1

func _is_locally_piloted() -> bool:
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST:
			return player_id == 0
		NetworkManager.GameMode.ONLINE_CLIENT:
			return player_id == 1
	return false

func _net_role() -> NetRole:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
		return NetRole.SIMULATED
	# Le client ne pilote que P2 ; P1 lui est purement répliqué.
	return NetRole.PREDICTED if player_id == 1 else NetRole.INTERPOLATED

## [Client] Un paquet d'état vient d'être appliqué sur les variables tampon.
func _on_net_synchronized() -> void:
	match _net_role():
		NetRole.INTERPOLATED:
			if not _net_snapshots.is_empty() \
					and _net_snapshots[-1]["pos"].distance_to(net_position) > TELEPORT_THRESHOLD:
				_net_snapshots.clear()
			_net_snapshots.append({
				"t": Time.get_ticks_msec() / 1000.0,
				"pos": net_position,
				"rot": net_rotation,
				"torch": net_flashlight_on,
			})
			if _net_snapshots.size() > SNAPSHOT_BUFFER_MAX:
				_net_snapshots.remove_at(0)
		NetRole.PREDICTED:
			_ingest_prediction_correction()

## [Client] Compare l'état hôte à la position qu'on avait prédite pour l'input
## que l'hôte dit avoir appliqué. Un ack déjà traité veut dire que l'hôte a
## rejoué le même input faute de paquet neuf : le recomparer inventerait un
## écart égal au déplacement entretemps.
func _ingest_prediction_correction() -> void:
	if net_ack_seq <= _last_corrected_seq: return
	_last_corrected_seq = net_ack_seq

	var past = _predict_history.get(net_ack_seq)
	for seq in _predict_history.keys():
		if seq <= net_ack_seq:
			_predict_history.erase(seq)
	if past == null: return

	var err: Vector2 = net_position - past["pos"]
	var dist := err.length()
	if dist > PREDICT_SNAP:
		# Désynchronisation franche : l'historique n'est plus fiable, on repart
		# de la vérité hôte quitte à perdre un aller-retour de prédiction.
		global_position = net_position
		rotation = net_rotation
		_predict_error = Vector2.ZERO
		_predict_history.clear()
	elif dist > PREDICT_DEADZONE:
		_predict_error = err
	else:
		_predict_error = Vector2.ZERO

	if absf(angle_difference(net_rotation, past["rot"])) > PREDICT_ROT_SNAP:
		rotation = net_rotation

## [Client] Consomme progressivement l'écart mesuré : appliqué d'un coup, il
## serait perçu comme un à-coup à chaque paquet.
func _consume_prediction_error(delta: float) -> void:
	if _predict_error == Vector2.ZERO: return
	var step := _predict_error * (1.0 - exp(-PREDICT_CORRECTION_RATE * delta))
	global_position += step
	_predict_error -= step
	if _predict_error.length() < 0.5:
		_predict_error = Vector2.ZERO

## [Client] Rend le joueur distant INTERP_DELAY en arrière : on dispose alors
## presque toujours de deux instantanés encadrants, malgré les 30 Hz.
func _apply_remote_interpolation() -> void:
	if _net_snapshots.is_empty(): return

	var render_t := Time.get_ticks_msec() / 1000.0 - INTERP_DELAY
	var first: Dictionary = _net_snapshots[0]
	var last: Dictionary = _net_snapshots[-1]

	if _net_snapshots.size() == 1 or render_t <= first["t"]:
		global_position = first["pos"]
		rotation = first["rot"]
		flashlight_on = first["torch"]
		return

	if render_t >= last["t"]:
		# Tampon épuisé : on prolonge brièvement la dernière vitesse connue
		# plutôt que de figer l'adversaire sur un paquet manquant.
		var prev: Dictionary = _net_snapshots[-2]
		var gap: float = last["t"] - prev["t"]
		var ahead := minf(render_t - last["t"], EXTRAPOLATION_MAX)
		if gap > 0.0001:
			global_position = last["pos"] + (last["pos"] - prev["pos"]) / gap * ahead
			rotation = last["rot"] + angle_difference(prev["rot"], last["rot"]) / gap * ahead
		else:
			global_position = last["pos"]
			rotation = last["rot"]
		flashlight_on = last["torch"]
		return

	for i in range(_net_snapshots.size() - 1):
		var a: Dictionary = _net_snapshots[i]
		var b: Dictionary = _net_snapshots[i + 1]
		if render_t <= b["t"]:
			var span: float = b["t"] - a["t"]
			var w: float = 0.0 if span <= 0.0001 else (render_t - a["t"]) / span
			global_position = a["pos"].lerp(b["pos"], w)
			rotation = lerp_angle(a["rot"], b["rot"], w)
			flashlight_on = a["torch"]
			# Les instantanés antérieurs ne resserviront plus.
			if i > 0:
				_net_snapshots = _net_snapshots.slice(i)
			return

## [Serveur / Client] Gère la physique (Sandbox autorisé).
func _physics_process(delta):
	if dead: return
	
	var state = get_tree().get_first_node_in_group("game_state")
	if state and state.ui._is_main_menu and not state.sandbox_mode:
		velocity = Vector2.ZERO
		flashlight_on = false
		return
		
	# Le client émet ses commandes puis simule quand même : l'état hôte ne sert
	# qu'à corriger. L'adversaire, lui, n'est jamais simulé ici.
	var role := _net_role()
	# Menu pause en ligne : l'arbre n'est pas gelé, le joueur reste donc une
	# cible — mais les touches servent à naviguer, elles ne doivent plus piloter
	# le personnage.
	var menu_open: bool = state != null and _is_locally_piloted() and state.ui.is_pause_menu_open()
	if role == NetRole.PREDICTED:
		_send_inputs_to_host(menu_open)
	elif role == NetRole.INTERPOLATED:
		_apply_remote_interpolation()

	# Décompte de départ : plus personne ne bouge, ne vise ni ne tire. Placé
	# après l'interpolation pour que l'adversaire soit tout de même rendu à sa
	# position d'apparition et non sur un instantané périmé.
	if state and state.countdown_left > 0.0:
		velocity = Vector2.ZERO
		flashlight_on = false
		flashlight.enabled = false
		body_light.enabled = false
		# Le détecteur de pas ne doit jamais voir le saut de téléportation du
		# spawn : on le recale tant que le décompte fige tout le monde.
		_last_step_pos = global_position
		_update_aim_line()
		return

	var can_move = role != NetRole.INTERPOLATED
	if role == NetRole.SIMULATED and NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN and multiplayer.has_multiplayer_peer():
		can_move = is_multiplayer_authority()
	if menu_open:
		velocity = Vector2.ZERO
		can_move = false

	if state and not (state.round_active or state.sandbox_mode):
		if can_move:
			velocity = velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
			if velocity != Vector2.ZERO:
				move_and_slide()
			# V2.2 — pendant la séquence de fin, GameState éteint lui-même les
			# lumières du vainqueur : le noir doit gagner en 400 ms, pas en une
			# frame de coupure sèche.
			if not state._end_sequence_active:
				flashlight_on = false
				flashlight.enabled = false
				body_light.enabled = false
		return
		
	if can_move:
		var input_dir = input_provider.get_movement_vector()
		# ⚠️ **La vitesse ne dépend que de deux causes, et toutes deux se
		# LISENT** : l'arme qu'on porte et l'éblouissement qu'on subit. Rien ne
		# doit accélérer un joueur sans que l'adversaire puisse le voir venir —
		# dans un jeu dont la seule information est la lumière, une accélération
		# muette est une information retirée à l'autre.
		var current_speed = speed
		if shoot_cooldown > 0 and current_weapon:
			current_speed *= current_weapon.movement_speed_while_reloading
		if dazzle_amount > 0:
			current_speed *= lerp(1.0, 0.4, dazzle_amount)
			
		velocity = input_dir * current_speed
		if velocity != Vector2.ZERO:
			move_and_slide()
		
		var aim_dir = input_provider.get_aim_direction(global_position)
		if aim_dir.length() > 0.1:
			var target_angle = aim_dir.angle()
			var aim_lerp_speed = 18.0 * (1.0 - dazzle_amount * 0.6)
			rotation = lerp_angle(rotation, target_angle, min(1.0, delta * aim_lerp_speed))
			
		# La torche n'obéit qu'au bouton : **aucun autre état du joueur ne
		# l'éteint.** Elle montre et elle trahit ; le moment est un choix, et il
		# reste entier.
		flashlight_on = input_provider.is_flashlight_pressed()

		if role == NetRole.PREDICTED:
			# Correction appliquée AVANT l'archivage : l'historique doit décrire
			# la position réellement affichée, sinon l'écart serait recompté.
			_consume_prediction_error(delta)
			_predict_history[_input_seq] = {"pos": global_position, "rot": rotation}
			if _predict_history.size() > PREDICT_HISTORY_MAX:
				_predict_history.erase(_predict_history.keys()[0])

	# Pas — son ET empreinte (D1), déclenchés sur la distance RÉELLEMENT
	# parcourue et non sur la vitesse simulée. Hors du bloc can_move exprès :
	# l'adversaire interpolé doit produire les mêmes traces que le joueur
	# simulé, sinon l'information devient asymétrique — l'hôte entendrait et
	# pisterait le client, jamais l'inverse. (Corrige au passage l'asymétrie
	# préexistante du SFX de pas, inaudible côté client pour l'adversaire.)
	var step_moved := global_position.distance_to(_last_step_pos)
	_last_step_pos = global_position
	# > 100 px en un tick : téléportation (spawn, correction sèche), pas un pas.
	if step_moved > 0.5 and step_moved < 100.0:
		step_distance_accumulated += step_moved
		# ⚠️ **Une seule distance, et surtout pas une branche.** Le seuil doit
		# être le même pour le joueur simulé et pour l'adversaire interpolé : un
		# pas qui se déclenche plus tôt d'un côté que de l'autre rend
		# l'information asymétrique — l'un entend et piste, l'autre pas.
		var step_dist := 45.0
		if step_distance_accumulated >= step_dist:
			step_distance_accumulated = 0.0
			# Fourchette fixe : rien ne module la hauteur du pas. **Un facteur
			# qui ne varie jamais suggère une modulation qui n'existe pas** — il
			# coûte une relecture à chaque passage, et il en promet une.
			AudioManager.play_sfx_2d_random_pitch("footstep", global_position, 0.95, 1.05)
			# D1 — l'empreinte au rythme exact du pas sonore : le son et la
			# trace racontent le même événement, sandbox compris.
			_foot_side = -_foot_side
			if state and state.arena:
				Footprint.spawn(state.arena, global_position, rotation, _foot_side)
			# V5.6 — le halo de rétrodiffusion respire au même pas.
			_backscatter_pulse = BACKSCATTER_STEP_PULSE

	# Chantier « brouiller la position de celui qui éblouit » — l'adversaire
	# s'efface pour QUI EST ÉBLOUI.
	#
	# ⚠️ **`modulate.a` et RIEN d'autre.** `player_enemy_light.gdshader` plafonne
	# `LIGHT` à `COLOR.rgb` : éclaircir la COULEUR relève ce plafond et fait
	# BRILLER la silhouette au lieu de la fondre. Un réglage entier est mort de
	# ça, et le piège ne se voit qu'à l'écran — le code paraît juste.
	#
	# ⚠️ **L'alpha suit l'éblouissement du REGARDEUR, pas du regardé.**
	# `visual_enemy` est ce corps-ci tel que l'AUTRE le voit : c'est donc le
	# dazzle de l'autre qui décide s'il le distingue. Prendre le sien inverserait
	# l'effet — on s'effacerait soi-même en éblouissant quelqu'un.
	if state != null and visual_enemy != null:
		var regardeur: Node = state.p2 if player_id == 0 else state.p1
		if is_instance_valid(regardeur):
			var a := Brouillage.opacite(float(regardeur.dazzle_amount))
			visual_enemy.modulate.a = a
			if visual_enemy_ptr != null:
				visual_enemy_ptr.modulate.a = a

	# DA2.4 — le corps roule sur le pied porteur.
	#
	# ⚠️ **Ce n'est pas une animation de remplacement, c'est la bonne réponse à
	# la contrainte.** L'item demandait quatre images de marche ; quatre images
	# FIXES ne peuvent pas rester en phase avec un détecteur de pas qui compte
	# une DISTANCE (45 px) et non un temps. Le son du pas,
	# l'empreinte au sol et la bosse de rétrodiffusion tombent déjà ensemble
	# juste au-dessus ; le roulis se dérive du même accumulateur, donc il tombe
	# avec eux — à toutes les vitesses, et sans un réglage.
	#
	# ⚠️ **Et il ne peut pas mentir sur la visée.** Un roulis se fait en
	# TRANSLATION le long de l'axe local Y, jamais en rotation : `rotation` dit
	# où le joueur vise, et c'est l'information la plus chère du jeu. Des frames
	# peintes avec l'arme pivotée l'auraient contredite douze fois par seconde.
	#
	# `_foot_side` alterne juste au-dessus : le corps penche donc d'un côté puis
	# de l'autre, ce qui est ce que fait un marcheur, et non un métronome.
	var vise_roulis := 0.0
	if step_moved > 0.5 and step_moved < 100.0:
		vise_roulis = sin(step_distance_accumulated / 45.0 * PI) \
			* ROULIS_MARCHE * float(_foot_side)
	_roulis = move_toward(_roulis, vise_roulis, ROULIS_RETOUR * delta)
	for poly in [visual, visual_dim, visual_reveal, visual_enemy,
			visual_reveal_enemy]:
		if poly != null:
			# Les cinq vues reposent en (0,0) — déclaré nulle part dans
			# `player.tscn`, donc vrai par défaut, et les deux vues « ennemi »
			# sont des `duplicate()` des autres.
			poly.position.y = _roulis

	# Visuals update for all clients
	# D3 — extinction traînée (décision actée) : le noir « avale » le faisceau
	# en ~80 ms au lieu d'une coupure sèche. Coût assumé : l'adversaire gagne
	# ces 80 ms d'information à l'extinction. Symétrique : l'effet joue aussi
	# sur la torche répliquée de l'adversaire.
	if flashlight_on:
		flashlight.enabled = true
		body_light.enabled = true
		if shoot_cooldown > 0:
			flashlight.energy = randf_range(1.5, 2.0)
		else:
			# V5.4 — la torche respire : ±3 % d'énergie sur un bruit lent,
			# identique pour les deux joueurs — la lumière vit, sans rien dire.
			_torch_breath_t += delta
			var souffle := 1.0 + noise.get_noise_1d(_torch_breath_t * 40.0) * TORCH_BREATH_AMP
			flashlight.energy = lerp(flashlight.energy, 2.5 * souffle, 8.0 * delta)

		# V5.6 — la rétrodiffusion gonfle d'un souffle à chaque pas (posé par le
		# détecteur de pas plus haut) puis se résorbe seule : marcher torche
		# allumée respire. L'info (torche visible) existe déjà.
		_backscatter_pulse = move_toward(_backscatter_pulse, 0.0, delta * 2.5)
		var pulse := 1.0 + _backscatter_pulse
		if current_weapon:
			body_light.energy = (flashlight.energy / 2.5) * 0.6 * current_weapon.backlight_multiplier * pulse
		else:
			body_light.energy = (flashlight.energy / 2.5) * 0.6 * pulse

		# V5.5 — poussière dans le faisceau : un grain ténu à la fois, posé
		# quelque part dans le cône. Visible des deux côtés, comme le faisceau.
		_dust_accum += delta
		if _dust_accum >= DUST_INTERVAL:
			_dust_accum = 0.0
			var pool := get_tree().get_first_node_in_group("particle_pool") as ParticlePool
			if pool:
				var faisceau := Vector2.from_angle(global_rotation)
				var portee := randf_range(40.0, 240.0)
				# `torch_angle_deg` est DÉJÀ un demi-angle : le multiplier par
				# 0,5 semait la poussière dans un cône deux fois trop étroit
				# (corrigé le 2026-08-18, même faux ami que l'éblouissement).
				# 30° sans arme : le même défaut que `Vision.COS_DEMI_CONE`.
				var demi_angle: float = current_weapon.demi_angle_torche() if current_weapon \
					else deg_to_rad(30.0)
				var ecart := faisceau.orthogonal() * portee * tan(demi_angle) * randf_range(-0.6, 0.6)
				pool.emit(ParticlePool.Kind.DUST, muzzle.global_position + faisceau * portee + ecart,
					Color(Charte.HALOGENE, 0.18), 1, 4.0, 14.0, faisceau, 160.0)
	elif flashlight.enabled:
		flashlight.energy = move_toward(flashlight.energy, 0.0, delta * (2.5 / TORCH_FADE_OUT))
		body_light.energy = move_toward(body_light.energy, 0.0, delta * (0.6 / TORCH_FADE_OUT))
		if flashlight.energy <= 0.01:
			flashlight.enabled = false
			body_light.enabled = false
	
	_update_aim_line()

	# Le tir suit l'autorité de simulation : en ligne c'est l'hôte qui l'arbitre
	# pour les deux joueurs, cooldown compris.
	var presse := input_provider.is_shoot_pressed()
	if can_move and presse and shoot_cooldown <= 0:
		shoot()
	elif can_move and presse and not _detente_pressee and _percu_ici():
		# Front montant seulement : détente maintenue pendant une seconde de
		# rechargement, le tremblement doit dire « trop tôt » une fois, pas vibrer
		# en continu comme une panne.
		tir_a_sec = 0.22
		# V4.4 — le percuteur. Positionnel a la bouche : un clic a vide est un
		# evenement du monde, et dans ce jeu il RACONTE quelque chose de cher —
		# « je suis desarme, et je suis la ». Il ne compte pas comme un tir pour
		# le pool (voir `AudioManager.est_un_tir`), sans quoi il ferait reculer
		# les pas de l'adversaire au moment ou l'on ne tire justement pas.
		if current_weapon:
			AudioManager.play_sfx_2d(
				AudioManager.chemin_percuteur(current_weapon.slug()),
				muzzle.global_position)
	_detente_pressee = presse
	if tir_a_sec > 0.0:
		tir_a_sec = maxf(0.0, tir_a_sec - delta)

## V4.4 — presser la détente pendant le rechargement ne produisait RIEN.
##
## Ni son, ni image, ni vibration : le joueur ne pouvait pas distinguer « j'ai
## appuyé trop tôt » de « ma touche n'a pas répondu ». C'est le seul geste du jeu
## qui échouait en silence.
##
## **Uniquement pour le joueur qui a pressé, et sur SON écran.** En ligne, l'hôte
## simule aussi l'adversaire : sans ce filtre, le HUD de l'hôte tremblerait quand
## le client tire à sec — lui apprenant que l'autre vient d'essayer de tirer, donc
## qu'il est à portée et à découvert. Même règle que pour le passe-bas des
## torches : ce qui réagit à l'état d'un joueur doit se demander de qui il tient
## cet état.
func _percu_ici() -> bool:
	var local := _index_joueur_local()
	return local < 0 or player_id == local

func _update_aim_line() -> void:
	if aim_cast == null or aim_line == null: return
	var end_pos = Vector2(2000, 0)
	if aim_cast.is_colliding():
		end_pos = to_local(aim_cast.get_collision_point())
	aim_line.points = PackedVector2Array([Vector2(28, 0), end_pos])

## V4.4 — temps restant du tremblement de refus, lu par le HUD.
var tir_a_sec: float = 0.0
## État précédent de la détente, pour ne réagir qu'au front montant.
var _detente_pressee: bool = false

func shoot():
	shoot_cooldown = current_weapon.cooldown
	# V1.5 — coup ferme et bref dans la manette du tireur.
	_rumble(0.0, RUMBLE_SHOOT_STRONG, 0.12)
	get_tree().call_group("game_state", "spawn_bullet", self, muzzle.global_position, rotation, current_weapon)

# ---------------------------------------------------------------------------
# V1.5 — Retour haptique. Quatre signaux : tir (fort, bref), impact reçu
# (moyen), pouls sous 30 HP, double coup du vainqueur au kill. Ne vibre que la
# manette du joueur assis devant CE personnage : le device_id de son
# LocalInputProvider, et seulement si ce pad est réellement branché — un
# joueur clavier a souvent un pad posé sur le bureau, il ne doit pas bourdonner
# pour l'adversaire.
# ---------------------------------------------------------------------------
const RUMBLE_SHOOT_STRONG := 0.7
const RUMBLE_HIT_WEAK := 0.5
const RUMBLE_HIT_STRONG := 0.3
const RUMBLE_PULSE_WEAK := 0.25
## Mi-temps de 170 BPM : 60 / 85 ≈ 0,71 s entre deux battements.
const RUMBLE_PULSE_PERIOD := 60.0 / 85.0
## D3 — durée d'avalement du faisceau à l'extinction de la torche.
const TORCH_FADE_OUT := 0.08
var _low_hp_pulse_accum: float = 0.0

func _rumble(weak: float, strong: float, duration: float) -> void:
	if not _is_locally_piloted(): return
	var lp := input_provider as LocalInputProvider
	if lp == null: return
	if not Input.get_connected_joypads().has(lp.device_id): return
	Input.start_joy_vibration(lp.device_id, weak, strong, duration)

## Remise à zéro du détecteur de pas, à appeler APRÈS toute téléportation
## (spawn de manche, bac à sable). Sans elle, le delta de position entre la
## fin de manche et le spawn passe sous le garde des 100 px et fabrique un
## pas fantôme — son + empreinte — pile au « FIGHT ! » (constat de revue).
func reset_step_tracker() -> void:
	_last_step_pos = global_position
	step_distance_accumulated = 0.0
	last_fatal_perp = -1.0

## Double coup du kill, ressenti par le vainqueur seulement.
func rumble_kill() -> void:
	_rumble(0.2, 0.9, 0.1)
	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(self):
		_rumble(0.2, 0.9, 0.1)

func trigger_shoot_visuals():
	add_camera_shake(15.0, 15.0)
	muzzle_flash.enabled = true
	var tw = create_tween()
	var flash_intensity = current_weapon.muzzle_flash_intensity if current_weapon else 1.0
	var flash_duration = current_weapon.muzzle_flash_duration if current_weapon else 0.1
	# DA2.3 — la séquence se déroule PAR-DESSUS la descente d'énergie, qui reste
	# seule maîtresse de la luminosité. Chaque image tient un tiers de la durée :
	# à 0,1 s et 60 Hz cela fait deux images de rendu chacune, à 0,05 s
	# (l'arbalète) une seule. **C'est le nombre que la durée permet, pas un choix
	# esthétique** — au-delà de trois, une image ne serait jamais affichée.
	LightTextures.poser(muzzle_flash, LightTextures.FLASH[0],
		LightTextures.EMPREINTE_FLASH)
	tw.tween_property(muzzle_flash, "energy", 0.0, flash_duration).from(flash_intensity)
	for i in range(1, LightTextures.FLASH.size()):
		var chemin: String = LightTextures.FLASH[i]
		tw.parallel().tween_callback(func():
			LightTextures.poser(muzzle_flash, chemin, LightTextures.EMPREINTE_FLASH)
		).set_delay(flash_duration * float(i) / float(LightTextures.FLASH.size()))
	tw.tween_callback(func(): muzzle_flash.enabled = false)
	
	visual_reveal.color.a = 1.0
	visual_reveal_ptr.color.a = 1.0
	if tw_reveal and tw_reveal.is_valid():
		tw_reveal.kill()
		
	tw_reveal = create_tween().set_parallel(true)
	tw_reveal.tween_property(visual_reveal, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw_reveal.tween_property(visual_reveal_ptr, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	if has_node("VisualRevealEnemy"):
		var vre = get_node("VisualRevealEnemy")
		var vrep = get_node("VisualRevealEnemyPtr")
		vre.color = Color(Charte.HALOGENE, 1.0)
		vrep.color = Color(Charte.HALOGENE, 1.0)
		tw_reveal.tween_property(vre, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw_reveal.tween_property(vrep, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	AudioManager.play_weapon_shot(current_weapon.slug() if current_weapon else "pistolet", muzzle.global_position)

	# V4.13 — fumée de bouche : trois grains gris qui dérivent après le flash.
	var pool := get_tree().get_first_node_in_group("particle_pool") as ParticlePool
	if pool:
		var canon := Vector2.from_angle(global_rotation)
		pool.emit(ParticlePool.Kind.SMOKE, muzzle.global_position + canon * 6.0,
			Color(Charte.ACIER * 0.6, 0.28), 3, 20.0, 55.0, canon, 70.0)

	# V4.14 — le sol répond au coup de feu : bref décal lumineux sous le tireur,
	# décor seulement (masque 1), sans ombre — le muzzle flash garde le premier
	# rôle, ceci n'est que son écho au sol.
	var ground_flash := PointLight2D.new()
	LightTextures.poser(ground_flash, LightTextures.ECLAT, 200.0)
	ground_flash.color = Charte.AMBRE
	ground_flash.energy = 1.2
	ground_flash.shadow_enabled = false
	ground_flash.range_item_cull_mask = 1
	add_child(ground_flash)
	var tw_g := create_tween()
	tw_g.tween_property(ground_flash, "energy", 0.0, 0.12)
	tw_g.tween_callback(ground_flash.queue_free)

func take_damage(amount: float, source_player: Node2D):
	if dead: return
	
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
		var new_hp = max(0.0, hp - amount)
		var sid = source_player.player_id if source_player else -1
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
			rpc_update_hp.rpc(new_hp, sid)
		else:
			rpc_update_hp(new_hp, sid)
			
	hit_sound.play()
	AudioManager.play_sfx_2d_random_pitch("flesh_impact", global_position, 0.92, 1.08)
	AudioManager.update_low_health(player_id, hp <= 30.0 and not dead)

	
	# Violent camera shake on hit
	add_camera_shake(35.0, 8.0)
	
	# Trigger damage vignette (flashes red screen edges)
	if vignette_mat:
		vignette_mat.set_shader_parameter("intensity", 1.5)
		var tw = create_tween()
		tw.tween_method(func(val): vignette_mat.set_shader_parameter("intensity", val), 1.5, 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

@rpc("authority", "call_local", "reliable")
func rpc_update_hp(new_hp: float, source_id: int):
	# V1.5 — l'impact se prend au ventre : vibration moyenne sur toute perte de
	# PV, branchée ici (valeur autoritaire) et non sur la balle prédite.
	# V4.6 — et la caméra du blessé encaisse un bref dézoom, même source.
	if new_hp < hp:
		_rumble(RUMBLE_HIT_WEAK, RUMBLE_HIT_STRONG, 0.25)
		var gs = get_tree().get_first_node_in_group("game_state")
		if gs and gs.has_method("camera_hit_kick"):
			gs.camera_hit_kick(player_id)
	hp = new_hp
	if hp <= 0 and not dead:
		hp = 0
		var state = get_tree().get_first_node_in_group("game_state")
		var killer = null
		if state:
			killer = state.p1 if source_id == 0 else state.p2
		die(killer)
	# Dynamic red light illuminating the scene to sell the impact
	var hit_light = PointLight2D.new()
	# Texture blanche partagée, teintée par `color` : une 400×400 était allouée
	# à chaque impact reçu.
	LightTextures.poser(hit_light, LightTextures.ECLAT, 400.0)
	# La lumière de l'impact est celle du sang, pas un rouge d'alerte : elle
	# éclaire une blessure, elle ne signale pas un état.
	hit_light.color = Charte.CARMIN
	hit_light.energy = 2.0
	hit_light.shadow_enabled = true
	# Cast shadows from walls ONLY (mask 1). If we cast from players (mask 4), the player's own occluder blocks 100% of the light!
	hit_light.shadow_item_cull_mask = 1
	# Main blood light affects walls (1) and other stuff (4), but NOT players (2)
	hit_light.range_item_cull_mask = 1 | 4
	add_child(hit_light)
	
	var tw_l = create_tween()
	# Perfectly smooth, lingering fade out
	tw_l.tween_property(hit_light, "energy", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_l.tween_callback(hit_light.queue_free)

func die(killer: Node2D):
	if dead: return
	dead = true
	AudioManager.update_low_health(player_id, false)

	visual.visible = false
	visual_ptr.visible = false
	visual_dim.visible = false
	visual_dim_ptr.visible = false
	visual_reveal.visible = false
	visual_reveal_ptr.visible = false
	
	if has_node("VisualEnemy"):
		get_node("VisualEnemy").visible = false
		get_node("VisualEnemyPtr").visible = false
		get_node("VisualRevealEnemy").visible = false
		get_node("VisualRevealEnemyPtr").visible = false
	flashlight.enabled = false
	body_light.enabled = false
	
	# Satisfying Death Effect (Screen Flash + Chromatic Aberration)
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)
	
	var flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Équité (signalé par la session « menus ») : sans visibility_layer, le
	# bit 1 par défaut rend dans les DEUX vues — le tueur se prenait 600 ms de
	# blanc dans les yeux. Le flash n'appartient qu'à l'écran du mort.
	flash_rect.visibility_layer = 2 if player_id == 0 else 4
	
	var mat = ShaderMaterial.new()
	mat.shader = SHADER_DEATH_FLASH
	mat.set_shader_parameter("flash_intensity", 1.0)
	flash_rect.material = mat
	ui_layer.add_child(flash_rect)
	
	var tw = create_tween()
	tw.tween_method(func(val): mat.set_shader_parameter("flash_intensity", val), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ui_layer.queue_free)
	
	# Floating FATAL Text
	var lbl = Label.new()
	# V2.5 — l'arme du tueur signe le kill.
	lbl.text = "FATAL"
	if killer and killer != self and killer.current_weapon:
		lbl.text = "FATAL — %s" % killer.current_weapon.name.to_upper()
	var settings = LabelSettings.new()
	settings.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	settings.font_size = Charte.T_ENSEIGNE
	settings.font_color = Charte.ROUGE
	settings.outline_size = 12
	settings.outline_color = Charte.NOIR
	lbl.label_settings = settings
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# DA4.4 (corrigé le 2026-08-26) — **le bandeau se MESURE au lieu d'être
	# supposé.** Il sortait de l'écran en écran scindé, relevé par Adrien.
	#
	# Trois littéraux — l'offset, le pivot, la taille du cartouche — avaient été
	# calibrés pour le mot « FATAL » seul, 130 px de large. Avec le nom de l'arme,
	# `FATAL — ARBALÈTE` fait 438 px : le texte triplait et **partait entièrement
	# vers la droite**, jusqu'à +507 px pour 478 px visibles de chaque côté du
	# joueur en écran scindé.
	#
	# ⚠️ **Le centrage n'était pas absent, il était INOPÉRANT.** Le rect d'un
	# `Label` épouse son texte — `Control.size` est borné par la taille minimale —
	# donc `HORIZONTAL_ALIGNMENT_CENTER` centre le texte dans une boîte qui a
	# exactement sa largeur : il ne déplace rien. Ce qu'il fallait centrer, c'est
	# la boîte sur le joueur, et cela demande de connaître sa largeur.
	var geo := geometrie_du_bandeau(lbl.text, settings.font, settings.font_size)
	var mot: Vector2 = geo["mot"]
	# Au-dessus du joueur et centré sur lui, quelle que soit la longueur du mot.
	lbl.position = global_position - Vector2(mot.x * 0.5, mot.y + 30.0)
	lbl.z_index = 200

	
	var lbl_mat = CanvasItemMaterial.new()
	lbl_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lbl.material = lbl_mat
	# DA4.4 — **le cartouche peint derrière le mot.**
	#
	# FATAL était un label sur le noir : le mot le plus fort du jeu, posé sur
	# rien. Il a maintenant un support — une plaque de tôle frappée, bords rongés,
	# l'encre a bavé.
	#
	# **Le mot reste du TEXTE**, dans la fonte d'enseigne, et la texture ne porte
	# que le support : c'est ce qui laisse « FATAL — POMPE » s'allonger avec le nom
	# de l'arme sans qu'aucune image soit à refaire. Enfant du `Label` et dessiné
	# dessous (`show_behind_parent`), donc il suit le mot dans son envol et sa
	# disparition sans qu'on ait à animer deux nœuds.
	var chemin_cartouche := "res://assets/ui/cartouche_fatal.png"
	if ResourceLoader.exists(chemin_cartouche):
		var plaque := TextureRect.new()
		plaque.texture = load(chemin_cartouche)
		plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plaque.stretch_mode = TextureRect.STRETCH_SCALE
		plaque.show_behind_parent = true
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Débordant du mot : une plaque au ras du texte se lit comme un surlignage.
		#
		# ⚠️ **La marge est constante, la taille non — et c'est l'inverse qui était
		# écrit.** La plaque valait `300 × 150` quel que soit le texte : elle était
		# donc **plus étroite que son propre mot pour trois armes sur quatre**,
		# alors que le commentaire ci-dessus promet qu'elle déborde. Un cartouche
		# se reconnaît à l'épaisseur de sa bordure, pas à un rapport : la même
		# plaque autour de « FATAL » et de « FATAL — ARBALÈTE » doit montrer la
		# même marge, pas la même proportion.
		#
		# Les deux coefficients sont réglés pour rendre EXACTEMENT les 300 × 150
		# d'origine sur le mot seul — la correction ne change donc rien à ce
		# qu'Adrien a validé hier, elle le fait seulement tenir sur les autres.
		plaque.size = geo["plaque"]
		plaque.position = -geo["marge"]
		# Masque gris teinté par le code, comme le cadre du HUD et la torche.
		# `CARMIN` et non `ROUGE` : c'est le rouge vu à l'intensité d'une chose qui
		# ne s'éclaire plus elle-même, et le mot en `ROUGE` doit ressortir dessus.
		plaque.modulate = Charte.CARMIN
		# Non éclairé, comme le mot qu'il porte : un support de texte qui
		# s'assombrirait hors de la torche disparaîtrait au pire moment.
		plaque.material = lbl_mat
		lbl.add_child(plaque)
	
	get_parent().add_child(lbl)
	
	var txt_tw = create_tween().set_parallel(true)
	lbl.scale = Vector2.ZERO
	# Le pivot au MILIEU : un pivot fixe à 100 px faisait grandir le bandeau
	# depuis un point situé quelque part dans le mot, donc toujours vers la
	# droite. Au centre, il enfle autour du joueur.
	lbl.pivot_offset = mot * 0.5
	# ⚠️ **L'agrandissement se borne à ce que la vue peut montrer.** 1,5× reste la
	# valeur voulue ; `LARGEUR_UTILE` est la largeur d'une vue en écran scindé, le
	# cas le plus étroit du jeu. Une arme au nom plus long que tout ce qui existe
	# aujourd'hui rétrécirait le bandeau au lieu de le faire sortir du cadre —
	# c'est le garde-fou qui manquait, et son absence est ce qui a rendu le défaut
	# invisible jusqu'à ce qu'une arme au nom long le révèle.
	var enfle: float = geo["enfle"]
	txt_tw.tween_property(lbl, "scale", Vector2(enfle, enfle), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	txt_tw.tween_property(lbl, "position", lbl.position + Vector2(0, -100), 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	txt_tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(1.0)
	txt_tw.chain().tween_callback(lbl.queue_free)

	# V2.9 — « à N px du centre » : le tir fatal raconté au perdant. Le « j'y
	# étais presque » est le moteur du rematch. Connue seulement si la balle
	# fatale a été simulée sur cette machine ; consommée pour ne jamais resservir.
	if last_fatal_perp >= 0.0:
		var sub = Label.new()
		sub.text = "à %d px du centre" % int(roundf(last_fatal_perp))
		var sub_settings = LabelSettings.new()
		sub_settings.font = Charte.police_display(Charte.POIDS_DISPLAY)
		sub_settings.font_size = Charte.T_TITRE
		sub_settings.font_color = Charte.HALOGENE
		sub_settings.outline_size = 8
		sub_settings.outline_color = Charte.NOIR
		sub.label_settings = sub_settings
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.position = global_position + Vector2(-100, -20)
		sub.custom_minimum_size = Vector2(200, 0)
		sub.z_index = 200
		sub.material = lbl_mat
		get_parent().add_child(sub)
		var sub_tw = create_tween().set_parallel(true)
		sub.modulate.a = 0.0
		sub_tw.tween_property(sub, "modulate:a", 1.0, 0.2).set_delay(0.25)
		sub_tw.tween_property(sub, "position", sub.position + Vector2(0, -60), 1.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		sub_tw.tween_property(sub, "modulate:a", 0.0, 0.5).set_delay(1.2)
		sub_tw.chain().tween_callback(sub.queue_free)
	# DA4.7 — **la marge survit à la manche.** Elle criait « j'y étais presque »
	# pendant deux secondes au-dessus d'un cadavre, puis disparaissait ; or le
	# moment où ce chiffre pèse le plus est celui où le joueur décide de rejouer
	# ou de partir, et c'est l'écran de fin. On le confie à `game_state`, seul à
	# savoir quand un match s'arrête.
	#
	# ⚠️ **Avant la remise à -1, et pas après.** La ligne suivante consomme la
	# valeur ; c'est elle qui garantit qu'un effleurement ne resserve pas à la
	# manche d'après, et l'ordre des deux lignes est tout ce qui sépare « la
	# marge du tir décisif » de « la marge d'un tir d'il y a trois manches ».
	if last_fatal_perp >= 0.0:
		get_tree().call_group("game_state", "noter_effleurement", last_fatal_perp)
	last_fatal_perp = -1.0

	# V1.5 — le vainqueur sent le kill : double coup dans SA manette.
	if killer and killer != self and killer.has_method("rumble_kill"):
		killer.rumble_kill()

	get_tree().call_group("game_state", "player_died", player_id, killer.player_id if killer else -1)

func add_camera_shake(intensity: float, decay: float = 5.0):
	if intensity > shake_intensity:
		shake_intensity = intensity
	shake_decay = decay

## Pic instantané — le flash de tir. Peut dépasser le plafond de la torche : le
## modèle le résorbe ensuite, c'est voulu.
func apply_dazzle(amount: float):
	dazzle_amount = min(1.0, dazzle_amount + amount)

## Une image d'éblouissement, appelée par `game_state` et JAMAIS d'ici.
##
## `plafond` est la lumière reçue à cet instant (0 = rien, 1 = faisceau saturant
## dans les yeux). Deux `_process` qui se partagent la même valeur sans se voir,
## c'est précisément le défaut qui vient d'être payé : la montée était dans
## l'un, la descente dans l'autre.
func integrer_eblouissement(plafond: float, delta: float) -> void:
	dazzle_amount = Eblouissement.integrer(dazzle_amount, plafond, delta)

func _calculate_uvs(poly: Polygon2D):
	if poly.polygon.size() == 0: return
	var pts = poly.polygon
	var min_x = pts[0].x
	var max_x = pts[0].x
	var min_y = pts[0].y
	var max_y = pts[0].y
	for p in pts:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
		
	var w = max_x - min_x
	var h = max_y - min_y
	if w == 0: w = 1
	if h == 0: h = 1
	
	# ⚠️ **`Polygon2D.uv` est en PIXELS DE TEXTURE, pas en 0..1.**
	#
	# Cette fonction produisait des UV normalisées. Avec une texture de 1×1 —
	# ce que portaient les cinq vues avant DA2.4, un `Polygon2D` exigeant une
	# texture sous peine de voir ses UV s'effondrer — c'était juste par accident :
	# 0..1 pixel couvre exactement le pixel unique. **Le bug était donc
	# inoffensif depuis toujours, et invisible pour la même raison.**
	#
	# DA2.4 a posé de vraies textures. Le quad s'est mis à échantillonner un
	# carré d'UN TEXEL dans le coin haut-gauche du sprite — où le soldat est
	# transparent. **Le joueur a disparu.** Relevé à l'écran par Adrien le
	# 2026-08-26 : « je ne vois rien, que le nez blanc de chaque joueur ».
	#
	# ⚠️ **Et le nez était la preuve.** `visual_ptr` a gardé sa texture 1×1 :
	# échantillonner son coin rend du blanc, donc il restait juste. La seule
	# chose encore visible à l'écran était exactement la seule qui échappait au
	# défaut. Un symptôme qui désigne sa cause, pour qui regarde ce qui RESTE.
	#
	# Le facteur d'échelle vaut (1,1) sur une texture de 1×1 : les vues qui n'ont
	# pas de sprite gardent donc le comportement d'avant, au bit près.
	var tex := poly.texture
	var ech := Vector2.ONE
	if tex != null:
		ech = Vector2(tex.get_width(), tex.get_height())
	var uvs = PackedVector2Array()
	for p in pts:
		uvs.append(Vector2((p.x - min_x) / w, (p.y - min_y) / h) * ech)
	poly.uv = uvs

func hide_all_visuals():
	visual.hide()
	visual_ptr.hide()
	visual_dim.hide()
	visual_dim_ptr.hide()
	visual_reveal.hide()
	visual_reveal_ptr.hide()
	visual_enemy.hide()
	visual_enemy_ptr.hide()
	visual_reveal_enemy.hide()
	visual_reveal_enemy_ptr.hide()

func show_all_visuals():
	visual.show()
	visual_ptr.show()
	visual_dim.show()
	visual_dim_ptr.show()
	visual_reveal.show()
	visual_reveal_ptr.show()
	visual_enemy.show()
	visual_enemy_ptr.show()
	visual_reveal_enemy.show()
	visual_reveal_enemy_ptr.show()
