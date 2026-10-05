# Audit MEN — Menus, écrans et affiches (hors manche)

Dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1` (0.8.3 + SOLO S12). Audit du 2026-10-04, lecture seule,
Godot non lancé. Préfixe des constats : **MEN**.

Fichiers lus en entier : `menu_hub`, `menu_backdrop`, `menu_torch`, `menu_after_image`, `menu_passerby`,
`menu_watcher`, `menu_tracer`, `menu_gnomon`, `menu_engraver`, `menu_ink`, `menu_skeleton`, `menu_title`,
`menu_veil`, `menu_glass`, `menu_hatch_rect`, `menu_comic_panel`, `menu_particles_ambiance`, `menu_artwork`,
`menu_apercu`, `menu_icones`, `menu_fiche_classe`, `menu_widgets`, `menu_recitatif`, `menu_theme`,
`menu_rivets_overlay`, `menu_tampon_verdict`, `intro_planches`, `power_on`, `affiche_de_fin`, `bilan_de_soiree`,
`carte_de_soiree`, `panneau_de_soiree`, `exporteur`, `cadre_photo`, `serie_de_session`, `screen_history`,
`screen_update` ; `screen_audio`, `screen_effects`, `screen_leaderboard`, `screen_profile`, `screen_calibration` et
`match_history_view` lus par extraits et par `grep` (aucun `_process`, `Timer`, `await`, polling ni `load()` d'image : tout y est
événementiel, hors `vide_historique.png`).
Lus pour leur seul usage : les neuf `menu_*.gdshader`. Hors liste mais lus parce que la mission y remonte :
`estampe_de_kill.gd`, `match_banner.gd`, `enseigne_qui_meurt.gd`, les classes internes de `ui.gd` (l. 296-760),
`ui.gd` `_process` / `_input` / `_allumer` / `_eteindre`, `game_state.gd` (rendu des vues, fin de manche),
`settings_manager.gd` (plafond de cadence), `charte.gd` (polices), `tools/bench_framerate.gd` (mode `--menus`).
Non lus à fond (code mort ou purement événementiel, vérifié par `grep`) : `menu_arene.gd`, `screen_matchmaking.gd`.

---

## 0. Réponse courte aux cinq questions

1. **Menus qui tournent pendant un duel ?** Rien de lourd. Les fonds shaderisés, le voile, le verre, les
   particules d'ambiance, le passant, le gnomon sont des enfants du `game_over_panel` masqué : quad non dessiné,
   et leurs `_process` ne font rien (`set_process(false)` ou sortie immédiate). **Mais six à sept nœuds de menu
   restent branchés sur `_process` / `_input` à chaque image du duel** (MEN-01, MEN-02), dont deux anneaux de
   curseur qui continuent d'animer un `StyleBox` caché. Ordre de grandeur ESTIMÉ : ≲ 0,05-0,15 ms/image au total,
   non mesuré — du gaspillage proportionnel à la cadence, pas un risque pour le 1 % bas. **Plus gros, et hors de
   mes fichiers** : le HUD de `ui.gd` réécrit ≈ 16 surcharges de thème par image (MEN-11, borne haute ESTIMÉE
   ≈ 0,5 ms) — à confirmer par l'agent HUD.
2. **`_draw` procédural.** Redessiné **au changement seulement**, par épisodes courts (0,2-0,9 s) ; les exceptions
   permanentes sont minuscules (MEN-16, anneaux de curseur). `MenuHatchRect` n'a pas de `_draw` : c'est un shader
   (et c'est lui qui, dans le HUD, tourne vraiment en duel : MEN-03).
3. **`Image` sur le fil principal.** Aucun `get_image()` ni `save_png()` automatique en fin de manche. `Exporteur`
   (`get_image` + `save_png` synchrones) ne part que sur geste du joueur ; `MenuIcones` appelle `get_image()` une
   fois par icône, au menu. Le vrai travail synchrone de fin de manche est un `load()` d'image 1920×1080 par
   l'affiche (MEN-07) et l'écriture du journal JSON (MEN-12).
4. **Grosses textures synchrones.** Au démarrage : 16 illustrations (≈ 58 Mo RGBA8) décodées d'un coup et gardées
   pendant les duels (MEN-08). En fin de manche : l'affiche (MEN-07). Film d'intro : 1080p30 Theora, jamais mesuré,
   une fois par installation (MEN-14).
5. **Le menu tient-il « 1 % bas ≥ 60 » ?** **Non démontré.** Le dernier relevé date du 2026-08-18 (207 fps moyen,
   1 % bas 163/169/139, pire image 12,6-16,2 ms) et précède le hub illustré (DA4.18), l'art voxel, les panneaux de
   BD et les particules ; **et le banc `--menus` ne traverse plus aucun écran** depuis que les identifiants du hub
   ont changé (MEN-09). Par la lecture, le coût CPU du menu est faible (≲ 0,3 ms/image) ; le coût GPU domine, et
   son premier candidat n'est pas du menu : les deux `SubViewport` de l'arène rendus derrière le hub (MEN-04),
   puis le plafond de 120 images/s sur un écran 60 Hz (MEN-05) et les copies d'écran du verre (MEN-06).

---

## 1. Carte des chemins chauds

### 1.1 Pendant un duel (menu fermé) — ce qui reste branché (Q1)

`ui.hide_game_over()` (ui.gd:9272-9287) → `_eteindre(game_over_panel)` (ui.gd:5259-5284) → `_fermer_sec` → `hide()` :
tout le sous-arbre du hub cesse d'être dessiné. Ce qui suit est donc **du travail GDScript résiduel**, pas du rendu.

| Élément | Où | Appelé en duel ? | Ce qui l'arrête |
|---|---|---|---|
| Fond (`Rideau` + `menu_backdrop.gdshader`), voile `MenuVeil`, verre `MenuGlass` | ui.gd:4160-4167, 4241-4263 | non dessinés (enfants du panneau / du hub masqués) | masquage de l'ancêtre ; `MenuVeil` est de plus `visible=false` à intensité 0 (menu_veil.gd:45) |
| `MenuBackdrop` (parallaxe) | menu_backdrop.gd:61-63, 109-117 | non : `set_process(false)` au repos | `SEUIL` atteint (l. 114-116) |
| `MenuTorch`, `MenuAfterImage`, `MenuTracer`, `MenuEngraver`, `MenuInk` | menu_torch.gd:51-53, menu_after_image.gd:42-44, menu_tracer.gd:64-66, menu_engraver.gd:228-230 | non : `set_process(false)` au repos, réveillés par événement | l'événement s'éteint seul ; `ui._update_focus_rings` éteint la flaque hors menu (ui.gd:1749-1759) |
| `MenuWatcher` (le regard) | menu_watcher.gd:42-43 (pas de `set_process(false)`) | non : endormi par `ui._endormir_le_regard_hors_menu` | ui.gd:1473-1482 (corrigé le 2026-09-28, `test_regard_hors_menu`) |
| `MenuGnomon` | menu_gnomon.gd:57-72 | un `Timer` de 1 s, sortie immédiate | `is_visible_in_tree()` |
| **`MenuHub._process`** | menu_hub.gd:158-159, 766-769 | **oui, chaque image**, sortie sur `_bg_image.is_visible_in_tree()` | masquage (mais l'appel reste) |
| **`MenuPasserby._process`** | menu_passerby.gd:43-46, 59-60 | **oui, chaque image**, sortie sur `is_visible_in_tree()` | masquage (mais l'appel reste) |
| **`NeonFocusRing` ×2** (`p1_cursor`, `p2_cursor`) | ui.gd:612-699, créés l. 1351-1354 | **oui, chaque image, sans aucune garde** : `sin`, `lerp` de couleur, écriture de `_style.border_color`, `torche.modulate/position`, `global_position`, `size` — sur un nœud caché | rien |
| **`EnseigneQuiMeurt`** | enseigne_qui_meurt.gd:101-109, 177-187 ; ui.gd:6187-6188 | **oui** : `_process` + `_input` sur chaque événement ; la garde teste `_cible.visible` (drapeau **local**, vrai même sous un ancêtre masqué) | `surveiller(null)` seulement quand le titre n'est plus « CANDELA 2D » (ui.gd:6123-6124) |
| **`CPUParticles2D` ×2** (≤ 26 + 12 particules) | menu_particles_ambiance.gd:108-126, 150-172 | traitement interne appelé ; `emitting` reste `true` (coupé seulement par `masquer_doux`, effacement du fond : menu_hub.gd:911-912) | ESTIMÉ : le moteur n'avance pas les particules d'un nœud non visible dans l'arbre (non vérifiable sans lancer Godot) |
| **`MatchBanner._process`** | match_banner.gd:157-158 | **oui, chaque image** : `refresh()` fabrique un instantané (MEN-02) | rien |
| `VirtualGamepadCursor._process` | ui.gd:723-727 | oui, sortie sur `visible` | `hide()` |
| `ui._process` (familles menu) | ui.gd:1451-1463, 1473-1482, 1556-1561, 1635-1661, 1724-1738 | oui | voir MEN-11 |

Dans le HUD (et non dans le menu), **`MenuHatchRect` ×2** (« HatchAlerte ») est dessiné à chaque image de la manche
avec un matériau et un shader propres, à alpha 0 (MEN-03).

Seul le menu de **pause** se superpose à un duel vivant (en ligne la simulation continue : rideau à 0,88, voile plein écran
avec copie d'écran, flaque de torche ; ui.gd:7304-7326). Son coût additionnel pendant qu'il est ouvert est assumé par la
conception (« masquer complètement un monde qui bouge ment », ui.gd:7306-7308) ; je ne l'ai pas audité plus avant.

### 1.2 Menu ouvert — par image

| Ce qui tourne | Où | Quantité au pire cas |
|---|---|---|
| `MenuHub._process` : `effect_time` (1 uniforme, + `torch_pos` quand la souris est sur le cadre), et **2× `set_torch_position_global`** (rim-light des cadres de BD) avec `queue_redraw` à chaque image tant que la souris est sur le cadre droit | menu_hub.gd:766-793, menu_comic_panel.gd:93-137 | 2 cadres × 8-16 `draw_line` |
| Anneaux de curseur | ui.gd:673-699, 1785-1806 | 2 |
| Parallaxe du fond (jusqu'à convergence, ≈ 1,5 s) | menu_backdrop.gd:109-117 | 1 uniforme |
| Flaque de torche (pendant le mouvement, puis commandes figées mais **toujours rendues**) | menu_torch.gd:87-129 | 10 cercles × 1-2 joueurs, rayon 250 px, ≈ 0,6 Mpx de mélange par flaque |
| Particules d'ambiance | menu_particles_ambiance.gd | ≤ 38 particules |
| GPU, passes qui couvrent l'écran ou le cadre droit : fond `menu_backdrop` (plein écran, ALU + `TIME`), illustration `menu_artwork` (9 prises, cadre droit, ×2 pendant les 0,45 s du fondu), verre `menu_glass` (copie d'écran + 9 prises, cadre droit), voile `menu_veil` (plein écran + copie d'écran), titre `menu_title` (`TIME`), `MenuHatchRect` ×2-3 (trames du salon) | shaders `menu_*.gdshader` | voir MEN-04/05/06 |
| **Hors menu mais rendus derrière lui : deux `SubViewport` 2D de l'arène** | game_state.gd:5905-5926 | 2 × ≈ 957×1080 (MEN-04) |

### 1.3 Redessins procéduraux (Q2)

| Classe | Déclencheur de `queue_redraw` | Primitives | Fréquence |
|---|---|---|---|
| `MenuEngraver` | `_process` pendant la gravure | ≤ ~18 cercles | 0,5-0,9 s à chaque *changement* de code |
| `MenuInk` | `_avancer` (tween) | 10 rectangles | 0,22 s par navigation |
| `MenuTracer` | `tirer()` / `_process` | 11-12 | 0,20 s par lanceur |
| `MenuSkeleton` | `attendre/figer/reveler`, redimensionnement | 5 par cellule, ≈ 150 pour le classement | aux changements d'état ; l'animation de la bande est dans le shader (`TIME`), zéro CPU pendant l'attente |
| `MenuTorch` | `_process` tant que la lampe bouge | 20 cercles | pendant le mouvement (+ traîne) |
| `MenuAfterImage` | `_process` | ≤ 8 rectangles | 0,35 s par saut de curseur |
| `MenuPasserby` | `_process` | 8-12 cercles | 3,5 s toutes les 25-45 s |
| `MenuWatcher` | `_process` | 6 cercles | 2,5 s toutes les 25 s, **menu ouvert seulement** |
| `MenuGnomon` | `Timer` 1 Hz | 1 chaîne | 1 par seconde |
| `MenuComicPanel` | `reveler` + **`set_torch_position_global` chaque image tant que la souris est sur le cadre** | 4 + 8 lignes | permanent en survol (MEN-16) |
| `NeonFocusRing` | `_style.border_color` modifié chaque image → `changed` du `StyleBox` | 0 (c'est un `StyleBoxFlat`) | permanent, menu ouvert |
| `MenuFicheClasse.Jauge/Cone`, `CadrePhoto`, `MenuRivetsOverlay`, `Field` (calibration) | `regler()` / `NOTIFICATION_RESIZED` | 12 rects ; 7 polygones × 25 points ; 8-9 lignes | à l'événement |
| `MenuHatchRect` | — pas de `_draw` : fragment shader (220 lignes) | 1 quad | chaque image tant qu'il est visible |

### 1.4 I/O, `Image`, chargements (Q3, Q4)

| Site | Où | Nature | Quand |
|---|---|---|---|
| `Exporteur.png` | exporteur.gd:51-83 | `SubViewport` 1080×1350 `UPDATE_ALWAYS`, 2 `await`, `texture.get_image()` (rapatriement GPU), `Image.save_png()` | **sur geste** (ENTRÉE sur la carte de soirée, une fois par séance après ≥ 3 matchs) |
| `MenuIcones.recadree` / `_reflet` | menu_icones.gd:204-226, 247-274 | `tex.get_image()` + `get_used_rect()` 128², mis en cache par chemin | première apparition de chaque icône (menu) |
| `AfficheDeFin._illustration_pour` | affiche_de_fin.gd:472-490 | `load()` de `fin_victoire.jpg` / `fin_defaite.jpg` (1920×1080, lossless + mipmaps) | **à chaque fin de match** (MEN-07) |
| `CarteDeSoiree._batir` | carte_de_soiree.gd:94-96 | `load()` de `carte_soiree_fond.png` 1080×1350 | une fois par séance |
| `MenuApercu.poser` ×18 | menu_apercu.gd:76-83 ; ui.gd:4599-4600 | `load()` de 16 images | **démarrage** (MEN-08) |
| `PowerOn._composer` | power_on.gd:118 | `load()` du wordmark 776 Ko | lancement |
| `IntroPlanches.jouer` | intro_planches.gd:205-213 | `load()` du `.ogv` (ressource légère) puis décodage Theora 1920×1080 @ 30 fps pendant 35,3 s | premier lancement / « REJOUER L'INTRO » (MEN-14) |
| `MatchRecord.load_history` | match_record.gd:275-285 | lecture + `JSON.parse_string` du journal (≤ 200 entrées) | fin de manche, retour au menu, panneau Historique (MEN-12) |
| `GameSettings.set_effect` → `_save()` | settings_manager.gd:673-679, 967-989 | `ConfigFile` complet réécrit à chaque appel | par curseur d'effet / 15× par « ACTIVÉS » (MEN-15) |

Code mort confirmé par `grep` (aucun `.new()`, aucun `load()`) : `menu_arene.gd` (372 l.), `menu_tampon_verdict.gd`
(129 l.), `screen_matchmaking.gd` (963 l., cité seulement en commentaire par `ui.gd:4620`). Coût d'exécution nul,
mais 1 464 lignes que les suites continuent de porter ; `ill_accueil.png` (980 Ko, `ui.gd:4639`) ne semble jamais
chargé non plus (l'accueil montre `fond_hub_iso.jpg` via `MenuApercu`).

---

## 2. Constats

> Convention : PROUVÉ = établi par lecture du code du dépôt ; ESTIMÉ = déduit du comportement du moteur ou
> d'un ordre de grandeur, **non mesuré**. Aucun chiffre ci-dessous n'a été mesuré par moi.

### MEN-01 — Six à sept nœuds de menu gardent un `_process` / `_input` actif pendant le duel

- **Où** : `menu_hub.gd:158-159, 766-769` · `menu_passerby.gd:43-46, 59-60` · `ui.gd:612-699` (anneaux, créés
  `ui.gd:1351-1354`) · `enseigne_qui_meurt.gd:101-109, 177-187` (créé `ui.gd:6187-6188`) ·
  `menu_particles_ambiance.gd:150-172, 332-336` · `menu_hub.gd:911-912`.
- **Constat** :
  ```gdscript
  # menu_hub.gd:766 — appelé à chaque image ; la sortie ne coûte qu'un test
  func _process(delta: float) -> void:
  	if _bg_image == null or not _bg_image.is_visible_in_tree():
  		return
  # ui.gd:673 (NeonFocusRing) — AUCUNE garde de visibilité
  func _process(delta: float) -> void:
  	_time += delta
  	var wave := 0.5 + 0.5 * sin(_time * 6.0)
  	_style.border_color = neon.lerp(Charte.HALOGENE, 0.45 * wave)   # StyleBox.changed → redraw différé
  	...
  	global_position = global_position.lerp(target_rect.position, t)
  	size = size.lerp(target_rect.size, t)
  # enseigne_qui_meurt.gd:107 — garde sur le drapeau LOCAL de la cible, pas sur l'arbre
  	if not _cible.visible:
  		_repos = 0.0
  		return
  ```
  Aucun de ces nœuds n'appelle `set_process(false)` ; `hide_game_over()` ne les touche pas ; les anneaux sont
  seulement `hide()` par `_update_focus_rings` (ui.gd:1749-1751). `enseigne_qui_meurt` croit « ne compter que sur
  le menu » (commentaire l. 105-106) mais `menu_enseigne.visible` reste vrai sous un panneau masqué. Sa méthode
  `_input` est appelée pour **chaque** événement d'entrée du duel (souris, manette).
- **Coût** : PROUVÉ que ces appels ont lieu à chaque image / événement du duel. ESTIMÉ (non mesuré) : 1-2 µs pour
  `MenuHub` et `MenuPasserby` (sortie sur un booléen), 10-25 µs par anneau (écriture de `border_color` ⇒ signal
  `changed` du `StyleBoxFlat` ⇒ notification de thème et `queue_redraw` différé, plus écritures de
  `position`/`size`), ≈ 3 µs + 1-2 µs par événement pour l'enseigne ⇒ **≲ 0,05 ms/image au total**. Proportionnel
  à la cadence (déplafonnée), sans effet sur le 1 % bas.
- **Proposition** : un interrupteur unique sur le modèle déjà écrit de `_endormir_le_regard_hors_menu`
  (ui.gd:1473-1482) : à la bascule de `menu_open`, `set_process(menu_open)` sur tout un groupe `vitrine`
  (anneaux, `MenuHub`, `MenuPasserby`, `EnseigneQuiMeurt` + `set_process_input`, particules `emitting=false` /
  `process_mode = DISABLED`). Corriger la garde de l'enseigne en `is_visible_in_tree()`. Ajouter un test sur le
  patron de `tools/test_regard_hors_menu.gd` qui énumère le groupe et exige `not is_processing()` menu fermé.
- **Gain attendu** : ≲ 0,05 ms/image CPU en duel (ESTIMÉ) ; zéro sur le menu.
- **Risque** : réveil des anneaux (`_snap=true` + `aim(rect, true)` sont déjà posés par `_update_focus_rings`
  à la réouverture, ui.gd:1785-1806) ; `PROCESS_MODE_ALWAYS` à conserver pour la pause. Équité / réseau : aucun.
- **Effort** : S. **Sévérité** : MINEUR.
- **Statut ROADMAP** : CONNU-OUVERT partiel — la règle « coût nul au repos / en match » est actée (l. 11482-11484,
  11951, 12038) et appliquée nœud par nœud (regard : commit `c8cdf5c` ; torche : `test_torche_hors_menu`), mais ces
  six nœuds n'ont jamais été couverts.
- **Vérifier** : `Performance.get_monitor(TIME_PROCESS)` en duel avec / sans l'interrupteur ; profileur GDScript
  (onglet Fonctions) ; nouveau test sur le patron de `tools/test_regard_hors_menu.gd`.

### MEN-02 — `MatchBanner` fabrique un instantané de 18 clés à chaque image, duel compris

- **Où** : `match_banner.gd:132-148, 157-158` · `matchmaking.gd:357-377` · `ui.gd:4208-4209`.
- **Constat** :
  ```gdscript
  func _process(_delta: float) -> void:
  	refresh()
  func refresh() -> void:
  	var snap := _snapshot()            # get_node_or_null + 4× has_method + search_snapshot()
  	...
  	if etat == ST_IDLE:
  		_dernier_etat = etat
  		hide()
  		return
  ```
  `search_snapshot()` construit un `Dictionary` de 18 clés et appelle `state_label()`, `is_supported()`,
  `step_index()`, `step_count()`, `range_low/high()`, `range_is_open()`, `range_label()` (formate une chaîne),
  `handshake_remaining()`. Le bandeau ne s'endort jamais, y compris au repos (`ST_IDLE`), c'est-à-dire pendant
  tout le duel. Le commentaire (l. 154-156) justifie la lecture par image par le chrono, qui n'existe que pendant
  une recherche.
- **Coût** : PROUVÉ (chaque image, allocation incluse). ESTIMÉ : 10-20 µs/image (non mesuré).
- **Proposition** : n'activer `_process` que si `Matchmaker.state != IDLE` — `Matchmaker` expose déjà
  `signal state_changed(state)` et `var state` publics (matchmaking.gd:125, 139) ; à défaut, tester `mm.state`
  avant de bâtir le `Dictionary`.
- **Gain attendu** : ≈ 0,01-0,02 ms/image et ≈ 20 allocations de moins par image en duel (ESTIMÉ).
- **Risque** : faible ; `matchmaker_override` (match_banner.gd:132-135) des doubles de `tools/test_match_banner.gd`
  doit alors émettre `state_changed` ou garder un chemin de repli.
- **Effort** : S. **Sévérité** : MINEUR. **Statut** : NOUVEAU (fichier hors liste de la mission, trouvé en
  remontant `screen_matchmaking`).
- **Vérifier** : `tools/test_match_banner.gd` ; profileur GDScript en duel.

### MEN-03 — « HatchAlerte » du HUD : deux quads à fragment shader de 220 lignes, dessinés à alpha 0, et dix `set_shader_parameter` par image

- **Où** : `ui.gd:2841-2855` (création : `alpha_mix = 0.0`) · `ui.gd:8768-8774` et `8811-8817` (`update_hud`, appelé
  à chaque image par `game_state.gd:2343-2345`, dans `_process` l. 2081) · `menu_hatch_rect.gd:92-105, 127-129,
  209-222` · `menu_hatch.gdshader:143-220`.
- **Constat** :
  ```gdscript
  # ui.gd:8768 — à chaque image, pour chaque joueur, hors alerte
  p1_hp_hatch.set_alert(false)          # alert_pulse, speed, line_width, roughness = …
  p1_hp_hatch.alpha_mix = 0.0
  # menu_hatch_rect.gd:127 — aucun test d'égalité avant de pousser au matériau
  func _update_param(param_name: String, val: Variant) -> void:
  	if _mat != null:
  		_mat.set_shader_parameter(param_name, val)
  ```
  Le `ColorRect` reste `visible` toute la manche ; le shader écrit `final_color.a *= … * alpha_mix` = 0 :
  le quad est rastérisé et mélangé pour rien. Il porte son propre `ShaderMaterial` (`_init_material`, l. 121-125),
  donc casse le regroupement des appels de dessin du HUD.
- **Coût** : PROUVÉ : 10 `set_shader_parameter` par image (2 joueurs × 5) et 2 appels de dessin à matériau dédié,
  en duel. ESTIMÉ : 10-25 µs CPU/image (matériaux marqués sales ⇒ UBO reconstruit ×2) + 2 changements d'état de
  dessin ; côté fragments ≈ 2 × (12 px × quelques centaines de px) à alpha nul — négligeable. Total ≈ 0,02-0,05
  ms/image, non mesuré.
- **Proposition** : (1) dans `menu_hatch_rect.gd`, que chaque setter sorte si la valeur est inchangée
  (`if is_equal_approx(v, x): return`) — `set_alert(false)` devient gratuit au repos ; (2) `visible = alert_pulse >
  0.0 or alpha_mix > 0.0` posé par `set_alert()` pour que le quad ne soit pas dessiné au repos.
- **Gain attendu** : −2 appels de dessin et −10 mises à jour de matériau par image en duel.
- **Risque** : visuel inchangé (alpha 0 au repos) ; `tools/test_hatch_shader.gd:89-94` vérifie `alert_pulse` /
  `speed` après `set_alert` — à garder vert. Équité : aucun.
- **Effort** : S. **Sévérité** : MINEUR. **Statut** : NOUVEAU.
- **Vérifier** : `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` en duel, avant/après (−2 attendu) ;
  `tools/test_hatch_shader.gd`.

### MEN-04 — Au menu, les deux `SubViewport` 2D de l'arène restent en `UPDATE_ALWAYS` derrière un rideau opaque à 96 %

- **Où** : `game_state.gd:5905-5926` (`_accorder_rendu_aux_vues`) · `game_state.gd:6464-6466`
  (`_on_main_menu_requested` : `vp1.get_parent().show(); vp2.get_parent().show(); _accorder_rendu_aux_vues()`) ·
  `main.tscn` (`SubViewport1` 957×1080 et `SubViewport2` 958×1080, `render_target_update_mode = 4`) ·
  `presentation_3d.gd:556-563` (la garde « pas sous les menus » ne couvre que la vue iso 3D) · `ui.gd:4160-4167`
  et `charte.gd:238` (le rideau : `PATE_RIDEAU`, alpha 0,96).
- **Constat** : au menu, les deux conteneurs sont visibles ⇒ `regardees.size() == 2` ⇒
  `_rendre_dans_les_sous_vues()` et `vue.render_target_update_mode = UPDATE_ALWAYS` pour `vp1` et `vp2`. L'arène
  (sol, murs, occluders, `CanvasModulate`) est donc rendue deux fois par image pour une image que 4 % d'opacité
  laissent à peine voir. La même chose vaut pendant le film d'intro (35 s) et le `PowerOn`. `presentation_3d.gd:556-560`
  l'écrit pour la 3D (« deux rendus 3D et quatre capteurs pour une image que personne ne regarde ») ; le même
  raisonnement n'a pas été appliqué aux sous-vues 2D.
- **Coût** : PROUVÉ (les deux vues rendent au menu). Le coût réel est **non mesuré** : la ROADMAP donne 1,52-1,60
  ms pour *le second rendu d'un duel* (game_state.gd:5839-5841), mais au menu personne ne bouge et les torches sont éteintes
  (`player.gd:320`), donc moins — je n'ai pas pu établir ce que contient l'arène à cet instant (lumières de carte ?). Borne ESTIMÉE : de ≈ 0,3 ms à ≈ 3 ms par image. **C'est, par la lecture, le plus
  gros poste du menu**, loin devant les effets de vitrine.
- **Proposition** : tant que `ui._is_main_menu` et pas `sandbox_mode` / `round_active`, passer `vp1` / `vp2` en
  `UPDATE_DISABLED` (les conteneurs gardent la dernière texture derrière le rideau) — ou `UPDATE_ONCE` à
  l'ouverture du menu. `_accorder_rendu_aux_vues()` est déjà rappelée à chaque bascule (`_restore_viewports`,
  `_on_main_menu_requested`…) : c'est le point d'accord naturel. Le mécanisme existe déjà : le gel du kill (V2.1)
  coupe `vp1` / `vp2` en `UPDATE_DISABLED` pour garder l'image figée (game_state.gd:4517-4518).
- **Gain attendu** : ESTIMÉ 0,3-3 ms/image sur le menu, 0 sur le duel ; moins de chaleur (la dérive thermique est
  documentée : ROADMAP l. 2945, 20347 ; `tools/bench_framerate.gd:58-59`).
- **Risque** : **compromis visuel à signaler à Adrien, pas à trancher** — `menu_theme.gd:65-67` : « on doit
  sentir qu'il y a un monde derrière, même à l'arrêt » ; si une animation du décor transparaît à travers les
  4 %, elle se figerait. Ne pas couper en `sandbox_mode` (hôte qui attend, entraînement). Réseau / équité : aucun
  (le rendu ne porte pas la simulation).
- **Effort** : S-M. **Sévérité** : MINEUR pour le duel ; candidat n° 1 du coût du menu (à confirmer par mesure).
- **Statut ROADMAP** : NOUVEAU (la ROADMAP traite « une vue cachée ne doit pas rendre » pour le duel, l. 5830-5846 ;
  pas « une vue masquée par le menu »).
- **Vérifier** : `bench_framerate.tscn -- --menus` (après MEN-09) avec `vp1/vp2` désactivés à la main ; ou F3 +
  `Performance.get_monitor(RENDER_TOTAL_PRIMITIVES_IN_FRAME)` au menu avec / sans.

### MEN-05 — Plafond des menus : 120 images/s sur un écran 60 Hz, vsync coupée, aucun palier d'inactivité

- **Où** : `settings_manager.gd:68` (`var vsync_enabled := false`), `:250-251` (`PLAFOND_MENU := 120`),
  `:723-729` (`_apply_video`), `:752-759` (`plafond_effectif`).
- **Constat** : le menu est plafonné à 120 (« valeur de départ, pas une décision », l. 247) sur le MacBook M3 à
  écran 60 Hz de la machine de référence, vsync désactivée par défaut : ≈ 2 images rendues pour 1 affichée, et
  aucun ralentissement quand rien ne bouge (le menu au repos garde fond animé, brume, particules, verre).
- **Coût** : PROUVÉ (valeurs). ESTIMÉ : le travail GPU et CPU du menu est ≈ doublé par rapport à un plafond à 60 ;
  le relevé de 2026-08-18 donnait ≈ 200 fps avant le plafond. La ROADMAP note elle-même « Attendu, non mesuré »
  (l. 22494-22496).
- **Proposition** : plafond du menu = fréquence de rafraîchissement de l'écran
  (`DisplayServer.screen_get_refresh_rate()`, 60 sur 60 Hz, 120 sur ProMotion), plus un palier
  `PLAFOND_MENU_INACTIF = 30` après ≈ 10 s sans geste (le compteur de `enseigne_qui_meurt` existe déjà), levé au
  premier événement. Option : vsync active au menu seulement (sinon déchirement à 60 sans vsync).
- **Gain attendu** : ≈ ÷2 de la charge du menu sur 60 Hz (ESTIMÉ) ; moins de chauffe avant un duel ; 0 sur le duel.
- **Risque** : le menu paraît moins fluide à 30 en veille (personne ne le regarde) ; tearing sans vsync à 60 :
  décision d'Adrien. Les lerps du menu sont en temps réel (`menu_torch.gd:88-90`, `menu_backdrop.gd:110-113`), donc
  indépendants de la cadence. Aucun effet en arène (`plafond_effectif` rend `fps_cap` dès `_en_arene`).
- **Effort** : S. **Sévérité** : MINEUR.
- **Statut ROADMAP** : CONNU-OUVERT (PE3 « 1. Le GPU brûle pour rien hors match », l. 22414-22423 ; PE3.1,
  l. 22487-22497).
- **Vérifier** : F3 (`plafond_moteur`, ui.gd:1967) ; `powermetrics` / Moniteur d'activité sur 60 s de menu ; le
  banc `--menus` ignore le plafond (`pilotage_externe`), il ne mesure donc pas ce gain.

### MEN-06 — `menu_glass.gdshader` : les rangées de réglage (flou = 0) déclarent quand même `hint_screen_texture`

- **Où** : `menu_glass.gdshader:40` (`uniform sampler2D screen_texture : hint_screen_texture`) et `:106-109`
  (lue seulement si `flou > 0.0`) · `menu_glass.gd:57-80, 84-91` (un même shader pour le cadre droit et chaque
  rangée `Row_`) · `screen_audio.gd:180`, `screen_effects.gd:249` (rangées nommées `Row_`) · `ui.gd:4253-4254`.
- **Constat** : la règle actée à ISO10 est « Godot copie l'écran pour tout objet dont le shader **déclare**
  `hint_screen_texture`, qu'il la lise ou non… pour qu'un effet d'écran ne coûte rien quand il ne montre rien, il
  faut un second shader sans la déclaration » (ROADMAP l. 4305-4317 ; copie plein cadre : 0,53 ms à 2560×1440, l. 4316-4317).
  M14 est antérieur (2026-08-18) et son commentaire (`menu_glass.gd:57-60`) croit que seule la surface à `flou`
  copie. Rangées vitrées visibles : 4 (panneau Audio), jusqu'à 22 (Effets : 15 effets de menu + 7 de confort, repli « avancé » ouvert).
- **Coût** : PROUVÉ que la déclaration existe sur toutes ces surfaces. **Non établi** : la multiplicité des copies
  (une par objet ou une par image) ; si c'est une par objet, chaque rangée coupe la passe d'un GPU à tuiles.
  ESTIMÉ : jusqu'à N-1 copies inutiles sur ces deux écrans de réglage. Aucun coût en duel.
- **Proposition** : un second shader `menu_glass_plat.gdshader` (identique, sans la déclaration ni le bloc
  `flou`) pour les rangées ; `MenuGlass.vitrer()` choisit selon `flou`. Même méthode que
  `voile_eblouissement_calme` (ROADMAP l. 4313-4315).
- **Gain attendu** : à mesurer ; borne ESTIMÉE ≤ 0,5 ms par rangée évitée sur les écrans Audio / Effets.
- **Risque** : rendu identique par construction à `flou = 0` ; relancer `tools/test_vitrine_menus.gd`.
- **Effort** : S. **Sévérité** : MINEUR (à mesurer). **Statut** : NOUVEAU.
- **Vérifier** : A/B au banc sur le panneau Audio (`hub.show_panel("panneau_audio")`), ou comparer
  `Performance.get_monitor(TIME_FPS)` avec les rangées dévitrées à la main.

### MEN-07 — Fin de manche : l'illustration de l'affiche (1920×1080, lossless + mipmaps) est décodée de façon synchrone, dans l'image qui pose le carton, à chaque match

- **Où** : `affiche_de_fin.gd:472-490` (`ill.texture = load(chemin)`) · `game_state.gd:4614-4640`
  (`show_game_over`, `poser_bilan`, `_poser_affiche_de_fin`, `_apply_deferred_rematch` dans la même image) ·
  `assets/ui/fin_victoire.jpg.import` et `fin_defaite.jpg.import` (`compress/mode=0`, `mipmaps/generate=true`).
- **Constat** : la texture n'est tenue que par le `TextureRect` du carton ; `congedier()` → `queue_free()` la
  libère ; le match suivant la redécode. Le mot est aussi composé à ≈ 140 px avec contour dans cette image
  (`affiche_de_fin.gd:222-231`) : première rastérisation de ces glyphes à cette taille.
- **Coût** : PROUVÉ (structure). ESTIMÉ (non mesuré) : 20-60 ms de décodage WebP lossless + mipmaps + premières
  glyphes, dans l'image où le salon est reconstruit (`hub.reset/push`, `_refresh_*`). Le monde est alors figé :
  peu visible, mais le fondu `D_ENTREE` (0,34 s, affiche_de_fin.gd:277-284) démarre sur cette image longue.
- **Proposition** : `ResourceLoader.load_threaded_request(FIN_VICTOIRE / FIN_DEFAITE)` dès que le vainqueur est
  connu (début de `_do_end_round`, avant la killcam, game_state.gd:4567) puis `load_threaded_get` à la pose ; ou
  garder une référence statique après le premier usage.
- **Gain attendu** : supprime un à-coup unique de quelques dizaines de ms par match (ESTIMÉ).
- **Risque** : +11 Mo résidents si les deux images sont gardées ; le chemin précharge la bonne (le verdict est
  connu avant la killcam). Aucun risque réseau / équité.
- **Effort** : S. **Sévérité** : MINEUR. **Statut** : NOUVEAU.
- **Vérifier** : `Time.get_ticks_usec()` autour de `_poser_affiche_de_fin` ; `tools/test_carton_transition.gd`,
  `test_carton_de_fin.gd`, `test_ecran_de_fin.gd`.

### MEN-08 — 16 illustrations de menu (≈ 58 Mo en RGBA8) décodées au démarrage et résidentes pendant les duels

- **Où** : `ui.gd:260-279` (`ILLUSTRATIONS`) et `ui.gd:4599-4600` · `menu_apercu.gd:39-83` · imports
  `assets/ui/*.import` (`compress/mode=0`, lossless).
- **Constat** :
  ```gdscript
  for cle: String in ILLUSTRATIONS.keys():
  	hub.register_panel(cle, MenuApercu.new(String(ILLUSTRATIONS[cle])))   # _init → poser() → load(chemin)
  ```
  18 clés, 16 fichiers distincts (`ill_creer`/`ill_rejoindre` doublonnent `ill_creer_ligne`/`ill_rejoindre_ligne`).
  Dimensions lues dans les en-têtes PNG/JPEG : 14 × 1024×640 (≈ 2,6 Mo chacune), `fond_hub_iso.jpg` 1920×1071 avec
  mipmaps (≈ 11 Mo), `ill_intro_allumage.png` 2048×1280 (≈ 10,5 Mo, pour la seule entrée « REJOUER L'INTRO »).
  Le `TextureRect` interne est masqué (`menu_apercu.gd:60`) : ces nœuds ne servent que de détenteurs de texture
  pour `MenuHub._update_background` (menu_hub.gd:804-809). Tout reste en mémoire toute la session, duel compris.
- **Coût** : PROUVÉ (chemin, tailles). ESTIMÉ : 0,3-0,8 s de décodage synchrone au démarrage (non mesuré) ; ≈ 58 Mo
  de VRAM / RAM. Aucun effet sur la cadence du duel sur M3 (mémoire unifiée) ; pèse sur la machine minimale (H13).
- **Proposition** : (a) charger à la demande — `ResourceLoader.load_threaded_request` pour l'écran courant et ses
  voisins, libérer à l'entrée en match ; (b) à défaut, texture compressée GPU (ASTC / BPTC) pour ces fonds
  sombres : **compromis visuel à trancher par Adrien** (Q18 a fixé des cibles de fidélité mesurées, ROADMAP
  l. 29673-29711 : le banding des noirs est le risque) ; (c) sortir la planche d'intro (10,5 Mo) du chargement initial.
- **Gain attendu** : démarrage −0,3 à −0,8 s (ESTIMÉ), −58 Mo en duel.
- **Risque** : clignotement au premier survol si le chargement n'est pas prêt (prefetch du voisin) ; compression :
  banding. Réseau / équité : aucun.
- **Effort** : M. **Sévérité** : MINEUR.
- **Statut ROADMAP** : CONNU-OUVERT (PE3 « 3. Les textures », l. 22424-22430 ; PE3.3, l. 22527 : lire `vram_mo`
  dans le diagnostic F6 avant toute décision d'import).
- **Vérifier** : F6 (`vram_mo`, `textures_mo`) ; `Time.get_ticks_usec()` autour de `_build_hub_screens`.

### MEN-09 — Le banc `--menus` ne traverse plus aucun écran : ses identifiants sont périmés

- **Où** : `tools/bench_framerate.gd:522` (`var ecrans := ["accueil", "local", "amical", "classe", "custom"]`) et
  `:543-552` · identifiants réels : `ui.gd:179-217` (`"salon_local"`, `"en_ligne_amical"`, `"en_ligne_competitif"`,
  `"personnalisation"`…) · `menu_hub.gd:473-474` (`has_screen`) et `:501-506` (`push` refuse l'écran courant).
- **Constat** : à chaque traversée prévue, `hub.has_screen("local")`, `"amical"`, `"classe"`, `"custom"` rendent
  `false` ⇒ `hub.reset()` (sans glissement) ; `"accueil"` rend `true` mais `push("accueil")` est refusé (déjà
  courant). La « traversée d'écran toutes les 1,2 s » qui fait entrer dans la mesure l'encre coulée, le glissement,
  le massicot de BD et le changement de fond **n'a plus lieu**. `preconditions_menus` (l. 573-591) ne vérifie que
  l'existence de propriétés et de méthodes, pas des identifiants. Le curseur, lui, change de cible à chaque image
  (`_set_focus`), donc le coût du survol (changement d'illustration, particules, pied de cadre) est bien mesuré.
- **Coût** : PROUVÉ. Conséquence : tout chiffre `--menus` pris aujourd'hui sous-estime les images de traversée,
  précisément celles que la ROADMAP signale comme les plus lentes (l. 34304-34308 : pire image 14,5 ms).
- **Proposition** : lire les identifiants sur l'interface (`_ui.SCREEN_LOCAL`, `SCREEN_FRIENDLY`, `SCREEN_RANKED`,
  `SCREEN_CUSTOM`) et ajouter à `preconditions_menus` un contrôle bruyant `hub.has_screen(id)` pour chacun
  (« câbler, taire, diagnostiquer »).
- **Gain attendu** : un banc fiable pour trancher MEN-04/05/06 ; aucun gain de cadence.
- **Risque** : aucun sur le jeu (outil).
- **Effort** : S. **Sévérité** : MINEUR (outil de mesure). **Statut** : NOUVEAU.
- **Vérifier** : lancer le banc et compter les `screen_changed` / `_slide` pendant la mesure.

### MEN-10 — `Charte._variation` fabrique un `FontVariation` neuf à chaque appel (jusque sur chaque coup et chaque mort)

- **Où** : `charte.gd:614-623` · appelants par événement : `bullet.gd:737` (`_spawn_damage_number`, par coup),
  `player.gd:3028` et `:3306` (bandeau « FATAL », par mort), `affiche_de_fin.gd:226`, `estampe_de_kill.gd:131` ·
  ≈ 100 sites de construction (`Charte.appareil` / `enseigne`, menus + HUD).
- **Constat** :
  ```gdscript
  static func _variation(chemin: String, poids: int) -> Font:
  	...
  	var base := load(chemin) as Font
  	var v := FontVariation.new()
  	v.base_font = base
  	v.variation_opentype = {TAG_WGHT: poids}
  	return v
  ```
  Aucun cache : même (chemin, poids) ⇒ nouvelle ressource, nouveau `Dictionary`, nouvelle RID de police. Les 16
  appelants hors `charte.gd` lisent ou assignent la ressource sans la modifier (vérifié) : un cache est sûr.
- **Coût** : PROUVÉ (allocation par appel). La conséquence moteur — cache de glyphes partagé ou non entre deux
  `FontVariation` identiques, donc nombre d'atlas et d'appels de dessin du texte — **n'est pas vérifiable sans
  lancer Godot** : NON MESURÉ. Au minimum quelques µs par appel ; au pire des glyphes rastérisés deux fois et du
  texte qui ne se regroupe pas.
- **Proposition** : cache statique `{ (chemin, poids) → FontVariation }` dans `Charte`.
- **Gain attendu** : ≥ 0 ; inconnu avant mesure.
- **Risque** : faible (aucun appelant ne mute la ressource) ; relancer `tools/test_charte.gd` (graisse haute ≠
  graisse basse).
- **Effort** : S. **Sévérité** : MINEUR (à vérifier). **Statut** : NOUVEAU. Fichiers hors de mon domaine
  (`charte.gd`, `bullet.gd`, `player.gd`) — à croiser avec les agents concernés.
- **Vérifier** : `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` au menu et au HUD, avant/après ;
  chronométrer `_spawn_damage_number`.

### MEN-11 — (transmis, hors périmètre `ui.gd`) Le HUD et les libellés d'état réécrivent leurs surcharges de thème à chaque image

- **Où** : `ui.gd:1647-1659` et `1724-1738` (état réseau, ping) · `ui.gd:3369-3385` (`_set_torch_style`) ·
  `ui.gd:3438-3450` (`_habiller_la_reserve`) · `ui.gd:3128-3278` (`_maj_reserves`) · `ui.gd:2960-2965`
  (`_marquer_accroupi`) · appelants : `ui._process` (l. 1456) et `update_hud` (l. 8801-8803, 8844-8846), lui-même
  appelé à chaque image par `game_state.gd:2343-2345`. Le principe est écrit trois fois dans le même fichier :
  `ui.gd:8908-8909` (« ne s'écrit qu'aux passages de seuil : poser un override de thème à chaque frame coûte pour
  rien »), et l'aveu de `ui.gd:365-368` (« la cartouche est retriée à CHAQUE image : `_set_flare_style()` /
  `_set_gadget_style()` y remplacent le stylebox »).
- **Constat** :
  ```gdscript
  # ui.gd:3375-3381 — chaque image, pour chaque joueur (mode voxel, le défaut)
  panel.add_theme_stylebox_override("panel", _plaques_de_cartouche(panel, active, player_color))
  ...
  lb.add_theme_color_override("font_color", COLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)
  var v := panel.find_child("Verrou", true, false) as Control
  # ui.gd:1652 / 1736-1738 — chaque image
  network_status_label.add_theme_color_override("font_color", tint)
  ping_label.text = "● %d ms" % rtt
  ping_label.add_theme_color_override("font_color", tint)
  ```
  Par joueur et par image : 2 surcharges pour la torche, 6 pour les réserves (fusées, gadget : libellé, plaque,
  libellé du gadget), plus 2 `find_child` récursifs (`Verrou`, `Accroupi`), 4 `get_node_or_null` et une recherche de
  groupe (`get_first_node_in_group("game_state")`) : ≈ 16 surcharges + 18 recherches de nœud par image, plus 2
  surcharges d'état réseau. Les plaques (`StyleBoxTexture`) sont, elles, bien mises en cache
  (`_plaques_de_cartouche`, l. 3359-3366) : l'allocation a été traitée, pas la notification.
- **Coût** : PROUVÉ (appels à chaque image, duel compris). ESTIMÉ (comportement du moteur non vérifié sans lancer
  Godot) : chaque `add_theme_*_override` émet `NOTIFICATION_THEME_CHANGED` même à valeur identique (la doc de
  `begin_bulk_theme_override()` le dit : ces méthodes notifient), ce qui invalide le façonnage du texte du `Label`
  et marque la chaîne de conteneurs pour re-tri ; l'aveu de `ui.gd:365-368` va dans ce sens. Ordre de grandeur
  0,1-0,5 ms/image au HUD, **non mesuré** — la borne haute en ferait le premier poste d'interface du duel.
- **Proposition** : mémoriser par panneau le dernier état écrit `(active, teinte, verrouillée)` et ne rien écrire
  s'il est inchangé (la même discipline que `_teindre_chrono`, ui.gd:8910-8922) ; mémoriser les nœuds trouvés
  (`Verrou`, `Accroupi`, `Label`, `Icon`) au lieu de les chercher par nom ; pour les deux libellés réseau,
  mémoriser la dernière teinte et la dernière chaîne.
- **Gain attendu** : ESTIMÉ 0,1-0,5 ms/image en duel ; à mesurer par l'agent HUD (c'est son périmètre).
- **Risque** : faible (un état mémorisé de plus par cartouche : le piège est de ne pas le réarmer à un changement
  de classe ou de teinte — `_plaques_de_cartouche` a déjà ce garde). Équité / réseau : aucun.
- **Effort** : S. **Sévérité** : MINEUR (à confirmer ; borne haute ESTIMÉE ≈ 0,5 ms/image). **Statut** : NOUVEAU
  (la ROADMAP ne mentionne ce coût nulle part ; seuls le chrono et le tremblement des cartouches l'ont reconnu).
  À dédoublonner avec l'agent HUD / `ui.gd`.
- **Vérifier** : profileur GDScript (Fonctions) sur `update_hud` en duel ; `Performance.get_monitor(TIME_PROCESS)`
  avant / après ; `tools/test_hud_style.gd` et `tools/test_tir_et_reserves.gd` (garde des cartouches).

### MEN-12 — Le journal des matchs (JSON, ≤ 200 entrées) est relu et réécrit à plusieurs reprises sur le fil principal autour d'une fin de match

- **Où** : `match_record.gd:247-263, 275-285` (`append_to_history` : lecture + `JSON.stringify(history, "\t")` +
  écriture à chaque fin de match, `game_state.gd:4770-4771`) · `game_state.gd:4719-4727`
  (`_peut_etre_la_soiree`, relit tout le journal à **chaque** retour au menu tant que la carte n'a pas été montrée,
  soit les deux premiers matchs) · `screen_history.gd:157-159` (`refresh` : `recent_report` **puis**
  `session_summary`, deux lectures, la seconde formate les ≤ 200 lignes : `match_history_view.gd:248-250`).
- **Coût** : PROUVÉ (structure). ESTIMÉ : quelques ms par lecture (≈ 45 clés par entrée, ≤ 400 Ko) ; jamais dans
  la manche. **Sévérité** : ANECDOTIQUE.
- **Proposition** : un cache mémoire du journal (`static var`) invalidé par `append_to_history` / `mark_reported` ;
  une seule lecture par `ScreenHistory.refresh`. **Gain** : quelques ms au retour de match. **Risque** : faible
  (invalidation). **Effort** : S. **Statut** : NOUVEAU.
- **À noter, sans lien de coût** : `ScreenHistory.refresh()` n'est appelé qu'à la construction (`screen_history.gd:119`) ;
  `ui._on_hub_screen_changed` ne rafraîchit que les *écrans* (`_screens[id]`), pas les *panneaux*
  (`PANEL_HISTORY`, `ui.gd:4585`). Le panneau semble donc figé sur le journal du lancement — à vérifier (voir §5).

### MEN-13 — Export PNG de la carte de soirée : `get_image()` et `save_png()` synchrones sur le fil principal

- **Où** : `exporteur.gd:51-83` · `panneau_de_soiree.gd:141-165`.
- **Constat** : `await` ×2, puis `texture.get_image()` (rapatriement GPU de 1080×1350×4 ≈ 5,8 Mo), `queue_free` de
  la vue, `image.save_png(chemin)` (encodage zlib + écriture dans le dossier Images). Déclenché par ENTRÉE sur la
  carte (une fois par séance, après ≥ 3 matchs), au menu, jamais en manche.
- **Coût** : PROUVÉ (synchrone). ESTIMÉ : 50-200 ms de gel au geste du joueur (non mesuré) ; l'animation de
  confirmation démarre après. **Sévérité** : ANECDOTIQUE (sur demande, hors manche).
- **Proposition** : `save_png` dans `WorkerThreadPool.add_task` après `get_image()`. **Gain** : supprime le gel.
  **Risque** : faible (l'`Image` est une copie). **Effort** : S. **Statut** : NOUVEAU.

### MEN-14 — Film d'intro : 1920×1080 Theora à 30 fps, 35,3 s, décodé sur CPU — jamais mesuré

- **Où** : `intro_planches.gd:50, 163-172, 205-213` · `assets/video/intro/intro_a.ogv` (9,1 Mo ; en-tête Theora
  lu : image 1920×1080, 30 fps) · `game_state.gd:678-696, 699-715`.
- **Constat** : `VideoStreamPlayer` plein cadre (`expand = true`) sur un flux 1080p ; 25 mesures × 1,41 s = 35,3 s.
  Une seule fois par installation (`GameSettings.intro_vue`) et sur « REJOUER L'INTRO ».
- **Coût** : NON MESURÉ. ESTIMÉ : décodage libtheora + conversion YUV→RGB + téléversement de 8 Mo par image vidéo,
  soit quelques ms par image vidéo sur le fil principal (selon la version du moteur, une part peut être déportée) ;
  pendant ce temps le jeu rend aussi les deux sous-vues de l'arène (MEN-04). Hors duel, hors compétition.
  **Sévérité** : ANECDOTIQUE. La ROADMAP ne mentionne aucun coût de décodage (grep `theora|ogv` : l. 2485, 5297, 14935+).
- **Proposition** : si une saccade apparaît sur machine modeste, livrer une variante 1280×720 (coût de décodage
  ≈ ÷2,25). **Statut** : NOUVEAU. **Vérifier** : `Performance.get_monitor(TIME_PROCESS)` pendant l'intro.

### MEN-15 — « ACTIVÉS / DÉSACTIVÉS » des effets de menu : quinze réécritures de `settings.cfg` et quinze `effect_changed`

- **Où** : `screen_effects.gd:340-347` (`_basculer_menus`) · `settings_manager.gd:673-679, 967-989`.
- **Constat** : `set_effect` appelle `_save()` (un `ConfigFile` complet, ≈ 40 valeurs) puis émet `effect_changed`,
  qui fait réappliquer les quinze uniformes par `ui._apply_menu_effects()` ; la boucle le fait quinze fois.
- **Coût** : PROUVÉ. ESTIMÉ : quelques ms à une dizaine de ms au clic, au menu. **Sévérité** : ANECDOTIQUE.
- **Proposition** : une variante `set_effects(Dictionary)` qui sauve et émet une fois. **Effort** : S.
  **Statut** : NOUVEAU.

### MEN-16 — Redessin permanent des cadres de BD tant que la souris est sur le cadre droit

- **Où** : `menu_hub.gd:780-793` · `menu_comic_panel.gd:93-137`.
- **Constat** : `MenuHub._process` rappelle `set_torch_position_global(gpos)` des deux `MenuComicPanel` **à chaque
  image** dès que la souris est dans `_bg_image`, même immobile : `get_global_rect()`, quatre écritures de
  `Dictionary` à clés `String`, `queue_redraw()` et réenregistrement de 12 à 16 `draw_line` par cadre.
- **Coût** : PROUVÉ. ESTIMÉ : ≈ 30-40 µs/image au menu. **Sévérité** : ANECDOTIQUE. Contraire à la règle commune
  « un menu au repos ne doit rien consommer » (ROADMAP l. 11482).
- **Proposition** : ne rappeler que si la position a changé d'au moins 1 px ; remplacer le `Dictionary` par
  quatre `float`. **Effort** : S. **Statut** : NOUVEAU.

---

## 3. Ce qui est déjà bien fait (à ne pas casser)

1. **Effets de vitrine endormis par défaut, réveillés par l'événement** : `MenuTorch`, `MenuAfterImage`,
   `MenuTracer`, `MenuEngraver`, `MenuBackdrop` font `set_process(false)` dès qu'ils n'ont plus rien à changer
   (menu_torch.gd:51-53, menu_after_image.gd:42-44, menu_tracer.gd:64-66, menu_engraver.gd:228-230,
   menu_backdrop.gd:61-63), et `tools/test_vitrine_menus.gd:259-330, 679-699` le garde.
2. **« Panneau caché = quad non dessiné »** : fond, voile, verre et passant sont des enfants du
   `game_over_panel` ; `MenuVeil.set_intensite(0)` met `visible=false` (menu_veil.gd:45) pour ne pas payer une
   copie d'écran qui ne montrerait rien ; `MenuGlass` pose un matériau par surface sans état.
3. **`MenuGnomon` au `Timer` d'une seconde plutôt qu'à `_process`** (menu_gnomon.gd:15-20, 57-72) : l'ombre de
   6°/minute n'a aucune raison d'être redessinée 240 fois par seconde.
4. **Écrans à nœuds fixes** : `ScreenHistory` bâtit un pool de `SHOWN` lignes et `refresh()` ne crée rien
   (screen_history.gd:13-15, 110-111, 154-181) ; `MenuHub._apply_panel` et `_transition_vers_texture` sortent si
   la clé / la texture est déjà montrée (menu_hub.gd:730-744, 836-841) ; `MenuHub.make_entry` construit ses
   styles une fois.
5. **Shaders tous préchargés en `const … = preload(...)`** (menu_glass.gd:32, menu_veil.gd:19, menu_title.gd:24,
   menu_backdrop.gd:30, menu_skeleton.gd:31, menu_hatch_rect.gd:15, menu_widgets.gd:20) : aucun `Shader.new()` à
   la volée ; matériau de pâte **partagé** (menu_widgets.gd:25-45) pour regrouper les appels de dessin ; plaques
   de bloc en cache statique (menu_widgets.gd:460-479).
6. **`MenuSkeleton` : l'animation vit dans le shader** (`TIME`) ; le CPU ne redessine qu'aux changements d'état
   (menu_skeleton.gd:81-149), et le nœud se masque (`visible=false`) à la fin.
7. **Aucune capture automatique en fin de manche** : `AfficheDeFin` et `EstampeDeKill` sont des superpositions
   tweenées, l'export PNG est explicite et verrouillé contre le double appui (`_exporte`,
   panneau_de_soiree.gd:141-165) ; `MenuIcones.recadree/_reflet` sont mis en cache par chemin.
8. **La règle « coût nul hors menu » est déjà testée là où elle a été violée** (`tools/test_regard_hors_menu.gd`,
   `tools/test_torche_hors_menu.gd`) : c'est le patron à étendre au reste de la vitrine (MEN-01).

---

## 4. Résumé des gains attendus (tous ESTIMÉS, aucun mesuré)

| Où | Gain | Dépend de |
|---|---|---|
| Duel (CPU) | MEN-01 + 02 + 03 : ≈ 0,1-0,2 ms/image de GDScript et de mises à jour de matériau en moins ; MEN-11 (HUD, hors périmètre) : 0,1-0,5 ms ESTIMÉS en plus | rien / confirmation par l'agent HUD |
| Menu (GPU) | MEN-04 (0,3-3 ms), MEN-05 (÷2 de la charge sur 60 Hz), MEN-06 (≤ 0,5 ms/rangée) | une mesure fiable : MEN-09 d'abord |
| Démarrage | MEN-08 : −0,3 à −0,8 s, −58 Mo | décision d'Adrien sur la compression |
| Fin de manche | MEN-07 : un à-coup de quelques dizaines de ms en moins | rien |

Aucun constat CRITIQUE ni MAJEUR dans ce domaine : le menu ne coûte rien de mesurable au duel.

---

## 5. Questions ouvertes

1. **Mesure du menu actuel.** Plus aucun relevé depuis 2026-08-18, et le banc ne traverse plus d'écran (MEN-09).
   Protocole proposé à l'agent de mesure (machine refroidie, un relevé long, jamais dix courts : ROADMAP l. 20345-20348) :
   (a) corriger les identifiants du banc ; (b) `--menus` 60 s ; (c) mêmes 60 s avec `vp1`/`vp2` en
   `UPDATE_DISABLED` ; (d) avec les quinze effets à 0 (« DÉSACTIVÉS ») pour isoler le coût de la vitrine ;
   (e) avec `PLAFOND_MENU = 60`. La médiane tranche, le 1 % bas du menu est bruité à ±30 fps sur 15 s
   (ROADMAP l. 34330-34345).
2. **Le monde derrière le menu est-il voulu vivant ?** (MEN-04) `menu_theme.gd:65-67` dit « on doit sentir qu'il y a
   un monde derrière, même à l'arrêt » ; à 4 % d'opacité, un décor qui bouge se voit-il ? Décision d'Adrien.
3. **Plafond du menu et vsync** (MEN-05) : 60 ou fréquence de l'écran ? vsync au menu seulement ? Un palier
   d'inactivité à 30 est-il acceptable ?
4. **Les copies d'écran sont-elles payées une fois par image ou une fois par objet ?** (MEN-06) La ROADMAP établit
   « déclarer = copier » (l. 4305), pas la multiplicité. Une mesure A/B sur le panneau Audio le tranche.
5. **Le cache de glyphes est-il partagé entre `FontVariation` identiques ?** (MEN-10) Si oui, le défaut n'est
   qu'une allocation ; sinon il casse le regroupement du texte du menu et du HUD.
6. **CPUParticles2D caché avance-t-il ses particules ?** (MEN-01) Je n'ai pu que supposer le comportement du moteur
   (non visible dans l'arbre ⇒ pas de simulation) ; un `emitting=false` à la fermeture rend la question sans objet.
7. **Un défaut fonctionnel repéré en passant, hors optimisation** : `ScreenHistory.refresh()` n'est rappelé que par
   `_on_hub_screen_changed` pour les *écrans* ; monté en *panneau* (`_attach_panel`, ui.gd:5789-5809, `PANEL_HISTORY`),
   il n'a aucun abonnement qui le rafraîchisse à l'affichage (`ScreenProfile`, lui, écoute les signaux de
   `RankedIdentity`) — l'historique pourrait rester celui du lancement. À vérifier à l'écran ; si c'est confirmé, le
   correctif (rafraîchir sur `panel_changed` ou sur `visibility_changed`) coûte deux lectures du journal par
   ouverture (MEN-12), au menu.
8. **Chauffe de `menu_hatch.gdshader` et du texte du HUD** : le shader est utilisé par le HUD (MEN-03) mais n'est
   « chauffé » que s'il a été dessiné avant au salon (fiche de classe, `menu_fiche_classe.gd:236`). Un joueur qui
   lance une recherche amicale depuis l'écran d'illustration pourrait le compiler, ainsi que rastériser les glyphes
   du HUD, au premier affichage du HUD (décompte du premier match). PE3.5 demande de vérifier « qu'aucun shader ne
   compile encore au premier usage en match » (ROADMAP l. 22431-22433). Non vérifié.
9. **Machine minimale (H13)** : 58 Mo d'illustrations résidentes (MEN-08) et le film 1080p (MEN-14) ne se jugent
   que sur elle.
