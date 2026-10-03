class_name BotInputProvider
extends InputProvider

## Un bot qui « appuie sur les touches » — chantier SOLO. S1 : il se DÉPLACE. S3 : il AGIT sur ce qu'il perçoit, et il tire.
##
## C'est un `InputProvider` de plus, à côté de `LocalInputProvider` et `NetworkInputProvider` :
## `player.gd` ne sait pas d'où viennent ses commandes, et le bot subit donc exactement les mêmes
## règles que le joueur (vitesse, ralentissements, murs, éblouissement). Aucune simulation
## parallèle à tenir égale. Ce qu'il renvoie, ce sont des commandes, jamais une position.
##
## ## Ce qu'il fait, et surtout ce qu'il ne fait pas
##
## Il rend un vecteur de mouvement vers la prochaine case de son chemin, une direction de visée, la gâchette, la recharge et
## l'état de torche que dit son profil. **Il ne lance jamais de fusée, ne pose aucun gadget, ne s'accroupit pas, n'enjambe pas**
## (S9) : ces méthodes de `InputProvider` ne sont volontairement pas redéfinies. **Il ne tire que si son profil dit `tire`**, et
## `is_shoot_pressed()` / `is_reload_pressed()` restent faux pour tout profil de S1 ou de S2 — le cran « adversaire mobile » ne
## tire donc toujours pas (`test_bot_combat` le prouve en le sabotant).
##
## ## La machine à états de S3 — quatre états, et un seul fil : la MÉMOIRE
##
## Le bot agit sur ce que `PerceptionBotNoeud` lui dit — ce qu'il VOIT (le modèle de vue), ce qu'il ENTEND (une zone), ce dont il
## SE SOUVIENT (`MemoireBot`) — et sur RIEN d'autre. **Il ne lit jamais la place du joueur adverse** : ni son nœud, ni le groupe
## `players`, ni la scène. `test_bot_combat` le garde au texte de ce fichier, et au sabotage (un bot à qui l'on donnerait la vraie
## place fait rougir la garde d'honnêteté).
##
##   • `PATROUILLE` — le déplacement de S1 (ronde, zone, libre), la torche du profil. Il revient ici quand la mémoire s'est effacée.
##   • `ENQUETE`    — la mémoire tient un SON : il marche vers le centre de la zone et la REGARDE (la visée y tourne).
##   • `COMBAT`     — il VOIT (ou vient de voir, `delai_reaction` près) : il s'arrête, se tourne vers ce qu'il a vu avec le lissage et
##                    l'erreur de son profil, tire quand la visée est assez juste, recharge à vide.
##   • `RECHERCHE`  — il a perdu de vue sa cible : il marche vers la dernière place connue, la regarde, et ne tire plus que si la
##                    prudence de son profil le permet. La mémoire qui s'efface le rend à `PATROUILLE`.
##
## **Tous les délais réels passent par `delai_reaction`** : passer à un état plus alarmant (patrouille → enquête, enquête → combat)
## ne se fait qu'après ce délai, compté depuis l'instant où le bot a perçu ce qui l'y pousse ; revenir à un état plus calme est
## immédiat. Pendant le délai il continue ce qu'il faisait — c'est ce qu'un joueur qui n'a rien remarqué fait.
##
## Le bot reste soumis aux règles du joueur : il « appuie sur les touches », et `player.gd` décide s'il tire (cadence, root après
## le tir, munitions, recharge). Lire SON PROPRE corps (munitions, recharge, cadence, orientation) est permis : un joueur sait
## combien de balles il lui reste.
##
## ## Le temps : sa propre `_physics_process`, et `avancer()` pour qui n'a pas de scène
##
## La décision vit dans `avancer(delta, position)`, qui ne lit aucun nœud : une suite en `--script`
## y pose un point matériel et regarde où il va. En jeu, `_physics_process` l'appelle avec la place
## du corps qu'il pilote (son parent). Le bot s'arrête de lui-même quand ce corps est mort.
##
## ## La perception (S2) : montée à part, et jamais lue pour agir
##
## Quand son profil dit `voit` ou `entend` (ou sous le drapeau de débogage `--perception-bot`), le fournisseur monte un
## enfant `PerceptionBotNoeud` qui voit par le MODÈLE (`PerceptionBot.voir`), entend `son_localise` et se souvient
## (`MemoireBot`). **`avancer()` ne lit rien de ce que le nœud sait** : il suit un chemin, quel que soit l'état. C'est `_penser()`
## (appelée par `_physics_process`, jamais par une suite sans scène) qui lit la perception, change d'état, tourne la visée et
## appuie sur la gâchette. Un profil de S1 (sourd et aveugle par défaut, `agit` faux) ne monte rien du tout ; un profil de S2 qui
## perçoit sans `agit` monte le nœud et ne le lit jamais : leur comportement, et leurs tirages, restent exactement ceux d'avant.
## Les réflexes tirent dans leur PROPRE générateur (`_rng_reflexes`), jamais dans celui des cibles du déplacement : monter S3
## ne change aucune cible de la ronde.

const Profil := preload("res://profil_bot.gd")
const Navigation := preload("res://navigation_bot.gd")
const Perception := preload("res://perception_bot_noeud.gd")
const Equip := preload("res://equipement_bot.gd")
const Percep := preload("res://perception_bot.gd")

