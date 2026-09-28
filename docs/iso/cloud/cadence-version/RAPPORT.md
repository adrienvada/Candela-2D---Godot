# Mesurer la cadence par version — rapport de la session cloud « cadence-version »

> Branche `claude/cloud-cadence-version`, partie de `origin/integration-iso14` (`a30a407`), 2026-09-28, de 06:41 à
> ~09:55 (Paris). **État : fait.** Rien ne change dans le jeu : une règle, deux outils, leurs essais, les tableaux du tri.

## Pour Adrien, en cinq lignes

1. Désormais, ton Mac ne mesure plus chaque idée une par une : il mesure **le jeu tel qu'il sera livré**, une fois par
   nouvelle version, contre la précédente, en **une demi-heure** au lieu d'une heure et demie.
2. Avant, le cloud **trie** les nouveautés sans chronomètre (ce qu'elles ajoutent à dessiner) ; je l'ai vérifié sur six
   nouveautés déjà mesurées sur ton Mac : il les range toutes du bon côté.
3. La prochaine version (les gadgets de la fusée et les personnages détaillés, éteints) est **neutre** : rien de plus à
   dessiner. C'est la première à mesurer, a30a407 contre elle ; la fiche est juste en dessous.
4. Parmi tes essais, **gratuits** : le faisceau, les pochoirs, le sol marqué, ton personnage sombre. **Un peu chers** : le
   mannequin, la lampe claire, les enseignes. **Lourds** : l'encre, les tuyaux, les murs meublés et le masque V5 (lequel
   est pourtant quatre fois plus léger que celui qui avait échoué).
5. Si une version ne tient pas, on enlève d'abord la nouveauté la plus lourde et on refait une demi-heure — jamais plus
   une série par idée.

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

`docs/iso/cadence_par_version.md`, écrite **avant** les outils (commit `f6e8754`, 06:47 à Paris, avant le premier outil), le texte qu'Iso 1 portera dans la
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

### Le calibrage : ce que le tri dit des nouveautés déjà mesurées au Mac

Avant de croire le tri sur l'inconnu, je l'ai passé sur ce que le Mac a déjà tranché (même tête `1dc5ec8`, même
référence, mêmes seuils) :

