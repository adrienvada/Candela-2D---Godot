#!/usr/bin/env bash
# UNE PRISE du banc de cadence dans le cloud (audit M) : copie fidèle de tools/cadence_cloud/prise.sh, avec trois paramètres de plus
# (GODOT : le binaire ; SCENE : la scène du banc, `bench_framerate` par défaut ou `mesure_banc` ; BASE_ARGS : les drapeaux de base,
# `--fusee --vue-unique --classe=pompe` par défaut). Tout le reste — foyer isolé, settings.cfg, cache Mesa, porte stricte, délai —
# est celui du projet.
dir="$(cd "$(dirname "$0")" && pwd)"
arbre="$1"; sortie="$2"; shift 2
SECONDES="${SECONDES:-45}"
PHYSIQUE="${PHYSIQUE:-8}"
SCENE="${SCENE:-bench_framerate}"
GODOT="${GODOT:-godot}"
BASE_ARGS="${BASE_ARGS:---fusee --vue-unique --classe=pompe}"
CACHE_MESA="${CACHE_MESA:-$HOME/.cache/candela_cadence_mesa}"
# Pseudo-drapeau de ce script (jamais transmis au jeu) : `--M-sans-fusee` retire la fusée du banc (le drapeau `--fusee` des drapeaux de base).
EXTRA=()
for a in "$@"; do
  if [ "$a" = "--M-sans-fusee" ]; then BASE_ARGS="${BASE_ARGS//--fusee/}"; else EXTRA+=("$a"); fi
done
set -- "${EXTRA[@]}"
"$dir/attendre_libre.sh" 120 || exit 3
maison="$(mktemp -d)"
mkdir -p "$maison/.local/share/godot/app_userdata/Candela 2D" "$CACHE_MESA"
printf '[video]\n\nvsync_enabled=false\nfps_cap=0\niso_lightmap="1080p"\n\n[display]\n\nintro_vue=true\n' \
  > "$maison/.local/share/godot/app_userdata/Candela 2D/settings.cfg"
debut=$(date +%s)
echo "[prise] $(date +%H:%M:%S) arbre=$arbre scene=$SCENE args=$BASE_ARGS --seconds $SECONDES --seuil-lent 1 --physique $PHYSIQUE $* ; load $(cat /proc/loadavg)" > "$sortie.log"
echo "[prise] cpu avant : $(head -1 /proc/stat) ; psi $(head -1 /proc/pressure/cpu 2>/dev/null)" >> "$sortie.log"
export MESA_SHADER_CACHE_DIR="$CACHE_MESA"
export MESA_SHADER_CACHE_MAX_SIZE=4G
# shellcheck disable=SC2086
HOME="$maison" timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$arbre" "res://tools/$SCENE.tscn" -- \
  $BASE_ARGS --seconds "$SECONDES" --seuil-lent 1 --physique "$PHYSIQUE" "$@" >> "$sortie.log" 2>&1 &
pid=$!
python3 "$dir/porte.py" "$pid" "$sortie.porte.json" 20 2 &
porte=$!
wait "$pid"; code=$?
wait "$porte"
echo "[prise] cpu après : $(head -1 /proc/stat) ; psi $(head -1 /proc/pressure/cpu 2>/dev/null) ; load $(cat /proc/loadavg)" >> "$sortie.log"
echo "[prise] code $code ; durée $(( $(date +%s) - debut )) s" >> "$sortie.log"
rm -rf "$maison"
exit "$code"
