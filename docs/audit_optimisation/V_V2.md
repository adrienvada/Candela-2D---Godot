# V2 — Vérification contradictoire : « ce qui calcule sans qu'on le voie »

Dépôt `52a29c1` (0.8.3 + SOLO S12). Lecture seule ; Godot jamais lancé. Constats vérifiés (doublons cités ensemble) :
HUD-01 · HUD-02 = ETA-03 = GAD-08 = MEN-11 · HUD-03 = CAR-01 · HUD-04 · HUD-05 = MEN-03 · HUD-06 = MEN-02 · MEN-01 ·
MEN-04 = ISO-07 · MEN-06 · ISO-04 = SHA-09 · ISO-10.

**Ce qui change la qualité de cette vérification : le moteur a été LU, pas supposé.** Les sources de **Godot 4.7.1-stable**
(la version du projet : `project.godot:16` dit « 4.7 ») sont copiées dans `audit/src/v471/` (récupérées sur GitHub, comme
l'avait fait l'auditeur RES ; rien n'est écrit hors du dossier de travail). Les numéros de ligne « moteur » ci-dessous sont
ceux de ces copies. Trois niveaux de preuve, partout :

- **PROUVÉ (dépôt)** : lu dans le code du jeu.
- **PROUVÉ (moteur)** : lu dans les sources 4.7.1.
- **ESTIMÉ** : un temps en µs/ms. **Aucun n'est mesuré.** Les coûts unitaires que j'utilise sont les miens (section 0.2) ;
  ils portent presque tout le total. Ils se mesurent en dix lignes de GDScript headless (section 4).

---

## 0. Ce que le moteur fait vraiment (et qui corrige plusieurs auditeurs)

### 0.1 Faits PROUVÉS dans les sources 4.7.1

| # | Fait | Où (moteur) |
|---|---|---|
| F1 | `add_theme_color_override` écrit puis notifie. **Aucun test d'égalité.** `_notify_theme_override_changed()` ne teste ni la visibilité ni la valeur : il suffit que le nœud soit dans l'arbre. | `control.cpp:4030-4034`, `3578-3582` |
| F2 | `add_theme_style_override` : `disconnect_changed` de l'ancienne ressource, affectation, `connect_changed(…, CONNECT_REFERENCE_COUNTED)`, puis notification — même avec la MÊME ressource. | `control.cpp:3998-4009` |
| F3 | Gestionnaire `NOTIFICATION_THEME_CHANGED` de `Control` : émet `theme_changed`, `_invalidate_theme_cache()` (vide 6 tables), `_update_theme_item_cache()`, `queue_redraw()`, `update_minimum_size()` et **`_size_changed()` tout de suite**. | `control.cpp:4628-4636`, `1888-1919`, `2160-2210` |
| F4 | `_update_theme_item_cache()` = `ThemeDB::update_class_instance_items` : **relit chaque élément de thème lié à la classe et à ses parents**, tous en défaut de cache après l'invalidation. Éléments liés : **Label 13, Button 32, PanelContainer 1**. Un défaut de cache construit un `Vector<StringName>` de dépendances puis interroge les thèmes. | `theme_db.cpp:360-376`, `control.cpp:3768-3790`, `theme_owner.cpp:178-262`, `label.cpp:1510-1523`, `button.cpp` (32 `BIND_THEME_ITEM`), `panel_container.cpp:127` |
| F5 | **Label** : le gestionnaire met `font_dirty = true`, `queue_redraw()`, `update_desired_size()`. Le refaçonnage (`_shape()`) a lieu à la prochaine demande de taille minimale ou au dessin. `Label.text` est gardé par égalité, **la couleur ne l'est pas**. | `label.cpp:912-917`, `440-451`, `991-993`, `1131-1134` |
| F6 | **Conséquence que personne n'avait vue, ordre des gestionnaires compris.** `Control` traite `THEME_CHANGED` AVANT `Label` (la classe de base d'abord) : le `_size_changed()` de `Control` appelle `get_combined_minimum_size()` → `Label::get_minimum_size()` → `_ensure_shaped()` **avant** que `Label` ne pose `font_dirty = true`. Le refaçonnage dû à une notification a donc lieu à la notification SUIVANTE, ou au dessin. Un Label **caché** ne dessine jamais : son `font_dirty` reste vrai d'une image à l'autre, et **chaque notification le refaçonne dans son propre `_size_changed()`**. Un Label visible est refaçonné au dessin (une fois par image) et, s'il est notifié deux fois dans l'image, une seconde fois. Dans tous les cas : ≈ 1 refaçonnage par notification. → **un nœud caché ne coûte pas moins qu'un nœud visible, pour le refaçonnage.** | `control.cpp:4628-4636` + `2160-2175` + `label.cpp:440-451`, `912-917` |
| F7 | **Container** : `NOTIFICATION_THEME_CHANGED` → `queue_sort()` (appel différé, une fois par image et par conteneur) ; `_sort_children` ne teste pas la visibilité. | `container.cpp:226-228`, `156-168`, `94-107` |
| F8 | **Button** : `NOTIFICATION_THEME_CHANGED` → `_shape()` (paragraphe de texte), `update_minimum_size()`, `queue_redraw()`, en plus du gestionnaire de `Control` (F3/F4). | `button.cpp:195-200` |
| F9 | `StyleBoxFlat::set_border_color` émet `changed` **sans garde** ; `StyleBoxTexture::set_modulate` est gardé par égalité ; `CanvasItem::set_modulate` / `set_self_modulate` aussi. | `style_box_flat.cpp:63-66`, `style_box_texture.cpp:150-156`, `canvas_item.cpp:575-583`, `655-663` |
| F10 | `ShaderMaterial::set_shader_parameter` et `MaterialStorage::material_set_param` (GLES3) : **aucune garde d'égalité** ; chaque appel écrit dans deux tables et met le matériau en file de mise à jour. | `material.cpp:419-451`, `material_storage.cpp:2519-2536` |
| F11 | `queue_redraw()` : un `_redraw_callback` différé par image et par nœud, **même caché** (il ne dessine alors rien). | `canvas_item.cpp:553-565`, `143-154` |
| F12 | **Copie d'écran, rasteriseur GLES3 :** au plus UNE copie automatique par appel de `canvas_render_items` (`material_screen_texture_cached`, « after a backbuffer copy, screen texture makes no further copies »), et l'étape de cull concatène tous les z-index en UN appel par canvas. `uses_screen_texture` est posé quand le code compilé **référence** la texture (une `if` à l'exécution n'y change rien ; une déclaration jamais référencée ne déclenche rien). | `rasterizer_canvas_gles3.cpp:400, 427-436, 519-532` ; `renderer_canvas_cull.cpp:76-105` ; `shader_compiler.cpp:946-951` |
| F13 | `CPUParticles2D::_update_internal` sort immédiatement si le nœud n'est pas visible dans l'arbre. | `cpu_particles_2d.cpp:709-713` |
| F14 | **`Performance.TIME_PROCESS` n'est pas une moyenne ni un échantillon d'image : c'est le MAXIMUM de `process_ticks` sur la dernière seconde, publié une fois par seconde** (et `process_ticks` inclut le `draw` du serveur de rendu). Le dépôt l'avait constaté sans en voir la cause (`tools/banc_pics.gd:255-285`). | `main.cpp:5093-5096`, `5130-5137` |
| F15 | `String.contains` = recherche linéaire depuis le début, **qui s'arrête au premier résultat** ; `Shader.code` rend le texte brut par copie à comptage de références. | `ustring.cpp:3033-3050`, `shader.cpp:141-144` |
| F16 | `Control::set_position` se termine toujours par `_size_changed()` (donc `get_combined_minimum_size()`). Ainsi `p1_panel.position = Vector2.ZERO`, écrit à chaque image par `_update_shake`, force le recalcul de toute la chaîne que les notifications viennent d'invalider. | `control.cpp:1468-1485`, `2160-2175` |

### 0.2 Coûts unitaires que j'utilise (ESTIMÉS, miens, non mesurés)

| Symbole | Quoi | Bas – haut |
|---|---|---|
| U1 | une relecture d'élément de thème en défaut de cache (F4) | 0,5 – 1,5 µs |
| U2 | refaçonnage d'un Label court (≤ 12 caractères) | 5 – 20 µs |
| U3 | surcoût fixe d'une notification (signal, vidage des caches, `queue_redraw`, `update_minimum_size`, `_size_changed`, 2-3 appels différés) | 2 – 4 µs |
| U4 | tri différé d'un conteneur de 1 à 3 enfants | 4 – 10 µs |
| U5 | un `set_shader_parameter` depuis GDScript (+0,4-0,6 µs si le nom est formaté) | 0,3 – 0,8 µs |

Dérivés : notification d'un **Label** c_L = (13 − 2-3 surcharges) × U1 + U2 + U3 ≈ **12 – 40 µs (centre 26)** ; d'un **Button**
(tuile de galerie) c_B = (32 − 5 styles surchargés) × U1 + U3 + `_shape` ≈ **18 – 49 µs (centre 33)** ; d'un **PanelContainer**
c_P = U1 + U3 + U4 + connexion/déconnexion ≈ **7 – 18 µs (centre 12)**.

---

## 1. Tableau des verdicts

