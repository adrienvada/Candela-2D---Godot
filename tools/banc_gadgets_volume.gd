## Banc du chantier « Gadgets en volume » (GV) — FENÊTRÉ, écran scindé, vue iso, lacet 45° B (le défaut du jeu).
##
## Adrien, 2026-09-30 : « J'aimerais également que tous les gadgets (je me souviens de la fumée occultante) soient
## davantage en 3D. Là on est pris entre le graphisme BD et la 3D voxel. Il faut quelque chose de plus uniforme avec le
## nouveau graphisme. » Ce banc montre les gadgets TELS QU'ILS SONT dans la vue iso (GV0), puis la fumée en voxels à
## l'essai contre les couches d'aujourd'hui (GV1), à cadrage identique.
##
## Un seul montage pour tout : la carte d'essai des murets, écran scindé ; J1 à l'ouest du lieu, torche allumée à
## l'énergie du jeu (2,5) braquée sur lui ; J2 au sud, torche éteinte, regardant le lieu. Chaque caméra suit son joueur,
## et les deux lacets (45° pour J1, 225° pour J2) regardent le lieu de deux côtés opposés : une prise de la fenêtre donne
## les deux vues à la fois.
##
## ⚠️ **Personne n'est ébloui, et c'est une mise en scène, pas le jeu.** Au premier passage, J1 regardait le sud et J2
## s'y tenait : J2 était dans le cône, et son voile d'éblouissement couvrait la moitié des vignettes. J2 se tient donc hors
## du cône ; les gadgets posés portent `eblouit = false` (le drapeau PAR INSTANCE que le jeu prévoit) ; la fusée, une fois
## posée, passe `is_replay` — le seul moyen qu'a le jeu de dire « cette fusée n'éblouit pas » (`_sources_eblouissantes`).
## La ligne de visée et le viseur des deux joueurs sont cachés : ils traversaient chaque vignette.
##
## ## Les modes (`--mode=`)
##
## - `avant` (GV0) — les dix gadgets posés par le VRAI chemin (`GameState._do_spawn_gadget`, par J2), plus la fusée en
##   vol, au plein feu, en braise, au résidu et en panache ; chacun sous la torche de J1 (ses propres lumières gardées),
##   puis dans le noir (toutes les lumières éteintes). Deux vignettes par prise : la vue de J1 et celle de J2.
## - `nuages` (GV1) — suie, poussière et fumée de fusée à plusieurs instants de leur vie, chacun rendu trois fois dans la
##   MÊME image de jeu (temps figé) : couches d'aujourd'hui, voxels gros, voxels fins.
## - `noir` (GV1) — la preuve du noir À L'ÉCRAN : le nuage dont une moitié est sous la torche et l'autre dans le noir, pris
##   sans voxels, avec, puis sans encore (temps figé, LED coupées, corps cachés) ; un pixel noir sans le volume, sous
##   l'emprise des cubes, et allumé avec, est une fuite. Le même relevé masque COUPÉ doit en trouver quelque part (sinon le
##   zéro est vide).
## - `cout` (GV1) — couches contre voxels, sur la même scène figée (fusée posée, suie, poussière) : la SURFACE COUVERTE
##   (les fragments que rastérisent les images du nuage, comptés par le GPU, dans chaque vue de l'écran scindé), les appels
##   de dessin, les primitives et le temps d'image médian.
##
## Relevés : lignes `BANC_GV …` au journal et `releves.txt` dans le dossier des prises (`--captures <dossier>`, défaut
## `user://gadgets_volume`). Planches : `docs/iso/gadgets_volume/planche_gv.py`.
##
## Lancer dans le conteneur du cloud (pas d'écran, rendu logiciel — ROADMAP, « Le photographe dans le cloud ») :
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/banc_gadgets_volume.tscn -- \
##     --mode=avant --captures /chemin/absolu
## `--fixed-fps 60` : une image y dure 0,2 à 1 s ; sans horloge fixe, le jeu n'avancerait pas du temps qu'on croit.
extends Node

const CARTE := "res://tools/cartes/murs_bas_essai.json"
## Les dix gadgets, sous les slugs du JEU (`GameState.IMPLEMENTATIONS`) : la mine et l'ombre habitée n'ont leur voxel que
## sous ces noms-là (piège payé par ISO7 Gadgets).
const GADGETS := ["mine_magnesium", "ombre_habitee", "torche_fantome", "voile", "gresillement", "leurre",
	"nappe_braises", "poudre_contact", "cartouche_suie", "poussiere"]
## Les distances des deux joueurs au lieu, en pixels de monde : hors du nuage le plus large qu'on y pose, pour qu'aucun
## corps n'y soit effacé ni n'y creuse de masse — sauf quand on le veut.
const DISTANCE_J1 := 150.0
const DISTANCE_J2 := 200.0
const DISTANCE_FUSEE := 290.0
## L'énergie de la torche de J1 sur la prise « sous la lampe » : celle du jeu (`player.gd`, 2,5 hors grésillement). Le banc
## d'ISO7 Gadgets prenait 0,8 ; à 0,8 le cône se lit à peine dans la vue iso (premier passage de ce banc).
const ENERGIE_TORCHE := 2.5
## Le côté d'une vignette, en pixels de FENÊTRE, par sujet : les nuages sont grands (la fumée d'une fusée monte à 250 px
## de rayon, 310 px à l'écran au zoom de l'écran scindé).
const COTE_PETIT := 280.0
const COTE_NUAGE := 520.0
const COTE_FUSEE := 700.0

