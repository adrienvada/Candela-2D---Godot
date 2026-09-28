# Le sol marqué, à l'essai — rapport (en cours)

Session cloud, branche `claude/cloud-sol-marque`, partie d'`origin/claude/cloud-ecart-illustrations` (f4039a0), le
28/09/2026. Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». Tâche : le manque n° 5 de
`docs/iso/cloud/ecart-illustrations/RAPPORT.md` — un sol jonché et marqué.

## Le plan

1. **Relevé, avant tout code** : illustration par illustration, ce qui est au sol (famille, taille, couleur, densité,
   emplacement : couloirs, salles, pieds de murs). Écartés d'emblée : les douilles de décor (fausse information) et tout
   marquage clair (le « ZONE 4 » blanc).
2. **L'essai `--sol-marque-essai`**, éteint par défaut, dans `arena_decor.gd` à côté des pochoirs : gravats, chaînes,
   bandes de marquage, lettres sombres, cuits dans la texture du décor (0 appel de dessin de plus), posés par une table
   écrite à la main pour les six cartes livrées, chaque marque avec son jumeau par la symétrie de la carte. Peinture
   noire translucide seulement (jamais plus clair que le sol), donc noire hors de la lumière.
3. **Preuves** : noir absolu (prises A, B, A' torches éteintes), jamais plus clair que le sol (au pixel, avec contre
   sans), symétrie J1/J2 à 45° B, comptes de dessin (outil `tools/cloud_budget/` de la session « Budget »), contraste
   d'un corps adverse au bord de la lumière sur sol nu et sol marqué.
4. **La planche** : par famille, l'illustration, le jeu sans, le jeu avec, 1:1 et loupe ×3 ; une vue d'ensemble avec
   tous les essais.
5. **Garde headless** : drapeau éteint, rien ne change au bit. Suite complète verte.

## État

- [ ] relevé
- [ ] drapeau et table
- [ ] garde headless
- [ ] prises et mesures
- [ ] planche
- [ ] suite complète
