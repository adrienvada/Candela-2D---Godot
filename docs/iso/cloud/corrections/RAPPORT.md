# Corrections proposées par la répétition — session cloud `claude/cloud-corrections`

> **Poussée.** Le premier `git push` de la session (le 2026-09-27 au soir) a été refusé
> par le garde des permissions ; les commits sont restés locaux jusqu'au feu vert relayé
> par la session coordinatrice le 2026-09-28 vers 12:45 (« Fais en sorte que les sessions
> cloud 30h qui n'ont pas fini terminent », Adrien). Le plan n'a donc pas pu être vu de
> dehors dans les 30 premières minutes. D3 était déjà terminé et prouvé avec sa garde
> (`test_drapeaux`) ; rien ne lui manquait.

## Pour Adrien, en cinq lignes

1. Les huit corrections trouvées par la répétition de ton test sont faites, **une par
   « paquet »**, pour que chacune puisse être reprise ou laissée seule.
2. **Équité** : les touches 1, 2, 3, 4, 0 et F2 ne changent plus l'aspect de l'image en
   partie publiée ou en ligne (elles restent pour les essais de développement).
3. Les options de lancement marchent maintenant **avec ou sans les deux tirets** `--` :
   `godot --path . --sans-usure` fait enfin ce qu'il dit.
4. Les deux messages d'erreur rouges (ouvrir l'éditeur après un match, le quitter par
   Échap) ont disparu, ainsi que la fuite signalée à la fermeture après un match en ligne.
5. La suite de tests est **verte** après le dernier changement ; la cadence n'a pas été
   mesurée ici (on ne la mesure que sur ton Mac).

> Base : `origin/integration-iso14` à `60e5c6d`. Session du 2026-09-27 au soir et
> 2026-09-28 (Paris). Rendu logiciel (llvmpipe) sous Xvfb : les images valent pour ce qui
> est affiché, **pas** pour la cadence. Aucun chiffre d'images par seconde ici.

## Le tableau

Chaque ligne est **un commit**, qui s'applique **seul** sur `60e5c6d` (vérifié :
`git cherry-pick -n <commit>` sur `60e5c6d`, un par un, sans conflit). Les hashs sont ceux
de la branche locale `claude/cloud-corrections`.

