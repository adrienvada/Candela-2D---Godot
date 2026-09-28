# Les murs meublés, en essai — rapport de la session cloud « murs meublés »

Branche `claude/cloud-murs-meubles`, depuis `origin/claude/cloud-ecart-illustrations` (`f4039a0`). Ordre de la session
coordinatrice « Fable 5.1 - CLOUD ISO UNRAILED », 2026-09-28. Le manque n° 4 de l'évaluation de l'écart aux
illustrations (`docs/iso/cloud/ecart-illustrations/RAPPORT.md`).

> État : **en cours** — relevé fait, plan posé, code à venir.

## Ce que les illustrations posent aux murs (relevé AVANT de coder)

Relevé à l'œil sur les vingt illustrations de `assets/ui/ill_*.png`. Les tailles sont rapportées au mannequin (≈ 1,8 m) ;
la matière et la couleur sont celles du dessin, pas celles qu'aura le jeu (voir « écart assumé »). Les tuyaux, les
câbles pendants et les enseignes sont déjà des essais (`--tuyaux-essai`, `--enseignes-essai`) : ils ne sont notés ici que
pour mémoire.

| Illustration | Posé aux murs | Famille | Taille | Matière, couleur | Densité |
|---|---|---|---|---|---|
| `ill_accueil` | deux **portes à grilles** (barreaux verticaux) de part et d'autre du poteau ; une plaque rouillée vierge au mur droit ; une descente de tuyau | porte, (grille) | porte : ~1 × 2,2 m, jusqu'au linteau | acier sombre à barreaux, cadre de fer, rouille | 2 portes pour ~6 m de mur |
| `ill_amical` | trois **petits boîtiers** électriques (un à chaque pilier, un sur le mur droit), un interrupteur, conduites horizontales cerclées, descentes ; une porte au fond à gauche (cadre) | boîtier, porte | boîtier : ~0,3 × 0,4 m à hauteur d'épaule ; porte ~1 × 2 m | tôle grise, un fil qui en descend | 1 boîtier par pilier / tous les ~3 m |
| `ill_amical_ligne` | des baies de serveurs **sur toute la hauteur** des deux murs, façades à grilles et LED cyan ; câbles en guirlandes au plafond | grille (façade), câbles | baie : ~0,6 × 2 m, jointives | acier noir, fentes d'aération, LED | le mur entier |
| `ill_competitif` | un grand **tableau électrique** à deux portes (disjoncteurs, « MAIN FEED », « UNIT 4A »), des câbles qui en sortent par le bas, deux conduites horizontales | boîtier (grand) | ~1 × 1,2 m, centre à hauteur de poitrine | acier gris-bleu, rivets, étiquettes | 1 pour ~4 m de couloir |
| `ill_creer_ligne` | un **plafond de faisceaux de câbles** serrés tenus par des colliers, des conduites rouges ; mur nu | câbles (faisceau) | faisceau de ~10 câbles, ~0,3 m d'épaisseur | caoutchouc noir, colliers de fer | tout le plafond |
| `ill_creer_local` (= `ill_rejoindre_local`, même fichier) | graffitis, une petite plaque « … VOLT », des **boîtiers** sur la mezzanine, câbles pendants au fond | boîtier | ~0,3 × 0,4 m | tôle sombre | épars |
| `ill_ecran_scinde` | piliers et poutres nus, une fissure ; presque rien | — | — | — | nu |
| `ill_entrainement` | **câbles** courant en travers du mur du fond et le long du pilier, un **interrupteur** (petit boîtier) sur le pilier, une lampe au plafond | câbles, boîtier | boîtier ~0,15 × 0,2 m ; câbles isolés, 3-4 en nappe lâche | caoutchouc noir, tôle claire | 1 boîtier, 1 nappe |
| `ill_intro_seuil` | une **porte d'acier rivetée** à panneaux (trois rangées de rivets horizontales, deux verticales, charnières), dans un chambranle riveté ; « ARENA » au-dessus | porte | ~1 × 2,2 m, jusqu'au linteau | acier rouillé brun-orangé, rivets sombres | 1 |
| `ill_quitter` | au bout du couloir, une **porte rivetée** à deux battants avec une serrure-boîtier ; à droite un petit **boîtier** (interrupteur à clé) | porte, boîtier | porte ~1,2 × 2,2 m ; boîtier ~0,15 × 0,25 m | acier bleu-gris rouillé | 1 + 1 |
| `ill_rejoindre_ligne` | des **faisceaux de câbles serrés** (8 à 12 câbles) le long des deux murs, sur trois hauteurs, tenus par des **colliers-étriers** verticaux tous les ~1,5 m, qui fléchissent entre deux ; une descente de tuyau ; au fond un **boîtier** bleu | câbles (faisceau), boîtier | faisceau ~0,25-0,4 m d'épaisseur ; boîtier ~0,3 × 0,5 m | caoutchouc noir luisant, étriers de fer ; boîtier gris | les deux murs entiers |
| les autres (`amical_local`, `intro_allumage`, `intro_descente`, `intro_dotation`, `intro_extinction`, `intro_prix`, `mise_a_jour`, `retour`) | écrans, béton nu criblé, escalier, portes de coffre (métaphores de menu) : pas de mobilier mural qui manque au duel | — | — | — | — |

