# Candela 2D — Feuille de route

> **Document de référence du projet.** Toute session de travail le lit avant
> d'agir et le met à jour avant de conclure. Protocole de mise à jour : voir
> [README.md](../README.md).
>
> Dernière mise à jour : 2026-08-25
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

1. **H8 — la paire de clés.** Deux commandes `openssl`, la publique dans
   `update_manager.gd`, la privée dans les secrets GitHub. Tant qu'elle manque,
   l'écran affiche « mises à jour non configurées » et ne télécharge rien.
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
| **Seule l'arbalète éclaire au-delà de l'écran** (2026-08-24, Adrien) | Chaque joueur voit **480 unités devant lui**. Au-delà, sa torche allume quelque chose qu'il ne voit pas et qui le trahit : elle coûte sans rien rapporter. Le pistolet passe de 30°/2,3 à **35°/1,6** (0,85 écran), le fusil de 3,5 à **1,8** (0,96), la pompe (60°/1,0 — 0,53) et l'arbalète (5°/3,5 — **1,87**) ne bougent pas. L'arbalète est l'arme furtive et lointaine ; le privilège de porter hors champ lui revient, et à elle seule. **La portée se lit désormais en fractions d'écran, pas en unités** — « 0,85 écran » se juge, « 410 unités » ne se juge pas. Effet second non cherché mais mesuré : à texture égale sur moins de terrain, la densité de texels du pistolet est multipliée par **2,9**, celle du fusil par 3,9. Raccourcir pour le jeu a réglé la netteté par-dessus le marché. ✅ **Portées dans `game_state.gd` le 2026-08-24**, à l'intégration de DA2.1. `tools/torches.gd` en garde une copie — la cuisson et le banc se chargent hors du jeu, où `game_state.gd` ne se charge pas — et `tools/test_torches.gd` exige leur égalité en lisant le TEXTE des deux sources. La divergence qui a réellement existé ici ne peut donc plus revenir muette. |
| **La résolution est assumée en smooth, pas en pixel-perfect** (2026-08-24, Adrien) | DA5.6, qui conditionnait toute commande d'asset. Le pixel-perfect impose une grille à des objets qui n'en ont pas : le monde de Candela n'est pas fait de sprites, il est fait de **lumière**, et un masque de lumière est agrandi jusqu'à 3,5 fois par `torch_scale` — une grille de texels y serait un défaut visible, jamais un style. Ce qui en découle et ne se rediscute plus : **filtrage linéaire et mipmaps à l'import, aucune texture en `nearest`**, et la résolution d'un asset cesse d'être un carcan — elle se choisit sur la densité de texels à l'écran, pas sur une grille. Première application : le cookie de torche vise **1024²**, où un texel couvre 1,75 pixel d'écran, contre 3,5 pour le 512² que `weapon_data.gd` fabrique aujourd'hui. |
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

---

## Pièges connus — ne pas les redécouvrir

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
- **V5.9 Streaks de sprint** — vignette resserrée + traits de vitesse côté
  sprinteur. **✅ Fait pour les traits** — shader plein écran préchargé
  (`sprint_streaks.gdshader`) : pointillés radiaux filant vers l'extérieur,
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
> (cible 1 % bas ≥ 120 fps) avant d'être gardé ». Le prendre sans cette mesure
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
  120 fps, gl_compatibility sans réserve. Peut partager son quad et ses
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
  droite, à valider au bench_framerate (cible 1 % bas ≥ 120 fps) avant d'être
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
  taps : très en deçà du budget 1 % bas ≥ 120 fps. Garde-fou impératif : le
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
  `bench_framerate` avant d'acter (1 % bas ≥ 120). **→ À implémenter derrière
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
  couture visible. ⚠️ **La traînée de balle (`radial_tight`) reste un dégradé** —
  aucune planche n'a été choisie pour elle, c'est la quatrième texture que la
  ligne « 3-4 » prévoyait. *(C : 3-4 textures)*
