# ISO14 — le lacet à 45° : le plan, par lecture du code (étape 1, sans code)

Décision d'Adrien, Q14 (2026-09-24, vers 01:19) : « on passe à 45° ce sera plus intéressant ». Ordre de la session cloud :
d'abord ce plan et le banc d'équité, puis le 45° derrière `--lacet=45`, éteint par défaut. **Le défaut ne change qu'après le
banc d'équité et la mesure de cadence.**

Ce plan dit, pour chaque endroit du code qui suppose le lacet 0°, ce qu'il suppose et ce qui change. Il a été établi par
lecture (recensement complet, puis les points décisifs relus un à un) ; rien n'a été lancé.

## Ce qui marche DÉJÀ à tout lacet

La bonne nouvelle d'abord, parce qu'elle borne le chantier. Les calculs qui comptent passent déjà par la base de la caméra :

- `CameraIso.transform_pour` (`camera_iso.gd`) : Euler YXZ (−tangage, lacet, 0) — la caméra tourne autour de la verticale ;
- la souris vers le sol : `CameraIso.vers_sol`, `Presentation3D.point_au_sol` (`local_input_provider.gd`) — une vraie
  intersection rayon-sol ; `vers_ecran`, `projecteur_ecran`, `angle_ecran` (voile, brouillage) ;
