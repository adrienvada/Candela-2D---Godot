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
const BulletCasingScript := preload("res://bullet_casing.gd")

@export var player_id: int = 0

## Ce joueur est un PNJ de l'aventure (chantier SOLO, S6) : un vrai `Player`, piloté par un `BotInputProvider`, que `GameState` pose
## par `AventurePartie`. Un PNJ porte `player_id` 1 — il joue, pour les lumières, les couches et les sons, le rôle d'adversaire du joueur
## humain (J2) — et ne se distingue de lui que par ce drapeau, lu à TROIS endroits : la perception d'un bot ne vise jamais un PNJ
## (`PerceptionBotNoeud._adversaire`), les balles d'un PNJ traversent les autres PNJ (`Bullet`), et un PNJ ne blesse pas un PNJ
## (`take_damage`). Faux partout ailleurs : le duel, en ligne comme en local, ne le pose jamais.
var est_pnj: bool = false
## Les dégâts d'une balle de ce PNJ, quelle que soit son arme : x au bord, y au centre (`bullet.gd`, `_hit_player`). Nul : ceux de l'arme —
## le duel, les boss. Posé par `AventurePartie` d'après `ProfilBot.degats_balle` (2026-10-04).
var degats_pnj: Vector2 = Vector2.ZERO

## La place de CE PNJ dans les réserves de `GameState` (fusées, gadget, batterie, recharge d'une minute) — S9b. Ces réserves sont
## indexées par `player_id`, et tous les PNJ en portent un (1) : sans place à eux ils partageaient celle de J2, semée sur la classe de
## J2 — un boss d'une autre classe perdait sa vraie réserve, un PNJ vidait celle d'un autre. `GameState.inscrire_un_pnj` la donne (2, 3,
## …) ; `-1` : aucune, le joueur est lu à son `player_id`, comme avant. Jamais posée hors de l'aventure.
## OMBRES, OM4b (Q86) — la place donne aussi au PNJ SA couche d'ombre : la poser (ou la rendre) réaccorde ses masques
## (`accorder_les_couches_de_pnj`).
var slot_reserve: int = -1:
	set(v):
		slot_reserve = v
		if is_inside_tree():
			accorder_les_couches_de_pnj()


## L'indice de CE joueur dans les réserves de `GameState` : sa place à lui s'il est un PNJ inscrit, son `player_id` sinon (le duel, en
## ligne comme en local, n'y change rien).
func slot_de_reserve() -> int:
	return slot_reserve if est_pnj and slot_reserve >= 0 else player_id

## La couche d'occluder de CE joueur, et celle de l'autre.
##
## Deux couches distinctes — 4 pour J1, 8 pour J2 — parce qu'une torche doit
## ombrer le corps d'en face **sans ombrer le sien**. Une couche commune rendait
## les deux indissociables : on ne pouvait qu'ombrer les deux ou aucun, et le
## jeu avait choisi aucun.
##
## ⚠️ **La règle a déménagé dans `CanauxLumiere` le 2026-09-12**, et ces quatre
## propriétés n'en sont plus que les noms locaux. Le leurre doit porter les mêmes
## couches qu'un corps — Adrien : « oui, qu'il ait l'ombre d'un corps » — et un
## gadget ne peut pas nommer `Player` : ce fichier s'appuie sur des autoloads, il
## ne compile pas dans une suite lancée en `--script`. Recopier `4 << id` là-bas
## aurait donné deux vérités pour une seule couche, dont l'une aurait vieilli.
var COUCHE_OCCLUDER_SIENNE: int:
	get: return CanauxLumiere.couche_ombre_corps(player_id)
var COUCHE_OCCLUDER_ADVERSE: int:
	get: return CanauxLumiere.couche_ombre_corps(1 - player_id)
## La couche du TORSE, réservée au rétroéclairage — 16 pour J1, 32 pour J2.
var COUCHE_TORSE: int:
	get: return CanauxLumiere.couche_ombre_torse(player_id)
var COUCHE_TORSE_ADVERSE: int:
	get: return CanauxLumiere.couche_ombre_torse(1 - player_id)
@export var speed: float = 260.0
@export var input_provider: InputProvider

var current_weapon: WeaponData

var hp: float = 100.0
var ghost_hp: float = 100.0

var shoot_cooldown: float = 0.0
var tw_reveal: Tween
var dazzle_amount: float = 0.0

## La source qui éblouit le plus ce joueur, cette image — ou `null`.
##
## ⚠️ **Le NIVEAU ne suffit pas, il faut la SOURCE.** Le voile penche vers ce qui
## aveugle : `ui._poser_voile()` dérive son relèvement de la POSITION de la
## source. Tant que l'éblouissement n'avait que deux sources croisées, l'appelant
## pouvait passer « l'autre joueur » en dur ; avec des sources déclarées, il faut
## dire laquelle a gagné le maximum. Sans ça le voile pencherait vers l'adversaire
## pendant qu'une lumière posée brûle derrière — et rien ne le verrait, aucune
## suite ne teste le relèvement.
##
## Posé par l'hôte dans `game_state._maj_eblouissement` (`retenir_la_source`). **Non
## répliqué**.
## OMBRES, OM1 (Q81, 2026-10-05) — et chez un CLIENT en ligne, posé pour son seul joueur
## local, par la même passe : le client ne calcule toujours pas l'éblouissement (l'hôte le
## réplique, `net_dazzle`), mais il en calcule la SOURCE, avec les mêmes fonctions — rien de
## neuf ne voyage sur le fil. ⚠️ **Jusque-là le client ne la connaissait jamais** : chez lui
## l'appareil de brouillage et le voile retombaient toujours sur l'adversaire
## (`game_state.source_eblouissante_ou`), si bien qu'une fusée qui l'aveuglait allumait le
## halo du brouillage sur la position de l'autre — le défaut corrigé chez l'hôte le
## 2026-09-09, que le client gardait faute de source.
var source_eblouissante: Node2D = null

## OMBRES, OM1 (Q81) — la source qui TIENT le niveau d'éblouissement de ce joueur : c'est le corps que son brouillage efface
## (`source_du_brouillage`). Ce n'est pas toujours la gagnante de l'image (`source_eblouissante`) :
##   • quand l'éblouissement redescend au-dessus du plafond de l'image, ce qui reste dans ses yeux vient de celle qui l'y a mis,
##     qu'elle se soit éteinte, détournée, ou qu'une autre tienne désormais un plafond plus bas ;
##   • un flash de bouche (`apply_dazzle`, `noter_la_source_du_pic`) nomme son tireur : son pic passe par-dessus le plafond et
##     s'y résorbe en un peu plus de deux dixièmes de seconde.
## Elle ne revient à la gagnante que lorsque l'éblouissement est retombé au plafond (`retenir_la_source`). Sans cette mémoire,
## un tireur noté une fois restait la source de toute redescente suivante : l'adversaire s'effaçait pendant que se dissipait
## l'éblouissement d'une fusée.
var _source_du_niveau: Node2D = null
## OMBRES, OM2 — vrai dès que l'étoile de la classe est posée (`_accorder_occluder_a_la_silhouette`) : le cercle provisoire de
## `_ready` ne l'écrase plus.
var _etoile_posee := false
## OMBRES, OM6 — l'instant (s) où la lumière de coup s'en va : sa courbe d'extinction (`Charte.Courbe.EXTINCTION`, sur une seconde)
## ne lui laisse alors qu'1,2 % de son énergie de départ — 0,006 de luminance au plus, en son centre : 1,5/255 en pâte brute (le
## défaut depuis Q83, 2026-10-05), qui ne coupe rien, et sous le premier seuil de la pâte D (0,02 à 0,05, `iso_pate.gdshaderinc`).
## Voir `rpc_update_hp`.
const FIN_LUMIERE_DE_COUP := 0.6
## Ce qu'il reste de la tenue d'un tir noté (secondes) : pendant `TENUE_DU_TIR`, la source reste le tireur même si son pic ne
## s'est pas encore montré. Chez le client, le tir arrive par un RPC et le pic par `net_dazzle`, synchronisé à 30 Hz : sans
## tenue, la passe de l'image suivante rendait la source aux lampes avant que le pic n'arrive. Chez l'hôte le pic est immédiat,
## la tenue ne change rien ; une seule règle des deux côtés.
var _tenue_du_tir := 0.0
## Trois intervalles de synchronisation de `net_dazzle` (30 Hz), moins que la résorption d'un pic à bout portant (0,225 s).
const TENUE_DU_TIR := 0.1

var current_ammo: int = 10
var is_reloading: bool = false
var reload_time_left: float = 0.0

## Le ROOT — chantier CLASSES, étape 2. Secondes restantes d'immobilisation
## après un tir. Zéro le reste du temps.
##
## ⚠️ **Rien de ceci ne part sur le fil, et il ne faut rien y mettre.** Le patron
## est celui que `lancer_fusee()` porte déjà quelques centaines de lignes plus
## bas : « le cooldown de tir existant porte ce désarmement — non répliqué,
## simulé identiquement chez l'hôte et dans la prédiction client, comme pour le
## tir ». `shoot()` tourne des DEUX côtés — le client prédit son propre tir —
## donc le compteur tombe juste chez les deux pairs sans qu'on transmette quoi
## que ce soit. Y ajouter un octet par tick serait payer pour une valeur qui est
## déjà bonne, et créer une divergence possible là où il n'y en a aucune.
##
## ⚠️ **Il ne bat que pendant le jeu actif.** Le bloc qui le décrémente vit après
## deux `return` anticipés : rien n'y tourne pendant le décompte de manche ni
## pendant la séquence de fin. Le rechargement gèle déjà de la même façon, et
## c'est cohérent — mais il faut le savoir, parce qu'aucune suite ne le dit.
var _root_restant: float = 0.0

## La durée du root EN COURS, gardée à côté de son compteur.
##
## ⚠️ **Pas `current_weapon.root.duree`.** La rampe se déduit de la durée du root
## qu'on subit, pas de celui qu'on subirait si on tirait maintenant : changer
## d'arme pendant un root en cours ferait sauter le facteur d'un coup, au milieu
## de la reprise. `equip_weapon` remet les deux à zéro pour la même raison — mais
## la remise à zéro protège du cas franc, ce champ protège du cas glissant.
var _root_duree: float = 0.0
var current_spread_bloom: float = 0.0
var _reload_presse: bool = false

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

## BF1 (2026-09-07) — les trois cotes du bandeau qui vivaient en littéraux dans
## `die()`. Elles n'y étaient pas fausses ; elles y étaient **inatteignables**,
## et c'est ce qui a laissé le cadrage sans banc pendant des semaines.
##
## `ELEVATION` : ce que la plaque flotte au-dessus du cadavre à sa naissance.
## `MONTEE` : ce qu'elle gagne pendant ses 1,5 s de vie — **la même valeur que
## le tween plus bas, et c'est tout l'objet de la constante** : le cadrage doit
## viser l'arrivée, pas le départ.
## `MARGE_CADRE` : la respiration entre la plaque et le bord de la vue, assez
## large pour que la pointe de la flèche (`DEBORD_FLECHE` × `enfle`) y tienne.
const ELEVATION_BANDEAU := 30.0
const MONTEE_BANDEAU := 100.0
const MARGE_CADRE_BANDEAU := 24.0

## La flèche de BF3, en unités du bandeau (donc multipliées par `enfle` à
## l'écran). `TAILLE` va de la base à la pointe, `DEBORD` dit de combien la
## pointe dépasse le bord de la plaque : le reste du triangle chevauche le
## cartouche, ce qui le fait lire comme une languette et non comme un satellite.
const TAILLE_FLECHE := 34.0
const DEBORD_FLECHE := 10.0


## BF1 — **où la plaque doit se poser pour tenir dans une vue.**
##
## `geometrie_du_bandeau()` juste au-dessus dit la TAILLE du bandeau ; celle-ci
## dit sa PLACE. Les deux manquaient pour la même raison — le calcul vivait
## dispersé dans `die()`, donc il fallait tuer un joueur pour l'exécuter — et le
## second défaut a survécu à la correction du premier : **DA4.4 a réglé la
## largeur, jamais la position.** Le code supposait depuis toujours qu'on meurt
## là où l'on regarde ; c'est vrai du mourant, jamais de celui qui tue à 900 px.
##
## ⚠️ **C'est la plaque FINALE qui doit tenir, pas celle de la naissance.** Le
## bandeau enfle jusqu'à `enfle` et monte de `MONTEE_BANDEAU` en 1,5 s. Un
## cadrage calculé sur la position de départ et sur la taille du mot ressort du
## cadre une seconde plus tard, et rien au banc ne le dirait. `plaque_finale`
## vaut donc `plaque * enfle`, et `elevation` compte déjà la montée.
##
## ⚠️ **`vue` est le rectangle du MONDE que la caméra montre, et il n'a pas la
## même taille selon le mode** : 957×1080 par vue en écran scindé, mais
## 1920×1080 quand le chantier R rend le duel dans la racine — l'aire 2D de la
## fenêtre en `keep`, pas les 1916 du `SubViewport`. Il se **mesure** sur la
## cible réelle de la caméra (`_rect_monde_de_la_vue()`), il ne se suppose pas.
##
## Un rectangle de taille nulle vaut « je ne sais pas cadrer » : l'ancre est
## rendue telle quelle, sans flèche. C'est le filet de `die()`, pas un cas
## d'erreur.
##
## Rend `centre` (où la plaque finale doit être centrée), `bord` (de quel côté
## elle s'est accrochée, -1/0/+1 par axe), `hors_champ` (le cadavre est-il
## invisible dans cette vue) et `direction` (unitaire, vers le cadavre ;
## `Vector2.ZERO` quand aucune flèche n'a de sens).
static func cadrage_du_bandeau(point_mort: Vector2, vue: Rect2,
		plaque_finale: Vector2, elevation: float) -> Dictionary:
	var ancre := point_mort + Vector2(0.0, -elevation)
	if vue.size.x <= 0.0 or vue.size.y <= 0.0:
		return {"centre": ancre, "bord": Vector2i.ZERO,
			"hors_champ": false, "direction": Vector2.ZERO}

	var utile := vue.grow(-MARGE_CADRE_BANDEAU)
	var demi := plaque_finale * 0.5
	var bas := utile.position + demi
	var haut := utile.end - demi
	# ⚠️ **Une vue plus étroite que la plaque rendrait `bas > haut`**, et
	# `clampf()` y répondrait par n'importe quoi — c'est le genre de renversement
	# qu'aucun essai à la main ne rencontre et qu'un nom d'arme un peu long
	# provoque. On recentre alors : la plaque déborde des deux côtés à parts
	# égales, ce qui est le moins faux des débordements.
	var centre := Vector2(
		utile.get_center().x if bas.x > haut.x else clampf(ancre.x, bas.x, haut.x),
		utile.get_center().y if bas.y > haut.y else clampf(ancre.y, bas.y, haut.y))

	# De quel côté le cadrage a-t-il retenu la boîte. Le seuil d'un demi-pixel
	# évite qu'un arrondi fasse dire « accroché » à une boîte qui n'a pas bougé.
	var ecart := ancre - centre
	var bord := Vector2i(
		0 if absf(ecart.x) < 0.5 else int(signf(ecart.x)),
		0 if absf(ecart.y) < 0.5 else int(signf(ecart.y)))

	# ⚠️ **La flèche se décide sur le CADAVRE, pas sur la boîte.** Le cadrage
	# retient la plaque bien avant que le mort sorte du champ — sinon elle
	# dépasserait — et pointer du doigt un corps que l'on voit très bien est du
	# bruit. Le critère est donc « le point de mort est-il hors de la vue ».
	var hors_champ := not vue.has_point(point_mort)
	var direction := Vector2.ZERO
	if hors_champ:
		var v := point_mort - centre
		if v.length_squared() > 0.0001:
			direction = v.normalized()
		else:
			hors_champ = false
	return {"centre": centre, "bord": bord,
		"hors_champ": hors_champ, "direction": direction}

## V2.9 — Distance à l'axe du dernier tir jugé fatal, écrite par la balle qui
## l'a simulé ici, consommée (et remise à -1) par die(). Cosmétique : chez le
## client c'est la simulation locale qui parle, pas l'arbitrage de l'hôte.
var last_fatal_perp: float = -1.0

var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var shake_time: float = 0.0

var vignette_mat: ShaderMaterial

## Les calques d'ÉCRAN de ce joueur — vignette de dégâts, flash de mort.
##
## ⚠️ **Un `CanvasLayer` s'attache au VIEWPORT de son parent, pas au monde.**
## Enfant du joueur, donc de l'arène, donc de `SubViewport1`, il ne se dessinait
## que dans cette sous-vue : invisible pour J2 en écran scindé (sa vue est
## `SubViewport2`), et invisible pour TOUT LE MONDE en vue unique, où les
## sous-vues sont arrêtées et où la racine rend le duel (chantier R). Adrien,
## le 2026-09-11, sur la vignette : « je ne l'ai pas vue ». Ces calques sont
## désormais logés par `GameState.accueillir_calque()` dans le viewport qui
## rend vraiment ce joueur, et relogés à chaque accord des vues.
var calques_ecran: Array[CanvasLayer] = []

## OMBRES, OM3 (chantier OMBRES, 2026-10-04) — l'ENVELOPPE du recul, à la place d'un tirage. Pendant le recul, la torche tirait
## une énergie au hasard entre 1,5 et 2,0 à chaque pas de physique (`randf_range`, 60 Hz) : un papillotement que la pâte D faisait
## sauter de palier en palier — jusqu'à 21 255 pixels hors des corps au-delà de 8 niveaux entre deux images consécutives (banc
## d'OM0 : le seul vrai scintillement trouvé). L'enveloppe garde le geste — la lampe plonge au coup et remonte pendant le recul —
## sans le hasard : `RECUL_CREUX` au coup, une remontée douce jusqu'à `RECUL_SORTIE` à la fin du recul, d'où le retour au souffle
## reprend comme avant. Sa moyenne sur le recul est celle du tirage (1,75) : la lampe n'est au total ni plus sombre ni plus claire.
## Fonction du seul temps de recul qui reste, et elle ne puise plus dans le hasard global à chaque pas.
const RECUL_CREUX := 1.5
const RECUL_SORTIE := 2.0
## La durée du recul en cours, prise quand il s'arme — un tir, une fusée, un gadget : tout ce qui pose `shoot_cooldown`.
var _recul_duree := 0.0
## Le compteur de recul vu au dernier pas de physique torche allumée : il REMONTE quand un recul s'arme ou s'allonge.
var _recul_vu := 0.0

## L'énergie de la torche AVANT toute atténuation : l'état lissé, qui plonge au
## coup et remonte (`_enveloppe_de_recul`) puis revient à 2,5. `flashlight.energy`
## en est la présentation, une fois le grésillement appliqué — voir le bloc qui
## les sépare, et pourquoi.
## OMBRES, OM3b (Q84, Adrien, 2026-10-05 : « Retirer ») — elle ne RESPIRE plus : le
## souffle de ±3 % sur un bruit lent (V5.4) est retiré, avec le bruit qui le portait.
var _energie_torche: float = 2.5
## Le facteur de lampe APPLIQUÉ à la dernière image torche allumée — le minimum des
## gadgets, calculé plus bas. Lu par la killcam (étape 28, lot F) : le fantôme rejoue
## la lampe telle qu'elle était rendue, sans une troisième copie de la règle du
## minimum. Torche éteinte, la valeur reste figée : sans effet, la lampe du fantôme
## suivant alors `p1_light` / `p2_light`.
var facteur_de_lampe_rendu: float = 1.0
## V5.6 — la rétrodiffusion « respire » au pas : bosse brève, résorbée seule.
const BACKSCATTER_STEP_PULSE := 0.35
var _backscatter_pulse: float = 0.0
## V5.5 — cadence d'émission de la poussière du faisceau.
const DUST_INTERVAL := 0.12
var _dust_accum: float = 0.0

