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
	test_map_codec test_map_geometry test_mur_led test_arena_build test_editor_tools
        test_classes test_match_format test_pause_menu test_menu_hub test_menu_solo test_comic_panel test_audio_settings
        test_match_history_view test_effect_policy test_screen_leaderboard test_regard_hors_menu
        test_screen_profile test_screen_historique test_arsenal test_matchmaking test_screen_matchmaking test_screen_audio
        test_screen_calibration test_match_banner test_carte_partagee test_rejeu_journal test_pseudo test_protocole
        test_vitrine_menus test_torche_hors_menu test_menu_artworks test_intro_planches test_enseigne test_audit_menus test_pool_sfx test_musique test_oreille test_ecran_de_fin test_serie_de_session test_vision test_eblouissement test_brouillage test_rejeu test_releve_balistique test_curseur_systeme test_curseur_joystick test_banc test_rendu_racine test_prediction_tir
        test_mise_a_jour test_charte test_habillage test_bandeau_fatal test_autoloads test_torches test_torche_bouton test_lumieres test_viseur test_marche test_sprites
        test_dosage_audio test_planche_marche test_fusee test_fusee_rouge_sang test_munitions_recharge test_sang_au_sol test_bilan_de_soiree
        test_hatch_shader test_inked_icons test_arena_matter test_arena_lighting test_hud_style
        test_menus_finitions test_conditions_de_match test_encrage test_curseurs_branches test_calques_joueur test_fusee_eteinte test_traces_carte test_entrainement_carte test_traces_rencontre
        test_telemetrie_gadgets test_murs_bas test_murs_bas_rendu
        test_proto_iso test_voxel_corps test_voxel_objets test_banc_iso test_iso_geometrie test_iso_equite test_iso_camera test_iso_vues test_iso_corps test_iso_murs_bas test_iso_objets test_iso_killcam test_killcam_calme test_iso_beaute test_rendu_rr test_iso_gadgets test_masque_formes test_iso_torches3d test_corps_portraits test_corps_mannequin test_menus_voxel test_iso_usure test_corps_detail test_corps_soi_sombre test_passe_unique test_corps_soi_fondu test_pochoirs test_gris_egaux test_iso_peinture_carte)

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

# Répétition du test d'Adrien (2026-09-27) : une seule lecture des drapeaux de lancement (D3).
# Posé ici, loin de la liste, pour que ce correctif se reprenne seul sans conflit.
SUITES+=(test_drapeaux)
# Chantier SON VISIBLE (0.8.0, 2026-09-29) : le modèle du liseré, sans scène. Hors de la liste, même raison.
SUITES+=(test_son_visible test_son_visible_jeu test_clic_a_vide)
# Le liseré suit la forme d'onde du son (2026-09-29) : la table d'enveloppes précalculées suit les WAV.
SUITES+=(test_enveloppes_sons)

# Q42 (2026-09-29) — le corps ignore sa propre ombre : l'étoile de chaque corps vit dans SA canvas, que les capteurs de ce corps
# ne comptent pas. Posé ici, comme la ligne du dessus, pour que ce lot se reprenne seul sans conflit avec la liste.
SUITES+=(test_ombre_propre)

# OMBRES, OM4 (2026-10-04) — les règles d'ombre « sans décision » : le flash de bouche qui recule devant un mur, l'écho au sol et la
# lumière de coup au masque des lumières neutres, l'étoile à la posture, l'ombre et la lueur d'un corps mort. Posé ici, comme les
# lignes du dessus, pour que ce lot se reprenne seul sans conflit avec la liste.
SUITES+=(test_ombres_regles)

# OMBRES, OM4b (2026-10-05) — des règles d'ombre pour N corps : une couche d'ombre par PNJ (Q86), et la fusée, la mine, la nappe de
# braises au masque des lumières neutres (Q87), lues sur les objets vivants d'une vraie salle. Posé ici, même raison.
SUITES+=(test_ombres_pnj)

# OMBRES, OM5 (2026-10-05) — l'ombre finie des corps sous les plafonniers (Q88) : la règle jumelle du shader, les shaders du sol et
# du décor, la poussée dans une vraie salle. Posé ici, même raison.
SUITES+=(test_ombres_plafonniers)

# OMBRES, OM2 (2026-10-05) — l'étoile à la forme du corps voxel (Q82) : sa forme pour les dix classes, la garde de dérive contre les
# boîtes d'un vrai corps, le cercle provisoire qui ne l'écrase plus, et l'ombre de contact des figurants en vue iso. Même raison.
SUITES+=(test_ombres_voxel)

