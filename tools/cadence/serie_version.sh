#!/usr/bin/env bash
# LA SÉRIE COURTE D'UNE VERSION (session cloud « cadence-version », 2026-09-28). À lancer sur le Mac d'Adrien, en une fois.
# La règle qu'elle sert : `docs/iso/cadence_par_version.md`. Le cloud ne mesure pas le temps : cette série est la seule qui
# dise si une version tient la règle 278.
#
#     tools/cadence/serie_version.sh --preparer <tête A> <tête B>        # une fois, AVANT : les deux arbres et leur import
#     mkdir /tmp/candela-mac.lock
#     tools/cadence/serie_version.sh <tête A> <tête B> <sortie>          # ≈ 28 min sans refus
#     rmdir /tmp/candela-mac.lock
#
# DEUX BRAS : A (la référence, la dernière version qui a tenu) et B (la candidate). Une version se lance SANS DRAPEAU :
# chaque bras tourne dans SON arbre de travail ($ARBRES/<hash>), à sa tête, avec ses défauts, et reçoit exactement les
# mêmes arguments que l'autre. Ce qui distingue les bras, c'est l'arbre — prouvé à chaque prise (voir « LA PREUVE »).
#
# LA SCÈNE (règle 278) : le pompe sous une fusée, vue unique, lacet par défaut (`bench_framerate.tscn -- --fusee --vue-unique
# --classe=pompe`). SCINDE=1 retire `--vue-unique` : l'écran scindé, seulement si le tri du cloud a classé « lourde » une
# nouveauté de géométrie.
#
# L'ORDRE : une chauffe A non comptée, puis A B B A A B (trois prises par bras). LA PROLONGATION, écrite d'avance : si le
# rapport des médianes tombe entre PROLONGER_BAS et PROLONGER_HAUT (0,958 et 0,982 : une image près de la barre, à 85),
# UN bloc B A de plus (qui ramène les positions moyennes à 4,5 et 4,5), puis le verdict sur quatre prises par bras.
# Jamais un second bloc.
#
# LA PORTE (ordre 432, reprise de `tools/masque_fumee/serie_mac_2.sh`, qui l'a tenue sur le Mac) :
#   1. un REPOS INITIAL de 5 minutes (REPOS_INITIAL, en secondes ; 20 dans l'ordre 432) : la charge y est relevée. Plus court
#      parce que la chauffe non comptée et les 90 s avant chaque prise protègent déjà la première prise, et que l'état
#      THERMIQUE est lu avant chaque prise (il doit valoir 0, « normal » ; sinon on attend, dix minutes au plus) ;
#   2. 90 SECONDES SANS AUCUN GODOT avant chaque prise (REPOS_PRISE) — `docs/iso/iso12/mesurer_une_cadence.md`, § 6 ;
#   3. la porte NE JUGE QUE LA FENÊTRE MESURÉE, de « Mesure sur … » à « FPS médian », au MAXIMUM (§ 2 et § 7) ;
#   4. tout processus étranger au-dessus de 20 % d'un cœur dans la fenêtre : prise REFUSÉE ; Claude Helper (tous ses
#      processus sommés) ADMIS sous 30 %, relevé à chaque prise ;
#   5. une prise refusée SE REFAIT À SA PLACE, quatre fois au plus ; à la cinquième, la série s'arrête sans verdict ;
#   6. ÉQUILIBRE DES BRAS À 2 POINTS de charge médiane de Claude Helper, sinon SANS VERDICT.
# Ne comptent pas comme étrangers : Godot, WindowServer, top, kernel_task (EXCLUS).
#
# LA PREUVE DE LA TÊTE, à chaque prise : l'arbre est à la tête voulue (hash relu avant et après), propre (aucun fichier suivi
# modifié), importé ; le journal porte « Rendu : <RENDU> » et « slugs pompe / pompe » ; les lignes d'état que le jeu imprime
# (celles qui commencent par « [ », chiffres ôtés) sont LES MÊMES à chaque prise d'un même bras. Le verdict imprime celles qui
# diffèrent entre A et B : c'est ce que la version change, dit par le jeu. PREUVE_A / PREUVE_B (facultatives) : une ligne que
# le journal de ce bras DOIT contenir.
#
# Ce qui ARRÊTE la série (une faute de montage, pas du bruit) : un arbre absent, sale, pas importé ou pas à sa tête ; une
# erreur de shader ou de script ; une preuve absente ; des lignes d'état qui changent au sein d'un bras ; une médiane
# illisible ; quelqu'un devant le Mac ; un Mac qui ne refroidit pas.
#
# LE VERDICT (règle 278) : VALIDE si les A tiennent dans 5 % et si les bras sont équilibrés ; B TIENT si la médiane de ses
# médianes vaut au moins 0,970 de celle de A ET si la médiane de ses 1 % bas (hors 10 s) est au-dessus de 60.
#
# Essais sans le Mac :
#     ESSAI_A_BLANC=1 tools/cadence/serie_version.sh A B /tmp/essai        # ni Godot ni top : fausses prises, fausses charges
#       (FAUX_RAPPORT=0.97 : la médiane simulée de B ; FAUX_HELPER / FAUX_ETRANGER : % de chance d'un pic par échantillon ;
#        FAUX_HELPER_FIXE=15 : Claude Helper constant, bras toujours équilibrés ; FAUX_THERMIQUE=2 : un Mac qui chauffe)
#     ESSAI_CLOUD=1 SECONDES=5 GODOT=godot xvfb-run -a -s "-screen 0 1920x1080x24" \
#       tools/cadence/serie_version.sh <A> <B> /tmp/essai-cloud             # le VRAI banc sous Xvfb, charges simulées
set -uo pipefail
# Tout le script est dans un bloc : bash le lit EN ENTIER avant d'en exécuter la première ligne. Sans lui, modifier
# le fichier pendant une série fait exécuter à bash du texte décalé (payé le 2026-09-28 dans le cloud : « rendre:
# command not found », puis une septième prise qui n'était pas dans l'ordre).
{
DEPOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DEPOT" || exit 1
BLANC="${ESSAI_A_BLANC:-0}"
CLOUD="${ESSAI_CLOUD:-0}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
# « .noindex » : Spotlight n'indexe pas un dossier qui porte ce suffixe (un import écrit des milliers de fichiers, et
# l'indexation est la charge la mieux connue du Mac : § 1 du document de mesure).
ARBRES="${ARBRES:-$HOME/candela-arbres.noindex}"
SECONDES="${SECONDES:-60}"
if [ "$BLANC" = "1" ] || [ "$CLOUD" = "1" ]; then
  REPOS_INITIAL="${REPOS_INITIAL:-3}"; REPOS_PRISE="${REPOS_PRISE:-1}"
else
  REPOS_INITIAL="${REPOS_INITIAL:-300}"; REPOS_PRISE="${REPOS_PRISE:-90}"
fi
SEUIL_ETRANGER="${SEUIL_ETRANGER:-20}"
SEUIL_HELPER="${SEUIL_HELPER:-30}"
EQUILIBRE="${EQUILIBRE:-2}"
REFAIRE_MAX="${REFAIRE_MAX:-4}"
EXCLUS="${EXCLUS:-^(godot|windowserver|top|kernel_task)}"
RENDU="${RENDU:-iso lacet 45° B}"
PROLONGER_BAS="${PROLONGER_BAS:-0.958}"
PROLONGER_HAUT="${PROLONGER_HAUT:-0.982}"
SCINDE="${SCINDE:-0}"
JOURNAL_TMP="/tmp/candela-serie-version.log"

# Une tête → son hash complet (refus si elle n'existe pas).
resoudre() { git rev-parse --verify --quiet "$1^{commit}" || { echo "✗ tête inconnue : $1 (git fetch ?)" >&2; exit 1; }; }
arbre_de() { echo "$ARBRES/$(echo "$1" | cut -c1-12)"; }

# ─── LA PRÉPARATION : les deux arbres, leur import. Hors de la série, parce qu'un import pèse sur les prises. ───
if [ "${1:-}" = "--preparer" ]; then
  shift
  mkdir -p "$ARBRES"
  for tete in "${1:?tête A}" "${2:?tête B}"; do
    h="$(resoudre "$tete")"; a="$(arbre_de "$h")"
    if [ -d "$a" ]; then
      echo "arbre déjà là : $a ($(git -C "$a" log --oneline -1 | cut -c1-60))"
    else
      git worktree add --detach "$a" "$h" > /dev/null 2>&1 || { echo "✗ worktree $a"; exit 1; }
      echo "arbre posé : $a ($(git -C "$a" log --oneline -1 | cut -c1-60))"
    fi
    if [ "$BLANC" = "1" ]; then mkdir -p "$a/.godot"; continue; fi
    echo "  import de $a (quelques minutes la première fois)…"
    "$GODOT" --headless --path "$a" --import > "$a/.import_serie.log" 2>&1
    echo "  import : code $? — journal $a/.import_serie.log"
    if [ -n "$(git -C "$a" status --porcelain --untracked-files=no)" ]; then
      echo "✗ l'import a MODIFIÉ des fichiers suivis dans $a :"; git -C "$a" status --porcelain --untracked-files=no | head
      echo "  (la série le refusera : une tête modifiée n'est plus la tête qu'on croit mesurer)"; exit 1
    fi
  done
  echo "prêt. La série : tools/cadence/serie_version.sh $1 $2 <sortie>"
  exit 0
fi

A_TETE="${1:?tête A (la référence)}"; B_TETE="${2:?tête B (la candidate)}"; OUT="${3:?dossier de sortie}"
A_HASH="$(resoudre "$A_TETE")"; B_HASH="$(resoudre "$B_TETE")"
[ "$A_HASH" != "$B_HASH" ] || { echo "✗ A et B sont la même tête ($A_HASH)"; exit 1; }
A_ARBRE="$(arbre_de "$A_HASH")"; B_ARBRE="$(arbre_de "$B_HASH")"
mkdir -p "$OUT"

hash_de() { case "$1" in A) echo "$A_HASH" ;; B) echo "$B_HASH" ;; esac; }
arbre() { case "$1" in A) echo "$A_ARBRE" ;; B) echo "$B_ARBRE" ;; esac; }
preuve_bras() { case "$1" in A) echo "${PREUVE_A:-}" ;; B) echo "${PREUVE_B:-}" ;; esac; }
scene() { if [ "$SCINDE" = "1" ]; then echo "--fusee --classe=pompe"; else echo "--fusee --vue-unique --classe=pompe"; fi; }

