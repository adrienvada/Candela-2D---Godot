# V6 — Vérification contradictoire : le réseau (fiabilité et latence du duel en ligne)

Vérificateur : V6, contradicteur, lecture seule, Godot non lancé. Dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1`. Rapport source : `audit/08_RES_reseau.md` (blocs RES-01, 02, 04, 05, 07, 09, 10 lus en entier), plus `audit/05_JOU_joueur_balles.md` (JOU-10), `audit/06_ETA_game_state.md` (ETA-09, partie historique de compensation seulement), `audit/14_CAR_cartes_replay.md` (CAR-07).

**Sources, toutes lues pour de bon et non recopiées de l'audit.**
1. Le dépôt (fichiers cités avec `fichier:ligne`).
2. **Moteur Godot 4.7.1-stable**, téléchargé depuis `raw.githubusercontent.com/godotengine/godot/4.7.1-stable` : `scene/main/scene_tree.cpp`, `main/main.cpp`, `modules/multiplayer/{scene_multiplayer,scene_rpc_interface,scene_replication_interface,multiplayer_synchronizer}.cpp`, `scene/main/{multiplayer_api,http_request,multiplayer_peer}.cpp`, `core/io/{marshalls,packet_peer,http_client_tcp}.cpp`. Les dix fichiers que l'auditeur avait copiés dans `audit/src/v471/` et que j'ai re-téléchargés (`scene_tree`, `main`, `scene_multiplayer`, `scene_rpc_interface`, `scene_replication_interface`, `multiplayer_synchronizer`, `multiplayer_api`, `marshalls`, `http_request`, `enet_multiplayer_peer`) sont **octet pour octet identiques** (`cmp`) ; `http_client_tcp`, `packet_peer` et `multiplayer_peer` sont des ajouts de ma part.
3. **EOSG tag `2.3.0`** (la version de `plugin.cfg`), source C++ téléchargée depuis `raw.githubusercontent.com/3ddelano/epic-online-services-godot/2.3.0/src/` : `eosg_multiplayer_peer.{cpp,h}`, `eosg_packet_peer_mediator.{cpp,h}`, `ieos.cpp`.
4. **Binaires EOSG** de `addons/epic-online-services-godot/bin/` : `nm` et `objdump` sur le `.so` Linux debug ; `strings` sur les deux binaires macOS (release et debug). Aucune exécution.
5. Copies de travail et scripts de calcul dans `audit/v6_work/` (hors dépôt) : `godot471/`, `eosg230/`, `codes.py`.

**Légende.** PROUVÉ = lu dans le code du dépôt, du moteur, d'EOSG ou du binaire. ESTIMÉ = raisonné, non mesuré. NON VÉRIFIÉ = je n'ai pas pu le lire (SDK Epic fermé, serveur, machine d'Adrien).

---

## 0. Verdicts

| ID(s) | Verdict | Sévérité corrigée | Coût corrigé |
|---|---|---|---|
| RES-01 | CONFIRMÉ | MAJEUR | pas de coût de cadence ; panne fonctionnelle silencieuse au-delà de ~1 100 caractères de code de carte (EOS seulement) |
| RES-02 | CONFIRMÉ AVEC RÉSERVE | MAJEUR | gain de latence : borne 2T (33 ms à 60 i/s) ; réaliste ≈ 23-29 ms de RTT à 60 i/s, 4-10 ms à 144, ≈ 0-2 ms à 500 ; commandes et état publié plus frais d'une image ; compensation de tir à revalider (elle se rapproche de la vérité, ESTIMÉ) |
| RES-05 | CONFIRMÉ | MINEUR | 0 en cadence ; retour de dégâts et télémétrie muets sur un coup de loin en loin (fréquence non mesurée) |
| RES-07 | CONFIRMÉ AVEC CORRECTION | MINEUR | 0 ; décompte exact, mais la sonde sous-estime le paquet SYNC d'environ la moitié et non de 18 % |
| RES-04 | CONFIRMÉ | MINEUR | 0 |
| RES-09 + ETA-09 + JOU-10 | CONFIRMÉ (coût) ; RÉFUTÉ (enjeu d'équité) | ANECDOTIQUE | ≈ 1-10 µs par image (≤ 0,5 % d'un cœur à 500 i/s), non mesuré |
| RES-10 | CONFIRMÉ AVEC RÉSERVE | ANECDOTIQUE | un gel unique de plusieurs secondes, surtout `ditto` ; le « 2 à 4 s » du SHA-256 n'est pas fondé (≈ 0,2-1,2 s, non mesuré) |

---

## 1. L'ordre exact d'une image (prouve RES-02, sert tout le rapport)

Moteur 4.7.1, EOSG 2.3.0, autoloads dans l'ordre de `project.godot`. PROUVÉ par lecture.

| # | Quand | Ce qui se passe | Source |
|---|---|---|---|
| 1 | `Main::iteration`, 0 à N pas physiques | `SceneTree::physics_process` : signal `physics_frame`, puis tous les `_physics_process` | `main.cpp:4997`, `scene_tree.cpp:639-671` |
| 1a | pas physique, **client** | `Player._physics_process` -> `_send_inputs_to_host()` -> `rpc_id(1,"rpc_send_inputs",…)` -> `EOSGMultiplayerPeer::_put_packet` -> `EOS_P2P_SendPacket`, **immédiat** (aucune file côté EOSG) | `player.gd:1727, 1429-1446`, `eosg_multiplayer_peer.cpp:486-541, 905-927` |
| 1b | pas physique, **hôte** | J2 applique la dernière commande reçue (`get_movement_vector`) ; dégâts -> `rpc_update_hp.rpc` ; tirs -> `rpc_spawn_bullet.rpc`, envois immédiats | `player.gd:1769, 2829`, `game_state.gd:4150` |
| 2 | `Main::iteration`, une fois par image rendue | `SceneTree::process` | `main.cpp:5058`, `scene_tree.cpp:688` |
| **2a** | début de `process` | **`multiplayer->poll()`** (si `multiplayer_poll`, vrai par défaut). `EOSGMultiplayerPeer::_poll` vide la file du médiateur (**remplie par la pompe de l'image précédente**) vers le socket du pair ; `SceneMultiplayer::poll` traite alors **tous** les paquets (les gestionnaires de RPC s'exécutent ici ; les états synchronisés écrasent `net_*` et `hp` chez le client) ; enfin `replicator->on_network_process()` : l'hôte envoie la synchro **si elle est due**, en lisant `net_*` **tels que le `_process` de l'image précédente les a écrits** | `scene_tree.cpp:706-711`, `scene_multiplayer.cpp:67-167`, `eosg_multiplayer_peer.cpp:668-…`, `scene_replication_interface.cpp:129-154, 802-853` |
| **2b** | juste après, signal `process_frame` | **Pompe EOSG** `EOSGPacketPeerMediator::_on_process_frame` : boucle `EOS_P2P_GetNextReceivedPacketSize` / `EOS_P2P_ReceivePacket` -> files par socket. Puis reprise de tout `await get_tree().process_frame` | `scene_tree.cpp:713`, `eosg_packet_peer_mediator.cpp:52-120` |
| **2c** | `_process(false)` : `process_priority` croissante, puis ordre de l'arbre (autoloads d'abord) | `NetworkManager._process` (ping 1 Hz : `rpc_id(…,"rpc_ping")`) -> … -> **`EOSGRuntime._process` : `IEOS.tick()` -> `EOS_Platform_Tick`** -> … -> `Matchmaker` -> scène : `GameState._process` (`_record_position_history`, `rpc_sync_time`), `Player._process` (**publication des `net_*` de l'hôte**), UI ; `presentation_3d` en dernier (priorité 10000) | `scene_tree.cpp:719, 1177-1236`, `project.godot` `[autoload]` (NetworkManager 6e, EOSGRuntime 10e), `network_manager.gd:967`, `runtime.gd:35`, `player.gd:1259-1268`, `presentation_3d.gd:463` |
| 2d | après `_process` | minuteurs et tweens (`create_timer().timeout`, p. ex. le ping de `test_transport`) | `scene_tree.cpp:729-730` |
| 3 | fin d'image | rendu | `main.cpp:5085-5089` |

Réponses aux quatre questions de la mission :
- **`multiplayer.poll()`** : 2a, avant tout `_process`, avant `process_frame`.
- **`process_frame`** : 2b, immédiatement après le sondage.
- **`EOS_Platform_Tick`** : 2c, dans `EOSGRuntime._process`, donc **après** la pompe et **avant** les `_process` de la scène. `IEOS::tick()` ne fait que `EOS_Platform_Tick` (`ieos.cpp:567-570`).
- **Vidage des files vers le pair multijoueur** : à 2a de l'image **suivante**. La pompe (2b) ne fait que déplacer SDK -> files du médiateur ; le passage médiateur -> socket -> `SceneMultiplayer` est l'affaire de `_poll`, appelé par `multiplayer->poll()`.
- **Envois du jeu** : commandes du client en 1a (physique) ; tout le reste (tirs, PV, bruits, gadgets) depuis la physique de l'hôte ou depuis un gestionnaire de RPC (2a) ; synchro à 2a ; ping à 2c.

---

## 2. RES-01 — la limite de paquet EOS et `rpc_start_round`

**Verdict : CONFIRMÉ. Sévérité : MAJEUR (fonctionnel).**

### 2.1 Le code
- **Limite PROUVÉE trois fois.**
  - Source 2.3.0 : `eosg_multiplayer_peer.cpp:558-560` `_get_max_packet_size()` rend `EOS_P2P_MAX_PACKET_SIZE`.
  - Binaire : `godot::EOSGMultiplayerPeer::_get_max_packet_size() const` en `0x15ce94` contient `mov $0x492,%eax` = **1 170** (`objdump`), et la table de chaînes porte `EOS_P2P_MAX_PACKET_SIZE 1170`.
  - Les deux messages de refus sont présents dans le `.so` Linux **et** dans les binaires macOS release et debug.
- **Refus, ni fragmentation ni troncature.** `eosg_multiplayer_peer.cpp:491` : `ERR_FAIL_COND_V_MSG(p_buffer_size > _get_max_packet_size(), ERR_UNAVAILABLE, "Failed to send packet. Packet size exceeds limits.")` ; second garde sur le paquet complet, **charge + 6 octets d'en-tête** (`eosg_multiplayer_peer.h:63` `PACKET_HEADER_SIZE = 6`) : `:906` (`_send_to`) et `:869` (`_broadcast`) -> `ERR_OUT_OF_MEMORY`. Charge Godot maximale : **1 164 octets**. Le canal fiable n'y change rien : les gardes précèdent `EOS_P2P_SendPacket`.
- **Le moteur ignore l'échec.**
  ```cpp
  // scene_rpc_interface.cpp:441-444 (et 458-469) — le retour de send_command n'est jamais lu
  for (const int P : targets) { multiplayer->send_command(P, packet_cache.ptr(), ofs); }
  // scene_rpc_interface.cpp:499-516 — puis rpcp() exécute l'appel local (call_local)
  ```
  `SceneMultiplayer::send_command` (`scene_multiplayer.cpp:260-286`) rend l'erreur en unicast et la jette en diffusion. Aucune ligne du module multiplayer ne lit `get_max_packet_size`, et la méthode **n'est pas exposée à GDScript** (`packet_peer.cpp:139-149` ne la lie pas ; seul `_get_max_packet_size` existe, virtuel de `MultiplayerPeerExtension`). Toute garde du jeu doit donc **coder la constante en dur**. (Au passage : `tools/peer_spy.gd` appelle `inner.get_max_packet_size()`, qui n'existe pas côté script ; il ne plante pas parce que personne ne l'appelle.)
- **Taille du paquet** : `1 + 1 + 1 + 1` (en-tête) + 2 + 2 (deux entiers) + `8 + pad4(L)` (code) + `8 + 32` (`match_id` = 16 octets en hexadécimal, `game_state.gd:1914-1915`) = **`56 + pad4(L)`**. Le premier RPC vers un nœud dont le chemin n'est pas confirmé ajoute 3 octets (identifiant de nœud sur 4) et le chemin `Main\0` (5 octets : racine de `main.tscn`). Charge <= 1 164 -> **L <= 1 108** (chemin confirmé), **≈ 1 100** sinon. L'auditeur disait « ~1 100 » : exact.

### 2.2 Tailles réelles (recalculées, `audit/v6_work/codes.py`)
Méthode : JSON compact à clés triées, flottants en `x.0` comme après lecture JSON de Godot, gzip niveau par défaut, base64, préfixe `CANDELA-`.

| Carte | Grille | Runs mur | Code | Paquet EOS |
|---|---|---|---|---|
| `default` | 32×32 | 58 | 512 | ≈ 576 |
| `arene_circulaire` | 24×24 | 52 | 536 | ≈ 600 |
| `map_004_le_bunker` | 26×26 | 62 | 592 | ≈ 656 |
| `map_003_la_croisee` | 28×28 | 68 | 620 | ≈ 684 |
| `map_001_le_cloitre` | 30×30 | 72 | 636 | ≈ 700 |
| `map_002_l_usine` | 32×26 | 68 | 644 | ≈ 708 |

Les six cartes livrées passent avec ≥ 460 octets de marge (l'audit disait 500-636 : à 1-2 % près). **Cartes joueur** (synthétiques : pièces à portes sur grille n×n, un run par ligne de mur vertical) :

| Grille | Pièces | Runs mur | Code | Paquet EOS | |
|---|---|---|---|---|---|
| 32×32 | 4 | 112 | 704 | ≈ 768 | passe |
| 40×40 | 8 | 207 | 1 012 | ≈ 1 076 | passe |
| 48×48 | 10 | 226 | 1 124 | ≈ 1 188 | **refusé** |
| 64×64 | 16 | 399 | 1 696 | ≈ 1 760 | refusé |
| 128×128 (plafond de l'éditeur : `map_codec.gd:27`, `map_editor.gd:942`) | 40 | 882 | 3 668 | ≈ 3 732 | refusé |
| 128×128 | 80 | 1 389 | 5 484 | ≈ 5 548 | refusé |
| 128×128 damier pathologique | - | 8 192 | 25 764 | ≈ 25 800 | refusé |

Le seuil tombe vers **215-220 runs de mur, soit trois fois la plus riche des cartes livrées** (72 runs) ; dans mes essais, entre une grille de 40 et une grille de 48 de côté (c'est le nombre de runs qui décide, pas la grille). Les murs verticaux coûtent cher : un run par ligne. La répartition réelle des cartes joueur est inconnue (aucune donnée dans le dépôt) : la fréquence est ESTIMÉE, la panne ne l'est pas.

### 2.3 Fréquence (appelants remontés)
- Par événement : chaque `rpc_start_round.rpc(…, _host_map_code(), …)`, donc la **première manche** (`game_state.gd:1836`, `_start_round`) **et chaque revanche** (`:5818`, `_check_rematch_start` ; l'audit ne citait pas ce second site).
- **EOS seulement.** ENet fragmente (`enet_multiplayer_peer.cpp`), et aucun banc EOS n'envoie plus de 1 170 octets : aucune suite actuelle ne peut le voir.
- Conditions : la carte courante de l'hôte dépasse ~1 100 caractères. (a) Salon à code : toute carte de la galerie est hébergeable (badge `PERSO`, `map_gallery.gd:389` ; aucun filtrage de `source` à l'hébergement). (b) Classé : `select_random_map()` tire **uniformément dans tout le catalogue de l'hôte**, cartes joueur comprises (`map_data.gd:217-222`, `_catalog` = livrées + `user://maps/`, `:63-78`, via `game_state.gd:5583-5587`) : un hôte qui possède k cartes trop lourdes sur N échoue avec la probabilité k/N à chaque match classé qu'il héberge. Un joueur qui n'a que les six cartes livrées n'est jamais touché.