# OMBRES, OM6 (2026-10-05) — l'allègement : l'ombre d'un halo sans récepteur, le capteur d'un corps qu'on ne montre pas, la
# lumière de coup partie à 1 % de son énergie — dans une vraie salle en iso. Même raison.
SUITES+=(test_ombres_allegement)

# Le point de braise de la fusée et l'Usine (0.8.0, 2026-09-29 ; Adrien : « Le point rouge : oui, dans la 0.8.0 » et « Oui corrige
# l'usine ») : la règle de luminance du point — aussi lumineux que sa lumière, en gardant le rouge —, à chaque pas des vingt secondes de
# la fusée, sans fenêtre ; et la symétrie de l'Usine, avec l'ancienne comme témoin sur lequel la garde rougit. Posé ici, comme les
# deux lignes du dessus, pour que ce lot se reprenne seul sans conflit avec la liste.
SUITES+=(test_point_braise test_usine_symetrie)

# L'écran de fin et le retour de l'éditeur (Adrien, 2026-09-29) : le carton nomme la CLASSE et se passe à n'importe quel appui
# (`test_carton_de_fin`), le salon ne se voit jamais à travers lui, image par image (`test_carton_transition` — sans fenêtre ; sous
# Xvfb le même fichier écrit la bande d'images et éprouve un vrai clic), et l'allumage « CANDELA » ne se rejoue pas quand on revient
# de l'éditeur de cartes (`test_allumage_unique`). Posé ici, comme les lignes du dessus, pour que ce lot se reprenne seul sans
# conflit avec la liste.
SUITES+=(test_carton_de_fin test_carton_transition test_allumage_unique)

# Chantier des lumières de la 0.8.0 (2026-09-29) : L1, la portée jusqu'au bord de l'écran ; L1bis, les faisceaux de 10° à 60° ;
# L2, la lumière qui part de la lampe du modèle ; L3, le point lumineux (Q46). Hors de la liste, même raison.
SUITES+=(test_portee_ecran test_faisceaux_concentres test_lampe_modele test_point_lumineux)

# L'allègement de la 0.8.0 (Adrien, 2026-09-30 : « Oui allège d'abord avant de publier la 0.8 ») : les couches du rayon dans
# l'air taillées à leur cône — l'enveloppe contient chaque cookie au texel près, l'éventail contient l'enveloppe, en plages,
# tourné comme la lampe ; le juge garde son disque. Posé ici, comme les lignes du dessus, pour que ce lot se reprenne seul.
SUITES+=(test_allegement_faisceau)

# Q72 (Adrien, 2026-09-30 : « Q72 : corrige aussi ») : la fusée posée de la killcam éclaire comme en match — une vraie fusée
# lancée dans une vraie manche, puis la killcam par son propre chemin, valeur par valeur. Posé ici, comme les lignes du dessus.
SUITES+=(test_fusee_killcam)

# Q58 (Adrien, 2026-10-01 : « il faudrait qu'à l'allumage la fusée illumine loin effectivement ») : à l'allumage, le halo de
# la fusée porte aussi loin que les torches, puis revient avant la braise — la courbe, la règle, une vraie fusée de match et
# la killcam à chaque âge. Posé ici, comme les lignes du dessus.
SUITES+=(test_fusee_allumage)

# Chantier « Gadgets en volume » (2026-09-30, Adrien : « tous les gadgets […] davantage en 3D ») : la fumée en VOXELS, LE
# DÉFAUT depuis GV1bis (Q67 : « Oui la fumée en gros »). Sans drapeau : les voxels « gros », au relief du dessin et à
# l'encre du roman graphique, puis les couches et chaque encre par la bascule des bancs. La même suite repasse plus bas
# sous `--fumee-couches` (le jeu d'avant, lu au lancement) et sous les trois choix lus au lancement. Hors de la liste,
# même raison que les lignes du dessus.
SUITES+=(test_fumee_voxel)

# GV2 (2026-10-01, ordre de la coordinatrice ; Q70 d'Adrien : « oui ») : les nappes au sol en voxels, À L'ESSAI, éteint par
# défaut — sans drapeau, le jeu publié, puis l'essai par la bascule des bancs. La même suite repasse plus bas sous
# `--nappes-voxels=braises` (l'essai lu au lancement). Hors de la liste, même raison que les lignes du dessus.
SUITES+=(test_nappes_voxel)