# L'arbre d'un bras est-il bien la tête qu'on croit ? Rend un message si non, rien si oui.
arbre_faux() {
  local a; a="$(arbre "$1")"
  [ -d "$a" ] || { echo "l'arbre $a n'existe pas (tools/cadence/serie_version.sh --preparer $A_TETE $B_TETE)"; return; }
  [ -d "$a/.godot" ] || { echo "l'arbre $a n'est pas importé (--preparer)"; return; }
  [ "$(git -C "$a" rev-parse HEAD)" = "$(hash_de "$1")" ] || { echo "l'arbre $a n'est plus à $(hash_de "$1" | cut -c1-12)"; return; }
  [ -z "$(git -C "$a" status --porcelain --untracked-files=no)" ] || { echo "l'arbre $a a des fichiers suivis modifiés"; return; }
}

godot_ouvert() {
  if [ "$BLANC" = "1" ]; then return 1; fi
  if [ "$CLOUD" = "1" ]; then
    # Dans le cloud, d'autres Godot tournent (le tri, sous llvmpipe) et la cadence n'y vaut rien : on ne guette que les
    # Godot lancés sur NOS arbres. Sur le Mac, TOUT Godot compte (l'éditeur d'Adrien compris, § 13 du document de mesure).
    pgrep -f -- "--path $ARBRES/" > /dev/null
  else
    pgrep -x Godot > /dev/null
  fi
}

