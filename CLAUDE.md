# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Avant toute chose

**Lire [docs/ROADMAP.md](docs/ROADMAP.md) en entier avant d'agir.** C'est le
document de référence : état des phases, décisions actées, « Pièges connus »
(erreurs déjà payées une fois) et jalons humains. Le protocole complet
humains/agents est dans [README.md](README.md). Règles non négociables :

- Le travail avance par **étapes numérotées** ; ne pas anticiper l'étape
  suivante sans demande explicite. Aucune refonte opportuniste : un problème
  hors périmètre se **signale**, il ne se corrige pas.
- Mettre à jour `docs/ROADMAP.md` **dans le même commit** que le travail décrit
  (état de phase, décision actée, piège découvert, ou à défaut la seule date de
  mise à jour). Expliquer le *pourquoi*, pas le *quoi*.
- **Et republier le suivi de projet**, destiné à Adrien :
  https://claude.ai/code/artifact/ba2ce690-309e-4d87-b72b-3ace1a1b681e
  **La republication est centralisée** (décidé le 2026-08-18, avec Adrien) :
  une seule session s'en charge à la fois ; les autres ne republient pas
  elles-mêmes, elles lui transmettent leur delta par message inter-session
  (`ListAgents` / `SendMessage`). Aucune session déjà chargée de la
  republication ? La première qui le constate en devient responsable et le dit
  aux autres. Détail du protocole : [README.md](README.md#republier-le-suivi).
  S'il faut republier soi-même : l'outil `Artifact` **en passant cette URL** —
  sans elle on crée un second artefact au lieu de mettre le premier à jour. La
  feuille de route est versionnée, le suivi ne l'est pas : **rien ne signale
  qu'il est périmé.** Une session sans cet outil le dit dans son rapport, avec
  ce qu'il aurait fallu changer.
- Plusieurs sessions peuvent travailler en parallèle : jamais de `git checkout`
  sans vérifier qu'aucune autre session n'utilise l'arbre (préférer un
  worktree). Ne jamais pousser sur GitHub sans demande explicite d'Adrien.
- La documentation, les commentaires et les messages de commit sont en
  **français**.

## Commandes

Le binaire Godot (4.7) sur le poste d'Adrien :
`/Applications/Godot.app/Contents/MacOS/Godot`.

```bash
# Lancer le jeu
godot --path .

# Suites de tests headless — TOUTES doivent passer avant tout commit
./tools/run_suites.sh

# Un seul test
godot --headless --path . --script res://tools/test_map_codec.gd
```

Les tests sortent avec le code 1 en cas d'échec. Autres bancs d'essai dans
`tools/` : `test_transport.tscn`, `test_online_match.tscn`,
`test_quit_path.tscn` (EOS/ENet, protocole dans `docs/PROTOCOLE_TEST_EOS.md`)
et `bench_framerate.tscn` (charge réelle). **La cible est passée de 120 à
`1 % bas ≥ 60` le 2026-08-25** (chantier R, étape R5, décision d'Adrien) — et
le jeu la passe de deux images par seconde, mesuré fenêtre au premier plan.
Le banc refuse désormais un relevé pris pendant que la fenêtre change de
focus : ce sont ces transitions, et non le second plan, qui décident du
1 % bas.

En jeu, **F3** ouvre le panneau de diagnostic (fps, ping, transport, lien
direct/relayé, NAT, lumières, particules). Pas de linter ni de CI : la barre
de qualité est « tous les tests headless passent » plus les checklists
manuelles de `docs/`.

## Le jeu en une phrase

Duel 1v1 en vue de dessus dans le noir absolu : la seule information est la
lumière (torche, flash de tir, rétrodiffusion). Toute décision se juge à une
double aune : **immédiat, intuitif, addictif** d'un côté ; **fonctionnel,
léger, honnête en compétition** de l'autre.

## Architecture

Scripts et scènes vivent **à plat à la racine** ; `tools/` porte tests et
bancs, `docs/` la documentation, `assets/` les ressources, `addons/` les
plugins (EOSG pour Epic Online Services, `godot_ai` pour le pont MCP éditeur).

### Autoloads (ordre déclaré dans project.godot)

`PatchLoader`, `ReplaySystem`, `InputSetup`, `AudioManager`, `MapData`,
`NetworkManager`, `GameSettings`, `UpdateManager`, puis `RankedIdentity` et
`Matchmaker`, plus les autoloads du plugin EOSG (`EOSGRuntime`, `HAuth`,
`HLobbies`, `HP2P`…). **L'ordre compte, à deux endroits** : `GameSettings` est
déclaré après `InputSetup` pour que les liaisons de touches sauvegardées
(`user://settings.cfg`) recouvrent les liaisons par défaut, et non l'inverse ;
et `PatchLoader` est **en tête de liste** — c'est une contrainte technique de la
Phase 9, pas un rangement, et le déplacer casse silencieusement les correctifs.

### Boucle de jeu

- `main.tscn` — racine `GameState` + deux `SubViewport` côte à côte. **Les deux
  vues ne s'affichent qu'en « 1v1 écrans scindés » ; partout ailleurs — en
  ligne, à l'entraînement — une seule vue.** (Décision d'Adrien, 2026-08-18 :
  « je ne crois pas que le deuxième écran permanent soit l'identité du jeu ».
  Ce fichier a affirmé le contraire, et l'affirmation a essaimé dans la
  ROADMAP.) Cacher un `SubViewportContainer` **ne suspend pas** son
  `SubViewport` : `_restore_viewports()` coupe aussi le
  `render_target_update_mode` de la vue masquée, sans quoi elle dessine dans une
  texture que personne n'affiche — 1,5 ms mesurées. La séparation des vues passe
  par `canvas_cull_mask` : chaque joueur ne voit que ses propres lumières.

  **En vue unique, le duel n'est plus rendu par un `SubViewport` du tout**
  (chantier R, 2026-08-25) : la racine adopte le même `World2D`, le masque de
  cull de la vue regardée et sa caméra, les deux `SubViewport` s'arrêtent, et le
  jeu est donc rastérisé à la résolution de la **fenêtre** au lieu d'être dessiné
  à 957×1080 puis étiré. Mesuré : **+15 % de cadence pour 3,6 fois plus de
  pixels**, la texture intermédiaire supprimée coûtant plus cher que les pixels
  gagnés sur un GPU à rendu par tuiles. L'écran scindé garde ses deux vues.
  `rendu_racine_autorise` ramène l'ancien chemin en une ligne.

  ⚠️ **Deux conséquences qui ne se devinent pas.** La racine doit cesser d'être
  auditrice pendant la bascule (`audio_listener_enable_2d`), sans quoi chaque son
  positionnel sort **deux fois** — voir « Pièges connus ». Et la densité de texels
  suit désormais la fenêtre en vue unique : une tuile de 35 px tombe à 0,5 texel
  par pixel en plein écran (chantier R, étape R6).
