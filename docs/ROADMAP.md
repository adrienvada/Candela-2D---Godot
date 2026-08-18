# Candela 2D — Feuille de route

> **Document de référence du projet.** Toute session de travail le lit avant
> d'agir et le met à jour avant de conclure. Protocole de mise à jour : voir
> [README.md](../README.md).
>
> Dernière mise à jour : 2026-08-18
>
> **Plus aucune session parallèle.** Une seule branche, `main`, un seul arbre de
> travail. Les dix worktrees d'agents et les six branches périmées ont été
> retirés : tous les livrables étaient déjà versionnés dans `main`.

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

  **Verdict : tenu.** Le 1 % bas — ce que le joueur ressent comme saccade —
  reste au-dessus de 120 sur les trois exécutions. À dire honnêtement : le
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
de gauche. **REJOUER prend désormais la place exacte de PRÊT** — même geste,
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

**Les entrées qui lancent un match portent le style plein.** Le geste qui engage
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

**Étape 6 — édition du pseudo.** 🟡 **Déployée le 2026-08-18** par Adrien —
`rename_profile` en base, fonction `rename` en ligne, porte vérifiée (`401` sans
jeton). Le nouveau plancher de rang est effectif en production dans la foulée :
un débutant s'affiche **Aveugle I**. **Écran câblé le 2026-08-18** : le
bouton MODIFIER s'ouvre sur une saisie préremplie du pseudo courant — on modifie
un pseudo, on n'en saisit pas un nouveau — et la rangée remplace la ligne du
pseudo plutôt que de s'ajouter dessous, pour que rien ne se déplace.

`can_rename()` exige un profil **prêt** : une identité en cours n'a pas de pseudo
à changer, et montrer le bouton donnerait une action qui échoue. Le contrôle qui
affirmait l'inverse a été **retourné, pas supprimé** — il disait pourquoi le
renommage était indisponible, et sa raison reste juste, elle ne s'applique
simplement plus. **Étape close.**

Le pseudo est la **seule** chose qu'un joueur peut changer de son profil : ni son
identifiant, ni son code de récupération, ni son classement — tout le reste est
dérivé ou constitutif. C'est ce qui rend l'étape petite.

Livré le 2026-08-18 :

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

#### Ce qui reste

**Le déploiement**, qui demande Adrien : `supabase db push` puis
`supabase functions deploy rename`. Rien n'est déployé — la fonction répondrait
404 aujourd'hui, et c'est pour cela que l'écran n'est pas encore câblé.

**Puis le champ dans l'écran du profil.** La place y est réservée depuis le début.
Le câbler avant le déploiement donnerait un bouton qui échoue, ce qui ne se
distingue pas d'un jeu cassé.

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

## Décisions actées

| Décision | Raison |
|---|---|
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
| **Assets manquants : câbler, taire, diagnostiquer** (2026-08-17) | Le code qui joue un son absent s'écrit normalement et reste silencieux, sans erreur. Aucun bouche-trou n'est fabriqué : un placeholder qui traîne finit par être pris pour une intention. `asset_manifest.gd` porte les 76 fichiers attendus et distingue **absent** de **présent mais vide** — `music_menu.ogg`, `music_match.ogg` et `music_victory.ogg` pèsent exactement 160 032 octets, trois copies du même flux vide qu'un contrôle de présence déclarerait bons. La détection se fait à la taille du fichier, ce qui se corrige tout seul le jour où le vrai arrive. État visible en jeu par **F3**. |
| **Armes : règle du miroir en classé** (2026-08-17, confirmée par Adrien) | Les deux joueurs partagent l'arsenal du moins bien classé. Sans elle, le mieux classé arriverait avec des options que l'autre ne peut pas avoir — l'Arbalète étant à la fois l'arme furtive et la quatrième débloquée. Coût assumé : l'arsenal varie selon l'adversaire, ce que l'interface doit expliquer au moment où ça arrive. |
| **Un abandon vaut forfait** | Décision du 2026-08-16. Quitter un match en ligne en cours donne la victoire à celui qui reste : c'est archivé, drapeau `forfait` à l'appui. **La faille est connue et acceptée** : il suffit de couper la connexion de l'adversaire pour lui voler un forfait, ou d'invoquer sa propre coupure. Les deux autres règles envisagées ne valent pas mieux — jeter le match récompense celui qui débranche en train de perdre. Aucune n'est bonne ; celle-ci a au moins le mérite de ne pas rendre l'abandon gratuit. À revoir quand il y aura assez de joueurs pour que ça se pratique. |
| **Code de récupération à 12 caractères**, pas 6 | Décision du 2026-08-16. L'alphabet est celui de `LobbyCode`, la longueur non. Un code de salon (6 caractères, 30 bits) désigne un salon qui vit dix minutes ; un code de récupération est un secret au porteur qui ouvre un profil classé à vie. 12 caractères sur 32 font 60 bits, ce qui met une attaque par essais hors de portée. Affiché par groupes de quatre (`ABCD-EFGH-JKLM`), stocké et envoyé sans séparateur. |
| **Code de récupération stocké en clair** | Décision du 2026-08-16. Un condensat serait plus sûr, mais le jeu réaffiche le code à chaque lancement — c'est tout son intérêt, le joueur peut le noter quand il y pense. Le compromis « secret au porteur » était déjà acté ; le stockage en clair en est la conséquence, pas une négligence. |
| **Edge Functions sans jeton Supabase** (`verify_jwt = false`) | Décision du 2026-08-16. Leur authentification est le jeton signé par Epic, qu'elles vérifient elles-mêmes. Exiger en plus un jeton Supabase n'ajouterait rien — la clé publiable est embarquée dans le jeu, donc connue de tous — et ferait dépendre l'accès du format des clés, qui a justement changé (publiable / secrète). |
| **PostgREST appelé directement, sans `supabase-js`** | Décision du 2026-08-16. Deux appels de fonction ne justifient pas de faire dépendre d'un paquet distant la seule porte d'entrée du classement. Tout tient en `fetch`, et `deno check` fonctionne hors ligne. |

