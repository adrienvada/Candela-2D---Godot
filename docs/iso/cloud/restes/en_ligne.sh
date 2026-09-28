#!/usr/bin/env bash
# Les traces en ligne : deux instances ENet headless, l'hôte abat J2 par de vrais tirs puis change de carte à l'écran
# de fin (ou non : REVANCHE=1).
#   GODOT=/usr/local/bin/godot ./docs/iso/cloud/restes/en_ligne.sh
set -u
cd "$(dirname "$0")/../../../.."
GODOT="${GODOT:-godot}"
export CANDELA_PORT="${CANDELA_PORT:-24124}"
R=""; [ "${REVANCHE:-0}" = 1 ] && R="--revanche"
timeout 300 "$GODOT" --headless --path . res://tools/banc_traces_en_ligne.tscn -- --hote $R > ${JOURNAL:-/tmp/restes_en_ligne}_hote.log 2>&1 &
sleep 4
timeout 300 "$GODOT" --headless --path . res://tools/banc_traces_en_ligne.tscn -- --invite $R > ${JOURNAL:-/tmp/restes_en_ligne}_invite.log 2>&1
wait
grep -hE "^(TRACES|VERDICT|===)|  J2|✗|SCRIPT ERROR" ${JOURNAL:-/tmp/restes_en_ligne}_hote.log ${JOURNAL:-/tmp/restes_en_ligne}_invite.log