- `game_state.gd` (`GameState`) — orchestration : manches, décompte partagé,
  RPC, spawn des balles, killcam, compensation de latence côté hôte. Format de
  match BO1 5 min, jamais en dur : il transite par `MatchRecord.Format`.
- `player.gd` — simulation, prédiction/correction, interpolation, lumières,
  shaders préchargés (un `Shader.new()` à la volée compile au premier mort :
  hoquet visible pile sur l'action décisive).
- `ui.gd` — HUD, menus, lobby, killcam, navigation à deux curseurs. Gros
  fichier : c'est le seul endroit hors `network_manager.gd` qui ait le droit
  de connaître le transport (bloc lobby uniquement).

### Réseau — hôte-autoritaire

Trois modes (`NetworkManager.GameMode`) : `LOCAL_SPLITSCREEN`, `ONLINE_HOST`,
`ONLINE_CLIENT`. L'hôte simule les deux joueurs ; le client n'envoie que ses
commandes numérotées, prédit son propre joueur (correction sur l'input
acquitté) et interpole l'adversaire depuis un tampon horodaté (100 ms de
retard, extrapolation ≤ 50 ms). Compensation de latence côté hôte : historique
400 ms, recul RTT/2 + retard d'interpolation, plafonné à 200 ms. Les tirs du
client sont prédits localement puis dédupliqués à l'arrivée de la balle
officielle.

- **Transport interchangeable** — `NetworkManager.Transport.EOS` (défaut en
  ligne, code de salon à 6 caractères, traversée de NAT) et `Transport.ENET`
  (LAN/debug). Tout ce qui est au-dessus (RPC, MultiplayerAPI, signaux) est
  identique : **aucun `if transport == ...` hors de `network_manager.gd` et du
  bloc lobby de `ui.gd`**.
- **Nommer explicitement tout nœud ajouté dynamiquement** (`Player1`,
  `GhostP1`…). Un RPC de scène se route par le chemin du nœud ; un nom
  auto-généré (`@CharacterBody2D@269`) dépend de tout ce qui a été instancié
  avant et diverge donc entre machines — les RPC sont alors jetés **sans
  aucune erreur console** (défaut réel, trois manches d'instrumentation pour
  le trouver).

### Entrées