# Chantier SOLO, S1 (2026-10-02) : le bot se déplace, et l'entraînement gagne son cran « adversaire mobile ». Deux gardes.
# `test_bot_navigation` (en `--script`, sans scène) : sur chaque carte livrée, des chemins qui ne traversent ni solide, ni mur
# bas, ni coin, ni couloir plus étroit que le corps ; RONDE, ZONE, LIBRE et la graine ; le bot ne commande que de la marche.
# `test_entrainement_bot` (le jeu monté, à pas d'image fixe — voir plus bas) : le bot avance sur un vrai corps sans jamais être
# bloqué, ne tire pas, revient quand on l'abat, et J2 retrouve son état d'avant à l'écran scindé. Posées ici, comme les lignes du
# dessus : ce sont des suites ordinaires, mais la seconde exige une horloge fixe et se lance donc par un `case` à part.
SUITES+=(test_bot_navigation test_entrainement_bot)

# Chantier SOLO, S2 (2026-10-02) : la PERCEPTION du bot, et la garde d'honnêteté. `test_bot_perception` (en `--script`, une carte
# fabriquée et des corps factices, sans fenêtre) : le modèle de vue ne voit jamais PLUS que la lumière — cible dans le noir, mur entre
# la lampe et le bot, hors du cadre de l'écran, cône de la torche, éclair, fusée, halo, murs bas —, l'ouïe ne donne jamais la place
# exacte (une zone qui contient la vérité sans la centrer, qui grandit avec la distance et derrière un mur), la mémoire s'efface, et
# le fournisseur d'entrées ne lit rien de la perception pour agir (S3). L'autre moitié de la preuve — le modèle contre les CAPTEURS
# du jeu — ouvre une fenêtre et n'entre dans aucune suite : `tools/banc_perception_bot.tscn` (commande dans son en-tête), dont les
# appuis sont vérifiés par `test_banc`. Posée ici, comme les lignes du dessus.
SUITES+=(test_bot_perception)

# Chantier SOLO, S3 (2026-10-02) : le bot AGIT sur ce qu'il perçoit, et il tire ; l'entraînement gagne son cran 3, « adversaire qui
# tire », avec trois difficultés. `test_bot_combat` : (1) des corps factices avec le vrai fournisseur et le vrai nœud de perception —
# le délai de réaction, l'erreur de visée qui se resserre, le lissage, la rafale, la recharge, l'enquête, la recherche, l'oubli,
# l'audace, la difficulté — et la garde d'HONNÊTETÉ (zéro coup vers un joueur dans le noir ou derrière un mur, aucune lecture de
# l'adversaire dans le texte du fournisseur) ; (2) le jeu monté, à pas d'image fixe : le cran 3 et ses difficultés lus de l'interface,
# le bot au profil choisi, des balles sur un joueur éclairé et aucune sur un joueur dans le noir, le cran 2 qui ne tire toujours
# jamais, la mort et la réapparition du JOUEUR. Elle exige l'horloge fixe : le `case` plus bas la lui donne, comme à
# `test_entrainement_bot`.
SUITES+=(test_bot_combat)

# Chantier SOLO, S5 (2026-10-02) : les PLAFONNIERS, lumières posées, permanentes et indestructibles de l'aventure. `test_plafonniers`
# (en `--script`, sans partie) : la pose depuis des données (noms, places, bornes, canaux de lumière et d'ombre conformes à
# `canaux_lumiere.gd`, hauteur au-dessus des murets), l'allumage par proximité et son hystérésis, l'absence de toute pose dans une
# carte de duel (les données, le code, et le vrai jeu monté sur chaque carte livrée), le modèle de vue du bot (sous un plafonnier :
# vue ; derrière un mur haut : non ; hors de la flaque : rien ; un mur bas par la géométrie de la hauteur de la lampe) et le miroir
# de lumières de la vue iso. L'autre moitié — la lumière réelle, lue sur les capteurs — est au banc `banc_perception_bot` (familles
# `plafonnier*`), qui ouvre une fenêtre et n'entre dans aucune suite headless.
SUITES+=(test_plafonniers)

# Chantier SOLO, S4 (2026-10-02) : les PROFILS du bot, réglés au banc de JEU. `test_banc_bot` est la forme COURTE du banc
# (`tools/banc_bot_difficulte.gd`, qui est long et reste hors des suites) : le catalogue des PNJ de l'aventure (chaque nom se construit,
# avec les bons axes ; le sourd et aveugle ne tire jamais ; les paliers de réflexes se rangent ; le boss est le profil NORMAL), les trois
# difficultés (mêmes champs de perception, de déplacement ET D'AUDACE : elles tirent toutes si vu ou entendu), puis des duels SIMULÉS
# dans le vrai jeu — déterministes par graine — où un joueur type honnête gagne plus souvent contre FACILE que contre NORMAL, plus contre
# NORMAL que contre DIFFICILE (l'ORDRE, des bornes larges, jamais un chiffre exact), et des PNJ d'initiation dans une salle. Elle exige
# l'horloge fixe : le `case` plus bas la lui donne, comme à `test_bot_combat`.
SUITES+=(test_banc_bot)

