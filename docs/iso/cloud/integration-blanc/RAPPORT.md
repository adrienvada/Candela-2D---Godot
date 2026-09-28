# Intégration à blanc — iso11-menus + iso12-corps dans integration-iso14

> Session cloud, branche `claude/cloud-integration-blanc`, ouverte le 2026-09-28 à 02:04 (Paris).
> **En cours** — ce fichier est le plan ; il sera complété au fil des étapes.

## Plan

1. Base : `origin/integration-iso14` (a30a407).
2. Fusionner `origin/iso11-menus` (0568441), puis `origin/iso12-corps` (cef9d93).
   Ancêtres communs trouvés sans approfondir le clone : 28152c5 (iso11), 5d9ef55 (iso12).
   Chaque conflit : fichier, deux côtés, résolution, pourquoi.
3. Inventaire par `git diff` de ce que chaque branche ajoute (fonctions, drapeaux,
   constantes), puis `grep` après fusion : rien ne doit manquer.
4. Valeurs par défaut d'integration-iso14 à conserver : lacet 45° « B », usure au
   défaut, décalage 0,15, zoom ×1,5 (`ZOOM_DUEL_DEFAUT`).
5. Suite complète headless verte ; planche courte au photographe (45° B, torches
   allumées/éteintes, une fusée), corps détaillé et rouge long éteints.
6. Corrections du photographe pour le cloud : commit à part, APRÈS les fusions,
   à ne PAS reprendre par Iso 1.
