# Candela 2D — Feuille de route

> **Document de référence du projet.** Toute session de travail le lit avant
> d'agir et le met à jour avant de conclure. Protocole de mise à jour : voir
> [README.md](../README.md).
>
> Dernière mise à jour : 2026-08-16

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
| 4 | **Supabase — compétitif / ELO** | 🟡 **En cours** — en attente du jalon humain H5 (création du projet Supabase) |

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

## Phase 4 — Supabase (compétitif / ELO) 🟡

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

### Périmètre

- Calcul d'ELO dans une Edge Function (jamais côté client — les stats EOS sont
  alimentées par le client, donc trichables pour un classement sérieux).
- Résultat de match **rapporté par les deux pairs** et validé seulement s'ils
  concordent. À ne pas surestimer : cela empêche l'un des deux de déclarer un
  faux résultat, mais **pas** un hôte au client modifié de tricher *pendant* le
  match, puisque c'est lui qui simule tout. C'est la seule parade disponible en
  P2P, pas une protection équivalente à un serveur — voir la décision
  « P2P conservé » plus bas.
- **Authenticité de l'identité** : le PUID seul ne prouve rien, n'importe qui
  pourrait en poster un. Chaque pair doit joindre son jeton d'identité Epic,
  que l'Edge Function vérifie auprès d'Epic avant d'écrire quoi que ce soit.
- Prévoir dès le schéma un champ d'**origine de l'arbitrage** (pair / serveur) :
  c'est ce qui permettra d'introduire un serveur dédié plus tard sans invalider
  l'historique déjà accumulé.
- Historique, saisons, liste de salons (reportée depuis la Phase 3).
- Le PUID Epic sert de clé d'identité, **après vérification** : le client joint
  son jeton signé par Epic (`EOS.Connect.ConnectInterface.copy_id_token`,
  disponible dans le plugin — vérifié le 2026-08-16), que l'Edge Function
  valide contre les clés publiques d'Epic avant d'en extraire le PUID. Sans
  cette étape, n'importe qui pourrait poster n'importe quel PUID.
- **Récupération d'identité : code de récupération** (décision du 2026-08-16).
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
- Fondation déjà en place : `match_record.gd` archive chaque match dans
  `user://match_history.json` (vainqueur, durée, armes, carte, mode, format).

---

## Décisions actées

| Décision | Raison |
|---|---|
| **Format BO1, 5 minutes** | Un duel où chaque erreur est fatale se suffit en une manche : c'est ce qui rend chaque décision lourde. Le format transite par `MatchRecord.Format` — un BO3/BO5 s'ajouterait sans refonte, mais n'est pas implémenté. |
| **EOS conservé** pour la connectivité | NAT traversal + relais gratuits, sans serveur à maintenir. |
| **Code de salon**, pas de liste de salons | Geste le plus immédiat pour « je joue avec un ami ». La liste n'a de sens qu'avec du matchmaking → Phase 4. |
| **Images par seconde déplafonnées** | EOS coûte ~31 ms de latence de plus qu'ENet à 60 fps (54 ms contre 23 ms). Le levier est la cadence d'image, pas le nombre de ticks (+2 ms seulement en tickant deux fois par frame). Norme du jeu compétitif. |
| **Pas d'adhésion Apple Developer** avant une sortie publique macOS | 99 $/an. Jusque-là : builds non signés + « Ouvrir quand même » dans Réglages Système. La signature/notarisation reste entièrement à valider le jour venu. |
| **Anti-camping reporté** | Une autre mécanique sera choisie. Ne pas réintroduire mort subite / arène qui rétrécit sans arbitrage. |
| **P2P conservé, pas de serveur dédié** | Décision du 2026-08-16. Un serveur supprimerait l'avantage de l'hôte et la triche par l'hôte, mais **dégraderait la latence des deux joueurs** — aujourd'hui l'un des deux joue à 0 ms — et coûterait un hébergement à vie. Il se justifiera quand le classement aura assez d'enjeu pour qu'on triche dessus, donc quand il y aura des joueurs. La bascule resterait peu coûteuse : le netcode étant déjà hôte-autoritaire, un serveur dédié n'est qu'un hôte headless sans joueur local. Il faudrait ajouter un mode « hôte sans joueur » et une orchestration ; rien ne serait à jeter. |
| **Killcam locale** (chacun rejoue son enregistrement) | Le joueur revoit exactement ce qu'il a vu : meilleur outil pour comprendre sa mort. Les deux killcams peuvent légitimement différer. |

