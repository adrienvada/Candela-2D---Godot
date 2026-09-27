# Répétition du test d'Adrien — session cloud `claude/cloud-repetition`

## Pour Adrien, en cinq lignes

1. J'ai rejoué ton test à la machine : 6 cartes en 1v1 écrans scindés, l'entraînement, une mort et sa killcam, l'écran de fin, l'éditeur, F3, F6, puis un match en réseau local entre deux fenêtres. **Rien ne bloque ton test** : chaque match est allé du menu à l'écran de fin sans plantage.
2. **À savoir avant de tester** : dans l'écran « S'entraîner », changer de carte ne sert à rien — l'entraînement joue toujours l'Arène standard.
3. **F5 n'ouvre pas l'éditeur de cartes** : l'éditeur s'ouvre par « CHANGER DE CARTE » puis le bouton « ÉDITEUR › ». Dans l'éditeur, F5 lance le mode test.
4. Si tu ajoutes des options au lancement, **mets-les après deux tirets** (`godot --path . -- --sans-usure`). Sans les tirets, `--lacet=0` marche, mais `--sans-usure` et d'autres sont ignorés sans rien dire.
5. Deux messages d'erreur rouges apparaîtront dans la console : l'un en ouvrant l'éditeur après un match, l'autre en le quittant par Échap. Ils ne cassent rien de visible ; les corrections sont proposées plus bas.

> Base : `origin/integration-iso14` à `18f5fdc`, puis à `60e5c6d` (la nouvelle tête poussée cette nuit, voir la fin). Session du 2026-09-27, de 01:10 à 04:xx (Paris). Rendu logiciel (llvmpipe) sous Xvfb en 1920×1080 : les images valent pour ce qui est affiché et pour les couleurs, **pas** pour la cadence ni l'éblouissement. Aucun chiffre d'images par seconde de ce rapport n'est une mesure.

## 1. Ce que le jeu fait VRAIMENT par défaut sur `18f5fdc` (lu dans le code, puis vu à l'exécution)

| Réglage | Valeur par défaut | Où c'est décidé | Vu à l'exécution |
|---|---|---|---|
| Vue | **isométrique** (tangage 52°) ; la vue de dessus seulement avec `--2d` ou le réglage « VUE DE DESSUS (DÉBOGAGE) » (build de débogage) | `settings_manager.gd:101` (`mode_iso := true`), `iso_applique` l. 323 ; `camera_iso.gd:19` | `[iso] vue isométrique allumée : écran scindé … tangage 52.0°, murs 1.25 tuile, pâte D — lavis et pochoir, lightmap 1080p` |
| Lacet | **45°, option B** : J1 à 45°, J2 à 225° (+180°), en local ET en ligne (imposé en ligne) | `settings_manager.gd:152-153`, `lacet_du_duel` l. 372, `lacet_du_joueur` l. 379 | `mode_rendu=iso lacet 45° B, lacet J1=45 J2=225` sur les six cartes ; F6 : `mode_rendu iso lacet 45° B` |
| Zoom du duel | **×1,5** (imposé en ligne ; en local, sauf zoom enregistré au réglage de débogage) | `settings_manager.gd:129`, `valeurs_du_duel` l. 411 | `zoom=1.50` |
| Décalage du regard vers la visée | **0,15** de la hauteur visible | `settings_manager.gd:132` | `décalage=0.15` |
| Portée des torches | **×0,75** | `settings_manager.gd:141` | — |
| Murs abîmés (usure) | **allumés** ; `--sans-usure` les éteint (après `--` seulement, voir D3) | `iso_materiaux.gd:165-173` | `[usure] allumée — variante USURE_ESSAI posée` |
| Masque de la fumée | **éteint** ; `--fumee-masque` l'allume | `iso_volumes.gd:96`, lecture l. 136-141 | `[fumée masque] éteint (le défaut depuis le 2026-09-26 …)` |
| Point de braise de la fusée posée | éteint sur `18f5fdc` ; **allumé, « presque blanc », sur `60e5c6d`** (Q34 = C) ; `--sans-fusee-coeur` l'éteint | `iso_volumes.gd` (`coeur_fusee`) | voir § 6 |
| Beauté (matériaux ISO7) | allumée ; `--sans-beaute` l'éteint | `iso_materiaux.gd:83` | — |
| Bandeau LED des murs | allumé ; `--sans-led-murs` l'éteint ; F7 bascule (build de débogage seulement) | `mur_led.gd:139-151`, l. 375 | — |
| Pâte | **D, lavis et pochoir** (mais voir D4 : les touches 1-4, 0 et F2 la changent en match) | `presentation_3d.gd:179` | `pâte D — lavis et pochoir` |
| Lightmap iso | **1080p** | `settings_manager.gd:185` | `lightmap 1080p` |
| Éteints par défaut | `--mannequin`, `--corps=portraits`, `--corps=sombre[2,3]`, `--corps-detaille`, `--corps-grossiers`, `--encre-essai`, `--pochoirs-essai`, `--faisceau`, `--fumee-masque`, `--led-murs-fige`, `--teinte=`, `--charte=`, `--pate` | `voxel_catalogue.gd`, `iso_materiaux.gd`, `arena_decor.gd`, `iso_volumes.gd`, `mur_led.gd`, `presentation_3d.gd`, `charte.gd` | — |
| Protocole | `Protocol.VERSION` = 18 | `protocol.gd:289` | poignée de main ENet : `protocole 18 accepté` |

