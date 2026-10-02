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
##      C'est le seul axe qui existe en S1, et il est complet ci-dessous.
##   2. **La perception et les réflexes** — sourd et aveugle, perçoit sans tirer, tire s'il
##      voit ou entend, lent ou vif. **Rien n'en est écrit** : voir « La place de l'axe
##      perception-réflexes » plus bas.
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

## ── La place de l'axe perception-réflexes ───────────────────────────────────────────────
##
## **S2 et S3 ajoutent ICI leurs champs, à la suite — rien n'est à renommer ni à déplacer.**
## Le périmètre est celui de la ROADMAP (« Chantier — le mode solo ») : ce que le bot perçoit
## (vue : cône et halo d'une lumière connue ; ouïe : une zone d'incertitude par famille de son),
## puis ce qu'il en fait (délai entre percevoir et agir, erreur et lissage de visée, mémoire de
## la dernière position connue, prudence), et enfin s'il tire.
##
## Deux règles à tenir quand ils arriveront :
##   • **un défaut qui n'allume rien** : tout champ de perception vaut « sourd et aveugle » par
##     défaut, de sorte qu'un profil de S1 reste, sans une ligne changée, le bot qui ne perçoit
##     rien et ne tire jamais ;
##   • **la difficulté vient des réflexes, jamais de l'information** (règle qui prime du
##     chantier) : aucun champ ne doit pouvoir faire voir PLUS que la lumière.
##
## S1 ne définit volontairement aucun de ces champs, pas même inerte : un champ que rien ne lit
## est une promesse que personne ne tient (voir « Un champ que personne ne lit ne se corrige
## pas tout seul » dans les pièges connus).


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
