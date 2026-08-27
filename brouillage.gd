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

## La vitesse d'un joueur, en pixels par seconde. **Recopiée** de `player.gd`
## (`@export var speed`) et non importée : ce fichier n'a aucune dépendance, et
## c'est précisément ce qui lui permet de tourner sous `--script` là où
## `game_state.gd` ne compile pas. Une recopie, donc — mais TENUE : la suite
## `test_brouillage` relit le littéral de `player.gd` et rougit si les deux
## divergent.
##
## ⚠️ **Sans ce lien, le nombre se périme en silence — et c'est arrivé.** Deux
## réglages de ce fichier se justifiaient par une vitesse que le jeu a cessé
## d'avoir. Aucune suite ne pouvait le voir : une suite lit des nombres, pas les
## raisons qu'on leur a données. **Une vitesse citée dans un commentaire ne
## vieillit avec rien ; une vitesse nommée dans le code vieillit avec le jeu.**
## C'est toute la différence, et elle a coûté la moitié de l'effet de
## `RETARD_REMANENCE` pendant une journée.
##
## Une seule allure, donc une seule constante : « marche » et « vitesse du
## joueur » sont le même nombre.
const VITESSE_MARCHE := 260.0

# --------------------------------------------------------------------------
# Les réglages « à saturation » — ce que chaque mode vaut à `dazzle = 1` et
# `force = 1`. Tous sont linéaires en `dazzle` : la mécanique amont
# (`Eblouissement.plafond_pour`) porte déjà toute la courbure du modèle, et en
# rajouter ici rendrait deux réglages responsables de la même sensation.
# --------------------------------------------------------------------------

## Rayon du halo à saturation, en pixels d'ÉCRAN (le seul réglage qui ne
## travaille pas en unités de monde : il vit au-dessus de la vue).
##
## **150 px, et non 260 : « le halo est trop gros, trop large » (Adrien, au
## banc, 2026-08-25).** Le premier chiffre avait été posé pour « avaler la
## silhouette et ses alentours » ; à l'essai il avale surtout l'écran.
const RAYON_HALO := 150.0

## Opacité au cœur du halo, à saturation. **0,7**, et la valeur a fait
## l'aller-retour en une soirée : 0,85 (posé), 1,0 (« plus intense en son
## centre »), 0,7 (« moins puissant »).
##
## **Les trois ne se contredisent pas, et ce sont le flou puis l'allongement qui
## les réconcilient.** Au premier essai le halo portait **seul** la charge de
## cacher l'émetteur : il fallait qu'il tape fort. Le flou lui en a retiré la
## moitié — celle qui concerne le faisceau —, et l'étirement a réglé le reste :
## un cœur étiré cache autant qu'un cœur vif sans désigner de centre. Un halo
## qui tape moins fort cache donc désormais autant, et il rend l'écran de
## nouveau lisible autour de lui.
##
## ⚠️ **Le motif qui tenait 0,85 sous 1,0 reste valable, mais ce n'est plus lui
## qui tient :** « à 1,0 le halo devient un disque plein, et un disque plein
## DÉSIGNE l'adversaire au lieu de le cacher ». Ce qui empêche le disque plein
## est maintenant `NETTETE_HALO` (la chute creusée réduit la surface saturée à un
## noyau) et `ALLONGEMENT_HALO` (le noyau est une traînée, pas un point).
## **Défaire l'un des deux sans redescendre l'intensité ramènerait le halo qui
## désigne**, qui est le défaut qu'Adrien a relevé sur capture.
const INTENSITE_HALO := 0.7

## L'exposant qui creuse le halo : `alpha(r) = (1 − r) ^ NETTETE_HALO`.
##
## « Plus intense en son centre et diminue plus rapidement en son bord »
## (Adrien, 2026-08-25). À 1,0 la chute est linéaire — une pente douce du centre
## au bord, ce qui donne une tache molle et large. À 2,5 : 0,55 au cinquième du
## rayon, 0,18 à mi-rayon, 0,02 aux quatre cinquièmes.
##
## **Les deux bornes ne bougent pas**, et c'est ce qui a décidé de la forme —
## même raisonnement que `Eblouissement.COURBURE_LUMIERE` : plein au centre,
## rigoureusement nul au bord, quel que soit l'exposant. Un exposant ne redresse
## que le milieu ; un seuil ou un décalage auraient cassé l'une des deux bornes,
## et celle du bord est la seule chose qui empêche le halo d'avoir un CONTOUR.
## Un halo à contour net est une forme de plus à lire, donc un repère de plus.
const NETTETE_HALO := 2.5