---

## Pièges connus — ne pas les redécouvrir

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

- **Déduplication des tirs prédits en FIFO aveugle** (`_consume_predicted_shot`
  n'apparie ni position ni angle). Si l'hôte refuse un tir (désaccord de
  cadence), le tir officiel suivant consomme la mauvaise prédiction ; avec un
  RTT > 1 s, le TTL expire et le client voit sa balle en double. Piste :
  apparier par angle approximatif et caler le TTL sur le RTT mesuré.
- **Mort simultanée = victoire du premier RPC arrivé** (`_end_sequence_active`
  ignore la seconde mort). Décision de design à prendre : un double kill
  vaut-il égalité ? Aujourd'hui l'égalité n'existe que par chrono écoulé.

**Tests**

- La mécanique centrale du jeu — voir et être vu dans le noir — n'a **aucun
  test automatique** : portée et cône de torche, révélation au tir, occlusion
  effective. Les suites s'arrêtent à la géométrie des occluders, très en amont
  du gameplay.
- Les transitions d'état en ligne (les 8 familles de la
  [CHECKLIST_TESTS_EN_LIGNE.md](CHECKLIST_TESTS_EN_LIGNE.md)) ne sont
  couvertes que manuellement — c'est la zone la plus régressive d'un jeu
  réseau. Le banc à deux instances est automatisable en ENet (cible 127.0.0.1,
  appariement scriptable), sans identifiants Epic.
- `ReplaySystem` (fenêtre de rejeu, `impact_frame`, ralenti) n'a pas de test
  unitaire ; seule `test_online_match` compte des balles rejouées.

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

### Vague 1 — Réveiller ce qui dort (systèmes câblés, jamais alimentés)

- **V1.1 Stems musicaux réels** — l'AudioStreamInteractive 4 couches à 170 BPM
  est câblé mais `generate_music_streams.gd` produit des flux vides (seul le
  heartbeat est réel). Le meilleur ratio du projet. — *assets : 3 clips +
  3 stems .ogg bouclés à 170 BPM (commande à passer en premier, délai long).*
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
  reçu), ping sonore + pulse du libellé. — *assets : 1 sample.*
- **V3.3 Décompte qui frappe** — 3-2-1 en pop TRANS_BACK + note montante par
  chiffre ; le CanvasModulate remonte du noir absolu au noir de jeu sur le
  « 1 » : la lumière naît au début de manche. — *assets : 3 notes courtes.*
- **V3.4 Dernière minute** — chrono or, stem batterie (V1.2), tic-tac sous
  10 s. — *assets : 1 tic-tac.*
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
  glisse avec un son de pion. — *assets : 1 sample.*
- **V3.7 Stinger de défaite noble** — 2 s qui se résolvent vers le thème du
  menu : perdre ne doit pas donner envie de quitter. — *assets : 1 stinger.*
- **V3.8 L'égalité pèse** — silence sec 1 s puis « ÉGALITÉ » gris et soupir de
  détente. — *assets : 1 sample.*
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

### Vague 4 — L'identité du tir et de l'impact

- **V4.1 Un son PAR arme** — les 4 armes partagent `weapon_shoot.wav`. Corps +
  queue distincts : le fusil claque, le pompe tonne, l'arbalète chuinte. —
  *assets : 4×2 samples.*
- **V4.2 Hitmarker centre/bord** — « thock » à pleins dégâts, « tick » en
  effleurement, branché sur `rpc_update_hp` (autoritaire), pas sur la balle
  prédite. — *assets : 2 samples.*
- **V4.3 Ricochet du fusil** — étincelles + « zing » par rebond : récompenser
  le geste le plus stylé du jeu. — *assets : 3 samples.*
- **V4.4 Tir à sec** — clic + tremblement du cercle de cooldown quand on
  presse pendant le rechargement. — *assets : 1 sample.*
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
  (déjà sans ombre) : toucher, c'est voir.