present() {
  [ "$BLANC" = "1" ] || [ "$CLOUD" = "1" ] && return 1
  top -l 2 -s 2 -n 30 -o cpu -stats command,cpu 2>/dev/null | awk '
    /^COMMAND/ { n++; next }
    n==2 { cpu=$NF; sub(/%/,"",cpu); nom=$0; sub(/[ \t]+[0-9.]+%?[ \t]*$/,"",nom); l=tolower(nom)
      if (l ~ /firefox|safari|chrome|vlc|iina|quicktime|music|podcasts|^tv|usbaudiod|coreaudiod|spotify/ && cpu+0 >= 5.0) {
        printf "%s %.1f%%\n", nom, cpu; t=1 } }
    END { exit t ? 0 : 1 }'
}

# L'état thermique du Mac (0 normal, 1 passable, 2 sérieux, 3 critique — § 9 du document de mesure). Hors du Mac : 0.
thermique() {
  if [ "$BLANC" = "1" ] || [ "$CLOUD" = "1" ]; then echo "${FAUX_THERMIQUE:-0}"; return; fi
  osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState' 2>/dev/null || echo "?"
}

# LE RELEVÉ DE CHARGE : « époque<TAB>processus<TAB>%cpu », jusqu'à ce que "$2" existe. `top -l 2`, seconde passe seulement.
releve() {
  local sortie="$1" stop="$2"
  while [ ! -e "$stop" ]; do
    if [ "$BLANC" = "1" ] || [ "$CLOUD" = "1" ]; then
      local t; t=$(date +%s)
      printf '%s\tClaude Helper (R\t%s\n' "$t" "${FAUX_HELPER_FIXE:-$((8 + RANDOM % 19))}" >> "$sortie"
      printf '%s\tClaude Helper (G\t%s\n' "$t" "$((RANDOM % 3))" >> "$sortie"
      printf '%s\tWindowServer\t%s\n' "$t" "$((30 + RANDOM % 20))" >> "$sortie"
      if [ $((RANDOM % 100)) -lt "${FAUX_HELPER:-3}" ]; then printf '%s\tClaude Helper\t%s\n' "$t" 31 >> "$sortie"; fi
      if [ $((RANDOM % 100)) -lt "${FAUX_ETRANGER:-3}" ]; then printf '%s\tspotlightknowled\t%s\n' "$t" 47 >> "$sortie"; fi
      sleep 1
    else
      top -l 2 -s 2 -n 40 -o cpu -stats command,cpu 2>/dev/null | awk -v t="$(date +%s)" '
        /^COMMAND/ { n++; next }
        n==2 && NF >= 2 { cpu=$NF; sub(/%/,"",cpu); nom=$0; sub(/[ \t]+[0-9.]+%?[ \t]*$/,"",nom); sub(/^[ \t]+/,"",nom)
          if (cpu+0 > 0) printf "%s\t%s\t%s\n", t, nom, cpu }' >> "$sortie"
      sleep 2
    fi
  done
}

