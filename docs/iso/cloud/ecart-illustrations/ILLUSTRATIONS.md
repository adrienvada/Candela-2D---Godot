# L'écart, illustration par illustration

Engendré par `planche.py` depuis `analyse.py` et `mesures.json` — ne pas éditer à la main.

## L'accueil — `ill_accueil.png`

Un mannequin anthracite, pistolet au poing, braque une lampe au cône ambre, dur et plein, sur un poteau de panneaux rouillés dont seul « ARENA » se lit. Béton gris-brun à hachures, portes à grilles, sol jonché de douilles en laiton et de sang. Plan moyen de trois quarts, à hauteur d'homme ; les murs se lisent en demi-teinte bien au-delà du cône.

Scène du jeu : **J1 devant l'enseigne « ARENA »** (`img/jeu_defaut_arena.jpg`, `img/jeu_tous_arena.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Le panneau sur POTEAU (le jeu pose une plaque à plat sur la face) ; les grilles, les portes ; la rouille claire du panneau. | compatible, à condition |
| Le sol | Dalles carrées brun-ocre, douilles et sang laissés par le jeu, gravats au pied des murs (usure). | Pochoirs : « ZONE 1 », « DEATHMATCH » et bandes, peints sombres au sol ; encre : hachures. | Les douilles de décor, par dizaines, qui brillent. | contredit les invariants |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Amical — `ill_amical.png`

Deux mannequins de part et d'autre d'un pilier de béton qui porte « ZONE 4 » peint au pochoir blanc, chacun avec sa lampe ambre ; poussière et étincelles dans les cônes. Tuyaux et boîtiers électriques aux murs, machine à droite, gravats, douilles, sang. Les deux joueurs se voient de profil.

