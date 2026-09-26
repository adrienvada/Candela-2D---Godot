# Les enseignes et panneaux muraux, en essai — rapport de la session cloud « enseignes »

Branche `claude/cloud-enseignes`, depuis `origin/integration-iso14` (`18f5fdc`). Ordre de la session
coordinatrice « Fable 5.1 - CLOUD ISO UNRAILED », 2026-09-27.

> État : **plan posé, travail en cours.** Ce fichier est complété au fil des commits.

## Ce que montrent les illustrations aux murs (relevé AVANT de coder)

Les vingt illustrations de `assets/ui/ill_*.png` (le dossier `assets/ui_illustrations/` de l'ordre n'existe pas :
les illustrations des menus sont dans `assets/ui/`). Ce qui est **porté par un mur** :

| Illustration | Au mur | Matière, couleur |
|---|---|---|
| `ill_accueil` | « ARENA » sur une plaque rectangulaire vissée à un poteau, contre le pilier d'une porte ; deux flèches-plaques illisibles dessous et une au-dessus ; une plaque rouillée vierge au mur de droite | tôle claire écaillée, rouille aux bords, lettres pochoir **noires** |
| `ill_intro_seuil` | « ARENA » sur une grande plaque au-dessus du linteau d'une porte blindée | même tôle rouillée, lettres pochoir noires |
| `ill_mise_a_jour` | « VAULT 07 » peint au pochoir directement sur le béton, en arc au-dessus de la porte de coffre | peinture **sombre** sur béton clair |
| `ill_retour` | « VAULT 07 » et « RESTRICTED » en petites plaques rivetées sur le cadre du coffre | acier sombre, lettres gravées |
| `ill_amical` | « ZONE 4 » peint au pochoir sur un pilier, à hauteur d'homme ; petits boîtiers électriques | peinture **claire** sur béton sombre |
| `ill_competitif` | un tableau électrique (« MAIN FEED », « UNIT 4A ») : un coffret métallique au mur | acier sombre, étiquettes claires |
| `ill_creer_local`, `ill_rejoindre_local` | tags et graffitis aux murs, une petite plaque « … VOLT » ; au sol « ZONE 4 » / « DEATHMATCH » (déjà fait : `--pochoirs-essai`) | traits sombres |
| `ill_intro_descente` | griffures et graffitis sur le béton de l'escalier | traits sombres |
| les autres (`amical_ligne`, `amical_local`, `creer_ligne`, `ecran_scinde`, `entrainement`, `intro_allumage`, `intro_dotation`, `intro_extinction`, `intro_prix`, `quitter`, `rejoindre_ligne`) | pas d'enseigne ni de plaque lisible ; des câbles et des tuyaux (le chantier des tuyaux), des cibles, des portes | — |

Trois familles, donc : **(1) la plaque d'enseigne** vissée (« ARENA »), **(2) le mot peint au pochoir sur le mur**
(« ZONE n », « VAULT 07 »), **(3) la petite plaque ou le coffret** sans texte lisible à l'échelle du jeu. Aucune n'est
une lumière : ce sont des surfaces que la torche révèle.

**Écart assumé avec l'illustration** : l'illustration peint « ZONE 4 » en clair et la plaque « ARENA » en tôle claire.
Au jeu, la règle des pochoirs l'emporte (décidée pour le sol le 2026-09-25) : jamais plus clair que la surface qui porte,
sinon un corps sombre debout devant ressortirait mieux qu'ailleurs. Plaque et peinture seront donc plus **sombres** que
le béton, lettres plus sombres encore ; le contraste plaque/lettre reste, inversé en valeur par rapport au béton.

## Le plan

