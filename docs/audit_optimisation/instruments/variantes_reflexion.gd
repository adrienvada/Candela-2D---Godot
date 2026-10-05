## Variantes « par réflexion » de l'audit M — INSTRUMENT TEMPORAIRE, jamais commité.
##
## Retirent UNE nouveauté du rendu sans toucher au code du jeu : elles posent, juste avant chaque dessin
## (`RenderingServer.frame_pre_draw`), l'état voulu sur les nœuds de la scène — aucun script du jeu ne peut le défaire entre-temps.
##
##   --v-sans-ombres-2d   shadow_enabled = false sur TOUTES les Light2D du monde (les passes d'ombre 2D disparaissent des lightmaps, des
##                        capteurs et de la vue de dessus) ;
##   --v-sans-capteurs    chaque CapteurCorps (SubViewport 256², le monde 2D re-rendu sous chaque corps) en UPDATE_DISABLED ;
##   --v-sans-halos       le halo de proximité (`Player.ambient_light`) de chaque corps éteint (enabled = false) ;
##   --v-sans-retro       la rétrodiffusion (`BodyLight`) de chaque corps éteinte ;
##   --v-sans-voile       le voile d'éblouissement (p1_dazzle, p2_dazzle) et sa copie de tampon (VoileBB) cachés ;
##   --v-sans-plafonniers les halos des plafonniers (groupe « plafonniers ») éteints ;
##   --v-sans-torches-pnj les torches des PNJ (leur Flashlight) éteintes à chaque image ;
##   --v-tient-flash      (D1 de V8) deux PointLight2D ÉTEINTES posées une fois, qui tiennent en permanence `LightTextures.FLASH[1]` et `FLASH[2]` :
##                        les textures que le flash de bouche pose à chaque tir et qu'aucune autre lumière ne tient — A = dépôt contre B = ceci ;
##   --v-bascule-flash    (D1 de V8, banc amplifié) une PointLight2D éteinte dont la texture alterne à CHAQUE image entre `FLASH[1]` et `FLASH[2]`, textures
##                        tenues par personne : une reconstruction de l'atlas des lumières par image ;
##   --v-bascule-flash-tenu  la même bascule, mais `FLASH[1]` et `FLASH[2]` tenues par deux lumières éteintes : aucune reconstruction (la référence) ;
##   --v-repos            (Q81, le plancher d'auto-éblouissement) la scène « au repos » : à chaque pas de physique, J2 est CACHÉ (hors jeu, comme à
##                        l'entraînement : sa torche n'éblouit plus J1, qui ne tient alors que la rétrodiffusion de sa PROPRE torche, 0,06) et plus personne
##                        ne tire (le délai de tir est tenu haut) — avec `--M-sans-fusee`, plus aucune source éblouissante que la propre torche de J1 ;
##   --v-sans-arene-menu  vp1 et vp2 (les SubViewport qui rendent l'arène) en UPDATE_DISABLED à chaque image — au hub, ils rendent l'arène en
##                        UPDATE_ALWAYS derrière le rideau du menu (`game_state.gd` `_accorder_rendu_aux_vues`).
extends RefCounted

var arene_menu := false
var tient_flash := false
var repos := false
var bascule_flash := false
var bascule_tenu := false
var _sonde_flash: PointLight2D = null
var _textures_flash: Array = []
var _tenus: Array = []
var ombres := false
var capteurs := false
var halos := false
var retro := false
var voile := false
var plafonniers := false
var torches_pnj := false

var _arbre: SceneTree = null
var _main: Node = null
var _ui: Node = null
var _lumieres: Array = []
var _capteurs: Array = []
var _n := 0


func _init(args: PackedStringArray) -> void:
	ombres = args.has("--v-sans-ombres-2d")
	capteurs = args.has("--v-sans-capteurs")
	halos = args.has("--v-sans-halos")
	retro = args.has("--v-sans-retro")
	voile = args.has("--v-sans-voile")
	plafonniers = args.has("--v-sans-plafonniers")
	torches_pnj = args.has("--v-sans-torches-pnj")
	arene_menu = args.has("--v-sans-arene-menu")
	tient_flash = args.has("--v-tient-flash")
	repos = args.has("--v-repos")
	bascule_flash = args.has("--v-bascule-flash")
	bascule_tenu = args.has("--v-bascule-flash-tenu")


func actif() -> bool:
	return ombres or capteurs or halos or retro or voile or plafonniers or torches_pnj or arene_menu or tient_flash or bascule_flash or bascule_tenu or repos


func description() -> String:
	var l: PackedStringArray = []
	for e in [["ombres 2D", ombres], ["capteurs", capteurs], ["halos de proximité", halos], ["rétrodiffusion", retro], ["voile", voile],
			["plafonniers", plafonniers], ["torches des PNJ", torches_pnj], ["arène sous le menu (vp1/vp2)", arene_menu], ["FLASH[1] et FLASH[2] tenues par deux lumières éteintes", tient_flash],
			["bascule de texture à chaque image (atlas)", bascule_flash], ["bascule de texture à chaque image, textures tenues", bascule_tenu],
			["scène au repos (J2 caché, sans tir)", repos]]:
		if e[1]:
			l.append(e[0])
	return ", ".join(l) if not l.is_empty() else "aucune"


## À appeler quand le jeu est monté (l'arbre, GameState, l'UI) ; branche le crochet d'avant-dessin.
func brancher(arbre: SceneTree, main: Node) -> void:
	_arbre = arbre
	_main = main
	_ui = main.get("ui") if main != null else null
	if repos and not arbre.physics_frame.is_connected(_repos_physique):
		arbre.physics_frame.connect(_repos_physique)
	if actif() and not RenderingServer.frame_pre_draw.is_connected(_avant_dessin):
		RenderingServer.frame_pre_draw.connect(_avant_dessin)
		print("[M] variantes par réflexion branchées : retirées = %s" % description())


