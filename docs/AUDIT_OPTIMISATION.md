# Audit d'optimisation — Candela 2D 0.8.3 (commit `52a29c1`)

> **Ce document propose, il ne tranche rien.** Aucune ligne du jeu n'a été modifiée. Les décisions qui reviennent à
> Adrien sont au § 2 ; le plan au § 3. Audit demandé par Adrien le 2026-10-04 (« Délègue à des sous-agents Sonnet 5.5
> chaque tâche. Fais un audit complet d'optimisation du jeu »), mené les 4 et 5 octobre par la session cloud « Audit
> d'optimisation du jeu » (`candela-2d-godot-86`, branche `ccr-7f4baeb9-fzg310`).
>
> **Annexes** : [`docs/audit_optimisation/`](audit_optimisation/LISEZMOI.md). Les rapports de vérification (`V_*.md`)
> **font foi** ; les rapports d'audit par domaine (`01` à `14`) sont la matière première — leurs coûts ESTIMÉS ont souvent
> été corrigés par les vérifications, presque toujours à la baisse (facteur 2 à 5).

## Comment lire ce document

- **PROUVÉ** : lu dans le code et recompté, ou établi dans les sources du moteur 4.7.1. **MESURÉ** : chronométré dans le
  cloud (Godot 4.7.1 officiel, conteneur Xeon 2,8 GHz à 4 cœurs sans GPU, en headless ou sous Xvfb + llvmpipe).
  **ESTIMÉ** : raisonné, non mesuré.
- **Aucun chiffre ne vient du Mac d'Adrien** (décision du 2026-09-30). Les millisecondes CPU mesurées ici sont celles d'un
  Xeon plus lent que le M3 pour du GDScript monothread (rapport ESTIMÉ entre 1,5 et 2) ; sous llvmpipe, seuls les
  **rapports** entre variantes ont un sens.
- Le temps GPU par vue **n'est pas mesurable** sous `gl_compatibility` (`viewport_get_measured_render_time_gpu` rend 0) :
  un coût GPU se déduit par élimination, jamais par lecture directe.
- Les identifiants (`HUD-02`, `RES-01`…) renvoient aux rapports annexés ; « V2 », « V6 »… aux vérifications.

---

## 1. En bref

1. **Les suites sont vertes** sur le commit audité (1 748 s, 0 échec, 0 erreur de script — MESURÉ). **Aucune fuite** sur
   une manche de 5 minutes : nœuds, orphelins et mémoire plafonnent dès que les traces au sol atteignent leurs plafonds.
2. **Un à-coup grave, et le plus facile de l'audit : chaque pose de poussière fige ≈ 0,1 s** (≈ 0,03 s pour la suie),
   chez chaque pair, hôte compris. Le préchauffage de ces nuages relâche les textures qui servent de clé à son cache ;
   chaque pose refait donc quatre boucles par pixel en GDScript. **Une ligne le supprime : 100 ms → 3 ms (MESURÉ).**
3. **Le CPU pèse plus qu'on ne le croyait.** Sans aucun rendu, la couche iso coûte **1,6 à 2,1 ms de CPU par image**
   (PvP : 3,8-4,3 ms en iso contre 2,2 en vue de dessus — MESURÉ), dont 0,47 ms pour le seul `Presentation3D._process`,
   et au moins 80 % de l'image CPU est du `_process`, pas de la physique. **Dans les grandes salles du solo, le CPU seul
   dépasse la cible** : p99 de 20,9 ms au chapitre 8 et 18,8 ms au chapitre 7 sur le Xeon (≈ 10-14 ms ESTIMÉ sur le M3,
   sans marge).
4. **L'interface travaille pour rien à chaque image** : 15 surcharges de thème réécrites à valeur identique (Godot
   notifie sans tester l'égalité : chaque `Label` visé se refaçonne, même caché), la galerie de cartes notifiée à chaque
   image pendant le duel, le panneau de l'adversaire nourri alors qu'il est caché — **23 notifications `theme_changed` par
   image** (MESURÉ). Le correctif « lire avant d'écrire », appliqué à une copie du jeu, **retire 0,67 ms par image (−32 % de
   l'image de repos)** et la galerie cachée en coûte 0,24 à 0,39 : ≈ 0,9 à 1,1 ms récupérables sur 2,1 (MESURÉ, headless).
   Au menu, l'arène est encore rendue deux fois derrière le rideau : l'arrêter retire **un tiers du temps d'image du hub**
   sous llvmpipe (MESURÉ, rapport).
5. **L'image d'impact est la meilleure piste pour les pics du 1 % bas**, que personne n'a jamais expliqués. MESURÉ : l'image
   du tir et celle de l'impact sont **la même image** ; elle coûte **+3,2 ms pour un plomb au mur, +8 à 8,6 ms pour cinq,
   +18 ms pour une volée de contact sur un corps**, puis une traîne qui double le total sur dix images. Les particules en font
   35 à 43 %, et chaque particule vivante coûte encore 10 à 19 µs par image (200 gouttes ≈ 2,8 ms par image en continu). C'est
   l'ordre de grandeur de l'écart entre le fond (2-3 ms) et un 1 % bas de 13-16 ms. Le verdict « les particules sont
   écartées » de `banc_pics` était excessif.
6. **Les premières fois compilent en plein duel** : premier allumage de torche (dix `Shader.new()` puis la compilation de
   la couche et du juge du rayon), première fumée, premier éblouissement fort. Rien n'est préchauffé hors de la fusée. Une
   liste complète de chauffe existe désormais (≈ 17-20 programmes GL, 16 ressources), à étaler pendant le décompte.
7. **Le départ d'une manche fige ≈ 0,5 s** (première image : 450-530 ms MESURÉS en headless, shaders non compris), pendant
   le décompte. Selon le décompte de V4 (ESTIMÉ), 45 à 90 % de ce temps est l'image d'usure de la carte, recalculée à chaque
   manche alors qu'elle ne dépend que de la carte ; le reste, l'arène rebâtie à l'identique. En aventure, l'écran-titre de
   la salle s'affiche **après** la construction : image figée 0,1 à 2,7 s.
8. **Le réseau a deux défauts plus graves que sa cadence.** Sur EOS, une carte dont le code dépasse ~1 100 caractères
   **ne démarre jamais chez le client, sans aucune erreur** (RES-01, PROUVÉ jusque dans l'addon). Et l'ordre de pompage
   d'EOS ajoute **une image de latence par sens : ≈ 23-29 ms de RTT à 60 i/s** (RES-02, ordre PROUVÉ dans le moteur, gain
   ESTIMÉ) — de quoi expliquer une bonne part de l'écart EOS 54 ms / ENet 23 ms relevé en août.
9. **Robustesse** : un code de carte de 12 Ko passe la validation, décode 134 millions de cases (≥ 3,2 Go) et **fige chaque
   démarrage 1 à 2 minutes** une fois importé (CAR-07, PROUVÉ par calcul).
10. **Le build porte 31,75 Mo d'images que rien ne charge** (37 % du PCK, chiffre exact à l'octet), la bibliothèque EOS en
    double sur macOS (−20,5 Mo de zip), et **chaque mise à jour laisse 131 à 185 Mo d'archive** sur le disque du joueur.
