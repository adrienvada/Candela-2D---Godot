# La cadence de tous les essais, en une commande pour le Mac — rapport de la session cloud « série-essais »

> ## ⛔ TÂCHE ARRÊTÉE (28/09, ~12:45, Paris)
>
> Arrêtée par la décision d'Adrien du 28/09 vers 06:35 : « Mesurons par version, plus par nouveauté. Trions avec le cloud
> avant le Mac. Faisons des séries plus courtes. » La session « Cadence par version » (`origin/claude/cloud-cadence-version`)
> a repris ce qui servait de plan ici. **Le lanceur de cette branche n'est PAS prêt pour le Mac** et ne doit pas y être lancé
> tel quel : ni garde headless, ni suite complète, ni essai `ESSAI_CLOUD=1` du lanceur lui-même.
>
> ### Ce qui reste utile
>
> 1. **Huit lignes d'état**, une par essai, imprimées seulement drapeau allumé, là où l'essai S'APPLIQUE (variante posée,
>    triangles posés) : `[encre] allumée — variante ENCRE_ESSAI posée (#define …)`, `[corps soi sombre] allumé — variante
>    CORPS_SOI_SOMBRE posée (#define …)` (`iso_materiaux.gd`) ; `[lampe claire] allumée — posée sur le sol et les murs`
>    (`lampe_claire.gd`) ; `[pochoirs] allumés — N pochoir(s) sur la carte « id »`, `[sol marqué] allumé — N marque(s) …`
>    (`arena_decor.gd`) ; `[tuyaux]`, `[enseignes]`, `[murs meublés] allumés — N triangles sur la carte « id »`
>    (`TuyauxIsoT.ligne_etat`). Avec `[faisceau]` et `[mannequin]` (déjà là), les dix essais se prouvent par le journal.
>    ⚠ **Sans garde headless et non passées par la suite complète** : à faire avant de les fusionner.
> 2. **Les dix essais, lancés SEULS, marchent sur le vrai banc sous Xvfb** : ligne imprimée, vue iso tenue, « iso lacet 45° B »,
>    Arène Standard (`00000001`, la carte que le banc prend toujours : `MapData` ne garde pas la sélection). Comptes du banc
>    (valables dans le cloud) plus bas : **pochoirs et sol marqué n'ajoutent ni appel, ni objet, ni primitive** ; tuyaux
>    +10 384 primitives (18 080 contre 7 696), murs meublés +7 560 (15 256) et +4 appels, faisceau +2 appels, enseignes +1 ;
>    encre, lampe claire, mannequin, corps sombre : aucun compte ne bouge (leur prix est dans le shader, Mac seulement).
> 3. **Le bras « tout » éteint la vue iso dans le cloud** (un seul lancement, non refait). Commande exacte :
>
>    ```
>    xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tools/bench_framerate.tscn -- --seconds 5 --max-fps 0 \
>      --fusee --vue-unique --classe=pompe --faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai \
>      --enseignes-essai --murs-meubles-essai --sol-marque-essai --corps-soi-sombre --lampe-claire
>    ```
>
>    Symptôme (journal dans `releves/tout_extinction.txt`) : la vue iso s'allume normalement, puis PENDANT les 30 s
>    d'échauffement le jeu imprime `[iso] les vues à projeter changent : mode_iso=true, jeu=true, joueurs=true, caméras=true,
>    menu=true, SubViewport1=true, SubViewport2=false` — c'est **`menu=true`** (`ui._is_main_menu` vrai : l'interface se croit
>    revenue au menu principal) qui fait retirer la vue (`[iso] peinture retirée`, `[iso] vue isométrique éteinte`) ; la mesure
>    tourne ensuite en 2D et le banc refuse lui-même son chiffre : `✗ --iso : la vue isométrique était éteinte sur 54 image(s)
>    mesurée(s) : chiffre refusé`. **Aucune erreur de script ni de shader.** Le même banc SANS essai (M0) et chacun des dix
>    essais seul gardent la vue iso. Ce n'est donc pas un essai isolé ; soit une combinaison, soit la lenteur du rendu logiciel
>    (≈ 8 à 11 images/s ici) qui ferait passer le banc par un état de menu — **non tranché**. Ce lancement avait lieu AVANT
>    l'ajout des lignes d'état (elles n'y sont pour rien). À refaire d'abord (le reproduire), puis par moitiés.
> 4. **Le lanceur** `tools/serie_essais/serie_mac_essais.sh` (séries A par pixel, B géométrie + TOUT, C écran scindé ; porte
>    de l'ordre 432 ; vérification de 5 s AVANT les 20 min de repos ; chaque bras prouvé par ses lignes et par l'ABSENCE des
>    autres) : essai à blanc de la série A passé ; jamais lancé sur le vrai banc. Réutilisable pour les séries « par version ».
>
> ### Ce que je n'ai pas pu prouver
> - Aucune cadence (le cloud ne mesure pas le temps).
> - La cause de l'extinction du bras « tout », ni même qu'elle se reproduit.
> - Les lignes d'état ne sont couvertes par aucune garde ; la suite complète n'a pas tourné sur elles.
>
> **Piège à reporter** : un banc qui repasse au menu en cours de chauffe ne crie pas — seule la ligne `✗ --iso … chiffre
> refusé`, en fin de sortie, le dit. Un lanceur doit refuser toute prise qui contient une ligne `✗` du banc.


> Branche `claude/cloud-serie-essais`, partie de `1dc5ec8` (`origin/claude/cloud-ecart-11`), 2026-09-28.
> **État : en cours — premier commit, le plan.** Rien ne change par défaut.

## Le plan (écrit avant de coder)

1. **Les bras.** M0 (aucun essai) ; un bras par essai candidat — `--faisceau`, `--mannequin`, `--pochoirs-essai`,
   `--encre-essai`, `--tuyaux-essai`, `--enseignes-essai`, `--murs-meubles-essai`, `--sol-marque-essai`,
   `--corps-soi-sombre`, `--lampe-claire` ; et un bras TOUT (les dix ensemble).
2. **La scène** : celle de la règle 278 (`bench_framerate.tscn --fusee --vue-unique --classe=pompe`, lacet 45° B, usure au
   défaut). La question de l'écran scindé pour les essais de géométrie est tranchée plus bas, après lecture des budgets.
3. **Les preuves** : aujourd'hui, seuls `--faisceau` et `--mannequin` impriment leur état au lancement. Les huit autres
   reçoivent une ligne d'état d'une ligne, dans le code de l'essai, et une garde headless qui la vérifie.
4. **Le lanceur** `tools/serie_essais/serie_mac_essais.sh`, calqué sur `tools/masque_fumee/serie_mac_2.sh` (ordre en miroir,
   chauffe, porte de l'ordre 432, verdict de la règle 278 bras par bras). Douze bras à quatre prises dépassent 1 h 45 :
   deux séries (A et B), chacune avec SA référence M0.
5. **Les essais à blanc** (`ESSAI_A_BLANC=1`), puis **sur le vrai banc sous Xvfb** (`ESSAI_CLOUD=1`).
6. **La fiche pour le Mac**, en tête de ce rapport.

## État à l'interruption (2026-09-28, travail en cours, commité pour ne rien perdre)

- **Lignes d'état ajoutées** (une par essai, là où l'essai s'applique) : `[encre] allumée`, `[corps soi sombre] allumé`
  (`iso_materiaux.gd`), `[lampe claire] allumée` (`lampe_claire.gd`), `[pochoirs] allumés — N pochoir(s)`, `[sol marqué]
  allumé — N marque(s)` (`arena_decor.gd`), `[tuyaux]` / `[enseignes]` / `[murs meublés] allumés — N triangles sur la carte
  « id »` (leurs fichiers). **La garde headless n'est pas encore écrite ; la suite complète n'a pas tourné sur ces lignes.**
- **Le lanceur** `tools/serie_essais/serie_mac_essais.sh` : séries A (par pixel : M0 FA MA EN CS LC, ~1 h 45), B (géométrie
  et TOUT : M0 TU EG MM TOUT, ~1 h 30), C facultative (écran scindé). Essai à blanc de la série A : 24 prises et la chauffe,
  refus refaits à leur place, verdict imprimé (« SANS VERDICT » par déséquilibre des fausses charges, comme prévu).
- **À éclaircir** : le bras TOUT, dans le cloud, a vu la vue iso s'éteindre pendant la chauffe (le banc a refusé son chiffre
  par « ✗ --iso ») ; M0 tient. Essais seuls en cours : faisceau, mannequin, pochoirs sans défaut ; les sept autres non faits.

### Les dix essais, chacun seul, sur le vrai banc sous Xvfb (5 s, cadences sans valeur)

Tous lancent, impriment leur ligne, restent en vue iso (aucun « ✗ » du banc), vue « iso lacet 45° B », sur l'Arène Standard
(`00000001`). Comptes du banc (médiane par image ; le cloud vaut pour les comptes, pas pour le temps), relevés dans `releves/` :

| essai | ligne imprimée | appels | objets | primitives |
|---|---|---|---|---|
| (référence de ces lancements) | — | 245 | 1 460 | 7 696 |
| pochoirs | 4 pochoir(s) | 245 | 1 460 | 7 696 |
| sol marqué | 48 marque(s) | 245 | 1 460 | 7 696 |
| encre, lampe claire, mannequin, corps soi sombre | variante posée / allumée | 245 | 1 460 | 7 696 |
| faisceau | allumé | 247 | 1 462 | 7 700 |
| enseignes | 4 triangles | 246 | 1 461 | 7 700 |
| tuyaux | 10 384 triangles | 246 | 1 461 | 18 080 |
| murs meublés | 7 560 triangles en 4 nœuds | 249 | 1 464 | 15 256 |

**Pochoirs et sol marqué : zéro appel, zéro objet, zéro primitive de plus** — ce qui justifie qu'ils n'aient pas de bras à eux
(ils sont dans TOUT). Les essais par pixel (encre, lampe, mannequin, corps sombre) ne changent aucun compte : leur prix est
dans le shader, que seul le Mac chiffrera. Reste inexpliqué : l'extinction de la vue iso dans le bras TOUT (un seul lancement).
