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
## - `nuages` (GV1, GV1bis) — suie, poussière et fumée de fusée à plusieurs instants de leur vie, chacun rendu dans la
##   MÊME image de jeu (temps figé) sous chaque rendu de `RENDUS` : les couches d'aujourd'hui, les voxels gros de GV1, ceux
##   de GV1bis sans encre, puis sous chacune des trois encres du roman graphique (arêtes, volutes, hachures).
## - `noir` (GV1, GV1bis) — la preuve du noir À L'ÉCRAN : le nuage dont une moitié est sous la torche et l'autre dans le
##   noir, pris sans voxels, avec, puis sans encore (temps figé, LED coupées, corps cachés) ; un pixel noir sans le volume,
##   sous l'emprise des cubes, et allumé avec, est une fuite. Un témoin (des cubes qui s'allumeraient partout) prouve que le
##   détecteur n'est pas aveugle. Et « ALLUMÉ RESTE ALLUMÉ » (GV1bis) : chaque encre contre les mêmes cubes sans encre —
##   aucun pixel éclairé éteint —, contre un témoin sans plancher.
## - `cout` (GV1, GV1bis) — couches contre voxels, sur la même scène figée (fusée posée, suie, poussière) : la SURFACE
##   COUVERTE (les fragments que rastérisent les images du nuage, comptés par le GPU, dans chaque vue de l'écran scindé),
##   les appels de dessin, les primitives et le temps d'image médian, pour chaque rendu de `RENDUS_COUT`.
## - `nappes` (GV2) — la nappe de braises (à trois âges) et la poudre de contact (avec des traces, de la plus fraîche à la
##   plus pâle, dans la nappe et au-dehors), chacune dans la MÊME image de jeu sous les trois rendus de `RENDUS_NAPPES` :
##   le jeu publié (couches, lueurs, traces au sol), l'essai « tas » et l'essai « braises » ; sous la lampe (la torche de J1
##   et les lumières propres de la nappe), puis sans la lampe (les lumières propres seules : une nappe de braises éclaire),
##   dans les deux vues.
## - `noir_nappes` (GV2) — la preuve du noir À L'ÉCRAN pour les nappes en cubes, la méthode de `noir` (A, B, A', l'emprise,
##   le témoin, le masque coupé) : la poudre à moitié sous la torche, la nappe de braises sa lumière coupée (seul son dessin
##   peint luit) et allumée, sous chaque variante ; et LES GRAINS : dans le noir, un pixel que les grains allument doit être
##   à moins de deux blocs de 4 px d'un pixel qu'allumait la trace 2D du jeu publié, levée à l'écran jusqu'au sommet de ses
##   grains — un grain ne luit que là où sa trace luisait, dans la colonne qu'il occupe au-dessus d'elle.
## - `cout_nappes` (GV2) — le jeu publié contre les deux variantes de l'essai, sur la même scène figée (la nappe de braises,
##   la poudre et douze traces), la méthode de `cout` : surface couverte, appels de dessin, primitives, temps d'image médian.
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
## GV2 — vrai : les lumières PROPRES du sujet (`_lumieres_gardees`) restent allumées même sans la torche — la prise « sans la
## lampe » d'une nappe de braises, qui éclaire en jeu tant qu'elle brûle.
var _propres := false
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
		"nappes":
			await _nappes()
		"noir_nappes":
			await _noir_nappes()
		"cout_nappes":
			await _cout_nappes()
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

## Les rendus comparés, dans la MÊME image de jeu : [nom, voxels ?, taille, encre, relief]. Les couches d'aujourd'hui ;
## les voxels gros de GV1 (le trait clair des côtés, le relief du bruit) ; ceux de GV1bis (le relief du dessin), sans encre
## puis sous chacune des trois encres du roman graphique.
const RENDUS := [["couches", false, "", "", ""], ["gv1", true, "gros", "cotes", "bruit"],
	["sans_encre", true, "gros", "aucune", "dessin"], ["aretes", true, "gros", "aretes", "dessin"],
	["volutes", true, "gros", "volutes", "dessin"], ["hachures", true, "gros", "hachures", "dessin"]]
## La preuve du noir : chaque encre de GV1bis, et la taille fine sous l'encre par défaut.
const RENDUS_NOIR := [["aretes", true, "gros", "aretes", "dessin"], ["volutes", true, "gros", "volutes", "dessin"],
	["hachures", true, "gros", "hachures", "dessin"], ["fin", true, "fin", IsoNuageVoxel.ENCRE_PAR_DEFAUT, "dessin"]]
## Le coût : les couches, GV1, les trois encres de GV1bis ; la taille fine pour la surface seulement.
const RENDUS_COUT := [["couches", false, "", "", ""], ["gv1", true, "gros", "cotes", "bruit"],
	["aretes", true, "gros", "aretes", "dessin"], ["volutes", true, "gros", "volutes", "dessin"],
	["hachures", true, "gros", "hachures", "dessin"], ["fin", true, "fin", IsoNuageVoxel.ENCRE_PAR_DEFAUT, "dessin"]]


