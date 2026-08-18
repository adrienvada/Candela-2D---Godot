#!/usr/bin/env bash
# Le match en ligne de bout en bout, à DEUX PROCESSUS, automatiquement.
#
# Dernier trou de l'étude de robustesse du 2026-08-16 : « les transitions d'état
# en ligne ne sont couvertes que manuellement — c'est la zone la plus régressive
# d'un jeu réseau ». Elles l'étaient parce qu'un match demande deux instances, et
# qu'aucune suite ne sait en coordonner deux.
#
# ENet lève l'obstacle : 127.0.0.1, aucun identifiant Epic, aucun code de salon à
# se transmettre — l'adresse est connue d'avance. Le banc `test_online_match`
# savait déjà jouer les deux rôles ; il lui manquait quelqu'un pour les lancer.
#
# CE QUI EST VÉRIFIÉ, et dans cet ordre d'importance :
#   1. les deux processus SORTENT (un banc qui pend est le mode de défaillance
#      déjà rencontré deux fois aujourd'hui — le banc de cadence restait ouvert
#      sans rien mesurer, et personne ne le savait) ;
#   2. les deux sortent en 0 ;
#   3. aucun n'a émis de SCRIPT ERROR — une erreur de script n'échoue PAS une
#      suite GDScript, seul un `_check` incrémente le compteur ;
#   4. l'échec dit DE QUEL CÔTÉ il vient, sans quoi il n'apprend rien.
#
# Lancer : ./tools/run_duo.sh
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BANC="res://tools/test_online_match.tscn"
# Le temps que l'hôte ouvre son salon. Généreux : sur une machine chargée le
# démarrage de Godot lui-même prend plusieurs secondes, et un délai trop court
# rendrait ce banc dépendant de la charge — le défaut exact qui a coûté une
# demi-journée de diagnostic le 2026-08-18.
ATTENTE_HOTE=60
# Plafond de vie d'un processus. Sans lui, un banc qui pend bloque le lanceur
# pour toujours, et c'est le lanceur entier qui devient inutilisable.
PLAFOND=180

TMP="$(mktemp -d)"
HOTE_LOG="$TMP/hote.log"
CLIENT_LOG="$TMP/client.log"
hote_pid=""
client_pid=""

nettoyer() {
  for pid in "$hote_pid" "$client_pid"; do
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
  done
}
trap nettoyer EXIT

echo "── Match en ligne à deux instances (ENet, 127.0.0.1) ──"

"$GODOT" --headless --path . "$BANC" -- --host --transport enet >"$HOTE_LOG" 2>&1 &
hote_pid=$!

# Attendre une CONDITION, pas une durée : l'hôte annonce son salon par « CODE: ».
# Un `sleep` fixe marcherait sur cette machine-ci, aujourd'hui.
attendu=0
while [ "$attendu" -lt "$ATTENTE_HOTE" ]; do
  if grep -q '^CODE:' "$HOTE_LOG" 2>/dev/null; then break; fi
  if ! kill -0 "$hote_pid" 2>/dev/null; then
    echo "ÉCHEC — l'hôte est mort avant d'ouvrir son salon"
    sed -n '$!d;p' "$HOTE_LOG" >/dev/null
    tail -20 "$HOTE_LOG"
    exit 1
  fi
  sleep 1
  attendu=$((attendu + 1))
done

if ! grep -q '^CODE:' "$HOTE_LOG"; then
  echo "ÉCHEC — l'hôte n'a pas ouvert de salon en ${ATTENTE_HOTE}s"
  tail -20 "$HOTE_LOG"
  exit 1
fi
echo "hôte prêt : $(grep -m1 '^CODE:' "$HOTE_LOG")"

"$GODOT" --headless --path . "$BANC" -- --join 127.0.0.1 --transport enet \
  >"$CLIENT_LOG" 2>&1 &
client_pid=$!

# Attendre les deux, sans dépasser le plafond. `wait` seul n'a pas de délai.
fini=0
while [ "$fini" -lt "$PLAFOND" ]; do
  hote_vivant=0; client_vivant=0
  kill -0 "$hote_pid" 2>/dev/null && hote_vivant=1
  kill -0 "$client_pid" 2>/dev/null && client_vivant=1
  [ "$hote_vivant" -eq 0 ] && [ "$client_vivant" -eq 0 ] && break
  sleep 1
  fini=$((fini + 1))
done

if [ "$fini" -ge "$PLAFOND" ]; then
  echo "ÉCHEC — un processus n'est jamais sorti (plafond ${PLAFOND}s)"
  kill -0 "$hote_pid" 2>/dev/null && echo "  · l'hôte pend encore"
  kill -0 "$client_pid" 2>/dev/null && echo "  · le client pend encore"
  exit 1
fi

wait "$hote_pid"; code_hote=$?
wait "$client_pid"; code_client=$?

echec=0
for cote in hote client; do
  if [ "$cote" = "hote" ]; then log="$HOTE_LOG"; code="$code_hote"; nom="HÔTE"
  else log="$CLIENT_LOG"; code="$code_client"; nom="CLIENT"; fi

  erreurs="$(grep -c 'SCRIPT ERROR' "$log" || true)"
  if [ "$code" -ne 0 ]; then
    printf '%-8s ÉCHEC (code %d)\n' "$nom" "$code"
    grep -E '^  ✗|^✗' "$log" | head -8
    echec=1
  elif [ "$erreurs" -ne 0 ]; then
    printf '%-8s ÉCHEC — %s erreur(s) de script malgré un code 0\n' "$nom" "$erreurs"
    grep -A2 'SCRIPT ERROR' "$log" | head -12
    echec=1
  else
    printf '%-8s OK\n' "$nom"
  fi
done

if [ "$echec" -ne 0 ]; then
  echo "--- le match à deux instances a échoué ---"
  echo "journaux conservés : $TMP"
  trap - EXIT
  nettoyer
  exit 1
fi
echo "--- le match à deux instances passe ---"
