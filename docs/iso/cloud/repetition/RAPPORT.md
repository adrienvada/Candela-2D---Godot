# Répétition du test d'Adrien — session cloud `claude/cloud-repetition`

> **Rapport en cours** (début : 2026-09-27 vers 01:10, heure de Paris). Base :
> `origin/integration-iso14` à `18f5fdc`.

## Plan

1. **Le défaut réel, lu dans le code** (pas dans les documents) : vue iso, lacet
   45° avec J2 en B, zoom ×1,5, murs abîmés, décalage du regard vers la visée,
   masque de la fumée, drapeaux éteints.
2. **Outillage** : Godot 4.7 officiel, import, photographe corrigé pour Xvfb
   (reprise de `claude/cloud-photographe`, commit à part).
3. **Parcours sous Xvfb 1920×1080** : lancement, hub, créer local, choix de
   carte, salon des armes, réglages ; un match local 1v1 sur chacune des six
   cartes livrées, en écran scindé et en vue unique ; entraînement ; une mort et
   sa killcam ; écran de fin ; éditeur (F5) ; F3 ; F6.
4. **En ligne en ENet**, deux processus sur la même machine
   (`tools/test_online_match.tscn`) — jamais EOS.
5. **Relevé de toute la console** (erreurs, avertissements, shaders, RPC jetés,
   fuites à la sortie), commande exacte de reproduction, classement
   bloquant / gênant / cosmétique, fichier et ligne probables, correctif proposé.
   Rien n'est corrigé dans le jeu.
6. **Suite complète** (`tools/run_suites.sh`) sur la base, pour distinguer ce
   que la suite voit de ce qu'elle ne voit pas.
7. Avant de finir : `git fetch origin integration-iso14` ; si la tête a bougé,
   refaire la répétition dessus et comparer.

Scripts de pilotage : `tools/cloud_repetition/` (fichiers neufs seulement).

## Premier constat

Le « protocole en six étapes » d'Adrien n'est **pas écrit** sur `18f5fdc` :
aucune occurrence dans `docs/ROADMAP.md` (section iso comprise), ni dans
`docs/iso/`, ni sur `claude/reveil`. La répétition suit donc la liste de la
tâche ci-dessus, qui le recouvre vraisemblablement.