Patron `InputProvider` (classe de base) : `LocalInputProvider` (actions
`p1_*`/`p2_*` de l'Input Map, clavier/souris ou manette par `device_id`) et
`NetworkInputProvider` (alimenté par RPC). `player.gd` ne sait pas d'où
viennent ses commandes.

### Cartes

- `map_data.gd` (autoload) — catalogue et sélection. `res://assets/maps/` est
  en **lecture seule** (cartes livrées, slugs réservés) ; les cartes joueur
  vont dans `user://maps/`, une carte = un fichier nommé.
- `map_codec.gd` — format v3 : RLE des cellules, code de partage
  `CANDELA-<base64(gzip(json))>` (~300-500 caractères), garde-fou
  anti-bombe de décompression à l'import.
- `map_geometry.gd` — produit **toujours ensemble** collision et occlusion
  lumineuse depuis les mêmes rectangles fusionnés (un seul `StaticBody2D` + N
  `LightOccluder2D`) : sans occluder, la torche traverse les murs et la
  mécanique centrale disparaît. Le vide hors sol est solide ; la grille
  déborde d'une case pour fermer la carte.
- Éditeur en jeu : `map_editor*.gd` + `map_gallery.gd` + `map_thumbnail.gd`.

### Enregistrement et archivage

- `replay_system.gd` — enregistre à **cadence fixe 60 Hz**, découplée du
  rendu (les fps sont déplafonnés : dimensionner un tampon en nombre d'images
  a déjà tronqué la killcam à 0,9 s sur une machine à 492 fps). Killcam
  locale : chacun rejoue son propre enregistrement, les deux killcams peuvent
  légitimement différer.
- `match_record.gd` — archive chaque match dans `user://match_history.json` ;
  fondation de l'envoi ELO de la Phase 4 (Supabase), aucune couche réseau ici.

### Rendu

`gl_compatibility` (décision actée, fps déplafonnés pour la latence EOS).
MSAA 2D inopérant sous ce renderer — ne pas le réintroduire. Le gameplay
repose entièrement sur les Light2D/occluders et une poignée de
`.gdshader` à la racine.

### Audio

`AudioManager` (autoload) : deux pools de seize voix — globales et
`AudioStreamPlayer2D` positionnelles —, arbitrage par priorité (un pas ne coupe
pas un coup au but), musique interactive à 170 BPM, bus `Master` / `Music` /
`SFX` / `SFX_Occlus` / `Speaker`.

**L'oreille est posée sur le joueur local** (`poser_oreille`, depuis `4d8a85e`).
Trois gestes qui ne valent que pris ensemble, et dont aucun ne s'entend seul :
le pool **déménage** dans le `World2D` de la vue de jeu (enfant de l'autoload, il
vivait dans celui de la racine), le `SubViewport` est **activé** comme oreille
(`audio_listener_enable_2d` vaut `false` par défaut), et un `AudioListener2D`
est posé sur le joueur. **Ne supprimer aucun des trois sans lire la ROADMAP** —
et surtout pas le troisième : sans auditeur explicite, Godot retombe sur le
centre de l'écran virtuel, un point fixe hors de la carte, ce qui est le défaut
d'origine.

L'oreille suit partout où il n'y a **qu'un** auditeur devant l'écran — en ligne
et à l'entraînement. Pas en écran partagé : deux joueurs y écoutent les mêmes
haut-parleurs. La règle est `oreille_suit(local_idx, entrainement)`, et elle
interroge le **nombre d'auditeurs**, jamais le transport.

Portée et occlusion : `PORTEE_RELATIVE` et `NIVEAU_RELATIF` disent, par son,
jusqu'où il informe et combien il pèse ; la portée se dérive de la **carte**
(`accorder_a_la_carte`, appelée par `rebuild_arena`). Un mur étouffe en routant
le son vers `SFX_Occlus` — même pièce que `SFX`, direct retiré. Le dosage se
fait au banc `tools/banc_audio.tscn`, jamais en éditant une constante à l'aveugle.

> ⚠️ **Ce paragraphe a affirmé le contraire pendant une demi-journée**, et il
> l'affirmait « mesuré le 2026-08-25 » — c'était vrai à l'écriture, faux dès la
> fusion `e3e1b34`. **Une session s'y est fiée sans aller voir le code et a bâti
> une contrainte inter-chantiers sur un état périmé.** Le passage disait vrai au
> présent d'un jour et se lisait comme une propriété du projet. Deux leçons, et
> la seconde est la plus chère : un constat daté **vieillit sans prévenir**, donc
> ce fichier décrit ce que le code FAIT et non ce qui lui manque ; et un défaut
> annoncé ici envoie chercher un travail déjà fait, ce qui coûte plus qu'un
> silence.

## EOS — points de vigilance

La liste complète et à jour est dans la section « Pièges connus » de la
ROADMAP. Les plus destructeurs :

- Copier `eos_credentials.example.gd` en `res://eos_credentials.gd` (ignoré
  par git). Sans lui le jeu démarre normalement, EOS reste « non configuré »,
  seul ENet est disponible. `CLIENT_SECRET`/`ENCRYPTION_KEY` : jamais commités.
- Ne JAMAIS appeler `delete_device_id()` ni `HAuth.login_anonymous_async()` :
  PUID différent à chaque lancement.
- Arrêt propre obligatoire : `EOSGRuntime.set_process(false)` → `await
  get_tree().process_frame` → `release()` → `shutdown()` → `quit()`. Sans
  l'attente d'une frame : segfault (ré-entrée dans `EOS_Platform_Tick()`).
- Deux instances locales partagent le même Device ID → PUID identique : lancer
  avec `--eos-ephemeral` (neutralisé hors build debug).
- Dans un build release, `print()` est tamponné et vidé à la **fermeture
  propre** seulement : tuer le processus jette la fin du journal. Lire
  `~/Library/Application Support/Godot/app_userdata/Candela 2D/logs/godot.log`
  après un quit propre.
