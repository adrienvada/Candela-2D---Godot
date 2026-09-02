#!/usr/bin/env bash
# Lance toutes les suites headless et échoue si l'une d'elles rate — OU si Godot
# a émis une erreur de script.
#
# Pourquoi ce second contrôle. Une `SCRIPT ERROR` n'échoue PAS un test GDScript :
# seul un `_check` incrémente le compteur. Une suite qui appelle une fonction
# supprimée continue donc d'annoncer « tous les tests passent » avec le code 0.
# Le cas s'est produit pour de vrai le 2026-08-17, sur la suite de la pause,
# après la disparition de la barre d'onglets. Grepper la sortie est le seul
# garde-fou qui ne dépende pas de la vigilance de l'auteur du test.
#
# ⚠️ **Et il était sourd à la moitié qui compte.** Ce contrôle ne cherchait que
# `SCRIPT ERROR`. Or les `push_error()` — le CRI DU REPLI MUET, sur lequel tout
# le dépôt s'appuie pour qu'une absence se VOIE : masque de lumière manquant,
# sprite manquant, viseur manquant — ne portent pas cette mention. Le lanceur
# était donc muet exactement là où le code a choisi de crier, et « tout passe,
# sans erreur de script » ne disait rien d'un jeu qui aurait perdu toutes ses
# textures. Trouvé le 2026-08-25 en cherchant à vérifier qu'un viseur se montait
# vraiment en match : la suite était verte et ne pouvait pas répondre.
#
# ⚠️ **La chaîne n'est PAS `USER ERROR`** — c'est ce que le premier rapport
# annonçait, moi compris, et c'était faux. Mesuré : Godot imprime
# `ERROR: <message>`, mot pour mot ce qu'il imprime pour son propre bruit de fin
# de course (« 16 resources still in use at exit »). Grepper `ERROR:` ferait
# donc rougir tous les lots. La signature qui distingue un cri DÉLIBÉRÉ est la
# ligne d'origine qui le suit : `at: push_error (`.
#
# ⚠️ **Ce que la garde n'entend PAS : `printerr()`.** Il n'imprime aucun préfixe
# — pas même `ERROR:` — juste le texte nu, donc rien ne le distingue d'un
# `print()`. Un cri passé par là restera muet. Mesuré le 2026-08-25 : **une
# seule occurrence** dans tout le code de production à la racine
# (`network_manager.gd`), le motif « repli muet » passant partout ailleurs par
# `push_error`. La garde couvre donc ce qu'elle doit couvrir — mais si un second
# `printerr` apparaît, personne ne l'entendra.
#
# ## Les cris VOULUS : une égalité déclarée, pas une interdiction
#
# ⚠️ **Une garde qui exigerait zéro cri rendrait le repli bruyant intestable.**
# `test_vision` construit exprès une arme dont le cookie n'existe pas, pour
# vérifier que le jeu CRIE au lieu de retomber en silence ; ses quatre
# `push_error` sont la preuve que le test réussit. Interdire tout cri, ce serait
# interdire d'éprouver le motif que le dépôt s'impose partout.
#
# Une suite déclare donc ses cris attendus en imprimant `CRIS ATTENDUS: <n>` ;
# sans déclaration, la tolérance est **zéro**. Le lanceur échoue si le compte
# **diffère** — et cette égalité vaut mieux qu'un plafond : elle attrape aussi
# le cas inverse, un test de repli qui CESSERAIT de crier parce qu'un
# `push_error` a été remplacé par un `return` silencieux. Même forme que
# l'égalité exigée de `test_torches.gd`.
set -uo pipefail

