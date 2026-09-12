class_name GadgetBase
extends StaticBody2D

## Le socle commun des gadgets de classe — chantier CLASSES, étape 5.
##
## ## Ce n'est pas une invention, c'est `training_target.gd` généralisé
##
## La cible d'échauffement fait déjà exactement ça : un `StaticBody2D` posé dans
## le monde, une forme de collision, un `LightOccluder2D` pour ne pas être un
## trou de lumière, et un visuel éclairé comme le décor. Le patron est repris tel
## quel ; ce qui s'y ajoute est ce qu'un gadget a de plus — des points de vie,
## une durée de vie, un poseur, et un drapeau d'éblouissement.
##
## ## Le nom du nœud est EXPLICITE, et ce n'est pas du rangement
##
## `Gadget_P1` / `Gadget_P2`, jamais un nom auto-généré. Un RPC de scène se route
## par le chemin du nœud ; un `@StaticBody2D@412` dépend de tout ce qui a été
## instancié avant, diverge donc entre machines, et **les RPC sont alors jetés
## sans aucune erreur console**. Le dépôt a payé trois manches d'instrumentation
## pour trouver ce défaut une première fois ; la règle est dans `CLAUDE.md`.
##
## ## La couche physique, et pourquoi un gadget n'est pas un mur
##
## `MapGeometry.GADGET_LAYER`, jamais `WALL_LAYER`. Sur la couche des murs, un
## gadget bloquerait les joueurs autant que les balles — et le voile du Spectre,
## dont toute l'idée est « elle arrête la lumière, les balles la traversent »,
## serait devenu un mur ordinaire. Les joueurs traversent parce que leur masque
## ne contient pas cette couche ; ce qui arrête ou non une BALLE est un drapeau,
## `arrete_les_balles`, décidé gadget par gadget.
##
## Depuis le 2026-09-10, le voile arrête aussi les JOUEURS (décision d'Adrien). Il
## le fait par une seconde couche, `GADGET_BLOQUANT_LAYER`, que pose le drapeau
## `arrete_les_joueurs` — jamais en ajoutant celle-ci au masque des joueurs, ce
## qui murerait les dix gadgets d'un coup.
##
## Et depuis le 2026-09-11, les gadgets DIFFUS — nuages et nappes — sortent de la
## couche des gadgets (`touche_par_les_balles`) : une balle ne les rencontre plus.

## Le joueur qui l'a posé — 0 ou 1. Sert à savoir qui subit quoi, et à la grâce
## du poseur si Adrien la demande un jour.
var poseur_id: int = -1

## Points de vie. Tout OBJET posé est destructible à la balle : c'est le contrat
## commun, et c'est ce qui donne une réponse à « j'ai vu quelque chose bouger ».
## Les gadgets diffus en sont exclus depuis le 2026-09-11 — voir
## `touche_par_les_balles` ; leurs points de vie ne servent plus à rien.
var pv: float = 1.0

## Ce gadget arrête-t-il les balles, ou se contente-t-il d'encaisser ?
##
## ⚠️ **Les deux existent, et la distinction est de conception.** Une mine ou un
## projecteur sont des objets durs : la balle s'y arrête. Un voile est une bâche
## tendue : la balle la déchire et poursuit. Confondre les deux ferait du voile
## un mur, c'est-à-dire l'inverse de ce qu'il raconte.
var arrete_les_balles: bool = true

## Ce gadget arrête-t-il les JOUEURS ? Faux pour tous, sauf le voile.
##
## Décision d'Adrien du 2026-09-10 pour le voile : « on ne peut pas passer au
## travers ». Le drapeau ajoute `MapGeometry.GADGET_BLOQUANT_LAYER` à la couche du
## gadget, et le masque des joueurs contient celle-là ; la couche des gadgets
## reste, pour que les balles le voient encore.
##
## ⚠️ **Lu dans `_ready()`**, comme `rayon` : une sous-classe le règle dans son
## `_init()`, jamais après l'entrée dans l'arbre.
##
## ⚠️ **Et lu à la POSE** (étape 28, 2026-09-11) : un gadget qui arrête les joueurs
## RECULE vers son poseur plutôt que de naître sur un corps, et se refuse faute de
## place — `GameState._reculer_hors_des_corps()`, sur la forme de
## `_forme_de_collision()`. Un second gadget bloquant en hérite sans rien écrire.
var arrete_les_joueurs: bool = false

## Une balle RENCONTRE-t-elle ce gadget ? Vrai pour les objets ; faux pour les
## gadgets DIFFUS — la suie, la poussière, la nappe de braises, la poudre.
##
## Décision d'Adrien du 2026-09-11 : « il ne faut pas pouvoir détruire un gadget
## gazeux ou diffus avec des balles ». Faux, le drapeau retire `GADGET_LAYER` de la
## couche du gadget : le `ShapeCast2D` de la balle ne le voit plus du tout — ni
## dégât, ni pas perdu, ni place prise dans la traversée bornée. Ce qui ARRÊTE une
## balle reste `arrete_les_balles` ; celui-ci dit si elle le rencontre.
##
## ⚠️ **Lu dans `_ready()`**, comme `arrete_les_joueurs` : réglé dans `_init()`.
var touche_par_les_balles: bool = true

