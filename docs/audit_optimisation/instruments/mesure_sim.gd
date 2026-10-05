## Mesure de la simulation SANS RENDU (audit M, étape 4) — INSTRUMENT TEMPORAIRE, jamais commité.
##
## Monte le vrai jeu, headless, à pas fixe, et joue une manche ou une salle pendant `--secondes` secondes de jeu en
## échantillonnant la sonde (`sonde_mesures.gd`). Trois scénarios :
##
##   --scenario=bots       l'entraînement : un joueur type (BotInputProvider aux réflexes humains, torche allumée) contre le bot NORMAL
##                         sur `--carte=<id>` (default), SANS jamais remettre au calme : les morts et réapparitions du mode s'enchaînent.
##   --scenario=solo       une salle d'aventure `--chapitre=N --salle=M` (de 1) : le joueur type fait sa ronde, les PNJ sont maintenus en vie
##                         et pleins (vie remise à 100 à chaque image) pour que la salle reste active pendant toute la mesure.
##   --scenario=repos      le jeu monté, entraînement, personne ne bouge (témoin du coût de base de la scène).
##
## Options : --2d (vue de dessus au lieu de l'iso, défaut), --secondes=300, --palier=300, --json=<fichier>.
##
## godot --headless --path . --fixed-fps 60 --script res://tools/mesure_sim.gd -- --scenario=bots --secondes=300
extends SceneTree

const Sonde := preload("res://tools/sonde_mesures.gd")
const SondeRendu := preload("res://tools/sonde_rendu.gd")
const VariantesReflexion := preload("res://tools/variantes_reflexion.gd")
const Duel := preload("res://tools/banc_bot_duel.gd")
const Profil := preload("res://profil_bot.gd")
const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")

var _o: Dictionary = {}
var _main: Node = null
var _sonde = null
var _rendu = null
var _var = null


func _init() -> void:
	call_deferred("_run")


func _options() -> Dictionary:
	var o := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if not s.begins_with("--"):
			continue
		var i := s.find("=")
		if i < 0:
			o[s.substr(2)] = "1"
		else:
			o[s.substr(2, i - 2)] = s.substr(i + 1)
	return o


func _run() -> void:
	_o = _options()
	await process_frame
	var f0 := Engine.get_physics_frames()
	for _i in 30:
		await process_frame
	if absi(int(Engine.get_physics_frames() - f0) - 30) > 1:
		printerr("✗ l'horloge n'est pas fixe : lancer avec --fixed-fps 60")
		quit(1)
		return
	var scenario := String(_o.get("scenario", "bots"))
	var secondes := float(_o.get("secondes", "300"))
	var iso := not _o.has("2d")
	print("=== MESURE SANS RENDU : scénario %s, %s, %.0f s de jeu ===" % [scenario, "iso" if iso else "vue de dessus (--2d)", secondes])
	print("  moteur %s · rendu %s · affichage %s" % [Engine.get_version_info()["string"], RenderingServer.get_current_rendering_driver_name(), DisplayServer.get_name()])
	var t_montage := Time.get_ticks_msec()
	var ok := false
	match scenario:
		"bots":
			ok = await _monter_bots(iso)
		"solo":
			ok = await _monter_solo(iso)
		"repos":
			ok = await _monter_repos(iso)
		"depart":
			await _scenario_depart(iso, false)
			return
		"mort":
			await _scenario_depart(iso, true)
			return
	if not ok:
		printerr("✗ le scénario %s ne se monte pas" % scenario)
		quit(1)
		return
	print("  monté en %.1f s (horloge murale)" % ((Time.get_ticks_msec() - t_montage) / 1000.0))
	_var = VariantesReflexion.new(OS.get_cmdline_user_args())
	_var.brancher(self, _main)
	# Une chauffe de `--chauffe` secondes de jeu avant de mesurer (shaders, bassins, premiers tirs).
	var chauffe := int(float(_o.get("chauffe", "0")) * 60.0)
	var t_ch := Time.get_ticks_msec()
	for i in chauffe:
		await process_frame
		if scenario == "solo":
			_maintenir_en_vie()
	if chauffe > 0:
		print("  chauffe : %d images en %.1f s d'horloge murale" % [chauffe, (Time.get_ticks_msec() - t_ch) / 1000.0])
	_sonde = Sonde.new()
	_sonde.configurer("%s %s" % [scenario, "iso" if iso else "2d"], int(_o.get("palier", "300")), 1.0 / 60.0, _extras)
	_sonde.armer_physique(self)
	if _o.has("rendu"):
		_rendu = SondeRendu.new()
		_rendu.armer(self)
	var images := int(secondes * 60.0)
	var t0 := Time.get_ticks_msec()
	for i in images:
		await process_frame
		_sonde.image()
		if _rendu != null:
			_rendu.image()
		if scenario == "solo":
			_maintenir_en_vie()
	var mur := (Time.get_ticks_msec() - t0) / 1000.0
	print("  %d images jouées en %.1f s d'horloge murale (%.2f ms par image en moyenne)" % [images, mur, mur * 1000.0 / images])
	print(_sonde.rapport(float(_o.get("depuis", "30"))))
	if _rendu != null:
		print(_rendu.rapport(_main))
	if _o.has("json"):
		_sonde.ecrire_json(String(_o["json"]))
	quit(0)


