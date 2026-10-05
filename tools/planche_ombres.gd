extends "res://tools/photographe.gd"
## OM0 — LE BANC DES OMBRES : la planche avant/après du chantier OMBRES (2026-10-04).
##
## Le vrai `main.tscn`, en vue iso, dans une vraie salle de l'aventure (chapitre 0 : 0.1 « Le premier pas », un PNJ sous un
## plafonnier ; 0.9, six PNJ). J1 braque sa torche sur un PNJ ; le banc photographie ce que le joueur voit, relit la lightmap
## qui l'a produit et MESURE ce que le chantier corrige. Il ne juge rien à la place d'Adrien : il rend la preuve reproductible,
## et c'est elle qui juge chaque lot (avant, dans l'arbre de la base ; après, dans celui de la branche).
##
## Il descend de l'outil de capture de l'audit du 2026-10-04 (`outils/zz_claude_solo.gd`, publié avec le rapport
## https://claude.ai/artifact/4K1qRwJv6YFVae7Vp5TLWr , jamais versionné), réécrit aux conventions des planches du dépôt
## (`planche_q42.gd`) : un catalogue de plans, un journal, une planche HTML, des sorties hors du dépôt.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . --resolution 1920x1080 \
##     res://tools/planche_ombres.tscn -- --sortie=<dossier absolu> --no-eos --led-murs-fige=0.5 [options]
##
## ## Les options du banc
## - `--liste` : le catalogue, sans ouvrir de salle (la fenêtre s'ouvre et se referme aussitôt).
## - `--famille=etoile,classes` / `--plan=etoile-camera-face,mur` : une partie du catalogue (tout, par défaut).
## - `--sortie=<dossier>` (`user://ombres` par défaut) ; `--taille=1920x1080` (la taille de la fenêtre et des prises).
## - `--avant=<dossier>` : la sortie d'un passage précédent du MÊME catalogue (l'arbre de la base) ; la planche montre alors,
##   plan par plan, l'image et les chiffres d'avant à côté de ceux d'après. Les images d'avant sont recopiées dans
##   `<sortie>/avant/` : le dossier se partage seul.
## - `--correctif=etoile_ccw|etoile_cw|disque|disque_ccw` : PROTOTYPE de l'audit, posé à l'exécution sur l'étoile de chaque
##   corps (J1, les PNJ), sans toucher au code du jeu — `etoile_ccw` est le correctif d'OM1 tel que l'audit l'a essayé.
##   `disque` (13 px) ne sert qu'à MESURER une largeur : Q42 a écarté « une ombre ronde pour tous ».
## - `--lightmaps` : écrit aussi la lightmap entière de chaque prise (lourd).
## - Les drapeaux du JEU passent tels quels, et le journal les recopie : `--pate brute` (sans postérisation ; ⚠️ séparé par
##   une espace, c'est la forme que lit `Presentation3D`), `--sans-faisceau-air` (build de débogage), `--led-murs-fige=0.5`.
##   Les plans « brute » du catalogue posent la pâte brute À L'EXÉCUTION (`style_pate`), pour comparer dans le même passage.
##
## ## Ce qu'il écrit, par prise
## - `<id>_ecran.png` : la fenêtre entière, l'écran « nu » (voile d'éblouissement, HUD et particules cachés : ce qu'on
##   compare est la lumière du monde, pas le voile qui respire — piège du 2026-09-30) ;
## - `<id>_pnj_iso.png` et `<id>_pnj_iso_reperes.png` : le PNJ découpé et agrandi ×3 dans l'image iso ; la seconde porte
##   le contour de son étoile au sol (rouge), le disque de son capteur (vert) et son centre (bleu) ;
## - `<id>_pnj_lightmap.png` : la lightmap (`vp1`, la vue de dessus que l'iso relit) autour du PNJ, avec les mêmes repères ;
## - `<id>_capteur.png` : le capteur du PNJ (ce que son corps voxel lit) ;
## - pour une série (scintillement) : `<id>_diff_max.png`, l'écart maximal entre images consécutives, ×4 ; et
##   `<id>_allers_retours.png` (OM3), les pixels qui ont papilloté — monté puis redescendu, ou l'inverse — au moins une fois ;
## - `journal.json` : pour chaque prise, les poses, la lampe, l'étoile au sol, et les MESURES :
##   · `sonde` — **« le sol dans l'étoile, côté lampe, est éclairé »** : la lightmap lue sur les rayons de l'étoile tournés
##     vers la lampe (± 60°), aux trois quarts du rayon (DANS l'étoile) puis à 6 px au-delà de son bord (dehors) ; `rapport`
##     = dedans / dehors. Aujourd'hui (`CULL_DISABLED`) l'intérieur est noir : rapport ≈ 0. L'ombre doit pourtant rester
##     derrière le corps : `derriere` est le même rapport, lu derrière l'étoile (côté opposé à la lampe), contre le sol
##     éclairé à la même distance de la lampe, de côté ;
##   · `capteur` — la moyenne et le maximum de l'anneau que le corps voxel lit dans son capteur (`planche_q42._niveau`) :
##     OM1 ne doit pas le faire bouger (Q42) ;
##   · `opacites` — l'opacité de CHAQUE PNJ telle que le corps iso la prend (`Presentation3D.opacite_du_corps`), et
##     l'éblouissement de J1 avec sa source (O2) ;
##   · `scintillement` (séries) — par paire d'images consécutives : pixels de l'écran dont la luma (Rec. 601, celle de la
##     mesure de l'audit) change de plus de 8 et de plus de 24 niveaux, et le saut maximal ; idem sur la lightmap ; et par
##     triplet (OM3), les ALLERS-RETOURS au-delà de 8 niveaux — le papillotement, qu'un balayage en douceur ne fait pas ;
##   · `lumieres` — le recensement des lumières au sol par quadrant de 560 px (plafond moteur de 15 par item, O12) ;
##   · `regles` (OM4, la famille du même nom) — l'étoile du PNJ (rendue ? à quelle échelle, contre celle de sa silhouette) ;
##     `largeur_ombre_px` dans la sonde (l'ombre derrière le corps, mesurée en travers) ; pour le tir au mur, la place du
##     flash, le sol à son pied, le sol autour du tireur (témoin) et le plus clair du sol AU-DELÀ du mur ;
## - `planche.html` : ce qu'on ouvre.
##
## ## Le même instant
## Les précautions de `planche_q42` et du piège « Une scène “tenue” par le photographe bouge encore » (2026-09-30) : les PNJ
## ne pensent plus (leur bot arrêté, une marionnette à sa place), J1 et chaque PNJ sont reposés à CHAQUE image (position,
## visée, vitesse nulle, vie pleine), les corps voxel reposés juste avant le rendu à leur pose exacte, sans respiration
## (`frame_pre_draw`) ; la respiration des torches n'existe plus (OM3b : retirée du jeu, et le bruit qui la portait avec) ;
## la poussière du faisceau est coupée ; les caméras sans lissage ; le bandeau LED tenu par `--led-murs-fige=0.5`. Le carton
## de la salle est passé d'un coup : le banc ne le photographie pas.
##
## ## Ce qu'il ne fait pas
## Il ne rend rien en headless (`RenduCommun.refus_headless`) : il se lance sous Xvfb ou dans une vraie fenêtre, hors du
## lanceur. Ses appuis sur le jeu sont vérifiés sans fenêtre par `tools/test_banc.gd` (`preconditions_manquantes`). Ce que
## llvmpipe (Mesa) rend n'est pas ce que rend le pilote d'Apple : le jugement final est celui d'Adrien, en jouant.

const FormatT := preload("res://aventure_format.gd")
const ProgressionT := preload("res://aventure_progression.gd")
const IsoPate := preload("res://iso_pate.gd")

const DOSSIER_PAR_DEFAUT := "user://ombres"
## Les dix classes, dans l'ordre de `planche_q42` (celui de `weapon_for_index`, relu par slug à l'équipement).
const SLUGS := ["pistolet", "fusil", "pompe", "arbalete", "occulteur", "fumiste", "incendiaire", "sentinelle",
	"allumeur", "spectre"]
## La découpe autour du PNJ (px d'écran ou de lightmap), agrandie `LOUPE` fois.
const DECOUPE_PX := 200
const LOUPE := 3
## Les images tenues avant une prise : la lampe s'allume au pas de physique, la caméra est remise sans lissage à chaque
## image, et le corps voxel est reposé avant chaque rendu — douze suffisent à ce que deux passages donnent la même image.
const IMAGES_POSE := 12
## Une série de scintillement : six images CONSÉCUTIVES, comme la mesure de l'audit.
const IMAGES_SERIE := 6
## OM3 — le recul qui file : quatorze images, de l'image d'avant le coup au début du retour au souffle (le recul d'une arme dure
## de 0,1 à 0,2 s, six à douze pas à 60 Hz).
const IMAGES_RECUL := 14
const SEUILS_SCINTILLEMENT := [8, 24]
## Un quadrant de `TileMapLayer` : 16 tuiles de 35 px (« quinze par item », Pièges connus).
const QUADRANT_PX := 560.0
const PLAFOND_LUMIERES := 15
## La sonde : les rayons de l'étoile tournés vers la lampe à ± 60°, lus aux trois quarts du rayon et à 6 px au-delà.
const SONDE_DEMI_ANGLE := 60.0
const SONDE_DEDANS := 0.75
const SONDE_DEHORS_PX := 6.0
## Les familles dont chaque prise lit la sonde (torche seule) : celles où J1 éclaire le PNJ regardé.
const FAMILLES_SONDEES := ["etoile", "classes", "mur", "plafonnier", "scintillement", "regles"]
## Le PNJ près d'un mur (plan `mur`) : à 30 px de la face, J1 de l'autre côté.
const MUR_ECART_PX := 30.0
## OM4, le tir au mur : le centre de J1 à 20 px de la face (le rayon de son corps est 18) — collé, comme
## `test_ombres_regles._le_flash_au_mur`.
const COLLE_AU_MUR_PX := 20.0
## La largeur de l'ombre derrière le corps : la lightmap lue en travers, à ± 60 px de l'axe lampe → corps, pixel par pixel ;
## « dans l'ombre » sous la moitié du sol éclairé des deux bouts.
const OMBRE_TRAVERS_PX := 60

var _iso: Presentation3D
var _journal: Array = []
var _plans_faits := 0
var _refuses: Array[String] = []
var _avant := ""
var _correctif := ""
var _lightmaps := false
var _prog: AventureProgression
## La salle posée : [chapitre, index] ; vide avant la première.
var _salle_posee: Array = []
var _pantin_j1: Marionnette
## Les poses à tenir : J1, et chaque PNJ (par son nœud) — [position, visée]. `_poses_origine` : celles de la salle telle
## qu'elle s'est posée ; chaque plan en repart (un plan précédent a pu déplacer un PNJ contre un mur).
var _pose_j1 := [Vector2.ZERO, Vector2.RIGHT]
var _poses_pnj := {}
var _poses_origine := {}
## La classe de chaque PNJ à la pose de la salle : rendue après un plan « classes ».
var _classes_d_origine := {}
## Le plan en cours (le tir, les lampes).
var _plan_en_cours: Dictionary = {}
## Vrai le temps d'une sonde : le bandeau LED des murs (`MurLed`) éteint à CHAQUE image — le jeu le rallume (piège du
## 2026-09-14, « Un capteur de lumière ne s'éteignait pas sous le `CanvasModulate` noir »).
var _sans_led := false
## L'énergie de la torche de J1 à chaque image d'une série : la respiration et le recul de tir se lisent là, pas à l'œil.
var _energies: Array = []
## OM4, le tir au mur : le mur d'une case choisi (`_mur_mince_vu`) — la face, la visée, le sol au-delà.
var _mur_du_plan: Dictionary = {}


