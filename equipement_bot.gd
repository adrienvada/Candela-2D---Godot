class_name EquipementBot
extends RefCounted

## Ce que le bot FAIT DE SES OUTILS — chantier SOLO, étape S9. Des fonctions pures : une situation décrite en données entre, une décision
## sort. Aucun nœud, aucune physique, aucun appui : `bot_input_provider.gd` lit ces décisions et « appuie sur les touches ».
##
## ## La règle qui prime : s'équiper ne donne AUCUNE information (Adrien, 2026-10-02)
##
## « L'adversaire doit être honnête : ne percevoir que les sons et la lumière. » Un bot qui sait se servir d'une fusée, d'une torche,
## d'un gadget n'en sait pas plus sur l'endroit où l'on se tient : chaque règle ci-dessous ne lit que
##   • sa MÉMOIRE (la dernière place vue, ou la zone entendue — jamais la vraie place de l'adversaire) et son état ;
##   • SON corps : sa place, son cap, sa vie, ses munitions, sa classe ;
##   • sa PROPRE réserve (fusées, gadget : un joueur les lit au HUD) — c'est le seul point où ce fichier va chercher un nœud, et c'est
##     `jeu_du()` : le nœud d'arbitrage de la partie, jamais un joueur ;
##   • la CARTE, que n'importe quel joueur a sous les yeux.
## **Ce fichier ne lit jamais l'autre joueur** : ni son nœud, ni le groupe `players`, ni sa lumière. `tools/test_bot_equipement.gd` le garde
## au texte (le code, commentaires exclus) et au sabotage — un outil à qui l'on donnerait la vraie place du joueur fait rougir la suite.
## Et ce que l'outil fait AU bot, il le lui fait comme à un joueur : une torche qu'il allume le trahit, une fusée qu'il lance l'éclaire
## aussi (c'est pourquoi elle a une distance minimale), un gadget qui bouche la lumière le gêne.
##
## ## Les règles sont des DONNÉES, et chacune dit POURQUOI
##
## `GADGETS` : une ligne par gadget — dans quels états le bot le pose, à quelle distance de la place qu'il vise, avec quelle condition de
## lumière ou de coup reçu, et ce qu'il fait ensuite. Il n'y a pas dix fonctions : il y a une fonction (`gadget_voulu`) et dix lignes, que
## la suite compte contre le catalogue du jeu (`GameState.IMPLEMENTATIONS`) — un onzième gadget sans règle fait rougir.
## Toutes ont le même socle : le bot sait où il pose (96 px devant lui, `GadgetBase.PORTEE_POSE`) et il se tourne donc d'abord vers la
## place qu'il vise ; il ne pose pas « à l'aveugle » (un état de patrouille ne pose jamais rien : il n'a rien perçu).
##
## ## Les chiffres sont des chiffres de DÉPART
##
## Aucun n'a été mesuré sur un joueur. Ils sont posés pour que la règle tienne sur le papier ; le banc de jeu juge ce que l'ensemble fait
## à la force du bot (`tools/banc_bot_difficulte.gd`), et c'est le PROFIL (`ProfilBot`) qu'on règle, pas ces règles.

const Memoire := preload("res://memoire_bot.gd")
const Percep := preload("res://perception_bot.gd")
const Navigation := preload("res://navigation_bot.gd")

## Les états du bot, recopiés de `BotInputProvider.Etat` : ce fichier ne peut pas le charger (le fournisseur le charge, un cycle de
## `preload` ne se compile pas). **Un nombre recopié dérive** : `test_bot_equipement` les compare à l'énumération vivante.
const ETAT_PATROUILLE := 0
const ETAT_ENQUETE := 1
const ETAT_RECHERCHE := 2
const ETAT_COMBAT := 3

## Le facteur de vitesse d'un accroupi (`Player.FACTEUR_VITESSE_ACCROUPI`), recopié — la suite le compare au corps du jeu. Le fournisseur
## en a besoin pour que son anti-blocage ne juge pas « bloqué » un corps qui avance bien à son allure.
const FACTEUR_ACCROUPI := 0.25