## Le rayon du REPÈRE que le poseur voit autour de ce gadget, ou 0 : pas de repère.
##
## Étape 28 (2026-09-11) : réglé dans `_init()` par les gadgets dont le bord de la
## zone d'effet ne se lit pas au pixel dans le noir — la mine (72), les braises
## (68), le grésillement (240), la poudre (110). C'est la liste du plancher validé,
## tirée d'`IMPLEMENTATIONS` et tenue par `tools/test_tir_et_reserves.gd` : un
## onzième gadget doit s'y ranger d'un côté ou de l'autre. Le rayon est celui qui
## DÉCIDE l'effet, jamais une valeur voisine.
##
## ⚠️ **Lu dans `_ready()`**, comme `rayon`.
var rayon_repere: float = 0.0

## Ce pair montre-t-il la vue du poseur ? Posé par `GameState._do_spawn_gadget()`
## AVANT l'entrée dans l'arbre, comme `poseur_id` — un gadget ne nomme aucun
## autoload, il ne peut donc pas le savoir seul.
##
## Faux par défaut : un gadget monté hors du jeu (une suite, un banc) n'a pas de
## repère. En ligne, la machine de l'adversaire ne le crée donc JAMAIS : aucune
## bascule de rendu, aucune killcam ne peut le révéler — la logique du cadenas de
## torche, une information locale qui ne voyage pas.
var repere_ici: bool = false

const POINTS_REPERE := 96
const LARGEUR_REPERE := 1.5
## Ténu : la famille du viseur (`player.gd`), qui dit aussi « à moi seul ». Dosage à
## valider sur la planche, avec la largeur.
const ALPHA_REPERE := 0.28
## Profondeur ABSOLUE : au-dessus du sol (−1), des murs (0) et des traces de poudre
## (1), sous les gadgets (4) et les corps (10) — et donc SOUS la nappe des braises
## (4 + 3) : il ne s'y voit que là où la peinture ne couvre pas ou pâlit, soit
## exactement le bord qui manque. Voir le piège « Deux `z_index` de parents
## différents ne se comparent pas ».
const Z_REPERE := 2

var _repere: Line2D = null

## Ce gadget peut-il éblouir ? Recopié du profil de classe à la construction —
## par INSTANCE, jamais par type (décision d'Adrien, 2026-09-09) : on doit
## pouvoir éteindre l'éblouissement d'un gadget sans toucher aux autres.
var eblouit: bool = false

## Son éblouissement se LIT-il dans un faisceau, ou se déduit-il d'une distance ?
##
## Les deux régimes existent déjà dans `game_state._plafond_de_source()` : une
## source dirigée échantillonne le pixel du cookie, une source de proximité ne
## connaît que la distance. Une torche fantôme est du premier genre ; une mine ou
## une nappe de braises, qui crachent dans toutes les directions, du second.
var eblouissement_dirige: bool = false

## Jusqu'où ce gadget aveugle, en pixels — **régime de proximité seulement**.
##
## Sans effet quand `eblouissement_dirige` vaut vrai : c'est alors le faisceau
## lui-même qui décide, et un rayon posé à côté serait une seconde vérité.
var rayon_eblouissement: float = 0.0

## Ce gadget arrête-t-il la LUMIÈRE ?
##
## Vrai pour tous ceux qui montent un occluder, c'est-à-dire tous sauf la mine —
## un boîtier posé à plat sur le sol, vu de dessus, n'a rien à masquer.
##
## ⚠️ **Il faut que ce drapeau et `_monter_occluder()` disent la même chose**, et
## c'est `game_state._ligne_de_vue_depuis()` qui en dépend : le rayon
## d'éblouissement est masqué sur la couche des gadgets, donc un gadget qui ne
## bloque pas la lumière doit en être EXCLU — sans quoi il arrêterait
## l'aveuglement sans arrêter le faisceau, exactement l'inverse du défaut corrigé
## à l'étape 11.
var occulte_la_lumiere: bool = true

## La classe du poseur, pour les gadgets qui portent SA lumière. `null` partout
## ailleurs, et c'est le cas ordinaire.
##
## ⚠️ Elle vit ici et non dans la sous-classe parce que c'est le spawn qui la
## connaît : `GameState._do_spawn_gadget()` la pose avant l'entrée dans l'arbre.
## Une sous-classe ne peut pas aller la chercher — elle ne sait pas qui l'a posée.
var classe_du_poseur: WeaponData = null

## Secondes de vie, ou 0 pour « jusqu'à la fin de la manche ».
var duree_vie: float = 0.0

## Rayon de la forme de collision, en pixels. Les sous-classes le règlent avant
## `_ready()`.
var rayon: float = 12.0

## L'angle du gadget posé, RELATIF à la direction de visée du poseur.
##
## Un quart de tour par défaut : on plante l'objet **en travers** de son regard,
## pas dans son axe. C'est ce qui compte pour les deux gadgets de la famille A —
## une bâche dans l'axe du regard ne masque rien, et une plaque vue par la
## tranche ne projette pas de torse.
##
## ⚠️ **Une variable et non une constante** : les gadgets à symétrie de
## révolution qui viendront — mine, nappe de braises — la mettront à zéro, et
## une constante ne se surcharge pas.
var angle_pose: float = PI / 2.0