## La marionnette du photographe, qui sait aussi s'accroupir (OM4 : l'étoile à la posture). La simulation repose la posture à
## chaque pas depuis `is_crouch_pressed()` : un `poser_posture(true)` direct serait défait au pas suivant.
class MarionnetteAccroupie extends Marionnette:
	var accroupi := false

	func is_crouch_pressed() -> bool:
		return accroupi


## LE CATALOGUE. Chaque plan : `id`, `famille`, `but` (ce qu'il montre, pour la planche), `salle` [chapitre, index],
## `cible` (le PNJ regardé), `cote` (d'où vient la torche, en degrés autour du PNJ, à partir du côté de la CAMÉRA :
## 0 = côté caméra, 180 = de dos, 90 = de profil), `distance` (J1 → PNJ, px), `theta` (la visée du PNJ : 0 = face à la
## lampe, l'arme vers elle ; 90 = de profil), et selon le plan : `classe` (la classe du PNJ), `mur`, `serie`,
## `respiration`, `tir`, `recul` (OM3 : le recul armé une fois, puis laissé filer), `pate` ("brute"), `plafonniers` (faux : éteints), `lampes` ("F", "H", "B" ; "-" : aucune), `ebloui_par`
## (un PNJ dont la torche vise J1) ; OM4 : `accroupi` (le PNJ regardé), `tir_au_mur` (J1 collé à un mur d'une case, qui
## tire), `torche` (faux : celle de J1 éteinte), `leds` (faux : le bandeau des murs éteint).
static func plans() -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	var base := {"salle": [0, 0], "cible": 0, "cote": 0.0, "distance": 160.0, "theta": 0.0}
	# O1 — d'où part l'ombre : la torche côté caméra (l'encoche est devant les pieds), de dos, de profil ; le PNJ face à la
	# lampe (son arme vers elle : le pire cas) ou de profil.
	for cote in [["camera", 0.0], ["dos", 180.0], ["profil", 90.0]]:
		for theta in [["face", 0.0], ["profil", 90.0]]:
			sortie.append(_plan_de(base, {"id": "etoile-%s-%s" % [cote[0], theta[0]], "famille": "etoile",
				"cote": cote[1], "theta": theta[1],
				"but": "O1 — torche %s, PNJ %s : l'ombre doit partir de derrière le corps, le sol devant les pieds rester éclairé" % [
					{"camera": "côté caméra", "dos": "de dos", "profil": "de profil"}[cote[0]],
					{"face": "face à la lampe (arme vers elle)", "profil": "de profil"}[theta[0]]]}))
	sortie.append(_plan_de(base, {"id": "etoile-courte", "famille": "etoile", "distance": 70.0,
		"but": "O1 — courte portée (70 px), torche côté caméra : la lampe tout près, l'étoile la plus large à l'écran"}))
	# O1 — les dix silhouettes : chacune a son étoile (l'arme décide de sa pointe), côté caméra, arme vers la lampe.
	for slug in SLUGS:
		sortie.append(_plan_de(base, {"id": "classe-%s" % slug, "famille": "classes", "classe": slug,
			"but": "O1 — l'étoile de la classe %s, torche côté caméra, arme vers la lampe" % slug}))
	# O3 — la torche traverse la flaque du plafonnier : des coins sombres sans occulteur en pâte D, lisses en brute.
	sortie.append(_plan_de(base, {"id": "plafonnier", "famille": "plafonnier",
		"but": "O3 — la torche dans la flaque du plafonnier, pâte D : les paliers dessinent-ils des ombres sans objet ?"}))
	sortie.append(_plan_de(base, {"id": "plafonnier-brute", "famille": "plafonnier", "pate": "brute",
		"but": "O3 — la même image en pâte brute : ce qui disparaît ici n'était pas une ombre"}))
	sortie.append(_plan_de(base, {"id": "plafonnier-eteint", "famille": "plafonnier", "plafonniers": false,
		"but": "O3 — la torche seule, plafonnier éteint : la référence"}))
	# O5 — l'ombre qui monte au mur : le PNJ à 30 px d'une face que la caméra voit, la torche côté caméra.
	sortie.append(_plan_de(base, {"id": "mur", "famille": "mur", "mur": true,
		"but": "O5 — le PNJ près d'un mur, torche côté caméra : son ombre devient-elle une bande pleine hauteur ?"}))
	# O3/O4 — le scintillement : six images consécutives, scène tenue ; la respiration ; le recul de tir. Pâte D, puis brute.
	# OM3b : la torche ne respire plus — les plans `serie-respiration` gardent leur nom, pour se comparer à un passage d'avant
	# (`--avant`), et montrent désormais la torche au repos, sans rien figer : elle doit tenir comme la scène tenue.
	for cas in [["fixe", false, false], ["respiration", true, false], ["tir", false, true]]:
		for pate in ["", "brute"]:
			sortie.append(_plan_de(base, {"id": "serie-%s%s" % [cas[0], "" if pate == "" else "-brute"], "famille": "scintillement",
				"serie": IMAGES_SERIE, "respiration": cas[1], "tir": cas[2], "pate": pate,
				"but": "O3/O4 — six images consécutives, %s, pâte %s : ce qui change sans que rien ne bouge" % [
					{"fixe": "scène tenue", "respiration": "la torche au repos (elle respirait avant OM3b)",
						"tir": "pendant le recul de tir"}[cas[0]],
					"brute" if pate == "brute" else "D"]}))
	# OM3 — le recul tel qu'il se joue : armé UNE fois, puis laissé filer (les plans `serie-tir` le tiennent armé à chaque image,
	# ce qui ne montre que son premier pas). Le coup, le recul entier, le début du retour au souffle ; pâte D, puis brute.
	for pate in ["", "brute"]:
		sortie.append(_plan_de(base, {"id": "serie-recul%s" % ("" if pate == "" else "-brute"), "famille": "scintillement",
			"serie": IMAGES_RECUL, "recul": true, "pate": pate,
			"but": "OM3 — un coup, puis le recul qui file, %d images, pâte %s : ce que la torche fait vraiment après un tir" % [
				IMAGES_RECUL, "brute" if pate == "brute" else "D"]}))
	# O2 — le brouillage, salle 0.9 (six PNJ) : la torche de J1 seule, puis un PNJ qui éblouit J1.
	var salle09 := {"salle": [0, 8], "cible": 0, "cote": 0.0, "distance": 160.0, "theta": 0.0}
	sortie.append(_plan_de(salle09, {"id": "brouillage-torche", "famille": "brouillage",
		"but": "O2 — salle 0.9, la torche de J1 seule allumée : l'opacité de CHAQUE PNJ"}))
	sortie.append(_plan_de(salle09, {"id": "brouillage-ebloui", "famille": "brouillage", "ebloui_par": 0, "theta": 0.0,
		"but": "O2 — salle 0.9, un PNJ braque sa torche sur J1 : qui s'efface ?"}))
	# O12 — le recensement des lumières au sol, salle 0.9 au repos (chaque prise le fait aussi).
	sortie.append(_plan_de(salle09, {"id": "lumieres-salle09", "famille": "lumieres", "cible": 1,
		"but": "O12 — salle 0.9 au repos : combien de lumières par quadrant de 560 px (plafond moteur : 15) ?"}))
	# OM4 — les règles d'ombre « sans décision », à l'image. La posture dans la salle 0.1, la pose des plans « etoile » (ses
	# sondes y sont propres), debout puis accroupi ; le tir au mur dans la salle 0.9, qui a un mur d'une seule case (la colonne
	# x = 7, dont la caméra voit la face est). La mort n'a pas de plan : en aventure, le PNJ abattu est caché avec son étoile
	# (`AventurePartie._ranger_les_morts`), avant comme après — elle se garde sans fenêtre, en duel (`test_ombres_regles`).
	sortie.append(_plan_de(base, {"id": "regles-debout", "famille": "regles",
		"but": "O11 — le PNJ debout sous la torche, côté caméra : la largeur de son ombre, la référence"}))
	sortie.append(_plan_de(base, {"id": "regles-accroupi", "famille": "regles", "accroupi": true,
		"but": "O11 — le même PNJ accroupi : son ombre doit rétrécir avec sa silhouette (×0,8)"}))
	sortie.append(_plan_de(salle09, {"id": "regles-tir-au-mur", "famille": "regles", "cible": 3, "tir_au_mur": true,
		"torche": false, "lampes": "-", "plafonniers": false, "leds": false,
		"but": "O9/O10 — J1 collé à un mur d'une case tire, seules lumières le flash et l'écho : le flash éclaire de son côté, l'écho ne passe pas le mur"}))
	return sortie


static func _plan_de(base: Dictionary, propre: Dictionary) -> Dictionary:
	var p := base.duplicate(true)
	p.merge(propre, true)
	return p


