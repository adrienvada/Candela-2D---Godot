extends Node

# Cartographie des sons vers leurs chemins d'accès
const SOUNDS: Dictionary = {
	"shoot": "res://assets/audio/sfx/weapon_shoot.wav",
	"footstep": "res://assets/audio/sfx/footstep.wav",
	"wall_impact": "res://assets/audio/sfx/wall_impact.wav",
	"flesh_impact": "res://assets/audio/sfx/flesh_impact.wav",
	"button_click": "res://assets/audio/sfx/button_click.wav",
	"music_menu": "res://assets/audio/music/music_menu.ogg",
	"music_match": "res://assets/audio/music/music_match.ogg",
	"music_victory": "res://assets/audio/music/music_victory.ogg",
	"music_interactive": "res://assets/audio/music/main_stream_interactive.tres",
	# V1.3 — les voix d'annonceur. **Elles vivent dans `voice/`, pas dans
	# `speaker/`** : ces chemins pointaient vers un dossier qui n'a jamais
	# existe, et `get_audio_stream` rendait donc `null` en silence depuis des
	# mois. Le bus, lui, s'appelle toujours `Speaker` — c'est une sortie, pas un
	# dossier.
	"spk_fight": "res://assets/audio/voice/spk_fight.wav",
	"spk_draw": "res://assets/audio/voice/spk_draw.wav",
	# Ces deux-la ne servent QU'EN ECRAN SCINDE : la ou deux joueurs partagent
	# les memes haut-parleurs, l'annonceur doit dire LEQUEL a gagne. Partout
	# ailleurs il s'adresse a quelqu'un, et « tu as gagne » vaut mieux que
	# « le joueur 1 a gagne ». Decision d'Adrien, 2026-08-25.
	"spk_p1_wins": "res://assets/audio/voice/spk_p1_wins.wav",
	"spk_p2_wins": "res://assets/audio/voice/spk_p2_wins.wav",
	# Et ceux-ci ne servent QUE HORS ecran scindé, pour la meme raison.
	"win": "res://assets/audio/voice/win.wav",
	"defeat": "res://assets/audio/voice/defeat.wav",
	"spk_perfect": "res://assets/audio/voice/spk_perfect.wav",
	"spk_close_call": "res://assets/audio/voice/spk_close_call.wav",
	# Déjà attendu par le manifeste (V3.2) : `play_sfx` rend null sur une
	# ressource absente, la clé se câble donc avant le fichier et reste muette
	# sans erreur — plutôt qu'un bouche-trou qu'on finirait par prendre pour une
	# intention.
	"ui_ready_ping": "res://assets/audio/sfx/ui_ready_ping.wav",
	# V5.1 — le claquement de torche, LE son entendu cinq cents fois par soirée.
	# Câblés, muets tant que les fichiers manquent (règle « câbler, taire,
	# diagnostiquer ») ; entrées à ajouter au manifeste (domaine « menus »).
	"torch_on": "res://assets/audio/sfx/torch_on.wav",
	"torch_off": "res://assets/audio/sfx/torch_off.wav",
	# V5.3 — l'acouphène d'éblouissement, boucle dont le volume suit dazzle_amount.
	"dazzle_ringing": "res://assets/audio/sfx/tinnitus_dazzle.wav",
	# V2.3 / V3.7 / V3.8 — les ponctuations de fin de manche. La regle qui decide
	# laquelle sort est `stinger_de_fin`, plus bas.
	#
	# Elles passent par le bus SFX et non par le bus musical, ce qui est
	# contre-intuitif pour de la musique. La raison est le filtre passe-bas de la
	# torche : dans le noir, le bus musical est coupe vers 300 Hz pour que la
	# musique recule. Une ponctuation de kill y passerait comme un coup sourd, au
	# moment precis ou elle doit trancher. **Le sting n'est pas de l'ambiance,
	# c'est un evenement** : il doit survivre au filtre qui fait reculer l'ambiance.
	"sting_kill": "res://assets/audio/music/sting_kill.ogg",
	"sting_kill_match": "res://assets/audio/music/sting_kill_match.ogg",
	"sting_defeat": "res://assets/audio/music/sting_defeat.ogg",
	"sting_draw": "res://assets/audio/music/sting_draw.ogg",
}

## Quelle ponctuation clot cette manche, vue depuis CETTE machine ?
##
## Pure a dessein, comme `torche_comptee` : la regle se verifie sans serveur
## audio, et c'est la seule facon de tester une decision qui depend de qui l'on
## est. Une ponctuation qui se trompe de camp ne leve aucune erreur — elle
## felicite le perdant, et on ne s'en apercoit qu'en jouant, une fois.
##
## - **Egalite** : le match s'acheve au temps, tout le monde entend la meme chose.
## - **Kill sans fin de match** : les DEUX joueurs l'entendent (decision d'Adrien,
##   2026-08-25). Un kill est un fait, pas une bonne nouvelle reservee a celui qui
##   l'obtient.
## - **Kill decisif** : le vainqueur entend le kill de match, le vaincu sa
##   defaite. **En ecran partage, personne n'est « le » vaincu a la sortie
##   audio** — les deux joueurs partagent les memes haut-parleurs, exactement
##   comme pour `torche_comptee`. On y garde donc le kill decisif, qui decrit
##   l'evenement sans designer un camp.
##
## ⚠️ Au format BO1 (le defaut), un kill met FIN au match : `sting_kill` ne sort
## donc jamais dans ce format-la. Il attend un format plus long. Ce n'est pas un
## defaut, mais c'est le genre de silence qu'on prend pour une panne.
static func stinger_de_fin(winner_id: int, match_over: bool, local_idx: int) -> String:
	if winner_id < 0:
		return "sting_draw" if match_over else ""
	if not match_over:
		return "sting_kill"
	if local_idx >= 0 and winner_id != local_idx:
		return "sting_defeat"
	return "sting_kill_match"

## L'oreille suit-elle un joueur, dans ce mode ?
##
## **La question n'est pas « suis-je en ligne », c'est « y a-t-il exactement une
## oreille devant l'ecran ».** Ce qui exclut l'ecran partage n'est pas d'etre en
## local : c'est que **deux joueurs y ecoutent les memes haut-parleurs**. Poser
## l'oreille sur l'un donnerait a l'autre la distance et la direction de ses
## propres pas, entendus depuis une tete qui n'est pas la sienne — pire que le
## point fixe, pas mieux.
##
## L'entrainement est local ET solitaire : une vue, un joueur, une sortie. La
## premiere version de cette regle interrogeait le transport, et l'excluait donc
## avec l'ecran partage — alors qu'il est le SEUL MODE SOLO du jeu, celui ou l'on
## peut juger un dosage sans monter deux instances.
##
## ⚠️ **Deuxieme fois que ce piege se paie sur l'entrainement.** La feuille de
## route porte deja « Le regard suit le joueur, pas le score » : le suivi de
## camera vivait dans `if round_active:`, l'entrainement desarme la manche, la
## camera ne suivait donc jamais. Meme faute, meme mode — l'entrainement est le
## seul endroit ou le jeu separe des concepts que le code confond.
static func oreille_suit(local_idx: int, entrainement: bool = false) -> bool:
	return local_idx >= 0 or entrainement

## Qui porte l'oreille, sachant l'index du joueur local.
##
## Ecrite positivement plutot qu'en `== 0 else p2` : hors ligne l'index vaut
## **-1**, et la forme naive designait alors J2 — en entrainement, un joueur
## cache et immobile. L'oreille se serait posee sur un fantome et le symptome
## aurait ete « le panoramique ne bouge pas », c'est-a-dire le defaut d'avant
## sous un correctif qui a l'air pose.
static func index_porteur(local_idx: int) -> int:
	return 1 if local_idx == 1 else 0

## La sortie audio est-elle PARTAGEE entre deux joueurs ?
##
## **Predicat canonique, et il ne sert pas qu'aux oreilles.** Toute regle qui
## depend de « y a-t-il une ou deux personnes devant cette sortie » se branche
## ici : les deux oreilles de l'ecran partage, mais aussi la voix d'annonceur —
## `spk_p1_wins` en ecran scinde contre `win`/`defeat` ailleurs — et demain tout
## ce qui devra decrire un evenement sans designer un camp.
##
## **Ne pas en ecrire une seconde.** Deux predicats paralleles repondent pareil
## jusqu'au jour ou quelqu'un en corrige un seul ; ce jour-la, une moitie du jeu
## croit qu'il y a deux joueurs pendant que l'autre croit qu'il y en a un. La
## question s'ecrit UNE fois et se lit partout — c'est la lecon de
## `oreille_suit`, qui interrogeait le transport quand il fallait compter les
## auditeurs, et qui a coute l'entrainement muet.
##
## Ecoute-t-on par DEUX oreilles, une par joueur ? (Decision d'Adrien, 2026-08-25.)
##
## Les trois cas sont exhaustifs et complementaires — en ligne et a l'entrainement
## il n'y a qu'un auditeur devant l'ecran, donc une oreille ; en ecran partage ils
## sont deux, donc deux. **Ecrite comme la negation exacte d'`oreille_suit` plutot
## que comme une seconde regle** : deux regles independantes finiraient par se
## contredire sur un cas que personne n'a prevu, et le jeu se retrouverait avec
## zero oreille ou trois.
static func ecoute_somme(local_idx: int, entrainement: bool = false) -> bool:
	return not oreille_suit(local_idx, entrainement)

## Points de vie au depart, et seuil du « de justesse ». Nommes ici parce que
## `voix_de_fin` les compare : un seuil ecrit en dur dans une comparaison est un
## seuil que personne ne retrouve le jour ou il faut le bouger.
const PV_MAX: float = 100.0
const PV_DE_JUSTESSE: float = 10.0

## Que dit l'annonceur a la fin du match, vu depuis CETTE machine ? (V1.3)
##
## La regle d'Adrien (2026-08-25) tient en une phrase : **en ecran scindé
## l'annonceur nomme le vainqueur, partout ailleurs il s'adresse a celui qui
## ecoute.** « Le joueur 1 a gagne » n'a de sens que quand deux joueurs se
## partagent les memes haut-parleurs et qu'il faut lever l'ambiguite ; devant un
## seul auditeur, c'est une periphrase pour « tu as gagne ».
##
## **Derivee d'`ecoute_somme`, pas ecrite a cote.** C'est exactement la meme
## question que l'oreille — combien d'auditeurs devant l'ecran — et cette
## question s'est deja trompee une fois en interrogeant le transport au lieu du
## nombre d'oreilles (voir `oreille_suit` et l'entrainement). Deux regles
## paralleles finiraient par diverger le jour ou l'on n'en corrige qu'une, et le
## jeu annoncerait « joueur 2 » a quelqu'un qui joue seul.
##
## `pv_vainqueur` sert les deux variantes, et elles s'excluent : intact, c'est un
## sans-faute ; sous le seuil, c'est passe de peu. Un match gagne a 100 PV ne
## peut pas etre « de justesse », l'ordre des tests le dit sans commentaire.
static func voix_de_fin(winner_id: int, local_idx: int, entrainement: bool,
		pv_vainqueur: float) -> String:
	if winner_id < 0:
		return "spk_draw"
	if ecoute_somme(local_idx, entrainement):
		return "spk_p1_wins" if winner_id == 0 else "spk_p2_wins"
	if local_idx >= 0 and winner_id != local_idx:
		return "defeat"
	if pv_vainqueur >= PV_MAX:
		return "spk_perfect"
	if pv_vainqueur <= PV_DE_JUSTESSE:
		return "spk_close_call"
	return "win"

