class_name ProfilBot
extends Resource

## Le profil d'un bot — chantier SOLO, étape S1.
##
## Une ressource de DONNÉES, comme `flare_profile.gd` et `gadget_profile.gd` : elle dit
## ce qu'un bot est, jamais comment il le fait. Le « comment » vit dans
## `bot_input_provider.gd` (les commandes) et `navigation_bot.gd` (les chemins).
##
## ## Un seul bot, deux axes (décision d'Adrien, 2026-10-02)
##
## Le bot de l'entraînement et celui de l'aventure sont **le même** : ce profil les règle
## tous deux, et l'aventure ne fait que monter dans le tableau. Deux axes indépendants.
##
##   1. **Le déplacement** — immobile, ronde répétitive, libre dans une zone, libre partout.
##      Complet depuis S1.
##   2. **La perception et les réflexes** — sourd et aveugle, perçoit sans tirer, tire s'il
##      voit ou entend, lent ou vif. **La perception existe depuis S2** (voit, entend, précision
##      de l'oreille, délai d'oubli : voir « L'axe perception » plus bas) ; **les réflexes
##      existent depuis S3** (agit, tire, délai de réaction, erreur et lissage de visée,
##      discipline de tir, audace : voir « L'axe réflexes » plus bas).
##
## ## Sans dépendance
##
## Ce fichier ne nomme aucun autoload et aucune autre classe globale. Une suite lancée en
## `--script` le charge donc seule (piège du 2026-08-18 : un `preload` qui nomme un autoload
## compile avant que les autoloads n'existent, et l'échec se propage à tout ce qui en
## dépend). Ses cases sont des `Vector2i` de la grille de la carte, pas des pixels : le
## profil ne connaît ni la taille d'une tuile ni la carte, il est donc le même d'une carte
## à l'autre — c'est la carte qui dit si une case est praticable.

## Comment le bot choisit où aller.
##
## - `IMMOBILE` : il ne bouge pas.
## - `RONDE` : il parcourt `points_ronde` dans l'ordre, en boucle.
## - `ZONE` : il tire ses cibles au hasard dans `zone`, et n'en sort pas — ni ses cibles,
##   ni ses chemins.
## - `LIBRE` : il tire ses cibles au hasard sur toute la carte praticable ; il cherche.
##
## ⚠️ Les valeurs sont **ajoutées en fin d'enum et jamais renumérotées** : un profil
## sauvegardé (S6 en portera dans les fichiers de niveau) les écrit par leur entier.
enum Deplacement { IMMOBILE, RONDE, ZONE, LIBRE }

@export var deplacement: Deplacement = Deplacement.IMMOBILE

## Les cases de la ronde, dans l'ordre où elles se visitent ; la dernière ramène à la
## première. Ne sert qu'à `RONDE`. Une case qui n'est pas praticable, ou qu'aucun chemin
## n'atteint, est sautée au lieu de bloquer le bot : une ronde mal posée se voit (le bot ne
## passe pas par là), elle ne le fige pas.
@export var points_ronde: Array[Vector2i] = []

## Le rectangle, en cases, où le bot reste. Ne sert qu'à `ZONE`. Une taille nulle ne
## contraint rien — c'est ce qui fait qu'un profil `ZONE` oublié de son rectangle se
## comporte en `LIBRE` plutôt qu'en statue ; le test de navigation garde ce cas.
@export var zone: Rect2i = Rect2i()

## La fraction de la vitesse de marche que le bot prend, dans ]0, 1]. Le joueur reçoit une
## commande analogique de longueur 1 à fond, et sa vitesse en dérive : le bot envoie donc
## directement ce nombre comme longueur de son vecteur de mouvement, et subit les mêmes
## règles que tout le monde (vitesse, ralentissements, murs).
##
## Elle règle aussi ce qui s'ENTEND : le pas est un aveu, et son niveau suit l'allure
## mesurée sur la distance parcourue (SON VISIBLE, Q47). Un bot lent est un bot discret.
@export_range(0.05, 1.0) var allure: float = 1.0