- la VISÉE au stick : `CameraIso.stick_au_sol(stick, lacet)` tourne déjà le stick du lacet (l'identité à 0°) ;
- les murs : `mur_iso.gdshader` et `mur_iso_eclaire.gdshader` branchent sur la NORMALE (dessous noir, dessus et liseré,
  faces lues devant elles) — aucune face « sud » en dur ; `iso_geometrie.gd` bâtit des boîtes complètes ;
- les halos (`halo_iso.gdshaderinc`, par `INV_VIEW_MATRIX`), les volumes (plans horizontaux), le voile debout, les
  lumières 3D et le relief (lampes du monde, lues dans la base de la vue) ;
- la zone morte des MURETS (`murs_bas*.gd`, `murs_bas_zone.gdshaderinc`) : une règle de lumière et de balle dans l'espace de
  la lightmap, par `ANGLE_FRANCHISSEMENT` — explicitement « PAS le tangage de la caméra », donc pas le lacet non plus.

Et rien ne passe sur le fil : les commandes restent des vecteurs du monde (`rpc_send_inputs`), `Protocol.VERSION` reste 18.

## Ce qui suppose le lacet 0°, et ce qui change

### 1. La caméra, et la promesse « jamais plus de carte que la vue 2D » — LA QUESTION À TRANCHER

- `camera_iso.gd` : `LACET_DEG := 0.0`, `var lacet_deg`. **Rien dans le jeu n'assigne `lacet_deg`** : les caméras sont créées dans
  `presentation_3d.gd` (deux endroits, vue unique et écran scindé) ; c'est là que la valeur du drapeau se posera.
- L'en-tête de `camera_iso.gd` le dit : la garantie « la vue iso ne montre jamais plus de carte que la caméra 2D » ne vaut qu'à 0°.
  `empreinte_au_sol` donne 1 513 × 1 080 px de monde à 0° ; tournée de 45°, la boîte englobante fait ~1 833 × 1 833 px et
  DÉBORDE la vue 2D de 1 080 px de haut. Le sol lit du noir hors du rectangle de la lightmap (`iso_lightmap.gdshaderinc`), et le
  plan de sol est taillé sur `CameraIso.rect_couvert`, aligné aux axes (`presentation_3d.gd`). **À 45° tel quel : des coins
  d'écran noirs.**
- Deux voies, à chiffrer avant de choisir — **c'est une question pour la session cloud, et sans doute pour Adrien** :
  - **(a) agrandir la lightmap** : la vue 2D qui la rend couvre la boîte tournée — ~1,7 fois plus de hauteur, soit de l'ordre de
    +50 à +70 % de pixels de lightmap à rendre (coût de cadence à mesurer), et la vue 2D montre alors PLUS de carte qu'aujourd'hui
    aux quatre coins (ce qui se voit reste borné par la lumière, pas par le cadre ; à vérifier au banc d'équité, qui le compte) ;
  - **(b) tourner la caméra 2D du lacet** : la lightmap garde sa taille (aucun pixel de plus), son rectangle suit l'écran. Mais
    `presentation_3d.gd` le dit : « les caméras 2D du duel ne tournent jamais » — la lecture de la lightmap (monde → UV) passe par la
    transformation de canevas, à vérifier qu'aucune lecture ne suppose un canevas sans rotation (capteurs des corps, peinture iso,
    `rect_couvert`, voile). Et ce qui est visible change de FORME : un rectangle tourné couvre d'autres cases qu'un rectangle droit.
  **Tranché par la session cloud (2026-09-24, 01:35) : (b), TOURNER la caméra 2D du lacet, n'agrandis pas** — « cinquante à
  soixante-dix pour cent de pixels de plus, sur notre premier poste de coût, pour calculer des coins que l'écran ne montre pas, ce
  n'est pas un bon échange ». **Condition** : un test qui prouve que les capteurs des corps, l'éblouissement et le noir absolu lisent
  les MÊMES valeurs à 0° et à 45° sur un jeu de positions, et la même chose pour les deux joueurs. Ce qui change, dit en clair : la
  lightmap couvre le même rectangle de monde, tourné de 45° ; un objet éloigné dans une diagonale du monde peut entrer ou sortir du
  cadre autrement qu'aujourd'hui — ce qui éclaire ne dépend pas du cadre, seul ce qui est RENDU au bord change. Image à l'étape 2.
- Le décalage vers la visée (`regard_duel.gd`) : `decalage_vise` suit la visée du monde, sans supposer « haut de l'écran = −y »
  (juste). Mais `centre_du_regard` BORNE le centre axe par axe du MONDE contre `vue_px / zoom` : juste seulement quand les axes
  du monde sont ceux de l'écran. À 45° : borner dans les axes de la caméra (tourner, borner, détourner). Et la longueur du
  décalage est prise sur la hauteur d'écran : à 45° elle varie avec la direction de visée (à décider : garder la même longueur
  à l'écran, donc la projeter).

### 2. La visée à la souris — rien à changer

`vers_sol` est une intersection réelle. Le seul repli (`local_input_provider.gd`, inverse du canevas de dessus) ne sert que si la
vue iso ne rend pas ce joueur.

### 3. Le stick — le DÉPLACEMENT n'est jamais tourné

- La visée au stick l'est déjà (`stick_au_sol`). **Le déplacement ne l'est pas** : `LocalInputProvider.get_movement_vector()`
  rend `Input.get_vector(...)` tel quel, lu par `player.gd` (et envoyé sur le fil). À 45°, stick haut ou Z partirait en diagonale à
  l'écran. **Le même `stick_au_sol`** dans `get_movement_vector`, avec le lacet de la caméra QUI REGARDE ce joueur (en écran
  scindé, chacun la sienne). Le clavier comme le stick : haut = haut de l'écran, pour les deux joueurs.
- Rien sur le fil ne change : c'est le fournisseur local qui tourne, la commande reste un vecteur du monde.

### 4. La killcam

`killcam_cadrage.gd` `cible()` : une boîte englobante ALIGNÉE AUX AXES DU MONDE, puis `vue.x / largeur`, `vue.y / hauteur`. À 45° :
tourner les positions du lacet avant la boîte, et tenir compte de l'étirement de la largeur (× 1/sin θ). La caméra 2D de la killcam
(`game_state.gd`) est suivie par `CameraIso` ; rien d'autre n'y dépend du lacet. Sa suite (`test_killcam_calme`) garde le calme.

### 5. Deux faces de mur au lieu d'une — le MODELÉ DES CORPS, pas les murs

