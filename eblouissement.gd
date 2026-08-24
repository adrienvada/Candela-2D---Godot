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

## 0,375 s pour retrouver ses yeux depuis la saturation complète — **quatre fois
## plus rapide qu'avant, sur le jugement d'Adrien manette en main** (2026-08-24).
##
## ⚠️ **Ce réglage a longtemps été l'inverse, et pour une raison écrite :** la
## descente valait 1,5 s, *« volontairement plus lente que la montée : c'est ce
## décalage qui fait de l'éblouissement une ouverture exploitable, et non une
## gêne qui passe avant qu'on en profite »*. Le raisonnement se tenait. **Il n'a
## simplement jamais été éprouvé** — la mécanique n'a fonctionné pour de vrai
## que le 2026-08-24, et personne ne l'avait jouée avant ce soir-là. À l'essai,
## une seconde et demie d'aveuglement ne se lit pas comme une ouverture pour
## l'adversaire : elle se lit comme une perte de contrôle sur son propre
## personnage.
##
## **La descente est donc désormais PLUS RAPIDE que la montée** (2,67/s contre
## 1,25/s), ce qu'un test interdisait explicitement. Le contrôle a été retourné,
## pas supprimé : sa raison reste lisible dans `test_eblouissement`, elle ne
## s'applique simplement plus.
##
## **Ce que ça coûte, et qu'il faut savoir avant de le rejuger :** le flash de
## tir se résorbe maintenant en **0,22 s** au lieu de 0,9. Le pic reste le même
## (`PIC_FLASH`), c'est sa durée qui fond. Un premier tir manqué à bout portant
## reste une ouverture, mais une ouverture **brève** — si elle devient trop
## brève pour être exploitée, c'est `PIC_FLASH` qu'il faut monter, pas la
## descente qu'il faut ralentir : on a mesuré que la lenteur, elle, se ressent
## comme une punition.
const DESCENTE_PAR_S := 1.0 / 0.375

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

## L'exposant qui courbe la lumière reçue avant qu'elle ne devienne une
## pénalité. Arbitré par Adrien le 2026-08-24, après relevé à l'écran.
##
## `Vision.intensite_recue` recopie terme pour terme la formule de la texture
## de torche : sa décroissance est **linéaire** jusqu'à zéro au bout du
## faisceau. C'est exact à l'alpha près, et faux à l'œil — sur du noir absolu,
## 5 % de lumière se lit encore comme « éclairé ». Mesuré en jeu : à 95 % de la
## portée du pistolet, un joueur se tenait dans une plaque de lumière
## franchement visible et ne prenait que **0,050**, soit un voile invisible. Le
## dernier tiers du faisceau éblouissait bien moins qu'il n'éclairait.
##
## 0,5 — la racine carrée — plutôt que le tiers de la vraie courbe de clarté
## perceptuelle : le tiers porte le bout du faisceau à 0,37, c'est-à-dire qu'on
## serait notablement ébloui à l'extrême limite de la flaque. Cela déplacerait
## la couture au lieu de la coudre. La racine rend 0,22 là-bas, 0,71 à
## mi-faisceau, 0,93 à bout portant.
##
## **Les deux bouts ne bougent pas**, et c'est ce qui a décidé de la forme :
## hors du faisceau on ne prend toujours rien, une lumière saturante sature
## toujours. Un exposant ne redresse que le milieu ; un seuil ou un décalage
## auraient cassé l'une des deux bornes — et celle du bas est la mécanique même
## du jeu, puisqu'elle dit « ici, on ne te voit pas ».
const COURBURE_LUMIERE := 0.5

## Ce qu'une quantité de lumière reçue COÛTE aux yeux, entre 0 et 1.
##
## Séparé de `Vision.intensite_recue` à dessein. La géométrie dit combien de
## lumière arrive, et elle doit rester le miroir exact de la texture — deux
## formules pour un même faisceau finiraient par diverger sans que rien ne le
## dise, et c'est écrit dans `vision.gd`. Ce fichier-ci dit ce que cette
## lumière fait à celui qui la reçoit. Les mélanger rendrait le RENDU
## tributaire d'un réglage d'équilibre.
static func plafond_pour(lumiere: float) -> float:
	return pow(clampf(lumiere, 0.0, 1.0), COURBURE_LUMIERE)

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
