# Journal des sessions parallèles

> **À quoi sert ce fichier.** Plusieurs sessions d'agents travaillent sur ce
> dépôt en même temps, sans pouvoir se parler. Le dépôt est leur seul canal.
> Ce journal dit **qui tient quoi en ce moment**, pour qu'aucune ne réécrive le
> fichier d'une autre.
>
> Ce n'est pas la feuille de route : `docs/ROADMAP.md` dit *où va le projet*,
> ce journal dit *qui a les mains dedans maintenant*. Une ligne périmée ici
> coûte un conflit de fusion ; une ligne périmée là-bas coûte une décision.

## Règle unique, et elle prime sur le confort

**Le partage se fait par fichier, pas par sujet.** Deux agents qui travaillent
sur « des sujets différents » dans le même fichier produisent un conflit à
chaque poussée. Deux agents sur des fichiers disjoints n'en produisent aucun.

`ui.gd` fait près de 3 000 lignes et construit toute l'interface en code : il
est réécrit en profondeur par la Phase 5. C'est le fichier qui rend le partage
par sujet impraticable.

## Répartition en cours

| Domaine | Fichiers réservés | Session |
|---|---|---|
| **Menus et méta** — Phases 5, 6, 7 | `ui.gd`, `settings_manager.gd`, `map_gallery.gd`, `ranked_identity.gd`, `asset_manifest.gd`, `hub_screen.gd`, `menu_hub.gd`, `menu_theme.gd`, `screen_*.gd`, `supabase/**` | Session « menus » |
| **Mise à jour du jeu** — Phase 9 | `update_manifest.gd`, `update_installer.gd`, `update_manager.gd`, `patch_loader.gd`, `screen_update.gd`, `tools/test_mise_a_jour.gd`, `tools/test_autoloads.gd`, `tools/fabrique_manifeste.sh`, `.github/workflows/release.yml`, `docs/MISE_A_JOUR.md` | Session « mise à jour » — **livrée le 2026-08-24**, plus personne dessus |
| **Game feel en manche** — vagues V1 à V6 | `player.gd`, `bullet.gd`, `blood_stain.gd`, `particle_pool.gd`, `light_textures.gd`, `training_target*.gd`, `*.gdshader`, `audio_manager.gd`, `tools/generate_music_streams.gd` | Session « game feel » |

### Précision sur `*.gdshader` — ajoutée le 2026-08-18 par la session « menus »

**Le glob `*.gdshader` réserve les shaders au domaine « game feel ». Il a été
écrit quand tous les shaders du dépôt étaient des shaders de jeu** — liseré du
joueur, sang, éblouissement, onde de choc. Les menus n'en avaient aucun.

La vague M en a créé cinq, tous nommés `menu_*.gdshader` :
`menu_backdrop`, `menu_title`, `menu_veil`, `menu_skeleton`, `menu_glass`.
**J'étais donc en infraction avec la lettre de la table pendant une journée
entière, sans le savoir, faute d'avoir lu ce fichier.** Aucun conflit n'en est
résulté — ce sont des fichiers **créés**, pas modifiés, et la fusion mesurée le
même soir n'en signale aucun.

**La frontière proposée, en ajout et non en réécriture :** `menu_*.gdshader`
appartient aux menus, tout autre `*.gdshader` reste au game feel. Le préfixe le
rend vérifiable d'un coup d'œil, et il correspond à ce qui s'est produit
naturellement des deux côtés — `sprint_streaks.gdshader` est arrivé chez eux le
même jour, sans collision.

Si la session « game feel » préfère une autre frontière, qu'elle la pose ici :
je m'y tiendrai.

### Ce que la Phase 9 a pris ailleurs, et pourquoi c'est minuscule

`ui.gd` appartient à la session « menus ». La mise à jour n'y a touché qu'en
**trois endroits** — une constante d'écran, une entrée d'accueil, un
`_attach_screen` — exactement le motif des écrans précédents. Tout le reste vit
dans des fichiers neufs. `project.godot` a gagné `config/version` et deux
autoloads, dont `PatchLoader` **en tête de liste** : cette position est une
contrainte technique, pas un rangement, et la déplacer casserait silencieusement
les correctifs.

### `game_state.gd` — le seul fichier disputé

Les deux domaines en ont besoin : l'orchestration du kill pour le game feel, la
règle du miroir des armes pour la Phase 7.

**Il appartient à la session « game feel » jusqu'à nouvel ordre.** La session
« menus » s'en tient à l'écart et demandera la main en arrivant à la Phase 7,
en l'annonçant ici.

### `docs/ROADMAP.md` — écrit par tout le monde

Inévitable, et gérable à deux conditions :

1. **N'écrire que dans ses propres sections.** Les vagues de game feel d'un
   côté, les Phases 5 à 7 de l'autre.
2. **Ne jamais reformater ni réordonner la section d'une autre session**, même
   pour l'améliorer. Une correction de forme sur un paragraphe voisin
   transforme un diff d'une ligne en conflit de section entière.

« Pièges connus » et « Décisions actées » se remplissent en **ajout** : une
entrée à la suite, jamais une réécriture des précédentes.

## Dépendance connue entre les deux domaines

**V1.4 (volumes Master / Musique / Effets / Annonceur) est listée comme
précondition de tout le travail audio — et elle vit dans les Options, donc dans
le domaine « menus ».** Elle est livrée par la Phase 5, étape 4. La session
« game feel » ne l'implémente pas : elle attend, ou densifie le mixage en
sachant qu'il n'est pas encore réglable.

## Les deux documents à tenir — règle du 2026-08-17

Toute session met à jour **les deux**, quel que soit son domaine :

1. `docs/ROADMAP.md` — versionné, pour les agents. Le *pourquoi*.
2. **Le suivi de projet**, pour Adrien :
   https://claude.ai/code/artifact/ba2ce690-309e-4d87-b72b-3ace1a1b681e

Le second se republie avec l'outil `Artifact` **en passant cette URL**. Sans elle,
la publication crée un artefact *distinct*, et Adrien se retrouve devant deux
tableaux qui se contredisent sans savoir lequel croire.

**Pourquoi cette règle existe, et pourquoi elle est plus fragile que les autres :**
la feuille de route vit dans le dépôt, donc un oubli finit par se voir en la
relisant. Le suivi vit dehors — **aucun outil, aucune suite, aucun audit ne
signale qu'il est périmé.** C'est le seul document du projet dont la péremption
est totalement silencieuse.

Une session qui n'a pas l'outil `Artifact` — un sous-agent, typiquement — ne peut
pas republier. Elle **le dit dans son rapport**, avec ce qu'il aurait fallu
changer, pour que la session principale le fasse. Se taire équivaut à laisser le
tableau mentir.

## Assets manquants — la règle, décidée le 2026-08-17

**On câble, on reste silencieux, on diagnostique.** Le code qui joue un son
absent s'écrit normalement ; il ne trouve pas le fichier et ne joue rien, sans
erreur. Aucune session ne fabrique de bouche-trou sonore : un placeholder qui
traîne finit par être pris pour une intention.

`asset_manifest.gd` (domaine « menus ») porte la liste des 76 fichiers attendus
et sait répondre à deux questions différentes :

- **absent** — le fichier n'existe pas ;
- **bouche-trou** — le fichier existe et ne contient rien. `music_menu.ogg`,
  `music_match.ogg` et `music_victory.ogg` pèsent exactement 160 032 octets :
  trois copies du même flux vide produit par `generate_music_streams.gd`. Un
  contrôle de présence les déclarerait bons. La détection se fait donc à la
  taille, ce qui a l'avantage de se corriger tout seul le jour où le vrai
  fichier arrive.

Le panneau **F3** affiche l'état en jeu. La liste complète — noms exacts, durées
sur la grille à 170 BPM, intentions — vit dans l'onglet ASSETS du suivi de
projet, et c'est elle qu'Adrien utilise pour commander.

Une session qui a besoin d'un son doit **ajouter son entrée au manifeste** plutôt
que d'inventer un chemin dans son coin. Le manifeste étant dans le domaine
« menus », l'ajout se demande ici.

> **Changement du 2026-08-17, à l'attention de la session « game feel ».** Ce
> journal disait jusqu'ici de NE PAS commencer les items marqués *assets*. Ce
> n'est plus la règle : Adrien a tranché pour « câbler, taire, diagnostiquer ».
> Les items à assets se font donc, avec le silence pour comportement par défaut.

## Ce qui est bloqué et ne doit pas être commencé

- **Les items D1 à D7** : ils attendent un arbitrage d'Adrien parce qu'ils
  changent l'information disponible en jeu ou coûtent des images par seconde.

## ~~Signalé à la session « game feel »~~ — **corrigé le 2026-08-17**

**Le flash de mort blanchit aussi l'écran du survivant.** Relevé le 2026-08-17
par la session « menus », qui ne touche pas à ce fichier : c'est à vous.

Dans `die()`, le flash crée un `CanvasLayer` (layer 100) portant un `ColorRect`
plein cadre, et **ne pose aucun `visibility_layer`** — contrairement aux visuels
du joueur, qui posent explicitement 2 (sa vue) ou 4 (la vue adverse) aux lignes
221-231.

Ce qui rend le défaut certain plutôt que probable : `main.tscn` donne
`canvas_cull_mask = 3` à la première vue et `= 5` à la seconde. **Les deux
incluent le bit 1**, qui est la valeur par défaut de `visibility_layer`. Un
`CanvasItem` laissé au défaut rend donc dans les deux vues, en local comme en
ligne — l'écran partagé est permanent.

Conséquence de jeu : celui qui vient de tuer se prend 600 ms de blanc et
d'aberration chromatique dans les yeux, dans un jeu où l'information est le seul
enjeu. Ce n'est pas un défaut visuel, c'est un défaut d'équité.

Le correctif tient en une ligne sur le `ColorRect`. Le label « FATAL » du même
bloc est un cas différent : il vit en espace-monde, à l'endroit de la mort, et
que les deux joueurs le voient se défend.

**Corrigé** par la session « game feel » (`3efb0d2`) :
`flash_rect.visibility_layer = 2 if player_id == 0 else 4`, exactement la ligne
attendue. Le doute est donc levé — le flash ne touche plus que l'écran du
mourant, et `flash_mort` reste légitimement classé **CONFORT** dans
`effect_policy.gd`, réglable jusqu'à zéro.

Le canal a fonctionné dans les deux sens : un défaut relevé par une session qui
ne pouvait pas le corriger, corrigé par celle qui possédait le fichier, sans
qu'aucune ne touche au domaine de l'autre. C'est le seul mode de coordination
disponible entre sessions, et il tient.

> **Clôture du 2026-08-17 : plus aucune session parallèle.** Une seule branche,
> `main`, un seul arbre. Ce journal redevient une archive — il reprendra son rôle
> de canal le jour où plusieurs sessions travailleront de nouveau ensemble.

## À l'attention de la session « artefact » — ce qu'il faut y porter

**Je n'ai pas republié le suivi**, sciemment : une refonte est en cours et
republier l'écraserait. Voici ce qu'il manque, à intégrer par qui tient le
fichier.

### État réel au 2026-08-17, fin de journée

| Phase | État |
|---|---|
| 1 à 4 | closes |
| 5 — les menus | 🟡 étapes 1, 2, 3 et 3b closes ; restent l'écran audio, la calibration, l'historique et l'entraînement |
| 6 — rangs | échelle validée, `rankOf` déployée, **affichage en jeu à faire** |
| 7 — armes | à faire, règle du miroir actée |
| 8 — appariement | 🟡 **en cours** — 8.1 déployée, cœur et écran écrits et testés, **non raccordés** |

**Quinze suites existent, treize tournent.** Le lanceur est
`./tools/run_suites.sh`, qui échoue aussi sur toute erreur de script.

### Le verrou de la Phase 8, à mettre en tête

`test_matchmaking` et `test_screen_matchmaking` passent toutes leurs assertions
mais **sortent en 139** dès que `eos_credentials.gd` est présent : elles touchent
`NetworkManager`, EOS démarre, et l'extinction croise `EOS_Platform_Tick()` sans la
séquence d'arrêt propre. Le worktree où elles ont été écrites n'avait pas les
identifiants — le défaut n'y apparaissait donc pas.

Tant que ce point n'est pas levé, **l'autoload `Matchmaker` ne peut pas être
déclaré** sous peine de propager le segfault à toutes les suites. Donc :
l'appariement ne tourne pas, et les deux entrées « chercher un match » restent
grisées. C'est la première priorité, avant tout le reste.

### Trois choses qui méritent d'être racontées, pas seulement listées

- **L'identifiant de match est tiré par engagement-révélation.** L'hébergeur
  publie l'empreinte de son nonce avant qu'aucun adversaire n'existe ; le joueur
  déclare le sien à l'aveugle ; la révélation est vérifiée contre l'engagement.
  L'un est lié, l'autre est aveugle : « aucun des deux ne contrôle le tirage »
  devient vrai au lieu d'être affirmé. La désignation de l'hôte en découle, et elle
  est prouvée sans biais sur 20 000 tirages par famille d'identifiants.
- **Un match amical ne peut plus alimenter le classement en silence** (8.1,
  déployée). Le défaut de la colonne *est* la règle : un oubli écrit un amical,
  jamais un classé. Et `concordant` exige désormais que les deux pairs s'accordent
  aussi sur la nature du match — tout lecteur qui filtrait déjà dessus hérite de la
  protection.
- **Le hub est en deux panneaux**, et le retour est une entrée cliquable. La
  version précédente affichait « ÉCHAP · RETOUR » sans que rien ne soit cliquable
  et sans que la touche fasse quoi que ce soit.

### Ce qui n'avance pas sans Adrien