## À quelle distance du centre d'une case on la tient pour atteinte, en pixels.
##
## Plus que le pas d'une image (4,3 px à pleine vitesse), pour ne pas tourner autour d'un
## point que l'arrondi manque. Mais surtout : le polygone de collision d'un joueur porte un
## NEZ de 28 px devant lui, alors que le centre d'une case n'est qu'à 17,5 px du mur d'en face. Un
## bot qui arrive à pleine vitesse sur la dernière case d'un couloir bute donc de son nez
## ~10,5 px avant le centre ; 12 px lui laissent atteindre son point plutôt que de s'y acharner
## (mesuré par le garde « jamais bloqué » du banc, voir ROADMAP).
const RAYON_ARRIVEE := 12.0
## La durée de marche sur laquelle on juge le progrès, en secondes. Court : un bot qui pousse un
## mur doit s'en apercevoir avant que le joueur ne le remarque.
const DELAI_BLOCAGE := 0.6
## La fraction de la distance attendue sous laquelle le bot est tenu pour bloqué. Basse exprès :
## longer un mur en biais est un vrai progrès, plus lent ; seul « presque immobile » est un blocage.
const PROGRES_MINIMAL := 0.25
## Le temps, à pleine allure, au-delà duquel une même étape du chemin est tenue pour manquée.
## Une étape fait au plus ~50 px (une diagonale), plus le décalage au départ : 0,2 s la franchit.
## 1,2 s laisse six fois cette marge, et laisse le temps de contourner l'autre joueur.
const DELAI_ETAPE := 1.2
## Au moins ce nombre de cases entre deux cibles tirées au hasard : une cible voisine ferait
## trembler le bot sur place au lieu de le faire chercher.
const DISTANCE_MINIMALE_CASES := 4.0
## La vitesse de marche du joueur, si le corps piloté ne la dit pas (`player.gd`, `speed`).
const VITESSE_DE_MARCHE := 260.0
## Vitesse à laquelle la visée rejoint la direction du déplacement, en 1/s. Le corps se tourne déjà
## à 18/s de son côté : ceci ne fait que garder la consigne du bot sans à-coups quand le chemin
## tourne à angle droit.
const LISSAGE_VISEE := 10.0

## Les quatre états du bot (S3). ⚠️ Rangés du plus calme au plus alarmant — `_choisir_l_etat` s'en sert pour savoir si un
## changement demande le délai de réaction (monter) ou non (descendre). Valeurs ajoutées en fin, jamais renumérotées.
enum Etat { PATROUILLE, ENQUETE, RECHERCHE, COMBAT }

## Le plus court délai pendant lequel le combat tient après la dernière vue, en secondes : un bot de délai nul ne doit pas
## lâcher son combat à la première image où une lampe respire.
const TENUE_MIN := 0.1
## Combien de temps la gâchette reste enfoncée sans qu'un coup parte avant que le bot y renonce, en secondes. Un tir part à
## l'image suivante ; ceci ne sert que si le corps refuse (enjambement, recharge qui vient de commencer).
const DELAI_APPUI_MAX := 0.25
## À moins de cette distance de la place qu'il vise, le bot garde sa visée : l'angle d'un point sur soi n'a pas de sens.
const DISTANCE_VISEE_MIN := 4.0
## Le délai minimal entre deux replanifications de la marche vers la mémoire, quand le chemin vient d'échouer, en secondes.
const DELAI_REPLANIFICATION := 1.0
## Un nouveau but d'enquête à moins de ce nombre de cases du précédent ne fait pas replanifier : le centre d'une zone entendue
## bouge d'un son à l'autre, et un bot qui change de chemin à chaque pas ne va nulle part.
const CASES_AVANT_REPLANIFIER := 2.0

var profil: ProfilBot = null
var navigation: NavigationBot = null
## La perception, montée en enfant quand le profil voit ou entend (S2) ; `null` sinon. Lue par les tests et, un jour, par
## S3 — jamais par `avancer()`.
var perception: PerceptionBotNoeud = null

## L'état de la machine de S3 : `PATROUILLE` tant que le bot ne réagit à rien (tout profil de S1 ou de S2).
var etat: int = Etat.PATROUILLE
## Combien de coups le bot a appuyé pour tirer, depuis sa création. Lu par les tests.
var coups_tires := 0

var _rng := RandomNumberGenerator.new()
## Les tirages des RÉFLEXES (l'erreur de visée) : un générateur à part, pour que S3 ne change aucune cible du déplacement.
var _rng_reflexes := RandomNumberGenerator.new()
## La graine du bot, gardée pour semer la perception SANS tirer dans `_rng` : monter la perception ne doit changer aucune
## cible du déplacement (même graine, même suite — ce que garde `test_bot_navigation`).
var _graine := 0
var _mouvement := Vector2.ZERO
## Direction de visée, unitaire ; nulle tant que le bot n'a jamais bougé — `player.gd` ignore alors
## la consigne et garde l'orientation de l'apparition (face au joueur), au lieu de se tourner vers
## un axe arbitraire.
var _visee := Vector2.ZERO
var _chemin: Array[Vector2i] = []
var _etape := 0
var _cible := Vector2i(-1, -1)
var _indice_ronde := 0
## L'anti-blocage : la distance parcourue et le temps de marche de la fenêtre en cours, le temps passé sur
## l'étape courante, et combien de fois de suite on a dû intervenir.
var _derniere_position := Vector2.ZERO
var _parcouru := 0.0
var _temps_de_marche := 0.0
var _temps_etape := 0.0
var _etape_vue := 0
var _blocages_de_suite := 0
## Combien de fois le bot a replanifié ou changé de cible faute de progrès. Lu par les tests ; ne sert à rien d'autre.
var blocages_total := 0

# --- S3 : la machine à états, la visée, la gâchette. Tout ceci est de l'état de DÉCISION : rien n'en sort sauf des commandes.
## L'instant (horloge de la perception) où le bot a commencé de percevoir ce qui l'alarme plus que son état ; `-1` sans délai en cours.
var _reaction_depuis := -1.0
## Le dernier instant où le modèle de vue a dit « vu ». `-INF` : jamais.
var _derniere_vue := -INF
## Le temps passé à viser depuis le début de l'engagement (l'erreur de visée se resserre avec lui), en secondes.
var _t_visee := 0.0
## L'erreur de visée du moment, dans [-1, 1] : multipliée par l'amplitude du moment, en degrés.
var _erreur_unite := 0.0
## L'angle que le bot veut tenir (radians, monde), erreur comprise ; valable si `_a_un_angle`.
var _angle_voulu := 0.0
var _a_un_angle := false
var _gachette := false
var _recharge := false
var _munitions_a_l_appui := 0
var _appui_depuis := 0.0
var _rafale_faite := 0
## Pas de tir avant cet instant (la pause entre deux rafales).
var _pause_jusqu := -INF
## Le chargeur est vide depuis cet instant ; `-1` sinon.
var _vide_depuis := -1.0
## Le but de la marche d'enquête (une case) et l'instant avant lequel on ne replanifie pas.
var _but_enquete := Vector2i(-1, -1)
var _prochain_plan := -INF