# LA PORTE, sur la fenêtre [début ; fin] : « OUVERTE|FERMÉE <raison> ; helper médiane max ; noms ; n échantillons ».
porte() {
  python3 - "$1" "$2" "$3" "$SEUIL_ETRANGER" "$SEUIL_HELPER" "$EXCLUS" <<'EOF'
import re, statistics, sys
chemin, debut, fin, seuil_e, seuil_h, exclus = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]), \
    float(sys.argv[5]), re.compile(sys.argv[6], re.I)
par_t = {}
for ligne in open(chemin, encoding="utf-8", errors="replace"):
    p = ligne.rstrip("\n").split("\t")
    if len(p) != 3:
        continue
    t, nom, cpu = float(p[0]), p[1].strip(), float(p[2])
    if debut <= t <= fin:
        par_t.setdefault(t, []).append((nom, cpu))
if not par_t:
    print("FERMÉE aucun échantillon de charge dans la fenêtre mesurée ; helper - - ; -")
    sys.exit()
helper, pire, noms = [], (0.0, ""), set()
for t, procs in sorted(par_t.items()):
    h = 0.0
    for nom, cpu in procs:
        if nom.lower().startswith("claude helper"):
            h += cpu
            noms.add(nom)
        elif not exclus.search(nom) and cpu > pire[0]:
            pire = (cpu, nom)
    helper.append(h)
raisons = []
if pire[0] > seuil_e:
    raisons.append("%s à %.1f %% (> %g)" % (pire[1], pire[0], seuil_e))
if max(helper) > seuil_h:
    raisons.append("Claude Helper à %.1f %% (> %g)" % (max(helper), seuil_h))
