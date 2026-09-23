# Mesurer une cadence sur ce Mac — ce que le 2026-09-23 a coûté pour l'apprendre

Une journée de mesures a produit plus de leçons sur l'INSTRUMENT que sur le jeu. Elles sont ici
parce qu'elles valent pour toute prise de cadence à venir, pas seulement pour le chantier ISO12.

## 1. Chaque lancement de Godot réveille l'indexation de macOS — et chaque sortie aussi

**Mesuré, pas supposé.** Relevé continu (`top -l 0 -s 10`) sur une série de quinze prises :

    avant le premier lancement (30 s) :  0 %   0 %   0 %
    à CHACUN des quinze lancements    :  pic de 47 à 83 % d'un cœur (`spotlightknowledged`)
    retard médian par rapport au lancement : −2 s

Et la sortie pique aussi, ce qu'une série ne peut pas montrer (sortie et lancement suivant y sont à
trois secondes l'un de l'autre, donc dans le même échantillon). Prouvé par une prise isolée suivie
de **soixante secondes d'écoute sans rien relancer** :

    +95 s : 13 %   +105 s : 61 %   +115 s : 22 %   (sortie à +93 s)

**Ce n'est donc ni le journal du jeu, ni `user://`, ni le dépôt** : trois pistes suivies et
éliminées le même jour (le journal part sous `/tmp` par `--log-file` et le pic persiste ; `find` ne
montre aucune écriture sous `user://` pendant une série ; l'arbre de mesure est déjà hors index).
C'est l'événement de lancement d'application lui-même. **Aucun déplacement de fichier n'y peut
rien** ; seule une chauffe assez longue met la mesure hors de portée du pic.

## 2. D'où la chauffe à 30 s — et la porte qui ne regarde QUE la fenêtre de mesure

`WARMUP_SEC` est passé de 12 à 30 s (Iso 1, `bac5fd7`). Vérifié le jour même :

    +5 s et +15 s : pic de 11 % puis 58 %   (dans la chauffe)
    +25 s          : 0 %
    fenêtre de mesure (+28 à +88 s) : **0,0 % d'un bout à l'autre**

⚠️ **Et la porte doit vérifier la fenêtre de mesure, PAS toute la prise.** Une porte qui surveillait
la prise entière a rejeté **quatorze prises sur quinze** : elle voyait le pic de lancement — celui
que la chauffe vient précisément d'exiler hors de la mesure — et refusait le remède.

## 3. Trois pièges d'instrument, payés le même jour

- **`top -l 1` ne mesure rien par processus.** La première passe ne peut pas calculer un
  pourcentage : tous les processus y valent 0,0 %. Un « machine calme, vérifié au top » fondé
  dessus ne prouve rien. Il faut `top -l 2` et ne lire que la seconde passe, ou un `top -l 0`
  continu dont on jette le premier échantillon.
- **`top` TRONQUE les noms à seize caractères** : il imprime `spotlightknowled`, jamais
  `spotlightknowledged`. Une porte qui comparait le nom entier ne trouvait rien, sommait zéro et
  s'ouvrait toujours — série entière perdue. **Comparer par préfixe.**
- **Lire un nombre APRÈS les deux-points, jamais « le premier nombre après un libellé ».** Le
  libellé « FPS 1 % bas hors 10 s » contient un 1 et un 10, et la parenthèse qui suit en contient
  d'autres : une lecture naïve rendait 51 là où le journal imprime 72. Le piège est écrit en tête de
  `tools/run_decomposition.sh` depuis août ; il a été repayé.

## 4. Ce que la machine fait pendant nos mesures, et que le verrou ne couvre pas

Le verrou (`/tmp/candela-mac.lock`) ne couvre que Godot. Trois charges lui échappent :

| charge | mesuré | effet |
|---|---|---|
| l'indexation au lancement et à la sortie | 47 à 83 % d'un cœur | réglé par la chauffe de 30 s |
| **les navigateurs d'Adrien** | `firefox` 20-24 % en continu, `Chrome Helper` jusqu'à 31 % | **non réglé** |
| `WindowServer` (le compositeur) | 28 à 50 % | inhérent au rendu fenêtré |
| nos propres sessions | `Claude Helper` 17 % | réglé par les fenêtres de silence annoncées |

⚠️ **Les navigateurs partagent le GPU avec le banc**, et cela se voit dans les pires images : trois
images consécutives à ~100 ms (blocage de 300 ms) pendant une prise dont la fenêtre était par
ailleurs propre de toute indexation. **Conséquence : les valeurs ABSOLUES d'une cadence mesurée
navigateurs ouverts ne sont pas comparables à une cible.** Le 2026-09-23, le mode de référence (sans
lumière 3D, celui qui tourne dans le jeu) échouait lui-même la cible de 60 au 1 % bas. Les ÉCARTS
entre variantes, eux, restent valables : la charge frappe toutes les prises également.

## 5. Ce qui protège une série, et pourquoi

- **L'ordre en miroir** (`1…n` puis `n…1`, ou `C A A C C A A C` pour deux variantes) : ce qui annule
  une dérive linéaire, c'est que **chaque variante ait la même position moyenne**, pas qu'on évite
  deux prises consécutives.
- **La dérive existe et se mesure** : sur neuf paires d'une même variante, la première passe a été
  plus rapide que la seconde **sept fois, jamais plus lente** (test des signes, p = 0,016).
- **Une fenêtre de silence annoncée** à toutes les sessions du Mac — y compris celles qui ne
  mesurent pas mais publient : elles écrivent et composent des images, et cela pèse.
- **Un essai à blanc du lanceur** (Godot remplacé par `echo`) avant d'engager un créneau : vérifier
  la syntaxe d'un script ne prouve pas qu'il tourne. Deux fois le même jour, une variable référencée
  dans sa propre déclaration `local` a fait échouer une série en trois secondes.

## 6. LE REPOS ENTRE PRISES — le piège le plus cher de la journée

**Enchaîner deux prises de cadence sans repos fausse la seconde, et toutes les suivantes.** Mesuré
le 2026-09-23 sur le même banc, la même scène et la même machine, navigateurs ouverts dans les deux
cas :

| | médianes | 1 % bas hors 10 s | pires images |
|---|---|---|---|
| quatre C **enchaînées** (série de 16:54) | 86, 75, 73, 73 | 72, **30, 35, 16** | 27 à **105 ms** |
| trois C avec **90 s de repos** (contrôle de 17:20) | **86, 86, 86** | **71, 78, 67** | 13 à 34 ms |

Trois prises reposées tiennent la cible ; trois prises enchaînées la manquent d'un facteur quatre.
**Et ce ne sont pas les charges extérieures** : `firefox` occupait 19,2 % pendant la première prise
et 21,2 % pendant la huitième, `WindowServer` 49 puis 46 % — constants. `Google Chrome He` allait
même à l'envers : la prise la plus RAPIDE est celle où il consommait le PLUS (16,7 %), la plus lente
celle où il était à zéro.

⚠️ **Conséquence sur les chiffres déjà publiés** : tout écart tiré d'une série enchaînée est suspect,
même sous protocole miroir. Le miroir n'annule qu'une dérive LINÉAIRE ; celle-ci chute d'un coup
après la première prise puis se stabilise. Dans la série de 16:54, la seule prise reposée était une
prise C, ce qui a avantagé C de **0,55 ms sur un écart annoncé de 4,21** (3,67 ms sans elle).

**Règle** : 90 s sans aucun Godot avant chaque lancement, en plus de la porte d'indexation.

## 7. LA PORTE PREND LE MAXIMUM, PAS LA MOYENNE

Une porte qui moyenne les échantillons de charge sur la fenêtre de mesure laisse passer un pic isolé :
`spotlightknowledged` à 34 % sur un échantillon parmi six donne une moyenne de 5,7 %, sous un seuil
de 10 %. C'est arrivé à la prise 4 du 2026-09-23, qui s'est retrouvée deuxième plus mauvaise de sa
série. **Une image lente ne se moyenne pas : elle se voit.** La porte garde donc le maximum.

## 8. LE NOM D'UN DRAPEAU N'EST PAS SON EFFET — lire l'include avant de mesurer

`--lampe-dominante` se lit comme « une seule lampe », donc comme une économie. **C'en est l'inverse :
c'est un correctif d'IMAGE conçu pour les ombres** (les passes additives des lampes à ombre
s'additionnent et éclaircissent ; la dominante n'en laisse écrire qu'une par pixel). Son coût, lu
dans `iso_relief.gdshaderinc` : un tour des huit lampes dans `fragment()` **en plus** du dénominateur,
puis **pour chaque lampe et chaque pixel** un nouveau tour des huit dans `light()` pour retrouver
laquelle c'est — soit ~8 évaluations par pixel qui deviennent ~8 + 8 + n × 9.

Mesuré en mode A (sans ombres, donc sans rien à corriger) : **+1,61 ms**, au-dessus du bruit. On paie
le tri pour rien. ⚠️ Et ce chiffre **ne concerne aucune configuration jouée** : `relief_dominante_3d`
est faux, la dominante n'ayant de sens qu'avec les ombres, qui sont en NON-GO.

**Troisième variante vide de la même journée**, après `--a-sans-led` et `--a-sans-halo-soi`, qui
retiraient des émissions que le mode A n'appelle jamais (la branche d'identité est active par défaut
et émet 0). Le motif est constant : **le drapeau retirait autre chose que ce que son nom disait.**

**Règle** : avant de mesurer une variante, lire ce que le drapeau fait DANS LE SHADER — pas ce que son
nom suggère, ni ce que son commentaire annonce. Et la règle jumelle, déjà écrite : une variante qui
mesure zéro se vérifie avant d'être crue. Il faut y ajouter : **une variante qui mesure un résultat
inattendu aussi** — c'est elle qui a révélé les trois.

## 9. La machine : un MacBook Air M3, sans ventilateur

`sysctl -n hw.model` → `Mac15,13` ; `system_profiler` → **MacBook Air, Apple M3, 8 cœurs (4+4),
24 Go**. **Un châssis sans ventilateur, à refroidissement passif.** Cela ne prouve rien à soi seul,
mais c'est le contexte de toutes nos mesures : une charge GPU soutenue s'y bride par construction,
et c'est l'explication la plus simple du repos de 90 s qui rétablit tout, comme du palier observé
après une minute de prise longue. L'état thermique se lit sans droits particuliers :

    osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState'
    → 0 normal · 1 passable · 2 sérieux · 3 critique   (essayé le 2026-09-23 : rend bien 0)

## 10. Le banc ne peut pas mesurer plus de ~270 s : la manche finit

Deux prises longues de six minutes ont été lancées le 2026-09-23, à 18:14 et à 19:47. **Les deux se
sont arrêtées à la même seconde** — 272,88 s et 272,84 s de mesure — et les deux ont été **refusées
par le banc lui-même** :

    hoquet 110.6 ms à 272.84 s — lampes : aucune lumière 3D
    ✗ la lampe n'a pas suivi la demande du banc sur 1 image(s) : chiffre refusé

L'identité des deux instants est ce qui désigne la cause. Les deux prises n'ont ni la même cadence ni
le même nombre d'images (18 078 contre 23 268) : l'événement est déterministe **dans le temps**, donc
il n'est ni thermique, ni machine, ni malchance. `tools/bench_framerate.gd:191` le dit d'ailleurs en
clair — « le banc joue déjà une vraie manche ». Et une manche dure `MatchRecord.ROUND_DURATION`,
soit **300 s** (`match_record.gd:101`). Le banc ne gèle pas `time_left` : au bout de cinq minutes de
temps de jeu la manche se termine, les torches s'éteignent, et la garde de l'étape 28 refuse — à
raison, puisqu'elle ne peut pas savoir ce que la fin de manche a éteint d'autre.

**Plafond utile : `ROUND_DURATION` − `WARMUP_SEC` − le montage, soit ~270 s.** Une mesure de durée de
match se demande donc à **240 s**, pas à 360. Deux prises de sept minutes de Mac ont été perdues à
l'ignorer, la seconde après un repos de trente minutes qu'il a fallu attendre.

⚠️ **Et les chiffres d'une prise refusée ne servent à rien, même partiellement** : la garde refuse
*le chiffre*, pas la dernière image. Les relevés 75/20 et 86/65 de ces deux prises ne doivent être
cités nulle part. Ce qu'elles laissent est une **question**, pas un résultat : leurs profils par
tranche diffèrent énormément (l'une plate à 85,7 jusqu'à 260 s, l'autre creusant à 45 entre 170 et
200 s avant de remonter), et la première venait d'une machine reposée quand la seconde suivait douze
prises enchaînées. C'est cohérent avec le § 7, mais cela demande une prise valide pour être affirmé.

## 11. Compter, quand on peut compter : la géométrie des corps habillés

Une tenue peinte (`--corps=portraits`, `sombre`, `sombre2`, `sombre3`) ajoute la bouteille dans le dos
aux six classes qui la portent. Combien cela coûte-t-il ? La question se **compte**, elle ne se mesure
pas : `tools/compte_boites_corps.gd`, headless, construit chaque corps dans les deux états et recense
les `MeshInstance3D` réellement posés. Relevé sur 7a648d2 le 2026-09-23 :

    6 classes sur 10 portent la bouteille, +2 maillages chacune (18 → 20).
    Un duel où les DEUX joueurs la portent : +4 maillages. Où aucun (le pompe) : +0.
    portraits, sombre, sombre2, sombre3 : 192 contre 180, les quatre, à l'identique.

**+2 et non +1 parce que `VoxelCorps._boite()` pose deux maillages par boîte** : la boîte visible et son
jumeau de profondeur (`BoiteProfondeur`). Le chiffre confirme la remarque d'ISO7 Beauté au maillage près.

Trois choses que ce recensement donne et qu'une prise de cadence n'aurait pas données :

- **Il est exact.** Aucun bruit, aucun repos de 90 s, aucune porte d'indexation — dix secondes de Mac.
- **Il prouve que le drapeau porte**, ce qu'aucune cadence ne prouve : il imprime d'abord ce que
  `VoxelCatalogue.tenue()` a compris de la ligne de commande (« sombre1 » pour `--corps=sombre`).
  ⚠️ Le drapeau se passe **après `--`** : la lecture se fait sur `OS.get_cmdline_user_args()`.
- **Il vérifie que les quatre tenues ont la même géométrie** au lieu de le déduire du code, ce qui
  autorise à n'en mesurer qu'une.

⚠️ **Et il montre où la moyenne ment.** Douze maillages sur dix classes font « +1,2 par corps », un
nombre que personne ne paie : six classes paient +2 en entier, quatre paient 0. La première version de
l'outil imprimait cette moyenne — corrigée avant publication. Un coût qui frappe une partie de la
population se dit par porteur, jamais par tête.

### Et le piège qu'il faut nommer : « même shader » ne veut pas dire « même coût »

L'outil compare aussi les shaders des matières du corps, gris contre tenue. Ils sont **identiques**,
chemin et empreinte du code :

    gris   res://corps_iso.gdshader             code 3381077480  (9 maillages)
    tenue  res://corps_iso.gdshader             code 3381077480  (10 maillages)
    gris   res://corps_iso_profondeur.gdshader  code  519987648  (9 maillages)
    tenue  res://corps_iso_profondeur.gdshader  code  519987648  (10 maillages)

La tentation est d'en conclure que la tenue ne coûte rien au pompe, puisque au pompe les maillages
sont les mêmes aussi. **C'est faux, et le shader lui-même le dit** : dans
`iso_corps_portrait.gdshaderinc`, `portrait_fiche()` et `portrait_teindre()` s'ouvrent toutes deux par

    if (portrait < 0.5) { return fiche; }

`portrait` est un **uniforme**. Le gris sort à la première ligne ; la tenue exécute la cinquantaine de
lignes qui suivent — patine, rouille, `smoothstep`, comparaisons de boîtes, tête, liseré d'arêtes —
**pour chaque pixel de chaque corps**. La bascule ne laisse donc aucune trace dans le programme : ni le
chemin, ni l'empreinte du code, ni le nombre de maillages ne bougent.

**La leçon générale** : une comparaison de shaders ne voit pas un coût gouverné par un uniforme. Elle
répond « identiques » aussi bien quand le travail est absent que quand il est simplement éteint ce
jour-là. Pour un coût derrière un uniforme, il n'existe que deux voies : lire la branche, ou mesurer.

## 12. Le coût des tenues sombres, mesuré (2026-09-23, 22:29 → 22:54)

Huit prises de 60 s sur 7a648d2, vue unique sous la torche, gris contre `--corps=sombre`, en miroir
**G H H G H G G H** — positions moyennes 4,5 des deux côtés, donc une dérive linéaire s'annule. Règle
posée par la session cloud **avant** les chiffres : H tient si la médiane de ses quatre 1 % bas vaut
au moins 60 **et** si la médiane de ses quatre médianes vaut au moins 97 % de celle de G.

    prise   mode  médiane  1 % bas  pire image   indexation sur TOUTE la fenêtre
    01_G    G       108      98      11,3 ms     0 %
    02_H    H       110      96      13,9 ms     0 %
    03_H    H       110      99      13,7 ms     0 %
    04_G    G       103      72      17,2 ms     23 %  mds_stores
    05_H    H       103      94      12,7 ms     35 %  spotlightknowledged
    06_G    G       103      98      13,3 ms     19 %  spotlightknowledged
    07_G    G       103      84      12,9 ms     0 %
    08_H    H       103      95      11,4 ms     0 %

    G : médiane des médianes 103,0 · médiane des 1 % bas 91,0
    H : médiane des médianes 106,5 · médiane des 1 % bas 95,5
    H/G sur les médianes : 1,034 (seuil 0,970)   →   **H TIENT**

**Ce que cela dit, et rien de plus** : le coût de shader de la tenue est **sous la résolution de la
série** (3 % de la médiane), en vue unique sous la torche. Pas « nul » : H est nominalement *plus
rapide* que G, ce qui est impossible et dit seulement que l'écart réel est noyé dans le bruit.

**La bouteille reste non mesurée en cadence, bornée par le recensement** : +2 maillages par classe
porteuse, six sur dix, +4 dans un duel de deux porteuses.

### Trois réserves, qui valent plus que le verdict

**La classe n'est pas celle qu'on croyait.** Le banc a imprimé « Manche lancée — armes : Fusil /
Fusil », alors que sa constante s'appelle `SHOTGUN_INDEX` (= 2) et que son propre garde dit « (pompe) ».
**La cause, trouvée par Iso 1 le soir même** : le banc presse la PLACE 2 du `ButtonGroup`, or depuis
`0e43dd4` `ui.gd` range les boutons par rang d'AFFICHAGE — la place 2 y est le Fusil, et l'indice de
catalogue se lit par `META_CLASSE_INDEX`. Une constante juste le jour où elle a été écrite, rendue
fausse par un tri ailleurs, sans que rien ne le signale. La mesure n'en souffre pas — ni le fusil ni le pompe ne portent la
bouteille, donc la comparaison reste bien « shader seul » —, mais c'est le motif du § 8 une fois de
plus : **le nom d'une constante n'est pas son effet**, et seule la ligne imprimée par le banc dit ce
qui a tourné. Sans elle, ce rapport aurait nommé la mauvaise classe.

**La porte d'avant-lancement laisse passer des fenêtres sales.** Elle n'examine que les derniers
échantillons **avant** le lancement ; la relecture d'après coup, sur toute la fenêtre de mesure, a
trouvé de l'indexation dans trois prises, dont **une seule** avait été signalée. C'est la relecture,
pas la porte, qui a vu 05_H à 35 % et 06_G à 19 %.

**Le verdict y survit, et c'est ce qui compte.** En écartant les trois prises polluées, il reste G à
105,5 de médiane et 91 de 1 % bas contre H à 110 et 96 : H/G = 1,043. La conclusion ne dépend donc
pas du traitement des prises sales — vérification faite APRÈS le verdict, pour ne pas choisir les
prises en fonction du résultat voulu.

⚠️ **Ces cadences (103-110) ne se comparent à aucune autre série de la journée** : il n'y a pas de
fusée ici. Les 86 du § 7 valaient pour une scène avec fusée allumée.

### Si la question revient : quelle économie serait sans perte d'image

Rien n'est à changer aujourd'hui — on ne dégrade pas une image pour un coût qu'on n'arrive pas à
mesurer. Mais si le coût des tenues devenait un jour visible, voici la seule piste **sans perte
d'image**, et surtout celle qu'il ne faut PAS prendre.

Les deux `pate_bruit` sont calculés **avant** les branches de boîte, donc payés aussi par les pixels
qui ne s'en servent pas. La tentation est de les descendre dans la branche du torse : **c'est faux**,
et c'est ISO7 Beauté qui l'a corrigé — la patine habille aussi les jambes et les bras. L'économie
juste serait de sauter les bruits sur les seules boîtes qui ne les utilisent pas (l'arme, et la tête
des tenues sombres), ce qui est un gain plus petit.

Le motif mérite d'être retenu au-delà de ce cas : **celui qui a écrit l'image sait quels pixels en
dépendent, et celui qui mesure ne le sait pas.** Une économie proposée par le mesureur se fait
valider par l'auteur avant d'être tentée.

## 13. Deux fautes de la même soirée, qui n'ont rien produit mais auraient pu produire pire

### Un drapeau vidé en silence fait jouer au banc son DÉFAUT

Le lanceur assemblait le drapeau de classe par `printf "$DRAPEAU_CLASSE" "$slug"`. **`printf` prend
`--classe=%s` pour une option** et rend une chaîne vide, sans que rien n'échoue. Les quatre prises
« fusil » seraient donc parties sans drapeau — et le défaut du banc étant désormais le **pompe**,
elles auraient joué le pompe. La série aurait comparé le pompe au pompe et conclu « le pompe ne coûte
rien » : un faux résultat parfaitement crédible, dans le sens qui arrangeait.

Ce qui l'a vu : le contrôle de la ligne « armes : » à chaque prise, et un passage à blanc où le
mannequin joue **exprès** la mauvaise classe. Remède dans le script : `${DRAPEAU_CLASSE//%s/$slug}`.

**La règle qui en sort** : quand un banc a un DÉFAUT, un drapeau perdu ne se voit pas — il se déguise
en l'autre branche de la comparaison. Toute série qui compare A à B en passant un drapeau doit
vérifier, prise par prise, **ce que le banc dit avoir joué**, jamais ce qu'on croit lui avoir demandé.

### Annoncer une fenêtre n'est pas l'ouvrir

À 23:13, le lanceur a pris le verrou et j'ai annoncé « fenêtre ouverte » à toutes les sessions. Mais
un Godot tournait : le lanceur a rendu le verrou et attendu — quatre-vingts fois, jusqu'à abandonner
à 23:52. Le processus était l'**éditeur** (aucun argument, parent `launchd`, dossier courant `/` :
ouvert depuis le Finder ou le Dock, donc Adrien). `pgrep -x Godot` en plus du verrou a fait
exactement son travail : **on ne prend pas la machine à Adrien**, et une cadence mesurée avec
l'éditeur ouvert ne vaudrait rien de toute façon.