---

## Pièges connus — ne pas les redécouvrir

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

**Export macOS**
- `textures/vram_compression/import_etc2_astc=true` est obligatoire dans
  `project.godot`, sinon l'export refuse de démarrer.
- Ne pas utiliser `custom_template` : installer les modèles d'exportation depuis
  le gestionnaire intégré de Godot (un téléchargement manuel corrompu avait fait
  croire à un bug de l'éditeur).
- Les entitlements réseau ne servent que sous App Sandbox (Mac App Store). En
  distribution directe, EOS ouvre ses sockets sans entitlement.

---

## Jalons humains — ce qui ne peut pas être automatisé

Tout le reste doit être fait par des agents. Ces points-là exigent Adrien.

| # | Jalon | Pourquoi humain | Quand |
|---|---|---|---|
| H1 | **Test à deux machines sur deux réseaux Internet distincts** | Exige un second poste et une seconde connexion. Le scénario qui compte : les deux postes en partage de connexion mobile (CGNAT des deux côtés). | ✅ Fait le 2026-08-16 — **contre-vérification à refaire** depuis les correctifs |
| H2 | Transfert manuel de `eos_credentials.gd` vers la seconde machine | Le fichier est ignoré par git : il ne voyage pas avec le clone. Clé USB ou AirDrop, jamais par mail. | Avec H1 |
| H3 | Playtest de ressenti (game feel) | Aucun agent ne peut juger si le jeu est amusant, lisible, tendu. | Après H1 |
| H4 | Adhésion Apple Developer + notarisation | Décision d'achat (99 $/an), puis validation sur machine vierge. | Avant une sortie publique macOS |
| H5 | **Création du projet Supabase et de ses clés** | Compte à créer, région à choisir, décisions de coût. | **Prochain jalon bloquant** |

---

## Prochaines étapes

1. **H5 : créer le projet Supabase** — Adrien. Rien ne peut commencer sans ses
   clés. Étapes numérotées de la Phase 4 détaillées dans sa section.
2. Reste dû de la Phase 2, jamais déroulé : la checklist manuelle
   `CHECKLIST_TESTS_EN_LIGNE.md` et la validation à 120 ms de latence simulée.
3. Deux points connus, sans urgence : le relais Epic n'a jamais été exercé (la
   connexion directe a toujours abouti), et la détection de déconnexion est
   lente des deux côtés.

## Journal des tests à deux machines

| Date | Configurations | Résultat |
|---|---|---|
| 2026-08-16 (matin) | Même Wi-Fi ; un poste en 4G ; les deux en 4G, opérateurs différents | `Lien DIRECT` partout, ping 58 ms. Trois défauts relevés : jointure incertaine, message trompeur, killcam muette. Tous corrigés depuis. |
| 2026-08-16 (après-midi) | Même réseau | Connexion et ping sains, mais **les commandes du client ne remontaient pas**. Trois manches d'instrumentation F3 ont mené à la cause : des noms de nœuds auto-générés divergents entre machines. Corrigé. |
| 2026-08-16 (soir) | Même réseau | Commandes et déplacements ✅. **Killcam tronquée** : tampon de rejeu dimensionné en images et non en durée, effondré par le déplafonnement des fps. Corrigé — enregistrement à 60 Hz fixe. |
| 2026-08-16 (fin) | Même réseau | **Tout fonctionne** : commandes, tirs, dégâts, killcam des deux côtés. Phase 3 close. |
