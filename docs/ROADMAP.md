# Candela 2D — Feuille de route

> **Document de référence du projet.** Toute session de travail le lit avant
> d'agir et le met à jour avant de conclure. Protocole de mise à jour : voir
> [README.md](../README.md).
>
> Dernière mise à jour : 2026-08-26
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
| 4 | **Supabase — compétitif / ELO** | ✅ **Terminée** — identité, matchs et classement déployés et vérifiés en production le 2026-08-16 |
| 5 | **Les menus** | ✅ **Terminée** le 2026-08-18 — six étapes closes. Ne restent que des vérifications à la main |
| 6 | Rangs (catégories et divisions) | ✅ **Terminée** le 2026-08-18 — rang affiché en jeu, plancher déployé, tout le monde démarre Aveugle I. Reste la vérification à deux identités |
| 7 | Déblocage d'armes par rang | ✅ **Mécanique terminée** le 2026-08-18 — table, grisage, miroir opérationnel, fenêtre de choix. **Manque du contenu, pas du code** : les catégories 5 à 10 ne débloquent rien |
| 8 | **Appariement** — amical, classé, recherche automatique | ✅ **Terminée côté code** le 2026-08-18 — recherche, bandeau, auto-lancement, fenêtre de choix d'arme, recul contre l'emballement des salons. Découverte croisée prouvée contre le vrai EOS. **Reste l'essai à deux fenêtres**, seule inconnue et humaine |
| 9 | **Mise à jour du jeu installé** | 🟡 **Écrite le 2026-08-24** — bouton dans le menu, manifeste signé publié par la CI sur tag, remplacement de bundle et correctif `.pck`. **Deux jalons humains avant qu'elle serve** : la paire de clés (H8) et la première installation réelle (H9) |

Les phases 5 à 7 forment une chaîne : les rangs ont besoin d'écrans, les armes
verrouillées ont besoin des rangs. L'ordre n'est pas négociable sans faire le
travail deux fois.

---

## Phase 2 — P2P hôte-autoritaire ✅

Neuf étapes numérotées, toutes terminées et fusionnées dans `main`.

1. **Autorité hôte intégrale** (`a73128c`) — l'hôte simule les deux joueurs, le
   client n'envoie que ses commandes numérotées.
2. **Prédiction & interpolation** (`d448fcd`) — le client prédit son propre
   joueur et corrige sur l'input acquitté ; l'adversaire est interpolé depuis un
   tampon horodaté (100 ms de retard, extrapolation ≤ 50 ms).
3. **Tir client immédiat** (`33d537c`) — balle prédite localement, dédupliquée à
   l'arrivée du tir officiel.
4. **Équité réseau** (`33d537c`) — ping par écho applicatif, compensation de
   latence (historique 400 ms, recul RTT/2 + retard d'interpolation, plafonné à
   200 ms), chronomètre recalé par l'hôte.
5. **Lobby lisible** (`33d537c`) — décompte 3-2-1 partagé, statuts en langage
   joueur, IP copiable.
6. **et 7. Durcissement des transitions** (`399d736`) — jeton de séquence sur la
   fin de manche, pause sans gel d'arbre en ligne, événements différés pendant
   la killcam, `time_scale` rétabli sur toutes les sorties.
8. **Format de match BO1** (`42f6c87`) — 5 minutes, écran VICTOIRE/DÉFAITE,
   score de session, archivage dans `user://match_history.json`, cible
   d'échauffement.
9. **Passe de performance** (`42f6c87`) — réserve de particules (coût
   d'émission −44 %), shaders préchargés en `.gdshader`, panneau F3 enrichi.

**Reste dû sur la Phase 2 :** la checklist manuelle
[CHECKLIST_TESTS_EN_LIGNE.md](CHECKLIST_TESTS_EN_LIGNE.md) n'a jamais été
déroulée à deux instances, et la validation à 120 ms de latence simulée non
plus. Sera absorbé par le test à deux machines de la Phase 3.

---

## Phase 3 — EOS (connectivité) ✅

**Objectif :** que deux joueurs quelconques sur Internet se rejoignent par un
code, sans configuration, sans redirection de port.

### Fait

- **Plugin EOSG validé** (Godot 4.7.1, EOSG 2.3.0, SDK EOS 1.19.1.2, binaires
  macOS universal). Init, login Device ID, lobby, P2P : tous fonctionnels.
- **Transport interchangeable** — `network_manager.gd` expose `Transport.EOS`
  (défaut en ligne) et `Transport.ENET` (LAN/debug, intact). Aucun autre fichier
  ne connaît le transport, hors bloc lobby de `ui.gd`.
- **Lobby par code** — 6 caractères, alphabet sans I/O/0/1, publié en attribut
  de lobby, jointure par recherche filtrée `bucket_id ET code`.
- **Identité éphémère de test** (`--eos-ephemeral`) — le Device ID Epic étant
  lié à la machine, deux instances locales partageraient sinon le même PUID.
  Neutralisée hors build debug, bandeau d'avertissement à l'écran.
- **Export macOS non signé validé** — `.dylib` embarqué, EOS opérationnel dans
  le `.app` (PUID obtenu), sortie 0. Préréglage versionné dans
  `export_presets.cfg`.

  **Piège de diagnostic, à ne pas retomber dedans :** dans un build release, la
  sortie `print()` est tamponnée et n'est vidée qu'à la **fermeture propre** de
  l'application. Tuer le processus (`pkill`, Ctrl-C) jette tout ce qui suit le
  dernier message d'erreur — ce qui a fait conclure à tort, le 2026-08-16, à un
  EOS qui ne démarrait pas dans l'export. Pour lire le journal d'un build :
  `open build/Candela.app`, puis `osascript -e 'quit app "Candela 2D"'`, et lire
  `~/Library/Application Support/Godot/app_userdata/Candela 2D/logs/godot.log`.
- Bancs d'essai : `tools/test_transport.tscn`, `tools/test_online_match.tscn`,
  `tools/test_quit_path.tscn`. Protocole :
  [PROTOCOLE_TEST_EOS.md](PROTOCOLE_TEST_EOS.md).
- **Réglage vsync / plafond d'images par seconde** — menu Options (onglet
  Contrôles), persisté dans `user://settings.cfg` via `GameSettings`
  (`settings_manager.gd`, nouvel autoload). Défaut : vsync désactivé, aucun
  plafond. Mesure avant/après sur `tools/test_transport.tscn` (deux instances
  locales, `CONNECTION_TYPE: DIRECT`) :

  | | 60 fps plafonné | Déplafonné |
  |---|---|---|
  | RTT_MIN_MS | 46,0 | 13,3 |
  | RTT_AVG_MS | 49,7–50,3 | 22,3 |
  | APP_RTT_MS | 48,8 | 23,9–24,2 |

  Confirme la décision actée plus bas : le plancher de RTT EOS suit la cadence
  d'image, pas le SDK. Mesure indépendante sur le même banc, autre session :
  59,0 ms de moyenne à 60 fps contre 21,2 ms déplafonné (145 fps en headless).

- **120 fps tenus en `gl_compatibility`** — vérifié sur un rendu réel fenêtré
  avec `tools/bench_framerate.tscn` : écran partagé (les deux vues rendent),
  pompe contre pompe à bout portant, torches allumées, HP maintenus pleins pour
  que l'échange ne s'arrête jamais. Pic de 123-125 particules sur 200 et 12
  balles simultanées, donc la charge est réelle et non supposée.

  | Exécution | FPS médian | 1 % bas | Minimum |
  |---|---|---|---|
  | 1 | 156 | 123 | 116 |
  | 2 | 160 | 137 | 137 |
  | 3 | 145 | 144 | 144 |

  > **⚠️ CE TABLEAU NE MESURE RIEN, constaté le 2026-08-18.** Le banc de
  > `9d69f09` échantillonnait `Engine.get_frames_per_second()`, **mis à jour une
  > fois par seconde** : ces « 1 % bas » sont des moyennes secondes, pas des
  > images lentes. La signature est dans les chiffres eux-mêmes — exécution 3 :
  > médiane 145, 1 % bas 144, minimum 144, trois valeurs quasi identiques, ce
  > qu'un vrai percentile ne produit jamais.
  >
  > **Conséquence : la cible de 120 fps n'a JAMAIS été vérifiée comme atteinte.**
  > Ce n'est pas « le jeu tenait et ne tient plus » — c'est « on ne savait pas ».
  > La première mesure honnête, le 2026-08-18 sur le banc corrigé, donne un
  > 1 % bas de **97** (journal en fin de document). Le verdict ci-dessous est
  > conservé tel qu'il a été écrit, parce qu'un document qui efface ses erreurs
  > n'apprend rien à celui qui le lit ensuite.

  **Verdict (2026-08-16, sur mesure creuse) : tenu.** Le 1 % bas — ce que le
  joueur ressent comme saccade — reste au-dessus de 120 sur les trois
  exécutions. À dire honnêtement : le
  minimum absolu est descendu une fois à 116, et la dispersion entre exécutions
  (145 à 160 de médiane) vient de la fenêtre elle-même, que macOS bride quand
  elle n'est pas au premier plan. Mesuré sur **Apple M3**, fenêtre 1280×720 :
  une machine plus modeste demandera sa propre mesure.

  > ⚠️ **Ce verdict ne décrit plus le jeu — relevé du 2026-08-25, chantier R,
  > jalon H10.** Fenêtre 2560×1440 au **premier plan**, focus stable attesté par
  > le banc : **1 % bas de 61 en vue unique**, et 63 sur l'ancien chemin de
  > rendu. Pas 120. Le chantier R n'y est pour rien — les deux chemins donnent
  > le même chiffre à deux images près.
  >
  > **Deux choses ont changé depuis, et aucune n'est une régression de code.**
  > La fenêtre a doublé (1280×720 → 2560×1440, décision du 2026-08-25), donc le
  > viewport racine est passé de 0,92 à 3,69 Mpx. Et surtout, **le banc sait
  > maintenant dire ce que le focus faisait** : la dispersion « 145 à 160 »
  > attribuée ci-dessus au second plan venait en réalité des **transitions** de
  > focus, et un relevé contaminé donne un 1 % bas de 44 à 81 sur une machine
  > qui en tient 120. Le verdict de 2026-08-16 a pu être pris dans l'un ou
  > l'autre état ; rien ne permet de le savoir, puisque rien ne le mesurait.
  >
  > **Ce qu'il faut en retenir : le chiffre affiché en tête de ce document —
  > « cible : 1 % bas ≥ 120 fps » — n'est plus un constat, c'est un objectif.**
  > Adrien a abaissé la barre à **60** le 2026-08-25 (chantier R, étape R5), et
  > le jeu passe cette barre-là de deux images par seconde. **Savoir s'il faut
  > remonter vers 120, et à quel prix, est une décision qui n'a pas été prise.**

- **Préférences persistées** — vsync, plafond d'images par seconde, résolution
  et remappage des touches vivent dans `user://settings.cfg`, sectionné
  (`video` / `display` / `input`), appliqué au démarrage par l'autoload
  `GameSettings`. Celui-ci est déclaré **après** `InputSetup` dans
  `project.godot` : c'est ce qui permet aux liaisons enregistrées de recouvrir
  les liaisons par défaut, et non l'inverse. Le remappage ne retire que les
  événements de manette, jamais le clavier ni la souris.
  Au passage, `anti_aliasing/quality/msaa_2d=2` a été retiré : inopérant sous
  `gl_compatibility` (« 2D MSAA is not yet supported for GLES3 » à chaque
  démarrage), c'était un réglage mort.

### Validation finale — 2026-08-16 ✅

Quatrième session à deux machines : commandes, déplacements, tirs, dégâts et
killcam fonctionnent des deux côtés. **La Phase 3 est close.**

Réglage de confort passé au même moment : la torche des fantômes est plafonnée
à la moitié de son intensité de jeu pendant la killcam
(`KILLCAM_TORCH_ENERGY`). À pleine puissance le halo passait par-dessus la
balle, qui est pourtant le sujet de la séquence.

### Traversée de NAT — validée le 2026-08-16 (jalon H1) ✅

Test à deux Mac, trois configurations : même Wi-Fi ; un poste en partage de
connexion ; **les deux postes en partage de connexion, sur deux opérateurs
différents**. Dans les trois cas, `Lien DIRECT`, NAT modéré, ping 58 ms,
160 fps. Le punchthrough d'EOS passe donc même dans le scénario réputé le plus
dur, sans redirection de port ni configuration.

Nuance à garder : **le relais Epic n'a jamais été exercé**, la connexion
directe ayant toujours abouti. Ce chemin de repli reste donc non testé.

### Défauts relevés pendant H1 — tous corrigés

- ~~**Salon fantôme.**~~ **Corrigé** (`313e33e`). L'appartenance à un salon EOS
  survit à la rupture du lien P2P : l'invité parti restait compté, le salon
  demeurait à 2/2 et refusait réellement la jointure suivante, pendant que
  l'hôte affichait « en attente du joueur 2 ». `_on_peer_disconnected` ne
  réarmait que l'acceptation des demandes P2P. Le plugin n'exposant aucune
  expulsion, l'hôte **reconstruit** son salon au départ d'un pair, en conservant
  le code déjà communiqué. Au passage, le message « introuvable ou déjà
  complet » couvrait deux causes opposées : un salon vraiment plein annonce
  désormais son occupation chiffrée, un refus d'Epic le dit et invite à
  réessayer.
- ~~**Killcam muette.**~~ **Corrigé.** L'enregistrement n'était pas en cause
  (3 évènements relevés des deux côtés) : la fenêtre de rejeu démarrait à
  `snapshots.size() - 240`, donc calée sur la **fin de l'enregistrement** — or
  celui-ci continue après la mort, le temps de capter le sang. Le tir fatal
  tombait avant le début de la fenêtre et n'était jamais rejoué. La fenêtre se
  cale désormais sur l'impact, et recule au besoin pour englober le tir fatal.
  Le défaut touchait les deux camps, pas seulement l'invité.
- ~~**Jointure : recherche unique.**~~ **Corrigée.** L'hôte renonce parfois à
  confirmer la visibilité de son code et l'annonce quand même (« publié sans
  confirmation de l'index Epic ») ; la recherche unique côté client échouait
  alors sur un code pourtant valide. Trois tentatives espacées désormais.

### ~~Ouvert~~ **Corrigé** — les commandes du client n'atteignaient pas l'hôte

Constaté au second test à deux machines (2026-08-16), corrigé le jour même.

**Symptôme.** Chez l'hôte, J2 restait figé sur son point d'apparition et ses
tirs n'infligeaient rien. Chez le client tout paraissait normal : il se voyait
bouger, voyait l'hôte, tirait et voyait ses impacts — tout cela étant prédit
localement.

**Ce que la mesure a établi**, en trois manches d'instrumentation :

| Relevé | Verdict |
|---|---|
| `Lien DIRECT`, ping 26–47 ms des deux côtés | Le transport fonctionne, dans les deux sens |
| Hôte : `reçues=0 rejetées=0` | La fonction n'est **jamais exécutée** — rien n'est filtré |
| Client : `envoyées=3411 visé=1` | Le client émet bien, vers le bon destinataire |
| `moi=1437910812` = `pair=1437910812` | Les identités de pairs concordent |
| `CHEMIN J2` : `@CharacterBody2D@269` chez l'hôte, `@263` chez le client | **La cause** |

**La cause.** Les nœuds Joueur étaient ajoutés à l'arbre **sans nom explicite**.
Godot en fabrique alors un depuis un compteur global d'objets créés
(`@CharacterBody2D@269`), dont la valeur dépend de tout ce qui a été instancié
avant — jusqu'au **nombre de cartes** dans la bibliothèque, la galerie
construisant un panneau par carte. L'hôte avait 3 cartes, le client 2 : deux
noms différents pour le même joueur.

Or un RPC de scène ne se route **que** par le chemin du nœud. Les commandes du
client désignaient chez l'hôte un nœud inexistant et étaient jetées sans le
moindre message — console à zéro erreur. Le ping, lui, passait : il vit sur
`NetworkManager`, un autoload au chemin fixe par construction.

**Le correctif.** `_setup_players()` et `_setup_ghosts()` nomment désormais
explicitement tout ce qu'ils ajoutent (`Player1`, `Player2`, `Camera1`,
`Camera2`, `GhostP1`, `GhostP2`).

**Pourquoi aucun test ne l'avait vu.** Deux instances sur la même machine
partagent la même bibliothèque de cartes, donc les mêmes noms auto-générés. Le
défaut n'apparaît qu'entre deux machines aux bibliothèques différentes.

### ~~Killcam tronquée à cadence libre~~ — **Corrigé**

Relevé au troisième test à deux machines : chez le client (492 fps) la killcam
ne montrait que des déplacements, jamais les tirs ; chez l'hôte (106 fps) elle
fonctionnait « une fois sur deux ».

**La cause : le tampon de rejeu était dimensionné en nombre d'images, pas en
durée.** `max_snapshots = 450`, commenté « 7.5 seconds at 60fps » — une valeur
juste tant que le jeu tournait à 60 fps. À 492 fps, ces 450 instantanés ne
couvrent plus que **0,9 seconde** : le tir fatal était purgé du tampon avant
même la fin de la manche. Pire, la fenêtre différait d'une machine à l'autre.

**C'est le déplafonnement de la cadence d'image, décidé plus haut pour gagner
30 ms de latence, qui a fait s'effondrer cette fenêtre.** Le gain reste acquis ;
seule l'hypothèse cachée « une image de rendu = une image de rejeu » était
fautive.

L'enregistrement se fait désormais à **cadence fixe (60 Hz)**, découplée du
rendu. La killcam couvre 7,5 s partout, identiquement, quelle que soit la
machine — et toute la logique de relecture, qui raisonne en images de 1/60 s,
reste intacte.

### Observations mineures relevées au passage

- **La reconstruction du salon ne conserve pas le code.** Vérifiée en séance
  (le code passe de `29MG4Q` à `S7EYHX` après le départ de l'invité), la
  reconstruction fonctionne, mais l'ancien salon traîne encore dans l'index
  d'Epic au moment du nouveau tirage : le code souhaité est vu comme pris. Sans
  conséquence fonctionnelle, l'hôte affichant le nouveau code.
- **Détection de déconnexion lente.** Wi-Fi coupé côté invité : l'hôte affiche
  encore `Lien DIRECT` (ping monté à 64 ms) et les deux camps se croient
  connectés un bon moment avant le message de rupture. Délai EOS à resserrer.

---

## Phase 4 — Supabase (compétitif / ELO) ✅

### Projet Supabase — créé le 2026-08-16 (jalon H5) ✅

| | |
|---|---|
| Projet | `Candela 2D - Godot` |
| Référence | `obnlcnwlkuojmplksxtu` |
| Région | AWS `eu-west-1` (Irlande) |
| Plan | Gratuit |

Le projet utilise le **nouveau système de clés** Supabase (publiable / secrète),
et non l'ancien couple `anon` / `service_role`. Configuration dans
`supabase_config.gd`, ignoré par git, avec `supabase_config.example.gd` comme
modèle versionné.

**La clé publiable n'est sûre qu'une fois la Row Level Security écrite** : sans
politique RLS, elle donne accès aux tables exposées. Elle reste donc hors de
git jusqu'à ce que l'étape 1 soit faite ; elle pourra rejoindre le dépôt
ensuite, ce qui évitera un transfert manuel de plus vers une seconde machine.
La clé **secrète** ne doit jamais entrer dans le jeu : les Edge Functions
reçoivent la leur par variable d'environnement.

### Étape 1 — identité vérifiée (`673c0e9`) ✅ CLOSE

**Aucun ELO n'est calculé à cette étape.** Elle établit qui est qui, de façon
infalsifiable. C'est austère, mais tout le reste s'écroule sans elle : un
classement dont on peut usurper les profils ne vaut rien.

Déployée le 2026-08-16 sur le projet `obnlcnwlkuojmplksxtu` : les deux migrations
appliquées, les deux Edge Functions en ligne, les secrets Epic posés. Marche à
suivre et relevé des contrôles : [SUPABASE.md](SUPABASE.md).

**Schéma** (`supabase/migrations/20260816160000_players_identity.sql`) — une
table `players` : `id` (uuid), `puid` (PUID Epic **courant**, unique), `code`
(récupération), `nickname`, `arbitration`, `created_at`, `seen_at`.

L'identité durable du profil est `id`, **jamais le PUID** : celui-ci change au
rattachement d'une nouvelle machine, et tout ce qui sera classé pointera sur
`id`. C'est ce qui permettra à un historique de survivre à un changement
d'ordinateur.

Le champ **`arbitration`** (`peer` / `server`) est celui que cette section
réclamait plus bas. Sa place définitive est sur la ligne de résultat, quand la
table des matchs existera ; il est porté sur `players` dès maintenant pour que
le type soit versionné avec le schéma et que la première ligne écrite dise déjà
qui l'a arbitrée.

**RLS** — activée, **sans aucune politique**. L'absence de politique est ici le
contenu, pas un oubli : RLS sans politique refuse tout. Les droits par défaut
accordés par Supabase aux rôles anonyme et authentifié sont retirés en plus. Le
jeu n'écrit donc jamais en direct ; les deux Edge Functions écrivent avec la clé
secrète, via deux fonctions SQL `security definer` (`identify_player`,
`link_profile`) dont l'exécution est refusée à tout autre rôle.

**Vérification du jeton Epic** (`supabase/functions/_shared/epic.ts`) — le
client joint le jeton rendu par `EOS.Connect.ConnectInterface.copy_id_token`.
La fonction le vérifie contre le JWKS d'Epic
(`https://api.epicgames.dev/auth/v1/oauth/jwks`), refuse tout `alg` autre que
RS256, contrôle `iss`, `exp`, `iat`, `aud` = CLIENT_ID et `pfdid` = DEPLOYMENT_ID,
puis n'extrait le PUID que du `sub`. **Un PUID posté dans le corps de la requête
n'est jamais lu.** Sans `EPIC_CLIENT_ID` en environnement, la fonction refuse
tout : une configuration incomplète ne dégrade jamais en « on laisse passer ».

Vérifié le 2026-08-16 avec un **vrai jeton Epic contre le vrai JWKS d'Epic** :
accepté ; la même charge utile modifiée après signature est refusée.
Revendications observées : `act, aud, exp, iat, iss, pfdid, pfpid, pfsid, sub,
tokenType`, `iss = https://api.epicgames.dev/auth/v1/oauth`, durée de vie 3600 s.

**Code de récupération** — tiré au serveur par `crypto.getRandomValues`, jamais
par le client : c'est ce qui empêche un joueur de se choisir le code d'un autre.
Alphabet de `LobbyCode` (ni I, ni O, ni 0, ni 1), mais **12 caractères** et non
6 — voir la décision actée plus bas.

**Côté Godot** — `recovery_code.gd` (logique pure : nettoyer, valider, mettre en
forme) et l'autoload `RankedIdentity` (`ranked_identity.gd`), qui s'identifie en
tâche de fond et expose les mêmes états qu'EOS : non configuré / en cours /
prêt / échec. Un onglet **PROFIL** affiche le code en grand, copiable, et offre
le rattachement d'une seconde machine.

`RankedIdentity` ne s'identifie pas en headless : les suites de tests y tournent,
et chaque exécution créerait un profil de plus dans la vraie base.

**Vérifié** : sans `supabase_config.gd`, le jeu démarre, EOS fonctionne, le
classement reste « non configuré », aucune erreur.

**Les cinq critères de sortie sont tenus**, vérifiés contre les fonctions
réellement déployées :

| Critère | Vérification |
|---|---|
| Deux instances locales, deux profils distincts | Deux identités éphémères → deux profils, deux codes lisibles |
| Un PUID posté sans jeton valide est refusé | `401` sur PUID seul, jeton inventé, `alg: none`, corps vide |
| Un code valide rattache une nouvelle identité | Une troisième identité reprend le profil de la première |
| Sans configuration Supabase, le jeu démarre | Vérifié : classement « non configuré », rien d'autre ne change |
| Les 6 suites passent | ✅ |

**L'onglet PROFIL a été exercé lui aussi**, en instanciant le vrai menu en
headless et en actionnant ses boutons par code : l'onglet est présent et
atteignable à la manette pour les deux joueurs, le code s'affiche groupé par
quatre, COPIER s'active au bon moment, le champ nettoie `abcd-efgh-jklm` en
`ABCDEFGHJKLM`, un code trop court est refusé sans appel réseau, un code valide
bascule le statut et le code affichés vers le profil repris, et un code inconnu
laisse le profil courant intact.

**Parcours à la souris — fait le 2026-08-16 (jalon H7) ✅.** Deux instances
fenêtrées, pilotées à l'écran : la mise en page tient (rien de coupé, code
lisible en grand), COPIER remplit réellement le presse-papiers système avec la
forme groupée `46YD-33UE-SJXA`, le collage dans le champ en retire les tirets,
RATTACHER bascule statut et code affichés vers le profil repris, et un code
inventé répond en orange sans toucher au profil courant. Une partie locale a été
lancée ensuite : écran partagé, HUD, chronomètre — rien du jeu n'a bougé.

Deux confirmations en prime : **le profil orphelin est bien effacé** — après le
rattachement, une seule ligne subsiste en base, celle du profil repris, portant
le PUID de la seconde machine — et **la fermeture par le bouton de fenêtre sort
en code 0**, donc l'arrêt propre d'EOS tient sur ce chemin-là aussi.

**L'étape 1 est close.**

Deux réserves de méthode, pour qui relira : les fenêtres étaient pilotées par
frappes synthétiques, et le focus clavier reste sur la dernière fenêtre touchée
— Échap et F3 semblaient sans effet sur l'autre. Rien n'indique un défaut du
jeu, mais rien ne l'exclut non plus : ces deux touches n'ont pas été vérifiées.

**Un défaut trouvé et corrigé en production** (`20260816183000`) : les fonctions
SQL signalaient « code de récupération inconnu » par un `NULL`, que PostgREST
sérialise en **objet de champs nuls** et non en `null`. L'Edge Function y voyait
un profil valide et répondait `200` — **un code inventé était accepté**. Les
fonctions rendent désormais un `setof` : zéro ligne devient `[]`, sans ambiguïté.
Le client Godot refuse en outre tout profil sans identifiant.

### Étape 2a — les matchs arrivent en base (`3837853`) ✅ CLOSE

**Toujours aucun ELO.** Cette étape archive fidèlement, sans interpréter.

Deux principes gouvernent le schéma. **On stocke les rapports, on dérive le
reste** : `match_reports` est immuable et brute ; la concordance, le vainqueur —
et demain le classement — sont des VUES par-dessus. Une règle d'interprétation
qui se révèle mauvaise se change alors sans migration et sans rien perdre.
**Chaque pair ne parle que de lui** : il déclare « j'ai gagné », jamais « untel a
perdu ». Il n'a donc pas besoin du PUID de son adversaire — le serveur apprend
les deux identités des deux jetons Epic, chacun vérifié. C'est aussi ce qui fait
fonctionner le rapport en LAN, où aucun PUID ne circule.

L'appariement passe par un **identifiant de match** tiré par l'hôte
(16 octets cryptographiques) et transmis au client dans `rpc_start_round`. Ni
secret ni autorité : juste de quoi rapprocher deux récits venus de deux machines
qui ne se parlent plus. Tiré par manche, ce qui coïncide avec le match en BO1 ;
**un BO3 devra le tirer à l'ouverture du match, pas de la manche.**

Le journal local `match_history.json` est écrit **avant** l'envoi et reste le
registre durable : ce qui n'atteint pas le serveur n'est pas perdu, et une étape
ultérieure pourra le rejouer. L'envoi réessaie trois fois puis renonce en le
disant.

**Vérifié en production le 2026-08-16** — deux instances, deux identités
éphémères distinctes, un vrai match en ENet mené jusqu'au chrono :

| Contrôle | Résultat |
|---|---|
| Les deux pairs rapportent le même match | ✅ deux lignes, même `match_id`, 4 s d'écart |
| La vue apparie et juge concordant | ✅ `concordant: true`, `winner: null` (égalité) |
| Rejouer un rapport ne le réécrit pas | ✅ l'original est rendu intact malgré un envoi contradictoire |
| Un PUID jamais identifié | ✅ refusé |
| Un tiers sur un match déjà complet | ✅ refusé — mais accepté sur un match neuf |
| Rapport sans jeton / jeton inventé | ✅ `401` |
| `match_reports` et la vue à la clé publiable | ✅ `42501 permission denied` |
| 6 suites Godot · 44 tests Deno | ✅ |

**Reste dû** : l'ELO lui-même (étape 2b), et le rejeu du journal local pour les
rapports qui n'ont pas pu partir.

### Étape 2b — le classement ✅ CLOSE

**Le classement est une valeur DÉRIVÉE, jamais écrite une fois pour toutes.** La
table `ratings` est reconstruite en entier par un rejeu de tout l'historique
concordant, après chaque match réglé. Conséquence voulue : un mauvais facteur K,
un mauvais classement de départ, une mauvaise pondération du forfait cessent
d'être fatals — on change la constante et on rejoue.

Le calcul vit dans `supabase/functions/_shared/elo.ts`, **pas en SQL**, pour une
raison : en SQL il serait intestable hors ligne. Or le classement est la partie
du système où une erreur est la plus difficile à voir après coup — un classement
faux reste plausible. 20 tests couvrent les propriétés plutôt que des valeurs :
symétrie des espérances, conservation du total, non-commutativité assumée,
indépendance à l'ordre des deux joueurs dans une ligne, convergence.

Réglages, tous nommés et isolés : départ à **1000**, facteur **K = 32** constant
(pas de phase provisoire — un raffinement légitime, mais chacun est une règle
inventée de plus, et il ne coûtera qu'un recalcul le jour où le besoin sera
démontré), forfait à **poids plein**, conséquence directe de la décision de ne
pas rendre l'abandon gratuit.

Le rejeu est **intégral** et non incrémental. Plus coûteux, et délibéré : il
n'existe alors aucun chemin par lequel la table pourrait diverger de
l'historique. Le jour où l'échelle l'exigera, l'incrémental deviendra une
optimisation — avec ce rejeu comme référence pour la vérifier.

**Vérifié en production le 2026-08-16**, deux instances et trois matchs :

| Contrôle | Résultat |
|---|---|
| Match nul entre égaux | ✅ 1000 partout, aucun déplacement |
| Une victoire déplace le classement | ✅ 1015 contre 985 |
| Le total se conserve | ✅ 2000 exactement |
| Rang calculé à la lecture | ✅ 1er et 2e |
| Affichage en jeu | ✅ « 1015 points · 1e · 3 matchs (1V 0D 2N) » dans l'onglet PROFIL |
| `ratings` et `leaderboard` à la clé publiable | ✅ fermés |
| 6 suites Godot · 64 tests Deno | ✅ |

### Étape 2c — le rejeu du journal local ✅ CLOSE (2026-08-18)

**Le classement avait des trous que personne ne pouvait voir.** Trois chemins
perdaient un rapport de match définitivement, tous silencieux :

1. `report_match()` sort sans rien faire si l'identité n'est pas encore `READY` —
   or elle ne l'est pas au premier match d'une session lancée hors ligne ;
2. `_drain_reports()` **vide la file entière** quand le jeton Epic est
   indisponible ;
3. `_retry_or_drop()` renonce après trois tentatives réseau.

Dans les trois cas le match était bien archivé dans `user://match_history.json`.
Le commentaire de `game_state.gd` promettait d'ailleurs qu'« une étape ultérieure
pourra rejouer ce qui manque ».

**Elle ne le pouvait pas.** L'enregistrement ne portait ni `match_id`, ni la
nature classée, ni l'issue vue par cette machine — c'est-à-dire exactement les
trois champs que le serveur exige. Le journal était un souvenir lisible par un
humain, pas une source de rejeu. La promesse était sincère et intenable, et rien
ne le signalait : c'est le même motif que les quatre écarts relevés la veille,
sous une forme plus retorse — non pas une décision jamais posée, mais une
**capacité affirmée que le format interdisait**.

Schéma porté en **v3** : `match_id`, `classe`, `issue`, `remonte`.
`MatchRecord.pending_reports()` sélectionne, `mark_reported()` clôt,
`RankedIdentity.replay_local_journal()` renvoie à l'instant où l'identité devient
utilisable.

#### Les deux décisions qui portent tout le reste

**Le rejeu est sûr parce que le serveur est idempotent par construction.** Un
match déjà complet est refusé en 4xx, et un 4xx clôt l'enregistrement. Un rapport
de trop ne coûte donc qu'un aller-retour, là où un rapport manquant fausse un
classement pour toujours. Les deux sens d'erreur ne se valent pas, et c'est ce qui
autorise à rejouer sans hésiter.

**La dissymétrie entre « le serveur a répondu » et « le réseau a échoué. »** Un
accusé de réception *et* un refus définitif closent l'enregistrement — il n'y a
plus rien à en attendre. Un échec de transport, lui, le laisse **ouvert** : le
serveur ne sait rien de ce match. Clore là perdrait très exactement ce que
l'étape cherche à sauver, et c'est la seule ligne de tout le dispositif qu'il ne
faut pas « simplifier ».

Les enregistrements d'avant la v3 n'ont pas d'identifiant : ils sont
définitivement irrejouables, et le filtre les écarte plutôt que d'envoyer des
récits que le serveur ne saurait apparier.

**Vingt assertions** (`tools/test_rejeu_journal.gd`). Ce qu'elles protègent est
invisible à l'usage : un classement à trous ressemble en tout point à un
classement juste — personne ne peut voir le match qui manque.

**Reste un fil, et il n'est pas chez moi :** `MatchRecord.build()` accepte
désormais `match_id`, `ranked` et `outcome`, mais **son unique appelant
(`game_state.gd:_archive_match_result`) ne les passe pas encore** — le fichier
appartenait à une autre session au moment de la livraison. Tant que ce n'est pas
fait, les nouveaux enregistrements sortent avec un `match_id` vide et le rejeu ne
reprend rien. La machinerie est prête et testée ; il manque une ligne d'appel.

### Périmètre

> Les trois points marqués ✅ ci-dessous sont **faits** par l'étape 1 ; le reste
> appartient aux étapes suivantes.

- Calcul d'ELO dans une Edge Function (jamais côté client — les stats EOS sont
  alimentées par le client, donc trichables pour un classement sérieux).
- Résultat de match **rapporté par les deux pairs** et validé seulement s'ils
  concordent. À ne pas surestimer : cela empêche l'un des deux de déclarer un
  faux résultat, mais **pas** un hôte au client modifié de tricher *pendant* le
  match, puisque c'est lui qui simule tout. C'est la seule parade disponible en
  P2P, pas une protection équivalente à un serveur — voir la décision
  « P2P conservé » plus bas.
- ✅ **Authenticité de l'identité** : le PUID seul ne prouve rien, n'importe qui
  pourrait en poster un. Chaque pair doit joindre son jeton d'identité Epic,
  que l'Edge Function vérifie auprès d'Epic avant d'écrire quoi que ce soit.
- ✅ Prévoir dès le schéma un champ d'**origine de l'arbitrage** (pair / serveur) :
  c'est ce qui permettra d'introduire un serveur dédié plus tard sans invalider
  l'historique déjà accumulé.
- Historique, saisons, liste de salons (reportée depuis la Phase 3).
- Le PUID Epic sert de clé d'identité, **après vérification** : le client joint
  son jeton signé par Epic (`EOS.Connect.ConnectInterface.copy_id_token`,
  disponible dans le plugin — vérifié le 2026-08-16), que l'Edge Function
  valide contre les clés publiques d'Epic avant d'en extraire le PUID. Sans
  cette étape, n'importe qui pourrait poster n'importe quel PUID.
- ✅ **Récupération d'identité : code de récupération** (décision du 2026-08-16).
  Le Device ID Epic étant lié à la machine, un joueur qui change d'ordinateur
  perdrait son classement. Le jeu lui affiche donc un code à conserver, qui
  rattache une nouvelle machine au profil existant. Les comptes en bonne et due
  forme (e-mail, Supabase Auth) viendront plus tard ; ce mécanisme se retire
  sans douleur le jour venu. Réutiliser l'alphabet sans ambiguïté de
  `LobbyCode` (ni I, ni O, ni 0, ni 1) : ce code se lit à voix haute et se
  recopie à la main.
  **Compromis assumé :** un code de récupération est un secret au porteur —
  qui l'obtient prend le profil. Proportionné pour un classement de jeu, à
  revoir si les enjeux montent.
- **Surface de triche à inventorier avant tout classement.** La signature à
  deux pairs (ci-dessus) ne suffit pas : le RTT applicatif est déclaratif et
  nourrit la compensation de tir, et la cadence de tir du client n'est bornée
  que par la simulation de l'hôte. Les inputs, eux, sont bornés côté hôte
  depuis le 2026-08-16 (vecteurs finis, longueur ≤ 1) et l'écho de ping n'est
  plus accepté que du pair attendu, avec RTT borné à [0, 10 s] — un début, pas
  une parade complète.
- Fondation déjà en place : `match_record.gd` archive chaque match dans
  `user://match_history.json` (vainqueur, durée, armes, carte, mode, format).
  Durci le 2026-08-16 pour pouvoir servir de source ELO : champ `version` dans
  chaque enregistrement (le futur envoi saura quelle forme il relit) et
  écriture atomique du journal (temporaire puis renommage — un arrêt brutal ne
  peut plus corrompre l'historique déjà archivé).

---

## Phase 5 — Les menus ✅ CLOSE le 2026-08-18

**Les six étapes sont livrées.** Ne restent que des vérifications humaines, qui ne
sont pas du travail de phase : parcourir les menus à la main et juger si
l'ensemble est agréable. Échap et F3 ont été vérifiés le 2026-08-18 — six gestes,
six réponses.

Trois choses ont été ajoutées au-delà du plan initial : la vague M, la fenêtre de
choix d'arme d'un match apparié, et un écran d'historique là où le plan
n'attendait qu'un tableau.

**La vague M continue hors phase, à 11 sur 15** — restent M11, M13, M14 et M15.
Clore la phase ne la clôt pas : c'est une vitrine d'effets, pas une étape dont
quelque chose dépend. Le dire évite qu'un lecteur croie les quinze faits.

**Pourquoi cette phase vient avant les rangs et le déblocage d'armes.** Les rangs
ont besoin d'un écran de classement, les armes verrouillées d'un sélecteur qui
sache montrer un verrou, et les deux d'un endroit où vivre. Les greffer sur
l'onglet JOUER actuel — qui porte déjà le mode, la carte et les deux râteliers
d'armes — puis restructurer ensuite reviendrait à faire le travail deux fois.
L'ordre n'est pas une préférence : c'est la seule séquence qui ne se paie pas
double.

**Rien de ce qui suit ne touche au réseau.** Le menu ne fait que *choisir* un
mode ; `NetworkManager` et `game_state.gd` reçoivent les mêmes appels quelle que
soit la structure retenue. La seule règle à ne pas enfreindre est celle de
l'architecture : hors de `network_manager.gd`, seul le bloc lobby de `ui.gd` a le
droit de connaître le transport.

### Ce qui manque — relevé du 2026-08-16 sur `ui.gd`

L'UI est construite **entièrement en code** : `ui.tscn` fait six lignes, et
`_build_menu()` fabrique tout. Il n'y a donc aucune scène à réagencer, ce qui
rend la refonte moins risquée qu'il n'y paraît — mais aussi entièrement à écrire.

| Manque | Constat |
|---|---|
| ~~Aucun réglage audio~~ **persistance faite, écran à faire** | `settings_manager.gd` porte désormais une section `audio` : quatre volumes en amplitude linéaire, convertis en décibels seulement à l'application. Reste à construire l'écran qui les expose. |
| **Aucun écran de classement** | L'Edge Function `standing` renvoie déjà un `top` de dix ; l'UI n'affiche que la ligne du joueur. Le travail serveur est fait, l'écran manque. |
| **Aucun mode entraînement** | `TrainingTarget` existe mais ne s'active qu'en attendant un adversaire en ligne (`game_state.gd:279`). Un joueur seul ne peut pas s'exercer. |
| **Aucune calibration de luminosité** | Dans un jeu dont l'unique canal d'information est la lumière, un écran mal réglé — ou trop bien réglé — est un avantage. C'est un problème d'honnêteté en compétition, pas de confort. |
| **L'onglet « CONTRÔLES » est un menu Options déguisé** | Il contient l'affichage et les images par seconde. Le nom ment sur le contenu. |
| **La pause est le menu complet** | Un seul `game_over_panel` sert de menu principal, de pause et d'écran de fin ; les différences se règlent en masquages à la volée (`show_main_menu`, `show_game_over`). Chaque nouvel écran ajoutera une règle de masquage de plus. |
| Pas d'historique, pas d'édition du pseudo | `nickname` existe côté base et `match_history.json` côté disque ; ni l'un ni l'autre n'a d'écran. |

### Structure retenue — B, le hub (décision d'Adrien, 2026-08-17)

Trois structures avaient été prototypées et navigables. **B est retenue** : un
accueil de grandes destinations, chacune un écran entier avec son retour.

Ce qu'elle coûte, et qui a été accepté en connaissance de cause : **trois clics
pour lancer un match local au lieu d'un**, quatre pour un salon en ligne au lieu
de deux. Ce prix se paie à chaque relance. Ce qu'elle rapporte : un écran, un
sujet — les rangs, le déblocage d'armes et les saisons s'y ajoutent sans
surcharger quoi que ce soit, là où l'onglet JOUER actuel est déjà plein.

**Conséquence à surveiller pendant l'écriture** : le critère « immédiat » du
projet est celui qui encaisse le coup. Si la relance après un match devient
pénible à l'usage, le correctif n'est pas de revenir en arrière mais d'ajouter un
raccourci de relance depuis l'écran de fin — à évaluer une fois le hub jouable,
pas avant.

#### L'arborescence — revisée par Adrien le 2026-08-17 (soir)

```
Accueil
├── 1V1 ÉCRANS SCINDÉS
│   ├── Jouer ............ action "lancer"
│   ├── Changer de carte . → Cartes
│   └── ‹ Retour
│
├── 1V1 AMICAL
│   ├── Chercher un match en ligne . (appariement) — grisé
│   ├── Match privé en ligne → écran intermédiaire
│   │   ├── Créer → Salon en ligne — hôte (code · statut · armes)
│   │   │   ├── Prêt · Changer de carte · Retour
│   │   ├── Rejoindre → Salon en ligne — invité (code à saisir)
│   │   │   ├── Prêt · Retour
│   │   └── ‹ Retour
│   ├── Match privé en local → écran intermédiaire
│   │   ├── Créer → Salon local — hôte (adresse IP · armes)
│   │   │   ├── Prêt · Changer de carte · Retour
│   │   ├── Rejoindre → Salon local — invité (saisie d'adresse IP)
│   │   │   ├── Prêt · Retour
│   │   └── ‹ Retour
│   └── ‹ Retour
│
├── 1V1 COMPÉTITIF
│   ├── Chercher un match en ligne . — grisé
│   ├── Mon rang ........... panneau de droite
│   ├── Top 10 ............. panneau de droite
│   ├── Informations profil  → Profil
│   └── ‹ Retour
│
├── S'ENTRAÎNER
│   ├── Lancer l'entraînement . — grisé
│   ├── Cible ................ — grisé
│   ├── Changer de carte ..... → Cartes
│   └── ‹ Retour
│
├── PROFIL .............. identité · code · pseudo · historique
├── PERSONNALISATION      *aucun sous-écran : tout se règle à droite*
│   ├── Contrôles .......... panneau (rebind J1 · J2, les 3 actions d'un bloc)
│   ├── Affichage .......... panneau (résolution · VSync · FPS · calibration)
│   ├── Effets ............. panneau
│   ├── Audio .............. panneau
│   └── ‹ Retour
└── QUITTER
```

**Deux panneaux, et ce n'est pas décoratif.** La liste à gauche, à droite ce que
l'entrée sous le curseur raconte. Cela permet à une entrée de **montrer une
information sans faire descendre d'un cran** : « Top 10 » et « Mon rang »
remplissent le panneau de droite au lieu d'ouvrir un sous-écran. Un menu qui
obligerait à entrer puis à ressortir pour lire trois lignes ferait payer un
aller-retour pour une consultation.

#### Un réglage n'est pas une destination (2026-08-18)

**Personnalisation n'a plus aucun écran sous elle.** Ses quatre rubriques étaient
quatre écrans à pousser, chacun redistribuant ses réglages en une nouvelle liste
à gauche : réassigner une touche coûtait deux descentes et deux remontées, et le
cadre de droite — la moitié de l'écran — ne servait qu'à commenter le niveau du
dessus. Chaque rubrique déplie désormais sa page entière à droite, au survol
comme à la sélection.

Le gain n'est pas seulement le nombre de gestes. La configuration des touches
n'était **jamais visible d'un coup** : une action par entrée, un panneau par
action. Un doublon entre deux actions — la même touche pour tirer et pour
sprinter — ne se repérait qu'en faisant l'aller-retour de mémoire. La grille de
trois lignes le montre.

Cela a coûté un déplacement du garde-fou de la calibration, deux fois dans la
même journée : d'abord quand la calibration est devenue un panneau, puis quand
les quatre réglages d'affichage ont fusionné et qu'elle a cessé d'avoir une clé
à elle. La formulation qui a survécu aux deux sans être réécrite est celle qui
teste la **cause réelle** — le champ de mesure est-il à l'écran — et non le nom
de l'endroit où il se trouvait ce jour-là.

Conséquence assumée : survoler « Affichage » éteint les effets de menu, puisque
le champ de mesure est dans le cadre. C'est visible, et c'est le bon sens de
l'échange — une mesure faussée par trois centièmes de luminance parasite ne se
signale, elle, jamais.

**Le retour est une entrée cliquable en bas de chaque liste**, pas un rappel de
touche. La première version affichait « ÉCHAP · RETOUR » sans que rien ne soit
cliquable — *et sans que la touche fasse quoi que ce soit*. Un libellé qui
annonce une commande inexistante est pire qu'une absence de libellé. La touche
double désormais le bouton ; elle ne le remplace pas.

**Ce qui n'existe pas est grisé, jamais masqué**, et le panneau de droite dit
pourquoi. Masquer laisserait croire que la fonction n'existera pas ; retirer
l'entrée du parcours du curseur ferait douter du bouton d'à côté. Sont grisés
aujourd'hui : les deux « chercher un match » (appariement manquant), le lancement
de l'entraînement, la configuration de la cible et l'écran audio.

#### La barre du bas disparaît aussi de l'écran de fin (2026-08-18)

Elle avait survécu là : REJOUER, MENU PRINCIPAL et QUITTER y doublaient la liste
de gauche. **REJOUER prend désormais la place exacte de PRÊT** *(⚠️ superseded
le 2026-08-24 : les deux ont quitté la colonne pour le cadre de droite. Le
problème que cette décision réglait — « deviner lequel des deux comptait » — est
réglé plus radicalement, puisqu'il n'y a plus qu'un seul bouton, et qu'il est là
où l'on regarde en choisissant son arme.)* — même geste,
même endroit, même style : s'engager dans la manche suivante. Les avoir séparés
en deux boutons, l'un dans la liste et l'autre dans une barre, obligeait à deviner
lequel comptait.

MENU PRINCIPAL disparaît : le retour de la liste ferme le salon et ramène au menu.
QUITTER aussi : **il n'existe que sur l'accueil**, jamais dans un salon.

`btn_replay` reste la source de vérité du libellé et devient invisible. Plusieurs
endroits écrivent son texte — « ✓ PRÊT », « Connexion au salon… » — et les
recenser pour les rerouter créerait autant d'occasions d'en oublier un ; l'entrée
de liste le recopie tant qu'on est sur l'écran de fin, et reprend son libellé
d'origine au menu.

#### Mise en page — révision du 2026-08-17 (soir)

**La barre de boutons du bas a disparu du menu.** « Jouer », « Prêt » et
« Chercher un match » lancent déjà le bon type de match depuis leur propre écran ;
une barre qui doublait tout ça obligeait à deviner lequel des deux gestes comptait.
« Quitter » devient une entrée de l'accueil, sous Personnalisation, au rouge.
**L'écran de fin garde sa barre** — REJOUER et MENU PRINCIPAL n'ont pas
d'équivalent dans le hub, et on n'y est plus dans le menu.

> ⚠️ **SUPERSEDED le 2026-08-24 par « le geste qui engage vit dans le cadre de
> droite » (arbitrage d'Adrien).** La colonne de gauche ne porte plus aucun
> lanceur : le bouton descend dans le cadre, sous les râteliers d'armes dont il
> dépend, et l'entrée de gauche qui ouvre ce cadre s'appelle « PRÉPARER LE
> MATCH ». Le style plein n'a donc plus de porteur à gauche — **il en retrouve
> un dans le cadre**, où rien ne le dispute au liseré du curseur. C'est même ce
> qui résout le défaut ci-dessous : le style plein avait été retiré des lanceurs
> le 2026-08-18 parce qu'il se confondait avec la sélection. Le déplacer lui
> rend sa place au lieu de le supprimer.
>
> Ce que le renversement coûte, et qui est assumé : **un déplacement de curseur
> de plus à chaque relance**, sur le geste le plus répété du jeu. C'est le
> critère « immédiat » qui encaisse. Si ça devient pénible à l'usage, le
> correctif n'est pas de revenir en arrière mais d'**aimanter le curseur sur le
> bouton du cadre à l'ouverture** — piste notée, pas implémentée : la poser
> d'avance serait corriger un défaut que personne n'a encore ressenti.

~~**Les entrées qui lancent un match portent le style plein.**~~ Le geste qui engage
une partie doit se distinguer de tout ce qui n'engage rien.

**La description a quitté le panneau de droite** pour se poser sous le titre du
jeu, à la place d'un « PRÊT À JOUER ? » qui ne disait rien. Lire l'explication
d'une entrée ne devrait pas demander de traverser l'écran du regard ; le panneau
de droite est libéré pour ce qui mérite d'y être.

**Tout est aligné en haut**, des deux côtés. Un contenu centré verticalement saute
d'un écran à l'autre selon sa hauteur, et le regard doit le rattraper à chaque fois.

#### Corrections du 2026-08-17 (nuit)

**« Quitter » reprend le style ordinaire.** Il portait le style plein des
lanceurs de match : il criait plus fort que ce qui démarre une partie, alors
qu'il ne fait que fermer le jeu.

**La bascule INTERNET / RÉSEAU LOCAL ne s'affiche plus du tout.** Entrer par
« match privé en ligne » ou par « en local » *est* le choix de transport ; la
reproposer dans le panneau remettait en question une décision déjà prise. Elle
reste dans l'arbre, dans un conteneur caché, parce que `_refresh_lobby_block()`
lit encore son état — la retirer vraiment demanderait de réécrire les quatre
combinaisons de mode et de transport.

#### Les trois chantiers de menu — livrés le 2026-08-18 ✅

Les trois demandes restées ouvertes la veille sont faites. Elles tenaient toutes
au même manque, et c'est ce qui rend le lot cohérent : **le hub savait attacher un
affichage riche à un écran, pas à une entrée.**

**1. La galerie de cartes n'est plus un écran.** Survoler « CHANGER DE CARTE »
remplit le panneau de droite avec les vignettes, et c'est là qu'on choisit ;
l'éditeur est un raccourci en bas du panneau. `SCREEN_MAPS` a disparu de
l'arborescence. La carte affichée dans le salon **cesse d'être un bouton** : elle
menait à la galerie, en doublon de l'entrée de la liste, et deux gestes pour une
décision, c'est un de trop.

**2. Contrôles et Affichage sont des listes.** Contrôles : une entrée par action
réassignable (Tirer, Torche, Courir), ses deux touches à droite. Affichage :
Résolution, Vsync, Images par seconde, Calibration. Au passage, une **duplication
réelle** disparaît : `_fill_controls_screen()` ajoutait aussi les blocs
d'affichage et de vidéo, déjà présents dans leur propre écran. Deux jeux de
boutons radio prétendaient chacun dire la résolution en cours — changer l'une
laissait l'autre mentir.

**3. Le salon s'ouvre depuis le menu.** Bouton « CRÉER LE SALON » dans le panneau
de droite, liste des joueurs au-dessus, code EOS (ou IP) affiché dès l'ouverture
et non plus au lancement du match. Quitter l'écran referme le salon.

##### Deux défauts trouvés en chemin, et corrigés parce qu'ils bloquaient

Ce sont eux le vrai gain de ce lot, et ni l'un ni l'autre n'était dans l'énoncé.

**Le panneau de droite était hors du champ de navigation.** `_nav_candidates()`
ne ramassait que `hub.body_of(...)`, c'est-à-dire la colonne de gauche. Tout ce
qui vivait à droite était **inatteignable aux deux curseurs** : le choix d'arme et
le champ de saisie du code de salon compris. À la souris tout marchait, ce qui
explique que personne ne l'ait vu.

**Les curseurs maison ne déclenchent pas `focus_entered`.** Ils dessinent un
liseré, ils n'appellent jamais `grab_focus()`. Le panneau de droite et la
description sous le titre ne suivaient donc que la **souris**. Sans correctif, la
galerie de cartes serait restée invisible à la manette — c'est-à-dire au
périphérique avec lequel ce jeu se joue. `MenuHub.reveal_entry()` est le relais :
`_set_focus()` l'appelle, et le hub retrouve ce que l'entrée raconte.

##### Ce que le netcode a dû accepter

Ouvrir le salon depuis le menu déplace un moment, et un seul : l'hôte peut
désormais être **encore dans ses menus quand l'adversaire se connecte**. Or le
client, lui, démarre sa manche à la connexion et envoie aussitôt
`rpc_client_weapon`, qui lance la manche chez l'hôte. Sans préparation, P2 serait
resté piloté par le clavier de l'hôte au lieu des commandes reçues, et l'hôte
aurait joué derrière son propre menu.

D'où `_enter_hosted_game()` dans `game_state.gd` : autorités, fournisseurs
d'entrées, vues. **Deux chemins y mènent** — l'hôte qui appuie sur « LANCER LE
MATCH », et l'adversaire qui arrive dans un salon déjà ouvert — et ils doivent
préparer exactement la même chose. Et `_on_replay_requested()` ne réhéberge plus
si le salon est ouvert : cela remplacerait le pair vivant, donc la connexion déjà
établie avec l'adversaire qui attend dans la liste.

**Non vérifié :** tout ceci n'a jamais tourné entre deux machines. Le parcours a
été validé en headless (structure, navigation au curseur, panneaux) et par les
dix-sept suites, mais l'ouverture d'un salon EOS depuis le menu, l'arrivée d'un
client pendant que l'hôte attend, et la fermeture du salon en quittant l'écran
demandent deux fenêtres. **À joindre au protocole H1/H3 d'Adrien.**

#### Ce qui reste de cette révision, et qui n'est pas cosmétique

**Ce que cette révision a révélé, et qui n'était pas dans l'énoncé.**
« Match privé **en ligne** » contre « **en local** » n'est pas une nuance de
vocabulaire : **c'est le choix de transport**, transformé en navigation. Entrer
dans « en local » pose `Transport.ENET`, entrer dans « en ligne » pose
`Transport.EOS`. La bascule INTERNET / RÉSEAU LOCAL disparaît donc de l'écran.

C'est le raisonnement de l'étape 3b appliqué une seconde fois, et il valait d'être
reconnu comme tel : **un état d'interface ne doit pas tenir lieu de décision.**

D'où **quatre salons au lieu de deux**, un par croisement mode × transport.

⚠️ **Ce paragraphe a décrit pendant une journée quelque chose qui n'existait pas.**
La navigation ne posait **ni le mode ni le transport** des salons locaux : les deux
écrans « en local » se déclaraient *écran partagé*, masquaient tout le bloc réseau
— pas de bouton « créer le salon », pas d'adresse IP, pas de liste de joueurs — et
« lancer le match » y démarrait un écran partagé au lieu d'héberger. Les quatre
salons étaient deux salons et deux doublons. Relevé par Adrien à l'usage le
2026-08-18, corrigé le jour même (`_apply_lobby_intent()`), et c'est la **troisième
fois de la semaine** qu'un document affirme au passé une intention jamais posée
dans le code — après les entrées « chercher un match » et l'autoload d'appariement.

Les deux bascules INTERNET / RÉSEAU LOCAL restent dans l'arbre, hors de vue, tenues
en miroir de la décision : le banc `tools/test_online_match.tscn` les pilote encore
pour choisir son transport. Les retirer demande de reprendre ce banc d'abord.

« Quitter » a quitté l'accueil : le bouton de la barre d'actions est toujours
visible, et une entrée de plus dans une liste de cinq destinations coûtait un
déplacement de curseur pour rien.

**Différences par rapport à l'arborescence du matin (2026-08-17) :**

- **1V1 Amical** : les deux modes (en ligne et local) sont séparés dans deux
  écrans intermédiaires. Dans la version du matin, Créer/Rejoindre s'atteignaient
  directement. Chaque salon (hôte ou invité, en ligne ou local) a désormais son
  propre écran.
- **Salon local / Rejoindre** : saisie d'adresse IP (et non de code de salon).
- **1V1 Compétitif** : Mon rang · Top 10 · Informations profil ajoutés (dans la
  version du matin, seul « Chercher un match » était là).
- **S'entraîner** : Mon rang et Top 10 ont migré vers Compétitif ; Cible et
  Changer de carte les remplacent.
- **Personnalisation** : l'Éditeur de cartes et Calibration ont été retirés ;
  Audio monte d'un rang (désactivé mais visible).

Le classement n'est plus une destination depuis l'écran d'entraînement : il se
lit depuis 1V1 Compétitif, dans le panneau de droite. L'écran autonome reste
construit — il sait tenir les six états du service — mais hors de l'arborescence.

### Les étapes, dans l'ordre

Chaque étape laisse le jeu jouable à la fin. C'est la contrainte qui gouverne le
découpage : aucune ne doit exiger la suivante pour que le menu fonctionne.

**Étape 1 — séparer la pause du menu principal. ✅ CLOSE**
À faire en premier, et elle l'aurait été quelle que soit la structure retenue.
Tant qu'un seul `game_over_panel` servait de menu, de pause et d'écran de fin,
tout écran ajouté coûtait une règle de masquage à la volée de plus.

`pause_panel` est désormais un panneau à part, construit par `_build_pause_menu()`
et monté directement sur le `CanvasLayer` : titre, score de session, temps
restant, et quatre issues en colonne — reprendre, options, menu principal,
quitter. Il ne connaît ni les onglets ni la préparation de match.

Trois points qui ne sautent pas aux yeux :

- **La pause est modale pour la navigation.** `_nav_candidates` rend la main dès
  que le panneau est visible : sans ce retour anticipé, le curseur filait dans
  les onglets du menu, cachés mais toujours dans l'arbre.
- **Les réglages en cours de match empruntent l'onglet CONTRÔLES**, seul onglet
  montré dans ce cas (`_options_from_pause`). C'est un détour assumé, pas une
  fin : il disparaît à l'étape 4, quand les options auront leur écran. Sans lui,
  la refonte aurait retiré au joueur un accès qu'il avait.
- **`REPRENDRE` a quitté la barre d'actions du menu.** Le menu à onglets ne
  s'affiche plus jamais par-dessus un match en cours, sauf pour cette parenthèse,
  qui a son propre `RETOUR`.

*Piège tenu* : l'abandon en ligne vaut forfait, archivé par `game_state.gd` en
réponse à `main_menu_requested` et `quit_requested`. Un bouton qui cesserait de
les émettre ferait disparaître le forfait **sans le moindre message d'erreur** —
d'où une septième suite headless, `tools/test_pause_menu.gd`, qui instancie le
vrai `ui.gd` et vérifie les deux signaux, la navigation captive, la parenthèse
des options et la fermeture forcée (celle qui a déjà laissé une killcam derrière
un panneau que plus rien ne fermait).

*Piège payé en l'écrivant, consigné plus bas* : ce test a d'abord annoncé « tous
les tests passent » sans rien exécuter.

**Étape 2 — l'ossature du hub. ✅ CLOSE**
Écran d'accueil, navigation vers un écran-enfant, retour, et la pile qui va avec.
Rien d'autre : les écrans-enfants sont des pages vides à ce stade. C'est l'étape
qui porte tout le risque de navigation, elle a donc été exercée seule, avant
qu'un seul écran ne soit rempli.

`menu_hub.gd` (`class_name MenuHub`) sait déclarer des écrans, empiler, revenir,
et n'afficher que le courant. Il ne connaît **aucun** contenu : l'étape 3 remplit
les corps sans le modifier.

**Pourquoi une pile et non un parent déclaré.** Un écran s'atteint par plusieurs
chemins — la galerie de cartes s'ouvre depuis la préparation locale comme depuis
le salon en ligne. Un parent fixe renverrait le joueur au mauvais endroit, défaut
qu'on ne voit qu'en jeu et qu'on met longtemps à croire parce qu'il ressemble à
une erreur de manipulation. La pile renvoie toujours d'où l'on vient, et
`tools/test_menu_hub.gd` l'exerce explicitement par les deux chemins.

Trois garanties tenues par l'ossature, chacune testée : l'accueil est le fond de
pile et ne peut pas en être retiré (dix retours d'affilée ne la vident pas) ; un
seul corps est visible à la fois, donc hors d'atteinte du curseur ; empiler
l'écran courant ne fait rien — sans quoi un double appui obligerait à deux
retours pour un seul aller, et le bouton passerait pour cassé.

`menu_theme.gd` extrait la palette et le rythme avant que le second consommateur
n'existe : deux copies d'une palette divergent toujours. `ui.gd` garde ses
constantes jusqu'à l'étape 3 — les changer maintenant toucherait des centaines de
lignes hors périmètre.

**Étape 3 — déplacer l'existant sous le hub. ✅ CLOSE**
La barre d'onglets a disparu : dix-huit fonctions et 350 lignes retirées de
`ui.gd`. Les blocs existants sont réemployés tels quels — seul leur point
d'accrochage change, ce qui permet de savoir que ce qui casse vient du
déplacement et de rien d'autre.

Arborescence livrée : accueil → JOUER · CLASSEMENT · PROFIL · OPTIONS, et
OPTIONS → contrôles · affichage · effets. La galerie de cartes s'atteint depuis
la carte sélectionnée de l'écran JOUER. Les écrans du classement, du profil et
des effets sont les `HubScreen` autonomes de la vague 2.

Les gâchettes L1/R1 ne feuillettent plus d'onglets : elles remontent d'un cran.
La parenthèse « options depuis la pause » de l'étape 1 disparaît du même coup —
la pause ouvre l'écran des options, il n'y a plus de masquage d'onglets.

**Ce qui n'est PAS fait, et pourquoi.** La structure B prévoit que « 1v1 en
ligne » et le salon soient des écrans distincts. Ils restent sur l'écran JOUER,
bascules de mode intactes, parce que **`selected_network_mode()` lit l'état de
ces boutons** et que le netcode l'interroge au lancement. Les éclater exige de
découpler le choix du mode de l'état des boutons : c'est un changement de
comportement, pas un déplacement, et l'étape 3 avait pour règle de ne rien
changer. → étape 3b.

**Étape 3b — découpler le mode de ses boutons. ✅ CLOSE**

`selected_network_mode()` rend désormais `_intended_mode`, une intention posée
**par la navigation** : entrer dans le salon local, c'est vouloir jouer en local,
et ça se dit une fois. Les quatre bascules — 1V1 LOCAL / EN LIGNE, CRÉER /
REJOINDRE — ont disparu avec leurs six connexions.

Ce qu'elles avaient de mauvais n'était pas d'être des boutons : c'était qu'un
**état d'interface tenait lieu de décision**. Le mode se déduisait de
`button_pressed` sur deux groupes distincts, et repasser en local ne décochait pas
le sous-mode en ligne — d'où une lecture à trois branches dont le commentaire
avouait que « six connexions n'arrivaient plus à tenir cohérentes ».

Le transport reste un bouton, lui : Internet ou réseau local est une vraie
alternative offerte au joueur, pas une conséquence de sa navigation.

**Deux bogues que j'ai écrits puis corrigés avant de commiter**, tous deux dus à
la même illusion — croire qu'un nœud peut servir à plusieurs endroits :
`transport_hbox` donné à trois panneaux se serait simplement déplacé dans le
dernier, et `_build_weapon_block()` réassignant `weapon_hbox` à chaque appel
aurait laissé deux râteliers orphelins dans l'arbre, la sélection d'arme ne lisant
plus que le dernier. Le panneau des salons est donc **unique**, et
`_refresh_lobby_block()` décide de ce qui s'y voit — ce qu'il faisait déjà pour
les quatre combinaisons de mode et de transport.

Corollaire du même piège : la boucle qui montre le panneau du bon écran comparait
clé par clé, ce qui masquait un panneau partagé entre trois écrans, la dernière
itération l'emportant. Elle désigne maintenant le panneau attendu, puis compare
les contrôles entre eux.

**Le test de fumée a validé le découplage en cassant.** `test_online_match`
pilotait le menu en écrivant `btn_mode_local.button_pressed = true` — exactement
la dépendance qu'on retirait. Il exprime maintenant le geste (`hub.push`) plutôt
que l'état, ce qui est aussi ce que fait un joueur.

**Étape 4 — Options : audio et calibration. ✅ CLOSE**

**Audio.** Un réglage qu'on ne peut pas entendre ne se règle pas : chaque
changement joue un son sur le bus concerné — le tir pour les effets, parce que
c'est le son de référence du duel. La musique du menu tourne déjà et *est* son
propre témoin : y superposer un bip la salirait sans rien apprendre.

**Calibration.** La cible porte **deux marques et non une** : un repère qui doit
tout juste apparaître, et le cran juste en dessous qui doit rester invisible.
« Montez jusqu'à voir ceci » ne pose qu'un plancher, or **l'avantage se trouve
au-dessus** — l'encadrement des deux côtés est ce qui sépare une cible perceptive
d'un curseur guidé.

Une silhouette et non une pastille : reconnaître une *forme* demande plus de
contraste que détecter une plage uniforme, et calibrer sur la tache réglerait le
jeu trop bas. Le champ est peint sur le **noir du match** et non sur le fond des
menus, volontairement moins noir — mesurer sur un noir relevé décalerait tous les
joueurs du même côté, invisiblement.

La fenêtre honnête est **montrée et nommée, jamais imposée** : l'écrêter ne ferait
pas disparaître le réglage, il migrerait vers le bouton du moniteur, là où le jeu
ne voit rien.
Le bloc audio est à créer de bout en bout, `settings_manager.gd` compris (section
`audio` dans `user://settings.cfg`, appliquée au démarrage comme le reste, en
respectant l'ordre des autoloads). La calibration de luminosité est un écran de
réglage guidé — « ajustez jusqu'à distinguer tout juste cette silhouette » — et
non un curseur nu : c'est une question d'honnêteté en compétition, pas de
confort.

**Étape 5 — les écrans manquants. ✅ CLOSE le 2026-08-18**

Les trois sont livrés, et le travail de fond préexistait dans chaque cas — c'est
ce qui rendait l'étape courte.

**Classement** — lu depuis 1v1 compétitif, dans le panneau de droite : « MON
RANG » et « TOP 10 » le remplissent sans faire descendre d'un cran. L'écran
autonome reste construit et sait tenir les six états du service, mais il est hors
de l'arborescence : une consultation de trois lignes ne doit pas coûter un
aller-retour. Le rang du joueur y figure depuis `431daba` — le serveur le
calculait et l'envoyait, la lecture le jetait.

**Entraînement** (`7e9fe8f`, `987909b`) — cible fixe au point d'apparition de J2,
carte par défaut, vue unique. La propriété non négociable est que **rien n'y est
archivé** : le journal local est la source du rejeu vers le classement, et une
seule ligne écrite là polluerait un classement que personne ne saurait plus
corriger. Un banc dédié le vérifie en comparant la taille du journal avant et
après.

**Historique** (`75bb3f5`) — le bilan de la soirée, puis les douze derniers
matchs. Ce que sa suite protège en premier n'est pas l'affichage mais
l'honnêteté : **ce qui a été écarté est dit**. Un journal peut contenir des
enregistrements illisibles ou écrits par une version plus récente ; les taire
donnerait un historique silencieusement incomplet, ce qui est la seule chose
qu'un historique ne doit jamais être — on le croirait entier.

**Étape 6 — édition du pseudo.** ✅ **Déployée le 2026-08-24** par Adrien —
`rename_profile` en base, fonction `rename` en ligne, porte vérifiée (`401` sans
jeton, réponse identique à `link`, déjà en production). Le nouveau plancher de
rang est effectif en production dans la foulée : un débutant s'affiche **Aveugle
I**. **Écran câblé depuis le 2026-08-18** côté client, resté inerte en attendant
ce déploiement : le bouton MODIFIER s'ouvre sur une saisie préremplie du pseudo
courant — on modifie un pseudo, on n'en saisit pas un nouveau — et la rangée
remplace la ligne du pseudo plutôt que de s'ajouter dessous, pour que rien ne se
déplace.

`can_rename()` exige un profil **prêt** : une identité en cours n'a pas de pseudo
à changer, et montrer le bouton donnerait une action qui échoue. Le contrôle qui
affirmait l'inverse a été **retourné, pas supprimé** — il disait pourquoi le
renommage était indisponible, et sa raison reste juste, elle ne s'applique
simplement plus. **Étape close.**

Le pseudo est la **seule** chose qu'un joueur peut changer de son profil : ni son
identifiant, ni son code de récupération, ni son classement — tout le reste est
dérivé ou constitutif. C'est ce qui rend l'étape petite.

Livré le 2026-08-18, déployé le 2026-08-24 :

- `supabase/migrations/20260818020000_rename_profile.sql` — `rename_profile()`,
  qui **renomme par le PUID et lui seul**. Passer un identifiant de profil
  laisserait renommer celui d'un autre à qui saurait le deviner ; le jeton Epic,
  lui, ne prouve qu'une chose, et c'est la bonne. Ensemble vide en cas d'échec,
  comme `link_profile` et pour la même raison.
- `supabase/functions/rename/index.ts` — refuse un pseudo vide plutôt que de
  retomber sur un « Joueur-XXXX » : le joueur croirait avoir renommé et
  découvrirait autre chose sur l'écran de fin de son adversaire.
- `RankedIdentity.rename()` et le signal `rename_completed`, calqués sur `link`.
  Un pseudo identique à l'actuel n'entraîne aucun aller-retour — afficher
  « enregistré » pour un changement qui n'en est pas un ne veut rien dire.

**Le nettoyage du pseudo est en double, et c'est voulu.** Le client nettoie pour
que le joueur **voie** ce qu'il obtiendra, le serveur nettoie parce qu'il ne fait
autorité sur rien de ce qui lui arrive, et la base refuse parce qu'elle est la
dernière ligne. Le risque du doublon est la divergence : le joueur se croirait
appelé autrement qu'il ne l'est, et ne s'en apercevrait que sur l'écran de fin de
son adversaire. D'où `RecoveryCode.sanitize_nickname()` — rangé **à côté** de
`sanitize()`, exactement comme le serveur range ses deux nettoyages dans le même
fichier — et `tools/test_pseudo.gd`, qui rejoue cas par cas les assertions de
`recovery_code_test.ts`.

**Déploiement vérifié le 2026-08-24** : `supabase migration list` confirme
`20260818020000` appliquée côté distant, et `rename` répond `401 jeton_absent`
sans jeton — exactement la réponse de `link`, déjà en production. Plus rien
n'attend Adrien sur cette étape.

### Couleur des entrées « lanceur » confondue avec le liseré de sélection — corrigé (2026-08-18)

Relevé par Adrien à l'usage : JOUER, PRÊT, CHERCHER UN MATCH, LANCER
L'ENTRAÎNEMENT et QUITTER se voyaient parfois pour l'entrée réellement visée par
un curseur, alors qu'elles ne l'étaient pas. **La cause** : `MenuHub.make_entry()`
peignait ces boutons au repos avec `accent` — `MenuTheme.P1` ou `.P2` — en fond et
en cadre 2 px. Or ces deux teintes sont aussi, au mot près du commentaire de
`menu_theme.gd`, « la couleur du curseur qui parcourt les menus » : un bouton
« lanceur » portait donc en permanence la couleur que le liseré de sélection ne
devrait porter qu'en le visant.

Le fond et le cadre au repos sont désormais identiques à toutes les entrées
(`MenuTheme.SURFACE` / `MenuTheme.LINE`), lanceur ou non — c'est ce qu'Adrien
demandait : la même couleur que le reste. Ce qui distinguait déjà « ouvre un
écran » de « s'active sur place » — le chevron — n'a pas changé. Un lanceur se
reconnaît maintenant à son libellé en gras (`FontVariation.variation_embolden`
sur `ThemeDB.fallback_font`, le projet n'a pas de police à poids multiples) plutôt
qu'à une couleur.

**QUITTER** en profite pour redevenir tout à fait ordinaire (`launcher` retiré de
son appel) : la décision du 2026-08-17 soir — « il ne doit pas crier plus fort que
ce qui engage une partie » — s'était perdue quand l'entrée avait déménagé de la
barre d'actions vers l'accueil du hub, sans que personne ne le remarque parce que
la couleur produisait toujours la bonne intuition (rouge = destructeur), même sans
le style plein.

**Non vérifié** : le rendu réel n'a pas pu être capturé dans cette session (pas de
binaire Godot dans l'environnement d'exécution) ; `tools/test_menu_hub.gd` ne teste
que la navigation, jamais le style, et ne peut donc pas garantir ce correctif à lui
seul. À confirmer à l'écran par Adrien.

---

## Phase 6 — Rangs ✅ CLOSE le 2026-08-18

Ne reste qu'une vérification humaine : voir son rang s'afficher après un vrai
match classé, à deux identités éphémères. Elle tombera d'elle-même dans l'essai
d'appariement, le rang se lisant depuis le menu.

**Ce qui a été livré, et le défaut qu'il a fallu trouver pour y arriver.** Le
serveur calculait la catégorie et l'envoyait pour chaque ligne du classement
depuis le 2026-08-17 — la lecture de **sa propre ligne** n'en retenait rien
(`431daba`). Le travail serveur était fait et n'atteignait pas l'écran ; c'est le
genre de manque qu'aucune erreur ne signale, puisque chaque moitié fonctionne.

Le rang est retenu **tel que le serveur le rend**, jamais recomposé. Recoller
« Bougie » et « II » côté jeu rejouerait une règle qui appartient au serveur, et
le jour où l'échelle bougerait le jeu afficherait l'ancienne sans la moindre
erreur.

Deux absences sont traitées comme des absences : un joueur jamais classé n'a pas
de catégorie — rien ne s'affiche plutôt qu'un « Aveugle I » inventé — et Candela
n'a pas de division, ce que l'écran dit au lieu de laisser un blanc.

Une dizaine de catégories, chacune subdivisée en divisions, à la manière de
Rocket League.

### L'échelle — validée par Adrien le 2026-08-17

Une progression de l'obscurité vers la lumière, qui se termine sur le nom du jeu
— *candela* étant l'unité d'intensité lumineuse.

| # | Catégorie | # | Catégorie |
|---|---|---|---|
| 1 | Aveugle | 6 | Brasier |
| 2 | Braise | 7 | Phare |
| 3 | Bougie | 8 | Aurore |
| 4 | Lanterne | 9 | Zénith |
| 5 | Torche | 10 | Candela |

Les bornes de classement de chaque catégorie ne sont pas encore fixées : elles
n'ont de sens qu'avec une population réelle, et elles se changent sans migration
puisque le rang est dérivé (voir ci-dessous).

### Exposition côté serveur — faite le 2026-08-17

`standing` rend désormais une catégorie pour chaque ligne, la sienne comme celles
du haut du tableau.

**Deux « rangs » cohabitent, et les confondre produirait un affichage faux sans
jamais lever d'erreur.** `rank` vient de la base : c'est la **position** au
classement général, calculée par un `rank() over` dans la vue `leaderboard`.
`tier` vient de `rankOf` : c'est la **catégorie** de l'échelle. Le premier dépend
de tous les autres joueurs, le second de personne — gagner peut changer la
catégorie sans changer la position, et l'inverse. D'où deux clés distinctes.

La catégorie est calculée **côté serveur** et non dans le jeu : deux
implémentations de la même échelle divergeraient, et c'est le classement affiché
qui aurait tort.

Un joueur sans ligne au classement n'a **pas** de catégorie. Afficher « Aveugle I »
à quelqu'un qui n'a jamais joué serait un rang inventé, au même titre que les
« 1000 points » déjà écartés à l'étape 2b.

Déployée et vérifiée en ligne : 401 sans jeton, 401 sur un jeton contrefait.
La vérification de bout en bout avec deux identités éphémères reste à faire.

### La contrainte d'architecture : le rang est dérivé, comme le classement

Le rang doit être une **fonction pure du classement**, calculée à l'affichage et
jamais stockée. C'est la même décision que celle qui gouverne déjà la Phase 4 :
la table `ratings` est reconstruite en entier par un rejeu. Si le rang était
écrit en base, changer une borne d'échelle exigerait une migration de données ;
dérivé, cela ne coûte qu'un redéploiement.

Concrètement : `rankOf(rating)` dans `elo.ts`, testée hors ligne comme le reste,
et rien de nouveau dans le schéma.

---

## Phase 7 — Déblocage d'armes ✅ MÉCANIQUE CLOSE le 2026-08-18

**Il manque du contenu, pas du code.** Les catégories 5 à 10 ne débloquent rien
faute d'armes à débloquer : Torche, Brasier, Phare, Aurore, Zénith et Candela
retombent toutes sur le pistolet. C'est un trou à combler avec des assets, et il
appartient à Adrien — au même titre que les 76 fichiers audio.

Tout le mécanisme est en place et exercé :

- **la table** (`rank_loadout.gd`, `e4323a1`) — un rang, une **sélection**, et non
  un cran franchi. Elle n'est pas monotone, ce qu'un test vérifie explicitement
  pour qu'une relecture ne le « corrige » pas ;
- **le grisage** (`4f9a570`) — visible et grisé, jamais masqué, avec sa raison ;
  puis restreint au râtelier de celui qui porte le rang (`78b244e`) ;
- **la règle du miroir, opérationnelle** — la catégorie voyage dans le ticket ET
  dans l'état de membre (`d584b6a`), parce que l'annonceur n'a jamais lu le
  ticket de celui qui s'assied et qu'un seul chemin ne suffisait pas ;
- **la fenêtre de choix** (`50b4ed5`, `b76115f`, `be77bbb`) — dix secondes, un
  panneau modal, le choix borné à l'arsenal commun et **l'hôte qui refait le
  contrôle à la réception** : un index reçu n'est pas un droit ;
- **un banc dédié** (`d83810a`), sans réseau ni appariement.

Le cas exercé n'est pas neutre : Lanterne contre Braise, où le mieux classé doit
**descendre**. Un miroir inversé passerait tous les autres contrôles.

> **Aucune correspondance arme ↔ rang n'existe en code** au 2026-08-18 — seulement
> la table ci-dessous. Le premier geste de la phase est donc de l'écrire. Avec la
> décision du jour (un débutant part d'**Aveugle I**), la table d'origine redevient
> cohérente telle quelle : Aveugle → Pistolet, Braise → Fusil, Bougie → Pompe,
> Lanterne → Arbalète.

Chaque catégorie débloque une arme. Les quatre armes actuelles occupent les
quatre premières catégories ; **les catégories 5 à 10 ne débloquent donc encore
rien**, et c'est un trou à combler avec du contenu, pas avec une règle — les armes
réservées au compétitif et la mécanique de changement en cours de match (voir plus
bas) sont deux façons de le combler.

**Ce n'est pas un déblocage qui s'accumule** (précision d'Adrien, 2026-08-18).
Un joueur reçoit **la sélection attribuée à son rang**, et rien d'autre : un
Lanterne n'a pas quatre armes, il a l'Arbalète. La table associe un rang à une
**sélection**, pas à un cran franchi.

| Catégorie | Sélection attribuée |
|---|---|
| 1 — Aveugle | Pistolet |
| 2 — Braise | Fusil |
| 3 — Bougie | Pompe |
| 4 — Lanterne | Arbalète |
| 5 à 10 | Pistolet, faute d'armes supplémentaires |

Deux conséquences qu'une table naïve manquerait :

- **La progression n'est pas monotone.** Les rangs supérieurs redescendent au
  Pistolet ; une table qui supposerait « plus haut = plus d'armes » serait fausse
  dès Torche.
- **La table est saisonnière** — « ça changera peut-être à chaque saison ». Elle
  doit donc se remplacer sans toucher au reste, ce qui écarte de la coder en dur
  dans l'interface.

Elle rend une **sélection** (un tableau) et non une arme, même quand celle-ci n'en
contient qu'une : le jour où le changement en cours de match arrive, rien ne
change dans la forme. La règle du miroir devient « la sélection du moins bien
classé », et se compose sans réécriture.

**Le socle amical est fixé** : Pistolet, Fusil, Pompe, Arbalète — libres en écran
partagé et dans tous les modes amicaux, **pas** en compétitif, où seule la
sélection du rang vaut.

**Le miroir suit le rang, pas la richesse de l'arsenal.** Conséquence directe de
la non-monotonie, et elle surprend : un Candela qui affronte un Lanterne prend
**l'Arbalète**, alors que sa propre sélection est le Pistolet. La règle dit « la
sélection du moins bien classé », et le moins bien classé des deux est ici le
mieux armé. C'est cohérent — l'arsenal commun est celui que les deux peuvent
avoir — mais tout code qui prendrait « l'intersection » ou « le plus pauvre des
deux arsenaux » serait faux.

~~**En local, toutes les armes sont accessibles** (décision du 2026-08-16)~~ —
**superseded le 2026-08-18** par la décision ci-dessous. La raison d'origine
(« l'écran partagé n'est pas classé, rien n'y justifie un verrou ») reste vraie
pour le socle commun ; elle ne l'est plus pour les armes réservées au classé, qui
ne se donnent pas gratuitement parce qu'on joue seul.

### L'asymétrie en match classé — tranchée : règle du miroir

**Décision d'Adrien, 2026-08-17 : les deux joueurs ont toujours le même arsenal
en match classé, et cet arsenal est celui du moins bien classé des deux.**

Le problème qu'elle résout : verrouiller des armes derrière le rang donnerait au
mieux classé des options que l'autre n'a pas, dans un duel 1v1 où l'équilibre est
tout. Le cas le plus net est l'**Arbalète** — 80 de dégâts, `emits_light = false`,
flash quasi nul : l'arme furtive, et la quatrième débloquée. Sans cette règle, un
joueur Lanterne aborderait un joueur Braise avec un outil que celui-ci ne peut pas
avoir.

Ce que la règle coûte, et qu'il faut assumer dans l'interface : **l'arsenal d'un
joueur change selon l'adversaire.** Un joueur Candela qui affronte un Aveugle se
retrouve au Pistolet. Si l'écran ne l'explique pas au moment où ça arrive, ce sera
vécu comme un bug — c'est le principal risque de cette décision, et il est
d'affichage, pas de logique.

Trois conséquences concrètes :

- Le salon doit annoncer l'arsenal commun **avant** le lancement, avec sa raison
  (« arsenal aligné sur *pseudo*, rang Braise »), et non le découvrir au moment
  de choisir.
- Les armes non retenues restent **visibles et grisées**, jamais masquées : un
  joueur doit voir ce qu'il possède même quand il ne peut pas l'utiliser.
- Le calcul de l'intersection appartient à l'hôte, comme tout le reste de
  l'autorité — le client l'affiche, il ne le décide pas.

En **local**, rien de tout cela ne s'applique : toutes les armes sont accessibles
(décision du 2026-08-16), l'écran partagé n'étant pas classé.

### Trois régimes d'arsenal — tranchés par Adrien le 2026-08-18

Ce n'est plus « classé contre local ». **L'arsenal se lit sur deux axes
indépendants** : quelles armes existent dans ce mode, et qui décide de celle qu'on
prend.

| Mode | Armes disponibles | Choix |
|---|---|---|
| **Amical** (en ligne *et* local) | Un **socle** débloqué pour tous | **Asymétrique** — chacun prend ce qu'il veut |
| **Compétitif** | Le socle **plus** les armes réservées au classé, selon le rang | **Symétrique** — règle du miroir |
| **Local hors debug** | Le socle seulement | Asymétrique |
| **Local en debug** | Tout, armes réservées comprises | Asymétrique |

**Ce qui change par rapport au 2026-08-16 :** le local n'ouvre plus tout. Les
armes réservées au compétitif n'y sont accessibles qu'en **mode debug** — donc
pour le développement, pas pour le joueur. Une arme gagnée en classé ne se
récupère pas en jouant seul.

**Ce qui change par rapport à la règle du miroir :** elle ne vaut **qu'en
compétitif**. En amical, deux amis peuvent s'affronter au Pistolet contre
l'Arbalète si ça leur chante — l'équilibre est une exigence de classement, pas
une exigence de jeu.

### Le changement d'arme en cours de match — mécanique de rang

**Décision d'Adrien, 2026-08-18.** À partir de certains rangs, en compétitif, on
ne choisit plus **une** arme mais une **sélection** au début du match, et on en
change **pendant** la manche.

C'est la première mécanique du jeu dont la *règle* dépend du rang, et non
seulement le contenu : **la difficulté monte avec l'échelle.** Un joueur haut
classé ne joue pas au même jeu qu'un débutant — il en joue une version qui demande
davantage.

**Absent de l'amical**, quel que soit le rang des joueurs.

#### Périmètre immédiat — arrêté par Adrien le 2026-08-18

**On reste aux quatre armes actuelles sur les quatre premiers rangs**, dans
l'ordre de la table ci-dessus. Les armes des rangs supérieurs et le rang qui
ouvre le changement en cours de match **se décideront bien plus tard** : ce ne
sont pas des questions ouvertes qui bloquent, ce sont des décisions ajournées.

Ce qui se construit maintenant doit donc simplement **ne pas les rendre plus
difficiles à ajouter** — en particulier ne pas supposer « une arme par joueur »
là où il y aura une sélection.

#### Ce que cette mécanique entraînera, à sa mise en chantier

- **À quel rang s'ouvre-t-elle**, et combien d'armes compte la sélection ?
- **La règle du miroir porte alors sur la sélection**, pas sur une arme unique —
  aligner deux sélections est un problème différent d'aligner deux armes.
- **C'est du netcode, pas seulement de l'interface.** Changer d'arme en cours de
  manche est une action de joueur de plus à répliquer, et la compensation de
  latence côté hôte rejoue l'historique : elle devra savoir quelle arme le joueur
  tenait à l'instant du tir, pas seulement laquelle il tient maintenant.
- **Quelles armes composent le socle**, et lesquelles sont réservées au classé ?
  Les quatre actuelles occupent les quatre premières catégories ; la frontière se
  posera avec les armes qui n'existent pas encore.

---

---

## Phase 8 — Appariement ✅ CLOSE CÔTÉ CODE le 2026-08-18

**Une seule inconnue subsiste, et elle est humaine : l'essai à deux fenêtres.**
Tout le reste est écrit, exercé, et une partie est prouvée contre le vrai service.

Ce qui a été livré au-delà du plan, et pourquoi :

- **plus de confirmation à l'appariement.** Adrien a vu passer la fenêtre de sept
  secondes sans avoir le temps de cliquer ; lui redemander s'il veut ce qu'il
  vient de demander ne servait à rien et faisait perdre l'appariement à qui
  hésite. Le bandeau annonce le lancement, le match part. Ce que ça coûte est
  écrit dans les tests retournés : **on ne peut plus renoncer entre « trouvé » et
  « lancé »** — le refus a été retiré avec la confirmation, parce qu'il aurait
  permis d'abandonner à l'instant où l'autre camp s'engage ;
- **un recul avant republication du ticket.** Les consoles d'Adrien montraient
  cinq tickets d'un côté, trois de l'autre, puis `create_lobby: TimedOut`,
  `join_lobby: TimedOut`, `search_for_lobbies: NoConnection`. La cause n'est pas
  l'élargissement de fourchette — il ne republie rien — mais le fait que
  `queue_join_async` **détruit notre ticket avant** de tenter la jointure : une
  jointure qui expire nous laisse sans ticket, le ticket perdu republie, la
  recherche retente. Chaque tour crée et détruit un salon. Le recul double à
  chaque échec (2 s → 16 s) et suspend la recherche plutôt que de la faire tourner
  à vide ;
- **la fenêtre de choix d'arme** de la Phase 7 s'ouvre sur ce chemin.

### ⚠️ Le banc de match en ligne est une couverture conditionnelle

`tools/test_online_match.tscn --host/--join` est **instable sur une machine
chargée**, constaté le 2026-08-18 : deux passages consécutifs, deux échecs
différents — d'abord le ping applicatif à zéro, puis l'écran de fin, la killcam et
le score. Le chiffre qui permet de trancher est le **ping applicatif : 155 ms
contre 26 habituels**, avec plusieurs instances Godot en vol. Ce sont des
symptômes de famine de temporisateurs, pas de défauts de logique.

À lancer **au calme**, et à ne pas prendre pour un défaut sans avoir regardé ce
chiffre. Ses modes `--local`, `--training` et `--fenetre` sont dans le lanceur et
ne souffrent pas de ça : un seul processus, aucun réseau.

## Ce qu'il reste — l'ancienne section, conservée pour le détail

Les deux entrées « Chercher un match » sont grisées dans le hub depuis le
2026-08-17. Cette phase les allume.

### Ce qui existe déjà, et qu'il ne faut pas réécrire

Beaucoup, et c'est ce qui rend la phase abordable : **identité vérifiée** auprès
d'Epic, **classement déployé** et recalculable, **rangs dérivés**, **salons EOS**
avec traversée de NAT et recherche filtrée (`bucket_id ET code`), **double
rapport** de match avec détection de concordance, et le **forfait** sur abandon.

Ce qui manque tient en trois choses : une file d'attente, une règle de
désignation de l'hôte, et une distinction entre match amical et match classé.

### ⚠️ Le défaut à corriger AVANT tout le reste

**Rien ne distingue aujourd'hui un match amical d'un match classé.**
`report_match` n'a pas de paramètre pour cela, et `recomputeRatings()` relit
« tous les matchs concordants » sans filtre. Vérifié le 2026-08-17 dans
`20260816210000_match_reports.sql` et `ranking.ts`.

Conséquence : le jour où un match amical devient jouable, **il alimentera l'ELO
en silence**. Personne ne s'en apercevra avant de voir un classement absurde, et
il faudra alors deviner quels matchs étaient amicaux — information qui n'aura pas
été écrite. C'est un défaut de correction, pas une fonctionnalité manquante, et
il se corrige pour presque rien tant qu'aucun match amical n'existe.

### Étape 8.1 — séparer amical et classé ✅ CLOSE, déployée le 2026-08-17

Type `public.match_kind` (`friendly` / `ranked`), colonne `kind` sur
`match_reports` avec **défaut `friendly`** — le défaut *est* la règle : un insert
qui oublie la nature écrit un amical, jamais un classé.

**`concordant` change de sens sans changer de nom** : il exige désormais aussi que
les deux pairs aient déclaré la même nature. Tout lecteur qui filtrait déjà sur
`concordant` hérite de la protection sans l'avoir demandée — et le rejeu du
classement en faisait partie.

La vue rend `kind` à **`null`** quand les deux se contredisent, et non
`'friendly'` : « ils ne sont pas d'accord » n'est pas « ils ont déclaré amical »,
et un filtre sur `ranked` écarte les deux cas. `kind_a` et `kind_b` sont exposées
brutes pour qu'un litige soit diagnosticable au lieu d'être seulement écarté.

**Le passé est décidé, pas deviné :** tout ce qui était en base a été joué avant
que l'amical existe, donc `update … set kind = 'ranked'` sans clause. Les tables
étant vides depuis la purge des essais de la Phase 4, l'ordre n'a touché aucune
ligne — mais il devait être écrit pour la prochaine fois.

Trois précautions de déploiement qui ne vont pas de soi :

- **`p_kind` est le dernier paramètre, avec un défaut**, parce que le déploiement
  n'est pas atomique : entre la migration et la fonction, l'ancien code appelle
  encore sans nature. Le défaut lui évite d'échouer, et `null` valant amical,
  l'intervalle peut au pire faire *manquer* des matchs — jamais en inventer.
- **`drop function` puis `create`, et non `create or replace`** : une liste de
  paramètres différente crée une **surcharge**. L'ancienne fonction sans nature
  serait restée appelable, PostgREST choisissant d'après les clés du corps.
- Le corps refuse volontairement le cast `p_kind::public.match_kind` : sur un mot
  inconnu il lèverait `22P02` et **ferait perdre le rapport**, alors que c'est le
  rapport qui fait foi.

Déployées et vérifiées en ligne : 401 sans jeton sur `/report` comme sur
`/standing`. **Ce qui reste invérifiable sans base locale** — aucun Postgres ni
Docker sur ce poste : la résolution des types à l'exécution, les droits, et le
comportement réel de PostgREST sur `kind=eq.ranked`. La vérification de bout en
bout avec deux identités éphémères reste due, et elle couvrira ces trois points.

#### Le détail des trois règles

Un champ sur `match_reports`, joint par les deux pairs, et un filtre dans le
rejeu. Trois précautions qui ne vont pas de soi :

- **Le classé doit être le cas explicite, l'amical le défaut.** Si le champ
  manque ou vaut `null`, le match ne compte pas. Un bogue de client ne doit pas
  pouvoir *ajouter* des matchs au classement — l'inverse se rattrape par un
  rejeu, pas celui-là.
- **Les deux pairs doivent être d'accord sur la nature du match**, comme ils le
  sont déjà sur l'issue. Un match où l'un déclare « classé » et l'autre
  « amical » est discordant : il ne compte pour rien, exactement comme deux
  récits qui se contredisent.
- **La migration doit décider du passé.** Les matchs déjà en base ont été joués
  avant que l'amical existe : ils sont classés. À écrire dans la migration plutôt
  qu'à supposer.

### ⚑ Vérifié contre le vrai EOS le 2026-08-17 — le filtre entier fonctionne

**La question qui pouvait invalider toute la Phase 8 est tranchée : oui.** EOS
accepte un filtre entier avec `GreaterThanOrEqual` et `LessThanOrEqual` sur
l'attribut de classement. `tools/test_queue.tscn` l'établit contre le service
réel, avec une identité éphémère : ticket publié à 1000, puis quatre requêtes
acceptées — fourchette bornée des deux côtés, borne basse seule, borne haute
seule, et sans borne. Les deux files (`RANKED` / `CASUAL`) répondent séparément.

L'élargissement par fourchettes fines tient donc tel qu'il est écrit. Le repli
prévu — publier des paliers nommés en chaîne et filtrer par égalité — n'est pas
nécessaire.

### ⚑ Match complet à deux fenêtres — validé le 2026-08-18 par Adrien

Premier parcours de bout en bout entre **deux identités Epic distinctes**, par le
chemin du salon à code. Vert des deux côtés, `EXIT_CODE: 0`, ping applicatif
26 ms.

Ce qui cesse d'être une supposition : le code se crée, s'affiche, se transmet et
se saisit ; **`PRÊT` reste grisé tant que l'hôte est seul** et s'ouvre à l'arrivée
de l'adversaire ; **aucune manche ne démarre à la connexion** (la porte de l'autre
session tient contre le vrai réseau) ; la manche se joue, la killcam rejoue 3/3
balles, l'écran de fin se pose, **le lien tient après la killcam**, et le rematch
relance une manche.

**Ce que cet essai ne prouve pas**, et qu'il ne faut pas lui faire dire :
l'appariement automatique n'y figure pas — c'est le chemin du code de salon. Et
les deux instances tournant sur la même machine et le même réseau, **ni la
traversée de NAT ni la latence réelle ne sont exercées** : H1 reste dû.

Deux erreurs dans la trace ne sont pas des défauts (`packet_sequence.is_null()`,
`states[…].playback.is_null()`) : l'audio est câblé sur des fichiers absents.
Une troisième l'était — `No multiplayer peer is assigned`, corrigée le jour même.

### ⚑ Découverte croisée prouvée le 2026-08-18 — deux identités se voient

Le banc à une instance ne prouvait que l'acceptation de la requête. **Deux
instances décalées de 2 secondes** lèvent le doute suivant : deux PUID distincts
(`0002…6377`, `0002…ae35`), deux tickets publiés, et **1 candidat vu de chaque
côté** dans la fourchette [940, 1060]. Une identité voit donc bien le ticket
d'une autre, à travers le filtre entier borné des deux côtés, contre le vrai
service. Marche à suivre reproductible :
[PROTOCOLE_TEST_EOS.md](PROTOCOLE_TEST_EOS.md).

Deux mesures obtenues en passant, qui ne se devinaient pas :

- **2 secondes d'écart suffisent** entre deux lancements éphémères. Le piège
  connu disait « les espacer » sans dire combien.
- **Un ticket fermé traîne ~1 minute dans l'index d'Epic.** Relevé sans le
  chercher : un troisième lancement solo a trouvé 1 candidat — un fantôme — puis
  0 deux minutes plus tard. La recherche proposera donc parfois un adversaire
  mort ; la jointure échoue et le délai de garde de 45 s l'écarte. La conception
  l'absorbe déjà, mais il fallait le savoir avant de le prendre pour un défaut.

Ce que ces bancs **ne** prouvent toujours pas, et qui reste dû : la **jointure**,
la poignée de main par engagement-révélation, l'**accord des deux camps sur qui
héberge**, et la connexion. Ces quatre-là ne s'exercent que par le jeu — donc
derrière les deux entrées encore grisées, puis avec deux fenêtres, donc Adrien.

Le banc est une **scène** et non un script : un `--script` compile
`network_manager.gd` avant l'enregistrement des autoloads du plugin EOS.

### Étape 8.2 — où vit la file d'attente

**Deux mécanismes possibles, et le choix n'est pas neutre.**

**A — Les salons EOS, par recherche filtrée.** Un joueur en attente publie un
salon portant sa fourchette de classement en attribut ; le chercheur filtre
dessus. C'est le mécanisme *déjà en place* pour le code à six caractères : la
jointure par recherche filtrée existe et fonctionne. Aucun service nouveau, aucun
coût d'hébergement, et la traversée de NAT est déjà résolue.
Sa limite est réelle : EOS filtre sur des attributs, il ne sait pas « le plus
proche ». On cherche donc par **fourchettes discrètes** qu'on élargit avec
l'attente, ce qui apparie moins finement qu'un vrai matcheur.

**B — Supabase comme file.** Une table de file, une fonction qui apparie, un
élargissement continu. Apparie mieux, et coûte cher : il faut détecter la
**présence** (un joueur qui ferme le jeu doit quitter la file — sans quoi on
apparie des fantômes), gérer la **double réservation** (deux joueurs appariés au
même troisième), et faire tourner le matcheur quelque part, les Edge Functions
étant liées à une requête.

**Recommandation : A d'abord.** La fourchette discrète est un défaut visible et
mesurable ; l'appariement fantôme est un défaut invisible qui use la confiance.
Avec une population faible — la situation réelle du jeu — **la finesse
d'appariement ne sert à rien : il n'y a personne à départager.** B se justifiera
quand la file sera assez peuplée pour que le choix entre deux adversaires ait un
sens, et rien de A n'est à jeter ce jour-là : le salon reste le lieu du match, le
matcheur ne fait que désigner qui rejoint qui.

### Étape 8.3 — qui devient l'hôte, et pourquoi c'est un sujet d'équité

**En P2P, l'hôte simule tout et joue à 0 ms.** C'est déjà écrit dans « Décisions
actées » comme le prix assumé de l'absence de serveur dédié. En match amical par
code, la question ne se pose pas : celui qui crée le salon est l'hôte, et les
deux joueurs le savent.

**En classé, la désignation silencieuse de l'hôte devient un avantage
distribué par le système.** Trois issues :

1. **Le chercheur rejoint l'hébergeur.** Simple, et injuste de façon systématique
   : qui attend le plus héberge le plus.
2. **Tirage au sort après appariement.** Équitable en espérance. Demande que le
   tirage ne soit pas fait par l'un des deux — donc côté serveur, ou dérivé d'une
   valeur qu'aucun des deux ne contrôle (l'identifiant de match, déjà tiré en
   16 octets cryptographiques).
3. **Alternance en cas de revanche.** Le meilleur des trois si les revanches
   s'enchaînent, et il ne coûte presque rien puisque le salon persiste.

### ✅ Tranchée, et implémentée : 2 pour le premier match, 3 pour les revanches

**La recommandation a été suivie, et le code la dépasse sur un point.** Ni Adrien
ni personne n'a eu à arbitrer entre les trois : la solution 2 était la seule qui
ne distribue pas un avantage, et la 3 s'y ajoute sans rien coûter.

`designate_host(match_id, key_a, key_b)` ordonne les deux identités
canoniquement, puis lit **un bit de `sha256("match_id|bas|haut")`**. Le hachage
n'est pas une précaution de style : lire directement les bits de l'identifiant
donnerait un tirage systématiquement biaisé le jour où un appelant y mettrait un
compteur au lieu de 16 octets cryptographiques. L'ordonnancement canonique, lui,
est ce qui fait que **les deux machines désignent le même hôte** — chacune appelle
avec elle-même en premier, et sans lui elles se désigneraient l'une l'autre.

`host_for_series()` alterne ensuite à chaque revanche : le tirage n'a lieu qu'une
fois, pour le premier match de la série.

**Et l'identifiant de match lui-même est tiré par engagement-révélation**, ce qui
rend « aucun des deux ne contrôle le tirage » littéralement vrai au lieu d'être
affirmé. L'hébergeur publie `sha256(nonce)` dans son ticket **avant qu'aucun
adversaire n'existe** ; le joueur déclare son propre nonce en étant aveugle à
cette valeur ; l'hébergeur révèle, et le joueur vérifie la révélation contre
l'engagement publié. L'hébergeur ne peut pas moudre — il est lié par son
engagement — et le joueur non plus, il est aveugle.

Vérifié sur 20 000 tirages par famille d'identifiants (séquentiels, chaînés,
cryptographiques), puis 400 000 hors suite pour confirmer que des écarts de
0,6 point étaient du bruit d'échantillonnage. Le test attrape explicitement la
régression classique : une désignation qui rendrait « la plus petite identité »
passe le déterminisme **et** la symétrie, et n'est prise que par les contrôles de
biais.

**Et c'est affiché** : le bandeau dit « vous hébergez » ou « il héberge » dès que
la désignation est connue. En P2P l'hôte joue sans latence et l'autre non — une
asymétrie qu'on n'affiche pas devient une rumeur.

### Étape 8.4 — la poignée de main à deux

Appariés n'est pas connectés. Il faut : les deux **acceptent** dans un délai
borné, l'un **refuse ou expire** → l'autre retourne en file **sans perdre son
tour**, et une **annulation** possible pendant l'attente.

Le piège classique, à écrire avant de coder : un joueur qui accepte puis ferme le
jeu doit être traité comme un refus, pas comme une acceptation qui ne se conclut
jamais. C'est-à-dire qu'il faut un **délai d'expiration côté chercheur**, jamais
une attente indéfinie d'un signal qui ne viendra pas.

### Étape 8.5 — élargir la fourchette avec l'attente

Une seule règle, et elle doit être annoncée à l'écran : la fourchette s'élargit
par paliers, et le joueur voit **quelle fourchette est cherchée en ce moment**.
Une recherche qui tourne sans dire ce qu'elle cherche donne l'impression d'être
cassée au bout de vingt secondes.

À décider : y a-t-il un plafond au-delà duquel on refuse d'apparier ? Un Candela
contre un Aveugle est un match perdu pour les deux — la règle du miroir des armes
en fait un match jouable, pas un match intéressant.

### Étapes 8.2 à 8.5 — le cœur de l'appariement 🟡 écrit, non raccordé

`matchmaking.gd` porte la file, la désignation de l'hôte, la poignée de main et
l'élargissement. Cinq états, une doublure de transport pour les tests, et **aucun
`if transport == …`** — la primitive de file vit dans `network_manager.gd`.

**L'identifiant de match est tiré par engagement-révélation**, et c'est ce qui rend
« aucun des deux ne contrôle le tirage » littéralement vrai au lieu d'être affirmé.
L'hébergeur publie `sha256(nonce)` dans son ticket **avant qu'aucun adversaire
n'existe** ; le joueur déclare son propre nonce en étant aveugle à cette valeur ;
l'hébergeur révèle alors, et le joueur vérifie la révélation contre l'engagement
publié — divergence, refus. L'hébergeur ne peut pas moudre, il est lié par son
engagement ; le joueur non plus, il est aveugle.

**La désignation est pure et prouvée sans biais.** `designate_host` ordonne les
deux clés canoniquement puis lit un bit de `sha256("match_id|bas|haut")`. Hacher
plutôt que lire les bits de l'identifiant compte : un appelant passant un compteur
obtiendrait sinon un tirage systématiquement biaisé. Vérifié sur 20 000 tirages par
famille d'identifiants (séquentiels, chaînés, cryptographiques, et « est-ce la plus
petite identité ? »), puis 400 000 hors suite pour confirmer que les écarts de
0,6 point étaient du bruit d'échantillonnage. Alternance en revanche.

Le test attrape explicitement **la régression classique** : une désignation qui
rendrait « la plus petite identité » passe le déterminisme *et* la symétrie, et
n'est prise que par les contrôles de biais. La symétrie elle-même est testée parce
que chaque machine appelle avec elle-même en premier — sans elle, les deux
désigneraient des hôtes différents et personne n'ouvrirait la connexion.

**Paliers d'élargissement** : ±60, ±120, ±240, ±480, puis sans filtre, à 0 / 15 /
35 / 60 / 90 s. Adossés à l'échelle réelle d'`elo.ts` — une division vaut 40
points, une catégorie 120 : ±60 est une demi-catégorie, ±480 en vaut quatre,
déséquilibré mais jouable sous la règle du miroir. Le plafond que l'étape 8.5
laissait à Adrien est **ouvert par défaut** : avec cette population, ne pas jouer
est un plus mauvais appariement que jouer contre plus fort. Une valeur à changer
dans la table.

#### ✅ Raccordé le 2026-08-18 — ce qui manquait, et ce qui manque encore

Les quatre points listés ici la veille : **deux étaient déjà faits sans que le
document le sache.** Les suites d'appariement ne sortent plus en 139 et
l'autoload `Matchmaker` est déclaré depuis `05b72c7`. Vérifier avant de croire un
document est décidément la leçon de la semaine.

**Ce qui manquait vraiment, et qu'aucune relecture n'avait vu :** personne
n'écoutait `match_ready`. Le cœur établissait le lien — `host_matched_game()` /
`join_matched_game()` — puis émettait dans le vide. Les deux machines se
connectaient et **restaient chacune dans leurs menus**, l'appariement
« fonctionnant » sans qu'aucune manche ne démarre. C'est le genre de manque qu'un
test unitaire ne trouve pas : chaque pièce faisait son travail.

Sont donc posés :

- `game_state.gd` écoute `match_ready`. L'hôte tire une carte au sort, prépare la
  partie et lance ; le client entre par `connection_success`, qui faisait déjà
  tout — le faire entrer deux fois relancerait sa manche par-dessus elle-même.
- **`MapData.select_random_map()`**, qui n'existait pas. « Cartes tirées au
  hasard » était une intention écrite dans l'arborescence du hub, jamais du code.
  Seul l'hôte tire ; le client adopte par `rpc_start_round`, comme dans un salon.
- **Le choix d'arme avant la file**, et la question qu'il pose : on choisit son
  arme **sans savoir de quel côté on tombera**, la désignation de l'hôte n'ayant
  lieu qu'une fois l'adversaire trouvé. L'hôte lit le râtelier de J1, l'invité
  celui de J2. D'où un seul râtelier montré, reporté sur l'autre au moment de
  partir (`UI.mirror_weapon_choice()`). Sans cela, **un joueur sur deux partait au
  pistolet** — et en BO1, aucun rematch ne rattrape le choix.

**Ce qui reste, et ce n'est plus du code :** l'essai à deux fenêtres. La
découverte est prouvée ; la jointure, la poignée de main, l'accord sur qui héberge
et la connexion ne s'exercent que par le jeu. Protocole dans
`docs/PROTOCOLE_TEST_EOS.md`.

### Étape 8.6 — la recherche se fait en arrière-plan ✅ CLOSE

**Décision d'Adrien, 2026-08-18 : chercher un match n'ouvre pas d'écran.** L'appui
lance la file et rend la main ; la recherche continue pendant qu'on parcourt les
menus, qu'on change d'arme, qu'on lit son classement. Un bandeau collé au bord
haut, centré au-dessus du titre du jeu, dit en permanence où elle en est et porte
les seuls gestes qui comptent : annuler, confirmer, refuser.

C'est la seule disposition qui ne mente pas sur la nature de l'attente. Un écran
dédié immobilise le joueur devant un compte à rebours qu'il ne peut pas
accélérer — il transforme une opération de fond en salle d'attente.

`match_banner.gd` porte tout cela, avec sa suite (33 assertions). Deux invariants
y sont verrouillés, et ce sont ceux qui se paient au classement :

- **Une sortie, toujours.** Dans chacun des quatre états non inertes, il existe un
  contrôle visible, non désactivé et atteignable au curseur pour quitter la file.
  Sans lui la seule issue serait de fermer le jeu.
- **Deux emplacements fixes, rangés par intention.** Ce qui engage à gauche, ce
  qui retire à droite, et jamais l'inverse. Un bouton unique passant d'ANNULER à
  CONFIRMER quand l'adversaire arrive confirmerait un match à un doigt qui partait
  pour **sortir** de la file. La suite vérifie que l'emplacement de sortie reste
  le même objet à travers la transition.

**Refuser n'est pas annuler**, et le bandeau appelle bien deux méthodes
différentes : refuser un match trouvé remet en file **sans perdre le temps déjà
attendu** ; annuler quitte. Les confondre ferait perdre sa place à qui vient de
dire vouloir continuer.

#### `screen_matchmaking.gd` n'est plus utilisé

Les 972 lignes de l'écran plein et ses ~1 000 lignes de suite **restent au
dépôt** : ils sont justes, testés, et rien ne prouve encore que le bandeau
suffise à l'usage. Le fichier n'est plus dans l'arborescence du hub et sa suite
teste donc un écran que personne n'atteint. **À trancher par Adrien après le
premier essai à deux fenêtres** : soit le bandeau tient et les deux fichiers
partent, soit un écran de détail revient et il est déjà écrit.

### ~~Étape 8.6 — l'écran de recherche~~ (conception d'origine, remplacée)

`screen_matchmaking.gd` tient sept états, dont ceux qui font tout le travail : la
recherche en cours **avec la fourchette cherchée en ce moment**, le match trouvé
avec les deux identités et **qui héberge**, le refus adverse, et l'indisponibilité.

**Le contrat supposé pour `matchmaking.gd`**, écrit avant que ce fichier n'existe
et à honorer au raccordement :

```gdscript
signal matchmaking_changed                    # sans argument
func matchmaking_snapshot() -> Dictionary
func start_search(ranked: bool) -> void
func cancel_search() -> void
func accept_match() -> void
func decline_match() -> void
```

Instantané : seules `configured` et `phase` sont obligatoires. **Une clé absente
veut dire « je ne sais pas »**, et l'écran n'affiche alors rien plutôt que de
deviner.

Quatre décisions qui méritent d'être lues avant de toucher à cet écran :

- **`phase` circule en chaîne, pas en énumération.** Deux raisons cumulées : un
  `preload()` sur un chemin absent échoue à l'analyse et emporterait l'écran
  entier ; et un miroir d'énumération recopié lirait « match trouvé » là où l'autre
  moitié dit « en recherche », **sans la moindre erreur**. Une chaîne inconnue se
  détecte, un entier faux se confond avec zéro.
- **Tout ou rien sur l'API.** Si l'une des cinq méthodes manque, l'écran passe en
  « indisponible » — même s'il pourrait lire l'instantané. Un instantané lisible
  sans `accept_match()` donnerait un bouton CONFIRMER qui ne fait rien, et un
  bouton mort ne se distingue pas d'un jeu cassé.
- **Deux emplacements fixes, rangés par intention et non par importance** :
  engagement en haut, retrait en bas. Un unique bouton passant d'ANNULER à
  CONFIRMER quand l'adversaire arrive confirmerait un match à quelqu'un qui
  appuyait pour **sortir** de la file. Un test vérifie que l'emplacement d'abandon
  reste le même objet à travers la transition.
- **`host_is_me` absent ⇒ « hôte pas encore désigné »**, jamais une déduction.
  Deviner d'après qui cherchait serait juste une fois sur deux.

L'explication de l'hébergement est **la même des deux côtés** — « sans serveur
dédié, c'est l'hôte qui simule le match : il joue sans latence, son adversaire
non ». L'asymétrie est une propriété du P2P, pas un reproche.

#### Ce qui reste de l'étape 8.6

Le raccordement à `matchmaking.gd` quand il existera, et l'ouverture des deux
entrées « chercher un match » aujourd'hui grisées.

### ~~Étape 8.6 — côté jeu~~ (périmètre d'origine)

Les écrans existent déjà, grisés. Il faut : un état de **recherche** (temps
écoulé, fourchette courante, annulation atteignable au curseur), l'écran de
**match trouvé** avec les deux identités et qui héberge, et le **retour en file**
sur refus adverse.

Contrainte d'architecture inchangée : hors de `network_manager.gd` et du bloc
lobby, **aucun fichier ne connaît le transport**. L'appariement est une affaire de
`network_manager.gd` ; le hub ne fait que demander et afficher.

### Étape 8.7 — abandon en file, et l'abus

Le forfait sur abandon **existe déjà** et fonctionne (`_archive_forfeit`, quatre
chemins convergents). Reste ce que l'appariement crée de neuf :

- **Esquive de file** — quitter avant que le match ne compte. Le forfait couvre le
  match commencé ; il ne couvre pas le refus répété d'appariement.
- **Échange de victoires** entre deux comptes complices. La concordance à deux
  rapports **ne protège pas de ça** : les deux mentent de concert et sont
  d'accord. C'est la limite structurelle du P2P, déjà notée, et l'appariement
  automatique la réduit sans l'annuler — on ne choisit plus son adversaire.
- **Comptes secondaires.** Le code de récupération est un secret au porteur : rien
  n'empêche d'avoir plusieurs profils. Proportionné pour un jeu à cette échelle,
  à revoir si les enjeux montent.

Aucun de ces trois points ne se résout par de la technique seule ; les écrire
évite de croire qu'un système d'appariement les règle.

### Étape 8.8 — la carte que l'autre n'a pas ✅ CLOSE (2026-08-18)

**Le cas est déjà résolu par construction, et personne ne l'avait écrit.** La carte
ne voyage pas par identifiant, elle voyage **par valeur** : `_host_map_code()`
produit le code de partage complet (`CANDELA-<base64(gzip(json))>`),
`rpc_start_round` le transporte, et le client appelle `adopt_shared_map()`, qui
reconstruit la géométrie **sans rien écrire sur le disque**. Une carte dessinée
cinq minutes plus tôt dans l'éditeur de l'hôte fonctionne donc chez l'invité qui ne
l'a jamais vue. Identique en EOS et en ENet — `rpc_start_round` ignore le
transport. En écran partagé la question ne se pose pas : une seule machine.

Trois propriétés en découlent, toutes voulues :

- le catalogue de l'invité n'entre jamais en jeu ;
- l'invité **ne conserve pas** la carte de l'hôte : `selected_map_id` passe à
  `"distante"` faute d'identifiant, et `user://maps/` n'est pas touché. Installer
  silencieusement le fichier d'un inconnu serait pire que de ne pas le garder ;
- seul l'invité adopte (`current_mode == ONLINE_CLIENT`) : l'hôte est déjà chez lui.

#### ⚠️ Ce qui est mal géré, et c'est grave

**L'échec de décodage ne fait qu'afficher un message, puis la manche démarre
quand même.**

```gdscript
var err := MapData.adopt_shared_map(map_code)
if err != "":
    ui.show_dialog_message("Carte", "Carte de l'hôte illisible : " + err)
_do_start_round(w1_idx, w2_idx)     # ← on continue
```

Les deux joueurs jouent alors sur **deux géométries différentes**, chacun sur la
sienne. Les balles de l'autre traversent des murs qui n'existent pas chez lui, la
torche éclaire une arène qui n'est pas là, et **les deux machines restent
parfaitement cohérentes avec elles-mêmes** : aucun plantage, aucune erreur, deux
joueurs convaincus que l'autre triche. C'est exactement la famille de défaut déjà
payée une fois avec l'appariement collision/occulteur.

Le décodage peut échouer pour quatre raisons, dont une **certaine** d'arriver :

1. **Version de codec différente** (`MapCodec.VERSION`). L'hôte tourne un build
   plus récent. C'est le cas courant en développement, et il se reproduira à chaque
   mise à jour publiée tant qu'il n'y a pas de mise à jour forcée.
2. Grille hors de `MIN_GRID`–`MAX_GRID` (8–128).
3. Code tronqué ou corrompu.
4. Garde-fou anti-bombe de 8 Mo.

**Et un cinquième cas, entièrement muet :** `map_code` vide. La garde
`if map_code != ""` fait alors *sauter l'adoption sans le moindre message*, et
l'invité joue sur sa carte précédente. Même divergence, sans même la boîte de
dialogue.

#### Ce qui a été fait

- **La manche ne démarre plus.** `rpc_start_round` refuse et sort ; c'était la
  seule règle qui comptait, tout le reste n'en est que la mise en œuvre.
- **Sans forfait pour le refusé.** Le jeton `_forfeit_pending` n'est armé que par
  `_do_start_round`, où l'on n'arrive jamais : `_on_main_menu_requested()` fait
  donc le ménage habituel sans rien archiver. Punir un joueur d'un écart de
  version aurait été le pire résultat possible.
- **L'hôte est prévenu** (`rpc_map_refused`), avant la déconnexion qui coupe le
  lien. Sans ce paquet il resterait seul dans son arène à attendre un adversaire
  déjà parti, et finirait par lui compter la victoire.
- **`map_code` vide est un échec**, plus « rien à faire ».
- **`tools/test_carte_partagee.gd`** — quinze assertions sur les cinq cas, sans
  réseau ni seconde machine. Le jeu d'essai dérive de la vraie carte livrée : un
  décor écrit à la main finirait par diverger du format réel, et la suite
  validerait un format que le jeu n'écrit plus.

**Deux défauts trouvés en écrivant la suite**, tous deux dans `map_codec.gd` :
`validate()` et `get_grid_size()` lisaient `grid_size` dans une variable typée
`Dictionary`. Un JSON qui met autre chose sous cette clé **jette une erreur de
script** au lieu du refus propre que toute la fonction s'applique à produire —
l'appelant reçoit `null` et lit `["ok"]` dessus. Or `validate()` est précisément
la porte d'entrée de tout code venu d'ailleurs. Les deux sites vérifient
désormais le type avant de lire.

#### Ce qui reste

**Comparer les versions à la connexion**, et non au lancement de la manche. Le
refus actuel est propre mais tardif : il arrive après la poignée de main, une
fois les deux joueurs engagés. L'échange devrait avoir lieu à la porte.

La difficulté n'est pas l'échange lui-même mais **le fait qu'il doive survivre à
ce qu'il mesure** : deux builds dont les RPC ont des arités différentes se jettent
mutuellement les paquets **sans aucune erreur console**. Un contrôle de version
posé dans un RPC est donc muet exactement dans le cas qu'il devait détecter. Il
faut un canal dont la forme ne change jamais — un paramètre optionnel n'y suffit
pas à lui seul. À concevoir avant d'écrire.

#### La question d'équité que le tirage au sort vient d'ouvrir

`select_random_map()` (livrée le 2026-08-18) tire dans **tout le catalogue de
l'hôte, cartes importées comprises**. En match classé, on peut donc être envoyé sur
une arène que l'adversaire a dessinée et que l'on découvre en jouant — pendant que
lui la connaît par cœur. Ce n'est pas un défaut technique, c'est un arbitrage :

- restreindre le tirage classé aux **cartes livrées** (slugs réservés de
  `res://assets/maps/`), ou
- l'ouvrir et considérer que la connaissance d'une arène fait partie du jeu.

**À trancher par Adrien.** Le tirage est aujourd'hui ouvert par défaut, et la
restriction tient en une ligne de filtre sur `source == "builtin"`.

### Étape 8.9 — se reconnaître avant de jouer ✅ CLOSE (2026-08-18)

Reste de l'étape 8.8. Le refus d'une arène illisible est propre mais **tardif** :
il arrive après la poignée de main, une fois les deux joueurs engagés. La
comparaison devrait avoir lieu à la porte.

#### Le piège qui rend l'exercice non trivial

**Un contrôle de version posé dans un RPC est muet exactement dans le cas qu'il
devait détecter.** Godot route les RPC par nom *et* par arité : deux builds dont
les signatures diffèrent se jettent mutuellement les paquets **sans aucune erreur
console**. Le build v2 qui ajoute `rpc_hello(version: int)` n'obtient jamais de
réponse d'un build v1 — non pas parce que les versions diffèrent, mais parce que
le message n'existe pas là-bas. Et un silence ne se distingue pas d'un réseau
lent.

C'est le même défaut, une couche plus bas, que celui déjà payé sur les noms de
nœuds auto-générés : **un RPC jeté ne dit rien.**

#### La règle qui en découle

**Le canal doit être figé pour toujours ; seule sa charge évolue.**

Un unique RPC, une seule signature, jamais modifiée :

```gdscript
@rpc("any_peer", "reliable")
func rpc_hello(payload: String) -> void:
```

Tout voyage **dans** la chaîne, en JSON. La forme ne bougeant plus jamais, l'arité
ne peut plus diverger ; les champs, eux, s'ajoutent librement — un champ inconnu
s'ignore, un champ absent vaut « ne sait pas ». C'est le seul RPC du jeu qui ait
le droit d'être appelé par un pair dont on ignore la version.

#### Mieux : ne pas avoir besoin du RPC

Sur les deux chemins EOS, **la version peut voyager avant toute connexion**, dans
les données de rendez-vous :

- **Salon à code** — l'hôte publie déjà `EOS_CODE_ATTRIBUTE` sur son salon. Un
  attribut `protocol` de plus est lu par le client **pendant la recherche**,
  c'est-à-dire avant `create_client()`. Divergence → refus à la porte, avec un
  message qui nomme la cause.
- **File d'appariement** — le ticket porte déjà classement et engagement. Un
  `protocol` de plus, et surtout : **il entre dans le filtre de recherche.** On
  n'est alors jamais apparié avec un build incompatible, plutôt que d'être
  apparié puis détrompé. C'est la version la plus économique de la correction —
  le problème disparaît au lieu d'être traité.

Reste **ENet en réseau local**, qui n'a aucun rendez-vous : c'est là, et là
seulement, que `rpc_hello` sert. Chemin de développement et de dépannage, où les
deux bouts sont presque toujours le même build.

#### Ce qu'on compare

Un `PROTOCOL_VERSION` unique et monotone, couvrant **tout ce qui est visible sur
le fil** : formes de RPC, codec de carte, format des attributs de salon. Pas une
version par sous-système — un joueur n'a pas à savoir lequel diffère.

Et on **refuse dans les deux sens**, sans « plus récent tolère plus ancien » : le
build ancien ne peut pas savoir ce que le nouveau a changé, donc sa tolérance
serait une supposition. Refuser symétriquement est la seule règle que les deux
côtés peuvent appliquer avec la même information.

#### La numérotation — tranchée par Adrien le 2026-08-18 : « carnet + rappel »

`Protocol.VERSION` est tenu **à la main**. Lui seul peut porter le jugement
« ce changement casse la compatibilité », qui n'est pas un calcul. Une empreinte
purement automatique changerait sur un renommage sans conséquence et interdirait
à jamais de dire « celui-ci passe, laissez-les jouer ».

Sa faiblesse est l'oubli. Elle est donc **mécanisée** : `Protocol.WIRE_WITNESS`
retient à quoi ressemblait le fil quand le numéro a été fixé, et
`tools/test_protocole.gd` le recalcule à chaque exécution. Si le fil a bougé sans
que le numéro bouge, la suite passe au rouge et affiche l'empreinte à recopier —
**après** avoir tranché la question du numéro, jamais avant. La décision reste
humaine ; seul l'oubli est automatisé.

L'empreinte couvre trois choses et pas une de plus : les **signatures de RPC**
(annotation comprise — changer le mode d'appel casse autant que changer l'arité),
la **version du codec de carte**, et les **noms d'attributs de salon EOS**.

Deux garde-fous du garde-fou, parce qu'un témoin qu'on peut contourner par
inadvertance ne vaut rien :

- la suite **refuse tout `@rpc` hors des fichiers déclarés** dans `RPC_SOURCES` —
  un RPC ajouté ailleurs échapperait au témoin, et c'est le seul mode de
  défaillance qui rende le dispositif inutile ;
- l'alarme a été **vérifiée en la déclenchant** : un paramètre ajouté en douce à
  `rpc_send_inputs` rend la suite rouge avec la marche à suivre, et la
  restauration la rend verte. Un garde-fou qu'on n'a jamais vu échouer n'est pas
  un garde-fou.

Le refus est **symétrique** — ni « le plus récent tolère le plus ancien », ni
l'inverse : le build ancien ne peut pas savoir ce que le nouveau a changé, donc
sa tolérance serait une supposition.

#### La poignée de main — livrée

Trois raccords, et **chacun refuse à un moment différent** parce que ce qu'on peut
dire au joueur diffère à chaque fois :

- **Salon à code** — l'hôte publie l'attribut `PROTO` ; l'invité le lit **pendant
  la recherche, avant de rejoindre**, et refuse avec « vos versions diffèrent ».
  Pourquoi un attribut plutôt que le `bucket_id` : y glisser le numéro serait plus
  simple, deux versions chercheraient dans deux index et ne se verraient
  littéralement pas — mais le joueur qui tape un code valide obtiendrait « aucun
  salon à ce code » pendant que son ami l'attend. Le silence exact que ce projet
  passe son temps à traquer.
- **File d'appariement** — le numéro entre **dans le filtre**. Personne n'attend
  d'explication sur un adversaire qu'on n'a jamais vu : filtrer fait mieux que
  refuser, on n'est jamais apparié avec un build incompatible. Le problème n'a
  pas lieu plutôt que d'être traité.
- **ENet** — aucun rendez-vous, donc `rpc_hello(payload: String)`, **le seul RPC
  du jeu dont la signature soit figée pour toujours**. Tout voyage dedans en JSON.
  Y ajouter un paramètre désactiverait le garde-fou pour toutes les versions déjà
  publiées.

**Le silence est un refus**, et c'est le cas qui compte le plus : un build
antérieur n'a pas `rpc_hello`, ne répondra jamais, et Godot jette le paquet sans
rien dire. Sans `_check_hello_arrived` (8 s), le garde-fou n'attraperait que les
versions sachant déjà se présenter — c'est-à-dire pas celle contre laquelle il a
été écrit.

Côté client, le refus emprunte `connection_failed`, déjà relié à une boîte de
dialogue : le joueur obtient le vrai message **sans qu'aucun fichier tenu par une
autre session ne change**. Le signal `protocol_mismatch` est là pour qui voudra
faire mieux.

#### Le rappel a servi le jour même

Ajouter `rpc_hello` a fait passer `test_protocole` au rouge, avec la question
attendue : « le fil a changé, décidez d'abord si `VERSION` doit monter ». Il le
devait — nouveau RPC, nouvel attribut. **`Protocol.VERSION` est passé à 2**, et le
témoin a été renouvelé après la décision, pas avant. Le dispositif s'est exercé
sur son premier vrai changement.

### Deux manques vérifiés indépendamment le 2026-08-17

Une relecture séparée de `network_manager.gd`, `ui.gd`, `map_data.gd` et
`game_state.gd`, cherchant spécifiquement ce qu'il faudrait pour l'appariement
automatique, confirme tout ce qui précède et ajoute deux manques que les
étapes ci-dessus ne nomment pas encore :

- **Aucun tirage de carte au hasard n'existe nulle part.** `map_data.gd`
  n'expose que `select_map(map_id)`, toujours manuel ; la mention « cartes
  aléatoires » de l'arborescence du hub (Phase 5) décrit une intention, pas du
  code. En ligne, c'est toujours l'hôte qui choisit et le client adopte sa
  carte par `rpc_start_round` (`game_state.gd:638-650`) — un tirage aléatoire
  s'insérerait au même point, côté hôte, avant l'appel.
- **Le panneau de choix d'arme n'existe que sur l'écran local.**
  `_build_weapon_block()` (`ui.gd:2228`) n'est rattaché qu'à l'aside de
  `SCREEN_LOCAL` (`ui.gd:1691`) ; les asides `SCREEN_HOST`/`SCREEN_JOIN` ne
  l'incluent pas. Un écran de recherche de match aura besoin de son propre
  point d'accroche pour ce panneau — ou de le rendre accessible globalement,
  ce qu'aucun verrou de `MenuHub` n'empêche par ailleurs (bonne nouvelle :
  rien dans `menu_hub.gd` ne bloque la navigation pendant une opération réseau
  asynchrone, donc le principe « recherche en arrière-plan pendant qu'on
  parcourt les menus » de l'étape 8.6 est déjà praticable sans changement
  d'architecture — il manque juste l'état persistant à afficher, pas la
  liberté de naviguer).

## À trancher — le HUD montre l'adversaire en ligne

**Découvert le 2026-08-18 en cherchant si un tremblement de cercle de recharge
pouvait fuiter. Il y a beaucoup plus gros au même endroit.**

`_build_player_hud(0)` et `_build_player_hud(1)` sont tous deux ajoutés au HUD de
match, et **rien ne masque celui de l'adversaire en ligne**. Chaque joueur voit
donc, en temps réel et sans rien éclairer :

- **les points de vie de l'autre** (`p2_hp.value = p2.hp`, valeur autoritaire) ;
- **son cercle de recharge**, donc l'instant exact où son arme redevient prête ;
- l'état de sa torche et son éblouissement.

**C'est légitime en écran partagé** — deux joueurs côte à côte, chacun voit
l'écran de l'autre de toute façon. **En ligne, c'est une autre affaire :** le jeu
tient dans la phrase « la seule information est la lumière », et savoir que
l'adversaire est à 20 PV ou que son pompe redevient prêt dans 0,3 s est une
information qu'aucune torche n'a payée.

**Ce document ne tranche pas.** Cela peut être un choix assumé — beaucoup de jeux
de duel montrent les deux barres, et cela rend la fin de match lisible. Mais rien
n'indique que quiconque l'ait décidé pour CE jeu, et c'est exactement le motif du
2026-08-18 : une **description d'implémentation** qui se transmet comme une
intention.

**Si c'est à corriger, c'est petit** : masquer le panneau adverse quand
`NetworkManager.current_mode` n'est pas `LOCAL_SPLITSCREEN`, comme
`_restore_viewports()` le fait déjà pour les vues.

---

## Phase 9 — Mise à jour du jeu installé 🟡 ÉCRITE, PAS ENCORE ÉPROUVÉE

Demandée par Adrien le 2026-08-24 : « un endroit du menu où je clique sur mettre
à jour, et une mise à jour automatique se lance ». Trois façons de faire ont été
comparées ; celle-ci — remplacement du bundle depuis les Releases GitHub, avec un
manifeste conçu dès le premier jour pour accueillir aussi les correctifs légers —
a été retenue **parce qu'elle est la seule qui rende le bouton demandé** sans
dépendre d'un lanceur tiers.

### Ce que le refus symétrique change au problème

`Protocol.accepts()` refuse dans les deux sens : dès qu'une version publiée
touche au fil, la population se coupe en deux moitiés qui ne se voient
littéralement pas. Le critère de conception n'est donc pas « est-ce que ça met à
jour » mais **combien de temps deux versions coexistent dans la nature**. C'est
ce qui justifie le chemin `.pck` : quatre mégaoctets referment la fracture en
trois secondes là où cent la laissent ouverte une soirée.

### Le niveau d'obligation — tranché par Adrien le 2026-08-24 : refus poli

Rien n'est bloqué. Le jeu démarre, l'écran scindé, l'entraînement et l'éditeur de
cartes fonctionnent avec une version de retard. La seule chose qui cesse —
trouver un adversaire en ligne — **a déjà cessé toute seule**, et l'écran de mise
à jour se contente de la nommer. L'alternative (mise à jour forcée) transformerait
une gêne en panne : un jeu qui refuse de démarrer tant qu'on n'a pas téléchargé
cent mégaoctets est un jeu qu'on n'ouvre pas ce soir-là.

### Ce qui est livré

| Pièce | Ce qu'elle garantit |
|---|---|
| `update_manifest.gd` | Lecture, comparaison de versions, choix du paquet, signature. Aucun réseau : **tout le jugement est vérifiable en headless** |
| `update_installer.gd` | Racine d'installation, décompression, script d'échange, correctif. Le seul fichier qui sache ce qu'est un `.app` |
| `update_manager.gd` (autoload) | Enchaînement et mise en mots. L'écran ne compare aucun état lui-même |
| `patch_loader.gd` (autoload, **déclaré en premier**) | Monte le `.pck` avant tout autre autoload, avec témoin de démarrage et quarantaine |
| `screen_update.gd` + entrée du hub | Le bouton demandé |
| `tools/fabrique_manifeste.sh` | Le manifeste n'invente rien : version, protocole et empreintes sont lus aux sources |
| `.github/workflows/release.yml` | Sur tag seulement : cohérence tag/version, suites vertes, export, signature, publication |
| `tools/test_mise_a_jour.gd` | **110 contrôles**, dont la chaîne de signature complète et le script d'échange. `tools/test_autoloads.gd` protège l'ordre des autoloads, que `project.godot` ne peut pas expliquer lui-même. Le lanceur compte désormais 39 exécutions (35 suites en `--script`, quatre bancs en scène) |

### Ce qui a été vérifié pour de vrai, et ce qui ne l'a pas été

Vérifié en exécution, ici :

- **la chaîne de signature de bout en bout** — une signature `openssl` RSA-4096
  SHA-256 détachée est acceptée par `Crypto.verify()` de Godot, et un seul octet
  modifié dans le manifeste la fait refuser. C'était le point d'intégration le
  plus risqué : deux bibliothèques différentes devaient s'accorder sans jamais
  se parler ;
- **les deux exports depuis un runner Linux** — Windows (50 Mo) et macOS (101 Mo)
  sortent tous les deux, et le manifeste se fabrique dessus ;
- **la moitié réversible du remplacement** — sur la vraie archive Windows de
  50 Mo : le dossier d'étape se crée à côté de l'installation, l'archive s'y
  décompresse, l'installation en place n'est pas touchée, et une archive qui ne
  contient pas ce qu'elle annonce est refusée en nommant ce qu'elle contient.

**Pas vérifié, et il faut le dire :** l'échange lui-même n'a jamais tourné sur
une vraie machine — il demande un jeu exporté, installé, et une version publiée.
Le script est éprouvé par lecture (il attend la fermeture du processus, garde
l'ancienne installation, sait revenir en arrière), ce qui n'est pas la même chose
que de l'avoir vu marcher. C'est le jalon H9.

### Ce qui reste

1. **H8 — la paire de clés.** ✅ Moitié publique posée le 2026-08-26. Reste le
   secret GitHub `CANDELA_MAJ_CLE_PRIVEE` — la clé privée ne passe par aucun
   agent, par aucun message, par aucun commit.
   **Piège vécu le même jour, et il vaut d'être écrit :** un tag `v0.1.0` a été
   posé avant que la clé publique ne soit dans le fichier et avant que le secret
   n'existe. Le tag est parti seul (une poussée de tag emporte ses objets même
   quand la poussée de `main` est refusée) et a désigné un commit que `main` ne
   connaissait pas. La publication a échoué là où elle devait : à la signature.
   **Poser le tag après que le commit visé est sur GitHub**, jamais avant.
2. **H9 — la première publication.** Poser `v0.1.0`, laisser la CI publier, puis
   installer et mettre à jour sur une vraie machine.
3. **Windows d'abord.** Adrien le pressent : les premiers joueurs seront sous
   Windows. C'est aussi la plateforme la plus simple ici — pas de notarisation,
   pas de translocation, un dossier et un `.exe`.

Détail opératoire complet : [docs/MISE_A_JOUR.md](MISE_A_JOUR.md).

---

## Décisions actées

| Décision | Raison |
|---|---|
| **Un lot de tests local ne dépend jamais d'Epic** (2026-08-26) | Les six scénarios duo tournent en ENet sur 127.0.0.1, et pourtant chaque instance ouvrait une session EOS au démarrage — **douze allers-retours réseau réels par lot**, pour un transport dont aucun scénario ne se sert. `run_duo.sh` passe désormais `--no-eos` à ses trois lancements ; le drapeau existait déjà dans `network_manager.gd`, personne ne s'en servait. Mesuré : 17 s le scénario avec, 15 s sans, ~12 s sur le lot. **Le temps gagné n'est pas l'argument.** Le vrai est qu'un lot qui rougit parce qu'Epic est lent produit un **faux rouge** — et un contrôle qui rougit sans raison finit débranché, ce qui coûte infiniment plus que les douze secondes. Corollaire : ce qui doit éprouver EOS l'éprouve explicitement (`test_transport`, `docs/PROTOCOLE_TEST_EOS.md`), et ne se contente pas d'en traîner une session au passage. |
| **Le sprint est supprimé** (2026-08-26, Adrien) | Une seule allure, désormais. Ce que la suppression a révélé est plus instructif que la décision elle-même : le sprint était **câblé jusque dans le fil réseau**. `rpc_send_inputs` portait un sixième argument pour lui seul, donc `Protocol.VERSION` passe de 4 à 5 — un client v4 enverrait six valeurs à un hôte v5 qui en attend cinq, et le témoin de fil a signalé la rupture avant qu'on y pense. Deux conséquences en cascade, qu'on ne cherchait pas : `sprint_streaks.gdshader` disparaît, ce qui **ferme V5.9** (les traits de vitesse n'ont plus de vitesse à tracer) ; et le détecteur de pas, qui compte une **distance**, n'a plus qu'un seuil au lieu de deux — 45 px, sans alternative. Or l'argument n°1 contre les frames de marche peintes (DA2.4) était précisément que « le sprint ferait mentir en permanence » une planche jouée à cadence fixe. **Cet argument vient de tomber avec le sprint** : la planche de marche redevient possible, à un seuil unique de 45 px. La décision a rouvert une porte qu'elle ne visait pas. |
| **Le champ de vision ne dépend plus du ratio de l'écran** (2026-08-25, Adrien) | `window/stretch/aspect` passe de `expand` à **`keep`**. En `expand`, l'aire 2D grandit dans l'axe excédentaire dès que la fenêtre n'est pas en 16:9 : mesuré, un plein écran sur l'écran de développement donnait **1920×1173 au lieu de 1920×1080**, soit **+8,6 % de hauteur vue** — et un ultra-large aurait vu davantage encore. Dans un jeu dont la règle est « la seule information est la lumière », voir plus de carte parce qu'on possède un autre écran est une asymétrie que personne n'a payée en s'éclairant. En `keep`, l'aire 2D reste **1920×1080 quel que soit le ratio** (vérifié à 16:9, 3:2 et 2,4:1) ; le prix est le retour des bandes noires, assumé. `default_clear_color` est passé au noir dans la foulée : les bandes sont peintes avec lui, et son défaut Godot est un gris qui n'a rien à faire autour d'un jeu noir. |
| **Seule l'arbalète éclaire au-delà de l'écran** (2026-08-24, Adrien) | Chaque joueur voit **480 unités devant lui**. Au-delà, sa torche allume quelque chose qu'il ne voit pas et qui le trahit : elle coûte sans rien rapporter. Le pistolet passe de 30°/2,3 à **35°/1,6** (0,85 écran), le fusil de 3,5 à **1,8** (0,96), la pompe (60°/1,0 — 0,53) et l'arbalète (5°/3,5 — **1,87**) ne bougent pas. L'arbalète est l'arme furtive et lointaine ; le privilège de porter hors champ lui revient, et à elle seule. **La portée se lit désormais en fractions d'écran, pas en unités** — « 0,85 écran » se juge, « 410 unités » ne se juge pas. Effet second non cherché mais mesuré : à texture égale sur moins de terrain, la densité de texels du pistolet est multipliée par **2,9**, celle du fusil par 3,9. Raccourcir pour le jeu a réglé la netteté par-dessus le marché. ✅ **Portées dans `game_state.gd` le 2026-08-24**, à l'intégration de DA2.1. `tools/torches.gd` en garde une copie — la cuisson et le banc se chargent hors du jeu, où `game_state.gd` ne se charge pas — et `tools/test_torches.gd` exige leur égalité en lisant le TEXTE des deux sources. La divergence qui a réellement existé ici ne peut donc plus revenir muette. |
| **La résolution est assumée en smooth, pas en pixel-perfect** (2026-08-24, Adrien) | DA5.6, qui conditionnait toute commande d'asset. Le pixel-perfect impose une grille à des objets qui n'en ont pas : le monde de Candela n'est pas fait de sprites, il est fait de **lumière**, et un masque de lumière est agrandi jusqu'à 3,5 fois par `torch_scale` — une grille de texels y serait un défaut visible, jamais un style. Ce qui en découle et ne se rediscute plus : **filtrage linéaire et mipmaps à l'import, aucune texture en `nearest`**, et la résolution d'un asset cesse d'être un carcan — elle se choisit sur la densité de texels à l'écran, pas sur une grille. Première application : le cookie de torche vise **1024²**, où un texel couvre 1,75 pixel d'écran, contre 3,5 pour le 512² que `weapon_data.gd` fabrique aujourd'hui. |
| **En écran partagé, on somme les deux oreilles et on renonce aux murs** (2026-08-25, Adrien) | *« Le mode canapé doit perdre l'occlusion. Il garde la direction du plus proche. On fait la somme. »* Deux joueurs, une paire d'enceintes : aucune oreille unique ne peut être juste pour les deux. La somme des deux écoutes règle ça **sans arbitrage**, parce que la copie du plus proche est naturellement la plus forte — c'est le comportement natif du moteur, pas un mélange à doser. **Ce qui est abandonné l'est en connaissance de cause :** l'occlusion demanderait deux voix par son pour étouffer l'une des deux copies, dans un pool de seize que les pas saturent déjà. La décision dit donc quelque chose du mode lui-même : **l'écran partagé est le mode convivial, pas le mode compétitif** — on y préfère une direction vivante à une information exacte. En ligne, où chacun a sa sortie, rien ne change : une oreille, et les murs étouffent. |
| **Aucun dosage n'est demandé à Adrien sans le moyen de l'entendre** (2026-08-25, Adrien) | Il a demandé le banc avant même qu'on lui propose les valeurs : *« Oui il faut un banc pour que je puisse doser. »* La règle qui en sort dépasse l'audio. **Un réglage qui se juge à la sensation ne se règle pas en éditant une constante et en relançant** — une itération par minute, et le souvenir du réglage précédent est déjà parti. L'oreille, comme l'œil, ne juge pas dans l'absolu : elle juge des ÉCARTS, donc il faut pouvoir revenir en arrière **pendant que ça joue**. Le dépôt a déjà payé l'absence de ce moyen au prix fort : l'éblouissement est resté non fonctionnel deux mois, et sa récupération, une fois enfin jouée manette en main, a été **renversée** par l'expérience contre ce que le raisonnement seul avait produit. Corollaire pour toute session : livrer un réglage sans son banc, c'est livrer une question qu'Adrien ne pourra pas trancher. |
| **Le son reste en 2D, et un mur étouffera par la réverb** (2026-08-25, Adrien) | Deux arbitrages du chantier « spatialisation du son », pris le jour où il a été inscrit. **2D** : mesuré plutôt que supposé, `AudioStreamPlayer3D` ne donne **pas** de localisation supplémentaire — Godot ne fait aucun rendu binaural et la sortie est stéréo, donc la direction se réduit des deux côtés à un équilibre gauche/droite. Son seul gain réel est le passe-bas qui s'ouvre avec la distance. Or ce qui manque au jeu est la direction *relative*, que S1 et S2 rendent sans changer de nœud. **Réversible sans travail perdu tant que les sites d'appel ne passent qu'un `Vector2`** — c'est cette signature qu'il faut protéger, pas le type du nœud. **Le mur** : oui, il étouffe, et la formulation d'Adrien porte la mécanique — « naturellement par la réverb ». Ce n'est donc pas *ajouter* de la réverb quand c'est occulté (l'oreille entendrait un effet s'allumer), c'est **retirer le son direct et laisser ce qui réverbérait déjà** : le son passe dans la pièce d'à côté. Même geste que la torche, où l'on ne peint pas d'ombre mais retire de la lumière. Conséquence de jeu assumée : **cela ajoute de l'information**, un pas sourd disant « derrière un mur » et un pas net « ligne directe » — l'oreille se met à enseigner la carte. |
| **L'artiste unique, c'est Adrien — et le procédé se choisit par famille d'asset** (2026-08-24, Adrien) | DA1.5 demandait « un artiste, un lot, un style » pour éviter que des sources dépareillées recréent l'incohérence que tout le chantier chasse. L'artiste unique étant Adrien, **le risque a changé de nature : il n'est plus entre personnes, il est entre outils.** Deux textures faites à trois mois d'écart par deux procédés différents jurent exactement comme deux artistes différents. La décision n'est donc pas un nom, c'est une correspondance à tenir comme on tient la palette. **Lumière et matière** (cookie, halos, flash de bouche, sang, impacts, usure) : image générée convertie en masque **plus** paramétrage par le code — l'image ne fournit que la matière, le code garde la géométrie, ce qui laisse les quatre angles d'arme gratuits. **Wordmark, icône, viseur** : main levée sur gabarit, parce qu'un logo ne se génère pas. **Key art** : génération fortement retravaillée. Et la règle qui rend le premier procédé honnête : **une image générée n'est jamais l'asset, seulement sa matière** — on n'en garde que la luminance passée au contraste, si bien que ce qui survit est la structure du bruit et non le style du modèle. Sans elle, on remplace le look « généré par défaut » par le look « généré tout court », c'est-à-dire le défaut même qui a ouvert ce chantier. |
| **En ligne, on ne voit plus le HUD de l'adversaire** (2026-08-19, Adrien) | Il montrait ses **points de vie** et surtout **son cercle de recharge** — l'instant exact où son arme redevient prête. Dans un jeu dont la règle est « la seule information est la lumière », c'était un renseignement que personne n'avait payé en s'éclairant ; le cercle est le plus cher des deux, puisque sans lui il faut **compter** après avoir entendu un tir, et qu'avec lui on **lit**. Rien n'indiquait que quiconque l'ait décidé — c'était une conséquence d'implémentation. **En écran partagé les deux restent** : les joueurs voient l'écran l'un de l'autre de toute façon. **Les deux panneaux ne sont plus « J1 » et « J2 » mais « moi » et « l'autre »** : le premier est bleu et à gauche, le second rouge et à droite, et `GameState` alimente le premier avec le joueur **local** quel que soit son numéro. Correction d'Adrien le même jour : « le client devient bleu, c'est l'adversaire qui doit apparaître rouge pour lui » — **la couleur suit le RÔLE, pas le numéro**. Le numéro garde ce qui lui appartient vraiment : le **point d'apparition**, qui reste celui de J2. |
| **Le regard suit le joueur, pas le score** (2026-08-19) | Le suivi de caméra vivait dans `if round_active:` — « une manche **comptée** est en cours ». L'entraînement désarme volontairement cette manche : la caméra n'était donc **jamais** mise à jour de toute la session, et le joueur sortait du cadre. Suivre quelqu'un du regard n'a rien à voir avec le fait que ça compte au classement. **C'est l'entraînement, le seul mode qui sépare les deux, qui a révélé la confusion** — et il a fallu qu'Adrien le signale, aucun test ne regardait où était la caméra. |
| **Là où l'interface enseigne, l'absence est une réponse et l'estimation est un mensonge** (2026-08-18) | La règle existait déjà dans le dépôt sous trois noms différents — « ne jamais inventer un chiffre que le serveur n'a pas donné », le **tiret** plutôt que le zéro dans le classement, et « vide plutôt qu'approximatif » pour la trajectoire de killcam. C'est la même, et elle mérite un nom unique. **Une trajectoire fausse enseigne une leçon fausse ; un classement approximatif apprend un faux niveau ; un « adversaire prêt » deviné fait attendre pour rien.** Le critère n'est pas « a-t-on une valeur ? » mais « cette valeur va-t-elle être **apprise** ? » — si oui, ne rien montrer bat toujours une estimation, parce qu'une absence se remarque et se corrige, tandis qu'une estimation s'intègre. |
| **L'écran partagé n'existe que dans « 1v1 écrans scindés »** (2026-08-18, Adrien) | Ce document affirmait que l'écran partagé permanent était « une décision de conception du jeu, présente même en ligne ». **C'était faux, et personne ne l'avait décidé** — une description d'architecture (`CLAUDE.md`) transformée en intention par la session qui rédigeait. Adrien l'a relevée : « je ne crois pas que le deuxième écran permanent soit l'identité du jeu ». La règle est maintenant explicite : **une seule vue partout ailleurs**, en ligne comme à l'entraînement. Le comportement d'affichage l'appliquait déjà ; ce qui manquait, c'est que le **rendu** le suive — la vue cachée dessinait encore, pour 1,5 ms mesurées. |
| **Le flash de tir éblouit** (2026-08-18, Adrien) | Le geste le plus lumineux du jeu ne coûtait rien à celui qui le déclenche. Pic instantané de 0,6 à bout portant, éteint au-delà de 600 px, pondéré par `muzzle_flash_intensity` — l'arbalète (0,1) reste l'arme discrète, par le réglage qui servait déjà au rendu. Pas de cône (un canon crache dans toutes les directions), mais une ligne de vue : un mur arrête un flash comme il arrête un faisceau. Conséquence de jeu assumée : **le premier tir manqué à bout portant devient une ouverture pour l'adversaire**, alors qu'il était jusqu'ici sans conséquence. |
| **On est éblouissable de dos** (2026-08-18, Adrien) | L'orientation de la victime n'entre pas dans le calcul : une torche braquée sur sa nuque éblouit. C'est une **décision**, pas un oubli — dans un jeu où la lumière est la seule information, être pris dans un faisceau doit coûter quelque chose quelle que soit la direction du regard, et la règle inverse rendrait le duel dos-à-dos illisible. À rouvrir si le jeu s'en trouve confus. |
| **L'éblouissement est arbitré par l'hôte** (2026-08-18) | Le client ne le calcule pas : il le calculerait sur un adversaire **interpolé**, donc avec 100 ms de retard, et comme l'effet pénalise vitesse ET visée, sa prédiction divergerait en permanence de l'arbitrage — une correction de position permanente pour un effet cosmétique en apparence. La valeur passe par `net_dazzle`, sur le synchroniseur qui portait déjà les HP. **Prix assumé :** le voile blanc arrive chez le client avec un demi aller-retour de retard. ⚠️ *Mis à jour le 2026-08-24 : cette ligne disait « sur un effet qui dure une seconde et demie » pour montrer que le retard était négligeable. **L'effet dure désormais 0,375 s**, la récupération ayant été accélérée. Le retard reste petit — un demi aller-retour vaut 13 à 30 ms sur les liens mesurés, soit 3 à 8 % de la vie de l'effet au lieu de 1 à 2 % — donc **la décision tient, mais sa marge a été divisée par quatre**. Si la descente était encore accélérée, c'est ici qu'il faudrait revenir : le voile du client finirait par arriver après la moitié de ce qu'il doit montrer.* |
| **L'éblouissement LIT le faisceau, il ne le recalcule plus** (2026-08-24, Adrien) | `Vision.intensite_texture` échantillonne l'alpha de la texture que la lumière projette ; `intensite_recue` n'est plus qu'un repli pour une arme sans texture. La copie était délibérée — *« deux formules pour un même faisceau finiraient par diverger »* — et le raisonnement était juste : **une copie garantit que deux nombres restent égaux, jamais qu'ils veulent dire la même chose.** Trois divergences en étaient sorties, toutes muettes : `torch_brightness` que le modèle ignorait, le cône écrit en dur à 30° pour quatre armes de 5 à 60°, et le profil peint des cookies qui tombe à 0,49-0,73 de la formule dans les flancs. **Un pixel ne peut pas diverger de lui-même**, et il porte tout à la fois — angle, portée, luminosité, matière peinte. Deux conséquences qui ne se devinent pas : **l'échelle vient de `img.get_size()`**, donc le piège « un cookie de 1024² porte deux fois plus loin qu'un 512² » n'existe plus côté pénalité, rien n'est à compenser ; et **le halo de proximité entre dans le calcul** — mesuré à 0,004 brut à 75° et un dixième de portée, 0,000 dans le dos, donc cohérent et négligeable. |
| **La récupération est quatre fois plus rapide, et plus rapide que la montée** (2026-08-24, Adrien, manette en main) | La descente passe de **1,5 s à 0,375 s**. Elle valait l'inverse, et pour une raison écrite : *« volontairement plus lente que la montée : c'est ce décalage qui fait de l'éblouissement une ouverture exploitable, et non une gêne qui passe avant qu'on en profite »*. **Le raisonnement se tenait ; il n'avait jamais été éprouvé.** La mécanique ne fonctionnait pas avant le 2026-08-24 — personne ne l'avait jamais jouée. À l'essai, une seconde et demie d'aveuglement ne se lit pas comme une ouverture pour l'adversaire : elle se lit comme **une perte de contrôle sur son propre personnage**. C'est le premier réglage de ce chantier tranché par le jeu et non par la mesure, et il **renverse** ce que le raisonnement seul avait produit. Le contrôle qui l'interdisait a été **retourné, pas supprimé** : sa raison reste lisible dans `test_eblouissement`, requalifiée en hypothèse que l'expérience a écartée. **Prix assumé, à connaître avant de rejuger : le flash de tir se résorbe en 0,22 s au lieu de 0,9.** Le pic est le même, sa durée fond. Si l'ouverture devient trop brève pour être exploitée, c'est `PIC_FLASH` qu'il faut monter — pas la descente qu'il faut ralentir, puisque c'est la lenteur qui a été jugée punitive. |
| **Pas de faisceau, pas de pénalité** (2026-08-24, Adrien) | `game_state._lumiere_recue` gardait un repli sur la formule analytique quand l'arme n'avait pas de texture, défendu par un commentaire affirmant qu'une torche sans cookie ne devait pas devenir « silencieusement inoffensive ». **Le raisonnement était à l'envers, et c'est en vérifiant le travail d'une autre session que je l'ai vu dans le mien** : `equip_weapon` pose `flashlight.texture = get_torch_texture()`, donc sans cookie la lumière ne rend **rien**. Le repli faisait payer une pénalité pour un faisceau que personne ne voit — **le dernier endroit du jeu qui calculait l'éblouissement depuis autre chose que l'écran**, dans un chantier dont c'était tout le sujet. Le silence redouté n'existait pas non plus : un cookie manquant lève une erreur au chargement. `lumiere_recue()` rend zéro, et ce zéro est la règle — on ne peut pas être aveuglé par une lampe éteinte. **Conséquence à connaître : `Vision.COS_DEMI_CONE` n'a plus aucun lecteur en production.** Elle reste comme défaut des fonctions analytiques, qui gardent un rôle — `intensite_recue` est la référence contre laquelle le cookie peint est validé. C'est écrit au-dessus de la constante, faute de quoi elle aurait de nouveau l'air décidée. |
| **L'arbalète éblouit peu, comme son faisceau le laisse voir** (2026-08-24, Adrien) | Son `torch_brightness` de 0,3 n'était cuit que dans l'alpha de la texture, et la formule ne connaissait pas ce paramètre : **l'arme furtive éblouissait exactement comme le pistolet avec un faisceau trois fois plus sombre.** Elle l'était partout — `emits_light = false`, flash de bouche à 0,1, carreau d'acier froid — sauf dans ce qu'elle inflige. Tranché comme un **défaut, pas un équilibrage**. Sa pénalité à bout portant tombe de 0,798 à **0,434**, et à mi-portée dans l'axe de 0,590 à **0,319** (en lecture brute du pixel : 0,636 → 0,188 — deux échelles, une racine carrée entre elles). Elle garde un moyen de pression ; elle cesse d'en avoir un qu'on ne voit pas venir. |
| **La lumière reçue est courbée avant de devenir une pénalité** (2026-08-24, Adrien) | `Vision.intensite_recue` recopie terme pour terme la formule de la texture de torche : sa décroissance est **linéaire** jusqu'à zéro au bout du faisceau. Exact à l'alpha près, faux à l'œil — sur du noir absolu, 5 % de lumière se lit encore comme « éclairé ». Mesuré à l'écran : à 95 % de la portée du pistolet, un joueur se tenait dans une plaque de lumière franchement visible et ne prenait que **0,050**. `Eblouissement.plafond_pour` applique désormais une racine carrée : 0,05 de lumière coûte 0,22 au lieu de 0,05, mi-faisceau 0,71 au lieu de 0,50. **Les deux bornes ne bougent pas**, et c'est ce qui a décidé de la forme — hors du faisceau on ne prend toujours rien (c'est la proposition même du jeu : ici, on ne te voit pas), une lumière saturante sature toujours. Un seuil ou un décalage auraient cassé l'une des deux. **La courbe vit dans `eblouissement.gd`, pas dans `vision.gd`** : la géométrie doit rester le miroir exact de la texture, sans quoi le rendu deviendrait tributaire d'un réglage d'équilibre. **Prix assumé : on éblouit plus loin qu'avant**, à cône et portée inchangés. |
| **Le voile passe SOUS le HUD** (2026-08-24, Adrien) | Il était monté après la rangée de HUD, donc peint par-dessus : à saturation, on ne lisait plus sa propre barre de vie, son cercle de recharge ni le chrono. L'éblouissement doit coûter la lecture du **monde** — l'adversaire et sa lumière —, jamais celle de sa propre fiche : la première est le jeu, la seconde est une punition de plus que ne rattrape aucune compétence. Ce n'était pas une décision, seulement l'ordre de déclaration dans `_build_menu()`, et **rien ne le nommait**. Un commentaire tient désormais l'ordre, faute de pouvoir l'attraper autrement. |
| **Le curseur « Éblouissement » ne touche que le voile** (2026-08-18) | Premier lecteur en jeu d'`EffectPolicy` : `GameSettings.current_effect` module l'opacité du voile blanc, **jamais** la pénalité de vitesse et de visée. Un curseur qui allégerait la pénalité serait un avantage compétitif déguisé en confort — ce que le plancher de 0,8 cherche précisément à empêcher, et qu'il ne pourrait pas empêcher tout seul. |
| **Divisions : I la plus basse** (convention Rocket League) | Décidée à l'écriture d'`elo.ts` et déployée le 2026-08-17, jamais remontée comme telle — la feuille de route la listait encore comme une question ouverte pour Adrien. C'est l'inverse de League of Legends, d'où le rappel dans le code : **interverties, les divisions produisent une échelle parfaitement plausible à l'œil**, et l'erreur ne se voit qu'au moment où un joueur se plaint de descendre en gagnant. |
| **Un débutant part d'Aveugle I** (2026-08-18) | Le classement de départ (1000) tombait dans **Bougie**, troisième catégorie sur dix : un débutant serait arrivé avec trois des quatre armes et n'en aurait débloqué qu'une. C'est `RANK_FLOOR` qui a été déplacé, **pas `START_RATING`** — la table des classements est reconstruite par rejeu intégral de l'historique, donc abaisser le départ aurait recalculé tous les matchs déjà joués et déplacé tous les joueurs. Déplacer le plancher ne change que la **lecture** de l'échelle. **Prix assumé :** un débutant ne peut plus chuter, ce que le calibrage d'origine cherchait précisément à éviter. ⚠️ **Non déployé** — tant que la fonction en ligne porte l'ancien plancher, l'écran affiche Bougie pour un débutant. |
| **Format BO1, 5 minutes** | Un duel où chaque erreur est fatale se suffit en une manche : c'est ce qui rend chaque décision lourde. Le format transite par `MatchRecord.Format` — un BO3/BO5 s'ajouterait sans refonte, mais n'est pas implémenté. |
| **EOS conservé** pour la connectivité | NAT traversal + relais gratuits, sans serveur à maintenir. |
| **Code de salon**, pas de liste de salons | Geste le plus immédiat pour « je joue avec un ami ». La liste n'a de sens qu'avec du matchmaking → Phase 4. |
| **Images par seconde déplafonnées** | EOS coûte ~31 ms de latence de plus qu'ENet à 60 fps (54 ms contre 23 ms). Le levier est la cadence d'image, pas le nombre de ticks (+2 ms seulement en tickant deux fois par frame). Norme du jeu compétitif. |
| **Pas d'adhésion Apple Developer** avant une sortie publique macOS | 99 $/an. Jusque-là : builds non signés + « Ouvrir quand même » dans Réglages Système. La signature/notarisation reste entièrement à valider le jour venu. |
| **Anti-camping reporté** | Une autre mécanique sera choisie. Ne pas réintroduire mort subite / arène qui rétrécit sans arbitrage. |
| **Arbitrage D1-D7 et autonomie de la session game feel** | Décision d'Adrien du 2026-08-17. D1 (empreintes), D3 (extinction traînée) et D7 (sang persistant, plafond d'abord) sont **activés** ; D5 s'implémente **derrière un drapeau debug** jusqu'à mesure sur le Mac d'Adrien ; D2 et D4 sont **actés sur le principe** mais attendent leurs assets ; D6 est **acté**, à implémenter par la session « menus » dans le hub. La session game feel pousse à chaque commit vert, fusionne dans `main` en fin de vague verte, et tranche elle-même les micro-réglages (durées, intensités) en les documentant ici. |
| **P2P conservé, pas de serveur dédié** | Décision du 2026-08-16. Un serveur supprimerait l'avantage de l'hôte et la triche par l'hôte, mais **dégraderait la latence des deux joueurs** — aujourd'hui l'un des deux joue à 0 ms — et coûterait un hébergement à vie. Il se justifiera quand le classement aura assez d'enjeu pour qu'on triche dessus, donc quand il y aura des joueurs. La bascule resterait peu coûteuse : le netcode étant déjà hôte-autoritaire, un serveur dédié n'est qu'un hôte headless sans joueur local. Il faudrait ajouter un mode « hôte sans joueur » et une orchestration ; rien ne serait à jeter. |
| **Tout sur `main`, plus de branche par chantier** (2026-08-17) | Avec plusieurs sessions qui poussent dans la journée, une branche qui vieillit coûte plus cher à fusionner qu'elle ne protège — et le protocole obligeait de toute façon à récupérer `main` avant chaque poussée. L'isolement se prend en **worktree**, jamais en `checkout` : `main` ne peut être déployé que dans un seul arbre. |
| **Killcam locale** (chacun rejoue son enregistrement) | Le joueur revoit exactement ce qu'il a vu : meilleur outil pour comprendre sa mort. Les deux killcams peuvent légitimement différer. |
| **Menus : structure B, le hub** (2026-08-17) | Un accueil de grandes destinations, chacune un écran entier. Coûte deux clics de plus par partie que les deux autres propositions ; rapporte un écran par sujet, seule forme qui absorbe les rangs, le déblocage d'armes et les saisons sans surcharger l'onglet JOUER, déjà plein. |
| **Rangs dérivés du classement, jamais stockés** (2026-08-17) | Même raison que la table `ratings`, déjà reconstruite par rejeu : changer une borne d'échelle ne doit pas coûter une migration de données. `rankOf(rating)` vit dans `elo.ts`, testable hors ligne. |
| **Assets manquants : câbler, taire, diagnostiquer** (2026-08-17) | Le code qui joue un son absent s'écrit normalement et reste silencieux, sans erreur. Aucun bouche-trou n'est fabriqué : un placeholder qui traîne finit par être pris pour une intention. `asset_manifest.gd` porte les 76 fichiers attendus et distingue **absent** de **présent mais vide** — `music_menu.ogg`, `music_match.ogg` et `music_victory.ogg` pesaient exactement 160 032 octets, trois copies du même flux vide qu'un contrôle de présence déclarerait bons. La détection se fait à la taille du fichier. **Éprouvé le 2026-08-24** : les vraies musiques sont arrivées et la détection s'est corrigée seule, sans que personne y touche. Les champs voisins écrits à la main, eux, ont menti jusqu'à ce qu'on les relise (voir « Un champ que personne ne lit »). État visible en jeu par **F3**. |
| **Armes : règle du miroir en classé** (2026-08-17, confirmée par Adrien) | Les deux joueurs partagent l'arsenal du moins bien classé. Sans elle, le mieux classé arriverait avec des options que l'autre ne peut pas avoir — l'Arbalète étant à la fois l'arme furtive et la quatrième débloquée. Coût assumé : l'arsenal varie selon l'adversaire, ce que l'interface doit expliquer au moment où ça arrive. |
| **Un abandon vaut forfait** | Décision du 2026-08-16. Quitter un match en ligne en cours donne la victoire à celui qui reste : c'est archivé, drapeau `forfait` à l'appui. **La faille est connue et acceptée** : il suffit de couper la connexion de l'adversaire pour lui voler un forfait, ou d'invoquer sa propre coupure. Les deux autres règles envisagées ne valent pas mieux — jeter le match récompense celui qui débranche en train de perdre. Aucune n'est bonne ; celle-ci a au moins le mérite de ne pas rendre l'abandon gratuit. À revoir quand il y aura assez de joueurs pour que ça se pratique. |
| **Code de récupération à 12 caractères**, pas 6 | Décision du 2026-08-16. L'alphabet est celui de `LobbyCode`, la longueur non. Un code de salon (6 caractères, 30 bits) désigne un salon qui vit dix minutes ; un code de récupération est un secret au porteur qui ouvre un profil classé à vie. 12 caractères sur 32 font 60 bits, ce qui met une attaque par essais hors de portée. Affiché par groupes de quatre (`ABCD-EFGH-JKLM`), stocké et envoyé sans séparateur. |
| **Code de récupération stocké en clair** | Décision du 2026-08-16. Un condensat serait plus sûr, mais le jeu réaffiche le code à chaque lancement — c'est tout son intérêt, le joueur peut le noter quand il y pense. Le compromis « secret au porteur » était déjà acté ; le stockage en clair en est la conséquence, pas une négligence. |
| **Edge Functions sans jeton Supabase** (`verify_jwt = false`) | Décision du 2026-08-16. Leur authentification est le jeton signé par Epic, qu'elles vérifient elles-mêmes. Exiger en plus un jeton Supabase n'ajouterait rien — la clé publiable est embarquée dans le jeu, donc connue de tous — et ferait dépendre l'accès du format des clés, qui a justement changé (publiable / secrète). |
| **Mise à jour : refus poli, jamais forcée** (2026-08-24, Adrien) | Une version de retard ne bloque rien. Ce qui cesse de fonctionner a déjà cessé tout seul — `Protocol.accepts()` refuse symétriquement — et l'écran le nomme au lieu de le contraindre. Une mise à jour obligatoire transformerait une gêne en panne, et un jeu compétitif qui se met à jour tout seul changerait le comportement d'une arme entre deux manches d'une même soirée. |
| **Rien ne s'installe sans signature valide** (2026-08-24) | Un fichier écrit par `HTTPRequest` ne porte pas l'attribut de quarantaine de macOS : les mises à jour ne repassent jamais devant Gatekeeper. C'est confortable, et cela veut dire que **plus personne d'autre que nous ne vérifie ce qui s'exécute**. Sans clé publique renseignée, le jeu se déclare « non configuré » et ne télécharge rien — même dégradation franche que sans `eos_credentials.gd`. |
| **Publier est un geste humain** (2026-08-24) | La CI ne publie que sur un tag `vX.Y.Z` posé à la main, et refuse un tag qui ne corresponde pas à `config/version`. Une version partie ne se rattrape pas : les jeux installés la trouveront encore dans deux ans. |
| **PostgREST appelé directement, sans `supabase-js`** | Décision du 2026-08-16. Deux appels de fonction ne justifient pas de faire dépendre d'un paquet distant la seule porte d'entrée du classement. Tout tient en `fetch`, et `deno check` fonctionne hors ligne. |

---

## ~~À creuser — la killcam s'arrête avant le moment fatal~~ — **FAUSSE ALERTE**

**Signalé le 2026-08-18, retiré le même jour. Le défaut n'existe pas : c'était le
banc qui le fabriquait.**

L'instrumentation montrait le rejeu s'arrêtant à l'index 185 alors que
`impact_frame` valait 203, et j'en ai conclu que la killcam ne montrait jamais la
mort. **Sauf que le scénario mesuré était la famille 5.3 — celui où le client se
coupe brutalement PENDANT le ralenti.** `_on_peer_disconnected` appelle
`_abort_killcam()` (ligne 381), qui pose `playing_back = false` et rend
`time_scale` à 1,0. **Le rejeu s'arrêtait parce que mon propre test venait de
tuer le pair.** C'est le comportement attendu, et c'est même exactement ce que ce
banc doit vérifier.

Un test unitaire écrit pour trancher l'hypothèse concurrente — un tampon plus
court que l'ancre — l'écarte aussi : `tools/test_rejeu.gd::_test_ancre_dans_le_tampon`
vérifie que l'ancre tombe dans le tampon et qu'il reste des images après elle.

**Ce que ça coûte d'écrire quand même :** j'ai attribué au jeu un effet produit
par mon instrument, et je l'ai consigné comme « mesuré, reproductible ». Il
l'était — reproductible parce que le banc le reproduisait. **Une mesure
reproductible n'est pas une mesure d'autre chose que soi tant qu'on n'a pas
écarté l'instrument.** C'est la même famille que les trois relevés de cadence de
la journée, cette fois avec l'expérimentateur dans la mesure.

**Ce qui reste vrai et utile :** le ralenti s'engage bien (0,063 mesuré, ancres
valides), et sa fenêtre est **courte** — quelques dixièmes de seconde, ce qui
suffit à rendre instable toute assertion qui l'échantillonne. C'est la raison
pour laquelle la seconde moitié de la famille 2 a été retirée.

---

## ⚠️ À ÉTABLIR — la reconnexion pendant une killcam ne rend pas la main

**Banc écrit, rouge, et volontairement HORS du lanceur** (`./tools/run_duo.sh
--reconnexion`, famille 4.1). Il exerce le seul scénario à trois processus : le
client meurt, quitte pendant la killcam de l'hôte, **et revient**.

**Ce qu'il montre, reproduit à chaque exécution :**

- l'hôte voit bien le retour (`ADVERSAIRE: revenu`) et sa killcam va à son terme ;
- mais **aucune entrée `PRÊT` n'est visible ensuite** sur l'écran `local_hote` —
  le salon est là, la porte ne s'ouvre pas ;
- et **le client revenu perd le lien** (« Trying to call an RPC while no
  multiplayer peer is active »).

**La cause n'est pas établie, et c'est pour ça que rien n'est corrigé.** Deux
modifications ont été faites au code de production en poursuivant ce symptôme
avant de comprendre qu'elles n'en étaient pas la cause. Elles se défendent
séparément et restent — ne pas annoncer une déconnexion à quelqu'un dont
l'adversaire est revenu, et rouvrir le salon dans tous les cas — mais **il faut
les lire comme des améliorations indépendantes, pas comme un correctif de ce
défaut-ci**.

**La leçon de méthode, sous une forme neuve :** « on croit débuguer, on est en
train de renoncer » a un cousin — **on croit corriger, on est en train de
déplacer la faute vers le code testé**. Deux fois de suite, le banc avait tort et
le code a été modifié quand même.

**Deux pistes examinées, deux écartées — et c'est le plus utile de cette entrée.**

1. ~~« `client_peer_id` n'est pas reposé pour le second client »~~ — **faux** :
   `_on_peer_connected` le pose (ligne 332). Vérifié par lecture.
2. ~~« le chemin différé parque le jeu en solo alors qu'un pair est là » —
   J2 caché, sans collision, remplacé par la cible d'entraînement~~. Cette
   incohérence **est réelle**, mais la corriger **ne fait pas passer le banc** :
   ce n'est donc pas la cause. Le correctif a été **retiré**.

**Ce qui reste vrai et candidat, sans preuve** : parquer en solo alors qu'un pair
est connecté est incohérent, et mérite d'être corrigé un jour — mais **comme une
amélioration propre, pas comme le correctif de ce défaut-ci**.

⚠️ **Trois modifications du code de production ont été faites en poursuivant ce
symptôme, aucune n'était la cause, et la troisième l'a été après avoir écrit la
règle qui l'interdit.** Le geste juste, appliqué à la troisième : revenir en
arrière. Un chemin de netcode ne se répare pas par tâtonnements — chaque essai
non concluant y laisse un changement dont personne ne saura dire pourquoi il est
là.

**Pour qui reprendra :** commencer par instrumenter ce que voit le bloc salon
(`_refresh_lobby_block`) au moment où il refuse d'afficher `PRÊT`, plutôt que de
deviner ce qui manque en amont.

### La ressource musicale RÉFÉRENCE ses flux, elle ne les embarque plus (2026-08-24)

`main_stream_interactive.tres` recopiait les paquets Ogg de chaque clip dans son
propre corps, en base64 : 704 ko de texte pour sept flux qui vivaient déjà, en
double, à côté de lui dans `assets/audio/music/`. Il les référence désormais par
`ext_resource`, et pèse 2,9 ko.

Ce n'est pas une affaire de poids. Un flux embarqué **fige la ressource** : le
jour où l'on remplace un stem, le `.ogg` du dossier change et la musique du jeu
ne change pas — et rien ne le dit, puisque les deux existent et que les deux se
chargent. C'est le mode de défaillance que ce dépôt traque partout : deux
sources de vérité dont une seule est écoutée, sans que rien ne distingue
laquelle. Il fallait régénérer le `.tres` par script à chaque retouche, donc
personne n'aurait retouché.

Ce qui ne bouge pas et ne doit pas bouger : les **noms** des clips
(`AudioManager.play_music` bascule par nom, un clip renommé cesse simplement de
répondre) et l'**ordre** des couches du clip « match » — 0 base, 1 batterie,
2 arpège, 3 pouls. `set_music_intensity` et `update_low_health` les adressent par
indice. `tools/test_musique.gd` tient les deux.

### Conserver l'énergie anneau par anneau SATURE une planche directionnelle (2026-08-25)

Le mode `--energie radial` de la cuisson force chaque anneau du masque à porter
la même lumière que le dégradé qu'il remplace. C'est exactement ce qu'il faut
pour un halo — la portée ne bouge alors pas d'un pixel, mesuré à **1,1 %** près
sur les huit masques de DA2.2.

Appliqué aux trois frames du flash de bouche, il a **écrêté jusqu'à 3 997 pixels,
soit 8 % du disque**. La cause n'est pas un réglage : c'est que la référence est
isotrope et la planche ne l'est pas. Demander à un anneau dont toute la matière
est d'un côté de porter le total d'un anneau uniforme ne laisse qu'une issue au
côté clair — dépasser 1,0, et se faire raboter. **La direction se paie en
saturation**, et la saturation détruit précisément la structure qu'on est venu
chercher.

Recuit en `--energie libre` : zéro écrêtage, et l'enveloppe temporelle survit
d'elle-même (44 %, 42 %, 36 % de lumière au fil des trois frames) au lieu d'être
aplatie par la normalisation. Le prix est un flash plus sombre que le disque
d'origine — mais **la luminosité d'une lumière est un réglage de code**
(`muzzle_flash_intensity`, le tween d'énergie), pas une propriété de sa texture.

La règle : **`radial` pour ce qui est rond, `libre` pour ce qui pointe.**

### Un repli qui IMITE ce qu'il remplace ment sur la nature de la panne (2026-08-25)

`tools/apercu_torche.gd` se rabattait sur le dégradé procédural quand un masque
peint était introuvable. Silencieusement. Or un PNG cuit mais **pas encore
importé par Godot est invisible à `ResourceLoader`** — c'est l'état normal d'un
asset frais, pas une anomalie.

Adrien a donc appuyé sur les touches de comparaison et vu la même image à chaque
fois, puisque le repli était exactement la chose que les masques remplacent. Le
seul diagnostic possible depuis l'écran était **« les touches ne marchent pas »**
— un défaut d'entrée, à l'autre bout de la chaîne de la vraie cause. Deux
hypothèses fausses ont été explorées avant de mesurer.

Un repli est légitime : sans lui, une texture nulle rend un **carré** lumineux,
pire que l'ancien rendu. Ce qui ne l'est pas, c'est qu'il se taise. Il se nomme
désormais en clair dans l'étiquette du banc, avec la commande qui répare
(`godot --headless --path . --import`), et `LightTextures.masque()` lève un
`push_error` avant de rendre `null`.

**Le critère général : un repli doit être DISCERNABLE de la réussite.** Celui
qui produit le même résultat visible que le chemin nominal ne dégrade pas le
service, il déplace le diagnostic.

### La feuille de contraintes remplace la conversion, pour ce qui n'est pas lumière (2026-08-25, Adrien)

*Une image générée n'est jamais l'asset, seulement sa matière* voulait dire, pour
les masques de lumière : **on n'en garde que la luminance.** La règle est
inapplicable à un sprite de 36 pixels ou à une tuile de 35 — là, ce qu'on garde
est le dessin. Sans équivalent, la porte se rouvrait sur le « look généré tout
court » que tout le chantier DA existe pour fermer.

L'équivalent est une **feuille de contraintes**, validée par Adrien :

1. **À plat, aucune lumière cuite.** Ni reflet, ni ombre portée, ni dégradé
   d'éclairage. L'arène est éclairée par des `Light2D` en temps réel : toute
   lumière peinte se bat contre elles.
2. **Palette de la charte**, découpe en alpha pure.
3. **Généré à la taille d'emploi, ou au plus huit fois.**

⚠️ **Et la règle qui la rend honnête : ce qui peut être mesuré doit l'être par
l'outil, pas demandé au prompt.** `tools/fabrique_tuiles.gd` divise chaque tuile
par sa propre luminance basse fréquence — la lumière peinte disparaît
mécaniquement. `tools/fabrique_sprites.gd` mesure ce qui en reste et l'imprime,
sans corriger : sur un sprite, retirer le modelé retirerait le dessin. **Une
consigne qu'on ne peut pas vérifier est une consigne qu'on ne tient pas.**

Le troisième point n'est pas une commodité. Une planche de 2048² pour une tuile
de 35 est suréchantillonnée **vingt-neuf fois** : on choisit alors sur une image
que le jeu n'affichera jamais.

### Un mur n'est pas une surface, c'est une masse cernée d'un filament (2026-08-25, Adrien)

DA2.7 demandait des murs peints. Essayée, mesurée, **abandonnée** — et le chemin
vaut plus que la conclusion, parce que deux hypothèses fausses l'ont précédée.

Les murs peints ne se distinguaient pas des murs actuels. D'abord accusé le
**fondu additif** de la couche des murs : faux, Adrien l'a réfuté à l'écran en
éteignant la torche — le `CanvasModulate` noir éteint tout ce que la lumière
n'atteint pas, un mur non éclairé n'ajoute rien. Puis accusé le **plafond de
luminance** que cette première peur avait fait poser : faux aussi, le tripler
n'a pas déplacé un millième.

La mesure a fini par le dire, et il fallait mesurer **l'intérieur seul** : la
matière porte un écart-type de **0,032**, l'arête halogène **0,30**. L'intérieur
n'était ni bridé ni éteint, il était **noyé — dix fois plus faible que son propre
bord.** Étiré jusqu'à 0,118 il devenait visible, mais amplifiait le grain de
redimensionnement autant que la structure.

**Conclusion d'Adrien : « DA2.7 ne vaut pas le coup ».** Un mur noir cerné d'un
filament que la torche accroche était déjà la bonne idée. Les tuiles de mur ont
été retirées plutôt que gardées « au cas où » : *un bouche-trou qui traîne finit
par être pris pour une intention.*

### Un viseur se génère, finalement (2026-08-25, Adrien)

**Revirement assumé, écrit comme tel.** La décision du 2026-08-24 disait :
*« wordmark, icône, viseur : main levée sur gabarit, parce qu'un logo ne se
génère pas ».* Adrien a tranché l'inverse pour le viseur, et DA2.11 lui revient.

La ligne d'origine n'est pas réécrite : **une décision qu'on voit changer d'avis
reste lisible ; une décision réécrite fait croire qu'on n'a jamais pensé
autrement.** Le wordmark et l'icône, eux, restent à la main levée — c'est le
viseur seul qui bouge, et il bouge parce que ce n'est pas un logo : c'est une
croix de quelques dizaines de pixels dont la forme se juge en jeu, pas une
signature.


### ✅ RECTIFIÉ — la cible EST tenue, mes relevés valaient la moitié (2026-08-26)

**Adrien a lancé le banc lui-même, fenêtre au premier plan :**

```
Images mesurées : 9771 en 60,0 s     Fenêtre : 2560x1440 natifs (3,69 Mpx)
FPS médian      : 165                Racine  : rendu 2560x1440
FPS 1 % bas     : 75                 Verdict 60 fps : TENU
Image la plus lente : 20,3 ms        Focus : stable au PREMIER PLAN
```

**Mes propres relevés donnaient 37-38 et « NON TENU ».** Ils étaient pris au
**second plan** : macOS bride une fenêtre de fond, et une application lancée
depuis un terminal ne peut pas réclamer le premier plan (mesuré, la demande est
refusée). **L'écart n'est pas un biais, c'est un facteur deux.**

⚠️ **Et le banc le disait.** Il étiquette « stable au SECOND PLAN — comparable,
mais c'est un plancher », et j'ai construit une conclusion dessus quand même.
**Un avertissement placé APRÈS le résultat qu'il invalide arrive trop tard pour
qui lit de haut en bas** — c'est une leçon d'ordre de présentation, pas de
vigilance. La ligne de focus devrait précéder les chiffres qu'elle conditionne.

Tout ce que la section ci-dessous conclut sur la cible est donc **faux**, et son
texte est conservé pour que le chemin reste lisible. Ce qui en survit :

- la dérive thermique est réelle (les relevés d'une session s'usent) ;
- le 1 % bas est bruité, et **un seul relevé long vaut mieux que dix courts** ;
- ni les torches, ni les shaders, ni l'audio, ni le plafond de cadence ne
  causent les pics — ces éliminations tiennent, elles étaient comparatives.

⚠️ **La marge est plus étroite que le verdict ne le suggère.** 1 % bas à 75 ne
veut pas dire « 15 images de marge » : la pire image dure **20,3 ms** contre
**16,7 ms** de budget à 60 fps, soit **3,4 ms** de coussin sur les images qui
comptent. Une copie plein cadre de 3,69 Mpx peut les manger à elle seule —
**`COPY_MODE_RECT` reste donc le bon choix** pour le flou du brouillage, non
plus par prudence mais par arithmétique.


### Le 1 % bas n'est pas tenu, et ce n'est pas le brouillage (2026-08-25)

**Mesuré neuf fois, `bench_framerate --vue-unique` : 1 % bas entre 43 et 60.**
Jamais au-dessus. La cible est 60.

⚠️ **La demande de branchement du brouillage partait d'un chiffre isolé.** Elle
affirme *« le jeu franchit la cible de DEUX images par seconde (61 mesuré) »* et
en tire qu'un flou lisant l'écran pourrait « manger la marge entière ». Il n'y a
pas deux images de marge : **il manque dix à quinze images**, et le brouillage
n'y est pour rien puisqu'il n'est pas branché. Le 61 venait d'un relevé
favorable, et un 1 % bas est **la moyenne des quinze images les plus lentes sur
mille cinq cents** — la statistique la plus bruitée du banc, celle qu'on ne cite
jamais sans son écart.

Deux corrections de méthode, payées en route :

- j'ai d'abord cru que l'éditeur Godot ouvert faussait les relevés. **Fermé,
  c'est PIRE** (43-45-51 contre 60-51-57). Ce n'était pas une charge parasite,
  c'était le bruit de la métrique ;
- et la lecture d'écran du brouillage n'est **pas** permanente, contrairement à
  ce qu'annonce la demande : `_copie_ecran.visible = _flou.visible`, donc elle
  ne coûte que pendant un éblouissement.

#### `tools/banc_pics.tscn` — le banc qui date les pics au lieu de les compter

`bench_framerate` dit **combien**, pas **pourquoi**, et l'écart le réclamait : la
médiane tient 100 à 123 fps pendant que le 1 % bas tombe à 45. Soixante images
par seconde entre le milieu et la queue, ce n'est pas une charge de fond.

Le banc **date** chaque image lente et **compare** ce qui se passe pendant, à ce
qui se passe le reste du temps. ⚠️ **Le son est coupé** (bus `Master`, avant la
scène **et** après — `AudioManager` pose ses volumes à l'init et écraserait une
sourdine mise trop tôt) : demandé nommément par Adrien, un duel de quinze
secondes tirant au pompe est insupportable pour qui travaille à côté.

**Ce qu'il dit, en trois relevés concordants :**

- ⚠️ **les pics sont ÉTALÉS, pas groupés au début** (12 à 23 % dans le premier
  cinquième). Ce n'est donc **pas** une compilation de shader : c'est un coût
  permanent, qui se paiera en match. La distinction décide de tout — un pic de
  compilation ne se voit qu'au chargement, et `bench_framerate` les mélange ;
- **aucun corrélat ne dépasse le seuil.** Appels de dessin +14 à +18 % sur les
  images lentes (suggestif, sous les 25 %), objets +3 %, particules ±6 %, nœuds
  +2 %. La cause n'est pas dans ce que ce banc sait compter ;
- mémoire statique : +2,7 à +2,9 Mo sur quinze secondes.

#### ⚠️ Un relevé valide demande un HUMAIN (2026-08-26)

**macOS bride une fenêtre au second plan, et une application lancée depuis un
terminal ne peut pas réclamer le premier plan** — la demande est refusée, mesuré.
Le banc étiquette honnêtement ses relevés (« stable au SECOND PLAN — c'est un
plancher »), mais l'étiquette arrive *après* la minute de mesure.

Les chiffres le disent : machine froide, deux relevés de 60 s au second plan
donnent **37 et 38**, quand un relevé au premier plan la veille donnait **60,5**.
**L'écart entre premier et second plan est du même ordre que celui qu'on
cherchait à expliquer** — donc aucune conclusion sur la cible ne tient sans
vérifier cette ligne-là d'abord.

**Protocole, et il n'est pas automatisable :** c'est Adrien qui lance le banc, ou
qui clique la fenêtre dès qu'elle apparaît. Une session ne peut pas produire ce
relevé seule, et doit dire lequel des deux cas elle a obtenu.

#### Deux pièges que ce banc a failli produire lui-même

⚠️ **Un format qui écrase la donnée ment autant qu'un contrôle qui ne peut pas
échouer.** Les colonnes `process` et `physique` — les deux qui disent si le CPU
est en cause — s'imprimaient en entiers alors qu'elles sont en secondes : elles
affichaient « 0 », et le banc paraissait n'avoir rien mesuré là où il avait
mesuré l'essentiel.

⚠️ **Et une fois lisibles, elles étaient impossibles.** `TIME_PROCESS` vaut
19,3 ms pendant que l'image médiane dure 9,1 ms — un temps de traitement ne peut
pas dépasser l'image qui le contient. Ce moniteur est une **moyenne glissante**,
pas un relevé par image. Le banc en tirait « **−3,1 %** du temps est hors du code
de jeu » : un pourcentage négatif, imprimé sans broncher. **Un banc qui rend un
nombre impossible est pire qu'un banc muet — il a l'autorité d'une mesure.** Il
refuse désormais ce partage et le dit.

Et le garde qui refuse a lui-même dû être repris : il comparait le moniteur à
l'image **lente**, qu'il ne dépasse qu'une fois sur deux — donc il ne se
déclenchait qu'une fois sur deux, et le banc concluait le reste du temps à partir
d'une mesure qu'il savait fausse. **Un garde intermittent est un faux vert qui
attend son tour.** Comparé à la **médiane**, il tranche à tous les coups.

**Ce qui reste à trouver** : la cause des pics n'est dans aucun des corrélats
mesurés. Prochaine piste, dans l'ordre — le coût par image du rendu (les +18 %
d'appels de dessin), puis l'allocation.


### Le lanceur était sourd exactement là où le dépôt a choisi de crier (2026-08-25)

**« Tout passe, sans erreur de script » ne disait rien d'un jeu qui aurait perdu
toutes ses textures.** `run_suites.sh` et `run_duo.sh` ne cherchaient que
`SCRIPT ERROR`. Or le motif que ce dépôt s'impose partout — **on câble, on ne
retombe jamais en silence, on crie** — passe par `push_error()` : masque de
lumière absent, sprite absent, viseur absent. Ces cris-là, aucun lanceur ne les
entendait.

Trouvé le 2026-08-25 en cherchant à vérifier qu'un viseur se montait vraiment en
match. La suite était verte **et ne pouvait pas répondre à la question.**

#### La chaîne exacte, et pourquoi la première était fausse

⚠️ **Ce n'est PAS `USER ERROR`.** C'est ce que j'ai affirmé de mémoire, une
seconde session l'a relayé en écrivant « je l'ai vérifié », et c'était faux dans
les deux bouches. Mesuré au banc :

```
push_error("X")   → ERROR: X
                     at: push_error (core/variant/variant_utility.cpp:1023)
push_warning("X") → WARNING: X
printerr("X")     → X          ← aucun préfixe, rien du tout
```

`ERROR:` est **mot pour mot** ce que Godot imprime pour son propre bruit de fin
de course (« 16 resources still in use at exit »). Grepper `ERROR:` aurait fait
rougir tous les lots. La signature qui distingue un cri **délibéré** est la
ligne d'origine qui le suit : **`at: push_error (`**.

⚠️ **Et `printerr()` reste invisible** — pas de préfixe du tout, donc rien ne le
distingue d'un `print()`. Mesuré : **une seule occurrence** dans tout le code de
production à la racine (`network_manager.gd`). La garde couvre donc ce qu'elle
doit couvrir, mais un second `printerr` serait muet. C'est une limite assumée,
pas un oubli.

#### Ce que la garde a trouvé au premier essai, et pourquoi elle ne le punit pas

`test_vision` émet **quatre `push_error` en passant au vert**, depuis on ne sait
quand. Mais ils sont **voulus** : le test construit exprès une arme dont le
cookie n'existe pas, et son propre commentaire le dit — « l'erreur attendue est
imprimée par `get_torch_texture()` : elle est **voulue**, c'est elle qui empêche
le silence ». Ces quatre cris sont **la preuve que le test réussit.**

⚠️ **Donc une garde qui exigerait zéro cri rendrait le repli bruyant
intestable** : on ne pourrait plus écrire un test qui vérifie qu'on crie. Le
dépôt avait déjà tranché ; il restait à ne pas le contredire.

D'où une **égalité déclarée** plutôt qu'une interdiction : une suite annonce
`CRIS ATTENDUS: <n>` dans sa sortie, et sans déclaration la tolérance est zéro.
Trois raisons, la troisième étant la seule qui compte vraiment :

1. aucune liste d'exemptions à maintenir — un test de repli se déclare lui-même,
   et ça se lit dans le test ;
2. le lanceur reste strict par défaut ;
3. **une égalité vaut mieux qu'un plafond.** Elle attrape le cas inverse : un
   test de repli qui **cesserait** de crier parce qu'un `push_error` a été
   remplacé par un `return` silencieux — précisément la régression que tout le
   motif existe pour empêcher — passerait sous un plafond et rougit sous une
   égalité. Même forme que l'égalité exigée de `test_torches.gd`.

Éprouvé rouge dans les deux sens avant d'être cru : `4 push_error(s), 3
déclaré(s)` d'un côté, `0 push_error(s), 2 déclaré(s)` de l'autre.

#### La leçon de méthode, et elle n'est pas de moi

Une session a nommé ce qui s'est passé entre nous mieux que je ne l'aurais fait,
en constatant qu'elle avait écrit « je l'ai vérifié » après n'avoir contrôlé
qu'un membre d'une affirmation composée — le grep du lanceur, vrai ; la chaîne
`USER ERROR`, jamais mesurée :

> **Corriger le détail d'une affirmation lui donne du poids ; certifier la
> moitié d'une affirmation la fait passer tout entière.**

C'est le même mécanisme que le faux-vert ci-dessous : dans les deux cas, ce qui
circule n'est pas une erreur mais **une garantie mal bornée**.


### Un contrôle textuel épingle un IDENTIFIANT, jamais un SENS (2026-08-25)

**Le troisième membre de la famille, et le seul qui défende activement le
défaut qu'il devrait attraper.**

DA2.11 dérivait la flèche du système de `_is_main_menu`. Le mécanisme était bon
— dériver plutôt qu'appairer, pour qu'aucun chemin de sortie oublié ne laisse la
souris invisible. **Le prédicat, lui, était faux** : `_is_main_menu` veut dire
« on est dans le hub », pas « un menu attend un clic ». La souris disparaissait
donc dans la pause, dans les dialogues et dans la fenêtre de choix d'arme —
c'est-à-dire précisément là où il faut cliquer. Trouvé par DA4, corrigé en
`e82df4f` (`_un_menu_attend_un_clic()`).

⚠️ **Et le banc de l'auteur exigeait le prédicat défectueux :**

```gdscript
_vrai("la derivation lit l'ecran affiche", corps.contains("_is_main_menu"))
```

Ce contrôle ne se contentait pas de manquer le défaut. **Il rougissait sur le
correctif.** Quiconque remplaçait le prédicat cassait le test, et se serait
demandé s'il avait tort. Un banc peut donc être pire que muet : il peut monter
la garde devant l'erreur.

#### Ce qui distingue les trois membres de la famille

| forme | ce qu'elle mesure | comment elle ment |
|---|---|---|
| `contains("ma_fonction()")` | que la fonction **existe** | la ligne `func` la contient déjà : ne peut pas échouer |
| `contains("rotation")` sur un bloc commenté | ce que le code **dit de lui-même** | le commentaire qui interdit le motif contient le motif |
| `contains("_is_main_menu")` | **quel identifiant** est lu | passe parce que le code est faux, rougit quand il est juste |

**La racine commune :** un contrôle textuel atteste d'un *câblage*, jamais d'un
*sens*. Il peut dire « quelque chose est branché là » ; il ne peut pas dire « la
bonne chose est branchée là ». Vérifier un sens demande d'**exécuter**.

⚠️ **Et la contrainte qui m'y avait poussée était moins serrée que je ne le
croyais.** J'avais choisi le texte parce que `ui.gd` et `player.gd` ne se
chargent pas en `--script` — vrai, et consigné depuis le 2026-08-18. J'en avais
conclu « donc on lit le texte », alors que la conclusion juste était « donc il
faut un banc qui monte une scène ». DA4 a écrit quatre contrôles **à
l'exécution** : ils interrogent `_un_menu_attend_un_clic()` en match, dans la
pause et dans un dialogue. Les quatre anciens contrôles textuels, eux, **étaient
tous verts pendant que le défaut existait**.

Une limite réelle sert d'excuse à une limite plus large qu'elle : c'est ainsi
qu'on se retrouve à tester le texte d'un fichier qu'on aurait pu exécuter.


### Un contrôle textuel qui cherche `ma_fonction()` ne peut pas échouer (2026-08-25)

**Deux contrôles de `tools/test_viseur.gd` sont restés verts pendant que je les
sabotais.** Ils cherchaient l'appel d'une fonction dans le texte d'un fichier :

```gdscript
_vrai("la dérivation tourne à chaque image",
    interface.contains("_suivre_le_curseur_systeme()"))
```

C'est vert. Ça reste vert après avoir retiré l'appel de `_process`. Ça restera
vert quoi qu'on retire — parce que **la ligne de déclaration contient la même
chaîne** : `func _suivre_le_curseur_systeme() -> void:`. Le contrôle ne mesure
pas que la fonction est appelée, il mesure qu'elle **existe**, ce que la ligne
d'à côté affirme déjà.

Le remède est d'exiger l'appel, c'est-à-dire une ligne qui contienne le nom sans
être la déclaration :

```gdscript
for l in interface.split("\n"):
    if l.contains("_suivre_le_curseur_systeme()") and not l.contains("func "):
        appelee = true
```

Même famille, rencontrée dans le même banc : `corps.contains("2")` pour
vérifier qu'un `visibility_layer` vaut 2 — vert grâce au `Vector2` de la ligne
d'au-dessus. **On isole la ligne, pas le bloc.**

⚠️ **Ce qui rend ce piège coûteux n'est pas l'erreur, c'est sa signature :** un
contrôle faux-vert est indistinguable d'un contrôle satisfait. Il gonfle le
compteur, passe la suite, et fait croire qu'une régression est surveillée. Les
deux n'ont été démasqués que parce que le banc a été **délibérément saboté avant
d'être cru** — huit sabotages, dont deux n'ont pas rougi. Un banc qui n'a jamais
rougi n'a rien prouvé ; c'est le seul moyen de distinguer « ça marche » de « ça
ne peut pas dire le contraire ».


### `duplicate()` ne recopie pas les variables de script (2026-08-25)

**Le joueur 2 n'a jamais vu une seule tache de sang.** Découvert en construisant
`wall_impact.gd` sur le modèle de `blood_stain.gd` — pas en cherchant un défaut.

L'écran partagé est permanent : chaque décal existe en deux exemplaires, un par
viewport, et le second est fabriqué par `duplicate()` puis rebasculé sur les
masques de J2. La copie naissait au bon endroit, aux bons masques, dans le bon
groupe. **Elle dessinait le vide.**

Mesuré : un nœud dont `_drops` contient deux gouttes rend une copie dont
`_drops` est **vide**. Seules les propriétés natives suivent — `rotation` passe,
`position` passe, `visibility_layer` passe. Rien de ce que le script déclare ne
passe.

```
_drops original : 2
_drops copie J2 : 0
```

Le remède tient en trois lignes : reporter l'état à la main après la copie. Ce
qui coûte, c'est de le savoir.

⚠️ **Et c'est encore une sortie plausible** — la quatrième de la même famille
relevée en deux jours, après les flux musicaux vides, les huit entrées fantômes
du manifeste et l'auditeur qui n'existait pas. À chaque fois : rien n'est en
panne, aucune erreur n'est levée, le nœud est là, et le résultat est faux. La
signature commune est qu'**un objet correctement construit peut être
correctement vide**, et qu'aucun contrôle de présence ne distingue les deux.

La leçon de méthode vaut mieux que le correctif : **le défaut n'a pas été trouvé
en relisant `blood_stain.gd`, mais en écrivant un second système sur son
modèle.** Reconstruire oblige à vérifier chaque hypothèse que la relecture
accepte.

---

## Pièges connus — ne pas les redécouvrir

### Retirer un paramètre ne se vérifie pas en cherchant son nom (2026-08-26)

En supprimant le sprint, `update_input_state()` perd un argument. Réflexe
naturel : `grep -rn sprint` pour trouver tous les appelants à corriger. Le lot
est reparti vert au premier essai — **et il manquait un appelant.**

`tools/test_online_match.gd` passait la valeur en **littéral** :
`update_input_state(seq, mov, aim, false, false, false)`. Aucun des trois
`false` ne porte le mot « sprint » ; le grep n'avait rien à trouver, et il n'a
donc rien trouvé. Le nom disparaît du site d'appel **au moment même** où le
paramètre est nommé par position.

**La règle : après un changement de signature, on cherche la FONCTION, jamais
l'argument** — `grep -rn 'update_input_state('` — et on compte les arguments de
chaque appel. Même famille que les contrôles creux déjà consignés ici : dans les
deux cas, une recherche rend « aucun problème » alors qu'elle n'interrogeait pas
ce qu'on croyait. Ici, l'aveu est arrivé par les suites ; il aurait pu arriver
par un RPC muet en ligne, où plus rien ne l'aurait dit.

**Le même retrait a produit une SECONDE occurrence, d'une autre forme, et c'est
elle qui généralise la leçon.** `tools/test_audit_menus.gd` exigeait
`"CONTRÔLES": 6,  # trois actions × deux joueurs`. Les trois actions étaient
Tirer, Torche et **Courir** ; le seuil comptait donc le sprint sans jamais le
nommer. Le lot est passé au rouge, et le message accusait la rubrique des
contrôles — un écran qui n'avait rien fait.

Ce qui relie les deux : **une dépendance survit à la disparition du mot qui la
désigne.** Un argument nommé par position, un effectif écrit en chiffre — dans
les deux cas la trace textuelle du sprint avait déjà disparu du site qui en
dépendait. Chercher le nom retiré ne peut, par construction, pas les trouver.

Corollaire pratique : **c'est le lot complet qui fait foi, jamais le grep.** Les
deux occurrences ont été rendues par des suites, l'une (`test_audit_menus`)
écrite par une autre session pour une raison sans rapport. Un contrôle qui compte
ce qu'un écran montre attrape des retraits que son auteur n'imaginait pas.

### Une fusion qui apporte des assets périme le cache d'import (2026-08-25)

Le piège du `.godot` périmé est déjà consigné pour le **checkout**. Il se paie
aussi, et plus sournoisement, après une **fusion** : `git merge` ajoute des
`.png`, des `.wav`, leurs `.import` — et rien ne réimporte.

Constaté : `test_vision` **verte à 15 h, rouge à 15 h 10**, sans qu'une ligne de
code ait changé entre les deux. Deux contrôles tombaient — « une arme sans
faisceau ne verse rien ». La suite lit les textures de cône des armes ; une
texture que `ResourceLoader` ne voit pas rend le même verdict qu'une arme sans
faisceau. **Le symptôme accuse le modèle de vision ; la cause est un fichier que
Godot n'a pas encore ouvert.**

`godot --headless --path . --import` : verte au premier essai, et le lot complet
passe derrière (273 s).

**La règle : après toute fusion qui apporte des assets, importer AVANT de
lancer les suites.** Un lot rouge lancé sans ça n'accuse pas ce qu'il croit — et
sur un arbre que six sessions partagent, la fusion des autres suffit à périmer
le cache sans qu'on ait rien fait soi-même.

*Troisième forme rencontrée dans la journée de « le symptôme désigne un autre
coupable que le sien », après le port volé et l'autoload qui ne compile pas.
C'est un motif, pas une série de coïncidences : **un outil de mesure qui
dépend d'un état invisible accuse toujours ce qu'il mesure.***


### Certifier la moitié d'une affirmation la fait passer tout entière (2026-08-25)

Une session m'annonce que le lanceur est sourd aux `push_error`, « parce que
Godot les imprime en `USER ERROR` ». **J'ai vérifié le lanceur — vrai, il ne
grep que `SCRIPT ERROR|Parse Error` — et j'ai écrit « je l'ai vérifié » pour
l'affirmation ENTIÈRE.** La chaîne, je ne l'avais pas mesurée. Elle était fausse :

    push_error("X")   → ERROR: X
                          at: push_error (core/variant/variant_utility.cpp:1023)
    printerr("X")     → X            ← aucun préfixe du tout

Ni `USER ERROR` nulle part. Et le faux est parti de là vers Adrien, puis vers le
suivi de projet, **avec le mot « vérifié » collé dessus.**

**Le mécanisme, et il n'a rien d'une étourderie : la certification blanchit.**
Une affirmation relayée avec « j'ai vérifié » acquiert le poids d'une mesure, et
le lecteur suivant cesse légitimement de contrôler — c'est même à ça que sert le
mot. Le porter sur un composé dont on n'a contrôlé qu'un membre transfère la
confiance aux membres qu'on n'a pas touchés.

C'est la même famille qu'un constat de la veille, formulé par la session
« spatialisation du son » en se rétractant : **corriger le détail d'une
affirmation lui donne du crédit** — elle avait rectifié un chiffre dans le
rapport d'une autre session tout en gardant sa conclusion, qui était la partie
fausse. Vérifier une moitié, corriger une moitié : les deux gestes déplacent la
confiance vers ce qu'on n'a pas regardé.

**La parade est une discipline de formulation, pas de vigilance : nommer ce
qu'on a vérifié, jamais l'affirmation.** « J'ai vérifié que le lanceur ne grep
que ces deux chaînes ; la sortie de `push_error`, je ne l'ai pas mesurée » aurait
laissé le doute exactement là où il était. **Un « vérifié » sans objet nommé est
un chèque en blanc tiré sur le lecteur suivant.**

*Épilogue utile : la chaîne mesurée a rapporté un angle mort que personne ne
cherchait — `printerr()` n'imprime aucun préfixe, donc un cri passé par lui reste
invisible à toute garde qui filtre les erreurs. Une seule occurrence en
production (`network_manager.gd`), mais la garde le dit désormais dans son
commentaire.*

### Reconnaître un son à son DOSSIER, c'est le classer par où il vit (2026-08-25)

`AudioManager.est_un_tir()` répond vrai pour la clé `"shoot"` **ou pour tout
chemin commençant par `DIR_ARMES`** (`res://assets/audio/weapons/`). Écrit pour
V4.1, quand ce dossier ne contenait que les seize prises de tir, c'était exact.

**Le jour où un autre son y est déposé, il devient un tir sans que personne ne
l'ait décidé.** C'est arrivé avec les `weapon_dry_*` (le percuteur à vide) :
livrés dans le même dossier, ils héritaient de la sémantique « coup de feu », et
**un clic à vide faisait donc reculer les pas de l'adversaire de six décibels**
(V4.15). Un joueur martelant une détente vide effaçait les pas d'en face —
l'inverse exact de ce que ce son raconte, puisqu'il avoue qu'on est désarmé.

Aucune erreur, aucun test rouge : le duck est un écart de volume, pas un état.

> ✅ **FERMÉ le 2026-08-25.** `est_un_tir` classe désormais par ce que le nom du
> fichier EST, et précisément par ce que `chemin_tir()` fabrique —
> `weapon_<arme>_NN.wav`, suffixe numérique à deux chiffres. **Les deux fonctions
> se répondent : l'une construit, l'autre reconnaît**, et un son qui n'a pas été
> construit par la première n'est pas reconnu par la seconde. Déposer un fichier
> dans un dossier a cessé d'être une décision de gameplay.
>
> Éprouvé sur les sons **qui n'existent pas encore** — une queue de tir, une
> variante de distance, un rechargement : tous vivront dans ce dossier, aucun ne
> devient un tir. C'est le seul genre de test qui vaille ici, puisque le défaut
> ne se déclenche qu'à l'arrivée d'un fichier futur.

**Ce que ça enseigne au-delà de l'audio : classer par l'EMPLACEMENT d'un fichier
plutôt que par sa NATURE fait dépendre le comportement du jeu d'une décision de
rangement.** Déplacer un asset devient un changement de règles, et personne ne
relit le code en déposant un `.wav`. Quand une famille de sons partage un
dossier avec une autre, la question se pose à un prédicat nommé — pas à un
préfixe recopié.

*Attribution rectifiée à sa demande, et elle avait raison d'insister :
`est_un_tir` — `s.begins_with(DIR_ARMES)` — a été écrite par la session « DA3
Audio » pour V4.1, un jour où ce dossier ne contenait que des tirs. **Elle a donc
trouvé son propre piège**, et elle l'a trouvé parce qu'elle savait comment la
fonction classait. Ma part est un avertissement qui portait à côté : j'avais
prévenu que le nouveau son prendrait la **portée** par défaut. C'était vrai, et
c'est ce qui rendait la chose dangereuse — **un avertissement juste sur un
symptôme fait paraître la cause traitée.** Il prenait aussi la priorité et le
duck. Elle est allée au prédicat au lieu de s'arrêter à la table que je
pointais.*

*La distinction qu'elle ajoute et qui rend la règle utilisable : les cookies de
torche se chargent par `torch_cookie`, les variantes de tir par un numéro dans
leur nom — **ceux-là dérivent d'un champ explicite, pas d'un dossier.** Ce n'est
pas le nommage qui est en cause, c'est de faire porter une règle par
l'emplacement.*


### `cam1` à `Nil` ne parle jamais de la caméra (2026-08-25)

```
Invalid assignment of property 'offset' … on a base object of type 'Nil'
    at GameState._process(), game_state.gd:1132
```

**Cette erreur a été diagnostiquée TROIS fois dans la même journée, avec trois
causes différentes, et aucune n'était la caméra.** Un Godot orphelin tenant le
port 7777 ; un cache `.godot` périmé ; et un `audio_manager.gd` qui ne compilait
pas, sauvegardé au milieu du lot d'une autre session.

**La signature est toujours la même parce que le mécanisme est toujours le
même** : quelque chose empêche `_ready()` d'aller jusqu'à `_setup_players()`
(ligne 672, qui crée `cam1`), pendant que `_process()` tourne déjà. La caméra
n'est pas absente : **elle n'a jamais été créée**, et vingt lignes d'erreur
identiques défilent sans jamais nommer ce qui a interrompu le démarrage.

Le cas le plus fréquent, et le plus trompeur : **un autoload qui ne compile
pas.** Godot le signale une fois, en haut du journal — `Failed to instantiate an
autoload` — puis déroule la cascade qui, elle, se répète. **On lit la fin du
journal, jamais le début.**

**La règle : devant un `cam1` à `Nil`, ne pas ouvrir `game_state.gd`. Remonter
au PREMIER message d'erreur du journal.** Si c'est un `Parse Error` sur un
autoload, tout le reste en découle. Et sur un arbre partagé, l'autoload fautif
n'est pas forcément le vôtre : `git status` dit qui a un fichier ouvert.

*Consigné par la session « résolution d'affichage », qui a payé deux de ces
trois occurrences et a nommé le motif — les trois autres sessions cherchaient
chacune une cause différente pour un symptôme unique.*


### L'écoute suit le viewport du listener, pas celui qui rend (2026-08-25)

La phrase manquait au dépôt et elle a failli coûter un défaut entier. **Un
`SubViewport` reste le viewport auditeur même avec son `render_target_update_mode`
à `UPDATE_DISABLED`** : il suffit qu'il soit dans l'arbre. Rendu et écoute sont
deux listes indépendantes, et rien dans le code ne le dit.

**Le corollaire est le piège, et il ne se devine pas :** `AudioStreamPlayer2D`
boucle sur **tous** les viewports auditeurs de son `World2D` et **somme une
sortie par viewport**. Deux viewports auditeurs du même monde, dont un sans
`AudioListener2D`, et chaque son sort **deux fois** — une copie juste, une copie
depuis le centre de l'écran virtuel. Or **`SceneTree` déclare la racine auditrice
au démarrage** : tout montage qui donne à la racine le `world_2d` du jeu produit
donc ce doublement, sans qu'une ligne de code n'ait l'air fautive.

Le symptôme est de la pire famille : **pas un silence, un son parfaitement
audible.** Environ +3 dB, panoramique juste mêlé à un panoramique faux. Personne
ne dit « le son est cassé » ; on dit « le son est bizarre », et on cherche dans
le mixage.

**Le contrôle qui tranche est un fait de graphe, sans pilote audio : compter les
viewports auditeurs du monde de jeu et exiger qu'il y en ait exactement UN.**
Il vit dans `tools/test_rendu_racine.gd` (domaine « résolution de rendu »).

Et la précaution de retour, qui coûte autant que l'aller : `SceneTree` compte sur
la racine auditrice pour tout ce qui joue **hors match**, menus compris. Un
montage qui la coupe doit la rétablir en sortant, sinon le jeu devient muet
ailleurs — et rien ne relie ce silence-là au lot qui l'a causé.

*Découvert en travaillant à deux sessions : la première l'a prédit depuis le
code de l'oreille, la seconde l'a fait rougir dans son montage réel avant de
corriger. Aucune des deux ne l'aurait vu seule — l'une avait le mécanisme, l'autre
le montage.*

### Ce n'est pas le second plan qui casse le 1 % bas, c'est la TRANSITION (2026-08-25)

**Cette page attribuait déjà la dispersion des relevés de cadence à « la fenêtre
que macOS bride quand elle n'est pas au premier plan » (2026-08-16, médianes de
145 à 160). C'était la bonne famille de cause et la mauvaise cause.** Le banc ne
mesurait pas le focus : il ne pouvait donc ni confirmer ni écarter l'explication,
et elle est restée écrite comme un fait pendant neuf jours.

Mesuré le 2026-08-25, six exécutions à charge et fenêtre identiques, une fois le
banc instrumenté :

- fenêtre **restée** au second plan : 1 % bas de **142, 143, 144** ;
- fenêtre ayant **changé** d'état pendant la mesure : 1 % bas de **44 et 71**,
  avec des images isolées à 18 et 60 ms ;
- **la médiane ne bouge pas — 144 partout.**

Le second plan seul ne coûte donc rien de visible. Ce qui coûte, c'est le moment
où la fenêtre prend ou perd le focus : une poignée d'images à 18 ou 60 ms, et
comme le 1 % bas d'un relevé de quinze secondes ne porte que sur une vingtaine
d'images, **ces quelques hoquets décident du percentile à eux seuls**.

Ce qui rend le piège coûteux : le chiffre faux est *parfaitement plausible*.
« Doubler la fenêtre fait tomber le 1 % bas de 143 à 44 » se lit comme une
régression de rendu, et aurait condamné le chantier R avant qu'il commence.

La règle, désormais imprimée par le banc lui-même : **un relevé à focus mixte se
jette.** Stable au premier plan ou stable au second plan sont l'un et l'autre
exploitables — le second est un plancher, pas une aberration.

### Le réglage était juste, le code était juste, le chemin entre les deux n'existait pas (2026-08-25)

`DEBUG_WINDOW_FACTOR` double la fenêtre en débogage. Il vit dans
`_apply_windowed()`. Le poste de développement a `resolution_index = 2` — **plein
écran** — enregistré dans `user://settings.cfg`, et la branche du plein écran
refuse d'agir en débogage pour ne pas masquer l'éditeur… **en ne faisant rien du
tout**. Elle n'appelait donc jamais `_apply_windowed()`, et la fenêtre restait
celle de `project.godot`.

Résultat : la fonctionnalité était inopérante **précisément chez celui qui l'avait
demandée**, et elle a été annoncée comme livrée. Aucune suite ne pouvait
l'attraper — aucune n'ouvre de fenêtre — et la relecture du code ne l'attrape pas
non plus, puisque les deux morceaux sont corrects séparément.

**C'est le banc qui l'a trouvée, en imprimant `Fenêtre : 1280×720` là où on
attendait 2560×1440.** Leçon de méthode, et elle vaut au-delà de ce cas : *un
instrument qui imprime ses conditions attrape les défauts que ni les tests ni la
relecture ne voient*, parce qu'il énonce ce qui est au lieu de vérifier ce qu'on
a prévu.

Corollaire pour tout `match` sur une préférence : **une branche qui refuse une
option doit rendre la meilleure approximation disponible, jamais un statu quo
muet.** Ici, un plein écran refusé se rend maintenant en la plus large fenêtre
que le débogage autorise.

### Des clés dépréciées font réécrire `project.godot` tout seul (2026-08-25)

`boot_splash/fullsize` et `boot_splash/use_filter` n'existent plus en Godot 4.7.
Le dépôt les portait quand même — écrites par DA1 (`3e2af76`, wordmark et boot
splash) sous une version antérieure. **À chaque `godot --import` et à chaque
ouverture de l'éditeur, Godot les migre** vers `boot_splash/stretch_mode=0` et
remonte `config/icon`. Le fichier se retrouve modifié sans que personne ne l'ait
touché.

Ce que ça coûte : `project.godot` est **perpétuellement sale** dans l'arbre
partagé, et git refuse alors toute fusion qui le touche — *« Your local changes
to the following files would be overwritten by merge »*. Le prix est payé par la
session suivante, jamais par celle qui a lancé l'import. Il a bloqué la fusion du
lot « affichage », et **trois sessions ont été interrogées avant qu'on comprenne
que le coupable n'était humain d'aucun côté.** DA2 a fourni le fait qui tranche :
une dizaine de `--import` cette nuit-là pour les masques DA2.2/DA2.3 et les
tuiles DA2.6, chacun réécrivant le fichier.

**La parade est de commiter la migration, pas de la retirer** — décision d'Adrien
le 2026-08-25. La retirer la fait revenir au prochain import ; la commiter ferme
le cycle. Et la règle générale, qui dépasse ce fichier : *une modification
qu'aucun humain n'a écrite et qui revient toute seule n'est pas un accident de
travail, c'est un état du dépôt* — et un état, ça se commite.

### Une fenêtre Godot se compte en pixels NATIFS, pas en points (2026-08-25)

Sur macOS, `window_set_size(Vector2i(1280, 720))` ne demande pas une fenêtre de
1280 points : il demande 1280 **pixels de dalle**. Sur l'écran de développement —
Retina, échelle 2, 3840×2486 pixels pour 1920×1243 points — la fenêtre n'occupe
donc que **640×360 points**, un tiers de la largeur de l'écran.

C'est toute l'explication du « le jeu s'ouvre dans une petite fenêtre », et
**rien ne la désigne** : le réglage dit 1280×720, la résolution de rendu est
bien celle-là, aucun chiffre n'est faux. Seule la taille physique surprend, et
elle ne s'écrit nulle part.

Mesuré, et pas déduit : en plein écran, `window_get_size()` rend `(3840, 2410)`.
Si la taille était comptée en points, elle rendrait `(1920, 1243)`.

Corollaire pour tout code qui dimensionne une fenêtre : **écrêter à
`DisplayServer.screen_get_usable_rect()`**. Une fenêtre plus haute que la zone
utile glisse sa barre de titre sous la barre de menus — on ne peut alors plus
ni la déplacer ni la fermer à la souris.

**Effet de bord mesurable, à ne pas prendre pour une régression :
`tools/bench_framerate.tscn` ouvre une vraie fenêtre et charge les autoloads,
donc il hérite du facteur.** Les relevés historiques — 1 % bas ≥ 120, médianes
145 à 160 — ont été pris en fenêtre **1280×720** ; les prochains le seront en
**2560×1440**, soit quatre fois plus de pixels dans le viewport racine. Les
`SubViewport` étant figés (piège suivant), l'arène ne coûte pas plus cher, mais
le HUD et le blit final si. **Comparer un relevé d'après à un relevé d'avant
sans le dire fabriquerait une régression qui n'existe pas.** Épingler la fenêtre
dans le banc réglerait la question ; ce n'est pas fait.

### Agrandir la fenêtre n'agrandit pas le rendu du jeu (2026-08-25)

**Les `SubViewport` de `main.tscn` rendent à taille FIXE, quelle que soit la
fenêtre** : 958×1080 par joueur en écran scindé, 1916×1080 en vue unique. Mesuré
sur une reproduction isolée, à quatre tailles de fenêtre de 1280×720 à 3840×2160
— le `SubViewportContainer` ne répercute pas le facteur d'étirement sur le
viewport qu'il porte.

Conséquence contre-intuitive, et c'est elle qu'il faut retenir : **agrandir la
fenêtre rend le jeu plus FLOU, pas plus net.** L'arène est rendue à 1080p puis
étirée à la taille de la fenêtre. Seuls le HUD et les menus, qui vivent dans le
viewport racine, gagnent réellement en finesse. À 1280×720, l'arène était même
légèrement suréchantillonnée — rendue à 1080p pour être affichée en 720p.

Deux choses en découlent, et aucune n'est faite :

1. **Le gain de netteté se paye en taux de remplissage, pas en résolution
   d'assets.** Faire suivre les `SubViewport` multiplierait par **exactement 4**
   les pixels de jeu en plein écran — 2,07 → 8,29 Mpx, le `keep` letterboxant le
   rendu à 3840×2160, soit 2 par axe. La cible « 1 % bas ≥ 120 fps » a été
   mesurée en fenêtre 1280×720 : elle serait à remesurer, pas à supposer.
2. **Tant que les `SubViewport` sont figés, aucune texture n'a besoin d'être
   recuite.** Une tuile de 35 px couvre une case de 35 unités : le rapport est
   de **1 texel pour 1 pixel de viewport**, et il ne bouge pas avec la fenêtre.
   Le jour où les `SubViewport` suivront, il bougera d'un coup — et c'est **le
   cookie de torche qui parlera le premier**, pas les tuiles : le 1024² visé par
   DA5.6 retomberait à 3,5 texels par pixel, exactement la mollesse que le 512²
   présentait et que ce choix corrigeait.

Précision fournie par la session DA2, qui mesurait la même chaîne par l'autre
bout le même jour, et qui rassure sur le coût de ce jour-là : les tuiles
(35 px), les sprites de joueur (36 px) et les cookies sont **cuits à taille
fixe** depuis des planches de 2048² — vingt-neuf à cinquante-sept fois plus
grandes que la sortie. `tools/fabrique_tuiles.gd` et `tools/fabrique_sprites.gd`
savent donc recuire plus fin : **c'est un paramètre à changer, pas une
regénération à commander.** Ce qui coûtera, ce sont les images par seconde, pas
les assets.


### Le voleur de port 7777 n'est pas toujours une voisine (2026-08-25)

Le piège du port occupé est déjà consigné, et son contrôle recommandé est
`pgrep -f run_suites` — *y a-t-il une autre session qui lance les suites ?* **Ce
contrôle rate le cas le plus fréquent, et il l'a raté trois fois en deux jours.**

`duo_enet` échouait à chaque lot complet et passait rejoué seul, **sans qu'aucun
lanceur voisin ne tourne**. La cause, prise en flagrant délit :

```
$ ps aux | grep "[G]odot --headless" | wc -l
       2
$ lsof -nP -iUDP:7777
Godot   30632 vada   13u  IPv6 ...  UDP *:7777
```

**Un Godot d'un lot PRÉCÉDENT, encore vivant, tenant le port.** Pas une session
concurrente : un processus qui n'est pas sorti, souvent parce qu'un chien de
garde l'a tué en `SIGKILL` (scénarios `--coupure` et `--ralenti`, qui coupent le
client exprès) ou parce qu'un lot a été interrompu. `pgrep -f run_suites` ne le
voit pas — le lanceur, lui, est bien terminé.

**Le contrôle qui tranche vraiment, et il nomme le coupable :**

```bash
lsof -nP -iUDP:7777
```

S'il rend une ligne alors qu'aucun lot ne tourne, `pkill -f "Godot --headless"`
et relancer. Vérifié : trois lots rouges d'affilée, puis vert au premier essai
après le `pkill`.

**Ce que ça corrige dans le piège existant** : « compter les lanceurs » répond à
la mauvaise question. Ce qui compte n'est pas *qui travaille*, c'est *qui tient
le port* — et la seconde question a une réponse exacte que la première n'a pas.

> **✅ FERMÉ le 2026-08-25 — l'orphelin avait UNE cause précise, et le lanceur
> ne peut plus la produire ni la subir.** Demande d'Adrien : « pour qu'on n'ait
> plus le problème ».
>
> **La cause : `client2_pid=$!` capturait le PID du SOUS-SHELL, pas celui de
> Godot.** Le scénario `--reconnexion` lançait son troisième processus dans un
> `( sleep 18 ; godot … ) &`. Le nettoyage tuait donc consciencieusement le
> sous-shell — souvent déjà mort — pendant que **Godot, lui, survivait** et
> gardait le port. Le `trap` était correct, sa cible ne l'était pas : un
> `kill -9` sur le mauvais PID réussit sans rien libérer. Corrigé par un `exec`
> dans le sous-shell, qui le fait **remplacer** par Godot : `$!` désigne enfin
> le processus qu'on croit tuer. Vérifié — le scénario tourne et ne laisse plus
> rien derrière lui.
>
> **Trois garde-fous, et chacun répare un mensonge différent :**
>
> 1. **`run_duo.sh` REFUSE de démarrer si le port est pris**, au lieu de
>    produire « aucun adversaire n'a rejoint ». Il nomme les PID, distingue le
>    lot en cours (*attendez*) de l'orphelin (*`pkill`*), et **ne tue jamais
>    rien de lui-même** : six sessions partagent la machine, un nettoyage
>    automatique casserait la mesure d'une voisine.
> 2. **Le nettoyage vérifie qu'il a nettoyé**, et crie s'il reste un tenant —
>    mais **seulement si on a lancé quelque chose**. Le premier jet accusait
>    d'un orphelin qu'on n'avait pas créé, sur un lanceur qui venait de refuser
>    de démarrer : le faux diagnostic déplacé d'un cran au lieu d'être supprimé.
> 3. **Un refus n'est plus un échec.** `run_duo.sh` rend **3**, le lanceur
>    affiche `REPORTÉ` et **ne met pas `fail` à 1** ; la dernière ligne dit
>    combien de scénarios n'ont pas tourné. Les confondre est ce qui a produit
>    le « 13 suites en échec » : un compte gonflé par de la contention envoie
>    chercher une panne réseau qui n'existe pas.
>
> **La leçon générale, et c'est elle qui vaut au-delà de ce port :** ces quatre
> diagnostics n'ont pas été perdus faute de rigueur — trois sessions ont vérifié
> soigneusement, chacune sa pièce. Ils ont été perdus parce que **l'outil de
> mesure rendait un symptôme qui désignait un autre coupable que le sien.**
> Contre ça, aucune discipline de lecture ne protège : c'est à l'outil de ne pas
> mentir.


### Deux machines, deux UID pour le même chemin (2026-08-25)

Le journal affirme depuis le 2026-08-18 que la génération d'UID est
**déterministe pour un chemin donné** : « l'UID que notre import a produit pour
`prediction_tir.gd` est identique au vôtre — la génération n'est donc pas
aléatoire ». La mesure était juste, la généralisation ne l'est pas.

Contre-exemple, relevé en fusionnant `origin/main` dans le worktree DA4 :

| Où | UID de `tools/test_musique.gd` |
|---|---|
| worktree DA4, généré par `--import` | `uid://qfh28uh28u71` |
| `origin/main`, versionné | `uid://debjcj28ioisf` |

**Même chemin, même version de Godot, même machine.** La fusion a d'ailleurs
refusé de démarrer pour cette seule raison — *untracked working tree files would
be overwritten*.

**Ce que ça change :** versionner les `.uid` n'est pas un confort qui « supprime
la question », c'est une **nécessité**. Un `.uid` absent du dépôt sera réinventé
différemment par chaque arbre qui l'importe, et deux arbres finiront par se
disputer une ressource que Godot croit distincte. Le remède reste celui déjà
appliqué — les versionner tous, y compris ceux des bancs — mais la raison est
plus forte qu'annoncée.

**Et le réflexe à avoir en fusion :** un `.uid` non suivi qui bloque un `git
merge` n'est jamais à garder. Celui du dépôt fait foi ; le local est un
sous-produit d'un `--import`.


### Le produit promettait par écrit ce qu'il ne faisait pas (2026-08-24)

Deux entrées de l'écran `1v1 compétitif` portent, **dans leur propre texte lu par
le joueur** : « affichés à droite » et « affiché à droite — sans quitter cet
écran ». Les deux appellent `hub.show_detail()`, qui écrit dans deux `Control`
cachés à la construction et que rien ne rallume. On clique, la phrase promet, il
ne se passe rien.

**Ce n'est pas le bug qui est intéressant — c'est qu'il portait sa propre
description.** Le dépôt consigne déjà quatre formes de garantie qui se périme en
silence : le commentaire vrai au passé, la liste d'appuis, le nombre sans son
échelle, la garantie tenue par une ligne d'un autre fichier. En voici une
cinquième, et c'est la plus visible de toutes : **la promesse était affichée à
l'écran, en français, au joueur.** Personne ne l'a lue comme une assertion à
vérifier.

**La leçon opérationnelle :** un libellé d'interface qui décrit un comportement
(« à droite », « sans quitter », « en un clic ») est une **spécification**, et
elle est testable. `MON RANG` promet que le cadre de droite change — c'est
exactement l'assertion qu'un banc peut poser.

**Et le banc qui aurait dû l'attraper existait et était vert.**
`tools/test_audit_menus.gd` s'intitule « aucune entrée ne laisse le cadre de
droite vide ». Il vérifie que chaque entrée **possède** un texte ou un panneau —
les données ont toujours été là. Il ne vérifie pas que le cadre **montre** quoi
que ce soit. Un banc qui contrôle la source au lieu du rendu passe au vert sur un
écran noir ; c'est la troisième fois, après le cadre de menu entièrement noir du
2026-08-18 et le joueur planté en bas de l'écran du 2026-08-19.

**La parade générale, valable au-delà de ce cas :** quand un contrôle porte sur
de l'affichage, l'assertion finale doit lire une propriété **du nœud rendu** —
`visible`, `size`, la couleur d'un pixel — et jamais le dictionnaire qui l'a
alimenté. Les deux sont à un appel de distance, et un seul dit la vérité.

### Un worktree neuf n'a pas de cache d'import, et le banc rougit ailleurs (2026-08-24)

Premier lancement des suites depuis un `git worktree` fraîchement créé :
**`test_charte` échoue**, seul, sans qu'une ligne de code soit en cause. Le même
banc passe dans l'arbre partagé, sur le même commit.

La cause : `.godot/imported/` **n'est pas versionné**, donc un worktree neuf n'en
a pas. Godot ne peut pas ouvrir les `.fontdata`, et les deux fontes ne se
chargent pas. Le banc mesure des chasses de glyphes ; sans fonte, il n'a rien à
mesurer.

**Ce qui rend le piège vicieux, c'est le diagnostic de l'API :**
`ResourceLoader.exists()` répond **vrai** — le `.ttf` est bien là —, et `load()`
échoue quand même. `Charte.polices_manquantes()`, qui interroge le premier,
annonce donc que tout est en place pendant que la fonte est introuvable. Les deux
questions sont différentes et une seule est posée.

**Et il déborde très largement de `test_charte`.** Toute mesure sur une fonte
absente retombe silencieusement sur la fonte par défaut de Godot — **qui est
tabulaire**. Un banc qui vérifie que les compteurs ne tremblent pas passerait
donc **au vert sur une interface entièrement nue**, ce qui est pire que rouge :
il affirmerait précisément ce qui est faux. `tools/test_habillage.gd` ouvre pour
cette raison sur un contrôle de chargement effectif — `police_ui() != null` —
avant toute autre mesure.

**Et il mord AUSSI après chaque fusion, pas seulement à la création — c'est même
sa forme la plus fréquente, ajoutée le 2026-08-25 après une troisième morsure.**

Le symptôme ne ressemble alors pas du tout à sa cause : on tire le travail d'une
voisine, on relance le lot, et **quatre suites rougissent avec des erreurs dans
des fichiers qu'on n'a jamais ouverts** — `candela_tileset.gd`, `player.gd`. Le
premier réflexe est de croire à une régression de l'autre session, ou à une
incompatibilité entre les deux lots. Ce n'était ni l'un ni l'autre : la fusion
apportait des **assets neufs**, et `.godot/imported/` ne les connaissait pas.

> **Des erreurs dans les fichiers d'une autre session, juste après avoir tiré son
> travail, sont un défaut de cache d'import jusqu'à preuve du contraire.**

Le contrôle qui tranche en dix secondes : l'erreur est-elle un `null` sur une
ressource (`Cannot call method 'get_image' on a null value`) plutôt qu'une erreur
de logique ? Si oui, réimporter avant de lire une seule ligne du code d'autrui.

**La parade, en une commande — avant la première suite d'un worktree neuf, et
après toute fusion apportant des assets :**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Un peu moins d'une minute. À faire aussi après tout ajout d'asset binaire.

### Une erreur uniforme ne ressemble pas à une erreur, elle ressemble à un choix (2026-08-24)

`menu_engraver.gd` dimensionnait les six cases du code de salon par deux
multiplications : `taille × 0,87` en largeur, `taille × 1,27` en hauteur. Le
raisonnement en abordant DA4.9 était : *ces coefficients ont été réglés à l'œil
devant Oxanium, ils vont donc casser sous la fonte d'enseigne.* La ROADMAP a même
porté pendant une heure la phrase « les cases auraient bâillé d'un tiers ».

**Mesuré, c'est faux — et la vérité est plus intéressante.** Sous la fonte
d'enseigne à `T_VERDICT`, l'ancien coefficient donne 36,5 px pour un glyphe
maximal de 31 px : 1,5 px de trop, 4 %. Personne n'aurait rien vu.

**Le défaut n'était pas à venir, il était déjà là — sur la fonte pour laquelle le
coefficient avait été réglé :**

| Fonte | Glyphe le plus large | Case donnée par `× 0,87` |
|---|---|---|
| Oxanium 400 @30 (l'ancien réglage) | **28,0 px** | **26,1 px** |
| Display 800 @42 (le nouveau) | 31,0 px | 36,5 px |

**La case était plus étroite de 1,9 px que la lettre la plus large qu'elle devait
contenir.** Sur un code de salon, c'est-à-dire sur l'objet qu'on lit à voix haute
à un ami — six caractères, tirés dans un alphabet où le `W` et le `M` sont
fréquents.

**Et voilà pourquoi personne ne l'a jamais vu : l'erreur était uniforme.** Les six
cases étaient trop étroites *de la même quantité*, donc rien ne dépassait par
rapport à son voisin, rien n'était de travers, aucune ligne ne cassait. Le bloc
paraissait simplement un peu serré — c'est-à-dire **exactement ce qu'aurait
donné quelqu'un qui aurait choisi de le serrer.** Un défaut qui frappe un élément
sur six se voit ; un défaut qui frappe les six également se lit comme une
intention.

C'est la parenté avec *exact au chiffre près, et faux à l'œil*, mais par l'autre
bout : là, le chiffre était juste et le rendu faux ; ici le rendu est **plausible**
et c'est ce qui protège le chiffre faux.

**La parade appliquée : remplacer le coefficient par la mesure qu'il résumait.**
La case vaut désormais le glyphe le plus large de `LobbyCode.ALPHABET` mesuré dans
la fonte réellement posée, plus un demi-pas de grille — 35 px au lieu de 36,5, et
surtout 32 px au lieu de 26,1 si l'on était resté sous Oxanium. C'est plus court à
lire que la multiplication, et ça se corrige seul au prochain changement de fonte.

**Le signe qui permet de les repérer** : un littéral non rond multipliant une
taille ou une dimension — `0,87`, `1,27`, `0,73`. Un nombre rond est généralement
une décision ; un nombre à deux décimales est presque toujours une mesure
fossilisée, et il faut alors chercher **de quoi** elle dépend — puis vérifier
qu'elle était juste *au départ*, ce qui n'allait pas de soi ici.

**Enfin, la façon dont ça a été trouvé mérite d'être notée, parce qu'elle est
reproductible.** Ce n'est pas la relecture : le premier jet du commentaire ET de
la ROADMAP affirmait le mauvais diagnostic, avec aplomb. C'est d'avoir écrit une
sonde jetable de vingt lignes pour *imprimer les trois cas côte à côte* avant de
conclure. Même motif que `K_ADVERSAIRE`, dont le premier commentaire affirmait
une égalité de luminance fausse de 8 % : **quand une affirmation porte un nombre,
c'est le calcul qui tranche, pas la lecture.**
### Un son positionnel sans auditeur reste parfaitement audible (2026-08-25)

Le jeu joue ses pas, ses tirs et ses impacts dans des `AudioStreamPlayer2D`
depuis le premier jour, et **personne n'a jamais posé l'oreille**. Le défaut ne
fait aucun bruit, au sens propre : Godot déclare la **racine** auditeur 2D par
défaut, et sans caméra ni `AudioListener2D` il pose l'oreille au centre de
l'écran virtuel — un point fixe du monde, hors de la carte. Tout continue de
s'entendre, le panoramique bouge quand les sons bougent, aucune erreur, aucun
test rouge. **Tout a l'air de marcher.**

Ce qui le rend invisible à la relecture aussi : **le pool vit dans le mauvais
monde.** Il est enfant de l'autoload, donc dans le `World2D` de la racine,
tandis que le jeu vit dans celui du `SubViewport`. Or un `AudioStreamPlayer2D`
ne s'adresse qu'aux viewports de **son** monde — poser un `AudioListener2D` sur
le joueur ne changerait donc **rien du tout**, et on chercherait l'erreur dans
l'auditeur, à l'autre bout de la chaîne de la vraie cause.

Le contrôle qui tranche tient en une ligne et ne demande **aucun pilote audio** :
`lecteur.get_world_2d() == vue_de_jeu.get_world_2d()`. C'est un fait de graphe
de scène, pas un son : il se vérifie en headless, comme
`tools/test_pool_sfx.gd` a su le faire pour l'arbitrage des voix.

**La règle générale : un canal qui « marche » n'est pas un canal qui dit la
vérité.** Troisième cas du dépôt, après les flux musicaux dits « vides » qui
jouaient un timbre pendant deux mois et l'éblouissement branché sur une valeur
qui ne montait jamais. Leur point commun n'est pas la nature du bug, c'est
**une sortie plausible**. Ce qui les aurait attrapés n'est pas un test de plus :
c'est de vérifier une fois ce que la sortie **veut dire**.

### Un `M` de `git status` ne dit pas à qui est la modification (2026-08-24)

Quatre attributions fausses dans la même soirée, sur le même arbre partagé, par
deux sessions différentes. À chaque fois la déduction s'est trompée et la
lecture du diff a tranché.

| ce qu'on croyait | ce que c'était |
|---|---|
| `project.godot` modifié par personne d'identifiable | la session « menus », qui posait l'icône |
| 92 lignes supprimées dans l'index « par une autre session » | un blob périmé de la session « menus » elle-même |
| 40 lignes de `ROADMAP.md` attribuées à la session DA2 | la session « musique », sur le défaut de l'intro |
| « tes corrections ne sont pas parties » dit à DA2 | `3191dd7` **était** ces corrections, déjà poussées |

**La raison est structurelle, pas une question d'attention : git ne stocke aucun
auteur pour une modification non commitée.** Il n'y a rien à interroger. Le `M`
dit qu'un fichier diffère de l'index, un point. La seule source d'attribution
est le **contenu**.

Donc la règle n'est pas « mieux déduire », c'est **ne jamais déduire** :
`git diff <chemin>` avant toute décision sur un fichier modifié qu'on n'a pas
écrit soi-même. Trente secondes.

**Ce qui justifie de la lire systématiquement, c'est l'asymétrie du coût.** Se
tromper en croyant la modification à soi fait **perdre le travail d'un autre,
sans conflit et sans avertissement** — c'est ainsi que 72 lignes ont disparu ce
soir-là, et qu'un index périmé en attendait 92 de plus. Se tromper dans l'autre
sens ne coûte qu'une question posée à une voisine. Les quatre cas ci-dessus sont
tous du premier type.

Corollaire pour les rapports entre sessions : **annoncer à quelqu'un l'état de
son propre travail est le pire moment pour déduire.** Il ne pourra pas vérifier
sans refaire le travail, et il n'a aucune raison de douter.

### Deux sessions qui lancent les suites en même temps se volent le port (2026-08-24)

`run_duo.sh` ouvre le salon sur **7777, en dur**. Deux sessions qui lancent
`run_suites.sh` simultanément — situation normale ici, on est quatre à six sur
l'arbre — se disputent ce port, et le perdant échoue.

Ce qui rend le piège coûteux, c'est la *forme* de l'échec. Il ne dit pas
« port occupé ». Il dit :

    ECHEC: le client n'a jamais rejoint
    ECHEC: aucun adversaire n'a rejoint

soit exactement ce qu'afficherait un vrai défaut de connexion — sans erreur de
script, sans trace, avec les cinq autres scénarios verts autour. On cherche donc
la panne dans le réseau du jeu, où elle n'est pas.

Le contrôle qui tranche en trente secondes : **rejouer le scénario seul**
(`./tools/run_duo.sh --coupure`). Vert isolé, rouge en parallèle = contention.
Et pour savoir avant de chercher : `pgrep -f run_suites` dit s'il y a une
voisine, `lsof -nP -iUDP:7777` dit si le port est pris.

Correctif possible, **signalé et non fait** (hors périmètre du jour) : tirer le
port d'une variable d'environnement avec une valeur par défaut, pour que chaque
session ait le sien.

### Isoler ses propres hunks par plumbing a une course (2026-08-24)

Arbre partagé par quatre sessions. Pour ne pas emporter le travail non commité
des voisines dans son commit, la manœuvre employée était : lire
`git show HEAD:fichier`, y rejouer ses seules modifications, `git hash-object -w`,
`git update-index --cacheinfo`, commiter. L'intention est bonne et le résultat
l'était sur le contenu. **Elle a quand même détruit 72 lignes.**

Deux défauts, tous deux dans l'écart entre la lecture et le commit :

1. **La course.** Entre `git show HEAD:…` et `git commit`, une autre session a
   commité `b8286b3`. Le commit produit avait donc `b8286b3` pour *parent* mais
   un arbre construit sur son *grand-parent* : il a proprement réverté les
   72 lignes de la voisine, sans conflit, sans avertissement. Il a fallu un
   commit de récupération (`52d6f1d`) pour les ressusciter.
2. **Le résidu.** L'index garde le blob posé à la main. Les commits suivants des
   voisines (faits par `git commit <chemin>`, qui n'actualise pas l'index)
   l'ont laissé en place : `git status` affichait **92 lignes supprimées en
   attente**, et un `git commit` nu de n'importe qui les aurait validées.

La manœuvre reste la bonne, à trois conditions : **relire le SHA de `HEAD` juste
avant de commiter et abandonner s'il a bougé** ; **relire `git diff --cached`
avant de commiter** plutôt qu'après ; **désindexer le chemin après le commit**
(`git restore --staged`) pour ne pas laisser d'arme chargée dans l'index commun.

La leçon générale : une commande qui écrit dans l'index d'un arbre partagé n'est
pas une opération locale. Elle laisse un état que les autres vont rencontrer.

### Un champ que personne ne lit ne se corrige pas tout seul (2026-08-24)

Le jour où Adrien a livré les vraies musiques, `asset_manifest.gd` a cessé de
signaler trois bouche-trous **sans qu'on touche à rien** : la détection compare
la taille du fichier, donc elle s'est corrigée seule. C'était exactement
l'intention de 2026-08-17, et elle a tenu.

Dans le même dictionnaire, à trois caractères de là, `p: true` a continué
d'annoncer ces mêmes trois bouche-trous, et trois durées de stinger sont restées
fausses de 0,7 à 1,4 s. Aucune erreur, aucune suite rouge — parce que **rien ne
lit ces champs** : les seules occurrences de `["p"]` dans le dépôt portent un
`Vector2` d'un dictionnaire sans rapport. Ce sont des commentaires déguisés en
données.

La règle : dans une même structure, séparer ce qui est **mesuré** de ce qui est
**déclaré**. Le mesuré suit le monde ; le déclaré pourrit, et il pourrit d'autant
plus silencieusement qu'il voisine avec du mesuré dont il emprunte le crédit. Un
champ qu'aucun code ne lit est de la documentation, quelle que soit sa syntaxe.

Corollaire vérifié le jour même : le signalement venait d'une session voisine,
qui ne tenait pas ce fichier. Les chiffres ont quand même été **mesurés**
(`AudioStream.get_length()`) avant correction — et la mesure a rapporté mieux que
le signalement, en montrant que les onze fichiers tombent pile sur la grille à
170 BPM (64 temps les boucles, 16 l'intro et la victoire, 4 et 8 les stingers).
Rapport juste, mesure quand même : elle a coûté trente secondes et confirmé une
propriété que personne n'avait pensé à annoncer.

**Et le même jour, la mesure elle-même s'est révélée trop étroite.** Signalé par
la session DA2 : `music_intro.ogg` était un bouche-trou qui **passait à travers**
la détection. Celle-ci teste `taille == 160 032`, or il existait **deux
gabarits** de bouche-trou et elle n'en couvrait qu'un :

| fichier | taille | durée | temps à 170 | crête |
|---|---|---|---|---|
| `music_menu` / `music_match` / `music_victory` | 160 032 o | 11,294 s | 32 | −17,0 dB |
| `music_intro` | 167 364 o | 12,000 s | 34 | −13,4 dB |

**Et cette entrée a d'abord été écrite fausse.** Elle annonçait que 160 032
octets valaient 22,588 s. Personne ne l'avait mesuré : la durée avait été
*déduite* de celle des vraies boucles, puis écrite comme un constat. C'est
exactement le défaut que le paragraphe précédent dénonce, commis dans le
paragraphe qui le dénonce — et rattrapé par une session voisine qui a décodé les
fichiers au lieu de lire la ligne. Le bouche-trou faisait la **moitié** d'une
vraie boucle.

Deux choses à corriger un jour, **signalées et pas touchées** (hors périmètre du
jour, `asset_manifest.gd` porte un commentaire au bon endroit) :

1. la détection devrait porter sur une propriété du contenu — durée hors grille,
   niveau crête — et non sur un nombre d'octets qui change avec la durée ;
2. le vocabulaire ment aussi. Ces fichiers sont décrits partout comme des « flux
   vides ». Ils ne sont pas silencieux : le bouche-trou de `music_menu.ogg`
   mesure −32,1 dB de moyenne et **−17,0 dB de crête**. Quelqu'un qui monte le
   volume entend quelque chose et en conclut que la musique marche. « Vide »
   était une intention de fabrication, jamais une propriété du fichier — encore
   un déclaré qu'on a lu comme un mesuré.

### Un garde-fou qui nomme des appuis se périme EN VERT (2026-08-24)

`tools/planche_eblouissement.gd` déclare les méthodes dont il dépend et refuse
de tourner si l'une manque — bonne idée, posée le matin même contre ce motif.
**L'après-midi, une migration d'API l'avait déjà périmé.** La planche cessait
d'appeler `image_torche()` pour passer par `WeaponData.lumiere_axiale()` ; la
liste continuait de nommer la première et ne nommait pas la seconde.

Un renommage de `lumiere_axiale()` aurait donc cassé la planche **en laissant
`test_banc` vert** — le garde-fou surveillait une porte qu'on n'empruntait plus,
et laissait ouverte celle par où l'on passait.

**Une liste d'appuis est du code appelant.** Elle se relit à chaque migration,
au même titre que les appels eux-mêmes. Sinon elle devient exactement ce contre
quoi elle protège : une chose qui a l'air vérifiée.

C'est la même famille que le contrôle hors sujet et que l'entrée barrée : trois
formes du même piège — **quelque chose qui rassure sans regarder au bon
endroit.** Le vert, la ligne barrée, la liste d'appuis. Aucun des trois ne ment ;
tous les trois dispensent d'aller voir.

Corollaire de méthode, appris le même jour en éprouvant le contrôle
anti-penchement sur un cookie truqué avant de le restaurer : **un contrôle qu'on
n'a jamais vu rougir n'est pas un contrôle, c'est une intention.**

### La résolution d'une texture de lumière décide de sa PORTÉE (2026-08-24)

**`PointLight2D.texture_scale` multiplie la taille PROPRE de la texture.** Un
cookie de 512² à `torch_scale = 1.0` couvre 512 unités de monde ; le même cookie
recuit en 1024², au même `torch_scale`, en couvre **1024**. La torche porte deux
fois plus loin, et **aucune valeur de gameplay n'a bougé**.

Payé en vrai sur DA2.1. Mes contrôles annonçaient une énergie conservée à 0,2 %
près — ils mesuraient en **coordonnées de texture**, où tout allait bien.
**C'est Adrien qui l'a vu à l'écran, en une phrase : « ça éclaire beaucoup trop
loin. »** Une mesure juste dans le mauvais repère est plus dangereuse qu'une
absence de mesure : elle rassure.

La parade est une ligne, et elle doit accompagner tout changement de résolution :

    texture_scale = torch_scale * 512.0 / float(texture.get_width())

**La règle générale, elle, dépasse la lumière : une propriété d'implémentation
— une résolution, un format, un nombre d'images — ne doit jamais décider d'une
grandeur de jeu.** Quand elle le fait, elle le fait en silence, et le silence est
le problème.

Corollaire du même chantier : **conserver l'énergie TOTALE d'un masque ne
conserve pas sa portée.** Le total peut être exact pendant que la répartition
s'est effondrée — ici, un cœur saturé à 255 sur les deux tiers de la longueur et
dix-huit fois trop de lumière au bord. L'invariant retenu est plus fort et se
vérifie sans seuil : *la structure est divisée par le SOMMET de son anneau, jamais
par sa moyenne*, si bien que **le cookie cuit n'éclaire jamais plus que celui
qu'il remplace, à aucune distance et sous aucun angle**.
### Une garantie tenue par une ligne que rien ne relie à elle (2026-08-24)

Retirer le repli analytique de l'éblouissement était juste — sans cookie, la
torche ne rend aucune lumière, donc rien ne doit être subi. Mais le changement a
**déplacé une charge sans le dire** : tant que le repli existait, une arme sans
cookie éblouissait quand même — moche, et bruyant à sa façon. Depuis, elle ne
fait **rien du tout** : ni lumière, ni pénalité, ni exception.

Le seul signal restant est **une ligne, dans un autre fichier** — le
`push_error` de `WeaponData.get_torch_texture()`. Le jour où quelqu'un la
dégrade en `print()` pour nettoyer la console, ou la retire parce qu'« elle ne
sert à rien, les cookies sont versionnés », la torche silencieusement
inoffensive revient, et cette fois sans repli pour l'atténuer.

**Le commentaire disait « un cookie manquant reste bruyant » — une propriété
vraie, sans dire de quoi elle dépend.** C'est la forme la plus discrète de la
journée, et la cinquième : après le contrôle hors sujet, l'entrée barrée, la
liste d'appuis périmée et le nombre sans son échelle, voici **la garantie dont
personne ne sait ce qui la tient**. Aucune ne ment ; toutes dispensent d'aller
voir.

Relevée par la session « assets visuels », qui a vu dans le changement d'une
autre ce que celle-ci ne pouvait pas voir dans le sien — c'est le motif de toute
la journée, et il a fonctionné six fois.

**La parade appliquée :** nommer la dépendance **du côté qui en dépend**, pas du
côté qui la fournit. Le fichier qui lève l'erreur n'a aucune raison de savoir
que l'éblouissement s'y adosse ; celui qui s'y adosse, si. Un contrôle qui
relierait vraiment les deux reste à poser, et il vit chez le fournisseur : *une
arme dont le cookie n'existe pas rend `null` et ne se tait pas*.

### Un nombre sans son échelle n'est pas un nombre (2026-08-24)

Quatre plafonds d'éblouissement transmis à la session voisine — « pistolet
0,931, fusil 0,914, pompe 0,686, arbalète 0,188 ». **Le premier était une
pénalité, les trois autres des lectures brutes de texture**, et il y a une racine
carrée entre les deux échelles. L'arbalète y passait pour tomber à 0,188 alors
qu'elle tombe à **0,434**.

Personne n'aurait pu le voir : les quatre nombres sont plausibles, du même ordre
de grandeur, et rangés dans un joli tableau. Le destinataire s'apprêtait à les
comparer aux siens après fusion — il aurait trouvé 0,43 là où on lui annonçait
0,19 et **conclu que la fusion avait cassé quelque chose**.

La cause n'est pas l'étourderie, elle est dans l'outil : `planche_eblouissement`
imprimait le **brut** dans un bloc et l'**après-courbe** dans un autre, à trente
lignes d'écart. Citer un mot de chaque était l'erreur naturelle. **Deux échelles
imprimées à deux endroits SONT un nombre sans son échelle** — le banc les met
désormais côte à côte sur la même ligne, colonnes nommées.

Même famille que le demi-angle pris pour un angle plein, et que l'alpha de
texture pris pour de la clarté perçue : **une grandeur qui change de sens en
chemin, sans changer d'unité ni de nom.** C'est la troisième fois dans ce
document. La parade est toujours la même : nommer l'échelle *à l'endroit où le
nombre se lit*, jamais dans un commentaire ailleurs.

### La planche a sorti une image qui contredisait son propre chiffre (2026-08-24)

`planche_eblouissement` imprimait « bout de portée → 0,217 » **sous une image
montrant le joueur visiblement HORS du faisceau**. Les deux étaient exacts, et
pris à deux instants différents : la valeur pendant que le banc maintenait les
deux joueurs en place, l'image 350 ms plus tard, pendant le repos de la pose —
moment où plus personne ne replaçait J2 et où la visée de J1 continuait de
suivre la souris.

**C'est le pire défaut possible pour cet outil précisément**, parce qu'il existe
pour comparer *ce qu'on subit* à *ce qu'on voit* : il cassait le seul lien qu'il
était chargé d'établir. Une planche dont l'image contredit son chiffre est pire
qu'une planche absente — on croit avoir vérifié.

Deux remèdes, et le second est le plus utile : la scène est désormais **tenue
pendant le repos ET pendant la capture** (`_poser_en_tenant`), et la valeur est
**relue après l'image**, l'écart avec celle d'avant étant imprimé quand il
dépasse 0,05 (« poste instable »). Le banc ne peut donc plus mentir en silence :
soit les deux instants concordent, soit il le dit.

**Généralisable :** dès qu'un outil relève un nombre et une image, il doit ou
bien les prendre au même instant, ou bien **mesurer et publier leur écart**.
Aucun contrôle ne l'aurait vu — c'est un défaut qui ne se lit que sur la planche
elle-même, en regardant.

### `uptime` ment sur la contention ; comptez les Godot (2026-08-24)

Le piège « un lanceur lent ne dit rien du code, il dit qui d'autre travaille »
(2026-08-19) conseille de **regarder `uptime` avant d'accuser une suite**. Le
conseil est bon et l'indicateur est mauvais — mesuré en trois passages de
`run_duo.sh --ralenti` sur le même code :

| essai | charge moyenne | instances Godot | verdict |
|---|---|---|---|
| 1 | **3,76** | **5** | ÉCHEC |
| 2 | 4,31 | 2 | OK |
| 3 | 4,29 | 2 | OK |

**La charge était PLUS BASSE sur l'échec.** Elle est une moyenne glissante : elle
monte après coup et redescend lentement, donc elle décrit la minute précédente,
pas celle qui commence. Ce qui prédit, c'est le nombre de processus Godot en vol
— `ps aux | grep -c '[G]odot'` — parce que la ressource disputée n'est pas le
CPU en général mais **les temporisateurs de deux instances qui doivent se
répondre en moins de 30 s**.

Signature à reconnaître, pour ne pas chercher au mauvais endroit : l'hôte sort en
**code 1 avec zéro assertion en échec** et annonce « aucun adversaire n'a
rejoint », pendant que le journal du CLIENT montre `connected to server`,
`peer connected` **et** la poignée de main acceptée. Les deux moitiés se sont
trouvées ; seule l'attente a expiré. Et le sous-ensemble qui rougit **change d'un
passage à l'autre** — un vrai défaut ne se déplace pas.

### Une entrée barrée empêche le suivant de regarder (2026-08-24)

Relevé par la session « assets visuels » sur `main`, et c'est le plus retors de
la journée. Une entrée **fermée** du 2026-08-18 disait :

> Le `0.866` y était écrit en dur, deux fois, sans dire qu'il valait 30° : c'est
> un **réglage d'équilibre**, il porte maintenant un nom et deux tests
> l'encadrent à 29° et 31°.

Le dépôt a donc **regardé cette constante, l'a jugée, l'a nommée et l'a figée
par deux tests — sans jamais remarquer qu'elle applique un seul angle à quatre
armes allant de 5° à 60°.** Le remède documenté n'a pas raté le défaut : il l'a
**consolidé**. Un nombre nu invite à demander d'où il sort ; un nombre baptisé
« réglage d'équilibre » et encadré de tests a l'air décidé.

**C'est « ne prenez pas le silence des suites pour une validation » d'un cran
au-dessus : ne prenez pas une entrée barrée pour un problème résolu.** Une
fermeture dit ce qui a été fait, jamais ce qui a été vu. Les deux tests
existaient bel et bien ; ils vérifiaient la constante contre elle-même.

**Corollaire de rédaction, payé deux fois dans la même heure :** en signalant ce
défaut j'ai cité de mémoire une entrée de ma propre branche comme si elle était
sur `main`. Deux fois. **Décrire au présent ce qui n'est pas encore fusionné est
la version personnelle du même piège** — et elle se corrige avec un `git show
origin/main:<fichier>`, qui coûte trois secondes.

### Le contrôle a attrapé l'erreur que son commentaire annonçait (2026-08-24)

En écrivant `intensite_texture`, le repère perpendiculaire a été posé avec
`avant.orthogonal()` — qui rend `Vector2(y, -x)`, c'est-à-dire **l'autre sens**
que le `Vector2(-y, x)` de la transformée du nœud. Le commentaire juste au-dessus
annonçait que c'était la seule ligne où une erreur de signe passerait inaperçue.
Elle serait passée : **les quatre textures actuelles sont symétriques en y**,
donc un faisceau retourné rend exactement les mêmes valeurs. Le jour où un cookie
peint cesserait de l'être — c'est-à-dire au lot suivant — la pénalité se serait
posée du mauvais côté du faisceau, sans qu'aucune suite ne bouge.

Ce qui l'a prise : un contrôle sur une **image asymétrique**, écrit exprès pour
ça, sur une propriété que la texture de production ne peut pas exercer. C'est la
seule leçon utile ici — **un test qui n'emploie que les données de production ne
peut pas voir les symétries qu'elles cachent.**

Deuxième leçon, plus petite et plus fréquente : les quatre contrôles de repère
ont d'abord échoué pour une raison qui n'avait rien à voir. Un alpha en
`FORMAT_RGBA8` est quantifié sur 8 bits, 0,5 en ressort à 0,50196, et
`is_equal_approx` compare à ~1e-6. **L'échec ressemblait trait pour trait au
défaut qu'on traquait.** Une tolérance nommée, plus large que la quantification
et bien plus fine que l'erreur cherchée (un repère retourné donne 0,25 au lieu de
0,5, jamais 0,502), sépare les deux.

### Un banc qui reproduit en panne le défaut qu'il traque (2026-08-24)

`tools/planche_eblouissement.tscn` presse `p1_torch` pour allumer la torche.
**Si cette action quittait l'Input Map, la torche ne s'allumerait jamais et tout
le relevé rendrait zéro** — c'est-à-dire trait pour trait la signature du défaut
de 2026-08-18 que cette planche existe pour surveiller. Le banc annoncerait la
panne qu'il est chargé de détecter, avec des chiffres parfaitement plausibles,
et on irait chercher dans `eblouissement.gd`.

**Ce n'est pas un cas particulier, c'est une propriété des bancs de bout en
bout :** ils partagent leurs appuis avec ce qu'ils mesurent, donc leurs pannes
imitent les défauts qu'ils cherchent. D'où la règle : **un banc doit vérifier
ses appuis AVANT de mesurer, et échouer bruyamment plutôt que rendre zéro.**
`preconditions_manquantes()` les nomme, `tools/test_banc.gd` les lit en headless.
C'est la parade déjà écrite pour `bench_framerate` — appliquée cette fois avant
la première panne, parce que le pire moment pour la découvrir était identifiable
d'avance : le jour où il faudra rejuger l'éblouissement après le lot des cookies.

**Corollaire, et il vaut au-delà des bancs : un zéro est la valeur la plus
dangereuse du dépôt.** Il est le résultat légitime de « hors du faisceau », le
résultat d'une panne d'entrée, et le résultat d'un fichier qui ne compile pas.
Partout où zéro peut vouloir dire trois choses, il faut le **nommer** — d'où le
« MUR entre les deux, relevé sauté » de la planche plutôt qu'un 0,000 aligné
avec les autres.

### Un banc qui vacille est pire qu'aucun banc (2026-08-24)

Deux passages consécutifs de la même planche, sur le même code : l'un rend un
relevé de cohérence complet, l'autre « MUR entre les deux » sur les **quinze**
postes. Les deux sont honnêtes. La cause n'est dans aucun des deux : la carte est
tirée au hasard, le point d'apparition tombe où il tombe, et la visée de J1 suit
la souris — donc une direction fixe mais **arbitraire**, constante pour toute
l'exécution. Le relevé se faisait un coup dans un couloir, un coup contre un mur.

Un outil qui donne deux verdicts opposés apprend à ignorer son propre lanceur, et
le jour où il dit vrai, personne ne le croit. La planche cherche donc à J1 un
emplacement dégagé, en anneaux concentriques — **en exigeant que le chemin
jusque-là soit libre lui aussi**. Sans cette seconde condition on téléporte le
joueur dans la pierre et on mesure un dégagement parfait vu de l'intérieur d'un
mur : la mesure est juste, le repère est faux.

### Une erreur d'analyse fait tourner la scène sans script, et sort en 0 (2026-08-24)

Une inférence de type ratée (`var espace := …` sur un `Node` non typé) a suffi :
`Failed to load script`, la scène tourne **sans script**, ne mesure rien, n'écrit
rien, et le processus sort proprement en **0**. Un passage complet perdu avant de
comprendre — et le lanceur annonçait « les outils visuels sont passés ».

C'est la troisième forme du même piège dans ce document, après la suite qui pend
et le banc qui pilotait un bouton disparu. `run_suites.sh` s'en protégeait déjà
en grepant `SCRIPT ERROR` malgré un code 0 ; `run_visuel.sh` ne le faisait pas.
Il relit désormais la sortie de ses trois outils et cherche `Parse Error` et
`Failed to load script`.

**La règle, sous sa forme la plus courte : le code de sortie ne suffit jamais à
dire qu'un outil a travaillé.**

### Exact au chiffre près, et faux à l'œil (2026-08-24)

**L'éblouissement recopiait la texture de torche terme pour terme, et c'est
précisément ce qui clochait.** `Vision.intensite_recue` porte le commentaire
« recopié du rendu à dessein — deux formules pour un même faisceau finiraient
par diverger » ; le raisonnement est juste et la conclusion l'était aussi. Elle
avait seulement un angle mort : **l'alpha d'une texture et la clarté perçue ne
sont pas la même quantité.** Sur du noir absolu, 5 % de lumière se lit encore
comme « éclairé ».

Mesuré au banc visuel : à 95 % de la portée du pistolet, un joueur se tient dans
une plaque de lumière franchement visible et prenait **0,050** de pénalité —
c'est-à-dire un voile invisible. Le dernier tiers du faisceau éblouissait bien
moins qu'il n'éclairait, et **aucune suite ne pouvait le dire**, puisque la
valeur calculée était exacte au regard de la formule qu'on lui demandait de
suivre.

**La leçon n'est pas « la formule était fausse ».** Elle est : *une grandeur
recopiée d'un système à l'autre change de sens en chemin.* La copie garantit que
les deux nombres restent égaux ; elle ne garantit pas qu'ils veulent dire la
même chose des deux côtés. C'est la même famille que le demi-angle pris pour un
angle plein — un nombre dont l'unité se devine — d'un cran plus abstrait : ici
l'unité est explicite, c'est l'**usage** qui diffère.

Le correctif est donc une conversion nommée (`Eblouissement.plafond_pour`) et
non une retouche de `vision.gd` : la géométrie reste le miroir de la texture,
et la traduction « lumière reçue → ce que ça coûte » vit là où elle est un
réglage d'équilibre.

### Ce qu'on voit n'a pas de nom, donc rien ne le tient (2026-08-24)

**Le voile d'éblouissement peignait par-dessus le HUD**, et personne ne l'avait
décidé : `dazzle_hbox` était simplement `add_child` après la rangée de HUD, et
dans un `CanvasLayer` l'ordre de déclaration EST l'ordre de dessin. À
saturation, un joueur ne lisait plus sa propre vie, son cercle de recharge ni le
chrono. Trente-cinq suites vertes, et le défaut se voit en une image.

C'est la troisième fois que le dépôt écrit la même chose — « on mesure ce qui
s'écrit, pas ce qui se voit » (2026-08-19), puis « 53 suites vertes et un écran
de menu invisible ». Ce cas-ci ajoute une précision utile : **il n'existe pas de
contrôle raisonnable pour cet ordre.** Un test qui comparerait deux indices
d'enfants passerait au vert le jour où le HUD déménagerait dans un autre nœud,
et échouerait sur tout réagencement innocent. Ce qui protège ici est un
commentaire posé à l'endroit exact où quelqu'un serait tenté de déplacer la
ligne — assumé comme tel, avec ce que ça vaut.

**Et le corollaire pour la planche de contact :** elle n'a rien affirmé, elle a
seulement posé l'image. C'est ce qui lui a permis de trouver un défaut que
personne n'aurait su formuler d'avance.

### Un `.godot` périmé fait échouer les bancs à deux instances, et l'erreur ment (2026-08-24)

Après une fusion qui apporte des fichiers neufs — polices, et surtout des
scripts portant un `class_name` — le cache d'import n'est plus à jour. Godot ne
retrouve alors ni `UpdateManifest` ni `UpdateInstaller`, l'autoload
`update_manager.gd` **ne compile pas**, et tout ce qui suit s'écroule.

**Ce qu'on voit n'a aucun rapport avec la cause.** Le banc annonce « l'hôte n'a
pas ouvert de salon en 60 s », puis déroule vingt lignes de
`Invalid assignment of property 'offset' … on a base object of type 'Nil'` dans
`game_state._process`. On cherche une régression de caméra ; il n'y en a pas.
La caméra est nulle parce que `_ready` n'est jamais allé jusqu'à
`_setup_players()`, et le `tail -20` du journal d'hôte ne montre que la fin de
la cascade — jamais la ligne qui l'a déclenchée.

Deux réflexes, dans cet ordre : **lire le DÉBUT du journal d'hôte**, pas sa fin ;
et après tout `git merge`/`git pull` qui apporte des fichiers, lancer
`godot --headless --path . --import` avant les suites. Ouvrir le projet dans
l'éditeur fait la même chose — c'est pour ça que le piège ne se voit pas sur le
poste d'Adrien, seulement dans une session qui ne lance jamais l'éditeur.

Accessoirement, le cache périmé coûte aussi du temps : le même lot est passé de
**898 s à 202 s** une fois l'import refait.

### 53 suites vertes, et un écran de menu entièrement invisible (2026-08-24)

**Le lot complet est passé — 229 s, code 0, aucune erreur de script — pendant que
la colonne de gauche du hub était à `modulate.a = 0` après chaque navigation.**
Toute la liste d'entrées d'un écran, invisible. Seul le liseré de sélection
restait à l'écran, parce qu'il vit dans un nœud séparé du corps de l'écran : ce
qu'on voyait était un cadre bleu vide au-dessus du vide.

**C'est la planche de contact qui l'a montré**, à son premier emploi réel dans ce
chantier. `test_vitrine_menus` et `test_menu_hub` étaient verts : ils vérifient
que les entrées existent, sont atteignables au curseur et retrouvent leur alpha
après une coulée d'encre — **jamais qu'elles sont visibles à l'instant où on
regarde l'écran**.

C'est la formule déjà écrite le 2026-08-19, confirmée une troisième fois : **on
mesure ce qui s'écrit, pas ce qui se voit.** Et le corollaire tient : `run_visuel.sh`
n'est pas une politesse de fin de tâche, c'est le seul contrôle du dépôt qui
regarde.

**La cause :** voir l'entrée suivante.

### Nommer une égalité interdite, plutôt qu'une valeur attendue (2026-08-24)

**La règle qui explique pourquoi certains contrôles attrapent des choses et
d'autres non.** Formulée par la session « assets visuels », à partir d'un défaut
de son propre lot ; écrite ici parce qu'elle vaut pour tout le dépôt.

Le mur n'est pas « le visuel ne se teste pas ». C'est qu'on essaie de nommer la
mauvaise chose. « Ce cookie de torche a la bonne allure » n'est pas assertable et
ne le sera jamais — mais **une texture ne fait pas que ressembler à quelque
chose, elle DÉCIDE de choses**, et celles-là ont des noms.

Le cas qui l'a produite : la cuisson des cookies de torche déplaçait la
**quantité de lumière** de chaque arme — jusqu'à **+96 % sur l'arbalète**,
c'est-à-dire sur l'arme furtive, sans qu'une seule ligne d'équilibrage ne bouge.
La question à poser devant tout asset : *qu'est-ce que cette texture décide, en
plus de son allure ?*

⚠️ **Et sa contrepartie, sans quoi l'exemple dit le contraire de la règle.**
Conserver l'énergie était juste **parce que la décision en cours était
esthétique** — on remplaçait un dégradé par une image peinte, pas on ne réglait
l'éclairage. Le jour où l'on voudra régler la lumière pour de bon, il faudra
qu'elle bouge, et un banc qui l'aurait figée serait alors l'obstacle.

**La règle n'est pas « ne rien déplacer », c'est « ne rien déplacer sans le
savoir ».** Un contrôle qui interdit le mouvement se transforme en carcan à la
première vraie décision ; un contrôle qui l'oblige à être **explicite** ne gêne
jamais celui qui sait ce qu'il fait. Nuance apportée par la session « assets
visuels », qui a prévu un `--energie libre` pour ce jour-là.

**Le corollaire est la vraie trouvaille : la propriété la plus rentable à nommer
est presque toujours une ÉGALITÉ INTERDITE, ou une égalité EXIGÉE — jamais une
valeur attendue.** Vérifié après coup sur tout ce qui a fonctionné le
2026-08-24, et les quatre contrôles avaient été écrits séparément sans que
personne voie la forme commune :

| Contrôle | Forme | Ce qu'il a attrapé |
|---|---|---|
| le vert n'entre pas dans l'arène | interdiction | (préventif) |
| la luminance de l'adversaire n'a pas bougé | égalité exigée | un commentaire faux de 8 % |
| deux graisses rendent des chasses différentes | égalité interdite | la clé `wght` en chaîne, sans effet |
| les dix chiffres font la même largeur | égalité exigée | une fonte non tabulaire |

Aucun ne demande de décider ce qui est beau, et tous attrapent la classe de
défaut qui passe sous les suites : **celle où quelque chose est resté identique
alors que ça aurait dû bouger.**

#### ⚠️ La règle ne suffit pas : il faut aussi le bon espace

**Contre-exemple fourni par la session qui a formulé la règle, sur son propre
lot — et il est plus instructif que la règle.**

Elle avait nommé la bonne grandeur : *l'énergie totale de la torche est
conservée*. Le contrôle était écrit, il passait, il annonçait **0,2 % d'écart**.
Et la portée des torches avait quand même doublé.

Parce que la mesure se faisait **en coordonnées de texture**, où tout allait
bien. En unités de monde — c'est-à-dire là où le jeu se joue — la même texture
recuite de 512² en 1024² portait deux fois plus loin, `texture_scale` multipliant
la taille *propre* de l'image. C'est Adrien qui l'a vu à l'écran, en une phrase.

> **Nommer la bonne grandeur ne suffit pas, il faut la mesurer dans le bon
> espace.**

Et le mode de défaillance mérite son nom : **le contrôle n'était pas faux, il
était HORS SUJET** — ce qui est plus difficile à voir qu'une erreur, *parce qu'il
passe au vert*. Une suite rouge envoie chercher ; une suite verte qui mesure
autre chose que ce qu'on croit **rassure**, et c'est le seul état dont personne
ne se méfie.

D'où le corollaire pratique, qui s'ajoute à la règle plutôt qu'il ne la
remplace : après avoir nommé la grandeur, **nommer l'espace dans lequel elle a un
sens pour le joueur**. Une luminance se juge à l'écran, pas dans un atlas ; une
portée en fractions de champ de vision, pas en unités ; une chasse de fonte en
pixels rendus, pas en unités de police.

Le motif complet, pour un asset qui en remplace un autre : comparer sur des
grandeurs invariantes, et **échouer s'ils sont trop proches OU trop loin** — trop
proches, on a livré un fichier qui ne change rien ; trop loin, on a déplacé
l'équilibrage en croyant faire de l'art.

**Chantier ouvert, délibérément pas fait le jour même :** un banc qui réclame les
quatre états d'une entrée de menu (repos, survol, sélection, curseur) et exige
qu'ils soient deux à deux distinguables. Il aurait attrapé les trois défauts
qu'Adrien a trouvés à l'œil. Il n'est pas écrit pour deux raisons : la session
qui venait d'introduire deux de ces trois défauts est **le plus mauvais juge de
son seuil** — elle le poserait là où son code passe ; et le seuil doit être
**résolu** depuis un contraste perceptuel, pas choisi.

### Un menu peut être cohérent partout et illisible quand même (2026-08-24)

**Le correctif de la sélection a rendu visible un défaut plus ancien : les deux
états ne portaient pas des ÉTATS, ils portaient des SUJETS.**

Chaque entrée teintait son survol et sa sélection avec **son propre accent**.
Rien que sur l'accueil, quatre couleurs : bleu pour les modes de jeu, ambre pour
le compétitif, gris pour les réglages, rouge pour QUITTER. Survoler « 1V1
COMPÉTITIF » donnait donc de l'ambre, et survoler sa voisine du bleu pâle sur du
noir — c'est-à-dire presque rien. **« Ambre » ne voulait pas dire
« sélectionné », il voulait dire « cette entrée-là est dorée ».**

Et les deux états ne différaient que par l'opacité — **6 % contre 12 %** — et un
pixel de bordure. Mesuré sur une entrée réelle : ses trois styleboxes rendaient
la même valeur. À la souris, indiscernables.

**Arbitrage d'Adrien : un rôle, une couleur.** Trois signaux, trois couleurs, et
elles ne dépendent plus du sujet :

| Signal | Couleur | Ce qu'il dit |
|---|---|---|
| survol souris | **acier** | le curseur passe ici |
| sélection | **ambre**, pour toute entrée | c'est elle que le cadre de droite montre |
| liseré | **bleu / rouge** | le curseur d'un joueur |

L'accent propre à l'entrée survit **là où il dit quelque chose de vrai** : le
chevron. Le compétitif reste doré et QUITTER rouge, sans que ça déteigne sur la
lecture de l'état. Et l'appui montre désormais l'ambre — ce que l'entrée est sur
le point de devenir — au lieu de retomber sur le style le plus faible.

**Ce que ça généralise :** une couleur qui encode à la fois *quoi* et *dans quel
état* n'encode ni l'un ni l'autre. Le joueur ne peut pas savoir si l'ambre parle
du sujet ou de l'état, donc il n'apprend ni l'un ni l'autre — et il ne peut même
pas nommer ce qui le gêne. Adrien a mis trois messages à le formuler ; le défaut
était là depuis l'écriture du hub.

### Un état branché sur `focus_entered` n'existe pas pour un curseur maison (2026-08-24)

**Relevé par Adrien à l'écran, et c'est la troisième fois que ce décrochage coûte
quelque chose.**

L'apparence de l'entrée SÉLECTIONNÉE — celle qui commande le cadre de droite —
vivait dans la stylebox `focus` de Godot, alimentée par `btn.focus_entered`. Or
les deux curseurs du jeu sont maison : ils dessinent un liseré et n'appellent
jamais `grab_focus()`. Conséquences, aucune signalée par quoi que ce soit :

- **à la manette et au clavier, aucune entrée n'était jamais peinte**, de toute
  une session ;
- **à la souris**, l'ambre restait collé sur le dernier bouton *cliqué*, même
  quand la sélection avait changé par un autre chemin — donc il désignait
  régulièrement une entrée qui ne commandait plus rien.

**Le commentaire du code affirmait pourtant « la sélection est franche — bordure
épaisse et fond deux fois plus dense ».** Il décrivait une intention. Pire : je
l'ai lu en cherchant la cause, je l'ai cru, et j'ai répondu à Adrien que l'ambre
était présent mais trop faible. **Il était absent.** C'est le piège « un
commentaire décrit une intention, on le relit comme un constat », payé une fois
de plus — et cette fois par celui qui venait de le citer.

**Ce qui a tranché : une capture d'écran d'Adrien**, où le cadre de droite
affichait le texte d'EFFETS pendant qu'aucune entrée ne portait de marque. Deux
relectures de code ne l'avaient pas vu.

**Le correctif, et pourquoi il était à moitié fait depuis six jours.** Le relais
`MenuHub.reveal_entry()` avait été posé le 2026-08-18 pour exactement cette
raison — et il n'alimentait que le **cadre de droite**. La moitié du décrochage
était corrigée, l'autre non. La sélection se peint désormais à la main
(`_peindre()`), sur `normal` **et** `hover` : sans le second, survoler l'entrée
choisie la ferait régresser vers la lueur de survol, c'est-à-dire paraître moins
choisie au moment où on la vise.

**Deux défauts voisins corrigés dans la foulée**, tous deux visibles une fois le
mécanisme réparé : `pressed` retombait sur le style de **survol**, le plus faible
des trois — au moment précis où l'on appuie, le bouton faiblissait ; et `AUDIO`
portait `COLOR_P1` quand ses trois voisines de colonne portaient `COLOR_GOLD`,
sans qu'aucune raison ne le justifie.

**Densité arbitrée par Adrien : discrète.** C'est la bordure qui identifie —
deux pixels d'ambre plein — et le fond ne fait que réchauffer, à un huitième
d'opacité. Un premier essai au quart donnait un aplat : l'entrée cessait d'être
*choisie* pour devenir un bouton d'une autre couleur, et son libellé y perdait
son contraste. **Bleu autour, ambre dedans**, et le liseré du curseur reste le
premier lu — c'est lui qui dit où l'on est.

### Où les deux instruments ne regardent pas (2026-08-24)

Le dépôt a maintenant **deux** instruments de vérification, et il vaut mieux
savoir ce qu'ils ne voient ni l'un ni l'autre que de croire qu'à eux deux ils
couvrent l'écran.

| Instrument | Ce qu'il atteint | Ce qui lui échappe |
|---|---|---|
| `run_suites.sh` | des états, des comptes, des transitions — tout ce qui a un **nom** dans le code | ce qui n'a de nom nulle part : une position, une couleur, une opacité |
| `run_visuel.sh` | ce qui se **voit**, sur les écrans qu'il visite | tout le reste des écrans, et tout ce qui n'est pas un état posé |

**Leur intersection laisse un trou nommable, et le voici : la killcam.** Aucune
suite ne l'exerce — elle demande une mort, donc une manche — et la planche ne la
visite pas. C'est là qu'un défaut attend le premier mort d'une vraie partie,
c'est-à-dire un joueur.

Ce n'est pas théorique : c'est exactement où le fil de la teinte de torche a été
trouvé le 2026-08-24, **par une lecture de code d'une autre session**, sur un
chemin que ni le lot vert ni les treize images n'auraient signalé.

**La leçon de méthode, et elle vaut au-delà de la killcam :** deux instruments
qui passent au vert ne disent rien d'un endroit qu'aucun des deux n'atteint. Un
lot annoncé « vérifié » devrait nommer ce qui n'a pas pu l'être — c'est moins
confortable et c'est la seule forme honnête.

**Autres zones dans le même cas, pour qu'elles cessent d'être invisibles :** les
écrans de salon et d'appariement (la planche les écarte exprès — y entrer ouvre
de vrais salons EOS), le second écran en jeu, et tout ce qui demande deux
machines. Les trois se vérifient à la main, et ne se vérifient qu'ainsi.

### Un `duplicate()` n'emporte que ce qui est déjà posé (2026-08-24)

Les fantômes de la killcam ne créent pas leur torche, ils la **dupliquent** —
`game_state.gd:_setup_ghosts()` fait `p1.get_node("Flashlight").duplicate()`. Une
propriété écrite **après** la copie n'y est donc jamais.

La teinte du faisceau avait d'abord été posée dans `equip_weapon()`. Elle
survivait quand même, par une chaîne de **trois maillons** : `_setup_players()`
précède `_setup_ghosts()`, `add_child(p1)` déclenche `_ready` synchronement, et
ce `_ready` appelle `equip_weapon()` avant de rendre la main. Intervertir deux
lignes, ou sortir `equip_weapon` du `_ready`, et **les torches de killcam
devenaient blanches** — invisible jusqu'au premier mort, c'est-à-dire découvert
par un joueur et non par un test.

**La règle : ce qui doit survivre à une copie se pose à la CONSTRUCTION, jamais
dans une méthode appelée plus tard.** La teinte vit maintenant à côté de
`energy` et des masques de calque, avec les autres propriétés qui ne dépendent
pas de l'arme — et elle ne dépend plus d'un ordre d'appel.

Relevé par la session « assets visuels », **en lecture de code**, sur un chemin
qu'aucune suite ne couvre et que la planche de contact ne voit pas non plus : la
killcam n'est dans aucun des deux.

### Godot efface les commentaires de `project.godot` (2026-08-24)

Le réglage `gui/theme/custom_font` avait été posé avec douze lignes expliquant
*pourquoi* la fonte d'interface vit là plutôt que Control par Control. **Elles
ont disparu**, le fichier étant réécrit dans son ordre canonique sans aucun
commentaire. Le réglage, lui, a survécu — donc rien ne signale la perte.

⚠️ **Première rédaction : « au premier enregistrement de l'éditeur ». C'est plus
large que ça, et la correction change la conclusion.** Relevé par la session
« assets visuels », qui les a restaurés deux fois dans l'après-midi et les a vus
repartir entre les deux, **sans jamais ouvrir l'éditeur** : `--headless --script`
suffit. Autrement dit, **`./tools/run_suites.sh` efface ces commentaires**, et
n'importe qui lançant une suite le fait aussi.

Ce n'est donc pas « quelqu'un a été distrait », c'est **« exécuter le projet
efface ces commentaires »**. Déplacer l'explication n'est pas la meilleure des
deux options, c'est **la seule qui tienne**.

**Un commentaire dans un fichier regénéré est un commentaire qu'on écrit pour
soi.** L'explication a été déplacée dans `charte.gd`, à côté de `CHEMIN_UI`.
Vaut pour `project.godot`, les `.import`, et tout ce que l'éditeur réécrit.

**Complément mesuré le 2026-08-24, parce que la portée exacte change ce qu'on en
fait.** Le coupable est bien **l'éditeur**, et lui seul : `ProjectSettings.save()`
appelé par l'extension `godot_ai` (`plugin.gd`, `input_handler.gd`). Trois
lancements ont été chronométrés sur le même fichier, commentaires en place :
`--headless --quit` les laisse **intacts**, `--headless --import` aussi, et
`./tools/run_suites.sh` en entier — trente-sept exécutions, 196 s — **également**.
La boucle de test ne détruit donc rien ; ouvrir le projet dans l'éditeur, si.
Le dire précisément évite d'aller chercher un coupable dans les suites, et évite
surtout de croire qu'une explication ne survit à rien.

**Et la conclusion va plus loin que le déménagement.** Un commentaire, où qu'il
vive, n'empêche personne de « ranger » les autoloads par ordre alphabétique dans
six mois. Les deux contraintes d'ordre de `project.godot` sont donc devenues un
banc — `tools/test_autoloads.gd` : **`PatchLoader` en premier** (un correctif
`.pck` monté après un autoload ne le recouvre plus, sans erreur) et
**`GameSettings` après `InputSetup`** (sinon les liaisons par défaut recouvrent
le remappage du joueur, perdu à chaque lancement, en silence). Le banc a été
vérifié **en cassant les deux règles l'une après l'autre** : chacune rend le lot
rouge avec la marche à suivre, et la remise en place le rend vert. La seconde
règle vivait dans `CLAUDE.md` depuis l'origine et n'était protégée par rien.

### Une propriété qui se pose sans effet et sans erreur (2026-08-24)

**Deux fois dans la même heure, en câblant les fontes.** On écrit quelque chose
de correct, la propriété se relit correctement, et **le rendu ne change pas d'un
pixel**. C'est la famille de défaut la plus chère du dépôt — la même que les noms
de nœuds auto-générés de la Phase 3, un cran plus bas.

1. **`opentype_features = {"tnum": 1}` sur une fonte qui n'a pas la
   fonctionnalité.** Le dictionnaire contient bien la clé ; les chiffres restent
   proportionnels. Le chrono continue de sauter, et rien ne le dit.
2. **`variation_opentype = {"wght": 900}` avec une clé en CHAÎNE.** Seul le tag
   **entier** agit (`2003265652`). Mesuré sur « CANDELA » en 40 px : 75 px de
   large quelle que soit la graisse avec la chaîne, 75 → 131 px avec l'entier.
   Sans cette mesure, le dépôt aurait remplacé son faux gras par un autre faux
   gras, en annonçant l'avoir supprimé.
3. **`Object.set("modulate:a", 0.5)` — la plus chère des trois.** `tween_property`
   accepte les chemins de sous-propriété, et une bonne moitié des animations du
   dépôt sont écrites ainsi. `set()`, lui, cherche une propriété portant ce nom
   **littéral**, ne la trouve pas, et se tait. Vérifié : `set("modulate:a", 0.4)`
   laisse l'alpha à 1,0 ; `set_indexed(NodePath("modulate:a"), 0.7)` le pose. Le
   premier jet de `Charte.animer()` employait `set` — d'où l'écran de menu
   invisible de l'entrée précédente.

**La parade est la même dans les deux cas, et elle est générale : contrôler
l'EFFET, jamais le réglage.** `tools/test_charte.gd` mesure la largeur de deux
graisses et exige qu'elles diffèrent ; il mesure les dix chiffres et exige qu'ils
soient égaux. Un contrôle qui relirait la propriété passerait au vert dans les
deux cas fautifs.

### `Color × float` multiplie aussi l'opacité (2026-08-24)

`ROUGE * 0.58` rend un rouge sombre **et à moitié transparent**. Une teinte
baissée n'est pas une teinte effacée : les dérivées de la charte sont opaques,
donc les facteurs portent sur les trois canaux et le banc compare en RVB. Relevé
par `test_charte` à son tout premier lancement — ce qui vaut mieux que de le
découvrir sur une tache de sang qu'on voit à travers.

### Un identifiant manquant dans `ui.gd` fait pendre trois suites (2026-08-24)

Une passe mécanique a écrit `T_DECOMPTE` dans `ui.gd` sans que la constante y
soit déclarée. **Une seule erreur d'analyse**, et le lot rend : six suites en
échec, **trois qui ne sortent pas du tout** (chien de garde à 120 s), plus une
cascade de `SCRIPT ERROR` désignant `game_state.gd:1099` — du code que personne
n'avait touché, et qui échouait parce que `ui.gd` ne se chargeait pas.

**Ce que ça confirme, et qui était déjà écrit ici : le message désigne le fichier
qui appelle, pas celui qui ne compile pas.** La bonne réaction a été de refuser de
« corriger » `game_state.gd` et d'aller chercher le `Parse Error`. La mauvaise
aurait été de toucher au netcode.

**Corollaire pour toute passe automatique sur des identifiants :** vérifier que
chaque symbole introduit est déclaré, avant de lancer le lot. `grep` le fait en
deux secondes ; le lanceur met dix minutes à le dire mal.

### Ne pas éditer `run_suites.sh` pendant qu'il tourne — repayé (2026-08-24)

Le piège était consigné plus bas depuis le 2026-08-18. Il a quand même été repayé
le 2026-08-24 : une ligne ajoutée à `SUITES=(…)` **pendant** l'exécution du lot,
pour y déclarer `test_charte`. Le lot a été arrêté et relancé, `bash -n` a
confirmé que le fichier était intact — mais dix minutes de mesure étaient perdues.

**Connaître un piège ne protège pas de lui.** Ce qui protège, c'est de ne pas
avoir la main sur le fichier au moment où il s'exécute : ajouter la suite
**avant** de lancer, ou après.

> ⚠️ **Repayé une TROISIÈME fois le 2026-08-25 — et le titre de cette entrée y
> est pour quelque chose.** J'éditais `tools/run_duo.sh` pendant qu'une autre
> session exécutait `run_suites.sh`. Chez elle : deux scénarios en échec avec
> des **erreurs de syntaxe bash à des lignes qui n'existent pas** en lecture
> normale. Rien dans son arbre n'était cassé ; `bash` relit un script au fil de
> son exécution, et il relisait un fichier que je réécrivais.
>
> **Le piège porte le nom d'UN fichier, et le danger est une CLASSE.** J'ai lu
> cette entrée, je me suis su prudent sur `run_suites.sh` — et j'ai édité le
> script qu'il appelle. Un titre trop étroit ne protège pas : il rassure.
> **La règle est : aucun script shell ne se modifie pendant qu'un lot tourne**,
> ni le lanceur, ni ce qu'il appelle, ni ce qu'ils sourcent.
>
> **Et le symptôme accuse un innocent**, comme le voleur de port : une erreur de
> syntaxe désigne le contenu du fichier, alors que la cause est *le moment*.
> Celui qui la reçoit relit son code et n'y trouve rien — parce qu'il n'y a rien.
>
> Le contrôle avant d'éditer un lanceur est le même que pour le port :
> `pgrep -f "run_suites|run_duo"`. Ici il répond juste — c'est bien le lanceur
> qu'on cherche.

### Un commentaire décrit une intention, on le relit comme un constat (2026-08-19)

Au-dessus de `ui.show_waiting_for_opponent()`, dans `_annoncer_deconnexion()`,
un commentaire affirmait en gras : « **le retour au salon a lieu dans TOUS les
cas** […] c'est lui qui ramène le menu ». Il avait été écrit **en corrigeant ce
défaut-là**. `show_waiting_for_opponent()` n'allume qu'un **label du HUD de
match** — aucun menu n'est ramené, et l'hôte restait dans son arène sans aucun
moyen de se déclarer prêt.

**Deux passes perdues à raisonner à partir de ce commentaire**, plus un
diagnostic voisin cohérent et faux (`game_over` qui aurait fermé le menu). Ce
qui a tranché, ce sont **trois sondes** : ne pas refermer → rouge ; rouvrir seul
→ rouge ; rouvrir **et** ne pas refermer → vert. Le mécanisme concurrent était
un **second** verrou, jamais le premier.

**Sonder, pas raisonner, dès qu'un commentaire tient lieu de preuve.**

### Famille 4.1 — le vrai fond n'est pas le menu (2026-08-19, OUVERT)

Le menu réparé, le banc reste rouge pour une **autre** cause, mesurée : sur
l'hôte, `multiplayer.multiplayer_peer` est **null immédiatement après le départ
du client** (348 « No multiplayer peer is assigned » dans le journal). Le
serveur est démonté, donc **aucune reconnexion n'est possible** — ce n'est pas
un artefact de banc, c'est le jeu.

Piste, non confirmée : `_close_lobby_if_left()` dans `ui.gd` coupe le salon dès
qu'un changement d'écran survient alors que `get_peers()` est vide. Fichier
d'une autre session, qui a été prévenue.


### Un lanceur lent ne dit rien du code, il dit qui d'autre travaille (2026-08-19)

Le lot des suites headless a pris **3672 s — soixante-et-une minutes** un soir,
contre **111 s** le lendemain sur le même code. Une suite lancée seule prend
**2,6 s**. La différence est la **contention** : plusieurs sessions lançaient
Godot en même temps, charge moyenne à **10**.

**Ce que ça a failli coûter :** un mode `--rapide` a été ajouté sur l'hypothèse
que les six scénarios à deux instances « coûtaient l'essentiel ». Mesuré, c'est
faux — ils valent ~5 min sur les 222 s… non, sur un lot complet **de 222 s au
calme**, dont ~110 s pour eux. Le mode reste utile, mais son commentaire
affirmait une cause qui n'était pas la bonne, et il aurait envoyé le suivant
optimiser le mauvais endroit.

**Avant de découper, d'optimiser ou d'accuser une suite : regarder `uptime`.**
C'est le même motif que le banc de cadence — un chiffre qui mesure la machine et
qu'on prend pour une propriété du code.


### Un percentile ne se mesure pas en un passage (2026-08-18)

Le 1 % bas varie d'un relevé à l'autre **sur la même configuration** : 163, 169
puis 139 dans les menus ; 97 puis 81 dans le duel. La médiane, elle, ne bouge pas
d'une image.

Une explication structurelle avait été inventée pour le rendre acceptable — « la
charge des menus est ponctuée, celle du duel est continue » — et elle a tenu une
demi-journée avant que le duel donne 81. **Attribuer à la charge ce qui appartient
à l'instrument produit une règle qu'on va appliquer** ; c'est la forme d'erreur la
plus coûteuse, plus qu'un chiffre faux.

**La règle : la médiane tranche partout, le 1 % bas nulle part sans répétition.**
Un 1 % bas ne s'énonce qu'avec sa dispersion, sur plusieurs relevés.

### Lire le premier nombre d'une ligne dont le libellé en contient un (2026-08-18)

`grep -oE '[0-9]+' | head -1` sur « `FPS 1 % bas : 97` » rend **1**, le chiffre du
libellé. La première version de `run_decomposition.sh` a rapporté « 1 % bas = 1 »
pour ses sept relevés.

**On a été sauvés par l'absurdité du résultat.** La même erreur sur un libellé
sans chiffre — ou décalée d'un cran — aurait rendu **97** : plausible, faux, et
indétectable. Extraire **après le séparateur** (`sed -n 's/.*: *\([0-9]*\).*/\1/p'`),
jamais le premier nombre de la ligne.
### L'éblouissement n'a jamais fonctionné, et trente suites étaient vertes (2026-08-18)

Adrien : « j'ai l'impression que l'effet d'éblouissement ne fonctionne pas ».
Il ne fonctionnait pas. Il n'avait **jamais** fonctionné.

Deux lignes, dans deux fichiers, qui ne se sont jamais regardées : la montée
valait `+0,5/s` dans `game_state._check_dazzle`, la descente `−2,0/s` dans
`player._process` — **sans aucune condition**, donc y compris pendant qu'on
prenait le faisceau en pleine face. Bilan net sous une torche braquée : `−1,5/s`.
La valeur ne pouvait pas dépasser ce qu'une seule image avait le temps d'ajouter
avant d'être rabotée : **0,008 à 60 fps, 0,001 à 500 fps** — voile blanc à 0,6 %
d'opacité, pénalité de vitesse à 0,5 %. Trois effets branchés dessus, tous
morts.

**La leçon générale : une valeur intégrée dans le temps n'appartient qu'à un
seul `_process`.** Montée ici, descente ailleurs, et plus personne n'additionne.
Aucune des deux lignes n'est fausse isolément ; c'est leur somme qui l'est, et
la somme n'était écrite nulle part. L'intégration vit désormais dans
`game_state._maj_eblouissement`, pour les deux joueurs, en un seul endroit.

**Pourquoi les tests n'ont rien dit, et c'est le pire de l'affaire.**
`test_vision` couvrait le cône et l'occlusion — exactement les deux seules
parties qui **fonctionnaient**. La suite était verte, la mécanique était morte,
et la fiche de la ROADMAP annonçait la mécanique centrale comme « couverte
depuis le 2026-08-18 ». Un test qui couvre la moitié qui marche fabrique une
confiance pire que l'absence de test. D'où le premier contrôle de
`test_eblouissement`, qui a l'air trop bête pour être écrit : **sous une
lumière, la valeur monte.**

**Trois autres défauts sortaient du même trou**, tous invisibles pour la même
raison — rien ne comparait le mécanisme à ce que l'écran montre :

- **Le cône était écrit en dur à 30°** pour les quatre armes, alors que
  `torch_angle_deg` va de **5° (arbalète) à 60° (pompe)**. Le pompe n'éblouissait
  que dans la moitié de sa flaque ; l'arbalète éblouissait 25° au-delà de son
  trait de lumière.
- **Aucune portée.** Le rayon était infini : on éblouissait d'un bout à l'autre
  de la carte, très au-delà du dernier photon (une torche porte de 256 à 896 px
  selon `torch_scale`).
- **Le flash de tir n'éblouissait pas du tout** : la chose la plus lumineuse du
  jeu ne coûtait rien à celui qui la déclenche.

**Corollaire de rangement.** `torch_angle_deg` est un **demi**-angle
(`get_torch_texture` allume les pixels dont l'écart à l'axe lui est inférieur).
Le même faux ami avait frappé deux fois : après l'éblouissement, le semis de
poussière de V5.5, qui le prenait pour un angle plein et le redivisait par deux
— la poussière dansait dans un cône deux fois trop étroit, et le pompe en
semait dans un tiers de sa flaque. **Corrigé le 2026-08-18 sur demande
d'Adrien.** La leçon n'est pas la ligne, c'est le nom : un nombre dont l'unité
se devine se trompera une troisième fois. `WeaponData.demi_angle_torche()` et
`cos_demi_cone()` sont désormais les deux seules lectures autorisées.

### Une suite qui pend bloque tout le lanceur (2026-08-18)

`run_suites.sh` n'avait **aucun plafond de temps**. Un appelant cassé a empêché
`test_netcode.gd` de compiler ; la scène a tourné **sans script**, sans jamais
sortir, et le lanceur a attendu **dix minutes** avant qu'on aille voir.

C'est la forme la plus coûteuse du piège déjà connu — un fichier qui ne compile
pas fait **pendre** le processus au lieu de le faire échouer. Une suite rouge
crie ; une suite qui pend ne dit rien **et** bloque tout ce qui suit.

Remède : chien de garde par suite (`PLAFOND_SUITE`, 120 s ; macOS n'a pas
`timeout`), et le code 137 est rapporté comme « n'est pas sorti », avec les
`Parse Error` de la sortie — qui nomment la vraie cause.

**Corollaire pour toute signature modifiée :** `grep -rn "nom_de_la_fonction("`
avant de commiter. Le compilateur ne prévient pas ici, il se tait et pend.


### `get_frames_per_second()` ne bouge qu'une fois par seconde (2026-08-18)

Le banc l'échantillonnait à chaque image. Quinze secondes de mesure donnaient
donc **quinze valeurs distinctes recopiées ~139 fois** : 2082 échantillons
affichés, quinze mesures réelles.

Fatal pour le seul chiffre qui compte. Le « 1 % bas » est censé capter ce que le
joueur ressent comme saccade — le comportement des images les plus lentes.
Calculé sur des moyennes d'une seconde, **il ne peut rien en dire** : une seconde
à 150 fps contenant une image à 20 ms se lit comme une seconde à 150 fps.

**La signature du défaut est `1 % bas == minimum`** — un percentile sur des
doublons est un minimum. Le relevé du 2026-08-18 rendait 109 pour les deux, et
son verdict « 120 fps NON TENU » ne prouvait rien.

Remède : échantillonner `get_process_delta_time()` **par image**, et rendre le
1 % bas comme la cadence moyenne du centième d'images le plus lent — une moyenne
sur la tranche, pas sa borne, pour qu'un pic isolé ne décide pas seul quand vingt
saccades le doivent.

**Ce qui se généralise :** avant de conclure d'un agrégat, vérifier combien de
mesures indépendantes il contient. Un tableau long n'est pas un échantillon
large.


### Un outil de mesure hors couverture se périme en silence (2026-08-18)

`tools/bench_framerate.gd` pilotait `_ui.btn_mode_local`, disparu à la Phase 5
quand les modes sont devenus des entrées du hub. Le banc s'ouvrait, levait une
erreur de script, **n'entrait jamais dans le duel et restait ouvert sans rien
mesurer** — il a fallu le tuer à la main. Découvert à la minute exacte où le
chiffre était demandé, après que trois sessions se soient arrêtées pour lui.

La cause n'est pas la ligne. **Le banc ouvre une fenêtre, donc il ne peut être
dans aucune suite headless**, et rien ne surveillait sa péremption. Remède :
`bench_framerate.preconditions_manquantes()` nomme ses appuis sur le jeu, le banc
les vérifie avant de mesurer et **sort en échec s'il en manque**, et
`tools/test_banc.gd` les contrôle en headless — sans rien rasteriser. Le banc
aurait échoué le jour de la refonte, pas une semaine plus tard.

**Ce qui se généralise :** tout outil qu'aucune suite ne peut exécuter doit au
moins exposer ses hypothèses sous une forme qu'une suite peut vérifier.

### Un `preload` en tête de fichier compile avant les autoloads (2026-08-18)

Troisième forme du même piège dans la journée. Une suite `--script` qui
`preload` un fichier nommant `NetworkManager` (ou tout autre autoload) le compile
**au chargement du script de test**, avant que les autoloads existent. L'échec ne
s'arrête pas au fichier fautif : il se propage à tout ce qui en dépend, si bien
que `main.tscn` arrive **sans ses scripts** et que la suite conclut « tout a
disparu ». Utiliser `load()` après la première frame.

Les deux autres formes : charger `game_state.gd` (« tous les tests passent » sur
des appels morts) et poser des propriétés au vol sur un `Node2D` avec `set()`.


### La torche de l'adversaire s'entendait dans votre musique (2026-08-18)

`AudioManager.set_player_torch()` était appelé pour **chaque** joueur, adversaire
répliqué compris. En ligne, quand l'autre allumait sa torche à l'autre bout de la
carte, hors de vue, le passe-bas du bus musical **local** s'ouvrait de 150 Hz.

Tout le jeu repose sur le fait qu'allumer sa torche est un aveu, payé de sa
position. Le bus musical le donnait gratuitement, sans qu'on ait à regarder — une
fuite par un canal que personne ne surveille, et qu'aucun test ne couvrait.
Trouvée en préparant V5.2, c'est-à-dire **au moment précis où on s'apprêtait à
l'amplifier**.

Le remède est une règle nommée et pure, `AudioManager.torche_comptee(player_id,
local_idx)` : en écran partagé (`local_idx == -1`) les deux torches comptent — même
écran, même sortie audio, rien à cacher ; en ligne, seulement la sienne.

**Ce que ça généralise :** tout ce qui réagit à l'état d'un joueur doit se demander
de QUI il tient cet état. Le son, la vibration et l'image sont trois canaux, et
seul le troisième se vérifie à l'œil.


### Une suite en `--script` ne doit pas charger `game_state.gd` (2026-08-18)

Il référence `NetworkManager` et `AudioManager` **par leur nom d'autoload** ; en
mode `--script` ces noms ne résolvent pas et le fichier ne compile pas. Une suite
qui le `preload` voit alors chacun de ses appels échouer — et **l'erreur avorte
la fonction de test sans incrémenter le compteur** : la suite annonce « tous les
tests passent » sur des appels morts. Rencontré pour de vrai en écrivant V3.9.

Seul le contrôle `grep -c 'SCRIPT ERROR'` de `run_suites.sh` l'attrape ; c'est
exactement ce pour quoi il existe. **Le remède est de ne pas dépendre de
l'orchestrateur** : ce qui est de la comptabilité pure (`serie_de_session.gd`)
vit dans son propre fichier, sans dépendance, et se teste à froid.

### Le tempo du jeu est recopié à trois endroits (2026-08-18)

170 BPM pilote les stems, le pouls haptique (V1.5) et la vignette battante
(V4.7) — mais chacun l'écrivait chez lui. `AudioManager.BPM` /
`AudioManager.PERIODE_BEAT` existent maintenant et servent la respiration V3.1 ;
**`player.gd` porte encore ses propres 170 et 85 en dur** (signalé, pas corrigé :
hors périmètre). Un tempo recopié est un tempo qui dérive — le jour où il change,
ce qui bat encore à l'ancien ne se signale pas, il se contente d'être à côté.


### Trois intentions sur un bouton, trois propriétés (2026-08-18)

Les entrées du hub sont peintes par plusieurs effets à la fois, et chacun croit
posséder son canal. À ce jour : **`scale`** porte la respiration de l'entrée qui
relance (V3.1), **`self_modulate`** porte l'éclat de déclaration (V3.2), et
**`modulate`** porte deux choses à lui seul — le grisage d'une entrée
indisponible (`ui.gd`, « PRÊT » à 0,45 quand il manque un joueur) et l'allumage
échelonné de l'encre coulée (M6).

Le défaut réel qui en est sorti : **l'encre rendait 1,0 à tout le monde en fin de
coulée**, donc rallumait à plein une entrée grisée qui restait `disabled` — un
contrôle qui a l'air disponible et ne répond pas, c'est-à-dire exactement ce que
le contrat « grisées, jamais masquées » veut éviter. Intermittent en prime :
selon qu'un rafraîchissement du bloc salon repassait après la coulée ou non.

**La règle : un effet qui emprunte une propriété partagée rend la valeur qu'il a
trouvée, jamais une valeur choisie d'avance.** Capturer à l'entrée, restituer à
la sortie. Un effet qui a besoin d'un canal à lui doit d'abord vérifier lesquels
sont pris — les trois cités le sont.

### Le banc de framerate est cassé depuis la refonte des menus (2026-08-18)

`tools/bench_framerate.gd:45` lit `_ui.btn_mode_local`, **qui n'existe plus** :
les boutons de mode sont devenus des entrées du hub à la Phase 5. Le banc
s'ouvre, instancie `main.tscn`, puis lève une erreur de script et **n'entre
jamais dans le duel** — il reste ouvert sans rien mesurer. Constaté en le
lançant pour la première fois depuis la refonte.

Ce que ça dit du banc lui-même : **il n'est dans aucune suite** (il ouvre une
fenêtre, il ne peut pas y être), donc rien ne signale qu'il a cessé de
fonctionner. Un outil de mesure hors couverture se périme en silence, et on ne
s'en aperçoit qu'au moment où l'on a besoin de la mesure — c'est-à-dire au pire
moment. À réparer avant tout relevé.

Vu au passage dans la même sortie : `play_music` lève trois erreurs Vorbis
(`packet_sequence.is_null()`), les fichiers de musique n'étant pas encore
fournis. Sans rapport, et attendu. — **Levé le 2026-08-24** : les flux réels
sont en place (V1.1), ces trois erreurs n'ont plus lieu d'être.

### Un banc qui attend des IMAGES mesure la machine, pas le code (2026-08-18)

En headless la cadence n'est pas plafonnée : quarante `process_frame` valent une
demi-seconde sur un poste calme et quarante millisecondes juste après vingt
autres lancements. `test_vitrine_menus` a passé **au vert seule et au rouge dans
le lot** pour cette seule raison, ce qui coûte cher à diagnostiquer puisque la
suite accusée se disculpe dès qu'on la relance — et que la consigne de
cohabitation dit justement de la relancer seule avant de conclure.

Attendre une **condition**, avec un budget en millisecondes
(`Time.get_ticks_msec()`), jamais un compte d'images. Même famille que le tampon
de killcam dimensionné en images, plus bas : dès qu'une durée compte, la compter
en images est faux.

### Le libellé d'une entrée de menu n'est pas dans `Button.text` (2026-08-18)

`MenuHub.make_entry()` pose le libellé dans un `Label` **enfant**, à côté du
chevron ; `Button.text` reste vide sur toutes les entrées du hub. Un audit qui
nomme les entrées fautives par `btn.text` échoue correctement mais ne dit sur
quoi : le message liste des chaînes vides. Passer par
`_entry_details[btn]["titre"]`, qui porte le libellé réel.


**Mise en page**
- **Un `Control` nu rend une taille minimale NULLE, même plein d'enfants.** Un
  composant écrit comme `extends Control` avec un conteneur à l'intérieur ne
  remonte rien à son parent : dans une rangée horizontale, le voisin s'installe
  **par-dessus**. Vu à l'écran le 2026-08-18 — le bouton COPIER posé sur le code
  de salon qu'il devait accompagner, et sur les deux rangées à la fois. La
  parade est `_get_minimum_size()`, qui rend la mesure combinée du conteneur
  intérieur, plus `update_minimum_size()` quand le contenu change. Aucun test
  headless ne l'aurait montré tant qu'on ne mesurait pas : `test_vitrine_menus`
  vérifie désormais que le bloc réserve sa place.

**Rendu à deux vues**
- **Le défaut par défaut : `visibility_layer` vaut 1, et les deux vues le
  laissent passer.** `main.tscn` donne `canvas_cull_mask = 3` à la première vue
  et `= 5` à la seconde ; toutes deux incluent le bit 1. Un `CanvasItem` créé
  dynamiquement sans `visibility_layer` explicite s'affiche donc **sur les deux
  écrans**, en local comme en ligne. Les visuels du joueur posent bien 2 ou 4
  (`player.gd:221-231`) — tout ce qui est ajouté à la volée doit le faire aussi.
  Trouvé le 2026-08-17 sur le flash de mort, qui éblouissait le survivant
  600 ms après son propre kill.

**Signaux**
- **`_set_state` n'émet rien quand l'état ne change pas — et c'est un piège dès
  qu'autre chose change avec lui.** Un rattachement réussi passe par
  `_adopt()`, qui appelle `_set_state(READY)` sur une identité **déjà** READY :
  aucun `state_changed`, alors que le pseudo ET le code de récupération viennent
  d'être remplacés. Un écran branché sur ce seul signal affiche indéfiniment le
  code d'un profil que la machine a abandonné — le code étant précisément la
  seule chose que le joueur doive conserver. D'où `profile_changed`, émis
  inconditionnellement. Règle générale : un signal d'état ne remplace pas un
  signal de contenu.

**Arbres de travail**
- **`main` ne peut être déployé que dans un seul arbre à la fois**, et un arbre
  oublié bloque toute avance rapide de la branche : `git branch -f main` répond
  `cannot force update the branch 'main' checked out at …`. C'est arrivé le
  2026-08-17 avec un arbre d'échafaudage laissé par une session antérieure. Le
  contournement est de fusionner **depuis l'arbre où la branche est déployée** ;
  la vraie correction est de retirer l'arbre inutile. Un `git worktree list` avant
  de s'étonner fait gagner un quart d'heure.
- **Un worktree neuf n'a pas les fichiers ignorés par git** — `eos_credentials.gd`
  et `supabase_config.gd` en particulier. Une suite qui passe en worktree peut donc
  échouer dans l'arbre principal, et l'inverse : EOS y démarre. C'est exactement ce
  qui a caché le segfault d'extinction des deux suites d'appariement.

**Artefacts et documents hors dépôt**
- **Deux sessions peuvent publier le même artefact et se marcher dessus.** Arrivé
  le 2026-08-17 : la publication a rendu un conflit parce qu'une autre session
  avait republié entre-temps. **Ne jamais forcer** — `force: true` jette
  purement et simplement le travail de l'autre. La marche à suivre est de relire
  la version en ligne, d'y fusionner ses propres modifications, et de republier.
  Le conflit est une chance : sans lui, l'écrasement serait silencieux.
- **Republier sans passer l'URL crée un artefact distinct.** Adrien se retrouve
  alors avec deux tableaux qui se contredisent sans savoir lequel croire. L'URL
  est inscrite dans le README, `CLAUDE.md` et le journal des sessions.

**Postgres et PostgREST**
- **Changer la liste de paramètres d'une fonction crée une SURCHARGE, pas un
  remplacement.** `create or replace` ne remplace que la fonction de *même*
  signature : l'ancienne reste appelable, et PostgREST choisit d'après les clés du
  corps de requête. Il faut `drop function` puis `create`.
- **Un `pgsql-parser` valide la syntaxe SQL, pas les corps plpgsql.** Démontré le
  2026-08-17 : un `end if;` retiré passe pour valide chez `pgsql-parser` et n'est
  rejeté que par `parsePlPgSQL`. Les deux, donc, tant qu'il n'y a pas de base
  locale.
- **Un déploiement Supabase n'est pas atomique** : entre `db push` et
  `functions deploy`, l'ancien code appelle la nouvelle base. Tout paramètre
  ajouté à une fonction doit donc venir **en dernier, avec un défaut**, et ce
  défaut doit être le choix sûr — celui qui fait au pire manquer une donnée
  plutôt qu'en inventer une.

**Navigation du hub**
- **`MenuHub.push()` refuse un identifiant inconnu en silence** — il rend `false`
  et personne ne le regarde. Une entrée qui pointe vers un écran mal orthographié
  ne fait donc *rien*, sans erreur ni message. Relevé le 2026-08-17 par l'écran de
  recherche, qui verrouille son identifiant par un test contre la constante de
  `ui.gd` plutôt que de le recopier.
- **Un écran attaché n'est pas un écran atteignable.** `_attach_screen()` le
  déclare au hub et `add_back_entry()` lui donne sa sortie : rien de tout cela ne
  crée le chemin qui y mène. Un écran peut donc être complet, testé, et
  inaccessible — c'est l'état de l'écran de recherche depuis le 2026-08-17, sans
  qu'aucune erreur ne le signale. Chercher le `push`, pas l'attache.
- **~~`_install_aside()` crie cinq fois à chaque construction du menu~~ — corrigé
  le 2026-08-18.** Un seul nœud `salon` était installé pour six écrans (voulu,
  étape 3b), mais la fonction appelait `add_child()` à chaque fois sur un hôte
  unique : premier appel parente, cinq suivants « already has a parent ». Sans
  conséquence fonctionnelle. Disparu avec `register_panel()`, gardé par clé —
  un panneau, un enregistrement, N écrans qui le désignent. **Ce qu'il faut en
  retenir** : le 2026-08-18, deux sessions se sont mutuellement attribué ce bruit
  avant que l'une vérifie qu'il était dans `main` depuis le début. Comparer avec
  `git show HEAD:<fichier>` coûte dix secondes et évite de corriger le travail
  d'un autre.
- **Le panneau de droite n'était pas dans le champ de navigation.** Relevé le
  2026-08-18 : `_nav_candidates()` ne ramassait que `hub.body_of(...)`, la colonne
  de gauche. Tout ce qui vivait à droite — **le choix d'arme, le champ où l'on
  tape le code du salon** — se cliquait à la souris et restait hors d'atteinte des
  deux curseurs. Le hub est en deux colonnes ; le champ de navigation doit l'être
  aussi.
- **Les deux curseurs ne déclenchent pas `focus_entered`.** Ils sont maison : ils
  dessinent un liseré et n'appellent jamais `grab_focus()`. Tout ce qui est branché
  sur `focus_entered` ne réagit donc **qu'à la souris** — c'était le cas du panneau
  de droite et de la description sous le titre. Le piège est silencieux et ne se
  voit pas en développant, où l'on a une souris sous la main. Passer par
  `MenuHub.reveal_entry()`, appelé depuis `_set_focus()`.

**Godot — API multijoueur**
- **`multiplayer != null` n'est jamais faux sur un nœud de l'arbre**, et ce n'est
  donc pas une garde. `get_peers()` sans pair assigné fait crier Godot — « No
  multiplayer peer is assigned » — et le message part **par paires** à chaque
  retour au menu, noyant tout ce qui compte dans le journal d'un essai à deux
  fenêtres. La garde utile est `has_multiplayer_peer()`. Relevé le 2026-08-18 sur
  une trace d'Adrien, dans deux fonctions écrites la veille : `_refresh_player_list`
  et `_close_lobby_if_left`. **Un bruit d'erreur constant coûte autant qu'un
  défaut** — il apprend à ne plus lire les erreurs.

**Cartes et géométrie**
- **Une carte joueur d'Adrien porte le même identifiant que l'arène livrée**
  (`00000001`). Le catalogue contient donc deux entrées de même `id`, et
  `get_map()` rend **la première trouvée** — les cartes livrées étant scannées en
  premier, l'arène standard masque la sienne. Relevé le 2026-08-18, **non
  corrigé** : c'est une donnée sur le disque d'Adrien, pas un défaut de code, et
  la corriger demande de décider quoi faire du fichier existant. L'identifiant
  vient du **contenu** du fichier, pas de son nom — d'où la collision possible,
  là où le slug est réservé par construction.
- **Une variable typée `Dictionary` qui reçoit du JSON venu d'ailleurs jette au
  lieu de refuser.** `MapCodec.validate()` et `get_grid_size()` lisaient
  `grid_size` ainsi : un code où cette clé porte autre chose provoquait une
  erreur de script *à l'intérieur* de la fonction chargée de rendre un refus
  propre, l'appelant recevant `null` puis lisant `["ok"]` dessus. Le typage strict
  est un contrat entre nous, pas avec une entrée non fiable — **vérifier le type
  avant de lire, sur toute donnée qui a traversé un JSON.**
- **~~Un échec d'adoption de la carte de l'hôte n'empêche pas la manche de
  démarrer~~ — corrigé le 2026-08-18 (étape 8.8).** `rpc_start_round` affiche un message puis appelle `_do_start_round`
  quoi qu'il arrive : les deux joueurs jouent sur des géométries différentes,
  chaque machine restant cohérente avec elle-même. Aucun plantage, aucune erreur,
  et deux joueurs persuadés que l'autre triche. Le cas **certain** d'arriver était
  la différence de `MapCodec.VERSION` entre deux builds. La manche refuse
  désormais de commencer. **Ce qu'il faut en retenir** : devant une donnée reçue
  qu'on ne sait pas lire, continuer coûte toujours plus cher que s'arrêter — et
  une divergence de simulation ne se signale par aucune erreur.
- **Une absence n'est pas « rien à faire ».** La garde `if map_code != ""` faisait
  sauter l'adoption en silence : le client entrait dans la manche sur sa carte
  précédente, sans même le message d'erreur. Un champ vide voulait dire « je ne
  sais pas sur quoi je joue ».

**Croisement de deux changements justes**
- **Deux corrections valides peuvent se combiner en un défaut, et le commentaire
  du code est alors le seul témoin.** Le 2026-08-18 : `_on_peer_connected` faisait
  quitter le menu à l'hôte dès l'arrivée du client, parce qu'à l'écriture
  `rpc_client_weapon` lançait la manche dans la foulée — le commentaire le disait
  explicitement. La porte PRÊT, écrite ensuite et à juste titre, a retiré ce
  lancement. **Résultat : l'hôte se retrouvait dans l'arène sans manche démarrée**,
  et comme il simule les deux joueurs et porte le chrono, **les deux fenêtres se
  figeaient** — clavier et souris morts, aucun message d'erreur.
  Ni l'un ni l'autre changement n'était fautif seul. **Ce qui aurait dû alerter :
  la seconde correction invalidait une hypothèse écrite noir sur blanc dans le
  commentaire de la première.** Devant une fonction dont le commentaire dit
  « X s'en charge juste après », vérifier que X s'en charge toujours.
  Trouvé par Adrien en jeu. ⚠️ **La première rédaction de ce piège disait que les
  bancs n'empruntaient jamais ce chemin — c'est faux.** Le banc à deux instances
  le couvre depuis `1d84580` : il fait arriver le client pendant que l'hôte attend
  dans son salon, puis presse PRÊT. Il n'a rien attrapé parce que **personne ne
  l'a lancé entre le changement et le défaut** — il est hors du lanceur, pour des
  raisons qui restent bonnes (deux processus, une session Epic).
  La leçon exacte est donc : **un banc qui couvre un chemin ne protège que s'il
  tourne à chaque changement de ce chemin.** Un banc manuel est une couverture
  conditionnelle, pas une couverture.

**Menus à deux écrans**
- **~~La liste des joueurs est écrite du point de vue de l'hôte~~ — corrigé le
  2026-08-18.** Le client y voyait « L'hôte » puis « Adversaire — connecté »,
  deux lignes pour la même personne — l'hôte étant son unique pair — et **ne s'y
  voyait jamais**. Une liste de joueurs où l'on ne figure pas laisse douter d'être
  connecté à quoi que ce soit, ce qu'elle devait précisément lever. Elle se lit
  désormais depuis la place de celui qui la regarde ; l'ordre, lui, reste celui du
  salon et non celui des personnes présentes.
- **~~Quitter un salon ne le fermait pas~~ — corrigé le 2026-08-18.** Le retour
  ne faisait que remonter d'un cran : `current_mode` restait « hôte », donc le
  bouton affichait « SALON OUVERT » grisé et **plus aucun autre salon ne pouvait
  s'ouvrir**, tandis que l'en-tête gardait le score d'un match terminé. Deux
  symptômes sans rapport apparent, une seule cause. Le retour d'un salon passe
  maintenant par `main_menu_requested`, donc par le démontage complet de
  `game_state` — archivage d'un abandon s'il y a lieu, salon EOS relâché, menu
  remis à plat.

**Ce que le banc affirme et ce que l'humain voit**
- **Un banc vert et un joueur bloqué peuvent décrire le même code.** Le
  2026-08-18, le banc à deux instances affirmait « aucune manche n'a démarré à la
  connexion » pendant qu'Adrien voyait son client **téléporté dans l'arène** dès la
  jointure. Les deux disaient vrai : le banc interroge `round_active`, qui restait
  faux, quand le joueur constate « je ne suis plus dans le menu ». Le client
  quittait bien le menu sans qu'aucune manche ne démarre — d'où une arène figée,
  chrono à l'arrêt, et un bouton PRÊT resté derrière lui.
  **Un contrôle doit interroger ce que le joueur perçoit**, pas l'état interne le
  plus proche. Ici : `ui._is_main_menu`, et non `round_active`.
- **~~`PRÊT` n'est pas grisé quand l'hôte est seul sur le chemin LAN~~ — c'était
  le banc, pas le jeu.** Corrigé le 2026-08-18 (`90dc148`). L'interface était
  juste : les entrées étaient bien grisées, mais **invisibles**, le hub étant
  resté à l'accueil. Deux défauts de banc derrière : son aide de test rendait
  `false` faute de trouver l'entrée — ce qui se lit exactement comme « le bouton
  est cliquable » — et le pilotage partait d'un écran que `show_main_menu()` avait
  entre-temps remis à l'accueil.
  **Ce que mon A/B pouvait établir et ce qu'il ne pouvait pas.** Lancer la même
  commande avant et après un changement prouve « le code que je viens d'écrire
  n'en est pas la cause ». Il **ne distingue pas** « défaut du jeu » de « défaut du
  banc » — les deux sont également préexistants. J'en ai pourtant conclu à un
  défaut du jeu, et je l'ai écrit ici. **Un contrôle qui échoue en accusant un code
  qui n'a pas changé doit d'abord être suspecté lui-même.**
- **Une attente asynchrone dans un banc masque les défauts de synchronisation de
  ce qu'elle attend.** C'est ce qui explique que seul le LAN voyait le défaut
  ci-dessus : l'attente de session EOS — jusqu'à trente secondes — laissait le
  temps à la remise à zéro du menu de passer avant les contrôles, là où le LAN
  n'attend rien. **Le chemin le plus rapide est le plus révélateur, et c'est en
  général celui qu'on teste le moins.**

**Fin de match en ligne**
- **`await RenderingServer.frame_post_draw` n'est JAMAIS émis en `--headless`.**
  Ce signal suit le *dessin* d'une image ; sans rendu, la coroutine reste
  suspendue pour toujours. Trouvé le 2026-08-18 sur la première attente de la
  séquence de fin, et **tout en découlait** : `_end_sequence_active` collé à vrai,
  `game_over` jamais posé, `stop_recording()` jamais atteint, l'enregistrement qui
  continue sans fin, l'impact qui glisse jusqu'en tête de tampon, la killcam qui
  se rejoue en boucle. Le correctif `_impact_seen` traitait donc l'aval d'un
  symptôme.
  **Ce qui rend le piège coûteux : le défaut est invisible en jeu** — une fenêtre
  dessine — et ne se voit que dans un banc headless. Règle : une attente de
  rendu (`frame_post_draw`, `frame_pre_draw`) n'a de sens que là où il y a un
  rendu ; ailleurs, `process_frame`. L'attente d'origine reste bonne en jeu :
  `process_frame` précède le rendu, et geler là fige l'image *d'avant* l'impact —
  balle en vol, victime debout.
- **Cacher un conteneur ne rend pas ses enfants `visible == false`.** Seul
  `is_visible_in_tree()` le dit. Un contrôle écrit sur `enfant.visible` continue
  donc de passer — ou d'échouer — pour une raison qui n'a rien à voir avec ce
  qu'il prétend vérifier. Relevé le 2026-08-18 : `join_input` enveloppé dans un
  `join_box` a rendu rouge une assertion du banc alors que le champ était bel et
  bien invisible.
- **~~Le cycle de fin de match n'est couvert par aucune suite~~ — fermé le
  2026-08-18.** C'est ce trou qui a laissé passer deux défauts en deux jours. Le
  mode `--local` de `test_online_match` va désormais jusqu'à `game_over` et entre
  au lanceur sous le nom `test_fin_de_match` : une seule instance, aucun réseau,
  aucune session Epic. Les modes `--host`/`--join` du même banc restent dehors —
  deux processus coordonnés, ce que `run_suites.sh` ne sait pas faire ; **à lancer
  à la main** avant de toucher au réseau, protocole dans
  `docs/PROTOCOLE_TEST_EOS.md`.
- **Une commodité non demandée a coûté une régression visible à chaque fin de
  match.** `_close_lobby_if_left()` fermait le salon en quittant l'écran : je
  l'avais ajoutée de moi-même, elle n'était pas au périmètre. `show_game_over()`
  appelle `hub.reset()`, qui émet `screen_changed("accueil")` **avant** le
  `push()` — l'hôte coupait donc sa propre connexion, et les deux joueurs se
  voyaient mutuellement déconnectés. Livrée avec dix-neuf suites vertes, sur le
  chemin exact qu'Adrien testait. Corrigée le 2026-08-18 (`ec2eac1`). Deux leçons :
  **ce qui n'est pas demandé se signale au lieu de s'écrire**, et une suite verte
  ne dit rien d'un chemin qu'aucune suite ne parcourt.
- **La killcam se rejoue en boucle en headless** — `impact_frame` collée au
  plafond du tampon, donc `_end_sequence_active` ne retombe jamais et l'écran de
  fin ne se pose pas. C'est ce qui garde `test_online_match` au rouge sur ses deux
  derniers contrôles. **En jeu fenêtré l'écran de fin s'affiche normalement**
  (vérifié par Adrien) : cela ressemble à un artefact de headless, ce n'est pas
  établi. Relevé le 2026-08-18, non corrigé.

**Entrées et touches**
- **Échap n'a pas un rôle mais quatre**, selon le contexte : ne pas quitter à
  l'accueil, remonter d'un cran en profondeur, ouvrir la pause en match, la
  refermer. C'est ce qui a fait traîner sa vérification deux jours — **un essai
  unique n'en couvre qu'un, et le résultat paraît alors inconcluant plutôt
  qu'incomplet.** Un relevé geste par geste, en tableau, tranche en trente
  secondes ce qu'un essai global laisse en suspens.
- **F3 est lu comme touche physique, hors Input Map, et macOS le capte avant le
  jeu** (Mission Control). `fn + F3` est la parade. Corollaire qui explique trois
  tentatives pilotées ratées : **une frappe synthétique atteint un champ de texte
  par le chemin unicode, jamais une action de l'Input Map par le chemin
  `keycode`.** Ce contrôle-là ne s'automatise pas.

**Outils et instrumentation**
- **Un `class_name` tout neuf n'existe pas encore pour `--script`.** Le registre
  des classes globales vit dans `.godot/global_script_class_cache.cfg`, qui est
  **ignoré par git** — il se reconstruit à l'ouverture du projet dans l'éditeur,
  pas au lancement headless. Un fichier créé hors éditeur donne donc
  « Identifier "X" not declared in the current scope » dans toutes les suites,
  alors que le fichier est parfait. Relevé le 2026-08-18 en créant `protocol.gd` ;
  `--headless --quit` ne suffit pas, il faut `--headless --editor --quit-after N`.
  Corollaire pour un clone neuf : **passer l'éditeur une fois avant
  `run_suites.sh`**, sans quoi tout ce qui porte un `class_name` semble absent.
- **`--check-only --script` ment sur les fichiers qui référencent un autoload.**
  Vérifier `ranked_identity.gd` ainsi rend « Identifier not found: NetworkManager »
  alors que le fichier est bon : en mode `--script`, les autoloads ne sont pas
  dans la portée. Même famille que ci-dessus — **le contrôle rapide échoue
  précisément sur les fichiers qui comptent le plus**, ceux qui touchent au
  réseau et à l'identité. Passer par une suite qui instancie ce qu'il faut.
- **Un remplacement de sous-chaîne qui mange un niveau d'indentation rend un
  script non compilable — et Godot désigne alors le mauvais fichier.** Relevé le
  2026-08-18 : `game_state.gd` corrompu par une substitution sur
  `"\t_round_token += 1"` a fait rendre par Godot un `ui` **sans script** — nœud
  nu, `CanvasLayer` de base — et l'erreur affichée parlait d'une méthode manquante
  sur `ui`, pas d'une erreur de syntaxe dans `game_state.gd`. **Le message désigne
  le fichier qui appelle, pas celui qui ne compile pas.** Devant un « méthode
  inexistante » sur un nœud qui devrait en avoir une, chercher d'abord un script
  qui n'a pas compilé.

**GDScript — noms**
- **`trait` est un mot réservé.** `var trait := ColorRect.new()` donne « Expected
  variable name after "var" », qui ne nomme pas le coupable.
- **Une locale nommée `visible` masque le membre de `Control`** et fait échouer
  l'analyse. Même famille : un nom innocent qui entre en collision avec le langage
  ou la classe de base.
- Les deux se présentent comme le piège d'outillage ci-dessus : **Godot annonce
  l'erreur sur le fichier qui appelle, pas sur celui qui ne compile pas.** Relevé
  le 2026-08-18 — `test_screen_matchmaking` est passée au rouge en annonçant
  « SCREEN_FRIENDLY introuvable » alors que le fautif était un fichier neuf qu'elle
  ne mentionne nulle part. Deux causes différentes, un seul symptôme : devant une
  erreur qui n'a aucun sens dans le fichier désigné, chercher un script voisin qui
  vient de changer.

**GDScript — chaînes**
- **`\u0000` dans un littéral GDScript ne donne pas un NUL** : l'analyseur le
  remplace par U+FFFD, qui n'est pas un caractère de contrôle. Recopier mot pour
  mot le cas de test serveur (`sanitizeNickname("Va\u0000da")`) fait donc échouer
  une fonction pourtant correcte. Relevé le 2026-08-18 en écrivant le miroir de
  `recovery_code_test.ts` ; `\u0001` passe par la même branche et s'écrit, lui.

**Tests headless**
- **Un banc dont la réussite consiste à disparaître doit le dire avant de
  disparaître.** `test_quit_path` réussit en se faisant arrêter par le code qu'il
  vérifie : il n'imprimait donc aucun verdict, et une réussite ressemblait trait
  pour trait à un banc qui n'aurait rien exécuté. Adrien l'a lancé le 2026-08-18
  sans pouvoir conclure. Corrigé par un `_exit_tree()` — le dernier endroit où
  l'on parle encore. **Règle générale : un garde-fou muet en cas de succès ne se
  distingue pas d'un garde-fou absent**, et c'est vrai des bancs comme des
  contrôles en jeu (voir la ligne de la poignée de main, même journée).
- **Un lot de suites lancé pendant qu'une autre session écrit ne prouve rien —
  ni en vert, ni en rouge.** Le 2026-08-18, `test_pause_menu` est sortie en échec
  (code 1) parce qu'elle a attrapé `ui.gd` en cours d'écriture ; relancée seule
  dans la foulée, 44 assertions et code 0. **Rien dans la sortie ne dit que la
  cause est extérieure au test.** Devant un rouge sur une suite qui touche un
  fichier qu'une autre session édite : la relancer seule avant de chercher la
  cause dans son propre code.
  **Pire que « peu fiable » : éditer `run_suites.sh` pendant qu'il tourne le
  corrompt en vol.** Bash relit le script depuis le disque au fil de l'exécution ;
  décaler les octets le fait reprendre au milieu d'un mot. Relevé le 2026-08-18 —
  un lot a rendu `line 53: _match.tscn: command not found`, morceau de
  `res://tools/test_online_match.tscn` coupé en deux, alors que la ligne était
  parfaite. **L'erreur nomme un fichier de test qui n'a aucun rapport** : encore
  la même famille que le reste de ces deux jours, le message qui désigne à côté.
  Ne pas modifier le lanceur pendant qu'il s'exécute — et devant un
  « command not found » qui ressemble à un bout de chemin, soupçonner cela avant
  de chercher une faute de frappe.
  **`test_protocole` y est particulièrement exposé** : il lit le fil dans des
  fichiers qu'une autre session peut être en train d'écrire, et rougit alors sur
  du travail en cours plutôt que sur un vrai changement de protocole. Devant son
  rouge : le relancer seul avant de toucher à `Protocol.VERSION`.

**Documents et messages de commit**
- **La CI accuse le commit qu'elle a testé, pas celui qui a cassé.** Quand
  plusieurs commits arrivent entre deux exécutions, le premier rouge désigne un
  innocent. Le 2026-08-18, `ce2aabe` — **86 lignes de `docs/ROADMAP.md` et rien
  d'autre** — a été signalé comme responsable d'une régression d'interface. Le
  vrai coupable était `1d84580`, deux commits plus tôt, qui avait enveloppé
  `join_input` dans un `join_box` sans que l'assertion du banc suive. Le
  signalement demandait de corriger « en priorité » un trunk déjà réparé depuis
  quatre commits (`d0902cc`).
  **La vérification coûte trois secondes : `git show --stat <commit>`.** Un commit
  qui ne touche pas le code en cause ne peut pas en être la cause. Et avant de
  corriger un rouge rapporté, **rejouer la commande sur `HEAD`** : elle passait.
- **C'est la troisième fois en trois jours que le récit désigne la mauvaise
  chose.** Un message de commit affirmant un travail non fait ; une feuille de
  route recopiant cette affirmation ; une CI accusant un commit de documentation.
  Le point commun n'est pas la négligence, c'est que **le récit et le code sont
  deux artefacts distincts qui dérivent l'un de l'autre sans jamais se
  contredire à voix haute**. La seule parade qui marche est mécanique : lire le
  diff, pas le titre.
- **Un message de commit peut affirmer un travail qui n'a pas été fait, et la
  feuille de route le recopie ensuite.** `05b72c7` annonce « les deux entrées
  ne sont plus grisées » ; il n'a jamais touché ces entrées. L'affirmation a
  vécu une journée dans les deux documents, et elle aurait coûté une séance de
  test à deux fenêtres préparée pour rien. **Vérifier le code, pas le récit** —
  `git log -S "<la chaîne concernée>"` dit en une seconde quel commit a
  réellement touché quoi.
- **Le même écart s'est produit quatre fois en deux jours**, toujours dans le
  même sens : une intention rédigée au passé, jamais posée dans le code. Les
  entrées « chercher un match » annoncées ouvertes ; le transport annoncé posé par
  la navigation ; les « cartes tirées au hasard » de l'arborescence, qu'aucune
  fonction ne savait tirer ; et deux points de blocage listés comme restants alors
  qu'ils étaient réglés. **Écrire une décision et l'implémenter sont deux gestes**,
  et ce document ne distingue pas les deux à la lecture. Un futur lot gagnerait à
  marquer explicitement ce qui est *décidé* et ce qui est *fait*.
- **`git commit` emporte tout l'index, pas seulement les fichiers qu'on vient
  d'ajouter — et l'index est partagé entre sessions.** Arrivé le 2026-08-18 :
  `49a7b40` s'intitule « La nature du match, lisible par qui l'archive » et
  contient `ranked_identity.gd` **plus** 29 lignes de `replay_system.gd` qu'une
  autre session avait indexées sans avoir encore commité. Rien n'est perdu, mais
  le message ne décrit pas la moitié de son contenu : qui cherchera pourquoi
  `impact_frame` porte un drapeau `_impact_seen` tombera sur un commit qui parle
  d'archivage.
  **Aggravant, et c'est le vrai enseignement :** le `git diff --cached --stat`
  affichait bien `replay_system.gd | 29 ++++`. La ligne a été *regardée* sans être
  *lue*. Un contrôle qu'on exécute par habitude ne protège de rien. La parade sûre
  est `git commit -- <chemins>`, qui ne commite que ce qu'on nomme, quoi qu'il y
  ait dans l'index. **Elle ne connaît cependant que les fichiers suivis** : sur un
  fichier neuf elle refuse (« pathspec did not match »), il faut `git add` d'abord
  puis nommer la liste complète au commit.
  ⚠️ **Et elle ne protège que des fichiers, pas des lignes.** `git commit -- <chemin>`
  commite l'état de l'**arbre de travail** pour ce chemin — donc *aussi* les
  modifications non commitées d'une autre session dans le même fichier. C'est
  arrivé **trois fois** le 2026-08-18 (`49a7b40`, `c01530d`, `2dcd37f`), chaque
  fois en reprenant brièvement un fichier tenu par quelqu'un d'autre. Rien n'a été
  perdu, mais trois commits portent du travail que leur message ne décrit pas.
  **La seule parade réelle en arbre partagé : `git diff <chemin>` avant de
  commiter, et le lire.** Prendre un fichier tenu par une autre session sans
  regarder ce qu'il contient déjà revient à signer son travail.
- ⚠️ **Le miroir du piège ci-dessus : c'est VOTRE fichier qui part avec le
  commit d'un autre — et la règle « ROADMAP dans le même commit » y survit
  mal.** Arrivé le 2026-08-25 : la justification de DA2.4 était écrite dans
  `docs/ROADMAP.md` et attendait que la suite passe ; pendant ces vingt minutes,
  `318e6ef` — une session audio, qui parle de caméras et de `cam1 à Nil` — a
  emporté le fichier entier. Quand `19b4f20` a enfin commité le code de la
  marche, **il n'y avait plus rien à commiter dans la ROADMAP** : `git add` a
  réussi sans un mot, et le commit est parti à trois fichiers au lieu de quatre.
  Rien n'est perdu et rien n'est en conflit — mais qui lira `19b4f20` pour
  comprendre *pourquoi* la marche n'est pas peinte ne trouvera pas la réponse
  dedans, et le commit qui la porte parle d'autre chose.
  **Ce que ça change en pratique :** la parade documentée plus haut protège
  celui qui commite, pas celui qui écrit. Le seul contrôle qui l'attrape est
  `git show --stat` **sur son propre commit, juste après** — la ROADMAP y manque,
  ou elle n'y manque pas. Et le remède n'est **jamais** de réécrire l'historique
  d'une branche que quatre sessions partagent : on rétablit le lien en nommant
  le commit dans l'entrée, ce que fait DA2.4 ci-dessus.
  **Corollaire, et il vaut au-delà de git :** plus une rédaction attend dans
  l'arbre de travail, plus elle est exposée. Écrire la ROADMAP *après* que la
  suite est verte, et non pendant, réduit la fenêtre de vingt minutes à une.
  ⚠️ **Le paragraphe que vous lisez a été emporté à son tour**, sept minutes
  après avoir été écrit, par `317ab03` — une session qui parle de percuteurs.
  Ce n'est pas une coïncidence amusante, c'est la mesure du phénomène : sur cet
  arbre, aux heures pleines, **tout texte laissé non commité a quelques minutes
  d'espérance de vie**, pas vingt. La seule rédaction qui vous appartienne est
  celle que vous commitez dans le même appel que son écriture.
- **Un `git add` groupé qui trébuche sur un fichier absent n'indexe RIEN**, et le
  commit qui suit part avec son message complet et son contenu amputé. Arrivé le
  2026-08-18 sur l'étape 8.8 : `6783d56` porte tout le récit et n'emporte que le
  fichier de test, le `.uid` listé n'ayant pas encore été régénéré par Godot. La
  parade est mécanique et coûte deux secondes — **`git show --stat` avant de
  pousser.** Le message n'est pas une preuve de ce qui est dedans, et c'est la
  variante *involontaire* du piège ci-dessus.
- **Le protocole de test suppose un alias `godot` qui n'existe pas sur le poste
  d'Adrien.** Toutes les commandes de `docs/PROTOCOLE_TEST_EOS.md` commençaient
  par `godot` ; il a eu `command not found` en copiant-collant. L'alias est
  désormais posé en tête du document, avec le piège du chemin du dépôt — il
  contient deux espaces, et un `cd` sans guillemets échoue en silence.

**Godot — réflexion**
- **`has_method()` posé sur un `GDScript` ne rend que les méthodes STATIQUES.**
  Un contrôle préalable qui vérifie une API sur le script annonce donc des
  méthodes manquantes qui existent toutes. Les méthodes d'instance se cherchent
  sur une instance.

**Godot — physique**
- **`move_and_slide()` repousse hors d'un chevauchement même à vélocité
  nulle — c'est ce qui faisait « traîner » P2 quand P1 restait collé contre
  lui.** Godot exécute une passe de récupération de pénétration au tout début
  de `move_and_slide()`, y compris quand la vélocité demandée est nulle. Deux
  `CharacterBody2D` sur le même layer qui se frôlent en continu (P1 poussant
  contre P2 immobile) voient donc P2 repoussé hors du chevauchement à chaque
  frame, sans qu'aucun code de jeu ne le déplace — c'est cette passe de
  récupération, appelée par P2 lui-même, qui bouge P2. Correctif :
  `player.gd` n'appelle plus `move_and_slide()` quand la vélocité est nulle
  (lignes 453-456 et 474-476). La forme de collision reste active dans
  l'espace physique indépendamment de l'appel, donc un joueur immobile
  continue de bloquer l'autre sans se faire pousser lui-même.

**Tests headless**
- **Un script lancé avec `--script` ne peut pas toucher à EOS.** Les autoloads du
  plugin EOSG (`HLobbies`, `HP2P`, `HAuth`…) ne sont pas encore enregistrés quand
  `network_manager.gd` se compile : `Identifier not found: HLobbies`, et tout ce
  qui en dépend s'effondre. Toute vérification contre le vrai service doit passer
  par une **scène** — c'est pourquoi `test_transport`, `test_online_match` et
  `test_quit_path` sont des `.tscn` et non des scripts. Relevé le 2026-08-17 en
  essayant de sonder le filtre de fourchette.
- **Une `SCRIPT ERROR` n'échoue PAS une suite — et ça s'est produit deux fois.**
  Seul un `_check` incrémente le compteur : une suite qui appelle une fonction
  supprimée continue d'annoncer « tous les tests passent » avec le code 0. Le
  2026-08-17, `test_pause_menu` a passé au vert en appelant `_visible_tabs()`,
  disparue avec la barre d'onglets — trois erreurs de script au journal, sortie 0.
  **Le garde-fou est `tools/run_suites.sh`**, qui grepe la sortie et échoue sur
  toute erreur de script : c'est le seul contrôle qui ne dépende pas de la
  vigilance de l'auteur du test. En second rideau, une suite vérifie en préalable
  que chaque symbole qu'elle touchera existe.
- **Tout nombre relu d'un JSON revient en flottant.** Un `vainqueur` écrit `0`
  vaut `0.0` à la relecture. Un contrôle `typeof(x) == TYPE_INT` écarte donc
  **tous** les enregistrements venus du disque, tout en passant sur ceux
  fraîchement construits en mémoire — le test qui l'attrape est celui qui passe
  vraiment par `JSON.stringify` puis `parse_string`, jamais celui qui construit
  son dictionnaire à la main.
- **Un worktree neuf n'a pas de `.godot/`** : `ProjectSettings.get_global_class_list()`
  y rend zéro entrée et aucun `class_name` ne résout. `--headless --import` est
  obligatoire avant la première suite. Dans la suite elle-même,
  `preload("res://…")` est plus sûr que le `class_name`, puisqu'il ne dépend pas
  du cache.
- **Un worktree neuf n'a pas la disposition audio du projet.** Sans un
  `--headless --import` préalable, l'uid de `default_bus_layout.tres` ne résout
  pas : seul le bus `Master` existe, `Music`, `SFX` et `Speaker` sont
  introuvables. Toute suite touchant à l'audio échoue alors pour cette seule
  raison, et le message ne le dit pas.
- **`AudioServer` est un état global qui survit d'une fonction de test à
  l'autre.** Un contrôle « régler la musique ne touche pas aux effets » qui
  compare à une valeur absolue passe ou échoue selon ce qu'un test antérieur a
  laissé. Comparer un avant/après, jamais une constante.
- **Les suites headless partagent le `user://` du jeu installé.** Un test qui
  appelle un setter réécrit les vraies préférences du joueur. Prévoir un point de
  dérivation du chemin (`var _settings_path := SETTINGS_PATH` plutôt que la
  constante en dur) et vérifier en fin de parcours que le fichier réel est intact.
- **Un test qui instancie une scène ne peut pas charger celle-ci depuis `_init`.**
  Les autoloads ne sont pas encore enregistrés à ce moment : `ui.gd`, qui
  référence `MapData`, échoue à la compilation. Godot rend alors un nœud **nu**,
  sans script — et chaque appel part en `SCRIPT ERROR` sans jamais incrémenter le
  compteur d'échecs. Le premier jet de `test_pause_menu.gd` a ainsi annoncé
  « ✓ Tous les tests passent » en n'ayant rien exécuté du tout. Deux parades, les
  deux nécessaires : charger la scène après `await process_frame`, et **vérifier
  que le script est bien attaché** (`has_method(...)`) avant le premier contrôle.
  Corollaire général : une erreur de script n'échoue pas un test — seul un
  `_check` le fait. Un harnais doit donc contrôler ses propres hypothèses.
- Dans un script `extends SceneTree`, `paused` appartient à l'arbre lui-même, pas
  à `root` — qui est la `Window`. `root.paused` échoue silencieusement de la même
  façon.

**EOS**
- Ne JAMAIS appeler `delete_device_id()` ni `HAuth.login_anonymous_async()` : il
  détruit et recrée l'identité à chaque appel, donc un PUID différent à chaque
  lancement.
- **Arrêt propre obligatoire** : `EOSGRuntime.set_process(false)` → `await
  get_tree().process_frame` → `release()` → `shutdown()` → `quit()`. Sans
  l'attente d'une frame, on ré-entre dans `EOS_Platform_Tick()` depuis sa propre
  pile → segfault.
- ID de socket P2P : alphanumérique uniquement, ≤ 32 caractères.
- Une recherche de salon **infructueuse** coûte ~3,1 s (une recherche qui trouve
  répond en ~200 ms).
- `LOBBY_MEMBERS` peut être incomplet juste après `join_async` : attendre le
  signal `lobby_updated`.
- Le `MultiplayerSynchronizer` n'est **pas** promu en `reliable` (mesuré
  390/390 en `UNRELIABLE`). Le plugin ne promeut que `unreliable_ordered`, que
  Godot n'utilise pas ici. Sujet clos.

**Outillage**
- **Homebrew est inutilisable sur cette machine.** `brew install` échoue sur
  « Your Command Line Tools are too outdated » : Homebrew 6 sur macOS 26 exige
  des CLT 26.3, celles installées sont en 16.4. Les remettre à niveau coûte
  ~2 Go et un mot de passe administrateur. Quand un outil existe en binaire
  autonome, le prendre directement plutôt que de payer ce détour — c'est ce qui
  a été fait pour la CLI Supabase (voir [SUPABASE.md](SUPABASE.md)).

**Tests à deux instances locales**
- **Deux instances `--eos-ephemeral` lancées coup sur coup se marchent dessus.**
  La seconde échoue sur `create_device_id — DuplicateNotAllowed` et repart sans
  identité Epic. Les espacer, ou basculer sur le transport ENet (`RÉSEAU LOCAL`,
  IP `127.0.0.1`), qui teste les mêmes chemins sans dépendre d'Epic.
- **Les deux instances partagent le même `user://`**, donc le même
  `match_history.json`. Sans conséquence entre deux machines, mais en local les
  deux journaux n'en font qu'un : ne pas y lire un « chaque camp a bien archivé
  le sien ».
- Le focus clavier reste sur la dernière fenêtre touchée. Un test piloté qui
  envoie Échap ou F3 les adresse à cette fenêtre-là, pas à celle qu'on regarde.

**Supabase / vérification de jeton**
- **`startsWith` ne valide pas un émetteur.** Le contrôle « l'émetteur commence
  par `https://api.epicgames.dev` », écrit littéralement, accepte
  `https://api.epicgames.dev.attaquant.test` — un tout autre domaine. Il faut
  exiger la base exacte OU une barre oblique juste après. Le défaut a été écrit
  puis attrapé par son propre test le 2026-08-16 ; il n'était pas exploitable
  (la signature est vérifiée avant), mais le même raisonnement appliqué ailleurs
  le serait.
- **Un composite `NULL` rendu par une fonction SQL n'arrive pas en `null`.**
  PostgREST le sérialise en OBJET DE CHAMPS NULS — `{"id":null,…}` — qu'un
  appelant prend pour une ligne valide. C'est ce qui a fait accepter un code de
  récupération inventé, en production, le 2026-08-16. Une fonction qui doit
  pouvoir ne rien rendre se déclare `returns setof` : zéro ligne devient `[]`.
- Ne pas se fier à l'en-tête `Accept: application/vnd.pgrst.object+json` pour
  distinguer « aucune ligne » : selon la version, PostgREST rend l'objet seul ou
  un tableau d'une entrée, et répond 406 sur zéro ligne. Le code accepte les
  trois formes.
- Le plugin EOS rend le jeton dans un sous-dictionnaire :
  `{result_code, id_token: {product_user_id, json_web_token}}`. Vérifié en
  exécution le 2026-08-16, jeton de 943 caractères.

**Export macOS**
- `textures/vram_compression/import_etc2_astc=true` est obligatoire dans
  `project.godot`, sinon l'export refuse de démarrer.
- `await get_tree().process_frame` reprend AVANT le rendu de la frame
  courante (le signal part en début de phase process) : pour figer ou capturer
  une image qui doit CONTENIR ce que la frame dessine, attendre
  `RenderingServer.frame_post_draw`. Payé une fois sur le gel du kill (V2.1),
  qui figeait la frame d'avant l'impact.
- Ne pas utiliser `custom_template` : installer les modèles d'exportation depuis
  le gestionnaire intégré de Godot (un téléchargement manuel corrompu avait fait
  croire à un bug de l'éditeur).
- Les entitlements réseau ne servent que sous App Sandbox (Mac App Store). En
  distribution directe, EOS ouvre ses sockets sans entitlement.

---

**Mise à jour du jeu installé**
- **Le bundle macOS ne s'appelle pas comme l'exécutable.** Godot le nomme d'après
  `config/name` : c'est « Candela 2D.app », avec l'espace, alors que l'export
  Windows produit `Candela.exe` dans un dossier `Candela`. Le manifeste annonce
  cette racine et le jeu la vérifie **avant** de remplacer quoi que ce soit — une
  racine annoncée à tort ne se découvrirait qu'après la fermeture du jeu, au seul
  moment où plus rien ne peut le dire. Relevé sur un export réel le 2026-08-24.
- **Le paquet macOS est universel, l'annoncer « x86_64 » le condamne.** Godot
  exporte un binaire x86_64 + arm64 ; un manifeste qui déclare une architecture
  ferait refuser le paquet par tous les Mac Apple Silicon, avec pour seul symptôme
  « aucun paquet ne correspond à cette machine ». Architecture vide = convient
  partout, et c'est ce que `fabrique_manifeste.sh` écrit pour macOS.
- **`ZIPReader` ne restitue ni le bit d'exécution ni les liens symboliques.** Un
  `.app` reconstruit avec lui ne se lance pas, et l'erreur ne ressemble en rien à
  sa cause. La décompression passe donc par `ditto` (macOS) et `tar` (Windows),
  jamais par l'API de Godot.
- **Un correctif `.pck` doit être monté avant le premier autoload.** Godot les
  instancie dans l'ordre de `project.godot` ; un correctif qui remplace
  `network_manager.gd` et qui arrive après n'a plus rien à recouvrir, sans erreur
  et sans trace. D'où `PatchLoader` en tête de liste. Corollaire : **un correctif
  ne peut ni ajouter un autoload, ni changer le moteur, ni l'addon EOS** (une
  GDExtension charge sa bibliothèque native au démarrage depuis `res://`), ni
  toucher à `project.godot`.
- **`%` est un caractère actif dans un `.bat`, `'` dans un script `sh`.** Le
  script d'échange refuse de se produire si un chemin en contient un, plutôt que
  de sortir un script mal cité qui effacerait autre chose que ce qu'il croit.
- **`JSON.stringify` n'écrit pas d'espace après les deux-points.** Une suite qui
  fabrique ses variantes par `replace('"format": 1', …)` ne remplace rien, ne dit
  rien, et reste verte sans avoir exercé quoi que ce soit — six contrôles de
  `test_mise_a_jour.gd` sont passés au vert pour cette seule raison avant que la
  fabrique ne soit refaite en dictionnaires. Le mode de défaillance exact que ce
  dépôt traque partout ailleurs.
- **`"a" + "b" % x` applique le format au seul dernier littéral.** En GDScript le
  `%` lie plus fort que le `+` : un message d'erreur construit sur deux lignes et
  formaté à la fin lève une erreur d'exécution au lieu d'afficher la raison — et
  c'est précisément dans le chemin d'erreur, celui qu'on teste le moins.
- **Lancer plusieurs instances de Godot en parallèle fait échouer des suites
  saines.** `test_pause_menu` et `test_screen_matchmaking` sont sorties en échec
  pendant qu'un export tournait à côté ; seules, elles passent. Avant de
  diagnostiquer une régression, vérifier qu'aucune autre instance ne tourne.

### Un MP3 ne sait pas rendre une boucle sur la grille (2026-08-24)

Adrien a livré la musique en `.mp3`. Le format ne code que des trames de **1152
échantillons** et n'accepte aucune longueur intermédiaire : les onze fichiers
arrivent donc arrondis à la trame, avec **1152 échantillons de silence exact en
tête** (le retard d'encodeur, mesuré identique sur les onze) et une queue
tronquée d'environ 48 ms. Déposés tels quels, ils sonnent juste **au premier
tour** — et le défaut n'apparaît qu'au second, quand la boucle revient un
quinzième de temps trop tôt.

Ce qui le rend traître : les quatre couches du clip « match » dérivent
**ensemble**, puisqu'elles portent le même décalage. Rien ne se désynchronise
entre elles, rien ne sonne faux ; c'est la musique entière qui glisse contre les
transitions `fade_beats` du flux interactif. On n'a donc aucun symptôme local à
suivre.

Le remède est à l'import, pas au mixage : rogner les 1152 échantillons de tête,
compléter la queue jusqu'au compte exact de temps (64 temps à 170 BPM =
1 084 235 échantillons), puis encoder en Vorbis. `tools/test_musique.gd` vérifie
désormais que chaque flux dure un nombre **entier** de temps — c'est le seul
contrôle qui aurait attrapé la chose sans oreille.

**Et le poste n'avait pas d'encodeur Ogg** : le `ffmpeg` de Homebrew est
construit sans `libvorbis`. `brew install vorbis-tools` fournit `oggenc`. Sans
lui, la seule voie sans transcodage aurait été de garder les `.mp3`, ce qui
obligeait à modifier `audio_manager.gd` et `asset_manifest.gd` — deux fichiers
tenus par d'autres sessions, pour un format qui aurait ramené le même défaut de
boucle.

### `play()` démarre au clip initial, pas au clip demandé (2026-08-24)

Question d'Adrien, en une ligne : « est-ce que l'intro se lance au démarrage du
jeu ? » Réponse mesurée : **elle se lançait, et elle était tuée un tiers de
seconde plus tard.**

`GameState._ready()` appelait `AudioManager.play_music("music_menu")`, et
`play_music` fait deux choses à la suite : `music_player.play()`, puis
`switch_to_clip_by_name("menu")`. Or **`play()` démarre un
`AudioStreamInteractive` à son `initial_clip`** — le clip 0, c'est-à-dire
l'intro. Elle partait donc pour de vrai, et la bascule demandée dans la même
image la coupait au prochain temps, par le repli ANY→ANY
(`from_time = NEXT_BEAT`, fondu de 0,5 temps). Cinq secondes et demie de musique
écrites, jouées 0,35 s.

Rien n'était en panne, et c'est tout le problème : le clip portait déjà son
`auto_advance` vers le menu, la ressource était juste, le code était juste. La
seule pièce fausse était **une croyance** — que `play()` démarre là où on lui
dit. Il démarre là où la ressource lui dit.

Ce qui le rend indétectable sans y penser : le symptôme est une intro *presque*
inaudible, pas une intro absente. Un silence se remarque ; un tiers de seconde
de musique au lancement passe pour un artefact de démarrage.

Corrigé en trois pièces, et il en fallait trois : une transition **explicite**
intro→menu (`from_time = END`, `to_time = START`, sans fondu) pour que
l'enchaînement parte de la fin et non du prochain temps ; une fonction
`AudioManager.demarrer_musique_au_lancement()` qui **ne demande rien** — elle
démarre, et laisse le clip initial vivre ; et l'appel correspondant au
lancement. Les retours au menu continuent de passer par `play_music`, qui trouve
le lecteur en marche et se contente de basculer : **l'intro ne revient pas.**
C'est le choix d'Adrien — au dixième retour au menu d'une soirée, cinq secondes
d'attente cessent d'être une entrée en matière.

Un piège d'énumération dans le même geste, attrapé par le test et pas par la
relecture : **`TRANSITION_TO_TIME_START` vaut 1, pas 0.** Le 0 est
`SAME_POSITION`. Écrire `to_time: 0` en croyant dire « au début » fait repartir
le menu à une position arbitraire — et ça s'entend une fois sur deux, ce qui est
la pire fréquence pour un défaut.

### Le jeu jouait des sons positionnels sans aucune oreille (2026-08-25)

Relevé par la session « spatialisation du son », vérifié et corrigé ici. **Le
défaut avait l'âge du projet** : `AudioStreamPlayer2D` partout, panoramique
partout, et **aucun auditeur**.

Trois pièces manquaient, et la cruauté du défaut tient à ce qu'**aucune ne
s'entend seule** :

1. Le pool d'`AudioStreamPlayer2D` est enfant de l'autoload `AudioManager`, donc
   dans le `World2D` de la **racine**. Le jeu vit dans celui du `SubViewport`. Un
   `AudioStreamPlayer2D` ne s'adresse qu'aux viewports de son propre monde.
2. **Un `SubViewport` n'est pas une oreille par défaut** —
   `audio_listener_enable_2d` vaut `false` ; seule la fenêtre racine l'a à
   `true`. Mesuré, pas déduit.
3. Aucun `AudioListener2D` n'existait nulle part dans `main.tscn`.

Poser un `AudioListener2D` sur le joueur **sans déménager le pool ne change rien
du tout** — et on chercherait l'erreur dans le listener pendant des heures. C'est
le piège qui compte ici : la pièce qu'on pense être la solution est celle qui ne
sert à rien seule.

Ce que le joueur entendait à la place : Godot posait l'oreille au centre de
l'écran virtuel, à un point fixe. **Le panoramique disait où le son était sur la
carte, pas par rapport à soi.** Avancer vers l'adversaire ne rendait pas ses pas
plus forts. Rien n'était en erreur, tout était audible.

**Corrigé en ligne uniquement** (`AudioManager.oreille_suit`, décision d'Adrien
du 2026-08-25). En écran partagé on n'y touche pas, et c'est la même raison que
`torche_comptee` : les deux joueurs écoutent les mêmes haut-parleurs, donc suivre
l'un donnerait à l'autre ses propres pas entendus depuis une tête qui n'est pas
la sienne. Ce serait **pire** que le point fixe, pas mieux.

`tools/test_oreille.gd` monte un vrai arbre de jeu et vérifie les trois pièces —
y compris, à dessein, que l'état d'origine était bien le défaut décrit. Ce qu'il
ne prouve pas, et qui se juge au casque : que le panoramique s'entend.

### La famille de défauts de cette nuit : la sortie plausible (2026-08-25)

Quatre défauts en une nuit, tous de la même espèce, et il vaut mieux les nommer
ensemble qu'un par un :

| Ce qu'on croyait | Ce qui était vrai |
|---|---|
| Les flux musicaux étaient « vides » | Ils portaient un timbre audible à −19 dBFS |
| Le manifeste inventoriait les sons d'armes | Huit entrées décrivaient des fichiers qui n'existeraient jamais |
| Le jeu spatialisait ses sons | Il n'avait aucune oreille depuis toujours |
| L'intro musicale ne se lançait pas | Elle se lançait et mourait en 0,35 s |

**Aucun n'a jamais levé la moindre erreur. Aucun n'a jamais fait rougir un
test.** À chaque fois le système produisait une sortie *plausible* : du son, un
compteur, un panoramique, un démarrage. C'est le mode de défaillance contre
lequel ce dépôt se bat le plus mal, parce que sa signature est l'absence de
signature.

Ce qui les a tous attrapés, sans exception : **mesurer la sortie plutôt que lire
le code.** Décoder un `.ogg` pour vérifier qu'il contient du silence, comparer
`get_world_2d()` de deux nœuds, sonder la valeur par défaut d'une propriété
plutôt que la supposer. Le corollaire pratique : quand un système audio ou visuel
« marche mais bizarrement », la question n'est pas *où est le bug* — c'est *qu'
est-ce que je crois savoir sans l'avoir mesuré*.

### Un dossier qui n'a jamais existé, et personne pour le dire (2026-08-25)

`AudioManager.SOUNDS` pointait les quatre voix d'annonceur vers
`res://assets/audio/speaker/`. **Ce dossier n'a jamais été créé.** Les chemins
ont donc rendu `null` en silence pendant des mois — `get_audio_stream` ne lève
rien sur une ressource absente, c'est la règle « câbler, taire, diagnostiquer ».

Ce qui rend le cas intéressant, c'est que le manifeste **le savait** : ses
entrées `spk_*` étaient marquées absentes, et le panneau F3 les comptait. La
détection a fonctionné. Ce qui manquait, c'est que personne ne rapproche
« absent » de « et le chemin lui-même est faux » — on lisait l'absence comme
« Adrien n'a pas encore produit les voix », pas comme « le chemin ne mène nulle
part ». Les deux se ressemblent dans un compteur.

Quand les fichiers sont arrivés, ils sont allés dans `voice/`. Le nom `speaker`
survivait parce que c'est celui du **bus**, qui est une sortie et non un
rangement. Les deux ne se confondent plus : `DIR_VOIX` pour les fichiers, bus
`Speaker` pour la sortie.

### Le percuteur à vide portait toute la carte (2026-08-25, attrapé avant l'écoute)

Deux pièges d'un coup, et aucun des deux ne se serait entendu comme un défaut.

**Le premier : un clic à vide passait pour un coup de feu.** Les fichiers
`weapon_dry_*` vivent dans `assets/audio/weapons/`, et `est_un_tir()` reconnaît
un tir **à son préfixe de chemin**. Un joueur martelant une détente vide aurait
donc fait reculer les pas de son adversaire de six décibels (V4.15) — l'inverse
exact de ce que ce son raconte, qui est « je ne tire pas ». Rien n'aurait levé
d'erreur : le clic se serait entendu, les pas auraient juste été un peu plus
bas, et personne n'aurait relié les deux.

**Le second : sans ligne dans `PORTEE_RELATIVE`, le percuteur prenait le
défaut** — 1,0 × la diagonale de la carte, à 0 dB. Un clic mécanique se serait
entendu d'un bout à l'autre de l'arène, aussi loin qu'un tir. Signalé par la
session « spatialisation du son » avant même que le son ne soit joué une fois.

Il a désormais sa ligne : **0,55 de portée, −9 dB**. Plus qu'un pas, bien moins
qu'un impact de mur. C'est un choix de conception, pas un réglage : un clic à
vide est l'aveu le plus cher du jeu après la torche — « je suis désarmé, et je
suis là ». À portée courte il ne trahit que celui qui est déjà assez près pour
vous trouver ; à portée longue il deviendrait une annonce.

### La séance de dosage du 2026-08-26 : Adrien aplatit les portées

Deuxième séance au banc, et elle renverse une intention de conception — pas un
réglage. Les valeurs sont dans `AudioManager`, avec leur date.

| Son | Portée avant | Portée après | Niveau |
|---|---|---|---|
| pas | 0,15 | **0,60** | −13 dB |
| coup au but | 1,35 | **0,60** | −2 dB |
| percuteur | 0,55 | **0,65** | −9 dB |
| impact mur | 1,20 | **0,80** | −3 dB |
| tir | 1,60 | **0,85** | 0 dB |

**L'écart des portées passe de 1-à-10,7 à 1-à-1,4.** Presque tout s'entend
presque partout ; ce qui distingue les sons n'est plus leur portée mais leur
niveau, qui s'étale de −13 à 0 dB. C'est la même position que la courbe à 0,40
de la veille, poussée jusqu'au bout : **dans le noir, entendre que l'autre
existe vaut plus que savoir à quelle distance il est.**

**La décision la plus forte de la séance, et elle est arrivée en dernier :
« le bruit d'impact ne doit pas porter au-delà des pas ».** Le coup au but est
le seul son que le banc n'exposait pas ; il était resté à 1,35 pendant que tout
le reste descendait, et il aurait porté **2406 px quand le tir qui le cause en
portait 1515** — le bruit de l'impact aurait trahi 60 % plus loin que le coup de
feu.

La règle posée dépasse la correction d'échelle : **être touché ne doit pas
trahir plus que marcher.** Le coup au but reste le deuxième son le plus fort du
jeu (−2 dB) mais devient intime — il confirme au tireur qu'il a touché, sans
annoncer à la carte entière où se passe le duel. Fort et court, au lieu de fort
et loin.

**Ce que j'avais faux, et pourquoi.** J'avais posé le percuteur à 0,55 en
raisonnant « un peu plus de la moitié de la référence ». Le nombre avait l'air
modeste ; multiplié par le facteur global de **1,80** qu'Adrien avait réglé la
veille, il donnait 0,99 — **exactement la diagonale de la carte**. Le percuteur
portait d'un bout à l'autre de l'arène, ce que son propre commentaire disait
vouloir empêcher.

La leçon vaut au-delà de ce nombre : **une valeur relative ne se juge pas
seule.** Elle vit dans un produit, et le facteur qui la multiplie a pu être
réglé par quelqu'un d'autre, un autre jour. Le premier écran du banc l'a montré
en une ligne — `portée 980 px (diagonale carte 990 × relative 0,55 × facteur
1,80)` — ce qu'aucune relecture du code n'avait donné, parce que le code ne
montre jamais le produit, seulement ses facteurs.

`tools/test_musique.gd` garde désormais la **forme** de ce jugement, pas ses
valeurs exactes : le coup au but sous le pas en portée et au-dessus en niveau,
les portées en un mouchoir et les niveaux étalés, aucun son ne couvrant plus
d'une diagonale et demie. Un dosage doit pouvoir être repris au banc sans casser
sa propre garde ; ce qui est verrouillé, c'est la décision, pas le chiffre.

### Un fichier livré, présent, et vide (2026-08-26)

`voice/defeat.wav` — la voix qui annonce la défaite — contenait **0,76 s de
silence numérique** : un pic de 1 sur 32768, soit −90 dBFS. Tout joueur qui
perdait un match n'entendait rien. Le fichier était au dépôt depuis la veille,
intégré, inventorié, testé.

**Ce que mes tests vérifiaient, et pourquoi ça ne suffisait pas.** Pour les voix,
`ResourceLoader.exists()` : le fichier est là, la clé résout, le chemin est bon.
Trois vérités qui ne disent **rien du contenu**. Pour les stingers j'avais
pourtant écrit « porte du son » en mesurant la durée — mais une durée non nulle
ne prouve rien non plus, celui-ci durait 0,76 s.

**Et le manifeste ne pouvait pas le voir** : sa détection de bouche-trou compare
une **taille exacte** (160 032 octets). Un silence d'une autre taille passe à
travers — angle mort déjà relevé sur `music_intro.ogg` le 2026-08-24, et qui
vient de coûter une seconde fois.

Trouvé en mesurant la loudness des 45 fichiers pour préparer DA3.9, pas en
cherchant un défaut. **La mesure a trouvé ce que la relecture ne pouvait pas
voir** — troisième fois de la semaine.

**Le garde-fou a failli reproduire le défaut à l'intérieur de lui-même.** Sa
première version lisait les octets de la ressource **importée** ; or Godot
compresse les `.wav` en QOA, elle y trouvait du bruit de compression et
**déclarait vivant un fichier vide**. Elle lit désormais le fichier **source**,
ce qui juge ce qu'Adrien a livré plutôt que ce que l'importeur en a fait — et
c'est le bon niveau : on veut savoir si la livraison est bonne, pas si
l'importeur a bien travaillé.

Cycle complet vérifié : rouge sur le fichier vide, vert sur le réexport.

---

## Chantiers de robustesse — étude du 2026-08-16

Une relecture exhaustive du code (huit sous-systèmes) a relevé une série de
points de vigilance. Les correctifs sûrs et localisés ont été appliqués le jour
même : garde anti-ré-émission sur `rpc_client_weapon` (un client pouvait
réinitialiser une manche en cours), état canonique `local_ready_for_rematch`
(la logique prêt/pas-prêt comparait le **texte** du bouton REJOUER, qu'une
reformulation aurait cassée en silence), bornage des inputs et du ping reçus
(voir Phase 4), écriture atomique et versionnée du journal de matchs,
renommage `p1_kills` → `p1_session_wins` (le compteur compte des **matchs de
session**, pas des éliminations — le nom aurait piégé les stats de la
Phase 4), et une CI GitHub Actions qui déroule les treize suites headless plus un
test de fumée du jeu complet à chaque poussée (validée sur Godot 4.7.1 Linux).

Le reste demande un arbitrage ou un vrai chantier — rien n'est bloquant :

**Netcode**

- ~~**Déduplication des tirs prédits en FIFO aveugle.**~~ **Fait le 2026-08-18**,
  par les deux pistes que l'étude proposait, dans `prediction_tir.gd` (sans
  dépendance, donc testable à froid).
  - **Le TTL suit le RTT mesuré** (2,5×, borné 500-3000 ms) au lieu d'une seconde
    fixe. Une durée de vie constante est fausse des deux côtés : trop courte sur
    un mauvais lien — la prédiction expire avant le retour de la balle et **le
    joueur voit son tir en double**, ce qui est le cas d'un réseau mobile saturé,
    c'est-à-dire exactement celui pour qui la prédiction existe — et trop longue
    sur un bon, où des fantômes traînent.
  - **L'appariement regarde l'angle** : deux tirs rapprochés se confondent
    autrement, l'ordre seul ne les sépare pas.
  - **Contrainte tenue, et elle vaut comme règle : « améliorer le choix ne doit
    pas dégrader le nombre. »** Si aucun angle ne correspond, on retombe sur la
    plus ancienne — comportement d'origine. Un appariement plus fin qui ferait
    apparaître un doublon là où l'ancien n'en faisait pas serait une régression
    invisible ici et visible chez quelqu'un d'autre, sur un lien qu'on n'a pas.
- **Mort simultanée = victoire du premier RPC arrivé** (`_end_sequence_active`
  ignore la seconde mort). Décision de design à prendre : un double kill
  vaut-il égalité ? Aujourd'hui l'égalité n'existe que par chrono écoulé.

**Tests**

- ~~La mécanique centrale du jeu — voir et être vu dans le noir — n'a **aucun
  test automatique**.~~ **Ouvert le 2026-08-16, fermé le 2026-08-18** par
  `tools/test_vision.gd`. Trente suites couvraient le codec, les menus, le
  réseau et le classement ; la seule chose dont dépend l'intérêt du jeu ne
  l'était pas.
  - ⚠️ **Le cône : ROUVERT le 2026-08-24. Ce qui est écrit ci-dessous est vrai
    et passe complètement à côté du défaut.** Texte d'origine conservé, parce
    que c'est lui la leçon :

    > Le `0.866` était écrit en dur, deux fois, sans dire qu'il valait 30° :
    > c'est un **réglage d'équilibre** (un cône plus large rend la torche moins
    > coûteuse à allumer), il porte maintenant un nom et deux tests l'encadrent
    > à 29° et 31°.

    **Le dépôt a regardé cette constante, l'a jugée, l'a baptisée et l'a figée
    par deux tests — sans voir qu'elle applique UN SEUL angle à QUATRE armes
    dont les faisceaux vont de 5° à 60°.** `game_state.gd` appelle
    `Vision.dans_le_cone()` sans jamais lui passer l'arme. En partie, aujourd'hui :
    la **pompe** éclaire 120° et n'éblouit que sur 60 — on est révélé, donc visé,
    sans subir de pénalité ; l'**arbalète** éclaire 10° et éblouit sur 60 — elle
    aveugle des joueurs qu'elle n'illumine pas, alors qu'elle est l'arme furtive.
    Seul le **pistolet** tombait juste, à 30° pile ; l'arbitrage des portées du
    2026-08-24 l'a porté à 35°, si bien que **plus aucune arme ne correspond**.

    **Et le remède documenté n'a pas raté le défaut : il l'a consolidé.** Un
    nombre nu invite à demander d'où il sort. Un nombre nommé, expliqué comme un
    réglage d'équilibre et encadré par deux tests **a l'air décidé** — plus
    personne ne le regarde. `tools/test_vision.gd` vérifie 29° dedans / 31°
    dehors : il fige la constante contre elle-même et restera vert quelles que
    soient les armes.

    **La leçon dépasse ce cas, et elle prolonge celle du contrôle hors sujet :
    une ligne barrée empêche le prochain de regarder.** Une suite verte qui
    mesure autre chose rassure ; une entrée déclarée close fait mieux — elle
    dispense d'aller voir. Rouvrir coûte une ligne, redécouvrir coûte une
    session.

    Retrouvé indépendamment le 2026-08-24 en intégrant DA2.1, et **refermé le
    même jour par la fusion de `claude/joueur-enouillissement-effet-xq3143`.**

    ✅ **Cette fois la fermeture est un fait, pas une affirmation** — et c'est
    toute la différence avec la première. Vérifié après fusion : `0.866` n'est
    plus qu'une **valeur par défaut de paramètre**. Les deux seuls chemins de
    production passent l'angle de l'arme — `game_state._lumiere_recue` via
    `arme.cos_demi_cone()`, `player.gd` via `current_weapon.demi_angle_torche()`
    pour le semis de poussière — et ne retombent sur 30° que faute d'arme. La
    constante a cessé d'être un réglage d'équilibre : c'est un repli.

    Et la pénalité ne recopie plus le faisceau, **elle le lit** :
    `Vision.intensite_texture` échantillonne l'alpha du cookie, qui porte à lui
    seul l'angle, la portée, la luminosité et la matière peinte. Un pixel ne peut
    pas diverger de lui-même.

    ⚠️ **La fusion a immédiatement attrapé un défaut au point de couture**, ce
    qui vaut mieux que n'importe quelle relecture : `_lumiere_recue` passait
    `torch_scale` là où le rendu emploie `echelle_torche()`. Les deux étaient le
    même nombre jusqu'aux cookies 1024², et valent depuis le simple et le double.
    L'éblouissement échantillonnait donc le faisceau **à mi-distance du point
    visé** — trop de pénalité au loin, de la pénalité là où le faisceau est
    éteint, et un jeu parfaitement jouable. Deux lots verts chacun de son côté ;
    c'est leur rencontre qui l'a montré.
  - **L'occlusion** est vérifiée dans un vrai monde physique bâti par
    `MapGeometry` : un mur arrête le faisceau, une **fosse le laisse passer**
    (décision de conception — « on peut éblouir son adversaire par-dessus un
    gouffre ») tout en arrêtant le joueur.
  - Le **contre-test** compte autant que le test : sans « sans mur entre eux, le
    faisceau passe », un masque de collision erroné bloquerait tout, y compris
    le vide, et le premier contrôle passerait quand même.
  - ⚠️ **Cette fiche a menti pendant deux jours.** La suite couvrait le cône et
    l'occlusion, c'est-à-dire les deux seules parties de la mécanique qui
    **fonctionnaient** ; l'éblouissement lui-même, lui, n'a jamais rien fait
    (voir les pièges). Annoncer « la mécanique centrale est couverte » sur cette
    base valait moins que rien. Complétée le 2026-08-18 par
    `tools/test_eblouissement.gd` (le modèle temporel : montée, plafond,
    descente, indépendance à la cadence, flash de tir) et par les contrôles
    d'`intensite_recue` dans `test_vision` (**portée** et **cône réel de
    l'arme**, qui manquaient tous les deux).
  - **Et par un troisième, qui est le seul à couvrir ce qui était cassé** :
    `test_online_match.tscn -- --eblouissement`, dans le lanceur. Le défaut ne
    vivait ni dans le modèle ni dans la géométrie mais **entre les deux** — une
    mécanique dont chaque moitié est verte peut être morte. Il braque une vraie
    torche dans un vrai match en écran partagé et regarde la valeur monter,
    redescendre, rester nulle dans le dos du faisceau, et sauter d'un coup au
    tir. J2 y est replacé **chaque image** devant J1 : en headless la visée de
    J1 retombe sur la souris, qui pointe le coin de l'écran — on suit sa
    direction au lieu de la combattre, et le test ne dépend alors ni de la carte
    ni du hasard du curseur.
  - Reste non couvert : la révélation au tir et l'énergie des lumières — ce sont
    des propriétés du rendu (Light2D, texture), pas de la géométrie, et le
    headless n'en dit rien.
  - **Et par un quatrième, le 2026-08-24 : `tools/planche_eblouissement.tscn`,
    qui REGARDE.** C'est lui qui a fermé le « reste non couvert » ci-dessus, et
    il a trouvé deux défauts qu'aucune assertion écrite d'avance n'aurait pris
    (les deux entrées de « Pièges connus » du jour). Il ouvre une vraie fenêtre,
    joue une vraie manche en écran partagé, et sort 30 images plus un relevé de
    mesures — temps de montée et de descente, pic de flash arme par arme, valeur
    subie à cinq postes du faisceau. Il est dans `tools/run_visuel.sh`, pas dans
    `run_suites.sh` : `--headless` ne rastérise rien et `frame_post_draw` n'y est
    jamais émis.

    **Il n'affirme presque rien, à dessein** — même règle que la planche de
    contact des menus : pas d'image de référence, pas de seuil, rien qui se
    périme. Il ne sort en échec que sur **deux propriétés d'équité** : le voile
    de J2 qui déborderait chez J1 (mesuré : la vue de J1 passe de 0,049 à 0,043
    de luminance quand J2 sature — elle baisse), et un blanc qui survivrait à la
    fin d'une manche. Tout le reste est du jugement, qu'il imprime sans trancher.

    **Trois pièges payés en l'écrivant**, tous consignés en tête du fichier :
    mesurer et photographier doivent être deux passes (une capture coûte 350 ms,
    et le premier jet mesurait sa propre lenteur — il annonçait 0,57 s pour une
    montée qui en prend 0,28) ; faire tirer J1 sur J2 à bout portant **tue le
    sujet** et tout ce qui suit rend zéro sans rien dire, d'où un flash mesuré à
    90° de l'axe, ce qui prouve au passage l'absence de cône ; et macOS cesse
    d'émettre `frame_post_draw` pour une fenêtre au second plan, d'où une reprise
    plutôt qu'un délai fixe.

    **Et il nomme ses appuis, dès le premier jour.** `preconditions_manquantes()`
    liste ce dont il dépend — deux joueurs, trois méthodes de `GameState`, les
    actions `p1_torch`/`p2_torch` de l'Input Map, les constantes du modèle, quatre
    méthodes de `WeaponData` — et `tools/test_banc.gd` les vérifie **en headless,
    sans rien rastériser**. C'est la parade déjà écrite pour `bench_framerate`,
    appliquée avant la panne au lieu d'après : un banc qui ouvre une fenêtre ne
    peut être dans aucune suite, donc rien ne surveille sa péremption, et le pire
    moment pour le découvrir cassé est identifiable d'avance — le jour où il
    faudra rejuger l'éblouissement après le lot des cookies. Le contrôle qui
    compte le plus est le plus bête : si `p1_torch` quittait l'Input Map, la
    torche ne s'allumerait jamais et **tout le relevé rendrait zéro**, c'est-à-dire
    exactement la signature du défaut de 2026-08-18 que cette planche surveille.

    **Deux durcissements payés le jour même, et le second vaut pour les trois
    outils visuels.** (1) Le relevé de cohérence était une **loterie** : la carte
    est tirée au hasard, le point d'apparition tombe où il tombe, et la visée de
    J1 suit la souris — donc une direction fixe mais arbitraire. Deux passages
    consécutifs ont donné l'un un relevé complet, l'autre « MUR » sur les quinze
    postes. La planche cherche désormais à J1 un emplacement dégagé, en anneaux
    concentriques, **en exigeant que le chemin jusque-là soit libre lui aussi** —
    sans quoi on téléporterait le joueur dans la pierre et on mesurerait un
    dégagement parfait vu de l'intérieur d'un mur. (2) Une **erreur d'analyse
    fait tourner la scène SANS script**, donc sans rien mesurer ni écrire, et
    elle sort proprement en **0** : `run_visuel.sh` relit maintenant la sortie de
    chaque outil et cherche `Parse Error`, exactement comme `run_suites.sh` grep
    `SCRIPT ERROR` pour la même raison. Le code de sortie ne suffit jamais à dire
    qu'un outil a travaillé.

### Premier jugement à l'œil de l'éblouissement — 2026-08-24

**La mécanique n'avait jamais été regardée.** Tout avait été écrit et vérifié en
headless, en conteneur distant. Ce relevé est le premier, sur le Mac d'Adrien,
en fenêtre réelle. Ce qu'il a établi, et qui n'était pas su :

| | au départ | + la courbe | + la lecture du pixel |
|---|---|---|---|
| plafond à 80 px dans l'axe (pistolet) | 0,864 | 0,930 | 0,931 |
| pistolet, mi-faisceau (294 px) | 0,500 | 0,707 | 0,706 |
| pistolet, bord du cône (27° sur 30) | 0,209 | 0,458 | 0,460 |
| pistolet, bout de portée (559 px sur 589) | 0,050 | 0,217 | 0,217 |
| **arbalète, plafond à 80 px** | 0,636 | 0,798 | **0,434** |
| **arbalète, dans l'axe (448 px)** | 0,349 | 0,590 | **0,319** |
| arbalète, dans le dos (halo) | 0,000 | 0,000 | 0,000 |
| **hors du cône** | **0,000** | **0,000** | **0,000** |

> ⚠️ **Toutes les valeurs de ce tableau sont des PÉNALITÉS, après la courbe.**
> Le banc, lui, imprime les deux échelles à deux endroits : `--- le plafond réel
> à 80 px ---` donne la lecture **brute** du pixel, la ligne `MONTÉE … plafond
> géométrique` donne l'**après-courbe**. Il y a une racine carrée entre les deux.
> Le 2026-08-24, quatre plafonds ont été transmis à la session voisine en citant
> un mot de chaque colonne — l'arbalète y passait pour tomber à 0,188 alors
> qu'elle tombe à 0,434. **Un nombre sans son échelle n'est pas un nombre**, et
> celui-ci aurait fait conclure à une fusion cassée. Les valeurs brutes
> correspondantes sont : pistolet 0,867 · fusil 0,914 · pompe 0,686 ·
> arbalète 0,188.

Les trois armes à `torch_brightness = 1` ne bougent pas d'un millième entre la
deuxième et la troisième colonne — c'est la vérification que l'échantillonnage
est **fidèle** et non un nouveau réglage déguisé. **Seule l'arbalète descend**, et
c'est exactement la correction demandée : sa luminosité de 0,3 ne vivait que dans
l'alpha de la texture, donc la formule ne l'avait jamais vue.

- **Les 80 % d'opacité ne sont jamais atteints en jeu.** La lumière reçue
  plafonne à 0,864 (pistolet), 0,911 (fusil), 0,688 (pompe), 0,636 (arbalète) à
  bout portant *dans l'axe*, faute de quoi le voile plafonnait entre 0,51 et
  0,73. La courbe remonte ces chiffres sans changer le principe.
- **La descente colle au modèle à 8 ms près** : 1,492 s mesurées pour 1,485 s
  promises. **Aucun réglage de temps n'a été touché** — la montée est déjà
  « rapide, quasi immédiate » (90 % du plafond en 0,51 s), et le « 0,8 s pour
  saturer » du commentaire décrivait un cas qui n'existe pas.
- **Le flash tient son intention** : 0,514 pour pistolet, fusil et pompe à
  80 px et 0,294 à 300 px (modèle : 0,520 et 0,300) ; **0,046 pour l'arbalète**,
  dont l'écran d'en face reste noir. L'arme discrète le reste par construction.
- **L'arbalète ne délivre jamais son plein, même en plein axe** : son demi-angle
  de 5° est plus étroit que le fondu d'arête de 7°, donc l'axe est déjà dans le
  fondu. Défendable pour une arme furtive, mais c'est un **accident de formule,
  pas une décision** — à trancher le jour où quelqu'un s'en plaindra.
- **fps inchangés** : médiane 144, 1 % bas 99 au banc duel standard, du même
  ordre que le relevé honnête du 2026-08-18 (97).

**Ce qui n'a PAS pu être jugé, et qu'il ne faut pas croire couvert :**

- **le flash au-delà de 550 px**, et les deux postes les plus lointains du
  faisceau (le bout de portée du pistolet, 559 px, et celui de l'arbalète,
  851 px). Il faut une ligne dégagée de cette longueur, et les cartes n'en
  offrent pas toujours. Le banc le **dit** — « MUR entre les deux, relevé
  sauté » — au lieu de rendre un zéro qu'on prendrait pour une mesure ; c'est la
  seule chose qui compte ici, puisqu'un zéro silencieux est exactement la
  signature du défaut de 2026-08-18 ;
- **le ressenti manette en main.** Les deux joueurs ont été pilotés par script.
  Les temps sont mesurés à la milliseconde ; savoir s'ils *se sentent* justes
  reste à Adrien.

### ⚠️ Dette : tout ceci porte sur l'ANCIEN faisceau

Signalé le 2026-08-24 par la session « assets visuels », pendant ce relevé.
Adrien a arbitré le même jour de nouvelles valeurs de torche — pistolet
30° → 35° et `torch_scale` 2,3 → 1,6, fusil 3,5 → 1,8 — qui vivent pour
l'instant dans `tools/torches.gd` : **`game_state.gd` porte encore les
anciennes.** Le cookie peint passe en outre de 512² à 1024² (portée doublée si
`texture_scale` n'est pas compensé) et sort à 63-72 % de la lumière actuelle.

**Aucun nombre de réglage n'a été touché ici** — montée, descente, pic de flash
et facteur de voile sont intacts.

**Et la dette a beaucoup rétréci le jour même : c'est la lecture du pixel qui l'a
réduite.** Tant que la pénalité recopiait la formule, chaque changement de cône,
de portée ou de matière peinte exigeait un report manuel dans le modèle — donc un
rejugement complet, et une occasion de plus de diverger. En lisant l'alpha de la
texture, **les trois arrivent gratuitement** : le cookie porte son angle, sa
portée et sa perte de lumière dans ses propres pixels. Mesuré sur `bis04` avant
son intégration : dans l'axe il reproduit la formule à 1 % près, et c'est **dans
les flancs qu'il tombe à 0,49-0,73** — exactement ce que la formule n'aurait pas
su voir, et ce pour quoi elle aurait puni.

Ce qui reste dû est donc un **jugement**, non plus un report : rejouer
`./tools/run_visuel.sh --eblouissement` une fois les cookies en jeu, et regarder
si les chiffres se sentent justes. Le banc dira les nombres ; Adrien dira s'ils
conviennent.
- ~~Les transitions d'état en ligne ne sont couvertes que manuellement.~~
  **Automatisé le 2026-08-18** par `tools/run_duo.sh`, dans le lanceur. Deux
  processus headless en ENet sur 127.0.0.1 : aucun identifiant Epic, aucun code
  à se transmettre, l'adresse est connue d'avance. Le banc savait déjà jouer les
  deux rôles ; il lui manquait quelqu'un pour les lancer.
  - **Il a trouvé un défaut à son premier lancement.** `_select_mode` poussait
    `SCREEN_HOST` / `SCREEN_JOIN` — les salons **Internet** — dans les deux cas,
    en comptant sur `btn_transport_lan` pour choisir ENet. Or depuis la refonte,
    **entrer dans un salon écrit lui-même le transport** : le `push` écrasait la
    bascule une frame plus tard, et le chemin LAN repartait sur EOS. Le client se
    faisait refuser par « Connexion à Epic en cours », dans un mode qui n'a rien
    à demander à Epic. **Invisible parce que personne ne lançait le duo en ENet**
    — c'est précisément le trou que ce runner comble.
  - Ce qu'il vérifie, dans l'ordre : que les deux processus **sortent** (un banc
    qui pend est le mode de défaillance déjà rencontré deux fois ce jour-là), en
    0, sans `SCRIPT ERROR`, et **en disant de quel côté** vient l'échec.
  - Attentes **conditionnelles**, jamais des `sleep` : l'hôte annonce son salon
    par `CODE:`, le runner l'attend. Un délai fixe rendrait la couverture
    dépendante de la charge — le défaut qui a coûté une demi-journée le même jour.
  - Coût : ~1 min, plus que toutes les autres suites réunies. C'est le prix d'une
    couverture sur la zone la plus régressive, payé une fois par commit plutôt
    qu'une manche entière à la main.
  - **Famille 3 automatisée le 2026-08-18** (`run_duo.sh --coupure`) :
    l'adversaire **disparaît pendant le 3-2-1**, sans quitter proprement. C'est la
    transition la plus régressive du jeu, et elle ne se vérifiait qu'en fermant
    une fenêtre à la main au bon moment.
    - **Le piège qu'elle protège est nommé dans le code lui-même** : « un départ
      interrompu en plein 3-2-1 laisserait `countdown_left` figé, donc l'hôte
      immobile pour toujours dans son bac à sable ». Un joueur bloqué, sans
      message et sans pouvoir bouger — le pire état atteignable, et le seul
      qu'aucune erreur ne signale.
    - Dix contrôles sur la reprise : décompte effacé, aucune manche en cours,
      bac à sable rendu, score et série remis à zéro, aucun « prêt » survivant,
      et **le joueur 2 qui cesse de courir sur sa dernière commande**, torche
      comprise — une lumière orpheline resterait allumée dans l'arène.
    - Le client **se tue lui-même** (`OS.kill`), et le runner **exige qu'il ne
      sorte PAS en 0** : une sortie propre préviendrait l'hôte par le protocole
      et n'exercerait pas la détection de perte de pair. Un banc qui passerait
      sans avoir coupé serait pire qu'aucun banc.
    - On attend d'être **vraiment dans le décompte** avant de couper : couper
      avant exercerait une autre famille, et le banc croirait couvrir celle-ci.
  - **Famille 1 automatisée le 2026-08-18** (`run_duo.sh --pause`) : **la pause
    en ligne ne gèle rien.** Le contrat est écrit dans `ui.gd` — « en ligne il
    figerait la simulation des deux joueurs, ce panneau se superpose donc à un
    monde qui court » — et le joueur en pause reste **vulnérable**, ce qui
    empêche la pause d'être une invincibilité gratuite.
    - **Deux propriétés opposées, et c'est leur combinaison qui fait la règle :**
      le monde continue **et** celui qui navigue cesse d'agir. Vérifier l'une
      sans l'autre laisserait passer les deux défauts qui comptent — une pause
      qui gèle le match pour les deux, ou un joueur qui court encore pendant
      qu'il lit son menu.
    - Le chrono est mesuré **avant et après** côté hôte : c'est la seule preuve
      que le monde a continué. Et `get_tree().paused` est vérifié **faux** côté
      client, là où le gel serait invisible autrement.
  - **Piège repayé en écrivant ce mode, et il vaut pour tous les bancs à deux
    processus : l'hôte doit sortir en DERNIER.** Sorti le premier, il coupe le
    lien pendant que l'autre mesure encore — et l'assertion tombe non pas parce
    que la propriété est fausse, mais parce que le pair a disparu. Le mode
    nominal le savait déjà ; je ne l'ai pas appliqué au mien.
  - **Famille 2 automatisée le 2026-08-18** (`run_duo.sh --killcam`) : ce que
    l'adversaire fait **pendant votre killcam**. Deux exigences opposées encore :
    son intention est **retenue** pendant le ralenti — rien ne bouge chez vous,
    aucune manche ne démarre seule — et **n'est pas perdue** à la sortie.
    - **Trois gates essayées avant la bonne, et les deux premières mesuraient
      autre chose.** `not round_active` est vrai dès le **début** de la killcam :
      le client pressait pendant son propre ralenti. `not _is_main_menu` est faux
      pendant **tout** le match : l'attente rendait la main avant même la mort.
      Seul `game_over` dit « ma killcam est finie ».
    - **Un diagnostic pris pour une preuve, au passage :** le banc imprime le
      libellé du salon à chaque appui, et cette ligne a été lue comme la preuve
      qu'un chemin de menu avait été emprunté. Elle ne prouvait rien — c'était un
      `print`. Une trace de diagnostic n'est pas un résultat.
    - ⚠️ **Sa seconde moitié a été retirée le 2026-08-18 : elle était instable.**
      Elle vérifiait que l'intention retenue du client est appliquée à la sortie
      du ralenti — elle passait, puis échouait, sur le même code. La cause tient
      à la fenêtre de séquence de fin, courte et **variable** (voir « la killcam
      s'arrête avant le moment fatal » ci-dessus). **Un banc qui vacille est pire
      qu'aucun banc** : il apprend à ignorer le lanceur, et le jour où il dit
      vrai personne ne le croit. Reste la moitié déterministe — rien ne bouge
      pendant le ralenti — qui protège du défaut le plus grave : une manche qui
      démarrerait pendant que l'autre regarde encore.
  - **Famille 5.3 automatisée le 2026-08-18** (`run_duo.sh --ralenti`) :
    l'adversaire disparaît **pendant le ralenti**. C'est le croisement de deux
    chemins que rien n'exerçait ensemble — la perte de pair et la sortie de
    ralenti. Un `time_scale` oublié ne ralentit pas la killcam, il ralentit
    **tout le jeu, menus compris**, et personne ne relierait un curseur qui rampe
    à une déconnexion d'il y a dix secondes.
    - ⚠️ **Limite écrite plutôt que masquée : `Engine.time_scale` reste à 1,000
      pendant six secondes côté hôte en headless**, alors que l'enregistrement
      montre la mort et que le rejeu démarre. Le contrôle a d'abord été un
      `print`, puis une assertion — **et l'assertion est tombée**. On ne sait pas
      si c'est un artefact du sans-rendu ou un fait de jeu. **Ce banc couvre donc
      la remise à zéro, pas le fait qu'un ralenti ait eu lieu avant** : son
      « le ralenti est levé » vérifie une valeur qui n'a peut-être jamais bougé.
    - À éclaircir en instrumentant le `target_time_scale` réellement calculé, ou
      à l'œil sur une vraie partie. **Écrit ici pour que personne ne prenne cette
      suite pour une garantie qu'elle ne donne pas.**
  - **Famille 5.2 automatisée le 2026-08-18**, dans le banc à **une** instance
    (`test_fin_de_match`) : la vitesse normale est rendue quand la killcam se
    termine d'elle-même. C'est le chemin de sortie le plus fréquent du jeu —
    celui de chaque mort de chaque partie — et le seul qu'une instance unique
    puisse exercer.
    - **Déterministe, contrairement au chemin de la déconnexion.** La séquence de
      fin est allée à son terme : on mesure un état stable, pas une fenêtre
      fugace de quelques dixièmes. C'est pourquoi ce contrôle vit dans le banc à
      une instance et **pas** dans celui à deux, où il serait instable par
      construction.
    - Trois contrôles : `time_scale` rendu à 1,0, rejeu arrêté, et **aucune vue
      laissée figée** — la ceinture de V2.1 passe par le même chemin.
  - **Famille 7.2 verrouillée le 2026-08-18**, dans `test_audit_menus` : **la
    carte appartient à l'hôte.** L'invité ne se voit pas proposer d'en changer —
    non par avarice, mais parce que son choix serait **écrasé au lancement**. Un
    bouton qui laisse choisir puis n'en tient pas compte est pire qu'un bouton
    absent : il fait croire à une décision qui n'existe pas.
    - Vérifié comme **propriété de structure du menu**, sans réseau ni
      adversaire : les deux écrans hôte offrent le panneau des cartes, les deux
      écrans invité non, et l'écran partagé le garde — les deux joueurs y sont du
      même côté.
    - Encore un contrôle placé là où il est déterministe plutôt que là où le
      sujet semble vivre. Le reste de la famille 7 (la carte suivante est bien
      jouée des deux côtés, carte personnalisée absente du disque de l'invité)
      demande deux instances et n'est pas couvert.
  - **Famille 6 automatisée le 2026-08-18** (`run_duo.sh --spam`) : les deux
    joueurs martèlent « prêt » pendant six secondes, **une seule manche doit
    démarrer**.
    - **Elle paraissait intestable, et c'est parce qu'on cherchait la mauvaise
      chose.** Elle décrit un martèlement pendant des transitions, donc des
      fenêtres de quelques dixièmes. Mais **sa propriété n'est pas une fenêtre,
      c'est un COMPTE** — et un compte est stable quel que soit le tempo. Si le
      code se cassait (double départ), il passerait à deux et le contrôle
      tomberait.
    - ⚠️ **Une seconde assertion a été tentée trois fois puis retirée**, et le
      récit est dans le banc : « décompte qui repart » s'est révélé faux sur sa
      prémisse (l'état `round_active` + `countdown_left > 0` est celui, normal,
      du 3-2-1), puis décalé d'un cran, puis en échec pour une raison non
      élucidée. **Retirée plutôt qu'affaiblie** — chaque correction la
      rapprochait de « ne rien vérifier », et la troisième aurait été le moment
      de l'assouplir jusqu'à ce qu'elle passe.
  - ⚠️ **La famille 4 n'est pas automatisable en l'état, et pas pour une raison
    technique : son attendu est contredit par le code.** La checklist demande que
    A « termine sa killcam en entier » quand le pair disparaît ; `_on_peer_disconnected`
    appelle `_abort_killcam()` et la coupe. **Les deux se défendent** — terminer
    respecte le joueur qui regarde, couper reconnaît que le match est fini et rend
    la main plus vite. Écrire un test contre l'un ou l'autre reviendrait à
    **trancher une question de jeu à la place d'Adrien**. Signalé dans la
    checklist ; son absence est un choix, pas un oubli.
  - Restent manuelles : la famille 4 (bloquée ci-dessus) et le reste des 5 et 7 de la
    [CHECKLIST_TESTS_EN_LIGNE.md](CHECKLIST_TESTS_EN_LIGNE.md) — pause en ligne,
    RPC pendant la killcam, reconnexions. Elles ont maintenant un socle.
- ~~`ReplaySystem` n'a pas de test unitaire.~~ **Fermé le 2026-08-18** par
  `tools/test_rejeu.gd`, qui verrouille les deux défauts déjà payés — la cadence
  fixe à 60 Hz (une seconde à 492 fps doit donner ~60 images, pas 492) et l'ancre
  d'impact qui ne repasse pas par sa propre sentinelle `-1`.
  - **Et il en a trouvé un troisième, réel : `slow_mo_start_frame` pouvait être
    négatif.** Le chemin nominal borne à zéro (`max(0, frame - 1)`), le **repli**
    ne bornait pas (`impact_frame - 15`). Une mort dans les quinze premières
    images rendait donc une ancre négative — que `start_playback` n'écarte pas,
    sa sentinelle étant `-1` et non « négatif ». Le ralenti se calculait alors
    sur un vol de balle débordant avant le début de l'enregistrement : sa
    progression démarrait déjà passé le seuil d'accélération, **donc le ralenti
    n'avait pas lieu**. Corrigé aux deux endroits.
  - Piège de méthode rencontré une troisième fois dans la journée : un faux
    joueur bâti en posant des propriétés au vol sur un `Node2D` (`set("hp", …)`)
    n'en crée aucune — l'appel échoue, la fonction de test s'interrompt, et la
    suite continue. Il faut une vraie classe.

---

## Game feel — propositions priorisées (étude des animations, 2026-08-16)

Soixante-dix propositions issues d'une étude des animations, effets et sons du
jeu, pour amplifier l'aspect addictif de la boucle. Triées en six vagues par
**ratio effet/effort** (les systèmes déjà câblés mais endormis d'abord), par
**position dans la boucle** (le kill et le rematch avant le polish de manche),
et par **dépendances** (les commandes d'assets tôt, leur délai est long).

Cadre de jugement, valable pour chaque item : pendant la manche, aucun effet ne
doit créer d'information asymétrique ni coûter du 1 % bas ; le kill, la
killcam, les écrans de fin et le menu sont des **zones franches** (la manche
est finie, budget libre). Tout shader neuf se précharge en `const`, toute
particule passe par le pool, jamais d'ombres sur les lumières de particules.
Sauf mention *assets*, un item est 100 % procédural : zéro ressource à fournir.

> **Lot du 2026-08-18 (session game feel) — V4.11, V4.13, V5.1, V5.3 audio,
> V5.4, V5.5, V5.6, V5.9, V6.2, V6.3 livrés.** Le lot a été taillé pour tenir
> **entièrement dans les fichiers de la session** (player.gd, bullet.gd,
> particle_pool.gd, audio_manager.gd, shaders) : `game_state.gd` et `ui.gd`
> sont passés à la session « fin de match », et tout ce qui exige un site
> d'appel chez eux est **bloqué en attendant, pas abandonné** — V3.3 (naissance
> de la lumière au FIGHT : décision de jeu, voir l'item), V3.4 (le tic-tac
> sous 10 s se déclenche là où `time_left` fait autorité), V3.7/V3.8 (stingers
> de fin — assets de toute façon), V5.12 (réverb dérivée de `grid_size` à
> l'entrée de manche), V6.1/V6.5 (l'overlay killcam et son uniform vivent dans
> l'orchestration de killcam). Les specs d'intégration sont sur chaque item ;
> le reste de la vague 5 (V5.7, V5.8, V5.10, V5.11) attend assets ou arbitrage.

### Vague 1 — Réveiller ce qui dort (systèmes câblés, jamais alimentés)

- **V1.1 Stems musicaux réels** — l'AudioStreamInteractive 4 couches à 170 BPM
  était câblé sur les flux vides de `generate_music_streams.gd` (seul le
  heartbeat était réel). **✅ Fait le 2026-08-24** — Adrien a livré les onze
  fichiers (`exports/V03`), intégrés en `.ogg` 48 kHz sous les noms que le
  manifeste attendait déjà, donc **sans une ligne de code à changer**.
  `main_stream_interactive.tres` a été réécrit au passage : il **référence** les
  flux au lieu de les embarquer en base64 (704 ko → 2,9 ko).

  La leçon, et c'est elle qui vaut d'être notée : le système a vécu deux mois
  « fonctionnel » sans jouer sa musique. Aucune erreur, aucun test rouge —
  `AudioManager` chargeait quatre clips, basculait de l'un à l'autre, ouvrait
  ses couches, et rendait autre chose que ce qu'on croyait. C'est exactement ce
  que `asset_manifest.gd` avait été écrit pour rattraper. Il l'a rattrapé ; il
  aura fallu qu'on lise le panneau.

  **Correction du 2026-08-24, après mesure — « muet » était faux, et je l'avais
  écrit deux fois.** Signalé par la session « DA1 », vérifié en décodant les
  fichiers depuis `3a1e18e` plutôt qu'en les croyant vides :

  | Bouche-trou (avant) | Durée | Crête | RMS |
  |---|---|---|---|
  | `music_menu` / `music_match` / `music_victory` | 11,294 s | −19,2 dBFS | −33,0 dBFS |
  | `music_intro` | 12,000 s | −15,2 dBFS | −32,6 dBFS |

  Ce ne sont pas des silences, ce sont des **timbres audibles**. Le jeu ne se
  taisait pas : il jouait doucement autre chose, et personne ne s'en est étonné
  parce que tout le dépôt les appelait « flux vides ». C'est le mode de
  défaillance le plus coûteux du lot — un défaut qu'on ne cherche pas, parce
  que le mot qui le désigne dit déjà qu'il n'y a rien à entendre.

  Deux détails qui vont avec, mesurés au passage : les 160 032 octets valent
  **11,294 s et non 22,588 s**, et `music_intro` n'était pas une copie des
  trois autres — durée, taille et timbre différents. La détection à l'égalité
  exacte ne rattrapait donc qu'un seul gabarit sur deux.
- **V1.2 Brancher `set_music_intensity`** — écrit, jamais appelé. Règles : 0
  par défaut, 1 en dernière minute, 2 quand les deux joueurs sont sous 30 HP.
  **✅ Fait** — piloté par `GameState._update_music_intensity` chaque frame
  (idempotent côté AudioManager), remis à 0 par `set_in_match`. Inaudible tant
  que les stems (V1.1) sont vides, mais la mécanique est en place.
- **V1.3 Fichiers annonceur manquants** — `spk_fight`/`spk_p1_wins`/
  `spk_p2_wins`/`spk_draw` sont câblés dans `SOUNDS` mais absents du dépôt
  (`assets/audio/speaker/` n'existe pas). — *assets : 4 lignes voix, 8 avec
  « PARFAIT » (kill sans dégât reçu) et « DE JUSTESSE » (< 10 HP restants).*
  **✅ Fait le 2026-08-25.** Huit fichiers livrés dans `assets/audio/voice/`.
  La règle est `AudioManager.voix_de_fin`, **dérivée d'`ecoute_somme`** et non
  écrite à côté : en écran scindé l'annonceur NOMME le vainqueur (deux joueurs,
  mêmes haut-parleurs), partout ailleurs il s'adresse à celui qui écoute — `win`,
  `defeat`, plus `spk_perfect` (sorti intact) et `spk_close_call` (sous 10 PV).
  Décision d'Adrien.
- **V1.4 Volumes utilisateur** — Master/Musique/Effets/Annonceur dans Options.
  Précondition de tout le reste : on ne densifie pas un mixage non réglable.
- **V1.5 Vibrations manette** — `start_joy_vibration` absent du code : tir
  (forte courte), impact reçu (moyenne), pouls faible sous 30 HP, double coup
  au kill. **✅ Fait** — constantes `RUMBLE_*` dans `player.gd`. Ne vibre que le
  pad du joueur localement aux commandes (device du `LocalInputProvider`,
  seulement s'il est branché). Impact branché sur `rpc_update_hp`
  (autoritaire), pas sur la balle prédite ; pouls à mi-temps de 170 BPM.
  Le réglage on/off attendra les Options de la Phase 5.

### Vague 2 — Le kill (zone franche, le shot de dopamine de la boucle)

- **V2.1 Gel d'exécution** — 150 ms de gel du rendu au moment fatal, puis
  chute dans le bullet-time existant. Pas de `time_scale` (piège connu).
  **✅ Fait** — gel du rendu seul (`render_target_update_mode` des deux
  viewports), 150 ms temps réel, une frame de délai pour figer le trait V2.6 ;
  restauration avant tout test de jeton + ceinture dans `_abort_killcam`.
- **V2.2 Le noir gagne** — à la mort, les lumières s'éteignent une à une en
  400 ms, la torche du tueur en dernier, puis le death flash existant.
  **✅ Fait** — rétrodiffusion (0,15 s) puis faisceau (0,25 s) du vainqueur,
  la victime étant déjà éteinte par `die()` ; les énergies remontent seules
  à la manche suivante.
- **V2.3 Jingle de kill** — 2 notes dans la tonalité du thème, variante si le
  match gagne la session. — *assets : 1-2 stingers accordés.*
- **V2.4 Onde de choc lumineuse** — cercle plein écran depuis l'impact, 400 ms.
  **✅ Fait** — `kill_shockwave.gd`, double anneau additif dessiné (aucune
  PointLight2D : une grande lumière recalculerait toutes les ombres),
  traverse les murs par design — ponctuation, pas information.
- **V2.5 « FATAL — ARBALÈTE »** — le label FATAL s'enrichit du nom de l'arme.
  **✅ Fait.**
- **V2.6 Trait sur-exposé** — la balle fatale laisse son trait HDR 1 frame.
  **✅ Fait** — largeur et énergie triplées sur kill jugé localement, fondu
  ralenti à 0,35 s pour que le gel V2.1 fige l'image incandescente.
- **V2.7 Tampon final** — stamp « KILL — 04:12 » sur l'arrêt sur image de 2 s.
  **✅ Fait** — CanvasLayer propre à GameState (ui.gd est à l'autre session),
  nettoyé par `_abort_killcam` sur tous les chemins de sortie.
- **V2.8 Acouphène de mort** — sifflement + monde étouffé 1 s côté perdant. —
  *assets : 1 sample.*
- **V2.9 « Effleuré : 13 px »** — afficher au perdant la distance
  perpendiculaire du tir fatal (la formule de dégâts la connaît). Le « j'y
  étais presque » est le moteur du rematch. **✅ Fait** — écrit par la balle
  fatale simulée localement, consommé par `die()`, jamais réutilisé.

### Vague 3 — Le rematch et le rythme (là où « encore une » se décide)

- **V3.1 REJOUER respire** — scale 1,00→1,03 au BPM, curseur aimanté dessus
  (`nav_seed`). **✅ Fait** — l'écran de fin est le seul du jeu où une entrée
  mérite d'attirer l'œil : après un match on ne cherche pas dans une liste, on
  redemande. Trois pour cent et pas davantage, parce que l'entrée vit dans une
  colonne dont les voisines ne bougent pas — au-delà, elle ne respire plus, elle
  saute, et la liste entière paraît instable. Un cosinus plutôt que deux tweens
  enchaînés : la courbe se referme sur elle-même, donc aucune couture au passage
  d'un battement au suivant.
  - **`nav_seed` accepte une valeur commune** (`NAV_SEED_LES_DEUX = -2`) : après
    un match en écran partagé les deux joueurs redemandent, et faire chercher le
    second lui ferait payer de ne pas être le premier. Négative à dessein — un
    indice de joueur est positif, et écrire 2 aurait fait d'un troisième joueur
    imaginaire une graine valide.
  - **Ce que la suite protège est l'arrêt, pas l'animation.** Une respiration qui
    survit à la fermeture laisserait une entrée du menu principal enfler seule —
    et là elle ne dit plus « rejouer » mais « prêt » : le menu insisterait pour
    lancer une partie que personne n'a demandée. Une boucle infinie ne se
    signale jamais d'elle-même.
  - **Signalé, pas corrigé** (hors périmètre) : en écran partagé l'entrée de
    relance s'appelle « JOUER » et n'est pas dans `_ready_entries`, donc le
    renommage PRÊT → REJOUER l'ignore. Le commentaire de `_sync_launch_entries`
    affirme pourtant qu'« une seule entrée porte les deux gestes ». C'est vrai
    en ligne, faux en écran partagé. La respiration passe par une liste séparée
    (`_relance_entries`) pour ne pas sauter le mode le plus joué **sans** changer
    au passage un libellé que personne n'a demandé de changer.
- **V3.2 La pression du prêt** — quand l'adversaire passe « ✓ PRÊT » (RPC déjà
  reçu), ping sonore + pulse du libellé. — *assets : 1 sample.* **✅ Fait** — le
  ping est câblé sur `ui_ready_ping`, clé déjà déclarée : il s'entendra le jour
  où le fichier arrive, sans rien à recâbler.
  - **Un message disait l'inverse de la vérité, et c'est le vrai gain.** Quand le
    client s'était déclaré et pas l'hôte, l'écran de l'hôte affichait « EN
    ATTENTE D'UN ADVERSAIRE » — alors que l'adversaire était là, prêt, et
    attendait précisément celui qui lisait la phrase. On ne se dépêche pas pour
    quelqu'un qu'on croit absent.
  - Le cas du « prêt » reçu **pendant la killcam** est traité aussi : son
    intention était déjà retenue, elle se signale à la sortie. Sans ça, le seul
    cas où l'adversaire est prêt AVANT nous aurait été le seul à ne rien montrer.
  - **Sur `self_modulate`**, ni `scale` (pris par la respiration V3.1) ni
    `modulate` (porte le grisage quand il manque un joueur). Trois intentions
    sur les mêmes boutons, trois propriétés — et la suite vérifie la
    cohabitation, parce que chacun des deux effets fonctionne parfaitement seul.
  - **Signalé, pas corrigé** (ce serait un changement de protocole) : le client
    n'apprend **jamais** que l'hôte est prêt — aucun RPC ne le lui dit. Il presse
    PRÊT, voit « ✓ PRÊT », puis attend sans savoir s'il attend l'hôte ou le
    réseau. L'ajout d'un RPC hôte → client demanderait une montée de
    `Protocol.VERSION`, ce qui dépasse un item de game feel.
- **V3.3 Décompte qui frappe** — 3-2-1 en pop TRANS_BACK + note montante par
  chiffre ; le CanvasModulate remonte du noir absolu au noir de jeu sur le
  « 1 ». — *assets : 3 notes courtes.* **Le pop est fait** (`ui.set_countdown`,
  TRANS_BACK depuis 1,7). Les notes attendent leurs samples. ⚠️ **La clause du
  CanvasModulate n'a pas de cible :** celui de l'arène est déjà `Color(0,0,0)`,
  et la calibration règle un **gamma**, pas cette couleur — il n'existe donc
  aucun « noir de jeu » au-dessus du noir absolu vers lequel remonter. Rendre
  l'intention (« la lumière naît au début de manche ») demanderait de toucher
  aux lumières des joueurs pendant le décompte, donc à ce qui est visible au
  départ d'une manche : c'est une décision de jeu, pas de finition.
- **V3.4 Dernière minute** — chrono or, stem batterie (V1.2), tic-tac sous
  10 s. — *assets : 1 tic-tac.* **✅ Fait côté image** : or sous 60 s, rouge
  d'alerte sous 10 s, et le chrono **bat à la seconde** sous ce dernier seuil.
  - Le battement naît du **temps lui-même** (`fmod(time_left, 1.0)`), pas d'un
    tween. Un tween relancé à chaque frame ne bat pas, il tremble — et un chrono
    resynchronisé par le réseau saute d'une fraction de seconde sans casser la
    pulsation.
  - La couleur ne s'écrit qu'aux **passages de seuil**, et se remet à neuf au
    début de chaque manche : sans ça, une manche qui suit une fin de match
    hériterait du rouge pendant ses quatre premières minutes.
  - **Défaut trouvé au passage et corrigé :** `update_hud` réécrivait le chrono
    **inconditionnellement**, donc `ui.time_label.text = "ENTRAÎNEMENT"` était
    effacé à la frame suivante et ne s'est jamais affiché. Une ligne qui existait
    et ne servait à rien, sans que rien le signale — un HUD qui écrase à chaque
    frame gagne toujours contre celui qui écrit une fois.
  - **Signalé, pas corrigé :** l'entraînement tourne sur le **même chrono de
    5 minutes** et se termine par une égalité. Défendable comme limite de
    séance, mais ce n'est écrit nulle part et personne ne l'a décidé.
- **V3.5 VICTOIRE qui claque** — lettres qui tombent une à une, fond pulsé au
  BPM. — *assets : 1 impact typographique.* ⚠️ **Sa prémisse a expiré, à
  rediscuter avant d'y toucher.** `game_over_title` **est** le titre du menu
  (« CANDELA 2D »), et M11 l'a adopté : le shader de braise vit sur ce `Label`
  et porte déjà la température du verdict — la victoire flambe, la défaite tombe
  de moitié. M1 y ancre en plus l'ombre du cadran. Le remplacer par une rangée de
  `Label` par lettre écraserait les deux. Reste possible sans rien casser :
  révéler les caractères un à un (`visible_characters`), le shader peignant ce
  qui est dessiné. Mais l'écran de fin est déjà signé, et en rajouter demande
  d'abord de décider si le verdict manque de quelque chose.
- **V3.6 Score qui se remplit** — la nouvelle unité de « SESSION : 3 - 2 »
  glisse avec un son de pion. — *assets : 1 sample.* **✅ Fait côté image.** La
  ligne monte de dix pixels **en prenant la couleur de celui qui vient de
  marquer**, puis retombe au repos. Le libellé restant un seul `Label`, on ne
  peut pas teinter un chiffre isolément — et teinter la ligne entière dit
  mieux la même chose : « 3 - 2 » ne révèle pas **qui** vient de gagner.
- **V3.7 Stinger de défaite noble** — 2 s qui se résolvent vers le thème du
  menu : perdre ne doit pas donner envie de quitter. — *assets : 1 stinger.*  **✅ Câblé le 2026-08-25** — `AudioManager.stinger_de_fin` décide
  lequel des quatre sort, selon le résultat et selon qui l'on est.

- **V3.8 L'égalité pèse** — silence sec 1 s puis « ÉGALITÉ » gris et soupir de
  détente. — *assets : 1 sample.* **✅ Fait** (le soupir attend le sien). Gris et
  non blanc : le blanc est la couleur de ce qui s'affirme, une égalité n'affirme
  rien. Le silence sec **coupe le bus musical** plutôt que d'en baisser le
  volume, et **restitue l'état trouvé** — le bus est déjà coupé quand le joueur a
  mis la musique à zéro, le rallumer d'office lui rendrait un son qu'il a
  retiré. Même règle que pour toute propriété partagée.
- **V3.9 Série de session** — « SÉRIE : 3 » à l'écran de fin, brisée avec un
  bruit de verre. **✅ Fait côté image** (le bruit de verre attend son sample).
  Ce qu'elle apporte que le score n'apportait pas : « 3 - 2 » ne dit pas dans
  quel **ordre**. Trois victoires puis deux défaites, ou une alternance stricte,
  donnent le même affichage — et on ne se sent pas du tout dans la même partie.
  - Une **égalité fait tomber** la série : une série est faite de victoires
    consécutives, et laisser une nulle la prolonger reviendrait à dire qu'on n'a
    pas perdu, ce qui n'est pas la même fierté.
  - Une **série de 1 ne se dit pas** — c'est un match gagné. L'annoncer à chaque
    fin de match viderait le mot avant qu'il ait servi une fois. Et une série de
    1 ne se **brise** pas non plus : elle passe.
  - La **rupture se dit avant** la série qui commence. Perdre une série de quatre
    est l'événement du match ; annoncer « SÉRIE : 1 » au vainqueur passerait à
    côté de ce qui vient de se produire.
  - Dans `serie_de_session.gd`, **pas dans `game_state.gd`** — voir les pièges :
    une suite qui charge l'orchestrateur en `--script` annonce « tous les tests
    passent » sur des appels morts.
- **V3.10 Stingers accordés** — kill/victoire/défaite/égalité dans la tonalité
  du thème : le jeu devient un seul instrument. — *assets : couvert par V2.3,
  V3.7, V3.8.*

> **⚠️ Avant de piocher dans les vagues 4 et 5 : beaucoup de ces items ne sont pas
> de la finition, ce sont des décisions de conception déguisées.** Le gel lié aux
> fps est levé (Adrien, 2026-08-18) ; ce tri-ci est indépendant et il reste.
>
> Dans ce jeu, **la lumière EST l'information**. Un effet visuel en manche n'est
> donc jamais neutre : il ajoute une chose que quelqu'un peut voir. Trois exemples
> dans la liste ci-dessous, tous rédigés comme des propositions esthétiques :
>
> - **V4.11 « les gouttes brillent 200 ms de leur propre lumière — toucher, c'est
>   voir »** : un sang auto-éclairé **révèle la position de la victime** au moment
>   du coup au but, dans le noir. C'est peut-être exactement ce qu'on veut ; ce
>   n'est pas une décision qu'un agent prend en implémentant.
> - **V4.13 fumée de bouche, 1 s** : prolonge d'une seconde la trace d'un tir,
>   donc la fenêtre pendant laquelle on sait où l'autre a tiré.
> - **V5.5 poussière dans le faisceau** : rend le faisceau visible **de côté**,
>   donc trahit un porteur de torche qu'on ne voyait pas jusque-là.
>
> **La leçon du 2026-08-18 s'applique mot pour mot :** ces phrases viennent de
> l'étude d'animations du 2026-08-16, pas d'Adrien. Les traiter comme des
> décisions prises, c'est refaire ce qui a été fait avec « l'écran partagé
> permanent est une décision de conception » — **transformer une description en
> intention**. Elles se **posent** à Adrien, elles ne s'implémentent pas d'office.
>
> Reste implémentable sans arbitrage : ce qui ne change **rien à ce qui est
> visible en manche** — l'audio, les menus, la killcam (zone franche, la manche
> est finie), et les effets purement locaux à celui qui agit déjà (recul de
> caméra, vibration).

### Vague 4 — L'identité du tir et de l'impact

- **V4.1 Un son PAR arme** — **✅ Fait le 2026-08-25.** Les 4 armes partageaient
  `weapon_shoot.wav`. Chacune a désormais **quatre variantes** dans
  `assets/audio/weapons/`, tirées au sort à chaque coup
  (`AudioManager.play_weapon_shot`).

  **Le découpage corps + queue annoncé ici n'a pas été retenu, et la raison
  vaut d'être gardée.** Il figurait au manifeste en huit entrées ; *rien ne le
  consommait* — aucune ligne de code ne connaissait `weapon_*_body` ni
  `weapon_*_tail`. Ce qui a tranché, c'est **V5.12** : une queue cuite dans
  l'échantillon **fige une pièce dans l'asset**, et s'additionnerait à la réverb
  dérivée de `grid_size`. Deux pièces superposées, dont la seconde ne dirait plus
  rien de la carte. Le découpage ne redeviendra utile que le jour où l'on voudra
  un rendu par distance — queue seule et étouffée au loin — et ce jour-là il se
  ré-exporte.

  **Quatre prises réelles plutôt qu'un échantillon repitché** : le tir est le son
  le plus répété du jeu, et un même échantillon s'entend en une poignée de coups
  quel que soit le pitch. Le pitch reste, resserré à ±4 % — la variation large
  servait à masquer la répétition ; trop de pitch s'entend comme un calibre qui
  change de taille d'un coup à l'autre.

  Les fichiers sont **forcés en mono à l'import**, comme le reste des effets :
  ils se jouent en 2D positionnel, et dans ce jeu **savoir d'où vient le coup est
  l'information**. Un flux stéréo dans un lecteur positionnel dilue le
  panoramique — la source cesse d'être un point.
- **V4.2 Hitmarker centre/bord** — « thock » à pleins dégâts, « tick » en
  effleurement, branché sur `rpc_update_hp` (autoritaire), pas sur la balle
  prédite. — *assets : 2 samples.*
- **V4.3 Ricochet du fusil** — étincelles + « zing » par rebond : récompenser
  le geste le plus stylé du jeu. — *assets : 3 samples.*
- **V4.4 Tir à sec** — clic + tremblement du cercle de cooldown quand on
  presse pendant le rechargement. — *assets : 1 sample.* **✅ Fait côté image.**
  Presser la détente pendant le rechargement ne produisait **rien** : ni son, ni
  image, ni vibration. Le joueur ne pouvait pas distinguer « j'ai appuyé trop
  tôt » de « ma touche n'a pas répondu » — le seul geste du jeu qui échouait en
  silence.
  - **Front montant seulement** : détente maintenue une seconde, le refus se dit
    une fois. Un tremblement continu ressemblerait à une panne d'affichage.
  - **Dessiné, pas déplacé** : le widget vit dans un conteneur, qui lui
    réimposerait sa position à la frame suivante.
  - **Uniquement pour celui qui a pressé.** En ligne l'hôte simule aussi
    l'adversaire : sans filtre, son HUD tremblerait quand le client tire à sec,
    lui apprenant que l'autre vient d'essayer de tirer — donc qu'il est à portée
    et à découvert. Même règle que pour le passe-bas des torches.
- **V4.5 Chiffres de dégâts avec poids** — pop TRANS_BACK, taille ∝ dégâts,
  or si ≥ 50. **✅ Fait** — 20→44 px proportionnels, or au seuil de 50.
- **V4.6 Zoom-kick à l'encaisse** — 2 % de dézoom 100 ms côté blessé.
  **✅ Fait** — sur la perte de PV autoritaire, jamais prédite.
- **V4.7 Vignette battante** — la vignette rouge pulse à 170 BPM sous 30 HP,
  synchrone du stem heartbeat. **✅ Fait** — même battement que le pouls
  haptique V1.5 : un seul cœur pilote l'image, la main et le stem.
- **V4.8 Douilles** — éjection via le pool + tintement décalé de 300-500 ms. —
  *assets : 3-4 samples.*
- **V4.9 Souffle du blessé** — souffle coupé abstrait sur gros impact. —
  *assets : 4-6 samples.*
- **V4.10 Vol de l'arbalète** — chuintement doppler discret du carreau sans
  lumière. — *assets : 1 boucle courte.*
- **V4.11 Éclat de sang** — les gouttes brillent 200 ms de leur propre lumière
  (déjà sans ombre) : toucher, c'est voir. **✅ Fait** — surmultiplication ×2
  de la lumière déjà portée par la goutte, décroissance linéaire dans
  `advance()` : l'éclat vit dans le tableau plat du pool, aucun nœud ni tween
  de plus. Visible sur les deux écrans par construction — toucher n'est pas
  une information privée, c'est la seule « annonce » que les deux partagent.
- **V4.12 Recul de caméra directionnel** — kick 4-6 px opposé au tir.
  **✅ Fait** — 6 px résorbés en ~100 ms, additionnés au shake existant.
- **V4.13 Fumée de bouche** — 2-3 particules additives dérivant 1 s.
  **✅ Fait** — profil `SMOKE` du pool : gros grain additif **sans lumière
  propre** (il n'existe que révélé — flash du tir, torche), forte friction
  pour l'effet nuage. Émis dans `trigger_shoot_visuals`, donc sur les mêmes
  chemins que le flash : hôte, tir prédit du client et killcam le voient tous.
- **V4.14 Le sol répond** — décal lumineux 1 frame sous le tireur.
  **✅ Fait** — écho lumineux au sol, décor seulement, sans ombre.
- **V4.15 Duck des pas sous le tir** — −6 dB pendant 300 ms après un coup de
  feu. **✅ Fait** — appliqué dans `AudioManager.play_sfx_2d`, donc sans toucher
  aux appelants, et **ajouté** au volume demandé plutôt que substitué. Ne
  concerne que les pas : effacer l'impact effacerait l'information qu'on vient
  de payer d'un tir.
- **V4.16 Priorités du pool SFX** — protéger les sons « récit » (kill, hit
  autoritaire) du vol de voix par les pas. **✅ Fait** — le pool tournait en
  anneau, le dix-septième son écrasant le premier quel qu'il soit. Les pas
  étant la source la plus bavarde (6-7 par seconde à deux joueurs), ce sont eux
  qui volaient le plus souvent une voix : le son qui n'apprend rien coupait le
  son qui apprend tout. Trois règles — une voix libre d'abord, sinon la moins
  prioritaire (à égalité la plus ancienne, l'anneau confiné à une classe), et
  **jamais plus important que soi** : un pas renonce plutôt que de couper un
  coup au but. L'arbitrage est une **fonction pure** (`choisir_voix`), sans
  nœud ni serveur audio, parce qu'en headless le pilote est muet et
  `AudioStreamPlayer.playing` ne dit pas la vérité — sans ça, l'arbitrage
  n'aurait été vérifiable qu'à l'oreille, en match, une fois.

### Vague 5 — Le noir qui respire (la traque, budget discret)

- **V5.1 Claquement de torche iconique** — le son entendu 500 fois par
  soirée, avec 2 frames de sur-intensité à l'amorçage. — *assets : 2 samples
  soignés.* **✅ Câblé, muet** — `torch_on`/`torch_off` joués sur la
  **transition** d'état seulement (pas à chaque frame où la torche est tenue),
  dans `set_player_torch`, que le site d'appel filtre déjà par
  `torche_comptee` : la torche adverse en ligne n'arrive jamais jusqu'au son.
  Les deux fichiers sont au manifeste ; rien à recâbler à la livraison. La
  sur-intensité d'amorçage appartient au sample lui-même, pas au code.
- **V5.2 Allumer = entendre** — amplifier le passe-bas piloté par les torches
  (déjà câblé) + sweep audible à l'allumage. **✅ Fait**, mais **il a d'abord
  fallu colmater une fuite d'information** — voir les pièges. L'écart passe de
  300-600 Hz (une octave qu'on ne remarque pas en jouant) à 200-840 : dans le
  noir la musique est sourde et lointaine, torche allumée elle revient dans la
  pièce. Le balayage dépasse la cible de 70 % en 0,09 s puis y retombe en
  0,45 s — c'est le dépassement qu'on entend, un filtre qui s'ouvre ; sans lui
  le changement est réel mais passe pour un hasard du mixage. **Aucun
  dépassement à l'extinction** : on ne fête pas de redevenir invisible.
- **V5.3 L'éblouissement se sent** — bloom pulsé + acouphène doux suivant
  `dazzle_amount` côté ébloui. — *assets : 1 boucle.* **✅ Fait côté audio,
  câblé-muet** — `AudioManager.set_dazzle_level(pid, dazzle_amount)` alimenté
  chaque frame par le joueur **piloté localement** uniquement : l'éblouissement
  est calculé par machine, on n'entend que le sien. En écran partagé les deux
  joueurs partagent la sortie audio, le volume suit donc le **max** des deux
  niveaux. La boucle (`tinnitus_dazzle.wav`, au manifeste) démarre/s'arrête
  sur les franchissements et son volume suit le niveau — muette tant que le
  fichier manque. **Le « bloom pulsé » n'est pas retenu** : pas de bloom sous
  `gl_compatibility`, et l'overlay blanc existant porte déjà la sensation —
  en pulser l'alpha brouillerait la lecture du niveau d'éblouissement, qui
  est une information de duel, pas une décoration.
  **✅ Complété le 2026-08-18 (session « éblouissement ») :** l'acouphène et le
  voile étaient branchés sur une valeur qui ne montait jamais — le câblage
  audio de ce jour-là était correct et parfaitement inaudible. La mécanique
  répare, l'item tient enfin ce qu'il annonce. Le voile reste blanc et plat,
  comme décidé ci-dessus ; ce qui a changé, c'est qu'il a maintenant quelque
  chose à montrer.
- **V5.4 Respiration de la torche** — Perlin lent ±3 % sur l'énergie.
  **✅ Fait** — le bruit module la **cible** du lerp d'énergie existant, pas
  l'énergie elle-même : la respiration traverse les fondus d'allumage et
  d'extinction sans les casser, et s'éteint avec eux. ±3 % et pas plus : la
  torche doit sembler vivante, pas défaillante — une torche qui faiblit
  visiblement dirait « pile morte », une mécanique qui n'existe pas.
- **V5.5 Poussière dans le faisceau** — particules additives ténues (pool).
  **✅ Fait** — profil `DUST` (grain minuscule, additif, presque immobile,
  sans lumière propre : il n'existe que révélé par le faisceau), semé à
  cadence fixe dans le cône réel de l'arme (`torch_angle_deg`, portée
  courante) tant que la torche est allumée. Côté budget, la poussière passe
  par le pool plafonné : elle recycle, elle n'alloue pas.
  ✅ **Corrigé le 2026-08-18** : le semis prenait `torch_angle_deg` pour un
  angle plein et le redivisait par deux, alors que c'est déjà un **demi**-angle
  — la poussière dansait dans un cône deux fois trop étroit, le pompe n'en
  semant que dans un tiers de sa flaque. Le semis lit maintenant
  `WeaponData.demi_angle_torche()`, comme l'éblouissement lit
  `cos_demi_cone()` : une seule lecture, un seul endroit où se tromper.
- **V5.6 Rétrodiffusion pulsée au pas** — le BodyLight respire en marchant.
  **✅ Fait** — chaque pas détecté (le détecteur V1.x existant, déjà gardé
  contre les téléportations) arme une impulsion qui se résorbe en ~140 ms sur
  la lumière de corps. La rétrodiffusion étant déjà visible de l'adversaire,
  la pulser n'ajoute **aucune information nouvelle** — elle rend juste la
  marche organique : on voit quelqu'un marcher, pas un lampadaire glisser.
- **V5.7 Pas par matériau** — 2 jeux de pas pour les 2 sols du damier. —
  *assets : 2×4 samples.*
- **V5.8 Shimmer du liseré néon** — les bordures des murs scintillent sous une
  lumière directe.
- ~~**V5.9 Streaks de sprint**~~ — ❌ **SANS OBJET depuis le 2026-08-26** : le
  sprint est supprimé (voir « Décisions actées »), donc `sprint_streaks.gdshader`
  est supprimé avec lui. L'effet fonctionnait ; il n'a plus rien à signaler.
  Conservé ci-dessous parce que la **raison d'écarter la vignette** vaut au-delà
  du sprint et resservira au premier effet plein écran qu'on voudra ajouter.
  Description d'origine : vignette resserrée + traits de vitesse côté
  sprinteur. Shader plein écran préchargé : pointillés radiaux filant vers l'extérieur,
  confinés aux bords (le centre, là où on vise, reste propre), intensité
  lissée à l'entrée/sortie de sprint. Le rect porte le `visibility_layer` du
  joueur : chacun ne voit que sa propre vitesse. **La vignette resserrée est
  écartée** : la vignette est le canal de la santé (V4.7 la fait battre sous
  30 HP) — la resserrer au sprint superposerait deux messages sur le même
  signal, et « je cours » se lirait « je saigne ».
- **V5.10 Présence de la salle** — sons ponctuels pannés très espacés. —
  *assets : 5-8 samples d'ambiance.*
- **V5.11 Frôlement de mur** — tissu + poussière à < 10 px d'un mur. —
  *assets : 3 samples.*
- **V5.12 Réverb par carte** — room size dérivée de `grid_size` à l'entrée de
  manche.

### Vague 6 — Killcam, menu, méta (confort et rétention)

- **V6.1 Grain VHS dynamique** — l'overlay killcam monte pendant le
  bullet-time, se stabilise à l'impact. **✅ Fait.**
  - **Les trois défauts d'image montent ensemble** — grain, aberration
    chromatique et balayage. Un seul se lirait comme un réglage ; les trois
    ensemble se lisent comme un état, « la bande souffre ».
  - **La tension s'AJOUTE au niveau d'origine.** À zéro, l'image est exactement
    celle d'avant l'ajout de l'uniforme : une killcam d'après-impact qui
    grésillerait un peu plus qu'hier serait une régression que personne ne
    saurait nommer.
  - **Lissée vers sa cible, pas posée.** Le ralenti accélère par paliers (courbe
    de V2.1) et suivre `time_scale` au pixel ferait clignoter le grain à chaque
    changement de palier.
  - `tension_killcam()` est **nommée et pure** : un effet piloté par
    `Engine.time_scale` se réglerait sinon à l'œil, une frame à la fois, sur une
    machine donnée. Bornée des deux côtés — un `time_scale` accéléré ou négatif
    ne doit pas détruire l'image.
- **V6.2 Trajectoire au trait** — la balle fatale dessine sa ligne complète en
  pointillé pendant le rejeu : la killcam devient professeur. **✅ Fait.**
  La killcam montrait la mort **sans l'expliquer** : on voyait tomber, pas d'où
  le coup venait. Dans un jeu où l'on meurt de ce qu'on n'a pas vu, c'est
  exactement l'information qui manque pour progresser — la ligne répond à la
  seule question que se pose la victime, *il était où ?*
  - **Aucune fuite** : la manche est finie, chacun rejoue **son propre**
    enregistrement, et la trajectoire est celle de la balle qui l'a tué — un fait
    déjà consommé.
  - **En pointillé, et tracé progressivement.** Un trait plein se lirait comme
    une balle encore en vol ; le pointillé dit « ceci s'est passé ». Le tracé
    avance en **temps réel**, pas en temps de scène : c'est un commentaire sur la
    scène, pas un élément de la scène — sinon il ramperait pendant le ralenti.
  - **Vide plutôt qu'approximatif** quand l'enregistrement ne permet pas de
    conclure (mort par chrono, tir sorti de la fenêtre) : **une trajectoire
    fausse enseignerait une leçon fausse**, ce qui est pire que de ne rien
    enseigner.
  - Le tir fatal se désigne par **la même règle que le départ du ralenti** — le
    dernier tir du **tueur** avant l'impact. Deux façons de le désigner finiraient
    par en désigner deux différents. La suite vérifie qu'un tir de la **victime**
    juste avant sa mort n'est pas confondu avec le coup fatal : un simple
    « dernier tir enregistré » ferait partir la ligne de la position du mort, et
    enseignerait un emplacement qui n'a jamais existé.
  pointillé pendant le rejeu : la killcam devient professeur. **✅ Fait** —
  `_draw()` sur la balle, strictement conditionné à `is_replay` : en manche
  réelle, rien, aucune information gratuite. Le tracé se dessine en espace
  local (la rotation suit la direction) et repart de zéro à chaque rebond
  comme la traîne — chaque segment du trajet est enseigné séparément, fidèle
  à la géométrie. Matériau additif non éclairé sur la racine, sinon le
  CanvasModulate noir avale le trait sous le voile de la killcam.
- **V6.3 Sidechain du ralenti** — heartbeat + souffle seuls pendant le
  bullet-time, tout relâcher à l'impact. **✅ Fait** — AudioManager détecte
  lui-même `Engine.time_scale < 0.5` en match : aucun site d'appel dans
  `game_state.gd` (passé à la session « fin de match »), le couplage est un
  constat, pas un câblage. Pendant le ralenti, les stems mélodiques tombent
  et le heartbeat est **forcé à plein** quel que soit l'état de santé ; à la
  sortie, l'intensité musicale est réévaluée depuis l'état réel (santé basse
  comprise) plutôt que restaurée depuis un instantané qui aurait pu périmer.
- **V6.4 Rembobinage VHS** — son de bande + timecode à rebours 300 ms au
  lancement. — *assets : 1 sample.*
- **V6.5 Négatif à l'impact** — 2 frames d'inversion vidéo au moment fatal.
  **✅ Fait.** Compté en **images** et non en secondes : l'effet est un
  clignement du rendu, et à 60 comme à 240 fps ce sont deux images qui doivent
  basculer, pas une durée qui en couvrirait huit.
  - **Déclenché au FRANCHISSEMENT** de l'image d'impact, jamais sur une
    comparaison de seuil : le rejeu piétine sur une même image pendant le ralenti
    extrême, et un `>=` déclencherait à chaque frame.
  - L'inversion s'applique **après la vignette** — inverser avant rendrait les
    bords sombres éclatants et emporterait le cadrage de l'image.
  - `reinitialiser_killcam()` remet l'orchestration à neuf à chaque ouverture.
    Sans ça, la **seconde** killcam de la partie trouverait le seuil déjà
    franchi et ne clignerait jamais : premier kill parfait, tous les suivants
    muets — un défaut qui ne se voit qu'à la deuxième mort.
- **V6.6 Le menu vit dans le noir** — torche fantôme balayant le fond du menu.
- **V6.7 Six slots néon** — le code de salon (6 caractères fixes) en 6 cases
  qui s'allument, clic par caractère. — *assets : 1-2 samples de frappe.*
- **V6.8 Power-on de connexion** — les deux moitiés d'écran s'allument à la
  connexion. — *assets : 1 sample.*
- **V6.9 Écran HISTORIQUE** — lire `match_history.json` (armes, cartes,
  durées) dans un onglet : contempler ses matchs, c'est revenir.
- **V6.10 Cartes de fin de soirée** — au retour menu après ≥ 3 matchs :
  « Ce soir : 7 matchs, 4-3, arme favorite : pompe ».

### Vague M — la vitrine : 15 effets visuels de menus (2026-08-18)

> **État au 2026-08-18 : LES QUINZE SONT LIVRÉS.** M1 le cadran de titre, M2 la
> rémanence rétinienne, M3 le regard du noir, M4 quelqu'un derrière la vitre,
> M5 le bruit de l'œil, M6 l'encre coulée, M7 le code gravé, M8 le départ au
> tir, M9 la torche du curseur, M10 l'extinction des feux, M11 le titre
> incandescent, M12 la brume d'abysse, M13 les squelettes de lumière, M14 le
> verre fumé, M15 le voile d'objectif. Chacun dans son fichier
> (`menu_gnomon.gd`, `menu_after_image.gd`, `menu_torch.gd`, `menu_watcher.gd`,
> `menu_passerby.gd`, `menu_ink.gd`, `menu_engraver.gd`, `menu_tracer.gd`,
> `menu_backdrop.gd`, `menu_title.gd`, `menu_veil.gd`, `menu_skeleton.gd`,
> `menu_glass.gd`, avec leurs cinq `.gdshader`) plutôt que dans un `ui.gd` de
> trois mille lignes —
> **sauf M10, qui n'a pas de nœud à lui** : il vit dans les chemins show/hide des
> deux panneaux, et c'est le seul endroit où il puisse vivre. Chacun avec sa
> ligne d'`effect_policy` **lue dans les deux sens** :
> l'intensité mémorisée s'applique à la construction et à chaque changement. Une
> ligne de politique sans lecture donnerait un curseur qui ne pilote rien, ce qui
> ressemble trait pour trait à un réglage qui marche.
>
> **Un seul étage de M14 est pris.** Sa fiche en prévoyait deux : l'étage sûr
> (filet, luisance, strie, lueur d'arête au focus — tout en ALU, coût nul) et un
> étage « flou réel » où la brume apparaîtrait défocalisée derrière le seul cadre
> de droite, par gaussienne 9 taps sur `screen_texture`. Le second **n'est pas
> pris**, et sa propre fiche disait pourquoi : « à valider au `bench_framerate`
> (cible 1 % bas ≥ 60 fps) avant d'être gardé ». Le prendre sans cette mesure
> serait ajouter une copie d'écran par image sur la foi d'une intuition. À
> reprendre le jour où quelqu'un lance le banc.
>
> **M5 et M12 sont fusionnés dans un seul matériau**, comme leurs fiches le
> prévoyaient : ils vivent sur le même quad — l'aplat de fond — et un second
> matériau plein écran aurait doublé le coût pour dessiner au même endroit. Le
> menu et la pause partagent ce matériau : ils ne sont jamais visibles ensemble,
> ils couvrent le même cadre, et deux matériaux auraient demandé de pousser
> chaque uniforme deux fois — donc, un jour, de les pousser une fois. 100 % ALU,
> zéro lecture de texture, `gl_compatibility` sans réserve.
>
> **Les livrés partagent une fiction et c'est voulu** : une flamme éclaire ce
> menu depuis quelque part. Elle projette l'ombre du titre (M1), on la porte à la
> main sous le curseur (M9), quelqu'un la promène derrière les panneaux (M4), et
> le noir qu'elle laisse a des yeux (M3). La rémanence (M2) est ce que tout cela
> imprime sur une rétine. Le second lot ajoute ce que cette lumière **écrit** :
> elle coule dans l'écran suivant (M6), elle grave le code dans le mur (M7), et
> elle part en balle quand on engage une partie (M8). M10 ferme la boucle en
> disant d'où l'on vient : entrer au menu, c'est éteindre sa torche ; en sortir,
> c'est la rallumer. Ce n'est pas une collection d'effets, c'est un même monde vu
> par neuf fenêtres.
>
> **Règle commune tenue par tous : coût nul au repos.** Chacun coupe son
> `_process` dès qu'il n'a plus rien à changer — y compris la torche, qui s'arrête
> une fois la lampe posée et la flamme retombée.
>
> **Ce que le banc `tools/test_vitrine_menus.gd` protège, et pourquoi il existe.**
> Ces effets sont décoratifs, mais **ils éteignent des contrôles pour les
> rallumer**. Une coulée interrompue par une navigation rapide, ou une intensité
> passée à zéro au milieu, et une entrée reste à alpha 0 : le joueur voit un menu
> à trous sans aucun moyen de comprendre pourquoi, et l'entrée reste dans le
> parcours du curseur — donc sélectionnable et invisible. Un effet de confort qui
> casse la navigation est pire que pas d'effet du tout. Le banc vérifie donc
> surtout des **retours à l'état sain** : arrêt en pleine coulée, extinction en
> pleine coulée, seconde coulée qui en chevauche une première. Trois chemins,
> trois façons de laisser une entrée dans le noir.
>
> **M11 a repris à M10 l'embrasement du titre**, et c'est la même leçon qu'au
> paragraphe précédent appliquée une fois de plus. M10 posait un éclat de blanc
> sur le titre pour qu'il « reprenne vie en dernier » ; M11 fait mieux, en
> balayant les lettres de la braise au plein or de gauche à droite. Deux effets
> qui rallument le même objet ne se composent pas. M10 se contente donc de rendre
> sa lumière au bloc d'en-tête, et le titre appartient à M11.
>
> Ce qui rend la cohabitation possible : **le shader du titre est entièrement
> multiplicatif**. Il ne pose jamais une couleur absolue, il multiplie celle qui
> lui arrive — `modulate` compris. M10 peut donc éteindre le titre pendant que
> M11 l'embrase, et les deux se composent au lieu de se disputer.
>
> **Le piège du `Label` que la fiche de M11 avait vu, et qui est réel** : sur un
> `Label`, chaque glyphe est un quad découpé dans un atlas, donc `UV` couvre **la
> lettre**, pas le bloc. Une onde calculée en `UV` repartirait de zéro à chaque
> caractère — un scintillement par lettre, pas une vague. La phase se prend sur
> `VERTEX.x`, continu d'un bout à l'autre du mot, normalisé par une largeur que
> le shader ne peut pas connaître et qu'on lui pousse au redimensionnement.
>
> **M14 ne vitre pas ce qu'on lit.** Le cadre de droite et les rangées de
> réglage, rien d'autre — en particulier pas les lignes du classement. Une
> luisance sur un chiffre est un coût de lisibilité pour un gain purement
> décoratif : un effet de matière se pose sur ce qu'on **manipule**, pas sur ce
> qu'on **lit**. Ce qui rend l'effet gratuit en lisibilité, par ailleurs, est que
> le matériau d'un `Control` ne peint que **son propre dessin** — sa `StyleBox` —
> et ne descend pas dans ses enfants : le texte reste net sans qu'on ait rien à
> faire pour lui.
>
> Même piège que sur le titre, même parade : une `StyleBoxFlat` à coins arrondis
> n'est pas un quad, Godot la découpe, et `UV` n'y couvre pas proprement le
> rectangle. La position vient de `VERTEX`.
>
> **M13 ne paraît que dans UN état, et ce n'est pas celui que sa fiche laissait
> croire.** Les barres fantômes attendaient « pendant que le classement attend le
> réseau », ce qui recouvre deux états très différents. Pendant
> l'**identification**, on ne sait pas encore qui demande : dix lignes fantômes
> promettraient alors un tableau dont rien ne dit qu'il existera, et
> `test_screen_leaderboard` interdisait déjà d'afficher des lignes à ce
> moment-là — l'interdit était juste. Les squelettes sont donc réservés à
> **`LOADING`** : identifié, le tableau en route. Un échec **survenu pendant
> l'attente** pose les barres sous les yeux (le geste dit « on a cherché et on
> n'a pas trouvé ») ; un échec arrivé sans qu'on ait rien montré n'a rien à
> poser. Aucun test existant n'a eu besoin d'être assoupli.
>
> **Le garde-fou de la calibration, arrivé avec M5 et rétroactif sur tous les
> autres.** C'est le seul point de la vitrine qui ne soit pas une question de
> goût. Le joueur règle son point de noir sur un champ mesuré ; trois centièmes
> de luminance parasite décaleraient ce réglage — pour lui, et donc pour tous
> ceux qui calibrent de la même façon. Les onze effets passent désormais par
> `_intensite_vitrine()`, qui rend zéro sur cet écran. **Le garde-fou est à ce
> seul endroit** plutôt que répété dans chaque effet, où il finirait par manquer
> au douzième. Il manquait à M9 depuis sa livraison, alors que sa fiche le
> demandait : c'est en écrivant M5 qu'on l'a vu.
>
> **Ce qui faisait passer M10 pour un défaut d'affichage, et les deux invariants
> qui en sont sortis** (relevé par Adrien à l'usage le 2026-08-18 : « on pourrait
> croire à des bugs d'affichage »). Ce n'était pas une impression. Trois causes,
> dont une qui n'était pas un réglage :
>
> 1. **Des blocs noirs sur une partie en cours.** Les surfaces partent en
>    silhouettes noires, mais le rideau tombait *en même temps* : pendant un
>    instant, on voyait des rectangles noirs posés sur l'arène en train de se
>    jouer, ce qui ne ressemble à rien d'autre qu'à un panneau qui a raté son
>    dessin. La nuit tombe désormais d'abord (`M10_ANCRAGE`), le menu se rallume
>    dedans.
> 2. **Trois blocs, pas une cascade.** Le hub ne compte que trois surfaces —
>    en-tête, liste, barre du bas — et un étalement large n'y fait pas une vague,
>    il y fait trois apparitions successives dont une porte presque tout l'écran.
>    L'étalement est passé sous la durée de rallumage d'une surface : les trois se
>    chevauchent, et l'œil lit une vague.
> 3. **M6 et M10 se marchaient dessus** — et c'est la vraie leçon. Ouvrir le menu
>    appelle une navigation de hub, donc l'encre coulée, qui met les entrées à
>    alpha 0 pour les rallumer ; pendant que M10 fait exactement la même chose sur
>    le conteneur qui les porte. **Deux effets qui animent des `modulate`
>    imbriqués sur les mêmes pixels ne se composent pas.** Chacun a désormais son
>    domaine : M10 la traversée arène ↔ menu, M6 la navigation à l'intérieur du
>    menu. L'encre ne coule que sur un **geste connu** — un `push()` appelé par du
>    code n'en produit pas. Corollaire utile : Échap et les gâchettes sont bien
>    des gestes, et l'interface leur donne un point de départ via
>    `MenuHub.noter_geste()`.
>
> Les deux premiers sont tenus par `test_vitrine_menus` comme des invariants et
> non comme des durées : « rien ne s'allume tant que l'arène se voit » et « aucune
> image d'écran entièrement noir ». Les durées pourront être retouchées sans
> rougir le banc ; ce qui faisait croire à un défaut ne peut plus revenir.
>
> **Le contrat que M10 a fallu inventer, et qu'aucune fiche n'avait vu.** Le
> panneau ne disparaît plus d'un coup : il se noie dans le noir avant que le
> rideau se lève, donc `visible` reste vrai six centièmes de seconde de plus. Or
> `is_pause_menu_open()` est lu par le jeu **pour empêcher le joueur d'agir**.
> Tel quel, l'effet aurait imposé un dixième de seconde d'inaction après chaque
> reprise — et en ligne, où le monde n'a jamais cessé de tourner, c'est une mort
> qu'on ne comprend pas. D'où `_extinction` : **un panneau qui s'éteint est déjà
> fermé pour tout ce qui décide quelque chose**, et `visible` n'est plus qu'une
> image. Tous les prédicats passent désormais par `_panneau_ouvert()`.
>
> Corollaire : **seules les quatre traversées arène ↔ menu s'animent.** Les
> bascules internes — la pause qui ouvre ses options, les options qui rendent la
> pause — restent sèches, et `force_close_pause()` aussi : la killcam ne peut pas
> attendre derrière un panneau qui s'efface.
>
> **M7 s'étend à l'adresse IP** (demandé par Adrien le 2026-08-18, en voyant le
> code gravé). C'est le même objet social : celui qu'on transmet à quelqu'un pour
> qu'il vienne jouer. Le graveur a donc deux mesures — **gabarit fixe** pour le
> code de salon, où six cases figées empêchent le bouton COPIER de se déplacer
> sous le doigt qui le vise ; **mesure libre** pour l'IP, dont la longueur n'est
> pas connue d'avance et dont un point logé dans une case de chiffre laisserait
> un trou. Seule l'adresse se grave : « VOTRE IP » reste un libellé, parce que
> ce n'est pas ce qu'on transmet.
>
> **Deux écarts assumés par rapport aux fiches ci-dessous**, notés parce qu'un
> lecteur de la fiche seule les prendrait pour des oublis :
> — M9 est dessiné en anneaux concentriques (`_draw`) et non par le shader décrit
> dans sa « Voie ». Dix cercles empilés à alpha décroissant donnent le même
> dégradé pour cinq centièmes d'alpha, sans uniforms à tenir d'accord avec la
> mise en page.
> — M8 : la fiche dit « ±32 px », qui est l'amplitude du **glissement** ; la
> traçante n'en prend que le **signe**. Sa course à elle est de 210 px, parce
> qu'une traînée de 32 px vivant 15 centièmes de seconde est invisible. C'est
> l'écran qui glisse de 32 px ; la balle, elle, s'en va.

Demandés par Adrien : « ultra-moderniser » les menus sans toucher à leur
structure — uniquement du visuel, pour un vanilla extrême. Produits par la
session « game feel » (cartographie du hub réel, trois angles de génération,
jury unique pour la cohérence d'ensemble), à IMPLÉMENTER PAR LA SESSION «
MENUS » : tout vit dans ui.gd et les screen_*.gd, son domaine. Classées du
rang 1 = le plus singulier et inédit au rang 15 = le plus classe et moderne —
un dégradé de singularité vers l'élégance, pas un ordre de qualité ni
d'implémentation. Contraintes communes : structure et navigation intactes, 100
% procédural, gl_compatibility, chaque effet enregistré dans effect_policy
(classe CONFORT, plancher 0.0 sauf mention), le noir reste noir.

- **M1 Le cadran de titre** —
  Derrière CANDELA 2D, une ombre portée du mot lui-même : copie noire
  cisaillée et écrasée, projetée par une flamme dorée hors champ dont un très
  léger dégradé chaud borde le flanc opposé du titre. L'angle de projection
  avance d'environ 6° par minute passée au menu — imperceptible en direct,
  flagrant au retour d'un match : le titre est un gnomon, le menu un cadran
  solaire. À l'écran de fin, VICTOIRE / DÉFAITE / ÉGALITÉ projette la sienne,
  telle quelle, dans ses couleurs propres.
  Pourquoi : L'idée la plus inédite du lot : personne n'a jamais fait d'un
  titre de menu une horloge d'ombre. Le temps devient une lumière qui tourne —
  récompense pure de l'attention (« tiens, l'ombre a bougé ») — et installe
  l'idée qu'un monde éclaire le menu depuis quelque part. Fonde aussi la
  fiction lumineuse commune : la flamme imaginaire qui projette cette ombre
  est celle qui fait rougeoyer le Titre incandescent (rang 11).
  Voie : Un Control nommé (OmbreTitre) inséré derrière le Label du titre dans
  _build_menu_header() (ui.gd:2110), redessiné à 1 Hz par un Timer — aucun
  _process : draw_set_transform (cisaillement + écrasement Y) puis draw_string
  du même texte, police par défaut, noir alpha ~0,5 ; angle = fonction du
  temps cumulé au menu. Hors flux : aucune incidence sur la mise en page (le
  clip à 60 px du sous-titre est intouché, l'ombre vit derrière). Dégradé «
  source » coupé sur l'écran calibration par prudence (rien de chaud près du
  champ noir). Intensité → alpha de l'ombre et du dégradé (0 = en-tête
  actuel). Ligne EffectPolicy `cadran_titre`, CONFORT, plancher 0.0 + phrase
  joueur — ScreenEffects et la persistance suivent seuls. Coût : un draw par
  seconde.
  Ressources : aucune (police par défaut, tout dessiné en code)
- **M2 La rémanence rétinienne** —
  Quand le liseré saute d'une entrée à l'autre, l'ancienne position garde son
  image rémanente : le même contour arrondi, mais dans la couleur
  complémentaire — le curseur cyan laisse un fantôme braise, le rouge de J2 un
  fantôme d'eau verte — qui s'élargit de 2-3 px en s'éteignant sur ~0,35 s.
  Exactement ce qu'une lumière vive imprime sur la rétine dans le noir : le
  négatif, pas la traînée. Curseur immobile = strictement rien à l'écran.
  Pourquoi : Chaque geste de navigation devient une trace physiologique : le
  joueur « sent » ses propres yeux travailler dans l'obscurité. Ce n'est pas
  un trail de particules (vu partout) : l'après-image négative n'a jamais été
  exploitée en menu et elle naît directement du thème. Donne envie de
  parcourir la liste juste pour voir le noir se souvenir. Fusion : préférée à
  la « rémanence de phosphore » (écho même-couleur = trail classique) ; la
  version négative est l'inédit.
  Voie : Un Control top-level nommé CoucheRemanence (même famille que
  NeonFocusRing, ui.gd:115), MOUSE_FILTER_IGNORE, tampon circulaire de 8
  entrées (rect, t0, couleur). _set_focus / _update_focus_rings (déjà en
  _process, ui.gd:543) y poussent l'ancienne position au changement de cible ;
  queue_redraw() uniquement tant que le tampon est non vide ; _draw() =
  draw_style_box bord-seul à alpha décroissant, complémentaire = Color(1-r,
  1-g, 1-b). Coût nul à l'arrêt, aucun nœud par entrée, aucun contact avec le
  résolveur (positions écran passées, jamais un contrôle vivant). Coupe-
  circuit sur l'écran calibration. Intensité → alpha crête et durée (0 =
  rien). Ligne `remanence_curseur`, CONFORT, plancher 0.0.
  Ressources : aucune
- **M3 Le regard du noir** —
  Après ~25 s sans aucun mouvement de curseur, quelque part dans les marges
  libres du backdrop — jamais sur un panneau, jamais près du champ de
  calibration — deux reflets minuscules apparaissent côte à côte : deux yeux
  qui accrochent une lumière lointaine. Montée en 0,4 s à peine au-dessus du
  seuil de perception, teinte P2 délavée, un clignement (60 ms d'extinction
  synchrone des deux points), puis disparition. Jamais deux fois au même
  endroit ; le moindre input les efface instantanément.
  Pourquoi : « L'obscurité qui regarde », littéralement : le menu au repos a
  un pouls, et l'adversaire existe déjà avant le match. Effet « je l'ai vu ou
  j'ai rêvé ? » qui rend le simple fait de laisser le menu ouvert légèrement
  électrique — on revient vérifier, on le montre à un ami. Purement visuel :
  honnête avec les sons UI encore absents, il n'attend aucun asset. Avec
  Quelqu'un derrière la vitre (rang 4), il peuple le noir sans jamais
  l'éclaircir.
  Voie : Timer d'inactivité réarmé par _set_focus et les inputs (déjà
  centralisés dans ui.gd) + un Control de dessin plein cadre nommé,
  MOUSE_FILTER_IGNORE : deux disques flous de 3 px (trois draw_circle
  concentriques en dégradé), alpha piloté par tween, queue_redraw uniquement
  pendant les ~2,5 s de vie, position tirée hors des rects connus des panneaux
  et du champ de calibration. Coût strictement nul le reste du temps — aucun
  _process ajouté. Intensité → alpha crête et fréquence (0 = jamais). Ligne
  `regard_du_noir`, CONFORT, plancher 0.0 garanti : confort pur, n'apprend
  rien, n'existe pas en match.
  Ressources : aucune
- **M4 Quelqu'un derrière la vitre** —
  Toutes les 25 à 45 s (aléatoire, jamais métronomique), une lueur floue et
  lente traverse l'écran DERRIÈRE les panneaux translucides (SURFACE à 0,92)
  et devant le backdrop — une torche portée par quelqu'un qui marche de
  l'autre côté d'un verre dépoli. Teinte à peine rougie (P2 à 6-8 % d'alpha),
  trajet oblique de 3-4 s, parallaxe naturel : étouffée sous les panneaux,
  révélée dans les gouttières entre colonnes. Rarement — une fois sur trois
  environ — un éclat bref accompagne le passage : montée de 90 ms, mort en 200
  ms, un coup de feu étouffé vu à travers le mur. Jamais deux fois le même
  trajet, jamais pendant la calibration.
  Pourquoi : Matérialise l'adversaire avant même le match : le noir du menu
  est habité. C'est le détail qu'on guette sans le vouloir. Donne enfin un
  sens visible à la translucidité de SURFACE, décision de thème jusqu'ici
  invisible — et le Verre fumé (rang 14) lui fournit sa vitre. Fusion : le «
  duel permanent » derrière la vitre est écarté (deux lueurs en mouvement
  continu concurrençaient la brume et la sobriété) ; son éclat de tir rare, le
  meilleur de l'idée, est conservé ici en événement.
  Voie : Un Control nommé inséré entre le backdrop et le MarginContainer
  (game_over_panel.add_child + move_child(…, 1) — ordre des enfants vérifié à
  ui.gd:1560-1568, structure intacte), MOUSE_FILTER_IGNORE. Il dessine UNE
  tache radiale (draw_texture d'une GradientTexture2D générée une fois en
  code), position pilotée par tween, queue_redraw seulement pendant le
  passage, Timer aléatoire le reste du temps : coût strictement nul au repos.
  L'éclat = seconde tache + court segment dans le même _draw, mêmes tweens.
  Pas besoin de Light2D : les panneaux translucides laissent transparaître
  d'eux-mêmes. Intensité → alpha crête et fréquence (0 = jamais). Ligne
  `passant_vitre`, CONFORT, plancher 0.0, phrase type « Une lueur peut parfois
  passer derrière les panneaux du menu ».
  Ressources : aucune (tache générée en code)
- **M5 Le bruit de l'œil** —
  À la frontière exacte entre halo et noir — l'anneau de pénombre autour de la
  torche du curseur et le long des bords éclairés des panneaux — une
  granulation animée quasi subliminale fourmille, comme le bruit rétinien d'un
  œil qui force dans l'obscurité. Nulle part ailleurs : ni dans la lumière
  pleine, ni dans le noir profond. Amplitude 2-3 % de luminance, scintillement
  quantifié à ~12 Hz (pas à chaque frame rendue) pour rester organique et
  jamais « vidéo ». Aucune scanline, aucune bande : vocabulaire volontairement
  distinct du grain VHS de la killcam.
  Pourquoi : Fait exister le noir comme matière — le noir « travaille » — sans
  jamais gêner la lecture. En duo avec la torche du curseur (rang 9), le
  joueur croit voir son propre œil s'adapter : sensation physiologique inédite
  en menu. Complémentaire du Voile d'objectif (rang 15) sans doublon : le
  voile est un grain de pellicule global et statique, le bruit de l'œil est
  localisé et vit uniquement à la lisière de la lumière.
  Voie : UN canvas_item shader nouveau à la racine, préchargé en const (règle
  absolue du dépôt), posé sur le ColorRect backdrop existant (ui.gd:1560) :
  hash noise procédural masqué par deux smoothstep en anneau autour d'uniforms
  centre/rayon poussés par _update_focus_rings (déjà en _process), temps
  quantifié dans le shader, uniform d'intensité lu de current_effect. Fragment
  trivial (une hash, deux smoothstep) : négligeable pour la cible 1 % bas ≥
  60 fps, gl_compatibility sans réserve. Peut partager son quad et ses
  uniforms avec la Brume d'abysse (rang 12) — un seul shader de backdrop pour
  les deux. À 0, rend le backdrop actuel à l'identique ; coupé net sur l'écran
  calibration. Ligne `bruit_de_l_oeil`, CONFORT, plancher 0.0.
  Ressources : aucune (un .gdshader nouveau à la racine — du code, pas
  d'asset)
- **M6 L'encre coulée** —
  Au push, le nouvel écran ne fait pas qu'arriver : il s'imprime. Depuis la
  hauteur exacte de l'entrée que vous venez d'activer, un ménisque lumineux —
  trait horizontal de 2 px, cœur blanc, franges à l'accent de l'écran — balaie
  la colonne entrante en 0,22 s ; devant lui les entrées sont encore éteintes
  (modulate.a 0), à son passage chacune s'allume avec ~60 ms de surbrillance
  avant de retomber à sa valeur, le chevron accent s'embrasant un souffle
  après sa rangée. Au back(), le trait part de l'entrée RETOUR et remonte.
  Cascade totale terminée avant que le pouce puisse agir. La lumière de votre
  geste coule littéralement dans l'écran suivant.
  Pourquoi : Rien n'« apparaît » : tout s'écrit, comme si la lumière était
  l'encre du menu. La continuité geste → écran rend la navigation charnelle,
  et l'œil lit la liste dans l'ordre où le jeu l'éclaire. C'est le stagger AAA
  raconté par le thème, pas un générique. Fusion des trois idées d'apparition
  des entrées : le trait directionnel de l'encre + l'allumage échelonné de la
  cascade ; le scale TRANS_BACK écarté (l'allumage doit rester de la lumière,
  pas du mouvement).
  Voie : Se greffe sur MenuHub._slide (menu_hub.gd:287) sans le remplacer : le
  même tween parallèle (même garde de kill) anime (a) un Control overlay
  nommé, clippé dans _host, MOUSE_FILTER_IGNORE, qui dessine le trait en
  _draw() (queue_redraw piloté par la progression du tween), (b) les
  modulate.a des enfants directs de la racine entrante, échelonnés selon leur
  position.y par rapport au front. modulate uniquement — jamais
  visible/disabled : les contrôles restent dans le parcours du résolveur dès
  la première frame, le curseur est de toute façon ressemé au changement
  d'écran. Point de départ = position du dernier bouton activé, connue de
  _set_focus. reset() reste sec. Actif 0,22 s puis inerte, aucun nœud par
  entrée. Intensité → longueur du trait et amplitude de surbrillance (0 =
  slide actuel inchangé). Ligne `encre_coulee`, CONFORT, plancher 0.0.
  Ressources : aucune
- **M7 Le code gravé par impacts** —
  Le code de salon à 6 caractères ne s'imprime pas : il se frappe. Chaque
  caractère apparaît en blanc incandescent puis refroidit vers l'or en 0,5 s,
  décalé de 70 ms (séquence totale < 1 s), avec une secousse d'1 px vers le
  bas et 2-3 étincelles minuscules qui chutent et meurent en 0,3 s au point
  d'impact — six balles qui gravent le code dans le mur. Même traitement pour
  le code de récupération du profil (GOLD 34).
  Pourquoi : Le code de salon est l'objet social du jeu — celui qu'on lit à
  voix haute à un ami — et il apparaît aujourd'hui sans cérémonie
  (ui.gd:2519). Le graver par impacts en fait un petit événement mémorable à
  chaque création de salon, dans le langage exact du monde (l'impact qui
  marque la matière, le métal qui refroidit), et le refroidissement blanc → or
  atterrit précisément sur la sémantique « or = à lire » du thème.
  Voie : lobby_code_label (ui.gd:2354, mis à jour ligne 2516) devient un HBox
  de 6 Labels nommés CodeChar0..5 à custom_minimum_size fixe — le gabarit
  occupe exactement la place du code (y compris l'état « — — — — — — »),
  stabilité de mise en page préservée, bouton copier inchangé. Animation
  déclenchée seulement quand la chaîne change (dernière valeur mémorisée :
  refresh idempotent, aucun rejeu au repeint). Étincelles via un Control _draw
  poolé, one-shot tween ; ni shader ni _process. Labels FOCUS_NONE, hors
  parcours curseur, jamais de liseré. Ligne `gravure_code`, CONFORT, plancher
  0.0 (0 = affichage instantané).
  Ressources : aucune
- **M8 Le départ au tir** —
  Presser une entrée launcher (style plein — le geste qui engage une partie)
  tire réellement : étoile de bouche blanche de 2 frames au chevron, puis une
  balle traçante — cœur blanc 1 px sur un fût large basse-alpha teinté accent,
  faux HDR — file dans le sens exact du _slide entrant (±32 px) et s'éteint en
  0,15 s. L'écran suivant semble tracté par la balle. Les push ordinaires
  gardent leur seul _pulse_press : l'effet est réservé au geste qui engage.
  Pourquoi : Réservé au launcher, l'effet sacralise l'instant décisif : JOUER
  n'est pas un clic, c'est un coup de feu — le vocabulaire du duel (flash de
  bouche, traçante) réutilisé tel quel là où le joueur s'engage. Le lien
  visuel balle → glissement d'écran donne à la navigation une causalité
  physique addictive : chaque partie lancée commence par la sensation du tir.
  Se marie naturellement avec L'encre coulée (rang 6) : la traçante devient
  l'encre du prochain écran.
  Voie : Un Control top-level poolé nommé MenuTracer avec _draw (ou deux
  Line2D préconstruits), réutilisé à chaque tir — zéro allocation, zéro coût
  au repos, one-shot tween. Câblage au même point que _pulse_press
  (_wire_buttons, ui.gd:393-405) filtré par une métadonnée launcher (le style
  plein la distingue déjà) ; le sens vient du push en cours du hub. Aucune
  modification de _slide, de la pile ou du résolveur. Le faux HDR par
  superposition de traits est la technique déjà imposée au laser du jeu,
  gl_compatibility garanti. Ligne `depart_au_tir`, CONFORT, plancher 0.0.
  Ressources : aucune
- **M9 La torche du curseur** —
  Le liseré J1 cesse d'être un simple cadre : il porte une flaque de lumière
  cyan (~250 px, dégradé radial doux, additif, alpha crête ~0,05) qui suit le
  curseur avec le lerp exponentiel déjà en place, en traînant de quelques
  pixels — une lampe portée à la main. Le backdrop et les filets reposent dans
  une pénombre légère — jamais sous ~45 % de luminance : tout reste lisible,
  le noir reste noir ; l'entrée focalisée est pleinement éclairée, ses
  voisines reçoivent une retombée décroissante, le bord du panneau droit
  accroche une lumière rasante. À chaque activation, la lueur palpite une fois
  (+60 % d'intensité, retombée en 0,18 s). Micro-vacillement de flamme
  optionnel (±3 %, bruit lent). Le ring P2 porte la même torche rouge sur son
  râtelier en écran partagé ; là où les deux halos se croisent, l'additif
  blanchit naturellement.
  Pourquoi : C'est LE geste diégétique fondateur et la clé de voûte du système
  : dans un jeu où la lumière est la seule information, le curseur devient une
  torche — regarder le menu, c'est déjà jouer. La retombée sur les voisines
  donne gratuitement une hiérarchie magnétique, et la palpitation d'appui
  donne à chaque geste une conséquence lumineuse — précieux tant que les sons
  UI manquent. Le Bruit de l'œil (rang 5) et la Rémanence (rang 2)
  s'accrochent à sa géométrie. Fusion des trois variantes curseur-lampe :
  concept de la torche, implémentation shader de la lueur.
  Voie : Un ColorRect « CursorGlow » plein cadre, MOUSE_FILTER_IGNORE, dernier
  enfant de game_over_panel et de pause_panel, shader canvas_item préchargé en
  const avec uniforms p1_pos/p1_strength/p2_pos/p2_strength + profondeur de
  pénombre — surtout PAS de Light2D + occluders + CanvasModulate sur des
  Controls (version écartée : occluders à resynchroniser sur un layout
  redimensionnable, fragile, pour un rendu équivalent). Alimenté depuis
  _update_focus_rings (ui.gd:543, les rects des rings y sont déjà calculés :
  centre = global_position + size/2) — aucun _process nouveau ; palpitation :
  _pulse_press pousse l'uniform à 1, le shader le fait décroître. Garde-fou :
  uniforms forcés à 0 sur l'écran calibration via _on_hub_screen_changed —
  rien de clair ne borde le champ noir de mesure. À 0 = menu actuel pixel pour
  pixel. Un quad, dégradés en ALU : coût nul. Ligne `torche_menu`, CONFORT,
  plancher 0.0.
  Ressources : aucune
- **M10 L'extinction des feux** —
  Le menu et la pause ne s'affichent plus : le monde s'éteint, puis le menu se
  rallume. Ouverture : la vue du jeu s'éteint, un battement d'obscurité vraie
  de 0,05 s, puis le rideau de nuit tombe (backdrop alpha 0 → 0,96 en 0,12 s)
  pendant que les panneaux, d'abord pures silhouettes noires (modulate noir),
  se rallument en cascade haut → bas sur 0,18 s, le titre or reprenant vie en
  dernier avec une frame de blanc. Fermeture : l'inverse en 0,10 s — les
  surfaces se noient dans le noir PUIS le rideau se lève sur l'arène. Aucun
  mouvement, aucune échelle : uniquement de la lumière qui meurt et qui
  renaît. La pause prend la variante courte dans les deux sens.
  Pourquoi : Ouvrir le menu est le geste le plus répété du jeu, et c'est
  aujourd'hui un show/hide sec (terrain libre documenté). Entrer au menu =
  éteindre sa torche, en sortir = la rallumer : le battement de noir absolu
  entre deux mondes rappelle le contrat à chaque traversée, sans un pixel de
  déplacement (zéro vertige, zéro gêne manette). Fusion des trois variantes de
  transition : le battement de noir de l'iris conservé, l'iris radial et la
  ligne balayante écartés au profit du tout-tween, plus sûr et plus « lumière
  pure ».
  Voie : Pur tween dans les chemins show/hide de game_over_panel et
  pause_panel : une fonction unique anime le color.a du backdrop (ui.gd:1560 /
  2604) et le modulate des enfants de Color(0,0,0) vers WHITE, TRANS_CUBIC,
  échelonné par position Y ; hide() réel différé à la fin du tween de
  fermeture (0,10 s, sous le seuil d'agacement) EN DÉ-PAUSANT L'ARBRE
  IMMÉDIATEMENT : seul le visuel s'éteint, la reprise du gameplay ne perd
  jamais un battement. Idempotent : kill du tween précédent (patron _slide
  déjà en place). Aucun nœud nouveau, aucun shader ; les contrôles gardent
  taille, position et visibilité (seule la couleur anime : rien ne disparaît
  sous le curseur), curseurs ressemés après comme aujourd'hui. À 0 : show/hide
  secs actuels. Ligne `extinction_menu`, CONFORT, plancher 0.0.
  Ressources : aucune
- **M11 Le titre incandescent** —
  CANDELA 2D cesse d'être un aplat or. En continu, une onde de luminance
  traverse les lettres de gauche à droite (période ~5 s, ±8 % autour de GOLD,
  légèrement plus chaud à la crête) — des braises sous un courant d'air ;
  aucun glyphe ne bouge, luminance seule. À l'ouverture du menu, le titre
  s'embrase : d'un ambre presque noir au plein or en 0,35 s, la vague partant
  du C et atteignant « 2D » en dernier, avec un halo en dépassement (alpha
  0,25 retombant en 0,4 s). À l'écran de fin, le même shader porte la
  température du verdict : la victoire flambe une fois vers le blanc-vert, la
  défaite voit son onde mourir en braise basse (amplitude divisée par deux).
  Pourquoi : Le titre est le premier pixel lu à chaque session et après chaque
  match ; la typographie cinétique le rend vivant et premium en racontant le
  jeu : une lumière qui brûle tant que ça joue. La température du verdict
  signe l'écran de fin sans toucher un layout. Cohérent avec le Cadran (rang
  1) : la même flamme imaginaire fait rougeoyer les lettres devant et projette
  l'ombre derrière. Fusion : l'embrasement d'ouverture remplace le vacillement
  du néon, écarté (clignotements irréguliers = risque photosensibilité, et
  métaphore « tube » concurrente de la braise).
  Voie : Un ShaderMaterial préchargé en const posé sur le Label du titre dans
  _build_menu_header() (ui.gd:2110). Subtilité exacte : sur un Label, UV
  couvre chaque glyphe dans l'atlas, pas le bloc — la phase horizontale se
  prend sur VERTEX.x (espace local, en pixels) normalisé par un uniform de
  largeur posé au resize. 100 % ALU, pas de screen_texture, gl_compatibility
  garanti. Le halo d'embrasement : un second Label fantôme derrière, même
  texte, modulate tweené — l'idiome des ombres chromatiques du titre killcam,
  déjà au dépôt. Luminance seule : la boîte clippée à 60 px sous le titre est
  respectée. Coût : un label et quelques ALU. Ligne `titre_vivant`, CONFORT,
  plancher 0.0.
  Ressources : aucune
- **M12 La brume d'abysse** —
  Derrière le hub, l'aplat BACKDROP devient une pénombre vivante : deux nappes
  de brouillard procédural (value noise, 2 octaves) dérivant en sens opposés à
  ~0,008 et 0,013 UV/s, luminance tenue entre 0,010 et 0,035 — jamais plus :
  le noir reste noir. Un halo radial décentré vers le haut respire sur ~9 s
  (±2 %) — une torche lointaine derrière un verre dépoli ; un biais cyan quasi
  subliminal à gauche, rouge à droite (alpha ~0,02) : les territoires P1/P2.
  L'ensemble glisse de 3-4 px à l'opposé du curseur J1, amorti sur ~1,5 s : la
  plaque du menu flotte devant un monde profond — parallaxe au stick, donc
  manette d'abord.
  Pourquoi : La première seconde du menu enseigne déjà la grammaire du jeu :
  le noir est habité, la lumière est une présence. L'intention actée du
  BACKDROP (« sentir un monde derrière ») devient littérale, et la parallaxe
  fait répondre tout l'écran au moindre geste — la réponse tactile permanente
  qui rend un menu magnétique. Sous 4 % de luminance, le contraste du texte
  est intact. C'est le sol du système : le décor dans lequel marche le passant
  (rang 4) et que floute le verre (rang 14).
  Voie : Un ShaderMaterial préchargé en const posé sur le ColorRect backdrop
  existant (ui.gd:1560, copie pause à 2604). Shader canvas_item 100 % ALU
  (hash noise, zéro fetch texture), animé par TIME : un quad plein écran, coût
  négligeable ; panneau caché = non dessiné = zéro coût en match. La parallaxe
  est un uniform vec2 alimenté depuis _update_focus_rings() (déjà en _process
  permanent) : aucun nouveau _process, aucun repeint GDScript. Peut fusionner
  dans le même shader que le Bruit de l'œil (rang 5) — un seul matériau de
  backdrop pour les deux. Forcé neutre sur l'écran calibration. Structure et
  navigation intactes. Ligne `brume_menu`, CONFORT, plancher 0.0 (l'intensité
  module brume + respiration + parallaxe ; 0 = l'aplat statique actuel).
  Ressources : aucune
- **M13 Les squelettes de lumière** —
  Pendant que le classement, le rang du profil ou la fourchette du matchmaking
  attendent le réseau : pas de texte figé ni de spinner. Les dix lignes pré-
  construites montrent des barres fantômes sombres (teinte LINE, coins 3 px) à
  l'emplacement exact du rang, du pseudo et de l'ELO, et une bande de lumière
  douce (~120 px, alpha 0,06, inclinée à 20°) balaie toutes les lignes en
  phase, un passage toutes les 1,1 s — une torche qui fouille des étagères
  dans le noir. À l'arrivée des données, chaque barre se fond dans son texte
  en 0,12 s, première ligne d'abord, 30 ms d'écart ; ma ligne s'allume en P1
  en dernier — la petite récompense. En échec : le balayage s'arrête, les
  barres se posent en DIM statique — l'absence n'est pas une panne.
  Pourquoi : L'attente réseau est l'endroit où les menus bon marché meurent
  (texte gelé) et où se joue la rétention des écrans classés. Le skeleton
  shimmer, signe lu « premium et vivant », est ici diégétique — chercher un
  adversaire ou un classement, c'est promener une lumière dans le noir — et il
  respecte à la lettre la sémantique DIM du dépôt (« non configuré » ne
  ressemble pas à une panne).
  Voie : Le terrain est prêt : screen_leaderboard.gd crée ses lignes une fois
  et les remplit (_rows:124, _fill_row:553, refresh:342 idempotent).
  Squelettes = ColorRects pré-créés dans chaque ligne, montrés/cachés par
  refresh() — aucune reconstruction, le motif signature d'état du dépôt.
  Balayage : UN ShaderMaterial partagé préchargé en const, phase par TIME +
  uniform de rangée — tout côté GPU, zéro repeint GDScript par seconde. Fondus
  : tweens modulate courts. Même matériau réutilisable dans le panneau `salon`
  et le MatchBanner pour la fourchette en attente. Curseur : squelettes
  MOUSE_FILTER_IGNORE / FOCUS_NONE, jamais dans le parcours ; les vraies
  lignes ne disparaissent jamais sous le liseré. Dégradé ALU, gl_compatibility
  OK. Ligne `balayage_attente`, CONFORT, plancher 0.0 (0 = barres statiques).
  Ressources : aucune
- **M14 Le verre fumé** —
  Le panneau de droite et les rangées de réglage passent de l'aplat peint au
  verre fumé : un filet lumineux interne de 1 px le long du bord haut (blanc
  alpha 0,05), une luisance verticale (+3 % de luminance en haut, éteinte à 30
  % de hauteur), et une strie spéculaire diagonale à 12°, alpha 0,02, qui
  dérive de 20 px sur ~12 s. Au focus d'une rangée, le bord P1 existant gagne
  une lueur interne de 6 px (alpha 0,10) : l'arête du verre qui accroche la
  torche du curseur. En option de luxe : derrière le seul panneau de droite,
  la brume d'abysse apparaît FLOUE (gaussien 9 taps via screen_texture),
  densifiée — le panneau flotte visiblement DANS le brouillard.
  Pourquoi : Le glassmorphism sombre est LE langage matière 2025-2026, et il
  est ici diégétique : les surfaces deviennent des vitres que le noir traverse
  — c'est aussi lui qui donne sa vitre au passant du rang 4. Le menu se met à
  « coûter cher » à l'œil parce que la matière a changé, pas la décoration :
  de la profondeur sans surcharge, le noir intact.
  Voie : Deux étages. Étage sûr (défaut) : impossible en StyleBox, donc un
  ShaderMaterial préchargé sur le PanelContainer de droite et sur les
  PanelContainer de rangée (_row_style de ScreenEffects/ScreenAudio) — le
  matériau d'un Control s'applique à son propre dessin (la stylebox) et ne
  s'hérite pas aux enfants : le texte reste net. Sheen + filet + strie en ALU
  pur : coût nul, gl_compatibility OK. Étage flou réel : hint_screen_texture
  est éprouvé au dépôt sous gl_compatibility (killcam_overlay.gdshader:3) ;
  une copie d'écran + 9 taps sur ~500×600 px, réservé au SEUL panneau de
  droite, à valider au bench_framerate (cible 1 % bas ≥ 60 fps) avant d'être
  gardé. Styles et nœuds existants, structure intacte. Ligne `verre_panneaux`,
  CONFORT, plancher 0.0 (0 = aplats actuels).
  Ressources : aucune
- **M15 Le voile d'objectif** —
  Une unique passe de finition plein écran, menus seulement : (a) grain de
  film monochrome fin, 1 px, 1,5-2 % de luminance, retiré à chaque frame — la
  recette du killcam mais trois fois plus fin, sans scanlines ni glitch : du
  cinéma, pas de la VHS ; (b) frange chromatique confinée aux 12 % extérieurs
  du cadre — R et B s'écartent jusqu'à 1,5 px pile dans les coins, zéro au
  centre : un bel objectif, pas une panne ; (c) vignette optique douce, −6 %
  de luminance dans les angles, respirant de ±1 % sur 7 s. Ensemble : le menu
  semble filmé en basse lumière par une très bonne optique.
  Pourquoi : C'est le 10 % invisible qui sépare l'UI plate propre de l'image
  AAA : le cadre gagne une texture photographique, le noir devient un noir de
  film et non un #000 vide. Bonus concret : le grain dissout le banding des
  dégradés sombres (artefact réel du 8 bits sous gl_compatibility, que la
  brume du rang 12 révélerait) — du polish qui est aussi un correctif.
  Vocabulaire optique statique, distinct du glitch killcam et du bruit
  localisé du rang 5 : c'est la couche de finition qui scelle tout le système.
  Voie : Un ColorRect « MenuVeil » plein cadre, dernier enfant côté menu et
  pause, MOUSE_FILTER_IGNORE, shader préchargé en const. Frange : 3 lectures
  hint_screen_texture pondérées par la distance au centre — l'idiome exact du
  killcam, prouvé sous gl_compatibility ; grain et vignette en ALU. Un quad, 3
  taps : très en deçà du budget 1 % bas ≥ 60 fps. Garde-fou impératif : le
  voile s'éteint sur l'écran calibration via screen_changed — du bruit de
  luminance sur le champ noir fausserait la mesure de tous les joueurs du même
  côté. Caché en match : zéro coût. Structure intacte. Ligne `voile_menu`,
  CONFORT, plancher 0.0 (l'intensité module grain, frange et vignette
  ensemble).
  Ressources : aucune (un .gdshader nouveau à la racine)

Écartées par le jury (raison en une ligne) :

- La torche du regard — fusionnée dans La torche du curseur (rang 9) : ses
  vraies ombres portées (Light2D + LightOccluder2D + CanvasModulate) exigent
  de resynchroniser des occluders sur un layout de Controls redimensionnable —
  fragile et sur-ingénieré pour un rendu équivalent au shader.
- La lueur du curseur — doublon du concept curseur-lampe ; c'est son
  implémentation (shader + uniforms poussés par _update_focus_rings, la voie
  la plus sûre) et sa palpitation d'appui qui sont reprises dans la fiche
  fusionnée du rang 9.
- Rémanence de phosphore — doublon de trace de curseur : l'écho même-couleur
  est un trail déjà vu partout ; l'après-image négative complémentaire (rang
  2) est la version réellement inédite.
- Balayage d'allumage — doublon d'apparition des entrées au changement
  d'écran, absorbé par L'encre coulée (rang 6) qui y ajoute le point de départ
  au geste et la direction push/back.
- Allumage en cascade — troisième variante du même stagger ; son échelonnement
  de modulate survit dans L'encre coulée, son scale TRANS_BACK est écarté
  (l'allumage doit rester de la lumière, jamais du mouvement).
- Extinction de torche — fusionnée dans L'extinction des feux (rang 10) : son
  battement de noir absolu est conservé, son iris radial (shader de masque +
  hide différé) cède au tout-tween d'alpha/modulate, plus sûr et sans shader.
- Rideau de lumière — troisième variante d'ouverture/fermeture ; sa ligne
  balayante additive mordait sur le vocabulaire du trait de L'encre coulée, et
  le fondu de luminance de la fiche retenue rend le même service.
- Le duel derrière la vitre — deux lueurs en mouvement permanent derrière le
  backdrop concurrençaient la brume d'abysse et la sobriété du noir ; son
  meilleur moment — l'éclat de tir rare et étouffé — est conservé dans
  Quelqu'un derrière la vitre (rang 4).
- Amorçage du néon — le vacillement irrégulier à l'ouverture cumule un risque
  de photosensibilité et une métaphore « tube électrique » concurrente de la
  braise ; sa fonction (un titre qui s'allume) est reprise par l'embrasement
  du Titre incandescent (rang 11).

### Items D — arbitrés par Adrien le 2026-08-17

- **D1 Empreintes éphémères** — traces de pas ~2 s visibles seulement sous une
  lumière : le noir garde une mémoire courte, la traque devient pistage. Info
  nouvelle mais symétrique — la plus forte idée « mécanique » de la liste. —
  *assets : 2-3 sprites (ou procédural).* **→ Activé, en procédural.**
  **✅ Fait** — `footprint.gd`, semelle sombre éclairée (jamais unshaded :
  seule une lumière la révèle), duplicata par viewport comme le sang, TTL
  2 s dont la fraîcheur se lit à l'alpha. Au passage, le PAS lui-même (son +
  empreinte) est passé sur la distance réellement parcourue, hors du bloc de
  simulation : l'ancien code rendait les pas de l'adversaire inaudibles côté
  client — asymétrie d'information préexistante, corrigée.
- **D2 Bourdon d'aveuglement** — la nappe monte quand on n'a pas VU
  l'adversaire depuis X s (aucune info : c'est sa propre ignorance qui sonne).
  **→ Acté sur le principe ; attend les stems réels (V1.1).**
- **D3 Extinction traînée** — la torche s'éteint en ~80 ms au lieu d'un coupé
  sec : ~80 ms d'info en plus pour l'adversaire. **→ Activé.** **✅ Fait** —
  `TORCH_FADE_OUT` dans player.gd, symétrique sur la torche répliquée.
- **D4 Grésillement positionnel de torche** — audible à très courte portée par
  l'adversaire. Cohérent avec « courir rend bruyant », mais info nouvelle. —
  *assets : 1 boucle.* **→ Acté sur le principe ; attend son asset.**
- **D5 Onde de choc du pompe** — distorsion BackBufferCopy : à mesurer sur
  `bench_framerate` avant d'acter (1 % bas ≥ 60). **→ À implémenter derrière
  un drapeau debug ; activation définitive après mesure sur le Mac d'Adrien.**
  **✅ Implémenté** (`pump_shockwave.gd` + `.gdshader`, drapeau
  `--fx-shockwave`). À mesurer : 1 % bas en duel pompe contre pompe, drapeau
  actif vs inactif — la recopie plein viewport ×2 est le coût dominant ; repli
  identifié si la mesure échoue (COPY_MODE_RECT borné au quad, ÷15 de volume
  copié).
- **D6 L'appel du vide** — cercle discret de 10 s autour de REJOUER, sans
  auto-start. **→ Acté ; vit dans le hub, donc à implémenter par la session
  « menus » (Phase 5).**
- **D7 Sang persistant entre matchs d'une session** — l'arène raconte la
  soirée (exige le plafond de taches déjà relevé comme fragilité).
  **→ Activé : plafond de taches d'abord, persistance ensuite.**
  **✅ Fait** — l'enquête a montré que la persistance existait déjà (seul le
  retour menu purge l'arène) : seul le plafond manquait. `MAX_STAINS = 120`,
  éviction de la doyenne avant tout dépôt, robuste aux volées de pompe
  (retrait de groupe immédiat, `queue_free` différé).

### Ressources à fournir (liste de courses consolidée)

| Type | Contenu | Volume |
|---|---|---|
| Musique (V1.1, stingers) | 3 clips + 3 stems 170 BPM, 4 stingers accordés | ~10 .ogg |
| Voix annonceur (V1.3) | fight, victoires, égalité + parfait, de justesse | 4-8 .wav |
| ~~Sons d'armes (V4.1)~~ | **livré** — 4 variantes par arme, tirées au sort | 16 samples |
| Foley | pas ×2, douilles, ricochets, frôlements, ambiances, torche | ~25 samples |
| UI / récit | frappes, ping prêt, pion, impacts typo, tic-tac, verre, rewind | ~10 samples |
| Corps | souffles blessé, acouphènes | ~8 samples |
| Visuel | quasi rien (procédural) — éventuellement 1-2 fontes, sprites D1, logo | 0-6 fichiers |

---

## Chantier direction artistique — sortir du look « généré » (inscrit le 2026-08-19)

> **Le constat d'Adrien, à l'origine du chantier :** le jeu manque d'une
> apparence pro et aboutie — « ça fait généré par IA ». Le diagnostic posé :
> ce n'est pas le procédural en soi qui est coupable (Downwell, Teleglitch,
> Ape Out sont massivement procéduraux et paraissent signés), c'est le
> **procédural par défaut** — fonte Godot, couleurs primaires codées en dur,
> dégradés radiaux mathématiquement parfaits, losanges de particules, easings
> standard. Chaque valeur par défaut visible dit « personne n'a choisi ça ».
> Un jeu paraît pro quand chaque pixel semble décidé. La ligne « Visuel :
> quasi rien » de la table des ressources ci-dessus décrivait l'état d'esprit
> d'avant ce chantier ; c'est précisément lui qu'Adrien a relevé.
>
> **Deux stratégies compatibles, menées de front :** rendre le procédural
> *signé* (DA1, DA5 — faisable par les sessions, sans asset) et mettre de
> l'autoral là où l'œil juge (DA2, DA3 — passe par Adrien et un artiste).
> Candela n'a qu'un sujet visuel, la lumière : quelques ancres bien placées
> (faisceau, personnage, titre) retournent la perception de tout le reste.
>
> **Ordre = priorité décroissante**, et le haut conditionne le bas : repeindre
> avant d'avoir une palette, c'est repeindre deux fois. DA1.5 (le choix d'un
> artiste unique) et DA5.6 (la résolution assumée) se tranchent **avant** la
> première commande. Marquage : *(S)* = sessions seules, sans asset ·
> *(G)* = gratuit, à sourcer par Adrien (fontes OFL, textures CC0) ·
> *(C)* = commande artiste / sound designer. **Tout est « proposé » : aucun
> item n'est commencé sans demande d'Adrien.**

### DA1 — Le socle ✅ **LIVRÉ le 2026-08-24** (DA1.1, 1.2, 1.3, 1.4, 1.8, 1.9)

> **Sept items sur neuf sont faits** — DA1.5 s'est tranché le 2026-08-24.
> Restent DA1.6 (le wordmark) et DA1.7 (icône et splash), les deux qui demandent
> un dessin. Tout ce qui était marqué *(S)* et *(G)* est livré.
>
> Tout descend maintenant de **`charte.gd`**, et de lui seul.

#### Ce que la révision a appris, et qui ne se devinait pas

**La première palette proposée était une palette assainie, pas une palette.**
Elle corrigeait des défauts — saturations à 100 %, blanc pur, rouges primaires —
et ne racontait rien. C'est Adrien qui l'a relevé en donnant le récit :
« un lieu industriel dans le noir, militaire, ambiance tactique, vision à la
lampe torche, LED ». Refaite **depuis** ce récit, elle a produit un principe que
l'hygiène seule n'aurait jamais donné :

> **Deux familles de lumière, et elles ne se mélangent pas.** Le MONDE est chaud
> — halogène, feu, sang : ce que la torche révèle. L'APPAREIL est LED — froid,
> étroit : ce que le matériel émet. *Si c'est chaud, c'est le monde ; si c'est
> LED, c'est toi.*

**Le vert est la seule couleur ajoutée, et il paie une confusion qui existait.**
Le code écrivait `GOLD if success else WARN` : deux orangés voisins portant des
sens **opposés**, lus à 12 px dans le noir. La triade d'instrument — vert « prêt »,
ambre « attention », rouge « faute » — les sépare. Ce n'est pas une préférence,
c'est un défaut de lisibilité qui avait un nom nulle part.

**Le bleu et le rouge des joueurs : le récit ne demandait pas d'en changer, il
explique pourquoi ils étaient justes.** *Blue force* contre *red force*, la
convention de tout affichage tactique — c'est-à-dire, mot pour mot, la décision
actée du 2026-08-19 (« la couleur suit le RÔLE, pas le numéro »). Seule la
saturation a bougé, de 100 % à ~70 %.

**`ACIER` traite la cause d'un défaut déjà corrigé en surface.** Le 2026-08-18,
les entrées « lanceur » se confondaient avec le liseré de sélection ; on avait
retiré la couleur des lanceurs. La cause restait : **l'interface n'avait pas de
couleur à elle et empruntait celle d'un joueur.** Elle en a une.

**Pas de kaki, et c'est délibéré.** Dans un jeu où l'on ne voit jamais le décor
autrement qu'en arête éclairée, une couleur de camouflage est une couleur qu'on
n'affiche jamais. Le militaire passe par la triade et la convention ami/ennemi.

#### La discipline : littéral + formule + banc

Les sept couleurs sont choisies ; **tout le reste est une opération sur elles** —
`CARMIN = ROUGE × 0,58`, `DIM = ACIER × 0,70`, les fonds et les sols sont le noir
monté vers l'acier. GDScript ne sachant pas appeler `lerp()` dans une constante,
les dérivées sont écrites en littéral et **`tools/test_charte.gd` recalcule
chacune à chaque exécution**. C'est le motif de `Protocol.WIRE_WITNESS` appliqué
à la couleur : la valeur ne peut pas s'éloigner de sa formule en silence.

**Une règle est devenue mécaniquement vérifiable : le vert n'entre jamais dans
l'arène.** Le banc lit le TEXTE des treize fichiers du monde et refuse toute
couleur verte qui s'y trouverait — pas les valeurs exportées, le texte, parce que
c'est ainsi que le défaut arriverait : quelqu'un écrit un `Color(...)` à la main
dans une particule. Corollaire utile : un pixel vert dans une capture est
toujours de l'interface.

**Et un contrôle qui protège le jeu, pas l'œil.** `ADVERSAIRE` — la couleur à
laquelle on voit quelqu'un dans le noir — a changé de température sans changer de
**luminance**, et le banc compare les deux. Le coefficient n'est pas choisi, il
est résolu. ⚠️ **Le premier jet affirmait cette égalité dans son propre
commentaire ; elle était fausse de 8 %.** Le gris neutre part d'une luminance de
1,0, l'halogène de 0,917. C'est le calcul qui l'a dit, pas la relecture.

#### Les fontes : la mesure a changé le choix

**Display : `Big Shoulders Display`** (signalétique industrielle ultra-condensée,
axe variable Thin→Black). **Interface : `Oxanium`** (linéale anguleuse à
chanfreins, variable). Les deux en SIL OFL 1.1, licences versionnées à côté.

Le premier candidat d'interface était *Chakra Petch*, qui portait le récit aussi
bien. **Il a été écarté par une mesure, pas par goût** : ses chiffres ne sont pas
tabulaires — `0` fait 12 px, `1` en fait 6,9 —, donc un chrono qui saute à chaque
seconde. Oxanium est tabulaire **par construction** : les dix chiffres font 11 px
pile, sans réglage à poser. *Une propriété qui n'a pas d'interrupteur ne peut pas
être éteinte par mégarde.*

Au passage, le dernier faux gras du dépôt disparaît : `menu_hub.gd` posait
`variation_embolden = 1.2` avec ce commentaire — « le projet n'a pas de police à
poids multiples ». Il en a deux, à axe variable.

#### L'échelle, et ce qu'elle a révélé

Six tailles (12 / 15 / 19 / 25 / 42 / 68) remplacent **vingt-cinq valeurs
distinctes**. Le décompte 3-2-1 est une **dérivée** (deux fois l'enseigne) et non
un septième cran : une échelle qui s'allonge « juste pour ce cas-là » a cessé
d'être une échelle.

**Le dépôt portait cinq copies de la palette et deux échelles privées** :
`ui.gd`, `menu_theme.gd` (dont le commentaire promettait de les réunir « le temps
de l'étape 3 », close depuis longtemps), `map_gallery.gd`, `map_editor_hud.gd`,
plus les `FONT_*` de `screen_matchmaking.gd` et `screen_leaderboard.gd`. Elles
avaient toutes divergé — six ors, sept rouges — et **aucune ne paraissait fausse
chez elle**.

#### Le mouvement

Trois courbes maison (Bézier cubiques évaluées par `Charte.courbe()`, pas des
`TRANS_*` de Godot) et trois durées — 90 / 180 / 300 ms. `Charte.animer()` les
applique via `tween_method`, seul chemin qui pose une vraie courbe plutôt que la
transition intégrée la plus proche. Les courbes sont **pures**, donc le banc
vérifie leurs bornes, la monotonie de l'entrée et **le dépassement du rebond** —
sans dépassement, ce n'est plus un rebond.

Les durées de **jeu** ne sont pas touchées : un fondu de mort de 2 s est accordé à
un fait de jeu, pas à un rythme d'interface.

#### Ce qui reste dû sur ce lot

- **Le rendu n'a pas encore été jugé à l'œil sur tous les écrans.** La planche de
  contact a été passée (voir plus bas) ; les écrans de salon et d'appariement en
  sont volontairement absents, y entrer ouvrant de vrais salons EOS.
- **`light_textures.gd` garde ses `Color(1, 1, 1)`, et ce n'est pas un oubli** :
  ce sont des **masques** multipliés par la teinte de la lumière qui les porte.
  Y mettre le blanc cassé teinterait deux fois. La règle porte sur ce que le
  joueur lit comme une couleur, pas sur un facteur neutre — même chose pour
  `modulate = Color.WHITE`, qui veut dire « aucune teinte ».

### DA1 — le détail des items

- **DA1.1 La bible visuelle d'une page** ✅ — `charte.gd` + `tools/test_charte.gd`.
  Palette de 6-7 couleurs *nommées*
  avec un rôle chacune (le noir du monde, le blanc cassé de la lumière, l'or
  tungstène, le carmin du sang, couleur J1, couleur J2, accent d'interface),
  règles dures (jamais de blanc pur, jamais de primaire, saturation
  plafonnée), plus un moodboard de ~10 références pour cadrer les commandes
  (Darkwood, Teleglitch, Hotline Miami, Inside, Nex Machina). Tout le
  chantier s'y réfère. *(S, arbitrage Adrien sur la palette)*
- **DA1.2 Deux fontes, mort de la fonte par défaut** ✅ **livrée le 2026-08-24**
  — `BigShouldersDisplay` (display) et `Oxanium` (UI), les deux OFL, embarquées
  dans `assets/fonts/`, `Oxanium` posée en fonte de projet. Une display à forte
  personnalité (titres, FATAL, verdicts) + une UI sobre à **chiffres
  tabulaires** (HUD, chrono, ping). SIL OFL : gratuit. Le levier au meilleur
  ratio de toute la liste — la fonte par défaut est le marqueur amateur n°1.
  *(G)*
- **DA1.3 La passe typographique** ✅ **livrée le 2026-08-24** — échelle de six
  tailles nommées dans `charte.gd` (`T_MENTION` à `T_ENSEIGNE`, plus
  `T_DECOMPTE`), appliquées partout ; `tools/test_charte.gd` refuse toute taille
  hors échelle. Les chiffres tabulaires sont vérifiés **par la mesure** — les dix
  glyphes doivent rendre la même chasse — et non par la présence du drapeau
  `tnum`, qui ne dit rien quand la fonte n'a pas la fonctionnalité. *(S)*
- **DA1.4 La passe de palette** ✅ **livrée le 2026-08-24** — ~51 littérales
  remplacées par une couleur nommée. Le banc interdit désormais la saturation
  au-delà de 75 %, tout canal pur hors `NOIR`, et **le vert dans l'arène** (il
  est réservé à l'état « ok » de l'interface) : la règle est vérifiée sur le
  *texte* de treize fichiers de monde, pas sur des constantes. *(S)*
- **DA1.5 Un seul artiste pour tout** ✅ **TRANCHÉ le 2026-08-24 : c'est Adrien,
  et le procédé se choisit par famille d'asset.** Un artiste unique ne suffit
  plus à garantir un style : c'est la table des procédés qui le tient. Raison et
  table en « Décisions actées ». *(Adrien)*
- **DA1.6 Le wordmark CANDELA** ✅ **livrée le 2026-08-24** — lettres au pochoir,
  halogène sur noir, liseré ambre ; sources d'Adrien dans `assets/logos/`.
  L'enseigne est un `TextureRect` posé **par-dessus** le `Label` du titre, pas à
  sa place : le même nœud porte cinq textes (le nom du jeu, « OPTIONS », trois
  verdicts) et seul le premier a un logo. Un seul point de décision,
  `_poser_titre()` — huit affectations y passent, sinon un chemin oublié
  laisserait le logo sur « DÉFAITE ». L'ombre M1 et la braise M11 sont intactes :
  l'enseigne est **enfant** du `Label`, donc calée sur le rectangle où le gnomon
  s'ancre déjà. *(C)*
- **DA1.7 Icône d'app + boot splash** ✅ **livrée le 2026-08-24** — `config/icon`
  ne pointe plus sur `icon.svg` ; l'écran de démarrage est l'enseigne sur le
  `NOIR` de la charte. Le logo Godot a disparu du lancement. *(dérivé de DA1.6)*
- **DA1.8 Trois courbes d'easing maison** ✅ **livrée le 2026-08-24** — `ENTREE`,
  `SORTIE`, `REBOND` en Bézier cubique résolue par Newton-Raphson, durées
  `D_COURT`/`D_MOYEN`/`D_LONG` (90/180/300 ms), un seul point d'entrée
  `Charte.animer()`. *(S)*
- **DA1.9 La grille de 8 px** ✅ **livrée le 2026-08-24** — six écarts nommés
  (`GAP_XXS` 4 px à `GAP_XL` 64 px), tous multiples de 8 sauf le demi-cran, et
  plus une seule marge écrite à la main dans les menus. *(S)*

### DA2 — Les ancres autorales in-game (là où l'œil juge en trois secondes)

- **DA2.1 Le cookie de torche peint** ✅ **livrée le 2026-08-24** — Adrien a
  comparé trois variantes cuites en 1024² dans le banc et retenu **`bis04`**,
  désormais cuite pour les quatre armes et intégrée à `weapon_data.gd` /
  `player.gd` / `game_state.gd`. L'outillage reste en place pour recuire :
  `tools/fabrique_cookies.gd` (cuisson hors ligne, curseurs `matiere`, `debut`,
  `contraste`, `energie`), `tools/apercu_torche.gd` (le banc, quatre variantes à
  la volée dans une vraie carte avec occluders), `tools/torches.gd` (la table des
  portées, partagée pour que les deux outils ne divergent pas) et
  `tools/test_torches.gd` (36 contrôles qui exigent que la table et le jeu
  disent la même chose).
  **Le procédé retenu : la planche ne devient pas le cookie, elle le MODULE.**
  L'échantillonnage est polaire — largeur de la planche = portée, hauteur =
  ouverture —, si bien qu'une seule planche sert les quatre armes et que
  `torch_angle_deg` reste vivant. Prix mesuré et assumé : le faisceau garde sa
  portée exacte et **63 à 72 % de sa lumière**, la planche ne pouvant que creuser.
  ⚠️ La compensation de `texture_scale` était annoncée comme la ligne la plus
  dangereuse du lot, et elle a mordu : à réglage inchangé, un cookie de 1024²
  portait **deux fois plus loin** qu'un 512². Fermée par
  `WeaponData.echelle_torche()`, qui rend l'empreinte au sol indépendante de la
  résolution du fichier — voir « Pièges connus », *la résolution d'une texture
  de lumière décide de sa PORTÉE*. *(C, ou G en CC0 retouché)*
- **DA2.2 Les halos peints** ✅ **livrée le 2026-08-25** — trois masques choisis
  par Adrien dans `tools/apercu_torche.tscn` : **`retrodiffusion_corona`** (le
  halo de corps, 256²), **`ambiante_braise`** (la lueur personnelle, 150²),
  **`eclat_poudre`** (balles, impacts, particules, sept postes d'empreintes
  différentes). Cuits par `tools/fabrique_cookies.gd --mode radial`, posés par
  `LightTextures.poser()`, tenus par `tools/test_lumieres.gd` (51 contrôles).
  L'échantillonnage y est **cartésien et non polaire** : un halo couvre 360°, et
  en polaire ses deux bords se rejoindraient le long d'un rayon en laissant une
  couture visible. ✅ **La quatrième texture existe depuis le 2026-08-25** — la
  traînée de balle était restée un dégradé procédural quand les trois autres
  étaient devenues des masques peints. Fermée avec DA2.12 ; `radial_tight` a été
  **retirée**, sans appelant. *(C : 3-4 textures)*
- **DA2.3 Le muzzle flash en frames** ✅ **livrée le 2026-08-25** — trois images
  peintes (famille **FB** : amorce, épanouissement, dissipation), déroulées
  par-dessus la descente d'énergie qui reste seule maîtresse de la luminosité.
  **Trois est le nombre que la durée permet, pas un choix esthétique** : à 0,1 s
  et 60 Hz chaque image tient deux images de rendu, à 0,05 s (l'arbalète) une
  seule ; au-delà, une image ne serait jamais affichée. Cuites en **énergie
  libre** et non radiale — voir « Pièges connus ». *(C : 1 planche)*
- **DA2.4 Le sprite du joueur** ✅ **livrée le 2026-08-25** — le personnage
  existe et est intégré : casque, épaules, avant-bras, vu de dessus strict, à
  **36 px d'épaules**, exactement le diamètre du `Polygon2D` qu'il remplace.
  **La marche est animée depuis le 2026-08-25**, mais **pas** par des frames
  peintes — et le détour vaut d'être lu, parce que la consigne d'origine était
  irréalisable telle quelle.

  Premier constat, mesuré : les seize frames livrées faisaient **s'effondrer la
  portée de l'arme**. Fusil +40,5 px en statique contre +22,5 en marche, pompe
  +38,5 contre +22,5 — les quatre armes devenaient **indistinguables pendant la
  marche**, alors qu'en statique elles s'échelonnent de +27,5 à +40,5. Dans un
  jeu où lire l'arme adverse décide du duel, ce n'est pas un défaut cosmétique,
  c'est une perte d'information. Cause trouvée en ouvrant les planches sources :
  **ce ne sont pas les mêmes caméras.** La planche statique est une vue de
  dessus stricte (on voit le dessus du crâne) ; la planche de marche est une vue
  oblique de trois-quarts arrière, jambes visibles, avec du flou de mouvement et
  des bavures magenta. Aucune découpe ne réconcilie deux caméras.

  Regénérer avec la planche statique **en pièce jointe** a réglé la caméra du
  premier coup — c'est le geste qui manquait, et il n'est possible que depuis
  une session qui sait joindre un fichier. Mais deux obstacles sont restés, et
  ce sont eux qui ont tranché :

  1. ⚠️ **Des frames fixes ne peuvent pas rester en phase avec le pas.** Le
     détecteur de pas de `player.gd` compte une **distance** — 45 px, 60 en
     sprint — et non un temps ; le son, l'empreinte au sol et la bosse de
     rétrodiffusion tombent déjà ensemble sur ce compteur. Une planche de quatre
     images jouée à cadence fixe dériverait de tout ça dès qu'on change
     d'allure, et le sprint la ferait mentir en permanence.

     ✅ **Cet obstacle est tombé le 2026-08-26**, et par une décision qui ne le
     visait pas : Adrien a supprimé le sprint. Il ne reste **qu'un seuil, 45 px**,
     donc plus de changement d'allure et plus rien à faire mentir. Une planche de
     marche indexée sur le compteur de distance — et non sur une horloge — reste
     en phase par construction. **L'obstacle n°2 (l'arme pivotée qui mentirait
     sur la visée) tient toujours**, lui, et c'est celui qui décide : la planche
     ne peut montrer que les jambes.
  2. ⚠️ **Une arme peinte pivotée mentirait sur la visée.** `rotation` dit déjà
     où le joueur vise : c'est l'information la plus chère du jeu. Toute
     inclinaison d'arme cuite dans une frame la contredit douze fois par
     seconde. (Ma propre première consigne à Gemini demandait le contraire —
     l'erreur venait de moi, pas du générateur.)

  D'où la solution retenue (commit `19b4f20`) : le corps **roule sur le pied
  porteur**, en
  translation le long de l'axe local Y, d'amplitude dérivée du **même
  accumulateur** que le pas (`sin(distance / pas × π) × 1,6 × côté_du_pied`).
  Elle tombe donc exactement avec le son et l'empreinte, à toutes les allures et
  sans un réglage ; elle ne peut pas pivoter l'arme ; et comme elle réemploie le
  sprite statique validé, **la portée de l'arme est préservée par construction**
  — le défaut d'origine devient impossible plutôt que corrigé. Le retour au
  repos est lissé, sans quoi s'arrêter en plein pas laisserait le corps penché à
  demeure. `ROULIS_MARCHE` règle l'amplitude en une ligne.

  Reste ouvert, et c'est un choix d'Adrien, pas un manque technique : une
  variation de membres peinte par-dessus ce roulis. Elle demanderait quatre
  planches tenant l'échelle **et** la longueur d'arme de la planche statique,
  ce que trois tentatives n'ont pas obtenu. Les seize PNG `*_marche_*.png` qui
  traînent dans `assets/sprites/` sont ceux de la mauvaise caméra : ils ne sont
  suivis par git ni chargés par quoi que ce soit, mais ils portent un nom
  crédible — **ne pas les câbler.**

  **DA2.4 et DA2.5 ont été FUSIONNÉES** par Adrien : en vue de dessus une
  arme n'est pas un objet séparé, c'est une forme qui dépasse des épaules — on
  cuit donc quatre sprites complets, un par arme, plutôt qu'un corps et quatre
  armes à raccorder. *(C)*
- **DA2.5 Les 4 armes en main** ✅ **CLOSE le 2026-08-25 par décision d'Adrien**,
  et la décision renverse le principe que cette entrée défendait. Il a écarté le
  test : *« pars du principe qu'on les reconnaît, ce n'est pas grave si ce n'est
  pas finement identifiable »*.

  ⚠️ **Le texte d'origine reste ci-dessous, non réécrit.** Il affirme que la
  distinction « n'est pas une affaire de goût » et qu'elle décide des duels ;
  Adrien tranche l'inverse. **Une décision qu'on voit changer d'avis reste
  lisible ; une décision réécrite fait croire qu'on n'a jamais pensé autrement.**

  **Ce que la mesure disait au moment de la décision**, pour que le choix soit
  daté et non pas rétrospectivement embelli. Écart entre paires, sur quatre
  caractéristiques (portée, épaules, masse d'encre, épaisseur du canon) :

  ```
  fusil / pompe            4,9 %   11,5 %    9,8 %   14,0 %
  pistolet / arbalete      6,8 %    8,7 %    6,7 %    9,4 %
  les quatre autres paires        23 % a 44 %
  ```

  Première lecture : « pistolet / arbalète indistincts ». **Fausse, et l'erreur
  venait de la mesure, pas des sprites** — quatre scalaires moyennent, donc ils
  écrasent la forme. Le profil de largeur le long de l'axe dit autre chose :

  ```
  fusil     21 18 16 12 10 10  6  6  2  2  2  2
  pompe     16 13 10  9  7  8  7  6  6  3  2
  pistolet  21 18 15 12 10 10  7  8
  arbalete  17 14 10 26 19 12  7        <- renflement a 9 px
  ```

  **L'arbalète est la seule dont le profil n'est pas décroissant** : ce 26 est
  l'arc transversal, une signature qu'aucune autre ne porte. Elle est donc
  séparable — par la forme, pas par la taille. La paire réellement à risque était
  **fusil / pompe** : même profil décroissant, longueurs de canon de 34 et 32 px,
  2 px d'écart de portée.

  ⚠️ **Ce que la clôture ne dit PAS.** Le test de nomination n'a pas été passé :
  on ne sait donc toujours pas si l'œil suit le chiffre, et la prédiction
  fusil / pompe n'a été ni confirmée ni infirmée. La distinction est **assumée
  suffisante**, pas **vérifiée suffisante** — et c'est une position parfaitement
  tenable pour un jeu où l'arme adverse s'entrevoit une demi-seconde dans le noir.
  Si un jour un duel se perd sur une confusion d'arme, c'est ici qu'il faudra
  revenir, et `tools/apercu_matiere.tscn` attend toujours.

  *Texte d'origine, conservé :* les
  quatre sprites sont cuits et posés. ⚠️ **Le test qui décide n'a pas été refait
  depuis la dernière regénération.** Il ne s'agit pas de goût : `tools/apercu_matiere.tscn`
  aligne les quatre figures sans annoncer l'ordre, et Adrien les nomme. **Au
  premier passage il en a nommé deux sur quatre**, confondant le pistolet et
  l'arbalète — et la mesure l'avait prédit, les deux dépassaient identiquement
  de 5 px au-delà des épaules. Après regénération les dépassements valent 29,
  38, 40 et 26 px ; reste à savoir si l'œil suit le chiffre. *(C, avec DA2.4)*
- **DA2.6 Le tileset des sols** ✅ **livrée le 2026-08-25** — les deux cases du
  damier sont des tuiles peintes, choisies par Adrien dans
  `tools/apercu_matiere.tscn` (variante 1, damier « faible »), cuites par
  `tools/fabrique_tuiles.gd` depuis une planche versionnée — donc recuisables.
  Chaque case prend l'une de **huit orientations** tirées d'un hachage de sa
  position : coût nul (Godot les porte dans l'identifiant de tuile alternative,
  8 sur 8 vérifiées) et **déterministe**, pour que les deux machines d'un match
  voient le même sol. **Le damier s'affaiblit sans disparaître** — il opposait
  0,111 à 0,231 de luminance, il oppose désormais 0,148 à 0,178 : le grain porte
  maintenant une part de l'information que le contraste portait seul. *(C)*
- ~~**DA2.7 Le tileset des murs**~~ — ❌ **ESSAYÉE PUIS ABANDONNÉE le 2026-08-25
  (Adrien).** Raison mesurée en « Décisions actées ». En deux mots : l'arête
  halogène EST le mur, et une matière peinte à l'intérieur n'ajoutait rien
  qu'elle ne noyait. *(abandonnée)*
- **DA2.8 Les decals de sang peints** ✅ **livrée le 2026-08-25** — le sang
  n'est plus un semis de 15 à 30 cercles tirés au sort : c'est **une
  éclaboussure peinte, tournée dans l'axe du tir**. Une tache raconte donc d'où
  le coup venait, ce qu'un semis ne pouvait pas dire. Deux formes — une flaque
  d'impact dense, une traînée directionnelle — tirées au sort avec une échelle
  variable. ⚠️ **L'entrée en demandait 6 à 8, il y en a DEUX** : Gemini a bloqué
  en boucle sur les suivantes. Les quatre à six manquantes sont commandées.
  ⚠️ **Deux textures par éclaboussure, et le cœur n'est pas décoratif** :
  `blood_shader.gdshader` « préserve le centre noir et les bords rouges », donc
  sa spéculaire n'a rien à réfléchir sur un aplat uniforme. Le dessin remplacé
  produisait ce contraste en deux passes ; les deux textures le reproduisent.
  *(C : 1 planche)*
- **DA2.9 Les impacts muraux** ✅ **livrée le 2026-08-25** — `wall_impact.gd`
  pose un éclat persistant à chaque balle qui touche la géométrie. **C'est la
  seule trace qu'un tir MANQUÉ laisse au monde**, et elle raconte le match
  autant que le sang. Douze éclats sous huit orientations tirées au sort : le
  motif ne se reconnaît pas. Teintés `ACIER` et non `HALOGENE` — un éclat est du
  métal mis à nu, une matière froide que la torche révèle, pas une source
  chaude. Plafond à 90, plus bas que les 120 du sang parce qu'un impact mural
  coûte un tir manqué, et qu'il y en a bien plus que de touches.
  ⚠️ **Quatre des seize sont sortis VIDES**, et la raison mérite d'être connue :
  c'étaient les brûlures, dessinées en sombre sur noir. L'alpha d'un décal vient
  de sa luminance — **une brûlure noire est un décal transparent.** La consigne
  « sombres et contrastés », donnée à cause du fondu additif des murs,
  contredisait la règle de polarité sans que personne le voie. Douze suffisent ;
  rien n'a été regénéré. *(C, avec DA2.8)*
- **DA2.10 Le key art du titre** 🟡 **ASSET PRÊT, PAS POSÉ le 2026-08-25** —
  ⚠️ **DEUX planches cuites, pas trois.** Cette entrée a annoncé trois planches
  « retouchées et ramenées sur la charte » ; `assets/keyart/` n'en a jamais
  contenu que deux, et git n'en a jamais connu d'autres. La troisième source,
  `K1_03.jpg`, n'a pas été écartée pour sa qualité : **elle est en portrait**
  (1536 × 2752) quand les deux autres sont en paysage. Ce n'est pas une
  candidate refusée, c'est un autre format — deux faisceaux croisés en X sur une
  grande moitié basse noire, une composition d'**affiche ou de capsule de
  boutique**, inutilisable comme fond d'un menu en 16/9. Elle mérite d'être
  gardée sous ce titre-là plutôt que comptée ici. Le compte faux venait de la
  source, pas du travail : trois sources, deux sorties, et personne ne l'a
  revérifié en écrivant.

  **Laquelle poser : `rasants`, et ce n'est pas un avis.** Le critère qui décide
  d'un fond de menu n'est pas la beauté de l'image mais **la place calme
  disponible derrière le titre**. Mesuré par bandes horizontales (luminance
  moyenne, écart-type, maximum) :

  ```
  planche        bande     moyenne    ecart      max
  convergents    haut 25%    0.052    0.125    0.998   ← une torche crevée
                 25-50%      0.098    0.136    0.822
  rasants        haut 25%    0.009    0.013    0.125   ← noir, et calme
                 25-50%      0.054    0.065    0.612
  ```

  Le quart supérieur de `rasants` plafonne à **0,125** : son pixel le plus clair
  est encore sombre, et son écart-type est **dix fois** plus bas. Un titre s'y
  pose sur du noir vrai. Celui de `convergents` contient une torche à **0,998**,
  c'est-à-dire un blanc crevé : n'importe quel lettrage qui la croise devient
  illisible, et la déplacer pour l'éviter, c'est laisser l'image décider de la
  mise en page.

  S'y ajoute une raison de fond, moins mesurable mais qui va dans le même sens :
  `rasants` montre des faisceaux **rasants** qui écrivent de longues ombres
  portées sur le sol — c'est littéralement l'occlusion, la mécanique du jeu —
  et deux torches qui se font face à la même hauteur, ce qui est un duel.
  `convergents` éclaire depuis le haut : c'est une battue, pas un 1v1.

  ✅ **`rasants` CHOISIE par Adrien le 2026-08-25**, conformément à la mesure.
  Les deux planches sont conservées ; le choix ne coûte rien à refaire.

  ✅ **POSÉE le 2026-08-25**, Adrien ayant dit « attaque DA2.10 ». Un
  `TextureRect` nommé `KeyArt`, dans `_poser_le_key_art()`.

  ⚠️ **Au-DESSUS du rideau, pas derrière — et ce n'est pas un détail de
  z-order.** `Charte.BACKDROP` est à alpha **0,96** : une planche posée dessous
  ne passerait qu'à 4 %, c'est-à-dire pas du tout. Le rideau reste le sol de
  l'écran, la planche est un voile posé dessus, sous tout le contenu.

  **`PRESENCE_KEY_ART = 0,34`, et le chiffre se mesure.** La bande claire de la
  planche culmine à 0,998 — exactement la luminance d'un titre en `HALOGENE`.
  À pleine force les faisceaux disputeraient l'écran aux mots. Composite
  vérifié après coup, en refaisant l'empilage du moteur (rideau à 0,96, puis
  planche à 0,34) :

  ```
  bande       moyenne    ecart      max
  haut 25%      0.011    0.004    0.039
  25-50%        0.026    0.022    0.190
  50-75%        0.117    0.078    0.348   <- le plus clair du fond
  bas 25%       0.071    0.059    0.260
  ```

  Le point le plus clair du fond tombe à **0,348** contre ~0,95 pour un texte :
  l'image se sent, elle ne se lit pas.

  **`STRETCH_KEEP_ASPECT_COVERED` et non `SCALE`** : la planche est en 16/9 et
  l'écran ne l'est pas toujours. L'étirer déformerait des faisceaux **dont
  l'angle est le sujet** — c'est ce qui distingue `rasants` de `convergents`.
  Et `MOUSE_FILTER_IGNORE`, sans quoi elle avalerait les clics du menu.

  ⚠️ **Ce que cette pose n'a PAS fait, et c'est assumé** : la planche ne reçoit
  ni la brume ni la parallaxe, qui vivent dans le matériau du rideau, en
  dessous. Un premier jet honnête vaut mieux qu'un couplage au shader que
  personne n'a demandé. Si Adrien veut que la planche respire avec le reste,
  c'est un pas séparé.

  *Historique : l'asset est resté choisi mais non posé quelques heures, sans
  titulaire —*
  Le fond du menu (`MenuBackdrop`, `MenuGlass`, parallaxe, brume dans le
  matériau) vit dans `ui.gd`, domaine de DA4 ; la session DA4 a explicitement
  décliné, non par refus mais par fin de capacité : *« le poser à moitié serait
  pire que de le laisser »*. **C'est donc un travail prêt à partir, sans
  titulaire**, et il tiendra en une ligne de brief pour qui reprendra
  l'interface : poser `assets/keyart/keyart_rasants.png` en fond de menu, titre
  dans le quart supérieur — celui qui plafonne à 0,125 de luminance.

  Retouchées et ramenées sur la charte par
  `tools/fabrique_keyart.gd`, dans `assets/keyart/`. **Rien ne les affiche** :
  le fond du menu est un système complet — `MenuBackdrop`, `MenuGlass`,
  parallaxe, brume dans le matériau — qui vit dans `ui.gd`, **domaine de DA4**.
  L'asset est de DA2, sa pose ne l'est pas.
  ⚠️ **La décision du 24 annonçait « génération fortement retravaillée », et la
  mesure a dit le contraire.** Le noir des trois planches est déjà à **0,000
  exactement** — ce que la promesse du jeu exige et qu'aucune retouche n'aurait
  eu à corriger — et la teinte des faisceaux tombait déjà à 1-8 % de
  `HALOGENE` : le modèle a décrit un tungstène et a atterri presque pile sur la
  lumière du jeu. Il restait **un seul écart**, le bleu à 0,74-0,79 contre 0,82.
  Corrigé, et **uniquement sur les hautes lumières** : corriger toute l'image
  aurait bleui les ombres, et un noir bleuté n'est plus le noir absolu — on
  aurait perdu la seule chose que ces planches avaient déjà juste. Vérifié après
  coup, le point noir et la moyenne des ombres n'ont pas bougé d'un centième.
  **Prétendre à une reprise que la mesure ne demande pas serait fabriquer du
  travail.** *(C)*
- **DA2.11 Le viseur custom** ✅ **livrée le 2026-08-25** — ⚠️ **ce n'était pas
  un habillage, c'était un MANQUE** — le dépôt ne contient **aucun** viseur : zéro
  occurrence de `crosshair`, `viseur`, `reticule`, et aucun
  `set_custom_mouse_cursor` nulle part. **Le jeu affiche donc la flèche du
  système pendant les matchs**, dans un jeu dont toute la proposition est « la
  seule information est la lumière ». Personne ne l'avait relevé parce qu'on ne
  cherche pas une absence : il n'y a pas de nom à grep. Deux points de
  rattachement vérifiés : `InputProvider.get_aim_direction()` rend la visée sans
  que rien ne sache d'où elle vient (clavier-souris et manette, sans un `if`) ;
  et ⚠️ **l'écran partagé exige un `visibility_layer` explicite** — 2 pour la vue
  de J1, 4 pour celle de J2 —, faute de quoi le viseur s'affiche dans les deux
  vues, défaut déjà payé sur le flash de mort le 2026-08-17.
  *(variante C — quatre chevrons rentrants — choisie par Adrien le 2026-08-25
  sur quatre propositions ; génération autorisée par le revirement consigné en
  « Décisions actées »)*

  **Ce qui a été livré, et l'écueil qui n'était pas dans l'énoncé.** L'item
  décrivait un viseur à poser ; il en fallait deux moitiés. Poser le sprite
  sans **éteindre la flèche du système** aurait donné **deux pointeurs à
  l'écran** — l'énoncé nommait pourtant le défaut (« le jeu affiche la flèche du
  système »), mais l'intitulé « viseur custom » invitait à ne lire que l'ajout.

  - **Le sprite** est enfant du joueur, posé en `(110, 0)` : `rotation` suit
    déjà la visée, donc aucun code de suivi. ⚠️ **La distance est fixe, et ce
    n'est pas un pis-aller** — `get_aim_direction()` rend une direction
    **normalisée**, la position de la souris est jetée avant d'arriver là. C'est
    voulu : le joueur vise un cap, et la manette ne sait rien dire d'autre.
    Aller rechercher la souris dans `player.gd` y rétablirait la connaissance du
    périphérique que tout le patron `InputProvider` existe pour lui retirer.
  - **Non éclairé** (`LIGHT_MODE_UNSHADED`) : un viseur qui s'éteindrait dans le
    noir serait inutilisable là où le jeu se joue. Il n'appartient pas au monde
    que la torche révèle.
  - ⚠️ **La flèche du système se DÉRIVE, elle ne s'appaire pas.** `ui.gd`
    recalcule `Input.mouse_mode` à chaque image depuis `_is_main_menu`. Ce
    drapeau bascule en quatre endroits, `round_active` en sept : poser un
    masquage d'un côté et une restauration de l'autre, c'est signer la dérive —
    **un seul chemin de sortie oublié laisse la souris invisible dans les
    menus, où plus rien n'est cliquable.** Un état recalculé se rattrape tout
    seul à l'image suivante. Et la flèche doit revenir en menu : c'est le survol
    souris qui y déplace la sélection de J1.
  - **`tools/test_viseur.gd`** (16 contrôles) mesure l'image — trou central de
    rayon 16 px sur 24, quadrants à 0,11 % du quart parfait, coins à zéro — et
    lit le texte pour les deux régressions nommées ci-dessus. **Éprouvé rouge
    sur huit sabotages avant d'être cru.** Deux de ses contrôles étaient
    d'abord incapables d'échouer : voir le piège consigné plus bas.
- **DA2.12 Les traçantes texturées** ✅ **livrée le 2026-08-25** — deux masques,
  et l'item en fermait deux. Le **halo de traînée** remplace le dégradé de
  `radial_tight` : c'est la quatrième texture que DA2.2 annonçait et n'avait
  jamais livrée — une dette qui vivait dans une entrée **close**, donc que rien
  ne rappelait. Et la **traçante** habille la `Line2D`, qui était un trait plein.
  ⚠️ **Le sens de la texture n'est pas anodin** : les points vont de la balle
  vers la queue, donc le bord gauche de la texture tombe sur le projectile. La
  planche est cuite retournée (`--miroir`) pour que le dense soit sur la balle —
  **une traînée s'éteint dans son sillage, elle ne s'y allume pas.**

### DA3 — L'audio

> **Le sous-titre disait « le câblage existe, il joue du silence ». Il ne joue
> plus de silence.** Au 2026-08-26, le dépôt porte **45 fichiers audio** — 12 en
> musique, 20 pour les armes, 8 de voix, 5 d'effets d'origine — et le dosage a
> été jugé à l'oreille par Adrien en deux séances au banc.
>
> **Ce qui reste de DA3 n'est plus du câblage, c'est de la PRODUCTION** : les
> sons qui manquent manquent parce qu'ils n'ont pas été faits, pas parce que le
> code les ignore. Seul DA3.9 (mastering) est un travail de session.
>
> **Titulaire depuis le 2026-08-26 : la session « DA3 »**, à la demande d'Adrien
> — le son entier, après la disparition de la session « spatialisation ».


- ~~**DA3.1 Les 4 sons de tir**~~ (= V4.1) — **✅ livrée le 2026-08-25**, en
  seize prises (quatre par arme) plutôt qu'en huit corps/queues. Le premier son
  entendu est le premier jugé, et il ne se répète plus.
- ~~**DA3.2 Les stems produits à 170 BPM**~~ (= V1.1) — **✅ livrée le
  2026-08-24.** La musique adaptative joue enfin ce qu'elle orchestrait.
- **DA3.3 Les trois fichiers câblés-muets du 2026-08-18** — `torch_on.wav`,
  `torch_off.wav`, `tinnitus_dazzle.wav` (V5.1, V5.3) : ils vivent dès le
  dépôt des fichiers. *(C : 3 samples)*

  ⚠️ **`tinnitus_dazzle` porte une question de CONCEPTION — et le câblage y a
  déjà répondu sans que personne ne la pose.** Ce paragraphe a dit pendant huit
  jours qu'il fallait trancher *avant* le câblage : c'est faux, `set_dazzle_level`
  existe depuis `4c110b2` (lot V5.3), garde-fou de nullité compris, et il ne
  manque que le fichier. Vérifié dans le code le 2026-08-26.

  La règle posée le 2026-08-25 s'applique : *un curseur de confort ne doit pas
  moduler une pénalité d'information.* S'il informe — « tu es ébloui, voilà ce
  qu'il te reste » — il relève de la même règle que le voile blanc et ne doit pas
  être réglable ; s'il habille, il suit le curseur d'effets. **Or le lecteur est
  câblé sur `SFX`**, que `settings_manager.gd` sait couper franc (`set_bus_mute`
  au zéro du curseur) : la réponse « il habille » est donc déjà en place, par
  défaut et non par décision.

  ⚠️ **Et le bus choisi porte une seconde question, plus dure que la
  première.** `SFX` est aussi le bus des pas — la seule information du jeu. Une
  boucle continue y masque acoustiquement l'adversaire *pendant* l'éblouissement,
  c'est-à-dire au moment où le joueur en a le plus besoin. Double peine
  délibérée ou effet de bord d'un choix de bus : à trancher au dépôt du fichier,
  et le banc `tools/banc_audio.tscn` est l'endroit pour en juger.
- ~~**DA3.4 Les stingers accordés**~~ (= V2.3, V3.7, V3.8, V3.10) — **✅ livrée
  le 2026-08-25.** Les quatre fichiers étaient au dépôt depuis la veille sans que
  rien ne les joue ; ils sont câblés par `AudioManager.stinger_de_fin`, une règle
  pure qui décide ce que CETTE machine entend. Un kill non décisif s'entend **des
  deux côtés** (décision d'Adrien) ; un kill décisif donne le kill de match au
  vainqueur et la défaite au vaincu ; en écran scindé, jamais de défaite —
  personne n'y est « le » vaincu à la sortie audio.

  ⚠️ **Au format BO1, `sting_kill` ne sortira jamais** : tout kill y est décisif.
  Ce n'est pas un défaut, mais c'est un silence qu'on prendra pour une panne.
- ~~**DA3.5 La voix d'annonceur**~~ (= V1.3) — **✅ livrée le 2026-08-25.** Huit
  fichiers dans `assets/audio/voice/`. La règle est `AudioManager.voix_de_fin`,
  **dérivée d'`ecoute_somme`** : en écran scindé l'annonceur NOMME le vainqueur —
  deux joueurs, mêmes haut-parleurs, il faut lever l'ambiguïté — partout ailleurs
  il s'adresse à celui qui écoute (`win`, `defeat`, `spk_perfect` sorti intact,
  `spk_close_call` sous 10 PV).

  ⚠️ Les chemins pointaient vers `assets/audio/speaker/`, **un dossier qui n'a
  jamais existé** : les voix étaient muettes en silence depuis des mois. Le mot
  `speaker` ne désigne plus qu'un **bus** — une sortie, pas un rangement.
- **DA3.6 Les pas par matériau** (= V5.7) — deux sols, deux jeux de pas. *(C)*
- **DA3.7 La famille de sons UI** — survol, validation, retour, erreur : une
  même matière sonore pour tous les menus. *(C : 5-6 samples)*
- **DA3.8 Le room tone** (= V5.10) — un lit de silence habité sous la manche.
  *(C)*
- **DA3.9 Le mastering global** — **✅ la moitié qui compte est faite le
  2026-08-26 ; l'autre moitié est ANNULÉE par décision d'Adrien.**

  **Annulé : « loudness cohérente entre bus ».** *« Il faut que les écarts de
  loudness soient importants, et puissent être corrigés à la marge dans le
  panneau de réglage du son »* (2026-08-26). L'écart **est** le mixage — musique
  à −18 LUFS, armes à −4 — et l'aligner détruirait ce qui a été jugé au banc. Le
  panneau (Master / Musique / Effets / Annonceur) fait l'ajustement fin ; le
  mastering ne le fait pas à sa place.

  **Fait : le filet de sortie.** Mesuré, **26 des 45 fichiers dépassaient
  0 dBFS**, jusqu'à +4,0 pour `weapon_pistolet_03` — un seul tir demandait déjà
  à la sortie plus qu'elle ne peut rendre, et une fusillade saturait au moment
  le plus intense. Un `AudioEffectHardLimiter` sur Master, marge −4,5 dB,
  plafond −0,5 dB.

  **Le principe, et c'est lui qui fait tout : la marge travaille, le filet se
  tait.** Une marge est une **translation, pas une compression** — baisser tout
  d'une même quantité préserve exactement chaque rapport jugé au banc. Le
  dimensionnement vient de la mesure : la marge couvre le pic le plus fort du
  dépôt plus un demi-décibel, si bien qu'un son **seul** ne réveille jamais le
  limiteur. Seules les sommes le réveillent.

  **Pourquoi ce n'est pas un détail d'ingénierie mais une contrainte de jeu :**
  dans un duel où le son est la seule information, un limiteur qui mord à chaque
  tir baisserait les pas de l'adversaire — **il retirerait l'information au
  moment précis où elle compte le plus.** Même famille que la règle du voile :
  ce qui protège le confort ne doit pas moduler ce qui renseigne.

  ⚠️ **Un seul limiteur, et sur Master.** Un limiteur sur `SFX` mordrait sur les
  tirs, donc baisserait les pas qui partagent ce bus : le défaut déplacé d'un
  cran. Vérifié par suite que ni `Music`, ni `SFX`, ni `Speaker` n'en portent.

  Réglable au banc (`M`/`P` la marge, `L`/`K` le plafond) avec un **témoin de
  crête** — un limiteur qui mord sur un transitoire ne s'entend pas comme une
  distorsion mais comme « la musique a hoqueté », et on cherche alors le défaut
  ailleurs. Le témoin dit ce que l'oreille ne peut pas prouver.

### DA4 — L'interface habillée

#### Le lot du 2026-08-24 : le dépôt avait deux fontes et n'en portait qu'une

**Le chantier DA4 s'ouvre sur un chiffre, pas sur une intention.** DA1.2 a livré
`BigShouldersDisplay` et `Oxanium` le matin même : deux fichiers OFL, leurs
licences versionnées à côté, l'axe variable vérifié par la mesure, une échelle de
six tailles, quatre graisses nommées. Six jours de travail plus tard,
`Charte.police_display()` était appelée depuis **trois** sites — `player.gd`,
`bullet.gd`, `game_state.gd` —, tous en espace-monde.

**Les 5 000 lignes de `ui.gd` ne l'appelaient jamais.** Tous les menus, le HUD,
la killcam, l'écran de fin, le titre du jeu à 68 px : la fonte d'enseigne
n'atteignait pas un seul écran. Et aucun `Control` du dépôt ne posait de graisse
— `POIDS_APPUI` et `POIDS_ENSEIGNE` n'existaient que pour l'arène. L'interface
entière rendait **une fonte, un poids**, ce qui est la définition exacte de « pas
habillée ».

**Rien ne le disait, et `tools/test_charte.gd` ne pouvait pas le dire.** Ce n'est
pas un défaut de sa part : il vérifie *la charte*, pas *son emploi*. Que les
chiffres d'Oxanium soient tabulaires, que l'axe de graisse agisse, que l'échelle
compte six crans — ces trois affirmations restent vraies dans un dépôt où plus
personne n'appliquerait la charte à quoi que ce soit. **Une charte peut être
intégralement conforme et intégralement inemployée.**

##### La cause n'est pas l'oubli, c'est le nombre de gestes

Poser une fonte demandait `add_theme_font_override` **plus**
`add_theme_font_size_override` **plus** une `FontVariation` pour la graisse :
trois gestes pour une intention. Personne ne fait trois gestes cinquante fois.

C'est très exactement ce qui avait déjà tenu les 51 couleurs littérales de
DA1.4 : ce n'est pas la discipline qui les a remplacées, c'est d'avoir eu un nom
**plus court à écrire que la valeur**. `Charte.enseigne(lbl, T_ENSEIGNE)` et
`Charte.appareil(lbl, T_COURANT)` font le geste unique, et posent les trois
propriétés **ensemble** — c'est ce qui les empêche de diverger, comme les 25
tailles avaient divergé.

##### La frontière entre les deux registres est mesurée, pas choisie

⚠️ **`BigShouldersDisplay` n'est pas tabulaire, et l'écart est d'un autre ordre
que tout ce qui a été relevé jusqu'ici.** À `T_VERDICT`, la chaîne `00:00` fait
**83 px** et `11:11` en fait **49** — 41 % de largeur en moins pour le même
nombre de signes. À `T_APPUI`, les dix chiffres vont de 5 à 9 px.

Pour mémoire, le défaut qui avait fait écarter *Chakra Petch* de la place de
fonte d'interface en DA1.2 valait 12 px contre 6,9 sur **un seul glyphe**.

**Ce n'est pas un défaut de la fonte.** Une signalétique industrielle n'a aucune
raison d'être tabulaire, et l'ultra-condensé qui fait sa personnalité est
précisément ce qui l'en empêche. C'est un défaut d'**emploi**, et il ne peut se
produire que d'un côté de la frontière :

> **La fonte d'enseigne ne porte jamais un signe qui se remplace sur place.**
> Elle prend les mots qui s'écrivent une fois — CANDELA, FATAL, VICTOIRE,
> KILLCAM, le code de salon. Le chrono, le ping, le score et le timecode restent
> à l'appareil, dont les chiffres sont tabulaires par construction.

**Le critère n'est pas « est-ce un nombre ».** Les nombres de dégâts de
`bullet.gd` sont en enseigne, et ils y sont bien : ils naissent, ils montent, ils
meurent, et **aucun ne se substitue à un autre dans la même boîte**. Le critère
est la substitution en place — c'est là, et seulement là, que la largeur qui
change se lit comme un tremblement.

##### Ce que le banc mesure, et pourquoi il est formulé ainsi

`tools/test_habillage.gd` (44ᵉ suite) monte l'interface réelle et mesure **les
dix chiffres de chaque compteur dans la fonte que le `Control` résout
effectivement**. Sept compteurs sont sous surveillance : chrono, ping, timecode
de killcam, les deux étiquettes de recharge, et les deux lignes du panneau F3.

⚠️ **La règle est écrite sur la mesure, jamais sur le nom de la fonte.** « Le
chrono n'est pas en display » serait vrai aujourd'hui et vide demain : il
suffirait d'une troisième fonte pour que le contrôle passe au vert sur un défaut
réel. Ce qu'on interdit, c'est le tremblement — pas un fichier.

**Le banc a été vu rougir avant d'être livré.** La fonte d'enseigne posée exprès
sur le chrono : `ui.time_label tremble : 9.0 px d'écart entre ses chiffres à
42 px`. C'est la leçon de `test_ecran_de_fin`, qui posait une graine de
navigation sur deux boutons puis n'assertait que sur des constantes — un contrôle
qu'on n'a pas vu échouer n'est pas un contrôle.

Il porte aussi un garde-fou qui protège tous les autres : **si les fontes ne se
chargent pas, chaque `Control` retombe sur la fonte par défaut de Godot, qui est
tabulaire — et les sept contrôles de tremblement passeraient au vert sur une
interface entièrement nue.** Voir « Pièges connus », *un worktree neuf n'a pas de
cache d'import*.

##### La fonte d'enseigne entre enfin dans l'interface

DA1 ayant rendu `ui.gd` en fin de séance, le lot a pu poser les deux registres
là où la charte les désigne. **Six `Control` changent, et c'est tout — mais ce
sont ceux qu'on regarde :**

| Contrôle | Registre | Pourquoi |
|---|---|---|
| le décompte 3-2-1 | **enseigne** | Un chiffre seul qui occupe l'écran n'est pas du texte. Ancré en plein cadre, donc rien ne peut trembler : `3`, `2` et `1` ne se comparent jamais, ils se succèdent au même endroit. |
| `KILLCAM` | **enseigne** | Un mot fixe, écrit une fois. |
| le titre / les verdicts | **enseigne** | Voir ci-dessous. |
| le chrono | appareil | Le compteur le plus exposé, et le seul qui **bat** sous dix secondes. |
| le ping | appareil | Se réécrit dans une rangée centrée dont il pousserait les voisins. |
| le timecode de killcam | appareil | Ancré **en haut à droite** : une largeur qui varie décolle le texte du bord. C'est le seul endroit du jeu où le tremblement se lirait comme un défaut de marge, pas de chiffre. |

**Le verdict referme une incohérence qui existait entre l'arène et l'interface.**
`player.gd` écrivait déjà FATAL en fonte d'affichage à `T_ENSEIGNE` ; l'écran de
fin écrivait VICTOIRE et DÉFAITE en fonte d'interface. **Les deux mots tombent à
quelques secondes d'intervalle sur le même temps fort** — l'un dans l'arène,
l'autre sur l'écran de fin — et ils ne se ressemblaient pas.

**Conséquence de mise en page, mesurée et assumée : l'en-tête du menu grandit de
13 px** (hauteur de ligne 69 → 82 à `T_ENSEIGNE`). L'enseigne dessinée de DA1.6
n'en est pas affectée — elle est posée par offsets calculés et non par la taille
du texte — et le rapport s'améliore même : elle mesure 84 px de haut pour un
`Label` qui passe de 69 à 82.

✅ **Jugé à l'œil le 2026-08-24, planche lancée par Adrien lui-même.** Les 13 px
ne cassent rien : l'en-tête reste aéré, rien ne déborde, la ligne de description
sous le titre garde sa place. Trois observations que seule l'image donne :

- **Le verdict tient sa promesse.** `JOUEUR 2 GAGNE` et `ÉGALITÉ` en condensée
  lisent comme de la signalétique et non comme du texte agrandi. La parenté avec
  le FATAL de l'arène se voit — c'était tout l'objet du changement.
- **Les accents existent dans la fonte d'enseigne.** `ÉGALITÉ` rend son `É`
  correctement. Ce n'était pas acquis : une condensée d'affichage tronque
  souvent son jeu de glyphes, et le verdict d'égalité aurait été le seul écran à
  le montrer.
- **Le code de salon tient à l'œil ce que le banc tenait au chiffre.**
  `WXYZW3` et `JT7JT7` commencent et finissent au même pixel. L'air entre les
  cases est généreux et lit comme un numéro de série, ce qui est l'effet
  recherché.

⚠️ **La passe visuelle est fragile pour une raison qui n'a rien à voir avec le
code, et il faut le savoir avant de s'en servir** : elle exige une fenêtre au
premier plan, et macOS bride le rendu dès qu'elle passe derrière. Trois passes
consécutives lancées depuis une session d'agent ont rendu **16, puis 2, puis 1**
image, pendant qu'Adrien travaillait au clavier — et la planche le **dit**
(`✗ … : aucune image (fenêtre au premier plan ?)`) au lieu de rendre des images
fausses, ce qui est le bon comportement. Lancée par Adrien sur une machine dont
il tenait le focus, elle a rendu les 16 d'un coup. **Une passe visuelle se lance
donc quand personne d'autre ne travaille, ou par la personne devant l'écran.**

##### Le banc a maintenant deux versants, et le second manquait

`tools/test_habillage.gd` n'interdisait d'abord que le mauvais registre. **Or un
dépôt qui n'emploie nulle part la fonte d'affichage passe tous les contrôles de
tremblement** — c'est très exactement l'état dans lequel le projet a vécu six
jours. Interdire ne dit rien sur l'emploi.

Trois enseignes sont donc désormais exigées : le titre, le décompte, `KILLCAM`.
Le contrôle est formulé « ce n'est pas la fonte d'interface » et non « c'est
`BigShouldersDisplay` » — nommer le fichier attendu rendrait le banc faux le jour
où l'enseigne change, c'est-à-dire le jour où l'on a besoin qu'il tienne.

**Les deux versants ont été vus rougir séparément** avant livraison : fonte
d'enseigne posée sur le chrono → `tremble : 9.0 px d'écart` ; fonte d'interface
posée sur le décompte → `rend « VICTOIRE » exactement comme la fonte d'interface
(598.0 px) : elle n'est pas habillée`.

##### Ce qui est livré, et ce qui ne l'est pas

Livrés : **DA4.2** et **DA4.9**, plus l'entrée de la fonte d'enseigne dans
l'interface (le socle typographique dont DA4.7 dépendait).

**Non commencés, et ils sont nombreux :** DA4.1 (9-slice), DA4.3 (le contour
dessiné des chiffres de dégâts — la moitié « fonte » était déjà faite par DA1),
DA4.4 à DA4.8, DA4.10 à DA4.17. `ui.gd` n'a été libéré qu'en fin de séance ;
tout ce qui demande des textures dessinées attend en outre le procédé DA1.5.

#### DA4.18 — Le cadre de droite est vide, et c'est un défaut (relevé par Adrien, 2026-08-24)

**Priorisé devant le reste de DA4 par Adrien** : c'est le plus grand rectangle de
l'interface, il occupe les deux tiers de chaque écran de menu, et il ne montrait
rien la plupart du temps.

**🟡 Premier lot livré le 2026-08-25 — les promesses sont tenues, le lit
d'ambiance reste à faire.**

- ✅ **`MON RANG` et `TOP 10` affichent enfin.** Elles passent par un verbe qui
  dit où va le texte, `MenuHub.montrer_texte()`, au lieu de `show_detail()` qui
  alimente l'en-tête. Les deux `Control` cachés deviennent **un panneau comme les
  autres**, sous une clé réservée : les rallumer tels quels aurait fait
  réapparaître la description à deux endroits, ce que la décision du 2026-08-18
  évitait à juste titre.
- ✅ **Le profil et l'historique descendent d'un étage** — `_attach_panel` au lieu
  de `_attach_screen`, comme les effets et l'audio avant eux. **Aucun des deux
  n'a été réécrit** : le contrat `HubScreen` interdit à un écran de connaître sa
  position, et c'est exactement la liberté qu'on encaisse ici. Quatre lignes
  d'accrochage, zéro ligne de contenu.
- ✅ **Les quatre libellés disent « à droite », et c'est vrai dans les quatre
  cas.** La promesse et le comportement sont alignés.
- ✅ **Le banc regarde le nœud rendu.** `test_audit_menus` vérifie `visible` **et**
  une largeur utile, plus le versant inverse — qu'une description ne s'empare pas
  du cadre. Sans ce second contrôle, corriger d'un côté ferait réapparaître le
  doublon de l'autre.
- ✅ **Le lit d'ambiance est posé** — « la carte sous la torche », option retenue
  par Adrien. Le cadre montre la carte réellement sélectionnée, rendue par le
  moteur avec les mêmes occluders que le match qui suit, révélée par une lumière
  qui dérive.

  ⚠️ **Il a fallu trois passes, et les deux premières ont raté pour des raisons
  qu'aucune mesure headless n'attrapait.** Elles valent d'être nommées, parce que
  la même erreur de méthode les relie :

  | Passe | Ce que la sonde disait | Ce que l'écran montrait |
  |---|---|---|
  | 1 | 4 rectangles, 4 occluders, texture posée, lumière qui bouge | une écharde dans une boîte noire |
  | 2 | idem, plus le sol dessiné | une tranche de carte, deux bandes sombres |
  | 3 | 96 % × 97 % du cadre, 80 % de la carte visible | *à juger* |

  **Une sonde qui compte des objets ne dit rien de ce qu'ils rendent.** Le sol
  manquait (passe 1) : la seule chose éclairée était le retrait de 3 px que la
  géométrie laisse au bord des murs. La portée était en dur et le noir était pur
  (passe 2). Et la troisième cause était **structurelle** : le nœud était rangé
  comme un panneau parmi les autres, dans un conteneur aligné en haut qui n'étire
  personne — il demandait 500 px et en obtenait 330, d'où un cadrage qui ne
  montrait que 38 % de la carte.

  **Un lit d'ambiance n'est pas un panneau : c'est ce qu'on voit quand aucun
  panneau ne parle.** Il vit désormais dans le cadre lui-même, derrière la pile,
  et recule à 18 % dès qu'un panneau s'affiche — un tableau d'historique lu
  par-dessus une arène éclairée serait illisible. **Le plancher de hauteur a
  disparu, et son absence est le signe que le nœud est enfin au bon endroit : une
  valeur qu'il faut forcer est presque toujours le symptôme d'un rangement
  fautif.**

##### Vu à l'écran le 2026-08-25, et l'historique justifie le déplacement à lui seul

Les trois états sont à la planche (`08-` à `09b-`). Le texte poussé s'affiche,
le profil s'affiche, et **l'historique se révèle être un vrai tableau** — date,
verdict teinté, durée, mode, adversaire, arme — qui **occupe naturellement toute
la largeur du cadre**. Il était jusqu'ici derrière une navigation, dans une
colonne de gauche large de 430 px. Ce n'est plus un rangement plus logique, c'est
le seul endroit où ce contenu tient.

**Ce qui reste faible, et c'est de la composition, pas du branchement :** les
trois panneaux se collent en haut d'un cadre qui fait plus de mille pixels de
haut, et le profil centre ses lignes sur toute la largeur — une phrase
d'explication court sur 900 px, ce qui se lit mal. C'est le travail de DA4.7
(hiérarchiser au lieu d'empiler), et ça vient après le lit d'ambiance.

⚠️ **Observation hors périmètre, signalée à Adrien : l'historique local est
pollué par les bancs.** La planche affiche « ce soir : 200 matchs · 98V 57D 0N ·
72 forfaits », avec des durées de 0 à 3 secondes. Ce sont les six scénarios à
deux instances de `run_duo.sh`, qui jouent de vrais matchs et les archivent dans
`user://match_history.json` — le même fichier que les parties d'Adrien. Aucun
défaut de code, mais **les bancs écrivent dans les données du joueur**, et
l'écran d'historique est donc illisible sur une machine de développement.

##### Un second défaut dormait sous le premier

`_detail_text` naissait à **un pixel de large** dans son panneau caché — mesuré
`(1.0, 1296.0)`. Visible mais large d'un pixel, il aurait rendu exactement le même
écran noir, et **on aurait cru le correctif raté.** Deux défauts empilés qui
produisent le même symptôme : corriger le premier seul aurait conduit à conclure
que le diagnostic était faux.

##### Le dégât collatéral, et il est instructif

`test_menu_hub` indexait les enfants du cadre **par position** —
`get_children()[2]`, `[3]`. L'arrivée du panneau intégré les a décalés d'un cran,
et le banc est sorti avec **deux erreurs de script et un code 0** : seul le grep
de `run_suites.sh` l'a attrapé. Remplacé par une recherche par clé,
`MenuHub.panneau()` — **une position n'est pas une identité.**

##### Ce qui a été établi, mesuré plutôt que supposé

**1. Les deux `Control` qui portent le texte du cadre sont cachés depuis leur
construction, et rien ne les rallume jamais.** `menu_hub.gd` fait
`_detail_title.hide()` et `_detail_text.hide()` ; `show_detail()` écrit
consciencieusement dans les deux, appelle `_apply_panel()`, émet son signal — et
**n'appelle jamais `show()`**. Vérifié à l'exécution : après un `show_detail()`,
les deux nœuds portent le bon texte et `visible = false`.

**2. Ce n'est pas un oubli, c'est une décision dont la conséquence n'a pas été
pesée.** Le commentaire au-dessus l'assume : *« le panneau de droite ne porte
plus la description : elle est montée dans l'en-tête, sous le titre — lire
l'explication d'une entrée ne devrait pas demander de traverser l'écran du
regard »*. Le raisonnement est bon. Ce qu'il n'a pas prévu, c'est qu'en enlevant
la description on ne laissait **rien** à la place.

**3. Et deux entrées PROMETTENT ce cadre dans leur propre libellé.** Dans
`1v1 compétitif`, `MON RANG` dit « affichés **à droite** » et `TOP 10` dit
« affiché **à droite** — sans quitter cet écran ». Toutes deux appellent
`hub.show_detail(...)`, donc écrivent dans les nœuds invisibles : **on clique, le
texte promet, il ne se passe rien.** C'est un cul-de-sac silencieux sur l'écran
qui porte la Phase 6.

**4. La grammaire de l'interface est incohérente, et c'est le fond du sujet.**
Deux mécanismes coexistent :

| Mécanisme | Ce qu'il fait | Qui l'emploie |
|---|---|---|
| `_attach_panel()` | le contenu **remplit le cadre de droite** | Contrôles, Affichage, Effets, Audio |
| `_attach_screen()` | le contenu **remplace la colonne de gauche** | Profil, Historique, Classement, Mise à jour |

Adrien le formule ainsi : *« mon profil doit s'afficher à droite, comme
l'historique, comme les scores, comme le top 10 »*. Les quatre écrans de
réglages le font déjà ; les quatre écrans de méta ne le font pas. Rien ne
justifie la différence — `HubScreen` interdit par contrat à un écran de connaître
sa position dans l'arborescence, **précisément pour qu'on puisse le déplacer**.

##### Ce qui reste à trancher : que met-on dans ce cadre au survol ?

Vider le défaut ne suffit pas — il faut **quelque chose qui donne envie**.
Demande d'Adrien : « peut-être un screenshot du jeu ? du mode actuel ? Faut que
ce soit sexy. » Propositions faites le 2026-08-24, **arbitrage en attente**, voir
le chat de la session DA4. À vérifier une fois posé : les quatre écrans de méta
et le parcours `1v1 compétitif` en entier.

##### Pourquoi aucune suite ne l'a vu, et c'est la partie qui doit changer

`tools/test_audit_menus.gd` existe **exactement pour ça** — son titre est
« aucune entrée ne laisse le cadre de droite vide » — et il est vert. Il lit
`_entry_details` et vérifie que chaque entrée porte un `texte` **ou** un
`panneau`. Les données sont là, elles ont toujours été là. **Ce qui manque, c'est
l'affichage**, et il n'a jamais été regardé. Le banc vérifie qu'on a *de quoi*
remplir le cadre, pas qu'il *est* rempli — troisième occurrence du motif consigné
le 2026-08-19, *ce qu'on voit n'a pas de nom, donc rien ne le tient*.

- **DA4.1 HUD en 9-slice dessinés** ✅ **livrée le 2026-08-25** — le cadre du HUD
  était un rectangle arrondi de 2 px avec une ombre portée, c'est-à-dire la
  signature exacte du panneau qu'aucune main n'a dessiné. Il porte une plaque de
  matériel usée, en 9-slice de marge 32 px.

  **La texture est un masque gris et `modulate_color` y met la couleur du
  joueur** : un seul fichier sert les deux HUD, comme la torche des curseurs.
  C'est ce qui permet de retoucher `BLEU` ou `ROUGE` dans la charte sans qu'aucune
  texture soit à refaire. Le repli sur l'ancien `StyleBoxFlat` est conservé : un
  HUD sans cadre serait deux blocs de texte flottant sur l'arène, alors qu'un
  cadre tracé reste un cadre. *(C — généré, procédé DA1.5)*
- **DA4.2 Chrono, score, ping en chiffres tabulaires** ✅ **livrée le 2026-08-24**
  — et la formulation d'origine était trop faible. « Ils cessent de sauter »
  décrivait un confort ; ce qui est posé est une **interdiction mesurée**, celle
  de la fonte d'enseigne sur tout ce qui se remplace en place, vérifiée sur sept
  compteurs par `tools/test_habillage.gd`. Les chiffres ne sautaient déjà pas —
  Oxanium est tabulaire par construction depuis DA1.2 — mais **rien n'empêchait
  qu'ils se mettent à sauter**, et l'item ne demandait que l'état, pas la
  garantie. *(S)*
- **DA4.3 Les chiffres de dégâts en fonte display** ✅ **livrée le 2026-08-25** —
  la moitié « fonte » l'était depuis DA1 ; restait le contour, et il portait un
  défaut mesurable.

  **Il valait 8 px, fixe, pour une taille qui va de 19 à 42.** Un effleurement
  recevait donc un halo de **42 % de sa propre taille** et un carreau d'arbalète
  de 19 % : **les petits chiffres étaient noyés dans leur contour, les gros
  non.** C'est l'inverse exact de ce que V4.5 cherche à faire — *le poids du
  chiffre EST l'information* — et un halo qui épaissit d'autant plus qu'il est
  petit écrase la différence qu'on venait d'établir.

  Le contour est désormais un **rapport** (11 %), soit 2 à 5 px sur toute
  l'échelle : assez pour détacher le chiffre d'un mur éclairé, jamais assez pour
  boucher les contre-formes de la fonte d'affichage, qui est ultra-condensée et
  les a étroites. L'ombre suit la même échelle et porte ce que le contour ne peut
  pas — une **direction** : un contour uniforme colle le chiffre à l'écran, une
  ombre décalée le pose au-dessus de la scène.

  **Troisième occurrence du même motif en deux jours** — après le coefficient de
  case du code de salon et la portée de lumière du panneau d'arène : *une valeur
  absolue là où il fallait un rapport, juste pour un seul cas et fausse pour tous
  les autres.* *(S)*
- **DA4.4 Le bandeau FATAL dessiné** ✅ **livrée le 2026-08-25** — le mot le plus
  fort du jeu était posé sur rien. Il a maintenant une plaque de tôle frappée,
  bords rongés, l'encre a bavé.

  **Le mot reste du TEXTE**, dans la fonte d'enseigne, et la texture ne porte que
  le support : c'est ce qui laisse « FATAL — POMPE » s'allonger avec le nom de
  l'arme sans qu'aucune image soit à refaire. Enfant du `Label` et dessiné
  dessous, donc il suit le mot dans son envol sans qu'on anime deux nœuds.

  Teinté en `CARMIN` et non `ROUGE` — le rouge vu à l'intensité d'une chose qui
  ne s'éclaire plus elle-même — pour que le mot en `ROUGE` ressorte dessus. Et
  non éclairé, comme le mot qu'il porte : un support de texte qui s'assombrirait
  hors de la torche disparaîtrait au pire moment. *(C — généré, procédé DA1.5)*
- **DA4.5 La killcam habillée** ✅ **livrée le 2026-08-25** — les trois volets.

  **Le grain vient d'une texture, plus d'un calcul.** `fract(sin(dot(...)))`
  produit un bruit **blanc** : chaque pixel indépendant de son voisin. Une bande
  vidéo usée ne fait pas ça — elle porte de la poussière, des rayures
  verticales, des zones plus fatiguées que d'autres. **Le hasard uniforme ne
  ressemble à aucune matière**, et c'est ce qui donnait à la killcam son air de
  filtre plutôt que d'archive. La planche défile en diagonale à deux vitesses
  premières entre elles, ce qui retarde longtemps la répétition visible.

  ⚠️ **Le coefficient a dû doubler, et l'oublier aurait effacé l'effet en
  silence** : une texture centrée sur zéro n'a que la moitié de l'amplitude d'un
  `fract()` qui va de 0 à 1. Garder l'ancien facteur aurait donné un grain deux
  fois plus faible, sans erreur et sans que personne sache pourquoi.

  **Le cadre de moniteur vit dans l'INTERFACE, pas dans l'arène.** Le voile de
  killcam, lui, y est reparenté pour passer sous les lumières ; le cadre n'a rien
  à y faire — c'est un objet d'affichage, et l'y mettre l'aurait fait
  **s'assombrir hors des torches**. Un cadre de moniteur qui s'éteint quand on ne
  l'éclaire pas. `NinePatchRect` à 64 px de marge, sur une texture dont le centre
  est vérifié à alpha zéro exact.

  **Le timecode était déjà réglé** par DA4.2 : il est en registre appareil, donc
  tabulaire par construction. C'est ce que « fonte mono » demandait — la propriété
  voulue est la chasse fixe, pas la famille. *(C — généré, procédé DA1.5)*
- **DA4.6 Le trait balistique en schéma** — le pointillé V6.2 stylé relevé
  d'expert : flèches, cote de distance, fonte mono. La killcam-professeur
  devient une pièce signature. *(S)*
- **DA4.7 La bannière de fin composée** 🟡 **en grande partie livrée le
  2026-08-25** — verdict, score de session et série sont désormais hiérarchisés
  au lieu d'être aplatis. Ce qui manque : « effleuré : 13 px », voir ci-dessous.

  **Ce qu'affichait la fin de match : `SESSION : 2 - 1   ·   3 D'AFFILÉE`.**
  Trois informations de natures différentes, séparées par des points médians,
  toutes du même poids, à 19 px en `DIM` — et écrites par `game_state.gd` **dans
  le label des descriptions d'entrées**. Rien n'y avait de rang, donc l'œil n'y
  avait pas d'entrée.

  Composé, chaque chose reprend son registre : le score est un **compteur**
  (appareil, tabulaire, chaque nombre teinté de la couleur de son joueur, ce qui
  le rend lisible sans lire le libellé) ; la série est un **cri** (enseigne,
  ambre) et n'apparaît que lorsqu'elle existe.

  ⚠️ **Un effet a failli s'éteindre en silence, et c'est le fait à retenir.**
  V3.6 — l'annonce du score, qui le fait monter de dix pixels dans la couleur de
  celui qui vient de marquer — animait `game_over_score`. Le score ayant
  déménagé dans le bloc composé, elle serait restée branchée sur un `Label` vide
  et invisible : elle aurait continué de tourner, sans erreur, sans rien animer.
  **Déplacer une donnée déplace tout ce qui la regarde**, et rien dans le
  langage ne le signale.

  ⬜ **Reste : « effleuré : 13 px ».** La donnée existe (`player.gd`,
  `last_fatal_perp`) mais elle est consommée sur place, en espace-monde, pour un
  label de l'arène. L'amener jusqu'à l'écran de fin demande un chemin
  `player` → `game_state` → `ui`, c'est-à-dire deux fichiers du domaine « game
  feel ». **À demander avant de le faire.** *(S)*
- **DA4.8 Les vignettes de la galerie encadrées** ✅ **livrée le 2026-08-25** —
  et elle a fait tomber une infraction à une décision actée.

  **La vignette est montée dans un cadre**, fond noir du monde, filet `LINE` :
  une image posée sur un fond se lit comme une image ; la même image serrée dans
  un cadre se lit comme un **objet** — une plaque, une pièce qu'on choisit.

  **La provenance quitte la pile de texte pour devenir une pastille sur le
  cadre.** Elle y gagne deux fois : le bloc passe de trois lignes centrées à deux
  — un titre et sa légende, donc une hiérarchie — et la mention se lit sans
  quitter l'image qu'elle qualifie. Le titre monte d'une **graisse** plutôt que
  d'une taille : l'échelle n'a que six crans, et c'est justement à ça que servent
  les quatre poids.

  ⚠️ **`texture_filter = NEAREST` était posé à DEUX endroits, contre la décision
  DA5.6 du 2026-08-24** — *« filtrage linéaire et mipmaps, **aucune texture en
  `nearest`** »* — et **avec un commentaire qui le défendait** : « pixels francs,
  une miniature ne doit pas devenir floue ».

  **Le commentaire décrivait un vrai symptôme et se trompait de cause.** La
  vignette n'était pas floue à cause du filtrage : elle était **agrandie** —
  rendue à 96 px et affichée sur ~124 dans la galerie, rendue à 80 et affichée
  sur 160 points HiDPI dans la fiche de carte. La décision disait d'ailleurs quoi
  faire à la place, dans la même phrase : *« la résolution d'un asset se choisit
  sur la densité de texels à l'écran »*. Les deux rendus passent à 256 et 160 ;
  plus rien n'est agrandi, et le filtrage linéaire n'a plus rien à flouter.

  C'est la deuxième fois dans ce lot qu'un contournement **portait sa propre
  justification en commentaire** — après les coefficients de dimensionnement du
  code de salon. Un commentaire qui défend une entorse est le meilleur endroit
  où chercher la cause qu'on n'a pas traitée. *(S)*
- **DA4.9 Le code de salon en cases display** ✅ **livrée le 2026-08-24** — les
  six cases sont en `BigShouldersDisplay` à `T_VERDICT`, et **le registre suit le
  GABARIT, pas l'appelant** : gabarit fixe = un code, donc l'enseigne ; mesure
  libre = une adresse IP, donc l'appareil et ses chiffres tabulaires. Le lier au
  gabarit le rend impossible à contredire — la seule disposition qui protège
  d'une fonte non tabulaire (chaque signe centré dans sa propre case) est
  exactement celle qui l'autorise. Bénéfice de bord : l'adresse IP passe au bon
  registre **sans toucher `ui.gd`**, tenu par une autre session.

  ⚠️ **Et le lot a trouvé au passage un défaut qui n'était pas celui qu'on
  cherchait.** On soupçonnait les deux coefficients de dimensionnement
  (`× 0,87`, `× 1,27`) de casser sous la nouvelle fonte ; mesurés, ils tiennent
  à 4 % près. **Ils étaient faux depuis le début sur Oxanium** — 26,1 px de case
  pour une lettre de 28,0 px —, et invisibles parce que les six cases étaient
  trop étroites *de la même quantité*. Détail en « Pièges connus », *une erreur
  uniforme ne ressemble pas à une erreur, elle ressemble à un choix*. La case se
  mesure désormais sur le glyphe le plus large de `LobbyCode.ALPHABET`, dans la
  fonte réellement posée.

  La promesse « un `I` et un `W` occupent la même case » existait en commentaire
  depuis la vague M et **ne reposait sur rien** : elle est maintenant vérifiée en
  gravant six `W` puis six `J` et en comparant les deux largeurs. *(S)*
- **DA4.10 Les glyphes manette officiels** ✅ **déjà faite — constaté le
  2026-08-25, aucun travail requis.** `assets/ui/prompts/` porte **seize SVG**
  (croix, rond, carré, triangle, les quatre flèches, L1/L2/L3, R1/R2/R3, share,
  options) **et ils sont câblés** : `_get_joypad_btn_info()` associe chaque
  `JOY_BUTTON_*` à son fichier, `_apply_btn_info()` le charge et efface le
  libellé texte.

  **Le repli est propre, et c'est ce qui rend l'item réellement clos** :
  `ResourceLoader.exists()` garde le chargement, et un glyphe absent redonne le
  texte au lieu d'un bouton muet. C'est la règle « câbler, taire, diagnostiquer »
  appliquée sans qu'on la lui ait demandée.

  ⚠️ **Un seul fichier manque, et il ne sera pas comblé** : `ps.svg`, référencé
  par `JOY_BUTTON_GUIDE`. C'est un symbole déposé de Sony — le repli en texte
  « PS » est la bonne réponse, pas une texture à produire. Signalé pour que
  personne ne le « corrige ».

  **Ce que l'item enseigne, au-delà de lui-même** : c'est la troisième fois en
  deux jours qu'on trouve des assets **livrés et non employés** ou **employés
  sans que la feuille de route le sache** — après la fonte d'affichage (DA4) et
  les quatre stingers (DA3.4). Une liste d'items ne mesure pas l'état du dépôt ;
  elle mesure ce que quelqu'un a pensé à y écrire. *(G)*
- **DA4.11 Le rebinding visuel** — un clavier dessiné plutôt qu'une liste de
  noms de touches. *(S + G)*
- **DA4.12 Les états vides illustrés** ✅ **livrée le 2026-08-25** — historique
  sans match, galerie sans carte. Une phrase seule au milieu d'un grand vide se
  lit comme **un écran qui a échoué à charger** ; la même phrase sous une image
  se lit comme une réponse — *il n'y a rien, et c'est normal*. Ce n'est pas
  décoratif : c'est la différence entre « le jeu est cassé » et « à vous de
  jouer ».

  Les deux dessins sont teintés en `LINE` et non `DIM` : une illustration
  d'absence doit rester **en retrait de la phrase qu'elle accompagne**, sinon
  elle devient le sujet. *(C — généré, procédé DA1.5)*
- **DA4.13 Les transitions d'écran signature** 🟡 **entamée le 2026-08-25** — et
  le constat est le même que pour les fontes.

  **DA1.8 a livré trois courbes maison** (`ENTREE`, `SORTIE`, `REBOND`) et un
  point d'entrée unique, `Charte.animer()`, précisément pour remplacer les
  `TRANS_*` de Godot. Compté ce jour : **7 appels à `Charte.animer()` contre 31
  `set_trans(Tween.TRANS_*)`**, répartis sur **cinq transitions différentes** —
  `CUBIC`, `SINE`, `BACK`, `QUAD`, `EXPO`. Le vocabulaire est livré, le code parle
  encore l'ancien.

  **Trois sites convertis**, choisis parce qu'ils sont les plus vus : le décompte
  3-2-1, l'appui sur une tuile de galerie, et l'annonce du score de fin. Les
  durées posées à la main (0,06 / 0,45 / 0,9 s) passent aux trois crans de
  l'échelle.

  ⬜ **Reste cinq sites** — `menu_title.gd` (2), `map_editor.gd` (2),
  `audio_manager.gd` (1), plus deux dans `ui.gd`. Aucun n'est difficile ; ils
  demandent seulement de connaître la valeur de départ, `Charte.animer()`
  passant par `tween_method` et non par `tween_property`.

  **Et l'item demandait autre chose que ce qu'il dit.** « Un seul motif de
  fondu » suppose que le problème est le fondu ; il est plus large — c'est
  l'unité du geste. Le rebond sous un bouton, sous une tuile et sous le décompte
  est ce qui donne la sensation qu'une seule main a animé l'écran. *(S)*
- **DA4.14 Les curseurs J1/J2 dessinés** ✅ **livrée le 2026-08-25** — une petite
  torche se pose à gauche du cadre de sélection, teintée par `modulate` : **un
  seul fichier sert les deux joueurs**, et retoucher `BLEU` ou `ROUGE` dans la
  charte ne demande aucune regénération.

  ⚠️ **Le liseré RESTE, et c'est une décision.** Il dit *quelle zone* est
  sélectionnée, ce qu'une icône ne peut pas dire ; la torche dit *qui*
  sélectionne. Les deux ne font pas le même travail, et l'item ne demandait de
  supprimer ni l'un ni l'autre. La torche se pose **à côté** du cadre, hors de
  lui : un signe de propriété ne se superpose pas à ce qu'il désigne. *(C —
  généré, procédé DA1.5)*
- **DA4.15 L'éditeur de cartes aligné** — icônes d'outils dessinées, palette de
  l'éditeur sous la bible. *(S + G)*
- **DA4.16 Le panneau F3 lui-même** ✅ **livrée le 2026-08-25** — et il disait
  quelque chose, en effet : le contraire de ce qu'on voulait.

  **Il était bordé d'`AMBRE`.** Or l'ambre veut dire *ce qui appelle* — le feu,
  la mise en garde, le chrono de dernière minute. Un cadre de diagnostic ouvert
  en permanence pendant qu'on joue n'appelle rien, il se consulte. Il porte
  maintenant `LINE` et `ACIER`, la couleur que l'interface s'est donnée en DA1.4
  précisément pour cesser d'emprunter celles des autres. **C'est la même faute
  que les entrées « lanceur » du 2026-08-18**, au même endroit du raisonnement.

  **Et son contenu était une ligne à barres verticales** — `DEBUG | FPS 120 |
  Ping 42 ms | Lumières 8 | Particules 30/200 | …`, tout en or, à 12 px. Ce
  n'est pas seulement laid : **il faut relire toute la ligne pour trouver une
  valeur**, à l'instant précis où l'on veut en vérifier une seule. C'est
  désormais une grille de deux colonnes — libellés en `DIM` à gauche, valeurs
  tabulaires alignées à droite : on lit une colonne, pas une phrase.

  **Trois mesures prennent la triade d'instrument** — images par seconde, ping,
  saturation du bassin de particules. Le vert est interdit dans l'arène par la
  règle 3 de la charte, mais le panneau F3 **est** de l'interface : c'est même
  le lieu le plus légitime de la triade, un tableau de bord existant pour dire
  d'un coup d'œil si la valeur va, alerte ou faute.

  ⚠️ **Les seuils ne sont pas choisis ici, et c'est ce qui les rend justes.**
  60 images/s est la cible de `bench_framerate` ; 60 et 120 ms sont exactement
  les paliers que `_update_ping_label()` emploie déjà pour le HUD. Un panneau de
  diagnostic avec ses propres seuils dirait « ça va » pendant que le HUD dit
  « attention ». *(S)*
- **DA4.17 Les messages d'erreur humanisés** ✅ **livrée le 2026-08-25** — et
  l'item se trompait de cible, ce qui vaut d'être noté.

  **Les textes étaient déjà humains.** « Impossible de lire l'arène de l'hôte…
  la cause la plus courante est un écart de version entre les deux jeux » nomme
  le problème, dit ce qui n'a pas eu lieu et propose un remède. Les sessions
  précédentes avaient fait ce travail sans qu'un item le réclame. Il n'y avait
  **aucun texte brut à humaniser.**

  **Ce qui manquait était la présentation : tout se ressemblait.**
  « Déconnexion », « Appariement » et « Erreur » sortaient dans le même or, le
  même cadre, le même bouton — le joueur ne pouvait pas savoir, avant d'avoir
  lu, s'il venait de perdre sa partie ou de recevoir une information. La triade
  d'instrument le dit maintenant en une teinte, avant la première syllabe :
  `INFORMATION` en acier, `ATTENTION` en ambre, `FAUTE` en rouge, sur le titre
  et le filet.

  Deux titres changent aussi. **« Erreur » ne disait rien** — le joueur sait
  déjà que ça a raté, il veut savoir *quoi* : c'est « Connexion impossible ». Et
  « Appariement » devient « Appariement indisponible », classé `ATTENTION` et
  non `FAUTE` : une installation sans Epic n'est pas en faute, le jeu se joue
  normalement, seul l'appariement manque.

  ⚠️ **Deux règles posées, et elles vont à l'encontre du réflexe :**

  - **Le corps du message reste toujours en `HALOGENE`, jamais rouge.** La
    charte l'écrit à propos de `ROUGE` : contraste 4,9:1 sur `SURFACE`,
    « suffisant pour un verdict en gros, insuffisant pour une phrase ». Teinter
    le paragraphe rendrait l'explication plus dure à lire **au moment précis où
    elle est le plus utile**. Seuls le titre et le filet portent la couleur.
  - **Le bouton ne prend jamais la couleur du registre.** Il ne détruit rien, il
    ferme. Un « OK » rouge se lit comme une action dangereuse alors qu'il n'y a
    plus rien à décider. *(S)*

### DA5 — La chasse aux défauts (l'audit « rien par défaut »)

- **DA5.1 L'audit zéro-défaut** — une session parcourt chaque écran et liste
  toute valeur par défaut encore visible : fonte, couleur, easing, curseur,
  son manquant. Le livrable est la liste, cochée ensuite. *(S)*
- **DA5.2 Blanc pur et noir pur interdits** hors fond du monde — tout passe au
  blanc cassé et au noir de la bible. *(S)*
- **DA5.3 Plus un cercle parfait visible** — toute lumière ou particule
  circulaire passe en texture. *(S + G)*
- **DA5.4 Le grain unifié** — un seul grain plein écran très subtil : le vernis
  qui « colle » tous les éléments entre eux, l'arme n°1 contre l'effet
  collage. *(S)*
- **DA5.5 L'aberration chromatique réservée** — un liseré chromatique léger sur
  les grands moments seulement (kill, éblouissement) ; jamais en continu. *(S)*
- **DA5.6 La résolution assumée** ✅ **TRANCHÉ le 2026-08-24 : smooth.**
  Filtrage linéaire, mipmaps, aucune texture en `nearest` ; la résolution se
  choisit sur la densité de texels à l'écran. Raison en « Décisions actées ».
  *(Adrien)*
- **DA5.7 Un seul style d'outline/ombre de texte** — défini dans le thème, plus
  jamais au cas par cas. *(S)*
- **DA5.8 Recalibrer la vague M sous la nouvelle DA** ✅ **FAIT le 2026-08-24.**
  Les 15 effets de menus sont procéduraux : sous la nouvelle palette et les
  nouvelles fontes ils deviennent un écrin ; sans ça, ils amplifient le look
  actuel. Détail ci-dessous. *(S)*

#### DA5.8 — ce que le recalibrage a trouvé

**Trois shaders portaient l'ancienne palette, et la passe DA1.4 ne les avait pas
vus : elle ne balayait que les `.gd`.** Un `.gdshader` est un endroit où une
couleur se cache bien — d'autant mieux que deux d'entre elles n'étaient **jamais
poussées depuis GDScript** et vivaient donc en dur, invisibles à toute recherche
faite du côté du script.

| Où | Ce qui restait | Devenu |
|---|---|---|
| `menu_backdrop.gdshader` | les deux territoires P1/P2, en `const` | uniformes poussés depuis la charte |
| `menu_title.gdshader` | `CHAUD` et `teinte_verdict`, en dur | dérivés de `LUMIERE` et de `ETAT_OK` |
| `menu_glass.gdshader` | défaut `teinte_focus` = ancien cyan | aligné (il est écrasé, mais un défaut périmé se lit comme une intention) |
| `menu_skeleton.gdshader` | balayage **achromatique** | la température d'une torche |

Le dernier n'est pas une couleur oubliée mais une **contradiction** : la fiche de
M13 dit « une torche qui fouille des étagères dans le noir », et la bande était
peinte en blanc pur. L'effet contredisait ce qu'il racontait.

**Les teintes multiplicatives sont NORMALISÉES avant d'être poussées.** Le shader
les emploie en facteur (`col * teinte`) : une couleur de la charte passée telle
quelle assombrirait au lieu de teinter. `MenuTitre._teinte()` divise par le canal
le plus fort puis ramène vers le blanc d'une force qui dose l'écart. Sans ça, le
titre aurait perdu en luminance à chaque crête d'onde.

#### M1 — le cas d'école, et il était visible à l'œil

Le cadran de titre projetait son ombre depuis **`size.y * 0.72`** — 72 % de la
hauteur du conteneur. Une valeur juste tant que le titre était en fonte par
défaut à 60 px. Passé en Big Shoulders à 68, dont les métriques n'ont rien à
voir, **l'ombre s'est retrouvée au-DESSUS du mot** : elle ne se lisait plus comme
une ombre mais comme une bavure d'affichage.

Elle est désormais ancrée au **rectangle réel de la cible**, donc indépendante de
la fonte et de la taille. Et son écrasement — 0,34, calibré contre une fonte
large — est passé à **0,55** : avec une display ultra-condensée, une copie
couchée à 34 % n'a plus assez d'encre pour se lire comme un mot, elle devient un
trait. *Une même valeur d'écrasement ne dit pas la même chose selon la chasse.*

#### M2 s'est réparé tout seul, et c'est vérifiable

Sa fiche promettait « le curseur cyan laisse un fantôme **braise**, le rouge un
fantôme **d'eau verte** ». La rémanence calcule la complémentaire de la couleur
du curseur — et sous l'ancienne palette **saturée à 100 %**, ces complémentaires
étaient un **rouge pur** `(1.0, 0.06, 0.0)` et un **vert pur** `(0.0, 1.0, 0.67)`.
Ni braise, ni eau.

Sous la charte : `(0.71, 0.28, 0.03)` et `(0.05, 0.71, 0.67)`. **L'effet avait été
écrit pour une palette qui n'existait pas encore**, et sa fiche décrivait le
résultat qu'il aurait *si* la saturation était plafonnée. Elle l'est.

#### Ce que M9 n'a pas eu besoin qu'on change, et pourquoi le dire

La torche du curseur reste peinte aux couleurs des joueurs, alors que la nouvelle
règle dit « ce qui révèle est chaud ». Ce n'est pas un oubli : **le curseur n'est
pas dans le monde, il est dans l'appareil.** La fiction d'origine — « le curseur
est une torche » — devient sous le nouveau principe « le curseur est une diode
qu'on promène », et les deux tiennent. Aucune couleur ne bouge.

Corrigé au passage : son commentaire annonçait « trois centièmes » pour une
valeur de cinq. Vérifié — la luminance ajoutée vaut ~0,011, moins du tiers du
plafond que le fond s'impose (`LUM_MAX = 0,035`). Les deux effets tenaient le
même contrat sans qu'aucun ne le dise.

#### La planche photographiait un écran que personne ne voit

**Elle appelait `grab_focus()`**, alors que le cadre de droite se remplit par
`MenuHub.reveal_entry()` — le relais posé le 2026-08-18, quand on a découvert que
les curseurs maison ne déclenchent jamais `focus_entered`. La planche empruntait
donc un chemin **que personne ne prend**. Corrigé.

**Et elle ne voyait aucun des écrans de fin**, où vivent deux des quinze effets :
la température du verdict (M11) et l'ombre projetée par VICTOIRE / DÉFAITE /
ÉGALITÉ (M1). Ils avaient donc été recalibrés à l'aveugle — ce que cet outil
existe précisément pour empêcher. Les trois verdicts sont désormais au cadre
(`20-`, `21-`, `22-`), et deux décisions anciennes s'y vérifient enfin : le
verdict prend la couleur du **vainqueur** en écran partagé, et l'égalité reste
**grise**, « parce que le blanc est la couleur de ce qui s'affirme ».

#### ⚠️ Signalé, pas corrigé — l'écran des EFFETS est vide

Hors périmètre de DA5.8, donc signalé comme l'exige le protocole.

**Le cadre de droite de la rubrique « Effets » n'affiche que sa ligne de
contexte : aucune rangée de réglage.** Vu sur la planche, et **identique avant le
chantier** — ce n'est pas une régression de la charte.

Ce qui est établi : les rangées **existent** dans l'arbre (contenu mesuré à
51 741 px de haut), et le `ScrollContainer` qui les porte a une hauteur de **0**.
Ce n'est donc pas un contenu manquant, c'est une mise en page qui s'effondre.
Ce qui n'est **pas** établi : la cause exacte — je n'ai pas poussé plus loin.

**Aucune suite ne peut l'attraper telle qu'elles sont écrites** : elles vérifient
que les rangées sont là, pas qu'on les voit. Troisième occurrence de ce motif
dans la même journée.

### DA6 — Les moments qu'on screenshote

- **DA6.1 L'écran de victoire en affiche** — composé comme un poster, pas comme
  un menu. *(S + C)*
- **DA6.2 La photo du gel fatal signée** — le gel V2.1 existe ; le cadrer, le
  titrer, le dater : chaque kill produit une image montrable. *(S)*
- **DA6.3 Les cartes de fin de soirée illustrées** (= V6.10). *(S + C)*
- **DA6.4 Le bilan de session partageable** — la même carte exportée en image.
  *(S)*
- **DA6.5 La séquence power-on** — le lancement du jeu comme un allumage (V6.8
  l'esquisse) : logo, souffle, lumière. *(S + C)*

### DA7 — Le dispensable assumé (quand le reste est fait)

- **DA7.1 Capsule et bannière de boutique** (Steam/itch). *(C)*
- **DA7.2 Le trailer de 60 secondes.** *(C)*
- **DA7.3 Presskit et screenshots composés.** *(S + Adrien)*
- **DA7.4 Un site d'une page.** *(S)*
- **DA7.5 Palettes alternatives déblocables** — la bible déclinée (nocturne,
  sépia), récompenses de rangs. *(S)*
- **DA7.6 Skins de torche et de viseur** — mêmes emplacements, autres cookies.
  *(C)*
- **DA7.7 Le thème du menu réinterprété** — variante saisonnière ou de rang du
  stem de menu. *(C)*
- **DA7.8 L'easter egg du logo** — la bougie du wordmark qui s'éteint si on
  reste trop longtemps sans jouer. *(S, après DA1.6)*

~~**Le départ au meilleur ratio, dès qu'Adrien donne le feu vert :** DA1.2, DA1.3,
DA1.4, DA1.8~~ — **fait le 2026-08-24**, avec DA1.1 et DA1.9.

**Le prochain départ au meilleur ratio :** le lot audio **DA3.1-DA3.3** (déjà
câblé de bout en bout, il n'attend que des fichiers) et la commande de **DA2.1**,
le cookie de torche peint — c'est « la plus grosse ancre du jeu », et elle passe
désormais sur une palette arrêtée, donc elle ne sera pas à refaire.

**Et DA5.8 est devenu urgent plutôt qu'optionnel.** Les quinze effets de la vague
M ont été écrits sous l'ancienne palette ; ils tournent maintenant sous la
nouvelle sans avoir été jugés à l'œil un par un. Ils la servent ou ils la
trahissent, et rien ne le dira tout seul.

---

## Chantier — la spatialisation du son (inscrit le 2026-08-25)

**Le constat qui ouvre le chantier : le jeu n'a pas d'oreille.** Le son de
manche est pourtant positionnel de bout en bout — `AudioManager` tient un pool
de seize `AudioStreamPlayer2D`, les pas, les tirs et les impacts s'y jouent à
leur position réelle, et les seize prises de tir sont **forcées en mono à
l'import** précisément pour que la source reste un point (V4.1, *« savoir d'où
vient le coup est l'information »*). Tout ce travail vise juste. **Rien
n'écoute depuis la place du joueur.**

Mesuré le 2026-08-25 en headless, sur l'arbre courant :

```
root.is_audio_listener_2d = true          ← le seul auditeur du jeu
root.get_audio_listener_2d = <null>       ← aucun AudioListener2D nulle part
root.canvas_transform      = identité     ← il ne suit rien
p2d.world_2d == root.world_2d ? true      ← le pool vit dans le monde de la racine
SubViewport neuf : world_2d == root ? false
```

Le pool est enfant de l'autoload, donc dans le `World2D` de la **racine** ; le
jeu vit dans celui du `SubViewport`, où sont les caméras. Un
`AudioStreamPlayer2D` ne s'adresse qu'aux viewports de **son** monde : les
caméras de jeu ne l'entendent jamais. Reste la racine, sans caméra ni auditeur —
Godot pose alors l'oreille au centre de l'écran virtuel, soit **(960, 540) en
coordonnées monde, fixe**. Une carte 20×20 en tuiles de 35 px s'étend de −35 à
735 px : **l'oreille est posée en dehors de la carte, et elle n'en bouge
jamais.**

Ce que ça produit, et qui ne se devine à aucun moment en jouant :

- le panoramique dit **où le son est sur la carte**, pas où il est par rapport à
  soi — deux joueurs aux deux bouts entendent le même panoramique du même pas ;
- **avancer vers l'adversaire ne rend pas ses pas plus forts** ;
- l'écart de volume d'un bout à l'autre de la carte vaut environ **2 dB**.

Autrement dit, dans un jeu dont la proposition est « la seule information est la
lumière », le second canal d'information n'est pas imprécis : **il est faux**,
et il l'est d'une façon qui s'écoute comme un fonctionnement normal. Le piège
est consigné à sa section.

**Périmètre, décidé avec Adrien le 2026-08-25 : le 1v1 SANS écran partagé
d'abord.** C'est le cas favorable, et il existe déjà — en ligne comme à
l'entraînement, une seule vue est affichée. Une vue, un joueur local, une sortie
stéréo : l'oreille a une place évidente. L'écran partagé se traite après (S6).

Les sept items ne sont pas de même nature, et c'est ainsi qu'il faut les lire :
**S1 est un défaut**, S2 et S4 sont des **réglages qui se jugent à l'oreille**,
S3 et S7 étaient des **arbitrages qui appartiennent à Adrien**, S5 est déjà
écrit ailleurs (V5.12) et attend S1, S6 est hors périmètre.

**Les deux arbitrages sont tombés le 2026-08-25, le jour même :** S3 **oui** —
un mur doit étouffer, « naturellement par la réverb » — et S7 **on reste en
2D**. Ce qui attend encore l'oreille d'Adrien, et non un choix de conception,
ce sont les dosages : la portée de S2 et l'équilibre sec/réverbéré de S3.

- **S1 — L'oreille rejoint le joueur. ✅ FAIT, sur `main`** (`4d8a85e`, fusionné
  par `e3e1b34`), avec une suite headless (`tools/test_oreille.gd`) qui
  verrouille le défaut au lieu de le corriger une fois.

  ⚠️ *Cette ligne a dit « dans un worktree, pas sur `main` » pendant vingt
  minutes, et c'était vrai en l'écrivant : `origin` a bougé entre-temps. Sur un
  arbre que six sessions partagent, **un état écrit vieillit plus vite qu'il ne
  se relit** — c'est une raison de plus de ne mesurer qu'au moment de décider.*

  **Trois pièces, pas deux** — la troisième avait été manquée par cette section
  et mesurée par la branche : un `SubViewport` n'est **pas** une oreille par
  défaut (`audio_listener_enable_2d` vaut `false`).

  **Et deux défauts se cachaient derrière le correctif, tous deux corrigés le
  2026-08-25 dans le worktree `audio-dosage`.** Ils méritent d'être lus
  ensemble, parce qu'ils forment une chaîne où chaque maillon rend le suivant
  invisible :

  1. **La règle interrogeait le transport** (`local_idx >= 0`) quand la vraie
     question est *« y a-t-il exactement un auditeur devant l'écran ? »*.
     L'entraînement — une vue, un joueur, une sortie — était donc exclu avec
     l'écran partagé, alors que la raison d'exclure celui-ci (deux joueurs, une
     paire d'enceintes) ne le concerne pas. Or **l'entraînement est le seul mode
     solo du jeu**, donc le seul où l'on peut doser un réglage sonore sans
     monter deux instances : le mode dont on avait le plus besoin était le seul
     privé d'oreille.
  2. **Le porteur était faux dès qu'on corrigeait la règle.** `p1 if idx == 0
     else p2` désigne **J2** quand l'index vaut −1 — en entraînement, un joueur
     caché et immobile. L'oreille se serait posée sur un fantôme et le symptôme
     aurait été « le panoramique ne bouge pas » : le défaut d'avant, sous un
     correctif qui a l'air posé.
  3. **Et le drapeau se lit trop tôt.** L'entraînement passe par
     `_do_start_round`, **qui remet `training_mode` à faux avant de rendre la
     main** — c'est écrit dans son propre commentaire. Une règle qui interroge
     le drapeau depuis l'intérieur du démarrage lit donc toujours « non ». Il
     faut un second appel, là où le drapeau est enfin vrai. Sans lui, les deux
     correctifs précédents auraient été posés, justes, et sans aucun effet.

  **La leçon, et c'est la deuxième fois que l'entraînement l'enseigne :** la
  feuille de route porte déjà « Le regard suit le joueur, pas le score » — le
  suivi de caméra vivait dans `if round_active:`, l'entraînement désarme la
  manche, la caméra ne suivait donc jamais. Même faute, même mode. **Ce n'est
  pas une coïncidence : l'entraînement est le seul endroit du jeu qui sépare des
  concepts que le code confond** — être en ligne, être seul, jouer une manche
  comptée. Tout drapeau qui mélange ces trois-là s'y trahira, et nulle part
  ailleurs.

  Le contenu de l'item, qui reste la référence : deux gestes qui ne valent que
  **pris ensemble** — sortir le pool du
  monde de la racine (le poser dans le monde de la vue de jeu) et poser un
  auditeur qui suive le joueur **local**. L'un sans l'autre ne s'entend pas :
  deux mondes distincts ne s'écoutent pas, et un auditeur posé dans un monde que
  le pool n'habite pas ne reçoit rien — c'est exactement l'impasse dans laquelle
  ce défaut envoie celui qui le corrige de bonne foi. Fichiers :
  `audio_manager.gd` et `game_state.gd`, tous deux au domaine « game feel ».
  **Vérifiable en headless sans pilote audio** : égalité des `World2D` et
  présence de l'auditeur sont des faits de graphe de scène, pas des sons.
- **S2 — La distance redevient une information. ✅ CÂBLÉ le 2026-08-25, PAS
  ENCORE DOSÉ.** La portée se dérive désormais de la carte
  (`AudioManager.accorder_a_la_carte`, appelée par `rebuild_arena` — le seul
  endroit qui connaît la taille de la carte et qui suit un changement depuis le
  menu), et **elle est posée par son** : un tir porte 1,6 fois la diagonale, un
  pas 0,45. Les deux tables du fichier disent maintenant la même chose sous deux
  angles — `SFX_PRIORITE` ce que le son apprend en voix, `PORTEE_RELATIVE` ce
  qu'il apprend en pixels. Un tir s'entend d'un bout à l'autre de l'arène parce
  que c'est le renseignement le plus cher du jeu après la lumière ; un pas est
  un indice de proximité, et l'entendre partout le rendrait bavard sans rien
  apprendre.

  ⚠️ **Les valeurs sont des propositions, pas des décisions** — aucune n'a été
  jugée à l'oreille. Elles se dosent au banc (voir plus bas). Le constat qui les
  motive : `max_distance` valait 2000 px
  pour une carte qui en fait 700 à 840. Même l'oreille bien posée, « collé à
  moi » et « à l'autre bout de la carte » ne seraient séparés que d'environ
  **3,7 dB** : ce n'est pas une distance, c'est une nuance de mixage. La portée
  et la courbe (`attenuation`) se dérivent de la carte
  (`grid_size × tile_size`), comme V5.12 dérive déjà sa réverb — un chiffre rond
  écrit en dur redeviendrait faux à la première carte d'une autre taille. **Le
  réglage final se juge à l'oreille, pas au calcul** : jalon humain, comme la
  récupération d'éblouissement l'a été le 2026-08-24.
- **S3 — Un mur étouffe. ✅ TRANCHÉ le 2026-08-25 par Adrien : oui, « mais
  naturellement par la réverb ».** L'intuition est juste et elle décide de
  l'implémentation, donc elle mérite d'être écrite en entier plutôt que résumée
  en « ajouter de l'occlusion ». Derrière un mur, **ce qui parvient à l'oreille
  EST le champ réverbéré** : le direct est bloqué, ce qui reste a rebondi, donc
  arrive plus tard et plus sombre. Mais **une réverb de bus ne sait pas où est
  le mur** — elle ne peut pas devenir l'occlusion toute seule. Ce qui rend
  l'effet naturel n'est donc **pas d'ajouter de la réverb quand c'est occulté**
  (l'oreille entend alors un effet qui s'allume), c'est de **retirer le son
  direct et de laisser ce qui réverbérait déjà**. Le son ne disparaît pas : il
  passe dans la pièce d'à côté. C'est le raisonnement de la torche appliqué au
  son — on n'ajoute pas d'ombre, on retire de la lumière.

  Trois conséquences qui ne se devinent pas. **La réverb garde le
  panoramique**, puisqu'elle s'applique après le placement de la voix : un son
  occulté reste orienté, on perd la netteté et la certitude, pas la direction —
  c'est le bon compromis pour un duel. **L'équilibre sec/réverbéré se pilote
  par la ligne de vue**, et un vrai fondu entre les deux coûte deux voix sur
  seize, contre une seule si le bus se choisit à l'instant du tir : commencer
  par le choix de bus, l'arbitrage de voix (V4.16) existe déjà pour ça.
  **Et cela AJOUTE de l'information au jeu, ça n'en retire pas** — un pas sourd
  dit « il est derrière un mur », un pas net dit « j'ai une ligne directe sur
  lui ». Un binaire devient une texture, et l'oreille se met à enseigner la
  carte : c'est un changement d'équilibre du duel, pas un polish, et c'est
  pour ça qu'il se posait à Adrien.

  **✅ CÂBLÉ le 2026-08-25, PAS ENCORE DOSÉ.** Le bus `SFX_Occlus` porte la
  **même pièce** que `SFX` — mêmes `room_size`, `damping`, `hipass` — avec le
  `dry` effondré à 0,12, le `wet` relevé à 0,85 et un passe-bas à 620 Hz. C'est
  littéralement « le même endroit, sans le direct ». Un second jeu de réglages
  en aurait fait une autre pièce, et deux pièces superposées ne diraient plus
  rien de la carte : c'est le raisonnement qui a fait renoncer aux queues cuites
  dans l'échantillon (V4.1).

  **Il envoie dans `SFX`, pas dans `Master`, et ce n'est pas un détail.** D'une
  part le curseur « Effets » des options continue de le gouverner sans qu'on
  touche à `settings_manager.gd` (domaine « menus ») — sans quoi les sons
  occultés auraient ignoré le réglage de volume, en silence. D'autre part la
  chaîne devient physiquement honnête : **la pièce d'à côté, puis la vôtre.**

  Le rayon part du son vers l'oreille au seul instant où l'on connaît les deux
  positions — dans `play_sfx_2d`. **Le doute joue en direct** : pas d'oreille
  posée, occlusion coupée, ou appel hors frame de physique, et le son part sec.
  Étouffer un son qu'on n'a pas su tester retirerait une information sur une
  incertitude. Ces replis sont **comptés** (`occlusions_hors_frame`) et lus par
  le banc : un repli qui ne se distingue pas de la réussite déplace le
  diagnostic au lieu de dégrader le service — piège payé le 2026-08-25 sur
  `apercu_torche`.

  Ce qui reste vrai du constat d'origine : rien n'atténuait un son
  émis derrière un mur, alors que le mur arrête la lumière **et** le flash de
  bouche — c'était la dernière asymétrie entre les deux canaux d'information du
  jeu. La
  requête existe déjà et sert à l'éblouissement (`GameState._ligne_de_vue`) ;
  elle coûterait une requête physique **par son joué**, et les sons se comptent
  par dizaines à la seconde, pas par image. Deux points techniques à connaître
  d'avance : le bus se choisit à l'instant du `play_sfx_2d` (un bus « occlus »
  avec passe-bas et perte de niveau), et **`area_mask` vaut 0 sur les lecteurs
  du pool** — donc aucune `Area2D` ne peut redéfinir leur bus tant que ce
  masque n'est pas posé. Le principe est acté ; **le dosage se juge à l'oreille
  et n'est pas encore écrit** — jalon humain, comme S2.
- **S4 — Le loin ne sonne pas comme le près.** `AudioStreamPlayer2D` n'offre pas
  d'`attenuation_filter` (c'est du 3D) : un tir lointain est le même timbre en
  plus faible, alors que l'oreille juge la distance au **timbre** avant le
  volume. Deux voies exclusives : un passe-bas piloté par la distance sur un bus
  dédié, ou le retour du découpage corps/queue que V4.1 a écarté — et qu'elle a
  écarté en laissant la porte ouverte, mot pour mot : « le jour où l'on voudra un
  rendu par distance […] il se ré-exporte ». Dépend de l'arbitrage S7.
- **S5 — La réverb dit la salle** (= **V5.12**, déjà inscrite en vague 5, non
  faite). Aujourd'hui : une réverb unique et figée sur le bus SFX
  (`room_size` 0,06, wet 0,38), la même sur toutes les cartes. **À raccorder
  APRÈS S1** : posée sur une spatialisation qui ne pointe sur personne, une
  réverb dérivée de la carte ne s'entendrait que comme une couleur de plus. Son
  prix est déjà payé — c'est pour elle que V4.1 a renoncé aux queues cuites dans
  l'échantillon.
- **S8 — Le banc de dosage. ✅ FAIT le 2026-08-25** (`tools/banc_audio.tscn`),
  et **il est la condition de S2 et S3, pas leur accessoire.**

  **La règle, validée par Adrien le 2026-08-25 : aucun dosage ne lui est demandé
  sans le moyen de l'entendre.** Doser en éditant une constante, relançant le
  jeu et rejouant une manche, c'est une itération par minute — et une mémoire
  d'oreille perdue entre deux essais, alors que **l'oreille ne juge pas dans
  l'absolu, elle juge des écarts**. C'est le régime exact qui a laissé
  l'éblouissement non fonctionnel pendant deux mois sans que personne s'en
  aperçoive : ce qu'on ne peut pas comparer, on ne le corrige pas, on s'y
  habitue.

  Le banc déplace la source, interpose les murs de la vraie carte, tourne le
  facteur de portée et la courbe **pendant que le son joue**, coupe l'occlusion
  d'une touche pour l'A/B, et met un réglage en mémoire pour y revenir. Il
  affiche la distance, la portée du son courant, l'atténuation en décibels, le
  bus effectivement choisi et le compteur de replis.

  **Il appelle `AudioManager`, il ne le recopie pas** — condition non
  négociable : un banc qui réimplémente ce qu'il mesure fait régler quelque
  chose qui n'est pas le jeu. Son afficheur de décibels est le seul calcul en
  double, et il est nommé comme tel : il est là pour être **lu**, jamais pour
  décider ce qui sort.

  ⚠️ **Et il ne se pilotait pas.** Écrit avec un `match` sur `keycode`, il
  attendait `KEY_1` — or **le clavier d'Adrien est en AZERTY**, où la rangée du
  haut produit `&`, `é`, `"` sans Maj. Les touches ne faisaient donc rien du
  tout : aucune erreur, aucun test rouge, un banc qui a l'air cassé. Corrigé en
  lisant la **position physique** des touches (`physical_keycode`, identique
  quelle que soit la disposition) et en n'employant que des touches qui ne
  bougent pas d'un clavier à l'autre — la souris place les deux points, les
  flèches tournent les molettes. **La disposition du clavier n'est pas un détail
  de confort sur un outil de dosage :** un banc qu'on ne peut pas piloter ne
  dose rien, et c'était la seule livraison du lot qui comptait vraiment. Un
  contrôle textuel garde le retour à `keycode`.

  ⚠️ **Ce que le banc ne dira pas** : si l'on parvient à *localiser* un
  adversaire. C'est une question de duel, pas de mixage — elle demande deux
  machines, et c'est la même dette que la contre-vérification H1. Le banc règle
  le mixage ; le duel valide le jeu. Deux séances, pas une.
- **S6 — L'écran partagé : deux joueurs, une seule sortie stéréo. ✅ TRANCHÉ ET
  LIVRÉ le 2026-08-25 par Adrien : on fait la SOMME, et le canapé perd
  l'occlusion.**

  Sa formulation : *« Le mode canapé doit perdre l'occlusion. Il garde la
  direction du plus proche. On fait la somme. »* Une oreille par joueur, chacune
  dans sa vue — **et c'est le moteur qui mélange** : `AudioStreamPlayer2D` boucle
  sur tous les viewports auditeurs de son `World2D` et somme une sortie par
  viewport. Chaque copie arrive au volume que CE joueur-là entendrait, donc **le
  plus proche l'emporte tout seul**, sa copie étant simplement plus forte. Aucun
  arbitrage à écrire, aucune pondération à régler.

  **Le prix, assumé et connu d'avance :** l'occlusion n'existe pas dans ce mode.
  Étouffer la copie de J1 sans toucher à celle de J2 demanderait **deux voix par
  son**, dans un pool de seize que les pas saturent déjà. `part_occultee` rend
  donc zéro dès qu'une seconde oreille est posée — c'est la réponse juste, pas un
  repli.

  Ce qui a permis de trancher, et qui vaut d'être noté comme méthode : **les
  trois options ont été montées dans le banc avant la décision** (touche `E`),
  et c'est en les montant qu'on a découvert l'incompatibilité avec l'occlusion.
  Le raisonnement seul l'aurait manquée — elle ne se voit qu'en écrivant le
  code, et elle est devenue l'argument principal de l'arbitrage.

  **Deux pièges du montage, tous deux invisibles :** une oreille ne peut pas être
  l'enfant du joueur (les deux joueurs vivent sous `vp1`, `make_current()`
  enregistre sur le viewport du nœud — les deux se disputeraient `vp1` et `vp2`
  n'écouterait rien), d'où un **relais** sous `vp2` qui recopie la position de
  J2. Et **la racine doit être coupée** puis rétablie : sans ça une troisième
  sortie s'ajoute — le point fixe que S1 vient de réparer, remis par-dessus son
  propre correctif.

  *État constaté le 2026-08-25, et présenté comme un fait, pas comme une
  décision :* la branche `worktree-audio-oreille-et-stingers` (`4d8a85e`) pose
  l'oreille **en ligne seulement** et laisse délibérément l'écran partagé sur
  le point fixe, avec l'argument même de cet item. **Cette session-ci n'a pas
  reçu d'Adrien la confirmation que c'est son arbitrage** — elle le note donc
  sans le clore, exactement pour la raison qui a fait écrire cette section :
  une description qu'on prend pour une intention.

  La contrainte à garder
  en tête pour ne pas la découvrir en implémentant S1 : en « 1v1 écrans
  scindés », les deux joueurs partagent la même paire d'enceintes, donc **toute
  oreille attachée à l'un désavantage l'autre**. Ce n'est pas un réglage, c'est
  un arbitrage — et il ne se prend pas au détour d'un autre item.
- **S7 — 2D ou 3D. ✅ TRANCHÉ le 2026-08-25 par Adrien : on reste en 2D.**

  ⚠️ **Cet item affirmait deux choses fausses avant d'être mesuré, et toutes
  deux penchaient du même côté — celui du renoncement.** Il annonçait qu'un
  `AudioStreamPlayer3D` donnerait « un point » et qu'il coûterait « la reprise
  de tous les sites d'appel ». Vérifié dans le moteur, sur le poste d'Adrien :
  **Godot ne fait aucun rendu binaural** — aucun réglage HRTF dans
  `ProjectSettings` (il n'y a que `2d_panning_strength` et
  `3d_panning_strength`), et la sortie est stéréo. En 3D comme en 2D, la
  direction se réduit donc à un équilibre gauche/droite : **ni l'un ni l'autre
  ne donne un point**, et un son droit devant se panoramique comme un son droit
  derrière. Quant au coût, il est **confiné à `audio_manager.gd`** plus un
  auditeur, parce que tous les appelants (`player.gd`, `bullet.gd`,
  `game_state.gd`) passent un `Vector2` et **ignorent quel nœud joue le son**.
  Le prix de l'option qu'on demandait d'arbitrer avait été surestimé : c'est
  une façon de faire choisir par crainte, et elle se corrige en mesurant.

  **L'écart réel entre les deux, relevé sur les propriétés des nœuds :**

  | | `AudioStreamPlayer2D` | `AudioStreamPlayer3D` |
  |---|---|---|
  | Direction | gauche/droite | gauche/droite, **identique** |
  | Devant/derrière, hauteur | non | non (pas de HRTF) |
  | Distance → volume | `(1 − d/portée)^attenuation`, coupure sèche | 4 modèles, `unit_size`, `max_db` |
  | **Distance → timbre** | **rien** | **`attenuation_filter` : 5000 Hz, −24 dB** |
  | Réverb par zone | oui — `Area2D.audio_bus_override` | oui — `Area3D` |
  | Cône d'émission, doppler | non | oui |

  Le seul gain réel de la 3D est donc **la distance** — le passe-bas qui
  s'ouvre avec l'éloignement, c'est-à-dire S4 gratuitement. Ni la
  localisation, ni la réverb par zone, que la 2D sait déjà faire.

  **Pourquoi rester en 2D :** ce qui manque au jeu est la direction *relative*,
  et elle ne gagne rien à passer en 3D. **Point de bascule à surveiller, et il
  se juge à l'oreille :** si après S1 et S2 « loin » et « près » ne se
  distinguent toujours pas, c'est que le volume seul n'y suffit pas, et la 3D
  redevient le bon geste — pour son filtre, pas pour sa dimension. La décision
  reste réversible sans travail perdu **tant que les sites d'appel continuent
  de ne passer qu'un `Vector2`** : c'est cette signature qu'il faut protéger,
  pas le type du nœud.

---

## Chantier — brouiller la position de celui qui éblouit (inscrit le 2026-08-25)

**Demande d'Adrien, le 2026-08-25 :** « il faut que l'éblouissement rende plus
difficile de viser le joueur qui éblouit […] il faut aussi que cela *floute*, ou
*brouille* la position du joueur émetteur ».

**Le constat qui la motive, et il est exact.** L'éblouissement coûte deux choses,
et toutes deux au **contrôle** : la vitesse de déplacement (`×0,4` à saturation,
`player.gd`) et la vivacité de visée (`×0,4` sur le `lerp_angle`). Il ne coûte
**rien à l'information** — la silhouette de celui qui braque sa torche reste
aussi nette et aussi bien placée qu'avant. On vise donc toujours juste, seulement
plus lentement. Dans un jeu dont la proposition entière est « la seule
information est la lumière », c'est la moitié manquante.

**Ce qui est livré, et ce qui ne l'est pas.** Aucun fichier de production n'est
touché : ni `player.gd`, ni `game_state.gd`, ni `ui.gd`, ni `eblouissement.gd`.
Trois fichiers **neufs** seulement — le modèle `brouillage.gd` (sans dépendance,
comme `vision.gd` et `eblouissement.gd`, et pour la même raison), le banc
`tools/banc_brouillage.tscn`, la suite `tools/test_brouillage.gd`. **Rien n'est
branché en jeu, et rien ne doit l'être avant que le banc ait tranché.**

### Les cinq options, et ce que chacune coûte à qui la subit

| # | Mode | Ce qu'on perd | Ce qui reste, donc le plafond de compétence | Le risque propre |
|---|---|---|---|---|
| 1 | **halo** | Le voile blanc se concentre en bloom autour de la source, et l'avale. | La **direction** : le bloom est centré sur lui. | Il **désigne** l'adversaire. À faible éblouissement, il peut être un gain net d'information. |
| 2 | **diplopie** | La silhouette se dédouble sur un cercle qui tourne lentement. | Le **milieu des deux copies est la position vraie**, exactement. Garder la tête froide et viser entre les deux marche. | Trop écarté ou trop net, on ne lit plus un dédoublement mais deux adversaires. |
| 3 | **tremblement** | La silhouette dérive continûment autour d'elle-même (≤ 34 px). | La **moyenne temporelle est nulle** : la patience paie. | Se lit comme une **désynchronisation réseau**. C'est le pire malentendu possible en ligne — le joueur incrimine sa connexion, pas la torche. |
| 4 | **rémanence** | On voit où l'adversaire **était**, jusqu'à 0,18 s plus tôt. | La position montrée a **vraiment existé** : on prend l'avance, comme sur une cible mouvante. | **Ne punit que celui qui bouge.** Un émetteur qui allume et se fige n'est pas brouillé du tout — « allumer et ne plus bouger » deviendrait une ligne de jeu. |
| 5 | **contraste** | La silhouette se dissout dans le voile (opacité → 0,18). | Rien de faux n'est montré : le signal est **retiré**, jamais déplacé. | Ne fonctionne **que tant que le voile est là** pour servir de fond ; sans lui, il ne dit plus « il se confond » mais « il disparaît ». |

Aucune n'est recommandée seule sans essai. La combinaison qui se défend le mieux
sur le papier est **1 + 2** : le halo rend la cause visible — on comprend
*pourquoi* on ne vise plus —, la diplopie prend la précision sans mentir sur la
direction ni retirer le plafond de compétence. Mais c'est exactement le genre de
raisonnement que le 2026-08-24 a renversé sur la vitesse de récupération : *il se
tenait, il n'avait jamais été éprouvé.* D'où le banc.

### Ce que la construction a déjà appris, avant tout jugement de goût

- **Le voile fait déjà presque tout le travail, et c'est le point le plus
  gênant.** À 0,60 d'éblouissement le voile vaut 0,48 d'opacité sur tout
  l'écran : le contraste de la silhouette ennemie est déjà écrasé *avant* qu'un
  brouillage n'intervienne. Relevé sur image, pas déduit. **Conséquence : si un
  mode est retenu, il faudra probablement BAISSER le facteur 0,8 du voile**,
  sans quoi les deux s'empilent en écran blanc — et un écran blanc ne se joue
  pas, il s'attend.
- **L'apex du faisceau trahit la position, et trois modes sur cinq l'ignorent.**
  Diplopie, tremblement et rémanence ne déplacent que l'image du corps ; le cône
  de lumière, lui, continue de partir du point vrai, et il est parfaitement
  visible. Le banc porte donc une bascule (`L`) : le faisceau suit-il le
  brouillage, ou reste-t-il sur la vérité ? **C'est une vraie question de
  conception, pas un détail d'implémentation** — faire trembler tout le champ
  lumineux est bien plus violent, et sans doute plus juste.
- **Un tremblement rapide se défait tout seul.** Le premier réglage faisait
  dériver la silhouette à **322 px/s**, plus vite qu'un joueur qui court. Deux
  conséquences, et la seconde compte davantage : ça se lisait comme une
  vibration, donc comme un défaut d'affichage ; et **l'œil intègre ce qui tremble
  vite**, si bien que la moyenne perçue redevient la position vraie — le
  brouillage s'annulait au moment précis où on le regardait. Le plafond est
  désormais physique et éprouvé par la suite : *jamais plus vite qu'un joueur qui
  marche*. Ce qui se déplace comme un joueur se lit comme un joueur.
- **Le shader ennemi plafonne `LIGHT` à `COLOR.rgb`.** Un réglage entier
  (« mêler la silhouette à la couleur du voile ») a été écrit, puis retiré au
  premier rendu : éclaircir la couleur vers l'halogène **relève le plafond** et
  fait donc BRILLER la silhouette au lieu de la fondre. Le réglage faisait
  l'inverse de son nom et rien ne l'aurait dit. À savoir avant de vouloir teinter
  quoi que ce soit qui porte `player_enemy_light.gdshader`.

### ⚠️ La conséquence qu'on ne voit pas venir : le curseur « Éblouissement »

Une décision actée dit que `GameSettings.current_effect("eblouissement")` module
**le voile et rien d'autre** — jamais la pénalité de vitesse ni de visée, parce
qu'« un curseur qui allégerait la pénalité serait un avantage compétitif déguisé
en confort ».

**Un brouillage est une pénalité d'information. Il tombe donc du mauvais côté de
cette frontière : il ne peut pas passer par le curseur.** Et cela crée une
situation qui n'existait pas : un joueur qui met le voile à zéro **garde le
brouillage sans sa cause visible**. Le mode `contraste` cesse alors de
fonctionner (plus de fond où se dissoudre), et le `tremblement` perd sa
justification à l'écran — il ne reste qu'une silhouette qui gigote sans raison,
c'est-à-dire, pour le joueur, un bug de réseau.

Trois issues, aucune évidente, toutes à trancher par Adrien : donner au voile un
**plancher** qu'aucun réglage ne peut passer ; lier le brouillage au voile
malgré la décision ; ou ne retenir qu'un mode qui se suffit à lui-même.

### ✅ B1 tranché au banc par Adrien, le 2026-08-25 — « la lampe »

**Premier essai manette en main, et il tranche la question centrale.** Adrien
retient **un mix du contraste et du halo**, avec trois exigences :

1. **Le contraste doit atteindre 100 % d'invisibilité** — « j'aime beaucoup,
   mais il faut que ça puisse atteindre 100 % ». `ALPHA_CONTRASTE` passe de
   **0,18 à 0,0**.
2. **Le halo doit se poser sur l'émetteur.** C'était un **défaut**, pas un
   choix (voir plus bas).
3. **Le voile doit être atténué.** Le banc démarre désormais à **0,35** au lieu
   des 0,8 d'`ui.gd`, et le facteur est réglable en direct (`F` / `H`).

Le mode combiné existe sous le nom **`Mode.LAMPE`**, touche `6` : *le corps
disparaît, sa lampe reste.* Les modes purs restent au banc comme témoins.

**Ce que ce choix résout, et que le raisonnement seul n'avait pas vu.** Ce
document portait une objection contre le contraste poussé à bout : une
disparition pure retire TOUTE information, donc le plafond de compétence tombe
avec. Le mix y répond exactement — *(⚠️ au 2026-08-25, troisième essai, ce
n'est plus exact : voir plus bas, le halo est devenu une traînée décentrée et
le repère est passé du centre à son extrémité arrière)* — **le halo reste
centré sur la position
vraie**, donc on ne perd pas la cible, on perd sa *netteté*. C'était la demande
depuis le début. Et l'atténuation du voile suit la même logique : le voile
faisait deux métiers (dire « tu es ébloui » ET cacher l'adversaire) ; le second
revient au halo, qui le fait **localement**, sans coûter la lecture du reste de
la carte.

**Conséquence à tenir : `Mode.CONTRASTE` seul n'est plus jouable en
production.** À 100 % d'invisibilité et sans halo, l'adversaire devient
introuvable. Il ne survit que comme témoin de banc. Deux contrôles de
`test_brouillage` tiennent la paire — l'invisibilité totale d'un côté, la
présence du halo de l'autre.

> ⚠️ **Ce qu'il reste à juger sur `LAMPE`, et qui ne se voit qu'en jouant :**
> un halo radial centré sur la vérité a un **centre lisible**. Le risque est
> qu'on apprenne à tirer au milieu de la tache, et que le brouillage se réduise
> à une gêne cosmétique. Ce qui doit l'empêcher n'est pas un décentrage — ce
> serait un mensonge — mais la **taille** de la tache, le fait qu'elle bouge, et
> la visée déjà ralentie. À vérifier au tableau de tirs, pas à l'œil : si le
> « % au but » de `lampe` rejoint celui d'`aucun`, c'est que le centre se lit
> trop bien, et c'est `RAYON_HALO` qu'il faut monter.

### Second essai d'Adrien, le 2026-08-25 — quatre corrections et un défaut de fond

« C'est pas mal du tout avec le contraste et le halo, mais… » Quatre demandes,
et la dernière rouvre une question que ce document avait posée le matin même :

1. **Le halo est trop gros, trop large.** `RAYON_HALO` : 260 → **150**.
2. **Plus intense en son centre, chute plus rapide au bord.** Le profil était un
   dégradé de trois points écrit à la main, quasi linéaire — donc une tache
   molle. Il vient désormais de `Brouillage.profil_halo`, `(1 − r) ^ 2,5`, et
   l'intensité au centre passe à 1,0. **Les deux ensemble et pas l'un sans
   l'autre** : monter le centre sans creuser la chute ramènerait le disque plein,
   c'est-à-dire le halo qui DÉSIGNE au lieu de cacher.
3. **Le contraste doit tomber plus vite.** La chute était linéaire : à
   mi-éblouissement il restait la moitié de la silhouette, ce qui se lit encore
   très bien sur du noir. `COURBE_CONTRASTE = 2,0` la porte à 0,25.
   **Ce n'est pas cosmétique** : la saturation n'est presque jamais atteinte en
   jeu (plafond réel du pistolet à bout portant : 0,93), donc une chute linéaire
   réservait l'invisibilité à un cas de figure que le duel ordinaire ne produit
   pas.
4. **On supprime le voile.** Il ne s'affiche plus par défaut au banc. Ce que sa
   disparition confirme : il faisait **deux métiers** — dire « tu es ébloui » et
   cacher l'adversaire. Le halo et le flou font le second, et localement.

### Le cône trahissait l'apex — et c'était écrit ici depuis l'ouverture

« Il faudrait ajouter du flou dans la zone de l'émission de lumière, sinon le
cône révèle où est le joueur. »

**Ce document portait déjà cette phrase**, à l'ouverture du chantier : *« l'apex
du faisceau trahit la position, et trois modes sur cinq l'ignorent »*. Elle y
était classée comme une remarque sur les modes à déplacement ; elle valait aussi
pour `LAMPE`, et personne ne l'avait vu. **Effacer le corps ne sert à rien tant
que deux arêtes qui convergent se prolongent à l'œil.**

Le remède est un vrai flou d'écran, `brouillage_flou.gdshader` : dix-sept
prélèvements, noyau plein au centre et **nul sur le bord du disque** — à rayon
constant, la bordure mélangerait du flou et du net côte à côte et poserait une
forme nette de plus, c'est-à-dire un repère aussi bon que celui qu'on efface.
Mesuré : le contraste local de la zone d'émission tombe de **24,5 %** à 24 px de
noyau (−8,5 % à 8, −35,9 % à 40).

**La zone floutée est plus large que le halo** — 210 contre 150 — et une suite
l'exige : le halo cache un CORPS, le flou casse une CONVERGENCE, qui se lit bien
au-delà du corps.

> ⚠️ **À savoir avant de brancher : ce flou lit l'écran.** Il exige un
> `BackBufferCopy` et il est aujourd'hui en `COPY_MODE_VIEWPORT`, donc une
> recopie plein cadre par image. En jeu il y aurait **deux vues**, et la cible de
> cadence est un 1 % bas ≥ 60 fps. Le repasser en `COPY_MODE_RECT` est
> possible — c'est ainsi qu'il a commencé — mais c'est à mesurer au banc de
> cadence, pas à supposer.

### ⚠️ Le shader lisait un tampon qu'on écrivait — et un faux correctif a failli le cimenter

Le flou a d'abord rendu l'image **juste, à la bonne place, et beaucoup trop
claire**. Diagnostic évident : un sRGB appliqué deux fois. J'ai posé un
`pow(couleur, 2,2)` — qui l'a rendue beaucoup trop **sombre**. Un balayage de
l'exposant contre une référence sans disque n'a rien trouvé qui colle : 1,0
donnait +19 % de luminance, 1,4 en donnait −43 %.

**Aucun exposant ne collait parce qu'aucun exposant n'était le problème.** Ce
qui l'a dit : la luminance n'était qu'à +19 % pendant que le contraste était à
**+226 %**. Un décalage colorimétrique déplace les deux ensemble ; cet excès de
VARIANCE seul désignait autre chose — le rectangle lisait un tampon qu'on était
en train d'écrire dans la même passe de canevas. Déplacé sur sa propre
`CanvasLayer`, au-dessus du monde entier, il colle à la référence à **0,000 %**
près sur les deux mesures, sans aucune correction.

**Deux choses à en retenir, et la seconde vaut au-delà de ce shader :**

- une lecture d'écran en 2D n'a de sens que si ce qu'elle lit est **fini d'être
  dessiné** ; une couche à part est le seul moyen de le garantir ;
- **un facteur de correction qui « marche à peu près » est le meilleur moyen de
  cimenter un défaut ailleurs.** Le 2,2 était plausible, documentable, et faux.
  Seule la mesure contre une référence l'a écarté — le contrôle décisif tenait
  en une ligne : *à noyau nul, le disque doit devenir invisible.*

### Troisième essai, le 2026-08-25 — le halo était un CERCLE, donc un repère

Adrien, capture à l'appui : « le problème c'est que le cercle est toujours
visible grâce à la luminosité centrale du halo. Il faudrait qu'elle s'étale
davantage, dans la direction du faisceau, avec le flou. »

**Le défaut est de forme, et il retourne une demande précédente contre son
but.** Un halo rond est une forme ; son cœur lumineux en marque le centre,
c'est-à-dire très exactement le point qu'on cherche à rendre introuvable. Et
**plus le cœur est net, mieux il le marque** — donc la netteté demandée au
deuxième essai (`NETTETE_HALO`, la chute creusée) travaillait *contre* le but
sans que ni lui ni moi ne l'ayons vu.

**La correction n'est pas d'adoucir le cœur** — ce serait défaire la demande
précédente — **mais de l'étirer.** Le halo et le flou deviennent deux ellipses
couchées sur l'axe du faisceau et poussées vers la victime. Le cœur devient une
traînée : aussi vif, il ne désigne plus. Mesuré sur image, faisceau vertical :
la zone claire fait **33 px en travers contre 225 le long**, soit un rapport de
6,8 là où un cercle rend 1,0.

Réglages du même essai : flou plus intense (noyau 24 → **34**), halo moins
puissant (intensité 1,0 → **0,7**), silhouette effacée plus vite (courbe 2,0 →
**3,4**, soit 0,11 d'opacité à mi-éblouissement contre 0,25).

> ⚠️ **Le repère a changé de nature, et une phrase de ce document est devenue
> fausse.** Il était écrit que « le halo reste centré sur la position vraie »,
> et que c'était ce qui gardait la vérité recouvrable. **Ce n'est plus exact :**
> la traînée est décentrée vers la victime, son barycentre n'est plus
> l'émetteur. Ce qui reste vrai — et ce sur quoi repose désormais tout le
> plafond de compétence — c'est que **l'émetteur est à l'extrémité arrière de la
> traînée**, celle qui s'éloigne de soi. On lit une forme au lieu d'un point.
> Ce n'est pas un mensonge, la traînée décrit fidèlement où la lumière est ;
> mais « viser le centre du halo » était un conseil juste et ne l'est plus.

> ⚠️ ~~**Conséquence non demandée : le joueur ébloui se voit lui-même flou.**~~
> **Tranché le 2026-08-25 : il ne doit pas l'être.** « Il ne faut pas que notre
> propre personnage devienne flou » (Adrien). Le flou porte désormais un trou
> autour de soi — nul en deçà de 44 px, plein au-delà de 104. **Le fondu entre
> les deux n'est pas un ornement** : un disque net au milieu du flou serait une
> forme de plus à lire, donc un repère, et on aurait remplacé un cercle par un
> autre. Mesuré : avec le trou, le contraste sur son propre personnage est
> **identique au millième** à celui d'une image sans aucun flou ; sans lui, il
> tombait de 35,5 %.
>
> Ce n'était pas qu'un confort : la décision actée du voile sous le HUD dit déjà
> que l'éblouissement doit coûter la lecture **du monde**, jamais celle de sa
> propre fiche. Se perdre soi-même est une punition de plus que ne rattrape
> aucune compétence.

### ✅ Les réglages retenus par Adrien, le 2026-08-25 — B3 clos

Quatrième et dernier essai de la soirée : **« c'est super : voile à 0,3, effet
à 2, il ne faut pas que notre propre personnage devienne flou ».**

| | valeur | où |
|---|---|---|
| voile | **0,3** | `Brouillage.VOILE_FACTEUR` — ⚠️ `ui.gd` porte encore **0,8** |
| gain du brouillage | **2,0** | `Brouillage.GAIN` |
| trou autour de soi | 44 → 104 px | `EXCLUSION_PRES` / `EXCLUSION_LOIN` |

**B3 est donc clos** : le voile a fait 0,8 → supprimé → 0,3 en une soirée, et
ce n'est pas de l'hésitation. Il faisait deux métiers — dire « tu es ébloui » ET
cacher l'adversaire ; le halo et le flou ont pris le second, et **localement**.
Il ne reste que le premier, qui se contente de 0,3.

**Le gain n'est pas une intensité, c'est une VITESSE** : à 2,0 la dose sature dès
0,5 d'éblouissement, donc tout le brouillage est atteint à mi-faisceau. Cela
compte parce que la saturation n'est presque jamais atteinte en jeu — plafond
réel du pistolet à bout portant : 0,93, et bien moins hors de l'axe. **Il vit
dans le modèle et non au banc**, sinon la production ne ferait pas ce qui a été
jugé.

**Il ne reste que B4** — le curseur « Éblouissement » — avant qu'un branchement
soit possible.

### ⚠️ Le halo se posait à côté de sa cible — défaut, et il avait survécu à une image

`TextureRect.expand_mode` vaut `EXPAND_KEEP_SIZE` par défaut : la taille
**minimale** du contrôle est alors celle de sa texture, 512². Toute taille
demandée plus petite était relevée à 512 pendant que la position, elle, restait
calculée sur le rayon voulu — le centre dessiné dérivait de `256 − rayon`, une
centaine de pixels vers le bas et la droite aux valeurs courantes.

**Le plus instructif est comment il a passé une vérification par l'image.**
L'unique capture du halo avait été prise avec l'émetteur **pile au-dessus du
canon**. À cet endroit l'erreur horizontale est rigoureusement nulle, et
l'erreur verticale se lit comme « le halo est un peu bas » — c'est-à-dire comme
un réglage, pas comme un défaut. **Une position centrée est le seul point
aveugle de ce défaut, et c'est celle qui avait été choisie pour le contrôler.**

La règle qui en sort, et elle vaut pour toute planche de ce dépôt : **une
capture de contrôle ne se prend pas sur un cas symétrique.** La symétrie est
exactement ce qui annule les erreurs qu'on cherche.

### Ce qui attend encore Adrien — B2 à B4

Le banc se lance seul : `godot --path . res://tools/banc_brouillage.tscn`. `0`
à `6` changent de mode en direct, `←/→` règlent la force, `F`/`H` le voile, le
clic tire, `Échap` imprime le tableau — par mode, combien de tirs, combien au
but, de combien on rate.

- ~~**B1 — quel(s) mode(s).**~~ ✅ **Tranché le 2026-08-25 : `Mode.LAMPE`**
  (contraste à 100 % + halo). Voir ci-dessus.
- **B2 — le faisceau suit-il le brouillage ?** (touche `L`). **Sans objet pour
  `LAMPE`** : ce mode ne déplace rien, il efface et il éclaire. La question ne
  se rouvrira que si un mode à déplacement revenait.
- ~~**B3 — quelle valeur pour le voile ?**~~ ✅ **Tranché le 2026-08-25 : 0,3.**
  Voir la section des réglages retenus. ⚠️ `ui.gd` porte encore 0,8 : c'est la
  seule valeur de production à changer au branchement.
- ~~**B4 — le curseur.**~~ ✅ **Tranché le 2026-08-25 : il n'y en a pas.**
  « On ne peut pas régler la valeur éblouissement, il ne faut pas donner
  d'avantage à un des deux » (Adrien).

  **Cette décision dépasse celle du 2026-08-18 au lieu de la contredire.**
  L'ancienne plaçait la frontière entre le CONFORT (le voile, réglable) et la
  PÉNALITÉ (vitesse et visée, jamais réglables). **Ce chantier a déplacé le
  voile du mauvais côté de cette frontière** : tant qu'il ne faisait que
  blanchir l'écran, le baisser ne rendait pas l'adversaire plus lisible — il
  l'était déjà, net et bien placé. Depuis que la lecture de l'adversaire dépend
  du halo, du flou et de l'effacement, **tout ce qui touche à l'éblouissement
  touche à l'information**, et un curseur devient un avantage quel que soit ce
  qu'il règle.

  Ce qu'il faudra faire au branchement : **`ui.gd` cesse de multiplier le voile
  par `GameSettings.current_effect("eblouissement")`** et pose `VOILE_FACTEUR`
  tel quel ; l'entrée « Éblouissement » de l'écran des effets n'a plus d'objet.
  Ces trois fichiers appartiennent à la session « menus » — **la modification se
  demande, elle ne se fait pas d'office**, et elle n'est donc pas faite ici.

**Les quatre items sont clos. Le chantier n'attend plus d'arbitrage** — il
attend un branchement, qui touche des fichiers tenus par une autre session.

**Rien n'est branché tant que B4 n'est pas posé.** `brouillage.gd` n'a toujours
aucun lecteur en production : le branchement touche `player.gd`, `ui.gd` et
`game_state.gd`, tenus par la session « game feel ». **Les nombres, eux, ne
manquent plus** — les quatre essais d'Adrien du 2026-08-25 les ont tous posés,
et ils vivent dans `brouillage.gd`.
## Chantier — la résolution de rendu du duel (inscrit le 2026-08-25)

**Le problème, en une phrase : le duel est rendu à 1080p et affiché en plus
grand.** Les `SubViewport` de `main.tscn` rendent à taille FIXE — 957×1080 et
958×1080 en écran scindé, 1916×1080 en vue unique — **quelle que soit la
fenêtre**, parce que `SubViewportContainer` ne répercute pas le facteur
d'étirement sur le viewport qu'il porte. Agrandir la fenêtre étire donc l'image
au lieu de l'affiner. Voir le piège « Agrandir la fenêtre n'agrandit pas le rendu
du jeu ».

Ce n'est pas un défaut : c'est un choix que personne n'a fait, et qui coûte de la
netteté là où le jeu se joue.

### R1 — Le banc doit dire ce qu'il rendait ✅ fait le 2026-08-25

Sans ça, aucun avant/après n'est possible et **rien ne le signale**.
`tools/bench_framerate.gd` imprime désormais, avant de mesurer : taille de
fenêtre en pixels natifs, aire 2D et facteur d'étirement, taille de rendu de
chaque `SubViewport` (en marquant celui qui est arrêté par `--une-vue`), et le
total de pixels de jeu par image. Il suit aussi l'état de focus et **qualifie son
propre relevé** — voir R2.

### R2 — Relevé de référence ✅ fait le 2026-08-25

Cinq exécutions, `--seconds 15`, duel complet, pompe contre pompe, torches
allumées, sur Apple M3.

| Fenêtre | Focus | Médian | 1 % bas | Pire image |
|---|---|---|---|---|
| 1280×720 | stable | 144 | 143 | 7,3 ms |
| 2560×1440 | **mixte (93 %)** | 144 | 71 | 18,5 ms |
| 2560×1440 | **mixte (89 %)** | 144 | 44 | 59,6 ms |
| 2560×1440 | stable | 144 | 142 | 7,2 ms |
| 2560×1440 | stable | 144 | 143 | 7,3 ms |
| 2560×1440 | stable | 144 | 144 | 7,0 ms |

**Deux résultats, et le second a failli passer pour le premier.**

1. **Doubler la fenêtre ne coûte rien de mesurable** : médiane 144 partout,
   1 % bas 142 à 144 dès que le focus est stable. C'est cohérent — les
   `SubViewport` rendent les mêmes 2,07 Mpx, seul le blit final grandit.
2. **Ce qui détruit le 1 % bas, ce sont les TRANSITIONS de focus**, pas la
   charge. Les deux relevés à 44 et 71 sont exactement les deux où la fenêtre a
   changé d'état pendant la mesure. Sans l'instrumentation de R1, on aurait lu
   « doubler la fenêtre fait tomber le 1 % bas de 143 à 44 » — un chiffre faux,
   parfaitement plausible, et qui aurait condamné le chantier avant qu'il
   commence.

**Référence à battre, donc : médiane 144, 1 % bas 142-144, pire image ~7,2 ms,
pour 2,07 Mpx de jeu par image.** Protocole obligatoire : focus stable, relevé
mixte jeté, trois exécutions.

### R3 — Choisir le mécanisme ⚠️ demande un arbitrage d'Adrien

Trois voies, et elles n'ont ni le même coût ni le même périmètre.

**(a) Supersampler les `SubViewport`.** Remplacer `SubViewportContainer` par un
`Control` qui dessine la texture, poser `SubViewport.size = taille × étirement`,
et **corriger le zoom des caméras du même facteur** — sans quoi le champ de
vision change, ce que `keep` vient précisément de figer. Touche `main.tscn` et
`game_state.gd`, où le zoom est posé à 1.0 en cinq endroits et animé pour la
killcam et l'encaissement. Coût de rendu : ×4 en plein écran (2,07 → 8,29 Mpx).

**(b) Sortir le duel du `SubViewport` en vue unique — ✅ RETENU par Adrien le
2026-08-25 « pour des raisons d'équité en compétitif », et ✅ IMPLÉMENTÉ le même
jour.** En ligne et à l'entraînement il n'y a qu'une vue ; le jeu est désormais
rendu par le viewport racine, à la résolution de la fenêtre. C'est le mode
compétitif, donc celui où la netteté compte.

**Comment c'est fait, et ce que ça ne fait pas.** Aucun nœud ne bouge : joueurs,
arène et balles restent enfants de `vp1`. La racine adopte le même `World2D`, le
masque de cull de la vue regardée, et sa caméra (`custom_viewport`) ; les deux
`SubViewport` passent en `UPDATE_DISABLED`. L'écran scindé local est inchangé —
il a besoin de ses deux vues, deux masques, deux caméras. Tout tient dans
`_accorder_rendu_aux_vues()`, qui savait déjà quelle vue est regardée.

**L'interrupteur `rendu_racine_autorise`** ramène la vue unique à son
`SubViewport`. Il existe pour que le banc mesure les deux chemins dans la même
exécution (R4), et sert de recours si le rendu racine se révélait mauvais
quelque part.

> **Correction, et elle porte sur l'argument qui a emporté la décision.** Ce
> paragraphe annonçait (b) comme **« gratuit en pixels »**, au motif que le blit
> intermédiaire disparaît au lieu de grossir. La moitié est vraie, la conclusion
> est fausse : **si le jeu est dessiné à la résolution de la fenêtre, il coûte
> les pixels de la fenêtre.** En vue unique, le rendu passe de 1916×1080 —
> 2,07 Mpx — à 3,69 Mpx dans la fenêtre de débogage doublée, et 8,29 Mpx en
> plein écran. Ce sont les pixels chers : lumières, occluders, mélange. L'étape
> supprimée avait été comptée, l'étape restante avait été oubliée.
>
> **La netteté se paye en pixels dans les deux voies. Il n'y a pas de repas
> gratuit**, et (a) et (b) coûtent sensiblement la même chose sur la vue qu'elles
> touchent — au blit près, qui est bon marché.
>
> Ce qui reste vrai, et ce qui fait choisir (b) : **aucun zoom de caméra à
> retoucher.** L'étirement de la fenêtre s'en charge, donc le champ de vision ne
> peut pas dériver — ce que le passage en `keep` vient précisément de verrouiller.
> (a) rouvrirait cette porte dans cinq endroits de `game_state.gd`, dont la
> killcam. S'y ajoute une pièce mobile en moins : plus d'image intermédiaire en
> vue unique.

> **Correction du 2026-08-25, apportée par la session « spatialisation du son »
> et vérifiée avant d'être écrite ici.** Ce paragraphe disait que (b) croisait
> S1 « qui dit que le pool audio vit dans le `World2D` de la racine ». **C'était
> périmé d'une journée : S1 est FAIT** (`4d8a85e`, fusionné par `e3e1b34`, donc
> déjà dans la base de ce chantier), `AudioManager.poser_oreille()` existe et
> `game_state.gd:992` l'appelle.
>
> **La contrainte réelle tient en une ligne : (b) peut déplacer le monde, il ne
> doit pas supprimer l'`AudioListener2D`.** Des trois gestes de
> `poser_oreille()`, un monde unique en rendrait deux redondants — le
> reparentage du pool deviendrait un déplacement interne, et
> `audio_listener_enable_2d` est déjà à `true` sur la fenêtre racine. Le
> troisième reste **nécessaire quel que soit le viewport** : sans auditeur
> explicite, Godot retombe sur le centre de l'écran virtuel, c'est-à-dire le
> défaut d'origine réintroduit par une refonte qui n'a rien à voir avec le son.
>
> **Et un argument POUR (b) qui ne vient pas des pixels :** depuis S1, le pool
> de seize voix vit dans le monde du jeu et se fait reparenter à chaque manche,
> avec un rappel sur `tree_exiting` — sans quoi les seize voix partent avec
> l'arène et plus aucun son positionnel ne sort de la session, sans erreur. Un
> monde unique supprimerait ce va-et-vient : une pièce mobile en moins sur un
> chemin qui a déjà son piège.
>
> `audio_manager.gd` appartient au domaine « game feel » / son : l'alléger se
> demande à cette session, ça ne se fait pas depuis ici.

**(c) Ne rien faire, et l'assumer par écrit.** La netteté actuelle est celle d'un
1080p étiré. Personne ne s'en est plaint avant qu'on la mesure.

### R4 — Mesurer l'après ✅ fait le 2026-08-25, **et le relevé ne prouve pas ce qu'on espérait**

Les deux chemins mesurés **dans la même session, sur la même machine, sous le
même focus** — c'est à ça que sert l'interrupteur `rendu_racine_autorise` et le
`--sans-racine` du banc. Comparer deux commits sur deux lancements aurait laissé
la machine et le focus varier entre les deux moitiés de la mesure.

| Vue unique | Pixels de jeu | Médiane | 1 % bas | Pire image |
|---|---|---|---|---|
| **avant** — `SubViewport` 957×1080 puis étiré | 1,03 Mpx | 144 | 142 | 7,3 ms |
| **après** — racine 2560×1440 | **3,69 Mpx** | 144 | 143 | 7,3 ms |

**3,6 fois plus de pixels, aucun écart mesurable. Et c'est précisément ce dont
il faut se méfier.**

**Le contrôle qui a sauvé la conclusion : le socle nu donne AUSSI 144.** Toutes
torches éteintes, tous shaders retirés, seconde vue arrêtée — 1,03 Mpx et
médiane 144, 1 % bas 142, pire image 7,3 ms. Aux erreurs de mesure près, c'est le
même relevé que le duel complet à 3,69 Mpx.

Conclusion honnête : **la fenêtre au second plan est bridée autour de 144 fps, et
le banc ne voit rien en dessous de ce plafond.** Il ne mesure donc pas la charge,
il mesure le plafond. Ce que le relevé établit vraiment :

- ✅ **les deux chemins tiennent ≥ 142 de 1 % bas** sous ce plafond ;
- ❌ **il n'établit PAS que le chantier est gratuit.** « 3,6× les pixels pour
  zéro coût » est une conclusion que ce relevé ne porte pas, et l'écrire aurait
  été le même défaut que les quinze mesures recopiées cent quarante fois du
  compteur de fps.

#### Le vrai relevé — Adrien, fenêtre au PREMIER PLAN, le 2026-08-25 (jalon H10 ✅)

Deux exécutions, focus **stable au premier plan** attesté par le banc lui-même,
donc comparables. Le plafond disparaît, et le résultat renverse deux choses.

| Vue unique, premier plan | Pixels de jeu | Moyen | Médian | 1 % bas | Pire image |
|---|---|---|---|---|---|
| **avant** — `SubViewport` 957×1080 | 1,03 Mpx | 104 | 105 | 63 | 17,6 ms |
| **après** — racine 2560×1440 | **3,69 Mpx** | **121** | **120** | 61 | 19,4 ms |

**1. Le chantier ne coûte pas, il RAPPORTE : +15 % de cadence pour 3,6 fois plus
de pixels.** L'explication est matérielle et vaut d'être retenue : le chemin
d'avant écrivait dans une texture intermédiaire puis la recopiait à l'écran. Sur
un GPU Apple, qui rend par tuiles, **changer de cible de rendu force un vidage de
tuiles coûteux**. Supprimer l'étape économise plus que les pixels ajoutés ne
coûtent. C'est l'inverse de ce que la prudence faisait attendre, et aucune
lecture de code ne l'aurait donné.

**2. Correction de ce que cette section affirmait plus haut : la marge sur le
seuil n'est PAS « du double », elle est de deux images par seconde.** Le
1 % bas réel est de **61 après et 63 avant**, contre une barre à 60. Le chiffre
« 142 » venait des relevés plafonnés et ne décrivait pas le jeu.

**3. Et un constat qui dépasse ce chantier, à ne pas lui attribuer :** 63 avant,
61 après — l'écart est dans le bruit, donc **le chantier R ne dégrade pas le
1 % bas**. Mais le jeu, mesuré honnêtement dans la fenêtre de développement,
tourne à un 1 % bas d'environ **60**, très loin des « 120 tenus » que ce document
annonce depuis le 2026-08-16. Ce relevé-là avait été pris en fenêtre 1280×720, et
sans instrument capable de dire ce que le focus faisait. **C'est un fait sur le
jeu, pas sur ce lot, et il appelle une décision d'Adrien.**

Réserve de méthode : une exécution par configuration. L'écart de +15 % dépasse la
dispersion observée le même jour sur deux relevés identiques (73 contre 81), donc
la direction est solide — deux exécutions de plus la confirmeraient.

### R5 — Le seuil, fixé AVANT de mesurer ✅ tranché par Adrien le 2026-08-25

**La barre passe de « 1 % bas ≥ 120 fps » à « 1 % bas ≥ 60 fps ».** Décision
d'Adrien, prise avant tout relevé d'après — c'est là tout l'objet de cette
étape : un seuil choisi en regardant le résultat n'est pas un seuil, c'est une
justification.

**Ce que ça ouvrait, écrit le jour même : « la barre ne mordra probablement pas,
la référence est à 142-144, il faudrait perdre plus de la moitié de la cadence
pour toucher 60 ».**

> ⚠️ **Faux, et conservé ici parce que l'erreur est instructive.** Ce « 142-144 »
> venait de relevés pris fenêtre au second plan, donc plafonnés — le socle nu
> donnait le même chiffre. Le relevé honnête d'Adrien, fenêtre au premier plan,
> donne un 1 % bas de **61 après et 63 avant** : la barre de 60 est franchie de
> deux images par seconde, pas du double. **Elle a bien failli mordre.**
>
> La décision reste la bonne — le chantier ne dégrade pas le 1 % bas, 63 → 61
> étant dans le bruit — mais elle a été prise sur un chiffre qui ne décrivait pas
> le jeu. *Un seuil fixé d'avance protège du biais de conclusion ; il ne protège
> pas d'une référence fausse.*

**Et une distinction qu'il ne faut pas perdre, parce que les deux chiffres se
ressemblent.** « 1 % bas à 60 » n'est pas « plafonner à 60 ». La Phase 3 a
mesuré que la cadence commande le RTT d'EOS — 60 fps plafonnés donnent
RTT_MIN 46 ms et RTT_AVG ~50, contre 13,3 et 22,3 déplafonné, soit **le double
de latence réseau**. Ce prix-là n'est PAS celui qu'Adrien vient d'accepter : il a
accepté que le centième d'images le plus lent descende à 60, pas que le jeu y
vive. La médiane reste déplafonnée, et c'est elle qui décide du RTT.

**Si le seuil ne passait pas** — cas peu probable, mais tranché d'avance : on en
fait un **réglage** dans les Options, à côté des intensités d'effets. La netteté
ne change aucune information de jeu — elle ne dit rien de plus sur l'adversaire —
donc en faire une option ne crée pas d'inégalité, contrairement au champ de
vision. C'est précisément pourquoi `keep` n'est pas réglable et pourquoi
celle-ci pourrait l'être.

**Mesuré sur la vue unique**, et non sur l'écran scindé : c'est la vue que (b)
transforme, et c'est le mode classé. L'écran scindé reste au comportement actuel
et n'a donc pas de « après » à mesurer.

### R6 — Recuire les assets ⏳ le seuil est passé, donc c'est DÛ

**Le fait géométrique, et il ne dépend d'aucune mesure de cadence :** en vue
unique, un asset dessiné pour couvrir N unités de monde couvre désormais N ×
l'étirement de la fenêtre. **×1,33 dans la fenêtre de développement doublée, ×2
en plein écran.** Une tuile de 35 px sur une case de 35 unités passe donc de 1
texel par pixel à **0,5 en plein écran** : elle sera interpolée, pas nette.
L'écran scindé local, lui, garde ses `SubViewport` à taille fixe et son 1:1.

**Cela renverse la consigne donnée le matin même** aux sessions qui produisent
des assets — « les `SubViewport` rendent à taille fixe, donc rien n'est à
recuire ». C'était vrai avant (b), c'est faux après, et les deux sessions
concernées ont été prévenues le jour même.

**La densité de référence : ×2** — proposée par DA2 le 2026-08-25, et son
argument est meilleur que le mien parce qu'il est **asymétrique**.
Sur-échantillonner se règle par mipmaps et filtrage linéaire : ça coûte de la
mémoire et de la bande passante sur des sorties de 35 px, autant dire rien.
**Sous-échantillonner ne se règle par rien** — aucun filtre ne restitue un détail
absent de la texture, ça coûte de la netteté. Dans un jeu dont toute la
proposition est que la lumière est la seule information, la netteté des surfaces
qui portent cette lumière n'est pas un poste où l'on rogne. *(Reste à faire
valider par Adrien : R6 n'est l'étape courante de personne.)*

**Et le périmètre est plus petit qu'annoncé — vérifié, pas déduit.** Ce
paragraphe listait le cookie de torche comme le premier à recuire, avec son piège
de portée. **C'est faux : les familles de LUMIÈRE sont déjà à l'abri, et testées.**

- Le **cookie** passe par `WeaponData.echelle_torche()`, et `tools/test_torches.gd`
  vérifie que l'empreinte vaut `512 × torch_scale` **quelle que soit la résolution
  du fichier** (`empreinte := tex.get_width() * w.echelle_torche()`). Le piège de
  portée n'est pas ouvert : il est fermé par un contrôle qui rougit.
- Les **halos peints** : `LightTextures.poser()` prend une **empreinte en unités
  de monde** et en dérive `texture_scale` ; `tools/test_lumieres.gd` le vérifie à
  quatre résolutions différentes.

C'est la propriété qui compte, et elle mérite d'être nommée : **découpler la
taille de la TEXTURE de l'empreinte en MONDE rend la recuisson gratuite.** Là où
c'est fait, R6 n'a rien à faire.

Reste donc :

1. ~~**Les tuiles** — un paramètre de `tools/fabrique_tuiles.gd`.~~
   ⚠️ **FAUX, vérifié le 2026-08-25 : ce n'est pas un paramètre, c'est une
   migration de format.** `fabrique_tuiles.gd` le dit lui-même à sa constante :
   *« Elle n'est pas paramétrable : une tuile d'une autre taille ne rentrerait
   pas dans l'atlas. »* Et `CandelaTileSet.TILE_SIZE` sert **trois rôles à la
   fois** :

   - la région de l'atlas de texture (`ts.tile_size`, les `blit_rect`) ;
   - **la taille d'une case du MONDE** — `map_geometry.gd` en dérive collision et
     occlusion, `menu_arene.gd` son aperçu ;
   - ⚠️ **une valeur du FORMAT DE SAUVEGARDE** — `map_codec.gd:215` et
     `map_data.gd:360` l'écrivent dans le fichier (`"tile_size"`).

   Doubler la texture demande donc de **séparer la région d'atlas de la taille de
   case**, et toute confusion entre les deux touche des cartes déjà enregistrées.

   ⚠️ **PRÉCISION qui change la nature du travail** (trouvée par la session
   « spatialisation du son », vérifiée avant reprise) : ce champ du format est
   **écrit et lu par personne.**

   - écrit deux fois — `map_codec.gd:215` et `map_data.gd:360` —, les deux
     depuis `CandelaTileSet.TILE_SIZE`, jamais depuis la carte ;
   - lu **zéro fois**. `MapGeometry.build_collisions()` accepte bien un
     `tile_size` en paramètre, mais **avec la constante pour défaut**, et
     `menu_arene.gd:301` l'appelle sans l'argument. La géométrie ignore donc la
     valeur stockée, et l'audio aussi.

   Ça coupe dans les deux sens. **La migration est plus SIMPLE qu'annoncé** —
   aucun lecteur ne casse si la constante change, puisqu'il n'y a pas de
   lecteur. Mais **le champ promet ce qu'il ne tient pas** : chaque carte
   enregistrée porte `tile_size: 35`, ce qui a toutes les apparences d'un
   filet pour les anciennes cartes, et n'en est pas un. Qui planifierait la
   migration en comptant dessus bâtirait sur du vide.

   Troisième exemplaire du même piège en deux jours : **un champ que personne ne
   lit ne se corrige pas tout seul**, et il ment d'autant mieux qu'il a l'air
   prévoyant. Deux issues, et le laisser inerte n'en est pas une : soit le champ
   devient **lu** — géométrie et audio prennent la valeur de la carte, ensemble
   ou pas du tout —, soit il est **retiré** du format pour cesser de promettre.
   Le choix appartient au domaine éditeur/cartes.
   Ce n'est plus « rien d'autre à décider » : c'est un chantier à part entière,
   avec une compatibilité ascendante à tenir.

   **Le motif se répète** : la troisième affirmation de portée de la journée
   démentie par une lecture — après les options de lanceur déjà implémentées et
   les « trois planches » de key art qui étaient deux. Une entrée de feuille de
   route qui dit *« rien d'autre à décider »* mérite qu'on aille voir, parce que
   c'est la formule qu'on écrit quand on n'a pas regardé.

1ter. ⚠️ **Et les RÉGLAGES qui ont produit les assets validés ne sont consignés
   nulle part.** Les outils documentent des invocations d'exemple
   (`--epaules 17.1` pour les sprites, `--taille 160` pour le sang), mais pas les
   curseurs fins de chaque cuisson retenue : quelle `--luminance` a donné le sol
   « faible » qu'Adrien a validé, quels `--matiere` et `--profil` ont donné les
   cookies. **Recuire à l'aveugle rejouerait ses arbitrages au hasard.**

   ✅ **Et pour le sol, la valeur a été RETROUVÉE plutôt que choisie
   (2026-08-25).** Adrien, à qui elle était demandée, ne s'en souvenait pas et a
   dit « choisis une valeur ». Il n'y avait pas à choisir : `--luminance` est
   *« la luminance moyenne visée »*, et l'outil l'**impose**. Elle est donc
   lisible dans l'asset livré. Mesuré sur les tuiles validées :

   ```
   solA_faible_1.png   35x35   moyenne 0.1476
   solB_faible_1.png   35x35   moyenne 0.1780
   ```

   Le « faible » du nom vient de `--nom`, l'outil écrivant `<nom>_<n>.png` — ce
   n'était pas un mode, c'était l'étiquette d'une variante retenue parmi
   plusieurs. La recette du sol est donc `--nom solA_faible --luminance 0.1476`
   et son jumeau à 0,1780.

   ⚠️ **La leçon dépasse ce paramètre : une recette perdue se retrouve dans le
   PRODUIT quand l'outil impose un résultat plutôt qu'un procédé.** Ce qui est
   irrécupérable, ce sont les curseurs qui *influencent* sans déterminer —
   `--contraste`, `--matiere`, `--profil`. D'où une règle utile pour les outils à
   venir : **un curseur qui vise une grandeur mesurable rend sa propre recette
   retrouvable**, un curseur qui pondère ne le fait pas.

   Conséquence directe sur l'ordre des choses : **une recuisson partielle est
   pire que pas de recuisson**, puisque la décision est « une fois, pour TOUTES
   les familles » — traiter les seuls sprites recréerait l'incohérence de densité
   que R6 existe pour supprimer. Le préalable n'est donc pas de recuire, c'est
   de **rendre les recettes reproductibles**, une par asset livré. Les planches
   sources sont versionnées précisément pour ça (`assets/sources/*/.gitignore` :
   *« sans elles, l'asset devient irreproductible »*) — mais une planche sans sa
   recette ne l'est qu'à moitié.

1bis. ⚠️ **LES DÉCALS, non listés jusqu'ici et pourtant couplés.** Trouvé le
   2026-08-25 en relisant avec la lunette de DA4, après le viseur.
   `blood_stain.gd` et `wall_impact.gd` dessinent tous deux à
   `_texture.get_size() * _echelle`, où `_echelle` n'est qu'une **variation
   aléatoire** (0,75-1,25 pour le sang, 0,22-0,34 pour les éclats) : la taille
   de base est celle du FICHIER. Recuits à ×2, **les taches de sang et les
   éclats de mur doubleraient à l'écran.**

   Ce sont donc **quatre familles** qui ont besoin de la même division —
   sprites, viseur, sang, éclats — quand cette liste n'en nommait qu'une. Et
   comme la décision d'Adrien est explicitement « une fois, pour TOUTES les
   familles », lancer la recuisson en l'état casserait **deux familles sur
   quatre en silence**.

   ⚠️ **Une valeur posée quatre fois finit par diverger** — c'est le procès que
   `charte.gd` fait lui-même aux 220 `Color(...)` qu'il a remplacés, et à la
   palette recopiée dont « chaque moitié paraît juste ». Le foyer naturel est
   donc `Charte`, qui est déjà une `class_name` accessible partout et porte
   cinquante constantes de ce genre — pas une constante recopiée dans quatre
   fichiers.

   ✅ **CORRIGÉ le 2026-08-25**, Adrien ayant tranché « corrige tout ». La
   densité vit désormais dans **`Charte.DENSITE_ASSETS`** — pas recopiée dans
   quatre fichiers — et les quatre familles en dérivent. `tools/test_sprites.gd`
   (22 contrôles) interdit à `player.gd` de redéclarer la sienne et exige des
   deux décals qu'ils divisent ; éprouvé rouge sur quatre sabotages, dont
   « le sang redessine à la taille de son fichier ».

   ⚠️ **Et la réparation a coûté un lot rouge à 32 suites, pour une TABULATION.**
   Le remplacement automatique visait `\tvar t := _texture.get_size()…` avec UNE
   tabulation quand la ligne en portait DEUX. Le garde-fou du script — vérifier
   que le motif est unique avant de remplacer — **était vert** : il comptait une
   **sous-chaîne**, pas une ligne. Le remplacement a donc démarré au milieu de
   l'indentation, `blood_stain.gd` a cessé de compiler, et comme `bullet.gd` le
   précharge, **32 suites sont tombées avec lui** en annonçant chacune « 2
   erreurs de script ». Aucune ne nommait la vraie cause.

   **Encore la famille du jour** : un contrôle qui atteste l'unicité d'un motif
   n'atteste pas qu'on a visé la bonne chose. Ancrer sur une ligne entière —
   retour à la ligne compris — aurait rougi tout de suite.
2. ~~**Les sprites, et c'est le seul vrai travail de R6.**~~ ✅ **DÉCOUPLÉS le
   2026-08-25** (commit ci-dessous). `_poser_sprite()` passe désormais par
   `empreinte_sprite()`, qui divise par `DENSITE_SPRITES` : un `fusil.png` recuit
   de 82 à 164 px occupera toujours 82 unités de monde.

   **`tools/test_sprites.gd` (17 contrôles) verrouille l'APPARIEMENT, pas la
   taille.** Le banc n'a pas d'avis sur la bonne taille du joueur — elle relève
   d'un arbitrage d'Adrien. Il exige que densité et recuisson **bougent
   ensemble** : densité passée à 2,0 sans recuire → `empreinte 41.0 au lieu de
   82.0` ; sprite recuit à 164 px sans toucher la densité → `empreinte 164.0 au
   lieu de 82.0`. Les deux sens éprouvés rouges avant que le banc soit cru.

   Il verrouille aussi un **lien** que rien d'autre ne portait : le roulis de
   marche vaut 1,6 unité de MONDE, calibré à l'œil contre un corps d'environ 17
   unités. Un joueur deux fois plus grand aurait gardé le même roulis — donc une
   démarche deux fois plus discrète, **sans qu'une ligne de la marche ait
   bougé**. Le rapport est borné entre 1 et 4 % ; il vaut 1,95 % aujourd'hui.

   ⚠️ **Le banc ne peut PAS charger `player.gd`.** Premier jet en
   `preload("res://player.gd")` : il pend, parce que le fichier référence
   `NetworkManager` au niveau de la classe et que les autoloads n'existent pas en
   `--script` (« Identifier not found »). C'est le piège du 2026-08-18, et c'est
   déjà la raison pour laquelle `test_torches.gd` lit le TEXTE de `game_state.gd`.
   Les deux constantes se lisent donc dans la source — ce qui est de toute façon
   le bon niveau : c'est par le texte que le défaut reviendrait.

   ⚠️ **Et la recuisson elle-même n'est PAS faite.** Ce commit ne fait que la
   rendre inoffensive. Passer `DENSITE_SPRITES` à 2,0 et recuire est désormais un
   geste sûr — c'est un pas séparé, qui attend Adrien.

#### Le motif qui a fait trouver le reste : une valeur absolue là où il faut un rapport

**Nommé par DA4 le 2026-08-25**, après l'avoir rencontré **quatre fois en deux
jours** : le coefficient de case du code de salon (26,1 px pour une lettre de
28,0, faux depuis le premier jour), la portée de lumière du panneau d'arène, le
contour des chiffres de dégâts (8 px fixes pour une taille allant de 19 à 42), et
deux marges de 9-slice écrites en pixels de TEXTURE — celles-là auraient
**tranché en plein dans le dessin** après recuisson, sans une erreur.

Énoncé : **dans un chantier de densité, tout littéral qui multiplie ou mesure une
dimension d'écran est suspect.**

Relire son propre travail du jour avec cette lunette a immédiatement donné une
cinquième occurrence, dans le viseur livré le matin même : un `Sprite2D` dessine
à la taille de sa TEXTURE, et celui-ci n'avait pas de taille explicite. Il
occupait 48 unités de monde **parce que son fichier fait 48 px** ; recuit à ×2 il
aurait doublé à l'écran, et la seule plainte possible aurait été « le viseur est
devenu énorme », sans rapport visible avec une recuisson. Corrigé sur le modèle
des lumières — empreinte déclarée, échelle dérivée — et verrouillé par deux
contrôles de `tools/test_viseur.gd`, éprouvés rouges.

⚠️ **Ce qui rend ce motif coûteux n'est pas sa difficulté, c'est son angle
mort.** Le viseur a été écrit deux fonctions au-dessus de la correction
`DENSITE_SPRITES`, le même jour, par la même session : **corriger un motif ne
fait pas relire le reste de son fichier avec.** Six occurrences chez trois
sessions, et — le constat est de DA3 — **aucune n'a été trouvée par celle qui
l'avait écrite.** C'est un motif qui se transmet mieux qu'il ne s'auto-détecte.

   Le texte d'origine, conservé :
   faut donc appliquer aux sprites le geste déjà fait pour les lumières :
   découpler la taille de texture de l'empreinte en monde. **Ce n'est pas un
   paramètre, c'est une correction — et elle n'est pas faite.**

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
| H8 | **Paire de clés de mise à jour** | ✅ **Clé publique en place le 2026-08-26** — paire RSA-4096 fabriquée par Adrien, publique dans `update_manager.gd` (relue par `openssl`, chargée par `Crypto` de Godot). **Reste la moitié qu'aucun agent ne doit toucher** : le secret GitHub `CANDELA_MAJ_CLE_PRIVEE`, à créer depuis `~/candela_maj_privee.pem`. Sans lui, la CI refuse de publier plutôt que d'annoncer une version non signée. | Avant toute publication |
| H9 | **Première publication, et première mise à jour réelle** | Poser `v0.1.0`, laisser la CI publier, installer sur une vraie machine et appuyer sur le bouton. L'échange de bundle n'a jamais tourné ailleurs qu'en lecture de son propre script : il demande un jeu exporté, installé, et une version publiée. | Après H8 |
| H10 | **Un relevé de cadence FENÊTRE AU PREMIER PLAN** (chantier R, étape R4) | macOS bride une fenêtre au second plan autour de **144 fps**, et une session d'agent ne peut pas se donner le focus. Tous les relevés du 2026-08-25 sont donc plafonnés : le socle nu — torches éteintes, shaders retirés, 1,03 Mpx — donne le même 144 que le duel complet à 3,69. **Le banc ne mesure pas la charge, il mesure le plafond.** La conclusion « le chantier R est gratuit » n'est PAS établie ; seul l'est le fait que les deux chemins passent le seuil de 60 avec une marge de plus du double. Une exécution au premier plan lève l'ambiguïté en trente secondes : `godot --path . res://tools/bench_framerate.tscn -- --vue-unique`, puis la même avec `--sans-racine`. Le banc dit lui-même dans quel état de focus il était. | ✅ **Fait par Adrien le 2026-08-25** — et il a renversé deux conclusions : le chantier R **gagne** 15 % de cadence au lieu de coûter, et le 1 % bas réel du jeu est de **61**, pas de 142. Détail dans R4. |

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

### Le seul chantier de code ouvert

1. **Les vagues de game feel** (section dédiée ci-dessus). Tout ce qui n'est pas
   marqué *assets* se fait sans rien attendre de personne. Les vagues 3 et 6
   passent par `ui.gd` — vérifier qu'aucune session ne le tient. Les vagues 4 et
   5 vivent dans `player.gd`, les lumières et les particules : c'est le terrain
   libre quand `ui.gd` est pris.
2. Les **chantiers de robustesse** de l'étude du 2026-08-16 (section dédiée), à
   piocher entre deux tâches. Aucun n'est bloquant.

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

---

## Journal des tests à deux machines

| Date | Configurations | Résultat |
|---|---|---|
| 2026-08-16 (matin) | Même Wi-Fi ; un poste en 4G ; les deux en 4G, opérateurs différents | `Lien DIRECT` partout, ping 58 ms. Trois défauts relevés : jointure incertaine, message trompeur, killcam muette. Tous corrigés depuis. |
| 2026-08-16 (après-midi) | Même réseau | Connexion et ping sains, mais **les commandes du client ne remontaient pas**. Trois manches d'instrumentation F3 ont mené à la cause : des noms de nœuds auto-générés divergents entre machines. Corrigé. |
| 2026-08-16 (soir) | Même réseau | Commandes et déplacements ✅. **Killcam tronquée** : tampon de rejeu dimensionné en images et non en durée, effondré par le déplafonnement des fps. Corrigé — enregistrement à 60 Hz fixe. |
| 2026-08-16 (fin) | Même réseau | **Tout fonctionne** : commandes, tirs, dégâts, killcam des deux côtés. Phase 3 close. |