La faute est ailleurs : l'annonce était adossée à la **prise du verrou**, pas au **démarrage de la
série**. Deux sessions ont gardé le silence quarante minutes pour rien. **Une fenêtre s'annonce quand
la première prise part**, et la surveillance se met sur le démarrage autant que sur la fin.

## 14. Le pompe sous une fusée, enfin mesuré (2026-09-24, 00:03 → 00:34)

Le pompe — cône de 60°, tirs à plombs — était depuis `0e43dd4` ce que le banc **croyait** mesurer
comme pire cas, et le seul cas qu'il ne mesurait jamais (§ 12). Huit prises de 60 s sur `b193420`,
vue unique sous une fusée, `--classe=pompe` contre `--classe=fusil`, en miroir **F P P F P F F P**.

    prise   mode  médiane  1 % bas  pire image   indexation sur TOUTE la fenêtre
    01_F    F       82       69      26,3 ms      0 %
    02_P    P       84       77      14,0 ms      0 %
    03_P    P       84       77      20,1 ms      0 %
    04_F    F       82       77      16,9 ms     45 %  spotlightknowledged
    05_P    P       86       68      16,1 ms     21 %  spotlightknowledged
    06_F    F       84       79      18,6 ms     31 %  spotlightknowledged
    07_F    F       84       77      20,0 ms     65 %  spotlightknowledged 53 %, mediaanalysisd 12 %
    08_P    P       86       77      19,0 ms      0 %

    F (fusil) : médiane des médianes 83,0 · médiane des 1 % bas 77,0
    P (pompe) : médiane des médianes 85,0 · médiane des 1 % bas 77,0
    P/F sur les médianes : 1,024 (pour information, sans seuil)