1. Fusionner les tuyaux (`70ffafa`, `origin/claude/cloud-tuyaux`) : même famille (décor mural 3D qui relit la lumière
   de la face qu'il recouvre), même ancrage dans `presentation_3d.gd`, même shader de base.
2. `enseignes_iso.gd` + `enseignes_iso.gdshader` (nouveaux fichiers) : sur les six cartes livrées, une table écrite à la
   main (comme `ArenaDecor.POCHOIRS_ESSAI`) : « ARENA » en plaque, « ZONE n » peint, quelques plaques muettes ;
   chacune a son jumeau par la symétrie de la carte ; un maillage fusionné par carte, un matériau (+1 appel de dessin).
   Le texte vient d'un atlas de lettres pochoir dessiné en code (déterministe, sans fichier image).
3. Le shader relit la lumière du pixel de face (fonctions de `mur_iso` copiées par les tuyaux) et la multiplie par un
   facteur ≤ 1 : noir hors de la lumière, jamais plus clair que la face.
4. Les lettres ne se lisent jamais à l'envers : l'axe du texte est choisi par la normale de la face (un quad vu de face
   n'est jamais en miroir) ; la garde projette l'axe du texte à l'écran pour chaque caméra qui voit la face (J1 lacet 0,
   J1 45° A, J2 45° B…) et exige qu'il aille de gauche à droite.
5. `tools/test_iso_enseignes.gd`, dans la suite : éteint = rien construit ; allumé = symétrie, bornes (rien au-dessus de
   l'arête, ni collision ni occluder), jamais plus clair (shader), sens de lecture.
6. La planche : éteint / allumé, 1:1 et ×3, à côté de l'illustration, au photographe sous Xvfb.

## Ce qui est construit (état au deuxième commit)

- `enseignes_iso.gd` (nouveau) — la classe `EnseignesIso`, le drapeau `--enseignes-essai` (éteint par défaut).
- `enseignes_iso.gdshader` (nouveau) — la lecture de la face des tuyaux, sans leur modelé.
- `tools/test_iso_enseignes.gd` (nouveau), ajouté à `tools/run_suites.sh` (1 ligne changée).
- `presentation_3d.gd` — **+31 lignes, aucune retirée** : les quatre ancrages des tuyaux, pour les enseignes (le script
  préchargé, trois variables, la construction avec les murs, la peinture posée et retirée, `_materiaux()`).
- Fusionnés pour s'en servir : les tuyaux (`70ffafa`, qui apportent `TuyauxIso.faces`, `hacher`, `tirage`,
  `face_dessinee`, `matiere_max` et le shader de base) et les correctifs du photographe sous Xvfb (`0c67705`, commit à part).

### Appels de dessin et primitives ajoutés

Allumé : **un** `MeshInstance3D` par carte, **une** surface, **un** matériau → **+1 appel de dessin par vue 3D**
(deux en écran scindé), quelle que soit la carte. Primitives : **deux triangles par enseigne**, de 2 (la carte par
défaut) à 8 enseignes (l'Arène circulaire), soit **4 à 16 triangles** et 8 à 32 sommets. Une texture de 256 × 128 RGBA8
avec ses mipmaps (~170 Ko). Éteint : rien — ni nœud, ni matériau, ni texture (prouvé par la garde).

### Les décisions, et leur pourquoi

1. **Un quadrilatère texturé, pas des lettres en volume.** Une plaque de tôle et une peinture sont plates ; un quad collé
   à 0,2-0,3 px de la face ne recouvre à l'écran que sa face (la parallaxe des volumes, qui a coûté aux tuyaux, y est
   de 0,5 px au pire) et coûte deux triangles.
2. **Les lettres dessinées en code (fonte 5 × 7 pochoir), pas une fonte rastérisée.** Headless, rien ne se rastérise :
   un atlas tiré d'une `Font` serait vide sous la suite, et la garde ne pourrait rien lire. Une fonte à cellules se
   dessine au texel près, identique partout, et à l'échelle du jeu (~1 pixel d'écran par cellule) une fonte plus fine ne
   se verrait pas. Les ponts du pochoir (O, A, R) sont dans les glyphes.
3. **Plus sombre que le mur, contrairement à l'illustration.** Tôle × 0,55, bord × 0,40, rivets × 0,25, lettres de plaque
   × 0,14 ; peinture × 0,45 (lettre usée × 0,70). Tous ces facteurs sont en plus plafonnés par la matière la plus sombre
   qu'une face porte. Le contraste lettre/fond de l'illustration reste, inversé en valeur par rapport au béton.