## Les appuis du banc sur le jeu — vérifiés sans fenêtre par `tools/test_banc.gd`, comme ceux du photographe : un outil qui
## ouvre une fenêtre n'est dans aucune suite, et rien d'autre ne dirait qu'il s'est périmé.
static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents
	for methode in ["demarrer_l_aventure", "_set_player_input_provider", "weapon_for_index", "_accorder_rendu_aux_vues"]:
		if not main.has_method(methode):
			absents.append("GameState.%s() a disparu" % methode)
	for prop in ["aventure", "figurants", "p1", "p2", "vp1", "cam1", "arena", "rendu_racine_autorise", "archiver_les_matchs"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	for prop in ["match_hud", "p1_dazzle", "aventure_progression"]:
		if not prop in ui:
			absents.append("UI.%s a disparu" % prop)
	var p1 = main.get("p1")
	if p1 != null:
		for prop in ["flashlight", "ambient_light", "body_light", "shoot_cooldown", "dazzle_amount",
				"source_eblouissante", "est_pnj", "visual_enemy", "_dust_accum", "muzzle_flash", "shake_intensity", "accroupi",
				"visual"]:
			if not prop in p1:
				absents.append("Player.%s a disparu" % prop)
		for methode in ["etoile", "equip_weapon", "trigger_shoot_visuals"]:
			if not p1.has_method(methode):
				absents.append("Player.%s() a disparu" % methode)
	# OM4 : la marionnette qui s'accroupit répond à la question que la simulation pose à chaque pas.
	var texte_entrees := FileAccess.get_file_as_string("res://input_provider.gd")
	if not texte_entrees.contains("func is_crouch_pressed("):
		absents.append("InputProvider.is_crouch_pressed() a disparu")
	var Pres: GDScript = load("res://presentation_3d.gd")
	var membres_pres := {}
	for m in Pres.get_script_method_list():
		membres_pres[String(m["name"])] = true
	for methode in ["instance", "_camera_de", "opacite_du_corps", "etat_du_corps"]:
		if not membres_pres.has(methode):
			absents.append("Presentation3D.%s() a disparu" % methode)
	var texte_pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	for motif in ["var _capteurs_figurants", "var _voxels", "var _corps", "var _capteurs ", "var style_pate"]:
		if not texte_pres.contains(motif):
			absents.append("Presentation3D : « %s » a disparu" % motif)
	var texte_aventure := FileAccess.get_file_as_string("res://aventure_partie.gd")
	for motif in ["var phase", "var pnj", "var _t "]:
		if not texte_aventure.contains(motif):
			absents.append("AventurePartie : « %s » a disparu" % motif)
	var Prog: GDScript = load("res://aventure_progression.gd")
	var membres_prog := {}
	for m in Prog.get_script_method_list():
		membres_prog[String(m["name"])] = true
	for methode in ["reussir_niveau", "terminer_chapitre"]:
		if not membres_prog.has(methode):
			absents.append("AventureProgression.%s() a disparu" % methode)
	var texte_camera := FileAccess.get_file_as_string("res://camera_iso.gd")
	for motif in ["func vers_ecran(", "func vers_sol("]:
		if not texte_camera.contains(motif):
			absents.append("CameraIso : « %s » a disparu" % motif)
	return absents


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if _drapeau(args, "--liste"):
		_imprimer_le_catalogue()
		_sortir(0)
		return
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_ombres : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", DOSSIER_PAR_DEFAUT)
	_avant = _valeur(args, "--avant", "")
	_correctif = _valeur(args, "--correctif", "")
	if _correctif != "" and not _correctif in ["etoile_ccw", "etoile_cw", "disque", "disque_ccw"]:
		printerr("✗ --correctif attend etoile_ccw, etoile_cw, disque ou disque_ccw (reçu « %s »)" % _correctif)
		_sortir(1)
		return
	_lightmaps = _drapeau(args, "--lightmaps")
	_taille = _lire_taille(_valeur(args, "--taille", "1920x1080"))
	var choisis := _choisir(args)
	if choisis.is_empty():
		printerr("✗ aucun plan ne correspond à la sélection (--famille, --plan) : voir --liste")
		_sortir(1)
		return
	print("=== Le banc des ombres (OM0) : %d plan(s) ===" % choisis.size())
	_poser_la_fenetre()
	AudioServer.set_bus_mute(0, true)
	# Avant d'instancier `main.tscn` (pièges de l'audit) : sans `intro_vue`, l'intro dessinée recouvre la prise ; sans
	# `mode_iso`, la vue de dessus.
	GameSettings.intro_vue = true
	GameSettings.mode_iso = true
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	var manquants := preconditions_manquantes(_ui, _main)
	if not manquants.is_empty():
		printerr("✗ les appuis du banc ont changé : ", "; ".join(manquants))
		_sortir(1)
		return
	# Le chemin de rendu du joueur (la racine rend la vue unique) : `vp1` reste la lightmap que l'iso relit.
	_main.rendu_racine_autorise = true
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
		await _attendre_disparition(allumage, 3.0)
	_prog = ProgressionT.new("user://planche_ombres_progression.cfg")
	RenderingServer.frame_pre_draw.connect(_avant_le_rendu)
	var debut := Time.get_ticks_msec()
	for plan in choisis:
		await _jouer_le_plan(plan)
	_ecrire_le_journal(debut)
	_ecrire_la_planche_des_ombres()
	print("\n%d plan(s) photographié(s), %d refusé(s) — %s" % [_plans_faits, _refuses.size(),
		ProjectSettings.globalize_path(_dossier)])
	for r in _refuses:
		print("  refusé : ", r)
	_sortir(0)


func _imprimer_le_catalogue() -> void:
	print("Le banc des ombres (OM0) — %d plans :" % plans().size())
	for p in plans():
		print("  %-28s %-14s %s" % [p["id"], p["famille"], p["but"]])


func _choisir(args: PackedStringArray) -> Array[Dictionary]:
	var familles := _valeur(args, "--famille", "").strip_edges()
	var ids := _valeur(args, "--plan", "").strip_edges()
	var sortie: Array[Dictionary] = []
	for p in plans():
		if familles != "" and not String(p["famille"]) in familles.split(","):
			continue
		if ids != "" and not String(p["id"]) in ids.split(","):
			continue
		sortie.append(p)
	return sortie


# ---------------------------------------------------------------------------
# LA SALLE
# ---------------------------------------------------------------------------

## Pose la salle [chapitre, index] — sauf si c'est déjà elle. Rend faux si elle ne se pose pas.
func _poser_la_salle(salle: Array) -> bool:
	if salle == _salle_posee and _main.aventure != null:
		return true
	var c := int(salle[0])
	var i := int(salle[1])
	var chapitre: Dictionary = FormatT.charger_chapitre("res://assets/solo/chapitre_%02d" % c, -1)
	if chapitre.is_empty():
		printerr("✗ chapitre %d illisible" % c)
		return false
	# La vraie règle d'ouverture (`AventureProgression`) : un chapitre s'ouvre quand le précédent est TERMINÉ — son boss tombé
	# (`terminer_chapitre`), pas seulement ses salles réussies ; une salle, quand la précédente est réussie.
	for k in c:
		var chap_k: Dictionary = FormatT.charger_chapitre("res://assets/solo/chapitre_%02d" % k, -1)
		for n in (chap_k["niveaux"] as Array).size():
			if not _prog.niveau_reussi(k, n):
				_prog.reussir_niveau(k, n)
		if not _prog.chapitre_termine(k):
			_prog.terminer_chapitre(k)
	for n in i:
		if not _prog.niveau_reussi(c, n):
			_prog.reussir_niveau(c, n)
	_ui.aventure_progression = _prog
	var classe := String(chapitre["classe_imposee"]) if String(chapitre["classe_imposee"]) != "" else "pistolet"
	if not _main.demarrer_l_aventure(chapitre, i, classe, _prog):
		printerr("✗ la salle %d.%d ne se pose pas" % [c, i + 1])
		return false
	# Le carton passé d'un coup : le banc ne le photographie pas (`AventurePartie._physics_process` le retire au pas suivant).
	_main.aventure.set("_t", 1.0e6)
	if not await _attendre(func() -> bool: return _main.aventure != null and int(_main.aventure.phase) == 1, 60.0):
		printerr("✗ la salle %d.%d n'est jamais passée en jeu" % [c, i + 1])
		return false
	_iso = Presentation3D.instance()
	if _iso == null:
		printerr("✗ aucune Presentation3D : la vue iso n'est pas en place")
		return false
	_salle_posee = salle.duplicate()
	_figer_les_pnj()
	_pantin_j1 = Marionnette.new()
	_pantin_j1.name = "MarionnetteJ1"
	_main._set_player_input_provider(_main.p1, _pantin_j1)
	_pantins = [_pantin_j1]
	print("\n--- salle %d.%d : %d PNJ, %d plafonnier(s), vue iso %s, zoom %.2f ---" % [c, i + 1,
		(_main.aventure.pnj as Array).size(), get_tree().get_nodes_in_group("plafonniers").size(),
		str(bool(_iso.get("_actif"))), (_main.cam1 as Camera2D).zoom.x])
	return true


## Les PNJ ne pensent plus : leur bot est arrêté, une marionnette prend sa place (le patron du photographe) ; ils seront
## reposés à chaque image.
func _figer_les_pnj() -> void:
	_poses_pnj.clear()
	_poses_origine.clear()
	_classes_d_origine.clear()
	for p in _main.aventure.pnj:
		var pnj := p as Player
		if pnj == null:
			continue
		var bot = pnj.input_provider
		if bot != null:
			(bot as Node).set_process(false)
			(bot as Node).set_physics_process(false)
		var pantin := MarionnetteAccroupie.new()
		pantin.name = "MarionnettePNJ"
		pantin.visee = Vector2.from_angle(pnj.rotation)
		_main._set_player_input_provider(pnj, pantin)
		_poses_origine[pnj] = [pnj.global_position, Vector2.from_angle(pnj.rotation)]
		_classes_d_origine[pnj] = _slug(pnj)
	_poses_pnj = _poses_origine.duplicate(true)


func _pnj(k: int) -> Player:
	var liste: Array = _main.aventure.pnj
	if liste.is_empty():
		return null
	return liste[clampi(k, 0, liste.size() - 1)] as Player


# ---------------------------------------------------------------------------
# UN PLAN
# ---------------------------------------------------------------------------

func _jouer_le_plan(plan: Dictionary) -> void:
	var id := String(plan["id"])
	print("\n· %s — %s" % [id, plan["but"]])
	if not await _poser_la_salle(plan["salle"]):
		_refuser(id, "la salle ne se pose pas")
		return
	_plan_en_cours = plan
	# Chaque plan part d'une lampe au repos (OM3) : un recul laissé par le plan d'avant — les séries « tir » le tiennent armé —
	# filerait encore pendant les premières images de celui-ci, et la torche n'aurait pas fini de remonter.
	var j1_repos := _main.p1 as Player
	j1_repos.shoot_cooldown = 0.0
	j1_repos.set("_energie_torche", 2.5)
	var cible := _pnj(int(plan["cible"]))
	if cible == null:
		_refuser(id, "aucun PNJ dans la salle")
		return
	# Chaque plan repart des poses d'origine des PNJ (un plan précédent a pu en déplacer un).
	_poses_pnj = _poses_origine.duplicate(true)
	for p in _poses_pnj:
		(p as Player).flashlight_on = false
		((p as Player).input_provider as Marionnette).torche = false
		var pantin_pnj := (p as Player).input_provider as MarionnetteAccroupie
		if pantin_pnj != null:
			pantin_pnj.accroupi = p == cible and bool(plan.get("accroupi", false))
	if plan.has("classe"):
		_equiper(cible, String(plan["classe"]))
	var ancre: Vector2 = (_poses_pnj[cible] as Array)[0]
	var vers_camera := _vers_la_camera(ancre)
	if bool(plan.get("mur", false)):
		var pres_du_mur: Variant = _pres_d_un_mur(ancre, vers_camera)
		if pres_du_mur == null:
			_refuser(id, "aucun mur visible de la caméra à portée du PNJ")
			return
		ancre = pres_du_mur
	var direction := vers_camera.rotated(deg_to_rad(float(plan["cote"])))
	var pos_j1 := ancre + direction * float(plan["distance"])
	var axe := Vector2.ZERO
	_mur_du_plan = {}
	if bool(plan.get("tir_au_mur", false)):
		# OM4 — J1 collé à un mur d'une case que la caméra voit, la visée sur le mur ; le PNJ reste à sa pose d'origine.
		var mur: Variant = _mur_mince_vu(ancre, vers_camera)
		if mur == null:
			_refuser(id, "aucun mur d'une case, vu de la caméra, avec du sol des deux côtés, à 400 px du PNJ")
			return
		_mur_du_plan = mur
		pos_j1 = _mur_du_plan["j1"]
		axe = _mur_du_plan["visee"]
		_pose_j1 = [pos_j1, axe]
	else:
		if not _place_libre(pos_j1) or _mur_entre_les_deux(pos_j1, ancre):
			_refuser(id, "J1 ne tient pas à %.0f px du PNJ de ce côté (mur ou vide) : %s" % [float(plan["distance"]), str(pos_j1)])
			return
		axe = (ancre - pos_j1).normalized()
		_pose_j1 = [pos_j1, axe]
		_poses_pnj[cible] = [ancre, (-axe).rotated(deg_to_rad(float(plan["theta"])))]
	# Un PNJ qui éblouit J1 (O2) : sa torche allumée, braquée sur lui.
	if plan.has("ebloui_par"):
		var eblouisseur := _pnj(int(plan["ebloui_par"]))
		var p_e: Vector2 = pos_j1 + (ancre - pos_j1).rotated(deg_to_rad(35.0)).normalized() * 150.0
		if eblouisseur == cible:
			p_e = ancre
		_poses_pnj[eblouisseur] = [p_e, (pos_j1 - p_e).normalized()]
		(eblouisseur.input_provider as Marionnette).torche = true
	_pantin_j1.visee = axe
	_pantin_j1.torche = bool(plan.get("torche", true))
	if _pantin_j1.torche:
		Input.action_press("p1_torch")
	else:
		Input.action_release("p1_torch")
	# Le bandeau LED éteint le temps du plan (OM4, le tir au mur : le flash et l'écho seuls) ; rendu tel quel à la fin.
	var leds := {}
	if not bool(plan.get("leds", true)):
		for l in get_tree().root.find_children("*", "PointLight2D", true, false):
			if l is MurLed:
				leds[l] = (l as Light2D).visible
		_sans_led = true
	# La pâte, à l'exécution : celle du plan, sinon celle du lancement (`--pate`).
	var pate_avant := int(_iso.style_pate)
	if String(plan.get("pate", "")) == "brute":
		_iso.style_pate = IsoPate.BRUTE
	var plafonniers_avant := _plafonniers(bool(plan.get("plafonniers", true)))
	_appliquer_le_correctif()
	await _tenir(IMAGES_POSE)
	var n := int(plan.get("serie", 0))
	if n > 0:
		await _serie(plan, cible, n)
	else:
		await _prise(plan, cible)
	_iso.style_pate = pate_avant
	_plafonniers(plafonniers_avant)
	if plan.has("classe"):
		_equiper(cible, _classe_d_origine(cible))
	if not bool(plan.get("leds", true)):
		_sans_led = false
		for l in leds:
			if is_instance_valid(l):
				(l as Light2D).visible = bool(leds[l])
	if String(plan.get("lampes", "")) != "":
		var j1 := _main.p1 as Player
		j1.flashlight.visible = true
		j1.ambient_light.visible = true
		j1.body_light.visible = true
	var pantin_cible := cible.input_provider as MarionnetteAccroupie
	if pantin_cible != null:
		pantin_cible.accroupi = false
	_plans_faits += 1


func _refuser(id: String, raison: String) -> void:
	printerr("  ✗ %s refusé : %s" % [id, raison])
	_refuses.append("%s — %s" % [id, raison])
	_journal.append({"plan": id, "refuse": raison})


## La direction du MONDE vers le bas de l'écran, au point `p` : là où se tient la caméra iso, vue du sol. La torche
## « côté caméra » vient de là. Lue sur la vraie caméra (`CameraIso.vers_sol`) : elle suit le lacet, quel qu'il soit.
func _vers_la_camera(p: Vector2) -> Vector2:
	var cam := _iso._camera_de(0)
	var logique := get_window().get_visible_rect().size
	var s := cam.vers_ecran(p, logique)
	var bas := cam.vers_sol(s + Vector2(0.0, 60.0), logique)
	var d := bas - cam.vers_sol(s, logique)
	return d.normalized() if d.length() > 0.001 else Vector2.DOWN


## Un point à `MUR_ECART_PX` de la face d'un mur que la caméra voit — un mur situé du côté opposé à la caméra (la face
## tournée vers elle est la face visible) —, sur un rayon libre depuis l'ancre. `null` s'il n'y en a aucun à 300 px.
func _pres_d_un_mur(ancre: Vector2, vers_camera: Vector2) -> Variant:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var meilleur: Variant = null
	var meilleure_d := INF
	for k in 13:
		var dir := (-vers_camera).rotated(deg_to_rad(-45.0 + 7.5 * float(k)))
		var q := PhysicsRayQueryParameters2D.create(ancre, ancre + dir * 300.0, MapGeometry.WALL_LAYER)
		q.exclude = _corps_exclus()
		var coup := espace.intersect_ray(q)
		if coup.is_empty():
			continue
		var d := ancre.distance_to(coup["position"])
		if d < meilleure_d and d > MUR_ECART_PX + 8.0:
			meilleure_d = d
			meilleur = (coup["position"] as Vector2) - dir * MUR_ECART_PX
	return meilleur


## Un disque de 20 px de sol libre (le corps de J1 y tient) : plus serré que `_sol_libre` du photographe (40 px).
func _place_libre(p: Vector2, rayon: float = 20.0) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var disque := CircleShape2D.new()
	disque.radius = rayon
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = disque
	q.collision_mask = MapGeometry.WALL_LAYER
	q.transform = Transform2D(0.0, p)
	q.exclude = _corps_exclus()
	return espace.intersect_shape(q, 1).is_empty()


## Un mur entre `a` et `b` — les CORPS exclus : J1, J2 et les PNJ sont sur la couche des murs (1), et le rayon qui va au
## centre du PNJ le toucherait (`photographe._mur_entre` n'exclut que J1 et J2).
func _mur_entre_les_deux(a: Vector2, b: Vector2) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, MapGeometry.WALL_LAYER)
	q.exclude = _corps_exclus()
	return not espace.intersect_ray(q).is_empty()