**Le « protocole en six étapes » d'Adrien n'est écrit nulle part sur `18f5fdc`** (ni `docs/ROADMAP.md`, ni `docs/iso/`, ni `claude/reveil`). La répétition suit la liste de la tâche.

## 2. Ce qui a été rejoué, et ce qui en est sorti

| Étape | Résultat | Images |
|---|---|---|
| Premier lancement, foyer neuf | L'intro en planches joue, se saute à la touche, le menu suit. Console propre. | `images/passe1_18f5fdc/00_*`, `01_*`, `02_*` |
| Menus : hub, 1v1 écrans scindés, galerie des cartes, salon des armes, personnalisation (contrôles, affichage, effets, audio), S'entraîner, 1v1 amical | Tous atteints, aucune erreur. | `images/passe1_18f5fdc/10_*` à `17_*` |
| Match local 1v1 écrans scindés, **six cartes** (Arène standard, Arène circulaire, Le Cloître, L'Usine, La Croisée, Le Bunker) | Sur les six : la carte choisie est jouée, 45° B, deux vues, J2 **tué par un vrai tir** de J1, killcam, gel du kill, affiche « JOUEUR 1 GAGNE », menu de fin. | `images/passe1_18f5fdc/2*_<carte>_*` |
| Entraînement, six fois (une par carte choisie) | Vue unique, part, tire. **Toujours l'Arène standard** (D1). | `images/passe1_18f5fdc/30_*` |
| F3 en match | Panneau affiché. Il recouvre le cadre HUD de J1 (cosmétique, C2). | `images/passe1_18f5fdc/40_f3.jpg` |
| F6 en match | `user://diagnostic.txt` écrit, contenu cohérent (`mode_rendu iso lacet 45° B`). | `images/passe1_18f5fdc/diagnostic_f6.txt` |
| F5 en match | **N'ouvre rien** (D2). | — |
| Éditeur (galerie → ÉDITEUR ›), F5 mode test, F5 retour, Échap | S'ouvre, le mode test s'ouvre et se referme, Échap ramène au jeu (l'allumage rejoue). **Deux erreurs de console** (E1, E2). | `images/passe1_18f5fdc/50_*` à `53_*` |
| QUITTER | Sortie propre, aucune fuite signalée. | — |
| En ligne, ENet, deux processus en fenêtre sur la même machine | Connexion, poignée de main v18, PRÊT, manche, déplacement du client vu par l'hôte, tirs, killcam, fin, **revanche** : tout passe des deux côtés. Trois vérifications du gadget échouent en fenêtre (N1, non prouvé). | `images/passe1_18f5fdc/en_ligne_*` |
| Suite complète `tools/run_suites.sh` | **Verte** : 137 suites, sans erreur de script, 585 s. | — |

## 3. Défauts, classés

Aucun **bloquant**. Chaque ligne : ce qui se passe, la commande qui le reproduit, le fichier probable, le correctif proposé. **Rien n'a été corrigé dans le jeu.**

### Gênants pour le test

**D1 — L'entraînement ignore la carte choisie.** L'écran « S'ENTRAÎNER » offre « CHANGER DE CARTE », la galerie sélectionne bien la carte (`MapData.selected_map_id` change), mais le lancement la remplace par l'Arène standard. Mesuré : carte choisie `map_002`, `map_003`, `map_004`, `map_001`, `00000002` → carte jouée `00000001` à chaque fois (images `30_*` identiques).
- Cause : `game_state.gd:901`, `MapData.select_map(MapData.DEFAULT_MAP_ID)` dans `_on_training_requested()`, inchangée depuis le 2026-08-18 (`2dcd37fe`) ; l'entrée « CHANGER DE CARTE » de l'entraînement est arrivée le 2026-09-09 (`3438c86`) sans la lever. Le texte de « PRÉPARER L'ENTRAÎNEMENT » dit encore « sur la carte par défaut » (`ui.gd:4334`).
- Reproduire : `./tools/cloud_repetition/run_pilote.sh --etapes=entrainement` (voir § 5).
- Correctif proposé : retirer la ligne 901 (garder la carte choisie), et corriger le texte de `ui.gd:4334` ; ou, si l'entraînement doit rester sur l'arène standard, retirer l'entrée « CHANGER DE CARTE » de l'écran d'entraînement (`ui.gd:4343-4346`). Choix d'Adrien. Tient à `game_state.gd` / `ui.gd`.

**D2 — F5 n'ouvre pas l'éditeur de cartes.** `CLAUDE.md` (« F5 l'éditeur de cartes ») et la tâche le disent ; le code ne lie F5 qu'**à l'intérieur** de l'éditeur (`map_editor.gd:411`, bascule du mode test). En match ou au menu, F5 ne fait rien (vérifié : scène courante inchangée). L'éditeur s'ouvre par CHANGER DE CARTE → « ÉDITEUR › » (`map_gallery.gd:228`, `_open_editor` l. 508).
- Correctif proposé : corriger la phrase de `CLAUDE.md` (« F5, dans l'éditeur, lance le mode test ; l'éditeur s'ouvre depuis la galerie ») — ou ajouter le raccourci si Adrien le veut. Documentation, pas de code.

**D3 — Les drapeaux passés sans `--` sont ignorés, pour une moitié d'entre eux, en silence.** `settings_manager.gd:337` lit `get_cmdline_user_args() + get_cmdline_args()` (donc `--lacet=`, `--zoom=`, `--decalage=`, `--torche=`, `--2d`, `--iso`, `--lightmap` marchent avant ou après `--`), alors que `iso_materiaux.gd:84` et `:173` (`--sans-beaute`, `--sans-usure`, `--encre-essai`), `arena_decor.gd:86` (`--pochoirs-essai`), `iso_volumes.gd:136` (`--faisceau`, `--fumee-masque`, `--sans-fumee-masque`, `--fusee-coeur…`) ne lisent QUE ce qui suit `--`. `godot --path . --lacet=0 --sans-usure` donne donc le lacet 0 **avec** les murs abîmés, sans un mot. Même piège pour les « Main Run Args » de l'éditeur Godot sans `--`.
- Reproduire (headless, 2 s) :
  `godot --headless --path . --script res://tools/cloud_repetition/drapeaux.gd --sans-usure --lacet=0 --pochoirs-essai` → `usure : true`, `pochoirs : false`, `lacet : 0.0` ;
  la même avec `--` avant les drapeaux → `usure : false`, `pochoirs : true`, `lacet : 0.0`.
- Correctif proposé : une seule lecture des arguments pour tous les drapeaux (par ex. `GameSettings._arguments()` rendu statique et appelé partout), ou, au minimum, écrire dans chaque protocole « après `--` ». La trace `[usure] allumée` permet de le vérifier à l'écran de la console. **Piège à reporter dans la feuille de route** (introuvable aujourd'hui dans « Pièges connus »).

**D4 — Les touches 1, 2, 3, 4, 0 et F2 changent la pâte du rendu en plein match, en build publié aussi, en ligne aussi.** `presentation_3d.gd:2039-2054` (`_input`, `TOUCHES_DIRECTES` l. 175, `TOUCHE_PATE` l. 174) n'a pas le garde `OS.is_debug_build()` que F7 a (`mur_led.gd:375`). Aucune action du jeu n'est liée à ces touches (vérifié : `grep KEY_1…` hors `tools/`), donc rien ne les consomme avant. Un appui par mégarde change l'image sans explication ; et la pâte D est décrite comme « la seule pâte qui garde la lueur faible au niveau de la vue de dessus » (`presentation_3d.gd:176-178`) — un joueur en ligne peut donc choisir une pâte qui montre autrement la lumière faible, ce qui touche l'équité.
- Non vu à l'image (lu dans le code seulement).
- Correctif proposé : `if not OS.is_debug_build(): return` en tête de `_input`, comme F7. Tient à `presentation_3d.gd`.

### Erreurs de console (rouges, sans effet visible constaté)

**E1 — `ERROR: Condition "!is_inside_tree()" is true. Returning: Ref<World2D>()` en ouvrant l'éditeur après un match.** Pile : `diagnostic_ecoute (audio_manager.gd:2395)` ← `_tracer_ecoute (:2488)` ← `rendre_oreille (:2543)` ← `_open_editor (map_gallery.gd:512)`. Au changement de scène, l'oreille est rendue et le traceur lit `voix.get_world_2d()` sur un lecteur du pool déjà sorti de l'arbre. Vu aussi à la sortie de l'hôte ENet. Le traceur est actif hors F4 (il écrit à chaque pose/retrait d'oreille en build de débogage).
- Reproduire : un match local, puis CHANGER DE CARTE → ÉDITEUR › (`run_pilote.sh --etapes=diag,editeur`).
- Correctif proposé : `if voix != null and voix.is_inside_tree():` à `audio_manager.gd:2394`. Tient à `audio_manager.gd`.

**E2 — `SCRIPT ERROR: Cannot call method 'set_input_as_handled' on a null value` en quittant l'éditeur par Échap.** `map_editor.gd:385-387` : `_go_back()` appelle `change_scene_to_file`, le nœud quitte l'arbre, puis `get_viewport()` rend `null` à la ligne 387.
- Reproduire : ouvrir l'éditeur sans rien modifier, Échap.
- Correctif proposé : prendre la vue AVANT `_go_back()` (`var vue := get_viewport()`… `if vue: vue.set_input_as_handled()`), ou marquer l'entrée traitée avant d'appeler `_go_back()`. Tient à `map_editor.gd`.

**E3 — Après un match EN LIGNE, la sortie laisse fuir des objets** (`WARNING: 14 ObjectDB instances were leaked at exit`, `ERROR: 2 resources still in use at exit`, une texture de 1,4 Mo, un shader, un matériau). Vu sur les deux processus ENet, en fenêtre ET en headless sans ma surcouche ; la sortie du pilote (QUITTER après des matchs LOCAUX) n'en montre aucune. `--verbose` nomme les fuyards :
- un trio orphelin `CanvasLayer` + `BackBufferCopy` + `Node` avec son `Shader` : c'est un appareil de brouillage (`brouillage_vue.gd:66`). En vue unique, celui de la vue non regardée est retiré de l'arbre (`game_state.gd:5494-5496`, `_accorder_brouillage_aux_vues`) et gardé dans `_brouillages` ; orphelin, rien ne le libère quand `GameState` part. Correctif proposé : à la sortie de `GameState` (`_exit_tree` ou `NOTIFICATION_PREDELETE`), `for app in _brouillages: if is_instance_valid(app) and app.get_parent() == null: app.free()`. Tient à `game_state.gd`.
- la musique interactive (`AudioStreamSynchronized`, sept `OggPacketSequencePlayback`) encore en lecture : probablement `audio_manager.gd` ; proposé : arrêter la musique dans le chemin de sortie (`NetworkManager.quit_game`). Non localisé plus précisément.
- Sans effet pour le joueur (le processus se termine) ; c'est une fuite de sortie, pas une fuite en jeu.
- Reproduire (headless, 2 min) : deux foyers où l'intro est vue, puis
  `CANDELA_PORT=29420 HOME=<foyer1> godot --verbose --headless --path . res://tools/test_online_match.tscn -- --host --transport enet --no-eos`
  et, 8 s plus tard, `HOME=<foyer2> godot --headless --path . res://tools/test_online_match.tscn -- --join 127.0.0.1 --transport enet --no-eos`.

### Cosmétiques

- **C1 — La légende de l'affiche de fin nomme l'arme, pas la classe** : « ARÈNE CIRCULAIRE · 00:02 · PISTOLET / PISTOLET » après un match choisi « Le Parasite / Le Parasite » (`affiche_de_fin.gd:333-336`, clés `arme_j1`/`arme_j2`). L'historique dit lui-même (schéma 4, `game_state.gd:4157`) que l'arme « ne désigne plus le joueur depuis que dix classes se partagent dix armes ». Proposé : la classe. Choix d'Adrien.
- **C2 — Le panneau F3 recouvre le cadre HUD de J1** en écran scindé (`images/passe1_18f5fdc/40_f3.jpg`). Outil de diagnostic : sans gravité.
- **C3 — Le retour de l'éditeur rejoue l'allumage « CANDELA »** (`images/passe1_18f5fdc/53_apres_editeur.jpg`) : `main.tscn` est rechargé en entier. Voulu ou non : à trancher.
- **C4 — F6 écrit `transport EOS` en écran scindé** et `ecran_hz nan` sous Xvfb ; ce `nan` part ensuite dans l'historique des matchs sous forme de `null` avec un avertissement (`match_record.gd:263`, « NaN found in argument passed to JSON.stringify() »). Sur le Mac la fréquence est connue : sans doute propre au cloud, mais `conditions_de_match.gd:171` gagnerait un `is_finite()`.

### Non prouvé

- **N1 — En fenêtre, l'hôte ENet ne pose pas son gadget dans le banc** (`test_online_match.gd:1447-1450`, `[0, 0]`), alors que la même vérification passe en headless dans la suite (verte). Hypothèse : l'horloge (`--fixed-fps 60` sous rendu logiciel, attentes du banc en temporisateurs), pas le jeu. Rien ne le prouve dans un sens ou dans l'autre ; à regarder seulement si Adrien voit un gadget refusé en ligne.

- **N2 — La variante killcam du banc en ligne (`--host-killcam` / `--join-killcam`) échoue en fenêtre** : « la manche n'a jamais commencé », l'invité est coupé après la poignée de main. Même lecture que N1 (horloge du rendu logiciel), non prouvée ; la variante passe en headless dans la suite (famille 4.1/4.2 de `run_duo.sh`). La killcam en ligne, elle, a été vue dans le match simple (photos `en_ligne_*_killcam`).

## 4. Ce que je n'ai PAS pu prouver

- **La cadence, l'éblouissement, les gestes des corps, le son** : rendu logiciel, pilote audio factice (aucune carte son dans le conteneur).
- **Les gestes réels** : les menus sont « cliqués » (le signal même d'un clic), F3/F5/F6/Échap/Espace sont de vraies touches injectées, mais les joueurs sont tenus par une marionnette (déplacement, visée, tir, torche, fusée). Ni la souris, ni la manette, ni le clavier de J2 n'ont été éprouvés.
- **Le 1v1 local en vue unique** n'existe pas dans le jeu (le 1v1 local est toujours en écrans scindés, décision du 2026-08-18) : la vue unique a été vue à l'entraînement et en ligne.
- **EOS** : jamais touché (consigne).
- **Les gadgets et la fusée en jeu réel** sur `18f5fdc` : seule la seconde passe lance une fusée (§ 6).
- **L'ouverture par un double-clic sur Godot.app** : les lancements passent par `godot --path .` ou une scène de pilotage qui monte `main.tscn`.

## 5. Tout refaire

```bash
# Godot 4.7 officiel en /usr/local/bin/godot, puis :
godot --headless --path . --import
GODOT=/usr/local/bin/godot ./tools/run_suites.sh                      # la suite (10 min)

R=/tmp/rep; mkdir -p $R/foyer $R/images
# Le parcours (≈ 60 min sous rendu logiciel) :
HOME_PILOTE=$R/foyer GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
  ./tools/cloud_repetition/run_pilote.sh --etapes=demarrage,menus,local,entrainement,diag,editeur,quitter \
  --sortie=$R/images > $R/pilote.log 2>&1
#   --cartes=map_003_la_croisee,…  pour une partie des cartes seulement

# Le match ENet à deux fenêtres (le foyer de la ligne précédente, où l'intro est vue) :
SETTINGS_VU="$R/foyer/.local/share/godot/app_userdata/Candela 2D/settings.cfg" \
  ./tools/cloud_repetition/run_enet.sh $R/enet host           # ou host-killcam

# Les drapeaux avant et après « -- » (D3) :
godot --headless --path . --script res://tools/cloud_repetition/drapeaux.gd --sans-usure --lacet=0
godot --headless --path . --script res://tools/cloud_repetition/drapeaux.gd -- --sans-usure --lacet=0

# Relever la console : tout ce qui n'est pas le bruit du conteneur (ALSA, vsync, pilote audio) :
grep -n "SCRIPT ERROR\|ERROR:\|WARNING:\|leaked" $R/pilote.log | grep -v "V-Sync\|audio drivers\|ERR_CANT_OPEN"
```

## 6. La nouvelle tête `60e5c6d`

(à compléter)

## 7. À reporter dans la feuille de route (par l'intégration)

- Piège : **les drapeaux se lisent de deux façons** (D3) — `--lacet=` passe avant `--`, `--sans-usure` non.
- Piège de banc : **un banc en fenêtre dans un foyer neuf joue l'intro par-dessus le salon** ; `test_online_match` y cherche PRÊT sous l'intro et échoue (« aucun bouton PRÊT visible »). Déjà consigné pour le photographe (« Un banc qui monte main.tscn dans un foyer neuf photographie l'intro ») ; vaut aussi pour `test_online_match` hors headless.
- Correction de `CLAUDE.md` : F5 (D2).
