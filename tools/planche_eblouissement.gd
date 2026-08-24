extends Node

## La planche de contact de l'ÉBLOUISSEMENT — une image par état, et les
## chiffres qui vont avec.
##
## ## Pourquoi ce banc existe alors que trois suites couvrent déjà la mécanique
##
## `test_eblouissement` prouve le modèle, `test_vision` la géométrie, et
## `test_online_match --eblouissement` le câblage entre les deux. **Aucun des
## trois ne regarde l'écran.** Or le défaut d'origine (2026-08-18) n'était pas
## seulement que la valeur ne montait pas : c'était que *ce qu'on subit* et *ce
## qu'on voit* n'avaient jamais été comparés. Un cône écrit en dur à 30° pour
## quatre armes qui vont de 5° à 60° ne se voit que sur une image.
##
## Ce banc n'affirme donc presque rien : il **pose** des images et **imprime**
## des mesures, à charge d'un humain de dire si c'est bon. C'est la règle de
## `planche_contact.gd`, appliquée à une mécanique plutôt qu'à des écrans : pas
## d'image de référence, pas de seuil, rien qui se périme.
##
## Les deux seules choses qu'il refuse sont des propriétés d'équité, pas de
## goût : **éblouir J2 ne doit rien changer à la vue de J1**, et **rien ne doit
## rester blanc** après la fin d'une manche.
##
## ## Trois pièges payés en l'écrivant, et qui valent pour tout banc de rendu
##
## 1. **Mesurer et photographier sont deux passes, jamais une.** La première
##    version relevait le chronomètre entre deux captures : chaque capture coûte
##    350 ms de repos plus le temps du rendu, si bien que les « jalons » lus
##    étaient des majorants de 200 ms, pas des mesures. Elles annonçaient une
##    montée à 0,57 s là où le modèle en promet 0,40. **Le banc mesurait sa
##    propre lenteur.**
## 2. **Le tir tue le sujet.** Faire tirer J1 sur J2 à bout portant termine la
##    manche au milieu du relevé, et tout ce qui suit rend zéro sans rien dire.
##    Le flash est donc mesuré **à 90° de l'axe de visée** : les balles partent
##    droit devant et manquent, la ligne de vue reste franche — et l'absence de
##    cône, qui est la propriété voulue du flash, se trouve prouvée au passage.
## 3. **macOS bride le rendu d'une fenêtre qui n'est pas au premier plan**, au
##    point que `frame_post_draw` cesse d'être émis. Un banc lancé depuis un
##    terminal perd le focus dès que le terminal le reprend. La fenêtre est donc
##    remise au premier plan avant chaque capture, et une capture manquée est
##    retentée une fois avant d'être déclarée perdue.
##
## Lancer, SANS --headless (rien n'y est rastérisé) :
##   godot --path . res://tools/planche_eblouissement.tscn

const Commun := preload("res://tools/rendu_commun.gd")
const Eblouissement := preload("res://eblouissement.gd")
## `vision.gd` n'a pas de `class_name` : il se preload, comme le fait
## `game_state.gd`. Le nommer sans le charger passe l'analyse du fichier et
## échoue à l'exécution — la scène tourne alors SANS script, sans jamais sortir.
const Vision := preload("res://vision.gd")

## Le temps qu'on laisse au jeu avant de photographier : les fondus finissent,
## les shaders se compilent. Plus court, on photographie une transition et la
## planche ment sur l'état qu'elle annonce.
const REPOS := 0.35

## Distance entre les deux joueurs pendant les mesures de faisceau. 80 px : dans
## la même flaque de lumière et la même cellule ouverte quelle que soit la
## carte, et deux corps de 18 px de rayon ne s'y touchent pas. C'est la valeur
## qu'emploie déjà `test_online_match --eblouissement`, et la reprendre permet
## de comparer les deux relevés.
const CORPS_A_CORPS := 80.0

var _main: Node
var _ui: Node
var _n := 0
var _echecs := 0
var _perdues := 0
var _dossier := "user://planche-eblouissement"
var _journal: Array[String] = []