# `--rapide` saute les scénarios à DEUX INSTANCES.
#
# ⚠️ **Ce paragraphe a menti deux fois, et pas de la même façon.** Il a d'abord
# affirmé que ces scénarios coûtaient « l'essentiel » du temps : c'était faux, et
# une mesure l'a corrigé. Puis **les chiffres correcteurs ont vieilli sans
# prévenir** — « 2,6 s par suite », « 36 suites », « les 46 suites », « six
# scénarios », « ~5 min ». Aucun n'était un mensonge à l'écriture ; tous étaient
# faux dix jours plus tard, et une session a bâti tout un plan de travail dessus
# avant d'aller mesurer. Corriger un chiffre ne suffit donc pas : il faut se
# demander pourquoi il était écrit là.
#
# Deux natures, deux parades, et c'est pour ça que les COMPTES ont disparu d'ici.
# Un compte se DÉRIVE — `${#SUITES[@]}` dans le message de fin ne peut pas se
# tromper, là où « 46 suites » ne se contredit jamais tout seul. Une durée, elle,
# ne se dérive pas : elle porte donc sa date ET son arbre, sans quoi deux mesures
# ne sont même pas comparables.
#
#   **Mesuré le 2026-08-27, sur `main` à `3577b1b`, machine au calme :** médiane
#   d'une suite lancée seule **0,53 s** ; toute la part headless **64 s** ; le lot
#   complet **241 s**. `--rapide` fait donc gagner ~177 s, et rien d'autre.
#
# **Et la vraie cause des lots interminables n'est aucune des deux : c'est la
# CONTENTION.** Un lot complet a pris **61 minutes** le 2026-08-19 avec une charge
# moyenne à 10 — plusieurs sessions lançant Godot en même temps. Le même lot
# prenait 2 min 17 la veille au calme. **Un lanceur lent ne dit rien du code, il
# dit qui d'autre travaille.** Avant de découper ou d'optimiser quoi que ce soit
# ici, regarder `uptime`.
#
# **Le défaut reste le lot COMPLET, et c'est délibéré.** Baisser la barre par
# défaut l'aurait affaiblie en silence : le jour où quelqu'un ajoute un défaut de
# transition, personne ne s'apercevrait que la couverture avait été retirée. Il
# faut demander à en faire moins, jamais l'obtenir sans le savoir.
#
# Quand utiliser lequel :
#   • `--rapide` pendant qu'on itère — toute la part headless, ~1 min ;
#   • le lot complet **avant de commiter**, comme l'exige `CLAUDE.md`.
RAPIDE=0
if [ "${1:-}" = "--rapide" ]; then RAPIDE=1; fi
DEBUT=$SECONDS

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

# ---------------------------------------------------------------------------
# UN `user://` PAR LOT
# ---------------------------------------------------------------------------
#
# Godot dérive `user://` de `HOME`. Sans les deux lignes ci-dessous, TOUS les
# lots — quel que soit l'arbre de travail d'où on les lance — écrivent dans le
# même `~/Library/Application Support/Godot/app_userdata/Candela 2D` : celui du
# jeu installé, avec ses cartes, ses réglages et son journal de matchs.
#
# Deux dégâts, et le second est le plus cher.
#
# **Le lot écrit chez le joueur.** La ROADMAP le dit déjà — « un test qui appelle
# un setter réécrit les vraies préférences du joueur » — et les suites s'en
# protègent une par une, par des chemins temporaires et un contrôle final que le
# vrai `settings.cfg` est intact. Cette discipline tient tant qu'UN SEUL lot
# tourne.
#
# **Deux lots simultanés se rendent FAUSSEMENT ROUGES.** Six sessions partagent
# cette machine ; deux `run_suites.sh` en même temps, ce sont deux processus qui
# écrivent le même fichier temporaire, au même nom, dans le même `user://`.
# Mesuré le 2026-08-26 en lançant chaque suite qui touche `user://` en six copies
# simultanées : `test_match_history_view` **6/6 en échec**, `test_audio_settings`
# 5/6, `test_screen_audio` 4/6, `test_match_format` 3/6, `test_effect_policy`
# 2/6, `test_rejeu_journal` 2/6 — les six autres tiennent. Avec un `user://` par
# copie, les mêmes 36 exécutions passent **36/36**.
#
# Ce qui rend ce défaut coûteux n'est pas qu'il fasse échouer : c'est **ce que
# disent ses messages**. « les cinq matchs sont rendus → 0 », « journal tronqué →
# liste vide » accusent le code, jamais la voisine. C'est exactement le faux
# diagnostic que le port dérivé a supprimé côté réseau, et il restait armé ici, à
# chaque lot.
#
# **Ce script ne supprime jamais ce répertoire, ni rien d'autre.** Il vit sous
# `mktemp -d`, donc dans le dossier temporaire que macOS purge de lui-même. Un
# lanceur de tests n'a aucune raison d'effacer quoi que ce soit ; la journée du
# 2026-08-26 a rappelé ce que coûte l'inverse. Le chemin est annoncé en fin de
# lot — c'est là que vivent les `logs/godot.log` de ses processus.
#
# `run_duo.sh`, appelé plus bas, hérite de cet environnement. Lancé seul, à la
# main, il continue d'utiliser le `user://` du jeu : ce n'est pas un oubli, c'est
# un outil de mise au point qu'on veut parfois voir écrire pour de vrai.
#
# ⚠️ **`mktemp -d` est gardé, et ce garde n'est pas de la politesse.** Ce script
# n'a pas `set -e` : une affectation qui échoue ne l'arrête pas. Un `mktemp -d`
# qui rate — `/tmp` plein, quota, `TMPDIR` inutilisable — laisserait donc
# `HOME` **vide**, et à partir de cette ligne tout ce qui est relatif au foyer
# viserait la RACINE : `"$HOME/x"` devient `/x`, pour ce script comme pour tout
# ce qu'il lance, Godot compris. Reproduit le 2026-08-26 en faisant échouer
# `mktemp` : `HOME=[]`, `"$HOME/x"` → `/x`. Le lot doit REFUSER de partir dans
# cet état, pas s'y engager en silence.
#
# Code 3, comme `run_duo.sh` : « je n'ai pas pu m'exécuter » n'est pas « le jeu
# est cassé », et un compte d'échecs gonflé envoie chercher une panne qui
# n'existe pas.
#
# Signalé par la session DA2, qui a lu cette ligne pendant que je l'écrivais.
MAISON_DU_LOT="$(mktemp -d)" || {
  echo "REFUS — 'mktemp -d' a échoué : impossible d'isoler le user:// du lot." >&2
  exit 3
}
if [ -z "$MAISON_DU_LOT" ] || [ ! -d "$MAISON_DU_LOT" ]; then
  echo "REFUS — foyer de lot invalide ([$MAISON_DU_LOT]) : lot non lancé." >&2
  exit 3