11. Le reste du terrain lumineux (capteurs de corps, halos sans récepteur, lumière de coup, murs par contours) est **déjà
    au lot OM6 du chantier OMBRES** : l'audit n'y touche pas et lui transmet des faits (§ 7).

---

## 2. Les décisions qui reviennent à Adrien

| # | Question | Pourquoi maintenant | Avis de l'audit |
|---|---|---|---|
| **D1** | **La machine minimale (jalon H13)** | La feuille de route le demande « avant toute optimisation » : la cible « 1 % bas ≥ 60 » ne décrit que le M3. Les grandes salles du solo dépassent déjà la cible en CPU seul sur un Xeon de serveur. Et la lightmap iso ne descend jamais sous 1920×1080 : à 1280×720, l'ajuster à la fenêtre retirerait **55,6 % des pixels 2D** (ISO-01, PROUVÉ ; temps jamais mesuré), sans toucher à l'équité (masques, champ, éblouissement lus hors de sa taille ; seuls les contours de seuil bougent d'un demi-texel au plus) — mais le défaut, le réglage enregistré et le plancher de netteté sont à Adrien (`settings_manager.gd:214-217` : « ce n'est pas une décision d'agent ») | Nommer une machine (même approximative : « un portable Intel de 2019 à iGPU ») ; tout le plan s'ordonne autrement selon qu'elle est lente en CPU ou en GPU, et la taille de la lightmap en découle |
| **D2** | **L'appareil du brouillage au repos — la Q89 du chantier OMBRES a un argument de performance** | Au repos, la propre torche éblouit son porteur de 0,06 ; ×2 de gain, cela dépasse le seuil du brouillage, dont le flou, la copie d'écran et le halo restent donc **allumés à chaque image** dès que la torche brûle (LUM-01). **PROUVÉ sans GPU par l'agent de mesure** : torche allumée au repos, l'arbre porte en permanence un `BackBufferCopy` et un nœud qui relit l'écran ; un plancher les retire et ramène l'état « torche allumée » à celui d'une torche éteinte. Coût ESTIMÉ 0,1-0,4 ms sur GPU à tuiles (une copie d'écran coupe la passe). **Depuis** : Adrien a tranché Q81 (« Oui », 2026-10-05) et OM1 l'a livrée pour le **corps** seul (`Brouillage.opacite_vue`, PR #8, à fusionner) ; l'appareil reste allumé au repos — c'est la Q89 qu'OMBRES a posée à Adrien | Oui pour l'appareil, avec le plancher posé dans **`BrouillageVue.maj`** (la variante A1, celle qui a été mesurée) — **surtout pas dans `Brouillage._dose`**, où il doublerait celui qu'OM1 retire déjà pour le corps (0,12 au lieu de 0,06 ; `test_ombres_regles` le garde). Le voile plein écran, lui, lit `dazzle_amount` (`ui.gd:2536`) : ne plus le dessiner au repos retire 13 à 16 % du temps d'image sous llvmpipe (MESURÉ, rapport ; bien moins sur le GPU du Mac, ESTIMÉ 0,05-0,7 ms), mais ferait passer un noir de 2-4/255 à 0 — décision d'image, elle aussi dans Q89 |
| **D3** | **Six classes sur dix rechargent et claquent à vide sans aucun son ni liseré** (AUD-07, PROUVÉ) | Équité d'information : pistolet, fusil, pompe et arbalète s'entendent et se voient au bord de l'écran adverse ; les six autres non. Leurs tirs, eux, ont le son générique. Aucune suite ne le garde | Fournir les sons, ou à défaut un repli générique pour la recharge et le clic à vide |
| **D4** | ~~**Chez le client, le flou et le halo de repos du brouillage se poseraient sur l'adversaire**~~ (V8, « D2 ») — **RÉGLÉ par OM1** (PR #8, commit `e2e1759`, à fusionner) | Sur `52a29c1`, `source_eblouissante` n'était écrite que chez l'hôte (`game_state.gd:2406`). OM1 fait calculer au client la source de l'éblouissement de son propre joueur (`Player.retenir_la_source`, rien de neuf sur le fil) ; gardé par `test_ombres_regles` (aucune partie en ligne jouée) | Plus rien à décider |
| **D5** | **Les cartes trop grandes pour EOS** (RES-01) | Les six cartes livrées passent (≤ 644 caractères) ; une carte de joueur 48×48 à dix pièces (1 124) ne part jamais chez le client, au premier départ comme en revanche ou au tirage classé | À court terme, une garde (refuser à l'éditeur ou à l'appariement ce qui ne passe pas) ; à terme, découper l'envoi — nouvelle forme de RPC, donc `Protocol.VERSION` 20 et une mineure |
| **D6** | **Corriger l'ordre de pompage EOS** (RES-02) | −23 à −29 ms de RTT à 60 i/s (ESTIMÉ, borne −33) ; −4 à −10 à 144 i/s. Le correctif tient en un sondage manuel en fin de `_process`, mais la compensation de tir se recale | Oui, avec un essai à deux machines (jalon H1) avant publication |
| **D7** | **Ordre des lots du § 3**, et lesquels confier à quelle session | Les lots 1, 2, 3 et 5 ne demandent aucune décision ; le lot 7 touche des fichiers du chantier OMBRES | Commencer par le lot 1 (gestes d'une ligne, gain mesuré ou sûr) |

Optionnel, pour plus tard : rogner les cookies des torches (LUM-04 : −30 % de dessins d'ombre en duel, −54 % en solo,
effort L, à faire **après** les mesures d'OM6) ; remplacer le hachage de la pâte (SHA-13 : ne gagne rien, change l'image) ;
réduire les huit prises de moyenne des faces de mur (SHA-10 : change l'image).

---

## 3. Le plan proposé

Ordonné par **gain sûr / risque**. Chaque lot se livre seul, avec sa preuve (test headless, banc, ou capture avant/après
au temps figé) et la mise à jour de la ROADMAP dans le même commit, comme le veut le protocole. Les preuves se font **dans
le cloud** : compteurs indépendants du matériel, temps CPU headless à `--fixed-fps 60`, rapports llvmpipe.

### Lot 1 — Les gestes d'une ligne (S, aucune décision ; image identique, sauf le filtre des textures d'écran)

| Geste | Constat | Gain | Preuve |
|---|---|---|---|
| Tenir les textures sources de la suie et de la poussière dans une variable statique de `IsoNuageVoxel.prechauffer()` | V1b-N1 | **−97 ms par pose de poussière, −28 ms par pose de suie (MESURÉ)** ; fin d'une fuite de 0,87 Mo par pose | `instruments/mesure_nuage.gd` (annexe) ; `test_fumee_voxel` exige « aucun `preload(` et un seul `load(CHEMIN_SHADER)` » : rester dans ce cadre |
| Lire avant d'écrire sur les sites de surcharges de thème du HUD (V2 en compte 9 ; la mesure en a retouché 8 : `ui.gd` 1652, 1737, 3168, 3246, 3375, 3380, 3439, 3446) | HUD-02 (= ETA-03, GAD-08, MEN-11, DEM-14) | **−0,67 ms par image, −32 % de l'image de repos (MESURÉ** sur une copie retouchée, `instruments/arbres/H1.diff` : 23 → 8 notifications par image) | banc « UI cachée » (`instruments/banc_ui_cachee.gd`) ; deux suites lisent le texte de `ui.gd` (`test_tir_et_reserves`, `test_habillage`) : la retouche n'a pas encore été jouée contre elles |
| `MapGallery` : `set_process(is_visible_in_tree())` sur `visibility_changed` | HUD-03 = CAR-01 | **0,24-0,39 ms par image (MESURÉ**, 6 cartes), linéaire en N | idem |
| Garder le bloc J2 de `update_hud` derrière `hud_panneau_p2.is_visible_in_tree()` (pas derrière `match_hud.visible`, qui figerait le voile) | HUD-01 | 0,09-0,3 ms/image en ligne | idem |
| Anneaux de focus et `MatchBanner` endormis hors usage ; hachures d'alerte et vignette de dégâts cachées à alpha 0 | HUD-05/06, MEN-02/03, LUM-12 = SHA-06 | 50-150 µs/image + 1 à 3 quads plein cadre | idem ; ROADMAP l. 6871 (« un effet éteint à intensité 0 rastérise encore ») |
| `Charte.courbe()` : table de 257 échantillons au lieu de Newton | JOU-03 (+ GAD-02) | 0,05-0,5 ms/image selon les particules ; erreur 5,4e-5 | `V3_work/courbe_sim.py` (annexe) |
| Supprimer `light.energy = 0 × …` et les deux `get_node` par particule et par image — mais **garder les 240 nœuds `Light` du pool** : ils sont les seuls à tenir la texture `ECLAT` dans l'atlas des lumières, les retirer ajouterait une reconstruction de l'atlas par tir (V8) | JOU-04, LUM-11 | 0,13-0,2 ms/image à 100 particules | headless |
| `create_tileset` : atlas constant en variable statique | CAR-06 | ≈ 1 ms par départ | `test_iso_*` |
| Supprimer l'archive de mise à jour après installation (+ balayage au démarrage) | DEM-10 | 131-185 Mo de disque par mise à jour | test de mise à jour |
| Écrire le journal des matchs et préparer le rapport **après** l'`await` de fin de manche | ETA-01 (= CAR-04, GAD-10, MEN-12, RES-03, DEM-06) | ≈ 40 ms au plafond de 200 fiches, sortis de l'image du coup fatal | deux suites épinglent le texte de `game_state.gd` : les adapter |
| `filter_linear` au lieu de `filter_linear_mipmap` sur les textures d'écran du voile et de la killcam | LUM-06 = SHA-07 | 0,1-0,4 ms pendant les éblouissements forts et la killcam (le moteur régénère 5-6 passes de mipmaps à chaque copie) | image quasi identique (LOD 0,03-0,05) : planche avant/après |
| Panneau F3 : `_decrire` paresseux, `hauteur_mur_haut()` en cache | ISO-10, GEO-12 | 15-35 µs/image | — |
| Onde de mort : la retrouver par un groupe au lieu de parcourir chaque image les ≈ 660-700 enfants de l'arène | ISO-03 | 0,05-0,15 ms/image en iso, croissant avec les traces | `test_nappes_voxel.gd:109-110` épingle le texte de `suivre()` : garder le bloc `if nappes_voxel:` à l'indentation exacte |

### Lot 2 — Le préchauffage (M, aucune décision)

La liste complète est au § 4 de [`V_V1b.md`](audit_optimisation/V_V1b.md) : **A1-A16** (ressources et calculs CPU, sûrs,
prouvables en headless) et **B1-B18** (programmes GL à DESSINER une fois, sortie nulle, dans le viewport réel), avec leur
placement : au lancement ce qui est CPU, **pendant le premier décompte** les gros programmes en premier (un ou deux par image),
rien ensuite (drapeaux statiques). Points saillants :

- le premier allumage de torche compile la couche et le juge du rayon et `halo_iso`, après dix `Shader.new()` en chaîne
  (SHA-02 : composer les `#define` en une passe et pré-créer les cinq variantes finales de `volume_iso`) — c'est l'à-coup
  le plus probable en plein duel (mécanisme PROUVÉ, 143-150 ms mesurés sur Mac pour des matériaux 3D comparables) ;
- le voile plein (premier éblouissement fort), le flou du brouillage et son `BackBufferCopy`, `blood_shader`, la nappe de
  la fusée, les grilles de cubes des nuages (+80 ms à la toute première pose de poussière, MESURÉ) ;
- **une garde**, sinon la liste se périme sans bruit : monter `main.tscn`, préchauffer, jouer un duel scripté, exiger que
  l'ensemble des matériaux vus ensuite soit inclus dans celui du préchauffage (faisable en headless) ;
- chauffer **sans rien d'observable** : alpha nul posé dans un uniforme (jamais `modulate.a`, qui fait sauter le dessin),
  aucune vraie lumière, aucun RPC, aucun tirage aléatoire global, à l'identique chez les deux pairs.

### Lot 3 — Le départ de manche (S-M, aucune décision)

| Geste | Constat | Gain |
|---|---|---|
| Réécrire l'image d'usure de la carte en `fill_rect` exacts, par carte | GEO-02 | **la plus grosse pièce du départ (45-90 %)** : 0,05-0,3 s par départ de duel, 0,4-2,3 s en salle 8.9 ; preuve par `test_iso_usure` déjà en place |
| Montrer l'écran-titre de la salle **avant** de la construire | BOT-09 | masque 0,1-2,7 s d'image figée à chaque entrée et chaque réessai |
| Mémoïser `build_grid` par contenu EXACT de carte (pas `hash()` 32 bits) | CAR-03 + GEO-03 + BOT-04 | 10-18 ms par départ de duel, 150-200 ms en 8.9 — ⚠️ `map_geometry.gd` est aussi visé par OM6 : prévenir la session OMBRES |
| Ne pas re-cuire le décor d'arène sans changement de carte | CAR-05 | 2-10 ms (duel) à 15-40 ms et −80 Mo transitoires (8.9) |
| A* paresseux à la première ouverture de l'écran Aventure | BOT-01 | ≈ −45 % d'un gel unique de 0,7-1,6 s |
| Précharger en fil les deux illustrations de l'affiche de fin au début de `_do_end_round` | MEN-07 | 25-50 ms (monde figé) |

### Lot 4 — L'image d'impact (M, le banc existe)

Le banc décrit au § 5 de [`V_V3.md`](audit_optimisation/V_V3.md) a été écrit et joué par l'agent de mesure
([`instruments/banc_image_impact.gd`](audit_optimisation/instruments/), à verser dans `tools/` avec sa garde dans
`tools/test_banc.gd`) : volées contre un mur à 40/120/165 px et contre un corps, surcoût = image du tir moins le fond,
40 volées par cas (résultats au § 4.3). Il sert d'étalon avant/après à chaque geste. Puis :
mettre en cache les références des particules (JOU-01 : 5 `get_node`, ~18 écritures et un `Dictionary` par particule),
recycler la plus ancienne trace au plafond au lieu d'évincer puis recréer (JOU-02 ; trois suites exigent les copies J2 :
les garder), une `CircleShape2D` partagée par les balles (JOU-06), dédoublonner `famille_de` et les rayons d'occlusion de
`play_sfx_2d` (AUD-03), et vérifier la piste nouvelle de l'**atlas des lumières** (V8 « D1 » : l'atlas des textures de
lumière 2D est reconstruit en entier à chaque texture inédite ; le flash de bouche en ajoute deux que rien d'autre ne tient,
soit jusqu'à deux reconstructions par tir — NON MESURÉ). **Une décision s'y ajoute** : le coût PERMANENT des particules
vivantes (10-19 µs chacune par image, l'intégration de leurs `RigidBody2D` ; ≈ 2,8 ms par image au plafond de 200 gouttes,
MESURÉ) pèse autant que l'impact lui-même sur la durée d'une volée. Un plafond plus bas, ou des gouttes sans corps rigide,
se verraient à l'écran : c'est à Adrien d'en juger, planche à l'appui.

### Lot 5 — Le build (S, aucune décision)

| Geste | Constat | Gain |
|---|---|---|
| Exclure de l'export les 33 images sans lecteur (seuls des outils et des tests y touchent) | DEM-01 | **−31,75 Mo de PCK** (zip Windows 131,2 → ≈ 100,3 Mo) |
| Retirer la copie orpheline de `libEOSSDK` à la racine de `Frameworks` (+ garde `otool` en CI, essai « Epic : connecté ») | DEM-02 | −20,5 Mo de zip macOS, −48,6 Mo installés |
| Ré-importer trois sources JPEG en perte maîtrisée et exclure le repli d'intro inutile (dans le cadre de DA5.6) | DEM-11 | ≈ −8,5 Mo |
| Exclure les fichiers du greffon `godot_ai` (son autoload, lui, est déjà retiré) | DEM-12 | −1,04 Mo |
| Chronométrer le démarrage et l'ajouter au diagnostic (`machine()`, F6) | DEM-05 | une base chiffrée sur les machines des testeurs |

### Lot 6 — Robustesse et réseau (S, puis décisions D5 et D6)

- **Borner le NOMBRE DE CASES au décodage d'un code de carte** (CAR-07) — pas seulement les runs : 16 384 runs donnent
  encore 2,1 millions de cases. À faire tôt : une carte piégée importée fige chaque lancement.
- **Garde sur la taille des cartes en ligne** (RES-01, D5).
- `hp` répliqué deux fois (synchro + `rpc_update_hp`) : le retour de dégâts et la télémétrie se taisent parfois (RES-05).
- Le témoin de protocole ignore la liste des propriétés répliquées et trois attributs de salon ; or une liste différente
  fait jeter le paquet de synchro entier sans erreur (RES-04).
- L'ordre de pompage EOS (RES-02, D6), avec son essai à deux machines.

### Lot 7 — Le GPU, à image identique (M, mesure d'abord)

- **Sauter l'habillage du sol et des faces de mur là où la lumière est nulle** (SHA-04) : `if (c != 0)` autour de la
  chaîne est exact au bit (aucun terme additif ne survit au noir, dérivées prises avant) ; 73 à 98 % des pixels sont noirs ;
  gain ESTIMÉ 0,3-1,4 ms. Réserves : trois gardes textuelles à rouvrir, un geste voisin « n'a rien rendu » sur le masque de
  la fumée (ROADMAP l. 4203), et llvmpipe ne le verra probablement pas — preuve à l'octet par le protocole du levier 1
  (`banc_lumiere3d.gd` + `docs/iso/iso13/levier1/compare_ab.py`).
- **Ne plus rendre l'arène derrière le menu** (MEN-04 = ISO-07 = DEM-08) : vp1 et vp2 rendent en `UPDATE_ALWAYS` sous un
  rideau à 96 % ; **−33,7 % du temps d'image du hub sous llvmpipe** (MESURÉ ; −72 % d'objets, −75 % de primitives), 0 en
  duel. Dans `_accorder_rendu_aux_vues`, rappelé après `show_main_menu`, les deux vues rallumées dans la même image au
  retour en jeu — à coordonner avec la session OMBRES. Les 4 % encore visibles derrière le rideau deviendraient une image
  figée : à montrer à Adrien.