| Défaut | Fichier(s) | Commit | Preuve avant → après | Qui devrait le reprendre |
|---|---|---|---|---|
| **D4** — touches de pâte en plein match, build publié et en ligne | `presentation_3d.gd` (+ `tools/test_touches_pate.gd`, `run_suites.sh`) | `42ef6b3` | `test_touches_pate.gd` : erreur d'analyse (fonction absente) → vert ; garde retiré de `_input` seul : 2 échecs, code 1 | la session qui tient `presentation_3d.gd` (Iso) |
| **D3** — drapeaux lus de deux façons (avant/après `--`) | `drapeaux_de_lancement.gd` (neuf) + 13 scripts de la racine (+ `tools/test_drapeaux.gd`, `run_suites.sh`, et deux contrôles de source qui attendaient l'ancienne lecture : `test_iso_gadgets.gd`, `test_corps_mannequin.gd`) | `2caff10` | `test_drapeaux.gd` sur les fichiers de la base : 12 échecs (11 états différents avant/après `--`, 20 lectures directes) → vert | l'intégration (touche des fichiers de plusieurs domaines) |
| **E1** — `!is_inside_tree()` à l'ouverture de l'éditeur après un match | `audio_manager.gd` | `751f11d` | parcours du pilote `diag,editeur,quitter` : 1 occurrence → 0 (la ligne « pool hors de l'arbre » apparaît à sa place) ; match ENet headless (voir E3), hôte + invité : 2 → 0 | la session qui tient `audio_manager.gd` |
| **E2** — `set_input_as_handled` sur `null` en quittant l'éditeur par Échap | `map_editor.gd` | `2a71bfd` | même parcours : 1 → 0 | la session qui tient l'éditeur |
| **E3** — appareil de brouillage orphelin à la sortie après un match en ligne | `game_state.gd` | `e115365` | match ENet headless, hôte en `--verbose` : 15 instances en fuite + 2 ressources → aucune | la session qui tient `game_state.gd` |
| **C4** — `ecran_hz` NaN sous Xvfb vers l'historique | `conditions_de_match.gd` (+ 2 contrôles dans `test_conditions_de_match.gd`) | `4e74fa3` | F6 dans le parcours : `ecran_hz nan` → `ecran_hz -1.0` | la session qui tient le diagnostic (PE2) |
| **7a** — `run_photos.sh` sortait en 0 sur une `SCRIPT ERROR` | `tools/run_photos.sh` | `fe8fba1` | faux Godot qui imprime une SCRIPT ERROR et sort en 0 : code 0 → code 1 | qui tient le photographe |
| **7b** — le photographe photographiait l'intro d'un `user://` neuf | `tools/photographe.gd` | `f957e59` | `--plan=accueil` en foyer neuf : l'intro (image `images/7b_avant_…`) → l'accueil (`images/7b_apres_…`) ; `settings.cfg` : `intro_vue=true` écrit → aucun fichier écrit | qui tient le photographe |
| **D2** — `CLAUDE.md` : « F5 l'éditeur de cartes » | `CLAUDE.md` (une phrase) | `9ecb91b` | `grep -rn KEY_F5 --include=*.gd . \| grep -v tools/` → une seule ligne, dans l'éditeur | l'intégration |

Deux commits d'**outillage**, à ne PAS reprendre avec les correctifs :

- `ad32d61` — `tools/cloud_repetition/` repris tel quel de `origin/claude/cloud-repetition`
  (le pilote et le banc en ligne qui rejouent les parcours où E1/E2/C4 se voyaient).
- `b9068c7` — les deux corrections du photographe sous Xvfb, reprises telles quelles de
  `origin/claude/cloud-photographe` (`0c67705`). À reprendre depuis SA branche.

Non touchés, comme demandé (choix d'Adrien) : **D1** (l'entraînement et sa carte),
**C1** (l'affiche de fin), **C3** (le retour de l'éditeur).

## Les décisions, et leur pourquoi

- **D4 — le garde porte sur les touches seules**, pas sur tout `_input` : `_input` ne
  fait aujourd'hui que la pâte, mais un ajout futur (visée, etc.) n'a pas à hériter d'un
  garde de débogage. La fonction `Presentation3D.touches_de_pate_actives()` est ce que le
  test tient. ⚠️ Le build publié ne se simule pas en headless (le binaire est de
  débogage) : le test lit donc la source pour vérifier que `_input` consulte le garde
  AVANT de lire les touches. C'est un test de structure, pas de comportement.
- **D3 — une classe neuve, `DrapeauxDeLancement`**, plutôt que `GameSettings._arguments()`
  rendu public : `fusee_modele.gd` lit son drapeau dans l'initialiseur d'une variable
  statique, au chargement de la classe, avant que les autoloads existent ; et faire
  dépendre `iso_materiaux.gd` ou `voxel_catalogue.gd` de l'autoload des réglages créait
  un couplage qu'ils n'ont pas. L'ordre de lecture (après `--` d'abord, puis le reste)
  est celui que `settings_manager.gd` a toujours eu. **Tous** les lecteurs de la racine
  y passent, y compris ceux qui lisaient déjà les deux listes (`network_manager.gd`,
  `ranked_identity.gd`, `charte.gd`, `mur_led.gd`, `settings_manager.gd`) et
  `update_manager.gd` qui ne lisait QUE ce qui précède `--` (`--sans-maj`) : aucun nom ni
  aucun sens ne change, seul l'endroit où on peut écrire un drapeau s'élargit. Le test
  interdit désormais toute lecture directe hors de cette classe à la racine (pas dans
  `tools/`, où les bancs lisent leurs propres options).
  ⚠️ **Nouvelle classe** : après la reprise, `godot --headless --path . --import`, sinon
  le registre des classes est en retard (piège déjà connu).
- **D3 — `--pate D` n'est pas éprouvé avant `--`** : un mot nu (`D`) parmi les arguments
  du moteur peut être pris par Godot pour autre chose. La lecture de `--pate` passe par la
  classe partagée comme les autres ; seul le test l'évite.
- **E1 — la ligne du diagnostic dit ce qui se passe** (« pool hors de l'arbre ») au lieu
  de se taire : le traceur est un outil de diagnostic, un silence y serait une absence
  qu'on ne voit pas.
- **E2 — l'entrée marquée traitée AVANT d'agir**, pour les trois branches d'Échap (elle
  l'était déjà dans les trois cas) : pas de changement de comportement.
- **E3 — `NOTIFICATION_PREDELETE` plutôt que `_exit_tree`** : `_exit_tree` vaudrait aussi
  pour un `GameState` retiré puis remis dans l'arbre ; on ne libère qu'à sa destruction,
  et seulement les appareils **sans parent** (ceux dans l'arbre partent avec leur vue).
- **E3, la musique : rien n'a été changé**, faute de l'avoir vue fuir. Dans le match ENet
  **headless** (deux processus, l'hôte en `--verbose`), la base `60e5c6d` fuit
  **15 instances, toutes de l'appareil de brouillage** (`CanvasLayer`, `BackBufferCopy`,
  `Node`, `ColorRect`, `TextureRect`, `Shader`, `ShaderMaterial`, `Gradient`…, et les
  ressources `brouillage_flou.gdshader` et `brouillage_vue.gd`) ; **aucune ligne de la
  musique** (`AudioStreamSynchronized`, `OggPacketSequencePlayback`). Après le correctif :
  **zéro** ligne de fuite, des deux côtés. La fuite de la musique que la répétition a vue
  venait de ses parcours **en fenêtre** ; mon essai en fenêtre (`test_online_match` sous
  Xvfb, deux processus) n'est pas allé jusqu'à la manche (« la manche démarre » en échec,
  le même symptôme que N2 de la répétition, lu comme l'horloge du rendu logiciel), donc
  il ne prouve rien dans un sens ni dans l'autre. Ce que j'ai lu : la musique vit dans
  `AudioManager.music_player` (`audio_manager.gd` l. 1391) ; la sortie du jeu passe par
  `NetworkManager.quit_game` → `_shutdown_eos_and_quit` → `get_tree().quit()` sans
  arrêter ce lecteur. Si la fuite se confirme sur le Mac, le geste proposé est
  `AudioManager.music_player.stop()` juste avant `get_tree().quit()` dans
  `network_manager.gd` — **non fait**, faute de preuve.
- **C4 — −1 plutôt que 0** pour une fréquence inconnue : c'est la convention de
  `DisplayServer.screen_get_refresh_rate()` elle-même.
- **7a — le lanceur imprime les deux lignes fautives** (la `SCRIPT ERROR` et son `at:`)
  et sort en 1 ; les photos déjà prises restent dans le dossier.
- **7b — l'intro n'est pas congédiée, elle n'est pas démarrée.** `photo_essais.gd`
  (origin/claude/cloud-essais) la congédie après coup ; mais le jeu écrit
  `intro_vue=true` dans `user://settings.cfg` **au démarrage** de l'intro, donc le foyer
  gardait la trace d'une intro que personne n'a vue. Ici, `GameSettings.intro_vue` est mis
  à vrai **en mémoire** le temps du `_ready()` de `main.tscn` (où le jeu décide), puis
  rendu. L'allumage prend la place de l'intro et le photographe le congédie comme toujours.
  `cineaste.gd` hérite du correctif. Vérifié : dans un foyer neuf, **aucun**
  `settings.cfg` n'est écrit par la séance.
- **D3/D4 et `run_suites.sh`** : deux ajouts de suite, chacun sur sa propre ligne
  `SUITES+=(…)`, posés à deux endroits éloignés du lanceur — sans quoi reprendre D3 sans
  D4 faisait un conflit (vérifié, puis corrigé en recomposant la chaîne locale).
- **D3 corrige aussi deux contrôles de source existants** (`test_iso_gadgets.gd` exigeait
  `for arg in OS.get_cmdline_user_args():` dans `iso_volumes.gd`, `test_corps_mannequin.gd`
  comptait `OS.get_cmdline_user_args().has(DRAPEAU_MANNEQUIN)`) : ils tenaient la lecture
  « après `--` seulement » comme une propriété, alors qu'elle était le défaut. Ils exigent
  désormais la porte commune ; leur intention (le drapeau est lu, une seule fois) est
  gardée. Trouvé par la première suite complète (2 échecs), corrigé DANS le commit D3
  pour que D3 repris seul garde la suite verte.

## La suite complète

`GODOT=/usr/local/bin/godot ./tools/run_suites.sh` sur `f957e59` (le dernier commit de code ;
le rapport ne touche que `docs/`) : **« tout passe, sans erreur de script » en 596 s**, code 0
(122 lignes OK au journal). Un premier passage, sur la chaîne d'avant la
recomposition, avait trouvé les deux contrôles de source que D3 devait suivre (voir plus haut).

## Les commandes pour tout refaire

```bash
# Godot 4.7 en /usr/local/bin/godot, xvfb-run présent, puis :
git checkout claude/cloud-corrections
godot --headless --path . --import                       # nouvelle classe DrapeauxDeLancement
GODOT=/usr/local/bin/godot ./tools/run_suites.sh         # la suite complète

# D4 et D3, seuls :
godot --headless --path . --script res://tools/test_touches_pate.gd
godot --headless --path . --script res://tools/test_drapeaux.gd
# … et la même chose sur la base : les fichiers du jeu de 60e5c6d, les deux tests gardés.

# E1, E2, C4 — le parcours de la répétition (≈ 10 min sous rendu logiciel) :
mkdir -p /tmp/p/foyer
HOME_PILOTE=/tmp/p/foyer GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
  ./tools/cloud_repetition/run_pilote.sh --etapes=diag,editeur,quitter --sortie=/tmp/p/images > /tmp/p/pilote.log 2>&1
grep -c 'is_inside_tree' /tmp/p/pilote.log                          # E1 : 1 avant, 0 après
grep -c "set_input_as_handled' on a null" /tmp/p/pilote.log         # E2 : 1 avant, 0 après
grep 'ecran_hz' /tmp/p/pilote.log                                   # C4 : nan avant, -1.0 après

# E3 — deux foyers où l'intro est vue, un match ENet headless :
for h in hote invite; do d="/tmp/e3/$h/.local/share/godot/app_userdata/Candela 2D"; mkdir -p "$d"
  printf '[display]\n\nintro_vue=true\n' > "$d/settings.cfg"; done
CANDELA_PORT=29431 HOME=/tmp/e3/hote godot --verbose --headless --path . \
  res://tools/test_online_match.tscn -- --host --transport enet --no-eos > /tmp/e3/hote.log 2>&1 &
sleep 8
CANDELA_PORT=29431 HOME=/tmp/e3/invite godot --headless --path . \
  res://tools/test_online_match.tscn -- --join 127.0.0.1 --transport enet --no-eos > /tmp/e3/invite.log 2>&1
wait
grep "leaked at exit\|still in use" /tmp/e3/hote.log                # E3 : 15 instances avant, rien après

# 7a — un faux Godot qui crie et sort en 0 :
printf '#!/bin/sh\necho "SCRIPT ERROR: essai"\nexit 0\n' > /tmp/faux && chmod +x /tmp/faux
GODOT=/tmp/faux ./tools/run_photos.sh --liste; echo $?              # 0 avant, 1 après

# 7b — le photographe dans un foyer neuf :
rm -rf /tmp/f && mkdir -p /tmp/f
HOME=/tmp/f GODOT=/usr/local/bin/godot GODOT_ARGS="--fixed-fps 60" \
  xvfb-run -a -s "-screen 0 1920x1080x24" ./tools/run_photos.sh --plan=accueil
ls "/tmp/f/.local/share/godot/app_userdata/Candela 2D/"             # pas de settings.cfg après
# image : …/photos/menus/01-accueil.png (l'intro avant, l'accueil après)
```

## Ce que je n'ai PAS pu prouver

- **D4 en build publié** : le cloud n'a qu'un binaire de débogage. Le test prouve que le
  garde existe et qu'il est consulté ; qu'il rende faux en build publié tient à
  `OS.is_debug_build()` lui-même (comme F7).
- **E3, la musique** : voir plus haut — pas vue en headless, pas atteinte en fenêtre.
- **La cadence** : aucune mesure ici. Les correctifs ne touchent aucun chemin d'image
  chaud (D3 est lu une fois ou au chargement là où il l'était déjà ; le garde D4 est un
  booléen sur un appui de touche).
- **Le Mac** : rien n'a été lancé sur la machine d'Adrien ; en particulier, la phrase de
  `CLAUDE.md` (D2) et le photographe (7b) n'y ont pas été rejoués.

## Défauts vus en passant (signalés, non corrigés)

- **Deux `.uid` manquent sur `integration-iso14`** : `godot --headless --path . --import`
  crée `tools/banc_equite_fusee.gd.uid` et `volume_masque.gdshaderinc.uid`, absents du
  dépôt (`git status` après l'import, sur `60e5c6d`). Le dépôt versionne les `.uid` (469
  pour 471 `.gd`). **Versionnés ici dans un commit à part**, à la demande de la session
  coordinatrice (2026-09-28).
- **Le match ENet en fenêtre** (`test_online_match` sous Xvfb, deux processus) échoue sur
  « la manche démarre » — même symptôme que N2 de la répétition. Non prouvé.

## À reporter dans la feuille de route (par l'intégration)

- Piège : **les drapeaux se lisaient de deux façons** (D3). Désormais une seule porte,
  `DrapeauxDeLancement` ; un drapeau lu ailleurs fait rougir `test_drapeaux`.
- Décision : **les touches de pâte ne vivent qu'en build de débogage** (équité, D4).
- Piège d'outil : **un `user://` neuf joue l'intro par-dessus la scène**, et la congédier
  après coup écrit quand même `intro_vue=true` dans les réglages du foyer (7b).
