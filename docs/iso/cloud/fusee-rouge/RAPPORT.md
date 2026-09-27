# Le rouge de la fusée contre celui de son illustration — essai `--fusee-rouge-sang` (session cloud « fusée-rouge »)

*27/09/2026, heure de Paris. Branche `claude/cloud-fusee-rouge`, base `origin/claude/cloud-fusee` (85ce792).*

**État : EN COURS — plan posé à 02:40.**

## Le plan

1. **Lire d'abord, écrire ensuite** : d'où vient la couleur de la lumière à chaque âge
   (`FuseeModele.temperature_a` → `fusee.gd::_appliquer_age` : `COULEUR_DETRESSE.lerp(Charte.AMBRE, température)`
   posée sur un `PointLight2D`), et ce que le jeu en lit :
   - capteur du corps **adverse** (`capteur_adverse.gdshader`) : `max(R, G, B) × énergie` — le **canal maximal**, aveugle
     à la teinte ;
   - capteur de **son propre** corps (`capteur_local.gdshader`) : la couleur canal par canal, puis `pate_luminance`
     (Rec. 709) dans `corps_iso.gdshader` — la **luminance** ;
   - le seuil commun des dix classes (Q32, 0,10) : un niveau de **luminance** (`niveau = pate_luminance(fiche × capteur)`),
     et le banc d'équité le calcule en luminance de la couleur × énergie × masque ;
   - l'éblouissement : l'**énergie** relative seule (`energie_relative()`), aveugle à la couleur.
2. **La règle, fixée AVANT les chiffres** (voir plus bas, section « La règle »).
3. **L'essai** derrière `--fusee-rouge-sang`, éteint par défaut : une seule constante de couleur au plein feu (la braise
   garde l'ambre, le raccord glisse de la nouvelle couleur vers l'ambre), calculée pour garder le canal maximal et la
   luminance, et pousser le bleu du sol au-dessus de son vert.
4. **Une garde headless** (`tools/test_fusee_rouge_sang.gd`) : drapeau éteint = couleur identique au bit ; allumé = la règle
   (canal max, luminance, énergie) à chaque âge ; ajoutée à `run_suites.sh`.
5. **La planche par âges** (plan `loupe-fusee-ages`) : défaut, `--fusee-rouge-sang`, `--fusee-rouge-long`, les deux
   ensemble, à côté de l'illustration, avec teinte / saturation / luminance du sol sous chaque image ; le noir absolu
   torches éteintes en trois prises A, B, A'.
6. La suite complète verte ; le rapport, cinq lignes pour Adrien en tête.

## La règle (fixée avant toute mesure)

Une couleur n'est une solution que si, **à chaque âge et à chaque distance** :
- (a) la lecture par les **capteurs de corps** (adverse : canal max × énergie ; local : luminance) et par le **seuil de Q32**
  (luminance × énergie × masque) ne bouge pas de plus de **1 %** ;
- (b) l'**éblouissement** est le même (il ne lit que l'énergie : l'énergie ne doit pas bouger du tout) ;
- (c) la **luminance du sol éclairé** mesurée à l'image ne bouge pas de plus de **±3 %** ;
- (d) le **noir absolu** est inchangé (torches éteintes, prises A, B, A' : aucun pixel noir de plus allumé) ;
- (e) la lumière reste **rouge** (règle FU2.1) ; `Protocol.VERSION` reste 18 (la couleur ne touche pas la simulation).
Sinon : pas de solution, dit chiffres à l'appui, et l'essai s'arrête là.