func _poser_rendu(rendu: Array) -> void:
	_volumes.poser_fumee_voxel(bool(rendu[1]), String(rendu[2]), String(rendu[3]), String(rendu[4]))


func _nuages() -> void:
	# La suie (9 s de vie) et la poussière (7,5 s) : la naissance (montée sur 12 % de la vie), pleine, pleine deux secondes plus
	# tard (la dérive lente du relief et du trait, à nuage égal), la dissipation.
	for nuage: Array in [["cartouche_suie", [0.45, 2.5, 5.0, 7.3], COTE_NUAGE, DISTANCE_J1, DISTANCE_J2],
			["poussiere", [0.4, 2.0, 4.0, 5.9], COTE_NUAGE + 140.0, 215.0, 215.0]]:
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
			_poser_rendu(rendu)
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
	var total_assombris := 0
	var total_sombres_assombris := 0
	var total_temoin_encre := 0
	var total_eteints_bord := 0
	var total_temoin_dedans := 0
	for c: Array in cas:
		var nom: String = c[0]
		# `--seulement=<cas>` : un seul cas (le préfixe de son nom), pour un essai rapide.
		if _seulement != "" and not nom.begins_with(_seulement):
			continue
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
		for rendu: Array in RENDUS_NOIR:
			var variante := String(rendu[0])
			_poser_rendu(rendu)
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
			# « ALLUMÉ RESTE ALLUMÉ » — même géométrie (la taille grosse), seule l'encre change. Cinq prises, L'ARBRE EN PAUSE
			# (`_prises_encre_figees`) : SANS encre, AVEC, le TÉMOIN (la même encre sans son plancher ni sa lumière : un trait
			# noir d'encre pure), SANS encre encore, AVEC encore. Un pixel n'est jugé que s'il est STABLE d'une prise sans encre
			# à l'autre ET d'une prise avec encre à l'autre. Aucun pixel éclairé (8/255 et plus) ne doit tomber sous 8/255 en
			# perdant 3/255 au moins ; les pixels SOMBRES (sous le plancher à l'écran) que l'encre assombrit encore se comptent
			# contre le témoin.
			if String(rendu[2]) == "gros":
				var prises := await _prises_encre_figees(variante, tenir)
				var sans1: Image = prises[0]
				var avec_encre: Image = prises[1]
				var noire: Image = prises[2]
				var sans2: Image = prises[3]
				var avec2: Image = prises[4]
				_poser_rendu(rendu)
				await _tenir_images(4, tenir)
				for pid in 2:
					var cote := COTE_FUSEE if nom.begins_with("fusee") else COTE_NUAGE + 140.0
					var al := _allumes_eteints(sans1, avec_encre, sans2, avec2, pid, cote)
					# Le témoin n'a qu'une prise : il n'est tenu que par la stabilité des prises sans encre.
					var tn := _allumes_eteints(sans1, noire, sans2, noire, pid, cote)
					_releve("allume cas=%s variante=%s vue=J%d stables=%d eclaires=%d assombris=%d eteints=%d eteints_dedans=%d eteints_bord=%d sombres=%d sombres_assombris=%d plus_sombre=%d | temoin_sans_plancher: eteints=%d eteints_dedans=%d sombres_assombris=%d" % [
						nom, variante, pid + 1, al["stables"], al["eclaires"], al["assombris"], al["eteints"], al["eteints_dedans"],
						al["eteints_bord"], al["sombres"], al["sombres_assombris"], al["plus_sombre"], tn["eteints"],
						tn["eteints_dedans"], tn["sombres_assombris"]])
					total_eteints_bord += int(al["eteints_bord"])
					total_temoin_dedans += int(tn["eteints_dedans"])
					total_assombris += int(al["assombris"])
					total_sombres_assombris += int(al["sombres_assombris"])
					total_temoin_encre += int(tn["sombres_assombris"])
					if pid == 0:
						_sauver(_recadrer(avec_encre, _lieu, pid, cote), "allume_%s_%s_avec_j1" % [nom, variante])
					if int(al["eteints"]) > 0:
						_releve("allume eteints cas=%s variante=%s vue=J%d : %s" % [nom, variante, pid + 1, al["details"]])
					if int(al["eteints_dedans"]) > 0:
						_echouer("%s %s J%d : %d pixels allumés éteints par l'encre, DEDANS la lumière" % [nom, variante,
							pid + 1, al["eteints_dedans"]])
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
	_releve("allume total_assombris=%d total_sombres_assombris=%d total_temoin_sombres_assombris=%d total_eteints_bord=%d total_temoin_eteints_dedans=%d" % [
		total_assombris, total_sombres_assombris, total_temoin_encre, total_eteints_bord, total_temoin_dedans])
	if total_assombris > 0 and total_temoin_dedans == 0 and _seulement == "":
		_echouer("le témoin sans plancher n'éteint aucun pixel DEDANS la lumière : le critère serait aveugle")
	if total_assombris == 0:
		_echouer("aucune encre n'a assombri un pixel : la preuve « allumé reste allumé » serait vide")
	if total_temoin_encre <= total_sombres_assombris:
		_echouer("le témoin sans plancher n'assombrit pas plus de pixels sombres que l'encre : le détecteur serait aveugle")


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