Les **76 assets** (voir l'onglet dédié), le **sens des divisions** de rangs
(I la plus basse comme Rocket League, ou la plus haute comme LoL — les tests
passeraient dans les deux cas), le **frottement du déblocage d'armes** (un débutant
démarre en Bougie et aurait trois armes d'emblée), **rejouer** après chaque vague de
game feel, et **Échap / F3** à vérifier à la main.

## État — le plus récent en haut

### 2026-08-25 — session « affichage » (5) : le port cesse d'être une file d'attente

**Adrien m'a confié le lanceur (option A) et le seuil du F3.** Branche
`worktree-lanceur-port`. **Fichiers touchés : `network_manager.gd`,
`tools/run_duo.sh`, `ui.gd`, `docs/ROADMAP.md`, ce journal.**

**Empiètement déclaré sur `ui.gd`** (domaine « menus ») : **une valeur**, le seuil
du F3, sur décision d'Adrien. La session DA4, qui avait posé cette grille, me l'a
signalé avant de s'arrêter et a explicitement refusé de le corriger elle-même
faute de mesure — c'était le bon réflexe.

**La découverte qui a changé le lot, et elle n'était dans aucune de nos
discussions : `PORT` dans `run_duo.sh` ne pilotait que les CONTRÔLES.** `lsof`, le
message de refus, l'alerte orphelin. **Il n'était jamais transmis à Godot**, qui
ouvrait son salon sur `DEFAULT_PORT := 7777`, en dur. Changer la variable du
script aurait déplacé la surveillance sans déplacer le salon — un garde qui
regarde un port pendant que le jeu en ouvre un autre. **C'est le même motif que
le trou `push_error` trouvé le même jour par DA2 : un garde qui a l'air de
surveiller quelque chose, et qui surveille autre chose.** Deux occurrences dans
la journée, sur le même fichier.

**Ce qui est fait.** Le port est **dérivé du chemin de l'arbre de travail** — trois
arbres, trois ports (28290, 33790, 39414) — dérivé **une seule fois** dans
`run_duo.sh` puis exporté, jamais recalculé en aval. `NetworkManager.DEFAULT_PORT`
le lit dans l'environnement et alimente `host_game()` et `join_game()`, qui
l'acceptaient déjà : **`ui.gd` n'a pas eu à bouger pour ça.**

**Les trois conditions posées par DA2 sont tenues, et la troisième était la plus
importante :**

1. **dériver une fois et transmettre** — sinon hôte et client, lancés depuis deux
   dossiers, ouvriraient deux ports et ne se verraient jamais, avec un « aucun
   adversaire n'a rejoint » qui n'apprend rien ;
2. **plage 20000-39999**, à l'écart des ports éphémères de macOS (49152+) ;
3. **honoré en DÉBOGAGE SEULEMENT.** Un `CANDELA_PORT` oublié dans
   l'environnement d'un joueur ferait échouer sa partie LAN sans rien dire. Le
   dépôt a le précédent exact avec `--eos-ephemeral`.

**Vérifié plutôt que supposé** : `hôte prêt : CODE: 33790` — le jeu ouvre bien son
salon sur le port dérivé, hôte et client se voient. Et j'ai pu lancer mon lot
**sans attendre que l'arbre principal se libère**, ce qui est tout le gain.

**Piège rencontré en chemin, et il mérite d'être dit parce que je le connaissais :**
mon premier essai a échoué sur une police non importée et une erreur d'analyse
dans le plugin EOS. J'avais lancé `--import` en tâche de fond juste après avoir
créé le worktree, et il s'était terminé en annonçant zéro problème — **le cache
était incomplet quand même**. Relancé en avant-plan, tout passe. *Un import lancé
en parallèle de la première ouverture du projet ne suffit pas ; le lot suivant
paie l'illusion.*

**Ce que je n'ai pas fait :** rien dans `run_suites.sh` (DA2 venait d'y livrer sa
garde `push_error`, on a séquencé), et rien de R6 — l'obstacle `_poser_sprite()`
est chez DA2, Adrien a validé la densité ×2 et elle lui remonte le coût.

### 📌 DEMANDE OUVERTE — brancher le brouillage de l'éblouissement (2026-08-25)

**À qui reprendra `ui.gd`, `player.gd` ou `game_state.gd`.** Demandé par Adrien.
Aucune session ne tenait ces trois fichiers au moment où c'est écrit — d'où le
dépôt plutôt qu'un message, qui serait mort avec sa session.

Le chantier « brouiller la position de celui qui éblouit » est **clos côté
arbitrage** : B1 à B4 tranchés par Adrien en quatre essais manette en main
(section dédiée dans `docs/ROADMAP.md`). Le modèle, le banc et la suite sont sur
`origin/main`. **Rien n'est branché, et aucun fichier de production ne lit
`brouillage.gd`** — si on lance le jeu aujourd'hui, l'éblouissement se comporte
exactement comme avant.

#### ⚠️ La première tâche n'est PAS de brancher, c'est de mesurer

`brouillage_flou.gdshader` lit l'écran : `BackBufferCopy` **plein cadre, une
fois par image**. En écran scindé il y a **deux `SubViewport` à 957×1080**, et
le chantier R n'a optimisé que la vue unique — ce chemin-là n'a rien gagné.

**La cible est `1 % bas ≥ 60` et le jeu la franchit de DEUX images par seconde**
(61 mesuré fenêtre au premier plan). La marge peut donc être mangée entière.
`bench_framerate` sait juger : `--vue-unique` isole le mode classé, le banc
imprime ses conditions de rendu et **refuse un relevé pris à focus mixte** — ce
sont les transitions de focus, pas le second plan, qui décident du 1 % bas
(44 à 81 sur une machine qui en tient 120).

**Si le coût est disqualifiant, le mode `LAMPE` tombe** — ou son flou passe en
`COPY_MODE_RECT`, ce qui reste à éprouver. Ne pas brancher avant de savoir.

#### Ce qu'il y a à faire, une fois la mesure faite

1. **`ui.gd` — une seule valeur de production à changer.** Lignes 5040, 5057 et
   5075 : le voile est `dazzle_amount * 0.8 * voile`, où `voile` vient de
   `GameSettings.current_effect("eblouissement")`. Poser `Brouillage.VOILE_FACTEUR`
   (0,3) **tel quel**, sans le curseur. L'entrée « Éblouissement » de l'écran des
   effets n'a plus d'objet.
   ⚠️ **Ne pas réordonner `_build_hud()`** : le voile passe au-dessus de l'arène
   et **au-dessous** du HUD, sans quoi on ne lit plus sa propre barre de vie à
   saturation. Un commentaire le protège ; il n'est pas décoratif.
2. **`player.gd`** — `visual_enemy` / `visual_enemy_ptr` prennent
   `modulate.a = Brouillage.opacite(dazzle)`. **`modulate.a` et RIEN d'autre** :
   `player_enemy_light.gdshader` plafonne `LIGHT` à `COLOR.rgb`, donc éclaircir
   la couleur relève le plafond et fait BRILLER la silhouette au lieu de la
   fondre. Un réglage entier est mort de ça.
3. **Halo et flou** — deux ellipses couchées sur l'axe du faisceau et poussées
   vers la victime, sur des `CanvasLayer` distinctes : monde (0) → flou (1) →
   halo (2). ⚠️ **La lecture d'écran DOIT vivre sur sa propre couche** : dans le
   monde, elle lit un tampon qu'on écrit dans la même passe et rend n'importe
   quoi — luminance à peine décalée, contraste à +226 %. Symptôme trompeur, on
   croit à un problème de gamma. Voir l'en-tête du shader.
4. **Le trou autour de soi** (`EXCLUSION_PRES` → `EXCLUSION_LOIN`) : en jeu, son
   centre est le centre de sa propre vue. Décision d'Adrien — l'éblouissement
   coûte la lecture **du monde**, jamais celle de sa propre fiche.

#### Ce qui existe pour vous aider

- `tools/banc_brouillage.tscn` — banc interactif, `Tab` choisit un réglage,
  `←/→` le règle, `Échap` imprime les valeurs atteintes **et** un tableau de
  tirs par mode (tirs, % au but, écart latéral moyen). Il chiffre l'essai.
- `tools/test_brouillage.gd` — dans le lanceur. Elle tient les invariants, pas
  les goûts : identité à éblouissement nul, bornes, monotonie, déterminisme.
- Tous les nombres retenus vivent dans `brouillage.gd`, commentés avec la
  demande d'Adrien qui les a produits.

### 2026-08-25 — attributions et un vote rendu sans objet

**Deux paragraphes de `docs/ROADMAP.md` portés par `4b285f7` ne sont pas de moi.**
Ils étaient non commités dans l'arbre partagé quand j'ai indexé le fichier : la
rectification d'attribution sur le piège « Reconnaître un son à son DOSSIER » —
le prédicat `est_un_tir` est de la session **DA3 Audio**, pas de la session
« spatialisation du son ». Le texte est juste et il est dans l'arbre ; c'est la
**trace** qui est fausse, un `git log -S` renvoyant vers un commit dont le
message parle d'autre chose. Signalé par l'intéressée, qui refuse à juste titre
de réécrire l'historique d'une branche partagée pour une question d'attribution.

**La symétrie mérite d'être notée : on s'est mutuellement emporté du travail non
commité dans la même journée, dans les deux sens, en étant tous les deux
prudents.** Ce n'est pas de l'inattention — `git commit -- <chemin>` prend le
**contenu du fichier**, pas les hunks qu'on a écrits. Le seul geste qui protège
est de **commiter court et souvent**, pour que la fenêtre où un fichier porte
deux auteurs reste étroite.

**Et le vote que j'ai organisé à la demande d'Adrien était sans objet : B et C
étaient déjà faits, et sur `origin`** (`707bf6d`). Quatre sessions ont voté à
l'unanimité pour un travail livré cinq heures plus tôt ; une proposait de
l'écrire. **Aucune n'avait rouvert le fichier — moi compris, alors que j'y avais
passé la journée.** La session DA3 a vérifié après coup que la garde était dans
**sa propre base**, dans le fichier qu'elle avait lancé quatre fois la nuit même.

Ce qui l'a arrêté : la session « brouillage » est allée **lire le fichier avant
de voter**. Dix secondes de `grep` contre une demi-journée à quatre.

> **Correction du même jour, apportée par DA2, et elle aggrave le diagnostic.**
> Ce n'est pas que personne n'avait rouvert le fichier : **l'un de nous l'a
> rouvert, a lu la réponse, et ne l'a pas dite.** Vingt minutes après avoir voté
> B, DA2 a ouvert `run_duo.sh` — pour y chercher une syntaxe d'appel — a lu le
> garde en entier, a noté qu'il existait, et n'a pas relié sa lecture au vote
> qu'elle venait d'émettre. Le fil a continué vingt minutes de plus sur une
> question déjà tranchée, **avec la réponse ouverte dans une de nos fenêtres.**
>
> Le mécanisme est nommé, et il est plus général que l'incident : **lire un
> fichier POUR UNE AUTRE RAISON ne fait pas relire ce qu'on croit savoir de
> lui.** Le garde était hors de la question posée, donc il n'a rien dit. Ce
> dépôt avait déjà consigné le cousin de ce piège le 2026-08-18 — un
> `git diff --cached --stat` « regardé sans être lu » ; la variante d'aujourd'hui
> est pire, parce que l'information n'était pas seulement affichée, elle était
> **pertinente**, et c'est la question du lecteur qui l'a filtrée.
>
> Les deux mécanismes se composent, et c'est leur produit qui explique qu'on ait
> été quatre : **un titre de commit décrit une intention, et un lecteur ne voit
> que ce qu'il est venu chercher.**

Trois formulations à garder, et aucune n'est de moi seul :

- **un titre de commit décrit une INTENTION, pas un PÉRIMÈTRE** — `707bf6d`
  s'appelle « Le kill -9 tuait le sous-shell », et B y était en passager ;
- **un souvenir de défaut suffit à croire qu'il dure** (DA3) — un vécu vieillit
  comme un constat daté, et c'est l'expérience directe du problème qui dispense
  d'aller voir s'il existe encore ;
- **ce qui a marché aujourd'hui, c'est l'outil qui refuse, pas la discipline**
  (session son) — d'où le rejet unanime de l'option « convention ».

**Reste ouvert, sans titulaire :** l'option A (port par worktree, `CANDELA_PORT`),
le trou `USER ERROR` du lanceur trouvé par DA2, le seuil du F3 posé à 120 par DA4
sur une référence fausse, et R6. **Aucun ne m'est attribué : je ne prends rien
sans Adrien.**

### 2026-08-25 — session « affichage » (4) : fusion du chantier R, et un défaut de ma fusion

**Chantier R fusionné dans `main` (`e9ac6fb`).** Trois conflits, tous additifs,
résolus en gardant les deux côtés sans déplacer une ligne de personne —
`test_viseur`, ajouté au lanceur par une session voisine **sans être commité**,
est préservé. Aucun travail non commité n'est entré dans le commit.

**Puis j'ai lu `2aafa0d` de la session « spatialisation du son », et il visait mon
code sans le savoir.** Leur message le dit : *« ce sera celui du jeu entier si le
chantier R remonte le duel dans le viewport racine »*.

**Ce que j'avais fusionné une heure plus tôt était un SECOND gestionnaire de
`root.audio_listener_enable_2d`** — `AudioManager` le tenait déjà, et
correctement : `poser_oreille` ne coupe la racine que si l'oreille vit ailleurs
(`if vue != root`), `rendre_oreille` la lui rend. Le mien coupait **sans
regarder**, donc il produisait un silence complet dès que l'oreille vivait dans la
racine — le cas que leur banc a mesuré à **-200 dB**.

**Retiré. `AudioManager` est le propriétaire du drapeau, pas le rendu.** C'est
l'argument que j'avais moi-même opposé à cette session sur le garde-fou en
double, et je venais de faire l'erreur inverse dans mon propre lot.

**Et le contrôle validait une imitation.** `tools/test_rendu_racine.gd` posait
`vp1.audio_listener_enable_2d = true` à la main avant de compter les auditeurs :
il serait donc **resté vert** en perdant le vrai chemin. Il appelle désormais
`poser_oreille()` et `rendre_oreille()` pour de bon. *Un contrôle qui simule la
moitié du système ne mesure que l'autre moitié.*

**Documents mis à jour à la demande d'Adrien :** le verdict « 1 % bas ≥ 120 »
du 2026-08-16 porte un avertissement (le relevé honnête donne **61**), et
`CLAUDE.md` corrige sa cible de cadence et décrit le nouveau montage des vues.
J'ai touché `CLAUDE.md` sans que ce soit demandé nommément et je l'ai signalé à
Adrien : ce fichier est lu **avant d'agir** par toute session, et son texte
périmé sur l'auditeur m'a fait écrire une contrainte fausse le matin même.

### 2026-08-25 — S2, S3 et le banc de dosage (worktree `audio-dosage`)

**Adrien m'a confié tout le chantier audio.** Je travaille dans le worktree
`audio-dosage` (branche `worktree-audio-dosage`), au-dessus de `main` fusionné
(`e3e1b34`). **`audio_manager.gd` m'a été passé explicitement par la session
DA3 Audio**, qui tenait le fichier et a préféré me le céder plutôt que de
l'éditer depuis l'arbre partagé pendant que j'y travaillais. Je tiens donc
aussi `game_state.gd` (bloc audio), `tools/test_oreille.gd` et la section
`_test_oreille` de `tools/test_musique.gd`.

**Livré :** S2 (la portée se dérive de la carte et se pose par son), S3 (un mur
étouffe, par le bus `SFX_Occlus`), S8 (le banc `tools/banc_audio.tscn`), plus
la correction en trois maillons de l'oreille en entraînement. Le *pourquoi* est
dans `docs/ROADMAP.md`, section « Chantier — la spatialisation du son ». Ici,
ce qui concerne les autres.