## Le tempo du jeu, en un seul endroit.
##
## Les stems, le pouls haptique et la vignette battante battent tous à 170 —
## mais chacun le réécrivait chez lui (`player.gd` porte encore ses propres 170
## et 85). Un tempo recopié est un tempo qui dérive : le jour où il change, ce
## qui bat encore à l'ancien ne se signale pas, il se contente d'être à côté.
const BPM: float = 170.0
const PERIODE_BEAT: float = 60.0 / BPM

## Les sons de tir, quatre variantes par arme : `weapon_<slug>_01..04.wav`.
##
## Le tirage au sort remplace ce que le pitch aléatoire faisait seul jusqu'ici.
## Un même échantillon repitché reste le même échantillon — l'oreille l'entend
## en une poignée de coups, et le tir est de loin le son le plus répété du jeu.
const DIR_ARMES := "res://assets/audio/weapons/"
## Prefixe commun aux sons d'armes. Sert a RECONNAITRE, `chemin_tir` a CONSTRUIRE.
const PREFIXE_TIR := "weapon_"
const VARIANTES_TIR := 4

## Le percuteur a vide, un par arme (V4.4).
##
## ⚠️ **Ces fichiers vivent dans `DIR_ARMES`, comme les tirs — et c'est un piege.**
## `est_un_tir()` reconnait un coup de feu a ce prefixe : sans l'exclusion
## explicite qu'elle porte, un clic a vide aurait pris la priorite d'un tir dans
## le pool ET fait reculer les pas de six decibels (V4.15). Un joueur qui
## martele une detente vide aurait efface les pas de son adversaire — soit
## exactement l'inverse de ce que le son a vide raconte, qui est « je suis
## desarme ».
const PREFIXE_PERCUTEUR := "weapon_dry_"

static func chemin_percuteur(slug: String) -> String:
	return "%s%s%s.wav" % [DIR_ARMES, PREFIXE_PERCUTEUR, slug]

## Le chemin d'une variante. Pure à dessein : vérifiable sans serveur audio.
static func chemin_tir(slug: String, variante: int) -> String:
	return "%sweapon_%s_%02d.wav" % [DIR_ARMES, slug, variante]

## Ce son est-il un coup de feu ?
##
## V4.15 en dépend — les pas reculent de six décibels juste après un tir. La
## question se réglait avant en comparant à la clé `"shoot"`, seule façon de
## tirer à l'époque. Depuis que chaque arme a ses variantes, **un tir arrive
## aussi sous la forme d'un CHEMIN**, et la comparaison à `"shoot"` répondait
## alors « non » : les pas seraient restés au premier plan pendant les
## fusillades, sans qu'aucune erreur ne le dise.
## Ce son est-il un coup de feu ?
##
## ⚠️ **Cette fonction classait par DOSSIER, et ça a coûté un défaut réel.**
## Elle répondait vrai pour tout chemin commençant par `DIR_ARMES`. Écrit pour
## V4.1, quand ce dossier ne contenait que les seize prises de tir, c'était
## exact — puis le percuteur à vide y a été livré, **et un clic à vide s'est mis
## à faire reculer les pas de l'adversaire de six décibels** (V4.15), l'inverse
## exact de ce que ce son raconte. La session DA3 l'a colmaté par une exclusion ;
## le fond restait : **le prochain fichier déposé là redevenait un tir.**
##
## Elle classe désormais par **ce que le nom du fichier EST**, et précisément par
## ce que `chemin_tir()` fabrique — `weapon_<arme>_NN.wav`. Les deux fonctions se
## répondent : l'une construit, l'autre reconnaît, et un son qui n'a pas été
## construit par la première n'est pas reconnu par la seconde. **Déposer un
## fichier dans un dossier n'est plus une décision de gameplay.**
##
## La clé `"shoot"` reste vraie : c'est le son générique d'avant V4.1, encore
## joué en repli quand les variantes d'une arme manquent.
static func est_un_tir(stream_or_key: Variant) -> bool:
	if not (stream_or_key is String):
		return false
	var s: String = stream_or_key
	if s == "shoot":
		return true
	if est_un_percuteur(s):
		return false
	var nom := s.get_file().get_basename()
	if not nom.begins_with(PREFIXE_TIR):
		return false
	# `weapon_pistolet_03` — le suffixe est un numero de variante a deux chiffres,
	# precede d'un souligne. C'est ce que `chemin_tir` ecrit, et rien d'autre.
	var coupe := nom.rsplit("_", true, 1)
	return coupe.size() == 2 and coupe[1].length() == 2 and coupe[1].is_valid_int()

## Ce son est-il un percuteur a vide ?
##
## Nomme plutot que teste au prefixe sur place : la question se pose a QUATRE
## endroits — le duck des pas, la priorite, la portee et le niveau — et un
## prefixe recopie quatre fois est un prefixe qui n'en corrige que trois le jour
## ou il change.
static func est_un_percuteur(stream_or_key: Variant) -> bool:
	if not (stream_or_key is String):
		return false
	return String(stream_or_key).get_file().begins_with(PREFIXE_PERCUTEUR)

## ============================================================================
## S2 — LA DISTANCE REDEVIENT UNE INFORMATION
## ============================================================================
##
## `max_distance` valait **2000 px pour toutes les voix**, sur une carte qui en
## fait 700 a 840. Meme l'oreille bien posee, « colle a moi » et « a l'autre
## bout » n'etaient separes que d'environ **3,7 dB** : ce n'est pas une distance,
## c'est une nuance de mixage. Et un chiffre rond ecrit en dur redevient faux a
## la premiere carte d'une autre taille — la portee se **derive de la carte**,
## comme V5.12 derive sa reverb de `grid_size`.
##
## ✅ **DOSE PAR ADRIEN AU BANC LE 2026-08-25** — facteur de portee **1,80** et
## courbe **0,40**. Ces deux-la ne sont plus des propositions : elles ont ete
## jugees a l'oreille, et la courbe a ete deplacee de 2,0 a 0,4, soit dans le
## sens **oppose** a ce que le raisonnement recommandait (voir
## `COURBE_DISTANCE_DEFAUT`).
##
## ⚠️ **Les portees RELATIVES d'un son a l'autre, elles, restent des
## propositions** : le banc ne joue qu'un son a la fois, donc leur rapport n'a
## pas ete compare. Ce qui a ete juge, c'est l'echelle d'ensemble.

## Portee de chaque son, en fraction de la diagonale de la carte.
##
## **Tous les sons ne portent pas pareil, et c'est une information de jeu.** Un
## coup de feu s'entend d'un bout a l'autre de l'arene — le taire au loin
## retirerait le renseignement le plus cher du jeu apres la lumiere. Un pas est
## un indice de PROXIMITE : l'entendre a travers toute la carte le rendrait
## bavard sans rien apprendre, puisqu'on ne saurait pas s'il est pres.
##
## Meme logique de classement que `SFX_PRIORITE`, et ce n'est pas un hasard :
## les deux tables disent ce que le son APPREND, l'une en voix, l'autre en
## pixels.
## ✅ **Rapports triples le 2026-08-25 a la demande d'Adrien, apres ecoute.**
## Le rapport tir/pas passe de **3,6 a 10,7** — exactement trois fois plus de
## contraste, obtenu en divisant la portee du pas par trois (0,45 → 0,15) plutot
## qu'en allongeant celle du tir, qui lui convenait deja.
##
## Et l'ORDRE a change, pas seulement l'echelle : les impacts remontent tout pres
## du tir (« legerement moins forts que les tirs ») au lieu d'occuper un milieu
## qui n'existait que dans mon classement. La hierarchie qu'il a demandee est
## **tir > impacts >>> pas**, pas une echelle reguliere.
const PORTEE_RELATIVE: Dictionary = {
	# ⚠️ **JUGES PAR ADRIEN AU BANC, LE 2026-08-26.** Ce ne sont plus des
	# rapports raisonnes : chaque valeur a ete entendue contre les autres, source
	# immobile, une molette a la fois.
	#
	# **Ce que la seance a change, et c'est une position de conception :** l'ecart
	# entre les portees allait de 1 a 10,7 ; il va desormais de 1 a 1,4. Presque
	# tout s'entend presque partout, et **ce qui distingue les sons n'est plus
	# leur portee mais leur NIVEAU** (voir la table suivante, qui s'etale de -13
	# a 0 dB). Les pas portent loin et pesent peu : ils disent une presence sans
	# la situer.
	#
	# C'est la meme decision que la courbe a 0,40, poussee jusqu'au bout — dans
	# le noir absolu, entendre que l'autre existe vaut plus que savoir a quelle
	# distance il est. Le silence n'est pas une information, c'est une absence
	# d'information.
	"footstep": 0.60,
	# **Le coup au but ne porte pas plus loin qu'un pas** (Adrien, 2026-08-26).
	# Il valait 1,35 — un reliquat de l'echelle d'avant, seul son a n'avoir pas
	# ete au banc : il aurait porte 2406 px quand le tir qui le cause en portait
	# 1515. **Le bruit de l'impact aurait trahi 60 % plus loin que le coup de feu.**
	#
	# La regle posee est plus forte qu'une correction d'echelle : **etre touche ne
	# doit pas trahir plus que marcher.** Le coup au but reste FORT (-2 dB, le
	# deuxieme du jeu) mais devient INTIME — il confirme a celui qui tire qu'il a
	# touche, sans annoncer a la carte entiere ou se passe le duel.
	"flesh_impact": 0.60,
	"wall_impact": 0.80,
	"shoot": 0.85,
	# V4.4 — le percuteur porte PEU, et c'est tout l'interet du son. Un clic a
	# vide dit « je suis desarme, et je suis la » : c'est l'aveu le plus cher du
	# jeu apres la torche. Qu'il s'entende d'un bout a l'autre de la carte en
	# ferait une annonce ; a portee courte, il ne trahit que celui qui est deja
	# assez pres pour etre trouve. Plus qu'un pas, bien moins qu'un impact.
	# **0,65 — juge par Adrien au banc, le 2026-08-26**, contre les pas et non
	# dans l'absolu : un clic a vide trahit un peu plus qu'un pas.
	#
	# ⚠️ La proposition etait **0,55, et elle etait fausse d'un facteur trois**.
	# Le nombre avait l'air modeste, mais il se multiplie par le facteur global de
	# 1,80 qu'Adrien avait deja regle : 0,55 x 1,80 = 0,99, soit **exactement la
	# diagonale de la carte**. Le percuteur portait d'un bout a l'autre de
	# l'arene — precisement ce que son commentaire disait vouloir empecher.
	#
	# La lecon vaut au-dela de ce nombre : **une valeur RELATIVE ne se juge pas
	# seule.** Elle vit dans un produit, et le facteur qui la multiplie a ete
	# regle par quelqu'un d'autre, un autre jour.
	"weapon_dry": 0.65,
}
const PORTEE_RELATIVE_DEFAUT: float = 1.0

## Niveau de chaque son, en decibels, AVANT toute distance.
##
## **Dimension neuve, ajoutee le 2026-08-25 sur demande d'Adrien** : « il faut
## que les tirs soient vraiment plus forts que le reste, et les pas beaucoup plus
## attenues ». Jusqu'ici tous les sons partaient au meme niveau et seule la
## PORTEE les distinguait — or porter loin et sonner fort sont deux choses. Un
## pas proche restait aussi present qu'un tir proche.
##
## Les deux tables se lisent ensemble : `PORTEE_RELATIVE` dit **jusqu'ou** un son
## informe, celle-ci dit **combien il pese** quand il informe. Le pas est le seul
## a etre lourdement penalise sur les deux, et c'est voulu — c'est le son le plus
## bavard du jeu (six a sept par seconde a deux joueurs), donc celui dont le
## cout d'attention est le plus mal reparti.
##
## ✅ **JUGES PAR ADRIEN AU BANC, LE 2026-08-26.** L'avertissement precedent
## disait « a doser, pas juges un par un » — il ne s'applique plus. Chaque niveau
## a ete entendu contre les autres, a source immobile.
##
## Seul le pas a bouge (-12 → -13 dB) : c'est la table des PORTEES qui a porte
## l'essentiel de la seance. Mais c'est ici que vit desormais la hierarchie, les
## portees s'etant resserrees de 1-a-10,7 vers 1-a-1,4.
const NIVEAU_RELATIF: Dictionary = {
	"footstep": -13.0,
	"wall_impact": -3.0,
	"flesh_impact": -2.0,
	"shoot": 0.0,
	"weapon_dry": -9.0,
}
const NIVEAU_RELATIF_DEFAUT: float = 0.0

