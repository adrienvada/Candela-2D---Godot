## Banc de cadence d'image en conditions de pire cas, FENÊTRÉ.
##
## La passe de performance de l'étape 9 avait été mesurée côté CPU seulement
## (`bench_particles.gd`, headless). Déplafonner la cadence d'image déplace la
## question sur le GPU : le jeu tient-il réellement au-dessus de 120 fps quand
## les deux vues rendent, torches allumées, pendant un échange au pompe ?
##
## Headless ne répond pas — rien n'est rasterisé. Ce banc ouvre donc une vraie
## fenêtre. Il n'est jamais lancé par le jeu.
##
## Lancer : godot --path . res://tools/bench_framerate.tscn -- [--seconds 15] [--max-fps 0]
extends Node

const WARMUP_SEC := 2.0
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
var _seconds := 15.0
var _peak_particles := 0
var _peak_bullets := 0
## Postes RETIRÉS de la charge. Les trois drapeaux se composent, ce qui donne les
## sept configurations utiles sans en inventer d'autres.
var _sans_vue := false
var _sans_torches := false
var _sans_shaders := false
## Mode menus (session voisine), qui n'est pas une variante du duel.
var _variante := ""
## Mesure la charge des MENUS au lieu du duel. Voir `_stress_menus()`.
var _menus := false


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
	Engine.max_fps = int(_value(args, "--max-fps", "0"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

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
	if args.has("--menus"):
		_variante = "--menus"

	print("=== Banc de cadence d'image ===")
	print("Charge: %s" % _libelle_charge())
	print("Plafond: %s | vsync: désactivé" % ("aucun" if Engine.max_fps == 0 else str(Engine.max_fps)))

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
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
	print("Échauffement %.0f s (chargement des shaders, remplissage du pool)…" % WARMUP_SEC)
	await _stress(WARMUP_SEC, false)

	print("Mesure sur %.0f s…" % _seconds)
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
		for p in [_main.p1, _main.p2]:
			p.hp = 100.0
			# Torches éteintes : c'est le seul geste du duel qu'on retire, et il
			# emporte avec lui les Light2D, leurs ombres portées et la
			# rétrodiffusion. Le reste de la boucle est identique au mot près.
			p.flashlight_on = not _sans_torches
			if p.shoot_cooldown <= 0.0:
				p.shoot()
		# Se viser mutuellement : les balles portent, donc les impacts aussi.
		_main.p1.rotation = (_main.p2.global_position - _main.p1.global_position).angle()
		_main.p2.rotation = (_main.p1.global_position - _main.p2.global_position).angle()

		if sampling:
			# Le temps de CETTE image. La première après l'échauffement peut
			# porter le coût d'un changement d'état ; elle compte quand même,
			# c'est une saccade que le joueur verrait.
			var dt := get_process_delta_time()
			if dt > 0.0:
				_samples.append(dt)
			# Relevés au vol : lus après la boucle ils vaudraient zéro, et le
			# banc prétendrait mesurer une charge qu'il n'aurait pas prouvée.
			_peak_particles = maxi(_peak_particles, _main.particle_pool.active_count())
			_peak_bullets = maxi(_peak_bullets, _main.bullet_container.get_child_count())


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
	if retires.is_empty():
		return "duel complet"
	if retires.size() == 3:
		return "socle nu (tout retiré)"
	return "duel " + ", ".join(retires)

func _appliquer_variante() -> void:
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

	print("\n=== RÉSULTAT (%s) ===" % _libelle_charge())
	print("  Images mesurées  : %d en %.1f s" % [sorted.size(), total])
	print("  FPS moyen        : %.0f" % avg)
	print("  FPS médian       : %.0f" % (1.0 / sorted[sorted.size() / 2]))
	print("  FPS 1 %% bas      : %.0f  (moyenne des %d images les plus lentes)"
		% [low1, lents])
	print("  Image la plus lente : %.1f ms  (soit %.0f fps)"
		% [sorted[sorted.size() - 1] * 1000.0, 1.0 / sorted[sorted.size() - 1]])
	print("  Particules (pic) : %d / %d" % [_peak_particles, ParticlePool.MAX_ACTIVE])
	print("  Balles (pic)     : %d" % _peak_bullets)
	print("  Verdict 120 fps  : %s" % ("TENU" if low1 >= 120.0 else "NON TENU (1 %% bas à %.0f)" % low1))


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
	for groupe in ["p1_weapon_group", "p2_weapon_group"]:
		if groupe in ui:
			var g: ButtonGroup = ui.get(groupe)
			if g == null or g.get_buttons().size() <= SHOTGUN_INDEX:
				absents.append("UI.%s n'a plus d'arme à l'indice %d (pompe)"
					% [groupe, SHOTGUN_INDEX])
	return absents


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
