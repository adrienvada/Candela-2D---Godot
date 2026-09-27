#!/usr/bin/env bash
# LA SÉRIE DU MASQUE DE LA FUMÉE ET DE SES FORMES — à lancer sur le Mac d'Adrien, en une fois (session cloud « masque-fumée »,
# 2026-09-27). Le cloud ne mesure pas le temps : cette série est la seule qui dira ce que chaque forme coûte.
#
# La scène de mesure de la règle 278 : le pompe sous une fusée, vue unique, lacet 45° B, usure au défaut
# (`tools/bench_framerate.gd --fusee`). Cinq bras, chacun par SON drapeau, et chacun prouvé par ce que le JEU imprime :
#   M0  (aucun drapeau)            « [fumée masque] éteint »                        — la référence, le jeu par défaut
#   M1  --fumee-masque             « [fumée masque] forme : celle de Gadgets »      — le masque d'aujourd'hui
#   V1  --fumee-masque-compact     « [fumée masque] forme : compacte (MASQUE_COMPACT) »
#   V2  --fumee-masque-resserre    « … forme : compacte, bande resserrée (…) »
#   V3  --fumee-masque-pochoir     « … forme : pochoir, compacte, bande resserrée (…) »
# Chaque forme AJOUTE une idée à la précédente : l'écart M1→V1 est le prix du code recopié, V1→V2 celui de la bande du sol,
# V2→V3 celui de poser la question quatre fois par pixel au lieu d'une.
#
# L'ORDRE EN MIROIR, quatre blocs : M0 M1 V1 V2 V3 | V3 V2 V1 M1 M0 | M0 M1 V1 V2 V3 | V3 V2 V1 M1 M0 — chaque bras a la
# même position moyenne (10,5), ce qui annule une dérive linéaire ; quatre prises par bras. Plus une prise de chauffe M0, non
# comptée. Vingt et une prises de SECONDES (60 par défaut) : environ vingt-cinq minutes.
#
# Ce qui refuse une prise (et arrête la série) : une erreur de shader ou de script au journal (une variante qui ne compile
# pas ne dessine rien et paraît gratuite, piège du 2026-09-25) ; la ligne d'état du bras absente ; la vue qui n'est pas
# « iso lacet 45° B » ; l'usure qui n'est pas allumée ; une médiane ou un 1 % bas illisible.
# Le verdict (règle 278, règle de validité de la session cloud) :
#   - VALIDE si les quatre M0 tiennent dans 5 % (plus rapide / plus lente ≤ 1,05), sinon SANS VERDICT ;
#   - un bras PASSE si sa médiane des médianes ≥ 0,970 × celle de M0 ET son 1 % bas médian (hors 10 s) ≥ 60.
#
# ⚠️ Il ouvre des FENÊTRES : verrou du Mac pris par l'appelant (mkdir /tmp/candela-mac.lock), aucun Godot ouvert, fenêtre de
# silence annoncée aux autres sessions ; il s'arrête si un navigateur, un lecteur ou le son dépasse 5 % d'un cœur.
#     tools/masque_fumee/serie_mac.sh <dossier de sortie>
#     ESSAI_A_BLANC=1 tools/masque_fumee/serie_mac.sh /tmp/essai    # la mécanique seule, sans Godot (fausses prises)
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
OUT="${1:?dossier de sortie}"
mkdir -p "$OUT"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SECONDES="${SECONDES:-60}"
BLANC="${ESSAI_A_BLANC:-0}"
# Le journal de Godot hors de l'index de Spotlight (piège d'ISO12) : un par prise, sous /tmp, recopié dans OUT.
JOURNAL_TMP="/tmp/candela-serie-masque.log"

# Pas de tableau associatif : le bash livré par Apple est le 3.2 (piège de `run_photos.sh`).
drapeau() {
  case "$1" in
    M0) echo "" ;; M1) echo "--fumee-masque" ;; V1) echo "--fumee-masque-compact" ;;
    V2) echo "--fumee-masque-resserre" ;; V3) echo "--fumee-masque-pochoir" ;;
  esac
}
preuve() {
  case "$1" in
    M0) echo "[fumée masque] éteint" ;;
    M1) echo "[fumée masque] forme : celle de Gadgets" ;;
    V1) echo "[fumée masque] forme : compacte (MASQUE_COMPACT)" ;;
    V2) echo "[fumée masque] forme : compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE)" ;;
    V3) echo "[fumée masque] forme : pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR)" ;;
  esac
}
ORDRE=(M0 M1 V1 V2 V3 V3 V2 V1 M1 M0 M0 M1 V1 V2 V3 V3 V2 V1 M1 M0)
# Une vérification courte des gardes (une prise par bras, par exemple) : ORDRE_COURT="M0 M1 V1 V2 V3" SECONDES=5. Jamais
# pour un verdict — le miroir n'y est plus.
if [ -n "${ORDRE_COURT:-}" ]; then
  # shellcheck disable=SC2206
  ORDRE=($ORDRE_COURT)
fi

