#!/usr/bin/env bash
# LE PHOTOGRAPHE — sort les images du jeu pour en parler dehors.
#
# Captures de jeu, menus, illustrations, phases de duel, écrans de fin : un
# dossier d'images nommées, un manifeste qui dit ce que montre chacune, et une
# planche HTML qu'on ouvre d'un double-clic.
#
# ⚠️ **Il exige une VRAIE fenêtre.** Rien n'est rastérisé en `--headless` et
# `RenderingServer.frame_post_draw` n'y est jamais émis : l'attendre suspendrait
# le processus pour toujours. C'est la même contrainte que `run_visuel.sh`, et
# la raison pour laquelle ces outils ne rejoindront jamais `run_suites.sh`.
#
# ⚠️ **Garder la fenêtre au premier plan pendant la séance.** macOS bride le
# rendu d'une fenêtre passée derrière, au point que le signal de fin de rendu
# cesse d'être émis. L'outil remet la fenêtre devant avant chaque prise et
# retente une fois, mais un terminal qui reprend le focus toutes les secondes
# aura raison de lui — il le DIT alors (« prise perdue ») plutôt que d'écrire du
# noir.
#
#   ./tools/run_photos.sh                       tout, en 1920×1080
#   ./tools/run_photos.sh --liste               le catalogue, sans ouvrir le jeu
#   ./tools/run_photos.sh --famille=jeu,fins    deux familles
#   ./tools/run_photos.sh --plan=gel-fatal      un seul plan
#   ./tools/run_photos.sh --taille=3840x2160    en 4K (si l'écran le permet)
#   ./tools/run_photos.sh --decoupes            + les recadrages carré et 9:16
#   ./tools/run_photos.sh --sans-hud            le HUD retiré des plans `ecran`
#   ./tools/run_photos.sh --zoom=1.6            cadrage serré (déclaré au manifeste)
#   ./tools/run_photos.sh --sortie=user://presse  ailleurs que dans `user://photos`
#
# Les images sortent dans `user://photos/`, dont le chemin réel est imprimé à la
# fin. C'est `planche.html` qu'on ouvre, pas le dossier.
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

# `--liste` n'a besoin d'aucune fenêtre : on l'exécute en headless pour qu'il
# soit instantané et utilisable dans un terminal distant.
#
# Deux branches plutôt qu'un tableau d'arguments : sous `set -u`, le bash 3.2
# livré par Apple refuse `"${tableau[@]}"` quand le tableau est VIDE — et le
# script mourait sur cette ligne avant d'avoir lancé quoi que ce soit.
sans_fenetre=0
for a in "$@"; do
  if [ "$a" = "--liste" ]; then sans_fenetre=1; fi
done

journal="$(mktemp)"
if [ "$sans_fenetre" = "1" ]; then
  "$GODOT" --headless --path . res://tools/photographe.tscn -- "$@" 2>&1 | tee "$journal"
else
  "$GODOT" --path . res://tools/photographe.tscn -- "$@" 2>&1 | tee "$journal"
fi
code=${PIPESTATUS[0]}

# Le code de sortie ne suffit pas, et c'est le piège qui a coûté un passage
# complet le 2026-08-24 : une erreur d'analyse fait tourner la scène **sans
# script**, donc sans rien photographier, et elle sort proprement en 0.
if grep -qE 'Parse Error|Failed to load script' "$journal"; then
  echo "--- erreur d'ANALYSE : la scène a tourné sans script, rien n'a été pris ---"
  grep -E 'Parse Error|Failed to load script' "$journal" | head -4
  code=1
fi
rm -f "$journal"
exit $code