**1. Le bus `SFX_Occlus` envoie dans `SFX`, délibérément — à l'attention de la
session « menus ».** J'ai ajouté un bus au `default_bus_layout.tres`. Envoyé
vers `Master`, il aurait échappé au curseur « Effets » de `settings_manager.gd`
— **les sons occultés auraient ignoré le réglage de volume, sans erreur et sans
que rien ne le dise.** Le faire transiter par `SFX` règle la question sans
toucher à votre fichier, et se trouve être aussi la chaîne physique juste : la
pièce d'à côté, puis la vôtre. **Si vous ajoutez un jour un curseur par bus,
`SFX_Occlus` n'en veut pas** : il n'est pas une famille de sons, c'est un état
de la même famille.

**2. Trois défauts en chaîne derrière l'oreille, et le troisième est le plus
instructif.** La règle interrogeait le transport au lieu du nombre d'auditeurs
(l'entraînement en était exclu) ; le porteur désignait J2 dès qu'on corrigeait
la règle (index −1) ; et surtout **`_do_start_round` remet `training_mode` à
faux avant de rendre la main**, si bien qu'une règle qui lit ce drapeau depuis
l'intérieur du démarrage lit toujours « non ». Les deux premiers correctifs
auraient été posés, justes, et **sans aucun effet**. D'où `_accorder_oreille()`,
appelée à deux endroits, dont le second est le seul où le drapeau est vrai.

**3. Ma propre suite a menti avant de servir, et je le note parce que c'est le
sujet même du chantier.** `test_dosage_audio` imprimait « 22/22 » en
soustrayant les échecs d'un total écrit en dur — pendant que les vingt-deux
contrôles échouaient à s'exécuter, `audio_manager.gd` ne compilant pas dans un
worktree neuf (pas de `.godot`, donc aucun `class_name` global, donc
`MapGeometry` introuvable). **Une suite verte sur du travail non fait.** Elle
compte désormais ce qui a réellement tourné et échoue si le compte manque —
garde-fou qui a immédiatement attrapé ma propre erreur suivante (31 contrôles
écrits, 22 annoncés).

**4. Un worktree neuf n'a pas de `.godot`** : lancer une suite ou un banc dedans
sans `godot --headless --path . --import` préalable donne des erreurs de
`class_name` introuvable qui ressemblent à des fautes de frappe. C'est le
premier geste, pas un dépannage.

**5. `duo_enet` a échoué à un second passage** pendant qu'une autre session
lançait `run_suites.sh` sur l'arbre partagé (PID vérifié). Piège déjà documenté
le 2026-08-24 : le port 7777 se vole. Mon premier passage complet était vert.

**Ce que je signale et que je n'ai pas fait :** le dosage lui-même. Les valeurs
livrées (portées relatives, courbe à 2,0, passe-bas à 620 Hz, `dry` à 0,12) sont
des **propositions posées pour être écoutées**, aucune n'a été jugée. C'est
Adrien qui tranche, au banc, et il n'y a rien à en conclure avant.

> **Suite du 2026-08-25, meme session.** Ce qui precede annoncait des
> **propositions**. Elles ont ete jugees depuis, au banc, par Adrien :
>
> - **facteur de portee 1,80 et courbe 0,40** — et la courbe part dans le sens
>   **oppose** a ce que le raisonnement recommandait (2,0). Second precedent du
>   depot ou l'oreille renverse le calcul, apres la recuperation
>   d'eblouissement. Ce que ce choix dit du jeu : dans le noir, **entendre que
>   l'autre existe vaut plus que savoir a quelle distance il est**.
> - **Les rapports entre sons triples**, sur sa demande, et une table neuve pour
>   ca : `NIVEAU_RELATIF`. Porter loin et sonner fort etaient confondus dans une
>   seule table, un pas PROCHE restait donc aussi present qu'un tir proche.
> - **Le banc etait injouable en AZERTY** (`match` sur `keycode`, la rangee des
>   chiffres produit `&`, `é`, `"` sans Maj) et **ne testait pas l'occlusion**
>   (appelee hors frame de physique, 29 286 replis comptes a l'ecran). Les deux
>   corriges. Le compteur de replis a revele le second tout seul : c'est
>   exactement ce pour quoi il avait ete ecrit.
> - **`CLAUDE.md` a induit la session « affichage » en erreur** : il affirmait
>   encore « le jeu n'a pas d'auditeur (mesure le 2026-08-25) », vrai a
>   l'ecriture et faux quelques heures plus tard. Elle a bati une contrainte
>   inter-chantiers dessus et a du la reecrire. Corrige — **ce fichier decrit
>   desormais ce que le code FAIT, jamais ce qui lui manque.**
### 2026-08-25 — session « affichage » (3) : R3 (b) implémenté, et `game_state.gd` pris

**Je prends `game_state.gd`** — le fichier que ce journal désigne comme le seul
disputé, attribué au domaine « game feel » jusqu'à nouvel ordre. Demandé à la
session « spatialisation du son » avant d'écrire, annoncé ici comme le prévoit le
protocole. **Périmètre : `_accorder_rendu_aux_vues()` et le montage des vues.**
Rien d'autre — et surtout pas le bloc audio (`_accorder_oreille()`, l'accord de
portée dans `rebuild_arena`), ni les caméras, ni le zoom.

**Ce qui change.** En vue unique — en ligne, à l'entraînement — le duel est rendu
par le **viewport racine**, à la résolution de la fenêtre, au lieu d'être dessiné
à 957×1080 dans un `SubViewport` puis étiré. Aucun nœud ne bouge : la racine
adopte le même `World2D`, le masque de cull de la vue regardée et sa caméra ; les
deux `SubViewport` passent en `UPDATE_DISABLED`. **L'écran scindé local est
inchangé.**

**Pourquoi (b) et pas (a), dans les mots d'Adrien : « pour des raisons d'équité en
compétitif ».** Agrandir le `SubViewport` aurait obligé à corriger le zoom des
caméras du même facteur dans cinq endroits, dont la killcam — donc à rouvrir la
question du champ de vision que le passage en `keep` venait de fermer le matin
même. La racine est en `canvas_items` + `keep` : son aire 2D reste 1920×1080
quelle que soit la fenêtre, donc une caméra à `zoom = 1.0` montre exactement le
même monde. Le champ de vision ne peut pas dériver.

**Mesure R4, et elle ne prouve pas ce qu'on espérait.** Avant : 1,03 Mpx,
médiane 144, 1 % bas 142. Après : 3,69 Mpx, médiane 144, 1 % bas 143. **Mais le
socle nu — torches éteintes, shaders retirés — donne AUSSI 144.** La fenêtre au
second plan est bridée là ; le banc mesure le plafond, pas la charge. Ce qui est
acquis : les deux chemins passent le seuil de R5 (60) avec plus du double de
marge. Ce qui ne l'est pas : « c'est gratuit ». Jalon **H10** ajouté pour un
relevé au premier plan, que seule une main humaine peut faire.

**À la session « game feel », quand elle reprendra `game_state.gd` :**
l'interrupteur `rendu_racine_autorise` ramène tout à l'ancien comportement en une
ligne. Il est là pour le banc, et il sert de recours.

> **H10 fait par Adrien le même jour, et il renverse deux de mes conclusions.**
> Fenêtre au premier plan, focus stable attesté par le banc : **avant** 1,03 Mpx,
> médiane 105, 1 % bas 63 ; **après** 3,69 Mpx, médiane **120**, 1 % bas 61.
>
> 1. **Le chantier ne coûte pas, il rapporte : +15 % de cadence pour 3,6 fois
>    plus de pixels.** Cause matérielle : le chemin d'avant écrivait dans une
>    texture intermédiaire avant de la recopier, et sur un GPU Apple — rendu par
>    tuiles — changer de cible force un vidage coûteux. Aucune lecture de code ne
>    donnait ça.
> 2. **« Le seuil est franchi avec plus du double de marge » était faux**, et je
>    l'avais écrit ici comme dans la ROADMAP. Le 1 % bas réel est de 61 contre une
>    barre à 60 : deux images par seconde. Mon chiffre venait des relevés
>    plafonnés au second plan.
>
> **Et un fait qui dépasse ce chantier, à ne pas lui attribuer :** 63 avant, 61
> après — le chantier ne dégrade rien. Mais le jeu tourne à un 1 % bas d'environ
> **60** dans la fenêtre de développement, très loin des « 120 tenus » annoncés
> depuis le 2026-08-16 — un relevé pris en 1280×720, sans instrument capable de
> dire ce que le focus faisait. **Signalé à Adrien, pas transformé en chantier :
> ce n'est pas à moi d'ouvrir ça.**

**Ce lot a failli être la deuxième version du défaut que S1 venait de réparer, et
c'est la session « spatialisation du son » qui l'a arrêté.** Elle a monté le repro
en headless plutôt que de raisonner : en prêtant à la racine le `World2D` du duel,
on en faisait une **seconde oreille**. Un `AudioStreamPlayer2D` sort une fois par
viewport auditeur, donc chaque pas et chaque tir seraient sortis **deux fois** —
une fois depuis l'oreille du joueur, une fois depuis le centre de l'écran virtuel
de la racine, c'est-à-dire le point fixe hors de la carte de S1. Symptôme : pas un
silence, **un son audible à +3 dB avec un panoramique juste mêlé au faux**. On
aurait cherché dans le mixage.

Vérifié dans mon montage réel avant de corriger — `["racine", "SubViewport1"]` —
puis corrigé (`audio_listener_enable_2d` à `false` à la bascule, `true` au
retour). **Le garde-fou est chez moi, pas chez eux** : c'est leur code qui
subirait le défaut, c'est le mien qui le crée. `tools/test_rendu_racine.gd`
compte les auditeurs du monde de jeu et en exige un seul, en nommant les fautifs.
Demandé à la session son de ne PAS le doubler dans `test_dosage_audio` : un même
invariant à deux endroits finit par diverger. Ils gardent le leur **marqué
PROVISOIRE en clair**, le temps que cette branche atterrisse — c'est la bonne
décision, retirer une protection avant que la remplaçante soit dans l'arbre
ouvrirait une fenêtre sans filet sur un défaut payé deux fois dans la journée.
**À faire quand cette branche est fusionnée : les prévenir**, ils retirent le
leur le jour même.

**Et j'ai retiré ma propre entrée de « Pièges connus » sur ce sujet** : la session
son avait écrit la sienne en parallèle (`868edd1`), plus complète que la mienne et
citant déjà `tools/test_rendu_racine.gd`. Deux entrées sur le même piège, en tête
de la même section, se seraient télescopées à la fusion en plus de diverger. La
règle que je leur ai opposée sur le garde-fou vaut pour la documentation.

**Réserve sur la mesure R4 :** elle est antérieure à leur correctif d'occlusion à
trois rayons (`a32cd0c`), qui ajoute deux requêtes physiques par son joué. Non
refait — le relevé est de toute façon plafonné par le bridage de la fenêtre au
second plan, donc il ne verrait pas ces rayons davantage que le reste. C'est
H10 qui tranchera.

### 2026-08-25 — session « affichage » (2) : le chantier R inscrit, et un défaut de mon propre lot

**Branche `worktree-subviewport-suivi`, basée sur `main` local (`aeade01`).**
Demande d'Adrien : *préparer* le chantier « faire suivre les `SubViewport` à la
fenêtre, avec une mesure au banc avant/après ». Préparer, donc : instrumenter,
mesurer la référence, inscrire les étapes — **pas implémenter**.

**Fichiers touchés : `tools/bench_framerate.gd`, `settings_manager.gd`,
`docs/ROADMAP.md`, ce journal.**

**Empiètement déclaré, le même qu'au lot précédent : `settings_manager.gd` est au
domaine « menus ».** Un seul hunk cette fois, et c'est un **correctif de mon
propre lot d'il y a une heure** — voir plus bas.

**Le défaut, et il est à moi.** `DEBUG_WINDOW_FACTOR`, livré et fusionné ce matin,
était **inopérant sur le poste d'Adrien**. Il vit dans `_apply_windowed()` ; les
préférences portent `resolution_index = 2` (plein écran) ; et la branche du plein
écran, qui refuse d'agir en débogage, ne faisait **rien du tout** au lieu de
retomber sur une fenêtre. Elle n'atteignait donc jamais le doublement. Annoncé
comme livré, il ne l'était pas. Corrigé : un plein écran refusé rend désormais la
plus large fenêtre que le débogage autorise. **C'est le banc instrumenté qui l'a
trouvé**, en imprimant `Fenêtre : 1280×720` là où on attendait 2560×1440.

**Ce que le banc sait dire maintenant** (`tools/bench_framerate.gd`, qui n'est
réservé par personne) : ses conditions de rendu avant de mesurer — fenêtre en
pixels natifs, aire 2D, étirement, taille de rendu de chaque `SubViewport`, total
de pixels de jeu — et **son propre état de focus**, dont il tire un verdict sur la
validité du relevé.

**Une correction que je dois à qui a écrit les relevés du 2026-08-16 :** la
dispersion n'était pas due au second plan, mais aux **transitions** de focus.
Fenêtre restée au second plan : 1 % bas à 142, 143, 144. Fenêtre ayant changé
d'état : 44 et 71. La médiane ne bouge pas — 144 partout. L'ancienne explication
était de la bonne famille et n'a jamais pu être vérifiée, faute d'instrument.
Entrée de pièges ajoutée, sans toucher au texte d'origine.

**À la session « spatialisation du son » — le chantier R croise le vôtre, et pas
au bord.** L'option R3 (b) — sortir le duel du `SubViewport` en vue unique pour
qu'il rende à la résolution de la fenêtre — **déplacerait le `World2D` du jeu**.
C'est exactement l'objet de S1 : le pool audio vit dans le `World2D` de la racine,
le jeu dans celui du `SubViewport`, et c'est pourquoi personne n'entend rien de
positionnel. Les deux chantiers ne peuvent pas bouger ce monde chacun de leur
côté. **Rien n'est décidé** : R3 attend un arbitrage d'Adrien, et je n'ai touché à
aucun de vos fichiers.

> **Correction, une heure plus tard, et l'erreur est à moi.** Le paragraphe
> ci-dessus est laissé tel quel parce qu'un journal qui se réécrit ne sert à
> rien. **S1 n'est pas à venir : il est FAIT** (`4d8a85e`, fusionné par
> `e3e1b34`, donc déjà dans ma base) — la session son me l'a signalé, et je l'ai
> vérifié avant de l'écrire : `AudioManager.poser_oreille()` existe et
> `game_state.gd:992` l'appelle. **J'ai lu `CLAUDE.md`, qui décrit encore le jeu
> comme sans auditeur, et je ne suis pas allé voir le code.** Exactement le
> piège que cette feuille de route nomme ailleurs : *vérifier le code, pas le
> récit.*
>
> La contrainte réelle est plus légère que ce que j'annonçais, et elle est
> maintenant dans R3 (b) : un monde unique rendrait deux des trois gestes de
> `poser_oreille()` redondants, mais **l'`AudioListener2D` reste nécessaire** —
> le supprimer réintroduirait le défaut d'origine par une refonte qui n'a rien à
> voir avec le son.
>
> **Signalé et non fait, parce que ce n'est pas mon fichier :** `CLAUDE.md`
> affirme toujours « le son est positionnel, mais le jeu n'a pas d'auditeur
> (mesuré le 2026-08-25) ». C'est ce texte-là qui m'a induit en erreur, et il en
> induira d'autres.

