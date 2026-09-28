#!/usr/bin/env bash
# LA SÉRIE DE CADENCE DE TOUS LES ESSAIS (session cloud « série-essais », 2026-09-28). À lancer sur le Mac d'Adrien, une
# série à la fois, quand le Mac est libre. Elle répond, essai par essai, à la question que pose chaque « oui » d'Adrien (Q37,
# Q39, Q40) : l'essai allumé tient-il la RÈGLE 278 — au moins 0,970 de la cadence sans lui, et un 1 % bas médian ≥ 60 ?
# Le cloud ne mesure pas le temps : cette série est la seule qui le dira.
#
# La scène de la règle 278 : le pompe sous une fusée, vue unique, lacet 45° B, usure au défaut, masque de la fumée éteint
# (le défaut), sur l'Arène Standard (la carte que le banc prend toujours : `MapData` ne garde pas la sélection d'un lancement
# à l'autre) — `bench_framerate.gd --fusee --vue-unique --classe=pompe`.
#
# TROIS SÉRIES, chacune avec SA référence M0 (un rapport ne se lit qu'entre prises d'une même séance) :
#   SERIE=A  les essais PAR PIXEL (shaders) — M0, FA, MA, EN, CS, LC      six bras, ~1 h 45
#   SERIE=B  les essais de GÉOMÉTRIE, et TOUT — M0, TU, EG, MM, TOUT       cinq bras, ~1 h 30
#   SERIE=C  (facultative) l'ÉCRAN SCINDÉ, où la géométrie se paie deux fois — M0, TU, MM, TOUT, sans `--vue-unique`
# Les bras, chacun par SES drapeaux, chacun PROUVÉ par ce que le jeu imprime (et par ce qu'il N'imprime PAS : un drapeau
# perdu se déguise en l'autre branche d'une comparaison) :
#   M0    aucun essai
#   FA    --faisceau             « [faisceau] allumé »              le cœur chaud à la lampe (Q37)
#   MA    --mannequin            « [mannequin] allumé »             (Q37)
#   EN    --encre-essai          « [encre] allumée — variante ENCRE_ESSAI posée (#define … »            (Q37)
#   CS    --corps-soi-sombre     « [corps soi sombre] allumé — variante CORPS_SOI_SOMBRE posée (#define … »   (Q39)
#   LC    --lampe-claire         « [lampe claire] allumée »         la lampe crème (Q40)
#   TU    --tuyaux-essai         « [tuyaux] allumés — N triangles sur la carte « 00000001 » », N > 0     (Q37)
#   EG    --enseignes-essai      « [enseignes] allumées — N triangles … », N > 0                         (Q37)
#   MM    --murs-meubles-essai   « [murs meublés] allumés — N triangles … », N > 0
#   TOUT  les dix essais ensemble, pochoirs et sol marqué compris : « et si je dis oui à tout ? »
# Les pochoirs (`--pochoirs-essai`) et le sol marqué (`--sol-marque-essai`) n'ont pas de bras à eux : cuits une fois par
# carte dans la MÊME texture du décor, ils ne coûtent rien par image (appels, objets, primitives et mémoire vidéo relevés
# égaux dans le cloud : docs/iso/cloud/serie-essais/RAPPORT.md) ; ils sont dans TOUT, prouvés par « [pochoirs] allumés —
# N pochoir(s) » et « [sol marqué] allumé — N marque(s) », N > 0.
#
# L'ORDRE EN MIROIR, quatre blocs : a b c … | … c b a | a b c … | … c b a — même position moyenne pour chaque bras, quatre
# prises chacun ; plus une chauffe M0 non comptée. Avant le repos, UNE VÉRIFICATION (bras TOUT, 5 s, non comptée) : si un
# essai n'imprime pas sa ligne ou si le jeu tombe en erreur, la série s'arrête AVANT les 20 minutes de repos, pas au
# milieu.
#
# LA PORTE (ordre 432 de la session coordinatrice, 27/09 01:39), reprise telle quelle de tools/masque_fumee/serie_mac_2.sh :
#   1. REPOS COMPLET de 20 minutes avant la première prise (REPOS_INITIAL, en secondes), la charge relevée pendant ce repos ;
#   2. 90 SECONDES SANS AUCUN GODOT avant chaque prise (REPOS_PRISE) — docs/iso/iso12/mesurer_une_cadence.md, § 6 ;
#   3. la porte NE JUGE QUE LA FENÊTRE MESURÉE : de « Mesure sur … » (après les 30 s de chauffe du banc) à « FPS médian » ;
#      elle prend le MAXIMUM, pas la moyenne (§ 7) ;
#   4. tout processus étranger au-dessus de 20 % d'un cœur dans la fenêtre : prise REFUSÉE ; sauf Claude Helper (tous ses
#      processus sommés échantillon par échantillon), ADMIS sous 30 %, relevé à chaque prise (médiane et maximum) ;
#   5. une prise refusée SE REFAIT À SA PLACE, jusqu'à quatre fois ; à la cinquième refusée, la série s'arrête sans verdict ;
#   6. ÉQUILIBRE DES BRAS À 2 POINTS : la médiane de la charge de Claude Helper de chaque bras à 2 points au plus de celle de
#      M0, sinon SANS VERDICT.
# Ne comptent pas comme étrangers : Godot, WindowServer, top, kernel_task (réglable : EXCLUS).
#
# Ce qui ARRÊTE la série (une faute de montage, pas du bruit) : une erreur de shader ou de script ; une ligne « ✗ » du banc
# (il refuse lui-même son chiffre, p. ex. la vue iso éteinte pendant la mesure) ; la ligne d'un essai du bras absente, ou
# celle d'un essai HORS du bras présente ; une carte autre que CARTE ; « [fumée masque] éteint » absent ; la vue qui n'est
# pas « iso lacet 45° B » ; l'usure éteinte ; une médiane illisible ; quelqu'un devant le Mac.
# Le verdict (règle 278), bras par bras : VALIDE si les quatre M0 tiennent dans 5 % et les bras sont équilibrés ; un bras
# PASSE si sa médiane des médianes ≥ 0,970 × celle de M0 ET son 1 % bas médian (hors 10 s) ≥ 60.
#
#     mkdir /tmp/candela-mac.lock
#     SERIE=A tools/serie_essais/serie_mac_essais.sh /tmp/serie-essais-A
#     SERIE=B tools/serie_essais/serie_mac_essais.sh /tmp/serie-essais-B
#     rmdir /tmp/candela-mac.lock
#     ESSAI_A_BLANC=1 SERIE=A tools/serie_essais/serie_mac_essais.sh /tmp/essai   # la mécanique seule : ni Godot ni top
#     ESSAI_CLOUD=1 SERIE=B ORDRE_COURT="M0 TU EG MM TOUT" SECONDES=5 GODOT=godot \
#       xvfb-run -a -s "-screen 0 1920x1080x24" tools/serie_essais/serie_mac_essais.sh /tmp/essai   # le vrai banc, Linux
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
OUT="${1:?dossier de sortie}"
mkdir -p "$OUT"
SERIE="${SERIE:?SERIE=A, B ou C}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SECONDES="${SECONDES:-60}"
BLANC="${ESSAI_A_BLANC:-0}"
CLOUD="${ESSAI_CLOUD:-0}"
if [ "$BLANC" = "1" ] || [ "$CLOUD" = "1" ]; then
  REPOS_INITIAL="${REPOS_INITIAL:-3}"; REPOS_PRISE="${REPOS_PRISE:-1}"