var flashlight_on: bool = false

## La suie (étape 27) : ce qu'on garde de soi pour soi au cœur du nuage — on s'y
## devine encore. Le seuil au-delà duquel le corps cesse de faire ombre vit dans le
## socle des gadgets (`GadgetBase.SEUIL_OMBRE_MASQUEE`) : le leurre le lit aussi.
const PART_SOI_DANS_LA_SUIE := 0.6
var _ombre_coupee := false
## OMBRES, O11 — l'ombre que la MORT coupe (étoile et disque de torse), à part de celle que la suie coupe : les deux se cumulent,
## et l'une ne doit pas rendre ce que l'autre retire. Tenue par `_accorder_l_ombre_a_la_vie`, à chaque image.
var _ombre_du_mort := false
## L'étoile de ce corps, dans SA canvas — Q42 : son capteur ne la voit pas (voir `EtoileDeCorps`). `null` avant `_ready()`.
var _etoile_de_corps: EtoileDeCorps
## L'opacité que le brouillage donne au pointeur et aux révélations, posée en
## physique ; `_process` la compose à chaque image avec le masque de la suie.
var _alpha_brouillage := 1.0
## Le masque de la suie à la position du joueur, relevé à la dernière image : le
## tir le lit pour étouffer son éclat (`trigger_shoot_visuals`).
var _masque_ici := 0.0
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

## ── La posture accroupie — chantier MURS BAS, étape MB2 (2026-09-14) ─────────
##
## Règles d'Adrien : « l'accroupi ralentit fortement, étouffe les pas, et se lit à
## sa silhouette plus une marque HUD pour soi ». Simulée comme le déplacement :
## l'hôte l'applique depuis le bit reçu, le client la prédit depuis sa propre
## bascule, l'adversaire l'affiche depuis les instantanés. Balles et lumière à deux
## hauteurs, et l'enjambement, viennent en MB3.
##
## Vitesse fixée par Adrien au prototype (H-MB0) : ×0,25, soit 65 px/s.
const FACTEUR_VITESSE_ACCROUPI := 0.25
## « Silhouette plus basse et ramassée » : les cinq vues du corps réduites d'un
## cinquième. Visuel seulement — la zone de touche et l'ombre du corps ne changent
## pas en MB2 (les balles à deux hauteurs sont l'objet de MB3).
const ECHELLE_SILHOUETTE_ACCROUPIE := 0.8
var accroupi: bool = false
## Répliquée hôte→client, comme `net_flashlight_on`.
var net_accroupi: bool = false

## ── L'enjambement — chantier MURS BAS, étape MB3b (2026-09-14) ───────────────
##
## « On enjambe un mur bas avec croix, lentement et en faisant du bruit. » Geste
## choisi par Adrien : TENIR la touche en poussant vers le muret ; lâcher arrête
## avant de monter dessus. Pendant la traversée : debout, 65 px/s (égalité avec
## l'accroupi assumée par Adrien au H-MB0), pas de tir.
const FACTEUR_VITESSE_ENJAMBEMENT := 0.25
## Vrai dès qu'on pousse vers un muret en tenant la touche, puis tant que le corps
## le chevauche (ISO11, L1 : un chevauchement sans geste n'ouvre rien).
var enjambe: bool = false
## Nombre de murets enjambés — le bruit joué, compté pour les suites.
var enjambements: int = 0
var _sur_muret_avant := false

# La torche est répliquée, pas simulée, côté non-autoritaire : on détecte son
# changement ici pour que le son suive dans tous les modes.
var _torch_audio_state: bool = false
## État précédent du verrou de torche, pour ne vibrer qu'au FRANCHISSEMENT du
## cran plein (armement ET désarmement), pas à chaque image où il reste tenu.
var _torch_locked_prev: bool = false

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
## L'étoile de bouche : la petite lumière d'encre du coup (chantier TIR, étape B) — voir `_ready`.
var etoile_de_bouche: PointLight2D
@onready var muzzle = $Muzzle

var aim_cast: RayCast2D
var aim_line: Line2D
@onready var shoot_sound = $ShootSound
var step_distance_accumulated: float = 0.0
## SON VISIBLE — le temps passé à marcher depuis le dernier pas (seules les images
## où l'on s'est vraiment déplacé comptent), pour en tirer l'allure du pas.
var _temps_du_pas: float = 0.0

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

## ## La planche de marche peinte (DA2.4, câblée le 2026-09-01)
##
## Quatre poses par arme, jouées **sur le compteur de distance** et jamais sur
## une horloge : la pose change au même instant que le son du pas, l'empreinte au
## sol et la bosse de rétrodiffusion, parce que tous les quatre lisent
## `step_distance_accumulated`. Une planche cadencée par le temps dériverait de
## tout ça à la première variation de vitesse.
##
## ⚠️ **Rien n'a besoin de passer sur le fil.** La pose se dérive d'un compteur
## que les DEUX côtés calculent déjà : le bloc du pas vit hors de `can_move`
## exprès, pour que l'adversaire interpolé produise les mêmes traces que le
## joueur simulé. Ajouter la pose aux RPC serait payer un octet par tick pour une
## valeur qui tombe juste toute seule — et créer une divergence possible là où il
## n'y en a aucune.
const MARCHE_PEINTE := true
## Les quatre poses de l'arme courante, préchargées. Vides si la planche manque :
## le jeu retombe alors sur le sprite statique, ce qu'il faisait avant ce câblage.
var _poses_peintes: Array[Texture2D] = []
var _poses_silhouettes: Array[Texture2D] = []
## Compteur de pas. `_foot_side` alterne déjà, mais il ne compte que modulo 2 —
## une planche de quatre poses a besoin de savoir lequel des quatre.
var _pas := 0
## Quelle pose est POSÉE sur les polygones en ce moment : -1 pour le statique.
## Sans cet état on réaffecterait cinq textures à chaque image pour rien.
var _pose_posee := -1
## Les deux textures du repos, gardées au changement d'arme.
var _sprite_peint_statique: Texture2D = null
var _sprite_sil_statique: Texture2D = null
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
	rep_config.add_property(NodePath(".:net_accroupi"))
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
	# Layer 2 : Sprite Ennemi (Rétrodiffusion, Torche, Sparks, Balles), plus le
	# canal de la vue adverse pour que le halo de l'autre le révèle de près —
	# chez l'autre seulement (Adrien, 2026-09-11). Voir canaux_lumiere.gd.
	visual_enemy.light_mask = CanauxLumiere.masque_vue_adverse(player_id)
	visual_enemy_ptr.light_mask = CanauxLumiere.masque_vue_adverse(player_id)
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
		
	# Setup Damage Vignette UI
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "CalqueVignette"
	_loger_calque(ui_layer)
	
	var vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Use the correct visibility layer so it only shows on the player's own viewport
	vignette_rect.visibility_layer = 2 if player_id == 0 else 4
	
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = SHADER_VIGNETTE
	# DA5.2 — poussé explicitement plutôt que confié au défaut du shader :
	# les deux valent la même chose aujourd'hui, mais un appelant qui ne pousse
	# pas sa couleur est celui qui a laissé passer le rouge primaire pur
	# corrigé par ce chantier (« un défaut périmé se lit comme une intention »).
	vignette_mat.set_shader_parameter("vignette_color",
		Vector4(Charte.ROUGE.r, Charte.ROUGE.g, Charte.ROUGE.b, 1.0))
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
	flashlight.position = LENTILLE_LAMPE

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
	#
	# Q65 — et le bit RÉCEPTEUR de l'ADVERSAIRE (`CanauxLumiere.recepteur_retro`, jamais le sien) : le capteur de soi de l'autre
	# joueur le porte, donc reçoit les ombres de cette rétrodiffusion — les murs arrêtent enfin sa lumière jusqu'à son corps —,
	# et le nôtre ne reçoit jamais celles de la nôtre. Aucun occluder ne porte ce bit : rien ne s'ajoute aux ombres du jeu.
	body_light.shadow_item_cull_mask = 1 | 2 | COUCHE_TORSE | COUCHE_TORSE_ADVERSE \
		| CanauxLumiere.recepteur_retro(1 - player_id)
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
	# Le corps d'en face fait ombre sous ma lueur comme sous ma torche, et son
	# sprite reçoit cette ombre (Adrien, 2026-09-14). Voir canaux_lumiere.gd.
	ambient_light.shadow_item_cull_mask = CanauxLumiere.masque_ombre_halo(player_id)
	ambient_light.range_item_cull_mask = CanauxLumiere.canal_de_vue(player_id)
	add_child(ambient_light)
	
	# The main occluder is configured as a perfect circle on layer 3 (value 4).
	# This ensures it blocks the main flashlight (mask 1|4) and bullets.
	var pts = PackedVector2Array()
	for i in range(16):
		var ang = (i / 16.0) * TAU
		# ⚠️ Cercle PROVISOIRE, écrasé par l'étoile de la silhouette au premier
		# `equip_weapon()` (`_accorder_occluder_a_la_silhouette`). Le lire comme
		# « l'ombre du joueur » a fait donner un disque au leurre (étape 15).
		pts.append(Vector2(cos(ang), sin(ang)) * 18.0)
		
	if has_node("LightOccluder2D"):
		var main_occ = get_node("LightOccluder2D")
		# OMBRES, OM1 — l'occulteur de l'étoile, par la charte (culling, ressource neuve), même pour ce cercle provisoire.
		# OMBRES, OM2 — ⚠️ **seulement si aucune étoile n'est encore posée** : `equip_weapon`, appelée plus haut dans ce même
		# `_ready`, a déjà pu poser celle de la classe — le cercle l'écrasait alors jusqu'au changement d'arme suivant (trouvé en
		# étudiant OM2 : un corps équipé avant d'entrer dans l'arbre gardait le cercle de 18 px).
		if not _etoile_posee:
			main_occ.occluder = Charte.occulteur_d_etoile(pts)
		# Une couche par joueur : c'est ce qui permet à une torche d'ombrer
		# l'autre corps sans ombrer le sien. Voir `flashlight.shadow_item_cull_mask`.
		main_occ.occluder_light_mask = COUCHE_OCCLUDER_SIENNE
		# Q42 — l'étoile quitte le monde partagé pour SA canvas : elle ombre toujours le sol, les murs et le corps d'en face,
		# mais plus le capteur de CE corps. Le nœud reste le même (masque, forme, `visible`) : voir `etoile()`.
		_etoile_de_corps = EtoileDeCorps.monter(self, main_occ)
		
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
	# Chantier TIR, étape B (2026-10-05) — la lumière de bouche ÉCLAIRE : le masque `ECLAT`, posé une fois pour toutes
	# sur 800 px. Les trois images d'encre de DA2.3 passent à l'ÉTOILE DE BOUCHE, juste en dessous.
	#
	# ⚠️ **`ECLAT` et pas une texture à soi, et ce n'est pas qu'une question de style.** L'atlas des textures de
	# lumière 2D se reconstruit EN ENTIER à chaque texture inédite (audit d'optimisation, V8 « D1 ») : `ECLAT` est déjà
	# tenue en permanence par les lumières du pool de particules, le grand flash n'y ajoute rien.
	LightTextures.poser(muzzle_flash, LightTextures.ECLAT,
		LightTextures.EMPREINTE_FLASH)
	muzzle_flash.color = Charte.AMBRE
	muzzle_flash.offset = Vector2.ZERO
	# L'ÉTOILE DE BOUCHE : la lumière de bouche d'AVANT, inchangée — 64 px, les trois images d'encre de DA2.3, l'énergie
	# de l'arme en descente droite. ⚠️ **Elle n'est pas un doublon, et elle a été retirée puis rendue le même jour.** En
	# vue iso (le jeu par défaut), l'éclat DESSINÉ n'est jamais montré — `IsoVolumes._suivre_eclats` le sort des lightmaps
	# et pose deux lueurs à l'arme : la forme d'étoile qu'on voyait au tir, c'était CETTE lumière, couchée au sol. La
	# première version du chantier TIR l'avait remplacée par le grand flash ; les captures du 2026-10-05 ont montré
	# l'étoile disparue (« un muzzle flash qui se VOIT », demandait Adrien). Le grand flash éclaire, l'étoile signe.
	# Créée une fois, jamais par tir ; mêmes masques que la lumière de bouche. Ses images basculent au tir comme avant :
	# ce coût d'atlas, que l'audit n'a pas mesuré, est celui d'aujourd'hui, ni plus ni moins.
	etoile_de_bouche = PointLight2D.new()
	etoile_de_bouche.name = "EtoileDeBouche"
	etoile_de_bouche.position = muzzle_flash.position
	etoile_de_bouche.enabled = false
	etoile_de_bouche.shadow_enabled = true
	etoile_de_bouche.shadow_item_cull_mask = muzzle_flash.shadow_item_cull_mask
	etoile_de_bouche.range_item_cull_mask = muzzle_flash.range_item_cull_mask
	etoile_de_bouche.color = Charte.AMBRE
	LightTextures.poser(etoile_de_bouche, LightTextures.FLASH[0], LightTextures.EMPREINTE_ETOILE)
	add_child(etoile_de_bouche)

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
	# Gardées : le retour au repos y revient, et il ne doit pas relire le disque.
	_sprite_peint_statique = t_peint
	_sprite_sil_statique = t_sil
	# ⚠️ Passe par `empreinte_sprite()` — voir `DENSITE_SPRITES`. Bâtir le quad
	# sur `get_width()` brut est le piège que R6 a levé : la recuisson d'un asset
	# redimensionnerait le joueur.
	var demi := Vector2(Charte.empreinte_sprite(t_peint.get_width()),
		Charte.empreinte_sprite(t_peint.get_height())) * 0.5
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
	#
	# ⚠️ **L'occluder reste sur la silhouette STATIQUE, et ce n'est pas un
	# raccourci.** Le recalculer à chaque pose coûterait un décodage d'image et
	# 32 rayons balayant les pixels, plusieurs fois par seconde — mais surtout
	# **l'ombre portée changerait de forme quatre fois par cycle**. L'écart entre
	# poses vaut au plus 4 px, à l'arrière du corps : invisible dans une ombre,
	# cher à calculer, et une ombre qui respire se lit comme un défaut.
	_accorder_occluder_a_la_silhouette(slug)

	_precharger_la_planche(slug)
	return true


## Les quatre poses de marche, chargées d'un coup au changement d'arme.
##
## ⚠️ **Préchargées, jamais à la volée.** C'est le même geste que les shaders
## quelques lignes plus haut, et pour la même raison : un `load()` au premier pas
## d'une manche compilerait et décompresserait pile au moment où le joueur bouge,
## c'est-à-dire pile sur l'action. Huit textures par arme, une seule fois.
##
## L'absence n'est pas une erreur : sans planche, le jeu garde le sprite statique
## et son roulis — exactement ce qu'il faisait avant le 2026-09-01. Mais elle se
## DIT, parce qu'un repli muet ne se distingue pas d'un câblage qui ne marche pas.
func _precharger_la_planche(slug: String) -> void:
	_poses_peintes.clear()
	_poses_silhouettes.clear()
	_pose_posee = -1
	if not MARCHE_PEINTE:
		return
	var peintes: Array[Texture2D] = []
	var silhouettes: Array[Texture2D] = []
	for n in range(1, 5):
		var a := SPRITES + "%s_marche_%d.png" % [slug, n]
		var b := SPRITES + "%s_marche_%d_silhouette.png" % [slug, n]
		if not ResourceLoader.exists(a) or not ResourceLoader.exists(b):
			push_warning("player : planche de marche incomplète pour « %s » — "
				% slug + "le sprite statique est conservé")
			return
		peintes.append(load(a))
		silhouettes.append(load(b))
	_poses_peintes = peintes
	_poses_silhouettes = silhouettes


## Pose l'image d'une pose sur les cinq vues. `idx` vaut -1 pour le statique.
##
## ⚠️ **Aucun quad n'est reconstruit et aucune UV n'est recalculée**, et c'est ce
## qui rend ce câblage bon marché. `_calculate_uvs()` dérive les UV des bornes du
## POLYGONE, en pixels de texture : tant que la pose a exactement les dimensions
## du statique — ce que `test_planche_marche` exige et vérifie — échanger la
## texture suffit. C'est très précisément ce que la contrainte d'échelle a acheté.
func _poser_pose(idx: int) -> void:
	if idx == _pose_posee or _poses_peintes.is_empty():
		return
	var t_peint: Texture2D = _sprite_peint_statique if idx < 0 else _poses_peintes[idx]
	var t_sil: Texture2D = _sprite_sil_statique if idx < 0 else _poses_silhouettes[idx]
	if t_peint == null or t_sil == null:
		return
	for paire in [[visual, t_peint], [visual_dim, t_peint], [visual_reveal, t_sil],
			[visual_enemy, t_sil], [visual_reveal_enemy, t_sil]]:
		var poly: Polygon2D = paire[0]
		if poly != null:
			poly.texture = paire[1]
	_pose_posee = idx


## Le disque de torse qui arrête la rétrodiffusion.
##
## ⚠️ **Rayon 12, et le nombre n'est pas libre** : la raison est écrite avec la
## forme, dans `Charte.ombre_de_torse()`. Elle a déménagé là-bas le 2026-09-12,
## comme l'étoile de la silhouette avant elle — le leurre doit faire le même trou
## sous la rétrodiffusion adverse, et un gadget ne peut pas nommer `Player`.
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
	forme.polygon = Charte.ombre_de_torse()
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
##
## OMBRES, OM2 (Q82, décision d'Adrien du 2026-10-05 : « Oui ») — **la silhouette est désormais celle du CORPS VOXEL**
## (`VoxelCatalogue.etoile_d_ombre`), plus celle du sprite vu de dessus : en iso, l'ombre d'un corps prend la forme du corps qu'on
## voit — sans l'arme ni la torche, tenues à hauteur de main, que l'étoile projetait au sol en une pointe. Même échantillonnage
## radial, même nombre de rayons ; le leurre lit la même fonction.
func _accorder_occluder_a_la_silhouette(slug: String) -> void:
	var occ := etoile()
	if occ == null:
		return
	# Une seule fonction, pour que le leurre fasse exactement le même trou (2026-09-11 ; le corps voxel depuis OM2).
	var pts := VoxelCatalogue.etoile_d_ombre(slug)
	if pts.is_empty():
		return
	_etoile_posee = true
	# ⚠️ **Une ressource NEUVE, jamais celle de la scène.** `player.tscn` déclare
	# l'`OccluderPolygon2D` en sous-ressource, sans `resource_local_to_scene` : J1
	# et J2 la PARTAGEAIENT, et dans un match entre deux classes les deux corps
	# projetaient l'ombre de la classe équipée en dernier — le leurre, lui, celle
	# de son poseur, et il se trahissait. Trouvé en revue (2026-09-11).
	# OMBRES, OM1 — la ressource et son culling viennent de la charte, comme pour le leurre (`Charte.occulteur_d_etoile`).
	occ.occluder = Charte.occulteur_d_etoile(pts)
	# OMBRES, OM4b (Q86) — et, pour un PNJ, sa couche propre en plus de la 8.
	occ.occluder_light_mask = COUCHE_OCCLUDER_SIENNE | couche_ombre_pnj()


## OMBRES, OM4b (Q86, Adrien, 2026-10-05 : « une couche par PNJ ») — la couche d'ombre propre à CE PNJ
## (`CanauxLumiere.couche_ombre_pnj`), 0 pour J1, J2 et un PNJ sans place.
func couche_ombre_pnj() -> int:
	return CanauxLumiere.couche_ombre_pnj(slot_de_reserve()) if est_pnj else 0


