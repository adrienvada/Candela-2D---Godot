## Tableau par configuration

Six cartes livrées : médiane des six (min–max) ; chaque carte vaut la médiane de ses 12 images. Pompe sous une fusée (Arène Standard) : la moyenne de ses 120 images.

### Vue unique, lacet 45°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| eteint | 6 cartes | 142.5 (97–158) | 6311 (5408–6838) | 947 (759–1160) | 4 | 2 | 6 | 0 | 411.2 (396.8–415.2) |
| meubles | 6 cartes | 140 (95–155) | 13340 (10338–15708) | 900.5 (718–1117) | 4 | 2 | 6 | 0 | 386.1 (381.6–390.1) |

### Écran scindé, lacet 45°

| configuration | scène | appels | primitives | objets | vues rendues | copies d'écran | lum. 2D à ombre | lum. 3D | mém. vidéo (Mo) |
|---|---|---|---|---|---|---|---|---|---|
| eteint | 6 cartes | 262.5 (182–294) | 11286 (9476–12312) | 1854 (1487–2295) | 9 | 4 | 6 | 0 | 341.0 (326.6–344.9) |
| meubles | 6 cartes | 261 (184–296) | 25432 (19432–30156) | 1812 (1446–2256) | 9 | 4 | 6 | 0 | 315.9 (311.4–319.9) |

## Écarts à la référence « eteint »

Carte par carte (même carte, même vue, même lacet), la configuration moins la référence : médiane des six cartes [pire carte] ; pompe sous une fusée à part.

### vue unique

| configuration | lacet | Δ appels, cartes | Δ appels, pompe | Δ primitives, cartes | Δ primitives, pompe | Δ copies d'écran | Δ lum. à ombre | Δ vues rendues |
|---|---|---|---|---|---|---|---|---|
| meubles | 45° | -2.5 [-5] | — | +7088 [+8876] | — | +0 | +0 | +0 |

### écran scindé

| configuration | lacet | Δ appels, cartes | Δ appels, pompe | Δ primitives, cartes | Δ primitives, pompe | Δ copies d'écran | Δ lum. à ombre | Δ vues rendues |
|---|---|---|---|---|---|---|---|---|
| meubles | 45° | +1 [-3] | — | +14280 [+17846] | — | +0 | +0 | +0 |

## Détail par vue — pompe sous une fusée

Appels de dessin par vue rendue et par passe (visible 3D / ombres 3D / canevas 2D), médiane des images.

