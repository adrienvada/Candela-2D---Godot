extends "res://tools/photographe.gd"
## LE BANC DE LA VUE DU BOT CONTRE LES CAPTEURS — chantier SOLO, étape S2 (2026-10-02).
##
## Le bot voit par un MODÈLE (`perception_bot.gd`), pas en relisant le GPU : « le modèle n'a le droit de se tromper que dans
## un sens — voir MOINS que la lumière, jamais plus ». `tools/test_bot_perception.gd` le prouve sans fenêtre, sur des
## situations posées à la main. Ce banc est l'autre moitié : **la vraie lumière du jeu**. Il monte un vrai duel (le vrai
## `main.tscn`, la vraie carte d'essai `tools/cartes/perception_essai.json`, les vraies torches, les vrais éclairs, la vraie
## fusée, le vrai halo), pose des situations, et compare à chacune
##   • ce que le MODÈLE dit — le nœud de perception du jeu (`PerceptionBotNoeud`), monté sur J2, qui relit les nœuds vivants
##     exactement comme en match ;
##   • ce que le CAPTEUR du corps de la cible rend dans la vue du bot (`CapteurCorps`, ISO2 : la lumière que reçoit le corps,
##     lue sur le disque de 256² texels où le shader des corps la lit) — le maximum d'un anneau de rayon 17 px, comme
##     `planche_q42`. C'est ce qu'un joueur verrait du corps de l'autre : un corps noir est un corps qu'on ne voit pas.
##
## ## Le verdict
##
##   • **ÉCHEC (code 1) : le modèle voit là où le capteur est NOIR** (maximum < `SEUIL_NOIR`) — c'est de la malhonnêteté,
##     le bot saurait ce que la lumière lui cache ; **ou** le capteur de SOI sous un plafonnier n'est pas ce que le mur commande ;
##     **ou** une prise `plafonnier_bas` n'a pas obtenu la posture qu'elle annonce ;
##   • **rapporté** : le taux d'accord — de tout ce que le capteur éclaire, la part que le modèle voit aussi. Il peut
##     LÉGITIMEMENT être sous 100 % : le modèle ne connaît pas la rétrodiffusion, ne regarde que ce qui tient dans l'écran, et
##     exige une ligne de vue du bot sur le corps (un corps éclairé derrière un mur est éclairé, mais pas vu). Un taux bas
##     n'est pas un défaut ; un modèle qui voit où le capteur est noir en est un.
##
## ⚠️ **Ce que le capteur mesure, et ne mesure pas.** Il lit la lumière REÇUE par le corps, jamais la ligne de vue entre le
## bot et lui : un corps éclairé par SA propre rétrodiffusion derrière un mur est lu éclairé. Les cas où le mur compte pour la
## preuve sont donc ceux où la lumière vient d'ailleurs que du corps — la torche du bot, un éclair du bot, une fusée, le halo
## du bot — et c'est là que le banc peut prendre le modèle en faute s'il ignore un mur.
##
## ## Les parties
##
##   1. **LE CADRE** : les quatre coins de l'écran de la caméra de J2, ramenés au sol par `CameraIso.vers_sol`, doivent être
##      ceux du cadre du modèle (`PerceptionBot.cadre_de_vue`), dans quatre visées. Un cadre plus large que l'écran serait
##      un bot qui voit hors de l'écran.
##   2. **LES SITUATIONS** : 124 prises en treize familles — le noir, la lampe de la cible (de face, de dos, de près, de loin), la
##      lampe derrière un mur, hors du cadre, le cône de la torche du bot (axe, flancs, bord, portée), le cône derrière un
##      mur, l'éclair de la cible, l'éclair du bot, la fusée (allumage, braise), la fusée derrière un mur, le halo de
##      proximité, les murs bas (debout, accroupi) et le bandeau LED des murs.
##   3. **LES PLAFONNIERS (S5)** : 64 prises en trois familles + 2 lectures du capteur de SOI. `plafonnier` : la flaque, de 20 à
##      115 % de son rayon, aux trois énergies que le jeu permet — **où le capteur éclaire encore, et où le modèle s'arrête** ;
##      `plafonnier_mur` : la paroi entre la lampe et la cible (capteur noir : le modèle est pris en faute s'il l'ignore), le
##      témoin sans mur, le bot derrière la paroi, et le capteur de SOI du bot (son propre corps dans sa propre vue : noir
##      derrière la paroi, éclairé sans) ; `plafonnier_bas` : la lampe haute et le mur bas (zone morte FINIE d'un accroupi, la
##      posture RÉELLE lue et exigée). Et, sur demande seulement (`--familles=planche`), une PLANCHE de quatre images à regarder
##      (`plafonnier_noir`, `_flaque`, `_accroupi`, `_sans_luminaire`) : l'œil juge ce que le capteur ne dit pas.
##
## ## Lancer
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . --resolution 1920x1080 \
##     res://tools/banc_perception_bot.tscn -- --no-eos [--sortie=<dossier>] [--taille=640x360] [--familles=a,b]
##
## Ouvre une fenêtre : il ne rejoint aucune suite headless. Ses appuis sur le jeu sont déclarés ici
## (`preconditions_perception`) et vérifiés par `tools/test_banc.gd`.

const Percep := preload("res://perception_bot.gd")
const Noeud := preload("res://perception_bot_noeud.gd")
const Profil := preload("res://profil_bot.gd")
const Memoire := preload("res://memoire_bot.gd")

const CARTE_BANC := "res://tools/cartes/perception_essai.json"
const TUILE := 35.0

## Sous ce maximum d'anneau, le corps est NOIR : le modèle n'a rien à y voir. Le noir absolu du jeu rend 0,0000 ; 0,03 laisse
## le bruit d'un filtre.
const SEUIL_NOIR := 0.03
## Au-dessus, le corps est ÉCLAIRÉ : le seuil d'apparition de Q32 (« lisible si elle atteint 0,10 »).
const SEUIL_LIT := 0.10
## Combien d'images on tient une pose avant de lire : la lampe respire, le regard se lisse (8/s), le capteur suit la place.
const IMAGES_POSE := 12
const IMAGES_CADRE := 40

## Le bot (J2) est au centre de la carte ; la cible (J1) autour de lui. 48 × 40 cases : le centre de la caméra n'y est pas
## bridé par les bords de la carte.
var _o := Vector2((24.0 + 0.5) * TUILE, (20.0 + 0.5) * TUILE)

class Poupee extends InputProvider:
	var visee := Vector2.RIGHT
	var torche := false
	var accroupi := false

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_shoot_pressed() -> bool:
		return false

	func is_flashlight_pressed() -> bool:
		return torche

	func is_flare_pressed() -> bool:
		return false

	func is_reload_pressed() -> bool:
		return false

	func is_crouch_pressed() -> bool:
		return accroupi


var _iso: Presentation3D
var _poupees: Array[Poupee] = []
var _noeud: PerceptionBotNoeud
## La pose voulue, réappliquée à chaque image.
var _cfg: Dictionary = {}
var _lignes: Array[Dictionary] = []
## S5 — le capteur de SOI du bot (J2 dans SA vue), sous un plafonnier : [nom, maximum de l'anneau, noir attendu ?].
var _soi: Array[Dictionary] = []
var _cadre_verdict: Dictionary = {}
var _familles_voulues: Array = []
var _cacher := PackedStringArray()