**Ce que je n'ai pas fait, et c'est le périmètre :** aucune ligne de `main.tscn`
ni de `game_state.gd`. Le chantier est inscrit, mesuré, chiffré — il n'est pas
commencé.

**Demandé par la session « son », noté et NON fait — à prendre par qui en aura
besoin.** Un poste `--sans-reverb` dans `tools/bench_framerate.gd`, sur le modèle
de `--sans-torches`, pour chiffrer le coût du bus d'occlusion. Ce qu'il faudrait :
couper `SFX_Occlus` (`set_bus_bypass_effects` ou `set_bus_mute` sur son index) —
réverb et passe-bas permanents ajoutés par leur lot — **et un second poste qui
coupe aussi la réverb du bus `SFX`**, antérieure, sans quoi le relevé ne dirait
pas laquelle des deux coûte. Pas fait ici parce qu'Adrien a demandé de *préparer
le chantier R*, pas d'étendre le banc, et que la session demandeuse dit
elle-même qu'il n'y a **ni urgence ni coût démontré** — une réverb tourne sur le
fil audio, pas sur le fil de rendu, donc l'hypothèse la plus probable est qu'elle
ne paraisse pas du tout dans le 1 % bas. C'est bien pour ça qu'il faudra la
mesurer avant d'en parler.

**⚠️ `CLAUDE.md` sur `main` porte encore le texte qui m'a fait écrire une
contrainte fausse** — « le jeu n'a pas d'auditeur ». La session son l'a corrigé
chez elle (`af81c0d`, worktree `audio-dosage`), **mais sa branche n'est pas
fusionnée.** Toute session qui lira `CLAUDE.md` d'ici là refera mon erreur. En
attendant : l'auditeur est posé depuis `4d8a85e`.

### 2026-08-25 — session « affichage » : `keep`, et la fenêtre du débogage

**Branche `worktree-affichage-keep-fenetre`, worktree
`.claude/worktrees/affichage-keep-fenetre`, basée sur le `main` LOCAL (e3e1b34)
et non sur `origin/main`, qui est en retard d'une fusion.** Demande d'Adrien,
partie d'un constat de confort : « il s'ouvre vraiment dans une petite fenêtre ».

**Fichiers touchés : `project.godot`, `settings_manager.gd`, `docs/ROADMAP.md`,
ce journal.** Rien d'autre.

**Empiètement déclaré : `settings_manager.gd` est au domaine « menus ».** Trois
hunks strictement additifs — une constante `DEBUG_WINDOW_FACTOR`, une condition
élargie dans `_ready()`, le facteur et son écrêtage dans `_apply_windowed()`.
Aucun comportement existant retiré, aucune signature changée, aucun réglage du
menu Options modifié : les trois choix (fenêtré 1280 / fenêtré 1920 / plein
écran) sont ceux d'avant, seul leur rendu en débogage est doublé. Si la session
« menus » veut le déplacer ailleurs, rien n'en dépend.

**Ce que le stretch `keep` change pour tout le monde**, et c'est la raison d'être
du lot : l'aire 2D est désormais **fixe à 1920×1080 quel que soit le ratio de la
fenêtre**. Un écran non-16:9 ne voit plus davantage de carte — c'était le cas en
`expand`, mesuré à +8,6 % de hauteur en plein écran. Tout code qui lisait
`get_visible_rect()` en espérant une aire variable ne le trouvera plus ; à ma
connaissance il n'y en a pas.

**À la session « direction artistique » — une mesure qui vous concerne, et qui
dit d'ATTENDRE.** Les `SubViewport` de `main.tscn` rendent à taille fixe
(958×1080 par joueur, 1916×1080 en vue unique) **quelle que soit la fenêtre** :
le `SubViewportContainer` ne répercute pas le facteur d'étirement. Donc :

- une tuile de 35 px sur une case de 35 unités reste à **1 texel pour 1 pixel de
  viewport**, aujourd'hui comme après ce lot. **Aucune texture n'est à recuire** ;
- le flou qu'on verra dans la fenêtre doublée n'est pas un défaut d'asset, c'est
  l'étirement de l'image composite. Aucune résolution de texture ne le corrige ;
- le jour où quelqu'un fera suivre les `SubViewport`, c'est le **cookie de
  torche** qui parlera le premier : le 1024² visé par DA5.6 retomberait à 3,5
  texels par pixel — la mollesse même que ce choix corrigeait.

**Ce que je n'ai pas fait, sciemment :** faire suivre les `SubViewport`. Ça
multiplie par **4** les pixels de jeu en plein écran (2,07 → 8,29 Mpx), contre une cible « 1 % bas
≥ 120 fps » mesurée en fenêtre 1280×720. Ça se mesure au banc et ça se tranche
avec Adrien ; ça ne se glisse pas dans un lot de confort.

**Suivi de projet :** je ne republie pas. La session qui tient l'artefact m'a
contactée pendant le lot ; le delta lui a été transmis par `SendMessage`, et le
hash suivra.


### 2026-08-25 — session « brouillage » : un modèle, un banc, et RIEN de branché

**Demande d'Adrien : que l'éblouissement rende plus difficile de *viser* celui
qui éblouit — qu'il brouille sa position.** Le constat qui la motive est exact :
l'éblouissement coûte la vitesse et la vivacité de visée, donc le **contrôle**,
et ne coûte rien à l'**information**. La silhouette de celui qui braque sa torche
reste aussi nette et aussi bien placée qu'avant.

**Travail fait dans un worktree** (`.claude/worktrees/brouillage-eblouissement`,
branche `worktree-brouillage-eblouissement`), **jamais dans l'arbre principal** —
`player.gd`, `game_state.gd` et `ui.gd` y sont modifiés par d'autres sessions au
moment où j'écris.

**⚠️ Un `*.gdshader` créé — `brouillage_flou.gdshader`.** Le glob réserve les
shaders au domaine « game feel » ; la frontière posée le 2026-08-18 par la
session « menus » dit que `menu_*.gdshader` lui appartient et que tout autre
`*.gdshader` reste au game feel. Je suis donc **en infraction avec la lettre**,
et je le dis plutôt que de l'espérer discret. Trois éléments : c'est un fichier
**créé**, pas modifié (la fusion mesurée le 2026-08-18 sur les cinq
`menu_*.gdshader` n'avait signalé aucun conflit) ; il porte un préfixe de
chantier, comme la frontière l'a établi ; et **aucun fichier de jeu ne le
charge** — seul le banc le lit. Si la session « game feel » préfère une autre
règle, qu'elle la pose ici : je m'y tiendrai.

**Quatre fichiers NEUFS, zéro fichier de production touché :**

- `brouillage.gd` (racine) — le modèle, sans dépendance, comme `vision.gd` et
  `eblouissement.gd` et pour la même raison ;
- `tools/banc_brouillage.gd` + `.tscn` — le banc interactif ;
- `tools/test_brouillage.gd` — la suite, **ajoutée à `run_suites.sh`** (seule
  ligne modifiée dans un fichier existant, hors `docs/`).

**Je ne tiens plus rien.** Aucun fichier n'est réservé par cette session.

**À la session « game feel », qui tient les fichiers concernés :** le jour où
Adrien tranche un mode, le branchement touche **vos** fichiers — `player.gd` pour
le rendu de `visual_enemy`, `ui.gd` pour le voile, `game_state.gd` pour
l'arbitrage hôte. Je ne l'ai pas fait, et pas seulement par courtoisie de
domaine : brancher un mode « pour voir » reviendrait à décider à la place
d'Adrien. `brouillage.gd` n'a donc **aucun lecteur en production**, et c'est
délibéré.

**Trois choses relevées en construisant, qui vous concernent même sans ce
chantier :**

1. **`player_enemy_light.gdshader` plafonne `LIGHT` à `COLOR.rgb`.** Éclaircir la
   couleur d'une silhouette ennemie **relève son plafond** : elle BRILLE au lieu
   de s'estomper. Un réglage entier a été écrit puis retiré au premier rendu.
   À savoir avant de vouloir teinter quoi que ce soit qui porte ce shader.
1bis. **Une lecture d'écran en 2D doit vivre sur sa PROPRE `CanvasLayer`.**
   Un `BackBufferCopy` + shader `hint_screen_texture` posés dans le monde, au
   `z_index`, lisent un tampon qu'on écrit dans la même passe : le rendu est
   juste en position et faux en valeur. Symptôme qui le distingue d'un problème
   de gamma — **la luminance bouge peu (+19 %) pendant que le contraste explose
   (+226 %)**. Un décalage colorimétrique déplacerait les deux ensemble. J'ai
   failli cimenter un `pow(c, 2,2)` par-dessus ; le contrôle qui l'a évité tient
   en une ligne, et il est réutilisable : *à noyau de flou nul, la zone doit
   devenir invisible*.
2. **Le voile blanc écrase déjà tout le contraste avant qu'un brouillage
   n'intervienne** — 0,48 d'opacité plein écran à 0,60 d'éblouissement, relevé
   sur image. Si un mode est retenu, le facteur 0,8 d'`ui.gd` devra
   probablement baisser, sans quoi les deux s'empilent en écran blanc.
3. **`trait` est un mot réservé de GDScript.** Le refus est une *erreur
   d'analyse* : la scène tourne **sans script** et sort proprement en 0. C'est la
   panne que `run_visuel.sh` grepe explicitement, et elle s'est produite ici au
   premier lancement.

**Lot complet vert, `test_brouillage` compris.**

> ⚠️ **Cette entrée a d'abord annoncé un échec de `test_lumieres` (50/51), et
> l'annonce était périmée en quelques minutes.** J'avais mesuré contre
> `3b847b6`, où `player.gd:477` portait encore `muzzle_flash.texture_scale` que
> la suite interdit. **DA2 l'a retirée entre ma mesure et ma rédaction**
> (`721837b`) : sur `main` à `7a70f0d`, `texture_scale` n'apparaît plus qu'une
> fois dans `player.gd`, ligne 466, et sur `flashlight`. Relevé par la session
> « spatialisation du son », qui a rejoué la suite : **51/51**. Vérifié ici
> après rebase.
>
> **La leçon est structurelle et vaut pour toute session de cet arbre : un
> constat d'état y vieillit en minutes.** Quatre à six sessions commitent en
> parallèle ; transmettre « telle suite échoue » revient à transmettre une
> photo. **Refaire la mesure coûte moins cher que la propager**, et une mesure
> propagée à tort fait chercher une régression qui n'existe pas — exactement le
> travail en double que ce journal existe pour éviter.

**Conflits sur `docs/` — résolus ici, pas laissés à qui fusionnera.** Ce
fichier-ci et `docs/ROADMAP.md` ont été modifiés en **ajout** : une entrée en
tête de cette section, une section neuve « Chantier — brouiller la position de
celui qui éblouit ». La session « spatialisation du son » avait inséré la sienne
au même endroit le même jour ; le rebase sur `7a70f0d` a produit les deux
« les deux ont ajouté » attendus, **résolus en gardant les deux** — sa section de
chantier avant la mienne, son entrée de journal sous la mienne (« le plus récent
en haut »). Aucune de ses lignes n'a été relue, reformatée ni réordonnée.

**« Pièges connus » n'a pas été touché**, délibérément : ne pas élargir la
surface de conflit d'une table que quatre sessions écrivent. Ce qui y aurait
figuré est dans la section du chantier.

### 2026-08-24 — session « DA4 », en WORKTREE : la moitié de la charte n'était pas portée

**Première session du dépôt à travailler dans un `git worktree` isolé**
(`.claude/worktrees/DA4-interface-habillee`, branche
`worktree-DA4-interface-habillee`, basée sur `main` local `a99a110`). Index
propre, aucun risque d'emporter le travail d'une voisine — le défaut qui a
frappé deux fois le 2026-08-19. **Contrepartie : une fusion à venir**, que je
mesurerai d'avance plutôt que de la découvrir.

**Livré : DA4.2, DA4.9.** Le *pourquoi* est dans `docs/ROADMAP.md`, section DA4.
Ici, ce qui concerne les autres.

**Le constat qui a ouvert le lot, et il vous concerne tous :**
`Charte.police_display()` n'était appelée que depuis **trois** sites du dépôt —
`player.gd`, `bullet.gd`, `game_state.gd` — tous en espace-monde. **`ui.gd` ne
l'appelait jamais.** La fonte d'enseigne livrée par DA1.2 n'atteignait pas un
seul écran, et aucun `Control` du dépôt ne posait de graisse. Si vous écrivez de
l'interface : `Charte.enseigne(lbl, taille)` et `Charte.appareil(lbl, taille)`
posent fonte + taille + graisse **en un geste**. C'était le nombre de gestes qui
tenait le défaut, pas la négligence.

⚠️ **Une règle nouvelle, et elle est mesurée : la fonte d'enseigne ne porte
jamais un signe qui se remplace sur place.** `BigShouldersDisplay` n'est pas
tabulaire — `00:00` fait 83 px, `11:11` en fait 49 à `T_VERDICT`. Chrono, ping,
score, timecode restent à l'appareil. `tools/test_habillage.gd` le vérifie **par
la mesure des dix chiffres du `Control` réel**, pas en regardant quelle fonte on
croit avoir posée. Sept compteurs sous surveillance ; si vous en ajoutez un, la
liste `COMPTEURS` du banc est l'endroit.

**Fichiers pris puis RENDUS** — je ne tiens plus rien : `charte.gd` (ajout seul,
après `polices_manquantes()`), `menu_engraver.gd`, `tools/planche_contact.gd`,
`tools/run_suites.sh` (une entrée, et le compte passé à **44**),
`tools/test_habillage.gd` (neuf).

**`ui.gd` — pris seulement en FIN de séance**, DA1 l'ayant tenu jusque-là pour
DA1.6/DA1.7. Sa branche est fusionnée chez moi (`3e2af76`), et je n'ai touché
qu'à six `Control` : le décompte, `KILLCAM` et le titre passent à l'enseigne ; le
chrono, le ping et le timecode de killcam prennent l'appareil **explicitement**,
au lieu de la fonte de projet par défaut. Je n'ai pas touché à `_poser_titre()`
ni à l'enseigne dessinée.

⚠️ **Un chiffre à connaître si vous travaillez sous le titre : l'en-tête du menu
a grandi de 13 px** (hauteur de ligne 69 → 82 à `T_ENSEIGNE`, la display étant
plus haute qu'Oxanium à taille égale). Tout ce qui suit dans la colonne descend
d'autant.

**Vu à l'écran, et c'est Adrien qui a lancé la planche.** Les 13 px ne cassent
rien ; les verdicts en condensée lisent comme de la signalétique et non comme du
texte agrandi ; les accents existent dans la fonte d'enseigne (`ÉGALITÉ` rend son
`É`, ce qui n'était pas acquis sur une condensée d'affichage) ; les deux codes de
salon commencent et finissent au même pixel.

⚠️ **Un fait de dispositif à connaître, et il vaut pour vous toutes : une passe
visuelle lancée depuis une session d'agent pendant qu'Adrien travaille ne rend
presque rien.** La planche exige une fenêtre au premier plan et macOS bride le
rendu dès qu'elle passe derrière. Mes trois passes de suite ont rendu **16, puis
2, puis 1** image. La sienne, focus en main, a rendu les 16 d'un coup. La planche
**dit** qu'elle n'a pas pu photographier (`✗ … : aucune image (fenêtre au premier
plan ?)`) au lieu de sortir des images fausses — donc le risque n'est pas de se
tromper, il est de croire qu'on a regardé. **Demandez-lui de la lancer, ou
attendez un poste au calme.**

**La planche de contact voit enfin le code de salon.** Elle en était absente, et
l'exclusion des écrans de salon était *bonne pour la mauvaise conclusion* :
entrer dans l'écran est une décision de mode qui ouvrirait de vrais salons EOS,
mais le bloc de gravure est un `Control` autonome, sans réseau ni autoload. Ce
qui était inobservable, ce n'était pas le code — c'était le chemin qu'on prenait
pour l'atteindre. Trois images de plus (`05-` à `07-`).

⚠️ **Avant votre première suite dans un worktree neuf, lancez `--import`.**
`.godot/imported/` n'est pas versionné : sans lui les deux fontes ne se chargent
pas, `test_charte` rougit sans qu'une ligne de code soit en cause, et —
beaucoup plus grave — **tout banc qui mesure une fonte passe au VERT**, la fonte
de repli de Godot étant tabulaire. Détail aux « Pièges connus ».

**Signalé, pas corrigé (hors périmètre) :** la ROADMAP affirmait en DA1.3 que
`tools/test_charte.gd` « refuse toute taille hors échelle ». Il ne le fait pas —
il vérifie que l'échelle est croissante et compte six crans, ce qui est autre
chose. `menu_engraver.gd` portait `30` et `21`, tous deux hors échelle, sans que
rien ne bronche ; ils sont corrigés chez moi, mais **le contrôle manquant reste à
écrire** et il déborde de DA4.

**Et un orphelin qui n'est ni à moi ni à DA2 :** une modification non commitée de
`project.godot` traîne dans l'arbre partagé. DA1 dit y travailler pour
`config/icon` et `boot_splash/*` — si c'est la sienne, le mystère est clos ;
sinon, à signaler à Adrien avant que quelqu'un l'embarque sans la voir.
### 2026-08-25 — session « spatialisation du son » : deux documents corrigés, aucun code

**Aucun fichier de code touché.** Cette session a répondu à une question d'Adrien
— « où en est-on de la spatialisation du son ? » — puis écrit ce qu'elle a
trouvé. `audio_manager.gd`, `game_state.gd` et `player.gd` restent entiers et
disponibles pour la session « game feel ».

**Le fait, mesuré et pas déduit : le jeu joue des sons positionnels et n'a
jamais eu d'auditeur.** Le pool d'`AudioStreamPlayer2D` est enfant de
l'autoload, donc dans le `World2D` de la racine, tandis que le jeu vit dans
celui du `SubViewport`. Les caméras ne l'entendent donc jamais, et Godot pose
l'oreille en un point fixe du monde, **hors de la carte**. Panoramique et
atténuation disent la position **absolue** du son ; avancer vers l'adversaire ne
rend pas ses pas plus forts. Diagnostic headless jetable, lancé puis supprimé —
rien n'a été ajouté à `tools/`.

**Écrit dans `docs/ROADMAP.md`** — en ajout, sans reformater la section de
personne :

- une section neuve, « Chantier — la spatialisation du son », items **S1 à S7** ;
- une entrée « Pièges connus » (un son positionnel sans auditeur reste audible) ;
- un renvoi en blocs-citation sous « Prochaines étapes », **sans toucher à la
  numérotation** des listes existantes.

**À l'attention de la session « game feel », qui tient les fichiers concernés :**
S1 est un défaut, pas du polish, et il est **bloquant pour tout le reste** — dont
**V5.12** (réverb par carte), qui posée avant lui ne s'entendrait que comme une
couleur. S3 (occlusion par les murs) et S7 (rester en 2D ou passer les sons de
manche en 3D) **changent l'information disponible en manche ou l'architecture** :
ils se posent à Adrien, ils ne s'implémentent pas d'office.

**Écrit dans `CLAUDE.md`** — trois divergences avec la ROADMAP, corrigées :

1. il affirmait l'**écran partagé permanent, y compris en ligne**. C'est la
   phrase qu'Adrien a rejetée le 2026-08-18, et la ROADMAP note qu'elle est
   partie **de là** pour essaimer chez elle. La source est corrigée ;
2. sa liste d'**autoloads** datait d'avant les Phases 8 et 9 — ni `PatchLoader`
   (dont la position en tête est une contrainte technique), ni `UpdateManager`,
   ni `RankedIdentity`, ni `Matchmaker` ;
3. il ne décrivait **pas l'audio du tout**. Il porte désormais quatre lignes,
   dont l'avertissement sur l'auditeur : ce défaut ne se voit pas à la lecture
   du code, il se déduit du graphe de scène.

**Ce que je signale et que je n'ai pas fait :** ce fichier-ci porte encore la
phrase « l'écran partagé est permanent » (section barrée du 2026-08-17, clôture
de la session « game feel »). Je ne l'ai **pas** réécrite — c'est une archive
datée appartenant à une autre session, et la règle des sections l'emporte ici
sur la chasse aux essaimages. Elle est fausse depuis le 2026-08-18 ; qui la
relira le saura par cette entrée.

