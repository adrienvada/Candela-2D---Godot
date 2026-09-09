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

## Où se trouve, DANS CHAQUE PLANCHE, le centre de sa plus grosse flaque — en
## fraction de la taille du fichier. Même ordre qu'`ECLABOUSSURES`.
##
## **La règle est d'Adrien, le 2026-09-07 :** « il faut que le centre de la plus
## grosse tache (la plus grosse forme rouge assez ronde sur chacune) soit sous le
## personnage ». Ce point-là n'est ni le centre du fichier ni le centre de masse
## de l'encre : c'est le centre du plus grand disque qui tient dans la matière.
##
## ⚠️ **Une constante par planche, parce qu'un décalage unique ne peut pas
## marcher.** Les deux planches ne se ressemblent pas : `sang_1` porte sa flaque
## à peu près au milieu, `sang_2` la porte à **13 %** de sa largeur, tout au bord.
## Un ancrage commun met donc forcément l'une des deux à côté — et c'est
## exactement ce qui faisait qu'« une tache sur deux » était franchement pire.
##
## ⚠️ **Mesuré, pas estimé, et RE-mesuré par le banc.** Ces valeurs sortent d'une
## transformée de distance sur le masque alpha des fichiers (2026-09-07) :
## `sang_1` flaque de 21 px de rayon, `sang_2` de 12,4 px.
## `tools/test_sang_au_sol.gd` refait ce calcul sur les vraies planches à chaque
## lot : recuire un décal sans corriger cette table fait rougir le banc, au lieu
## de déplacer les taches en silence.
const FLAQUES := [Vector2(0.522, 0.565), Vector2(0.134, 0.539)]

## Quelle planche est une « étoile » — une flaque centrée, à peu près ronde,
## sans direction lisible — par opposition aux planches DIRECTIONNELLES, dont
## la traînée se voit. Même ordre et même taille qu'`ECLABOUSSURES`.
##
## **Règle d'Adrien, le 2026-09-09 :** l'étoile centrée ne doit apparaître que
## pour un tir qui passe très près du centre réel du joueur ; sinon, ce sont
## les planches directionnelles qui doivent sortir. Voir `SEUIL_ETOILE_CENTREE`
## et `_choisir_eclaboussure()`.
const EST_ETOILE_CENTREE := [true, false]

## Distance maximale, en pixels, entre l'AXE du tir et le CENTRE réel du joueur
## pour que l'étoile centrée soit éligible au tirage.
##
## ⚠️ **Un seuil sur l'axe, pas sur le point d'impact.** `bullet.gd::_hit_player()`
## calcule déjà cette distance perpendiculaire pour l'atténuation des dégâts
## (`dist_to_axis`) — c'est elle, non normalisée, qui est transmise ici. Jamais
## une seconde mesure : le même nombre décide « le tir a-t-il touché près du
## centre ? » pour les dégâts ET pour le choix de la planche.
##
## **0-2 px, valeur d'Adrien** : un tir qui vise exactement le centre du corps
## donne 0 ; au-delà de 2 px d'écart, ce sont les planches directionnelles.
const SEUIL_ETOILE_CENTREE := 2.0

var _texture: Texture2D = null
var _coeur: Texture2D = null
## Centre de la flaque de LA planche tirée au sort, en fraction (voir FLAQUES).
## ⚠️ Lue par `_draw()`, donc à reporter à la main dans `_create_p2_duplicate()`.
var _ancre := Vector2(0.5, 0.5)
var _echelle := 1.0
var _drops = []
var color = Color(Charte.CARMIN, 0.9) # Sang séché, sombre
## Rang de cette tache, figé à l'entrée dans l'arbre (voir _next_order).
var _order := 0
## Copie J2, tenue par l'original pour être libérée d'un seul geste.
var _p2_copy: Node2D = null


## ## L'ancrage de la planche — SG1, nommé le 2026-09-07
##
## ⚠️ **Ce calcul n'avait pas de nom, donc rien ne le tenait.** Il vivait en deux
## morceaux — la pose dans `setup()`, le rectangle dans `_draw()` — qu'aucun banc
## ne pouvait exercer sans déposer une vraie tache dans une vraie arène. C'est le
## motif exact qui a laissé passer le bandeau FATAL hors cadre pendant des
## semaines, et c'est lui qu'Adrien a fini par relever à l'œil : « les taches de
## sang démarrent souvent AVANT le sprite du joueur touché ».
##
## Les deux fonctions ci-dessous sont **pures et statiques** : elles ne lisent
## aucun état d'instance, et `tools/test_sang_au_sol.gd` les appelle sans monter
## de partie.