else
  REPOS_INITIAL="${REPOS_INITIAL:-1200}"; REPOS_PRISE="${REPOS_PRISE:-90}"
fi
SEUIL_ETRANGER="${SEUIL_ETRANGER:-20}"
SEUIL_HELPER="${SEUIL_HELPER:-30}"
EQUILIBRE="${EQUILIBRE:-2}"
REFAIRE_MAX="${REFAIRE_MAX:-4}"
EXCLUS="${EXCLUS:-^(godot|windowserver|top|kernel_task)}"
CARTE="${CARTE:-00000001}"
JOURNAL_TMP="/tmp/candela-serie-essais.log"

# LES ESSAIS : clé → drapeau → ce que le jeu imprime quand il est allumé (expression étendue, début de ligne). La garde
# headless `tools/test_serie_essais.gd` relit ce tableau et vérifie que chaque ligne existe dans le code de son essai.
ESSAIS="FA MA EN CS LC TU EG MM PO SM"
drapeau_essai() {
  case "$1" in
    FA) echo "--faisceau" ;; MA) echo "--mannequin" ;; EN) echo "--encre-essai" ;; CS) echo "--corps-soi-sombre" ;;
    LC) echo "--lampe-claire" ;; TU) echo "--tuyaux-essai" ;; EG) echo "--enseignes-essai" ;;
    MM) echo "--murs-meubles-essai" ;; PO) echo "--pochoirs-essai" ;; SM) echo "--sol-marque-essai" ;;
  esac
}
# Allumé : la ligne, avec ce qu'elle doit dire (un compte non nul, la variante réellement posée).
preuve_essai() {
  case "$1" in
    FA) echo '^\[faisceau\] allumé' ;;
    MA) echo '^\[mannequin\] allumé' ;;
    EN) echo '^\[encre\] allumée — variante ENCRE_ESSAI posée \(#define ENCRE_ESSAI' ;;
    CS) echo '^\[corps soi sombre\] allumé — variante CORPS_SOI_SOMBRE posée \(#define CORPS_SOI_SOMBRE' ;;
    LC) echo '^\[lampe claire\] allumée' ;;
    TU) echo '^\[tuyaux\] allumés — [1-9][0-9]* triangles' ;;
    EG) echo '^\[enseignes\] allumées — [1-9][0-9]* triangles' ;;
    MM) echo '^\[murs meublés\] allumés — [1-9][0-9]* triangles' ;;
    PO) echo '^\[pochoirs\] allumés — [1-9][0-9]* pochoir' ;;
    SM) echo '^\[sol marqué\] allumé — [1-9][0-9]* marque' ;;
  esac
}
# Éteint : le simple préfixe ne doit apparaître nulle part.
trace_essai() { preuve_essai "$1" | sed -E 's/ (allumée?s?) .*/ \1/'; }
essais_du_bras() {
  case "$1" in
    M0) echo "" ;; TOUT) echo "$ESSAIS" ;; *) echo "$1" ;;
  esac
}
drapeaux() { local e; for e in $(essais_du_bras "$1"); do printf '%s ' "$(drapeau_essai "$e")"; done; }

