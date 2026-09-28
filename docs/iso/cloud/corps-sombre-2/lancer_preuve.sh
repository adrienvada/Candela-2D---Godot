#!/usr/bin/env bash
# Q39 (2) — la preuve à l'image du correctif de pré-passe (banc des corps, sous Xvfb, rendu llvmpipe du cloud).
# Six configurations × quatre classes × deux lumières, chacune prise deux fois : telle quelle et pré-passes cachées
# (`--sans-profondeur`, la référence). `--temps-fixe` : deux lancements rendent la même pose.
#   GODOT=/chemin/godot ./docs/iso/cloud/corps-sombre-2/lancer_preuve.sh [dossier]
set -u
GODOT="${GODOT:-godot}"
DOS="${1:-/tmp/preuve_passe}"
mkdir -p "$DOS"
cd "$(dirname "$0")/../../../.."
COMMUN="--temps-fixe --sans-matiere --silhouette=0.5"
declare -A CFG=(
  [rien]=""
  [detail]="--corps-detaille --fusion-ab"
  [q39]="--corps-soi-sombre"
  [q39det]="--corps-soi-sombre --corps-detaille --fusion-ab"
  [q39anc]="--corps-soi-sombre --passe-ancienne"
  [q39detanc]="--corps-soi-sombre --corps-detaille --fusion-ab --passe-ancienne"
)
banc() {  # $1 = capture, reste = drapeaux
  local cap="$1"; shift
  timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . res://tools/banc_corps.tscn -- \
    $COMMUN "$@" --capture="$cap" >> "$DOS/journal.txt" 2>&1 || echo "✗ $cap" >> "$DOS/journal.txt"
}
for lum in 0.8 0.15; do
  for cl in pistolet occulteur fusil fumiste; do
    # Le fond de la même scène (même cadrage) : le corps entièrement effacé (opacité 0, sans silhouette : il se jette).
    banc "$DOS/vide_${cl}_$lum.png" --classe=$cl --lumiere=$lum --opacite=0 --silhouette=0
  done
  for cfg in rien detail q39 q39det q39anc q39detanc; do
    for cl in pistolet occulteur fusil fumiste; do  # Parasite, Occulteur, Illusionniste, Fumiste
      banc "$DOS/${cfg}_${cl}_$lum.png" --classe=$cl --lumiere=$lum ${CFG[$cfg]}
      banc "$DOS/${cfg}_${cl}_${lum}_sp.png" --classe=$cl --lumiere=$lum ${CFG[$cfg]} --sans-profondeur
    done
  done
done
python3 docs/iso/cloud/corps-sombre-2/preuve_passe.py "$DOS"
