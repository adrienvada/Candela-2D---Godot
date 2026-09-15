# ISO10 — verdict de la série de loupe (tour 1) et lot 1 de la finition

Session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 15/09/2026 16:19. Verdict pris sur les dix-sept PNG de docs/iso/loupe/ (a2c6cd2, publiés octet pour octet dans la galerie, version 12), regardés à 1:1 puis au centre grossi ×4 au plus proche voisin (200×112 → 800×448), contre les planches du DA qu'Iso 1 leur a associées : face_mur_01, sol_01, frise_1_a_5, E1_promesse_02, E3_flash_pro, fusee_posee_01 + fumee_03, icône gadget_torche_fantome. Mandat d'Adrien (15:2x) : « très joli, fluide et agréable à regarder, sans pixels voyants ». Le « tout est là » attend « plus rien à voir » sur un tour de loupe.

## Ce qui est bon (à ne pas toucher)

- **Le bord du cône** (loupe-bord-cone) et **le bord de l'ombre du pilier** (loupe-ombre) : doux, propres, sans crénelage ni marche. La lightmap à 0,75 texel par pixel ne se voit pas là.
- **Le HUD** (loupe-hud-hud) : net, sans frange, texte et cadres propres ; l'icône voxel du gadget est fine.
- **La face du pilier elle-même** (loupe-pilier) : douce, sans texel visible ; sa matière est plus lisse que le béton de face_mur_01, mais rien n'y est voyant.
- **La fluidité** : la bande de trente images est régulière, aucun saut visible ; temps d'image réels 9,4 à 11,1 ms. Rien à corriger ici.
- **Les trois loupes en scindé** : même dessin, un peu plus doux, et **aucune frange chromatique** — c'est la preuve qui désigne le défaut 1.

## Les défauts, loupe par loupe

1. **Frange chromatique sur tous les bords, en vue unique seulement** (toutes les loupes de la vue unique : corps J1 et J2, pilier, LED, sol, balle, viseur, fusée). À ×4 : rouge d'un côté, cyan de l'autre, environ un pixel de 2560×1440 sur les bords ordinaires, deux sur les arêtes très contrastées (le bandeau LED, l'arête claire du pied du pilier dans loupe-ombre, les chevrons du viseur). Mesuré : le meilleur recalage rouge↔vert vaut +1 px sur toutes les loupes de la vue unique et 0 sur les trois loupes en scindé ; le HUD n'en a pas. C'est donc une passe en espace écran de la vue racine (rendu racine du chantier R), sous le HUD, active au repos. Suspects : `voile_eblouissement` (DA5.5 : aberration = 0,015 × niveau, qui ne doit vivre que pendant un éblouissement réel — vérifier que `niveau` vaut bien 0 au repos en vue unique, et que le voile n'est pas en mode 1 sur une copie plein cadre), une passe de finition posée sur la vue racine à ISO7 (pâte, liseré), ou `menu_veil` resté sur le jeu. Méthode : refaire loupe-led et loupe-corps-j1 en coupant les passes une à une ; la bonne est celle dont la coupure ramène le recalage à 0. **Au repos, la frange vaut 0** ; elle ne revient que sur ses deux grands moments (éblouissement, mort), comme DA5.5 l'écrit.

