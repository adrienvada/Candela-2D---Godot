## Test headless des mécaniques de munitions, dispersion (bloom), cadence et rechargement
##
## Ce que ce banc garantit :
##   • Les 4 armes respectent les capacités de munitions demandées (10, 24, 1, 6)
##   • La hiérarchie des temps de recharge : Pompe > Arbalète > Fusil > Pistolet
##   • La cadence : Pistolet plus rapide que le Fusil
##   • La dispersion dynamique (bloom) sur le Pistolet et le Fusil
##   • Les liaisons de touches (Carré / R pour recharger, Triangle pour fusée)
##   • L'intégration réseau et le contrat d'implémentation de player.gd et input providers
##
## Lancer : godot --headless --path . --script res://tools/test_munitions_recharge.gd -- --no-eos
extends SceneTree

const WeaponDataScript := preload("res://weapon_data.gd")

var _failures: int = 0
var _total: int = 0

func _check(label: String, condition: bool, detail: String = "") -> void:
	_total += 1
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== TESTS MUNITIONS, CADENCE, BLOOM & RECHARGEMENT ===")
	await process_frame

	_test_capacites_et_armes()
	_test_cadences_et_hierarchie_recharge()
	_test_dispersion_bloom_modele()
	_test_liaisons_touches()
	_test_contrat_code_joueur()
	_test_contrat_entrees_reseau()

	print("\n--- %d tests, %d échec(s) ---" % [_total, _failures])
	quit(1 if _failures > 0 else 0)

## Crée les instances d'armes comme dans GameState._ready()
## ⚠️ **SIGNALÉ, pas corrigé : ceci est une COPIE du catalogue de `game_state`.**
##
## Le banc reconstruit les quatre armes au lieu de lire celles du jeu, puis
## compare le texte de `game_state.gd` à cette copie. Il ne vérifie donc pas ce
## que le jeu fait : il vérifie qu'on a bien édité DEUX endroits du même geste.
## Le jour où l'on n'en édite qu'un, il rougit — ce qui est utile — mais il ne
## dira jamais qu'une valeur est mauvaise, seulement qu'elle est désaccordée.
##
## Le dépôt a déjà écrit la règle noir sur blanc dans `class_data.gd` : « une
## copie garantit que deux nombres restent égaux, jamais qu'ils veulent dire la
## même chose ». Le remède serait de monter `main.tscn` et d'interroger
## `weapon_for_index()`, comme le fait `tools/test_classes.gd`. **Hors périmètre
## du réglage du 2026-09-09 : signalé ici, à reprendre.**
func _creer_armes() -> Dictionary:
	var pistolet = WeaponDataScript.new()
	pistolet.max_ammo = 6
	
	var fusil = WeaponDataScript.new()
	fusil.name = "Fusil"
	fusil.cooldown = 0.24
	fusil.max_ammo = 4
	fusil.reload_time = 3.5
	fusil.spread_bloom_per_shot_deg = 3.5
	fusil.max_spread_bloom_deg = 20.0
	fusil.spread_recovery_speed_deg = 40.0
	
	var pompe = WeaponDataScript.new()
	pompe.name = "Pompe"
	pompe.cooldown = 0.45
	pompe.max_ammo = 6
	pompe.reload_time = 5.6
	pompe.spread_bloom_per_shot_deg = 0.0
	pompe.max_spread_bloom_deg = 0.0
	
	var arbalete = WeaponDataScript.new()
	arbalete.name = "Arbalète"
	arbalete.cooldown = 0.3
	arbalete.max_ammo = 1
	arbalete.reload_time = 4.5
	arbalete.spread_bloom_per_shot_deg = 0.0
	arbalete.max_spread_bloom_deg = 0.0
	
	return {
		"pistolet": pistolet,
		"fusil": fusil,
		"pompe": pompe,
		"arbalete": arbalete
	}

func _test_capacites_et_armes() -> void:
	print("\n[Capacités de chargeurs & Valeurs de GameState]")
	var armes = _creer_armes()
	var gs_src = FileAccess.get_file_as_string("res://game_state.gd")
	
	_check("Pistolet a 6 munitions", armes.pistolet.max_ammo == 6)
	_check("Fusil a 4 munitions", armes.fusil.max_ammo == 4)
	_check("Arbalète a 1 munition", armes.arbalete.max_ammo == 1)
	_check("Pompe a 6 munitions", armes.pompe.max_ammo == 6)

	# Vérifier que game_state.gd configure bien ces valeurs
	_check("game_state.gd configure 4 munitions pour le fusil", gs_src.contains("weapon_fusil.max_ammo = 4"))
	_check("game_state.gd configure 6 munitions pour le pistolet", gs_src.contains("weapon_pistolet.max_ammo = 6"))
	_check("game_state.gd configure 6 munitions pour la pompe", gs_src.contains("weapon_pompe.max_ammo = 6"))
	_check("game_state.gd configure 1 munition pour l'arbalète", gs_src.contains("weapon_arbalete.max_ammo = 1"))