- **DA2.3 Le muzzle flash en frames** ✅ **livrée le 2026-08-25** — trois images
  peintes (famille **FB** : amorce, épanouissement, dissipation), déroulées
  par-dessus la descente d'énergie qui reste seule maîtresse de la luminosité.
  **Trois est le nombre que la durée permet, pas un choix esthétique** : à 0,1 s
  et 60 Hz chaque image tient deux images de rendu, à 0,05 s (l'arbalète) une
  seule ; au-delà, une image ne serait jamais affichée. Cuites en **énergie
  libre** et non radiale — voir « Pièges connus ». *(C : 1 planche)*
- **DA2.4 Le sprite du joueur** — personnage top-down lisible en silhouette
  (tête, épaules, arme), idle + 4-6 frames de marche. Un personnage incarne le
  duel ; une forme fait un diagramme. *(C)*
- **DA2.5 Les 4 armes en main** — silhouettes distinctes sur le sprite : le
  pompe se reconnaît à sa forme avant son son. *(C, avec DA2.4)*
- **DA2.6 Le tileset des sols** — les 2 matériaux du damier en vraies tuiles
  avec usure et taches, 3-4 variantes par tuile posées aléatoirement pour
  briser la répétition parfaite. *(C)*
- **DA2.7 Le tileset des murs** — coins dessinés, liseré intégré au tile plutôt
  que tracé. *(C, avec DA2.6)*
- **DA2.8 Les decals de sang peints** — 6-8 éclaboussures remplaçant les
  polygones : une scène de crime, pas un nuage de losanges. *(C : 1 planche)*
- **DA2.9 Les impacts muraux** — éclats et brûlures en decals persistants.
  *(C, avec DA2.8)*
- **DA2.10 Le key art du titre** — une illustration d'ambiance (deux torches
  dans le noir) derrière le menu : une image installe l'univers mieux que
  quinze shaders. *(C)*
