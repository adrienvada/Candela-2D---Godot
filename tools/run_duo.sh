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

# Le port du salon ENet. Un seul lot peut l'occuper à la fois sur cette machine.
PORT=7777

## Qui tient le port, s'il est tenu ? Rend les PID, une par ligne.
tenants_du_port() {
  lsof -nP -iUDP:"$PORT" -t 2>/dev/null
}

## REFUSER PLUTÔT QUE DE PRODUIRE UN FAUX DIAGNOSTIC.
##
## Ce contrôle existe parce que son absence a coûté QUATRE diagnostics à TROIS
## sessions dans la même journée (2026-08-25). Un port déjà pris ne se voyait
## nulle part : l'hôte n'ouvrait pas de salon, le banc rendait « aucun adversaire
## n'a rejoint », et la scène qui ne démarrait pas produisait une cascade de
## `offset` sur un objet Nil. Trois sessions ont cherché une régression de
## netcode et une panne de caméra qui n'existaient ni l'une ni l'autre.
##
## **Le lanceur ne tue rien de lui-même.** Six sessions travaillent sur cette
## machine ; un `pkill` automatique tuerait le lot légitime d'une voisine au
## milieu de sa mesure. Il dit ce qu'il voit, il distingue le lot en cours de
## l'orphelin, et il rend la commande à taper.
verifier_port_libre() {
  local pids
  pids="$(tenants_du_port)"
  [ -z "$pids" ] && return 0

  echo "REFUS — le port UDP $PORT est déjà pris ; ce banc ne peut pas s'exécuter."
  echo "  Sans ce refus, l'hôte n'ouvrirait pas de salon et l'échec dirait"
  echo "  « aucun adversaire n'a rejoint » : un faux défaut de réseau."
  echo "  Le détiennent :"
  local p
  for p in $pids; do
    echo "    · PID $p — $(ps -o command= -p "$p" 2>/dev/null | cut -c1-90)"
  done
  if pgrep -f "run_suites|run_duo" >/dev/null 2>&1; then
    echo "  Un lot tourne en ce moment (une autre session, sans doute) :"
    echo "  ATTENDEZ qu'il finisse. Ne tuez rien, vous casseriez sa mesure."
  else
    echo "  AUCUN lot ne tourne : c'est un ORPHELIN d'un lot précédent."
    echo "  Remède :  pkill -f \"Godot --headless\""
  fi
  return 1
}

TMP="$(mktemp -d)"
HOTE_LOG="$TMP/hote.log"
CLIENT_LOG="$TMP/client.log"
hote_pid=""
client_pid=""

nettoyer() {
  for pid in "$hote_pid" "$client_pid" "${client2_pid:-}"; do
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
  done
  # **Vérifier que le nettoyage a nettoyé.** Un `kill -9` sur le mauvais PID
  # réussit sans rien libérer : c'est exactement ce qui produisait les
  # orphelins, et personne ne le voyait puisque la sortie du lanceur ne parlait
  # que de tests. Le port met un instant à se libérer après la mort du
  # processus, d'où les quelques essais.
  #
  # ⚠️ **Seulement si on a lancé quelque chose.** Ce garde-fou a crié
  # « ORPHELIN » à son premier essai alors que le lanceur venait de REFUSER de
  # démarrer : le port était tenu par la voisine, pas par nous. Un contrôle qui
  # accuse d'un dégât qu'on n'a pas fait est exactement le faux diagnostic que
  # ce lot supprime — il l'aurait juste déplacé d'un cran.
  [ -z "$hote_pid" ] && return 0
  local reste i
  for i in 1 2 3 4 5 6; do
    reste="$(tenants_du_port)"
    [ -z "$reste" ] && return 0
    sleep 0.5
  done
  echo "⚠️  ORPHELIN — le port $PORT est encore tenu APRÈS le nettoyage :"
  local p
  for p in $reste; do
    echo "    · PID $p — $(ps -o command= -p "$p" 2>/dev/null | cut -c1-90)"
  done
  echo "    Le prochain lot échouera sur « aucun adversaire n'a rejoint »."
  echo "    Remède :  pkill -f \"Godot --headless\""
}
trap nettoyer EXIT