| ID(s) | Verdict | Sévérité corrigée | Coût corrigé (ESTIMÉ) | Statut ROADMAP |
|---|---|---|---|---|
| HUD-02 + ETA-03 + GAD-08 + MEN-11 | CONFIRMÉ (mécanisme PROUVÉ moteur ; coût À MESURER) | MAJEUR | 0,15 – 0,56 ms, centre ≈ 0,35 ; **15-16** écritures, pas 16-18 | NOUVEAU |
| HUD-01 | CONFIRMÉ | MAJEUR si seul, MINEUR une fois HUD-02 corrigé | 0,09 – 0,3 ms en ligne (dont ~0,07-0,24 ms sont des notifications de HUD-02), 0 en écran scindé | NOUVEAU |
| HUD-03 + CAR-01 | CONFIRMÉ, **sous-estimé ×2-4** | MAJEUR | 0,1 – 0,3 ms avec 6 cartes ; linéaire en N | NOUVEAU |
| HUD-05 + MEN-03 | CONFIRMÉ | MINEUR | 15 – 40 µs | NOUVEAU |
| HUD-06 + MEN-02 | CONFIRMÉ | MINEUR | 20 – 45 µs | NOUVEAU |
| MEN-01 | CONFIRMÉ AVEC RÉSERVE (3 nœuds sur 7 coûtent quelque chose) | ANECDOTIQUE | ≤ 12 µs hors HUD-06 | CONNU-OUVERT partiel |
| MEN-04 + ISO-07 | CONFIRMÉ | MINEUR (menus seulement) | ≈ 3 ms au menu (±50 %), 0 en duel | NOUVEAU |
| HUD-04 | CONFIRMÉ AVEC RÉSERVE (existence prouvée, coût NON ÉTABLI) | MINEUR, à mesurer (pas MAJEUR) | GPU 0,05 – 0,8 ms selon la fenêtre | CONNU-OUVERT l. 16993, **périmé en partie** |
| MEN-06 | **RÉFUTÉ en l'état** (pas N copies : une seule par canvas) ; résidu réel = 1 copie au hub | ANECDOTIQUE | 0,05 – 0,3 ms, hub seulement | NOUVEAU |
| ISO-04 + SHA-09 | CONFIRMÉ AVEC RÉSERVE | MINEUR | 0,1 – 0,35 ms ; « balayage de 126 Ko » **réfuté** (10-25 µs) | NOUVEAU |
| ISO-10 | CONFIRMÉ | ANECDOTIQUE | 15 – 35 µs | NOUVEAU |

Aucun de ces constats ne recoupe OM3/OM4/OM6 du chantier OMBRES (halos, capteurs, lumière de coup, murs par contours) : rien n'est
« DÉJÀ PRIS EN CHARGE ». **Deux voisinages à coordonner, sans recouvrement de fond :** MEN-04 / ISO-07 touche `game_state.gd`
(`_accorder_rendu_aux_vues`, fichier partagé) ; ISO-04 touche `presentation_3d.gd:799-824`, dans la fonction `_suivre` où OM6 prévoit de
retoucher les capteurs (`:809-810`). Dans les deux cas : prévenir la session `candela-2d-godot-d4`, ne rien fusionner dans sa branche.

---

## 2. Blocs

### B1 — HUD-02 + ETA-03 + GAD-08 + MEN-11 : les `add_theme_*_override` réécrits à chaque image

**1. Le code.** Les quatre auditeurs ont raison sur le fond ; leurs comptes divergent. **Liste exacte** (habillage voxel =
défaut ; `Charte.habillage_par_argument` rend `voxel` sans drapeau, `charte.gd:480-487`) :

| # | Site | Nœud visé (type) | Écriture |
|---|---|---|---|
| 1 | `ui.gd:1652` | `network_status_label` (`Label` dans `HBoxContainer` dans `MarginContainer`) | couleur |
| 2 | `ui.gd:1737` | `ping_label` (`Label`) — seulement si `NetworkManager.has_rtt` | couleur |
| 3 | `ui.gd:3375` | cartouche **torche** (`PanelContainer`) ×2 joueurs | stylebox `panel` |
| 4 | `ui.gd:3380` | libellé « TORCHE » (`Label`) ×2 | couleur |
| 5 | `ui.gd:3168` | `lbl_f` « FUSÉES n » (`Label`) ×2 | couleur |
| 6 | `ui.gd:3439` (par `_set_flare_style` 3173 → 3457) | cartouche **fusées** (`CartoucheReserve`, un `PanelContainer`) ×2 | stylebox `panel` |
| 7 | `ui.gd:3446` (même chemin) | **le même `lbl_f`**, valeur identique à (5) ×2 | couleur |
| 8 | `ui.gd:3246` | `lbl_g` nom du gadget (`Label`) ×2 | couleur |
| 9 | `ui.gd:3439` (par `_set_gadget_style` 3271 → 3495) | cartouche **gadget** (`CartoucheReserve`) ×2 | stylebox `panel` |

```gdscript
# ui.gd:3375-3381 — _set_torch_style (branche voxel), appelée par update_hud 8801 et 8844
panel.add_theme_stylebox_override("panel", _plaques_de_cartouche(panel, active, player_color))
var hb := panel.get_child(0).get_child(0)
var lb := hb.get_child(1) as Label
lb.add_theme_color_override("font_color",
	COLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)
# ui.gd:3167-3173 — _maj_reserves (appelée par update_hud 8803 et 8846)
lbl_f.text = "FUSÉES —" if plafond <= 0 else "FUSÉES %d" % n
lbl_f.add_theme_color_override("font_color",
	COLOR_LUMIERE if n > 0 else COLOR_DIM)
…
_set_flare_style(p_f, n > 0, teinte)            # → _habiller_la_reserve : stylebox + couleur du MÊME Label
```

- **7 écritures par joueur** (torche 2 + fusées 3 + gadget 2) → **14**, + 1 réseau, + 1 ping en ligne = **15 en local/entraînement,
  16 en ligne**. HUD-02 a le bon compte (7) ; ETA-03 et MEN-11 comptent 8 par joueur (il y en a 7) ; GAD-08 compte « 6 par
  joueur, 12 » pour les seules réserves (il y en a 5 : `_habiller_la_reserve` ne trouve pas de nœud « Label » dans la cartouche
  du gadget, dont le libellé est un petit-enfant — `ui.gd:3444`, `3052-3099`). Les « 18 » de HUD-02 ajoutent les deux
  `NeonFocusRing`, qui ne sont pas des `add_theme_*` mais des `StyleBox.changed` (B5).
- Les deux écritures de `lbl_f` portent **exactement la même valeur** (`COLOR_DIM` est `Charte.PATE_TEXTE_SECOND`,
  `ui.gd:84`) : pas de va-et-vient, la lecture-avant-écriture proposée par HUD-02 fonctionne ; la première écriture est un pur
  doublon.

