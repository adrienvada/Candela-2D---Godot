# 12 — BOT : bot, IA des PNJ, mode solo et aventure

Audit d'optimisation du 2026-10-04 · commit `52a29c1` · **lecture seule, Godot non lancé** · préfixe `BOT`.

Périmètre lu en entier : `bot_input_provider.gd`, `perception_bot.gd`, `perception_bot_noeud.gd`, `navigation_bot.gd`, `profil_bot.gd`,
`memoire_bot.gd`, `equipement_bot.gd`, `aventure_carton.gd`, `aventure_format.gd`, `aventure_partie.gd`, `aventure_progression.gd`,
`serie_de_session.gd`, l'en-tête de `tools/banc_bot_difficulte.gd`. Lus en plus, parce que le bot les appelle : `game_state.gd` (points d'appel),
`ui.gd` (écran de l'aventure), `map_geometry.gd`, `map_codec.gd`, `murs_bas.gd`, `plafonnier.gd`, `weapon_data.gd`, `audio_manager.gd` (émission des sons),
`tools/flux_commandes_bot.gd`, `tools/test_bot_equipement.gd`, `tools/test_bot_combat.gd` (gardes).
Chiffres de contenu (taille des salles, nombre de PNJ…) calculés en décodant les JSON de `assets/solo/` avec `bot_stats.py` (dans ce dossier, Python, à lancer
depuis la racine du dépôt) : **PROUVÉS**. Tout temps en µs/ms est **ESTIMÉ** (voir §2) : aucune mesure de cadence d'aventure n'existe dans le dépôt.

---

## 0. Lecture rapide

1. **Le bot n'est pas un poste de coût majeur, et le code est sain là où ça compte** : zéro requête physique (aucun `intersect_ray`, aucun
   `PhysicsRayQueryParameters2D` dans les six fichiers), aucune lecture GPU par pas (une seule, unique par classe d'arme : BOT-10), un seul `_physics_process` par bot, un par nœud de perception, aucun `_process`,
   aucun `print`, `Timer` ni `create_tween` dans le chemin chaud, A* natif et replanifications sur événement. Coût **ESTIMÉ** de la couche bot + perception :
   ~0,04 à 0,10 ms par PNJ qui voit et par pas de physique ; **0,3 à 0,7 ms pour la salle la plus chargée** (8.9 : 7 PNJ, carte 100×80, 8 plafonniers),
   soit 2 à 4 % d'un budget de 16,7 ms. **Non mesuré** : la ROADMAP le dit elle-même (l.33729, « Le coût n'est pas mesuré »).
2. **Les vrais coûts d'un PNJ sont très probablement ailleurs** (un `Player` complet de 15 nœuds, trois lumières, un capteur 256² et un corps iso par PNJ à moins de
   1 300 px, les omni des plafonniers — ROADMAP l.32771). L'audit des lumières du 2026-10-04 (`CONTEXTE_CHANTIERS_EN_COURS.md` §1) estime les ombres 2D d'une salle 24×24 à 6 PNJ à ≈ 3 ms torches éteintes, jusqu'à 9,5 ms (modèle calé sur 0,09 ms par lampe à 8 occulteurs, « à lire entre ×0,4 et ×2 ») : de l'ordre de dix fois mon estimation du bot ; `05_JOU` compte de son côté un `Player` complet par PNJ (coût du domaine « multiplié par jusqu'à 9 »). À mesurer **avant** de pousser plus loin le travail sur le bot (Questions ouvertes, Q1).
3. **Un seul gel certain, et il est hors partie : BOT-01** — la première ouverture de l'écran Aventure valide *synchroniquement les 100 salles livrées*
   (123 951 cases de grille) : ESTIMÉ 0,6 à 2,5 s de fil principal figé, une fois par session.
4. **Ordre conseillé** (tout est exact, c'est-à-dire sans changer un bit de comportement du bot, sauf mention contraire) :
   BOT-01 (A* paresseux, une dizaine de lignes) → BOT-05 / BOT-06 (mémoïser ou supprimer des tris et balayages purs) → BOT-04 (partager le monde de la carte) →
   BOT-02 (sortie anticipée de `_voir`) → BOT-03 (fenêtre de repli) ; BOT-09 est une affaire d'ordre d'appel qui masque *toute* la construction d'une salle ; BOT-10 est un préchauffage d'une ligne par classe ; BOT-07 et BOT-08 ne valent que si la mesure les réclame.
5. **Le déterminisme tient à peu de chose** (§5) : sept générateurs semés depuis une graine, un ordre de nœuds Player → bot → perception, un A* à tie-break fixe.
   **Les empreintes md5 existantes ne couvrent PAS** l'équipement, la mise en joue, les rafales, la fouille ni les tempéraments (S9–S11) : avant de toucher
   `_equiper`, `case_de_repli`, `_fouiller`, il faut relever de nouvelles empreintes sur `52a29c1`.

### Tableau des constats

| ID | Sévérité | Quoi | Effort | Statut ROADMAP |
|---|---|---|---|---|
| BOT-01 | MAJEUR | Écran Aventure : validation synchrone de 100 salles à la première ouverture | S puis M | NOUVEAU |
| BOT-02 | MINEUR | `_voir` complet même quand rien ne peut être vu ; ~20 conteneurs par pas et par PNJ, dupliqués | S puis M | CONNU-OUVERT (coût non mesuré) / NOUVEAU (proposition) |
| BOT-03 | MINEUR | `case_de_repli` balaie toute la composante connexe à chaque repli | S | NOUVEAU |
| BOT-04 | MINEUR | Le « monde » du modèle de vue est reconstruit par chaque PNJ ; la même carte est décodée ~21 fois | S | NOUVEAU |
| BOT-05 | MINEUR | Fonctions pures de navigation recalculées en chemin fréquent (`case_praticable_proche` par pas, `cases_dans` par tirage) | S | NOUVEAU |
| BOT-06 | MINEUR | Tris GDScript inutiles ou surdimensionnés (`_numeroter_les_composantes`, `case_loin_de`) | S | NOUVEAU |
| BOT-07 | MINEUR | Murs bas : forme de lumière refaite à chaque ligne de vue, aucun pré-filtre (2 salles concernées) | S | NOUVEAU |
| BOT-08 | ANECDOTIQUE | Chaîne d'équipement : lookups dynamiques répétés à chaque pas | S | NOUVEAU |
| BOT-09 | MINEUR | Le carton de salle s'affiche *après* la construction de la salle, pas pendant | S | NOUVEAU |
| BOT-10 | MINEUR | Cookie de torche jamais préchauffé : premier échantillon CPU en pleine partie (domaine éblouissement) | S | NOUVEAU |

---

## 1. Réponses aux cinq questions de la mission

**Q1 — Coût par pas d'un bot / PNJ.**
- *Décisions* : chaque bot décide **à chaque pas de physique (60 Hz)**, sans échelonnement : `_penser` (`bot_input_provider.gd:571`) enchaîne 8 sous-étapes
  puis `_equiper` (`:886`) pour les profils équipés (92 PNJ « equipe » dans 27 salles, 5 au plus par salle, plus les 10 boss) ; `avancer` (`:363`) suit. Environ une quarantaine d'appels GDScript et une
  quinzaine de `corps.get("…")` dynamiques par pas (comptage par lecture, à quelques unités près).
- *Raycasts et visibilité* : **aucune requête physique** (grep des six fichiers : 0 occurrence de `intersect_ray`, `PhysicsRayQueryParameters2D`, `direct_space_state`).
  La visibilité est un **parcours de grille case par case** (Amanatides-Woo, `perception_bot.gd:195-239`, décision ROADMAP l.4079 et l.31974), plus le test de polygones d'ombre des
  gadgets (`:246-272`) et la règle des murs bas (`murs_bas.gd:223-237`, rarement sollicitée : 18 salles sur 100 en ont). Par pas et par PNJ : **0** parcours de grille quand la cible
  est hors du cadre, 1 à 3 en général, une vingtaine au pire (cône de torche + points du corps + plafonniers à portée).
- *Comment il « voit »* : par un **modèle géométrique en fonctions pures** (`PerceptionBot.voir`, `:448`), **jamais par le moteur de lumière** : le nœud relit des *propriétés* des nœuds
  `Light2D` (`enabled`, `energy`, `global_position`, taille de texture × `texture_scale`, `height` : `perception_bot_noeud.gd:273-354`) et échantillonne l'`Image` CPU du cookie de torche
  (`WeaponData.lumiere_recue`, `weapon_data.gd:322`). Les capteurs GPU (`CapteurCorps`) ne servent qu'au banc de validation en fenêtre (ROADMAP l.31707-31715, décision d'Adrien « par le calcul »).
- *Allocations* : de l'ordre de **19 + P conteneurs** (Dictionary/Array, P = plafonniers de la salle) et ~20 + 3P lectures dynamiques par pas et par PNJ qui voit (comptage par lecture, à quelques unités près ;
  détail dans BOT-02). GDScript compte les références : pas de pause de ramasse-miettes, le coût est du temps CPU, pas des hoquets.

