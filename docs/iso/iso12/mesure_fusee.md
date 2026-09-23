# Décomposition du coût de la fusée — 18 prises, 2026-09-23 05:35→05:55

Commit 2f06b1b (worktree détaché `iso7-mesure-fusee`), `--iso --vue-unique --seconds 60
--seuil-lent 25 --temps-par-vue`, neuf variantes en deux passes alternées (1→9 puis 9→1),
Mac sous verrou, aucune autre session. Δ en millisecondes de l'image médiane.

| variante | image médiane | écart 2 passes | Δ récupéré | CPU racine (p1/p2) |
|---|---|---|---|---|
| témoin (sans fusée) | 9,85 ms | 0,29 | — | 1,54 / 1,70 |
| fusée de référence | 13,25 ms | 0,18 | — | 2,57 / 2,85 |
| sans sa lumière 2D | 13,16 | 0,35 | **0,09** | 2,46 / — |
| sans l'ombre de sa lumière | 13,16 | 0,35 | **0,09** | 2,52 / — |
| sans nappes ni voile (2D) | 12,48 | **1,71** | 0,76 ⚠️ | 1,86 / 2,17 |
| sans volume de fumée (iso) | 10,59 | 0,56 | **2,66** | 2,64 / 2,93 |
| sans lueurs | 13,33 | 0,00 | **−0,09** | 2,67 / — |
| volume à 2 couches au lieu de 4 | 12,20 | 0,60 | 1,04 | 2,85 / — |
| les six ensemble | 10,00 | 0,00 | 3,25 | 1,96 / 1,96 |

**COÛT TOTAL : 3,39 ms** par image, vue unique. Somme des parts 3,50 ; les six ensemble 3,25 ;
**interaction +0,26 ms** — les parties s'additionnent proprement. **Résidu 0,15 ms** : rien
n'échappe aux drapeaux (prédit « quelques dixièmes » avant la mesure).

## Ce qui est établi

1. **Le volume de fumée iso coûte 2,66 ms, soit 78 % du coût de la fusée.** Quatre quads
   superposés, jusqu'à 400 px de côté, mêlés, échantillonnant la lightmap.
2. **Ce coût est du REMPLISSAGE, par élimination** : retirer le volume ne change pas le CPU par
   vue (2,64/2,93 contre 2,57/2,85 avec) tout en rendant 2,66 ms d'image. Le temps GPU par vue
   lit 0,00 sur ce Mac — la conclusion vient donc de l'élimination, pas d'une mesure directe.
3. **L'hypothèse de la passe d'ombre est RÉFUTÉE pour la fusée** : son ombre vaut 0,09 ms, sa
   lumière 2D 0,09 ms, ses lueurs zéro. Aucune économie à chercher de ce côté.
4. **Les nappes et le voile 2D coûtent du CPU** (1,86/2,17 contre 2,57/2,85 : −0,69 ms, sur les
   deux passes) mais leur Δ d'image (0,76) est plus petit que l'écart entre ses deux passes
   (1,71) : **non établi en temps d'image**. CPU et GPU se recouvrent — retirer du CPU ne se voit
   pas quand l'image est tenue par le GPU.
5. **4 couches → 2 rend 1,04 ms.** La surface des couches (rayon décroissant de 22 %) prédit
   1,32 ms ; l'écart tient au coût fixe par couche. 4 → 3 rendrait ~0,66 ms.

## Ce qui n'est PAS établi

**La queue du 1 % bas.** Regroupées, les 105 images lentes des 18 prises sont calées sur la
période de 6,5 s du banc (R = 0,538, p ≈ 0,0000). **Mais 59 d'entre elles viennent d'UNE prise**
(p2_sans_ombre2d, pire image 133 ms). Sans elle : R = 0,049, **p = 0,90, dispersé**. La
concentration ne tient donc qu'à une prise anormale, et la question reste ouverte.

⚠️ **Et c'est ma mesure qui est en cause, pas le banc** : le 1 % bas vaut ~23,8 ms, et j'ai posé
le seuil à 25 ms. Dix-sept prises sur dix-huit n'ont donc attrapé que 1 à 5 images — le test est
sans puissance là où il aurait fallu qu'il en ait. **Rejouer deux prises à `--seuil-lent 18`
trancherait, et coûte trois minutes de Mac.**

