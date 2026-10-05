# Consignes communes — audit d'optimisation de Candela 2D (2026-10-04)

Tu es un sous-agent d'un audit d'optimisation complet du jeu, orchestré par une autre session.
Plusieurs sous-agents travaillent en parallèle, chacun sur un domaine. Ton domaine et tes fichiers
sont dans ton message de mission ; ces consignes valent pour tous.

Dépôt : `/home/user/Candela-2D---Godot` — commit `52a29c1` (version 0.8.3 + SOLO S12).
Dossier de travail (le SEUL où tu écris) : `docs/audit_optimisation/`

## Le projet en bref

- Godot **4.7**, GDScript, renderer **`gl_compatibility`** (décision actée). Fps **déplafonnés** (latence EOS).
- Duel 1v1 dans le noir absolu ; la seule information est la lumière (torche, flash de tir, rétrodiffusion).
  Depuis ISO6 (2026-09-15) la vue par défaut est **isométrique** ; la vue de dessus 2D reste le **moteur de
  lumière** que l'iso projette (drapeau `--2d` pour l'ancienne vue).
- Réseau **hôte-autoritaire** (EOS par défaut, ENet en LAN) : l'hôte simule les deux joueurs, le client
  prédit/corrige et interpole l'adversaire (100 ms de retard), compensation de latence côté hôte.
- Cible de performance : **« 1 % bas ≥ 60 »** (décision d'Adrien, 2026-08-25). Machine de référence
  d'Adrien : **MacBook M3** (GPU à tuiles : la surface rastérisée et les mélanges coûtent cher), écran 60 Hz.
- Double aune de toute décision : **immédiat, intuitif, addictif** d'un côté ; **fonctionnel, léger,
  honnête en compétition** de l'autre. Une optimisation qui abîme la lisibilité de la lumière, l'équité en
  ligne ou l'identité visuelle n'en est pas une : signale le compromis au lieu de le trancher.
- Scripts et scènes à plat à la racine ; `tools/` = tests et bancs ; `docs/` = documentation.

## Règles strictes

1. **Lecture seule.** Ne modifie, ne crée, ne supprime AUCUN fichier du dépôt. Aucune commande git qui écrit
   (commit, checkout, stash, reset, worktree…). Tu n'écris que dans le dossier de travail ci-dessus.
2. **Ne lance PAS Godot**, sous aucune forme : un seul agent est chargé des mesures de cadence sur cette
   machine (4 cœurs) et un second processus lourd fausserait ses chiffres. Pour la même raison, évite les
   commandes coûteuses : **pas de grep récursif** sur `addons/` ni `assets/` (430 Mo à eux deux) ni depuis la
   racine ; cible les fichiers (`*.gd`, `*.gdshader`, `*.gdshaderinc`, `*.tscn`, `*.tres`, `project.godot`,
   `tools/…`, `docs/…`). Ignore tout dossier `.claude/` ou `.godot/`.
3. **`docs/ROADMAP.md` fait 2,9 Mo (34 455 lignes) : ne le lis PAS en entier** (d'autres agents s'en chargent
   par tronçons). Cherches-y (`grep -n -i`) les mots-clés de ton domaine et lis les passages trouvés. C'est la
   mémoire du projet : mesures, décisions, et « Pièges connus » (l. 3272-10337) — des erreurs déjà payées.
   Repères utiles à tous : « Décisions actées » (l. 2434), « Chantier — la résolution de rendu du duel »
   (l. 17002), « Chantier — l'allègement de la 0.8.0 » (l. 30456), « Prochaines étapes » (l. 33917),
   « D'où viennent les millisecondes du duel » (l. 34076), « Journal des relevés de cadence » (l. 34222).
   Lis aussi `CLAUDE.md` à la racine (≈ 300 lignes) : il résume l'architecture et plusieurs pièges.
4. **Avant de recommander quoi que ce soit, vérifie que ce n'est pas déjà fait, mesuré, refusé ou proscrit.**
   Exemples de choses proscrites ou déjà payées : MSAA 2D (inopérant sous ce renderer) ; `Shader.new()` à la
   volée (hoquet au premier mort) ; supprimer un des trois gestes de l'« oreille » audio ; dissocier collision
   et occlusion lumineuse ; laisser un nœud dynamique sans nom explicite (RPC jetés sans erreur) ; dimensionner
   un tampon en images plutôt qu'en temps (fps déplafonnés) ; masquer un `SubViewportContainer` sans couper le
   `render_target_update_mode` de sa vue.
5. **Sois factuel.** Chaque constat cite `fichier:ligne` et l'extrait de code. Distingue le **PROUVÉ** par
   lecture (« le code alloue un Dictionary par balle et par image ») de l'**ESTIMÉ** (« probablement de l'ordre
   de 0,1 ms »). Aucun chiffre inventé ; une chose non mesurée s'écrit comme non mesurée. Si tu doutes qu'un
   chemin soit chaud, remonte ses appelants jusqu'à le savoir.
6. **Hiérarchise.** Chemin chaud (par image, par tick physique, par paquet) > par événement (tir, mort,
   manche) > chargement/démarrage > code froid. Une micro-optimisation sur du code froid tient en une ligne.
   Mieux vaut 6 constats solides et vérifiés que 25 approximatifs.
7. Rédige en **français**.