## À quelle distance du poseur le gadget se plante, en pixels.
##
## Devant, jamais sous les pieds : un objet posé à l'endroit exact où l'on se
## tient se confondrait avec le joueur pour toute la durée de la manche — y
## compris dans l'ombre qu'il découpe, qui est précisément l'information que ces
## deux gadgets fabriquent.
##
## ⚠️ **96 px, et la première valeur était 44.** Vérifié en capture, torche
## allumée : à 44 px le voile coupe le faisceau au ras du canon — le poseur
## s'aveugle lui-même et l'objet n'est plus un écran, c'est un mur qu'on se
## prend. À 96, soit une longueur et demie de corps, la bâche tombe hors du
## premier pas et masque ce qu'il y a DERRIÈRE elle, qui est ce qu'on lui
## demande. Le chiffre est une mesure, pas un goût.
const PORTEE_POSE := 96.0

var _age: float = 0.0

## Le slug de catalogue, posé par `GameState._do_spawn_gadget()`. Porté par
## l'instantané de killcam (étape 28, lot F) pour dire QUOI est irreconstructible
## quand ça arrive ; la copie, elle, se refait par le script (`etat_de_rejeu`).
## Vide pour un gadget créé à la main dans une suite ou un banc : c'est voulu, et
## c'est pourquoi la copie ne passe pas par lui.
var slug: String = ""

## Une copie de killcam (étape 28, lot F) : pilotée par l'instantané, sans physique,
## HORS du groupe « gadgets » et hors de la couche qui arrête les joueurs. Posé
## AVANT l'entrée dans l'arbre, comme `poseur_id` — voir `_ready()`.
var is_replay: bool = false

## La couche de collision d'avant le masquage de killcam, ou -1 : voir
## `masquer_pour_rejeu()`. ⚠️ **Zéro est une valeur légitime** (les gadgets diffus
## n'ont plus aucune couche), d'où la sentinelle négative.
var _couche_hors_rejeu: int = -1

signal detruit(gadget: GadgetBase)

## Étape 28, lot E (télémétrie des gadgets, 2026-09-11) — pourquoi un gadget est
## mort, tel que l'hôte le dit au client (`GameState.rpc_detruire_gadget`) : le
## client ne peut pas le deviner, son propre minuteur de fin de vie tombe un
## demi-aller-retour plus tard et il n'encaisse aucune balle.
const MORT_FIN_DE_VIE := 0
const MORT_BALLE := 1

## Étape 28, lot E — la CAUSE d'une perte de PV, portée par `Player.rpc_update_hp`.
## Ici et pas dans `Player` : un gadget ne nomme pas `Player` (une suite en
## `--script` cesserait de compiler), et `player.gd` lit déjà `GadgetBase`
## (`effacements_a`). Sans elle, le client ne sépare pas un PV de braises d'une
## balle du poseur : les deux arrivent par le même `rpc_update_hp`.
const DEGATS_BALLE := 0
const DEGATS_BRAISES := 1

## Étape 28, lot H — la CAUSE d'un allumage, portée par
## `GameState.rpc_allumer_gadget` (décision d'Adrien du 2026-09-12 : le comptage des
## mines devient exact avant la publication). Sans elle, l'ordre ne disait que « ce
## gadget s'allume » : un lecteur devait retrancher les mines abattues des allumages
## pour deviner les passages, ce qui ne donnait qu'un MAJORANT — une mine abattue
## meurt de son embrasement 1,6 s plus tard, et le match archivé avant ne lui compte
## aucune mort.
const ALLUMAGE_PASSAGE := 0
const ALLUMAGE_BALLE := 1

## Vrai quand une BALLE a décidé de sa mort. Posé chez l'hôte (`encaisser`, et
## `GadgetMine.encaisser` pour une mine abattue), lu par
## `GameState._sur_gadget_detruit()`.
var abattu_par_balle: bool = false


## Étape 28, lot E — le joueur (0 ou 1) que désigne un NOM de gadget, ou −1.
##
## ⚠️ **L'inverse EXACT du littéral de `GameState._do_spawn_gadget()`** :
## `g.name = "GadgetJ%d_%d" % [pid + 1, numero]`. Le littéral reste dans
## `game_state.gd` (`tools/test_classes.gd` le lit par son texte) ;
## `tools/test_telemetrie_gadgets.gd` relie les deux — il lit le littéral et éprouve
## l'aller-retour. L'hôte ET le client s'en servent pour attribuer une mort ou un
## allumage de gadget : le même calcul des deux côtés, sur la seule donnée que les
## deux ordres portent.
static func poseur_du_nom(nom: String) -> int:
	if not nom.begins_with("GadgetJ"):
		return -1
	var reste := nom.trim_prefix("GadgetJ")
	if not reste.contains("_"):
		return -1
	var n := reste.get_slice("_", 0)
	if not n.is_valid_int():
		return -1
	var pid := int(n) - 1
	return pid if pid == 0 or pid == 1 else -1