fi
export HOME="$MAISON_DU_LOT"

# ---------------------------------------------------------------------------
# UN PORT PAR LOT
# ---------------------------------------------------------------------------
#
# Même défaut que le `user://` ci-dessus, autre ressource, et il restait ouvert.
# `run_duo.sh` dérive son port de `pwd -P` : c'est un port **par arbre**. Deux
# lots lancés depuis le MÊME arbre — le cas courant, une session qui relance
# après un correctif pendant qu'une autre finit le sien — ouvrent donc le même
# port UDP. Le second trouve le champ occupé et rend `REPORTÉ`.
#
# Ce n'est pas une panne, le lanceur le dit ainsi, et c'est bien le problème :
# **c'est une mesure qui n'a pas eu lieu, présentée comme un lot vert.** Huit
# scénarios à deux instances peuvent disparaître d'un lot sans que son verdict
# final change de couleur.
#
# ⚠️ **Le port se dérive du FOYER du lot, et pas d'un tirage.** Le foyer est déjà
# unique par lot — c'est `mktemp -d` qui le garantit, pas nous — donc il n'y a
# rien de neuf à inventer : la même unicité sert deux fois. Un `RANDOM` aurait
# fait la même chose en apparence, mais sans rien garantir et sans se reproduire
# à la relecture d'un journal.
#
# Plage 20000-39999, à l'écart des ports éphémères de macOS (49152+) : la même
# que `run_duo.sh`, et pour la même raison — un port qui tomberait dans la plage
# de l'OS entrerait en conflit de façon intermittente, le pire mode de panne pour
# un banc.
#
# ⚠️ **Dérivé UNE FOIS et exporté**, jamais recalculé en aval. `run_duo.sh` honore
# `CANDELA_PORT` s'il le trouve. Le piège est déjà consigné : une seconde
# dérivation, faite ailleurs, rouvre très exactement le défaut que la première
# ferme — hôte et client ouvriraient deux ports et ne se verraient jamais, et
# l'échec dirait « aucun adversaire n'a rejoint », c'est-à-dire rien.
#
# `verifier_port_libre` reste dans `run_duo.sh` : ce port-ci est improbable, pas
# impossible, et un filet qu'on retire parce qu'il ne sert plus est un filet
# qu'on regrette.
CANDELA_PORT=$(( 20000 + $(printf '%s' "$MAISON_DU_LOT" | cksum | cut -d' ' -f1) % 20000 ))
export CANDELA_PORT