## Le niveau d'un son, d'apres sa cle. Meme precaution que pour la portee : un
## tir arrive aussi sous forme de chemin depuis V4.1.
static func niveau_relatif_de(stream_or_key: Variant) -> float:
	if est_un_percuteur(stream_or_key):
		return float(NIVEAU_RELATIF.get("weapon_dry", NIVEAU_RELATIF_DEFAUT))
	if est_un_tir(stream_or_key):
		return float(NIVEAU_RELATIF.get("shoot", NIVEAU_RELATIF_DEFAUT))
	if stream_or_key is String:
		return float(NIVEAU_RELATIF.get(stream_or_key, NIVEAU_RELATIF_DEFAUT))
	return NIVEAU_RELATIF_DEFAUT

## Ecarts de dosage poses par le banc, par cle de son. Vides en jeu : ils
## n'existent que le temps d'une seance d'ecoute, et ce qui en sort se recopie
## dans les tables ci-dessus. **Un reglage qui ne survit qu'en memoire n'est pas
## un reglage, c'est un souvenir.**
var _portee_dosee: Dictionary = {}
var _niveau_dose: Dictionary = {}

func doser_portee(cle: String, valeur: float) -> void:
	_portee_dosee[cle] = clampf(valeur, 0.02, 6.0)

func doser_niveau(cle: String, valeur: float) -> void:
	_niveau_dose[cle] = clampf(valeur, -40.0, 12.0)

func portee_dosee(cle: String) -> float:
	return float(_portee_dosee.get(cle, portee_relative_de(cle)))

func niveau_dose(cle: String) -> float:
	return float(_niveau_dose.get(cle, niveau_relatif_de(cle)))

## Grille de la carte par defaut. C'est la SEULE valeur recopiee ici, et elle est
## une propriete de `assets/maps/default.json` — pas une constante d'audio.
## ⚠️ **Elle doit valoir la grille de `assets/maps/default.json`**, et
## `test_dosage_audio` le vérifie : « la grille par défaut est celle de la carte
## par défaut ». Passée de 20×20 à 30×30 le 2026-08-26, quand Adrien a demandé
## une arène une fois et demie plus grande. Le banc a attrapé l'oubli le jour
## même — sans lui, la portée de repli aurait décrit une carte imaginaire, et le
## dosage du son aurait été juste sur une arène qui n'existe plus.
const GRILLE_DEFAUT := Vector2i(30, 30)

## Diagonale de la carte par defaut, en pixels. Sert tant qu'`accorder_a_la_carte()`
## n'a pas ete appelee — une suite, un menu, un banc. Ce n'est pas un repli
## silencieux : c'est la meme grandeur, calculee sur la carte que le jeu charge
## par defaut.
##
## ⚠️ **C'etait `989.95`, recopie a la main, et un test le gardait — contre une
## AUTRE copie.** Le controle comparait la constante a
## `diagonale_carte(Vector2i(20, 20), Vector2i(35, 35))`, dont les deux littéraux
## etaient eux aussi ecrits dans le test. Le jour ou `CandelaTileSet.TILE_SIZE`
## change, la constante ET son garde-fou restent faux **ensemble**, et la suite
## reste verte. **Un garde-fou qui compare une copie a une copie ne garde rien.**
## Signale par la session DA3, qui a vu la copie ; le garde-fou factice est ma
## part.
##
## Derive maintenant de `CandelaTileSet.TILE_SIZE` : une fonction et non une
## constante, GDScript n'admettant pas d'appel dans une expression `const`.
static func portee_carte_defaut() -> float:
	return diagonale_carte(GRILLE_DEFAUT, CandelaTileSet.TILE_SIZE)

## Courbe d'attenuation (`AudioStreamPlayer2D.attenuation`), exposant applique a
## `(1 - d/portee)`.
##
## **0,40 — juge par Adrien au banc le 2026-08-25, et c'est l'inverse de ce que
## le raisonnement avait produit.** La valeur proposee etait 2,0, choisie parce
## qu'elle fait couter 12 dB a la mi-portee : « une distance, pas un reglage ».
## A l'oreille, non. Un exposant inferieur a 1 garde le son PRESENT presque
## partout et ne l'efface qu'au bout — mi-portee ne coute plus que 2,4 dB, et la
## chute arrive tard.
##
## Ce que ce choix dit du jeu, et il faut le lire avant de le rejuger : dans le
## noir absolu, **entendre que l'autre existe vaut plus que savoir a quelle
## distance il est**. Une decroissance franche rend la distance lisible et rend
## le silence trop frequent — or le silence, ici, n'est pas une information, c'est
## une absence d'information. Le second precedent du depot ou l'oreille renverse
## le calcul, apres la recuperation d'eblouissement (2026-08-24).
const COURBE_DISTANCE_DEFAUT: float = 0.4

## Diagonale de la carte courante, posee par `accorder_a_la_carte()`.
var _portee_carte: float = portee_carte_defaut()

## Les deux molettes du dosage. Publiques a dessein : le banc les tourne pendant
## que le son joue, et **un dosage qui demande de relancer le jeu ne se fait
## pas** — c'est ce regime qui a laisse l'eblouissement non fonctionnel deux mois
## sans que personne s'en apercoive.
## **1,80 — juge par Adrien au banc le 2026-08-25.** Toutes les portees relatives
## sont donc multipliees par 1,8 : un pas porte 802 px sur la carte par defaut,
## un tir 2851. Le facteur reste une molette et n'est pas fondu dans la table —
## c'est ce qui garde LISIBLE le fait qu'un humain a tranche, et de combien il a
## deplace la proposition.
const FACTEUR_PORTEE_DEFAUT: float = 1.8

var facteur_portee: float = FACTEUR_PORTEE_DEFAUT
var courbe_distance: float = COURBE_DISTANCE_DEFAUT

## La diagonale d'une carte, en pixels. Pure : verifiable sans arene ni audio.
static func diagonale_carte(grille: Vector2i, tuile: Vector2i) -> float:
	return Vector2(float(grille.x) * float(tuile.x),
		float(grille.y) * float(tuile.y)).length()

## La portee relative d'un son, d'apres sa cle.
##
## Un tir joue par son CHEMIN vaut un tir joue par sa cle — meme precaution que
## `priorite_de`, et pour la meme raison : depuis V4.1 le tir arrive sous les
## deux formes, et une comparaison qui ne repond qu'a l'une echoue en silence.
static func portee_relative_de(stream_or_key: Variant) -> float:
	if est_un_percuteur(stream_or_key):
		return float(PORTEE_RELATIVE.get("weapon_dry", PORTEE_RELATIVE_DEFAUT))
	if est_un_tir(stream_or_key):
		return float(PORTEE_RELATIVE.get("shoot", PORTEE_RELATIVE_DEFAUT))
	if stream_or_key is String:
		return float(PORTEE_RELATIVE.get(stream_or_key, PORTEE_RELATIVE_DEFAUT))
	return PORTEE_RELATIVE_DEFAUT

## La portee absolue d'un son, en pixels. Pure, et c'est elle que la suite tient.
static func portee_absolue(stream_or_key: Variant, portee_carte: float,
		facteur: float) -> float:
	return maxf(1.0, portee_carte * portee_relative_de(stream_or_key) * facteur)

## La meme, mais en tenant compte d'un dosage en cours au banc. Non statique :
## elle lit l'etat de la seance. En jeu, sans seance, elle rend exactement
## `portee_absolue` — le banc ne peut donc pas faire diverger le jeu de sa table.
func portee_courante(stream_or_key: Variant) -> float:
	var cle := String(stream_or_key) if stream_or_key is String else ""
	var relative := float(_portee_dosee.get(cle, portee_relative_de(stream_or_key)))
	return maxf(1.0, _portee_carte * relative * facteur_portee)

## ============================================================================
## DA3.9 — LA SORTIE NE SATURE PLUS, ET LE LIMITEUR NE MIXE PAS
## ============================================================================
##
## **Le probleme, mesure le 2026-08-26 :** vingt-six des quarante-cinq fichiers
## du depot depassent 0 dBFS en pic reel, jusqu'a **+4,0** pour
## `weapon_pistolet_03`. Un seul tir suffisait donc a demander a la sortie plus
## qu'elle ne peut rendre ; en fusillade, avec la reverb du bus SFX et la musique
## dessous, la somme saturait — et elle saturait **au moment le plus intense**,
## c'est-a-dire la ou le jeu ne peut pas se permettre de sonner amateur.
##
## **CE QU'ON NE FAIT PAS, ET C'EST LA DECISION D'ADRIEN (2026-08-26) :** on
## n'aligne pas la loudness des familles. « Il faut que les ecarts de loudness
## soient importants, et puissent etre corriges a la marge dans le panneau de
## reglage du son. » L'ecart EST le mixage — musique a -18 LUFS, armes a -4 — et
## l'aplatir detruirait ce qu'il a juge au banc. Le panneau (Master / Musique /
## Effets / Annonceur) fait l'ajustement fin, pas le mastering.
##
## **CE QU'ON FAIT : de la MARGE, puis un filet.**
##
## La marge est une **translation, pas une compression** : baisser tout d'une
## meme quantite en decibels preserve exactement chaque rapport juge au banc. Le
## mixage d'Adrien passe intact, il descend simplement sous le plafond. C'est la
## seule facon d'empecher la saturation sans toucher a une seule de ses valeurs.
##
## **Et le limiteur reste MUET en jeu normal, par construction.** C'est la
## contrainte « esprit du jeu », et elle n'est pas cosmetique : dans un duel ou le
## son est la seule information, un limiteur qui mord a chaque tir baisserait les
## pas de l'adversaire — **il retirerait l'information au moment precis ou elle
## compte le plus**. Meme famille que la regle du voile : ce qui protege le
## confort ne doit pas moduler ce qui renseigne.
##
## Le dimensionnement decoule donc de la mesure, pas d'une habitude : la marge
## couvre le pic le plus fort du depot (+4,0) plus un demi-decibel, si bien qu'un
## son SEUL, aussi fort soit-il, passe **sous** le plafond sans jamais reveiller
## le limiteur. Seules les SOMMES le reveillent — plusieurs tirs, ou un tir sur un
## stinger. C'est exactement le role d'un filet : rare, bref, et inaudible tant
## qu'on ne tombe pas.
##
## ⚠️ **UN SEUL limiteur, et sur Master seulement.** La tentation etait d'en
## poser un seul sur `SFX` pour que la musique ne baisse jamais. Ecartee : un
## limiteur sur SFX mordrait sur les tirs — donc baisserait les pas, qui partagent
## ce bus — et rejouerait le defaut qu'on veut eviter, deplace d'un cran. Mieux
## vaut un filet unique qui ne se declenche presque jamais qu'un etage de plus
## qui travaille tout le temps.
##
## **Le code fait foi, le fichier de bus n'est qu'un etat initial** — lecon payee
## sur la force d'occlusion, ou le banc dosait 2470 Hz pendant que le jeu jouait
## 620. `_ready()` pose le limiteur au demarrage ; ses valeurs sont ecrites dans
## `default_bus_layout.tres` uniquement pour que le fichier ne raconte pas autre
## chose que le code.