2. **L'encre des murs : la bande de hachures au pied** (loupe-pilier, loupe-ombre, loupe-led, loupe-hud-viseur). Tirets noirs diagonaux à période fixe, durs, crénelés, grossis 2,4×, avec la frange par-dessus : c'est la première source de « pixels voyants » sur les murs. **Le DA n'a pas ces hachures** : face_mur_01 est un béton beige à larges coups de pinceau d'encre diluée, bords diffus, coulures, points épars. Remède : remplacer la bande de tirets par un lavis doux au pied du mur (assombrissement lisse, bord diffus, largeur en pixels d'écran) ou par des coups de pinceau larges ; plus aucun trait à un texel de monde. Si un trait d'encre reste, il se dessine en espace écran avec une transition d'un pixel (fwidth / smoothstep).

3. **L'encre du sol : les gribouillis** (loupe-sol, loupe-balle-impact, loupe-corps-j2, loupe-bord-cone). Craquelures dessinées en traits noirs de deux pixels, très contrastés, trois à six par dalle ; à ×4 ce sont des blocs noirs à frange. sol_01 montre des fissures en cheveu, des taches de lavis douces et des points. Remède : traits plus fins et moins noirs (gris moyen, opacité partielle), moins nombreux, lavis doux ; même règle de transition d'un pixel d'écran. Les dalles, les joints et le ton d'ensemble sont bons.

4. **Les marques au sol : sang et impacts** (loupe-hud-viseur, loupe-bord-cone). La tache de sang est un blob rouge-noir à bords en escalier, grossi 2,4× ; l'impact est presque invisible (limite connue du cadrage). Remède : bord adouci sur un pixel d'écran (smoothstep dans le shader de sang) ou texture de marque à 2× ; l'impact, on le rejuge au tour 2 sur un cadrage qui le met au centre.

5. **Les corps** (loupe-corps-j1, loupe-corps-j2, et en scindé). Boîtes plates aux arêtes dures et crénelées, sans ombre de contact au pied ; la frise_1_a_5 montre des mannequins de plâtre aux arêtes nettes mais lisses, une face éclairée et une face dans l'ombre, une ombre de contact douce. Dans ce lot : l'anticrénelage des arêtes (MSAA 3D ou FXAA sur la vue 3D des corps si `gl_compatibility` le permet, mesuré au banc ; sinon un bord adouci d'un pixel dans le shader du corps) et une ombre de contact douce sous chaque corps. **Pas dans ce lot** : la lumière directionnelle sur les faces — c'est la proposition (A) de Beauté (lightmap de direction), décidée pour après le test ; le modelé dessus / face sud (1,15 / 0,9) reste. Vérifier la couleur des corps contre planche_palette_corps (bleu-gris et gris sombre sur les loupes, plâtre clair sur la frise) et dire ce que la planche impose.

6. **La fusée et sa suie** (loupe-fusee-suie). La loupe la plus loin de ses planches : halo rose-saumon qui couvre toute la loupe, nappes à lobes durs, anneaux concentriques (banding en moiré) sur le halo, texels de fumée en blocs d'environ quatre pixels, frange par-dessus. fusee_posee_01 : un petit halo chaud autour d'une flamme, des cubes de fumée nets ; fumee_03 : une fumée ambre, douce, aux bords plumeux, sur noir. Remède : couleur vers l'ambre de fumee_03 (la neutralité du halo dans la pâte, corrigée par Beauté en (a), ne bouge pas : c'est la teinte des nappes et de la fumée qui change), bords plumeux (transition large), bruit de la fumée évalué à la résolution de l'écran et non dans une texture basse, anneaux supprimés (gradient en flottant ou grain léger qui les dissout). **Le rayon de lumière de la fusée ne bouge pas** : c'est une information de jeu ; seul le dessin des nappes et de la fumée change.

7. **La torche fantôme** (loupe-torche-fantome). Un sprite bleu-gris d'une quinzaine de pixels, un point clair, et un trait sépia fin et faible pour tout cône ; le sol autour reste noir. À côté d'un cône de joueur (loupe-sol, loupe-bord-cone), elle ne trompe personne. À vérifier contre sa spécification dans la ROADMAP (chantier Gadgets) : si c'est un leurre, il lui faut le cône d'une torche de joueur (même cookie, même portée ×0,75, même chaleur) ; si elle est voulue plus faible, le dire dans le delta et on tranche. Le sprite (28-30 px source, grossi 2,4×) reste lisible ; à re-dériver à 3× depuis la planche verte si le tour 2 le montre brouillé.

8. **Le trait de balle** (loupe-balle-vol). Les tirets clairs du trait sont nets et acceptables ; les paires de points noirs qui le longent sont crénelées — dire ce qu'elles sont (ombre ? particules ?) et les adoucir ou les retirer ; le joint de dalle vertical porte une ligne rouge qui vient du défaut 1.

Note, hors lot : la chaleur d'ISO7 (sépia) est plus chaude que le béton beige-gris des planches ; ce n'est pas un pixel voyant et la décision ISO7b tient. À garder pour la planche finale, pas pour ce lot.

## Le lot 1, par familles (un commit par famille, lot complet vert, delta à chaque commit)

- **1a — la frange à 0 au repos** (défaut 1). D'abord, parce qu'il touche tous les bords et que les autres loupes se jugent après lui.
- **1b — l'encre** : murs (défaut 2), sol (défaut 3), marques (défaut 4), points du trait de balle (défaut 8). Une règle : toute marque d'encre se dessine avec une transition d'un pixel d'écran, jamais à un texel de monde grossi.
- **1c — la fusée** (défaut 6).
- **1d — les corps** (défaut 5) : anticrénelage et ombre de contact, mesure de cadence au banc si MSAA 3D ou FXAA.
- **1e — la torche fantôme** (défaut 7) : vérification de la spécification, puis correction ou question.

## Le tour 2 de loupe

Mêmes dix-sept cadrages (`./tools/run_photos.sh --famille=loupe --taille=2560x1440`), plus un cadrage qui met l'impact au centre. `docs/iso/planche_loupe.jpg` prend une **troisième colonne : le centre de chaque loupe (200×112) grossi ×4 au plus proche voisin**, pour qu'Adrien voie ce que je vois. Les PNG vont à la galerie octet pour octet par « ISO Assets Sonnet » (section « Loupe, tour 2 »), delta à la session cloud avec le hash. Je rejuge alors loupe par loupe ; « plus rien à voir » ou tour 3.

## Ce qui ne bouge pas

La simulation, le protocole (VERSION 18), les hitbox (18 px), l'équité (ordre 31 : ×1,8 ; 0,25 ; ×0,75 en ligne), le noir absolu (toute correction passe sa suite), les rayons de lumière (torche, fusée, LED), les décisions actées ISO7b (aucune direction lue dans le gradient) et ISO8. Une correction qui coûte de la cadence se mesure au banc et se dit dans le delta ; le relevé long reste au test final.