## Le nom du groupe du nœud d'arbitrage de la partie (`GameState`) : la réserve de fusées et de gadget du bot s'y lit.
const GROUPE_DU_JEU := "game_state"

# ---------------------------------------------------------------------------
# LA TORCHE
# ---------------------------------------------------------------------------

## La marge, en pixels, qui empêche une torche de clignoter quand le bot hésite sur la limite de fouille : allumée, elle ne s'éteint
## que `HYSTERESIS_TORCHE_PX` plus loin que la distance où elle s'est allumée.
const HYSTERESIS_TORCHE_PX := 60.0


## La torche doit-elle brûler ? Un profil qui ne la dit pas tactique garde sa torche fixe (`torche_allumee`) : exactement le bot d'avant S9.
##
## Tactique : **éteinte tant que le bot n'a rien perçu** (un bot prudent ne se trahit pas pour rien) ; **en enquête et en recherche,
## éteinte pendant qu'il s'approche et allumée quand il est à portée de fouiller** (`torche_rayon_fouille_px` de la place qu'il vise) ;
## **en combat, inchangée** — allumée, elle reste allumée (éteindre en plein tir ferait perdre la cible qu'elle vient de révéler, et le
## bot clignoterait de combat en recherche), éteinte, il ne l'allume pas ; **en repli, toujours éteinte** (il s'éloigne d'un endroit
## que son tir a trahi : une lampe le suivrait).
static func torche_voulue(profil: ProfilBot, etat: int, connue: bool, distance: float, actuelle: bool, en_repli: bool) -> bool:
	if not profil.torche_tactique:
		return profil.torche_allumee
	if en_repli:
		return false
	match etat:
		ETAT_PATROUILLE:
			return profil.torche_en_patrouille
		ETAT_COMBAT:
			return actuelle
		_:
			if not connue or profil.torche_rayon_fouille_px <= 0.0:
				return false
			var limite := profil.torche_rayon_fouille_px + (HYSTERESIS_TORCHE_PX if actuelle else 0.0)
			return distance <= limite


# ---------------------------------------------------------------------------
# LA PRUDENCE : s'accroupir pour approcher un son, changer de place après avoir tiré
# ---------------------------------------------------------------------------

## La marge, en pixels, de l'accroupissement : accroupi, il ne se relève que `HYSTERESIS_ACCROUPI_PX` plus loin.
const HYSTERESIS_ACCROUPI_PX := 40.0


## Le bot doit-il être accroupi ? **En enquête seulement, sur un SON** (la zone qu'il a entendue, et qu'il va voir) et à moins de
## `accroupi_pres_du_son_px` d'elle : le pas accroupi est le plus discret du jeu — c'est la leçon du niveau 0.8 —, au quart de la
## vitesse. Jamais en combat (il se bat debout : l'accroupi vise de plus bas, il n'a pas à se cacher d'un adversaire qu'il voit), jamais
## en patrouille (il n'a rien entendu).
static func accroupi_voulu(profil: ProfilBot, etat: int, source: int, connue: bool, distance: float, actuel: bool) -> bool:
	if profil.accroupi_pres_du_son_px <= 0.0 or etat != ETAT_ENQUETE or not connue or source != Memoire.Source.OUIE:
		return false
	return distance <= profil.accroupi_pres_du_son_px + (HYSTERESIS_ACCROUPI_PX if actuel else 0.0)


## Comment le bot s'éloigne de sa place.
##   • `LATERAL` : de côté, hors de l'axe du tir qu'on vient de lui rendre (au moins `ANGLE_REPLI_LATERAL_DEG` de l'axe vers la place
##     qu'il vise) — après une rafale, c'est ce que le niveau 0.7 enseigne ;
##   • `RECUL` : en arrière, le dos à ce qu'il vise (au moins `ANGLE_REPLI_RECUL_DEG` de l'axe) — après avoir posé une mine, qui
##     aveugle jusqu'à 460 px ;
##   • `VERS` : vers un point donné — le nuage de suie qu'il vient de poser, où il va se cacher.
enum Repli { LATERAL, RECUL, VERS }