## Méthode suggérée

1. Lis `CLAUDE.md`. Puis cartographie ton domaine : `grep -n` des `_process`, `_physics_process`, `_input`,
   `_unhandled_input`, `_draw`, `queue_redraw`, `set_process`, `set_physics_process`, `_integrate_forces`,
   `Timer`, `create_tween`, `connect(` à haute fréquence. Établis ce qui tourne par image / tick / paquet /
   événement, et les quantités (combien de nœuds, lumières, balles, voix, PNJ… au pire cas d'un duel).
2. Lis en entier les fichiers de ton domaine ; pour les très gros, les fonctions du chemin chaud et tout ce
   qu'elles appellent (y compris hors de ton domaine si nécessaire).
3. Pour chaque constat candidat, cherche dans la ROADMAP s'il est connu, mesuré, décidé ou proscrit.
4. Rédige le rapport.

## Liste de contrôle générique (GDScript, Godot 4.7, gl_compatibility)

**CPU**
- Allocations dans le chemin chaud : Array/Dictionary/Packed*Array/String créés par image, `str()` / `%` /
  `format` par image, lambdas ou `Callable` créées par image, `PhysicsRayQueryParameters2D.create()` par requête.
- Recherches de nœuds dans le chemin chaud : `get_node` / `$` / `find_child` / `get_nodes_in_group` par image.
- `print()` dans un chemin chaud : `run/flush_stdout_on_print=true` (PE2.4) vide le journal à CHAQUE print,
  en release aussi.
- Variables non typées dans les boucles chaudes ; boucles O(n²) ; tris par image ; `has_method()` / `call()`
  dynamiques par image.
- `create_tween()` / `create_timer()` / `instantiate()` / `queue_free()` par image ou par balle sans pool ;
  objets qui **s'accumulent sur une manche** (traces, douilles, taches, décalcomanies) sans plafond.
- Signaux émis par image vers beaucoup d'abonnés ; `set_process(true)` jamais rendu ; nœuds masqués ou hors
  écran qui continuent de calculer.
- Requêtes physiques (raycasts, `intersect_shape`) par image et par entité.
- Travail synchrone lourd sur le fil principal **à un moment décisif** (premier tir, première mort, début de
  manche, fin de match) : `load()`, compilation de shader, `Image` manipulée en GDScript, écriture de fichier,
  JSON volumineux, `get_image()` (synchronise le GPU).

**GPU (2D sous gl_compatibility ; GPU à tuiles sur le Mac)**
- Surface rastérisée et sur-dessin : couches additives ou translucides plein écran ; textures de lumière dont
  la surface suit le CARRÉ de l'échelle (leçon payée de la 0.8.0).
- `Light2D` / `PointLight2D` : nombre simultané au pire cas, `shadow_enabled`, filtre d'ombre, portée et
  `texture_scale`, masques (`range_item_cull_mask`, `shadow_item_cull_mask`) ; chaque lumière ombrée rend les
  occluders ; un élément éclairé par N lumières se dessine en plusieurs passes.
- Lecture d'écran (`hint_screen_texture`, `BackBufferCopy`) : une copie de tampon par usage.
- `SubViewport` : taille, `render_target_update_mode`, vues masquées qui rendent encore.
- Matériaux dupliqués par instance (cassent le regroupement des appels de dessin) ; `set_shader_parameter`
  par image sur beaucoup de matériaux ; textures régénérées et re-téléversées (`ImageTexture.update`) par image.
- Shaders compilés au premier usage (hoquet) ; nombre de variantes.

**Réseau** : RPC envoyés au rythme du rendu (fps déplafonnés !) au lieu d'un pas fixe ; charges utiles en
Variant/Dictionary/String ; fiable vs non fiable ; allocations par paquet reçu.

## Livrable

1. Écris ton rapport complet dans le fichier indiqué par ta mission, avec ces sections :
   - **Carte des chemins chauds** — ce qui tourne par image / tick / paquet / événement, avec `fichier:ligne`,
     et les ordres de grandeur (quantités au pire cas).
   - **Constats** — un bloc par constat, identifiant `<PRÉFIXE>-NN`, avec : **Titre** ; **Où** (`fichier:ligne`) ;
     **Constat** (extrait de code) ; **Coût** (quand, combien, PROUVÉ/ESTIMÉ) ; **Proposition** (concrète) ;
     **Gain attendu** ; **Risque** (gameplay, équité, visuel, réseau, déterminisme des bancs) ; **Effort** (S/M/L) ;
     **Sévérité** (CRITIQUE / MAJEUR / MINEUR / ANECDOTIQUE) ; **Statut ROADMAP** (NOUVEAU / CONNU-OUVERT /
     DÉJÀ-TRANCHÉ, avec le numéro de ligne de la ROADMAP) ; **Comment le vérifier** (banc existant de `tools/`,
     moniteur `Performance`, drapeau de lancement…).
   - **Ce qui est déjà bien fait** — 3 à 8 points, pour qu'on ne casse pas ce qui marche.
   - **Questions ouvertes** — ce que seule une mesure, ou Adrien, peut trancher.
2. Ta **réponse finale** à l'orchestrateur : le chemin du rapport, puis UNE ligne par constat au format
   `ID | sévérité | fichier:ligne | titre | gain | effort | statut ROADMAP`. Rien d'autre.