## OMBRES, OM4b (Q86) — les masques d'un PNJ selon sa place : son étoile porte sa couche (en plus de la 8), et ses trois lumières
## qui découpent un corps — la torche, le halo de proximité, le flash de bouche — lisent celles de TOUS les autres PNJ, jamais la
## sienne (on ne se tient pas dans sa propre ombre). Avant, la torche d'un PNJ traversait les autres PNJ, quand celle de J1 les
## ombrait tous (O6). Seuls les bits des PNJ bougent : la posture (le bit des murs bas) et le reste du masque restent tels quels.
## Rien ne change pour J1 et J2 : leurs lumières ne lisent aucune couche de PNJ — celles de J1 lisent la 8, que toute étoile de
## PNJ porte toujours.
func accorder_les_couches_de_pnj() -> void:
	var occ := etoile()
	if occ != null:
		occ.occluder_light_mask = COUCHE_OCCLUDER_SIENNE | couche_ombre_pnj()
	var tous := CanauxLumiere.masque_des_pnj()
	var autres := (tous & ~couche_ombre_pnj()) if est_pnj else 0
	# Chantier TIR — l'étoile de bouche suit le flash de bouche : mêmes ombres, toujours.
	for lumiere in [flashlight, ambient_light, muzzle_flash, etoile_de_bouche]:
		if lumiere != null:
			(lumiere as Light2D).shadow_item_cull_mask = ((lumiere as Light2D).shadow_item_cull_mask & ~tous) | autres


## Au cœur de la suie, le corps cesse de faire ombre — l'ombre dirait la position
## et même la forme de la silhouette. Purement visuel : les balles, les collisions
## et la ligne de vue d'éblouissement passent par la physique, pas par les
## occluders. N'écrit que sur un changement.
func _couper_l_ombre(coupee: bool) -> void:
	if coupee == _ombre_coupee:
		return
	_ombre_coupee = coupee
	_poser_la_visibilite_de_l_ombre()


## L'étoile et le disque de torse se voient si NI la suie NI la mort ne les coupent.
func _poser_la_visibilite_de_l_ombre() -> void:
	for occ in [etoile(), get_node_or_null("OccluderTorse")]:
		if occ != null:
			occ.visible = not (_ombre_coupee or _ombre_du_mort)


## OMBRES, O11 (chantier OMBRES, 2026-10-04) — un corps mort ne fait plus d'ombre et sa lueur s'éteint. `die()` cache ses
## sprites et coupe sa torche et sa rétrodiffusion, mais laissait l'étoile, le disque de torse et le halo de proximité : l'ombre
## d'un corps disparu restait au sol — jusqu'au retrait du PNJ en aventure, toute la killcam et l'écran de fin en duel. Lu à CHAQUE
## image plutôt que posé dans `die()` : la vie revient par plusieurs chemins (`_do_start_round`, les réapparitions de
## l'entraînement, le retour au menu), et une règle d'état les couvre tous sans qu'aucun ait à s'en souvenir. N'écrit que sur un
## changement. Le halo : `enabled`, ici seulement — un mort n'éclaire rien, et le modèle de vue du bot, qui lit `enabled`
## (`perception_bot_noeud.gd`), ne voit plus de lueur à un corps tombé.
func _accorder_l_ombre_a_la_vie() -> void:
	if dead == _ombre_du_mort:
		return
	_ombre_du_mort = dead
	_poser_la_visibilite_de_l_ombre()
	if ambient_light != null:
		ambient_light.enabled = not dead


## L'occluder de l'étoile de ce corps : sa canvas (`EtoileDeCorps`) une fois `_ready()` passé, le nœud de la scène avant.
## Les gardes et le reste du corps la lisent ici, jamais par un chemin (`get_node("LightOccluder2D")`), qui a changé.
func etoile() -> LightOccluder2D:
	if _etoile_de_corps != null:
		return _etoile_de_corps.occluder
	return get_node_or_null("LightOccluder2D") as LightOccluder2D


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
	# Changer d'arme annule l'immobilisation de la précédente : garder un root de
	# 0,60 s après être passé à une classe qui en a 0,08 serait une pénalité que
	# rien à l'écran n'expliquerait.
	_root_restant = 0.0
	_root_duree = 0.0
	if current_weapon:
		current_ammo = current_weapon.max_ammo
		is_reloading = false
		reload_time_left = 0.0
		current_spread_bloom = 0.0
	# DA2.4 + DA2.5 — la silhouette du joueur change avec son arme.
	_poser_sprite(weapon.slug() if weapon.has_method("slug") else "pistolet")
	
	var tex = weapon.get_torch_texture()
	flashlight.texture = tex
	# La teinte n'est pas touchée ici : elle est posée une fois à la construction
	# de la torche, et une arme n'en change pas.
	flashlight.texture_scale = weapon.echelle_torche()


## Le tir peut-il interrompre le rechargement en cours ?
##
## Vrai pour la seule recharge cartouche par cartouche. C'est ce qui donne son
## sens à la mécanique : « on peut tirer dès qu'on a des balles » (Adrien,
## 2026-09-09). Une recharge d'un bloc reste un engagement — l'interrompre
## rendrait sa durée sans conséquence, donc gratuite.
func recharge_interruptible() -> bool:
	return is_reloading and current_weapon != null \
		and current_weapon.recharge_par_cartouche


func start_reload() -> void:
	if current_weapon == null: return
	if is_reloading: return
	if current_ammo >= current_weapon.max_ammo: return
	is_reloading = true
	reload_time_left = current_weapon.duree_etape_recharge()
	var slug: String = current_weapon.slug() if current_weapon.has_method("slug") else "pistolet"
	_bruit_de_corps(BruitDeCorps.RECHARGE, slug)
	# Éjection de douille d'atelier au sol lors du rechargement
	if slug != "arbalete":
		var gs = get_tree().get_first_node_in_group("game_state")
		if gs and gs.arena:
			var shoot_dir := Vector2.from_angle(rotation)
			BulletCasingScript.eject(gs.arena, global_position, shoot_dir, slug)


func _process(delta):
	# Publié ici et non dans _physics_process : les sorties anticipées (mort,
	# menu, round inactif) y laisseraient l'état répliqué figé sur du passé.
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		net_position = global_position
		net_rotation = rotation
		net_flashlight_on = flashlight_on
		net_dazzle = dazzle_amount
		net_ack_seq = _last_input_seq
		net_accroupi = accroupi

	# Hors du bloc de simulation : côté client la torche est répliquée, et les
	# sorties anticipées de _physics_process ne doivent pas laisser le son bloqué.
	# La torche de l'adversaire ne se déclare PAS au bus musical en ligne : elle
	# ouvrirait le passe-bas local et dirait qu'il vient de s'allumer, hors de
	# vue. Voir `AudioManager.torche_comptee`.
	if flashlight_on != _torch_audio_state:
		_torch_audio_state = flashlight_on
		if AudioManager.torche_comptee(player_id, _index_joueur_local()):
			AudioManager.set_player_torch(player_id, flashlight_on)

	# OMBRES, O11 — AVANT la sortie des morts : c'est elle qui empêchait toute règle d'ombre de voir la mort.
	_accorder_l_ombre_a_la_vie()
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
					var pouls := 0.55 * EffectPolicy.curseur("vignette_degats")
					vignette_mat.set_shader_parameter("intensity", pouls)
					var tw_v = create_tween()
					# DA4.13 — une intensité de shader qui retombe : EXTINCTION.
					Charte.animer_via(tw_v,
						func(v): vignette_mat.set_shader_parameter("intensity", v),
						pouls, 0.0, 0.45, Charte.Courbe.EXTINCTION)
	else:
		_low_hp_pulse_accum = 0.0

	if shoot_cooldown > 0:
		shoot_cooldown -= delta
		if shoot_cooldown <= 0:
			shoot_cooldown = 0
			# Play ready sound here if desired

	# Chantier FUSÉE (FU2.1) — dans la fumée, le sprite S'EFFACE : la masse
	# sombre du voile porte seule la présence. La masse seule ne suffisait pas,
	# le sprite restait lisible dessous (retour d'Adrien au premier essai).
	# Calculé ici, côté joueur — lui seul connaît tous ses visuels — depuis des
	# positions déjà répliquées : les deux machines effacent au même endroit.
	#
	# Une seule règle pour le joueur et le LEURRE depuis le 2026-09-11 (étape 27) :
	# elle vit dans `GadgetBase.effacements_a()`, que le leurre lit aussi.
	var effacements := GadgetBase.effacements_a(get_tree(), global_position)
	var occultation := effacements.x
	# Chantier CLASSES (étape 14) — les VOLUMES effacent de la même façon, et
	# c'est délibérément le même mécanisme : deux façons de s'effacer dans deux
	# nuages différents se sentiraient comme un défaut, pas comme deux gadgets.
	#
	# ⚠️ **Boucles sans garde** (`GadgetBase.effacements_a()`), et c'est tenable pour une
	# seule raison : `GadgetBase.occultation_pour()` existe et rend zéro, donc
	# TOUT gadget sait répondre. Le jour où quelqu'un ajoutera au groupe un objet
	# qui ne sait pas, le jeu plantera à chaque image — c'est le défaut qu'une
	# session voisine a relevé sur le groupe des fusées le 2026-09-09.
	#
	# Chantier CLASSES (étape 27) — la SUIE masque le corps (Adrien, 2026-09-11 :
	# « qu'on ne me voie pas dans la fumée ») : pour l'autre, plus rien au cœur, ni
	# sprite ni ombre. Pour soi, on se devine encore — se perdre de vue dans son
	# propre nuage serait une punition, pas un effet. Calculée à part : la fumée de
	# fusée, dont Adrien a validé le dosage, ne change pas.
	var masque := effacements.y
	_masque_ici = masque
	var a_soi := 1.0 - maxf(occultation, masque * PART_SOI_DANS_LA_SUIE)
	var a_autre := 1.0 - maxf(occultation, masque)
	for v in [visual, visual_dim, visual_reveal]:
		if v:
			v.modulate.a = a_soi
	if visual_enemy:
		# ⚠️ **Le minimum du brouillage et de la suie, comme le pointeur** (`a_masque`, juste
		# en dessous). Ce bloc tourne dans `_process`, donc APRÈS le brouillage écrit dans
		# `_physics_process` : il posait la seule suie et écrasait à chaque image l'effacement de
		# l'ennemi pour qui est ébloui. Au rendu, un joueur ébloui à 0,71 voyait l'ennemi à
		# l'opacité 1,00 (relevé sur `RenderingServer.frame_pre_draw`, banc ISO2b, 2026-09-14) —
		# le pointeur et la silhouette de tir s'effaçaient, le corps non. Rien ne l'a vu : la suite
		# de la suie ne regardait que la suie.
		visual_enemy.modulate.a = minf(_alpha_brouillage, a_autre)
	# Le pointeur et la silhouette révélée au tir aussi : un tir DANS la suie ne
	# rend pas le corps — c'est le nuage entier qui pulse (`diffuser_flash`).
	#
	# ⚠️ **Posé à chaque image depuis l'alpha du brouillage, jamais par un `minf`
	# cumulatif** : un `minf` ne fait que baisser, et le pointeur restait invisible
	# après la suie — le bloc du brouillage, seul autre écrivain, ne tourne ni au
	# décompte ni hors manche. Trouvé en revue (2026-09-11).
	var a_masque := minf(_alpha_brouillage, 1.0 - masque)
	for v in [visual_enemy_ptr, visual_reveal_enemy, visual_reveal_enemy_ptr]:
		if v:
			v.modulate.a = a_masque
	_couper_l_ombre(masque >= GadgetBase.SEUIL_OMBRE_MASQUEE)

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
func rpc_send_inputs(seq: int, mov: Vector2, aim: Vector2, shoot: bool, torch: bool, flare: bool, reload: bool = false, gadget: bool = false, crouch: bool = false, climb: bool = false) -> void:
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
	input_provider.update_input_state(mov, aim, shoot, torch, flare, reload, gadget, crouch, climb)

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
		# La posture reste celle qu'on a, comme la torche : ouvrir le menu ne
		# relève personne.
		rpc_id(1, "rpc_send_inputs", _input_seq, Vector2.ZERO, Vector2.ZERO, false, flashlight_on, false, false, false, accroupi, false)
		return
	var mov := input_provider.get_movement_vector()
	var aim := input_provider.get_aim_direction(global_position)
	_input_seq += 1
	rpc_id(1, "rpc_send_inputs", _input_seq, mov, aim,
		input_provider.is_shoot_pressed(), input_provider.is_flashlight_pressed(),
		input_provider.is_flare_pressed(), input_provider.is_reload_pressed(),
		input_provider.is_gadget_pressed(), input_provider.is_crouch_pressed(),
		input_provider.is_climb_pressed())

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
				"accroupi": net_accroupi,
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
	# ⚠️ **`move_and_collide` et non `global_position +=`.** Le second est un
	# téléport : il traverse les murs. Tant que le joueur bouge il se dégage seul
	# au tick suivant, ce qui a masqué le défaut jusqu'ici — mais un joueur
	# immobilisé après un tir ne bouge plus, et il y reste.
	#
	# `_predict_error -= step` reste juste même si le mur mange une partie du
	# pas : l'écart n'est pas intégré, il est RE-MESURÉ à chaque paquet
	# (`_predict_error = err`, depuis `net_position`). Ce qui est perdu revient
	# dans la mesure suivante — d'où l'inutilité de calculer le trajet réel.
	move_and_collide(step)
	_predict_error -= step
	if _predict_error.length() < 0.5:
		_predict_error = Vector2.ZERO

## MB3b — enjamber. Poussé VERS un muret en tenant la touche : la collision avec
## les murs bas est coupée. Lâché AVANT d'y monter : elle revient, et le muret
## arrête le corps. Commencé, on ne peut plus la rendre — un corps dans un mur
## serait éjecté —, la traversée continue donc jusqu'au bout.
##
## ⚠️ ISO11, L1 — « on ne doit pas pouvoir escalader un mur juste avec le
## joystick » (Adrien, test 1). « Déjà dessus » se lisait sur le cercle
## d'encombrement de 28 px, celui du canon. Canon tourné ailleurs, le disque du
## corps (18 px) s'arrête contre le muret DANS ce cercle : la règle le croyait
## monté et coupait la collision sans le geste — tout muret frôlé s'escaladait,
## et l'on ne pouvait plus se cacher derrière. Le chevauchement ne prolonge
## désormais qu'un enjambement COMMENCÉ par le geste (`enjambe` de l'image
## d'avant) ; seul un disque déjà dans la pierre (`RAYON_DEDANS`, un saut de
## correction réseau) continue sans lui. Aucun bit de plus sur le fil.
func _regler_enjambement(_input_dir: Vector2) -> void:
	# L'ENCOMBREMENT (28, le canon) et non le rayon de touche (18) : c'est la
	# collision qu'on coupe, donc la forme de la collision qui décide.
	var murs := MursBas.murs_de_la_manche
	var dessus := MursBas.chevauche_cercle(global_position, MursBas.RAYON_ENCOMBREMENT, murs)
	# ⚠️ **Le GESTE d'enjamber est retiré** (Adrien, 2026-10-04 : « Supprime le fait qu'on puisse enjamber les murs c'est nul ça
	# sert à rien ») : plus aucune poussée volontaire n'ouvre un muret. Reste le seul cas où couper la collision n'est pas un choix
	# — un disque déjà DANS la pierre (`RAYON_DEDANS` : un saut de correction réseau, une apparition) doit pouvoir en sortir, sans
	# quoi il y resterait coincé. `input_dir` et `is_climb_pressed()` ne servent plus ; le fil garde son bit (toujours faux), pour
	# que `Protocol.VERSION` ne bouge pas.
	var dedans := MursBas.chevauche_cercle(global_position, MursBas.RAYON_DEDANS, murs)
	enjambe = dedans or (enjambe and dessus)
	if enjambe:
		collision_mask &= ~MapGeometry.LOW_WALL_LAYER
	else:
		collision_mask |= MapGeometry.LOW_WALL_LAYER

## MB3b — « en faisant du bruit » : un frôlement fort à chaque montée sur un muret.
func _guetter_enjambement() -> void:
	# ⚠️ Seulement pendant une traversée (`enjambe`) : le cercle d'encombrement (28 px) chevauche un muret dès qu'on s'y adosse, canon
	# tourné ailleurs. Tant que le geste existait, ce frôlement précédait presque toujours une montée ; depuis son retrait
	# (2026-10-04), il aurait joué « on enjambe » à chaque fois qu'on se colle à un muret pour s'y cacher — relevé par
	# `test_accroupi`. La traversée ne reste que pour sortir d'un muret où l'on se trouve déjà.
	var dessus := enjambe and MursBas.chevauche_cercle(global_position, MursBas.RAYON_ENCOMBREMENT,
		MursBas.murs_de_la_manche)
	if dessus and not _sur_muret_avant:
		enjambements += 1
		AudioManager.play_enjambement(global_position, player_id)
	_sur_muret_avant = dessus

## La posture — MB2. Un seul point d'écriture, pour que la silhouette ne puisse
## jamais dire autre chose que la simulation : la vitesse lit `accroupi`, les vues
## du corps suivent ici, au changement seulement.
func poser_posture(voulue: bool) -> void:
	if voulue == accroupi:
		return
	accroupi = voulue
	var echelle := Vector2.ONE * (ECHELLE_SILHOUETTE_ACCROUPIE if voulue else 1.0)
	for poly in [visual, visual_dim, visual_reveal, visual_enemy, visual_reveal_enemy]:
		if poly != null:
			poly.scale = echelle
	# OMBRES, O11 — l'étoile suit la silhouette : accroupi, le sprite passe à ×0,8 et l'ombre restait celle du corps debout. Posé
	# sur le nœud de l'occluder, que `EtoileDeCorps` ne remet pas à l'échelle (son `RemoteTransform2D` ne recopie que la position
	# et la rotation) ; la forme, elle, reste celle de la silhouette (`_accorder_occluder_a_la_silhouette` ne touche pas l'échelle).
	var occ_etoile := etoile()
	if occ_etoile != null:
		occ_etoile.scale = echelle
	# MB3a — « la torche d'un accroupi bute sur le mur » : toutes les lumières
	# qu'il porte passent sous la hauteur d'un mur bas et en lisent les occluders
	# pleins. Debout, elles passent par-dessus. Un seul bit, posé ou retiré.
	for lumiere in [flashlight, body_light, ambient_light, muzzle_flash, etoile_de_bouche]:
		if lumiere != null:
			if voulue:
				lumiere.shadow_item_cull_mask |= CanauxLumiere.COUCHE_OMBRE_MUR_BAS
			else:
				lumiere.shadow_item_cull_mask &= ~CanauxLumiere.COUCHE_OMBRE_MUR_BAS

## [Client] Rend le joueur distant INTERP_DELAY en arrière : on dispose alors
## presque toujours de deux instantanés encadrants, malgré les 30 Hz.
##
## La posture ne s'interpole pas : elle suit l'instantané le plus ancien des deux
## encadrants, comme la torche — un corps n'est pas « à moitié accroupi ».
func _apply_remote_interpolation() -> void:
	if _net_snapshots.is_empty(): return

	var render_t := Time.get_ticks_msec() / 1000.0 - INTERP_DELAY
	var first: Dictionary = _net_snapshots[0]
	var last: Dictionary = _net_snapshots[-1]

	if _net_snapshots.size() == 1 or render_t <= first["t"]:
		global_position = first["pos"]
		rotation = first["rot"]
		flashlight_on = first["torch"]
		poser_posture(first.get("accroupi", false))
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
		poser_posture(last.get("accroupi", false))
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
			poser_posture(a.get("accroupi", false))
			# Les instantanés antérieurs ne resserviront plus.
			if i > 0:
				_net_snapshots = _net_snapshots.slice(i)
			return