const ANGLE_REPLI_LATERAL_DEG := 60.0
const ANGLE_REPLI_RECUL_DEG := 140.0
## La distance d'un repli, en pixels : de 3 à 7 cases de côté (assez pour sortir de l'axe, pas assez pour quitter la salle) ; le recul va
## plus loin, 5 à 10 cases.
const DISTANCE_REPLI_LATERAL := Vector2(105.0, 260.0)
const DISTANCE_REPLI_RECUL := Vector2(175.0, 350.0)
## Combien de cases au plus le chemin d'un repli compte : une case « cachée » de l'autre côté d'un mur n'est pas un repli, c'est un voyage.
const ETAPES_REPLI_MAX := 14
## Combien de cases candidates on essaie avant de renoncer.
const ESSAIS_REPLI := 8


## La case où le bot s'éloigne, ou `(-1, -1)` s'il n'y en a pas. `menace` : la place qu'il vise — SA MÉMOIRE, jamais la vraie place de
## l'adversaire. Parmi les cases qui respectent l'angle et la distance du mode, il préfère celles qu'un tireur posé en `menace` ne voit
## pas à travers un mur (la carte est lue comme un joueur la lit : `Percep.segment_degage`) ; `rng` départage, et c'est le seul tirage.
static func case_de_repli(navigation: NavigationBot, monde: Dictionary, position: Vector2, menace: Vector2, mode: int,
		rng: RandomNumberGenerator) -> Vector2i:
	var ici := Navigation.case_du_monde(position)
	var axe := menace - position
	axe = axe.normalized() if axe.length() > 1.0 else Vector2.RIGHT
	var fenetre := DISTANCE_REPLI_RECUL if mode == Repli.RECUL else DISTANCE_REPLI_LATERAL
	var angle_min := deg_to_rad(ANGLE_REPLI_RECUL_DEG if mode == Repli.RECUL else ANGLE_REPLI_LATERAL_DEG)
	var cachees: Array[Vector2i] = []
	var ouvertes: Array[Vector2i] = []
	for c in navigation.cases_atteignables(ici):
		var centre := Navigation.centre_de_la_case(c)
		var vers := centre - position
		var d := vers.length()
		if d < fenetre.x or d > fenetre.y:
			continue
		if absf(axe.angle_to(vers)) < angle_min:
			continue
		if Percep.segment_degage(menace, centre, monde):
			ouvertes.append(c)
		else:
			cachees.append(c)
	for groupe in [cachees, ouvertes]:
		var g: Array[Vector2i] = groupe
		for _essai in mini(ESSAIS_REPLI, g.size()):
			var c: Vector2i = g[rng.randi_range(0, g.size() - 1)]
			if navigation.chemin(ici, c).size() <= ETAPES_REPLI_MAX:
				return c
	return Vector2i(-1, -1)


# ---------------------------------------------------------------------------
# LA FUSÉE
# ---------------------------------------------------------------------------

## La distance minimale de la place visée, en pixels. Une fusée éclaire son lanceur aussi (`GameState._sources_eblouissantes` : « on ne la
## lance pas à ses pieds impunément ») : elle s'allume à ~450 px (`FuseeModele` : 900 px/s, 900 px/s² de frottement, v²/2f), et son halo
## d'allumage porte 468 px. Lancée de plus près, le bot se trahirait et se serait aveuglé pour éclairer un endroit qu'il touche presque.
const FUSEE_DISTANCE_MIN := 240.0
## La distance maximale : au-delà de la portée libre du vol (~450 px, plus un rebond), la fusée s'allume plus près du bot que de sa cible.
const FUSEE_DISTANCE_MAX := 470.0
## Le plus gros rayon de zone qu'une fusée vaut : le halo d'allumage couvre ~468 px autour de son point d'arrivée ; une zone plus
## vaste que lui ne serait éclairée qu'en partie, et le bot se serait trahi pour une chance sur deux.
const FUSEE_RAYON_ZONE_MAX := 320.0
## De combien le corps peut s'écarter de la direction de la zone au moment du lancer, en degrés : la fusée part droit devant lui.
const FUSEE_ANGLE_MAX_DEG := 10.0
## La confiance minimale dans ce que le bot a entendu : une trace presque oubliée ne vaut pas une fusée.
const FUSEE_CONFIANCE_MIN := 0.25