func _corps_exclus() -> Array[RID]:
	var rids: Array[RID] = [(_main.p1 as CollisionObject2D).get_rid(), (_main.p2 as CollisionObject2D).get_rid()]
	if _main.aventure != null:
		for p in _main.aventure.pnj:
			if is_instance_valid(p):
				rids.append((p as CollisionObject2D).get_rid())
	return rids


## OM4, le tir au mur — un mur d'UNE case dont la caméra voit la face, du sol des deux côtés : J1 s'y colle et tire. C'est là
## que l'écho au sol d'avant O10 passait à travers la pierre, et que le flash d'avant O9 brûlait DANS le mur. Cherché par la
## physique, au centre des cases à 400 px de `pres_de` (le plus proche gagne) : la case libre, le mur à une demi-case dans la
## direction `d` (une face que la caméra voit), et la case d'après de nouveau libre, le mur ne faisant qu'une case d'épaisseur.
## Rend la place de J1, sa visée, la face et le point lu au-delà du mur ; `null` s'il n'y en a aucun.
func _mur_mince_vu(pres_de: Vector2, vers_camera: Vector2) -> Variant:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var case := 35.0
	var meilleur: Variant = null
	var meilleure_d := INF
	var centre0 := (pres_de / case).floor()
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var c := (centre0 + Vector2(dx, dy) + Vector2(0.5, 0.5)) * case
			if c.distance_to(pres_de) >= meilleure_d or not _place_libre(c, 15.0):
				continue
			for d in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
				if (-d).dot(vers_camera) < 0.5:
					continue
				var q := PhysicsRayQueryParameters2D.create(c, c + d * case, MapGeometry.WALL_LAYER)
				q.exclude = _corps_exclus()
				var proche := espace.intersect_ray(q)
				if proche.is_empty() or absf(c.distance_to(proche["position"]) - case * 0.5) > 1.0:
					continue
				var au_dela: Vector2 = c + d * case * 2.0
				if not _place_libre(au_dela, 15.0) or not _dans_la_carte(au_dela):
					continue
				var r := PhysicsRayQueryParameters2D.create(au_dela, c, MapGeometry.WALL_LAYER)
				r.exclude = _corps_exclus()
				var loin := espace.intersect_ray(r)
				if loin.is_empty() or absf(au_dela.distance_to(loin["position"]) - case * 0.5) > 1.0:
					continue
				var face: Vector2 = proche["position"]
				meilleure_d = c.distance_to(pres_de)
				meilleur = {"j1": face - d * COLLE_AU_MUR_PX, "visee": d, "face": face,
					"outre": (loin["position"] as Vector2) + d * 5.0}
	return meilleur


## Un point DANS la carte : un rayon dans chacune des quatre directions bute sur un mur à moins de 2 000 px. Hors de la carte
## (au-delà du mur d'enceinte, qui ne fait qu'une case), il n'y a plus rien — et la physique dit « libre ».
func _dans_la_carte(p: Vector2) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	for d in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
		var q := PhysicsRayQueryParameters2D.create(p, p + d * 2000.0, MapGeometry.WALL_LAYER)
		q.exclude = _corps_exclus()
		if espace.intersect_ray(q).is_empty():
			return false
	return true


## OM4 — le tir, au moment de la prise : le flash et l'écho au sol posés par le geste du jeu (`trigger_shoot_visuals`), la
## secousse de caméra annulée aussitôt (l'image d'avant et celle d'après doivent se superposer au pixel).
func _tirer() -> void:
	var j1 := _main.p1 as Player
	j1.trigger_shoot_visuals()
	j1.shake_intensity = 0.0


## OM4 — ce que les règles d'ombre changent, en chiffres : l'étoile du PNJ (rendue ? à quelle échelle, contre celle de sa
## silhouette) ; au tir au mur, la place du flash, le sol du côté du tireur et le sol au-delà du mur.
func _mesurer_les_regles(plan: Dictionary, cible: Player, lightmap: Image) -> Dictionary:
	var occ: LightOccluder2D = cible.etoile()
	var r := {"etoile_rendue": occ != null and occ.is_visible_in_tree(),
		"echelle_etoile": snappedf(occ.scale.x, 0.001) if occ != null else -1.0,
		"echelle_silhouette": snappedf((cible.visual as Node2D).scale.x, 0.001), "accroupi": cible.accroupi}
	if bool(plan.get("tir_au_mur", false)) and not _mur_du_plan.is_empty():
		var j1 := _main.p1 as Player
		var d: Vector2 = _mur_du_plan["visee"]
		var face: Vector2 = _mur_du_plan["face"]
		var cote := d.orthogonal()
		r["mur"] = {"face": _v(face), "visee": _v(d), "outre": _v(_mur_du_plan["outre"])}
		r["flash_avance_px"] = snappedf(j1.muzzle_flash.position.x, 0.01)
		r["flash_energie"] = snappedf(j1.muzzle_flash.energy, 0.001)
		# Le sol au pied du mur, devant J1 — là où le flash reculé brûle (son empreinte est petite : une trentaine de px).
		r["sol_au_flash"] = _moyenne_lue(lightmap, [face - d * 4.0, face - d * 8.0, face - d * 8.0 + cote * 5.0,
			face - d * 8.0 - cote * 5.0])
		# Le témoin : le sol autour de J1, hors de l'empreinte du flash — l'écho seul l'éclaire, avant comme après.
		r["sol_autour_du_tireur"] = _moyenne_lue(lightmap, [face - d * 10.0 + cote * 30.0, face - d * 10.0 - cote * 30.0,
			j1.global_position - d * 30.0])
		# Le sol au-delà du mur : le plus clair de la bande de 1 à 12 px derrière sa face lointaine, sur ± 15 px — l'écho sans
		# ombre y laissait une lueur.
		var loin: Vector2 = (_mur_du_plan["outre"] as Vector2) - d * 5.0
		var plus_clair := 0.0
		for a in range(1, 13):
			for b in range(-15, 16):
				plus_clair = maxf(plus_clair, _luminance_au(lightmap, loin + d * float(a) + cote * float(b)))
		r["sol_outre_mur_max"] = snappedf(plus_clair, 0.0001)
	return r