case "$SERIE" in
  A) BRAS="M0 FA MA EN CS LC"; VUE="--vue-unique" ;;
  B) BRAS="M0 TU EG MM TOUT"; VUE="--vue-unique" ;;
  C) BRAS="M0 TU MM TOUT"; VUE="" ;;
  *) echo "✗ SERIE=$SERIE : A, B ou C"; exit 1 ;;
esac
# L'ordre en miroir : BRAS, BRAS renversé, BRAS, BRAS renversé.
read -r -a _b <<< "$BRAS"
_r=(); for ((i=${#_b[@]}-1; i>=0; i--)); do _r+=("${_b[i]}"); done
ORDRE=("${_b[@]}" "${_r[@]}" "${_b[@]}" "${_r[@]}")
if [ -n "${ORDRE_COURT:-}" ]; then
  # shellcheck disable=SC2206
  ORDRE=($ORDRE_COURT)
fi

godot_ouvert() {
  if [ "$CLOUD" = "1" ]; then
    pgrep -x "$(basename "$GODOT" | cut -c1-15)" > /dev/null \
      || pgrep -x "$(basename "$(readlink -f "$(command -v "$GODOT")")" | cut -c1-15)" > /dev/null
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

# LE RELEVÉ DE CHARGE (repris de serie_mac_2.sh) : « époque<TAB>processus<TAB>%cpu », seconde passe de `top -l 2` seulement.
releve() {
  local sortie="$1" stop="$2"
  while [ ! -e "$stop" ]; do
    if [ "$BLANC" = "1" ] || [ "$CLOUD" = "1" ]; then
      local t; t=$(date +%s)
      printf '%s\tClaude Helper (R\t%s\n' "$t" "$((8 + RANDOM % 19))" >> "$sortie"
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

# LA PORTE, sur la fenêtre [début ; fin] (époques) : imprime « OUVERTE|FERMÉE <raison> ; helper médiane max ; noms ».
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

# LES PREUVES D'UN BRAS dans le journal "$2" : rend 0, ou imprime ce qui manque et rend 1.
prouver() {
  local bras="$1" j="$2" e dedans faute=0 cartes
  for e in $ESSAIS; do
    dedans=0
    case " $(essais_du_bras "$bras") " in *" $e "*) dedans=1 ;; esac
    if [ "$dedans" = "1" ]; then
      grep -qE "$(preuve_essai "$e")" "$j" || { echo "le jeu n'atteste pas $e : « $(preuve_essai "$e") » absent"; faute=1; }
    else
      ! grep -qE "$(trace_essai "$e")" "$j" || { echo "$e est allumé HORS de son bras : « $(grep -m1 -E "$(trace_essai "$e")" "$j")"; faute=1; }
    fi
  done
  cartes="$(sed -n 's/.* sur la carte « \([^»]*\) ».*/\1/p' "$j" | sort -u | tr '\n' ' ')"
  if [ -n "$cartes" ] && [ "$cartes" != "$CARTE " ]; then echo "la carte n'est pas « $CARTE » : $cartes"; faute=1; fi
  grep -q "^\[fumée masque\] éteint" "$j" || { echo "« [fumée masque] éteint » absent (le masque n'est pas au défaut)"; faute=1; }
  grep -q "Rendu : iso lacet 45° B" "$j" || { echo "la vue n'est pas « iso lacet 45° B »"; faute=1; }
  grep -q "^\[usure\] allumée" "$j" || { echo "l'usure n'est pas allumée"; faute=1; }
  if [ -n "$VUE" ]; then
    grep -q "^VUE UNIQUE" "$j" || { echo "la vue unique n'a pas été posée"; faute=1; }
  else
    ! grep -q "^VUE UNIQUE" "$j" || { echo "la vue unique a été posée dans la série de l'écran scindé"; faute=1; }
  fi
  if grep -q "^✗" "$j"; then echo "le banc refuse son chiffre : $(grep -m1 "^✗" "$j")"; faute=1; fi
  if grep -qE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; then
    echo "erreur au journal : $(grep -m1 -E "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j")"; faute=1
  fi
  return $faute
}

banc() {  # banc <bras> <secondes> <journal>
  # shellcheck disable=SC2046
  "$GODOT" --log-file "$JOURNAL_TMP" --path . res://tools/bench_framerate.tscn -- \
    --seconds "$2" --max-fps 0 --fusee $VUE --classe=pompe $(drapeaux "$1") > "$3" 2>&1
}

faux_journal() {  # à blanc : ce que le banc imprimerait
  local bras="$1" e
  echo "Échauffement 30 s (…)"; sleep 1; echo "Mesure sur $SECONDES s…"; date +%s > "$OUT/.debut"; sleep 3
  [ -n "$VUE" ] && echo "VUE UNIQUE: seconde vue fermee, rendu par la RACINE"
  echo "[fumée masque] éteint (…)"; echo "[usure] allumée — variante USURE_ESSAI posée (…)"
  for e in $(essais_du_bras "$bras"); do
    case "$e" in
      FA) echo "[faisceau] allumé — le cœur chaud seul, sans rayon" ;;
      MA) echo "[mannequin] allumé — les corps en mannequins (ISO13 lot A)" ;;
      EN) echo "[encre] allumée — variante ENCRE_ESSAI posée (#define ENCRE_ESSAI dans son code)" ;;
      CS) echo "[corps soi sombre] allumé — variante CORPS_SOI_SOMBRE posée (#define CORPS_SOI_SOMBRE dans son code)" ;;
      LC) echo "[lampe claire] allumée — posée sur le sol et les murs (force 1)" ;;
      TU) echo "[tuyaux] allumés — 13800 triangles sur la carte « $CARTE »" ;;
      EG) echo "[enseignes] allumées — 8 triangles sur la carte « $CARTE »" ;;
      MM) echo "[murs meublés] allumés — 7088 triangles sur la carte « $CARTE » en 4 nœud(s)" ;;
      PO) echo "[pochoirs] allumés — 4 pochoir(s) sur la carte « $CARTE »" ;;
      SM) echo "[sol marqué] allumé — 6 marque(s) sur la carte « $CARTE »" ;;
    esac
  done
  echo "Rendu : iso lacet 45° B · caméras 2D"; echo "  FPS médian       : $((80 - ${#bras} - RANDOM % 3))"
  echo "  FPS 1 % bas hors 10 s : $((70 - RANDOM % 4))  (…) — lu par le verdict"; date +%s > "$OUT/.fin"
}