4. **Deux sortes seulement : « ARENA » (plaque) et « ZONE n » (peint, sur deux lignes comme `ill_amical`).** Ce sont
   les deux seules enseignes lisibles de l'illustration qui disent quelque chose du jeu ; « VAULT 07 », « RESTRICTED »,
   « MAIN FEED » nommeraient des lieux qui n'existent pas dans le duel. Une plaque muette rouillée est possible avec
   le même atlas, non faite (pas demandée, et un décor de plus à juger).
5. **Le placement par orbites, calculé, pas une table écrite à la main.** Les pochoirs du sol ont une table ; ici, une
   face exposée n'est retenue que si **toutes** ses images par le groupe de la carte sont aussi des faces exposées. Le
   groupe : la symétrie qui porte le départ de J1 sur celui de J2 (`sigma` : le miroir gauche-droite sur cinq cartes, le
   demi-tour sur la Croisée) et le demi-tour (celui de l'option B, le défaut en ligne, où J2 regarde de l'autre côté).
   Une orbite d'« ARENA » (la plus proche du centre), une de « ZONE n » (la plus proche des départs, chaque face à deux
   cases au moins plus près d'un départ que de l'autre, et à trois cases au moins de tout départ). L'orbite doit porter
   une face SUD — du côté de J1 pour « ZONE » — : J1 la voit à 0° et à 45°, et J2 voit son image (une face nord) à 180°
   et à 225°. Calculé, le placement se prouve pour toute carte, et une carte de joueur en recevrait un correct — mais
   **seules les cartes livrées sont vérifiées**, et c'est un essai : on peut restreindre aux cartes livrées si Adrien le
   veut.
6. **Jamais à l'envers, par construction.** L'axe du texte est `(n.y, −n.x)` : la droite de quiconque regarde la face de
   face. Une caméra qui voit la face de dos ne la dessine pas (le tri des tuyaux) ; donc aucun texte n'est jamais vu en
   miroir, et, le monde n'ayant pas de roulis, jamais la tête en bas. La garde le vérifie à dix lacets, dont 225° (J2 à
   45° B).
7. **Sous le jour des tuyaux.** Une enseigne avance de 0,3 px au plus, un tuyau commence à 0,5 : les deux essais allumés
   ensemble, un tuyau passe DEVANT une plaque, jamais au travers. Ils ne se connaissent pas : un tuyau peut barrer une
   enseigne. À juger si les deux sont gardés.

### Ce que la garde prouve (`tools/test_iso_enseignes.gd`, 168 vérifications)

Drapeau éteint : ni nœud, ni matériau. Allumé : un nœud, calque commun, sans ombre ni enfant, une surface, l'atlas posé,
retiré quand on éteint. Aucune classe de collision, d'occluder ou de lumière dans le script. Atlas : identique deux
fois, chaque texel ≤ 0,70, lettres présentes, peinture transparente hors des lettres, lettre de plaque plus sombre que
la tôle. Par carte : même construction deux fois, empreinte figée ; chaque coin sous l'arête (moins une saillie vue sous
le tangage), au-dessus de la bande de sol, devant sa face à 0,3 px au plus, à 3,5 px au moins de ses bouts (l'encre des
arêtes) ; une enseigne par face ; chaque enseigne a ses jumelles par tout le groupe, « ZONE » échangée par `sigma`,
chaque « ZONE n » du côté de Jn ; pour chaque paire de caméras (A 0°, B 0°, A 45°, B 45°, C 45°) dont les MURS sont
équitables, ce que dessine J2 est l'image exacte de ce que dessine J1 ; à 0° et 45° en option B, chaque joueur a « ARENA »
et sa « ZONE » sous les yeux ; aucun texte à l'envers à dix lacets ; enroulement comme une `BoxMesh`. Shader : lecture
de la face copiée mot pour mot de `mur_iso`, `unshaded`, ni lumière ni émission, `ALBEDO = c` venu de la lumière lue et
de facteurs de la pâte, plafond `matiere_max`, instrument éteint, accordé comme les murs.

**Éprouvée par six mutations** : axe de lecture inversé → 12 échecs ; « ZONE 1 » décalée de 2 px → 7 ; tôle à 1,1 → 1 ;
plafond `matiere_max` retiré du shader → 1 ; saillie à 0,8 px → 7 ; enroulement inversé → 6 ; 0 une fois le code remis.