- **Le plancher de l'appareil du brouillage** (D2, Q89 d'OMBRES), dans `BrouillageVue.maj` : il retire la copie d'écran
  permanente du repos (LUM-01).

### Lot 8 — Le solo (mesure d'abord)

Les grandes salles dépassent la cible en CPU seul (§ 8). **Où va ce temps n'est pas attribué** : avant tout correctif, un
banc par soustraction (perception des PNJ, peinture iso de 39 Mo en 100×80, lumières, traces), dans le banc solo prévu par
OM6. Candidats déjà vérifiés : BOT-02 (15-50 µs par PNJ et par pas), BOT-03 (0,3-3 ms par repli, au moment du tir),
BOT-05 (latent), SHA-08 b (deux niveaux sur cent à 37-44 murets : +4 ms MESURÉS en écran scindé). ⚠️ Les bancs de
difficulté sont déterministes par graine : tout correctif doit garder l'ordre des tirages (BOT-03 : l'ordre y-puis-x).

---

## 4. Les constats vérifiés, par moment du jeu

Sévérités et coûts **après** vérification contradictoire. CONFIRMÉ = le code fait ce qui est dit ; « avec réserve » = le
mécanisme est prouvé mais l'ampleur reste à mesurer. Le détail (extraits de code, appelants, correctif minimal) est dans le
rapport `V_*` cité.