func _extras() -> Dictionary:
	return Sonde.extras_du_jeu(self, _main)


func _monter_bots(iso: bool) -> bool:
	var duel := Duel.new(self)
	if not await duel.monter(String(_o.get("carte", "default")), {}, iso):
		return false
	_main = duel.main
	var graine := 7
	seed(Duel.GRAINE_BASE + graine * 104729)
	var placement: Dictionary = duel.placer_au_hasard(graine)
	var profil := Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
	_main.graine_du_bot = Duel.GRAINE_BASE ^ (graine * 31)
	_main._poser_l_adversaire(profil)
	_main.p2.equip_weapon(_main.weapon_for_index(int(_o.get("classe", "0"))))
	duel._rendre_les_reserves()
	Duel.redresser_le_corps(_main.p1)
	Duel.redresser_le_corps(_main.p2)
	if not placement.is_empty():
		_main.p1.global_position = placement["joueur"]
		_main.p1.rotation = float(placement["cap_joueur"])
		_main.p2.global_position = placement["bot"]
		_main.p2.rotation = float(placement["cap_bot"])
	_main.p2.velocity = Vector2.ZERO
	_main.p1.reset_step_tracker()
	_main.p2.reset_step_tracker()
	var bot: BotInputProvider = _main.p2.input_provider as BotInputProvider
	bot.reinitialiser()
	duel._liberer_le_fournisseur(_main.p1)
	var joueur := Duel.fabriquer_le_joueur(Duel.COMPORTEMENTS[String(_o.get("comportement", "avance_torche"))], _main._navigation_bot,
		Duel.GRAINE_BASE ^ (graine * 17), "humain")
	_main.p1.input_provider = joueur
	_main.p1.add_child(joueur)
	print("  entraînement : joueur type (%s) contre bot NORMAL, carte %s, classe du bot %s" % [_o.get("comportement", "avance_torche"), _o.get("carte", "default"), _o.get("classe", "0")])
	return true


func _monter_repos(iso: bool) -> bool:
	var duel := Duel.new(self)
	if not await duel.monter(String(_o.get("carte", "default")), {}, iso):
		return false
	_main = duel.main
	return true


var _partie: Node = null
var _chap := 0
var _salle := 0


func _monter_solo(iso: bool) -> bool:
	_chap = int(_o.get("chapitre", "0"))
	_salle = int(_o.get("salle", "9"))
	root.get_node("GameSettings").mode_iso = iso
	Format.racine = "res://assets/solo"
	Format.oublier_le_cache()
	var chapitre: Dictionary = Format.charger_chapitre("res://assets/solo/chapitre_%02d" % _chap)
	if chapitre.is_empty():
		printerr("✗ chapitre %d illisible" % _chap)
		return false
	var prog := Progression.new("user://mesure_solo.cfg")
	# Les chapitres d'avant d'abord (ils ouvrent le suivant), puis les salles d'avant de ce chapitre.
	for c in _chap:
		prog.terminer_chapitre(c)
	for i in _salle - 1:
		prog.reussir_niveau(_chap, i)
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for _i in 3:
		await process_frame
	_main.ui.aventure_progression = prog
	_main.archiver_les_matchs = false
	var classe := String(chapitre["classe_imposee"])
	if classe == "":
		classe = prog.classe_pour_jouer("")
	if classe == "":
		classe = "pistolet"
	var ok: bool = _main.demarrer_l_aventure(chapitre, _salle - 1, classe, prog)
	if not ok or _main.aventure == null:
		printerr("✗ demarrer_l_aventure a refusé (classe %s)" % classe)
		return false
	_partie = _main.aventure
	# Le carton dure 2,4 s ; on laisse la salle se poser, puis on met le joueur type aux commandes.
	for _i in 200:
		await process_frame
	var duel := Duel.new(self)
	duel.main = _main
	duel.ui = _main.ui
	var joueur := Duel.fabriquer_le_joueur(Duel.COMPORTEMENTS[String(_o.get("comportement", "avance_torche"))], _main._navigation_bot, 4242, "humain")
	duel._liberer_le_fournisseur(_main.p1)
	_main.p1.input_provider = joueur
	_main.p1.add_child(joueur)
	# `--pnj=N` : ne garder que N PNJ AU TRAVAIL (les autres sont endormis : `PROCESS_MODE_DISABLED` sur tout leur sous-arbre — plus de `_process`,
	# de `_physics_process`, de bot, de perception —, cachés et sans collision). Pour attribuer le coût d'une salle aux PNJ (V4, Q1 de BOT : 0, 3, 7).
	var gardes := (_partie.pnj as Array).size()
	if _o.has("pnj"):
		gardes = clampi(int(_o["pnj"]), 0, (_partie.pnj as Array).size())
		for i in range(gardes, (_partie.pnj as Array).size()):
			var p: Player = (_partie.pnj as Array)[i]
			p.process_mode = Node.PROCESS_MODE_DISABLED
			p.hide()
			p.collision_layer = 0
			p.collision_mask = 0
	print("  salle %d.%d « %s » : %d PNJ (%d au travail), joueur type (%s), classe %s, carte %s" % [_chap, _salle, String(_partie.niveau().get("titre", "?")),
		(_partie.pnj as Array).size(), gardes, _o.get("comportement", "avance_torche"), classe, str(MapCodecShim.taille(_main))])
	return true