**Q2 — Navigation.** `AStarGrid2D` natif (`navigation_bot.gd:127-143`), **pas** de `NavigationServer`/`NavigationAgent`. Une case de grille = une tuile de 35 px ; `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`,
heuristique OCTILE, poids 1,6 sur les cases voisines d'un mur, cases « étranglées » (couloir d'une tuile) solides. Taille de grille : 16×16 à **100×80** en aventure (8 000 cases), ≤ 32×32 sur les six cartes
de duel, jusqu'à 128×128 pour une carte joueur (`MapCodec.MAX_GRID`). **Recalcul sur événement, jamais par pas** : cible suivante d'une patrouille (`_decider`, `bot_input_provider.gd:434`), blocage détecté
(`_guetter_le_blocage`, fenêtres de 0,6 s et 1,2 s), mémoire déplacée de ≥ 2 cases (`CASES_AVANT_REPLANIFIER`), repli. Un but injoignable est temporisé à 1 s (`DELAI_REPLANIFICATION`). Une grille d'A* **de la taille de la
carte** est de plus construite, paresseusement, par rectangle de ZONE distinct (`:166-171`, décision ROADMAP l.31894). Seuls deux appels *par pas* touchent la navigation sans être des chemins :
`_case_de` et `_suivre_la_memoire` → `case_praticable_proche` (BOT-05).

**Q3 — Aventure.**
- *PNJ simultanés* : validateur `PNJ_MAX = 8` (`aventure_format.gd:102`) ; **livré : 255 PNJ dans 100 salles, 2,55 en moyenne, 7 au plus (salle 8.9, carte 100×80)**. 234 agissent, 215 voient et 194 entendent
  (boss compris), 21 sont sourds et aveugles (aucun nœud de perception, `_penser` sauté), 92 sont équipés par la clé « equipe » (5 au plus par salle ; les 10 boss le sont par leur palier). **S12 : 47 PNJ à tempérament dans 32 salles, 3 au plus dans une même salle** (guetteur 15, embusqué 12, traqueur 13,
  peureux 7) — le tempérament ne coûte rien de plus par pas (quelques booléens).
- *Salles hors de vue ou inactives* : **il n'en existe pas** — une seule salle vit à la fois ; les PNJ de la précédente sont retirés *immédiatement* (`remove_child` puis `queue_free`, `aventure_partie.gd:212-222`) et
  se désabonnent du signal de son (`perception_bot_noeud.gd:117-122`). Dans la salle, **tous les PNJ vivants tournent à chaque pas, sans endormissement ni niveau de détail par distance** (seuls les capteurs iso sont
  bornés à 1 300 px, `presentation_3d.gd:161`). Un PNJ mort sort tôt des deux `_physics_process` du bot (`dead`), reste dans l'arbre jusqu'à la salle suivante.
- *Chargement* : (a) **la première ouverture de l'écran Aventure valide les 100 salles d'un coup** (BOT-01) ; (b) **entrer dans une salle ou la recommencer après une mort construit tout dans une seule image**
  (`_poser_la_salle`, `aventure_partie.gd:154-172`) : arène, plafonniers, une `NavigationBot` neuve, et pour chaque PNJ un `Player` instancié et un « monde » de perception reconstruit (BOT-04) ; le carton n'est montré
  qu'à la fin (BOT-09). Le JSON lui-même (222 Ko au total, 7,6 Ko pour la plus grosse salle) est négligeable.

**Q4 — Mémoire.** **Rien ne grandit sans borne en partie.** `MemoireBot` : une seule trace (O(1)). `zones_recentes` : plafonné à 8 (`ZONES_GARDEES`). `noms_des_lumieres` : vidé à chaque pas. `poses_par_gadget` :
une clé par gadget du catalogue (10). `_astar_par_zone` : une grille par rectangle de zone *distinct* d'une salle (≤ 8), libérée avec la `NavigationBot` (qui vit autant que les PNJ). `AventureFormat._cache` : statique, une entrée
par racine (100 salles préparées, quelques centaines de Ko de chaînes RLE). Les tableaux de réserve de `GameState` sont redimensionnés à 2 par `liberer_les_pnj` à chaque salle. Pas de fuite de signal (`_exit_tree`). Seule croissance : des
entiers de comptage (`sons_entendus`, `pas_vus`, `coups_tires`).

**Q5 — Déterminisme des bancs.** Voir §5. En une phrase : **préférer des optimisations *structurelles* (sauter, partager, mémoïser une fonction pure) aux réécritures arithmétiques ou temporelles** ; ne jamais changer le nombre ni l'ordre
des tirages d'un des sept générateurs, ni l'ordre Player → bot → perception, ni la cadence de la perception sans rejouer la matrice 80/55/30.

---

## 2. Hypothèses d'estimation

Je suppose, pour GDScript 4.x sur un Mac de classe M : 0,1–0,3 µs par appel de fonction GDScript, 0,1–0,2 µs par `Object.get()` dynamique, 0,3–0,6 µs par Dictionary littéral de 4–8 clés, 0,3–0,6 µs par
`get_nodes_in_group` sur un petit groupe, ~0,5 µs par appel `est_libre`, 0,15 µs par cellule décodée d'une chaîne RLE. **Aucune de ces valeurs n'est mesurée dans ce dépôt** ; elles servent à classer les postes entre eux, pas à promettre un gain. La seule
mesure voisine : « un duel de 6 s de jeu coûte ~1 s de processus » (ROADMAP l.32254), headless, **tout le jeu compris, deux bots qui perçoivent** — soit ≤ 2,8 ms par pas pour l'ensemble, borne supérieure très lâche.

---

## 3. Carte des chemins chauds

| Fréquence | Quoi | Où | Quantités (pire cas = salle 8.9 : 7 PNJ, 100×80) |
|---|---|---|---|
| **par pas de physique × PNJ qui agit** | `BotInputProvider._physics_process` → `_penser` (état, engagement, visée, fouille, peur, alignement, tir, recharge) puis `avancer` | `bot_input_provider.gd:337, 571, 363` | 7 PNJ (234 des 255 PNJ livrés agissent) |
| par pas × PNJ équipé | `_equiper` → torche, posture, `_gerer_la_fusee`, `_gerer_le_gadget` (`Equip.jeu_du`, `slug_du_gadget`, `gadget_basculable_de`) | `:886, 944, 963` ; `equipement_bot.gd:342-359` ; `game_state.gd:3618` | 5 équipés |
| **par pas × PNJ qui voit** | `PerceptionBotNoeud._physics_process` → `_voir` : `_bot`, `_lire_les_gadgets`, `_adversaire`, `_lumieres` (+ `_plafonniers`), `PerceptionBot.voir` | `perception_bot_noeud.gd:147, 159, 225, 206, 308, 342` ; `perception_bot.gd:448` | 7 PNJ ; 8 plafonniers ; ≈ 19 + P conteneurs et 0–22 parcours de grille par PNJ et par pas |
| par pas × PNJ en enquête/recherche | `avancer` → `_suivre_la_memoire` → `case_praticable_proche` | `bot_input_provider.gd:389-390, 852-857` ; `navigation_bot.gd:227-244` | jusqu'à 7 |
| par pas × PNJ en patrouille sans chemin | `_decider` : jusqu'à 8 tirages × 2 tours, chacun avec `prochaine_cible` (→ `cases_dans` en ZONE) | `bot_input_provider.gd:396-398, 434-447, 477-495` ; `navigation_bot.gd:119-124` | état d'échec seulement |
| par son localisé × PNJ qui entend | `_sur_un_son` → `PerceptionBot.ecouter` (3 parcours de grille si le son est entendu) | `perception_bot_noeud.gd:129` ; `perception_bot.gd:533` | 194 PNJ « entendent » sur 255 ; les PNJ se rejettent entre eux au 1er test (`emetteur` = 1 pour tous, `audio_manager.gd:1793`) |
| par événement | replanification (A* natif) : nouvelle cible, blocage, mémoire déplacée ≥ 2 cases | `bot_input_provider.gd:434, 523, 852` | quelques par seconde et par PNJ au plus |
| par événement (fin de rafale, peur, mine/suie posée) | `_planifier_un_repli` → `Equip.case_de_repli` → jusqu'à 8 A* | `bot_input_provider.gd:1019` ; `equipement_bot.gd:126` | 1 à 3 par seconde en combat |
| par salle (entrée ou reprise après mort) | `_poser_la_salle` → `_creer_les_pnj` : `NavigationBot.depuis_carte`, N × (`instantiate` + `configurer` + monde de perception) | `aventure_partie.gd:154-207` | 8 000 cases ; ~21 `build_grid` |
| **par première ouverture de l'écran Aventure** | `chapitres_livres` → 10 × `charger_chapitre` → 100 × `valider_niveau` (+ une `NavigationBot` chacune) | `aventure_format.gd:490-515` ; `ui.gd:5419-5422, 5920-5924` | 123 951 cases de grille |
| par lancement d'entraînement / réapparition | `NavigationBot.depuis_carte`, `case_loin_de` (tri complet) | `game_state.gd:1075-1114, 1156-1193` | ≤ 32×32 livrées ; 128×128 possibles |
| par salle gagnée | 2 écritures de `user://solo.cfg` (< 2 Ko) : `noter_temps`, `reussir_niveau` | `aventure_progression.gd:127-155` | négligeable |

