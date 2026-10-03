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


## ── L'axe équipement — S9 (2026-10-02) ─────────────────────────────────────────────────────────────────────────────────────
##
## **Ce que le bot FAIT DE SES OUTILS** : sa torche, sa prudence, sa fusée, le gadget de sa classe. Il « appuie sur les touches »
## comme un joueur (`is_flashlight_pressed`, `is_crouch_pressed`, `is_flare_pressed`, `is_gadget_pressed`) et `player.gd` lui
## applique les règles de tout le monde : désarmement, stock, recharge d'une minute, root, éblouissement. Les règles — QUAND il s'en
## sert, OÙ il pose — vivent dans `equipement_bot.gd` (des fonctions pures), jamais ici : ce profil ne fait que les RÉGLER.
##
## ⚠️ **S'équiper ne donne AUCUNE information** (la règle qui prime, depuis S2). Chaque règle ne lit que ce que le bot perçoit — sa
## mémoire (vue ou zone entendue), son état, SON corps (munitions, vie, posture, classe), sa propre réserve (fusées, gadget : un
## joueur les voit au HUD) et la carte, que n'importe quel joueur a sous les yeux. Une garde (`tools/test_bot_equipement.gd`) le lit au
## texte de `equipement_bot.gd` et au sabotage. Et ce que l'outil fait au BOT, il le lui fait comme à un joueur : une torche qu'il allume
## le trahit, une fusée qu'il lance l'éclaire aussi, un gadget qui bouche la lumière le gêne.
##
## **Un défaut qui ne change rien au bot de S1 à S4** : tous les champs sont éteints. Un profil sans équipement garde donc sa torche
## fixe (`torche_allumee`), ne s'accroupit pas, ne lance rien, ne pose rien — mêmes commandes, à la graine près (la garde le compare).
## Les champs d'équipement ne pèsent qu'une fois `agit` vrai : un bot qui n'agit pas ne passe pas par `_penser()`.
##
## ⚠️ **Tous les chiffres sont des chiffres de DÉPART, passés au banc de jeu (`tools/banc_bot_difficulte.gd`)** : l'équipement change la
## force du bot, et c'est ICI, jamais dans la perception, que le banc le ramène sur les cibles de S4 (80 / 55 / 30 %).

## La torche est-elle un OUTIL ? Vrai : le bot l'allume et l'éteint selon la situation (`EquipementBot.torche_voulue`) et `torche_allumee`
## est ignorée. Faux : la torche est fixe, comme avant S9.
##
## Les règles, quand elle est tactique : **jamais allumée tant qu'il n'a rien perçu** (un bot prudent ne se trahit pas pour rien) ; en
## enquête ou en recherche, **éteinte pendant qu'il s'approche, allumée quand il est assez près de la place qu'il fouille**
## (`torche_rayon_fouille_px`) ; éteinte en combat (il voit déjà ce qui l'a mis en alerte, la lumière ne ferait que le trahir).
@export var torche_tactique: bool = false

## Une torche tactique brûle-t-elle aussi en PATROUILLE ? Faux (le défaut) : le bot prudent. Vrai : un bot qui éclaire son chemin,
## et que sa lampe trahit de loin — celui d'un début de chapitre, pas d'un boss.
@export var torche_en_patrouille: bool = false

## À partir de quelle distance de la place qu'il fouille — le centre de la zone entendue, ou la dernière place connue —, en pixels, le
## bot allume sa torche. Plus grand : il éclaire de plus loin (il voit plus tôt, il se trahit plus tôt) ; 0 : il ne la rallume jamais.
## Une hystérésis de `EquipementBot.HYSTERESIS_TORCHE_PX` l'empêche de clignoter sur la limite.
@export_range(0.0, 1500.0) var torche_rayon_fouille_px: float = 300.0

## La PRUDENCE d'après tir : combien de secondes le bot s'éloigne de sa place après avoir tiré une rafale, torche éteinte, sans tirer
## (un tir trahit : l'éclair se voit, le coup s'entend — c'est la leçon du niveau 0.7). 0 : il reste où il est, comme avant S9.
## Sans effet sur un bot IMMOBILE : une statue ne change pas de place.
@export_range(0.0, 5.0) var repli_apres_tir_s: float = 0.0

## La prudence d'approche : en enquête, le bot s'accroupit — le pas le plus discret du jeu, au quart de la vitesse — quand la zone qu'il
## a entendue est à moins de cette distance, en pixels. 0 : il ne s'accroupit pas.
@export_range(0.0, 1500.0) var accroupi_pres_du_son_px: float = 0.0