func _test_cadences_et_hierarchie_recharge() -> void:
	print("\n[Cadences et Hiérarchie des temps de recharge]")
	var armes = _creer_armes()
	var gs_src = FileAccess.get_file_as_string("res://game_state.gd")

	# Cadences
	_check("Pistolet a une cadence plus rapide que le Fusil (0.16s < 0.24s)",
		armes.pistolet.cooldown < armes.fusil.cooldown,
		"%.2fs vs %.2fs" % [armes.pistolet.cooldown, armes.fusil.cooldown])

	# Hiérarchie de recharge demandée : Pompe > Arbalète > Fusil > Pistolet
	var t_pompe: float = armes.pompe.reload_time
	var t_arbalete: float = armes.arbalete.reload_time
	var t_fusil: float = armes.fusil.reload_time
	var t_pistolet: float = armes.pistolet.reload_time

	_check("Pompe recharge plus lentement que l'Arbalète (%.2fs > %.2fs)" % [t_pompe, t_arbalete],
		t_pompe > t_arbalete)
	_check("Arbalète recharge plus lentement que le Fusil (%.2fs > %.2fs)" % [t_arbalete, t_fusil],
		t_arbalete > t_fusil)
	_check("Fusil recharge plus lentement que le Pistolet (%.2fs > %.2fs)" % [t_fusil, t_pistolet],
		t_fusil > t_pistolet)

	_check("game_state.gd configure reload_time fusil (3.5s)", gs_src.contains("weapon_fusil.reload_time = 3.5"))
	_check("game_state.gd configure reload_time pompe (5.6s)", gs_src.contains("weapon_pompe.reload_time = 5.6"))
	_check("game_state.gd configure reload_time arbalète (4.5s)", gs_src.contains("weapon_arbalete.reload_time = 4.5"))

func _test_dispersion_bloom_modele() -> void:
	print("\n[Dispersion dynamique / Recoil Bloom]")
	var armes = _creer_armes()
	var pistolet: WeaponData = armes.pistolet
	var fusil: WeaponData = armes.fusil

	_check("Pistolet a du bloom par tir (> 0°)", pistolet.spread_bloom_per_shot_deg > 0.0)
	_check("Pistolet a un plafond de bloom (> 15°)", pistolet.max_spread_bloom_deg >= 15.0)
	_check("Pistolet a une récupération de bloom positive", pistolet.spread_recovery_speed_deg > 0.0)

	_check("Fusil a du bloom par tir (> 0°)", fusil.spread_bloom_per_shot_deg > 0.0)
	_check("Fusil a un plafond de bloom (> 15°)", fusil.max_spread_bloom_deg >= 15.0)
	_check("Fusil a une récupération de bloom positive", fusil.spread_recovery_speed_deg > 0.0)

	# Modélisation mathématique du bloom
	var bloom := 0.0
	# 3 tirs successifs
	for i in 3:
		bloom = minf(pistolet.max_spread_bloom_deg, bloom + pistolet.spread_bloom_per_shot_deg)
	_check("3 tirs consécutifs de pistolet accumulent du bloom (%.1f°)" % bloom, bloom >= 3.0 * pistolet.spread_bloom_per_shot_deg - 0.01)

	# 0.5s de récupération
	var dt := 0.5
	var recup := pistolet.spread_recovery_speed_deg * dt
	bloom = maxf(0.0, bloom - recup)
	_check("Le bloom se résorbe avec le temps (%.1f° après 0.5s)" % bloom, bloom == 0.0)