- Les murs : rien (voir plus haut). Deux faces se verront, chacune lue devant elle.
- **Les corps** supposent la face sud :
  - `corps_iso.gdshader` et `corps_iso_eclaire.gdshader`, `modele_du_corps` : `n.y > 0,5 → 1,15`, `n.z > 0,5 → 0,9` (« face sud ») ;
  - `iso_materiaux.gd` en miroir : `MODELE_DESSUS 1,15`, `MODELE_FACE_SUD 0,9`, `MODELE_AUTRES 1,0` ;
  - le mannequin d'ISO13 (`iso_corps_mannequin.gdshaderinc`) : les dessus s'assombrissent quand la lumière vient « du sud, vers la
    caméra » ; `MANNEQUIN_REPORT := 1,6` (`voxel_catalogue.gd`) est un rapport d'aires vues qui DÉPEND de la caméra.
  À 45° : la règle se lit sur `dot(n.xz, direction horizontale de la caméra)` — un uniforme de plus (la direction de la vue), la
  même formule à tout lacet ; et `MANNEQUIN_REPORT` se recalcule. Ces deux fichiers sont à ISO7 Beauté : je le lui demande, je
  ne les touche pas.
  - Relevé par Beauté et confirmé par la session cloud (01:49) : **le côté lumière du mannequin** (lot A) suppose une caméra qui ne
    voit que les faces sud ; à 45° elle en voit deux, et la compensation d'équité par les dessus doit suivre l'AXE DE LA CAMÉRA,
    pas +z. Même chose pour son **lot C**, sur deux faces. Poste à part entière de l'étape 2, chez Beauté.

### 6. La bande cachée derrière un mur

- `iso_geometrie.gd` `bande_masquee_px = h / tan θ` : juste à tout lacet.
- **`longueur_cachee` balaie la COLONNE** (`case_sol + (0, k)`, au sud) : juste à 0° seulement. À 45° la bande est diagonale et un
  mur cache derrière deux faces. À réécrire : un point de sol P est caché si, en marchant de P vers la caméra (direction
  horizontale de la vue) sur moins d'une bande, on entre dans une case de mur — échantillonné à l'intérieur des cases (5 × 5
  points par case), pas au seul centre. À 0°, le nouveau calcul doit rendre EXACTEMENT les chiffres d'aujourd'hui (garde).
- `analyser_equite` en dépend (part de sol cachée par moitié de carte, `BANDE_MAX_PX := 18,0`).
- Aucun code de rayons X ou de coupe : un corps derrière un mur est caché par la profondeur 3D seule ; la silhouette de soi et
  l'effacement ne dépendent pas du lacet.

### 7. Photographe, bancs, suites

- `tools/test_iso_camera.gd` affirme `LACET_DEG == 0` et que l'empreinte tient dans la vue 2D à lacet nul : **garde qui reste
  juste** tant que le défaut est 0° ; une garde neuve pour `--lacet=45` (et la voie retenue au point 1).
- `tools/test_iso_killcam.gd` : le stick aux lacets 0/30/90/−45 (déjà général) et l'identité à 0°.
- `tools/test_iso_geometrie.gd` (rayon sud/nord seulement, tableau « lacet 0°, caméra au sud »), `tools/test_iso_vues.gd` (angle du
  voile en formule à 0°), `tools/test_iso_beaute.gd` (valeurs « face sud », faces visibles {haut, +z, ±x}),
  `tools/test_corps_mannequin.gd` (équité nord/sud du modelé) : chacune garde son cas à 0° et reçoit son cas à 45°.
- Les scènes bâties autour de LA face sud : `tools/photographe.gd` (`_face_au_mur_haut`), `tools/banc_iso_beaute.gd`,
  `tools/banc_lumiere3d.gd`, `tools/banc_claustro.gd`, `tools/loupe.gd` — à généraliser en « la face tournée vers la caméra ».
- `tools/banc_iso.gd` a DÉJÀ un `--lacet` et F9 pour ses propres caméras (0 et 45), et `tools/proto_iso.gd` des préréglages de lacet :
  à relire, ils ont peut-être déjà mesuré une partie de ce qui suit.
- `tools/bench_framerate.gd` borne les lumières contre le rectangle de la vue 2D : son coût change si la lightmap grandit (voie a).