## Les appuis de cette planche sur le jeu, sous une forme qu'une suite headless
## peut vérifier — `tools/test_banc.gd` les lit.
##
## **Un banc qui ouvre une fenêtre ne peut être dans aucune suite headless, donc
## rien ne surveille sa péremption.** Le dépôt l'a déjà payé : `bench_framerate`
## pilotait un bouton disparu à la refonte des menus, s'ouvrait, levait une
## erreur, n'entrait jamais dans le duel et restait ouvert sans rien mesurer —
## découvert une semaine plus tard, à la minute où le chiffre était demandé.
##
## Cette planche est exactement dans ce cas, et le pire moment pour la découvrir
## cassée est identifiable d'avance : le jour où l'éblouissement sera à rejuger
## après le lot des cookies de torche. D'où cette liste, écrite le jour même où
## la planche est née plutôt qu'après la première panne.
##
## `Commun.preconditions_manquantes` couvre déjà le socle partagé avec la
## planche des menus ; ce qui suit est ce que celle-ci ajoute — et elle ajoute
## beaucoup, puisqu'elle pilote une manche entière au lieu de traverser des
## écrans.
static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents

	for prop in ["p1", "p2", "round_active", "countdown_left", "time_left"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	# `_ligne_de_vue` est privée et la planche l'appelle quand même : c'est le
	# seul moyen de dire « un mur s'est glissé entre les deux » plutôt que de
	# rendre un zéro qu'on prendrait pour un défaut d'éblouissement.
	for methode in ["_on_replay_requested", "weapon_for_index", "_ligne_de_vue"]:
		if not main.has_method(methode):
			absents.append("GameState.%s() a disparu" % methode)

	if not ui.has_method("update_hud"):
		absents.append("UI.update_hud() a disparu")
	if not "SCREEN_LOCAL" in ui:
		absents.append("UI.SCREEN_LOCAL a disparu")

	# Le joueur est interrogé sur son SCRIPT et non sur une instance : au moment
	# où la suite regarde, la manche n'a pas commencé et `p1` peut être nul.
	var script_joueur := load("res://player.gd") as GDScript
	if script_joueur == null:
		absents.append("player.gd est introuvable")
	else:
		var noms := {}
		for m in script_joueur.get_script_method_list():
			noms[m["name"]] = true
		for methode in ["equip_weapon", "shoot", "take_damage", "integrer_eblouissement"]:
			if not noms.has(methode):
				absents.append("Player.%s() a disparu" % methode)

	# Les deux touches que la planche presse. Une action retirée de l'Input Map
	# ferait `action_press` sur du vide : la torche ne s'allumerait jamais et
	# tout le relevé rendrait zéro, ce qui ressemble trait pour trait au défaut
	# de 2026-08-18 qu'elle est censée surveiller.
	for action in ["p1_torch", "p2_torch"]:
		if not InputMap.has_action(action):
			absents.append("l'action « %s » a disparu de l'Input Map" % action)

	# Le modèle et l'arme, lus par la planche pour imprimer ce qu'elle juge.
	var modele := load("res://eblouissement.gd") as GDScript
	if modele == null:
		absents.append("eblouissement.gd est introuvable")
	else:
		for constante in ["MONTEE_PAR_S", "DESCENTE_PAR_S", "PIC_FLASH",
				"PORTEE_FLASH", "COURBURE_LUMIERE"]:
			if not modele.get_script_constant_map().has(constante):
				absents.append("Eblouissement.%s a disparu" % constante)
		var noms_modele := {}
		for m in modele.get_script_method_list():
			noms_modele[m["name"]] = true
		for methode in ["integrer", "pic_de_flash", "plafond_pour"]:
			if not noms_modele.has(methode):
				absents.append("Eblouissement.%s() a disparu" % methode)

	var geometrie := load("res://vision.gd") as GDScript
	if geometrie == null:
		absents.append("vision.gd est introuvable")
	else:
		var noms_vision := {}
		for m in geometrie.get_script_method_list():
			noms_vision[m["name"]] = true
		for methode in ["intensite_recue", "intensite_texture"]:
			if not noms_vision.has(methode):
				absents.append("Vision.%s() a disparu" % methode)

	var arme := WeaponData.new()
	for methode in ["portee_torche", "cos_demi_cone", "demi_angle_torche", "image_torche"]:
		if not arme.has_method(methode):
			absents.append("WeaponData.%s() a disparu" % methode)
	for prop in ["torch_angle_deg", "muzzle_flash_intensity"]:
		if not prop in arme:
			absents.append("WeaponData.%s a disparu" % prop)

	return absents


func _ready() -> void:
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ cette planche ne peut pas travailler ici : ", refus)
		printerr("  Lancer SANS --headless : godot --path . res://tools/planche_eblouissement.tscn")
		_sortir(1)
		return

	print("=== Planche de contact — ÉBLOUISSEMENT ===")
	_au_premier_plan()
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")

	var manquants: Array[String] = Commun.preconditions_manquantes(_ui, _main)
	manquants.append_array(preconditions_manquantes(_ui, _main))
	if not manquants.is_empty():
		printerr("✗ la planche ne peut pas démarrer — le jeu a changé sous elle :")
		for m in manquants:
			printerr("    · ", m)
		_sortir(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	for f in _anciennes():
		DirAccess.remove_absolute(f)

	if not await _ouvrir_une_manche():
		_sortir(1)
		return

	_dire_les_reglages()
	await _sweep_du_voile()
	await _mesurer_le_temps()
	await _photographier_la_montee()
	await _le_flash_des_quatre_armes()
	await _coherence_faisceau()
	await _ecran_partage()
	await _fin_de_manche()

	print("\n--- ce que la planche a mesuré ---")
	for ligne in _journal:
		print("  " + ligne)
	print("\n%d images écrites dans :\n  %s" % [_n, ProjectSettings.globalize_path(_dossier)])
	if _perdues > 0:
		printerr("⚠ %d capture(s) perdue(s) — fenêtre au second plan" % _perdues)
	if _echecs > 0:
		printerr("\n✗ %d propriété(s) d'équité en échec" % _echecs)
	_sortir(1 if _echecs > 0 else 0)


## Une vraie manche en écran partagé : aucun réseau, une seule instance, et
## pourtant le chemin réel `game_state._process` → `_lumiere_recue` → `player`.
func _ouvrir_une_manche() -> bool:
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 20.0):
		printerr("✗ la manche n'a jamais démarré")
		return false
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0):
		printerr("✗ le décompte n'a jamais fini")
		return false
	_maintenir_en_vie()
	return true


