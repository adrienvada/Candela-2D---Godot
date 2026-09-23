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