## Le bot lance-t-il une fusée ? **Vers une zone qu'il a ENTENDUE sans la voir** — jamais vers une cible qu'il voit (la fusée sert à voir
## ce qu'on n'a fait qu'entendre, et chaque fusée de trop est un éclat qui le trahit) : en enquête, sur une trace d'OUÏE assez nette
## (`FUSEE_RAYON_ZONE_MAX`), assez récente, ni trop près ni trop loin (`FUSEE_DISTANCE_*`), le corps tourné vers elle, un chemin DÉGAGÉ
## de murs jusqu'à elle (sinon la fusée rebondit et s'allume ailleurs), et une fusée en réserve et les mains libres.
##
## `situation` : `profil`, `etat`, `source`, `connue`, `distance`, `rayon`, `confiance`, `ecart_deg` (entre son cap et la direction de la
## zone), `vu` (la cible est vue à cet instant), `libre` (la ligne vers la zone est dégagée), `fusee_disponible`, `mains_libres`.
static func fusee_voulue(s: Dictionary) -> bool:
	var profil: ProfilBot = s["profil"]
	if not profil.lance_des_fusees or not bool(s.get("fusee_disponible", false)) or not bool(s.get("mains_libres", false)):
		return false
	if int(s["etat"]) != ETAT_ENQUETE or not bool(s["connue"]) or int(s["source"]) != Memoire.Source.OUIE or bool(s.get("vu", false)):
		return false
	var d := float(s["distance"])
	if d < FUSEE_DISTANCE_MIN or d > FUSEE_DISTANCE_MAX:
		return false
	if float(s["rayon"]) > FUSEE_RAYON_ZONE_MAX or float(s["confiance"]) < FUSEE_CONFIANCE_MIN:
		return false
	return bool(s.get("libre", false)) and float(s["ecart_deg"]) <= FUSEE_ANGLE_MAX_DEG


# ---------------------------------------------------------------------------
# LE GADGET DE LA CLASSE : dix gadgets, dix lignes
# ---------------------------------------------------------------------------

## Le bot sait où son gadget se plante : à `GadgetBase.PORTEE_POSE` (96 px) devant lui, ramené en deçà du premier mur. Il doit donc faire
## face à la place qu'il vise (`angle`), et il lui faut un chemin dégagé jusqu'à elle (`libre`) — pas de gadget planté dans une paroi.
const ANGLE_POSE_DEG := 25.0
## La durée pendant laquelle un coup reçu compte pour « je viens d'être touché », en secondes.
const FENETRE_TOUCHE_S := 2.0
## Combien de temps après la fin d'une rafale on pose un gadget « d'après tir », en secondes : c'est un instant, pas une période.
const FENETRE_RAFALE_S := 0.8
## Combien de temps le bot s'éloigne après avoir posé une mine, et combien de temps il reste dans son nuage de suie, en secondes.
const DUREE_RECUL_MINE_S := 2.5
const DUREE_DANS_LE_NUAGE_S := 4.0

## Ce que le bot fait APRÈS avoir posé : rien, reculer (la mine aveugle à 460 px, poseur compris), ou se mettre dedans (la suie ne cache que
## ceux qui s'y tiennent).
const PUIS_RIEN := ""
const PUIS_RECUL := "recul"
const PUIS_DEDANS := "dedans"