var _main: Node
var _ui: Node
var _iso: Node
var _dossier := ""
var _mode := "avant"
var _echecs := 0
var _releves: PackedStringArray = []
var _murs: Array = []
var _lieu := Vector2.ZERO
## La torche de J1 est-elle voulue allumée (les autres lumières du jeu s'éteignent à chaque image, elle non) ?
var _torche := false
## Les lumières PROPRES au sujet (la fusée, la torche fantôme, la mine…), gardées allumées sous la lampe.
var _lumieres_gardees: Array = []
var _volumes: IsoVolumes
## GV1, preuve du noir — vrai : les cubes des nuages sont cachés juste avant le rendu (`_avant_le_rendu`), tout le reste de
## l'image étant celui de la prise avec eux. C'est la prise « sans le volume ».
var _cacher_voxels := false
## GV1, coût — les nœuds 3D à cacher juste avant le rendu (la prise « sans les images » du compteur de fragments).
var _caches: Array = []
## GV1, noir — les nœuds 3D cachés pendant toute une preuve (les corps : voir `_noir`).
var _caches_fixes: Array = []
## Où J1 braque sa torche : sur le lieu par défaut ; décalé pour la preuve du noir (une moitié du nuage dans le noir).
var _visee := Vector2.ZERO
## Pour itérer sans refaire toute la série : `--seulement=<nuage>` (cartouche_suie, poussiere, fusee) et `--vite` (un
## instant par nuage, le nuage plein).
var _seulement := ""
var _vite := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--seulement="):
			_seulement = arg.trim_prefix("--seulement=")
		elif arg == "--vite":
			_vite = true
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	_dossier = args[i + 1] if i >= 0 and i + 1 < args.size() else ProjectSettings.globalize_path("user://gadgets_volume")
	DirAccess.make_dir_recursive_absolute(_dossier)
	# Pour cette exécution seulement : rien ne s'écrit dans settings.cfg, et l'intro ne joue pas par-dessus le duel
	# (piège « un foyer isolé est un joueur neuf »).
	GameSettings.pilotage_externe = true
	GameSettings.intro_vue = true
	GameSettings.mode_iso = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# ⚠️ Sous Xvfb sans gestionnaire de fenêtres, `window_set_size` ne retaille pas la VUE : elle resterait en 1280×720
	# pendant que tout le monde croit 1920×1080 (piège du photographe). `Window.size` la retaille sur-le-champ.
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_window().size = Vector2i(1920, 1080)
	AudioServer.set_bus_mute(0, true)
	print("=== Banc « Gadgets en volume » — mode %s ===" % _mode)
	print("  fenêtre %s, vue %s, carte vidéo %s" % [str(DisplayServer.window_get_size()), str(get_window().size),
		RenderingServer.get_video_adapter_name()])

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_main._on_replay_requested()
	# ⚠️ Le décompte dure trois secondes de JEU : sous rendu logiciel et horloge fixe, 180 images, deux à trois minutes
	# de montre. On l'abrège comme les suites le font (`countdown_left = 0,001`), une fois la manche lancée.
	if not await _attendre(func(): return _main.round_active and _main.countdown_left > 0.0, 300.0):
		_echouer("la manche n'a pas démarré")
		_finir()
		return
	_main.countdown_left = 0.001
	if not await _attendre(func(): return _main.round_active and _main.countdown_left <= 0.0, 300.0):
		_echouer("le décompte ne s'est pas fini")
		_finir()
		return
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(CARTE))
	MapData.current_map_data = MapCodec.validate(json.data as Dictionary)["data"]
	_main.rebuild_arena()
	await _images(5)
	_murs = (_main.murs_bas as Array).duplicate()
	if not await _attendre(func() -> bool:
			var p := Presentation3D.instance()
			return p != null and bool(p.get("_actif")) and bool(p.get("_scinde")), 10.0):
		_echouer("la vue iso ne s'est pas allumée en écran scindé")
		_finir()
		return
	_iso = Presentation3D.instance()
	_ui.visible = false
	var rentre := (_murs[0] as Rect2).grow(-MursBas.RETRAIT_LUMIERE)
	# Au sud du muret d'essai, sur le sol dégagé (le lieu du banc d'ISO7 Gadgets).
	_lieu = Vector2(rentre.get_center().x, rentre.end.y + 5.0 * MursBas.TUILE)
	_preparer_les_joueurs()
	print("BANC_GV lieu=%s lacets J1=%.0f J2=%.0f zoom=%s" % [str(_lieu), float(GameSettings.lacet_de(0)),
		float(GameSettings.lacet_de(1)), str(_main.get("zoom_duel") if "zoom_duel" in _main else "?")])
	_volumes = (_iso.get("_miroirs") as Node).get("volumes")
	RenderingServer.frame_pre_draw.connect(_avant_le_rendu)
	match _mode:
		"avant":
			await _avant()
		"nuages":
			await _nuages()
		"noir":
			await _noir()
		"cout":
			await _cout()
		_:
			_echouer("mode inconnu : %s" % _mode)
	_finir()


# ─── GV0 : les gadgets tels qu'ils sont ──────────────────────────────────────

func _avant() -> void:
	_placer_les_joueurs(DISTANCE_J1, DISTANCE_J2)
	await _images(90)
	for k in GADGETS.size():
		var slug: String = GADGETS[k]
		var nuage := slug in ["cartouche_suie", "poussiere"]
		if slug == "poussiere":
			# La poussière est large (168 px) : J1 et J2 hors d'elle, pour qu'aucun corps n'y soit effacé.
			_placer_les_joueurs(215.0, 215.0)
			await _images(70)
		var g := await _poser(slug, 9500 + k)
		if g == null:
			continue
		# Un nuage monte sur 12 % de sa vie : on le prend plein (2 s), comme on le voit en jeu.
		await _images(120 if nuage else 45)
		if slug == "poudre_contact":
			await _traverser(g, 90.0)
		await _prendre_les_deux("avant_%s" % slug, COTE_NUAGE if nuage else COTE_PETIT, [g])
		if slug == "mine_magnesium":
			# La mine dort sans témoin ; déclenchée, elle s'embrase 1,6 s.
			g.call("allumer")
			await _images(12)
			await _prendre_les_deux("avant_mine_embrasee", COTE_PETIT, [g])
		g.queue_free()
		await _images(4)
	# La fusée : en vol, puis posée à chaque acte, puis éteinte (le panache).
	_placer_les_joueurs(DISTANCE_FUSEE, DISTANCE_FUSEE)
	await _images(90)
	var f := await _nouvelle_fusee()
	f.set_physics_process(false)
	f.global_position = _lieu
	MursBasRendu.poser_hauteur_source(f.get_node("Halo") as Light2D, 1.2)
	await _images(20)
	await _prendre_les_deux("avant_fusee_vol", COTE_PETIT, [f])
	_poser_la_fusee(f)
	for acte: Array in [["plein_feu", 1.0], ["braise", 6.0], ["residu", 17.0]]:
		await _figer_fusee(f, float(acte[1]))
		await _prendre_les_deux("avant_fusee_%s" % String(acte[0]), COTE_FUSEE, [f], func(): f.call("forcer_age", float(acte[1])))
	await _figer_fusee(f, 6.0)
	f.call("eteindre")
	# Le panache suit sa propre horloge (`_physics_process`) : 0,6 s après l'extinction, il couvre encore.
	f.set_physics_process(true)
	await _images(36)
	f.set_physics_process(false)
	await _prendre_les_deux("avant_fusee_panache", COTE_FUSEE, [f])
	f.queue_free()
	await _images(4)


## Une fusée neuve, posée par le chemin du banc des hauteurs : le script, ses paramètres, puis le conteneur des balles
## (celui que le miroir suit, rejeu compris).
func _nouvelle_fusee() -> Node2D:
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", _lieu)
	f.set("direction", Vector2.DOWN)
	f.set("joueurs", [_main.p1, _main.p2])
	_main.bullet_container.add_child(f)
	await get_tree().process_frame
	return f


## La fusée se pose comme en jeu (`_atterrir` : sa lumière passe à l'empreinte du sol, 440 px) — `forcer_age` seul la
## laisserait à l'empreinte du vol (160 px), comme la fusée de killcam (signalé, hors périmètre). Puis `is_replay` : une
## fusée de rejeu n'éblouit personne (`_sources_eblouissantes`), et c'est tout ce que ce drapeau change une fois posée.
func _poser_la_fusee(f: Node2D) -> void:
	f.global_position = _lieu
	f.call("_atterrir")
	f.set("is_replay", true)


## Pose la fusée à l'âge demandé et l'y tient le temps que la fumée et sa lueur prennent (le rendu, pas le jeu).
func _figer_fusee(f: Node2D, age: float) -> void:
	f.set_physics_process(false)
	f.call("forcer_age", age)
	for n in 20:
		f.call("forcer_age", age)
		await RenderingServer.frame_post_draw


## J1 (la torche) marche à travers la nappe, d'un bord à l'autre, pour y laisser ses traces (la poudre relève les pas à
## chaque pas de physique, chez tous les pairs) ; puis il revient à sa place.
func _traverser(g: Node2D, rayon: float) -> void:
	var p := _main.p1 as Node2D
	var depart := p.global_position
	for n in 50:
		p.global_position = g.global_position + Vector2(-rayon - 20.0 + (2.0 * rayon + 40.0) * float(n) / 49.0, 10.0)
		await get_tree().physics_frame
	p.global_position = depart
	await _images(60)


# ─── GV1 : les nuages, couches contre voxels ─────────────────────────────────

## Les rendus comparés, dans la MÊME image de jeu : les couches d'aujourd'hui, puis les deux variantes de voxels.
const RENDUS := [["couches", false, ""], ["gros", true, "gros"], ["fin", true, "fin"]]