| nouveauté | au Mac (règle 278) | le tri | accord ? |
|---|---|---|---|
| masque de la fumée et sa bande (`--fumee-masque`) | **0,838**, ne tient pas | **lourde** : un programme de 12 514 instructions, 98 lectures, 15 boucles, là où les volumes n'en avaient aucun ; zéro appel de plus | oui — et c'est le cas que les seuls comptes rataient |
| mannequin (`--mannequin`, lot A) | **0,989**, tient | **à surveiller** : +252 instructions par pixel de corps (branche de l'uniforme `mannequin`) | oui |
| faisceau (`--faisceau`, lot E) | **0,989**, tient | **neutre** : +3 appels (le bruit), aucun programme | oui |
| | détail des corps (`--corps-detaille`) | **0,976**, tient (0,6 point au-dessus) | **à surveiller** : +12 appels par carte (+24,5 en écran scindé), une boucle de plus dans le programme des corps (+226 instructions) | oui — après recalage (voir ci-dessous) |
| | rouge long (`--fusee-rouge-long`) | **1,024**, tient | **neutre** : rien au-delà du bruit, aucun programme | oui |
| usure (Q30, au défaut ; tri renversé : `--sans-usure` pris pour référence) | **0,944**, ne tient pas | **lourde** : une boucle de plus et +344 instructions dans les programmes du sol et des murs (`tri_essais/TRI_calibrage_usure.md`) | oui |

**Un recalage, avoué.** Au premier passage, le tri classait « lourd » le détail des corps lui-même : le seuil d'appels
était posé **exactement** sur sa valeur (+24, relevé +24,5 : un demi-appel de bruit), et toute boucle ajoutée comptait
« lourde ». Or le détail des corps et l'usure ajoutent chacun une boucle, et l'un tient (0,976) quand l'autre échoue
(0,944) : la différence est la **surface** — les corps font quelques pour cent de l'écran, le sol et les murs presque tout.
D'où les deux règles écrites dans `tri.py` : le seuil d'appels est l'écart du détail des corps **plus le bruit** (+15, +31),
et une boucle dans le programme des corps (reconnu à ses uniformes `portrait`, `mannequin`) est « à surveiller », ailleurs
« lourde ». Recalé sur des mesures connues, donc à confirmer par les séries à venir.

Après ce recalage, le tri ne se trompe dans aucun sens sur ces six cas. Il ne voit pas pour autant le temps : il dit **où regarder**, et
la série courte tranche.

### (a) La prochaine version : `244cb88` contre `a30a407`

| version | classe | Δ appels, cartes U / S | Δ appels, pompe U / S | programmes de shader nouveaux | part de l'écran qui change |
|---|---|---|---|---|---|
| `244cb88` | **neutre** | +0 / +2 | +0,6 / +18,8 (hasard des salves, non confirmé) | **0** | 0,09 % (le témoin : 0,09 %) |

**Neutre : la série courte en vue unique suffit.** Git dit que trois shaders changent (`corps_iso.gdshader`,
`corps_iso_eclaire.gdshader` +35 lignes, `iso_corps_detail.gdshaderinc` +23 / −4, sans lecture de texture ni boucle
ajoutées) ; **le GLSL compilé, lui, ne change pas** : ces lignes sont sous `CORPS_DETAIL`, éteint par défaut. Ce que la
version change par défaut (le point de braise rouge de la fusée) passe par des couleurs, pas par du code. Le jeu n'imprime
aucune ligne d'état qui distingue les deux têtes : la preuve de la tête, pour cette série, reposera sur le hash de l'arbre.
Tableaux et journaux : `tri_version/`.

⚠️ Le seul écart au-dessus du bruit connu (+18,8 appels au pompe en écran scindé) est tout entier dans le monde 2D des deux
lightmaps, là où vivent les étincelles, et absent de la vue unique : c'est lui qui a fait relever le bruit du pompe en écran
scindé (piège 2).

### (b) Les essais candidats d'Adrien, chacun contre `1dc5ec8` sans lui

Même tête, `1dc5ec8` (écart 11, où tous les essais sont fusionnés), lancée sans puis avec le drapeau. « U » vue unique, « S »
écran scindé ; appels : médiane des six cartes, et moyenne de 120 images au pompe sous une fusée. « Pire programme » : ce que
le programme le plus changé ajoute (instructions / lectures de texture / boucles), après optimisation.

| essai | **classe** | Δ appels cartes U / S | Δ appels pompe U / S | Δ primitives | pire programme | part de l'écran | pourquoi |
|---|---|---|---|---|---|---|---|
| Q37 `--faisceau` | **neutre** | +3 / +5 | +1,3 / +7,7 | +0,1 % | — | 0,10 % | un quad par torche dans un programme existant ; **0,989 au Mac** (lot E) |
| Q37 `--pochoirs-essai` | **neutre** | +0,5 / +1,5 | −0,7 / −0,9 | 0 | — | 0,09 % | cuits dans le décor ; rien par image |
| Q37 `--sol-marque-essai` | **neutre** | +1 / +1,5 | −0,2 / +8,6 | 0 | — | 0,08 % | cuit dans le décor ; rien par image |
| Q39 `--corps-soi-sombre` | **neutre** | +0 / +1,5 | −0,6 / +6,5 | 0 | +136 / 0 / 0 (corps) | 0,28 % | une variante des corps, +136 instructions sur les pixels de son propre corps |
| Q37 `--mannequin` | **à surveiller** | +0 / +0,5 | −0,6 / +3,9 | 0 | +252 / 0 / 0 (branche de l'uniforme) | 0,09 % | coût caché derrière un uniforme, sur les corps ; **0,989 au Mac** (lot A) |
| Q40 `--lampe-claire` | **à surveiller** | +1 / +0,5 | −0,4 / +10,5 | 0 | +156 / **+2** / 0 (branche de l'uniforme) | **6,3 %** | deux lectures de texture de plus, sur toute la lumière du sol |
| Q37 `--enseignes-essai` | **à surveiller** | +1 / +3,5 | −0,1 / +5,5 | +0,2 % | shader neuf : 1 138 / 15 / 0 | 0,10 % | un shader neuf, moins lourd que le sol, sur peu de pixels |
| Q37 `--encre-essai` | **lourde** | **+20 / +40,5** | −1,3 / +2,8 | +3,9 % | +170 (contour neuf) ; +66 au sol | 0,15 % | le contour des corps est une passe de plus par pièce : plus d'appels que le détail des corps |
| Q37 `--tuyaux-essai` | **lourde** | +1 / +5 | +0,2 / +11,7 | **+222 %** | shader neuf : 1 156 / 14 / 0 | 0,14 % | géométrie ×3 : **écran scindé à mesurer** |
| Q37 `--murs-meubles-essai` | **lourde** | +5,5 / +9 | +3,7 / +20,6 | **+116 %** | shader neuf : 1 156 / 14 / 0 | 0,19 % | géométrie ×2 (il pose des tuyaux et des enseignes) : **écran scindé à mesurer** |
| V5 `--fumee-masque-ajuste` | **lourde** | +1 / +2 | +0,5 / +5,3 | 0 | **3 486 / 23 / 7** | 0,07 % | sept boucles sur les volumes ; mais **3,6 fois moins d'instructions et 4 fois moins de lectures** que la bande (12 514 / 98 / 15, **0,838** au Mac) |

**Ce qui est gratuit, pour Adrien, avant de dire oui** : le faisceau, les pochoirs, le sol marqué, le soi-sombre — rien
de plus à dessiner, presque rien de plus par pixel. Le mannequin, la lampe claire et les enseignes coûtent un peu par
pixel : ils entrent dans une version sans série à eux, et la série de cette version dira s'ils passent. L'encre, les
tuyaux, les murs meublés et le masque V5 sont **lourds** : s'ils entrent dans une version et qu'elle échoue, c'est par eux
que la recherche de la coupable commencera — dans cet ordre de lourdeur : le masque V5 (des boucles sur les volumes), puis
les tuyaux et les murs meublés (la géométrie, à mesurer aussi en écran scindé), puis l'encre (des appels).

Le jeu **s'annonce** pour quatre drapeaux seulement (faisceau, mannequin, et les deux du masque) ; les huit autres
n'impriment rien (§ 5). Pour les pochoirs et le sol marqué, rien dans ce tri ne prouve qu'ils étaient posés : zéro partout
peut aussi vouloir dire « pas là » (le zéro vide du § 15 du document de mesure).

Images (`tri_essais/images/`, la carte où l'image change le plus : référence | essai | pixels qui changent, en magenta) :
`lampe-claire.jpg` (6,3 % de l'écran : toute la flaque de lumière), `tuyaux.jpg`, `murs-meubles.jpg`, `encre.jpg`,
`corps-soi-sombre.jpg`. Tableau complet, programme par programme : `tri_essais/TRI.md` ; tout : `tri_essais/tri.json`.

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

## La suite

`GODOT=/usr/local/bin/godot ./tools/run_suites.sh` sur cette branche (`7c73359` + le tri, rien du jeu touché) : **142 bancs
OK, « tout passe, sans erreur de script (651 s) », EXIT 0.**

## 5. Signalé, hors de ma tâche (non corrigé)

- **Huit essais sur douze ne s'annoncent pas dans le journal** : `--pochoirs-essai`, `--encre-essai`, `--tuyaux-essai`,
  `--enseignes-essai`, `--murs-meubles-essai`, `--sol-marque-essai`, `--corps-soi-sombre`, `--lampe-claire` n'impriment
  aucune ligne d'état (contrairement à `[faisceau] allumé`, `[mannequin] allumé`, `[fumée masque] …`). Pour une série par
  version, ce n'est pas bloquant (la preuve est l'arbre) ; mais le jour où l'un devient un défaut, la série ne pourra pas
  **lire** dans le journal qu'il est allumé. Le plan « série-essais » (`c0e98a7`) prévoyait de leur donner une ligne : à
  reprendre par leurs auteurs. Reproduire : `grep '^\[' docs/iso/cloud/cadence-version/tri_essais/journaux/<essai>.log`.
- **`--encre-essai` : +20 appels sur les cartes, 0 au pompe sous la fusée.** Le contour des corps (`voxel_corps.gd:323`,
  `definir_contour` → `next_pass`) ajoute une passe par pièce de corps sur les cartes (pistolet), et rien au pompe. Je n'ai pas
  cherché pourquoi (le kit du pompe ? le moment où le corps est construit ?) : à regarder avant de le mesurer. Reproduire :
  comparer `tri_essais/journaux/encre.log` et `ref.log`, lignes `· carte` et `· pompe`.
- Deux `.uid` non suivis (`tools/banc_equite_fusee.gd.uid`, `volume_masque.gdshaderinc.uid`) apparaissent à l'import
  d'integration-iso14 : d'autres branches les versionnent déjà, avec des valeurs différentes (conflit tranché à
  l'écart 11) ; je ne les ai pas commités, pour ne pas en ajouter une troisième.

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
# Le calibrage de l'usure (tri renversé : la référence SANS usure, la tête au défaut comme variante)
TEMOIN=0 ARBRES=/tmp/candela-arbres tools/cadence/tri_cloud.sh --essais 1dc5ec8 /tmp/tri/essais "calib-sans-usure=--sans-usure"
mkdir -p /tmp/tri/usure && for d in journaux glsl captures glsl_compte; do ln -sfn /tmp/tri/essais/$d /tmp/tri/usure/$d; done
python3 tools/cadence/tri.py /tmp/tri/usure calib-sans-usure ref
# La suite complète
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
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