## Les règles. Clés : `etats` (les états où il le pose), `distance` (de la place qu'il vise : `[min, max]`, en pixels), `vu` (`1` : la
## cible doit être vue à cet instant ; `0` : elle ne doit PAS l'être ; `-1` : indifférent), `lampe` (la torche de la cible doit être
## VUE : « la torche trahit », et c'est ce que la règle exploite), `touche` (il vient d'être touché), `apres_rafale` (il vient de finir
## une rafale), `puis` (ce qu'il fait ensuite), `pourquoi` (la raison de la règle — elle se lit à `--regles`, et la suite exige qu'elle existe).
##
## ⚠️ **Aucune règle ne se prétend optimale** : chacune est la plus simple qui ne fasse pas de mal. Si un gadget était trop complexe pour une
## règle sûre, la règle serait « ne pas le poser » — aucun ne l'est, mais le grésillement (un interrupteur) a sa règle d'allumage à part,
## `bobine_voulue`, et deux gadgets (suie, mine) demandent un geste de plus après la pose (`puis`).
const GADGETS := {
	# Le Parasite. La bobine fait sauter les LAMPES dans 240 px : elle ne sert que face à une torche. Posée vers la place qu'il vise, à
	# portée de tir ; allumée par `bobine_voulue` quand la torche de la cible est vue.
	"gresillement": {"etats": [ETAT_ENQUETE, ETAT_RECHERCHE, ETAT_COMBAT], "distance": [150.0, 420.0], "vu": -1, "lampe": false,
		"touche": false, "apres_rafale": false, "puis": PUIS_RIEN,
		"pourquoi": "la bobine éteint les lampes dans 240 px : on la pose entre soi et la place visée, à portée de tir, et on l'allume quand la torche de la cible est vue"},
	# L'Illusionniste. Le leurre est un corps de plus dans la lumière : il se pose AU MOMENT où l'adversaire a de quoi viser — juste après
	# une rafale, quand le bot va changer de place — pour que le prochain coup parte sur lui.
	"leurre": {"etats": [ETAT_COMBAT], "distance": [160.0, 600.0], "vu": 1, "lampe": false,
		"touche": false, "apres_rafale": true, "puis": PUIS_RIEN,
		"pourquoi": "l'adversaire vient de tirer sur sa place ou sait où elle est : le faux corps, 96 px devant, prend le coup suivant pendant que le bot change de place"},
	# Le Terrassier. Un nuage où l'on ne voit pas loin, sur le chemin de la zone entendue : celui qui s'y engage perd sa portée, le Terrassier
	# a le faisceau le plus large du jeu. Posé quand il n'a RIEN vu (en combat, il boucherait sa propre vue).
	"poussiere": {"etats": [ETAT_ENQUETE, ETAT_RECHERCHE], "distance": [200.0, 380.0], "vu": 0, "lampe": false,
		"touche": false, "apres_rafale": false, "puis": PUIS_RIEN,
		"pourquoi": "sur la route de la zone entendue : qui s'y engage ne voit plus loin ; jamais en combat, le nuage boucherait aussi sa vue"},
	# Le Braconnier. La lampe sur trépied balaie comme un joueur qui cherche : l'adversaire qui la voit y court, ou s'y aveugle. Posée vers une
	# zone entendue et assez loin pour qu'elle ne soit pas à ses pieds : le bot reste dans le noir pendant que l'appât brûle.
	"torche_fantome": {"etats": [ETAT_ENQUETE], "distance": [250.0, 450.0], "vu": 0, "lampe": false,
		"touche": false, "apres_rafale": false, "puis": PUIS_RIEN,
		"pourquoi": "un appât : une lampe qui balaie vers la zone entendue, à distance, pendant que le bot reste dans le noir"},
	# Le Fumiste. La suie ne cache que ceux qui sont DEDANS : il la pose quand il vient d'être touché, tourné vers le tireur, et il se met
	# dedans (`PUIS_DEDANS`). Le tireur voit qu'il y a quelqu'un, plus qui ni où il vise.
	"cartouche_suie": {"etats": [ETAT_COMBAT], "distance": [120.0, 400.0], "vu": 1, "lampe": false,
		"touche": true, "apres_rafale": false, "puis": PUIS_DEDANS,
		"pourquoi": "il vient d'être touché : le nuage, 96 px devant, cache ceux qui s'y tiennent — il s'y met"},
	# L'Incendiaire. La nappe brûle qui s'y attarde : posée en combat, entre lui et la cible vue, elle ferme le chemin droit. Il n'en
	# évite pas la sienne ensuite (signalé) : huit points la traversent.
	"nappe_braises": {"etats": [ETAT_COMBAT], "distance": [150.0, 420.0], "vu": 1, "lampe": false,
		"touche": false, "apres_rafale": false, "puis": PUIS_RIEN,
		"pourquoi": "entre lui et la cible vue : un sol qu'on ne traverse plus, posé là où il tient sa place"},
	# La Sentinelle. Elle veille : la poudre écrit les pas de qui passe. Posée sur le chemin d'une zone entendue, puis il y va ; le bot ne
	# lit pas les traces (le modèle de vue ne les connaît pas : voir moins que la lumière), l'adversaire, lui, y voit ses pas luire.
	"poudre_contact": {"etats": [ETAT_ENQUETE], "distance": [200.0, 450.0], "vu": 0, "lampe": false,
		"touche": false, "apres_rafale": false, "puis": PUIS_RIEN,
		"pourquoi": "sur le chemin d'une zone entendue : chaque pas qui la traverse luit ensuite — la Sentinelle veille"},
	# L'Occulteur. La plaque d'acier arrête la lumière et en rend une ombre d'homme : elle se pose face à une torche VUE, entre la lampe et
	# lui — l'adversaire éclaire une plaque, et lit une ombre qui ment.
	"ombre_habitee": {"etats": [ETAT_ENQUETE, ETAT_RECHERCHE, ETAT_COMBAT], "distance": [150.0, 450.0], "vu": -1, "lampe": true,
		"touche": false, "apres_rafale": false, "puis": PUIS_RIEN,
		"pourquoi": "face à une torche qu'il voit : la plaque coupe le faisceau et projette l'ombre d'un homme absent"},
	# L'Allumeur. La mine aveugle et révèle dans 460 px, POSEUR COMPRIS : il la pose vers une zone entendue puis RECULE (`PUIS_RECUL`),
	# pour ne pas se trouver dans le flash que son adversaire déclenchera.
	"mine_magnesium": {"etats": [ETAT_ENQUETE, ETAT_RECHERCHE], "distance": [250.0, 450.0], "vu": 0, "lampe": false,
		"touche": false, "apres_rafale": false, "puis": PUIS_RECUL,
		"pourquoi": "sur la route d'une zone entendue, puis il recule : le flash aveugle dans 460 px, poseur compris"},
	# Le Spectre. La bâche arrête la lumière et les joueurs, pas les balles : posée face à une torche VUE, elle casse le faisceau qui le
	# cherche — même geste que l'ombre, une autre idée. Il n'éclaire jamais : sa bâche est sa seule façon de se protéger de la lumière.
	"voile": {"etats": [ETAT_RECHERCHE, ETAT_COMBAT], "distance": [150.0, 400.0], "vu": -1, "lampe": true,
		"touche": false, "apres_rafale": false, "puis": PUIS_RIEN,
		"pourquoi": "face à une torche qu'il voit : la bâche coupe le faisceau qui le cherche — les balles, elles, la traversent"},
}


