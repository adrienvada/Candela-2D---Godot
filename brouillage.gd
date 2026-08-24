## Le BROUILLAGE — ce que l'éblouissement retire à la LECTURE de l'adversaire.
##
## Un fichier sans dépendance, comme `vision.gd` et `eblouissement.gd`, et pour
## la même raison : `game_state.gd` nomme des autoloads, donc ne compile pas en
## mode `--script`, et une suite qui le charge annonce « tous les tests passent »
## sur des appels morts (piège consigné le 2026-08-18).
##
## ## La question à laquelle ce fichier répond
##
## L'éblouissement coûte aujourd'hui deux choses, et toutes deux au CONTRÔLE :
## la vitesse de déplacement (`×0,4` à saturation) et la vivacité de visée
## (`×0,4` sur le `lerp_angle`). Il ne coûte **rien à l'information** : la
## silhouette de celui qui braque sa torche reste aussi nette et aussi bien
## placée qu'avant. On vise donc toujours juste, seulement plus lentement.
##
## Demande d'Adrien (2026-08-25) : **que l'éblouissement rende plus difficile de
## VISER celui qui éblouit** — qu'il « floute » ou « brouille » sa position.
##
## ## Ce que ce fichier fait, et ce qu'il ne fait pas
##
## Il produit des **perturbations de rendu**, jamais des perturbations de
## simulation. La position vraie ne bouge pas, les balles partent où le canon
## regarde, l'hôte reste seul arbitre. Le brouillage ne touche qu'à ce que
## l'écran de la victime MONTRE. C'est la seule forme acceptable dans un jeu qui
## se veut « honnête en compétition » : dégrader la lecture est un coût de
## perception, déplacer une hitbox serait un mensonge.
##
## ## Les deux invariants, et ils sont éprouvés par `tools/test_brouillage.gd`
##
## 1. **À éblouissement nul, tout mode est l'identité.** Pas « presque » :
##    exactement. Un brouillage résiduel à 0 rendrait le jeu illisible au repos,
##    et surtout il ne se verrait jamais dans un relevé — c'est la signature du
##    défaut de 2026-08-18, une mécanique qui agit là où personne ne la regarde.
## 2. **La vérité reste RECOUVRABLE.** Le barycentre des fantômes est la position
##    vraie ; la moyenne temporelle de la dérive est nulle. Un joueur qui vise le
##    milieu, ou qui prend le temps de moyenner, retrouve sa cible. Un brouillage
##    dont la moyenne mentirait serait un désavantage sans plafond de compétence,
##    c'est-à-dire de la chance déguisée en mécanique.
extends RefCounted

## Les cinq façons de brouiller, plus l'absence — l'absence est un mode à part
## entière parce que c'est la référence contre laquelle les autres se jugent.
enum Mode {
	AUCUN,        ## Rien. L'état actuel du jeu, et le témoin du banc.
	HALO,         ## Le voile blanc se concentre autour de la source.
	DIPLOPIE,     ## La silhouette se dédouble ; le milieu est la vérité.
	TREMBLEMENT,  ## La silhouette dérive continûment autour de sa position.
	REMANENCE,    ## On voit où l'adversaire ÉTAIT, pas où il est.
	CONTRASTE,    ## La silhouette s'efface jusqu'à disparaître.
	LAMPE,        ## Les deux : le corps disparaît, sa lampe reste. **Choix d'Adrien.**
}

## Les libellés, pour un banc et pour un menu d'options. Ici plutôt qu'ailleurs :
## un mode ajouté sans son nom se repère au premier affichage.
const NOMS := {
	Mode.AUCUN: "aucun",
	Mode.HALO: "halo",
	Mode.DIPLOPIE: "diplopie",
	Mode.TREMBLEMENT: "tremblement",
	Mode.REMANENCE: "rémanence",
	Mode.CONTRASTE: "contraste",
	Mode.LAMPE: "lampe (contraste + halo)",
}

# --------------------------------------------------------------------------
# Les réglages « à saturation » — ce que chaque mode vaut à `dazzle = 1` et
# `force = 1`. Tous sont linéaires en `dazzle` : la mécanique amont
# (`Eblouissement.plafond_pour`) porte déjà toute la courbure du modèle, et en
# rajouter ici rendrait deux réglages responsables de la même sensation.
# --------------------------------------------------------------------------

## Rayon du halo à saturation, en pixels d'ÉCRAN (le seul mode qui ne travaille
## pas en unités de monde : il vit sur le voile, au-dessus des deux vues).
## 260 px sur une demi-fenêtre de 640 : de quoi avaler la silhouette et ses
## alentours sans blanchir le quart de l'écran.
const RAYON_HALO := 260.0

## Opacité au centre du halo, à saturation. Volontairement sous 1,0 : à 1,0 le
## halo devient un disque plein, et un disque plein DÉSIGNE l'adversaire au lieu
## de le cacher — le piège de ce mode, et la première chose à regarder au banc.
const INTENSITE_HALO := 0.85