func _moyenne_lue(lightmap: Image, points: Array) -> float:
	var somme := 0.0
	var n := 0
	for p in points:
		var l := _luminance_au(lightmap, p)
		if l >= 0.0:
			somme += l
			n += 1
	return snappedf(somme / n, 0.0001) if n > 0 else -1.0


## Les plafonniers allumés ou non ; rend l'état d'avant (vrai : allumés).
func _plafonniers(allumes: bool) -> bool:
	var avant := true
	for pl in get_tree().get_nodes_in_group("plafonniers"):
		var n := pl as Node
		avant = avant and n.process_mode != Node.PROCESS_MODE_DISABLED
		n.process_mode = Node.PROCESS_MODE_INHERIT if allumes else Node.PROCESS_MODE_DISABLED
		for l in n.find_children("*", "Light2D", true, false):
			(l as Light2D).enabled = allumes
	return avant


## Équipe le PNJ d'une classe, par son slug (la même lecture que `planche_q42._equiper`).
func _equiper(pnj: Player, slug: String) -> void:
	var i := SLUGS.find(slug)
	for k in 10:
		var c = _main.weapon_for_index(k)
		if c is ClassData and String((c as ClassData).slug()) == slug:
			i = k
			break
	if i < 0:
		return
	pnj.equip_weapon(_main.weapon_for_index(i))
	_appliquer_le_correctif()


func _classe_d_origine(pnj: Player) -> String:
	return String(_classes_d_origine.get(pnj, "pistolet"))


## PROTOTYPE (`--correctif`) — l'étoile de chaque corps remplacée À L'EXÉCUTION, comme l'audit l'a essayé ; rien du jeu n'est
## modifié. Reposé après chaque équipement (`equip_weapon` refait l'étoile).
func _appliquer_le_correctif() -> void:
	if _correctif == "":
		return
	var corps: Array = [_main.p1]
	corps.append_array(_main.aventure.pnj if _main.aventure != null else [])
	for c in corps:
		var occ: LightOccluder2D = (c as Player).etoile()
		if occ == null or occ.occluder == null:
			continue
		var poly := OccluderPolygon2D.new()
		if _correctif.begins_with("disque"):
			var pts := PackedVector2Array()
			for i in 24:
				pts.append(Vector2.from_angle(TAU * float(i) / 24.0) * 13.0)
			poly.polygon = pts
		else:
			poly.polygon = occ.occluder.polygon
		poly.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE if _correctif.ends_with("_ccw") \
			else (OccluderPolygon2D.CULL_CLOCKWISE if _correctif.ends_with("_cw") else OccluderPolygon2D.CULL_DISABLED)
		occ.occluder = poly


# ---------------------------------------------------------------------------
# TENIR LA SCÈNE
# ---------------------------------------------------------------------------

func _tenir(n: int) -> void:
	for i in n:
		_reposer()
		await get_tree().process_frame


## Une image : J1 et chaque PNJ à leur pose, immobiles, vivants ; la lampe telle que le plan la veut.
func _reposer() -> void:
	var j1 := _main.p1 as Player
	j1.global_position = _pose_j1[0]
	j1.velocity = Vector2.ZERO
	j1.global_rotation = (_pose_j1[1] as Vector2).angle()
	j1.hp = 100.0
	j1.set("_dust_accum", -1.0e9)
	if bool(_plan_en_cours.get("tir", false)):
		j1.shoot_cooldown = 0.2
	var lampes := String(_plan_en_cours.get("lampes", ""))
	if lampes != "":
		j1.flashlight.visible = lampes.contains("F")
		j1.ambient_light.visible = lampes.contains("H")
		j1.body_light.visible = lampes.contains("B")
	for p in _poses_pnj:
		var pnj := p as Player
		if not is_instance_valid(pnj):
			continue
		var pose: Array = _poses_pnj[pnj]
		pnj.global_position = pose[0]
		pnj.velocity = Vector2.ZERO
		pnj.global_rotation = (pose[1] as Vector2).angle()
		(pnj.input_provider as Marionnette).visee = pose[1]
		pnj.hp = 100.0
		pnj.set("_dust_accum", -1.0e9)
	_poser_le_regard()
	for cam in [_main.cam1, _main.cam2]:
		if is_instance_valid(cam):
			(cam as Camera2D).reset_smoothing()
	if _sans_led:
		for l in get_tree().root.find_children("*", "PointLight2D", true, false):
			if l is MurLed:
				(l as Light2D).visible = false
	_ecran_nu()


## Le décalage du regard de J1 posé à sa valeur d'ARRIVÉE, à chaque image. `RegardDuel.lisser` ne s'arrête jamais net : après un
## changement de visée, la caméra 2D glisse d'une fraction de pixel pendant des secondes, la lightmap rééchantillonnée fait sauter
## les paliers du lavis, et une série « scène tenue » compte des milliers de pixels qui changent (premier passage du banc : 1 351
## à 2 696 pixels de lightmap au-delà de 8 niveaux, deux plans après la pose de la salle, zéro une fois la caméra arrivée) —
## piège du 2026-09-25, « La caméra 2D glisse encore au temps figé ». Mêmes entrées que `GameState._suivre_du_regard`.
func _poser_le_regard() -> void:
	var cam := _main.cam1 as Camera2D
	var j1 := _main.p1 as Node2D
	if cam == null or j1 == null:
		return
	var vue := cam.custom_viewport as Viewport
	var vue_px := vue.get_visible_rect().size if vue != null else Vector2(1920.0, 1080.0)
	var vise := RegardDuel.decalage_vise(Vector2.RIGHT.rotated(j1.rotation), GameSettings.decalage_visee, vue_px, cam.zoom.y)
	var decalages: Array = _main.get("_regard_decalage")
	if decalages != null and decalages.size() > 0:
		decalages[0] = vise


## L'écran « nu » (le patron de `banc_lumieres._q76_montrer`) : le voile d'éblouissement — qui respire même en pause —, le
## HUD et les particules cachés. Ce que le banc compare est la lumière du monde.
func _ecran_nu() -> void:
	var voile := (_main.ui.p1_dazzle as Node).get_parent() as CanvasItem
	if voile != null:
		voile.visible = false
	if _main.ui.match_hud != null:
		(_main.ui.match_hud as CanvasItem).visible = false
	var pool := get_tree().get_first_node_in_group("particle_pool") as CanvasItem
	if pool != null:
		pool.visible = false


## Juste avant le rendu, après le `_process` de la présentation : les corps voxel à leur pose EXACTE, sans respiration
## (le patron de `planche_q42`) — J1 (corps 0) et les figurants (corps 2 + k).
func _avant_le_rendu() -> void:
	if _iso == null or not is_instance_valid(_iso) or _main.aventure == null:
		return
	var voxels: Array = _iso.get("_voxels")
	var corps: Array = _iso.get("_corps")
	var poses: Array = [[0, _main.p1, _pose_j1]]
	var figurants: Array = _iso.get("_figurants")
	for k in figurants.size():
		var f = figurants[k]
		if is_instance_valid(f) and _poses_pnj.has(f):
			poses.append([2 + k, f, _poses_pnj[f]])
	for entree in poses:
		var j := int(entree[0])
		if j >= voxels.size() or j >= corps.size():
			continue
		var voxel := voxels[j] as VoxelCorps
		if voxel == null or not (corps[j] as Node3D).visible or j >= (_iso.get("_etats_corps") as Array).size():
			continue
		var etat: Dictionary = _iso.etat_du_corps(j, entree[1])
		etat["position"] = (entree[2] as Array)[0]
		etat["visee"] = (entree[2] as Array)[1]
		etat["vitesse"] = Vector2.ZERO
		etat["t"] = 0.0
		voxel.poser(etat)


# ---------------------------------------------------------------------------
# LES PRISES ET LES MESURES
# ---------------------------------------------------------------------------

## Une image : l'écran nu et la lightmap de la même image.
func _capturer_l_image() -> Array:
	await RenderingServer.frame_post_draw
	var ecran: Image = get_window().get_texture().get_image()
	var lightmap: Image = _main.vp1.get_texture().get_image()
	return [ecran, lightmap]


func _prise(plan: Dictionary, cible: Player) -> void:
	var id := String(plan["id"])
	_reposer()
	if bool(plan.get("tir_au_mur", false)):
		_tirer()
	var images: Array = await _capturer_l_image()
	var ecran: Image = images[0]
	var lightmap: Image = images[1]
	ecran.save_png("%s/%s_ecran.png" % [_dossier, id])
	if _lightmaps:
		lightmap.save_png("%s/%s_lightmap.png" % [_dossier, id])
	var entree := _mesurer(plan, cible, ecran, lightmap)
	_decouper_autour(id, cible, ecran, lightmap)
	if String(plan["famille"]) in FAMILLES_SONDEES and not bool(plan.get("tir_au_mur", false)):
		entree["sonde"] = await _sonde_torche_seule(cible)
	_journal.append(entree)
	_imprimer(entree)


## La sonde se lit sur une image à part, TORCHE SEULE : les plafonniers coupés le temps d'une image. Un plafonnier n'est arrêté
## par aucun corps (son masque d'ombre est neutre, S5) : il éclaire l'intérieur de l'étoile quoi qu'il arrive, et la sonde
## mesurerait sa flaque au lieu de ce que l'étoile fait à la torche (premier passage : 0,53 « dedans / dehors » sous le
## plafonnier de la salle 0.1, là où la lightmap montre l'intérieur noir sous la torche). L'image du plan, elle, garde tout.
func _sonde_torche_seule(cible: Player) -> Dictionary:
	var avant := _plafonniers(false)
	var leds := {}
	for l in get_tree().root.find_children("*", "PointLight2D", true, false):
		if l is MurLed:
			leds[l] = (l as Light2D).visible
	_sans_led = true
	await _tenir(2)
	_reposer()
	var images: Array = await _capturer_l_image()
	if _lightmaps:
		(images[1] as Image).save_png("%s/%s_sonde_lightmap.png" % [_dossier, String(_plan_en_cours.get("id", "sonde"))])
	var r := _sonder(images[1], cible.global_position, _etoile_au_sol(cible), (_main.p1.flashlight as Light2D).global_position)
	r["lumieres"] = "torche seule (plafonniers et bandeau LED coupés)"
	# Le capteur du PNJ sous la même lumière : il ne voit pas l'étoile de son corps (Q42), donc le culling de cette étoile ne
	# doit pas le faire bouger — la seule lecture où il n'est pas saturé par le plafonnier.
	r["capteur"] = _niveau_du_capteur(cible)
	_plafonniers(avant)
	_sans_led = false
	for l in leds:
		if is_instance_valid(l):
			(l as Light2D).visible = bool(leds[l])
	await _tenir(2)
	return r