## Les cinq prises de « allumé reste allumé », L'ARBRE EN PAUSE : ni le jeu ni la présentation ne bougent d'une prise à
## l'autre, seul l'uniforme de l'encre change sur les matériaux des cubes — sans encre, avec, le TÉMOIN (sans plancher ni
## lumière), sans encre encore, avec encore. ⚠️ Deux passages sans pause ont compté des « éteints » qui n'étaient pas de
## l'encre : le premier comparait deux images (la scène scintille : un pixel sur cinq d'une image à l'autre, jusqu'à un sur
## quatre autour de la fusée) ; le second, qui ne jugeait que les pixels stables dans chaque paire de prises, en a encore
## trouvé trois dans une seule vue d'une seule scène — un scintillement en phase dans chaque paire (espacée de douze images)
## et pas d'une paire à l'autre (quatre images). Arbre en pause, les deux prises sans encre sont identiques au pixel près.
func _prises_encre_figees(encre: String, tenir: Callable) -> Array:
	_poser_rendu(["prise", true, "gros", encre, "dessin"])
	await _tenir_images(6, tenir)
	var mats := _materiaux_des_cubes()
	var style := int(IsoNuageVoxel.ENCRES[encre])
	var arbre := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	arbre.paused = true
	var out := []
	for prise: Array in [[-1, false], [style, false], [style, true], [-1, false], [style, false]]:
		for m in mats:
			var sm := m as ShaderMaterial
			sm.set_shader_parameter("encre_style", int(prise[0]))
			sm.set_shader_parameter("trait_plancher", 0.0 if bool(prise[1]) else IsoMateriaux.ENCRE_PLANCHER_AFFICHE)
			sm.set_shader_parameter("trait_reste", 0.0 if bool(prise[1]) else IsoNuageVoxel.TRAIT_RESTE)
		await _images(3)
		out.append(get_viewport().get_texture().get_image())
	arbre.paused = false
	return out


## Les SOMBRES de « allumé reste allumé » : éclairés sous `SOMBRE_ECRAN` — sous le plancher de l'encre à l'écran (16/255 en
## valeur affichée : ~71/255 écrit, × l'opacité d'un cube, 0,7 au moins), une face n'a pas de trait ; ceux que l'encre
## assombrit quand même ne sont que des bords anticrénelés (une face claire à peine couverte), et le témoin sans plancher
## doit en assombrir bien plus.
const SOMBRE_ECRAN := 48


