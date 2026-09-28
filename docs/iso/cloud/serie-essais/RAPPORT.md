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
