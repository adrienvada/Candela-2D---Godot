# Contexte — travaux parallèles qui recoupent l'audit d'optimisation (relevé le 2026-10-04 au soir)

## 1. « Audit des lumières de Candela » — session cloud du 2026-10-04 (lecture seule, même commit 52a29c1)

Rapport illustré : https://claude.ai/artifact/4K1qRwJv6YFVae7Vp5TLWr (ses constats O1 à O12). Points qui touchent la PERFORMANCE :

- **Règle du moteur** (`renderer_viewport.cpp`, Godot 4.7) : la carte d'ombre de chaque lumière à ombres dont le rectangle
  touche un viewport est recalculée POUR CHAQUE viewport, sans vérifier qu'un élément la reçoit ; ces passes n'apparaissent
  pas dans le compteur d'appels de dessin.
- Par image : 1 lightmap (monde 2D, 1080p) en vue unique, 2 en écran scindé ; capteurs 256² (monde 2D re-rendu) : 2 en duel
  vue unique, 4 en écran scindé, 8-9 en salle de solo ; lumières à ombres toujours allumées : 2 halos en duel (dont 1 sans
  récepteur en vue unique), 7-8 halos + plafonniers en solo.
- Estimations (modèle calé sur 0,09 ms par lampe à 8 occulteurs, mesuré le 2026-09-23, « à lire entre ×0,4 et ×2 ») : ombres
  2D ≈ 1,2-1,5 ms duel vue unique, 2,3-2,9 ms écran scindé ; salle 24×24 à 6 PNJ ≈ 3 ms torches éteintes, jusqu'à 9,5 ms.
- Repère mesuré (ISO6, médiane des appels de dessin) : 199 duel vue de dessus, 235 iso vue unique, 412 écran scindé.
- Pistes d'allègement déjà écrites (« Lot 6 ») : capteurs en `UPDATE_WHEN_VISIBLE` (`presentation_3d.gd:809-810`, `:1199`,
  objets dans `miroirs_iso.gd`) ; `shadow_enabled = false` pour les halos sans récepteur (PNJ, adversaire non regardé ;
  ne PAS passer par `enabled`, lu par `perception_bot_noeud.gd:316`) ; couper l'ombre de `hit_light` après 0,3-0,5 s ;
  occulteurs de murs par contours (`map_geometry.gd`, `trace_contours`, existe mais n'est pas branché : 20-40 % de dessins
  d'ombre en moins) ; dans les grandes salles, étoiles rattachées aux seuls capteurs proches, capteurs lointains une image
  sur deux ; drapeaux de banc `--sans-ombres-2d`, `--sans-capteurs`, `--sans-halos-pnj`.
- Autres faits : `_energie_torche = randf_range(1.5, 2.0)` à CHAQUE pas de physique pendant le recul (`player.gd:1977-1978`),
  tirage sur le générateur global (diverge hôte/client) ; plafond moteur de 15 lumières par item (quadrant de sol de 560 px) ;
  la lumière 3D miroir d'ISO12 est éteinte par défaut (`presentation_3d.gd:263`, `lumiere_3d := false`).
- « Le coût du solo n'a jamais été mesuré » (S5 à S8 : « aucun relevé de cadence »).

## 2. Chantier OMBRES (OM) — EN COURS, session cloud « Candela Chantier OMBRES — éclairage »

Nom inter-session `candela-2d-godot-d4`, branche `claude/determined-pasteur-mtrws1` (2 commits au-dessus de main :
`492311a` inscription, `35ba721` OM0). Copie de SA ROADMAP : `audit/ROADMAP_branche_OMBRES.md`, section « Chantier — les
ombres et la lumière du solo (OM) » à partir de la ligne 33869.

| Lot | Objet | État |
|---|---|---|
| OM0 | banc des ombres (planche, scintillement, sonde de lightmap, gardes) | ✅ fait le 2026-10-04 |
| OM1 | culling de l'étoile + brouillage par source | attend Q81 |
| OM2 | ombre à la forme du corps voxel | attend Q82 |
| OM3 | image stable : enveloppe de tir déterministe ; pâte D ; respiration ; **PCF5 + atlas d'ombres 4096 (Q85) — un SURCOÛT à mesurer** | attend Q83-Q85 |
| OM4 | règles pour N corps (couches PNJ, lumières posées, flash, hit_light, ground_flash, mort, posture) | attend Q86-Q87 |
| OM5 | plafonniers | attend Q88 |
| **OM6** | **Alléger : capteurs, halos sans récepteur, lumière de coup, murs par contours, banc de cadence solo** | à faire, sans décision |
| OM7 | ombre des corps calculée dans le shader du sol | plus tard |

**Conséquence pour l'audit** : tout constat qui recoupe OM6 (ou OM3/OM4) est **CONNU-OUVERT, titulaire chantier OMBRES** ;
il se cite, il ne se re-propose pas comme nouveau, et l'audit n'y touche pas (fichiers d'une autre session). L'audit peut en
revanche apporter ce qui manque à OM6 : une mesure, un chiffre, un risque non vu.
