# L'orientation — le capteur de J2, dix classes × huit orientations

Même processus, mêmes places que la base (Parasite, profil, ombre d'aujourd'hui), même torche (Parasite).
Orientation = où regarde J2 par rapport à la torche de J1 : `face` il la regarde, `dos` il lui tourne le dos,
`_g` / `_d` la torche à sa gauche / droite. Écart = (plus haut − plus bas) / plus haut.

## 45° B (lacet 45.0 B)

Facteurs de la voie (d) : **d1** (constant, parts moyennées sur 64 directions) ; *d1 profil* (la même chose avec le seul profil de la base, pour comparaison).

| Classe | part moyenne | d1 | d1 profil |
|---|---|---|---|
| Parasite | 0.396 | 1.000 | 1.000 |
| Illusionniste | 0.393 | 1.006 | 1.000 |
| Terrassier | 0.402 | 0.983 | 1.145 |
| Braconnier | 0.433 | 0.913 | 1.109 |
| Occulteur | 0.365 | 1.084 | 1.029 |
| Fumiste | 0.334 | 1.184 | 1.164 |
| Incendiaire | 0.363 | 1.089 | 1.029 |
| Sentinelle | 0.397 | 0.995 | 1.029 |
| Allumeur | 0.406 | 0.973 | 1.000 |
| Spectre | 0.446 | 0.888 | 0.973 |

### Place `b10` — capteur mesuré (moyenne de l'anneau)

Sans ombre propre : 0.1577 à 0.1577 sur 14 prises (classes et orientations mêlées).

| Classe | face | diag_face_g | profil_g | diag_dos_g | dos | diag_dos_d | profil_d | diag_face_d | écart entre orientations |
|---|---|---|---|---|---|---|---|---|---|
| Parasite | 0.0657 | 0.0877 | 0.0997 | 0.1014 | 0.0865 | 0.0647 | 0.0284 | 0.0095 | 91 % |
| Illusionniste | 0.0657 | 0.0877 | 0.0997 | 0.1014 | 0.0865 | 0.0647 | 0.0284 | 0.0095 | 91 % |
| Terrassier | 0.0888 | 0.0827 | 0.0930 | 0.0886 | 0.0718 | 0.0697 | 0.0330 | 0.0293 | 68 % |
| Braconnier | 0.0574 | 0.0845 | 0.0920 | 0.0951 | 0.0977 | 0.0819 | 0.0573 | 0.0276 | 72 % |
| Occulteur | 0.0638 | 0.0858 | 0.0997 | 0.1014 | 0.0782 | 0.0546 | 0.0219 | 0.0000 | 100 % |
| Fumiste | 0.0638 | 0.0827 | 0.0955 | 0.0913 | 0.0717 | 0.0450 | 0.0122 | 0.0000 | 100 % |
| Incendiaire | 0.0638 | 0.0846 | 0.0997 | 0.0993 | 0.0846 | 0.0546 | 0.0122 | 0.0000 | 100 % |
| Sentinelle | 0.0710 | 0.0846 | 0.0972 | 0.0993 | 0.0846 | 0.0653 | 0.0348 | 0.0127 | 87 % |
| Allumeur | 0.0742 | 0.0877 | 0.0997 | 0.1014 | 0.0846 | 0.0653 | 0.0348 | 0.0127 | 87 % |
| Spectre | 0.0691 | 0.0877 | 0.1039 | 0.1064 | 0.0876 | 0.0707 | 0.0352 | 0.0366 | 67 % |
| **écart entre classes — aujourd'hui** | 35 % | 6 % | 11 % | 17 % | 27 % | 45 % | 79 % | 100 % | |
| **écart entre classes — (d1)** | 40 % | 21 % | 26 % | 21 % | 23 % | 29 % | 75 % | 100 % | |
| **écart entre classes — (d2)** | 16 % | 4 % | 10 % | 5 % | 8 % | 9 % | 64 % | 100 % | |
| **écart entre classes — maximum, aujourd'hui** | 0 % | 0 % | 0 % | 0 % | 0 % | 7 % | 20 % | 100 % | |
| **écart entre classes — maximum × d1** | 25 % | 25 % | 25 % | 25 % | 25 % | 21 % | 12 % | 100 % | |
| **écart entre classes — maximum × d2** | 31 % | 9 % | 16 % | 16 % | 30 % | 42 % | 84 % | 100 % | |

