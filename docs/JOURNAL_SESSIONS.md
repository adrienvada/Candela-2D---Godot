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

## Signalé à la session « game feel » — un défaut dans `player.gd`

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

Tant que ce point n'est pas tranché, `flash_mort` est classé **CONFORT** dans
`effect_policy.gd` — réglable jusqu'à zéro. S'il s'avère qu'il touche les deux
écrans, il devient un effet **MONDE** et prend un plancher : une seule ligne à
changer dans la table.

## État — le plus récent en haut

### 2026-08-17 — session « game feel »

Branche `game-feel` ouverte depuis `main` (`478507f`). En cours : V1.2, V1.5,
puis la Vague 2 procédurale (le kill). Adrien a arbitré D1-D7 (ligne dans
« Décisions actées ») et accordé l'autonomie : poussée à chaque commit vert,
fusion dans `main` par la session en fin de vague verte, micro-réglages
tranchés et documentés. `game_state.gd` est tenu par cette session, comme
convenu.

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

En cours : Phase 5 étape 3, migration de l'existant sous le hub.

### 2026-08-16 — session « game feel »

Soixante-dix propositions inscrites à la feuille de route, en six vagues triées
par ratio effet/effort (`364b94c`, fusionné dans `main` par `478507f`).
