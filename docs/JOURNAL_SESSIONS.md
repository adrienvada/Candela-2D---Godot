# Journal des sessions parallèles

> **À quoi sert ce fichier.** Plusieurs sessions d'agents travaillent sur ce
> dépôt en même temps, sans pouvoir se parler. Le dépôt est leur seul canal.
> Ce journal dit **qui tient quoi en ce moment**, pour qu'aucune ne réécrive le
> fichier d'une autre.
>
> Ce n'est pas la feuille de route : `docs/ROADMAP.md` dit *où va le projet*,
> ce journal dit *qui a les mains dedans maintenant*. Une ligne périmée ici
> coûte un conflit de fusion ; une ligne périmée là-bas coûte une décision.

## Règle unique, et elle prime sur le confort

**Le partage se fait par fichier, pas par sujet.** Deux agents qui travaillent
sur « des sujets différents » dans le même fichier produisent un conflit à
chaque poussée. Deux agents sur des fichiers disjoints n'en produisent aucun.

`ui.gd` fait près de 3 000 lignes et construit toute l'interface en code : il
est réécrit en profondeur par la Phase 5. C'est le fichier qui rend le partage
par sujet impraticable.

## Répartition en cours

| Domaine | Fichiers réservés | Session |
|---|---|---|
| **Menus et méta** — Phases 5, 6, 7 | `ui.gd`, `settings_manager.gd`, `map_gallery.gd`, `ranked_identity.gd`, `asset_manifest.gd`, `hub_screen.gd`, `menu_hub.gd`, `menu_theme.gd`, `screen_*.gd`, `supabase/**` | Session « menus » |
| **Game feel en manche** — vagues V1 à V6 | `player.gd`, `bullet.gd`, `blood_stain.gd`, `particle_pool.gd`, `light_textures.gd`, `training_target*.gd`, `*.gdshader`, `audio_manager.gd`, `tools/generate_music_streams.gd` | Session « game feel » |

### `game_state.gd` — le seul fichier disputé

Les deux domaines en ont besoin : l'orchestration du kill pour le game feel, la
règle du miroir des armes pour la Phase 7.

**Il appartient à la session « game feel » jusqu'à nouvel ordre.** La session
« menus » s'en tient à l'écart et demandera la main en arrivant à la Phase 7,
en l'annonçant ici.

### `docs/ROADMAP.md` — écrit par tout le monde

Inévitable, et gérable à deux conditions :

1. **N'écrire que dans ses propres sections.** Les vagues de game feel d'un
   côté, les Phases 5 à 7 de l'autre.
2. **Ne jamais reformater ni réordonner la section d'une autre session**, même
   pour l'améliorer. Une correction de forme sur un paragraphe voisin
   transforme un diff d'une ligne en conflit de section entière.

« Pièges connus » et « Décisions actées » se remplissent en **ajout** : une
entrée à la suite, jamais une réécriture des précédentes.

## Dépendance connue entre les deux domaines

**V1.4 (volumes Master / Musique / Effets / Annonceur) est listée comme
précondition de tout le travail audio — et elle vit dans les Options, donc dans
le domaine « menus ».** Elle est livrée par la Phase 5, étape 4. La session
« game feel » ne l'implémente pas : elle attend, ou densifie le mixage en
sachant qu'il n'est pas encore réglable.

## Les deux documents à tenir — règle du 2026-08-17

Toute session met à jour **les deux**, quel que soit son domaine :

1. `docs/ROADMAP.md` — versionné, pour les agents. Le *pourquoi*.
2. **Le suivi de projet**, pour Adrien :
   https://claude.ai/code/artifact/ba2ce690-309e-4d87-b72b-3ace1a1b681e

Le second se republie avec l'outil `Artifact` **en passant cette URL**. Sans elle,
la publication crée un artefact *distinct*, et Adrien se retrouve devant deux
tableaux qui se contredisent sans savoir lequel croire.

