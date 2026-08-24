#!/usr/bin/env bash
# Aperçu des matières — comparer les tuiles peintes à celles d'aujourd'hui,
# dans l'arène, à la torche. Voir l'en-tête de `tools/apercu_matiere.gd`.
#
#   F  variante de sol        M  variante de mur
#   T  éteindre la torche     Z  zoom jeu / zoom 1:1
#   R  rotations de tuiles    flèches déplacer · souris viser · Échap quitter
#
# Une tuile fait 35 pixels. **Z est la touche qui compte** : à zoom jeu on juge
# l'ambiance, à 1:1 on voit ce qui a survécu à la réduction — et c'est là que se
# décide si une planche valait la peine.
#
# ⚠️ **T répond à une question de conception, pas de goût.** La couche des murs
# est en fondu additif. Torche éteinte, les murs doivent DISPARAÎTRE : s'ils
# restent visibles, on lit le plan de la carte sans rien allumer, et la promesse
# du jeu — « la seule information est la lumière » — tombe.
#
set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [ ! -x "$GODOT" ]; then
  echo "Godot introuvable : $GODOT" >&2
  echo "Renseigner GODOT=/chemin/vers/Godot pour surcharger." >&2
  exit 1
fi

# ⚠️ Le lanceur s'ancre sur SA PROPRE position — ce qui défait le piège du `.`,
# mais en ouvre un autre depuis qu'il existe des worktrees : appelé depuis une
# copie du dépôt, il prévisualise CETTE copie. Le 2026-08-24, le banc a été
# lancé depuis `.claude/worktrees/DA4-interface-habillee` ; les touches ajoutées
# une heure plus tôt dans l'arbre principal n'y étaient pas, et le seul
# diagnostic possible depuis l'écran était « les touches ne marchent pas ».
# Deux copies d'un outil ne se distinguent par rien à l'exécution : on le dit.
case "$RACINE" in
  */.claude/worktrees/*)
    echo "⚠️  Ce banc est celui du WORKTREE : $RACINE" >&2
    echo "    Il ne contient que ce qui a été commité sur SA branche." >&2
    echo "    Pour l'arbre principal, appeler le script par son chemin absolu." >&2
    echo >&2
    ;;
esac

exec "$GODOT" --path "$RACINE" res://tools/apercu_matiere.tscn -- "$@"