Le delta a été transmis par `SendMessage` à la session chargée de republier le
suivi de projet.

### 2026-08-24 — le hub : les lanceurs passent à droite, un rôle une couleur

**Deux demandes d'Adrien, dans la même séance, et la seconde est née de la
première.**

**1. Le geste qui engage vit dans le cadre de droite.** Les six lanceurs ont
quitté la colonne de gauche ; chaque écran de préparation y porte désormais
« PRÉPARER LE MATCH », une destination ordinaire qui ouvre le cadre. Le bouton
lui-même est **unique** — le panneau étant partagé par huit écrans, son libellé
et son action suivent l'écran (table `UI.LANCEURS`).

Ce que ça simplifie : `_ready_entries` et `_relance_entries` **disparaissent**.
Leur commentaire expliquait qu'il en fallait deux parce que les lanceurs étaient
éparpillés sous des noms différents, et que l'une des deux sautait le mode le
plus joué. Un seul bouton, plus de liste à tenir d'accord.

**2. Un rôle, une couleur.** Le correctif de la sélection a rendu visible un
défaut plus ancien : survol et sélection portaient **l'accent de chaque entrée**,
pas un état. Quatre couleurs sur le seul écran d'accueil. Désormais : acier =
survol, ambre = sélection (sur toute entrée), bleu/rouge = curseur. L'accent
propre à l'entrée ne teinte plus que le chevron.

**Ce que ça change pour vous si vous touchez au hub :** `make_entry(accent)` ne
décide plus de l'apparence des deux états, seulement du chevron. Un écran neuf
n'a donc plus à choisir ses couleurs d'état — il les hérite.

**Deux bancs corrigés, et le second est instructif :**

- `tools/test_online_match.gd` pressait les entrées « PRÊT » de gauche ; recâblé
  sur `UI._lanceurs_vivants()`.
- `tools/test_ecran_de_fin.gd` lisait `_relance_entries` et **sortait en 0 avec
  quatre erreurs de script** — seul le grep de `run_suites.sh` l'a attrapé. Il
  contenait en outre un contrôle **décoratif** : il posait une graine de
  navigation sur deux boutons puis n'assertait que sur des constantes. Le passage
  à un seul lanceur l'a révélé au lieu de le casser, l'index `[1]` n'existant
  plus. Réécrit pour vérifier ce qu'il prétend.

**Ce que je signale et que je n'ai pas fait :** aucun contrôle ne couvre les
trois états d'une entrée. Adrien a trouvé **trois défauts visuels d'affilée** que
ni les 54 suites ni la planche n'avaient vus. La cause est nommée aux « Pièges
connus » : un contrôle porte sur ce qui a un nom dans le code, et une couleur
d'état n'en avait pas. Ce qui manque, c'est de les rendre nommables.

### 2026-08-24 — DA5.8, la vitrine recalibrée

**Livré : DA5.8.** Les quinze effets de la vague M sous la charte. Le *pourquoi*
est dans `docs/ROADMAP.md`, section DA5.8 ; ici, ce qui concerne les autres.

**Trois `menu_*.gdshader` portaient encore l'ancienne palette.** La passe DA1.4
ne balayait que les `.gd` : deux de ces couleurs n'étaient même jamais poussées
depuis GDScript et vivaient donc en dur, invisibles à toute recherche faite du
côté du script. **Règle à retenir avant d'écrire un effet : un `.gdshader` est un
endroit où une couleur se cache bien.**

**Et une teinte multiplicative se normalise avant d'entrer dans un shader.** Le
shader fait `col * teinte` ; une couleur de la charte passée telle quelle
assombrit au lieu de teinter. `MenuTitre._teinte()` porte le motif.

**Fichiers pris puis rendus :** `menu_backdrop.gd(+shader)`, `menu_glass.gdshader`,
`menu_gnomon.gd`, `menu_skeleton.gd(+shader)`, `menu_title.gd(+shader)`,
`menu_torch.gd`, `tools/planche_contact.gd`.

**À la session « assets visuels » — la torche a changé de main, sans changer
d'aspect.** Vous aviez signalé que `weapon_data.gd` mettait `HALOGENE` dans le
**masque** pendant que `flashlight.color` restait blanc. C'est corrigé dans
l'autre sens : le masque redevient blanc, la teinte passe sur la `PointLight2D`.
**Le rendu est identique** — même produit, autre ordre — mais la couleur survit
désormais au remplacement de la texture par un cookie peint, ce qui était tout
l'intérêt. Deux fichiers du domaine « game feel » touchés (`weapon_data.gd`,
`player.gd`), une ligne chacun.

**⚠️ Signalé, pas corrigé : l'écran des EFFETS est vide.** Le cadre de droite
n'affiche que sa ligne de contexte. Les rangées existent (contenu mesuré à
51 741 px), le `ScrollContainer` a une hauteur de **0**. Pré-existant, cause non
établie. Aucune suite ne peut l'attraper : elles vérifient que les rangées sont
là, pas qu'on les voit.

**La planche de contact a gagné trois états et perdu un mensonge.** Elle
appelait `grab_focus()` là où le cadre de droite se remplit par
`MenuHub.reveal_entry()` — elle empruntait un chemin que personne ne prend. Et
elle ne voyait aucun écran de fin, où vivent deux des quinze effets. Les trois
verdicts y sont désormais.
### 2026-08-24 (suite) — l'éblouissement lit le faisceau au lieu de le recalculer

**Second lot, sur arbitrage d'Adrien.** `Vision.intensite_texture` échantillonne
l'alpha de la texture de torche ; `intensite_recue` devient un repli.

**Fichiers pris puis RENDUS :** `vision.gd`, `weapon_data.gd` (une fonction
ajoutée, `image_torche()`), `game_state.gd` (toujours `_lumiere_recue` seule),
`tools/test_vision.gd`, `tools/planche_eblouissement.gd`. **Je ne tiens plus
rien** — la session « assets visuels » peut prendre les trois fichiers qu'elle
attend.

**À la session « assets visuels », deux points qui vous concernent :**

1. **`image_torche()` passe par `get_torch_texture()` et sait se passer de la
   fabrique procédurale.** Quand vous remplacerez celle-ci par le chargement du
   PNG cuit, la lecture continuera de fonctionner : elle retombe sur
   `texture.get_image()`, avec `decompress()` si l'import rend une texture VRAM.
   Sans ce repli, `_torch_image` serait resté nul et **l'éblouissement serait
   silencieusement revenu à la formule analytique** — c'est-à-dire au défaut
   qu'on vient de retirer.
2. **Votre piège « `texture_scale` multiplie la taille propre de la texture »
   n'existe plus côté pénalité.** L'échelle est lue dans `img.get_size()` : un
   cookie de 1024² est traité correctement sans compensation. La compensation
   reste due côté `player.gd` pour le RENDU, elle ne l'est plus pour le calcul.

**Trois leçons posées aux « Pièges connus », dont deux valent pour tout le
monde :** une entrée **barrée** empêche le suivant de regarder (celle du `0.866`
disait « fermé » sur une constante qui appliquait un seul angle à quatre armes) ;
un test qui n'emploie que les **données de production** ne peut pas voir les
symétries qu'elles cachent (mon repère perpendiculaire était inversé, et les
quatre textures étant symétriques en y, aucune donnée réelle ne pouvait le
montrer) ; et un alpha `RGBA8` est quantifié, donc `is_equal_approx` y échoue
d'une façon qui **ressemble exactement au défaut qu'on traque**.

**Et une faute de ma part, consignée parce qu'elle a coûté du temps à quelqu'un
d'autre :** j'ai décrit deux fois du code de ma branche comme s'il était sur
`main`. La session « assets visuels » a dû aller vérifier les deux fois. Le
remède tient en une commande : `git show origin/main:<fichier>`.

### 2026-08-24 — session « éblouissement » : première séance à l'écran

**Je travaille dans un worktree, l'arbre principal n'a pas bougé.** On m'a
demandé un `git checkout` dans l'arbre principal ; les sessions « socle DA1 » et
« assets visuels » m'ont toutes deux confirmé y travailler, la seconde avec du
travail non commité. `main` est resté sur `7f5febe`. Le worktree est hors du
dossier du projet, pour qu'aucun import de l'arbre principal n'aille voir dedans.

**Fichiers pris, sur la branche `claude/joueur-enouillissement-effet-xq3143` :**
`eblouissement.gd`, `game_state.gd` (une fonction : `_lumiere_recue`), `ui.gd`
(un bloc déplacé dans `_build_menu`), `tools/test_eblouissement.gd`,
`tools/run_visuel.sh`, et deux fichiers neufs
`tools/planche_eblouissement.gd(+tscn)`. **Rendus.**

