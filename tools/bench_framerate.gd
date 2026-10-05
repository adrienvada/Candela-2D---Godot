## Banc de cadence d'image en conditions de pire cas, FENÊTRÉ.
##
## La passe de performance de l'étape 9 avait été mesurée côté CPU seulement
## (`bench_particles.gd`, headless). Déplafonner la cadence d'image déplace la
## question sur le GPU : le jeu tient-il réellement sa cadence cible quand les
## deux vues rendent, torches allumées, pendant un échange au pompe (`--classe=<slug>` pour une autre classe) ?
## (La cible est `CIBLE_1_POURCENT_BAS`, plus bas — elle a valu 120, elle vaut
## 60 depuis le 2026-08-25, et l'écrire en toutes lettres ici l'a déjà périmée
## une fois.)
##
## Headless ne répond pas — rien n'est rasterisé. Ce banc ouvre donc une vraie
## fenêtre. Il n'est jamais lancé par le jeu.
##
## Lancer : godot --path . res://tools/bench_framerate.tscn -- [--seconds 15] [--max-fps 0]
##
## ## OM6 — le MODE SOLO et les trois INTERRUPTEURS DE LUMIÈRE (chantier OMBRES, 2026-10-04)
##
## Le coût de la lumière EN SOLO n'avait jamais été relevé : ce banc ne savait mesurer qu'un duel. Deux ajouts, et le duel n'est
## pas touché (sans ces drapeaux, rien de ce qui suit ne tourne ni ne s'imprime).
##
## - `--solo=<chapitre>.<salle>` (`--solo=8.9` : le chapitre 8, sa 9e salle, `assets/solo/chapitre_08/niveau_09.json`) : au lieu du
##   duel, la salle d'aventure, en vue iso comme le jeu, VIVANTE. J1 est posté là où le plus de PNJ le voient (le modèle de vue des
##   bots lui-même), torche tenue, immobile (et non en balayage : voir `_poster_j1`), il ne tire pas ; les PNJ le voient, allument
##   leurs torches et TIRENT — une fusillade, le pire cas des lumières (flashs, échos au sol, lumières de coup). Sa vie est remise à
##   plein à chaque pas de physique (voir
##   `SOLO_PV_DE_J1`) : s'il tombait, la salle se recommencerait et la charge changerait. Si la salle se termine quand même, le
##   banc le DIT et refuse le chiffre. Réglages du solo : `--solo-poste=<x>,<y>` (la case de J1, par défaut celle que le modèle
##   choisit) et `--solo-graine=<n>` (la graine des PNJ, 4242 par défaut : deux prises jouent les mêmes bots).
##   `--solo` ne se prend avec aucun drapeau du duel (`DRAPEAUX_DU_DUEL`) : les lire sans les appliquer serait mesurer autre chose.
## - `--sans-ombres-2d` : toute `Light2D` sans ombre (`shadow_enabled` — JAMAIS `enabled`, que lit la perception des bots), y
##   compris celles qui naissent pendant la mesure (flash de bouche, écho au sol, lumière de coup, fusées…), prises par
##   `SceneTree.node_added` et non par un balayage à chaque image.
## - `--sans-capteurs` : les capteurs de corps (`CapteurCorps`, des sous-vues de 256² par corps et par objet) ne rendent plus
##   (`UPDATE_DISABLED`). ⚠️ **Le jeu les rallume à CHAQUE image** (`Presentation3D._suivre` et `_suivre_les_figurants` écrivent
##   `UPDATE_ALWAYS`) : un arrêt posé une fois serait annulé à l'image suivante, sans rien dire. Le banc les remet à l'arrêt à
##   `RenderingServer.frame_pre_draw`, après tous les `_process` et avant le dessin — l'entrée que le jeu laisse.
## - `--sans-halos-pnj` (solo seulement) : le halo de proximité (`ambient_light`) de chaque PNJ sans ombre — l'item « halos sans
##   récepteur » d'OM6 —, `shadow_enabled` seul.
##
## Un drapeau posé se lit dans la ligne « Charge », dans l'en-tête du RÉSULTAT, et dans un bloc « Interrupteurs » que le banc
## écrit AVANT le verdict avec ce que chacun a vraiment touché (lumières éteintes, nées pendant la mesure, capteurs repris au
## jeu, halos) et ce qu'il a vérifié à la fin : une prise ne dit pas « sans ombres » sans l'avoir prouvé.
extends Node

## La cible, en un seul endroit — le verdict la lit, il ne la réécrit pas.
##
## ⚠️ **Le verdict était écrit en dur à 120, et il l'est resté après que la
## barre soit passée à 60** (chantier R, étape R5, décision d'Adrien du
## 2026-08-25, `CLAUDE.md` et `docs/ROADMAP.md`). Le banc annonçait donc
## « NON TENU » sur un jeu qui **atteint** la cible en vigueur — un outil de
## mesure qui rend le verdict d'une règle abrogée, ce qui est pire qu'un outil
## muet : on l'a cru.
##
## Le nombre vit ici et nulle part ailleurs dans ce fichier, pour que la
## prochaine décision d'Adrien n'ait qu'une ligne à changer.
##
## ⚠️ **Ne pas « corriger » les 120 qui restent plus bas dans ce fichier.** Ce
## sont des relevés HISTORIQUES — « les relevés historiques (1 % bas ≥ 120,
## médianes 145 à 160) » —, et les réécrire ferait mentir des mesures qui ont
## réellement été prises sous l'ancienne barre.
const CIBLE_1_POURCENT_BAS := 60.0

## Durée d'échauffement, non mesurée.
##
## ⚠️ **Elle valait 2 s, et l'échauffement réel en dure DOUZE.** Mesuré le
## 2026-08-25 sur un relevé de 60 s : **100 % des images lentes tombent dans les
## douze premières secondes**, puis plus une seule pendant quarante-huit. Un banc
## qui échauffe 2 s et mesure 15 s passait donc les quatre cinquièmes de son
## relevé DANS l'échauffement, et rendait « NON TENU » sur un jeu qui tient sa
## cible : 1 % bas à **60,5** sur la minute, médiane à **144**.
##
## ⚠️ **Le piège est celui de la fenêtre d'observation, et il est général** : une
## fenêtre plus courte que le transitoire qu'elle veut exclure fait passer ce
## transitoire pour un régime permanent. Neuf relevés de 12 à 20 s ont conclu
## « le jeu ne tient pas sa cible » ; un relevé de 60 s dit l'inverse, avec les
## mêmes images. Ce n'est pas le jeu qui a changé, c'est la durée du regard.
## ⚠️ **Elle valait 2 s ; portée à 12 s puis REMISE à 2 s, et le détour est le
## résultat.** Un relevé de 60 s du 2026-08-25 montrait 100 % des images lentes
## dans les douze premières secondes, puis plus une seule pendant quarante-huit :
## un échauffement de 2 s laissait donc le transitoire dans la mesure. Mais
## porter l'échauffement à 12 s **n'a rien amélioré** — 43, 45, 45 — ce qui
## réfute l'explication.
##
## Ce que la série entière dit, elle : **les relevés de la session ont dérivé
## vers le bas de bout en bout** — 60/51/57, puis 43/45/51, puis 43/45/45 — après
## une vingtaine de bancs fenêtrés enchaînés en une heure. **La machine chauffait,
## et c'est le banc qui la chauffait.**
##
## ⚠️ **Un banc de cadence lancé en boucle mesure sa propre chaleur.** Aucun
## garde-fou du fichier ne l'attrape : il vérifie le focus, la charge, les
## conditions de rendu — pas l'état thermique, qui est invisible depuis le
## processus. Deux relevés séparés de dix minutes ne sont pas deux échantillons
## de la même population.
##
## **Le protocole qui vaut** : machine refroidie, UN relevé long (60 s), pas dix
## courts. Le 1 % bas est de toute façon la moyenne du centile le plus lent — il
## trouve toujours une queue, quelle qu'elle soit, donc le multiplier ne le
## stabilise pas, ça l'use.
##
## ⚠️ **Portée à 12 s une seconde fois, le 2026-09-23 (ISO12, session cloud, sur un constat d'ISO7 Gadgets)**, et le détour
## ci-dessus ne la contredit pas : il réfutait une explication de la DÉRIVE entre relevés (la chaleur), pas le transitoire du
## début de mesure. Sur deux prises complètes et horodatées, machine calme, **53 des 55 images lentes de la prise fusée
## tombaient dans les cinq premières secondes de la mesure**, et la moitié de celles du témoin : le 1 % bas se calculait
## surtout sur des images de chauffe (témoin 76,6 sur toutes les images, 84,8 hors des cinq premières secondes ; fusée 62,1
## et 70,1). D'où, en plus des 12 s : le 1 % bas imprimé DES DEUX FAÇONS (`TRANSITOIRE_SEC`), les images lentes par tranche
## de 10 s, et un verdict qui dit lequel il lit — celui HORS TRANSITOIRE. Un hoquet de début de partie est un autre sujet
## qu'une cadence : il se rapporte à part, il ne décide pas du verdict.
##
## ⚠️ **Portée à 30 s PAR DÉFAUT le 2026-09-23 au soir (session cloud, 16:38, sur la trouvaille d'ISO7 Gadgets)**, et pour une
## raison qui n'est PAS le jeu : **chaque lancement de Godot déclenche l'indexation de macOS** — `spotlightknowledged`, avec
## `mediaanalysisd`, à 47-83 % d'un cœur pendant 10 à 20 s. Quinze lancements, quinze pics, zéro dans les 30 s qui précèdent
## le premier ; ni le journal (écrit sous /tmp), ni `user://` (rien écrit pendant la série), ni l'arbre (sous /tmp) n'en sont
## la cause. Une chauffe plus courte que ce pic fait mesurer la cadence PENDANT l'indexation, à l'insu de qui lance le banc —
## Adrien compris : c'est pourquoi c'est un DÉFAUT et non une option. La fenêtre du verdict (hors des dix premières secondes
## de mesure, `TRANSITOIRE_VERDICT_SEC`) ne bouge pas : une chose à la fois.
const WARMUP_SEC := 30.0
## Les premières secondes de la MESURE, rapportées à part (voir `WARMUP_SEC`).
const TRANSITOIRE_SEC := 5.0
## Et DIX, sur lesquelles le verdict se lit depuis le 2026-09-23 (session cloud, 07:43, décidé AVANT les relectures). Les cinq
## restent imprimées, pour la comparaison avec les relevés d'avant. ⚠️ Le motif avancé alors — « le transitoire de C déborde les
## cinq secondes : 92 images lentes dans les dix premières » — venait du compteur par tranche fautif (ex æquo comptés, voir
## `_report`) et a été retiré ; la décision des dix secondes, prise avant les chiffres, reste.
const TRANSITOIRE_VERDICT_SEC := 10.0
## La classe des deux joueurs, par son SLUG : le POMPE par défaut — le cône le plus large, donc le pire cas que ce banc mesure —,
## une autre par `--classe=<slug>` (`--classe=fusil` reproduit les séries passées, voir ci-dessous).
##
## ⚠️ **Le banc a joué au FUSIL pendant qu'on écrivait « au pompe »** (ISO12, 2026-09-23, vu par ISO7 Gadgets dans la ligne
## « Manche lancée — armes : Fusil / Fusil » que ce banc imprime). Il pressait le bouton à la PLACE 2 du râtelier
## (`SHOTGUN_INDEX`), qui était le pompe tant que la liste suivait l'ordre du catalogue ; depuis 0e43dd4, `ui.gd` range les
## boutons par RANG d'affichage, et la place 2 porte le Fusil — `ui.gd` le disait lui-même (« l'index de classe, pas la place
## dans la liste »). Toutes les séries prises depuis sont au fusil. Désormais : le bouton dont l'index de classe est celui du
## slug (`UI.set_weapon_selection`), jamais une place ; et la prise REFUSÉE si la classe équipée n'est pas celle voulue.
const CLASSE_PAR_DEFAUT := "pompe"
var _classe := CLASSE_PAR_DEFAUT
## Portée utile du pompe : assez près pour que chaque tir touche.
const DUEL_DISTANCE := 150.0

var _main: Node
var _ui: Node
## **Temps d'image, en secondes — pas des fps.**
##
## Le banc échantillonnait `Engine.get_frames_per_second()` à chaque frame. Or ce
## compteur n'est mis à jour qu'**une fois par seconde** : quinze secondes de
## mesure donnaient quinze valeurs distinctes, recopiées cent quarante fois
## chacune. Le tableau paraissait riche — 2082 échantillons au relevé du
## 2026-08-18 — et ne contenait que quinze mesures.
##
## Conséquence directe sur le seul chiffre qui compte : le « 1 % bas » est censé
## dire ce que le joueur ressent comme saccade, c'est-à-dire le comportement des
## images les plus lentes. Calculé sur des moyennes d'une seconde, **il ne peut
## rien en dire** : une seconde à 150 fps contenant une image à 20 ms se lit
## comme une seconde à 150 fps. Le relevé rendait `1 % bas == minimum`, ce qui
## est la signature du défaut — un percentile sur des doublons est un minimum.
var _samples: Array[float] = []
## ISO12 — l'instant (s depuis le début de la mesure) de chaque image de `_samples`, pour DATER les pires ; et la pire image
## de l'échauffement, qui dit si un hoquet de compilation y est tombé plutôt que dans la mesure.
var _samples_t: Array[float] = []
var _pire_echauffement := 0.0
## ISO12 — l'instant absolu (`Time.get_ticks_usec`) de chaque image mesurée, et celui du début de la mesure : la pire image
## se compare aux premiers allumages du miroir de lumière (`LumieresIso.premiers_allumages`), sur la même horloge.
var _samples_us: Array[int] = []
var _debut_mesure_us := 0
## Liserés du son visible déjà reçus au départ de la mesure, par vue (voir `_liseres_recus`).
var _liseres_au_depart: Array = []
## ISO12 — `--chauffe-couverture` : la chauffe allume une fois CHAQUE sorte de lampe à l'écran avant le chronomètre, au lieu
## de seulement durer (complément de la session cloud, 02:05 : trois secondes de torche ne compilent ni la fusée ni ce que la
## torche éteinte laisse). Sans ce drapeau, la chauffe reste par durée — c'est la comparaison demandée.
var _chauffe_couverture := false
## ISO12 — `--lampe-dominante` : le prototype de la lampe dominante (`Presentation3D.relief_dominante_3d`), à mesurer contre la
## lumière 3D sans ombres (A) en relevés alternés (session cloud, 03:13).
var _lampe_dominante := false
## ISO12 — `--ombres-spots-seules` (« D-léger ») : les ombres sur les seuls spots, les omnis (fusée, flash, braises) sans ombre,
## donc sans cubemap (`Presentation3D.ombres_omni_3d`). Pour chiffrer le prix des ombres omni dans le tableau C/A/B/D.
var _ombres_spots_seules := false
## ISO12 — `--seuil-lent 25` : dater TOUTE image mesurée au-dessus de ce seuil (ms), pas seulement les cinq pires. Demandé par
## ISO7 Gadgets (2026-09-23) : sous la fusée, la queue du 1 % bas pourrait venir des sauts de l'âge de la fusée tenue par le banc
## (période de 6,5 s, voir `_stress`) plutôt que de la fusée — des images lentes rangées sur ses multiples le diraient. 0 : éteint.
var _seuil_lent_ms := 0.0
## Les images lentes de la mesure ([instant µs, durée s, instant depuis le début de la mesure s]) et les ÉVÉNEMENTS de mise en
## scène datés ([instant µs, libellé]) : le rapport range chaque image lente à côté de l'événement le plus proche.
var _lentes: Array = []
var _evenements: Array = []
var _age_fusee_precedent := -1.0
## ISO12 — `--temps-par-vue` : le temps de rendu CPU et GPU de CHAQUE viewport actif, image par image (`RenderingServer.
## viewport_set_measure_render_time`), en médiane et au 99e centile. Demandé par la session cloud (04:55) pour répartir le coût
## de la fusée entre les vues ; éteint par défaut (la mesure elle-même a un coût).
var _temps_par_vue := false
## ISO12 — LES SIX DRAPEAUX DE LA FUSÉE (spécification d'ISO7 Gadgets, 2026-09-23 ; OUI de la session cloud, 04:55) : chacun
## RETIRE une partie de la fusée du banc (`--fusee`) pour répartir son coût. Éteints par défaut, jamais en jeu.
## ⚠️ Les trois premiers sont reposés À CHAQUE IMAGE, juste après `appliquer_age` (`_poser_les_drapeaux_de_la_fusee`) :
## `Fusee._appliquer_age` réécrit `Halo.enabled`, `Voile.visible` et `NappeN.visible` à chaque image, et un drapeau posé une seule
## fois serait annulé à l'image suivante, sans rien dire — le relevé dirait « la lumière 2D ne coûte rien ». Et c'est toujours
## `visible = false` / `enabled = false`, jamais l'alpha : un quad transparent se rasterise et se mêle comme un autre.
var _fusee_sans_lumiere2d := false   # --fusee-sans-lumiere2d : la PointLight2D « Halo » éteinte (son énergie reste écrite)
var _fusee_sans_ombre2d := false     # --fusee-sans-ombre2d : son ombre seule (la passe d'ombre, que le compteur d'appels ne voit pas)
var _fusee_sans_fumee2d := false     # --fusee-sans-fumee2d : les nappes et le voile (⚠️ change le contenu des lightmaps)
var _fusee_sans_volume := false      # --fusee-sans-volume : le volume de fumée iso (`IsoVolumes.volumes_actifs`)
var _fusee_sans_lueurs := false      # --fusee-sans-lueurs : la lueur posée et celles de la comète (`IsoVolumes.lueurs_actives`)
var _fusee_couches := -1             # --fusee-couches N : les couches du volume de la fusée (`IsoVolumes.couches_fusee`)
## Q58 — `--fusee-age S` : la fusée du banc TENUE à cet âge de combustion (secondes) au lieu de boucler dans la braise — pour
## mesurer l'allumage (0,5 s : le halo à la portée des torches, la fumée qui monte). Négatif (le défaut) : la boucle d'avant.
var _fusee_age := -1.0
var _fusee_age_annonce := false
var _vues_mesurees: Array = []
var _temps_vues: Dictionary = {}
var _seconds := 15.0
## ISO12 — la lumière 3D bridée pendant le relevé, et sa variante.
var _lumiere3d := false
var _lumiere3d_sans_ombres := false
var _lumiere3d_echelle := 1.0
var _peak_particles := 0
var _peak_bullets := 0
## Les compteurs du serveur de rendu, relevés à chaque image mesurée : appels
## de dessin, objets, primitives (2026-09-11, régression de cadence du décor
## d'arène — ils disent où va le temps de rendu, indépendamment du focus).
var _appels: Array[int] = []
var _objets: Array[int] = []
## ISO12 — l'instant de mesure de chaque relevé de rendu, pour la table par tranche de 10 s (`_rapporter_par_tranche`).
var _rendu_t: Array[float] = []
var _primitives: Array[int] = []
## Postes RETIRÉS de la charge. Les trois drapeaux se composent, ce qui donne les
## sept configurations utiles sans en inventer d'autres.
var _sans_vue := false
var _sans_torches := false
var _sans_shaders := false
## Poste AJOUTÉ à la charge (chantier FUSÉE, FU2) : une fusée en pleine braise,
## fumée dense, entretenue pendant toute la mesure — c'est le banc qui décide
## si les nappes + voile tiennent le 1 % bas, jamais l'intuition.
var _fusee := false
var _fusee_banc: Fusee
## Poste AJOUTÉ à la charge (étape 28, lot F) : une torche fantôme et une nappe de
## poudre chargée de traces. ⚠️ **Ce qu'on mesure ici n'est PAS la killcam** — elle
## n'est pas une image de match et ne décide pas du 1 % bas. C'est l'ENREGISTREMENT à
## 60 Hz, qui tourne dans chaque manche : un `etat_de_rejeu()` par gadget, plus la
## boucle des traces. Le banc joue déjà une vraie manche, donc il enregistre déjà ; il
## ne posait simplement aucun gadget.
var _gadgets := false
var _poudre_banc: GadgetPoudre = null
var _torche_banc: GadgetBase = null
## Mode menus (session voisine), qui n'est pas une variante du duel.
var _variante := ""
## Mesure la charge des MENUS au lieu du duel. Voir `_stress_menus()`.
var _menus := false
## Images mesurées pendant que la fenêtre n'avait PAS le focus.
##
## macOS bride une fenêtre au second plan. La ROADMAP attribuait déjà à ça la
## dispersion des relevés du 2026-08-16 — 145 à 160 de médiane sur trois
## exécutions — mais le banc ne le mesurait pas : il ne pouvait donc ni le
## confirmer ni l'écarter. Un relevé pris derrière une autre fenêtre est un
## PLANCHER, pas une mesure, et il doit le dire lui-même.
var _images_hors_focus := 0
## Chantier R — mesurer la VUE UNIQUE (en ligne, entraînement) et non l'écran
## scindé. La charge simulée reste celle du duel complet : seul le chemin de
## RENDU change, ce qui est exactement ce que le chantier déplace.
var _vue_unique := false
## Force la vue unique à repasser par son `SubViewport`, c'est-à-dire l'état
## d'AVANT le chantier R. Sert à mesurer les deux chemins dans la même session,
## sur la même machine, sous le même focus.
var _sans_racine := false
## Chantier ISO, relevé de fin de chantier — mesurer la VUE ISOMÉTRIQUE (`--iso`), avec
## `--vue-unique` ou en écran scindé, et la taille de sa lightmap (`--lightmap 1080p|plein`).
## La charge simulée reste celle du duel : seul le rendu change. ⚠️ Un relevé « iso » pris pendant
## que la vue iso s'est éteinte mesurerait la vue de dessus sous le nom de l'iso (piège d'ISO3b) :
## le banc refuse de démarrer si elle ne tient pas, et refuse le chiffre si elle s'éteint en route.
var _iso := false
var _lightmap := ""
var _images_hors_iso := 0
## Images mesurées où la lampe d'un joueur ne suivait PAS la demande du banc, et
## images mesurées pendant le décompte de départ (le jeu y éteint les torches
## lui-même : elles ne sont pas un désaccord, elles sont hors de la question).
## Voir `tenir_la_torche()` — sans ces compteurs, le banc a mesuré un mois entier
## torches éteintes en annonçant « torches allumées ».
var _torches_desaccord := 0
var _torches_decompte := 0
## Le compteur de pas de physique à la dernière image vue EN décompte.
var _pas_du_decompte := -1