## Les réglages tels qu'ils sont AU MOMENT du relevé, imprimés avant toute
## image. Un jugement porté sur des valeurs qu'on ne connaît pas ne se rejoue
## pas — et ces constantes sont précisément ce que la séance doit arbitrer.
func _dire_les_reglages() -> void:
	print("\n--- les réglages jugés ici ---")
	print("  MONTEE_PAR_S   %.3f  → saturation en %.2f s sous un faisceau qui sature"
		% [Eblouissement.MONTEE_PAR_S, 1.0 / Eblouissement.MONTEE_PAR_S])
	print("  DESCENTE_PAR_S %.3f  → récupération en %.2f s depuis la saturation"
		% [Eblouissement.DESCENTE_PAR_S, 1.0 / Eblouissement.DESCENTE_PAR_S])
	print("  PIC_FLASH      %.3f    PORTEE_FLASH %.0f px" % [
		Eblouissement.PIC_FLASH, Eblouissement.PORTEE_FLASH])
	var voile: float = GameSettings.current_effect("eblouissement")
	print("  curseur « Éblouissement » : %.2f (brut %.2f) → voile maximal %.0f %% d'opacité"
		% [voile, GameSettings.get_effect("eblouissement"), voile * 0.8 * 100.0])
	print("\n--- les quatre armes : cône, portée, éclat de bouche ---")
	for idx in range(4):
		var arme: WeaponData = _main.weapon_for_index(idx)
		print("  %-9s demi-cône %4.1f°  (cône plein %5.1f°)  portée %5.0f px  éclat %.2f" % [
			_nom(arme), arme.torch_angle_deg, arme.torch_angle_deg * 2.0,
			arme.portee_torche(), arme.muzzle_flash_intensity])
	# Ce que le faisceau verse réellement à bout portant, arme par arme. Ce
	# nombre est le PLAFOND que la montée vise : sans lui, un « la valeur ne
	# monte qu'à 0,86 » passerait pour un défaut du modèle.
	# Lu dans la TEXTURE, comme le fait la production depuis le 2026-08-24 : la
	# formule analytique donnerait un autre chiffre pour l'arbalète, dont la
	# luminosité de 0,3 ne vit que dans l'alpha de l'image.
	# **Les deux échelles sur la même ligne, et c'est une réparation.** Ce bloc
	# n'imprimait que le brut pendant que la mesure de montée imprimait
	# l'après-courbe : quatre plafonds ont été transmis à la session voisine en
	# citant un mot de chaque, et l'arbalète y passait pour tomber à 0,188 quand
	# elle tombe à 0,434. Il y a une racine carrée entre les deux colonnes.
	# **Un nombre sans son échelle n'est pas un nombre** — et deux échelles
	# imprimées à deux endroits différents SONT un nombre sans son échelle.
	print("\n--- le plafond réel à 80 px dans l'axe (ce vers quoi la montée tend) ---")
	print("  %-9s %8s  %8s   %s" % ["", "brut", "PÉNALITÉ", "(formule, pour mémoire)"])
	for idx in range(4):
		var arme: WeaponData = _main.weapon_for_index(idx)
		# `echelle_torche()`, pas `torch_scale` : l'échelle que la LUMIÈRE
		# emploie. Les deux étaient le même nombre jusqu'aux cookies cuits en
		# 1024². Cette planche a rapporté quatre plafonds faux avant qu'on le
		# voie — elle échantillonnait plus près du centre, donc plus clair, et
		# faisait passer un défaut d'outil pour un effet du cookie peint.
		var brut: float = Vision.intensite_texture(arme.image_torche(),
			Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT * CORPS_A_CORPS,
			arme.echelle_torche())
		print("  %-9s %8.3f  %8.3f   %.3f" % [_nom(arme), brut,
			Eblouissement.plafond_pour(brut),
			Vision.intensite_recue(Vector2.RIGHT, Vector2.ZERO,
				Vector2.RIGHT * CORPS_A_CORPS, arme.portee_torche(),
				arme.cos_demi_cone())])


## Le voile seul, à des valeurs imposées. C'est la seule façon de juger
## l'intensité sans que la question « est-ce que ça monte assez vite » vienne
## se mélanger à « est-ce que c'est trop blanc ».
func _sweep_du_voile() -> void:
	print("\n--- le voile, à valeur imposée ---")
	_eteindre_les_torches()
	for v in [0.0, 0.25, 0.5, 0.75, 1.0]:
		await _poser_a_valeur("10-voile-%03d" % int(v * 100.0), _main.p2, v)
	_journal.append("voile : alpha = éblouissement × 0,80 × curseur (%.2f) → maximum %.2f"
		% [GameSettings.current_effect("eblouissement"),
		0.8 * GameSettings.current_effect("eblouissement")])