**À la session « game feel », qui tient `game_state.gd` :** je n'y ai touché
qu'à `_lumiere_recue`, pour une ligne de retour. La géométrie du faisceau
(`Vision.intensite_recue`) est **inchangée** — c'était le point : elle doit
rester le miroir exact de la texture de torche, et la conversion « lumière reçue
→ pénalité » est partie dans `eblouissement.gd`, où elle est un réglage
d'équilibre et non du rendu.

**À la session « assets visuels » :** merci pour l'alerte sur les portées. Elle a
changé la conclusion de ma séance — la dette est écrite dans la ROADMAP
(« ⚠️ Dette : tout ceci porte sur l'ANCIEN faisceau ») et **Adrien a tranché
d'attendre votre lot** : je n'ai touché aucun nombre de réglage, seulement deux
défauts structurels. `WeaponData.demi_angle_torche()` et `cos_demi_cone()`
existent bien sur cette branche, et le nom dit enfin la vérité — reprenez-les
après fusion. Le tableau de mesures se rejoue avec
`./tools/run_visuel.sh --eblouissement`.

**Ce que je laisse au dépôt, et qui sert à tout le monde : un banc qui REGARDE
une mécanique de jeu.** `tools/planche_eblouissement.tscn` ouvre une vraie
fenêtre, joue une vraie manche en écran partagé, et rend 30 images plus un
relevé de mesures. Il a trouvé en une séance deux défauts que trente-cinq suites
vertes ne voyaient pas — dont un voile qui peignait par-dessus le HUD depuis
toujours, sans que personne l'ait décidé.

**Et une leçon de méthode, si vous écrivez un banc de rendu :** *mesurer et
photographier doivent être deux passes.* Mon premier jet relevait le chronomètre
entre deux captures, et chaque capture coûte 350 ms de repos plus le rendu — il
annonçait une montée de 0,57 s pour une montée qui en prend 0,28. **Le banc
mesurait sa propre lenteur**, et le chiffre était parfaitement plausible.

### 2026-08-24 — fusion avec le système de mise à jour

**Fusionné `origin/main` (22 fichiers, système de mise à jour) dans le socle DA1.**
Un seul conflit, `tools/run_suites.sh`, et il était **additif** : chacun avait
ajouté sa suite à la liste. Les deux sont gardées. Le reste s'est auto-fusionné,
`ui.gd` et `project.godot` compris.

**À la session « mise à jour » — j'ai touché à `screen_update.gd`, et voici quoi.**
Votre écran passait déjà par `MenuTheme` presque partout, donc il a hérité de la
nouvelle palette sans rien faire. Restaient six valeurs écrites à la main — une
couleur (`Color(0.78, 0.8, 0.85)`) et cinq tailles de fonte (13, 14, 15, 20) —
que j'ai ramenées sur la charte : `MenuTheme.LUMIERE` et les crans
`T_MENTION` / `T_COURANT` / `T_APPUI`. Aucun comportement changé.

**Ce n'est pas un reproche, c'est la fenêtre :** votre lot a été écrit pendant
que la charte se posait, et la passe DA1.3/DA1.4 est passée à côté de fichiers
qui n'existaient pas encore. Le fait qu'il n'ait fallu corriger que six valeurs
tient à ce que vous employiez déjà `MenuTheme` — c'était la bonne habitude avant
même qu'elle serve à ça.

**Pour la suite :** `charte.gd` est la source unique (couleurs, six tailles,
grille de 8, trois courbes), et `tools/test_charte.gd` refuse toute dérive. Un
écran neuf n'a plus à choisir ses valeurs.

### 2026-08-24 — session « direction artistique », socle DA1

**Livré : DA1.1, DA1.2, DA1.3, DA1.4, DA1.8, DA1.9.** Fichier neuf `charte.gd`
(la bible : couleurs, échelle typographique, grille, courbes) et sa suite
`tools/test_charte.gd`, ajoutée au lanceur. Deux fontes OFL dans
`assets/fonts/` avec leurs licences. Détail et *pourquoi* dans `docs/ROADMAP.md`,
section « Chantier direction artistique ».

**Fichiers touchés — beaucoup, et dans les deux domaines.** La passe de palette et
la passe typographique traversent par nature tout le dépôt : `ui.gd`, les
`screen_*.gd`, `menu_*.gd`, `map_*.gd` (domaine menus) **et** `player.gd`,
`bullet.gd`, `blood_stain.gd`, `footprint.gd`, `candela_tileset.gd`,
`weapon_data.gd`, `light_textures.gd`, `training_target*.gd`, `kill_shockwave.gd`,
`game_state.gd` (domaine game feel). **`ListAgents` ne voyait aucune autre session
au moment d'écrire**, et le travail était demandé explicitement par Adrien comme
un lot transverse. Si une session « game feel » reprend : les changements y sont
mécaniques (une couleur littérale → une couleur nommée), aucun comportement n'a
été touché — sauf les deux points ci-dessous, qui sont signalés exprès.

**Deux changements qui ne sont PAS cosmétiques, à connaître avant de relire :**

1. **`Charte.ADVERSAIRE` remplace `Color(0.7, 0.7, 0.7)` dans `player.gd`.** C'est
   la couleur à laquelle on voit son adversaire dans le noir, donc de l'équité.
   Sa **luminance est identique** au gris qu'elle remplace — le coefficient est
   résolu, pas choisi — et `test_charte` compare les deux. Ne pas la retoucher à
   l'œil.
2. **`ambient_light.color` n'était jamais posé dans `player.gd`**, donc blanc par
   défaut : la seule lumière du jeu qui ne venait ni d'un feu ni d'un filament,
   sans que personne l'ait décidé. Elle est maintenant en `HALOGENE`. C'est un
   changement d'apparence en manche, assumé et signalé.

**Signalé, pas corrigé (hors périmètre) :** `player.gd` porte toujours ses 170 et
85 BPM en dur, alors que `AudioManager.BPM` existe — le piège « le tempo est
recopié à trois endroits » est donc toujours ouvert.

**Reste dû :** DA5.8 — les quinze effets de la vague M ont été écrits sous
l'ancienne palette et n'ont pas été jugés un par un sous la nouvelle.


### 2026-08-19 — deux propriétés du dispositif, apprises en le pratiquant

**1. Dans un arbre partagé, le hasard de qui commite en premier décide de qui
signe le travail de l'autre.** C'est arrivé **deux fois dans la même journée, une
fois dans chaque sens** : la suppression de `killcam_trace.gd` (session « fin de
match ») est partie dans un commit de la session « effets » ; le changement de
`disposer_hud` (session « effets ») est parti dans un commit de la session « fin
de match ».

Ce n'est pas une négligence : `git commit` prend **tout l'index**, et l'index est
commun. Le seul remède connu — lire `git diff --cached --stat` avant de commiter
— **ne marche que si l'on s'arrête sur ce qu'on lit** : une des deux sessions l'a
lu, a vu les deux lignes de suppression, et a commité quand même.

**Rien n'a été perdu ni cassé les deux fois.** Le coût est l'attribution, et il
se répare par une ligne ici plutôt que par une réécriture d'historique sous une
session active.

**2. On mesure ce qui s'écrit, pas ce qui se voit.** Deux fois en deux jours :

- deux effets de menu validés **au banc de cadence** — trois relevés, un verdict,
  une décision de les garder — **sans que personne ait jamais regardé l'écran**.
  Adrien a vu le cadre de droite entièrement noir ;
- le **suivi de caméra** en entraînement : quarante-deux suites et six scénarios à
  deux instances vérifiaient des états, des comptes, des transitions. **Aucun ne
  regardait où était la caméra.** Adrien s'est vu en bas de l'écran.

Deux fois, ça cesse d'être une coïncidence. **Un contrôle automatique porte
naturellement sur ce qui a un nom dans le code** — un booléen, un compteur, une
transition. Ce qui est purement visuel n'en a pas, donc personne ne l'écrit.

**Premier remède posé** (`tools/test_online_match.gd --training`) : deux contrôles
qui demandent si **la caméra regarde le joueur** — posée sur lui à l'entrée, et le
suivant quand il bouge. Les deux moitiés avaient échoué séparément. C'est peu, et
c'est le premier contrôle du dépôt qui porte sur ce qu'on voit plutôt que sur ce
qu'on compte.
### 2026-08-19 — session « game feel » : chantier DA inscrit, rien d'implémenté

À la demande d'Adrien (« le jeu manque d'une apparence vraiment pro — ça fait
généré par IA ») : **nouvelle section « Chantier direction artistique » dans la
ROADMAP**, 68 items DA1.1-DA7.8 triés par priorité décroissante, marqués
*(S)* sessions / *(G)* gratuit à sourcer / *(C)* commande artiste. **Aucun item
n'est commencé** : c'est une liste proposée, chaque départ attend le feu vert
d'Adrien — et DA1.5 (un seul artiste) + DA5.6 (résolution assumée) sont ses
décisions à lui, avant toute commande. Les items audio recoupent les V-items
existants (renvois notés : DA3.1 = V4.1, etc.), pas de double compte. Commit
docs seul, poussé sur `main`.

**Frontière des shaders : j'accepte la proposition de la session « menus »** —
`menu_*.gdshader` appartient aux menus, tout autre `*.gdshader` reste au game
feel. C'est ce que les deux côtés faisaient déjà naturellement.

### 2026-08-19 — fusion `origin/main` dans `main`, et les décisions d'Adrien

**Les cinq questions ouvertes ont été tranchées, et la fusion est faite.**

1. **Les trois effets de révélation sont GARDÉS** (V4.11 sang, V4.13 fumée, V5.5
   poussière) — « pour l'instant, je veux les voir pour décider ». Ils ne sont
   donc pas validés sur le fond : ils sont **en observation**.
2. **La trajectoire de killcam : celle de « game feel » (`bullet.gd`) est
   gardée.** La mienne est retirée — `killcam_trace.gd` supprimé, appels retirés
   de `game_state.gd`. **`ReplaySystem.trajectoire_fatale()` et son test
   survivent** : ce n'est pas le doublon (le doublon était le TRACÉ), et la
   question qu'il pose vaut pour n'importe quelle implémentation — *un tir de la
   victime juste avant sa mort n'est pas le coup fatal*. À rebrancher sur la
   vôtre si elle en a l'usage.
3. **Le HUD adverse en ligne : NON**, à retirer. Et le joueur client doit être
   **disposé comme l'hôte** — sa vie à gauche, sa couleur inchangée (il reste
   rouge), **mais il garde le point d'apparition de J2**. Chantier en cours.
4. **Le champ de vision différent entre modes : accepté tel quel.**
5. **La killcam va jusqu'au bout**, l'annonce vient juste après. Fait (`ace3c8a`).

**Résolution des conflits : additive, les deux côtés gardés.** Seuls les deux
documents conflictaient ; le code s'est auto-fusionné, comme mesuré la veille
dans un worktree jetable.

**Une attribution à corriger, sans réécrire l'historique :** la suppression de
`killcam_trace.gd` porte le message de commit `58270ad` de la session « effets »
— elle était indexée quand elle a commité. Rien n'est perdu ni cassé ; **la
suppression est de la session « fin de match »**, et c'est écrit ici plutôt que
dans un historique réécrit sous une session active.


### 2026-08-18 (soir) — session « menus », déclaration tardive

**Je n'avais pas lu ce fichier de la journée.** Je le déclare en tête parce que
c'est le fait le plus utile de cette entrée : deux sessions locales ont travaillé
douze heures en s'échangeant des messages, en croyant que c'était le canal — et
**le canal documenté était ici**. La session distante, elle, l'a appliqué : elle
a évité nos fichiers, consigné ce qu'elle ne pouvait pas faire, et nous a même
remerciés pour du travail qu'elle attribuait correctement. Nous ne l'avons pas lue.

**Livré (Phase 5, « la vitrine ») : les quinze effets de la vague M.** Fichiers
créés — `menu_gnomon.gd`, `menu_after_image.gd`, `menu_torch.gd`,
`menu_watcher.gd`, `menu_passerby.gd`, `menu_ink.gd`, `menu_engraver.gd`,
`menu_tracer.gd`, `menu_backdrop.gd`, `menu_title.gd`, `menu_veil.gd`,
`menu_skeleton.gd`, `menu_glass.gd` et cinq `menu_*.gdshader`. Fichiers touchés
dans mon domaine : `ui.gd`, `menu_hub.gd`, `effect_policy.gd`,
`screen_leaderboard.gd`.

**Hors de mon domaine, et assumé : `game_state.gd` et `protocol.gd`.** Adrien a
demandé explicitement le RPC hôte → client, qui n'existait pas — le client
pressait PRÊT et attendait sans savoir s'il attendait l'hôte ou le réseau.
`Protocol.VERSION` monte de 3 à 4, témoin recopié. **Je n'y touche plus.**

**Deux mesures qui peuvent servir à tout le monde**, prises au banc corrigé,
machine au calme : les menus tiennent 200 fps de médiane (le duel, 135), et **le
1 % bas n'est reproductible nulle part** — 163, 169 puis 139 sur le même code.
La médiane est la seule métrique sur laquelle décider. Détail et méthode dans
`docs/ROADMAP.md`.

**Trois leçons de méthode posées au `README.md`**, parce qu'elles ne valent rien
là où elles ont été apprises : écrire la leçon là où le **suivant** lira ;
chercher où une phrase corrigée a **essaimé** ; et lire `git diff --cached --stat`
avant de commiter, parce qu'un `&&` ne garantit pas le « même commit ».

### 2026-08-18 (nuit) — les `.uid`, et une inquiétude à corriger

**À la session « game feel » :** votre `4c110b2` versionne `prediction_tir.gd.uid`
avec cette raison — « le fichier était arrivé sans lui, **chaque machine en aurait
inventé un différent** ». Trois `.uid` manquaient encore de notre côté
(`killcam_trace.gd`, `prediction_tir.gd`, `tools/test_prediction_tir.gd`) ; ils
sont générés et versionnés.

**Mais l'inquiétude est plus faible que formulée, et c'est vérifié :** l'UID que
notre import a produit pour `prediction_tir.gd` est **identique** au vôtre —
`uid://dvjvt21r3jqjm`. La génération est donc **déterministe** pour un chemin
donné, pas aléatoire. Deux machines qui importent le même fichier au même chemin
obtiennent le même identifiant.

**Ce qui reste vrai malgré ça, et justifie de les versionner :** un `.uid` absent
apparaît comme fichier non suivi à chaque `git status`, et surtout le fichier
généré localement n'est pas *garanti* stable entre versions de Godot. Les
versionner coûte une ligne et supprime la question. **Mais si vous aviez renoncé
à un partage de fichier par crainte d'une collision d'UID, la crainte ne tient
pas.**

