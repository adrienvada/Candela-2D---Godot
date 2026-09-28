## Tableau par configuration

Six cartes livrées : médiane des six (min–max) ; chaque carte vaut la médiane de ses 12 images. Pompe sous une fusée (Arène Standard) : la moyenne de ses 120 images.

### Vue unique, lacet 45°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| defaut2 | 6 cartes | 135 (91–153) | 6211 (5304–6740) | 897.5 (712–1113) | 4 | 2 | 6 | 0 | 385.7 (381.3–389.7) |
| defaut | 6 cartes | 145.5 (97–157) | 6311 (5414–6836) | 948 (762–1160) | 4 | 2 | 6 | 0 | 415.3 (400.8–419.2) |
| solmarque2 | 6 cartes | 137 (91–153) | 6210 (5312–6740) | 897.5 (716–1113) | 4 | 2 | 6 | 0 | 387.9 (383.4–391.8) |
| solmarque | 6 cartes | 136 (91–154) | 6210 (5304–6742) | 899 (712–1113) | 4 | 2 | 6 | 0 | 387.9 (383.4–391.8) |

### Écran scindé, lacet 45°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| defaut2 | 6 cartes | 255 (176–288) | 11184 (9372–12212) | 1805 (1440–2248) | 9 | 4 | 6 | 0 | 315.5 (311.1–319.5) |
| defaut | 6 cartes | 261 (182–290) | 11286 (9464–12304) | 1851.5 (1481–2295) | 9 | 4 | 6 | 0 | 345.0 (330.6–349.0) |
| solmarque2 | 6 cartes | 251 (176–284) | 11188 (9356–12204) | 1801 (1432–2248) | 9 | 4 | 6 | 0 | 317.6 (313.2–321.6) |
| solmarque | 6 cartes | 255 (176–288) | 11182 (9372–12212) | 1805 (1440–2248) | 9 | 4 | 6 | 0 | 317.6 (313.2–321.6) |

## Écarts à la référence « defaut2 »

Carte par carte (même carte, même vue, même lacet), la configuration moins la référence : médiane des six cartes [pire carte] ; pompe sous une fusée à part.

### vue unique

| configuration | lacet | Δ appels, cartes | Δ appels, pompe | Δ primitives, cartes | Δ primitives, pompe | Δ copies d'écran | Δ lum. à ombre | Δ vues rendues |
|---|---|---|---|---|---|---|---|---|
| defaut | 45° | +6 [+12] | — | +100 [+118] | — | +0 | +0 | +0 |
| solmarque2 | 45° | +0 [+4] | — | +0 [+8] | — | +0 | +0 | +0 |
| solmarque | 45° | +0 [+2] | — | +0 [+4] | — | +0 | +0 | +0 |

### écran scindé

| configuration | lacet | Δ appels, cartes | Δ appels, pompe | Δ primitives, cartes | Δ primitives, pompe | Δ copies d'écran | Δ lum. à ombre | Δ vues rendues |
|---|---|---|---|---|---|---|---|---|
| defaut | 45° | +6 [+12] | — | +102 [+114] | — | +0 | +0 | +0 |
| solmarque2 | 45° | -2 [-8] | — | -4 [-16] | — | +0 | +0 | +0 |
| solmarque | 45° | +0 [-2] | — | +0 [-4] | — | +0 | +0 | +0 |

## Détail par vue — pompe sous une fusée

Appels de dessin par vue rendue et par passe (visible 3D / ombres 3D / canevas 2D), médiane des images.