## Le halo s'étire lui aussi dans l'axe du faisceau : `RAYON_HALO` est son
## demi-axe EN TRAVERS, celui-ci son rapport longueur/largeur.
##
## ⚠️ **C'est un défaut de forme, relevé par Adrien sur capture (2026-08-25) :**
## « le cercle est toujours visible grâce à la luminosité centrale du halo ».
## Un halo rond est une **forme**, donc un repère — et son cœur lumineux marque
## son centre, c'est-à-dire très exactement le point qu'on cherche à rendre
## introuvable. Plus le cœur est net, mieux il le marque : la netteté demandée
## au premier essai travaillait CONTRE le but, sans que ni lui ni moi ne le
## voyions.
##
## **La correction n'est pas d'adoucir le cœur** — ce serait défaire la demande
## précédente — mais de l'ÉTIRER. Le cœur devient une traînée le long du
## faisceau au lieu d'un point : il reste vif, il ne désigne plus. C'est aussi
## ce qu'on voit d'une source dirigée dans la vraie vie, où l'éblouissement
## bave dans l'axe de la lampe.
const ALLONGEMENT_HALO := 2.4

## De combien le halo est poussé vers la victime, en fraction de son demi-grand
## axe — même raison que `AVANCE_FLOU` : derrière l'émetteur il n'y a pas de
## faisceau, et un halo centré sur lui recentre le regard sur lui.
const AVANCE_HALO := 0.3

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
## la silhouette dérivait à 322 px/s, soit plus vite qu'un joueur ne peut se
## déplacer** (`VITESSE_MARCHE`, 260 px/s). Deux conséquences, et la seconde est
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

## L'avance que la rémanence fait prendre à la silhouette à saturation, en
## pixels de monde. **94 px, soit cinq rayons de joueur** : on ne vise plus le
## corps qu'on voit, on vise cinq rayons devant lui.
##
## C'est ÇA, le réglage. Le retard en secondes n'en est que la conversion — voir
## `RETARD_REMANENCE` juste dessous, et l'avertissement qui l'accompagne.
const AVANCE_REMANENCE := 94.0

## Le retard de rémanence à saturation, en secondes. **Dérivé, jamais écrit** :
## une avance en pixels ne devient un temps qu'en passant par une vitesse.
##
## ⚠️ **Il valait 0,18 s, écrit à la main, et sa justification invoquait une
## vitesse de 520 px/s.** Cette vitesse a disparu du jeu — et les mêmes 0,18 s
## n'achetaient plus que 47 px, la moitié de ce pour quoi elles avaient été
## posées. Le nombre n'avait pas bougé ; c'est le monde autour de lui qui avait
## changé, et rien n'a rougi. **Un réglage dérivé d'une vitesse doit nommer cette vitesse dans
## le code.** Écrite dans le commentaire, elle ne tient rien : elle ne fait que
## raconter, au présent, un présent qui passe.
##
## ⚠️ **C'est le seul mode dont le coût dépend de ce que fait CELUI QU'ON VISE.**
## Un adversaire immobile n'est pas brouillé du tout, un adversaire qui se
## déplace l'est pleinement. **Et il n'y a qu'une façon de se déplacer** : le
## coût ne se module pas, il se déclenche — bouger ou ne pas bouger, rien entre
## les deux. À juger au banc : c'est peut-être la bonne mécanique (bouger sous
## sa propre torche devient payant), ou la mauvaise (allumer et se figer devient
## la seule ligne de jeu).
const RETARD_REMANENCE := AVANCE_REMANENCE / VITESSE_MARCHE

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
## ⚠️ **« Centré sur la position vraie » n'est plus exact depuis
## `ALLONGEMENT_HALO`, et le repère a changé de nature.** Le halo est désormais
## une traînée couchée sur l'axe du faisceau et poussée vers la victime : son
## **barycentre n'est plus l'émetteur**. Ce qui reste vrai — et ce sur quoi
## repose tout le plafond de compétence de ce mode — c'est que **l'émetteur est
## à l'extrémité ARRIÈRE de la traînée**, celle qui s'éloigne de soi. On lit une
## forme au lieu d'un point.
##
## C'est plus difficile, et ce n'est pas un mensonge : la traînée décrit
## fidèlement où la lumière est. Mais la phrase « viser le centre du halo »
## était juste et ne l'est plus, et quelqu'un qui rejugerait ce mode sur elle se
## tromperait.
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

