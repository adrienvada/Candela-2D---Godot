#!/usr/bin/env bash
# Q15 — refait toutes les images et les mesures de la planche du zoom (session cloud zoom-2).
# Un lancement par couple (zoom, carte) : voir l'en-tête de tools/planche_zoom.gd.
# Cloud : GODOT=/usr/local/bin/godot, sous xvfb-run. Sur le Mac : sans xvfb-run (XVFB="").
set -uo pipefail
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
SORTIE="${SORTIE:-$PWD/docs/iso/cloud/zoom/images}"
TAILLE="${TAILLE:-1920x1080}"
XVFB="${XVFB-xvfb-run -a -s \"-screen 0 ${TAILLE}x24\"}"
ZOOMS="${ZOOMS:-1.25 1.5 1.75 2.0}"
CARTES="${CARTES:-map_001_le_cloitre map_003_la_croisee}"
mkdir -p "$SORTIE"
for z in $ZOOMS; do
  for c in $CARTES; do
    echo "--- zoom $z, carte $c"
    eval $XVFB "$GODOT" --fixed-fps 60 --path . res://tools/planche_zoom.tscn -- \
      --zoom="$z" --taille="$TAILLE" --sortie="$SORTIE" --cartes="res://assets/maps/$c.json" 2>&1 \
      | grep -E "zoom posé|→|·|✗|mesures|SCRIPT ERROR|Parse Error"
  done
done