## Les appuis de ce banc sur le jeu, lisibles sans fenêtre : `tools/test_banc.gd` les vérifie. Même discipline que les autres
## bancs — un outil qu'aucune suite ne peut exécuter doit exposer ses hypothèses, sinon il se périme en silence (le banc de
## cadence est resté cassé des jours à ne rien mesurer, 2026-08-18).
static func preconditions_perception(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents
	for prop in ["p1", "p2", "cam1", "cam2", "vp1", "vp2", "arena", "round_active", "countdown_left",
			"rendu_racine_autorise", "archiver_les_matchs", "murs_bas"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	for methode in ["_on_replay_requested", "rebuild_arena", "_accorder_rendu_aux_vues", "_set_player_input_provider",
			"_do_spawn_fusee"]:
		if not main.has_method(methode):
			absents.append("GameState.%s() a disparu" % methode)
	for prop in ["hub", "center_line", "hud_panneau_p2", "match_hud", "_voile_scinde"]:
		if not prop in ui:
			absents.append("UI.%s a disparu" % prop)
	var script_joueur := load("res://player.gd") as GDScript
	if script_joueur == null:
		absents.append("player.gd est introuvable")
	else:
		var noms := {}
		for m in script_joueur.get_script_method_list():
			noms[m["name"]] = true
		for methode in ["poser_posture", "trigger_shoot_visuals", "equip_weapon"]:
			if not noms.has(methode):
				absents.append("Player.%s() a disparu" % methode)
		var propres := {}
		for p in script_joueur.get_script_property_list():
			propres[p["name"]] = true
		for prop in ["flashlight", "body_light", "ambient_light", "muzzle_flash", "muzzle", "accroupi", "dead",
				"flashlight_on", "current_weapon", "player_id"]:
			if not propres.has(prop):
				absents.append("Player.%s a disparu" % prop)
	var script_iso := load("res://presentation_3d.gd") as GDScript
	if script_iso == null:
		absents.append("presentation_3d.gd est introuvable")
	else:
		var methodes := {}
		for m in script_iso.get_script_method_list():
			methodes[m["name"]] = true
		for methode in ["instance", "viewport_ecran", "_camera_de", "capteurs"]:
			if not methodes.has(methode):
				absents.append("Presentation3D.%s() a disparu" % methode)
		var props := {}
		for p in script_iso.get_script_property_list():
			props[p["name"]] = true
		if not props.has("_capteurs"):
			absents.append("Presentation3D._capteurs a disparu")
	var script_camera := load("res://camera_iso.gd") as GDScript
	if script_camera == null or not script_camera.get_script_method_list().any(func(m): return m["name"] == "vers_sol"):
		absents.append("CameraIso.vers_sol() a disparu")
	var script_fusee := load("res://fusee.gd") as GDScript
	if script_fusee == null:
		absents.append("fusee.gd est introuvable")
	else:
		var m_fusee := {}
		for m in script_fusee.get_script_method_list():
			m_fusee[m["name"]] = true
		for methode in ["forcer_age", "est_allumee_au_sol", "energie_relative"]:
			if not m_fusee.has(methode):
				absents.append("Fusee.%s() a disparu" % methode)
	# S5 — les plafonniers : le banc les pose par `Plafonnier.poser` (l'appel de S6) et lit leur lumière et leurs bornes.
	var script_plafonnier := load("res://plafonnier.gd") as GDScript
	if script_plafonnier == null:
		absents.append("plafonnier.gd est introuvable")
	else:
		var m_plafonnier := {}
		for m in script_plafonnier.get_script_method_list():
			m_plafonnier[m["name"]] = true
		for methode in ["poser", "retirer", "actualiser", "normaliser", "valider"]:
			if not m_plafonnier.has(methode):
				absents.append("Plafonnier.%s() a disparu" % methode)
		var p_plafonnier := {}
		for p in script_plafonnier.get_script_property_list():
			p_plafonnier[p["name"]] = true
		if not p_plafonnier.has("halo"):
			absents.append("Plafonnier.halo a disparu")
		var constantes := script_plafonnier.get_script_constant_map()
		for nom in ["INTENSITE_MIN", "INTENSITE_PAR_DEFAUT", "INTENSITE_MAX", "GROUPE"]:
			if not constantes.has(nom):
				absents.append("Plafonnier.%s a disparu" % nom)
	if not ResourceLoader.exists(CARTE_BANC):
		absents.append("la carte du banc (%s) est introuvable" % CARTE_BANC)
	for chemin in ["res://perception_bot.gd", "res://perception_bot_noeud.gd", "res://memoire_bot.gd", "res://profil_bot.gd",
			"res://plafonnier.gd"]:
		if not ResourceLoader.exists(chemin):
			absents.append("%s est introuvable" % chemin)
	return absents


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ banc_perception_bot : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://perception_bot")
	_taille = _lire_taille(_valeur(args, "--taille", "640x360"))
	var voulues := _valeur(args, "--familles", "").strip_edges()
	_familles_voulues = [] if voulues == "" else Array(voulues.split(","))
	# `--cacher=led,halos` : éteint des lumières du jeu pendant la séance, pour ISOLER ce qui éclaire le capteur (diagnostic).
	_cacher = _valeur(args, "--cacher", "").split(",", false)
	print("=== Banc : la vue du bot contre les capteurs (S2) ===")
	_poser_la_fenetre()
	AudioServer.set_bus_mute(0, true)
	var intro_vue_avant: bool = GameSettings.intro_vue
	GameSettings.intro_vue = true
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	GameSettings.intro_vue = intro_vue_avant
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	var manquants := preconditions_perception(_ui, _main)
	if not manquants.is_empty():
		printerr("✗ les appuis du banc ont disparu : ", "; ".join(manquants))
		_sortir(1)
		return
	_main.rendu_racine_autorise = true
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
		await _attendre_disparition(allumage, 3.0)
	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 120.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 180.0):
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_carte_duel = CARTE_BANC
	await _passer_sur_la_carte_des_murs_bas()
	if MapData.current_map_data.get("name", "") != "Essai — perception du bot":
		printerr("✗ la carte du banc n'a pas été posée (%s)" % str(MapData.current_map_data.get("name", "?")))
		_sortir(1)
		return
	_poupees.clear()
	for j in [_main.p1, _main.p2]:
		var p := Poupee.new()
		p.name = "PoupeeDuBanc"
		_main._set_player_input_provider(j, p)
		_poupees.append(p)
	_sans_hud = true
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	_iso = Presentation3D.instance()
	if _iso == null:
		printerr("✗ aucune Presentation3D : la vue iso n'est pas en place")
		_sortir(1)
		return
	if not await _passer_en_vue_unique_de_j2():
		_sortir(1)
		return
	for j in [_main.p1, _main.p2]:
		_equiper(j, "pistolet")
	# Le nœud de perception du jeu, monté sur J2 comme `BotInputProvider` le fait : il relit les nœuds vivants.
	var profil := Profil.new()
	profil.voit = true
	profil.entend = false
	_noeud = Noeud.new()
	_noeud.configurer(profil, MapData.current_map_data, _main.p2, 1)
	_main.p2.add_child(_noeud)
	print("  J2 est le bot, J1 la cible. Zoom de la vue de J2 : %s, lacet %s, portée de la torche %.0f px"
		% [str(_main.cam2.zoom), str(GameSettings.lacet_duel), float(_main.p2.current_weapon.portee_torche())])
	await _tenir_images(IMAGES_POSE)

	await _verifier_le_cadre()
	await _les_familles()
	_verdict()
	_sortir(1 if _echec() else 0)


func _equiper(joueur: Node, slug: String) -> void:
	for k in 10:
		var c = _main.weapon_for_index(k)
		if c is ClassData and String((c as ClassData).slug()) == slug:
			joueur.equip_weapon(_main.weapon_for_index(k))
			return


## La vue de J2 seule — celle du bot, comme `planche_q42 --vue-unique=1`. Le jeu se range seul (`_accorder_rendu_aux_vues`).
func _passer_en_vue_unique_de_j2() -> bool:
	var autre := _main.vp1.get_parent() as Control
	if autre != null:
		autre.hide()
	_ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	_ui._voile_scinde = false
	if _ui.hud_panneau_p2 != null:
		_ui.hud_panneau_p2.visible = false
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	# Le zoom d'une VUE UNIQUE (×1,5), pas celui de l'écran scindé (×1,25) que la manche a posé : c'est le cadrage que le modèle
	# donne au bot, et celui qu'ont l'entraînement et le duel en ligne (`GameState._apply_network_mode`, qui appelle ceci).
	GameSettings.accorder_au_mode(false, false)
	_main.cam1.zoom = Vector2.ONE * GameSettings.zoom_duel
	_main.cam2.zoom = Vector2.ONE * GameSettings.zoom_duel
	await _attendre_images(20)
	if _iso.viewport_ecran(1) == null or _iso.viewport_ecran(0) != null:
		printerr("✗ la vue de J2 seule n'est pas en place")
		return false
	if _iso._capteurs[1][0] == null:
		printerr("✗ le capteur du corps de J1 dans la vue de J2 n'existe pas")
		return false
	return true


# ---------------------------------------------------------------------------
# LA POSE
# ---------------------------------------------------------------------------

## Pose voulue : `o` / `t` (positions), `o_visee` / `t_visee`, `o_torche` / `t_torche`, `o_accroupi` / `t_accroupi`.
func _pose(o: Vector2, o_visee: Vector2, t: Vector2, t_visee: Vector2, o_torche := false, t_torche := false,
		o_accroupi := false, t_accroupi := false) -> void:
	_cfg = {"o": o, "o_visee": o_visee.normalized(), "t": t, "t_visee": t_visee.normalized(), "o_torche": o_torche,
		"t_torche": t_torche, "o_accroupi": o_accroupi, "t_accroupi": t_accroupi}


func _appliquer() -> void:
	if _cfg.is_empty():
		return
	var o = _main.p2
	var t = _main.p1
	o.global_position = _cfg["o"]
	t.global_position = _cfg["t"]
	o.rotation = (_cfg["o_visee"] as Vector2).angle()
	t.rotation = (_cfg["t_visee"] as Vector2).angle()
	_poupees[1].visee = _cfg["o_visee"]
	_poupees[0].visee = _cfg["t_visee"]
	_poupees[1].torche = _cfg["o_torche"]
	_poupees[0].torche = _cfg["t_torche"]
	_poupees[1].accroupi = _cfg["o_accroupi"]
	_poupees[0].accroupi = _cfg["t_accroupi"]
	for j in [o, t]:
		j.velocity = Vector2.ZERO
		j.hp = 100.0
		j.set("_dust_accum", -1.0e9)
		if _cacher.has("halos"):
			j.ambient_light.visible = false
	if _cacher.has("led"):
		var led := _main.arena.get_node_or_null("MurLed") as Node2D
		if led != null:
			led.visible = false


func _tenir_images(n: int) -> void:
	for i in n:
		_appliquer()
		await get_tree().process_frame


## Le niveau que lit le corps `j` dans le capteur de la vue `v` : [moyenne de l'anneau, maximum de l'anneau], la luminance de
## `planche_q42._niveau` (Rec. 709, anneau de rayon 17 px — là où le shader des corps lit).
func _niveau(v: int, j: int) -> Array:
	var c = _iso._capteurs[v][j]
	if c == null:
		return [-1.0, -1.0]
	var img: Image = (c as CapteurCorps).get_texture().get_image()
	var texels_par_px := float(CapteurCorps.TAILLE) / CapteurCorps.MONDE_PX
	var r := minf(Presentation3D.RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0) * texels_par_px
	var centre := Vector2(img.get_width(), img.get_height()) * 0.5
	var somme := 0.0
	var haut := 0.0
	for a in 64:
		var q := centre + Vector2.from_angle(TAU * (float(a) + 0.5) / 64.0) * r
		var px := img.get_pixelv(Vector2i(q))
		var lum := px.r * 0.2126 + px.g * 0.7152 + px.b * 0.0722
		somme += lum
		haut = maxf(haut, lum)
	return [somme / 64.0, haut]


## Lit le capteur de la cible dans la vue du bot ET ce que le modèle en dit, et les consigne.
func _lire(famille: String, nom: String, extra: Dictionary = {}) -> void:
	var niveau := _niveau(1, 0)
	var vue: Dictionary = _noeud.derniere_vue
	var ligne := {
		"famille": famille, "nom": nom,
		"modele_vu": bool(vue["vu"]), "par": (vue["par"] as Array).duplicate(),
		"dans_le_cadre": bool(vue["dans_le_cadre"]),
		"capteur_max": snappedf(float(niveau[1]), 0.0001), "capteur_moy": snappedf(float(niveau[0]), 0.0001),
		"lumieres": _noeud.noms_des_lumieres.duplicate(),
		"distance": snappedf(_main.p1.global_position.distance_to(_main.p2.global_position), 0.1),
	}
	ligne.merge(extra)
	var etat := _etat(ligne)
	# Une prise qui n'est ni « accord » ni « noir » dit QUELLES lumières brûlent autour de la cible : c'est ce qui permet de
	# comprendre un « manque » ou un « douteux » sans refaire la séance.
	if etat != "accord" and etat != "noir":
		ligne["lumieres_autour"] = _lumieres_autour(_main.p1.global_position, 520.0)
	_lignes.append(ligne)
	print("  %-14s %-34s modèle %-3s capteur max %.3f moy %.3f  %s%s" % [famille, nom,
		"OUI" if ligne["modele_vu"] else "non", ligne["capteur_max"], ligne["capteur_moy"], etat,
		("  par " + ", ".join(ligne["par"])) if ligne["modele_vu"] else ""])
	if ligne.has("lumieres_autour"):
		for texte in ligne["lumieres_autour"]:
			print("        · " + String(texte))


## Les lumières allumées du jeu à moins de `rayon` px de `centre`, pour le journal : « nom@position e=énergie r=rayon ».
func _lumieres_autour(centre: Vector2, rayon: float) -> Array[String]:
	var sortie: Array[String] = []
	for n in _main.find_children("*", "PointLight2D", true, false):
		var l := n as PointLight2D
		if l == null or not l.enabled or not l.is_visible_in_tree() or l.energy < 0.01:
			continue
		if l.global_position.distance_to(centre) > rayon:
			continue
		var r := float(l.texture.get_width()) * l.texture_scale * 0.5 if l.texture != null else 0.0
		sortie.append("%s/%s@(%.0f,%.0f) e=%.2f r=%.0f" % [l.get_parent().name, l.name, l.global_position.x,
			l.global_position.y, l.energy, r])
	return sortie


## Le jugement d'une ligne.
##   ACCORD    : le modèle voit, le capteur éclaire ;
##   NOIR      : ni l'un ni l'autre ;
##   MANQUE    : le capteur éclaire, le modèle ne voit pas (légitime : il voit moins) ;
##   DOUTEUX   : le modèle voit, le capteur est faible (entre le noir et le seuil d'apparition) ;
##   MALHONNÊTE: le modèle voit, le capteur est NOIR — l'échec du banc.
func _etat(ligne: Dictionary) -> String:
	var m := float(ligne["capteur_max"])
	var vu: bool = ligne["modele_vu"]
	if vu and m < SEUIL_NOIR:
		return "MALHONNÊTE"
	if vu and m < SEUIL_LIT:
		return "douteux"
	if vu:
		return "accord"
	if m >= SEUIL_LIT:
		return "manque"
	return "noir"


func _pol(d: float, deg: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(deg)) * d


## Un point de l'écran du bot, `v` pixels dans les axes de l'écran (x à droite, y vers le bas), ramené au monde.
func _ecran(centre: Vector2, v: Vector2) -> Vector2:
	return centre + v.rotated(-deg_to_rad(Percep.LACET_DEFAUT))


func _voulue(famille: String) -> bool:
	return _familles_voulues.is_empty() or _familles_voulues.has(famille)


# ---------------------------------------------------------------------------
# 1. LE CADRE
# ---------------------------------------------------------------------------

## Les quatre coins de l'écran de la caméra de J2, ramenés au sol, contre ceux du cadre du modèle — dans quatre visées. La
## caméra lisse son décalage (8/s) : on tient la pose assez longtemps pour qu'elle l'ait rejoint.
func _verifier_le_cadre() -> void:
	print("\n[1. Le cadre : l'écran de J2, au sol, contre le cadre du modèle]")
	var cam := _iso._camera_de(1)
	var logique := _iso.viewport_ecran(1).get_visible_rect().size
	var pire := 0.0
	var visees := {"est": Vector2.RIGHT, "ouest": Vector2.LEFT, "nord": Vector2.UP, "sud": Vector2.DOWN}
	for nom in visees:
		var visee: Vector2 = visees[nom]
		_pose(_o, visee, _o + _pol(400.0, 200.0), Vector2.LEFT)
		await _tenir_images(IMAGES_CADRE)
		var reel: Array[Vector2] = []
		for coin in [Vector2.ZERO, Vector2(logique.x, 0.0), logique, Vector2(0.0, logique.y)]:
			reel.append(cam.vers_sol(coin, logique))
		var cadre := Percep.cadre_de_vue(_main.p2.global_position, visee, {"decalage_lisse": _noeud._decalage_lisse})
		var demi: Vector2 = cadre["demi"]
		var modele: Array[Vector2] = []
		for k in [Vector2(-demi.x, -demi.y), Vector2(demi.x, -demi.y), demi, Vector2(-demi.x, demi.y)]:
			modele.append((cadre["centre"] as Vector2) + (k as Vector2).rotated(-deg_to_rad(float(cadre["lacet"]))))
		var ecart := 0.0
		for p in reel:
			var proche := INF
			for q in modele:
				proche = minf(proche, p.distance_to(q))
			ecart = maxf(ecart, proche)
		pire = maxf(pire, ecart)
		print("  visée %-5s : zoom %.2f, centre réel %s, centre du modèle %s, plus grand écart de coin %.2f px" % [nom,
			cam.size, str(((reel[0] + reel[1] + reel[2] + reel[3]) * 0.25).snapped(Vector2(0.1, 0.1))),
			str((cadre["centre"] as Vector2).snapped(Vector2(0.1, 0.1))), ecart])
		# Un point à 3 px DEDANS le cadre du modèle doit être dans l'écran, un point à 3 px DEHORS doit en sortir.
		var faux := 0
		for k in 16:
			# Un point du BORD du rectangle, dans la direction `u` depuis son centre, puis 4 px en dedans et 4 px au-delà.
			var u := Vector2.from_angle(TAU * (float(k) + 0.5) / 16.0)
			var echelle := minf(demi.x / maxf(absf(u.x), 1.0e-6), demi.y / maxf(absf(u.y), 1.0e-6))
			var bord: Vector2 = u * echelle
			for dehors: bool in [false, true]:
				var l: Vector2 = bord + u * (4.0 if dehors else -4.0)
				var monde: Vector2 = (cadre["centre"] as Vector2) + l.rotated(-deg_to_rad(float(cadre["lacet"])))
				var ecran: Vector2 = cam.vers_ecran(monde, logique, 0.0)
				var dans := ecran.x >= 0.0 and ecran.y >= 0.0 and ecran.x <= logique.x and ecran.y <= logique.y
				if dans == dehors:
					faux += 1
		_cadre_verdict[nom] = {"ecart_px": snappedf(ecart, 0.01), "points_faux": faux}
		print("               trente-deux points à ±4 px du bord : %d mal classés" % faux)
	_cadre_verdict["pire_ecart_px"] = snappedf(pire, 0.01)


# ---------------------------------------------------------------------------
# 2. LES SITUATIONS
# ---------------------------------------------------------------------------

func _les_familles() -> void:
	print("\n[2. Les situations : le modèle contre le capteur du corps de la cible]")
	if _voulue("noir"):
		await _famille_noir()
	if _voulue("lampe"):
		await _famille_lampe()
	if _voulue("lampe_mur"):
		await _famille_lampe_mur()
	if _voulue("hors_cadre"):
		await _famille_hors_cadre()
	if _voulue("cone"):
		await _famille_cone()
	if _voulue("cone_mur"):
		await _famille_cone_mur()
	if _voulue("halo"):
		await _famille_halo()
	if _voulue("eclair_cible"):
		await _famille_eclair(false)
	if _voulue("eclair_bot"):
		await _famille_eclair(true)
	if _voulue("fusee"):
		await _famille_fusee()
	if _voulue("fusee_mur"):
		await _famille_fusee_mur()
	if _voulue("murs_bas"):
		await _famille_murs_bas()
	if _voulue("led_murs"):
		await _famille_led_murs()
	if _voulue("plafonnier"):
		await _famille_plafonnier()
	if _voulue("plafonnier_mur"):
		await _famille_plafonnier_mur()
	if _voulue("plafonnier_bas"):
		await _famille_plafonnier_bas()
	# La planche : seulement si on la DEMANDE (`--familles=planche`) — des images, pas des mesures.
	if _familles_voulues.has("planche"):
		await _planche_plafonnier()


## Le noir : ni torche, ni éclair, ni fusée — le corps de la cible, loin du halo du bot, est noir ; le modèle ne voit rien.
func _famille_noir() -> void:
	for b in [180.0, 135.0, 225.0, 90.0, 270.0]:
		for d in [150.0, 300.0, 450.0]:
			_pose(_o, Vector2.LEFT, _o + _pol(d, b), (_o - (_o + _pol(d, b))))
			await _tenir_images(IMAGES_POSE)
			_lire("noir", "à %d px, cap %d°" % [d, b])


## La lampe de la cible : sa torche allumée, sa rétrodiffusion éclaire son corps — le bot le voit à sa lampe, dans le cadre.
func _famille_lampe() -> void:
	for b in [180.0, 135.0, 225.0, 90.0, 270.0]:
		for d in [200.0, 350.0]:
			for face in [true, false]:
				var t := _o + _pol(d, b)
				var vers_o := (_o - t).normalized()
				_pose(_o, Vector2.LEFT, t, vers_o if face else -vers_o, false, true)
				await _tenir_images(IMAGES_POSE)
				_lire("lampe", "à %d px, cap %d°, %s" % [d, b, "de face" if face else "de dos"])


## La lampe derrière la paroi pleine : le capteur lit le corps éclairé par SA rétrodiffusion (il l'est), le modèle exige une
## ligne de vue du bot — il voit MOINS, c'est voulu.
func _famille_lampe_mur() -> void:
	for b in [0.0, 12.0, -12.0]:
		var t := _o + _pol(320.0, b)
		_pose(_o, Vector2.RIGHT, t, (_o - t).normalized(), false, true)
		await _tenir_images(IMAGES_POSE)
		_lire("lampe_mur", "derrière la paroi, cap %d°" % b)


## Hors du cadre de l'écran : la lampe brûle, la ligne est dégagée, l'écran ne la montre pas. Dedans/dehors de chaque côté.
func _famille_hors_cadre() -> void:
	for cote: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		for dehors: bool in [true, false]:
			_pose(_o, Vector2.LEFT, _o + _pol(400.0, 200.0), Vector2.LEFT)
			await _tenir_images(IMAGES_POSE)
			var cadre := Percep.cadre_de_vue(_o, Vector2.LEFT, {"decalage_lisse": _noeud._decalage_lisse})
			var demi: Vector2 = cadre["demi"]
			var reste := Vector2(demi.x * cote.x, demi.y * cote.y)
			var l := reste + cote * (70.0 if dehors else -70.0)
			var t: Vector2 = _ecran(cadre["centre"], l)
			_pose(_o, Vector2.LEFT, t, (_o - t).normalized(), false, true)
			await _tenir_images(IMAGES_POSE)
			_lire("hors_cadre", "bord %s, %s" % [str(cote), "dehors" if dehors else "dedans"])


## Le cône de la torche du bot, visée à l'ouest : axe, flancs, bord (le demi-angle du Parasite est 20,34°), au-delà, et la
## portée (468 px, la limite que le jeu pose). La cible ne porte rien : seule la torche du bot l'éclaire — plus, à moins de
## 128 px, sa rétrodiffusion, que le modèle laisse dehors.
func _famille_cone() -> void:
	var lampe := _o + Vector2(-16.1, 4.55)
	for alpha in [0.0, 8.0, 16.0, 22.0, 30.0, 45.0]:
		for d in [120.0, 250.0, 400.0, 450.0, 500.0]:
			var t := lampe + _pol(d, 180.0 + alpha)
			_pose(_o, Vector2.LEFT, t, Vector2.RIGHT, true, false)
			await _tenir_images(IMAGES_POSE)
			_lire("cone", "à %d px, %d° de l'axe" % [d, alpha])


## Le cône derrière la paroi pleine : la torche du bot est dans l'axe, la cible dans sa portée, un mur entre les deux. Le
## capteur est noir (la lumière du bot ne passe pas) ; **c'est ici que le modèle est pris en faute s'il ignore un mur**.
func _famille_cone_mur() -> void:
	for d in [250.0, 330.0, 420.0]:
		var t := _o + _pol(d, 0.0)
		_pose(_o, Vector2.RIGHT, t, Vector2.LEFT, true, false)
		await _tenir_images(IMAGES_POSE)
		_lire("cone_mur", "derrière la paroi, à %d px" % d)
	# Dans le même axe, la paroi retirée : un témoin, à l'ouest, à la même distance.
	_pose(_o, Vector2.LEFT, _o + _pol(330.0, 180.0), Vector2.RIGHT, true, false)
	await _tenir_images(IMAGES_POSE)
	_lire("cone_mur", "témoin sans mur, à 330 px")


## Le halo de proximité du bot : sa propre lueur éclaire l'ennemi collé à lui (texture de 75 px de rayon), la torche éteinte.
func _famille_halo() -> void:
	for d in [30.0, 45.0, 60.0, 80.0, 110.0, 140.0]:
		var t := _o + _pol(d, 180.0)
		_pose(_o, Vector2.LEFT, t, Vector2.RIGHT)
		await _tenir_images(IMAGES_POSE)
		_lire("halo", "à %d px" % d)


## Un éclair de tir : tiré de la cible (le modèle voit le tireur) ou du bot (il éclaire la cible). L'éclair dure 0,1 s :
## on lit deux images après `trigger_shoot_visuals`, pendant qu'il brûle.
func _famille_eclair(par_le_bot: bool) -> void:
	var famille := "eclair_bot" if par_le_bot else "eclair_cible"
	var distances := [60.0, 100.0, 140.0] if par_le_bot else [100.0, 250.0, 400.0]
	for d in distances:
		var t := _o + _pol(d, 180.0)
		# Le tireur regarde vers l'autre : son canon est du côté de l'autre.
		_pose(_o, Vector2.LEFT, t, Vector2.RIGHT)
		await _tenir_images(IMAGES_POSE)
		var tireur = _main.p2 if par_le_bot else _main.p1
		tireur.trigger_shoot_visuals()
		await _tenir_images(2)
		var brule: bool = tireur.muzzle_flash.enabled and tireur.muzzle_flash.energy > 0.3
		_lire(famille, "à %d px" % d, {"eclair_actif": brule})
		await _tenir_images(IMAGES_POSE)
	if not par_le_bot:
		# Derrière la paroi : la cible tire, son corps est éclairé par son propre éclair ; le modèle exige une ligne de vue.
		var t := _o + _pol(320.0, 0.0)
		_pose(_o, Vector2.RIGHT, t, Vector2.LEFT)
		await _tenir_images(IMAGES_POSE)
		_main.p1.trigger_shoot_visuals()
		await _tenir_images(2)
		_lire(famille, "derrière la paroi, à 320 px", {"eclair_actif": bool(_main.p1.muzzle_flash.enabled)})
		await _tenir_images(IMAGES_POSE)


## Pose une vraie fusée au sol, à `pos`, à l'âge de combustion `age`.
func _poser_une_fusee(pos: Vector2, age: float) -> Node:
	_main._do_spawn_fusee(1, pos, 0.0, 4242)
	await get_tree().process_frame
	var f: Node = null
	for n in get_tree().get_nodes_in_group("fusees"):
		f = n
	if f == null:
		printerr("✗ la fusée n'a pas été posée")
		return null
	f.forcer_age(age)
	f.global_position = pos
	return f


func _retirer_la_fusee(f: Node) -> void:
	if f != null and is_instance_valid(f):
		f.queue_free()
	await _tenir_images(3)


## Une fusée posée à 250 px à l'ouest du bot ; la cible à r px d'elle, au nord ou au sud. À l'allumage (le halo à la portée des
## torches, Q58) et à la braise (l'empreinte habituelle). La torche du bot est éteinte : seule la fusée éclaire.
func _famille_fusee() -> void:
	for age in [0.5, 6.0]:
		var pos_f := _o + _pol(250.0, 180.0)
		_pose(_o, Vector2.LEFT, _o + _pol(400.0, 200.0), Vector2.RIGHT)
		var f := await _poser_une_fusee(pos_f, age)
		if f == null:
			return
		for r in [60.0, 150.0, 250.0, 350.0]:
			for b in [90.0, 270.0]:
				var t := pos_f + _pol(r, b)
				_pose(_o, Vector2.LEFT, t, Vector2.RIGHT)
				await _tenir_images(IMAGES_POSE)
				_lire("fusee", "âge %.1f s, à %d px de la fusée, cap %d°" % [age, r, b],
					{"rayon_halo": snappedf(float((f.get_node("Halo") as Light2D).texture.get_width() * (f.get_node("Halo") as PointLight2D).texture_scale * 0.5), 0.1)})
		await _retirer_la_fusee(f)


## Une fusée de l'autre côté de la paroi pleine, la cible de ce côté-ci à 120 px d'elle : le capteur est noir (la paroi arrête
## la fusée), le modèle ne doit rien voir. Puis, la cible du côté de la fusée et le bot derrière : le capteur est éclairé, le
## modèle exige une ligne de vue — il voit moins.
func _famille_fusee_mur() -> void:
	var pos_f := _o + _pol(330.0, 0.0)
	_pose(_o, Vector2.LEFT, _o + _pol(400.0, 200.0), Vector2.RIGHT)
	var f := await _poser_une_fusee(pos_f, 6.0)
	if f == null:
		return
	var t_ici := Vector2(1010.0, _o.y)
	_pose(_o, Vector2.LEFT, t_ici, Vector2.RIGHT)
	await _tenir_images(IMAGES_POSE)
	_lire("fusee_mur", "la paroi entre la fusée et la cible (à %d px de la fusée)" % t_ici.distance_to(pos_f))
	var t_la := pos_f + Vector2(0.0, 60.0)
	_pose(_o, Vector2.LEFT, t_la, Vector2.RIGHT)
	await _tenir_images(IMAGES_POSE)
	_lire("fusee_mur", "la cible éclairée, le bot derrière la paroi")
	await _retirer_la_fusee(f)


## Les murs bas, à l'est du bot déplacé (il se tient entre la paroi et le mur bas). Le mur bas est à x = 1295-1330 : la cible
## derrière lui, à `k` px de sa face de sortie. Debout, une lumière debout passe par-dessus ; accroupie, la cible tombe dans la
## zone morte (44 px) ; une lumière accroupie bute.
func _famille_murs_bas() -> void:
	var o2 := Vector2(1172.5, _o.y)
	for k in [20.0, 50.0, 80.0]:
		for accroupi in [false, true]:
			var t := Vector2(1330.0 + k, _o.y)
			# La torche du bot (debout) éclaire la cible derrière le mur bas.
			_pose(o2, Vector2.RIGHT, t, Vector2.LEFT, true, false, false, accroupi)
			await _tenir_images(IMAGES_POSE)
			_lire("murs_bas", "torche du bot, cible %s à %d px derrière" % ["ACCROUPIE" if accroupi else "debout", k])
	# Le bot ACCROUPI : sa torche bute sur le mur bas.
	var t2 := Vector2(1330.0 + 50.0, _o.y)
	_pose(o2, Vector2.RIGHT, t2, Vector2.LEFT, true, false, true, false)
	await _tenir_images(IMAGES_POSE)
	_lire("murs_bas", "torche d'un bot ACCROUPI, cible debout à 50 px derrière")
	# La lampe de la cible debout, vue par-dessus le mur bas, et accroupie dans la zone morte.
	for accroupi in [false, true]:
		var t := Vector2(1330.0 + 20.0, _o.y)
		_pose(o2, Vector2.RIGHT, t, Vector2.LEFT, false, true, false, accroupi)
		await _tenir_images(IMAGES_POSE)
		_lire("murs_bas", "lampe de la cible %s à 20 px derrière" % ["ACCROUPIE" if accroupi else "debout"])


## Le bandeau LED des murs (`MurLed`), la seule lumière du jeu que le modèle ne connaît pas et qu'aucune famille ci-dessus n'éteint :
## rien d'allumé, la cible collée à la paroi pleine (à 10, 40, 80 et 150 px de sa face ouest). Le capteur dit si un corps qui
## longe un mur est éclairé ; le modèle, lui, n'a pas cette lumière — il voit MOINS (manque), jamais plus.
func _famille_led_murs() -> void:
	for k in [10.0, 40.0, 80.0, 150.0]:
		var t := Vector2(1050.0 - k, _o.y)
		_pose(_o, Vector2.LEFT, t, Vector2.RIGHT)
		await _tenir_images(IMAGES_POSE)
		_lire("led_murs", "à %d px de la paroi" % k)


## S5 — pose UN plafonnier par `Plafonnier.poser` (l'appel que fera S6), à `pos`, de `rayon` cases et d'énergie `energie`.
func _poser_un_plafonnier(pos: Vector2, rayon: float, energie: float) -> Plafonnier:
	var case := Vector2i(floori(pos.x / TUILE), floori(pos.y / TUILE))
	var liste := Plafonnier.poser(_main.arena, [{"case": case, "rayon": rayon, "intensite": energie}])
	if liste.is_empty():
		printerr("✗ le plafonnier n'a pas été posé")
		return null
	var p: Plafonnier = liste[0]
	# Au point demandé et non au centre de la case : la flaque se mesure à distance exacte.
	p.global_position = pos
	return p


func _retirer_les_plafonniers() -> void:
	Plafonnier.retirer(_main.arena)
	await _tenir_images(3)


## S5 — la FLAQUE : un plafonnier à 300 px à l'ouest du bot, la cible à `f × R` de lui (R = le rayon de la texture), au nord puis
## au sud, aux trois énergies que le jeu permet (`INTENSITE_MIN`, le défaut, `INTENSITE_MAX`). La torche du bot est éteinte et la
## cible ne porte rien : seul le plafonnier l'éclaire. **Ce que le banc cherche : le plus grand `f` où le modèle voit encore sans que
## le capteur soit noir** — `FRACTION_PLAFONNIER` est choisie sous lui, jamais réglée pour que le bot « voie bien ».
func _famille_plafonnier() -> void:
	var rayon_cases := 5.0
	var r_tex := rayon_cases * TUILE
	for energie in [Plafonnier.INTENSITE_MIN, Plafonnier.INTENSITE_PAR_DEFAUT, Plafonnier.INTENSITE_MAX]:
		var pos_p := _o + _pol(300.0, 180.0)
		_pose(_o, Vector2.LEFT, _o + _pol(400.0, 200.0), Vector2.RIGHT)
		var p := _poser_un_plafonnier(pos_p, rayon_cases, energie)
		if p == null:
			return
		for f in [0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.15]:
			for b in [90.0, 270.0]:
				var t := pos_p + _pol(f * r_tex, b)
				_pose(_o, Vector2.LEFT, t, Vector2.RIGHT)
				await _tenir_images(IMAGES_POSE)
				_lire("plafonnier", "énergie %.1f, à %.0f %% du rayon, cap %d°" % [energie, f * 100.0, b],
					{"energie": energie, "fraction": f, "rayon_tex": r_tex})
		await _retirer_les_plafonniers()


## S5 — la FLAQUE ET LE MUR : un plafonnier (6 cases de rayon) à 40 px de la face EST de la paroi pleine, la cible de l'autre côté
## (à l'ouest), à 100 puis 120 px de lui — dans sa flaque, le mur au milieu : le capteur est NOIR, **le modèle est pris en faute
## s'il ignore le mur**. Puis le témoin, à 100 px du plafonnier sans mur entre eux : éclairé. Et la cible du côté du plafonnier, le
## bot derrière la paroi : éclairée, jamais vue (le modèle exige une ligne de vue — il voit moins).
func _famille_plafonnier_mur() -> void:
	var pos_p := Vector2(1085.0 + 40.0, _o.y)
	_pose(_o, Vector2.LEFT, _o + _pol(400.0, 200.0), Vector2.RIGHT)
	var p := _poser_un_plafonnier(pos_p, 6.0, Plafonnier.INTENSITE_PAR_DEFAUT)
	if p == null:
		return
	for d in [100.0, 120.0]:
		var t := Vector2(pos_p.x - d, _o.y)
		_pose(_o, Vector2.LEFT, t, Vector2.RIGHT)
		await _tenir_images(IMAGES_POSE)
		_lire("plafonnier_mur", "la paroi entre le plafonnier et la cible (à %d px de lui)" % d)
	# Le témoin : à 100 px du plafonnier vers le nord, sans mur entre eux, dans le champ d'un bot du même côté de la paroi.
	var t_nord := pos_p + Vector2(0.0, -100.0)
	_pose(Vector2(1172.5, _o.y), Vector2.RIGHT, t_nord, Vector2.LEFT)
	await _tenir_images(IMAGES_POSE)
	_lire("plafonnier_mur", "le témoin sans mur, à 100 px du plafonnier, le bot du même côté")
	# Le bot derrière la paroi, la cible dans la flaque : éclairée, jamais vue.
	var t_la := pos_p + Vector2(0.0, 40.0)
	_pose(_o, Vector2.RIGHT, t_la, Vector2.LEFT)
	await _tenir_images(IMAGES_POSE)
	_lire("plafonnier_mur", "la cible dans la flaque, le bot derrière la paroi")
	# Le capteur de SOI du bot (son propre corps, dans sa propre vue : `masque_de_soi`, le bit 256 de J2) : derrière la paroi, dans la
	# flaque du plafonnier, il doit être NOIR ; au même écart sans mur, éclairé. C'est la moitié du masque d'ombre que le capteur
	# croisé de la cible ne mesure pas.
	_pose(Vector2(pos_p.x - 100.0, _o.y), Vector2.LEFT, _o + _pol(400.0, 200.0), Vector2.RIGHT)
	await _tenir_images(IMAGES_POSE)
	_lire_soi("le bot à 100 px du plafonnier, la paroi entre eux", true)
	_pose(pos_p + Vector2(0.0, -100.0), Vector2.LEFT, _o + _pol(400.0, 200.0), Vector2.RIGHT)
	await _tenir_images(IMAGES_POSE)
	_lire_soi("le bot à 100 px du plafonnier, sans mur", false)
	await _retirer_les_plafonniers()


## Le capteur de soi de J2 dans sa propre vue, à l'instant : consigné, jugé (noir attendu, ou éclairé).
func _lire_soi(nom: String, noir_attendu: bool) -> void:
	var niveau := _niveau(1, 1)
	var m := float(niveau[1])
	var ok := m < SEUIL_NOIR if noir_attendu else m >= SEUIL_LIT
	_soi.append({"nom": nom, "capteur_max": snappedf(m, 0.0001), "noir_attendu": noir_attendu, "ok": ok})
	print("  plafonnier_soi %-46s capteur de SOI max %.3f  %s" % [nom, m, "ok" if ok else "ÉCHEC (%s attendu)" % ("noir" if noir_attendu else "éclairé")])


## S5 — la FLAQUE ET LE MUR BAS : le plafonnier (9 cases de rayon) à 127 px de la face de sortie du mur bas, la cible derrière. La
## lampe est PLUS HAUTE que le muret : sa lumière passe par-dessus et laisse derrière lui une zone morte FINIE de `D × (h_mur − h_c)
## / (h_lampe − h_mur)` — 35 px pour un corps accroupi à cette distance, rien pour un corps debout. Une cible accroupie dedans : le
## capteur est NOIR (**le modèle est pris en faute s'il ignore le mur bas**) ; au-delà : éclairé. Debout : éclairé partout.
##
## ⚠️ Les cibles sont à 22 px et plus de la face de sortie : plus près, le CENTRE du corps est « dans la pierre » (`RAYON_DEDANS`,
## 16 px) et `Player` ne se laisse pas accroupir (l'enjambement le tient debout) — la première version de la famille posait une cible
## à 10 px : « ACCROUPIE » dans le journal, debout dans le jeu, capteur éclairé, et la prise suivante en gardait l'état. Le banc lit donc
## la posture RÉELLE (`accroupi_reel`) et ÉCHOUE sur une prise qui n'est pas celle qu'il annonce.
##
## ⚠️ **Ce que cette famille ne peut PAS prendre en faute : un modèle qui ignorerait le mur bas pour la LUMIÈRE.** Sabotage essayé
## (la ligne de vue de la lampe au mur bas retirée du modèle) : banc vert, zéro prise malhonnête. Dans le rayon que le modèle retient
## (au plus 60 % de 9 cases, plus le bord du corps), la zone morte de la lampe haute d'un accroupi (au plus ~40 px) est toujours
## INCLUSE dans celle que la règle du jeu donne à l'œil du bot (44 px) : l'œil bute déjà là où la lampe butterait, et le modèle dit
## « non » par lui. La règle de la lampe ne se discrimine qu'avec un rayon que le jeu ne permet pas : c'est le rôle de
## `tools/test_plafonniers.gd` (disque de 400 px), pas de ce banc.
func _famille_plafonnier_bas() -> void:
	var o2 := Vector2(1172.5, _o.y)
	var pos_p := Vector2(1200.0, _o.y)
	_pose(o2, Vector2.RIGHT, o2 + _pol(200.0, 20.0), Vector2.LEFT)
	var p := _poser_un_plafonnier(pos_p, 9.0, Plafonnier.INTENSITE_PAR_DEFAUT)
	if p == null:
		return
	for k in [22.0, 40.0, 70.0]:
		for accroupi in [false, true]:
			var t := Vector2(1330.0 + k, _o.y)
			_pose(o2, Vector2.RIGHT, t, Vector2.LEFT, false, false, false, accroupi)
			await _tenir_images(IMAGES_POSE)
			var reel := bool(_main.p1.accroupi)
			_lire("plafonnier_bas", "cible %s à %d px derrière le mur bas" % ["ACCROUPIE" if accroupi else "debout", k],
				{"accroupi_reel": reel, "posture_obtenue": reel == accroupi})
	await _retirer_les_plafonniers()


## S5 — la PLANCHE du plafonnier, à regarder : la vue de J2 (le bot) en iso, un plafonnier à 105 px à l'ouest du mur bas et à 105 px à
## l'est de la paroi pleine, la cible debout dans sa flaque. Quatre images dans le dossier de sortie : `plafonnier_noir.png` (rien
## d'allumé), `plafonnier_flaque.png` (la flaque, ses ombres de murs, la zone morte du muret, le luminaire), `plafonnier_accroupi.png`
## (la cible accroupie derrière le muret) et `plafonnier_sans_luminaire.png` (le luminaire retiré du suivi, pour juger ce qu'il ajoute).
## Un banc qui ne se regarde pas ne prouve pas ce qu'on voit : l'œil juge ce que le capteur ne dit pas.
func _planche_plafonnier() -> void:
	print("\n[Planche : le plafonnier, en iso, vu du bot]")
	var o2 := Vector2(1172.5, _o.y + 70.0)
	var cible := Vector2(1175.0, _o.y - 60.0)
	_pose(o2, Vector2.LEFT, cible, Vector2.DOWN)
	await _tenir_images(IMAGES_POSE * 3)
	await _photo("plafonnier_noir")
	var p := _poser_un_plafonnier(Vector2(1190.0, _o.y), 6.0, Plafonnier.INTENSITE_PAR_DEFAUT)
	if p == null:
		return
	await _tenir_images(IMAGES_POSE * 3)
	await _photo("plafonnier_flaque")
	_pose(o2, Vector2.LEFT, Vector2(1360.0, _o.y), Vector2.LEFT, false, false, false, true)
	await _tenir_images(IMAGES_POSE * 3)
	await _photo("plafonnier_accroupi")
	var miroirs = _iso.get("_miroirs")
	var volumes = miroirs.get("volumes") if miroirs != null else null
	if volumes != null:
		volumes.set("lueurs_actives", false)
		_pose(o2, Vector2.LEFT, cible, Vector2.DOWN)
		await _tenir_images(IMAGES_POSE * 3)
		await _photo("plafonnier_sans_luminaire")
		volumes.set("lueurs_actives", true)
	await _retirer_les_plafonniers()


func _photo(nom: String) -> void:
	_au_premier_plan()
	var img: Image = await Commun.capturer(get_tree(), 3000)
	if img == null:
		print("  (pas de capture pour %s)" % nom)
		return
	img.save_png("%s/%s.png" % [_dossier, nom])
	print("  · %s.png (%dx%d)" % [nom, img.get_width(), img.get_height()])


# ---------------------------------------------------------------------------
# LE VERDICT
# ---------------------------------------------------------------------------

func _compter(famille: String = "") -> Dictionary:
	var c := {"n": 0, "accord": 0, "noir": 0, "manque": 0, "douteux": 0, "malhonnete": 0, "modele_vu": 0, "capteur_lit": 0}
	for l in _lignes:
		if famille != "" and l["famille"] != famille:
			continue
		c["n"] += 1
		if l["modele_vu"]:
			c["modele_vu"] += 1
		if float(l["capteur_max"]) >= SEUIL_LIT:
			c["capteur_lit"] += 1
		match _etat(l):
			"accord":
				c["accord"] += 1
			"noir":
				c["noir"] += 1
			"manque":
				c["manque"] += 1
			"douteux":
				c["douteux"] += 1
			"MALHONNÊTE":
				c["malhonnete"] += 1
	return c


func _echec() -> bool:
	if _compter()["malhonnete"] > 0 or _lignes.is_empty():
		return true
	for l in _lignes:
		if l.has("posture_obtenue") and not bool(l["posture_obtenue"]):
			return true
	for l in _soi:
		if not bool(l["ok"]):
			return true
	for nom in _cadre_verdict:
		if nom == "pire_ecart_px":
			continue
		if int(_cadre_verdict[nom]["points_faux"]) > 0 or float(_cadre_verdict[nom]["ecart_px"]) > 6.0:
			return true
	return false


func _verdict() -> void:
	print("\n=== Verdict ===")
	print("  LE CADRE : plus grand écart de coin entre l'écran réel de J2 et le cadre du modèle : %.2f px (seuil 6 px)"
		% float(_cadre_verdict.get("pire_ecart_px", -1.0)))
	for nom in _cadre_verdict:
		if nom == "pire_ecart_px":
			continue
		print("    visée %-5s : écart %.2f px, %d point(s) mal classé(s) sur 32" % [nom, float(_cadre_verdict[nom]["ecart_px"]),
			int(_cadre_verdict[nom]["points_faux"])])
	print("  LES SITUATIONS (le capteur éclairé = maximum d'anneau ≥ %.2f ; noir = < %.2f) :" % [SEUIL_LIT, SEUIL_NOIR])
	print("    %-14s %4s %8s %8s %7s %6s %7s %8s %11s" % ["famille", "n", "modèle", "capteur", "accord", "noir", "manque",
		"douteux", "MALHONNÊTE"])
	var familles: Array[String] = []
	for l in _lignes:
		if not familles.has(String(l["famille"])):
			familles.append(String(l["famille"]))
	for f in familles:
		var c := _compter(f)
		print("    %-14s %4d %8d %8d %7d %6d %7d %8d %11d" % [f, c["n"], c["modele_vu"], c["capteur_lit"], c["accord"], c["noir"],
			c["manque"], c["douteux"], c["malhonnete"]])
	var t := _compter()
	print("    %-14s %4d %8d %8d %7d %6d %7d %8d %11d" % ["TOTAL", t["n"], t["modele_vu"], t["capteur_lit"], t["accord"], t["noir"],
		t["manque"], t["douteux"], t["malhonnete"]])
	var taux := 100.0 * float(t["accord"]) / maxf(float(t["capteur_lit"]), 1.0)
	print("  TAUX D'ACCORD : de %d prises où le capteur éclaire le corps, le modèle en voit %d (%.1f %%) — le reste est ce que le"
		% [t["capteur_lit"], t["accord"], taux])
	print("    modèle laisse dans le noir (rétrodiffusion, hors cadre, corps éclairé derrière un mur) : LÉGITIME, il voit moins.")
	print("  MALHONNÊTETÉ : %d prise(s) où le modèle voit un corps que le capteur laisse NOIR%s" % [t["malhonnete"],
		" — ÉCHEC" if int(t["malhonnete"]) > 0 else " — aucune"])
	if int(t["douteux"]) > 0:
		print("    (%d prise(s) douteuse(s) : le modèle voit, le capteur est entre %.2f et %.2f — à regarder.)"
			% [t["douteux"], SEUIL_NOIR, SEUIL_LIT])
	if not _soi.is_empty():
		var faux := _soi.filter(func(l: Dictionary) -> bool: return not bool(l["ok"])).size()
		print("  LE CAPTEUR DE SOI sous un plafonnier : %d prise(s), %d hors de ce que le mur commande%s" % [_soi.size(), faux,
			" — ÉCHEC" if faux > 0 else " — le mur noircit le corps de soi, l'absence de mur l'éclaire"])
	# Le témoin : le banc ne vaut que s'il a vu le capteur noir ET éclairé.
	if int(t["noir"]) + int(t["manque"]) + int(t["accord"]) + int(t["douteux"]) == 0 or int(t["capteur_lit"]) == 0:
		print("  ✗ le capteur n'a jamais été éclairé : le banc ne discrimine rien.")
	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"commit": _commit(), "cadre": _cadre_verdict, "total": t, "taux_d_accord": snappedf(taux, 0.1),
		"seuil_noir": SEUIL_NOIR, "seuil_lit": SEUIL_LIT, "prises": _lignes, "capteur_de_soi": _soi}, "  "))
	f.close()
	print("  journal : %s/journal.json" % ProjectSettings.globalize_path(_dossier))