### 8. L'équité en ligne

`settings_manager.gd` : `DRAPEAU_ZOOM` et ses frères, filtrés hors build de débogage (`arguments_de_reglage`), et
`valeurs_du_duel(en_ligne, …)` qui rend des CONSTANTES en ligne. `--lacet=` s'y ajoute sur le même patron : un `DRAPEAU_LACET`,
le filtre, le tuple (constant en ligne — le défaut acté, 0° jusqu'au changement), et une affectation à chaque `CameraIso.lacet_deg`.
`game_state.gd` appelle `accorder_au_mode(en_ligne)` à chaque manche ; la garde à étendre est dans `tools/test_iso_camera.gd`.
`conditions_de_match.gd` enregistre `mode_rendu` : il enregistrera aussi le lacet.
⚠️ Constaté en passant, hors périmètre : `mode_iso` / `--2d` n'est PAS forcé égal en ligne (signalé, pas corrigé).

### 9. Le reste qui tient à la direction de vue

Tout ce qui est dessiné en 2D passe par la lightmap et se projette à plat au sol : sang, traces, marques du décor, textes 2D du
monde — ils apparaîtront TOURNÉS de 45° à l'écran, ce qui est juste pour ce qui est au sol. À vérifier : le bandeau FATAL
(`player.gd`, `cadrage_du_bandeau` et sa flèche hors écran travaillent sur un `Rect2` de vue aligné aux axes). Pas de mini-carte.

## LE BANC D'ÉQUITÉ — ce qu'il mesure, et la règle proposée

L'étude demandait « carte par carte » avant tout 45°. Le banc est HEADLESS (aucune fenêtre, aucune cadence) : de la géométrie.

**Ce qu'il mesure**, pour chaque carte livrée (`res://assets/maps/`), au lacet 0° et 45° — et, pour la question du point 1, avec les
deux voies (un même lacet pour les deux joueurs ; ou J2 au lacet + 180°) :
1. **la part de sol cachée par les murs, par moitié de carte** (la moitié de J1, celle de J2 : les cases plus proches de chaque
   apparition, comme `analyser_equite`), par le nouveau `longueur_cachee` échantillonné ;
2. **la part cachée dans un rayon de 6 cases de chaque apparition** (là où la partie commence) ;
3. **la plus grande tache de sol entièrement invisible** (cases connexes), par moitié ;
4. à 0°, les chiffres d'aujourd'hui À L'IDENTIQUE (garde du nouveau calcul) ;
5. pour la voie (b) du point 1 (caméra 2D tournée), la part de carte montrée en plus ou en moins par rapport à 0°, par moitié.

**Pourquoi « J2 au lacet + 180° » est à mesurer** : les cartes livrées sont à symétrie centrale (le commentaire d'`analyser_equite`
le dit). Avec un MÊME lacet pour les deux, les murs ne sont pas orientés pareil dans les deux moitiés — c'est là que l'équité se
joue. Avec J2 à lacet + 180°, chaque joueur voit sa moitié exactement comme l'autre voit la sienne : l'équité tient PAR CONSTRUCTION
sur une carte symétrique, et le banc doit alors rendre des moitiés égales à l'arrondi près. Ce n'est plus « la même valeur pour
tous » au sens littéral, mais la même RÈGLE pour tous ; à la session cloud et à Adrien de dire s'ils la veulent (en écran scindé,
les deux vues côte à côte ne seraient plus orientées pareil).