# ---------------------------------------------------------------------------
# OM6 — LE MODE SOLO ET LES INTERRUPTEURS DE LUMIÈRE (voir l'en-tête du fichier)
# ---------------------------------------------------------------------------

## La vie de J1 en solo, remise à CHAQUE PAS DE PHYSIQUE (`physics_frame`, avant que le pas ne simule) — et non à 100 ni à chaque
## image. Deux raisons. **Le pas, pas l'image** : sous llvmpipe (ou à 20 images par seconde) plusieurs pas de physique passent entre
## deux images, et une remise « par image » laisserait les coups s'additionner jusqu'à la mort. **Plus que 100** : une salve de
## pompe (huit plombs de 10 à 20) tombe en UN pas, et aucune remise entre deux pas n'y peut rien. J1 ne doit JAMAIS mourir : sa mort
## recommence la salle (nouveaux PNJ, carton, bots à mémoire vide) et la charge mesurée n'est plus celle qu'on annonce. Rien du
## jeu ne lit cette valeur autrement que par seuils (le cœur qui bat à 30, la barre de vie, qui plafonne) ; les coups encaissés, eux,
## se comptent ici, et le rapport les dit.
const SOLO_PV_DE_J1 := 1000.0
## Le fichier de progression du banc : à lui, JAMAIS `user://solo.cfg` (la vraie progression du joueur). Effacé avant d'être écrit et
## dès que la salle est posée (la partie garde la progression en mémoire) : il ne reste rien sur le poste.
const SOLO_PROGRESSION := "user://bench_framerate_progression.cfg"
## La graine des PNJ par défaut (`GameState.graine_du_bot` : sans elle, chaque prise sème ses bots au hasard et deux prises ne
## jouent pas la même salle). ⚠️ Cela ne rend pas deux prises identiques : le jeu tire aussi au `randf()` global (poussière,
## ambiance — « Pièges connus », 2026-10-03).
const SOLO_GRAINE_PAR_DEFAUT := 4242
## Le poste de J1 se cherche sur une case sur `SOLO_POSTE_PAS` (en x et en y) : assez fin pour trouver le coin d'où l'on voit, assez
## large pour que la recherche tienne en moins d'une seconde sur une carte de 100 × 80.
const SOLO_POSTE_PAS := 3
## Et il ne se pose jamais à moins de cette distance (px) du départ d'un PNJ : J1 ne naît pas dans un corps.
const SOLO_POSTE_ECART_MIN_PX := 80.0
## Les drapeaux du DUEL, que `--solo` refuse : ils règlent une scène que le solo ne joue pas, et les lire sans les appliquer ferait
## mesurer autre chose que ce qu'on croit (le mode de défaillance de la journée du 2026-09-14). `--classe=` est un préfixe.
const DRAPEAUX_DU_DUEL := ["--fusee", "--gadgets", "--une-vue", "--sans-torches", "--sans-shaders", "--vue-unique", "--sans-racine",
	"--menus", "--2d", "--lumiere3d", "--sans-ombres", "--echelle", "--chauffe-couverture", "--lampe-dominante",
	"--ombres-spots-seules", "--fusee-sans-lumiere2d", "--fusee-sans-ombre2d", "--fusee-sans-fumee2d", "--fusee-sans-volume",
	"--fusee-sans-lueurs", "--fusee-couches", "--fusee-age"]
