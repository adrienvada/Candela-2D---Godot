## L'éblouissement — combien de lumière un joueur prend dans les yeux, et
## comment il s'en remet.
##
## Un fichier sans dépendance, comme `vision.gd` et pour la même raison :
## `game_state.gd` nomme des autoloads, donc ne compile pas en mode `--script`,
## et une suite qui le charge annonce « tous les tests passent » sur des appels
## morts (piège consigné le 2026-08-18).
##
## ## Le défaut que ce fichier répare (2026-08-18)
##
## L'éblouissement existait depuis le début et **n'a jamais rien fait**. La
## montée valait `+0,5/s` pendant que la descente, écrite ailleurs et
## **inconditionnelle**, valait `−2,0/s` : sous un faisceau tenu en pleine face,
## le bilan était NÉGATIF. La valeur ne dépassait jamais ce qu'une seule image
## avait le temps d'ajouter avant d'être rabotée — 0,008 à 60 fps, 0,001 à
## 500 fps (les images ne sont pas plafonnées) — soit un voile blanc à 0,6 %
## d'opacité et une pénalité de vitesse de 0,5 %.
##
## Deux `_process` se partageaient la même variable sans jamais s'additionner.
## D'où la règle qui suit : **l'intégration se fait en un seul endroit**,
## `game_state`, pour les deux joueurs et dans un ordre décidé.
##
## ## Le modèle : la lumière reçue est un PLAFOND, pas une addition
##
## Une torche lointaine ou rasante ne peut éblouir qu'un peu, si longtemps
## qu'elle insiste ; une torche à bout portant dans l'axe sature. On monte vers
## ce plafond à `MONTEE_PAR_S`, on en redescend à `DESCENTE_PAR_S` dès qu'il
## baisse. Trois vertus, et c'est pour elles que le modèle a été choisi :
##
## 1. La valeur ne peut pas dériver — pas d'intégrale qui s'emballe si le rayon
##    reste accroché une seconde de trop.
## 2. Le **pic du flash de tir** peut passer AU-DESSUS du plafond puis se
##    résorber : c'est exactement ce qu'on attend d'un flash, et ça tombe tout
##    seul du modèle au lieu d'être un cas particulier.
## 3. L'intégration est linéaire des deux côtés, donc **indépendante de la
##    cadence** : mille pas de 1 ms donnent la valeur d'un pas d'une seconde.
##    Sur un jeu dont les images ne sont pas plafonnées, ça ne se négocie pas —
##    un tampon dimensionné en nombre d'images a déjà tronqué la killcam.
extends RefCounted

## 0,8 s pour saturer sous un faisceau à bout portant, dans l'axe. Réglage de
## jeu, pas constante technique : Adrien a demandé « rapide, quasi immédiat »
## (2026-08-18). Plus court rendrait la torche punitive au balayage — on
## éblouirait en passant, sans avoir rien visé.
const MONTEE_PAR_S := 1.25

## 1,5 s pour retrouver ses yeux depuis la saturation complète. Volontairement
## plus lente que la montée : c'est ce décalage qui fait de l'éblouissement une
## ouverture exploitable, et non une gêne qui passe avant qu'on en profite.
const DESCENTE_PAR_S := 1.0 / 1.5

## Ce qu'un tir jette dans les yeux d'en face, à bout portant et à pleine
## intensité d'arme. Le tir est le geste le plus lumineux du jeu et il ne
## coûtait rien à celui qui le déclenche (décision du 2026-08-18, avec Adrien).
## 0,6 : la victime perd un tiers de sa vitesse et de sa vivacité de visée
## pendant une seconde — assez pour que le duel bascule, pas assez pour qu'un
## premier tir manqué vaille exécution.
const PIC_FLASH := 0.6

## Portée du flash de tir, en pixels. Au-delà, un coup de feu se voit mais
## n'éblouit plus. Choisie du même ordre que la portée d'une torche moyenne
## (~590 px) : ce qui aveugle doit rester ce qui est proche.
const PORTEE_FLASH := 600.0

## Une image d'éblouissement. `plafond` est la lumière reçue à cet instant
## (0 = noir complet, 1 = faisceau saturant dans les yeux).
##
## Aucune allocation, aucun état caché : la valeur entre et sort, ce qui rend le
## modèle vérifiable sans moteur, sans joueur et sans réseau.
static func integrer(valeur: float, plafond: float, delta: float) -> float:
	var cible := clampf(plafond, 0.0, 1.0)
	if valeur < cible:
		return minf(cible, valeur + MONTEE_PAR_S * delta)
	return maxf(cible, valeur - DESCENTE_PAR_S * delta)

## Le pic instantané d'un flash de tir vu à `distance`, pondéré par l'éclat de
## l'arme (`WeaponData.muzzle_flash_intensity`).
##
## L'arbalète porte 0,1 : elle est l'arme discrète, son carreau ne révèle
## presque rien — il serait incohérent qu'elle aveugle comme le fusil. Le
## réglage existait déjà pour le rendu, il sert maintenant deux fois, et une
## arme silencieuse le reste par construction.
static func pic_de_flash(distance: float, eclat_arme: float) -> float:
	if distance >= PORTEE_FLASH:
		return 0.0
	var proximite := 1.0 - maxf(distance, 0.0) / PORTEE_FLASH
	return PIC_FLASH * proximite * clampf(eclat_arme, 0.0, 1.0)