SUITES=(test_liaisons test_icones_editeur
	test_map_codec test_map_geometry test_arena_build test_editor_tools
        test_match_format test_pause_menu test_menu_hub test_audio_settings
        test_match_history_view test_effect_policy test_screen_leaderboard
        test_screen_profile test_screen_historique test_arsenal test_matchmaking test_screen_matchmaking test_screen_audio
        test_screen_calibration test_match_banner test_carte_partagee test_rejeu_journal test_pseudo test_protocole
        test_vitrine_menus test_audit_menus test_pool_sfx test_musique test_oreille test_ecran_de_fin test_serie_de_session test_vision test_eblouissement test_brouillage test_rejeu test_releve_balistique test_curseur_systeme test_banc test_rendu_racine test_prediction_tir
        test_mise_a_jour test_charte test_habillage test_bandeau_fatal test_autoloads test_torches test_lumieres test_viseur test_marche test_sprites
        test_dosage_audio test_planche_marche)

# Plafond de vie d'une suite. Aucune ne dépasse quelques secondes ; ce plafond
# n'est pas là pour les lentes mais pour celles qui NE SORTENT PAS.
#
# Le cas s'est produit le 2026-08-18 : un appelant cassé a empêché
# `test_netcode.gd` de compiler, la scène a tourné sans script, et le lanceur a
# attendu **dix minutes** avant qu'on aille voir. Une suite qui pend est pire
# qu'une suite rouge — elle ne dit rien et elle bloque tout ce qui suit.
#
# macOS n'a pas `timeout`, d'où le chien de garde à la main.
PLAFOND_SUITE=${PLAFOND_SUITE:-120}