## L'exposant qui fait tomber la silhouette : `alpha = (1 − t) ^ COURBE_CONTRASTE`.
##
## « Il faudrait que le contraste diminue plus rapidement également » (Adrien,
## au banc, 2026-08-25). La chute était **linéaire** : à mi-éblouissement il
## restait la moitié de la silhouette, ce qui se lit encore très bien sur du
## noir. À 2,0 : 0,56 au quart, 0,25 à mi-chemin, 0,06 aux trois quarts —
## l'adversaire a disparu bien avant la saturation, qui n'est presque jamais
## atteinte en jeu (le plafond réel du pistolet à bout portant vaut 0,93).
##
## **C'est ce détail qui rend la demande nécessaire plutôt que cosmétique :**
## une chute linéaire réservait l'invisibilité à un cas de figure que le jeu ne
## produit qu'à bout portant dans l'axe. La courbe la rend atteignable dans le
## duel ordinaire.
##
## Mêmes deux bornes intactes qu'ailleurs : `alpha(0) = 1`, `alpha(1) = 0`.
## **3,4 depuis le second essai** — « il faudrait que la silhouette disparaisse
## encore davantage et plus rapidement » (Adrien, 2026-08-25). Elle valait 2,0,
## qui valait elle-même 1,0 (une droite) au premier jet.
##
## Ce que chaque passe a déplacé, à mi-éblouissement : **0,50 → 0,25 → 0,11**.
## Et aux trois quarts : 0,25 → 0,06 → 0,01. L'adversaire est donc désormais
## effacé bien avant que l'éblouissement ne sature — ce qui compte, puisque la
## saturation n'est presque jamais atteinte en jeu (plafond réel du pistolet à
## bout portant : 0,93).
##
## **La borne basse n'a jamais bougé et ne doit pas bouger** : hors faisceau on
## voit l'adversaire normalement. C'est la proposition même du jeu, et un
## exposant la préserve exactement là où un seuil la casserait.
const COURBE_CONTRASTE := 3.4

## Le rayon de la zone floutée à saturation, en pixels d'écran, et la force du
## flou en son centre.
##
## **Le cône trahit l'apex, et c'est le défaut qui décide de ce mode** (Adrien,
## 2026-08-25) : « il faudrait ajouter du flou dans la zone de l'émission de
## lumière, sinon le cône révèle où est le joueur ». Effacer le corps ne sert à
## rien tant que **deux arêtes qui convergent se prolongent à l'œil**.
##
## Le rayon est plus large que celui du halo — 210 contre 150 — et ce n'est pas
## un arrondi : le halo doit cacher un CORPS, le flou doit casser une
## CONVERGENCE, qui se lit bien au-delà du corps. Un flou plus étroit que le
## halo laisserait les arêtes redevenir nettes juste là où elles se rejoignent.
## ⚠️ **`RAYON_FLOU` est le demi-axe EN TRAVERS du faisceau, pas un rayon de
## disque.** La zone était un disque ; Adrien l'a jugée insuffisante au second
## essai (2026-08-25) : « il faudrait que le flou soit plus intense, et s'étale
## davantage en direction de l'ébloui, dans la direction du faisceau ».
##
## Le disque avait un défaut de forme, pas de taille : **la convergence des deux
## arêtes ne se lit pas autour de l'apex, elle se lit LE LONG du faisceau.** Un
## disque en gomme le sommet et laisse intactes les deux droites qui y mènent —
## il suffit alors de les prolonger de l'œil. L'ellipse suit le faisceau, donc
## elle brouille ce qui sert effectivement à viser.
const RAYON_FLOU := 190.0