**LA RÈGLE, FIXÉE PAR LA SESSION CLOUD AVANT TOUT CHIFFRE (2026-09-24, 01:44)** — trois options chiffrées : **A** (même lacet
pour les deux), **B** (J2 à lacet + 180°), **C** (J2 à −45°, l'image de la caméra de J1 dans le miroir gauche-droite). Une option est
**ÉQUITABLE** sur une carte si (0), (a), (b) et (e) tiennent :
- **(0) préalable** (repris de l'étude ISO1) : à 0° comme à 45°, dans chaque option, sur les six cartes, AUCUNE case de sol
  entièrement invisible, et aucune position où un corps (rayon 18 px) soit entièrement caché ; et la longueur cachée maximale, en
  pixels, imprimée. Il remplace mon « ≤ 2 cases d'écart » : deux cases entièrement invisibles font une cachette pour un corps entier ;
- **(a)** l'écart de part cachée entre les deux moitiés ≤ 1 point, et ≤ l'écart à 0° + 0,5 point ;
- **(b)** autour de chaque apparition (6 cases), la part cachée ne dépasse pas celle de l'autre de plus d'1 point ;
- **(e) L'ABRI CACHÉ** — le biais que (a) et (b) ne voient pas : en A à 45°, chaque mur cache son côté éloigné de la caméra ; l'un des
  deux joueurs est loin de la caméra, et ses abris face à l'autre sont cachés quand ceux de l'autre restent visibles — la part
  cachée par moitié peut rester égale. Définition : p est à l'abri de q si le segment [p, q] coupe un mur à moins d'1,5 case de p.
  Pour le joueur i, sur les points p de sa moitié (5 × 5 par case) et les centres q des cases de la moitié adverse, abri_caché_i est
  la part de TOUS les couples (p, q) où p est à l'abri de q ET caché SUR L'ÉCRAN DE L'ADVERSAIRE (sa caméra, selon l'option) — la
  part JOINTE, celle des Décisions actées, sur laquelle le verdict se prend (session cloud, 2026-09-24, 04:47). La part
  conditionnelle — parmi les couples où p est à l'abri, la part où il est caché — est imprimée à côté, en information ; si un
  jour les deux verdicts divergent sur une carte, on le dit à la session cloud. Règle : écart J1/J2 ≤ 1 point.
  ⚠️ Cette phrase disait d'abord « la part des couples « p à l'abri de q » où p est caché » : la lecture conditionnelle, qui
  n'était pas celle des Décisions actées. Relevé au prototype (04:43), corrigé ici ;
  ⚠️ « À 0° en A, les deux valent presque zéro » était une supposition : le banc la DÉMENT sur La Croisée (5,10 / 0,06 à 0°,
  les abris de J1 face à J2 cachés sur l'écran de J2) — voir « Ce que le banc a trouvé » plus bas ;
- **(d) devient une INFORMATION**, pas un critère : la part cachée totale à 45° contre 0° est le prix de l'angle, le même pour les
  deux (un rectangle isolé cache L·(largeur + hauteur)/√2 à 45° contre L·largeur à 0°). Au-dessus de 1,5, l'image va à Adrien.
- La garde (4) : à 0°, le nouveau calcul rend les chiffres d'aujourd'hui.
Adrien choisit parmi les options équitables sur les six cartes ; si aucune ne l'est, la session cloud revient vers lui avec la carte et
l'image. Une carte qui échoue se corrige, pas l'angle.

**Le banc imprime aussi, par carte, LA SYMÉTRIE QUI ÉCHANGE LES APPARITIONS, et si les murs la respectent** : « par construction »
se vérifie, ça ne se déclare pas. Lecture des six JSON par la session cloud, à confirmer par le banc : Arène circulaire, défaut,
Cloître, Bunker — murs symétriques des deux façons, mais apparitions échangées seulement par le MIROIR GAUCHE-DROITE (la rangée
d'apparition n'est pas la rangée centrale) : B y montrera un petit écart dû à la rangée, C y sera exact ; La Croisée — apparitions
(5,5) et (22,22), échangées par la symétrie centrale : B exact, C non ; **L'Usine — 4 cases de mur hors des deux symétries (les deux
blocs de 3 au centre, x de 15 à 17, rangées 9-10 et 15-16, décalés d'une colonne vers J2) : INÉGALE DÈS LA 2D**, avant tout lacet —
signalé, pas corrigé (dessin de carte, hors périmètre). Et `game_state.gd` pose J1 sur `spawn_p1` et J2 sur `spawn_p2` à chaque
manche : un biais de caméra favoriserait le même joueur toute la partie.

À l'étape 2, la planche 0° contre 45° montre aussi la vue de J2 dans chaque option déclarée équitable : Adrien juge la sensation
sur image (« chacun depuis son côté » en B et C, « la même carte pour les deux » en A).

## Ce que le banc a trouvé — PRÉVU par le prototype, à confirmer par le banc GDScript

Chiffres du prototype Python `docs/iso/iso14/proto_equite.py` (qui écrit `reference_prototype.json`, relu par le banc pour
imprimer son écart carte par carte), même algorithme que `tools/banc_equite.gd` (2026-09-24, 04:43 ; aucun Godot
lancé, le Mac étant à Adrien). **Le banc GDScript doit rendre les mêmes** : c'est sa première vérification. Bande 34,2 px,
8 rayons par case, moitiés lues sur l'écran de l'adversaire, (e) joint.

- **(0) passe partout** : aucune case invisible, aucun disque de corps entièrement caché, plus longue portion cachée
  34,2 px. ⚠️ C'est le DISQUE AU SOL de la zone de touche : 18 px de rayon, 36 de diamètre, plus que la bande — il ne
  peut pas tenir entier derrière une face. Le corps EN HAUTEUR (voxel posé, debout et accroupi) est jugé à part par
  `_corps_colle()` (question de la session cloud, 04:47).
- **À 45°, B est équitable sur les six cartes ; A sur aucune ; C sur cinq** (pas La Croisée : moitiés 13,18 / 16,38).
- **À 0°, le jeu d'aujourd'hui (A) N'EST PAS équitable sur deux cartes** — constat qui ne doit rien au lacet :
  La Croisée (moitiés 7,37 / 11,98, apparitions 7,51 / 18,78, abri caché 5,10 / 0,06) et L'Usine (moitiés 9,68 / 10,71,
  écart 1,03 > 1).
- (d), le prix de l'angle (part cachée totale 45° / 0°) : 1,29 à 1,48 selon la carte, sous 1,5 partout.
- Les symétries confirment la lecture de la session cloud : défaut, arène, Cloître, Bunker échangent les apparitions par le
  miroir gauche-droite ; La Croisée par la symétrie centrale ; L'Usine a 4 murs hors des deux.

## La planche (3) — ce qu'elle montrera

Le plan `ecran-scinde-duel` du photographe (ajouté pour ISO14 : les deux vues au même instant, côte à côte, sur la carte
du duel — J1 face à un mur haut intérieur, J2 derrière ; `ecran-scinde` se prend sur la carte de la séance et ignorait
`--carte-duel`, la première chaîne a rendu deux rangées identiques), sur **La Croisée** (diagonale, et C y
échoue) et **Le Cloître** (B et C y passent, et c'est la carte de l'illustration de l'entraînement), à **0°**, **45° B** et
**45° C** — `--carte-duel=…` pour la carte, `-- --lacet=45 --lacet-j2=B|C` pour l'angle. Assemblée par
`docs/iso/iso14/planche_lacet.py` à côté de `assets/ui/ill_entrainement.png`, C marqué « non équitable » sur La Croisée.
En B, J2 voit la carte retournée par rapport à J1 : en écran scindé, les deux moitiés ne sont plus orientées pareil — c'est
ce qu'Adrien jugera sur l'image.

## L'ordre de l'étape 2 (le code, après validation de ce plan)

1. `--lacet=` dans `settings_manager.gd` (débogage seulement, constant en ligne), posé sur `CameraIso.lacet_deg` ; conditions de
   match. 2. Le point 1 selon la voie choisie. 3. Le déplacement tourné (`LocalInputProvider`). 4. `regard_duel` et la killcam dans
   les axes de la caméra. 5. `longueur_cachee` généralisé et le banc d'équité. 6. Le modelé des corps (Beauté). 7. Suites, bancs,
   photographe. 8. La planche 0° contre 45° sur les mêmes scènes, à côté des illustrations. 9. La cadence (Gadgets), selon la
   voie du point 1.