# Chantier SOLO, S6 (2026-10-02) : le MOTEUR de l'aventure. `test_aventure_format` (en `--script`, sans partie) : le validateur accepte
# le chapitre d'essai (`tools/aventure_essai/`, jamais `assets/solo/`) et refuse chaque défaut — profil inconnu, case hors carte ou non
# praticable, ronde sans points, chapitre sans boss final… — un cas par règle ; l'ordre des classes débloquées suit le rang ; la
# progression (`user://solo.cfg`, ici un chemin à la suite) ouvre chapitres et salles dans l'ordre ; aucune carte de duel n'est touchée.
# `test_aventure_partie` (le jeu monté, à pas d'image fixe — `case` plus bas, comme `test_bot_combat`) : une salle se charge (arène,
# plafonniers, joueur, PNJ `PNJ_<i>` pilotés par des bots, carton), la perception d'un PNJ ne vise que le joueur, les PNJ ne se
# blessent pas, la vue iso les montre TOUS (et le duel est rendu comme avant), tous les PNJ morts enchaînent la salle suivante, mourir
# recommence la salle, finir le boss débloque la classe et l'écrit, quitter rend l'entraînement et l'écran scindé intacts, l'écran.
# `test_aventure_restes` (2026-10-04, à pas fixe) : le bandeau « FATAL — <arme> » et sa marge sont au JcJ, et rien d'une mort ne
# reste d'une salle à l'autre — un corps libéré avant la fin de son fondu laissait ses étiquettes dans l'arène.
# `test_aventure_hud` (2026-10-04, à pas fixe) : les consignes de l'initiation portent les touches de l'InputMap et ne s'allument que
# sur le geste FAIT ; le compteur suit chaque abattu ; le tampon de la salle réussie claque, le record ne tombe que s'il bat un temps.
# `test_aventure_tirs_pnj` (2026-10-04, à pas fixe) : le tir d'un PNJ part en direct, sans occlusion, à trois diagonales au moins ; le
# même tir joué comme un tir ordinaire serait étouffé (le témoin) ; le tir du joueur garde sa portée.
SUITES+=(test_aventure_format test_aventure_partie test_aventure_restes test_aventure_hud test_aventure_tirs_pnj)

# Chantier SOLO, S9 (2026-10-02) : le bot S'ÉQUIPE — sa torche (éteinte tant qu'il n'a rien perçu, allumée pour fouiller, éteinte pour
# s'approcher), sa prudence (changer de place après un tir, s'accroupir pour approcher un son), sa fusée (vers une zone ENTENDUE, jamais
# vers une cible vue) et le gadget de sa classe (une règle par gadget, dix gadgets comptés contre le catalogue du jeu). `test_bot_equipement` :
# les règles pures, le texte de `equipement_bot.gd` (il ne lit jamais l'autre joueur), des corps factices avec le vrai fournisseur et le vrai
# nœud de perception (chaque gadget posé dans la mise en scène de sa règle, la bobine, la mine qui recule, la suie où il entre), la garde
# d'HONNÊTETÉ (équipé de tout, devant un joueur dans le noir : aucun outil), les empreintes du flux de commandes des profils SANS équipement
# (relevées sur le code d'avant S9), puis le jeu monté (vrai `Player`, vrai `GameState` : les dix gadgets naissent dans l'arène, la fusée
# part, le corps s'accroupit et se replie). Elle exige l'horloge fixe : le `case` plus bas la lui donne, comme à `test_bot_combat`.
SUITES+=(test_bot_equipement)

# Chantier SOLO, S7 (2026-10-02) : le CONTENU du chapitre 0, « L'initiation » (`assets/solo/chapitre_00/`, écrit par
# `tools/fabrique_chapitre_00.gd`). `test_chapitre_00` (en `--script`, sans partie) juge ce que chaque salle ENSEIGNE, mesuré sur ses
# données avec les fonctions du jeu : chaque PNJ atteignable à pied, aucune ronde, aucun couloir d'une tuile ; 0.1 le PNJ dans la flaque
# et en vue du départ ; 0.2 aucune lampe sur lui, le pilier le cache ; 0.3 plus de tirs que de balles au chargeur ; 0.4 un mur bas
# entre chaque PNJ et le départ ; 0.5 hors de portée de torche du chemin du centre, tous au halo d'une fusée ; 0.6 des flaques sur le
# chemin direct et un détour qui les évite ; 0.7 chaque tir vu d'un autre PNJ, un abri ; 0.8 aucune lampe ; 0.9 les quatre sortes de PNJ ;
# 0.10 un duel en miroir.
SUITES+=(test_chapitre_00)