## Pic reel le plus fort du depot, mesure le 2026-08-26 (`weapon_pistolet_03`).
## Sert a dimensionner la marge, et a la reverifier quand des sons arrivent.
const PIC_MAX_DEPOT_DB: float = 4.0

## La marge, en decibels. Negative : c'est une translation vers le bas.
## Couvre `PIC_MAX_DEPOT_DB` plus un demi-decibel de securite.
const MARGE_DB: float = -4.5

## Le plafond du filet. -0,5 plutot que 0 : une conversion vers le materiel peut
## depasser de quelques dixiemes entre deux echantillons.
const PLAFOND_DB: float = -0.5

const BUS_MASTER := "Master"

## Marge et plafond courants — publics, le banc les tourne pendant que ca joue.
var marge_db: float = MARGE_DB
var plafond_db: float = PLAFOND_DB

## Pose le filet sur Master, ou met a jour celui qui y est. Idempotente.
##
## Rend `false` si le bus n'existe pas — en headless comme dans un worktree neuf,
## la disposition audio peut manquer, et une suite ne doit pas echouer pour ca.
func poser_limiteur() -> bool:
	var idx := AudioServer.get_bus_index(BUS_MASTER)
	if idx == -1:
		return false
	var limiteur: AudioEffectHardLimiter = null
	for i in AudioServer.get_bus_effect_count(idx):
		var e := AudioServer.get_bus_effect(idx, i)
		if e is AudioEffectHardLimiter:
			limiteur = e
			break
	if limiteur == null:
		limiteur = AudioEffectHardLimiter.new()
		AudioServer.add_bus_effect(idx, limiteur)
	limiteur.pre_gain_db = marge_db
	limiteur.ceiling_db = plafond_db
	return true

## Un son de ce niveau reveille-t-il le filet ? Pure, donc verifiable.
##
## C'est la propriete qui definit le reglage : **un son SEUL ne doit jamais le
## reveiller**, aussi fort soit-il. Si celui-ci rend `true` pour le pic le plus
## fort du depot, la marge est trop courte et le limiteur s'est mis a mixer.
static func reveille_le_filet(pic_db: float, marge: float, plafond: float) -> bool:
	return pic_db + marge > plafond

## ============================================================================
## S3 bis — LA FORCE DE L'OCCLUSION, EN UNE SEULE MOLETTE
## ============================================================================
##
## « L'occlusion marche moyen, je ne sais pas pourquoi » (Adrien, 2026-08-25).
## Cette phrase dit surtout qu'il lui manquait de quoi chercher : le passe-bas et
## la perte de niveau etaient cuits dans le layout, donc invisibles et
## intouchables pendant l'ecoute.
##
## **Une seule molette pour les deux, parce que « a quel point un mur etouffe »
## est UNE dimension perceptive, pas deux.** A 0 le mur ne fait rien ; a 1 il
## coupe a 300 Hz et retire 14 dB. Les deux bougent ensemble parce qu'ils disent
## la meme chose — un mur epais assourdit ET attenue, jamais l'un sans l'autre.
## ⚠️ **CORRIGE LE 2026-08-25, APRES ECOUTE : un mur ne RETIRE pas le son
## direct, il le TRANSMET assourdi.**
##
## La premiere version prenait la formule d'Adrien — « naturellement par la
## reverb » — au pied de la lettre et effondrait le `dry` a 0,12 dans le fichier
## de bus, hors de portee de la molette. Resultat mesure et entendu : **le meme
## silence a tous les niveaux**. « Derriere un mur j'entends rien, devant
## j'entends comme si de rien n'etait. » Douze pour cent d'un son percussif court,
## plus une queue de reverb, ne font pas un son etouffe : ils font une absence.
##
## La physique dit l'inverse de ce que j'avais code : **les basses traversent un
## mur**, ce sont les aigus qui restent de l'autre cote. Le direct doit donc
## rester SUBSTANTIEL et perdre son haut du spectre. La reverb complete, elle ne
## remplace pas. La formule d'Adrien decrivait bien ce qu'on ENTEND — la piece
## d'a cote — mais pas le mecanisme qui y mene.
##
## Les quatre parametres bougent maintenant ENSEMBLE sur une seule molette,
## parce qu'un mur les deplace ensemble : plus il est epais, plus il coupe les
## aigus, plus il attenue, et plus la part reverberee domine ce qui reste.
const OCCLUSION_COUPURE_MIN: float = 400.0
const OCCLUSION_COUPURE_MAX: float = 5000.0
const OCCLUSION_PERTE_MAX_DB: float = -10.0
## Le direct qui traverse : presque tout a force nulle, un peu plus de la moitie
## a force pleine. **Jamais 0,12** — c'etait le defaut.
const OCCLUSION_DRY_MAX: float = 0.95
const OCCLUSION_DRY_MIN: float = 0.55
const OCCLUSION_WET_MIN: float = 0.30
const OCCLUSION_WET_MAX: float = 0.75
## Attenuation supplementaire par PART occultee, en plus de celle du bus. C'est
## elle qui fait la pente : un tiers occulte coute un tiers de ce creux.
const OCCLUSION_PENTE_DB: float = -5.0

## Force appliquee au bus d'occlusion. **0,45 — juge par Adrien au banc le
## 2026-08-26**, apres un premier reglage a 0,50 la veille. Nommee en constante
## plutot qu'ecrite dans la variable : c'est une valeur tranchee par un humain,
## elle merite d'etre trouvable.
const FORCE_OCCLUSION_DEFAUT: float = 0.45

## Force appliquee au bus d'occlusion.
##
## ⚠️ **Et cette valeur a revele que RIEN NE L'APPLIQUAIT EN JEU.** Seul le banc
## appelait `appliquer_force_occlusion` ; en match, le bus gardait les valeurs
## brutes de `default_bus_layout.tres` — dont une coupure a **620 Hz** quand le
## banc a 0,55 en produisait **2470**. Quatre fois plus etouffe en jouant qu'en
## dosant. Adrien aurait regle a l'oreille au banc et entendu autre chose en
## match, sans qu'aucune erreur ne le dise : **le banc mesurait une chose et le
## jeu en jouait une autre**, exactement le defaut contre lequel ce banc avait
## ete ecrit.
##
## Depuis, `_ready()` applique la force au demarrage : **le code fait foi, le
## fichier de bus n'est qu'un etat initial.** Ses valeurs y sont accordees a
## 0,50 pour qu'il ne raconte pas autre chose que le code — deux sources qui
## divergent en silence sont le mode de defaillance que ce depot traque partout.
var force_occlusion: float = FORCE_OCCLUSION_DEFAUT

## Ecrit la force dans le bus. Idempotente, appelable a chaque frame.
func appliquer_force_occlusion(force: float) -> void:
	force_occlusion = clampf(force, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(BUS_SFX_OCCLUS)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, OCCLUSION_PERTE_MAX_DB * force_occlusion)
	for i in AudioServer.get_bus_effect_count(idx):
		var effet := AudioServer.get_bus_effect(idx, i)
		if effet is AudioEffectFilter:
			(effet as AudioEffectFilter).cutoff_hz = lerpf(
				OCCLUSION_COUPURE_MAX, OCCLUSION_COUPURE_MIN, force_occlusion)
		if effet is AudioEffectReverb:
			var r := effet as AudioEffectReverb
			r.dry = lerpf(OCCLUSION_DRY_MAX, OCCLUSION_DRY_MIN, force_occlusion)
			r.wet = lerpf(OCCLUSION_WET_MIN, OCCLUSION_WET_MAX, force_occlusion)

## La coupure courante du MUR, pour affichage. Pure.
##
## Nommee `coupure_occlusion_pour` et non `coupure_pour` : ce fichier porte deja
## une `coupure_pour(torches)` — le passe-bas de la musique pilote par les
## torches (V5.2). Deux coupures, deux sujets ; le parseur a attrape la
## collision, mais un nom qui aurait passe aurait ete pire qu'une erreur.
static func coupure_occlusion_pour(force: float) -> float:
	return lerpf(OCCLUSION_COUPURE_MAX, OCCLUSION_COUPURE_MIN, clampf(force, 0.0, 1.0))

## Accorde le son a la carte qu'on vient de poser. Appelee par `rebuild_arena`.
func accorder_a_la_carte(grille: Vector2i, tuile: Vector2i) -> void:
	_portee_carte = maxf(1.0, diagonale_carte(grille, tuile))

func portee_carte() -> float:
	return _portee_carte

## ============================================================================
## S3 — UN MUR ETOUFFE (decision d'Adrien, 2026-08-25)
## ============================================================================
##
## « Oui, mais **naturellement par la reverb** » — et cette formulation porte la
## mecanique. Derriere un mur, ce qui parvient a l'oreille EST le champ
## reverbere : le direct est bloque, ce qui reste a rebondi. Donc **on n'ajoute
## pas de reverb quand c'est occulte** — l'oreille entendrait un effet
## s'allumer — **on retire le son direct et on laisse ce qui reverberait deja**.
## Le son ne disparait pas : il passe dans la piece d'a cote. Meme geste que la
## torche, ou l'on ne peint pas d'ombre, on retire de la lumiere.
##
## Concretement, le bus `SFX_Occlus` porte la MEME piece que `SFX` — memes
## `room_size`, `damping`, `hipass` — avec le **`dry` effondre** et le `wet`
## releve, plus un passe-bas. C'est litteralement « le meme endroit, sans le
## direct ». Un second jeu de reglages en ferait une autre piece, et deux pieces
## superposees ne diraient plus rien de la carte — c'est le raisonnement qui a
## fait renoncer aux queues cuites dans l'echantillon (V4.1).
##
## **Une voix, pas deux.** Un vrai fondu sec/reverbere demanderait de jouer le
## son sur deux bus a la fois, donc deux voix sur seize pour un seul evenement,
## dans un pool que les pas saturent deja. Le choix de bus a l'instant du tir
## rend la meme information pour une voix. Si le fondu devient necessaire, c'est
## `SFX_POOL_SIZE` qu'il faudra revoir d'abord.
const BUS_SFX := "SFX"
const BUS_SFX_OCCLUS := "SFX_Occlus"

## L'occlusion est-elle active ? Coupee, tout part en direct — c'est l'etat
## d'avant, et le banc s'en sert pour l'A/B.
var occlusion_active: bool = true

## Combien de sons ont ete joues SANS que l'occlusion ait pu etre calculee.
##
## Un `PhysicsDirectSpaceState2D` ne se consulte que pendant une frame de
## physique ; un son joue depuis un `Timer` ou une frame de rendu ne peut donc
## pas etre teste. Il part alors en direct — le repli le plus sur, puisqu'il ne
## retire rien.
##
## **Mais un repli doit etre DISCERNABLE de la reussite** (piege du 2026-08-25,
## paye sur `apercu_torche`). Sans ce compteur, une occlusion qui ne se
## calculerait jamais s'entendrait exactement comme une occlusion desactivee, et
## on chercherait le defaut dans le bus.
var occlusions_hors_frame: int = 0

## Quel bus pour ce son ? Pure a dessein.
##
## Ne detourne **que** le bus de jeu : un appelant qui demande explicitement
## `Master` (les apercus de l'ecran audio) ou `Speaker` garde ce qu'il a demande.
## Sans cette garde, regler le volume dans les options ferait passer les apercus
## par la reverb d'occlusion.
static func bus_pour(bus_demande: String, occulte: bool) -> String:
	if bus_demande != BUS_SFX:
		return bus_demande
	return BUS_SFX_OCCLUS if occulte else BUS_SFX

