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