**Au pas, hors de mes fichiers mais proportionnel au nombre de PNJ** (à transmettre) : `GameState._maj_eblouissement` tourne dans `_process`, donc **par image rendue (fps déplafonnés)**, avec 2 + N cibles et un Dictionary par source
(`game_state.gd:2081, 2197, 2360-2406, 2410`) ; `Plafonnier._physics_process` ×P relit le groupe `players` et fabrique un tableau de positions (`plafonnier.gd:261-275`, chiffré par `02_GEO` à ≈ 0,03 ms/pas). **Autres recoupements** : `AudioManager._annoncer` construit son dictionnaire de 18 clés pour chaque son positionnel dès qu'un écouteur est connecté — et un bot qui entend en est un (`perception_bot_noeud.gd:112-114`, noté par `11_AUD`) ; `ReplaySystem.record_frame` continue d'enregistrer pendant l'aventure sans que rien l'exploite (ROADMAP l.32782, `game_state.gd:2220-2221`).

---

## 4. Constats

### BOT-01 — Première ouverture de l'écran Aventure : validation synchrone des 100 salles livrées

- **Où** : `aventure_format.gd:490-515` (`chapitres_livres`), `:460-484` (`charger_chapitre`), `:407-435` (`valider_chapitre`), `:181-248` (`valider_niveau`), `:601-628` (`_carte_normalisee`) ;
  `navigation_bot.gd:80-92` (`_construire`), `:127-151` (`_fabriquer_astar`, `_pres_d_un_mur`) ; déclencheur `ui.gd:5920-5924` → `:5419-5422`.
- **Constat** : l'écran Aventure appelle `AventureFormat.chapitres_livres()` ; au premier appel il charge **les dix chapitres** et valide **chacune des 100 salles**, y compris la construction d'une `NavigationBot` complète par salle (jetée ensuite), alors
  que la validation n'a jamais besoin de chemins.
  ```gdscript
  # aventure_format.gd:466 — pour chaque chapitre, valider_niveau(n) sur ses dix salles
  erreurs.append_array(valider_chapitre(manifeste, lu["niveaux"], niveaux_attendus if attendus < 0 else attendus))
  # aventure_format.gd:221 — une NavigationBot par salle, pour juger quelques cases
  navigation = NavigationT.depuis_carte(lue)
  # navigation_bot.gd:84-91 — 3 build_grid, une boucle à jusqu'à 4 est_libre par case de sol, puis l'A* (inutile ici)
  _solide = Geometrie.build_solid_grid(data)
  ...
  _astar = _fabriquer_astar(Rect2i())          # _pres_d_un_mur : jusqu'à 8 est_libre par case praticable
  ```
  Le cache (`_cache`, `:123, 491-493`) évite de recommencer aux ouvertures suivantes ; la première coûte tout. Le commentaire de `:488-489` le sait (« valider coûte une grille de navigation par salle ») sans le chiffrer.
- **Coût** : PROUVÉ — 100 salles, Σ(L+2)(H+2) = **123 951 cases de grille**, 87 656 cases de sol, 23 135 de mur, dont le chapitre 8 seul 36 524 (29 %) ; chacune des 87 656 cases de sol paie `_etranglee` (jusqu'à 4 `est_libre`) et, si elle est praticable, `_pres_d_un_mur` (jusqu'à 8 `est_libre`). ESTIMÉ — **0,6 à 2,5 s de fil principal figé**, réparti à peu près ainsi : A* ≈ 33 %, trois `build_grid` par salle (qui re-décodent chacune les trois chaînes RLE) ≈ 24 %, boucle de `_construire` ≈ 22 %,
  numérotation des composantes (tri, BOT-06) ≈ 13 %, `check_playable` et copies ≈ 8 %. Se produit une fois par session, au clic sur « Aventure » depuis l'écran Solo (le menu est figé, sans que le gel soit masqué par quoi que ce soit).
  Même constructeur à chaque lancement d'entraînement (`game_state.gd:1076`) : ESTIMÉ ~12 ms pour 1 100 cases, ~150–250 ms pour une carte joueur 128×128.
