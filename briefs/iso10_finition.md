# ISO10 — la finition : très joli, fluide, agréable à regarder, sans pixels voyants (brief de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 15/09/2026 15:31, sur le mot d'Adrien de 15:2x)

Adrien : « Assure-toi vraiment de confronter les images en jeu aux images générées par Gemini, arrête-toi uniquement quand tu as atteint un niveau très joli, fluide et agréable à regarder. Sans pixels voyants. » Ce chantier ne se ferme pas sur un lot vert : il se ferme sur un verdict de la session cloud, pris sur image, loupe par loupe, contre les planches du DA. Il s'ouvre quand la série de loupe d'Iso 1 (ordre 40) est dans la galerie et jugée ; la liste des défauts vient de ce jugement, pas de ce brief. Ce brief pose la méthode et les suspects connus.

## Où

Sur `iso2-vues` (tête 9831cbd ou plus récente), dans un worktree à soi, branche `iso10-finition`. Un lot à la fois sur le Mac (`pgrep -x Godot`, un mot aux autres sessions), heure de Paris par `date`, pas de push, pas de PR, fusion dans iso2-vues sur le mot de la session cloud seulement. Delta à « Fable 5.1 - CLOUD ISO UNRAILED » à chaque commit (hash, lot, planche) et à tout blocage.

## La boucle

1. **Loupe** : le photographe (`tools/photographe.gd`, drapeau de loupe ajouté par l'ordre 40) prend des recadrages 1:1 à la fenêtre native du Mac (2560×1440) au cadrage par défaut ; chaque loupe est posée à côté de la planche du DA qui lui répond dans `docs/iso/planche_loupe.jpg`.
2. **Verdict** de la session cloud, loupe par loupe : ce qui est joli, ce qui a des pixels voyants, ce qui n'est pas à la hauteur de la planche.
3. **Correction par lots** (un défaut ou une famille par commit, lot complet vert, delta), puis **nouvelle série de loupe** sur les mêmes cadrages, et retour au 2. La boucle s'arrête quand la session cloud dit « plus rien à voir ».
4. **Fluidité** : la bande de trente images à 60 Hz (caméra qui glisse, joueur qui marche) doit être régulière, sans saut ni hoquet ; le F3 lit les temps d'image de la séquence. Le relevé de cadence long reste au test final (décision d'Adrien du 15/09 05:13), mais un hoquet visible sur trente images se corrige ici.

## Les suspects connus (à confirmer sur les loupes, pas à corriger d'avance)

- **L'art à 1 texel par unité de monde, grossi 2,4×** dans la fenêtre d'Adrien (×1,8 sur 1440 px) : les sprites de gadgets (`assets/sprites/gadget_*.png`, 28-30 px), la balle, le viseur, les traces (sang, poudre, impacts), le décor cuit en une texture par carte, les bandes d'encre au pied des murs (MurEncre, période 6 px de monde, soit 14 px d'écran). Remèdes possibles : re-dériver les sprites à 3× depuis les planches vertes sources du DA (`assets/sources/gadgets/`, non versionnées, sur le Mac d'Adrien), cuire le décor à 2× (1120 px → 2240 px par côté, une carte de 32×32), dessiner l'encre d'arête en espace écran (largeur en pixels d'écran, pas de monde), filtrage linéaire plutôt que nearest là où le pixel se voit.
- **Les bords d'ombre durs des occluders** (polygones à arêtes nettes, crénelés en diagonale à ce zoom) : filtre d'ombre des Light2D (PCF) ou flou de la lightmap au bord, sans toucher à l'équité (le noir absolu reste noir, une ombre adoucie ne révèle rien de plus qu'une ombre nette à la même distance ; à prouver par la suite de noir absolu).
- **La lightmap 1080p à 0,75 texel par pixel** : douce plutôt que pixelisée (bilinéaire), mais un bord de cône peut marcher ; la pleine résolution par défaut est la question 4 d'Adrien, à mesurer au banc si les loupes le demandent.
- **Les corps voxel** : des boîtes 3D aux arêtes crénelées sans anticrénelage (`gl_compatibility` : MSAA 2D inopérant, mais la vue 3D de la présentation peut porter un MSAA 3D ou un FXAA, à mesurer) ; l'encre de contour ; le modélé dessus / face sud.
- **La chaleur et la matière** (ISO7b) sur TOUS les écrans : le duel, mais aussi la killcam, l'entraînement, les fins ; une face de mur qui redevient froide quelque part est un défaut.
- **Le bandeau LED** : gradient de lumière sur le mur, banding éventuel.
- **Les quatre images du DA à flamme** (ordres 36-39) : posées et vérifiées à l'écran.

## Ce qui ne bouge pas

La simulation, le protocole (VERSION 18), les hitbox (18 px), l'équité (même cadrage et même portée en ligne, ordre 31), le noir absolu (toute correction d'ombre ou de lightmap passe la suite de noir absolu), les décisions actées d'ISO8 (×1,8 ; 0,25 ; ×0,75) et d'ISO7b (aucune direction lue dans le gradient). Une correction qui coûte de la cadence se mesure au banc et se dit dans le delta ; Adrien tranche au test final.

## Livraison

À chaque lot : commit, lot complet vert, `docs/iso/planche_loupe.jpg` refaite (mêmes cadrages, avant / après / planche du DA), captures à la galerie par « ISO Assets Sonnet », ROADMAP (section ISO10 : ce qui a été vu, ce qui a été corrigé, ce qui reste, les pièges) et journal dans le même commit, delta à la session cloud. À la fin : message de fin avec la tête, et la planche finale refaite.