## La torche, allumée ou non. **Éteinte par défaut, et c'est un choix de conception, pas un
## oubli** : le cran « adversaire mobile » sert à trouver quelqu'un dans le noir, et un bot
## qui éclaire se trahirait avant même que ses pas ne s'entendent. Un bot qui allume sa
## torche est un bot qui a des raisons de le faire — elles viendront avec S3.
@export var torche_allumee: bool = false

## ── L'axe perception — S2 (2026-10-02) ────────────────────────────────────────────────
##
## **Ce que le bot PERÇOIT**, jamais ce qu'il en fait (c'est S3). Le calcul vit dans `perception_bot.gd` (fonctions pures)
## et `perception_bot_noeud.gd` (l'état) ; ces champs ne font que les régler. Règle qui prime du chantier : **la
## difficulté vient des réflexes, jamais de l'information** — aucun champ ci-dessous ne peut donc faire voir PLUS que la
## lumière : `precision_auditive` resserre une zone d'incertitude autour du son (elle ne donne jamais sa position
## exacte), `delai_oubli` règle la mémoire, et `voit` / `entend` ne font qu'ouvrir ou fermer un sens.
##
## **Un défaut qui n'allume rien** : sourd et aveugle. Un profil de S1 reste, sans une ligne changée, le bot qui ne perçoit
## rien — c'est ce que garde `test_bot_perception` — et le cran « adversaire mobile » ne monte même pas le nœud de
## perception (`BotInputProvider._monter_la_perception`).

## Le bot voit-il ? Vrai : il juge ce que la lumière lui montre (torche, éclair, fusée, halo ; les plafonniers de S5
## s'ajouteront à la même liste), selon le MODÈLE de `PerceptionBot.voir` — qui ne voit jamais que MOINS que la lumière.
@export var voit: bool = false

## Le bot entend-il ? Vrai : il écoute `AudioManager.son_localise`, et garde de chaque son une ZONE (jamais la place
## exacte), qui grandit avec la distance et derrière un mur.
@export var entend: bool = false

## La précision de l'oreille : le rayon de la zone d'incertitude est DIVISÉ par ce facteur. 1 vaut l'oreille que décrit le
## liseré du joueur (`SonVisible.percevoir`, les ancres d'Adrien : 10° pour un pas de course tout près, 180° pour un pas
## accroupi) ; 2, une zone deux fois plus étroite ; 0,5, deux fois plus large. Borné : à l'infini il donnerait la place
## exacte, ce que le bot n'a jamais le droit de recevoir (`PerceptionBot.RAYON_ZONE_MIN` plancher le rayon).
## ⚠️ **Chiffre de départ**, non mesuré en jeu — c'est S4 (les profils, réglés au banc) qui le tranchera.
@export_range(0.25, 4.0) var precision_auditive: float = 1.0

## Combien de temps, en secondes, le bot garde une dernière position connue avant de l'oublier tout à fait : sa confiance
## décroît de 1 à 0 sur ce délai (`MemoireBot`). Un bot qui n'a rien perçu n'a rien à oublier : ce champ ne pèse que
## sur ce qui a été vu ou entendu. **Chiffre de départ**, non mesuré (S4).
@export_range(0.5, 60.0) var delai_oubli: float = 6.0

## ── L'axe réflexes — S3 (2026-10-02) ───────────────────────────────────────────────────
##
## **Ce que le bot FAIT de ce qu'il perçoit.** C'est ICI, et seulement ici, que vit la difficulté (Adrien : « trois crans de
## difficulté avec plus ou moins de réflexes ») : aucun champ ci-dessous ne touche à ce que le bot voit ou entend, et les trois
## profils de `pour_adversaire_qui_tire` ont des champs de PERCEPTION identiques — une garde le compare champ à champ.
##
## **Un défaut qui ne change rien au bot de S1 ni de S2** : `agit` et `tire` sont faux. Un profil qui perçoit sans `agit`
## reste le bot de S2 (il marche, il se souvient, il ne réagit à rien) ; un profil qui `agit` sans `tire` enquête, regarde et
## poursuit, sans jamais tirer. Les autres champs règlent COMMENT, et ne pèsent qu'une fois `agit` (ou `tire`) vrai — chacun est
## lu par `bot_input_provider.gd`, et une garde le vérifie au texte (« Un champ que personne ne lit… », Pièges connus).
##
## ⚠️ **Tous les chiffres des trois difficultés sont des chiffres de DÉPART** : posés pour que l'écart se sente, jamais réglés
## en jouant. C'est S4 (les profils, réglés au banc) qui les tranchera.