print("%s %s ; helper %.1f %.1f ; %s ; %d échantillons" % ("FERMÉE" if raisons else "OUVERTE",
      " et ".join(raisons) if raisons else "-", statistics.median(helper), max(helper),
      ",".join(sorted(noms)) or "-", len(helper)))
EOF
}

# Les lignes d'état du jeu (« [ … »), chiffres ôtés, triées, uniques : ce qui doit être identique d'une prise à l'autre
# d'un même bras.
etat() { grep '^\[' "$1" | grep -v '^\[godot_ai' | sed 's/[0-9][0-9.,]*/#/g' | sort -u; }

arret() { echo "✗ $*" | tee -a "$OUT/serie.txt"; exit 1; }

# ─── L'EN-TÊTE ───
if [ "$BLANC" != "1" ] && [ "$CLOUD" != "1" ]; then
  [ -d /tmp/candela-mac.lock ] || { echo "✗ le verrou du Mac n'est pas pris (mkdir /tmp/candela-mac.lock)"; exit 1; }
fi
if [ "$BLANC" != "1" ]; then
  for b in A B; do f="$(arbre_faux "$b")"; [ -z "$f" ] || { echo "✗ bras $b : $f"; exit 1; }; done
fi
if godot_ouvert; then echo "✗ un Godot est déjà ouvert"; exit 1; fi
ORDRE=(A B B A A B)
if [ -n "${ORDRE_COURT:-}" ]; then
  # shellcheck disable=SC2206
  ORDRE=($ORDRE_COURT)
fi
{ echo "série courte d'une version — $(TZ=Europe/Paris date '+%Y-%m-%d %H:%M:%S') (Paris)"
  echo "A (référence) : $A_HASH  $(git log --format='%s' -1 "$A_HASH" | cut -c1-70)"
  echo "B (candidate) : $B_HASH  $(git log --format='%s' -1 "$B_HASH" | cut -c1-70)"
  echo "arbres : $A_ARBRE · $B_ARBRE"
  echo "scène : bench_framerate.tscn -- --seconds $SECONDES --max-fps 0 $(scene) · rendu attendu « $RENDU »"
  echo "ordre : chauffe A, puis ${ORDRE[*]} · prolongation d'UN bloc B A si le rapport tombe dans [$PROLONGER_BAS ; $PROLONGER_HAUT]"
  echo "repos initial ${REPOS_INITIAL} s, avant chaque prise ${REPOS_PRISE} s · porte : étranger ≤ ${SEUIL_ETRANGER} %," \
       "Claude Helper ≤ ${SEUIL_HELPER} %, équilibre ${EQUILIBRE} points, ${REFAIRE_MAX} reprises au plus"
  [ "$BLANC" = "1" ] && echo "⚠ ESSAI À BLANC : ni Godot ni top — fausses prises, fausses charges"
  [ "$CLOUD" = "1" ] && echo "⚠ ESSAI DU CLOUD : le vrai banc, des charges SIMULÉES ; la cadence ne vaut rien ici"
} | tee "$OUT/serie.txt"

# ─── 1. LE REPOS INITIAL, relevé ───
echo "repos initial : ${REPOS_INITIAL} s sans rien lancer ($(TZ=Europe/Paris date +%H:%M:%S))" | tee -a "$OUT/serie.txt"
: > "$OUT/charge_repos.tsv"; rm -f "$OUT/.stop_repos"
releve "$OUT/charge_repos.tsv" "$OUT/.stop_repos" &
PID_RELEVE=$!
sleep "$REPOS_INITIAL"
touch "$OUT/.stop_repos"; wait "$PID_RELEVE" 2>/dev/null
if godot_ouvert; then arret "un Godot s'est ouvert pendant le repos initial : arrêt"; fi
python3 - "$OUT/charge_repos.tsv" <<'EOF' | tee -a "$OUT/serie.txt"
import statistics, sys
par_t = {}
for l in open(sys.argv[1], encoding="utf-8", errors="replace"):
    p = l.rstrip("\n").split("\t")
    if len(p) == 3 and p[1].lower().startswith("claude helper"):
        par_t[p[0]] = par_t.get(p[0], 0.0) + float(p[2])
