# RES — Réseau et services en ligne

Audit d'optimisation du 2026-10-04, commit `52a29c1` (0.8.3 + SOLO S12). Lecture seule : Godot n'a pas été lancé, aucun fichier du dépôt n'a été touché.

**Sources utilisées.**
1. Le dépôt : `network_manager.gd`, `protocol.gd`, `network_input_provider.gd`, `matchmaking.gd`, `lobby_code.gd`, `ranked_identity.gd`, `recovery_code.gd`, `conditions_de_match.gd`, `update_*.gd`, `patch_loader.gd`, les 25 `@rpc` de `game_state.gd` / `player.gd` / `network_manager.gd` et leurs appelants, plus `match_record.gd`, `match_banner.gd`, `ui.gd`, `settings_manager.gd` là où ils touchent au réseau.
2. La ROADMAP (Phases 2, 3, 4, 8, 9, « Pièges connus », « Journal des tests à deux machines »).
3. **Le moteur Godot 4.7.1-stable, lu sur GitHub** (la version du projet) : `scene/main/scene_tree.cpp`, `main/main.cpp`, `modules/multiplayer/*`, `scene/main/multiplayer_api.cpp`, `modules/enet/enet_multiplayer_peer.cpp`, `scene/main/http_request.cpp`, `scene/gui/control.cpp`, `scene/gui/label.cpp`. Copies locales dans `audit/src/v471/` (hors dépôt).
4. **Le binaire de l'addon EOSG** (`addons/epic-online-services-godot/bin/linux/libeosg.linux.template_debug.dev.x86_64.so`) lu avec `nm`, `objdump -d` et `strings` — aucune exécution. Hypothèse : le binaire macOS est compilé depuis la même source (EOSG 2.3.0).

**Légende.** PROUVÉ = lu dans le code du dépôt, du moteur ou du binaire. ESTIMÉ = déduit par raisonnement ou ordre de grandeur, non mesuré. Aucun chiffre de temps n'a été mesuré dans ce rapport.

## Verdict

