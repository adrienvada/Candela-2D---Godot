# Consignes — vérification contradictoire des constats de l'audit d'optimisation (2026-10-04)

**Ton rôle : contradicteur.** Les constats qu'on te confie viennent d'auditeurs qui ont lu le code en lecture seule et ont
souvent ESTIMÉ des coûts. Ton travail est de chercher à les RÉFUTER. Un constat ne survit que s'il résiste ; un chiffre
ne survit que s'il est justifié. Mieux vaut trois constats solides que dix fragiles : n'hésite pas à rétrograder.

Dossier de travail : `docs/audit_optimisation/`
(appelé `audit/` ci-dessous). Dépôt : `/home/user/Candela-2D---Godot`, commit `52a29c1`.

## À lire d'abord

1. `audit/CONSIGNES_AUDIT.md` — le contexte du jeu et les **règles strictes** (lecture seule, ne lance PAS Godot, pas de
   grep récursif sur `addons/` ni `assets/`, français). Elles s'appliquent à toi.
2. `audit/CONTEXTE_CHANTIERS_EN_COURS.md` — un audit des lumières et le chantier OMBRES (en cours, autre session) couvrent
   déjà une partie du terrain : un constat qui recoupe leur lot OM6 est « DÉJÀ PRIS EN CHARGE ».
3. Le ou les rapports d'audit qui portent tes constats (chemins dans ta mission) : lis le bloc complet de chaque constat.

## Pour chaque constat

1. **Le code** : relis le code cité (`fichier:ligne` ; les numéros peuvent être décalés de quelques lignes, l'extrait doit
   exister). Le code fait-il vraiment ce qui est dit ?
2. **La fréquence** : remonte les appelants jusqu'à la source. Par image rendue ? par tick physique ? par événement ? Sous
   quelles conditions (vue unique, écran scindé, en ligne, entraînement, solo) ? Le chemin est-il actif dans un duel
   standard, ou seulement dans un cas rare ?
3. **Le coût** : l'estimation est-elle plausible ? Raisonne sur ce que fait Godot 4.7 quand tu le sais (par exemple : les
   `add_theme_*_override` notifient `NOTIFICATION_THEME_CHANGED` sans tester l'égalité de la valeur ; un `Label` notifié
   invalide son cache de thème, refait sa taille minimale et se redessine ; une `StyleBox` modifiée émet `changed` vers tous
   les contrôles qui l'utilisent). Quand tu ne sais pas, écris « à mesurer » plutôt que d'inventer. Corrige tout chiffre
   qui ne repose sur rien.
4. **Les invariants** : le correctif proposé casse-t-il quelque chose — équité en ligne, déterminisme des bancs, lisibilité
   de la lumière, routage des RPC, un test existant (`grep` dans `tools/` des tests qui lisent ce code ou son texte source) ?
   Consulte les extraits de la ROADMAP `audit/roadmap/R*.md` (catégories C « pièges » et D « invariants ») et `grep -n` la
   ROADMAP elle-même.
5. **Le statut** : déjà connu, décidé, refusé, ou en cours ailleurs (ROADMAP ; copie de la ROADMAP de la branche OMBRES :
   `audit/ROADMAP_branche_OMBRES.md`) ?
6. **Le verdict** : CONFIRMÉ / CONFIRMÉ AVEC RÉSERVE / RÉFUTÉ / DÉJÀ PRIS EN CHARGE ; sévérité corrigée (CRITIQUE / MAJEUR /
   MINEUR / ANECDOTIQUE) ; le **correctif minimal** recommandé (le plus petit geste qui rapporte l'essentiel) ; et **comment
   le prouver dans le cloud** — Adrien ne mesure plus rien sur son Mac (décision du 2026-09-30) : compteur indépendant du
   matériel (appels de dessin, nœuds, allocations), test headless, temps CPU headless à pas fixe (`--fixed-fps 60`,
   moniteurs `Performance`), ou rapport de cadence sous llvmpipe (`tools/cadence_cloud/`).

Quand plusieurs auditeurs ont trouvé le même défaut, traite-le une seule fois et cite tous leurs identifiants.

## Livrable

1. Écris `audit/V_<ton identifiant>.md` : un bloc par constat (ou groupe de doublons) avec les six points ci-dessus, les
   extraits de code qui fondent le verdict, et les appelants remontés.
2. Ta **réponse finale** : le chemin du fichier, puis UNE ligne par constat :
   `ID(s) | verdict | sévérité corrigée | coût corrigé | justification en une phrase`. Rien d'autre.