func _avant_dessin() -> void:
	if _arbre == null or _main == null or not is_instance_valid(_main):
		return
	_n += 1
	if tient_flash and _tenus.is_empty():
		var lt: GDScript = load("res://light_textures.gd") as GDScript
		var chemins: Array = lt.get_script_constant_map()["FLASH"]
		for i in [1, 2]:
			var l := PointLight2D.new()
			l.name = "TientFlash%d" % i
			l.enabled = false
			l.texture = lt.call("masque", chemins[i])
			l.texture_scale = 64.0 / float(l.texture.get_width()) if l.texture != null else 1.0
			_main.add_child(l)
			_tenus.append(l)
		print("[M] --v-tient-flash : %d lumières éteintes tiennent FLASH[1] et FLASH[2] (%s, %s)" % [_tenus.size(), str(chemins[1]), str(chemins[2])])
	if (bascule_flash or bascule_tenu) and _sonde_flash == null:
		var lt2: GDScript = load("res://light_textures.gd") as GDScript
		var chemins2: Array = lt2.get_script_constant_map()["FLASH"]
		for i in [1, 2]:
			_textures_flash.append(lt2.call("masque", chemins2[i]))
		if bascule_tenu:
			for i in 2:
				var h := PointLight2D.new()
				h.name = "TientFlashBascule%d" % (i + 1)
				h.enabled = false
				h.texture = _textures_flash[i]
				_main.add_child(h)
				_tenus.append(h)
		_sonde_flash = PointLight2D.new()
		_sonde_flash.name = "SondeFlash"
		_sonde_flash.enabled = false
		_main.add_child(_sonde_flash)
		print("[M] bascule de texture : %s (%s, %s)" % ["TENUES (référence)" if bascule_tenu else "NON tenues (une reconstruction d'atlas par image)", str(chemins2[1]), str(chemins2[2])])
	if _sonde_flash != null and is_instance_valid(_sonde_flash):
		_sonde_flash.texture = _textures_flash[_n % 2]
	# Les listes se rafraîchissent toutes les 10 images (un nœud naît ou meurt : tirs, étincelles, PNJ).
	if _n % 10 == 1:
		_lumieres = _arbre.root.find_children("*", "Light2D", true, false)
		_capteurs.clear()
		for n in _arbre.root.find_children("*", "SubViewport", true, false):
			var s: Script = (n as Node).get_script()
			if s != null and s.get_global_name() == &"CapteurCorps":
				_capteurs.append(n)
	if ombres:
		for l in _lumieres:
			if is_instance_valid(l):
				(l as Light2D).shadow_enabled = false
	if capteurs:
		for c in _capteurs:
			if is_instance_valid(c):
				(c as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	var corps: Array = _arbre.get_nodes_in_group("players")
	for joueur in [_main.get("p1"), _main.get("p2")]:
		if joueur != null and is_instance_valid(joueur) and not corps.has(joueur):
			corps.append(joueur)
	if halos or retro:
		for p in corps:
			if not is_instance_valid(p):
				continue
			if halos and p.get("ambient_light") != null and is_instance_valid(p.ambient_light):
				p.ambient_light.enabled = false
			if retro and p.get("body_light") != null and is_instance_valid(p.body_light):
				p.body_light.enabled = false
	if torches_pnj:
		for p in corps:
			if is_instance_valid(p) and bool(p.get("est_pnj")) and p.get("flashlight") != null:
				p.flashlight.enabled = false
	if plafonniers:
		for pl in _arbre.get_nodes_in_group("plafonniers"):
			if is_instance_valid(pl) and pl.get("halo") != null and is_instance_valid(pl.halo):
				pl.halo.enabled = false
	if voile and _ui != null and is_instance_valid(_ui):
		for nom in ["p1_dazzle", "p2_dazzle", "_voile_bb"]:
			var v: Variant = _ui.get(nom)
			if v != null and is_instance_valid(v):
				(v as CanvasItem).visible = false
	if arene_menu:
		for nom in ["vp1", "vp2"]:
			var vp: Variant = _main.get(nom)
			if vp != null and is_instance_valid(vp):
				(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED


## `--v-repos` : avant chaque pas de physique, J2 est caché (hors jeu : plus une source d'éblouissement) et le délai de tir est tenu haut. Le banc de cadence re-vise et re-tire
## dans son `_process` (après la physique) ; ce crochet passe AVANT la physique suivante, qui est ce qui calcule `dazzle_amount`.
func _repos_physique() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	var j1: Variant = _main.get("p1")
	var j2: Variant = _main.get("p2")
	if j1 == null or j2 == null or not is_instance_valid(j1) or not is_instance_valid(j2):
		return
	# J2 est CACHÉ, comme à l'entraînement : `GameState._en_jeu(j)` (`visible` et vivant) l'écarte de `_sources_eblouissantes()`, donc plus aucune
	# torche adverse n'éblouit J1 — qui ne tient plus que la rétrodiffusion de sa PROPRE torche (0,06). (Le banc re-vise J2 vers J1 dans son
	# `_process`, avant celui de `GameState` qui calcule l'éblouissement : tourner le dos ne servirait à rien.) Plus aucun tir : le délai est tenu haut.
	j2.visible = false
	j1.shoot_cooldown = 99.0
	j2.shoot_cooldown = 99.0