fail=0
# Scénarios qui n'ont pas pu tourner (port occupé). Comptés à part : une mesure
# qui n'a pas eu lieu n'est pas une mesure ratée.
reportes=0
run() {
  local nom="$1"; shift
  local sortie tmp chien code

  # ------------------------------------------------------------------------
  # `--no-eos` POUR TOUS — et posé ICI, pas à chaque appel
  # ------------------------------------------------------------------------
  #
  # C'est le corollaire obligatoire du `user://` par lot, et il ne se devine
  # pas. **L'identité Epic — le Device ID — vit sous `HOME`.** Un foyer neuf
  # n'en contient aucune : le SDK part donc en créer une PAR LE RÉSEAU, à
  # chaque suite et à chaque lot. `create_device_id()` puis un `await` sur le
  # rappel d'Epic, dans `network_manager.gd`.
  #
  # Mesuré le 2026-08-27 sur `test_matchmaking`, identifiants présents, foyer
  # isolé : **15 s** au lieu de 4, le temps du dialogue avec Epic. Chez la
  # session DA2, deux fois de suite, la même suite **ne revenait pas** — quatre
  # suites tuées par le chien de garde et un lot de 789 s au lieu de 200. La
  # différence entre les deux mesures n'est pas dans le code, elle est chez
  # Epic : c'est dire si l'on ne veut pas de cette dépendance ici. **Un vert
  # obtenu le jour où Epic répond n'est pas un vert.**
  #
  # Et le prix silencieux serait pire que la lenteur : chaque lot frapperait une
  # identité Epic NEUVE, ce que tout le dépôt s'interdit (« ne JAMAIS appeler
  # `delete_device_id()` : PUID différent à chaque lancement »).
  #
  # Ce n'est donc pas une optimisation, c'est la décision `cdefb7b` du
  # 2026-08-26 — « un lot de tests local ne dépend jamais d'Epic » — appliquée à
  # l'endroit qui l'avait manquée : elle n'était descendue que dans
  # `run_duo.sh`. Coût en couverture : **aucun**, et ce n'est pas une opinion —
  # **aucune suite n'exerce Epic**, et chaque lot le prouve de lui-même :
  # `grep -c 'init EOS'` sur sa sortie rend zéro.
  #
  # ⚠️ **Cette phrase s'appuyait sur un total de verdicts — « le lot passe à
  # 68 OK ».** Il était faux (mon grep comptait aussi les lignes internes de
  # `run_duo.sh`), je l'ai corrigé partout ailleurs le soir même, et il a survécu
  # ICI à trois relectures : **un chiffre qu'on a soi-même produit puis réparé
  # ailleurs devient invisible à sa propre relecture.** On relit ce qu'on
  # soupçonne, et on ne soupçonne pas ce qu'on croit déjà réparé.
  #
  # D'où la forme retenue, qui vaut au-delà de ce cas : **une justification
  # s'appuie sur un invariant, pas sur un compte.** « Aucune suite n'exerce
  # Epic » reste vrai indéfiniment ; « 61 verdicts » cesse de l'être à la
  # prochaine suite ajoutée — et personne ne pense à relire une justification.
  #
  # **Posé dans `run()` et non aux six appels** parce qu'un banc ajouté demain
  # hériterait sinon du blocage sans que personne y pense — même raison que le
  # reste de ce fichier : un garde-fou ne doit pas dépendre de la vigilance.
  # `--` d'abord si l'appelant n'en a pas : au-delà, Godot passe tout au jeu.
  local args=("$@") a separateur=0
  for a in "${args[@]}"; do [ "$a" = "--" ] && separateur=1; done
  [ "$separateur" -eq 0 ] && args+=("--")
  args+=("--no-eos")

  tmp="$(mktemp)"
  "$GODOT" --headless --path . "${args[@]}" >"$tmp" 2>&1 &
  local gpid=$!
  # `disown` puis redirection : sans eux, le shell annonce « Terminated: 15 »
  # pour CHAQUE chien de garde abattu, soit une ligne de bruit par suite — et
  # c'est exactement le genre de bavardage qui fait qu'on cesse de lire la sortie.
  ( sleep "$PLAFOND_SUITE"; kill -9 "$gpid" 2>/dev/null ) 2>/dev/null &
  chien=$!
  disown "$chien" 2>/dev/null || true
  wait "$gpid"; code=$?
  kill "$chien" 2>/dev/null
  sortie="$(cat "$tmp")"; rm -f "$tmp"
  # 137 = tué par le chien de garde (128 + SIGKILL).
  if [ "$code" -eq 137 ]; then
    printf '%-28s ÉCHEC — n'"'"'est pas sorti en %ss (bloqué)\n' "$nom" "$PLAFOND_SUITE"
    printf '%s\n' "$sortie" | grep -E 'SCRIPT ERROR|Parse Error|at: push_error \(' | head -4
    fail=1
    return
  fi
  local erreurs
  erreurs="$(printf '%s\n' "$sortie" | grep -c 'SCRIPT ERROR' || true)"
  # Le cri du repli muet — voir l'en-tête pour la signature, et pourquoi ce
  # n'est surtout pas `ERROR:`.
  local cris attendus
  cris="$(printf '%s\n' "$sortie" | grep -c 'at: push_error (' || true)"
  # Les cris que la suite déclare attendre — voir l'en-tête. `tail -1` : si une
  # suite déclarait deux fois, la dernière fait foi plutôt qu'un cumul muet.
  attendus="$(printf '%s\n' "$sortie" \
    | sed -n 's/^CRIS ATTENDUS: *\([0-9][0-9]*\).*/\1/p' | tail -1)"
  attendus="${attendus:-0}"
  if [ "$code" -ne 0 ]; then
    printf '%-28s ÉCHEC (code %d)\n' "$nom" "$code"; fail=1
  elif [ "$erreurs" -ne 0 ]; then
    printf '%-28s ÉCHEC — %s erreur(s) de script malgré un code 0\n' "$nom" "$erreurs"
    printf '%s\n' "$sortie" | grep -A2 'SCRIPT ERROR' | head -12
    fail=1
  elif [ "$cris" -ne "$attendus" ]; then
    printf '%-28s ÉCHEC — %s push_error(s), %s déclaré(s)\n' "$nom" "$cris" "$attendus"
    # `-B1` parce que le message est sur la ligne AVANT `at: push_error` :
    # sans lui on afficherait l'origine sans jamais dire ce qui manque.
    printf '%s\n' "$sortie" | grep -B1 -A1 'at: push_error (' | head -12
    fail=1
  else
    printf '%-28s OK\n' "$nom"
  fi
}

for t in "${SUITES[@]}"; do run "$t" --script "res://tools/$t.gd"; done
run test_netcode res://tools/test_netcode.tscn

