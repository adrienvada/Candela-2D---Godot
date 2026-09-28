# Mesurer la cadence par version — rapport de la session cloud « cadence-version »

> Branche `claude/cloud-cadence-version`, partie de `origin/integration-iso14` (`a30a407`), 2026-09-28, de 06:41 à
> @@FIN@@ (Paris). **État : en cours — tri des essais en route.** Rien ne change dans le jeu : une règle, deux outils, leurs essais, les tableaux du tri.

## Pour Adrien, en cinq lignes

@@CINQ@@

## La fiche pour le Mac (Iso 1)

**La première série : `a30a407` (la référence) contre la prochaine version intégrée** — la fusion d'iso11-menus et
d'iso12-corps que la session « intégration à blanc » a préparée (`244cb88` ; ta propre fusion doit lui être identique :
`git diff 244cb88 HEAD -- . ':!docs/iso/cloud'` vide). Le tri du cloud la classe **neutre** (§ 2) : vue unique seulement.

```bash
# 0. L'outil dans son propre arbre (on ne touche pas à l'arbre des autres sessions)
git fetch origin claude/cloud-cadence-version integration-iso14      # + la branche de la version à mesurer
git worktree add ~/candela-arbres.noindex/outil origin/claude/cloud-cadence-version
cd ~/candela-arbres.noindex/outil

# 1. AVANT la série, hors du verrou : les deux arbres (~/candela-arbres.noindex/<hash>) et leur import
tools/cadence/serie_version.sh --preparer a30a407 <tête B>           # quelques minutes ; refuse si l'import modifie un fichier suivi

# 2. La série, ≈ 28 min sans refus
mkdir /tmp/candela-mac.lock
tools/cadence/serie_version.sh a30a407 <tête B> /tmp/serie-version-<date>
rmdir /tmp/candela-mac.lock
```

`<tête B>` : un hash, une branche (`origin/…`) ou `244cb88`. `GODOT` vaut par défaut
`/Applications/Godot.app/Contents/MacOS/Godot` ; `ARBRES` par défaut `~/candela-arbres.noindex` (Spotlight ignore les
dossiers en `.noindex`). L'écran scindé : `SCINDE=1` (seulement si le tri a classé « lourde » une nouveauté de géométrie).

**Durée.** 5 min de repos initial, puis sept prises d'environ 3 min 20 (90 s sans Godot, le lancement, 30 s de chauffe du
banc, 60 s de mesure) : **≈ 28 min**. Chaque prise refusée par la porte : +3 min 20. La prolongation, si elle se déclenche :
+6 min 40 (≈ 35 min).

**Ce que le lanceur fait, dans l'ordre.** Il vérifie le verrou, qu'aucun Godot n'est ouvert, et que chaque arbre existe,
est importé, est à sa tête et n'a aucun fichier suivi modifié. Repos initial relevé (charge de Claude Helper). Puis une
chauffe A non comptée et `A B B A A B` ; avant chaque prise : 90 s sans aucun Godot, l'état thermique du Mac (il attend
qu'il soit « normal », dix minutes au plus), personne devant le Mac (navigateur, lecteur, son). Chaque prise :
`Godot --path <arbre du bras> res://tools/bench_framerate.tscn -- --seconds 60 --max-fps 0 --fusee --vue-unique
--classe=pompe` — **les mêmes arguments aux deux bras, aucun drapeau** : une version se mesure avec ses défauts.

**Ce qu'il refuse.**

| il refuse la PRISE (et la refait à sa place, quatre fois au plus) | il ARRÊTE la série (faute de montage) |
|---|---|
| un processus étranger au-dessus de 20 % d'un cœur dans la fenêtre mesurée (Godot, WindowServer, top, kernel_task exceptés) | un arbre absent, pas importé, pas à sa tête, ou avec un fichier suivi modifié — relu avant ET après chaque prise |
| Claude Helper (tous ses processus sommés) au-dessus de 30 % | une erreur de shader ou de script au journal |
| | « Rendu : iso lacet 45° B » absent (réglable : `RENDU=`), ou les joueurs pas au pompe |
| | des lignes d'état du jeu (`[usure] …`, `[fumée masque] …`…) qui changent d'une prise à l'autre d'un même bras |
| | une médiane illisible ; quelqu'un devant le Mac ; un Mac qui ne refroidit pas ; une cinquième reprise de la même prise |

