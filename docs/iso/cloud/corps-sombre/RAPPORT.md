# Q39 sur image — son propre corps, sombre avec un liseré (session cloud corps-sombre, 2026-09-28)

Branche `claude/cloud-corps-sombre`, partie d'`origin/integration-iso14` (a30a407). **Rapport en cours** : ce premier
commit porte le plan ; le rapport complet le remplacera.

## Ce que fait le jeu aujourd'hui (lu avant de coder)

- Son propre corps (le voxel de sa classe, `corps_iso.gdshader`) est composé, dans SA vue seulement, avec la silhouette de
  la vue de dessus : `visual_dim` (`player.gd:608`), la couleur du joueur (`Charte.BLEU` éclaircie par
  `TEINTE_VERS_BLANC`, J2 `Charte.ROUGE`) à l'opacité 0,5 fois son opacité rendue
  (`Presentation3D.silhouette_du_corps`). Le shader pose `ALBEDO = (c·o·(1−s) + sil·s)/a`, `a = 1−(1−o)(1−s)` : à o = 1,
  s = 0,5, le corps est **moitié corps éclairé, moitié couleur du joueur**, à toute lumière. Dans le noir il vaut donc la
  moitié de sa couleur (la « silhouette de soi », 125/255 mesurés par ISO2b) ; sous la lampe il garde cette teinte.
- **Pourquoi** (ROADMAP, décisions actées, 2026-09-14 au soir, Adrien : « oui ») : en vue de dessus, `visual_dim` fait
  qu'on se voit toujours ; en iso, son corps était noir hors lumière — on se perdait. ISO2b a repris la même valeur, « aucune
  constante neuve ». Dans la vue d'en face, `silhouette_N` est transparent : l'adversaire ne voit que le corps éclairé.
- C'est ce qui donne le corps bleu glacier uni (~138) relevé par la session « écart aux illustrations » (manque n° 2) et
  par Q33 (signal 1 : la prise réelle et la prise forcée en pleine lumière du corps de soi ont le même nombre de pixels).

## Le plan

1. **Le drapeau `--corps-soi-sombre`**, éteint par défaut, lu comme `--mannequin` (`VoxelCatalogue`, `forcer_…` pour les
   suites). Il ne touche que la branche du shader où `silhouette_N` est non nul — c'est-à-dire le corps de soi dans sa
   propre vue ; la vue d'en face ne passe jamais par elle (s = 0). Rien dans la simulation, rien dans `Protocol`.
2. **L'essai, dans `corps_iso.gdshader`** : au lieu du mélange à 50 % avec la couleur du joueur,
   - le corps éclairé, assombri (cible ~50 en pleine lumière, comme les illustrations) ;
   - un **liseré clair du côté d'où vient la lumière réelle** : la direction dominante calculée par
     `MannequinIso.direction_dominante()` (Light2D du jeu : torche, fusée, torche adverse ; murs compris), réutilisée
     telle quelle, et une intensité lue dans le capteur du corps de ce côté — pas de lumière, pas de liseré ;
   - **dans le noir complet, un repère minimal** : un liseré ténu à la couleur du joueur sur le contour du corps, pour se
     retrouver toujours (la raison d'être de la silhouette de soi).
3. **La garde headless** : drapeau éteint, le shader rend au bit la même chose (branche uniforme non prise) et
   l'uniforme reste à 0 ; allumé, la vue d'en face est inchangée.
4. **Les mesures sur image** (Xvfb, photographe/`photo_essais`) : contraste du corps local contre le sol dans le noir, au
   bord de la lumière, en pleine lumière, sous une fusée ; aujourd'hui et avec l'essai ; lacet 45° B et écran scindé ; la vue
   de l'adversaire comparée au pixel ; le noir absolu (0 pixel allumé hors du corps local).
5. **La planche** : trois ou quatre classes, aujourd'hui / l'essai, 1:1 et loupe ×3, à côté d'`ill_accueil`,
   `ill_ecran_scinde`, `ill_entrainement`.