## [Serveur / Client] Gère la physique (Sandbox autorisé).
## Ramène la lampe (et la rétrodiffusion) du bon côté du mur.
##
## Un rayon du centre du corps vers la lentille, sur la couche des murs : s'il
## touche avant elle, la lampe recule sur ce rayon à `RETRAIT_LAMPE` du mur, sans
## jamais entrer dans le corps (4 px au moins). Sans mur, elle reprend sa place.
## La rétrodiffusion garde SA règle d'avant L2 : droit devant, posée à 18, le
## bord du corps, et reculée devant un mur plus proche. Deux rayons par image et
## par joueur, torche allumée seulement.
func _rapprocher_la_lampe() -> void:
	var lampe := LENTILLE_LAMPE
	var retro := RETRO_AVANCEE
	if flashlight_on and is_inside_tree():
		var espace := get_world_2d().direct_space_state
		var vers_lampe: Vector2 = global_transform.basis_xform(LENTILLE_LAMPE).normalized()
		var d := _mur_devant(espace, vers_lampe, LENTILLE_LAMPE.length() + RETRAIT_LAMPE)
		if d >= 0.0:
			lampe = LENTILLE_LAMPE.normalized() * clampf(d - RETRAIT_LAMPE, 4.0, LENTILLE_LAMPE.length())
		var r := _mur_devant(espace, global_transform.x.normalized(), RETRO_AVANCEE + RETRAIT_LAMPE)
		if r >= 0.0:
			retro = clampf(r - RETRAIT_LAMPE, 4.0, RETRO_AVANCEE)
	if not flashlight.position.is_equal_approx(lampe):
		flashlight.position = lampe
	if not is_equal_approx(body_light.position.x, retro):
		body_light.position.x = retro


## OMBRES, O9 (chantier OMBRES, 2026-10-04) — le flash de bouche, comme la lampe (`_rapprocher_la_lampe`) : un corps collé à un mur
## posait son flash à 28 px devant lui, DANS le mur — et une lumière posée dans un occluder ne donne « ni ombre ni lumière mais du
## hasard » (`charte.gd`, le disque de torse) : des ombres au hasard à chaque tir. Le flash recule sur le même rayon, à
## `RETRAIT_LAMPE` du mur, jamais à moins de 4 px du centre. Un rayon par tir, au tir seulement. Le `Muzzle` (le canon : balles,
## fumée, son) ne bouge pas : seule la LUMIÈRE recule — le point où le modèle de vue du bot lit l'éclair (`perception_bot_noeud`)
## la suit, puisqu'il lit la position de cette lumière.
func _reculer_le_flash() -> void:
	var place := FLASH_AVANCEE
	if is_inside_tree():
		var d := _mur_devant(get_world_2d().direct_space_state, global_transform.x.normalized(), FLASH_AVANCEE + RETRAIT_LAMPE)
		if d >= 0.0:
			place = clampf(d - RETRAIT_LAMPE, 4.0, FLASH_AVANCEE)
	muzzle_flash.position = Vector2(place, 0.0)
	# Chantier TIR — l'étoile de bouche recule avec lui : posée dans le mur, elle aussi donnerait des ombres au hasard.
	if etoile_de_bouche != null:
		etoile_de_bouche.position = muzzle_flash.position


## OMBRES, OM3 — l'énergie de la torche à `avance` du recul (0 au coup, 1 à sa fin) : le creux, puis la remontée en douceur.
static func energie_de_recul(avance: float) -> float:
	return lerpf(RECUL_CREUX, RECUL_SORTIE, smoothstep(0.0, 1.0, clampf(avance, 0.0, 1.0)))


## OMBRES, OM3 — l'enveloppe du recul en cours. Armée quand le compteur REMONTE (un tir le pose ; une fusée ou un gadget peuvent
## l'allonger, `maxf`) : sa durée est prise à cet instant, et l'avance se lit sur ce qu'il en reste.
func _enveloppe_de_recul() -> float:
	if shoot_cooldown > _recul_vu + 0.0001:
		_recul_duree = shoot_cooldown
	_recul_vu = shoot_cooldown
	if _recul_duree <= 0.0:
		return RECUL_SORTIE
	return energie_de_recul(1.0 - shoot_cooldown / _recul_duree)


## La distance au premier mur dans `direction` (unitaire, monde), jusqu'à `longueur` ; −1 sans mur.
func _mur_devant(espace: PhysicsDirectSpaceState2D, direction: Vector2, longueur: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * longueur,
		MapGeometry.WALL_LAYER)
	q.exclude = [get_rid()]
	var coup: Dictionary = espace.intersect_ray(q)
	return -1.0 if coup.is_empty() else global_position.distance_to(coup["position"])


func _physics_process(delta):
	# Étape 28, lot C — les deux minuteurs de REFUS se décomptent ICI, avant toute
	# sortie anticipée : la mort, le menu, le décompte de départ, la manche finie.
	# ⚠️ Placés plus bas, après ces gardes, ils se FIGEAIENT : un refus armé dans les
	# 0,22 s qui précèdent la fin d'une manche gardait sa valeur pendant la killcam,
	# l'écran de fin et le décompte — et le HUD, qui le recopie à chaque image, tenait
	# la cartouche décalée tout l'entre-manche, puis la faisait trembler au FIGHT sur
	# un appui que personne n'avait fait (revue du lot C, 2026-09-11, reproduit dans
	# Godot). Ce sont des minuteurs de RESSENTI, que la simulation ne lit jamais : les
	# décompter partout ne fait pas diverger les pairs. `tir_a_sec` (V4.4, plus bas)
	# porte le même défaut, antérieur au lot : signalé, laissé à sa place.
	if refus_fusee > 0.0:
		refus_fusee = maxf(0.0, refus_fusee - delta)
	if refus_gadget > 0.0:
		refus_gadget = maxf(0.0, refus_gadget - delta)
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
	if menu_open or input_provider == null or not input_provider.is_shoot_pressed():
		_tir_consomme = false
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
		# MB2 — la posture AVANT la vitesse : le pas de cette image se fait déjà
		# à l'allure de la posture choisie à cette image.
		var input_dir = input_provider.get_movement_vector()
		# MB3b — l'enjambement se décide avant la posture : on enjambe DEBOUT, et
		# la bascule d'accroupissement reprend la main une fois le muret passé.
		_regler_enjambement(input_dir)
		poser_posture(input_provider.is_crouch_pressed() and not enjambe)
		# ⚠️ **La vitesse ne dépend que de deux causes, et toutes deux se
		# LISENT** : l'arme qu'on porte et l'éblouissement qu'on subit. Rien ne
		# doit accélérer un joueur sans que l'adversaire puisse le voir venir —
		# dans un jeu dont la seule information est la lumière, une accélération
		# muette est une information retirée à l'autre.
		var current_speed = speed
		if (shoot_cooldown > 0 or is_reloading) and current_weapon:
			current_speed *= current_weapon.movement_speed_while_reloading
		# Le ROOT — troisième cause, et elle se LIT comme les deux autres : un
		# joueur qui vient de tirer ne bouge plus, ce que l'adversaire voit.
		# `facteur()` rend 1 hors de sa fenêtre, donc la ligne est inconditionnelle.
		if _root_restant > 0.0:
			current_speed *= RootProfile.facteur(_root_restant, _root_duree)
		if dazzle_amount > 0:
			current_speed *= lerp(1.0, 0.4, dazzle_amount)
		# La posture — quatrième cause, et elle se LIT aussi : la silhouette
		# ramassée (`poser_posture`). Un ralentissement qu'on ne voit pas serait
		# une information retirée à l'autre ; celui-ci se voit dès qu'on éclaire.
		if accroupi:
			current_speed *= FACTEUR_VITESSE_ACCROUPI
		# MB3b — « lentement » : la traversée d'un muret a sa propre allure, qui
		# remplace celle de la marche (l'éblouissement ou le root la ralentissent
		# encore, parce qu'ils se lisent aussi).
		if enjambe:
			current_speed *= FACTEUR_VITESSE_ENJAMBEMENT

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
		var torche_avant := flashlight_on
		flashlight_on = input_provider.is_flashlight_pressed()
		# Un PNJ qui allume sa torche se fait ENTENDRE (2026-10-04) : c'est l'annonce de sa mise en joue (`BotInputProvider`), et le seul
		# claquement de torche que joue le jeu pour un autre que soi — audible de partout, comme ses tirs.
		if est_pnj and flashlight_on and not torche_avant:
			AudioManager.play_sfx_2d_random_pitch("torch_on", global_position, 0.95, 1.05, 0.0, AudioManager.BUS_SFX, player_id,
				AudioManager.FACTEUR_PORTEE_TIR_PNJ, true)
		# Chantier vibrations manettes — le clic du cran plein, à l'armement ET
		# au désarmement du verrou (les deux sont le même geste physique : la
		# gâchette qui touche sa butée). `is_flashlight_locked()` est déjà le
		# bon état à lire — voir la session Menus aspect refinement (cadenas du
		# HUD, `931a7c0`).
		var torch_locked := input_provider.is_flashlight_locked()
		if torch_locked != _torch_locked_prev:
			_torch_locked_prev = torch_locked
			_rumble(RUMBLE_TORCH_LOCK, RUMBLE_TORCH_LOCK, 0.04)

		if role == NetRole.PREDICTED:
			# Correction appliquée AVANT l'archivage : l'historique doit décrire
			# la position réellement affichée, sinon l'écart serait recompté.
			_consume_prediction_error(delta)
			_predict_history[_input_seq] = {"pos": global_position, "rot": rotation,
				"accroupi": accroupi}
			if _predict_history.size() > PREDICT_HISTORY_MAX:
				_predict_history.erase(_predict_history.keys()[0])

	# Pas — son ET empreinte (D1), déclenchés sur la distance RÉELLEMENT
	# parcourue et non sur la vitesse simulée. Hors du bloc can_move exprès :
	# l'adversaire interpolé doit produire les mêmes traces que le joueur
	# simulé, sinon l'information devient asymétrique — l'hôte entendrait et
	# pisterait le client, jamais l'inverse. (Corrige au passage l'asymétrie
	# préexistante du SFX de pas, inaudible côté client pour l'adversaire.)
	# MB3b — le bruit de l'enjambement, pour TOUS les rôles : l'adversaire affiché
	# le produit comme le joueur simulé, depuis la même position.
	_guetter_enjambement()
	var step_moved := global_position.distance_to(_last_step_pos)
	_last_step_pos = global_position
	# > 100 px en un tick : téléportation (spawn, correction sèche), pas un pas.
	if step_moved > 0.5 and step_moved < 100.0:
		step_distance_accumulated += step_moved
		_temps_du_pas += delta
		# ⚠️ **Une seule distance, et surtout pas une branche.** Le seuil doit
		# être le même pour le joueur simulé et pour l'adversaire interpolé : un
		# pas qui se déclenche plus tôt d'un côté que de l'autre rend
		# l'information asymétrique — l'un entend et piste, l'autre pas.
		var step_dist := 45.0
		if step_distance_accumulated >= step_dist:
			# SON VISIBLE (Q47) — l'allure du pas : la vitesse MOYENNE sur ce pas,
			# rapportée à la vitesse de marche. Mesurée sur la distance parcourue et
			# non lue sur l'entrée, pour la même raison que le pas lui-même :
			# l'adversaire interpolé n'a pas d'entrée, mais il a une trajectoire, et
			# les deux pairs doivent entendre le même pas au même niveau.
			var allure := step_distance_accumulated / maxf(_temps_du_pas, 0.001) / maxf(speed, 1.0)
			step_distance_accumulated = 0.0
			_temps_du_pas = 0.0
			# Fourchette fixe : rien ne module la hauteur du pas. **Un facteur
			# qui ne varie jamais suggère une modulation qui n'existe pas** — il
			# coûte une relecture à chaque passage, et il en promet une.
			# V5.7 — **le son du pas suit le DAMIER, pas le hasard.** La case
			# se derive de la position par la meme parite que
			# `CandelaTileSet.get_floor_atlas` : traverser le damier doit
			# s'entendre alterner comme il se voit alterner.
			#
			# L'origine exacte de la grille n'est volontairement pas corrigee du
			# decalage d'arene : une erreur d'origine echangerait A et B
			# GLOBALEMENT, ce qui ne s'entend pas — les deux sont des sols. Ce
			# qui compte, et que ce calcul garantit, c'est que deux cases
			# voisines different.
			var case := Vector2i((global_position / float(CandelaTileSet.TILE_SIZE.x)).floor())
			# MB2 — accroupi, le pas s'étouffe. Hors du bloc `can_move` comme le
			# reste : l'adversaire interpolé étouffe les siens de la même façon.
			AudioManager.play_footstep(global_position, case, accroupi, allure, player_id)
			# V5.11 — le frolement, au meme rythme que le pas et jamais seul :
			# on ne frole un mur qu'en s'y deplacant. Le lier au pas plutot qu'a
			# un minuteur evite le crepitement d'un joueur immobile colle a une
			# paroi, qui trahirait une position sans qu'aucun geste soit fait.
			if get_slide_collision_count() > 0:
				_bruit_de_corps(BruitDeCorps.FROLEMENT)
			# D1 — l'empreinte au rythme exact du pas sonore : le son et la
			# trace racontent le même événement, sandbox compris.
			_foot_side = -_foot_side
			_pas += 1
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
	#
	# OMBRES, OM1 (Q81, décision d'Adrien, 2026-10-05) — **et seulement s'il EST la
	# source de cet éblouissement**, de ce qui dépasse la rétrodiffusion de 0,06
	# (`Brouillage.opacite_vue`). Avant, tout ennemi s'effaçait dès que le regardeur
	# était ébloui, par n'importe quoi — sa propre torche comprise.
	if state != null and visual_enemy != null:
		var regardeur: Node = state.p2 if player_id == 0 else state.p1
		if is_instance_valid(regardeur):
			var a := Brouillage.opacite_vue(float(regardeur.dazzle_amount), regardeur.source_du_brouillage() == self)
			_alpha_brouillage = a
			visual_enemy.modulate.a = a
			if visual_enemy_ptr != null:
				visual_enemy_ptr.modulate.a = a
			if visual_reveal_enemy != null:
				visual_reveal_enemy.modulate.a = a
			if visual_reveal_enemy_ptr != null:
				visual_reveal_enemy_ptr.modulate.a = a

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

	# La pose peinte, sur le MÊME compteur que tout le reste du pas.
	#
	# ⚠️ **Le retour au repos est accroché à celui du roulis, et pas à l'arrêt du
	# mouvement.** Une pose ne s'interpole pas : revenir au sprite statique dès
	# que le joueur s'immobilise ferait un saut visible, en plein milieu du retour
	# lissé du corps. En attendant que `_roulis` ait fini, les deux mécanismes se
	# posent au même instant et l'arrêt devient une seule chose au lieu de deux.
	if not _poses_peintes.is_empty():
		if step_moved > 0.5 and step_moved < 100.0:
			_poser_pose(_pas % _poses_peintes.size())
		elif is_zero_approx(_roulis):
			_poser_pose(-1)

	# Visuals update for all clients
	# D3 — extinction traînée (décision actée) : le noir « avale » le faisceau
	# en ~80 ms au lieu d'une coupure sèche. Coût assumé : l'adversaire gagne
	# ces 80 ms d'information à l'extinction. Symétrique : l'effet joue aussi
	# sur la torche répliquée de l'adversaire.
	if flashlight_on:
		flashlight.enabled = true
		_rapprocher_la_lampe()
		body_light.enabled = true
		if shoot_cooldown > 0:
			_energie_torche = _enveloppe_de_recul()
		else:
			# OMBRES, OM3b (Q84, Adrien, 2026-10-05 : « Retirer ») — la torche ne respire plus. Le souffle (V5.4 : ±3 %
			# d'énergie sur un bruit tiré à chaque pas, que ce lissage écrasait) ne faisait en pratique que quelques millièmes
			# (2,497 à 2,504 au banc d'OM0, 2,492 à 2,502 à celui d'OM3b ; zéro pixel au-delà de huit niveaux) : rien à l'image,
			# mais une lumière qui ne tenait jamais tout à fait la même valeur. Reste le
			# retour, lissé, à l'énergie de repos après un recul. La fausse torche du Braconnier perd son souffle avec
			# (`GadgetTorcheFantome`).
			_energie_torche = lerp(_energie_torche, 2.5, 8.0 * delta)

		# Chantier CLASSES (étape 16) — le GRÉSILLEMENT du Parasite fait sauter
		# les lampes autour de lui : le faisceau papillote, faiblit, tombe au
		# noir, revient (le noir absolu depuis l'étape 24). Et la SUIE du Fumiste
		# étouffe la lampe qu'on y tient (étape 27) : même boucle, même minimum —
		# voir `GadgetSuie.facteur_de_lampe()`.
		#
		# ⚠️ **Posé APRÈS le souffle et AVANT la rétrodiffusion**, et les deux
		# places comptent. Après le souffle, parce que la panne doit s'appliquer à
		# l'énergie réellement rendue et non se faire écraser par le `lerp` de la
		# ligne au-dessus. Avant la rétrodiffusion, parce que celle-ci se dérive de
		# `flashlight.energy` : sans ça, le halo du porteur resterait plein pendant
		# que son faisceau s'éteint, et il verrait que sa lampe ment.
		#
		# ⚠️ **Le MINIMUM, jamais le produit** : deux bobines ne doivent pas
		# éteindre deux fois. C'est la même règle que le MAX de l'éblouissement —
		# le modèle est un plafond, pas une intégrale.
		var lampe := 1.0
		for gadget in get_tree().get_nodes_in_group("gadgets"):
			lampe = minf(lampe, gadget.facteur_de_lampe(global_position))
		# ⚠️ **L'atténuation s'applique à `_energie_torche`, JAMAIS à
		# `flashlight.energy`**, et la première version faisait l'inverse.
		#
		# `flashlight.energy` était l'ÉTAT lissé : le multiplier réinjectait
		# l'atténuation dans le lissage de l'image suivante, et elle se composait
		# indéfiniment. Mesuré au creux du grésillement — 0,094 au lieu des 0,57
		# attendus, soit six fois trop —, **et la valeur dépendait de la cadence** :
		# plus la machine est rapide, plus le `lerp` par image est petit, plus la
		# composition l'emporte. Une mécanique dont la force dépend du matériel n'a
		# pas sa place dans un jeu qui se veut honnête en compétition.
		#
		# ⚠️ Aucune suite ne pouvait l'attraper : le facteur du gadget était juste,
		# le câblage était juste, et le banc mesure les deux. C'est le nombre
		# IMPRIMÉ par une capture qui l'a montré.
		# Étape 28, lot F — retenu pour la killcam AVANT d'être appliqué : le fantôme
		# rejoue le grésillement et la suie, qui n'y étaient pas.
		facteur_de_lampe_rendu = lampe
		flashlight.energy = _energie_torche * lampe

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
				var poussiere_mod := 1.0
				var gs := get_node_or_null(^"/root/GameSettings")
				if gs and gs.has_method("current_effect"):
					poussiere_mod = gs.current_effect("poussiere_faisceau")
				# Grain contrasté style roman graphique : vivement révélé sous le faisceau
				var alpha_grain := randf_range(0.60, 0.85) * poussiere_mod
				pool.emit(ParticlePool.Kind.DUST, muzzle.global_position + faisceau * portee + ecart,
					Color(Charte.HALOGENE, alpha_grain), 1, 4.0, 14.0, faisceau, 160.0)
	elif flashlight.enabled:
		flashlight.energy = move_toward(flashlight.energy, 0.0, delta * (2.5 / TORCH_FADE_OUT))
		body_light.energy = move_toward(body_light.energy, 0.0, delta * (0.6 / TORCH_FADE_OUT))
		if flashlight.energy <= 0.01:
			flashlight.enabled = false
			body_light.enabled = false
	
	_update_aim_line()

	# Récupération de la précision (dispersion bloom)
	if current_weapon and current_spread_bloom > 0.0:
		current_spread_bloom = maxf(0.0, current_spread_bloom - current_weapon.spread_recovery_speed_deg * delta)

	# Progression du root. Posé ici et pas ailleurs : ce bloc est celui du
	# rechargement, il ne tourne que pendant le jeu actif, et les deux comptent
	# le même genre de temps — celui pendant lequel on ne peut pas faire ce qu'on
	# voudrait.
	if _root_restant > 0.0:
		_root_restant = maxf(0.0, _root_restant - delta)

	# Progression du rechargement
	if is_reloading:
		reload_time_left -= delta
		if reload_time_left <= 0.0:
			reload_time_left = 0.0
			if current_weapon != null and current_weapon.recharge_par_cartouche:
				# Une cartouche entre, et la suivante s'enchaîne d'elle-même
				# jusqu'à ce que le chargeur soit plein — ou qu'un tir coupe.
				#
				# ⚠️ Le chargeur se remplit AVANT le test d'arrêt. L'écrire dans
				# l'autre ordre laisserait la dernière cartouche comptée par la
				# boucle et jamais posée dans l'arme : un chargeur annoncé plein
				# à cinq sur six, ce que rien à l'écran n'expliquerait.
				current_ammo = mini(current_ammo + 1, current_weapon.max_ammo)
				_rumble(0.0, RUMBLE_RELOAD_READY, 0.05)
				if current_ammo >= current_weapon.max_ammo:
					is_reloading = false
				else:
					reload_time_left = current_weapon.duree_etape_recharge()
					_bruit_de_corps(BruitDeCorps.RECHARGE, current_weapon.slug())
			else:
				is_reloading = false
				if current_weapon:
					current_ammo = current_weapon.max_ammo
					_rumble(0.0, RUMBLE_RELOAD_READY, 0.08)

	# Détection de l'ordre de recharger
	var reload_presse := input_provider.is_reload_pressed()
	if not reload_presse:
		_reload_presse = false
	elif can_move and not _reload_presse and not is_reloading and current_weapon \
			and current_ammo < current_weapon.max_ammo:
		start_reload()
		_reload_presse = true

	# Le tir suit l'autorité de simulation : en ligne c'est l'hôte qui l'arbitre
	# pour les deux joueurs, cooldown compris.
	var presse := input_provider.is_shoot_pressed()
	# MB3b — on ne tire pas en enjambant (proposition de la note, § 6.2).
	if can_move and presse and shoot_cooldown <= 0 and not enjambe \
			and (not is_reloading or recharge_interruptible()):
		if current_ammo > 0:
			# Un appui, un tir — sauf l'arme automatique, la seule qui tire en boucle
			# détente tenue (décision d'Adrien, 2026-09-10). Un appui pris pendant
			# le cooldown part à son terme : le verrou n'est posé qu'AU tir.
			if (current_weapon != null and current_weapon.automatique) or not _tir_consomme:
				shoot()
				_tir_consomme = true
		else:
			# Plus de munitions : tir à sec + rechargement automatique
			# `tir_a_sec <= 0.0` en plus du front montant : la détente est
			# désormais un AXE (gâchette R2, chantier 10 classes), pas un
			# bouton — pas de front franc, un bruit d'analogique proche du
			# seuil de zone morte peut agiter `_detente_pressee` sur
			# plusieurs images. Le second garde absorbe ce bruit sans rien
			# retirer au geste : un vrai relâchement-répression reste à plus
			# de 220 ms, largement au-dessus de tout tremblement de capteur.
			if not _detente_pressee and _clic_a_sec <= 0.0:
				_clic_a_vide()
			start_reload()
	elif can_move and presse and not _detente_pressee and _clic_a_sec <= 0.0 \
			and (current_ammo <= 0 or (is_reloading and not recharge_interruptible())):
		# ⚠️ Semi-automatique (2026-09-10) : le clic « trop tôt » ne sonne plus
		# quand il reste des munitions. L'appui n'est pas perdu, il part au terme
		# du cooldown — et un clic de percuteur juste avant un tir qui part
		# mentirait. Il ne reste que pour ce qui refuse VRAIMENT : chargeur vide,
		# ou recharge d'un bloc qu'on ne peut pas interrompre.
		# Front montant ET fenêtre de 220 ms écoulée — voir le garde ci-dessus.
		# V4.4 — le percuteur. Positionnel a la bouche : un clic a vide est un
		# evenement du monde, et dans ce jeu il RACONTE quelque chose de cher —
		# « je suis desarme, et je suis la ». Il ne compte pas comme un tir pour
		# le pool (voir `AudioManager.est_un_tir`), sans quoi il ferait reculer
		# les pas de l'adversaire au moment ou l'on ne tire justement pas.
		_clic_a_vide()
	# Le root de RAFALE : il ne tombe pas coup par coup mais au relâchement, ou
	# quand le chargeur se vide. Sans ce bloc, l'Occulteur n'aurait aucun root du
	# tout — un manque qui ne lèverait rien et ne se verrait qu'en jouant.
	var _cl_rafale := current_weapon as ClassData
	if _cl_rafale != null and _cl_rafale.root != null and _cl_rafale.root.apres_rafale:
		if _detente_pressee and not presse:
			_root_restant = maxf(_root_restant, _cl_rafale.root.duree)
			_root_duree = _cl_rafale.root.duree

	_detente_pressee = presse
	if tir_a_sec > 0.0:
		tir_a_sec = maxf(0.0, tir_a_sec - delta)
	if _clic_a_sec > 0.0:
		_clic_a_sec = maxf(0.0, _clic_a_sec - delta)
	# Étape 28, point 5 — ⚠️ AVANT les blocs de lancer et de pose, sur l'état d'AVANT
	# l'appui : placé après, la dernière fusée lancée se lirait comme un refus (la
	# réserve vient de tomber à zéro), et une bobine éteinte batterie basse aussi.
	_sentir_les_refus(state, input_provider.is_flare_pressed(),
		input_provider.is_gadget_pressed(), can_move)

	# Le lancer de fusée suit la même autorité que le tir. Front montant sur un
	# bit MAINTENU dans la commande réseau : un « just_pressed » d'un seul tick
	# se perd en unreliable — c'est le patron `_detente_pressee`. Un front pris
	# pendant le rechargement reste EN ATTENTE (le drapeau ne se pose qu'au
	# lancer ou au relâchement) : bouton tenu, la fusée part dès la fin du
	# cooldown, chez l'hôte comme dans la prédiction — jamais tir et lancer
	# dans la même image, le tir arme son cooldown en premier.
	var fusee_presse := input_provider.is_flare_pressed()
	if not fusee_presse:
		_fusee_pressee = false
	elif can_move and not _fusee_pressee and shoot_cooldown <= 0 \
			and state and state.fusee_disponible(slot_de_reserve()):
		lancer_fusee()
		_fusee_pressee = true

	# La pose de gadget suit EXACTEMENT le même patron, et c'est délibéré : deux
	# gestes qui font la même chose — un bit maintenu, un front, un désarmement
	# porté par le cooldown de tir, un arbitrage chez l'hôte — doivent s'écrire
	# pareil, sinon l'un des deux dérivera.
	#
	# ⚠️ L'ordre compte : le gadget est examiné APRÈS la fusée. Les deux touches
	# tenues ensemble, la fusée part d'abord et arme le cooldown, donc le gadget
	# attend le tick suivant. Jamais les deux dans la même image — et l'ordre est
	# le même chez l'hôte et dans la prédiction du client, puisque c'est ce bloc
	# qui tourne des deux côtés.
	var gadget_presse := input_provider.is_gadget_pressed()
	if not gadget_presse:
		_gadget_pressee = false
	elif can_move and not _gadget_pressee and state \
			and state.gadget_basculable_de(slot_de_reserve()) != null:
		# ⚠️ **L'interrupteur passe AVANT la pose, et sans ses gardes.** Celui de la
		# pose exige `shoot_cooldown <= 0` et `gadget_disponible()` : le premier est
		# presque toujours faux chez un Parasite qui tire, le second le devient dès
		# la bobine posée. Tels quels, ils bloquaient l'EXTINCTION — on n'aurait
		# jamais pu couper sa bobine en combattant. Éteindre n'occupe pas les mains :
		# aucun désarmement.
		state.basculer_gadget(self)
		_gadget_pressee = true
	elif can_move and not _gadget_pressee and shoot_cooldown <= 0 \
			and state and state.gadget_disponible(slot_de_reserve()):
		# Étape 28 — le voile sans place se SENT ici, au moment où la pose part (un
		# appui pris pendant le cooldown part plus tard, sans nouveau front). Le
		# ressenti seul : la pose et le désarmement suivent, inchangés.
		_sentir_pose_sans_place(state)
		poser_gadget()
		_gadget_pressee = true

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
## SON VISIBLE, S6 (2026-09-29) — les bruits de corps que l'adversaire interpolé ne
## peut pas refaire lui-même.
##
## ⚠️ **Une asymétrie d'avant, que le liseré rendait visible.** En ligne, l'hôte simule
## les deux joueurs : il entend les rechargements et les frôlements du client. Le
## client, lui, n'interpole que la trajectoire de l'hôte — ni `start_reload()` ni
## `move_and_slide()` ne tournent pour lui, donc il n'entendait JAMAIS ces deux bruits
## de l'hôte. Le son rendu visible les dessinant, l'hôte aurait vu le client recharger
## derrière un mur, et jamais l'inverse. Tir, douille, pas, enjambement et souffle
## étaient déjà symétriques (`trigger_shoot_visuals`, `rpc_update_hp`, la trajectoire).
##
## Le joueur de l'hôte (`player_id` 0) envoie donc ces bruits au client ; celui du
## client n'a rien à envoyer : le client le prédit, et l'hôte le simule.
enum BruitDeCorps { RECHARGE, FROLEMENT, PERCUTEUR }