if [ "$BLANC" != "1" ] && [ "$CLOUD" != "1" ]; then
  [ -d /tmp/candela-mac.lock ] || { echo "✗ le verrou du Mac n'est pas pris (mkdir /tmp/candela-mac.lock)"; exit 1; }
fi
if godot_ouvert; then echo "✗ un Godot est déjà ouvert"; exit 1; fi
{ echo "série $SERIE : bras $BRAS · vue ${VUE:-écran scindé} · carte $CARTE"
  echo "base : $(git log --oneline -1 | cut -c1-70) · diff : $(git diff --stat | tail -1)"
  echo "début : $(TZ=Europe/Paris date '+%Y-%m-%d %H:%M:%S') (Paris) · SECONDES=$SECONDES · repos initial ${REPOS_INITIAL} s," \
       "avant chaque prise ${REPOS_PRISE} s · porte : étranger ≤ ${SEUIL_ETRANGER} %, Claude Helper ≤ ${SEUIL_HELPER} %," \
       "équilibre ${EQUILIBRE} points, ${REFAIRE_MAX} reprises au plus"
  echo "ordre : ${ORDRE[*]}"
  [ "$BLANC" = "1" ] && echo "⚠ ESSAI À BLANC : ni Godot ni top — fausses prises, fausses charges"
  [ "$CLOUD" = "1" ] && echo "⚠ ESSAI DU CLOUD : le vrai banc, des charges SIMULÉES ; la cadence ne vaut rien ici"
} | tee "$OUT/serie.txt"