present() {
  top -l 2 -s 2 -n 30 -o cpu -stats command,cpu 2>/dev/null | awk '
    /^COMMAND/ { n++; next }
    n==2 { cpu=$NF; sub(/%/,"",cpu); nom=$0; sub(/[ \t]+[0-9.]+%?[ \t]*$/,"",nom); l=tolower(nom)
      if (l ~ /firefox|safari|chrome|vlc|iina|quicktime|music|podcasts|^tv|usbaudiod|coreaudiod|spotify/ && cpu+0 >= 5.0) {
        printf "%s %.1f%%\n", nom, cpu; t=1 } }
    END { exit t ? 0 : 1 }'
}

if [ "$BLANC" != "1" ]; then
  [ -d /tmp/candela-mac.lock ] || { echo "✗ le verrou du Mac n'est pas pris (mkdir /tmp/candela-mac.lock)"; exit 1; }
  if pgrep -x Godot > /dev/null; then echo "✗ un Godot est déjà ouvert"; exit 1; fi
fi
echo "base : $(git log --oneline -1 | cut -c1-70) · diff : $(git diff --stat | tail -1)" | tee "$OUT/serie.txt"

# Une prise : le banc, son journal, les gardes, puis « bras médiane 1%bas » dans resultats.txt.
prendre() {
  local nom="$1" bras="$2" j="$OUT/$1.txt"
  if [ "$BLANC" = "1" ]; then
    # Fausses prises : la mécanique (ordre, gardes, verdict) sans ouvrir de fenêtre.
    { preuve "$bras"; echo "[usure] allumée — variante USURE_ESSAI posée"
      echo "Rendu : iso lacet 45° B · caméras 2D"; echo "  FPS médian       : $((80 - ${#bras} - RANDOM % 3))"
      echo "  FPS 1 % bas hors 10 s : $((70 - RANDOM % 4))  (…) — lu par le verdict"; } > "$j"
  else
    if qui=$(present); then echo "✗ $nom : quelqu'un est devant le Mac ($(echo $qui | tr '\n' ' ')) : arrêt"; exit 1; fi
    # shellcheck disable=SC2046
    "$GODOT" --log-file "$JOURNAL_TMP" --path . res://tools/bench_framerate.tscn -- \
      --seconds "$SECONDES" --max-fps 0 --fusee --vue-unique --classe=pompe $(drapeau "$bras") > "$j" 2>&1
  fi
  if grep -qE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; then
    echo "✗ $nom : erreur au journal"; grep -m3 -E "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error" "$j"; exit 1
  fi
  grep -qF "$(preuve "$bras")" "$j" || { echo "✗ $nom : le jeu n'atteste pas « $(preuve "$bras") »"; exit 1; }
  grep -q "Rendu : iso lacet 45° B" "$j" || { echo "✗ $nom : la vue n'est pas « iso lacet 45° B »"; exit 1; }
  grep -q "\[usure\] allumée" "$j" || { echo "✗ $nom : l'usure n'est pas allumée"; exit 1; }
  # Le nombre APRÈS les deux-points, jamais le premier de la ligne (« 1 % bas hors 10 s » en contient deux).
  local med bas
  med="$(sed -n 's/.*FPS médian *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  bas="$(sed -n 's/.*FPS 1 % bas hors 10 s *: *\([0-9][0-9]*\).*/\1/p' "$j" | head -1)"
  [ -n "$med" ] && [ -n "$bas" ] || { echo "✗ $nom : médiane ou 1 % bas illisible"; exit 1; }
  printf '%-8s %-3s médiane %4s   1 %% bas (hors 10 s) %4s   %s\n' "$nom" "$bras" "$med" "$bas" "$(drapeau "$bras")" \
    | tee -a "$OUT/serie.txt"
  [ "$nom" = "chauffe" ] || echo "$bras $med $bas" >> "$OUT/resultats.txt"
}

: > "$OUT/resultats.txt"
prendre chauffe M0
k=0
for bras in "${ORDRE[@]}"; do
  k=$((k + 1))
  prendre "$(printf '%02d' $k)_$bras" "$bras"
done

python3 - "$OUT/resultats.txt" <<'EOF' | tee -a "$OUT/serie.txt"
import statistics, sys
lignes = [l.split() for l in open(sys.argv[1]) if l.strip()]
par = {}
for b, med, bas in lignes:
    par.setdefault(b, []).append((int(med), int(bas)))
ref = [m for m, _ in par["M0"]]
tient = max(ref) / min(ref) <= 1.05
m0 = statistics.median(ref)
print("\nréférence M0 : %s — %s (plus rapide / plus lente %.3f, seuil 1,05)"
      % (ref, "VALIDE" if tient else "SANS VERDICT", max(ref) / min(ref)))
for b in ("M0", "M1", "V1", "V2", "V3"):
    meds = [m for m, _ in par[b]]
    bas = statistics.median([x for _, x in par[b]])
    r = statistics.median(meds) / m0
    ms = 1000.0 / statistics.median(meds) - 1000.0 / m0
    ok = r >= 0.970 and bas >= 60
    print("%-3s médianes %-18s médiane des médianes %5.1f · rapport %.3f (%+.2f ms) · 1 %% bas médian %4.1f · %s"
          % (b, meds, statistics.median(meds), r, ms, bas, "—" if b == "M0" else ("PASSE" if ok else "ÉCHOUE")))
if not tient:
    print("SÉRIE SANS VERDICT : la référence ne tient pas dans 5 % (repos de cinq minutes, charge relue, puis relancer).")
EOF