func _nuages() -> void:
	# La suie (9 s de vie) et la poussière (7,5 s) : la naissance (montée sur 12 % de la vie), pleine, la dissipation.
	for nuage: Array in [["cartouche_suie", [0.45, 2.5, 7.3, 8.4], COTE_NUAGE, DISTANCE_J1, DISTANCE_J2],
			["poussiere", [0.4, 2.0, 5.9, 6.9], COTE_NUAGE + 140.0, 215.0, 215.0]]:
		var slug: String = nuage[0]
		if _seulement != "" and _seulement != slug:
			continue
		if _vite:
			nuage[1] = [nuage[1][1]]
		_placer_les_joueurs(float(nuage[3]), float(nuage[4]))
		await _images(90)
		var g := await _poser(slug, 9600)
		if g == null:
			continue
		for age: float in nuage[1]:
			# L'âge est TENU à chaque image (à un pas près) : la vie du nuage est celle qu'on photographie, et sa lueur (la
			# suie s'allume en entier) suit les lumières de la prise, comme en jeu.
			g.set("_age", age)
			await _tenir_images(12, func(): g.set("_age", age))
			await _prendre_rendus("gv1_%s_%04.1f" % [slug, age], float(nuage[2]), [g], func(): g.set("_age", age))
		g.queue_free()
		await _images(4)
	# La fumée de la fusée : la montée au plein feu, pleine à la braise, un corps qui la traverse (sillage et masse), le
	# résidu qui se dissipe, le panache noir de l'extinction.
	if _seulement != "" and _seulement != "fusee":
		return
	_placer_les_joueurs(DISTANCE_FUSEE, DISTANCE_FUSEE)
	await _images(90)
	var f := await _nouvelle_fusee()
	f.set_physics_process(false)
	_poser_la_fusee(f)
	for acte: Array in ([["2_braise", 6.0]] if _vite else [["1_plein_feu", 1.0], ["2_braise", 6.0], ["4_residu", 17.0]]):
		var age: float = acte[1]
		await _figer_fusee(f, age)
		await _prendre_rendus("gv1_fusee_%s" % String(acte[0]), COTE_FUSEE, [f], func(): f.call("forcer_age", age))
		if String(acte[0]) == "2_braise":
			var final := await _traversee(f)
			await _prendre_rendus("gv1_fusee_3_sillage", COTE_FUSEE, [f], func(): f.call("forcer_age", final))
			_placer_les_joueurs(DISTANCE_FUSEE, DISTANCE_FUSEE)
			await _images(60)
	if not _vite:
		await _figer_fusee(f, 6.0)
		await _panache(f, 0.5)
		await _prendre_rendus("gv1_fusee_5_panache", COTE_FUSEE, [f])
	f.queue_free()
	await _images(4)


## J2 traverse la fumée d'est en ouest, à l'allure d'une course, et s'arrête dedans : le voile creuse son sillage (des
## trous qui se referment en 2 s) et pose sa masse sur lui. L'horloge de la fusée court pendant la traversée (le sillage
## s'échantillonne tous les quarts de seconde), puis s'arrête : rend l'âge où elle est figée.
func _traversee(f: Node2D) -> float:
	var p := _main.p2 as Node2D
	f.set_physics_process(true)
	for k in 48:
		p.global_position = f.global_position + Vector2(170.0 - 5.0 * float(k), 40.0)
		await get_tree().physics_frame
	f.set_physics_process(false)
	var age := float(f.call("age_combustion"))
	await _tenir_images(10, func(): f.call("forcer_age", age))
	_releve("traversee age=%.2f trous=%d masses=%d" % [age,
		int(((f.get_node("Voile") as Sprite2D).material as ShaderMaterial).get_shader_parameter("nb_trous")),
		int(((f.get_node("Voile") as Sprite2D).material as ShaderMaterial).get_shader_parameter("nb_masses"))])
	return age


## Éteint la fusée et laisse courir l'horloge de son panache `apres` secondes, puis le fige.
func _panache(f: Node2D, apres: float) -> void:
	f.call("eteindre")
	f.set_physics_process(true)
	for k in roundi(apres * 60.0):
		await get_tree().physics_frame
	f.set_physics_process(false)
	await _images(4)


## Les trois rendus d'une même image de jeu, sous la lampe puis dans le noir, dans les deux vues.
func _prendre_rendus(nom: String, cote: float, sujets: Array, tenir := Callable()) -> void:
	for lumiere in ["lampe", "noir"]:
		_torche = lumiere == "lampe"
		_lumieres_gardees = _lumieres_des(sujets) if _torche else []
		# Dans le noir, une seconde : la lueur de la suie (lissée sur 0,1 s) retombe, comme en jeu.
		await _tenir_images(30 if _torche else 60, tenir)
		for rendu: Array in RENDUS:
			_volumes.poser_fumee_voxel(bool(rendu[1]), String(rendu[2]))
			await _tenir_images(5, tenir)
			var img := get_viewport().get_texture().get_image()
			for pid in 2:
				var c := _recadrer(img, _lieu, pid, cote)
				_sauver(c, "%s_%s_%s_j%d" % [nom, lumiere, String(rendu[0]), pid + 1])
				_releve("prise=%s lumiere=%s rendu=%s vue=J%d max=%d moy=%.1f allumes=%d" % [nom, lumiere, String(rendu[0]),
					pid + 1, _valeur_max(c), _moyenne(c), _allumes(c, 0)])
	_volumes.poser_fumee_voxel(false)
	_torche = false
	_lumieres_gardees = []


# ─── GV1 : la preuve du noir À L'ÉCRAN ───────────────────────────────────────