### 2.4 Coût et ce que voit le joueur
Pas de coût de cadence. **Hôte** : `rpcp()` exécute l'appel local, `_do_start_round` s'exécute, la manche part ; il est seul dans l'arène, J2 immobile sur son point d'apparition. Trace unique : une ligne `ERROR: Condition "p_buffer_size > _get_max_packet_size()" is true. Returning: ERR_UNAVAILABLE` dans la console. **Client** : reste sur son écran d'attente, sans message. Je n'ai trouvé à la lecture **aucune échéance côté client** qui attende `rpc_start_round` (les échéances de 20 s, `game_state.gd:5520-5553`, ne couvrent que la connexion). Effet de bord : `_forfeit_pending` est armé chez l'hôte (`:1953`), donc le quitter peut y inscrire un forfait local ; le classement exige deux rapports appariés par `match_id` (`supabase/functions/report/index.ts:2-3`), donc pas de victoire gratuite attendue, **NON VÉRIFIÉ côté SQL**.

### 2.5 Croisement avec CAR-07
Orthogonaux. Les bornes proposées par CAR-07 (`MAX_RLE_CHARS = 131 072`, `MAX_RUNS = 16 384`) laissent passer des cartes valides dont le code fait ~60 Ko : **elles ne protègent pas du plafond EOS**. Inversement, le plafond EOS ne neutralise pas CAR-07 : un code de 1 100 caractères (≈ 820 octets gzip) peut se décompresser en ≈ 0,85 Mo de JSON, soit ≈ 100 000 runs de 128 cases, ≈ 13 millions de `Vector2i` (ordre de grandeur calculé, non exécuté) ; et ENet n'a aucune limite. Les deux bornes devraient vivre côté `MapCodec` (par exemple `MapCodec.EOS_CODE_MAX`) et se tester ensemble.