## Le rapport longueur/largeur de l'ellipse, dans l'axe du faisceau. 2,6 : la
## zone s'étire vers celui qu'on éblouit, là où le cône s'ouvre et où ses arêtes
## sont les plus lisibles.
const ALLONGEMENT_FLOU := 2.6

## De combien l'ellipse est poussée VERS la victime, en fraction de son
## demi-grand axe. 0,4 — elle n'est pas centrée sur l'émetteur : derrière lui il
## n'y a pas de faisceau à brouiller, et flouter le vide ne coûte que des
## pixels. Ce décalage ne déplace jamais rien de ce qui est dessiné, il choisit
## seulement où la lecture est dégradée.
const AVANCE_FLOU := 0.4

const FORCE_FLOU := 1.0

## **Le rayon autour de SOI où le flou ne mord pas**, en pixels d'écran : plein
## effet au-delà de `EXCLUSION_LOIN`, rigoureusement nul en deçà de
## `EXCLUSION_PRES`.
##
## « Il ne faut pas que notre propre personnage devienne flou » (Adrien,
## 2026-08-25). La zone floue est poussée vers la victime ; à distance de duel
## ordinaire elle atteignait son propre personnage.
##
## **Et ce n'est pas qu'une gêne de lecture, c'est une décision actée du
## projet :** l'éblouissement doit coûter la lecture **du monde** — l'adversaire
## et sa lumière —, jamais celle de sa propre fiche. Se perdre soi-même est une
## punition de plus que ne rattrape aucune compétence. Le même raisonnement
## avait déjà fait passer le voile blanc SOUS le HUD.
##
## Le fondu entre les deux rayons n'est pas un ornement : un disque net
## d'image nette au milieu du flou serait **une forme de plus à lire**, donc un
## repère — exactement le défaut que le halo en traînée vient de corriger.
const EXCLUSION_PRES := 44.0
const EXCLUSION_LOIN := 104.0

## Le rayon du noyau de flou, en pixels d'écran : la QUANTITÉ de flou, distincte
## de la taille de la zone.
##
## **34 px, contre 24 au premier jet** — « il faudrait que le flou soit plus
## intense » (Adrien, 2026-08-25). La chute de contraste local mesurée dans la
## zone d'émission vaut −8,5 % à 8 px, −24,5 % à 24, −35,9 % à 40.
const NOYAU_FLOU := 34.0

## Le halo, en pixels d'écran et en opacité. `centre` reste à l'appelant : c'est
## lui qui sait projeter une position de monde dans SA vue, et ce fichier ne
## connaît ni caméra ni viewport.
##
## Les maxima sont des PARAMÈTRES et non des lectures directes des constantes,
## pour que le banc puisse les régler en direct sans recopier la formule. La
## production appelle sans rien passer et prend les valeurs actées ; le banc
## passe ses valeurs vives et imprime, en sortant, celles qu'il faudra
## transcrire ici. **Une seule formule, deux appelants** — c'est la règle que ce
## dépôt a payée trois fois pour l'apprendre.
static func halo(dazzle: float, force: float = GAIN,
		rayon_max: float = RAYON_HALO, intensite_max: float = INTENSITE_HALO) -> Dictionary:
	var t := _dose(dazzle, force)
	return {
		"rayon": rayon_max * t,
		"intensite": intensite_max * t,
	}

## Le profil radial du halo, échantillonné pour fabriquer son dégradé : plein au
## centre, nul au bord, creusé par `nettete`. `r` va de 0 (centre) à 1 (bord).
static func profil_halo(r: float, nettete: float = NETTETE_HALO) -> float:
	return pow(clampf(1.0 - clampf(r, 0.0, 1.0), 0.0, 1.0), maxf(nettete, 0.01))