# Le cycle de fin de match, en une seule instance et sans réseau.
#
# Ce chemin n'était couvert par AUCUNE suite, et c'est ce qui a laissé passer
# deux défauts en deux jours — dont `await RenderingServer.frame_post_draw`, qui
# n'est jamais émis en headless et suspendait la séquence de fin pour toujours.
# Invisible en jeu, puisqu'une fenêtre dessine ; visible seulement ici.
#
# Les modes `--host` / `--join` du même banc restent hors du lanceur : ils
# demandent deux processus coordonnés et une session Epic. À lancer à la main,
# protocole dans docs/PROTOCOLE_TEST_EOS.md.
run test_fin_de_match res://tools/test_online_match.tscn -- --local

# L'entraînement solitaire : une seule instance, aucun réseau. Ce qu'il protège
# avant tout, c'est que RIEN n'y soit archivé — le journal local est la source du
# rejeu vers le classement, et une ligne écrite ici polluerait un classement que
# personne ne saurait plus corriger.
run test_entrainement res://tools/test_online_match.tscn -- --training

# La fenêtre de choix d'un match apparié — dix secondes, arsenal aligné par la
# règle du miroir. Exercée en écran partagé : la mécanique est locale à
# `game_state`, et la faire dépendre de deux processus et d'Epic l'aurait rendue
# intestable en pratique, donc jamais testée.
run test_fenetre_de_choix res://tools/test_online_match.tscn -- --fenetre

# L'éblouissement dans un vrai match — le CÂBLAGE, pas le modèle.
#
# `test_eblouissement` prouve le modèle et `test_vision` la géométrie. Le défaut
# du 2026-08-18 vivait entre les deux : montée dans un fichier, descente dans un
# autre, jamais additionnées. Les deux suites étaient vertes, la mécanique
# centrale du jeu était morte. Ce mode-ci est le seul qui l'aurait vu.
run test_eblouissement_en_jeu res://tools/test_online_match.tscn -- --eblouissement

# Le match complet à DEUX PROCESSUS, en ENet sur 127.0.0.1.
#
# Dernier trou de l'étude de robustesse du 2026-08-16 : « les transitions d'état
# en ligne ne sont couvertes que manuellement — c'est la zone la plus régressive
# d'un jeu réseau ». Elles l'étaient parce qu'un match demande deux instances.
# ENet lève l'obstacle : aucun identifiant Epic, adresse connue d'avance.
#
## Un scénario à deux instances : OK, REPORTÉ, ou ÉCHEC.
##
## **Trois issues et non deux, parce que deux mentaient.** `run_duo.sh` rend
## désormais **3** quand il refuse de démarrer — son port UDP est tenu par un
## autre lot, aujourd'hui forcément un lot lancé du MÊME arbre, puisque le port
## se dérive du chemin. Ce n'est pas un échec : c'est une mesure qui n'a pas eu
## lieu.
##
## ⚠️ **Ce passage a nommé « 7777 » longtemps après que le port a cessé d'être
## 7777** (`aa57a33` le dérive de l'arbre). Le lanceur ne connaît pas ce port et
## ne doit surtout pas le recalculer : `run_duo.sh` le dérive UNE fois et
## l'exporte, et le refaire ici rouvrirait le défaut que cette règle ferme —
## deux dérivations, deux ports, aucun rendez-vous. D'où un message qui renvoie
## à `run_duo.sh` au lieu d'écrire un numéro qu'il ne peut pas connaître.
##
## Les compter ensemble a coûté quatre diagnostics à trois sessions le
## 2026-08-25. Le lanceur annonçait « au moins une suite a échoué », quelqu'un
## lisait la queue de sortie, et l'on partait chercher une régression de netcode
## — puis une panne de caméra — pendant que la vraie cause était un Godot
## orphelin qui tenait le port. **Un résumé qui gonfle un compte d'échecs est
## aussi trompeur qu'une erreur qui ment sur sa cause.**
##
## REPORTÉ ne met PAS `fail` à 1 : le lot reste vert, et sa dernière ligne dit
## combien de scénarios n'ont pas pu tourner.
duo() {
  local nom="$1"; shift
  if [ "$RAPIDE" -eq 1 ]; then return 0; fi
  ./tools/run_duo.sh "$@"
  local code=$?
  if [ "$code" -eq 0 ]; then
    printf '%-28s OK\n' "$nom"
  elif [ "$code" -eq 3 ]; then
    printf '%-28s REPORTÉ (port occupé, pas une panne)\n' "$nom"
    reportes=$((reportes + 1))
  else
    printf '%-28s ÉCHEC\n' "$nom"; fail=1
  fi
}

