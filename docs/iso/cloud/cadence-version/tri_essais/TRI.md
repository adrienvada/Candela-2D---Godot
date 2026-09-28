# Tri du cloud — référence « ref » · témoin « temoin »

Comptes : écart à la référence, médiane des six cartes (vue unique U, écran scindé S) et moyenne de 120 images au pompe sous une fusée (PU, PS). Bruit retenu : carte/unique ±3, carte/scinde ±7, pompe/unique ±3, pompe/scinde ±20. Aucun temps : le cloud ne mesure pas la cadence.

| nouveauté | classe | Δ appels U / S | Δ appels PU / PS | Δ primitives U (%) | vues, copies, ombres | programmes nouveaux | pire programme : Δ instr. / lect. / boucles | part de l'écran (max, cartes) |
|---|---|---|---|---|---|---|---|---|
| faisceau | **neutre** | +3 / +5 | +1.3 / +7.7 | +0.1 | aucune | 0 | — | 0.10 % |
| mannequin | **à surveiller** | +0 / +0.5 | -0.6 / +3.9 | +0.0 | aucune | 2 | +252 / +0 / +0 | 0.09 % |
| pochoirs | **neutre** | +0.5 / +1.5 | -0.7 / -0.9 | +0.0 | aucune | 0 | — | 0.09 % |
| encre | **lourde** | +20 / +40.5 | -1.3 / +2.8 | +3.9 | aucune | 26 | +170 / +0 / +0 | 0.15 % |
| tuyaux | **lourde** | +1 / +5 | +0.2 / +11.7 | +221.9 | aucune | 6 | +1156 / +14 / +0 | 0.14 % |
| enseignes | **à surveiller** | +1 / +3.5 | -0.1 / +5.5 | +0.2 | aucune | 6 | +1138 / +15 / +0 | 0.10 % |
| murs-meubles | **lourde** | +5.5 / +9 | +3.7 / +20.6 | +115.9 | aucune | 12 | +1156 / +14 / +0 | 0.19 % |
| sol-marque | **neutre** | +1 / +1.5 | -0.2 / +8.6 | +0.0 | aucune | 0 | — | 0.08 % |
| corps-soi-sombre | **neutre** | +0 / +1.5 | -0.6 / +6.5 | +0.0 | aucune | 5 | +136 / +0 / +0 | 0.28 % |
| lampe-claire | **à surveiller** | +1 / +0.5 | -0.4 / +10.5 | +0.0 | aucune | 3 | +156 / +2 / +0 | 6.32 % |
| masque-V5 | **lourde** | +1 / +2 | +0.5 / +5.3 | +0.0 | aucune | 10 | +3486 / +23 / +7 | 0.07 % |
| calib-masque-bande | **lourde** | +2 / +3.5 | -1.6 / +12.9 | +0.1 | aucune | 5 | +12514 / +98 / +15 | 0.06 % |
| calib-corps-detaille | **à surveiller** | +12 / +24.5 | +2.7 / +13.2 | +8.5 | aucune | 5 | +226 / +0 / +1 | 0.08 % |
| calib-rouge-long | **neutre** | +0.5 / -1 | -0.6 / +14.6 | +0.0 | aucune | 0 | — | 0.10 % |

**faisceau — neutre.** rien au-delà du bruit, aucun programme de shader nouveau.
  - le jeu dit : + [faisceau] allumé — le cœur chaud seul, sans rayon

**mannequin — à surveiller.** shader : +252 instructions (uniforme mannequin)
  - le jeu dit : + [mannequin] allumé — les corps en mannequins (ISO# lot A)
  - programme 211.shader_test (uniforme mannequin plié), branche d'uniforme (apparié à le même, uniforme à 0, contenu à 1.00) : 1441 instructions, 0 lectures, 0 boucles ; Δ +252 / +0 / +0 ; code propre : uniforme mannequin
  - programme 220.shader_test (uniforme mannequin plié), branche d'uniforme (apparié à le même, uniforme à 0, contenu à 1.00) : 36 instructions, 0 lectures, 0 boucles ; Δ +0 / +0 / +0 ; code propre : uniforme mannequin

**pochoirs — neutre.** rien au-delà du bruit, aucun programme de shader nouveau.
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)