- Le réseau n'est **pas** un poste de coût CPU : aucun émetteur n'est piloté par le rendu, les débits sont de l'ordre de 5 Ko/s par sens, les allocations par paquet sont minuscules.
- **Deux constats MAJEURS, aucun n'est une question de CPU.**
  - RES-01 : un paquet EOS ne peut pas dépasser **1 170 octets** et l'addon ne fragmente pas ; `rpc_start_round` transporte le code de carte entier. Une carte dont le code dépasse ~1 100 caractères ne démarre jamais chez le client, sans erreur visible. Le tirage de carte du classé puise dans tout le catalogue de l'hôte, cartes joueur comprises.
  - RES-02 : sur EOS, **chaque paquet reçu attend une image de plus** (la pompe de l'addon tourne sur `process_frame`, après `multiplayer.poll()`), et l'état publié par l'hôte a une image de retard. Correctif de quelques lignes, à valider au banc `test_transport` déjà en place.
- Les autres constats sont MINEURS ou ANECDOTIQUES : archivage synchrone du journal à l'image de la mort, trou dans le témoin de protocole, `hp` envoyé par deux voies, sondages d'interface à chaque image, budget de tick EOS implicite.
- **Ne pas optimiser l'encodage du fil** : le moteur compresse déjà booléens et entiers ; toute modification de forme impose `Protocol.VERSION = 20` (la 19 est publiée depuis la 0.8.0) pour un gain de 1 à 3 Ko/s.

---

## 1. Carte des chemins chauds

Repères : question 1 (inventaire, bande passante) = 1.2 et 1.3 ; question 2 (fps déplafonnés) = 1.1 ; questions 3 à 6 = 1.4.

### 1.1 Les horloges du réseau (qui tourne quand)

Réglages de cadence (PROUVÉ) : `physics_ticks_per_second` non surchargé donc **60** (`project.godot`, section `[physics]` : seul le moteur 3D est réglé) ; vsync désactivé et aucun plafond par défaut (`settings_manager.gd:68`, `fps_cap := 0` ligne 77) ; en menu 120 images/s fenêtre au premier plan, 30 hors focus (`settings_manager.gd:250-251`) ; en arène le plafond est `fps_cap`, donc **illimité**. Au pire cas on compte **120 à 500+ images/s** contre **60 pas physiques/s**.

| Horloge | Ce qui tourne | Où | Quantité au pire cas |
|---|---|---|---|
| Par image rendue | `multiplayer.poll()` du moteur : lecture des paquets, dispatch RPC et instantanés, puis `on_network_process()` (envoi des synchronisations, filtré par le temps) | moteur, `scene_tree.cpp:707-713` | 1 par image |
| Par image rendue | pompe EOS : `EOSGPacketPeerMediator::_on_process_frame` appelle `EOS_P2P_GetNextReceivedPacketSize` puis `EOS_P2P_ReceivePacket` en boucle | binaire EOSG (symbole `0x1796ca`) | au moins 1 appel SDK par image, même à vide |
| Par image rendue | `EOSGRuntime._process` -> `IEOS.tick()` -> `EOS_Platform_Tick` (budget 2 ms ou 5 ms, voir RES-08) | `addons/epic-online-services-godot/runtime.gd:35` | 1 par image ; coût non mesuré |
| Par image rendue | `NetworkManager._process` : accumulateur de ping, `get_peers()` en ligne | `network_manager.gd:967-976` | 1 par image |
| Par image rendue | `Matchmaking._process` -> `tick()` : retour immédiat hors recherche | `matchmaking.gd:239-241, 406-408` | 1 appel trivial par image |
| Par image rendue | `MatchBanner._process` -> `refresh()` : **construit un Dictionary de 18 clés par image, même au repos** | `match_banner.gd:157-166` | 1 par image, pendant les duels aussi (RES-06) |
| Par image rendue | `ui._process` -> `_update_network_status()` et `_update_ping_label()` : `add_theme_color_override` à chaque image | `ui.gd:1456, 1635-1661, 1724-1738` | 1 à 2 par image (RES-06) |
| Par image rendue | `GameState._process` : `_conditions.echantillonner()` (2 ajouts à des `PackedFloat32Array`) | `game_state.gd:2083`, `conditions_de_match.gd:86-98` | 1 par image, négligeable |
| Par image rendue, hôte | `_record_position_history()` : un Dictionary de 5 clés par image + `remove_at(0)` | `game_state.gd:2091-2092, 4266-4274` | 120 à 500 par seconde (RES-09) |
| Par image rendue, hôte | publication de l'état répliqué : 6 affectations `net_*` par joueur | `player.gd:1262-1268` | 12 affectations par image |
| Temporel, ≤ 30 Hz | `MultiplayerSynchronizer` des deux joueurs (`replication_interval = 1/30`) | `player.gd:611-628` | un paquet de 99 à 129 octets par période (RES-07) |
| Pas physique, 60 Hz | client : `_send_inputs_to_host` -> `rpc_id(1, "rpc_send_inputs", ...)` | `player.gd:1727, 1429-1446` | 60 paquets/s de 38 à 40 octets |
| Pas physique, 60 Hz | client : interpolation de l'adversaire, historique de prédiction (un Dictionary par pas) | `player.gd:1728-1729, 1613-1656, 1834-1837` | 60 par seconde |
| Par paquet, hôte | `rpc_send_inputs` (garde-fous puis `update_input_state`) | `player.gd:1394-1417` | 60 par seconde |
| Par paquet, client | `_on_net_synchronized` (un Dictionary par instantané de l'adversaire) et `_ingest_prediction_correction` (`keys()` + `erase`) | `player.gd:1475-1491, 1497-1522` | 30 + 30 par seconde |
| Accumulateurs de delta | `rpc_ping` 1 s ; `rpc_sync_time` 5 s | `network_manager.gd:965-976`, `game_state.gd:2151-2155` | 1 paquet/s et 1 paquet/5 s |
| Par événement | tir, PV, bruits de corps, gadgets, fusées, démarrage et fin de manche, prêts | tableau 1.2 | quelques paquets/s au plus |
| Par événement, kill | `_archive_match_result` : journal complet relu et réécrit, rapport HTTP préparé | `game_state.gd:4460, 4733-4774` | une fois par match, synchrone (RES-03) |
| Démarrage | init SDK EOS (`initialize` et `create`, synchrones), identification Supabase (asynchrone), vérification de mise à jour à +3 s (installé seulement) | `network_manager.gd:793-842`, `ranked_identity.gd:130-147`, `update_manager.gd:140-167` | une fois |

**Réponse à la question 2 (fps déplafonnés).** Aucun émetteur réseau n'est déclenché depuis `_process`. Les entrées partent du pas physique (60 Hz), l'état par un intervalle temporel du moteur, le ping et la synchro du chrono par accumulation de delta. Le piège « 500 fps = 500 paquets/s » n'existe pas dans ce code. Vérifié côté moteur : `MultiplayerSynchronizer::update_outbound_sync_time` (`multiplayer_synchronizer.cpp:124-135`) ne laisse partir un paquet que si `p_usec >= last_sync_usec + sync_interval_usec`. La ROADMAP a de son côté compté 390 paquets de synchronisation, tous en `UNRELIABLE` (ROADMAP:9624).

Nuance (ESTIMÉ) : la période effective n'est pas exactement 33,3 ms. Le moteur fixe `last_sync_usec = p_usec` sans reporter le reste, donc la période est « la première image après 33,3 ms » : ~34 ms à 500 fps, mais alternance 33/50 ms à 60 fps, soit 20 à 30 Hz. C'est une des raisons du retard d'interpolation de 100 ms.

Les seuls sondages au rythme du rendu sont **de l'interface** (`MatchBanner`, `ui._update_network_status`) et l'historique de compensation de l'hôte, tous trois traités ci-dessous.

### 1.2 Inventaire des RPC (25) et de la synchronisation

Tous utilisent le **canal 0** (aucun `@rpc` ne précise de canal). En ENet cela donne deux flux indépendants : `reliable` sur le canal ENet 0, `unreliable` sur le canal ENet 1 (`enet_multiplayer_peer.cpp:340-357`). En EOS, le pair EOSG range les modes Godot dans `EOS.P2P.PacketReliability` et refuse `unreliable_ordered` (il le promeut en fiable : chaîne `EOSGMultiplayerPeer does not support unreliable ordered` dans le binaire) ; le jeu n'emploie pas ce mode.

Tailles : **au niveau Godot, en-tête RPC compris**, selon l'encodage du moteur 4.7.1 (PROUVÉ, `multiplayer_api.cpp:66-136`, `marshalls.cpp:1377-1383, 1539-1546`, `scene_rpc_interface.cpp:355-424`). En-tête RPC : 1 octet de méta + 1 de n° de nœud + 1 de n° de méthode + 1 de nombre d'arguments = **4** (3 sans argument ; le chemin du nœud est ajouté tant que le pair ne l'a pas confirmé). `bool` : **1**. `int` : 2 (|v| <= 127), 3 (<= 32 767) ou 5. `float` : 8 s'il est exactement représentable en 32 bits, sinon 12. `Vector2` : **12**. `String` : 8 + longueur arrondie au multiple de 4.

| RPC (fichier:ligne) | Mode, appel | Émetteur -> récepteur | Cadence | Charge utile |
|---|---|---|---|---|
| `rpc_send_inputs` (`player.gd:1394`) | any_peer, unreliable | client -> hôte | **60 Hz** (pas physique) | 38-40 o : `seq`, 2 Vector2, 7 bool |
| `rpc_ping` / `rpc_pong` (`network_manager.gd:992, 1000`) | any_peer, unreliable | les deux sens | 1 Hz chacun | 9 o |
| `rpc_hello` (`network_manager.gd:1026`) | any_peer, reliable | les deux sens | une fois par lien | ~28 o (JSON `{"protocol":19}`) |
| `rpc_start_round` (`game_state.gd:1842`) | authority, call_local, reliable | hôte -> les deux | début de manche, revanche | **L + 58 o** où L = longueur du code de carte (560-700 o pour les cartes livrées) |
| `rpc_map_refused` (1895) | any_peer, reliable | client -> hôte | rare | ~110 o |
| `rpc_end_round` (4422) | authority, call_local, reliable | hôte -> les deux | une fois par manche | 6 o |
| `rpc_sync_time` (4314) | authority, call_remote, reliable | hôte -> client | 5 s, et fin de décompte | 12-16 o |
| `rpc_spawn_bullet` (4128) | authority, call_local, reliable | hôte -> les deux | par tir (<= ~10/s) | 28-32 o |
| `rpc_update_hp` (`player.gd:2874`) | authority, call_local, reliable | hôte -> les deux | par dégât reçu | 16-20 o |
| `rpc_bruit_de_corps` (`player.gd:2258`) | authority, call_remote, reliable | hôte -> client | rechargement, clic à vide, frôlement (1 par pas de 45 px contre un mur : ~6/s) | 26-34 o |
| `rpc_spawn_fusee` (3223) / `rpc_stock_fusees` (3187) / `rpc_eteindre_fusee` (4068) | authority, call_local, reliable | hôte -> les deux | par fusée ; stock : un paquet toutes les 12 à 18 s (ROADMAP:19604) | 31-35 / 16-20 / 9 o |
| `rpc_spawn_gadget` (3611) / `rpc_etat_gadget` (3704) / `rpc_allumer_gadget` (3600) / `rpc_detruire_gadget` (3746, call_remote) | authority, reliable | hôte -> client(s) | par gadget posé, basculé, allumé, détruit | 54-70 / 39-51 / 30-38 / 30-38 o |
| `rpc_client_weapon` (5004), `rpc_countdown_weapon` (5439), `rpc_countdown_ready` (5729), `rpc_client_ready` (5799), `rpc_client_unready` (6546) | any_peer, reliable | client -> hôte | événements de salon | 3 à 6 o |
| `rpc_countdown_launch` (5743), `rpc_host_ready` (5762) | authority, call_remote, reliable | hôte -> client | événements de salon | 3 et 5 o |
| **Synchronisation** des deux joueurs (`player.gd:611-628`) | moteur : unreliable | hôte -> client | **<= 30 Hz** (20-30 réels à 60 fps) | 99-129 o par paquet |

Le contenu d'une synchronisation, par joueur (PROUVÉ, `scene_replication_interface.cpp:802-853` : 8 octets d'identifiant et de taille par synchronizer, 3 octets d'en-tête de paquet) : `net_position` 12 + `net_rotation` 8 ou 12 + `net_flashlight_on` 1 + `net_dazzle` 8 ou 12 + `net_ack_seq` 2 à 5 + `net_accroupi` 1 + `hp` 8 ou 12 = 40 à 55 octets, plus 8 octets de cadre. Toutes les propriétés sont en mode « toujours » : elles repartent à chaque période même inchangées.

### 1.3 Bande passante d'un duel (1v1, régime établi)

Le moteur n'ajoute plus d'en-tête de pair en ENet (`enet_multiplayer_peer.cpp:369-373` : `enet_packet_create(nullptr, p_buffer_size, ...)` direct), et il **vide l'hôte ENet à chaque `put_packet`** (lignes 390-412) : un paquet = un datagramme. Surcoût ENet ~12 octets + UDP/IPv4 28 octets = 40. Pour EOS la charge Godot est identique, plus 6 octets d'en-tête EOSG (PROUVÉ, `EOSGPacket::prepare`) ; l'enveloppe P2P d'Epic, elle, n'est pas déterminée.

| Sens | Flux | Paquets/s | Charge Godot | Sur le fil (ENet) |
|---|---|---|---|---|
| client -> hôte | commandes `rpc_send_inputs` | 60 | 38-40 o | **78-80 o, soit 4,7-4,8 Ko/s** |
| client -> hôte | ping + événements | ~2 | 9 o | ~0,1 Ko/s |
| hôte -> client | synchronisation | <= 30 | 99-129 o | **139-169 o, soit 4,2-5,1 Ko/s** |
| hôte -> client | tirs, PV, bruits, gadgets, fusées | 3-15 | 16-70 o | 0,2-0,9 Ko/s |
| hôte -> client | ping | ~1 | 9 o | ~0,05 Ko/s |

**Total : ~5 Ko/s montant client (~40 kbit/s, ~62 paquets/s) et ~5-6 Ko/s descendant (~45 kbit/s, ~32-45 paquets/s).** Une manche de 5 minutes pèse ~1,5 Mo par sens. Les deux `Vector2` (24 o sur 38) dominent les commandes.

Si l'on appliquait l'ancien encodage « Variant brut » (4 octets d'en-tête par valeur, booléens sur 8 octets), les commandes pèseraient ~92 octets : le moteur 4.7.1 fait déjà mieux. La quantification (positions en entiers, angle sur 2 octets, bits de bouton sur 1 octet) économiserait environ 20 octets par commande et 40 par synchronisation, soit 2 à 3 Ko/s au total.

### 1.4 Réponses synthétiques aux questions 3 à 6

**3. Encodage.** Pas de Dictionary, d'Array ni de String de Variant sur le chemin chaud : les RPC fréquents sont des types simples (`int`, `Vector2`, `bool`, `float`). Aucune quantification. **Aucune redondance** : une commande porte l'état courant des boutons (niveaux) et un numéro ; l'hôte rejoue la dernière reçue si une commande manque et jette tout `seq <= _last_input_seq` (`player.gd:1405`). Aucune compression ENet (`COMPRESS_NONE` par défaut, jamais réglée), aucune en EOS. Les `float` de `hp` et `net_dazzle` passent sur 12 octets dès qu'ils ne sont pas exactement représentables en 32 bits (`marshalls.cpp:1377-1383`).

**4. Réception.** Par RPC reçu, le moteur alloue deux petits `Vector` (`scene_rpc_interface.cpp:280-283`) ; côté script : `rpc_send_inputs` n'alloue rien. Côté client : un `Dictionary` de 5 clés par instantané de l'adversaire (30/s), `keys()` d'un Dictionary de ~5 à 15 entrées par correction (30/s), un `Dictionary` de 3 clés par pas physique pour l'historique de prédiction (60/s). Structures bornées : `_net_snapshots` <= 32 entrées (en pratique 4-6, `slice(i)` purge), `_predict_history` <= 120, `_pos_history` borné **en temps** à 0,4 s. Aucune de ces allocations n'est mesurable à l'échelle d'une image (ESTIMÉ : ~120 petites allocations par seconde, de l'ordre de 0,1 à 0,3 ms/s au total côté client).

**5. EOS.** Coût par image : `IEOS.tick()` (budget implicite, RES-08), la pompe de l'addon, `EOSGMultiplayerPeer::_poll` (une `List` par appel, un `PacketData` et un `EOSGPacket` par paquet reçu, ~60/s). Aucune interrogation périodique de l'état du lien : `eos_network_type` et `eos_nat_type` sont posés une fois (`network_manager.gd:774-776, 878-879`). Les files du SDK ne sont pas réglées (`HP2P.set_packet_queue_size` n'est jamais appelé, `HP2P.get_packet_queue_info` non plus). **Le coût réel de `EOS_Platform_Tick` n'est mesuré nulle part** (ROADMAP : aucune occurrence) : question ouverte.

**6. Services HTTP.**
- `RankedIdentity` : un `HTTPRequest` **sans threads** (`ranked_identity.gd:131-134`, `use_threads` vaut faux par défaut : `SafeFlag`), donc asynchrone mais avec la poignée de main TLS et l'analyse du corps sur le fil principal. Une requête à la fois (`_pending`), délai 20 s, reprises 3 x 4 s. Charges : ~3 Ko en envoi (jeton Epic de ~943 caractères + rapport et conditions), < 5 Ko en réponse (`TOP = 10` côté serveur, `supabase/functions/standing/index.ts:14`).
- `UpdateManager` : `HTTPRequest` **avec** threads et téléchargement direct vers fichier (`update_manager.gd:144`) ; vérification automatique à +3 s seulement dans un build installé, jamais en match ; signature RSA-4096 vérifiée sur le fil principal (~ms).
- Appariement : une passe de recherche EOS toutes les `SWEEP_INTERVAL = 2 s` **après la fin de la précédente** (~3 s à vide, 200 ms si elle trouve), soit environ une passe toutes les 5 s ; recul 2 -> 16 s après un échec (`matchmaking.gd:85, 122-123`). Raisonnable et déjà expliqué dans le code.
- Démarrage : rien de bloquant n'a été trouvé à la lecture, sauf l'initialisation **synchrone** du SDK (`EOS.Platform.PlatformInterface.initialize` et `create`, `hplatform.gd:128, 165`), non mesurée.

---

## 2. Constats

### RES-01 — Un paquet EOS ne dépasse pas 1 170 octets : le code de carte de `rpc_start_round` peut ne jamais arriver

**Titre.** Perte silencieuse du démarrage de manche sur les cartes dont le code de partage dépasse ~1 100 caractères (EOS seulement).

**Où.** `game_state.gd:1836, 1842-1843` (envoi du code), `game_state.gd:1919-1922` (`_host_map_code`), `map_codec.gd:101-105` (`to_share_code`), `game_state.gd:5583-5587` et `map_data.gd:217-222` (tirage de carte du classé). Limite dans le binaire EOSG (`EOSGMultiplayerPeer::_get_max_packet_size`).

**Constat.**
```gdscript
# game_state.gd:1836
rpc_start_round.rpc(w1_idx, w2_idx, _host_map_code(), _new_match_id())
# game_state.gd:1842
@rpc("authority", "call_local", "reliable")
func rpc_start_round(w1_idx: int, w2_idx: int, map_code: String = "", match_id: String = ""):
# game_state.gd:5583 — en classé, la carte est tirée dans TOUT le catalogue de l'hôte
func _poser_la_carte_appariee() -> void:
	if _matchmade_ranked:
		MapData.select_random_map()
```
Le code (`CANDELA-<base64(gzip(json))>`) voyage dans **un seul** paquet. Preuves :
- Désassemblage : `EOSGMultiplayerPeer::_get_max_packet_size()` est `mov $0x492,%eax`, soit **1 170** (`objdump`, adresse `0x15ce94`).
- Chaînes et code du binaire : `Condition "p_buffer_size > _get_max_packet_size()" is true. Returning: ERR_UNAVAILABLE` (dans `_put_packet`) et `Condition "packet.packet_size() > _get_max_packet_size()" is true. Returning: ERR_OUT_OF_MEMORY` (dans `_send_to`, juste avant `IEOS::_p2p_send_packet`) : le pair **refuse** un tampon plus grand, il ne fragmente pas (ENet, lui, fragmente). L'envoi est immédiat (aucune file à vider au `poll`).
- Moteur : `SceneRPCInterface::_send_rpc` appelle `multiplayer->send_command(P, ...)` **sans lire son résultat** (`scene_rpc_interface.cpp:441-444`, ligne 443) et `rpcp` exécute ensuite l'appel local (`call_local`, lignes 500-516). L'appel `rpc()` rend donc OK, l'hôte démarre sa manche, le client ne reçoit rien. Seule trace : une ligne dans la console de l'hôte.

Taille : paquet Godot = L + 58 octets environ (en-tête 4 + deux entiers 4 + `match_id` 40 + 8 pour la chaîne). EOSG y ajoute **6 octets d'en-tête** (`EOSGPacket::prepare` écrit 1 octet d'événement, 1 de canal et 4 de pair émetteur ; `get_payload` = tampon + 6) et la limite de 1 170 s'applique à la somme (second garde, dans `_send_to`) : charge Godot <= 1 164 octets, donc **L <= ~1 100 caractères**, un peu moins tant que le pair n'a pas confirmé le chemin du nœud (il est alors joint au paquet). Cartes livrées (calcul gzip + base64 sur les JSON d'`assets/maps/`) : **500 à 636 caractères** pour 24 à 32 de grille, 52 à 72 segments de mur. Simulation (murs aléatoires, donc pire que des cartes dessinées à la main) : 40x40 et 90 segments = 836 caractères ; **48x48 et 140 segments = 1 104** ; 64x64 et 220 segments = 1 552 ; 128x128 = 3 660. L'éditeur permet jusqu'à 128x128 (`map_codec.gd:27`). L'anti-bombe (8 Mo) borne la décompression, pas l'émission.

**Coût.** Pas de coût de cadence : une panne fonctionnelle. Un hôte EOS qui lance une carte trop dense (choisie, ou tirée au hasard en classé) joue seul pendant que le client reste sur son salon, sans message. ENet (LAN) fonctionne (il fragmente), et aucun banc EOS n'envoie un paquet de plus de 1 170 octets : les cartes livrées (<= 636 caractères) passent, donc aucune suite actuelle ne le voit. PROUVÉ pour la limite et l'absence d'erreur côté script ; ESTIMÉ pour la fréquence (dépend des cartes joueur).

**Proposition.**
1. *Sans changer le fil* (à faire d'abord). Ajouter à `NetworkManager` une fonction `taille_max_paquet()` (1 164 en EOS : 1 170 moins l'en-tête EOSG de 6 ; grand en ENet) pour respecter la règle « aucun `if transport` hors `network_manager.gd` ». `GameState._host_map_code()` compare `code.length() + 120` à cette limite (marge pour le chemin du nœud) : si trop gros, ne pas lancer, afficher une boîte claire (« cette carte est trop grosse pour le jeu en ligne Epic : N caractères, maximum ~1 050 par prudence ; jouez-la en LAN ou simplifiez-la ») et revenir à la carte par défaut. `MapData.select_random_map()` écarte les cartes trop grosses quand le transport est EOS. L'éditeur et la galerie affichent la taille du code et préviennent au-delà du seuil.
2. *Test de garde* : une suite headless qui calcule `MapCodec.to_share_code` de chaque carte livrée et échoue au-dessus de 1 000 caractères.
3. *Structurel, avec `Protocol.VERSION = 20`* : transfert découpé (un RPC fiable `rpc_carte_morceau(index, total, octets)` de ~900 octets), ou code allégé des champs inutiles au client (`name`, `author`, `created_utc`). À grouper avec la prochaine rupture de fil inévitable.

**Gain attendu.** Aucun gain de cadence ; supprime un échec silencieux. 

**Risque.** Garde : faible, aucun changement de fil. Découpage : rupture du protocole 19 publié (voir RES-07).

**Effort.** S (garde, filtre, test) ; M à L (découpage + VERSION 20).

**Sévérité.** MAJEUR.

**Statut ROADMAP.** NOUVEAU. La carte « par valeur » est documentée (ROADMAP:2022-2125, tirage ouvert en classé :2112-2124) ; aucune mention d'une limite de paquet EOS (aucune occurrence de `1170` ni de `max_packet` dans la ROADMAP ; les « fragment » qu'elle contient sont des fragments de shader).

**Comment le vérifier.** (a) Headless, sans EOS : la suite de garde ci-dessus. (b) À deux instances EOS : étendre `tools/test_transport.gd` pour envoyer un RPC fiable portant une chaîne de 2 000 caractères et constater qu'il n'arrive pas (la console de l'envoyeur affiche la condition `p_buffer_size > _get_max_packet_size()`), puis le refaire avec 1 000 caractères. (c) En jeu : héberger en EOS une carte 64x64 dense.

---

### RES-02 — Sur EOS, chaque paquet reçu attend une image de plus ; l'état publié par l'hôte a une image de retard

**Titre.** L'ordre d'une image réseau est `poll` -> pompe EOS -> `_process` : un paquet pompé à l'image N n'est livré qu'à l'image N+1, et la publication de `net_*` suit le `poll` qui la lit.

**Où.** Moteur : `scene/main/scene_tree.cpp:707-713` (4.7.1). Addon : `runtime.gd:35-36`. Jeu : `player.gd:1259-1268`, `network_manager.gd:967-976` (aucun sondage manuel), `player.gd:1262-1268` et `1395-1417` (ack).

**Constat.**
```cpp
// scene_tree.cpp (4.7.1), SceneTree::process
if (multiplayer_poll) { multiplayer->poll(); ... }   // 1. le moteur sonde d'abord
emit_signal(SNAME("process_frame"));                  // 2. puis émet process_frame
```
```gdscript
# runtime.gd:35 (addon)                    # player.gd:1259-1268 (jeu)
func _process(_delta: float):               func _process(delta):
	IEOS.tick()                                  if ... ONLINE_HOST:
                                                    net_position = global_position
                                                    net_ack_seq = _last_input_seq   # etc.
```
Dans le binaire EOSG : `EOSGPacketPeerMediator::_init` se branche sur le signal **`process_frame`** (chaîne `Main loop does not have the process_frame() signal`) ; son `_on_process_frame` appelle `IEOS::_p2p_receive_packet` en boucle et range les paquets dans des files par socket ; `EOSGMultiplayerPeer::_poll` ne parle pas au SDK, il tire dans ces files (`poll_next_packet`). Chaîne résultante, PROUVÉE par lecture :

- *Réception* : SDK -> pompe à `process_frame` de l'image N -> livrée au `poll()` de l'image **N+1**. Délai de lecture du SDK jusqu'au jeu : entre 1 et 2 périodes d'image (1,5 en moyenne). Avec un `poll` placé après la pompe : entre 0 et 1 (0,5 en moyenne).
- *Émission de l'état* : `MultiplayerSynchronizer` lit `net_*` pendant le `poll()` (`multiplayer_synchronizer.cpp:157-172`, `get_indexed`), qui précède tous les `_process` ; il envoie donc ce que `_process` a écrit à l'image **précédente**.
- *Atomicité de la paire (position, ack)* : l'hôte exécute la physique, puis `poll()` (qui peut recevoir une commande et avancer `_last_input_seq`), puis `_process` publie `net_ack_seq = _last_input_seq` à côté d'une `net_position` calculée **avant** cette commande. Le commentaire de `player.gd:377` dit « dernier input client **appliqué** », le code publie le dernier **reçu**. L'écart vaut au plus un pas de déplacement (4,3 px à 260 px/s), du même ordre que `PREDICT_DEADZONE = 4.0`, qui l'absorbe aujourd'hui.

Cohérent avec ce que la ROADMAP a mesuré sans l'expliquer : « le plancher de RTT EOS suit la cadence d'image, pas le SDK » (ROADMAP:139, 17241 ; `RTT_MIN` 46 ms à 60 fps contre 13,3 ms déplafonné). L'expérience `--extra-tick` (`tools/eos_extra_ticker.gd`, un `IEOS.tick()` par pas physique) n'a **aucun résultat consigné** ; elle n'aurait pas dû aider, puisque la pompe est liée à `process_frame`, pas au tick.

**Coût.** Latence, pas CPU : de l'ordre d'**une période d'image par sens** sur le chemin de réception, plus une image sur l'état publié. Une période vaut 16,7 ms à 60 fps (le « 1 % bas » visé), 6,9 ms à 144, 2 ms à 500. PROUVÉ pour l'ordre des étapes ; ESTIMÉ pour l'ampleur (non mesurée).

**Proposition.** Sondage multijoueur manuel, **en fin de phase `_process`**.
```gdscript
# network_manager.gd — avant le `return` de --no-eos dans _ready()
process_mode = Node.PROCESS_MODE_ALWAYS     # le sondage du moteur ignore la pause
process_priority = 100                      # après les _process des joueurs (0)
get_tree().multiplayer_poll = false

func _process(delta: float) -> void:
	multiplayer.poll()                      # après la pompe EOS et après la publication de net_*
	... (suite inchangée)
```
Effets : (1) la pompe a déjà rempli les files, le `poll` les consomme dans la même image au lieu de la suivante : -1 période par sens pour tout ce que traite un gestionnaire (ping/pong, commandes d'entrée, `rpc_update_hp`, horodatage des instantanés de l'adversaire) ; (2) `net_*` est publié après avoir été écrit, non avant (état moins périmé d'une image) ; (3) la position et l'ack sont assignés dans `_process` avant le `poll` qui reçoit la commande suivante : la paire redevient cohérente sans toucher `player.gd`. En ENet il n'y a pas d'effet (1) à gagner : la lecture du socket se fait dans `poll()` lui-même, et déplacer le sondage ne le fait glisser que de la durée de la passe `_process` ; la RTT d'un banc ENet ne doit donc pas bouger, ce qui en fait un témoin. Variante de repli sans risque : garder le sondage du moteur et ajouter ce second appel en fin de `_process` (la deuxième passe est filtrée par le temps côté synchronizer). Elle n'apporte que l'effet (1) : c'est encore le premier sondage, celui du moteur, qui reçoit la commande avant que `_process` n'écrive la paire et qui envoie l'état périmé.

**Gain attendu.** ~-1 période d'image par sens : **-2 périodes de RTT**, environ -33 ms à 60 fps, -14 ms à 144, -4 ms à 500 (ESTIMÉ). Le raisonnement retombe sur le relevé de la ROADMAP : l'écart entre RTT_MIN à 60 fps plafonnés (46 ms) et déplafonné (13,3 ms) vaut 32,7 ms, soit deux périodes de 16,7 ms (ROADMAP:17240-17243). Prédiction falsifiable : `RTT_MIN` du banc à `--max-fps 60` passe de ~46 ms à environ 13-20 ms, et la même mesure en ENet ne bouge pas.

**Risque.** Gameplay : aucune règle ne change, mais le ressenti se déplace. Les gestionnaires RPC s'exécutent désormais après les `_process` du cycle : ce qu'ils posent est lu au cycle suivant, et l'ordre des paquets est intact. En revanche l'adversaire interpolé s'affiche environ une image plus tôt, puisque ses instantanés sont horodatés à l'instant du sondage (`player.gd:1482`), qui devient celui de la pompe au lieu de l'image suivante ; la compensation de latence suit, car elle lit la RTT mesurée qui baisse du même ordre, mais son repère n'a jamais été validé (question ouverte 5) : à contrôler à deux, pas seulement au chronomètre. Équité : symétrique (l'hôte et le client gagnent chacun une image de réception ; l'avantage de l'hôte à 0 ms ne change pas). Réseau : si `NetworkManager._process` cessait de tourner, plus aucun paquet ne serait lu — d'où le `PROCESS_MODE_ALWAYS`, un test sur `get_tree().multiplayer_poll` et le repli par double sondage. Bancs : `test_online_match` et `test_transport` à rejouer à deux instances.

**Effort.** S pour le code ; M pour la validation à deux machines.

**Sévérité.** MAJEUR (latence de chaque match EOS, surtout aux cadences basses visées par la cible « 1 % bas >= 60 »).

**Statut ROADMAP.** CONNU-OUVERT pour la dépendance du RTT à la cadence (ROADMAP:139, 17241-17245) ; NOUVEAU pour la cause (ordre `poll` / pompe) et pour la correction.

**Comment le vérifier.** *Dans le cloud, sans Epic :* (a) un test headless avec un pair factice (`MultiplayerPeerExtension`) qui pompe sur `process_frame` et livre dans `_poll()` : il consigne `Engine.get_process_frames()` à l'envoi, dans le gestionnaire de réception et dans le `_process` d'un joueur, et montre le saut d'une image avec le sondage du moteur et sa disparition avec le sondage manuel ; il garde aussi `get_tree().multiplayer_poll == false` et `NetworkManager.process_mode == ALWAYS`. (b) Témoin et non-régression : `test_transport` en ENet local, deux instances, avant puis après (`godot --headless --path . res://tools/test_transport.tscn -- --host --transport enet --max-fps 60`, puis `-- --join 127.0.0.1 --transport enet --max-fps 60` ; `--no-eos` évite d'initialiser EOS, `network_manager.gd:198`) : la RTT ne doit pas bouger et le trafic doit rester intact. La fraîcheur de l'état publié (effets 2 et 3) n'apparaît pas dans une RTT : elle demande une sonde propre (un numéro d'image écrit dans une propriété synchronisée, relu à l'arrivée). *Hors cloud :* la mesure sur EOS (`RTT_MIN_MS` et `RTT_AVG_MS` de `test_transport --eos-ephemeral --max-fps 60`, `tools/test_transport.gd:182-183`, protocole `docs/PROTOCOLE_TEST_EOS.md`) exige des identifiants Epic et deux instances : à faire une fois par un humain ; en attendant, la preuve est l'ordre des appels, lu dans le moteur et le binaire. Rejouer `test_online_match.tscn`.

---

### RES-03 — L'image de la mort relit et réécrit tout le journal des matchs, et prépare le rapport HTTP, de façon synchrone

**Titre.** Archivage du match sur le fil principal, à l'image décisive.

**Où.** `game_state.gd:4444-4460` (appel), `4515` (première attente), `4733-4774` (`_archive_match_result`), `match_record.gd:247-285` (`append_to_history`, `_write_history`, `load_history`), `ranked_identity.gd:274-285, 328-341, 345-350, 447-464`.

**Constat.**
```gdscript
# game_state.gd:4446-4460 (aucun await avant la ligne 4515)
if match_over:
	...
	_archive_match_result(winner_id)
...
await RenderingServer.frame_post_draw          # 4515
# match_record.gd:247-251, 263
var history := load_history(path)              # lit et analyse TOUT le JSON
history.append(record)
...
file.store_string(JSON.stringify(history, "\t"))   # réécrit TOUT, indenté
```
La chaîne est synchrone : `take_damage` -> `rpc_update_hp` (call_local) -> `die()` -> `call_group("game_state", "player_died")` (`player.gd:3077`) -> `rpc_end_round.rpc()` -> `_do_end_round` -> `_archive_match_result`. Elle comprend aussi `_conditions.resume()` (copie et **tri** de toutes les durées d'image de la manche, jusqu'à ~150 000 flottants pour 5 minutes à 500 fps), la construction du bloc `machine()`, puis, en ligne, `RankedIdentity.report_match` : jeton Epic, `JSON.stringify`, ouverture d'une connexion TLS non threadée. Quand la réponse arrive, `_settle_front()` appelle `MatchRecord.mark_reported`, qui **recharge et réécrit encore tout le journal** (en pleine killcam).

**Coût.** Une fois par match, aux deux pairs. Taille du journal : un enregistrement réaliste fait ~2 000 octets indentés ; plafonné à `HISTORY_MAX = 200`, le fichier atteint ~**390 Kio** (calcul). Analyse + `stringify` indenté de cet ordre : de l'ordre de la dizaine de millisecondes, ESTIMÉ, non mesuré (le chiffre croît avec l'ancienneté du joueur jusqu'au plafond). Atténué par le gel de 150 ms qui suit (`KILL_FREEZE_DURATION`), donc probablement peu visible, mais c'est exactement la catégorie « écriture de fichier et JSON volumineux à un moment décisif ».

**Proposition.** Garder l'ordre « journal d'abord, rapport ensuite » (c'est l'invariant de rejeu) mais déplacer les deux ensemble **après** le gel du kill : exécuter `_archive_match_result` après `await get_tree().create_timer(KILL_FREEZE_DURATION, true, false, true).timeout`, ou dans un `WorkerThreadPool.add_task` pour la partie fichier. Le chemin de forfait et de sortie du jeu (`_archive_forfeit`, appelé juste avant de quitter) doit rester synchrone. Variantes complémentaires : ne plus indenter (`JSON.stringify(history)`) ; ou passer à un fichier JSONL en ajout (un match = une ligne, plus de relecture).

**Gain attendu.** Retire ~10-40 ms ESTIMÉS (journal à 200 entrées) de l'image décisive ; rien sur la cadence moyenne.

**Risque.** Faible : une fenêtre de quelques centaines de ms pendant laquelle un arrêt brutal perdrait l'entrée (le rejeu du journal ne la retrouverait pas) ; le chemin de fermeture normal doit vider l'écriture en attente. Équité et bancs : aucun.

**Effort.** S (différer) ; M (fil séparé ou JSONL).

**Sévérité.** MINEUR (masqué en partie par le gel du kill).

**Statut ROADMAP.** NOUVEAU (PE2.4 traite du vidage du journal de log, pas du journal de matchs ; aucune mesure de `append_to_history`).

**Comment le vérifier.** Micro-banc headless : fabriquer 200 enregistrements du schéma 6 dans un fichier temporaire et chronométrer `MatchRecord.append_to_history` et `mark_reported` avec `Time.get_ticks_usec()`. En jeu : chronométrer `_archive_match_result` entre deux `get_ticks_usec` (F6 écrit déjà un diagnostic). `tools/banc_pics.tscn` (recherche de pics) peut montrer l'image de la mort.

---

### RES-04 — Le témoin de protocole ne voit ni la configuration du `MultiplayerSynchronizer`, ni trois attributs de salon

**Titre.** La plus grosse part du trafic (la synchronisation à 30 Hz) change de forme sans faire rougir `test_protocole`.

**Où.** `tools/test_protocole.gd:100-112` (`_empreinte`), `player.gd:611-627` (propriétés répliquées, intervalle), `protocol.gd:334` (`WIRE_WITNESS`).

**Constat.**
```gdscript
# tools/test_protocole.gd:100-112 — ce que l'empreinte couvre
for sig in _signatures_rpc(chemin): morceaux.append(sig)
morceaux.append("mapcodec=%d" % MapCodec.VERSION)
for cle in ["EOS_BUCKET_ID", "EOS_CODE_ATTRIBUTE", "EOS_QUEUE_ATTRIBUTE",
		"EOS_QUEUE_RATING_ATTRIBUTE", "EOS_QUEUE_COMMIT_ATTRIBUTE",
		"EOS_MEMBER_NONCE_ATTRIBUTE", "EOS_MEMBER_RATING_ATTRIBUTE",
		"EOS_MEMBER_ACCEPT_ATTRIBUTE", "EOS_SOCKET_ID"]: ...
# player.gd:614-626 — jamais lu par l'empreinte
rep_config.add_property(NodePath(".:net_position")) ... (".:hp")
sync.replication_interval = 1.0 / 30.0
```
Le périmètre « signatures de RPC, codec de carte, noms d'attributs de salon » est écrit noir sur blanc (ROADMAP:2205-2207), mais le principe annoncé est « tout ce qui est visible sur le fil » (ROADMAP:2182). La liste, l'ordre et l'intervalle des propriétés répliquées voyagent pourtant dans chaque paquet SYNC, et deux jeux dont la liste diffère décodent n'importe quoi ou jettent le paquet (`on_sync_receive`, `scene_replication_interface.cpp:855-897`) : un seul synchronizer mal décodé abandonne le paquet entier (`ERR_FAIL_COND_V`, lignes 891-893), donc l'état des deux joueurs gèle, avec pour seule trace une erreur de console que le joueur ne voit pas. Les ajouts `net_dazzle` et `net_accroupi` n'ont été couverts que parce que MB2 modifiait aussi `rpc_send_inputs`. Même trou pour `EOS_PROTOCOL_ATTRIBUTE`, `EOS_QUEUE_TIER_ATTRIBUTE` et `EOS_MEMBER_TIER_ATTRIBUTE`, absents de la liste. Aucune suite ne lit `rep_config` (`grep` : seuls `player.gd` et `tools/sync_probe.gd`).

**Coût.** Aucun à l'exécution : un trou dans le filet de sécurité qui compte le plus ici (« le pire défaut du netcode est celui qui ne lève rien », `protocol.gd:7-8`). Il devient aigu dès qu'on optimise la synchronisation (RES-05, RES-07).

**Proposition.** Sortir la liste en constante partagée (`const REPLIQUE := [".:net_position", ...]` et `INTERVALLE_SYNC`) lue à la fois par `Player._ready()` et par `_empreinte()`, ajouter les trois attributs manquants, puis recopier `WIRE_WITNESS` (sans changer `VERSION` : le fil n'a pas bougé). Prouver l'alarme comme la ROADMAP l'a fait pour `rpc_send_inputs` (ROADMAP:2215-2218) : ajouter une propriété bidon, constater le rouge, restaurer.

**Gain attendu.** Aucun gain de cadence ; ferme le trou avant qu'une optimisation du fil ne s'y glisse.

**Risque.** Nul pour le jeu ; la recopie du témoin se décide humainement (règle du carnet).

**Effort.** S.

**Sévérité.** MINEUR.

**Statut ROADMAP.** NOUVEAU (le périmètre de l'empreinte est décidé, ROADMAP:2205-2207 ; le synchronizer n'y est ni inclus ni exclu explicitement).

**Comment le vérifier.** `godot --headless --path . --script res://tools/test_protocole.gd` : vert avant, rouge après ajout d'une propriété, vert après restauration.

---

### RES-05 — `hp` voyage par deux voies ; selon l'ordre d'arrivée, le client saute le retour de dégâts

**Titre.** `hp` est répliqué à 30 Hz **et** annoncé par `rpc_update_hp` ; le commentaire qui justifie la comptabilité du client est périmé.

**Où.** `player.gd:620-622` (réplication), `2874-2907` (`rpc_update_hp`), `game_state.gd:3540-3542` (`noter_pv_perdus`).

**Constat.**
```gdscript
# player.gd:622 — le client reçoit hp de la synchronisation, aussi pour son propre joueur
rep_config.add_property(NodePath(".:hp"))
# player.gd:2879-2900 — le RPC compare à hp, qui a pu être réécrit par la synchro
if new_hp < hp:
	_rumble(...); gs.camera_hit_kick(player_id); AudioManager.play_breath_hit(...)
gs_tel.noter_pv_perdus(player_id, source_id, cause, maxf(hp - new_hp, 0.0), ...)
hp = new_hp
```
Le commentaire de `player.gd:2885-2895` affirme : « le client ne touche `hp` qu'ici, au départ de manche et au retour au menu ». C'est faux : le `MultiplayerSynchronizer` écrit `hp` chez le client à chaque période. Cas nominal : le RPC fiable part avant la synchronisation suivante et arrive le premier, tout va bien. Quand le datagramme fiable est retardé (perte, retransmission, relais), la synchronisation, non fiable, arrive d'abord avec le nouveau `hp` : le RPC trouve `new_hp < hp` faux, saute la vibration, le recul de caméra et le souffle, et la télémétrie compte une perte de zéro (`maxf(hp - new_hp, 0.0)`). La mort, elle, reste correcte (`hp = new_hp` puis `if hp <= 0 and not dead`).

**Coût.** Aucun en cadence. Effet : retour de dégâts parfois muet côté client et télémétrie des gadgets sous-comptée. PROUVÉ par lecture ; fréquence NON MESURÉE (elle croît avec la perte et la gigue du lien ; le lien relayé n'a jamais été exercé, ROADMAP:228).

**Proposition.** Ne pas toucher au fil (VERSION 20 sinon). Tenir côté script `_hp_annonce`, la dernière valeur confirmée par RPC (remise à 100 aux trois endroits où `game_state.gd` pose `hp = 100.0`, lignes 1157-1182, 1976-1977, 6414-6419) et calculer le retour et la perte contre elle, pas contre `hp`. Corriger le commentaire. Option plus tard, avec une rupture de fil : retirer `.:hp` de la synchronisation (économise 8 à 12 octets par joueur et par paquet).

**Gain attendu.** Fiabilité du retour de dégâts et de la télémétrie ; 0 en cadence.

**Risque.** Faible ; sensible aux bancs qui appellent `rpc_update_hp` directement.

**Effort.** S.

**Sévérité.** MINEUR (hors performance : signalé).

**Statut ROADMAP.** NOUVEAU.

**Comment le vérifier.** Test headless : poser `p.hp = 60.0` puis appeler `p.rpc_update_hp(60.0, 0, 0)` et vérifier que le retour de dégâts et `noter_pv_perdus` reçoivent bien 40.

---

### RES-06 — L'interface sonde l'état réseau et l'appariement à chaque image, y compris pendant un duel

**Titre.** `MatchBanner.refresh()` construit un Dictionary de 18 clés par image ; `ui._process` repose deux couleurs de police par image.

**Où.** `match_banner.gd:129-166` ; `ui.gd:1451-1456, 1635-1661, 1724-1738` ; `matchmaking.gd:357-377`.

**Constat.**
```gdscript
# match_banner.gd:157-159 — process_mode ALWAYS, jamais set_process(false)
func _process(_delta: float) -> void:
	refresh()
# match_banner.gd:160-163 : refresh() appelle _snapshot() (143-148 : _usable() + mm.call("search_snapshot")) AVANT le test d'inactivité
# ui.gd:1652, 1736-1737, chaque image
network_status_label.add_theme_color_override("font_color", tint)
ping_label.text = "● %d ms" % rtt
ping_label.add_theme_color_override("font_color", tint)
```
Le commentaire de `match_banner.gd:154-156` justifie la lecture par image par la présence d'un chrono ; au repos il n'y a pas de chrono, et le bandeau est caché pendant tous les duels. `search_snapshot()` fabrique 18 entrées et appelle une douzaine de fonctions (`range_label()` formate une chaîne en classé). `_usable()` (`match_banner.gd:129-141`) relit en outre le nœud par son chemin absolu et teste quatre `has_method` à chaque appel, donc à chaque image : son commentaire choisit de ne pas mettre l'absence en cache, ce qui devient inutile si le bandeau ne tourne qu'en cours de recherche. Dans le moteur 4.7.1, `add_theme_color_override` **ne vérifie pas que la valeur a changé** : il écrit et déclenche `NOTIFICATION_THEME_CHANGED` (`control.cpp:4030-4034, 3578-3582`), qui invalide le cache de thème, relance `queue_redraw()`, `update_minimum_size()` et `_size_changed()` (`control.cpp:4628-4637`), et marque la police du Label « sale » (`label.cpp:912-917`). `Label.text` est protégé (`label.cpp:1131-1134`), pas la couleur. `_update_network_status()` le fait **même hors ligne**.

**Coût.** À chaque image rendue : snapshot 5 à 10 µs, deux surcharges de thème 8 à 20 µs chacune. Total ESTIMÉ 10 à 50 µs par image, soit 0,5 à 2,5 % d'un cœur à 500 fps, 0,1 à 0,7 % à 144 fps. Non mesuré. Recoupe probablement l'audit de l'interface.

**Proposition.** `MatchBanner` : `set_process(false)` au repos, réveillé par les signaux `state_changed` / `range_changed` du `Matchmaker` (le chrono de la recherche garde un tic à l'image tant que l'état n'est pas IDLE). `ui._update_network_status` : mémoriser le dernier `tint` et le dernier ping affiché, n'écrire qu'au changement (un test de 2 lignes).

**Gain attendu.** ~10-50 µs par image de moins sur le fil principal en duel.

**Risque.** Faible : un bandeau qui ne se réveillerait pas serait visible tout de suite en recherche ; tests existants `test_screen_matchmaking`, `test_matchmaking`.

**Effort.** S.

**Sévérité.** MINEUR.

**Statut ROADMAP.** NOUVEAU (PE3 cite « l'allocation dans `_process` » en général, ROADMAP:22420).

**Comment le vérifier.** *Dans le cloud :* sur le modèle de `tools/test_match_banner.gd` (sa doublure `FauxCoeur`, l.19, porte déjà les quatre prises que `REQUIRED` exige, `match_banner.gd:36`), compter les appels à `search_snapshot()` sur 600 images (`await process_frame`) : 600 aujourd'hui, 0 au repos après correction (la doublure devra alors émettre les signaux qui réveillent le bandeau). Pour le coût des surcharges de thème : un micro-banc headless, 10 000 `add_theme_color_override` à valeur constante avec et sans garde, chronométrés par `Time.get_ticks_usec()`. `tools/cadence_cloud/` ne convient pas ici : sous llvmpipe une image dure 300 à 600 ms (`prise.sh:10`), un écart de quelques dizaines de microsecondes y disparaît dans le bruit. *Sur le Mac :* profileur de scripts sur `ui._update_network_status`.

---

### RES-07 — Charge utile et bande passante : état des lieux, et pourquoi ne pas y toucher maintenant

**Titre.** Les RPC fréquents ne sont pas compactés, et c'est acceptable ; tout changement de forme coûte `VERSION = 20`.

**Où.** `player.gd:1394-1395, 1429-1446, 611-628` ; `protocol.gd:315` ; `tools/sync_probe.gd:14-29`.

**Constat.** Voir 1.2 et 1.3. ~5 Ko/s par sens, 62 + ~35 paquets/s. Le moteur compresse déjà bool et int ; la marge restante (quantification des deux `Vector2`, un octet pour les sept boutons, propriétés lentes en changement) vaut 2 à 3 Ko/s. Deux faits sans risque à noter : (a) `net_ack_seq` de P1 voyage inutilement (toujours -1) ; (b) `hp` et `net_dazzle` passent sur 12 octets au lieu de 8 dès qu'ils ne sont pas exacts en 32 bits.

Piège de mesure : `tools/sync_probe.gd` prétend reproduire « la forme exacte du MultiplayerSynchronizer de player.gd — mêmes propriétés » mais n'en réplique que 5 sur 7 (il manque `net_dazzle` et `net_accroupi`, ajoutés en MB2). Le banc `test_transport` sous-estime donc la taille des paquets SYNC d'environ 18 %. `tools/peer_spy.gd` compte les paquets par commande mais pas les octets.

**Coût.** Négligeable : 40 kbit/s par sens ne sature aucune liaison ; la fiabilité du lien relayé n'a jamais été exercée (ROADMAP:228).

**Proposition.** Ne rien changer au fil tant qu'aucune rupture n'est déjà nécessaire (RES-01 structurel, RES-05). Si `VERSION = 20` est un jour payé : regrouper commandes (angle 2 octets, boutons 1 octet), retirer `hp` et `net_ack_seq` de P1 de la synchronisation, passer les propriétés lentes en « sur changement » après avoir vérifié le comportement du moteur en non fiable. En attendant : aligner `sync_probe.gd` sur la liste réelle (via la constante de RES-04) et ajouter les octets au mouchard.

**Gain attendu.** -2 à -3 Ko/s par sens au mieux ; aucun gain de cadence.

**Risque.** Rupture du protocole 19 publié depuis la 0.8.0 (ROADMAP:2459, `protocol.gd:297-305`) : la population se coupe en deux jusqu'à la mise à jour des deux côtés.

**Effort.** L (avec VERSION 20) ; S pour aligner le banc.

**Sévérité.** MINEUR (information, décision de ne pas faire).

**Statut ROADMAP.** NOUVEAU : aucune mesure ni estimation de bande passante n'existe dans la ROADMAP ; le mode de transfert du synchronizer est clos (ROADMAP:9624).

**Comment le vérifier.** *Dans le cloud :* ajouter un cumul d'octets (`buffer.size()`) au mouchard `tools/peer_spy.gd`, qui ne compte aujourd'hui que des paquets par commande et par mode (`sent`, l.24, 59-65), puis lancer `test_transport` en ENet local avec `--spy`, deux instances (`godot --headless --path . res://tools/test_transport.tscn -- --host --transport enet --spy`, puis `-- --join 127.0.0.1 --transport enet --spy`) : chaque instance branche son mouchard (`_install_spy`, `tools/test_transport.gd:85, 112`) et relève ses propres paquets sortants, par commande (SYNC = 6, REMOTE_CALL = 0) et par mode, ce qui couvre les deux sens. *À l'éditeur :* le profileur réseau du débogueur, présent en build de débogage seulement (moteur 4.7.1, hors dépôt : `_profile_bandwidth` `scene_multiplayer.cpp:40, 93, 255` ; `rpc_in` / `rpc_out` `scene_rpc_interface.cpp:286, 431` ; `sync_in` / `sync_out` `scene_replication_interface.cpp:897, 846`). Seule l'enveloppe EOS (6 octets d'en-tête EOSG, puis le lien direct ou relayé) échappe au cloud.

---

### RES-08 — Le budget de tick EOS est implicite : 2 ms ou 5 ms selon le plafond d'images au lancement

**Titre.** `tick_budget_in_milliseconds` n'est jamais réglé ; il se déduit de `Engine.max_fps` au moment de l'initialisation.

**Où.** `addons/epic-online-services-godot/heos/hplatform.gd:45-46, 107-112` ; `network_manager.gd:818` ; `settings_manager.gd:250-251, 753-759`.

**Constat.**
```gdscript
# hplatform.gd:107-112 — le jeu ne règle jamais HPlatform.tick_budget_in_milliseconds
var max_fps = max(Engine.get_max_fps()*1.0, 60.0)
var budget_ms = floori((0.3 * 1000) / max_fps)
budget_ms = max(budget_ms, 2) # at least 2ms
```
Au lancement (menu, fenêtre au premier plan), `Engine.max_fps` vaut `PLAFOND_MENU = 120` -> budget **2 ms**. Si le joueur a enregistré un plafond de 60 images/s (ou lance la fenêtre hors focus, 30), le calcul tombe à `max(.., 60)` -> budget **5 ms**, pour toute la session (la plateforme n'est créée qu'une fois). Le budget borne la durée d'un `EOS_Platform_Tick` ; sa valeur réelle d'usage n'est mesurée nulle part.

**Coût.** Au pire cas, un tick peut prendre 2 ou 5 ms d'une image de 16,7 ms (à 60 fps, 5 ms = 30 %). Le plafond est PROUVÉ par lecture ; le coût réel d'un tick n'a jamais été mesuré (question ouverte 2).

**Proposition.** Poser explicitement `HPlatform.tick_budget_in_milliseconds = 2` avant `setup_eos_async` (une ligne dans `NetworkManager._init_eos_async`), pour qu'il ne dépende ni du plafond enregistré ni du focus.

**Gain attendu.** Pire cas d'un tick EOS borné et reproductible ; rien en moyenne.

**Risque.** Un budget trop serré étale le travail du SDK sur plusieurs ticks (callbacks légèrement retardés) ; 2 ms est déjà la valeur du lancement habituel.

**Effort.** S.

**Sévérité.** ANECDOTIQUE.

**Statut ROADMAP.** NOUVEAU.

**Comment le vérifier.** Profileur de scripts : temps propre de `EOSGRuntime._process` en menu puis en duel EOS ; ou `Time.get_ticks_usec()` autour d'un `IEOS.tick()` ajouté dans un banc.

---

### RES-09 — L'historique de compensation de latence est échantillonné à chaque image rendue

**Titre.** Un Dictionary de 5 clés par image chez l'hôte, alors que les positions ne changent qu'au pas physique.

**Où.** `game_state.gd:2091-2092, 4266-4274, 252, 264`.

**Constat.**
```gdscript
# game_state.gd:2091-2092 (_process) puis 4271-4274
if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
	_record_position_history()
...
_pos_history.append({"t": now, "p1": p1.global_position, "p2": p2.global_position,
	"a1": p1.accroupi, "a2": p2.accroupi})
while _pos_history.size() > 1 and now - _pos_history[0]["t"] > POS_HISTORY_WINDOW:
	_pos_history.remove_at(0)
```
La fenêtre est correctement bornée en temps (0,4 s), mais le nombre d'entrées suit la cadence : ~24 à 60 fps, ~200 à 500 fps. Les positions des deux joueurs ne bougent qu'au pas physique (`move_and_slide` dans `_physics_process`) : à 500 fps, 8 échantillons sur 9 sont des doublons.

**Coût.** 120 à 500 Dictionary alloués, remplis et libérés par seconde, plus un `remove_at(0)` sur un tableau de 24 à 200 entrées : ESTIMÉ 0,05 % d'un cœur à 500 fps. Négligeable ; le défaut est surtout que le coût et la taille du tampon dépendent de la cadence (leçon de la killcam, ROADMAP:300-314).

**Proposition.** Enregistrer à chaque pas physique (60 Hz fixe, comme `ReplaySystem`) : même information, ≤ 24 entrées, coût constant. L'interpolation linéaire entre échantillons de pas rend une position rétroactive légèrement plus lisse qu'aujourd'hui (écart au plus un pas, 4,3 px à pleine vitesse).

**Gain attendu.** ~0,5 ms/s à 500 fps ; surtout une quantité constante.

**Risque.** Compensation de latence : la position rétroactive peut différer de quelques pixels ; à valider par `test_netcode` (qui alimente `_pos_history` à la main) et `banc_equite`.

**Effort.** S.

**Sévérité.** ANECDOTIQUE.

**Statut ROADMAP.** NOUVEAU.

**Comment le vérifier.** `tools/test_netcode.tscn` (`_test_rewound_position`) ; moniteur `Performance.OBJECT_COUNT` / mémoire sur un duel hôte à cadence libre.

---

### RES-10 — La préparation d'une mise à jour gèle la fenêtre plusieurs secondes

**Titre.** Empreinte SHA-256 de 130 à 185 Mo, extraction par `OS.execute` bloquant, et fil de téléchargement qui tourne à vide.

**Où.** `update_manager.gd:295, 306-311` ; `update_installer.gd:179-198` ; `update_manager.gd:140-167` ; moteur `http_request.cpp:180-185`.

**Constat.**
```gdscript
# update_manager.gd:295, 308 — après le téléchargement, sur le fil principal
if UpdateManifest.empreinte_fichier(_archive) != str(paquet["sha256"]): ...   # FileAccess.get_sha256
var prep := _installeur.preparer_bundle(_archive, racine, str(paquet["racine"]))
# update_installer.gd:186 — OS.execute est bloquant ; le 4e argument est read_stderr
code = OS.execute("/usr/bin/ditto", ["-x", "-k", chemin_archive, chemin_vers], sortie, true)
```
Les archives publiées font 130 960 497 et 185 128 994 octets (ROADMAP:2459). Le SHA-256 et `ditto` / `tar` / `unzip` tournent donc sur le fil principal pendant que l'écran affiche « Téléchargement… » : fenêtre figée plusieurs secondes (ESTIMÉ 2 à 4 s ; le système peut l'étiqueter « ne répond pas »). Le téléchargement threadé est correct, mais la boucle du fil est `while (...) { _update_connection(); delay_usec(1); }` (moteur `http_request.cpp:180-185`) : un cœur tourne à vide pendant toute la requête (une à deux secondes pour la vérification de +3 s, toute la durée du téléchargement ensuite).

**Coût.** Rare et volontaire (geste du joueur, écran dédié, jamais en match : refus n° 4 du fichier). Hors chemin chaud. Le nettoyage du démarrage suivant (`nettoyer_apres_installation`) coûte quatre `stat` quand il n'y a rien à effacer.

**Proposition.** Lancer le SHA-256 et l'extraction dans un `Thread` / `WorkerThreadPool` et attendre un signal en rafraîchissant « Préparation… » ; ou, au minimum, passer l'état à `Etat.TELECHARGEMENT` avec un libellé « Vérification et préparation… » et laisser une image se dessiner avant l'appel bloquant.

**Gain attendu.** Une fenêtre qui ne se fige pas ; un cœur de moins en boucle active pendant le téléchargement n'est pas corrigible sans changer de client HTTP.

**Risque.** Faible ; l'installeur a des suites (`test_mise_a_jour.gd`).

**Effort.** M.

**Sévérité.** ANECDOTIQUE.

**Statut ROADMAP.** NOUVEAU (Phase 9 ne mentionne pas le blocage).

**Comment le vérifier.** Une mise à jour réelle ; ou, sans réseau, un micro-banc headless qui appelle `preparer_bundle` sur une archive d'essai d'une centaine de Mo : `Engine.get_process_frames()` relevé avant et après ne bouge pas (le gel tient à l'appel bloquant) et `Time.get_ticks_msec()` en donne la durée. `tools/test_mise_a_jour.gd` couvre déjà l'installeur et reste à rejouer.

---

### RES-11 — `NetworkManager._process` : `get_peers()` par image en ligne, `_reset_rtt()` par image hors ligne

**Titre.** Micro-gaspillage sur du code toujours actif.

**Où.** `network_manager.gd:967-976, 979-983, 985-988`.

**Constat.** `_process` appelle `_remote_peer()` (donc `multiplayer.get_peers()`, qui alloue un tableau) à chaque image en ligne, et `_reset_rtt()` (quatre affectations) à chaque image hors ligne, pour n'envoyer qu'un ping par seconde.

**Coût.** ESTIMÉ ~0,2 ms/s. Négligeable.

**Proposition.** `set_process(false)` hors ligne et un `Timer` d'une seconde pour le ping (ou, si RES-02 est adopté, garder l'accumulateur mais ne tester `get_peers()` qu'à l'échéance).

**Gain attendu.** Négligeable.

**Risque.** Nul.

**Effort.** S.

**Sévérité.** ANECDOTIQUE.

**Statut ROADMAP.** NOUVEAU.

**Comment le vérifier.** Profileur de scripts (temps propre de `NetworkManager._process`).

---

## 3. Ce qui est déjà bien fait

1. **Aucun émetteur au rythme du rendu.** Commandes au pas physique (`player.gd:1727`), état par intervalle temporel du moteur, ping et synchro du chrono par delta. Le piège « fps déplafonnés = rafale de paquets » est évité par construction ; ne pas déplacer ces envois dans `_process`.
2. **Des commandes qui sont des niveaux, numérotées, bornées côté hôte.** `is_finite`, `limit_length(1.0)`, `seq <= _last_input_seq` rejeté, expéditeur vérifié, remise au neutre à la déconnexion (`player.gd:1394-1424`, `network_input_provider.gd:56-67`). Un paquet perdu ne casse rien et rien n'a besoin de redondance.
3. **Un encodage déjà compact par le moteur.** Booléens sur 1 octet, entiers sur 2 à 5 : les sept boutons d'une commande tiennent en 7 octets. Pas de String ni de Dictionary de Variant sur le chemin chaud.
4. **Le dispositif de version.** Carnet tenu à la main, témoin recalculé, poignée de main figée à un seul paramètre (`rpc_hello(payload: String)`, `network_manager.gd:1026`), refus symétrique, version dans l'attribut de salon et dans le filtre de la file d'appariement. La liste des gardes de `protocol.gd` est un modèle (voir RES-04 pour le trou à boucher).
5. **Des tampons bornés en temps et non en images** : 0,4 s pour l'historique de compensation, 32 instantanés, 120 commandes de prédiction, enregistrement de killcam à 60 Hz fixe. Aucune croissance non bornée dans les chemins réseau.
6. **Des services HTTP prudents.** Une requête à la fois, délais, reprises bornées (3 x 4 s), jeton Epic redemandé à chaque appel, journal local écrit **avant** l'envoi par fichier temporaire puis renommage (atomique), rejeu du journal au démarrage. Mises à jour : signature RSA-4096 vérifiée avant tout, empreinte avant décompression, plafonds de taille (64 Ko manifeste, 600 Mo paquet), téléchargement threadé vers fichier, jamais pendant un match.
7. **Un appariement bien cadencé.** Une passe toutes les ~5 s, `_busy` qui interdit les passes qui se chevauchent, délai de garde de 45 s sur un candidat qui échoue, recul exponentiel de 2 à 16 s après un ticket perdu (leçon payée du 2026-08-18 : Epic cesse de suivre), autoload inerte en headless et hors recherche.
8. **Un transport interchangeable sans fuite** : aucun `if transport` hors `network_manager.gd` et du bloc de salon d'`ui.gd` ; ping applicatif borné (`clampf` à 10 s) ; arrêt propre d'EOS (`set_process(false)` -> une image -> `release()`), à ne jamais raccourcir.

---

## 4. Questions ouvertes

1. **Valider RES-02.** Dans le cloud, le test d'ordre (pair factice) prouve le mécanisme et la boucle ENet sert de témoin ; l'ampleur sur EOS (`test_transport --max-fps 60` et `144`, avant/après) demande des identifiants Epic et un humain, et c'est la mesure qui tranche. L'expérience `--extra-tick` n'a jamais été consignée ; son résultat (probablement nul) confirmerait que le goulet est la pompe et non le tick.
2. **Coût réel de `EOS_Platform_Tick` et de la pompe**, par image, en menu et en duel : profileur de scripts sur `EOSGRuntime._process`. Rien dans la ROADMAP. Seule une mesure dit si RES-08 vaut une ligne.
3. **Octets réels** (profileur réseau de l'éditeur, ou octets dans `PeerSpy`) pour confirmer le modèle de 1.3, notamment l'enveloppe P2P d'Epic que ce rapport n'a pas pu déterminer (direct ou relayé). Le relais Epic n'a jamais été exercé (ROADMAP:228).
4. **Que faire des cartes trop grosses pour EOS** : refuser avec message (RES-01, étape 1, sans rupture de fil) ou payer un transfert découpé (VERSION 20 -> 0.9.0 et coupure de la population). Décision d'Adrien ; il faut aussi trancher si le classé continue de tirer dans les cartes joueur (ROADMAP:2112-2124, question d'équité déjà ouverte).
5. **Compensation de latence : repère à vérifier.** `_lag_comp_delay() = RTT/2 + INTERP_DELAY` (`game_state.gd:4309-4310`) recule P1 de `RTT/2 + 100 ms`. Ce que voit le tireur date, en repère hôte, de `RTT + 100 ms` (état hôte -> client : une demi-RTT ; commande client -> hôte : l'autre demi-RTT), plus ~une image hôte et une demi-image client (RES-02). Hypothèse : la compensation n'en couvre que la moitié, et favorise un peu la cible (l'hôte). Peut être voulu (compromis courant) mais la ROADMAP dit que la validation à 120 ms de latence simulée n'a **jamais** été faite (ROADMAP:89, 34071). À mesurer avant tout changement de `INTERP_DELAY` ou de `replication_interval`.
6. **Passer à 60 Hz de synchronisation et 50 ms de retard d'interpolation** : +~4-5 Ko/s par sens contre ~50 ms de latence perçue en moins sur l'adversaire. Arbitrage de conception, pas de CPU. Comme `INTERP_DELAY` est une règle que les deux pairs doivent partager (la compensation de l'hôte la suppose chez le client), c'est une rupture de sens : `VERSION = 20`.
7. **Instantanés datés à l'arrivée.** `_on_net_synchronized` pose `Time.get_ticks_msec()` (`player.gd:1482`) : après un hoquet local de H ms, tous les paquets accumulés reçoivent la même date et l'adversaire « saute » d'un coup (durée nulle entre instantanés). Sans effet à 60 fps stable, visible sur un pic de plus de 100 ms (le cas du « 1 % bas »). Mesurable en simulant un `OS.delay_msec(150)` côté client ; la correction demanderait de dater les paquets à l'émission.
8. **Temps de démarrage** : mesurer le temps jusqu'au premier menu avec et sans `--no-eos --no-supabase --sans-maj` pour isoler l'initialisation synchrone du SDK EOS (`initialize` et `create`). Les drapeaux existent déjà.
9. **Détection de déconnexion lente** et **relais Epic jamais exercé** (ROADMAP:323-325, 34072-34074) : dettes connues, hors périmètre de ce rapport mais à rejouer avec RES-01 (la limite de 1 170 octets est la même sur un lien relayé).

---

## Annexe — fichiers moteur et binaire consultés

- Moteur 4.7.1-stable : `scene/main/scene_tree.cpp` (l. 707-713), `main/main.cpp` (l. 4966-5089, physique puis `process` puis rendu), `modules/multiplayer/scene_multiplayer.cpp` (`poll`, `send_command`, profilage), `scene_replication_interface.cpp` (`on_network_process`, `_send_sync`, `sync_mtu = 1350`), `scene_rpc_interface.cpp` (`_send_rpc`, `rpcp`), `multiplayer_synchronizer.cpp` (`update_outbound_sync_time`, `get_state`), `scene/main/multiplayer_api.cpp` (`encode_and_compress_variant`), `modules/enet/enet_multiplayer_peer.cpp` (`put_packet`), `scene/main/http_request.cpp` (boucle de fil), `scene/gui/control.cpp` et `label.cpp` (surcharges de thème), `core/io/marshalls.cpp` (encodage `float`, `Vector2`).
- Binaire EOSG (Linux x86_64, debug) : `EOSGMultiplayerPeer::_get_max_packet_size` = 0x492 ; `_put_packet` (gardes `p_buffer_size` et `packet.packet_size()`) ; `EOSGPacketPeerMediator::_init`, `_on_process_frame`, `poll_next_packet` ; chaînes `process_frame()` et `does not support unreliable ordered`.
