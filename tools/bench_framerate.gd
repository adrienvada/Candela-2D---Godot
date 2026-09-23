## Banc de cadence d'image en conditions de pire cas, FENÊTRÉ.
##
## La passe de performance de l'étape 9 avait été mesurée côté CPU seulement
## (`bench_particles.gd`, headless). Déplafonner la cadence d'image déplace la
## question sur le GPU : le jeu tient-il réellement sa cadence cible quand les
## deux vues rendent, torches allumées, pendant un échange au pompe ?
## (La cible est `CIBLE_1_POURCENT_BAS`, plus bas — elle a valu 120, elle vaut
## 60 depuis le 2026-08-25, et l'écrire en toutes lettres ici l'a déjà périmée
## une fois.)
##
## Headless ne répond pas — rien n'est rasterisé. Ce banc ouvre donc une vraie
## fenêtre. Il n'est jamais lancé par le jeu.
##
## Lancer : godot --path . res://tools/bench_framerate.tscn -- [--seconds 15] [--max-fps 0]
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
const WARMUP_SEC := 12.0
## Les premières secondes de la MESURE, rapportées à part (voir `WARMUP_SEC`).
const TRANSITOIRE_SEC := 5.0
const SHOTGUN_INDEX := 2
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
	_fusee_sans_lumiere2d = args.has("--fusee-sans-lumiere2d")
	_fusee_sans_ombre2d = args.has("--fusee-sans-ombre2d")
	_fusee_sans_fumee2d = args.has("--fusee-sans-fumee2d")
	_fusee_sans_volume = args.has("--fusee-sans-volume")
	_fusee_sans_lueurs = args.has("--fusee-sans-lueurs")
	_fusee_couches = int(_value(args, "--fusee-couches", "-1"))
	_lumiere3d_echelle = float(_value(args, "--echelle", "1"))
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
	print("Plafond: %s | vsync: désactivé" % ("aucun" if Engine.max_fps == 0 else str(Engine.max_fps)))

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
		else preconditions_manquantes(_ui, _main)
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

	# Écran partagé : les DEUX vues rendent, chacune avec son jeu de lumières et
	# d'ombres portées. C'est le pire cas de la passe de performance.
	#
	# Le mode ne se choisit plus par un bouton mais par la navigation, qui écrit
	# `_intended_mode`. Le banc n'a pas d'écran à parcourir : il pose l'intention
	# directement, comme le ferait l'entrée « 1V1 écrans scindés ».
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_select_shotgun(_ui.p1_weapon_group)
	_select_shotgun(_ui.p2_weapon_group)
	_main._on_replay_requested()

	if not await _await(func(): return _main.round_active, 15.0):
		printerr("✗ la manche n'a pas démarré")
		_sortir(1)
		return

	print("Manche lancée — armes : %s / %s" % [
		_main.p1.current_weapon.name, _main.p2.current_weapon.name])
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
	_poser_les_drapeaux_des_volumes()
	_conditions()
	print("Échauffement %.0f s (chargement des shaders, remplissage du pool)…" % WARMUP_SEC)
	_pire_echauffement = 0.0
	await _stress(WARMUP_SEC, false)
	print("  pire image de l'échauffement : %.1f ms" % (_pire_echauffement * 1000.0))

	print("Mesure sur %.0f s…" % _seconds)
	if _temps_par_vue:
		_armer_temps_par_vue()
	_recenser_les_ombres_2d()
	_debut_mesure_us = Time.get_ticks_usec()
	await _stress(_seconds, true)
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
			_fusee_banc.appliquer_age(age_mis)
			_poser_les_drapeaux_de_la_fusee(_fusee_banc)
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
	# ISO12 — le même 1 % bas, HORS des `TRANSITOIRE_SEC` premières secondes de la mesure (voir `WARMUP_SEC`).
	var regime: Array = []
	for i in _samples.size():
		if i < _samples_t.size() and _samples_t[i] >= TRANSITOIRE_SEC:
			regime.append(_samples[i])
	regime.sort()
	var low1_regime := low1
	var lents_regime := 0
	if not regime.is_empty():
		lents_regime = maxi(1, int(round(regime.size() * 0.01)))
		var somme_regime := 0.0
		for i in range(regime.size() - lents_regime, regime.size()):
			somme_regime += regime[i]
		low1_regime = float(lents_regime) / somme_regime

	print("\n=== RÉSULTAT (%s) ===" % _libelle_charge())
	print("  Images mesurées  : %d en %.1f s" % [sorted.size(), total])
	print("  FPS moyen        : %.0f" % avg)
	print("  FPS médian       : %.0f" % (1.0 / sorted[sorted.size() / 2]))
	print("  FPS 1 %% bas      : %.0f  (moyenne des %d images les plus lentes, TOUTES images)"
		% [low1, lents])
	print("  FPS 1 %% bas hors transitoire : %.0f  (moyenne des %d plus lentes, hors des %.0f premières secondes) — lu par le verdict"
		% [low1_regime, lents_regime, TRANSITOIRE_SEC])
	# Les images du 1 % le plus lent (toutes images), par tranche de 10 s : où tombe la queue.
	var seuil_lent: float = sorted[sorted.size() - lents]
	var tranches: PackedInt32Array = []
	tranches.resize(int(ceil(total / 10.0)) + 1)
	for i in _samples.size():
		if _samples[i] >= seuil_lent and i < _samples_t.size():
			tranches[mini(int(_samples_t[i] / 10.0), tranches.size() - 1)] += 1
	var par_tranche: PackedStringArray = []
	for k in tranches.size():
		if k * 10.0 < total:
			par_tranche.append("%d-%d s : %d" % [k * 10, k * 10 + 10, tranches[k]])
	print("  Images lentes (1 %% le plus lent) par tranche : %s" % ", ".join(par_tranche))
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
	print("  Verdict %.0f fps   : %s  (sur le 1 %% bas hors transitoire)" % [CIBLE_1_POURCENT_BAS,
		"TENU" if low1_regime >= CIBLE_1_POURCENT_BAS else "NON TENU (1 %% bas hors transitoire à %.0f)" % low1_regime])
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
	# `tenir_la_torche()` ne sait allumer que par la gâchette : sans ces actions,
	# il ne ferait rien, et le banc mesurerait torches éteintes.
	for action in ["p1_torch", "p2_torch"]:
		if not InputMap.has_action(action):
			absents.append("action %s absente de l'Input Map (tenir_la_torche)" % action)
	for groupe in ["p1_weapon_group", "p2_weapon_group"]:
		if groupe in ui:
			var g: ButtonGroup = ui.get(groupe)
			if g == null or g.get_buttons().size() <= SHOTGUN_INDEX:
				absents.append("UI.%s n'a plus d'arme à l'indice %d (pompe)"
					% [groupe, SHOTGUN_INDEX])
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


func _select_shotgun(group: ButtonGroup) -> void:
	var buttons: Array = group.get_buttons()
	if SHOTGUN_INDEX < buttons.size():
		buttons[SHOTGUN_INDEX].button_pressed = true


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