## Le bot pose-t-il le gadget `slug` ? `situation` : `etat`, `connue`, `distance`, `ecart_deg`, `libre`, `vu`, `lampe_vue` (la torche de
## la cible est vue), `touche_depuis` (secondes depuis le dernier coup reçu, `INF` : jamais), `rafale_depuis` (secondes depuis la fin de la
## dernière rafale, `INF` : jamais), `gadget_disponible` (la réserve, recharge d'une minute comprise), `mains_libres`.
##
## ⚠️ Un slug sans règle ne pose rien — et ne crie pas ici : la suite compare les clés au catalogue du jeu.
static func gadget_voulu(slug: String, s: Dictionary) -> bool:
	if not GADGETS.has(slug) or not bool(s.get("gadget_disponible", false)) or not bool(s.get("mains_libres", false)):
		return false
	var r: Dictionary = GADGETS[slug]
	if not bool(s["connue"]) or not (int(s["etat"]) in (r["etats"] as Array)):
		return false
	var d := float(s["distance"])
	var fenetre: Array = r["distance"]
	if d < float(fenetre[0]) or d > float(fenetre[1]):
		return false
	if float(s["ecart_deg"]) > ANGLE_POSE_DEG or not bool(s.get("libre", false)):
		return false
	match int(r["vu"]):
		1:
			if not bool(s.get("vu", false)):
				return false
		0:
			if bool(s.get("vu", false)):
				return false
	if bool(r["lampe"]) and not bool(s.get("lampe_vue", false)):
		return false
	if bool(r["touche"]) and float(s.get("touche_depuis", INF)) > FENETRE_TOUCHE_S:
		return false
	if bool(r["apres_rafale"]) and float(s.get("rafale_depuis", INF)) > FENETRE_RAFALE_S:
		return false
	return true