# --- S9 : les outils. Tout ceci est de l'état de DÉCISION, comme le reste : rien n'en sort sauf des commandes (torche, posture, fusée, gadget).
## Combien de temps un appui de fusée ou de gadget dure, en secondes : `player.gd` agit sur le FRONT montant, six images suffisent largement.
const APPUI_OUTIL_S := 0.1
## Combien de temps on attend avant de réessayer un outil dont l'appui n'a rien produit (une pose refusée faute de place, une fusée que les
## mains occupées ont retardée), en secondes.
const REESSAI_OUTIL_S := 1.2
## Un lancer de fusée désarme le tireur de ce temps au moins (`FuseeModele.DESARMEMENT`, 0,6 s) ; une pose, de 0,3 s : sous cette valeur,
## après l'appui, le bot tient la fusée pour non partie.
const DESARMEMENT_MINIMAL_FUSEE := 0.3

## La commande de torche du bot tactique (`is_flashlight_pressed`), de posture (`is_crouch_pressed`), les appuis de fusée et de gadget.
var _torche := false
var _accroupi := false
var _fusee_presse := false
var _gadget_presse := false
var _fusee_depuis := 0.0
var _gadget_depuis := 0.0
var _fusee_pret_apres := -INF
var _gadget_pret_apres := -INF
var _gadget_slug_appuye := ""
var _gadget_etait_une_bascule := false
## La visée au moment de l'appui du gadget : ce qui dit OÙ il se plante (96 px devant), pour le geste qui suit (`PUIS_DEDANS`).
var _pose_vers := Vector2.ZERO
## Le repli : il reste tant que `_repli_restant` n'est pas écoulé ; le chemin est celui de `_chemin`, et la machine à états ne le défait pas.
var _repli_actif := false
var _repli_restant := 0.0
## La fin de la dernière rafale, et celle que le repli a déjà traitée (horloge de la perception).
var _rafale_finie_a := -INF
var _rafale_traitee_a := -INF
## Le dernier coup reçu (horloge de la perception) et la vie au pas d'avant.
var _touche_a := -INF
var _hp_vu := -1.0
## Un tirage à part pour les outils : monter l'équipement ne change aucune cible du déplacement ni aucune erreur de visée.
var _rng_equipement := RandomNumberGenerator.new()
## Ce que le bot a fait de ses outils, depuis sa création : lus par les tests, jamais par le bot.
var fusees_lancees := 0
var gadgets_poses := 0
var bascules_gadget := 0
var replis := 0
var poses_par_gadget := {}


## Règle le bot. `graine` rend ses tirages reproductibles : même graine, même profil, même carte,
## même suite de cibles — ce qui est ce qui permet à un test de les comparer.
func configurer(un_profil: ProfilBot, une_navigation: NavigationBot, graine: int = 0) -> void:
	profil = un_profil
	navigation = une_navigation
	_graine = graine
	_rng.seed = graine
	_rng_reflexes.seed = graine ^ 0x7e57
	_rng_equipement.seed = graine ^ 0x9ad9
	reinitialiser()


## Oublie le chemin en cours : à appeler quand le corps a été déplacé d'autorité (réapparition).
func reinitialiser() -> void:
	_oublier_le_chemin()
	# Un corps déplacé d'autorité (réapparition) ne se souvient plus : la mémoire de la manche d'avant n'est pas la sienne — ni
	# l'état, ni la gâchette, ni le délai en cours.
	if perception != null:
		perception.reinitialiser()
	etat = Etat.PATROUILLE
	_reaction_depuis = -1.0
	_derniere_vue = -INF
	_a_un_angle = false
	_gachette = false
	_recharge = false
	_rafale_faite = 0
	_pause_jusqu = -INF
	_vide_depuis = -1.0
	# S9 : les outils repartent de zéro. Une torche allumée, un accroupissement ou un repli de la manche d'avant ne sont pas ceux d'un
	# corps qu'on vient de remettre en jeu ; la fusée et le gadget, eux, se rechargent ailleurs (`GameState`).
	_torche = false
	_accroupi = false
	_fusee_presse = false
	_gadget_presse = false
	_fusee_pret_apres = -INF
	_gadget_pret_apres = -INF
	_repli_actif = false
	_repli_restant = 0.0
	_rafale_finie_a = -INF
	_rafale_traitee_a = -INF
	_touche_a = -INF
	_hp_vu = -1.0


## Le chemin en cours et tout ce que l'anti-blocage en a mesuré : au changement d'état, à la réapparition.
func _oublier_le_chemin() -> void:
	_chemin = []
	_etape = 0
	_cible = Vector2i(-1, -1)
	_mouvement = Vector2.ZERO
	_temps_de_marche = 0.0
	_parcouru = 0.0
	_temps_etape = 0.0
	_etape_vue = 0
	_blocages_de_suite = 0
	_but_enquete = Vector2i(-1, -1)
	_prochain_plan = -INF


func _ready() -> void:
	_monter_la_perception()


## Monte le nœud de perception si le profil voit ou entend — ou si le drapeau de débogage le demande, auquel cas le nœud
## travaille sur une COPIE du profil qui voit et entend, pour l'affichage seulement : le profil du bot ne change pas.
func _monter_la_perception() -> void:
	if perception != null or profil == null or navigation == null:
		return
	var deboguer := DrapeauxDeLancement.present(Perception.DRAPEAU_DEBOGAGE)
	if not (profil.voit or profil.entend or deboguer):
		return
	var corps := get_parent() as Node2D
	if corps == null:
		return
	var pour_le_noeud := profil
	if deboguer and not (profil.voit and profil.entend):
		pour_le_noeud = profil.duplicate() as ProfilBot
		pour_le_noeud.voit = true
		pour_le_noeud.entend = true
	var noeud := Perception.new()
	noeud.configurer(pour_le_noeud, navigation.carte, corps, _graine ^ 0x5eed, deboguer)
	perception = noeud
	add_child(noeud)


