# Annexes de l'audit d'optimisation (2026-10-04/05)

Le rapport est [`../AUDIT_OPTIMISATION.md`](../AUDIT_OPTIMISATION.md). Ce dossier garde la matière qui le fonde, telle que
les sous-agents l'ont écrite. **Dans ces fichiers, `audit/` désigne ce dossier**, et « le scratchpad » l'espace de travail
éphémère de la session (disparu avec elle : seuls les fichiers copiés ici restent).

**Ce qui fait foi** : les vérifications `V_*.md` et les mesures `00_M_mesures.md`. Les rapports d'audit `01` à `14` sont la
matière première : leurs coûts ESTIMÉS ont souvent été corrigés par les vérifications, presque toujours à la baisse, et un
constat qui n'apparaît dans aucune vérification n'a pas été vérifié (les MINEURS et ANECDOTIQUES, pour la plupart).

Le dossier porte un `.gdignore` : Godot n'en importe ni n'en analyse rien, et rien n'en part dans un export. Les scripts
de `instruments/` sont donc des copies de référence : pour les relancer, les copier dans `tools/` (ils ont été écrits pour
y vivre).

| Fichier | Contenu |
|---|---|
| `00_M_mesures.md` | Les mesures, toutes dans le cloud (Godot 4.7.1 officiel, Xeon 4 cœurs sans GPU) : suites, démarrage, CPU par image et dérive sur 5 min, images singulières, pose de gadget (V1b-N1), image d'impact, HUD et écrans cachés, plancher d'auto-éblouissement, décomposition sous llvmpipe |
| `01_ISO_pipeline.md` | Chaîne de rendu iso, vues, caméras, lumières iso |
| `02_GEO_geometrie.md` | Géométrie, voxels, matériaux, décor |
| `03_SHA_shaders.md` | Coût GPU des 59 shaders |
| `04_LUM_lumieres.md` | Lumières 2D, occlusion, éblouissement, brouillage |
| `05_JOU_joueur_balles.md` | Joueur, balles, particules, traces, entrées |
| `06_ETA_game_state.md` | `game_state.gd`, killcam, relevés |
| `07_GAD_gadgets_fusee.md` | Gadgets des classes, fusée éclairante |
| `08_RES_reseau.md` | Réseau, EOS, services HTTP |
| `09_HUD_interface_en_manche.md` | `ui.gd`, HUD, réglages |
| `10_MEN_menus_ecrans.md` | Menus, écrans, affiches |
| `11_AUD_audio.md` | Audio et son rendu visible |
| `12_BOT_bot_solo.md` | Bot, PNJ, aventure |
| `13_DEM_demarrage_build.md` | Démarrage, configuration, build, assets |
| `14_CAR_cartes_replay.md` | Cartes, éditeur, rejeu, archivage |
| `V_V1a.md` | Vérification — le coup fatal (archivage, premier kill, affiche, `FontVariation`) |
| `V_V1b.md` | Vérification — les premières fois à froid ; **§ 4 : la liste complète de ce qu'un préchauffage doit couvrir** |
| `V_V2.md` | Vérification — ce qui calcule sans qu'on le voie (HUD, galerie, menus, arène sous le menu, uniformes) |
| `V_V3.md` | Vérification — l'image d'impact ; **§ 4 : le décompte ; § 5 : le protocole du banc** |
| `V_V4.md` | Vérification — le départ de manche et le solo |
| `V_V5.md` | Vérification — robustesse et équité (code de carte piégé, classes muettes, liseré, fumée de fusée) |
| `V_V6.md` | Vérification — le réseau (sources de l'addon EOSG 2.3.0 et du moteur lues) |
| `V_V7.md` | Vérification — le build et le démarrage |
| `V_V8.md` | Vérification — lumières, éblouissement, brouillage (sources du moteur 4.7 lues) ; **les faits transmis au chantier OMBRES** |
| `V_V9.md` | Vérification — le coût GPU des shaders |
| `V_V10.md` | Vérification — la taille de la lightmap iso |
| `CONSIGNES_AUDIT.md`, `CONSIGNES_LECTURE.md`, `CONSIGNES_VERIFICATION.md` | Les consignes données aux sous-agents (méthode, règles, format) |
| `CONTEXTE_CHANTIERS_EN_COURS.md` | Ce que l'audit savait des travaux parallèles (audit des lumières, chantier OMBRES) |
| `instruments/` | Les scripts de mesure de l'agent M (`banc_image_impact.gd`, `banc_ui_cachee.gd`, `mesure_nuage.gd`, `mesure_sim.gd`, `micro_particules.gd`, `preuve_flou.gd`…) et ses copies des outils de cadence ; `instruments/arbres/*.diff` : les retouches GELÉES mesurées (H1 = « lire avant d'écrire » du HUD ; A1, A2, A2q, A12 = plancher d'auto-éblouissement) — jamais appliquées au dépôt |
| `V3_work/`, `v4/`, `v5_work/` | Calculs relançables des vérificateurs (géométrie de la pompe, courbe de Bézier, recompte des départs, code de carte piégé, stéréo des sons) |

Les neuf extraits de la ROADMAP lue par tronçons (R1 à R9) ne sont pas versionnés : ils ne font que la recopier.