## « ALLUMÉ RESTE ALLUMÉ » dans la vue `pid` — ⚠️ AU BORD et DEDANS (2026-10-01, après la fusion de la ligne publiée) : un
## pixel « éteint » dont un des huit voisins, sans l'encre, est sous 8/255 est AU BORD de la lumière — la face ne le couvre
## qu'en partie (l'anticrénelage mêle ses échantillons), et l'encre, tenue à son plancher sur la face, fait passer le mélange
## sous 8/255 avec le noir voisin. Le premier vu : la poussière, arêtes, vue de J1, 10 → 7/255, ses voisins de 0 à 32 — le
## trait d'une arête sur le bord du cône (la torche raccourcie par Q76 y a amené une arête). La règle du plancher tient par
## FACE (la suite la prouve sur le miroir de la pâte) ; un pixel partagé avec le noir n'est pas une face. Seuls les éteints
## DEDANS (tous leurs voisins éclairés) font échouer la preuve ; ceux du bord sont comptés et décrits.
##
## « ALLUMÉ RESTE ALLUMÉ » dans la vue `pid` : entre les prises SANS encre (`sans1`, `sans2`) et les prises AVEC (`avec`,
## `avec2` : la même image de jeu, les mêmes cubes — seule l'encre change, donc seuls les pixels des cubes peuvent
## différer). Un pixel n'est jugé que s'il est le même dans `sans1` et `sans2` ET dans `avec` et `avec2` : un pixel qui
## scintille n'est pas jugé. Les pixels éclairés (8/255 et plus sur un canal, sans encre), ceux que l'encre assombrit (de
## 3/255 au moins), ceux qu'elle ÉTEINT (assombris ET sous 8/255 avec elle), et la plus sombre valeur qu'elle laisse à un
## pixel qu'elle assombrit.
func _allumes_eteints(sans1: Image, avec: Image, sans2: Image, avec2: Image, pid: int, cote: float) -> Dictionary:
	var a := _recadrer(sans1, _lieu, pid, cote)
	var b := _recadrer(avec, _lieu, pid, cote)
	var a2 := _recadrer(sans2, _lieu, pid, cote)
	var b2 := _recadrer(avec2, _lieu, pid, cote)
	for im in [a, b, a2, b2]:
		(im as Image).convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var db := b.get_data()
	var da2 := a2.get_data()
	var db2 := b2.get_data()
	var stables := 0
	var eclaires := 0
	var assombris := 0
	var eteints := 0
	var eteints_bord := 0
	var sombres := 0
	var sombres_assombris := 0
	var plus_sombre := 255
	# Les premiers pixels « éteints », décrits : x, y, valeur sans l'encre et avec, le plus sombre et le plus clair de leurs
	# huit voisins sans l'encre.
	var details: PackedStringArray = []
	var largeur := a.get_width()
	for k in range(0, mini(mini(da.size(), db.size()), mini(da2.size(), db2.size())), 3):
		if da[k] != da2[k] or da[k + 1] != da2[k + 1] or da[k + 2] != da2[k + 2]:
			continue
		if db[k] != db2[k] or db[k + 1] != db2[k + 1] or db[k + 2] != db2[k + 2]:
			continue
		stables += 1
		var ma := maxi(da[k], maxi(da[k + 1], da[k + 2]))
		if ma < 8:
			continue
		eclaires += 1
		var mb := maxi(db[k], maxi(db[k + 1], db[k + 2]))
		if mb + 3 <= ma:
			assombris += 1
			plus_sombre = mini(plus_sombre, mb)
			if mb < 8:
				eteints += 1
				var x := (k / 3) % largeur
				var y := (k / 3) / largeur
				var vmin := 255
				var vmax := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var kk := ((y + dy) * largeur + (x + dx)) * 3
						if kk >= 0 and kk + 2 < da.size():
							var v := maxi(da[kk], maxi(da[kk + 1], da[kk + 2]))
							vmin = mini(vmin, v)
							vmax = maxi(vmax, v)
				if vmin < 8:
					eteints_bord += 1
				if details.size() < 6:
					details.append("(%d,%d) %d→%d voisins %d..%d%s" % [x, y, ma, mb, vmin, vmax,
						" (bord)" if vmin < 8 else " (DEDANS)"])
		if ma < SOMBRE_ECRAN:
			sombres += 1
			if mb + 3 <= ma:
				sombres_assombris += 1
	return {"stables": stables, "eclaires": eclaires, "assombris": assombris, "eteints": eteints,
		"eteints_bord": eteints_bord, "eteints_dedans": eteints - eteints_bord, "sombres": sombres,
		"sombres_assombris": sombres_assombris, "plus_sombre": plus_sombre, "details": " ; ".join(details)}


func _materiaux_des_cubes() -> Array:
	var out := []
	for c in _volumes.get_children():
		if c is MultiMeshInstance3D and not c.is_queued_for_deletion():
			out.append((c as MultiMeshInstance3D).material_override)
	return out


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
		for rendu: Array in RENDUS_COUT:
			_poser_rendu(rendu)
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
			for rendu: Array in [["sans_le_nuage", false, "", "", ""]] + RENDUS_COUT.filter(
					func(r): return String(r[0]) != "fin"):
				_poser_rendu(rendu)
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


# ─── GV2 : les nappes au sol ─────────────────────────────────────────────────

## Les rendus des nappes, dans la MÊME image de jeu : [nom, essai ?, variante]. Le jeu publié (couches, lueurs, traces au
## sol) ; l'essai « tas » (les nappes en cubes, les braises des cubes qui rougeoient, les traces en grains) ; l'essai
## « braises » (les nappes au sol, leurs braises seules en cubes, les traces en grains).
const RENDUS_NAPPES := [["publie", false, ""], ["tas", true, "tas"], ["braises", true, "braises"]]
## La nappe de braises vit 10 s (`GameState.IMPLEMENTATIONS`) et pâlit avec ce qu'elle brûle (0,35 à 1) : fraîche, à mi-vie,
## à la fin.
const AGES_BRAISES := [0.5, 5.0, 9.5]
## Le côté des vignettes des nappes, en pixels de fenêtre (la poudre fait 220 px de large, 275 à l'écran ; les traces
## dépassent d'un côté).
const COTE_NAPPE := 420.0


func _poser_rendu_nappes(rendu: Array) -> void:
	_volumes.poser_nappes_voxel(bool(rendu[1]), String(rendu[2]))