func _ready() -> void:
	# ⚠️ **Une copie de killcam n'est PAS un gadget pour le monde vivant** (étape 28,
	# lot F). Onze boucles lisent ce groupe — éblouissement, facteur de lampe, ligne
	# de vue, effets, bascule, « un gadget debout », pouls de tir, lueur des volumes.
	# Une copie dedans éblouirait, se ferait basculer, viderait la batterie au HUD, ou
	# brûlerait les joueurs téléportés sur le trajet rejoué. Filtrer site par site,
	# c'est sept filtres, et le huitième qu'on oublie. Les balles rejouées la
	# rencontrent par la PHYSIQUE, jamais par ce groupe.
	if not is_replay:
		add_to_group("gadgets")
	collision_layer = MapGeometry.GADGET_LAYER
	if arrete_les_joueurs:
		collision_layer |= MapGeometry.GADGET_BLOQUANT_LAYER
	if not touche_par_les_balles:
		collision_layer &= ~MapGeometry.GADGET_LAYER
	# ⚠️ Masque à ZÉRO : un gadget ne se déplace pas, il n'a personne à heurter.
	# Lui donner un masque le ferait participer aux résolutions de collision pour
	# rien, à chaque image, sur un corps statique.
	collision_mask = 0
	z_index = 4

	var forme := CollisionShape2D.new()
	forme.name = "Forme"
	forme.shape = _forme_de_collision()
	add_child(forme)

	_monter_occluder()
	_monter_visuel()
	_monter_repere()

	if is_replay:
		# L'instantané fait foi : ni âge qui court, ni fin de vie, ni effet, ni trace
		# posée. Même geste que la fusée copiée.
		set_physics_process(false)
		# ⚠️ **Le passé n'arrête personne.** Les vrais corps sont téléportés sur le
		# trajet rejoué (`GameState._process`) et `move_and_slide()` tourne encore hors
		# manche tant que la vitesse n'est pas nulle : un voile du passé pourrait
		# heurter un corps du présent. La couche des GADGETS reste, elle — les balles
		# rejouées doivent rencontrer la copie comme elles ont rencontré l'original.
		collision_layer &= ~MapGeometry.GADGET_BLOQUANT_LAYER


## Le repère du poseur : un cercle ténu du rayon d'effet, sur SA vue seule
## (étape 28, 2026-09-11). Rien si `rayon_repere` vaut 0 ou si ce pair ne montre
## pas la vue du poseur (`repere_ici`).
##
## ⚠️ **Non éclairé** (`materiau_peint_lumineux`) : un `light_mask` à 0 seul le
## laisserait noir sous le `CanvasModulate` de l'arène. ⚠️ **Sa couche est posée
## sur LUI** : un enfant n'hérite pas de la couche de son parent, et la racine du
## gadget garde la couche 1, qui passe dans les deux vues.
##
## En écran scindé, l'écran d'à côté le montre — accepté par Adrien le 2026-09-11 :
## « pas grave si en écran scindé l'autre le voit ». Aucun `_process` : le trait
## est bâti une fois, un appel de dessin par repère.
func _monter_repere() -> void:
	if rayon_repere <= 0.0 or not repere_ici:
		return
	var l := Line2D.new()
	l.name = "Repere"
	var pts := PackedVector2Array()
	for i in POINTS_REPERE:
		pts.append(Vector2.from_angle(TAU * float(i) / POINTS_REPERE) * rayon_repere)
	l.points = pts
	l.closed = true
	l.width = LARGEUR_REPERE
	l.antialiased = true
	l.default_color = Color(Charte.HALOGENE, ALPHA_REPERE)
	l.material = materiau_peint_lumineux()
	l.visibility_layer = couche_de_vue(poseur_id)
	l.z_as_relative = false
	l.z_index = Z_REPERE
	add_child(l)
	_repere = l


## La couche de visibilité de la VUE du joueur `pid` : 2 pour J1, 4 pour J2 — la
## règle de `player.gd` (`visual`, `visual_enemy`…), qui reste la source : les
## suites comparent aux nœuds du vrai joueur. Un pid hors de {0, 1} ne s'affiche
## NULLE PART et crie : la couche 1 serait les deux vues, une forme plausible qui
## se prend pour une intention.
static func couche_de_vue(pid: int) -> int:
	if pid != 0 and pid != 1:
		push_error("GadgetBase : aucune vue pour le joueur %d" % pid)
		return 0
	return 2 if pid == 0 else 4


## La forme de collision : un disque de `rayon`, dans le socle.
##
## ⚠️ **Elle doit dire la même forme que l'occluder**, et une sous-classe qui
## surcharge l'un surcharge l'autre. Une exception, écrite : le LEURRE, dont chaque
## forme suit la forme correspondante du joueur — une ombre en étoile, une zone de
## touche ronde (2026-09-11) ; l'éblouissement, lui, lit l'étoile (`regard_par_la_forme`).
## Le voile a vécu jusqu'au 2026-09-10 avec une
## ombre en bande de 8 px et une collision en DISQUE de 84 px de rayon — voir
## `GadgetVoile._forme_de_collision()` ; l'ombre habitée, jusqu'à l'étape 28
## (2026-09-11), avec une plaque de 36 × 6 px et un disque de 18 — voir
## `GadgetOmbre._forme_de_collision()`.
func _forme_de_collision() -> Shape2D:
	var cercle := CircleShape2D.new()
	cercle.radius = rayon
	return cercle


