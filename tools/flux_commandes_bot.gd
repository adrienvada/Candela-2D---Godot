## Le FLUX DE COMMANDES d'un bot — chantier SOLO, étape S9 : de quoi prouver qu'un profil sans équipement n'a pas changé.
##
## « Les profils sans équipement ne changent pas (même graine, mêmes commandes qu'avant). » Un test qui le promet doit comparer à AVANT,
## pas à lui-même : ce fichier rejoue, sur des corps factices et une mise en scène fixe, ce que le vrai fournisseur d'entrées
## (`BotInputProvider`) COMMANDE à chaque pas de physique — déplacement, visée, gâchette, recharge, torche, et les quatre commandes que S9
## a ajoutées (fusée, gadget, posture) —, et en rend une empreinte (`md5` du flux entier). `tools/test_bot_equipement.gd` en garde les
## empreintes, **relevées sur le code de S4 (`f113da8`), avant la moindre ligne de S9** : si l'une d'elles bouge, un profil qui n'avait pas
## d'équipement n'a plus les mêmes commandes.
##
## ⚠️ **Ce fichier ne nomme AUCUN champ de S9** (`torche_tactique`, `lance_des_fusees`…) : il doit tourner sur le code d'avant, où ils
## n'existent pas (`profil.set()` ne s'attache qu'à ceux qu'un profil possède). Sans cela, l'empreinte « d'avant » ne se relèverait pas.
##
## Une mise en scène, fixe : un bot posé à l'ouest d'une carte 40 × 30 dotée d'une paroi pleine, une cible factice à l'est. À t = 1 s, un pas
## est entendu au milieu ; à t = 6 s, la cible allume sa torche vers le bot ; à t = 10 s, elle l'éteint et s'en va dans le noir.
##
## Lancer (pour relever les empreintes) : godot --headless --path . --fixed-fps 60 --script res://tools/test_bot_equipement.gd -- --empreintes
extends RefCounted

const Profil := preload("res://profil_bot.gd")
const Bot := preload("res://bot_input_provider.gd")
const Nav := preload("res://navigation_bot.gd")
const Codec := preload("res://map_codec.gd")
const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")
const Percep := preload("res://perception_bot.gd")

const TUILE := 35.0
const PAS := 1.0 / 60.0


