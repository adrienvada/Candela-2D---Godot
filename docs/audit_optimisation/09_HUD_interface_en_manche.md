# 09 — HUD / interface en manche (préfixe HUD)

Commit audité : `52a29c1` (0.8.3 + SOLO S12). Périmètre : `ui.gd` (9 403 l.), `ui.tscn`, `charte.gd`, `settings_manager.gd`,
`hub_screen.gd`, `match_banner.gd`, `asset_manifest.gd`, `aventure_hud.gd` ; lus en plus, parce que le duel les traverse :
`menu_hatch_rect.gd`, `menu_widgets.gd` (pâte, plaques), `menu_apercu.gd`, `menu_hub.gd` (`_process`), `menu_torch.gd`,
`menu_backdrop.gd`, `menu_watcher.gd`, `menu_passerby.gd`, `menu_gnomon.gd`, `menu_icones.gd`, `map_gallery.gd`,
`matchmaking.gd` (`search_snapshot`), `voile_eblouissement*.gdshader*`, `audio_manager.gd` (trace F4), `game_state.gd` (appelants).

**Méthode et honnêteté.** Lecture seule, Godot non lancé. Donc :
- **PROUVÉ** = lu dans le code (un appel par image, un nombre de sites, un nœud qui reste en `_process`).
- **ESTIMÉ** = le coût en µs/ms. Il repose sur ma connaissance du moteur 4.x (le comportement de `add_theme_*_override`,
  de `Label.set_text`, de `Container` sur `NOTIFICATION_THEME_CHANGED`…), que je n'ai pas pu relire dans les sources 4.7 ici.
  **Aucun chiffre en µs de ce rapport n'est une mesure.** Les fourchettes sont larges à dessein.
- Le plancher de bruit du banc de cadence est de ~0,25 ms sur la médiane (ROADMAP l. 34151) : la plupart des gains ci-dessous
  sont **sous ce plancher pris un à un**. C'est pourquoi la section 4 propose un micro-banc headless (en µs) plutôt qu'un relevé de fps.
- **Ne pas se fier à `Performance.TIME_PROCESS` en valeur absolue** : c'est une moyenne glissante du moteur, pas un échantillon par
  image — le dépôt l'a payé (`tools/banc_pics.gd:255-285` : « 19,3 ms pendant que l'image médiane dure 9,1 »). Valable seulement en A/B.
- `ui.gd` est « partagé, à demander avant d'écrire » (`docs/JOURNAL_SESSIONS.md` l. 30, 45, 82).

---

## 0. En dix lignes

1. **Pendant un duel, `ui.gd` fait tout le travail du HUD à chaque image rendue (fps déplafonnés), sans aucune notion de « changé »** :
   `GameState._process` pousse l'état complet par `ui.update_hud(...)` (game_state.gd:2342-2345), inconditionnellement.
2. **Le panneau de l'adversaire est caché en ligne, à l'entraînement — mais `update_hud` le nourrit quand même** (7 écritures de
   thème, `_maj_reserves`, hachure, icône de gadget chargée depuis le disque). Et **au menu, les deux panneaux** sont nourris alors que `match_hud` est caché. (HUD-01)
3. **Le poste le plus lourd identifié : ~18 `add_theme_*_override` par image à valeur identique** (couleurs de libellés, `stylebox`
   des cartouches, statut réseau). Chacun déclenche `NOTIFICATION_THEME_CHANGED` ; sur un `PanelContainer`, un nouveau tri. Le code
   le sait (ui.gd:364-370, 8908) mais ne l'a corrigé que pour le chrono. (HUD-02)
4. **« Un menu caché qui calcule encore » : trouvé. `MapGallery._process` (map_gallery.gd:608) tourne toute la session, galerie
   cachée, et repeint à chaque image un `StyleBox` partagé par TOUTES les tuiles de cartes → une notification de thème par carte et par image,
   duel compris. Le coût croît avec le nombre de cartes perso.** (HUD-03)
5. **GPU : deux aplats plein écran permanents** — `VoileEncre` (10 % de noir, jamais caché) et le voile d'éblouissement « calme »,
   qui n'est plus gratuit depuis que la rétrodiffusion de la torche tient son niveau à 0,06 (12 lectures de texture par pixel). (HUD-04)
6. Plus petits, mais gratuits à corriger : hachure d'alerte (10 `set_shader_parameter`/image à pleine santé), deux
   `NeonFocusRing` cachés qui traitent, `MatchBanner.refresh()` qui construit un Dictionnaire de 18 clés par image.
7. **Le panneau F3 ouvert est coûteux** (texte réassigné 3 fois par image → reshape permanent, scan d'arène à 4 Hz, 95 ouvertures de
   fichiers à 4 Hz en dev), et **F6 le laisse ouvert** — sans que la télémétrie de cadence le sache. F3 fermé : ~2 lectures de touche. F4 fermé : rien par image.
8. Ni MSDF ni suréchantillonnage de police ; polices dynamiques, **aucune chauffe de glyphes** (`preload=[]`). Les shaders de l'UI
   (voile plein, killcam) ne sont pas préchauffés non plus (déjà noté ROADMAP l. 22510).
9. **Tout l'écran de menu est construit d'avance** (`UI._ready`), dont 16 illustrations décodées et résidentes (~44-58 Mo estimés).
10. **Hypothèse centrale à trancher en 10 lignes de GDScript headless** : le moteur court-circuite-t-il un `add_theme_color_override`
    de valeur égale ? Si oui HUD-02 s'effondre ; sinon c'est le plus gros poste CPU de l'interface (annexe A).

---

## 1. Carte des chemins chauds

### 1.1 Par image rendue, pendant un duel (Q1)

Cadence : celle du rendu, déplafonnée (`Engine.max_fps` = `fps_cap`, 0 par défaut en arène : settings_manager.gd:753-759).
Ordre de grandeur des relevés du dépôt : médiane ≈ 100-150 i/s sur le M3 (ROADMAP l. 27623-27640, 34076+) ; **non remesuré ici**.

| # | Appelant → travail | `fichier:ligne` | Quantité au pire cas d'un duel EN LIGNE (voxel + iso = défauts) |
|---|---|---|---|
| 1 | `GameState._process` → `ui.update_hud(p1, p2, time_left, horloge)` | game_state.gd:2342-2345 | **1 appel/image**, hors de tout `if round_active` : il tourne aussi aux menus |
| 1a | bloc J1 (joueur local) | ui.gd:8763-8804 | ~25 lectures dynamiques `p.get("…")`/`p.hp` (paramètres NON typés), 3 formatages `%`, `set_progress`, `_set_torch_style`, `_marquer_accroupi`, `_maj_reserves`, `_poser_voile` |
| 1b | bloc J2 (adversaire, **panneau caché en ligne**) | ui.gd:8806-8873 | identique à 1a, sur des nœuds invisibles |
| 1c | `_set_torch_style` ×2 | ui.gd:3369-3419 | par joueur : 1 `stylebox` override + 1 couleur override + `find_child("Verrou")` |
| 1d | `_maj_reserves` ×2 | ui.gd:3128-3278 | par joueur : 1 `get_first_node_in_group`, 4 `has_method`, ~10 `Dictionary.get` à clé String, 1 formatage, **5 overrides** (`lbl_f`, `lbl_g`, + `_habiller_la_reserve` ×2 → 2 `stylebox` + 1 couleur) |
| 1e | hachure d'alerte | ui.gd:8768-8774 ; menu_hatch_rect.gd:212-222 | **5 `set_shader_parameter`/joueur** à pleine santé (8 si ≤ 30 PV) |
| 1f | voile d'éblouissement | ui.gd:2531-2575 | torche allumée (`niveau` ≥ 0,06 > 0,001) : 5 `set_shader_parameter` + `Presentation3D.angle_ecran` + 2-3 `EffectPolicy.curseur` + 1 appel serveur `aberration_debut()` |
| 1g | chrono | ui.gd:8892-8906 | `format_clock` + `text =` (pas de changement → sortie anticipée du `Label`) ; `scale`/`pivot_offset` sous 10 s |
| 2 | `UI._process` | ui.gd:1451-1463 | 10 appels (dont `_update_joystick_cursor`, conditionnel) : |
| 2a | `_update_network_status` | ui.gd:1635-1661, 1724-1738 | **2 couleurs override/image** (statut + ping), 2 chaînes construites, `get_first_node_in_group`, `local_ipv4()` |
| 2b | `_sync_launch_entries` | ui.gd:5304-5309 | `get_meta` + `text =` sur un bouton du hub caché |
| 2c | `_update_focus_rings` | ui.gd:1742-1759 | 3 `_panneau_ouvert`, 2 `hide()`, 2 `menu_torch.viser(…, null)` (sortie anticipée, bien fait) |
| 2d | `_update_shake`, `_update_health_trails`, `_update_debug` (F3 fermé), `_update_killcam` (sortie anticipée) | 1808-1860, 2106-2108 | `Vector2.ZERO` posé ×2, 2 lectures de touche |
| 3 | `_process` de **nœuds** de l'arbre UI | | voir 1.2 |
| 4 | `UI._input` (par événement, pas par image) | ui.gd:8284-8295 | en ligne : **7 `event.is_action("p2_menu_…")` avant** de tester si un menu est ouvert |