**encre — lourde.** +20.0 appels en carte/unique (> +15 : le détail des corps, qui tient à 0,976, plus le bruit) ; +40.5 appels en carte/scinde (> +31 : le détail des corps, qui tient à 0,976, plus le bruit) ; shader neuf : 170 instructions, 0 lectures (m_contour_unites, m_normale_coque ; le plus lourd déjà à l'écran : 3846, 51)
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)
  - programme 211.shader_test, neuf (apparié à 193.shader_test, contenu à 0.36) : 170 instructions, 0 lectures, 0 boucles ; Δ +170 / +0 / +0 ; code propre : m_contour_unites, m_normale_coque
  - programme 223.shader_test, neuf (apparié à 205.shader_test, contenu à 0.37) : 170 instructions, 0 lectures, 0 boucles ; Δ +170 / +0 / +0 ; code propre : m_contour_unites, m_normale_coque
  - programme 214.shader_test, neuf (apparié à 196.shader_test, contenu à 0.36) : 170 instructions, 0 lectures, 0 boucles ; Δ +170 / +0 / +0 ; code propre : m_contour_unites, m_normale_coque
  - programme 160.shader_test, modifié (apparié à 142.shader_test, contenu à 1.00) : 3912 instructions, 51 lectures, 1 boucles ; Δ +66 / +0 / +0 ; code propre : m_pate_hachures, m_pate_hachures_facteur, m_penombre

