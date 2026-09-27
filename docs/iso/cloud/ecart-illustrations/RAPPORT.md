# L'écart du jeu à ses illustrations — rapport (en cours)

Session cloud `claude/cloud-ecart-illustrations`, lancée le 2026-09-27 par la
session coordinatrice « CLOUD ISO UNRAILED ». Base : `origin/integration-iso14` (60e5c6d).

## Plan

1. Fusionner dans cette branche, dans l'ordre : `origin/claude/cloud-essais`,
   `origin/claude/cloud-enseignes`, `origin/claude/cloud-fusee-rouge`. Vérifier
   par `grep` les points d'ancrage de chaque drapeau d'essai ; suite complète verte.
2. Décrire chacune des vingt illustrations `assets/ui/ill_*.png`.
3. Pour chacune, monter la scène de jeu la plus proche (photographe ou héritier),
   deux prises au même instant : jeu par défaut / tous les essais allumés
   (1920×1080, lacet 45° B, zoom ×1,5), sous Xvfb.
4. Tableau par illustration : présent / apporté par les essais / manquant, et
   compatibilité de chaque manque avec les invariants (noir absolu, équité,
   règle des pochoirs).
5. Synthèse : les cinq manques qui changeraient le plus l'image, coût en dessins
   (méthode de `origin/claude/cloud-budget`), décision d'Adrien requise ou non.
6. `planche.html` autonome + images JPEG.