## Le bot lance-t-il une fusée vers une zone qu'il a ENTENDUE sans la voir (s'il lui en reste) ? Il n'en lance jamais vers une cible
## qu'il voit : la fusée sert à voir ce qu'on n'a fait qu'entendre. Elle éclaire le bot aussi, et il a pour cela sa distance minimale.
@export var lance_des_fusees: bool = false

## Le bot se sert-il du gadget de SA classe ? Une règle par gadget (`EquipementBot.GADGETS`) : quand le poser, vers où. Faux : il ne pose rien.
@export var utilise_le_gadget: bool = false


## Le profil se sert-il d'au moins un outil ? Faux pour tout profil de S1 à S4 : `BotInputProvider` ne passe alors pas par `_equiper()`, et ses
## commandes restent exactement celles d'avant S9.
func est_equipe() -> bool:
	return torche_tactique or repli_apres_tir_s > 0.0 or accroupi_pres_du_son_px > 0.0 or lance_des_fusees or utilise_le_gadget


## Les trois difficultés du cran 3 de l'entraînement, « adversaire qui tire ». ⚠️ Valeurs ajoutées en fin d'enum, jamais
## renumérotées : `ui.gd` en garde les mêmes entiers (une garde les compare).
enum Difficulte { FACILE, NORMAL, DIFFICILE }

## Les PALIERS DE RÉFLEXES, du plus lent au plus vif — S4. Les trois difficultés de l'entraînement en sont les trois derniers ;
## les deux premiers sont ceux des PNJ de l'initiation, qui doivent laisser à un débutant le temps de réagir. **Une seule table**
## (`appliquer_les_reflexes`) sert l'entraînement, les PNJ et le boss : « les mêmes paliers de réflexes » d'un bout de l'aventure à
## l'autre. ⚠️ Valeurs ajoutées en fin d'enum, jamais renumérotées : un fichier de niveau les écrira par leur entier.
enum Palier { TRES_LENT, LENT, FACILE, NORMAL, DIFFICILE }

## Ce que perçoit un PNJ — S4. Un PNJ qui ne perçoit rien (`AUCUN`) ne réagit à rien et ne tire jamais : c'est un but, pas un
## adversaire. Les trois autres tirent « si vu ou entendu » (décision d'Adrien), chacun avec ses sens.
enum Sens { AUCUN, VUE, OUIE, VUE_ET_OUIE }

## **L'audace est la même pour tout le monde — la difficulté règle QUAND il tire et AVEC QUELLE JUSTESSE, jamais SI.** (S4 ; S3
## l'avait fait varier de 40 à 140 px, et FACILE ne tirait alors jamais sur un pas entendu à 350-400 px, ce que la décision d'Adrien
## — « adversaire qui tire si vu ou entendu » — interdit.) 100 px de zone : un pas entendu jusqu'à ~480 px (zone de 68 px à 400),
## un tir jusqu'à ~1 100 px. Un bot lent qui tire sur ce qu'il a entendu manque : sa visée est large, ses rafales rares.
const AUDACE_ZONE_PX := 100.0

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