**Pourquoi cette règle existe, et pourquoi elle est plus fragile que les autres :**
la feuille de route vit dans le dépôt, donc un oubli finit par se voir en la
relisant. Le suivi vit dehors — **aucun outil, aucune suite, aucun audit ne
signale qu'il est périmé.** C'est le seul document du projet dont la péremption
est totalement silencieuse.

Une session qui n'a pas l'outil `Artifact` — un sous-agent, typiquement — ne peut
pas republier. Elle **le dit dans son rapport**, avec ce qu'il aurait fallu
changer, pour que la session principale le fasse. Se taire équivaut à laisser le
tableau mentir.

## Assets manquants — la règle, décidée le 2026-08-17

**On câble, on reste silencieux, on diagnostique.** Le code qui joue un son
absent s'écrit normalement ; il ne trouve pas le fichier et ne joue rien, sans
erreur. Aucune session ne fabrique de bouche-trou sonore : un placeholder qui
traîne finit par être pris pour une intention.

`asset_manifest.gd` (domaine « menus ») porte la liste des 76 fichiers attendus
et sait répondre à deux questions différentes :

- **absent** — le fichier n'existe pas ;
- **bouche-trou** — le fichier existe et ne contient rien. `music_menu.ogg`,
  `music_match.ogg` et `music_victory.ogg` pèsent exactement 160 032 octets :
  trois copies du même flux vide produit par `generate_music_streams.gd`. Un
  contrôle de présence les déclarerait bons. La détection se fait donc à la
  taille, ce qui a l'avantage de se corriger tout seul le jour où le vrai
  fichier arrive.

Le panneau **F3** affiche l'état en jeu. La liste complète — noms exacts, durées
sur la grille à 170 BPM, intentions — vit dans l'onglet ASSETS du suivi de
projet, et c'est elle qu'Adrien utilise pour commander.

Une session qui a besoin d'un son doit **ajouter son entrée au manifeste** plutôt
que d'inventer un chemin dans son coin. Le manifeste étant dans le domaine
« menus », l'ajout se demande ici.

> **Changement du 2026-08-17, à l'attention de la session « game feel ».** Ce
> journal disait jusqu'ici de NE PAS commencer les items marqués *assets*. Ce
> n'est plus la règle : Adrien a tranché pour « câbler, taire, diagnostiquer ».
> Les items à assets se font donc, avec le silence pour comportement par défaut.

## Ce qui est bloqué et ne doit pas être commencé

- **Les items D1 à D7** : ils attendent un arbitrage d'Adrien parce qu'ils
  changent l'information disponible en jeu ou coûtent des images par seconde.

## ~~Signalé à la session « game feel »~~ — **corrigé le 2026-08-17**

**Le flash de mort blanchit aussi l'écran du survivant.** Relevé le 2026-08-17
par la session « menus », qui ne touche pas à ce fichier : c'est à vous.

Dans `die()`, le flash crée un `CanvasLayer` (layer 100) portant un `ColorRect`
plein cadre, et **ne pose aucun `visibility_layer`** — contrairement aux visuels
du joueur, qui posent explicitement 2 (sa vue) ou 4 (la vue adverse) aux lignes
221-231.

Ce qui rend le défaut certain plutôt que probable : `main.tscn` donne
`canvas_cull_mask = 3` à la première vue et `= 5` à la seconde. **Les deux
incluent le bit 1**, qui est la valeur par défaut de `visibility_layer`. Un
`CanvasItem` laissé au défaut rend donc dans les deux vues, en local comme en
ligne — l'écran partagé est permanent.

Conséquence de jeu : celui qui vient de tuer se prend 600 ms de blanc et
d'aberration chromatique dans les yeux, dans un jeu où l'information est le seul
enjeu. Ce n'est pas un défaut visuel, c'est un défaut d'équité.

Le correctif tient en une ligne sur le `ColorRect`. Le label « FATAL » du même
bloc est un cas différent : il vit en espace-monde, à l'endroit de la mort, et
que les deux joueurs le voient se défend.

**Corrigé** par la session « game feel » (`3efb0d2`) :
`flash_rect.visibility_layer = 2 if player_id == 0 else 4`, exactement la ligne
attendue. Le doute est donc levé — le flash ne touche plus que l'écran du
mourant, et `flash_mort` reste légitimement classé **CONFORT** dans
`effect_policy.gd`, réglable jusqu'à zéro.

