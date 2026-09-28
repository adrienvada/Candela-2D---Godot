# Mesurer la cadence par version — rapport de la session cloud « cadence-version »

> Branche `claude/cloud-cadence-version`, partie de `origin/integration-iso14` (`a30a407`), 2026-09-28.
> **État : en cours — premier commit, le plan.** Rien ne change dans le jeu.

## La demande

Adrien, le 28/09 vers 06:35 : « Mesurons par version, plus par nouveauté. Trions avec le cloud avant le Mac. Faisons des
séries plus courtes. » Le Mac ne fait tourner qu'un jeu à la fois ; une série par nouveauté (1 h 20 à 1 h 45) en a fait le
goulot du chantier.

## Le plan (écrit avant de coder)

1. **La règle d'abord**, dans `docs/iso/cadence_par_version.md` : ce qu'est une version (une tête intégrée avec ses
   défauts ; un essai éteint n'en fait pas partie), quand on la mesure (quand ses défauts changent), la référence (la
   dernière version mesurée), le tri du cloud, la série courte, et la recherche de la coupable quand une version échoue
   (on retire la nouveauté que le tri classe la plus lourde, par une autre série courte). Barre de la règle 278 gardée.
2. **Le tri du cloud**, `tools/cadence/tri_cloud.sh` (+ Python) : pour deux têtes A et B, chacune dans un worktree à moi,
   l'outil de la session « Budget » (appels, primitives, passes ; six cartes à 45° B, vue unique et écran scindé, pompe sous
   une fusée), le diff des shaders entre A et B (lignes, lectures de texture, boucles ; le GLSL capturé sous Mesa si
   possible), la part de l'écran qui change (captures A contre B). Classement « neutre / à surveiller / lourde » avec des
   seuils tirés des mesures du Mac déjà connues (corps détaillés +12 appels → 0,976 ; bande du masque → 0,838 ; rouge long
   → 1,024). Appliqué à (a) `244cb88` contre `a30a407`, (b) chaque essai candidat (Q37, Q39, Q40, V5) contre le même état
   sans lui, sur `1dc5ec8` (écart 11, où tous les essais sont fusionnés).
3. **La série courte**, `tools/cadence/serie_version.sh <tête A> <tête B> <sortie>` : deux bras, deux worktrees importés
   avant, la scène de la règle 278, un miroir court avec chauffe non comptée, la porte de l'ordre 432 reprise de
   `serie_mac_2.sh`, une règle de prolongation écrite d'avance, la preuve de la tête dans chaque prise. 30 minutes au plus.
   Essais à blanc et sous Xvfb.
4. **La fiche pour le Mac**, en tête de ce rapport, et la première série à faire.

Reprise du plan « série-essais » (`c0e98a7`, arrêté) : le lanceur calqué sur `serie_mac_2.sh`, les deux essais à blanc, la
preuve par ligne d'état. Abandonné : une série par essai et les douze bras.