## L'occluder, pour qu'un gadget ne soit pas un trou de lumière au milieu de
## l'arène. Même geste que `training_target.gd`.
##
## ⚠️ Les sous-classes qui veulent une autre FORME d'ombre — le voile est une
## bande, l'ombre habitée une découpe de torse — surchargent cette méthode. C'est
## le seul endroit où la forme de l'ombre se décide, pour qu'il n'y en ait pas
## deux.
func _monter_occluder() -> void:
	var occ := LightOccluder2D.new()
	occ.name = "Occluder"
	var poly := OccluderPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var ang := (i / 16.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * rayon)
	poly.polygon = pts
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.occluder_light_mask = MapGeometry.WALL_LAYER
	add_child(occ)


## Le visuel. Vide dans le socle : un gadget sans sprite doit se VOIR absent,
## pas se faire remplacer par une forme plausible.
##
## ⚠️ **Aucun bouche-trou ici, et c'est délibéré.** Dessiner un disque de secours
## redonnerait un objet crédible, et un objet crédible se prend pour une
## intention — c'est la règle « câbler, taire, diagnostiquer » du dépôt, la même
## qui fait crier `WeaponData.get_torch_texture()` plutôt que fabriquer un
## dégradé.
##
## Chaque sous-classe décide donc de son visuel, et les deux façons sont
## légitimes tant que le choix est ÉCRIT : charger un sprite et crier s'il manque,
## ou dessiner l'objet quand sa forme finale est de l'ordre du trait — aucun
## gadget n'en relève depuis l'étape 26 : neuf portent leur image, le leurre celle
## de son poseur. Ce qui reste interdit est le troisième chemin : dessiner *en
## attendant* un sprite. Le premier chemin passe par `_poser_sprite()`.
func _monter_visuel() -> void:
	pass


## La texture d'une pièce de gadget, ou `null` — et alors un CRI.
##
## `piece` est le nom du fichier sans `gadget_` ni `.png` : voir
## `GadgetProfile.chemin_sprite_de()`, seul endroit où le chemin se forme.
func _texture_de(piece: String) -> Texture2D:
	var chemin := GadgetProfile.chemin_sprite_de(piece)
	if not ResourceLoader.exists(chemin):
		push_error("%s : sprite absent — %s" % [get_script().resource_path.get_file(), chemin])
		return null
	return load(chemin)


## Pose un sprite de gadget à sa taille PEINTE, 1 texel par unité de monde, éclairé
## comme le décor. Rend `null`, sans rien poser, si l'image manque.
##
## ⚠️ **L'image garde sa taille, même plus grande que la collision** — la bobine,
## la mine et la torche sont peintes à 28-30 px pour une collision de 16 à 18.
## Adrien a gardé l'écart le 2026-09-10, en connaissance de cause : une balle peut
## traverser le bord visible d'une mine.
func _poser_sprite(nom: String, piece: String) -> Sprite2D:
	var tex := _texture_de(piece)
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = nom
	sprite.texture = tex
	sprite.light_mask = MapGeometry.WALL_LAYER
	add_child(sprite)
	return sprite


## ⚠️ **L'âge court TOUJOURS, même sans durée de vie.** Il ne courait que pour
## les gadgets périssables, et `age()` — public, documenté « l'âge du gadget » —
## rendait donc zéro à vie pour les autres. La torche fantôme en dérive son
## balayage : elle serait restée parfaitement immobile.
func _physics_process(delta: float) -> void:
	_age += delta
	if duree_vie > 0.0 and _age >= duree_vie:
		detruire()


## Ce gadget MASQUE-t-il le corps de qui s'y tient — plus de sprite pour l'autre,
## plus d'ombre ? Faux dans le socle ; vrai pour la suie (Adrien, 2026-09-11).
##
## ⚠️ **Répond pour TOUS les gadgets** : `player.gd` le demande sans garde, dans
## la même boucle qu'`occultation_pour()`. Un gadget qui ne saurait pas répondre
## ferait planter le jeu à chaque image.
func masque_le_corps() -> bool:
	return false


## Un tir est parti de l'intérieur : le volume pulse en entier. Vide dans le socle.
##
## ⚠️ Appelé sans garde sur tous les gadgets, depuis `game_state._do_spawn_bullet`.
func diffuser_flash() -> void:
	pass


## Une balle vient de le traverser. Rien dans le socle : un objet dur arrête la
## balle, il n'a pas à trembler. Le voile, lui, est une toile, et elle bat.
##
## ⚠️ **Appelé chez TOUS les pairs** — chacun voit passer ses balles, l'hôte seul
## décide des dégâts. C'est pour ça qu'il ne doit toucher à rien de simulé.
func secouer() -> void:
	pass


## Encaisse des dégâts. Rend `true` si le gadget en meurt.
##
## L'hôte seul appelle ceci : la destruction est autoritaire, comme tout le
## reste. Le client la voit arriver par `GameState.rpc_detruire_gadget`.
##
## ⚠️ **Ce commentaire mentait jusqu'au 2026-09-10** : il disait « par la
## réplication du nœud », et aucun nœud de gadget n'était répliqué — le client
## détruisait ses gadgets avec ses propres balles, à ses propres instants.
func encaisser(degats: float) -> bool:
	pv -= degats
	if pv > 0.0:
		return false
	# Étape 28, lot E — la balle a décidé : la télémétrie la compte abattue.
	abattu_par_balle = true
	detruire()
	return true


