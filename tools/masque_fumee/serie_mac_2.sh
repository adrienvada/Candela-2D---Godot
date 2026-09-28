#!/usr/bin/env bash
# LA SÉRIE DU MASQUE DE LA FUMÉE, SECONDE MANCHE : M0, le pochoir (V3) et les deux formes plus économes (V4, V5), avec la
# PORTE DE L'ORDRE 432 DANS LE LANCEUR (session cloud « masque-fumée-2 », 2026-09-28). À lancer sur le Mac d'Adrien, en une
# fois. Le cloud ne mesure pas le temps : cette série est la seule qui dira si une forme passe sous la barre des 3 %.
#
# La scène de la règle 278 : le pompe sous une fusée, vue unique, lacet 45° B, usure au défaut (`bench_framerate.gd --fusee`).
# Quatre bras, chacun par SON drapeau, chacun prouvé par ce que le JEU imprime :
#   M0  (aucun drapeau)            « [fumée masque] éteint »
#   V3  --fumee-masque-pochoir     « [fumée masque] forme : pochoir, compacte, bande resserrée (…) »
#   V4  --fumee-masque-lumiere     « [fumée masque] forme : lumière d'abord, pochoir, … »
#   V5  --fumee-masque-ajuste      « [fumée masque] forme : juge ajusté, lumière d'abord, … »
# Chaque forme AJOUTE une idée à la précédente : V3 → V4 est le prix de la pâte et de la matière payées là où la lumière seule
# tranchait ; V4 → V5 celui du carré du juge et du parcours des murs loin de tout mur.
#
# L'ORDRE EN MIROIR, quatre blocs : M0 V3 V4 V5 | V5 V4 V3 M0 | M0 V3 V4 V5 | V5 V4 V3 M0 — même position moyenne pour chaque
# bras (8,5), quatre prises chacun ; plus une chauffe M0 non comptée.
#
# LA PORTE (ordre 432 de la session coordinatrice, 27/09 01:39 ; ce qu'Iso 1 a dû ajouter à la main au lanceur précédent) :
#   1. REPOS COMPLET de 20 minutes avant la première prise (REPOS_INITIAL, en secondes) : rien n'est lancé ; la charge est
#      relevée pendant ce repos (elle dira si Claude Helper tombe quand les sessions se taisent) ;
#   2. 90 SECONDES SANS AUCUN GODOT avant chaque prise (REPOS_PRISE) — `docs/iso/iso12/mesurer_une_cadence.md`, § 6 ;
#   3. la porte NE JUGE QUE LA FENÊTRE MESURÉE : de la ligne « Mesure sur … » (après les 30 s de chauffe du banc) à la ligne
#      « FPS médian » — jamais le pic de lancement que la chauffe exile (§ 2 du même document) ; elle prend le MAXIMUM, pas
#      la moyenne (§ 7) ;
#   4. tout processus étranger au-dessus de 20 % d'un cœur dans la fenêtre : prise REFUSÉE ; sauf Claude Helper (tous ses
#      processus confondus, sommés échantillon par échantillon), ADMIS sous 30 % : relevé à chaque prise (médiane et
#      maximum) ; au-dessus de 30 %, prise refusée ;
#   5. une prise refusée SE REFAIT À SA PLACE (l'ordre en miroir ne bouge pas), jusqu'à quatre fois ; à la cinquième
#      refusée, la série s'arrête sans verdict ;
#   6. ÉQUILIBRE DES BRAS À 2 POINTS : la médiane de la charge de Claude Helper sur les prises de chaque bras à 2 points au
#      plus de celle des prises M0, sinon la série ne rend pas de verdict (une charge inégale pourrait faire l'écart).
# Ne comptent pas comme étrangers : Godot lui-même, WindowServer (le compositeur, inhérent au rendu fenêtré, § 4), top (le
# relevé lui-même, le même pour toutes les prises) et kernel_task (la régulation thermique du Mac sans ventilateur, § 9 : elle
# répond à la charge mesurée, elle ne vient pas d'ailleurs). Liste réglable : EXCLUS (expression rationnelle, préfixes).
#
# Ce qui refuse une prise ET ARRÊTE la série (une faute de montage, pas du bruit) : une erreur de shader ou de script ; la ligne
# d'état du bras absente ; la vue qui n'est pas « iso lacet 45° B » ; l'usure éteinte ; une médiane illisible ; quelqu'un
# devant le Mac (navigateur, lecteur, son au-dessus de 5 %).
# Le verdict (règle 278) : VALIDE si les quatre M0 tiennent dans 5 % et les bras sont équilibrés ; un bras PASSE si sa médiane
# des médianes ≥ 0,970 × celle de M0 ET son 1 % bas médian (hors 10 s) ≥ 60.
#
# Durée : 20 min de repos, puis dix-sept prises de ~3 min 20 (90 s de repos, 30 s de chauffe, SECONDES de mesure, le montage),
# soit environ 1 h 20 sans refus.
#
#     mkdir /tmp/candela-mac.lock
#     tools/masque_fumee/serie_mac_2.sh /tmp/serie-masque-fumee-2
#     rmdir /tmp/candela-mac.lock
#     ESSAI_A_BLANC=1 tools/masque_fumee/serie_mac_2.sh /tmp/essai   # la mécanique seule : ni Godot ni top (fausses prises et
#                                                                   # fausses charges, refus compris), repos réduits
#     ESSAI_CLOUD=1 ORDRE_COURT="M0 V3 V4 V5" SECONDES=5 GODOT=godot tools/masque_fumee/serie_mac_2.sh /tmp/essai
#                                                                   # le VRAI banc sous Linux (Xvfb), charges simulées
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
OUT="${1:?dossier de sortie}"
mkdir -p "$OUT"
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
JOURNAL_TMP="/tmp/candela-serie-masque-2.log"