Signaux reçus par image : **aucun** (les 56 `connect` de ui.gd sont des événements d'interface). Minuteries : `MenuGnomon` (1 Hz, sort si caché).
Tweens vivants : le décompte (3 s). Aucun `_physics_process` dans `ui.gd` ; `AventureHud.suivre()` est appelé à 60 Hz par
`AventurePartie._physics_process` (aventure_partie.gd:229-240) : ≤ 10 PNJ, trivial.

**Bilan chiffré par image (duel en ligne, torche allumée, F3 fermé).** Les comptes sont PROUVÉS ; les colonnes de coût sont ESTIMÉES.

| Poste | Compte | Coût estimé |
|---|---|---|
| `add_theme_*_override` qui notifient `THEME_CHANGED` | **18** = 2 réseau + 2×7 HUD (dont 7 sur nœuds cachés) + 2 anneaux cachés (via `border_color`) | 0,1–0,5 ms |
| dont **re-tri de conteneur** (cartouches `PanelContainer`) | 6 | inclus |
| notifications de thème **sur les tuiles de cartes cachées** (HUD-03) | N = nombre de cartes (≥ 6) | N × 5-15 µs |
| `set_shader_parameter` (hachure ×10, voile ×5) | 15 | 20-50 µs |
| `MatchBanner.refresh()` | 1 Dictionnaire de 18 clés, 4 `has_method`, 1 `get_node_or_null` | 8-20 µs |
| lectures dynamiques / groupes / `has_method` / `find_child` | ~50 / ~5 / ~10 / 4 | 20-50 µs |
| `EffectPolicy.curseur()` + `aberration_debut()` | 4 + 3 | 15-30 µs |
| `_process` d'anneaux cachés | 2 | 10-40 µs |
| **Total hors tuiles de cartes** | | **≈ 0,2-0,7 ms, soit ~3-10 % d'une image à ~7 ms** |

### 1.2 Q2 — ce qui reste dans l'arbre pendant un duel

**Dans l'arbre, caché, sans `_process` utile** : `game_over_panel` + `MenuHub` + 15 écrans + 18 `MenuApercu` + `MenuParticlesAmbiance`
(2 `CPUParticles2D`, `emitting` possible : le moteur ne les simule pas tant qu'ils ne sont pas visibles dans l'arbre — comportement 4.x
connu, à confirmer) + `ScreenEffects/Audio/Profile/History/Update/Leaderboard/Calibration` + `pause_panel`, `pick_panel`, `dialog_panel`, `debug_panel`, killcam (`killcam_*`).

**Visible pendant le duel** (dessiné) : `VoileEncre` (plein écran, alpha 0,1, ui.gd:2582-2587), `p1_dazzle` (plein écran en vue unique, shader), `p2_dazzle` (seulement en écran scindé), `match_hud` (~100 nœuds : ~40/joueur + centre + voiles), le statut réseau et le ping (en ligne), `center_line` (écran scindé seulement). `MenuAfterImage`, `MenuTorch`, `MenuWatcher`, `MenuTracer` sont des `Control` plein cadre visibles mais sans commande de dessin au repos ; `MenuBackdrop` et `MenuGlass` sont de simples `Node`.

**En `_process` pendant le duel :**

| Nœud | État | Verdict |
|---|---|---|
| `NeonFocusRing` ×2 (ui.gd:673) | **caché mais traite chaque image** (jamais de `set_process(false)`) | HUD-06 |
| `MapGallery` (map_gallery.gd:608) | **caché mais traite chaque image**, `process_mode = ALWAYS` | **HUD-03** |
| `MatchBanner` (match_banner.gd:157) | **traite chaque image**, caché quand rien ne cherche | HUD-06 |
| `CircularCooldown` ×2, `CartoucheReserve` ×4, `VirtualGamepadCursor` | appel + `if` → sortie | négligeable |
| `MenuHub`, `MenuPasserby`, `enseigne_qui_meurt` | sortie sur `is_visible_in_tree()` / `visible` | négligeable |
| `MenuWatcher`, `MenuTorch`, `MenuAfterImage`, `MenuTracer`, `MenuBackdrop`, `MenuEngraver` | `set_process(false)` hors usage | **bien fait** (M3 : ui.gd:1465-1482) |
| `Matchmaker._process`/`tick`, `UpdateManager._process` | sortie immédiate au repos | négligeable |
| `AventureHud` | aucun `_process`, `visible=false` hors salle | bien fait |

### 1.3 Q3 — chargements et polices

- `load()` **dans le chemin d'un duel** : un seul — l'icône du gadget de la classe (ui.gd:3249-3260, `MenuIcones.recadree` → `get_image()` = lecture GPU synchrone), au premier `update_hud` d'une manche, **pour l'adversaire caché aussi**. → HUD-09.
- `load()` **à l'ouverture d'un écran** : `MenuHub._update_background` (menu_hub.gd:819-820) charge le fond de la catégorie au premier passage ; la plupart sont déjà en cache de `ResourceLoader` (le fichier est le même que l'illustration). Hors duel.
- Polices : `Oxanium.ttf` et `BigShouldersDisplay.ttf`, `importer="font_data_dynamic"`, **`multichannel_signed_distance_field=false`** (pas de MSDF), **`oversampling=0.0`** (suit l'échelle de la fenêtre : `window/stretch/mode="canvas_items"`, project.godot:76 ; pas de suréchantillonnage propre), **`preload=[]`** (aucune chauffe de glyphes), `generate_mipmaps=false`, `hinting=3`, `subpixel_positioning=4`. Atlas de glyphes remplis **à la première apparition** de chaque (glyphe, taille, contour, graisse). Aucune mention de glyphes dans la ROADMAP sous cet angle. → HUD-09.
- `Charte._variation()` (charte.gd:614-623) crée un `FontVariation` neuf à chaque `Charte.appareil()/enseigne()` (≈ 34 sites dans ui.gd). Les caches de glyphes sont censés être partagés par l'appel moteur `FontFile.find_variation` (même graisse = même RID) : **à vérifier** (annexe A, point 3), sans quoi chaque appel ouvrirait un atlas neuf — ce qui compterait surtout pour `player.gd`/`bullet.gd` (un `police_display()` par bandeau/nombre de dégâts).

### 1.4 Q4 — construction au démarrage

`UI._ready` (ui.gd:1332-1376) construit **tout** d'avance : HUD (`_build_hud`), killcam, menu complet (`_build_menu` → en-tête, `MenuHub`, `_build_hub_screens` : 15 écrans, aventure 11+10 entrées, râteliers de 10 classes ×2 + fiches ×2, salon, `MapGallery` (vignettes peintes en GDScript, `MapThumbnail`), panneaux CONTRÔLES/AFFICHAGE, `ScreenEffects/Audio/Profile/History/Update/Leaderboard`, **18 `MenuApercu` qui font `load()` à la construction**), pause, fenêtre de choix, dialogue, barre de statut, décompte, panneau F3, deux anneaux, curseur manette. ~480 sites `add_child` statiques sur 12 fichiers, beaucoup en boucle : **de l'ordre du millier de nœuds, non mesuré**. Plus : un script de 9 403 lignes compilé au lancement, et 10 `get_image()` d'icônes d'arme (lecture GPU) pour les boutons de classe. → HUD-10.

### 1.5 Q5 — F3 et F4 fermés

- **F3 fermé** : `_update_debug` (ui.gd:1838-1856) = 2 `Input.is_physical_key_pressed` par image puis sortie. `debug_panel` caché. **Coût négligeable.**
- **F4 fermé** : `AudioManager._unhandled_key_input` (audio_manager.gd:2653-2658) sort sur tout événement qui n'est pas un F4 pressé. **Aucun coût par image.** *Mais* `_tracer_ecoute` est aussi appelé **automatiquement** à chaque pose/retrait d'oreille (audio_manager.gd:2381, 2412, 2470, 2688) — donc à chaque début/fin de manche, dans tous les builds : composition de ~25 lignes + `FileAccess.open(READ_WRITE)` + `seek_end` + `store_string` + `flush()` sur `user://diagnostic_ecoute.txt`, **en append, sans plafond**. → HUD-11.
- **F3 ouvert** : coûteux, voir HUD-07.

---

## 2. Constats

### HUD-01 — `update_hud` nourrit chaque image des panneaux CACHÉS (adversaire en ligne/entraînement, les deux au menu)

- **Où** : ui.gd:8806-8873 (bloc `if p2:`), ui.gd:8458-8494 (`disposer_hud`), game_state.gd:2342-2345 (appel inconditionnel). Voir aussi ui.gd:8441-8457 (décision du 2026-08-19 : HUD adverse caché en ligne).
- **Constat** :
  ```gdscript
  # ui.gd:8488-8489 — l'adversaire n'est pas affiché…
  hud_panneau_p1.visible = true
  hud_panneau_p2.visible = not en_ligne
  # ui.gd:8806-8846 — … mais il est nourri à pleine cadence, avec les mêmes appels que le joueur local
  if p2:
      …
      _set_torch_style(p2_torch, p2.flashlight_on, COLOR_P2, _torche_verrouillee(p2))
      _marquer_accroupi(p2_torch, p2)
      _maj_reserves(p2_reserves, 1, p2)
  # game_state.gd:2342-2345 — à chaque _process, même hors manche (menus, écran de fin)
  if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
      ui.update_hud(p2, p1, time_left, not training_mode)
  else:
      ui.update_hud(p1, p2, time_left, not training_mode)
  ```
  `disposer_hud(true)` (entraînement) cache aussi le panneau 2 (ui.gd:8470-8477). Et `match_hud.hide()` (menus, fin de match : ui.gd:9003, 9041) ne suspend rien : `update_hud` continue de pousser les deux fiches (dès que `p1`/`p2` existent).
- **Coût** : PROUVÉ — la moitié du travail du HUD (7 notifications de thème sur nœuds cachés, ~40 appels dynamiques de `_maj_reserves`, 5 `set_shader_parameter` de hachure, `find_child` ×2) est dépensée sur un panneau que personne ne voit, **dans le mode le plus sensible à la latence (EOS)**. S'ajoute un effet de bord : à la première image d'une manche, `_maj_reserves` charge l'icône de gadget de l'adversaire (`load()` + `get_image()`, lecture GPU synchrone — HUD-09) alors qu'elle ne sera jamais affichée. ESTIMÉ : 40-60 % du coût HUD en ligne ; ~100 % aux menus.
- **Proposition** : extraire les deux blocs en `_maj_fiche_joueur(i, p)` et ne les appeler que si la fiche est affichée : `hud_panneau_p1.visible and match_hud.visible` / `hud_panneau_p2.visible and match_hud.visible`. Laisser **hors** de la garde : le chrono (8892-8906), les voiles (`_poser_voile`, `_voile_bb`) et `p*_target_hp`. Rejouer une mise à jour forcée à la réouverture (`hide_game_over`, `disposer_hud`) pour ne jamais montrer une image de valeurs périmées. **Garder littéralement** `_maj_reserves(p1_reserves, 0, p1)` et `_maj_reserves(p2_reserves, 1, p2)` : `tools/test_tir_et_reserves.gd:658-660` lit le **source** de `ui.gd`.
- **Gain attendu** : voir Coût (ESTIMÉ 0,05-0,3 ms/image en ligne, davantage encore aux menus), plus un hoquet de début de manche en moins (icône adverse).
- **Risque** : équité nulle (au contraire, l'UI cesse de lire l'état adverse). Une image de valeurs périmées à la réouverture si la mise à jour forcée est oubliée (à voir à la planche de photos). Garde de test sur le texte du source.
- **Effort** : S.
- **Sévérité** : **MAJEUR** (le plus gros gain pour le moins d'effort, dans le mode en ligne).
- **Statut ROADMAP** : NOUVEAU. Contexte : décision de cacher le HUD adverse (ROADMAP l. 2289 « À trancher — le HUD », tranché ui.gd:8441-8457) ; personne n'a relevé que sa mise à jour continue.
- **Comment le vérifier** : micro-banc headless (annexe A) — `update_hud` ×2000 avec `hud_panneau_p2.visible = false` avant/après, en µs (`Time.get_ticks_usec`) ; puis `bench_framerate --vue-unique` en blocs alternés (le gain unitaire est sous le plancher de bruit) ; suites `test_tir_et_reserves`, `test_classes`, `test_ecran_de_fin`, `test_hud_style`, `test_menus_finitions`.

### HUD-02 — ~18 overrides de thème réécrits à chaque image, à valeur identique

- **Où** : ui.gd:1652 (statut réseau), 1737 (ping), 3375/3380 (`_set_torch_style`), 3168 et 3246 (`_maj_reserves`), 3439/3446 (`_habiller_la_reserve`, appelée pour les fusées ET le gadget), appelants 8801/8803/8844/8846.
- **Constat** :
  ```gdscript
  # ui.gd:1652 — dans _process, chaque image
  network_status_label.add_theme_color_override("font_color", tint)
  # ui.gd:3375, 3380 — branche voxel (le défaut), par joueur et par image
  panel.add_theme_stylebox_override("panel", _plaques_de_cartouche(panel, active, player_color))
  lb.add_theme_color_override("font_color", COLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)
  # ui.gd:3439, 3446 — _habiller_la_reserve (×2 cartouches par joueur)
  panel.add_theme_stylebox_override("panel", _plaques_de_cartouche(panel, active, player_color))
  label.add_theme_color_override("font_color", COLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)
  ```
  Décompte par joueur : torche (stylebox + couleur) = 2 ; fusées (`lbl_f` couleur, stylebox, couleur de nouveau sur le même libellé) = 3 ; gadget (`lbl_g` couleur, stylebox) = 2 → **7 ; ×2 joueurs = 14 ; + statut réseau + ping = 16 ; + 2 anneaux cachés (HUD-06) = 18**.
  Le dépôt connaît le problème et ne l'a réglé qu'au chrono et aux allocations : « *poser un override de thème à chaque frame coûte pour rien* » (ui.gd:8908-8909, `_teindre_chrono`), et « *la cartouche est retriée à CHAQUE image : `_set_flare_style()` / `_set_gadget_style()` y remplacent le stylebox* » (ui.gd:364-370 — **l'aveu que le re-tri a lieu**). `_plaques_de_cartouche` (ui.gd:3342-3366) ne supprime que la création de `StyleBoxFlat` (« cent vingt par seconde »), pas l'écriture de l'override.
- **Coût** : PROUVÉ — 16-18 écritures/image. ESTIMÉ (moteur 4.x : `add_theme_color_override`/`add_theme_stylebox_override` n'ont **pas** de garde d'égalité, notifient toujours `NOTIFICATION_THEME_CHANGED` ; un `Label` marque son texte à re-façonner et `update_minimum_size()` ; un `Container` fait `queue_sort()` ; un override de `stylebox` déconnecte/reconnecte en plus un signal) : 10-40 µs par notification sur un nœud visible, 3-10 µs sur un caché → **0,1-0,5 ms/image**. À 5 µs la ligne bascule en ANECDOTIQUE — d'où l'annexe A.
  Variante `--charte=pate` (non défaut) : en plus 3 `StyleBoxFlat.new()` par joueur et par image (ui.gd:3387, 3459, 3497) et 4 `find_child` de plus.
- **Proposition** : deux assistants en **lecture-avant-écriture sur l'état du moteur** (sans cache à tenir, donc auto-réparants) :
  ```gdscript
  func _couleur_si_change(c: Control, nom: StringName, v: Color) -> void:
      if c.has_theme_color_override(nom) and c.get_theme_color(nom) == v: return
      c.add_theme_color_override(nom, v)
  func _style_si_change(c: Control, nom: StringName, s: StyleBox) -> void:
      if c.has_theme_stylebox_override(nom) and c.get_theme_stylebox(nom) == s: return
      c.add_theme_stylebox_override(nom, s)
  ```
  (la lecture d'un override présent se fait sans notification). Les poser sur les ~10 sites listés ; pour le statut réseau, garder `_dernier_tint`/`_dernier_texte`. Une fois les écritures disparues, le re-tri documenté de `CartoucheReserve` n'a plus de cause (son `queue_sort()` explicite pendant la secousse reste, ui.gd:397-409).
- **Gain attendu** : 18 → ~0 notification/image en régime établi (les valeurs changent au plus quelques fois par seconde) ; supprime les 6 re-tris de cartouches/image. ESTIMÉ 0,1-0,5 ms.
- **Risque** : perte de la « réécriture qui répare » si une autre main retirait l'override — la lecture-avant-écriture la conserve. `test_menus_finitions.gd:281-285` appelle `_set_torch_style` directement avec des états successifs (compatible : on compare aux arguments/à l'état moteur) ; `test_classes.gd:2919-2925` appelle `_maj_reserves`.
- **Effort** : S (assistants) à M (si on veut aussi sauter `_maj_reserves` quand rien ne change).
- **Sévérité** : **MAJEUR** sous réserve de l'annexe A.
- **Statut ROADMAP** : NOUVEAU (aucune occurrence de « THEME_CHANGED »/« override par image » dans la ROADMAP ; seul précédent : le chrono, l. 11059).
- **Comment le vérifier** : annexe A (points 1 et 2) ; profileur de l'éditeur sur un duel en ligne (lignes `Control::_notification`, `Label::_shape`, `Container::_sort_children`) ; `test_hud_style`, `test_menus_finitions`, `test_classes`, `test_habillage`.

### HUD-03 — `MapGallery._process` : un menu caché qui notifie N tuiles à chaque image, duel compris

- **Où** : map_gallery.gd:608-616 (`_process`), 321-325 (les tuiles), menu_widgets.gd:532-541 (`reteindre`) ; la galerie est enregistrée dans le hub (ui.gd:4542-4549).
- **Constat** :
  ```gdscript
  # map_gallery.gd:608-616 — aucune garde de visibilité, process_mode = ALWAYS (l. 91)
  func _process(delta: float) -> void:
      _pulse += delta
      if _style_selected != null:
          var wave := 0.5 + 0.5 * sin(_pulse * 4.0)
          MenuWidgets.reteindre(_style_selected, COLOR_P1.lerp(Charte.HALOGENE, 0.4 * wave))
  # map_gallery.gd:324-325 — le MÊME style sert de « pressed » à TOUTES les tuiles
  tile.add_theme_stylebox_override("pressed", _style_selected)
  tile.add_theme_stylebox_override("hover_pressed", _style_selected)
  # menu_widgets.gd:540-541 — en voxel (défaut), le style est un StyleBoxTexture
  teinte.a = tex.modulate_color.a ;  tex.modulate_color = teinte
  ```
  Changer `modulate_color` d'un `StyleBox` émet `changed` ; chaque contrôle qui l'a posé en override y est connecté (`_notify_theme_override_changed`) → **`THEME_CHANGED` sur chaque tuile `Button`, chaque image, la galerie étant cachée.** N = `MapData.list_maps().size()` (6 cartes livrées + les cartes perso du joueur).
- **Coût** : PROUVÉ — `_process` permanent + une émission `changed` par image. ESTIMÉ : N × 5-15 µs (re-résolution du cache de thème d'un `Button` : ~20 entrées) ; 6 cartes ≈ 30-90 µs, **30 cartes perso ≈ 0,2-0,5 ms/image** — un coût qui **croît avec la bibliothèque du joueur** et que le banc de cadence (6 cartes) ne voit pas.
- **Proposition** : `set_process(false)` à `_ready`, et `visibility_changed.connect(func(): set_process(is_visible_in_tree()))` (le signal part aussi quand un ancêtre se cache) ; ou n'animer que la tuile sélectionnée (un `modulate`/shader sur ce seul nœud) au lieu d'un style partagé.
- **Gain attendu** : N notifications/image → 0 hors galerie visible.
- **Risque** : nul pour le jeu ; à la réouverture, la bordure repart de la phase en cours (accumulateur `_pulse`) — rien à faire.
- **Effort** : S.
- **Sévérité** : **MAJEUR** (le seul poste de ce rapport qui dépend d'une donnée du joueur et grandit avec elle ; coût mesuré au banc : 0 parce que le banc n'a que 6 cartes).
- **Statut ROADMAP** : NOUVEAU. `map_gallery.gd` n'est ni dans ma liste ni dans `menu_*.gd`/`screen_*.gd` : à croiser avec l'agent des menus pour ne pas le compter deux fois.
- **Comment le vérifier** : F3 « CARTES » donne N ; micro-banc : `MapGallery.new()`, N tuiles, 2000 × `_process(0.007)` en µs, pour N = 6 puis 30 (copies de cartes dans `user://maps/`) ; suites `test_vitrine_menus`, `test_menus_finitions`.

### HUD-04 — Deux aplats plein écran permanents : `VoileEncre` et le voile d'éblouissement « calme » (12 lectures de texture)

- **Où** : ui.gd:2582-2587 (`VoileEncre`), ui.gd:2430-2468 (`_forger_voile`), 2531-2575 (`_poser_voile`), 8878-8885 ; `voile_eblouissement.gdshaderinc` (`fragment()`), `voile_eblouissement_calme.gdshader` ; eblouissement.gd:174 ; game_state.gd:2573.
- **Constat** :
  ```gdscript
  # ui.gd:2582-2587 — jamais caché (menus compris), 10 % de noir sur TOUT le duel
  voile_encre.color = Color(Charte.NOIR, 0.1) ;  add_child(voile_encre)
  # eblouissement.gd:174 + game_state.gd:2573 — torche allumée : le niveau d'éblouissement ne tombe pas à 0
  const RETRODIFFUSION := 0.06      # × gain_taille (≤ 2) × facteur de lampe
  # ui.gd:2554 — seul un niveau ≤ 0,001 évite le fragment ; torche allumée on n'y est jamais
  if niveau <= 0.001: return
  ```
  ```glsl
  // voile_eblouissement.gdshaderinc:308 — fragment(), mode 1, défauts des uniformes (l. 142, 159, 211 : lueurs_n=2, flares_n=5, fantomes_n=5)
  if (niveau <= 0.001) { COLOR = vec4(0.0); } else { … 2 + 5 + 5 = 12 texture(), plusieurs dizaines de sin/cos PAR PIXEL … }
  ```
  Torche allumée, le voile **calme** (ISO10 1a : sans lecture d'écran, ui.gd:2543) se dessine plein cadre avec alpha ≈ 0,06 × (0,18-0,5 + lueurs) ≈ 1-4 %. ISO10 1a a supprimé la copie d'écran et la frange (0,53 ms/image à 2560×1440 pour *copie + voile plein*, ROADMAP l. 4317, 26533), **mais le coût du voile calme lui-même n'a jamais été isolé**. Le défaut signalé en ROADMAP l. 16993 (« `p1_dazzle` reste visible à alpha 0 ») est donc **périmé en partie** : le correctif proposé (`visible = niveau > 0.001`) ne couvre plus l'état courant du duel (torche allumée).
- **Coût** : PROUVÉ — un quad plein écran à fragment non trivial tant que la torche est allumée, + un second aplat translucide plein écran toujours. ESTIMÉ (GPU seulement) : voile calme 0,1-0,4 ms à 1440p (12 lectures de texture + une cinquantaine d'appels `sin`/`cos` par pixel, tous à entrées uniformes sauf `d`, × 3,7 Mpx), `VoileEncre` 0,02-0,1 ms ; **utile seulement si la scène est liée au GPU** (à lire avec `--temps-par-vue`). Fourchette très incertaine : le compilateur de pilote d'Apple sait sortir les calculs purement uniformes du fragment (préambule) ; une part du « par pixel » ci-dessus est peut-être déjà payée une fois par tracé.
- **Proposition** : 1) **mesurer d'abord** : `--plan=loupe-cout-voile` avec trois bras (voile calme tel quel / voile masqué / sans `VoileEncre`). 2) Si l'écart dépasse ~0,15 ms : **option A, sans effet visuel** — sortir du `fragment()` tout ce qui ne dépend pas du pixel (rotations `cos/sin` de chaque flare et de chaque fantôme, centres et échelles des lueurs, scintillements : fonctions de `temps`/`relevement`, déjà poussés en uniformes depuis GDScript) vers des tableaux d'uniformes calculés une fois par image en GDScript. **À ne tenter qu'après mesure sur le Mac** : si le pilote fait déjà ce hissage, le gain est nul. **Option B (visuelle, à trancher par Adrien)** : une variante allégée sous `aberration_debut`. **Option C (visuelle)** : voile à demi-résolution (il est lisse, hormis le grain). 3) **Ne pas retirer `VoileEncre`** : il assombrit toute l'image de 10 % (lumières comprises) — c'est un choix d'identité (« il assoit le HUD sur le jeu »), pas un détail.
- **Gain attendu** : GPU 0-0,4 ms ESTIMÉ ; nul si le duel est lié au CPU.
- **Risque** : option A : aucun si l'égalité numérique est vérifiée (`tools/banc_voile.tscn`, planche d'éblouissement, test pixel) ; B/C : lisibilité de la lumière et identité visuelle — **signalé, non tranché**.
- **Effort** : M (A), S (mesure).
- **Sévérité** : **MAJEUR (à confirmer par la mesure)**.
- **Statut ROADMAP** : CONNU-OUVERT (l. 16993), partiellement périmé par ISO10 1a (l. 26518-26535, 4309-4317).
- **Comment le vérifier** : `tools/photographe` `--plan=loupe-cout-voile` (8 blocs alternés de 120 images, cf. l. 26533) ; `bench_framerate --vue-unique --temps-par-vue` ; `tools/banc_voile.tscn`, `planche_eblouissement` pour l'égalité visuelle.

### HUD-05 — Hachure d'alerte de la barre de vie : 5 `set_shader_parameter` par joueur et par image, à pleine santé

- **Où** : ui.gd:8764-8774 (J1), 8812-8817 (J2) ; menu_hatch_rect.gd:26-128 (setters), 212-222 (`set_alert`).
- **Constat** :
  ```gdscript
  # ui.gd:8768-8774 — chaque image
  if p1.hp <= 30.0 and p1.hp > 0.0: p1_hp_hatch.set_alert(true, Charte.ROUGE, 3.5) ; p1_hp_hatch.alpha_mix = 0.70
  else:                              p1_hp_hatch.set_alert(false) ;                    p1_hp_hatch.alpha_mix = 0.0
  # menu_hatch_rect.gd:26-30 — chaque setter pousse au matériau SANS comparer
  var alpha_mix: float = 1.0:
      set(v): alpha_mix = v ; _update_param("alpha_mix", alpha_mix)
  # menu_hatch_rect.gd:219-222 — set_alert(false) = 4 setters (alert_pulse, speed, line_width, roughness)
  ```
- **Coût** : PROUVÉ — 5 `set_shader_parameter` (8 en alerte) par joueur et par image : le matériau est marqué sale, son UBO reconstruit et renvoyé au GPU chaque image (comportement 4.x des backends), pour deux ColorRect de 340×12 px qui restent **dessinés à alpha 0**. ESTIMÉ 20-50 µs/image (le P2 compris, hors-écran).
- **Proposition** : rendre les setters de `MenuHatchRect` idempotents (`if v == x: return`, comme `Range.set_value`) — corrige tous les sites d'un coup, y compris les menus — et n'appeler `set_alert` qu'au changement d'état de santé ; `hatch.visible = alpha_mix > 0`.
- **Gain attendu** : 10 appels serveur et 2 reconstructions d'UBO par image ; 2 appels de dessin.
- **Risque** : nul ; `tools/test_hatch_shader.gd` couvre `set_alert`.
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU.
- **Comment le vérifier** : micro-banc (annexe A, point 2) ; `test_hatch_shader`.

### HUD-06 — Nœuds cachés qui traitent chaque image : `NeonFocusRing` ×2 et `MatchBanner`

- **Où** : ui.gd:664-699 (anneaux), 1742-1759 (les cache), match_banner.gd:132-148, 157-165 (bandeau), matchmaking.gd:357-377.
- **Constat** :
  ```gdscript
  # ui.gd:673-699 — jamais set_process(false) ; ui.gd:1750-1751 ne fait que hide()
  func _process(delta):  _style.border_color = neon.lerp(…) ; torche.modulate = Color(neon, …)
                         torche.position = … ; global_position = … ; size = …
  # match_banner.gd:157 — process_mode = ALWAYS, jamais couplé à l'état de la file
  func _process(_delta): refresh()   # → _snapshot() → _usable() → get_node_or_null + 4 has_method
                                     #   → mm.call("search_snapshot")  (Dictionnaire de 18 clés, matchmaking.gd:357)
  ```
  Chaque anneau : `border_color` (change à chaque image) → `emit_changed` → son propre override de style → `THEME_CHANGED` ; plus `modulate`, `position`, `global_position`, `size` posés. Le bandeau : au repos il construit un Dictionnaire (+ `state_label()`, `range_label()`, `is_supported()` → `backend.has_method`…) puis fait `hide()`, **chaque image de chaque duel**. Le commentaire du fichier assume la lecture par image « parce que le chrono avance de toute façon » — vrai en recherche, faux au repos.
- **Coût** : PROUVÉ. ESTIMÉ : anneaux 10-40 µs ; bandeau 8-20 µs + 1 Dictionnaire et ~5 chaînes allouées par image.
- **Proposition** : anneaux — `set_process(false)` à la création et `visibility_changed → set_process(visible)` (au `show()`, `_update_focus_rings` fait déjà `aim(rect, true)`). Bandeau — `set_process(false)` au repos, réveil sur `Matchmaker.state_changed` (signal existant, matchmaking.gd:125) ; garder le chemin `matchmaker_override` des suites.
- **Gain attendu** : ~20-60 µs/image et une allocation de moins par image.
- **Risque** : faible. Le bandeau doit se réveiller à `ST_SEARCHING` (`test_matchmaking*`, `test_audit_menus`) ; un anneau ne doit pas rester figé à la réouverture (snap).
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU. Même famille que M3 (« le regard du noir n'a rien à faire hors d'un menu », ui.gd:1465-1482), appliquée à la seule moitié des effets.
- **Comment le vérifier** : micro-banc (2000 × `_process`) ; `test_torche_hors_menu`, `test_audit_menus`.

### HUD-07 — Panneau F3 ouvert : coûteux, laissé ouvert par F6, et la télémétrie l'ignore

- **Où** : ui.gd:1838-1935 (`_update_debug`), 1918-1929 (texte), 1953-1957 (F6), 2087-2104 (`_rescan_debug_counts`) ; asset_manifest.gd:219-254 ; map_data.gd:81-82.
- **Constat** :
  ```gdscript
  # ui.gd:1918-1929 — TROIS affectations par image, de valeurs toutes différentes
  net_debug_label.text = _network_debug_line()
  net_debug_label.text += "\n" + p2_path          # en ligne
  net_debug_label.text += "\n" + _assets_summary
  # ui.gd:1953-1954 — F6 (copie du diagnostic) ouvre F3 et ne le referme jamais
  debug_mode_active = true ;  debug_panel.visible = true
  ```
  `Label.set_text` ne court-circuite que si la chaîne est égale à la précédente : la 1ʳᵉ affectation diffère de la valeur finale de l'image d'avant → le libellé (320 px, `autowrap`) est **sale à chaque image** : refaçonnage + coupures de ligne + redessin permanents. S'y ajoutent 3 overrides de couleur par image (`fps_label`, `dbg_ping`, `dbg_particules`), `MapData.list_maps()` qui duplique le catalogue (map_data.gd:82), `Presentation3D.texte_f3`, et toutes les 250 ms : un parcours de **tout le sous-arbre du monde** (`_rescan_debug_counts`) et `AssetManifest.summary()` — `placeholders()` rouvre ~95 fichiers (`FileAccess.open`) à 4 Hz en dev (en export, les `.wav` sources ne sont pas dans le paquet : seulement des `exists()`).
- **Coût** : PROUVÉ (structure). ESTIMÉ : 0,1-0,3 ms/image + un pic de 0,1-1 ms toutes les 250 ms, **F3 ouvert seulement**. Deux conséquences qui comptent plus que les µs : (a) **le « IMAGES/S » que l'on lit sur F3 inclut le coût de F3** (le banc, lui, tourne F3 fermé) ; (b) **F6 est la commande que l'on demande aux testeurs** (ui.gd:1845-1848) et elle laisse F3 ouvert pour le reste de la session : les `conditions` de match envoyées (`conditions_de_match.gd:155` note seulement `build: debug|release`) mesurent alors un jeu plus lent, **sans le dire**.
- **Proposition** : assembler le texte une fois (`"\n".join(PackedStringArray)`) et ne l'affecter qu'une fois, et seulement s'il diffère ; mettre `AssetManifest.summary()` en cache (résultat statique, invalider à la main) ; faire que F6 referme F3 à la fin de la note de 4 s s'il était fermé avant ; ajouter `f3_ouvert` aux conditions de match (ou ne pas compter les images F3 ouvert).
- **Gain attendu** : F3 ouvert redevient quasi gratuit ; la télémétrie redevient interprétable. Aucun gain pour le joueur qui n'ouvre jamais F3.
- **Risque** : nul (diagnostic) ; `tools/test_conditions_de_match.gd` si on ajoute une clé.
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU (PE2.2 décrit F6, pas son effet de bord).
- **Comment le vérifier** : micro-banc (annexe A) `_update_debug` avec `debug_mode_active = true` vs `false`, 2000 itérations ; `bench_framerate` F3 ouvert/fermé en blocs alternés ; `test_conditions_de_match` si on ajoute une clé.

### HUD-08 — Shaders de l'interface non préchauffés : voile plein (premier éblouissement), `killcam_overlay` (première killcam)

- **Où** : ui.gd:67-69, 2452-2466, 3819-3841 ; voile_eblouissement.gdshader, killcam_overlay.gdshader ; modèle à suivre : fusee.gd:343-358.
- **Constat** : tous sont `preload`, **aucun n'est dessiné d'avance**. La ROADMAP le dit en toutes lettres : « *un `preload` charge le shader, mais le programme GL se compile au premier DESSIN — seule `Fusee.prechauffer()` dessine d'avance* » (l. 22510). Le voile « calme » est dessiné dès la première image (visible dès le départ) ; **le voile plein (460 lignes, `hint_screen_texture`) ne l'est qu'au premier éblouissement réel ≥ 0,12** ; `killcam_overlay` est caché (`killcam_overlay.hide()`, ui.gd:3817) jusqu'à la première killcam.
  Nuance sur le banc qui sert de référence : `tools/banc_pics.gd:25-26` écrit qu'un pic de compilation « *se paie une fois par lancement et
  jamais en match* » — vrai de ce qui est dessiné au chargement, **faux pour ces deux shaders, dessinés pour la première fois EN match**.
- **Coût** : ESTIMÉ — un hoquet **unique par session** au premier éblouissement réel (flash, fusée) et à la première mort. Ordre de grandeur mesuré ailleurs sur la même machine : 143-150 ms pour la compilation d'une lampe (ROADMAP l. 27616) ; un shader canvas est probablement moindre, non mesuré.
- **Proposition** : même patron que `Fusee.prechauffer` : un quad d'alpha nul portant chaque matériau, dessiné une image au chargement de l'arène (`rebuild_arena`), pour le voile plein (avec `niveau` = 0 : une seule copie d'écran, une seule fois) et `killcam_overlay`. Jauger au `banc_pics` (« des pics groupés au début sont une compilation »).
- **Gain attendu** : retire deux hoquets de première fois, pile sur des moments décisifs.
- **Risque** : faible (une image de dessin invisible) ; vérifier que le quad ne casse pas le noir absolu (alpha 0 strict).
- **Effort** : M.
- **Sévérité** : MINEUR (une fois par session).
- **Statut ROADMAP** : CONNU-OUVERT (l. 22510 PE3.5 ; l. 22431-22433 item 5 « La chauffe des shaders »).
- **Comment le vérifier** : `bench_framerate --chauffe-couverture` + dater les pires images ; `banc_pics` ; forcer un éblouissement à froid et relever la pire image.

### HUD-09 — Chargements à froid en début de manche : icône de gadget (lecture GPU) et glyphes

- **Où** : ui.gd:3249-3260 ; menu_icones.gd:254-274 ; assets/fonts/*.import ; charte.gd:798-808 ; ui.gd:3562-3581 (décompte).
- **Constat** :
  ```gdscript
  # ui.gd:3256-3260 — au premier update_hud où la classe change (début de manche), joueur ET adversaire
  if String(ico.get_meta("slug", "?")) != slug:
      ico.set_meta("slug", slug)
      ico.texture = MenuIcones.recadree(load(chemin)) if chemin != "" and ResourceLoader.exists(chemin) else null
  # menu_icones.gd:260 — premier appel par chemin : tex.get_image()  (lecture GPU synchrone), puis get_used_rect()
  ```
  (La fiche de classe du salon réchauffe `_recadrages` pour la classe survolée, menu_fiche_classe.gd:499 — pas pour la classe adverse.)
  Polices : `font_data_dynamic`, `preload=[]`, aucune chauffe. Le HUD et le décompte (`T_DECOMPTE` = 136 px, contour 15 px, graisse 800) rastérisent leurs glyphes à la première apparition dans la session ; les chiffres du chrono et des délais de rechargement s'ajoutent un à un.
- **Coût** : ESTIMÉ — icône : 1-5 ms, une fois par gadget et par session, à l'ouverture de manche ; glyphes : de l'ordre de la milliseconde par glyphe de grande taille avec contour, ~0,1-0,5 ms pour les petits ; quelques ms au premier affichage du HUD, puis plus rien. Tous **hors de l'action décisive** (pendant le décompte), mais au début de manche, que la liste de contrôle de l'audit désigne comme moment sensible.
- **Proposition** : le HUD-01 supprime déjà l'icône adverse. Pour le reste : précharger/recadrer l'icône à l'équipement de la classe (salon) et non au premier `update_hud` ; chauffer les glyphes par la configuration de pré-rendu de l'import des polices (`preload`) ou par un `Label` hors champ montrant une fois le jeu de caractères du HUD (chiffres, `:` `.` `%` `/`, majuscules accentuées, `·`, `—`) à chaque (taille, graisse, contour) employé — une dizaine.
- **Gain attendu** : quelques ms de hoquet de première manche en moins ; mesurable seulement par la pire image de l'échauffement.
- **Risque** : faible ; mémoire de quelques atlas.
- **Effort** : S (icône), S-M (glyphes).
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU (aucune mention de glyphes, de MSDF ou de chauffe de polices ; l. 22431 ne parle que de shaders).
- **Comment le vérifier** : `bench_framerate` (la ligne « pire image de l'échauffement », `_pire_echauffement`) HUD présent vs absent ; `--seuil-lent 8` pour dater les images lentes de début de manche.

### HUD-10 — Démarrage et mémoire : toute l'interface est construite d'avance, 16 illustrations résidentes pendant le duel

- **Où** : ui.gd:1332-1376, 4154-4664, 4599-4600 (18 `MenuApercu`), ui.gd:260-279 (`ILLUSTRATIONS`) ; menu_apercu.gd:81-84 (`load()` dans `_init`) ; assets/ui/*.png.import (`compress/mode=0`, sans mipmaps).
- **Constat** : `MenuApercu.new(chemin)` fait `_image.texture = load(chemin)` dans son constructeur : **16 fichiers uniques** (14 × 1024×640, `ill_intro_allumage` 2048×1280, `fond_hub_iso.jpg` 1920×1071 avec mipmaps), tous décodés et téléversés au lancement, **tous résidents pendant le duel** alors que le hub est caché. Importés sans perte : ≈ 14 × 1,97 Mo + 7,9 Mo + 8,2 Mo ≈ **44 Mo (58 Mo si le moteur les passe en RGBA8)**, ESTIMÉ. Le dépôt le sait en général : « *295 images importées sans perte et sans mipmaps, des fonds d'interface de 3 Mo chacun : VRAM et temps de chargement* » (ROADMAP l. 22424).
  Autres coûts de lancement (hors duel) : ~480 sites `add_child` / ~230 `.new()` dans `ui.gd` seul, de l'ordre du millier de nœuds ; 10 `get_image()` d'icônes d'arme (boutons de classe) ; vignettes de cartes peintes pixel par pixel en GDScript (`MapThumbnail.render` : `fill_rect` par cellule, ×N cartes, refaites à chaque `catalog_changed`) ; un script de 9 403 lignes à analyser/compiler.
- **Coût** : ESTIMÉ — 100-400 ms de lancement (décodage ≈ 16 × 5-15 ms ; construction ; compilation), ~44-58 Mo de textures sans usage en duel. Sur le M3 à mémoire unifiée, la pression est faible ; ce n'est pas un coût de cadence.
- **Proposition** : charger une illustration à la demande (premier survol/ouverture de l'écran), `load_threaded_request` au repos, la libérer (`texture = null`) à l'entrée en duel ; ou VRAM compressée (S3TC/BPTC) pour les `ill_*` — **décision de qualité d'Adrien** (c'est de l'artwork). Mesurer d'abord le temps de `UI._ready` (annexe A, point 4).
- **Gain attendu** : lancement plus court, ~44-58 Mo rendus ; zéro effet sur le 1 % bas d'un duel.
- **Risque** : qualité des illustrations (compression) ; un chargement paresseux ne doit jamais tomber en plein survol (fondu).
- **Effort** : M.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : CONNU-OUVERT pour les textures (l. 22424) ; NOUVEAU pour « les 16 illustrations sont chargées par le constructeur de `MenuApercu` et gardées en duel ».
- **Comment le vérifier** : `Performance.OBJECT_NODE_COUNT`/`RENDER_TEXTURE_MEM_USED` avant et après `UI` ; `PE3.3` (`vram_mo`/`textures_mo` dans le diagnostic F6, ROADMAP l. 22527) ; temps de `_ready`.

### HUD-11 — Micro-coûts par image et par événement (ANECDOTIQUES un à un)

Regroupés pour mémoire ; chacun tient en une ligne de correctif.

```gdscript
# ui.gd:2526-2528 — un appel serveur par image (×2-3), pour une valeur qui ne change pas en jeu
static func aberration_debut() -> float:
	var v: Variant = RenderingServer.shader_get_parameter_default(SHADER_VOILE.get_rid(), &"aberration_debut")
# ui.gd:8290-8295 — en ligne, 7 recherches d'action pour CHAQUE événement d'entrée, avant de savoir si un menu est ouvert
if event.is_action("p2_menu_right") or event.is_action("p2_menu_left") or … 
```

- **`_marquer_accroupi`/`_set_torch_style` : `find_child` par image** — ui.gd:2963, 3382 (+ 3417, 3518, 3521 en `--charte=pate`) : 4 parcours de sous-arbre/image pour retrouver des nœuds connus à la construction. → garder les références dans le dictionnaire de la torche.
- **`get_first_node_in_group("game_state")` ×~5 et `has_method` ×~10 par image** (9 et 20 sites dans le fichier, dont une partie par événement) — ui.gd:1693, 2506, 2518, 3131 (×2 joueurs), 3155, 3204-3229 ; `Object.get("…")` ×~50 sur des paramètres non typés (`update_hud(p1, p2, …)`). → une référence `_gs` posée à la construction ; typer `p1: Player`.
- **`EffectPolicy.curseur()` ×4 + `aberration_debut()` ×3 par image** — ui.gd:2543, 2553, 8881 ; `aberration_debut()` interroge `RenderingServer.shader_get_parameter_default(...)` (ui.gd:2527) alors que la valeur est constante en jeu. `curseur()` fait `get_node_or_null(^"GameSettings")` + `has_method` + deux appels de script (effect_policy.gd:345-352). → un cache posé par `GameSettings.effect_changed`.
- **`UI._input`** — ui.gd:8290-8295 : 7 `is_action` « p2_menu_* » avant de tester `_panneau_ouvert(...)` (8309-8311) ; en ligne, chaque événement clavier/souris/manette les paie. → tester « un menu est ouvert » d'abord.
- **Killcam** — ui.gd:2115-2120 : `killcam_timecode.text` reformaté (le compteur d'images change à chaque image) **et** override de couleur réécrit à chaque image ; `get_node_or_null(^"/root/ReplaySystem")` ×1/image. Pendant la killcam seulement.
- **Écritures disque synchrones** — settings_manager.gd:967-989 : `_save()` (ConfigFile complet) à **chaque** setter, donc à chaque cran d'un curseur de volume/d'effet (le menu d'options reste atteignable en pleine partie en ligne, la pause ne gèle rien), suivi de `effect_changed` → `_apply_menu_effects()` (ui.gd:4278-4281, ~15 affectations d'uniformes) ; audio_manager.gd:2630-2651 : trace d'écoute à chaque pose/retrait d'oreille (début/fin de manche, 2-4 fois : `poser_oreille` commence par `rendre_oreille`). → écrire au relâchement du curseur ; plafonner/tourner `diagnostic_ecoute.txt`.
- **Sévérité** ANECDOTIQUE ; **cumul** ≈ 30-80 µs/image + une poignée de µs-ms par événement. **Statut** NOUVEAU. **Effort** S chacun.

### HUD-12 — Couplages de `ui.gd` qui gênent l'optimisation (Q6 — constat, aucune refonte proposée)

`ui.gd` : 9 403 lignes (dont 3 172 de commentaires), 256 définitions (fonctions et classes internes), 204 variables membres, 218 `add_theme_*_override` (80 couleurs, 20 styleboxes, 84 constantes, 34 tailles), **aucune ressource `Theme`** posée (tout le style est par nœud). Ce qui force des mises à jour globales :

```gdscript
# ui.gd:8748 — la seule porte d'entrée du HUD de match : deux paramètres NON typés, aucun signal de changement
func update_hud(p1, p2, time_left: float, horloge: bool = true) -> void:
# ui.gd:3131 / 2506 / 2518 — l'UI retourne chercher GameState par groupe, au rythme de l'image
var gs := get_tree().get_first_node_in_group("game_state")
```

1. **Modèle « poussé » sans signal de changement.** Le HUD n'écoute rien : `GameState._process` lui pousse tout (game_state.gd:2342-2345) et chaque écriture est inconditionnelle (ui.gd:8748-8906). Sans « sale », impossible de ne rien faire quand rien ne change — d'où HUD-01, 02, 05.
2. **Aller-retour UI → GameState par groupe**, au rythme de l'image : `_maj_reserves`, `_source_du_voile`, `_deux_vues_affichees`, `_human_network_status`/`_technical_network_status` interrogent `get_first_node_in_group("game_state")` puis `has_method(...)` ; les paramètres `p1`, `p2` sont non typés (accès dynamiques, aucune optimisation de GDScript possible).
3. **Un seul `_process` et un seul `_input` pour une dizaine de préoccupations** (menu, curseurs, joystick, réseau, F3, killcam…), et un état « un menu est ouvert » **recalculé à trois endroits à chaque image** (`_un_menu_attend_un_clic`, `_endormir_le_regard_hors_menu`, `_update_focus_rings`) — par choix documenté (ui.gd:1492-1498, « *dérivé chaque image, jamais appairé* »). Cette décision, juste pour la robustesse, s'oppose à toute mise à jour événementielle.
4. **Des tests lisent le texte du source** (`test_tir_et_reserves.gd:658-660`) : extraire une fonction de `update_hud` oblige à conserver des chaînes exactes.
5. **`ui.gd` est partagé** (« à demander avant d'écrire », JOURNAL_SESSIONS) et contient à la fois menus, HUD, killcam, F3, lobby réseau (seul fichier autorisé à connaître le transport) : toute optimisation du HUD touche un fichier que d'autres chantiers modifient.
6. **Style par nœud, jamais par thème** : retoucher une couleur globale = repasser sur chaque nœud, et c'est ce style de code (réécrire l'override « au cas où ») qui a produit HUD-02.
- **Sévérité** MINEUR (information) ; **Effort** L (non proposé) ; **Statut** NOUVEAU.

---

## 3. Ce qui est déjà bien fait (à ne pas casser)

1. **Les effets de menu dorment hors usage** : `set_process(false)` par défaut (torche, rémanence, traçante, brume, gravure), `MenuTorch.viser(…, null)` ne redessine que si la flaque était allumée (menu_torch.gd:69-74), `MenuWatcher` éteint hors menu (ui.gd:1465-1482, M3), `MenuHub`/`MenuPasserby`/`enseigne_qui_meurt`/`MenuGnomon` sortent sur `visible`. Les effets du hub ne coûtent rien en duel hormis les cas listés.
2. **Les écritures de thème déjà gardées** : le chrono (`_teindre_chrono`, ui.gd:8910-8922, seuils), `CircularCooldown.set_progress`, `CartoucheReserve.poser_jauge`, `_update_health_trails`, `set_countdown` (ne rejoue qu'au changement de seconde). C'est le patron à généraliser.
3. **Plus d'allocation de `StyleBox` par image en voxel (défaut)** : `_plaques_de_cartouche` (ui.gd:3342-3366) garde les plaques sur le panneau. Le commentaire chiffre l'ancien défaut (« cent vingt par seconde »).
4. **Shaders préchargés, un matériau de pâte PARTAGÉ** (`MenuWidgets.materiau_pate()`, menu_widgets.gd:34-45 : « *un matériau par panneau les séparerait tous* »), matériau de voile **par rectangle** (équité), voile « calme » sans lecture d'écran et copie plein cadre seulement pendant un éblouissement réel (ISO10 1a : −0,53 ms/image à 1440p).
5. **Les caches de calcul coûteux** : `MenuIcones.recadree` (par chemin), `MapThumbnail` (par id@échelle), `Charte.ombre_de_silhouette` (par chemin, calculée au début de manche pour que le leurre n'ait plus qu'à lire), `local_ipv4()`.
6. **F3 fermé et F4 fermé ne coûtent rien par image** ; les comptages lourds de F3 sont à 4 Hz (`DEBUG_SCAN_INTERVAL`) et un commentaire explique pourquoi (« *ce qui n'a rien à faire dans une frame* »).
7. **`GameSettings` n'a aucun `_process`** ; `_apply_video` n'est appelé qu'aux bascules (`signaler_arene`, focus).
8. **`AventureHud`** : aucun `_process`, `visible=false` hors salle, appelé au pas fixe par la partie ; ses libellés portent leur `LabelSettings` (pas d'override de thème à rafraîchir).

---

## 4. Questions ouvertes

**À mesurer (personne d'autre que Godot ne peut trancher) :**

1. **Le moteur 4.7 court-circuite-t-il un override identique ?** C'est la clé de HUD-02. Si oui, HUD-02 tombe à ANECDOTIQUE et seuls HUD-01/03/05/06 restent. Annexe A, point 1.
2. **Le coût réel du HUD** (`update_hud` + `UI._process`) en µs : annexe A, point 2 ; puis un drapeau de banc `--sans-hud` (comme `--sans-torches`) qui masque `UI` *et* saute `update_hud`, relevé en blocs alternés de 120 images (patron `loupe-cout-voile`, plancher de bruit 0,25 ms).
3. **Deux `FontVariation` de mêmes paramètres partagent-elles leur cache de glyphes ?** `Charte.police_ui(400).get_rids() == Charte.police_ui(400).get_rids()` en trois lignes headless. Si non : un atlas neuf par appel de `Charte.appareil`, ce qui compterait pour `player.gd:3028,3306` et `bullet.gd:737` (un `police_display()` par événement).
4. **Le voile calme coûte-t-il > 0,15 ms (GPU) ?** HUD-04, à lire avec `--temps-par-vue`. Et le duel est-il lié au CPU ou au GPU sur le M3 ? Si CPU : HUD-04 n'apporte rien et HUD-01/02/03 sont les leviers.
5. **Combien de cartes perso un joueur type possède-t-il ?** (HUD-03 croît avec N ; le banc en a 6.)
6. **Temps de `UI._ready`** (HUD-10) et nombre de nœuds de l'arbre UI (`OBJECT_NODE_COUNT` avant/après).
7. **Les `CPUParticles2D` d'ambiance du hub cachés ne simulent pas** (comportement 4.x attendu) : vérifier au micro-banc (annexe A), hub caché, `emitting` vrai puis faux.

**À trancher par Adrien :**

8. `VoileEncre` (10 % de noir plein écran, jamais caché) et le voile calme à bas niveau : acceptables à alléger/demi-résolution ? Cela touche la lisibilité de la lumière et l'identité (HUD-04 B/C). Rien n'est proposé sans son accord.
9. Compression VRAM des illustrations (HUD-10) : perte de qualité acceptable pour de l'artwork de menu ?
10. F6 doit-il laisser F3 ouvert (HUD-07) ? Les `conditions` de match doivent-elles dire que F3 était ouvert ?
11. Le HUD adverse caché en ligne : confirmer qu'il peut cesser d'être *calculé* (aucune lecture de l'état adverse par l'UI) — c'est l'esprit de la décision du 2026-08-19, mais elle ne parlait que de l'affichage.

---

## Annexe A — micro-banc proposé (à écrire ; rien n'a été lancé)

`tools/banc_hud.gd`, headless, mesure en **µs** (donc sous le plancher de bruit des fps). Esquisse :

```gdscript
extends SceneTree
# godot --headless --path . --fixed-fps 60 --script res://tools/banc_hud.gd
func _init() -> void: call_deferred("_run")
func _run() -> void:
	# 1. Le moteur court-circuite-t-il un override de valeur égale ?
	var l := Label.new(); l.text = "FUSÉES 1"; root.add_child(l); await process_frame
	var t := Time.get_ticks_usec()
	for i in 20000: l.add_theme_color_override("font_color", Color.WHITE)      # même valeur à chaque tour
	var identique := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	for i in 20000:
		if not (l.has_theme_color_override("font_color") and l.get_theme_color("font_color") == Color.WHITE):
			l.add_theme_color_override("font_color", Color.WHITE)               # lecture avant écriture
	var garde := Time.get_ticks_usec() - t
	print("override identique x20000 : %d µs ; avec garde : %d µs" % [identique, garde])
	# 2. update_hud et UI._process, montés comme tools/test_tir_et_reserves.gd / test_classes.gd (gs.ui, gs.p1, gs.p2)
	#    boucle 2000 × (gs.ui.update_hud(gs.p1, gs.p2, 250.0) ; gs.ui._process(0.007) ; await process_frame)
	#    variantes : panneau 2 visible / caché ; MapGallery avec N = 6 et N = 30 tuiles ; MatchBanner au repos.
	# 3. get_rids() de deux FontVariation de mêmes paramètres.
	# 4. Time.get_ticks_usec() autour de load("res://ui.gd").new() + add_child + await process_frame  (= UI._ready).
	quit()
```

Remarques : en headless le rendu est factice mais le `TextServer`, les thèmes, les conteneurs et les notifications tournent ;
les redessins différés sont aspirés par `await process_frame` toutes les ~100 itérations. Le résultat chiffre donc la part CPU
« notifications + mise en page + refaçonnage », pas le dessin. Aucune des suites existantes ne mesure cela.

*Fin du rapport.*
