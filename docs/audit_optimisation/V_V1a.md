# V1a — « Le coup fatal » : vérification contradictoire

Commit `52a29c1` (0.8.3 + SOLO S12). **Lecture seule, Godot non lancé.** Rôle : contradicteur.
Constats examinés : ETA-01 + CAR-04 + GAD-10 + MEN-12 (journal), ETA-02 + HUD-08 (premiers dessins), MEN-07 (affiche de fin),
JOU-05 + MEN-10 (`FontVariation`). Rapports lus : `06_ETA`, `14_CAR`, `07_GAD`, `10_MEN`, `09_HUD`, `05_JOU`.
Aides de calcul écrites hors dépôt : `audit/v1a_work/taille_fiche.py`, `repartition.py`, `comptes.py`, `versions.py` (taille d'une
fiche du journal, reconstituée clé par clé depuis `MatchRecord.build`, `ConditionsDeMatch.resume/machine`, `TelemetrieGadgets.resume`).

Convention : **PROUVÉ** = lu dans le code ; **ESTIMÉ** = raisonné, non mesuré ; **À MESURER** = je n'ai pas de base.
Les ordres de grandeur ESTIMÉS sont à lire entre ×0,4 et ×2,5.

---

## 0. Verdicts

| ID(s) | verdict | sévérité (auditeur → corrigée) | coût corrigé |
|---|---|---|---|
| ETA-01 + CAR-04 + GAD-10 + MEN-12 | CONFIRMÉ AVEC RÉSERVE | MAJEUR / MINEUR / ANECDOTIQUE / ANECDOTIQUE → **MINEUR** | fiche 2,07 Ko, 200 fiches = 0,41 Mo ; ESTIMÉ ≈ 4 ms à 20 fiches, ≈ 40 ms au plafond (15-100), refait une fois à l'accusé en ligne ; `resume()` 1-3 ms (≤ 15) |
| ETA-02 | CONFIRMÉ AVEC RÉSERVE (portée corrigée : deux des items ne valent qu'en `--2d`) | MAJEUR → **MINEUR** | À MESURER (aucune mesure de compilation canvas dans le dépôt) |
| HUD-08 | CONFIRMÉ AVEC RÉSERVE | MINEUR → **MINEUR** (le seul item « en jeu » du lot : voile plein au premier éblouissement) | À MESURER |
| MEN-07 | CONFIRMÉ | MINEUR → **ANECDOTIQUE** | ESTIMÉ 25-50 ms, une fois par match, monde figé |
| JOU-05 + MEN-10 | RÉFUTÉ pour la conséquence alléguée (glyphes ré-rastérisés), sous réserve du test d'égalité des RID (§ 5.4) ; l'allocation est vraie | MINEUR → **ANECDOTIQUE** | ESTIMÉ 10-30 µs par appel ; aucun gain chiffrable |

---

## 1. L'image du kill, dans l'ordre (commun à tous les blocs)

Chaîne synchrone, hôte ou local (le client passe par `rpc_end_round`, voir plus bas) :

```
Bullet._physics_process (hôte)
 → Player.take_damage                                   player.gd:2817
   → rpc_update_hp.rpc(...)  @rpc call_local → exécuté À L'INSTANT   player.gd:2875
      → gs.noter_pv_perdus (télémétrie) ; hp = new_hp ; die(killer)   player.gd:2897-2907
         die()                                           player.gd:2945
           ColorRect + ShaderMaterial(SHADER_DEATH_FLASH) + tween      2974-3002
           LabelSettings + Charte.police_display + geometrie_du_bandeau
             + _poser_bandeau_fatal (une fois par vue AFFICHÉE)         3024-3058
           call_group("game_state", "player_died", ...)                3077
            → GameState.player_died                      game_state.gd:4409
              → rpc_end_round.rpc(w)  call_local         game_state.gd:4418
                → _do_end_round                           game_state.gd:4426
                    _conditions.arreter()                 4435
                    _archive_match_result(winner_id)      4460   <-- journal
                    ui.set_countdown / force_close_pause  4466-4469
                    AudioManager.* (musique, sting, voix) 4471-4499
                    await RenderingServer.frame_post_draw 4515   <-- PREMIER await
```

* Aucun `await` entre `_do_end_round` (4426) et 4513/4515 : **l'archive est bien dans l'image du kill, avant le premier `await`** (PROUVÉ).
  `frame_post_draw` n'est émis qu'après le dessin ; en headless la branche 4512-4513 attend `process_frame`.
* Le commentaire `player.gd:2886-2888` le sait : `die()` « archive le match de façon synchrone chez l'hôte et en local ». C'est un fait
  de conception documenté (la télémétrie doit précéder l'archive), son COÛT n'a jamais été évalué.
* Client : `rpc_update_hp` (call_local) exécute `die()` ; `player_died` rend la main tout de suite (`game_state.gd:4412-4413`) ;
  `rpc_end_round` (même canal fiable, souvent le même paquet) lance `_do_end_round` : **même chaîne, même archive**, à l'image où le
  paquet est traité (début d'image, avant `_process`).
* Cas `winner_id == -1` (temps écoulé, `game_state.gd:2159-2163`) : aucun `await` avant la fin de la fonction — archive,
  `show_game_over` et affiche dans la même image ; pas de kill, pas un moment décisif.
* Ce qui suit l'image du kill : `frame_post_draw` → `UPDATE_DISABLED` sur les vues → gel de **0,15 s** en temps réel
  (`KILL_FREEZE_DURATION`, 236 ; 4515-4520) → 1,5 s de sang → killcam → tampon → 2 s → affiche (≈ 7 à 11 s après le kill hors égalité).

---

## 2. Bloc A — ETA-01 + CAR-04 + GAD-10 + MEN-12 : le journal des matchs

### 2.1 Le code

```gdscript
# game_state.gd:4740-4774 (_archive_match_result) — tout est synchrone
var conditions := _conditions.resume()                       # tri + boucles GDScript sur N durées d'image
var gadgets := _telemetrie.resume(...)
var record := MatchRecord.build(..., conditions, gadgets)    # 2 duplicate(true)
dernier_enregistrement = record
if archiver_les_matchs:                                      # défaut true (game_state.gd:391)
    MatchRecord.append_to_history(record)                    # <-- I/O
_report_to_ranking(winner_id, forfeit, conditions, gadgets)  # <-- file d'envoi (en ligne, identité prête)

# match_record.gd:247-251, 257-271, 275-285
static func append_to_history(record, path):
    var history := load_history(path)                  # file_exists + open + get_as_text + JSON.parse_string (fichier ENTIER)
    history.append(record)
    history = cap(history, HISTORY_MAX)                # 200 ; slice (copie de 200 références) au plafond
    return history if _write_history(history, path) else []
static func _write_history(history, path):             # open .tmp + JSON.stringify(history, "\t") + store_string + close + rename
# match_record.gd:232-243
static func mark_reported(match_id, path):             # load_history + boucle + _write_history : REFAIT TOUT
```

```gdscript
# conditions_de_match.gd:122-146 — N = images rendues de la manche (compte à rebours compris)
var triees := durees.duplicate(); triees.sort()        # natif
for v in triees: total += v                            # boucle GDScript, N tours ; idem sur _rtt (en ligne) avec maxf
```

```gdscript
# ranked_identity.gd:274-285, 328-341, 345-350, 513-533 — en ligne, identité READY seulement
func report_match(...): if state != State.READY or match_id.is_empty(): return   # sinon rien, donc pas de mark_reported
    _report_queue.append(payload); _drain_reports()    # _copy_id_token (appel EOS local) + JSON.stringify(payload) compact + HTTPRequest.request
func _on_report_completed(result, code, payload):      # 200 ET 4xx
    _settle_front() -> MatchRecord.mark_reported(match_id)   # relecture + réécriture complètes
```

Les extraits cités par les quatre auditeurs existent et font ce qu'ils disent (PROUVÉ).

### 2.2 Fréquence, appelants remontés

* `append_to_history` ← `game_state.gd:4771` ← `_archive_match_result` ← **`_do_end_round:4460`** (`player_died:4420` en local ; `rpc_end_round:4424`
  chez tous les pairs ; `_process:2159/2163` au temps écoulé) et **`_archive_forfeit:4874`** (800, 982, 1246, 6365, 6494, 6507 : retours au menu /
  déconnexions). Une fois par match et par pair (BO1 : `match_over` toujours vrai, 4444-4446). Jamais par image.
* `mark_reported` ← `ranked_identity.gd:350` ← `_settle_front` ← `_on_report_completed` (200 et 4xx). Une fois par match **en ligne, identité READY** ;
  jamais en local, en entraînement, ni sans profil.
* Lectures du journal hors fin de match : `_peut_etre_la_soiree` (`game_state.gd:4719-4727`, appelé à 6378 au retour au menu, tant que la carte de
  soirée n'est pas montrée : seuil 3 matchs retenus, `bilan_de_soiree.gd:35` → les deux premiers retours de la séance) ; `ScreenHistory.refresh`
  (2 lectures, au lancement : voir 2.5) ; `replay_local_journal` (1 lecture, à l'identification) ; F6 (`ui.gd:1997`, 1 lecture).
* **Compte exact autour d'un match en ligne (identité READY), par pair** : image du kill = 1 lecture-analyse + 1 `JSON.stringify` indenté + 1 écriture
  (+ rename) + 1 `stringify` compact du rapport (≈ 2 Ko) ; accusé du serveur (ESTIMÉ 0,2 à ~1 s plus tard : RTT + fonction Edge ; donc plutôt pendant le gel / les 1,5 s de sang que « à une
  image quelconque de la killcam ») = 1 lecture-analyse + 1 `stringify` + 1 écriture ; retour au menu = 1 lecture (matchs 1 et 2 de la séance).
  Hors ligne / entraînement : le premier jeu seulement.

### 2.3 Le coût

**Taille du fichier au pire cas** (reconstituée hors Godot, mêmes clés et profondeur, format `JSON.stringify(h, "\t")` à clés triées) :

| | octets |
|---|---|
| fiche v6 (une entrée dans le tableau) | **2 075** (81 paires clé/valeur : 19 de premier niveau, 13 + 18 pour `conditions` et sa `machine`, 5 + 2×13 pour `gadgets`) |
| dont `gadgets` | 830 (**40 %** — GAD-10 demandait « ≈ 40 % ? non vérifié » : oui) |
| dont `conditions` (avec `machine` ≈ 463) | 794 (38 %) |
| fiche v5 / v4 | 1 245 / 451 |
| **200 fiches v6 (plafond `HISTORY_MAX`, match_record.gd:93)** | **414 602 (0,41 Mo)** ; compact sans indentation 324 201 (−22 %) |
| 20 fiches | 41 462 (41 Ko) |

Les auditeurs disaient 0,38 Mo (CAR-04) et 375 Ko (ETA-01) : même ordre ; la fiche réelle varie avec `os_version`, `gpu_pilote`, `mode` (±10 %).
MEN-12 écrit « ≈ 45 clés par entrée » : c'est 45 NOMBRES ; il y a 81 clés. Un journal mixte (anciennes versions plus petites) tombe vers 0,2-0,3 Mo.
**Le plafond est atteint en pratique** : la ROADMAP note que l'historique d'Adrien était déjà plein à 200 le 2026-09-10 (l. 5020, 5043) — le « pire
cas » est le cas courant d'un joueur assidu.

À 200 fiches v6 : 16 200 clés, 5 200 valeurs chaîne, 9 000 nombres, 1 000 booléens, ≈ 223 000 caractères de chaînes à (dé)sérialiser.

**Temps** (aucune mesure : le moteur n'a pas été lancé ; modèle par jetons, calé sur le comportement connu de `JSON` de Godot 4 — analyseur
récursif qui construit les chaînes caractère par caractère, sérialiseur qui concatène des `String` temporaires et passe 8 `replace` dans `json_escape`) :

| poste | 20 fiches | 200 fiches (plafond) |
|---|---|---|
| `load_history` (lecture + `JSON.parse_string`) | ≈ 1-2 ms | ≈ 12-25 ms |
| `JSON.stringify(h, "\t")` + écriture + rename | ≈ 2-3 ms | ≈ 20-30 ms |
| **`append_to_history`** | **≈ 4 ms** (2-10) | **≈ 40 ms (15-100)** |
| `mark_reported` (idem, à l'accusé) | ≈ 4 ms | ≈ 40 ms |
| `resume()` (N = 6 000-15 000 : duel de 1-2 min à 100-150 i/s) | 0,5-1,5 ms (+ 0,5-1,5 ms de boucle `_rtt` en ligne) | idem ; pire cas 5 min à 300 i/s (N = 90 000) ≈ 9-15 ms |

Divergences entre auditeurs, tranchées : ETA-01 (10-100 ms au plafond) tient ; CAR-04 (10-30 ms) et GAD-10 (« quelques ms à une vingtaine ») sont
bas au plafond ; MEN-12 (« quelques ms par lecture ») est bas ; le « 1 à ~20 ms » de `resume()` (ETA-01) et le « 2-25 ms » (CAR-04) sont hauts pour le
cas typique. Sur Windows, la création + renommage d'un fichier peut être ralentie par l'antivirus : non mesurable ici.

**Effet réel sur l'image** : le travail retarde la PRÉSENTATION de l'image d'impact de X ms (hôte : la même image ; client : l'image où le paquet est
traité), puis un gel volontaire de 150 ms fige l'image (vue iso par défaut : `presentation_3d.gd:803-805`, « la lightmap ne bouge plus, la 3D non plus »). Il n'y a donc pas de saccade dans un mouvement continu, et rien n'est décidé après le kill :
**aucun effet d'équité**, aucun effet sur le 1 % bas (le relevé s'arrête à 4435, avant — l'argument d'ETA-01 est exact). Le second coup (accusé) tombe
pendant le sang / le noir (tweens et particules vivants) : un à-coup de ≈ 40 ms au plafond, visible à qui regarde.

### 2.4 Invariants (ce que le correctif ne doit pas casser)

* `dernier_enregistrement = record` (4766) reste SYNCHRONE : `test_telemetrie_gadgets.gd:502/573/672` et `test_online_match.gd:1524-1526` le lisent juste
  après l'appel.
* **Deux tests lisent le TEXTE de `game_state.gd`** : `var conditions := _conditions.resume()` et `_report_to_ranking(winner_id, forfeit, conditions, gadgets)`
  (`test_conditions_de_match.gd:203, 206, 208`, `test_telemetrie_gadgets.gd:368` ; la 3e ligne épinglée est `'"conditions": MatchRecord.conditions_a_envoyer(conditions, gadgets),'`).
  Déplacer l'appel est permis, le réécrire autrement ne l'est pas.
* `_forfeit_pending = false` (4735) reste synchrone (garde contre le double archivage entre chemins de retour au menu).
* Télémétrie des gadgets et conditions figées à l'instant du coup (deux pairs qui doivent s'accorder) : ne différer que l'ÉCRITURE et l'ENVOI, pas
  la construction (CAR-04 a raison).
* « Le journal local d'abord, l'envoi ensuite » (4772-4774) : l'ordre écriture -> rapport doit survivre ; `mark_reported` suppose l'entrée déjà écrite.
* Écriture atomique `.tmp` + rename et repli sur journal vide (`match_record.gd:253-271`, ROADMAP l. 5008-5050) : à garder.
* Après un `await`, `if token != _round_token: return` (4516) : l'écriture différée ne doit pas dépendre de ce test (une manche relancée entre-temps
  ne doit pas perdre l'archive).
* Le garde `archiver_les_matchs` (bancs d'outils : photographe, banc_*) doit rester dans le chemin différé.
* Cache mémoire du journal (proposition 3 d'ETA-01 / de CAR-04) : danger de **perte d'entrées entre deux instances qui partagent `user://`** (duo,
  `run_duo.sh`, tests EOS ; `run_suites.sh:100-135` documente déjà ce partage). Aujourd'hui chaque écriture relit le fichier, donc la seconde instance
  garde la première ; avec un cache, la dernière écrite efface l'autre. Et vidage obligatoire à l'arrêt propre (CLAUDE.md).

### 2.5 Statut

NOUVEAU pour le temps (aucune mention dans la ROADMAP ; l. 5008-5050 ne traitent que le plafond, l'atomicité et le garde `archiver_les_matchs`). Le caractère
synchrone est écrit dans le code (`player.gd:2886-2888`) mais jamais chiffré. **Erreur de CAR-04** : « `ScreenHistory.refresh` fait deux `load_history` à
la construction de l'UI et à chaque entrée dans l'écran » — faux pour « à chaque entrée » : `refresh()` n'est appelé que par `build` (`screen_history.gd:119`) et
par `_on_hub_screen_changed` pour les écrans du hub (`ui.gd:5873-5876`) ; `panel_changed` ne nourrit que `_refresh_calibration_guard` (`ui.gd:4559`). MEN-12 a
raison (et signale, à juste titre, que le panneau d'historique semble figé sur le journal du lancement : voir section 6).

### 2.6 Verdict

**CONFIRMÉ AVEC RÉSERVE — MINEUR.** Réel, synchrone, avant le premier `await`, et d'ampleur « dizaines de ms au plafond » qui est le cas courant ; mais
post-décision, suivi d'un gel volontaire, sans effet d'équité ni sur le 1 % bas. MAJEUR (ETA-01) n'est pas soutenu ; ANECDOTIQUE (GAD-10, MEN-12) sous-estime
le plafond. Les quatre se traitent d'un bloc (un seul correctif, un seul test). À faire parce que le correctif est petit, pas parce que le gain est grand.

**Correctif minimal (effort S).** Dans `_archive_match_result`, garder `resume()`, `build()`, `dernier_enregistrement` et `_forfeit_pending` synchrones ; capturer
`record`, `winner_id`, `forfeit`, `conditions`, `gadgets` ; exécuter `append_to_history(record)` puis `_report_to_ranking(...)` APRÈS le premier `await` de
`_do_end_round` (avant le test de jeton), avec la même branche headless (`process_frame`). Cas sans `await` (`winner_id == -1`, forfait) : inchangés. Option M, plus tard
et avec les garde-fous de 2.4 : journal en mémoire (`mark_reported` sans relecture). Ne pas faire : fil de travail pour `statistiques()` (1-3 ms, définitions du banc
à respecter, `conditions_de_match.gd:25-29`), JSON-lignes (change le format, `test_rejeu_journal`), somme incrémentale (arrondis du banc).

**Gain attendu corrigé** : retire ≈ 4-7 ms (20 fiches) à ≈ 40-45 ms (plafond) de l'image d'impact, et l'absorbe dans le gel ; rien sur la cadence moyenne.
L'à-coup de l'accusé reste (≈ 40 ms au plafond, en ligne) tant que `mark_reported` relit le fichier.

**Preuve dans le cloud** (rien de tout cela ne demande de fenêtre) :
1. Micro-banc `--headless --script` (classes sans autoload : `test_conditions_de_match` le prouve) : 200 fiches réalistes via `MatchRecord.build` +
   `ConditionsDeMatch.machine()` + `TelemetrieGadgets.resume`, puis `Time.get_ticks_usec` autour de `load_history`, `JSON.stringify(h, "\t")`,
   `append_to_history`, `mark_reported` (médiane de 20, à 20/100/200 fiches), et de `ConditionsDeMatch.statistiques` avec 12 000 / 36 000 / 90 000 valeurs.
   Affiche la taille du fichier. Pur CPU : valable en ordre de grandeur ; l'exprimer aussi en « tours de boucle GDScript » pour comparer au Mac.
2. Garde déterministe, indépendante du matériel, après correctif : deux compteurs statiques dans `MatchRecord` (lectures, écritures) ; dans le harnais de
   `test_killcam_calme.gd` (qui appelle `main._do_end_round(0)` avec les vrais autoloads, `user://` isolé par `run_suites.sh`), exiger `ecritures == 0`
   tant que la coroutine n'a pas dépassé son premier `await`, puis `== 1` après.

---

## 3. Bloc B — ETA-02 + HUD-08 : premiers dessins et chargements à froid

### 3.1 Le mécanisme (et une contradiction à lever)

ETA-02 relevait une contradiction : `death_flash.gdshader:18-19` affirme « Ressource préchargée : compilée au démarrage, la première mort ne déclenche plus de
compilation à chaud », alors que `Fusee.prechauffer` dessine un quad « pour payer hors action la compilation du shader du voile ». **Tranchée** : le commentaire du
shader est inexact. Quatre sources du dépôt disent la même chose, dans le même sens :
* `fusee.gd:338-358` (doc de `prechauffer`) ;
* ROADMAP l. 22509-22513 (PE3.5) : « un `preload` charge le shader, mais le programme GL se compile au premier DESSIN — seule `Fusee.prechauffer()` dessine d'avance » ;
* `iso_nuage_voxel.gd:302-305` (docstring de `prechauffer`) : « Le shader, lui, se COMPILE à son premier dessin, dans le pilote : ce coût-là n'est pas pris ici » ;
* ROADMAP l. 27615-27622 (mesure sur le Mac) : « les hoquets de 143 à 150 ms sont des COMPILATIONS au premier allumage d'une sorte de lampe » — des variantes de
  lampe 3D (shaders spatiaux), pas des shaders canvas.

`preload` règle donc le chargement et l'analyse de la ressource (et évite le `Shader.new()` fabriqué dans `die()`, dont la compilation tombait pile à la mort : `player.gd:6-8`), pas la compilation
du programme GL, paresseuse au premier dessin (de mémoire des sources du moteur, non vérifié ici ; cohérent avec les quatre points ci-dessus).

### 3.2 Ce que le projet préchauffe déjà, et ce qui manque

| quoi | où | préchauffe réelle ? |
|---|---|---|
| volutes de la fusée (3 textures) + shader du voile | `fusee.gd:343-358`, appelé par `rebuild_arena` (`game_state.gd:1565`) ; un `Sprite2D` d'alpha de shader 0 dans l'arène, libéré à l'image suivante, garde statique `_voile_rechauffe` | **OUI** (seul dessin d'avance pour un shader canvas) |
| fumée voxel : shader, aplats, reliefs, planches | `iso_nuage_voxel.gd:306-322` (`prechauffer`, `prechauffer_nappes`), appelé à la naissance de la présentation iso (`iso_volumes.gd:343, 355, 1709`) | NON pour le GL : l'aveu est dans le commentaire (partie CPU seulement) |
| texture de torche | `weapon_data.gd:~220` « cuite hors ligne » | n'est pas un shader |
| shaders `preload` en `const` (doctrine) | `player.gd:9-12`, `blood_stain.gd:32`, `ui.gd:15, 67-69`, `game_state.gd:6`, `brouillage_vue.gd:43`, etc. (liste : 49 sites dans les `.gd` de la racine) | NON : charge seulement |
| particules de sang | `particle_pool.gd` (240 corps pré-alloués) | nœuds cachés : rien n'est dessiné d'avance |
| chauffe « par couverture » des lampes 3D | `tools/bench_framerate.gd:446-451, 724-757` | **banc seulement** ; `lumieres_iso.gd:116, 315` note les premiers allumages, ne chauffe rien. ROADMAP l. 27519-27521 : « noté, pas fait » |
| voile de killcam, flash de mort, fantôme (`--2d`), voile d'éblouissement PLEIN, flou de brouillage | — | **NON** (ROADMAP l. 22431-22433 : « déjà traitée pour le joueur, le sang, la fusée et l'onde de choc » = `preload`, pas dessin) |

La ROADMAP reconnaît le trou : l. 20390 et 21416-21417 « le hoquet au premier rejeu n'est pas tranché : ni la capture ni le photographe ne mesurent un temps d'image ».
`tools/banc_pics.gd:25-26` écrit qu'un pic de compilation « se paie une fois par lancement et jamais en match » : faux pour ces shaders, dessinés pour la première fois EN
match (HUD-08 a raison).

### 3.3 Le code, et la portée réelle dans la vue par défaut (iso)

La vue par défaut est l'iso (`settings_manager.gd:101`, `mode_iso := true`). Deux items d'ETA-02 ne valent donc qu'avec `--2d` :
* **`SHADER_GHOST` (`ghost_unshaded.gdshader`)** : en iso, `Presentation3D._suivre_le_fantome` appelle `_cacher_le_fantome` (`presentation_3d.gd:1766-1773`) qui passe le
  `visibility_layer` de `VisualColored` et de ses enfants à `COUCHE_HORS_VUE` ; le corps du fantôme est le corps voxel du joueur (`_corps[j]`, uniformes
  `silhouette_N` / `opacite_N` posés à 0, `presentation_3d.gd:1460-1467`), donc des shaders déjà chauds. Le `ghost_unshaded` n'est jamais dessiné.
* **Le `ColorRect` de 20 000 x 20 000 px + `BackBufferCopy`** (`game_state.gd:634-647`) : en iso, `_accorder_le_voile_de_killcam` (`presentation_3d.gd:847, 1784-1798`)
  sort ce voile de la lightmap et crée, à la PREMIÈRE killcam, un `CanvasLayer` (couche -1) + `ColorRect` plein cadre qui partage le matériau
  (`_creer_le_voile`, `:1801-1814`). Le shader tourne donc sur la fenêtre. En revanche `ui.show_killcam` montre quand même `KillcamBB` (`ui.gd:9326-9328`) :
  voir section 6.

Reste vrai en iso : `SHADER_DEATH_FLASH` (créé dans `die()`, `player.gd:2987-2993`, dessiné pour la première fois à l'image du kill — **uniquement chez la
VICTIME, à ma lecture** : le flash porte `visibility_layer` 2 ou 4 et vit dans la vue du mort, que le vainqueur n'affiche pas, `player.gd:2982-2985`), `killcam_overlay.gdshader`
(96 lignes dont 42 de code, 5 `texture(screen_texture)` en `filter_linear_mipmap`, `killcam_overlay.gdshader:20, 52-61` ; première killcam, matériau créé par `ui.gd:3819-3841`),
et le voile d'éblouissement PLEIN :

```gdscript
# ui.gd:2543-2545 — HUD-08
var choisi := plein if niveau * EffectPolicy.curseur("eblouissement") >= aberration_debut() else calme   # seuil 0,12
```
`voile_eblouissement.gdshader` = 463 lignes d'include dont 128 de code (HUD-08 écrit « 460 lignes » : trois quarts sont des commentaires), `hint_screen_texture` + `filter_linear_mipmap` (`voile_eblouissement.gdshaderinc:245`) ; le voile « calme » est
dessiné dès la première image (rétrodiffusion 0,06 < 0,12). Le plein n'est donc dessiné qu'au premier éblouissement réel de la séance : EN JEU, sur la machine
de l'ébloui, à un moment qui compte — le seul item du lot qui soit pendant la partie et non après la décision.

Autres « premières fois » de l'image du kill, tous CONFIRMÉS mais petits et bornés :
* glyphes du bandeau « FATAL — ARME » (+ « à N px du centre ») : fonte dynamique, sans MSDF ni `preload` (`assets/fonts/*.import`), rastérisés au premier dessin de
  chaque (taille, contour) ; ESTIMÉ 5-15 ms au tout premier kill.
* `load("res://assets/ui/cartouche_fatal.png")` (512 x 256, 8,8 Ko ; `player.gd:3202-3206`) : ≈ 1 ms une fois.
* sons : `tinnitus_death.wav` (288 Ko, `jouer_acouphene_mort`, `audio_manager.gd:2093`), sting (OGG) et voix d'annonceur (150-480 Ko) chargés au premier `play_*`
  (`get_audio_stream`, `audio_manager.gd:1479-1505`, aucun préchargement hors musique interactive) : ≈ 1-5 ms au total (ESTIMÉ ; fichiers petits).
* première killcam : `ReleveBalistique` (glyphes), copies de fusées / gadgets de rejeu : rares.
* `ReplaySystem.start_playback` / `stop_recording` / `releve_du_tir_fatal` : légers (lus : `replay_system.gd:117, 289-330, 407-433`).

### 3.4 Fréquence et coût

**Fréquence** : une fois par processus et par shader (le programme GL reste ensuite), sur la machine qui le dessine : le perdant pour le flash de mort, chaque pair pour
le voile de killcam, l'ébloui pour le voile plein. Un `Shader.new()` fabriqué à la volée créerait une ressource neuve, donc très probablement un programme neuf à chaque usage : c'est ce que `preload` a supprimé.

**Coût : À MESURER, et je ne peux pas faire mieux que les auditeurs.** Ni les shaders canvas ni les glyphes n'ont été chronométrés nulle part dans le dépôt. La seule donnée
(143-150 ms) concerne des variantes de lampe 3D (shaders de la scène iso, une compilation par sorte de lampe), pas comparables telles quelles à un shader canvas ; en lignes de code (hors commentaires et blancs) `death_flash` fait 14, `ghost` 5, `killcam_overlay` 42,
`brouillage_flou` 33, le voile plein 128 (comptées sur les fichiers). Je ne retiens pas le « quelques ms à quelques dizaines de ms » d'ETA-02 comme un chiffre : c'est une intuition. Une
fois par séance, par shader, par machine.

### 3.5 Invariants

* **Noir absolu / équité** : une chauffe ne doit rien laisser à l'écran. Attention, piège que ni ETA-02 ni HUD-08 ne voient : `modulate.a = 0` ou `visible = false` **sautent
  le dessin** (donc la compilation). Par shader : `death_flash` sort `alpha = 0` à `flash_intensity = 0` (quad invisible, OK) ; le voile plein sort `COLOR = vec4(0.0)` tant que `niveau <= 0.001`
  (`voile_eblouissement.gdshaderinc:308-309`, quad invisible, OK : HUD-08 a raison pour lui, et la copie d'écran est faite quand même puisqu'elle tient au code du shader, pas
  à la branche prise) ; **mais `killcam_overlay` sort toujours `alpha = 1` (`COLOR = vec4(col, 1.0)`, ligne 95)** : sa chauffe doit être une identité (`intensite = 0`,
  `negatif = 0`, quad de 2 x 2 px au centre de l'écran où la vignette vaut 1) ou passer par un `SubViewport` isolé. « Alpha nul » ne convient donc pas à celui-là.
* **Même état de rendu que le dessin réel** : un programme GL est partagé entre cibles, mais sur le pilote d'Apple (OpenGL au-dessus de Metal) le coût d'un premier
  dessin peut dépendre aussi du format de la cible et du mélange : une chauffe dans un `SubViewport` de format différent (la lightmap) ne vaudrait qu'en partie pour le flash
  de mort, dessiné dans la fenêtre. Dessiner la chauffe dans la même racine que le dessin réel (un `CanvasLayer` de la fenêtre, un quad de 1-2 px, une image).
  `Fusee.prechauffer` ne passe PAS par un `SubViewport` isolé (contrairement à ce que laisse lire ETA-02 « sur le modèle de ») : il dessine dans l'arène.
* Les lectures d'écran (`killcam_overlay`, voile plein : `hint_screen_texture` en `filter_linear_mipmap`) obligent le moteur à faire, à leur premier dessin, la copie plein cadre de la
  cible et sa chaîne de mipmaps (de mémoire du moteur) : la chauffe doit les payer aussi, dans la cible réelle.
* Suites qui comptent des nœuds / des enfants d'arène : `rebuild_arena` appelle déjà `Fusee.prechauffer` ; vérifier `test_arena_build`, `test_arena_lighting`,
  `test_fusee_killcam`, `test_iso_killcam`, `test_killcam_calme` après l'ajout d'une chauffe (nœuds éphémères libérés à l'image suivante, comme `ChauffeVoileFusee`).

### 3.6 Statut, verdict, correctif, preuve

Statut : CONNU-OUVERT (ROADMAP l. 20390, 21416-21417, 22431-22433, 22509-22513 ; question jamais tranchée faute de mesure).

**CONFIRMÉ AVEC RÉSERVE — MINEUR.** Le mécanisme est établi par le dépôt lui-même ; l'ampleur est inconnue ; le moment est après la décision (flash de mort, killcam) sauf pour
le voile plein. ETA-02 « MAJEUR sous réserve de mesure » : je le ramène à MINEUR (une fois par séance, hors du moment qui se joue) en gardant la possibilité qu'une mesure
le remonte. Ordre de priorité si l'on fait la chauffe : (1) voile plein (en jeu), (2) flash de mort (image du kill, chez le perdant), (3) killcam (après la décision, masquée par
le ralenti et le « rembobinage » sonore).

**Correctif minimal (M)** : une fonction de chauffe unique, appelée à côté de `Fusee.prechauffer(arena)` (`game_state.gd:1565`) ou pendant le compte à rebours, garde
statique « une fois par processus », qui dessine UNE image, dans la racine de la fenêtre, trois quads de 1-2 px à sortie nulle ou identité : `death_flash` (`flash_intensity = 0`),
voile plein (`niveau = 0`), `killcam_overlay` (`intensite = 0`, `negatif = 0`), puis se libère. Corriger le commentaire de `death_flash.gdshader:18-19`. Ne rien faire pour
`SHADER_GHOST` (jamais dessiné en iso ; en `--2d` seulement). Même famille, hors lot : `blood_shader` (premier saignement de la séance), `brouillage_flou` (premier brouillage).

**Preuve dans le cloud** :
1. Existence et ordre de grandeur sous Xvfb + llvmpipe, **cache de shaders Mesa désactivé** (`MESA_SHADER_CACHE_DISABLE=true` : `tools/cadence_cloud/prise.sh` le laisse
   volontairement ACTIF, ce qui masquerait la compilation à la seconde prise) : deux duels bot de suite dans le même processus (base `tools/banc_bot_duel.gd`, qui s'arrête à la
   première mort), `Time.get_ticks_usec` image par image autour du kill et du début de killcam ; la différence « kill n°1 - kill n°2 » isole le coût de premier usage sur cette
   pile. Ça ne chiffre pas le Mac (le dépôt le dit lui-même, l. 31300-31301, 31445) mais prouve le mécanisme et l'effet avant/après d'une chauffe.
2. Garde structurelle : la fonction de chauffe expose l'ensemble des shaders chauffés ; un test vérifie qu'après `rebuild_arena` + 2 images les trois y sont, qu'aucun nœud de
   chauffe ne reste, et que l'arène reste noire (le détecteur de fuite « au-delà de 2/255 » déjà employé par GV1, ROADMAP l. 2468).

---

## 4. Bloc C — MEN-07 : l'illustration de l'affiche de fin

### 4.1 Le code et les appelants

```gdscript
# affiche_de_fin.gd:476-490 (_illustration_pour), appelée par _composer (:179), lui-même par AfficheDeFin.poser (:147-154)
var chemin := FIN_DEFAITE if m.begins_with("DÉFAITE") else FIN_VICTOIRE
...
ill.texture = load(chemin)                      # synchrone
ill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
```
Appelants : `GameState._poser_affiche_de_fin` (`game_state.gd:4678`) <- `_do_end_round:4639`, dans l'image qui fait aussi `ui.show_game_over(winner_id)` (reconstruction du salon,
`ui.gd:9039-9130`), `ui.poser_bilan`, `_apply_deferred_rematch`, la composition de ~25 contrôles et du mot du verdict à ≈ 140 px avec contour (`affiche_de_fin.gd:222-231` :
glyphes rastérisés à cette taille au premier match de la séance). Aucune autre référence aux deux chemins dans les `.gd` racine : rien ne la précharge, et `congedier()` la libère
(la texture n'est tenue que par le `TextureRect`) : **redécodée à chaque match**. Égalité : aucune illustration, aucun `load` (`:474-475`).

Vérifié : `fin_victoire.jpg` 1920 x 1080 (468 534 o), `fin_defaite.jpg` 1920 x 1080 (243 008 o) — en-têtes JPEG lus ; `.import` : `compress/mode=0` (sans perte),
`mipmaps/generate=true` pour les deux. La `.ctex` (WebP sans perte, une image par niveau de mipmap) n'est pas sur cette machine (`.godot/` absent).

### 4.2 Fréquence, coût

Une fois par match et par pair (hors égalité), environ 7 à 11 s après le kill (0,15 s + 1,5 s + killcam 3-7 s + 2 s), monde figé. Coût : décodage WebP sans perte
de ≈ 2,8 Mpx (1920 x 1080 + mipmaps) + envoi de ≈ 11 Mo au GPU. ESTIMÉ **25-50 ms** (les 20-60 ms de MEN-07 tiennent) ; à MESURER, et la part décodage se
mesure en headless. Le fondu d'entrée (0,34 s, tween) démarre sur cette image longue : les premières images du fondu sont avalées, sans importance. Le mot à 140 px et la
reconstruction du salon partagent la même image ; MEN-07 isole le décodage, qui est le morceau identifiable, pas forcément le plus lourd.

### 4.3 Invariants

* L'affiche **lit** le verdict sur `ui.game_over_title` plutôt que de le recalculer (`affiche_de_fin.gd:439-448`, en-tête : « deux calculs finiraient par se contredire ») :
  on ne peut donc pas choisir quelle image précharger sans dupliquer cette règle. Précharger LES DEUX (22 Mo résidents ≈ 10 s) ou factoriser la règle.
* `tools/test_carton_de_fin.gd`, `test_carton_transition.gd`, `test_ecran_de_fin.gd` (cités par MEN-07) ; garde « Opaque DÈS LA PREMIÈRE IMAGE » (`couverture()`).
* `ResourceLoader.exists` + `push_error` si l'image manque : à conserver.
* Lancer la requête dès que `winner_id != -1` est connu (début de `_do_end_round`) ; si le joueur quitte pendant la killcam, la ressource chargée reste simplement dans le cache.

### 4.4 Statut, verdict, correctif, preuve

Statut : NOUVEAU pour ce coût (la ROADMAP l. 22424-22430 parle des textures sans perte en général). **CONFIRMÉ — ANECDOTIQUE** (non décisif, une fois par match, monde
figé, fondu qui absorbe) ; le correctif est petit, donc à prendre si la tâche passe par là.

**Correctif minimal (S)** : `ResourceLoader.load_threaded_request` des deux chemins au début de `_do_end_round` quand `winner_id != -1` ; l'affiche garde son `load(chemin)`
(ou `load_threaded_get`) : de mémoire, `load()` rejoint la tâche en vol et rend aussitôt si elle est finie. Ne PAS passer en `preload` : +22 Mo résidents toute la séance et
~60 ms de plus au lancement.

**Preuve dans le cloud** : (a) headless, `ResourceLoader.load(FIN_VICTOIRE, "", CACHE_MODE_IGNORE)` chronométré 5 fois : la part décodage (pas d'envoi GPU en headless) ;
(b) après correctif, garde déterministe : `ResourceLoader.has_cached(FIN_VICTOIRE)` (ou `load_threaded_get_status == LOADED`) vrai avant l'appel de `_poser_affiche_de_fin`
dans `test_carton_de_fin`.

---

## 5. Bloc D — JOU-05 + MEN-10 : `Charte._variation()` sans cache

### 5.1 Le code et les appelants

```gdscript
# charte.gd:614-623
static func _variation(chemin: String, poids: int) -> Font:
    if not ResourceLoader.exists(chemin): return null
    var base := load(chemin) as Font
    ...
    var v := FontVariation.new(); v.base_font = base; v.variation_opentype = {TAG_WGHT: poids}
    return v
```
PROUVÉ : un `FontVariation` + un `Dictionary` + un `exists` + un `load` (cache) par appel ; rien n'est gardé. Appelants (`police_display`/`police_ui`, `charte.gd:631-637` ;
`habiller_selon:804`) : `bullet.gd:737` (chaque plomb qui touche), `player.gd:3028` et `:3306` (bandeau et marge, une fois par mort et par vue), `affiche_de_fin.gd:226`,
`estampe_de_kill.gd:131`, `carte_de_soiree.gd:219`, `arena_decor.gd:338` (une fois par cuisson), `aventure_*`, `menu_engraver.gd:155`, ≈ 100 sites de construction de
menus via `Charte.appareil/enseigne` (au lancement). **Correction de fréquence** : JOU-05 et MEN-10 disent « par événement » ; `releve_balistique.gd:373, 397, 425, 456, 471`
est dans `_draw` (`:283`, via `_tracer_*` et `_ecrire`) et se rejoue à chaque `queue_redraw`, c'est-à-dire à chaque image où `progression` change (`avancer`, `:140-145`) : ≈ 9
appels par image pendant la seconde environ du pré-tracé de la killcam. Aucun appel par image dans le HUD de manche (vérifié dans `ui.gd` 3120-3500, 8740-8940, 1440-1470).

### 5.2 Ce que fait vraiment le moteur (ce que les auditeurs ne savaient pas)

La question posée : le cache de glyphes est-il partagé entre deux `FontVariation` de même base et mêmes paramètres ? **Je ne peux pas le prouver ici (sources du moteur
absentes), mais je penche fortement pour OUI**, pour deux raisons tirées de ma connaissance du moteur (4.x) :
* `FontVariation` ne possède pas ses glyphes : il demande au `FontFile` de base une variation (`Font.find_variation(...)`), et `FontFile::find_variation` commence par
  **chercher une variation existante** de mêmes coordonnées / gras / transformation / espacements avant d'en créer une. Deux `FontVariation` identiques résolvent donc le
  MÊME `RID` de police du serveur de texte, dont le cache de glyphes (par RID et par taille) est partagé ;
* la doc de `TextServer.create_font_linked_variation` décrit (de mémoire, paraphrasée) une variation qui réutilise le même cache de glyphes et les mêmes données que la police de base.

Donc **JOU-05 (« un `FontVariation` a son propre cache de glyphes et ses propres pages d'atlas dans le TextServer ») est très probablement faux**, et ses chiffres (0,2-0,6 ms par
plomb, 1-3 ms par bandeau, « −0,2 à −0,5 ms par chiffre ») ne reposent sur rien : RÉFUTÉS. Ce qui est perdu à chaque `FontVariation` neuf est plus petit : le **cache de
lignes mises en forme propre à chaque objet `Font`** (utilisé par `draw_string` et `get_string_size`, de mémoire `Font::cache`). Il joue pour `releve_balistique._draw` (la
ligne est remise en forme à chaque image), pas pour les `Label` (chacun a son `TextParagraph`). Ordre de grandeur ESTIMÉ : 10-30 µs par appel d'allocation ; ≈ 0,2-0,5 ms par
image de pré-tracé en remise en forme. Aucun gain sur le chiffre de dégâts ni sur le bandeau.

### 5.3 Invariants, statut

Aucun test ne dépend de l'identité d'instance (`test_charte.gd:475-476` compare deux graisses de clés différentes, `test_habillage.gd:185-187`, `test_pochoirs.gd:160`, `test_bandeau_fatal.gd:88`).
Les 16 appelants hors `charte.gd` lisent ou assignent sans muter (vérifié par MEN-10 ; `menu_hub.gd:1086-1087` mute une autre `FontVariation`, la sienne, sans passer par `Charte`).
Statut : NOUVEAU (aucune note ROADMAP sur le cache des polices).

### 5.4 Verdict, correctif, preuve

**RÉFUTÉ pour la conséquence alléguée ; CONFIRMÉ comme simple allocation — ANECDOTIQUE.** À ne pas porter dans la liste d'optimisations. Si l'on veut tout de même l'hygiène :
`static var _fontes: Dictionary` clé `[chemin, poids]` dans `Charte._variation` (S ; fonte partagée, jamais mutée).

**Preuve dans le cloud (headless, déterministe, 15 lignes)** : créer deux `FontVariation` de même base et même `{TAG_WGHT: 800}` ; comparer `a.get_rids()[0] == b.get_rids()[0]`.
Égaux = cache de glyphes partagé = constat clos. Compléter par le temps de 10 000 `Charte.police_display(800)` (µs par appel), et le temps de `get_string_size` à froid sur une
instance neuve contre une instance réutilisée (montre l'effet du cache de lignes). Le serveur de texte fonctionne en `--headless` (les suites `test_charte`, `test_habillage`
mesurent déjà des largeurs de chaînes).

---

## 6. Observations hors périmètre (signalées, non traitées)

1. **Le panneau d'historique des matchs ne se rafraîchit jamais après le lancement** (confirme la note de MEN-12) : `ui.gd:4585` l'attache comme panneau ; `refresh()` n'est appelé que
   par `ScreenHistory.build` (`screen_history.gd:119`) et par `_on_hub_screen_changed` pour des identifiants d'écran ; `panel_changed` n'est branché que sur `_refresh_calibration_guard`
   (`ui.gd:4559`). Défaut fonctionnel, pas de cadence ; à vérifier à l'oeil avant d'en faire une fiche.
2. `ui.show_killcam` montre `KillcamBB` (`BackBufferCopy` `COPY_MODE_VIEWPORT`, `ui.gd:9326-9328`) même en iso, où le voile 2D qui le lirait est sorti de la lightmap : une copie
   plein cadre par image de killcam sans lecteur (à vérifier : le chemin `../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB`). Killcam seulement.
3. `death_flash.gdshader:18-19` : commentaire inexact (3.1).
4. `ui.aberration_debut()` (`ui.gd:2526-2528`) appelle `RenderingServer.shader_get_parameter_default` à chaque `_poser_voile`, donc chaque image et chaque voile : micro-coût, à laisser à l'agent HUD.
5. Deux `print()` dans `ReplaySystem.record_frame` à l'image de la mort (`replay_system.gd:153, 187`) : avec `flush_stdout_on_print=true` (PE2.4) chacun vide le journal du moteur
   (fichier disque) : quelques dizaines de µs, anecdotique, mais sur l'image du kill.

---

## 7. Récapitulatif des mesures à écrire (toutes faisables sans Mac)

| preuve | outil | indépendante du matériel ? |
|---|---|---|
| temps de `append_to_history` / `mark_reported` / `statistiques` à 20-100-200 fiches et N = 12 k-36 k-90 k | micro-banc `--headless --script` | non (CPU), ordre de grandeur seulement |
| aucune I/O de journal avant le premier `await` | compteurs statiques dans `MatchRecord` + `test_killcam_calme` | **oui** |
| premier kill contre second kill (existence + avant/après d'une chauffe) | banc bot x2 sous Xvfb + llvmpipe, cache Mesa désactivé | mécanisme oui, millisecondes non |
| chauffe effectuée, aucune fuite de lumière | test structurel + détecteur 2/255 | **oui** |
| décodage de `fin_victoire.jpg` | `ResourceLoader.load(..., CACHE_MODE_IGNORE)` headless | non (CPU), partiel (pas d'envoi GPU) |
| l'image est en cache à la pose | `has_cached` dans `test_carton_de_fin` | **oui** |
| cache de glyphes partagé entre `FontVariation` identiques | égalité de `get_rids()[0]` headless | **oui** |