## ⚠️ **Une seule mort par gadget** (étape 28, lot E, 2026-09-11). Sans garde, deux
## balles dans la même image (le second `encaisser` repasse sous zéro), ou un gadget
## remplacé qui atteint sa fin de vie avant sa libération, rappelaient `detruire()` :
## deux signaux, deux ordres au client, deux morts comptées.
func detruire() -> void:
	if is_queued_for_deletion():
		return
	detruit.emit(self)
	queue_free()


## Ce gadget demande-t-il à s'allumer, vu où sont les joueurs ?
##
## Faux dans le socle : la plupart ne se déclenchent pas. Seule la mine répond
## vrai aujourd'hui.
##
## ⚠️ **L'HÔTE SEUL appelle ceci** (`GameState._maj_gadgets()`), et le partage
## est délibéré : la DÉCISION vit dans le gadget, parce que c'est là que son
## rayon et son armement se lisent avec ce qu'ils veulent dire ; l'AUTORITÉ reste
## chez `GameState`, parce qu'elle appartient au réseau et à rien d'autre. Un
## gadget qui s'allumerait tout seul s'allumerait deux fois — une chez chaque
## pair, à deux instants différents.
func veut_s_allumer(_joueurs: Array) -> bool:
	return false


## Cette demande d'allumage vient-elle d'une BALLE ? (Étape 28, lot H.)
##
## Lue par `GameState.allumer_gadget()` : elle QUALIFIE la demande d'allumage en
## cours, elle ne la déclenche pas. Faux dans le socle, comme `veut_s_allumer()` — un
## gadget qui ne se déclenche jamais n'a pas de cause.
##
## ⚠️ **Elle doit répondre juste HORS de toute précondition**, et la première rédaction
## de ce commentaire disait le contraire (« juste après un `veut_s_allumer()` vrai, et
## seulement là », corrigé en revue le 2026-09-12) : la boucle de l'hôte
## (`_maj_gadgets`) passe bien par `veut_s_allumer()` d'abord, mais le photographe
## appelle `allumer_gadget()` directement pour mettre en scène une mine allumée
## (`tools/photographe.gd`, et c'est délibéré — c'est ce chemin-là qu'il photographie).
## Donc rien ne garantit qu'un état lu ici vienne d'être rafraîchi.
##
## ⚠️ **Elle doit suivre l'ordre de priorité de `veut_s_allumer()`**, et c'est tout ce
## qu'il y a à tenir : la mine y regarde `_touchee` AVANT la proximité, donc elle
## répond vrai ici dès qu'elle est touchée. Les deux réponses vivent dans le même
## fichier pour qu'on ne puisse pas en changer une sans voir l'autre.
##
## ⚠️ **Répond pour TOUS les gadgets**, comme `energie_relative()` :
## `GameState.allumer_gadget()` la lit SANS garde `has_method()`, qui changerait un
## oubli en « tout allumage est un passage » — muet, et faux dans la seule colonne
## que ce lot existe pour rendre exacte (CLAUDE.md, la fusion du 2026-09-09).
func allumage_par_balle() -> bool:
	return false


## L'ordre d'allumage, rejoué à l'identique chez les deux pairs.
func allumer() -> void:
	pass


## Ce que ce gadget FAIT aux joueurs, à chaque image RENDUE : `GameState._process()`
## → `_maj_gadgets()`, fps déplafonnés. ⚠️ `delta` varie donc d'une machine à
## l'autre : un effet qui agit PAR APPEL dépendrait du matériel — voir
## l'accumulateur de `GadgetBraises` (étape 28, 2026-09-11). Ce texte disait
## « chaque pas de physique » : c'était faux, et c'est ce qui a laissé la nappe
## verser un RPC et une lumière d'impact par image rendue.
##
## Vide dans le socle : la plupart ne font rien qu'exister et masquer. Seule la
## nappe de braises répond aujourd'hui.
##
## ⚠️ **L'HÔTE SEUL appelle ceci**, comme `veut_s_allumer()`, et pour la même
## raison. Un gadget qui infligerait des dégâts de lui-même les infligerait deux
## fois — une chez chaque pair — et le client verrait sa barre descendre deux
## fois plus vite que l'arbitrage.
func appliquer_effets(_joueurs: Array, _delta: float) -> void:
	pass


## La part de sa pleine lumière que ce gadget brûle en ce moment, entre 0 et 1 :
## ce qui multiplie son éblouissement de PROXIMITÉ (étape 28, 2026-09-11, Adrien :
## « l'aveuglement suit ce qui brûle » — la règle de la fusée, étendue aux
## gadgets). Un dans le socle : un gadget qui ne s'éteint pas brûle à plein.
##
## ⚠️ **Répond pour TOUS les gadgets**, comme `occultation_pour()` :
## `GameState._sources_eblouissantes()` le lit SANS garde. Un `has_method()` y
## changerait un oubli en inaction muette — CLAUDE.md, la fusion du 2026-09-09.
##
## ⚠️ Sans effet sur une source DIRIGÉE (la torche fantôme) : `_plafond_de_source()`
## ne lit le gain qu'au régime de proximité.
func energie_relative() -> float:
	return 1.0


## Combien ce gadget EFFACE ce qui se trouve à `pos`, entre 0 et 1.
##
## Zéro dans le socle : seuls les volumes — suie, poussière — répondent
## autrement. `player.gd` interroge tous les gadgets sans condition, exactement
## comme il interroge toutes les fusées.
##
## ⚠️ **C'est pour ça que la méthode vit ICI et pas seulement sur `GadgetVolume`.**
## La boucle des fusées est sans garde, et une session voisine a relevé le
## 2026-09-09 que le jour où un objet rejoindrait ce groupe sans savoir répondre,
## le jeu **planterait à chaque image**. Le socle répond, donc tout gadget répond.
func occultation_pour(_pos: Vector2) -> float:
	return 0.0