## Règle les RÉFLEXES d'un profil sur un palier — et rien d'autre : ni la perception, ni le déplacement, ni l'audace (la même
## partout). Le tableau est celui du banc de jeu (`tools/banc_bot_difficulte.gd`, S4) ; ses chiffres, et pourquoi, sont dans la ROADMAP.
##
##                       TRES_LENT  LENT   FACILE  NORMAL  DIFFICILE
##   délai de réaction     1,20     0,80    0,40    0,26    0,235   s
##   erreur de visée         25       20     11      7,5      6,9    ° (au départ)
##   … plancher              10        7      3       2      1,45    °
##   … resserrement         4,0      3,5    2,5     1,8     1,48    s
##   vitesse de visée        2       2,5     5       8      9,25    rad/s
##   tolérance de tir       12       10      7      4,5     3,95    °
##   rafale                  1        1      2       2        3     coups
##   pause de rafale        2,5      2,0    0,9     0,55    0,49    s
##
## ⚠️ **Plus lent n'est pas plus sûr pour qui AVANCE** : un TRÈS_LENT à 1,5 s (erreur 30° → 12°) laissait à un débutant 79 à 88 % de victoires
## contre un PNJ qui entend, là où 1,2 s lui en laisse 98 à 100 % — tirer tard, c'est tirer sur quelqu'un qui est arrivé à bout portant.
##
## Les trois derniers paliers (FACILE, NORMAL, DIFFICILE) sont ceux de l'entraînement, réglés pour que le joueur type du banc — 0,25 s
## de réaction — les batte environ 80 % / 55 % / 30 % du temps. Les deux premiers sont ceux de l'initiation, réglés contre un débutant.
static func appliquer_les_reflexes(p: ProfilBot, palier: int) -> void:
	p.audace_zone_px = AUDACE_ZONE_PX
	match palier:
		Palier.TRES_LENT:
			p.delai_reaction = 1.2
			p.erreur_visee_deg = 25.0
			p.erreur_visee_min_deg = 10.0
			p.duree_resserrement = 4.0
			p.vitesse_visee = 2.0
			p.tolerance_tir_deg = 12.0
			p.tirs_par_rafale = 1
			p.pause_entre_rafales = 2.5
		Palier.LENT:
			p.delai_reaction = 0.8
			p.erreur_visee_deg = 20.0
			p.erreur_visee_min_deg = 7.0
			p.duree_resserrement = 3.5
			p.vitesse_visee = 2.5
			p.tolerance_tir_deg = 10.0
			p.tirs_par_rafale = 1
			p.pause_entre_rafales = 2.0
		Palier.FACILE:
			p.delai_reaction = 0.40
			p.erreur_visee_deg = 11.0
			p.erreur_visee_min_deg = 3.0
			p.duree_resserrement = 2.5
			p.vitesse_visee = 5.0
			p.tolerance_tir_deg = 7.0
			p.tirs_par_rafale = 2
			p.pause_entre_rafales = 0.9
		Palier.DIFFICILE:
			p.delai_reaction = 0.235
			p.erreur_visee_deg = 6.9
			p.erreur_visee_min_deg = 1.45
			p.duree_resserrement = 1.48
			p.vitesse_visee = 9.25
			p.tolerance_tir_deg = 3.95
			p.tirs_par_rafale = 3
			p.pause_entre_rafales = 0.49
		_:
			p.delai_reaction = 0.26
			p.erreur_visee_deg = 7.5
			p.erreur_visee_min_deg = 2.0
			p.duree_resserrement = 1.8
			p.vitesse_visee = 8.0
			p.tolerance_tir_deg = 4.5
			p.tirs_par_rafale = 2
			p.pause_entre_rafales = 0.55


## Le palier d'une difficulté de l'entraînement (`FACILE` → `FACILE`, `NORMAL` → `NORMAL`, `DIFFICILE` → `DIFFICILE`) ; toute valeur
## inconnue retombe sur NORMAL — le défaut de l'écran, et le boss de l'aventure.
static func palier_de_la_difficulte(difficulte: int) -> int:
	match difficulte:
		Difficulte.FACILE:
			return Palier.FACILE
		Difficulte.DIFFICILE:
			return Palier.DIFFICILE
	return Palier.NORMAL


## Le profil du cran 3 de l'entraînement, « adversaire qui tire » — S3. Il circule comme celui du cran 2 (LIBRE, allure 0,7, torche
## éteinte : la torche tactique est pour S9), VOIT et ENTEND, réagit et tire.
##
## **Seuls les RÉFLEXES changent d'une difficulté à l'autre** (`appliquer_les_reflexes`). Mêmes champs de perception (voit, entend,
## précision de l'oreille, délai d'oubli), même déplacement, même allure, **même audace** : un bot facile n'est pas aveugle ni sourd,
## il est lent et approximatif — ce qu'un joueur apprend contre lui vaut contre les deux autres.
##
## ⚠️ **Réglé au banc de jeu (S4)** contre un joueur type honnête : voir la ROADMAP, section SOLO, pour la méthode, les cibles et les
## chiffres. Ce sont des cibles de départ, à juger par Adrien en jouant.
static func pour_adversaire_qui_tire(difficulte: int = Difficulte.NORMAL) -> ProfilBot:
	var p := new()
	p.deplacement = Deplacement.LIBRE
	p.allure = 0.7
	p.torche_allumee = false
	p.voit = true
	p.entend = true
	p.agit = true
	p.tire = true
	var palier := palier_de_la_difficulte(difficulte)
	appliquer_les_reflexes(p, palier)
	equiper_pour_le_palier(p, palier)
	return p