## Les deux temps, mesurés image par image et **sans photographier**.
##
## C'est la séparation qui compte : une capture coûte 350 ms de repos plus le
## rendu, et un jalon relevé entre deux captures mesure le banc, pas le jeu.
func _mesurer_le_temps() -> void:
	print("\n--- les deux temps, mesurés image par image ---")
	var arme: WeaponData = _main.p1.current_weapon
	var plafond: float = Eblouissement.plafond_pour(Vision.intensite_texture(
		arme.image_torche(), Vector2.RIGHT, Vector2.ZERO,
		Vector2.RIGHT * CORPS_A_CORPS, arme.echelle_torche()))

	# MONTÉE. Le chronomètre part à la première image où la valeur bouge, et non
	# à l'appui : entre les deux il y a une image de scrutation d'entrée, et la
	# compter dans la montée ferait accuser le modèle d'un retard qui est celui
	# du banc.
	_main.p2.dazzle_amount = 0.0
	Input.action_press("p1_torch")
	var t0 := -1.0
	var jalons := {}
	var vus: Array[float] = []
	var horloge := 0.0
	while horloge < 2.5:
		_tenir_une_image(CORPS_A_CORPS, 0.0)
		await get_tree().process_frame
		horloge += get_process_delta_time()
		var v: float = _main.p2.dazzle_amount
		if t0 < 0.0 and v > 0.0:
			t0 = horloge
		if t0 >= 0.0:
			vus.append(v)
			for seuil in [0.25, 0.5, 0.75, 0.9]:
				if not jalons.has(seuil) and v >= seuil * plafond:
					jalons[seuil] = horloge - t0
	var atteint: float = _main.p2.dazzle_amount
	_journal.append("MONTÉE (pistolet, 80 px, dans l'axe) — plafond géométrique %.3f, atteint %.3f"
		% [plafond, atteint])
	for seuil in [0.25, 0.5, 0.75, 0.9]:
		if jalons.has(seuil):
			_journal.append("  %.0f %% du plafond en %.3f s  (modèle : %.3f s)"
				% [seuil * 100.0, jalons[seuil], seuil * plafond / Eblouissement.MONTEE_PAR_S])
		else:
			_journal.append("  %.0f %% du plafond JAMAIS atteint en 2,5 s" % (seuil * 100.0))

	# DESCENTE, depuis la saturation réelle et faisceau coupé.
	_eteindre_les_torches()
	_main.p2.dazzle_amount = 1.0
	var t1 := 0.0
	var bas := {}
	while t1 < 3.0:
		_tenir_une_image(CORPS_A_CORPS, 0.0)
		await get_tree().process_frame
		t1 += get_process_delta_time()
		var v: float = _main.p2.dazzle_amount
		for seuil in [0.5, 0.25, 0.1, 0.01]:
			if not bas.has(seuil) and v <= seuil:
				bas[seuil] = t1
	_journal.append("DESCENTE depuis 1,00, faisceau coupé")
	for seuil in [0.5, 0.25, 0.1, 0.01]:
		if bas.has(seuil):
			_journal.append("  sous %.0f %% en %.3f s  (modèle : %.3f s)"
				% [seuil * 100.0, bas[seuil], (1.0 - seuil) / Eblouissement.DESCENTE_PAR_S])
		else:
			_journal.append("  JAMAIS sous %.0f %% en 3 s" % (seuil * 100.0))


## Les images de la montée, en une passe séparée : on rejoue la même montée et
## on photographie à des instants choisis, sans que la capture pollue l'horloge.
func _photographier_la_montee() -> void:
	print("\n--- les images de la montée ---")
	for cible in [0.2, 0.4, 0.6, 0.8, 1.0]:
		_main.p2.dazzle_amount = 0.0
		_eteindre_les_torches()
		Input.action_press("p1_torch")
		var garde := 0.0
		while _main.p2.dazzle_amount < cible and garde < 3.0:
			_tenir_une_image(CORPS_A_CORPS, 0.0)
			await get_tree().process_frame
			garde += get_process_delta_time()
		Input.action_release("p1_torch")
		await _poser_a_valeur("20-montee-%03d" % int(cible * 100.0), _main.p2,
			minf(cible, _main.p2.dazzle_amount))