# Chantier SOLO, S8 (2026-10-03) : le CONTENU des chapitres 1 à 3 (`assets/solo/chapitre_01` à `03`, écrits par `tools/fabrique_chapitre_01.gd` à `03`, qui
# partagent `tools/fabrique_commune.gd`). Chaque garde charge son chapitre par `tools/outils_chapitre.gd` (le contexte d'une salle, le modèle de vue du bot, les
# chemins de `NavigationBot`, l'ouïe réelle de l'audio) et mesure ce que chaque salle ENSEIGNE. `test_chapitre_01` — « Les rondes » (Fumiste) : chaque ronde une boucle
# praticable qui repasse sous une lampe, deux rondes qui se croisent sans se toucher, la ronde dans le noir qu'aucune case ne montre entière à la torche, le guetteur,
# la ronde qui regarde, l'enfilade de trois flaques, la suie (1.7 à 1.9 : « equipe »), un duel en miroir. `test_chapitre_02` — « Les rondes écoutent » (Illusionniste) :
# les portées d'écoute (un pas debout, un pas accroupi, un tir, une douille), des zones d'abri accroupi, la salle nue, les recoins, deux salles reliées, le T, la
# diversion, le leurre. `test_chapitre_03` — « Les zones » (Braconnier) : chaque zone contient son gardien et assez de cases pour errer, la porte, la frontière, le
# damier, la lampe au loin (3.7 à 3.9 : « equipe », et un gardien équipé ENTEND).
SUITES+=(test_chapitre_01 test_chapitre_02 test_chapitre_03)

# Chantier SOLO, S8 : `test_chapitres_marche` (le jeu monté, à pas d'image fixe — `case` plus bas) joue chaque salle de ronde ou de zone des chapitres 1 à 3 avec le VRAI
# corps (PNJ désarmés et sourds-aveugles : seul le déplacement est mesuré) : chaque ronde passe par chacun de ses points et boucle, une zone n'est jamais quittée et visitée
# pour un cinquième au moins, aucun PNJ n'est immobile plus de trois secondes, deux rondes ne se traversent pas. S1 avait dit que RONDE et ZONE n'étaient éprouvées qu'avec
# un point matériel : c'est ici que le vrai corps les parcourt.
SUITES+=(test_chapitres_marche)

# Chantier SOLO, S8, lot 2 (2026-10-03) : le CONTENU des chapitres 4 à 6 (`assets/solo/chapitre_04` à `06`, écrits par `tools/fabrique_chapitre_04.gd` à `06`, sur la grille de
# `fabrique_commune.gd`). Mêmes outils que le lot 1 (`tools/outils_chapitre.gd`) plus `tools/outils_chapitre_04_06.gd` : l'ouïe d'un PNJ DERRIÈRE LES MURS (`PerceptionBot.ecouter`
# sur le monde de la salle), « la règle de son gadget peut-elle se déclencher ? » (la fenêtre de `EquipementBot.GADGETS`), la forme d'une salle (sol ouvert, blocs, culs-de-sac).
# `test_chapitre_04` — « Les zones écoutent » (Terrassier) : un pas debout s'entend de la porte et pas un pas accroupi, un tir réveille les trois pièces, un chemin silencieux
# accroupi, des zones moitié claires, un L et son poste, la carrière où la poussière tient, des zones emboîtées dans un dédale de murets, la poussière (4.7 à 4.9 : « equipe »).
# `test_chapitre_05` — « Les groupes » (Incendiaire) : des zones qui se recouvrent, une ronde sous un gardien, un poste qui couvre une ronde mieux que l'autre, un bruit qui n'appelle
# qu'un gardien, un passage de trois cases qu'une nappe de 136 px ferme, une croix à quatre groupes, la nappe (5.7 à 5.9). `test_chapitre_06` — « Les chasseurs » (Sentinelle) : des
# boucles sans cul-de-sac, une boucle noire où se cacher, des îlots, trois seuils éclairés, un sol nu où un pas s'entend, des couloirs de 4 cases que la poudre remplit (6.7 à 6.9).
SUITES+=(test_chapitre_04 test_chapitre_05 test_chapitre_06)

# Chantier SOLO, S8, lot 2 : `test_chapitres_marche_04_06` (le jeu monté, à pas d'image fixe — `case` plus bas), sur le modèle de `test_chapitres_marche` (que l'autre session du lot
# n'a pas à éditer, ni moi) : le VRAI corps parcourt chaque ronde, chaque zone et — pour la première fois dans une salle d'aventure — chaque CHASSEUR (déplacement libre) des
# chapitres 4 à 6, PNJ désarmés et sourds-aveugles. Rondes : chaque point, la boucle ; zones : jamais quittées, visitées ; chasseurs : des cases distinctes, tous les quarts de carte,
# du sol seulement ; jamais immobile plus de trois secondes ; deux rondes ne se rattrapent pas.
SUITES+=(test_chapitres_marche_04_06)