- **DA2.11 Le viseur custom** — croix dessinée, réactive (s'ouvre au tir, se
  teinte à l'éblouissement). *(C, ou S en vectoriel soigné)*
- **DA2.12 Les traçantes texturées** — habiller la `Line2D` d'une texture de
  trait (grain, pointes effilées) : la balle cesse d'être un segment. *(G ou C)*

### DA3 — L'audio, la moitié du « pro » (le câblage existe, il joue du silence)

- ~~**DA3.1 Les 4 sons de tir**~~ (= V4.1) — **✅ livrée le 2026-08-25**, en
  seize prises (quatre par arme) plutôt qu'en huit corps/queues. Le premier son
  entendu est le premier jugé, et il ne se répète plus.
- ~~**DA3.2 Les stems produits à 170 BPM**~~ (= V1.1) — **✅ livrée le
  2026-08-24.** La musique adaptative joue enfin ce qu'elle orchestrait.
- **DA3.3 Les trois fichiers câblés-muets du 2026-08-18** — `torch_on.wav`,
  `torch_off.wav`, `tinnitus_dazzle.wav` (V5.1, V5.3) : ils vivent dès le
  dépôt des fichiers. *(C : 3 samples)*
- **DA3.4 Les stingers accordés** (= V2.3, V3.7, V3.8, V3.10) — **les quatre
  fichiers sont dans le dépôt depuis le 2026-08-24** (`sting_kill`,
  `sting_kill_match`, `sting_defeat`, `sting_draw`, accordés et sur la grille).
  **Rien ne les joue** : aucune clé dans `AudioManager.SOUNDS`, aucun appel. Il
  ne reste que le câblage, et il est au domaine « game feel ».
- **DA3.5 La voix d'annonceur** (= V1.3) — 3-2-1, FIGHT, verdicts. Rien ne dit
  « fini » comme une voix. *(C)*
- **DA3.6 Les pas par matériau** (= V5.7) — deux sols, deux jeux de pas. *(C)*
- **DA3.7 La famille de sons UI** — survol, validation, retour, erreur : une
  même matière sonore pour tous les menus. *(C : 5-6 samples)*
- **DA3.8 Le room tone** (= V5.10) — un lit de silence habité sous la manche.
  *(C)*
- **DA3.9 Le mastering global** — loudness cohérente entre bus, limiteur,
  égalisation : l'écart pro/amateur *s'entend* au volume près. *(C, câblage S)*

### DA4 — L'interface habillée

- **DA4.1 HUD en 9-slice dessinés** — jauges et cadres peints au lieu des
  rectangles stylés par code. *(C)*
- **DA4.2 Chrono, score, ping en chiffres tabulaires** — ils cessent de
  « sauter » à chaque changement. *(S, découle de DA1.2)*
- **DA4.3 Les chiffres de dégâts en fonte display** — contour dessiné dans le
  style, plus d'outline automatique. *(S)*
- **DA4.4 Le bandeau FATAL dessiné** — cartouche peint, pas un label sur le
  noir. *(C)*
- **DA4.5 La killcam habillée** — cadre VHS authored, timecode en fonte mono,
  grain *texturé* plutôt que bruit calculé. *(C : 2-3 textures)*
- **DA4.6 Le trait balistique en schéma** — le pointillé V6.2 stylé relevé
  d'expert : flèches, cote de distance, fonte mono. La killcam-professeur
  devient une pièce signature. *(S)*
- **DA4.7 La bannière de fin composée** — verdict, série, « effleuré : 13 px »
  hiérarchisés comme une affiche, pas empilés. *(S après DA1, C pour l'ornement)*
- **DA4.8 Les vignettes de la galerie encadrées** — cadre, ombre, titre composé
  pour chaque carte. *(S)*
- **DA4.9 Le code de salon en cases display** — V6.7 le prévoit ; la typo
  display le rend iconique. *(S, après DA1.2)*
- **DA4.10 Les glyphes manette officiels** — icônes de boutons dessinées au
  lieu de « X », « LB » en texte. *(G : jeux de glyphes libres)*
- **DA4.11 Le rebinding visuel** — un clavier dessiné plutôt qu'une liste de
  noms de touches. *(S + G)*
- **DA4.12 Les états vides illustrés** — historique sans match, galerie sans
  carte : une petite illustration et une phrase, pas un écran nu. *(C, petit)*
- **DA4.13 Les transitions d'écran signature** — un seul motif de fondu (une
  extinction ?), décliné partout. *(S)*
- **DA4.14 Les curseurs J1/J2 dessinés** — deux petites torches plutôt que deux
  rectangles colorés. *(C)*
- **DA4.15 L'éditeur de cartes aligné** — icônes d'outils dessinées, palette de
  l'éditeur sous la bible. *(S + G)*
- **DA4.16 Le panneau F3 lui-même** — même la debug UI dit quelque chose de la
  rigueur du jeu. *(S)*
- **DA4.17 Les messages d'erreur humanisés** — « L'hôte a quitté le salon »
  stylé et calme, jamais un texte brut. *(S)*

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
S3 et S7 sont des **arbitrages qui appartiennent à Adrien**, S5 est déjà écrit
ailleurs (V5.12) et attend S1, S6 est hors périmètre.

- **S1 — L'oreille rejoint le joueur.** *Bloquant : tout le reste est inaudible
  sans lui.* Deux gestes qui ne valent que **pris ensemble** — sortir le pool du
  monde de la racine (le poser dans le monde de la vue de jeu) et poser un
  auditeur qui suive le joueur **local**. L'un sans l'autre ne s'entend pas :
  deux mondes distincts ne s'écoutent pas, et un auditeur posé dans un monde que
  le pool n'habite pas ne reçoit rien — c'est exactement l'impasse dans laquelle
  ce défaut envoie celui qui le corrige de bonne foi. Fichiers :
  `audio_manager.gd` et `game_state.gd`, tous deux au domaine « game feel ».
  **Vérifiable en headless sans pilote audio** : égalité des `World2D` et
  présence de l'auditeur sont des faits de graphe de scène, pas des sons.
- **S2 — La distance redevient une information.** `max_distance` vaut 2000 px
  pour une carte qui en fait 700 à 840. Même l'oreille bien posée, « collé à
  moi » et « à l'autre bout de la carte » ne seraient séparés que d'environ
  **3,7 dB** : ce n'est pas une distance, c'est une nuance de mixage. La portée
  et la courbe (`attenuation`) se dérivent de la carte
  (`grid_size × tile_size`), comme V5.12 dérive déjà sa réverb — un chiffre rond
  écrit en dur redeviendrait faux à la première carte d'une autre taille. **Le
  réglage final se juge à l'oreille, pas au calcul** : jalon humain, comme la
  récupération d'éblouissement l'a été le 2026-08-24.
- **S3 — Un mur étouffe.** Rien n'atténue aujourd'hui un son émis derrière un
  mur, alors que le mur arrête la lumière **et** le flash de bouche. C'est la
  seule asymétrie qui reste entre les deux canaux d'information du jeu. La
  requête existe déjà et sert à l'éblouissement (`GameState._ligne_de_vue`) ;
  elle coûterait une requête physique **par son joué**, et les sons se comptent
  par dizaines à la seconde, pas par image. Deux points techniques à connaître
  d'avance : le bus se choisit à l'instant du `play_sfx_2d` (un bus « occlus »
  avec passe-bas et perte de niveau), et **`area_mask` vaut 0 sur les lecteurs
  du pool** — donc aucune `Area2D` ne peut redéfinir leur bus tant que ce
  masque n'est pas posé. ⚠️ **Change l'information disponible en manche : se
  pose à Adrien, ne s'implémente pas d'office** — même règle que les items D.
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
- **S6 — L'écran partagé : deux joueurs, une seule sortie stéréo.** Hors
  périmètre jusqu'à nouvel ordre (Adrien, 2026-08-25). La contrainte à garder
  en tête pour ne pas la découvrir en implémentant S1 : en « 1v1 écrans
  scindés », les deux joueurs partagent la même paire d'enceintes, donc **toute
  oreille attachée à l'un désavantage l'autre**. Ce n'est pas un réglage, c'est
  un arbitrage — et il ne se prend pas au détour d'un autre item.
- **S7 — Ce que la 2D ne donnera pas, quoi qu'on fasse.** Le panoramique stéréo
  n'encode que **X** : en vue de dessus, l'axe Y n'existe pas à l'oreille, il ne
  se traduit qu'en volume. L'oreille rendra donc **un axe et une distance,
  jamais un point** — à savoir avant de promettre « localiser l'adversaire au
  son ». Si un point est voulu, il faut passer les sons de manche en
  `AudioStreamPlayer3D` avec un Z fictif, ce qui apporte du même coup le
  filtrage par distance (S4) et les zones de réverb (S5), et coûte la reprise de
  tous les sites d'appel. **C'est une décision d'architecture, pas un réglage :
  à trancher AVANT S2 et S4**, sous peine de les régler deux fois.

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
| H8 | **Paire de clés de mise à jour** | Deux commandes `openssl` ; la publique se recopie dans `update_manager.gd`, la privée devient le secret GitHub `CANDELA_MAJ_CLE_PRIVEE`. Aucun agent ne doit détenir une clé privée de signature. **Tant qu'elle manque, l'écran affiche « mises à jour non configurées » et ne télécharge rien.** | Avant toute publication |
| H9 | **Première publication, et première mise à jour réelle** | Poser `v0.1.0`, laisser la CI publier, installer sur une vraie machine et appuyer sur le bouton. L'échange de bundle n'a jamais tourné ailleurs qu'en lecture de son propre script : il demande un jeu exporté, installé, et une version publiée. | Après H8 |

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