## Le flash de tir, arme par arme et à 90° de l'axe de visée.
##
## Le hors-axe n'est pas une commodité : c'est ce qui empêche la balle de tuer
## le sujet au milieu du relevé, **et** c'est la preuve de la propriété voulue —
## un canon crache dans toutes les directions, le flash n'a pas de cône. Une
## ligne de vue, en revanche, oui, et elle est vérifiée avant chaque tir.
func _le_flash_des_quatre_armes() -> void:
	print("\n--- le flash de tir, les quatre armes, à 90° de l'axe ---")
	_eteindre_les_torches()
	_degager([[CORPS_A_CORPS, PI * 0.5], [300.0, PI * 0.5], [550.0, PI * 0.5]])
	for idx in range(4):
		var arme: WeaponData = _main.weapon_for_index(idx)
		for distance in [CORPS_A_CORPS, 300.0, 550.0]:
			_main.p1.equip_weapon(arme)
			_main.p2.dazzle_amount = 0.0
			_main.p1.shoot_cooldown = 0.0
			await _tenir(0.25, distance, PI * 0.5)
			if not _main._ligne_de_vue(_main.p1.get_world_2d().direct_space_state,
					_main.p1, _main.p2):
				_journal.append("flash %-9s à %3.0f px : MUR entre les deux, relevé sauté"
					% [_nom(arme), distance])
				continue
			_main.p1.shoot()
			await get_tree().process_frame
			var pic: float = _main.p2.dazzle_amount
			var theorique := Eblouissement.pic_de_flash(distance, arme.muzzle_flash_intensity)
			_journal.append("flash %-9s à %3.0f px : pic %.3f  (modèle %.3f)"
				% [_nom(arme), distance, pic, theorique])
			if distance == CORPS_A_CORPS:
				await _poser_a_valeur("40-flash-%d-%s" % [idx, _nom(arme).to_lower()],
					_main.p2, pic)
			_maintenir_en_vie()
	_main.p1.equip_weapon(_main.weapon_for_index(0))


## Cohérence faisceau ↔ éblouissement : ce qu'on subit doit correspondre à ce
## qu'on voit. C'était la moitié du défaut du 2026-08-18, et aucun test headless
## ne le juge — il faut une image du faisceau ET la valeur au même instant.
##
## Cinq postes par arme, sur le bord du cône et sur le bord de la portée : là où
## un cône écrit en dur se trahit. La valeur imprimée est celle que le jeu a
## réellement intégrée ; l'image dit si le joueur était dans la lumière.
func _coherence_faisceau() -> void:
	print("\n--- cohérence : ce qu'on subit contre ce qu'on voit ---")
	for idx in [0, 2, 3]: # pistolet (30°), pompe (60°), arbalète (5°)
		var arme: WeaponData = _main.weapon_for_index(idx)
		_main.p1.equip_weapon(arme)
		# Dégagé arme par arme : le pompe a besoin de 294 px, l'arbalète de
		# 1030. Un seul emplacement pour les trois n'existerait sur presque
		# aucune carte, et le chercher ferait échouer les trois ensemble.
		# Le poste « dans-le-dos » a besoin de dégagement DERRIÈRE le porteur.
		# Sans cette exigence il rendait « MUR » à tous les coups, donc le halo
		# n'était jamais chiffré — un poste qui ne mesure jamais rien est pire
		# qu'un poste absent : il a l'air couvert.
		_degager([[arme.portee_torche() * 0.5, 0.0],
			[arme.portee_torche() * 0.5, arme.demi_angle_torche() * 1.15],
			[arme.portee_torche() * 1.15, 0.0],
			[CORPS_A_CORPS, PI]])
		# « dans-le-dos » n'est pas un poste comme les autres : il est là parce
		# que la lecture du pixel a fait ENTRER le halo de proximité dans le
		# calcul, et qu'un changement de jeu doit être chiffré à chaque passage
		# plutôt que découvert. Un joueur collé à une torche allumée est vu ;
		# reste à savoir combien ça lui coûte.
		for poste in [["axe", 0.0, 0.5], ["bord-du-cone", 0.9, 0.5],
				["juste-dehors", 1.15, 0.5], ["bout-de-portee", 0.0, 0.95],
				["au-dela", 0.0, 1.15], ["dans-le-dos", 0.0, 0.0]]:
			var angle: float = arme.demi_angle_torche() * float(poste[1])
			var rayon: float = arme.portee_torche() * float(poste[2])
			if String(poste[0]) == "dans-le-dos":
				angle = PI
				rayon = CORPS_A_CORPS
			_main.p2.dazzle_amount = 0.0
			Input.action_press("p1_torch")
			await _tenir(0.8, rayon, angle)
			var vu: float = _main.p2.dazzle_amount
			var mur: bool = not _main._ligne_de_vue(
				_main.p1.get_world_2d().direct_space_state, _main.p1, _main.p2)
			await _poser_en_tenant("50-coherence-%s-%s" % [_nom(arme).to_lower(), poste[0]],
				"%s · %s : %.2f%s" % [_nom(arme), poste[0], vu, "  (MUR)" if mur else ""],
				rayon, angle)
			# Relu APRÈS la capture : c'est cette valeur-là qui correspond à
			# l'image, et l'écart avec celle d'avant dit si le poste était
			# stable. Un poste qui bouge entre les deux ne prouve rien.
			var apres: float = _main.p2.dazzle_amount
			Input.action_release("p1_torch")
			_journal.append("cohérence %-9s %-14s (%4.1f°, %4.0f px) → %.3f%s%s" % [
				_nom(arme), poste[0], rad_to_deg(angle), rayon, apres,
				"   ⚠ mur entre les deux" if mur else "",
				"   ⚠ poste instable (%.3f avant la pose)" % vu
					if absf(apres - vu) > 0.05 else ""])
	_main.p1.equip_weapon(_main.weapon_for_index(0))