## Diamètre du corps du joueur, en pixels.
##
## ⚠️ **Relevé sur `player.tscn`** (le polygone de collision va de -18 à +18),
## et non lu sur `bullet.gd::PLAYER_BODY_RADIUS` : le jour où cette constante-là
## dérive, on veut que le sang le dise, pas qu'il suive en silence.
const DIAMETRE_CORPS := 36.0


## Où la tache se place et comment elle s'oriente, d'un seul geste.
##
## `impact` est le point d'**entrée** — le bord de la boîte du joueur du côté du
## tireur, ce que `bullet.gd::_hit_player()` transmet — et l'axe X du repère rendu
## pointe donc vers l'**aval**, dans le sens de la balle.
##
## Une seule vérité : `setup()` s'en sert pour poser le nœud, le banc s'en sert
## pour savoir où les pixels atterrissent. Les deux ne peuvent plus diverger.
static func pose(impact: Vector2, direction: Vector2) -> Transform2D:
	return Transform2D(direction.angle(), impact)


## Le centre du corps du joueur touché, dans le repère rendu par `pose()`.
##
## `bullet.gd` transmet le point d'**entrée** — le bord de la boîte du côté du
## tireur — donc le centre du corps est un rayon plus loin, vers l'aval.
const CENTRE_DU_CORPS := DIAMETRE_CORPS * 0.5


## Le rectangle que `_draw()` remet à `draw_texture_rect`, exprimé dans le repère
## rendu par `pose()` : X positif vers l'aval, origine au point d'impact.
##
## `taille` est la taille FINALE de la planche, densité et variation aléatoire
## déjà appliquées — c'est le `t` de `_draw()`. `ancre` dit où se trouve, dans
## cette planche-là, le centre de sa plus grosse flaque (voir `FLAQUES`).
##
## ## La règle, et pourquoi ce n'est pas un décalage
##
## **Adrien, le 2026-09-07 : « le centre de la plus grosse tache doit être sous
## le personnage, et la traînée dans la direction du tir. »** C'est la planche
## qu'on cale sur le corps, par le point qui compte à l'œil — pas un rectangle
## qu'on pousse d'un nombre de pixels.
##
## ⚠️ **Un décalage uniforme ne pouvait pas y arriver, et c'est ce qui a été
## essayé d'abord.** Les deux planches ne portent pas leur flaque au même
## endroit — 52 % de la largeur pour `sang_1`, **13 %** pour `sang_2` — donc tout
## réglage commun met l'une des deux à côté. Cela explique le constat d'origine :
## les taches démarraient « SOUVENT » avant le joueur, pas toujours.
##
## ⚠️ **Ce que ce calcul n'essaie PAS de faire : empêcher toute encre de remonter
## vers le tireur.** Une éclaboussure projette dans toutes les directions, y
## compris en arrière, et une première version de cette fonction bornait cette
## remontée — un proxy plausible qui aurait interdit de poser la flaque là où
## elle doit être. Ce qui doit tomber sur le corps, c'est la MASSE ; les
## projections, elles, ont le droit de dépasser des deux côtés.
static func rectangle_de_la_tache(taille: Vector2, ancre: Vector2) -> Rect2:
	# On place le rectangle pour que son point `ancre` — le cœur de la flaque —
	# tombe sur le centre du corps. Le Y suit la même logique : la flaque se
	# centre EN TRAVERS du tir, elle ne se contente pas d'un milieu de fichier.
	return Rect2(Vector2(CENTRE_DU_CORPS, 0.0) - taille * ancre, taille)