## Les économies, chiffrées (étape 2 — aucune appliquée, aucune commitée)

- **A — indexer le nombre de couches sur la SURFACE du panache** au lieu de le fixer à 4. Le
  panache grandit de ×1 à ×1,25 en rayon sur sa vie (`FUMEE_GONFLE`), soit ×1,56 en surface : un
  budget de remplissage constant donnerait 4 couches au début, 3 puis 2 à mesure qu'il s'étale.
  **~1 ms au moment le plus lent**, et c'est le moment qui décide du 1 % bas. Précédent dans le
  code : « une nappe de moins en écran scindé » (`fusee.gd`).
- **B — 4 couches → 3 partout : ~0,66 ms**, le plus petit changement d'image possible.
- **C — 4 → 2 : 1,04 ms mesurées**, mais deux tranches de dôme sur quatre : arbitrage d'image,
  donc d'Adrien.
- **D — NE PAS TOUCHER** à la lumière 2D (0,09 ms), à son ombre (0,09) ni aux lueurs (0,00).
  Tout travail de ce côté est perdu d'avance, et c'est le résultat le plus utile de la série :
  il ferme trois pistes que deux sessions tenaient pour prometteuses.
- **E — les nappes et le voile 2D** : 0,69 ms de CPU, mais les retirer en iso change la lightmap
  que le volume échantillonne. À trancher sur image, pas au banc.

## Ce que cette série prouve sur la MÉTHODE

Les trois pistes fermées (lumière, ombre, lueurs) avaient chacune un raisonnement solide derrière
elles — le mien pour le remplissage des nappes, celui de la session cloud pour la passe d'ombre,
appuyé sur les sources du moteur. **Aucune n'a survécu à la mesure**, et la seule qui tenait
(le volume iso) n'avait été nommée par personne comme la principale. Le drapeau par partie, une
partie à la fois et alternée, a fait en vingt minutes ce que trois heures de lecture de code
n'avaient pas fait.

## D'où viennent les 2,66 ms : DIX LECTURES DE TEXTURE PAR PIXEL ET PAR COUCHE

Lecture de `volume_iso.gdshader` (demandée par la session cloud, 06:00 — « 4 ns par pixel, c'est
beaucoup pour un simple mélange alpha »). Ce n'est pas un mélange alpha :

- `lire_lightmap_lissee` = **neuf** `texture()` — le point, plus huit sur un cercle de rayon
  `rayon × 0,18` ;
- la dernière ligne relit la lightmap BRUTE pour la neutralité (`pate_poids_neutre(lire_lightmap(px))`)
  : **une dixième** ;
- plus le bruit procédural `pate_bruit`, et la `pate()` quand le style n'est pas brut.

**Dix lectures par pixel et par couche, donc quarante par pixel de fumée avec quatre couches.**
Les 4 ns par pixel cessent d'être surprenants.

### Deux économies à IMAGE STRICTEMENT IDENTIQUE

**(α) Jeter avant de lire, au lieu de lire puis jeter.** Le shader calcule la couleur `c` (dix
lectures) PUIS l'opacité `a`, et ne fait `discard` qu'ensuite. Or `a` ne dépend pas de `c` :
`a = densite × (1 − smoothstep(coeur, 1, r)) × bruit` vaut **zéro pour tout pixel hors du disque
inscrit**, soit les **21,5 %** de coins du quad, plus la frange où l'opacité tombe sous 0,003.
Calculer `a` d'abord et jeter avant les lectures ne change pas un pixel — ce sont exactement les
mêmes pixels jetés, plus tôt. ⚠️ `aa` et `px_ecran` (qui appellent `fwidth`) doivent RESTER en
tête, hors de tout branchement : le fichier le dit déjà en commentaire, et c'est le piège qui
transformerait cette économie en artefacts de bord.
**Gain estimé : ~0,57 ms** (21,5 % de 2,66), plus la frange.

