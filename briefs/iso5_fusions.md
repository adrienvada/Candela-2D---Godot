# ISO5 — les fusions de la vague « grand budget », puis ISO6, puis la fin (message de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 15/09/2026 à 08:30, sur mandat d'Adrien de 05:00)

Les quatre chantiers de la vague sont clos, chacun sur un lot complet vert, tous nés de `iso2-vues` à 953ead3 (ton commit 5398092 leur est postérieur, sans conflit attendu). Tu tiens `iso2-vues` : c'est toi qui fusionnes, une branche à la fois, dans cet ordre, et tu ne t'arrêtes pas entre deux.

## L'ordre et l'état des branches

1. `iso7-beaute` — HEAD **0cc300e** (f95cb16 murs et sol texturés ; 6e64afb pâte et lumière vue ; 0cc300e bancs, `pate_facteur`, plancher d'encre, planche_iso7.jpg). Tient `iso_pate.gdshaderinc`, `iso_pate.gd`, `iso_materiaux.gd`, `mur_iso.gdshader`, `sol_iso.gdshader`, `assets/iso/`, `tools/test_iso_beaute.gd`, `tools/banc_iso_beaute.gd`, `tools/verifie_tuilable.py`, `tools/fabrique_textures_iso.py`. Crochets à préserver : `presentation_3d.gd` (préchargement SHADER_SOL → sol_iso.gdshader ; `IsoMateriaux.accorder_mur(_mat_mur)`, `accorder_sol(mat)`, `accorder_grille(_mat_mur, data)`, `accorder_corps(mat)` dans `_accorder_le_slug`) ; `tools/run_suites.sh` (test_iso_beaute).
2. `iso-gadgets-lumieres` — HEAD **e280015** (331764b hauteur des sources, volumes, lueurs, miroirs ; e280015 banc et planches). Tient `gadget_*.gd` (image), `fusee.gd`, `miroirs_iso.gd`, `voxel_objet.gd`, `capteur_objet.gdshader`, `kill_shockwave.gd`, `iso_volumes.gd`, `volume_iso.gdshader`, `halo_iso.gdshader`, `tools/test_iso_gadgets.gd`, `tools/banc_iso_gadgets.gd`. Crochets : `murs_bas_zone.gdshaderinc` (trois uniformes et la règle de hauteur), `murs_bas_rendu.gd` (constante, hauteurs, `poser_hauteur_source`, jumelle, uniformes poussés), `gadget_braises.gd` et `gadget_mine.gd` (une ligne), `tools/test_murs_bas_rendu.gd`, `tools/run_suites.sh` (test_iso_gadgets). Aucune ligne dans presentation_3d.gd, game_state.gd, player.gd.
3. `iso-habillage` — HEAD **1ab8bb1** (b824335 charte ; 30297e7 hub ; 8d228f7 HUD ; c0dbcc0 killcam ; 1ab8bb1 fins). Tient `ui.gd` (aspect), `charte.gd`, `menu_theme.gd`, `menu_widgets.gd`, `menu_*.gd`, `menu_pate.gdshader`, `estampe_de_kill`, `affiche_de_fin`, `carte_de_soiree`, `cadre_photo`, `intro_planches`, la barre de `map_editor_hud`, `assets/ui/`, `tools/test_habillage.gd`, `tools/preparer_habillage.py`, `tools/fabrique_tampon_encre.py`. Crochet : `killcam_overlay.gdshader` reçoit deux uniforms (`trait_couleur` vec3, `virage` vec4, sans source_color, défauts = rendu d'origine), poussés par ui.gd depuis la charte ; le matériau est partagé avec ton calque iso.
4. `iso-corps` — HEAD **03ffdb6** (7a9291a vague 5 : squelette sur le gabarit du DA, `pointe_arme()` ; 36a982d pâte branchée : uniforms `encre_arete` / `encre_reste`, `VoxelCorps.definir_encre()` ; 03ffdb6 : l'encre passe par `pate_facteur`, `--encre=` sur le banc des corps). Tient `voxel_catalogue.gd`, `voxel_corps.gd`, `corps_iso.gdshader`, `corps_iso_profondeur.gdshader`, `tools/test_voxel_corps.gd`, `tools/banc_corps.tscn`.

## La méthode, pour chaque fusion

`git merge --no-commit --no-ff <branche>` ; conflits résolus en gardant les deux logiques ; **`iso_pate.gdshaderinc` et `iso_pate.gd` gardés à l'état de 0cc300e** (ISO Corps l'a repris à 03ffdb6, Gadgets a la base ; après chaque fusion : `git diff 0cc300e -- iso_pate.gdshaderinc iso_pate.gd` doit être vide) ; `--import` headless deux fois ; grep des ancrages des deux côtés (les crochets listés ci-dessus, tes propres fonctions d'ISO5, `MiroirsIso.SLUG_DU_CATALOGUE`, `IsoMateriaux.accorder_*`, `poser_hauteur_source`, `definir_encre`, `pointe_arme`) ; lot complet vert ; commit de fusion ; delta à la session cloud (hash, lot, crochets vérifiés). Un seul lot à la fois sur le Mac : les quatre sessions sont au repos, mais vérifie `pgrep -x Godot`.

## Après les quatre fusions, avant ISO6 (petits gestes, un commit « Raccords de la vague »)

- `volume_iso.gdshader` : ajouter `c = pate_temperature(c, temperature);` en fin de fragment, uniform réglé à `IsoMateriaux.TEMPERATURE` (les nuages prennent la teinte chaude du sol ; consigné par Gadgets).
- L'encre de la pâte sur les objets debout et le leurre : poser `pate_encre_boite` (par `pate_facteur`) dans le matériau des `VoxelObjet` (`miroirs_iso.gd` / `capteur_objet.gdshader`), comme ISO Corps l'a fait pour les corps ; noir absolu et équité inchangés (la suite le prouve).
- `halo_iso.gdshader` : si les lueurs paraissent ternes au banc, passer leur intensité par `pate_facteur` (Gadgets : l'alpha d'un mélange additif se voit ≈ à la puissance 2,4).
- Éclat de bouche : vérifier au banc qu'il part de `VoxelCorps.pointe_arme()` (branché par has_method).
- L'icône de torche du HUD est encore l'ancien pictogramme gris : demande-la à « ISO Assets Sonnet » par SendMessage (128 px, fond vert, pâte D, même famille que les dix icônes de gadget) et pose-la comme Habillage a posé les autres (`tools/preparer_habillage.py`).
- `sol_projete.gdshader` n'est plus préchargé par personne : retire-le du chemin iso s'il ne sert plus, garde-le pour la vue de dessus s'il y sert.
- Lot complet vert, commit, delta.

## Puis ISO6

Comme écrit dans `briefs/iso5_iso6.md` (`git show FETCH_HEAD:briefs/iso5_iso6.md`) : l'iso par défaut, `--2d` et drapeau de débogage, suites converties, photographe et banc en iso (le photographe reprend les 21 plans d'Habillage en vue iso : elle n'a que des captures en vue de dessus), F3 et F6, fantôme de killcam aligné sur l'étalon 2D, CLAUDE.md et ROADMAP réécrits, planche_iso6.jpg, commit, delta.

## Puis la fin

Planche finale (les deux vues, un duel avec tout : corps v5 encrés, murs et sol texturés, fusée en vol par-dessus un muret, fumées, HUD et killcam dans la pâte) ; message de fin à la session cloud avec la commande absolue, le code de la carte d'essai, la liste des planches et les points à juger de chaque chantier (ils sont dans les ROADMAP de chaque branche). La fusion de `iso2-vues` dans `main` se fera sur le mot de la session cloud, jamais de push. Ne finis jamais un tour en attendant : Monitor. Accuse réception à « Fable 5.1 - CLOUD ISO UNRAILED » dès la lecture de ce fichier.