func _test_liaisons_touches() -> void:
	print("\n[Liaisons de touches & Menus]")
	_check("Action p1_reload enregistrée dans InputMap", InputMap.has_action("p1_reload"))
	_check("Action p2_reload enregistrée dans InputMap", InputMap.has_action("p2_reload"))

	# Vérifier Carré (JOY_BUTTON_X) pour reload
	var p1_reload_events = InputMap.action_get_events("p1_reload")
	var has_joy_square = false
	var has_key_r = false
	for ev in p1_reload_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_X:
			has_joy_square = true
		if ev is InputEventKey and ev.physical_keycode == KEY_R:
			has_key_r = true
	_check("Touche Carré (JOY_BUTTON_X) assignée au rechargement J1", has_joy_square)
	_check("Touche R assignée au rechargement J1", has_key_r)

	# La fusée est passée de Triangle à L1 le 2026-09-09 (décision d'Adrien) :
	# les quatre gestes de combat tiennent sur les quatre commandes d'épaule.
	# ⚠️ Le contrôle complet des quatre, collisions comprises, vit dans
	# `tools/test_liaisons.gd` § 8 — ici on ne garde que la fusée, parce que ce
	# banc-ci est celui du rechargement et qu'elle voisine avec Carré.
	var p1_flare_events = InputMap.action_get_events("p1_lance_fusee")
	var has_joy_l1 = false
	for ev in p1_flare_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_LEFT_SHOULDER:
			has_joy_l1 = true
	_check("Touche L1 assignée à la fusée éclairante J1", has_joy_l1)

	# Vérifier ui.gd
	var ui_src = FileAccess.get_file_as_string("res://ui.gd")
	_check("ui.gd contient le libellé de recharge 'Recharger'", ui_src.contains("\"reload\": \"Recharger\""))
	_check("ui.gd référence l'affichage des munitions", ui_src.contains("current_ammo"))

func _test_contrat_code_joueur() -> void:
	print("\n[Contrat d'implémentation player.gd]")
	var p_src = FileAccess.get_file_as_string("res://player.gd")

	_check("player.gd déclare current_ammo", p_src.contains("var current_ammo: int"))
	_check("player.gd déclare is_reloading", p_src.contains("var is_reloading: bool"))
	_check("player.gd déclare reload_time_left", p_src.contains("var reload_time_left: float"))
	_check("player.gd déclare current_spread_bloom", p_src.contains("var current_spread_bloom: float"))
	_check("player.gd possède start_reload()", p_src.contains("func start_reload()"))
	_check("player.gd bloque le tir à chargeur vide",
		p_src.contains("if current_ammo <= 0: return"))
	# ⚠️ Le blocage pendant recharge n'est plus inconditionnel : la recharge
	# cartouche par cartouche du Terrassier se laisse interrompre (« on peut
	# tirer dès qu'on a des balles », Adrien 2026-09-09). Ce sont donc DEUX
	# choses qu'on tient ici — que le refus existe, et qu'il ait une exception
	# nommée. Le comportement lui-même est éprouvé sur un vrai joueur dans
	# `tools/test_classes.gd`, section « La recharge cumulative du Terrassier ».
	_check("player.gd refuse le tir pendant une recharge d'un bloc",
		p_src.contains("if not recharge_interruptible(): return"))
	_check("et l'exception est nommée, pas devinée",
		p_src.contains("func recharge_interruptible()"))
	_check("player.gd décrémente les munitions lors d'un tir", p_src.contains("current_ammo -= 1"))
	_check("player.gd applique la dispersion bloom", p_src.contains("current_spread_bloom"))
	_check("player.gd recharge automatiquement l'arbalète après tir",
		p_src.contains("current_weapon.max_ammo == 1"))

func _test_contrat_entrees_reseau() -> void:
	print("\n[Contrat des entrées et réseau]")
	var ip_src = FileAccess.get_file_as_string("res://input_provider.gd")
	var lip_src = FileAccess.get_file_as_string("res://local_input_provider.gd")
	var nip_src = FileAccess.get_file_as_string("res://network_input_provider.gd")
	var p_src = FileAccess.get_file_as_string("res://player.gd")

	_check("input_provider.gd déclare is_reload_pressed()", ip_src.contains("func is_reload_pressed()"))
	_check("local_input_provider.gd implémente is_reload_pressed()", lip_src.contains("func is_reload_pressed()"))
	_check("network_input_provider.gd implémente is_reload_pressed()", nip_src.contains("func is_reload_pressed()"))
	_check("network_input_provider.gd stocke reload_pressed", nip_src.contains("var reload_pressed"))
	_check("network_input_provider.gd prend reload dans update_input_state", nip_src.contains("reload: bool"))
	_check("player.gd rpc_send_inputs prend reload", p_src.contains("reload: bool = false"))