**(β) La dixième lecture est déjà faite.** `lire_lightmap_lissee` calcule `lire_lightmap(p)` comme
premier de ses neuf échantillons, puis le noie dans la moyenne ; la dernière ligne du `fragment()`
la refait à l'identique. Rendre les deux valeurs au lieu d'une supprime une lecture sur dix, avec
**les mêmes nombres**.
**Gain estimé : ~0,27 ms** (un dixième de 2,66).

Ensemble : **~0,8 ms sur 3,39, soit 24 % du coût de la fusée, sans toucher à l'image.** Et elles
rendent inutile le resserrement de la géométrie (octogone, seize côtés) : un polygone n'économise
que la rastérisation des coins, quand le `discard` précoce en économise les dix lectures.

⚠️ **Estimations, pas mesures.** Les deux se vérifient au banc par le même protocole que la
série : un drapeau par économie, deux passes alternées, et l'on compare au pixel une capture
avant et après pour prouver que l'image n'a pas bougé.

## Le recensement des lampes à ombre : partiel, par ma faute

Les prises portent le commit `2f06b1b`, où `_recenser_les_ombres_2d` plante sur la fenêtre racine
(`disable_2d` n'existe pas sur une `Window`) — défaut que j'ai trouvé à la prise de validation et
signalé à Iso 1, qui l'a corrigé APRÈS. Seule la ligne d'en-tête sort :
**8 occulteurs dans la scène, 2 lampes allumées à ombre sans fusée, 3 avec.**

La fusée ajoute donc exactement une lampe à ombre, comme prévu. Mais **2 et non 6** : ma
prédiction par lecture (torche, rétroéclairage et halo de chacun des deux joueurs) est démentie,
et je ne sais pas encore pourquoi. **La question des halos privés reste donc entière** : il faut
une prise sur le commit corrigé d'Iso 1 pour avoir le détail par viewport.

## Les halos privés : question CLOSE, et par le comptage

Rappel du soupçon : le rassemblement des lumières d'une vue ne teste pas le masque de cull (lecture
du moteur par la session cloud), et le halo de proximité de chaque joueur n'éclaire que son canal
privé (`CanauxLumiere.canal_de_vue`, `16 << id`). Une vue paierait donc la passe d'ombre d'un halo
qui n'y éclaire rien.

**Confirmé par le recensement d'Iso 1** (banc de cadence, vue unique) : les deux lampes 2D à ombre
sont bien les halos (150 px, masques 16 et 32), et le drapeau « n'éclaire AUCUN objet de ce
viewport » s'allume sur `SubViewport1` (pour le halo de l'autre joueur), sur les deux capteurs et
sur `PeintureIso`. **80 dessins d'ombre par image, dont 64 pour rien.**

**Et négligeable, par ma propre mesure** : retirer la lampe à ombre de la fusée — une lampe, même
ordre — a rendu 0,09 ms, dans le bruit. Les deux halos valent donc ~0,18 ms, leur part inutile
**~0,14 ms** : 4 % du coût d'une fusée, 1 % d'une image.

**Restait la crainte que le coût explose sur une vraie carte**, puisqu'il suit le nombre
d'occulteurs. `tools/compte_occulteurs.gd` (headless, sans fenêtre ni cadence) répond :

| carte | cases de mur | rectangles fusionnés | occulteurs |
|---|---|---|---|
| carte d'essai des murs bas | 348 (aucune à l'intérieur) | 4 murs hauts + 5 murs bas | **9** |
| Cloître | 372, dont 48 à l'intérieur (les piliers) | 9 murs hauts, aucun mur bas | **9** |

**Le Cloître ne produit pas plus d'occulteurs que la carte d'essai** : ses quarante-huit cases de
piliers fusionnent en cinq rectangles, pas cinquante. Le gâchis reste à 0,16 ms, sous le seuil de
0,3 fixé par la session cloud. **Question close.**

⚠️ **Deux avertissements sur cet outil.** (1) Il échoue son étalonnage d'une unité : 9 là où le banc
compte 8, et je ne l'explique pas. À cette échelle cela ne change rien, mais qui s'en servira pour
une décision serrée doit le savoir. (2) **J'ai soupçonné cet instrument d'être faux parce que son
résultat me paraissait invraisemblable** — deux cartes très différentes rendant le même compte. Il
avait raison ; c'est le diagnostic ajouté à chaque étage (cases lues, rectangles fusionnés,
occulteurs posés) qui l'a montré. Douter d'un instrument est sain ; le condamner sur une
invraisemblance ne l'est pas.