## Un mur separe-t-il ce point de l'oreille ?
##
## Rend `false` des qu'on ne peut pas repondre — pas d'oreille posee, occlusion
## coupee, hors frame de physique. **Le doute joue en direct** : etouffer un son
## qu'on n'a pas su tester retirerait une information sur une incertitude.
## Quelle PART du trajet est bouchee ? 0 = degage, 1 = franchement derriere un mur.
##
## **« Elle est binaire » — Adrien, 2026-08-25, et il a raison : un seul rayon ne
## peut repondre que oui ou non.** Un joueur qui se penche a l'angle d'un mur
## basculait donc d'un coup entre « comme si de rien n'etait » et « etouffe », a
## un pixel pres, plusieurs fois par seconde en marchant. Ce clignotement est
## pire qu'une occlusion absente : il attire l'attention sur le mixage au lieu de
## renseigner sur l'adversaire.
##
## Trois rayons — l'axe et deux lateraux ecartes de 24 px — rendent un TIERS, un
## DEUX-TIERS ou un TOUT. Le bord d'un mur devient une pente courte au lieu d'une
## falaise, pour deux requetes physiques de plus sur un son qui n'en coutait
## qu'une. Ce n'est pas une vraie diffraction : c'est le minimum qui supprime le
## clignotement, et c'est ce qu'on cherchait.
const OCCLUSION_ECART_LATERAL: float = 24.0

func part_occultee(pos: Vector2) -> float:
	# **En mode « canapé », l'occlusion N'EXISTE PAS, et c'est une consequence
	# assumee de la decision d'Adrien du 2026-08-25, pas un oubli.** Etouffer la
	# copie de J1 sans toucher a celle de J2 demanderait deux voix par son, dans
	# un pool de seize que les pas saturent deja. Rendre `0.0` ici est donc la
	# reponse juste : aucun mur n'etouffe rien quand deux oreilles ecoutent.
	if _oreille2 != null:
		return 0.0
	if not occlusion_active or _oreille == null or not is_instance_valid(_oreille):
		return 0.0
	if not _oreille.is_inside_tree():
		return 0.0
	if not Engine.is_in_physics_frame():
		occlusions_hors_frame += 1
		return 0.0
	var monde := _oreille.get_world_2d()
	if monde == null:
		return 0.0
	var espace := monde.direct_space_state
	if espace == null:
		return 0.0
	var vers := _oreille.global_position
	var perp := (vers - pos).orthogonal().normalized() * OCCLUSION_ECART_LATERAL
	var touches := 0
	for decalage in [Vector2.ZERO, perp, -perp]:
		var q := PhysicsRayQueryParameters2D.create(pos + decalage, vers + decalage,
			MapGeometry.WALL_LAYER)
		if not espace.intersect_ray(q).is_empty():
			touches += 1
	return float(touches) / 3.0

func est_occulte(pos: Vector2) -> bool:
	if not occlusion_active or _oreille == null or not is_instance_valid(_oreille):
		return false
	if not _oreille.is_inside_tree():
		return false
	if not Engine.is_in_physics_frame():
		occlusions_hors_frame += 1
		return false
	var monde := _oreille.get_world_2d()
	if monde == null:
		return false
	var espace := monde.direct_space_state
	if espace == null:
		return false
	var q := PhysicsRayQueryParameters2D.create(pos, _oreille.global_position,
		MapGeometry.WALL_LAYER)
	return not espace.intersect_ray(q).is_empty()

const SFX_POOL_SIZE: int = 16

## V4.16 — priorité d'un son dans le pool. Plus haut, mieux protégé.
##
## Le pool tournait en **anneau** : le dix-septième son écrasait le premier, quel
## qu'il soit. Or les pas sont de loin la source la plus bavarde — un toutes les
## ~0,3 s et par joueur, donc six à sept par seconde à deux. Dans une fusillade,
## où s'ajoutent les tirs et les impacts de mur, ce sont eux qui reviennent le
## plus souvent voler une voix. Ils pouvaient couper net le claquement de chair
## d'un coup au but : **le son qui ne raconte rien coupait le son qui raconte.**
##
## Le classement suit ce que le son APPREND au joueur, pas son volume. Toucher
## quelqu'un est l'information la plus chère du jeu — c'est la seule confirmation
## qu'on obtient dans le noir. Un pas n'apprend qu'une présence, déjà donnée par
## le suivant.
const SFX_PRIORITE: Dictionary = {
	"footstep": 0,
	"wall_impact": 1,
	"button_click": 1,
	"ui_ready_ping": 1,
	"shoot": 2,
	"flesh_impact": 3,
}
## Un son inconnu du barème — ou joué depuis un flux et non depuis une clé — se
## place au-dessus des pas et en dessous du récit. Le défaut ne doit privilégier
## personne, mais il ne doit pas non plus laisser un son anonyme couper un kill.
const SFX_PRIORITE_DEFAUT: int = 2

## V4.15 — les pas s'effacent sous le coup de feu.
##
## Un tir sature déjà l'attention ; les pas qui continuent dessous ne s'entendent
## pas et volent des voix. Six décibels suffisent à les faire reculer sans les
## faire disparaître — on doit encore savoir que l'autre bouge.
const DUCK_TIR_DB: float = -6.0
const DUCK_TIR_S: float = 0.3

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_players_2d: Array[AudioStreamPlayer2D] = []
## Dernière voix servie de chaque pool. Ce n'est plus un pointeur d'anneau depuis
## que l'attribution est arbitrée par priorité — la valeur n'est plus lue pour
## décider, seulement pour observer.
var sfx_index: int = 0
var sfx_2d_index: int = 0
## Priorité et instant de départ de chaque voix des deux pools, pour arbitrer un
## vol de voix. Dimensionnés dans `_ready()`, en même temps que les pools.
var _sfx_prio: PackedInt32Array = PackedInt32Array()
var _sfx_debut: PackedFloat64Array = PackedFloat64Array()
var _sfx_prio_2d: PackedInt32Array = PackedInt32Array()
var _sfx_debut_2d: PackedFloat64Array = PackedFloat64Array()
## Instant du dernier coup de feu, en secondes depuis le lancement.
var _dernier_tir: float = -1000.0

# Lecteur musique unique (AudioStreamPlayer supportant nativement AudioStreamInteractive !)
var music_player: AudioStreamPlayer
var filter_tween: Tween

var speaker_player: AudioStreamPlayer
var heartbeat_tween: Tween

## Nombre de torches comptées au dernier calcul, pour distinguer un allumage
## d'une extinction : seul le premier mérite un balayage.
var _torches_allumees: int = 0
## Un silence sec en cours : deux appels superposés rendraient le premier état
## capturé après le second, et la musique resterait coupée pour de bon.
var _silence_en_cours: bool = false
var low_health_players: Dictionary = {}
var player_torches: Dictionary = {}
var is_in_match: bool = false

var _stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Pool d'AudioStreamPlayer pour SFX globaux & UI
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	_sfx_prio.resize(SFX_POOL_SIZE)
	_sfx_debut.resize(SFX_POOL_SIZE)
		
	# Pool d'AudioStreamPlayer2D pour SFX 2D positionnels
	for i in range(SFX_POOL_SIZE):
		var p2d := AudioStreamPlayer2D.new()
		p2d.bus = "SFX"
		# ⚠️ **Aucune portee posee ici, et c'est deliberé.** Il y avait
		# `max_distance = 2000.0` — devenu doublement inutile depuis S2 : la
		# portee est reecrite a CHAQUE `play_sfx_2d` (le pool est partage, la voix
		# qui joue un pas vient de jouer un tir), et 2000 est de toute facon le
		# defaut de Godot. La ligne ne faisait donc rien **tout en se lisant comme
		# une valeur active** : le genre de litteral qu'on retrouve dans six mois,
		# qu'on ajuste, et dont on cherche longtemps pourquoi il n'a aucun effet.
		# Signale par la session DA3.
		add_child(p2d)
		sfx_players_2d.append(p2d)
	_sfx_prio_2d.resize(SFX_POOL_SIZE)
	_sfx_debut_2d.resize(SFX_POOL_SIZE)
		
	# AudioStreamPlayer unique pour la musique
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	# Pré-chargement de la ressource interactive si présente
	var interactive_path := "res://assets/audio/music/main_stream_interactive.tres"
	if ResourceLoader.exists(interactive_path):
		var res = load(interactive_path)
		if res is AudioStreamInteractive:
			music_player.stream = res
			# Recherche du clip "match" (Logique Verticale)
			for i in range(res.clip_count):
				if res.get_clip_name(i) == "match":
					var clip_stream = res.get_clip_stream(i)
					if clip_stream is AudioStreamSynchronized:
						match_sync_stream = clip_stream
					break
		elif res is AudioStream:
			music_player.stream = res
			
	# Assurer la présence de l'effet LowPassFilter sur le bus Music
	_ensure_music_lowpass_effect()

	# DA3.9 — le filet de sortie. Posé par le CODE et non par le fichier de bus :
	# c'est la leçon de la force d'occlusion, où le banc dosait une valeur que le
	# jeu n'appliquait pas.
	poser_limiteur()

	# S3 — poser la force d'occlusion dès le démarrage. **Sans cette ligne, la
	# molette du banc ne pilote que le banc** : le jeu garderait les valeurs
	# cuites dans le fichier de bus, et tout dosage fait à l'oreille serait perdu
	# entre l'outil et le match.
	appliquer_force_occlusion(force_occlusion)
	
	# AudioStreamPlayer pour l'annonceur / speaker
	speaker_player = AudioStreamPlayer.new()
	speaker_player.bus = "Speaker"
	add_child(speaker_player)

# --- SECURITE : GARANTIE DU FILTRE PASS-BAS SUR LE BUS MUSIC ---
func _ensure_music_lowpass_effect() -> AudioEffectFilter:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		return null
		
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var effect = AudioServer.get_bus_effect(bus_idx, i) as AudioEffectFilter
		if effect:
			AudioServer.set_bus_effect_enabled(bus_idx, i, true)
			return effect
			
	return null

# --- RECHERCHE ET CHARGEMENT SECURISE DE SONS ---
func get_audio_stream(stream_or_key: Variant) -> AudioStream:
	if stream_or_key is AudioStream:
		return stream_or_key
	if not stream_or_key is String:
		return null
		
	var key_str: String = stream_or_key
	var path: String = SOUNDS.get(key_str, key_str)
	
	if _stream_cache.has(path):
		return _stream_cache[path]
		
	if not ResourceLoader.exists(path):
		var alt_path: String = ""
		if path.ends_with(".ogg"):
			alt_path = path.left(-4) + ".wav"
		elif path.ends_with(".wav"):
			alt_path = path.left(-4) + ".ogg"
			
		if alt_path != "" and ResourceLoader.exists(alt_path):
			path = alt_path
		else:
			return null
			
	var stream = load(path) as AudioStream
	if stream:
		_stream_cache[path] = stream
	return stream

