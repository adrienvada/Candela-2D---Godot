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
#   ./tools/run_visuel.sh            les trois
#   ./tools/run_visuel.sh --planche  les images seulement
#   ./tools/run_visuel.sh --controles  les trois propriétés seulement
#   ./tools/run_visuel.sh --eblouissement  la planche de l'éblouissement seule
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
fail=0
quoi="${1:-}"

# Lancer un outil visuel et RELIRE SA SORTIE.
#
# Le code de sortie ne suffit pas ici, et c'est le piège qui a coûté un
# passage complet le 2026-08-24 : une erreur d'analyse fait tourner la scène
# **sans script**, donc sans rien mesurer, sans rien écrire — et elle sort
# proprement en 0. C'est la forme la plus silencieuse de la panne déjà
# consignée pour `run_suites.sh`, qui grep `SCRIPT ERROR` pour la même raison.
#
# `tee` plutôt qu'un tuyau nu : on veut voir défiler l'outil ET pouvoir relire
# ce qu'il a dit. Un tuyau simple avalerait en plus le code de sortie, piège
# déjà payé le 2026-08-18 et consigné au README.
lancer() {
  local journal
  journal="$(mktemp)"
  "$GODOT" --path . "$1" 2>&1 | tee "$journal"
  local code=${PIPESTATUS[0]}
  if grep -qE 'Parse Error|Failed to load script' "$journal"; then
    echo "--- $1 : erreur d'ANALYSE — la scène a tourné sans script, rien n'a été mesuré ---"
    grep -E 'Parse Error|Failed to load script' "$journal" | head -4
    code=1
  fi
  rm -f "$journal"
  return $code
}

if [ "$quoi" != "--controles" ] && [ "$quoi" != "--eblouissement" ]; then
  echo "--- Planche de contact (une image par état, elle n'affirme rien) ---"
  lancer res://tools/planche_contact.tscn
  [ $? -ne 0 ] && fail=1
fi

if [ "$quoi" != "--planche" ] && [ "$quoi" != "--eblouissement" ]; then
  echo "--- Ce qui se voit (trois propriétés) ---"
  lancer res://tools/test_rendu.tscn
  [ $? -ne 0 ] && fail=1
fi

# L'éblouissement : des images ET des mesures, parce que la mécanique n'a
# jamais été comparée à ce que l'écran montre. Elle sort en 1 sur deux
# propriétés d'ÉQUITÉ seulement — le voile de J2 qui déborderait chez J1, et un
# blanc qui survivrait à la fin d'une manche. Tout le reste est du jugement,
# qu'elle imprime sans trancher.
if [ "$quoi" != "--planche" ] && [ "$quoi" != "--controles" ]; then
  echo "--- Éblouissement : le voile, les temps, le flash, la cohérence ---"
  lancer res://tools/planche_eblouissement.tscn
  [ $? -ne 0 ] && fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "--- au moins un outil visuel a échoué ---"
  exit 1
fi
echo "--- les outils visuels sont passés ---"