- **Proposition** (par ordre croissant d'effort, cumulables) :
  1. **A* paresseux** : `_construire` ne construit plus `_astar` ; `chemin()` (`:160`) le fabrique au premier appel. Aucun test ne touche `_astar` / `_astar_par_zone` (grep `tools/` et racine : 0 occurrence hors `navigation_bot.gd`) ; la validation de format n'appelle jamais `chemin()`.
  2. **Charger par chapitre** : l'écran n'a besoin, pour *tous* les chapitres, que du titre, de `classe_imposee` et de leur existence (`ui.gd:5441-5447, 5476-5480`) ; les salles ne servent que pour le chapitre pris (`:5436, 5483-5489, 5567-5573`). Lire les dix
     manifestes (11 lectures, sans validation de salle) à l'ouverture, et ne valider les dix salles d'un chapitre qu'au moment de le prendre : ~10× moins au premier affichage. Six sites d'appel dans `ui.gd` (`:5422, 5494, 5513, 5533, 5563, 5583`).
  3. Ou **valider en tâche de fond d'image** : une salle par image (`await get_tree().process_frame` entre deux salles) depuis l'écran Solo, pour que l'ouverture trouve le cache plein.
  4. (Décision d'Adrien) **ne pas valider les salles *livrées* à l'exécution d'un export** : elles le sont par les suites (`test_aventure_format`, `test_chapitre_00` à `_09`, `test_chapitres_marche*`) ; la validation resterait pour les builds de debug et les chapitres d'essai.
     Contre : le principe fondateur du fichier (« Une salle mal écrite doit se VOIR », `:10-16`).
- **Gain attendu** : (1) ≈ −30 à −35 % exact, sans autre changement ; (2) de l'ordre de 10× sur le premier affichage (ESTIMÉ ≈ 0,1–0,25 s pour un chapitre, 0,45 s pour le chapitre 8) ; (3) masque le gel entièrement.
- **Risque** : gameplay/équité/réseau/visuel : aucun. Déterminisme des bancs : aucun RNG du bot concerné ; **mais** `MapCodec.validate` appelle `generate_id()` → `randi()` **global** pour chaque carte sans `id` (les 100 cartes livrées n'en ont pas :
  `map_codec.gd:187-188, 251-252`) : déplacer ou retarder la validation déplace ~100 tirages du flux global (sans effet en jeu ; le banc reseede par image, ROADMAP l.3408-3426). **Ne pas déplacer cette validation dans un fil**
  (accès concurrent au `randi()` global). Option 2 : change le contrat de `chapitres_livres()` (six appels `ui.gd`, `test_aventure_format`).
- **Effort** : S (1) · M (2, 3).
- **Sévérité** : MAJEUR (seul gel certain de mon périmètre ; hors duel, donc sans effet sur le « 1 % bas » mais bien visible).
- **Statut ROADMAP** : NOUVEAU (aucune mention de `chapitres_livres` ni de ce coût dans `docs/ROADMAP.md` ; seul le commentaire du code en parle).
- **Comment le vérifier** : script headless de mesure (à écrire par l'agent de mesure, il n'existe pas) :
  ```gdscript
  extends SceneTree
  const F := preload("res://aventure_format.gd")
  func _init() -> void:
  	var t := Time.get_ticks_usec()
  	var c := F.chapitres_livres()
  	print("chapitres_livres : %d chapitres en %.0f ms" % [c.size(), (Time.get_ticks_usec() - t) / 1000.0])
  	quit()
  ```
  (`godot --headless --path . --script res://tools/<ce_script>.gd`). Non-régression : `test_aventure_format`, `test_chapitre_00`…`_09`, `test_aventure_partie`, et l'égalité de `JSON.stringify(chapitres_livres())` avant/après.

### BOT-02 — Perception : `_voir` complet pour des PNJ qui ne peuvent rien voir, et ~20 conteneurs reconstruits par pas et par PNJ

- **Où** : `perception_bot_noeud.gd:147-184` (`_physics_process`, `_voir`), `:206-211` (`_adversaire`), `:225-242` (`_lire_les_gadgets`), `:308-335` (`_lumieres`), `:342-354` (`_plafonniers`) ; `perception_bot.gd:448-490` (`voir`).
- **Constat** : à **chaque pas**, pour **chaque** PNJ qui voit, le nœud relit seul les mêmes quatre groupes de nœuds et refabrique la liste complète des lumières, puis exécute `voir()` — **même quand ni le corps ni la lampe de l'adversaire ne peuvent
  être dans le cadre**, cas où `voir()` rend nécessairement « rien » quelles que soient les lumières (`vu` exige `corps_dans_le_cadre` ou une lampe `dans_le_cadre`, `perception_bot.gd:458, 466-474`).
  ```gdscript
  # perception_bot_noeud.gd:167-181 (extrait)
  _cadre = Percep.cadre_de_vue(bot["position"], bot["visee"], reglages)     # Dictionary ; voir() en refait un autre (perception_bot.gd:457)
  _lire_les_gadgets()                         # get_nodes_in_group("gadgets") + Array + 2 écritures dans monde
  var adversaire := _adversaire()             # get_nodes_in_group("players")
  var lumieres := _lumieres(adversaire)       # ~9 + P conteneurs ; "fusees" et "plafonniers" relus
  ...
  derniere_vue = Percep.voir(bot, cible, lumieres, monde, reglages)
  # :344-353 — identique pour tous les PNJ d'un même pas
  for p in get_tree().get_nodes_in_group(Plafonnier.GROUPE):
  	...get_node_or_null("Halo")... sortie.append(Percep.lumiere_disque(String((p as Node).name), halo.global_position, r, halo.height, true))
  ```
- **Coût** : comptage par lecture (à quelques unités près) — par pas et par PNJ qui voit : ≈ 19 + P conteneurs (`_bot` 1, `reglages` 1, `cadre_de_vue` ×2, groupes gadgets/players/fusées/plafonniers 4 + leurs tableaux de sortie, `_lumieres` ≈ 5 + P dictionnaires de lumière, `cible`, `res`, `par`), ≈ 20 + 3P lectures de
  propriétés, 0 à ~22 parcours de grille. Les plafonniers (jusqu'à 8) pèsent P × (`get_node_or_null("Halo")` + 4 lectures + 1 Dictionary). ESTIMÉ ≈ **25 à 60 µs par PNJ et par pas** ; ×7 en 8.9 ≈ 0,2 à 0,4 ms. Dans les grandes salles (le cadre,
  1 009 × 720 px tourné de 45°, ne couvre que ~7 % d'une carte 100×80), **la plupart des PNJ sont hors cadre la plupart du temps** : ESTIMÉ 60 à 70 % de ce coût est du travail dont le résultat est connu d'avance.
- **Proposition** :
  1. **Sortie anticipée exacte** dans `_voir`, après la mise à jour de `_decalage_lisse`, du cadre et de `monde["ebloui"]` : si `not Percep.dans_le_cadre(adversaire.global_position, _cadre, Percep.RAYON_CORPS)` **et** (la lampe de l'adversaire ne brûle pas
     **ou** `not Percep.dans_le_cadre(lampe.global_position, _cadre)`), poser `derniere_vue = {"vu": false, "dans_le_cadre": false, "par": [], "position": Vector2.ZERO}` (c'est exactement ce que `voir()` rendrait, aveuglé ou non) et rendre la main sans construire `_lumieres`
     ni appeler `voir`. **Ne jamais sauter** `_decalage_lisse = Regard.lisser(...)` (état à chaque pas).
  2. **Cliché de scène partagé par pas**, clé `Engine.get_physics_frames()` : l'adversaire, sa lampe et son éclair, les disques de plafonniers (leur état ne change qu'au `_physics_process` de chaque plafonnier, hors du bloc contigu des PNJ dans l'arbre), construits une fois puis réutilisés par les N PNJ. **Garder dans
     le même ordre** [cône, halo, éclair du bot, lampe adverse, éclair adverse, fusées, plafonniers] (la première lampe/éclair vu donne `res["position"]`). **Laisser par PNJ** les groupes `gadgets` et `fusees` (un PNJ qui lance une fusée ou pose un gadget *pendant son propre pas* serait vu par les suivants du même pas : un cliché partagé
     les ratera), ou clé supplémentaire `get_node_count_in_group`.
  3. (Micro) ne calculer `Portee.demi_empreinte(...)` qu'une fois (constantes), ne refaire `cadre_de_vue` qu'une fois (passer `_cadre` à `voir` via `reglages`).
- **Gain attendu** : (1) ESTIMÉ −15 à −40 µs par PNJ lointain et par pas → ≈ 0,1 à 0,25 ms par pas en 8.9 ; neutre dans les petites salles (le cadre couvre toute la salle). (2) ≤ 0,1 ms par pas en 8.9 : à ne faire que si la mesure (Q1) montre que la perception compte.
- **Risque** : équité — nul si (1) est exact (on ne change pas ce que le bot voit, seulement le moment où l'on constate qu'il ne voit rien). Gardes à ménager : `noms_des_lumieres` est lu par `test_plafonniers.gd:689-736` et `test_bot_perception.gd:911, 1039` (le garder à jour, ou en faire un getter paresseux) ;
  des tests qui appellent `_voir` à la main deux fois dans la même image invalideraient le cliché (2). Déterminisme des bancs : exact si l'ordre des lumières et `_decalage_lisse` sont préservés ; la perception **ne doit pas** être fusionnée dans `_penser` ni ralentie (voir §5, menaces 2 et 3). **Coordination** : `_plafonniers()` (`:342-354`) lit le `Halo` des plafonniers que le chantier OMBRES (OM5 « plafonniers », OM6 « halos sans récepteur », session `candela-2d-godot-d4`, branche `claude/determined-pasteur-mtrws1`) peut retoucher ; OM6 sait déjà qu'il faut passer par `shadow_enabled` et jamais par `enabled`, que cette lecture exige — à confirmer avec cette session avant d'écrire dans ce fichier, et jamais de `git merge` dans sa branche (CLAUDE.md).
- **Effort** : S (1) · M (2).
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : CONNU-OUVERT pour le coût (« Le coût n'est pas mesuré », l.31850, 31854, 32540, 32771, 33262, 33729 — la salle 8.9 y est citée) ; NOUVEAU pour la proposition.
- **Comment le vérifier** : suites `test_bot_perception`, `test_plafonniers`, `test_bot_combat`, `test_aventure_partie` ; **exactitude** : `banc_bot_difficulte.gd --duels=4 --trace --brut=avant.json` (mêmes `--cartes`/`--part`), idem après, diff des traces ; **gain** : temps de physique moyen
  (`Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)`, 600 pas headless `--fixed-fps 60`) dans la salle 8.9 avec 0 puis 7 PNJ, ou chronomètre `Time.get_ticks_usec()` autour de `_voir`.

### BOT-03 — `case_de_repli` balaie toute la composante connexe de la carte à chaque repli

- **Où** : `equipement_bot.gd:126-153` ; appelé par `bot_input_provider.gd:1019-1037` (`_planifier_un_repli`), lui-même par `_equiper` (`:903-907`, fin de rafale), `_gerer_la_peur` (`:719`) et `_commencer_le_puis` (`:1011`).
- **Constat** :
  ```gdscript
  # equipement_bot.gd:135-146
  for c in navigation.cases_atteignables(ici):       # toute la composante connexe : jusqu'à ~7 000 cases en 8.9 (7 148 cases de sol)
  	var centre := Navigation.centre_de_la_case(c)
  	var vers := centre - position
  	var d := vers.length()
  	if d < fenetre.x or d > fenetre.y:             # fenêtre de 105–260 px (latéral) ou 175–350 px (recul) : > 95 % rejetées ici
  		continue
  	...
  	if Percep.segment_degage(menace, centre, monde):   # un parcours de grille par candidate restante
  ```
- **Coût** : PROUVÉ — O(taille de la composante) par repli au lieu de O(fenêtre) ; la fenêtre tient dans ±11 cases (≤ 529 cases) autour du bot. ESTIMÉ ≈ 1 ms pour ~1 200 cases (salles 2.9 à 5.9, 5 PNJ), **≈ 5 ms pour ~7 000 cases** (8.9), par repli ; un repli par fin de rafale
  (PNJ NORMAL/DIFFICILE équipés : `repli_apres_tir_s > 0`, `profil_bot.gd:453, 458`), donc au moment le plus chargé d'un combat, plus jusqu'à 8 A* natifs (`ESSAIS_REPLI`).
- **Proposition** : parcourir seulement la fenêtre carrée de `ceil(fenetre.y / 35) + 1` cases autour de `ici`, **dans le même ordre de lecture (y puis x)**, en testant l'appartenance à la composante de `ici` (exposer `NavigationBot.meme_composante(a, b)` ou `numero_de_composante`). Reproduire
  le comportement de `cases_atteignables` : liste vide si `ici` n'est pas praticable.
- **Gain attendu** : ×2 sur les salles de ~1 000 cases, ≈ ×10 sur 8.x ; supprime les pics de 3–5 ms au moment du tir.
- **Risque** : exact — les tableaux `cachees` et `ouvertes` sont des sous-suites identiques du même ordre de lecture, donc `rng.randi_range(0, g.size() - 1)` tire les mêmes indices (`_rng_equipement` consomme les mêmes tirages). Mais **ce chemin n'est couvert par aucune empreinte md5**
  (`Flux.sans_equipement`, `tools/flux_commandes_bot.gd:205-222`, éteint le repli) : relever d'abord des empreintes de profils équipés (§5).
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : `test_bot_equipement` (repli, mine qui recule, suie), `test_aventure_boss` ; nouvelles empreintes avant/après ; mesure : chronomètre autour de `case_de_repli` dans une salle de 5 000 cases.

### BOT-04 — Le « monde » du modèle de vue est reconstruit par chaque PNJ ; la même carte est décodée ~21 fois au chargement de la plus grosse salle

- **Où** : `perception_bot_noeud.gd:75-81` (ligne 77), `bot_input_provider.gd:331-334`, `perception_bot.gd:162-171`, `map_geometry.gd:128-172` (`build_grid`), `:176-190` (`build_solid_grid`), `:321-328` (`rects_monde`), `map_codec.gd:73-94` (`decode_runs`) ; `aventure_partie.gd:175-207`.
- **Constat** : chaque `PerceptionBotNoeud.configurer` appelle `PerceptionBot.monde_de_la_carte(carte)` : `build_grid(WALLS)` **et** `rects_monde(LOW_WALLS)` (= un `build_grid` + un `merge_rects`), sur la *même* carte pour les N PNJ, alors que la `NavigationBot` (déjà construite, `aventure_partie.gd:176`) a calculé les mêmes grilles puis les a jetées.
  Et chaque `build_grid` re-décode les **trois** chaînes RLE et remplit **trois** ensembles même quand `kind` n'en lit qu'un (`WALLS` ne lit que `wall_set`).
  ```gdscript
  # perception_bot.gd:163-166
  "murs": Geometrie.build_grid(data, Geometrie.Kind.WALLS),
  ...
  "murs_bas": Geometrie.rects_monde(data, Geometrie.Kind.LOW_WALLS),
  ```
- **Coût** : PROUVÉ — salle 8.9 (grille de 102 × 82 = 8 364 cases, 7 PNJ) : arène 4 `build_grid` (`game_state.gd:1496-1497`) + navigation 3 + perception 7 × 2 = **21 `build_grid` et ~11 `merge_rects`** de la même carte. ESTIMÉ ≈ 8 ms par `build_grid` → **~170 ms + ~35 ms**
  de fusion au chargement de cette seule salle, dont environ 160 ms attribuables à la navigation et à la perception (17 des 21 `build_grid`, 7 des 11 fusions) ; ≈ 1 à 2 ms par `build_grid` et ~10–15 ms au total pour une salle typique de 1 100 cases. Se paie à chaque entrée **et à chaque reprise après une mort**.
- **Proposition** : (a) une seule construction du monde par `NavigationBot` (`monde_de_vue()` mémoïsé, copie *superficielle* par nœud : `murs` et `murs_bas` partagés en lecture seule, `aveugle`/`obstacles`/`ebloui` propres à chaque nœud) ; (b) ne décoder et ne remplir dans `build_grid` que les ensembles que `kind` lit
  (WALLS : murs ; LOW_WALLS : bas et murs ; PITS : les trois) et ne décoder qu'une fois dans `build_solid_grid` (9 décodages → 3) — `map_geometry.gd` est le fichier de l'agent arène, à coordonner ; (c) option : `PerceptionBotNoeud.configurer` accepte un monde déjà construit (paramètre facultatif).
- **Gain attendu** : ESTIMÉ −100 à −150 ms au chargement de 8.9 (et −60 % sur tout `build_grid(WALLS)` côté arène), ≤ 10 ms ailleurs.
- **Risque** : aucun sur le comportement (données pures, mêmes valeurs). Piège : un dictionnaire de monde *partagé et modifié* — `aveugle`, `obstacles`, `ebloui` sont écrits à chaque pas (`:241-242, 171`), donc la copie par nœud est obligatoire. Les tests construisent leur monde par `monde_de_la_carte` (API inchangée).
- **Effort** : S (a, c) · M (b, selon l'agent arène).
- **Sévérité** : MINEUR.
- **Recoupement dans cet audit** : `14_CAR_cartes_replay.md` CAR-03 propose de mémoïser `build_grid`/`rects_monde` **par contenu** dans `MapGeometry` (de 20 à 3 constructions, estimation concordante : 9–12 ms par `build_grid` en 8.9) et compte déjà « jusqu'à 14 de plus à la salle 8.9 » côté bot. Si CAR-03 est livré, (b) et le gros de (a) sont absorbés. Ce que BOT-04 apporte à CAR-03 : **la vérification d'aliasing que CAR-03 demande** — `navigation_bot.gd` ne fait que lire `_solide` (`:99`) et `perception_bot.gd` que lire `monde["murs"]` (`:176`) et `monde["murs_bas"]` (`:283, 298`) ; une grille partagée en lecture seule leur convient. Le dictionnaire `monde` lui-même (`aveugle`, `obstacles`, `ebloui`) reste, lui, à copier par nœud.
- **Statut ROADMAP** : NOUVEAU (recoupe CAR-03 de cet audit).
- **Comment le vérifier** : `test_bot_perception`, `test_aventure_partie`, `test_plafonniers` ; mesure : chronomètre autour de `_creer_les_pnj` et de `rebuild_arena` pour 8.9 (`Time.get_ticks_usec()`), ou le profileur Godot sur `aventure_poser_la_salle`.

### BOT-05 — Fonctions pures de navigation recalculées dans les chemins fréquents

- **Où** : `bot_input_provider.gd:852-857` (appel par pas), `:389-390` ; `navigation_bot.gd:227-244` (`case_praticable_proche`), `:119-124` (`cases_dans`) ; `bot_input_provider.gd:396-398, 434-447, 477-495` (`_decider`, `prochaine_cible`).
- **Constat** :
  ```gdscript
  # bot_input_provider.gd:855-856 — à CHAQUE pas en ENQUETE / RECHERCHE (avancer, :389-390), même si la mémoire n'a pas bougé
  var maintenant := perception.maintenant()
  var but := navigation.case_praticable_proche(Navigation.case_du_monde(perception.memoire.position))
  # navigation_bot.gd:233-241 — anneaux de plus en plus grands, (2r+1)² itérations chacun, 3 appels natifs par itération
  for r in range(1, rayon_max + 1):
  	for dy in range(-r, r + 1):
  		for dx in range(-r, r + 1):
  			if maxi(absi(dx), absi(dy)) != r:
  				continue
  # navigation_bot.gd:119-124 — TOUTES les cases praticables de la carte, à chaque tirage de cible d'un PNJ ZONE
  for c in _cases:
  	if rect.has_point(c):
  ```
  Et `_decider` n'a **aucune temporisation après un échec** : si aucun des 8 tirages ne donne de chemin, `_chemin` reste vide et `avancer` rappelle `_decider` (deux tours par pas, `:396`) : **jusqu'à 16 `prochaine_cible` par pas**, soit 16 `cases_dans` en ZONE.
- **Coût** : PROUVÉ — la trace de mémoire d'un *son* a un centre décalé jusqu'à 0,8 × le rayon de la zone, sans bornage à la carte (`perception_bot.gd:554-555`) : il peut tomber dans un mur, un vide, ou hors de la grille. Sur une case non praticable, `case_praticable_proche` cherche jusqu'à la première
  case praticable : ESTIMÉ ≈ 10–20 µs pour r = 2, ≈ 1,6 ms pour r = 14 (4 500 itérations), ≈ 5 ms pour r = 22, **à chaque pas** tant que la trace dure (`delai_oubli` 6 s, 12 s pour un traqueur). `cases_dans` : ESTIMÉ ≈ 2 ms par tirage sur ~7 000 cases (8.9), 0,1 ms sur une salle de 400 cases.
  L'état d'échec permanent est latent : les gardes de contenu des chapitres (`test_chapitre_03`…) vérifient que chaque zone a « assez de cases pour errer », pas leur connexité ; le validateur n'en dit rien.
- **Proposition** : (a) mémoïser `but` tant que `memoire.position` ne change pas (la position n'est réécrite que par `noter_vue`/`noter_son`) ; (b) dans `case_praticable_proche`, ne parcourir que les **8 r cases de l'anneau** (pour chaque `dy`, tous les `dx` si |dy| = r, sinon seulement ±r, dans le même ordre) — sous-suite exacte
  de l'ordre actuel, donc même case choisie à égalité (`<` strict, première trouvée) ; (c) mémoïser `cases_dans(rect)` dans un Dictionnaire par `Rect2i` (comme `_astar_par_zone`), même tableau, même ordre ; (d) *non exact* : temporiser un `_decider` en échec (changerait les tirages de `_rng` dans les rares
  cas d'échec transitoire ; à ne faire qu'avec recalibrage).
- **Gain attendu** : (a)+(b) suppriment un coût latent de 1,6–5 ms par pas par PNJ concerné ; (c) 2 ms → ~0 par tirage en 8.9, et rend sans objet le multiplicateur ×16 de l'état d'échec.
- **Risque** : (a)(b)(c) exacts, aucune consommation de RNG (`_rng` n'est tiré qu'après, dans `_tirer`, sur le même tableau). `cases_dans` rendrait un tableau *partagé* : `_tirer` ne le modifie pas (vérifié, `:499-508`). (d) hors exactitude.
- **Effort** : S.
- **Sévérité** : MINEUR (latent).
- **Statut ROADMAP** : NOUVEAU (« ZONE enferme les chemins… mise en cache », l.31894, ne parle que des grilles d'A*).
- **Comment le vérifier** : `test_bot_navigation` (même graine → même suite de 60 cibles, `:497-514` ; ZONE ne sort jamais du rectangle), `test_chapitres_marche*` (salles de ronde et de zone au vrai corps), `test_bot_perception` ; mesure : chronomètre autour des deux fonctions avec une trace de son placée hors carte.

### BOT-06 — Tris GDScript inutiles ou surdimensionnés dans `NavigationBot`

- **Où** : `navigation_bot.gd:188-208` (`_numeroter_les_composantes`), `:251-268` (`case_loin_de`).
- **Constat** :
  ```gdscript
  # navigation_bot.gd:204-207 — les cases sont déjà parcourues dans l'ordre de lecture (_cases), le remplissage les en fait sortir, puis on les remet
  membres.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
  	return a.y < b.y or (a.y == b.y and a.x < b.x))
  # :256-267 — un Array [d², case] par case atteignable, trié en entier pour n'en garder que les 15 % les plus loin
  classees.sort_custom(func(a: Array, b: Array) -> bool: ...)
  ```
- **Coût** : ESTIMÉ — le tri de composante : ≈ 45 ms pour une composante de ~7 000 cases (8.9), une fois par `NavigationBot`, au premier `cases_atteignables` : sous le carton pour un PNJ LIBRE (premier `_decider`), mais **en plein combat** quand ce premier appel est un repli (`case_de_repli`,
  BOT-03) ; ≈ 4 ms sur une salle de 700 cases. `case_loin_de` : à chaque (ré)apparition du bot **et du joueur** à l'entraînement (`game_state.gd:1105, 1166`) ≈ 6 ms pour 700 cases, ≈ 190 ms pour 16 000 cases (carte joueur 128×128) :
  un pic de plusieurs images au moment de la réapparition.
- **Proposition** : (a) *composantes* : après le remplissage (qui ne sert qu'à numéroter), reconstruire `_composantes` en parcourant `_cases` **déjà en ordre de lecture** et en ajoutant chaque case à la liste de `_composante_de[c]` — mêmes tableaux, même numérotation (par première case en ordre de lecture), zéro tri.
  (b) *case_loin_de* : même ordre total (distance décroissante, puis y, puis x) en ne triant que les `n` candidates : calculer les d² dans un `PackedFloat64Array`, trouver le n-ième par le tri natif des flottants, ne garder que les cases au-dessus du seuil (et, à égalité de seuil, les premières en ordre de lecture), trier ces `n` seulement.
- **Gain attendu** : (a) −45 ms une fois (8.9) ; (b) ×5 à ×6 sur les grosses cartes joueur, pas d'allocation de 16 000 petits tableaux.
- **Risque** : exact si l'ordre des listes et le départage sont préservés (le tri actuel est un ordre total, ce qui rend le résultat indépendant de l'instabilité de `sort_custom`) ; `rng.randi_range(0, n - 1)` doit rester le seul tirage de `case_loin_de`. `cases_atteignables` rend la liste interne : ne rien muter.
- **Effort** : S (a) · S–M (b).
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU (l.32162 ne décrit que le comportement de `case_loin_de`).
- **Comment le vérifier** : `test_bot_navigation` (même graine, composantes, ordre de lecture), `test_aventure_format` (rondes atteignables), `test_entrainement_bot` (réapparition « loin du joueur ») ; comparaison élément à élément des listes avant/après sur les 6 cartes livrées + les 100 salles.

### BOT-07 — Murs bas : forme de lumière refaite à chaque ligne de vue, sans pré-filtre

- **Où** : `perception_bot.gd:280-286` (`ligne_de_vue`), `:292-301` (`ligne_de_la_lumiere`), `murs_bas.gd:143-147` (`forme_de_lumiere`), `:160-163` (`franchit_regle`), `:223-237` (`franchit`).
- **Constat** : quand la carte porte des murets, **chaque** `ligne_de_vue` reconstruit le tableau des rectangles rentrés de 3 px (`r.grow(-RETRAIT_LUMIERE)` pour chacun) puis teste le segment contre **tous** les murets (`sortie_du_rect`, deux axes, sans boîte englobante).
  ```gdscript
  # murs_bas.gd:160-163
  return franchit(source, cible, h_source, h_cible, forme_de_lumiere(murs_bas), hauteur_mur(), ANGLE_FRANCHISSEMENT)
  ```
- **Coût** : PROUVÉ — sur les 100 salles livrées, **82 n'ont aucun mur bas** (retour anticipé, `perception_bot.gd:284-285`) et les six cartes de duel non plus ; les plus chargées : **ch.7 salle 8 (44 rectangles, 3 PNJ)** et **ch.9 salle 7 (37, 2 PNJ)**, les autres ≤ 10. ESTIMÉ ≈ 50–100 µs par `ligne_de_vue` dans ces deux salles ; jusqu'à une
  dizaine d'appels par pas quand la cible est dans le cadre et éclairée (cône : 1 + 6 points du corps).
- **Proposition** : calculer la forme rentrée **une fois** dans `monde_de_la_carte` (clé `murs_bas_lumiere`, avec repli sur le calcul actuel si la clé manque, par précaution : aucun banc ni test n'en fabrique à la main aujourd'hui), et appeler `Murs.franchit(...)` directement avec les mêmes constantes (`hauteur_mur()`, `ANGLE_FRANCHISSEMENT`) — arithmétique identique.
  Option : pré-filtre par boîte englobante du segment.
- **Gain attendu** : −30 à −50 % de ces appels dans 2 salles sur 100 ; nul ailleurs.
- **Risque** : exact (mêmes opérations dans le même ordre). Aucun test n'écrit `monde["murs_bas"]` à la main (grep : lecture seule, `test_bot_perception.gd:254`).
- **Effort** : S.
- **Sévérité** : MINEUR (2 salles).
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : `test_bot_perception` (murs bas), `test_plafonniers` (`plafonnier_bas`), `banc_perception_bot.tscn` (fenêtre) ; mesure : salle 7.8, un PNJ qui voit, cible éclairée dans le cadre.

### BOT-08 — Chaîne d'équipement : lookups dynamiques répétés à chaque pas

- **Où** : `bot_input_provider.gd:886-939, 944-958, 963-996` ; `equipement_bot.gd:342-359` ; `game_state.gd:3049-3065, 3335-3343, 3618-3624`. Plus, par événement sonore : `perception_bot_noeud.gd:129-140`, `perception_bot.gd:533-564`.
- **Constat** : pour un PNJ équipé (tous le sont avec `utilise_le_gadget`), chaque pas refait : `Equip.jeu_du(corps)` (`get_first_node_in_group("game_state")` + 2 `has_method`), `has_method`/`call("slot_de_reserve")`, `Equip.slug_du_gadget` (4 accès dynamiques) et `jeu.call("gadget_basculable_de", pid)` (une boucle sur le groupe `gadgets`, même en patrouille) ;
  en alerte, un `situation` de 14 clés, un parcours de grille (`segment_degage`) et `jeu.call("fusee_disponible", pid)` même quand le profil ne lance pas de fusée (`:955`, la garde `lance_des_fusees` n'est testée qu'après dans `fusee_voulue`). Côté oreille : `_sur_un_son` fabrique `_bot()` avant que `ecouter` ne rejette un son de PNJ ou hors portée,
  et `ecouter` fait ses 3 parcours d'occultation avant que `percevoir` ne rejette un son inaudible alors que le meilleur cas (occultation nulle) se calcule d'abord.
- **Coût** : ESTIMÉ ≈ 6 à 16 µs par PNJ équipé et par pas (≈ 30–80 µs par pas pour 5 équipés) ; côté sons, quelques dizaines d'événements par seconde × 7 : négligeable.
- **Proposition** : garder `jeu` dans le fournisseur (`Equip.jeu_du` une fois, revalidé par `is_instance_valid` — **la recherche de nœud reste dans `equipement_bot.gd`**, le texte de `bot_input_provider.gd` ne doit contenir ni `get_tree()` ni `get_first_node_in_group` : garde de `test_bot_combat.gd:421`) ; ne demander `gadget_basculable_de` que si ce PNJ a un gadget posé
  (`gadgets_poses`/le compteur du jeu) ; ne lire `fusee_disponible` que si `profil.lance_des_fusees` ; rejeter tôt dans `ecouter`.
- **Gain attendu** : ≈ −5 à −10 µs par PNJ équipé et par pas.
- **Risque** : exact si les réponses mises en cache ne changent qu'à événement ; **chemin couvert par aucune empreinte** (voir §5) ; la garde de texte de `test_bot_combat.gd:411-432` interdit certaines écritures dans `bot_input_provider.gd`.
- **Effort** : S.
- **Sévérité** : ANECDOTIQUE.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : `test_bot_equipement` (dix gadgets posés dans leur mise en scène), `test_aventure_boss` ; nouvelles empreintes de profils équipés avant/après.

### BOT-09 — Le carton de salle est montré *après* la construction de la salle, pas pendant

- **Où** : `aventure_partie.gd:154-172` (`_poser_la_salle`), appelée par `demarrer` (`:131`), `_salle_suivante` (`:333`) et `recommencer_la_salle` (`:320`) ; doc de `aventure_carton.gd:6-7`.
- **Constat** : la doc du carton dit qu'il « couvre l'écran pendant que la salle suivante se construit derrière lui ». Or `_poser_la_salle` fait **tout, de façon synchrone, dans la même image** (arène, plafonniers, navigation, PNJ, HUD) et n'appelle `_carton.montrer(...)` qu'à la fin (`:168`) : le joueur voit donc **la dernière image
  figée** (menu, dernière salle, vue de sa mort) pendant toute la construction, puis le carton. Les accrocs d'après (compilation de shader, première grille de zone, premier échantillonnage de cookie) sont, eux, bien absorbés par les 2,4 s de carton opaque.
- **Coût** : la durée de la construction n'est pas connue (aucun chronomètre dans le dépôt, ROADMAP l.33729) ; ESTIMÉ de quelques dizaines de ms pour une salle typique à plusieurs centaines pour 8.9 (BOT-04 y contribue pour ~160 ms ; l'arène et les `Player` n'en sont pas estimés ici). Se paie à chaque entrée et à chaque reprise après une mort. Godot rattrape ensuite jusqu'à 8 pas de physique dans l'image suivante (sans effet : tout est figé par le carton).
- **Proposition** : montrer le carton **un pas avant** de construire : dans `_salle_suivante` et `recommencer_la_salle`, appeler `_carton.montrer(...)` avec le titre du niveau *suivant* (déjà connu dans `chapitre["niveaux"]`), poser `jeu.countdown_left` positif, passer à une phase d'un pas (`CONSTRUCTION`), et ne construire qu'au `_physics_process` suivant.
  Garder `demarrer` et l'appel public `recommencer_la_salle()` synchrones pour les suites (qui attendent une salle prête au retour).
- **Gain attendu** : le gel de construction passe sous un fond noir au lieu d'une image figée ; ne raccourcit rien, mais masque *toute* la construction (arène comprise, hors de mon périmètre).
- **Risque** : gameplay nul ; ne pas laisser un pas de jeu s'écouler entre le carton et la construction (`countdown_left` doit figer joueur et PNJ) ; `test_aventure_partie` suppose une salle prête après `demarrer`.
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : `test_aventure_partie` ; à l'œil, une capture vidéo d'une reprise après mort ; chronomètre autour de `_poser_la_salle`.

### BOT-10 — Cookie de torche jamais préchauffé : premier échantillonnage CPU en pleine partie (domaine éblouissement, vu du bot)

- **Où** : `weapon_data.gd:288-299` (`image_torche`), `:322-323` (`lumiere_recue`) ; consommateurs : `perception_bot.gd:382-386` (cône du bot), `game_state.gd:2707` (éblouissement).
- **Constat** : `image_torche()` ne charge l'`Image` CPU qu'à la première demande (`tex.get_image()`, éventuellement `decompress()`), sur un cookie de **1 024 × 1 024** (importé sans compression, `compress/mode=0`). Aucun appelant ne la préchauffe (grep : seul `weapon_data.gd` la nomme).
  Pour le bot, la première fois est le premier pas où un PNJ dont la torche brûle (guetteur dès le départ, ou fouille) a la cible dans son cadre et en ligne de vue ; pour le joueur, le premier allumage de sa torche face à un PNJ (`_lumiere_recue` dans `_maj_eblouissement`). Une fois par classe d'arme (les `WeaponData` sont partagées).
- **Coût** : ESTIMÉ quelques ms (relecture d'une texture de 4 Mo ; en `gl_compatibility` elle passe très probablement par une lecture GPU, à confirmer), **une fois par classe**, à un moment décisif (la première torche allumée, le premier PNJ qui vous éclaire) ; non mesuré.
- **Proposition** : appeler `image_torche()` pour les classes présentes à la pose de la salle (`aventure_poser_la_salle`, sous le carton) ou au chargement de la partie ; le carton de BOT-09 couvre cet instant.
- **Gain attendu** : supprime un hoquet unique par classe, sur la seule action que l'initiation enseigne en premier (« torche_allumer »).
- **Risque** : nul (état purement lu). À coordonner avec l'agent éblouissement : même défaut pour les duels.
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : profileur / chronomètre autour de `image_torche()` au premier allumage, en fenêtre.

### Examinés sans constat

`serie_de_session.gd` (arithmétique pure, une fois par match), `aventure_progression.gd` (deux écritures de `user://solo.cfg` par salle gagnée, < 2 Ko ; `niveaux_reussis()` alloue et trie à chaque appel mais ne sert qu'à l'interface), `memoire_bot.gd` (O(1)), `profil_bot.gd` (données ;
`pnj_nomme` ne tourne qu'à la validation et à la création), `aventure_carton.gd` (nœuds construits une fois par partie, invisible hors affichage), `aventure_hud.gd` (`suivre` : O(N) par pas, négligeable). Aucun appel réseau, aucun RPC dans le périmètre (`protocol.gd` intact). **GPU** : rien ne se dessine dans le périmètre hors du drapeau `--perception-bot` (`_draw` gardé par `debogage`, `perception_bot_noeud.gd:363-365`) ; le carton est un `CanvasLayer` opaque plein écran pendant 2,4 s (1,4 s et 3,4 s aux fins de salle et de chapitre) au-dessus d'un monde qui continue de se rendre : voulu, il absorbe les premières images (shaders, premières grilles), sans effet de jeu.

---

## 5. Garde-fous du déterminisme (question 5)

**Ce qui protège aujourd'hui.**
- `tools/test_bot_equipement.gd:46-65` — `EMPREINTES` : md5 du **flux de commandes** (mouvement, visée, gâchette, recharge, torche, fusée, gadget, posture) sur **840 pas** d'une mise en scène fixe (`tools/flux_commandes_bot.gd`), pour 18 couples (profil, graine), relevées sur le code de S4.
- `tools/test_banc_bot.gd:353-384` — même graine, même duel : même issue et même instant, même graine de gadget, **même trace de 21 relevés**, avec un duel intermédiaire ; plus l'ordre statistique FACILE > NORMAL > DIFFICILE sur les graines 401-416 (384 duels par ligne, 78 / 53 / 32 %).
- `tools/test_bot_navigation.gd:497-514` — même graine, même suite de 60 cibles.
- `tools/test_bot_combat.gd:411-432, 1008-1009` — **gardes de texte** sur `bot_input_provider.gd` : pas de `get_nodes_in_group`, `get_first_node_in_group`, `get_tree()`, `"players"`, `find_child`, `get_node(`, `get_node_or_null(` dans le code ; toute `global_position` lue est celle de `corps` ;
  `avancer()` ne contient pas le mot « perception ». Toute optimisation qui a besoin d'un nœud passe donc par `equipement_bot.gd` ou `perception_bot_noeud.gd`.

**Ce qui ne protège PAS.**
- **Les empreintes sont blanches sur S9–S11** : `Flux.sans_equipement` (`flux_commandes_bot.gd:205-222`) éteint torche tactique, fusée, gadget, repli, accroupi, mise en joue, dispersion de rafale, fouille et rafales tirées au sort. `_equiper`, `case_de_repli`, `_fouiller`, `_gerer_la_peur`, les tempéraments et la mise en joue
  n'ont **aucune** référence bit à bit. **Avant de toucher à l'un d'eux** : relever, sur `52a29c1`, des empreintes de profils équipés et à tempérament (`-- --empreintes` existe, `test_bot_equipement.gd:88-89, 152-165`) et les ajouter à `EMPREINTES`.
- **L'égalité un à un de deux lots de duels est fragile** : ~4 % des duels dépendent de ce qui a été joué avant dans le processus (ROADMAP l.3431-3440) ; deux découpages `--part` ne rendent pas les mêmes duels un à un. À 16 graines, l'écart-type de « FACILE moins NORMAL » est ~17 points (`test_banc_bot.gd:335-343`) : la matrice
  statistique ne peut pas prouver l'exactitude, seulement détecter une dérive de calibration (il faut ≥ 384 duels par ligne : ~5 min sur 4 processus, ROADMAP l.32254).

**Ce qui menacerait le déterminisme** (par ordre de probabilité d'être commis par inadvertance) :
1. **Changer le nombre ou l'ordre des tirages** d'un des sept générateurs : `_rng` (cibles), `_rng_reflexes`, `_rng_rafale`, `_rng_equipement` (`bot_input_provider.gd:122-126, 236, 247-255`), `PerceptionBotNoeud._rng` (2 tirages par son entendu), `rng` de `case_loin_de`, `_rng` d'`AventurePartie` (`_creer_les_pnj`).
   Mémoïser une fonction pure (BOT-05, 06) ne tire pas ; réduire `_tirer` (8 essais) ou `ESSAIS_REPLI` en change.
2. **L'ordre des nœuds** : Player (parent) → `BotInputProvider` → `PerceptionBotNoeud` (enfant du fournisseur). La perception calculée au pas k est lue par le bot au pas k+1, et le corps lit sa commande avant que son bot ne pense (ROADMAP l.33813-33816, `flux_commandes_bot.gd` : « le corps (parent) lit les commandes, puis son fournisseur (enfant) décide pour l'image suivante »).
   Fusionner la perception dans `_penser`, changer `process_priority`, ou reparenter retire ou ajoute un pas de latence à **tous** les délais.
3. **La cadence de la perception** : une perception à 30 Hz ou ralentie pour les PNJ lointains n'est pas exacte ; la ROADMAP exige de rejouer la matrice après toute retouche de perception (l.3324-3330 : 79/55/34 → 66/61/36 pour un correctif en apparence anodin). Et le **joueur type du banc est le même `BotInputProvider` avec le même nœud de perception** (l.32257) : changer l'un change l'étalon.
4. **L'arithmétique** : remplacer `distance_to` par des carrés, précalculer des cos/sin, réordonner des opérations sur `Vector2` (simple précision) peut basculer un seuil à l'ulp (`<= RAYON_ARRIVEE`, `>= SEUIL_CONE`, bords du cadre, égalités du parcours de grille) ; des écarts de 0,02 px « d'origine non trouvée » ont déjà été payés (l.3405, 3429).
   Préférer sauter, partager et mémoïser à réécrire.
5. **L'A\*** : tout remplacement (`NavigationServer2D`), changement d'heuristique OCTILE, du mode diagonal, du poids 1,6, lissage de chemin ou cache de chemins entre cases voisines change les trajectoires, donc tout. Idem le rayon d'arrivée (12 px), les fenêtres d'anti-blocage.
6. **L'ordre des collections** : `_cases` et `_composantes` en ordre de lecture ; `case_loin_de` : ordre total (distance décroissante, y, x) ; `get_nodes_in_group` rend l'ordre de l'arbre, et la **première** lampe ou éclair vu donne `res["position"]` (`perception_bot.gd:489`) : garder l'ordre des lumières.
7. **Le temps** : `_t += delta` (double) dans `PerceptionBotNoeud` ; ne le remplacer ni par un compteur d'images ni par une horloge murale (`Time.get_ticks_msec()` est faux en simulation accélérée, ROADMAP l.3393-3395). Ne pas arrêter la perception pendant le carton sans mesurer : `_t` serait décalé de 144 pas (sans effet sur les latchs, qui sont remis à ±INF par `reinitialiser()`, mais les sommes en double changeraient d'arrondi).
8. **Le `randi()` global** : `MapCodec.generate_id()` le tire à la validation de chaque carte sans `id` (BOT-01) ; un fil concurrent serait une course. Le banc reseede le global à chaque image (l.3408-3426), donc rien d'autre n'en dépend, mais la graine de gadget (`GameState._poser_gadget`) en dépend en jeu.
9. **Du multithreading de la perception** : le travail d'un PNJ (quelques dizaines de µs) est du même ordre que l'envoi d'une tâche ; gain nul, risque d'ordre d'application. **Non recommandé.**
10. **Endormir les PNJ lointains** change le jeu (leurs pas s'entendent, leur ronde se voit) et la remise à zéro au réveil : décision d'Adrien, pas une optimisation.

**Menaces venues d'ailleurs, à garder en tête** : (a) le chantier OMBRES, question Q81 (« le brouillage n'efface-t-il que le corps qui éblouit… »), changerait `Brouillage.opacite`, que `PerceptionBot.corps_distinct` lit (`perception_bot.gd:147-148`) : la ROADMAP prévient que la matrice de difficulté (78 / 52 / 34) et les boss se rejouent alors (`ROADMAP_branche_OMBRES.md`, Q81) — c'est le risque le plus réel pour les cibles 80/55/30 ; (b) l'énergie de la torche, que `_lampe_brule` compare à un seuil (`perception_bot_noeud.gd:277`), vient d'un `randf_range` sur le générateur **global** pendant le recul (`player.gd:1977-1978`, relevé par l'audit des lumières) : sans effet tant que l'énergie reste > 1,0, mais le banc doit continuer de reseeder le global par image ; (c) toute modification de `Player` (vitesse, collision, `move_and_slide`) déplace les trajectoires, donc la matrice.

**Protocole conseillé pour toute optimisation du bot** : (1) relever les empreintes manquantes sur le commit de départ ; (2) lot de référence `banc_bot_difficulte.gd --duels=4 --trace --brut=avant.json` (mêmes `--cartes` — `--liste` donne les ids —, `--part`, `--classe`), puis `apres.json`, diff des traces et des `graine_gadget_bot` ;
(3) `./tools/run_suites.sh` ; (4) la matrice complète (≥ 384 duels par ligne) seulement si la perception ou les réflexes changent.

**« Pièges connus » relus pour cet audit, et ce qu'ils imposent aux propositions ci-dessus** : (1) l.3344-3347 — `get()` rend `null` sur une propriété absente et `bool(null)` lève une erreur : la sortie anticipée de BOT-02 doit lire la lampe de l'adversaire avec les mêmes gardes que `_lampe_brule` ; (2) l.3459-3463 — `has_method()` est vrai du socle de tous les gadgets : aucun branchement nouveau ne doit s'appuyer sur lui, et `CLAUDE.md` interdit les gardes `has_method()` qui transforment une fonction absente en inaction muette ; (3) l.3471-3478 — un corps libéré reste dans le groupe `players` jusqu'à la fin de l'image : tout cliché de l'adversaire se revalide (`is_instance_valid`, `visible`, `dead`) à chaque pas et ne survit pas à un changement de salle ; (4) l.3299-3310 — « tout ce qui a été écrit pour J1 et J2 est à relire quand un troisième corps existe » : les PNJ partagent `player_id` 1 (et donc les sons, les couches, le slot de J2 si `slot_de_reserve` n'est pas lu) ; (5) l.3397-3446 — les trois pièges de déterminisme du banc (`randf()` global, minuteurs de douille, ~4 % d'issues dépendantes de l'ordre) sont ceux du §5 ; (6) l.4079 — le parcours de grille case par case est décidé : aucune proposition ne le touche.

---

## 6. Ce qui est déjà bien fait

1. **La vue par le calcul, sans physique ni GPU** : fonctions pures, parcours de grille exact, aucun `intersect_ray` ; testable sans fenêtre, et qui « ne se trompe que dans le sens du noir » (`perception_bot.gd:4-30`). C'est la bonne réponse au 1 % bas (ROADMAP l.31707-31715).
2. **Rien ne s'exécute pour rien** : un profil sans `voit`/`entend` ne monte aucun nœud de perception (`bot_input_provider.gd:321-322`), `agit` faux saute `_penser` (`:357`), un PNJ immobile sourd sort d'`avancer` à la première ligne, un corps mort sort des deux `_physics_process`. Les 21 PNJ sourds et aveugles ne coûtent presque rien.
3. **Le temps est celui de la physique** : un seul `_physics_process` par bot, par perception et par partie ; aucun `_process`, `Timer`, `create_tween`, `print`, `instantiate` dans le chemin chaud. La cadence déplafonnée ne multiplie rien dans le bot.
4. **La navigation est native, bâtie une fois, et replanifie sur événement** : `AStarGrid2D` ; cibles, blocage, mémoire déplacée de ≥ 2 cases, but injoignable temporisé (`DELAI_REPLANIFICATION`) ; composantes connexes mises en cache ; grille de zone mise en cache par rectangle ; tout en ordre de lecture pour que la graine suffise.
5. **Des générateurs séparés par préoccupation et semés d'une seule graine** (`bot_input_provider.gd:247-255`) : monter la perception, l'équipement, les rafales ou la fouille n'a changé aucune cible du déplacement — c'est la raison pour laquelle les empreintes de S4 tiennent. Les gardes de texte et de sabotage sont nombreuses.
6. **Pas de croissance sans borne** (Q4), nettoyage immédiat des PNJ (`remove_child` avant `queue_free`, piège payé « un corps libéré reste dans le groupe `players` », ROADMAP l.3471), désabonnement du signal de son dans `_exit_tree`.
7. **Le son ne s'annonce que s'il y a un écouteur** (`audio_manager.gd:1732`), et les PNJ se rejettent entre eux au premier test (`emetteur` identique) ; les tirs de PNJ sont audibles de partout sans occlusion coûteuse (`:1793-1794`).
8. **L'aventure écrit peu et au bon moment** : la progression n'est sauvée que sur événement (salle réussie, record battu, chapitre fini) ; le validateur est strict et mis en cache ; le carton est un `CanvasLayer` invisible hors affichage, et la salle est démontée en une fois (`demonter`). Les capteurs iso des figurants sont bornés à 1 300 px (`presentation_3d.gd:158-161`).

---

## 7. Questions ouvertes

1. **Q1 — Quelle part du coût réel d'un PNJ est dans le bot ?** Seule une mesure peut le dire. Protocole : salle 8.9 montée headless (`--fixed-fps 60`, comme `test_aventure_partie`), `TIME_PHYSICS_PROCESS` moyenné sur 600 pas avec 0, 3 puis 7 PNJ ; puis la même salle en fenêtre avec `bench_framerate`
   (il n'a **aucun** scénario d'aventure : ajouter `--aventure=<chapitre>.<salle>` — le « banc de cadence solo » est déjà inscrit à OM6, **CONNU-OUVERT, titulaire chantier OMBRES** : s'y associer plutôt que le refaire). Seuils proposés : si la différence 0 → 7 PNJ dépasse 1 ms en physique, BOT-02 passe MAJEUR.
2. **Q2 — Combien de temps dure réellement `chapitres_livres()` sur le Mac d'Adrien ?** (script de BOT-01.) Si < 300 ms, BOT-01 redescend à MINEUR et l'A* paresseux suffit.
3. **Décision d'Adrien — valider ou non les salles livrées à l'exécution d'un export** (BOT-01, option 4), ou charger chapitre par chapitre.
4. **Décision d'Adrien — endormir les PNJ qui n'ont rien perçu et sont loin du joueur ?** Gain mesurable seulement dans les grandes salles de 8.x ; mais leurs pas et leurs rondes sont de l'information de jeu (on les entend).
5. **Une perception à cadence réduite (30 Hz) pour les PNJ lointains** gagnerait ~15 µs par PNJ et par pas mais décale la latence de réaction d'un pas et oblige à rejouer la matrice 80/55/30 ; **non recommandée** tant que Q1 ne montre pas que le bot pèse.
6. **Les coûts de rendu d'un PNJ sont hors de mon périmètre et probablement dominants** : capteur 256² et corps iso (≤ 1 300 px), omni 3D et ombres des plafonniers (8 au plus), trois lumières par `Player` ; ROADMAP l.32771 et 33729 les déclarent « non mesurés ». Pour les agents rendu / iso / lumières.
7. **Cadence de `_maj_eblouissement`** : elle tourne dans `_process` (par image rendue, fps déplafonnés) avec 2 + N cibles ; à voir par l'agent éblouissement avec la salle 8.9.
8. **Le flux de commandes n'est jamais comparé sur des PNJ réels** (`FauxTireur`, pas un `Player`) : les marches au vrai corps (`test_chapitres_marche*`) bornent des seuils, elles ne comparent pas des traces. Un relevé de trace d'une salle d'aventure (positions des PNJ toutes les 6 images, comme `test_banc_bot`) manque pour garder BOT-02 à BOT-08.

---

*Annexe — reproduire les chiffres de contenu* : `cd /home/user/Candela-2D---Godot && python3 <dossier d'audit>/bot_stats.py` (décode les RLE comme `MapCodec.decode_runs`, fusionne comme `MapGeometry.merge_rects` ; imprime taille, sol, murs, murets, rectangles fusionnés, PNJ et plafonniers de chacune des 100 salles).