func _physics_process(delta: float) -> void:
	var corps := get_parent() as Node2D
	if corps == null:
		return
	# Un corps mort ne marche pas : `player.gd` n'y lit plus ses commandes, mais le bot ne doit pas
	# non plus continuer de « décider » — il reprendrait son chemin d'avant la mort à la réapparition.
	if bool(corps.get("dead")):
		_mouvement = Vector2.ZERO
		_gachette = false
		_recharge = false
		return
	var vitesse := VITESSE_DE_MARCHE
	var lue: Variant = corps.get("speed")
	if lue is float and float(lue) > 0.0:
		vitesse = float(lue)
	# S9 : accroupi, le corps avance au quart de sa vitesse (`Player.FACTEUR_VITESSE_ACCROUPI`) ; l'anti-blocage compare la distance
	# parcourue à celle d'un corps à pleine marche, et jugerait bloqué un accroupi qui avance bien.
	if _accroupi:
		vitesse *= Equip.FACTEUR_ACCROUPI
	# S3 : décider AVANT de marcher — l'état change ce que `avancer` fait de ce pas. Un profil qui n'agit pas ne passe pas ici.
	if profil != null and profil.agit:
		_penser(delta, corps)
	avancer(delta, corps.global_position, vitesse)


## Un pas de décision : met à jour le vecteur de mouvement et la visée pour un corps en `position`.
func avancer(delta: float, position: Vector2, vitesse: float = VITESSE_DE_MARCHE) -> void:
	if profil == null or navigation == null \
			or profil.deplacement == Profil.Deplacement.IMMOBILE:
		_mouvement = Vector2.ZERO
		return
	# S9 : un REPLI (le bot s'éloigne après un tir, recule après une mine, se met dans son nuage) suit son propre chemin, quel que soit l'état :
	# la machine à états ne le défait pas, la mémoire ne le redirige pas, et la patrouille n'en tire pas d'autre.
	var en_repli := _repli_actif
	# En combat le bot tient sa place : il se tourne et tire (S3). Il ne reprend la marche qu'en perdant sa cible de vue.
	if etat == Etat.COMBAT and not en_repli:
		_mouvement = Vector2.ZERO
		return
	var ici := _case_de(position)

	_guetter_le_blocage(delta, position, ici, vitesse)
	# Enquête et recherche : le chemin mène à la mémoire, pas à une cible tirée au hasard (S3).
	if etat != Etat.PATROUILLE and not en_repli:
		_suivre_la_memoire(ici)

	# Un chemin vide ou achevé : on décide d'où aller. Deux tours au plus, parce qu'un chemin
	# qui s'achève à l'instant où l'on décide (cible à moins d'un rayon d'arrivée) doit pouvoir
	# donner tout de suite le suivant plutôt qu'une image d'immobilité. **Seule la patrouille tire une cible au hasard** : un
	# bot qui enquête et qui est arrivé reste là à regarder, jusqu'à ce que la mémoire s'efface.
	for _tour in 2:
		if _etape >= _chemin.size() and etat == Etat.PATROUILLE and not en_repli:
			_decider(ici)
		while _etape < _chemin.size() \
				and position.distance_to(Navigation.centre_de_la_case(_chemin[_etape])) <= RAYON_ARRIVEE:
			_etape += 1
		if _etape < _chemin.size():
			break
	if _etape >= _chemin.size():
		_mouvement = Vector2.ZERO
		return

	var vers := Navigation.centre_de_la_case(_chemin[_etape]) - position
	var direction := vers.normalized()
	_mouvement = direction * clampf(profil.allure, 0.05, 1.0)
	# La visée suit le déplacement en patrouille seulement : en enquête elle regarde la zone, et c'est `_viser` qui la tourne.
	if etat != Etat.PATROUILLE:
		return
	if _visee == Vector2.ZERO:
		_visee = direction
	else:
		var poids := clampf(delta * LISSAGE_VISEE, 0.0, 1.0)
		_visee = Vector2.from_angle(lerp_angle(_visee.angle(), direction.angle(), poids))


## La case où se trouve le corps, ramenée au sol praticable le plus proche s'il est (par un
## arrondi, un recul de la physique) sur une case que le chemin ne traverse pas.
func _case_de(position: Vector2) -> Vector2i:
	var c := Navigation.case_du_monde(position)
	if navigation.est_praticable(c):
		return c
	var proche := navigation.case_praticable_proche(c)
	return proche if proche.x >= 0 else c


## Choisit la prochaine cible et le chemin qui y mène. Vide si le profil n'en donne aucune, ou si
## aucune des huit premières n'est atteignable : le bot reste alors en place et réessaiera à la
## prochaine image — une ronde posée sur des cases inaccessibles se voit, elle ne fait pas planter.
func _decider(ici: Vector2i) -> void:
	_chemin = []
	_etape = 0
	for _essai in 8:
		var c := prochaine_cible(ici)
		if c.x < 0:
			return
		var ch := _chemin_vers(ici, c)
		if ch.size() >= 2:
			# La cible retenue est la fin du chemin : celle tirée, ou l'entrée de la zone si le bot en est dehors.
			_cible = ch[ch.size() - 1]
			_chemin = ch
			_temps_de_marche = 0.0
			return


## Le chemin de `ici` à `cible`. Pour un bot de ZONE, il reste dans la zone — et un bot qui n'y est pas encore
## (apparu à côté, déplacé) n'a qu'un chemin de TRANSIT : il est coupé à la première case qui entre dans la
## zone, sans quoi un chemin tracé de l'extérieur pourrait en ressortir et y rentrer en contournant un mur,
## et « ne sort jamais du rectangle » ne vaudrait qu'une fois dedans. Arrivé à cette case, il décide en zone.
func _chemin_vers(ici: Vector2i, cible: Vector2i) -> Array[Vector2i]:
	if profil.deplacement != Profil.Deplacement.ZONE or profil.zone.size == Vector2i.ZERO:
		return navigation.chemin(ici, cible)
	if profil.zone.has_point(ici):
		return navigation.chemin(ici, cible, profil.zone)
	var transit: Array[Vector2i] = []
	for c in navigation.chemin(ici, cible):
		transit.append(c)
		if profil.zone.has_point(c):
			return transit
	# Aucune case du chemin n'entre dans la zone (cible injoignable) : pas de chemin.
	transit.clear()
	return transit