## Un tireur factice : ce que `player.gd` fait des commandes, et rien de plus — la visée à 18/s, la cadence, les munitions, la recharge, le
## relâchement exigé entre deux coups ; la torche et la posture suivent la commande. L'ordre est celui de l'arbre : le corps (parent) lit les
## commandes, puis son fournisseur (enfant) décide pour l'image suivante.
class FauxTireur extends Node2D:
	var player_id := 1
	var accroupi := false
	var dead := false
	var hp := 100.0
	var speed := 260.0
	var current_weapon: WeaponData = null
	var current_ammo := 6
	var shoot_cooldown := 0.0
	var is_reloading := false
	var reload_time_left := 0.0
	var flashlight := PointLight2D.new()
	var ambient_light := PointLight2D.new()
	var muzzle_flash := PointLight2D.new()
	var input_provider: InputProvider = null
	var tirs: Array[Dictionary] = []
	var recharges := 0
	var t := 0.0
	var marche := true
	## Le journal du flux : une ligne par pas de physique.
	var flux: Array[String] = []
	var enregistrer := false
	var _tir_consomme := false
	var _recharge_presse := false

	func _init(arme: WeaponData) -> void:
		current_weapon = arme
		current_ammo = arme.max_ammo
		name = "FauxTireur"
		flashlight.enabled = false
		flashlight.energy = 2.5
		muzzle_flash.enabled = false
		ambient_light.enabled = true
		ambient_light.energy = 0.8
		for l in [flashlight, ambient_light, muzzle_flash]:
			add_child(l)
		LightTextures.poser(ambient_light, LightTextures.AMBIANTE, LightTextures.EMPREINTE_AMBIANTE)
		LightTextures.poser(muzzle_flash, LightTextures.FLASH[0], LightTextures.EMPREINTE_FLASH)
		flashlight.position = Vector2(16.1, -4.55)

	func _ready() -> void:
		add_to_group("players")

	func _physics_process(delta: float) -> void:
		t += delta
		if input_provider == null:
			return
		var visee := input_provider.get_aim_direction(global_position)
		if visee.length() > 0.1:
			rotation = lerp_angle(rotation, visee.angle(), minf(1.0, delta * 18.0))
		var v := 0.25 if accroupi else 1.0
		if marche:
			global_position += input_provider.get_movement_vector() * speed * v * delta
		flashlight.enabled = input_provider.is_flashlight_pressed()
		accroupi = input_provider.is_crouch_pressed()
		shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
		if is_reloading:
			reload_time_left -= delta
			if reload_time_left <= 0.0:
				is_reloading = false
				current_ammo = current_weapon.max_ammo
		var veut_recharger := input_provider.is_reload_pressed()
		if not veut_recharger:
			_recharge_presse = false
		elif not _recharge_presse and not is_reloading and current_ammo < current_weapon.max_ammo:
			is_reloading = true
			reload_time_left = 1.0
			recharges += 1
			_recharge_presse = true
		var presse := input_provider.is_shoot_pressed()
		if not presse:
			_tir_consomme = false
		if presse and shoot_cooldown <= 0.0 and not is_reloading and current_ammo > 0 and not _tir_consomme:
			current_ammo -= 1
			shoot_cooldown = current_weapon.cooldown
			_tir_consomme = true
			tirs.append({"t": t, "rotation": rotation})
		if enregistrer:
			var m := input_provider.get_movement_vector()
			var a := input_provider.get_aim_direction(global_position)
			flux.append("%.3f,%.3f|%.3f,%.3f|%d%d%d%d%d%d|%.2f,%.2f" % [m.x, m.y, a.x, a.y, int(input_provider.is_shoot_pressed()),
				int(input_provider.is_reload_pressed()), int(input_provider.is_flashlight_pressed()), int(input_provider.is_flare_pressed()),
				int(input_provider.is_gadget_pressed()), int(input_provider.is_crouch_pressed()), global_position.x, global_position.y])


## Une cible factice : ce que le nœud de perception lit d'un adversaire.
class FauxJoueur extends Node2D:
	var player_id := 0
	var accroupi := false
	var dead := false
	var hp := 100.0
	var speed := 260.0
	var current_weapon: WeaponData = null
	var flashlight := PointLight2D.new()
	var ambient_light := PointLight2D.new()
	var muzzle_flash := PointLight2D.new()

	func _init(arme: WeaponData) -> void:
		current_weapon = arme
		name = "FauxJoueur"
		flashlight.enabled = false
		flashlight.energy = 2.5
		muzzle_flash.enabled = false
		ambient_light.enabled = true
		ambient_light.energy = 0.8
		for l in [flashlight, ambient_light, muzzle_flash]:
			add_child(l)
		LightTextures.poser(ambient_light, LightTextures.AMBIANTE, LightTextures.EMPREINTE_AMBIANTE)
		LightTextures.poser(muzzle_flash, LightTextures.FLASH[0], LightTextures.EMPREINTE_FLASH)

	func _ready() -> void:
		add_to_group("players")

	func allumer_la_torche(vers: Vector2) -> void:
		rotation = vers.angle()
		flashlight.position = Vector2(16.1, -4.55)
		flashlight.enabled = true
		flashlight.energy = 2.5

	func eteindre_la_torche() -> void:
		flashlight.enabled = false


## Les statiques du jeu que le modèle de vue lit (`WeaponData.facteur_portee`…) : posées comme `GameSettings` les pose, rendues après.
static func poser_les_statiques() -> Array:
	var avant := [WeaponData.facteur_portee, WeaponData.portee_plancher, WeaponData.portee_plafond]
	var bord := Portee.portee_au_bord(Portee.VUE_UNIQUE, Percep.ZOOM_VUE_UNIQUE, Percep.DECALAGE_VISEE, Iso.TANGAGE_DEG)
	WeaponData.facteur_portee = 0.75
	WeaponData.portee_plancher = bord
	WeaponData.portee_plafond = bord
	return avant


static func rendre_les_statiques(avant: Array) -> void:
	WeaponData.facteur_portee = avant[0]
	WeaponData.portee_plancher = avant[1]
	WeaponData.portee_plafond = avant[2]


