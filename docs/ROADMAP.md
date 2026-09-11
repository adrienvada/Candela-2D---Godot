# Candela 2D — Feuille de route

> **Document de référence du projet.** Toute session de travail le lit avant
> d'agir et le met à jour avant de conclure. Protocole de mise à jour : voir
> [README.md](../README.md).
>
> Dernière mise à jour : 2026-09-10
>
> ⚠️ **Cette ligne disait « plus aucune session parallèle ». C'était faux, et
> ça a coûté une journée de travail en double.** Un seul arbre, oui — mais
> **quatre sessions y travaillent**, dont une qui **pousse sur `origin`** et ne
> reçoit aucun message : son seul canal est le dépôt, comme le prévoit
> [docs/JOURNAL_SESSIONS.md](JOURNAL_SESSIONS.md).
>
> **Lire ce journal AVANT d'écrire dans un fichier.** Il porte une table de
> domaines — qui tient quel fichier — et les intentions annoncées par chaque
> session. Cette ligne-ci le faisait passer pour une archive ; il ne l'est pas.
>
> Ce que l'oubli a produit le 2026-08-18 : **V6.2 implémentée deux fois**, de
> deux façons correctes, dans deux fichiers différents — le journal l'attribuait
> pourtant explicitement, et laissait V6.1 à l'autre session. Et plusieurs
> fichiers du domaine « game feel » (`player.gd`, `audio_manager.gd`,
> `game_state.gd`) modifiés par une session qui ne les tenait pas.

---

## Le jeu

Duel 1v1 en vue de dessus. Deux joueurs s'affrontent dans le noir absolu ; la
seule source d'information est la lumière — sa propre torche, qui révèle mais
trahit, le flash d'un tir, la rétrodiffusion sur un mur. **Être vu, c'est être
mort.** Chaque manche est un BO1 de 5 minutes.

Contrainte transversale : le jeu doit rester **immédiat, intuitif, addictif**
d'un côté, et **fonctionnel, léger, honnête en compétition** de l'autre. Toute
décision se juge à cette double aune.

---

## État des phases

| Phase | Objet | État |
|---|---|---|
| 1 | Local écran partagé | ✅ Terminée |
| 2 | P2P hôte-autoritaire (lobby / match / killcam) | ✅ Terminée — fusionnée dans `main` (`3dd2149`) |
| 3 | **EOS — connectivité** | ✅ **Terminée** — validée à deux machines, fusionnée dans `main` |
| 4 | Killcam | Premier jet : trame de demi-teinte à la place du grain vidéo — Adrien, le 2026-09-11 : « je ne vois pas la différence, propose un graphisme plus marqué, que tout soit dessiné ». **Lot 4 bis** : le rejeu devient une planche de reconstitution — image réduite à trois tons, CONTOURS tirés à l'encre partout où la lumière change brusquement (bord d'un faisceau, silhouette, arête), trame de points sur le ton du milieu, resserrée avec le ralenti, grain de papier fixe. Le négatif garde ses deux images, la vignette reste, les uniforms de `ui.gd` ne changent pas. | 🟡 **rendu envoyé à Adrien le 2026-09-11** — attend son verdict |
| 5 | Vignette de dégâts | Hachures rouges à 45° qui entrent par les bords à bord franc (`damage_vignette.gdshader`). **Adrien ne l'a pas vue, et c'était un DÉFAUT, pas un goût** : un `CanvasLayer` s'attache au viewport de son parent, et celui de la vignette (comme celui du flash de mort) était enfant du joueur, donc de `SubViewport1` — jamais dessiné pour J2 en écran scindé, ni pour personne en vue unique, où les sous-vues sont arrêtées et où la racine rend le duel (chantier R, 2026-08-25). **Depuis toujours, donc.** `GameState.accueillir_calque()` loge désormais ces calques dans le viewport qui rend vraiment le joueur, et les reloge à chaque accord des vues. | 🟡 **rendu envoyé à Adrien le 2026-09-11** — attend son verdict |
| 6 | Rim light | `player_rim_light.gdshader` et `ghost_unshaded.gdshader` : aplat éclairé uniformément, plus de bord quatre fois plus clair que le centre (0,4 → 4,0 et 0,1 → 4,0). Juste tant que le joueur était un disque `Polygon2D` ; depuis DA2.4 c'est un sprite peint qui porte son contour, et un dégradé radial par-dessus un dessin est un vernis. | ✅ **gardé par Adrien le 2026-09-11** |
| 7 | Onde de choc du kill | `kill_shockwave.gd` : UN anneau franc, blanc halogène, sans anticrénelage, en mélange normal et non additif, plein jusqu'à 72 % de sa vie puis effacé d'un coup — à la place du double anneau doré sur-exposé et rouge qui fondait. Un trait d'encre n'a qu'une valeur et un bord. | ✅ **gardé par Adrien le 2026-09-11** |
| 8 | Shimmer des murs | **Retiré le 2026-09-11** (`git revert`). Adrien ne voyait pas à quoi correspondait le scintillement : c'est le `sin(TIME × 4,5 Hz)` de `shimmer_murs.gdshader`, qui fait vibrer le liseré halogène sous la torche. La session « Murs avec bande LED respirante » a précisé que sa respiration est une lumière À PART (`mur_led.gd`) et ne touche pas à ce scintillement ; elle modifie en revanche `light()` du même shader (`ENERGIE_REFERENCE`, décision d'Adrien du 2026-09-10). Couper le scintillement redevient une question pour Adrien, sans dépendance : à relire dans `light()` si on y revient. | ↩︎ retiré — question ouverte |
| 9 | Éblouissement | **On garde l'éblouissement actuel** (Adrien, 2026-09-11 : « je l'aime bien »). Aucune refonte. Une seule retouche à sa demande : le curseur `eblouissement` agit de nouveau sur l'opacité du voile (voir « les quinze curseurs »). | ✅ tranché, inchangé |
| 10 | Onde de choc du pompe | **Supprimée le 2026-09-11** (Adrien : « on supprime ») : `pump_shockwave.gd`, son shader et l'appel de `game_state.gd` retirés, D5 barrée. | ✅ fait |

Ce qui reste tel quel, et pourquoi : le sol en béton grainé (MV3 nomme le béton
brut comme matière ; damier choisi par Adrien le 25 août), les empreintes, les
douilles, les chiffres de dégâts, le tampon et l'estampe de kill, le viseur, les
planches de fumée de la fusée.

**Les quinze curseurs inertes sont câblés le 2026-09-11** (Adrien : « il faut
que les quinze curseurs fonctionnent »). Un seul chemin, `EffectPolicy.curseur(id)`
— `GameSettings` avec le plancher du contexte, ou 1,0 sans réglages —, et un
lecteur par identifiant : `secousse_camera` et `recul_camera` (amplitude de la
secousse et du recul), `vignette_degats` (pic et pouls), `flash_mort` (opacité
de la case), `tremblement_interface` (fiches et cercle de recharge),
`grain_killcam` (trame, contours, papier), `eblouissement` (opacité du voile,
jamais la pénalité — décision du 2026-08-18), `silhouette_revelee` (alpha de
la silhouette au tir), `flash_de_tir` (énergie de la lumière de bouche et
l'éclat dessiné, pas la pénalité), `trait_de_balle` (lumière et aura de la
balle), `lumiere_impact` (lumière de touche), `particules_sang` (nombre de
gouttes), `eclats_impact` (nombre d'étincelles et opacité de l'éclat posé),
`traces_de_sang` (opacité des taches). **`arene_au_repos` est RETIRÉ de la
table** : il réglait `menu_arene.gd`, que le hub n'instancie plus depuis le
2026-08-27 — un curseur qui règle un composant absent est un curseur qui ment.
`tools/test_curseurs_branches.gd` exige désormais un lecteur littéral pour
chaque identifiant de la table, et rougit sinon.

