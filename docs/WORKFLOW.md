# Workflow — dérouler les Phases 5 à 7 en parallèle

> Ce document dit **comment** le travail est découpé et orchestré.
> `docs/ROADMAP.md` dit *quoi* faire et *pourquoi*.
> `docs/JOURNAL_SESSIONS.md` dit *qui tient quoi en ce moment*.

## Le blocage qu'il fallait lever d'abord

Toute l'interface vivait dans `ui.gd` : 3 000 lignes construites en code, un seul
fichier. Le découpage réel du travail entre agents suit les **fichiers**, jamais
les sujets — deux agents sur deux écrans différents du même fichier produisent un
conflit à chaque poussée.

Tant que les écrans vivaient dans `ui.gd`, **la parallélisation était impossible
par construction**, quel que soit le plan. Ce n'était pas un problème
d'organisation : c'était un problème d'architecture.

`hub_screen.gd` (`class_name HubScreen`) le lève : un écran est désormais un
fichier autonome, qui ne connaît ni `ui.gd` ni le hub, et qui demande la
navigation par signal au lieu de la décider. N agents peuvent construire N écrans
sans se croiser ; le hub les assemble.

C'est la seule raison de ce découpage. Qu'il donne aussi une meilleure
architecture est un effet secondaire, pas le motif.

## Règles d'orchestration

### 1. Tout agent tourne dans un worktree isolé

Sans exception, et cette règle a été payée : un agent lancé dans l'arbre
principal a vu son travail **en cours** avalé par un `git add -A` de la session
principale. Un worktree lui donne son propre arbre et son propre `.godot/`, ce
qui évite aussi les courses à l'import de Godot entre deux instances.

### 2. Un agent ne commite jamais

Il laisse ses modifications dans l'arbre. La session principale relit, valide
contre les suites, et commite — c'est le seul endroit où la cohérence de
l'ensemble est vérifiable.

### 3. Un agent reçoit une liste de fichiers, pas un sujet

En clair : ce qu'il peut écrire, et ce qu'il lui est **interdit** de toucher même
pour une amélioration évidente. Un agent qui repère un problème hors périmètre le
signale dans son rapport ; il ne le corrige pas.

### 4. Les fichiers partagés ne sont jamais donnés à un agent

`docs/ROADMAP.md`, `README.md`, `CLAUDE.md`, `project.godot`,
`.github/workflows/tests.yml` : la session principale seule y écrit. Ce sont les
fichiers que tout le monde voudrait modifier, donc ceux qui conflictent toujours.

### 5. Chaque livraison prouve qu'elle sait échouer

Une suite de tests qui ne peut pas rendre 1 ne prouve rien. Le dépôt a déjà connu
une suite annonçant « tous les tests passent » sans avoir rien exécuté (voir
« Pièges connus »). Chaque agent casse volontairement une assertion, vérifie le
code de sortie, et remet en état.

## Les vagues

Une vague groupe des travaux **sans dépendance entre eux et sans fichier
commun**. On n'ouvre la suivante qu'une fois la précédente intégrée : c'est ce
qui garde les fusions petites.

### Vague 1 — les fondations sans interface ⏳

Trois travaux qui ne touchent à aucun écran, donc lançables immédiatement.

| # | Objet | Fichiers | Alimente |
|---|---|---|---|
| 1a | Échelle des rangs, fonction pure | `supabase/functions/_shared/elo{,_test}.ts` | Phase 6 |
| 1b | Volumes audio persistés | `settings_manager.gd`, sa suite | Phase 5 étape 4 |
| 1c | Lecture du journal de matchs | `match_history_view.gd`, sa suite | Phase 5 étape 5 |

### Vague 2 — les écrans, un fichier chacun

Ouverte par `hub_screen.gd`. Chaque écran est indépendant des autres : ils ne se
connaissent pas, ils émettent des signaux.

| # | Écran | Fichier | Dépend de |
|---|---|---|---|
| 2a | Options — audio | `screen_audio.gd` | 1b |
| 2b | Options — calibration de luminosité | `screen_calibration.gd` | — |
| 2c | Classement (top 10 et rang) | `screen_leaderboard.gd` | — |
| 2d | Historique des matchs | `screen_history.gd` | 1c |
| 2e | Profil et pseudo | `screen_profile.gd` | — |

### Vague 3 — l'assemblage (session principale, séquentiel)

Non parallélisable, et c'est assumé : tout converge dans `ui.gd`. Migration de
l'existant sous le hub (Phase 5 étape 3), branchement des écrans de la vague 2,
bascule de l'ancien menu vers le nouveau.

### Vague 4 — le classement de bout en bout

Exposition du rang côté serveur, déploiement, vérification en production avec des
identités éphémères, purge des données d'essai.

### Vague 5 — le déblocage d'armes

Bloqué sur un fichier : `game_state.gd` appartient à la session « game feel »
jusqu'à passation. La partie interface (armes verrouillées visibles et grisées,
et la raison affichée) est indépendante et peut partir avant.

## Ce qui ne sera jamais fait par un agent

À dire franchement plutôt qu'à laisser espérer :

- **Les 76 fichiers d'assets** — aucun agent ne produit un son. Liste complète
  dans l'onglet ASSETS du suivi.
- **Les décisions D1 à D7** — elles changent l'information disponible en jeu.
- **Le test à deux machines (H1)** et **l'adhésion Apple (H4)**.
- **Le playtest de ressenti** — tranché une fois, à retrancher après chaque
  changement de game feel.