## La carte des corps factices : 40 × 30 de sol, une paroi pleine en x = 26 (y de 8 à 21).
static func carte() -> Dictionary:
	var d := Codec.new_map("flux", Vector2i(40, 30))
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	for y in 30:
		for x in 40:
			sol.append(Vector2i(x, y))
	for y in range(8, 22):
		murs.append(Vector2i(26, y))
	d["floor"] = Codec.encode_runs(sol)
	d["walls"] = Codec.encode_runs(murs)
	return d


static func c(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * TUILE, (float(y) + 0.5) * TUILE)


## Un événement du signal de son de l'audio (`AudioManager.son_localise`), tel que le nœud de perception le reçoit.
static func evenement(audio: Node, famille: String, pos: Vector2, emetteur: int = 0) -> Dictionary:
	var table: Dictionary = audio.get_script().get_script_constant_map()
	var diagonale := 1583.0
	return {
		"cle": famille, "famille": famille, "pos": pos, "emetteur": emetteur,
		"niveau_db": float(table["NIVEAU_RELATIF"].get(famille, 0.0)),
		"portee": diagonale * float(table["PORTEE_RELATIVE"].get(famille, 1.0)) * float(table["FACTEUR_PORTEE_DEFAUT"]),
		"fumee_db": 0.0, "wet": 0.0, "diagonale": diagonale,
	}


## Rend à un profil l'état d'avant S9 : tous les champs d'équipement éteints — s'il en a. Sans effet sur le code d'avant.
static func sans_equipement(p: ProfilBot) -> ProfilBot:
	for champ in ["torche_tactique", "torche_en_patrouille", "lance_des_fusees", "utilise_le_gadget"]:
		if p.get(champ) != null:
			p.set(champ, false)
	for champ in ["repli_apres_tir_s", "accroupi_pres_du_son_px"]:
		if p.get(champ) != null:
			p.set(champ, 0.0)
	return p


## Rejoue la mise en scène fixe pour `profil` et `graine`, `pas` pas de physique : rend `digest` (l'empreinte du flux de commandes), `tirs`,
## `etats` (les états visités). `racine` : le nœud sous lequel on monte la scène (la racine de l'arbre).
static func rejouer(arbre: SceneTree, profil: ProfilBot, graine: int, pas: int = 840) -> Dictionary:
	# Trois pas de physique pour que l'arbre soit au repos : sans eux, le tout premier appel d'un processus perd un pas (839 au lieu de 840).
	for _i in 3:
		await arbre.physics_frame
	var statiques := poser_les_statiques()
	var donnees := carte()
	var navigation := Nav.depuis_carte(donnees)
	var arme := WeaponData.new()
	arme.max_ammo = 6
	arme.cooldown = 0.16
	var scene := Node2D.new()
	scene.name = "SceneFlux"
	arbre.root.add_child(scene)
	var tireur := FauxTireur.new(arme)
	var cible := FauxJoueur.new(arme)
	scene.add_child(tireur)
	scene.add_child(cible)
	tireur.global_position = c(8, 15)
	tireur.rotation = 0.0
	cible.global_position = c(14, 15)
	cible.rotation = PI
	var bot := Bot.new()
	bot.configurer(profil, navigation, graine)
	tireur.input_provider = bot
	tireur.add_child(bot)
	tireur.enregistrer = true
	var audio: Node = arbre.root.get_node("AudioManager")
	var etats: Array[int] = []
	for i in pas:
		await arbre.physics_frame
		if etats.is_empty() or etats[etats.size() - 1] != bot.etat:
			etats.append(bot.etat)
		if i == 60:
			audio.son_localise.emit(evenement(audio, "footstep", c(20, 15)))
		elif i == 360:
			cible.allumer_la_torche(Vector2.LEFT)
		elif i == 600:
			cible.eteindre_la_torche()
			cible.global_position = c(14, 24)
	var resultat := {
		"digest": "\n".join(PackedStringArray(tireur.flux)).md5_text(), "tirs": tireur.tirs.size(), "etats": etats,
		"pas": tireur.flux.size(),
	}
	scene.get_parent().remove_child(scene)
	scene.free()
	rendre_les_statiques(statiques)
	return resultat