## Pure : ce bruit doit-il partir vers le client ? Seulement en ligne, chez l'hôte,
## pour son propre joueur.
static func bruit_a_repliquer(mode: int, pid: int, pair_present: bool) -> bool:
	return pair_present and mode == NetworkManager.GameMode.ONLINE_HOST and pid == 0

func _bruit_de_corps(genre: int, arme: String = "", ou: Variant = null) -> void:
	var pos: Vector2 = global_position if ou == null else ou
	_jouer_bruit_de_corps(genre, arme, pos)
	if bruit_a_repliquer(NetworkManager.current_mode, player_id, multiplayer.has_multiplayer_peer()):
		rpc_bruit_de_corps.rpc(genre, arme, pos)

## [Client] Un bruit de corps de l'hôte, joué à la position où l'hôte l'a fait.
@rpc("authority", "call_remote", "reliable")
func rpc_bruit_de_corps(genre: int, arme: String, pos: Vector2) -> void:
	_jouer_bruit_de_corps(genre, arme, pos)

func _jouer_bruit_de_corps(genre: int, arme: String, pos: Vector2) -> void:
	match genre:
		BruitDeCorps.RECHARGE:
			AudioManager.play_weapon_reload(arme, pos, player_id)
		BruitDeCorps.FROLEMENT:
			AudioManager.play_wall_brush(pos, player_id)
		BruitDeCorps.PERCUTEUR:
			AudioManager.play_percuteur(arme, pos, player_id)

## Q54 (Adrien, 2026-09-29 : « oui on le rend audible ») — le clic à vide, SÉPARÉ
## de son retour.
##
## ⚠️ **Le son était rangé derrière la garde du retour de refus** (`_percu_ici`,
## « chez le seul joueur qui a pressé ») : juste pour la vibration et le tremblement
## de la cartouche, qui ne parlent qu'à celui qui appuie — mais le SON, lui, est un
## événement du monde (V4.4 : « je suis désarmé, et je suis là »). En ligne, personne
## n'entendait donc le clic de l'autre ; en écran partagé, les deux l'entendaient.
## Équitable parce que muet des deux côtés, et contraire à ce que le son devait dire.
##
## Désormais : le son part partout où ce joueur est simulé ou prédit (l'hôte entend
## le clic du client, le client le sien), et l'hôte envoie le clic de SON joueur au
## client (S6) ; le retour reste à celui qui a pressé. Deux fenêtres de 220 ms
## distinctes : `_clic_a_sec` pour le monde, `tir_a_sec` pour le HUD, que l'hôte ne
## doit pas faire trembler pour le client — il apprendrait l'essai hors de portée.
func _clic_a_vide() -> void:
	_clic_a_sec = 0.22
	if current_weapon:
		_bruit_de_corps(BruitDeCorps.PERCUTEUR, current_weapon.slug(), muzzle.global_position)
	if _percu_ici() and tir_a_sec <= 0.0:
		tir_a_sec = 0.22
		_rumble(RUMBLE_DRY_FIRE, 0.0, 0.05)

func _percu_ici() -> bool:
	var local := _index_joueur_local()
	return local < 0 or player_id == local

## Étape 28, point 5 (2026-09-11) — un appui de fusée ou de gadget que l'arbitrage
## refuse se SENT : la cartouche tremble (HUD) et la manette vibre. Jusqu'ici seul
## le tir avait ce retour (V4.4, plus haut) ; la fusée et le gadget refusés ne
## produisaient RIEN — le geste qui échoue en silence que V4.4 avait retiré.
##
## Les refus sont ceux que l'hôte prononce en silence : réserve vide
## (`fusee_disponible`), recharge de pose (`gadget_disponible`), bobine éteinte sous
## le seuil de rallumage (`GameState.appui_gadget_refuse`). Le voile sans place a son
## propre chemin, `_sentir_pose_sans_place()`, au moment où la pose part. Un appui
## pendant le cooldown de tir N'EST PAS un refus : il part au terme du cooldown.
##
## ⚠️ **Chez le seul joueur qui a pressé** (`_percu_ici`, voir au-dessus) : sinon
## l'hôte, qui simule aussi le client, sentirait les refus de l'autre — donc
## apprendrait qu'il vient d'essayer. **Aucun son** : un son parlerait au monde.
## Et rien de ce qui suit ne touche la simulation — ni `_fusee_pressee`, ni
## `_gadget_pressee`, ni `shoot_cooldown` : les deux pairs ne doivent pas diverger.
func _sentir_les_refus(state: Node, fusee_presse: bool, gadget_presse: bool,
		can_move: bool) -> void:
	var front_f := fusee_presse and not _fusee_tenue
	var front_g := gadget_presse and not _gadget_tenu
	_fusee_tenue = fusee_presse
	_gadget_tenu = gadget_presse
	if not can_move or state == null or not _percu_ici():
		return
	if front_f and not state.fusee_disponible(slot_de_reserve()):
		_ressentir_refus_fusee()
	if front_g and state.appui_gadget_refuse(slot_de_reserve()):
		_ressentir_refus_gadget()

## Étape 28, point 5 — le voile SANS PLACE. La décision reste à l'hôte
## (`GameState.spawn_gadget`, lot B) ; ceci n'est qu'un PRÉ-CONTRÔLE local, au moment
## où la pose part, sur les mêmes arguments que `poser_gadget()` envoie. S'il n'y a
## de place nulle part, le refus se sent comme les autres.
##
## ⚠️ **Il n'ajoute QUE le retour ressenti** : la pose part quand même vers l'hôte, et
## le désarmement de 0,30 s a lieu des deux côtés, strictement comme avant. Un
## pré-contrôle qui retiendrait la pose ou le désarmement ferait diverger les pairs —
## le client voit l'adversaire 100 ms en retard, son verdict peut différer de celui
## de l'hôte. C'est le prix connu : un refus senti que l'hôte accepte, ou l'inverse,
## dans cette fenêtre.
func _sentir_pose_sans_place(state: Node) -> void:
	if state == null or not _percu_ici():
		return
	var classe := current_weapon as ClassData
	if classe == null or classe.gadget == null:
		return
	var point: Vector2 = state.point_de_pose_libre(self, global_position, rotation,
		classe.gadget.slug)
	if not point.is_finite():
		_ressentir_refus_gadget()

func _ressentir_refus_fusee() -> void:
	refus_fusee = DUREE_REFUS
	_rumble(RUMBLE_REFUS, 0.0, 0.05)

func _ressentir_refus_gadget() -> void:
	refus_gadget = DUREE_REFUS
	_rumble(RUMBLE_REFUS, 0.0, 0.05)

func _update_aim_line() -> void:
	if aim_cast == null or aim_line == null: return
	var end_pos = Vector2(2000, 0)
	if aim_cast.is_colliding():
		end_pos = to_local(aim_cast.get_collision_point())
	aim_line.points = PackedVector2Array([Vector2(28, 0), end_pos])

## V4.4 — temps restant du tremblement de refus, lu par le HUD.
var tir_a_sec: float = 0.0
## Q54 — la fenêtre de 220 ms du clic à vide ENTENDU, pour tous les pairs qui simulent
## ce joueur (voir `_clic_a_vide`).
var _clic_a_sec: float = 0.0
## Étape 28, point 5 (2026-09-11) — temps restant du tremblement de refus de la
## FUSÉE et du GADGET, lus par le HUD comme `tir_a_sec`. Locaux à qui a pressé :
## jamais répliqués, jamais lus par la simulation.
var refus_fusee: float = 0.0
var refus_gadget: float = 0.0
## La durée de `tir_a_sec` (0,22 s, plus haut) : un refus a une seule durée.
const DUREE_REFUS := 0.22
## Fronts BRUTS des deux touches, pour le seul ressenti. ⚠️ Surtout pas
## `_fusee_pressee` / `_gadget_pressee` : eux portent la simulation (lancer, pose,
## désarmement) et doivent rester identiques chez l'hôte et dans la prédiction du
## client — un refus qui les toucherait chez le seul joueur local ferait diverger
## les deux pairs.
var _fusee_tenue: bool = false
var _gadget_tenu: bool = false
## État précédent de la détente, pour ne réagir qu'au front montant.
var _detente_pressee: bool = false
## Même chose pour le bouton de fusée.
var _fusee_pressee: bool = false
## Et pour celui du gadget.
var _gadget_pressee: bool = false

## Le verrou du tir semi-automatique : posé AU TIR, levé au relâchement.
##
## ⚠️ **Levé en tête de `_physics_process`, AVANT les sorties anticipées** du
## décompte et de la manche inactive. Placé dans le bloc de tir, un relâchement
## pendant le décompte ne serait jamais vu : le joueur devrait relâcher une
## seconde fois pour tirer à la première image de jeu.
##
## ⚠️ **Et levé aussi quand le menu pause est ouvert**, parce que c'est ce que
## voit l'hôte : le client lui envoie alors un paquet neutre, détente relâchée.
## Sans cet alignement, l'hôte lèverait le verrou et pas le client — et à la
## fermeture du menu, gâchette tenue, l'hôte tirerait sans que le client
## prédise rien : une balle officielle orpheline, des munitions divergentes.
var _tir_consomme: bool = false

