#!/usr/bin/env bash
# Lance toutes les suites headless et échoue si l'une d'elles rate — OU si Godot
# a émis une erreur de script.
#
# Pourquoi ce second contrôle. Une `SCRIPT ERROR` n'échoue PAS un test GDScript :
# seul un `_check` incrémente le compteur. Une suite qui appelle une fonction
# supprimée continue donc d'annoncer « tous les tests passent » avec le code 0.
# Le cas s'est produit pour de vrai le 2026-08-17, sur la suite de la pause,
# après la disparition de la barre d'onglets. Grepper la sortie est le seul
# garde-fou qui ne dépende pas de la vigilance de l'auteur du test.
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SUITES=(test_map_codec test_map_geometry test_arena_build test_editor_tools
        test_match_format test_pause_menu test_menu_hub test_audio_settings
        test_match_history_view test_effect_policy test_screen_leaderboard
        test_screen_profile test_screen_historique test_arsenal test_matchmaking test_screen_matchmaking test_screen_audio
        test_screen_calibration test_match_banner test_carte_partagee test_rejeu_journal test_pseudo test_protocole
        test_vitrine_menus test_audit_menus test_pool_sfx test_ecran_de_fin test_serie_de_session test_vision)

fail=0
run() {
  local nom="$1"; shift
  local sortie
  sortie="$("$GODOT" --headless --path . "$@" 2>&1)"
  local code=$?
  local erreurs
  erreurs="$(printf '%s\n' "$sortie" | grep -c 'SCRIPT ERROR' || true)"
  if [ "$code" -ne 0 ]; then
    printf '%-28s ÉCHEC (code %d)\n' "$nom" "$code"; fail=1
  elif [ "$erreurs" -ne 0 ]; then
    printf '%-28s ÉCHEC — %s erreur(s) de script malgré un code 0\n' "$nom" "$erreurs"
    printf '%s\n' "$sortie" | grep -A2 'SCRIPT ERROR' | head -12
    fail=1
  else
    printf '%-28s OK\n' "$nom"
  fi
}

for t in "${SUITES[@]}"; do run "$t" --script "res://tools/$t.gd"; done
run test_netcode res://tools/test_netcode.tscn

# Le cycle de fin de match, en une seule instance et sans réseau.
#
# Ce chemin n'était couvert par AUCUNE suite, et c'est ce qui a laissé passer
# deux défauts en deux jours — dont `await RenderingServer.frame_post_draw`, qui
# n'est jamais émis en headless et suspendait la séquence de fin pour toujours.
# Invisible en jeu, puisqu'une fenêtre dessine ; visible seulement ici.
#
# Les modes `--host` / `--join` du même banc restent hors du lanceur : ils
# demandent deux processus coordonnés et une session Epic. À lancer à la main,
# protocole dans docs/PROTOCOLE_TEST_EOS.md.
run test_fin_de_match res://tools/test_online_match.tscn -- --local

# L'entraînement solitaire : une seule instance, aucun réseau. Ce qu'il protège
# avant tout, c'est que RIEN n'y soit archivé — le journal local est la source du
# rejeu vers le classement, et une ligne écrite ici polluerait un classement que
# personne ne saurait plus corriger.
run test_entrainement res://tools/test_online_match.tscn -- --training

# La fenêtre de choix d'un match apparié — dix secondes, arsenal aligné par la
# règle du miroir. Exercée en écran partagé : la mécanique est locale à
# `game_state`, et la faire dépendre de deux processus et d'Epic l'aurait rendue
# intestable en pratique, donc jamais testée.
run test_fenetre_de_choix res://tools/test_online_match.tscn -- --fenetre

if [ "$fail" -ne 0 ]; then
  echo "--- au moins une suite a échoué ---"; exit 1
fi
echo "--- toutes les suites passent, sans erreur de script ---"