# 0. LA VÉRIFICATION, AVANT LE REPOS : le bras le plus chargé de la série (TOUT, ou le dernier), 5 s, non comptée. Toutes
# les lignes, aucune erreur — sinon rien ne sert d'attendre vingt minutes.
VERIF="${_b[${#_b[@]}-1]}"
echo "vérification avant le repos : bras $VERIF, 5 s ($(TZ=Europe/Paris date +%H:%M:%S))" | tee -a "$OUT/serie.txt"
if [ "$BLANC" = "1" ]; then
  faux_journal "$VERIF" > "$OUT/verification.txt"
else
  banc "$VERIF" 5 "$OUT/verification.txt"
fi
if ! fautes="$(prouver "$VERIF" "$OUT/verification.txt")"; then
  echo "✗ vérification : $fautes" | tee -a "$OUT/serie.txt"; echo "✗ SÉRIE NON LANCÉE" | tee -a "$OUT/serie.txt"; exit 1
fi
grep -E "^\[(faisceau|mannequin|encre|corps soi sombre|lampe claire|tuyaux|enseignes|murs meublés|pochoirs|sol marqué)\]" \
  "$OUT/verification.txt" | sed 's/^/  ✓ /' | tee -a "$OUT/serie.txt"

# 1. LE REPOS COMPLET, relevé.
echo "repos complet : ${REPOS_INITIAL} s sans rien lancer ($(TZ=Europe/Paris date +%H:%M:%S))" | tee -a "$OUT/serie.txt"
: > "$OUT/charge_repos.tsv"
rm -f "$OUT/.stop_repos"
releve "$OUT/charge_repos.tsv" "$OUT/.stop_repos" &
PID_RELEVE=$!
sleep "$REPOS_INITIAL"
touch "$OUT/.stop_repos"; wait "$PID_RELEVE" 2>/dev/null
if godot_ouvert; then echo "✗ un Godot s'est ouvert pendant le repos complet : arrêt" | tee -a "$OUT/serie.txt"; exit 1; fi
python3 - "$OUT/charge_repos.tsv" <<'EOF' | tee -a "$OUT/serie.txt"
import statistics, sys
par_t, noms = {}, {}
for l in open(sys.argv[1], encoding="utf-8", errors="replace"):
    p = l.rstrip("\n").split("\t")
    if len(p) == 3 and p[1].lower().startswith("claude helper"):
        par_t[p[0]] = par_t.get(p[0], 0.0) + float(p[2])
        noms[p[1]] = max(noms.get(p[1], 0.0), float(p[2]))