## La prochaine cible du profil, en cases, depuis la case `depuis` — `(-1, -1)` s'il n'y en a pas.
##
## Publique et sans effet sur le déplacement : une suite compare deux bots de même graine cible par
## cible, sans rien simuler.
##   • RONDE : le point suivant de `points_ronde`, dans l'ordre, en boucle ; une case non
##     praticable est sautée.
##   • ZONE : une case praticable tirée dans `zone` (taille nulle : comme LIBRE).
##   • LIBRE : une case tirée parmi celles qu'on peut rejoindre à pied depuis `depuis`.
func prochaine_cible(depuis: Vector2i) -> Vector2i:
	if profil == null or navigation == null:
		return Vector2i(-1, -1)
	match profil.deplacement:
		Profil.Deplacement.RONDE:
			var n := profil.points_ronde.size()
			for _i in n:
				var p: Vector2i = profil.points_ronde[_indice_ronde % n]
				_indice_ronde = (_indice_ronde + 1) % n
				if navigation.est_praticable(p) and (p != depuis or n == 1):
					return p
			return Vector2i(-1, -1)
		Profil.Deplacement.ZONE:
			if profil.zone.size != Vector2i.ZERO:
				return _tirer(navigation.cases_dans(profil.zone), depuis)
			return _tirer(navigation.cases_atteignables(depuis), depuis)
		Profil.Deplacement.LIBRE:
			return _tirer(navigation.cases_atteignables(depuis), depuis)
	return Vector2i(-1, -1)


## Une case au hasard, qui ne soit ni `depuis` ni trop proche (quand il y a le choix).
func _tirer(candidates: Array[Vector2i], depuis: Vector2i) -> Vector2i:
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var dernier := Vector2i(-1, -1)
	for _essai in 8:
		var c: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
		dernier = c
		if c != depuis and Vector2(c - depuis).length() >= DISTANCE_MINIMALE_CASES:
			return c
	return dernier


## L'anti-blocage : sans progrès, replanifier ; sans progrès deux fois de suite, changer de cible. Le corps
## peut être retenu par une arête que la grille ne voit pas (le nez, un coin), par l'autre joueur, ou par
## un mur bas que la grille ignorait — quelle qu'en soit la cause, le bot ne s'acharne pas.
##
## **Deux signaux, parce qu'aucun ne suffit seul.**
##   • La DISTANCE PARCOURUE sur `DELAI_BLOCAGE` de marche, et pas le déplacement net : un bot qui atteint
##     sa cible et repart en arrière fait un demi-tour légitime, dont le déplacement net sur la fenêtre
##     est presque nul — le garde l'a déclaré bloqué sur un corps libre, mesuré dans `test_bot_navigation`.
##     Un corps réellement retenu, lui, ne parcourt presque rien.
##   • Le TEMPS passé sur une même étape du chemin : un corps qui glisse le long d'un mur sans jamais
##     atteindre son point parcourt de la distance et n'avance pourtant pas. Une étape fait au plus une
##     case et demie : ne pas l'avoir franchie en `DELAI_ETAPE / allure` secondes est un blocage.
func _guetter_le_blocage(delta: float, position: Vector2, ici: Vector2i, vitesse: float) -> void:
	if _mouvement == Vector2.ZERO:
		_temps_de_marche = 0.0
		_parcouru = 0.0
		_temps_etape = 0.0
		_derniere_position = position
		return
	_parcouru += position.distance_to(_derniere_position)
	_derniere_position = position
	_temps_de_marche += delta
	if _etape != _etape_vue:
		_etape_vue = _etape
		_temps_etape = 0.0
	_temps_etape += delta
	var allure := clampf(profil.allure, 0.05, 1.0)
	var bloque := _temps_etape >= DELAI_ETAPE / allure
	if _temps_de_marche >= DELAI_BLOCAGE:
		var attendu := vitesse * allure * _temps_de_marche
		bloque = bloque or _parcouru < attendu * PROGRES_MINIMAL
		_temps_de_marche = 0.0
		_parcouru = 0.0
		if not bloque:
			_blocages_de_suite = 0
	if not bloque:
		return
	_temps_etape = 0.0
	_blocages_de_suite += 1
	blocages_total += 1
	if _blocages_de_suite == 1 and _cible.x >= 0:
		var ch := _chemin_vers(ici, _cible)
		if ch.size() >= 2:
			_chemin = ch
			_etape = 0
			_etape_vue = 0
			return
	# Deux fois de suite, ou plus de chemin : une autre cible.
	_blocages_de_suite = 0
	_chemin = []
	_etape = 0
	_etape_vue = 0


# ---------------------------------------------------------------------------
# S3 — PENSER : la perception entre, des commandes sortent.
# ---------------------------------------------------------------------------

## Un pas de pensée, pour un corps vivant : lit la perception, change d'état, tourne la visée, appuie sur la gâchette et sur la
## recharge. **C'est la seule fonction de ce fichier qui lise `perception`** (avec ses sous-fonctions) : `avancer()` n'en sait rien.
func _penser(delta: float, corps: Node2D) -> void:
	if perception == null or perception.memoire == null:
		return
	var maintenant := perception.maintenant()
	var memoire: MemoireBot = perception.memoire
	if bool(perception.derniere_vue.get("vu", false)):
		_derniere_vue = maintenant
	_choisir_l_etat(corps, maintenant, memoire)
	_viser(delta, corps, memoire)
	_gerer_le_tir(corps, maintenant, memoire)
	_gerer_la_recharge(corps, maintenant)
	# S9 : les outils. Un profil sans équipement ne passe pas ici : mêmes commandes, à la graine près, que le bot d'avant.
	if profil.est_equipe():
		_equiper(delta, corps, maintenant, memoire)


## Ce que le bot VEUT faire de ce qu'il sait, et s'il le fait déjà ou doit encore réagir.
##
## Le souhait vient de la mémoire et de la vue, jamais du monde : vu à l'instant (ou à `delai_reaction` près) → combat ; une trace
## de VUE qui s'efface → recherche ; une trace d'OUÏE → enquête ; rien → patrouille. Descendre d'un cran (combat → recherche,
## n'importe quoi → patrouille) est immédiat. Monter demande `delai_reaction`, compté depuis la première image où le souhait
## dépasse l'état — et il redémarre de zéro si, avant son terme, le souhait retombe (le bruit s'est tu, la mémoire s'est effacée).
func _choisir_l_etat(corps: Node2D, maintenant: float, memoire: MemoireBot) -> void:
	var tenue := maxf(profil.delai_reaction, TENUE_MIN)
	var souhait := Etat.PATROUILLE
	if memoire.connue(maintenant):
		if maintenant - _derniere_vue <= tenue:
			souhait = Etat.COMBAT
		elif memoire.source == MemoireBot.Source.VUE:
			souhait = Etat.RECHERCHE
		else:
			souhait = Etat.ENQUETE
	if souhait <= etat:
		_reaction_depuis = -1.0
		if souhait != etat:
			_entrer_dans(souhait, corps)
		return
	if _reaction_depuis < 0.0:
		_reaction_depuis = maintenant
	if maintenant - _reaction_depuis >= profil.delai_reaction:
		_reaction_depuis = -1.0
		_entrer_dans(souhait, corps)