Géométrie : erreur de la prédiction (vraie torche) et part éclairée exacte / rayons parallèles.

- niveau : erreur moyenne 0.0023, au pire 0.0122 ; 35 prises sur 80 prédites à 0,0005 près
- maximum : erreur moyenne 0.0025, au pire 0.1686
- part éclairée, vraie torche contre rayons parallèles : écart moyen 0.006, au pire 0.047 (en points d'anneau : 0.4 / 3.0 sur 64)
- contrôle (de face repris après les sept autres) : écart au pire 0.0000 sur 10 classes

### Place `mi` — capteur mesuré (moyenne de l'anneau)

Sans ombre propre : 0.4939 à 0.4939 sur 14 prises (classes et orientations mêlées).

| Classe | face | diag_face_g | profil_g | diag_dos_g | dos | diag_dos_d | profil_d | diag_face_d | écart entre orientations |
|---|---|---|---|---|---|---|---|---|---|
| Parasite | 0.1953 | 0.2554 | 0.2794 | 0.2852 | 0.2521 | 0.1744 | 0.0469 | 0.0257 | 91 % |
| Illusionniste | 0.1953 | 0.2554 | 0.2794 | 0.2852 | 0.2521 | 0.1744 | 0.0469 | 0.0257 | 91 % |
| Terrassier | 0.2522 | 0.2333 | 0.2529 | 0.2496 | 0.2071 | 0.1720 | 0.0926 | 0.0868 | 66 % |
| Braconnier | 0.1618 | 0.2309 | 0.2587 | 0.2657 | 0.2833 | 0.2206 | 0.1445 | 0.0751 | 74 % |
| Occulteur | 0.1802 | 0.2483 | 0.2729 | 0.2852 | 0.2269 | 0.1389 | 0.0406 | 0.0000 | 100 % |
| Fumiste | 0.1802 | 0.2401 | 0.2598 | 0.2569 | 0.2070 | 0.1123 | 0.0000 | 0.0000 | 100 % |
| Incendiaire | 0.1876 | 0.2401 | 0.2794 | 0.2786 | 0.2453 | 0.1455 | 0.0000 | 0.0000 | 100 % |
| Sentinelle | 0.2054 | 0.2401 | 0.2725 | 0.2786 | 0.2521 | 0.1746 | 0.0653 | 0.0351 | 87 % |
| Allumeur | 0.2154 | 0.2483 | 0.2794 | 0.2852 | 0.2521 | 0.1746 | 0.0653 | 0.0351 | 88 % |
| Spectre | 0.1944 | 0.2483 | 0.2860 | 0.2922 | 0.2539 | 0.1914 | 0.0866 | 0.0689 | 76 % |
| **écart entre classes — aujourd'hui** | 36 % | 10 % | 12 % | 15 % | 27 % | 49 % | 100 % | 100 % | |
| **écart entre classes — (d1)** | 40 % | 26 % | 23 % | 22 % | 24 % | 34 % | 100 % | 100 % | |
| **écart entre classes — (d2)** | 19 % | 6 % | 8 % | 5 % | 10 % | 14 % | 100 % | 100 % | |
| **écart entre classes — maximum, aujourd'hui** | 2 % | 0 % | 0 % | 0 % | 1 % | 20 % | 100 % | 100 % | |
| **écart entre classes — maximum × d1** | 25 % | 25 % | 25 % | 25 % | 25 % | 25 % | 100 % | 100 % | |
| **écart entre classes — maximum × d2** | 33 % | 9 % | 16 % | 16 % | 30 % | 39 % | 100 % | 100 % | |

Géométrie : erreur de la prédiction (vraie torche) et part éclairée exacte / rayons parallèles.

- niveau : erreur moyenne 0.0051, au pire 0.0384 ; 41 prises sur 80 prédites à 0,0005 près
- maximum : erreur moyenne 0.0024, au pire 0.0314
- part éclairée, vraie torche contre rayons parallèles : écart moyen 0.017, au pire 0.156 (en points d'anneau : 1.1 / 10.0 sur 64)
- contrôle (de face repris après les sept autres) : écart au pire 0.0000 sur 10 classes

## 0° (lacet 0.0 B)

Facteurs de la voie (d) : **d1** (constant, parts moyennées sur 64 directions) ; *d1 profil* (la même chose avec le seul profil de la base, pour comparaison).

| Classe | part moyenne | d1 | d1 profil |
|---|---|---|---|
| Parasite | 0.396 | 1.000 | 1.000 |
| Illusionniste | 0.393 | 1.006 | 1.000 |
| Terrassier | 0.402 | 0.983 | 1.145 |
| Braconnier | 0.433 | 0.913 | 1.109 |
| Occulteur | 0.365 | 1.084 | 1.029 |
| Fumiste | 0.334 | 1.184 | 1.164 |
| Incendiaire | 0.363 | 1.089 | 1.029 |
| Sentinelle | 0.397 | 0.995 | 1.029 |
| Allumeur | 0.406 | 0.973 | 1.000 |
| Spectre | 0.446 | 0.888 | 0.973 |

### Place `b10` — capteur mesuré (moyenne de l'anneau)

Sans ombre propre : 0.1577 à 0.1577 sur 14 prises (classes et orientations mêlées).

| Classe | face | diag_face_g | profil_g | diag_dos_g | dos | diag_dos_d | profil_d | diag_face_d | écart entre orientations |
|---|---|---|---|---|---|---|---|---|---|
| Parasite | 0.0657 | 0.0877 | 0.0997 | 0.1014 | 0.0865 | 0.0647 | 0.0284 | 0.0095 | 91 % |
| Illusionniste | 0.0657 | 0.0877 | 0.0997 | 0.1014 | 0.0865 | 0.0647 | 0.0284 | 0.0095 | 91 % |
| Terrassier | 0.0888 | 0.0827 | 0.0930 | 0.0886 | 0.0718 | 0.0697 | 0.0330 | 0.0293 | 68 % |
| Braconnier | 0.0574 | 0.0845 | 0.0920 | 0.0951 | 0.0977 | 0.0819 | 0.0573 | 0.0276 | 72 % |
| Occulteur | 0.0638 | 0.0858 | 0.0997 | 0.1014 | 0.0782 | 0.0546 | 0.0219 | 0.0000 | 100 % |
| Fumiste | 0.0638 | 0.0827 | 0.0955 | 0.0913 | 0.0717 | 0.0450 | 0.0122 | 0.0000 | 100 % |
| Incendiaire | 0.0638 | 0.0846 | 0.0997 | 0.0993 | 0.0846 | 0.0546 | 0.0122 | 0.0000 | 100 % |
| Sentinelle | 0.0710 | 0.0846 | 0.0972 | 0.0993 | 0.0846 | 0.0653 | 0.0348 | 0.0127 | 87 % |
| Allumeur | 0.0742 | 0.0877 | 0.0997 | 0.1014 | 0.0846 | 0.0653 | 0.0348 | 0.0127 | 87 % |
| Spectre | 0.0691 | 0.0877 | 0.1039 | 0.1064 | 0.0876 | 0.0707 | 0.0352 | 0.0366 | 67 % |
| **écart entre classes — aujourd'hui** | 35 % | 6 % | 11 % | 17 % | 27 % | 45 % | 79 % | 100 % | |
| **écart entre classes — (d1)** | 40 % | 21 % | 26 % | 21 % | 23 % | 29 % | 75 % | 100 % | |
| **écart entre classes — (d2)** | 16 % | 4 % | 10 % | 5 % | 8 % | 9 % | 64 % | 100 % | |
| **écart entre classes — maximum, aujourd'hui** | 0 % | 0 % | 0 % | 0 % | 0 % | 7 % | 20 % | 100 % | |
| **écart entre classes — maximum × d1** | 25 % | 25 % | 25 % | 25 % | 25 % | 21 % | 12 % | 100 % | |
| **écart entre classes — maximum × d2** | 31 % | 9 % | 16 % | 16 % | 30 % | 42 % | 84 % | 100 % | |

Géométrie : erreur de la prédiction (vraie torche) et part éclairée exacte / rayons parallèles.

- niveau : erreur moyenne 0.0023, au pire 0.0122 ; 35 prises sur 80 prédites à 0,0005 près
- maximum : erreur moyenne 0.0025, au pire 0.1686
- part éclairée, vraie torche contre rayons parallèles : écart moyen 0.006, au pire 0.047 (en points d'anneau : 0.4 / 3.0 sur 64)
- contrôle (de face repris après les sept autres) : écart au pire 0.0000 sur 10 classes

### Place `mi` — capteur mesuré (moyenne de l'anneau)

Sans ombre propre : 0.4939 à 0.4939 sur 14 prises (classes et orientations mêlées).

| Classe | face | diag_face_g | profil_g | diag_dos_g | dos | diag_dos_d | profil_d | diag_face_d | écart entre orientations |
|---|---|---|---|---|---|---|---|---|---|
| Parasite | 0.1953 | 0.2554 | 0.2794 | 0.2852 | 0.2521 | 0.1744 | 0.0469 | 0.0257 | 91 % |
| Illusionniste | 0.1953 | 0.2554 | 0.2794 | 0.2852 | 0.2521 | 0.1744 | 0.0469 | 0.0257 | 91 % |
| Terrassier | 0.2522 | 0.2333 | 0.2529 | 0.2496 | 0.2071 | 0.1720 | 0.0926 | 0.0868 | 66 % |
| Braconnier | 0.1618 | 0.2309 | 0.2587 | 0.2657 | 0.2833 | 0.2206 | 0.1445 | 0.0751 | 74 % |
| Occulteur | 0.1802 | 0.2483 | 0.2729 | 0.2852 | 0.2269 | 0.1389 | 0.0406 | 0.0000 | 100 % |
| Fumiste | 0.1802 | 0.2401 | 0.2598 | 0.2569 | 0.2070 | 0.1123 | 0.0000 | 0.0000 | 100 % |
| Incendiaire | 0.1876 | 0.2401 | 0.2794 | 0.2786 | 0.2453 | 0.1455 | 0.0000 | 0.0000 | 100 % |
| Sentinelle | 0.2054 | 0.2401 | 0.2725 | 0.2786 | 0.2521 | 0.1746 | 0.0653 | 0.0351 | 87 % |
| Allumeur | 0.2154 | 0.2483 | 0.2794 | 0.2852 | 0.2521 | 0.1746 | 0.0653 | 0.0351 | 88 % |
| Spectre | 0.1944 | 0.2483 | 0.2860 | 0.2922 | 0.2539 | 0.1914 | 0.0866 | 0.0689 | 76 % |
| **écart entre classes — aujourd'hui** | 36 % | 10 % | 12 % | 15 % | 27 % | 49 % | 100 % | 100 % | |
| **écart entre classes — (d1)** | 40 % | 26 % | 23 % | 22 % | 24 % | 34 % | 100 % | 100 % | |
| **écart entre classes — (d2)** | 19 % | 6 % | 8 % | 5 % | 10 % | 14 % | 100 % | 100 % | |
| **écart entre classes — maximum, aujourd'hui** | 2 % | 0 % | 0 % | 0 % | 1 % | 20 % | 100 % | 100 % | |
| **écart entre classes — maximum × d1** | 25 % | 25 % | 25 % | 25 % | 25 % | 25 % | 100 % | 100 % | |
| **écart entre classes — maximum × d2** | 33 % | 9 % | 16 % | 16 % | 30 % | 39 % | 100 % | 100 % | |

Géométrie : erreur de la prédiction (vraie torche) et part éclairée exacte / rayons parallèles.

- niveau : erreur moyenne 0.0051, au pire 0.0384 ; 41 prises sur 80 prédites à 0,0005 près
- maximum : erreur moyenne 0.0024, au pire 0.0314
- part éclairée, vraie torche contre rayons parallèles : écart moyen 0.017, au pire 0.156 (en points d'anneau : 1.1 / 10.0 sur 64)
- contrôle (de face repris après les sept autres) : écart au pire 0.0000 sur 10 classes

