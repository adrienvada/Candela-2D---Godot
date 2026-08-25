#!/usr/bin/env bash
# Cuit les aperçus de mode du cadre de droite — de vraies captures du jeu.
#
# Comme `run_visuel.sh`, il exige une VRAIE fenêtre : rien n'est rastérisé en
# `--headless`, et `RenderingServer.frame_post_draw` n'y est jamais émis.
#
# ⚠️ **Garder la fenêtre au premier plan pendant la vingtaine de secondes.**
# macOS bride le rendu d'une fenêtre passée derrière, et la fabrique rend alors
# zéro image. Elle le DIT plutôt que d'écrire du noir — une fabrique qui écrit
# une image noire est pire qu'une qui n'écrit rien, parce qu'on intègre l'image
# noire sans la regarder — mais autant ne pas la relancer trois fois pour rien.
#
# Les images sortent dans `user://apercus/`. Les REGARDER, puis les copier dans
# `assets/ui/` : ce sont elles que le joueur verra en choisissant son mode.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

journal="$(mktemp)"
"$GODOT" --path . res://tools/fabrique_apercus.tscn 2>&1 | tee "$journal"
code=${PIPESTATUS[0]}
# Le code de sortie ne suffit pas : une erreur d'analyse fait tourner la scène
# SANS SCRIPT, donc sans rien cuire, et sort proprement en 0. Piège déjà payé le
# 2026-08-24 sur les outils visuels.
if grep -qE 'Parse Error|Failed to load script' "$journal"; then
  echo "--- erreur d'ANALYSE : la scène a tourné sans script, rien n'a été cuit ---"
  grep -E 'Parse Error|Failed to load script' "$journal" | head -4
  code=1
fi
rm -f "$journal"
exit $code