### 4.1 À-coups — une image longue, une fois

| Constat | Verdict | Sévérité | Coût | Source |
|---|---|---|---|---|
| Pose de poussière / suie : cache du nuage indexé par une texture morte | CONFIRMÉ, **MESURÉ** | **MAJEUR** | 95-105 ms / 30-35 ms par pose, chez chaque pair | V1b-N1, `00_M_mesures.md` § 3bis |
| Premier allumage de torche : 10 `Shader.new()` + couche, juge et halo compilés | CONFIRMÉ avec réserve | MAJEUR présumé | à mesurer (143-150 ms pour des matériaux 3D sur Mac) | ISO-09 = SHA-01, SHA-02 ; V1b, V9 |
| Première grille de nuage (poussière, suie, fusée) | CONFIRMÉ, MESURÉ (poussière, suie) | MINEUR | +80 ms / +70 ms à la toute première pose ; 8-20 ms ESTIMÉ (fusée) | GEO-04, GAD-05 ; V1b |
| Premier éblouissement fort : voile plein compilé en jeu | CONFIRMÉ avec réserve | MINEUR | à mesurer | HUD-08, LUM-05 ; V1a, V8 |
| Premier allumage après FIGHT : `image_torche()` (lecture GPU de 4 Mo, aussi en export) ; scripts de gadget compilés à la pose | CONFIRMÉ avec réserve | MINEUR | 0,5-5 ms ; 1-3 ms | ETA-05 = BOT-10 = LUM-07 ; V1b |
| **Départ de manche** : première image | **MESURÉ** | MAJEUR à l'œil, hors jeu (pendant le décompte) | **450-530 ms** (headless, shaders non compris) | `00_M_mesures.md` § 4.2 |
| — dont l'image d'usure de la carte | CONFIRMÉ | MINEUR à MAJEUR | 0,05-0,3 s (duel), 0,4-2,3 s (8.9) | GEO-02 ; V4 |
| — dont l'arène rebâtie à l'identique (`build_grid` ×20, décor relu au GPU, tileset) | CONFIRMÉ | MINEUR | 10-18 ms + 2-10 ms + ≈ 1 ms | ETA-04, CAR-03/05/06, GEO-03, BOT-04 ; V4 |
| Salle d'aventure : écran-titre montré après la construction | CONFIRMÉ | MINEUR | 0,1-2,7 s figés, à chaque entrée et réessai | BOT-09 ; V4 |
| Première ouverture de l'écran Aventure (100 salles validées) | CONFIRMÉ | MINEUR | 0,7-1,6 s, une fois par session | BOT-01 ; V4 |
| Fin de match : archivage synchrone dans l'image du coup fatal | CONFIRMÉ avec réserve | **MINEUR** (était MAJEUR) | ≈ 40 ms au plafond, **après** la décision et pendant le gel de 150 ms : ni équité ni 1 % bas | ETA-01 (+5 doublons) ; V1a |
| Fin de partie : panneau de fin | MESURÉ | MINEUR | 86-121 ms (394 ms à la toute première partie) | `00_M_mesures.md` § 4.2 |
| Affiche de fin : `load()` synchrone d'une illustration 1920×1080 | CONFIRMÉ | ANECDOTIQUE | 25-50 ms, monde figé | MEN-07 ; V1a |