## Des TRACES de poudre, posées comme la poudre les pose (`GadgetPoudre.nouvelle_trace`, le groupe, l'arène) mais SANS leur
## fondu : leur éclat est celui qu'on leur donne, tenu le temps des prises. Un chemin d'est en ouest qui traverse la nappe
## au pas de la poudre (26 px) — les plus anciennes pâlissent —, puis les pieds poudrés au-dehors, de plus en plus pâles.
func _des_traces_tenues(centre: Vector2) -> Array:
	var traces := []
	var n_dedans := 8
	for k in n_dedans + 4:
		var m := GadgetPoudre.nouvelle_trace()
		var x := -95.0 + 26.0 * float(k)
		m.global_position = centre + Vector2(x, 12.0 + 6.0 * sin(float(k) * 1.3))
		m.rotation = 0.12 * sin(float(k) * 0.9)
		var eclat := GadgetPoudre.LUEUR_MAX * (0.35 + 0.65 * float(k) / float(n_dedans - 1)) if k < n_dedans \
			else GadgetPoudre.LUEUR_MAX * float(GadgetPoudre.CHARGE_MAX - (k - n_dedans)) / float(GadgetPoudre.CHARGE_MAX + 1)
		m.modulate.a = eclat
		m.add_to_group("traces_de_poudre")
		_main.arena.add_child(m)
		traces.append(m)
	return traces


## Les trois rendus d'une même image de nappe, sous la lampe puis sans elle (les lumières propres de la nappe gardées), dans
## les deux vues.
func _prendre_nappes(nom: String, cote: float, sujets: Array, tenir := Callable()) -> void:
	for lumiere in ["lampe", "sans_lampe"]:
		_torche = lumiere == "lampe"
		_propres = true
		_lumieres_gardees = _lumieres_des(sujets)
		await _tenir_images(30, tenir)
		for rendu: Array in RENDUS_NAPPES:
			_poser_rendu_nappes(rendu)
			await _tenir_images(6, tenir)
			var img := get_viewport().get_texture().get_image()
			for pid in 2:
				var c := _recadrer(img, _lieu, pid, cote)
				_sauver(c, "%s_%s_%s_j%d" % [nom, lumiere, String(rendu[0]), pid + 1])
				_releve("prise=%s lumiere=%s rendu=%s vue=J%d max=%d moy=%.1f allumes=%d" % [nom, lumiere, String(rendu[0]),
					pid + 1, _valeur_max(c), _moyenne(c), _allumes(c, 0)])
	_volumes.poser_nappes_voxel(false)
	_torche = false
	_propres = false
	_lumieres_gardees = []


func _nappes() -> void:
	if _seulement == "" or _seulement == "nappe_braises":
		_placer_les_joueurs(DISTANCE_J1, DISTANCE_J2)
		await _images(90)
		var g := await _poser("nappe_braises", 9900)
		if g != null:
			for age: float in ([5.0] if _vite else AGES_BRAISES):
				g.set("_age", age)
				await _tenir_images(12, func(): g.set("_age", age))
				await _prendre_nappes("gv2_braises_%04.1f" % age, COTE_NAPPE, [g], func(): g.set("_age", age))
			g.queue_free()
			await _images(4)
	if _seulement == "" or _seulement == "poudre_contact":
		_placer_les_joueurs(DISTANCE_J1, DISTANCE_J2)
		await _images(90)
		var po := await _poser("poudre_contact", 9901)
		if po != null:
			po.set_physics_process(false)
			var traces := _des_traces_tenues(po.global_position)
			await _prendre_nappes("gv2_poudre", COTE_NAPPE + 60.0, [po])
			for t in traces:
				(t as Node).queue_free()
			po.queue_free()
			await _images(4)