## La règle d'ordre des prises, telle que la session cloud l'a corrigée

J'avais proposé « jamais deux prises consécutives de la même variante ». **La bonne formulation est
plus large et plus juste** : *jamais une variante plus tôt ou plus tard EN MOYENNE que les autres*.
Ce qui annule une dérive linéaire, c'est l'égalité des positions moyennes — `1…n` puis `n…1` pour
plusieurs variantes, `C A A C` pour deux (le `A A` du milieu est sans danger : A et C y ont la même
position moyenne). Ma version interdisait à tort des séquences valides.

## LA QUEUE DU 1 % : RÉSOLUE — c'est l'échauffement du banc, pas un cycle

La section « ce qui n'est PAS établi » ci-dessus a été écrite à 05:55 ; la réponse est venue à 06:29,
sur deux prises de 60 s avec la série COMPLÈTE des temps d'image (`--seuil-lent 1`, 6 112 et 4 813
images datées), machine calme, ancien chemin du shader.

**Mon test de phase était inapplicable, et il le disait sans que je l'entende** : il déclarait les
images lentes « calées » sur 6,5 s pour les deux prises — **fusée ET TÉMOIN**. Or le témoin n'a pas
de fusée, donc pas de bouclage d'âge : il ne peut rien y avoir à 6,5 s. La cause : les images lentes
sont massées au DÉBUT de la mesure — **53 des 55** au-dessus du 99e centile tombent dans les cinq
premières secondes (71 sur 98 dans les dix premières, pour le témoin). Un paquet concentré dans un
intervalle rend n'importe quelle période « significative ».

**Et ce paquet a un nom, écrit dans l'en-tête du banc** : « Échauffement 2 s » — ⚠️ **valeur du
2026-09-23 au matin, sur `2f06b1b` ; Iso 1 l'a depuis portée à 12 s (`WARMUP_SEC := 12.0`, vérifié
sur `fd6826d` le même jour à 16:40).** Ce qui suit décrit donc la mesure telle qu'elle a été prise,
pas l'état du banc aujourd'hui : avec douze secondes de chauffe, le transitoire décrit ici est
peut-être déjà hors de la fenêtre de mesure, et cela reste à vérifier. L'en-tête
avertit que « l'échauffement réel en dure DOUZE ». La mesure commence dans la chauffe, et le 1 % bas
— quarante-huit images — se calcule pour l'essentiel sur des images de chauffe.

| | 1 % bas, toutes images | hors des 5 premières secondes |
|---|---|---|
| témoin (sans fusée) | 76,6 | **84,8** |
| fusée | 62,1 | **70,1** |

**Hors transitoire, le jeu tient la cible de 60 sous une fusée, avec dix images d'avance.**

⚠️ **Et une correction de fait, à mon compte** (session cloud, 07:54). J'ai écrit dans des messages
que le fameux « 1 % bas à 39 » cumulait le transitoire ET une machine chargée, en citant Spotlight à
93 % et Chrome à 84 %. **Ces chiffres ont été relevés entre 06:21 et 06:26, pas à 04:44** : je les ai
rattachés à une prise faite une heure et demie plus tôt. **La charge du Mac à 04:44 n'a jamais été
mesurée.** Le 39 reste expliqué par le transitoire de chauffe — par analogie avec mes deux prises,
même banc, même échauffement de 2 s (celui de `2f06b1b`) — et par rien d'autre. L'erreur n'a pas atteint ce dépôt ; elle
est corrigée ici pour qu'elle ne revienne pas par la mémoire de quelqu'un.

⚠️ Et « Spotlight tourne en permanence » n'est pas établi non plus : les relevés d'Iso 1 le montrent
absent AVANT chaque prise et présent après, retombant en 10 à 15 s. C'est moi qui avais avancé
« charge permanente » ; je le retire.