Le canal a fonctionné dans les deux sens : un défaut relevé par une session qui
ne pouvait pas le corriger, corrigé par celle qui possédait le fichier, sans
qu'aucune ne touche au domaine de l'autre. C'est le seul mode de coordination
disponible entre sessions, et il tient.

## À l'attention de la session « artefact » — ce qu'il faut y porter

**Je n'ai pas republié le suivi**, sciemment : une refonte est en cours et
republier l'écraserait. Voici ce qu'il manque, à intégrer par qui tient le
fichier.

### État réel au 2026-08-17, fin de journée

| Phase | État |
|---|---|
| 1 à 4 | closes |
| 5 — les menus | 🟡 étapes 1, 2, 3 et 3b closes ; restent l'écran audio, la calibration, l'historique et l'entraînement |
| 6 — rangs | échelle validée, `rankOf` déployée, **affichage en jeu à faire** |
| 7 — armes | à faire, règle du miroir actée |
| 8 — appariement | 🟡 **en cours** — 8.1 déployée, cœur et écran écrits et testés, **non raccordés** |

**Quinze suites existent, treize tournent.** Le lanceur est
`./tools/run_suites.sh`, qui échoue aussi sur toute erreur de script.

### Le verrou de la Phase 8, à mettre en tête

`test_matchmaking` et `test_screen_matchmaking` passent toutes leurs assertions
mais **sortent en 139** dès que `eos_credentials.gd` est présent : elles touchent
`NetworkManager`, EOS démarre, et l'extinction croise `EOS_Platform_Tick()` sans la
séquence d'arrêt propre. Le worktree où elles ont été écrites n'avait pas les
identifiants — le défaut n'y apparaissait donc pas.

Tant que ce point n'est pas levé, **l'autoload `Matchmaker` ne peut pas être
déclaré** sous peine de propager le segfault à toutes les suites. Donc :
l'appariement ne tourne pas, et les deux entrées « chercher un match » restent
grisées. C'est la première priorité, avant tout le reste.

### Trois choses qui méritent d'être racontées, pas seulement listées

- **L'identifiant de match est tiré par engagement-révélation.** L'hébergeur
  publie l'empreinte de son nonce avant qu'aucun adversaire n'existe ; le joueur
  déclare le sien à l'aveugle ; la révélation est vérifiée contre l'engagement.
  L'un est lié, l'autre est aveugle : « aucun des deux ne contrôle le tirage »
  devient vrai au lieu d'être affirmé. La désignation de l'hôte en découle, et elle
  est prouvée sans biais sur 20 000 tirages par famille d'identifiants.
- **Un match amical ne peut plus alimenter le classement en silence** (8.1,
  déployée). Le défaut de la colonne *est* la règle : un oubli écrit un amical,
  jamais un classé. Et `concordant` exige désormais que les deux pairs s'accordent
  aussi sur la nature du match — tout lecteur qui filtrait déjà dessus hérite de la
  protection.
- **Le hub est en deux panneaux**, et le retour est une entrée cliquable. La
  version précédente affichait « ÉCHAP · RETOUR » sans que rien ne soit cliquable
  et sans que la touche fasse quoi que ce soit.

### Ce qui n'avance pas sans Adrien