**2. La fréquence.** Chaque image rendue, sans condition de mode :
`GameState._process` (`game_state.gd:2081`) n'a aucun `return` avant `ui.update_hud(...)` (`2342-2345`, vérifié : aucun `return`
entre 2081 et 2345) ; `p1` et `p2` sont instanciés une fois (`_setup_players`, `1617-1623`) et jamais libérés, donc les deux
blocs s'exécutent **aussi aux menus, pendant la killcam et à l'écran de fin** (`match_hud.hide()` ne suspend rien,
`ui.gd:9003, 9041`). `UI._process` (`ui.gd:1451`, `PROCESS_MODE_ALWAYS` `1333`) appelle `_update_network_status()` (`1456`) à chaque
image, **même en local** (le libellé est alors vide mais l'écriture a lieu).
Écritures par image : local scindé 15 · entraînement 15 (dont 7 sur le panneau J2 caché) · en ligne 16 (dont 7 sur J2 caché) ·
menus 15 (toutes sur des nœuds cachés sauf le statut réseau).

**3. Le coût (moteur lu).** Chaque écriture déclenche F1+F3 :

- **Label** (F4-F6) : relecture de ~10 éléments de thème, remise à « sale » du texte, **refaçonnage** (au dessin s'il est visible,
  tout de suite s'il est caché), 2-3 appels différés. `lbl_f` est notifié **deux fois** : deux refaçonnages par image.
- **PanelContainer / CartoucheReserve** (F2, F7) : déconnexion + reconnexion du signal `changed` de la plaque (la même ressource),
  relecture de l'élément `panel`, **tri différé** du conteneur (le commentaire `ui.gd:364-370` — « la cartouche est retriée à
  CHAQUE image » — décrit exactement ceci, et il est exact).
- Effet induit (F16) : `UI._update_shake` écrit `p1_panel.position` / `p2_panel.position` à chaque image (`ui.gd:1829, 1836`) ;
  chaque écriture appelle `_size_changed()` → recalcul de la taille minimale de toute la chaîne que les notifications ont
  invalidée (≈ 10-20 conteneurs).

Compte par image (en ligne) : **10 notifications de Label** (4 par joueur — torche, `lbl_f` deux fois, `lbl_g` — + réseau + ping), **6 de
conteneur**, 2 recalculs de chaîne (F16). Le refaçonnage est compté UNE fois par notification, dans c_L (donc les deux notifications de
`lbl_f` paient chacune le leur : deux refaçonnages par image et par joueur). ESTIMÉ : 10 × c_L (12-40) + 6 × c_P (42-108) + 2 × (5-25)
= **≈ 170 – 560 µs**. Je garde **0,15 ms** comme plancher raisonné (marge sur U1). **Plancher 0,15 ms ; centre ≈ 0,35 ms.**
HUD-02 disait « 10-40 µs par nœud visible, 3-10 µs caché » : le chiffre « caché » est faux (F6). Sa phrase « à 5 µs la ligne
bascule en ANECDOTIQUE » est réfutée : un Label notifié coûte au moins ~12 µs.

**4. Les invariants.** Équité en ligne, lisibilité de la lumière, RPC : aucun lien (HUD seulement). Tests qui lisent le texte de
`ui.gd` : `test_tir_et_reserves.gd:657-660` exige les chaînes littérales `_maj_reserves(p1_reserves, 0, p1)` et
`_maj_reserves(p2_reserves, 1, p2)` (à conserver) ; `test_habillage.gd:750-790` relit la plage `class CircularCooldown` →
`func _build_status_bar` et interdit les couleurs chiffrées / les neutres d'appareil (un assistant sans `Color(0.` passe) ;
`test_menus_finitions.gd:281-285` et `test_classes.gd:2919-2925` appellent `_set_torch_style` / `_maj_reserves` avec des états
successifs et ne lisent que visibilité et texte : compatibles. `CartoucheReserve` ne s'adosse pas à l'écriture (son
`queue_sort()` explicite pendant la secousse, `ui.gd:397-409`). `inner.minimum_size_changed` (`ui.gd:2746-2749`) ne dépend que
des vrais changements de taille (le texte appelle lui-même `update_minimum_size`).
Piège à éviter : la comparaison de `StyleBox` est une comparaison d'identité ; `_plaques_de_cartouche` rend les mêmes objets
(`ui.gd:3359-3366`), donc elle tient — pas en `--charte=pate` (non défaut : un `StyleBoxFlat.new()` par appel).

**5. Le statut.** NOUVEAU. Précédent dans le code (pas dans la ROADMAP) : `_teindre_chrono` (`ui.gd:8908-8922`) et l'aveu
`ui.gd:364-370`. Précédent ROADMAP : l. 11059 (le chrono). Aucune occurrence de `THEME_CHANGED` / « override par image ».

**6. Verdict.** **CONFIRMÉ.** MAJEUR (plancher 0,15 ms, mécanisme prouvé au source). **Correctif minimal :** deux assistants en
lecture-avant-écriture, comme proposé par HUD-02 —

```gdscript
func _couleur_si_change(c: Control, nom: StringName, v: Color) -> void:
	if c.has_theme_color_override(nom) and c.get_theme_color(nom) == v:
		return
	c.add_theme_color_override(nom, v)
func _style_si_change(c: Control, nom: StringName, s: StyleBox) -> void:
	if c.has_theme_stylebox_override(nom) and c.get_theme_stylebox(nom) == s:
		return
	c.add_theme_stylebox_override(nom, s)
```

(`get_theme_color(nom)` sans type renvoie la surcharge présente au premier test, `control.cpp:3774-3779` : lecture sans
notification) — posés sur les 9 sites ; pour le réseau, garder la dernière teinte. Supprimer en plus la première écriture de
`lbl_f` (7 → 6 sites). **En régime établi : 15-16 → ~0 notification par image.**
**Preuve dans le cloud :** (a) *compteur indépendant du matériel* — `Control` émet le signal public `theme_changed` à chaque
notification (`control.cpp:4629`, déclaré `5139`) : brancher un compteur sur tous les `Control` de `ui` pendant 300 images de
duel monté headless et imprimer ceux qui sont notifiés à chaque image (attendu : ≈ 16 nœuds, `lbl_f` à 2 par image ; après
correctif : 0). Un `Label` sonde (`_notification` comptant `NOTIFICATION_THEME_CHANGED`) tranche en une ligne si le moteur 4.7.1
court-circuite une valeur égale (la lecture du source dit non : 1000 écritures → 1000 notifications). (b) signaux `draw` des 3
Labels de J1 et `sort_children` des 3 cartouches de J1 : ≈ 1 par image avant, ≈ 0 après. (c) temps : section 4.

---

### B2 — HUD-01 : `update_hud` nourrit un panneau caché

**1. Le code.** Exact (`ui.gd:8806-8846`, bloc `if p2:`) : tout ce que reçoit J1 est refait pour J2 — `hp`, hachure (5
`set_shader_parameter`), ~15 lectures dynamiques `p2.get(…)`, `_set_torch_style(p2_torch…)` (`8844`), `_marquer_accroupi`
(`find_child`), `_maj_reserves(p2_reserves, 1, p2)` (`8846`). `disposer_hud` cache le panneau (`ui.gd:8472` entraînement,
`8489` en ligne : `hud_panneau_p2.visible = not en_ligne`). Rien ne relie `update_hud` à cette visibilité.
L'icône de gadget adverse : `ui.gd:3256-3260` (`MenuIcones.recadree(load(chemin))`, `menu_icones.gd:254-274`) — **une fois par
changement de classe et par session** (cache `_recadrages`), pas par image : un hoquet de début de manche, ANECDOTIQUE.

**2. La fréquence.** Chaque image, mêmes appelants que B1. En ligne et à l'entraînement le panneau J2 est caché ; au menu les
deux le sont.

**3. Le coût.** Le bloc J2 en ligne = 7 notifications (4 de Label — torche, `lbl_f` ×2, `lbl_g` — soit **4 refaçonnages même cachés**, F6 ; 3 de cartouche avec tri) +
~35 µs de lectures dynamiques, formats, hachure. ESTIMÉ : (7 notifications ≈ 4 × 26 + 3 × 12, plus ≈ 15 pour le recalcul de chaîne de `p2_panel.position`, F16 ≈ 155 µs) + 20-70 µs ≈ **0,09 – 0,3 ms
(centre ≈ 0,19)**. Une fois B1 corrigé il ne reste que les 20-70 µs (la lecture des propriétés, la hachure). HUD-01 disait
« 40-60 % du coût HUD en ligne » : plausible, et le « rabais caché » qu'il supposait n'existe pas pour les Labels.
**Écran scindé : gain nul** (les deux panneaux sont affichés).

**4. Les invariants.** Équité : aucune, l'UI cesse de LIRE l'état adverse. Tests : `test_ecran_de_fin.gd:405-444` ne teste que
des `visible` ; `test_tir_et_reserves.gd:657-660` exige les deux chaînes `_maj_reserves(p1_reserves, 0, p1)` /
`_maj_reserves(p2_reserves, 1, p2)` (l'appel adverse peut rester littéralement dans le texte, sous une garde) ; les bancs qui
masquent J2 à la main (`photographe.gd:1614`, `planche_braise.gd:265`, `planche_q42.gd:428`, `banc_perception_bot.gd:314`)
n'en dépendent pas. **ETA-03 propose une garde plus large, qui n'est pas sûre :** « n'appeler `update_hud` que si
`match_hud.visible` » arrêterait aussi `_poser_voile(p1_dazzle…)` et la copie `_voile_bb` (`ui.gd:8804, 8878-8885`), qui vivent
HORS de `match_hud` (`ui.gd:2620-2650`) : un voile d'éblouissement resterait figé au niveau de la dernière image pendant l'écran
de fin. HUD-01 a raison de garder le chrono et les voiles hors de la garde. Garde correcte : `hud_panneau_p2.is_visible_in_tree()`
(pas `.visible`, qui est un drapeau local).

**5. Le statut.** NOUVEAU (la décision du 2026-08-19, `ui.gd:8441-8457`, ne parle que d'affichage).

**6. Verdict.** **CONFIRMÉ.** MAJEUR si pris seul (0,09-0,3 ms en ligne), MINEUR comme résiduel après B1. **Correctif minimal :**
`var j2_vu := hud_panneau_p2 != null and hud_panneau_p2.is_visible_in_tree()` et `if p2 and j2_vu:` autour du bloc J2 ; le
voile de J2 (`8870-8873`), le chrono, et **`p2_target_hp = p2.hp`** (sinon `p2.hp < p2_target_hp` déclencherait une secousse de 0,2 s
parasite à la réouverture, `ui.gd:8807-8809`) restent dehors. Le panneau redevenu visible est rafraîchi dès l'image où il l'est :
`update_hud` tourne chaque image et teste la visibilité à ce moment-là.
**Preuve cloud :** `update_hud(p1, null, t)` contre `update_hud(p1, p2, t)` avec `hud_panneau_p2.visible = false`, en µs (section 4) ;
recensement `theme_changed` : les nœuds de `p2_torch`/`p2_reserves` disparaissent de la liste.

---

### B3 — HUD-03 + CAR-01 : `MapGallery._process` caché, N notifications de bouton par image

**1. Le code.** Exact et confirmé :

```gdscript
# map_gallery.gd:89-91 — la galerie traite même arbre en pause
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
# map_gallery.gd:608-616
func _process(delta: float) -> void:
	_pulse += delta
	if _style_selected != null:
		var wave := 0.5 + 0.5 * sin(_pulse * 4.0)
		MenuWidgets.reteindre(_style_selected, COLOR_P1.lerp(Charte.HALOGENE, 0.4 * wave))
# map_gallery.gd:324-325 — LE MÊME style, posé sur CHAQUE tuile
tile.add_theme_stylebox_override("pressed", _style_selected)
tile.add_theme_stylebox_override("hover_pressed", _style_selected)
# menu_widgets.gd:532-541 — voxel (défaut) : le style est un StyleBoxTexture
tex.modulate_color = teinte        # émet `changed` (la teinte change chaque image : sinusoïde)
```

Aucune garde de visibilité ni `set_process(false)` (grep sur `map_gallery.gd` : aucun `set_process`). `register_panel` fait
`content.hide()` (`menu_hub.gd:405-410`) : la galerie est cachée tant que l'écran des cartes n'est pas affiché, et sous le hub
masqué pendant un duel.

**2. La fréquence.** Chaque image de la session, duel compris. N = `MapData.list_maps().size()` = 6 cartes livrées
(`assets/maps/*.json`) + les cartes de `user://maps` (`map_data.gd:81-82`, 28-29).

**3. Le coût (moteur lu).** Une tuile est un **`Button`**, pas un `Label`. `StyleBoxTexture::set_modulate` émet `changed`
(F9), et chaque tuile y est connectée par F2 (une connexion par tuile malgré les deux noms : `CONNECT_REFERENCE_COUNTED`) →
`_notify_theme_override_changed` → F3 **sur un nœud caché mais dans l'arbre** : relecture des éléments de thème du `Button`
(32 liés, 5 styles surchargés ⇒ 27 défauts de cache, F4), `_shape()` du bouton (F8), `_size_changed()`, appels différés.
c_B ≈ 18 – 49 µs (centre ≈ 33) ⇒ **6 cartes : 0,1 – 0,3 ms (centre ≈ 0,2)** ; 30 cartes perso : 0,5 – 1,6 ms. Les auditeurs
avaient 5-15 µs par tuile (HUD-03) et 5-10 µs (CAR-01) en la traitant comme un `Label` : **sous-estimé ×2-4**. Leur raisonnement
sur la croissance avec N est juste, et c'est ce qui en fait le poste le plus sensible aux données du joueur.

**4. Les invariants.** Aucun test ne lit la respiration (`test_habillage.gd:596` scanne `map_gallery.gd` pour des couleurs,
rien sur `_process`) ; `_on_tile_pressed` est appelé directement par `test_audit_menus.gd:605` et `test_entrainement_carte.gd:158`.
Le minuteur de confirmation de suppression vit dans `_process` (`map_gallery.gd:618-621`) : à la mise en sommeil, appeler
`_disarm_delete()`. Équité / réseau / déterminisme : aucun.

**5. Le statut.** NOUVEAU. Le principe est acté (« les effets de la vitrine coupent tous leur traitement au repos, par
conception », ROADMAP l. 34297), appliqué nœud par nœud (`MenuWatcher`, `MenuTorch`…), jamais à la galerie.

**6. Verdict.** **CONFIRMÉ**, estimation corrigée à la hausse. MAJEUR (0,1-0,3 ms à 6 cartes, croissant avec N, correctif de 4
lignes sans risque). **Correctif minimal :** dans `_ready`, `visibility_changed.connect(_sur_visibilite)` puis
`func _sur_visibilite(): set_process(is_visible_in_tree()); if not is_visible_in_tree(): _disarm_delete()` (le signal part aussi
quand un ancêtre se cache). **Preuve cloud :** `gallery.is_processing() and not gallery.is_visible_in_tree()` est vrai
aujourd'hui (rouge après correctif) ; `gallery._style_selected.get_signal_connection_list("changed").size() == N` ; recensement
`theme_changed` : N `Button` à ≈ 1 notification par image ; µs avec `gallery.set_process(false)` pour N = 6 puis 30 (copier des
cartes dans `user://maps/`).

---

### B4 — HUD-05 + MEN-03 : la hachure d'alerte, dix `set_shader_parameter` par image

**1. Le code.** Confirmé.

```gdscript
# ui.gd:8768-8774 (J1) et 8811-8817 (J2) — chaque image
if p1.hp <= 30.0 and p1.hp > 0.0: p1_hp_hatch.set_alert(true, Charte.ROUGE, 3.5); p1_hp_hatch.alpha_mix = 0.70
else:                              p1_hp_hatch.set_alert(false);                    p1_hp_hatch.alpha_mix = 0.0
# menu_hatch_rect.gd:72-75 — chaque setter pousse sans comparer ; 127-129 ; 209-222 (set_alert(false) = 4 setters)
var alpha_mix: float = 1.0:
	set(v):
		alpha_mix = v
		_update_param("alpha_mix", alpha_mix)
```

Le `ColorRect` reste visible et son shader écrit `final_color.a *= … * alpha_mix` (`menu_hatch.gdshader:216`) : dessiné à alpha 0.

**2. La fréquence.** Chaque image (même chemin que B1) ; 5 setters par joueur à pleine santé, 8 sous 30 PV.

**3. Le coût.** 10 × U5 (≈ 3-8 µs) + 2 mises à jour de bloc d'uniformes (F10 : pas de garde ; le matériau est propre à chaque
hachure, `menu_hatch_rect.gd:121-125`) ≈ 4-12 µs + un appel de dessin à matériau dédié par hachure visible (1 en ligne, 2 en
scindé) ≈ 5-20 µs. **≈ 15 – 40 µs.** GPU : ~3 600 px par barre de 340×12, ALU simple, sans lecture d'écran ni `hint_screen_texture`
(`menu_hatch.gdshader` : aucun) : nul.

**4. Les invariants.** `tools/test_hatch_shader.gd:62-98` vérifie `alert_pulse`/`speed` après `set_alert` : vert avec des setters
idempotents. Première valeur : `_sync_all_params()` pousse tout à `_ready` (`menu_hatch_rect.gd:111-115, 145-164`), donc un setter
qui sort sur « valeur égale » ne perd rien. Les défauts GDScript égalent ceux du shader pour les paramètres de la hachure.

**5. Le statut.** NOUVEAU.

**6. Verdict.** **CONFIRMÉ.** MINEUR (15-40 µs). **Correctif minimal :** `if is_equal_approx(v, x): return` dans les setters de
`menu_hatch_rect.gd` (un seul fichier, 16 propriétés ; `Color` : `v == x`) + côté HUD seulement (`update_hud`, pas dans les setters
génériques, que les menus utilisent avec `alpha_mix = 1`) `p1_hp_hatch.visible = alerte` (retire 1 à 2 appels de dessin à alpha 0).
**Preuve cloud :** une sous-classe de test `extends MenuHatchRect` qui surcharge `_update_param` pour compter
(`_update_param` est une méthode GDScript, surchargeable) : `set_alert(false)` ×120 images → 600 appels avant, 0 après ;
`RENDER_TOTAL_DRAW_CALLS_IN_FRAME` sous llvmpipe : −1 en vue unique.

---

### B5 — HUD-06 + MEN-02 : anneaux de curseur et bandeau de recherche qui traitent cachés

**1. Le code.** Confirmé.

```gdscript
# ui.gd:673-699 — NeonFocusRing._process, jamais set_process(false) (grep : aucun dans ui.gd pour p1_cursor/p2_cursor)
_style.border_color = neon.lerp(Charte.HALOGENE, 0.45 * wave)      # StyleBoxFlat : émet `changed` SANS garde (F9)
torche.modulate = Color(neon, 0.72 + 0.28 * wave); torche.position = …; global_position = …; size = …
# ui.gd:1749-1751 — hors menu : seulement hide(), à chaque image
p1_cursor.hide(); p2_cursor.hide()
# match_banner.gd:157-165
func _process(_delta: float) -> void:
	refresh()                              # _snapshot() → _usable() → get_node_or_null + 4 has_method → search_snapshot()
# matchmaking.gd:357-377 — Dictionnaire de 18 clés (compté : state … last_error)
```

**2. La fréquence.** Chaque image de la session, duel compris ; le bandeau reste en `ST_IDLE` (`match_banner.gd:168-171`, `hide()`).

**3. Le coût.** Anneau : `border_color` émet `changed` → F3 sur un `Panel` caché (1 élément de thème surchargé : ~2-4 µs) +
`modulate`/`position`/`global_position`/`size` (chaque `set_position` finit par `_size_changed`, F16) ≈ 8-12 µs ; ×2. Bandeau :
`get_node_or_null` à chemin absolu + 4 `has_method` + `call` + un Dictionnaire de 18 entrées (18 insertions de `Variant`) et quelques
chaînes + une douzaine d'appels de fonction ≈ 5-12 µs. **≈ 20 – 45 µs au total** (HUD-06 : 20-60 ; MEN-02 : 10-20 : cohérent).

**4. Les invariants.** `tools/test_match_banner.gd` injecte un faux cœur par `matchmaker_override` (`match_banner.gd:132-135`) :
un réveil sur `Matchmaker.state_changed` (signal existant, `matchmaking.gd:125`) doit être doublé d'un repli quand l'override
est posé. Anneaux : au `show()`, `_update_focus_rings` fait déjà `aim(rect, true)` (snap) ; `PROCESS_MODE_ALWAYS` à garder pour
la pause. Tests : `test_torche_hors_menu`, `test_audit_menus`.

**5. Le statut.** NOUVEAU (même famille que M3, `ui.gd:1465-1482`).

**6. Verdict.** **CONFIRMÉ.** MINEUR (20-45 µs). **Correctif minimal :** anneaux : `set_process(false)` à la création et
`visibility_changed → set_process(visible)` ; bandeau : `set_process(false)`, réveil par `state_changed` et à l'état courant ≠ `ST_IDLE`.
**Preuve cloud :** `p1_cursor.is_processing()`/`match_banner.is_processing()` en match (vrais aujourd'hui) ; compteur d'appels de
`search_snapshot` par un faux cœur injecté (déterministe : 1 par image avant, 0 au repos après).

---

### B6 — MEN-01 : « six ou sept nœuds de menu gardent `_process` / `_input` actifs »

**1-3.** Vérifié nœud par nœud : `MenuHub._process` (`menu_hub.gd:766-768`) et `MenuPasserby._process` (`menu_passerby.gd:59-61`)
sortent sur `is_visible_in_tree()` (< 1 µs chacun) ; `VirtualGamepadCursor._process` sort sur `not visible` ;
`MenuParticlesAmbiance` n'a **aucun `_process`** et ses deux `CPUParticles2D` (`emitting = true`) sortent dès `_update_internal`
si le nœud n'est pas visible dans l'arbre (F13, **le doute de MEN-01 est levé**) ; `EnseigneQuiMeurt` coûte ~2-4 µs plus un `_input` par
événement (~1 µs ; sa garde `_cible.visible` est un drapeau local, `enseigne_qui_meurt.gd:107` : elle vieillit pendant un duel,
mais le moindre appui la réveille). Les deux anneaux et le bandeau sont les vrais coûts : ils sont comptés en B5.
**Verdict : CONFIRMÉ AVEC RÉSERVE, ANECDOTIQUE** (≤ 12 µs hors B5 ; 3 nœuds sur 7 coûtent quelque chose). **Statut :** CONNU-OUVERT partiel (règle « zéro au repos », ROADMAP
l. 11482-11484 ; appliquée à `MenuWatcher`/`MenuTorch`). **Correctif :** l'interrupteur « vitrine » de MEN-01 est bon mais le gain
propre est faible ; faire B5 et laisser le reste. **Preuve cloud :** test sur le patron de `test_regard_hors_menu.gd`
(`not is_processing()` menu fermé).

---

### B7 — MEN-04 + ISO-07 : deux `SubViewport` 2D rendus sous le menu

**1. Le code.** Confirmé.

```gdscript
# game_state.gd:5905-5927 — _accorder_rendu_aux_vues
for vue in [vp1, vp2]:
	var conteneur := vue.get_parent() as Control
	if conteneur != null and conteneur.visible: regardees.append(vue)
…
var vu: bool = conteneur != null and conteneur.visible and not _rendu_racine
vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS if vu else SubViewport.UPDATE_DISABLED
# game_state.gd:6463-6466 — retour au menu : on remontre les DEUX conteneurs
vp1.get_parent().show(); vp2.get_parent().show(); _accorder_rendu_aux_vues()
```

`main.tscn:34, 48` : `render_target_update_mode = 4` (UPDATE_ALWAYS) sur `SubViewport1`/`2` : au **lancement** (aucun accord avant le premier
match) les deux rendent déjà.

**Ce qui est réellement rendu au menu** (demandé) :

- **Vues :** `vp1` (957×1080) et `vp2` (958×1080), `world_2d` partagé (`vp2.world_2d = vp1.world_2d`, `game_state.gd:609`), en
  `UPDATE_ALWAYS` : le sol, le décor cuit, les murs, les occulteurs, les deux joueurs, restés à leur point d'apparition (rien ne les
  masque au retour au menu, `game_state.gd:6413-6422`), et les lumières **toujours allumées** : le halo ambiant de chaque joueur
  (`ambient_light`, `shadow_enabled = true`, énergie 0,8, aucun `enabled` basculé : `player.gd:896-913`, grep) — `body_light` et la
  torche sont éteintes (`flashlight_on = false` `player.gd:320`, `flashlight.enabled = false` `813`, `body_light.enabled = false` `854`). Chaque vue rend donc le monde 2D complet et recalcule la carte d'ombre de ces deux halos
  (règle du moteur citée par `CONTEXTE_CHANTIERS_EN_COURS.md` : « pour CHAQUE viewport »).
- **Iso :** éteinte. `Presentation3D._vues_a_projeter` renvoie une liste vide quand `_is_main_menu` (`presentation_3d.gd:556-563`) ;
  `_eteindre()` libère les capteurs (`_retirer_capteurs`, `664`), la peinture et rend les calques. **Aucun capteur 256² n'existe au menu.**
- **Le rideau :** `PATE_RIDEAU = Color(0.0375, 0.0315, 0.0255, 0.96)` (`charte.gd:238`) sur un `ColorRect` du `game_over_panel`
  (`ui.gd:4160-4167`). **Il n'est pas opaque : 4 % de l'arène passe**, et c'est voulu (« on doit sentir qu'il y a un monde derrière »,
  `menu_theme.gd:65-67` ; `menu_backdrop.gdshader:143-145` : « l'alpha n'est jamais touché : c'est lui qui dit combien d'arène passe »).
  Mais l'image qui passe est quasi noire : `arena.tscn:31-32` `CanvasModulate` noir, torches éteintes ; il ne reste que les deux
  halos ambiants. 4 % de lueurs ≤ 0,8 ⇒ au plus quelques /255 au centre des halos : **invisible en pratique**, sans être nul.
  **Réponse à la réserve d'ISO-07 (« le hub est-il opaque dans tous ses écrans ? ») :** le rideau est UN seul `ColorRect` plein cadre,
  enfant direct de `game_over_panel` et placé sous tout le contenu (`ui.gd:4160-4167`) : toutes les pages du hub (galerie, fiche de
  classe, réglages…) se superposent à lui, donc partagent exactement ce 96 %. Le voile `MenuVeil` n'existe pas (B9).

**2. La fréquence.** Chaque image tant que le joueur est au menu, pendant l'intro (35 s, `IntroPlanches` plein écran ;
`ui.menu_voile = true`, `game_state.gd:690`) et le `PowerOn` ; jamais en duel (en match, `_restore_viewports` n'allume que la vue
regardée). **Même gaspillage, non listé par les auditeurs :** à l'écran de fin de match, une fois la killcam passée,
`_abort_killcam` rappelle l'accord (`game_state.gd:4978`) et rallume la ou les vues regardées derrière le même rideau.