**tuyaux — lourde.** primitives +222 % en carte/unique (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; primitives +246 % en carte/scinde (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; primitives +146 % en pompe/unique (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; primitives +167 % en pompe/scinde (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; shader neuf : 1156 instructions, 14 lectures (m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste ; le plus lourd déjà à l'écran : 3846, 51)
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)
  - programme 193.shader_test, neuf (apparié à 145.shader_test, contenu à 0.64) : 1156 instructions, 14 lectures, 0 boucles ; Δ +1156 / +14 / +0 ; code propre : m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste
  - programme 190.shader_test, neuf (apparié à 142.shader_test, contenu à 0.64) : 1156 instructions, 14 lectures, 0 boucles ; Δ +1156 / +14 / +0 ; code propre : m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste
  - programme 211.shader_test, neuf (apparié à 172.shader_test, contenu à 0.65) : 1156 instructions, 14 lectures, 0 boucles ; Δ +1156 / +14 / +0 ; code propre : m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste
  - programme 202.shader_test, neuf (apparié à 154.shader_test, contenu à 0.65) : 3 instructions, 0 lectures, 0 boucles ; Δ +3 / +0 / +0 ; code propre : m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste

**enseignes — à surveiller.** shader neuf : 1138 instructions, 15 lectures (m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place ; le plus lourd déjà à l'écran : 3846, 51) ; shader neuf : 11 instructions, 1 lectures (m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place ; le plus lourd déjà à l'écran : 3846, 51)
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)
  - programme 193.shader_test, neuf (apparié à 145.shader_test, contenu à 0.64) : 1138 instructions, 15 lectures, 0 boucles ; Δ +1138 / +15 / +0 ; code propre : m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place
  - programme 190.shader_test, neuf (apparié à 142.shader_test, contenu à 0.64) : 1138 instructions, 15 lectures, 0 boucles ; Δ +1138 / +15 / +0 ; code propre : m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place
  - programme 211.shader_test, neuf (apparié à 172.shader_test, contenu à 0.65) : 1138 instructions, 15 lectures, 0 boucles ; Δ +1138 / +15 / +0 ; code propre : m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place
  - programme 202.shader_test, neuf (apparié à 154.shader_test, contenu à 0.64) : 11 instructions, 1 lectures, 0 boucles ; Δ +11 / +1 / +0 ; code propre : m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place

**murs-meubles — lourde.** primitives +116 % en carte/unique (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; primitives +129 % en carte/scinde (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; primitives +106 % en pompe/unique (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; primitives +122 % en pompe/scinde (géométrie : au-delà de +50 %, aucune mesure du Mac ne dit que la règle tienne) ; +5.5 appels en carte/unique (bruit ±3) ; +9.0 appels en carte/scinde (bruit ±7) ; +3.7 appels en pompe/unique (bruit ±3) ; +20.6 appels en pompe/scinde (bruit ±20) ; shader neuf : 1156 instructions, 14 lectures (m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste ; le plus lourd déjà à l'écran : 3846, 51) ; shader neuf : 1138 instructions, 15 lectures (m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place ; le plus lourd déjà à l'écran : 3846, 51) ; shader neuf : 11 instructions, 1 lectures (m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place ; le plus lourd déjà à l'écran : 3846, 51)
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)
  - programme 208.shader_test, neuf (apparié à 145.shader_test, contenu à 0.64) : 1156 instructions, 14 lectures, 0 boucles ; Δ +1156 / +14 / +0 ; code propre : m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste
  - programme 229.shader_test, neuf (apparié à 172.shader_test, contenu à 0.65) : 1156 instructions, 14 lectures, 0 boucles ; Δ +1156 / +14 / +0 ; code propre : m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste
  - programme 205.shader_test, neuf (apparié à 142.shader_test, contenu à 0.64) : 1156 instructions, 14 lectures, 0 boucles ; Δ +1156 / +14 / +0 ; code propre : m_albedo, m_contour, m_corps_sombre, m_couvert, m_emprise_preuve, m_encre_reste
  - programme 193.shader_test, neuf (apparié à 145.shader_test, contenu à 0.64) : 1138 instructions, 15 lectures, 0 boucles ; Δ +1138 / +15 / +0 ; code propre : m_atlas, m_couvert, m_emprise_preuve, m_face_n, m_matiere_max, m_place

**sol-marque — neutre.** rien au-delà du bruit, aucun programme de shader nouveau.
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)

**corps-soi-sombre — neutre.** rien au-delà du bruit, aucun programme de shader nouveau.
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)
  - programme 211.shader_test, modifié (apparié à 193.shader_test, contenu à 1.00) : 1609 instructions, 2 lectures, 0 boucles ; Δ +136 / +0 / +0 ; code propre : m_ax, m_axe_x, m_axe_z, m_az, m_bande, m_corps
  - programme 223.shader_test, modifié (apparié à 205.shader_test, contenu à 1.00) : 1609 instructions, 2 lectures, 0 boucles ; Δ +136 / +0 / +0 ; code propre : m_ax, m_axe_x, m_axe_z, m_az, m_bande, m_corps
  - programme 214.shader_test, modifié (apparié à 196.shader_test, contenu à 1.00) : 1609 instructions, 2 lectures, 0 boucles ; Δ +136 / +0 / +0 ; code propre : m_ax, m_axe_x, m_axe_z, m_az, m_bande, m_corps
  - programme 220.shader_test, modifié (apparié à 202.shader_test, contenu à 1.00) : 36 instructions, 0 lectures, 0 boucles ; Δ +0 / +0 / +0 ; code propre : m_ax, m_axe_x, m_axe_z, m_az, m_bande, m_corps

**lampe-claire — à surveiller.** shader : +2 lecture(s) de texture (uniforme lampe_claire)
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)
  - programme 193.shader_test (uniforme lampe_claire plié), branche d'uniforme (apparié à le même, uniforme à 0, contenu à 1.00) : 1691 instructions, 0 lectures, 0 boucles ; Δ +156 / +2 / +0 ; code propre : uniforme lampe_claire
  - programme 160.shader_test (uniforme lampe_claire plié), branche d'uniforme (apparié à le même, uniforme à 0, contenu à 1.00) : 3839 instructions, 0 lectures, 0 boucles ; Δ +69 / +0 / +0 ; code propre : uniforme lampe_claire
  - programme 187.shader_test (uniforme lampe_claire plié), branche d'uniforme (apparié à le même, uniforme à 0, contenu à 1.00) : 3 instructions, 0 lectures, 0 boucles ; Δ +0 / +0 / +0 ; code propre : uniforme lampe_claire

**masque-V5 — lourde.** shader neuf : 3486 instructions, 23 lectures, 7 boucles (m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE) ; shader neuf : 3351 instructions, 23 lectures, 7 boucles (m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE) ; shader neuf : 1472 instructions, 17 lectures, 1 boucles (m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE) ; shader neuf : 115 instructions, 1 lectures (m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE ; le plus lourd déjà à l'écran : 3846, 51)
  - le jeu dit : + [fumée masque] allumé — variante FUMEE_MASQUE posée (#define FUMEE_MASQUE dans son code) ; point noir de l'écran #D : écrit sous #/# → noir (rampes du #-#-# : # → # # → #) ; usure recopiée (#define USURE_ESSAI, comme le sol) ; + [fumée masque] forme : juge ajusté, lumière d'abord, pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR, MASQUE_LUMIERE, MASQUE_AJUSTE) ; − [fumée masque] éteint (le défaut depuis le #-#-# ; --fumee-masque l'allume) — le shader des volumes d'avant
  - programme 298.shader_test, neuf (apparié à 145.shader_test, contenu à 0.79) : 3486 instructions, 23 lectures, 7 boucles ; Δ +3486 / +23 / +7 ; code propre : m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE
  - programme 307.shader_test, neuf (apparié à 172.shader_test, contenu à 0.79) : 3486 instructions, 23 lectures, 7 boucles ; Δ +3486 / +23 / +7 ; code propre : m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE
  - programme 295.shader_test, neuf (apparié à 142.shader_test, contenu à 0.79) : 3486 instructions, 23 lectures, 7 boucles ; Δ +3486 / +23 / +7 ; code propre : m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE
  - programme 301.shader_test, neuf (apparié à 148.shader_test, contenu à 0.79) : 3351 instructions, 23 lectures, 7 boucles ; Δ +3351 / +23 / +7 ; code propre : m_BORNE_MARGE, m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE

**calib-masque-bande — lourde.** shader neuf : 12514 instructions, 98 lectures, 15 boucles (m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE, m_a0) ; shader neuf : 11161 instructions, 82 lectures, 14 boucles (m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE, m_a0)
  - le jeu dit : + [fumée masque] allumé — variante FUMEE_MASQUE posée (#define FUMEE_MASQUE dans son code) ; point noir de l'écran #D : écrit sous #/# → noir (rampes du #-#-# : # → # # → #) ; usure recopiée (#define USURE_ESSAI, comme le sol) ; + [fumée masque] forme : celle de Gadgets ; − [fumée masque] éteint (le défaut depuis le #-#-# ; --fumee-masque l'allume) — le shader des volumes d'avant
  - programme 298.shader_test, neuf (apparié à 145.shader_test, contenu à 0.81) : 12514 instructions, 98 lectures, 15 boucles ; Δ +12514 / +98 / +15 ; code propre : m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE, m_a0
  - programme 307.shader_test, neuf (apparié à 172.shader_test, contenu à 0.81) : 12514 instructions, 98 lectures, 15 boucles ; Δ +12514 / +98 / +15 ; code propre : m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE, m_a0
  - programme 295.shader_test, neuf (apparié à 142.shader_test, contenu à 0.81) : 12514 instructions, 98 lectures, 15 boucles ; Δ +12514 / +98 / +15 ; code propre : m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE, m_a0
  - programme 301.shader_test, neuf (apparié à 148.shader_test, contenu à 0.81) : 11161 instructions, 82 lectures, 14 boucles ; Δ +11161 / +82 / +14 ; code propre : m_POINT_NOIR_ECRIT, m_SOL_COUTURE_PX, m_SOL_HAUSSE_MAX, m_TAILLE_MATIERE, m_USURE_SOL_PLUS_SOMBRE, m_a0

**calib-corps-detaille — à surveiller.** +12.0 appels en carte/unique (bruit ±3) ; +24.5 appels en carte/scinde (bruit ±7) ; shader des corps : +1 boucle(s), +226 instructions (m_DETAIL_MARBRE, m_DETAIL_PORE, m_a_p, m_cellule, m_detail, m_detail_cuir ; le détail des corps, +1 boucle, tient à 0,976)
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)
  - programme 208.shader_test, modifié (apparié à 205.shader_test, contenu à 1.00) : 1699 instructions, 2 lectures, 1 boucles ; Δ +226 / +0 / +1 ; code propre : m_DETAIL_MARBRE, m_DETAIL_PORE, m_a_p, m_cellule, m_detail, m_detail_cuir
  - programme 196.shader_test, modifié (apparié à 193.shader_test, contenu à 1.00) : 1699 instructions, 2 lectures, 1 boucles ; Δ +226 / +0 / +1 ; code propre : m_DETAIL_MARBRE, m_DETAIL_PORE, m_a_p, m_cellule, m_detail, m_detail_cuir
  - programme 199.shader_test, modifié (apparié à 196.shader_test, contenu à 1.00) : 1699 instructions, 2 lectures, 1 boucles ; Δ +226 / +0 / +1 ; code propre : m_DETAIL_MARBRE, m_DETAIL_PORE, m_a_p, m_cellule, m_detail, m_detail_cuir
  - programme 202.shader_test, modifié (apparié à 199.shader_test, contenu à 1.00) : 76 instructions, 0 lectures, 0 boucles ; Δ +40 / +0 / +0 ; code propre : m_DETAIL_MARBRE, m_DETAIL_PORE, m_a_p, m_cellule, m_detail, m_detail_cuir

**calib-rouge-long — neutre.** rien au-delà du bruit, aucun programme de shader nouveau.
  - le jeu dit : rien de différent (aucune ligne d'état ne distingue ce lancement de la référence : le drapeau ne s'annonce pas)

**Témoin** (la référence relancée) : Δ appels carte/unique +0.5, carte/scinde +1, pompe/unique -0.5, pompe/scinde +5.2 ; programmes nouveaux 0 ; part de l'écran 0.08 % au plus — c'est le bruit.