## Le bot réagit-il à ce qu'il perçoit ? Vrai : il enquête vers un son, se tourne vers ce qu'il voit, cherche la dernière place
## connue de l'adversaire quand il le perd (la machine à états de `BotInputProvider`). Faux : il garde sa ronde, quoi qu'il perçoive.
@export var agit: bool = false

## Le bot tire-t-il ? Vrai : il appuie sur la gâchette quand sa visée est assez juste (et recharge à vide). Faux : il regarde,
## enquête et poursuit sans jamais tirer — le cran 2 de l'entraînement, et les PNJ d'aventure qui ne font que veiller.
@export var tire: bool = false

## Le DÉLAI DE RÉACTION, en secondes : le temps entre l'instant où le bot perçoit quelque chose de plus alarmant que ce qu'il
## traitait (un son quand il patrouillait, la vue de l'adversaire quand il enquêtait) et l'instant où il en fait quelque chose :
## se tourner, marcher, tirer. Il sert aussi à l'attente avant de recharger un chargeur vide, et à tenir un combat dont la cible
## vient de disparaître (un reflet, une lampe qui respire n'y mettent pas fin). Le seul délai du bot : aucun autre ne se cache
## dans son code.
@export_range(0.0, 2.0) var delai_reaction: float = 0.35

## L'ERREUR DE VISÉE, en degrés : l'écart d'amplitude MAXIMALE entre la direction où il veut tirer et celle où se trouve ce
## qu'il perçoit, au premier instant de la poursuite. Elle se resserre jusqu'à `erreur_visee_min_deg` en `duree_resserrement`
## secondes passées à viser : un tireur qui prend son temps vise juste. Tirée au hasard (graine du bot) dans [-1, 1] × cette
## amplitude, et retirée après chaque coup.
@export_range(0.0, 45.0) var erreur_visee_deg: float = 10.0
## Le plancher de cette erreur, en degrés : même au bout de la durée, un bot ne vise pas parfaitement.
@export_range(0.0, 45.0) var erreur_visee_min_deg: float = 2.5
## Le temps, en secondes, que met l'erreur à passer de son maximum à son plancher.
@export_range(0.1, 10.0) var duree_resserrement: float = 2.0

## Le LISSAGE de la visée : la vitesse à laquelle la consigne de visée tourne, en radians par seconde (au plus). Le corps la
## suit à sa propre vitesse (`player.gd`, 18/s) : cette limite est ce qui fait qu'un demi-tour prend du temps.
@export_range(0.5, 40.0) var vitesse_visee: float = 6.0

## La DISCIPLINE DE TIR. Il tire quand le corps est à moins de `tolerance_tir_deg` degrés de la direction qu'il veut tenir (erreur
## de visée comprise) ; il tire `tirs_par_rafale` coups, à la cadence de l'arme, puis attend `pause_entre_rafales` secondes.
@export_range(0.0, 30.0) var tolerance_tir_deg: float = 6.0
@export_range(1, 12) var tirs_par_rafale: int = 2
@export_range(0.0, 5.0) var pause_entre_rafales: float = 0.8

## La PRUDENCE, ou son contraire : jusqu'à quelle largeur de zone, en pixels, le bot ose tirer sur ce qu'il n'a fait qu'ENTENDRE (ou
## sur une place qu'il vient de perdre de vue). Un tir trahit le tireur — l'éclair se voit, le coup s'entend — : tirer sur une zone
## vague, c'est se trahir pour presque rien. 0 : il ne tire que sur ce qu'il voit ; une zone d'un tir à 400 px fait 35 px, celle
## d'un pas à 400 px, 68. Sur ce qu'il voit, la prudence ne joue pas.
@export_range(0.0, 600.0) var audace_zone_px: float = 80.0


