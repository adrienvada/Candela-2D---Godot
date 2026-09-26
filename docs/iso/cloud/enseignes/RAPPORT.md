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