## Au-delà de quel masque un corps cesse de faire ombre (étape 27) : la moitié du
## nuage. En deçà l'ombre reste — un corps au bord de la suie n'y est pas caché.
## Une seule valeur pour le joueur ET le leurre, qui doit disparaître comme lui.
const SEUIL_OMBRE_MASQUEE := 0.5

## Ce qui efface un corps à `pos`, chacun entre 0 et 1 : `x` l'OCCULTATION (fumée
## de fusée, poussière — le sprite pâlit, l'ombre reste), `y` le MASQUE (la suie —
## le corps disparaît, et son ombre avec au-delà de `SEUIL_OMBRE_MASQUEE`).
##
## ⚠️ **Une seule règle pour le joueur et le leurre** (2026-09-11, trouvé en revue) :
## un leurre qui restait net dans la suie, où un vrai corps disparaît, se trahissait
## par ce qu'il avait EN PLUS. Les deux lisent donc cette fonction.
##
## Sans garde sur les membres des groupes, pour la raison qui fait vivre
## `occultation_pour()` dans le socle : tout gadget et toute fusée savent répondre.
static func effacements_a(arbre: SceneTree, pos: Vector2) -> Vector2:
	var occultation := 0.0
	var masque := 0.0
	for fusee in arbre.get_nodes_in_group("fusees"):
		occultation = maxf(occultation, fusee.occultation_pour(pos))
	for gadget in arbre.get_nodes_in_group("gadgets"):
		var o: float = gadget.occultation_pour(pos)
		if gadget.masque_le_corps():
			masque = maxf(masque, o)
		else:
			occultation = maxf(occultation, o)
	return Vector2(occultation, masque)


## Vrai quand la ligne de vue d'éblouissement doit lire l'OMBRE de ce gadget plutôt
## que sa collision — voir `coupe_le_regard()` et `GameState._ligne_de_vue_depuis()`.
## Le leurre seul (2026-09-11) : son ombre est une étoile, sa zone de touche un
## disque, et l'éblouissement doit suivre ce que la lumière montre.
var regard_par_la_forme: bool = false


## Le segment `de` → `vers` traverse-t-il l'ombre de ce gadget ? Lu seulement quand
## `regard_par_la_forme` est vrai. Faux dans le socle.
func coupe_le_regard(_de: Vector2, _vers: Vector2) -> bool:
	return false


## Ce gadget fait-il de l'ombre sous les lumières PORTÉES par le joueur `pid` —
## sa torche, son flash de tir (étape 28, lot G, 2026-09-12) ?
##
## Vrai dans le socle : un objet posé bouche la lumière de tout le monde. Le
## LEURRE dit non pour son poseur, parce que son occluder vit désormais sur la
## couche du corps de celui-ci, et qu'une torche n'ombre jamais le corps de qui la
## tient. `GameState._ligne_de_vue_depuis()` le lit pour que l'éblouissement suive
## l'ombre qu'on VOIT — c'est toute la raison d'être de `regard_par_la_forme`.
##
## ⚠️ Sans `has_method()` chez l'appelant : le socle répond pour tous. Un garde
## défensif transformerait une méthode absente en inaction muette.
##
## ⚠️ **Mais la PORTÉE de cette réponse est plus étroite que sa formulation, et il
## faut le savoir avant de la redéfinir ailleurs.** `_ligne_de_vue_depuis()` ne
## l'interroge que dans la branche des gadgets dont `regard_par_la_forme` est vrai
## — aujourd'hui le leurre, et lui seul, qui la redéfinit. Le `true` ci-dessous
## n'est donc consulté par personne : le rendre faux ne change rien, vérifié par
## sabotage le 2026-09-12, zéro suite rouge. **Redéfinir cette méthode sur un
## gadget dont le drapeau reste faux ne produirait aucun effet, sans erreur ni
## suite rouge** — le motif exact du garde `has_method()` consigné dans CLAUDE.md.
## Lever `regard_par_la_forme` fait partie du geste.
func fait_ombre_aux_lumieres_de(_pid: int) -> bool:
	return true


## Ce par quoi ce gadget multiplie l'énergie d'une lampe torche à `pos`.
##
## Un dans le socle — la lampe est intacte. Le grésillement du Parasite (la lampe
## saute) et la suie du Fumiste (la lampe tenue dedans y reste, étape 27)
## répondent autrement.
##
## ⚠️ **Il touche AUSSI l'éblouissement depuis le 2026-09-10.** Il ne touchait
## que le rendu tant que la lampe gardait 22 % : elle éclairait encore, elle
## éblouissait encore. Depuis qu'elle peut devenir noire, `GameState._lumiere_recue()`
## le lit chez l'hôte — on ne peut pas être aveuglé par une lampe qu'on voit
## éteinte. Voir `gadget_gresillement.gd`.
func facteur_de_lampe(_pos: Vector2) -> float:
	return 1.0