## LE NOIR À L'ÉCRAN des nappes en cubes, et celui des grains.
func _noir_nappes() -> void:
	_caches_fixes = []
	for corps in (_iso.get("_corps") as Array):
		_caches_fixes.append(corps)
	var total_temoin := 0
	var total_sans_masque := 0
	# [nom, slug, variante, lumière propre allumée ?, visée de J1 par rapport au lieu]
	var cas := [
		["poudre_tas", "poudre_contact", "tas", false, Vector2(0.0, -60.0)],
		["braises_tas_lueur_coupee", "nappe_braises", "tas", false, Vector2(0.0, -60.0)],
		["braises_tas_lueur", "nappe_braises", "tas", true, Vector2(0.0, -60.0)],
		["braises_seules_lueur", "nappe_braises", "braises", true, Vector2(0.0, -60.0)],
	]
	for c: Array in cas:
		var nom: String = c[0]
		if _seulement != "" and not nom.begins_with(_seulement):
			continue
		_placer_les_joueurs(DISTANCE_J1, DISTANCE_J2)
		_visee = _lieu + (c[4] as Vector2)
		await _images(90)
		var g := await _poser(String(c[1]), 9950)
		if g == null:
			continue
		var age := 5.0
		var tenir := func(): g.set("_age", age)
		_torche = true
		_propres = bool(c[3])
		_lumieres_gardees = _lumieres_des([g]) if bool(c[3]) else []
		_poser_rendu_nappes(["essai", true, String(c[2])])
		await _tenir_images(40, tenir)
		var avec := await _sandwich(tenir)
		var emprise := await _emprise(tenir)
		_volumes.poser_masque_fumee(false)
		await _tenir_images(4, tenir)
		var sans_masque := await _sandwich(tenir)
		_volumes.poser_masque_fumee(true)
		await _tenir_images(4, tenir)
		for pid in 2:
			var m := _fuites(avec, pid, COTE_NAPPE, emprise)
			var sm := _fuites(sans_masque, pid, COTE_NAPPE, emprise)
			var t := _fuites([avec[0], emprise, avec[2]], pid, COTE_NAPPE, emprise)
			total_temoin += int(t["fuites_2"])
			total_sans_masque += int(sm["fuites_2"])
			_releve("noir_nappes cas=%s vue=J%d noirs=%d emprise=%d noirs_dessous=%d instables=%d fuites=%d fuites_sup2=%d fuites_sup8=%d | masque_coupe: fuites_sup2=%d | temoin: fuites_sup2=%d" % [
				nom, pid + 1, m["noirs"], m["emprise"], m["noirs_emprise"], m["instables"], m["fuites"], m["fuites_2"],
				m["fuites_8"], sm["fuites_2"], t["fuites_2"]])
			_sauver(m["b"], "noir_nappes_%s_avec_j%d" % [nom, pid + 1])
			_sauver(m["a"], "noir_nappes_%s_sans_j%d" % [nom, pid + 1])
			_sauver(m["carte"], "noir_nappes_%s_carte_j%d" % [nom, pid + 1])
			if int(m["emprise"]) == 0:
				_echouer("%s J%d : les cubes n'ont rien rastérisé — la preuve serait vide" % [nom, pid + 1])
			if int(m["fuites_2"]) > 0:
				_echouer("%s J%d : %d fuites au-delà de 2/255 (pixels noirs allumés par les cubes)" % [nom, pid + 1,
					m["fuites_2"]])
		_volumes.poser_nappes_voxel(false)
		_torche = false
		_propres = false
		_lumieres_gardees = []
		_visee = Vector2.ZERO
		g.queue_free()
		await _images(4)
	_releve("noir_nappes total_masque_coupe_fuites_sup2=%d total_temoin_fuites_sup2=%d" % [total_sans_masque, total_temoin])
	if total_temoin == 0 and _seulement == "":
		_echouer("le témoin ne montre aucune fuite : le détecteur serait aveugle, la preuve vide")
	if _seulement == "" or _seulement == "grains":
		await _noir_des_grains()
	_caches_fixes = []


## LES GRAINS dans le noir : la poudre et ses traces, toutes les lumières éteintes ; la prise du jeu publié (les traces au sol,
## dans la lightmap), puis chaque variante de l'essai (les grains). Un pixel que l'essai allume (au-delà de 2/255) doit être à
## moins de deux blocs de 4 px d'un pixel qu'allumait la trace du jeu publié (au-delà de 0), la trace LEVÉE à l'écran
## jusqu'au sommet de ses grains (`_montee_ecran`) : un grain luit là où sa trace luisait, dans la colonne qu'il occupe au-
## dessus d'elle, nulle part ailleurs. Posé sur le tas de poudre (variante « tas »), un grain est plus haut que sa trace, et la
## caméra le montre plus haut — la parallaxe d'un objet posé, pas une lueur qui déborde : sans la levée, le haut du premier
## grain de chaque trace sortait de la tolérance (27 et 22 pixels, première preuve de GV2). Et l'essai doit allumer
## quelque chose (sinon, une preuve vide).
func _noir_des_grains() -> void:
	_placer_les_joueurs(DISTANCE_J1, DISTANCE_J2)
	_visee = Vector2.ZERO
	await _images(60)
	var po := await _poser("poudre_contact", 9960)
	if po == null:
		return
	po.set_physics_process(false)
	var traces := _des_traces_tenues(po.global_position)
	_torche = false
	_propres = false
	_lumieres_gardees = []
	_poser_rendu_nappes(RENDUS_NAPPES[0])
	await _tenir_images(30, Callable())
	var publie := get_viewport().get_texture().get_image()
	for rendu: Array in RENDUS_NAPPES.slice(1):
		_poser_rendu_nappes(rendu)
		await _tenir_images(10, Callable())
		var essai := get_viewport().get_texture().get_image()
		# Le sommet des grains : sur le tas (« tas » : la hauteur de la poudre), au ras du sol sinon (`IsoVolumes._suivre_traces`).
		var base := float(IsoNuageVoxel.NAPPES["poudre_contact"]["hauteur"]) * IsoVolumes.TUILE if String(rendu[2]) == "tas" \
			else IsoVolumes.PLANCHER_PX
		for pid in 2:
			var a := _recadrer(publie, _lieu, pid, COTE_NAPPE + 60.0)
			var b := _recadrer(essai, _lieu, pid, COTE_NAPPE + 60.0)
			var montee := _montee_ecran(pid, base + IsoVolumes.GRAIN_HAUT_PX, publie)
			var r := _hors_des_traces(a, b, 4, montee)
			_releve("grains rendu=%s vue=J%d allumes_publie=%d allumes_essai=%d hors_des_traces=%d montee_px=%.1f" % [
				String(rendu[0]), pid + 1, r["publie"], r["essai"], r["hors"], montee])
			_sauver(a, "grains_publie_j%d" % (pid + 1))
			_sauver(b, "grains_%s_j%d" % [String(rendu[0]), pid + 1])
			if int(r["essai"]) == 0:
				_echouer("grains %s J%d : rien d'allumé — la preuve serait vide" % [String(rendu[0]), pid + 1])
			if int(r["hors"]) > 0:
				_echouer("grains %s J%d : %d pixels allumés loin de toute trace" % [String(rendu[0]), pid + 1, r["hors"]])
	_volumes.poser_nappes_voxel(false)
	for t in traces:
		(t as Node).queue_free()
	po.queue_free()
	await _images(4)