# Chantier SOLO, S9b (2026-10-03) : l'INTÉGRATION de S6 (le moteur de l'aventure) et de S9 (le bot équipé), écrits en parallèle. `test_aventure_boss`
# (le jeu monté, à pas d'image fixe — `case` plus bas) : chaque PNJ a SA réserve de fusées et de gadget, semée sur SA classe (deux PNJ ne se volent
# plus la leur, un boss Fumiste pose sa suie et retrouve ses réserves quand la salle recommence, le bot d'entraînement rééquipe à sa réapparition la
# classe qu'il porte) ; l'éblouissement vaut pour les PNJ dans les deux sens (torche et éclair de tir), sauf entre eux ; un bot ébloui voit MOINS,
# jamais plus. Les boss par classe sont gardés par `test_banc_bot` (existence, bornes larges, aucun champ de perception touché).
SUITES+=(test_aventure_boss)

# Chantier SOLO, S8 lot 2 (2026-10-03) : le CONTENU des chapitres 7 à 9 (`assets/solo/chapitre_07` à `09`, écrits par `tools/fabrique_chapitre_07.gd` à `09`). Des PNJ LIBRES
# (partout, sans trajet ni zone) et des salles bien plus grandes que celles d'un duel. Les gardes partagent `tools/outils_chapitre.gd` (le lot 1) et `tools/outils_chasseurs.gd`
# (la lumière d'une salle : flaques, ombres, noir ; les îlots ; un PNJ libre part loin du joueur et hors de toute lampe). `test_chapitre_07` — « Les chasseurs vifs »
# (Occulteur) : un duel dans une petite arène, deux chambres et une porte, le noir complet, cinq flaques en quinconce, un poste couvrant un hall, les ombres des colonnes,
# les îlots, un labyrinthe de murets, la meute, un duel en miroir (7.7 à 7.9 : « equipe », et un chasseur équipé VOIT).
SUITES+=(test_chapitre_07 test_chapitre_08 test_chapitre_09)
# `test_chapitre_08` — « Les grandes salles » (Allumeur) : « grande » se mesure contre la plus grande carte de duel livrée ; un H, une galerie de 90 cases, des goulets éclairés, vingt
# machines, une cour et sa galerie, six salles noires, seize blocs, quatre halls ; des rondes de même tour qui ne se touchent jamais ; la mine (8.7 à 8.9 : « equipe », un PNJ
# équipé de la mine ENTEND). `test_chapitre_09` — « L'élite » (Spectre) : une élite est plus vive qu'un chasseur normal (lu au catalogue) ; la flaque unique, les voiles qui coupent
# la lumière, un poste de niveau difficile dans sa niche, un labyrinthe à fenêtres basses, la meute, un duel de part et d'autre de voiles (9.7 à 9.9 : « equipe », un voile).
# `test_chapitres_marche_07_09` (le jeu monté, à pas d'image fixe — `case` plus bas ; elle HÉRITE de `test_chapitres_marche`) : le vrai corps parcourt les rondes, les zones et les
# PNJ LIBRES des chapitres 7 à 9, franchit les goulets et les portes étroites, ne sort jamais du sol.
SUITES+=(test_chapitres_marche_07_09)

fail=0
# Scénarios qui n'ont pas pu tourner (port occupé). Comptés à part : une mesure
# qui n'a pas eu lieu n'est pas une mesure ratée.
reportes=0