**Comment lire le verdict** (fin de `serie.txt`) :

    A  prises 01_A 04_A 05_A   médianes [..]  1 % bas [..]  → médiane .. · 1 % bas médian .. · Claude Helper ..
    B  prises 02_B 03_B 06_B   …
    A tient dans 5 % : oui … · bras équilibrés : oui (écart … points)
    rapport B/A 0.9xx (+x.xx ms par image) · 1 % bas médian de B ..
    VERDICT : B TIENT | B NE TIENT PAS (règle 278 : rapport ≥ 0,970 ET 1 % bas médian > 60)
    lignes d'état propres à A (« < ») et à B (« > ») — ce que la version change, dit par le jeu

- **B TIENT** → B devient la référence de la version suivante.
- **B NE TIENT PAS** → chercher la coupable (règle, § 6) : retirer la nouveauté que le tri classe la plus lourde, et une
  série courte A contre B′.
- **SANS VERDICT** (les A ne tiennent pas dans 5 %, ou Claude Helper diffère de plus de 2 points entre les bras) → la série
  est à refaire, pas à lire.
- **« verdict PROVISOIRE … » puis « ⤷ PROLONGATION »** → le rapport tombait entre 0,958 et 0,982 : un bloc `B A` de plus a
  été pris, et **seul le verdict qui suit compte**. Jamais de second bloc.
- Les prises refaites portent `_r1`, `_r2`… : le verdict ne lit que celles que la porte a acceptées.

## 1. La règle

`docs/iso/cadence_par_version.md`, écrite **avant** les outils (commit `…` de 06:5x), le texte qu'Iso 1 portera dans la
feuille de route. En bref : une **version** est une tête intégrée lancée **sans drapeau** ; elle se mesure **quand ses
défauts changent** ; sa **référence** est la dernière version qui a tenu ; le **tri du cloud** passe avant ; la **série
courte** est `chauffe + A B B A A B`, 30 minutes au plus ; une version qui échoue se déshabille **par la nouveauté que le tri
classe la plus lourde**, par une autre série courte, jamais par une série par nouveauté. La barre de la règle 278 ne change
pas (≥ 0,970 de la référence, 1 % bas médian > 60).

**Décisions prises, et leur pourquoi** (personne n'était devant moi ; ce sont des choix, à trancher par Iso 1 ou Adrien s'ils
ne conviennent pas) :

| décision | pourquoi |
|---|---|
| Une version se lance **sans aucun drapeau**, chaque bras dans son arbre | un drapeau perdu se déguise en l'autre bras (§ 13 du document de mesure) ; sans drapeau, rien à perdre. Ce qui distingue les bras, c'est l'arbre, prouvé par son hash avant et après chaque prise |
| **Trois prises par bras**, `A B B A A B` | dans les séries déjà faites à la règle 278, les médianes d'un bras varient de 0 à 2 images d'une prise à l'autre (T 88·88·88 ; U0 89·89·89 ; U1 84·84·84 ; M0 88·86·87 ; M1 82·82·82 ; 0° 88·88·87 ; 45° 84·86·84) : la médiane de trois bouge d'une image au plus, 1,2 % à 85 |
| Une **chauffe A** non comptée | la dérive mesurée le 23/09 chute d'un coup après la première prise (§ 5 et § 6) : la chauffe l'absorbe |
| **60 s de mesure**, 30 s de chauffe du banc, **90 s** sans Godot | inchangés : toutes les séries de référence sont faites ainsi, et le repos de 90 s est ce qui rend trois prises comparables (§ 6 : enchaînées, le 1 % bas s'effondre d'un facteur quatre) |
| **Repos initial 5 min** au lieu de 20 | ce que les 20 minutes protégeaient (la première prise), la chauffe et les 90 s le font ; et l'état thermique du Mac est désormais **lu** avant chaque prise au lieu d'être supposé refroidi (Mac sans ventilateur, § 9) |
| La **prolongation** : un bloc `B A` si le rapport est dans [0,958 ; 0,982] | ± 1 image à 85 (la résolution de la médiane) : c'est là qu'une image de bruit peut tourner le verdict. `B A` et pas `A B` : il ramène les positions moyennes à 4,5 et 4,5, le miroir exact. Jamais un second bloc : ce serait chercher le verdict |
| L'équilibre de Claude Helper, la porte, les reprises : **inchangés** | l'ordre 432, tel que `serie_mac_2.sh` l'a tenu ; le code de la porte est recopié à l'identique |
| Arbres dans `~/candela-arbres.noindex` | Spotlight n'indexe pas un dossier en `.noindex` ; l'import écrit des milliers de fichiers |