## Le flou de la zone d'émission : rayon de la zone en pixels d'écran, et force
## du flou en son centre. Voir `RAYON_FLOU` — c'est ce qui empêche le cône de
## trahir son apex.
static func flou(dazzle: float, force: float = GAIN,
		rayon_max: float = RAYON_FLOU, force_max: float = FORCE_FLOU) -> Dictionary:
	var t := _dose(dazzle, force)
	return {
		"rayon": rayon_max * t,
		"force": force_max * t,
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
static func fantomes(dazzle: float, force: float = GAIN, temps: float = 0.0,
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
static func derive(dazzle: float, force: float = GAIN, temps: float = 0.0,
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
static func retard(dazzle: float, force: float = GAIN) -> float:
	return RETARD_REMANENCE * _dose(dazzle, force)

## La perte de contraste : ce qu'il reste d'opacité à la silhouette, entre 1 (on
## la voit) et `ALPHA_CONTRASTE` (elle se dissout dans le voile).
## Le dégradé radial du halo, prêt à poser.
##
## Vit ici et non chez ses deux appelants — le banc et l'appareil de vue —
## parce qu'une texture fabriquée deux fois finit par différer, et que
## l'écart serait invisible : deux halos presque pareils restent deux halos.
## Douze points suffisent pour que l'interpolation linéaire ne se distingue
## plus de la courbe, même à l'exposant le plus creusé.
static func texture_halo(nettete: float = NETTETE_HALO,
		teinte: Color = Color(1.0, 0.93, 0.82)) -> GradientTexture2D:
	var grad := Gradient.new()
	var offsets := PackedFloat32Array()
	var couleurs := PackedColorArray()
	for i in 12:
		var r := float(i) / 11.0
		offsets.append(r)
		couleurs.append(Color(teinte.r, teinte.g, teinte.b, profil_halo(r, nettete)))
	grad.offsets = offsets
	grad.colors = couleurs
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 512
	tex.height = 512
	return tex


## La demi-emprise ÉCRAN de la zone à photocopier, en pixels.
##
## ⚠️ **Elle couvre ce que le shader LIT, pas ce qu'il PEINT**, et les deux ne
## coïncident pas. Chaque fragment du flou prélève seize voisins jusqu'à
## `rayon_noyau` pixels de lui — les vecteurs d'`ANNEAU` sont unitaires, donc
## c'est bien la borne. Une emprise ajustée au dessin ferait lire au bord des
## texels **périmés** : hors de la zone copiée, la texture d'écran garde ce
## qu'une copie précédente y avait laissé. Le symptôme serait un liseré fantôme
## sur le pourtour, visible seulement en mouvement — donc jamais sur une capture.
##
## ⚠️ **Et l'emprise est celle du rectangle TOURNÉ.** Le flou suit l'axe du
## faisceau ; prendre la taille telle quelle donne une boîte trop petite dès que
## l'angle n'est pas droit, et les coins lisent du périmé. Pour un rectangle
## (l, h) tourné de θ, la demi-emprise vaut :
##
##     (l/2·|cos θ| + h/2·|sin θ| , l/2·|sin θ| + h/2·|cos θ|)
##
## Cette fonction vit ICI et non dans le banc parce qu'un banc ne se teste pas :
## elle est de la géométrie pure, donc éprouvable sans rien rendre — et
## `tools/test_brouillage.gd` vérifie que les quatre coins tournés y tombent.
static func emprise_copie(taille: Vector2, rotation: float,
		marge: float) -> Vector2:
	var co := absf(cos(rotation))
	var si := absf(sin(rotation))
	var demi := taille * 0.5
	return Vector2(
		demi.x * co + demi.y * si + marge,
		demi.x * si + demi.y * co + marge)


static func opacite(dazzle: float, force: float = GAIN,
		courbe: float = COURBE_CONTRASTE) -> float:
	var t := _dose(dazzle, force)
	return lerpf(ALPHA_CONTRASTE, 1.0, pow(1.0 - t, maxf(courbe, 0.01)))

## Le GAIN du brouillage : de combien l'éblouissement est multiplié avant de
## devenir une dose. **2,0, choisi par Adrien au banc le 2026-08-25** (« effet
## à 2 »).
##
## Ce n'est pas un facteur d'intensité, c'est un facteur de **vitesse** : à
## gain 2 la dose sature dès 0,5 d'éblouissement, donc tout le brouillage est
## atteint à mi-faisceau au lieu du plein feu. Cela compte parce que la
## saturation n'est presque jamais atteinte en jeu — plafond réel du pistolet à
## bout portant : 0,93, et bien moins dès qu'on s'écarte de l'axe.
##
## **Il vit ici et pas au banc**, sinon la production ne ferait pas ce
## qu'Adrien a jugé : le banc n'est qu'un endroit où l'on bouge des nombres, la
## valeur retenue doit revenir dans le modèle. Le paramètre `force` des
## fonctions publiques reste son point de dérogation, pour le banc et les tests.
const GAIN := 2.0

## L'opacité du voile blanc, décidée au banc : **0,3**.
##
## ⚠️ **`ui.gd` porte encore 0,8**, et ce sera à changer au branchement.
##
## Le voile est passé par trois états en une soirée : 0,8 (hérité), *supprimé*
## (« on supprime le voile »), puis 0,3. Ce n'est pas de l'hésitation, c'est le
## halo et le flou qui ont pris son travail : il faisait deux métiers — dire
## « tu es ébloui » ET cacher l'adversaire. Le second est parti ailleurs, et
## **localement** ; il ne reste que le premier, qui se contente de 0,3.
##
## ⚠️ **ET IL N'EST PAS RÉGLABLE.** Décision d'Adrien, 2026-08-25 : « on ne peut
## pas régler la valeur éblouissement, il ne faut pas donner d'avantage à un des
## deux ». Voir la note sur `EffectPolicy` juste en dessous — c'est la seule
## chose de ce fichier qui oblige à toucher un fichier d'options.
const VOILE_FACTEUR := 0.3

## ⚠️ **AUCUN RÉGLAGE D'OPTIONS NE DOIT MODULER QUOI QUE CE SOIT D'ICI.**
##
## Décision d'Adrien du 2026-08-25, et elle **dépasse** celle du 2026-08-18 au
## lieu de la contredire. L'ancienne disait : le curseur « Éblouissement » module
## le voile blanc, **jamais** la pénalité de vitesse et de visée — « un curseur
## qui allégerait la pénalité serait un avantage compétitif déguisé en confort ».
## La frontière passait donc entre le CONFORT (le voile) et la PÉNALITÉ.
##
## **Ce chantier a déplacé le voile du mauvais côté de cette frontière.** Tant
## qu'il ne faisait que blanchir l'écran, le baisser ne rendait pas l'adversaire
## plus lisible — il l'était déjà, net et bien placé. Depuis que la lecture de
## l'adversaire dépend du halo, du flou et de l'effacement, **tout ce qui touche
## à l'éblouissement touche à l'information**, et un curseur devient un avantage
## quel que soit ce qu'il règle.
##
## Ce qu'il faudra faire au branchement, et c'est la seule chose de ce chantier
## qui oblige à toucher les options : **`ui.gd` doit cesser de multiplier le
## voile par `GameSettings.current_effect("eblouissement")`** et poser
## `VOILE_FACTEUR` tel quel. L'entrée « Éblouissement » de l'écran des effets
## n'a plus d'objet.
##
## `ui.gd`, `settings_manager.gd` et `effect_policy.gd` appartiennent à la
## session « menus » : la modification se demande, elle ne se fait pas d'office.
const REGLABLE_PAR_LES_OPTIONS := false

## La dose commune : l'éblouissement multiplié par le réglage de force, ramené
## dans [0,1].
##
## **Le `clampf` sur `dazzle` avant la multiplication n'est pas une coquetterie.**
## `apply_dazzle` laisse le pic de flash dépasser le plafond de la torche — c'est
## le modèle, et c'est voulu — mais un `dazzle` au-dessus de 1 sortirait ici des
## amplitudes que rien n'a jamais jugées.
static func _dose(dazzle: float, force: float) -> float:
	return clampf(clampf(dazzle, 0.0, 1.0) * maxf(force, 0.0), 0.0, 1.0)
