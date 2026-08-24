#!/usr/bin/env bash
# Aperçu des lumières — comparer les masques dans le noir, sur des murs, avec
# les ombres. Voir l'en-tête de `tools/apercu_torche.gd` pour ce qu'il montre.
#
# Quatre familles s'y comparent, chacune sur sa touche, chacune commençant par
# le DÉGRADÉ D'AUJOURD'HUI — sans lui on jugerait dans le vide :
#
#   H  rétrodiffusion (le halo de corps)     A  lueur ambiante
#   E  éclat ponctuel (balles, impacts)      F  flash de bouche, 3 frames
#   T  éteindre la torche — indispensable : à 2,5 d'énergie elle noie des
#      lueurs qui valent 0,6, et on ne juge plus rien.
#   Espace  arme suivante   ·   flèches  se déplacer   ·   souris  viser
#
# **Pourquoi ce lanceur existe.** La commande directe est
# `godot --path . res://tools/apercu_torche.tscn`, et le `.` est un piège : il
# désigne le dossier COURANT, pas celui du projet. Lancée depuis ailleurs — un
# terminal ouvert sur la maison, un bouton d'exécution dont on ne choisit pas le
# répertoire —, Godot ne trouve aucun `project.godot` et **ouvre le gestionnaire
# de projets** au lieu de la scène. Rien n'échoue, rien ne le dit : on croit
# avoir mal compris l'outil alors qu'on était au mauvais endroit.
#
# Ce script résout la racine depuis SA PROPRE position, donc il marche appelé de
# n'importe où, y compris par un chemin absolu.
#
#   tools/run_apercu.sh              la fenêtre, à piloter
#   tools/run_apercu.sh --captures   les images de torche, puis il sort
#
# ⚠️ `--captures` ne photographie QUE les cookies de torche, pas les halos :
# une lueur se juge en bougeant, à côté d'un mur qu'elle éclaire de biais.
#
# ⚠️ En mode `--captures`, garder la fenêtre AU PREMIER PLAN : macOS bride une
# fenêtre en arrière-plan, `frame_post_draw` cesse d'arriver et les images
# sortent vides.
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

exec "$GODOT" --path "$RACINE" res://tools/apercu_torche.tscn -- "$@"