drapeau() {
  case "$1" in
    M0) echo "" ;; V3) echo "--fumee-masque-pochoir" ;; V4) echo "--fumee-masque-lumiere" ;; V5) echo "--fumee-masque-ajuste" ;;
  esac
}
preuve() {
  case "$1" in
    M0) echo "[fumée masque] éteint" ;;
    V3) echo "[fumée masque] forme : pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR)" ;;
    V4) echo "[fumée masque] forme : lumière d'abord, pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR, MASQUE_LUMIERE)" ;;
    V5) echo "[fumée masque] forme : juge ajusté, lumière d'abord, pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR, MASQUE_LUMIERE, MASQUE_AJUSTE)" ;;
  esac
}
BRAS="M0 V3 V4 V5"
ORDRE=(M0 V3 V4 V5 V5 V4 V3 M0 M0 V3 V4 V5 V5 V4 V3 M0)
if [ -n "${ORDRE_COURT:-}" ]; then
  # shellcheck disable=SC2206
  ORDRE=($ORDRE_COURT)
fi

# Un Godot est-il ouvert ? Sur le Mac, le processus s'appelle Godot ; sous Linux (essai du cloud), du nom sous lequel il a
# été lancé (un lien : `godot`) ou de celui du binaire, que le noyau tronque à quinze caractères.
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