# ---------------------------------------------------------------------------
# LE JEU DÉMARRE-T-IL ? — quinze secondes, et ça manquait
# ---------------------------------------------------------------------------
#
# **Soixante et onze suites vertes n'ont jamais prouvé que le jeu se lance**, et
# le 2026-09-09 la session DA7 l'a payé : après une fusion, cinq classes
# nouvelles étaient injoignables (« Identifier not declared »), le jeu ne
# démarrait plus — **et sa suite dédiée était verte.** Elle chargeait ses
# fichiers par `preload` sur un CHEMIN, ce qui ne consulte jamais le registre des
# noms de classe. Le code était bon des deux côtés ; seul le registre était en
# retard.
#
# ⚠️ **Le contrôle ne peut PAS reposer sur le code de sortie, et c'est mesuré.**
# Contre-test du 2026-09-09 : cache de classes vidé, `--quit-after 2000` imprime
# **771 `SCRIPT ERROR`** et sort en **0**. Un contrôle qui lirait le code de
# sortie certifierait donc un jeu mort — pire que pas de contrôle du tout, parce
# qu'il rassure. On lit la SORTIE, comme le fait déjà chaque suite de ce lanceur
# et comme `run_visuel.sh` le fait pour les erreurs d'analyse.
#
# Il est en TÊTE : si le jeu ne démarre pas, tout ce qui suit est du bruit.
echo "── Le jeu démarre-t-il ? ──"
demarrage="$(mktemp)"
"$GODOT" --headless --path . --no-eos --quit-after 2000 > "$demarrage" 2>&1
if grep -q "SCRIPT ERROR" "$demarrage"; then
  echo "demarrage                    ÉCHEC"
  echo "    Le jeu ne démarre pas. $(grep -c 'SCRIPT ERROR' "$demarrage") erreur(s) de script."
  grep "SCRIPT ERROR" "$demarrage" | head -3 | sed 's/^/    /'
  echo "    Si c'est après une fusion ou un ajout de class_name :"
  echo "    godot --headless --path . --import   (le registre des classes est en retard)"
  fail=1
else
  echo "demarrage                    OK"
fi
rm -f "$demarrage"
echo
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
    # Les contrôles qui ont rougi, tant qu'on a la sortie sous la main : une suite qui rougit UNE fois sur sept ne se
    # relit plus après coup (test_arena_matter, 2026-09-24 : six passes vertes ensuite, la ligne perdue).
    printf '%s\n' "$sortie" | grep -E '✗' | head -6
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

# `test_iso_camera` compare deux parties pas pour pas : à pas d'image fixe, sans quoi le moment
# où une balle éteinte quitte la scène dépend du rendu (voir `_simulation_inchangee`, et les
# Pièges connus de la ROADMAP). Avant `--script` : c'est un argument du moteur, pas du jeu.
# `test_entrainement_bot` y est aussi : il compte des SECONDES SIMULÉES (distance parcourue, blocage), qui ne valent que si une
# image fait un pas de physique ; il vérifie lui-même l'horloge et refuse de conclure sans elle.
for t in "${SUITES[@]}"; do
  case "$t" in
    # `test_chapitres_marche_07_09` joue les trente salles des chapitres 7 à 9 au vrai corps, dont celles de 100×80 cases : 4 min 28 s seule
    # dans le conteneur cloud (mesuré le 2026-10-03). Son plafond : 600 s, un peu plus de deux fois cela.
    test_chapitres_marche_07_09) PLAFOND_SUITE=600 run "$t" --fixed-fps 60 --script "res://tools/$t.gd" ;;
    # `test_chapitres_marche_04_06` joue vingt-sept salles (dont neuf à chasseurs, 45 s de jeu chacune) : ~130 s au calme (132 s mesurées), plus que le plafond de 120 s des autres suites
    # (mesuré le 2026-10-03 : 38 s le chapitre 4, 45 s le 5, 61 s le 6). Il a donc son plafond, jamais plus large que ce qu'il lui faut pour sortir.
    test_chapitres_marche_04_06) PLAFOND_SUITE=420 run "$t" --fixed-fps 60 --script "res://tools/$t.gd" ;;
    # `test_banc_bot` joue ~48 duels simulés : 43 s en CI, mais 1 min 42 à 1 min 54 dans le conteneur cloud au calme (4 cœurs lents, mesuré le
    # 2026-10-03), à quelques secondes du plafond de 120 s — et au-delà dès que la machine est chargée (« n'est pas sorti en 120s »). Son plafond est
    # donc le sien : 300 s, soit 2,5 fois le plus lent mesuré au calme ; un vrai blocage reste attrapé.
    test_banc_bot) PLAFOND_SUITE=300 run "$t" --fixed-fps 60 --script "res://tools/$t.gd" ;;
    # `test_chapitres_marche` (chapitres 1 à 3, le vrai corps) : 115 à 141 s seule dans le conteneur cloud au calme (mesuré le 2026-10-05,
    # chantier OMBRES, sur deux arbres dont celui d'avant le lot) — au-delà des 120 s communs, et rouge dans deux suites entières sur
    # trois. Son plafond est donc le sien, comme celui de ses sœurs : 360 s, 2,5 fois le plus lent mesuré ; un vrai blocage reste attrapé.
    test_chapitres_marche) PLAFOND_SUITE=360 run "$t" --fixed-fps 60 --script "res://tools/$t.gd" ;;
    # `test_ombres_pnj`, `test_ombres_plafonniers`, `test_ombres_voxel` et `test_ombres_allegement` montent une vraie salle
    # d'aventure, comme les suites d'aventure de la ligne suivante : à pas d'image fixe.
    test_ombres_pnj|test_ombres_plafonniers|test_ombres_voxel|test_ombres_allegement) run "$t" --fixed-fps 60 --script "res://tools/$t.gd" ;;
    test_iso_camera|test_entrainement_bot|test_bot_combat|test_aventure_partie|test_aventure_restes|test_aventure_hud|test_aventure_tirs_pnj|test_bot_equipement|test_aventure_boss|test_chapitres_marche) run "$t" --fixed-fps 60 --script "res://tools/$t.gd" ;;
    *) run "$t" --script "res://tools/$t.gd" ;;
  esac
