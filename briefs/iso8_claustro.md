# ISO8 — la caméra serrée : zoom, cônes plus courts, un duel claustrophobe (brief de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 15/09/2026 12:25, sur mandat d'Adrien de 12:20)

Adrien, 12:20 : « Si tu juges qu'il faut changer les proportions, zoomer dans le jeu, réduire la taille des cônes de lumière pour le rendre plus claustrophobique, n'hésite pas. » La session cloud juge qu'il le faut : sur les 47 captures recadrées d'ISO6, le duel montre toute l'arène (1920×1080 logiques, tuile de 35 px, corps d'une vingtaine de pixels) et le volume de l'iso est invisible ; les planches du DA sont des gros plans environ trois fois plus serrés. Ce chantier serre la caméra et raccourcit les torches, **en gardant l'équité** (les deux joueurs ont la même caméra, la même torche) et **sans toucher à la simulation ni au protocole** (une caméra est une présentation locale ; `Protocol.VERSION` = 18).

## Où

Dans ton worktree (`prompt-iso2-3e1d2e`), branche `iso8-claustro` créée depuis `iso2-vues` à **ee5ac9f** (`git checkout -b iso8-claustro`) ; `iso2-vues` reste à ee5ac9f pour les fusions à venir (balle-sans-lumiere, iso7b-faces), que tu feras sur le mot de la session cloud, avant ou après ce chantier selon ce qui arrive en premier. Aucun fichier commun attendu avec Beauté (shaders) ni Gadgets (bullet.gd) ; si tu touches `player.gd` pour la torche, dis-le dans ton delta.

## Étape 1 — le banc des variantes, avant tout choix

Un banc (`tools/banc_iso.gd`, option `--claustro` ou banc à part) qui prend la même scène — carte d'essai des murs bas (J1 face à la bordure nord à 3,5 tuiles, J2 derrière le muret), puis une vraie carte à murs hauts intérieurs (le Cloître ou la carte livrée la plus bâtie) — en vue unique ET en écran scindé, sous ces variantes : zoom ×1,0 (témoin), ×1,5, ×1,8, ×2,2 ; portée de torche `torch_scale` 1,6 (témoin), 1,2, 1,0 ; ouverture 35° (témoin) et 30° de demi-angle (les cookies sont cuits, `tools/fabrique_cookies.gd` recuit ; un seul jeu de cookies supplémentaire suffit). Une planche `docs/iso/planche_iso8_variantes.jpg` (grille zoom × portée, légendes), envoyée à « ISO Assets Sonnet » pour la galerie, delta à la session cloud **avant tout réglage par défaut** : elle choisit sur image, tu attends son mot (Monitor) ; en attendant, l'étape 2 se prépare.

## Étape 2 — la caméra qui suit, paramétrée

- **Zoom** : un réglage `zoom_duel` (GameSettings, défaut à fixer par la session cloud, sans doute ×1,8), appliqué aux deux vues (`cam1`, `cam2`) et à la caméra iso (l'empreinte au sol de `CameraIso` divisée d'autant ; `vers_sol` et `stick_au_sol` suivent la caméra). Drapeau `--zoom=1.8` et curseur dans les réglages de débogage, pour qu'Adrien compare en direct au test final. La killcam garde son zoom dynamique (0,7-2,8 ; 1,2-2,8 en temps ralenti) : vérifie qu'il part du zoom du duel et non de 1,0.
- **La caméra suit le joueur** avec un décalage vers la visée (un quart de la hauteur visible dans la direction du curseur ou du stick, lissé, plafonné aux limites de la carte) : c'est ce qui rend un zoom serré jouable. Même règle pour les deux joueurs, en scindé comme en vue unique ; en ligne, le client suit son joueur prédit, l'hôte le sien. Aucun état réseau.
- **Bords de carte** : la caméra s'arrête aux bords (limites), sans jamais montrer le hors-carte noir sur plus d'une tuile.
- **Lightmap** : à ×1,8, la lightmap 1080p montre ses texels ; mesure au banc (F3 : taille de lightmap) et dis si la pleine résolution s'impose par défaut avec ce zoom.

## Étape 3 — les torches plus courtes

Selon le choix de la session cloud : `torch_scale` par défaut (sans doute 1,2 : portée 307 px, neuf tuiles au lieu de douze) et demi-angle (35 ou 30°), pour toutes les armes, dans les données de classe (`game_state.gd` construit les armes) ; drapeau `--torche=1.2` et réglage de débogage. Tout ce qui dérive de la portée suit par `portee_torche()` et `demi_angle_torche()` (éblouissement, poussière de faisceau, rétrodiffusion) : vérifie qu'aucune constante ne double la valeur. Les suites d'équité (zone morte, capteurs, noir absolu) restent vertes ; celles qui supposent la portée de 410 px lisent désormais `portee_torche()`.

## Étape 4 — preuve et livraison

Planche `docs/iso/planche_iso8.jpg` (avant ×1,0 / après défaut retenu, vue unique et scindé, carte des murs bas et carte à murs hauts), captures à la galerie, suite `test_iso_camera` étendue (zoom appliqué aux deux vues, décalage de visée borné, limites de carte, killcam qui part du zoom du duel), lot complet vert, ROADMAP (« Décisions actées » : la phrase d'Adrien de 12:20, datée ; état des phases) et journal dans le même commit, français. Delta à « Fable 5.1 - CLOUD ISO UNRAILED » à chaque commit. Puis la planche finale refaite avec ce cadrage (et ISO7b si elle est fusionnée), sur la carte à murs hauts.

Ne touche pas : la simulation, le protocole, les hitbox (18 px), le noir absolu, les corps (ISO Corps et Beauté s'en occupent), la vue de dessus au-delà du zoom partagé. Règles du socle : un lot à la fois (`pgrep -x Godot`, message aux autres avant/après ; le Mac est à Beauté puis Gadgets à 12:12), pas de push, pas de PR, heure de Paris par `date`, Monitor plutôt qu'une fin de tour en attente. Accuse réception à « Fable 5.1 - CLOUD ISO UNRAILED » dès lecture.