## Ce gadget s'allume-t-il et s'éteint-il à la demande de son poseur ?
##
## Faux dans le socle. Seul le grésillement répond vrai (2026-09-10) : sa touche
## le pose une fois, puis l'allume et l'éteint tant qu'il tient debout.
func est_basculable() -> bool:
	return false


## L'âge du gadget, en secondes. Public parce que les sous-classes en dérivent
## leur apparence — et parce qu'un banc doit pouvoir le forcer.
func age() -> float:
	return _age


static var _materiau_incandescent: CanvasItemMaterial

## Le matériau de ce qui BRÛLE — braises, lentille allumée, cœur de fusée.
##
## ⚠️ **`light_mask = 0` ne suffit PAS, et c'est le piège.** Un `CanvasItem` qui
## ne reçoit aucune lumière reste soumis au `CanvasModulate` de l'arène, lequel
## éteint tout : les charbons de la nappe sortaient NOIRS sur un sol qu'ils
## éclairaient eux-mêmes. Constaté à la capture.
##
## Ce qui émet doit être `UNSHADED` et additif, comme le cœur de la fusée le fait
## déjà — sa note le dit dans les mêmes termes : *« le cœur EST une source, il
## doit se voir dans le noir complet ; éclairé, il serait avalé hors de son
## halo »*. Le matériau est partagé, comme là-bas : il n'a pas d'état.
static func materiau_incandescent() -> CanvasItemMaterial:
	if _materiau_incandescent == null:
		_materiau_incandescent = CanvasItemMaterial.new()
		_materiau_incandescent.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_materiau_incandescent.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _materiau_incandescent


static var _materiau_peint_lumineux: CanvasItemMaterial

## Le matériau d'une image PEINTE lumineuse — la nappe de braises, depuis l'étape
## 26. Non éclairée par le décor, comme ce qui brûle, mais en MÉLANGE et non en
## addition : l'image porte déjà sa lueur. Additionnée à la lumière de la nappe,
## elle virait à la boule blanche où plus aucune pierre ne se lisait — vu à la
## capture, sur trois rendus comparés.
static func materiau_peint_lumineux() -> CanvasItemMaterial:
	if _materiau_peint_lumineux == null:
		_materiau_peint_lumineux = CanvasItemMaterial.new()
		_materiau_peint_lumineux.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _materiau_peint_lumineux


## Ce qu'il faut à la killcam pour REFAIRE ce gadget tel qu'il était rendu (étape 28,
## lot F). Les sous-classes AJOUTENT par `super()` — l'oublier retirerait les champs
## du socle, et `tools/test_rejeu.gd` le vérifie gadget par gadget.
##
## ⚠️ **Ce qui a été RENDU, pas ce qui le causait.** Recalculer au rejeu une énergie
## qui dépend de `facteur_de_lampe_a()` ou d'`effacements_a()` lirait le monde
## PRÉSENT — exactement le défaut que ce champ corrige.
##
## `script` : la killcam est LOCALE (chacun rejoue son propre enregistrement), la
## référence vaut donc dans cette partie et rebâtit la même classe par construction
## — sans table à tenir, sans `load()`, sans second chemin de choix de classe.
func etat_de_rejeu() -> Dictionary:
	return {
		"nom": String(name),
		"slug": slug,
		"script": get_script(),
		"poseur": poseur_id,
		"classe": classe_du_poseur,
		"graine": int(get("graine")) if "graine" in self else 0,
		"actif": bool(get("actif")) if "actif" in self else true,
		"pos": global_position,
		"rot": global_rotation,
		"rot_pose": global_rotation,
		"age": _age,
		"duree_vie": duree_vie,
		"energie": 0.0,
	}


## La copie prend l'état d'une image. Le socle pose le lieu et l'âge ; chaque
## sous-classe pose ensuite ce qu'elle a enregistré en plus.
func rejouer(d: Dictionary) -> void:
	_age = float(d["age"])
	global_position = d["pos"]
	global_rotation = float(d["rot"])


## Le gadget VIVANT se cache le temps du rejeu, et revient ensuite (étape 28, lot F).
## On masque au lieu de libérer, par décision d'Adrien : les ordres qui arrivent
## pendant la killcam — allumage, bascule, destruction — visent ainsi toujours un
## nœud qui existe.
##
## ⚠️ **Caché ET hors collision** : `hide()` éteint le sprite, les lumières et
## l'ombre, mais n'empêche pas une balle rejouée de s'arrêter sur un présent
## invisible. La couche d'origine est RETENUE, parce qu'elle n'est pas la même pour
## tous — le voile porte `GADGET_BLOQUANT_LAYER`, les diffus n'ont plus `GADGET_LAYER`.
func masquer_pour_rejeu(masque: bool) -> void:
	if masque:
		if _couche_hors_rejeu < 0:
			_couche_hors_rejeu = collision_layer
		collision_layer = 0
		hide()
	else:
		if _couche_hors_rejeu >= 0:
			collision_layer = _couche_hors_rejeu
			_couche_hors_rejeu = -1
		show()


## Ce gadget vivant est-il masqué par une killcam en cours ? Lu par
## `GameState._sources_eblouissantes()` : on ne peut pas être aveuglé par ce qu'on
## ne voit pas. Sans `has_method` chez l'appelant — le socle répond pour tous.
func est_masque_pour_rejeu() -> bool:
	return _couche_hors_rejeu >= 0