## Une série : `n` images CONSÉCUTIVES (la scène reposée entre deux, rien d'autre), puis l'écart entre chaque paire.
func _serie(plan: Dictionary, cible: Player, n: int) -> void:
	var id := String(plan["id"])
	var ecrans: Array[Image] = []
	var lightmaps: Array[Image] = []
	_energies.clear()
	for k in n:
		if k == 0 and bool(plan.get("recul", false)):
			# Le coup : le recul armé une fois, de la durée de l'arme de J1, puis laissé au décompte du jeu.
			var j1 := _main.p1 as Player
			j1.shoot_cooldown = float(j1.current_weapon.cooldown) if j1.current_weapon != null else 0.16
		_reposer()
		var images: Array = await _capturer_l_image()
		ecrans.append(images[0])
		lightmaps.append(images[1])
		_energies.append(snappedf(float((_main.p1.flashlight as Light2D).energy), 0.0001))
		await get_tree().process_frame
	ecrans[0].save_png("%s/%s_ecran.png" % [_dossier, id])
	var entree := _mesurer(plan, cible, ecrans[0], lightmaps[0])
	_decouper_autour(id, cible, ecrans[0], lightmaps[0])
	var paires: Array = []
	var cumul_ecran := PackedByteArray()
	var lumas_e: Array[PackedByteArray] = []
	var lumas_l: Array[PackedByteArray] = []
	for k in n:
		lumas_e.append(_luma(ecrans[k]))
		lumas_l.append(_luma(lightmaps[k]))
	var corps := _masque_des_corps(ecrans[0].get_width(), ecrans[0].get_height())
	for k in n - 1:
		var e := _ecart(lumas_e[k], lumas_e[k + 1], cumul_ecran, corps)
		cumul_ecran = e["cumul"]
		var l := _ecart(lumas_l[k], lumas_l[k + 1], PackedByteArray(), PackedByteArray())
		paires.append({"ecran": _sans_cumul(e), "lightmap": _sans_cumul(l)})
	# OM3 — les allers-retours, sur chaque triplet d'images : le papillotement, que ne fait pas une lumière qui monte en douceur.
	var allers_retours := []
	var carte_ar := PackedByteArray()
	for k in range(1, n - 1):
		var ar_e := _allers_retours(lumas_e[k - 1], lumas_e[k], lumas_e[k + 1], corps, SEUILS_SCINTILLEMENT[0], carte_ar)
		carte_ar = ar_e["marque"]
		var ar_l := _allers_retours(lumas_l[k - 1], lumas_l[k], lumas_l[k + 1], PackedByteArray(), SEUILS_SCINTILLEMENT[0],
			PackedByteArray())
		allers_retours.append({"ecran_hors_corps_8": int(ar_e["compte"]), "lightmap_8": int(ar_l["compte"])})
	if not carte_ar.is_empty():
		Image.create_from_data(ecrans[0].get_width(), ecrans[0].get_height(), false, Image.FORMAT_L8, carte_ar).save_png(
			"%s/%s_allers_retours.png" % [_dossier, id])
	entree["scintillement"] = {"images": n, "paires": paires, "resume": _resume_des_paires(paires),
		"energies_torche": _energies.duplicate(), "allers_retours": allers_retours,
		"allers_retours_total": {
			"ecran_hors_corps_8": allers_retours.reduce(func(a: int, t: Dictionary) -> int: return a + int(t["ecran_hors_corps_8"]), 0),
			"lightmap_8": allers_retours.reduce(func(a: int, t: Dictionary) -> int: return a + int(t["lightmap_8"]), 0)}}
	if String(plan["famille"]) in FAMILLES_SONDEES:
		entree["sonde"] = await _sonde_torche_seule(cible)
	if not cumul_ecran.is_empty():
		var w := ecrans[0].get_width()
		var h := ecrans[0].get_height()
		var vis := Image.create_from_data(w, h, false, Image.FORMAT_L8, cumul_ecran)
		vis.save_png("%s/%s_diff_max.png" % [_dossier, id])
	_journal.append(entree)
	_imprimer(entree)


static func _sans_cumul(e: Dictionary) -> Dictionary:
	var d := e.duplicate()
	d.erase("cumul")
	return d


## L'écart entre deux images de même taille, données en luma Rec. 601 (celle de `PIL.Image.convert("L")`, donc de la mesure
## de l'audit) : le nombre de pixels qui changent de plus de chaque seuil, et le saut maximal. `cumul` : l'écart maximal par
## pixel accumulé, ×4 (l'image de la planche). `corps` (même taille, 1 = pixel d'un corps) : ces pixels sont comptés à part —
## les corps voxel frémissent d'un pixel même tenus (piège du 2026-09-30), et ce qu'on mesure ici est la lumière du monde.
static func _ecart(la: PackedByteArray, lb: PackedByteArray, cumul: PackedByteArray, corps: PackedByteArray) -> Dictionary:
	var n := mini(la.size(), lb.size())
	if cumul.size() != n:
		cumul = PackedByteArray()
		cumul.resize(n)
	var au_dela_8 := 0
	var au_dela_24 := 0
	var maxi := 0
	var hors_corps_8 := 0
	var hors_corps_24 := 0
	var avec_corps := corps.size() == n
	var s1: int = SEUILS_SCINTILLEMENT[0]
	var s2: int = SEUILS_SCINTILLEMENT[1]
	for i in n:
		var d := absi(la[i] - lb[i])
		if d > s1:
			au_dela_8 += 1
			var dehors := not avec_corps or corps[i] == 0
			if dehors:
				hors_corps_8 += 1
			if d > s2:
				au_dela_24 += 1
				if dehors:
					hors_corps_24 += 1
		if d > maxi:
			maxi = d
		if d * 4 > cumul[i]:
			cumul[i] = mini(d * 4, 255)
	return {"au_dela_8": au_dela_8, "au_dela_24": au_dela_24, "saut_max": maxi, "cumul": cumul,
		"hors_corps_8": hors_corps_8, "hors_corps_24": hors_corps_24}


## OM3 — les ALLERS-RETOURS : les pixels (hors des corps, si un masque est donné) dont la luma monte puis redescend — ou
## l'inverse — de plus de `seuil` niveaux sur trois images consécutives. C'est la signature d'un papillotement ; une lumière qui
## monte en douceur peut faire changer des milliers de pixels d'une image à l'autre sous la pâte D (les paliers balaient le sol),
## mais chacun dans le même sens.
## Rend `{compte, marque}` : la marque (255 là où un aller-retour a eu lieu, cumulée d'un triplet à l'autre) devient
## `<id>_allers_retours.png` — OÙ la lumière papillote.
static func _allers_retours(la: PackedByteArray, lb: PackedByteArray, lc: PackedByteArray, corps: PackedByteArray,
		seuil: int, marque: PackedByteArray) -> Dictionary:
	var n := mini(la.size(), mini(lb.size(), lc.size()))
	var avec_corps := corps.size() == n
	if marque.size() != n:
		marque = PackedByteArray()
		marque.resize(n)
	var compte := 0
	for i in n:
		if avec_corps and corps[i] != 0:
			continue
		var d1 := int(lb[i]) - int(la[i])
		var d2 := int(lc[i]) - int(lb[i])
		if (d1 > seuil and d2 < -seuil) or (d1 < -seuil and d2 > seuil):
			compte += 1
			marque[i] = 255
	return {"compte": compte, "marque": marque}


## Les pixels de l'écran que couvrent les corps (J1 et les PNJ) : un disque de 70 px autour de chaque corps projeté, et de 40 px
## autour du point à 1,1 tuile de haut (la tête) — large : on écarte un corps, pas un bout de sol.
func _masque_des_corps(w: int, h: int) -> PackedByteArray:
	var masque := PackedByteArray()
	masque.resize(w * h)
	var cam := _iso._camera_de(0)
	var logique := get_window().get_visible_rect().size
	var taille := Vector2(w, h)
	var corps: Array = [_main.p1]
	corps.append_array(_main.aventure.pnj)
	for c in corps:
		if not is_instance_valid(c):
			continue
		for pied_tete in [[0.0, 70.0], [38.0, 40.0]]:
			var centre := cam.vers_ecran((c as Node2D).global_position, logique, pied_tete[0]) * taille / logique
			var r := float(pied_tete[1])
			for y in range(maxi(0, int(centre.y - r)), mini(h, int(centre.y + r) + 1)):
				for x in range(maxi(0, int(centre.x - r)), mini(w, int(centre.x + r) + 1)):
					if Vector2(x, y).distance_squared_to(centre) <= r * r:
						masque[y * w + x] = 1
	return masque


static func _luma(img: Image) -> PackedByteArray:
	var copie := img.duplicate() as Image
	if copie.get_format() != Image.FORMAT_RGB8:
		copie.convert(Image.FORMAT_RGB8)
	var src := copie.get_data()
	var sortie := PackedByteArray()
	sortie.resize(src.size() / 3)
	for i in sortie.size():
		var o := i * 3
		sortie[i] = (src[o] * 299 + src[o + 1] * 587 + src[o + 2] * 114 + 500) / 1000
	return sortie


static func _resume_des_paires(paires: Array) -> Dictionary:
	var r := {}
	for source in ["ecran", "lightmap"]:
		var mini8 := 1 << 30
		var maxi8 := 0
		var mini24 := 1 << 30
		var maxi24 := 0
		var saut := 0
		var hc8 := [1 << 30, 0]
		var hc24 := [1 << 30, 0]
		for p in paires:
			var e: Dictionary = p[source]
			mini8 = mini(mini8, int(e["au_dela_8"]))
			maxi8 = maxi(maxi8, int(e["au_dela_8"]))
			mini24 = mini(mini24, int(e["au_dela_24"]))
			maxi24 = maxi(maxi24, int(e["au_dela_24"]))
			saut = maxi(saut, int(e["saut_max"]))
			hc8 = [mini(hc8[0], int(e["hors_corps_8"])), maxi(hc8[1], int(e["hors_corps_8"]))]
			hc24 = [mini(hc24[0], int(e["hors_corps_24"])), maxi(hc24[1], int(e["hors_corps_24"]))]
		r[source] = {"au_dela_8": [mini8, maxi8], "au_dela_24": [mini24, maxi24], "saut_max": saut,
			"hors_corps_8": hc8, "hors_corps_24": hc24}
	return r


## Les mesures d'une prise (voir l'en-tête) — sur l'image de l'écran et la lightmap de la MÊME image.
func _mesurer(plan: Dictionary, cible: Player, ecran: Image, lightmap: Image) -> Dictionary:
	var lampe: Light2D = _main.p1.flashlight
	var etoile := _etoile_au_sol(cible)
	var occ: LightOccluder2D = cible.etoile()
	var entree := {"plan": String(plan["id"]), "famille": String(plan["famille"]),
		"j1": _v(_main.p1.global_position), "pnj": _v(cible.global_position), "classe_pnj": _slug(cible),
		"lampe": _v(lampe.global_position), "torche_allumee": lampe.enabled, "energie": lampe.energy,
		"etoile": Array(etoile).map(func(v: Vector2) -> Array: return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]),
		"cull_mode_etoile": occ.occluder.cull_mode if occ != null and occ.occluder != null else -1,
		"zoom": (_main.cam1 as Camera2D).zoom.x, "ecran": [ecran.get_width(), ecran.get_height()],
		"repere_lightmap": [snappedf(_main.vp1.get_canvas_transform().origin.x, 0.000001),
			snappedf(_main.vp1.get_canvas_transform().origin.y, 0.000001)],
		"pate": int(_iso.style_pate)}
	# Où tombent J1 et le PNJ dans la lightmap (pixels), et sa rotation : la caméra 2D suit le lacet de la vue iso.
	var ct_lm: Transform2D = _main.vp1.get_canvas_transform()
	var sc_lm := Vector2(lightmap.get_size()) / Vector2(_main.vp1.size)
	entree["lightmap_px"] = {"j1": _v((ct_lm * _main.p1.global_position) * sc_lm), "pnj": _v((ct_lm * cible.global_position) * sc_lm),
		"rotation_deg": snappedf(rad_to_deg(ct_lm.get_rotation()), 0.01), "echelle": snappedf(ct_lm.get_scale().x * sc_lm.x, 0.0001)}
	entree["capteur"] = _niveau_du_capteur(cible)
	var opacites := []
	for p in _main.aventure.pnj:
		if is_instance_valid(p):
			opacites.append(snappedf(Presentation3D.opacite_du_corps(p, false), 0.001))
	var source = _main.p1.get("source_eblouissante")
	entree["opacites"] = opacites
	entree["eblouissement_j1"] = snappedf(float(_main.p1.dazzle_amount), 0.001)
	entree["source_eblouissante"] = String((source as Node).name) if source is Node and is_instance_valid(source) else ""
	entree["lumieres"] = _recenser()
	if String(plan["famille"]) == "regles":
		entree["regles"] = _mesurer_les_regles(plan, cible, lightmap)
	return entree