# Il coûte une minute environ, plus que toutes les autres réunies. C'est le prix
# d'une couverture sur la zone la plus régressive, et il se paie une fois par
# commit plutôt qu'une manche entière à la main.
duo duo_enet

# Famille 3 de la checklist : l'adversaire disparaît pendant le 3-2-1.
#
# La transition la plus régressive du jeu, vérifiée jusqu'ici en fermant une
# fenêtre à la main au bon moment. Le piège qu'elle protège est nommé dans
# `game_state.gd` : un décompte laissé figé cloue l'hôte sur place, sans message
# et sans pouvoir bouger. C'est le pire état atteignable, et le seul qu'aucune
# erreur ne signale.
duo duo_coupure --coupure

# Famille 1 : la pause en ligne ne gèle rien.
#
# Deux propriétés OPPOSÉES, et c'est leur combinaison qui fait la règle : le
# monde continue **et** celui qui navigue cesse d'agir. Vérifier l'une sans
# l'autre laisserait passer les deux défauts qui comptent — une pause qui gèle
# le match pour les deux, ou un joueur qui court encore pendant qu'il lit son
# menu. La pause ne doit pas être une invincibilité gratuite.
duo duo_pause --pause

# Famille 2 : ce que l'adversaire fait pendant votre killcam.
#
# Deux exigences opposées à nouveau : pendant le ralenti son intention est
# RETENUE et non appliquée — rien ne bouge chez vous, aucune manche ne démarre
# seule — mais à la sortie elle n'est pas PERDUE. Un changement d'arme appliqué
# au milieu d'un ralenti couperait la killcam de celui qui regarde encore.
duo duo_killcam --killcam

# Famille 5.3 : l'adversaire disparaît PENDANT le ralenti.
#
# Le croisement de deux chemins que rien n'exerçait ensemble — la perte de pair
# et la sortie de ralenti. Un `time_scale` oublié ne ralentit pas la killcam,
# il ralentit TOUT LE JEU, menus compris, et le joueur n'a aucune raison de
# relier son curseur qui rampe à une déconnexion d'il y a dix secondes.
#
# ⚠️ Ce banc couvre la remise à zéro, PAS le fait qu'un ralenti ait eu lieu
# avant : `Engine.time_scale` reste à 1,0 en headless, limite écrite dans le
# banc lui-même.
duo duo_ralenti --ralenti

# Famille 6 : les deux martèlent « prêt » — une seule manche doit démarrer.
#
# Cette famille paraissait intestable : elle décrit un martèlement pendant des
# transitions, donc des fenêtres de quelques dixièmes. Mais sa propriété n'est
# pas une fenêtre, c'est un COMPTE — et un compte est stable quel que soit le
# tempo. C'est le principe de placement appliqué : chercher l'observable stable
# plutôt que le moment.
duo duo_spam --spam

# Familles 4.1 et 4.2 : l'adversaire meurt, quitte pendant la killcam, revient.
#
# ⚠️ **Ces deux-là ont manqué au lot pendant une semaine, et l'absence s'est
# refermée sur elle-même** : le banc avait été sorti du lanceur parce qu'il était
# rouge, et il est resté rouge dans la feuille de route parce que personne ne le
# relançait. Il était vert depuis le matin du 2026-08-19. **Un banc qu'on retire
# du lot parce qu'il rougit cesse d'être un banc : il devient une phrase.**
#
# Deux scénarios et non un, parce que l'INSTANT du retour est tout le sujet : la
# 4.1 le veut pendant la killcam de l'hôte, la 4.2 sur son écran de fin. Un seul
# banc les confondait — et passait sur la seconde en croyant juger la première.
#
# Chacun peut rendre REPORTÉ (code 3) : le placement du retour dépend du tempo de
# la machine, et un banc qui rougit sous la charge est un faux rouge, donc un
# banc qu'on finit par débrancher.
duo duo_reconnexion --reconnexion
duo duo_reconnexion_tardive --reconnexion-tardive

