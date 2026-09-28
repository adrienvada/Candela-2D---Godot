#!/usr/bin/env bash
# Répétition : un match en ligne ENet à deux processus sur cette machine, EN FENÊTRE (deux Xvfb).
# Jamais EOS : `--transport enet --no-eos`.
#   ./tools/cloud_repetition/run_enet.sh <dossier de sortie absolu> [host|host-killcam|...]
# Le second argument choisit le couple de modes du banc test_online_match (host → --host/--join).
set -uo pipefail
GODOT="${GODOT:-/usr/local/bin/godot}"
SORTIE="${1:?dossier de sortie}"
MODE="${2:-host}"
HOTE="--$MODE"
INVITE="--${MODE/host/join}"
cd "$(dirname "$0")/../.."
mkdir -p "$SORTIE/home_hote" "$SORTIE/home_invite"
# Un foyer neuf joue l'intro PAR-DESSUS le salon (piège « Un banc qui monte main.tscn dans un
# foyer neuf photographie l'intro ») : SETTINGS_VU, un settings.cfg où l'intro est vue, est recopié.
if [ -n "${SETTINGS_VU:-}" ]; then
  for h in home_hote home_invite; do
    d="$SORTIE/$h/.local/share/godot/app_userdata/Candela 2D"; mkdir -p "$d"; cp "$SETTINGS_VU" "$d/settings.cfg"
  done
fi
export CANDELA_PORT="${CANDELA_PORT:-29417}"
HOME="$SORTIE/home_hote" xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --resolution 1920x1080 \
  --path . res://tools/cloud_repetition/en_ligne.tscn -- $HOTE --transport enet --no-eos \
  --photos="$SORTIE/photos_hote" > "$SORTIE/hote.log" 2>&1 &
PID_HOTE=$!
for i in $(seq 1 180); do grep -q "^CODE:" "$SORTIE/hote.log" && break; sleep 1; done
if ! grep -q "^CODE:" "$SORTIE/hote.log"; then echo "✗ l'hôte n'a jamais ouvert son salon"; kill $PID_HOTE; exit 1; fi
HOME="$SORTIE/home_invite" xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --fixed-fps 60 --resolution 1920x1080 \
  --path . res://tools/cloud_repetition/en_ligne.tscn -- $INVITE 127.0.0.1 --transport enet --no-eos \
  --photos="$SORTIE/photos_invite" > "$SORTIE/invite.log" 2>&1 &
PID_INVITE=$!
wait $PID_INVITE; CODE_INVITE=$?
wait $PID_HOTE; CODE_HOTE=$?
echo "hôte : sortie $CODE_HOTE — invité : sortie $CODE_INVITE"