## Ce que le bot fait après avoir posé `slug` : `PUIS_RIEN`, `PUIS_RECUL` ou `PUIS_DEDANS`.
static func puis_de(slug: String) -> String:
	return String((GADGETS[slug] as Dictionary)["puis"]) if GADGETS.has(slug) else PUIS_RIEN


## Le grésillement est un INTERRUPTEUR : une fois la bobine posée, la même touche l'allume et l'éteint (`GameState.basculer_gadget`). Elle
## doit-elle brûler ? Oui quand la TORCHE de la cible est vue et que la place qu'il vise est à moins de 330 px de lui — la bobine est à
## 96 px devant lui, et son rayon d'action de 240 px recouvre alors la place visée ; non quand il n'a plus rien perçu (la batterie est une
## réserve de 14 s : on ne la brûle pas pour rien) ou qu'il en est loin.
##
## ⚠️ **Sa propre torche en pâtit** (« le Parasite qui traverse sa propre zone y perd sa lampe ») : un profil à torche tactique qui fouille
## à 300 px de la zone la rallume dans la zone de sa propre bobine. C'est une règle de joueur : il n'y a pas de parade, et le banc dit ce
## que ça coûte.
static func bobine_voulue(etat: int, connue: bool, distance: float, lampe_vue: bool, actuelle: bool) -> bool:
	if etat == ETAT_PATROUILLE or not connue:
		return false
	if lampe_vue and distance <= 330.0:
		return true
	# Déjà allumée : on ne la coupe que quand rien ne la justifie plus (perdue de vue depuis longtemps, ou loin), pas à chaque clignement
	# d'une lampe.
	return actuelle and distance <= 330.0 and etat == ETAT_COMBAT


# ---------------------------------------------------------------------------
# CE QUE LE BOT LIT DE SON PROPRE ÉQUIPEMENT
# ---------------------------------------------------------------------------

## Le nœud d'arbitrage de la partie (`GameState`), ou `null` : un corps factice, une suite sans scène, un nœud qui n'a pas la méthode.
## C'est le SEUL nœud que ce fichier va chercher, et il n'a pas de joueur : la réserve de fusées et de gadget est ce qu'un joueur lit à son
## HUD. Le groupe est nommé ici et nulle part dans `bot_input_provider.gd`, dont le texte ne doit contenir aucune recherche de nœud.
static func jeu_du(corps: Node) -> Node:
	if corps == null or not corps.is_inside_tree():
		return null
	var jeu := corps.get_tree().get_first_node_in_group(GROUPE_DU_JEU)
	return jeu if jeu != null and jeu.has_method("gadget_disponible") and jeu.has_method("fusee_disponible") else null


## Le slug du gadget de la classe que porte ce corps, ou `""` (une arme sans classe, une classe sans gadget livré).
static func slug_du_gadget(corps: Node) -> String:
	var arme: Variant = corps.get("current_weapon")
	if arme == null:
		return ""
	var g: Variant = (arme as Object).get("gadget")
	if g == null:
		return ""
	if g.has_method("est_livre") and not bool(g.call("est_livre")):
		return ""
	return String((g as Object).get("slug"))