**LE JEU TIENT AU POMPE SOUS LA FUSÉE** : 1 % bas médian 77, pour un seuil de 60 posé avant les
chiffres. Et le verdict ne tient pas à une médiane bien choisie — **les huit prises, une par une,
dépassent 60** : la plus basse est à 68. C'est la forme la plus solide que puisse prendre ce résultat.

### Ce que la série dit de l'instrument, et qui est plus gênant que le verdict

**La porte d'avant-lancement a déclaré les huit prises « propres ». Quatre ne l'étaient pas**, dont
une à 65 % d'indexation dans sa fenêtre de mesure. Deuxième série de suite où la relecture d'après
coup trouve ce que la porte ne voit pas, et cette fois elle en rate quatre sur quatre. **La porte
d'avant-lancement ne protège de rien une fois la prise commencée** ; seule la relecture compte.

**Mais l'indexation ne s'est pas vue dans les chiffres.** `07_F`, la plus polluée des huit (65 %),
donne 77 au 1 % bas — parmi les meilleures. Il faut le dire aussi franchement que l'inverse : sur
cette série, la pollution mesurée n'a pas dégradé la cadence de façon lisible. La porte reste utile
comme précaution, pas comme explication.

⚠️ **Le rapport P/F, lui, ne vaut pas grand-chose ici** : trois des quatre prises F étaient polluées
contre une des quatre P. 1,024 se lit « pas d'écart visible », jamais « le pompe est plus rapide ».