func shoot():
	if current_weapon == null: return
	if current_ammo <= 0: return
	if is_reloading:
		if not recharge_interruptible(): return
		# Le tir coupe le remplissage. La cartouche EN COURS n'entre pas : le
		# joueur a choisi de tirer avec ce qu'il avait, et le temps déjà passé
		# sur celle-ci est perdu. C'est ce qui garde un coût au choix.
		is_reloading = false
		reload_time_left = 0.0
	
	current_ammo -= 1
	shoot_cooldown = current_weapon.cooldown
	# Le ROOT s'arme ici, du même geste que le cooldown et pour la même raison :
	# `shoot()` tourne chez l'hôte ET dans la prédiction du client, donc les deux
	# pairs arment le même compteur au même tir.
	#
	# ⚠️ L'Occulteur est le seul à ne pas s'immobiliser coup par coup — son
	# pistolet-mitrailleur ne peut pas s'arrêter huit fois de suite. Son root
	# vient à la fin de la rafale, plus bas, au relâchement de la détente.
	var _cl := current_weapon as ClassData
	if _cl != null and _cl.root != null and not _cl.root.apres_rafale:
		_root_restant = _cl.root.duree
		_root_duree = _cl.root.duree
	# V1.5, renforcé (chantier ressenti lourd) — coup dans la manette du
	# tireur, en deux temps plutôt qu'un seul pouls plat.
	#
	# ⚠️ Fusion des deux chantiers : le root et la vibration s'arment au même
	# endroit et ne se gênent pas. La version renforcée de `main` l'emporte sur
	# l'ancien `_rumble(0.0, RUMBLE_SHOOT_STRONG, 0.12)` — c'est le geste qu'Adrien
	# a jugé, et il n'a rien à voir avec l'immobilisation.
	_rumble_shoot()
	
	var final_rot := rotation
	if current_spread_bloom > 0.001:
		var dev := deg_to_rad(randf_range(-current_spread_bloom, current_spread_bloom))
		final_rot += dev
	
	if current_weapon.spread_bloom_per_shot_deg > 0.0:
		current_spread_bloom = minf(
			current_spread_bloom + current_weapon.spread_bloom_per_shot_deg,
			current_weapon.max_spread_bloom_deg
		)
	
	get_tree().call_group("game_state", "spawn_bullet", self, muzzle.global_position, final_rot, current_weapon)
	
	if current_ammo == 0 and current_weapon.max_ammo == 1:
		start_reload()

## Le lancer désarme : pas de tir pendant l'animation (FuseeModele.DESARMEMENT).
## Le cooldown de tir existant porte ce désarmement — non répliqué, simulé
## identiquement chez l'hôte et dans la prédiction client, comme pour le tir.
## L'arbitrage du stock et le spawn restent chez `game_state` (l'hôte).
func lancer_fusee():
	shoot_cooldown = maxf(shoot_cooldown, FuseeModele.DESARMEMENT)
	# Recul plus sourd et plus long qu'un tir : on ne doit pas confondre les
	# deux gestes rien qu'au ressenti dans la main.
	_rumble(RUMBLE_FLARE_WEAK, RUMBLE_FLARE_STRONG, 0.18)
	get_tree().call_group("game_state", "spawn_fusee", self, global_position, rotation)

## Poser un gadget désarme aussi : on a les mains prises. Même mécanique que le
## lancer de fusée — cooldown de tir non répliqué, arbitrage du stock et spawn
## chez `game_state`.
##
## ⚠️ **La position envoyée est celle du JOUEUR, pas celle du gadget.** C'est
## l'hôte qui décide où l'objet se plante réellement — il faut une requête de
## physique pour ne pas le planter dans un mur, et deux mondes pourraient y
## répondre différemment. Voir `GameState._point_de_pose()` — et, pour un gadget
## qui arrête les joueurs, reculé hors des corps ou refusé faute de place
## (`GameState.point_de_pose_libre()`, étape 28). Le désarmement ci-dessous a lieu
## même alors, chez l'hôte comme dans la prédiction : c'est ce qui les garde d'accord.
func poser_gadget():
	shoot_cooldown = maxf(shoot_cooldown, GadgetProfile.DESARMEMENT)
	get_tree().call_group("game_state", "spawn_gadget", self, global_position, rotation)

# ---------------------------------------------------------------------------
# V1.5 — Retour haptique. Tir (fort, bref), impact reçu (moyen), pouls sous
# 30 HP, double coup du vainqueur au kill, tir à sec, rechargement terminé,
# lancer de fusée, mort du perdant, clic du verrou de torche (chantier
# vibrations manettes). Ne vibre
# que la manette du joueur assis devant CE personnage : le device_id de son
# LocalInputProvider, et seulement si ce pad est réellement branché — un
# joueur clavier a souvent un pad posé sur le bureau, il ne doit pas bourdonner
# pour l'adversaire. Intensité pilotée par le réglage CONFORT
# `vibration_manette` (0 à 100 %, pas de plancher en classé : purement local à
# celui qui la ressent, elle ne porte aucune information sur l'adversaire).
# ---------------------------------------------------------------------------
## Ressenti lourd (au-delà de V1.5) — le tir n'est plus un pouls plat mais
## deux temps : un claquement bref (les deux moteurs, presque au plafond) puis
## un grave qui traîne (moteur grave seul). Aucun des deux ne dépend du poids
## par classe du chantier racine (`candela-10-classes-system`, en cours
## ailleurs) : uniforme pour l'instant, à moduler par arme le jour où ce
## chantier fusionne et expose un poids.
const RUMBLE_SHOOT_SNAP_WEAK := 0.2
const RUMBLE_SHOOT_SNAP_STRONG := 0.9
const RUMBLE_SHOOT_TAIL_STRONG := 0.4
const RUMBLE_HIT_WEAK := 0.5
const RUMBLE_HIT_STRONG := 0.3
const RUMBLE_PULSE_WEAK := 0.25
## Mi-temps de 170 BPM : 60 / 85 ≈ 0,71 s entre deux battements.
const RUMBLE_PULSE_PERIOD := 60.0 / 85.0
## Clic sec du percuteur à vide — plus faible et plus court qu'un tir, pour
## ne jamais se confondre avec lui.
const RUMBLE_DRY_FIRE := 0.35
## Étape 28 — un appui de fusée ou de gadget refusé. La MÊME signature que le
## percuteur à vide, délibérément : un refus a un seul goût dans la main. Nommée à
## part pour se doser sans toucher au tir à sec.
const RUMBLE_REFUS := 0.35
## L'arme qui redevient prête : un « tac » sur le moteur grave, pas un coup.
const RUMBLE_RELOAD_READY := 0.45
const RUMBLE_FLARE_WEAK := 0.4
const RUMBLE_FLARE_STRONG := 0.25
## Le clic du cran plein de la torche — les deux moteurs, très bref : c'est un
## déclic mécanique qui se sent, pas un coup qui se ressent.
const RUMBLE_TORCH_LOCK := 0.3
## D3 — durée d'avalement du faisceau à l'extinction de la torche.
const TORCH_FADE_OUT := 0.08
var _low_hp_pulse_accum: float = 0.0
## Étape 28, lot C (2026-09-11) — PRISE D'ESSAI : la dernière vibration DEMANDÉE
## (faible, forte, durée), notée par `_rumble` AVANT tout filtre — fournisseur local,
## manette branchée, curseur « Vibrations de la manette ». Les suites n'ont pas de
## manette : sans elle, `_rumble` sortait à sa première ligne, et aucune ne pouvait
## voir qu'un refus avait cessé de vibrer (revue du lot C). Elle prouve la DEMANDE,
## pas le moteur qui tourne. Jamais lue par le jeu.
var derniere_vibration := Vector3.ZERO

## `_is_locally_piloted()` n'est PAS le bon garde ici : il renvoie toujours
## faux en écran partagé (aucun `match` pour LOCAL_SPLITSCREEN), ce qui
## coupait les quatre vibrations de V1.5 dans le mode qui est l'identité du
## jeu — trouvé en câblant ce chantier, jamais joué manette en main avant.
## Le filtre qui suit lui est équivalent en ligne (le corps répliqué tourne
## sur un `NetworkInputProvider`, jamais un `LocalInputProvider`) et, en
## plus, correct en écran partagé : chaque corps y a bien un pad local, le
## sien. Voir Pièges connus.
func _rumble(weak: float, strong: float, duration: float) -> void:
	derniere_vibration = Vector3(weak, strong, duration)
	var lp := input_provider as LocalInputProvider
	if lp == null: return
	if not Input.get_connected_joypads().has(lp.device_id): return
	var intensite := 1.0
	var gs := get_node_or_null(^"/root/GameSettings")
	if gs and gs.has_method("current_effect"):
		intensite = gs.current_effect("vibration_manette")
	if intensite <= 0.0: return
	Input.start_joy_vibration(lp.device_id, weak * intensite, strong * intensite, duration)

## Remise à zéro du détecteur de pas, à appeler APRÈS toute téléportation
## (spawn de manche, bac à sable). Sans elle, le delta de position entre la
## fin de manche et le spawn passe sous le garde des 100 px et fabrique un
## pas fantôme — son + empreinte — pile au « FIGHT ! » (constat de revue).
func reset_step_tracker() -> void:
	_last_step_pos = global_position
	step_distance_accumulated = 0.0
	last_fatal_perp = -1.0

## À appeler avec `reset_step_tracker()` à chaque nouvelle manche : le cran
## plein d'un bouton mécanique à deux crans (voir `LocalInputProvider`) est une
## mémoire, et une mémoire qui survit à la mort rallumerait la torche au spawn
## sans qu'on ait touché la gâchette. `has_method` serait ici une fausse
## prudence — `InputProvider` porte cette méthode par défaut en no-op, tout
## fournisseur en hérite déjà.
func reset_flashlight_latch() -> void:
	if input_provider:
		input_provider.reset_flashlight_state()

## MB2 — chaque manche commence debout. La bascule d'accroupissement est une
## mémoire, comme le cran plein de la torche : survivant à la mort, elle ferait
## réapparaître le joueur accroupi sans qu'il ait touché à rien.
func reset_posture() -> void:
	if input_provider:
		input_provider.reset_crouch_state()
	poser_posture(false)
	# ISO11, L1 — l'enjambement est une mémoire aussi : commencé à la mort, il
	# laisserait la collision des murets coupée au spawn suivant.
	enjambe = false
	collision_mask |= MapGeometry.LOW_WALL_LAYER

## Ressenti lourd du tir : un claquement (les deux moteurs, bref) puis un
## grave qui traîne (moteur grave seul) — pas un pouls plat. Le second temps
## tient dans le cooldown de l'arme la plus rapide (Pistolet, 0,16 s) ; en
## rafale, chaque tir écrase l'attente en cours et relance la sienne, ce qui
## se ressent comme un grondement continu plutôt qu'un défaut.
func _rumble_shoot() -> void:
	_rumble(RUMBLE_SHOOT_SNAP_WEAK, RUMBLE_SHOOT_SNAP_STRONG, 0.07)
	await get_tree().create_timer(0.07).timeout
	if is_instance_valid(self):
		_rumble(0.0, RUMBLE_SHOOT_TAIL_STRONG, 0.08)

## Double coup du kill, ressenti par le vainqueur seulement.
func rumble_kill() -> void:
	_rumble(0.2, 0.9, 0.1)
	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(self):
		_rumble(0.2, 0.9, 0.1)

## Mort ressentie par le perdant : un grave qui s'éteint en trois temps sur
## ~0,5 s, symétrique au double coup du vainqueur (`rumble_kill`) — jusqu'ici
## la victime ne sentait RIEN à sa propre mort. `_rumble` filtre déjà le bon
## pad ; pas de garde `_is_locally_piloted` ici, il coupe l'écran partagé.
func rumble_death() -> void:
	_rumble(0.05, 0.6, 0.15)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self):
		_rumble(0.03, 0.35, 0.15)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self):
		_rumble(0.0, 0.15, 0.2)

func trigger_shoot_visuals():
	add_camera_shake(15.0, 15.0)
	_reculer_le_flash()
	muzzle_flash.enabled = true
	var tw = create_tween()
	var flash_intensity = current_weapon.muzzle_flash_intensity if current_weapon else 1.0
	# Curseur MONDE « Flash de bouche » (plancher 0,6 en classé). Il ne touche
	# que le RENDU : la pénalité d'éblouissement du flash est un modèle à part.
	var curseur_flash := EffectPolicy.curseur("flash_de_tir")
	flash_intensity *= curseur_flash
	# Chantier CLASSES (étape 27) — un tir DANS la suie ne sort pas du nuage : la
	# lumière de bouche et l'éclat dessiné s'y étouffent comme une lampe, et c'est
	# le nuage entier qui pulse (`GadgetVolume.diffuser_flash`). L'éclat, non
	# éclairé et posé au-dessus de la masse, disait sinon la position exacte du
	# tireur. Trouvé en revue (2026-09-11). Visuel seulement : l'éblouissement du
	# flash est un modèle à part, arbitré par l'hôte.
	var hors_suie := 1.0 - _masque_ici
	flash_intensity *= hors_suie
	var flash_duration = current_weapon.muzzle_flash_duration if current_weapon else 0.1
	# Chantier TIR, étape B (2026-10-05) — **le flash ÉCLAIRE.** Adrien : « Il faudrait surtout qu'il y ait un muzzle
	# flash qui se voit et qui éclaire » ; rayon choisi sur maquette : 400 px. La lumière de bouche faisait 64 px
	# d'empreinte, six fois moins que la lumière de coup (400) qu'elle provoque : elle n'éclairait que le canon. Elle
	# couvre désormais `LightTextures.EMPREINTE_FLASH` (800 px), ombres des murs comprises, et descend en
	# `_poser_le_flash()` : blanche au coup, ambre ensuite, éteinte au bout de la durée de l'arme. Le temps d'un éclair,
	# le tir photographie la pièce — l'adversaire proche compris : c'est ici, et pas sur la balle, que le tir révèle.
	# L'éblouissement n'en dépend pas : `Eblouissement.pic_de_flash` a sa propre portée.
	var pic: float = flash_intensity * PIC_DU_FLASH
	_poser_le_flash(0.0, pic)
	# Refonte roman graphique (lot 1, 2026-09-10) — **l'éclat DESSINÉ.** Les
	# trois frames sont des éclats d'encre à pointes (blanc sur noir,
	# `assets/sources/encre/`). Posées sur la seule lumière de bouche, à 64 px
	# d'empreinte, elles restaient noyées sous l'écho au sol de V4.14 : on dessine
	# donc l'éclat lui-même, en sprite non éclairé à la bouche du canon, orienté
	# dans l'axe du tir. Depuis l'étape B du chantier TIR, les trois images
	# vivent sur ce sprite et sur l'étoile de bouche ; le grand flash garde `ECLAT`.
	#
	# DA2.3 — la séquence se déroule PAR-DESSUS la descente d'énergie, qui reste
	# seule maîtresse de la luminosité. Chaque image tient un tiers de la durée :
	# à 0,1 s et 60 Hz cela fait deux images de rendu chacune, à 0,05 s
	# (l'arbalète) une seule. **C'est le nombre que la durée permet, pas un choix
	# esthétique** — au-delà de trois, une image ne serait jamais affichée.
	var eclat := _eclat_de_bouche()
	eclat.texture = LightTextures.masque(LightTextures.FLASH[0])
	eclat.modulate = Color(Charte.HALOGENE, curseur_flash * hors_suie)
	eclat.visible = eclat.texture != null and curseur_flash * hors_suie > 0.0
	# L'étoile de bouche : exactement la lumière de bouche d'avant le chantier TIR (voir `_ready`).
	LightTextures.poser(etoile_de_bouche, LightTextures.FLASH[0], LightTextures.EMPREINTE_ETOILE)
	etoile_de_bouche.enabled = true
	tw.tween_method(_poser_le_flash.bind(pic), 0.0, 1.0, flash_duration)
	tw.parallel().tween_property(etoile_de_bouche, "energy", 0.0, flash_duration).from(flash_intensity)
	for i in range(1, LightTextures.FLASH.size()):
		var chemin: String = LightTextures.FLASH[i]
		tw.parallel().tween_callback(func():
			LightTextures.poser(etoile_de_bouche, chemin, LightTextures.EMPREINTE_ETOILE)
			if is_instance_valid(eclat):
				eclat.texture = LightTextures.masque(chemin)
		).set_delay(flash_duration * float(i) / float(LightTextures.FLASH.size()))
	tw.tween_callback(func():
		muzzle_flash.enabled = false
		etoile_de_bouche.enabled = false
		if is_instance_valid(eclat):
			eclat.visible = false)
	
	# Curseur MONDE « Silhouette révélée au tir » (plancher 0,7 en classé).
	var revele := EffectPolicy.curseur("silhouette_revelee")
	visual_reveal.color.a = revele
	visual_reveal_ptr.color.a = revele
	if tw_reveal and tw_reveal.is_valid():
		tw_reveal.kill()
		
	tw_reveal = create_tween().set_parallel(true)
	# DA4.13 — la révélation s'éteint : EXTINCTION, à 0,012 d'écart de l'`expo
	# out` qu'elle remplace. Ces quatre-là sont les plus longues du jeu (2 s) et
	# les plus regardées : c'est là qu'un changement de courbe se serait vu.
	Charte.animer(tw_reveal, visual_reveal, "color:a", visual_reveal.color.a,
		0.0, 2.0, Charte.Courbe.EXTINCTION)
	Charte.animer(tw_reveal, visual_reveal_ptr, "color:a",
		visual_reveal_ptr.color.a, 0.0, 2.0, Charte.Courbe.EXTINCTION)
	
	if has_node("VisualRevealEnemy"):
		var vre = get_node("VisualRevealEnemy")
		var vrep = get_node("VisualRevealEnemyPtr")
		vre.color = Color(Charte.HALOGENE, revele)
		vrep.color = Color(Charte.HALOGENE, revele)
		Charte.animer(tw_reveal, vre, "color:a", vre.color.a, 0.0, 2.0,
			Charte.Courbe.EXTINCTION)
		Charte.animer(tw_reveal, vrep, "color:a", vrep.color.a, 0.0, 2.0,
			Charte.Courbe.EXTINCTION)
	
	var _slug := current_weapon.slug() if current_weapon else "pistolet"
	# Un PNJ de l'aventure tire « audible de partout » : ni mur ni distance ne l'éteignent (Adrien, 2026-10-04 ; voir `play_weapon_shot`).
	AudioManager.play_weapon_shot(_slug, muzzle.global_position, player_id, est_pnj)
	# V4.10 — **le carreau ne sonne PAS au canon**, et c'est une decision
	# d'Adrien (2026-08-28) : joue ici, il se confondrait avec le coup et
	# n'apprendrait rien. Il sonne la ou il FROLE sa cible — voir
	# `bullet._guetter_le_frolement`. « Une info de TIR, pas de position. »
	if _slug != "arbalete":
		# V4.8 — la douille retombe APRES le coup, jamais avec lui. Le retard
		# est ce qui la rend lisible : jouee sur le tir, elle disparaitrait
		# dedans. Elle tombe aux pieds du tireur, pas au bout du canon.
		_tinter_la_douille()

	# V4.13 — fumée de bouche : trois grains gris qui dérivent après le flash.
	var pool := get_tree().get_first_node_in_group("particle_pool") as ParticlePool
	if pool:
		var canon := Vector2.from_angle(global_rotation)
		pool.emit(ParticlePool.Kind.SMOKE, muzzle.global_position + canon * 6.0,
			Color(Charte.ACIER * 0.6, 0.28), 3, 20.0, 55.0, canon, 70.0)

	# V4.14 — l'écho au sol du tir (`ground_flash`, 130 px) est RETIRÉ (chantier TIR, étape B, 2026-10-05). Il imitait un
	# flash qui éclaire ; le flash éclaire désormais lui-même, avec ses ombres. Une lumière de moins par tir — c'était la
	# seule que chaque coup CRÉAIT : la lumière de bouche, elle, existe une fois par joueur.
	# ⚠️ La règle d'OMBRES O10 (2026-10-04) qu'il portait en dernier — « collé à un mur, l'écho éclairait le sol DE
	# L'AUTRE CÔTÉ et disait à travers la pierre qu'on venait de tirer » — reste tenue : le grand flash et l'étoile de
	# bouche sont ombrés par les murs (`tools/test_ombres_regles.gd`, O10, le vérifie désormais sur eux).