### 4.2 Le coût de chaque image, en manche

| Constat | Verdict | Sévérité | Coût | Source |
|---|---|---|---|---|
| La couche iso, CPU seul | **MESURÉ** | — | **1,6-2,1 ms par image** (PvP 3,8-4,3 ms iso contre 2,2 ms en vue de dessus) | `00_M_mesures.md` § 4 |
| 15 surcharges de thème réécrites par image, notifiées sans test d'égalité (23 notifications par image en tout) | CONFIRMÉ, **MESURÉ** | **MAJEUR** | **0,67 ms** par image au repos (−32 %), correctif appliqué à une copie | HUD-02 (+4 doublons) ; V2 ; `00_M_mesures.md` § 7.2 |
| Galerie de cartes notifiée à chaque image, cachée, pendant le duel | CONFIRMÉ, **MESURÉ** | **MAJEUR** | **0,24-0,39 ms** (6 cartes), linéaire en N | HUD-03 = CAR-01 ; V2 ; § 7.2 |
| Panneau adverse caché nourri chaque image ; icône rechargée | CONFIRMÉ, MESURÉ | MINEUR après HUD-02 | 0,14-0,20 ms (le bloc J2 caché coûte presque autant que le visible) | HUD-01 ; V2 ; § 7.2 |
| `Presentation3D._process` | MESURÉ | — | **0,47 ms par appel** : le plus gros poste scripté de la couche iso au repos | `00_M_mesures.md` § 7.2 |
| ≈ 270 `set_shader_parameter` par image dont 40-55 % constants ; recherche dans 2 Ko de code shader par appel | CONFIRMÉ avec réserve | MINEUR | 0,1-0,35 ms (0,06-0,2 récupérables) | ISO-04 = SHA-09 ; V2 |
| Liseré du son visible reconstruit trace par trace à chaque image | CONFIRMÉ avec réserve | MINEUR (MAJEUR si > 1,5 ms au micro-banc) | 0 hors échange ; 0,5-2,6 ms pendant une rafale (ESTIMÉ ×2) | AUD-01 ; V5 |
| Traces au plafond : le coût d'image monte avec elles | MESURÉ (dérive) | MINEUR | ≈ 1-2 µs par groupe de traces et par image (ESTIMÉ sur la dérive) | `00_M_mesures.md` § 4.1 |
| Brouillage au repos : flou + copie + halo allumés dès que la torche brûle | CONFIRMÉ, présence PROUVÉE sans GPU | MINEUR (MAJEUR si ≥ 0,3 ms) | 0,1-0,4 ms sur GPU à tuiles (ESTIMÉ) ; nul sous llvmpipe, qui n'a pas de coupure de passe | LUM-01 ; V8 ; `00_M_mesures.md` § 6a |
| Voile « calme » plein écran torche allumée (12 lectures + ≈ 55 `sin/cos` par pixel) | CONFIRMÉ, MESURÉ (rapport) | MINEUR sur le Mac, décision d'image | **13 à 16 % du temps d'image sous llvmpipe** ; 0,05-0,7 ms GPU à 1440p (ESTIMÉ) | LUM-02 = HUD-04 = SHA-03 ; V2, V8 ; § 6a |
| Habillage du sol et des murs payé sur les pixels noirs | CONFIRMÉ avec réserve | MAJEUR présumé | 0,3-1,4 ms GPU (ESTIMÉ) | SHA-04 ; V9 |
| Passe d'ombre rejouée dans chaque capteur de corps | CONFIRMÉ avec réserve | MAJEUR présumé | 0,3-1,9 ms (duel), 0,6-2,0 (solo) ESTIMÉS | LUM-03 ; V8 — **levier : OM6** |
| Fumée de fusée | CONNU-OUVERT | MAJEUR potentiel | 3,39 ms/fusée mesurés en couches (M3) ; ≈ 2 ms ESTIMÉ en voxels, jamais mesuré sur M3 | GAD-01 ; V5 |
| Sous le menu, l'arène rendue derrière un rideau à 96 % | CONFIRMÉ, MESURÉ (rapport) | MINEUR (0 en duel) | **un tiers du temps d'image du hub sous llvmpipe** (−33,7 %) ; ≈ 3 ms/image au menu sur le Mac (ESTIMÉ) | MEN-04 = ISO-07 = DEM-08 ; V2 ; § 6c |

### 4.3 L'image d'impact — la piste des pics

V3 a établi le décompte (multiplicités PROUVÉES par la géométrie, coûts ESTIMÉS) ; l'agent de mesure l'a ensuite **MESURÉ**
au banc qu'il proposait (headless, iso, Xeon ; surcoût de l'image par rapport au fond, médiane de 40 volées) :

| Volée de pompe | Surcoût de l'image (médiane / p90) | Cumul sur dix images |
|---|---|---|
| tir dans le vide | +0,64 / +1,87 ms | +3,5 ms |
| mur, 1 plomb touche | +3,16 / +4,92 ms | +13,1 ms |
| mur, 3 plombs | +5,76 / +8,09 ms | +15,4 ms |
| mur, 5 plombs | **+8,0 à 8,6** / +9,5 à 12,9 ms | +19 à 22 ms |
| corps, 1 touche | +4,9 à 5,3 ms | ≈ +13 ms |
| corps, 3 touches | **+12,4** / +17,5 ms | +30,2 ms |
| corps, 5 touches (contact) | **+18,0** / +20,1 ms | +28,5 ms |
| vue de dessus, mur 5 plombs | +6,74 ms | +18,5 ms |