## La montée À L'ÉCRAN, en pixels de l'image de la fenêtre `img`, d'un point posé à `h` pixels de monde au-dessus du sol, au
## lieu, dans la vue `pid` : la caméra de la vue (`CameraIso.vers_ecran`, sa hauteur), mise à l'échelle comme `_recadrer`.
func _montee_ecran(pid: int, h: float, img: Image) -> float:
	var cam := _iso.call("_camera_de", pid) as CameraIso
	var vue := _iso.call("viewport_ecran", pid) as Viewport
	var affichages: Array = _iso.get("_affichages")
	if cam == null or vue == null or affichages.size() <= pid:
		return 0.0
	var taille := vue.get_visible_rect().size
	var d := cam.vers_ecran(_lieu, taille).y - cam.vers_ecran(_lieu, taille, h).y
	var cadre := (affichages[pid] as Control).get_global_rect()
	var fenetre := get_viewport().get_visible_rect().size
	return d * (cadre.size.y / taille.y) * (float(img.get_height()) / fenetre.y)


## Les pixels allumés par `b` (au-delà de 2/255) dont aucun bloc voisin (de `bloc` pixels, à un bloc près) ne contient un pixel
## allumé par `a` (au-delà de 0), chaque pixel de `a` LEVÉ de `montee` pixels vers le haut de l'image (la colonne d'un objet
## posé au-dessus de lui ; 0 : au sol).
static func _hors_des_traces(a: Image, b: Image, bloc: int, montee := 0.0) -> Dictionary:
	var ia := a.duplicate() as Image
	var ib := b.duplicate() as Image
	ia.convert(Image.FORMAT_RGB8)
	ib.convert(Image.FORMAT_RGB8)
	var w := mini(ia.get_width(), ib.get_width())
	var h := mini(ia.get_height(), ib.get_height())
	var da := ia.get_data()
	var db := ib.get_data()
	var bw := ceili(float(w) / float(bloc))
	var bh := ceili(float(h) / float(bloc))
	var blocs := PackedByteArray()
	blocs.resize(bw * bh)
	var publie := 0
	for y in h:
		for x in w:
			var k := (y * ia.get_width() + x) * 3
			if da[k] > 0 or da[k + 1] > 0 or da[k + 2] > 0:
				publie += 1
				for t in range(0, ceili(maxf(montee, 0.0)) + 1, bloc):
					var yl := maxi(y - t, 0)
					blocs[(yl / bloc) * bw + x / bloc] = 1
				var yh := maxi(y - ceili(maxf(montee, 0.0)), 0)
				blocs[(yh / bloc) * bw + x / bloc] = 1
	var essai := 0
	var hors := 0
	for y in h:
		for x in w:
			var k := (y * ib.get_width() + x) * 3
			if maxi(db[k], maxi(db[k + 1], db[k + 2])) <= 2:
				continue
			essai += 1
			var bx := x / bloc
			var by := y / bloc
			var proche := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var cx := bx + dx
					var cy := by + dy
					if cx >= 0 and cy >= 0 and cx < bw and cy < bh and blocs[cy * bw + cx] == 1:
						proche = true
			if not proche:
				hors += 1
	return {"publie": publie, "essai": essai, "hors": hors}