## Règle les OUTILS d'un profil sur un palier — et rien d'autre : ni la perception, ni les réflexes, ni le déplacement (S9). **Une seule table**,
## comme celle des réflexes : l'entraînement, et le boss de chaque chapitre (`boss()`, le profil NORMAL), s'équipent de la même façon.
## Idempotente : elle éteint tout avant de poser ce que le palier dit.
##
##                       FACILE    NORMAL    DIFFICILE
##   torche tactique      non       oui       oui
##   … fouille à          —         ?         ?       px
##   repli après tir      —         ?         ?       s
##   accroupi près du son —         —         ?       px
##   fusée sur zone       non       non       ?
##   gadget de la classe  non       oui       oui
##
## ⚠️ **Les chiffres sont ceux du banc de jeu** (`tools/banc_bot_difficulte.gd`, ROADMAP S9) : l'équipement change la force du bot, et c'est ICI
## qu'on la ramène sur les cibles de S4 (le joueur type de référence bat FACILE ~80 %, NORMAL ~55 %, DIFFICILE ~30 %) — jamais dans la perception.
## Les paliers des PNJ (`pnj()`) n'ont aucun outil : l'initiation est celle de S4.
static func equiper_pour_le_palier(p: ProfilBot, palier: int) -> void:
	p.torche_tactique = false
	p.torche_en_patrouille = false
	p.torche_rayon_fouille_px = 300.0
	p.repli_apres_tir_s = 0.0
	p.accroupi_pres_du_son_px = 0.0
	p.lance_des_fusees = false
	p.utilise_le_gadget = false
	match palier:
		Palier.NORMAL:
			p.torche_tactique = true
			p.torche_rayon_fouille_px = 300.0
			p.repli_apres_tir_s = 0.6
			p.utilise_le_gadget = true
		Palier.DIFFICILE:
			p.torche_tactique = true
			p.torche_rayon_fouille_px = 300.0
			p.repli_apres_tir_s = 0.3
			p.accroupi_pres_du_son_px = 450.0
			p.lance_des_fusees = true
			p.utilise_le_gadget = true


## ── Le CATALOGUE des PNJ de l'aventure — S4 ───────────────────────────────────────────────────────────────────────────────
##
## Un PNJ est ce même bot, réglé sur les deux axes : **comment il bouge** (`Deplacement`), **ce qu'il perçoit** (`Sens`) et **à
## quel palier de réflexes** (`Palier`). L'aventure monte dans ce tableau : l'initiation (chapitre 0) n'a que des PNJ immobiles et ne
## fait croître que leur nombre ; les chapitres suivants ajoutent les rondes, puis la zone, puis le libre, avec les mêmes paliers.
## **Le boss de chaque chapitre est le profil d'entraînement NORMAL** (décision d'Adrien) : `boss()`.
##
## Le nom d'un PNJ est `<déplacement>_<sens>_<palier>` (`immobile_voit_tres_lent`, `ronde_entend_lent`, `zone_voit_entend_normal`…) ;
## un PNJ sourd et aveugle n'a pas de palier (`immobile_sourd_aveugle`) : il ne réagit à rien. C'est ce nom qu'un fichier de niveau
## (S6) écrira — jamais une suite de champs. `noms_du_catalogue()` les énumère tous, `pnj_nomme()` les construit.
##
## Les allures, elles, sont celles d'un PNJ qui GARDE : une ronde à 0,5, une zone à 0,6, le libre à 0,7 (celle du cran 2).

const _NOMS_DEPLACEMENT := {"immobile": Deplacement.IMMOBILE, "ronde": Deplacement.RONDE, "zone": Deplacement.ZONE, "libre": Deplacement.LIBRE}
const _NOMS_SENS := {"voit": Sens.VUE, "entend": Sens.OUIE, "voit_entend": Sens.VUE_ET_OUIE}
const _NOMS_PALIER := {"tres_lent": Palier.TRES_LENT, "lent": Palier.LENT, "facile": Palier.FACILE, "normal": Palier.NORMAL, "difficile": Palier.DIFFICILE}
const _ALLURE_PNJ := {Deplacement.IMMOBILE: 1.0, Deplacement.RONDE: 0.5, Deplacement.ZONE: 0.6, Deplacement.LIBRE: 0.7}