## Choisit la voix qu'un nouveau son doit prendre, ou -1 s'il doit être renoncé.
##
## **Pure à dessein** : aucun nœud, aucune horloge, rien de l'état du serveur
## audio. C'est ce qui la rend vérifiable en headless, où le pilote audio est
## muet et où `AudioStreamPlayer.playing` ne dit pas la vérité — un arbitrage
## qu'on ne peut pas tester est un arbitrage dont on découvre les défauts à
## l'oreille, en match, une fois.
##
## Trois règles, dans cet ordre :
##
## 1. **Une voix libre d'abord**, toujours : ne voler que sous contrainte.
## 2. Sinon, prendre la **moins prioritaire** ; à égalité, la plus ancienne —
##    c'est le comportement d'anneau d'origine, mais confiné à une même classe.
## 3. **Ne jamais voler plus important que soi.** Si toutes les voix comptent
##    plus que le son entrant, il est renoncé. Un pas perdu ne s'entend pas ;
##    un coup au but coupé en deux, si.
static func choisir_voix(occupees: Array[bool], priorites: PackedInt32Array,
		debuts: PackedFloat64Array, priorite: int) -> int:
	var pire := -1
	var pire_prio := 0
	var pire_debut := 0.0
	for i in occupees.size():
		if not occupees[i]:
			return i
		var p: int = priorites[i] if i < priorites.size() else SFX_PRIORITE_DEFAUT
		var d: float = debuts[i] if i < debuts.size() else 0.0
		if pire < 0 or p < pire_prio or (p == pire_prio and d < pire_debut):
			pire = i
			pire_prio = p
			pire_debut = d
	if pire < 0 or pire_prio > priorite:
		return -1
	return pire

## La priorité d'un son, d'après sa clé. Un flux passé directement n'en a pas.
static func priorite_de(stream_or_key: Variant) -> int:
	# Un tir joué par son chemin vaut un tir joué par sa clé. Le défaut donnait
	# déjà la même valeur, mais par coïncidence : l'écrire rend le classement
	# vrai plutôt que chanceux, et il le restera si le défaut change.
	if est_un_tir(stream_or_key):
		return int(SFX_PRIORITE.get("shoot", SFX_PRIORITE_DEFAUT))
	if stream_or_key is String:
		return int(SFX_PRIORITE.get(stream_or_key, SFX_PRIORITE_DEFAUT))
	return SFX_PRIORITE_DEFAUT

func _occupations(pool: Array) -> Array[bool]:
	var occupees: Array[bool] = []
	for p in pool:
		occupees.append(bool((p as Node).get("playing")))
	return occupees