## L'étoile du corps, au sol : sa forme passée par la transformation de son CORPS (ce que `EtoileDeCorps` recopie avant le
## rendu — `test_ombre_propre._forme_monde`).
static func _etoile_au_sol(corps: Node2D) -> PackedVector2Array:
	var occ: LightOccluder2D = corps.call("etoile")
	if occ == null or occ.occluder == null:
		return PackedVector2Array()
	# L'échelle du nœud de l'étoile (OM4 : la posture) — sa canvas ne recopie que la position et la rotation du corps ; à ×1
	# (tout corps debout, et tout le code d'avant OM4), la forme d'avant.
	return corps.global_transform * Transform2D(0.0, occ.scale, 0.0, Vector2.ZERO) * occ.occluder.polygon


## « Le sol dans l'étoile, côté lampe, est éclairé » — lu dans la lightmap (voir l'en-tête).
func _sonder(lightmap: Image, centre: Vector2, etoile: PackedVector2Array, lampe: Vector2) -> Dictionary:
	if etoile.size() < 3:
		return {}
	var vers_lampe := (lampe - centre).normalized()
	var dedans := 0.0
	var dehors := 0.0
	var n := 0
	var r_derriere := 0.0
	for v in etoile:
		var d := v - centre
		if d.length() < 1.0:
			continue
		var dir := d.normalized()
		if dir.dot(vers_lampe) >= cos(deg_to_rad(SONDE_DEMI_ANGLE)):
			dedans += _luminance_au(lightmap, centre + d * SONDE_DEDANS)
			dehors += _luminance_au(lightmap, v + dir * SONDE_DEHORS_PX)
			n += 1
		if dir.dot(-vers_lampe) > 0.95:
			r_derriere = maxf(r_derriere, d.length())
	var r := {"rayons": n}
	if n > 0:
		r["dedans"] = snappedf(dedans / n, 0.0001)
		r["dehors"] = snappedf(dehors / n, 0.0001)
		r["rapport"] = snappedf(dedans / maxf(dehors, 1e-4), 0.001)
	# Derrière : au-delà de l'étoile, côté opposé à la lampe, contre le même éloignement de la lampe mais de côté (hors de
	# l'ombre du corps, dans le cône si la lampe y porte).
	if r_derriere > 0.0 and not bool(_plan_en_cours.get("mur", false)):
		var p_derriere := centre - vers_lampe * (r_derriere + 12.0)
		var dist := lampe.distance_to(p_derriere)
		var p_cote := lampe + (p_derriere - lampe).normalized().rotated(deg_to_rad(9.0)) * dist
		var l_derriere := _luminance_au(lightmap, p_derriere)
		var l_cote := _luminance_au(lightmap, p_cote)
		r["derriere"] = snappedf(l_derriere, 0.0001)
		r["derriere_cote"] = snappedf(l_cote, 0.0001)
		r["derriere_rapport"] = snappedf(l_derriere / maxf(l_cote, 1e-4), 0.001)
		r["largeur_ombre_px"] = _largeur_de_l_ombre(lightmap, p_derriere, vers_lampe)
	return r


## La largeur de l'ombre du corps en travers de l'axe lampe → corps, au point `p` derrière lui : le nombre de pixels de monde,
## sur ± `OMBRE_TRAVERS_PX`, où la lightmap tombe sous la moitié du sol lu aux deux bouts. −1 si les deux bouts sont noirs
## eux aussi : rien à mesurer.
func _largeur_de_l_ombre(lightmap: Image, p: Vector2, vers_lampe: Vector2) -> int:
	var travers := vers_lampe.orthogonal()
	var bouts := (_luminance_au(lightmap, p + travers * OMBRE_TRAVERS_PX)
		+ _luminance_au(lightmap, p - travers * OMBRE_TRAVERS_PX)) * 0.5
	if bouts <= 0.02:
		return -1
	var n := 0
	for k in range(-OMBRE_TRAVERS_PX, OMBRE_TRAVERS_PX + 1):
		if _luminance_au(lightmap, p + travers * float(k)) < bouts * 0.5:
			n += 1
	return n


## La luminance (Rec. 709, celle de la pâte) de la lightmap au point du monde `p`.
func _luminance_au(lightmap: Image, p: Vector2) -> float:
	var ct: Transform2D = _main.vp1.get_canvas_transform()
	var echelle := Vector2(lightmap.get_size()) / Vector2(_main.vp1.size)
	var q := Vector2i((ct * p) * echelle)
	if q.x < 0 or q.y < 0 or q.x >= lightmap.get_width() or q.y >= lightmap.get_height():
		return -1.0
	var c := lightmap.get_pixelv(q)
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## Ce que lit le corps voxel du PNJ dans SON capteur : moyenne et maximum de l'anneau (le calcul de `planche_q42._niveau`).
func _niveau_du_capteur(cible: Player) -> Dictionary:
	var figurants: Array = _iso.get("_figurants")
	var capteurs: Array = _iso.get("_capteurs_figurants")
	var k := figurants.find(cible)
	if k < 0 or k >= capteurs.size() or capteurs[k] == null:
		return {}
	var img: Image = (capteurs[k] as CapteurCorps).get_texture().get_image()
	var texels_par_px := float(CapteurCorps.TAILLE) / CapteurCorps.MONDE_PX
	var rayon := minf(Presentation3D.RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0) * texels_par_px
	var centre := Vector2(img.get_width(), img.get_height()) * 0.5
	var somme := 0.0
	var haut := 0.0
	for a in 64:
		var q := centre + Vector2.from_angle(TAU * (float(a) + 0.5) / 64.0) * rayon
		var px := img.get_pixelv(Vector2i(q))
		var v := px.r * 0.2126 + px.g * 0.7152 + px.b * 0.0722
		somme += v
		haut = maxf(haut, v)
	return {"moyenne": snappedf(somme / 64.0, 0.0001), "maximum": snappedf(haut, 0.0001)}


## Le recensement de l'audit : par quadrant de 560 px du sol, les `Light2D` allumées et visibles qui l'atteignent (portée
## qui croise le décor ou une vue).
func _recenser() -> Dictionary:
	var sol := _main.arena.get_node_or_null("CustomFloor") as Node2D
	var origine := sol.global_position if sol != null else Vector2.ZERO
	var par_quadrant := {}
	var total := 0
	for l in get_tree().root.find_children("*", "Light2D", true, false):
		var lum := l as Light2D
		if lum == null or not lum.enabled or not lum.is_visible_in_tree():
			continue
		if (lum.range_item_cull_mask & (1 | 16)) == 0:
			continue
		total += 1
		var r := 64.0
		if lum is PointLight2D and (lum as PointLight2D).texture != null:
			var t := (lum as PointLight2D).texture
			r = maxf(t.get_width(), t.get_height()) * 0.5 * (lum as PointLight2D).texture_scale
		var c := lum.global_position - origine
		for qx in range(int(floor((c.x - r) / QUADRANT_PX)), int(floor((c.x + r) / QUADRANT_PX)) + 1):
			for qy in range(int(floor((c.y - r) / QUADRANT_PX)), int(floor((c.y + r) / QUADRANT_PX)) + 1):
				var cle := "%d,%d" % [qx, qy]
				par_quadrant[cle] = int(par_quadrant.get(cle, 0)) + 1
	var pire := 0
	for cle in par_quadrant:
		pire = maxi(pire, int(par_quadrant[cle]))
	return {"total": total, "pire_quadrant": pire, "plafond": PLAFOND_LUMIERES, "par_quadrant": par_quadrant}


func _slug(corps: Node) -> String:
	var arme = corps.get("current_weapon")
	if arme is ClassData:
		return String((arme as ClassData).slug())
	return ""


static func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]


func _imprimer(e: Dictionary) -> void:
	var s: Dictionary = e.get("sonde", {})
	var ligne := "  %s : PNJ %s (%s), lampe %s, sonde dedans/dehors %s, derrière %s, capteur %s, opacités %s, ébloui J1 %.3f (%s), lumières : pire quadrant %d" % [
		e["plan"], str(e["pnj"]), e["classe_pnj"], str(e["lampe"]), str(s.get("rapport", "—")), str(s.get("derriere_rapport", "—")),
		str((e.get("capteur", {}) as Dictionary).get("moyenne", "—")), str(e["opacites"]), float(e["eblouissement_j1"]),
		e["source_eblouissante"], int((e["lumieres"] as Dictionary)["pire_quadrant"])]
	print(ligne)
	if e.has("scintillement"):
		var r: Dictionary = (e["scintillement"] as Dictionary)["resume"]
		print("    scintillement écran : >8 %s, >24 %s, saut max %d — hors des corps : >8 %s, >24 %s ; lightmap : >8 %s, saut max %d" % [
			str(r["ecran"]["au_dela_8"]), str(r["ecran"]["au_dela_24"]), int(r["ecran"]["saut_max"]),
			str(r["ecran"]["hors_corps_8"]), str(r["ecran"]["hors_corps_24"]),
			str(r["lightmap"]["au_dela_8"]), int(r["lightmap"]["saut_max"])])
		print("    énergie de la torche, image par image : %s" % str((e["scintillement"] as Dictionary)["energies_torche"]))