v = [par_t[t] for t in sorted(par_t)]
print("Claude Helper pendant le repos : médiane %.1f %%, max %.1f %%" % (statistics.median(v), max(v)) if v
      else "Claude Helper pendant le repos : jamais vu")
EOF

# ─── 2. UNE PRISE : repos, thermique, banc, relevé, preuves, porte. 0 = retenue, 2 = refusée par la porte (à refaire). ───
prendre() {
  local nom="$1" bras="$2" j="$OUT/$1.txt" charge="$OUT/$1.charge.tsv" a
  a="$(arbre "$bras")"
  local calme=0
  while [ "$calme" -lt "$REPOS_PRISE" ]; do
    if godot_ouvert; then calme=0; else calme=$((calme + 1)); fi
    sleep 1
  done
  local th attente=0
  th="$(thermique)"
  while [ "$th" != "0" ]; do
    [ "$attente" -ge 600 ] && arret "$nom : le Mac ne revient pas à l'état thermique normal ($th) en dix minutes : arrêt"
    echo "  … $nom : état thermique $th, on attend" | tee -a "$OUT/serie.txt"
    sleep 30; attente=$((attente + 30)); th="$(thermique)"
  done
  if qui=$(present); then arret "$nom : quelqu'un est devant le Mac ($(echo "$qui" | tr '\n' ' ')) : arrêt"; fi
  if [ "$BLANC" != "1" ]; then local f; f="$(arbre_faux "$bras")"; [ -z "$f" ] || arret "$nom : $f"; fi
  : > "$charge"; rm -f "$OUT/.stop" "$OUT/.debut" "$OUT/.fin"
  releve "$charge" "$OUT/.stop" &
  local pid_releve=$!
  if [ "$BLANC" = "1" ]; then
    local base=85 med
    if [ "$bras" = "B" ]; then med="$(python3 -c "print(round($base * ${FAUX_RAPPORT:-0.99}) - $((RANDOM % 2)))")"
    else med=$((base - RANDOM % 2)); fi
    { echo "Manche lancée — armes : Pompe / Pompe (slugs pompe / pompe ; voulue : pompe)"
      echo "[usure] allumée — variante USURE_ESSAI posée"
      [ "$bras" = "B" ] && echo "[fusée cœur] point de braise rouge (2)" || echo "[fusée cœur] halo (1)"
      echo "Échauffement 30 s (…)"; sleep 1; echo "Mesure sur $SECONDES s…"; date +%s > "$OUT/.debut"; sleep 3
      echo "Rendu : $RENDU · caméras 2D J1 -45.0°, J2 135.0°"; echo "  FPS médian       : $med"
      echo "  FPS 1 % bas hors 10 s : $((70 - RANDOM % 4))  (…) — lu par le verdict"; date +%s > "$OUT/.fin"; } > "$j"
  else
    ( while [ ! -e "$OUT/.stop" ]; do
        [ -e "$OUT/.debut" ] || { grep -q "^Mesure sur" "$j" 2>/dev/null && date +%s > "$OUT/.debut"; }
        [ -e "$OUT/.fin" ] || { grep -q "FPS médian" "$j" 2>/dev/null && date +%s > "$OUT/.fin"; }
        sleep 0.5
      done ) &
    local pid_guet=$!
    # shellcheck disable=SC2046
    "$GODOT" --log-file "$JOURNAL_TMP" --path "$a" res://tools/bench_framerate.tscn -- \
      --seconds "$SECONDES" --max-fps 0 $(scene) > "$j" 2>&1
    sleep 1
    [ -e "$OUT/.fin" ] || date +%s > "$OUT/.fin"
    touch "$OUT/.stop"; wait "$pid_guet" 2>/dev/null
  fi
  touch "$OUT/.stop"; wait "$pid_releve" 2>/dev/null
  # Les preuves : la tête (relue APRÈS la prise aussi), la scène, les lignes d'état.
  if [ "$BLANC" != "1" ]; then local f; f="$(arbre_faux "$bras")"; [ -z "$f" ] || arret "$nom (après la prise) : $f"; fi
  echo "tête $(hash_de "$bras") · arbre $a" >> "$j"
  if grep -qE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; then
    grep -m3 -E "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; arret "$nom : erreur au journal"
  fi
  grep -qF "Rendu : $RENDU" "$j" || arret "$nom : la vue n'est pas « $RENDU »"
  grep -qF "slugs pompe / pompe" "$j" || arret "$nom : les deux joueurs ne sont pas au pompe"
  if [ -n "$(preuve_bras "$bras")" ]; then
    grep -qF "$(preuve_bras "$bras")" "$j" || arret "$nom : le jeu n'atteste pas « $(preuve_bras "$bras") »"
  fi
  etat "$j" > "$OUT/$nom.etat"
  if [ -e "$OUT/etat_$bras.ref" ]; then
    if ! diff -q "$OUT/etat_$bras.ref" "$OUT/$nom.etat" > /dev/null; then
      diff "$OUT/etat_$bras.ref" "$OUT/$nom.etat" | head -6 | tee -a "$OUT/serie.txt"
      arret "$nom : les lignes d'état du jeu ne sont plus celles des autres prises du bras $bras"
    fi
  else
    cp "$OUT/$nom.etat" "$OUT/etat_$bras.ref"
  fi
  [ -e "$OUT/.debut" ] || arret "$nom : le début de la mesure n'a pas été vu (« Mesure sur »)"
  local med bas p
  med="$(sed -n 's/.*FPS médian *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  bas="$(sed -n 's/.*FPS 1 % bas hors 10 s *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  [ -n "$med" ] && [ -n "$bas" ] || arret "$nom : médiane ou 1 % bas illisible"
  p="$(porte "$charge" "$(cat "$OUT/.debut")" "$(cat "$OUT/.fin")")"
  printf '%-10s %s  médiane %4s   1 %% bas (hors 10 s) %4s   thermique %s   porte %s\n' "$nom" "$bras" "$med" "$bas" "$th" "$p" \
    | tee -a "$OUT/serie.txt"
  case "$p" in
    OUVERTE*)
      [ "$nom" = "chauffe" ] || echo "$bras $med $bas $(echo "$p" | sed -n 's/.*; helper \([0-9.]*\) \([0-9.]*\) ;.*/\1 \2/p') $nom" \
        >> "$OUT/resultats.txt"
      return 0 ;;
    *) return 2 ;;
  esac
}

