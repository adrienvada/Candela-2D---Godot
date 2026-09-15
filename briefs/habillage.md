# HABILLAGE — HUD, menus, killcam et écrans de fin dans la pâte du DA (brief de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 15/09/2026 vers 05:25, sur mandat d'Adrien de 05:00)

Tu es « Habillage sonnet » (adresse ListAgents : habillage-sonnet-candela-6c2849-b8). Ta branche : `iso-habillage`, créée depuis `iso2-vues` (corps épais fusionnés depuis 26417a8). Ton worktree : `.claude/worktrees/iso-habillage`. Ta branche automatique `claude/habillage-sonnet-candela-6c2849` (issue de main) ne sert pas : laisse-la.

## L'objectif

Tout ce qui n'est pas la vue de jeu — le HUD de match, le hub et ses menus, le lobby, la killcam (planche, estampe de kill, bandeau, affiche de fin, bilan), les écrans de fin, l'intro — parle la même langue que la vue iso et que les planches du DA (pâte D, encre, lumière chaude ; `docs/iso/planches_gemini/` de la branche `claude/iso-assets-gemini-boards-4e8d33` : `killcam/killcam_tireur_01.jpg`, `killcam_victime_01.jpg`, `vignette_bunker_01.jpg`, `classes/planche_classes_synthese.jpg`). Adrien veut « une version grand budget aboutie » : l'interface est ce qu'il voit en premier et en dernier.

## Ce qui ne bouge pas

`ui.gd` fait 8 500 lignes et quatre suites de menus le gardent : tu ne changes ni la navigation (deux curseurs, `nav_owner`, `nav_seed`, voisin géométrique), ni la structure des écrans, ni les signaux, ni le bloc lobby (le seul qui connaisse le transport), ni les préchargements (un `Shader.new()` à la volée a déjà coûté un hoquet sur l'action décisive ; les trois textures du voile d'éblouissement manquantes ont déjà rendu du noir sans erreur : lis ces deux pièges en tête de `ui.gd`). Tu changes l'aspect : couleurs et charte (`charte.gd`), cadres, fonds, illustrations, icônes, graisses et espacements, le tout par les constantes de charte et les ressources, jamais par des valeurs en dur dispersées. Le noir absolu de la vue ne te concerne pas : l'interface est un `CanvasLayer` au-dessus, elle a le droit d'être visible ; elle n'a pas le droit de révéler quoi que ce soit du jeu (pas de mini-carte, pas de position adverse, rien de plus qu'aujourd'hui).

## Les étapes, dans l'ordre

1. **Inventaire, écrit avant de toucher** (ROADMAP, section « Habillage iso ») : les écrans de `ui.gd` et ce que chacun affiche, la charte actuelle (`charte.gd` : accent, blanc cassé de la lumière, grille de 8, échelle de six tailles), les ressources d'`assets/ui/`, les suites qui les gardent (`tools/test_menus*.gd`, `test_banc.gd`, le photographe `tools/run_photos.sh` et son catalogue `--liste`).
2. **La charte iso.** Une palette tirée des planches du DA (encre, papier, lumière chaude, un accent), posée dans `charte.gd` ; les fonds de panneaux en matière (papier, encre) plutôt qu'en aplats ; les cadres au filament. Chaque écran est repris avec la même charte : hub, menus, lobby, options, éditeur de cartes (sa toolbar seulement), HUD.
3. **Le hub.** Fond = une illustration iso du bunker (demande à « ISO Assets Sonnet » : « vignette du hub en iso, pâte D, 1920×1080, sans texte, deux variantes » ; en attendant, `vignette_bunker_01.jpg` recadrée). Sélection de classe et d'arme avec des portraits par classe (demande-les : dix portraits 256 px, fond vert, dans le style de la frise `planche_classes_synthese.jpg` ; détoure-les avec `tools/incruster_vert.py` s'il existe, sinon un script à toi). Prends chaque image par `git checkout claude/iso-assets-gemini-boards-4e8d33 -- <chemin>`, jamais par fusion.
4. **Le HUD de match.** Munitions, minuteur, score, gadgets : lisibles sur du noir, discrets, dans la charte ; icônes de gadgets régénérées en pâte D (demande dix icônes 128 px, fond vert, un gadget chacune, à ISO Assets ; les noms sont dans `gadget_profile.gd`). Aucune information de plus qu'aujourd'hui.
5. **La killcam.** Son habillage (planche, estampe, bandeau, affiche, bilan) est refait dans la composition des planches `killcam_tireur_01` / `killcam_victime_01` : cadre, typographie, encre ; le voile de killcam (`killcam_overlay.gdshader`, tenu par ISO5 sur `iso2-vues`) peut recevoir une teinte par un uniform : demande-lui le crochet par message, tu ne le modifies pas toi-même.
6. **Les écrans de fin et l'intro.** Victoire, défaite, bilan de match, écran de fin de partie en ligne : mêmes cadres et mêmes matières ; l'intro (`intro_vue`) garde son texte, prend la charte. Une illustration de fin (demande-la : « victoire » et « défaite », iso, pâte D, sans texte) si le temps le permet.
7. **Preuves et livraison.** Les quatre suites de menus restent vertes à chaque commit ; suite `tools/test_habillage.gd` (chaque ressource référencée existe, est connue de git, a la bonne taille ; aucune texture manquante derrière un `hint_default_black` ; charte cohérente : aucune couleur en dur hors `charte.gd`, vérifié par grep), sabotée une fois ; captures par le photographe (`./tools/run_photos.sh`, vraie fenêtre : annonce le lot aux autres sessions et vérifie `pgrep -x Godot` avant) ; planche `docs/iso/planche_habillage.jpg` (hub, sélection, HUD en jeu, killcam, fin) ; ROADMAP et journal dans le même commit ; lot complet vert ; commits locaux « Habillage — … », un par étape livrable (charte ; hub ; HUD ; killcam ; fins). Delta à la session cloud à chaque commit.

## Fichiers

- **Tu tiens** : `ui.gd` (aspect seulement), `charte.gd`, `assets/ui/**`, `intro_vue.gd` (aspect), `tools/test_habillage.gd`, `docs/iso/planche_habillage.jpg`, ta section de ROADMAP.
- **Partagés, crochet minimal demandé par message** : `killcam_overlay.gdshader` (ISO5), le photographe et son catalogue (`photographe.gd`, ISO5 pour ISO6 : demande-lui d'ajouter tes cadrages, ou pose-les dans un fichier à toi qu'il charge).
- **Tu ne touches pas** : la vue de jeu, les shaders iso, les gadgets, `player.gd`, `game_state.gd`, `network_manager.gd`.

## Pour finir

Delta de fin : commits, crochets, planche, images demandées et reçues. ISO5 fusionnera ta branche dans `iso2-vues` sur le mot de la session cloud ; tu ne fusionnes rien toi-même.
