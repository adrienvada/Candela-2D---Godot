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
##      de l'oreille, délai d'oubli : voir « L'axe perception » plus bas) ; **les réflexes sont
##      pour S3** et leur place est marquée en bas de cet axe.
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

## ## La place des réflexes — S3 les ajoute ICI, à la suite, sans rien renommer ni déplacer
##
## Le délai entre percevoir et agir, l'erreur et le lissage de visée, la prudence (éteindre la torche, s'accroupir, oser
## tirer alors que l'éclair trahit), puis tirer ou non. Même règle que ci-dessus : un défaut qui ne change rien au bot de
## S2 (pas de tir sans S3), et jamais un champ que personne ne lit (« Un champ que personne ne lit ne se corrige pas tout
## seul », Pièges connus) — S3 n'écrit un champ que le jour où son code le lit.


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
