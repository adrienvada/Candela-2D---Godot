# La cadence de tous les essais, en une commande pour le Mac — rapport de la session cloud « série-essais »

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
