# Tri du cloud — référence « calib-sans-usure »

Comptes : écart à la référence, médiane des six cartes (vue unique U, écran scindé S) et moyenne de 120 images au pompe sous une fusée (PU, PS). Bruit retenu : carte/unique ±3, carte/scinde ±7, pompe/unique ±3, pompe/scinde ±20. Aucun temps : le cloud ne mesure pas la cadence.

| nouveauté | classe | Δ appels U / S | Δ appels PU / PS | Δ primitives U (%) | vues, copies, ombres | programmes nouveaux | pire programme : Δ instr. / lect. / boucles | part de l'écran (max, cartes) |
|---|---|---|---|---|---|---|---|---|
| ref | **lourde** | -1 / -2 | +0.6 / -10.1 | -0.0 | aucune | 12 | +344 / +0 / +1 | 0.23 % |

**ref — lourde.** shader : +1 boucle(s) (m_USURE_IMPACTS_MAX, m_USURE_RESTE, m_USURE_SEUILS, m_USURE_TRAVEE_PX, m_aureole, m_bas) ; shader : +1 lecture(s) de texture (m_USURE_IMPACTS_MAX, m_USURE_RESTE, m_USURE_SEUILS, m_USURE_TRAVEE_PX, m_cellule, m_centre)
  - le jeu dit : + [audio]   par famille : footstep_a=# footstep_b=# shoot=# breath_hit=# hit_center=# shell=# ; + [audio] dernier son #D : res://assets/audio/sfx/shell_#wav ; + [usure] allumée — variante USURE_ESSAI posée (#define USURE_ESSAI dans son code) ; − [audio]   par famille : footstep_a=# footstep_b=# shoot=# breath_hit=# hit_center=# shell=# ambience=# ; − [audio] dernier son #D : res://assets/audio/sfx/ambience_#wav
  - programme 145.shader_test, modifié (apparié à 163.shader_test, contenu à 1.00) : 3846 instructions, 51 lectures, 1 boucles ; Δ +344 / +0 / +1 ; code propre : m_USURE_IMPACTS_MAX, m_USURE_RESTE, m_USURE_SEUILS, m_USURE_TRAVEE_PX, m_aureole, m_bas
  - programme 172.shader_test, modifié (apparié à 190.shader_test, contenu à 1.00) : 3846 instructions, 51 lectures, 1 boucles ; Δ +344 / +0 / +1 ; code propre : m_USURE_IMPACTS_MAX, m_USURE_RESTE, m_USURE_SEUILS, m_USURE_TRAVEE_PX, m_aureole, m_bas
  - programme 142.shader_test, modifié (apparié à 160.shader_test, contenu à 1.00) : 3846 instructions, 51 lectures, 1 boucles ; Δ +344 / +0 / +1 ; code propre : m_USURE_IMPACTS_MAX, m_USURE_RESTE, m_USURE_SEUILS, m_USURE_TRAVEE_PX, m_aureole, m_bas
  - programme 160.shader_test, modifié (apparié à 178.shader_test, contenu à 1.00) : 1705 instructions, 18 lectures, 1 boucles ; Δ +179 / +1 / +0 ; code propre : m_USURE_IMPACTS_MAX, m_USURE_RESTE, m_USURE_SEUILS, m_USURE_TRAVEE_PX, m_cellule, m_centre