# Deux scénarios : le match nominal, et la coupure pendant le décompte.
# `--coupure` en argument choisit le second.
if [ "${1:-}" = "--coupure" ]; then
  MODE_HOTE="--host-coupure"
  MODE_CLIENT="--join-coupure"
  TITRE="Coupure de l'adversaire pendant le décompte (famille 3)"
elif [ "${1:-}" = "--reconnexion" ]; then
  MODE_HOTE="--host-reconnexion"
  MODE_CLIENT="--join-ralenti"
  TITRE="L'adversaire quitte pendant la killcam et revient (famille 4.1)"
elif [ "${1:-}" = "--spam" ]; then
  MODE_HOTE="--host-spam"
  MODE_CLIENT="--join-spam"
  TITRE="Martèlement de « prêt » des deux côtés (famille 6)"
elif [ "${1:-}" = "--ralenti" ]; then
  MODE_HOTE="--host-ralenti"
  MODE_CLIENT="--join-ralenti"
  TITRE="Coupure pendant le ralenti (famille 5.3)"
elif [ "${1:-}" = "--killcam" ]; then
  MODE_HOTE="--host-killcam"
  MODE_CLIENT="--join-killcam"
  TITRE="RPC pendant la killcam (famille 2)"
elif [ "${1:-}" = "--pause" ]; then
  MODE_HOTE="--host-pause"
  MODE_CLIENT="--join-pause"
  TITRE="La pause en ligne ne gèle rien (famille 1)"
else
  MODE_HOTE="--host"
  MODE_CLIENT="--join"
  TITRE="Match en ligne à deux instances (ENet, 127.0.0.1)"
fi

echo "── $TITRE ──"

# **Code 3 et non 1, et c'est tout l'objet de ce garde-fou.** « Je n'ai pas pu
# m'exécuter » n'est pas « le jeu est cassé ». Confondre les deux est la faute
# même qui a coûté quatre diagnostics à trois sessions : un compte d'échecs
# gonflé par de la contention envoie chercher une panne réseau qui n'existe pas.
verifier_port_libre || exit 3

"$GODOT" --headless --path . "$BANC" -- $MODE_HOTE --transport enet >"$HOTE_LOG" 2>&1 &
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

"$GODOT" --headless --path . "$BANC" -- $MODE_CLIENT 127.0.0.1 --transport enet \
  >"$CLIENT_LOG" 2>&1 &
client_pid=$!

# Famille 4.1 : le premier client se tue pendant la killcam, un SECOND revient.
# C'est le seul scénario à trois processus, et le retour doit être tenté pendant
# que l'hôte est encore dans sa séquence de fin — sinon on testerait une simple
# jointure sur un salon au repos, pas une reconnexion.
if [ "${1:-}" = "--reconnexion" ]; then
  # `exec` n'est PAS un détail de style : sans lui, `$!` capture le PID du
  # SOUS-SHELL, pas celui de Godot. Le nettoyage tuait donc le sous-shell et
  # laissait Godot vivant — un orphelin qui garde le port 7777 et empoisonne
  # tous les lots suivants. Avec `exec`, le sous-shell est REMPLACÉ par Godot :
  # `$!` désigne le processus qu'on croit tuer.
  ( sleep 18
    exec "$GODOT" --headless --path . "$BANC" -- --join 127.0.0.1 --transport enet \
      >"$TMP/client2.log" 2>&1 ) &
  client2_pid=$!
fi

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
  # Le client de la coupure se tue lui-même : sortir en 0 signifierait qu'il
  # est parti proprement, donc que le test n'a PAS exercé la perte de pair.
  if [ "$cote" = "client" ] && { [ "${1:-}" = "--coupure" ] || [ "${1:-}" = "--ralenti" ] \
      || [ "${1:-}" = "--reconnexion" ]; }; then
    if [ "$code" -eq 0 ]; then
      printf '%-8s ÉCHEC — sorti proprement, la coupure n'"'"'a pas eu lieu\n' "$nom"
      echec=1
    else
      printf '%-8s OK (coupé, code %d)\n' "$nom" "$code"
    fi
    continue
  fi
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