## `distance_axe_centre` : distance en pixels entre l'axe du tir et le centre
## réel du joueur — voir `SEUIL_ETOILE_CENTREE`. Par défaut `INF` (« loin » du
## centre) : un appelant qui ne la connaît pas obtient une planche
## DIRECTIONNELLE, jamais l'étoile réservée aux tirs quasi parfaits.
func setup(base_pos: Vector2, direction: Vector2, distance_axe_centre: float = INF):
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
	_choisir_eclaboussure(distance_axe_centre)
	if _texture != null:
		# ⚠️ Position ET rotation d'un seul geste, par `pose()`. Le repli
		# procédural plus bas, lui, NE tourne PAS le nœud : ses gouttes
		# calculent déjà leur angle depuis `direction`, et le tourner en plus
		# appliquerait la rotation deux fois.
		transform = pose(base_pos, direction)
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
## **Le tirage est restreint à une catégorie** (voir `EST_ETOILE_CENTREE`) :
## l'étoile centrée seulement si `distance_axe_centre <= SEUIL_ETOILE_CENTREE`,
## les planches directionnelles sinon. À une seule planche par catégorie
## aujourd'hui, le tirage au sort est donc sans effet — il reste écrit pour que
## d'autres planches directionnelles rejoignent un jour la liste sans qu'il
## faille retoucher cette fonction.
##
## Rend la main en criant si les fichiers manquent : un décal cuit mais pas
## encore importé par Godot est invisible à `ResourceLoader`, et c'est l'état
## normal d'un asset frais. Sans ce cri, le jeu retomberait sur les cercles et
## personne ne saurait dire pourquoi les éclaboussures n'ont pas changé.
func _choisir_eclaboussure(distance_axe_centre: float) -> void:
	var centree := distance_axe_centre <= SEUIL_ETOILE_CENTREE
	var candidats: Array[int] = []
	for j in range(ECLABOUSSURES.size()):
		if EST_ETOILE_CENTREE[j] == centree:
			candidats.append(j)
	if candidats.is_empty():
		# Filet : aucune planche ne correspond à la catégorie demandée (le cas
		# ne se produit pas aujourd'hui, mais une planche retirée par erreur ne
		# doit pas faire disparaître tout le sang). On retombe sur l'ensemble.
		for j in range(ECLABOUSSURES.size()):
			candidats.append(j)
	var i: int = candidats[randi() % candidats.size()]
	var chemin: String = ECLABOUSSURES[i]
	var coeur := chemin.replace(".png", "_coeur.png")
	if not ResourceLoader.exists(chemin) or not ResourceLoader.exists(coeur):
		push_error("blood_stain : eclaboussure absente — %s " % chemin
			+ "(cuire avec tools/fabrique_decals.gd, puis : "
			+ "godot --headless --path . --import). Repli sur les cercles.")
		return
	_texture = load(chemin)
	_coeur = load(coeur)
	_ancre = FLAQUES[i]


func _draw():
	# Liseré carmin, puis cœur presque noir : une goutte est plus sombre en son
	# centre qu'à son bord, où la lumière rasante l'attrape.
	if _texture != null:
		# ⚠️ **Divisé par la densité, sinon recuire redimensionne le décal.**
		# `_echelle` n'est qu'une variation ALÉATOIRE d'une instance à l'autre :
		# sans cette division, la taille de base d'une tache de sang serait celle
		# de son FICHIER, et une recuisson à ×2 la doublerait à l'écran. Voir
		# `Charte.DENSITE_ASSETS` — même geste que pour les sprites du joueur.
		var t := _texture.get_size() * _echelle / Charte.DENSITE_ASSETS
		draw_texture_rect(_texture, rectangle_de_la_tache(t, _ancre), false,
			Color(Charte.CARMIN, 0.8))
		var c := _coeur.get_size() * _echelle / Charte.DENSITE_ASSETS
		# Le cœur est cuit du même dessin, à la même taille : même ancre, donc
		# les deux passes restent superposées au pixel près.
		draw_texture_rect(_coeur, rectangle_de_la_tache(c, _ancre), false,
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
	# ⚠️ **`duplicate()` NE RECOPIE PAS les variables de script**, et il faut donc
	# reporter l'état à la main. Mesuré le 2026-08-25 : un nœud dont `_drops`
	# contient deux gouttes rend une copie dont `_drops` est VIDE. Seules les
	# propriétés natives suivent — `rotation` passe, `position` passe, rien de ce
	# que le script déclare ne passe.
	#
	# **Le défaut est antérieur au sang peint** : sous le dessin procédural, la
	# copie J2 naissait déjà avec zéro goutte, donc **le joueur 2 n'a jamais vu
	# une seule tache**. Rien ne le signalait — la copie existait, elle était au
	# bon endroit, aux bons masques, et elle dessinait le vide. Une sortie
	# plausible de plus.
		stain_p2.set("_texture", _texture)
		stain_p2.set("_coeur", _coeur)
		stain_p2.set("_echelle", _echelle)
		# `_ancre` est arrivée avec la règle d'Adrien du 2026-09-07 : c'est
		# précisément le genre de variable neuve que ce bloc oublie. Sans cette
		# ligne, J2 verrait toutes ses taches ancrées au milieu de la planche —
		# le défaut d'origine, à moitié, et pour lui seul.
		stain_p2.set("_ancre", _ancre)
		stain_p2.set("_drops", _drops)
		stain_p2.queue_redraw()
		get_parent().add_child(stain_p2)
		_p2_copy = stain_p2