## Pour chaque nuage et chaque variante, le nuage à moitié sous la torche de J1, l'autre moitié dans le noir (toutes les
## autres lumières éteintes, LED comprises, l'âge tenu, les deux corps cachés). Trois prises à la suite : A sans les cubes,
## B avec, A' sans encore (`_cacher_voxels` les retire juste avant le rendu : tout le reste de l'image est celui de B, juge
## compris), puis l'EMPRISE des cubes (`_emprise`). Un pixel STABLE (A = A') et NOIR (0 sur les trois canaux) dans A, sous
## l'emprise des cubes, que B allume, est une FUITE. La même prise masque COUPÉ (le juge retiré) doit en trouver quelque
## part : sinon le zéro serait vide (piège du 2026-09-24, « un zéro doit être vérifié non vide »).
func _noir() -> void:
	# Où J1 braque sa torche, par rapport au centre du nuage. ⚠️ Pour que la preuve puisse trouver une fuite, le cône doit
	# TRAVERSER le nuage : un cube se dessine plus haut que son pied (vers le nord-ouest dans la vue de J1, le sud-est dans
	# celle de J2), et ne peut allumer un pixel noir qu'au bord d'une lumière qui a du noir de ce côté-là. Au premier passage,
	# le cône rasait le bord nord du nuage : masque coupé, pas une fuite nulle part — une preuve vide. La suie s'allume en
	# entier dès qu'une lumière la touche (sa lueur) : son cas ne peut rien prouver du masque, il prouve seulement qu'elle
	# n'allume rien.
	var cas := [
		["cartouche_suie", 2.5, Vector2(0.0, -70.0), DISTANCE_J1, DISTANCE_J2],
		["poussiere", 2.0, Vector2(0.0, -20.0), 215.0, 215.0],
		["fusee_panache", 0.35, Vector2(0.0, -20.0), DISTANCE_FUSEE, DISTANCE_FUSEE],
		["fusee_braise_lumiere_coupee", 6.0, Vector2(0.0, -20.0), DISTANCE_FUSEE, DISTANCE_FUSEE],
	]
	# Les deux corps, cachés pendant toute la preuve : la silhouette de soi est tramée d'une image à l'autre, et ses pixels
	# passaient pour des fuites (premier passage : 4 et 48 « fuites », toutes sur le corps de J1, loin du nuage). Un corps se
	# dessine APRÈS les cubes : le cacher ne peut que découvrir des pixels, jamais en masquer une fuite.
	_caches_fixes = []
	for corps in (_iso.get("_corps") as Array):
		_caches_fixes.append(corps)
	var total_sans_masque := 0
	var total_temoin := 0
	for c: Array in cas:
		var nom: String = c[0]
		_placer_les_joueurs(float(c[3]), float(c[4]))
		_visee = _lieu + (c[2] as Vector2)
		await _images(90)
		var sujet: Node2D
		var tenir := Callable()
		if nom.begins_with("fusee"):
			sujet = await _nouvelle_fusee()
			sujet.set_physics_process(false)
			_poser_la_fusee(sujet)
			await _figer_fusee(sujet, 6.0)
			if nom == "fusee_panache":
				await _panache(sujet, float(c[1]))
			else:
				var f := sujet
				tenir = func(): f.call("forcer_age", 6.0)
		else:
			sujet = await _poser(nom, 9650)
			if sujet == null:
				continue
			var g := sujet
			var age := float(c[1])
			tenir = func(): g.set("_age", age)
		# La torche seule : la lumière propre du sujet reste éteinte (pour la fusée, c'est ce qui rend la preuve possible —
		# sa lumière éclaire tout son nuage, et il n'y aurait plus de noir derrière lui).
		_torche = true
		_lumieres_gardees = []
		await _tenir_images(40, tenir)
		# LA RÉFÉRENCE : les couches d'aujourd'hui, sous le même juge et la même mesure — ce que le jeu fait déjà. Un résidu
		# des cubes se lit contre le leur.
		_volumes.poser_fumee_voxel(false)
		await _tenir_images(6, tenir)
		var couches: Array = _noeuds_du_nuage(sujet)["images"]
		var avec_couches := await _sandwich(tenir, couches)
		var emprise_couches := await _emprise(tenir, couches)
		var residus_couches := [0, 0]
		for pid in 2:
			var cote := COTE_FUSEE if nom.begins_with("fusee") else COTE_NUAGE + 140.0
			var m := _fuites(avec_couches, pid, cote, emprise_couches)
			residus_couches[pid] = int(m["fuites"])
			_releve("noir cas=%s variante=couches vue=J%d noirs=%d emprise=%d noirs_dessous=%d instables=%d fuites=%d fuites_sup2=%d fuites_sup8=%d" % [
				nom, pid + 1, m["noirs"], m["emprise"], m["noirs_emprise"], m["instables"], m["fuites"], m["fuites_2"],
				m["fuites_8"]])
			_sauver(m["b"], "noir_%s_couches_avec_j%d" % [nom, pid + 1])
			_sauver(m["a"], "noir_%s_couches_sans_j%d" % [nom, pid + 1])
			_sauver(m["carte"], "noir_%s_couches_fuites_j%d" % [nom, pid + 1])
		for variante in ["gros", "fin"]:
			_volumes.poser_fumee_voxel(true, variante)
			await _tenir_images(6, tenir)
			var avec := await _sandwich(tenir)
			var emprise := await _emprise(tenir)
			_volumes.poser_masque_fumee(false)
			await _tenir_images(4, tenir)
			var sans_masque := await _sandwich(tenir)
			_volumes.poser_masque_fumee(true)
			await _tenir_images(4, tenir)
			for pid in 2:
				var cote := COTE_FUSEE if nom.begins_with("fusee") else COTE_NUAGE + 140.0
				var m := _fuites(avec, pid, cote, emprise)
				var s := _fuites(sans_masque, pid, cote, emprise)
				# LE TÉMOIN : les mêmes prises, B remplacée par l'emprise — des cubes qui ajouteraient de la lumière partout,
				# noir compris. Le détecteur doit y voir une fuite sur chaque pixel noir sous les cubes : c'est ce qui prouve
				# qu'un zéro, plus haut, n'est pas un zéro d'aveugle.
				var t := _fuites([avec[0], emprise, avec[2]], pid, cote, emprise)
				total_sans_masque += int(s["fuites_2"])
				total_temoin += int(t["fuites_2"])
				_releve("noir cas=%s variante=%s vue=J%d noirs=%d emprise=%d noirs_dessous=%d instables=%d fuites=%d fuites_sup2=%d fuites_sup8=%d | masque_coupe: fuites=%d fuites_sup2=%d fuites_sup8=%d | temoin: fuites_sup2=%d" % [
					nom, variante, pid + 1, m["noirs"], m["emprise"], m["noirs_emprise"], m["instables"], m["fuites"],
					m["fuites_2"], m["fuites_8"], s["fuites"], s["fuites_2"], s["fuites_8"], t["fuites_2"]])
				_sauver(m["b"], "noir_%s_%s_avec_j%d" % [nom, variante, pid + 1])
				_sauver(m["a"], "noir_%s_%s_sans_j%d" % [nom, variante, pid + 1])
				_sauver(s["b"], "noir_%s_%s_masque_coupe_j%d" % [nom, variante, pid + 1])
				_sauver(s["carte"], "noir_%s_%s_masque_coupe_fuites_j%d" % [nom, variante, pid + 1])
				if int(m["fuites"]) > 0:
					_sauver(m["carte"], "noir_%s_%s_fuites_j%d" % [nom, variante, pid + 1])
				if int(m["emprise"]) == 0:
					_echouer("%s %s J%d : les cubes n'ont rien rastérisé — la preuve serait vide" % [nom, variante, pid + 1])
				# LE CRITÈRE : aucune fuite au-delà de 2/255. Les résidus à 1-2/255 viennent du juge du masque (Q31), qui
				# tranche au pixel au bord d'une lumière faible : les couches d'aujourd'hui les ont aussi, au même endroit et
				# en nombre comparable (premier passage : 18 pour les couches, 6 à 9 pour les cubes) — le relevé les donne
				# côte à côte (`couches=`), sans en faire un échec : leur compte bouge d'une image à l'autre.
				_releve("noir residus cas=%s variante=%s vue=J%d cubes=%d couches=%d" % [nom, variante, pid + 1, m["fuites"],
					residus_couches[pid]])
				if int(m["fuites_2"]) > 0:
					_echouer("%s %s J%d : %d fuites au-delà de 2/255 (pixels noirs allumés par les cubes)" % [nom, variante,
						pid + 1, m["fuites_2"]])
		_volumes.poser_fumee_voxel(false)
		_torche = false
		_visee = Vector2.ZERO
		sujet.queue_free()
		await _images(4)
	_caches_fixes = []
	# Un zéro doit être vérifié non vide (piège du 2026-09-24). Le TÉMOIN le vérifie : des cubes qui ajouteraient de la
	# lumière partout sont vus en fuite sur chaque pixel noir sous eux. Le masque COUPÉ, lui, est relevé pour ce qu'il dit :
	# ce que le pochoir retire en plus du noir au pied (au bord d'une lumière dure — un mur —, pas au bord doux d'un cône).
	_releve("noir total_masque_coupe_fuites_sup2=%d total_temoin_fuites_sup2=%d" % [total_sans_masque, total_temoin])
	if total_temoin == 0:
		_echouer("le témoin ne montre aucune fuite : le détecteur serait aveugle, la preuve vide")