# LE RELEVÉ DE CHARGE : une ligne « époque<TAB>processus<TAB>%cpu » par processus et par échantillon, dans "$1", jusqu'à ce
# que "$2" existe. `top -l 2` et la SECONDE passe seulement : la première ne mesure rien par processus (§ 3). Les noms sont
# tronqués à seize caractères par top : la porte compare par PRÉFIXE.
releve() {
  local sortie="$1" stop="$2"
  while [ ! -e "$stop" ]; do
    if [ "$BLANC" = "1" ] || [ "$CLOUD" = "1" ]; then
      # Fausses charges : Claude Helper entre 8 et 26 %, parfois plus de 30 (la prise se refait), et de temps en temps un
      # indexeur au-dessus de 20 % (idem) ; FAUX_HELPER / FAUX_ETRANGER en pour cent de chance par échantillon.
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

if [ "$BLANC" != "1" ] && [ "$CLOUD" != "1" ]; then
  [ -d /tmp/candela-mac.lock ] || { echo "✗ le verrou du Mac n'est pas pris (mkdir /tmp/candela-mac.lock)"; exit 1; }
fi
if godot_ouvert; then echo "✗ un Godot est déjà ouvert"; exit 1; fi
{ echo "base : $(git log --oneline -1 | cut -c1-70) · diff : $(git diff --stat | tail -1)"
  echo "début : $(TZ=Europe/Paris date '+%Y-%m-%d %H:%M:%S') (Paris) · SECONDES=$SECONDES · repos initial ${REPOS_INITIAL} s," \
       "avant chaque prise ${REPOS_PRISE} s · porte : étranger ≤ ${SEUIL_ETRANGER} %, Claude Helper ≤ ${SEUIL_HELPER} %," \
       "équilibre ${EQUILIBRE} points, ${REFAIRE_MAX} reprises au plus"
  [ "$BLANC" = "1" ] && echo "⚠ ESSAI À BLANC : ni Godot ni top — fausses prises, fausses charges"
  [ "$CLOUD" = "1" ] && echo "⚠ ESSAI DU CLOUD : le vrai banc, des charges SIMULÉES ; la cadence ne vaut rien ici"
} | tee "$OUT/serie.txt"

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

# 2. UNE PRISE, portée : le repos, le banc, le relevé, les gardes, la porte. Rend 0 si la prise est retenue, 2 si la porte
# l'a refusée (à refaire), et ARRÊTE la série sur une faute de montage.
prendre() {
  local nom="$1" bras="$2" j="$OUT/$1.txt" charge="$OUT/$1.charge.tsv"
  # 90 s sans aucun Godot : l'attente recommence si un Godot apparaît.
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
    { echo "Échauffement 30 s (…)"; sleep 1; echo "Mesure sur $SECONDES s…"; date +%s > "$OUT/.debut"; sleep 3
      preuve "$bras"; echo "[usure] allumée — variante USURE_ESSAI posée"
      echo "Rendu : iso lacet 45° B · caméras 2D"; echo "  FPS médian       : $((80 - ${#bras} - RANDOM % 3))"
      echo "  FPS 1 % bas hors 10 s : $((70 - RANDOM % 4))  (…) — lu par le verdict"; date +%s > "$OUT/.fin"; } > "$j"
  else
    # Le début et la fin de la fenêtre mesurée, datés au moment où le banc les imprime.
    ( while [ ! -e "$OUT/.stop" ]; do
        [ -e "$OUT/.debut" ] || { grep -q "^Mesure sur" "$j" 2>/dev/null && date +%s > "$OUT/.debut"; }
        [ -e "$OUT/.fin" ] || { grep -q "FPS médian" "$j" 2>/dev/null && date +%s > "$OUT/.fin"; }
        sleep 0.5
      done ) &
    local pid_guet=$!
    # shellcheck disable=SC2046
    "$GODOT" --log-file "$JOURNAL_TMP" --path . res://tools/bench_framerate.tscn -- \
      --seconds "$SECONDES" --max-fps 0 --fusee --vue-unique --classe=pompe $(drapeau "$bras") > "$j" 2>&1
    sleep 1
    [ -e "$OUT/.fin" ] || date +%s > "$OUT/.fin"
    touch "$OUT/.stop"; wait "$pid_guet" 2>/dev/null
  fi
  touch "$OUT/.stop"; wait "$pid_releve" 2>/dev/null
  if grep -qE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; then
    echo "✗ $nom : erreur au journal" | tee -a "$OUT/serie.txt"
    grep -m3 -E "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; exit 1
  fi
  grep -qF "$(preuve "$bras")" "$j" || { echo "✗ $nom : le jeu n'atteste pas « $(preuve "$bras") »" | tee -a "$OUT/serie.txt"; exit 1; }
  grep -q "Rendu : iso lacet 45° B" "$j" || { echo "✗ $nom : la vue n'est pas « iso lacet 45° B »" | tee -a "$OUT/serie.txt"; exit 1; }
  grep -q "\[usure\] allumée" "$j" || { echo "✗ $nom : l'usure n'est pas allumée" | tee -a "$OUT/serie.txt"; exit 1; }
  [ -e "$OUT/.debut" ] || { echo "✗ $nom : le début de la mesure n'a pas été vu (« Mesure sur »)" | tee -a "$OUT/serie.txt"; exit 1; }
  local med bas p
  med="$(sed -n 's/.*FPS médian *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  bas="$(sed -n 's/.*FPS 1 % bas hors 10 s *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  [ -n "$med" ] && [ -n "$bas" ] || { echo "✗ $nom : médiane ou 1 % bas illisible" | tee -a "$OUT/serie.txt"; exit 1; }
  p="$(porte "$charge" "$(cat "$OUT/.debut")" "$(cat "$OUT/.fin")")"
  printf '%-10s %-3s médiane %4s   1 %% bas (hors 10 s) %4s   porte %s\n' "$nom" "$bras" "$med" "$bas" "$p" \
    | tee -a "$OUT/serie.txt"
  case "$p" in
    OUVERTE*)
      # « bras médiane 1%bas helper_médiane helper_max »
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

python3 - "$OUT/resultats.txt" "$BRAS" "$EQUILIBRE" <<'EOF' | tee -a "$OUT/serie.txt"
import statistics, sys
lignes = [l.split() for l in open(sys.argv[1]) if l.strip()]
bras = sys.argv[2].split()
equilibre = float(sys.argv[3])
par = {}
for b, med, bas, hmed, hmax in lignes:
    par.setdefault(b, []).append((int(med), int(bas), float(hmed), float(hmax)))
ref = [m for m, _, _, _ in par["M0"]]
tient = max(ref) / min(ref) <= 1.05
m0 = statistics.median(ref)
h0 = statistics.median([h for _, _, h, _ in par["M0"]])
print("\nréférence M0 : %s — %s (plus rapide / plus lente %.3f, seuil 1,05)"
      % (ref, "tient" if tient else "NE TIENT PAS", max(ref) / min(ref)))
equilibres = True
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
    print("%-3s médianes %-18s médiane des médianes %5.1f · rapport %.3f (%+.2f ms) · 1 %% bas médian %4.1f · Claude Helper"
          " médiane %.1f %% (max %.1f)%s · %s"
          % (b, meds, statistics.median(meds), r, ms, bas, h, hmax, "" if eq else " ⚠ DÉSÉQUILIBRÉ",
             "—" if b == "M0" else ("PASSE" if ok else "ÉCHOUE")))
valide = tient and equilibres
print("SÉRIE %s" % ("VALIDE" if valide else "SANS VERDICT : " + " et ".join(
    ([] if tient else ["la référence ne tient pas dans 5 %"])
    + ([] if equilibres else ["la charge de Claude Helper diffère de plus de %g points entre bras" % equilibre]))))
if len(ref) < 3:
    print("⚠ moins de trois prises de référence : vérification de la mécanique seulement, AUCUN verdict (ORDRE_COURT).")
EOF
if [ "$SECONDES" -lt 20 ]; then
  echo "⚠ SECONDES=$SECONDES : le 1 % bas « hors 10 s » n'a presque aucune image — ces chiffres ne valent rien." | tee -a "$OUT/serie.txt"
fi