**L'image du tir est l'image de l'impact** (100 % des volées). Par soustraction (5 plombs au mur) : particules 35 % de
l'image, 43 % sur dix images ; liserés du son visible 11 % ; couche iso 19 % ; plafonds de traces atteints +14 % ; rayons
d'occlusion ≈ 0 ; 47 % non attribués (impacts de mur et leurs copies, sons, plombs, fondus). Une particule coûte 20-34 µs à
l'émission et **10-19 µs par image tant qu'elle vit** (intégration des `RigidBody2D` de la réserve) : 200 gouttes actives,
le plafond, ≈ 2,8 ms par image en continu. Constats : JOU-01 (particules, MAJEUR, CONFIRMÉ par la mesure), JOU-02
(traces au plafond en iso, MAJEUR), JOU-03, JOU-04, JOU-06 = ETA-08, JOU-08, AUD-03 (MINEURS), LUM-10 (une `hit_light` à ombre **par plomb** : la prémisse « une fois
par coup » de la ROADMAP l. 2506 est fausse pour la pompe — levier OM4/OM6). Sur le verdict de `banc_pics` : le banc
corrélait le STOCK de particules, dont la dent de scie ne pouvait dépasser ≈ +12 % pour un seuil de 25 % — il ne pouvait
pas conclure ; la ROADMAP l. 2999 est prudente, la l. 22360 (« a écarté ») excessive.

### 4.4 Le réseau

| Constat | Verdict | Sévérité | Ce que ça coûte | Source |
|---|---|---|---|---|
| Carte > ~1 100 caractères : le départ de manche n'arrive jamais chez le client EOS, sans erreur | CONFIRMÉ (addon EOSG 2.3.0 et moteur lus) | **MAJEUR** | fiabilité | RES-01 ; V6 |
| Pompe EOS après `multiplayer.poll()` : une image de retard par sens | CONFIRMÉ avec réserve | **MAJEUR** | ≈ +23-29 ms de RTT à 60 i/s | RES-02 ; V6 |
| `hp` répliqué par la synchro et par RPC | CONFIRMÉ | MINEUR | retour de dégâts parfois muet | RES-05 ; V6 |
| Témoin de protocole incomplet | CONFIRMÉ | MINEUR | une désynchronisation silencieuse non gardée | RES-04 ; V6 |
| Charge utile ≈ 5 Ko/s par sens | CONFIRMÉ | — | rien à gagner sans `VERSION` 20 | RES-07 ; V6 |
| Historique de compensation échantillonné par image | coût CONFIRMÉ, enjeu d'équité RÉFUTÉ | ANECDOTIQUE | 1-10 µs ; écart ≤ 1 pas (4,33 px) | RES-09 ; V6 |
| Mise à jour : SHA-256 et extraction bloquants | CONFIRMÉ avec réserve | ANECDOTIQUE | gel de 0,2-1,2 s, geste rare | RES-10 ; V6 |

Bonne nouvelle, vérifiée : **aucun émetteur ne suit le rythme du rendu** (commandes au pas physique, état par intervalle du
moteur) ; le piège « fps déplafonnés = rafale de paquets » est évité par construction.

### 4.5 Le build et le démarrage

