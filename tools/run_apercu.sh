#!/usr/bin/env bash
# Aperçu de torche — comparer les cookies dans le noir, sur des murs, avec les
# ombres. Voir l'en-tête de `tools/apercu_torche.gd` pour ce qu'il montre.
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
#   tools/run_apercu.sh --captures   les seize images, puis il sort
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

exec "$GODOT" --path "$RACINE" res://tools/apercu_torche.tscn -- "$@"