# --- Aucun asset livré ne vit hors du dépôt ---------------------------------
#
# ⚠️ **Ce contrôle est en bash et pas en GDScript, et c'est la raison d'être du
# placement.** La question n'est pas « le fichier est-il sur le disque ? » — les
# bancs Godot répondent déjà à celle-là, et elle a répondu OUI le 2026-08-26
# pendant que quatorze icônes livrées n'existaient QUE sur le poste d'Adrien, le
# jour même où un incident effaçait sa session. La question est « git le
# connaît-il ? », et seul git peut y répondre.
#
# Ce que ça attrape : un asset déposé dans `assets/` et jamais ajouté. Il se voit
# à l'écran, tous les bancs sont verts, et il disparaît avec la machine.
#
# ⚠️ **`assets/` en entier, et surtout PAS une liste de sous-dossiers.** Le
# premier jet en nommait trois — `ui`, `audio`, `maps` — sur les quatorze que le
# dépôt porte. Les onze autres, dont `sprites/`, n'étaient pas surveillés : les
# trente-deux images de la démarche, cuites le 2026-08-25, seraient restées
# invisibles à la garde écrite pour les trouver. **Une énumération partielle se
# lit comme une liste complète** — c'est exactement la faute que ce contrôle
# existe pour attraper, commise dans le contrôle lui-même. Relevé par la session
# DA2 le 2026-08-27.
#
# Les planches sources non retenues restent muettes : `--exclude-standard` honore
# les `.gitignore` de `assets/sources/`, et c'est voulu — leur doctrine les exclut
# nommément. Un fichier ignoré est un fichier dont l'absence a été DÉCIDÉE.
hors_depot=$(git ls-files --others --exclude-standard -- assets 2>/dev/null | wc -l | tr -d ' ')
if [ "${hors_depot:-0}" -ne 0 ]; then
  echo "--- ${hors_depot} asset(s) présent(s) mais HORS DU DÉPÔT ---"
  git ls-files --others --exclude-standard -- assets | sed 's/^/    /'
  echo "    Ils s'affichent, les bancs sont verts, et ils meurent avec la machine."
  echo "    git add les fichiers ci-dessus, ou explique leur exclusion dans un .gitignore."
  fail=1
fi

DUREE=$((SECONDS - DEBUT))
# **Annoncé à chaque lot, et pas seulement en cas d'échec.** Ce lanceur ne joue
# plus dans le `user://` du jeu : c'est un changement de comportement, et un
# changement de comportement silencieux est précisément ce que ce fichier
# reproche ailleurs à `--rapide`. La ligne dit aussi où lire les journaux.
# Avant le verdict, jamais après : la DERNIÈRE ligne appartient au résultat.
echo "user:// de ce lot : $MAISON_DU_LOT (ce script n'y supprime rien)"
# Annoncé pour la même raison que le foyer : c'est un changement de
# comportement, et un changement silencieux est ce que ce fichier reproche
# ailleurs. Le port sert aussi à lire un journal de duo après coup.
echo "port UDP de ce lot : $CANDELA_PORT (dérivé du foyer, jamais recalculé)"
if [ "$fail" -ne 0 ]; then
  echo "--- au moins une suite a échoué (${DUREE}s) ---"; exit 1
fi
if [ "$RAPIDE" -eq 1 ]; then
  # `${#SUITES[@]}` et non un chiffre : c'est la seule façon qu'un compte reste
  # vrai quand la liste grandit. L'en-tête de ce fichier a annoncé « 46 suites »
  # jusqu'à ce qu'il y en ait 48, sans que rien ne le contredise.
  echo "--- les ${#SUITES[@]} suites headless sont vertes en ${DUREE}s — SCÉNARIOS À DEUX INSTANCES NON JOUÉS ---"
  echo "    (relancer sans --rapide avant de commiter)"
elif [ "$reportes" -ne 0 ]; then
  # **Vert, mais incomplet — et il faut que la DERNIÈRE ligne le dise.** C'est
  # elle qu'on lit ; un « tout passe » sur un lot amputé de ses scénarios réseau
  # ferait commiter du netcode que personne n'a exercé.
  echo "--- tout passe, MAIS ${reportes} scénario(s) à deux instances REPORTÉ(S) (${DUREE}s) ---"
  echo "    Le port du lot était occupé : ce n'est pas une panne, c'est une mesure qui n'a pas eu lieu."
  echo "    Le port se dérive de l'arbre ; run_duo.sh l'imprime en tête de chaque scénario."
  echo "    Relancer quand le champ est libre :  lsof -nP -iUDP:<le port annoncé>"
else
  echo "--- tout passe, sans erreur de script (${DUREE}s) ---"
fi