## Change d'état. Le chemin en cours est oublié (il menait ailleurs) ; un engagement qui commence repart d'une visée neuve, et un
## engagement qui finit rend la gâchette.
func _entrer_dans(nouveau: int, corps: Node2D) -> void:
	var avant := etat
	etat = nouveau
	# S9 : un repli en cours n'est pas un chemin d'enquête — changer d'état (la cible a disparu, il faut la chercher) ne le défait pas.
	if not _repli_actif:
		_oublier_le_chemin()
	if avant == Etat.PATROUILLE:
		# Début d'engagement : la consigne de visée part de là où le corps regarde déjà — jamais un demi-tour instantané.
		_visee = Vector2.from_angle(corps.rotation)
		_t_visee = 0.0
		_a_un_angle = false
		_rafale_faite = 0
		_tirer_l_erreur()
	if nouveau == Etat.PATROUILLE:
		_gachette = false
		_a_un_angle = false
		_rafale_faite = 0


## Une nouvelle erreur de visée, dans [-1, 1] : au début d'un engagement et après chaque coup.
func _tirer_l_erreur() -> void:
	_erreur_unite = _rng_reflexes.randf_range(-1.0, 1.0)


## La visée : tourne la consigne vers la place que dit la mémoire (jamais la vraie), de `vitesse_visee` radians par seconde au plus,
## avec l'erreur du moment — qui se resserre de `erreur_visee_deg` à `erreur_visee_min_deg` en `duree_resserrement` secondes
## passées à viser. En patrouille elle ne fait rien : c'est le déplacement qui oriente.
func _viser(delta: float, corps: Node2D, memoire: MemoireBot) -> void:
	if etat == Etat.PATROUILLE:
		return
	var vers := memoire.position - corps.global_position
	if vers.length() < DISTANCE_VISEE_MIN:
		return
	_t_visee += delta
	var amplitude := lerpf(profil.erreur_visee_deg, profil.erreur_visee_min_deg,
		clampf(_t_visee / maxf(profil.duree_resserrement, 0.01), 0.0, 1.0))
	_angle_voulu = vers.angle() + deg_to_rad(_erreur_unite * amplitude)
	_a_un_angle = true
	var courant := _visee.angle() if _visee != Vector2.ZERO else corps.rotation
	var pas := profil.vitesse_visee * delta
	_visee = Vector2.from_angle(courant + clampf(angle_difference(courant, _angle_voulu), -pas, pas))


## La gâchette. Un coup part quand : le profil tire, le bot est engagé et sait où viser, son arme est prête (munitions, pas en
## recharge, cadence), la pause de rafale est finie, la zone n'est pas trop vague pour son audace (sauf s'il VOIT), et **le corps
## est à moins de `tolerance_tir_deg` de l'angle voulu** — l'erreur de visée comprise : c'est elle qui fait manquer un bot lent.
## L'appui dure jusqu'au coup, puis tombe : `player.gd` veut un relâchement entre deux coups d'une arme semi-automatique.
func _gerer_le_tir(corps: Node2D, maintenant: float, memoire: MemoireBot) -> void:
	var munitions := int(corps.get("current_ammo"))
	var attente := float(corps.get("shoot_cooldown"))
	if _gachette:
		if munitions < _munitions_a_l_appui or attente > 0.0:
			_gachette = false
			_rafale_faite += 1
			coups_tires += 1
			_tirer_l_erreur()
			if _rafale_faite >= profil.tirs_par_rafale:
				_rafale_faite = 0
				_pause_jusqu = maintenant + profil.pause_entre_rafales
				_rafale_finie_a = maintenant
		elif maintenant - _appui_depuis > DELAI_APPUI_MAX:
			_gachette = false
		return
	if not profil.tire or etat == Etat.PATROUILLE or not _a_un_angle:
		return
	# S9 : pas de tir pendant un repli (« tire, puis bouge »), ni entre un appui de fusée ou de gadget et son effet (les mains sont prises).
	if _repli_actif or _fusee_presse or _gadget_presse:
		return
	if bool(corps.get("is_reloading")) or munitions <= 0 or attente > 0.0 or maintenant < _pause_jusqu:
		return
	# La prudence : sur une zone entendue ou une place perdue de vue, il ne tire que si elle est assez précise pour valoir de se trahir.
	if etat != Etat.COMBAT and memoire.rayon_a(maintenant) > profil.audace_zone_px:
		return
	if absf(angle_difference(corps.rotation, _angle_voulu)) > deg_to_rad(profil.tolerance_tir_deg):
		return
	_gachette = true
	_munitions_a_l_appui = munitions
	_appui_depuis = maintenant


## La recharge : à vide, après `delai_reaction` (le temps de s'en apercevoir) ; au calme, dès que le chargeur n'est pas plein.
## Un bot qui ne tire pas n'a rien à recharger.
func _gerer_la_recharge(corps: Node2D, maintenant: float) -> void:
	var arme: Variant = corps.get("current_weapon")
	if not profil.tire or arme == null:
		_recharge = false
		return
	var munitions := int(corps.get("current_ammo"))
	if bool(corps.get("is_reloading")) or munitions >= int(arme.max_ammo):
		_recharge = false
		_vide_depuis = -1.0
		return
	if munitions <= 0:
		if _vide_depuis < 0.0:
			_vide_depuis = maintenant
		_recharge = maintenant - _vide_depuis >= profil.delai_reaction
	else:
		_vide_depuis = -1.0
		_recharge = etat == Etat.PATROUILLE