## 2. Le tri du cloud

`tools/cadence/tri_cloud.sh` (+ `tri.py`), sur l'outil de la session « Budget » (`tools/cloud_budget/`, recopié ici, un seul
ajout : il congédie l'intro). Pour chaque configuration : **un lancement** sous Xvfb (six cartes à 45° B et le pompe sous
une fusée, vue unique puis écran scindé ; captures des scènes ; `MESA_SHADER_CAPTURE_PATH`, le GLSL que Godot donne au
pilote). Puis `tri.py` compare à la référence :

1. **les comptes** — appels, primitives, vues rendues, copies d'écran, lumières à ombre ; médiane des six cartes, moyenne
   de 120 images au pompe ;
2. **les programmes de shader** — ceux qui n'existent pas dans la référence, compilés en SPIR-V et optimisés (glslang,
   `spirv-opt -O`), comparés au programme le plus proche : instructions, lectures de texture, boucles en plus ; et, pour
   un essai dont le coût est **derrière un uniforme** (aucun programme nouveau), le programme compilé uniforme à 0 puis à 1
   (`--plier=<nom>:<uniforme>`) : la branche que l'uniforme allume ;
3. **la part de l'écran** — les pixels des six cartes qui bougent de plus de 16/255 : une borne basse de ce qui est touché ;
4. **ce que le jeu dit** — les lignes d'état (`[mannequin] allumé …`) qui distinguent le lancement de la référence : la
   preuve que le drapeau a porté (ou l'aveu qu'il ne s'annonce pas).

### Les seuils, et d'où ils viennent

| classe | ce qui y mène | l'appui au Mac |
|---|---|---|
| **lourde** | plus de **+12 appels** par carte en vue unique (ou +24 en écran scindé) | les personnages détaillés : +12 appels, **0,976** — ils tiennent à 0,6 point de la barre ; au-delà, aucune preuve que la règle tienne |
| | une **vue rendue, copie d'écran ou lumière à ombre** de plus | une passe entière sur tout l'écran ; le premier masque, qui copiait l'écran : **0,943** |
| | les **primitives** de la scène au-delà de **+50 %** (et c'est de la géométrie : l'écran scindé se mesure) | les tuyaux, ×3, jamais mesurés |
| | un programme de shader qui ajoute une **boucle**, ou **4 lectures de texture** ou plus | le masque de la fumée : **zéro appel, et 0,838** |
| **à surveiller** | des appels au-dessus du bruit, jusqu'à +12 ; primitives +10 à +50 % | — |
| | un programme (ou une branche d'uniforme) qui ajoute **1 à 3 lectures**, ou **150 instructions** ou plus sans lecture | le mannequin : +252 instructions par pixel de corps, **0,989** (lot A) — il tient |
| **neutre** | rien au-delà du bruit, aucun programme ni branche au-delà de ces seuils | le faisceau (lot E) : **0,989** ; le rouge long : **1,024** ; la tenue sombre (branche d'uniforme d'une cinquantaine de lignes) : **1,034** |

**Le bruit** : deux lancements de la même tête, relevés par la session Budget et ici (témoins) : ±3 appels par carte en vue
unique, ±7 en écran scindé, ±3 au pompe en vue unique, **±20 au pompe en écran scindé** — les salves tirées au hasard y sont
dessinées deux fois. L'écart du pompe en écran scindé ne compte que **confirmé** par la vue unique du pompe ou par l'écran
scindé des cartes. Part de l'écran : 0,08 à 0,10 % entre deux lancements identiques.

@@CALIB@@

### (a) La prochaine version : `244cb88` contre `a30a407`

@@TRI_VERSION@@

### (b) Les essais candidats d'Adrien, chacun contre `1dc5ec8` sans lui

@@TRI_ESSAIS@@

## 3. La série courte : les essais du lanceur

| essai | commande | ce qui s'est passé | fichier |
|---|---|---|---|
| à blanc, refus refaits | `ESSAI_A_BLANC=1 FAUX_ETRANGER=25 FAUX_HELPER_FIXE=15` | dix refus (un indexeur au-dessus de 20 %), chacun refait **à sa place**, jusqu'à la quatrième reprise ; verdict « B TIENT » | `essais/blanc_refus_refaits.txt` |
| à blanc, prolongation | `FAUX_RAPPORT=0.975 FAUX_HELPER_FIXE=15` | rapport 0,965 : verdict marqué **provisoire**, un bloc `B A`, verdict final sur quatre prises par bras | `essais/blanc_prolongation.txt` |
| à blanc, ne tient pas | `FAUX_RAPPORT=0.93` | 0,953, sous la bande de prolongation : « B NE TIENT PAS », pas de bloc de plus | `essais/blanc_ne_tient_pas.txt` |
| à blanc, bras déséquilibrés | charges tirées au hasard | Claude Helper à 3 points d'écart : **SANS VERDICT** | `essais/blanc_desequilibre.txt` |
| à blanc, cinq refus | `FAUX_HELPER=100` | la même prise refusée cinq fois : **série arrêtée sans verdict** | `essais/blanc_cinq_refus.txt` |
| à blanc, Mac chaud | `FAUX_THERMIQUE=2` | attente de dix minutes, puis **arrêt** | `essais/blanc_thermique.txt` |
| **le vrai banc sous Xvfb** | `ESSAI_CLOUD=1 SECONDES=5 FAUX_HELPER=1 FAUX_ETRANGER=1`, arbres préparés par `--preparer` | les deux arbres (a30a407, 244cb88) importés hors série ; treize lancements de `bench_framerate.tscn` dans le bon arbre ; les preuves tenues à chaque prise (« Rendu : iso lacet 45° B », « slugs pompe / pompe », lignes d'état identiques au sein d'un bras, hash relu avant et après) ; six refus simulés refaits à leur place ; **SANS VERDICT**, comme il se doit sur des cadences du cloud (7 à 8 images/s, les A à 14 % l'une de l'autre) | `essais/cloud_xvfb_serie.txt`, une prise entière : `essais/cloud_xvfb_prise_04_A.txt` |
| arbre modifié | `ESSAI_CLOUD=1` sur les arbres du tri (où le photographe est corrigé, donc un fichier suivi modifié) | `✗ bras A : l'arbre /tmp/candela-arbres/a30a407a0c20 a des fichiers suivis modifiés`, avant toute prise | — |

⚠️ **Les cadences de l'essai du cloud (7 à 8 images par seconde, 1 % bas 0) ne valent rien** : elles ne sont là que pour
montrer que le lanceur lit ce que le banc imprime.

Ce que l'essai du cloud **n'a pas pu** vérifier : `top` et `osascript` sous macOS (le format de `top -l 2` et la lecture par
préfixe sont repris tels quels de `serie_mac_2.sh`, qui a tourné sur le Mac ; l'état thermique est la commande du § 9 du
document de mesure, « essayée le 2026-09-23 : rend bien 0 »).

## 4. Pièges découverts (à reporter dans la feuille de route)

1. **Modifier un script bash pendant qu'il tourne lui fait exécuter du texte décalé.** Bash lit un script au fil de
   l'exécution, par décalage d'octets. Retoucher le lanceur pendant l'essai du cloud a produit « rendre: command not found »,
   puis une septième prise qui n'était pas dans l'ordre — et la série aurait pu rendre un verdict sur un ordre faux. Remède,
   dans les deux outils : tout le corps dans un bloc `{ … exit; }`, que bash lit en entier avant la première ligne. **Vaut
   pour tout lanceur de série** : sur le Mac, ne jamais éditer (ni `git pull`) l'arbre d'un lanceur pendant qu'il tourne —
   d'où l'arbre `outil` à part dans la fiche.
2. **Le bruit du pompe en écran scindé est d'environ ±20 appels, pas ±8.** Deux lancements de a30a407 : +11,4 ; a30a407
   contre 244cb88, dont le monde 2D est le même : +18,8, tout entier dans les étincelles des deux lightmaps, et +0,6 en vue
   unique. Un écart du pompe en écran scindé ne se lit que confirmé ailleurs.
3. **Un coût derrière un uniforme ne laisse aucune trace dans le GLSL compilé** (le § 11 du document de mesure, retrouvé par
   l'outil) : `--mannequin` ne fait naître aucun programme. Le **pliage** (l'uniforme remplacé par 0 puis par 1, la branche
   morte élaguée par `spirv-opt`) rend ce coût comptable : +252 instructions par pixel de corps. Il faut nommer l'uniforme,
   ce que seul le code dit.
4. **`pkill -f <motif>` tue le shell qui le lance** si sa propre ligne de commande contient le motif (payé ici : le shell de
   la session a été tué). Cousin du piège de `pgrep -f` relevé par la session Budget.
5. **Deux Godot dans le même conteneur** : la garde « aucun Godot ouvert » du lanceur voyait le Godot du tri et attendait
   sans fin. Dans le cloud (`ESSAI_CLOUD=1`), elle ne guette plus que les Godot lancés sur ses propres arbres ; **sur le Mac,
   tout Godot compte**, l'éditeur d'Adrien compris.
6. **`tools/cloud_budget/budget.gd` ne se charge pas seul sur cette branche** : il appelle `_lire_l_horloge()`, qui vient des
   corrections du photographe pour Xvfb (0c67705), absentes d'integration-iso14. Le tri les applique dans ses arbres de
   travail (non suivis, jamais commités) ; ne pas lancer `budget.tscn` depuis cette branche telle quelle.

## 5. Signalé, hors de ma tâche (non corrigé)

@@SIGNALE@@

## 6. Ce que je n'ai PAS pu prouver

- **Aucune cadence.** Pas un chiffre d'images par seconde de ce rapport n'est une mesure. Le tri compte ; il ne dit pas
  combien de millisecondes vaut ce qu'il compte sur le GPU d'Apple.
- **Que les seuils du tri classent juste.** Ils sont tirés de six mesures du Mac (corps détaillés, masque et sa bande,
  premier masque, mannequin, faisceau, rouge long, tenue sombre) ; c'est peu. Chaque série courte à venir est un point de
  plus : si une version classée « neutre » échoue, les seuils sont à revoir, et c'est écrit dans la règle.
- **Que la série courte ait la résolution annoncée.** Trois prises par bras suffisent si la dispersion reste celle des
  séries passées (0 à 2 images) ; une série où les A s'écartent de plus de 5 % rend « sans verdict », elle ne ment pas.
- **`top` et `osascript` sous macOS**, dans ce lanceur : repris tels quels de ce qui a tourné sur le Mac, jamais exécutés ici.
- **Que 5 minutes de repos initial suffisent.** C'est une décision, appuyée sur la chauffe non comptée, le repos de 90 s
  et la lecture de l'état thermique ; la première série courte le dira (la chauffe et `01_A` ne doivent pas s'écarter des
  autres A de plus que la dispersion habituelle).
- **Les coûts par pixel au-delà du nombre d'instructions** : une lecture de texture ou une boucle ne coûtent pas le même
  prix partout ; le compte statique ne voit ni la divergence des branches, ni le cache, ni la bande passante. Le compte
  d'un programme ne dit pas non plus combien de pixels l'exécutent (la « part de l'écran » n'en est qu'une borne basse :
  une image identique peut coûter plus cher).
- **Les uniformes non nommés** : le pliage exige de savoir quel uniforme un drapeau allume. Je l'ai lu dans le code pour
  les essais de (b) ; un essai à venir dont on ne nomme pas l'uniforme passera « neutre » s'il n'ajoute ni programme ni
  appel (l'outil le signale quand l'image change).
- **Les écarts limités à la scène du tri** : six cartes, deux joueurs immobiles, torches allumées ; et le pompe sous une
  fusée sur l'Arène Standard. Un essai qui ne se montre qu'ailleurs (une autre carte, un gadget, la killcam) n'y paraît pas.

## 7. Tout refaire

```bash
# Outillage (une fois) : Godot 4.7 officiel en /usr/local/bin/godot, Xvfb, glslang-tools, spirv-tools, Pillow, numpy
git fetch origin integration-iso14 claude/cloud-integration-blanc claude/cloud-ecart-11 claude/cloud-photographe main

# Le tri (a) : la version candidate contre la référence (≈ 25 min, trois lancements : A, témoin, B)
ARBRES=/tmp/candela-arbres tools/cadence/tri_cloud.sh a30a407 244cb88 /tmp/tri/version
# Le tri (b) : chaque essai contre la même tête sans lui (≈ 7 min par lancement ; un lancement déjà fait est sauté)
PLIER="mannequin:mannequin encre:pate_hachures lampe-claire:lampe_claire" \
ARBRES=/tmp/candela-arbres tools/cadence/tri_cloud.sh --essais 1dc5ec8 /tmp/tri/essais \
  "faisceau=--faisceau" "mannequin=--mannequin" "pochoirs=--pochoirs-essai" "encre=--encre-essai" \
  "tuyaux=--tuyaux-essai" "enseignes=--enseignes-essai" "murs-meubles=--murs-meubles-essai" \
  "sol-marque=--sol-marque-essai" "corps-soi-sombre=--corps-soi-sombre" "lampe-claire=--lampe-claire" \
  "masque-V5=--fumee-masque-ajuste" "calib-masque-bande=--fumee-masque" "calib-corps-detaille=--corps-detaille" \
  "calib-rouge-long=--fusee-rouge-long"
@@REFAIRE_CALIB@@
# Le lanceur de la série courte, sans le Mac
ESSAI_A_BLANC=1 FAUX_RAPPORT=0.975 FAUX_HELPER=0 FAUX_ETRANGER=0 FAUX_HELPER_FIXE=15 \
  tools/cadence/serie_version.sh a30a407 244cb88 /tmp/essai-blanc
GODOT=godot ARBRES=/tmp/serie-arbres tools/cadence/serie_version.sh --preparer a30a407 244cb88
ESSAI_CLOUD=1 SECONDES=5 FAUX_HELPER=1 FAUX_ETRANGER=1 GODOT=godot ARBRES=/tmp/serie-arbres \
  xvfb-run -a -s "-screen 0 1920x1080x24" tools/cadence/serie_version.sh a30a407 244cb88 /tmp/essai-cloud
```

## Les fichiers

- `docs/iso/cadence_par_version.md` — la règle.
- `tools/cadence/serie_version.sh` — la série courte (Mac) ; `tools/cadence/tri_cloud.sh`, `tools/cadence/tri.py` — le tri
  (cloud) ; `tools/cloud_budget/` — l'outil Budget recopié (+ le congé de l'intro).
- `docs/iso/cloud/cadence-version/tri_version/`, `tri_essais/` — `TRI.md` (les tableaux), `tri.json` (tout), `journaux/`
  (les lignes `BUDGET` de chaque lancement, d'où `tri.py` refait les comptes) ; `images/` — ce qui a été compté.
- `docs/iso/cloud/cadence-version/essais/` — les sorties des essais du lanceur.
