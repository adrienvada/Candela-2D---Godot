#!/usr/bin/env bash
# D'où viennent les 7,6 ms du duel ? Sept relevés, et des BORNES plutôt qu'un
# nombre.
#
# La roadmap attribuait le coût à « deux SubViewport qui rendent chacun leurs
# lumières ». Hypothèse écrite comme une explication, jamais mesurée — la forme
# exacte de ce que le 2026-08-18 a passé la journée à démonter ailleurs.
#
# POURQUOI DANS LES DEUX SENS. Retirer un poste du duel complet donne sa borne
# BASSE : ce qu'on économise quand tout le reste est encore là pour masquer son
# coût. Le rendre à un socle nu donne sa borne HAUTE : ce qu'il coûte quand rien
# ne le recouvre. Le vrai coût est entre les deux, et **l'écart entre les bornes
# mesure le recouvrement** — c'est-à-dire précisément ce qu'un relevé unique ne
# peut pas dire. Des bornes serrées tranchent ; des bornes larges apprennent que
# le poste ne s'isole pas, ce qui est aussi une réponse.
#
# Le socle nu est la mesure la plus intéressante des sept : elle dit le plancher
# qu'aucun réglage ne fera bouger.
#
# Ouvre une fenêtre à chaque passage : à ne lancer qu'au calme, et avec l'accord
# d'Adrien. Environ deux minutes en tout.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SECONDES="${SECONDES:-15}"

lancer() {
  local titre="$1"; shift
  local sortie
  sortie="$("$GODOT" --path . res://tools/bench_framerate.tscn -- \
    --seconds "$SECONDES" --max-fps 0 "$@" 2>&1)"
  local med bas
  # Extraire APRÈS les deux-points, jamais le premier nombre de la ligne : le
  # libellé « FPS 1 % bas » contient lui-même un 1, et la première version de ce
  # script a rapporté « 1 % bas = 1 » pour les sept relevés. Un chiffre absurde
  # se remarque ; un chiffre plausible pris au mauvais endroit, non.
  med="$(printf '%s\n' "$sortie" | sed -n 's/.*FPS médian *: *\([0-9][0-9]*\).*/\1/p' | head -1)"
  bas="$(printf '%s\n' "$sortie" | sed -n 's/.*FPS 1 % bas *: *\([0-9][0-9]*\).*/\1/p' | head -1)"
  if [ -z "$med" ]; then
    printf '%-34s ÉCHEC\n' "$titre"
    printf '%s\n' "$sortie" | grep -E '✗|SCRIPT ERROR' | head -4
    return
  fi
  printf '%-34s médian %4s   1%% bas %4s\n' "$titre" "$med" "$bas"
}

echo "── D'où viennent les millisecondes du duel ──"
echo "   (médiane = régime courant ; 1 % bas = traîne)"
echo
lancer "duel complet"
lancer "socle nu"                  --une-vue --sans-torches --sans-shaders
echo
echo "  Bornes BASSES — retiré du duel complet :"
lancer "  sans la 2e vue"          --une-vue
lancer "  sans les torches"        --sans-torches
lancer "  sans les shaders joueur" --sans-shaders
echo
echo "  Bornes HAUTES — rendu au socle nu :"
lancer "  2e vue seule"            --sans-torches --sans-shaders
lancer "  torches seules"          --une-vue --sans-shaders
lancer "  shaders joueur seuls"    --une-vue --sans-torches