if par_t:
    v = [par_t[t] for t in sorted(par_t)]
    tiers = max(1, len(v) // 3)
    print("Claude Helper pendant le repos : médiane %.1f %%, max %.1f %% ; premier tiers %.1f, dernier tiers %.1f ; processus : %s"
          % (statistics.median(v), max(v), statistics.median(v[:tiers]), statistics.median(v[-tiers:]),
             ", ".join("%s (max %.1f)" % kv for kv in sorted(noms.items()))))
else:
    print("Claude Helper pendant le repos : jamais vu")
EOF

# 2. UNE PRISE, portée. Rend 0 si retenue, 2 si la porte l'a refusée (à refaire) ; ARRÊTE la série sur une faute de montage.
prendre() {
  local nom="$1" bras="$2" j="$OUT/$1.txt" charge="$OUT/$1.charge.tsv"
  local calme=0
  while [ "$calme" -lt "$REPOS_PRISE" ]; do
    if godot_ouvert; then calme=0; else calme=$((calme + 1)); fi
    sleep 1
  done
  if qui=$(present); then echo "✗ $nom : quelqu'un est devant le Mac ($(echo $qui | tr '\n' ' ')) : arrêt" | tee -a "$OUT/serie.txt"; exit 1; fi
  : > "$charge"; rm -f "$OUT/.stop" "$OUT/.debut" "$OUT/.fin"
  releve "$charge" "$OUT/.stop" &
  local pid_releve=$!
  if [ "$BLANC" = "1" ]; then
    faux_journal "$bras" > "$j"
  else
    ( while [ ! -e "$OUT/.stop" ]; do
        [ -e "$OUT/.debut" ] || { grep -q "^Mesure sur" "$j" 2>/dev/null && date +%s > "$OUT/.debut"; }
        [ -e "$OUT/.fin" ] || { grep -q "FPS médian" "$j" 2>/dev/null && date +%s > "$OUT/.fin"; }
        sleep 0.5
      done ) &
    local pid_guet=$!
    banc "$bras" "$SECONDES" "$j"
    sleep 1
    [ -e "$OUT/.fin" ] || date +%s > "$OUT/.fin"
    touch "$OUT/.stop"; wait "$pid_guet" 2>/dev/null
  fi
  touch "$OUT/.stop"; wait "$pid_releve" 2>/dev/null
  local fautes
  if ! fautes="$(prouver "$bras" "$j")"; then
    echo "✗ $nom ($bras) : $fautes" | tr '\n' ' ' | tee -a "$OUT/serie.txt"; echo | tee -a "$OUT/serie.txt"
    echo "✗ SÉRIE ARRÊTÉE : une faute de montage ne se refait pas" | tee -a "$OUT/serie.txt"; exit 1
  fi
  [ -e "$OUT/.debut" ] || { echo "✗ $nom : le début de la mesure n'a pas été vu (« Mesure sur »)" | tee -a "$OUT/serie.txt"; exit 1; }
  local med bas p
  med="$(sed -n 's/.*FPS médian *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  bas="$(sed -n 's/.*FPS 1 % bas hors 10 s *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  [ -n "$med" ] && [ -n "$bas" ] || { echo "✗ $nom : médiane ou 1 % bas illisible" | tee -a "$OUT/serie.txt"; exit 1; }
  p="$(porte "$charge" "$(cat "$OUT/.debut")" "$(cat "$OUT/.fin")")"
  printf '%-10s %-4s médiane %4s   1 %% bas (hors 10 s) %4s   porte %s\n' "$nom" "$bras" "$med" "$bas" "$p" \
    | tee -a "$OUT/serie.txt"
  case "$p" in
    OUVERTE*)
      [ "$nom" = "chauffe" ] || echo "$bras $med $bas $(echo "$p" | sed -n 's/.*; helper \([0-9.]*\) \([0-9.]*\) ;.*/\1 \2/p')" \
        >> "$OUT/resultats.txt"
      return 0 ;;
    *) return 2 ;;
  esac
}

: > "$OUT/resultats.txt"
prendre chauffe M0 || true
k=0
for bras in "${ORDRE[@]}"; do
  k=$((k + 1))
  essai=0
  until prendre "$(printf '%02d' $k)_${bras}$([ $essai -gt 0 ] && echo "_r$essai")" "$bras"; do
    essai=$((essai + 1))
    if [ "$essai" -gt "$REFAIRE_MAX" ]; then
      echo "✗ prise $k ($bras) refusée $essai fois : SÉRIE ARRÊTÉE, SANS VERDICT" | tee -a "$OUT/serie.txt"; exit 1
    fi
    echo "  ↻ prise $k ($bras) refusée par la porte : refaite à sa place (reprise $essai sur $REFAIRE_MAX)" | tee -a "$OUT/serie.txt"
  done