## Un PNJ : `deplacement`, `sens`, `palier`. Un PNJ `AUCUN` (sourd et aveugle) ignore le palier : il n'agit pas, ses champs de
## réflexes restent ceux d'un profil neuf. Les points de ronde et la zone se posent ensuite, sur le profil rendu.
static func pnj(deplacement: int, sens: int, palier: int = Palier.LENT) -> ProfilBot:
	var p := new()
	p.deplacement = deplacement
	p.allure = _ALLURE_PNJ.get(deplacement, 1.0)
	p.torche_allumee = false
	if sens == Sens.AUCUN:
		return p
	p.voit = sens == Sens.VUE or sens == Sens.VUE_ET_OUIE
	p.entend = sens == Sens.OUIE or sens == Sens.VUE_ET_OUIE
	p.agit = true
	p.tire = true
	appliquer_les_reflexes(p, palier)
	return p


## Le nom d'un PNJ du catalogue.
static func nom_du_pnj(deplacement: int, sens: int, palier: int = Palier.LENT) -> String:
	var d: String = _NOMS_DEPLACEMENT.find_key(deplacement)
	if sens == Sens.AUCUN:
		return d + "_sourd_aveugle"
	var s: String = _NOMS_SENS.find_key(sens)
	var l: String = _NOMS_PALIER.find_key(palier)
	return "%s_%s_%s" % [d, s, l]


## Tous les noms du catalogue : pour chaque déplacement, le PNJ sourd et aveugle, puis chaque sens à chaque palier.
static func noms_du_catalogue() -> Array[String]:
	var noms: Array[String] = []
	for d in _NOMS_DEPLACEMENT.values():
		noms.append(nom_du_pnj(d, Sens.AUCUN))
		for s in _NOMS_SENS.values():
			for pa in _NOMS_PALIER.values():
				noms.append(nom_du_pnj(d, s, pa))
	return noms


## Construit un PNJ par son nom ; `null` si le nom n'est pas du catalogue (un fichier de niveau mal écrit se voit, il ne devient
## pas silencieusement un PNJ par défaut).
static func pnj_nomme(nom: String) -> ProfilBot:
	var morceaux := nom.split("_")
	if morceaux.size() < 3 or not _NOMS_DEPLACEMENT.has(morceaux[0]):
		return null
	var d: int = _NOMS_DEPLACEMENT[morceaux[0]]
	var reste := "_".join(morceaux.slice(1))
	if reste == "sourd_aveugle":
		return pnj(d, Sens.AUCUN)
	for s_nom in _NOMS_SENS:
		if reste.begins_with(s_nom + "_"):
			var palier_nom := reste.substr(s_nom.length() + 1)
			if _NOMS_PALIER.has(palier_nom):
				return pnj(d, _NOMS_SENS[s_nom], _NOMS_PALIER[palier_nom])
	return null


## Les cinq PNJ de l'initiation (chapitre 0), nommés comme la table de la ROADMAP les décrit.
##   0.1 à 0.5  — `pnj_immobile_sourd_aveugle` : un but, pas un adversaire (il ne perçoit rien, ne tire jamais) ;
##   0.6        — `pnj_immobile_voit_tres_lent`   : il voit la torche, tire, réflexes TRÈS lents ;
##   0.7        — `pnj_immobile_voit_lent`        : il voit et tire, réflexes lents (chaque tir réveille les autres) ;
##   0.8        — `pnj_immobile_entend_lent`      : il entend et tire, réflexes lents ;
##   0.9        — `pnj_immobile_voit_entend_lent` : il voit et entend, réflexes lents.
static func pnj_immobile_sourd_aveugle() -> ProfilBot:
	return pnj(Deplacement.IMMOBILE, Sens.AUCUN)


static func pnj_immobile_voit_tres_lent() -> ProfilBot:
	return pnj(Deplacement.IMMOBILE, Sens.VUE, Palier.TRES_LENT)


static func pnj_immobile_voit_lent() -> ProfilBot:
	return pnj(Deplacement.IMMOBILE, Sens.VUE, Palier.LENT)


static func pnj_immobile_entend_lent() -> ProfilBot:
	return pnj(Deplacement.IMMOBILE, Sens.OUIE, Palier.LENT)


static func pnj_immobile_voit_entend_lent() -> ProfilBot:
	return pnj(Deplacement.IMMOBILE, Sens.VUE_ET_OUIE, Palier.LENT)


## Le BOSS de chaque chapitre : le profil d'entraînement NORMAL, rien de plus (« juste un bot en mode moyen », Adrien). Un seul bot.
static func boss() -> ProfilBot:
	return pour_adversaire_qui_tire(Difficulte.NORMAL)