## L'EMPRISE des cubes : la même image de jeu, les cubes dessinés au COMPTEUR (sans pochoir, en addition : voir `_compteur`).
## Là où elle monte par rapport à la prise sans eux, un cube a été rastérisé — y compris au-dessus du noir, où le vrai
## shader est refusé par le pochoir. Une fuite ne se compte que là.
func _emprise(tenir: Callable, noeuds: Array = []) -> Image:
	var origines := {}
	var cibles: Array = noeuds.duplicate()
	if cibles.is_empty():
		for n in _volumes.get_children():
			if n is MultiMeshInstance3D and not n.is_queued_for_deletion():
				cibles.append(n)
	for n in cibles:
		var gi := n as GeometryInstance3D
		origines[gi] = gi.material_override
		gi.material_override = _materiau_compteur(gi.material_override as ShaderMaterial)
	await _tenir_images(3, tenir)
	var img := get_viewport().get_texture().get_image()
	for gi in origines:
		(gi as GeometryInstance3D).material_override = origines[gi]
	await _tenir_images(3, tenir)
	return img


## A, B, A' : trois images de la même partie, sans les cubes, avec, sans encore. `images` : d'autres nœuds à retirer à la
## place des cubes (les couches de la référence), cachés juste avant le rendu comme eux.
func _sandwich(tenir: Callable, images: Array = []) -> Array:
	var out := []
	for cacher in [true, false, true]:
		if images.is_empty():
			_cacher_voxels = cacher
		else:
			_caches = images if cacher else []
		await _tenir_images(3, tenir)
		out.append(get_viewport().get_texture().get_image())
	_cacher_voxels = false
	_caches = []
	return out


## Les fuites d'un sandwich dans la vue `pid`, sous l'emprise des cubes : pixels stables et noirs sans les cubes, que les cubes
## rastérisent (`emprise` plus clair que A), allumés avec. Rend aussi une carte (rouge : fuite ; gris : pixel noir stable ;
## bleu : instable ; vert sombre : noir stable sous l'emprise) et les comptes.
func _fuites(images: Array, pid: int, cote: float, emprise: Image) -> Dictionary:
	var a := _recadrer(images[0], _lieu, pid, cote)
	var b := _recadrer(images[1], _lieu, pid, cote)
	var a2 := _recadrer(images[2], _lieu, pid, cote)
	var e := _recadrer(emprise, _lieu, pid, cote)
	for im in [a, b, a2, e]:
		(im as Image).convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var db := b.get_data()
	var da2 := a2.get_data()
	var de := e.get_data()
	var carte := Image.create_empty(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8)
	var dc := carte.get_data()
	var noirs := 0
	var sous := 0
	var noirs_sous := 0
	var instables := 0
	var fuites := 0
	var fuites_2 := 0
	var fuites_8 := 0
	for k in range(0, mini(mini(da.size(), db.size()), mini(da2.size(), de.size())), 3):
		var dans := de[k] > da[k] or de[k + 1] > da[k + 1] or de[k + 2] > da[k + 2]
		if dans:
			sous += 1
		var stable := da[k] == da2[k] and da[k + 1] == da2[k + 1] and da[k + 2] == da2[k + 2]
		if not stable:
			instables += 1
			dc[k + 2] = 200
			continue
		if da[k] == 0 and da[k + 1] == 0 and da[k + 2] == 0:
			noirs += 1
			if not dans:
				dc[k] = 60
				dc[k + 1] = 60
				dc[k + 2] = 60
				continue
			noirs_sous += 1
			var m := maxi(db[k], maxi(db[k + 1], db[k + 2]))
			if m > 0:
				fuites += 1
				dc[k] = 255
				if m > 2:
					fuites_2 += 1
				if m > 8:
					fuites_8 += 1
			else:
				dc[k + 1] = 90
	carte.set_data(carte.get_width(), carte.get_height(), false, Image.FORMAT_RGB8, dc)
	return {"a": a, "b": b, "carte": carte, "noirs": noirs, "emprise": sous, "noirs_emprise": noirs_sous,
		"instables": instables, "fuites": fuites, "fuites_2": fuites_2, "fuites_8": fuites_8}


# ─── GV1 : le coût ───────────────────────────────────────────────────────────

## LE COÛT, sur la même scène figée pour tous les rendus (le sujet à son âge, les deux corps immobiles, les caméras posées,
## les LED coupées) : une fusée posée à la braise, une suie pleine, une poussière pleine, en écran scindé.
##
## 1. **La surface couverte** — ce que les images du nuage font RASTÉRISER, vue par vue : chaque fragment de ses couches (ou
##    de ses cubes) et de son juge compté par le GPU (`_surface`). C'est le coût de remplissage, celui qu'un GPU à tuiles
##    paie : les voxels ne coûtent presque rien en appels de dessin, ils paient en surface (piège transmis par ISO7).
## 2. **Le temps d'image** — médiane et 9ᵉ décile de 60 images sous la lampe : sans le nuage (ses images cachées), avec
##    les couches, avec chaque variante de voxels, deux tours entrelacés (la dérive d'un conteneur partagé se voit d'un tour
##    à l'autre) ; les appels de dessin et les primitives de l'image.
##
## ⚠️ Rendu LOGICIEL (llvmpipe) : le temps mesure un processeur qui rastérise, sur des cœurs que d'autres sessions
## partagent ; seuls l'ordre et les rapports, pris sur la même scène à quelques secondes d'écart, disent quelque chose. La
## surface et les appels, eux, ne dépendent pas de la machine : ce sont les mêmes sur tout GPU.
func _cout() -> void:
	await _etalonner()
	for scene: String in ["fusee", "suie", "poussiere"]:
		if _seulement != "" and _seulement != scene and not (_seulement == "cartouche_suie" and scene == "suie"):
			continue
		var sujet: Node2D
		var tenir := Callable()
		if scene == "fusee":
			_placer_les_joueurs(DISTANCE_FUSEE, DISTANCE_FUSEE)
			await _images(60)
			sujet = await _nouvelle_fusee()
			sujet.set_physics_process(false)
			_poser_la_fusee(sujet)
			var f := sujet
			tenir = func(): f.call("forcer_age", 6.0)
		else:
			var poussiere: bool = scene == "poussiere"
			_placer_les_joueurs(215.0 if poussiere else DISTANCE_J1, 215.0 if poussiere else DISTANCE_J2)
			await _images(60)
			sujet = await _poser("poussiere" if poussiere else "cartouche_suie", 9680 + (1 if poussiere else 0))
			if sujet == null:
				continue
			var g := sujet
			var age := 2.0 if poussiere else 2.5
			tenir = func(): g.set("_age", age)
		_torche = true
		_lumieres_gardees = _lumieres_des([sujet])
		await _tenir_images(40, tenir)
		# 1. La surface couverte, rendu par rendu.
		for rendu: Array in RENDUS:
			_volumes.poser_fumee_voxel(bool(rendu[1]), String(rendu[2]))
			await _tenir_images(10, tenir)
			var mesure := await _surface(sujet, tenir)
			for pid in 2:
				var m: Dictionary = mesure[pid]
				_releve("surface scene=%s rendu=%s vue=J%d fragments=%d images=%d juge=%d empreinte=%d aire_couches=%d cubes=%d histogramme=%s" % [
					scene, String(rendu[0]), pid + 1, int(m["images"]) + int(m["juge"]), m["images"], m["juge"], m["empreinte"],
					m["aire_couches"], _cubes(), str(m["histogramme"]).replace(" ", "")])
				if int(m["images"]) <= 0:
					_echouer("%s %s J%d : le compteur n'a rien compté — la mesure serait vide" % [scene, String(rendu[0]), pid + 1])
				if String(rendu[0]) == "couches" and int(m["aire_couches"]) > 0:
					# Le compteur, vérifié sur ce qu'on sait calculer : l'aire des quads des couches, projetés par la caméra.
					var rapport := float(m["images"]) / float(m["aire_couches"])
					_releve("compteur scene=%s vue=J%d mesure/aire=%.3f" % [scene, pid + 1, rapport])
					if absf(rapport - 1.0) > 0.1:
						_echouer("%s J%d : le compteur s'écarte de %.0f %% de l'aire des couches" % [scene, pid + 1,
							absf(rapport - 1.0) * 100.0])
		# 2. Le temps d'image, sous la lampe.
		_torche = true
		_lumieres_gardees = _lumieres_des([sujet])
		await _tenir_images(30, tenir)
		for tour in 2:
			for rendu: Array in [["sans_le_nuage", false, ""]] + RENDUS:
				_volumes.poser_fumee_voxel(bool(rendu[1]), String(rendu[2]))
				await _tenir_images(20, tenir)
				# La référence : la même image sans le nuage — ses couches et son juge cachés juste avant chaque rendu, tout le
				# reste (les autres images de la présentation, la lightmap) inchangé.
				if String(rendu[0]) == "sans_le_nuage":
					var n := _noeuds_du_nuage(sujet)
					_caches = n["images"] + n["juges"]
				var mesure := await _mesurer(60, tenir)
				_caches = []
				_releve("cout scene=%s tour=%d rendu=%s appels=%d primitives=%d image_ms_mediane=%.1f image_ms_p90=%.1f cubes=%d" % [
					scene, tour + 1, String(rendu[0]), mesure["appels"], mesure["primitives"], mesure["mediane"],
					mesure["p90"], _cubes()])
		_volumes.poser_fumee_voxel(false)
		_torche = false
		_lumieres_gardees = []
		sujet.queue_free()
		await _images(4)