done

python3 - "$OUT/resultats.txt" "$BRAS" "$EQUILIBRE" "$SERIE" <<'EOF' | tee -a "$OUT/serie.txt"
import statistics, sys
lignes = [l.split() for l in open(sys.argv[1]) if l.strip()]
bras = sys.argv[2].split()
equilibre = float(sys.argv[3])
noms = {"M0": "sans essai", "FA": "le cœur chaud à la lampe (--faisceau)", "MA": "le mannequin (--mannequin)",
        "EN": "l'encre (--encre-essai)", "CS": "son corps sombre à liseré (--corps-soi-sombre)",
        "LC": "la lampe crème (--lampe-claire)", "TU": "les tuyaux (--tuyaux-essai)",
        "EG": "les enseignes (--enseignes-essai)", "MM": "les murs meublés (--murs-meubles-essai)",
        "TOUT": "TOUT (les dix essais, pochoirs et sol marqué compris)"}
par = {}
for b, med, bas, hmed, hmax in lignes:
    par.setdefault(b, []).append((int(med), int(bas), float(hmed), float(hmax)))
ref = [m for m, _, _, _ in par["M0"]]
tient = max(ref) / min(ref) <= 1.05
m0 = statistics.median(ref)
h0 = statistics.median([h for _, _, h, _ in par["M0"]])
print("\nSÉRIE %s — référence M0 : %s — %s (plus rapide / plus lente %.3f, seuil 1,05)"
      % (sys.argv[4], ref, "tient" if tient else "NE TIENT PAS", max(ref) / min(ref)))
equilibres = True
verdicts = []
for b in bras:
    if b not in par:
        continue
    meds = [m for m, _, _, _ in par[b]]
    bas = statistics.median([x for _, x, _, _ in par[b]])
    h = statistics.median([x for _, _, x, _ in par[b]])
    hmax = max(x for _, _, _, x in par[b])
    eq = abs(h - h0) <= equilibre
    equilibres = equilibres and eq
    r = statistics.median(meds) / m0
    ms = 1000.0 / statistics.median(meds) - 1000.0 / m0
    ok = r >= 0.970 and bas >= 60
    print("%-4s médianes %-18s médiane des médianes %5.1f · rapport %.3f (%+.2f ms) · 1 %% bas médian %4.1f · Claude Helper"
          " médiane %.1f %% (max %.1f)%s · %s"
          % (b, meds, statistics.median(meds), r, ms, bas, h, hmax, "" if eq else " ⚠ DÉSÉQUILIBRÉ",
             "—" if b == "M0" else ("PASSE" if ok else "ÉCHOUE")))
    if b != "M0":
        verdicts.append((b, ok, r, bas))
valide = tient and equilibres
print("SÉRIE %s %s" % (sys.argv[4], "VALIDE" if valide else "SANS VERDICT : " + " et ".join(
    ([] if tient else ["la référence ne tient pas dans 5 %"])
    + ([] if equilibres else ["la charge de Claude Helper diffère de plus de %g points entre bras" % equilibre]))))
if valide:
    print("\nEN CLAIR, essai par essai (règle 278 : ≥ 0,970 de la cadence sans essai, 1 % bas ≥ 60) :")
    for b, ok, r, bas in verdicts:
        print("  %s %s : %s (%.1f %% de la cadence, 1 %% bas %.0f)"
              % ("✓" if ok else "✗", noms.get(b, b), "peut être allumé par défaut" if ok else "NE PASSE PAS",
                 100.0 * r, bas))
if len(ref) < 3:
    print("⚠ moins de trois prises de référence : vérification de la mécanique seulement, AUCUN verdict (ORDRE_COURT).")
EOF
if [ "$SECONDES" -lt 20 ]; then
  echo "⚠ SECONDES=$SECONDES : le 1 % bas « hors 10 s » n'a presque aucune image — ces chiffres ne valent rien." | tee -a "$OUT/serie.txt"
fi