## **Une propriété d'équité, pas de goût :** éblouir J2 ne doit rien changer à
## la vue de J1. Le flash de mort avait déjà commis exactement cette faute en
## laissant son `visibility_layer` par défaut — les deux masques de vue
## incluent le bit 1, donc un `CanvasItem` laissé au défaut rend des DEUX côtés.
func _ecran_partage() -> void:
	print("\n--- écran partagé : le voile de J2 doit rester chez J2 ---")
	_eteindre_les_torches()
	_main.p1.dazzle_amount = 0.0
	_main.p2.dazzle_amount = 0.0
	var img_avant := await _capturer_a_valeur(_main.p2, 0.0)
	if img_avant == null:
		printerr("  ✗ contrôle impossible : aucune image de référence")
		_perdues += 1
		return
	img_avant.save_png("%s/60-partage-avant.png" % _dossier)
	_n += 1
	var gauche_avant := Commun.luminance_moyenne(img_avant, _demi_ecran(img_avant, true))

	var img_apres := await _capturer_a_valeur(_main.p2, 1.0)
	if img_apres == null:
		printerr("  ✗ contrôle impossible : aucune image saturée")
		_perdues += 1
		return
	img_apres.save_png("%s/61-partage-j2-eblouii.png" % _dossier)
	_n += 1
	var gauche_apres := Commun.luminance_moyenne(img_apres, _demi_ecran(img_apres, true))
	var droite_avant := Commun.luminance_moyenne(img_avant, _demi_ecran(img_avant, false))
	var droite_apres := Commun.luminance_moyenne(img_apres, _demi_ecran(img_apres, false))

	_journal.append("écran partagé — vue de J1 : %.4f → %.4f (%+.4f)"
		% [gauche_avant, gauche_apres, gauche_apres - gauche_avant])
	_journal.append("écran partagé — vue de J2 : %.4f → %.4f (%+.4f)"
		% [droite_avant, droite_apres, droite_apres - droite_avant])
	# Tolérance large : les deux vues partagent le même monde, et rien n'y est
	# parfaitement immobile. Ce qu'on refuse est un blanchiment, pas un
	# frémissement.
	if gauche_apres - gauche_avant > 0.05:
		_echecs += 1
		printerr("  ✗ la vue de J1 blanchit quand J2 est ébloui (%+.4f)"
			% (gauche_apres - gauche_avant))
	else:
		print("  ✓ la vue de J1 ne bouge pas (%+.4f)" % (gauche_apres - gauche_avant))
	if droite_apres - droite_avant < 0.02:
		_echecs += 1
		printerr("  ✗ la vue de J2 ne blanchit PAS — le voile ne se voit pas (%+.4f)"
			% (droite_apres - droite_avant))
	else:
		print("  ✓ la vue de J2 est bien la seule voilée (%+.4f)"
			% (droite_apres - droite_avant))


## **La seconde propriété d'équité : rien ne reste blanc d'une manche à
## l'autre.** Un voile oublié à la fin d'une manche se rejouerait au début de la
## suivante, et personne ne saurait d'où il vient.
func _fin_de_manche() -> void:
	print("\n--- killcam et fin de manche ---")
	_eteindre_les_torches()
	_main.p2.dazzle_amount = 1.0
	await _poser("70-avant-la-mort", "J2 saturé, sur le point de mourir")
	_main.p2.take_damage(999.0, _main.p1)
	await _attendre(func() -> bool: return not _main.round_active, 15.0)
	await _poser("71-killcam", "juste après la mort — la killcam commence")
	_journal.append("à la mort : J1 %.3f · J2 %.3f"
		% [_main.p1.dazzle_amount, _main.p2.dazzle_amount])

	# On laisse la séquence de fin se dérouler entièrement plutôt que de la
	# couper : c'est au retour que le voile oublié se verrait.
	var attente := 0.0
	while attente < 9.0:
		await get_tree().process_frame
		attente += get_process_delta_time()
	await _poser("72-apres-la-sequence", "la séquence de fin terminée")
	_journal.append("après la séquence : J1 %.3f · J2 %.3f"
		% [_main.p1.dazzle_amount, _main.p2.dazzle_amount])
	if _main.p1.dazzle_amount > 0.01 or _main.p2.dazzle_amount > 0.01:
		_echecs += 1
		printerr("  ✗ un éblouissement survit à la fin de la manche")
	else:
		print("  ✓ rien ne reste blanc")


# ---------------------------------------------------------------------------
# Mécanique de la planche
# ---------------------------------------------------------------------------