done
# ISO6 — les suites de RÉFÉRENCE 2D, sous le drapeau de débogage `--2d`.
#
# L'iso est le jeu par défaut depuis ISO6 : toute suite qui monte `main.tscn` tourne donc sous la
# vue iso, qui retire les sprites de corps des vues (couche 0, remplacés par les corps voxel) et
# force le chemin sous-vue. Les suites ci-dessous mesurent le RENDU DE LA VUE DE DESSUS — couches
# de visibilité des sprites, masques des vues — et non la simulation ; la vue de dessus restant le
# moteur de lumière que l'iso projette, jusqu'à ISO9, elles gardent leur sens et restent au lot,
# sous le drapeau. Une suite n'entre ici que si ses contrôles rouges en iso sont des contrôles de
# la vue de dessus, relus un par un — jamais pour faire taire un défaut de l'iso.
SUITES_2D=(test_tir_et_reserves)
for t in "${SUITES_2D[@]}"; do run "$t" --script "res://tools/$t.gd" -- --2d; done
# GV1bis — la fumée SOUS ses drapeaux, lus par la porte commune des drapeaux au lancement et non basculés par un banc :
# le retour aux couches d'avant (le shader des voxels jamais chargé), puis la taille fine, les hachures et le relief du
# bruit ensemble (le choix d'un nuage né sous un drapeau est celui du drapeau).
run test_fumee_voxel_couches --script "res://tools/test_fumee_voxel.gd" -- --fumee-couches
run test_fumee_voxel_drapeaux --script "res://tools/test_fumee_voxel.gd" -- --fumee-voxels=fin --fumee-encre=hachures --fumee-relief=bruit
# GV2 — les nappes à l'essai, lu au lancement (la variante « braises »).
run test_nappes_voxel_braises --script "res://tools/test_nappes_voxel.gd" -- --nappes-voxels=braises
# RR1 — l'essai sans encre, lu au lancement (`--sans-encre`) : l'encre part, la matière reste ; il l'emporte sur `--encre-essai`.
run test_rendu_rr_sans_encre --script "res://tools/test_rendu_rr.gd" -- --sans-encre --encre-essai
run test_rendu_rr_sans_courbe --script "res://tools/test_rendu_rr.gd" -- --sans-courbe
run test_netcode res://tools/test_netcode.tscn
# Une scène et non un --script : player.gd s'appuie sur des autoloads que le mode
# --script ne déclare pas à la compilation (voir l'en-tête du test).
run test_halo_proximite res://tools/test_halo_proximite.tscn
# L'accroupi (chantier MURS BAS, MB2) : une scène pour la même raison — un vrai
# joueur qui marche, et les autoloads qu'il nomme.
run test_accroupi res://tools/test_accroupi.tscn

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

# L'instant où l'hôte apprend qu'il est apparié — et où il ne doit RIEN lancer.
#
# `match_ready` est émis dans la foulée de `host_matched_game()` : aucun pair ne
# peut encore être là. L'hôte tombait alors dans la branche « resté seul » de
# `_start_round()` et y restait pour toujours, la porte PRÊT ayant retiré le
# départ automatique à l'arrivée du client. Une instance suffit à le prouver :
# le défaut est dans l'ORDRE, pas dans le réseau.
run test_depart_apparie res://tools/test_online_match.tscn -- --appariement

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

# Le départ d'un match APPARIÉ — le seul qui n'entre pas par un salon à code.
#
# L'appariement ouvre le lien puis annonce, dans le même appel : il annonce donc
# AVANT que le lien soit établi. Personne ne couvrait cet ordre, et il a produit
# le 2026-09-09 le pire état atteignable à deux machines — l'hôte seul dans son
# arène pour toujours, l'invité connecté mais resté dans son menu, sans une seule
# erreur console. Les deux moitiés se testent séparément : `--appariement` (une
# instance) prouve qu'il ne part pas seul, celui-ci qu'il part quand l'autre
# arrive.
duo duo_apparie --apparie

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
