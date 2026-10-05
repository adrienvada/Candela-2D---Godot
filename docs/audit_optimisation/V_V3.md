# V3 — « L'image d'impact » : vérification contradictoire (2026-10-05)

Contradicteur, lecture seule, Godot **non lancé**. Dépôt `52a29c1`.
Constats vérifiés : JOU-01, JOU-02, JOU-03, JOU-04, JOU-06 + ETA-08, JOU-08 (`05_JOU`, `06_ETA`), GAD-02 (`07_GAD`),
CAR-02 (`14_CAR`), AUD-03 (`11_AUD`). Le reproche fait au verdict de `tools/banc_pics.gd` est traité au § 2.
Pièces de calcul (Python pur, sans Godot) : `audit/V3_work/geometrie_pompe.py`, `courbe_sim.py`, `decompte.py`.

**Légende des chiffres.** PROUVÉ = lu dans le code, ou calculé exactement (comptage, géométrie, simulation numérique de la
fonction). MESURÉ = chiffre déjà relevé dans la ROADMAP (ligne citée). ESTIMÉ = raisonnement sur ce que fait Godot 4.x, avec
une fourchette ; aucun chronomètre derrière. À MESURER = je ne sais pas, et je ne l'invente pas.

---

## 0. Verdicts

| ID | Verdict | Sévérité corrigée | Ce qui change par rapport au rapport d'audit |
|---|---|---|---|
| JOU-01 | CONFIRMÉ AVEC RÉSERVE | MAJEUR (à confirmer par `bench_particles`) | structure prouvée ; « 60 à 125 par volée » corrigé par la géométrie (125 = contact seul) ; 20-50 µs/particule (pas 30-60), ×2,5 d'incertitude |
| banc_pics (reproche) | CONFIRMÉ AVEC RÉSERVE | — | le stock ne pouvait pas dépasser ≈ +12 % sur une gerbe, pour un seuil de 25 % ; la ROADMAP l. 2999 est prudente, l. 22360 « a écarté » ne l'est pas |
| JOU-02 | CONFIRMÉ AVEC RÉSERVE | MAJEUR au plafond en iso, MINEUR avant | « 10 taches par volée » n'existe qu'au contact (2 ou 6 en pratique) ; « toutes au plafond en 1-2 min » faux pour le sang ; 0,2-0,45 ms/tache avant plafond (iso) |
| JOU-03 | CONFIRMÉ | MINEUR (pas MAJEUR) | 10-12 appels GDScript PROUVÉS, jamais de bissection ; 2,5-5 µs/évaluation (pas 4-10) ; correctif sans risque |
| JOU-04 | CONFIRMÉ | MINEUR | écriture d'énergie sur lumière éteinte PROUVÉE ; ≈ 1,3-2 µs/particule/image |
| JOU-06 + ETA-08 | CONFIRMÉ (les deux rapports s'accordent une fois les périmètres alignés) | MINEUR | pas une cause de queue ; pool de balles à ne pas faire avant mesure |
| JOU-08 | CONFIRMÉ | MINEUR | gain par image surestimé ×3-8 (10-30 µs, pas 50-100) ; 40-80 µs par trace posée ; trois suites exigent les copies |
| GAD-02 | CONFIRMÉ, DOUBLON PARTIEL de JOU-03 | ANECDOTIQUE | Sentinelle seule ; la table de JOU-03 en règle la moitié ; pas dans l'image d'impact |
| CAR-02 | CONFIRMÉ AVEC RÉSERVE | ANECDOTIQUE | coût de base mesuré à 4,2 µs (ROADMAP l. 21387) contre 15-25 estimés ; événements de rejeu par PLOMB (pas par tir) |
| AUD-03 | CONFIRMÉ AVEC RÉSERVE | MINEUR | comptes exacts (8 `famille_de`, rayons doublés en vue unique) ; gain ≈ 25-45 µs/son (pas 50-100) ; 1 à 10 sons dans l'image d'impact |

**Décompte (§ 4)** : volée de pompe, vue iso, hors GPU et pilote — 5 plombs au mur **2,9-7,1 ms** ; 1 plomb au corps
**1,5-3,8 ms** ; 3 plombs au corps **4,5-11,4 ms** ; l'image du tir s'y ajoute (0,8-1,7 ms) si elle coïncide.
Particules 33-42 %, traces et leurs copies 23-31 %, sons 11-18 %.

---

## 1. Faits établis (recomptés, PROUVÉS)

### 1.1 Un plomb de pompe ne lance qu'UNE fois sa forme : à son premier tick

`game_state.gd:541-553` : pompe `bullet_speed 10000`, `bullet_max_distance 180`, `projectile_count 5`,
`spread_angles_deg [0, 20, -20, 60, -60]`, cooldown 0,45 s, dégâts 20 (centre) / 15 (bord).
`bullet.gd:177-192` :

```gdscript
var step = direction * weapon.bullet_speed * delta      # 10000/60 = 166,67 px
distance_traveled += travel_step
if distance_traveled >= weapon.bullet_max_distance:     # 166,67 < 180 au tick 1 ; 333 >= 180 au tick 2
    _fade_and_destroy(global_position) ; return
shape_cast.target_position = Vector2(travel_step, 0)    # le seul lancer de la vie du plomb
shape_cast.force_shapecast_update()
```

Donc **tous les impacts d'une volée tombent au même tick** (le premier tick du plomb), et ce lancer balaie 166,7 px +
rayon 4. Un plomb qui ne touche rien meurt au tick suivant (`_fade_and_destroy`, sans effet).

### 1.2 Combien de plombs touchent, selon la distance (calcul exact, `V3_work/geometrie_pompe.py`)

Modèle : plomb = cercle de rayon 4 balayé sur 166,67 px ; corps du joueur = cercle de rayon 18 (polygone de
`player.tscn:9`, le nez de 28 px est ignoré) ; muzzle à 28 px du centre (`player.tscn:69`) ; mur plat perpendiculaire à la
visée ; visée au centre du corps. Les joueurs se bloquent entre eux (même couche 1, `PLAYER_MASK` contient la couche 1) :
D vaut au moins 36 px de côté, 46 px nez contre corps, 56 px nez contre nez.

| Cible | Distance | Plombs qui touchent |
|---|---|---|
| Corps | D (centre à centre) < 54 px | **5** (fenêtre pratique : D de 36-46 à 54 px selon les orientations, soit au contact) |
| Corps | 54 ≤ D < 93 px | **3** (0°, ±20°) |
| Corps | 93 ≤ D < 217 px | **1** (0°) |
| Mur | w (canon → mur) < 88 px (centre → mur < 116 px = 3,3 tuiles de 35 px) | **5** |
| Mur | 88 ≤ w < 161 px | **3** |
| Mur | 161 ≤ w < 171 px | **1** |
| Mur | w ≥ 171 px | 0 (le plomb meurt en l'air) |

Conséquences : (1) « 125 gouttes » (JOU-01) n'est atteint qu'au contact ; le maximum pratique d'un corps est **3 plombs =
75 gouttes + 6 taches**. (2) « 10 taches par volée » (JOU-02) n'existe qu'au contact (D < 54 px) : le cas courant est **2
taches (1 plomb) ou 6 (3 plombs, D < 93 px)**.
(3) « 60 étincelles » est atteint contre un mur à moins de 88 px du canon, situation courante en salle étroite.
(4) `bench_framerate.gd:108` et `banc_pics.gd:42` posent `DUEL_DISTANCE = 150` : à 150 px (canon à 122 px du centre
adverse) **un seul plomb touche le corps** ; les quatre autres partent dans le décor.

### 1.3 Ce que déclenche UN plomb qui touche

**Mur** (`bullet.gd:280-286` → `_spawn_wall_effects`, 705-729 ; pompe : `bounces_left = 0` donc `avec_son = true`) :
1 son `play_wall_impact` ; 12 étincelles (`emit SPARK`) ; 1 `WallImpact` (nœud, `set_script`, `setup` : `exists` + `load`,
`add_child`, `_ready`, copie J2 différée, copie peinture iso différée) ; `_fade_and_destroy` (Tween, 2 `animer`).

**Corps** (`bullet.gd:221-226` → `_hit_player` 396-429) : `take_damage` → `rpc_update_hp` (`player.gd:2875-2932` :
`_rumble`, `camera_hit_kick` = 1 Tween, `play_breath_hit` = 1 son, `noter_pv_perdus`, `PointLight2D` `hit_light` à ombres
+ Tween, ici OM6) + `add_camera_shake` + vignette (1 Tween) ; puis `_spawn_hit_effects` (672-699) : `play_hit` = 1 son,
25 gouttes (`emit BLOOD` 15 + 10), 2 `BloodStain` (nœud + `set_script` + `setup` + `_ready` + copie J2 + copie peinture) ;
`_spawn_damage_number` (732-810 : `Label`, `LabelSettings`, `FontVariation` neuf — JOU-05 —, 4 `animer`) ; `_fade_and_destroy`.

### 1.4 Les comptes sont FIXES : ce ne sont pas des réglages

`EffectPolicy.curseur("particules_sang" | "eclats_impact")` : effets de la famille MONDE, non réglables
(`effect_policy.gd:319-329`, `reglable()` faux ; `DEFAULT = 1.0`, `MAX = 1.0`). 25 gouttes par plomb au corps et 12
étincelles par plomb au mur sont donc des constantes de jeu — et des **informations de match** (`effect_policy.gd:237-246`).
Toute réduction du NOMBRE est une décision d'Adrien ; seule la réduction du COÛT par particule, ou l'étalement dans le
temps, est neutre.

### 1.5 Même tick que le tir, ou le tick suivant ? À LEVER AU BANC

Les plombs sont ajoutés pendant `Player._physics_process` (`game_state.gd:4196`). Dans les 4.x que je connais, `SceneTree`
itère sur un instantané de la liste de traitement : un nœud ajouté pendant la passe n'est traité qu'à la passe suivante
(plombs lancés au tick N+1). **Non vérifié sous 4.7 (pas de source ici).** À 60 i/s l'image d'impact serait donc l'image
qui suit celle du tir ; si les deux coïncidaient, leurs coûts (§ 4.4) s'additionneraient. Le banc du § 5 journalise
`Engine.get_physics_frames()` au spawn et à la première trace posée : une ligne qui tranche.

### 1.6 Ce que fait `emit()` par particule (BLOOD ; les trois autres familles sont voisines)

`particle_pool.gd:138-164` (`emit`) et `175-273` (`_configure`) : 5 `get_node(String)` (lignes 176, 177, 178, 161, 162) ;
**18 écritures de propriétés** : `circle.radius`, `poly.texture`, `poly.polygon` (+ `PackedVector2Array` neuf),
`poly.material`, `light.energy`, `light.enabled`, `rb.linear_damp`, `rb.angular_velocity`, `rb.physics_material_override`,
`poly.color`, `poly.scale`, `poly.modulate.a`, `light.color`, `rb.position`, `rb.rotation`, `rb.freeze = false`,
`rb.show()`, `rb.linear_velocity` ; 1 `Dictionary` de 5 clés ; trois familles sur quatre ajoutent `LightTextures.poser`
(2 écritures de plus). Chaque écriture engage le moteur : `circle.radius` réécrit la forme côté serveur physique (déplace
la forme dans le BVH, émet `changed` vers la `CollisionShape2D`) ; `physics_material_override` se **déconnecte puis se
reconnecte** au signal `changed` du matériau partagé à chaque émission ; `freeze = false` change le mode du corps (la forme
quitte l'arbre statique du BVH) ; `show()` met en file un redessin pour le corps ET ses trois enfants, dont le
`Polygon2D` (triangulation à nouveau au flush).

---

## 2. Le reproche fait au verdict de `tools/banc_pics.gd`

**Reproche (JOU)** : le banc corrélait le STOCK de particules actives, pas le FLUX d'émission, donc « particules écartées »
(ROADMAP l. 3000, 22360) ne tient pas pour l'émission.
**Verdict : CONFIRMÉ AVEC RÉSERVE.** Le banc ne pouvait pas voir le flux ; ce que la ROADMAP a écrit est plus nuancé à
un endroit, et faux à l'autre.

**Le code** (`tools/banc_pics.gd`) : le corrélat est `"particules": _main.particle_pool.active_count()` (l. 150), pris
à chaque image ; l'écart est calculé entre la **médiane** des 1 % images lentes et la médiane de toutes (l. 248-253) ;
« suspect » seulement si `absf(ecart) >= 25.0` (l. 252). Le duel est à 150 px, chacun tire dès que `shoot_cooldown <= 0`
(l. 129-134).

**L'arithmétique de la sensibilité (PROUVÉE par les constantes du jeu).** Une touche ajoute 25 gouttes (§ 1.4), vivant
1,5 à 3,0 s (`particle_pool.gd:153`, moyenne 2,25 s). Le stock de la prise du 2026-08-25 n'est pas publié ; le banc de la
veille, MÊME échange (pompe contre pompe à 150 px, `bench_framerate.gd:108`), a relevé un pic de 122 (ROADMAP l. 34244, « identique aux trois
relevés »), soit un stock moyen ≈ 100-110. Le stock est donc une **dent de scie** d'amplitude crête-à-crête ≈ 25 (≈ 22-25 % de
la moyenne) : juste après une touche il est au sommet, soit **+12 % au-dessus de la médiane globale**. Même si TOUTES les images lentes étaient
des images d'impact, la médiane de leur stock dépasserait celle de toutes les images de ≈ 12 % — **sous le seuil de 25 %**. Le « ±6 % »
observé (ROADMAP l. 3000) est compatible avec « aucun lien » ET avec « toutes les images lentes sont des impacts, diluées
par l'irrégularité des touches ». Même raisonnement pour les nœuds : un impact crée 8 à 25 nœuds, sur quelques milliers (la réserve de
particules en compte 960, les traces jusqu'à 1 000), soit ≈ 1 %, contre un seuil de 25 % : « nœuds +2 % » ne discriminait rien non plus.

**Ce que la ROADMAP a réellement écrit.** l. 2999-3001 : « aucun corrélat ne dépasse le seuil […] La cause n'est pas dans
ce que ce banc sait compter » — **juste et prudent**. l. 22360 : « `banc_pics` a **écarté** particules, objets et nœuds » —
**plus fort que la mesure**, et c'est cette phrase qui a laissé la piste fermée. La ligne « Ponctuel et poolé — Ouvert » de
l. 34216 raisonne, elle aussi, sur le STOCK (« pic à 122 sur 200 […] rien de ponctuel n'entre dans le régime permanent »), pas sur le flux.

**Trois raisons de plus pour lesquelles ce verdict ne vaut plus pour `52a29c1`** :
1. Le relevé date du 2026-08-25, en vue de dessus. Depuis : peinture iso (une copie de plus par trace + un rendu à la
   demande, 2026-09-15), SON VISIBLE (un liseré calculé par son : 0,02-0,08 ms, ROADMAP l. 30287, 2026-09-29), lumière de
   coup, copies de traces, `FontVariation` par chiffre — tout sur le chemin de l'impact.
2. À 150 px, un seul plomb touche le corps (§ 1.2) : le banc n'exerce **jamais** les volées à 3 ou 5 plombs.
3. Le seul corrélat qui bougeait — appels de dessin +14 à +18 %, soit +20 à +36 appels sur 133-199 — a l'ordre de
   grandeur exact d'une gerbe de 25 gouttes (6 textures en alternance cassent le regroupement) + 2 taches à 2 textures +
   un `Label`. **Compatible avec « les images lentes sont des images d'impact » ; ce n'est pas une preuve.**

**Compatibilité de taille avec la queue mesurée.** Iso, vue unique, torche, sans lumière 3D : médiane 105 fps, 1 % bas 75
(ROADMAP l. 27622-27630), soit 9,5 → 13,3 ms : **+3,8 ms**. Le Mac, mesuré le 2026-08-18 en écran scindé : médiane 7,6 ms,
pire image 12,6 ms (l. 34242-34243) : **+5 ms**. Fenêtre 2560×1440 au premier plan, vue de dessus (2026-08-25) : médiane ~120, 1 % bas 61
(l. 179-180, 22359), soit 8,3 → 16,4 ms : **+8 ms** — mais à cette résolution le GPU y est pour sa part, que le banc du § 5 ne voit pas.
Le § 4 estime le surcoût CPU d'une image d'impact à 1,5-7 ms (jusqu'à 11 pour 3 plombs au corps) : même ordre.
Compatible, pas probant.

**Correctif du banc (S).** Ajouter des corrélats de FLUX par image : émissions cumulées du pool (compteur à poser dans
`emit`), delta de `AudioManager._sons_2d_lances`, delta des effectifs des groupes de traces, `get_tree().get_processed_tweens().size()`,
marqueurs « tir » / « impact » ; comparer lentes/toutes sur ces deltas (contraste attendu ≫ ×10, au lieu de +12 %).

---

## 3. Les constats

### JOU-01 — `ParticlePool.emit` : 20-50 µs par particule (ESTIMÉ), volée de 12 à 75 particules

**1. Le code.** Confirmé tel qu'écrit (§ 1.6). Extrait :
```gdscript
# particle_pool.gd:176-178, 161-162
var poly := rb.get_node("Poly") as Polygon2D
var light := rb.get_node("Light") as PointLight2D
var circle := (rb.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
...
_active.append({"rb": rb, "age": 0.0, "life": lifetime,
    "scale": rb.get_node("Poly").scale, "energy": (rb.get_node("Light") as PointLight2D).energy})
```
**2. La fréquence.** Par événement, tous modes, sur chaque pair (chacun simule ses effets) : `Bullet._spawn_hit_effects`
(2 appels : 15 + 10), `Bullet._spawn_wall_effects` (12), `Player.trigger_shoot_visuals:2704` (3 SMOKE par tir),
`Player:2056` (1 DUST toutes les 0,12 s par torche allumée, adversaire compris). Comptes corrigés au § 1.2 :
**12 (1 plomb mur) à 60 (5 plombs mur) étincelles ; 25 (1 plomb corps) à 75 (3 plombs) gouttes ; 125 seulement au contact.**
**3. Le coût.** PROUVÉ : 5 `get_node`, 18-20 écritures, 1 Dictionary, 1 `PackedVector2Array` par particule. Décomposition
ESTIMÉE (µs, bas-haut, famille BLOOD) : get_node ×5 1,5-3 ; `circle.radius` 2-5 ; texture + polygone 1-2 ; **redessin
différé du `Polygon2D`** (triangulation + `add_triangle_array`) 4-10 ; matériau + lumière 1-2 ; damp, vitesses 1-2 ;
`physics_material_override` (déconnexion/reconnexion + 2 `body_set_param`) 2-4 ; couleurs/échelle 0,5-1 ; position +
rotation + notification de transformée 2-4 ; `freeze = false` (BVH `set_static`) 2-5 ; `show()` + 4 redessins différés 3-6 ;
Dictionary + 2 get_node 1,5-3 ; aléas 1. **Total 22-48 µs** : le 30-60 de l'auditeur est le haut de ma fourchette ; je retiens
**20-50 µs, ×2,5 d'incertitude**. À mesurer : une ligne de `bench_particles`. ATTENTION à ce banc, dont les erreurs vont dans
les deux sens : (i) il tourne tout entier dans `_init`, sans jamais rendre la main à la boucle principale, donc la file des appels différés
n'est jamais vidée pendant le chronométrage — le redessin différé du `Polygon2D` et des `CollisionShape2D`, le `show()` en cascade et le flush
des transformées (≈ 8-15 µs par particule dans ma décomposition) lui **échappent** ; (ii) ses 85 émissions × 40 rafales saturent le plafond
de 200 actives dès la 3ᵉ rafale, donc la plupart des émissions recyclent (`_retire(0)` : `remove_at(0)` + `freeze = true` + `hide()`,
≈ +10 µs) et chaque rafale appelle `advance(0.1)` sur ~200 particules (≈ 1 ms), ce qui **gonfle** sa sortie. Il donne un ordre de
grandeur de la part SYNCHRONE, pas une borne. Pour la valeur « à froid » : `clear_all()` entre rafales, deux chronomètres séparés
(`emit`, `advance`) et au moins un `await process_frame` par rafale pour que le flush différé soit payé ; le banc du § 5 mesure, lui, le flush.
**4. Les invariants.** `tools/test_arena_lighting.gd:108-110` lit `pool._active[0]["rb"]` puis `get_node("Poly")`/`("Light")` ;
`tools/test_match_format.gd:214` itère `child.get_node("Light")` sur toute la réserve (la suppression du nœud lumière, (c),
casse cette suite) ; `tools/test_match_format.gd:227-239` exige plafond 200 et recyclage ; `tools/test_lumieres.gd:116`
scanne le texte du fichier pour `.texture_scale`. L'ordre des tirages `randf*` ne change pas si on se contente de ne pas
réécrire. Le NOMBRE de gouttes/étincelles est une constante de jeu (§ 1.4) : (e) « gerbe partagée par volée » change l'image,
**décision d'Adrien**. Aucun effet réseau (cosmétique local).
**5. Le statut.** Chiffrage NOUVEAU ; piste CONNUE-OUVERTE (ROADMAP l. 22421 : « l'allocation dans `_process` et
`_physics_process` ») ; la piste « particules » a été fermée à tort par l. 22360 (§ 2). Aucun recoupement avec OM.
**6. Verdict.** CONFIRMÉ AVEC RÉSERVE, **MAJEUR (à confirmer)** : plus gros poste de l'image d'impact (33-42 %, § 4).
*Correctif minimal* : (a) cacher `Poly`, `Light`, `Shape`/`circle` dans une table indexée par corps, renseignée à
`_make_particle` (plus aucun `get_node` à l'émission ni dans `advance`) ; (b) mémoriser la famille de chaque corps et ne
réécrire `circle.radius`, `poly.material`, `poly.texture`, `physics_material_override` que si elle change (le dernier
corps libéré est `pop_back` : même famille le plus souvent) ; polygone du sang précalculé par texture (6 constantes) et taille
par `poly.scale`. Gain ESTIMÉ −8 à −14 µs/particule (−30 %). (d) étalement ≤ 30-40/image : neutre pour l'information
(nombre conservé), à valider à l'œil — second temps, après mesure.
*Preuve cloud* : `godot --headless --path . --script res://tools/bench_particles.gd` (ligne « Par impact de pompe » ÷ 85 =
µs/particule, avec la réserve ci-dessus) ; puis le banc du § 5, variante `sans particules` (`pool.remove_from_group("particle_pool")`,
geste que `bullet.gd:645` prévoit) pour la soustraction.

### JOU-02 — Traces : création, éviction, copies

**1. Le code.** Confirmé. `blood_stain.gd:463-464` : `while get_tree().get_nodes_in_group("blood_stain").size() >= MAX_STAINS:
_evict_oldest()` ; `_evict_oldest` (472-479) relit le groupe et boucle sur 120 `stain._order` (Variant) ; `release()` retire du
groupe ; `:467` `call_deferred("_create_p2_duplicate")` → `duplicate()` (498) + 6 `set` ; `:320` `ShaderMaterial.new()` par tache ;
`:405-411` 2 `ResourceLoader.exists` + 2 `load` par tache ; `peinture_iso.gd:266` `source.get_property_list()` par copie.
Même structure pour `wall_impact.gd:112-126` (plafond 90) et `bullet_casing.gd:74-77, 138-144` (plafond 120).
Compte exact des lectures de groupe au plafond, par tache : `while` (1ʳᵉ lecture, tri car le groupe a changé) → `_evict_oldest`
(2ᵉ lecture, sans tri) → `release` → `while` (3ᵉ lecture, **second tri**). **2 tris + 3 copies de tableau + une boucle de 120.**
**2. La fréquence.** Par événement : 2 taches par plomb qui touche un corps (`bullet.gd:692-699`), 1 éclat par plomb qui touche
un mur (722-729), 1 douille par tir ET par cartouche rechargée (`game_state.gd:4218`, `player.gd:1256`). Corrections :
- « 10 taches par volée » : **2 (1 plomb), 6 (3 plombs, D < 93 px), 10 (contact)**, § 1.2 ;
- « toutes au plafond après ~1-2 minutes » : **faux pour le sang** (120 taches = 60 touches d'un plomb, ou 20 à 60 volées de pompe ;
  traces conservées d'une manche à l'autre mais balayées au changement de carte/mode/adversaire, `game_state.gd:1380-1397`) ;
  **vrai pour douilles (120 tirs ou rechargements) et éclats (90 plombs au mur = 18 à 90 volées)** en tir soutenu.
**3. Le coût.** Structure PROUVÉE ; chiffres ESTIMÉS (µs) : nœud + script + `setup` + `_ready` 60-120 (tache) / 30-60 (éclat) ;
copie J2 40-80 ; 3 `_draw` 10-25 ; **copie peinture iso 100-200** (`get_property_list()` ≈ 70 dictionnaires de 6 clés ≈ 60-100 µs +
`duplicate()` 40-60) ; **éviction au plafond 120-250** (2 tris de 120 nœuds ≈ 2 × 50-80, boucle 35-50, 3 copies de tableau
≈ 10). Par tache : **0,2-0,45 ms avant plafond en iso** (0,1-0,25 en 2D), **+0,12-0,25 ms au plafond**. Le « 0,4-0,8 ms »
du rapport est le haut de ma fourchette au plafond. Sur `ResourceLoader.exists`/`load` : les 9+9 PNG de sang et 16 d'éclats
font 1-2 Ko (160×130 px pour le sang, 96×96 px pour les éclats) et restent en cache tant qu'une tache les tient : 5-15 µs, pas 25-70 ; le coût de premier chargement
(34 fichiers minuscules) est négligeable. Le rendu complet de la peinture est **MESURÉ** négligeable à 25 traces
(« −0,37 à +1,1 ms », ROADMAP l. 26756-26760) ; non mesuré à 330.
**4. Les invariants.** Cinq suites lisent les groupes `blood_stain` / `blood_p2` / `wall_impact*` / `bullet_casing` / `casing_p2` :
`test_traces_carte.gd:65, 100`, `test_traces_rencontre.gd:79-80` et `test_entrainement_carte.gd:112-113` **exigent** `blood_p2 >= blood_stain`
et `wall_impact_p2 >= wall_impact` (donc des copies J2 même en entraînement) ; `test_sang_au_sol.gd:398-399` attend les copies **après UN
`process_frame`** (étaler leur création sur plusieurs images la casserait) ; `test_iso_usure.gd:180` cherche dans le TEXTE de la présentation
le garde `not (e as Node).is_in_group("wall_impact_p2")`. L'invariant
« le total ne dépasse jamais le plafond, même dans la même image » (`blood_stain.gd:459-462, 481-483`) doit survivre ;
**`balayer_les_traces_si_la_carte_change` (`game_state.gd:1391-1397`) retire les traces du groupe SANS appeler `release()`** :
une file FIFO statique doit donc se purger des nœuds invalides (`is_instance_valid`), sinon elle compte des fantômes ;
la peinture iso est indexée par original (`_copies`) ; piège « copie J2 évincée dans la frame même de sa naissance »
(`blood_stain.gd:495`) ; décision D7 (ROADMAP l. 12107-12115) : plafond 120, éviction de la doyenne AVANT dépôt — compatible
avec une file FIFO.
**5. Le statut.** Plafonds : DÉJÀ-TRANCHÉS (D7). Éviction « négligeable » (`blood_stain.gd:469-471`) : jamais mesurée.
Chiffrage de la pose complète : NOUVEAU. Aucun recoupement avec OM.
**6. Verdict.** CONFIRMÉ AVEC RÉSERVE ; **MAJEUR** quand le plafond est atteint et la peinture iso active (≈ 25-30 % de
l'image d'impact), **MINEUR** avant. *Correctif minimal* : (b) file FIFO statique `Array` + `pop_front` quand la taille atteint
le plafond, purgée des invalides, groupes conservés pour les tests et la peinture ; (c) textures en `const`/`preload`
(patron de `GOUTTES_SANG`) et **un `ShaderMaterial` partagé** (`blood_shader.gdshader` : aucune `uniform`, vérifié) ; (d)
`PeintureIso._copier` : une méthode `recopier_sur()` par classe de trace à la place de `get_property_list()` (−80 µs par
copie). Ne PAS tenter (a) « recycler le nœud » avant d'avoir mesuré le reste. Gain ESTIMÉ au plafond : −0,15 à −0,3 ms par tache.
*Preuve cloud* : micro-banc headless (patron de `bench_particles`) — `BloodStain.MAX_STAINS = 20` (c'est un `static var` fait
pour cela), poser 200 taches, chronométrer `setup` + `add_child` + le flush, avant/après plafond, avec et sans
`GameSettings.mode_iso` ; et **une mesure décisive en cinq lignes** : `get_nodes_in_group` sur un groupe de 120 après
`add_to_group`/`remove_from_group` contre le même sans modification, ×1 000 — la différence EST le coût du tri.

### JOU-03 — `Charte.courbe()` : Bézier par Newton en GDScript

**1. Le code.** Confirmé (`charte.gd:1112-1115, 1195-1224`). **Simulation exacte en doubles** (`V3_work/courbe_sim.py`, 2 001
points par courbe) : pour EXTINCTION, **8,34 appels de `_bezier_axe`/`_bezier_pente` en moyenne (max 10), plus `courbe` et
`_bezier_y` : 10-12 appels GDScript par évaluation, jamais de repli par bissection** (0 sur 2 001). ENTREE 8,6 ; SORTIE 7,7 ; REBOND 6,9.
**2. La fréquence.** **Par image rendue** (fps déplafonnés) : `ParticlePool.advance` (`particle_pool.gd:300`, une fois par
particule active), et chaque pas de chaque Tween `Charte.animer` / `animer_via` (`charte.gd:1149-1152, 1176-1181`) : `tw_reveal`
(2-4 `animer` pendant 2 s après chaque tir), chiffres de dégâts (4), fondu de balle (2), `hit_light`, vignette, caméra, traces de
poudre (GAD-02), plus `ui.gd:440` et `son_visible.gd:360` (repli). Aucun usage gameplay (grep : seulement ces trois appels directs).
**3. Le coût.** ESTIMÉ : 10-12 appels de fonctions à ~0,25-0,35 µs (13-16 opérations flottantes chacune) + enveloppe → **2,5-5 µs par
évaluation** (l'auditeur : 4-10 ; je ne vois pas de quoi atteindre 10). Par image : N particules × 2,5-5 µs = **0,05-0,1 ms à N=20
(poussière seule), 0,25-0,5 ms à N=100** ; tweens d'un échange 20-50 µs. Proportionnel aux fps.
**4. Les invariants.** La table ne change aucun nombre de jeu (affichage pur). Erreur d'une table linéaire (calcul exact) :
257 entrées → **5,4×10⁻⁵ max sur EXTINCTION** (6,1×10⁻⁵ SORTIE, 4,3×10⁻⁵ ENTREE, 2,4×10⁻⁵ REBOND), 513 entrées → 1,5×10⁻⁵ ;
la tolérance de `tools/test_charte.gd` (`_proche`, 5×10⁻⁴ par défaut ; courbe(0)=0 et courbe(1)=1 exacts par construction)
passe. Construire la table au chargement de la classe (≈ 4 × 257 × 3,5 µs ≈ 3,6 ms au démarrage), jamais au premier tir.
**5. Le statut.** NOUVEAU (ROADMAP l. 12257 décrit la courbe sans coût). `test_charte` interdit les `TRANS_*` de Godot : la
table est le seul chemin conforme.
**6. Verdict.** CONFIRMÉ, **MINEUR** (0,05-0,5 ms/image selon N : un plancher, pas une cause de queue), mais **à faire en premier** :
S, zéro risque, et il profite à GAD-02, aux tweens du jeu, au HUD. *Correctif minimal* : `static var _table` de 257 floats par courbe
+ interpolation linéaire dans `courbe()`. *Preuve cloud* : 200 000 appels `Charte.courbe(EXTINCTION, t)` (µs/appel, avant/après) ; écart
max sur 10 000 points contre l'ancienne version (≤ 1×10⁻⁴) ; `./tools/run_suites.sh` pour `test_charte`.

### JOU-04 — `advance()` : `get_node` par particule et par image ; lumières éteintes

**1. Le code.** Confirmé : `particle_pool.gd:302-303`, deux `get_node(String)` + deux écritures par particule et par image ; les quatre
familles posent `light.energy = 0.0` et `light.enabled = false` (lignes 197-198, 215-216, 235+242, 259-260) donc
`entry["energy"] == 0.0` et `light.energy = 0.0 * eased` est une écriture **vide de sens, PROUVÉE**.
**2. La fréquence.** `ParticlePool._process` → `advance(delta)`, par image rendue, pour chaque particule active (≤ 200). Les corps ne
bougent qu'à 60 Hz : à 120 i/s la moitié des mises à jour est redondante.
**3. Le coût.** ESTIMÉ : 2 `get_node` (~1 µs) + 1 écriture RS (0,3) ≈ 1,3-2 µs par particule et par image (hors courbe) ; 0,13-0,2 ms à N=100.
Les 240 `PointLight2D` éteintes ne coûtent rien par image au rendu (une lumière désactivée est écartée au premier test du
moteur) : leur coût est à l'émission (`LightTextures.poser`, `light.color`, ~2-3 µs) et en mémoire.
**4. Les invariants.** `tools/test_arena_lighting.gd:110`, `tools/test_match_format.gd:214` lisent le nœud `Light` (à adapter si on le retire) ;
`banc_lumieres` et `banc_balle_sans_lumiere` recensent les lumières ACTIVES (inchangés). Cadencer `advance` à 60 Hz : accumuler `delta`
(la killcam au ralenti passe par `Engine.time_scale`, donc par `delta`).
**5. Le statut.** NOUVEAU pour le nœud ; lumières éteintes DÉJÀ-TRANCHÉ (l. 5417-5435).
**6. Verdict.** CONFIRMÉ, **MINEUR**. *Correctif minimal* : (a) `entry["poly"]` renseigné à l'émission ; supprimer l'écriture d'énergie ;
laisser le nœud `Light` (suites intactes). *Preuve cloud* : `bench_particles` prolongé d'une boucle `advance(1/120)` à N = 20/60/122/200.

### JOU-06 + ETA-08 — Tir : tout est créé par balle

**1. Le code.** Confirmé : `game_state.gd:4182` `bullet_scene.instantiate()` par plomb ; `bullet.gd:90-156` `Line2D`, `Sprite2D`,
`ShapeCast2D`, `CircleShape2D.new()` (une ressource physique) ; en iso `miroirs_iso.gd:352-360, 389-399` crée 2 `MeshInstance3D` + 2
`ShaderMaterial` par balle à son premier suivi ; `player.gd:2722-2731` `PointLight2D` d'écho + Tween par tir ; `bullet_casing.gd` (74-77, 138-170).
**2. La fréquence.** Par tir et par plomb (pompe : 5 par tir ; 2,2 tirs/s au plus), tous modes, sur chaque pair. **Les deux rapports sont
compatibles** : JOU-06 (0,3-0,8 ms) compte TOUTE l'image d'un tir de pistolet (visuels, Tweens, son, douille) ; ETA-08 (150-250 µs, 400 au
pompe) ne compte que l'instanciation des balles et de la douille.
**3. Le coût.** ESTIMÉ : par plomb 50-100 µs en 2D (instantiate ~10 + `_ready` ~30-45 + `add_child` + événement de rejeu), +20-40 µs par
quad iso ; douille 80-150 (+120-250 au plafond de 120) ; pompe : **0,25-0,5 ms (2D), 0,45-1,0 ms (iso)** pour les cinq plombs. Pas une cause
de queue à lui seul.
**4. Les invariants.** Un `CircleShape2D` partagé est sûr (`radius` n'est jamais réglé hors défaut, grep) ; un pool de balles doit remettre à
zéro `bounces_left`, `_traverses`, `_lag_survolee`, tunnel de fumée, exceptions du cast, et les quads iso sont indexés par `get_instance_id()`
(`miroirs_iso.gd:353`) ; la killcam instancie la même scène (`game_state.gd:4384`, `is_replay`). L'écho au sol (`ground_flash`) est un objet
d'**OM4** (masques) : à coordonner avec la session OMBRES, pas à modifier ici.
**5. Le statut.** NOUVEAU pour le chiffrage ; « toute particule passe par le pool » (l. 10793) ne vise pas les balles. OM4 recoupe `ground_flash`.
**6. Verdict.** CONFIRMÉ, **MINEUR**. *Correctif minimal* : un `CircleShape2D` en `static var` ; rien d'autre avant mesure.
*Preuve cloud* : 200 × `_do_spawn_bullet` (pompe) + libération, `Performance.OBJECT_NODE_COUNT` et chronomètre, 2D puis iso.

### JOU-08 — Copies J2 créées pour une vue qui n'est jamais affichée

**1. Le code.** Confirmé : `call_deferred("_create_p2_duplicate")` inconditionnel (`blood_stain.gd:467`, `wall_impact.gd:116`, `bullet_casing.gd:78`,
`footprint.gd:96-119`). Hors écran scindé, un exemplaire sur deux est masqué par `canvas_cull_mask` (CLAUDE.md) : l'hôte ne voit que la couche 2,
le client que la couche 4.
**2. La fréquence.** Par trace posée, tous modes sauf écran scindé.
**3. Le coût.** ESTIMÉ : à la création 40-80 µs (`duplicate()` ≈ 27 propriétés lues et écrites + script + `add_child`), à l'éviction 10-30 µs ; par
image : seuls les 23 Tweens d'empreintes de copies (`footprint.gd:107-109`, `tween_property`, interpolation C++, ≈ 0,5 µs chacun) soit **≈ 12 µs/image**
(≈ 30 en comptant les douilles en glissade) — **le « −0,05 à −0,1 ms par image » est surestimé d'un facteur 3 à 8** : les traces sont des `CanvasItem`
statiques, écartés au masque. Nœuds : −165 à −330 selon plafonds.
**4. Les invariants.** **Trois suites EXIGENT les copies J2, même en entraînement** : `tools/test_traces_carte.gd:65, 100`, `test_traces_rencontre.gd:79-80`,
`test_entrainement_carte.gd:112-113` (`blood_p2 >= blood_stain`, `wall_impact_p2 >= wall_impact`) ; supprimer les copies en vue unique est donc une
modification d'assertions, pas un correctif transparent. (`test_calques_joueur.gd`, cité par le rapport, ne lit pas les traces.) La peinture iso est
indépendante des couches (elle copie l'ORIGINAL) ; `balayer_les_traces_si_la_carte_change` couvre les changements de mode. **Piège** : poser la couche de la vue
regardée sur l'original suppose de connaître cette vue à la pose (hôte : 2, client : 4, entraînement/solo : 2), et le garde-fou « tout `CanvasItem` ajouté à la
volée pose explicitement un `visibility_layer` » (ROADMAP l. 9093-9100, R3) s'applique.
**5. Le statut.** NOUVEAU ; l'idiome de duplication est assumé (l. 18196).
**6. Verdict.** CONFIRMÉ, **MINEUR**, effort M avec risque moyen. *Correctif minimal* : aucun avant les correctifs de JOU-02 ; si l'on y vient, un seul
prédicat côté `GameState` (« les deux vues sont-elles affichées ? ») lu par les quatre classes, et la couche posée à la création.
*Preuve cloud* : `OBJECT_NODE_COUNT` à saturation (plafonds abaissés par les `static var`) en vue unique ; `get_processed_tweens().size()`.

### GAD-02 — Poudre de contact : un Tween et une Bézier par trace et par image

**1. Le code.** Confirmé (`gadget_poudre.gd:213-243`) : `Charte.animer(fondu, m, "modulate:a", …, DUREE_LUEUR = 8.0)` + `tween_callback(queue_free)`
par trace ; plafond 72 par nappe (`MARQUES_MAX`), une trace tous les 26 px.
**2. La fréquence.** Par image rendue, tant que des traces vivent (≤ 8 s) ; seulement avec la **Sentinelle** (une classe sur dix), sur chaque pair.
**3. Le coût.** ESTIMÉ : lambda (≈ 1-1,5) + `is_instance_valid` + `interpoler` (`lerp` Variant ≈ 0,5) + `courbe` (2,5-5) + `set_indexed` (≈ 1) =
**4-9 µs par trace et par image** (rapport : 5-15) ; 72 traces → 0,3-0,65 ms, typique 15 traces → 0,06-0,14 ms. La borne MESURÉE de la ROADMAP (l. 20338-20353,
« de presque zéro à 0,85 ms » pour les deux gadgets ensemble) est compatible. Après 3 s la courbe EXTINCTION a fini son travail visible, les 5 s restantes
écrivent des alphas imperceptibles.
**4. Les invariants.** `test_charte` refuse les `TRANS_*` de Godot ; `test_classes`, `test_nappes_voxel`, `test_rejeu`, `test_tir_et_reserves` lisent
`traces_de_poudre` ; `replay_system.gd:225-241` relit `modulate.a`.
**5. Le statut.** NOUVEAU pour le coût ; le choix `tween_method` est expliqué (l. 12257-12262).
**6. Verdict.** CONFIRMÉ, **DOUBLON PARTIEL de JOU-03** (même cause : `Charte.courbe`), **ANECDOTIQUE** en soi ; **aucun rapport avec l'image d'impact**.
*Correctif minimal* : celui de JOU-03 (supprime ≈ 50 % du coût : 2,1-4,6 des 4-9 µs). Le « conducteur unique à 30 Hz » (effort M) n'est pas à faire avant mesure.
*Preuve cloud* : `bench_framerate --gadgets` ne se lance pas en headless ; micro-banc : 72 traces entretenues, 600 images à pas fixe, horodatage
`Time.get_ticks_usec()` autour de `_process` (nœuds-repères de priorité ±1e6), avant/après la table.

### CAR-02 — `ReplaySystem.record_frame` : purge, événements, Array neuf

**1. Le code.** Confirmé (`replay_system.gd:243-260`) : `snapshots.pop_front()` sur 450 éléments, deux boucles sur `bullet_events`, un `Array` neuf,
dès que le tampon est plein (7,5 s). **Mais `bullet_events` reçoit un événement par PLOMB** (`game_state.gd:4196-4199`, `record_bullet_fired` est DANS la boucle
des plombs), pas par tir : une volée de pompe en écrit 5.
**2. La fréquence.** 60 Hz par accumulateur (`replay_system.gd:122-130`), appelé depuis `GameState._process:2221`, tous modes tant que `recording`.
**3. Le coût.** Le rapport estime 15-25 µs de base : **contredit par la mesure, 4,2 µs** (`tools/test_rejeu.gd:593-609`, 600 appels sur un tampon de 450 donc
jusqu'à 150 `pop_front` inclus, ROADMAP l. 21387 ; 49,3 µs avec deux gadgets et 144 traces ; fausse scène, machine non précisée). Boucles : ESTIMÉ 0,4 µs par événement pour les deux (Dictionary) ;
pompe soutenu : 40-170 événements dans la fenêtre → +16-68 µs ; `pop_front` 5-15 µs (ESTIMÉ). **Au pire ≈ 70-100 µs par instantané, typique ≈ 20-30 µs** : 1-6 ms
par SECONDE de jeu, pas par image. Rien à voir avec un pic. La « marge de 139 µs » citée est une relique du relevé du 2026-08-26 (1 % bas 60,5 contre 60,0), pas
la marge actuelle.
**4. Les invariants.** `impact_frame`, `slow_mo_start_frame`, `_impact_seen` : zone piégée (Pièges connus l. 9290-9345) ; le tampon doit rester dimensionné en TEMPS ;
`tools/test_rejeu.gd`, `test_online_match.gd`, `test_accroupi.gd`, `test_carton_transition.gd`, `test_iso_camera.gd` en dépendent.
**5. Le statut.** NOUVEAU ; la cadence 60 Hz est DÉJÀ-TRANCHÉE (`replay_system.gd:11-21`).
**6. Verdict.** CONFIRMÉ AVEC RÉSERVE, **ANECDOTIQUE**. *Correctif minimal* : aucun sur les événements (killcam = zone la plus piégée du dépôt, gain < 0,1 ms) ;
au plus `@onready` des deux `MuzzleFlash` (−1 µs). *Preuve cloud* : prolonger `test_rejeu` (tampon plein, 0 / 40 / 160 événements) — il imprime déjà « MESURE record_frame ».

### AUD-03 — `play_sfx_2d` : 8 `famille_de`, rayons doublés

**1. Le code.** Confirmé, comptes exacts : `famille_de` évaluée aux lignes 1616 (`elif`, absent pour un tir), 1624, 1625 (via `niveau_relatif_de` : l'argument par
défaut de `Dictionary.get` est évalué même si la clé existe, `_niveau_dose` étant vide en jeu), 1626 (`portee_courante` : 2 fois, directe + `portee_relative_de`),
`_annoncer` (« famille »), 1635 (`priorite_de`), 1684 (`_fam`) = **8** (7 pour un tir). Vue unique : `GameState._sur_son_localise` (6194-6213) lance `part_occultee_entre`
(3 rayons) PENDANT `_annoncer`, puis `play_sfx_2d:1664` appelle `part_occultee(pos)` (3 rayons) pour la même paire (source, joueur local = porteur de l'oreille) :
**6 rayons au lieu de 3, PROUVÉ** (en écran scindé `part_occultee` rend 0 sans rayon). `_occupations` lit `playing` par `get()` dynamique ×16 ; `occultation_fumee`
copie le groupe `fusees` à chaque son (1 µs, négligeable).
**2. La fréquence.** Par son positionnel, dans le chemin des tirs (physique) : **1 son de tir par volée, 1 `wall_impact` PAR PLOMB au mur, 2 sons PAR PLOMB au corps
(`play_hit` + `play_breath_hit`)** — il n'y a aucun dédoublonnage par image (`audio_manager.gd:1926-1927`).
**3. Le coût.** ESTIMÉ 80-250 µs par son : `famille_de` 1,5-2,5 µs × 8 (chaîne de `get_file`/`get_basename`/`rsplit`) = 12-20 ; rayons 6 × 4-6 µs = 24-36 ;
liseré (`recevoir` + `percevoir` + `vie_de`) 30-100 (`vie_de` : 0,02-0,08 ms, ROADMAP l. 30287, 26 à 160 pas de 10 ms ; ignoré si le son est à moins de 24 px
du regardeur, `son_visible.gd:288`) ; voix + `play()` 20-40 ; Dictionnaires d'annonce et de témoin 10. Le « 150-300 » du rapport est le haut ; JOU
(60-120 µs pour un pas entier) en est le bas. Gain des quatre propositions : **≈ 25-45 µs par son** (rapport : 50-100) : −10-18 (une classification au lieu de huit),
−12-18 (un seul jeu de rayons), −3 (`playing` typé), −1 (fusées) ; l'ordre des gardes n'économise les rayons que pour les sons rejetés (hors portée, famille muette, trop près),
rares dans l'image d'impact.
**4. Les invariants.** `famille_de` reste l'UNIQUE fonction de classification (leçon l. 10035-10041) : passer la famille aux tables, ne pas la recopier ;
`tools/test_dosage_audio.gd`, `test_pool_sfx.gd`, `test_son_visible_jeu.gd` (signature de `recevoir`), `test_enveloppes_sons.gd` ; l'occlusion en vue unique
suit `oreille_suit` (CLAUDE.md) ; ne pas toucher aux trois gestes de l'oreille.
**5. Le statut.** Principe « une requête par son » ACCEPTÉ (l. 15639-15645) ; le doublon en vue unique NOUVEAU.
**6. Verdict.** CONFIRMÉ AVEC RÉSERVE, **MINEUR** isolément (0,025-0,045 ms par son, 0,12-0,23 ms par volée à 5 plombs au mur). *Correctif minimal* : `var fam := famille_de(…)`
une fois en tête de `play_sfx_2d`, passé aux tables (surcharges prenant la famille, signatures statiques conservées) ; réutiliser la part occultée de l'oreille quand
le regardeur est le porteur de l'oreille. *Preuve cloud* : 1 000 × `play_wall_impact` dans un rappel de physique, avec / sans `occlusion_active`, avec / sans
`son_localise` connecté (soustraction des rayons et du liseré) ; compteur `_sons_2d_lances`.
*Levier non listé* (décision d'Adrien, pas une optimisation neutre) : cinq `wall_impact` dans la même image et à quelques pixels (même échantillon, pitch ±8 %) ne
s'entendent pas comme cinq ; un regroupement par image (un son, niveau relevé) économiserait 4 × 80-250 µs et 4 voix sur 16 par volée au mur. Le banc de mixage
(`tools/banc_audio.tscn`) a dosé ces sons plomb par plomb : à ré-écouter.

---

## 4. Décompte de l'image d'impact d'une volée de pompe (vue iso, hors GPU et pilote)

**Hypothèses.** Multiplicités PROUVÉES (§ 1.2-1.3). Coûts unitaires ESTIMÉS (µs, bas-haut) : son 80-250 ; particule 20-50 (tout compris) ; `advance` d'une
particule neuve 4-8 ; physique d'un corps neuf (première intégration + synchro) 2-6 (À MESURER) ; `WallImpact` 30-60 ; `BloodStain` 60-120 ; copie J2 40-80 ;
copie peinture iso 104-208 ; chiffre de dégâts 150-600 (JOU-05, NON vérifié ici, FontVariation neuf par plomb) ; `take_damage` + `rpc_update_hp` 71-176 (dont 0-40 pour
l'envoi du RPC fiable en hôte, À MESURER) ; fondu de balle 15-30. Le total est la somme des bornes : c'est une enveloppe, pas une loi de probabilité. Les plafonds de
traces sont supposés non atteints sauf mention. Le coût GPU (appels de dessin +25 à +60, ombre de `hit_light` — OM6, rendu de la peinture iso — MESURÉ négligeable à
25 traces) et le temps du pilote GL du Mac ne sont PAS comptés.

### 4.1 Mur — 5 plombs touchent (canon à moins de 88 px du mur) : **2,9-7,1 ms**

| Travail | Multiplicité (PROUVÉ) | ms | Source |
|---|---|---|---|
| sons `wall_impact` | 5 | 0,40-1,25 | AUD-03 |
| étincelles `emit(SPARK)` | 60 | 1,20-3,00 | JOU-01 |
| `WallImpact` (nœud + `setup`) | 5 | 0,15-0,30 | JOU-02 |
| copie J2 différée | 5 | 0,20-0,40 | JOU-02 / JOU-08 |
| `_draw` ×2-3 | 5 | 0,03-0,07 | JOU-02 |
| copie peinture iso | 5 | 0,52-1,04 | JOU-02 |
| fondu de balle (Tween + 2 `animer`) | 5 | 0,07-0,15 | JOU-03 |
| `advance` des 60 neuves (cette image) | 60 | 0,24-0,48 | JOU-03/04 |
| physique des 60 corps neufs | 60 | 0,12-0,36 | À MESURER |
| **Total** | | **2,94-7,08** | |

Variantes : au plafond d'éclats (90) +0,5-1,25 → 3,4-8,3 ; en vue de dessus (sans peinture) 2,4-6,0 ; 3 plombs 1,8-4,3 ; 1 plomb 0,6-1,4.
Parts : particules 41-42 %, traces et copies 26-31 %, sons 14-18 %, `advance` + physique 12 %.

### 4.2 Corps — 1 plomb touche (D de 93 à 217 px ; le cas des bancs) : **1,5-3,8 ms**

| Travail | Multiplicité (PROUVÉ) | ms | Source |
|---|---|---|---|
| sons `play_hit` + `play_breath_hit` | 2 | 0,16-0,50 | AUD-03 |
| gouttes `emit(BLOOD)` 15 + 10 | 25 | 0,50-1,25 | JOU-01 |
| `BloodStain` (nœud + `setup` + `exists`/`load` ×2) | 2 | 0,12-0,24 | JOU-02 |
| copie J2 | 2 | 0,08-0,16 | JOU-02 / JOU-08 |
| `_draw` ×3 | 2 | 0,02-0,06 | JOU-02 |
| copie peinture iso | 2 | 0,21-0,42 | JOU-02 |
| chiffre de dégâts | 1 | 0,15-0,60 | JOU-05 (hors liste) |
| `take_damage` + `rpc_update_hp` (Tweens ×3, `hit_light`, rumble, télémétrie) | 1 | 0,07-0,18 | OM6 pour l'ombre |
| fondu de balle + maths du plomb | 1 | 0,02-0,04 | — |
| `advance` + physique des 25 neuves | 25 | 0,15-0,35 | JOU-03/04 |
| **Total** | | **1,49-3,80** | |

Variantes : au plafond de taches (120) +0,24-0,5 → 1,7-4,3 ; vue de dessus 1,3-3,4 ; **3 plombs (54 ≤ D < 93 px) 4,5-11,4 ; 5 plombs (contact) 7,4-19,0**.
Parts (1 plomb) : particules 33 %, taches et copies 23-29 %, sons 11-13 %, chiffre 10-16 %, `advance` + physique 10 %.
Un plomb tué ne tue qu'une fois : les plombs suivants d'une volée mortelle frappent le cadavre comme un mur (`bullet.gd:221, 280-286`).

### 4.3 Ce que les deux décomptes disent ensemble

- **Les particules sont le premier poste (≈ 40 %), les traces et leurs copies le second (≈ 25-30 %), les sons le troisième (≈ 15 %).** Aucun de ces postes
  n'explique à lui seul une image à 16 ms ; c'est leur coïncidence dans la même image, ajoutée au plancher permanent (JOU-03/04 : ≈ 0,3-0,8 ms par image
  pendant un échange), qui le ferait — hypothèse, que le banc du § 5 doit confirmer ou infirmer.
- Les trois correctifs « S » (JOU-01 a+b, JOU-02 b+c+d, AUD-03) retirent ESTIMÉ −8 à −14 µs/particule (≈ −0,5 à −0,85 ms sur le mur à 5 plombs), −0,08 ms par copie
  peinture (≈ −0,4 ms) et −0,13 à −0,23 ms de sons, −0,1-0,3 ms par tache au plafond : **de l'ordre de −20 à −35 % de l'image d'impact**. Pour aller plus loin il faut changer ce qu'on fait (étaler dans le temps
  les copies J2 et peinture, invisibles pendant 1-3 images et déjà différées d'une image par le code — au-delà d'une image, `test_sang_au_sol.gd:398`, qui attend les copies
  après un `process_frame`, est à adapter ; regrouper les sons), pas comment on le fait.
- **Compatibilité avec la queue mesurée** : médiane iso 9,5 ms, 1 % bas 13,3 ms (+3,8 ms, l. 27622-27630) ; surcoût estimé d'une image d'impact 1,5-7 ms (jusqu'à 11 pour
  3 plombs au corps). Compatible, **pas prouvé** : c'est exactement ce que le banc du § 5 doit dire.

### 4.4 Image du tir (si elle coïncide avec l'image d'impact, § 1.5) : +0,8-1,7 ms iso (0,6-1,3 en 2D)

5 plombs instanciés 0,25-0,5 (+ 10 quads iso 0,25-0,45) ; douille 0,08-0,15 (+0,12-0,25 au plafond) ; `trigger_shoot_visuals` (3 Tweens, lumière d'écho,
éclat de bouche, 3 grains de fumée) 0,25-0,6 ; son de tir 0,08-0,25 ; `_flash_de_tir`, événements de rejeu, rumble 0,03-0,06. Chiffres ESTIMÉS (JOU-06 / ETA-08).

### 4.5 Ce qui est PROUVÉ, ESTIMÉ, À MESURER

PROUVÉ : toutes les multiplicités (plombs, particules, nœuds, sons, Tweens), le fait que tout tombe au même tick, l'absence de toute limite par image, les
comptes de `famille_de` et de rayons, le nombre d'appels GDScript de `courbe`. MESURÉ (ROADMAP) : `record_frame` 4,2 µs ; `vie_de` 0,02-0,08 ms ; rendu de peinture
forcé à chaque image −0,37..+1,1 ms. ESTIMÉ : tout coût unitaire de ce § 4 (incertitude dominante : particule ×2,5, son ×3, chiffre de dégâts ×4, copie peinture ×2).
À MESURER : physique et synchro des corps neufs, envoi du RPC, `FontVariation`, GPU et pilote.

---

## 5. Protocole headless — « le banc de l'image d'impact » (à écrire : `tools/banc_image_impact.gd`)

**But** : la durée CPU de l'image d'impact d'une volée de pompe, par scénario, avant/après chaque correctif, sans fenêtre ni GPU.
**Lancement** (cloud, conteneur libre — `tools/cadence_cloud/attendre_libre.sh`, `porte.py` pour refuser une prise bruitée) :

```
godot --headless --path . --fixed-fps 60 --script res://tools/banc_image_impact.gd -- \
      --volees=60 --scenario=mur|corps --distance=60 --iso=1 --seed=7 --plafond=0|1
```

**Pas fixe, horodatage au lieu de `delta`.** `--fixed-fps 60` avec la physique à 60 Hz (défaut du projet) donne exactement un tick par image et un `delta` CONSTANT : le temps
d'image ne se lit donc jamais dans `delta` (ni dans `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS`, lissés par le moteur — ROADMAP l. 3029-3041 — donc inutilisables par
image). Le script `extends SceneTree` relève `Time.get_ticks_usec()` au début de sa `_physics_process` et de sa `_process` (que `MainLoop` appelle AVANT les nœuds de la phase) :
`phys_us = t(process_k) − t(physique_k)` (nœuds de physique + PAS du serveur de physique, donc la première intégration des corps neufs, + flush différé de fin de tick, donc les copies
J2 et peinture), `proc_us = t(physique_k+1) − t(process_k)` (nœuds, Tweens, flush différé, dessin factice), `image_us = phys_us + proc_us`. Ne PAS compter sur `RenderingServer.frame_post_draw` en headless (non garanti). Pièges déjà payés par le dépôt : sortir par
`NetworkManager.quit_game(code)` (arrêt EOS) ; `GameSettings.pilotage_externe = true` ; `Engine.max_fps = 0` ; le « jamais `--fixed-fps` » de `prise.sh` vise le banc fenêtré sous
llvmpipe (où il fausse le temps d'image), pas un banc horodaté en headless.

```gdscript
extends SceneTree                       # tools/banc_image_impact.gd — squelette, non écrit dans le dépôt
var _t_phys := 0 ; var _t_proc := 0 ; var _images: Array[Dictionary] = []
func _physics_process(_d: float) -> bool:
    var t := Time.get_ticks_usec()
    if not _images.is_empty():                                   # ferme l'image k-1
        _images[-1]["proc_us"] = t - _t_proc ; _images[-1]["image_us"] = t - _t_phys
    _t_phys = t
    _images.append({"tick": Engine.get_physics_frames(), "noeuds": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
        "particules": _pool.active_count(), "sons": AudioManager._sons_2d_lances, "traces": _effectifs_des_groupes()})
    return false
func _process(_d: float) -> bool:
    var t := Time.get_ticks_usec() ; _images[-1]["phys_us"] = t - _t_phys ; _t_proc = t
    return false
# Le tir part du _physics_process d'un NOEUD assistant (cf. Boucle) : _tireur._physics_process → gs._do_spawn_bullet(...)
```

**Montage** (repris de `tools/test_calques_joueur.gd:36-60`, `tools/banc_balle_sans_lumiere.gd:48-90`, `tools/test_tir_et_reserves.gd:952-967, 1005-1025`) : instancier
`main.tscn`, `ui._intended_mode`, `_main._on_replay_requested()`, attendre `round_active and countdown_left <= 0` ; vue unique (`vp2.get_parent().hide()` +
`_accorder_rendu_aux_vues()`) ; `GameSettings.mode_iso = iso` AVANT la manche et refus du chiffre si `Presentation3D.instance()._actif` est faux (garde de
`bench_framerate.gd`, `_images_hors_iso`) ; pompe choisie ; joueurs immobiles (`set_physics_process(false)`) ; **mur de test** `StaticBody2D` sur `WALL_LAYER` à
`distance` px du canon (`_mur_de_test`, attendre DEUX `physics_frame` avant le premier tir) ; scénario corps : `p2` posé à D, `hp = 100` à chaque tir.

**Boucle.** Toutes les 60 images (1 s, laisse les Tweens et le stock retomber), depuis le `_physics_process` d'un **nœud assistant** (ajouté à la racine après `main`) :
`gs._do_spawn_bullet(p1, muzzle, rot, pompe)`. ATTENTION : jamais depuis le script de boucle principale, qui tourne avant TOUS les nœuds — les plombs seraient alors dans
l'arbre avant la passe et traités dans le même tick, ce que le jeu ne fait pas (le tir y part de `Player._physics_process`, en cours de passe) et qui fausserait justement
la question du § 1.5. Dans une image de physique, les rayons d'occlusion sonores sont lancés (`Engine.is_in_physics_frame()`), comme en jeu.
Relevé par image : `image_us`, `phys_us`, `proc_us`, `Engine.get_physics_frames()`, `OBJECT_NODE_COUNT`, `pool.active_count()`,
`AudioManager._sons_2d_lances`, effectifs des groupes `blood_stain` / `wall_impact` / `bullet_casing` / `*_p2`, `get_tree().get_processed_tweens().size()`.
Marqueurs : image du tir (spawn), première image où une trace ou une particule apparaît (impact) → **lève la question du § 1.5** (même tick ou suivant).
Témoin : tir « dans le vide » (aucun mur à moins de 180 px) — coût du tir sans impact. Fond : médiane des images hors de [spawn, spawn+4].

**Sorties.** `VOLEE n f_tir f_impact image_us phys_us proc_us particules+ noeuds+ sons+ traces+` par volée, puis `IMPACT : médiane / p90 / max`, `FOND : médiane`,
**`SURCOUT = médiane(images d'impact) − médiane(fond)`** et la même chose pour l'image du tir. Plus les 5 images suivantes cumulées (coûts qui débordent).
**Auto-contrôle (le banc doit prouver qu'il exerce ce qu'il annonce)** : le nombre d'éclats posés doit égaler la prédiction du § 1.2 pour la distance choisie (5 / 3 / 1), le delta de
particules 12 × n (mur) ou 25 × n (corps), le delta de sons n (+ 1 de tir) ou 2n ; sinon ✗ et le chiffre est refusé.

**Matrice.** distance au mur {40 → 5 plombs, 120 → 3, 165 → 1} ; corps {D = 50, 75, 150} ; iso {0, 1} ; plafonds {loin, atteints — `BloodStain.MAX_STAINS`, `WallImpact.MAX_ECLATS`,
`BulletCasing.MAX_CASINGS` abaissés, ce sont des `static var` faits pour cela}. Écarter les 5-10 premières volées de la médiane (premier usage : shaders, FontVariation,
textures) mais les imprimer à part.

**Attribution par soustraction, dans le même processus** (variantes qui doivent chacune prouver qu'elles ont retiré quelque chose, compteur à l'appui) :
`sans particules` (`pool.remove_from_group("particle_pool")`, `bullet.gd:645` rend alors le geste silencieux), `sans traces` (`gs.arena` détaché le temps de la volée,
`bullet.gd:686-688, 720-721`), `sans liseré` (déconnecter `AudioManager.son_localise`), `sans rayons` (`occlusion_active = false`), `sans iso` (`mode_iso = false`). Micro-bancs de
confirmation : `bench_particles` (µs/particule, § JOU-01), 200 000 × `Charte.courbe` (JOU-03), 1 000 × `get_nodes_in_group` après modification (JOU-02), 1 000 × `play_wall_impact`
(AUD-03), 200 × `_do_spawn_bullet` (JOU-06), `test_rejeu` prolongé (CAR-02).

**Avant / après.** Deux arbres (le commit courant et le correctif) alternés ABBA, trois tours, même graine ; on compare `SURCOUT` médian et p90 (pas des moyennes brutes), en
donnant la dispersion — le dépôt a déjà vu un même montage donner un 1 % bas de 81 puis de 97 (ROADMAP l. 34155). Un écart inférieur au plancher de bruit du poste (0,25 ms sur une
médiane, l. 34151) ne se lit pas.

**Ce que ce banc ne mesure PAS** : le GPU, le coût CPU du pilote GL sur Mac (enregistrement des appels de dessin — le moteur de rendu est factice en headless), le thread
audio, la différence de vitesse entre l'x86 du cloud et le M3 (rapports avant/après seulement, jamais de millisecondes à comparer à celles du Mac). Complément fenêtré sous
llvmpipe, pour le seul compteur d'appels de dessin (indépendant du matériel) : `banc_pics` avec les corrélats de FLUX du § 2.

---

## 6. Questions ouvertes (qu'une mesure ou Adrien seuls tranchent)

1. Le coût par particule (20-50 µs ?) : une ligne de `bench_particles`, avec ses réserves. Tout le reste en dépend.
2. L'image d'impact est-elle l'image du tir ? (§ 1.5) Si oui, §§ 4.1-4.2 + 4.4 s'additionnent.
3. Un `FontVariation` neuf par chiffre de dégâts coûte-t-il 0,15 ou 0,6 ms (JOU-05, hors de ma liste) ? C'est le poste le plus incertain du corps.
4. Étaler dans le temps les copies J2 et peinture (invisibles 1-3 images) : acceptable pour l'identité visuelle ? Regrouper les `wall_impact` d'une même volée en un son ?
5. Après correctifs, la queue (1 % bas) bouge-t-elle ? Si l'image d'impact tombe de 7 à 5 ms et que le 1 % bas ne bouge pas, la cause est ailleurs (GPU, pilote) : c'est le
   second résultat utile du banc.