## Cherche à J1 un emplacement d'où son axe de visée est dégagé sur les postes
## que la section va relever.
##
## **Sans ça, le relevé est une loterie, et c'est un défaut de banc qui imite un
## défaut de jeu.** La carte est tirée au hasard, le point d'apparition tombe où
## il tombe, et la visée de J1 suit la souris — donc une direction fixe mais
## arbitraire, stable pour toute l'exécution. Deux passages consécutifs ont donné
## l'un un relevé complet, l'autre « MUR entre les deux » sur les quinze postes :
## honnête, et parfaitement inutile.
##
## On cherche donc une position, en anneaux concentriques autour du départ, d'où
## tous les postes voient clair. **Et on exige que le chemin jusqu'à cette
## position soit libre lui aussi** : téléporter J1 dans un mur rendrait un
## dégagement parfait vu de l'intérieur de la pierre.
##
## `exigences` est une liste de `[rayon, ecart]`. On garde le meilleur candidat
## même incomplet — un relevé partiel qui se dit partiel vaut mieux que rien.
func _degager(exigences: Array) -> void:
	if not is_instance_valid(_main.p1):
		return
	var depart: Vector2 = _main.p1.global_position
	var meilleur := depart
	var meilleur_score := _score_degagement(depart, exigences)
	if meilleur_score >= exigences.size():
		return
	var pas := 110.0
	for anneau in range(1, 11):
		var n := anneau * 8
		for i in range(n):
			var a := TAU * float(i) / float(n)
			var c: Vector2 = depart + Vector2.RIGHT.rotated(a) * (pas * float(anneau))
			if not _segment_libre(depart, c):
				continue
			var score := _score_degagement(c, exigences)
			if score > meilleur_score:
				meilleur_score = score
				meilleur = c
				if score >= exigences.size():
					_main.p1.global_position = meilleur
					return
	_main.p1.global_position = meilleur
	if meilleur_score < exigences.size():
		print("  · dégagement partiel : %d postes sur %d voient clair"
			% [meilleur_score, exigences.size()])


func _score_degagement(pos: Vector2, exigences: Array) -> int:
	var axe: Vector2 = _main.p1.global_transform.x
	var n := 0
	for e in exigences:
		if _segment_libre(pos, pos + axe.rotated(float(e[1])) * float(e[0])):
			n += 1
	return n


## Aucun mur entre deux points. Les deux joueurs sont exclus : on teste le
## décor, pas les corps — ceux-ci vont justement être déplacés.
func _segment_libre(de: Vector2, vers: Vector2) -> bool:
	var espace: PhysicsDirectSpaceState2D = _main.p1.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(de, vers, MapGeometry.WALL_LAYER)
	q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
	return espace.intersect_ray(q).is_empty()


## Replace J2 à `rayon` px de J1, à `ecart` radians de son axe de visée — pour
## UNE image.
##
## Replacé à chaque image et non orienté une fois : la visée de J1 retombe sur
## la souris, qui bouge le joueur à chaque image. On suit sa direction au lieu
## de la combattre — le relevé ne dépend alors ni de la carte ni du curseur.
func _tenir_une_image(rayon: float, ecart: float) -> void:
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2):
		return
	var axe: Vector2 = _main.p1.global_transform.x.rotated(ecart)
	_main.p2.global_position = _main.p1.global_position + axe * rayon
	_maintenir_en_vie()

func _tenir(duree: float, rayon: float, ecart: float) -> void:
	var reste := duree
	while reste > 0.0:
		_tenir_une_image(rayon, ecart)
		await get_tree().process_frame
		reste -= get_process_delta_time()

## Les deux joueurs restent debout de force. Une planche qui perd son sujet en
## cours de route rend des images noires sans jamais dire pourquoi — c'est ce
## qui est arrivé au premier jet, où le pompe tuait J2 au troisième relevé.
func _maintenir_en_vie() -> void:
	for j in [_main.p1, _main.p2]:
		if is_instance_valid(j) and not j.dead:
			j.hp = 100.0

func _eteindre_les_torches() -> void:
	Input.action_release("p1_torch")
	Input.action_release("p2_torch")
	if is_instance_valid(_main.p1):
		_main.p1.flashlight_on = false
	if is_instance_valid(_main.p2):
		_main.p2.flashlight_on = false

func _nom(arme: WeaponData) -> String:
	return arme.name if arme != null and arme.name != "" else "Pistolet"

## macOS bride le rendu d'une fenêtre au second plan, au point que
## `frame_post_draw` cesse d'être émis. On la remet devant plutôt que d'attendre
## une image qui ne viendra pas.
func _au_premier_plan() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()