## Les découpes autour du PNJ : dans l'image iso (×3, avec et sans repères) et dans la lightmap ; et son capteur.
func _decouper_autour(id: String, cible: Player, ecran: Image, lightmap: Image) -> void:
	var cam := _iso._camera_de(0)
	var logique := get_window().get_visible_rect().size
	var taille := Vector2(ecran.get_size())
	# Le point regardé : le PNJ — ou J1, au tir au mur (OM4), où ce qui change est autour de lui.
	var regarde := (_main.p1 as Node2D).global_position if not _mur_du_plan.is_empty() else cible.global_position
	var c := cam.vers_ecran(regarde, logique) * taille / logique
	var x0 := clampi(int(c.x) - DECOUPE_PX / 2, 0, maxi(0, ecran.get_width() - DECOUPE_PX))
	var y0 := clampi(int(c.y) - DECOUPE_PX * 2 / 3, 0, maxi(0, ecran.get_height() - DECOUPE_PX))
	var coupe := ecran.get_region(Rect2i(x0, y0, DECOUPE_PX, DECOUPE_PX))
	coupe.resize(DECOUPE_PX * LOUPE, DECOUPE_PX * LOUPE, Image.INTERPOLATE_NEAREST)
	coupe.save_png("%s/%s_pnj_iso.png" % [_dossier, id])
	var reperes := coupe.duplicate() as Image
	var origine := Vector2(x0, y0)
	var etoile := _etoile_au_sol(cible)
	var disque := PackedVector2Array()
	for a in 32:
		disque.append(cible.global_position + Vector2.from_angle(TAU * a / 32.0) * CapteurCorps.RAYON_PX)
	var vers := func(p: Vector2) -> Vector2: return (cam.vers_ecran(p, logique) * taille / logique - origine) * LOUPE
	_tracer_le_contour(reperes, etoile, vers, Color(1, 0.1, 0.1))
	_tracer_le_contour(reperes, disque, vers, Color(0.1, 1, 0.1))
	var centre: Vector2 = vers.call(cible.global_position)
	reperes.fill_rect(Rect2i(Vector2i(centre) - Vector2i(2, 2), Vector2i(5, 5)), Color(0.2, 0.4, 1))
	reperes.save_png("%s/%s_pnj_iso_reperes.png" % [_dossier, id])
	# La lightmap autour du PNJ, avec l'étoile (rouge) et le disque du capteur (vert).
	var ct: Transform2D = _main.vp1.get_canvas_transform()
	var sc := Vector2(lightmap.get_size()) / Vector2(_main.vp1.size)
	var cl := (ct * regarde) * sc
	var lx0 := clampi(int(cl.x) - DECOUPE_PX / 2, 0, maxi(0, lightmap.get_width() - DECOUPE_PX))
	var ly0 := clampi(int(cl.y) - DECOUPE_PX / 2, 0, maxi(0, lightmap.get_height() - DECOUPE_PX))
	var lcoupe := lightmap.get_region(Rect2i(lx0, ly0, DECOUPE_PX, DECOUPE_PX))
	lcoupe.resize(DECOUPE_PX * LOUPE, DECOUPE_PX * LOUPE, Image.INTERPOLATE_NEAREST)
	var lorig := Vector2(lx0, ly0)
	var vers_lm := func(p: Vector2) -> Vector2: return ((ct * p) * sc - lorig) * LOUPE
	_tracer_le_contour(lcoupe, etoile, vers_lm, Color(1, 0.1, 0.1))
	_tracer_le_contour(lcoupe, disque, vers_lm, Color(0.1, 1, 0.1))
	lcoupe.save_png("%s/%s_pnj_lightmap.png" % [_dossier, id])
	var figurants: Array = _iso.get("_figurants")
	var capteurs: Array = _iso.get("_capteurs_figurants")
	var k := figurants.find(cible)
	if k >= 0 and k < capteurs.size() and capteurs[k] != null:
		(capteurs[k] as CapteurCorps).get_texture().get_image().save_png("%s/%s_capteur.png" % [_dossier, id])


static func _tracer_le_contour(img: Image, poly: PackedVector2Array, vers: Callable, couleur: Color) -> void:
	for i in poly.size():
		var a: Vector2 = vers.call(poly[i])
		var b: Vector2 = vers.call(poly[(i + 1) % poly.size()])
		var n := int(maxf(a.distance_to(b), 1.0))
		for s in n + 1:
			var p := a.lerp(b, float(s) / float(n))
			var x := int(p.x)
			var y := int(p.y)
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, couleur)


# ---------------------------------------------------------------------------
# LE JOURNAL ET LA PLANCHE
# ---------------------------------------------------------------------------

func _drapeaux_du_jeu() -> Array:
	var sortie := []
	var args := OS.get_cmdline_args()
	for i in args.size():
		var a := String(args[i])
		if a in ["--pate", "--sans-faisceau-air", "--2d"] or a.begins_with("--led-murs-fige"):
			sortie.append(a if a != "--pate" or i + 1 >= args.size() else "%s %s" % [a, args[i + 1]])
	return sortie


func _ecrire_le_journal(debut_ms: int) -> void:
	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"banc": "planche_ombres (OM0)", "commit": _commit(),
		"date": Time.get_datetime_string_from_system(), "fenetre": [_taille.x, _taille.y],
		"correctif": _correctif, "drapeaux_du_jeu": _drapeaux_du_jeu(),
		"lacet": GameSettings.lacet_de(0), "duree_s": snappedf(float(Time.get_ticks_msec() - debut_ms) / 1000.0, 0.1),
		"refuses": _refuses, "prises": _journal}, "  "))
	f.close()


func _ecrire_la_planche_des_ombres() -> void:
	var avant := {}
	if _avant != "":
		avant = _lire_l_avant()
	var html := PackedStringArray()
	html.append("<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\"><title>Le banc des ombres</title>")
	html.append("<style>body{background:#0b0b0c;color:#eee;font:14px sans-serif;margin:16px}h2{margin:28px 0 6px}"
		+ ".rang{display:flex;flex-wrap:wrap;gap:12px}figure{margin:0}figcaption{color:#aaa;font-size:12px}"
		+ "img{width:300px;height:auto;image-rendering:pixelated;border:1px solid #333}code{color:#f3d9ad}"
		+ "table{border-collapse:collapse;margin:6px 0}td,th{border:1px solid #333;padding:3px 8px;text-align:right}</style></head><body>")
	html.append("<h1>Le banc des ombres — chantier OMBRES (OM0)</h1><p>Commit <code>%s</code>, %s, fenêtre %d×%d, correctif « %s », drapeaux du jeu : <code>%s</code>%s.</p>" % [
		_commit(), Time.get_datetime_string_from_system(), _taille.x, _taille.y, _correctif, " ".join(PackedStringArray(_drapeaux_du_jeu())),
		("" if _avant == "" else " — <b>avant</b> : <code>%s</code>" % _avant)])
	for e in _journal:
		var id := String(e["plan"])
		html.append("<h2>%s</h2>" % id)
		if e.has("refuse"):
			html.append("<p>Refusé : %s</p>" % e["refuse"])
			continue
		html.append("<p>%s</p>" % _but_de(id))
		html.append(_tableau_des_mesures(e, avant.get(id, {})))
		html.append("<div class=\"rang\">")
		for suffixe in ["pnj_iso_reperes", "pnj_iso", "pnj_lightmap", "capteur", "diff_max"]:
			if avant.has(id) and FileAccess.file_exists("%s/avant/%s_%s.png" % [_dossier, id, suffixe]):
				html.append("<figure><img src=\"avant/%s_%s.png\"><figcaption>AVANT — %s</figcaption></figure>" % [id, suffixe, suffixe])
			if FileAccess.file_exists("%s/%s_%s.png" % [_dossier, id, suffixe]):
				html.append("<figure><img src=\"%s_%s.png\"><figcaption>%s — %s</figcaption></figure>" % [id, suffixe,
					"APRÈS" if not avant.is_empty() else "ICI", suffixe])
		html.append("</div>")
	html.append("</body></html>")
	var f := FileAccess.open("%s/planche.html" % _dossier, FileAccess.WRITE)
	f.store_string("\n".join(html))
	f.close()


func _but_de(id: String) -> String:
	for p in plans():
		if String(p["id"]) == id:
			return String(p["but"])
	return ""


## Le journal d'un passage précédent, par plan ; ses images recopiées dans `<sortie>/avant/`.
func _lire_l_avant() -> Dictionary:
	var chemin := "%s/journal.json" % _avant
	if not FileAccess.file_exists(chemin):
		printerr("✗ --avant : pas de journal.json dans ", _avant)
		return {}
	var donnees = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if not donnees is Dictionary:
		printerr("✗ --avant : journal illisible")
		return {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/avant" % _dossier))
	var par_plan := {}
	for e in (donnees as Dictionary).get("prises", []):
		var id := String((e as Dictionary).get("plan", ""))
		par_plan[id] = e
		for suffixe in ["pnj_iso_reperes", "pnj_iso", "pnj_lightmap", "capteur", "diff_max"]:
			var src := "%s/%s_%s.png" % [_avant, id, suffixe]
			if FileAccess.file_exists(src):
				DirAccess.copy_absolute(ProjectSettings.globalize_path(src),
					ProjectSettings.globalize_path("%s/avant/%s_%s.png" % [_dossier, id, suffixe]))
	return par_plan


func _tableau_des_mesures(e: Dictionary, avant: Dictionary) -> String:
	var lignes := PackedStringArray()
	lignes.append("<table><tr><th></th>%s<th>ici</th></tr>" % ("" if avant.is_empty() else "<th>avant</th>"))
	var mesures := [
		["sonde : sol dans l'étoile ÷ dehors (côté lampe)", func(x: Dictionary) -> String: return str((x.get("sonde", {}) as Dictionary).get("rapport", "—"))],
		["sonde : derrière ÷ de côté (l'ombre reste)", func(x: Dictionary) -> String: return str((x.get("sonde", {}) as Dictionary).get("derriere_rapport", "—"))],
		["capteur du PNJ (moyenne de l'anneau)", func(x: Dictionary) -> String: return str((x.get("capteur", {}) as Dictionary).get("moyenne", "—"))],
		["capteur du PNJ, torche seule (Q42 : ne bouge pas)", func(x: Dictionary) -> String: return str(((x.get("sonde", {}) as Dictionary).get("capteur", {}) as Dictionary).get("moyenne", "—"))],
		["opacité des PNJ", func(x: Dictionary) -> String: return str(x.get("opacites", "—"))],
		["éblouissement de J1 (source)", func(x: Dictionary) -> String: return "%s (%s)" % [str(x.get("eblouissement_j1", "—")), str(x.get("source_eblouissante", ""))]],
		["lumières : pire quadrant / 15", func(x: Dictionary) -> String: return str((x.get("lumieres", {}) as Dictionary).get("pire_quadrant", "—"))],
		["scintillement écran >8 (min, max)", func(x: Dictionary) -> String: return str(((x.get("scintillement", {}) as Dictionary).get("resume", {}) as Dictionary).get("ecran", {}).get("au_dela_8", "—")) if x.has("scintillement") else "—"],
		["scintillement écran hors des corps >8 (min, max)", func(x: Dictionary) -> String: return str(((x.get("scintillement", {}) as Dictionary).get("resume", {}) as Dictionary).get("ecran", {}).get("hors_corps_8", "—")) if x.has("scintillement") else "—"],
		["scintillement écran hors des corps >24 (min, max)", func(x: Dictionary) -> String: return str(((x.get("scintillement", {}) as Dictionary).get("resume", {}) as Dictionary).get("ecran", {}).get("hors_corps_24", "—")) if x.has("scintillement") else "—"],
		["scintillement écran >24 (min, max)", func(x: Dictionary) -> String: return str(((x.get("scintillement", {}) as Dictionary).get("resume", {}) as Dictionary).get("ecran", {}).get("au_dela_24", "—")) if x.has("scintillement") else "—"],
		["saut max écran", func(x: Dictionary) -> String: return str(((x.get("scintillement", {}) as Dictionary).get("resume", {}) as Dictionary).get("ecran", {}).get("saut_max", "—")) if x.has("scintillement") else "—"],
		["scintillement lightmap >8 (min, max)", func(x: Dictionary) -> String: return str(((x.get("scintillement", {}) as Dictionary).get("resume", {}) as Dictionary).get("lightmap", {}).get("au_dela_8", "—")) if x.has("scintillement") else "—"],
	]
	for m in mesures:
		var f: Callable = m[1]
		lignes.append("<tr><th>%s</th>%s<td>%s</td></tr>" % [m[0], "" if avant.is_empty() else "<td>%s</td>" % f.call(avant), f.call(e)])
	lignes.append("</table>")
	return "\n".join(lignes)