| Constat | Verdict | Ce que ça coûte | Source |
|---|---|---|---|
| 33 images sans lecteur dans le PCK | CONFIRMÉ (exact à l'octet) | 31,75 Mo sur 86,39 | DEM-01 ; V7 |
| `libEOSSDK` en double dans l'app macOS (+ `icon.icns` dans le PCK) | CONFIRMÉ | 20,5 Mo de zip, 48,6 Mo installés | DEM-02 ; V7 |
| Archive de mise à jour jamais supprimée | CONFIRMÉ | 131-185 Mo par mise à jour | DEM-10 ; V7 |
| Sources JPEG ré-encodées sans perte (×4) | CONFIRMÉ avec réserve | ≈ 8,5 Mo | DEM-11 ; V7 |
| 16 illustrations du hub décodées au lancement et résidentes en duel | CONFIRMÉ avec réserve | 43,6-58,2 Mo (calculés) ; décodage 0,41 s sur le Xeon | DEM-03 = MEN-08 = HUD-10 ; V7 |
| **Démarrage jusqu'au premier menu** | **MESURÉ** | ≈ 5,7 s headless (≈ 6,3 s sous Xvfb à chaud) : compilation GDScript du bloc de `main.tscn` 2,75 s, autoloads 1,2 s (dont `NetworkManager` + greffon EOS 0,54 s, `AudioManager` 0,19 s), `_ready` en cascade 1,18 s | `00_M_mesures.md` § 3 |
| Glyphes « ● » (ping) et « ✓ » absents des polices | CONFIRMÉ | repli système à la première occurrence, coût non vérifiable ici | DEM-07 ; V7 |

En export, les scripts partent en jetons binaires (`script_export_mode=2`) : le coût de compilation au démarrage d'un
build exporté **n'est pas mesuré** ici (seulement celui du projet lancé depuis les sources).

---

## 5. Ce que la vérification a réfuté ou rétrogradé

À ne pas redécouvrir :

- **`FontVariation` neuve à chaque chiffre de dégâts** (JOU-05 = MEN-10) : RÉFUTÉ pour la conséquence alléguée — deux
  variations de même base et mêmes coordonnées résolvent le même RID de police, donc le même cache de glyphes.
- **Copies d'écran des rangées du menu en verre** (MEN-06) : RÉFUTÉ — Godot 4.7.1 ne copie l'écran qu'une fois par passe
  de rendu des éléments.
- **Stéréo des sons positionnels** (AUD-04) : fait exact, enjeu RÉFUTÉ (29 des 40 sons ont L = R exactement).
- **Hachage `fract(sin())` de la pâte** (SHA-13) : pas une optimisation (le remplaçant coûte plus) ; changer de hachage
  change l'image.
- **Archive au coup fatal** (ETA-01 et ses cinq doublons) : de MAJEUR à MINEUR — après la décision, pendant le gel.
- **BOT-01** (MAJEUR → MINEUR), **DEM-01** (MAJEUR → MINEUR : du poids, pas de la cadence), **JOU-03** (MAJEUR → MINEUR),
  et des coûts unitaires divisés par 2 à 5 pour CAR-03, BOT-04, BOT-05, JOU-08, CAR-02.
- **« 5 µs par trace » du liseré** (ROADMAP) : ne couvre que la lecture de la vie de la trace, pas son dessin ; et la série
  « son visible +4,0 ms » n'avait aucun liseré dessiné.
- **Rogner les colonnes de la lightmap que la caméra iso ne lit jamais** (ISO-02 : 21,2 % de colonnes, PROUVÉ) : à ne pas
  faire sans mesure — rogner `size_2d_override` change `get_visible_rect()`, donc les bornes du champ de `RegardDuel` près
  des murs, et réécrit `test_iso_vues`, pour un gain jamais établi.
- **`hit_light` « une fois par coup »** (ROADMAP l. 2506) : faux pour la pompe, une par plomb.

---

## 6. Hors performance — défauts trouvés en chemin (signalés, pas corrigés)

| Défaut | Gravité | Source |
|---|---|---|
| Carte EOS > ~1 100 caractères : départ silencieusement perdu chez le client | MAJEUR | RES-01 ; V6 |
| Code de carte piégé : 12 Ko → 134 M de cases, démarrage figé 1-2 min ; la carte voyage aussi par valeur dans `rpc_start_round` | MAJEUR | CAR-07 ; V5 (`v5_work/bombe_codec.py`) |
| Six classes muettes à la recharge et au clic à vide (ni son, ni liseré) | MINEUR côté code, question d'équité | AUD-07 ; V5 |
| Brouillage de repos ancré sur l'adversaire chez le client (lu, non vu) | réglé par OM1 (PR #8, à fusionner) | V8 « D2 » |
| `hp` doublement répliqué ; témoin de protocole incomplet | MINEUR | RES-05, RES-04 ; V6 |
| Miniature de carte jamais invalidée après l'éditeur (vignette périmée) | MINEUR, non vérifié | CAR-08 |
| `bench_framerate --menus` : identifiants d'écran peut-être périmés (le banc retombe sur `hub.reset()`) | MINEUR (outil), non vérifié | MEN-09 |

**Documentation à corriger** (par qui tient ces fichiers) :
- **`CLAUDE.md`** affirme qu'« en vue unique, le duel n'est plus rendu par un `SubViewport` du tout ». C'est vrai en vue de
  dessus (`--2d`) seulement : **en iso, vue par défaut depuis ISO6, `rendu_racine_autorise = false` force le chemin
  `SubViewport`** (`presentation_3d.gd:611`, `:741-742` ; `settings_manager.gd:101`) — le gain de +15 % du chantier R ne
  s'applique pas à la vue iso (ROADMAP l. 23832-23836, qui le dit).
- ROADMAP l. 7659-7662 : l'autoload `_mcp_game_helper` **est** retiré de l'export (vérifié dans `project.binary` publié) ;
  seuls les fichiers du greffon voyagent.
- ROADMAP l. 22360 (« `banc_pics` a écarté les particules ») et l. 2506 (`hit_light` une fois par coup) : voir § 5.
- L'en-tête de `Fusee.prechauffer` annonce « 8,5 ms » : mesure du repli procédural, périmée depuis les planches peintes.

---

## 7. Coordination avec le chantier OMBRES

Le chantier OMBRES (session `candela-2d-godot-d4`, branche `claude/determined-pasteur-mtrws1`) tient l'éclairage du solo.
**Déjà à son lot OM6, donc hors du plan de l'audit** : capteurs de corps et d'objets en `UPDATE_WHEN_VISIBLE` (GAD-12,
ISO-06), halos sans récepteur (LUM-09), ombre de la lumière de coup (LUM-10), murs par contours (LUM-08).

**Faits que l'audit lui apporte** (V8, avec les sources du moteur 4.7) :
- flou, halo et opacité adverse passent tous par `Brouillage._dose` (`brouillage.gd:655`) ; le voile lit `dazzle_amount`
  (`ui.gd:2536`) ; la pénalité de vitesse et de visée le lit brut. Repos = 0,06 exactement, atteint en 48 ms ; seuils
  d'allumage : flou d > 0,00526, halo d > 0,00333 ;
- `source_eblouissante` vaut `null` chez le client : Q81 b ne peut pas la lire là ;
- passe d'ombre (4.7-stable) : toute lampe à ombre dont l'AABB de rect croise le viewport est rejouée ; chaque lampe
  redessine tous les occulteurs dont la couche croise son `shadow_item_cull_mask` ; `canvas_cull_mask` ne filtre ni
  lumières ni occulteurs ; compter par masque donne × 0,79 en duel, × 0,65 en solo ;
- `PointLight2D.offset` décale le rect de culling et la texture, pas l'origine de l'ombre ; `rect_cache` est l'AABB du
  rect tourné (jusqu'à × 1,41 de côté) ;
- `UPDATE_WHEN_VISIBLE` : le drapeau est posé par la liaison d'un matériau portant la texture du capteur à un dessin ; un
  corps hors champ ne le pose pas, avec une image de retard à la rentrée ;
- l'atlas des textures de lumière est reconstruit en entier à chaque texture inédite : tout geste d'OM4 qui change quelle
  lumière tient quelle texture (flash, `hit_light`, `ground_flash`) change le nombre de reconstructions ; `ECLAT` n'est tenue
  que par les 240 lumières du pool de particules ;
- Q85 : la carte d'ombre est une bande de 2 lignes par lampe et par quart de tour ; un atlas 4096 coûte de la mémoire plus
  que du temps de passe.

**Depuis l'envoi de ces faits** (réponse de la session OMBRES, 2026-10-05, vérifiée sur sa branche) : OM1 est livré (PR #8,
commit `e2e1759`). Il règle D4 (le client connaît la source de son éblouissement) et applique Q81 au **corps** seul : un
plancher de 0,06 soustrait dans `Brouillage.opacite_vue`, rien dans `_dose` ni dans `brouillage_vue.gd`. D'où l'avis de D2 :
le plancher de l'appareil, s'il est retenu (Q89), va dans `BrouillageVue.maj`, jamais dans `_dose`. OMBRES a signalé à
Adrien le rognage des cookies de torche (LUM-04) comme constat de l'audit ; les autres faits sont notés pour OM6.

**Fichiers que l'audit propose de toucher et qu'OMBRES touche aussi** : `map_geometry.gd` (mémo de `build_grid`, lot 3),
`presentation_3d.gd` (`_suivre` et les uniformes, ISO-04), `game_state.gd` (`_accorder_rendu_aux_vues`, lot 7),
`brouillage*.gd` (plancher de l'appareil, Q89 : `BrouillageVue.maj` ; OM1 a touché `brouillage.gd`). Rien n'y sera écrit
sans accord de la session qui les tient.

---

## 8. Les mesures

Détail, commandes exactes et journaux : [`00_M_mesures.md`](audit_optimisation/00_M_mesures.md). Instruments (non
versionnés dans `tools/`, copiés en annexe) : [`instruments/`](audit_optimisation/instruments/).

**Coût d'une image sans rendu** (headless, `--fixed-fps 60`, horloge murale entre deux `process_frame`, Xeon 2,8 GHz) :

| Scénario | moyenne | p99 | Lecture |
|---|---|---|---|
| Au repos (iso) | 1,94 ms | 4,35 | plancher CPU de la scène montée |
| PvP, banc du projet, vue unique iso + fusée | 3,79-4,26 ms | 7,9-8,8 | deux prises, bruit ±6 % |
| idem, écran scindé iso | 4,43 ms | 8,78 | |
| idem, vue de dessus (`--2d`) | 2,17 ms | 4,82 | **l'iso coûte 1,6-2,1 ms de CPU** |
| Duel contre le bot, iso / `--2d` | 5,84 / 3,85 ms | 13,2 / 10,2 | |
| Solo, chapitre 0, salle 9 (6 PNJ, 24×24) | 7,15 ms | 14,5 | |
| Solo, chapitre 7, salle 9 (4 PNJ, 50×36) | 10,02 ms | **18,8** | au-delà de 16,7 ms (cible « 1 % bas ≥ 60 ») |
| Solo, chapitre 8, salle 9 (7 PNJ, 100×80) | 11,43 ms | **20,9** | idem ; le coût suit la taille de la carte plus que le nombre de PNJ |

Images singulières (MESURÉES) : départ de manche 450-530 ms ; coup fatal 17-27 ms ; début de killcam 24-35 ms ; panneau
de fin 86-121 ms (394 ms la première fois).

**Piège de mesure, payé puis vérifié dans les sources** : `Performance.TIME_PROCESS` et `TIME_PHYSICS_PROCESS` ne sont
rafraîchis qu'une fois par seconde et valent le **maximum** de la seconde (`main.cpp`) — jamais un coût par image. Et en
headless sans `--fixed-fps`, `OS::add_frame_delay` dort ~6,9 ms par image.

**Compteurs de rendu** (iso, vue unique, charge de référence du projet, 1920×1080 ; indépendants du matériel, à la
réserve du pilote) : **188 appels de dessin, 1 403 objets, 61 556 primitives dont 91 % dans la seule passe 3D** de la racine ;
9 viewports dont **6 rendent, 5,76 Mpx cumulés** (2,8 fois l'écran : racine, lightmap 1920×1080, peinture iso 1190², trois
capteurs 256²) ; 282 Mo de mémoire vidéo ; 254 `PointLight2D` dans l'arbre, dont 8 allumées et **7 à ombre**, pour
**792 arêtes d'ombre par image**, dont 14 couples lampe-viewport qui « n'éclairent rien » (les 7 lampes dans la peinture iso,
4 dans le capteur de la fusée) — LUM-03, compté ici par le banc lui-même. Écran scindé et vue de dessus : non mesurés.

**Décomposition sous llvmpipe** (rapports d'une même série, prises en miroir, porte stricte ; rien ne dit ce que voit le M3) :

| Variante | Effet sur le temps d'image | Lecture |
|---|---|---|
| Plancher d'auto-éblouissement sur le flou, sa copie d'écran et le halo du brouillage (A1) | **−0,3 %** (nul) | attendu : la coupure de passe d'un GPU à tuiles n'existe pas sous llvmpipe ; la PRÉSENCE de la copie et de la lecture d'écran à chaque image est, elle, PROUVÉE sans GPU (et retirée par A1) |
| Le voile « calme » plus dessiné au repos (A2, `modulate.a = 0` sous le plancher) | **−13 à −16 %** (−46 à −51 ms sur 314) | le shader plein écran du voile est lourd au pixel ; sur le Mac le gain serait bien moindre (ESTIMÉ 0,05-0,7 ms) — c'est une décision d'image (noir de 2-4/255 → 0) |
| Les trois ensemble (A12) | **−13,8 %** | |
| **L'arène plus rendue sous le menu du hub** (vp1/vp2 en `UPDATE_DISABLED`) | **−33,7 %** (167 → 111 ms ; −72 % d'objets, −75 % de primitives, 4,14 → 2,07 Mpx, −16 Mo de mémoire vidéo) | l'arène est rendue deux fois, puis recouverte à 96 % ; la couper figerait les 4 % visibles : petite décision d'aspect |

Aussi mesuré : la fusée coûte ≈ 0,8 ms de CPU par image ; l'écran scindé ajoute 0,2 à 0,9 ms.

**Non mesuré** (commande de chacun au § 8 de `00_M_mesures.md`) : le GPU à tuiles du M3 (prix réel d'une coupure de passe,
du voile, des deux vues) ; la fumée de fusée sous llvmpipe ; la reconstruction de l'atlas des lumières (V8, « D1 ») ; la
décomposition générale (torches, faisceau, ombres 2D, capteurs) ; trois configurations sur quatre des compteurs de rendu ;
l'attribution du coût du solo, PNJ par PNJ.

---

## 9. Ce qui est déjà bien fait — à ne pas casser

- **Aucun émetteur réseau au rythme du rendu** ; commandes numérotées, bornées et vérifiées côté hôte ; encodage compact
  (sept boutons en 7 octets) ; tampons bornés en temps, jamais en images.
- **Aucune vue cachée ne rend en match** (`UPDATE_DISABLED` sur la vue non regardée) ; la peinture iso est rendue à la
  demande ; les maillages ne sont jamais régénérés par image ; les figurants coupent leur capteur hors de portée.
- **L'allègement de la 0.8.0** : couches du rayon taillées à l'enveloppe du cookie, enveloppes calculées au décompte.
- **Variantes par `#define`** plutôt que par uniforme ; un matériau pour tous les murs, un pour les trois nappes ; filtre
  d'ombre `NONE` partout ; aucune lumière créée à l'image ; les lumières décoratives retirées avec méthode
  (`enabled = false`, pas `energy = 0`) ; le bandeau LED en une seule lumière cuite.
- **Pool de particules réel** (240 corps préalloués, plafond 200 avec recyclage) ; traces plafonnées avec éviction FIFO ;
  la balle sans lumière ; aucun `print()` dans un chemin chaud (`flush_stdout_on_print` ne coûte donc rien en match).
- **Le bot voit par le calcul**, sans physique ni GPU, au pas de physique, avec des générateurs séparés semés d'une seule
  graine ; navigation `AStarGrid2D` replanifiée sur événement.
- **Rejeu à 60 Hz fixe** dimensionné en temps ; journal des matchs plafonné et écrit de façon atomique ; miniatures peintes
  en `Image` sans `SubViewport`.
- **Le build** : `tools/`, `docs/`, les 90 Mo de `assets/sources/`, `supabase/` ne partent pas ; scripts en jetons
  binaires (82 000 lignes → 2,64 Mo) ; audio en QOA et en flux (17 Mo de sources → 5,78 Mo).

---

## 10. Méthode et limites

**Qui a fait quoi.** La session a orchestré ; chaque tâche a été confiée à un sous-agent Sonnet 5.5 :
- **14 auditeurs de domaine**, en lecture seule (chaîne iso, géométrie et voxels, shaders, lumières, joueur et balles,
  `game_state.gd`, gadgets et fusée, réseau, HUD, menus, audio, bot et solo, démarrage et build, cartes et rejeu) :
  164 constats, dont les CRITIQUES, MAJEURS et les doublons croisés ont tous été soumis à la vérification ;
- **9 lecteurs de la ROADMAP** : le document (2,9 Mo, 34 455 lignes) ne tient pas dans un seul contexte ; il a été lu
  **en entier**, par tronçons, pour en extraire mesures, décisions, pièges, invariants et pistes de performance ;
- **10 vérificateurs contradictoires** : chacun chargé de RÉFUTER un groupe de constats (code relu, appelants remontés,
  sources du moteur 4.7.1 et de l'addon EOSG lues quand il le fallait, croisement avec la ROADMAP et le chantier OMBRES) ;
- **1 agent de mesure**, seul à lancer Godot (4.7.1 officiel), dans un worktree isolé.

**Limites.**
- Rien n'a été vu sur le pilote d'Apple ni joué par un humain. Les coûts GPU sont ESTIMÉS (sauf ceux que la ROADMAP avait
  déjà mesurés) ; sous llvmpipe, la « coupure de passe » d'un GPU à tuiles n'existe pas : un écart nul n'y infirme pas un
  coût de passe plein cadre.
- Les coûts CPU MESURÉS le sont sur un Xeon ; le rapport au M3 (ESTIMÉ 1,5 à 2) n'est pas mesuré.
- Le commit audité est `52a29c1` ; la branche OMBRES a commencé à bouger l'éclairage depuis : les numéros de ligne sont
  ceux de `52a29c1`, à relire avant de s'y fier.
- Une limite d'usage des sous-agents a interrompu le travail quelques heures le 2026-10-05 ; tous les agents ont été
  repris avec leur contexte, aucune tâche n'a été abandonnée.
