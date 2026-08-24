#!/usr/bin/env bash
# Les deux outils qui regardent l'ÉCRAN, et pourquoi ils sont hors du lanceur.
#
# `run_suites.sh` tourne en `--headless` : rien n'y est rastérisé,
# `RenderingServer.frame_post_draw` n'y est jamais émis, et l'attendre suspend le
# processus pour toujours. Ces deux-là exigent une vraie fenêtre.
#
# À lancer AVANT UNE LIVRAISON, pas à chaque commit — ils ouvrent une fenêtre et
# durent une vingtaine de secondes chacun.
#
#   ./tools/run_visuel.sh            les deux
#   ./tools/run_visuel.sh --planche  les images seulement
#   ./tools/run_visuel.sh --controles  les trois propriétés seulement
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
fail=0
quoi="${1:-}"

if [ "$quoi" != "--controles" ]; then
  echo "--- Planche de contact (une image par état, elle n'affirme rien) ---"
  "$GODOT" --path . res://tools/planche_contact.tscn
  # Pas de tuyau ici : un tuyau avalerait le code de sortie et le résultat lu
  # serait celui de `tail`. Piège payé le 2026-08-18, consigné au README.
  [ $? -ne 0 ] && fail=1
fi

if [ "$quoi" != "--planche" ]; then
  echo "--- Ce qui se voit (trois propriétés) ---"
  "$GODOT" --path . res://tools/test_rendu.tscn
  [ $? -ne 0 ] && fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "--- au moins un outil visuel a échoué ---"
  exit 1
fi
echo "--- les outils visuels sont passés ---"