## LE COÛT des nappes : le jeu publié contre les deux variantes de l'essai, sur la même scène figée — la nappe de braises à
## mi-vie (sa lumière allumée), la poudre et ses douze traces —, la méthode de `cout`.
func _cout_nappes() -> void:
	await _etalonner()
	for scene: String in ["braises", "poudre"]:
		if _seulement != "" and _seulement != scene:
			continue
		_placer_les_joueurs(DISTANCE_J1, DISTANCE_J2)
		await _images(60)
		var g := await _poser("nappe_braises" if scene == "braises" else "poudre_contact", 9980 + (1 if scene == "poudre" else 0))
		if g == null:
			continue
		var traces := []
		var tenir := Callable()
		if scene == "braises":
			tenir = func(): g.set("_age", 5.0)
		else:
			g.set_physics_process(false)
			traces = _des_traces_tenues(g.global_position)
		_torche = true
		_propres = true
		_lumieres_gardees = _lumieres_des([g])
		await _tenir_images(40, tenir)
		for rendu: Array in RENDUS_NAPPES:
			_poser_rendu_nappes(rendu)
			await _tenir_images(10, tenir)
			var mesure := await _surface_nappe(g, tenir)
			for pid in 2:
				var m: Dictionary = mesure[pid]
				_releve("surface scene=%s rendu=%s vue=J%d fragments=%d images=%d juge=%d empreinte=%d" % [scene, String(rendu[0]),
					pid + 1, int(m["images"]) + int(m["juge"]), m["images"], m["juge"], m["empreinte"]])
				if int(m["images"]) <= 0:
					_echouer("%s %s J%d : le compteur n'a rien compté — la mesure serait vide" % [scene, String(rendu[0]), pid + 1])
		await _tenir_images(30, tenir)
		for tour in 2:
			for rendu: Array in [["sans_la_nappe", false, ""]] + RENDUS_NAPPES:
				_poser_rendu_nappes(rendu if String(rendu[0]) != "sans_la_nappe" else RENDUS_NAPPES[0])
				await _tenir_images(20, tenir)
				if String(rendu[0]) == "sans_la_nappe":
					var n := _noeuds_de_la_nappe(g)
					_caches = n["images"] + n["juges"]
				var mesure := await _mesurer(60, tenir)
				_caches = []
				_releve("cout scene=%s tour=%d rendu=%s appels=%d primitives=%d image_ms_mediane=%.1f image_ms_p90=%.1f" % [
					scene, tour + 1, String(rendu[0]), mesure["appels"], mesure["primitives"], mesure["mediane"], mesure["p90"]])
		_volumes.poser_nappes_voxel(false)
		_torche = false
		_propres = false
		_lumieres_gardees = []
		for t in traces:
			(t as Node).queue_free()
		g.queue_free()
		await _images(4)


## Les nœuds 3D des images d'une nappe : ses couches ou ses cubes (clé 0), ses lueurs ou ses braises en cubes (clé 1), son
## juge ; pour la poudre, les grains de toutes les traces (l'entrée de l'arène).
func _noeuds_de_la_nappe(sujet: Object) -> Dictionary:
	var images := []
	var juges := []
	for e: Dictionary in (_volumes.get("_suivis") as Dictionary).values():
		var source: Object = (e["source"] as WeakRef).get_ref()
		var genre := String(e["genre"])
		if not (source == sujet and ["volume", "nuage_voxel", "braises"].has(genre)) \
				and not (genre == "grains" and String(sujet.get("slug")) == "poudre_contact"):
			continue
		for n in e["noeuds"]:
			if is_instance_valid(n) and (n as Node3D).visible:
				images.append(n)
		if is_instance_valid(e.get("juge")) and (e["juge"] as Node3D).visible:
			juges.append(e["juge"])
	return {"images": images, "juges": juges}


## La surface couverte par les images d'une nappe (la méthode de `_surface`, sur `_noeuds_de_la_nappe`).
func _surface_nappe(sujet: Node, tenir: Callable) -> Array:
	var torche := _torche
	var propres := _propres
	var gardees := _lumieres_gardees
	_torche = false
	_propres = false
	_lumieres_gardees = []
	await _tenir_images(40, tenir)
	var noeuds := _noeuds_de_la_nappe(sujet)
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
	_propres = propres
	_lumieres_gardees = gardees
	var out := []
	for pid in 2:
		var images := _ecarts(base[pid], comptes[0][pid], _unites[pid])
		var juge := _ecarts(base[pid], comptes[1][pid], _unites[pid])
		out.append({"images": images["fragments"], "juge": juge["fragments"], "empreinte": images["empreinte"]})
	return out


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
##
## GV2 — les lumières PROPRES gardées (`_propres`) sont RALLUMÉES, et pas seulement épargnées : une extinction faite avant
## qu'on les déclare gardées (l'âge tenu juste après la pose) les éteignait, et rien ne les rallumait — le jeu ne coupe
## jamais la lueur d'une nappe de braises. Ses braises sortaient à l'éclat 0 : invisibles dans le tas, la variante
## « braises » cachée, et le sol sans sa lueur ambre (trois passages du banc de GV2 à chercher la faute dans le shader).
func _eteindre_tout() -> void:
	var lampe := _main.p1.get("flashlight") as Light2D
	for n in _main.find_children("*", "Light2D", true, false):
		if _propres and _lumieres_gardees.has(n):
			(n as Light2D).enabled = true
			continue
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