## Le chemin d'enquête et de recherche : de `ici` vers la case praticable la plus proche de la place que dit la mémoire. Replanifié
## quand le but bouge de `CASES_AVANT_REPLANIFIER` cases, ou quand le chemin s'est achevé sans y être (un blocage l'a vidé) — au plus
## une fois par `DELAI_REPLANIFICATION`, pour qu'un but injoignable ne coûte pas un A* par image. Un but injoignable laisse le
## bot sur place, à regarder : il ne se fige pas, il enquête de là où il est.
func _suivre_la_memoire(ici: Vector2i) -> void:
	if perception == null or perception.memoire == null:
		return
	var maintenant := perception.maintenant()
	var but := navigation.case_praticable_proche(Navigation.case_du_monde(perception.memoire.position))
	if but.x < 0:
		_chemin = []
		return
	var change := _but_enquete.x < 0 or Vector2(but - _but_enquete).length() >= CASES_AVANT_REPLANIFIER
	var fini_sans_but := _etape >= _chemin.size() and ici != but
	if not (change or fini_sans_but) or maintenant < _prochain_plan:
		return
	_but_enquete = but
	var ch := _chemin_vers(ici, but)
	if ch.size() >= 2:
		_chemin = ch
		_etape = 0
		_etape_vue = 0
		_cible = ch[ch.size() - 1]
		_temps_de_marche = 0.0
		_prochain_plan = -INF
	else:
		_chemin = []
		_prochain_plan = maintenant + DELAI_REPLANIFICATION


# ---------------------------------------------------------------------------
# S9 — LES OUTILS : la torche, la prudence, la fusée, le gadget de la classe
# ---------------------------------------------------------------------------

## Un pas d'outils, pour un corps vivant : décide de la torche, de la posture, de la fusée et du gadget, et enclenche les replis. **Ne lit que
## ce que `PerceptionBotNoeud` a vu ou entendu** (la mémoire, la vue du moment), SON corps et SA réserve — les règles sont dans
## `equipement_bot.gd`, dont le texte ne contient aucune lecture de l'adversaire (la suite le vérifie). Appelée après `_viser` et
## `_gerer_le_tir` : un outil ne prend jamais le pas sur ce que le bot vient de décider de son arme.
func _equiper(delta: float, corps: Node2D, maintenant: float, memoire: MemoireBot) -> void:
	# Un coup reçu : sa vie baisse. Le bot lit SA vie, comme un joueur lit sa barre.
	# Un corps qui ne dit pas sa vie (un corps factice) n'a jamais été touché : `-1` ne fait jamais baisser.
	var vie: Variant = corps.get("hp")
	var hp := float(vie) if vie != null else -1.0
	if _hp_vu >= 0.0 and hp < _hp_vu:
		_touche_a = maintenant
	_hp_vu = hp

	# Le repli s'écoule ; il s'achève sur place, au bout de son temps.
	if _repli_actif:
		_repli_restant -= delta
		if _repli_restant <= 0.0:
			_repli_actif = false
			_oublier_le_chemin()

	# Une rafale vient de finir : il s'éloigne d'un endroit que son tir a trahi (la prudence d'après tir).
	if _rafale_finie_a > _rafale_traitee_a:
		_rafale_traitee_a = _rafale_finie_a
		if profil.repli_apres_tir_s > 0.0 and profil.deplacement != Profil.Deplacement.IMMOBILE and etat != Etat.PATROUILLE \
				and memoire.connue(maintenant):
			_planifier_un_repli(corps, Equip.Repli.LATERAL, profil.repli_apres_tir_s, memoire.position, Vector2.INF)

	var connue := memoire.connue(maintenant)
	var ici: Vector2 = corps.global_position
	var distance := ici.distance_to(memoire.position) if connue else INF
	var vu := bool(perception.derniere_vue.get("vu", false))

	# La torche et la posture : des COMMANDES, que `player.gd` applique comme à un joueur.
	if profil.torche_tactique:
		_torche = Equip.torche_voulue(profil, etat, connue, distance, _torche, _repli_actif)
	_accroupi = Equip.accroupi_voulu(profil, etat, memoire.source, connue, distance, _accroupi)

	# La fusée et le gadget : ce que le bot lit de sa propre réserve, il le lit chez le nœud d'arbitrage, jamais chez un joueur.
	var jeu := Equip.jeu_du(corps)
	var pid := int(corps.get("player_id"))
	var attente := float(corps.get("shoot_cooldown"))
	var mains_libres := attente <= 0.0 and not _gachette
	var situation := {}
	if connue and etat != Etat.PATROUILLE and (profil.lance_des_fusees or profil.utilise_le_gadget):
		var vers := memoire.position - ici
		situation = {
			"profil": profil, "etat": etat, "source": memoire.source, "connue": true, "distance": distance,
			"rayon": memoire.rayon_a(maintenant), "confiance": memoire.confiance(maintenant),
			"ecart_deg": absf(rad_to_deg(angle_difference(corps.rotation, vers.angle()))),
			"vu": vu, "lampe_vue": (perception.derniere_vue.get("par", []) as Array).has("lampe_de_la_cible"),
			"libre": Percep.segment_degage(ici, memoire.position, perception.monde),
			"touche_depuis": maintenant - _touche_a, "rafale_depuis": maintenant - _rafale_finie_a,
			"mains_libres": mains_libres,
		}
	_gerer_la_fusee(corps, maintenant, jeu, pid, situation)
	_gerer_le_gadget(corps, maintenant, jeu, pid, situation, connue, distance)


## La fusée : un appui de `APPUI_OUTIL_S`, quand `Equip.fusee_voulue` le dit. Elle part vers la zone entendue : `player.gd` la lance droit devant le
## corps, qui est tourné vers elle (c'est une des conditions de la règle).
func _gerer_la_fusee(corps: Node2D, maintenant: float, jeu: Node, pid: int, situation: Dictionary) -> void:
	if _fusee_presse:
		if maintenant - _fusee_depuis >= APPUI_OUTIL_S:
			_fusee_presse = false
			_fusee_pret_apres = maintenant + REESSAI_OUTIL_S
			# Un lancer arme le désarmement du tireur : c'est le seul signe, côté bot, que la fusée est partie.
			if float(corps.get("shoot_cooldown")) >= DESARMEMENT_MINIMAL_FUSEE:
				fusees_lancees += 1
		return
	if situation.is_empty() or maintenant < _fusee_pret_apres:
		return
	situation["fusee_disponible"] = jeu != null and bool(jeu.call("fusee_disponible", pid))
	if Equip.fusee_voulue(situation):
		_fusee_presse = true
		_fusee_depuis = maintenant