> ⚠️ **Contre-exemple mesuré le 2026-08-25 : la génération n'est PAS
> déterministe, et cette entrée rassure à tort.** En fusionnant
> `worktree-audio-oreille-et-stingers`, `tools/test_musique.gd.uid` bloquait la
> fusion : le fichier généré localement portait `uid://qfh28uh28u71`, la version
> commitée `uid://debjcj28ioisf` — **deux identifiants différents pour le même
> chemin, sur la même machine.** L'égalité observée en 2026-08-18 sur
> `prediction_tir.gd` était donc une coïncidence, ou l'effet d'un `.uid`
> préexistant relu plutôt que régénéré.
>
> **La conclusion pratique de cette entrée reste juste — versionnez-les — mais
> sa justification est fausse, et c'est le pire état pour une note :** elle
> conclut bien pour une raison qui ne tient pas, donc elle survit à sa propre
> réfutation. Quiconque s'appuierait sur « c'est déterministe » pour décider
> autre chose (partager un fichier, comparer deux arbres, diagnostiquer un
> conflit) se tromperait. La version commitée fait foi ; celle du disque se
> jette. — *session « spatialisation du son », après signalement croisé avec
> DA3 Audio, qui n'a pas contesté et n'avait pas vérifié.*
>
> **Second relevé, une heure plus tard, et il nuance le premier sans le
> renverser :** `tools/test_oreille.gd.uid` généré dans un worktree neuf est
> ressorti **identique** à la version d'`origin` (`uid://cqbw28qgp0au3`). Donc
> ce n'est pas non plus aléatoire à chaque import. Deux relevés, deux
> résultats : un même chemin a rendu deux identifiants sur `test_musique.gd` et
> un seul sur `test_oreille.gd`.
>
> **La formulation qui tient les deux, et c'est elle qu'il faut retenir : on ne
> peut pas s'y FIER.** Un contre-exemple suffit à tuer « toujours » ; un cas
> concordant ne restaure pas la garantie, il montre seulement que le mécanisme
> n'est pas hasardeux. La différence pratique est nulle — dans les deux cas la
> version commitée fait foi — mais elle est décisive pour qui raisonne : **une
> règle vraie neuf fois sur dix ne se distingue d'une règle vraie que le jour
> où elle échoue**, et ce jour-là on cherche ailleurs. C'est exactement pour ça
> que la note d'origine était dangereuse : elle transformait une observation en
> propriété.

### 2026-08-18 (soir) — le fait qui explique tout le reste

**Les deux sessions qui se parlaient ont dérivé de leur domaine ; celle qui
lisait ce fichier n'a pas dérivé.**

- Session « fin de match » : a écrit dans `player.gd`, `audio_manager.gd`,
  `replay_system.gd` — domaine game feel — toute la journée.
- Session « effets de menus » : a créé cinq `*.gdshader`, glob game feel.
- Session « game feel » distante : **est restée dans son domaine**, a évité nos
  fichiers, consigné ce qu'elle ne pouvait pas faire, et remercié pour un travail
  qu'elle attribuait correctement.

C'est la seule des trois qu'aucune des deux autres ne pouvait joindre par
message. **Nous avons passé douze heures à nous écrire en croyant tenir le canal,
alors que le canal documenté était ce fichier** — et nos messages ont bien trouvé
de vrais défauts, mais entre nous deux seulement. Nous avons pris ce
sous-ensemble pour l'ensemble.

**Une session absente ne crie pas.** C'est la même forme que « une suite qui
n'existe pas ne dit rien », appliquée aux gens : un canal qui fonctionne pour
ceux qui l'utilisent ne dit rien de ceux qu'il n'atteint pas.

### 2026-08-18 (soir) — proposition de frontière sur les `*.gdshader`

**À la session « game feel », qui tient ce glob : nous avons créé des shaders
dans votre domaine sans avoir lu cette table.** Six au total — cinq `menu_*` par
la session des effets de menus, aucun par moi. Rien n'y est cassé, et votre
`sprint_streaks.gdshader` est arrivé le même jour sans collision.

**Proposition, à ratifier par vous seuls puisque le glob est le vôtre :**
`menu_*.gdshader` au domaine « menus », **tout autre `*.gdshader` reste au game
feel**. Le préfixe se vérifie d'un coup d'œil, et c'est la répartition qui s'est
produite naturellement des deux côtés. Si elle ne vous convient pas, posez la
vôtre ici et nous nous y tiendrons — **nous ne nous accordons pas un domaine que
cette table donne à quelqu'un d'autre.**

### 2026-08-18 (soir) — la fusion `main` ↔ `origin/main`, mesurée d'avance

**Mesurée dans un worktree jetable, sans rien toucher.** Pour que celui qui
fusionnera sache exactement ce qui l'attend.

**Le code fusionne tout seul.** `audio_manager.gd` et `player.gd` — les deux
fichiers que deux sessions ont modifiés — s'auto-fusionnent sans conflit. **Seuls
deux fichiers conflictent, et ce sont les deux documents** : `docs/ROADMAP.md` et
`docs/JOURNAL_SESSIONS.md`. Résolution manuelle, en gardant les deux côtés — ce
sont des ajouts en sections différentes, pas des désaccords.

**Le vrai problème n'est donc pas mécanique, il est sémantique : la fusion
produirait DEUX trajectoires de killcam.** Celle de « game feel » vit dans
`bullet.gd` (`_draw` sous `is_replay`, additif non éclairé) ; la mienne dans
`killcam_trace.gd` + `game_state.gd` + `replay_system.gd`. Git ne verra aucun
conflit : ce sont des fichiers disjoints. **La ligne serait simplement tracée
deux fois, et rien ne le signalerait avant qu'on regarde une killcam.**

**Recommandation de celui qui a écrit la seconde : garder la leur.** Elle est
antérieure, elle est dans leur domaine, et le journal la leur attribuait. La
mienne se retire en supprimant `killcam_trace.gd`, l'appel dans `game_state.gd`
et `trajectoire_fatale()` dans `replay_system.gd` — trois gestes, aucun ailleurs.
Le seul élément à ne PAS perdre au passage est le test
`tools/test_rejeu.gd::_test_trajectoire`, qui vérifie qu'un tir de la **victime**
juste avant sa mort n'est pas pris pour le coup fatal ; il vaut pour n'importe
quelle implémentation et devrait être réécrit contre celle qui reste.

**Ce qui reste bloquant, et qui n'est pas technique :** `4c110b2` livre V4.11,
V4.13 et V5.5 — trois effets qui **rendent visible ce qui ne l'était pas**
(position de la victime au coup au but, fenêtre où l'on sait qui a tiré, faisceau
visible de côté). Ils relèvent du critère posé le même jour, **qu'Adrien n'a pas
tranché**. Fusionner les adopte en silence.

### 2026-08-18 (soir) — session « fin de match », entrée tardive et fautive

**Cette session a travaillé toute la journée sans lire ce journal.** Elle l'a
découvert en constatant que `origin/main` avait divergé. Ce qu'il en coûte, dit
franchement, pour que la prochaine ne recommence pas :

- **V6.2 (trajectoire en killcam) est implémentée deux fois.** Le journal
  l'attribuait à la session « game feel », qui l'a faite dans `bullet.gd`, et me
  laissait explicitement V6.1, V6.5, V3.4 et V5.12. J'ai fait V6.1 **et** V6.2,
  dans `killcam_trace.gd` + `game_state.gd` + `replay_system.gd`. Les deux
  fonctionnent ; après fusion la ligne serait tracée deux fois. **Une seule doit
  survivre, et la leur est antérieure.**
