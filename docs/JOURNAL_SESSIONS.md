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
| **Menus et méta** — Phases 5, 6, 7 | `ui.gd`, `settings_manager.gd`, `map_gallery.gd`, `ranked_identity.gd`, `supabase/**`, tout nouveau script de menu | Session « menus » |
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

## Ce qui est bloqué et ne doit pas être commencé

- **Tout item marqué *assets*** dans la section game feel : les fichiers audio
  n'existent pas dans le dépôt. Aucune session ne doit inventer de bouche-trou
  sonore — un placeholder qui traîne finit par être pris pour un choix.
- **Les items D1 à D7** : ils attendent un arbitrage d'Adrien parce qu'ils
  changent l'information disponible en jeu ou coûtent des images par seconde.

## État — le plus récent en haut

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

Phase 5 étape 1 close (`67b4d1e`) : la pause est sortie du menu à onglets et
vit dans son propre panneau. Septième suite headless ajoutée,
`tools/test_pause_menu.gd`, qui instancie le vrai `ui.gd`.

En cours : Phase 5 étape 2, l'ossature du hub. `ui.gd` est donc pris.

### 2026-08-16 — session « game feel »

Soixante-dix propositions inscrites à la feuille de route, en six vagues triées
par ratio effet/effort (`364b94c`, fusionné dans `main` par `478507f`).
