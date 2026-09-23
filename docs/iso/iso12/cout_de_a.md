# ISO12 — ce que coûte le mode A, mesuré (2026-09-23, 17:37→18:21)

Treize prises sur `bac5fd7`, scène « vue unique, fusée », **90 s de repos sans Godot avant chaque
lancement**, porte d'indexation au maximum avant le lancement et sur la fenêtre de mesure, `ioreg` à
chaque lancement (clavier inactif depuis plus de quatre heures, Adrien absent). Ordre
`C A R C A L L A C R A C` : chaque variante a la même position moyenne (6,5), ce qui annule une
dérive linéaire.

Règles posées par la session cloud **avant** les chiffres : validité (moyenne des quatre C ≥ 60,
sinon aucun verdict), cellule (A ≥ 90 % de C au 1 % bas **et** A ≥ 60), décomposition (écart des
médianes en ms, établi seulement s'il dépasse l'étendue des prises de sa variante **et** celle des
quatre A).

## Le verdict

**Validité tenue : les quatre C moyennent 65,2 au 1 % bas.** Le verdict compte.

| | 1 % bas hors 10 s | médiane |
|---|---|---|
| **C** (sans lumière 3D) — 77, 72, 72, 40 | **65,2** | 85,5 fps = 11,70 ms |
| **A** (lumière 3D bridée, sans ombres) — 58, 59, 46, 56 | **54,8** | 69,5 fps = 14,39 ms |

**LA CELLULE TOMBE, sur les deux critères** : A vaut **84 %** de C (seuil 90) et **54,8 < 60**.
⚠️ Une prise A (position 8) avait sa fenêtre polluée et **n'a pas été reprise** — le lanceur n'avait
pas la reprise, omission de ma part. Sans elle : A = 57,7 et 88 % de C. **Le verdict ne change pas.**

**Coût de A sur C : +2,69 ms par image à la médiane.** ⚠️ Et non les 4,21 ms annoncés le matin : ce
chiffre venait d'une série enchaînée sans repos, dont la seule prise reposée était une prise C, ce
qui avantageait C de 0,55 ms (voir `mesurer_une_cadence.md`).

## La décomposition : un résultat NÉGATIF, et c'est le résultat

| composant retiré | écart des médianes | étendues (variante / A) | verdict |
|---|---|---|---|
| le relief (A − R) | **−0,10 ms** | 0,00 / 0,21 | **sous le bruit** |
| ce qui reste (R − C) | **+2,80 ms** | — | — |
| total (A − C) | **+2,69 ms** | — | — |

**Le relief ne coûte rien de mesurable.** La boucle de huit lampes du dénominateur, la division dans
`light()`, le varying : invisibles à la médiane. C'est un bon résultat pour la v27, qui apporte le
modelé sans prix.

**Tout le coût est dans les matériaux éclairés** — la bride, la lecture de lightmap, le chemin
d'identité — c'est-à-dire **là où aucun drapeau ne peut aller le chercher sans changer l'image.**
Cette conclusion avait été écrite comme prédiction AVANT la mesure ; elle se vérifie. **Il n'y a pas
d'économie invisible à trouver : la suite est un arbitrage d'image, donc d'Adrien.**

⚠️ **Ce qui n'a PAS été mesuré, malgré les apparences.** La troisième variante (`--lampe-dominante`)
a rendu le jeu **plus lent** de 1,61 ms. Explication d'Iso 1, vérifiée dans son include : ce drapeau
n'est pas une réduction du nombre de lampes, c'est un **correctif d'image pour les ombres** qui
ajoute un tour des huit lampes dans `fragment()` **et un autre dans `light()` pour chaque lampe et
chaque pixel** — on passe de ~8 évaluations par pixel à ~8 + 8 + n × 9. Sans ombres il n'y a rien à
corriger : on paie le tri pour rien. **Donc le coût de la boucle des lampes du moteur reste
INDIFFÉRENCIÉ dans les 2,69 ms**, et ce +1,61 ms ne concerne aucune configuration jouée
(`relief_dominante_3d` est faux, les ombres sont en NON-GO).

**Troisième variante vide de la journée** après les deux émissions que le mode A n'appelle pas
(`lire_led`, `lire_halo_soi` : la branche d'identité est active par défaut et émet 0). Le motif est
constant : **le drapeau retirait autre chose que ce que son nom disait.**

## La prise longue — un signal pour Adrien, hors du chantier

Six minutes mesurées, mode C, même scène. **Les appels de dessin et les objets ne bougent pas
(188 / 1392) : la scène est identique d'un bout à l'autre.**

    0-50 s    : 85,7 fps
    60-130 s  : 75,0        un palier, SANS cause extérieure visible
    140-200 s : 45 à 65     creux, images lentes en paquets
    210-280 s : 50 à 74     remontée partielle
    1 % bas sur les six minutes : 20 · pire image : 144,9 ms

⚠️ **Non attribué.** Le creux de 140-200 s coïncide avec `Google Chrome He` à 46 % et une montée de
`firefox` (19-20 → 22-23 %) ; le palier de 60 s, lui, n'a aucune cause extérieure visible.

**Ce que cela poserait s'il se confirmait** : nos prises durent 60 s et tombent entièrement dans le
palier haut ; **un match en dure 300**. Toutes les cellules du tableau mesureraient alors un régime
que le joueur ne connaît que la première minute. Il faudrait une prise longue en mode A et une autre
navigateurs fermés pour départager. **Rien n'est conclu ici.**
