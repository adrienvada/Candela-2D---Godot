class_name RankLoadout

## Quelles armes un joueur peut prendre, selon le mode et son rang — Phase 7.
##
## ## Deux axes, pas un
##
## L'arsenal ne se lit pas sur « classé contre local », mais sur deux questions
## indépendantes (décision d'Adrien, 2026-08-18) :
##
##   • **hors compétitif** — écran partagé et tous les modes amicaux — chacun
##     prend ce qu'il veut dans le SOCLE, et les deux camps peuvent différer.
##     L'équilibre est une exigence de classement, pas de jeu : deux amis ont le
##     droit de s'affronter Pistolet contre Arbalète ;
##   • **en compétitif**, chacun reçoit la **sélection attribuée à son rang**,
##     et la règle du miroir aligne les deux camps sur celle du moins bien classé.
##
## ## Ce n'est pas un déblocage qui s'accumule
##
## Un joueur Lanterne n'a pas quatre armes : il a l'Arbalète. La table associe un
## rang à une sélection, pas à un cran franchi — et elle n'est **pas monotone** :
## faute d'armes supplémentaires, les rangs au-dessus de Lanterne redescendent au
## Pistolet. Tout code qui supposerait « plus haut = plus d'armes » serait faux
## dès Torche.
##
## ## Une sélection, jamais une arme
##
## Chaque entrée est un tableau, alors qu'elle n'en contient qu'une aujourd'hui.
## C'est délibéré : Adrien prévoit qu'à partir de certains rangs on emporte
## plusieurs armes et qu'on en change pendant la manche. Rendre une arme seule
## obligerait à réécrire tous les appelants ce jour-là ; rendre une sélection d'un
## élément ne coûte rien maintenant et les laisse intacts.
##
## ## Saisonnière
##
## « Ça changera peut-être à chaque saison. » La table vit donc **ici**, dans un
## fichier qui ne connaît ni l'interface ni le réseau, et se remplace sans
## toucher à ce qui la lit.

## Index des armes — celui des râteliers de l'interface et des RPC de choix
## d'arme. C'est la clé stable : les noms portent des accents et se traduisent,
## les index sont ce qui circule réellement sur le fil.
const PISTOLET := 0
const FUSIL := 1
const POMPE := 2
const ARBALETE := 3

## Ce que tout le monde peut prendre hors compétitif, sans rien avoir mérité.
const SOCLE: Array[int] = [PISTOLET, FUSIL, POMPE, ARBALETE]

## La sélection compétitive, par catégorie de rang — index 0 = Aveugle,
## première des dix catégories de l'échelle (`RANK_TIERS` dans `elo.ts`).
##
## Les six dernières entrées sont au Pistolet **faute de contenu**, pas par
## conception : les catégories 5 à 10 ne débloquent encore rien, et c'est un trou
## à combler avec des armes, pas avec une règle.
const COMPETITIF: Array[Array] = [
	[PISTOLET],  # 1 — Aveugle
	[FUSIL],     # 2 — Braise
	[POMPE],     # 3 — Bougie
	[ARBALETE],  # 4 — Lanterne
	[PISTOLET],  # 5 — Torche
	[PISTOLET],  # 6 — Brasier
	[PISTOLET],  # 7 — Phare
	[PISTOLET],  # 8 — Aurore
	[PISTOLET],  # 9 — Zénith
	[PISTOLET],  # 10 — Candela
]

## La sélection d'un joueur en compétitif, d'après sa catégorie (1 à 10).
##
## Un rang inconnu — 0, négatif, ou hors échelle — rend la sélection de la
## première catégorie plutôt qu'un tableau vide. Entrer en compétitif attribue le
## classement de départ, lequel tombe au plancher de l'échelle depuis le
## 2026-08-18 : un joueur sans ligne au classement est donc Aveugle en pratique.
## Rendre vide donnerait un joueur sans arme, ce qu'aucun appelant ne sait
## afficher et qu'aucune partie ne peut jouer.
static func for_tier(tier_index: int) -> Array[int]:
	var i := clampi(tier_index, 1, COMPETITIF.size()) - 1
	var selection: Array[int] = []
	selection.assign(COMPETITIF[i])
	return selection

## La règle du miroir : les deux camps partagent la sélection du **moins bien
## classé** des deux.
##
## Sans elle, le mieux classé arriverait avec des options que l'autre ne peut pas
## avoir — le cas le plus net étant l'Arbalète, à la fois l'arme furtive et la
## quatrième de l'échelle. Le coût, assumé, est que l'arsenal d'un joueur dépend
## de son adversaire : l'interface doit le dire au moment où ça arrive, sans quoi
## ce sera vécu comme un défaut.
##
## Le calcul appartient à l'hôte, comme tout le reste de l'autorité ; le client
## l'affiche, il ne le décide pas.
static func mirrored(tier_a: int, tier_b: int) -> Array[int]:
	return for_tier(mini(maxi(tier_a, 1), maxi(tier_b, 1)))

## Les armes proposées dans un mode donné.
##
## `ranked` est la seule question qui compte ici : l'écran partagé et l'amical en
## ligne partagent exactement le même arsenal, et les distinguer serait inventer
## une règle que personne n'a demandée.
static func available(ranked: bool, own_tier: int = 0,
		opponent_tier: int = 0) -> Array[int]:
	if not ranked:
		var socle: Array[int] = []
		socle.assign(SOCLE)
		return socle
	# Adversaire inconnu — file d'attente, salon vide : on montre sa propre
	# sélection. Elle ne peut que rétrécir à l'arrivée de l'autre, jamais
	# s'élargir, donc rien de ce qui est annoncé ici ne sera repris à tort.
	if opponent_tier <= 0:
		return for_tier(own_tier)
	return mirrored(own_tier, opponent_tier)

## Une arme est-elle jouable dans ce contexte ? Les armes écartées restent
## visibles et grisées — un joueur doit voir ce qu'il possède même quand il ne
## peut pas s'en servir.
static func is_available(weapon_index: int, ranked: bool, own_tier: int = 0,
		opponent_tier: int = 0) -> bool:
	return weapon_index in available(ranked, own_tier, opponent_tier)

## Pourquoi une arme est indisponible, en langage joueur — ou chaîne vide si elle
## l'est. L'interface doit pouvoir répondre « pourquoi ? » sans reconstruire le
## raisonnement, sous peine de deux explications qui divergent.
static func reason_for(weapon_index: int, ranked: bool, own_tier: int = 0,
		opponent_tier: int = 0, opponent_name: String = "") -> String:
	if is_available(weapon_index, ranked, own_tier, opponent_tier):
		return ""
	if not ranked:
		return "Cette arme n'est pas disponible dans ce mode."
	if opponent_tier > 0 and opponent_tier < maxi(own_tier, 1):
		var qui := opponent_name if not opponent_name.is_empty() else "votre adversaire"
		return "Arsenal aligné sur %s, moins bien classé que vous." % qui
	return "Cette arme se mérite à un autre rang."