Scène du jeu : **J1 devant la peinture murale « ZONE 1 »** (`img/jeu_defaut_zone.jpg`, `img/jeu_tous_zone.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. Deux cônes qui se croisent dans l'air. — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Le « ZONE 4 » BLANC du dessin (le jeu le peint sombre : un blanc serait plus clair que le béton qui le porte) ; les boîtiers électriques ; le pilier isolé. | compatible, à condition |
| Le sol | Dalles carrées brun-ocre, douilles et sang laissés par le jeu, gravats au pied des murs (usure). | Pochoirs : « ZONE 1 », « DEATHMATCH » et bandes, peints sombres au sol ; encre : hachures. | Les gravats épars (hors du pied des murs), la machine. | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Amical en ligne — `ill_amical_ligne.png`

Une salle de serveurs : baies noires semées de LED cyan, câbles en guirlandes au plafond, long couloir en perspective. Un mannequin rouillé braque une lampe jaune pâle ; une tache de lumière au sol ; traînée de sang. Ambiance froide bleu-gris.

Scène du jeu : **J1 devant la face la plus meublée de tuyaux** (`img/jeu_defaut_mur.jpg`, `img/jeu_tous_mur.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Les petites lumières | Les filets LED dorés au pied des murs, allumés partout. | Rien. | Des LED cyan par centaines sur des baies : autant de sources, qui éclaireraient les joueurs proches. | compatible, à condition |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Les baies de serveurs (un décor entier, pas une texture) ; les câbles en guirlande au PLAFOND — le jeu n'a pas de plafond. | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Amical local — `ill_amical_local.png`

Un mur d'écrans cathodiques verts qui éclairent une table d'armes ; un mannequin bleu rouillé de face à droite. Toute la lumière est verte et vient des écrans.

Aucune scène du jeu ne l'approche : Une salle de moniteurs à tubes verts (images de couloirs, « 22:15:38 SEC C »), une table en bois avec pistolets et chargeurs : c'est l'armurerie d'avant-match, un décor de menu. Aucune carte n'a de moniteurs ni de table, aucune scène ne s'en approche.

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| Ce qu'il faudrait | — | — | Un décor d'intérieur (écrans, table, armes posées) et une lumière verte fixe. | compatible, à condition |

## Compétitif — `ill_competitif.png`

Un tableau électrique ouvert (« MAIN FEED ») éclairé de cyan, un couloir qui s'enfonce dans le rouge, des impacts de balles plein les murs, un mannequin qui avance lampe blanche au poing, un rond de lumière au sol, des douilles partout. Rouge et sarcelle.

Scène du jeu : **trois tirs dans un mur, étincelles en l'air** (`img/jeu_defaut_impacts.jpg`, `img/jeu_tous_impacts.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. Le rond de lumière au bout du cône, net. — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Couleurs d'ambiance | Une seule famille de couleur : ocre, dorée par les LED. | Rien. | Le rouge du fond de couloir et le cyan du tableau : deux lumières colorées fixes. | compatible, à condition |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Le tableau électrique ; les impacts par dizaines (le jeu montre les 48 derniers, au défaut, là où l'on a tiré — c'est de l'information, pas du décor). | compatible |
| Le sol | Dalles carrées brun-ocre, douilles et sang laissés par le jeu, gravats au pied des murs (usure). | Pochoirs : « ZONE 1 », « DEATHMATCH » et bandes, peints sombres au sol ; encre : hachures. | Les douilles en nappe, préalables à tout tir. | contredit les invariants |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Créer en ligne — `ill_creer_ligne.png`

Un mannequin accroupi tient une fusée au cœur blanc et à la flamme rouge ; un halo rouge sang, une énorme fumée rouge et noire qui roule sous un plafond de câbles et de tuyaux ; sol de douilles.

Scène du jeu : **une fusée, 1,5 s après le lancer** (`img/jeu_defaut_fusee1.jpg`, `img/jeu_tous_fusee1.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière de la fusée | Un grand disque de lumière rouge-orangé (1,5 s), puis orange-jaune (4 s) ; le point de braise presque blanc (Q34 = C, au défaut). | Rouge long : le rouge tient jusqu'à 4 s ; rouge « sang » : la teinte passe de l'orange au rouge (350-5°) — mais à luminance égale il vire au ROSE (voir la loupe à 4 s). | Le rouge SOMBRE et saturé (le 1 % le plus clair de l'illustration : 242, 175, 174 ; sa moyenne éclairée : 86, 41, 44). | contredit les invariants |
| La fumée | Une fumée claire et translucide, couleur de la lumière. | Rien de plus. | La fumée épaisse, SOMBRE, en rouleaux, qui cache le plafond. | compatible, à condition |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Les câbles et tuyaux au plafond : le jeu n'a pas de plafond (les tuyaux de l'essai sont sur les faces). | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. La pose accroupie, la fusée tenue à la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Créer en local — `ill_creer_local.png`

Un pilier fissuré, ocre, entre deux mannequins ; au sol, un marquage peint « ZONE 4 » et « DEATHMATCH » dans des bandes blanches, des chaînes, des douilles ; mezzanine à garde-corps, graffitis, machine. Toute l'image baigne dans un jaune d'ocre chaud.

Scène du jeu : **J1 devant le pochoir au sol « ZONE 1 »** (`img/jeu_defaut_sol.jpg`, `img/jeu_tous_sol.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Le sol | Dalles carrées brun-ocre, douilles et sang laissés par le jeu, gravats au pied des murs (usure). | Pochoirs : « ZONE 1 », « DEATHMATCH » et bandes, peints sombres au sol ; encre : hachures. | Les bandes et les lettres BLANCHES (le jeu les peint en noir à 45 % : un blanc serait plus clair que le sol) ; les chaînes. | compatible, à condition |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | La mezzanine, le garde-corps, les graffitis clairs sur béton sombre. | compatible, à condition |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Écran scindé — `ill_ecran_scinde.png`

Un diptyque : à gauche, lumière AMBRE (J1), à droite lumière BLEUE (J2), de part et d'autre d'un mur ; poutres, plafond de planches, poussière dans les cônes, ronds de lumière au sol ; mannequins rouillés.

Scène du jeu : **l'écran scindé, de part et d'autre du mur haut** (`img/jeu_defaut_scinde.jpg`, `img/jeu_tous_scinde.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. Une couleur de torche par joueur (ambre / bleu). — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Équité des couleurs | Même torche pour les deux ; J2 vu depuis le côté opposé (lacet B). | Rien. | Deux torches de couleurs différentes. | compatible, à condition |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Poutres et plafond : le jeu vu de haut n'en a pas. | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Entraînement — `ill_entrainement.png`

Un stand de tir : une suspension au plafond jette un cône de lumière sur une cible en carton criblée ; un mannequin tire ; un tapis de douilles couvre tout le sol ; piliers de béton, silhouettes de cibles au fond du couloir.

Scène du jeu : **l'entraînement, la cible** (`img/jeu_defaut_entrainement.jpg`, `img/jeu_tous_entrainement.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière | Seule la torche du joueur ; la cible dans le noir. | Cœur chaud à la lampe. | Une lampe FIXE au plafond au-dessus de la cible. | compatible |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Le sol | Dalles carrées brun-ocre, douilles et sang laissés par le jeu, gravats au pied des murs (usure). | Pochoirs : « ZONE 1 », « DEATHMATCH » et bandes, peints sombres au sol ; encre : hachures. | Le tapis de douilles (ici légitime : c'est l'entraînement, personne n'en tire d'information). | compatible |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Les cibles-silhouettes en carton, les piliers. | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. La pose de tir, bras tendus. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Intro — l'allumage — `ill_intro_allumage.png`

Le plus proche du jeu : un noir total, un mannequin rouillé, un cône ambre plein de poussière et d'étincelles qui frappe un mur de béton pâle criblé d'impacts, du sang qui coule, des douilles. Hors du cône, rien.

Scène du jeu : **trois tirs dans un mur, étincelles en l'air** (`img/jeu_defaut_impacts.jpg`, `img/jeu_tous_impacts.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. Le cône plein de poussière, jusqu'au mur. — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Le noir hors de la lumière | Noir, sauf les filets LED. | Rien. | Rien : l'illustration EST le noir absolu. | compatible |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Le béton PÂLE sous la lampe (le jeu : beige moyen) ; les impacts groupés à hauteur d'homme ; le sang qui coule sur la face. | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Intro — la descente — `ill_intro_descente.png`

Un mannequin de dos, sac à l'épaule, descend un escalier sous une ampoule nue qui pend à son fil ; murs lépreux ocre.

Aucune scène du jeu ne l'approche : Un escalier : le jeu est plan, sans niveaux ni marches.

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| Ce qu'il faudrait | — | — | Des niveaux, une ampoule fixe. | compatible, à condition |

## Intro — la dotation — `ill_intro_dotation.png`

Une table, un pistolet dans un rond de lumière tombée du plafond, la main cubique d'un mannequin qui saisit la lampe.

Aucune scène du jeu ne l'approche : Un gros plan d'objets sur une table (pistolet dans un rond de lumière, main qui prend la lampe) : un plan de cinéma, que la caméra du jeu ne fait pas.

## Intro — l'extinction — `ill_intro_extinction.png`

Le noir presque total (93 % de l'image sous 7,5/255) : une main de mannequin au bord d'une table, une braise rouge qui meurt, un filet de fumée.

Scène du jeu : **le duel, torches éteintes** (`img/jeu_defaut_noir.jpg`, `img/jeu_tous_noir.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| Le noir | Torches éteintes : 45 % de l'image reste éclairée par les filets LED des murs. | Rien : aucun essai n'allume le noir (1 pixel, au bruit près). | L'illustration est PLUS noire que le jeu : sans les LED, il ne resterait que la braise. | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. La main et son liseré, seuls visibles près de la braise. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Intro — le prix — `ill_intro_prix.png`

Un couloir voûté ; un mannequin de dos braque sa lampe ambre, qui découpe au fond un autre mannequin en SILHOUETTE NOIRE sur un mur pâle ; l'ombre géante du premier sur le mur de gauche ; gravats, sang.

Scène du jeu : **le duel — J1 face au mur haut, J2 dans son cône** (`img/jeu_defaut_duel.jpg`, `img/jeu_tous_duel.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière et sa couleur | Un cône de torche court, bord net, crème-ocre : le 1 % le plus clair de l'image vaut (172, 144, 99). | Cœur chaud : une perle blanche à la lampe (≈ 13 px), plus claire que ce qu'elle couvre — c'est son rôle. | Une lumière plus claire et plus pâle dans le cône (le 1 % le plus clair des illustrations : 220-255, crème) ; le faisceau visible dans l'air, avec sa poussière. — plus clair DANS le cône : compatible (rien ne sort de la lumière). Le rayon dans l'air : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir) — il contredit tant que sa cause n'est pas levée. | compatible, à condition |
| Le contre-jour | J2 dans le cône est ÉCLAIRÉ, gris, de face. | Mannequin : côté de la lumière. | La silhouette noire sur fond clair : l'adversaire DEVANT un mur éclairé. | compatible |
| Les ombres portées des corps | Les corps ne portent pas d'ombre sur les murs. | Rien. | La grande ombre du joueur sur le mur, portée par une lumière derrière lui. | contredit les invariants |
| Le noir hors de la lumière | Hors torche, les filets LED des murs éclairent faiblement le sol autour d'eux ; le reste est noir (médiane de l'image : 0). La moitié de l'image est à 0 strict — surtout le vide autour de la carte. | Rien ne change : aucun essai n'allume un pixel noir (au bruit près ; voir les mesures). | Les demi-teintes partout : murs et sols lisibles loin de toute lumière (médiane des illustrations 16-51, 9e décile 85-230, contre 0 et 28 au jeu). | contredit les invariants |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Intro — le seuil — `ill_intro_seuil.png`

Une porte d'acier rivetée, rouillée, entrouverte sur une lumière orange plate ; au-dessus, la plaque « ARENA » ; un mannequin la pousse, lampe à la main ; pierre ocre à hachures ; ombre longue au sol.

Scène du jeu : **J1 devant l'enseigne « ARENA »** (`img/jeu_defaut_arena.jpg`, `img/jeu_tous_arena.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière | Seule la torche. | Rien. | La lumière qui vient d'une autre pièce, par une porte. | compatible, à condition |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | La porte d'acier ; la plaque ARENA claire et grande (le jeu : petite, sombre, sur la face). | compatible, à condition |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Le geste (pousser une porte). Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Mise à jour — `ill_mise_a_jour.png`

Un mannequin de dos, en contre-jour, devant une porte de coffre ronde entrouverte d'où jaillissent des rayons dorés ; chaînes, douilles.

Aucune scène du jeu ne l'approche : Une porte de coffre-fort ronde « VAULT 07 » qui s'ouvre sur des rayons dorés : une métaphore de menu (le jeu se met à jour), sans rien du duel.

## Quitter — `ill_quitter.png`

Un couloir vide, une lampe torche couchée au sol, allumée, une flaque de sang, des douilles ; une porte rivetée au fond ; ambre et reflets bleus.

Aucune scène du jeu ne l'approche : Personne : une lampe abandonnée au sol, allumée, près d'une flaque de sang. Le jeu n'a pas de torche qui reste allumée sans joueur — la plus proche serait la fin de manche, et le photographe ne sait pas la poser au même instant pour les deux lancements.

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| Ce qu'il faudrait | — | — | Une lampe qui reste allumée à terre, sans joueur : une lumière posée (comme la fusée). | compatible, à condition |

## Rejoindre en ligne — `ill_rejoindre_ligne.png`

Un couloir étroit tapissé de faisceaux de câbles noirs et de tuyaux ; au fond, un boîtier bleu irradie ; un mannequin, sac au dos, pistolet au poing, marche vers lui ; douilles au sol.

Scène du jeu : **J1 devant la face la plus meublée de tuyaux** (`img/jeu_defaut_mur.jpg`, `img/jeu_tous_mur.jpg`).

| Thème | Déjà là | Les essais apportent | Manque | Invariants |
|---|---|---|---|---|
| La lumière | La torche, les filets LED dorés. | Rien. | Une source bleue fixe au fond du couloir, qui rayonne. | compatible, à condition |
| Les murs | Des blocs de béton beige, arêtes nettes, usure au défaut (fissures, taches, impacts qui restent) ; filets LED dorés au pied ; dessus noirs. | Encre : hachures dans la pénombre et arêtes épaissies ; tuyaux : conduites et câbles sombres sur les faces ; enseignes : « ARENA » et « ZONE n », plus sombres que le béton. | Les faisceaux de câbles serrés, d'un bout à l'autre du couloir (l'essai en pose quelques-uns). | compatible |
| Personnages | Des voxels à la silhouette de mannequin ; J1 bleu glacier CLAIR sous son propre halo, J2 gris sous la torche. | Mannequin : segments et côté de la lumière ; encre : un contour noir de 1,5 px d'écran ; corps détaillés : accessoires modelés (à 60 px, à peine lisibles). | Le corps SOMBRE (ardoise, ~40-60 de luminance) cerné d'un liseré clair du côté de la lumière ; la rouille ; la lampe et l'arme lisibles dans la main. Le sac à dos (les corps détaillés en portent sur certaines classes). Condition : un corps plus sombre est toujours permis ; le liseré clair seulement du côté d'une lumière réelle, jamais dans le noir — et J1 doit rester lisible à ses propres yeux (à décider par Adrien). | compatible, à condition |
| Cadrage | Vue isométrique de haut (tangage 52°, lacet 45°), zoom ×1,5 : un personnage fait ~60 px, 5 à 6 % de la hauteur. | Rien : aucun essai ne touche la caméra. | Le plan à hauteur d'homme, le personnage à 60-80 % de la hauteur, le plafond et la profondeur d'un couloir. | contredit les invariants |

## Rejoindre en local — `ill_rejoindre_local.png`

Le même fichier, octet pour octet, que « Créer en local » (même empreinte md5) : voir plus haut.

Scène du jeu : **J1 devant le pochoir au sol « ZONE 1 »** (`img/jeu_defaut_sol.jpg`, `img/jeu_tous_sol.jpg`).

## Retour — `ill_retour.png`

Une porte de coffre-fort ronde, gonds et volant, entrouverte ; un faisceau doré horizontal ; roche, sol de dalles.

Aucune scène du jeu ne l'approche : La porte du coffre « VAULT 07 / RESTRICTED » en gros plan, un rayon doré : une image de menu.