## Où brûle la lampe, dans le repère du joueur (x vers la visée, y à sa droite), en unités de monde : **la lentille
## de la torche que tient le modèle 3D** (chantier des lumières de la 0.8.0, L2 — Adrien, 2026-09-29 : « il faudrait
## que la source de chaque lumière soit attachée au modèle 3D de chaque personnage »). Le bout du fût de la torche
## voxel (`VoxelCorps`, pivot `Torse/Torche`) : `avant_main` + la longueur de la torche vers l'avant, `ecart_main`
## à GAUCHE (la main qui n'engage pas la visée) — 16,1 px devant, 4,55 px à gauche. **Dérivée du squelette**, jamais
## recopiée : la torche est du « matériel standard, identique pour les dix classes » (`VoxelCatalogue.SQUELETTE`),
## donc la même lampe pour tous, et une position que les deux machines calculent de ce qu'elles savent déjà
## (position et visée du joueur) — rien de plus sur le fil. `tools/test_lampe_modele.gd` compare ce point au bout
## du fût voxel, J1 et J2, dans plusieurs visées.
##
## ⚠️ **Elle valait (30, 0) avant L2, plus loin que le rayon du corps (18)** : collé à un mur, le point d'émission de
## la torche se retrouvait 12 px À L'INTÉRIEUR du mur, et les ombres — calculées depuis ce point — laissaient passer
## la lumière de l'autre côté (Adrien, 2026-09-11 : « si on est collé à un mur, on peut éclairer derrière »).
## `_rapprocher_la_lampe()` ramène la lampe du côté du corps dès qu'un mur se trouve entre les deux : c'est lui qui
## tient cette règle, pas la distance — la lentille, plus proche, reste gardée par lui.
const LENTILLE_LAMPE := Vector2(
	(float(VoxelCatalogue.SQUELETTE["avant_main"]) + float(VoxelCatalogue.SQUELETTE["torche"]["longueur"])) * float(CandelaTileSet.TILE_SIZE.x),
	-float(VoxelCatalogue.SQUELETTE["ecart_main"]) * float(CandelaTileSet.TILE_SIZE.x))

## La rétrodiffusion : droit devant, au bord du corps (sa place d'avant L2, inchangée).
const RETRO_AVANCEE := 18.0

## Le flash de bouche : droit devant, au bout du canon (`MuzzleFlash` dans `player.tscn`, le même point que `Muzzle`).
const FLASH_AVANCEE := 28.0

## Ce qu'on laisse entre la lampe et le mur qui l'arrête, en unités de monde.
const RETRAIT_LAMPE := 3.0

## Le pic d'énergie du flash de bouche, multiplié par `muzzle_flash_intensity` de l'arme (chantier TIR, étape B). Il
## descend en `(1 − k)²` sur la durée de l'arme : à 0,1 s et 60 Hz, 69 % puis 44 % aux deux premières images, la queue
## ensuite. 1,8 est l'énergie de la maquette validée le 2026-10-05 ; le jeu la pose sur un masque en paliers (`ECLAT`),
## pas sur le dégradé de la maquette — c'est le réglage à rejuger à l'écran.
const PIC_DU_FLASH := 1.8

## Empreinte de l'éclat de bouche dessiné, en unités de monde. Elle valait 96 px, réglée pour ne pas couvrir l'écho
## au sol de 130 px ; l'écho retiré (chantier TIR, étape B), l'éclat grandit à 120 px. Il reste la FORME du coup, la
## lumière de bouche en est la PORTÉE.
const EMPREINTE_ECLAT_DESSINE := 120.0

## Le flash de bouche à `k` de sa durée (0 : le coup part, 1 : éteint) : énergie `pic × (1 − k)²`, teinte halogène au
## coup, ambre dès 40 % de la durée — un éclair blanc qui retombe en feu.
func _poser_le_flash(k: float, pic: float) -> void:
	var reste := 1.0 - clampf(k, 0.0, 1.0)
	muzzle_flash.energy = pic * reste * reste
	muzzle_flash.color = Charte.HALOGENE.lerp(Charte.AMBRE, clampf(k / 0.4, 0.0, 1.0))

## Le sprite de l'éclat de bouche — créé une fois, réutilisé à chaque tir.
## Enfant de la bouche du canon : il suit la rotation du joueur sans calcul.
## Non éclairé (un éclat est une lumière, il n'attend pas qu'on l'éclaire) et
## en mélange NORMAL, pas additif : posé en additif sur l'écho au sol de V4.14,
## qui sature déjà en blanc au cœur, il disparaissait dedans — mesuré à la
## capture, le 2026-09-10. Une forme d'encre se pose PAR-DESSUS la lumière,
## elle ne s'y ajoute pas. Sa teinte est l'halogène de la charte, pas le blanc
## pur — voir `Charte.HALOGENE`.
func _eclat_de_bouche() -> Sprite2D:
	var existant := muzzle.get_node_or_null("EclatDessine")
	if existant != null:
		return existant
	var s := Sprite2D.new()
	s.name = "EclatDessine"
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	s.material = mat
	s.modulate = Charte.HALOGENE
	s.z_index = 12
	s.visible = false
	var t := LightTextures.masque(LightTextures.FLASH[1])
	if t != null:
		s.scale = Vector2.ONE * (EMPREINTE_ECLAT_DESSINE / float(t.get_width()))
	muzzle.add_child(s)
	return s


## Enregistre un calque d'écran de ce joueur et le confie à `GameState`, qui
## sait quel viewport rend ce joueur. Sans `GameState` (suite, banc), le calque
## reste enfant du joueur, comme avant.
func _loger_calque(calque: CanvasLayer) -> void:
	# ⚠️ Pas de `tree_exited` pour retirer un calque de la liste : reloger un
	# calque passe par `remove_child`, qui l'émet aussi — le premier jet vidait
	# la liste à la première bascule de vue. Un calque libéré (le flash de mort,
	# après son tween) devient simplement invalide, et la liste s'en purge.
	for i in range(calques_ecran.size() - 1, -1, -1):
		if not is_instance_valid(calques_ecran[i]):
			calques_ecran.remove_at(i)
	calques_ecran.append(calque)
	var gs = get_tree().get_first_node_in_group("game_state") if is_inside_tree() else null
	if gs and gs.has_method("accueillir_calque"):
		gs.accueillir_calque(self, calque)
	else:
		add_child(calque)


## `cause` (étape 28, lot E) : `GadgetBase.DEGATS_BALLE` par défaut — la balle et
## les outils n'ont rien à changer ; la nappe de braises passe `DEGATS_BRAISES`.
func take_damage(amount: float, source_player: Node2D, cause: int = GadgetBase.DEGATS_BALLE):
	if dead: return
	# Les PNJ de l'aventure ne se blessent pas entre eux (SOLO, S6) : une même équipe. Le geste le plus simple, et sans effet hors de
	# l'aventure — `est_pnj` n'y est jamais posé. (Les balles d'un PNJ traversent déjà les autres PNJ ; ceci couvre aussi ce qui
	# ne passe pas par `Bullet` : un rebond, une nappe.)
	if est_pnj and source_player != null and source_player.get("est_pnj") == true:
		return

	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
		var new_hp = max(0.0, hp - amount)
		var sid = source_player.player_id if source_player else -1
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
			rpc_update_hp.rpc(new_hp, sid, cause)
		else:
			rpc_update_hp(new_hp, sid, cause)
			
	# ⚠️ **Le son de l'impact n'est PLUS joue ici, et c'etait un doublon reel.**
	# `bullet.gd` joue deja `play_hit` sur le meme evenement, au point d'impact
	# exact et avec la precision du coup ; cette ligne-ci le rejouait depuis le
	# CENTRE du corps, une seconde fois. Deux echantillons superposes a quelques
	# millisecondes, ce qui ne s'entend pas comme un doublon mais comme un son
	# plus epais — donc indosable : aucun niveau n'aurait jamais paru juste au
	# banc de mixage.
	#
	# Il jouait aussi de facon INCOHERENTE : `take_damage` n'est appele que
	# `if not is_replay`, si bien que la killcam n'entendait qu'un impact quand
	# le direct en entendait deux. La balle est la seule a savoir ou et comment
	# elle a touche ; c'est elle qui parle.
	#
	# `hit_sound.play()` est parti avec : `$HitSound` est un `AudioStreamPlayer`
	# SANS FLUX dans `player.tscn` — il ne jouait rien depuis toujours. Le noeud
	# lui-meme reste dans la scene, a la main de qui la tient.
	# Le battement de cœur est celui du JOUEUR : un PNJ de l'aventure blessé à 30 PV ne fait pas battre le sien (SOLO, S6) — il aurait pris
	# `player_id` 1 et fait entendre au joueur humain un cœur qui n'est pas le sien.
	if not est_pnj:
		AudioManager.update_low_health(player_id, hp <= 30.0 and not dead)

	
	# Violent camera shake on hit
	add_camera_shake(35.0, 8.0)
	
	# Trigger damage vignette (flashes red screen edges)
	if vignette_mat:
		# Curseur CONFORT « Vignette de dégâts » — sans lecteur jusqu'au
		# 2026-09-11 (audit DA5.1) : un joueur qui le descendait à zéro voyait
		# le rouge plein à chaque coup.
		var pic := 1.5 * EffectPolicy.curseur("vignette_degats")
		vignette_mat.set_shader_parameter("intensity", pic)
		var tw = create_tween()
		# DA4.13 — EXTINCTION : une intensité qui retombe à zéro.
		Charte.animer_via(tw,
			func(val): vignette_mat.set_shader_parameter("intensity", val),
			pic, 0.0, 0.6, Charte.Courbe.EXTINCTION)

## `cause` (étape 28, lot E) : `GadgetBase.DEGATS_BALLE` ou `DEGATS_BRAISES`. ⚠️ SANS
## valeur par défaut : un appelant resté à deux arguments doit lever une erreur de
## script, pas envoyer un paquet que le pair d'en face jetterait.
@rpc("authority", "call_local", "reliable")
func rpc_update_hp(new_hp: float, source_id: int, cause: int):
	# V1.5 — l'impact se prend au ventre : vibration moyenne sur toute perte de
	# PV, branchée ici (valeur autoritaire) et non sur la balle prédite.
	# V4.6 — et la caméra du blessé encaisse un bref dézoom, même source.
	if new_hp < hp:
		_rumble(RUMBLE_HIT_WEAK, RUMBLE_HIT_STRONG, 0.25)
		var gs = get_tree().get_first_node_in_group("game_state")
		if gs and gs.has_method("camera_hit_kick"):
			gs.camera_hit_kick(player_id)
		AudioManager.play_breath_hit(global_position, player_id)
	# Étape 28, lot E — la télémétrie des gadgets. ICI : c'est la seule ligne que les
	# DEUX pairs exécutent pour chaque PV perdu, et elle doit précéder `die()`, qui
	# archive le match de façon synchrone chez l'hôte et en local. `hp` y vaut encore
	# l'ancienne valeur chez les deux pairs (`take_damage` calcule `new_hp` avant
	# l'appel local ; le client ne touche `hp` qu'ici, au départ de manche et au retour
	# au menu — qui met fin au match) : la perte est la même des deux côtés. La liste
	# est exhaustive, et elle a déjà été fausse d'un cas (revue du 2026-09-11) :
	# `game_state.gd` écrit `p1.hp`/`p2.hp` en trois endroits, `_do_start_round` et les
	# deux du retour au menu. ⚠️ Sans `has_method` : une garde muette ferait
	# d'une fonction absente une télémétrie à zéro, sans erreur (CLAUDE.md, fusion du
	# 2026-09-09).
	var gs_tel = get_tree().get_first_node_in_group("game_state")
	if gs_tel != null:
		gs_tel.noter_pv_perdus(player_id, source_id, cause, maxf(hp - new_hp, 0.0),
			new_hp <= 0.0 and not dead)
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
	# Curseur MONDE « Lumière d'impact » (plancher 0,4 en classé).
	hit_light.energy = 2.0 * EffectPolicy.curseur("lumiere_impact")
	hit_light.shadow_enabled = true
	# OMBRES, O10 (2026-10-04) — le masque des lumières NEUTRES (`CanauxLumiere.masque_ombre_neutre_pour_les_corps`), et plus `1`
	# seul. Les murs l'arrêtaient au sol, mais sa portée (`1 | 4`) touche aussi le capteur de SOI de l'autre joueur, dont le masque
	# (`masque_de_soi`) ne croisait pas `1` : un corps derrière un mur, à moins de 200 px d'un blessé, rougissait dans SA vue à
	# travers la pierre (« `shadow_item_cull_mask` filtre AUSSI les sprites qui reçoivent l'ombre », Pièges connus). Les bits
	# récepteurs du masque neutre (128, 256) lui font recevoir les murs ; aucune couche de corps n'y est — le blessé ne s'ombre
	# pas lui-même, le patron du plafonnier (« Une lumière neutre que les murs doivent couper pour TOUS les corps »).
	hit_light.shadow_item_cull_mask = CanauxLumiere.masque_ombre_neutre_pour_les_corps()
	# Main blood light affects walls (1) and other stuff (4), but NOT players (2)
	hit_light.range_item_cull_mask = 1 | 4
	add_child(hit_light)
	
	# OMBRES, OM6 — le tween vit avec la LUMIÈRE (et non le corps) : la lumière libérée plus tôt (ci-dessous), il s'arrête avec elle.
	var tw_l = hit_light.create_tween()
	# Perfectly smooth, lingering fade out
	# DA4.13 — EXTINCTION. C'était un `SINE_IN_OUT`, symétrique : la charte n'a
	# pas de courbe symétrique et n'en veut pas, une lumière qui meurt n'ayant
	# aucune raison de s'éteindre aussi lentement qu'elle s'est allumée.
	Charte.animer(tw_l, hit_light, "energy", hit_light.energy, 0.0, 1.0,
		Charte.Courbe.EXTINCTION)
	# OMBRES, OM6 (2026-10-05) — la lumière s'en va quand il ne lui reste qu'1 % de son énergie (`FIN_LUMIERE_DE_COUP`), au lieu
	# de la seconde entière : sa traîne n'éclairait plus rien qu'on voie, et coûtait encore une ombre — une par PLOMB, de 400 px.
	# ⚠️ **Couper seulement son ombre, comme le proposait la feuille de route, la ferait passer à travers les murs** : à 0,3 s il
	# lui reste 12 % de son énergie, à 0,5 s encore 3 % — le défaut même qu'OM4a a corrigé (un corps derrière un mur « rougissait
	# à travers la pierre »).
	tw_l.parallel().tween_callback(hit_light.queue_free).set_delay(FIN_LUMIERE_DE_COUP)

## V4.8 — le tintement de la douille, 300 a 500 ms apres le coup.
##
## `await` plutot qu'un `Timer` : le son n'a aucun etat a porter, et un minuteur
## par tir encombrerait l'arbre pendant une fusillade. La garde
## `is_instance_valid` est obligatoire — un joueur peut mourir entre le coup et
## la chute de sa douille, et c'est meme un cas frequent.
func _tinter_la_douille() -> void:
	await get_tree().create_timer(randf_range(0.30, 0.50)).timeout
	if is_instance_valid(self) and not dead:
		AudioManager.play_shell(global_position, player_id)

func die(killer: Node2D):
	if dead: return
	dead = true
	AudioManager.update_low_health(player_id, false)
	# V2.8 — le sifflement et le monde etouffe, **sur la machine du perdant
	# seulement**. `_is_locally_piloted` est la meme garde que l'acouphene
	# d'eblouissement : c'est SON oreille qui siffle, pas celle de l'adversaire
	# qui vient de gagner. En ecran scindé les deux joueurs partagent la sortie —
	# le perdant y est bien le pilote local de ce corps-la.
	if _is_locally_piloted():
		AudioManager.jouer_acouphene_mort()
	rumble_death()

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
	ui_layer.name = "CalqueFlashMort"
	ui_layer.layer = 100
	# Logé dans le viewport qui rend ce joueur, comme la vignette : `calques_ecran`.
	_loger_calque(ui_layer)
	
	var flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Équité (signalé par la session « menus ») : sans visibility_layer, le
	# bit 1 par défaut rend dans les DEUX vues — le tueur se prenait 600 ms de
	# blanc dans les yeux. Le flash n'appartient qu'à l'écran du mort.
	flash_rect.visibility_layer = 2 if player_id == 0 else 4
	
	var mat = ShaderMaterial.new()
	mat.shader = SHADER_DEATH_FLASH
	# Chantier RR, RR5 — le flash fondu en jeu, ses trois paliers sous `--sans-fondu` (`death_flash.gdshader`).
	mat.set_shader_parameter("fondu", IsoMateriaux.effets_fondus())
	# Curseur CONFORT « Flash de mort » : à zéro, la case blanche ne vient pas.
	var flash_mort := EffectPolicy.curseur("flash_mort")
	mat.set_shader_parameter("flash_intensity", flash_mort)
	flash_rect.material = mat
	ui_layer.add_child(flash_rect)
	
	# Le tween vit avec le calque, pas avec le corps : un PNJ retiré avant la fin du fondu (salle suivante) laissait sinon le calque
	# en place, comme le bandeau plus bas.
	var tw = ui_layer.create_tween()
	# DA4.13 — EXTINCTION, à 0,012 de l'`expo out` d'origine.
	Charte.animer_via(tw,
		func(val): mat.set_shader_parameter("flash_intensity", val),
		flash_mort, 0.0, 0.6, Charte.Courbe.EXTINCTION)
	tw.tween_callback(ui_layer.queue_free)
	
	# Floating FATAL Text
	#
	# BF2 (2026-09-07) — **un bandeau par vue AFFICHÉE, et non un nœud partagé.**
	#
	# Relevé par Adrien au deuxième essai : le mot le plus fort du jeu s'affichait
	# là où celui qui l'avait mérité ne le voyait pas. Le nœud était unique et
	# n'avait **aucun `visibility_layer`** ; la valeur par défaut est le bit 1, que
	# les DEUX masques de cull contiennent — `~4` pour la vue de J1, `~2` pour
	# celle de J2, relevés à l'exécution le 2026-09-07. Les deux écrans dessinaient
	# donc le même nœud au même endroit, à l'aplomb du cadavre. Celui qui tue à
	# 900 px ne voyait rien du tout.
	#
	# ⚠️ **Ce n'est pas ce que DA4.4 a corrigé le 2026-08-26.** Elle a réglé la
	# LARGEUR du bandeau, qui sortait du cadre ; la POSITION n'a jamais été mise en
	# cause, parce que le code suppose depuis toujours qu'on meurt là où l'on
	# regarde. C'est vrai du mourant, jamais du tueur.
	#
	# `die()` tourne sur les deux machines (`rpc_update_hp` est `call_local`) :
	# rien à répliquer, le même code produit partout les mêmes bandeaux.
	# V2.5 — l'arme du tueur signe le kill.
	var texte_fatal := "FATAL"
	if killer and killer != self and killer.current_weapon:
		texte_fatal = "FATAL — %s" % killer.current_weapon.name.to_upper()
	var settings = LabelSettings.new()
	settings.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	settings.font_size = Charte.T_ENSEIGNE
	settings.font_color = Charte.ROUGE
	Charte.contourer_settings(settings, settings.font_size) # DA5.7
	var geo := geometrie_du_bandeau(texte_fatal, settings.font, settings.font_size)

	# V2.9 — la marge du tir fatal, lue AVANT la boucle pour que chaque vue en
	# reçoive une copie. Sa consommation, elle, ne bouge pas : elle reste plus bas.
	var perp := last_fatal_perp

	var vues := [_rect_monde_de_la_vue(0), _rect_monde_de_la_vue(1)]
	# ⚠️ **Le filet, et il compte plus qu'il n'en a l'air.** Une vue que personne
	# ne regarde rend un rectangle vide et ne reçoit pas de bandeau. Mais si
	# AUCUNE des deux n'a pu être mesurée — caméras pas encore debout, chemin
	# d'appel imprévu —, n'afficher aucun bandeau serait pire que le défaut qu'on
	# corrige. On sert alors les deux vues sans cadrage : c'est l'affichage
	# d'avant, mais chacune dans SA vue, donc le défaut d'Adrien ne peut pas
	# revenir par cette porte-là.
	var aucune: bool = vues[0].size == Vector2.ZERO and vues[1].size == Vector2.ZERO
	# Le bandeau et sa marge sont des signes du JcJ, et de lui seul (Adrien, 2026-10-04 : « il ne faut pas jouer le carton rouge
	# "pistolet" quand on est contre des PNJ. Ces mécaniques sont propres au JcJ »). Voir `kill_entre_joueurs()`.
	var jcj := kill_entre_joueurs(killer)
	for idx in 2:
		if not jcj:
			break
		var vue: Rect2 = vues[idx]
		if vue.size == Vector2.ZERO and not aucune:
			continue
		# Bit 2 pour la vue de J1, bit 4 pour celle de J2 : les deux seuls bits que
		# les masques de cull séparent.
		_poser_bandeau_fatal(texte_fatal, settings, geo, vue, 2 << idx, perp)
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