## La couleur que le compteur AJOUTE à chaque fragment. ⚠️ **Ce qu'elle devient à l'écran ne se devine pas** : mesuré
## (2026-09-30, `gl_compatibility` sous llvmpipe, vue 3D à anticrénelage 4×), un fragment écrit 0,5 ajoute bien 128/255,
## mais 0,05 n'ajoute que 7,5/255, 0,03 un seul, et 0,025 rien du tout — un pied non linéaire sous 0,3, alors que
## l'accumulation, elle, est exactement linéaire (7,5 · n pour n = 1 à 8 fragments). Le premier compteur, qui supposait la
## pente sRGB (2/255/12,92), ne comptait rien. D'où l'ÉTALON (`_etalonner`) : l'unité est lue sur place, dans les vues du
## jeu, sur un carré d'aire connue ; 0,04 en donne ~4 par fragment, soit ~60 fragments par pixel avant de saturer.
const COULEUR_COMPTEUR := 0.04
static var _compteurs := {}
## L'unité étalonnée, par vue : ce qu'un fragment du compteur ajoute au rouge (en 1/255).
var _unites: Array = [0.0, 0.0]


## LE COMPTEUR : la copie d'un shader de nuage (couches, juge ou cubes) dont chaque fragment AJOUTE `COULEUR_COMPTEUR` —
## même sommet (les cubes gardent leur taille, les couches leur quad), sans pochoir (on compte ce qui est rastérisé,
## avant le test du masque), sans `discard` (un fragment jeté a été rastérisé et ombré jusque-là), profondeur lue comme
## l'original (un fragment caché par un mur est rejeté tôt, comme en jeu). Une chirurgie de texte faite ICI, au banc : aucun
## shader du jeu ne porte de quoi compter.
static func _compteur(s: Shader) -> Shader:
	if _compteurs.has(s):
		return _compteurs[s]
	var code := s.code
	code = RegEx.create_from_string("render_mode[^;]*;").sub(code,
		"render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;", true)
	code = RegEx.create_from_string("stencil_mode[^;]*;").sub(code, "", true)
	code = code.replace("discard;", "{}")
	var debut := code.find("{", code.find("void fragment()"))
	var profondeur := 0
	var k := debut
	while k < code.length():
		if code[k] == "{":
			profondeur += 1
		elif code[k] == "}":
			profondeur -= 1
			if profondeur == 0:
				break
		k += 1
	code = code.substr(0, k) + "\tALBEDO = vec3(%.9f);\n\tALPHA = 1.0;\n" % COULEUR_COMPTEUR + code.substr(k)
	var c := Shader.new()
	c.code = code
	_compteurs[s] = c
	return c


static func _materiau_compteur(m: ShaderMaterial) -> ShaderMaterial:
	var c := ShaderMaterial.new()
	c.shader = _compteur(m.shader)
	c.render_priority = m.render_priority
	for u in m.shader.get_shader_uniform_list():
		var nom := String(u["name"])
		c.set_shader_parameter(nom, m.get_shader_parameter(nom))
	return c


## Les nœuds 3D des images d'un nuage : ses couches ou ses cubes, et son juge (celui du masque de la fumée).
func _noeuds_du_nuage(sujet: Object) -> Dictionary:
	var images := []
	var juges := []
	for e: Dictionary in (_volumes.get("_suivis") as Dictionary).values():
		if not ["volume", "fumee", "nuage_voxel"].has(String(e["genre"])):
			continue
		if (e["source"] as WeakRef).get_ref() != sujet:
			continue
		for n in e["noeuds"]:
			if is_instance_valid(n) and (n as Node3D).visible:
				images.append(n)
		if is_instance_valid(e.get("juge")) and (e["juge"] as Node3D).visible:
			juges.append(e["juge"])
	return {"images": images, "juges": juges}


## LA SURFACE COUVERTE par les images d'un nuage, dans chaque vue : dans le noir (le compteur ajoute sur du noir, rien ne
## sature), la prise sans les images du nuage, puis ses images (sans le juge) au compteur, puis son juge seul au compteur.
## Les fragments = la somme des écarts / l'unité, au pixel près des bords (l'anticrénelage y compte la part couverte) ;
## l'empreinte = les pixels touchés au moins une fois ; l'aire des couches = leurs quads projetés par la caméra de la vue,
## bornés à la vue (le contrôle du compteur).
func _surface(sujet: Node, tenir: Callable) -> Array:
	var torche := _torche
	var gardees := _lumieres_gardees
	_torche = false
	_lumieres_gardees = []
	await _tenir_images(40, tenir)
	var noeuds := _noeuds_du_nuage(sujet)
	var tous: Array = noeuds["images"] + noeuds["juges"]
	_caches = tous
	await _tenir_images(4, tenir)
	var base := _images_des_vues()
	var comptes := []
	for passe in ["images", "juges"]:
		var comptes_passe: Array = noeuds[passe]
		_caches = tous.filter(func(n): return not comptes_passe.has(n))
		var origines := {}
		for n in comptes_passe:
			var gi := n as GeometryInstance3D
			origines[gi] = gi.material_override
			gi.material_override = _materiau_compteur(gi.material_override as ShaderMaterial)
		await _tenir_images(4, tenir)
		comptes.append(_images_des_vues())
		for gi in origines:
			(gi as GeometryInstance3D).material_override = origines[gi]
	_caches = []
	_torche = torche
	_lumieres_gardees = gardees
	var out := []
	for pid in 2:
		var images := _ecarts(base[pid], comptes[0][pid], _unites[pid])
		var juge := _ecarts(base[pid], comptes[1][pid], _unites[pid])
		out.append({"images": images["fragments"], "juge": juge["fragments"], "empreinte": images["empreinte"],
			"histogramme": images["histogramme"], "aire_couches": _aire_des_couches(noeuds["images"], pid)})
	return out