# --- JOUER DES SFX GLOBAUX ---
func play_sfx(stream_or_key: Variant, pitch_scale: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return null
		
	# --- BULLET TIME / KILLCAM AUDIO ---
	# Si la scène est au ralenti (Engine.time_scale < 1.0), tous les effets sonores
	# s'adaptent dynamiquement à l'échelle de temps de la scène (ralentis avec l'action).
	var final_pitch = pitch_scale
	if Engine.time_scale < 1.0:
		final_pitch *= clamp(Engine.time_scale, 0.05, 1.0)
		
	var prio := priorite_de(stream_or_key)
	var voie := choisir_voix(_occupations(sfx_players), _sfx_prio, _sfx_debut, prio)
	if voie < 0:
		return null
	var maintenant := Time.get_ticks_msec() / 1000.0
	_sfx_prio[voie] = prio
	_sfx_debut[voie] = maintenant
	sfx_index = voie
	var player = sfx_players[voie]
	
	player.stream = stream
	player.pitch_scale = final_pitch
	player.volume_db = volume_db
	player.bus = bus_name
	player.play()
	return player

func play_sfx_random_pitch(stream_or_key: Variant, min_pitch: float = 0.92, max_pitch: float = 1.08, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	var pitch = randf_range(min_pitch, max_pitch)
	return play_sfx(stream_or_key, pitch, volume_db, bus_name)

# --- JOUER DES SFX 2D POSITIONNELS ---
func play_sfx_2d(stream_or_key: Variant, pos: Vector2, pitch_scale: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer2D:
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return null
		
	# --- BULLET TIME / KILLCAM AUDIO ---
	# Si la scène est au ralenti (Engine.time_scale < 1.0), tous les effets sonores
	# s'adaptent dynamiquement à l'échelle de temps de la scène (ralentis avec l'action).
	var final_pitch = pitch_scale
	if Engine.time_scale < 1.0:
		final_pitch *= clamp(Engine.time_scale, 0.05, 1.0)
		
	var maintenant := Time.get_ticks_msec() / 1000.0
	# V4.15 — un tir vient de partir : les pas reculent de six décibels. Le coup
	# de feu sature déjà l'attention, et les pas qui continuent dessous ne
	# s'entendent pas tout en volant des voix. On les efface, on ne les coupe pas :
	# savoir que l'autre bouge reste une information du jeu.
	var volume_final := volume_db
	if est_un_tir(stream_or_key):
		_dernier_tir = maintenant
	elif stream_or_key is String and stream_or_key == "footstep" \
			and maintenant - _dernier_tir < DUCK_TIR_S:
		volume_final += DUCK_TIR_DB
	
	var prio := priorite_de(stream_or_key)
	var voie := choisir_voix(_occupations(sfx_players_2d), _sfx_prio_2d, _sfx_debut_2d, prio)
	if voie < 0:
		return null
	_sfx_prio_2d[voie] = prio
	_sfx_debut_2d[voie] = maintenant
	sfx_2d_index = voie
	var player = sfx_players_2d[voie]
	
	player.global_position = pos
	player.stream = stream
	player.pitch_scale = final_pitch
	# S2 — la portee se pose PAR SON et par carte, pas une fois pour toutes a la
	# construction du pool : le pool est partage, la voix qui joue un pas vient
	# de jouer un tir, et une portee posee a `_ready()` serait celle du dernier
	# son qui l'a occupee.
	player.max_distance = portee_courante(stream_or_key)
	player.attenuation = courbe_distance
	# Le niveau par son s'AJOUTE au volume demande, il ne le remplace pas : le
	# duck des pas sous le tir (V4.15) reste un ecart, pas une valeur absolue.
	var cle_niveau := String(stream_or_key) if stream_or_key is String else ""
	player.volume_db = volume_final + float(
		_niveau_dose.get(cle_niveau, niveau_relatif_de(stream_or_key)))
	# S3 — le bus se choisit ici, au seul instant ou l'on connait a la fois la
	# position du son et celle de l'oreille. La PART occultee adoucit en plus le
	# bord : un son occulte au tiers part sur le bus etouffe, mais n'y perd qu'un
	# tiers de la penalite. Sans ca, l'angle d'un mur fait clignoter le mixage.
	var part := part_occultee(pos)
	player.bus = bus_pour(bus_name, part > 0.0)
	if part > 0.0:
		player.volume_db += OCCLUSION_PENTE_DB * part
	player.play()
	return player

## Le coup de feu d'une arme, tiré au sort parmi ses quatre variantes.
##
## Le pitch reste, mais resserré : ±4 % au lieu de ±8 %. La variation large
## servait à masquer la répétition d'un échantillon unique ; avec quatre prises
## réelles elle n'a plus ce travail à faire, et trop de pitch s'entend — un
## calibre qui change de taille d'un coup à l'autre.
##
## Une arme dont les variantes manquent retombe sur le son générique plutôt que
## de se taire : la règle du dépôt est de câbler et de rester silencieux, mais
## le coup de feu est le seul son qui porte une INFORMATION DE JEU — il dit
## qu'on vient de tirer, et où. Le taire changerait l'équilibre, pas seulement
## l'ambiance.
func play_weapon_shot(slug: String, pos: Vector2) -> AudioStreamPlayer2D:
	var chemin := chemin_tir(slug, randi_range(1, VARIANTES_TIR))
	if get_audio_stream(chemin) == null:
		return play_sfx_2d_random_pitch("shoot", pos, 0.92, 1.08)
	return play_sfx_2d_random_pitch(chemin, pos, 0.96, 1.04)

func play_sfx_2d_random_pitch(stream_or_key: Variant, pos: Vector2, min_pitch: float = 0.92, max_pitch: float = 1.08, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer2D:
	var pitch = randf_range(min_pitch, max_pitch)
	return play_sfx_2d(stream_or_key, pos, pitch, volume_db, bus_name)

# --- MUSIQUE INTERACTIVE & AUDIOSTREAMPLAYER ---
func play_music(stream_or_key: Variant) -> void:
	var clip_name := str(stream_or_key)
	if clip_name.begins_with("music_"):
		clip_name = clip_name.trim_prefix("music_")
		
	# Si un AudioStreamInteractive est chargé sur le music_player
	if music_player.stream is AudioStreamInteractive:
		if not music_player.playing:
			music_player.play()
		var playback = music_player.get_stream_playback()
		if playback and playback is AudioStreamPlaybackInteractive:
			playback.switch_to_clip_by_name(clip_name)
			return

	# Fallback : Chargement d'un fichier audio direct
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return
		
	if music_player.stream == stream and music_player.playing:
		return

	music_player.stream = stream
	music_player.play()

## Démarre la musique au lancement du jeu, par l'intro.
##
## Pourquoi `play_music("music_menu")` ne pouvait pas rendre ce service, et
## pourquoi c'est contre-intuitif : elle appelle `play()`, qui démarre le flux à
## son **clip initial** — l'intro — puis bascule aussitôt sur le menu. L'intro
## sortait donc pour de vrai, mais jusqu'au prochain temps seulement (0,35 s à
## 170 BPM, par le repli ANY→ANY), avant d'être fondue. Cinq secondes et demie
## de musique écrites, jouées un tiers de seconde, sans que rien ne soit en
## panne et sans qu'aucune erreur ne le dise.
##
## Ici on démarre et on ne demande RIEN. Le clip initial joue en entier, et son
## `auto_advance` conduit au menu au bout de ses seize temps. Les retours au
## menu qui suivront passent par `play_music`, qui trouve le lecteur déjà en
## marche et se contente de basculer : l'intro ne revient pas de la partie.
## C'est ce qui la garde rare — au dixième retour au menu d'une soirée, cinq
## secondes d'attente ne sont plus une entrée en matière, c'est un péage.
func demarrer_musique_au_lancement() -> void:
	if music_player.stream is AudioStreamInteractive:
		if not music_player.playing:
			music_player.play()
		return
	# Sans le flux interactif — ressource absente — il n'y a pas d'intro à
	# jouer ni d'enchaînement automatique pour en sortir : on ouvre sur le menu.
	play_music("music_menu")

func switch_music_clip(clip_name: String) -> void:
	if music_player.stream is AudioStreamInteractive:
		if not music_player.playing:
			music_player.play()
		var playback = music_player.get_stream_playback()
		if playback and playback is AudioStreamPlaybackInteractive:
			playback.switch_to_clip_by_name(clip_name)
			return
	play_music(clip_name)

# --- LOGIQUE VERTICALE (INTENSITE DE MATCH) ---
var match_sync_stream: AudioStreamSynchronized = null
var music_intensity_tweens: Dictionary = {}
## Niveau courant : permet à GameState d'appeler set_music_intensity chaque
## frame sans relancer les tweens — seul un vrai changement déclenche le fondu.
var music_intensity: int = 0

func set_music_intensity(level: int) -> void:
	# level 0 : Base uniquement (-60db sur le reste)
	# level 1 : Base + Batterie (Stems 0 et 1)
	# level 2 : Base + Batterie + Arpège (Stems 0, 1, et 2)
	if level == music_intensity:
		return
	music_intensity = level
	if not match_sync_stream:
		return
		
	var target_vols = [-60.0, -60.0, -60.0]
	
	if level >= 0:
		target_vols[0] = 0.0 # Base active
	if level >= 1:
		target_vols[1] = 0.0 # Drums actifs
	if level >= 2:
		target_vols[2] = 0.0 # Arpège actif
		
	for i in range(min(3, match_sync_stream.stream_count)):
		if music_intensity_tweens.has(i) and music_intensity_tweens[i].is_valid():
			music_intensity_tweens[i].kill()
			
		var t = create_tween()
		music_intensity_tweens[i] = t
		var current_vol = match_sync_stream.get_sync_stream_volume(i)
		t.tween_method(
			func(v: float): match_sync_stream.set_sync_stream_volume(i, v),
			current_vol, target_vols[i], 1.0
		)

# --- GESTION DU FILTRE PASS-BAS ADDITIF (LAMPES & MATCH) ---
## V3.8 — un silence sec, puis la musique revient.
##
## Une égalité n'est pas une défaite au ralenti : c'est un arrêt. Couper le son
## une seconde le dit mieux que n'importe quel mot, et le mot arrive dans ce
## silence au lieu de se poser sur une musique qui continue comme si de rien
## n'était.
##
## **On restitue l'état trouvé, pas un état choisi.** Le bus est déjà coupé quand
## le joueur a mis la musique à zéro : le rallumer d'office lui rendrait un son
## qu'il a explicitement retiré. C'est la même règle que pour toute propriété
## partagée — capturer à l'entrée, restituer à la sortie.
func silence_sec(duree: float = 1.0) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx == -1:
		return
	if _silence_en_cours:
		return
	_silence_en_cours = true
	var etait_coupe := AudioServer.is_bus_mute(idx)
	AudioServer.set_bus_mute(idx, true)
	var minuterie := get_tree().create_timer(duree, true, false, true)
	minuterie.timeout.connect(func() -> void:
		AudioServer.set_bus_mute(idx, etait_coupe)
		_silence_en_cours = false)

## Noeud du monde de jeu qui heberge les voix positionnelles pendant un match, et
## l'oreille posee sur le joueur local. Voir `poser_oreille`.
var _hote_positionnel: Node = null
var _oreille: AudioListener2D = null
## Mode « canapé » seulement : la seconde oreille, son relais sous `vue2`, le
## joueur qu'il recopie, et les vues qu'on a rendues auditrices — pour savoir
## quoi rendre a l'etat d'origine.
var _oreille2: AudioListener2D = null
var _relais: Node2D = null
var _suivi: Node2D = null
var _vues_ecoutantes: Array = []

## Fait demenager les voix positionnelles dans le monde du jeu, et pose l'oreille
## sur le joueur local.
##
## **Sans les DEUX gestes, aucun des deux ne s'entend**, et c'est le piege de ce
## correctif. Le pool d'`AudioStreamPlayer2D` est enfant de cet autoload, donc
## dans le `World2D` de la RACINE ; le jeu vit dans celui du `SubViewport`. Un
## `AudioStreamPlayer2D` ne s'adresse qu'aux viewports de son propre monde —
## poser un `AudioListener2D` sur le joueur sans demenager le pool ne change rien
## du tout, et on chercherait l'erreur dans le listener.
##
## Troisieme piece, invisible et mesuree : **un `SubViewport` n'est PAS une
## oreille par defaut** — `audio_listener_enable_2d` vaut `false`, seule la
## fenetre racine l'a a `true`. Sans l'activer, le viewport est ignore meme une
## fois le pool au bon endroit.
##
## Ce que ca corrige : l'oreille etait plantee au centre de l'ecran virtuel,
## immobile. Le panoramique disait ou le son etait SUR LA CARTE, pas par rapport
## a soi ; avancer vers l'adversaire ne rendait pas ses pas plus forts. Rien
## n'etait en erreur et tout etait audible — une sortie plausible.
func poser_oreille(porteur: Node2D) -> void:
	rendre_oreille()
	if porteur == null or not is_instance_valid(porteur):
		return
	var hote := porteur.get_parent()
	if hote == null:
		return
	_hote_positionnel = hote
	for p in sfx_players_2d:
		if is_instance_valid(p) and p.is_inside_tree():
			p.reparent(hote, false)
	var vue := porteur.get_viewport()
	if vue != null:
		vue.audio_listener_enable_2d = true
		# ⚠️ **ET COUPER LA RACINE, sans quoi il y a DEUX auditeurs.**
		#
		# `SceneTree` declare la racine auditrice au demarrage. Activer la vue de
		# jeu ne la remplace pas : elle S'AJOUTE. Or `AudioStreamPlayer2D` somme
		# une sortie par viewport auditeur — chaque son sortait donc deux fois,
		# une copie juste depuis l'oreille du joueur, une copie depuis le point
		# fixe hors de la carte. **C'est le defaut que S1 pretendait reparer,
		# survivant a son propre correctif** et mesure en entrainement le
		# 2026-08-25 : `auditeurs = 2 ["racine", "SubViewport1"]`.
		#
		# Invisible jusqu'ici parce que la copie fautive etait le plus souvent
		# HORS PORTEE — le point fixe est loin de la carte, et les portees ont
		# ete resserrees. Elle ne produisait donc « que » un son sourd et
		# decale par instants, pas une erreur.
		_vues_ecoutantes = [vue]
		# ⚠️ **Sauf si l'oreille vit DANS la racine** — sinon on coupe le viewport
		# qui la porte, et il n'y a plus aucun auditeur du tout. Mesuré : crête du
		# bus SFX à **-200 dB**, silence complet, sur un banc qui marchait la
		# minute d'avant. Le premier jet de ce correctif coupait sans regarder.
		#
		# Le cas n'est pas theorique : c'est celui du banc de dosage, et ce sera
		# celui du jeu entier si le chantier R remonte le duel dans le viewport
		# racine. **Un correctif qui suppose que le monde est ailleurs casse le
		# jour ou il est ici.**
		if vue != get_tree().root:
			get_tree().root.audio_listener_enable_2d = false
	_oreille = AudioListener2D.new()
	_oreille.name = "OreilleLocale"
	porteur.add_child(_oreille)
	_oreille.make_current()
	# L'hote disparait a chaque reconstruction d'arene. Sans ce rappel, le pool
	# partirait avec lui : seize voix liberees, et plus un seul son positionnel du
	# reste de la session — sans erreur, evidemment.
	if not hote.tree_exiting.is_connected(rendre_oreille):
		hote.tree_exiting.connect(rendre_oreille, CONNECT_ONE_SHOT)
	_tracer_ecoute("une oreille posee sur %s" % porteur.name)

## Pose UNE oreille par joueur, chacune dans sa propre vue — le mode « canapé ».
##
## **Decision d'Adrien du 2026-08-25 : en ecran partage, on fait la SOMME.** Le
## moteur la produit tout seul — `AudioStreamPlayer2D` boucle sur tous les
## viewports auditeurs de son `World2D` et somme une sortie par viewport. Chaque
## copie arrive au volume que CE joueur-la entendrait, si bien que **le plus
## proche l'emporte sans qu'on arbitre** : sa copie est simplement plus forte.
##
## ⚠️ **Une oreille ne peut pas etre l'enfant du joueur ici, et c'est le piege du
## montage.** `make_current()` enregistre le listener sur SON viewport, et les
## deux joueurs vivent tous deux sous `vue1` (`vp2` partage le monde mais
## n'heberge aucun joueur). Deux oreilles posees sur les joueurs se disputeraient
## donc `vue1`, et `vue2` n'ecouterait rien : on aurait une oreille au lieu de
## deux, sans erreur. La seconde vit donc sous `vue2` sur un **relais** dont la
## position recopie celle de J2 a chaque frame.
##
## ⚠️ **La racine se coupe, et c'est vital.** `SceneTree` la declare auditrice au
## demarrage : sans cette coupure, une TROISIEME sortie s'ajoute — celle du point
## fixe hors de la carte, c'est-a-dire le defaut que S1 vient de reparer, remis
## par-dessus son propre correctif et parfaitement audible. Voir le piege
## « L'ecoute suit le viewport du listener » dans la ROADMAP.
func poser_deux_oreilles(j1: Node2D, j2: Node2D, vue1: Viewport, vue2: Viewport) -> void:
	rendre_oreille()
	if j1 == null or j2 == null or vue1 == null or vue2 == null:
		return
	if not is_instance_valid(j1) or not is_instance_valid(j2):
		return
	var hote := j1.get_parent()
	if hote == null:
		return
	_hote_positionnel = hote
	for p in sfx_players_2d:
		if is_instance_valid(p) and p.is_inside_tree():
			p.reparent(hote, false)

	get_tree().root.audio_listener_enable_2d = false
	vue1.audio_listener_enable_2d = true
	vue2.audio_listener_enable_2d = true

	_oreille = AudioListener2D.new()
	_oreille.name = "OreilleJ1"
	j1.add_child(_oreille)
	_oreille.make_current()

	_relais = Node2D.new()
	_relais.name = "RelaisOreilleJ2"
	vue2.add_child(_relais)
	_oreille2 = AudioListener2D.new()
	_oreille2.name = "OreilleJ2"
	_relais.add_child(_oreille2)
	_oreille2.make_current()
	_suivi = j2
	_vues_ecoutantes = [vue1, vue2]

	if not hote.tree_exiting.is_connected(rendre_oreille):
		hote.tree_exiting.connect(rendre_oreille, CONNECT_ONE_SHOT)
	_tracer_ecoute("deux oreilles posees — ecran partage (somme)")

## ============================================================================
## LE DIAGNOSTIC D'ECOUTE — pour lire ce qui sort, pas ce qu'on croit poser
## ============================================================================
##
## **Ecrit parce qu'un graphe correct n'est pas un son qui sort.** Trois fois de
## suite, « auditeurs = 1, oreille courante, pool dans le bon monde » a ete
## verifie et trouve juste pendant que le silence durait. Ces trois faits sont
## vrais et ne prouvent rien : il manquait quelqu'un pour ecouter, ou le son
## partait hors de portee.
##
## Il vit dans l'autoload et **ne touche a aucun fichier d'une autre session** —
## `ui.gd` et son panneau F3 appartiennent au domaine « menus ». Il s'imprime
## dans la console, donc visible directement quand on lance depuis l'editeur.
##
## Imprime aux TRANSITIONS (pose et retrait d'oreille) plutot que sur demande :
## c'est la transition qui casse, et personne ne pense a interroger l'etat juste
## apres l'avoir changee. Sur demande aussi, par **F4**.
func diagnostic_ecoute() -> String:
	var lignes := PackedStringArray()
	var arbre := get_tree()
	if arbre == null:
		return "[audio] pas d'arbre"

	var auditeurs := PackedStringArray()
	if arbre.root.is_audio_listener_2d():
		auditeurs.append("racine%s" % ("" if arbre.root.get_audio_listener_2d() != null else " (SANS oreille — point fixe)"))
	for v in _vues_ecoutantes:
		if v != null and is_instance_valid(v) and (v as Viewport).is_audio_listener_2d():
			auditeurs.append(String((v as Viewport).name))

	lignes.append("[audio] auditeurs : %s" % (", ".join(auditeurs) if auditeurs.size() > 0
		else "AUCUN — rien ne sortira"))
	lignes.append("[audio] oreilles  : principale=%s seconde=%s" % [
		"oui" if _oreille != null and is_instance_valid(_oreille) else "non",
		"oui" if _oreille2 != null and is_instance_valid(_oreille2) else "non"])
	if _oreille != null and is_instance_valid(_oreille):
		lignes.append("[audio]   principale sur %s, courante=%s, viewport=%s" % [
			_oreille.get_parent().name, _oreille.is_current(),
			_oreille.get_viewport().name if _oreille.get_viewport() != null else "—"])
	var voix: AudioStreamPlayer2D = sfx_players_2d[0] if sfx_players_2d.size() > 0 else null
	if voix != null:
		lignes.append("[audio] pool chez : %s" % voix.get_parent().name)
	lignes.append("[audio] portee d'un pas=%.0f px, d'un tir=%.0f px (carte %.0f, facteur %.2f)" % [
		portee_courante("footstep"), portee_courante("shoot"),
		_portee_carte, facteur_portee])
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx != -1:
		lignes.append("[audio] bus SFX : %s, volume %.1f dB" % [
			"COUPE" if AudioServer.is_bus_mute(idx) else "actif",
			AudioServer.get_bus_volume_db(idx)])
	lignes.append("[audio] replis hors physique : %d" % occlusions_hors_frame)
	return "\n".join(lignes)

## L'etat s'imprime aux transitions, en build debug seulement.
##
## **En build release, `print()` est tamponne et vide a la fermeture propre** :
## un diagnostic qui ne sort qu'a la sortie ne diagnostique rien. Il n'a de sens
## que depuis l'editeur, ou Adrien le lit pendant qu'il joue.
var _a_trace_une_pose := false

func _tracer_ecoute(quand: String) -> void:
	if not OS.is_debug_build():
		return
	if quand.begins_with("une oreille") or quand.begins_with("deux oreilles"):
		_a_trace_une_pose = true
	print("--- ecoute : %s ---" % quand)
	print(diagnostic_ecoute())

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_F4:
		_tracer_ecoute("F4, a la demande")

## Ramene les voix a la maison et retire l'oreille. Idempotente a dessein : elle
## est appelee au debut de `poser_oreille` autant qu'a la fin d'un match.
func rendre_oreille() -> void:
	if _oreille != null and is_instance_valid(_oreille):
		_oreille.queue_free()
	_oreille = null
	# Le mode « canapé » laisse trois choses derriere lui, et **les oublier rend
	# le jeu muet hors match sans qu'aucune erreur ne le dise** : la racine
	# coupee, deux vues auditrices, et un relais qui suit un joueur disparu.
	if _oreille2 != null and is_instance_valid(_oreille2):
		_oreille2.queue_free()
	_oreille2 = null
	if _relais != null and is_instance_valid(_relais):
		_relais.queue_free()
	_relais = null
	_suivi = null
	for v in _vues_ecoutantes:
		if v != null and is_instance_valid(v):
			(v as Viewport).audio_listener_enable_2d = false
	_vues_ecoutantes = []
	if get_tree() != null:
		get_tree().root.audio_listener_enable_2d = true
	# Tracé au RETRAIT autant qu'à la pose : le défaut du 2026-08-25 était une
	# pose suivie d'un retrait qui la défaisait. Ne tracer que les poses aurait
	# montré un état juste à chaque fois.
	if _a_trace_une_pose:
		_a_trace_une_pose = false
		_tracer_ecoute("oreille rendue")
	if _hote_positionnel != null and is_instance_valid(_hote_positionnel):
		if _hote_positionnel.tree_exiting.is_connected(rendre_oreille):
			_hote_positionnel.tree_exiting.disconnect(rendre_oreille)
	_hote_positionnel = null
	for p in sfx_players_2d:
		if is_instance_valid(p) and p.is_inside_tree() and p.get_parent() != self:
			p.reparent(self, false)

func set_in_match(in_match: bool) -> void:
	is_in_match = in_match
	player_torches.clear()
	_torches_allumees = 0
	# Chaque match repart au calme : l'intensité gagnée ne survit pas à la manche.
	set_music_intensity(0)
	if is_in_match:
		update_torch_cutoff()
	else:
		set_music_cutoff(20000.0, 1)

## La torche de ce joueur a-t-elle le droit d'être entendue ici ?
##
## **C'était une fuite d'information, et elle a bien failli être amplifiée.**
## `set_player_torch` était appelé pour CHAQUE joueur, adversaire répliqué
## compris : en ligne, quand l'autre allumait sa torche à l'autre bout de la
## carte, invisible, la musique locale s'ouvrait de 150 Hz. Le jeu tout entier
## repose sur le fait qu'allumer sa torche est un aveu — un aveu que l'adversaire
## paie de sa position. Le bus musical le donnait gratuitement, sans regarder.
##
## `local_idx` vaut -1 en écran partagé : les deux joueurs regardent le même
## écran et s'entendent par la même sortie, il n'y a rien à cacher. En ligne, il
## désigne le seul joueur dont on a le droit de connaître la torche : soi.
static func torche_comptee(player_id: int, local_idx: int) -> bool:
	return local_idx < 0 or player_id == local_idx

## La coupure du passe-bas musical, selon le nombre de torches allumées.
##
## V5.2 — l'écart était de 300 à 600 Hz, soit une octave qu'on ne remarque pas
## en jouant. De 200 à 840, on l'entend : dans le noir la musique est sourde et
## lointaine, torche allumée elle revient dans la pièce. **Allumer, c'est
## entendre** — et le prix reste le même, on se montre.
static func coupure_pour(torches: int) -> float:
	return 200.0 + float(maxi(torches, 0)) * 320.0

func set_player_torch(player_id: int, is_on: bool) -> void:
	# V5.1 — le claquement d'allumage/extinction, sur la transition seulement.
	# Sans fuite par construction : le site d'appel (player.gd) filtre déjà par
	# torche_comptee — la torche adverse en ligne n'arrive jamais ici.
	var avant: bool = player_torches.get(player_id, false)
	player_torches[player_id] = is_on
	if avant != is_on:
		play_sfx("torch_on" if is_on else "torch_off", 1.0, -6.0)
	if is_in_match:
		update_torch_cutoff()

func update_torch_cutoff() -> void:
	var active_count := 0
	for pid in player_torches:
		if player_torches[pid]:
			active_count += 1

	var cible := coupure_pour(active_count)
	# V5.2 — le balayage. Une torche qui s'allume dépasse sa cible puis y
	# retombe : c'est ce dépassement qu'on ENTEND, un filtre qui s'ouvre. Sans
	# lui, le changement est réel mais passe pour un hasard du mixage.
	# À l'extinction, aucun dépassement : on ne fête pas de se rendre invisible.
	if active_count > _torches_allumees:
		_torches_allumees = active_count
		set_music_cutoff(cible * 1.7, 0.09)
		var retombee := create_tween()
		retombee.tween_interval(0.09)
		retombee.tween_callback(func() -> void: set_music_cutoff(cible, 0.45))
		return
	_torches_allumees = active_count
	set_music_cutoff(cible, 0.25)

func set_music_cutoff(cutoff_hz: float, duration: float = 0.1) -> void:
	var filter = _ensure_music_lowpass_effect()
	if not filter:
		return
		
	if filter_tween and filter_tween.is_valid():
		filter_tween.kill()
		
	filter_tween = create_tween()
	filter_tween.tween_property(filter, "cutoff_hz", cutoff_hz, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- SPEAKER & UI ---
func play_speaker(stream_or_key: Variant, volume_db: float = 0.0) -> void:
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return
		
	if speaker_player.playing:
		speaker_player.stop()
		
	speaker_player.stream = stream
	speaker_player.volume_db = volume_db
	speaker_player.play()

func play_button_click(volume_db: float = 0.0) -> void:
	play_sfx("button_click", 1.0, volume_db)

# --- V5.3 : ACOUPHÈNE D'ÉBLOUISSEMENT ---

## Boucle dont le volume suit l'éblouissement du joueur LOCAL — chaque machine
## n'écoute que ses propres yeux (le site d'appel, player.gd, est déjà gardé
## par _is_locally_piloted). En écran partagé, deux joueurs éblouis partagent
## la sortie : on prend le maximum. Muet tant que l'asset manque.
var _dazzle_levels: Dictionary = {}
var _dazzle_player: AudioStreamPlayer
var _dazzle_current: float = 0.0

func set_dazzle_level(pid: int, amount: float) -> void:
	_dazzle_levels[pid] = amount
	var niveau := 0.0
	for v in _dazzle_levels.values():
		niveau = maxf(niveau, float(v))
	# Idempotent : appelé chaque frame, il ne travaille que sur un vrai
	# changement — même patron que set_music_intensity.
	if absf(niveau - _dazzle_current) < 0.02 and (niveau > 0.01) == (_dazzle_current > 0.01):
		return
	_dazzle_current = niveau
	if niveau <= 0.01:
		if _dazzle_player and _dazzle_player.playing:
			_dazzle_player.stop()
		return
	if _dazzle_player == null:
		_dazzle_player = AudioStreamPlayer.new()
		_dazzle_player.bus = "SFX"
		add_child(_dazzle_player)
	if not _dazzle_player.playing:
		var s := get_audio_stream("dazzle_ringing")
		if s == null:
			return # Câblé, muet : l'asset n'existe pas encore.
		_dazzle_player.stream = s
		_dazzle_player.play()
	_dazzle_player.volume_db = linear_to_db(clampf(niveau, 0.05, 1.0)) - 8.0

# --- V6.3 : SIDECHAIN DU RALENTI (KILLCAM) ---

## Pendant le bullet-time, la musique s'efface — seul le battement de cœur
## reste — et tout revient à l'impact. Piloté par Engine.time_scale, qui est
## déjà la source du pitch des SFX : aucun couplage nouveau avec la killcam.
var _bullet_time_duck := false

func _process(_delta: float) -> void:
	# Le relais de la seconde oreille recopie la position de J2 (mode « canapé »).
	# **Ici, et AVANT la sortie anticipée du duck de ralenti** : ce `_process`
	# rend la main dès la deuxième ligne la plupart des frames. Un second
	# `_process` aurait été refusé par le parseur ; le placer après le `return`
	# ne l'aurait été par personne, et l'oreille de J2 serait restée immobile.
	if _relais != null and is_instance_valid(_relais) \
			and _suivi != null and is_instance_valid(_suivi):
		_relais.global_position = _suivi.global_position

	var bt := Engine.time_scale < 0.5 and match_sync_stream != null
	if bt == _bullet_time_duck:
		return
	_bullet_time_duck = bt
	if bt:
		for i in range(mini(3, match_sync_stream.stream_count)):
			_tween_stem(i, -60.0, 0.12)
		if match_sync_stream.stream_count > 3:
			_tween_stem(3, 0.0, 0.12)
	else:
		# Réappliquer l'état nominal : l'intensité courante pour les stems 0-2
		# (en forçant la garde d'idempotence), la santé basse pour le cœur.
		var niveau := music_intensity
		music_intensity = -1
		set_music_intensity(niveau)
		_eval_low_health_state()

## Fondu d'un stem vers une cible, en écrasant le tween que l'intensité ou le
## cœur aurait laissé en vol sur ce même stem.
func _tween_stem(i: int, cible_db: float, duree: float) -> void:
	if match_sync_stream == null or i >= match_sync_stream.stream_count:
		return
	if i == 3 and heartbeat_tween and heartbeat_tween.is_valid():
		heartbeat_tween.kill()
	if music_intensity_tweens.has(i) and music_intensity_tweens[i].is_valid():
		music_intensity_tweens[i].kill()
	var t := create_tween()
	music_intensity_tweens[i] = t
	var depuis := match_sync_stream.get_sync_stream_volume(i)
	t.tween_method(
		func(v: float): match_sync_stream.set_sync_stream_volume(i, v),
		depuis, cible_db, duree
	)

# --- ETAT SANTE BASSE (STEM MUSICAL SYNCHRONISE) ---
func update_low_health(player_id: int, is_low: bool) -> void:
	low_health_players[player_id] = is_low
	_eval_low_health_state()

func reset_low_health() -> void:
	low_health_players.clear()
	_eval_low_health_state()

func _eval_low_health_state() -> void:
	var any_low: bool = false
	for pid in low_health_players:
		if low_health_players[pid]:
			any_low = true
			break
			
	if not match_sync_stream or match_sync_stream.stream_count <= 3:
		return

	if heartbeat_tween and heartbeat_tween.is_valid():
		heartbeat_tween.kill()
		
	heartbeat_tween = create_tween()
	var target_vol := 0.0 if any_low else -60.0
	var current_vol := match_sync_stream.get_sync_stream_volume(3)
	heartbeat_tween.tween_method(
		func(v: float): match_sync_stream.set_sync_stream_volume(3, v),
		current_vol, target_vol, 0.5
	)