## Photographie l'état courant. `note` est imprimée à côté du nom de fichier :
## une planche dont il faut deviner ce qu'on regarde ne sert à rien.
func _poser(nom: String, note: String = "") -> void:
	var fin := Time.get_ticks_msec() + int(REPOS * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame
	var img: Image = await _capturer_avec_reprise()
	if img == null:
		printerr("  ✗ %s : aucune image (fenêtre au second plan)" % nom)
		_perdues += 1
		return
	img.save_png("%s/%s.png" % [_dossier, nom])
	_n += 1
	print("  · %-38s %s" % [nom, note])


## Photographie un poste de faisceau **sans lâcher la scène**.
##
## **C'est la promesse même de cette planche, et le premier jet la trahissait.**
## `_poser` laisse 350 ms de repos puis attend le rendu : pendant ce temps, plus
## personne ne replace J2 et la visée de J1 continue de suivre la souris. Le
## nombre était donc relevé à un instant, l'image prise à un autre — et la
## planche a sorti un « bout de portée → 0,217 » illustré par un joueur
## visiblement HORS du faisceau.
##
## Une planche dont l'image contredit son chiffre est pire qu'une planche
## absente : elle est faite pour comparer ce qu'on subit à ce qu'on voit, et
## c'était exactement ce lien-là qu'elle cassait.
func _poser_en_tenant(nom: String, note: String, rayon: float, ecart: float) -> void:
	var fin := Time.get_ticks_msec() + int(REPOS * 1000.0)
	while Time.get_ticks_msec() < fin:
		_tenir_une_image(rayon, ecart)
		await get_tree().process_frame
	_au_premier_plan()
	var img: Image = await _capturer_en_tenant(rayon, ecart)
	if img == null:
		_au_premier_plan()
		img = await _capturer_en_tenant(rayon, ecart)
	if img == null:
		printerr("  ✗ %s : aucune image (fenêtre au second plan)" % nom)
		_perdues += 1
		return
	img.save_png("%s/%s.png" % [_dossier, nom])
	_n += 1
	print("  · %-38s %s" % [nom, note])


func _capturer_en_tenant(rayon: float, ecart: float) -> Image:
	var rendu := [false]
	var cb := func() -> void: rendu[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var fin := Time.get_ticks_msec() + 3000
	while not rendu[0] and Time.get_ticks_msec() < fin:
		_tenir_une_image(rayon, ecart)
		await get_tree().process_frame
	if not rendu[0]:
		if RenderingServer.frame_post_draw.is_connected(cb):
			RenderingServer.frame_post_draw.disconnect(cb)
		return null
	var texture := get_tree().root.get_texture()
	return texture.get_image() if texture != null else null


func _capturer_avec_reprise() -> Image:
	_au_premier_plan()
	var img: Image = await Commun.capturer(get_tree(), 3000)
	if img != null:
		return img
	_au_premier_plan()
	return await Commun.capturer(get_tree(), 3000)


## Photographie à une valeur d'éblouissement IMPOSÉE.
##
## Deux tentatives, comme `_poser` : les toutes premières captures d'un lot se
## perdaient systématiquement, la fenêtre n'ayant pas fini d'arriver devant
## quand elles tombaient. Une reprise vaut mieux qu'un délai fixe, qui serait
## soit trop court sur une machine chargée, soit du temps perdu partout.
func _poser_a_valeur(nom: String, joueur: Node2D, valeur: float) -> void:
	var img := await _capturer_a_valeur(joueur, valeur)
	if img == null:
		img = await _capturer_a_valeur(joueur, valeur)
	if img == null:
		printerr("  ✗ %s : aucune image (fenêtre au second plan)" % nom)
		_perdues += 1
		return
	img.save_png("%s/%s.png" % [_dossier, nom])
	_n += 1
	print("  · %-38s imposé %.2f, réel %.3f" % [nom, valeur, joueur.dazzle_amount])


## La valeur est réécrite à CHAQUE image de l'attente : `game_state` réintègre
## sans relâche, et une valeur posée une fois se serait déjà érodée quand
## l'image arrive. Le HUD est rafraîchi dans la foulée, sans quoi le voile
## afficherait la valeur de l'image précédente.
func _capturer_a_valeur(joueur: Node2D, valeur: float) -> Image:
	_au_premier_plan()
	var rendu := [false]
	var cb := func() -> void: rendu[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var fin := Time.get_ticks_msec() + 3000
	while not rendu[0] and Time.get_ticks_msec() < fin:
		joueur.dazzle_amount = valeur
		_ui.update_hud(_main.p1, _main.p2, _main.time_left, false)
		await get_tree().process_frame
	if not rendu[0]:
		if RenderingServer.frame_post_draw.is_connected(cb):
			RenderingServer.frame_post_draw.disconnect(cb)
		return null
	var texture := get_tree().root.get_texture()
	return texture.get_image() if texture != null else null


## La moitié gauche (J1) ou droite (J2) de l'image, en écartant la bande
## centrale : les deux `SubViewportContainer` sont séparés de 5 px, et une
## mesure qui la traverserait mélangerait les deux vues.
func _demi_ecran(img: Image, gauche: bool) -> Rect2i:
	if img == null:
		return Rect2i()
	var t := img.get_size()
	var marge := int(t.x * 0.04)
	if gauche:
		return Rect2i(marge, 0, t.x / 2 - marge * 2, t.y)
	return Rect2i(t.x / 2 + marge, 0, t.x / 2 - marge * 2, t.y)


func _attendre(predicat: Callable, plafond: float) -> bool:
	var attendu := 0.0
	while not predicat.call():
		if attendu >= plafond:
			return false
		await get_tree().create_timer(0.1).timeout
		attendu += 0.1
	return true


func _anciennes() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(_dossier)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(ProjectSettings.globalize_path("%s/%s" % [_dossier, f]))
	return out


## Sortir par la porte du jeu : `main.tscn` instancie les autoloads EOS, et
## quitter sec ré-entre dans `EOS_Platform_Tick()` — segfault documenté.
func _sortir(code: int) -> void:
	print("EXIT_CODE: %d" % code)
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
	else:
		get_tree().quit(code)