# Une prise à sa place, refaite si la porte la refuse.
k=0
prise_a_sa_place() {
  local bras="$1" essai=0
  k=$((k + 1))
  until prendre "$(printf '%02d' $k)_${bras}$([ $essai -gt 0 ] && echo "_r$essai")" "$bras"; do
    essai=$((essai + 1))
    [ "$essai" -gt "$REFAIRE_MAX" ] && arret "prise $k ($bras) refusée $essai fois : SÉRIE ARRÊTÉE, SANS VERDICT"
    echo "  ↻ prise $k ($bras) refusée par la porte : refaite à sa place (reprise $essai sur $REFAIRE_MAX)" | tee -a "$OUT/serie.txt"
  done
}

# LE VERDICT : imprime le tableau et, sur la dernière ligne, « RAPPORT <r> » (ou « RAPPORT - » sans verdict).
verdict() {
  python3 - "$OUT/resultats.txt" "$EQUILIBRE" <<'EOF'
import statistics, sys
lignes = [l.split() for l in open(sys.argv[1]) if l.strip()]
equilibre = float(sys.argv[2])
par = {}
for b, med, bas, hmed, hmax, nom in lignes:
    par.setdefault(b, []).append((int(med), int(bas), float(hmed), float(hmax), nom))
if "A" not in par or "B" not in par:
    print("il manque un bras : aucun verdict\nRAPPORT -")
    sys.exit()
ref = [m for m, *_ in par["A"]]
tient_ref = max(ref) / min(ref) <= 1.05
mA = statistics.median(ref)
hA = statistics.median([x[2] for x in par["A"]])
hB = statistics.median([x[2] for x in par["B"]])
eq = abs(hA - hB) <= equilibre
for b in ("A", "B"):
    meds = [x[0] for x in par[b]]
    bas = [x[1] for x in par[b]]
    print("%s  prises %-28s médianes %-16s 1 %% bas %-16s → médiane %5.1f · 1 %% bas médian %5.1f · Claude Helper %.1f %% (max %.1f)"
          % (b, " ".join(x[4] for x in par[b]), meds, bas, statistics.median(meds), statistics.median(bas),
             statistics.median([x[2] for x in par[b]]), max(x[3] for x in par[b])))
mB = statistics.median([x[0] for x in par["B"]])
basB = statistics.median([x[1] for x in par["B"]])
r = mB / mA
ms = 1000.0 / mB - 1000.0 / mA
print("A tient dans 5 %% : %s (plus rapide / plus lente %.3f) · bras équilibrés : %s (écart %.1f points)"
      % ("oui" if tient_ref else "NON", max(ref) / min(ref), "oui" if eq else "NON", abs(hA - hB)))
print("rapport B/A %.3f (%+.2f ms par image) · 1 %% bas médian de B %.1f" % (r, ms, basB))
if not (tient_ref and eq):
    print("SANS VERDICT : " + " et ".join(([] if tient_ref else ["la référence ne tient pas dans 5 %"])
          + ([] if eq else ["la charge de Claude Helper diffère de plus de %g points entre bras" % equilibre])))
    print("RAPPORT -")
else:
    ok = r >= 0.970 and basB > 60
    print("VERDICT : B %s (règle 278 : rapport ≥ 0,970 ET 1 %% bas médian > 60)" % ("TIENT" if ok else "NE TIENT PAS"))
    if len(ref) < 3:
        print("⚠ moins de trois prises par bras : vérification de la mécanique seulement, AUCUN verdict (ORDRE_COURT).")
    print("RAPPORT %.4f" % r)
EOF
}