## Écart entre chaque fantôme et la position vraie, à saturation, en pixels de
## monde. 30 px pour un joueur de 18 px de rayon : les copies se touchent
## presque, elles ne s'éparpillent pas. Au-delà on ne lit plus un dédoublement,
## on lit deux adversaires.
const RAYON_DIPLOPIE := 30.0

## Tours par seconde de la figure de diplopie. Lente à dessein : le dédoublement
## doit respirer, pas tourner — une rotation rapide se lit comme un effet de
## particules, et le milieu devient impossible à tenir à l'œil.
const ROTATION_DIPLOPIE := 0.11

## Amplitude de la dérive à saturation, en pixels de monde. 34 px, soit un peu
## moins de deux rayons de joueur : la silhouette sort de sa propre empreinte,
## donc viser au jugé ne suffit plus, mais elle ne quitte jamais la flaque de
## lumière où on l'a trouvée.
const AMPLITUDE_DERIVE := 34.0

## Les deux fréquences de la dérive, en hertz. Deux et pas une : une sinusoïde
## seule est un balancier, et un balancier s'anticipe en trois secondes. Le
## rapport est volontairement bancal (0,45 contre 1,15) pour que la figure ne se
## referme pas avant vingt secondes, là où l'effet en dure moins de deux.
##
## ⚠️ **Elles valaient 1,0 et 2,7, et c'est la première suite qui l'a rattrapé :
## la silhouette dérivait à 322 px/s, soit plus vite qu'un joueur qui COURT
## (520 px/s en sprint, 260 en marche).** Deux conséquences, et la seconde est
## celle qui compte :
##
## - ça ne se lisait pas comme une dérive mais comme une **vibration**, c'est-
##   à-dire comme un défaut d'affichage ;
## - et une vibration **cache moins bien qu'une dérive**. L'œil intègre ce qui
##   tremble vite : la moyenne perçue redevient la position vraie, et le
##   brouillage s'annule tout seul au moment où on le regarde. C'est l'inverse
##   du but. Une dérive lente, elle, tient son mensonge assez longtemps pour
##   qu'on tire dessus.
##
## Le plafond est donc physique et non esthétique : `test_brouillage` exige que
## la dérive ne dépasse jamais la vitesse de MARCHE. Ce qui se déplace comme un
## joueur se lit comme un joueur.
const DERIVE_HZ_LENTE := 0.45
const DERIVE_HZ_RAPIDE := 1.15

## Part de la composante rapide dans la dérive. 0,3 : elle donne le grain, la
## lente donne le déplacement.
const DERIVE_PART_RAPIDE := 0.3

## Retard de rémanence à saturation, en secondes. 0,18 s — à 520 px/s en sprint,
## 94 px d'avance à prendre, soit cinq rayons de joueur.
##
## ⚠️ **C'est le seul mode dont le coût dépend de ce que fait CELUI QU'ON VISE.**
## Un adversaire immobile n'est pas brouillé du tout ; un adversaire qui court
## l'est deux fois plus qu'un autre. À juger au banc : c'est peut-être la bonne
## mécanique (bouger sous sa propre torche devient payant), ou la mauvaise
## (allumer et se figer devient la seule ligne de jeu).
const RETARD_REMANENCE := 0.18

## Ce qu'il reste d'opacité à la silhouette à saturation : **zéro**. L'adversaire
## devient rigoureusement invisible.
##
## **Arbitré par Adrien au banc, le 2026-08-25** : « j'aime beaucoup [le
## contraste] mais il faut que ça puisse atteindre 100 % d'invisibilité ». La
## valeur était 0,18 — un reste de silhouette, choisi par prudence.
##
## ⚠️ **Ce zéro serait dangereux seul, et il ne l'est pas parce qu'il ne vient
## jamais seul.** Une disparition pure retire TOUTE information : plus rien ne
## dit où viser, et le plafond de compétence tombe avec. C'est l'objection que
## ce fichier portait contre le mode `CONTRASTE` poussé à bout — et **le mix
## demandé par Adrien y répond exactement** : le halo de `Mode.LAMPE` reste
## centré sur la position vraie. Le corps disparaît, sa lampe reste. On ne perd
## pas la cible, on perd sa NETTETÉ — ce qui était la demande depuis le début.
##
## **La conséquence à tenir : `Mode.CONTRASTE` seul n'est plus jouable en
## production, il n'est plus qu'un témoin de banc.** Le retenir sans halo
## rendrait l'adversaire introuvable à saturation.
##
## ⚠️ Il y avait ici un second réglage, `MELANGE_CONTRASTE`, retiré au premier
## rendu. Son idée : mêler la couleur de la silhouette à celle du voile. Le
## shader ennemi (`player_enemy_light.gdshader`) plafonne `LIGHT` à `COLOR.rgb`,
## donc éclaircir la couleur **relève le plafond** et fait BRILLER la silhouette
## au lieu de la fondre. Le réglage faisait le contraire de son nom, et rien ne
## l'aurait dit.
const ALPHA_CONTRASTE := 0.0