## L'ÉTALON : un carré de 90 px de monde posé à plat à 2 px du sol, au lieu du banc (sol dégagé, aucun mur devant), dessiné
## au compteur dans le noir ; l'unité d'une vue = la somme des écarts / l'aire du carré projeté par sa caméra. Le mode des
## écarts à l'intérieur du carré (un seul fragment par pixel) doit la redire.
func _etalonner() -> void:
	_placer_les_joueurs(DISTANCE_J1, DISTANCE_J2)
	_torche = false
	_lumieres_gardees = []
	await _tenir_images(90, Callable())
	var carre := MeshInstance3D.new()
	carre.name = "EtalonCompteur"
	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE
	carre.mesh = plan
	carre.scale = Vector3(90.0, 1.0, 90.0)
	carre.position = Vector3(_lieu.x, 2.0, _lieu.y)
	carre.layers = 1
	carre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;\nvoid fragment() {\n\tALBEDO = vec3(%.9f);\n\tALPHA = 1.0;\n}\n" % COULEUR_COMPTEUR
	var mat := ShaderMaterial.new()
	mat.shader = sh
	carre.material_override = mat
	(_volumes.get_parent() as Node).add_child(carre)
	_caches = [carre]
	await _tenir_images(4, Callable())
	var base := _images_des_vues()
	_caches = []
	# Personne d'autre ne le rallume : les images d'un nuage, elles, sont reposées visibles par la présentation à chaque image.
	carre.visible = true
	await _tenir_images(4, Callable())
	var avec := _images_des_vues()
	for pid in 2:
		var aire := float(_aire_des_couches([carre], pid))
		var e := _ecarts(base[pid], avec[pid], 1.0)
		_unites[pid] = float(e["fragments"]) / maxf(aire, 1.0)
		var mode := 0
		var h: Array = e["histogramme_brut"]
		for k in h.size():
			if int(h[k]) > int(h[mode]):
				mode = k
		_releve("etalon vue=J%d aire=%d somme=%d unite=%.3f mode_des_ecarts=%d" % [pid + 1, roundi(aire), e["fragments"],
			_unites[pid], mode])
		if aire < 1000.0 or _unites[pid] < 1.0 or absf(float(mode) - _unites[pid]) > 1.0:
			_echouer("J%d : l'étalon du compteur est illisible (aire %d, unité %.2f, mode %d)" % [pid + 1, roundi(aire),
				_unites[pid], mode])
	carre.queue_free()
	await _images(2)


func _images_des_vues() -> Array:
	var out := []
	for v in (_iso.get("_vues3d") as Array):
		var img := (v as SubViewport).get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		out.append(img)
	return out


## Les fragments comptés entre deux prises (le rouge ; `unite` : ce qu'ajoute un fragment), l'empreinte (les pixels touchés
## au moins une fois), la PROFONDEUR de peinture (combien de pixels ont reçu 1, 2, … 8 fragments et plus) et l'histogramme
## brut des écarts (0 à 32, pour l'étalon).
static func _ecarts(a: Image, b: Image, unite: float) -> Dictionary:
	var da := a.get_data()
	var db := b.get_data()
	var somme := 0
	var empreinte := 0
	var profondeur := PackedInt32Array()
	profondeur.resize(9)
	var brut := PackedInt32Array()
	brut.resize(33)
	var u := maxf(unite, 0.001)
	for k in range(0, mini(da.size(), db.size()), 3):
		var d := int(db[k]) - int(da[k])
		if d <= 0:
			continue
		somme += d
		brut[mini(d, 32)] += 1
		if float(d) * 2.0 >= u:
			empreinte += 1
			profondeur[clampi(roundi(float(d) / u), 1, 8)] += 1
	return {"fragments": roundi(float(somme) / u), "empreinte": empreinte,
		"histogramme": Array(profondeur).slice(1), "histogramme_brut": Array(brut)}


## L'aire, en pixels de la vue `pid`, des quads des couches projetés par sa caméra et bornés à la vue. 0 pour des cubes.
func _aire_des_couches(noeuds: Array, pid: int) -> int:
	var cam := _iso.call("_camera_de", pid) as Camera3D
	var vue := (_iso.get("_vues3d") as Array)[pid] as SubViewport
	if cam == null:
		return 0
	var cadre := PackedVector2Array([Vector2.ZERO, Vector2(vue.size.x, 0), Vector2(vue.size), Vector2(0, vue.size.y)])
	var aire := 0.0
	for n in noeuds:
		if not (n is MeshInstance3D):
			return 0
		var mi := n as MeshInstance3D
		var poly := PackedVector2Array()
		for coin in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]:
			poly.append(cam.unproject_position(mi.global_transform * coin))
		for morceau in Geometry2D.intersect_polygons(poly, cadre):
			aire += absf(_aire_polygone(morceau))
	return roundi(aire)


static func _aire_polygone(p: PackedVector2Array) -> float:
	var a := 0.0
	for k in p.size():
		a += p[k].cross(p[(k + 1) % p.size()])
	return a * 0.5


func _mesurer(n: int, tenir: Callable) -> Dictionary:
	var durees: Array = []
	var appels: Array = []
	var primitives: Array = []
	var avant := Time.get_ticks_usec()
	for k in n:
		if tenir.is_valid():
			tenir.call()
		_eteindre_tout()
		await RenderingServer.frame_post_draw
		var t := Time.get_ticks_usec()
		durees.append(float(t - avant) / 1000.0)
		avant = t
		appels.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	durees.sort()
	appels.sort()
	primitives.sort()
	return {"mediane": durees[durees.size() / 2], "p90": durees[int(durees.size() * 0.9)],
		"appels": appels[appels.size() / 2], "primitives": primitives[primitives.size() / 2]}


## Le nombre de cubes que portent les grilles visibles (les deux vues).
func _cubes() -> int:
	var n := 0
	for c in _volumes.get_children():
		if c is MultiMeshInstance3D and not c.is_queued_for_deletion() and (c as MultiMeshInstance3D).multimesh != null:
			n += (c as MultiMeshInstance3D).multimesh.instance_count
	return n


## Juste avant le rendu : les cubes cachés pour la prise « sans le volume » de la preuve du noir. Rien d'autre ne change.
func _avant_le_rendu() -> void:
	for n in _caches + _caches_fixes:
		if is_instance_valid(n):
			(n as Node3D).visible = false
	if not _cacher_voxels or _volumes == null:
		return
	for c in _volumes.get_children():
		if c is MultiMeshInstance3D:
			(c as Node3D).visible = false


# ─── Les prises ──────────────────────────────────────────────────────────────

## Une prise « sous la lampe » (torche de J1 à 0,8 et les lumières propres du sujet) puis « dans le noir » (tout éteint),
## chacune en deux vignettes : la vue de J1 et la vue de J2. `tenir` est rappelé à chaque image (un sujet que le jeu fait
## vieillir se repose à son âge).
func _prendre_les_deux(nom: String, cote: float, sujets: Array, tenir := Callable()) -> void:
	_lumieres_gardees = _lumieres_des(sujets)
	_torche = true
	await _tenir_images(30, tenir)
	var lampe := get_viewport().get_texture().get_image()
	_torche = false
	_lumieres_gardees = []
	await _tenir_images(14, tenir)
	var noir := get_viewport().get_texture().get_image()
	for pid in 2:
		var a := _recadrer(lampe, _lieu, pid, cote)
		var b := _recadrer(noir, _lieu, pid, cote)
		_sauver(a, "%s_lampe_j%d" % [nom, pid + 1])
		_sauver(b, "%s_noir_j%d" % [nom, pid + 1])
		_releve("prise=%s vue=J%d lampe_max=%d lampe_moy=%.1f noir_max=%d noir_allumes=%d" % [nom, pid + 1,
			_valeur_max(a), _moyenne(a), _valeur_max(b), _allumes(b, 0)])
	_torche = false