: > "$OUT/resultats.txt"; rm -f "$OUT"/etat_*.ref
prendre chauffe A || true
rm -f "$OUT/etat_A.ref"   # la chauffe ne fixe pas la référence d'état (elle peut compiler des shaders que les autres non)
for bras in "${ORDRE[@]}"; do prise_a_sa_place "$bras"; done

echo | tee -a "$OUT/serie.txt"
V="$(verdict)"
R="$(echo "$V" | sed -n 's/^RAPPORT //p')"
if [ "$R" != "-" ] && [ -z "${ORDRE_COURT:-}" ] \
   && python3 -c "import sys; sys.exit(0 if $PROLONGER_BAS <= $R <= $PROLONGER_HAUT else 1)"; then
  # Le verdict des six prises n'est que provisoire : celui de la prolongation le remplace.
  echo "$V" | grep -v '^RAPPORT' | sed 's/^VERDICT :/verdict PROVISOIRE, remplacé par celui de la prolongation :/' \
    | tee -a "$OUT/serie.txt"
  echo "⤷ PROLONGATION : le rapport $R tombe dans [$PROLONGER_BAS ; $PROLONGER_HAUT] — UN bloc B A de plus, jamais davantage" \
    | tee -a "$OUT/serie.txt"
  for bras in B A; do prise_a_sa_place "$bras"; done
  echo | tee -a "$OUT/serie.txt"
  verdict | grep -v '^RAPPORT' | tee -a "$OUT/serie.txt"
else
  echo "$V" | grep -v '^RAPPORT' | tee -a "$OUT/serie.txt"
fi

# Ce que le jeu dit de la différence entre les deux versions (ses lignes d'état, chiffres ôtés).
{ echo; echo "lignes d'état propres à A (« < ») et à B (« > ») — ce que la version change, dit par le jeu :"
  d="$(diff "$OUT/etat_A.ref" "$OUT/etat_B.ref" | grep '^[<>]')"
  if [ -n "$d" ]; then echo "$d"
  else echo "  (aucune : rien dans le journal ne distingue A de B ; la preuve de la tête ne repose que sur le hash de l'arbre)"; fi
  echo "fin : $(TZ=Europe/Paris date '+%Y-%m-%d %H:%M:%S') (Paris)"
} | tee -a "$OUT/serie.txt"
if [ "$SECONDES" -lt 20 ]; then
  echo "⚠ SECONDES=$SECONDES : le 1 % bas « hors 10 s » n'a presque aucune image — ces chiffres ne valent rien." | tee -a "$OUT/serie.txt"
fi
exit
}