## Le gadget : une règle par slug (`Equip.GADGETS`), l'interrupteur à part pour la bobine. Un appui de `APPUI_OUTIL_S`, puis le geste d'après
## (`puis`) si la pose a eu lieu — le jeu a alors armé la recharge d'une minute : c'est le signe que la pose est partie.
func _gerer_le_gadget(corps: Node2D, maintenant: float, jeu: Node, pid: int, situation: Dictionary, connue: bool, distance: float) -> void:
	if jeu == null:
		return
	if _gadget_presse:
		if maintenant - _gadget_depuis >= APPUI_OUTIL_S:
			_gadget_presse = false
			_gadget_pret_apres = maintenant + REESSAI_OUTIL_S
			if _gadget_etait_une_bascule:
				bascules_gadget += 1
			elif not bool(jeu.call("gadget_disponible", pid)):
				gadgets_poses += 1
				poses_par_gadget[_gadget_slug_appuye] = int(poses_par_gadget.get(_gadget_slug_appuye, 0)) + 1
				_commencer_le_puis(corps, _gadget_slug_appuye)
		return
	if not profil.utilise_le_gadget or maintenant < _gadget_pret_apres:
		return
	var slug := Equip.slug_du_gadget(corps)
	if slug == "":
		return
	var bobine: Variant = jeu.call("gadget_basculable_de", pid)
	if bobine != null:
		# Le grésillement posé : la même touche l'allume et l'éteint. Elle n'occupe pas les mains.
		var actif := bool((bobine as Object).get("actif"))
		var lampe_vue := bool(situation.get("lampe_vue", false))
		if Equip.bobine_voulue(etat, connue, distance, lampe_vue, actif) != actif:
			_presser_le_gadget(maintenant, slug, true)
		return
	if situation.is_empty():
		return
	situation["gadget_disponible"] = bool(jeu.call("gadget_disponible", pid))
	if Equip.gadget_voulu(slug, situation):
		_pose_vers = Vector2.from_angle(corps.rotation)
		_presser_le_gadget(maintenant, slug, false)


func _presser_le_gadget(maintenant: float, slug: String, bascule: bool) -> void:
	_gadget_presse = true
	_gadget_depuis = maintenant
	_gadget_slug_appuye = slug
	_gadget_etait_une_bascule = bascule


## Le geste d'après une pose : reculer (la mine aveugle à 460 px, poseur compris) ou se mettre dans son nuage (la suie ne cache que ceux qui
## s'y tiennent). Rien pour les autres. Il part du MÊME point que le jeu — 96 px devant le poseur, dans la direction où il regardait.
func _commencer_le_puis(corps: Node2D, slug: String) -> void:
	var menace: Vector2 = perception.memoire.position
	match Equip.puis_de(slug):
		Equip.PUIS_RECUL:
			_planifier_un_repli(corps, Equip.Repli.RECUL, Equip.DUREE_RECUL_MINE_S, menace, Vector2.INF)
		Equip.PUIS_DEDANS:
			var centre: Vector2 = corps.global_position + _pose_vers * 96.0
			_planifier_un_repli(corps, Equip.Repli.VERS, Equip.DUREE_DANS_LE_NUAGE_S, menace, centre)


## Enclenche un repli : une case où aller (`Equip.case_de_repli`, ou le point donné), un chemin qui respecte la ZONE du profil, un temps.
## Rien ne se passe — et le bot reste où il est — si aucune case ne convient : un repli manqué se voit, il ne fige pas le bot.
func _planifier_un_repli(corps: Node2D, mode: int, duree: float, menace: Vector2, point: Vector2) -> void:
	var ici := _case_de(corps.global_position)
	var cible := Vector2i(-1, -1)
	if mode == Equip.Repli.VERS:
		cible = navigation.case_praticable_proche(Navigation.case_du_monde(point))
	else:
		cible = Equip.case_de_repli(navigation, perception.monde, corps.global_position, menace, mode, _rng_equipement)
	if cible.x < 0:
		return
	var ch := _chemin_vers(ici, cible)
	if ch.size() < 2 and mode != Equip.Repli.VERS:
		return
	_oublier_le_chemin()
	if ch.size() >= 2:
		_chemin = ch
		_cible = cible
	_repli_actif = true
	_repli_restant = duree
	replis += 1


# ---------------------------------------------------------------------------
# Ce que `player.gd` lit. Tout ce qui n'est pas ici reste à `false`, comme dans InputProvider.
# ---------------------------------------------------------------------------

func get_movement_vector() -> Vector2:
	return _mouvement


func get_aim_direction(_player_global_pos: Vector2) -> Vector2:
	return _visee


func is_flashlight_pressed() -> bool:
	# S9 : une torche tactique est une COMMANDE du bot (`_torche`, posée par `_equiper`) ; sinon elle est fixe, comme avant.
	if profil != null and profil.torche_tactique:
		return _torche
	return profil != null and profil.torche_allumee


## La gâchette (S3) : faux pour tout profil qui ne tire pas — rien ne l'enfonce hors de `_gerer_le_tir`, que `profil.tire` garde.
func is_shoot_pressed() -> bool:
	return _gachette


## La recharge (S3) : même garde, `_gerer_la_recharge`.
func is_reload_pressed() -> bool:
	return _recharge


## La fusée (S9) : faux tant que `_equiper` n'a pas décidé d'en lancer une — et elle ne le décide que si le profil `lance_des_fusees`.
func is_flare_pressed() -> bool:
	return _fusee_presse


## Le gadget (S9) : même garde. La même touche pose, puis allume et éteint la bobine du Parasite (`GameState.basculer_gadget`).
func is_gadget_pressed() -> bool:
	return _gadget_presse


## La posture voulue (S9) : accroupi pour approcher un son, selon `accroupi_pres_du_son_px`. Faux sinon : le bot d'avant ne s'accroupissait pas.
func is_crouch_pressed() -> bool:
	return _accroupi


## Pour les tests : le chemin en cours, et la cible visée.
func chemin_courant() -> Array[Vector2i]:
	return _chemin


func cible_courante() -> Vector2i:
	return _cible
