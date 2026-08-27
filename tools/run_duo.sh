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
#   3bis. aucun n'a émis de `push_error()` — le CRI DU REPLI MUET (masque,
#      sprite ou viseur absent). Même angle mort que dans `run_suites.sh`,
#      corrigé le même jour : la signature est `at: push_error (`, PAS
#      `ERROR:`, que Godot imprime aussi pour son propre bruit de fin ;
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

# Le port du salon ENet, **DÉRIVÉ DE L'ARBRE DE TRAVAIL**.
#
# Un port fixe pour six sessions qui partagent la machine, c'est une file
# d'attente que personne n'a demandée : le refus ci-dessous protège du faux
# diagnostic, mais il ne rend pas la mesure possible pour autant. Deux worktrees
# doivent pouvoir mesurer EN MÊME TEMPS.
#
# La journée du 2026-08-25 a tranché la forme : quatre diagnostics faux à trois
# sessions, et la conclusion unanime que **l'outil qui évite bat la discipline
# qui se souvient**. Un `CANDELA_PORT` qu'il faudrait penser à exporter aurait
# été de la discipline ; le dériver n'en demande aucune.
#
# **Dérivé ICI et exporté, jamais recalculé en aval** — c'est la condition posée
# par DA2, et elle évite une panne muette : si l'hôte et le client dérivaient
# chacun de leur propre chemin, deux processus lancés depuis des dossiers
# différents ouvriraient deux ports et ne se verraient jamais. L'échec dirait
# « aucun adversaire n'a rejoint », c'est-à-dire rien.
#
# **Plage 20000-39999**, à l'écart des ports éphémères de macOS (49152+) : un
# hash qui y tomberait entrerait en conflit avec ce que l'OS vient d'attribuer,
# de façon intermittente et irreproductible — le pire mode de panne pour un banc.
if [ -n "${CANDELA_PORT:-}" ]; then
  PORT="$CANDELA_PORT"
else
  PORT=$(( 20000 + $(pwd -P | cksum | cut -d' ' -f1) % 20000 ))
fi
# Godot le lit dans `NetworkManager.DEFAULT_PORT`, en debug seulement.
export CANDELA_PORT="$PORT"

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
  for pid in "$hote_pid" "$client_pid" "${client2_pid:-}" "${guetteur_pid:-}"; do
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
  TITRE="Il quitte pendant la killcam et revient PENDANT (famille 4.1)"
elif [ "${1:-}" = "--reconnexion-tardive" ]; then
  # La 4.2 de la checklist : « B rejoint alors que A est déjà sur l'écran de
  # fin ». Elle n'était pas un scénario — elle était ce que la 4.1 exerçait sans
  # le savoir, un `sleep 18` fixe la faisant tomber quatre secondes APRÈS la fin
  # de la killcam. La séparer coûte trois lignes et rend son vert honnête.
  MODE_HOTE="--host-reconnexion-tardive"
  MODE_CLIENT="--join-ralenti"
  TITRE="Il quitte pendant la killcam et revient APRÈS (famille 4.2)"
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

# Les deux variantes partagent tout sauf l'instant du retour : un seul prédicat,
# plutôt que trois comparaisons de chaîne qui finiront par diverger.
RECO=0
case "${1:-}" in --reconnexion|--reconnexion-tardive) RECO=1 ;; esac

echo "── $TITRE ──  (port $PORT)"

# **Code 3 et non 1, et c'est tout l'objet de ce garde-fou.** « Je n'ai pas pu
# m'exécuter » n'est pas « le jeu est cassé ». Confondre les deux est la faute
# même qui a coûté quatre diagnostics à trois sessions : un compte d'échecs
# gonflé par de la contention envoie chercher une panne réseau qui n'existe pas.
verifier_port_libre || exit 3

# ⚠️ **`--no-eos` : ces scenarios tournent en ENet, EOS n'y sert a rien.**
#
# Sans lui, chaque instance ouvre une session Epic — un aller-retour reseau
# reel, douze fois par lot complet. Mesure le 2026-08-26 : 17 s le scenario
# avec, 15 s sans, soit ~12 s sur le lot.
#
# Le gain de temps n'est pas le meilleur argument. Le vrai est qu'un lot LOCAL
# ne doit pas dependre d'internet ni de la disponibilite d'Epic : un banc qui
# rougit parce qu'Epic est lent est un FAUX ROUGE, et un faux rouge se fait
# debrancher. Le drapeau existait deja dans network_manager.gd, personne ne
# s'en servait.
"$GODOT" --headless --path . "$BANC" -- $MODE_HOTE --transport enet --no-eos >"$HOTE_LOG" 2>&1 &
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

"$GODOT" --headless --path . "$BANC" -- $MODE_CLIENT 127.0.0.1 --transport enet --no-eos \
  >"$CLIENT_LOG" 2>&1 &
client_pid=$!