**Le cookie de torche, en clair** : le faisceau de la lampe est une image
(`assets/torche/cookie_*.png`) et le modèle d'éblouissement lit l'opacité de
cette image à l'endroit où se tient la victime pour calculer sa pénalité
(« l'éblouissement LIT le faisceau », décision du 2026-08-24). Si l'image
passe en paliers d'encre, la pénalité passe en paliers avec elle : un joueur
au bord du faisceau serait aveuglé d'un coup au lieu de progressivement. C'est
donc un changement de RÈGLE de jeu déguisé en changement de rendu, et il
attend une décision ; le faisceau reste tel quel.

---

## Chantier — prêt à l'essai : ce qui précède les premiers joueurs (inscrit le 2026-09-10)

**Demande d'Adrien, 2026-09-10 : « j'arrive à un point où je sens que mon jeu
est prêt à être expérimenté. Quels sont les chantiers classiques à effectuer à
ce stade ? Je pense notamment à de l'optimisation. »** La réponse a été donnée
en session, puis inscrite ici sur son « ok ». **Rien de ce qui suit n'est
commencé** : c'est un plan à étapes numérotées, et chaque étape se lance sur
demande explicite, comme le veut le protocole. L'ordre est une recommandation de
la session, pas un arbitrage d'Adrien.

### Le constat qui décide de l'ordre

L'optimisation n'est pas le premier chantier de ce stade, pour une raison de
méthode déjà payée dans ce document : **toutes les mesures de cadence du projet
viennent d'une seule machine**, un Apple M3 (relevés R2, R4, `banc_pics`). Le
jeu y tient la barre de 60 de 1 % bas avec deux images de marge, et la cause
des pics n'est pas trouvée. Optimiser avant de savoir sur quelles machines les
testeurs joueront, c'est optimiser ce que le M3 sait mesurer. Un essai, lui,
apprend deux choses avant toute autre : si le jeu démarre chez quelqu'un
d'autre, et ce qu'il y coûte. D'où l'ordre — ce qui empêche un essai
d'apprendre (PE1), ce qui permet d'apprendre (PE2), puis seulement ce qu'on
apprend (PE3).

État vérifié dans le dépôt le 2026-09-10 :

| Point | État |
|---|---|
| Version publiée | `v0.4.2`, mise à jour en place éprouvée sur machine réelle (Phase 9) |
| Cadence, vue unique, fenêtre de développement, M3 | médiane ~120, 1 % bas **61** pour une barre à 60 (R4, relevé d'Adrien) |
| Cause des pics | non trouvée ; `banc_pics` a écarté particules, objets et nœuds ; pistes restantes : le coût de rendu par image (appels de dessin +14 à +18 % sur les images lentes), puis l'allocation |
| Parties jouées sous Windows | **aucune consignée** — un export CI et un échange de mise à jour, pas une partie. Adrien pressent pourtant que les premiers joueurs seront sous Windows (Phase 9) |
| Classes éprouvées manette en main | une sur dix (H11) ; les dix gadgets jamais utilisés en match |
| Ce qu'un match archive sur la machine | rien : ni cadence, ni GPU, ni OS — `match_record.gd` archive le résultat, pas les conditions |

### PE1 — Stabilité sur machine étrangère

Un essai qui plante n'apprend rien, et il coûte un testeur. Trois choses, dans
cet ordre :

1. **Une partie complète sous Windows sur un poste vierge**, GPU intégré, en
   `gl_compatibility`. C'est le jalon **H12** : il exige un poste que personne
   ici n'a. Ce qu'on cherche : le jeu démarre, EOS s'authentifie, un match en
   ligne se joue, la mise à jour passe.
2. **Solder les dettes réseau des « Prochaines étapes »** : checklist
   `CHECKLIST_TESTS_EN_LIGNE.md` jamais déroulée, 120 ms de latence simulée
   jamais validées, relais Epic jamais exercé, détection de déconnexion lente,
   contre-vérification à deux machines (H1), rejeu de l'appariement à deux
   machines. Aucune n'est nouvelle ; toutes deviennent bloquantes le jour où un
   inconnu joue sur un mauvais lien.
3. **macOS sans notarisation (H4)** : Gatekeeper refusera l'application à
   quiconque n'est pas Adrien. Soit payer, soit documenter le contournement pour
   les testeurs — mais le décider avant d'envoyer un lien.

### PE2 — Instrumentation de l'essai ✅ PE2.1 à PE2.4 livrés le 2026-09-10 — le déploiement de PE2.3 est le jalon H14

Le chantier le plus rentable et le plus souvent oublié : **sans lui, un testeur
qui dit « ça rame » n'a rien donné.** Aujourd'hui F3 affiche la cadence
instantanée, `user://match_history.json` archive le résultat des matchs, et rien
ne consigne les conditions.

1. **Chaque match archive ses conditions** dans `MatchRecord` : médiane, 1 % bas
   et pire image sur la durée du match — mesurés **par image**, comme le banc,
   jamais par `get_frames_per_second()` (piège connu) —, GPU, OS, résolution de
   fenêtre, RTT moyen, transport, lien direct ou relayé, version. Le relevé de
   cadence se fait alors sur les machines des testeurs, pas sur le M3.
2. **Un bouton « copier le diagnostic »**, dans le panneau F3 ou les Options, qui
   met dans le presse-papiers ce que le testeur ne saura pas décrire.
3. **Faire remonter ces lignes par Supabase**, dont l'infrastructure existe
   (Phase 4) : une table de plus, une Edge Function de plus, aucune donnée
   nominative au-delà du PUID déjà envoyé avec les matchs classés. À trancher
   par Adrien : ce qui remonte, et si les matchs amicaux remontent aussi.
   ✅ **Tranché le 2026-09-10** — voir « Décisions actées » et le lot du jour.
4. **Un journal qui survit au plantage.** Piège connu : en release, `print()`
   est tamponné et vidé à la fermeture propre seulement ; un plantage jette la
   fin du journal, c'est-à-dire la seule partie utile. Un fichier écrit en flux,
   ou vidé à chaque fin de manche.

### PE3 — Optimisation, mesurée 🟡 PE3.1 et PE3.4 livrés, PE3.5 audité le 2026-09-10 — PE3.2 et PE3.3 attendent une machine

Préalable : **définir la machine minimale** — jalon **H13**, décision d'Adrien.
Sans elle, aucune cible n'a de sens : la barre « 1 % bas ≥ 60 » (R5) ne décrit
que la machine où elle a été mesurée. Puis, par rendement décroissant :

1. **Le GPU brûle pour rien hors match.** Les menus tournent déplafonnés vers
   200 fps (relevé `--menus`), `Engine.max_fps` n'est posé que par le réglage du
   joueur, aucun `low_processor_usage_mode`, rien à la perte de focus. Sur un
   portable, c'est ce qui fait souffler les ventilateurs — la plainte numéro un
   des testeurs — et c'est peu coûteux : un plafond dans les menus et hors
   focus, jamais en match, puisque la médiane déplafonnée commande le RTT (R5).
2. **La cause des pics.** Reprendre les pistes de `banc_pics` : le coût de rendu
   par image, puis l'allocation dans `_process` et `_physics_process`. Outil :
   le profileur de l'éditeur sur un vrai match. Sur la machine minimale, pas sur
   le M3.
3. **Les textures.** 295 images importées sans perte (`compress/mode=0`) et sans
   mipmaps, des fonds d'interface de 3 Mo chacun : VRAM et temps de chargement,
   à peser avec R6 qui doublera la densité des assets. Une décision d'import,
   pas une retouche par fichier.
4. **La taille du build.** L'export n'a aucun filtre d'exclusion, et
   `tools/captures/` (10 Mo, quinze imports) part dans le paquet. Mineur, un
   filtre suffit.
5. **La chauffe des shaders.** Déjà traitée pour le joueur, le sang, la fusée et
   l'onde de choc ; vérifier qu'aucun shader ne compile encore au premier usage
   en match (`test_arena_lighting` en tient une partie).

### Le lot du 2026-09-10 — ce qui se code sans fenêtre, et ce qu'il a appris

**Demande d'Adrien : « je n'ai pas de machine Windows. Peut-on attaquer 2 et
3 ? »** Oui, pour la part qui se code sans fenêtre. La session a récupéré le
Godot 4.7.1 Linux de la CI, donc les suites headless tournent ici ; elle n'a
ni fenêtre ni GPU, donc **aucune mesure nouvelle** — tout ce qui suit est du
code vérifié par les suites, et les chiffres attendus restent des attentes.

- **PE2.1 — chaque match archive ses conditions.** `conditions_de_match.gd`,
  et `MatchRecord` passe au **schéma 5** avec la clé `conditions`. Une durée
  par image lue à l'horloge (`Time.get_ticks_usec`), jamais au delta de
  traitement — l'encaissement d'un tir ralentit `time_scale` en pleine manche
  et un relevé au delta y lirait 5 000 fps ; définitions du banc mot pour mot
  (médiane, 1 % bas = moyenne du centième le plus lent, pire image) pour qu'un
  chiffre de match se compare à un chiffre de banc sans conversion ; les
  écarts de plus de 0,5 s (pause en écran partagé, fenêtre gelée) comptés
  comme des **trous**, pas comme des saccades ; arrêté à la mort, avant la
  killcam. Le lien y est (RTT moyen et max), et la machine (OS, CPU, GPU,
  pilote, fenêtre, VRAM). Vérifié : la fumée `--local` archive un
  enregistrement v5 — 255 images, médiane 145, 1 % bas 113, machine sans GPU
  puisque headless, et c'est attendu. ⚠️ **Local seulement** : l'envoi au
  classement construit son propre corps et ne transmet rien de tout ça —
  c'est PE2.3, et il attend Adrien.
- **PE2.2 — F6 copie le diagnostic.** Presse-papiers **et**
  `user://diagnostic.txt` (un presse-papiers se perd au copier suivant), et le
  panneau F3 s'ouvre pour le dire — un geste sans retour visible passe pour un
  geste raté. ⚠️ **Pas F4, comme prévu d'abord** : F4 est la trace d'écoute
  d'`AudioManager` (`_tracer_ecoute`) et F5 l'éditeur de cartes. Un grep
  limité à trois fichiers ne l'avait pas vu ; la feuille de route, si.
- **PE2.4 — le journal survit au plantage.** `run/flush_stdout_on_print=true`
  dans `project.godot`, vérifié dans la source de Godot 4.7
  (`core/io/logger.cpp` : `RotatedFileLogger::logv` ne vide le fichier qu'en
  erreur, ou sous ce réglage). Coût nul en manche : zéro `print` dans
  `player.gd` et `bullet.gd`. `CLAUDE.md` dit désormais ce que le code fait ;
  les deux passages de ce document qui décrivent l'ancien tamponnage (Phase 3,
  piège « Un diagnostic qui ne tourne pas là où l'on joue ») portent une note
  datée plutôt qu'une réécriture.
- **PE2.3 — les conditions remontent avec le rapport.** Tranché par Adrien le
  2026-09-10, version minimale : elles voyagent avec le rapport des matchs **en
  ligne**, amicaux et classés, **tous les champs** du schéma 5, et une phrase
  d'information aux testeurs (dans `docs/SUPABASE.md`). Pas d'envoi séparé pour
  l'écran scindé ni l'entraînement : ils ne rapportent rien, et les couvrir
  demanderait un identifiant de machine anonyme — un chantier à part. Livré en
  trois pièces : la migration `20260910120000_match_conditions.sql` (colonne
  `conditions jsonb`, `report_match` avec `p_conditions` en dernier et un
  défaut, vue `conditions_de_match` qui aplatit ce qu'on lit), le tamis
  `parseConditions` dans `_shared/match_report.ts` (liste blanche clé par clé,
  **jamais un motif de refus** — un relevé mal formé ne doit pas faire perdre
  un match au classement, même arbitrage que le format inconnu ramené à BO1),
  et le corps du rapport côté jeu, rejeu du journal compris. Vérifié : 95 tests
  Deno verts, six nouveaux. ⚠️ **Rien n'est déployé** : `db push` puis
  `functions deploy report` sont le jalon **H14**, et lui seul les fait.
- **PE3.1 — un plafond hors arène.** `GameSettings.PLAFOND_MENU = 120` dans
  les menus, `PLAFOND_HORS_FOCUS = 30` quand la fenêtre a perdu le focus, et
  **jamais en arène** — `round_active or sandbox_mode`, donc l'entraînement et
  le salon d'attente restent déplafonnés, et un hôte qui passe une seconde sur
  une autre fenêtre simule toujours pour l'adversaire. Un choix du joueur plus
  bas l'emporte. Les bancs (`bench_framerate`, `banc_pics`) posent
  `pilotage_externe` pour que `--menus` mesure la charge et non le plafond.
  **Ces deux nombres sont des valeurs de départ**, pas des décisions. Attendu,
  non mesuré : les menus passent de ~200 à 120 images par seconde, ce qui se
  lit au F3 sans banc.
- **PE3.4 — `tools/*` hors de l'export.** `exclude_filter="tools/*"` sur les
  trois préréglages. Vérifié avant : aucun `res://tools/` dans le code de jeu,
  aucun `.tscn` ne pointe dedans, et les deux `class_name` du dossier
  (`PeerSpy`, `RenduCommun`) n'ont aucun usage à la racine. Gain attendu : les
  10 Mo de captures et les scripts de test ; non mesuré, l'export n'étant pas
  possible ici.
- **PE3.5 — l'audit des shaders.** Vingt-trois `.gdshader`. Vingt et un sont
  préchargés en `const` ou chargés par les menus (`intro_planches.gd`,
  `menu_hub.gd`, en `load()` hors match — hors sujet). **Deux ne sont
  référencés par aucun code de jeu** : `distorsion_eblouissement.gdshader` et
  `poussiere_faisceau.gdshader` — le `poussiere_faisceau` du code est un
  identifiant d'EFFET (`effect_policy.gd`), pas ce fichier. Signalés, pas
  supprimés : hors périmètre. **Ce que l'audit ne ferme pas** : un `preload`
  charge le shader, mais le programme GL se compile au premier DESSIN — seule
  `Fusee.prechauffer()` dessine d'avance. Une chauffe générale est un pas
  séparé, et il se juge à `banc_pics` (des pics groupés au début sont une
  compilation, des pics étalés non).

**Ce qui attend Adrien, et ne se commence pas :**

- **H14** — déployer PE2.3 : `supabase db push` puis
  `supabase functions deploy report --no-verify-jwt`, dans cet ordre, l'une
  juste après l'autre (`docs/SUPABASE.md`). Tant que ce n'est pas fait, les
  clients à jour envoient un bloc que la base ignore, sans rien perdre.
- **PE3.2** — `banc_pics` sur son Mac, fenêtre au premier plan, pour la cause
  des pics ; et désormais, gratuitement, les `conditions` de ses propres
  matchs dans `user://match_history.json` — c'est le même relevé, pris en
  jouant.
- **PE3.3** — lire `vram_mo` et `textures_mo` dans le diagnostic F6 avant toute
  décision d'import. ⚠️ **0 veut dire « non mesuré par ce pilote », jamais
  « aucune texture »** — le résumé headless le montre.
- **H13** — la machine minimale.

**Trois choses payées en route.** Deux contrôles textuels de `test_classes.gd`
épinglaient la FORME de ce lot — « le schéma est passé à 4 », et la parenthèse
fermante après `_slug_de_classe(p2)` — et ont rougi sans qu'une classe ait
bougé : le premier vérifie désormais « 4 ou plus » (l'égalité exacte vit dans
`test_rejeu_journal.gd`), le second l'appel et non sa ponctuation. C'est le
piège « un contrôle textuel épingle un identifiant, jamais un sens », payé une
fois de plus. L'import sur cette machine a généré six
`.uid` pour les vidéos `.ogv` de l'intro, absents du dépôt : la garde des
assets non suivis a rougi le lot entier (piège « Un import sur une autre
machine produit ce que la garde exige »). Et `get_video_adapter_driver_info()`
vit sur `OS`, pas sur `RenderingServer` : le script ne compilait pas, la suite
annonçait « tous les tests passent », et c'est la garde `SCRIPT ERROR` du
lanceur qui l'aurait attrapé — pas le compteur de la suite.

### PE4 — Mise en main

Aucun écran « comment jouer » trouvé dans les menus (recherche sur « comment
jouer », « tutoriel », « didacticiel » dans `ui.gd`, `menu_hub.gd`,
`hub_screen.gd`). Un duel dans le noir absolu est inhabituel, et la première
minute décide de tout : commandes affichées, entraînement mis en avant au premier
lancement, fiche de classe existante réutilisée.

### PE5 — Équilibrage et contenu

H11 reste ouvert sur neuf classes, les gadgets n'ont jamais servi en match, et
l'effet de bord Sentinelle / Incendiaire (root plus long que la cadence, signalé
à l'étape 20 des dix classes) ne se juge qu'en jouant. Avec peu de testeurs,
tout le monde démarre Aveugle I et l'appariement sera étroit : la fourchette
d'attente (étape 8.5) est à revoir pour une population de dix personnes.

### PE6 — Distribution

Windows d'abord (Phase 9), itch.io comme canal d'essai — les gabarits de capsule
DA7.1 existent —, des notes de version, et un canal de retour. Détail relevé :
l'autoload `_mcp_game_helper` du plugin éditeur `godot_ai` part dans le build
release. Il est inerte hors débogueur, mais un outil de développement n'a rien à
y faire.

### Ce qui n'a pas été vérifié

Ce plan est écrit depuis une lecture du dépôt, sans Godot ni fenêtre dans
l'environnement de la session. **Aucune mesure nouvelle n'a été prise** ; tous
les chiffres viennent des relevés déjà consignés ici. L'absence d'écran d'aide
est une absence de résultat de recherche, pas une preuve.

---

## Jalons humains — ce qui ne peut pas être automatisé

Tout le reste doit être fait par des agents. Ces points-là exigent Adrien.

| # | Jalon | Pourquoi humain | Quand |
|---|---|---|---|
| H1 | **Test à deux machines sur deux réseaux Internet distincts** | Exige un second poste et une seconde connexion. Le scénario qui compte : les deux postes en partage de connexion mobile (CGNAT des deux côtés). | ✅ Fait le 2026-08-16 — **contre-vérification à refaire** depuis les correctifs |
| H2 | Transfert manuel de `eos_credentials.gd` vers la seconde machine | Le fichier est ignoré par git : il ne voyage pas avec le clone. Clé USB ou AirDrop, jamais par mail. | Avec H1 |
| H3 | Playtest de ressenti (game feel) | Aucun agent ne peut juger si le jeu est amusant, lisible, tendu. | ✅ **Tranché le 2026-08-16 par Adrien : « le jeu est amusant »** — le classement a donc quelqu'un à classer |
| H4 | Adhésion Apple Developer + notarisation | Décision d'achat (99 $/an), puis validation sur machine vierge. | Avant une sortie publique macOS |
| H5 | Création du projet Supabase et de ses clés | Compte à créer, région à choisir, décisions de coût. | ✅ Fait le 2026-08-16 |
| H6 | Déploiement du schéma et des Edge Functions | `supabase login` ouvre un navigateur et `supabase link` demande le mot de passe de la base. Une fois ces deux-là passés, le reste s'enchaîne sans intervention. | ✅ Fait le 2026-08-16 |
| H7 | Parcours du profil à la souris | Mise en page et presse-papiers réel, qu'aucun test headless ne rend. | ✅ Fait le 2026-08-16 |
| H8 | **Paire de clés de mise à jour** | ✅ **Fait — les deux moitiés.** Clé publique en place le 2026-08-26 (`0af06e1`, `update_manager.gd`, relue par `openssl`, chargée par `Crypto` de Godot) ; secret GitHub `CANDELA_MAJ_CLE_PRIVEE` créé le 2026-08-25. Le workflow `Publication` a déjà tourné une fois de bout en bout ce jour-là sur un tag posé trop tôt (commit sans la clé) — la Release qui en est sortie est un brouillon orphelin, encore à supprimer avant H9. Détail dans « Ce qui reste ». | Avant toute publication |
| H9 | **Première publication, et première mise à jour réelle** | ✅ **Fait.** Trois Releases publiées (`v0.1.0`, `v0.2.0`, `v0.2.1`, vérifié `gh release list`, plus de brouillon orphelin). Adrien a testé l'échange sur une machine réelle (Antigravity) et l'a vu réussir. **`v0.3.0` publiée le 2026-09-09** (`gh run list --workflow=release.yml`, succès) — mineure montée car `Protocol.VERSION` était passé de 8 à 9 depuis `v0.2.11` sans que la mineure suive ; `tools/verifier_publication.sh` l'a signalé avant le tag. Changelog complet dans les notes de la release. **`v0.3.1` publiée le 2026-09-09** (correctif de dosage des taches de sang, `POIDS_TAILLE` — voir DA2.8 suite 2 ; protocole inchangé, `verifier_publication.sh` a confirmé un simple correctif). **`v0.4.0` publiée le 2026-09-09** (`gh release view v0.4.0`, workflow `Publication` succès en 8 min, `main` à `2255537`, macOS 157 Mo / Windows 103 Mo) — mineure montée pour deux raisons combinées : le correctif d'appariement classé (`rpc_countdown_launch`, `Protocol.VERSION` 9→10) et le chantier des dix classes asymétriques (`Protocol.VERSION` 10→15 après renumérotation à la fusion — voir le carnet de `protocol.gd`). Adrien a éprouvé l'arbalète manette en main avant d'ordonner la fusion, puis la publication. **`v0.4.1` publiée le 2026-09-09** — corrective et non mineure : `Protocol.VERSION` reste à 15, `verifier_publication.sh` l'a confirmé avant le tag. Elle porte le réglage d'après-partie d'Adrien (étape 20 du chantier DIX CLASSES) : le root enfin senti, les quatre gestes de combat sur L2/L1/R2/R1, la grille de munitions et de cadences arbitrée, et la recharge cartouche par cartouche du Terrassier. ⚠️ **Publiée en connaissance d'un manque** : six classes sur dix n'ont pas de planche de marche et glissent avec leur sprite statique — Adrien a tranché « publier maintenant » plutôt que d'attendre les 48 images. **`v0.4.2` publiée le 2026-09-09** — corrective, `Protocol.VERSION` toujours à 15. Elle porte deux choses : les **planches de marche de cinq des six classes neuves** (étape 21 ; le Spectre glisse, décision d'Adrien) et surtout le correctif des **seize silhouettes noires** — l'adversaire s'effaçait en marchant, dans toutes les versions publiées jusqu'à la 0.4.1 incluse. **`v0.5.0` publiée le 2026-09-10** — mineure : `Protocol.VERSION` 15 → 16 (tir semi-automatique, index des dix classes sur le fil, état et destruction des gadgets portés par l'hôte), `verifier_publication.sh` l'a confirmé avant le tag. Elle porte le chantier DIX CLASSES des étapes 22 à 26 — le choix de classe revenu dans le salon, l'entraînement qui joue la classe choisie et compte ses fusées, un appui un tir (l'Occulteur seul en rafale), une minute de recharge et un gadget debout par joueur, le grésillement en batterie qui éteint les torches, le voile qu'on ne traverse plus, les images des gadgets et la poudre aux traces lisibles, les touches Y et N de J2 au clavier — ; les finitions des menus (titres re-détourés, menu muet sous l'allumage, fiche de classe refaite, icônes d'armes en couleur, verrou de torche en cadenas) ; l'intro en vidéo (DA6.6) ; les conditions de match archivées et F6 (PE2, PE3) ; et le correctif de la gâchette R2, qui avait manqué la 0.4.1 et la 0.4.2. | ✅ **Fait le 2026-09-08** |
| H11 | **Éprouver les dix classes manette en main** (chantier CLASSES) | Aucune suite ne dit si un *root* est jouable, si un gadget vaut son coût, ni si une classe est simplement pénible. Les dix ont été calibrées au raisonnement et à la mesure ; rien de tout ça ne dit ce que ça fait de jouer. | 🟡 **Commencé le 2026-09-09** — Adrien a éprouvé **l'arbalète** (0,60 s de root, l'extrême haut de la grille) et ordonné la fusion. ⚠️ Il n'a demandé aucun changement de valeur **et n'a pas prononcé de verdict sur le chiffre** : ce qui est établi est que le root ne l'a pas arrêté, pas que 0,60 s soit juste. Neuf classes restent à essayer, et les dix gadgets n'ont jamais servi en match. |
| H10 | **Un relevé de cadence FENÊTRE AU PREMIER PLAN** (chantier R, étape R4) | macOS bride une fenêtre au second plan autour de **144 fps**, et une session d'agent ne peut pas se donner le focus. Tous les relevés du 2026-08-25 sont donc plafonnés : le socle nu — torches éteintes, shaders retirés, 1,03 Mpx — donne le même 144 que le duel complet à 3,69. **Le banc ne mesure pas la charge, il mesure le plafond.** La conclusion « le chantier R est gratuit » n'est PAS établie ; seul l'est le fait que les deux chemins passent le seuil de 60 avec une marge de plus du double. Une exécution au premier plan lève l'ambiguïté en trente secondes : `godot --path . res://tools/bench_framerate.tscn -- --vue-unique`, puis la même avec `--sans-racine`. Le banc dit lui-même dans quel état de focus il était. | ✅ **Fait par Adrien le 2026-08-25** — et il a renversé deux conclusions : le chantier R **gagne** 15 % de cadence au lieu de coûter, et le 1 % bas réel du jeu est de **61**, pas de 142. Détail dans R4. |
| H12 | **Une partie complète sous Windows sur un poste vierge** (chantier PRÊT À L'ESSAI, PE1) | Exige un poste Windows à GPU intégré que personne ici n'a. Ce qui compte : le jeu démarre, EOS s'authentifie, un match en ligne se joue, une mise à jour passe. La feuille de route ne consigne aucune partie jouée sous Windows — seulement un export CI et un échange de mise à jour. | Avant le premier lien envoyé à un testeur |
| H13 | **La machine minimale** (chantier PRÊT À L'ESSAI, PE3) | Une décision, pas une mesure : sans machine nommée, la barre « 1 % bas ≥ 60 » (R5) ne décrit que le M3 où elle a été mesurée. | Avant toute optimisation |
| H14 | **Déployer PE2.3** — `supabase db push` puis `supabase functions deploy report --no-verify-jwt` | `supabase login` et le mot de passe de la base n'appartiennent qu'à Adrien, comme pour H6. Deux commandes, dans cet ordre, l'une juste après l'autre : entre les deux, l'ancienne fonction appelle `report_match` sans conditions et le défaut `null` la sauve. Marche à suivre et requêtes de lecture dans `docs/SUPABASE.md`. | Avant le premier lien envoyé à un testeur, pour que ses matchs comptent dès le premier |

---

## Qui peut faire quoi — répartition du 2026-08-17

Deux colonnes, parce qu'elles ne s'attendent pas l'une l'autre : **une session
peut travailler des heures sans Adrien**, et il n'a rien à débloquer pour ça.

### Faisable sans Adrien — dans cet ordre

| # | Chantier | Pourquoi c'est autonome |
|---|---|---|
| ~~1~~ | ~~**Banc de file en scène**~~ | **FAIT** — EOS accepte le filtre entier, la conception tient. Un `.tscn` headless voit les autoloads du plugin EOS. Une seule instance suffit à répondre à la question qui bloque : EOS accepte-t-il un filtre entier avec `GreaterThanOrEqual` ? On ne cherche pas à trouver quelqu'un, on cherche à savoir si la **requête** est acceptée. |
| ~~2~~ | ~~**Écran audio**~~ · ~~**Écran de calibration**~~ | **FAITS le 2026-08-17**, branchés dans le hub. |
| ~~4~~ | ~~**Écran historique**~~ | ✅ **FAIT le 2026-08-18** — `screen_history.gd`, sa suite `test_screen_historique`, et le compte des enregistrements écartés. |
| ~~5~~ | ~~**Affichage du rang en jeu**~~ | ✅ **FAIT le 2026-08-18** — Phase 6 close : catégorie, division, points restants et échelon suivant, dans `ranked_identity.gd`. |
| ~~6~~ | ~~**Édition du pseudo**~~ (Phase 5, étape 6) | ✅ **FAIT le 2026-08-24** — écrite et testée le 2026-08-18, déployée le 2026-08-24 (`db push` + `functions deploy rename`), porte vérifiée `401` comme `link`. |
| ~~7~~ | ~~**Rejouer le journal local**~~ | ✅ **FAIT le 2026-08-18** — schéma v3, `pending_reports()` / `mark_reported()`, `replay_local_journal()`, vingt assertions. Le raccordement de `MatchRecord.build()` est fait aussi (`c064e6c`). |
| ~~7bis~~ | ~~**La poignée de main de l'étape 8.9**~~ | ✅ **FAITE le 2026-08-18** — attribut `PROTO` sur le salon à code (lu avant la jointure), numéro dans le **filtre** de la file, `rpc_hello` à signature figée pour ENet, et le silence traité comme un refus. `Protocol.VERSION` est à **2**. |
| ~~8~~ | ~~**Déblocage d'armes, côté interface**~~ | ✅ **FAIT le 2026-08-18** — Phase 7 close côté mécanique : `rank_loadout.gd`, grisage avec la raison, règle du miroir de bout en bout. Reste le **contenu** des catégories 5 à 10, qui exige Adrien. |
| 9 | **Vagues de game feel procédurales** (V3, V4, V5, V6) | **C'est le seul chantier de code encore ouvert.** Tout ce qui n'est pas marqué *assets* se fait sans rien attendre. Les vagues 3 et 6 passent par `ui.gd` : vérifier qu'aucune session ne le tient avant d'y toucher. |

### Exige Adrien — rien ne remplace sa présence

| Quoi | Pourquoi |
|---|---|
| **Les 76 assets** | Aucun agent ne produit un son. Voir l'onglet ASSETS du suivi : noms exacts, durées sur la grille à 170 BPM, intentions. **Commencer par les cinq fichiers de musique** — délai le plus long, et ils réveillent un système entier déjà câblé. |
| **Rejouer (jalon H3)** | Le seul juge du ressenti. À reprendre après chaque vague de game feel : une boucle qui ne redemande jamais dérive, elle optimise ce qu'elle sait mesurer. |
| **Appariement automatique à deux fenêtres** | **Le prochain, et le dernier inconnu de la Phase 8.** ⚠️ Première tentative du 2026-08-18 **sans `--eos-ephemeral`** : même Device ID donc même PUID des deux côtés, chaque instance écartait le ticket de l'autre comme étant le sien, et les deux ont cherché indéfiniment. Rien n'indique un défaut de l'appariement — c'est le piège du PUID partagé, déjà consigné, rencontré pour de vrai. Deux instances avec `--eos-ephemeral`, à surveiller pendant qu'elles se cherchent. La découverte est prouvée ; la jointure, la poignée de main, l'accord sur qui héberge et la connexion ne le sont pas. Protocole détaillé, sept étapes. |
| **Test à deux machines (H1)** | Une contre-vérification est due depuis les correctifs. Le test à deux fenêtres du 2026-08-18 ne le remplace pas : même machine, même réseau, donc **ni traversée de NAT ni latence réelle**. |
| ~~**Échap et F3 en jeu**~~ | ✅ **Fait le 2026-08-18** — les six gestes répondent. |
| ~~**Sens des divisions de rang**~~ | ⚠️ **Ce n'était pas une décision ouverte** — elle est prise et **déployée** depuis le 2026-08-17. `elo.ts` documente `division` comme « 1 (I, la plus basse) à 3 (III) », convention Rocket League, et `labelAt()` l'applique. Restait à le **dire** à Adrien, pas à le lui demander. La contredire coûterait un redéploiement. |
| ~~**Frottement du déblocage d'armes**~~ | ✅ **Tranché le 2026-08-18 par Adrien : descendre le plancher.** Tous les joueurs démarrent à l'échelon le plus bas (`RANK_FLOOR = START_RATING`), donc avec le seul pistolet, et les trois autres armes se gagnent. |
| **Adhésion Apple Developer (H4)** | 99 $/an, décision d'achat. |
| ~~**Déployer la fonction `rename`**~~ | ✅ **Fait le 2026-08-24** — `db push` + `functions deploy rename`, porte vérifiée `401` comme `link`. Écran câblé depuis le 18, opérationnel. |
| **Numérotation de `Protocol.VERSION`** | Tranchée (« carnet + rappel »), mais **le numéro lui-même reste à monter à la main** à chaque changement du fil. C'est le seul jugement que la mécanique ne peut pas rendre. |

---

## Prochaines étapes

> **Le banc de framerate demande DEUX relevés, pas un** (constat partagé avec la
> session des effets, 2026-08-18). Deux charges de nature différente attendent la
> même mesure : le flou défocalisé de M14 est une passe de rendu de plus par
> image **dans les menus**, les particules de la vague 5 sont **en match**. Un
> chiffre pris dans l'un ne dit rien de l'autre. Et le relevé n'a de valeur qu'au
> calme : deux sessions en parallèle, plus l'éditeur Godot ouvert, suffisent à le
> rendre ininterprétable — il faut alors le dire dans le résultat, ou fermer.
> **Le banc ouvre une fenêtre sur le poste d'Adrien : il ne se lance pas sans lui
> demander.**

> **Cap donné par Adrien le 2026-08-16 :** le jeu est amusant (H3 tranché), le
> classement est en place, et la suite est le contenu — les menus d'abord, puis
> les rangs, puis le déblocage d'armes (Phases 5 à 7).

> **Bilan du 2026-08-17.** Onze agents lancés, dix ont livré. Le onzième —
> l'écran de **calibration de luminosité** — a été tué par une limite de session
> et n'a jamais été relancé. *(Livré depuis : il est aujourd'hui un panneau de la
> rubrique Affichage, avec sa suite `test_screen_calibration`.)*
>
> **Au 2026-08-18, `run_suites.sh` en lance vingt-neuf**, toutes vertes. Les
> comptes qui figuraient ici — treize, dix-sept, vingt-trois — datent chacun d'un
> moment de cette journée-là ; c'est le lanceur qui fait foi, pas ce document.
>
> Les trois bancs d'essai réseau ne sont pas des suites et n'y figurent pas :
> `test_transport`, `test_online_match` (dont trois modes *sont* dans le lanceur)
> et `test_quit_path`. Ils demandent deux processus et une session Epic.

> **⚠️ Cette liste a menti pendant une journée.** Elle annonçait comme « seul
> blocage de la Phase 8 » l'ouverture des deux entrées « chercher un match » —
> déjà faites au moment où on la lisait ([ui.gd:1860](../ui.gd),
> [ui.gd:1916](../ui.gd) : plus de motif `NOT_YET`, action `chercher`, style de
> lanceur). Une liste de prochaines étapes périmée est **pire qu'absente** :
> elle envoie refaire ce qui est fait, et détourne du reste. Réécrite le
> 2026-08-18 en vérifiant chaque point dans le code.

**Tout le code des phases 2 à 8 est livré.** Ce qui reste se range en trois tas,
et un seul est du travail de session.

> **Ajouté le 2026-08-25 — un quatrième tas, et ce n'est pas du polish :** la
> **spatialisation du son** (section dédiée ci-dessus). Son premier item, S1,
> est un **défaut structurel** — le jeu joue des sons positionnels sans avoir
> jamais posé d'auditeur —, il vit dans `audio_manager.gd` et `game_state.gd`,
> donc dans le domaine « game feel ». Deux de ses items (S3, S7) attendent un
> arbitrage d'Adrien et **ne se commencent pas**.

> **Ajouté le 2026-09-10 — un cinquième tas, et il PRÉCÈDE l'optimisation :** le
> chantier **« prêt à l'essai »** (section dédiée ci-dessus), inscrit sur le
> « ok » d'Adrien après sa question du jour. Six étapes PE1 à PE6, **aucune
> commencée** ; l'ordre recommandé est PE1 (stabilité sur machine étrangère),
> PE2 (instrumentation de l'essai), PE3 (optimisation, mesurée sur une machine
> nommée). Deux jalons humains en découlent, H12 et H13.

### Le seul chantier de code ouvert

1. **Les vagues de game feel** (section dédiée ci-dessus). Tout ce qui n'est pas
   marqué *assets* se fait sans rien attendre de personne. Les vagues 3 et 6
   passent par `ui.gd` — vérifier qu'aucune session ne le tient. Les vagues 4 et
   5 vivent dans `player.gd`, les lumières et les particules : c'est le terrain
   libre quand `ui.gd` est pris.
2. Les **chantiers de robustesse** de l'étude du 2026-08-16 (section dédiée), à
   piocher entre deux tâches. Aucun n'est bloquant.
3. **La refonte roman graphique des effets en jeu** (section dédiée, inscrite
   le 2026-09-10) — huit lots autonomes, un commit et un rendu avant/après
   chacun ; les lots 9 et 10 attendent Adrien.

### Ce qui attend Adrien, et rien d'autre

3. **L'appariement automatique à deux fenêtres**, avec `--eos-ephemeral` des deux
   côtés — sans lui, les deux instances partagent un Device ID donc un PUID, et
   chacune écarte le ticket de l'autre comme étant le sien (rencontré pour de
   vrai le 2026-08-18). La découverte est prouvée ; la jointure, la poignée de
   main, l'accord sur qui héberge et la connexion ne le sont pas. Protocole :
   [PROTOCOLE_TEST_EOS.md](PROTOCOLE_TEST_EOS.md).
4. **La contre-vérification à deux machines** (H1), due depuis les correctifs. Le
   test à deux fenêtres ne la remplace pas : même machine, même réseau, donc ni
   traversée de NAT ni latence réelle.
5. **Les 76 assets**, à commencer par les cinq fichiers de musique — délai de
   production le plus long, et ils réveillent un système entier déjà câblé (V1.1).
6. **Le contenu des catégories de rang 5 à 10** : six armes à inventer. La
   mécanique les attend, le tableau `RankLoadout.COMPETITIF` a leurs places.

### Dettes anciennes, sans urgence

7. Reste dû de la Phase 2, jamais déroulé : la checklist manuelle
   `CHECKLIST_TESTS_EN_LIGNE.md` et la validation à 120 ms de latence simulée.
8. Deux points connus : le relais Epic n'a jamais été exercé (la connexion
   directe a toujours abouti), et la détection de déconnexion est lente des deux
   côtés.

## D'où viennent les millisecondes du duel — mesuré le 2026-08-18

`tools/run_decomposition.sh`, sept relevés pris le 2026-08-18 avec l'accord
d'Adrien. **Conclusion : la seconde vue EST le coût du duel ; les torches et les
shaders du joueur ne se distinguent pas du bruit.**

| Configuration | médiane | soit | 1 % bas |
|---|---|---|---|
| duel complet | 135 | 7,41 ms | 81 |
| **socle nu** (1 vue, sans torches, sans shaders) | 165 | 6,06 ms | 117 |
| sans la 2ᵉ vue | 172 | 5,81 ms | 118 |
| sans les torches | 135 | 7,41 ms | 103 |
| sans les shaders joueur | 132 | 7,58 ms | 92 |
| socle + 2ᵉ vue seule | 132 | 7,58 ms | 99 |
| socle + torches seules | 160 | 6,25 ms | 119 |
| socle + shaders joueur seuls | 160 | 6,25 ms | 118 |

**Tout l'écart à expliquer vaut 1,35 ms** (duel complet moins socle nu).

| Poste | borne basse | borne haute | verdict |
|---|---|---|---|
| **2ᵉ vue** | 1,60 ms | 1,52 ms | **bornes serrées, et ≥ l'écart total : elle explique tout** |
| torches | 0,00 ms | 0,19 ms | sous le bruit |
| shaders joueur | −0,17 ms | 0,19 ms | **encadrent zéro : indiscernable** |

**Ce que ça tranche.** L'hypothèse de ce document — « deux `SubViewport` qui
rendent chacun leurs lumières » — était **juste, et pour la moitié seulement de
la raison invoquée** : c'est le **second rendu** qui coûte, pas l'éclairage. Une
torche allumée ne se mesure pas ; un `.gdshader` de joueur non plus.

**⚠️ Et une phrase de ce document était fausse : « l'écran partagé permanent est
une décision de conception du jeu ».** Personne ne l'a jamais décidé — c'était une
description d'architecture (`CLAUDE.md`) transformée en intention par la session
qui rédigeait, puis présentée à Adrien comme un arbitrage à prendre. **Adrien l'a
relevée lui-même** : « je ne crois pas que le deuxième écran permanent soit
l'identité du jeu ».

**En vérifiant, on a trouvé mieux qu'une correction de vocabulaire.** Cacher un
`SubViewportContainer` **ne suspend pas** son `SubViewport` : `_restore_viewports()`
appelait `hide()` sur la vue inutile en ligne et à l'entraînement, et celle-ci
**continuait de dessiner dans une texture que personne n'affiche**. Le
`render_target_update_mode` n'était mis à `UPDATE_DISABLED` que pendant le gel du
kill, et rétabli à `UPDATE_ALWAYS` **sur les deux vues** derrière.

C'est **exactement le piège que le banc de décomposition venait d'éviter le même
jour** (`UPDATE_DISABLED` plutôt que `hide()`), présent dans le jeu lui-même.

**Le levier n'est donc pas l'écran partagé, c'est un rendu inutile :**

- en **écran partagé**, la seconde vue est légitime — quelqu'un la regarde ;
- **en ligne et à l'entraînement, personne ne la regarde** et elle coûtait
  pourtant les 1,5 ms mesurés, soit tout l'écart ;
- et la convergence vaut d'être dite : **la cible de cadence vient de la latence
  EOS**, donc du mode en ligne — précisément là où ce coût ne servait à rien.

Corrigé : `_accorder_rendu_aux_vues()` accorde le mode de rendu à la visibilité
réelle, y compris à la sortie du gel du kill — qui rallumait les deux d'office et
faisait revenir le coût à la première mort, sans rien pour le dire. **Le gain
reste à mesurer en ligne** : la décomposition a été prise en écran partagé, où
les deux vues sont légitimes.

**Signalé, pas corrigé — le champ de vision diffère entre les modes.** Les deux
`SubViewportContainer` sont en `EXPAND | FILL` dans un `HBoxContainer` : cacher
l'un fait occuper toute la largeur à l'autre, ce qui est le comportement voulu.
Mais le zoom de caméra reste 1,0 dans les deux cas — donc **en ligne on voit
environ deux fois plus large qu'en écran partagé**. C'est symétrique entre les
deux joueurs d'un même match, donc ce n'est pas un avantage ; c'est en revanche
une **différence entre modes** dans un jeu où l'information est tout le sujet, et
une carte apprise en écran partagé ne se joue pas pareil en ligne. À trancher par
Adrien, pas par le code.

**Deux réserves, et la seconde corrige ce qu'on croyait acquis.**

1. **Le plancher de bruit vaut ~0,25 ms sur la médiane.** « Sans la 2ᵉ vue »
   (172) ressort **plus rapide** que le socle nu (165), alors qu'il en fait
   davantage. Aucun écart inférieur à ce plancher n'est lisible — ce qui suffit à
   ranger torches et shaders comme « non mesurables », pas comme « gratuits ».
2. **Le 1 % bas du duel est bruité lui aussi : 81 ici contre 97 deux heures
   plus tôt, sur la même configuration.** On avait écrit que le duel, à charge
   continue, donnait un 1 % bas solide — contrairement aux menus. **C'est faux
   des deux côtés** : la traîne varie d'un relevé à l'autre partout. Seule la
   **médiane** est reproductible. Toute décision prise sur un 1 % bas unique,
   duel compris, est prise sur un chiffre qu'un second relevé déplacerait.

**Ce que la cible devient, dit précisément.** Elle est écrite « **1 % bas** ≥ 120
fps », donc sur la métrique dont on vient d'établir qu'elle **ne se mesure pas en
un passage**. Sur la médiane — la seule reproductible — le duel tient **7,41 ms
contre 8,33 ms de budget**, et toutes les configurations mesurées sont au-dessus
de 120.

Il serait tentant d'en conclure « le jeu a toujours tenu les 120 fps ». **Ce
serait refaire l'erreur du jour** : changer de métrique pour obtenir le verdict
qui arrange, exactement comme le banc d'origine changeait d'échantillon sans le
dire. Ce qui est vrai est plus étroit et plus utile :

- **la cible telle qu'elle est écrite n'est pas vérifiable en un relevé** ;
- **sur la métrique qui l'est, le jeu passe** ;
- donc soit on **réécrit la cible sur la médiane** — et elle est tenue — soit on
  la garde sur le 1 % bas et **il faut alors répéter les relevés**, en donnant la
  dispersion et non un nombre.

Le choix appartient à Adrien ; ce document ne le prend pas à sa place.

**Pourquoi ce chantier.** Ce document attribuait les 7,6 ms du duel à « deux
`SubViewport` qui rendent chacun leur jeu de lumières et d'ombres portées ».
C'était une **hypothèse écrite comme une explication**, jamais mesurée — la forme
exacte de ce que cette journée a passé son temps à démonter ailleurs, et écrite
de la main de la session qui venait de démonter les deux autres.

**Pourquoi sept et pas trois.** Retirer un poste du duel complet donne sa borne
**basse** : ce qu'on économise quand tout le reste est encore là pour masquer son
coût. Le rendre à un socle nu donne sa borne **haute** : ce qu'il coûte quand
rien ne le recouvre. Le vrai coût est entre les deux, et **l'écart entre les
bornes mesure le recouvrement lui-même** — ce qu'un relevé unique ne peut pas
dire. Des bornes serrées tranchent ; des bornes larges apprennent que le poste ne
s'isole pas, et c'est aussi une réponse.

Le **socle nu** (une vue, sans torches, sans shaders joueur) est la mesure la
plus intéressante des sept : elle dit le plancher qu'aucun réglage ne fera bouger.

**Un garde-fou qui vaut comme règle générale : une variante de banc doit prouver
qu'elle a changé quelque chose.** « Sans shaders » compte les matériaux retirés
et **sort en échec sur zéro** ; la seconde vue passe par `UPDATE_DISABLED` et non
`hide()`, un conteneur caché laissant le `SubViewport` rendre dans son coin. Sans
ces deux contrôles, une variante produit un chiffre **valide sur une
configuration qui n'est pas celle qu'elle annonce** — et deux mesures identiques
se liraient alors comme « ce poste ne coûte rien », la conclusion la plus
dangereuse des deux.

---

## Ce que les relevés ont déjà tranché pour le game feel

**Le gel des vagues 4 et 5 était trop large, et c'est corrigé ici.** Il avait été
posé vague par vague ; le coût se juge **item par item**.

| Ce que fait l'item | Statut | Pourquoi |
|---|---|---|
| **Ponctuel et poolé** — un éclat, une secousse, un one-shot qui rend son nœud | **Ouvert** | Le pic de particules est à 122 sur 200, identique aux trois relevés : le budget n'est pas saturé, et rien de ponctuel n'entre dans le régime permanent. |
| **Coût par image, en continu** — une `Light2D` de plus, un `.gdshader` sur un nœud toujours visible | **Gelé** | Le 1 % bas du duel est déjà sous la cible. Ajouter du permanent avant de savoir d'où vient le coût existant serait exactement ce que la règle du dépôt interdit. |
| **Audio, menus, killcam** | **Ouvert** | Zones franches (manche finie) ou charge sans commune mesure — les menus tiennent à 163 de 1 % bas, 66 % de marge. |

---

## Journal des relevés de cadence — 2026-08-18

Trois relevés le même jour, **dont deux ne mesuraient rien.** L'histoire compte
autant que le chiffre : elle dit pourquoi il ne faut pas refaire confiance à un
banc sans le relancer.

| # | Résultat | Ce qu'il valait |
|---|---|---|
| 1 | *aucun* | Le banc pilotait `_ui.btn_mode_local`, disparu à la Phase 5. Ouvert, erreur de script, jamais entré dans le duel, **resté ouvert sans mesurer**. Tué à la main. |
| 2 | 1 % bas **109**, minimum 109 | Mesure creuse : `get_frames_per_second()` ne bouge qu'une fois par seconde, donc 15 mesures recopiées 139 fois. `1 % bas == minimum` en est la signature. Sorti en **signal 11** (arrêt EOS non propre). |
| 3 | **1 % bas 97** | Le seul honnête. Temps d'image relevés par image, sortie par `quit_game()`, code 0. |

**Relevé n° 3 — conditions propres** (éditeur Godot fermé, aucune autre session,
aucun autre Godot), écran partagé, torches allumées, échange au pompe :

```
Images mesurées     : 2035 en 15,0 s
FPS moyen           : 136        FPS médian : 132  (7,6 ms)
FPS 1 % bas         : 97         (moyenne des 20 images les plus lentes)
Image la plus lente : 12,6 ms → 79 fps
Particules (pic)    : 122 / 200
Verdict 120 fps     : NON TENU
```

**Ce que le chiffre dit — et il dit autre chose que ce qu'on cherchait.**

- **Il n'y a pas de saccade.** Cinq millisecondes séparent la médiane (7,6 ms) de
  la pire image (12,6 ms). Ce n'est pas un pic qui tire le 1 % bas vers le bas,
  c'est une **charge constante un peu trop lourde**. Cela écarte d'emblée tous
  les suspects « allocation ponctuelle ».
- **Le budget de particules n'est pas saturé** : 122 sur 200, valeur identique
  aux relevés 2 et 3. C'est le seul chiffre qui ait survécu aux trois. **La marge
  n'est donc pas dans les particules**, et l'ajouter de nouvelles (vague 5) ne
  sera pas ce qui fait basculer le verdict.
- La cible de 120 fps demande 8,33 ms par image. La **médiane est à 7,6 ms** : le
  jeu tient de justesse en régime courant et perd sur la traîne.
- **Ce n'est PAS une régression** — et c'est le point le plus important. Le
  « verdict : tenu » du 2026-08-16 reposait sur le **même compteur creux** : le
  banc d'origine échantillonnait déjà `get_frames_per_second()`. Sa signature
  était publiée depuis trois jours (médiane 145, 1 % bas 144, minimum 144 — trois
  valeurs quasi identiques, ce qu'un vrai percentile ne produit jamais) et
  personne ne l'a lue. **Les 120 fps n'ont jamais été vérifiés comme atteints** :
  ce 97 est la première mesure honnête du projet, pas une dégradation. Le coût
  vient de la conception — deux `SubViewport` rendant chacun leur jeu de lumières
  et d'ombres portées.

**Écarté explicitement, faute de mécanisme :** l'arbitrage du pool de voix
(`choisir_voix`) construit un tableau de 16 booléens **par son joué**, soit
quelques allocations par seconde — il ne peut pas produire un plancher aussi
régulier. Il restait le premier suspect tant qu'on croyait à des pics ; le relevé
honnête l'écarte.

### Relevé des MENUS — 2026-08-18, banc corrigé, `--menus`

```
Images mesurées     : 3112 en 15,0 s
FPS moyen           : 207        FPS médian : 200
FPS 1 % bas         : 163        Image la plus lente : 14,5 ms (69 fps)
Particules (pic)    : 0 / 200    Verdict 120 fps : TENU
```

**Les deux charges du jeu sont sans commune mesure**, et c'est la première fois
qu'on peut le dire : 200 fps de médiane dans les menus contre 132 dans le duel,
un 1 % bas 43 fps au-dessus de la cible contre 23 en dessous. Zéro particule et
zéro balle confirment que la charge mesurée est bien la vitrine seule.

**Conséquence de méthode : un verdict unique aurait été faux dans les deux
sens.** Traiter les deux moments du jeu comme une seule mesure aurait bridé les
menus pour un problème qui n'est pas le leur, ou déclaré le duel sain sur la
bonne santé du hub.

**Ce que le banc de menus a dû faire pour ne pas mentir** — et c'est le piège
propre à cette charge : *un curseur immobile est le MEILLEUR cas, pas le pire*.
Les effets de la vitrine coupent tous leur traitement au repos, par conception.
Un banc qui ne bougerait pas rendrait un chiffre honnête sur une charge absente.
Le mode `--menus` déplace donc le curseur à chaque image et traverse un écran
toutes les 1,2 s, en passant par `noter_geste()` puis `push()` — sans quoi
l'encre coulée ne se déclenche pas et l'effet le plus coûteux de la navigation
manquerait à la mesure.

**Signalé sans être expliqué** : l'image la plus lente des menus (14,5 ms) est
*pire* que celle du duel (12,6 ms). Sur 3112 images c'est un point isolé — les
31 plus lentes tiennent une moyenne de 6,1 ms — et il tombe probablement sur une
traversée d'écran. Si quelqu'un cherche un jour un à-coup au changement d'écran,
c'est ici qu'il commence.

### Le second étage de M14, mesuré — 2026-08-18

Sa fiche l'interdisait sans mesure : « à valider au `bench_framerate` avant
d'être gardé ». Trois relevés `--menus`, machine calme, 15 s chacun :

| | moyen | médian | 1 % bas | pire image |
|---|---|---|---|---|
| sans flou | 207 | **200** | 163 | 14,5 ms |
| avec flou (1) | 200 | **200** | 169 | 12,6 ms |
| avec flou (2) | 200 | **199** | 139 | 16,2 ms |

**Décision : le flou est gardé.** Il coûte ~3 % de la cadence moyenne (207 → 200,
mesuré deux fois) et **rien de détectable sur la médiane** (200 → 200 / 199),
dans un mode qui a 66 % de marge au-dessus de la cible. Neuf lectures d'écran en
croix plutôt qu'en carré — quatre-vingt-une prises pour un résultat que l'œil ne
distingue pas à ce rayon — et **réservé au seul cadre de droite** : c'est une
copie d'écran par image, la donner aux vingt rangées coûterait vingt fois pour un
effet qu'on ne verrait que sur la plus grande.

> **Et un constat de méthode qui vaut pour les relevés suivants : le 1 % bas des
> MENUS n'est pas une statistique fiable sur 15 s.** Il vaut 163, 169 puis 139
> sur trois exécutions du même code — ±30 fps — pendant que la médiane ne bouge
> pas d'une image. La raison est structurelle : en menu la charge est *ponctuée*
> (traversées d'écran, compilations de shader) et non continue comme dans le
> duel. Une trentaine d'images seulement tombent dans le centième le plus lent,
> et deux transitions y suffisent à tout déplacer.
>
> **Conséquence pratique : dans le mode menus, c'est la MÉDIANE qui tranche**, et
> le 1 % bas ne sert qu'à repérer une saccade franche. Dans le duel, où la charge
> est continue, c'est l'inverse. Attribuer une différence de 1 % bas à un
> changement de code, ici, serait exactement l'erreur qu'on a passé la journée à
> traquer — un chiffre à qui l'on fait dire ce qu'il ne mesure pas.

**Décision qui revenait à Adrien** : 97 est-il acceptable ? La cible de 120
venait de la latence EOS, pas du confort visuel. À 97 le budget d'image ajoute
~10 ms au temps de réaction ; à 120 il en ajouterait 8,3. L'écart réel est de
**1,7 ms** — à comparer aux 54 ms de plancher RTT mesurés sur EOS.

> **TRANCHÉ le 2026-08-18 par Adrien : « 1,7 ms c'est pas dramatique, on verra
> plus tard. »**
>
> Lire exactement ce qui est dit, et rien de plus. Il **ajourne** l'arbitrage ;
> il ne réécrit pas la règle. Concrètement :
>
> - **la cible reste écrite telle quelle** — `1 % bas ≥ 120` — en attendant une
>   décision qui n'est pas urgente ;
> - **elle cesse de bloquer quoi que ce soit.** Aucun chantier ne s'ajourne plus
>   au motif que le 1 % bas est sous la cible : elle l'a fait deux fois le
>   2026-08-18, sur un chiffre dont on sait maintenant qu'il varie de 81 à 97
>   sans qu'une ligne change.
>
> Ce qui reste vrai et qui servira le jour où la question se rouvrira : **la
> médiane est la seule métrique reproductible**, le jeu la tient (7,41 ms contre
> 8,33 de budget), et le seul coût identifié est **la seconde vue**.
>
> ⚠️ **Ce paragraphe disait « l'écran partagé permanent, une décision de
> conception et non un réglage ». C'est la formule qu'Adrien venait de rejeter**
> (« je ne crois pas que le deuxième écran permanent soit l'identité du jeu »),
> corrigée deux commits plus tôt, et **revenue à un autre endroit du même
> document** — écrite de bonne foi par une session qui reprenait la synthèse
> d'avant la correction.
>
> **Une erreur corrigée revient par la synthèse.** Le correctif était posé là où
> l'erreur était née ; la reformulation, elle, est allée la rechercher dans le
> souvenir de ce qu'on croyait établi. C'est le pendant du piège du README —
> écrire la leçon là où le suivant lira ne suffit pas si l'ancienne version reste
> lisible ailleurs. **Corriger un document, c'est aussi chercher où la phrase a
> déjà essaimé.**
>
> Ce qui est exact : la seconde vue est le seul coût identifié ; **l'écran partagé
> n'existe désormais que dans « 1v1 écrans scindés »** (décision d'Adrien, table
> des décisions actées), et en ligne comme à l'entraînement la vue cachée ne rend
> plus — elle rendait encore la veille de cette ligne.
>
> Ce qui reste à trancher, un jour : garder la cible sur le 1 % bas en exigeant
> des relevés répétés et une dispersion, ou la réécrire sur la médiane. Les deux
> formulations ne disent pas la même chose, et c'est pour ça qu'on ne l'a pas
> tranché à sa place.

### Quatre défauts relevés après l'arrivée des dix classes (2026-09-09)

Adrien a joué sur `v0.4.0` fraîchement publiée et rapporté quatre points, tous
corrigés le même jour.

**1. L'affiche de victoire/défaite (`affiche_de_fin.gd`, chantier DA6) n'était
pas la dernière porte devant REJOUER.** Elle est opaque et censée avaler ses
propres clics, mais elle se congédie sur N'IMPORTE QUEL geste — donc un joueur
pressé la fait disparaître ET presse REJOUER dans le même clic, avant d'avoir
rien lu. `AfficheDeFin.est_active()` (nouveau) et `UI.set_launch_locked()`
grisent désormais le bouton tant qu'elle vit, en plus du filtre de clic déjà
là — deux portes, pas une. `_poser_affiche_de_fin()` connecte son
`tree_exited` pour relâcher le verrou, quel que soit le chemin de sortie
(délai de six secondes ou geste). ⚠️ Le banc `test_online_match.gd` appelait
`_on_replay_requested()` directement, sans passer par un clic : il a fallu lui
faire congédier l'affiche d'abord, sans quoi le verrou — tout neuf et
parfaitement fondé — bloquait un rematch légitime. Rien à en tirer contre le
correctif : le banc simulait un geste qu'aucun joueur ne fait.

**2. Le menu pause héritait du ralenti de la killcam.** `replay_system.gd`
porte `Engine.time_scale` à 0,03-0,05 pour l'effet bullet-time, et un `Tween`
suit ce temps par défaut : ouvrir la pause pendant une killcam l'allumait donc
au ralenti. **Même défaut, même remède qu'un cas déjà payé sur l'audio**
(`audio_manager.gd`, `_tween_etouffement`, l'étouffement de la mort qui durait
vingt secondes réelles) : `Tween.set_ignore_time_scale(true)` sur les deux
tweens de `_allumer()`/`_eteindre()` — le mécanisme M10 partagé par tous les
panneaux de menu, pause comprise. Une pièce d'interface n'a aucune raison de
ralentir avec l'image ; le second cas de cette forme confirme que c'est une
règle du dépôt, pas un raccommodage.

**3 et 4. Deux ajouts au salon, une fois le chantier CLASSES posé.** La
session « 10 classes » a délibérément sorti le râtelier complet du panneau de
salon par défaut — sa fiche fait trois fois la hauteur de la colonne, qui
loge déjà la carte, la liste des joueurs et PRÊT (voir le commentaire de
`_build_weapon_block()`). Adrien confirme cet arbitrage mais veut un
sélecteur compact EN PLUS de la carte déjà là, sans ouvrir la fiche : les
deux cartes de classe du salon (`_cartes_classe`, jusque-là de simples
résumés en lecture seule) deviennent cliquables — clic gauche pour avancer,
clic droit pour reculer dans la liste ordonnée par rang, en sautant les
classes verrouillées par le rang (`.disabled`). Une carte visible EST une
carte qu'on a le droit de changer : `_montrer_rateliers()` cache déjà celle
qu'on ne pilote pas depuis cette machine, donc aucun contrôle d'autorisation
de plus à écrire. Et la vignette de carte (`map_card`) devient elle-même
cliquable, renvoyant vers l'entrée « CHANGER DE CARTE » déjà présente dans la
liste — mais seulement sur les écrans qui en ont une (l'hôte d'un salon, pas
l'invité ; l'écran partagé et l'entraînement, où il n'y a que de l'hôte). Le
« si on est l'hôte » demandé se lit donc dans un dictionnaire vide plutôt que
dans un contrôle explicite : un écran sans entrée mappée ne fait simplement
rien au clic.

⚠️ **Ces quatre correctifs touchent `ui.gd` et `game_state.gd`, que la session
« 10 classes » modifie activement au même moment** — coordination confirmée
avec elle avant de pousser (voir plus haut, échange sur `v0.4.0`) : elle sait
que ces deux fichiers ont bougé sur `main` avant son prochain rebase.

---

## Journal des tests à deux machines

| Date | Configurations | Résultat |
|---|---|---|
| 2026-08-16 (matin) | Même Wi-Fi ; un poste en 4G ; les deux en 4G, opérateurs différents | `Lien DIRECT` partout, ping 58 ms. Trois défauts relevés : jointure incertaine, message trompeur, killcam muette. Tous corrigés depuis. |
| 2026-08-16 (après-midi) | Même réseau | Connexion et ping sains, mais **les commandes du client ne remontaient pas**. Trois manches d'instrumentation F3 ont mené à la cause : des noms de nœuds auto-générés divergents entre machines. Corrigé. |
| 2026-08-16 (soir) | Même réseau | Commandes et déplacements ✅. **Killcam tronquée** : tampon de rejeu dimensionné en images et non en durée, effondré par le déplafonnement des fps. Corrigé — enregistrement à 60 Hz fixe. |
| 2026-08-16 (fin) | Même réseau | **Tout fonctionne** : commandes, tirs, dégâts, killcam des deux côtés. Phase 3 close. |
| 2026-09-09 | Deux machines, **recherche automatique** (le premier essai de ce chemin) | Elles se trouvent, mais **une seule entre en match** : l'hôte attend un joueur 2 qui reste dans son menu. Aucune erreur console. Cause : `match_ready` est émis avant que le lien soit établi, l'hôte partait donc seul en bac à sable — voir « Ouvrir un lien n'est pas l'établir » dans les Pièges connus. Corrigé, et couvert par deux bancs. **Reste à rejouer à deux machines.** |
| 2026-09-09 (rejoué) | Deux machines, **match amical apparié** | Les deux se trouvent, la fenêtre de choix de dix secondes s'ouvre, les deux appuient sur PRÊT — **la manche ne part que côté hôte**, l'invité reste planté sur son décompte jusqu'à dix. Aucune erreur console. Cause : l'abrègement par « prêt » ne collapse le décompte que localement, côté hôte (`_process()`) — rien n'en informe le client. Voir « Deux prêts, un seul départ » aux Pièges connus. **Corrigé en retirant la fenêtre du chemin amical** (elle reste au classé) : Adrien a tranché à cette occasion que l'amical choisit son arme avant la recherche, garde un décompte de trois secondes commun aux deux côtés, et joue sur la carte par défaut plutôt qu'une carte tirée au sort. **Reste à rejouer.** |