func _maintenir_en_vie() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	_main.p1.hp = 100.0
	if _partie != null and is_instance_valid(_partie):
		for p in _partie.pnj:
			if is_instance_valid(p) and not p.dead:
				p.hp = 100.0


## Petit utilitaire : la taille de la carte active, pour la ligne d'en-tête.
class MapCodecShim:
	static func taille(main: Node) -> Variant:
		var md: Node = main.get_tree().root.get_node("MapData")
		var d: Dictionary = md.get_selected()
		return d.get("grid_size", "?")


## --scenario=depart : le DÉPART d'une manche locale (écran scindé), image par image, depuis le geste « rejouer » jusqu'à `--secondes`
## de jeu après lui : les pires images et leur date. C'est le moment où une saccade se voit (arène bâtie, vues montées, décompte).
func _scenario_depart(iso: bool, avec_mort: bool = false) -> void:
	var secondes := float(_o.get("secondes", "8"))
	root.get_node("GameSettings").mode_iso = iso
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for _i in 3:
		await process_frame
	var ui: Node = _main.ui
	var modes: Dictionary = (root.get_node("NetworkManager").get_script() as Script).get_script_constant_map()["GameMode"]
	ui._intended_mode = int(modes["LOCAL_SPLITSCREEN"])
	var idx := 0
	for i in _main.classes().size():
		if String(_main.classes()[i].slug()) == String(_o.get("classe", "pompe")):
			idx = i
	ui.set_weapon_selection(0, idx)
	ui.set_weapon_selection(1, idx)
	_var = VariantesReflexion.new(OS.get_cmdline_user_args())
	_var.brancher(self, _main)
	var dts: Array[float] = []
	var evenements: Array = []
	var t_prec := Time.get_ticks_usec()
	var t_geste := t_prec
	_main._on_replay_requested()
	var t_apres_geste := Time.get_ticks_usec()
	print("  le geste « rejouer » (appel synchrone, avant la première image) : %.1f ms" % ((t_apres_geste - t_geste) / 1000.0))
	var images := int(secondes * 60.0)
	var round_vu := false
	var i_actif := -1
	var tue := false
	var etat_prec := ""
	for i in images:
		await process_frame
		var t := Time.get_ticks_usec()
		dts.append((t - t_prec) / 1000.0)
		t_prec = t
		if not round_vu and bool(_main.round_active):
			round_vu = true
			i_actif = i
			evenements.append([i, "manche active"])
		# Les changements d'état de la manche (manche active, killcam, fin de partie, panneau de fin) : ils datent les pires images.
		var etat := "manche=%s killcam=%s fin=%s panneau=%s" % [str(_main.round_active), str(root.get_node("ReplaySystem").playing_back),
			str(_main.game_over), str(ui.game_over_panel.visible)]
		if etat != etat_prec:
			etat_prec = etat
			evenements.append([i, etat])
		# Le coup fatal : trois secondes après le départ du jeu (décompte fini), J1 abat J2 — le chemin de la balle n'est pas l'objet,
		# c'est la MORT (effets, killcam, fin de manche) : `take_damage` fait le reste comme pour une balle.
		if avec_mort and not tue and round_vu and float(_main.countdown_left) <= 0.0 and i >= i_actif + 240:
			tue = true
			evenements.append([i, "coup fatal sur J2"])
			var t_k := Time.get_ticks_usec()
			_main.p2.take_damage(1000.0, _main.p1)
			print("  take_damage fatal (appel synchrone) : %.1f ms" % ((Time.get_ticks_usec() - t_k) / 1000.0))
	var tri: Array = range(dts.size())
	tri.sort_custom(func(a, b) -> bool: return dts[a] > dts[b])
	print("  %d images après le geste (%.1f s de jeu) ; moyenne %.2f ms, médiane %.2f ms" % [dts.size(), dts.size() / 60.0, SondeRendu.moy(dts), SondeRendu.med(dts)])
	var l: PackedStringArray = []
	for k in mini(12, tri.size()):
		l.append("image %d : %.1f ms" % [tri[k], dts[tri[k]]])
	print("  les douze pires images : " + " · ".join(l))
	print("  événements : %s" % str(evenements))
	print("  premières images (ms) : " + " ".join(PackedStringArray(dts.slice(0, 20).map(func(x): return "%.1f" % x))))
	quit(0)