**3. Le coût.** Ancre du dépôt : « 2ᵉ vue 2D, torches éteintes, **1,52 – 1,60 ms** » (ROADMAP, tableau « D'où viennent les
millisecondes du duel », l. 34099 ; `game_state.gd:5839-5841`). Deux vues ⇒ **≈ 3 ms (±50 %)**, ESTIMÉ ; l'arène a gagné
des éléments depuis août (LED, encre, halos ombrés), l'état du menu est plus calme que le duel. MEN-04 disait 0,3-3 ms : son bas est
trop bas, ISO-07 dit ~3 ms : retenu. **Utile surtout à la chaleur / la batterie** (menu plafonné à 120 i/s sur écran 60 Hz,
`settings_manager.gd:250-251`), 0 pour le 1 % bas d'un duel (dérive thermique documentée : ROADMAP l. 2945, 20347).

**4. Les invariants.** (a) Compromis visuel à **signaler à Adrien, pas à trancher** : `UPDATE_DISABLED` fige la dernière image
(les halos ne vacillent pas, donc rien ne se verrait de plus) ; `UPDATE_ONCE` à l'entrée du menu garde une image fraîche. (b) **La
correction doit vivre dans `_accorder_rendu_aux_vues`** (8 sites d'appel directs : 5 dans `game_state.gd` — `4525`, `4978`, `6307`,
`6333`, `6466` —, 3 dans `presentation_3d.gd` — `613`, `710`, `743` —, plus les 9 appelants de `_restore_viewports`) et non à côté : le
gel du kill (`game_state.gd:4517-4525`) et `Presentation3D._eteindre` (`presentation_3d.gd:710`) le rappellent et réécriraient
`UPDATE_ALWAYS`. (c) **Ordre d'appel :** `_on_main_menu_requested` appelle l'accord (`6466`) **avant** `ui.show_main_menu()` (`6468`) ;
à cet instant `_is_main_menu` est encore faux (`show_main_menu` le pose, `ui.gd:9002`, et ne touche pas aux vues) — il faut rappeler
l'accord après, ou inverser. (d) Ne pas couper en `sandbox_mode` (hôte qui attend dans l'arène), à l'entraînement, ni en manche, ni
pendant la killcam (qui se rend dans `vp1`). (e) Le démarrage n'appelle aucun accord (`_ready` finit par `ui.show_main_menu()` ou par l'intro,
`game_state.gd:657-662`) : l'y ajouter. (f) `game_state.gd` est un fichier partagé (CLAUDE.md) et le chantier OMBRES (session
`candela-2d-godot-d4`) touche aussi aux vues et aux capteurs : **ne rien fusionner dans sa branche, lui envoyer le delta**.