## Les trois difficultés du cran 3 de l'entraînement, « adversaire qui tire ». ⚠️ Valeurs ajoutées en fin d'enum, jamais
## renumérotées : `ui.gd` en garde les mêmes entiers (une garde les compare).
enum Difficulte { FACILE, NORMAL, DIFFICILE }

## Le profil du cran 2 de l'entraînement, « adversaire mobile » : il circule partout sur la
## carte, torche éteinte, et ne tire jamais.
##
## ⚠️ **L'allure de 0,7 est un chiffre de départ, pas une mesure.** À 1,0 le bot marche aussi
## vite que le joueur, qui ne le rattrape alors jamais en ligne droite ; à 0,7 la poursuite
## est possible, et ses pas portent moins loin. Il n'a été éprouvé par personne manette en
## main : c'est S4 (les profils, réglés au banc) qui le tranchera.
static func pour_entrainement_mobile() -> ProfilBot:
	var p := new()
	p.deplacement = Deplacement.LIBRE
	p.allure = 0.7
	p.torche_allumee = false
	return p


## Le profil du cran 3 de l'entraînement, « adversaire qui tire » — S3. Il circule comme celui du cran 2 (LIBRE, allure 0,7,
## torche éteinte : la torche tactique est pour S9), VOIT et ENTEND, réagit et tire.
##
## **Seuls les RÉFLEXES changent d'une difficulté à l'autre.** Mêmes champs de perception (voit, entend, précision de l'oreille,
## délai d'oubli), même déplacement, même allure : un bot facile n'est pas aveugle ni sourd, il est lent et approximatif — ce
## qu'un joueur apprend contre lui vaut contre les deux autres.
##
## ⚠️ **Chiffres de DÉPART, non mesurés en jeu** (S4 les réglera). L'ordre de grandeur : le délai d'un joueur humain à un signal
## net est de l'ordre de 0,25 s ; le facile est franchement lent, le difficile à peine plus vif qu'un bon joueur.
##
##                       FACILE   NORMAL   DIFFICILE
##   délai de réaction    0,60     0,35      0,18   s
##   erreur de visée       18       10         5     ° (au départ)
##   … plancher            5        2,5       0,8    °
##   … resserrement        3,0      2,0       1,2    s
##   vitesse de visée      3        6         12     rad/s
##   tolérance de tir      10       6         3      °
##   rafale                1        2         3      coups
##   pause de rafale       1,4      0,8       0,4    s
##   audace (zone)         40       80        140    px
static func pour_adversaire_qui_tire(difficulte: int = Difficulte.NORMAL) -> ProfilBot:
	var p := new()
	p.deplacement = Deplacement.LIBRE
	p.allure = 0.7
	p.torche_allumee = false
	p.voit = true
	p.entend = true
	p.agit = true
	p.tire = true
	match difficulte:
		Difficulte.FACILE:
			p.delai_reaction = 0.60
			p.erreur_visee_deg = 18.0
			p.erreur_visee_min_deg = 5.0
			p.duree_resserrement = 3.0
			p.vitesse_visee = 3.0
			p.tolerance_tir_deg = 10.0
			p.tirs_par_rafale = 1
			p.pause_entre_rafales = 1.4
			p.audace_zone_px = 40.0
		Difficulte.DIFFICILE:
			p.delai_reaction = 0.18
			p.erreur_visee_deg = 5.0
			p.erreur_visee_min_deg = 0.8
			p.duree_resserrement = 1.2
			p.vitesse_visee = 12.0
			p.tolerance_tir_deg = 3.0
			p.tirs_par_rafale = 3
			p.pause_entre_rafales = 0.4
			p.audace_zone_px = 140.0
		_:
			p.delai_reaction = 0.35
			p.erreur_visee_deg = 10.0
			p.erreur_visee_min_deg = 2.5
			p.duree_resserrement = 2.0
			p.vitesse_visee = 6.0
			p.tolerance_tir_deg = 6.0
			p.tirs_par_rafale = 2
			p.pause_entre_rafales = 0.8
			p.audace_zone_px = 80.0
	return p
