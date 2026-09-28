#!/usr/bin/env bash
# La peinture iso en ligne : deux instances ENet headless, l'hôte change de carte à l'écran de fin.
#   GODOT=/usr/local/bin/godot ./docs/iso/cloud/peinture-perimee/en_ligne.sh
set -u
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
export CANDELA_PORT="${CANDELA_PORT:-24123}"
timeout 300 "$GODOT" --headless --path . res://tools/banc_peinture_en_ligne.tscn -- --hote > ${JOURNAL:-/tmp/pp_en_ligne}_hote.log 2>&1 &
sleep 4
timeout 300 "$GODOT" --headless --path . res://tools/banc_peinture_en_ligne.tscn -- --invite > ${JOURNAL:-/tmp/pp_en_ligne}_invite.log 2>&1
wait
grep -hE "^(PEINTURE|VERDICT|===)|  entrée|✗|SCRIPT ERROR" ${JOURNAL:-/tmp/pp_en_ligne}_hote.log ${JOURNAL:-/tmp/pp_en_ligne}_invite.log