**5. Le statut.** NOUVEAU : la ROADMAP règle « une vue cachée ne doit pas rendre » pour le duel (décision l. 2565 ; mesure l. 34099 ;
code `game_state.gd:5830-5846`, dont les numéros de ligne cités par MEN-04 « l. 5830-5846 » sont ceux de ce commentaire, pas de la
ROADMAP) ; pas « une vue masquée par le menu ». Ne recoupe pas OM6 (capteurs / halos de PNJ en duel).

**6. Verdict.** **CONFIRMÉ.** MINEUR (menus). **Correctif minimal :** dans `_accorder_rendu_aux_vues`, `if ui != null and ui._is_main_menu
and not sandbox_mode and not round_active: vue.render_target_update_mode = UPDATE_ONCE/DISABLED` ; rappeler l'accord après
`ui.show_main_menu()` et au démarrage. **Preuve cloud :** test headless : après `show_main_menu()`, `vp1/vp2.render_target_update_mode`
vaut `UPDATE_DISABLED` (rouge aujourd'hui) ; *compteur indépendant du matériel* sous Xvfb + llvmpipe
(`tools/cadence_cloud/`) : `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` et `RENDER_TOTAL_PRIMITIVES_IN_FRAME` au hub avant / après (attendu :
les appels de dessin de l'arène 2D × 2 vues disparaissent du compteur — l'ordre de grandeur est la centaine par vue, d'après les
« 199 appels, duel vue de dessus » de `CONTEXTE_CHANTIERS_EN_COURS.md`, **à relever** : il n'a jamais été pris au hub) ; temps relatif
seulement (`prise.sh` : « relative seulement »). **Les passes d'ombre n'apparaissent pas dans ce compteur** (même fichier de contexte) :
le gain en ms ne se lit donc que sur le temps d'image.

---

### B8 — HUD-04 : deux aplats plein écran permanents

**Les deux passages de la ROADMAP, lus.**
- **l. 16993** (point 3 de la liste « signalé, pas corrigé ») : `p1_dazzle` reste `visible` à alpha 0, donc mélangé plein écran à
  chaque image ; le remède proposé est `rect.visible = niveau > 0.001`.
- **l. 26514-26545** (ISO10, 1a) : la rétrodiffusion de sa propre torche tient le niveau à **0,06 en permanence** ; la copie plein cadre
  et l'aberration étaient donc actives au repos ; remède : un second shader (`voile_eblouissement_calme.gdshader`) **sans lecture
  d'écran**, choisi sous `aberration_debut` (0,12) ; mesuré **0,53 ms par image** (`--plan=loupe-cout-voile`, fenêtre native au
  Cloître, 14,35 ms « copie + voile plein forcés » contre 13,82 ms « voile calme »).

**1. Le code.** Confirmé : `VoileEncre` `Color(NOIR, 0.1)` plein cadre, jamais caché (`ui.gd:2582-2587` ; grep : aucune autre
référence). `_poser_voile` (`ui.gd:2531-2575`) pose le niveau à chaque image et choisit le matériau calme sous `aberration_debut()`.
Torche allumée : `Eblouissement.RETRODIFFUSION = 0.06` (`eblouissement.gd:174`) × `gain_taille` (1,0 : `EXPOSANT_TAILLE = 0.0`,
`eblouissement.gd:199-205`) × `facteur_de_lampe_a` (`game_state.gd:2573-2574`) ⇒ `niveau ≈ 0,06 > 0,001` ⇒ la branche lourde du
fragment est prise (`voile_eblouissement.gdshaderinc:307-310`) : 2 lueurs + 5 flares + 5 fantômes (défauts des uniformes, que
`_forger_voile` ne change pas) = **12 `texture()`** et **≈ 55 `sin`/`cos`** (4 pour le tremblement et l'axe, 3 par lueur, 5 par flare, 4 par
fantôme), dont la grande majorité ne dépend que d'uniformes. Côté CPU, `_poser_voile` pose 5 uniformes et appelle `EffectPolicy.curseur`,
`GameSettings.current_effect`, `Presentation3D.angle_ecran` : ≈ 10-25 µs par image, **rangé sous HUD-11 (hors mission), non compté en §3**.

**Constat sur la ROADMAP :** le défaut l. 16993 est **périmé en partie** — son remède (`visible = niveau > 0.001`) ne couvre plus
l'état courant d'un duel torche allumée (le voile est alors réellement dessiné), seulement torche éteinte (où le fragment sort sur
`COLOR = vec4(0)`, un quad transparent). Et la mesure de 0,53 ms **n'isole pas** le voile calme : elle compare « plein + copie » à
« calme », jamais « calme » à « rien ».

**3. Le coût.** Non établi. Raisonnement : à 3,7 Mpx (fenêtre debug ×2 = 2560×1440, celle des relevés Mac) un fragment de ~100-400
opérations ≈ 0,1-0,8 ms sur un M3 (≈ 3,5 TFlops) ; le compilateur d'Apple peut sortir les calculs d'uniformes en préambule (le
bas) ; à 1280×720 (la fenêtre par défaut d'un build publié, `project.godot:74-75`) divisé par 4. **0,05 – 0,8 ms GPU, ESTIMÉ, très
incertain** ; `VoileEncre` ≤ 0,05 ms (un mélange plein cadre sur GPU à tuiles), **à ne pas toucher** (identité, « il assoit le HUD »).
Sans preuve que le duel est lié au GPU, **le gain CPU est nul**.

**4-6.** Option A de HUD-04 (sortir les calculs d'uniformes du fragment) : risque nul **si** `tools/banc_voile.tscn` et la planche
d'éblouissement confirment l'égalité numérique ; options B/C (variante allégée, demi-résolution) touchent la lisibilité de la lumière :
**à Adrien**. **Verdict : CONFIRMÉ AVEC RÉSERVE (existence prouvée, coût NON ÉTABLI) ; sévérité rabaissée de MAJEUR à MINEUR-à-mesurer.**
**Preuve cloud :** `loupe.gd` a déjà `_cout_du_voile` (`loupe.gd:1498-1545`, bras A « plein + copie », B « calme ») ; **ajouter les bras C
« `p1_dazzle.visible = false` » et D « sans `VoileEncre` »** et lancer sous Xvfb + llvmpipe (relatif : le rasteriseur logiciel paie le
fragment au pixel, ce qui donne au moins le *rapport* voile / reste de la scène).

---

### B9 — MEN-06 : `menu_glass` et la copie d'écran

**1. Le code.** Confirmé et élargi : `menu_glass.gdshader:40` déclare `screen_texture : hint_screen_texture` et **la référence** dans
`brume_defocalisee()` (`:73-84`), appelée par `fragment()` sous `if (flou > 0.0)` (`:106-109`). F12 : c'est la référence statique qui
compte, pas le test à l'exécution — la règle de la ROADMAP (l. 4305-4317 : « déclarer fait copier ») est juste en pratique pour ce
shader, mais pour la mauvaise lettre (une déclaration jamais référencée ne copierait rien). **`RELECTURE_ECRAN := false`**
(`ui.gd:929`, depuis le 2026-08-19) ⇒ `menu_glass.vitrer(hub.right_panel(), COLOR_P1, false)` (`ui.gd:4253`) ⇒ **même le cadre de droite,
toujours visible au hub, a `flou = 0` et ne lit rien** ; `MenuVeil` n'est pas créé (`ui.gd:4260`). Le rapport MEN (« voile `menu_veil`
(plein écran + copie d'écran), verre (copie + 9 prises) ») décrit donc un état éteint depuis le 19 août.

**2-3. Combien de copies ?** **Une.** `canvas_render_items` copie l'écran une seule fois (F12) pour tous les lecteurs d'un même
canvas, et l'étape de cull les rend en un seul appel (`renderer_canvas_cull.cpp:76-105`). 22 rangées de plus ne changent rien :
leur copie est celle que le cadre de droite déclenche déjà. L'hypothèse « jusqu'à N-1 copies inutiles » est **réfutée** ; le
commentaire `menu_glass.gd:57-60` et la phrase ROADMAP l. 34324-34326 (« la donner aux vingt rangées coûterait vingt fois ») reposent
sur une idée que le moteur dément. Le dépôt
avait raison de le sentir (l. 6438-6462 : « le tampon est une ressource de viewport partagée »). Coût de la copie unique
inutile : ≈ 0,05 – 0,3 ms/image, **au hub seulement** (ROADMAP l. 4316-4317 : copie + voile plein = 0,53 ms à 1440p).

**4-6.** Un second shader sans la référence aurait un seul usage vrai : le cadre de droite quand `RELECTURE_ECRAN` est faux. **Verdict
: RÉFUTÉ en l'état** (la déclaration est réelle, mais elle ne coûte pas N copies : une seule, déjà due au cadre de droite) ;
**résidu ANECDOTIQUE** (une copie au hub). Correctif minimal : `menu_glass_plat.gdshader`
(identique sans `screen_texture` ni `flou`), choisi par `vitrer()` quand `flou` est faux — et la règle ISO10 reformulée « référencer ».
Risque : `tools/test_vitrine_menus.gd`. **Preuve cloud :** pas de compteur direct des copies ; temps relatif au hub sous llvmpipe avec / sans
le shader plat, et `RENDER_*` ne les compte pas — **à mesurer**.

---

### B10 — ISO-04 + SHA-09 : les `set_shader_parameter` de la présentation iso

**1. Le code.** Confirmé. `Presentation3D._suivre` (`presentation_3d.gd:795-824`) : `style` ×5 matériaux, puis par vue `canevas_%d_x/y/o`
et `taille_%d` ×5 matériaux (20 formats de nom) ; corps (`886-901`) ; `IsoVolumes._pousser_lightmaps` (`iso_volumes.gd:2085-2125`) :
6 poussées (`lumiere_%d`, 3 `canevas`, `taille`, `style`) × chaque matériau de volume (8 pour deux faisceaux) + recopie du contact et
de l'usure du mur (`2104-2110`) ; `_poser_couches` (`1908-1933`) 8 poussées × 3 couches × torche ; `_poser_longueur` (`854-866`).

**Le décompte, rapproché (ISO-04 ≈ 300 ; SHA-09 270-290).** Les deux sont justes et ne diffèrent que par le périmètre : SHA-09 est
le bon chiffre pour un duel de base sur une carte livrée (≈ 237 `set_shader_parameter` + ≈ 32 `get_shader_parameter` ≈ **270 appels**,
≈ 100 formats de nom) ; ISO-04 y ajoute la zone morte des murs bas (64) et les capteurs (16), absents des six cartes livrées
(aucune n'a de muret : `assets/maps`). Mon recomptage par site :

| Site | Appels / image | Constants ou redondants |
|---|---|---|
| `_suivre` (style 5, canevas/taille 20, corps ≈ 18, contact ≈ 8) | ≈ 51 | `style` 5 (constant) ; `taille_N` 5 (constant tant que la fenêtre ne change pas) |
| `_pousser_lightmaps` : 8 matériaux × 6 | 48 | `style`, `taille_N`, `lumiere_N` (texture constante) : 24 |
| même : contact (2 noms) + usure (2 noms), `get` puis `set`, 8 matériaux | 64 (32 `set` + 32 `get`) | usure (16) constante entre deux impacts |
| `_poser_couches` : 8 × 3 couches × 2 lampes | 48 | `masque`, `avec_masque`, `nuage_graine` : 18 |
| `_poser_longueur` / `_poser_juge` / `_tailler_faisceau_air` | ≈ 20 | `fondu_air` 6 |
| lentilles et éclats (`point_lumineux`) | ≈ 30 | — |
| `ui._poser_voile` | 5 | — |

Les `canevas_N_x/y/o` changent avec la caméra mais sont poussés 13 fois avec la **même** valeur (la candidate naturelle d'un
`global uniform`, option de SHA-09). Redondants ou constants : ≈ 110-160 appels sur ≈ 270, soit **40 – 55 %**, pas « deux tiers ».

**Le « balayage de 126 Ko » (demandé : par image, ou une fois ?).** **Par image** — `IsoVolumes.suivre` (`iso_volumes.gd:447`) appelle
`_pousser_lightmaps` à chaque image tant qu'une volume masqué ou « forme » existe, et, par matériau de ce type :

```gdscript
# iso_volumes.gd:2108 — dans la boucle `for m in mats` (volumes de faisceau, deux par torche : 3 couches + 1 juge)
if mur != null and (m as ShaderMaterial).shader.code.contains("#define USURE_ESSAI\n"):
```

mais le **coût est faux d'un facteur ~8**. `variante_definie` (`iso_materiaux.gd:118-129`) insère chaque `#define` **juste après
`shader_type …;`** : dans `volume_iso.gdshader`, `shader_type` est à l'octet **1690** (`;` à 1710) sur 15 437 caractères. `contains`
(F15) s'arrête à la première occurrence, vers l'octet ~1 750-1 950 : ≈ 2 Ko lus par appel, **≈ 16 Ko pour 8 matériaux, soit
10 – 25 µs**, pas ~130 µs. Le balayage complet (15,8 Ko × 8) n'a lieu que sous `--sans-usure` (le `#define` est alors absent).
Reste que la réponse est fixée à la création du matériau : le mettre en cache est trivial et propre.

**3. Le coût.** ≈ 270 appels × U5 (0,3-0,8) + ≈ 100 formats (0,3-0,7) + mises à jour de blocs d'uniformes de ~25 matériaux
(beaucoup changent de toute façon : corps, couches) ⇒ **≈ 0,1 – 0,35 ms (centre ≈ 0,2)**, ESTIMÉ ; **récupérable ≈ 0,06 – 0,2 ms**
(les constantes + les noms formatés précalculés en `StringName`). ISO-04 : 0,15-0,3 ; SHA-09 : 0,1-0,4 : cohérent. Autre coût de
SHA-09 non vérifié ici : `IsoMateriaux.beaute_active()` → `DrapeauxDeLancement.arguments()` concatène deux `PackedStringArray`
à chaque appel (`drapeaux_de_lancement.gd:22-27`) ; appelé par nuage de fusée/gadget seulement (`iso_nuage_voxel.gd:490-521`), donc
hors duel de base.

**4. Les invariants.** **Beaucoup de gardes textuelles** (listées par ISO-04, vérifiées) : `test_iso_gadgets.gd:1004` lit 600 caractères
après `func _pousser_lightmaps(` ; `test_iso_gadgets.gd:1130-1135` extrait par expression régulière les noms posés en dur
(`set_shader_parameter\("nom"`) de plusieurs fonctions et exige `vus >= 20` : **un refactor en boucle sur des constantes ferait chuter
ce compte (rouge, donc non muet)** ; `test_corps_mannequin.gd:156-157` compte deux occurrences de la boucle des matériaux de corps ;
`test_banc.gd:289-300` impose l'ordre `_lumieres.call("suivre")` < `_accorder_le_relief()` < `_accorder_la_led()` ; `test_fumee_voxel.gd:548`.
**Piège déjà payé** (« Q39 (2) », `presentation_3d.gd:1321-1327`) : une constante posée une fois doit être **reposée si le matériau est
recréé** (changement de classe, `_accorder_le_slug`).
**Conflit de chantier à signaler :** `_suivre` est la fonction où le lot OM6 du chantier OMBRES prévoit de passer les capteurs en
`UPDATE_WHEN_VISIBLE` (`presentation_3d.gd:809-810`, `CONTEXTE_CHANTIERS_EN_COURS.md`). Retoucher `799-824` dans le même temps promet un
conflit de fusion ; ne rien y écrire sans que la session `candela-2d-godot-d4` ait été prévenue (CLAUDE.md : jamais de `git merge` dans
la branche d'une autre session).
(`IsoMateriaux.accorder_mur / accorder_sol / accorder_corps`, qui appellent `beaute_active()`, ne tournent qu'aux événements — construction
de l'arène, changement de classe : `presentation_3d.gd:1307, 1890-1896, 1989-1995, 2055` — pas par image dans un duel de base.)

**5. Le statut.** NOUVEAU (seul « nom inconnu » est consigné, ROADMAP l. 4036).

**6. Verdict.** **CONFIRMÉ AVEC RÉSERVE.** MINEUR. **Correctif minimal, dans l'ordre :** (0) mémoriser à la création de chaque matériau de
volume s'il porte `USURE_ESSAI` (supprime le `contains` et la recopie inutile des 48 `usure_impacts`) ; (1) poser `style`, `taille_N`,
`lumiere_N`, `fondu_air`, `masque`, `avec_masque` **à la création / au changement** ; (2) précalculer les noms `canevas_%d_x…` en
`StringName` statiques. L'option 2 de SHA-09 (uniformes globaux) est L, risque élevé (≈ 40 déclarations, plusieurs suites). **Preuve cloud :**
un compteur d'appels demande une cale (`IsoMateriaux.pousser(m, nom, v)` qui incrémente en build debug) — elle fait partie du
correctif ; en attendant, µs de `Presentation3D._process` + `IsoVolumes.suivre` ×2000 sur `main.tscn` monté avec iso et deux torches
(headless : le serveur factice ignore la mise à jour des blocs, on ne mesure que le côté script = borne basse).

---

### B11 — ISO-10 : `_decrire` recomposé chaque image

**1-2.** Confirmé : `Presentation3D._process` finit par `etat = _decrire(voulues)` (`presentation_3d.gd:523`) à **chaque image**, F3 fermé ;
`_decrire` (`1827-1852`) formate 3-4 chaînes à 7-9 arguments, bâtit un `PackedStringArray`, appelle `variante_lightmap()`
(`get_node_or_null` + `get`), `DisplayServer.window_get_size()`, et `IsoGeometrie.hauteur_mur_haut()` qui fait un **`load()` puis
`get_script_constant_map()`** à chaque appel (`iso_geometrie.gd:49-60`). Lecteurs de `.etat` : F3 par `Presentation3D.texte_f3`
(`presentation_3d.gd:382-386`, `ui.gd:1917`), `tools/banc_iso.gd:857, 2239`, `bench_framerate.gd:1201, 1391`, `banc_murs_bas.gd:489`.
**3.** ESTIMÉ **15 – 35 µs** (centre 25). **4.** `etat` doit rester lisible par les bancs : propriété (`get`) ou méthode paresseuse + cache
statique de `hauteur_mur_haut()`. **5.** NOUVEAU. **6.** **CONFIRMÉ**, ANECDOTIQUE. **Preuve cloud :** µs de `_decrire` ×5000 sur une
présentation allumée.

---

## 3. Estimation honnête du coût CPU total par image, pendant un duel

Cas : duel en ligne, vue unique iso, 6 cartes livrées, F3 fermé, torches allumées. En µs, ESTIMÉ ; **mécanisme et nombre d'appels
PROUVÉS (dépôt + moteur 4.7.1), coûts unitaires non mesurés**.

| Poste | Bas | Centre | Haut | Dépend de |
|---|---|---|---|---|
| B1 notifications de thème du HUD (15-16 écritures, dont 7 sur J2 caché) | 150 | 350 | 560 | c_L, c_P (U1, U2) |
| B2 reste du bloc J2 caché (hors notifications) | 20 | 40 | 70 | U5, lectures |
| B3 galerie cachée (6 tuiles) | 110 | 200 | 300 | c_B (U1) |
| B4 hachure d'alerte | 15 | 25 | 40 | U5 |
| B5 anneaux + bandeau | 20 | 30 | 45 | — |
| B6 reste (enseigne, hub, passant) | 3 | 6 | 12 | — |
| **Sous-total HUD / menus** | **≈ 320** | **≈ 650** | **≈ 1 030** | |
| B10 ISO-04 + SHA-09 (dont le `contains` du shader, 10-25) | 100 | 200 | 350 | U5 |
| B11 ISO-10 | 15 | 25 | 35 | — |
| **Sous-total ISO** | **≈ 115** | **≈ 225** | **≈ 385** | |
| **TOTAL** | **≈ 0,43 ms** | **≈ 0,9 ms** | **≈ 1,4 ms** | |

- **Hors duel (non additionné) :** B7 ≈ 3 ms au menu ; B8 GPU 0,05-0,8 ms ; B9 0,05-0,3 ms au hub.
- **Près des deux tiers du centre (B1 + B3 = 550 sur 875 µs) reposent sur deux inconnues** : le coût d'une notification de `Label` /
  `PanelContainer` (B1) et de `Button` (B3). Le bas de 0,43 ms suppose U1 = 0,5 µs et U2 = 5 µs ; si le moteur était deux fois plus
  rapide que mes bas, B1 et B3 tomberaient de moitié et le total vers 0,3 ms. C'est pourquoi : **À MESURER, et ça se mesure avant
  d'écrire un seul correctif** (section 4). Ce que cette estimation ne dit PAS : le coût GPU (HUD-04), le coût des menus (B7, B9), ni le
  CPU de `_poser_voile` / `aberration_debut()` (HUD-11, hors mission, ≈ 30-80 µs).
- **Part récupérable ≈ 80 %** (B1 ~95 %, B2-B3 100 %, B4 80 %, B10 ~50-60 %, B11 100 %) : ce qui reste, ce sont les vrais changements
  d'état (torche, fusée, PV).
- **Rapport à la cible :** à 100-150 i/s (images de 6,7-10 ms) cela fait ≈ 4-21 % d'une image (centre ≈ 9-13 %), contre une marge
  écrite de 139 µs (ROADMAP l. 20352, 22095) et un plancher de bruit du banc de 0,25 ms (l. 34151) : **chaque ligne est invisible au banc
  de cadence prise seule, la somme ne l'est pas.** Ne vaut pour le 1 % bas que si le fil principal est le goulot (inconnu : question 1).
- **Écran scindé local :** B1 vaut 15 écritures (pas de ping), B2 vaut zéro (les deux panneaux sont affichés, c'est le gain qui disparaît),
  B10 compte ≈ 20 appels de plus (la seconde vue : ≈ 65-85 poussées dans `_suivre` contre ≈ 50, ISO-04 / SHA-09) ; le total reste du
  même ordre.

---

## 4. Protocole headless qui le mesurerait

**Esquisse, non lancée** (Godot n'a pas été exécuté pour cette vérification). `tools/banc_ui_cachee.gd`, `extends SceneTree`, patron de
`test_ecran_de_fin.gd` (monter `main.tscn`). `godot --headless --path . --fixed-fps 60 --script res://tools/banc_ui_cachee.gd`.
`--fixed-fps` supprime la synchronisation temps réel : chaque image dure ce que le CPU y met, et l'écart entre deux `process_frame`
est un temps de calcul pur (le serveur de rendu étant factice).

```gdscript
extends SceneTree
var _n: Dictionary = {}             # chemin -> nombre de theme_changed
var _dt: Array[int] = []            # µs entre deux process_frame
func _brancher(noeud: Node) -> void:
	if noeud is Control:
		var chemin := str(noeud.get_path())
		(noeud as Control).theme_changed.connect(func() -> void: _n[chemin] = int(_n.get(chemin, 0)) + 1)
	for e in noeud.get_children(): _brancher(e)
func _init() -> void: call_deferred("_run")
func _run() -> void:
	await process_frame
	var main := (load("res://main.tscn") as PackedScene).instantiate(); root.add_child(main)
	await process_frame
	var ui = main.get_node("UI")
	# Bras « en ligne » : comme `tools/test_ecran_de_fin.gd:395-447` — le mode se pose par le NŒUD (`/root/NetworkManager`), jamais par
	# le nom d'autoload (non résolu en `--script`), puis `disposer_hud()` cache le panneau adverse.
	var reseau: Node = root.get_node(^"/root/NetworkManager")
	reseau.current_mode = reseau.GameMode.ONLINE_HOST
	ui.hide_game_over(); ui.disposer_hud()                      # `hide_game_over` rend le HUD de match (`ui.gd:9272-9287`)
	for i in 120: await process_frame                           # échauffement (le fondu de `_eteindre` est fini)
	_brancher(ui)
	var avant := Time.get_ticks_usec()
	for i in 300:
		await process_frame
		var t := Time.get_ticks_usec(); _dt.append(t - avant); avant = t
	for c in _n: if _n[c] >= 280: print("%4d × %s" % [_n[c], c])   # tout nœud notifié à CHAQUE image
	_dt.sort(); print("médiane %d µs, moyenne %d µs" % [_dt[_dt.size() / 2], _dt.reduce(func(a, b): return a + b) / _dt.size()])
	quit()
```

**A. Compteurs, sans chronomètre (déterministes, indépendants du matériel) — c'est la première chose à lancer.**
1. *Recensement* ci-dessus : doit lister 13 nœuds du HUD (6 par joueur — plaque et libellé de la torche, `lbl_f`, plaque des fusées,
   `lbl_g`, plaque du gadget — plus le statut réseau ; le ping seulement si `NetworkManager.has_rtt`), avec `lbl_f` à ≈ 2 notifications par
   image, les N `Button` de la galerie et les 2 anneaux ; tout ce qu'un auditeur n'a pas vu y apparaîtra aussi.
2. *Sonde* : un `Label` enfant de test dont `_notification` compte `NOTIFICATION_THEME_CHANGED` ; 1 000 `add_theme_color_override` à valeur
   égale ⇒ 1 000 (le source 4.7.1 le dit déjà ; cela clôt la « question ouverte 1 » de HUD).
3. Signaux `draw` (3 Labels de J1) et `sort_children` (3 cartouches de J1) : ≈ 300 sur 300 images avant correctif, ≈ 0 après.
4. `gallery.is_processing()`, `p1_cursor.is_processing()`, `match_banner.is_processing()` en match ; `get_signal_connection_list("changed")`
   de `_style_selected` = N ; sous-classe de `MenuHatchRect` surchargeant `_update_param` pour compter ; faux cœur injecté dans
   `MatchBanner.matchmaker_override` pour compter les `search_snapshot`.
5. `vp1/vp2.render_target_update_mode` après `show_main_menu()` (B7).

**B. Temps (µs), à pas fixe.** *Mesure principale : l'écart `Time.get_ticks_usec()` entre deux `process_frame`* (il contient le pas de
physique, les `_process`, les appels différés — refaçonnage, tris, `_redraw_callback` — et la file de messages).
- **`--fixed-fps 60` est obligatoire, pas décoratif :** avec lui, `Main::iteration` rend la main AVANT `OS::add_frame_delay`
  (`main.cpp:5166-5174`) ; sans lui, en headless (`window_can_draw()` faux, `display_server_headless.h:139`), `add_frame_delay` dort
  `application/run/low_processor_mode_sleep_usec` (6 900 µs par défaut, `main.cpp:2260`, absent de `project.godot`) à CHAQUE image
  (`os.cpp:721-723`), et l'écart mesuré ne dit que ce sommeil.
- **Ne pas attendre `RenderingServer.frame_post_draw` en headless :** `can_any_window_draw()` y est faux (`display_server_headless.h:141`),
  donc `RenderingServer::draw()` n'est jamais appelé (`main.cpp:5076-5090`) et le signal ne part pas — l'`await` pendrait. Pour la même
  raison `process_ticks` n'y contient pas le dessin.
- **Ne pas prendre `Performance.TIME_PROCESS` pour une moyenne :** c'est le maximum de la dernière seconde, publié une fois par seconde (F14).
  Il ne sert qu'à lire « la pire image de chaque seconde » (utile pour le 1 % bas), toujours en A/B, jamais en absolu.
- Le serveur de rendu headless est factice : les poussées d'uniformes ne mettent à jour aucun bloc GPU, donc les lignes ISO ne mesurent que
  le côté script (borne basse) ; les Labels, conteneurs et boutons, eux, exécutent bien refaçonnage, tri et `_redraw_callback`
  (appels différés du `MessageQueue`, indépendants du pilote d'affichage).
- Blocs de 300 images après 120 d'échauffement, **alternés A B A B A B** (dérive thermique, GC), médiane et moyenne par bloc.
- Bras sans correctif (réglables dans le banc) : `T0` témoin ; `T1` `ui.update_hud(p1, null, t)` (coût du bloc J2) ;
  `T2` `gallery.set_process(false)` pour N = 6 puis 30 cartes ; `T3` `p1_cursor/p2_cursor/match_banner.set_process(false)`.
- Bras avec correctif (deux arbres, processus alternés) : `T4` HUD-02 (lecture-avant-écriture), `T5` `MenuHatchRect` idempotent,
  `T6` ISO-04 (0)-(2).
- **Micro-bancs unitaires — ils donnent U1…U4 :** un `Label` dans `HBoxContainer` dans `PanelContainer`, un `PanelContainer` avec
  `StyleBoxTexture` surchargé, un `Button` surchargé de 5 styles ; 1 écriture identique par image contre 0, 2 000 images. Le total
  de la section 3 se recalcule alors par `Σ nombre de notifications × coût mesuré`.
- ISO : `Presentation3D._process` et `IsoVolumes.suivre` ×2 000, `_decrire` ×5 000, `main.tscn` monté avec iso et deux torches.

**C. Hors headless (GPU, appels de dessin, copies) :** Xvfb + llvmpipe, `tools/cadence_cloud/prise.sh` — **relatif seulement**, jamais
`--fixed-fps` (c'est écrit dans `prise.sh`). Compteurs : `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (B4 : −1 en vue unique, −2 en scindé ; B7 : l'arène 2D rendue deux fois sort du compteur au hub, ordre de grandeur non relevé).
HUD-04 : ajouter les bras C/D à `loupe.gd:_cout_du_voile`.

---

## 5. Ce que les auditeurs n'avaient pas vu / corrections de leurs chiffres

- **Un Label caché se refaçonne à chaque notification** (F6) : le panneau J2 caché n'est pas « presque gratuit » (HUD-01, HUD-02), et les 7
  notifications de J2 coûtent presque comme celles de J1.
- **Le doublon de `lbl_f`** : deux écritures de même valeur, deux refaçonnages par image et par joueur.
- **Une tuile de galerie est un `Button`** (32 éléments de thème) : HUD-03/CAR-01 sous-estimés ×2-4.
- **`RELECTURE_ECRAN := false`** : le voile de menu n'existe pas, le verre ne lit rien ; MEN-06 vise le mauvais objet (les rangées) et le
  mauvais nombre (N copies). Le vrai résidu est une copie unique, due au cadre de droite.
- **`TIME_PROCESS` = maximum par seconde** (`main.cpp:5096`) : le protocole d'annexe A du rapport HUD (qui l'utilisait en A/B pour des écarts de quelques dizaines de µs) est à corriger.
- **ETA-03 (gater `update_hud` sur `match_hud.visible`)** figerait le voile d'éblouissement : préférer HUD-01.
- **ISO-04 : « deux tiers constants » → 40-55 % ; « 126 Ko » → ~16 Ko lus.** MEN-04/ISO-07 : les capteurs n'existent pas au menu.
- **Compte exact des écritures de thème : 7 par joueur**, dont 5 pour les réserves : HUD-02 a juste ; ETA-03 et MEN-11 en comptent 8 ;
  GAD-08 compte 6 pour les seules réserves (il y en a 5). Au total 15 écritures (16 en ligne), pas 16-18.

## 6. Questions ouvertes

1. **Le fil principal est-il le goulot d'un duel sur le M3 ?** Toute cette famille est du CPU principal ; si le duel est lié au GPU, le gain
   en images/s est nul (reste l'énergie et la chaleur). `--temps-par-vue` ne le dit pas (0,00 pour le GPU, ROADMAP).
2. **Compromis MEN-04 (à Adrien) :** accepter que l'arène derrière le menu soit une image figée (4 % d'une image quasi noire).
3. **HUD-04 B/C (à Adrien)** et l'ordre des mesures : voile calme d'abord, jamais `VoileEncre`.
4. **Combien de cartes perso un joueur type possède-t-il ?** (B3 est linéaire en N ; le banc en a 6.)
5. Les 18 `MenuApercu` / 16 illustrations résidentes (HUD-10 / MEN-08) et le reste de HUD-07 à HUD-12 n'étaient pas dans ma mission.