func _tenir_images(n: int, tenir: Callable) -> void:
	for k in n:
		if tenir.is_valid():
			tenir.call()
		_eteindre_tout()
		await RenderingServer.frame_post_draw


## Les lumières que porte un sujet (ses `Light2D`, à toute profondeur).
func _lumieres_des(sujets: Array) -> Array:
	var l := []
	for s in sujets:
		if is_instance_valid(s):
			for n in (s as Node).find_children("*", "Light2D", true, false):
				l.append(n)
	return l


# ─── Mise en place ───────────────────────────────────────────────────────────

func _preparer_les_joueurs() -> void:
	for p: Node2D in [_main.p1, _main.p2]:
		p.set_physics_process(false)
		p.set("velocity", Vector2.ZERO)
		p.set("flashlight_on", false)
		p.set("dazzle_amount", 0.0)
		for nom in ["flashlight", "body_light", "ambient_light", "muzzle_flash"]:
			(p.get(nom) as Light2D).enabled = false
	_eteindre_tout()


## J1 à l'ouest du lieu, regardant l'est (sa torche l'éclaire) ; J2 au sud, regardant le nord, hors du cône de J1.
## Chaque caméra suit son joueur : il faut une seconde de jeu pour qu'elle se pose (lissage du regard), l'appelant
## l'attend.
func _placer_les_joueurs(d1: float, d2: float) -> void:
	_main.p1.global_position = _lieu + Vector2(-d1, 0.0)
	_main.p1.rotation = 0.0
	_main.p2.global_position = _lieu + Vector2(0.0, d2)
	_main.p2.rotation = -PI / 2.0


func _poser(slug: String, numero: int) -> Node2D:
	var avant: Array = _main.bullet_container.get_children()
	# Posé par J2 : la torche de J1 l'éclaire, et un joueur n'a qu'un gadget à la fois.
	_main._do_spawn_gadget(1, _lieu, 0.0, slug, numero)
	await _images(3)
	for n in _main.bullet_container.get_children():
		if not avant.has(n) and "slug" in n and String(n.get("slug")) == slug:
			_releve("pose=%s noeud=%s" % [slug, n.name])
			# Le drapeau PAR INSTANCE du jeu (« cette source n'éblouit pas ») : on veut voir le gadget, pas le voile.
			n.set("eblouit", false)
			# ⚠️ `_do_spawn_gadget` prend la durée de vie dans le profil de la classe DU POSEUR, pas dans le catalogue du
			# slug : une suie posée par un J2 qui n'est pas Fumiste ne vieillirait jamais (sa vie resterait pleine). On lui
			# rend celle du catalogue, celle qu'elle a en jeu sous la main de sa classe.
			var catalogue: Dictionary = _main.get_script().get_script_constant_map()["IMPLEMENTATIONS"]
			if catalogue.has(slug):
				n.set("duree_vie", float((catalogue[slug] as Dictionary).get("duree_vie", 0.0)))
			return n
	_echouer("« %s » n'a pas été posé par le vrai chemin" % slug)
	return null


## Toutes les lumières du duel éteintes — le bandeau LED compris, que le jeu rallume (piège d'ISO2) —, sauf la torche de
## J1 quand elle est voulue (tenue à `ENERGIE_TORCHE`) et les lumières propres du sujet sous la lampe.
func _eteindre_tout() -> void:
	var lampe := _main.p1.get("flashlight") as Light2D
	for n in _main.find_children("*", "Light2D", true, false):
		if _torche and (n == lampe or _lumieres_gardees.has(n)):
			continue
		(n as Light2D).enabled = false
		if (n as Node).name == MurLed.NOM:
			(n as Node).set_process(false)
	if _torche:
		_main.p1.set("flashlight_on", true)
		lampe.enabled = true
		lampe.energy = ENERGIE_TORCHE
	else:
		_main.p1.set("flashlight_on", false)
	if _visee != Vector2.ZERO:
		_main.p1.rotation = (_visee - (_main.p1 as Node2D).global_position).angle()
	# La ligne de visée et le viseur traversaient chaque vignette : cachés (le miroir iso lit leur visibilité).
	for p in [_main.p1, _main.p2]:
		var ligne := p.get("aim_line") as CanvasItem
		if ligne != null:
			ligne.visible = false
		var viseur := (p as Node).get_node_or_null(^"Viseur") as CanvasItem
		if viseur != null:
			viseur.visible = false


# ─── Outils ──────────────────────────────────────────────────────────────────

## La région de la fenêtre, de `cote` pixels, centrée sur la projection de `monde` dans la vue iso de `pid`, bornée au
## cadre de CETTE vue (jamais un pixel de la vue voisine).
func _recadrer(img: Image, monde: Vector2, pid: int, cote: float) -> Image:
	var projeter: Callable = _iso.call("projecteur_ecran", pid)
	var affichages: Array = _iso.get("_affichages")
	if not projeter.is_valid() or affichages.size() <= pid:
		return img
	var cadre := (affichages[pid] as Control).get_global_rect()
	var vue := _iso.call("viewport_ecran", pid) as Viewport
	var logique: Vector2 = projeter.call(monde)
	var echelle_vue := cadre.size / vue.get_visible_rect().size
	var fenetre := get_viewport().get_visible_rect().size
	var px := Vector2(img.get_size()) / fenetre
	var centre := (cadre.position + logique * echelle_vue) * px
	var r := Rect2i(Vector2i((centre - Vector2(cote, cote) * 0.5).round()), Vector2i(roundi(cote), roundi(cote)))
	var borne := Rect2i(Vector2i((cadre.position * px).round()), Vector2i((cadre.size * px).round()))
	r = r.intersection(borne)
	return img.get_region(r) if r.has_area() else img


func _images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


func _attendre(condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


static func _valeur_max(img: Image) -> int:
	var rgb := img.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var m := 0
	for o in rgb.get_data():
		m = maxi(m, o)
	return m


static func _moyenne(img: Image) -> float:
	var rgb := img.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var d := rgb.get_data()
	var s := 0
	for o in d:
		s += o
	return float(s) / maxf(1.0, float(d.size()))


## Le nombre de pixels dont un canal dépasse `seuil`/255.
static func _allumes(img: Image, seuil: int) -> int:
	var rgb := img.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var d := rgb.get_data()
	var n := 0
	for k in range(0, d.size(), 3):
		if d[k] > seuil or d[k + 1] > seuil or d[k + 2] > seuil:
			n += 1
	return n


func _sauver(img: Image, nom: String) -> void:
	if _dossier != "" and img != null:
		img.save_png(_dossier.path_join(nom + ".png"))


func _releve(ligne: String) -> void:
	print("BANC_GV ", ligne)
	_releves.append(ligne)


func _echouer(raison: String) -> void:
	_echecs += 1
	printerr("  ✗ ", raison)
	_releves.append("ECHEC " + raison)


func _finir() -> void:
	_releve("VERDICT=%s echecs=%d" % ["OK" if _echecs == 0 else "ECHEC", _echecs])
	var f := FileAccess.open(_dossier.path_join("releves_%s.txt" % _mode), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_releves) + "\n")
		f.close()
	GameSettings.mode_iso = false
	get_tree().quit(0 if _echecs == 0 else 1)
