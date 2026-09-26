<!-- généré par composer.py -->

Réglages du banc : `BANC_ZOOM reglages lacet_j1=45 lacet_j2=225 option=B decalage=0.15 facteur_portee=0.75 fenetre=(1920, 1080) vue=(1920, 1080)`

| Zoom | Corps de J1 sur l'image, 1080 lignes (L × H, px) | Corps sur 1440 lignes (×4/3) | Zone de touche (disque de 18 px) à l'écran, 1080 lignes | Torche du pistolet à l'écran, visée verticale / horizontale | …en part de la demi-hauteur / de la demi-largeur | …en part de l'écran DEVANT J1 (702 / 1166 px) |
|---|---|---|---|---|---|---|
| ×1,25 | 39 × 43 ; 39 × 44 | 52 × 57 ; 52 × 59 | 57 × 45 px | 384 / 487 px | 71 % / 51 % | 55 % / 42 % |
| ×1,5 | 47 × 52 ; 47 × 52 | 63 × 69 ; 63 × 69 | 69 × 54 px | 461 / 585 px | 85 % / 61 % | 66 % / 50 % |
| ×1,75 | 55 × 60 ; 54 × 60 | 73 × 80 ; 72 × 80 | 80 × 63 px | 538 / 682 px | 100 % / 71 % | 77 % / 59 % |
| ×2,0 | 62 × 69 ; 63 × 70 | 83 × 92 ; 84 × 93 | 91 × 72 px | 614 / 780 px | 114 % / 81 % | 88 % / 67 % |

Le regard décalé avance la caméra de 0,15 de la hauteur VISIBLE : à l'écran, c'est toujours 162 px, quel que soit le zoom. J1 se tient donc à 702 px du bord vers lequel il vise (visée verticale), à 1166 px en visée horizontale (162 / sin 52° = 206 px de décalage) — hors bornes de la carte. Le zoom grandit la torche, pas cet espace.

| Classe | Portée (px de monde) | Zoom au-delà duquel le bout de la torche sort de l'écran : visée verticale / horizontale |
|---|---|---|
| Pistolet | 307 | ×2,29 / ×2,99 |
| Fusil | 346 | ×2,03 / ×2,66 |
| Pompe | 192 | ×3,66 / ×4,78 |
| Arbalète | 672 | ×1,04 / ×1,37 |

Jusqu'où l'écran 1920×1080 montre le sol autour du joueur, en pixels de MONDE, hors bornes de la carte (calcul : caméra iso KEEP_HEIGHT, tangage 52°, décalage 0,15 ; vérifié contre la vraie caméra, écart 0 px) :

| Zoom | Visée verticale : devant / derrière / côtés | Visée horizontale : devant / derrière / côtés | Pistolet 307 px : part de la portée visible devant (vert. / horiz.) | Arbalète 672 px : idem |
|---|---|---|---|---|
| ×1,25 | 562 / 302 / 605 | 735 / 476 / 432 | 100 % / 100 % | 84 % / 100 % |
| ×1,5 | 468 / 252 / 504 | 612 / 396 / 360 | 100 % / 100 % | 70 % / 91 % |
| ×1,75 | 401 / 216 / 432 | 525 / 340 / 309 | 100 % / 100 % | 60 % / 78 % |
| ×2,0 | 351 / 189 / 378 | 459 / 297 / 270 | 100 % / 100 % | 52 % / 68 % |

| Carte | Zoom | Part de la carte à l'écran de J1 / de J2 | J1 voit devant / derrière / à gauche / à droite (px de monde, jusqu'au bord de l'image) | J2 idem | J1 a J2 à l'écran | J2 a J1 à l'écran | Scindé : J1 / J2 ont l'autre |
|---|---|---|---|---|---|---|---|
| Le Cloître | ×1,25 | 72 % / 76 % | 562 / 302 / 744 / 466 | 723 / 565 / 507 / 413 | oui | oui | oui / oui |
| Le Cloître | ×1,5 | 54 % / 60 % | 468 / 252 / 515 / 493 | 645 / 429 / 422 / 344 | oui | oui | oui / oui |
| Le Cloître | ×1,75 | 42 % / 47 % | 401 / 216 / 432 / 432 | 553 / 367 / 362 / 295 | oui | oui | oui / oui |
| Le Cloître | ×2,0 | 33 % / 37 % | 351 / 189 / 378 / 378 | 484 / 322 / 317 / 258 | oui | oui | oui / oui |
| La Croisée | ×1,25 | 71 % / 63 % | 562 / 302 / 605 / 605 | 774 / 514 / 413 / 507 | oui | oui | oui / oui |
| La Croisée | ×1,5 | 57 % / 63 % | 468 / 252 / 540 / 469 | 409 / 664 / 344 / 422 | oui | oui | oui / oui |
| La Croisée | ×1,75 | 44 % / 48 % | 401 / 216 / 432 / 432 | 430 / 490 / 295 / 362 | oui | oui | oui / oui |
| La Croisée | ×2,0 | 36 % / 36 % | 351 / 189 / 378 / 378 | 445 / 360 / 258 / 317 | oui | oui | oui / oui |

Classes relevées : Pistolet 307 px (demi-angle 35°) ; Fusil 346 px (demi-angle 10°) ; Pompe 192 px (demi-angle 60°) ; Arbalète 672 px (demi-angle 5°)