**Et Adrien était au clavier pendant la fenêtre.** La garde d'inactivité a suspendu la série huit
minutes entre `05_P` et `06_F`, puis repris quand le clavier a dépassé dix minutes d'inactivité. Le
miroir survit à une pause : ce qu'il annule, c'est une dérive linéaire, et les positions moyennes
restent 4,5 des deux côtés.

### Quatrième réserve : ma relecture ne suivait que les INDEXEURS

Signalée par la session cloud, et elle a raison. ISO Assets générait des images dans Chrome pendant la
fenêtre, et ma relecture d'après coup ne cherchait que `spotlight`, `mds`, `mediaanalysisd` — les noms
de la porte. En la refaisant sur **tout processus étranger au-dessus de 10 %**, hors Godot :

    prise    pire charge étrangère dans la fenêtre de mesure
    01_F     WindowServer 46 %, kernel_task 17 %, Claude 12 %
    02_P     WindowServer 47 %, kernel_task 16 %
    03_P     WindowServer 46 %, kernel_task 15 %
    04_F     WindowServer 48 %, spotlightknowledged 45 %, kernel_task 15 %
    05_P     Google (Chrome) 53 %, WindowServer 46 %, kernel_task 22 %
    06_F     WindowServer 47 %, spotlightknowledged 31 %, kernel_task 15 %
    07_F     spotlightknowledged 53 %, WindowServer 48 %, Claude 19 %
    08_P     WindowServer 47 %, kernel_task 15 %

**Chrome n'apparaît que dans une fenêtre, `05_P` — et `05_P` est justement la prise dont le 1 % bas
est le plus bas de la série (68).** C'est la seule corrélation propre du lot, et elle va dans le sens
attendu. Elle ne change pas le verdict : 68 dépasse encore 60, et une charge de plus ne peut que
baisser une cadence, donc **« le jeu tient » est un résultat conservateur** — la vraie cadence du
pompe est au moins celle-là.

Deux choses que cette relecture élargie montre en passant. **`WindowServer` tourne à 46-48 % dans les
huit fenêtres** : c'est le compositeur qui affiche la fenêtre de jeu, pas une pollution — que personne
ne le « découvre » plus tard comme une anomalie. Et **nos propres processus `Claude` pèsent 12 à 19 %**
dans deux prises : l'agent qui mesure est lui-même une charge.

**La leçon d'instrument** : une relecture qui cherche des noms connus ne trouve que ce qu'elle
connaît. Chercher **tout processus au-dessus d'un seuil** coûte le même travail et voit ce qu'on
n'avait pas prévu. Corollaire pratique : annoncer une fenêtre en demandant « pas de Godot » est trop
étroit — il faut demander **pas de charge lourde**, génération d'images et navigateur compris.
