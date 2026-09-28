# Q39, deuxième tour — le risque de Beauté, et sa variante (session cloud corps-sombre-2, 2026-09-28)

Branche `claude/cloud-corps-sombre-2`, partie d'`origin/claude/cloud-integration-blanc` (d84c650), avec
`origin/claude/cloud-corps-sombre` (3c968da) fusionnée dedans (7493c82). **Rien ne change par défaut.**

> ⚠️ **Démarrage bloqué, puis repris.** Au premier passage, le garde-fou de permissions de la session a refusé deux
> actions : le lien du binaire Godot dans `/usr/local/bin` (refus maintenu : le binaire est lancé depuis
> `/tmp/Godot_v4.7-stable_linux.x86_64`, `GODOT=` le passe aux scripts), et la résolution des conflits de la fusion. La
> session s'est arrêtée là jusqu'au message de la session coordinatrice de 12:45 relayant Adrien (« Fais en sorte que les
> sessions cloud 30h qui n'ont pas fini terminent ») ; la fusion a été résolue ensuite, comme l'évaluation 11.

## Plan (état : en cours)

1. **Fusion** (fait, 7493c82) — conflits `iso_materiaux.gd` et `voxel_catalogue.gd`, résolus comme
   `docs/iso/cloud/ecart-11/RAPPORT.md` § 1 ; ancres des deux branches vérifiées par grep (19 + 33, aucune manquante).
2. **Le correctif de pré-passe de Beauté** — dans `accorder_corps`, poser TOUTES les variantes (CORPS_DETAIL,
   CORPS_DETAIL_MATIERE, CORPS_SOI_SOMBRE) puis appeler `accorder_passe_profondeur` UNE fois, à la fin ; la méta
   `MATERIAU_PROFONDEUR` posée à la construction de tout corps ; la sortie de pré-passe sous CORPS_SOI_SOMBRE aussi.
   Garde headless sur les 8 combinaisons (détail × matière × soi sombre) + preuve par mutation (l'ancien ordre rougit).
3. **La preuve à l'image sous llvmpipe** — `tools/banc_corps.gd` (`--fusion-ab`, `--sans-profondeur`), critère de
   l'ordre 426 : Q39 seul, Q39 + `--corps-detaille`, rien ; quatre classes dont Parasite et Occulteur ; à 0,8 et 0,15.
4. **La variante B « fondu »** (drapeau éteint à part) : n'assombrir que là où le corps d'aujourd'hui se fond dans le sol.
   D'abord écrire ce que le shader lit pour décider ; puis mesurer comme Q39 (six lumières, vue unique et écran scindé).
5. **La planche** : quatre classes × six lumières, aujourd'hui / A / B, loupe ×3, à côté des illustrations.