- **V4.12 Recul de caméra directionnel** — kick 4-6 px opposé au tir.
  **✅ Fait** — 6 px résorbés en ~100 ms, additionnés au shake existant.
- **V4.13 Fumée de bouche** — 2-3 particules additives dérivant 1 s.
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
  soignés.*
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
  `dazzle_amount` côté ébloui. — *assets : 1 boucle.*
- **V5.4 Respiration de la torche** — Perlin lent ±3 % sur l'énergie.
- **V5.5 Poussière dans le faisceau** — particules additives ténues (pool).
- **V5.6 Rétrodiffusion pulsée au pas** — le BodyLight respire en marchant.
- **V5.7 Pas par matériau** — 2 jeux de pas pour les 2 sols du damier. —
  *assets : 2×4 samples.*
- **V5.8 Shimmer du liseré néon** — les bordures des murs scintillent sous une
  lumière directe.
- **V5.9 Streaks de sprint** — vignette resserrée + traits de vitesse côté
  sprinteur.
- **V5.10 Présence de la salle** — sons ponctuels pannés très espacés. —
  *assets : 5-8 samples d'ambiance.*
- **V5.11 Frôlement de mur** — tissu + poussière à < 10 px d'un mur. —
  *assets : 3 samples.*
- **V5.12 Réverb par carte** — room size dérivée de `grid_size` à l'entrée de
  manche.

### Vague 6 — Killcam, menu, méta (confort et rétention)

- **V6.1 Grain VHS dynamique** — l'overlay killcam monte pendant le
  bullet-time, se stabilise à l'impact (un uniform à animer).
- **V6.2 Trajectoire au trait** — la balle fatale dessine sa ligne complète en
  pointillé pendant le rejeu : la killcam devient professeur.
- **V6.3 Sidechain du ralenti** — heartbeat + souffle seuls pendant le
  bullet-time, tout relâcher à l'impact.
- **V6.4 Rembobinage VHS** — son de bande + timecode à rebours 300 ms au
  lancement. — *assets : 1 sample.*
- **V6.5 Négatif à l'impact** — 2 frames d'inversion vidéo au moment fatal.
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
| Sons d'armes (V4.1) | corps + queue par arme | 8 samples |
| Foley | pas ×2, douilles, ricochets, frôlements, ambiances, torche | ~25 samples |
| UI / récit | frappes, ping prêt, pion, impacts typo, tic-tac, verre, rewind | ~10 samples |
| Corps | souffles blessé, acouphènes | ~8 samples |
| Visuel | quasi rien (procédural) — éventuellement 1-2 fontes, sprites D1, logo | 0-6 fichiers |

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
| 6 | **Édition du pseudo** (Phase 5, étape 6) | ✅ Écrite et testée le 2026-08-18. **Le déploiement demande Adrien** — `supabase db push` puis `supabase functions deploy rename` ; l'écran sera câblé après, un bouton qui répond 404 ne se distinguant pas d'un jeu cassé. |
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
| **Déployer la fonction `rename`** | `supabase db push` puis `supabase functions deploy rename`. Écrite et testée depuis le 2026-08-18 ; l'écran du profil attend ce déploiement pour être câblé. |
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
7. **Le déploiement de la fonction `rename`** — `supabase db push` puis
   `supabase functions deploy rename`. Écrite et testée ; l'écran du profil
   attend ce déploiement, un bouton qui répond 404 ne se distinguant pas d'un
   jeu cassé.

### Dettes anciennes, sans urgence

8. Reste dû de la Phase 2, jamais déroulé : la checklist manuelle
   `CHECKLIST_TESTS_EN_LIGNE.md` et la validation à 120 ms de latence simulée.
9. Deux points connus : le relais Epic n'a jamais été exercé (la connexion
   directe a toujours abouti), et la détection de déconnexion est lente des deux
   côtés.

## Journal des tests à deux machines

| Date | Configurations | Résultat |
|---|---|---|
| 2026-08-16 (matin) | Même Wi-Fi ; un poste en 4G ; les deux en 4G, opérateurs différents | `Lien DIRECT` partout, ping 58 ms. Trois défauts relevés : jointure incertaine, message trompeur, killcam muette. Tous corrigés depuis. |
| 2026-08-16 (après-midi) | Même réseau | Connexion et ping sains, mais **les commandes du client ne remontaient pas**. Trois manches d'instrumentation F3 ont mené à la cause : des noms de nœuds auto-générés divergents entre machines. Corrigé. |
| 2026-08-16 (soir) | Même réseau | Commandes et déplacements ✅. **Killcam tronquée** : tampon de rejeu dimensionné en images et non en durée, effondré par le déplafonnement des fps. Corrigé — enregistrement à 60 Hz fixe. |
| 2026-08-16 (fin) | Même réseau | **Tout fonctionne** : commandes, tirs, dégâts, killcam des deux côtés. Phase 3 close. |