## Le halo, en pixels d'écran et en opacité. `centre` reste à l'appelant : c'est
## lui qui sait projeter une position de monde dans SA vue, et ce fichier ne
## connaît ni caméra ni viewport.
static func halo(dazzle: float, force: float = 1.0) -> Dictionary:
	var t := _dose(dazzle, force)
	return {
		"rayon": RAYON_HALO * t,
		"intensite": INTENSITE_HALO * t,
	}

## Les décalages des fantômes, en pixels de monde, autour de la position vraie.
##
## **Rend un tableau VIDE à éblouissement nul**, et c'est un contrat : vide veut
## dire « dessine la silhouette normalement, une seule fois, à sa place ». Rendre
## un décalage nul obligerait l'appelant à distinguer « une copie au centre » de
## « pas de copie », et cette distinction-là finit toujours par se perdre.
##
## Le barycentre de N points également répartis sur un cercle est le centre du
## cercle, exactement — c'est ce qui rend la vérité recouvrable, et c'est pour
## cette propriété que la figure est un cercle régulier et non un semis.
static func fantomes(dazzle: float, force: float = 1.0, temps: float = 0.0,
		copies: int = 2) -> PackedVector2Array:
	var sortie := PackedVector2Array()
	var t := _dose(dazzle, force)
	if t <= 0.0 or copies < 2:
		return sortie
	var rayon := RAYON_DIPLOPIE * t
	var depart := temps * ROTATION_DIPLOPIE * TAU
	for i in copies:
		sortie.append(Vector2.RIGHT.rotated(depart + TAU * float(i) / float(copies)) * rayon)
	return sortie

## La dérive continue, en pixels de monde.
##
## Somme de sinus et non `FastNoiseLite` : la dérive doit être **déterministe et
## sans état**, pour que l'hôte et le client en tirent la même figure d'un même
## instant sans rien se transmettre, et pour qu'une suite headless puisse
## l'éprouver sans moteur. `graine` déphase la figure — deux joueurs éblouis en
## même temps ne doivent pas trembler à l'unisson, ce qui se lirait comme un
## défaut d'affichage plutôt que comme deux paires d'yeux.
##
## Le vecteur est borné par `limit_length` : l'amplitude annoncée est la vraie,
## pas celle d'un axe. Sans elle, la diagonale vaudrait √2 fois le réglage, et
## c'est exactement le genre d'écart qu'on découvre en mesurant six mois plus
## tard.
static func derive(dazzle: float, force: float = 1.0, temps: float = 0.0,
		graine: float = 0.0) -> Vector2:
	var t := _dose(dazzle, force)
	if t <= 0.0:
		return Vector2.ZERO
	var lent := temps * TAU * DERIVE_HZ_LENTE
	var rapide := temps * TAU * DERIVE_HZ_RAPIDE
	var part := DERIVE_PART_RAPIDE
	var x := sin(lent + graine) * (1.0 - part) + sin(rapide + graine * 1.7 + 1.3) * part
	var y := cos(lent * 0.83 + graine * 2.3) * (1.0 - part) + cos(rapide * 1.17 + graine * 0.9 + 4.2) * part
	return Vector2(x, y).limit_length(1.0) * (AMPLITUDE_DERIVE * t)

## Le retard de rémanence, en secondes. L'appelant garde l'historique : ce
## fichier ne peut pas, et ne doit pas — un tampon dimensionné en nombre
## d'images a déjà tronqué la killcam sur une machine à 492 fps, et la leçon vaut
## pour tout ce qui mémorise ici.
static func retard(dazzle: float, force: float = 1.0) -> float:
	return RETARD_REMANENCE * _dose(dazzle, force)

## La perte de contraste : ce qu'il reste d'opacité à la silhouette, entre 1 (on
## la voit) et `ALPHA_CONTRASTE` (elle se dissout dans le voile).
static func opacite(dazzle: float, force: float = 1.0) -> float:
	return lerpf(1.0, ALPHA_CONTRASTE, _dose(dazzle, force))

## La dose commune : l'éblouissement multiplié par le réglage de force, ramené
## dans [0,1].
##
## **Le `clampf` sur `dazzle` avant la multiplication n'est pas une coquetterie.**
## `apply_dazzle` laisse le pic de flash dépasser le plafond de la torche — c'est
## le modèle, et c'est voulu — mais un `dazzle` au-dessus de 1 sortirait ici des
## amplitudes que rien n'a jamais jugées.
static func _dose(dazzle: float, force: float) -> float:
	return clampf(clampf(dazzle, 0.0, 1.0) * maxf(force, 0.0), 0.0, 1.0)