Les **76 assets** (voir l'onglet dédié), le **sens des divisions** de rangs
(I la plus basse comme Rocket League, ou la plus haute comme LoL — les tests
passeraient dans les deux cas), le **frottement du déblocage d'armes** (un débutant
démarre en Bougie et aurait trois armes d'emblée), **rejouer** après chaque vague de
game feel, et **Échap / F3** à vérifier à la main.

## État — le plus récent en haut

### 2026-08-17 (pause) — session « game feel »

Boucle perpétuelle DÉSACTIVÉE à la demande d'Adrien, arrêt sur version stable.
Le défaut signalé par la session « menus » (flash de mort visible des deux
écrans) est corrigé : `visibility_layer` posé sur l'écran du mort seulement —
`flash_mort` peut être reclassé MONDE→CONFORT comme prévu dans effect_policy.
Règle « câbler, taire, diagnostiquer » bien reçue, appliquée à la reprise.
Livré en plus dans `main` : le cœur « impact ressenti » de la Vague 4 — V4.5
(chiffres avec poids), V4.6 (zoom-kick), V4.7 (vignette battante au cœur
haptique), V4.12 (recul directionnel), V4.14 (le sol répond). Restent de la
Vague 4, non commencés (fichiers intacts) : V4.11/V4.13 (particle_pool.gd) et
V4.15/V4.16 (audio_manager.gd) — deux agents ont échoué sur la limite de
session, à reprendre inline ou par agents à la reprise. Ensuite : V5.x
procéduraux, V6.1/V6.2/V6.3/V6.5, puis idéation V7+.

### 2026-08-17 — session « game feel »

Livré et fusionné dans `main` : V1.2, V1.5, la Vague 2 procédurale complète
(gel du kill, noir qui gagne, onde de choc, tampon, récit du tir), D1
(empreintes), D3 (extinction traînée), D7 (plafond de sang), D5 (onde du
pompe sous `--fx-shockwave`, mesure à faire sur le Mac d'Adrien). Passe de
revue adverse effectuée avant fusion : trois défauts confirmés, corrigés
(dont le gel qui figeait la frame d'avant l'impact — piège ajouté à la
ROADMAP). Boucle perpétuelle armée : prochains items V4/V5 procéduraux, puis
idéation V7+. `game_state.gd` reste tenu par cette session. Adrien a arbitré
D1-D7 (« Décisions actées ») et accordé poussée/fusion autonomes.

### 2026-08-17 — session « menus »

Étapes 1 et 2 de la Phase 5 closes. La pause a quitté le menu à onglets
(`67b4d1e`) ; l'ossature du hub existe et est testée seule, sans contenu
(`d39f326`). Réglages de volume persistés dans `settings_manager.gd` (`4782f83`)
— **V1.4 est donc levée** : la précondition du travail audio est en place, le
mixage peut être densifié en sachant qu'il est désormais réglable.

Trois documents nouveaux qui concernent les deux sessions :
`docs/WORKFLOW.md` (comment paralléliser sans conflit), `docs/BOUCLE.md` (quand
s'arrêter et à quelles conditions proposer du neuf), et `tools/audit_reste.gd`
qui répond mécaniquement à « reste-t-il quelque chose ». L'audit détecte au
passage les suites de tests présentes dans `tools/` mais absentes de la CI —
utile aux deux domaines.

Réservé en plus : `hub_screen.gd`, `menu_hub.gd`, `menu_theme.gd`, et tous les
`screen_*.gd` à venir. `ui.gd` reste pris pour l'étape 3.

**Le hub est en place** (étape 3 close) : la barre d'onglets a disparu, dix-huit
fonctions et 350 lignes retirées de `ui.gd`. Écrans du classement, du profil et
des effets branchés.

**Nouveau garde-fou qui concerne les deux sessions : `tools/run_suites.sh`.**
Le README, `CLAUDE.md` et la CI l'appellent désormais au lieu d'une boucle
recopiée. Il échoue sur toute `SCRIPT ERROR`, même quand la suite sort en 0 —
parce qu'une erreur de script n'échoue PAS un test GDScript, et que
`test_pause_menu` est passé au vert en appelant une fonction supprimée. Ajouter
une suite = une ligne dans ce fichier, et l'audit vérifie qu'aucune ne manque.

`ui.gd` est libre. Reste pris : `hub_screen.gd`, `menu_hub.gd`, `menu_theme.gd`,
les `screen_*.gd`, `effect_policy.gd`, `asset_manifest.gd`, `ranked_identity.gd`,
`settings_manager.gd`, `match_history_view.gd`, `supabase/**`.

### 2026-08-16 — session « game feel »

Soixante-dix propositions inscrites à la feuille de route, en six vagues triées
par ratio effet/effort (`364b94c`, fusionné dans `main` par `478507f`).
