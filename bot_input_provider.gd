class_name BotInputProvider
extends InputProvider

## Un bot qui « appuie sur les touches » — chantier SOLO, étape S1 : il se DÉPLACE, rien d'autre.
##
## C'est un `InputProvider` de plus, à côté de `LocalInputProvider` et `NetworkInputProvider` :
## `player.gd` ne sait pas d'où viennent ses commandes, et le bot subit donc exactement les mêmes
## règles que le joueur (vitesse, ralentissements, murs, éblouissement). Aucune simulation
## parallèle à tenir égale. Ce qu'il renvoie, ce sont des commandes, jamais une position.
##
## ## Ce qu'il fait, et surtout ce qu'il ne fait pas
##
## Il rend un vecteur de mouvement vers la prochaine case de son chemin, une direction de visée qui
## suit son déplacement, et l'état de torche que dit son profil. **Il ne tire jamais, ne lance
## jamais de fusée, ne pose aucun gadget, ne recharge pas, ne s'accroupit pas, n'enjambe pas** :
## les méthodes correspondantes de `InputProvider` ne sont volontairement pas redéfinies, et
## `test_entrainement_bot` le vérifie au sabotage. Tirer arrive avec S3, voir et entendre avec S2 —
## un bot qui ferait l'un sans l'autre serait un bot qui voit dans le noir (règle qui prime du
## chantier : la difficulté vient des réflexes, jamais de l'information).
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
## (`MemoireBot`). **Le bot ne s'en sert pas encore** : `avancer()` ne lit rien de ce que le nœud sait — agir sur ce qu'il
## perçoit (tourner, poursuivre, tirer) est S3. Un profil de S1 (sourd et aveugle par défaut) ne monte rien du tout :
## son comportement, et ses tirages, restent exactement ceux de S1.

const Profil := preload("res://profil_bot.gd")
const Navigation := preload("res://navigation_bot.gd")
const Perception := preload("res://perception_bot_noeud.gd")

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

var profil: ProfilBot = null
var navigation: NavigationBot = null
## La perception, montée en enfant quand le profil voit ou entend (S2) ; `null` sinon. Lue par les tests et, un jour, par
## S3 — jamais par `avancer()`.
var perception: PerceptionBotNoeud = null

var _rng := RandomNumberGenerator.new()
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


## Règle le bot. `graine` rend ses tirages reproductibles : même graine, même profil, même carte,
## même suite de cibles — ce qui est ce qui permet à un test de les comparer.
func configurer(un_profil: ProfilBot, une_navigation: NavigationBot, graine: int = 0) -> void:
	profil = un_profil
	navigation = une_navigation
	_graine = graine
	_rng.seed = graine
	reinitialiser()


## Oublie le chemin en cours : à appeler quand le corps a été déplacé d'autorité (réapparition).
func reinitialiser() -> void:
	_chemin = []
	_etape = 0
	_cible = Vector2i(-1, -1)
	_mouvement = Vector2.ZERO
	_temps_de_marche = 0.0
	_parcouru = 0.0
	_temps_etape = 0.0
	_etape_vue = 0
	_blocages_de_suite = 0
	# Un corps déplacé d'autorité (réapparition) ne se souvient plus : la mémoire de la manche d'avant n'est pas la sienne.
	if perception != null:
		perception.reinitialiser()


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
		return
	var vitesse := VITESSE_DE_MARCHE
	var lue: Variant = corps.get("speed")
	if lue is float and float(lue) > 0.0:
		vitesse = float(lue)
	avancer(delta, corps.global_position, vitesse)


## Un pas de décision : met à jour le vecteur de mouvement et la visée pour un corps en `position`.
func avancer(delta: float, position: Vector2, vitesse: float = VITESSE_DE_MARCHE) -> void:
	if profil == null or navigation == null \
			or profil.deplacement == Profil.Deplacement.IMMOBILE:
		_mouvement = Vector2.ZERO
		return
	var ici := _case_de(position)

	_guetter_le_blocage(delta, position, ici, vitesse)

	# Un chemin vide ou achevé : on décide d'où aller. Deux tours au plus, parce qu'un chemin
	# qui s'achève à l'instant où l'on décide (cible à moins d'un rayon d'arrivée) doit pouvoir
	# donner tout de suite le suivant plutôt qu'une image d'immobilité.
	for _tour in 2:
		if _etape >= _chemin.size():
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
# Ce que `player.gd` lit. Tout ce qui n'est pas ici reste à `false`, comme dans InputProvider.
# ---------------------------------------------------------------------------

func get_movement_vector() -> Vector2:
	return _mouvement


func get_aim_direction(_player_global_pos: Vector2) -> Vector2:
	return _visee


func is_flashlight_pressed() -> bool:
	return profil != null and profil.torche_allumee


## Pour les tests : le chemin en cours, et la cible visée.
func chemin_courant() -> Array[Vector2i]:
	return _chemin


func cible_courante() -> Vector2i:
	return _cible
