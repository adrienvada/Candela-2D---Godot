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
## ## Un déblocage qui S'ACCUMULE — décision d'Adrien, 2026-09-09
##
## Un joueur Lanterne a **quatre classes** : la sienne et les trois d'en dessous.
## Chaque entrée de la table dit ce qu'un rang **ajoute**, et `for_tier()` cumule
## tout ce qui précède.
##
## ⚠️ **Ce paragraphe disait exactement le contraire jusqu'au 2026-09-09**, et le
## contrôle qui le gardait était écrit « pour qu'une relecture ne le corrige
## pas ». Il a bien fait son travail : ce n'est pas une relecture qui l'a changé,
## c'est le propriétaire du jeu. Le garde-fou existe pour empêcher une
## *correction* non demandée, jamais pour opposer un veto à une décision.
##
## Ce que ça change ailleurs, et qui vaut d'être su : la règle du miroir devient
## **cohérente par construction**. Elle alignait déjà les deux camps sur le moins
## bien classé ; avec un déblocage cumulatif, la sélection du moins bien classé
## est un **sous-ensemble** de celle de l'autre — le mieux classé ne se voit donc
## plus retirer une classe pour s'en voir prêter une qu'il n'a jamais jouée.
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
## Les six classes du chantier CLASSES. Les index 0 à 3 gardent EXACTEMENT le
## sens qu'ils avaient : le catalogue de `game_state` les a conservés à leur
## place précisément pour que rien de ce qui circulait ne change de sens.
const FUMISTE := 4
const INCENDIAIRE := 5
const SENTINELLE := 6
const OCCULTEUR := 7
const ALLUMEUR := 8
const SPECTRE := 9

## Ce que tout le monde peut prendre hors compétitif, sans rien avoir mérité.
##
## ⚠️ **Il vaut LES DIX depuis le 2026-09-09, et ce n'est pas un élargissement.**
## Le socle a toujours voulu dire « tout ce qui existe » : il comptait quatre
## entrées parce que le jeu comptait quatre armes, pas parce qu'on en retenait
## six. Le laisser à quatre pendant que le catalogue en compte dix aurait
## transformé une NON-restriction en restriction, en silence — et l'écran de
## sélection aurait montré six classes grisées jusque dans l'entraînement, c'est-
## à-dire précisément là où l'on va essayer une classe.
##
## Ce qui se mérite reste ce qui se mérite : la table compétitive attribue une
## classe par rang, et elle, elle ne change pas.
const SOCLE: Array[int] = [
	PISTOLET, FUSIL, POMPE, ARBALETE,
	FUMISTE, INCENDIAIRE, SENTINELLE, OCCULTEUR, ALLUMEUR, SPECTRE,
]

## Ce que chaque catégorie de rang **AJOUTE**, index 0 = Aveugle, première des
## dix catégories de l'échelle (`RANK_TIERS` dans `elo.ts`).
##
## ⚠️ **Ce n'est plus « la sélection d'un rang », c'est son APPORT.** La sélection
## se lit par `for_tier()`, qui cumule ; lire cette table directement rendrait
## une seule classe là où le joueur en a plusieurs.
##
## ⚠️ **L'échelle des rangs EST une échelle de lumière**, et la table la suit
## littéralement — décision d'Adrien du 2026-09-09, à partir de deux ancrages :
## le rang 1 est celui du pistolet, et **Brasier est le pyrotechnicien**. Le
## second dit tout du principe : Brasier n'est pas « le sixième palier de
## puissance », c'est *un feu*, et on y met celui qui fait du feu.
##
## Les trois derniers paliers basculent en OPPOSITION plutôt qu'en
## correspondance, et c'est le renversement que l'échelle appelait : au sommet de
## l'échelle de la lumière on trouve **la seule classe qui n'en émet aucune** —
## le Spectre, zéro fusée, zéro flash, arme silencieuse.
##
## ⚠️ **L'ordre n'est PAS une échelle de difficulté**, et ça reste vrai malgré le
## cumul : le Braconnier (0,60 s de root) est au rang 4, l'Allumeur (0,20 s) au
## rang 9. Ce qui croît avec le rang est le **choix**, pas la puissance — un
## Zénith a neuf classes de plus qu'un Aveugle, pas une classe plus forte.
const COMPETITIF: Array[Array] = [
	[PISTOLET],     # 1 — Aveugle  · Le Parasite     — il aveugle l'autre
	[FUMISTE],      # 2 — Braise   · Le Fumiste      — une braise fume
	[FUSIL],        # 3 — Bougie   · L'Illusionniste — la bougie fait danser les ombres
	[ARBALETE],     # 4 — Lanterne · Le Braconnier   — on appâte à la lampe
	[POMPE],        # 5 — Torche   · Le Terrassier   — la torche la plus large du jeu
	[INCENDIAIRE],  # 6 — Brasier  · L'Incendiaire   — le feu au rang du feu
	[SENTINELLE],   # 7 — Phare    · La Sentinelle   — un phare veille, et porte loin
	[OCCULTEUR],    # 8 — Aurore   · L'Occulteur     — à l'aurore répond l'occultation
	[ALLUMEUR],     # 9 — Zénith   · L'Allumeur      — la lumière maximale, sans ombre
	[SPECTRE],      # 10 — Candela · Le Spectre      — celui qui n'émet aucune lumière
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
	var jusqua := clampi(tier_index, 1, COMPETITIF.size())
	var selection: Array[int] = []
	# ⚠️ **Cumulatif** — décision d'Adrien, 2026-09-09 : « au premier rang on peut
	# jouer en pistolet, au deuxième rang pistolet et fusil, etc. » Chaque entrée
	# dit ce que son rang AJOUTE ; la sélection est tout ce qui précède.
	#
	# L'ordre est celui de l'échelle de LUMIÈRE, décidé le même jour et inchangé :
	# le rang 2 ajoute donc le Fumiste et non le fusil, qui arrive au rang 3.
	for palier in jusqua:
		for idx in COMPETITIF[palier]:
			if not idx in selection:
				selection.append(idx)
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
## ⚠️ **Depuis le déblocage cumulatif, elle ne RETIRE plus qu'elle ne prête.** La
## sélection du moins bien classé est un sous-ensemble de celle de l'autre : le
## mieux classé perd des options, il n'en reçoit jamais une qu'il n'a pas
## débloquée. Ce n'était pas garanti avant — un Lanterne et un Torche
## échangeaient deux classes disjointes.
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