Onze illustrations, quatre familles :

1. **La porte rivetée** (accueil, amical, intro_seuil, quitter) : une plaque d'acier plate d'une case de large et des deux
   tiers de la hauteur du mur, un chambranle, des bandes rivetées, de la rouille ; certaines à barreaux.
2. **Le boîtier électrique** (amical, competitif, creer_local, entrainement, quitter, rejoindre_ligne) : une boîte de tôle
   qui avance de la face, petite (interrupteur, coffret) ou grande (tableau à deux portes), souvent avec un câble ou une
   conduite qui en descend.
3. **La grille d'aération** (accueil, amical_ligne) : une plaque plate à fentes horizontales ou à barreaux, dans un cadre.
4. **Le faisceau de câbles serrés** (creer_ligne, entrainement, rejoindre_ligne) : huit à douze câbles jointifs, en nappe
   horizontale le long d'un mur, tenus par des étriers verticaux, qui fléchissent un peu entre deux. Différent des câbles
   de `--tuyaux-essai` (un à trois câbles lâches, en guirlande sous l'arête).

**Écart assumé avec les illustrations** : elles les peignent en tôle claire, rouille orange, caoutchouc luisant ; au jeu,
la règle des pochoirs l'emporte — tout sera **plus sombre que la face qui le porte**, et noir hors de la lumière. La LED
cyan des baies et le boîtier bleu qui irradie de `ill_rejoindre_ligne` sont des lumières : **exclus** (le noir absolu).

## Le plan

1. `murs_meubles_iso.gd` (nouveau) : le drapeau `--murs-meubles-essai` (éteint par défaut), une **table écrite à la
   main** par carte livrée (comme `ArenaDecor.POCHOIRS_ESSAI`) : pour chaque objet, sa famille, sa face (case et normale),
   sa place le long d'elle et sa hauteur. La table ne porte qu'un représentant par orbite ; ses jumeaux sont ses images
   par le groupe de la carte (`EnseignesIso.groupe` : la symétrie qui échange les départs et le demi-tour de l'option B),
   et la garde exige que chacun tombe sur une face exposée.
2. Quatre familles, **un maillage fusionné par carte et par famille, un matériau par famille** : +1 appel de dessin par
   vue et par famille au plus (+4 en tout, +8 en écran scindé).
   - portes et grilles : des quadrilatères plats à 0,2-0,3 px de la face, texturés par un atlas dessiné en code, lus par
     le shader des enseignes (`enseignes_iso.gdshader`, réutilisé tel quel) ;
   - boîtiers et faisceaux : des volumes (boîtes, tubes, étriers), lus par le shader des tuyaux
     (`tuyaux_iso.gdshader`, réutilisé tel quel), qui relit la lumière du pixel de face recouvert à l'écran.
   Les deux shaders ne font que multiplier la lumière de la face par un facteur ≤ `matiere_max` : noir hors de la
   lumière, jamais plus clair que la face, par construction et prouvé par leurs gardes. Aucun nouveau shader à prouver.
3. Rien au-dessus de l'arête, rien sur la bande de sol, rien près des bouts de la face ; ni collision, ni occluder, ni
   ombre ; rien sur une face qui porte une enseigne.
4. `tools/test_iso_murs_meubles.gd`, dans la suite : éteint = rien construit ; allumé = symétrie par le groupe, bornes,
   atlas ≤ 1, aucune classe de collision/occluder/lumière.
5. Les preuves en images au photographe sous Xvfb : noir absolu (torches éteintes, A, B, A'), jamais plus clair que la
   face au pixel (avec contre sans, au même instant), symétrie J1/J2 à 45° B, comptes de dessin avec l'outil de la
   session « Budget ».
6. La planche : par famille, l'illustration, le jeu sans, le jeu avec, 1:1 et ×3 ; une vue d'ensemble tous essais allumés.
