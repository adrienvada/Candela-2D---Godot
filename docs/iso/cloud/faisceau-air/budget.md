## Tableau par configuration

Six cartes livrées : médiane des six (min–max) ; chaque carte vaut la médiane de ses 12 images. Pompe sous une fusée (Arène Standard) : la moyenne de ses 120 images.

### Vue unique, lacet 0°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| defaut | 6 cartes | 134.5 (88–151) | 6330 (5280–6716) | 958.5 (710–1110) | 4 | 2 | 6 | 0 | 385.7 (381.3–389.7) |
| air | 6 cartes | 142 (96–161) | 6347 (5298–6736) | 968 (719–1118) | 4 | 2 | 6 | 0 | 385.7 (381.3–389.7) |

### Vue unique, lacet 45°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| defaut | 6 cartes | 136 (91–151) | 6211 (5308–6736) | 896.5 (714–1113) | 4 | 2 | 6 | 0 | 387.7 (383.3–391.7) |
| air | 6 cartes | 145.5 (99–161) | 6227 (5328–6756) | 906 (724–1121) | 4 | 2 | 6 | 0 | 387.7 (383.3–391.7) |

### Écran scindé, lacet 0°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| defaut | 6 cartes | 248 (169–282) | 11396 (9312–12140) | 1925 (1430–2241) | 9 | 4 | 6 | 0 | 315.5 (311.1–319.5) |
| air | 6 cartes | 261 (185–294) | 11428 (9340–12164) | 1939 (1444–2257) | 9 | 4 | 6 | 0 | 315.5 (311.1–319.5) |

### Écran scindé, lacet 45°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| defaut | 6 cartes | 257 (176–286) | 11188 (9380–12208) | 1804 (1444–2248) | 9 | 4 | 6 | 0 | 317.5 (313.1–321.5) |
| air | 6 cartes | 273 (192–302) | 11218 (9408–12240) | 1820 (1458–2264) | 9 | 4 | 6 | 0 | 317.5 (313.1–321.5) |

## Écarts à la référence « defaut »

Carte par carte (même carte, même vue, même lacet), la configuration moins la référence : médiane des six cartes [pire carte] ; pompe sous une fusée à part.

### vue unique

| configuration | lacet | Δ appels, cartes | Δ appels, pompe | Δ primitives, cartes | Δ primitives, pompe | Δ copies d'écran | Δ lum. à ombre | Δ vues rendues |
|---|---|---|---|---|---|---|---|---|
| air | 0° | +8.5 [+10] | — | +17 [+20] | — | +0 | +0 | +0 |
| air | 45° | +8.5 [+10] | — | +17 [+20] | — | +0 | +0 | +0 |

### écran scindé

| configuration | lacet | Δ appels, cartes | Δ appels, pompe | Δ primitives, cartes | Δ primitives, pompe | Δ copies d'écran | Δ lum. à ombre | Δ vues rendues |
|---|---|---|---|---|---|---|---|---|
| air | 0° | +13 [+16] | — | +26 [+32] | — | +0 | +0 | +0 |
| air | 45° | +16 [+18] | — | +32 [+36] | — | +0 | +0 | +0 |

## Détail par vue — pompe sous une fusée

Appels de dessin par vue rendue et par passe (visible 3D / ombres 3D / canevas 2D), médiane des images.

