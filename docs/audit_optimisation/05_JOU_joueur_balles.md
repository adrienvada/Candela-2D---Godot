# Audit JOU — Simulation CPU : joueur, balles, effets de manche, entrées

Dépôt `52a29c1` (0.8.3 + SOLO S12), lecture seule, Godot **non lancé**. Fichiers lus en entier : `player.gd`, `bullet.gd`,
`bullet_casing.gd`, `footprint.gd`, `blood_stain.gd`, `wall_impact.gd`, `kill_shockwave.gd`, `particle_pool.gd`,
`training_target*.gd`, `weapon_data.gd`, `input_provider.gd`, `local_input_provider.gd`, `network_input_provider.gd`,
`input_setup.gd`, `liaisons.gd`, `player.tscn`, `bullet.tscn`. Lus pour remonter les appelants : `game_state.gd` (tir, historique de
compensation, caméras, fantômes), `peinture_iso.gd`, `miroirs_iso.gd`, `charte.gd` (courbes, fontes), `light_textures.gd`,
`gadget_base.gd`, `replay_system.gd` (enregistrement), `ui.gd` (`_input`), `presentation_3d.gd` (visée), `camera_iso.gd`.

> **Honnêteté des chiffres.** Aucun chiffre de microsecondes ci-dessous n'est mesuré : Godot était interdit. **PROUVÉ** = lu dans le code
> (ce qui s'exécute, combien de fois). **ESTIMÉ** = coût unitaire déduit d'un modèle (voir « Hypothèses de coût » en annexe), avec une
> fourchette. Là où le moteur intervient (re-tri d'un groupe, reconstruction d'un `Line2D`, cache de glyphes d'un `FontVariation`), c'est
> un comportement connu du moteur que je n'ai pas pu vérifier ici : il est marqué ESTIMÉ.

---

## 0. Lecture rapide

1. **Aucun CRITIQUE.** La simulation du joueur, de la balle et des entrées est bon marché : ESTIMÉ ≈ 0,5–1 ms par image rendue en
   échange de tirs soutenu (soit 3–6 % du budget de 16,7 ms), dont la moitié vient du pool de particules. Cohérent avec la ROADMAP
   (« D'où viennent les millisecondes du duel », l. 34076-34147 : torches et shaders joueur sous le bruit, le coût est dans le rendu).
2. **Le seul poste permanent qui compte** est `ParticlePool.advance()` : une résolution de Bézier par Newton **en GDScript** par particule
   active et par image rendue (JOU-03, MAJEUR, effort S).
3. **Les frames qui comptent pour le « 1 % bas » sont les frames d'événement**, pas le régime continu : une touche de pompe pose, en
   une seule image, 25 gouttes de sang par plomb (jusqu'à 125), 2 taches par plomb, 1 chiffre de dégâts par plomb, avec 3 copies de chaque
   tache (J2, peinture iso) et une éviction par balayage de groupe au plafond. ESTIMÉ 2–3,5 ms **par plomb qui touche** (JOU-01, JOU-02,
   JOU-05).
4. **Le relevé `banc_pics` n'a pas pu voir ces pics** : son corrélat « particules » est le **stock actif** (`tools/banc_pics.gd:150`,
   saturé vers 122/200), pas le **flux d'émission par image**. La conclusion « `banc_pics` a écarté particules, objets et nœuds »
   (ROADMAP l. 3000, 22360) ne tient donc pas pour l'émission.
5. **La prédiction client ne re-simule rien** : 0 input rejoué, 0 `move_and_slide` supplémentaire ; une correction est un lissage
   exponentiel consommé par au plus un `move_and_collide` par tick. Le coût de la prédiction ne dépend pas du RTT, seulement la taille d'un
   petit historique (RTT/16,7 ms entrées).
6. **Entrées** : tout est lu par sondage dans `_physics_process` ; aucun `_input` dans le joueur ni les fournisseurs. Seul `ui.gd::_input`
   voit passer chaque évènement (JOU-11, ANECDOTIQUE).
7. **Ordre d'attaque conseillé** : JOU-03 (table de courbe, S, sans risque) → JOU-04 + JOU-01 (a)(b)(c) (S) → **mesurer** avec
   `tools/bench_particles.gd` (déjà là, headless) → seulement alors JOU-02 (M) et JOU-08 (M).

---

## 1. Carte des chemins chauds

### 1.1 Quantités au pire cas (un duel ; l'aventure SOLO porte jusqu'à **8 PNJ**, `aventure_format.gd:102`, chacun un `Player` complet)

| Quoi | Quantité | Source |
|---|---|---|
| Joueurs simulés | 2 (1 + 8 PNJ en aventure) ; ~30 nœuds chacun | `player.tscn`, `player.gd:594-979` |
| Fantômes de killcam | 2 `Node2D` nus, **aucun script**, cachés hors killcam : coût nul en match | `game_state.gd:1689-1725` |
| Lumières par joueur | 1 ambiante à ombres **toujours allumée**, torche + rétrodiffusion à ombres si torche, flash de bouche à ombres 0,1 s, écho au sol 0,12 s par tir, lumière de coup à ombres 1 s par PV perdu | `player.gd:901-917, 812-893, 2722-2731, 2909-2932` |
| Balles en vol | pistolet 1-2/joueur ; Occulteur (0,09 s) ~2 ; pompe 5 plombs/volée, `bullet_max_distance` 180 px ; fusil 2 rebonds, 15 000 px à 15 000 px/s. Une balle vit ≈ 6 ticks + 0,08 s de fondu ⇒ **≤ ~10 en même temps** | `game_state.gd:508-570, 5165-5242` |
| Particules | pool de **240** `RigidBody2D` (+ `Polygon2D` + `PointLight2D` + `CollisionShape2D`), **200** actives au plus ; pic relevé **122** (ROADMAP l. 34244) | `particle_pool.gd:22-23` |
| Traces persistantes (toute la session, même carte/mode/adversaire) | sang **120**, éclats de mur **90**, douilles **120** ; chacune dédoublée (copie J2) ; + 3ᵉ copie dans `PeintureIso` en vue iso ⇒ ~330 originaux, ~660 nœuds en 2D, ~1 000 avec la peinture | `blood_stain.gd:37`, `wall_impact.gd:45`, `bullet_casing.gd:19`, `peinture_iso.gd:55` |
| Empreintes | TTL 2 s, **pas de plafond** mais cadence bornée par la marche : 5,8 pas/s/joueur ⇒ ≈ 23 originaux + 23 copies, **46 Tweens** vivants | `footprint.gd:21, 64-119` |
| Physique | 60 ticks/s (défaut, `project.godot` sans réglage) ; rendu **déplafonné** (60-120+ fps sur le M3) | `project.godot:169-171` |

### 1.2 Par image rendue (`_process`) — fps déplafonnés

| Chemin | Travail | Alloc / lookups | ESTIMÉ |
|---|---|---|---|
| `Player._process` ×2 `player.gd:1259-1390` | hôte : publie 6 propriétés `net_*` ; `GadgetBase.effacements_a` (2 groupes) ; 7 écritures `modulate.a` ; `_couper_l_ombre` (sort si inchangé) ; `AudioManager.set_dazzle_level` | 2 `get_nodes_in_group` + 2 littéraux de tableau (1340, 1360) + 1 `values()` dans l'audio ≈ **5 allocations/image/joueur** ; 0 `get_node` ; 0 requête physique ; 0 `print` | 12-25 µs/joueur |
| `ParticlePool._process` `particle_pool.gd:286-304` | pour **chaque** particule active : 8 accès Dictionary, `Charte.courbe` (Newton), 2 `get_node(String)`, 2 écritures (échelle, énergie de lumière morte) | 2 NodePath + conversions par particule | **5-8 µs × N** : 0,1 ms (N=20 poussières) · 0,3-0,6 ms (N=60-120) · 1-1,6 ms (N=200) |
| Tweens vivants (SceneTree) | `tw_reveal` (4 `Charte.animer` ×2 s après chaque tir), chiffres de dégâts (4 ×1,1 s), 46 tweens d'empreintes (`modulate:a`), fondu de balle | `Charte.courbe` à chaque pas d'`animer` | 0,05-0,15 ms pendant un échange |
| `BulletCasing._process` | seulement tant que la douille glisse (~0,4 s), puis `set_process(false)` ✔ | – | ~0 |
| `KillShockwave._process` | 0,4 s à la mort : `queue_redraw` + `draw_arc` 97 points | – | zone franche |
| `GameState._process` (hôte) `game_state.gd:2091-2092` | `_record_position_history()` : **1 Dictionary de 5 clés par image rendue** | 1 alloc + `remove_at(0)` | 2-4 µs |
| `ReplaySystem.record_frame` (autre agent) `replay_system.gd:122-260` | cadence fixe 60 Hz ; `Snapshot.new()`, 4 `get_node("MuzzleFlash")`, balayage des enfants de `bullet_container`, 2 boucles sur `bullet_events` | ~10 allocs / snapshot | 10-25 µs ×60/s |
| `PeintureIso._process` (iso, autre agent) | UPDATE_ONCE du **rendu complet de la peinture** à chaque trace posée/retirée (`peinture_iso.gd:183-200`) | – | GPU, à chiffrer côté iso |

### 1.3 Par tick physique (60 Hz)

| Chemin | Travail | ESTIMÉ |
|---|---|---|
| `Player._physics_process` ×2 `player.gd:1694-2217` | lecture de ~12 commandes ; `move_and_slide()` si ≠ 0 vitesse (CharacterBody2D, polygone concave décomposé, mode GROUNDED par défaut) ; `_regler_enjambement` (2 balayages des murs bas + écriture de `collision_mask` à chaque tick, 1557-1572) ; bruit de pas/Footprint tous les 45 px ; 5 écritures `position.y` + 1 littéral (1947-1953) ; **torche allumée** : `_rapprocher_la_lampe` = **2 `intersect_ray`** (nouvel objet de requête + `exclude=[rid]` + Dictionnaire de résultat chacun, 1667-1691), bruit, `get_nodes_in_group("gadgets")` (2003), 3 écritures d'énergie, poussière toutes les 0,12 s ; **`_update_aim_line`** : `RayCast2D` de 2000 px (1 requête interne) + `PackedVector2Array` + `Line2D.points=` (2357-2362) | 60-150 µs/joueur (+ `move_and_slide` : non estimé finement) |
| Client prédit `player.gd:1826-1837` | **1 Dictionnaire** `{pos,rot,accroupi}` par tick ; `multiplayer.get_peers()` ; `rpc_id(1, "rpc_send_inputs", …10 args)` | 5-10 µs |
| Client, adversaire interpolé `player.gd:1613-1656` | `_apply_remote_interpolation` : recherche **linéaire** dans `_net_snapshots` (≤ 32, en pratique 3-5), ~12 accès Dictionary | 3-6 µs |
| `Bullet._physics_process` ×(≤10) `bullet.gd:177-357` | 1 `ShapeCast2D.force_shapecast_update()` ; `_maj_tunnel` → `get_nodes_in_group("fusees")` **à chaque tick** (347, 535-539) ; `Core.points=` + `has_node/get_node("Core")` par String (356-357) ; arbalète : boucle sur les joueurs (497-520) | 15-25 µs/balle |
| Physique des particules | jusqu'à 200 `RigidBody2D` actifs contre le seul masque des murs (`collision_layer = 0` : pas de paires particule-particule) ; les corps amortis s'endorment | 2-6 µs/corps (non mesuré) |

### 1.4 Par paquet réseau

| Chemin | Travail |
|---|---|
| Hôte, `rpc_send_inputs` (60 Hz par le client) `player.gd:1394-1417` | 1 `get_first_node_in_group`, bornage `limit_length`, `update_input_state` : O(1) |
| Client, `_on_net_synchronized` (30 Hz/joueur) `player.gd:1475-1491` | interpolé : 1 Dictionnaire de 5 clés + parfois `slice(i)` (nouveau tableau) ; prédit : `_ingest_prediction_correction` → `keys()` + `erase` de RTT/16,7 ms entrées |

### 1.5 Par événement (c'est là que se jouent les pics)

| Événement | Ce qui s'exécute dans la même image | ESTIMÉ |
|---|---|---|
| **Pas** (45 px) `player.gd:1895-1896` | `Footprint.new` + `add_child` + `_ready` (Tween + `call_deferred`) + copie J2 différée (`duplicate()`, 2ᵉ Tween) ; `AudioManager.play_footstep` | 60-120 µs |
| **Tir** `player.gd:2404-2448`, `game_state.gd:4157-4250` | pour chaque balle : `instantiate` + `Line2D`/`Sprite2D`/`ShapeCast2D`/`CircleShape2D` neufs (`bullet.gd:75-169`), en iso 2 `MeshInstance3D` + 2 `ShaderMaterial` (`miroirs_iso.gd:357-359`) ; `trigger_shoot_visuals` : 3 Tweens + lambdas + `PointLight2D.new()` (écho au sol) ; douille (`BulletCasing`, éviction au plafond + copie J2) ; 3 grains de fumée ; `_tinter_la_douille` (timer) ; son ; `_rumble_shoot` (timer) | 0,3-0,8 ms (pistolet) ; ×N plombs |
| **Touche** (par plomb) `bullet.gd:396-429, 672-699, 732-810` | 25 gouttes (15+10) ; 2 taches de sang (+2 copies J2 + 2 copies peinture) ; chiffre de dégâts (`Label`, `LabelSettings`, **`FontVariation` neuf**, 5 tweeners) ; `take_damage` → `rpc_update_hp` : `PointLight2D` à ombres de 400 px 1 s + vignette + son | **2-3,5 ms/plomb** ; volée de pompe complète : jusqu'à ~10 |
| **Impact de mur** (par plomb) `bullet.gd:705-729` | 12 étincelles ; 1 éclat (`wall_impact`, éviction au plafond, copie J2, copie peinture) ; son | 0,8-1,2 ms/plomb ; volée de pompe : 3-6 ms |
| **Mort** `player.gd:2945-3327` | `CanvasLayer` + `ColorRect` + shader, 2 bandeaux FATAL (Label, `LabelSettings`, `FontVariation`, `TextureRect` + `load()` du cartouche, flèche, tweens) | zone franche (manche finie) |

### 1.6 Réponses aux six questions de la mission

**Q1 — Un joueur par image et par tick.** Voir 1.2/1.3. Allocations : ~5/image et ~8-12/tick par joueur (torche allumée), toutes
petites. Recherches de nœuds : **zéro `get_node` par chemin** dans `Player` (tout est mis en cache dans des `@onready`/variables) ; seuls
des `get_first_node_in_group("game_state")` (1 par tick) et des `get_nodes_in_group` sur groupes presque vides. Requêtes physiques :
1 `RayCast2D` (visée) + 2 `intersect_ray` (lampe, torche allumée) + `move_and_slide`. Signaux : un seul, `synchronized`, à 30 Hz. **`print()` :
aucun** dans `player.gd`/`bullet.gd`/pool/traces (PROUVÉ par `grep` ; seuls `input_setup.gd:104-112` au démarrage). La propriété
`run/flush_stdout_on_print` ne coûte donc rien en match.

**Q2 — Prédiction/correction.** **Zéro input re-simulé.** `_ingest_prediction_correction` (1497-1522) compare la position hôte à
`_predict_history[net_ack_seq]` ; au-delà de 4 px il pose `_predict_error`, que `_consume_prediction_error` (1526-1541) résorbe de
`1 − exp(−12 Δt)` par tick via **un** `move_and_collide(step)` (plus un seul `move_and_slide` par tick comme d'habitude). Au-delà de
100 px : téléport + historique vidé. L'historique est borné (`PREDICT_HISTORY_MAX = 120`) et purgé à chaque paquet ; le tampon
d'interpolation (`SNAPSHOT_BUFFER_MAX = 32`) est parcouru linéairement mais ne contient en pratique que 3-5 entrées (le retard
de 100 ms à 30 Hz ; `slice(i)` rogne les anciennes). **Historique de compensation de l'hôte** (400 ms) : **une allocation par IMAGE rendue,
pas par tick** (`game_state.gd:2092, 4271`) — 24 entrées à 60 fps, ~80 à 200 fps ; relu linéairement depuis la plus ancienne, deux fois par
volée d'un client (`_rewound_position`, `_rewound_posture`) : négligeable (JOU-10).

**Q3 — Balles.** Pas de pool : `bullet_scene.instantiate()` par plomb (`game_state.gd:4182`) puis `_ready` crée 4 objets (dont une
`CircleShape2D`, donc une ressource physique) ; en iso, 2 `MeshInstance3D` + 2 `ShaderMaterial` de plus par balle (`miroirs_iso.gd:357-359`).
Par tick : 1 `ShapeCast2D` (pas de raycast séparé ; rebond = `direction.bounce`, fusil seulement), `Core.points=` reconstruit, 1
`get_nodes_in_group("fusees")`. **Plus aucune lumière attachée** (décision d'Adrien 2026-09-15, `bullet.gd:77-84`). La mort lance un Tween
(2 `animer`) + `queue_free` au bout de 0,08 s (0,35 s pour le tir fatal). Détail : JOU-06, JOU-07.

**Q4 — Traces sur 5 minutes.** **Plafonnées** (120/90/120, éviction FIFO de la doyenne, retrait de groupe immédiat) ; empreintes bornées par
leur TTL. Le coût de dessin croît jusqu'à saturation puis reste plat : douilles saturées en ~120 tirs, sang en ~60 touches, éclats en 90
impacts de mur ; chaque trace est un `CanvasItem` dessiné **une fois** (`_draw` sur `queue_redraw` à la pose ; le fondu passe par `modulate`).
Ce qui **ne** s'accumule **pas** : aucun redessin par image. Ce qui coûte : la **pose** (JOU-02), les copies (JOU-08), et un **rendu
complet de la peinture iso à chaque pose/retrait** (`peinture_iso.gd:183-200`, côté iso). Chaque tache porte son propre
`ShaderMaterial` (`blood_stain.gd:320`) mais les deux textures qu'elle dessine (`_texture`, `_coeur`) cassaient déjà le regroupement.

**Q5 — `particle_pool.gd`.** C'est un **vrai pool** (240 corps pré-alloués, 200 actifs max, recyclage de la plus ancienne, aucune
allocation de nœud en match) ✔. Ce n'est **ni `GPUParticles2D` ni `CPUParticles2D`** : des `RigidBody2D` + `Polygon2D` (pour le rebond
sur les murs : `physics_material_override.bounce` 0,2/0,6). La ROADMAP ne tranche pas ce choix (seul `CPUParticles2D` y apparaît, pour
l'ambiance des menus, l. 18567) ; aucun `GPUParticles2D` n'existe dans le dépôt. **Émetteurs hors écran** : aucun test de visibilité — la
poussière du faisceau est émise pour **chaque** torche allumée, y compris celle de l'adversaire loin de l'écran (`player.gd:2036-2057`),
et toutes les particules actives sont mises à jour et simulées qu'elles soient vues ou non (durée de vie ≤ 3 s : coût borné).
Détail : JOU-01, JOU-03, JOU-04.

**Q6 — Entrées.** **Aucun traitement par évènement dans le joueur** : `LocalInputProvider` sonde `Input.get_vector`, `Input.get_action_*`
depuis `_physics_process` (la souris est lue par `get_mouse_position()` au moment du tir/de la visée, jamais par `InputEventMouseMotion`).
Aucune allocation par `InputEvent` dans mes fichiers. `Input.use_accumulated_input` est à son défaut (aucun script ni `project.godot` ne le
change) : les mouvements de souris sont fusionnés à ≤ 1 par image rendue. Les évènements de manette (non accumulés) passent tous par
`ui.gd::_input` (JOU-11). Seul coût par commande : ~50 conversions `String → StringName` par tick (noms d'actions stockés en `String`),
et la visée iso/le déplacement iso appelés deux fois par tick côté client prédit (négligeable, JOU-09).

---

## 2. Constats

### JOU-01 — Frame d'impact : émettre une particule coûte ~30-60 µs, et une volée en émet 60 à 125 dans la même image

- **Où** : `particle_pool.gd:138-164` (`emit`), `175-273` (`_configure`) ; appelants `bullet.gd:672-683` (15+10 gouttes **par plomb**),
  `bullet.gd:705-712` (12 étincelles par plomb), `player.gd:2704-2708` (3 grains de fumée par tir), `player.gd:2056` (poussière).
- **Constat** :
  ```gdscript
  # particle_pool.gd:176-178 — trois get_node(String) à CHAQUE émission, puis 157-163 : deux de plus
  var poly := rb.get_node("Poly") as Polygon2D
  var light := rb.get_node("Light") as PointLight2D
  var circle := (rb.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
  circle.radius = 2.0                          # 181 : réécrit la forme côté physique, même inchangée
  poly.polygon = PackedVector2Array([...])     # 193 : tableau neuf + Polygon2D à re-trianguler
  rb.physics_material_override = _phys_blood   # 201 : recharge les caractéristiques physiques
  rb.position = pos ; rb.rotation = 0.0        # 270-271 : deux écritures de transformation vers la physique
  rb.freeze = false ; rb.show()                # 272-273 : changement de mode du corps + notifications
  ```
  Chaque particule recyclée est reconfigurée **en entier** (forme, matériau de rendu, matériau physique, lumière) alors que sa famille
  est le plus souvent celle de la fois d'avant. Le tout se répète `amount` fois : `bullet.gd:681-683` (15 + 10 × `particules_sang`),
  `:712` (12 × `eclats_impact`) **par plomb** ; la pompe tire 5 plombs au même tick (`game_state.gd:552`).
- **Coût** : PROUVÉ : ≈ 5 `get_node(String)`, ≈ 20 écritures de propriétés dont ≈ 8 partent vers un serveur (physique ou rendu), 1 Dictionnaire et
  1 `PackedVector2Array` par particule. ESTIMÉ **30-60 µs/particule** ⇒ 25 gouttes ≈ 0,75-1,5 ms ; 60 étincelles (volée de pompe dans un mur)
  ≈ 2-3,6 ms ; 125 gouttes (volée de pompe qui touche, hp non réduit) ≈ 4-7,5 ms, **en une seule image**. Le banc `tools/bench_particles.gd` mesure
  déjà ce chemin (85 émissions × 40 rafales) et imprime « Par impact de pompe » : sa sortie n'est consignée nulle part dans la ROADMAP.
- **Proposition** :
  (a) **S** — mettre `poly`, `light`/`circle` en cache dans le pool (par exemple trois `Array` parallèles indexés par le rang du corps, ou
  des clés `"poly"`/`"circle"` ajoutées au Dictionnaire d'`_active`, **compatible avec `tools/test_arena_lighting.gd:109` qui lit
  `_active[0]["rb"]`**) ; plus aucun `get_node` ni à l'émission ni dans `advance`.
  (b) **S** — ne réécrire que ce qui change : mémoriser la famille (`kind`) de chaque corps ; `circle.radius`, `poly.material`,
  `physics_material_override` seulement quand la famille change ; polygone unitaire posé une fois par famille, taille via `poly.scale` (déjà
  la variable d'animation).
  (c) **S** — supprimer la lumière du corps (voir JOU-04).
  (d) **M** — budget d'émission par image : file d'attente, ≤ 30-40 particules/image, le reste à l'image suivante (une volée s'étale sur 2-4 images,
  ≤ 50 ms ; le flash, le son et l'impact restent à l'image).
  (e) **Décision de design (Adrien)** : les plombs d'une même volée sur le même corps partagent **une** gerbe (25 gouttes, 2 taches) au lieu de 5.
- **Gain attendu** : (a)+(b)+(c) ESTIMÉ −30 à −50 % du coût d'émission (−0,3 à −1,5 ms sur une frame d'impact de pompe) ; (d) divise le pic
  par 2-4 ; (e) divise le coût de la volée par ~5 mais change l'image.
- **Risque** : (a)-(c) visuel nul ; l'ordre des tirages `randf*` ne change pas (les bancs reseedent par image, ROADMAP l. 3418). (d) retarde de
  16-50 ms certaines gouttes — imperceptible mais à valider à l'œil. (e) identité visuelle : **à trancher, pas à faire seul**. Aucun effet réseau
  (tout est local, jamais répliqué).
- **Effort** : S (a-c), M (d).
- **Sévérité** : **MAJEUR** (ESTIMÉ — à confirmer par `bench_particles`).
- **Statut ROADMAP** : NOUVEAU pour le chiffrage. CONNU-OUVERT pour la piste (l. 22420 : « la cause des pics … l'allocation dans `_process` et
  `_physics_process` »). **La conclusion « particules écartées » (l. 3000, 22360) est à rouvrir** : `banc_pics.gd:150` corrèle le *stock* actif.
  La passe de performance (l. 84-85) n'a mesuré que l'émission *relative* à l'ancien chemin (−44 %).
- **Comment le vérifier** : `godot --headless --path . --script res://tools/bench_particles.gd` (déjà headless) → diviser « émission totale »
  par 3 400 émissions (40 × 85) = µs/particule, avant/après. Puis `tools/banc_pics.tscn` **avec deux corrélats ajoutés** : émissions par image
  et traces créées par image. Suites à relancer : `test_match_format` (capacité, plafond, recyclage), `test_arena_lighting` (poussière).

---

### JOU-02 — Frame d'impact : poser une trace coûte ~0,4-0,8 ms (création, éviction, deux copies), et toutes sont « au plafond » après ~1-2 minutes

- **Où** : `bullet.gd:686-699` (2 taches/plomb), `705-729` (éclat), `game_state.gd:4216-4218` + `player.gd:1256` (douille) ;
  `blood_stain.gd:309-413, 450-529` ; `wall_impact.gd:57-166` ; `bullet_casing.gd:36-170` ; `peinture_iso.gd:208-280`.
- **Constat** :
  ```gdscript
  # blood_stain.gd:463-464 — au plafond (120), CHAQUE nouvelle tache
  while get_tree().get_nodes_in_group("blood_stain").size() >= MAX_STAINS:
      _evict_oldest()                  # 474 : get_nodes_in_group (2ᵉ tableau) + 120 `stain._order` non typés
  # puis add_to_group + call_deferred("_create_p2_duplicate") → duplicate() complet (498)
  # blood_stain.gd:320 / 405-411 — par tache : ShaderMaterial neuf, 2 ResourceLoader.exists, 2 load
  material = ShaderMaterial.new() ; ... load(chemin) ; load(coeur)
  # peinture_iso.gd:266 — 3ᵉ copie en vue iso (défaut) : scan complet des propriétés du nœud
  for p in source.get_property_list():  # ≈ 60-80 Dictionary de 6 clés, par trace
  ```
  Au plafond (régime établi : les traces **survivent aux manches** d'un même match, `blood_stain.gd:7-18`), chaque trace nouvelle =
  **créer 3 nœuds et en libérer 3** (original, copie J2, copie peinture) + 3 appels `get_nodes_in_group` sur un groupe qu'on vient de modifier
  (le moteur re-trie un groupe modifié par ordre d'arbre à chaque lecture : ESTIMÉ 60-100 µs pour 120 nœuds). Même mécanique pour les
  douilles (120) à **chaque tir** (`bullet_casing.gd:74-77, 138-144`) et pour les éclats (90).
- **Coût** : PROUVÉ : la chaîne ci-dessus s'exécute pour chaque trace. ESTIMÉ **0,4-0,8 ms par tache** au plafond (création 30-60 µs, éviction
  150-250 µs, `ResourceLoader`+`load` 25-70 µs, copie J2 50-100 µs, copie peinture 150-250 µs, 3 `_draw` ~30 µs), 0,3-0,5 ms par éclat ou douille.
  Un plomb qui touche ⇒ 2 taches ≈ 1-1,5 ms ; une volée de pompe complète ⇒ 10 taches ≈ 4-8 ms, sur la frame d'impact et la suivante (copies
  différées). L'éviction avait été jugée « négligeable devant le son et les particules » (`blood_stain.gd:469-471`) : l'arbitrage ne
  comptait ni le re-tri du groupe, ni les copies, ni le fait que *toutes* les poses sont ensuite au plafond.
- **Proposition** :
  (a) **M** — **recycler au lieu d'évincer puis créer** : au plafond, reprendre le nœud le plus ancien (`setup()` à nouveau + `queue_redraw()`) et ses
  copies J2/peinture en leur recopiant leur état (4-6 variables, par une méthode `recopier_sur(copie)` explicite dans chaque classe de trace). Zéro
  création/libération en régime établi.
  (b) **S** — file FIFO statique (`static var _vivantes: Array[Node2D]`, `pop_front()` quand la taille atteint le plafond) à la place du balayage
  de groupe ; le groupe reste pour les tests et la peinture.
  (c) **S** — textures en `const` + `preload` (patron de `GOUTTES_SANG`, `particle_pool.gd:52-59`) au lieu de `exists`+`load` par tache ; un
  `ShaderMaterial` partagé en `static var` (`blood_shader.gdshader` n'a aucun paramètre).
  (d) **M** — `PeintureIso._copier` : remplacer `get_property_list()` par la méthode `recopier_sur()` de (a).
- **Gain attendu** : ESTIMÉ −60 à −80 % du coût de pose en régime établi (il reste `setup` + `queue_redraw`) : de ~1-1,5 ms à ~0,3 ms par plomb qui touche.
- **Risque** : tests `test_sang_au_sol`, `test_traces_carte`, `test_traces_rencontre` (groupes `blood_stain`/`blood_p2`/`casing_p2`, comptes, balayage
  `game_state.gd:1382-1397`) ; l'invariant « le total ne dépasse jamais le plafond, même dans la même frame » (`blood_stain.gd:459-462, 481-483`)
  doit survivre ; la peinture iso est indexée par original (`_copies[n]`) : un recyclage doit redemander un rendu (`_sale = true`). Aucun effet réseau
  ni sur la simulation (traces locales).
- **Effort** : M (a, d) ; S (b, c).
- **Sévérité** : **MAJEUR** (ESTIMÉ).
- **Statut ROADMAP** : DÉJÀ-TRANCHÉ pour le plafond (D7, l. 12107-12115) et pour « parcours linéaire négligeable » (`blood_stain.gd:469-471`) ;
  NOUVEAU pour le chiffrage de la pose complète et pour le recyclage.
- **Comment le vérifier** : micro-banc headless (même patron que `bench_particles.gd`) : poser 200 taches avec le plafond abaissé (`MAX_STAINS` est un
  `static var` pour cela, `blood_stain.gd:37`) et chronométrer `Time.get_ticks_usec()` autour de `flaque.setup`/`add_child` ; `tools/banc_pics.tscn`
  (pics corrélés aux touches) ; `Performance.OBJECT_NODE_COUNT` plat sur 5 minutes. Suites : `test_sang_au_sol`, `test_traces_carte`, `test_traces_rencontre`.

---

### JOU-03 — `Charte.courbe()` : résolution de Bézier par Newton, en GDScript, à chaque image pour chaque particule et chaque tween

- **Où** : `charte.gd:1112-1115` (`courbe`), `1195-1224` (`_bezier_axe`/`_pente`/`_y`) ; consommateurs `particle_pool.gd:300`, `charte.gd:1145-1152`
  (`animer`) et `1175-1181` (`animer_via`) ; aussi `ui.gd:440`, `son_visible.gd:360` (repli).
- **Constat** :
  ```gdscript
  static func _bezier_y(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
      var t := x
      for _i in _NEWTON_PASSES:                       # jusqu'à 6 passes
          var ecart := _bezier_axe(t, x1, x2) - x     # 1 appel de fonction GDScript
          if absf(ecart) < _EPSILON:
              return _bezier_axe(t, y1, y2)
          var pente := _bezier_pente(t, x1, x2)       # 1 de plus
          ...
      # filet : bissection ~20 itérations, 1 appel chacune
  # particle_pool.gd:300 — chaque image, chaque particule active
  var eased: float = 1.0 - Charte.courbe(Charte.Courbe.EXTINCTION, t)
  ```
  Les quatre courbes sont **fixes** et la fonction est **pure** sur [0,1] : rien ne justifie de la résoudre à chaque appel.
- **Coût** : PROUVÉ : ≈ 9-10 appels de fonctions GDScript par évaluation convergée (4 passes + évaluation finale), ~20 de plus si le filet est pris.
  ESTIMÉ **4-10 µs/appel**. Par image rendue : pool = N × (4-10 µs) → 0,1-0,2 ms (N=20 poussières, toujours là si une torche est allumée),
  0,3-0,6 ms (N=60-120 en échange), jusqu'à ~1 ms (N=200) ; tweens d'un échange (`tw_reveal` 4 courbes × 2 s après chaque tir,
  `player.gd:2671-2688` ; 4 par chiffre de dégâts 1,1 s, `bullet.gd:795-808` ; 2 par balle qui s'éteint) ≈ 30-60 µs. **À 120 fps le coût est doublé
  par rapport à 60.**
- **Proposition** : **S** — table précalculée par courbe dans `charte.gd` (257 échantillons, interpolation linéaire, extrémités exactes) construite à
  l'initialisation de la classe (≈ 4 × 257 × 6 µs ≈ 6 ms **au démarrage**, jamais au premier tir) ou écrite en `const PackedFloat32Array`. `courbe()` devient
  une lecture + une interpolation (~0,3 µs). Les appelants ne changent pas. Écart maximal estimé ≈ 4×10⁻⁵ sur EXTINCTION (courbure ≲ 20, pas 1/256),
  très en deçà des seuils de `tools/test_charte.gd` (10⁻³ à 4×10⁻²).
- **Gain attendu** : −85 à −90 % du coût de `courbe` : **−0,1 à −0,9 ms par image** selon N (pool) et −25 à −50 µs (tweens). Profite aussi à tous les
  `Charte.animer` des menus (ui, panneaux).
- **Risque** : visuel nul à 10⁻⁴ près ; `test_charte` (départ 0, arrivée 1, monotonie de ENTREE, crête de REBOND > 1,02 — échantillonnée à 1/256, aucun problème) à
  relancer ; `ui.gd:440` et `son_visible.gd:360` utilisent aussi `courbe` mais tolèrent 10⁻⁴. Pas d'effet réseau/simulation (affichage pur).
- **Effort** : S.
- **Sévérité** : **MAJEUR** (le plus gros calcul pur du domaine, croît avec N × fps).
- **Statut ROADMAP** : NOUVEAU (« Courbes … évaluées par `Charte.courbe()` », l. 12257, sans mention de coût ; la fiche DA4.13 ne chiffre rien).
- **Comment le vérifier** : script headless qui appelle `Charte.courbe(EXTINCTION, t)` 100 000 fois (t croissant) avant/après, et compare l'écart max à l'ancienne
  version sur 10 000 points ; `bench_particles.gd` étendu d'une boucle `pool.advance(1.0/120.0)` à N = 20/60/122/200 ; `tools/test_charte.gd`.

---

### JOU-04 — Pool de particules : `advance()` hors courbe, mises à jour au rythme du rendu, et 240 `PointLight2D` mortes

- **Où** : `particle_pool.gd:286-304` (`advance`), `126-132` (une lumière par corps), `197-198, 214-216, 234-242, 258-260` (lumière éteinte dans les 4 familles),
  `268` (`light.color`), `161-162, 302-303` ; tests `tools/test_arena_lighting.gd:110`, `tools/test_match_format.gd:214`.
- **Constat** :
  ```gdscript
  # advance(), chaque image, chaque particule
  (rb.get_node("Poly") as Polygon2D).scale = (entry["scale"] as Vector2) * eased
  (rb.get_node("Light") as PointLight2D).energy = float(entry["energy"]) * eased   # entry["energy"] vaut 0.0 pour les 4 familles
  ```
  Les 4 familles posent `light.enabled = false` et `light.energy = 0.0` (le sang depuis le 2026-09-10, les étincelles depuis le 2026-09-15, la poussière et
  la fumée n'ont jamais éclairé). L'écriture d'énergie est donc `0 × eased` : **inutile** ; les 240 `PointLight2D` vivent pourtant dans l'arbre (un RID
  de lumière chacune) et sont reconfigurées à chaque émission (`light.color`, `LightTextures.poser` pour 3 familles sur 4). `advance` tourne dans
  `_process` (**rendu déplafonné**) alors que les corps ne bougent qu'à 60 Hz (aucune interpolation physique activée).
- **Coût** : PROUVÉ : 2 `get_node(String)`, ~8 accès Dictionary, 2 écritures vers le rendu par particule et par image. ESTIMÉ 1,5-2,5 µs/particule/image
  (hors courbe) ; à 120 fps, la moitié des mises à jour est redondante avec le pas physique.
- **Proposition** : (a) **S** — `entry["poly"]` rempli à l'émission, plus de `get_node` ; (b) **S** — supprimer le nœud `Light`, ses écritures et
  `LightTextures.poser` (adapter les 2 suites, dont l'assertion « aucune lumière de particule ne projette d'ombre » devient triviale) ; (c) **S** — n'appeler
  `advance` qu'au pas de 60 Hz (accumuler `delta`, appeler avec le delta accumulé) ; (d) option — tableaux parallèles `PackedFloat32Array` plutôt que
  Dictionnaires.
- **Gain attendu** : −40 à −50 % du coût résiduel d'`advance` avec (a)(b), puis −50 % de plus à 120 fps avec (c) ; −240 nœuds `Light2D` et −240 RID de lumière.
- **Risque** : (c) l'extinction visuelle passe à 60 Hz : à l'œil identique (la position est déjà à 60 Hz) ; (b) deux suites à adapter ; `tools/banc_lumieres.gd` et
  `banc_balle_sans_lumiere.gd` recensent les lumières **activées** (inchangées).
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU. (Lumières éteintes : DÉJÀ-TRANCHÉ pour le rendu, l. 5417-5435 et `particle_pool.gd:31-36, 252-257` ; le *nœud* n'a jamais été retiré.)
- **Comment le vérifier** : `bench_particles.gd` étendu (voir JOU-03) ; `Performance.OBJECT_NODE_COUNT` (−240 + −240 enfants de lumière) ; `test_match_format`, `test_arena_lighting`.

---

### JOU-05 — `Charte._variation()` n'a pas de cache : un `FontVariation` neuf pour chaque chiffre de dégâts (et chaque bandeau)

- **Où** : `charte.gd:614-623` ; appelants `bullet.gd:737` (à chaque plomb qui touche), `player.gd:3028, 3306` (bandeau FATAL + marge),
  `releve_balistique.gd:373, 397, 425, 456, 471` (killcam), `arena_decor.gd:338`, `estampe_de_kill.gd:131`, …
- **Constat** :
  ```gdscript
  static func _variation(chemin: String, poids: int) -> Font:
      if not ResourceLoader.exists(chemin): return null
      var base := load(chemin) as Font
      ...
      var v := FontVariation.new()          # un objet neuf À CHAQUE APPEL
      v.base_font = base
      v.variation_opentype = {TAG_WGHT: poids}
      return v
  # bullet.gd:737 — chaque plomb qui touche
  settings.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
  ```
- **Coût** : PROUVÉ : un `FontVariation` + un Dictionnaire + un `exists` + un `load` par appel, jamais partagés. ESTIMÉ (moteur : un `FontVariation` a son propre cache de
  glyphes et ses propres pages d'atlas dans le TextServer) : les glyphes du chiffre (corps, contour, ombre) sont **rastérisés à nouveau** pour chaque
  chiffre de dégâts, soit 0,2-0,6 ms par plomb qui touche (×5 pour une volée de pompe) ; 1-3 ms par bandeau FATAL (zone franche).
- **Proposition** : **S** — `static var _fontes: Dictionary` clé `[chemin, poids]` ; aucune des 16 sites d'appel ne mute la fonte (lecture par
  `LabelSettings.font`, `draw_string`, `get_string_size`) — vérifié. En complément, option : pré-rastériser les chiffres 0-9 aux tailles utilisées pendant le
  chargement (le premier affichage de chaque taille de chiffre — entre `T_APPUI` 19 et `T_VERDICT` 42 — rastérise sinon à la volée).
- **Gain attendu** : ESTIMÉ −0,2 à −0,5 ms par chiffre ; supprime l'allocation répétée de pages d'atlas.
- **Risque** : faible. `tools/test_charte.gd:475-476` compare deux graisses (clés distinctes) ; ne pas partager un `FontVariation` que quelqu'un modifierait
  ensuite (aucun cas aujourd'hui).
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : micro-banc headless : créer 200 `Label` avec `LabelSettings` via `Charte.police_display`, forcer `get_minimum_size()` (qui force la mise en forme),
  chronométrer avant/après ; `Performance.RENDER_TEXTURE_MEM_USED` plat pendant un échange.

---

### JOU-06 — Frame de tir : tout est créé par balle (nœuds, forme physique, quads iso, tweens, lumière d'écho)

- **Où** : `game_state.gd:4182-4196` ; `bullet.gd:75-169` (`_ready`), `601-641` (`_fade_and_destroy`) ; `miroirs_iso.gd:357-359, 389-399` ; `player.gd:2612-2731`
  (3 Tweens, `ground_flash`) ; `bullet_casing.gd` (JOU-02).
- **Constat** :
  ```gdscript
  # bullet.gd:90-156 — par balle : Line2D, Sprite2D, ShapeCast2D + CircleShape2D (une ressource physique)
  var circle = CircleShape2D.new() ; circle.radius = radius ; shape_cast.shape = circle
  # miroirs_iso.gd:357-359 — iso (défaut), au premier tick de la balle : 2 MeshInstance3D + 2 ShaderMaterial
  q = {"core": _quad("BalleCoeur", …, true), "aura": _quad("BalleAura", …, true)}
  # player.gd:2722-2731 — par tir : une PointLight2D neuve, un Tween neuf, libérés 0,12 s plus tard
  var ground_flash := PointLight2D.new() ; … ; add_child(ground_flash)
  ```
- **Coût** : PROUVÉ : ~8 créations d'objets de rendu/physique par balle (+ 3 Tweens et 1 lumière par tir). ESTIMÉ 0,3-0,8 ms la frame d'un tir de pistolet (douille
  non comprise), ≈ 0,15 ms par plomb de plus pour la pompe. La lumière d'écho au sol compte dans la limite des 15 lumières par item (ROADMAP l. 5425 : « 7 » simultanées
  au banc de rafale).
- **Proposition** : (a) **S** — un `CircleShape2D` partagé en `static var` pour le rayon 4 (une ressource physique de moins par balle) ; (b) **S** — réutiliser une
  `PointLight2D` d'écho par joueur (activer, rejouer l'énergie) au lieu d'en créer une par tir ; (c) **M** — pool de balles (nœuds `Core`/`Aura`/`ShapeCast2D`
  gardés ; remise à zéro explicite de `bounces_left`, `_traverses`, `_frolement_joue`, tunnel de fumée, exceptions du cast) — **à ne faire qu'après mesure** (JOU-01/02 d'abord).
- **Gain attendu** : ESTIMÉ −0,1 à −0,3 ms par tir.
- **Risque** : le pool exige une remise à zéro rigoureuse (la killcam instancie la même scène, `game_state.gd:4384`, avec `is_replay`) ; les miroirs iso sont indexés par
  `get_instance_id()` (`miroirs_iso.gd:353`) : un pool doit les réinitialiser ; `Bullet` est un nœud RPC-neutre (non répliqué) : pas de risque de nom.
- **Effort** : S (a, b), M (c).
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : CONNU-OUVERT en principe (« Ponctuel et poolé — Ouvert », l. 34216 ; « toute particule passe par le pool », l. 10793) ; NOUVEAU pour le chiffrage et pour les quads iso.
- **Comment le vérifier** : `tools/banc_pics.tscn` (marqueurs de tir) ; `Performance.OBJECT_NODE_COUNT` (créations/libérations par seconde) ; `tools/test_tir_et_reserves.gd`,
  `tools/test_prediction_tir.gd`, `tools/test_iso_objets.gd`.

---

### JOU-07 — Dessins invisibles recalculés à chaque tick : `Line2D.points` des traçantes et de la ligne de visée, `RayCast2D` de visée des joueurs que personne ne regarde

- **Où** : `bullet.gd:356-357` (et `616-617`), `player.gd:949-968, 2357-2362, 1742, 2065`, `miroirs_iso.gd:328-336, 360-371, 433-439`.
- **Constat** :
  ```gdscript
  # bullet.gd:356-357 — à chaque tick de chaque balle qui vole (même une fois la longueur plafonnée à 800 px)
  if has_node("Core"):
      get_node("Core").points = PackedVector2Array([Vector2.ZERO, Vector2(-trail_length, 0)])
  # player.gd:2362 — à chaque tick de chaque joueur (RayCast2D de 2000 px + Line2D)
  aim_line.points = PackedVector2Array([Vector2(28, 0), end_pos])
  # miroirs_iso.gd:332/367/374 — en iso (défaut) ces dessins 2D sont retirés de toutes les lightmaps
  item.visibility_layer = Presentation3D.COUCHE_HORS_VUE
  ```
  En vue iso, `miroirs_iso` rend traçante, aura et ligne de visée en **quads 3D** et envoie leurs `Line2D`/`Sprite2D` sur `COUCHE_HORS_VUE` : aucune vue 2D ne les
  dessine plus, mais chaque affectation de `points` relance le `_draw()` du `Line2D` (le nœud reste `visible`) ; il sert seulement de porteur de données
  (`ligne.points` est relu par `miroirs_iso`). Et la ligne de visée de l'**adversaire** (couche privée de l'autre, `player.gd:970-973`) et celle de tout **PNJ** ne
  sont visibles dans aucune vue : leur `RayCast2D` + `Line2D` sont calculés pour rien.
- **Coût** : PROUVÉ : 1 `Line2D` reconstruit par balle et par tick, 1 par joueur et par tick ; ESTIMÉ 3-6 µs la reconstruction (moteur : `Line2D::set_points` ne compare
  pas) + 2-4 µs la requête de visée. Duel : ≈ 20-60 µs/tick ; aventure à 8 PNJ : jusqu'à ≈ 0,15 ms/tick.
- **Proposition** : **S** — (a) balle : n'écrire `points` que si `trail_length` change (il est plafonné à 800) ; mémoriser `core` dans une variable (`@onready`) au lieu de
  `has_node`/`get_node("Core")` par String ; (b) joueur : n'actualiser la ligne (et laisser `aim_cast.enabled` allumé) que si ce joueur est regardé — vrai en écran scindé hors
  entraînement, sinon `player_id == _index_joueur_local()` (ou 0 hors ligne) et `not est_pnj` ; sinon `aim_cast.enabled = false`. **M** (optionnel) — porter le segment dans des
  variables lues par `miroirs_iso` et passer le `Line2D` en `visible = false` en iso.
- **Gain attendu** : ESTIMÉ −0,02 à −0,15 ms par tick (duel → aventure).
- **Risque** : `miroirs_iso._suivre_joueurs` lit `ligne.points` et `is_visible_in_tree()` (`miroirs_iso.gd:333-334`) ; `tools/test_iso_objets.gd`, `banc_murs_bas.gd`,
  `banc_gadgets_volume.gd` référencent `aim_line`. **Équité** : la ligne de visée de l'adversaire doit rester invisible chez l'autre (inchangé : on ne fait que cesser de la calculer).
- **Effort** : S.
- **Sévérité** : MINEUR (ANECDOTIQUE en duel).
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : `Performance.TIME_PHYSICS_PROCESS` (moyenne glissante : voir ROADMAP l. 3029-3041 pour le piège de ce moniteur) en SOLO à 8 PNJ avant/après ;
  `tools/test_iso_objets.gd`.

---

### JOU-08 — Les copies J2 des traces et des empreintes sont créées même quand la vue de J2 n'est jamais affichée

- **Où** : `footprint.gd:96-119`, `blood_stain.gd:491-529`, `wall_impact.gd:140-166`, `bullet_casing.gd:154-170` ; contexte `CLAUDE.md` (« Boucle de jeu » : deux vues seulement en
  « 1v1 écrans scindés »).
- **Constat** : chaque trace existe en deux exemplaires (couche 2 pour la vue de J1, couche 4 pour celle de J2) pour l'écran scindé. En ligne, à l'entraînement et en
  solo — la majorité des parties —, une seule vue est affichée : **un exemplaire sur deux est toujours masqué** par le `canvas_cull_mask` (l'hôte voit les originaux, le client voit les
  copies). L'autre est quand même créé (`duplicate()` différé), dessiné, et — pour les empreintes — animé par son propre Tween. En iso, `PeintureIso` en ajoute une troisième.
- **Coût** : ESTIMÉ : à saturation ≈ 330 nœuds de traces masqués ; empreintes : 23 nœuds + 23 Tweens inutiles en marche continue des deux joueurs (≈ 25-35 µs par image) ;
  par événement, un `duplicate()` de 30-80 µs en moins par trace.
- **Proposition** : **M** — ne créer la copie que si les deux vues sont affichées (écran scindé hors entraînement) ; sinon poser la couche de **la vue regardée** sur
  l'original (hôte : 2 ; client : 4). Prédicat à fournir par `GameState` (la logique existe déjà : `Player._rect_monde_de_la_vue`, `oreille_suit`).
- **Gain attendu** : −50 % des nœuds de traces et des Tweens d'empreintes ; ≈ −0,05 à −0,1 ms par image ; −1 `duplicate()` par trace posée.
- **Risque** : moyen — `test_traces_carte`, `test_traces_rencontre`, `test_calques_joueur` comptent les copies ; la peinture iso enregistre les copies dans les groupes `*_p2`
  (`peinture_iso.gd:38-55`) ; le balayage au changement de mode (`game_state.gd:1382`) évite les traces orphelines si les vues changent. **À trancher par l'architecte du dépôt.**
- **Effort** : M.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU (la duplication est un idiome assumé, l. 18196 ; elle n'a pas été revue depuis que l'écran scindé a cessé d'être permanent, l. 34108-34147).
- **Comment le vérifier** : `Performance.OBJECT_NODE_COUNT` à saturation des plafonds en ligne ; nombre de Tweens (`SceneTree.get_processed_tweens().size()`) pendant une marche à deux ; suites ci-dessus.

---

### JOU-09 — Micro-coûts par tick et par image dans le joueur et la balle (à traiter si l'on touche au fichier)

- **Où / Constat** (tous PROUVÉS ; chacun ≲ 10 µs) :
  1. `player.gd:1667-1691` — `_rapprocher_la_lampe` : par tick et par joueur torche allumée, 2 × (`PhysicsRayQueryParameters2D.create` + `exclude = [get_rid()]` + Dictionnaire de
     résultat). Pistes : créer les 2 objets de requête une fois (`_ready`) et ne changer que `from`/`to` ; **sauter les 2 rayons si position et rotation sont inchangées depuis
     le tick d'avant** (joueur immobile torche allumée : cas très courant).
  2. `player.gd:1340, 1360, 1947` — trois littéraux de tableau (`[visual, …]`) à chaque image/tick ; `:2362` `PackedVector2Array([…])`.
  3. `player.gd:2003` — `get_nodes_in_group("gadgets")` à chaque tick/joueur torche allumée ; `gadget_base.gd:628-630` — 2 groupes par image/joueur ; `bullet.gd:536` — `fusees` par
     tick/balle.
  4. `bullet.gd:356-357` — `has_node("Core")` + `get_node("Core")` par String à chaque tick.
  5. `player.gd:1379-1390` — **boucle morte** : `for c in get_children(): if c is Camera2D` — aucune `Camera2D` n'est jamais enfant d'un `Player` (`player.tscn` n'en contient pas ;
     `game_state.gd:1629-1637` les met sous `players_node`) : `shake_intensity`/`add_camera_shake` ne secouent rien côté joueur (la vraie secousse est dans `game_state`, `cam1_shake_time`).
     ≈ 3-5 µs/image/joueur pendant ≈ 0,25-0,5 s après chaque tir ou touche.
  6. `player.gd:1557-1572` + `1772` — `_regler_enjambement` : 2 balayages de `MursBas.murs_de_la_manche` et une écriture de `collision_mask` à **chaque tick** pour tout joueur qui peut
     bouger, alors que le geste d'enjamber est retiré depuis le 2026-10-04 (il ne reste que le cas « déjà dans la pierre »). Piste sûre : écrire le masque **seulement au changement**, et sortir
     tôt si `murs.is_empty()`.
  7. `player.gd:1431-1432` — `multiplayer.get_peers()` (tableau) à chaque tick côté client, pour un compteur de diagnostic.
  8. `player.gd:1502, 1837` — `_predict_history.keys()` (tableau) par paquet, et par tick quand l'historique dépasse 120.
  9. `local_input_provider.gd:75-137` — noms d'actions stockés en `String` (≈ 50 conversions `String → StringName` par tick) ; `get_movement_vector`/`get_aim_direction` appelés
     deux fois par tick côté client prédit (`_send_inputs_to_host` puis la simulation). Piste : stocker des `StringName` (`&"p1_move_up"`).
  10. `player.gd:1947-1953` — 5 écritures `poly.position.y = _roulis` par tick et par joueur **même à l'arrêt** (`_roulis = 0`) : `Node2D.set_position` n'a pas de garde d'égalité
      (ESTIMÉ, moteur) ; piste : écrire seulement si `_roulis` a changé.
- **Coût** : ESTIMÉ ≈ 20-60 µs par tick et par joueur au total ; < 0,3 % d'un cœur.
- **Proposition** : regrouper ces retouches dans un même commit « micro » (S) ; l'item 1 (rayons) et l'item 6 (masque) sont les plus utiles ; l'item 5 est du code mort à supprimer.
- **Gain attendu** : ≈ −0,03 à −0,1 ms par tick.
- **Risque** : item 6 — symétrie hôte/prédiction : la règle doit rester une fonction pure de la position (inchangé si l'on n'écrit que le changement) ; item 5 — `tools/test_*` qui
  liraient `shake_intensity` (non trouvé, à greper avant) ; item 1 — attention à ne pas figer la lampe contre un mur qui apparaît (gadget bloquant) : n'invalider que si position/rotation inchangées **et** pas de gadget.
- **Effort** : S.
- **Sévérité** : ANECDOTIQUE.
- **Statut ROADMAP** : NOUVEAU. (La piste générale « allocation dans `_process` et `_physics_process` » est CONNU-OUVERT, PE3.2, l. 22420 : **réponse de cet audit : elle ne peut pas expliquer des pics**, ~15-20
  petites allocations par tick et par joueur.)
- **Comment le vérifier** : `Performance.TIME_PHYSICS_PROCESS` ; `tools/test_marche.gd`, `test_planche_marche.gd`, `test_accroupi` (enjambement), `test_prediction_tir.gd`.

---

### JOU-10 — Historique de compensation de latence : un Dictionnaire par image rendue (hôte), fenêtre de 400 ms ⇒ jusqu'à ~80 entrées

- **Où** : `game_state.gd:2091-2092` (appel dans `_process`), `4266-4274` (`_record_position_history`), `4277-4305` (lectures). *À croiser avec l'agent `game_state`.*
- **Constat** :
  ```gdscript
  _pos_history.append({"t": now, "p1": …, "p2": …, "a1": p1.accroupi, "a2": p2.accroupi})   # 1 Dictionnaire par IMAGE
  while _pos_history.size() > 1 and now - _pos_history[0]["t"] > POS_HISTORY_WINDOW:
      _pos_history.remove_at(0)                                                              # O(n)
  ```
  La fenêtre est en temps (✔ le principe « tampon en durée, pas en images » est acté, ROADMAP l. 34452), mais l'allocation et la taille du tampon croissent avec la cadence de rendu (24 entrées à 60 fps, ~80 à 200 fps). Lectures
  linéaires depuis la plus ancienne, deux fois par volée d'un client (`_do_spawn_bullet` calcule `lag_center` et `lag_hauteur` une seule fois par volée, `game_state.gd:4166-4175`).
- **Coût** : ESTIMÉ 2-4 µs par image ; ≈ 0,2-0,5 ms/s. Négligeable.
- **Proposition** : tampon circulaire de `PackedFloat32Array` échantillonné au pas physique (60 Hz, dans `_physics_process`) : zéro allocation, taille fixe, et la compensation devient indépendante de la
  cadence de rendu (aujourd'hui l'échantillon interpolé dépend de l'image rendue la plus proche).
- **Gain attendu** : ≈ −3 µs/image ; surtout de la propreté (déterminisme vis-à-vis du fps).
- **Risque** : réseau/équité — la compensation d'un tir du client interpole entre deux échantillons : passer de 60-200 Hz à 60 Hz change légèrement la précision (≤ 16 ms d'échantillonnage vs ~5 ms) ;
  `tools/test_prediction_tir.gd` et les bancs d'équité (`banc_equite*.gd`) à relancer. **À ne pas faire sans l'agent réseau.**
- **Effort** : S.
- **Sévérité** : ANECDOTIQUE.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : `tools/test_prediction_tir.gd`, `tools/banc_equite.gd`.

---

### JOU-11 — `ui.gd::_input` : 9 recherches dans l'`InputMap` par évènement, en ligne, en plein match

- **Où** : `ui.gd:8284-8346` (surtout 8290-8295, 8301).
- **Constat** :
  ```gdscript
  if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
      if event.is_action("p2_menu_right") or event.is_action("p2_menu_left") or … # 7 is_action
  …
  if event.is_action_pressed("sys_pause"): …
  var pause_open: bool = _panneau_ouvert(pause_panel)
  if not _panneau_ouvert(game_over_panel) and not pause_open: return          # sortie, mais APRÈS les 8 recherches
  ```
  En match en ligne (aucun panneau ouvert), la sortie rapide arrive après les 7 `is_action` du filtre J2 et le `is_action_pressed("sys_pause")`. Chaque évènement du jeu passe ici :
  mouvements de souris (**fusionnés à ≤ 1 par image**, `use_accumulated_input` par défaut), mais aussi chaque variation d'axe de manette (non fusionnée).
- **Coût** : ESTIMÉ 3-5 µs/évènement ; une manette bavarde (quelques centaines d'évènements/s) ⇒ 1-2 ms/s ≈ 0,1-0,2 % d'un cœur.
- **Proposition** : tester d'abord `menu_voile`, `_is_rebinding`, puis la sortie « aucun panneau ouvert et pas d'appui pause » avant le filtre J2 (réordonner, sans changer de comportement) ;
  `StringName` en constantes.
- **Gain attendu** : ≈ −2 à −4 µs par évènement ; ~0.
- **Risque** : l'ordre des gardes de `_input` porte le contrat du menu pause et du réassignement : relire `tools/test_menu_*` / `test_pause_*` après coup.
- **Effort** : S.
- **Sévérité** : ANECDOTIQUE.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : suites de menus de `tools/run_suites.sh` ; compteur de `_input` par seconde avec une manette connectée.

---

## 3. Ce qui est déjà bien fait (à ne pas casser)

1. **Aucun `print()` dans le chemin chaud** (`player.gd`, `bullet.gd`, pool, traces) : `flush_stdout_on_print=true` (`project.godot:39`) ne coûte rien en match, comme son commentaire l'annonce (« zéro print dans player.gd et bullet.gd »).
2. **La prédiction ne rejoue rien** : correction lissée (`player.gd:1497-1541`), historique et tampon d'interpolation **bornés** (120 / 32), purge à chaque paquet, `move_and_collide` plutôt qu'un
   téléport (`player.gd:1538`). Le coût est indépendant du RTT.
3. **Plafonds + éviction FIFO des traces avec retrait de groupe immédiat** (120/90/120 ; `release()` retire du groupe avant `queue_free`), douilles qui coupent leur `_process` au repos
   (`bullet_casing.gd:95`), empreintes et traces **dessinées une seule fois** (le fondu passe par `modulate`), polygones d'empreinte partagés en `static var` (`footprint.gd:44-45`).
4. **Pool de particules réel** : 240 corps pré-alloués, plafond de 200 avec recyclage de la doyenne, aucune lumière à ombre, textures de gouttes et shader du sang en `const preload`
   (`particle_pool.gd:52-59`, `blood_stain.gd:32`) — la leçon « un `Shader.new()` à la volée compile au premier mort » est appliquée partout.
5. **La balle n'a plus aucune lumière** (`bullet.gd:77-84`) : plus de saturation des 15 lumières par item, matériau additif partagé en `static var` (`bullet.gd:66-73`), un seul
   `ShapeCast2D` par balle (pas de rayon séparé) avec exceptions explicites, boucle de gadgets traversants **bornée** (`TRAVERSES_MAX`).
6. **Écritures sur changement seulement** là où elles comptent : `_rapprocher_la_lampe` (`is_equal_approx`, 1679-1682), `poser_posture`, `_couper_l_ombre`, `_poser_pose` (ne réaffecte les 5
   textures que quand la pose change, 1075-1087), `flashlight.position`.
7. **Entrées par sondage** : le joueur ne connaît pas le périphérique (`InputProvider`), aucun traitement par évènement, hôte qui **borne** ce qu'il applique (`rpc_send_inputs`,
   `player.gd:1410-1414`) ; et les évènements de souris sont fusionnés par le moteur.
8. **Chargements lourds payés hors action** : sprites et planche de marche chargés au changement d'arme (`player.gd:1033-1065`), texture de torche cuite (`weapon_data.gd:231-239`),
   ombre de silhouette mémorisée par chemin (`charte.gd:1012-1069`), `Fusee.prechauffer` au `rebuild_arena` — le patron existe, il reste à l'étendre (JOU-05).

---

## 4. Questions ouvertes

1. **Mesure d'abord.** Tous les µs de ce rapport sont estimés. Le banc `tools/bench_particles.gd` (headless, déjà là) donne le µs/particule d'émission ; un micro-banc équivalent pour la pose de tache au
   plafond et pour le chiffre de dégâts donnerait les deux autres. À faire **avant** JOU-02 (M) et JOU-08 (M).
2. **`banc_pics` doit changer de corrélat** : « particules » = stock actif (saturé à 122/200), il ne peut pas révéler un pic d'émission. Ajouter « émissions par image » et « traces créées par image »,
   et rouvrir la conclusion « particules écartées » (ROADMAP l. 3000, 22360).
3. **Adrien : une volée de pompe qui touche = 5 gerbes de 25 gouttes et 10 taches.** Garder (lisibilité du kill, identité « roman graphique ») ou partager une gerbe par corps touché dans la même image ?
   Le gain est de l'ordre de plusieurs ms sur la frame la plus décisive du jeu ; c'est un choix de direction artistique, pas de code.
4. **Architecture : les copies J2** hors écran scindé (JOU-08). Qui tranche ? Le prédicat « vues affichées » existe en substance mais pas comme API.
5. **Aventure à 8 PNJ** : chaque PNJ est un `Player` complet (~30 nœuds, 1 lumière d'ambiance **à ombres toujours allumée**, `RayCast2D` de 2000 px par tick, `Line2D`, `_process`/`_physics_process`
   complets, 2 rayons de lampe) : le coût du domaine est multiplié par jusqu'à 9. À mesurer en SOLO (`Performance.TIME_PHYSICS_PROCESS`, `OBJECT_NODE_COUNT`).
6. **GPU (agent lumières/rendu)** : la lumière de coup `hit_light` est une `PointLight2D` **à ombres** de 400 px, **par plomb qui touche**, vivante 1 s (`player.gd:2909-2932`) — jusqu'à 5 lumières à
   ombres simultanées après une volée —, plus un écho au sol par tir (ROADMAP l. 5425 : 7 simultanées au banc). Décidées « ce qui éclaire vraiment le jeu » (l. 5434) mais leur cumul en volée n'a pas
   été chiffré.
7. **GPU (agent iso)** : chaque trace posée ou retirée relance un rendu complet de la peinture (`peinture_iso.gd:183-200`, jusqu'à 4096² texels) ; en échange de tirs, plusieurs par seconde.
8. **`motion_mode` des `CharacterBody2D`** : défaut GROUNDED (jamais réglé : `grep motion_mode` vide), alors que le jeu est de dessus. FLOATING éviterait la logique sol/plafond/pente de
   `move_and_slide()` (coût non estimé), mais change le comportement aux murs sud/nord (ressenti, prédiction identique des deux côtés). **Ne pas toucher sans Adrien** ; mesurer d'abord.
9. **Cadence des mises à jour visuelles à 60 Hz** (JOU-04 c) : acceptable pour le fondu des particules ? À valider à l'œil sur un écran 120/144 Hz.
10. **`shoot_cooldown` décrémenté dans `_process`** (au rythme du rendu) : déjà signalé (ROADMAP l. 10303-10308, CONNU-OUVERT) comme dépendance du tir à la cadence ; le passer dans
    `_physics_process` supprimerait cette dépendance, mais change le pas où part le tir — décision d'Adrien.

---

## Annexe — Hypothèses de coût (ESTIMÉ) et limites

- GDScript typé : 25-60 ns par opération simple ; 0,1-0,25 µs par appel de fonction ; 0,3-0,5 µs par `get_node(String)` (conversion `NodePath` + résolution) ; 0,05-0,1 µs par accès Dictionnaire à clé `String`.
- Appel unitaire vers un serveur (rendu ou physique) : 0,2-1 µs ; écriture de transformation d'un corps physique : 2-4 µs ; changement de mode `freeze` : 3-6 µs.
- Création d'un nœud (`new` + `add_child` + `_ready`) : 5-15 µs ; `duplicate()` d'un `Node2D` scripté : 30-80 µs ; `get_property_list()` d'un `Node2D` scripté : 60-120 µs ; Tween : création 5-8 µs, pas 0,5-1 µs.
- `get_nodes_in_group` : ~0,2 µs (groupe vide) à 60-100 µs (120 nœuds, groupe modifié donc re-trié par ordre d'arbre).
- Comportements moteur supposés (non vérifiés ici) : `Line2D::set_points` relance toujours le dessin ; `Node2D::set_position` sans garde d'égalité ; cache de glyphes propre à chaque `FontVariation` ; re-tri d'un groupe modifié.
- Cadence : le M3 de référence tourne à 60-120 fps (ROADMAP l. 22359 : médiane ~120 en vue unique ; l. 30465-30470 : médianes 50-65 sur la scène de pompe de la 0.8.0) ; les coûts « par image » sont donnés pour 60 et 120 fps.
- **Non examinés** (autres agents) : `game_state.gd` (hors lignes citées), `audio_manager.gd` (voix, `play_weapon_shot`, `play_footstep`), `presentation_3d.gd`/`iso_volumes.gd` (rendu iso), `replay_system.gd` au-delà de l'enregistrement,
  `bot_input_provider.gd` (SOLO), le réseau (`rpc_send_inputs` à 60 Hz avec 10 arguments).