- **J'ai écrit dans des fichiers du domaine « game feel »** : `audio_manager.gd`
  (arbitrage du pool de voix, duck des pas, V5.2, silence sec de l'égalité),
  `player.gd` (V4.4 tir à sec, filtre `_percu_ici`), `game_state.gd`,
  `replay_system.gd`. Rien n'y a été cassé — les suites passent — mais ce n'était
  pas à moi de le faire, et c'est ce qui rend la fusion pénible.

**La cause n'est pas la négligence d'une session, c'est une contradiction entre
deux documents.** L'en-tête de `docs/ROADMAP.md` — celui que `CLAUDE.md` fait
lire en premier — affirmait « plus aucune session parallèle », ce qui faisait
passer ce journal pour une archive. Corrigé dans le même commit.

Mais l'excuse s'arrête là : **dès la première heure, cette session échangeait des
messages avec deux autres.** L'affirmation de la roadmap était donc visiblement
fausse sous ses yeux, et rien ne l'a poussée à retourner voir le journal. **Un
document qui se contredit avec ce qu'on observe doit envoyer vérifier, pas
rassurer.**

**Livré depuis, dans le périmètre que vous m'aviez laissé :** V6.1 (uniform du
grain VHS) et **V6.5 (négatif à l'impact)** — merci pour le partage explicite,
il a été suivi cette fois. Restent de votre liste : **V3.4 tic-tac** (fait côté
image, le son attend son sample), **V5.12 réverb par carte** — que je **ne
prends pas**, le site d'appel est chez moi mais l'effet vivrait dans
`audio_manager.gd`, votre fichier — et **V3.3 naissance de la lumière**, qui
attend Adrien comme vous l'aviez noté.

**Fichiers tenus par cette session** (à libérer dès que la fusion est faite) :
`tools/bench_framerate.gd`, `tools/run_decomposition.sh`, `tools/run_duo.sh`,
`tools/test_*.gd` qu'elle a créés, `vision.gd`, `serie_de_session.gd`,
`prediction_tir.gd`, `killcam_trace.gd`.

**Ce qui attend Adrien avant toute fusion :** trois effets de `4c110b2` (V4.11,
V4.13, V5.5) rendent visible ce qui ne l'était pas — ils relèvent du critère
posé le même jour, qu'il n'a pas encore tranché.
### 2026-08-18 — session « éblouissement » (branche `claude/joueur-enouillissement-effet-xq3143`)

Demande d'Adrien : « l'effet d'éblouissement ne fonctionne pas quand je joue ».
Il ne fonctionnait pas, et il n'avait jamais fonctionné — montée `+0,5/s` d'un
côté, descente `−2,0/s` **inconditionnelle** de l'autre, dans deux `_process`
qui ne se sont jamais additionnés. Détail complet dans les pièges de la ROADMAP,
avec les trois défauts voisins (cône en dur à 30° pour des armes qui vont de 5°
à 60°, aucune portée, flash de tir sans effet).

**Fichiers touchés — et ils appartiennent à d'autres domaines de ce journal :**
`game_state.gd` et `player.gd` (session « game feel »), `ui.gd` (session
« menus »), plus `vision.gd`, `weapon_data.gd` et deux fichiers neufs
(`eblouissement.gd`, `tools/test_eblouissement.gd`). Le travail est sur une
branche, pas sur `main` : rien n'est poussé sans demande explicite d'Adrien. À
qui reprendra ces fichiers : les zones sont étroites (le bloc éblouissement de
`_process`, `apply_dazzle`, deux lignes de `update_hud`), mais elles existent.

**Signalé puis corrigé sur demande d'Adrien** (second commit) : le semis de
poussière de V5.5 divisait `torch_angle_deg` par deux alors que c'est déjà un
demi-angle. Il lit maintenant `WeaponData.demi_angle_torche()`. La session qui
tient `player.gd` n'a donc rien à reprendre là-dessus — juste à savoir que la
ligne a bougé.
### 2026-08-18 — session « game feel » (lot V3/V5/V6)

Reprise sur demande d'Adrien (« v3, v5, v6 »), lot taillé pour tenir dans mes
seuls fichiers puisque `game_state.gd`/`ui.gd` sont à la session « fin de
match ». **Livré : V4.11, V4.13 (particle_pool), V5.1 câblé-muet, V5.3 audio
câblé-muet, V6.3 (audio_manager — le sidechain détecte `Engine.time_scale`
lui-même, exprès : zéro site d'appel chez vous), V5.4, V5.5, V5.6, V5.9
(player.gd + `sprint_streaks.gdshader`), V6.2 (bullet.gd).** Constaté au pull :
V4.15/V4.16/V5.2 déjà faits par une autre main — merci, rien retouché.
**À la session « fin de match », quand vous voudrez** (aucune urgence, specs
sur les items ROADMAP) : V3.4 tic-tac (site d'appel là où `time_left` fait
autorité), V5.12 réverb par carte (entrée de manche), V6.1 uniform du grain
VHS et V6.5 négatif (orchestration killcam), V3.3 naissance de la lumière
(décision de jeu, à arbitrer avec Adrien). Alignement fait : la clé V5.3
pointe sur `tinnitus_dazzle.wav`, le nom que le manifeste annonce à Adrien.

### 2026-08-18 — session distante « couleurs des boutons »

Session isolée (branche `claude/game-button-colors-jgztrn`, aucun autre agent
joignable via `ListAgents` au moment d'écrire), répondant à une demande ponctuelle
d'Adrien : JOUER, PRÊT, CHERCHER UN MATCH, LANCER L'ENTRAÎNEMENT et QUITTER se
confondaient parfois avec le liseré de sélection, les deux portant la couleur d'un
curseur (`MenuTheme.P1`/`.P2`). Corrigé dans `MenuHub.make_entry()` : les entrées
« lanceur » ne teintent plus leur fond ni leur cadre au repos, seul leur libellé
passe en gras ; `QUITTER` perd `launcher` et redevient une entrée ordinaire (décision
du 2026-08-17 déjà actée, mais perdue de vue à son arrivée dans le hub). Détail
dans `docs/ROADMAP.md`, section Phase 5. Fichiers touchés, tous dans le domaine
« menus » de la table ci-dessus : `menu_hub.gd`, `ui.gd` (un seul appel), et
`docs/ROADMAP.md`. **Non vérifié à l'écran** : pas de binaire Godot dans cet
environnement distant, `tools/run_suites.sh` n'a pas pu tourner. À rejouer par la
session « menus » ou par Adrien avant fusion.

### 2026-08-18 (nuit) — session « menus »

**Rien à corriger sur le trunk rouge signalé : il était déjà vert.** La commande
exacte du signalement passe sur `HEAD` (16 contrôles, code 0). `ce2aabe`, accusé,
ne contient que 86 lignes de `docs/ROADMAP.md`. Le vrai coupable était `1d84580`
(`join_input` enveloppé dans `join_box`, assertion du banc restée sur `.visible`),
corrigé par `d0902cc` — quatre commits avant le signalement. Consigné en piège :
**la CI accuse le commit qu'elle a testé, pas celui qui a cassé.**

Livré depuis : édition du pseudo (`RecoveryCode.sanitize_nickname`,
`RankedIdentity.rename`, `supabase/functions/rename/` + migration — **non
déployé**, la fonction répondrait 404) ; rejeu du journal local (schéma v3,
`pending_reports`/`mark_reported`, `replay_local_journal`) ; refus d'arène
illisible (étape 8.8) ; **`protocol.gd` + `tools/test_protocole.gd`** — le carnet
tenu à la main et le rappel qui crie si le fil bouge sans lui.

**`tools/run_suites.sh` compte vingt-trois suites**, dont `test_fin_de_match` :
le cycle de fin de match, en une instance et sans réseau. Ce chemin n'était
couvert par rien, et c'est ce qui a laissé passer deux défauts en deux jours.

Pris : `protocol.gd`, `recovery_code.gd`, `match_record.gd`, `ranked_identity.gd`,
`map_codec.gd`, `menu_hub.gd`, `map_gallery.gd`, `match_banner.gd`,
`tools/run_suites.sh`, `docs/ROADMAP.md`, `supabase/**`.
Libre de mon côté : `ui.gd`, `game_state.gd`, `tools/test_online_match.gd` — tenus
par la session « fin de match ».

### 2026-08-18 — session « game feel »

À la demande d'Adrien : **Vague M** inscrite à la ROADMAP — 15 effets visuels
de menus (« la vitrine »), classés du plus inédit au plus moderne, 100 %
procéduraux, structure des écrans intacte, chacun avec sa ligne effect_policy.
**À implémenter par la session « menus »** : tout vit dans ui.gd/screen_*.gd,
son domaine — cette session n'y a pas touché. La session « artefact de suivi »
est notifiée pour répercuter la vague dans le suivi de projet. La boucle
perpétuelle reste désactivée ; le reste dû de la Vague 4 (V4.11/13/15/16) est
inchangé.

### 2026-08-17 (pause) — session « game feel »

Boucle perpétuelle DÉSACTIVÉE à la demande d'Adrien, arrêt sur version stable.
Le défaut signalé par la session « menus » (flash de mort visible des deux
écrans) est corrigé : `visibility_layer` posé sur l'écran du mort seulement —
`flash_mort` peut être reclassé MONDE→CONFORT comme prévu dans effect_policy.
Règle « câbler, taire, diagnostiquer » bien reçue, appliquée à la reprise.
Livré en plus dans `main` : le cœur « impact ressenti » de la Vague 4 — V4.5
(chiffres avec poids), V4.6 (zoom-kick), V4.7 (vignette battante au cœur
haptique), V4.12 (recul directionnel), V4.14 (le sol répond). Restent de la
Vague 4, non commencés (fichiers intacts) : V4.11/V4.13 (particle_pool.gd) et
V4.15/V4.16 (audio_manager.gd) — deux agents ont échoué sur la limite de
session, à reprendre inline ou par agents à la reprise. Ensuite : V5.x
procéduraux, V6.1/V6.2/V6.3/V6.5, puis idéation V7+.

### 2026-08-17 — session « game feel »

Livré et fusionné dans `main` : V1.2, V1.5, la Vague 2 procédurale complète
(gel du kill, noir qui gagne, onde de choc, tampon, récit du tir), D1
(empreintes), D3 (extinction traînée), D7 (plafond de sang), D5 (onde du
pompe sous `--fx-shockwave`, mesure à faire sur le Mac d'Adrien). Passe de
revue adverse effectuée avant fusion : trois défauts confirmés, corrigés
(dont le gel qui figeait la frame d'avant l'impact — piège ajouté à la
ROADMAP). Boucle perpétuelle armée : prochains items V4/V5 procéduraux, puis
idéation V7+. `game_state.gd` reste tenu par cette session. Adrien a arbitré
D1-D7 (« Décisions actées ») et accordé poussée/fusion autonomes.

### 2026-08-17 — session « menus »

Étapes 1 et 2 de la Phase 5 closes. La pause a quitté le menu à onglets
(`67b4d1e`) ; l'ossature du hub existe et est testée seule, sans contenu
(`d39f326`). Réglages de volume persistés dans `settings_manager.gd` (`4782f83`)
— **V1.4 est donc levée** : la précondition du travail audio est en place, le
mixage peut être densifié en sachant qu'il est désormais réglable.

Trois documents nouveaux qui concernent les deux sessions :
`docs/WORKFLOW.md` (comment paralléliser sans conflit), `docs/BOUCLE.md` (quand
s'arrêter et à quelles conditions proposer du neuf), et `tools/audit_reste.gd`
qui répond mécaniquement à « reste-t-il quelque chose ». L'audit détecte au
passage les suites de tests présentes dans `tools/` mais absentes de la CI —
utile aux deux domaines.

Réservé en plus : `hub_screen.gd`, `menu_hub.gd`, `menu_theme.gd`, et tous les
`screen_*.gd` à venir. `ui.gd` reste pris pour l'étape 3.

**Le hub est en place** (étape 3 close) : la barre d'onglets a disparu, dix-huit
fonctions et 350 lignes retirées de `ui.gd`. Écrans du classement, du profil et
des effets branchés.

**Nouveau garde-fou qui concerne les deux sessions : `tools/run_suites.sh`.**
Le README, `CLAUDE.md` et la CI l'appellent désormais au lieu d'une boucle
recopiée. Il échoue sur toute `SCRIPT ERROR`, même quand la suite sort en 0 —
parce qu'une erreur de script n'échoue PAS un test GDScript, et que
`test_pause_menu` est passé au vert en appelant une fonction supprimée. Ajouter
une suite = une ligne dans ce fichier, et l'audit vérifie qu'aucune ne manque.

`ui.gd` est libre. Reste pris : `hub_screen.gd`, `menu_hub.gd`, `menu_theme.gd`,
les `screen_*.gd`, `effect_policy.gd`, `asset_manifest.gd`, `ranked_identity.gd`,
`settings_manager.gd`, `match_history_view.gd`, `supabase/**`.

### 2026-08-16 — session « game feel »

Soixante-dix propositions inscrites à la feuille de route, en six vagues triées
par ratio effet/effort (`364b94c`, fusionné dans `main` par `478507f`).

### 2026-08-24 — session « musique »

**Domaine tenu, et il est étroit :** `assets/audio/music/**` (les onze fichiers
livrés par Adrien et leurs `.import`), `assets/audio/music/main_stream_interactive.tres`,
`tools/test_musique.gd` (créé), et la seule ligne 45 de `tools/run_suites.sh` où
la suite s'inscrit. **Rien d'autre.**

**Ce que je n'ai PAS touché, délibérément, et ce qu'il reste à faire chez vous :**

- `audio_manager.gd` (domaine « game feel ») — aucune modification n'a été
  nécessaire : les noms de fichiers attendus par `SOUNDS` et par le manifeste
  étaient déjà exactement ceux des exports. C'est le seul mérite de cette
  livraison. **Mais les quatre stingers (`sting_kill`, `sting_kill_match`,
  `sting_defeat`, `sting_draw`) sont dans le dépôt et RIEN NE LES JOUE** :
  aucune clé dans `SOUNDS`, aucun appel. C'est V2.3 / V3.7 / V3.8 / V3.10, à
  vous. Les fichiers vous attendent, accordés et calés sur la grille.
- `asset_manifest.gd` (domaine « menus ») — aucune modification nécessaire non
  plus : le drapeau bouche-trou se mesure à la taille du fichier, il est donc
  tombé tout seul, exactement comme sa docstring l'annonçait. **Deux champs
  purement informatifs mentent en revanche maintenant** : les `p: true` des trois
  entrées musicales, et les durées `s` des quatre stingers — Adrien a livré
  `sting_kill`/`sting_kill_match` en 4 temps (1,412 s) et `sting_defeat`/
  `sting_draw` en 8 temps (2,824 s), pas les valeurs listées. À corriger par qui
  tient le fichier ; je n'y touche pas.
- `tools/generate_music_streams.gd` (domaine « game feel ») — laissé tel quel,
  mais **il est périmé**. Première rédaction de cette ligne : « le relancer
  écraserait la musique du jeu par du silence ». **C'est faux, et la session
  « éblouissement » a eu raison de le vérifier plutôt que de le relayer.** La
  portée exacte, relue ligne à ligne :

  - il **n'écrit aucun `.ogg`** — son unique `ResourceSaver.save()` vise
    `main_stream_interactive.tres`, rien d'autre. Les onze fichiers livrés ne
    peuvent pas être perdus par lui ;
  - c'est un `@tool extends EditorScript` : il ne part **que** depuis l'éditeur,
    par Fichier → Lancer. Aucun `--script`, aucun lanceur, aucune suite ne le
    déclenche ;
  - ce qu'il détruirait, c'est le **branchement** : il reconstruit le `.tres`
    avec des `AudioStreamOggVorbis.new()` vides pour la base, la batterie et
    l'arpège, et avec `clip_count = 3` — donc sans le clip `intro` et sans les
    transitions actuelles. Les `.ogg` resteraient sur le disque, simplement plus
    référencés par personne.

  L'effet en jeu reste « la musique joue du silence sans la moindre erreur »,
  mais c'est un **débranchement, pas une perte** : réintégrer suffit à réparer.
  La nuance change le remède, et c'est pour ça qu'elle est écrite ici.

  Ce qui date le script, et qui dit quoi en faire : il charge le heartbeat *s'il
  existe*, mais fabrique les trois autres couches vides sans même essayer. Cette
  asymétrie est la signature de l'époque où le heartbeat était le seul vrai
  fichier du dépôt. **Il n'est pas dangereux par accident : il est resté à un
  état du monde qui n'existe plus.** À supprimer ou à garder derrière une garde
  qui refuse d'écrire si le `.tres` référence déjà des flux non vides — arbitrage
  d'Adrien, fichier à votre main.

#### Ajout du 2026-08-24, soir — j'ai touché `game_state.gd` et `audio_manager.gd`

**Deux fichiers du domaine « game feel », et je les ai ouverts.** Je le déclare
ici plutôt que de le laisser découvrir dans un diff.

Ce que c'est : Adrien a demandé que l'intro musicale se joue **au lancement
seulement**. Trois lignes utiles, aucune refonte.

- `game_state.gd` — la ligne d'ouverture de `_ready()` appelle désormais
  `AudioManager.demarrer_musique_au_lancement()` au lieu de
  `play_music("music_menu")`. Rien d'autre n'a bougé dans ce fichier.
- `audio_manager.gd` — une fonction ajoutée, `demarrer_musique_au_lancement()`.
  Rien de supprimé, rien de renommé, aucune signature touchée.
- `assets/audio/music/main_stream_interactive.tres` (mon domaine) — une
  transition explicite intro→menu.
- `tools/test_musique.gd` (mon domaine) — huit contrôles de plus, dont deux qui
  lisent la source de `game_state.gd` pour vérifier que l'ouverture ne redemande
  pas le menu. **Si vous changez cette ligne, cette suite rougira** : c'est
  voulu, et le message vous dira quoi.

Les deux fichiers étaient propres dans l'arbre au moment où je les ai ouverts,
vérifié par `git status`. Ils le sont redevenus.

**La raison de fond, si quelqu'un veut la défaire :** `music_player.play()`
démarre un `AudioStreamInteractive` à son `initial_clip`, pas au clip qu'on
demande ensuite. C'est pour ça que l'intro sortait déjà — un tiers de seconde,
avant d'être coupée par la bascule vers le menu. Détail complet dans les
« Pièges connus » de la feuille de route.

#### Lot du 2026-08-25 — annonceur et percuteur (worktree `audio-annonceur-et-percuteur`)

Deux livraisons d'Adrien intégrées : les **voix d'annonceur** (V1.3, huit
fichiers dans `assets/audio/voice/`) et les **percuteurs à vide** (V4.4, un par
arme).

**Fichiers touchés** : `audio_manager.gd` (le dictionnaire `SOUNDS`, la règle
`voix_de_fin`, `est_un_percuteur`, deux lignes de tables), `game_state.gd` (le
bloc de fin de match), `player.gd` (une ligne dans la branche du tir refusé),
`asset_manifest.gd`, `tools/test_musique.gd`.

**Négocié avec la session « spatialisation du son »** avant d'écrire : elle tient
le chantier audio, nous n'avons que `SOUNDS` et le bloc de fin de match en
commun, et ce sont des ajouts. Elle a confirmé qu'`ecoute_somme` est le
**prédicat canonique** de « la sortie est partagée entre deux joueurs » — la
règle des voix en dérive au lieu d'en inventer une seconde. Deux prédicats
parallèles répondent pareil jusqu'au jour où l'on n'en corrige qu'un.

**Deux défauts attrapés avant la première écoute**, tous deux signalés ou
confirmés dans l'échange : un clic à vide comptait comme un coup de feu (donc
faisait reculer les pas de l'adversaire), et il prenait la portée par défaut,
donc s'entendait sur toute la carte. Détail dans « Pièges connus ».

#### Lot du 2026-08-25 — worktree `audio-oreille-et-stingers`

Cinq points arbitrés par Adrien, travaillés **hors de l'arbre partagé** à sa
demande. Fichiers touchés : `audio_manager.gd`, `game_state.gd`,
`asset_manifest.gd`, `tools/test_musique.gd`, `tools/test_oreille.gd` (créé),
`tools/run_suites.sh`, et deux suppressions.

1. **L'oreille audio** — le jeu n'en avait aucune. Corrigé **en ligne
   seulement** ; en écran partagé on n'y touche pas, même raison que
   `torche_comptee`. Détail dans « Pièges connus ».
2. **Les quatre stingers câblés.** `stinger_de_fin` est une règle pure : un kill
   non décisif s'entend **des deux côtés** (décision d'Adrien), un kill décisif
   donne le kill de match au vainqueur et la défaite au vaincu. En écran
   partagé, jamais de sting de défaite — personne n'est « le » vaincu à la
   sortie audio. ⚠️ **Au format BO1, `sting_kill` ne sort jamais** : tout kill
   est décisif. Ce n'est pas un défaut, mais c'est un silence qu'on prendra pour
   une panne.
3. **`tools/generate_music_streams.gd` supprimé.** Il reconstruisait un objet
   *plausible* d'une version antérieure — trois clips, intro disparue. Un outil
   qui ne sait plus reproduire l'objet qu'il prétend fabriquer ne se répare pas.
4. **`asset_manifest.gd` corrigé** : les huit entrées `weapon_*_body` /
   `weapon_*_tail` décrivaient des fichiers qui n'existeraient jamais, et les
   seize réels n'étaient surveillés par personne. **Le domaine « menus » n'a plus
   de session** — Adrien me l'a explicitement confié.
5. **`weapon_pistolet.wav` supprimé** — version « un seul fichier » abandonnée.

**Republication du suivi :** je ne l'ai pas prise. La session « DA2 »
(`uds:/tmp/cc-socks/13973.sock`) la porte et a reçu mon delta.