## `--solo=<chapitre>.<salle>`, tel que reçu ; vide hors solo.
var _solo := ""
## [chapitre, index de la salle (de 0)] : « 8.9 » → [8, 8].
var _solo_salle: Array = []
var _solo_graine := SOLO_GRAINE_PAR_DEFAUT
## La case de J1 imposée par `--solo-poste=<x>,<y>` ; (-1, -1) : celle que le modèle choisit.
var _solo_poste_force := Vector2i(-1, -1)
## Le niveau préparé de la salle (`AventureFormat.preparer_niveau`), son titre, et la progression du banc.
var _solo_niveau: Dictionary = {}
var _solo_titre := ""
var _prog: AventureProgression
## Le poste de J1 : `case`, `centre` (px), `visee` (unitaire), `vus` (combien de PNJ le voient au départ), `candidats`.
var _solo_poste: Dictionary = {}
## Vrai pendant la MESURE (pas pendant l'échauffement) : ce que le pas de physique compte des coups reçus.
var _solo_en_mesure := false
## Les PV de J1 perdus pendant la mesure, et le nombre de pas de physique où il en a perdu.
var _solo_pv_perdus := 0.0
var _solo_pas_touches := 0
## Le plus grand écart de J1 à son poste (px) : il ne doit pas bouger.
var _solo_derive_max := 0.0
## Les coups tirés par les bots de la salle au départ de la mesure : instance → coups.
var _solo_coups_au_depart: Dictionary = {}
## Par image mesurée : combien de PNJ en combat, torche allumée, flash de bouche allumé.
var _solo_combat: Array[int] = []
var _solo_torches_pnj: Array[int] = []
var _solo_flashs_pnj: Array[int] = []
## Non vide si la salle a quitté la phase de jeu : `phase`, `a` (s depuis le début de la boucle), `mesure` (vrai : dans la mesure),
## `raison`. Le banc s'arrête alors — la charge n'est plus celle qu'on annonce — et le dit.
var _solo_perdue: Dictionary = {}
## Les trois interrupteurs de lumière (`--sans-ombres-2d`, `--sans-capteurs`, `--sans-halos-pnj`), et ce qu'ils ont vérifié à la fin.
var _interrupteurs := Interrupteurs.new()
var _interrupteurs_verifies: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_seconds = float(_value(args, "--seconds", "15"))
	# Deux charges, deux mesures. La vitrine des menus est une passe de rendu par
	# image dans le hub ; le duel est une simulation à deux vues. **Un chiffre
	# pris dans l'une ne dit rien de l'autre**, et les mélanger dans un seul
	# relevé donnerait une moyenne qui ne décrit aucun des deux moments du jeu.
	_menus = args.has("--menus")
	# Le banc impose sa cadence : sans cela il hériterait du plafond enregistré
	# dans les préférences et deux exécutions ne seraient plus comparables.
	# PE3.1 — le banc tient le plafond lui-même : sans ce drapeau, GameSettings
	# poserait son plafond des menus et `--menus` mesurerait 120 au lieu de la charge.
	GameSettings.pilotage_externe = true
	Engine.max_fps = int(_value(args, "--max-fps", "0"))
	# ISO14 — `--physique N` : les pas de physique par seconde, pour une prise DIAGNOSTIQUE (l'écran scindé iso bridé à
	# 60, hypothèse d'ISO7 Gadgets : un chemin calé sur la physique). Absent, rien ne change ; relu sur « Cadence : ».
	if args.has("--physique"):
		Engine.physics_ticks_per_second = int(_value(args, "--physique", "60"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_couper_le_son("avant la scène")
	_reclamer_le_premier_plan()

	# **Décomposer, parce qu'un total n'est pas une explication.**
	#
	# La roadmap attribuait les 7,6 ms du duel à « deux SubViewport qui rendent
	# chacun leur jeu de lumières et d'ombres portées ». C'était une hypothèse
	# écrite comme un fait, et jamais mesurée — la forme exacte de ce que le
	# 2026-08-18 a passé la journée à démonter ailleurs.
	#
	# Trois variantes, même charge et même durée que le duel complet, chacune
	# retirant UN poste :
	#   --une-vue      : la seconde vue ne rend plus  → coût du double rendu
	#   --sans-torches : les torches restent éteintes → coût des Light2D/occluders
	#   --sans-shaders : les matériaux du joueur sautent → coût des .gdshader
	#
	# **Ce que ça donne et ce que ça ne donne pas.** Les postes se recouvrent :
	# une torche éteinte allège aussi le second viewport. La somme des écarts ne
	# fera donc pas 7,6 ms, et n'a pas à la faire. On obtient l'ORDRE DE GRANDEUR
	# de chaque poste — pas une décomposition exacte. Le dire évite qu'on prenne
	# plus tard ce chiffre pour plus précis qu'il n'est.
	_sans_vue = args.has("--une-vue")
	_sans_torches = args.has("--sans-torches")
	_sans_shaders = args.has("--sans-shaders")
	_fusee = args.has("--fusee")
	_gadgets = args.has("--gadgets")
	_vue_unique = args.has("--vue-unique")
	_sans_racine = args.has("--sans-racine")
	# ISO6 — l'iso est le jeu, donc le banc la mesure par défaut ; `--2d` mesure la vue de dessus
	# (drapeau de débogage, comme dans le jeu). `--iso` reste accepté : les commandes des relevés
	# d'ISO5 le portent.
	if args.has("--iso") and args.has("--2d"):
		printerr("✗ --iso et --2d ensemble : un relevé ne mesure qu'une vue")
		_sortir(2)
		return
	_iso = not args.has("--2d")
	_lightmap = _value(args, "--lightmap", "")
	# ISO12 — la lumière 3D bridée, éteinte par défaut comme dans le jeu. Sans ces drapeaux, ce banc mesure la vue iso d'ISO11.
	_lumiere3d = args.has("--lumiere3d")
	_lumiere3d_sans_ombres = args.has("--sans-ombres")
	_chauffe_couverture = args.has("--chauffe-couverture")
	_lampe_dominante = args.has("--lampe-dominante")
	_ombres_spots_seules = args.has("--ombres-spots-seules")
	_seuil_lent_ms = float(_value(args, "--seuil-lent", "0"))
	_temps_par_vue = args.has("--temps-par-vue")
	for a in args:
		if a.begins_with("--classe="):
			_classe = a.trim_prefix("--classe=")
	_fusee_sans_lumiere2d = args.has("--fusee-sans-lumiere2d")
	_fusee_sans_ombre2d = args.has("--fusee-sans-ombre2d")
	_fusee_sans_fumee2d = args.has("--fusee-sans-fumee2d")
	_fusee_sans_volume = args.has("--fusee-sans-volume")
	_fusee_sans_lueurs = args.has("--fusee-sans-lueurs")
	_fusee_couches = int(_value(args, "--fusee-couches", "-1"))
	_fusee_age = float(_value(args, "--fusee-age", "-1"))
	_lumiere3d_echelle = float(_value(args, "--echelle", "1"))
	# OM6 — le mode solo et les trois interrupteurs de lumière. Refusés AVANT tout le reste : un drapeau lu sans être appliqué est la
	# forme de défaillance que ce banc a le plus payée (« ce relevé n'a pas mesuré ce qu'il annonce »).
	var refus_solo := refus_du_solo(args)
	if not refus_solo.is_empty():
		for r in refus_solo:
			printerr("✗ ", r)
		_sortir(2)
		return
	_interrupteurs.sans_ombres_2d = args.has("--sans-ombres-2d")
	_interrupteurs.sans_capteurs = args.has("--sans-capteurs")
	_interrupteurs.sans_halos_pnj = args.has("--sans-halos-pnj")
	var solo_demande: Variant = valeur_egal(args, "--solo")
	if solo_demande != null:
		_solo = String(solo_demande)
		_solo_salle = lire_la_salle(_solo)
		var poste_demande: Variant = valeur_egal(args, "--solo-poste")
		if poste_demande != null:
			_solo_poste_force = lire_le_poste(String(poste_demande))
		var graine_demandee: Variant = valeur_egal(args, "--solo-graine")
		if graine_demandee != null:
			_solo_graine = int(String(graine_demandee))
		# Le solo est TOUJOURS en vue unique (une salle, un joueur) : `_vue_iso_tenue()` attend une vue iso non scindée.
		_vue_unique = true
	if (_lumiere3d_sans_ombres or args.has("--echelle")) and not _lumiere3d:
		printerr("✗ --sans-ombres et --echelle se prennent avec --lumiere3d")
		_sortir(2)
		return
	if _lumiere3d and not _iso:
		printerr("✗ --lumiere3d est une variante de la vue iso : pas avec --2d")
		_sortir(2)
		return
	if _lightmap != "" and not (_iso and Presentation3D.LIGHTMAPS.has(_lightmap)):
		printerr("✗ --lightmap se prend avec la vue iso (pas avec --2d) et attend %s (reçu « %s »)"
			% [" | ".join(Presentation3D.LIGHTMAPS), _lightmap])
		_sortir(2)
		return
	if not _iso:
		GameSettings.mode_iso = false
	if _iso:
		var absents_iso := preconditions_iso(GameSettings)
		if not absents_iso.is_empty():
			printerr("✗ --iso : %s" % "; ".join(absents_iso))
			_sortir(1)
			return
		# Pour cette exécution seulement : ni `set_vue_de_dessus()` ni sauvegarde, rien ne s'écrit dans
		# settings.cfg (`pilotage_externe` est déjà posé).
		GameSettings.mode_iso = true
		GameSettings.iso_lightmap = _lightmap if _lightmap != "" else "1080p"
	if args.has("--menus"):
		_variante = "--menus"

	print("=== Banc de cadence d'image ===")
	print("Charge: %s" % _libelle_charge())
	# ⚠️ « vsync: désactivé » est ce que ce banc a DEMANDÉ (plus haut), pas une relecture : la vérité est dans la
	# ligne « Cadence : » imprimée au départ de la mesure.
	print("Plafond: %s | vsync: désactivé" % ("aucun" if Engine.max_fps == 0 else str(Engine.max_fps)))

	if _solo != "":
		# Pour cette exécution seulement (`GameSettings` ne sauvegarde pas une simple écriture) : sans lui, l'intro dessinée recouvre
		# la salle — le duel du banc s'en passe parce que `settings.cfg` le dit déjà, un foyer neuf ne le dit pas (`prise.sh` l'écrit).
		GameSettings.intro_vue = true
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_couper_le_son("après la scène")
	_ui = _main.get_node("UI")

	# **Vérifier ses appuis AVANT de mesurer.** Le banc lisait `btn_mode_local`,
	# disparu avec la refonte des menus de la Phase 5 : il s'ouvrait, levait une
	# erreur de script, n'entrait jamais dans le duel, et **restait ouvert sans
	# rien mesurer**. Il a fallu le tuer à la main, le jour où on avait besoin du
	# chiffre. Un banc qui échoue doit le dire et sortir.
	var manquants := preconditions_menus(_ui) if _menus \
		else (preconditions_solo(_ui, _main) if _solo != "" else preconditions_manquantes(_ui, _main))
	if not manquants.is_empty():
		printerr("✗ le banc ne peut pas démarrer — le jeu a changé sous lui :")
		for m in manquants:
			printerr("    · ", m)
		printerr("  Voir tools/test_banc.gd, qui vérifie ces appuis en headless.")
		_sortir(1)
		return

	if _menus:
		await _mesurer_menus()
		return
	if _solo != "":
		await _mesurer_solo()
		return

	# Écran partagé : les DEUX vues rendent, chacune avec son jeu de lumières et
	# d'ombres portées. C'est le pire cas de la passe de performance.
	#
	# Le mode ne se choisit plus par un bouton mais par la navigation, qui écrit
	# `_intended_mode`. Le banc n'a pas d'écran à parcourir : il pose l'intention
	# directement, comme le ferait l'entrée « 1V1 écrans scindés ».
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	# La classe par son INDEX de catalogue, cherché par slug — jamais une place du râtelier (voir `CLASSE_PAR_DEFAUT`).
	var idx_classe := index_de_classe(_main, _classe)
	if idx_classe < 0:
		printerr("✗ --classe=%s : aucune classe de ce slug au catalogue" % _classe)
		_sortir(1)
		return
	_ui.set_weapon_selection(0, idx_classe)
	_ui.set_weapon_selection(1, idx_classe)
	if _ui.selected_weapon_index(0) != idx_classe or _ui.selected_weapon_index(1) != idx_classe:
		printerr("✗ la classe « %s » (index %d) n'a pas de bouton dans les râteliers : prise refusée" % [_classe, idx_classe])
		_sortir(1)
		return
	_main._on_replay_requested()

	if not await _await(func(): return _main.round_active, 15.0):
		printerr("✗ la manche n'a pas démarré")
		_sortir(1)
		return

	var slug_1 := String(_main.p1.current_weapon.slug())
	var slug_2 := String(_main.p2.current_weapon.slug())
	print("Manche lancée — armes : %s / %s (slugs %s / %s ; voulue : %s)" % [
		_main.p1.current_weapon.name, _main.p2.current_weapon.name, slug_1, slug_2, _classe])
	# La ligne ci-dessus a été, le 2026-09-23, la seule à dire la vérité : elle décide désormais, elle ne fait plus que témoigner.
	if slug_1 != _classe or slug_2 != _classe:
		printerr("✗ la classe équipée (%s / %s) n'est pas celle voulue (%s) : prise refusée" % [slug_1, slug_2, _classe])
		_sortir(1)
		return
	_appliquer_variante()
	if _iso and not await _vue_iso_tenue():
		_sortir(1)
		return
	# ⚠️ ICI et pas à la lecture des options : `poser_lumiere_3d()` échange les shaders des matériaux DÉJÀ construits. Appelé
	# avant que la vue iso ne soit tenue, il ne trouve rien à échanger et ne fait rien, sans le dire.
	if _lumiere3d:
		var iso3d := Presentation3D.instance()
		if iso3d == null:
			printerr("✗ --lumiere3d : pas de Presentation3D une fois la vue iso tenue")
			_sortir(1)
			return
		iso3d.set("bride_mode_3d", 1)
		iso3d.set("bride_echelle_3d", _lumiere3d_echelle)
		iso3d.set("ombres_3d", not _lumiere3d_sans_ombres)
		iso3d.set("relief_dominante_3d", _lampe_dominante)
		# Le banc mesure aussi l'écran scindé, que le jeu laisse éteint (GO réduit, 2026-09-23).
		iso3d.set("lumiere_3d_ecran_scinde", true)
		if _ombres_spots_seules:
			iso3d.set("ombres_omni_3d", false)
		iso3d.poser_lumiere_3d(true)
		await get_tree().process_frame
		print("Lumière 3D    : allumée, bride identité échelle %.2f, ombres %s, lampe dominante %s"
			% [_lumiere3d_echelle, "non" if _lumiere3d_sans_ombres else ("spots seuls" if _ombres_spots_seules else "oui"),
			"oui" if _lampe_dominante else "non"])
		# ISO12 — trois secondes rendues AVANT le chronomètre, la lumière 3D allumée : ses shaders et leurs variantes compilent
		# ici, pas dans la mesure. La pire image de ce préchauffage est imprimée : si le hoquet y tombe, c'était une compilation.
		_pire_echauffement = 0.0
		await _stress(3.0, false)
		print("Préchauffage lumière 3D : 3 s, pire image %.1f ms" % (_pire_echauffement * 1000.0))
		if _chauffe_couverture:
			await _chauffer_par_couverture()
	# OM6 — les interrupteurs de lumière, armés AVANT l'échauffement : les shaders et les passes d'ombre qui compilent à la chauffe
	# sont ceux de la charge mesurée. Sans drapeau, rien n'est branché ni imprimé : le duel reste ce qu'il était.
	_armer_les_interrupteurs([])
	_poser_les_drapeaux_des_volumes()
	_conditions()
	print("Échauffement %.0f s (chargement des shaders, remplissage du pool)…" % WARMUP_SEC)
	_pire_echauffement = 0.0
	await _stress(WARMUP_SEC, false)
	print("  pire image de l'échauffement : %.1f ms" % (_pire_echauffement * 1000.0))

	print("Mesure sur %.0f s…" % _seconds)
	# ISO14 — l'angle de la caméra, LU dans le jeu au départ de la mesure et non supposé du drapeau : `mode_rendu()`
	# (« iso », ou « iso lacet 45° B ») et la rotation réelle des deux caméras 2D (r = −L). Une prise qui dirait
	# « lacet 45 » sans l'avoir joué se lit ici (demande d'ISO7 Gadgets, série de cadence du 45°, 2026-09-24).
	var cams := []
	for nom in ["cam1", "cam2"]:
		var c = _main.get(nom) if is_instance_valid(_main) else null
		# `+ 0.0` : « 0.0° » et non « -0.0° » à lacet nul (relevé par ISO7 Gadgets).
		cams.append("%.1f°" % (rad_to_deg((c as Camera2D).rotation) + 0.0) if c is Camera2D else "absente")
	print("Rendu : %s · caméras 2D J1 %s, J2 %s" % [GameSettings.mode_rendu(), cams[0], cams[1]])
	# ISO14 — ce qui cadence VRAIMENT la mesure, RELU au départ (demande de la session cloud et d'ISO7 Gadgets,
	# 2026-09-24) : l'écran scindé iso plafonnait à 60 exactement alors que la ligne « Plafond / vsync » de l'en-tête
	# disait « aucun / désactivé » — cette ligne-là dit ce que le banc a DEMANDÉ, celle-ci ce qui s'applique.
	var ecran := DisplayServer.window_get_current_screen()
	print("Cadence : max_fps %d · vsync %d (relu ; 0 désactivée, 1 activée, 2 adaptative, 3 mailbox) · physique %d/s · plafond_effectif %d · pilotage_externe %s · écran %d/%d, %s px, %.0f Hz"
		% [Engine.max_fps, DisplayServer.window_get_vsync_mode(), Engine.physics_ticks_per_second, GameSettings.plafond_effectif(),
		GameSettings.pilotage_externe, ecran + 1, DisplayServer.get_screen_count(), DisplayServer.screen_get_size(ecran),
		DisplayServer.screen_get_refresh_rate(ecran)])
	if _temps_par_vue:
		_armer_temps_par_vue()
	_recenser_les_ombres_2d()
	_liseres_au_depart = _liseres_recus()
	_interrupteurs.commencer_la_mesure()
	_debut_mesure_us = Time.get_ticks_usec()
	await _stress(_seconds, true)
	_finir_les_interrupteurs()
	_report()
	_sortir(0)


## La charge des menus : le hub ouvert, les quinze effets de la vitrine actifs,
## et un curseur qui ne s'arrête jamais.
##
## C'est le pire cas honnête du menu, et il ne ressemble en rien au duel : aucune
## simulation, aucune particule, mais **une passe plein écran par image** (le
## voile relit l'écran) posée sur un fond animé par shader, une torche, une
## rémanence et un titre incandescent. C'est cette charge-là qu'il faut connaître
## avant d'ajouter le flou défocalisé du second étage de M14.
func _mesurer_menus() -> void:
	_ui.show_main_menu()
	await get_tree().process_frame
	print("Menus ouverts — %d effets de vitrine actifs" % _compter_effets())
	print("Échauffement %.0f s (compilation des shaders de la vitrine)…" % WARMUP_SEC)
	await _stress_menus(WARMUP_SEC, false)
	print("Mesure sur %.0f s…" % _seconds)
	await _stress_menus(_seconds, true)
	_report()
	_sortir(0)


## Un curseur qui parcourt les entrées sans jamais s'arrêter, et qui change
## d'écran régulièrement.
##
## Le curseur immobile serait le meilleur cas, pas le pire : la torche, la
## rémanence et la parallaxe du fond **coupent leur traitement au repos** — c'est
## la règle commune de la vitrine. Un banc qui ne bougerait pas mesurerait un
## menu endormi et conclurait que tout va bien.
##
## Le changement d'écran passe par `noter_geste()` puis `push()` : c'est
## exactement ce que fait une entrée pressée, et c'est la seule façon de
## déclencher l'encre coulée — un `push()` nu n'en produit pas, par conception.
func _stress_menus(duration: float, sampling: bool) -> void:
	var elapsed := 0.0
	var depuis_navigation := 0.0
	var index := 0
	var ecrans := ["accueil", "local", "amical", "classe", "custom"]
	var ecran := 0
	while elapsed < duration:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		depuis_navigation += dt

		# Le curseur passe d'une entrée à la suivante à chaque image : c'est plus
		# rapide qu'un humain, et c'est voulu — on mesure le coût de la mise à
		# jour, pas la vitesse d'un pouce.
		var cibles: Array = _ui._nav_candidates(0)
		if not cibles.is_empty():
			index = (index + 1) % cibles.size()
			var cible: Control = cibles[index]
			if is_instance_valid(cible) and cible.is_visible_in_tree():
				_ui._set_focus(0, cible)

		# Une traversée d'écran toutes les 1,2 s : assez pour que l'encre coulée
		# et le glissement soient dans la mesure, pas assez pour que le banc ne
		# mesure QUE des transitions.
		if depuis_navigation >= 1.2:
			depuis_navigation = 0.0
			ecran = (ecran + 1) % ecrans.size()
			var hub = _ui.hub
			if hub != null and hub.has_screen(ecrans[ecran]):
				if not cibles.is_empty():
					hub.noter_geste(cibles[index] as Control)
				hub.push(ecrans[ecran])
			elif hub != null:
				hub.reset()

		if sampling and dt > 0.0:
			_samples.append(dt)
			if not get_window().has_focus():
				_images_hors_focus += 1


func _compter_effets() -> int:
	var vivants := 0
	for nom in ["menu_gnomon", "menu_after_image", "menu_torch", "menu_watcher",
			"menu_passerby", "menu_tracer", "menu_backdrop", "menu_title",
			"menu_veil", "menu_glass"]:
		if nom in _ui and _ui.get(nom) != null:
			vivants += 1
	return vivants


## Les appuis du MODE MENUS, séparés de ceux du duel : les deux modes ne touchent
## pas au même jeu, et une liste commune se serait plainte de l'absence d'une
## arme dans un banc qui n'en tire aucune.
static func preconditions_menus(ui: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null:
		absents.append("main.tscn n'expose plus UI")
		return absents
	for prop in ["hub", "menu_torch", "menu_backdrop", "menu_veil", "menu_glass"]:
		if not prop in ui:
			absents.append("UI.%s a disparu — la vitrine n'est plus là" % prop)
	for methode in ["show_main_menu", "_set_focus", "_nav_candidates"]:
		if not ui.has_method(methode):
			absents.append("UI.%s() a disparu" % methode)
	var hub = ui.get("hub") if "hub" in ui else null
	if hub == null:
		absents.append("UI.hub est nul")
	elif not hub.has_method("noter_geste"):
		# Sans lui, l'encre coulée ne se déclenche pas et le banc mesurerait un
		# menu amputé de l'effet le plus coûteux de la navigation.
		absents.append("MenuHub.noter_geste() a disparu — l'encre ne coulerait pas")
	return absents


# ---------------------------------------------------------------------------
# OM6 — LE MODE SOLO : une salle de l'aventure, vivante, en vue iso
# ---------------------------------------------------------------------------

## La valeur de `<nom>=<valeur>` dans les arguments : `""` pour `<nom>` seul, `null` si le drapeau n'y est pas. Le dernier l'emporte,
## comme dans la lecture de `--classe=`. Statique : `tools/test_banc.gd` la vérifie sans fenêtre.
static func valeur_egal(args: PackedStringArray, nom: String) -> Variant:
	var trouve: Variant = null
	for a in args:
		if a == nom:
			trouve = ""
		elif a.begins_with(nom + "="):
			trouve = a.trim_prefix(nom + "=")
	return trouve


## « 8.9 » → [8, 8] : le chapitre 8, sa 9e salle — l'index part de 0 et les fichiers de 01 (`niveau_09.json`), comme le catalogue du banc
## des ombres. `[]` si le texte n'est pas une salle de l'aventure.
static func lire_la_salle(texte: String) -> Array:
	var m := RegEx.create_from_string("^([0-9]+)\\.([0-9]+)$").search(texte)
	if m == null:
		return []
	var chapitre := int(m.get_string(1))
	var salle := int(m.get_string(2))
	if chapitre > AventureFormat.CHAPITRE_MAX or salle < 1 or salle > AventureFormat.NIVEAUX_PAR_CHAPITRE:
		return []
	return [chapitre, salle - 1]


## Le fichier de la salle `index` (de 0) du chapitre `chapitre`.
static func chemin_de_la_salle(chapitre: int, index: int) -> String:
	return AventureFormat.racine.path_join("chapitre_%02d" % chapitre).path_join("niveau_%02d.json" % (index + 1))


## « 38,20 » → la case (38, 20) ; (-1, -1) si le texte n'en est pas une.
static func lire_le_poste(texte: String) -> Vector2i:
	var morceaux := texte.split(",")
	if morceaux.size() != 2 or not morceaux[0].strip_edges().is_valid_int() or not morceaux[1].strip_edges().is_valid_int():
		return Vector2i(-1, -1)
	var c := Vector2i(int(morceaux[0]), int(morceaux[1]))
	return c if c.x >= 0 and c.y >= 0 else Vector2i(-1, -1)


## Pourquoi ces arguments ne forment pas une prise valide ; vide s'ils en forment une. `--solo` ne se prend avec aucun drapeau du duel
## (`DRAPEAUX_DU_DUEL`), ses réglages ne se prennent qu'avec lui, et `--sans-halos-pnj` n'a de PNJ à éteindre qu'en solo. Statique,
## pour `tools/test_banc.gd`.
static func refus_du_solo(args: PackedStringArray) -> Array[String]:
	var raisons: Array[String] = []
	var solo: Variant = valeur_egal(args, "--solo")
	if solo == null:
		for f in ["--solo-poste", "--solo-graine"]:
			if valeur_egal(args, f) != null:
				raisons.append("%s se prend avec --solo=<chapitre>.<salle>" % f)
		if args.has("--sans-halos-pnj"):
			raisons.append("--sans-halos-pnj : un duel n'a pas de PNJ — il se prend avec --solo=<chapitre>.<salle>")
		return raisons
	var salle := lire_la_salle(String(solo))
	if salle.is_empty():
		raisons.append("--solo attend <chapitre>.<salle> (--solo=8.9 : le chapitre 8, sa 9e salle ; chapitres 0 à %d, salles 1 à %d) — reçu « %s »"
			% [AventureFormat.CHAPITRE_MAX, AventureFormat.NIVEAUX_PAR_CHAPITRE, String(solo)])
	elif not FileAccess.file_exists(chemin_de_la_salle(int(salle[0]), int(salle[1]))):
		raisons.append("--solo=%s : pas de salle, %s n'existe pas" % [String(solo), chemin_de_la_salle(int(salle[0]), int(salle[1]))])
	var interdits: Array[String] = []
	for f in DRAPEAUX_DU_DUEL:
		if args.has(f):
			interdits.append(f)
	if valeur_egal(args, "--classe") != null:
		interdits.append("--classe=")
	if not interdits.is_empty():
		raisons.append("--solo ne se prend pas avec %s : des drapeaux du duel, que le solo ne lit pas — les passer mesurerait autre chose que ce qu'on croit"
			% ", ".join(interdits))
	var poste: Variant = valeur_egal(args, "--solo-poste")
	if poste != null and lire_le_poste(String(poste)) == Vector2i(-1, -1):
		raisons.append("--solo-poste attend une case <x>,<y> (ex. --solo-poste=38,20) — reçu « %s »" % String(poste))
	var graine: Variant = valeur_egal(args, "--solo-graine")
	if graine != null and not String(graine).is_valid_int():
		raisons.append("--solo-graine attend un entier — reçu « %s »" % String(graine))
	return raisons


## Les noms (propriétés, méthodes, constantes) qu'un script déclare, lus SANS l'instancier — une instance créée ici ne serait jamais
## libérée —, et une constante de ce script par son nom (une énumération), `null` si elle n'y est pas.
static func _membres_du_script(chemin: String) -> Dictionary:
	var membres := {}
	var script := load(chemin) as GDScript
	if script == null:
		return membres
	for d in script.get_script_property_list():
		membres[String(d["name"])] = true
	for d in script.get_script_method_list():
		membres[String(d["name"])] = true
	for nom in script.get_script_constant_map():
		membres[String(nom)] = true
	return membres


static func _constante_du_script(chemin: String, nom: String) -> Variant:
	var script := load(chemin) as GDScript
	return script.get_script_constant_map().get(nom) if script != null else null


## Les appuis du MODE SOLO sur le jeu, nommés une fois et vérifiables sans fenêtre (`tools/test_banc.gd`), comme ceux du duel : le banc
## n'est dans aucune suite, et un outil hors couverture se périme en silence. Le solo en a plus que le duel — il pose une partie
## d'aventure, lit ses bots, la perception qu'ils ont de J1 et les lumières de chaque corps. Séparés des appuis du duel : une liste
## commune se plaindrait de la disparition d'une fusée dans un banc qui n'en lance aucune.
static func preconditions_solo(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents
	for methode in ["demarrer_l_aventure", "_set_player_input_provider"]:
		if not main.has_method(methode):
			absents.append("GameState.%s() a disparu" % methode)
	for prop in ["aventure", "figurants", "graine_du_bot", "archiver_les_matchs", "countdown_left", "p1", "p2", "cam1", "particle_pool",
			"bullet_container", "son_visible_actif", "_sons_vues"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	if not "aventure_progression" in ui:
		absents.append("UI.aventure_progression a disparu")
	var j1: Variant = main.get("p1")
	if j1 != null:
		for prop in ["est_pnj", "ambient_light", "flashlight", "muzzle_flash", "hp", "dead", "input_provider", "current_weapon"]:
			if not prop in j1:
				absents.append("Player.%s a disparu" % prop)
		if not (j1 as Object).has_method("reset_step_tracker"):
			absents.append("Player.reset_step_tracker() a disparu")
	# `tenir_la_torche()` ne sait allumer que par la gâchette : sans cette action, J1 resterait éteint et personne ne le verrait.
	if not InputMap.has_action("p1_torch"):
		absents.append("action p1_torch absente de l'Input Map (tenir_la_torche)")
	# Ce que le banc lit ou appelle dans les scripts du solo.
	var attendus := {
		"res://aventure_partie.gd": ["phase", "pnj", "_t", "essais", "morts", "salles_gagnees", "Phase"],
		"res://aventure_format.gd": ["charger_chapitre", "preparer_niveau", "profil_du_pnj", "CHAPITRE_MAX", "NIVEAUX_PAR_CHAPITRE", "CLASSE_PAR_DEFAUT"],
		"res://aventure_progression.gd": ["niveau_reussi", "reussir_niveau", "chapitre_termine", "terminer_chapitre"],
		"res://bot_input_provider.gd": ["etat", "coups_tires", "Etat"],
		"res://navigation_bot.gd": ["depuis_carte", "cases_praticables", "est_praticable", "centre_de_la_case"],
		"res://perception_bot.gd": ["monde_de_la_carte", "cadre_de_vue", "dans_le_cadre", "segment_degage"],
		"res://profil_bot.gd": ["voit", "tire"],
		"res://local_input_provider.gd": ["get_aim_direction", "action_torch"],
		"res://capteur_corps.gd": ["proprietaire", "corps_id", "vue_id", "creer"],
	}
	for chemin in attendus:
		var membres := _membres_du_script(String(chemin))
		if membres.is_empty():
			absents.append("%s ne se charge plus" % String(chemin).get_file())
			continue
		for nom in (attendus[chemin] as Array):
			if not membres.has(String(nom)):
				absents.append("%s ne déclare plus « %s »" % [String(chemin).get_file(), String(nom)])
	var phases: Variant = _constante_du_script("res://aventure_partie.gd", "Phase")
	for nom in ["CARTON", "JEU", "SALLE_GAGNEE", "JOUEUR_ABATTU", "CHAPITRE_FINI"]:
		if not (phases is Dictionary and (phases as Dictionary).has(nom)):
			absents.append("AventurePartie.Phase.%s a disparu" % nom)
	var etats: Variant = _constante_du_script("res://bot_input_provider.gd", "Etat")
	for nom in ["PATROUILLE", "COMBAT"]:
		if not (etats is Dictionary and (etats as Dictionary).has(nom)):
			absents.append("BotInputProvider.Etat.%s a disparu" % nom)
	return absents


## Le poste de J1 : la case d'où le plus de PNJ de la salle le VOIENT à leur départ, par le modèle de vue des bots eux-mêmes
## (`PerceptionBot` : le cadre de leur écran, puis une ligne de vue sans mur haut) et non par une distance devinée. Sans cela, J1 reste
## là où le niveau le dit — le coin d'où l'on entre, loin de tous — et la salle 8.9 (3500 × 2800 px, sept PNJ aux quatre coins) se
## mesure vide : aucune fusillade, le contraire du pire cas qu'on veut chiffrer. Seuls comptent les PNJ qui VOIENT et TIRENT (`voit`,
## `tire` de leur profil). Les ex æquo vont au poste le plus proche de ses tireurs (des coups qui portent), puis à la première case.
## `impose` : la case demandée (`--solo-poste`), évaluée comme une autre. Rend `case`, `centre` (px), `visee` (unitaire, vers les PNJ
## qui le voient), `vus`, `tireurs` (PNJ qui voient ET tirent, au total), `candidats` ; `erreur` si la case imposée n'est pas praticable.
static func choisir_le_poste(niveau: Dictionary, impose: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var carte: Dictionary = niveau["carte"]
	var navigation := NavigationBot.depuis_carte(carte)
	var monde: Dictionary = PerceptionBot.monde_de_la_carte(carte)
	var departs: Array[Vector2] = []
	var yeux: Array[Vector2] = []
	var cadres: Array[Dictionary] = []
	for e: Dictionary in niveau["pnj"]:
		var oeil := NavigationBot.centre_de_la_case(e["case"])
		departs.append(oeil)
		var profil := AventureFormat.profil_du_pnj(e)
		if profil != null and profil.voit and profil.tire:
			yeux.append(oeil)
			cadres.append(PerceptionBot.cadre_de_vue(oeil, Vector2.from_angle(float(e["rotation"]))))
	var candidates: Array[Vector2i] = []
	if impose != Vector2i(-1, -1):
		if not navigation.est_praticable(impose):
			return {"erreur": "la case %s n'est pas praticable (mur, vide ou étau)" % str(impose)}
		candidates.append(impose)
	else:
		for c in navigation.cases_praticables():
			if c.x % SOLO_POSTE_PAS == 0 and c.y % SOLO_POSTE_PAS == 0:
				candidates.append(c)
	var meilleur: Dictionary = {}
	var meilleurs_vus := -1
	var meilleure_somme := INF
	for c in candidates:
		var p := NavigationBot.centre_de_la_case(c)
		if impose == Vector2i(-1, -1):
			var trop_pres := false
			for d in departs:
				if d.distance_to(p) < SOLO_POSTE_ECART_MIN_PX:
					trop_pres = true
					break
			if trop_pres:
				continue
		var vus := 0
		var somme := 0.0
		var barycentre := Vector2.ZERO
		for k in yeux.size():
			if PerceptionBot.dans_le_cadre(p, cadres[k]) and PerceptionBot.segment_degage(yeux[k], p, monde):
				vus += 1
				somme += yeux[k].distance_to(p)
				barycentre += yeux[k]
		if vus > meilleurs_vus or (vus == meilleurs_vus and vus > 0 and somme < meilleure_somme):
			meilleurs_vus = vus
			meilleure_somme = somme
			var visee := Vector2.from_angle(float(niveau["joueur"]["rotation"]))
			if vus > 0 and (barycentre / float(vus)).distance_to(p) > 1.0:
				visee = (barycentre / float(vus) - p).normalized()
			meilleur = {"case": c, "centre": p, "visee": visee, "vus": vus, "tireurs": yeux.size(), "candidats": candidates.size()}
	if meilleur.is_empty() or (impose == Vector2i(-1, -1) and meilleurs_vus <= 0):
		# Personne ne voit nulle part (une salle de pure initiation) : J1 reste où le niveau le met, et le banc le dira.
		var c: Vector2i = niveau["joueur"]["case"]
		meilleur = {"case": c, "centre": NavigationBot.centre_de_la_case(c), "visee": Vector2.from_angle(float(niveau["joueur"]["rotation"])),
			"vus": 0, "tireurs": yeux.size(), "candidats": candidates.size()}
	return meilleur


## Le nombre de salles d'un chapitre, lu dans son manifeste seul : marquer les chapitres d'avant comme finis n'exige pas de les
## charger et de les valider (une grille de navigation par salle).
static func _nombre_de_salles(chapitre: int) -> int:
	var texte := FileAccess.get_file_as_string(AventureFormat.racine.path_join("chapitre_%02d" % chapitre).path_join("chapitre.json"))
	var manifeste: Variant = JSON.parse_string(texte)
	if manifeste is Dictionary and (manifeste as Dictionary).get("niveaux") is Array:
		return ((manifeste as Dictionary)["niveaux"] as Array).size()
	return AventureFormat.NIVEAUX_PAR_CHAPITRE


## Pose la salle demandée : la VRAIE règle d'ouverture de l'aventure (`planche_ombres._poser_la_salle`) — un chapitre s'ouvre quand le
## précédent est TERMINÉ (son boss tombé : `terminer_chapitre`, pas seulement ses salles réussies), une salle quand la précédente est
## réussie —, le départ ordinaire (`demarrer_l_aventure`), J1 à son poste, puis le carton passé d'un coup. Rend faux si elle ne se pose pas.
func _poser_la_salle_solo() -> bool:
	var c: int = _solo_salle[0]
	var i: int = _solo_salle[1]
	var chapitre: Dictionary = AventureFormat.charger_chapitre(AventureFormat.racine.path_join("chapitre_%02d" % c), -1)
	if chapitre.is_empty() or i >= (chapitre["niveaux"] as Array).size():
		printerr("✗ --solo=%s : le chapitre %d ne se charge pas (ses défauts sont criés plus haut) ou n'a pas de salle %d" % [_solo, c, i + 1])
		return false
	_solo_niveau = (chapitre["niveaux"] as Array)[i]
	_solo_titre = String(_solo_niveau["titre"])
	# La progression du banc : un fichier à lui (jamais `user://solo.cfg`, celle du joueur), repartie de zéro à chaque prise.
	_effacer_la_progression_du_banc()
	_prog = AventureProgression.new(SOLO_PROGRESSION)
	for k in c:
		for n in _nombre_de_salles(k):
			if not _prog.niveau_reussi(k, n):
				_prog.reussir_niveau(k, n)
		if not _prog.chapitre_termine(k):
			_prog.terminer_chapitre(k)
	for n in i:
		if not _prog.niveau_reussi(c, n):
			_prog.reussir_niveau(c, n)
	_ui.aventure_progression = _prog
	var classe := String(chapitre["classe_imposee"])
	if classe == "":
		classe = AventureFormat.CLASSE_PAR_DEFAUT
	# Les bots semés : deux prises jouent les mêmes PNJ (voir `SOLO_GRAINE_PAR_DEFAUT`). Le départ ordinaire de l'aventure lit la graine.
	_main.graine_du_bot = _solo_graine
	_main.archiver_les_matchs = false
	if not _main.demarrer_l_aventure(chapitre, i, classe, _prog):
		printerr("✗ la salle %s ne se pose pas (`demarrer_l_aventure` a refusé : voir plus haut)" % _solo)
		return false
	var poste := choisir_le_poste(_solo_niveau, _solo_poste_force)
	if poste.has("erreur"):
		printerr("✗ --solo-poste : %s" % String(poste["erreur"]))
		return false
	_solo_poste = poste
	_poster_j1(poste)
	# Le carton passé d'un coup, et J1 déjà à son poste : à son retrait, chaque bot repart d'une mémoire vide et voit J1 là où il est.
	_main.aventure.set("_t", 1.0e6)
	var en_jeu := await _await(func() -> bool:
		return _main.aventure != null and int(_main.aventure.phase) == AventurePartie.Phase.JEU, 60.0)
	_effacer_la_progression_du_banc()
	if not en_jeu:
		printerr("✗ la salle %s n'est jamais passée en jeu" % _solo)
		return false
	return true


func _effacer_la_progression_du_banc() -> void:
	if FileAccess.file_exists(SOLO_PROGRESSION):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SOLO_PROGRESSION))


## J1 à son poste : immobile, la visée tenue, la torche par la gâchette (voir `PosteDeJ1`), la vie remise à plein à chaque pas.
##
## **Immobile, et non en balayage lent — le choix et ses raisons.** (1) Ce qu'on chiffre dépend de l'EMPRISE des lumières, pas de l'endroit
## où leur cône éclaire : la carte d'ombre d'une lumière se recalcule pour son rectangle et les occulteurs qu'il touche
## (`_recenser_les_ombres_2d`) ; tourner la torche ne fait varier cette emprise que de la marge d'un carré qui pivote (jusqu'à ×1,4 de
## côté), et ne change ni les capteurs ni les halos. Un balayage n'apporterait donc rien à la mesure. (2) Il ne change pas non plus qui ouvre le
## feu : le modèle de vue des bots voit la LAMPE de J1 (« la torche trahit »), où qu'elle regarde. (3) En revanche il ferait glisser la
## caméra (le décalage vers la visée) et glisser le regard sous la pâte (piège du 2026-09-25), donc changer d'une prise à l'autre ce qui
## est dans le champ — et deux prises A/B ne joueraient plus la même scène : une visée tenue est la seule qui se rejoue. (4) Un J1
## immobile est la cible la plus facile : plus de coups au but, donc plus de lumières de coup — le pire cas de cette lumière-là.
func _poster_j1(poste: Dictionary) -> void:
	var j1: Player = _main.p1
	var centre: Vector2 = poste["centre"]
	var visee: Vector2 = poste["visee"]
	var fournisseur := PosteDeJ1.new()
	fournisseur.name = "PosteDeJ1"
	fournisseur.visee = visee
	_main._set_player_input_provider(j1, fournisseur, 0)
	j1.global_position = centre
	j1.velocity = Vector2.ZERO
	j1.global_rotation = visee.angle()
	j1.reset_step_tracker()
	j1.hp = SOLO_PV_DE_J1
	_main.cam1.global_position = centre
	_main.cam1.reset_smoothing()
	get_tree().physics_frame.connect(_remettre_j1_a_plein)


## Avant CHAQUE pas de physique (`physics_frame` part avant que le pas ne simule) : ce que J1 a perdu au pas d'avant se compte, puis sa
## vie revient à plein. Voir `SOLO_PV_DE_J1` pour le pourquoi du pas et de la valeur.
func _remettre_j1_a_plein() -> void:
	var j1: Player = _main.p1 if is_instance_valid(_main) else null
	if j1 == null or j1.dead:
		return
	var perdu := SOLO_PV_DE_J1 - j1.hp
	if perdu > 0.0:
		if _solo_en_mesure:
			_solo_pv_perdus += perdu
			_solo_pas_touches += 1
		j1.hp = SOLO_PV_DE_J1


## La salle est-elle encore celle qu'on mesure ? Vide si oui, sinon la raison. Rien ne se mesure dans un autre état que le jeu en
## cours, J1 vivant, la première fois : une salle recommencée a de nouveaux PNJ (bots à mémoire vide, carton) et une autre charge.
func _etat_de_la_salle() -> String:
	var a: AventurePartie = _main.aventure if is_instance_valid(_main) else null
	if a == null:
		return "la partie d'aventure n'existe plus"
	if int(a.phase) != AventurePartie.Phase.JEU:
		return "la partie a quitté la phase JEU pour %s" % String(AventurePartie.Phase.find_key(int(a.phase)))
	if _main.p1.dead:
		return "J1 est mort"
	if a.morts > 0 or a.essais > 1:
		return "la salle a été recommencée (%d mort(s), essai %d)" % [a.morts, a.essais]
	if a.salles_gagnees > 0:
		return "la salle a été gagnée"
	return ""


## Une charge de solo : J1 tient sa torche au poste, les PNJ jouent (leurs bots les mènent, rien n'est piloté d'ici), et le banc compte
## ce qui se passe. **Le bloc d'échantillonnage est celui de `_stress()`, recopié** : la boucle du duel n'est pas touchée, pour que ses
## séries restent comparables d'une version à l'autre du banc. Sort dès que la salle cesse d'être la salle annoncée (`_solo_perdue`) :
## continuer mesurerait autre chose, et durerait pour rien.
func _stress_solo(duration: float, sampling: bool) -> void:
	var elapsed := 0.0
	var precedent_us := Time.get_ticks_usec()
	while elapsed < duration:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		# ⚠️ **Le temps d'une image se lit à l'HORLOGE MURALE, pas au delta du jeu.** Le delta plafonne à
		# `max_physics_steps_per_frame` pas de physique (8 × 1/8 s = 1 s sous `--physique 8`), et la salle 8.9 dépasse ce plafond
		# sous llvmpipe : la première prise (2026-10-05) a « mesuré » 21 images de 940 à 1 060 ms, toutes collées au plafond — un
		# chiffre qui ne pouvait pas bouger. Baisser la physique pour relever le plafond change la scène (à `--physique 2`, 11 coups
		# de PNJ au lieu de 60 : ce n'est plus la fusillade annoncée). Le temps de JEU (`elapsed`), lui, reste le delta : la durée
		# d'une prise se compte en jeu, comme dans le duel.
		var maintenant_us := Time.get_ticks_usec()
		var dt_mur := float(maintenant_us - precedent_us) / 1.0e6
		precedent_us = maintenant_us
		var raison := _etat_de_la_salle()
		if raison != "":
			_solo_perdue = {"raison": raison, "a": elapsed, "mesure": sampling}
			return
		# Par la GÂCHETTE, comme le duel (voir `tenir_la_torche`) : J1 tient son faisceau, c'est lui que les PNJ voient.
		tenir_la_torche(_main.p1, true)
		_solo_derive_max = maxf(_solo_derive_max, (_main.p1 as Node2D).global_position.distance_to(_solo_poste["centre"] as Vector2))
		if sampling and _iso:
			var iso := Presentation3D.instance()
			if iso == null or not bool(iso.get("_actif")):
				_images_hors_iso += 1
		if not sampling:
			_pire_echauffement = maxf(_pire_echauffement, dt_mur)
			continue
		if dt_mur > 0.0:
			_samples.append(dt_mur)
			_samples_t.append(elapsed)
			_samples_us.append(maintenant_us)
			if dt_mur > 0.05:
				print("  hoquet %.1f ms à %.2f s — lampes : %s" % [dt_mur * 1000.0, elapsed, _etat_des_lampes()])
			if _seuil_lent_ms > 0.0 and dt_mur * 1000.0 > _seuil_lent_ms:
				_lentes.append([maintenant_us, dt_mur, elapsed])
			if _temps_par_vue:
				_relever_temps_par_vue()
		if not get_window().has_focus():
			_images_hors_focus += 1
		_peak_particles = maxi(_peak_particles, _main.particle_pool.active_count())
		_peak_bullets = maxi(_peak_bullets, _main.bullet_container.get_child_count())
		_relever_rendu()
		_rendu_t.append(elapsed)
		_relever_torches_solo()
		_recenser_la_fusillade()


## La lampe de J1 suit-elle la demande, à CETTE image ? Le même contrôle que `_relever_torches()` (voir son piège du décompte), pour J1
## seul : J2 est garé et caché en aventure, et celles des PNJ sont à leurs bots.
func _relever_torches_solo() -> void:
	if _main.countdown_left > 0.0:
		_pas_du_decompte = Engine.get_physics_frames()
	if _main.countdown_left > 0.0 or Engine.get_physics_frames() == _pas_du_decompte:
		_torches_decompte += 1
		return
	if not _main.p1.flashlight.enabled:
		_torches_desaccord += 1


## Qui fait la fusillade, à cette image : les PNJ en combat, ceux dont la torche est allumée, ceux dont le flash de bouche brûle.
func _recenser_la_fusillade() -> void:
	var combat := 0
	var torches := 0
	var flashs := 0
	var partie: AventurePartie = _main.aventure
	for p: Player in partie.pnj:
		if not is_instance_valid(p) or p.dead:
			continue
		if p.flashlight.enabled:
			torches += 1
		if p.muzzle_flash.enabled:
			flashs += 1
		var bot := p.input_provider as BotInputProvider
		if bot != null and bot.etat == BotInputProvider.Etat.COMBAT:
			combat += 1
	_solo_combat.append(combat)
	_solo_torches_pnj.append(torches)
	_solo_flashs_pnj.append(flashs)


## Les coups tirés par les bots de la salle : instance du PNJ → `BotInputProvider.coups_tires`.
func _coups_des_bots() -> Dictionary:
	var coups := {}
	var partie: AventurePartie = _main.aventure
	for p: Player in partie.pnj:
		if is_instance_valid(p) and p.input_provider is BotInputProvider:
			coups[p.get_instance_id()] = (p.input_provider as BotInputProvider).coups_tires
	return coups


func _commencer_la_mesure_solo() -> void:
	_solo_en_mesure = true
	_solo_pv_perdus = 0.0
	_solo_pas_touches = 0
	_solo_derive_max = 0.0
	_solo_combat.clear()
	_solo_torches_pnj.clear()
	_solo_flashs_pnj.clear()
	_solo_coups_au_depart = _coups_des_bots()
	_interrupteurs.commencer_la_mesure()


## La mesure d'une salle d'aventure : la salle posée, la vue iso tenue, les interrupteurs armés, l'échauffement (le temps que les PNJ voient
## J1 et ouvrent le feu), puis la mesure — le même squelette que le duel, la même sortie (`_report`).
func _mesurer_solo() -> void:
	if not await _poser_la_salle_solo():
		_sortir(1)
		return
	if _iso and not await _vue_iso_tenue():
		_sortir(1)
		return
	# Ce que la salle porte AVANT qu'un interrupteur n'y touche : le dénominateur de ce que chacun retire.
	var avant := {
		"lumieres": Interrupteurs.recenser_les_lumieres(get_tree()),
		"capteurs": Interrupteurs.recenser_les_capteurs(get_tree(), _main.p1, _main.p2, _main.aventure.pnj),
	}
	_annoncer_le_solo(avant)
	_armer_les_interrupteurs(_main.aventure.pnj)
	_conditions()
	print("Échauffement %.0f s (chargement des shaders, remplissage du pool — et le temps que les PNJ voient J1 et ouvrent le feu)…" % WARMUP_SEC)
	_pire_echauffement = 0.0
	await _stress_solo(WARMUP_SEC, false)
	print("  pire image de l'échauffement : %.1f ms" % (_pire_echauffement * 1000.0))
	if _solo_perdue.is_empty():
		print("Mesure sur %.0f s…" % _seconds)
		print("  temps d'image lus à l'horloge murale (le delta du jeu plafonne à %d pas × 1/%d s = %.2f s : voir `_stress_solo`)" % [
			Engine.max_physics_steps_per_frame, Engine.physics_ticks_per_second,
			float(Engine.max_physics_steps_per_frame) / float(Engine.physics_ticks_per_second)])
		_annoncer_le_rendu_solo()
		if _temps_par_vue:
			_armer_temps_par_vue()
		_recenser_les_ombres_2d()
		_liseres_au_depart = _liseres_recus()
		_commencer_la_mesure_solo()
		_debut_mesure_us = Time.get_ticks_usec()
		await _stress_solo(_seconds, true)
	_solo_en_mesure = false
	_finir_les_interrupteurs()
	if _samples.is_empty():
		# `_report()` ne dirait que « aucun échantillon » : la raison est ici.
		_rapporter_le_solo()
		_rapporter_les_interrupteurs()
		_sortir(1)
		return
	_report()
	_sortir(1 if not _refus_solo().is_empty() else 0)


## Ce que le solo annonce AVANT de mesurer : la salle, J1 et son poste, les PNJ, les lumières et les capteurs qu'elle porte.
func _annoncer_le_solo(avant: Dictionary) -> void:
	var a: AventurePartie = _main.aventure
	var n := _solo_niveau
	var carte: Dictionary = n["carte"]
	var grille: Variant = carte.get("grid_size")
	var taille_de_la_grille := "%d×%d" % [int(grille["x"]), int(grille["y"])] if grille is Dictionary else str(grille)
	print("Solo          : salle %s « %s » — chapitre « %s », %d PNJ, %d plafonnier(s), carte de %s cases de %d px" % [_solo, _solo_titre,
		String(a.chapitre["titre"]), (n["pnj"] as Array).size(), (n["plafonniers"] as Array).size(), taille_de_la_grille,
		int(carte.get("tile_size", 0))])
	var pnj: PackedStringArray = []
	for k in (n["pnj"] as Array).size():
		var e: Dictionary = (n["pnj"] as Array)[k]
		pnj.append("PNJ_%d %s %s%s" % [k, String(e["classe"]), String(e["profil_nom"]),
			(" " + String(e["temperament"])) if String(e["temperament"]) != "" else ""])
	print("Solo · PNJ    : %s" % " ; ".join(pnj))
	var poste := _solo_poste
	print("Solo · J1     : classe %s, poste case %s (%.0f, %.0f px) %s, visée %.0f°, immobile, torche tenue par la gâchette, ne tire pas ;"
		% [String(_main.p1.current_weapon.slug()), str(poste["case"]), (poste["centre"] as Vector2).x, (poste["centre"] as Vector2).y,
		"imposé (--solo-poste)" if _solo_poste_force != Vector2i(-1, -1) else "choisi par le modèle de vue des bots",
		rad_to_deg((poste["visee"] as Vector2).angle()) + 0.0])
	print("                vu au départ par %d des %d PNJ qui voient et tirent (parmi %d postes essayés) ; vie remise à %.0f à chaque pas de physique"
		% [int(poste["vus"]), int(poste["tireurs"]), int(poste["candidats"]), SOLO_PV_DE_J1])
	if int(poste["vus"]) == 0:
		print("                ⚠ AUCUN PNJ ne voit ce poste au départ : la fusillade ne viendra que s'ils se croisent (`--solo-poste=<x>,<y>` pour en choisir un)")
	print("Solo · graine : PNJ semés à %d (`--solo-graine=<n>` pour une autre) — le jeu tire aussi au `randf()` global : deux prises ne rejouent pas le même combat à l'image près"
		% _solo_graine)
	var j2: Player = _main.p2
	print("Solo · J2     : %s ; sa lumière de proximité %s, son flash de bouche %s, sa torche %s (le jeu le gare sous le premier PNJ)"
		% ["caché" if not j2.visible else "VISIBLE", "allumée" if j2.ambient_light.enabled else "éteinte",
		"allumé" if j2.muzzle_flash.enabled else "éteint", "allumée" if j2.flashlight.enabled else "éteinte"])
	var lum: Dictionary = avant["lumieres"]
	print("Lumières 2D   : %d dans la scène, %d à ombre (avant tout interrupteur) — %s" % [int(lum["total"]), int(lum["a_ombre"]),
		Interrupteurs.decrire(lum["par_etiquette"])])
	var cap: Dictionary = avant["capteurs"]
	print("Capteurs      : %d de corps, %d actifs à cet instant — %s" % [int(cap["total"]), int(cap["rendus"]), Interrupteurs.decrire(cap["par_genre"], "actif")])


## « Rendu » et « Cadence » au départ de la mesure : RECOPIÉS de `_ready()`, dont le duel n'est pas touché (voir `_stress_solo`).
func _annoncer_le_rendu_solo() -> void:
	var cams := []
	for nom in ["cam1", "cam2"]:
		var c = _main.get(nom) if is_instance_valid(_main) else null
		cams.append("%.1f°" % (rad_to_deg((c as Camera2D).rotation) + 0.0) if c is Camera2D else "absente")
	print("Rendu : %s · caméras 2D J1 %s, J2 %s" % [GameSettings.mode_rendu(), cams[0], cams[1]])
	var ecran := DisplayServer.window_get_current_screen()
	print("Cadence : max_fps %d · vsync %d (relu ; 0 désactivée, 1 activée, 2 adaptative, 3 mailbox) · physique %d/s · plafond_effectif %d · pilotage_externe %s · écran %d/%d, %s px, %.0f Hz"
		% [Engine.max_fps, DisplayServer.window_get_vsync_mode(), Engine.physics_ticks_per_second, GameSettings.plafond_effectif(),
		GameSettings.pilotage_externe, ecran + 1, DisplayServer.get_screen_count(), DisplayServer.screen_get_size(ecran),
		DisplayServer.screen_get_refresh_rate(ecran)])


## Pourquoi cette prise de solo ne vaut pas (vide : elle vaut). Ce que `_report()` imprime déjà de son côté (torches) y figure aussi, pour
## le code de sortie.
func _refus_solo() -> Array[String]:
	var raisons: Array[String] = []
	if not _solo_perdue.is_empty():
		raisons.append("la salle n'est plus celle qu'on mesure : %s" % String(_solo_perdue["raison"]))
	if _images_hors_iso > 0:
		raisons.append("la vue iso était éteinte sur %d image(s) mesurée(s)" % _images_hors_iso)
	if _torches_desaccord > 0:
		raisons.append("la torche de J1 n'a pas suivi la demande du banc sur %d image(s)" % _torches_desaccord)
	for defaut in _interrupteurs.defauts(_interrupteurs_verifies):
		raisons.append(defaut)
	return raisons


## Ce que le solo a vraiment joué, imprimé AVANT le verdict : la salle, la fusillade, J1. Ce qui invalide la prise est écrit « ✗ … chiffre
## refusé » ; ce qui la rend douteuse sans l'invalider, « ⚠ ».
func _rapporter_le_solo() -> void:
	var a: AventurePartie = _main.aventure
	if not _solo_perdue.is_empty():
		print("  ✗ SALLE            : %s, à %.1f s de %s — la charge n'est plus la salle annoncée : chiffre refusé"
			% [String(_solo_perdue["raison"]), float(_solo_perdue["a"]), "la mesure" if bool(_solo_perdue["mesure"]) else "l'échauffement"])
	else:
		var debout := 0
		for p: Player in a.pnj:
			if is_instance_valid(p) and not p.dead:
				debout += 1
		print("  Salle            : %s « %s » tenue en jeu sur toute la mesure (phase JEU, J1 vivant, 0 reprise ; %d PNJ debout sur %d)"
			% [_solo, _solo_titre, debout, a.pnj.size()])
	if _images_hors_iso > 0:
		print("  ✗ VUE ISO          : éteinte sur %d image(s) mesurée(s) — chiffre refusé" % _images_hors_iso)
	if _solo_combat.is_empty():
		return
	var apres := _coups_des_bots()
	var coups := 0
	var tireurs := 0
	for id in apres:
		var fait := int(apres[id]) - int(_solo_coups_au_depart.get(id, 0))
		coups += maxi(fait, 0)
		if fait > 0:
			tireurs += 1
	var duree := 0.0
	for s in _samples:
		duree += s
	var avec_flash := 0
	var pic_flash := 0
	for f in _solo_flashs_pnj:
		if f > 0:
			avec_flash += 1
		pic_flash = maxi(pic_flash, f)
	var pic_combat := 0
	for f in _solo_combat:
		pic_combat = maxi(pic_combat, f)
	var pic_torches := 0
	for f in _solo_torches_pnj:
		pic_torches = maxi(pic_torches, f)
	print("  Fusillade        : %d coups de PNJ pendant la mesure (%.1f par seconde), tirés par %d PNJ sur %d · en combat : médiane %d, pic %d · torches de PNJ allumées : médiane %d, pic %d · flash de bouche de PNJ : %.0f %% des images, pic %d à la fois"
		% [coups, float(coups) / maxf(duree, 0.001), tireurs, a.pnj.size(), _mediane_int(_solo_combat), pic_combat,
		_mediane_int(_solo_torches_pnj), pic_torches, 100.0 * float(avec_flash) / float(_solo_flashs_pnj.size()), pic_flash])
	if coups == 0:
		print("  ⚠ AUCUN TIR DE PNJ pendant la mesure : ce n'est pas une fusillade — personne n'a ouvert le feu sur J1 (poste, graine, durée d'échauffement ; `--solo-poste=<x>,<y>` pour en choisir un autre)")
	print("  J1               : poste tenu (écart maximal %.1f px) · touché sur %d pas de physique, %.0f PV perdus (remis à %.0f avant chaque pas) · jamais mort"
		% [_solo_derive_max, _solo_pas_touches, _solo_pv_perdus, SOLO_PV_DE_J1])


## Sortir par la porte du jeu, et non par `get_tree().quit()`.
##
## Le banc instancie `main.tscn`, donc les autoloads EOS : quitter sec ré-entre
## dans `EOS_Platform_Tick()` et le processus meurt en **signal 11** (relevé du
## 2026-08-18, code 134). Les chiffres sortaient avant le crash, donc la mesure
## restait valide — mais c'est le piège d'arrêt propre déjà consigné dans la
## ROADMAP, et en build release la fin du journal serait perdue avec.
func _sortir(code: int) -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
		return
	get_tree().quit(code)


## Les deux joueurs se tirent dessus au pompe, torches allumées, HP maintenus
## pleins pour que l'échange ne s'arrête jamais : impacts, sang, étincelles,
## flashs de bouche et lumières dynamiques tournent en continu.
func _stress(duration: float, sampling: bool) -> void:
	var elapsed := 0.0
	while elapsed < duration and _main.round_active:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		# Les points d'apparition sont aux deux bouts de l'arène : à cette
		# distance les plombs de pompe expirent avant de toucher, et le banc ne
		# produirait aucune particule — il mesurerait une charge imaginaire.
		_main.p2.global_position = _main.p1.global_position + Vector2(DUEL_DISTANCE, 0.0)
		if _fusee and is_instance_valid(_fusee_banc):
			# L'âge (de COMBUSTION, depuis FU2.1) boucle DANS la braise : fumée à
			# pleine densité en continu pendant toute la mesure.
			var age_mis := FuseeModele.FUMEE_MONTEE \
				+ fmod(elapsed, FuseeModele.DUREE_BRAISE - FuseeModele.FUMEE_MONTEE - 0.5)
			if _fusee_age >= 0.0:
				age_mis = _fusee_age
			_fusee_banc.appliquer_age(age_mis)
			_poser_les_drapeaux_de_la_fusee(_fusee_banc)
			if _fusee_age >= 0.0 and not _fusee_age_annonce:
				# Le relevé dit ce qu'il a mesuré : l'âge tenu et l'empreinte que la lumière porte à cet âge (Q58).
				_fusee_age_annonce = true
				var halo := _fusee_banc.get_node_or_null(^"Halo") as PointLight2D
				print("Fusée du banc tenue à l'âge %.2f s : halo de %.0f px d'empreinte, énergie %.2f" % [_fusee_age,
					float(halo.texture.get_width()) * halo.texture_scale if halo != null and halo.texture != null else 0.0,
					halo.energy if halo != null else 0.0])
			# Le BOUCLAGE de l'âge (tous les 6,5 s) est un événement de mise en scène : l'âge saute en arrière, et le rayon du
			# panache, l'alpha et l'échelle des nappes changent d'un coup (lecture d'ISO7 Gadgets, 2026-09-23).
			if sampling and age_mis < _age_fusee_precedent:
				_evenements.append([Time.get_ticks_usec(), "bouclage de l'âge de la fusée"])
			_age_fusee_precedent = age_mis
		# Étape 28, lot F — la nappe est tenue à son plafond de traces : elles
		# s'éteignent en 8 s (`GadgetPoudre.DUREE_LUEUR`) et le relevé en dure 15 à 60.
		# Sans entretien, le banc mesurerait une charge qui fond, et le chiffre ne
		# dirait pas de quoi il est le coût.
		#
		# ⚠️ **FRÈRE du bloc `--fusee`, jamais son enfant.** Il en était l'enfant, et
		# la revue du 2026-09-12 l'a vu avant la première mesure : l'entretien ne
		# tournait alors QUE si `--fusee` était passé aussi, c'est-à-dire jamais dans
		# le mode que le protocole prescrit — `--gadgets` seul contre le banc de base,
		# celui qui isole le poste ajouté.
		if _gadgets:
			_entretenir_la_poudre()
		if sampling and _iso:
			var iso := Presentation3D.instance()
			if iso == null or not bool(iso.get("_actif")):
				_images_hors_iso += 1
		for p in [_main.p1, _main.p2]:
			p.hp = 100.0
			# Torches éteintes : c'est le seul geste du duel qu'on retire, et il
			# emporte avec lui les Light2D, leurs ombres portées et la
			# rétrodiffusion. Le reste de la boucle est identique au mot près.
			# Par la GÂCHETTE, jamais par `flashlight_on` : voir `tenir_la_torche()`.
			tenir_la_torche(p, not _sans_torches)
			if p.shoot_cooldown <= 0.0:
				p.shoot()
		# Se viser mutuellement : les balles portent, donc les impacts aussi.
		_main.p1.rotation = (_main.p2.global_position - _main.p1.global_position).angle()
		_main.p2.rotation = (_main.p1.global_position - _main.p2.global_position).angle()

		if not sampling:
			_pire_echauffement = maxf(_pire_echauffement, get_process_delta_time())
		if sampling:
			# Le temps de CETTE image. La première après l'échauffement peut
			# porter le coût d'un changement d'état ; elle compte quand même,
			# c'est une saccade que le joueur verrait.
			var dt := get_process_delta_time()
			if dt > 0.0:
				_samples.append(dt)
				_samples_t.append(elapsed)
				_samples_us.append(Time.get_ticks_usec())
				# ISO12 — un HOQUET (> 50 ms) se date et s'accompagne de l'état des lampes : en écran scindé, des hoquets de
				# 132 à 138 ms tombaient à 28 et 46 s de mesure, loin de tout premier allumage (chaque vue a ses matériaux).
				if dt > 0.05:
					print("  hoquet %.1f ms à %.2f s — lampes : %s" % [dt * 1000.0, elapsed, _etat_des_lampes()])
				if _seuil_lent_ms > 0.0 and dt * 1000.0 > _seuil_lent_ms:
					_lentes.append([Time.get_ticks_usec(), dt, elapsed])
				if _temps_par_vue:
					_relever_temps_par_vue()
			if not get_window().has_focus():
				_images_hors_focus += 1
			# Relevés au vol : lus après la boucle ils vaudraient zéro, et le
			# banc prétendrait mesurer une charge qu'il n'aurait pas prouvée.
			_peak_particles = maxi(_peak_particles, _main.particle_pool.active_count())
			_peak_bullets = maxi(_peak_bullets, _main.bullet_container.get_child_count())
			_relever_rendu()
			_rendu_t.append(elapsed)
			_relever_torches()

	# Étape 28, lot F — on RECOMPTE après coup, et on refuse le chiffre si la nappe a
	# fondu. ⚠️ Le garde de `_appliquer_variante()` ne voit que la POSE : le fondu des
	# traces, lui, se produit PENDANT la mesure. Un garde évalué avant ne peut pas voir
	# une charge qui fond — il lit 72, accepte, et le relevé part sans dire de quoi il
	# est le coût. C'est exactement ce qui serait arrivé avec l'entretien imbriqué.
	# Le même refus pour les torches : un chiffre « torches allumées » pris lampes
	# éteintes est le coût d'une autre charge, et rien d'autre ne le dirait.
	if sampling and _images_hors_iso > 0:
		printerr("✗ --iso : la vue isométrique était éteinte sur %d image(s) mesurée(s) : chiffre refusé"
			% _images_hors_iso)
		_sortir(1)
	if sampling and _torches_desaccord > 0:
		printerr("✗ la lampe n'a pas suivi la demande du banc sur %d image(s) : chiffre refusé"
			% _torches_desaccord)
		_sortir(1)
	if sampling and _gadgets:
		var restantes := _traces_vivantes()
		if restantes * 2 < GadgetPoudre.MARQUES_MAX:
			printerr("✗ la nappe a fondu pendant la mesure (%d traces sur %d) : chiffre refusé"
				% [restantes, GadgetPoudre.MARQUES_MAX])
			_sortir(1)


## ISO12 — LA CHAUFFE PAR COUVERTURE : chaque sorte de lampe du miroir allumée une fois, À L'ÉCRAN (un objet hors champ ne
## compile rien), sur le sol, les murs et les deux corps, avant le chronomètre. Quatre phases d'une demi-seconde à une seconde,
## chacune avec sa pire image : si l'une d'elles porte le hoquet, c'est la sorte de lampe qu'elle ajoute qui compilait.
func _chauffer_par_couverture() -> void:
	# 1. Une fusée posée entre les deux joueurs : omni à ombre, sur le sol, un mur proche et les deux corps.
	var chauffe: Fusee = null
	if not (_fusee and is_instance_valid(_fusee_banc)):
		chauffe = Fusee.new()
		chauffe.is_replay = true
		chauffe.name = "FuseeChauffe"
		chauffe.depart = _main.p1.global_position + Vector2(DUEL_DISTANCE * 0.5, 24.0)
		chauffe.graine = 4242
		chauffe.joueurs = [_main.p1, _main.p2]
		_main.bullet_container.add_child(chauffe)
		chauffe.appliquer_age(FuseeModele.FUMEE_MONTEE + 1.0)
	_pire_echauffement = 0.0
	await _stress(1.0, false)
	print("Chauffe par couverture — fusée posée : pire image %.1f ms" % (_pire_echauffement * 1000.0))
	if chauffe != null:
		chauffe.queue_free()
	# 2. Torches coupées : plus de spot ni de rétrodiffusion, les tirs seuls (omni sans ombre) — la variante de base « sans spot ».
	var torches := _sans_torches
	_sans_torches = true
	_pire_echauffement = 0.0
	await _stress(0.5, false)
	print("Chauffe par couverture — torches coupées, tirs seuls : pire image %.1f ms" % (_pire_echauffement * 1000.0))
	# 3. Torches rallumées : le retour du spot à ombre et de la rétrodiffusion.
	_sans_torches = torches
	_pire_echauffement = 0.0
	await _stress(0.5, false)
	print("Chauffe par couverture — torches rallumées : pire image %.1f ms" % (_pire_echauffement * 1000.0))
	var miroir := _miroir_de_lumiere()
	if miroir != null:
		print("Chauffe par couverture — sortes déjà allumées : %s" % ", ".join(PackedStringArray((miroir.get("premiers_allumages") as Dictionary).keys())))


## ISO12 — LE RECENSEMENT DES OMBRES 2D, PAR VIEWPORT RENDU, une fois au début de la mesure (demandes d'ISO7 Gadgets, 2026-09-23).
## Chaque Light2D à ombre redessine les occulteurs qu'elle touche, quatre fois par occulteur, et le compteur d'appels de dessin ne
## le voit pas. Hypothèse de la session cloud, à vérifier ici : le rassemblement des lumières d'une vue ne teste pas le masque
## d'éclairage — une lampe dont le rectangle coupe la vue y paierait sa passe d'ombre même sans y éclairer AUCUN objet (le halo
## de proximité d'un joueur, masqué sur son canal privé, dans la lightmap de l'autre). Le compte se prend sur la scène qui tourne,
## pas hors machine. Rectangle d'une lampe : sa texture × `texture_scale`, centrée sur elle ; d'un occulteur : son polygone
## transformé ; d'une vue : son rectangle visible ramené au monde par l'inverse de sa transformation de canevas.
func _recenser_les_ombres_2d() -> void:
	var occulteurs: Array = []
	for n in get_tree().root.find_children("*", "LightOccluder2D", true, false):
		var o := n as LightOccluder2D
		if o.occluder == null or not o.is_visible_in_tree():
			continue
		var pts := o.occluder.polygon
		if pts.is_empty():
			continue
		var r := Rect2(o.global_transform * pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(o.global_transform * p)
		occulteurs.append(r)
	var lampes: Array = []
	for n in get_tree().root.find_children("*", "PointLight2D", true, false):
		var l := n as PointLight2D
		if not (l.enabled and l.shadow_enabled and l.is_visible_in_tree()):
			continue
		var taille := Vector2(64.0, 64.0)
		if l.texture != null:
			taille = Vector2(l.texture.get_size()) * l.texture_scale
		lampes.append([l, Rect2(l.global_position - taille * 0.5, taille)])
	var objets: Array = []
	for n in get_tree().root.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if ci is Light2D or ci is LightOccluder2D or not ci.is_visible_in_tree() or not (ci is Node2D):
			continue
		objets.append(ci)
	var vues: Array = [get_tree().root]
	for n in get_tree().root.find_children("*", "SubViewport", true, false):
		if (n as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
			vues.append(n)
	print("  Ombres 2D : %d occulteurs dans la scène, %d lampes allumées à ombre" % [occulteurs.size(), lampes.size()])
	for v in vues:
		var vp := v as Viewport
		# `get` et non l'accès direct : sur la `Window` racine, première de la liste, `disable_2d` lève une erreur de script qui
		# coupait tout le détail après la ligne d'en-tête (trouvé par ISO7 Gadgets à sa prise de validation, 2026-09-23).
		if vp.get("disable_2d") == true or vp.world_2d == null:
			continue
		var champ: Rect2 = vp.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, vp.get_visible_rect().size)
		var dedans: Array = []
		for e in lampes:
			var l := e[0] as PointLight2D
			if l.get_world_2d() != vp.world_2d or not (e[1] as Rect2).intersects(champ):
				continue
			var eclaire := false
			for ci in objets:
				var item := ci as Node2D
				if item.get_world_2d() != vp.world_2d or (item.visibility_layer & vp.canvas_cull_mask) == 0:
					continue
				# Le MASQUE seul, jamais la position (remarque d'ISO7 Gadgets) : le sol et les murs sont des `TileMapLayer` et un
				# `StaticBody2D` immenses dont l'origine est au coin de la carte — un test par position déclarerait « n'éclaire
				# rien » TOUTES les lampes. Ici le drapeau ne s'allume que si l'inutilité est PROUVÉE : aucun objet de ce viewport
				# ne porte un canal que la lampe éclaire.
				if (item.light_mask & l.range_item_cull_mask) != 0:
					eclaire = true
					break
			dedans.append([l, e[1], eclaire])
		if dedans.is_empty():
			continue
		var n_union := 0
		for r in occulteurs:
			for d in dedans:
				if (r as Rect2).intersects(d[1] as Rect2):
					n_union += 1
					break
		print("  · %s : %d lampes à ombre, %d occulteurs dans leur union — 4 × N × lampes = %d"
			% [String(vp.get_path()) if vp != get_tree().root else "racine", dedans.size(), n_union,
			4 * n_union * dedans.size()])
		for d in dedans:
			var l := d[0] as PointLight2D
			var r := d[1] as Rect2
			print("      %s : %.0f × %.0f px, masque %d%s" % [String(l.get_path()).get_file(), r.size.x, r.size.y,
				l.range_item_cull_mask, "" if d[2] else " — n'éclaire AUCUN objet de ce viewport"])


## Les trois drapeaux de la fusée 2D, reposés à chaque image APRÈS `appliquer_age` (qui les réécrit).
func _poser_les_drapeaux_de_la_fusee(f: Node) -> void:
	var halo := f.get_node_or_null(^"Halo") as PointLight2D
	if halo != null:
		if _fusee_sans_lumiere2d:
			halo.enabled = false
		if _fusee_sans_ombre2d:
			halo.shadow_enabled = false
	if _fusee_sans_fumee2d:
		for n in f.get_children():
			if n is CanvasItem and (String(n.name).begins_with("Nappe") or String(n.name) == "Voile"):
				(n as CanvasItem).visible = false


## Les trois drapeaux des volumes iso, posés une fois la vue iso tenue, AVANT l'échauffement ; puis les volumes vidés, pour que le
## nombre de couches s'applique à une fusée déjà suivie (`_couches()` ne fait que créer).
func _poser_les_drapeaux_des_volumes() -> void:
	if not (_fusee_sans_volume or _fusee_sans_lueurs or _fusee_couches >= 0):
		return
	var iso := Presentation3D.instance()
	var miroirs: Node = iso.get("_miroirs") as Node if iso != null else null
	var volumes: Object = miroirs.get("volumes") if miroirs != null else null
	if volumes == null:
		printerr("✗ drapeaux de la fusée : pas de volumes iso (la vue iso est-elle tenue ?)")
		_sortir(1)
		return
	volumes.set("volumes_actifs", not _fusee_sans_volume)
	volumes.set("lueurs_actives", not _fusee_sans_lueurs)
	volumes.set("couches_fusee", _fusee_couches)
	volumes.call("vider")
	print("Drapeaux de la fusée : volume %s, lueurs %s, couches %s" % ["non" if _fusee_sans_volume else "oui",
		"non" if _fusee_sans_lueurs else "oui", "défaut" if _fusee_couches < 0 else str(_fusee_couches)])


## Les viewports qui rendent (la racine, et chaque SubViewport dont le rendu n'est pas coupé), mesurés à partir de maintenant.
func _armer_temps_par_vue() -> void:
	_vues_mesurees.clear()
	_temps_vues.clear()
	var vues: Array = [get_tree().root]
	for n in get_tree().root.find_children("*", "SubViewport", true, false):
		if (n as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
			vues.append(n)
	for v in vues:
		var rid: RID = (v as Viewport).get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		var nom := String((v as Node).get_path())
		_vues_mesurees.append([rid, nom])
		_temps_vues[nom] = [[], []]


func _relever_temps_par_vue() -> void:
	for e in _vues_mesurees:
		var t: Array = _temps_vues[e[1]]
		(t[0] as Array).append(RenderingServer.viewport_get_measured_render_time_cpu(e[0]))
		(t[1] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(e[0]))


static func _centile(valeurs: Array, q: float) -> float:
	if valeurs.is_empty():
		return 0.0
	var tri := valeurs.duplicate()
	tri.sort()
	return float(tri[mini(tri.size() - 1, int(q * tri.size()))])


func _rapporter_temps_par_vue() -> void:
	if not _temps_par_vue or _vues_mesurees.is_empty():
		return
	var lignes: Array = []
	for nom in _temps_vues:
		var t: Array = _temps_vues[nom]
		lignes.append([_centile(t[1], 0.5), "  %-60s CPU %.2f / %.2f ms · GPU %.2f / %.2f ms (médiane / 99e centile)"
			% [nom.right(60), _centile(t[0], 0.5), _centile(t[0], 0.99), _centile(t[1], 0.5), _centile(t[1], 0.99)]])
	lignes.sort_custom(func(a, b) -> bool: return float(a[0]) > float(b[0]))
	print("  Temps de rendu par vue (%d vues, triées par GPU médian) :" % lignes.size())
	for l in lignes:
		print(l[1])


## Chaque image lente de la mesure, avec l'événement de mise en scène le plus proche (bouclage de la fusée, premier allumage
## d'une sorte de lampe) et l'écart en millisecondes.
func _rapporter_les_lentes() -> void:
	if _seuil_lent_ms <= 0.0:
		return
	var evenements := _evenements.duplicate()
	var miroir := _miroir_de_lumiere()
	if miroir != null:
		var premiers: Dictionary = miroir.get("premiers_allumages")
		for sorte in premiers:
			evenements.append([int(premiers[sorte]), "premier allumage de « %s »" % sorte])
	print("  Images lentes (> %.0f ms) : %d, événements de mise en scène datés : %d" % [_seuil_lent_ms, _lentes.size(),
		evenements.size()])
	for l in _lentes:
		var proche := "aucun"
		var ecart := 0.0
		var meilleur := INF
		for e in evenements:
			var d := float(int(e[0]) - int(l[0])) / 1000.0
			if absf(d) < meilleur:
				meilleur = absf(d)
				ecart = d
				proche = String(e[1])
		print("  lente %.1f ms à %.2f s — le plus proche : %s (%+.0f ms)" % [float(l[1]) * 1000.0, float(l[2]), proche, ecart])


## L'état des lampes 3D allumées, pour dater un hoquet : combien d'omnis et de spots, et combien portent une ombre.
func _etat_des_lampes() -> String:
	var miroir := _miroir_de_lumiere()
	if miroir == null:
		return "aucune lumière 3D"
	var omni := 0
	var spot := 0
	var ombrees := 0
	for l in miroir.find_children("*", "Light3D", true, false):
		var lampe := l as Light3D
		if not lampe.visible:
			continue
		if lampe is SpotLight3D:
			spot += 1
		else:
			omni += 1
		if lampe.shadow_enabled:
			ombrees += 1
	return "%d omni, %d spot, %d à ombre" % [omni, spot, ombrees]


## Le miroir de lumière 3D (`LumieresIso`), ou null hors lumière 3D.
func _miroir_de_lumiere() -> Node:
	var iso := Presentation3D.instance()
	return iso.get("_lumieres") as Node if iso != null else null


## ISO12 — DATER LES PIRES contre les premiers allumages : pour chacune des cinq pires images, la sorte de lampe allumée pour la
## première fois dans les 100 ms qui la précèdent, s'il y en a une. Et chaque premier allumage, en secondes depuis le début de
## la mesure (négatif : pendant la chauffe, donc hors du chiffre).
func _dater_les_pires(ordre: Array) -> void:
	var miroir := _miroir_de_lumiere()
	if miroir == null:
		return
	var premiers: Dictionary = miroir.get("premiers_allumages")
	var lignes: PackedStringArray = []
	for sorte in premiers:
		lignes.append("%s %+.2f s" % [sorte, float(int(premiers[sorte]) - _debut_mesure_us) / 1e6])
	print("  Premiers allumages (depuis le début de la mesure) : %s" % ", ".join(lignes))
	for k in mini(5, ordre.size()):
		var i: int = ordre[k]
		if i >= _samples_us.size():
			continue
		var fin_image: int = _samples_us[i]
		var debut_image: int = fin_image - int(_samples[i] * 1e6)
		for sorte in premiers:
			var t: int = int(premiers[sorte])
			if t >= debut_image - 100000 and t <= fin_image:
				print("  ⚠️ pire image n° %d (%.1f ms) : PREMIER ALLUMAGE de « %s » — compilation, pas régime"
					% [k + 1, _samples[i] * 1000.0, sorte])


## Retire UN poste de la charge, une fois la manche lancée.
##
## Après le lancement et avant l'échauffement : la manche doit démarrer dans les
## mêmes conditions que le duel complet — un décompte qui échouerait faute de
## seconde vue mesurerait autre chose que ce qu'on croit — et l'échauffement doit
## voir la charge définitive, sinon il chargerait des shaders qu'on vient de
## retirer.
func _libelle_charge() -> String:
	if _variante == "--menus":
		return "menus"
	# OM6 — le solo dit sa salle (son titre quand elle est posée) ; les interrupteurs, entre crochets : le libellé est ce que lit
	# l'en-tête du RÉSULTAT, et une prise ne doit jamais perdre le drapeau qui la distingue d'une autre.
	if _solo != "":
		var solo := "solo %s" % _solo
		if _solo_titre != "":
			solo += " « %s »" % _solo_titre
		return solo + _suffixe_des_interrupteurs() + " — VUE ISO, lightmap %s" % (_lightmap if _lightmap != "" else "1080p")
	var retires: Array[String] = []
	if _sans_vue: retires.append("sans 2e vue")
	if _sans_torches: retires.append("sans torches")
	if _sans_shaders: retires.append("sans shaders")
	if _vue_unique:
		retires.append("vue unique" + (" AVANT chantier R" if _sans_racine else " rendue par la racine"))
	var libelle := "duel complet"
	if retires.size() == 3:
		libelle = "socle nu (tout retiré)"
	elif not retires.is_empty():
		libelle = "duel " + ", ".join(retires)
	if _fusee:
		libelle += " + fusée éclairante"
	if _gadgets:
		libelle += " + gadgets (torche fantôme, poudre et ses traces)"
	libelle += _suffixe_des_interrupteurs()
	if _iso:
		libelle += " — VUE ISO, lightmap %s" % (_lightmap if _lightmap != "" else "1080p")
	else:
		libelle += " — VUE DE DESSUS (--2d)"
	return libelle


func _appliquer_variante() -> void:
	# **La vue unique se pose en cachant le conteneur, pas en arretant le rendu.**
	# C'est le geste exact de `_restore_viewports()` en ligne et a l'entrainement,
	# et c'est lui que `_accorder_rendu_aux_vues()` lit pour decider s'il rend
	# dans la racine. Arreter le SubViewport a la main (ce que fait `--une-vue`)
	# mesurerait un ecran scinde ampute, pas une vue unique.
	if _vue_unique:
		_main.rendu_racine_autorise = not _sans_racine
		_main.vp2.get_parent().hide()
		_main.ui.center_line.hide()
		_main._accorder_rendu_aux_vues()
		print("VUE UNIQUE: seconde vue fermee, rendu %s"
			% ("par les SubViewport (avant chantier R)" if _sans_racine else "par la RACINE"))
	if _sans_vue:
		# `UPDATE_DISABLED` et non `hide()` : un conteneur caché laisse le
		# SubViewport rendre dans son coin, et on mesurerait le même coût en
		# croyant l'avoir retiré.
		_main.vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
		print("RETIRÉ: seconde vue arrêtée")
	if _sans_shaders:
		var retires := 0
		for joueur in [_main.p1, _main.p2]:
			retires += _demateriauser(joueur)
		# Un zéro dirait que la variante n'a rien changé, et le banc mesurerait le
		# duel complet sous un autre nom — le mode de défaillance de la journée.
		if retires == 0:
			printerr("✗ aucun matériau retiré : la variante ne mesure rien")
			_sortir(1)
			return
		print("RETIRÉ: %d matériaux des joueurs" % retires)
	if _sans_torches:
		print("RETIRÉ: torches maintenues éteintes")
	if _fusee:
		# Pilotée à la main (patron killcam) plutôt que vivante : sa combustion
		# dure ~20 s, la mesure 60 — l'entretien de l'âge est dans `_stress()`,
		# pour que la charge (fumée dense + lumière) soit CONSTANTE d'un bout à
		# l'autre du relevé au lieu de mourir au premier tiers.
		_fusee_banc = Fusee.new()
		_fusee_banc.is_replay = true
		_fusee_banc.name = "FuseeBanc"
		_fusee_banc.depart = _main.p1.global_position + Vector2(DUEL_DISTANCE * 0.5, 0.0)
		_fusee_banc.graine = 12345
		_fusee_banc.joueurs = [_main.p1, _main.p2]
		_main.bullet_container.add_child(_fusee_banc)
		print("AJOUTÉ: fusée éclairante en braise entretenue (fumée + lumière à ombres)")
	if _gadgets:
		# Posés par le VRAI chemin (`_do_spawn_gadget`) : un gadget ajouté à la main
		# n'aurait ni slug, ni classe de poseur, ni signal de mort — l'instantané ne
		# le verrait pas comme il voit ceux d'un match.
		var axe: Vector2 = (_main.p2.global_position - _main.p1.global_position).normalized()
		_main._do_spawn_gadget(0, _main.p1.global_position + axe * 80.0, 0.0,
			"torche_fantome", 9001)
		_main._do_spawn_gadget(1, _main.p1.global_position - axe * 40.0, 0.0,
			"poudre_contact", 9002)
		_torche_banc = _gadget_du_banc(0)
		_poudre_banc = _gadget_du_banc(1) as GadgetPoudre
		if _torche_banc == null or _poudre_banc == null:
			printerr("✗ la variante --gadgets n'a pas posé ses deux gadgets : rien à mesurer")
			_sortir(1)
			return
		# Charge CONSTANTE d'un bout à l'autre du relevé, comme la fusée pilotée à la
		# main : la durée de vie vient du profil de la classe équipée (le pompe), qui
		# n'est pas celle du gadget posé. Un gadget qui mourrait au premier tiers
		# ferait mesurer deux charges différentes sous un seul chiffre.
		_torche_banc.duree_vie = 0.0
		_poudre_banc.duree_vie = 0.0
		_entretenir_la_poudre()
		var traces := _traces_vivantes()
		# Un zéro dirait que la variante ne mesure rien — le mode de défaillance que
		# `--sans-shaders` a déjà appris à refuser. ⚠️ Ce garde-ci ne voit que la POSE :
		# c'est le recomptage de fin de `_stress()` qui surveille la FONTE.
		if traces == 0:
			printerr("✗ aucune trace de poudre : la variante ne mesure rien")
			_sortir(1)
			return
		print("AJOUTÉ: torche fantôme J1, poudre J2, %d traces entretenues" % traces)


## Le gadget debout de ce joueur, ou `null`.
func _gadget_du_banc(pid: int) -> GadgetBase:
	for g in get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion() and g.poseur_id == pid:
			return g
	return null


## La nappe est REMPLIE puis entretenue à son plafond, À CHAQUE IMAGE de `_stress()` :
## les traces s'éteignent en 8 s et le relevé en dure 15 à 60. Sans entretien, le banc
## mesurerait une charge qui fond.
func _entretenir_la_poudre() -> void:
	if not is_instance_valid(_poudre_banc):
		return
	var vivantes := _traces_vivantes()
	for i in maxi(0, GadgetPoudre.MARQUES_MAX - vivantes):
		var a := randf() * TAU
		var r := sqrt(randf()) * GadgetPoudre.RAYON
		var p: Vector2 = _poudre_banc.global_position + Vector2.from_angle(a) * r
		_poudre_banc._poser_marque(p, Vector2.from_angle(a), 1.0)


## Les traces de poudre encore VIVANTES — les seules qui coûtent quelque chose.
## ⚠️ Une trace `queue_free()` reste dans son groupe jusqu'à la fin de l'image : la
## compter masquerait précisément la fonte qu'on surveille, et le plafond se croirait
## tenu alors que la nappe se vide.
func _traces_vivantes() -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("traces_de_poudre"):
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			n += 1
	return n


## Retire tous les `.material` d'un sous-arbre. Rend le compte — un zéro dirait
## que la variante n'a rien changé, et le banc mesurerait le duel complet sous
## un autre nom.
func _demateriauser(racine: Node) -> int:
	var n := 0
	for enfant in racine.get_children():
		if enfant is CanvasItem and (enfant as CanvasItem).material != null:
			(enfant as CanvasItem).material = null
			n += 1
		n += _demateriauser(enfant)
	return n


## Ce que le banc rendait VRAIMENT, en pixels, imprimé avant de mesurer.
##
## Sans ces lignes, deux relevés ne sont pas comparables et **rien ne le
## signale** — c'est le même mode de défaillance que le compteur de fps mis à
## jour une fois par seconde : un tableau qui a l'air riche et ne dit rien.
##
## Le cas s'est présenté le 2026-08-25 : la fenêtre de débogage a doublé, donc
## le viewport racine est passé de 0,92 à 3,69 Mpx, **pendant que les
## `SubViewport` restaient à 958×1080 chacun**. Les images par seconde ont
## bougé sans qu'aucune ligne du jeu ne change, et les relevés historiques
## (1 % bas ≥ 120, médianes 145 à 160, fenêtre 1280×720) ont cessé d'être
## comparables sans que le banc en dise un mot.
##
## C'est exactement la mesure que le chantier R1-R6 doit déplacer : il fait
## suivre les `SubViewport` à la fenêtre, donc il multiplie la dernière ligne.
func _conditions() -> void:
	var fenetre := DisplayServer.window_get_size()
	var aire := get_viewport().get_visible_rect().size
	# L'étirement est le rapport que `canvas_items` applique entre l'aire 2D et
	# les pixels réels. En `keep` il est identique sur les deux axes.
	var etirement := (float(fenetre.y) / aire.y) if aire.y > 0.0 else 0.0
	print("Fenêtre       : %d×%d pixels natifs (%.2f Mpx)"
		% [fenetre.x, fenetre.y, fenetre.x * fenetre.y / 1e6])
	print("Aire 2D       : %.0f×%.0f — étirement ×%.2f" % [aire.x, aire.y, etirement])
	var pixels_jeu := 0
	for vue in [_main.vp1, _main.vp2]:
		if vue == null:
			continue
		var actif: bool = vue.render_target_update_mode != SubViewport.UPDATE_DISABLED
		print("  %-12s: rendu %d×%d%s"
			% [vue.name, vue.size.x, vue.size.y, "" if actif else "  (ARRÊTÉ)"])
		if actif:
			pixels_jeu += vue.size.x * vue.size.y
	# **Le chantier R déplace le rendu du duel, pas seulement sa taille.** Quand
	# la racine rend le jeu, les `SubViewport` sont arrêtés et ne comptent plus :
	# le duel occupe l'aire 2D rastérisée à la résolution de la fenêtre.
	if _main._rendu_racine:
		var largeur := int(round(aire.x * etirement))
		var hauteur := int(round(aire.y * etirement))
		pixels_jeu = largeur * hauteur
		print("  %-12s: rendu %d×%d  ← chantier R, le duel passe par la RACINE"
			% ["Racine", largeur, hauteur])
	print("Pixels de jeu : %.2f Mpx par image" % (pixels_jeu / 1e6))
	# La vue iso : ses lightmaps et ses vues 3D, telles que `Presentation3D` les décrit (F3).
	if _iso and Presentation3D.instance() != null:
		print("Vue iso       : %s" % Presentation3D.instance().etat.replace("\n", " | "))


## La vue iso tient-elle, et sur la bonne configuration de vues ? Refuse le relevé sinon.
func _vue_iso_tenue() -> bool:
	var tenue := await _await(func() -> bool:
		var p := Presentation3D.instance()
		return p != null and bool(p.get("_actif")) and bool(p.get("_scinde")) != _vue_unique, 5.0)
	if not tenue:
		printerr("✗ --iso : la vue isométrique ne tient pas %s — le relevé mesurerait la vue de dessus sous le nom de l'iso"
			% ("en vue unique" if _vue_unique else "en écran scindé"))
		if Presentation3D.instance() != null:
			printerr("    raison : %s" % Presentation3D.instance().raison_des_vues())
		return false
	return true


## ISO12 — PAR TRANCHE DE 10 s (session cloud, 2026-09-23, 07:46) : la médiane, les images du 1 % le plus lent (par rang), les
## appels de dessin et les objets médians. Une dérive de la MACHINE fait baisser la médiane à comptes plats ; une ACCUMULATION
## dans la scène fait monter les comptes. Sans cette table, une minute de banc ne sépare pas les deux.
func _rapporter_par_tranche(rang_lent: Array, lents: int) -> void:
	var dt_par: Dictionary = {}
	var lents_par: Dictionary = {}
	for i in _samples.size():
		if i < _samples_t.size():
			var k := int(_samples_t[i] / 10.0)
			if not dt_par.has(k):
				dt_par[k] = []
			(dt_par[k] as Array).append(_samples[i])
	for r in mini(lents, rang_lent.size()):
		var i: int = rang_lent[r]
		if i < _samples_t.size():
			var k := int(_samples_t[i] / 10.0)
			lents_par[k] = int(lents_par.get(k, 0)) + 1
	var appels_par: Dictionary = {}
	var objets_par: Dictionary = {}
	for j in mini(_rendu_t.size(), mini(_appels.size(), _objets.size())):
		var k := int(_rendu_t[j] / 10.0)
		if not appels_par.has(k):
			appels_par[k] = []
			objets_par[k] = []
		(appels_par[k] as Array).append(_appels[j])
		(objets_par[k] as Array).append(_objets[j])
	var cles := dt_par.keys()
	cles.sort()
	print("  Par tranche de 10 s (médiane fps | lentes du 1 % | appels | objets) :")
	for k in cles:
		var d: Array = dt_par[k]
		d.sort()
		var a: Array = appels_par.get(k, [0])
		var o: Array = objets_par.get(k, [0])
		a.sort()
		o.sort()
		print("    %3d-%3d s : %5.1f | %4d | %4d | %5d" % [k * 10, k * 10 + 10, 1.0 / float(d[d.size() / 2]),
			int(lents_par.get(k, 0)), int(a[a.size() / 2]), int(o[o.size() / 2])])


## [1 % bas, nombre d'images qui le font] sur les images mesurées APRÈS `depuis_s` secondes de mesure ; [0, 0] s'il n'y en a pas.
func _un_pour_cent_bas_apres(depuis_s: float) -> Array:
	var regime: Array = []
	for i in _samples.size():
		if i < _samples_t.size() and _samples_t[i] >= depuis_s:
			regime.append(_samples[i])
	if regime.is_empty():
		return [0.0, 0]
	regime.sort()
	var lents := maxi(1, int(round(regime.size() * 0.01)))
	var somme := 0.0
	for i in range(regime.size() - lents, regime.size()):
		somme += regime[i]
	return [float(lents) / somme, lents]


## Combien de liserés chaque vue du son visible a reçus depuis sa création (J1, J2).
func _liseres_recus() -> Array:
	var recus := []
	if not is_instance_valid(_main):
		return recus
	for vue in _main.get("_sons_vues"):
		recus.append(int(vue.get("recus_compte")) if is_instance_valid(vue) else 0)
	return recus


## Le son visible pendant la mesure : actif ou coupé, et combien de liserés il a dessinés.
## Posée AVANT le verdict, comme la ligne des torches : c'est une charge, et une prise
## « avec liserés » qui n'en aurait reçu aucun (aucun son localisé, ou le drapeau
## `--sans-son-visible`) ne mesure pas ce qu'elle annonce (demande de Gadgets, 2026-09-29).
func _rapporter_le_son_visible() -> void:
	if not bool(_main.get("son_visible_actif")):
		print("  Son visible      : coupé (--sans-son-visible) — aucun liseré dessiné")
		return
	var fin := _liseres_recus()
	var parts := PackedStringArray()
	var total := 0
	for i in fin.size():
		var n := int(fin[i]) - (int(_liseres_au_depart[i]) if i < _liseres_au_depart.size() else 0)
		if n < 0:
			# Les vues ont été recréées pendant la mesure (nouvelle manche) : leur compteur est reparti de zéro.
			n = int(fin[i])
		total += n
		parts.append("J%d %d" % [i + 1, n])
	print("  Son visible      : actif — %d liserés reçus pendant la mesure (%s)"
		% [total, ", ".join(parts) if not parts.is_empty() else "aucune vue montée"])


func _report() -> void:
	if _samples.is_empty():
		printerr("✗ aucun échantillon")
		return
	# Trié du plus RAPIDE au plus lent : ce sont des durées, pas des cadences.
	var sorted := _samples.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	# Moyenne des cadences = images / temps total, et non moyenne des 1/dt : la
	# seconde donne un poids démesuré aux images rapides et flatte le résultat.
	var avg := float(sorted.size()) / total

	# **1 % bas au sens habituel** : la cadence moyenne du centième d'images le
	# plus LENT. Une moyenne sur cette tranche, et non sa borne — un seul pic
	# isolé ne doit pas décider seul du verdict, mais vingt saccades doivent.
	var lents := maxi(1, int(round(sorted.size() * 0.01)))
	var somme_lentes := 0.0
	for i in range(sorted.size() - lents, sorted.size()):
		somme_lentes += sorted[i]
	var low1 := float(lents) / somme_lentes
	# ISO12 — le même 1 % bas, HORS des premières secondes de la mesure (voir `WARMUP_SEC`) : cinq, et dix pour le verdict.
	var hors_5 := _un_pour_cent_bas_apres(TRANSITOIRE_SEC)
	var hors_10 := _un_pour_cent_bas_apres(TRANSITOIRE_VERDICT_SEC)
	var low1_regime: float = hors_10[0] if hors_10[1] > 0 else low1

	print("\n=== RÉSULTAT (%s) ===" % _libelle_charge())
	print("  Images mesurées  : %d en %.1f s" % [sorted.size(), total])
	print("  FPS moyen        : %.0f" % avg)
	print("  FPS médian       : %.0f" % (1.0 / sorted[sorted.size() / 2]))
	print("  FPS 1 %% bas      : %.0f  (moyenne des %d images les plus lentes, TOUTES images)"
		% [low1, lents])
	print("  FPS 1 %% bas hors 5 s  : %.0f  (moyenne des %d plus lentes, hors des %.0f premières secondes)"
		% [hors_5[0], hors_5[1], TRANSITOIRE_SEC])
	print("  FPS 1 %% bas hors 10 s : %.0f  (moyenne des %d plus lentes, hors des %.0f premières secondes) — lu par le verdict"
		% [hors_10[0], hors_10[1], TRANSITOIRE_VERDICT_SEC])
	# Les images du 1 % le plus lent (toutes images), par tranche de 10 s : où tombe la queue.
	# ⚠️ EXACTEMENT les `lents` images du 1 %, prises par leur RANG. La première version comptait les images « au-dessus du
	# seuil », ex æquo compris — et les durées d'image se répètent à l'identique : la somme des tranches valait jusqu'à 5,5 fois
	# le 1 % annoncé (A : 261 pour 47), et « 55 puis 176 en fin de prise » décrivait un autre ensemble que son étiquette (vu par
	# ISO7 Gadgets, 2026-09-23). Le nombre d'images au seuil ou au-delà s'imprime à part.
	var seuil_lent: float = sorted[sorted.size() - lents]
	var rang_lent: Array = range(_samples.size())
	rang_lent.sort_custom(func(x, y) -> bool: return _samples[x] > _samples[y])
	var tranches: PackedInt32Array = []
	tranches.resize(int(ceil(total / 10.0)) + 1)
	for k in mini(lents, rang_lent.size()):
		var i: int = rang_lent[k]
		if i < _samples_t.size():
			tranches[mini(int(_samples_t[i] / 10.0), tranches.size() - 1)] += 1
	var au_seuil := 0
	for v in _samples:
		if v >= seuil_lent:
			au_seuil += 1
	var par_tranche: PackedStringArray = []
	for k in tranches.size():
		if k * 10.0 < total:
			par_tranche.append("%d-%d s : %d" % [k * 10, k * 10 + 10, tranches[k]])
	print("  Images lentes (les %d du 1 %% le plus lent) par tranche : %s  — seuil %.2f ms, %d images au seuil ou au-delà"
		% [lents, ", ".join(par_tranche), seuil_lent * 1000.0, au_seuil])
	_rapporter_par_tranche(rang_lent, lents)
	print("  Image la plus lente : %.1f ms  (soit %.0f fps)"
		% [sorted[sorted.size() - 1] * 1000.0, 1.0 / sorted[sorted.size() - 1]])
	# ISO12 — les cinq pires, DATÉES : un hoquet unique au début (compilation) ne se lit pas comme un régime.
	var ordre: Array = range(_samples.size())
	ordre.sort_custom(func(a, b) -> bool: return _samples[a] > _samples[b])
	var pires: PackedStringArray = []
	for k in mini(5, ordre.size()):
		var i: int = ordre[k]
		pires.append("%.1f ms à %.2f s" % [_samples[i] * 1000.0, _samples_t[i] if i < _samples_t.size() else -1.0])
	print("  Cinq pires images : %s" % ", ".join(pires))
	_dater_les_pires(ordre)
	_rapporter_les_lentes()
	_rapporter_temps_par_vue()
	print("  Particules (pic) : %d / %d" % [_peak_particles, ParticlePool.MAX_ACTIVE])
	print("  Balles (pic)     : %d" % _peak_bullets)
	if not _appels.is_empty():
		print("  Rendu (médiane par image) : %d appels de dessin, %d objets, %d primitives"
			% [_mediane_int(_appels), _mediane_int(_objets), _mediane_int(_primitives)])
	print("  Mémoire vidéo    : %.0f Mo (textures %.0f Mo, tampons %.0f Mo)" % [
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])
	if _iso and Presentation3D.instance() != null:
		print("  Vue iso          : %s" % Presentation3D.instance().etat.replace("\n", " | "))
	# La ligne des torches AVANT le verdict : elle dit de quelle charge le chiffre
	# est le coût, et un avertissement placé après ce qu'il invalide arrive trop
	# tard (piège du 2026-08-26). Le mode menus n'a pas de joueur : rien à dire.
	if not _menus:
		var demande := "éteintes" if _sans_torches else "allumées"
		if _torches_desaccord == 0:
			print("  Torches          : %s sur toute la mesure (vérifié par image)" % demande)
		else:
			print("  ✗ TORCHES : la lampe n'a pas suivi la demande (« %s ») sur %d image(s)"
				% [demande, _torches_desaccord])
		if _torches_decompte > 0:
			print("    dont %d image(s) mesurées pendant le décompte de départ, où le jeu"
				% _torches_decompte)
			print("    éteint les torches lui-même — non comptées comme désaccord")
		_rapporter_le_son_visible()
		if _solo != "":
			_rapporter_le_solo()
	# OM6 — ce que les interrupteurs de lumière ont touché et vérifié : AVANT le verdict, comme la ligne des torches. Une prise
	# « sans ombres » dont une lumière a gardé la sienne ne mesure pas ce qu'elle annonce, et le dit ici, pas après le chiffre.
	_rapporter_les_interrupteurs()
	print("  Verdict %.0f fps   : %s  (sur le 1 %% bas hors des %.0f premières secondes)" % [CIBLE_1_POURCENT_BAS,
		"TENU" if low1_regime >= CIBLE_1_POURCENT_BAS else "NON TENU (1 %% bas hors 10 s à %.0f)" % low1_regime,
		TRANSITOIRE_VERDICT_SEC])
	# **Ce n'est pas le second plan qui casse le 1 % bas, c'est le CHANGEMENT.**
	#
	# Mesuré le 2026-08-25, cinq relevés à charge et fenêtre identiques : les
	# deux exécutions où la fenêtre a changé d'état de focus donnent un 1 % bas
	# de 44 et 71, les trois qui sont restées dans un état stable donnent 142,
	# 143 et 143. La médiane, elle, ne bouge pas — 144 partout. Une transition
	# de focus coûte une image à 18 ou 60 ms, et vingt images suffisent à décider
	# du percentile.
	#
	# D'où la règle, et elle conditionne tout usage avant/après du banc :
	# **un relevé à focus MIXTE ne se compare à rien et se jette.** Stable au
	# premier plan ou stable au second plan sont l'un et l'autre exploitables ;
	# le second est un plancher, pas une aberration.
	var part := 100.0 * float(_images_hors_focus) / float(sorted.size())
	if _images_hors_focus == 0:
		print("  Focus            : stable au premier plan — relevé comparable")
	elif _images_hors_focus == sorted.size():
		print("  Focus            : stable au SECOND PLAN — comparable, mais c'est un plancher")
	else:
		# **Afficher la MINORITÉ, pas le pourcentage.** Un relevé à 2166 images sur
		# 2173 hors focus s'annonçait « 100 % mixte », ce qui se lit comme une
		# erreur d'affichage et donne envie de passer outre. Les sept images de
		# l'autre état sont pourtant le sujet : le 1 %% bas ne porte que sur une
		# vingtaine d'images, donc une poignée de transitions le décide.
		var minorite := mini(_images_hors_focus, sorted.size() - _images_hors_focus)
		print("  ⚠ FOCUS MIXTE : %d image(s) sur %d dans l'autre état (%.1f %% hors focus)"
			% [minorite, sorted.size(), part])
		print("    La fenêtre a changé d'état pendant la mesure, et le 1 %% bas ne")
		print("    porte que sur %d images : ces transitions le décident." % lents)
		print("    **RELEVÉ À JETER** — refaire sans toucher à la fenêtre.")


## Les appuis du banc sur le jeu, nommés une fois et vérifiables sans fenêtre.
##
## C'est ce qui manquait : **le banc n'est dans aucune suite** — il ouvre une
## fenêtre, il ne peut pas y être — donc rien ne signalait qu'il avait cessé de
## fonctionner. Un outil de mesure hors couverture se périme en silence, et on
## s'en aperçoit au moment précis où on a besoin de la mesure.
##
## La liste est publique et statique pour que `tools/test_banc.gd` la vérifie en
## headless, sans rien rasteriser. Elle ne remplace pas le banc ; elle garantit
## qu'il pourra démarrer.
## Les appuis de la variante `--iso` : les réglages que le banc pose pour l'exécution, et les tailles de
## lightmap que la présentation connaît. Vérifiés en headless par `tools/test_banc.gd`.
static func preconditions_iso(reglages: Object) -> Array[String]:
	var absents: Array[String] = []
	if reglages == null:
		absents.append("GameSettings absent")
		return absents
	for prop in ["mode_iso", "iso_lightmap", "pilotage_externe"]:
		if not prop in reglages:
			absents.append("GameSettings.%s a disparu (variante --iso)" % prop)
	for variante in ["1080p", "plein"]:
		if not Presentation3D.LIGHTMAPS.has(variante):
			absents.append("Presentation3D ne connaît plus la lightmap « %s » (--lightmap)" % variante)
	return absents


static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents
	for prop in ["_intended_mode", "p1_weapon_group", "p2_weapon_group"]:
		if not prop in ui:
			absents.append("UI.%s a disparu" % prop)
	for prop in ["round_active", "p1", "p2", "particle_pool", "bullet_container"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	if not main.has_method("_on_replay_requested"):
		absents.append("GameState._on_replay_requested() a disparu")
	if not main.has_method("spawn_fusee"):
		absents.append("GameState.spawn_fusee() a disparu (variante --fusee)")
	if not main.has_method("_do_spawn_gadget"):
		absents.append("GameState._do_spawn_gadget() a disparu (variante --gadgets)")
	if not "countdown_left" in main:
		absents.append("GameState.countdown_left a disparu (contrôle des torches)")
	# La ligne « Son visible » du relevé (`_rapporter_le_son_visible`).
	for prop in ["son_visible_actif", "_sons_vues"]:
		if not prop in main:
			absents.append("GameState.%s a disparu (ligne « Son visible » du relevé)" % prop)
	# Lu sur le script, sans l'instancier : une vue créée ici ne serait jamais libérée.
	var proprietes_vue: Array = (load("res://son_visible_vue.gd") as GDScript).get_script_property_list()
	if not proprietes_vue.any(func(d: Dictionary) -> bool: return d["name"] == "recus_compte"):
		absents.append("son_visible_vue.gd n'expose plus recus_compte (ligne « Son visible » du relevé)")
	# `tenir_la_torche()` ne sait allumer que par la gâchette : sans ces actions,
	# il ne ferait rien, et le banc mesurerait torches éteintes.
	for action in ["p1_torch", "p2_torch"]:
		if not InputMap.has_action(action):
			absents.append("action %s absente de l'Input Map (tenir_la_torche)" % action)
	# Le choix de la classe du banc, par son index de catalogue (voir `CLASSE_PAR_DEFAUT`).
	for m in ["set_weapon_selection", "selected_weapon_index"]:
		if not ui.has_method(m):
			absents.append("UI.%s() a disparu (choix de la classe du banc)" % m)
	if not main.has_method("classes"):
		absents.append("GameState.classes() a disparu (choix de la classe du banc)")
	elif index_de_classe(main, CLASSE_PAR_DEFAUT) < 0:
		absents.append("la classe du banc « %s » n'est plus au catalogue" % CLASSE_PAR_DEFAUT)
	return absents


## Réclamer le premier plan, parce que le relevé n'a pas de sens sans lui.
##
## ⚠️ **macOS bride une fenêtre au second plan**, et ce banc le sait déjà : il
## refuse un relevé pris à focus mixte et étiquette un relevé de fond « c'est un
## plancher ». Mais il se contentait de le CONSTATER, or il est lancé depuis un
## terminal — qui garde le premier plan. Le relevé partait donc bridé une fois
## sur deux, et le banc en avertissait dans sa dernière ligne, après une minute
## de mesure perdue.
##
## **Constater une condition qu'on peut établir, c'est se résigner à un relevé
## sur deux.** Un banc qui a besoin du premier plan doit le demander.
##
## Ça reste une demande : le système peut la refuser, et l'étiquette de focus
## garde donc tout son rôle — elle dit ce qui s'est réellement passé, pas ce
## qu'on a réclamé.
func _reclamer_le_premier_plan() -> void:
	DisplayServer.window_move_to_foreground()
	get_window().grab_focus()


## Le son, coupé — et ce n'est pas une politesse, c'est une correction.
##
## ⚠️ **Ce banc jouait un duel au pompe à plein volume, pendant quinze secondes,
## à chaque lancement.** Il est fait pour tourner en boucle — matrices de
## variantes, relevés répétés pour dompter le bruit du 1 % bas — donc il tirait
## des dizaines de fois d'affilée sur la machine de quelqu'un qui travaille à
## côté. Adrien a dû le demander deux fois le 2026-08-25, la seconde en
## majuscules ; c'est une fois de trop pour un défaut qui coûte quatre lignes.
##
## ⚠️ **Deux fois, et pas par superstition** : `AudioManager` pose ses volumes de
## bus à son initialisation, donc une sourdine mise avant qu'il existe serait
## effacée par lui. Le banc l'imprime, pour qu'un silence ne puisse pas être
## confondu avec un banc qui n'a rien lancé.
##
## Le pilote `Dummy` (`godot --audio-driver Dummy`) reste plus radical : il
## empêche le son au niveau du système. Mais il change ce qu'on mesure, et un
## banc de cadence ne doit pas mesurer une configuration que personne ne joue.
func _couper_le_son(quand: String) -> void:
	var maitre := AudioServer.get_bus_index("Master")
	if maitre < 0:
		printerr("  ⚠ bus Master introuvable — le son n'a PAS pu être coupé")
		return
	AudioServer.set_bus_mute(maitre, true)
	AudioServer.set_bus_volume_db(maitre, -80.0)
	print("  son coupé (%s) : muet=%s" % [quand, AudioServer.is_bus_mute(maitre)])


## L'index de catalogue d'une classe, par son slug ; -1 si elle n'y est pas. C'est cet index que `UI.set_weapon_selection`
## attend et qui circule sur le fil — jamais la place d'un bouton dans le râtelier, qui suit le rang d'affichage.
static func index_de_classe(main: Node, slug: String) -> int:
	if main == null or not main.has_method("classes"):
		return -1
	var classes: Array = main.classes()
	for i in classes.size():
		if classes[i] != null and String(classes[i].slug()) == slug:
			return i
	return -1


func _await(predicate: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not predicate.call():
		if waited >= timeout:
			return false
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return true


func _value(args: PackedStringArray, flag: String, fallback: String) -> String:
	var idx := args.find(flag)
	if idx < 0 or idx + 1 >= args.size():
		return fallback
	return args[idx + 1]


## Les compteurs de rendu de l'image qui vient de se dessiner.
func _relever_rendu() -> void:
	_appels.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	_objets.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)))
	_primitives.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))


## Tenir la gâchette de torche d'un joueur, ou la lâcher — le seul chemin que
## `player.gd` respecte.
##
## ⚠️ **Le banc écrivait `p.flashlight_on = true`, et le jeu l'écrasait à chaque
## pas de physique** (constaté le 2026-09-14). `_physics_process` relit
## `flashlight_on = input_provider.is_flashlight_pressed()` AVANT d'allumer ou
## d'éteindre la `Light2D`, et le banc, qui écrit après `process_frame`, arrive
## toujours après le pas qui compte. Résultat : `flashlight_on` se LISAIT vrai
## (le banc venait de l'écrire) pendant que `flashlight.enabled` restait faux —
## 1076 images sur 1076 à la sonde. L'écrasement existe depuis la naissance du
## banc (`9d69f09`, 2026-08-15 : `Input.is_action_pressed` à l'époque) ; ce n'est
## pas le retrait du sprint (`5037a14`) qui l'a introduit.
##
## D'où la gâchette : `Input.action_press` sur l'action du fournisseur, que le pas
## de physique suivant lit exactement comme un doigt. **Au premier cran**, sous
## `TORCH_CRAN_FOND` : allumée tant que tenue, sans basculer le verrou du cran
## plein — l'état de la lampe reste une fonction de la demande, sans mémoire, et
## `--sans-torches` ne peut pas hériter d'un verrou resté enclenché.
##
## Statique et publique pour que `tools/test_banc.gd` prouve en headless que la
## lampe suit la demande après un pas de physique.
static func tenir_la_torche(joueur: Node, allumee: bool) -> void:
	var fournisseur = joueur.get("input_provider")
	if fournisseur == null or not "action_torch" in fournisseur:
		return
	var action: String = fournisseur.action_torch
	if not InputMap.has_action(action):
		return
	if allumee:
		Input.action_press(action, LocalInputProvider.TORCH_CRAN_FOND * 0.5)
	else:
		Input.action_release(action)


## La lampe suit-elle la demande, à CETTE image ? Relevé au vol, comme les
## compteurs de rendu : lu après la boucle, il ne dirait que l'état final.
func _relever_torches() -> void:
	# ⚠️ **Le décompte ne finit pas pour la lampe à l'image où il passe à zéro.**
	# Il se décrémente au traitement d'image ; la lampe ne s'allume qu'au pas de
	# physique SUIVANT, et à cadence déplafonnée plusieurs images passent sans
	# aucun pas. La première version de ce contrôle comptait cette image-là comme
	# un désaccord et refusait un relevé sain (sonde du 2026-09-14 : 1 image sur
	# 837, torches allumées sur toutes les autres). Tant qu'aucun pas n'a suivi
	# le décompte, on est encore dedans.
	if _main.countdown_left > 0.0:
		_pas_du_decompte = Engine.get_physics_frames()
	if _main.countdown_left > 0.0 or Engine.get_physics_frames() == _pas_du_decompte:
		_torches_decompte += 1
		return
	for p in [_main.p1, _main.p2]:
		if p.flashlight.enabled != (not _sans_torches):
			_torches_desaccord += 1
			return


static func _mediane_int(valeurs: Array[int]) -> int:
	var tri := valeurs.duplicate()
	tri.sort()
	return tri[tri.size() / 2]


# ---------------------------------------------------------------------------
# OM6 — LES TROIS INTERRUPTEURS DE LUMIÈRE, et J1 au poste
# ---------------------------------------------------------------------------

## Armés avant l'échauffement (les shaders et les passes d'ombre qui compilent à la chauffe sont ceux de la charge mesurée),
## vérifiés à la fin. Sans drapeau, rien n'est branché ni imprimé.
func _armer_les_interrupteurs(pnj: Array) -> void:
	if not _interrupteurs.actif():
		return
	_interrupteurs.armer(get_tree(), pnj, _main.p1, _main.p2)
	for ligne in _interrupteurs.lignes_au_depart():
		print(ligne)


## La vérification de la fin, faite une fois la dernière image mesurée : un balayage unique, hors de ce qu'on chronomètre.
func _finir_les_interrupteurs() -> void:
	if _interrupteurs.actif():
		_interrupteurs_verifies = _interrupteurs.finir()


## « [sans ombres 2D, sans capteurs] » : ce que le libellé de la charge ajoute (rien sans drapeau).
func _suffixe_des_interrupteurs() -> String:
	var retraits := _interrupteurs.noms_des_retraits()
	return (" [%s]" % ", ".join(retraits)) if not retraits.is_empty() else ""


func _rapporter_les_interrupteurs() -> void:
	if not _interrupteurs.actif():
		return
	for ligne in _interrupteurs.lignes_de_fin(_interrupteurs_verifies):
		print(ligne)


## J1 en solo : le VRAI fournisseur local — sa gâchette de torche passe par les actions de l'Input Map, comme `tenir_la_torche()` la
## presse dans le duel du banc, et le jeu y retrouve ce qu'il lui demande (la manette, le cran de la torche) —, sauf sa VISÉE, tenue.
## Le fournisseur local vise à la souris : sous Xvfb elle ne bouge jamais, sur un poste elle est où l'on l'a laissée, et la visée de J1
## (donc sa torche, donc ce qu'il éclaire et ce que les PNJ voient) dériverait vers elle à chaque pas de physique
## (`Player` : `rotation = lerp_angle(rotation, aim_dir.angle(), …)`).
class PosteDeJ1 extends LocalInputProvider:
	var visee := Vector2.RIGHT

	func get_aim_direction(_position_du_joueur: Vector2) -> Vector2:
		return visee


## OM6 — LES TROIS INTERRUPTEURS DE LUMIÈRE, d'un seul tenant : une classe à part pour que `tools/test_banc.gd` la joue sans fenêtre
## (elle ne dépend que de nœuds qu'une suite sait fabriquer). Quatre règles, chacune payée ailleurs dans ce fichier :
##
## - **Elle ne touche JAMAIS `enabled`** : `perception_bot_noeud.gd` lit celui des halos, des torches et des flashs pour décider ce que
##   les bots voient, et couper `enabled` mesurerait des PNJ aveugles — une autre charge, sans un mot. `eteindre_l_ombre()` est le seul
##   endroit qui écrit, et il n'écrit que `shadow_enabled`.
## - **Les lumières nées pendant la mesure sont prises à leur naissance** (`SceneTree.node_added`), jamais par un balayage de l'arbre à
##   chaque image : un `find_children` par image est un coût CPU de plus dans la mesure qu'il prétend lire. Le seul balayage est celui du
##   départ (ce qui existe déjà) et celui de la fin (la vérification), tous deux hors du chronomètre.
## - **Le jeu réécrit les capteurs à chaque image** : `Presentation3D._suivre` et `_suivre_les_figurants` posent `UPDATE_ALWAYS` à chaque
##   passage, et un arrêt posé une fois serait annulé à l'image suivante, sans rien dire (le piège des trois premiers drapeaux de la
##   fusée, plus haut). Les capteurs sont donc remis à l'arrêt à `RenderingServer.frame_pre_draw` — après tous les `_process`, avant le
##   dessin — : l'entrée honnête, que `Presentation3D` utilise lui-même pour la zone morte de ses capteurs. Aucun code du jeu n'est touché.
## - **Les compteurs vivent dans des champs de cet objet, pas dans des lambdas** : une lambda ne capture un entier que par valeur, et
##   « un compteur incrémenté dans une lambda reste à zéro » (Pièges connus, 2026-10-02) — une garde « jamais » peut être vide.
class Interrupteurs extends RefCounted:
	var sans_ombres_2d := false
	var sans_capteurs := false
	var sans_halos_pnj := false

	## Ce que `armer` a trouvé et touché, une fois.
	var lumieres_vues_au_depart := 0
	var lumieres_eteintes_au_depart := 0
	var capteurs_suivis_au_depart := 0
	var halos_pnj: Array = []
	var halos_pnj_eteints := 0
	## Ce qui s'est passé depuis (remis à zéro par `commencer_la_mesure`) : nœuds vus entrer dans l'arbre, lumières 2D nées — et, parmi
	## elles, celles qui portaient une ombre à leur naissance —, capteurs nés, passages du crochet de dessin et capteurs que le jeu avait
	## rallumés et que le crochet a remis à l'arrêt.
	var noeuds_vus := 0
	var lumieres_nees := 0
	var lumieres_nees_a_ombre := 0
	var nees_par_etiquette: Dictionary = {}
	var capteurs_nes := 0
	## Les capteurs nés depuis l'armement, échauffement compris (celui d'une fusée lancée par un PNJ naît n'importe quand) : ne se remet pas à zéro.
	var capteurs_nes_depuis_l_armement := 0
	var appels_du_crochet := 0
	var capteurs_repris := 0
	## Les capteurs de corps suivis (`CapteurCorps`) : ceux du départ et ceux qui naissent.
	var capteurs: Array = []
	var _arbre: SceneTree = null
	## Où l'on balaie au départ et à la fin : la racine de l'arbre (le jeu), ou un sous-arbre (une suite, qui ne touche pas au reste).
	var _racine: Node = null
	var _joueurs: Array = []
	var _pnj: Array = []
	var _branche := false
	static var _chiffres: RegEx = null


	func actif() -> bool:
		return sans_ombres_2d or sans_capteurs or sans_halos_pnj


	## Les drapeaux posés, dans l'ordre : ce que le libellé de la charge ajoute entre crochets.
	func noms_des_retraits() -> PackedStringArray:
		var noms: PackedStringArray = []
		if sans_ombres_2d:
			noms.append("sans ombres 2D")
		if sans_capteurs:
			noms.append("sans capteurs")
		if sans_halos_pnj:
			noms.append("sans halos de PNJ")
		return noms


	## L'ombre d'une lumière 2D éteinte — la SEULE écriture de cette classe sur une lumière, et jamais `enabled`. Vrai si elle en avait une.
	static func eteindre_l_ombre(lumiere: Light2D) -> bool:
		if not lumiere.shadow_enabled:
			return false
		lumiere.shadow_enabled = false
		return true


	## « PNJ_3/Flashlight » → « PNJ_#/Flashlight » : le parent et le nom, les numéros effacés (sept PNJ, une ligne), un nœud sans nom
	## (`@PointLight2D@1273` : le halo, l'écho au sol et la lumière de coup n'en ont pas) devenu « · ».
	static func etiquette_de(noeud: Node) -> String:
		if _chiffres == null:
			_chiffres = RegEx.create_from_string("[0-9]+")
		var nom := String(noeud.name)
		var parent := noeud.get_parent()
		var nom_parent := String(parent.name) if parent != null else "·"
		if nom.begins_with("@"):
			nom = "·"
		if nom_parent.begins_with("@"):
			nom_parent = "·"
		return _chiffres.sub(nom_parent + "/" + nom, "#", true)


	## « A ×12 (3 à ombre), B ×4 (0 à ombre) » : un recensement `étiquette → [n, k]`, du plus nombreux au moins nombreux, douze lignes au plus.
	static func decrire(par: Dictionary, mot: String = "à ombre") -> String:
		if par.is_empty():
			return "aucune"
		var lignes: Array = []
		for etiquette in par:
			lignes.append([int((par[etiquette] as Array)[0]), "%s ×%d (%d %s)" % [etiquette, int((par[etiquette] as Array)[0]),
				int((par[etiquette] as Array)[1]), mot]])
		lignes.sort_custom(func(x, y) -> bool: return int(x[0]) > int(y[0]))
		var morceaux: PackedStringArray = []
		for k in mini(lignes.size(), 12):
			morceaux.append(String(lignes[k][1]))
		return ", ".join(morceaux) + (" …" if lignes.size() > 12 else "")


	## Toutes les `Light2D` de l'arbre : combien, combien à ombre, par étiquette. Un seul balayage, au départ — hors du chronomètre.
	static func recenser_les_lumieres(arbre: SceneTree) -> Dictionary:
		var total := 0
		var a_ombre := 0
		var par_etiquette := {}
		for n in arbre.root.find_children("*", "Light2D", true, false):
			var lumiere := n as Light2D
			var etiquette := etiquette_de(lumiere)
			var e: Array = par_etiquette.get(etiquette, [0, 0])
			e[0] += 1
			total += 1
			if lumiere.shadow_enabled:
				e[1] += 1
				a_ombre += 1
			par_etiquette[etiquette] = e
		return {"total": total, "a_ombre": a_ombre, "par_etiquette": par_etiquette}


	## À qui est ce capteur : J1, J2, un figurant (un PNJ), un leurre — ou un objet posé, qui n'a pas de propriétaire.
	static func genre_de_capteur(capteur: CapteurCorps, p1: Node, p2: Node, pnj: Array) -> String:
		var corps: Variant = capteur.proprietaire
		if corps == null or not is_instance_valid(corps):
			return "objet posé"
		if corps == p1:
			return "J1"
		if corps == p2:
			return "J2"
		if pnj.has(corps):
			return "figurant"
		return "leurre"


	## Tous les capteurs de corps de l'arbre : combien, combien rendent à cet instant, par genre.
	static func recenser_les_capteurs(arbre: SceneTree, p1: Node, p2: Node, pnj: Array) -> Dictionary:
		var total := 0
		var rendus := 0
		var par_genre := {}
		for n in arbre.root.find_children("*", "SubViewport", true, false):
			var capteur := n as CapteurCorps
			if capteur == null:
				continue
			var genre := genre_de_capteur(capteur, p1, p2, pnj)
			var e: Array = par_genre.get(genre, [0, 0])
			e[0] += 1
			total += 1
			if capteur.render_target_update_mode != SubViewport.UPDATE_DISABLED:
				e[1] += 1
				rendus += 1
			par_genre[genre] = e
		return {"total": total, "rendus": rendus, "par_genre": par_genre}


	## Branche les crochets et traite ce qui existe déjà. `pnj` : les PNJ de la salle (leurs halos, pour `--sans-halos-pnj`) ; `p1`, `p2` :
	## pour dire à qui est chaque capteur ; `racine` : le sous-arbre à balayer (toute la scène par défaut). Les crochets, eux, écoutent
	## l'arbre entier — c'est ce qui prend une lumière née n'importe où.
	func armer(arbre: SceneTree, pnj: Array = [], p1: Node = null, p2: Node = null, racine: Node = null) -> void:
		_arbre = arbre
		_racine = racine if racine != null else arbre.root
		_joueurs = [p1, p2]
		_pnj = pnj
		if sans_ombres_2d:
			for n in _racine.find_children("*", "Light2D", true, false):
				lumieres_vues_au_depart += 1
				if eteindre_l_ombre(n as Light2D):
					lumieres_eteintes_au_depart += 1
		if sans_capteurs:
			for n in _racine.find_children("*", "SubViewport", true, false):
				if n is CapteurCorps:
					_suivre_un_capteur(n as CapteurCorps)
					capteurs_suivis_au_depart += 1
		if sans_halos_pnj:
			for p in pnj:
				if is_instance_valid(p) and bool(p.get("est_pnj")):
					var halo: Variant = p.get("ambient_light")
					if halo is Light2D:
						halos_pnj.append(halo)
						if eteindre_l_ombre(halo as Light2D):
							halos_pnj_eteints += 1
		if sans_ombres_2d or sans_capteurs:
			arbre.node_added.connect(_sur_un_noeud)
		if sans_capteurs:
			RenderingServer.frame_pre_draw.connect(avant_le_rendu)
		_branche = true


	func desarmer() -> void:
		if not _branche or _arbre == null:
			return
		if _arbre.node_added.is_connected(_sur_un_noeud):
			_arbre.node_added.disconnect(_sur_un_noeud)
		if RenderingServer.frame_pre_draw.is_connected(avant_le_rendu):
			RenderingServer.frame_pre_draw.disconnect(avant_le_rendu)
		_branche = false


	## Chaque nœud qui entre dans l'arbre, de n'importe où (un sous-viewport compris). Une lumière 2D est éteinte à sa naissance : les
	## sites du jeu posent tous `shadow_enabled` AVANT `add_child` (`hit_light`, la fusée, le plafonnier, les gadgets), donc la
	## valeur qu'on lit ici est la dernière — et la vérification de la fin le contrôle sur ce qui survit.
	func _sur_un_noeud(noeud: Node) -> void:
		noeuds_vus += 1
		if noeud is Light2D:
			if sans_ombres_2d:
				_lumiere_nee(noeud as Light2D)
		elif noeud is CapteurCorps:
			if sans_capteurs:
				_suivre_un_capteur(noeud as CapteurCorps)
				capteurs_nes += 1
				capteurs_nes_depuis_l_armement += 1


	func _lumiere_nee(lumiere: Light2D) -> void:
		lumieres_nees += 1
		var avait_une_ombre := eteindre_l_ombre(lumiere)
		var etiquette := etiquette_de(lumiere)
		var e: Array = nees_par_etiquette.get(etiquette, [0, 0])
		e[0] += 1
		if avait_une_ombre:
			e[1] += 1
			lumieres_nees_a_ombre += 1
		nees_par_etiquette[etiquette] = e


	func _suivre_un_capteur(capteur: CapteurCorps) -> void:
		if not capteurs.has(capteur):
			capteurs.append(capteur)
		capteur.render_target_update_mode = SubViewport.UPDATE_DISABLED


	## À `RenderingServer.frame_pre_draw` : chaque capteur que le jeu a rallumé pendant l'image est remis à l'arrêt, un capteur libéré est
	## oublié. Vingt capteurs au plus : quelques microsecondes, et seulement avec `--sans-capteurs`.
	func avant_le_rendu() -> void:
		appels_du_crochet += 1
		var i := capteurs.size() - 1
		while i >= 0:
			var capteur: Variant = capteurs[i]
			if not is_instance_valid(capteur):
				capteurs.remove_at(i)
			elif (capteur as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
				(capteur as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
				capteurs_repris += 1
			i -= 1


	## La mesure commence : ce qui s'est passé pendant l'échauffement n'est pas ce qui se rapporte.
	func commencer_la_mesure() -> void:
		noeuds_vus = 0
		lumieres_nees = 0
		lumieres_nees_a_ombre = 0
		nees_par_etiquette = {}
		capteurs_nes = 0
		appels_du_crochet = 0
		capteurs_repris = 0


	## La vérification de la FIN, une fois la dernière image mesurée, puis les crochets débranchés : ce qui devait être éteint l'est-il resté ?
	## Un seul balayage, hors du chronomètre. Rend les noms des lumières encore à ombre, les halos de PNJ à ombre, les capteurs encore actifs.
	func finir() -> Dictionary:
		var bilan := {"lumieres_vues": 0, "lumieres_a_ombre": [], "halos_a_ombre": 0, "capteurs_vivants": 0, "capteurs_actifs": 0}
		if _racine != null and sans_ombres_2d:
			for n in _racine.find_children("*", "Light2D", true, false):
				bilan["lumieres_vues"] = int(bilan["lumieres_vues"]) + 1
				if (n as Light2D).shadow_enabled:
					(bilan["lumieres_a_ombre"] as Array).append(etiquette_de(n))
		if sans_halos_pnj:
			for h in halos_pnj:
				if is_instance_valid(h) and (h as Light2D).shadow_enabled:
					bilan["halos_a_ombre"] = int(bilan["halos_a_ombre"]) + 1
		if sans_capteurs:
			for c in capteurs:
				if is_instance_valid(c):
					bilan["capteurs_vivants"] = int(bilan["capteurs_vivants"]) + 1
					if (c as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
						bilan["capteurs_actifs"] = int(bilan["capteurs_actifs"]) + 1
		desarmer()
		return bilan


	## Ce que `armer` a fait, une ligne par drapeau.
	func lignes_au_depart() -> PackedStringArray:
		var lignes: PackedStringArray = []
		if sans_ombres_2d:
			lignes.append("Interrupteur  : --sans-ombres-2d : %d lumières 2D vues, %d mises sans ombre (%d l'étaient déjà) ; celles qui naissent ensuite sont prises à leur entrée dans l'arbre (SceneTree.node_added), pas par un balayage à chaque image"
				% [lumieres_vues_au_depart, lumieres_eteintes_au_depart, lumieres_vues_au_depart - lumieres_eteintes_au_depart])
		if sans_capteurs:
			lignes.append("Interrupteur  : --sans-capteurs : %d capteurs de corps mis à l'arrêt (UPDATE_DISABLED) ; le jeu les rallume à chaque image, ils sont donc remis à l'arrêt à chaque image, juste avant le dessin (frame_pre_draw)"
				% capteurs_suivis_au_depart)
		if sans_halos_pnj:
			lignes.append("Interrupteur  : --sans-halos-pnj : %d halo(s) de proximité de PNJ sans ombre (%d éteint(s) par ce drapeau, les autres l'étaient déjà)"
				% [halos_pnj.size(), halos_pnj_eteints])
		return lignes


	## Ce que chaque drapeau a touché PENDANT la mesure et ce que la vérification de la fin a trouvé. Un « ✗ » est un défaut (`defauts`).
	func lignes_de_fin(bilan: Dictionary) -> PackedStringArray:
		var lignes: PackedStringArray = []
		if sans_ombres_2d:
			var restantes: Array = bilan.get("lumieres_a_ombre", [])
			lignes.append("  Interrupteurs    : --sans-ombres-2d : %d lumière(s) 2D née(s) pendant la mesure, dont %d avec une ombre (éteintes à leur naissance) — %s ; %d nœuds vus entrer dans l'arbre · en fin de mesure : %s"
				% [lumieres_nees, lumieres_nees_a_ombre, decrire(nees_par_etiquette, "à ombre à la naissance"), noeuds_vus,
				("✗ %d lumière(s) 2D ont gardé ou repris une ombre : %s" % [restantes.size(), ", ".join(PackedStringArray(restantes))])
				if not restantes.is_empty() else "0 lumière 2D à ombre sur %d vues ✓" % int(bilan.get("lumieres_vues", 0))])
		if sans_capteurs:
			lignes.append("  Interrupteurs    : --sans-capteurs : %d capteur(s) suivi(s) en tout (%d au départ, %d nés ensuite dont %d pendant la mesure) ; le jeu en a rallumé %d fois en %d images de dessin (chaque fois remis à l'arrêt) · en fin de mesure : %s"
				% [capteurs_suivis_au_depart + capteurs_nes_depuis_l_armement, capteurs_suivis_au_depart, capteurs_nes_depuis_l_armement,
				capteurs_nes, capteurs_repris, appels_du_crochet,
				("✗ %d capteur(s) actifs sur %d" % [int(bilan.get("capteurs_actifs", 0)), int(bilan.get("capteurs_vivants", 0))])
				if int(bilan.get("capteurs_actifs", 0)) > 0 else "0 actif sur %d ✓" % int(bilan.get("capteurs_vivants", 0))])
		if sans_halos_pnj:
			lignes.append("  Interrupteurs    : --sans-halos-pnj : %d halo(s) de PNJ · en fin de mesure : %s" % [halos_pnj.size(),
				("✗ %d encore à ombre" % int(bilan.get("halos_a_ombre", 0))) if int(bilan.get("halos_a_ombre", 0)) > 0
				else "0 à ombre ✓"])
		return lignes


	## Les défauts de la vérification de la fin : ce qu'un interrupteur dit avoir fait et n'a pas tenu. Vide si tout tient.
	func defauts(bilan: Dictionary) -> Array[String]:
		var d: Array[String] = []
		if bilan.is_empty():
			return d
		var restantes: Array = bilan.get("lumieres_a_ombre", [])
		if sans_ombres_2d and not restantes.is_empty():
			d.append("--sans-ombres-2d : %d lumière(s) 2D avaient encore une ombre en fin de mesure" % restantes.size())
		if sans_halos_pnj and int(bilan.get("halos_a_ombre", 0)) > 0:
			d.append("--sans-halos-pnj : %d halo(s) de PNJ avaient encore une ombre en fin de mesure" % int(bilan["halos_a_ombre"]))
		if sans_capteurs and int(bilan.get("capteurs_actifs", 0)) > 0:
			d.append("--sans-capteurs : %d capteur(s) rendaient encore en fin de mesure" % int(bilan["capteurs_actifs"]))
		return d