### 2.6 Invariants et statut
Correctif sans changement de fil : `MapCodec.VERSION` et les signatures de RPC ne bougent pas, `WIRE_WITNESS` et `Protocol.VERSION` non plus ; `rpc_hello` intact. Tests concernés : `test_carte_partagee` (cinq cas d'adoption), `test_map_codec`, `test_protocole`, `test_online_match.gd:346` (appelle `_poser_la_carte_appariee()` sur la seule branche **amicale**, carte par défaut ; `select_random_map` n'a **aucun** test dans `tools/`, le filtre du tirage classé en demande donc un neuf). Tout découpage de la carte en plusieurs paquets exige un RPC ou un sens nouveau : `VERSION = 20`, une mineure (`test_corps_soi_fondu.gd:208` et `test_corps_soi_sombre.gd:178` figent `Protocol.VERSION == 19` : ils bougeront). Le filtre du tirage classé touche à la question d'équité encore ouverte (ROADMAP:2112-2124) : le présenter comme contrainte technique, pas comme la décision d'Adrien. **Statut ROADMAP : NOUVEAU** (aucune occurrence de `1170`, `max_packet` ni `MTU` ; « une carte complète tient dans ~300-500 caractères », `map_codec.gd:11`, n'est garanti par rien).

### 2.7 Correctif minimal
1. `NetworkManager` : constante `EOS_CHARGE_MAX := 1164` et `charge_max()` (valeur énorme hors EOS), pour garder la règle « aucun `if transport` hors `network_manager.gd` ».
2. `GameState` : avant les **deux** `rpc_start_round.rpc` (`:1836`, `:5818`), si `56 + pad4(len(code)) + 8 > charge_max()`, ne pas lancer ; `ui.show_dialog_message(…)` (déjà utilisé par `_refuse_match_on_map`) : « cette carte est trop détaillée pour le jeu en ligne Epic (N caractères, maximum 1 100) ; jouez-la en LAN ou simplifiez-la » ; repli sur la carte par défaut.
3. `MapData.select_random_map()` : écarter les entrées dont le code dépasse la limite quand le transport est EOS.
4. Galerie et éditeur : afficher la taille du code et avertir au-delà du seuil.

### 2.8 Comment le prouver dans le cloud
- Suite headless de garde : chaque carte livrée a `MapCodec.to_share_code(...).length() <= 1 000`.
- Preuve de la moitié « moteur » sans Epic : un `MultiplayerPeerExtension` de test qui recopie les deux gardes d'EOSG (`_get_max_packet_size()` = 1 170, refus au-delà de 1 164 avec `push_error`), puis un RPC fiable `call_local` portant une chaîne de 1 400 caractères : l'appel local s'exécute, la réception distante jamais, aucune erreur ne remonte à l'appelant. La moitié « EOSG » est prouvée par la source et le désassemblage ci-dessus.
- Tests unitaires du garde et du filtre (carte de 1 124 caractères refusée, carte livrée acceptée).
- Hors cloud, une fois : `test_transport` en EOS avec un RPC de 2 000 caractères (identifiants Epic requis ; ce n'est pas une mesure de cadence).

---

## 3. RES-02 — la pompe EOS tourne après le sondage

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : MAJEUR (latence).** Le mécanisme est prouvé ; l'ampleur est surestimée par l'audit ; plusieurs points du texte sont à corriger.

### 3.1 Le mécanisme (PROUVÉ, voir le tableau §1)
Un paquet qui arrive au SDK pendant l'image N est lu par la pompe en **2b de l'image N+1**, puis livré par le sondage en **2a de l'image N+2** : délai arrivée -> gestionnaire = entre T et 2T (moyenne 1,5 T). Avec un sondage placé **après** la pompe : entre ε et T + ε (moyenne 0,5 T + ε), où ε est le temps entre `process_frame` et le sondage. ENet lit sa socket dans `poll()` lui-même : 0,5 T. Modèle de RTT applicatif : EOS actuel ≈ 3 T, ENet ≈ T, EOS corrigé ≈ T + 2ε.

**Fréquence (appelants remontés).** Par image rendue, sur le transport EOS seulement, pour **chaque paquet des deux sens** (le sondage et la pompe sont des services du moteur et d'EOSG, pas du jeu : rien dans `network_manager.gd` ni `player.gd` ne sonde à la main, `grep` : aucun `.poll()` ni `multiplayer_poll` hors `tools/peer_spy.gd:105`). Le chemin est actif dans tout duel EOS standard ; il ne l'est pas en entraînement ni en solo (pas de pair).

### 3.2 Ce que la ROADMAP mesure déjà, et qui corrobore le modèle
- ROADMAP:135-137 : RTT_AVG 49,7-50,3 ms à 60 i/s plafonnés (3 T = 50,0), 22,3 déplafonné ; autre session : 21,2 ms à 145 i/s (3 T = 20,7). RTT_MIN 46,0 contre 13,3.
- **ROADMAP:2585** (décisions actées) : « EOS coûte ~31 ms de latence de plus qu'ENet à 60 fps (54 ms contre 23 ms). Le levier est la cadence d'image, pas le nombre de ticks (**+2 ms seulement en tickant deux fois par frame**). » L'écart EOS - ENet vaut 2 T (33,3) à 2 ms près.
- **Correction de l'audit** : il écrit que l'expérience `--extra-tick` « n'a aucun résultat consigné ». Elle l'est, à ROADMAP:2585, et le résultat va dans son sens : le tick n'est pas le goulet.
- Le modèle n'explique pas un point : la « mesure indépendante » à 59,0 ms à 60 i/s (+9 ms par rapport à 3 T). Autre session, conditions inconnues.

### 3.3 L'ampleur du gain
- **Borne haute** : 2 T = 33,3 ms à 60 i/s (13,9 à 144, 4,0 à 500). Le « −33 ms » de l'audit est cette borne : valable dans un banc headless où ε ≈ 0,1-0,5 ms.
- **En jeu** : gain = 2 T − (ε_hôte + ε_client). ε est le temps de script d'une image (ESTIMÉ 2-5 ms, à relever avec `Time.get_ticks_usec()` entre `process_frame` et la fin de `_process`) : **≈ 23-29 ms à 60 i/s, ≈ 12-18 à 90, ≈ 7-13 à 120, ≈ 4-10 à 144, ≈ 0-2 à 500**. Le gain est surtout aux cadences basses et aux images lentes du « 1 % bas » : c'est là que la cible 60 est jouée.
- **Prédiction falsifiable du banc** (`test_transport --max-fps 60`, EOS) : RTT_AVG de ~50 à ≈ 18-28 ms (le modèle donne T + 2ε ≈ 18 ; l'ENet mesuré à 23 ms, dont ~6 ms que le modèle n'explique pas, donne la fourchette haute), RTT_MIN de 46 à ≈ 14-20 ; en ENet **inchangé** (~23 ms), ce qui en fait un témoin.
- **Gains hors RTT** (décompte ESTIMÉ, avec φ = durée de la physique d'une itération et e_p = position de `Player._process` dans la passe) : la commande de J2 est appliquée **exactement T plus tôt** par l'hôte (pompe -> application : 2T − φ avant, T − φ après, parce que le pas physique ouvre l'itération) ; l'état publié (`net_*`, écrit par `Player._process`, lu par la synchro) part avec T − e_p de moins d'âge, y compris en **ENet** ; la vue qu'a le client de J1 est plus fraîche d'environ 2T − e_p − ε (réception + publication), soit ≈ 28-30 ms à 60 i/s.

### 3.4 Le correctif minimal
```gdscript
# network_manager.gd, _ready(), AVANT le `return` de --no-eos (même chemin en ENet, en EOS et dans les bancs)
process_mode = Node.PROCESS_MODE_ALWAYS   # le sondage du moteur ignorait la pause
process_priority = 100                    # après les _process de priorité 0 (publication des net_*), avant presentation_3d (10000)
get_tree().multiplayer_poll = false       # API documentée : « appeler MultiplayerAPI.poll() soi-même »

func _process(delta: float) -> void:
	multiplayer.poll()                    # PREMIÈRE instruction : avant le `return` de _remote_peer() == 0
	var target := _remote_peer()
	…
```
Variante-ceinture, une ligne : `EOSGRuntime.process_priority = 200`, pour que `EOS_Platform_Tick` suive le sondage dans la même image. Elle n'est utile que si `EOS_P2P_SendPacket` attendait un tick pour partir : **NON VÉRIFIÉ** (SDK fermé), mais l'expérience à +2 ms plaide pour que non.

### 3.5 Corrections au texte de l'audit
1. **`multiplayer_poll = false` + sondage manuel est le mécanisme prévu** (`scene_tree.cpp:1881-1887, 1977`), pas un contournement.
2. **Le sondage doit rester dans `_process`.** La pompe n'est branchée sur `process_frame` qu'**après la connexion Connect** (`eosg_packet_peer_mediator.cpp:380-398` appelle `_init()`, qui fait `main_loop->connect("process_frame", …)` à `:218-234`) : un rappel de `NetworkManager` branché à `_ready` se déclencherait **avant** la pompe (les signaux suivent l'ordre de connexion) et ne ferait rien gagner. Tout `_process` passe, lui, toujours après la pompe.
3. **« La paire (position, ack) redevient cohérente »** : vrai à un pas physique par image (≈ 60 i/s) ; faux au-delà. À 144 i/s plus d'une image sur deux (58 %) n'a pas de pas physique, et l'ack publié (dernier **reçu**, `player.gd:1267`) reste en avance sur la position (dernier pas **appliqué**) d'au plus un pas : 4,33 px à 260 px/s (`player.gd:70`), contre `PREDICT_DEADZONE = 4,0` (`:363`). Constat exact mais mineur ; la vraie correction serait de verrouiller le numéro appliqué dans `_physics_process`, indépendamment de RES-02. Le commentaire de `player.gd:377` (« dernier input appliqué ») reste faux.
4. **Le « 20 à 30 Hz réels » de la synchro** (`multiplayer_synchronizer.cpp:124-135`, `last_sync_usec = p_usec` sans report du reste) : exact, la période est quantifiée par les images.
5. **La variante de repli** (garder le sondage du moteur et en ajouter un second) ne donne que l'effet « réception » et laisse la synchro partir au premier sondage avec un état périmé : à ne pas retenir.

### 3.6 Risques et invariants
- **Ordre gestionnaires / `_process`.** Les gestionnaires de RPC s'exécutent désormais **après** les `_process` de la même image au lieu d'avant. Je n'ai trouvé aucun code qui s'appuie sur « gestionnaire avant `_process` » : les consommateurs (`rpc_send_inputs` -> `update_input_state`, `_apply_remote_interpolation`, `_ingest_prediction_correction`) lisent au pas physique suivant, qui précède de toute façon le sondage dans l'itération (`main.cpp:4997` avant `:5058`). À confirmer par les suites ; je n'ai pas lu chaque gestionnaire.
- **Compensation de latence : c'est le vrai risque, et il va plutôt dans le bon sens (ESTIMÉ, non mesuré).** Le recul que l'hôte applique au tir du client est `RTT/2 + 100 ms` (`game_state.gd:4309-4310`). Le recul réellement nécessaire est `R_vrai = D_commande + D_vue + 100 ms`, où `D_commande` est le délai tir -> application par l'hôte et `D_vue` l'âge de ce que le tireur voit de J1. Décompte à 60 i/s, réseau négligeable : avant, `D_commande ≈ 2,5 T` et `D_vue ≈ 2,5 T` -> `R_vrai ≈ 5 T + 100 ≈ 181 ms`, contre `R_formule ≈ 1,5 T + 100 ≈ 125 ms` : la formule **sous-couvre d'environ 3,5 T ≈ 56 ms** (la cible, donc l'hôte, est favorisée ; c'est la question ouverte 5 de l'audit, chiffrée). Après : `R_vrai` baisse de ≈ 3T − e_p − ε, `R_formule` de T − ε seulement : le biais se réduit d'environ **2 T (≈ 30 ms)**, à ≈ −24 ms. Le correctif **rapproche** donc la compensation de la vérité ; il ne la sur-corrigerait que si la formule était déjà juste, ce que rien n'établit. Le repère n'a **jamais** été validé (ROADMAP:89, 34071 : latence simulée de 120 ms jamais déroulée) : à mesurer à deux machines avec latence simulée, pas seulement au chronomètre. Symétrie : le client gagne deux étages, l'hôte un seul ; l'avantage de l'hôte à 0 ms **diminue**. Le plafond `LAG_COMP_MAX = 0,2` (`game_state.gd:263`) borne la formule, pas `R_vrai` : il ne joue qu'au-delà de 200 ms de RTT et n'est pas concerné.
- **Arrêt EOS.** Le piège (`EOSGRuntime.set_process(false)` -> `await process_frame` -> `release()`, ré-entrée dans `EOS_Platform_Tick` = segfault, `network_manager.gd:931-961`) **n'est pas touché** : `multiplayer.multiplayer_peer = null` est posé avant (`:949`), donc le sondage de l'image d'arrêt est un no-op ; le sondage tourne dans `NetworkManager._process`, **hors** de la pile native du tick ; la reprise de l'`await` reste à `process_frame`, avant tout `_process`. Aucune nouvelle entrée dans le SDK depuis un callback.
- **Défaillance silencieuse si `NetworkManager._process` ne tourne plus** : plus aucun paquet n'est lu. D'où `PROCESS_MODE_ALWAYS`, la position du sondage en première instruction, et un test statique (§3.8). Un seul propriétaire : les tests qui font `load("res://network_manager.gd")` (`test_matchmaking.gd:226`) n'inspectent que des constantes, sans monter de nœud.
- **Tests qui lisent le texte de `network_manager.gd`** : `test_corps_soi_fondu.gd:210`, `test_corps_soi_sombre.gd:180` (absence de `soi_fondu`, `soi_sombre`), `test_plafonniers.gd:554` (absence de `plafonnier`), `test_protocole.gd:111` (constantes de salon). Aucun ne s'oppose.

### 3.7 Statut
CONNU-OUVERT pour la dépendance du RTT à la cadence (ROADMAP:135-139, 2585, 17240-17245) ; **NOUVEAU** pour la cause (ordre sondage / pompe) et pour le remède.

### 3.8 Comment le prouver dans le cloud
1. **Test d'ordre, sans Epic** (`tools/test_ordre_reseau.gd`, `--headless`). Deux `SceneMultiplayer` dans un arbre (`set_multiplayer(api, chemin)`), reliés par un `MultiplayerPeerExtension` qui imite EOSG : `_put_packet` pose dans la file « SDK » de l'autre pair ; une pompe branchée sur `process_frame` la vide vers une boîte de réception ; `_poll()` vide la boîte vers la file lue par `_get_packet`. Un RPC émis depuis `_physics_process` (comme `rpc_send_inputs`) à l'itération k : gestionnaire à **k + 2** avec le sondage du moteur, à **k + 1** avec le sondage manuel ; une propriété synchronisée écrite dans `_process` est lue chez le pair une image plus récente. Mesure en indices d'images (`Engine.get_process_frames()`), pas en millisecondes : déterministe.
2. **Garde statique** : `get_tree().multiplayer_poll == false`, `NetworkManager.process_priority == 100`, `process_mode == PROCESS_MODE_ALWAYS`.
3. **Témoin ENet à deux processus** : `./tools/run_duo.sh` et `test_transport` en ENet (`--transport enet --max-fps 60`), avant puis après : RTT inchangé (~23 ms ±2), aucun `SCRIPT ERROR`, aucun `push_error`.
4. **Neutralité CPU** : temps de `NetworkManager._process` à pas fixe (`--fixed-fps 60`), inchangé.
5. **Hors cloud** (identifiants Epic, deux instances) : `RTT_MIN_MS` / `RTT_AVG_MS` de `test_transport --eos-ephemeral --max-fps 60` et `144`, avant puis après ; puis `test_online_match`.

---

## 4. RES-05 — `hp` répliqué à 30 Hz et annoncé par `rpc_update_hp`

**Verdict : CONFIRMÉ. Sévérité : MINEUR.**

### 4.1 Le code
```gdscript
# player.gd:622 — la synchro écrit `hp` chez le client, pour ses DEUX joueurs
rep_config.add_property(NodePath(".:hp"))
# player.gd:2879-2900 — le RPC compare à `hp`, déjà réécrit par la synchro dans le cas fâcheux
if new_hp < hp:   # vibration, recul de caméra, souffle
	…
gs_tel.noter_pv_perdus(player_id, source_id, cause, maxf(hp - new_hp, 0.0), …)
hp = new_hp
```
Le commentaire de `player.gd:2889-2890` (« le client ne touche `hp` qu'ici, au départ de manche et au retour au menu ») est **faux** : `SceneReplicationInterface::on_sync_receive` appelle `set_state` -> `set_indexed("hp")` à chaque paquet (`scene_replication_interface.cpp:886-895`). Si la synchro arrive avant le RPC : pas de retour de dégâts, perte comptée **0**. La mort reste exacte (`hp = new_hp`, puis `if hp <= 0 and not dead: die()`, avec `mortel` vrai).

### 4.2 Fréquence
Un RPC fiable par dégât reçu ; `hp` repart dans chaque synchro (≈ 24-30 Hz). Côté hôte (`take_damage`, `player.gd:2825-2831`) : le RPC part dans la physique, la synchro suivante dans la même image si elle est due, donc **les deux paquets quittent l'hôte à quelques microsecondes d'écart, RPC en tête**. Le cas fâcheux demande un renversement à l'arrivée, ou une perte du fiable. **L'audit dit « seulement sous perte ou gigue » : c'est la thèse à nuancer, car l'ordre de livraison entre un paquet fiable et un non fiable n'est garanti ni par ENet (canaux 0 et 1 indépendants) ni par EOS (SDK fermé, canaux multiplexés) : NON VÉRIFIÉ.** Fréquence non mesurée ; le lien relayé n'a jamais été exercé (ROADMAP:228).

### 4.3 Coût
0 en cadence. Effet : un coup sans vibration, sans recul de caméra, sans souffle, et une télémétrie client sous-comptée sur ce coup. Or la ROADMAP a décidé (ligne 2575) que « les deux archives d'un match disent la même chose, à la gigue près » en comptant sur `rpc_update_hp` : l'hypothèse « seul écrivain de `hp` » qui la fonde est fausse.

### 4.4 Invariants et statut
Correctif sans fil : conserver côté script la dernière valeur **annoncée** (`_hp_annonce`, remise à 100 là où `hp = 100.0` est posé : `game_state.gd:1157, 1182, 1976-1977, 6414, 6419`), comparer contre elle. **Piège** : un oubli de remise à zéro se lit comme une perte fausse, le genre de repli muet que le dépôt traque. **Ancres textuelles à conserver** : `tools/test_telemetrie_gadgets.gd:327, 343-344` lisent le texte de `player.gd` et exigent `gs_tel.noter_pv_perdus(player_id, source_id, cause,`, `rpc_update_hp.rpc(new_hp, sid, cause)` et `rpc_update_hp(new_hp, sid, cause)`, et interdisent `has_method("noter_pv_perdus")`. Retirer `.:hp` de la synchro supprimerait la cause mais change le fil (`VERSION 20`, à grouper avec une rupture déjà due). **Statut : NOUVEAU.** Rien dans la ROADMAP sur la double voie.

### 4.5 Comment le prouver dans le cloud
Test headless : `p.hp = 60.0` (valeur déjà écrite par la synchro), puis `p.rpc_update_hp(60.0, 0, 0)` ; vérifier que `noter_pv_perdus` reçoit 40 et que le retour de dégâts joue (doublure de `GameState` avec compteur).

---

## 5. RES-07 — charge utile et `sync_probe` désaligné

**Verdict : CONFIRMÉ AVEC CORRECTION. Sévérité : MINEUR** (la décision de ne pas toucher au fil est juste ; l'écart du banc est une réparation de petite taille).

### 5.1 Décompte vérifié
Encodage du moteur 4.7.1, lu : `multiplayer_api.cpp:66-136` (booléen sur 1 octet, entier sur 2 à 9 selon la valeur) ; `marshalls.cpp:1377-1383` (flottant : 4 octets d'en-tête + 4, ou + 8 s'il n'est pas exactement représentable en 32 bits) ; `Vector2` : 4 + 8.
- **`rpc_send_inputs`** : 4 d'en-tête + `seq` (2, 3 ou 5) + 2×12 + 7 booléens = **38 à 40 octets** : exact. 60 par seconde -> 2,3-2,4 Ko/s de charge Godot, +6 octets EOSG par paquet.
- **Synchro** : 7 propriétés par joueur = 40 à 55 octets + 8 de cadre ; deux joueurs + 3 d'en-tête = **99 à 129 octets** : exact. `update_outbound_sync_time` (`multiplayer_synchronizer.cpp:124-135`) : au plus 30 Hz, 20 à 30 Hz à 60 i/s (période quantifiée par les images ; ≈ 24 Hz ESTIMÉ) -> 2,0-3,9 Ko/s de charge Godot. « ~5 Ko/s par sens sur le fil » (ENet, 40 octets d'enveloppe par paquet) : plausible, ESTIMÉ pour EOS (enveloppe d'Epic inconnue).
- `net_ack_seq` de P1 : toujours -1 (`rpc_send_inputs` rejette `player_id != 1`, `player.gd:1397`) : exact.
- Le moteur groupe les états en un paquet jusqu'à `sync_mtu` = 1 350 octets (`scene_replication_interface.cpp:803, 834`), au-dessus des 1 164 d'EOS : sans conséquence ici (≈ 130 octets), à garder en tête si le nombre de propriétés explose.

### 5.2 `sync_probe` : 5 propriétés sur 7, confirmé
`tools/sync_probe.gd:13-17, 23-28` : `net_position`, `net_rotation`, `net_flashlight_on`, `net_ack_seq`, `hp` ; il manque `net_dazzle` et `net_accroupi` (`player.gd:614-622`), alors que l'en-tête du fichier promet « mêmes propriétés ». **Correction** : l'audit chiffre la sous-estimation à ~18 %. C'est l'écart **par état de joueur** (9-13 octets sur ~47). Le banc n'instancie qu'**une** sonde (`test_transport.gd:205-211`), alors que le jeu envoie **deux** synchroniseurs dans un même paquet : le paquet SYNC du banc fait ≈ 42-53 octets contre 99-129 réels, soit **environ la moitié**. `tools/peer_spy.gd` ne compte que des paquets (`sent`, `:24, 59-65`), pas d'octets : confirmé.

### 5.3 Coût, invariants, correctif, preuve
Coût : 0. Invariants : toute modification de **forme** (quantifier les `Vector2`, un octet pour les boutons, retirer `hp` ou `net_ack_seq` de P1 de la synchro) change le fil : `Protocol.VERSION = 20`, donc une mineure et la coupure de la population (`test_corps_soi_fondu.gd:208` et `test_corps_soi_sombre.gd:178` figent aujourd'hui 19) ; la sonde, elle, ne touche pas au jeu. Correctif utile et minimal : ajouter les deux propriétés à la sonde **et** instancier deux sondes, plus une garde qui compare la liste de la sonde à celle de `player.gd` (lecture du texte, dans le style des suites existantes) ; ajouter un cumul d'octets (`buffer.size()`) à `PeerSpy._put_packet_script`. Preuve dans le cloud : `test_transport --transport enet --spy` à deux processus, octets par commande. **Statut : NOUVEAU.**

---

## 6. RES-04 — le témoin de protocole ne voit ni la synchro ni trois attributs

**Verdict : CONFIRMÉ. Sévérité : MINEUR.**

### 6.1 Le code
`tools/test_protocole.gd:100-112` : l'empreinte hache les signatures de RPC (`RPC_SOURCES`), `mapcodec=` et neuf constantes de `network_manager.gd` : `EOS_BUCKET_ID`, `EOS_CODE_ATTRIBUTE`, `EOS_QUEUE_ATTRIBUTE`, `EOS_QUEUE_RATING_ATTRIBUTE`, `EOS_QUEUE_COMMIT_ATTRIBUTE`, `EOS_MEMBER_NONCE_ATTRIBUTE`, `EOS_MEMBER_RATING_ATTRIBUTE`, `EOS_MEMBER_ACCEPT_ATTRIBUTE`, `EOS_SOCKET_ID`. Absents : **`EOS_PROTOCOL_ATTRIBUTE`** (`network_manager.gd:74`, « PROTO » : l'attribut même qui porte la version), `EOS_QUEUE_TIER_ATTRIBUTE` (`:103`), `EOS_MEMBER_TIER_ATTRIBUTE` (`:115`), tous trois utilisés (`:363, 453, 545, 550, 579, 606, 636, 702`). Rien non plus pour `rep_config` ni `replication_interval` (`player.gd:611-627`) : aucune suite ne les lit (`grep` : `player.gd` et `sync_probe.gd` seuls).

### 6.2 Pourquoi c'est un vrai trou
`decode_and_decompress_variants` boucle sur le nombre de propriétés **du récepteur** (`multiplayer_api.cpp:247-266`) : moins de variantes émises que de propriétés attendues -> `ERR_FAIL_COND_V_MSG(… "Size too small")` -> `on_sync_receive` abandonne le paquet **entier**, donc l'état des deux joueurs (`scene_replication_interface.cpp:889-893`) ; plus de variantes -> l'excédent est ignoré sans erreur ; ordre différent -> affectation positionnelle de types faux. Dans tous les cas : aucune erreur visible au joueur. **Aucun garde de VERSION ne l'attrape** tant que le fil « RPC » n'a pas bougé : `net_accroupi` n'a été couvert que parce que MB2 changeait aussi `rpc_send_inputs`.

### 6.3 Fréquence, coût, invariants, correctif, preuve
Fréquence : statique (une suite headless, aucun chemin chaud du jeu). Coût : 0 à l'exécution. Correctif : sortir la liste et l'intervalle en constantes lues par `Player._ready()` et par `_empreinte()` ; ajouter les trois attributs ; recopier `WIRE_WITNESS` (`protocol.gd:334`) **sans** monter `VERSION` (le fil n'a pas bougé), après décision humaine selon la règle du carnet. Prouver l'alarme comme la ROADMAP l'a fait pour `rpc_send_inputs` (ajouter une propriété bidon : rouge ; restaurer : vert) : `godot --headless --path . --script res://tools/test_protocole.gd`. **Statut : NOUVEAU** (le périmètre est écrit à ROADMAP:2205-2207, le synchroniseur n'y est ni inclus ni exclu). Remarque hors périmètre : le dernier paragraphe de `protocol.gd` dit encore la v19 « Non publiée » alors que la 0.8.0 est taguée (ROADMAP:2459 : « La 0.8.0 est publiée et vérifiée », 2026-10-01) ; commentaire périmé. Conséquence pour toute proposition « fil » de ce rapport : `VERSION = 20`, soit la mineure suivante (0.9.0), et la population coupée en deux jusqu'à la mise à jour.

---

## 7. RES-09 + ETA-09 + JOU-10 — l'historique de compensation, une entrée par image rendue

**Verdict : CONFIRMÉ pour le coût, RÉFUTÉ pour l'enjeu d'équité. Sévérité : ANECDOTIQUE.** (La partie « rejeu » d'ETA-09, `replay_system.gd`, n'est pas traitée ici.)

### 7.1 Le code et les appelants
```gdscript
# game_state.gd:2091-2092, dans GameState._process (par image rendue, hôte seulement, lobby compris)
if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
	_record_position_history()
# game_state.gd:4271-4274
_pos_history.append({"t": now, "p1": …, "p2": …, "a1": …, "a2": …})
while _pos_history.size() > 1 and now - _pos_history[0]["t"] > POS_HISTORY_WINDOW:   # 0,4 s
	_pos_history.remove_at(0)
```
Lectures : `_rewound_position` et `_rewound_posture` (`:4277-4305`), par balayage linéaire, **une fois par volée d'un client** (`_do_spawn_bullet`, `:4173-4175`), depuis la physique de l'hôte. `GameState` n'a pas de `_physics_process` (seul `_process`, `:2081`). Taille du tampon = 0,4 × cadence : 24 (60 i/s), 58 (144), 200 (500).

### 7.2 Coût
Un `Dictionary` de 5 clés alloué, rempli et libéré par image, plus un `remove_at(0)`. **L'audit estime 2 µs par image et ~0,05 % d'un cœur à 500 i/s ; c'est probablement bas** : `remove_at(0)` d'un tableau de Variant décale élément par élément avec affectation de `Variant` (comptage de références atomique sur chaque `Dictionary`), soit des dizaines de nanosecondes × 200 entrées à 500 i/s : **1-10 µs par image selon la cadence, ≤ 0,5 % d'un cœur au pire**, toujours sans pic (donc sans effet sur le 1 % bas). À mesurer par micro-banc si l'on y tient : aucun enjeu.

### 7.3 L'équité : réfutée
Les positions ne changent qu'au pas physique ; l'historique échantillonné par image est donc une **marche d'escalier** à haute cadence (marche = 4,33 px à 260 px/s) et une rampe linéaire à 60 i/s. L'écart de position rétroactive entre les deux est **≤ 1 pas (4,33 px, ≈ 17 ms de position cible)**, et la rampe, qui imite l'interpolation linéaire que voit le tireur, est la plus fidèle. C'est une dépendance à la cadence réelle mais minuscule, très en dessous de l'incertitude du repère de la compensation (RES-02 §3.6). Rien à corriger au nom de l'équité.

### 7.4 Correctif minimal et invariants
Garder la structure (`test_netcode.gd:103-150` alimente `_pos_history` à la main avec `{"t","p1","p2"}` : une refonte en tableaux parallèles le casserait) et ne changer que l'échantillonnage : une garde `Engine.get_physics_frames()` (ne pousser qu'une entrée par pas physique) à l'intérieur de `_record_position_history()`. Taille bornée à ≤ 25 entrées, indépendante de la cadence. Aucune signature de RPC ne bouge ; ne pas confondre avec la fenêtre de 0,4 s, qui est juste. **Statut : NOUVEAU** (la leçon « tampon en durée, pas en images », ROADMAP:300-314, est tenue ici).

### 7.5 Comment le prouver dans le cloud
Test headless à pas fixe (`--fixed-fps 500`, 3 s simulées, hôte monté) : `_pos_history.size()` = 200 avant, ≤ 25 après ; relancer `tools/test_netcode.tscn` (`_test_rewound_position`) et un banc d'équité.

---

## 8. RES-10 — la préparation d'une mise à jour fige la fenêtre

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : ANECDOTIQUE.**

### 8.1 Le code
`update_manager.gd:259-314` (`telecharger`) : après `await _http.request_completed`, sur le **fil principal** : `UpdateManifest.empreinte_fichier(_archive)` (`:295` -> `FileAccess.get_sha256`, `update_manifest.gd:353-354`), puis `_installeur.preparer_bundle(...)` (`:308`) -> `_decompresser` -> `OS.execute("/usr/bin/ditto", ["-x","-k",…], sortie, true)` (`update_installer.gd:186`), **bloquant** jusqu'à la fin du processus (le 4e argument est `read_stderr`). État affiché : « Téléchargement… ». Moteur : `http_request.cpp:172-190` : `while (!quit) { _update_connection(); OS::delay_usec(1); }` ; en mode bloquant `HTTPClientTCP::_get_http_data` boucle sur `get_partial_data` (`http_client_tcp.cpp:738-757`), qui ne bloque pas : la boucle consomme un cœur pendant toute la requête. Les archives font 130 960 497 et 185 128 994 octets (ROADMAP:2459).

### 8.2 Fréquence et coût
Un geste volontaire du joueur, sur un écran dédié, jamais en match. Le gel est réel mais **le chiffre « 2 à 4 s » du SHA-256 n'est pas fondé** : SHA-256 de 185 Mo ≈ 0,2 à 1,2 s selon que mbedTLS emploie ou non les instructions SHA d'ARM (non mesuré) ; la durée est dominée par l'extraction `ditto`, **plusieurs secondes** (ESTIMÉ). Un cœur à vide pendant le téléchargement : PROUVÉ par lecture des deux boucles (non mesuré), sans correctif possible sans changer de client HTTP. La vérification automatique à +3 s (`update_manager.gd:140-167`) lance deux petites requêtes de moins d'une seconde.

### 8.3 Correctif, invariants, preuve
Le plus petit geste : repasser à un libellé « Vérification et préparation… » et laisser une image se dessiner (`await get_tree().process_frame`) avant les deux appels bloquants ; ensuite, `WorkerThreadPool` pour le SHA-256 et `OS.create_process` + attente pour l'extraction. `test_mise_a_jour.gd` couvre l'installeur. **Statut : NOUVEAU.** Preuve dans le cloud : micro-banc headless qui chronomètre `empreinte_fichier` sur un fichier de 185 Mo et `_decompresser` (`unzip`) sur une archive d'essai, avec `Engine.get_process_frames()` relevé avant et après (inchangé : le gel tient à l'appel bloquant) ; non représentatif de l'Apple M3.

---

## 9. Ce que je corrige dans le rapport source

1. **RES-02** : l'expérience `--extra-tick` **a** un résultat consigné (ROADMAP:2585, +2 ms) ; « −33 ms » est une borne, l'ordre de grandeur en jeu est ≈ 23-29 ms à 60 i/s et décroît avec la cadence ; la cohérence « position/ack » ne tient qu'à un pas par image ; la voie `process_frame` est fragile (la pompe se branche après la connexion Connect) ; le sondage manuel est l'usage documenté du moteur ; l'ordre du tick par rapport au sondage reste à lever par `EOSGRuntime.process_priority` ; l'audit renvoie la compensation de tir à une validation (« son repère n'a jamais été validé ») sans dire dans quel sens elle bouge : mon décompte (ESTIMÉ, §3.6) dit que son biais actuel (≈ −56 ms à 60 i/s, au profit de la cible) se réduit d'environ 2 T.
2. **RES-01** : le second site d'appel (`game_state.gd:5818`, revanche) manquait ; arithmétique exacte `56 + pad4(L)`, L <= 1 108 ; aucune échéance côté client trouvée ; conséquence « forfait local de l'hôte » ; croisement avec CAR-07.
3. **RES-05** : le cas nominal est « l'hôte émet le RPC en tête », mais l'ordre de livraison n'est garanti ni en ENet ni en EOS ; et la décision ROADMAP:2575 repose sur l'hypothèse fausse.
4. **RES-07** : la sonde sous-estime le paquet SYNC d'environ la moitié (une sonde au lieu de deux), pas de 18 %.
5. **RES-09** : coût probablement bas d'un facteur 2 à 5 à 500 i/s (mais toujours négligeable) ; l'équité est hors de cause.
6. **RES-10** : le SHA-256 n'est pas de « 2 à 4 s ».

## 10. Ce que je n'ai pas pu vérifier
- **Le SDK Epic est fermé** : le délai réel entre l'arrivée d'un paquet et sa disponibilité à `EOS_P2P_ReceivePacket`, et le fait qu'`EOS_P2P_SendPacket` parte sans tick (la doc d'Epic dit « sent immediately » de mémoire, non relu : la page d'API a répondu 404). L'enveloppe réseau d'Epic (direct ou relayé) et l'ordre de livraison fiable / non fiable.
- **Toute valeur en millisecondes sur EOS** : exige des identifiants Epic et deux instances ; ε (temps de script d'une image) jamais mesuré.
- **Le SQL de classement** : l'effet d'un rapport unique sur le classement.
- **Le binaire macOS** : seules les chaînes ont été lues ; la valeur 1 170 est désassemblée sur le `.so` Linux x86_64, de la même source `2.3.0`.
- **Les gestionnaires de RPC un par un** : l'absence de dépendance « gestionnaire avant `_process` » est établie par lecture des consommateurs principaux, pas exhaustivement.