## Ce kill est-il un kill de JcJ — un joueur abattu par un autre joueur ? Le bandeau « FATAL — <arme> » et la marge du tir fatal
## n'ont de sens que là : ils signent un duel et nourrissent le « j'y étais presque » d'une revanche. Contre la machine, ils
## mentent (Adrien, 2026-10-04 : « ces mécaniques sont propres au JcJ »).
##
## Faux dès qu'un des deux corps est un PNJ de l'aventure (`est_pnj`), et partout où `game_state` est en **entraînement** — le
## mode des deux usages solo, l'entraînement contre le bot et l'aventure, où rien ne se joue entre deux personnes. Sans
## `game_state` (bancs isolés du bandeau), le duel est la règle : c'est le cas que ces bancs mesurent.
func kill_entre_joueurs(killer: Node) -> bool:
	if est_pnj or (killer != null and killer.get("est_pnj") == true):
		return false
	var gs := get_tree().get_first_node_in_group("game_state") if is_inside_tree() else null
	return gs == null or gs.get("training_mode") != true


## BF2 — le rectangle du MONDE que montre la vue `idx`, ou un rectangle vide
## quand personne ne la regarde.
##
## ⚠️ **La taille se mesure sur la cible réelle de la caméra, elle ne se suppose
## pas.** Depuis le chantier R (2026-08-25), une vue unique n'est plus rendue par
## un `SubViewport` du tout : `_rendre_dans_la_racine()` pointe la caméra sur la
## fenêtre, dont l'aire 2D en `keep` vaut **1920×1080** — et non les 957 d'une
## vue scindée ni les 1916 du `SubViewport` étiré d'avant. Relevé le 2026-09-07 :
## racine 1920×1080, vues scindées 957×1080 et 958×1080.
##
## ⚠️ **`game_state.gd` est en lecture seule ici, et il n'a besoin d'aucun
## accesseur neuf** — c'est pourquoi le journal n'en demande pas. `cam1` / `cam2`
## sont publiques, et « cette vue est-elle affichée » se lit entièrement sur la
## caméra, en deux cas qui couvrent les cinq configurations du jeu :
##
## - la caméra vise la **fenêtre** → le chantier R l'a détournée, donc c'est
##   celle qu'on regarde ;
## - la caméra vise un `SubViewport` → il est affiché si et seulement s'il
##   dessine encore. C'est le `render_target_update_mode` qui fait foi et **non
##   le `visible` du conteneur** : en rendu racine le conteneur reste visible
##   alors que sa vue est arrêtée, et lire le mauvais des deux donnerait ici un
##   bandeau dans une texture que personne n'affiche.
##
## Le script de `game_state` n'est pas nommé non plus : on passe par le groupe et
## par `Object.get()`. Nommer un script en fait une dépendance de **compilation**,
## et c'est ce qui a empêché `tools/test_bandeau_fatal.gd` de compiler.
func _rect_monde_de_la_vue(idx: int) -> Rect2:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return Rect2()
	var cam := gs.get("cam1" if idx == 0 else "cam2") as Camera2D
	if cam == null or not is_instance_valid(cam):
		return Rect2()
	# ⚠️ `custom_viewport` est déclaré `Node` et non `Viewport` : sans ce
	# transtypage, l'inférence de `taille` échoue et **player.gd cesse de
	# compiler** — pour tout le jeu, pas seulement pour ici.
	var cible := cam.custom_viewport as Viewport
	if cible == null:
		return Rect2()
	var sous_vue := cible as SubViewport
	if sous_vue != null \
			and sous_vue.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return Rect2()
	var zoom := cam.zoom
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		return Rect2()
	# `get_screen_center_position()` tient compte du zoom, du décalage de secousse
	# et des limites : c'est le centre du monde effectivement montré, pas la
	# position nominale de la caméra.
	var taille := cible.get_visible_rect().size / zoom
	return Rect2(cam.get_screen_center_position() - taille * 0.5, taille)


## BF2 — pose un bandeau FATAL complet dans UNE vue, et dans elle seule.
##
## ⚠️ **`visibility_layer` se pose sur CHAQUE `CanvasItem`, jamais sur un
## sous-arbre.** Ils sont quatre ici — le mot, sa plaque enfant, la flèche
## enfant, le sous-titre frère — et un seul oublié le fait ressortir dans les
## deux vues, à l'ancienne place : le défaut qu'on corrige, reproduit par
## distraction.
##
## ⚠️ **Le cadrage n'agit que par un DÉCALAGE ajouté aux positions d'origine.**
## Dans la vue du mort la caméra est sur lui, l'ancre tombe donc au milieu du
## cadre et ce décalage vaut exactement zéro : tout ce qu'Adrien a validé le
## 2026-08-26 y reste au pixel près. C'est la forme la plus courte de la
## garantie de non-régression, et elle se lit dans le code plutôt que dans un
## commentaire.
func _poser_bandeau_fatal(texte: String, settings: LabelSettings,
		geo: Dictionary, vue: Rect2, couche: int, perp: float) -> void:
	var mot: Vector2 = geo["mot"]
	var enfle: float = geo["enfle"]
	# ⚠️ **La plaque FINALE** : celle du départ mesure `enfle` fois moins et se
	# trouve 100 px plus bas. C'est l'arrivée qui doit tenir dans le cadre.
	var plaque_finale: Vector2 = geo["plaque"] * enfle
	var elevation := ELEVATION_BANDEAU + MONTEE_BANDEAU + mot.y * 0.5
	var cadrage := cadrage_du_bandeau(global_position, vue, plaque_finale,
		elevation)
	var decalage: Vector2 = cadrage["centre"] \
		- (global_position + Vector2(0.0, -elevation))

	var lbl := Label.new()
	# Nommé explicitement : la règle du dépôt ne souffre pas d'exception locale,
	# même là où rien n'est répliqué.
	lbl.name = "BandeauFatal%d" % couche
	lbl.text = texte
	lbl.label_settings = settings
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# DA4.4 — **le centrage n'était pas absent, il était INOPÉRANT.** Le rect d'un
	# `Label` épouse son texte, donc `HORIZONTAL_ALIGNMENT_CENTER` centre le texte
	# dans une boîte qui a exactement sa largeur : il ne déplace rien. Ce qu'il
	# faut centrer, c'est la boîte, et cela demande de connaître sa largeur.
	lbl.position = global_position \
		- Vector2(mot.x * 0.5, mot.y + ELEVATION_BANDEAU) + decalage
	lbl.z_index = 200
	lbl.visibility_layer = couche

	var lbl_mat := CanvasItemMaterial.new()
	lbl_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lbl.material = lbl_mat

	# DA4.4 — **le cartouche peint derrière le mot.** FATAL était un label sur le
	# noir : le mot le plus fort du jeu, posé sur rien. Il a maintenant un
	# support — une plaque de tôle frappée, bords rongés, l'encre a bavé.
	#
	# **Le mot reste du TEXTE**, dans la fonte d'enseigne, et la texture ne porte
	# que le support : c'est ce qui laisse « FATAL — POMPE » s'allonger avec le
	# nom de l'arme sans qu'aucune image soit à refaire. Enfant du `Label` et
	# dessiné dessous (`show_behind_parent`), donc il suit le mot dans son envol
	# et sa disparition sans qu'on ait à animer deux nœuds.
	var chemin_cartouche := "res://assets/ui/cartouche_fatal.png"
	if ResourceLoader.exists(chemin_cartouche):
		var plaque := TextureRect.new()
		plaque.name = "Cartouche"
		plaque.texture = load(chemin_cartouche)
		plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plaque.stretch_mode = TextureRect.STRETCH_SCALE
		plaque.show_behind_parent = true
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ⚠️ **La marge est constante, la taille non.** Un cartouche se reconnaît
		# à l'épaisseur de sa bordure, pas à un rapport : la même plaque autour de
		# « FATAL » et de « FATAL — ARBALÈTE » doit montrer la même marge.
		plaque.size = geo["plaque"]
		plaque.position = -geo["marge"]
		# `CARMIN` et non `ROUGE` : le rouge vu à l'intensité d'une chose qui ne
		# s'éclaire plus elle-même, pour que le mot en `ROUGE` ressorte dessus.
		plaque.modulate = Charte.CARMIN
		# Non éclairé, comme le mot qu'il porte : un support qui s'assombrirait
		# hors de la torche disparaîtrait au pire moment.
		plaque.material = lbl_mat
		# ⚠️ Troisième `CanvasItem`, troisième `visibility_layer`. L'enfant
		# n'hérite de rien.
		plaque.visibility_layer = couche
		lbl.add_child(plaque)

	# BF3 (2026-09-07) — **la flèche : où est le corps qu'on ne voit pas.**
	#
	# Elle ne paraît que si le cadavre est hors de la vue. Le cadrage, lui,
	# retient la plaque bien avant — sinon elle dépasserait —, et désigner du
	# doigt un corps que l'on voit très bien serait du bruit : les deux critères
	# sont donc distincts, et c'est `cadrage_du_bandeau()` qui les sépare.
	#
	# Enfant du `Label`, comme le cartouche : elle hérite ainsi de l'envol, de
	# l'agrandissement et de la disparition sans qu'on ait un troisième nœud à
	# animer. Toutes ses cotes sont donc en unités de bandeau, avant `enfle`.
	if cadrage["hors_champ"]:
		var d: Vector2 = cadrage["direction"]
		var demi_plaque: Vector2 = geo["plaque"] * 0.5
		# Le point où la direction perce le bord du cartouche : on met à l'échelle
		# `d` jusqu'à ce qu'il touche le premier des deux côtés. Sans ça, une
		# flèche en diagonale flotterait loin d'un coin.
		var t := 1.0 / maxf(absf(d.x) / demi_plaque.x, absf(d.y) / demi_plaque.y)
		var perce: Vector2 = mot * 0.5 + d * t
		# La pointe dépasse de `DEBORD_FLECHE`, le reste du triangle chevauche la
		# plaque : elle se lit comme une languette du cartouche, pas comme un
		# satellite qui flotte à côté. C'est aussi ce qui la garde dans le cadre —
		# `MARGE_CADRE_BANDEAU` est dimensionnée pour ce seul débord.
		var pointe: Vector2 = perce + d * DEBORD_FLECHE
		var base: Vector2 = perce - d * (TAILLE_FLECHE - DEBORD_FLECHE)
		var cote: Vector2 = d.orthogonal() * TAILLE_FLECHE * 0.5
		var fleche := Polygon2D.new()
		fleche.name = "FlecheFatal"
		fleche.polygon = PackedVector2Array([pointe, base + cote, base - cote])
		# `ROUGE`, celui du mot : la flèche appartient au bandeau, pas au décor.
		fleche.color = Charte.ROUGE
		# ⚠️ **Non éclairée, comme le mot et sa plaque.** Un support qui
		# s'assombrit hors de la torche disparaît au pire moment — et la flèche
		# pointe justement vers là où il n'y a pas de lumière.
		fleche.material = lbl_mat
		# ⚠️ Quatrième `CanvasItem`, quatrième `visibility_layer`. Une flèche qui
		# ressort dans les deux vues montre au mort une direction qui n'est pas la
		# sienne : pire que pas de flèche du tout.
		fleche.visibility_layer = couche
		fleche.z_index = 200
		fleche.z_as_relative = false
		lbl.add_child(fleche)

	get_parent().add_child(lbl)

	# ⚠️ **Le tween appartient au BANDEAU, pas au corps qui meurt** (2026-10-04). Lié au mort par `create_tween()`, il mourait avec
	# lui : le bandeau est posé chez le PARENT, et un corps libéré avant la fin du fondu — un PNJ de l'aventure, retiré au passage à
	# la salle suivante — laissait « FATAL — PISTOLET » et sa marge imprimés dans l'arène pour toujours, sans aucune erreur.
	var txt_tw = lbl.create_tween().set_parallel(true)
	lbl.scale = Vector2.ZERO
	# Le pivot au MILIEU : un pivot fixe à 100 px faisait grandir le bandeau
	# depuis un point situé quelque part dans le mot, donc toujours vers la
	# droite. Au centre, il enfle autour de sa propre place.
	lbl.pivot_offset = mot * 0.5
	# DA4.13 — le claquement puis la montée.
	Charte.animer(txt_tw, lbl, "scale", lbl.scale, Vector2(enfle, enfle),
		Charte.D_MOYEN, Charte.Courbe.REBOND)
	Charte.animer(txt_tw, lbl, "position", lbl.position,
		lbl.position + Vector2(0, -MONTEE_BANDEAU), 1.5, Charte.Courbe.ENTREE)
	txt_tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(1.0)
	txt_tw.chain().tween_callback(lbl.queue_free)

	# V2.9 — « à N px du centre » : le tir fatal raconté au perdant. Le « j'y
	# étais presque » est le moteur du rematch. Connue seulement si la balle
	# fatale a été simulée sur cette machine.
	#
	# BF5 — **il suit le bandeau de SA vue, et rien de plus.** Le même `decalage`
	# lui est appliqué : il garde donc sa place relative au mot, où que le cadrage
	# ait dû poser celui-ci.
	#
	# **Les deux joueurs le voient, tranché par Adrien le 2026-09-09.** La
	# question était réelle : le commentaire ci-dessus le destine au perdant, et
	# le cadrage l'a rendu lisible par le tueur pour la première fois. La réponse
	# est de le laisser aux deux — ne pas restreindre son audience ici.
	if perp < 0.0:
		return
	var sub = Label.new()
	sub.name = "MargeFatal%d" % couche
	sub.text = "à %d px du centre" % int(roundf(perp))
	var sub_settings = LabelSettings.new()
	sub_settings.font = Charte.police_display(Charte.POIDS_DISPLAY)
	sub_settings.font_size = Charte.T_TITRE
	sub_settings.font_color = Charte.HALOGENE
	Charte.contourer_settings(sub_settings, sub_settings.font_size) # DA5.7
	sub.label_settings = sub_settings
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = global_position + Vector2(-100, -20) + decalage
	sub.custom_minimum_size = Vector2(200, 0)
	sub.z_index = 200
	sub.material = lbl_mat
	# ⚠️ Nœud FRÈRE du bandeau, donc quatrième `visibility_layer` à poser à la
	# main. C'est celui qu'on oublie.
	sub.visibility_layer = couche
	get_parent().add_child(sub)
	# Même règle que le bandeau : le tween vit avec l'étiquette, pas avec le corps.
	var sub_tw = sub.create_tween().set_parallel(true)
	sub.modulate.a = 0.0
	sub_tw.tween_property(sub, "modulate:a", 1.0, 0.2).set_delay(0.25)
	Charte.animer(sub_tw, sub, "position", sub.position,
		sub.position + Vector2(0, -60), 1.5, Charte.Courbe.ENTREE)
	sub_tw.tween_property(sub, "modulate:a", 0.0, 0.5).set_delay(1.2)
	sub_tw.chain().tween_callback(sub.queue_free)


func add_camera_shake(intensity: float, decay: float = 5.0):
	# Curseur CONFORT « Secousse de caméra » — jusqu'à zéro, même en classé.
	intensity *= EffectPolicy.curseur("secousse_camera")
	if intensity > shake_intensity:
		shake_intensity = intensity
	shake_decay = decay

## Pic instantané — le flash de tir. Peut dépasser le plafond de la torche : le
## modèle le résorbe ensuite, c'est voulu.
func apply_dazzle(amount: float, source: Node2D = null):
	dazzle_amount = min(1.0, dazzle_amount + amount)
	if source != null:
		noter_la_source_du_pic(source)

## Une image d'éblouissement, appelée par `game_state` et JAMAIS d'ici.
##
## `plafond` est la lumière reçue à cet instant (0 = rien, 1 = faisceau saturant
## dans les yeux). Deux `_process` qui se partagent la même valeur sans se voir,
## c'est précisément le défaut qui vient d'être payé : la montée était dans
## l'un, la descente dans l'autre.
func integrer_eblouissement(plafond: float, delta: float) -> void:
	dazzle_amount = Eblouissement.integrer(dazzle_amount, plafond, delta)


## OMBRES, OM1 (Q81) — après chaque image d'éblouissement, la gagnante de l'image et son plafond : appelée par
## `game_state._maj_eblouissement`, chez l'hôte après l'intégration, chez un client en ligne sur l'éblouissement que l'hôte
## réplique (sans y toucher). Pose `source_eblouissante` (le voile, l'appareil de brouillage), et ne rend la source du NIVEAU
## à la gagnante que lorsque l'éblouissement est retombé à son plafond — voir `_source_du_niveau`.
func retenir_la_source(gagnante: Node2D, plafond: float, delta: float) -> void:
	source_eblouissante = gagnante
	_tenue_du_tir = maxf(0.0, _tenue_du_tir - delta)
	if _tenue_du_tir <= 0.0 and dazzle_amount <= plafond + 0.001:
		_source_du_niveau = gagnante


## OMBRES, OM1 (Q81) — le tireur dont le flash atteint ce joueur : chez l'hôte avec son pic (`apply_dazzle`), chez un client en
## ligne seul (le pic arrive par `net_dazzle`).
func noter_la_source_du_pic(tireur: Node2D) -> void:
	_source_du_niveau = tireur
	_tenue_du_tir = TENUE_DU_TIR


## OMBRES, OM1 (Q81, décision d'Adrien, 2026-10-05) — le corps que l'éblouissement de CE joueur efface à ses yeux : la source
## qui tient son niveau (`_source_du_niveau`) — un corps, une fusée, un gadget, ou lui-même (sa propre torche). Seul un corps
## qui EST cette source s'efface (`Brouillage.opacite_vue`), et le bot n'en perd pas d'autre (`PerceptionBot.corps_distinct`).
func source_du_brouillage() -> Node2D:
	return _source_du_niveau if is_instance_valid(_source_du_niveau) else null

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