# Familles 4.1 et 4.2 : le premier client se tue pendant la killcam, un SECOND
# revient. Seul scénario à trois processus, et **l'instant du retour EST le
# scénario** — c'est lui, et lui seul, qui sépare la 4.1 de la 4.2.
#
# ⚠️ **Il était ordonnancé par `sleep 18`, et ce délai fixe a fait mesurer à ce
# banc autre chose que son titre pendant une semaine.** La séquence de fin de
# l'hôte dure une douzaine de secondes et démarre elle-même après un lancement de
# Godot, un décompte et un tir : horodaté le 2026-08-26, le revenant arrivait
# **quatre secondes après** la fin de la killcam. Le banc était vert, sur la 4.2.
# Ramené à douze secondes, il rougissait deux fois sur deux.
#
# La forme juste est celle que ce fichier applique déjà à `CODE:` quinze lignes
# plus haut : **attendre une CONDITION**. L'hôte imprime `RETOUR:` quand il veut
# le revenant, un guetteur pose le jeton, et le revenant — DÉJÀ DÉMARRÉ, en
# attente sur ce fichier — rejoint dans la demi-seconde.
#
# Le démarrer tout de suite est ce qui retire du chemin critique les deux à
# quatre secondes de lancement de Godot, lesquelles suffisaient à faire glisser
# le retour hors de la killcam. Et comme il n'y a plus de `sleep`, il n'y a plus
# de sous-shell : `$!` désigne Godot directement, et le piège de l'orphelin qui
# gardait le port — celui qui imposait `exec` ici — n'a plus d'objet.
if [ "$RECO" -eq 1 ]; then
  JETON="$TMP/retour"
  "$GODOT" --headless --path . "$BANC" -- --join-retour 127.0.0.1 --jeton "$JETON" \
    --transport enet --no-eos >"$TMP/revenant.log" 2>&1 &
  client2_pid=$!
  ( while kill -0 "$hote_pid" 2>/dev/null; do
      if grep -q '^RETOUR:' "$HOTE_LOG" 2>/dev/null; then : > "$JETON"; exit 0; fi
      sleep 0.2
    done ) &
  guetteur_pid=$!
fi

# Attendre TOUS les processus du lot, sans dépasser le plafond. `wait` seul n'a
# pas de délai. Le revenant en fait partie : ne pas l'attendre, c'était noter un
# lot dont un tiers travaillait encore.
fini=0
while [ "$fini" -lt "$PLAFOND" ]; do
  vivants=0
  for pid in "$hote_pid" "$client_pid" "${client2_pid:-}"; do
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && vivants=$((vivants + 1))
  done
  [ "$vivants" -eq 0 ] && break
  sleep 1
  fini=$((fini + 1))
done

if [ "$fini" -ge "$PLAFOND" ]; then
  echo "ÉCHEC — un processus n'est jamais sorti (plafond ${PLAFOND}s)"
  kill -0 "$hote_pid" 2>/dev/null && echo "  · l'hôte pend encore"
  kill -0 "$client_pid" 2>/dev/null && echo "  · le client pend encore"
  [ -n "${client2_pid:-}" ] && kill -0 "$client2_pid" 2>/dev/null \
    && echo "  · le revenant pend encore"
  exit 1
fi

wait "$hote_pid"; code_hote=$?
wait "$client_pid"; code_client=$?
code_revenant=0
[ -n "${client2_pid:-}" ] && { wait "$client2_pid"; code_revenant=$?; }

# **« Je n'ai pas pu mesurer » n'est pas « le jeu est cassé », et le banc le dit
# maintenant lui aussi.** Le code 3 servait au port occupé ; il sert désormais
# aussi au placement du retour, qui dépend du tempo de la machine et non du code.
# Un vert emprunté à la famille d'à côté serait pire qu'un rouge — et un rouge
# dû à la charge se ferait débrancher.
if [ "$code_hote" -eq 3 ]; then
  echo "REPORTÉ — la mesure n'a pas eu lieu :"
  grep -m1 'MESURE NON FAITE' "$HOTE_LOG" | sed 's/^/    /'
  echo "    Ce n'est pas une panne : le scénario n'a pas pu être exercé."
  exit 3
fi

# Le troisième journal est NOTÉ comme les deux autres.
#
# ⚠️ Il était produit et jamais lu, et ça a coûté une entrée fausse dans la
# feuille de route : le revenant jouait alors `--join`, le scénario NOMINAL, face
# à un hôte qui sort une quinzaine de secondes après son arrivée. Son journal se
# remplissait de « Trying to call an RPC while no multiplayer peer is active » —
# en aval de cette sortie et de rien d'autre — et ce symptôme a été consigné
# comme un défaut du jeu. **Un journal qu'on écrit sans le lire est pire qu'un
# journal absent : il a l'air d'une preuve.**
cotes="hote client"
[ -n "${client2_pid:-}" ] && cotes="$cotes revenant"

echec=0
for cote in $cotes; do
  if [ "$cote" = "hote" ]; then log="$HOTE_LOG"; code="$code_hote"; nom="HÔTE"
  elif [ "$cote" = "client" ]; then log="$CLIENT_LOG"; code="$code_client"; nom="CLIENT"
  else log="$TMP/revenant.log"; code="$code_revenant"; nom="REVENANT"; fi

  erreurs="$(grep -c 'SCRIPT ERROR' "$log" || true)"
  cris="$(grep -c 'at: push_error (' "$log" || true)"
  # Le client de la coupure se tue lui-même : sortir en 0 signifierait qu'il
  # est parti proprement, donc que le test n'a PAS exercé la perte de pair.
  if [ "$cote" = "client" ] && { [ "${1:-}" = "--coupure" ] || [ "${1:-}" = "--ralenti" ] \
      || [ "$RECO" -eq 1 ]; }; then
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
  elif [ "$cris" -ne 0 ]; then
    printf '%-8s ÉCHEC — %s push_error(s) malgré un code 0\n' "$nom" "$cris"
    grep -B1 -A1 'at: push_error (' "$log" | head -12
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
