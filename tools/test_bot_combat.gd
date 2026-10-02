## La garde du COMBAT du bot — chantier SOLO, étape S3 : il agit sur ce qu'il perçoit, il tire, et rien d'autre.
##
## Adrien, 2026-10-02 : « l'adversaire doit être honnête » et « trois crans de difficulté avec plus ou moins de réflexes ».
## Cette suite prouve les deux moitiés de la règle qui prime du chantier :
##
##   • **L'HONNÊTETÉ** — le bot ne vise ni ne tire jamais vers une cible qu'il ne perçoit pas : un joueur immobile dans le noir,
##     une torche allumée derrière une paroi pleine, un joueur silencieux hors de la lumière : zéro coup, état de patrouille,
##     mémoire vide. Et le texte de `bot_input_provider.gd` ne lit nulle part le joueur adverse (ni nœud, ni groupe, ni scène).
##   • **LA DIFFICULTÉ NE VIENT QUE DES RÉFLEXES** — les trois difficultés du cran 3 ont des champs de perception IDENTIQUES ;
##     seuls délai de réaction, erreur et vitesse de visée, discipline de tir et audace diffèrent, et chacun est lu par le code.
##
## ## Deux couches
##
##   1. **Des corps factices** (`FauxTireur` : l'essentiel de `player.gd` — rotation à 18/s, cadence, munitions, recharge —, `FauxJoueur`
##      pour la cible) avec le VRAI fournisseur d'entrées, le VRAI nœud de perception (le modèle de vue, le vrai signal de son) et un
##      `_physics_process` réel : le délai de réaction, l'erreur de visée qui se resserre, le lissage, la rafale, la recharge,
##      l'enquête vers un son, la recherche, l'oubli, l'audace, la difficulté. C'est rapide, et chaque grandeur se mesure à l'image près.
##   2. **Le jeu monté** (`main.tscn`, vrais corps, vraie physique, vraies balles, **à pas d'image fixe** comme `test_entrainement_bot`) :
##      le cran 3 et ses difficultés LUS DE L'INTERFACE (l'entrée, la coche, l'entrée de difficulté qui tourne), le bot monté au profil
##      choisi, zéro balle sur un joueur dans le noir ou derrière un mur, des balles sur un joueur éclairé, le cran 2 qui ne tire
##      toujours jamais, la mort et la réapparition du JOUEUR, et le retour à la cible et à l'écran scindé.
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`) : une « seconde simulée » est alors soixante images. La suite vérifie elle-même
## l'horloge et refuse de conclure sans elle. Les compteurs de balles passent par des TABLEAUX : une lambda GDScript capture un entier
## PAR COPIE (« Un compteur incrémenté dans une lambda reste à zéro », Pièges connus) — une garde « jamais » écrite autrement serait vide.
##
## **Sabotée** (la règle du dépôt) : la liste est dans la ROADMAP, section SOLO, S3.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_bot_combat.gd
extends SceneTree

const Percep := preload("res://perception_bot.gd")
const Memoire := preload("res://memoire_bot.gd")
const Noeud := preload("res://perception_bot_noeud.gd")
const Profil := preload("res://profil_bot.gd")
const Bot := preload("res://bot_input_provider.gd")
const Nav := preload("res://navigation_bot.gd")
const Codec := preload("res://map_codec.gd")
const Son := preload("res://son_visible.gd")
const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")

const TUILE := 35.0
const PAS := 1.0 / 60.0
## La carte du jeu monté : celle de la perception (S2), 48 × 40, une paroi pleine en colonne 30 (lignes 14 à 27).
const CARTE_JEU := "res://tools/cartes/perception_essai.json"

var _failures := 0
var _verifications := 0
var _data: Dictionary = {}
var _nav: NavigationBot = null
var _arme: WeaponData = null


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LE BOT AGIT ET TIRE, HONNÊTEMENT (S3) ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe,
		"lancer avec --fixed-fps 60")
	if not horloge_fixe:
		_sortir()
		return
	var statiques := _poser_les_statiques_du_jeu()
	_data = _carte()
	_nav = Nav.depuis_carte(_data)
	_arme = WeaponData.new()
	_arme.max_ammo = 6
	_arme.cooldown = 0.16
	_les_profils()
	_le_texte_du_fournisseur()
	await _le_delai_de_reaction()
	await _la_difficulte()
	await _le_lissage()
	await _l_erreur_qui_se_resserre()
	await _la_discipline_de_tir()
	await _la_recharge()
	await _l_honnetete_des_corps_factices()
	await _enquete_recherche_oubli()
	await _l_audace()
	await _un_profil_qui_n_agit_pas()
	_restaurer_les_statiques(statiques)
	await _le_jeu_monte()
	_sortir()


func _sortir() -> void:
	print("\n%d vérifications" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


## Soixante images font-elles soixante pas de physique ? La seule définition de l'horloge fixe qui se MESURE.
func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


func _images(n: int) -> void:
	for _i in n:
		await process_frame


# ---------------------------------------------------------------------------
# La mise en place — les mêmes statiques que `test_bot_perception`
# ---------------------------------------------------------------------------

func _poser_les_statiques_du_jeu() -> Array:
	var avant := [WeaponData.facteur_portee, WeaponData.portee_plancher, WeaponData.portee_plafond]
	var bord := Portee.portee_au_bord(Portee.VUE_UNIQUE, Percep.ZOOM_VUE_UNIQUE, Percep.DECALAGE_VISEE, Iso.TANGAGE_DEG)
	WeaponData.facteur_portee = 0.75
	WeaponData.portee_plancher = bord
	WeaponData.portee_plafond = bord
	return avant


func _restaurer_les_statiques(avant: Array) -> void:
	WeaponData.facteur_portee = avant[0]
	WeaponData.portee_plancher = avant[1]
	WeaponData.portee_plafond = avant[2]


## La carte des corps factices : 40 × 30 de sol, une paroi pleine en x = 26 (y de 8 à 21).
func _carte() -> Dictionary:
	var d := Codec.new_map("combat", Vector2i(40, 30))
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


# ---------------------------------------------------------------------------
# Les corps factices
# ---------------------------------------------------------------------------

## Un tireur factice : ce que `player.gd` fait des commandes, et rien de plus — la visée à 18/s, la cadence, les munitions, la
## recharge, le relâchement exigé entre deux coups. L'ordre est celui de l'arbre : le corps (parent) lit les commandes, puis son
## fournisseur (enfant) décide pour l'image suivante.
class FauxTireur extends Node2D:
	var player_id := 1
	var accroupi := false
	var dead := false
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
	## Les coups : `t` (secondes de ce corps), `rotation` au départ du coup.
	var tirs: Array[Dictionary] = []
	var recharges := 0
	var t := 0.0
	var marche := true
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

	func _ready() -> void:
		add_to_group("players")

	func _physics_process(delta: float) -> void:
		t += delta
		if input_provider == null:
			return
		var visee := input_provider.get_aim_direction(global_position)
		if visee.length() > 0.1:
			rotation = lerp_angle(rotation, visee.angle(), minf(1.0, delta * 18.0))
		if marche:
			global_position += input_provider.get_movement_vector() * speed * delta
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


## Une cible factice : ce que le nœud de perception lit d'un adversaire.
class FauxJoueur extends Node2D:
	var player_id := 0
	var accroupi := false
	var dead := false
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


## Une situation : une scène, un tireur factice piloté par le VRAI fournisseur, une cible factice.
class Rig extends RefCounted:
	var scene: Node2D
	var tireur: FauxTireur
	var cible: FauxJoueur
	var bot: BotInputProvider
	## Le journal d'états du bot : une entrée à chaque CHANGEMENT d'état (`etat`), avec l'instant du tireur.
	var etats: Array = []
	var _dernier := -1

	func suivre() -> void:
		if bot.etat != _dernier:
			_dernier = bot.etat
			etats.append([tireur.t, bot.etat])

	func noms_des_etats() -> Array:
		return etats.map(func(e: Array) -> int: return int(e[1]))

	## Libère la scène SUR-LE-CHAMP : un `queue_free` laisse les corps de la situation d'avant dans le groupe `players` jusqu'à la fin de
	## l'image, et le bot de la situation suivante les prendrait pour son adversaire — un fantôme à sa propre place, que son halo
	## « voit » (relevé en écrivant cette garde : une vue de plus dans le noir, à la première image de chaque situation).
	func liberer() -> void:
		if scene != null and is_instance_valid(scene):
			scene.get_parent().remove_child(scene)
			scene.free()


## Monte une situation. `profil` règle le bot ; `pos_bot` / `pos_cible` en pixels ; `vers` : où le tireur regarde au départ.
func _rig(profil: ProfilBot, pos_bot: Vector2, pos_cible: Vector2, graine: int = 7, vers: Vector2 = Vector2.RIGHT) -> Rig:
	var r := Rig.new()
	r.scene = Node2D.new()
	r.scene.name = "SceneCombat"
	root.add_child(r.scene)
	r.tireur = FauxTireur.new(_arme)
	r.cible = FauxJoueur.new(_arme)
	r.scene.add_child(r.tireur)
	r.scene.add_child(r.cible)
	r.tireur.global_position = pos_bot
	r.tireur.rotation = vers.angle()
	r.cible.global_position = pos_cible
	r.cible.rotation = PI
	r.bot = Bot.new()
	r.bot.configurer(profil, _nav, graine)
	r.tireur.input_provider = r.bot
	r.tireur.add_child(r.bot)
	return r


## Déroule `n` pas de physique, en suivant les changements d'état. `jusqua` : un `Callable` rendant vrai pour s'arrêter plus tôt.
func _derouler(r: Rig, n: int, jusqua: Callable = Callable()) -> void:
	for _i in n:
		await physics_frame
		r.suivre()
		if jusqua.is_valid() and bool(jusqua.call()):
			return


## Un profil de test : immobile (le bot ne bouge pas, il pense), au cran donné de la difficulté, modifié par `changements`.
func _profil(difficulte: int, changements: Dictionary = {}, immobile: bool = true) -> ProfilBot:
	var p := Profil.pour_adversaire_qui_tire(difficulte)
	if immobile:
		p.deplacement = Profil.Deplacement.IMMOBILE
	for k in changements:
		p.set(k, changements[k])
	return p


## L'angle, en degrés, entre où le tireur regardait au coup et où se trouvait VRAIMENT la cible (le test, lui, a le droit de savoir).
func _erreur_reelle_deg(r: Rig, tir: Dictionary) -> float:
	var vrai := (r.cible.global_position - r.tireur.global_position).angle()
	return absf(rad_to_deg(angle_difference(float(tir["rotation"]), vrai)))


# ---------------------------------------------------------------------------
# LES PROFILS
# ---------------------------------------------------------------------------

func _les_profils() -> void:
	print("\n[Les profils : même perception, des réflexes qui diffèrent]")
	var f := Profil.pour_adversaire_qui_tire(Profil.Difficulte.FACILE)
	var n := Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
	var d := Profil.pour_adversaire_qui_tire(Profil.Difficulte.DIFFICILE)
	var par_defaut := Profil.new()
	_check("un profil neuf n'agit pas et ne tire pas : le bot de S1 et de S2 garde exactement son comportement",
		not par_defaut.agit and not par_defaut.tire)
	var mobile := Profil.pour_entrainement_mobile()
	_check("le profil du cran 2 n'agit pas, ne tire pas, ne perçoit rien : inchangé",
		not mobile.agit and not mobile.tire and not mobile.voit and not mobile.entend
		and mobile.deplacement == Profil.Deplacement.LIBRE and is_equal_approx(mobile.allure, 0.7) and not mobile.torche_allumee)
	# Les champs de PERCEPTION et de déplacement : identiques d'une difficulté à l'autre, champ à champ.
	var communs := ["voit", "entend", "precision_auditive", "delai_oubli", "deplacement", "allure", "torche_allumee", "agit", "tire"]
	var identiques := true
	var pas_identique := ""
	for champ in communs:
		if f.get(champ) != n.get(champ) or n.get(champ) != d.get(champ):
			identiques = false
			pas_identique = champ
	_check("les trois difficultés ont les MÊMES champs de perception, de déplacement et d'agir (la difficulté ne vient que des réflexes)",
		identiques, pas_identique)
	_check("… elles voient, entendent, agissent et tirent toutes les trois", f.voit and f.entend and f.agit and f.tire)
	_check("… elles circulent comme le cran 2 (LIBRE, allure 0,7) et gardent la torche du profil (éteinte : la torche tactique est S9)",
		f.deplacement == Profil.Deplacement.LIBRE and is_equal_approx(f.allure, 0.7) and not f.torche_allumee)
	# Les réflexes : ordonnés du facile au difficile.
	_check("le délai de réaction diminue du facile au difficile (%.2f > %.2f > %.2f)" % [f.delai_reaction, n.delai_reaction, d.delai_reaction],
		f.delai_reaction > n.delai_reaction and n.delai_reaction > d.delai_reaction)
	_check("l'erreur de visée diminue (%.0f > %.0f > %.0f °), son plancher aussi, et elle se resserre plus vite" % [f.erreur_visee_deg, n.erreur_visee_deg, d.erreur_visee_deg],
		f.erreur_visee_deg > n.erreur_visee_deg and n.erreur_visee_deg > d.erreur_visee_deg
		and f.erreur_visee_min_deg > n.erreur_visee_min_deg and n.erreur_visee_min_deg > d.erreur_visee_min_deg
		and f.duree_resserrement > n.duree_resserrement and n.duree_resserrement > d.duree_resserrement)
	_check("la visée tourne plus vite (%.0f < %.0f < %.0f rad/s) et tolère moins d'écart au tir" % [f.vitesse_visee, n.vitesse_visee, d.vitesse_visee],
		f.vitesse_visee < n.vitesse_visee and n.vitesse_visee < d.vitesse_visee
		and f.tolerance_tir_deg > n.tolerance_tir_deg and n.tolerance_tir_deg > d.tolerance_tir_deg)
	_check("les rafales sont plus longues et les pauses plus courtes",
		f.tirs_par_rafale <= n.tirs_par_rafale and n.tirs_par_rafale <= d.tirs_par_rafale and f.tirs_par_rafale < d.tirs_par_rafale
		and f.pause_entre_rafales > n.pause_entre_rafales and n.pause_entre_rafales > d.pause_entre_rafales)
	# S4 : l'audace n'est PLUS un réflexe qui varie. « Tire si vu ou entendu » vaut pour les trois (décision d'Adrien) : la difficulté
	# règle QUAND et AVEC QUELLE JUSTESSE, jamais SI. S3 l'avait fait varier de 40 à 140 px et FACILE ne tirait jamais sur un pas à 400 px.
	_check("l'audace est la MÊME pour les trois difficultés (%.0f px) : la difficulté ne change pas SI le bot tire sur un son" % n.audace_zone_px,
		is_equal_approx(f.audace_zone_px, n.audace_zone_px) and is_equal_approx(n.audace_zone_px, d.audace_zone_px) and n.audace_zone_px >= 68.0)
	_check("une difficulté inconnue retombe sur NORMAL (le défaut de l'écran, et celui du boss de l'aventure)",
		is_equal_approx(Profil.pour_adversaire_qui_tire(99).delai_reaction, n.delai_reaction))


## Chaque champ de réflexe est LU par le fournisseur d'entrées (« Un champ que personne ne lit ne se corrige pas tout seul »), et le
## fournisseur ne regarde jamais le joueur adverse : ni son nœud, ni le groupe `players`, ni la scène.
func _le_texte_du_fournisseur() -> void:
	print("\n[Le texte du fournisseur : chaque réflexe est lu, et l'adversaire n'est jamais regardé]")
	var texte := FileAccess.get_file_as_string("res://bot_input_provider.gd")
	for champ in ["agit", "tire", "delai_reaction", "erreur_visee_deg", "erreur_visee_min_deg", "duree_resserrement", "vitesse_visee",
			"tolerance_tir_deg", "tirs_par_rafale", "pause_entre_rafales", "audace_zone_px"]:
		_check("`profil.%s` est lu par le fournisseur" % champ, texte.contains("profil." + champ))
	# Le code, sans les commentaires : un commentaire peut parler du groupe sans le lire.
	var code := ""
	for ligne in texte.split("\n"):
		var l := String(ligne).strip_edges()
		if not l.begins_with("#"):
			code += ligne + "\n"
	for interdit in ["get_nodes_in_group", "get_first_node_in_group", "get_tree()", "\"players\"", "find_child", "get_node(", "get_node_or_null("]:
		_check("le code du fournisseur ne contient pas « %s » : il ne va pas chercher l'adversaire" % interdit, not code.contains(interdit))
	# Il ne lit le monde que par SON corps (`corps`) et par la perception : toute `global_position` lue l'est sur un de ces deux.
	var seul_son_corps := true
	var intrus := ""
	for ligne in code.split("\n"):
		var i := String(ligne).find("global_position")
		if i >= 0 and not (String(ligne).contains("corps.global_position") or String(ligne).contains("position: Vector2")
				or String(ligne).contains("global_position)")):
			seul_son_corps = false
			intrus = String(ligne).strip_edges()
	_check("toute `global_position` qu'il lit est celle de son propre corps", seul_son_corps, intrus)


# ---------------------------------------------------------------------------
# LE DÉLAI DE RÉACTION
# ---------------------------------------------------------------------------

func _le_delai_de_reaction() -> void:
	print("\n[Le délai de réaction : entre percevoir et agir]")
	for delai in [0.6, 0.18]:
		var r := _rig(_profil(Profil.Difficulte.NORMAL, {"delai_reaction": delai}), c(20, 15), c(24, 15))
		await _derouler(r, 6)
		_check("(délai %.2f s) au repos : patrouille, aucun coup, la cible dans le noir n'est pas perçue" % delai,
			r.bot.etat == Bot.Etat.PATROUILLE and r.tireur.tirs.is_empty() and r.bot.perception.pas_vus == 0)
		var t_allume: float = r.tireur.t
		r.cible.allumer_la_torche(Vector2.LEFT)
		var vue_a := [-1.0]
		var combat_a := [-1.0]
		var tir_a := [-1.0]
		for _i in 150:
			await physics_frame
			r.suivre()
			if vue_a[0] < 0.0 and r.bot.perception.pas_vus > 0:
				vue_a[0] = r.tireur.t
			if combat_a[0] < 0.0 and r.bot.etat == Bot.Etat.COMBAT:
				combat_a[0] = r.tireur.t
			if tir_a[0] < 0.0 and not r.tireur.tirs.is_empty():
				tir_a[0] = float(r.tireur.tirs[0]["t"])
				break
		_check("(délai %.2f s) la lampe de la cible est perçue dans les deux images qui suivent son allumage" % delai,
			vue_a[0] >= 0.0 and vue_a[0] - t_allume <= 3.0 * PAS, "vue à %.3f s, allumée à %.3f s" % [vue_a[0], t_allume])
		_check("(délai %.2f s) il tire : un coup part" % delai, tir_a[0] >= 0.0)
		_check("(délai %.2f s) le combat ne commence qu'APRÈS le délai de réaction : %.3f s après la première perception" % [delai, combat_a[0] - vue_a[0]],
			combat_a[0] - vue_a[0] >= delai - 2.0 * PAS, "%.3f s" % (combat_a[0] - vue_a[0]))
		_check("(délai %.2f s) … et sans traîner : au plus un délai plus 0,1 s" % delai, combat_a[0] - vue_a[0] <= delai + 0.1)
		_check("(délai %.2f s) le premier coup ne part pas avant le délai de réaction (%.3f s après la première perception)" % [delai, tir_a[0] - vue_a[0]],
			tir_a[0] - vue_a[0] >= delai - 2.0 * PAS, "%.3f s" % (tir_a[0] - vue_a[0]))
		_check("(délai %.2f s) … et il part dans la seconde qui suit" % delai, tir_a[0] - vue_a[0] <= delai + 1.0)
		r.liberer()
	# Un délai nul : il réagit sans attendre — mais la visée, elle, demande toujours du temps.
	var r0 := _rig(_profil(Profil.Difficulte.NORMAL, {"delai_reaction": 0.0}), c(20, 15), c(24, 15))
	await _derouler(r0, 4)
	r0.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(r0, 6)
	_check("un délai nul : le combat commence dès la perception (en moins de quatre images)", r0.bot.etat == Bot.Etat.COMBAT)
	r0.liberer()
	# Un son qui se tait avant le délai ne fait pas réagir : le délai redémarre de zéro.
	var rs := _rig(_profil(Profil.Difficulte.NORMAL, {"delai_reaction": 0.6, "delai_oubli": 0.5}), c(8, 15), c(18, 15))
	await _derouler(rs, 4)
	rs.bot.perception.memoire.noter_son(c(18, 15), 40.0, rs.bot.perception.maintenant())
	await _derouler(rs, 60)
	_check("une trace d'ouïe qui s'efface en moins d'un délai de réaction (0,5 s < 0,6 s) ne fait jamais quitter la patrouille",
		not rs.noms_des_etats().has(Bot.Etat.ENQUETE) and rs.bot.etat == Bot.Etat.PATROUILLE, str(rs.noms_des_etats()))
	rs.liberer()


# ---------------------------------------------------------------------------
# LA DIFFICULTÉ : sur une même situation, graines fixes
# ---------------------------------------------------------------------------

func _la_difficulte() -> void:
	print("\n[La difficulté : plus de réflexes, jamais plus d'information]")
	var delais := {}
	var erreurs := {}
	for d in [Profil.Difficulte.FACILE, Profil.Difficulte.NORMAL, Profil.Difficulte.DIFFICILE]:
		var somme_delai := 0.0
		var somme_erreur := 0.0
		var n_erreur := 0
		for graine in [3, 5, 8, 13]:
			var r := _rig(_profil(d), c(20, 15), c(25, 15), graine)
			await _derouler(r, 6)
			r.cible.allumer_la_torche(Vector2.LEFT)
			var t_vue := [-1.0]
			for _i in 360:
				await physics_frame
				r.suivre()
				if t_vue[0] < 0.0 and r.bot.perception.pas_vus > 0:
					t_vue[0] = r.tireur.t
			var tirs := r.tireur.tirs
			if tirs.is_empty():
				_check("difficulté %d, graine %d : il tire sur une cible éclairée en six secondes" % [d, graine], false)
			else:
				somme_delai += float(tirs[0]["t"]) - t_vue[0]
				for tir in tirs:
					somme_erreur += _erreur_reelle_deg(r, tir)
					n_erreur += 1
			r.liberer()
		delais[d] = somme_delai / 4.0
		erreurs[d] = somme_erreur / maxf(float(n_erreur), 1.0)
		print("    · difficulté %d : premier coup %.2f s après la première perception, erreur moyenne %.3f ° sur %d coups"
			% [d, delais[d], erreurs[d], n_erreur])
	var F := Profil.Difficulte.FACILE
	var N := Profil.Difficulte.NORMAL
	var D := Profil.Difficulte.DIFFICILE
	_check("le difficile réagit plus vite que le facile (%.2f s contre %.2f s), le normal entre les deux" % [delais[D], delais[F]],
		delais[D] + 0.1 < delais[F] and delais[D] <= delais[N] + 0.02 and delais[N] <= delais[F] + 0.02)
	_check("le difficile vise plus juste que le facile (%.1f ° contre %.1f ° d'écart moyen à la vraie place)" % [erreurs[D], erreurs[F]],
		erreurs[D] < erreurs[F] - 1.0)


# ---------------------------------------------------------------------------
# LE LISSAGE DE LA VISÉE
# ---------------------------------------------------------------------------

func _le_lissage() -> void:
	print("\n[Le lissage : la consigne de visée ne tourne jamais plus vite que `vitesse_visee`]")
	for vitesse in [3.0, 12.0]:
		# La cible est DERRIÈRE le bot : un demi-tour de 180°. Aucune erreur, aucun tir : on ne mesure que la rotation.
		var profil := _profil(Profil.Difficulte.NORMAL, {"vitesse_visee": vitesse, "erreur_visee_deg": 0.0, "erreur_visee_min_deg": 0.0,
			"tire": false, "delai_reaction": 0.1})
		var r := _rig(profil, c(20, 15), c(15, 15), 7, Vector2.RIGHT)
		await _derouler(r, 6)
		r.cible.allumer_la_torche(Vector2.RIGHT)
		var precedent := [r.bot.get_aim_direction(Vector2.ZERO)]
		var pire := [0.0]
		var t_fait := [-1.0]
		var t0: float = r.tireur.t
		for _i in 150:
			await physics_frame
			r.suivre()
			var v := r.bot.get_aim_direction(Vector2.ZERO)
			if v != Vector2.ZERO and precedent[0] != Vector2.ZERO:
				pire[0] = maxf(pire[0], absf(precedent[0].angle_to(v)))
			precedent[0] = v
			if t_fait[0] < 0.0 and r.bot.etat == Bot.Etat.COMBAT and absf(angle_difference(r.tireur.rotation, PI)) < deg_to_rad(5.0):
				t_fait[0] = r.tireur.t - t0
		_check("(%.0f rad/s) la consigne tourne au plus de %.0f rad/s : pire pas %.4f rad pour %.4f permis" % [vitesse, vitesse, pire[0], vitesse * PAS],
			pire[0] <= vitesse * PAS + 1.0e-4)
		_check("(%.0f rad/s) le demi-tour se fait, et prend un temps proportionnel (%.2f s)" % [vitesse, t_fait[0]],
			t_fait[0] > 0.0 and t_fait[0] >= PI / vitesse - 0.05 and t_fait[0] <= PI / vitesse + 0.5, "%.2f s" % t_fait[0])
		r.liberer()


# ---------------------------------------------------------------------------
# L'ERREUR DE VISÉE QUI SE RESSERRE
# ---------------------------------------------------------------------------

func _l_erreur_qui_se_resserre() -> void:
	print("\n[L'erreur de visée se resserre en visant longtemps]")
	# Aucun tir : on lit la visée voulue, qui est la direction de ce que le bot SAIT (la lampe, qu'il voit) plus l'erreur du moment.
	var profil := _profil(Profil.Difficulte.NORMAL, {"tire": false, "erreur_visee_deg": 20.0, "erreur_visee_min_deg": 0.0,
		"duree_resserrement": 2.0, "delai_reaction": 0.1, "vitesse_visee": 40.0})
	var r := _rig(profil, c(20, 15), c(25, 15), 11)
	await _derouler(r, 6)
	r.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(r, 12)
	var ecart_debut := _ecart_de_visee_deg(r)
	await _derouler(r, 60)
	var ecart_milieu := _ecart_de_visee_deg(r)
	await _derouler(r, 120)
	var ecart_fin := _ecart_de_visee_deg(r)
	print("    · écart de la visée voulue à ce que le bot sait : %.1f ° au début, %.1f ° à mi-parcours, %.1f ° au bout" % [ecart_debut, ecart_milieu, ecart_fin])
	_check("au début de la poursuite l'écart est celui de l'erreur tirée (non nul, au plus 20 °)", ecart_debut > 0.5 and ecart_debut <= 20.0 + 0.01, "%.2f" % ecart_debut)
	_check("il se resserre : plus petit à mi-parcours qu'au début", ecart_milieu < ecart_debut)
	_check("… et nul au bout de la durée de resserrement (plancher 0)", ecart_fin < 0.01, "%.3f" % ecart_fin)
	r.liberer()
	# Le plancher tient : même au bout, un bot de plancher 4° ne vise pas parfaitement.
	var profil2 := _profil(Profil.Difficulte.NORMAL, {"tire": false, "erreur_visee_deg": 20.0, "erreur_visee_min_deg": 4.0,
		"duree_resserrement": 1.0, "delai_reaction": 0.1})
	var r2 := _rig(profil2, c(20, 15), c(25, 15), 11)
	await _derouler(r2, 6)
	r2.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(r2, 200)
	var ecart_plancher := _ecart_de_visee_deg(r2)
	_check("le plancher (4 °) tient : l'écart ne descend pas dessous et ne monte pas dessus (%.2f °)" % ecart_plancher,
		absf(ecart_plancher - 4.0 * absf(r2.bot._erreur_unite)) < 0.01)
	r2.liberer()


## L'écart, en degrés, entre l'angle que le bot veut tenir et la direction de ce qu'il SAIT (sa mémoire).
func _ecart_de_visee_deg(r: Rig) -> float:
	var vers: Vector2 = r.bot.perception.memoire.position - r.tireur.global_position
	return absf(rad_to_deg(angle_difference(r.bot._angle_voulu, vers.angle())))


# ---------------------------------------------------------------------------
# LA DISCIPLINE DE TIR
# ---------------------------------------------------------------------------

func _la_discipline_de_tir() -> void:
	print("\n[La discipline de tir : rafales, pauses, tolérance]")
	var profil := _profil(Profil.Difficulte.NORMAL, {"tirs_par_rafale": 3, "pause_entre_rafales": 1.0, "delai_reaction": 0.1,
		"erreur_visee_deg": 2.0, "erreur_visee_min_deg": 2.0, "tolerance_tir_deg": 6.0})
	var r := _rig(profil, c(20, 15), c(25, 15), 4)
	var gros := _arme.duplicate() as WeaponData
	gros.max_ammo = 60
	r.tireur.current_weapon = gros
	r.tireur.current_ammo = 60
	await _derouler(r, 6)
	r.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(r, 600)
	var tirs := r.tireur.tirs
	_check("sur dix secondes il tire plusieurs rafales (%d coups)" % tirs.size(), tirs.size() >= 9, str(tirs.size()))
	# Les coups d'une rafale sont à la cadence de l'arme ; entre deux rafales, la pause.
	var pauses_ok := true
	var rafales_ok := true
	var pire := ""
	for i in range(1, tirs.size()):
		var ecart := float(tirs[i]["t"]) - float(tirs[i - 1]["t"])
		if i % 3 == 0:
			if ecart < 1.0 - 2.0 * PAS:
				pauses_ok = false
				pire = "pause %.3f s au coup %d" % [ecart, i]
		elif ecart > 0.5:
			rafales_ok = false
			pire = "trou de %.3f s dans la rafale au coup %d" % [ecart, i]
	_check("après chaque rafale de trois, une pause d'au moins 1 s", pauses_ok, pire)
	_check("les trois coups d'une rafale s'enchaînent à la cadence de l'arme (moins de 0,5 s entre eux)", rafales_ok, pire)
	# Chaque coup part quand le corps est dans la tolérance de l'angle voulu (le coup part une ou deux images après l'appui : +1 °).
	var dans_la_tolerance := 0
	for tir in tirs:
		var vers: Vector2 = r.bot.perception.memoire.position - r.tireur.global_position
		# la cible ne bouge pas : l'erreur de visée change d'un coup à l'autre, la tolérance sur le COUP vaut pour la consigne du moment ;
		# on borne donc l'écart à la place connue par la tolérance plus l'amplitude maximale de l'erreur (2 °) plus la marge d'image.
		if absf(rad_to_deg(angle_difference(float(tir["rotation"]), vers.angle()))) <= 6.0 + 2.0 + 1.0:
			dans_la_tolerance += 1
	_check("chaque coup part dans la tolérance de tir (6 °) autour de ce que le bot sait, erreur de visée comprise (%d sur %d)" % [dans_la_tolerance, tirs.size()],
		dans_la_tolerance == tirs.size())
	r.liberer()
	# La tolérance gouverne le départ : une tolérance nulle ne laisse presque rien partir ; une grande laisse partir plus tôt.
	var stricte := _rig(_profil(Profil.Difficulte.NORMAL, {"tolerance_tir_deg": 0.0, "erreur_visee_deg": 15.0, "erreur_visee_min_deg": 15.0,
		"delai_reaction": 0.1}), c(20, 15), c(25, 15), 4)
	await _derouler(stricte, 6)
	stricte.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(stricte, 240)
	var tirs_stricte := stricte.tireur.tirs.size()
	stricte.liberer()
	var large := _rig(_profil(Profil.Difficulte.NORMAL, {"tolerance_tir_deg": 30.0, "erreur_visee_deg": 15.0, "erreur_visee_min_deg": 15.0,
		"delai_reaction": 0.1}), c(20, 15), c(25, 15), 4)
	await _derouler(large, 6)
	large.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(large, 240)
	_check("une tolérance de 0 ° ne tire presque jamais (%d coups) ; de 30 °, souvent (%d)" % [tirs_stricte, large.tireur.tirs.size()],
		tirs_stricte < large.tireur.tirs.size() and large.tireur.tirs.size() >= 2)
	large.liberer()


# ---------------------------------------------------------------------------
# LA RECHARGE
# ---------------------------------------------------------------------------

func _la_recharge() -> void:
	print("\n[La recharge : à vide, après le temps de s'en apercevoir]")
	# Au calme : un chargeur vide se recharge, après `delai_reaction`.
	var r := _rig(_profil(Profil.Difficulte.NORMAL, {"delai_reaction": 0.5}), c(20, 15), c(34, 25))
	await _derouler(r, 6)
	r.tireur.current_ammo = 0
	var t_vide: float = r.tireur.t
	var t_recharge := [-1.0]
	for _i in 240:
		await physics_frame
		r.suivre()
		if t_recharge[0] < 0.0 and r.tireur.recharges > 0:
			t_recharge[0] = r.tireur.t - t_vide
	_check("un chargeur vide est rechargé (une recharge, chargeur plein ensuite)", r.tireur.recharges == 1 and r.tireur.current_ammo == 6,
		"%d recharges, %d balles" % [r.tireur.recharges, r.tireur.current_ammo])
	_check("… après le délai de réaction, pas avant (%.2f s pour 0,5 s)" % t_recharge[0], t_recharge[0] >= 0.5 - 2.0 * PAS and t_recharge[0] <= 0.5 + 0.2)
	# Au calme, un chargeur entamé se complète.
	var r2 := _rig(_profil(Profil.Difficulte.NORMAL), c(20, 15), c(34, 25))
	await _derouler(r2, 6)
	r2.tireur.current_ammo = 3
	await _derouler(r2, 120)
	_check("au calme, un chargeur entamé est complété", r2.tireur.current_ammo == 6 and r2.tireur.recharges == 1)
	r.liberer()
	r2.liberer()
	# Au combat : il vide son chargeur sur une cible éclairée, puis recharge.
	var rc := _rig(_profil(Profil.Difficulte.NORMAL, {"pause_entre_rafales": 0.3, "tirs_par_rafale": 3, "delai_reaction": 0.2}), c(20, 15), c(25, 15), 6)
	await _derouler(rc, 6)
	rc.cible.allumer_la_torche(Vector2.LEFT)
	var vide_vu := [false]
	for _i in 480:
		await physics_frame
		rc.suivre()
		if rc.tireur.current_ammo == 0:
			vide_vu[0] = true
	_check("au combat, le chargeur se vide (six coups) puis le bot recharge (%d recharge)" % rc.tireur.recharges,
		vide_vu[0] and rc.tireur.recharges >= 1 and rc.tireur.tirs.size() >= 6, "%d coups, %d recharges" % [rc.tireur.tirs.size(), rc.tireur.recharges])
	rc.liberer()
	# Un bot qui ne tire pas ne recharge pas, même à vide (le cran 2).
	var rn := _rig(_profil(Profil.Difficulte.NORMAL, {"tire": false}), c(20, 15), c(34, 25))
	await _derouler(rn, 6)
	rn.tireur.current_ammo = 0
	await _derouler(rn, 120)
	_check("un bot qui ne tire pas ne recharge pas", rn.tireur.recharges == 0 and not rn.bot.is_reload_pressed())
	rn.liberer()


# ---------------------------------------------------------------------------
# L'HONNÊTETÉ, sur des corps factices
# ---------------------------------------------------------------------------

func _l_honnetete_des_corps_factices() -> void:
	print("\n[L'honnêteté : jamais un coup vers ce qu'il ne perçoit pas]")
	for d in [Profil.Difficulte.FACILE, Profil.Difficulte.NORMAL, Profil.Difficulte.DIFFICILE]:
		# Un joueur immobile dans le noir, à 5 cases, en face : torche éteinte, silencieux.
		var noir := _rig(_profil(d), c(20, 15), c(25, 15), 9)
		await _derouler(noir, 600)
		_check("(difficulté %d) joueur immobile dans le noir, en ligne de vue : zéro coup, patrouille, mémoire vide" % d,
			noir.tireur.tirs.is_empty() and noir.bot.etat == Bot.Etat.PATROUILLE and noir.bot.perception.pas_vus == 0
			and not noir.bot.perception.memoire.connue(noir.bot.perception.maintenant()) and not noir.bot.is_shoot_pressed(),
			"%d coups, état %d, %d vues" % [noir.tireur.tirs.size(), noir.bot.etat, noir.bot.perception.pas_vus])
		noir.liberer()
		# Une torche allumée DERRIÈRE la paroi pleine : le modèle ne voit pas, le bot ne bouge pas, ne tire pas.
		var mur := _rig(_profil(d), c(20, 15), c(32, 15), 9)
		await _derouler(mur, 6)
		mur.cible.allumer_la_torche(Vector2.LEFT)
		await _derouler(mur, 600)
		_check("(difficulté %d) torche allumée derrière une paroi pleine : zéro coup, patrouille, mémoire vide" % d,
			mur.tireur.tirs.is_empty() and mur.bot.etat == Bot.Etat.PATROUILLE and mur.bot.perception.pas_vus == 0
			and not mur.bot.perception.memoire.connue(mur.bot.perception.maintenant()),
			"%d coups, état %d, %d vues" % [mur.tireur.tirs.size(), mur.bot.etat, mur.bot.perception.pas_vus])
		mur.liberer()
	# Un bot qui MARCHE (une ZONE à l'ouest) et dont la cible reste dans le noir à l'autre bout de la carte : zéro coup non plus.
	var en_zone := _profil(Profil.Difficulte.DIFFICILE, {}, false)
	en_zone.deplacement = Profil.Deplacement.ZONE
	en_zone.zone = Rect2i(1, 1, 18, 12)
	var libre := _rig(en_zone, c(5, 5), c(36, 26), 21)
	var excursion := [0.0]
	for _i in 900:
		await physics_frame
		libre.suivre()
		excursion[0] = maxf(excursion[0], libre.tireur.global_position.distance_to(c(5, 5)))
	_check("un bot qui patrouille, la cible dans le noir à l'autre bout : zéro coup (il ne sait rien d'elle)",
		libre.tireur.tirs.is_empty() and libre.bot.perception.pas_vus == 0 and libre.bot.etat == Bot.Etat.PATROUILLE,
		"%d coups, %d vues, état %d" % [libre.tireur.tirs.size(), libre.bot.perception.pas_vus, libre.bot.etat])
	_check("… et il a bien marché (le bot de S1 est intact) : il s'est éloigné de son départ de %.0f px" % excursion[0], excursion[0] > 150.0)
	libre.liberer()
	# Un joueur silencieux et éclairé par SA torche, mais que le bot ne regarde pas (hors du cadre de son écran) : rien.
	var dos := _rig(_profil(Profil.Difficulte.DIFFICILE), c(5, 15), c(5 + 24, 25), 9, Vector2.LEFT)
	await _derouler(dos, 6)
	dos.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(dos, 300)
	_check("une lampe allumée hors du cadre de l'écran du bot (à 24 cases, dans son dos) : il ne la voit pas, ne tire pas",
		dos.tireur.tirs.is_empty() and dos.bot.perception.pas_vus == 0, "%d vues" % dos.bot.perception.pas_vus)
	dos.liberer()


# ---------------------------------------------------------------------------
# ENQUÊTE, RECHERCHE, OUBLI
# ---------------------------------------------------------------------------

func _evenement(famille: String, pos: Vector2, emetteur: int = 0, fumee_db: float = 0.0) -> Dictionary:
	var audio: Node = root.get_node("AudioManager")
	var table: Dictionary = audio.get_script().get_script_constant_map()
	var diagonale := 1583.0
	return {
		"cle": famille, "famille": famille, "pos": pos, "emetteur": emetteur,
		"niveau_db": float(table["NIVEAU_RELATIF"].get(famille, 0.0)),
		"portee": diagonale * float(table["PORTEE_RELATIVE"].get(famille, 1.0)) * float(table["FACTEUR_PORTEE_DEFAUT"]),
		"fumee_db": fumee_db, "wet": 0.0, "diagonale": diagonale,
	}


func _enquete_recherche_oubli() -> void:
	print("\n[Enquête : un son entendu fait aller vers la zone, la regarder, puis oublier]")
	var son_pos := c(18, 15)
	var profil := _profil(Profil.Difficulte.NORMAL, {"delai_reaction": 0.3, "audace_zone_px": 0.0}, false)
	var r := _rig(profil, c(6, 15), c(34, 25), 5)
	await _derouler(r, 10)
	# Un bot qui patrouille ne revient pas sur ses pas quand rien ne se passe : on le laisse partir, puis on fait du bruit.
	await _derouler(r, 30)
	var audio: Node = root.get_node("AudioManager")
	var evt := _evenement("footstep", son_pos, 0)
	var pos_avant: Vector2 = r.tireur.global_position
	var d_avant := pos_avant.distance_to(son_pos)
	var t_son: float = r.tireur.t
	audio.son_localise.emit(evt)
	_check("le vrai signal de l'audio parvient au nœud : une zone est gardée, jamais la place exacte",
		r.bot.perception.sons_entendus == 1 and r.bot.perception.memoire.source == Memoire.Source.OUIE
		and not r.bot.perception.memoire.position.is_equal_approx(son_pos))
	var t_enquete := [-1.0]
	var distance_min := [d_avant]
	var visee_vers_zone := [false]
	for _i in 300:
		await physics_frame
		r.suivre()
		if t_enquete[0] < 0.0 and r.bot.etat == Bot.Etat.ENQUETE:
			t_enquete[0] = r.tireur.t - t_son
		distance_min[0] = minf(distance_min[0], r.tireur.global_position.distance_to(son_pos))
		if r.bot.etat == Bot.Etat.ENQUETE:
			var vers := (r.bot.perception.memoire.position - r.tireur.global_position)
			if vers.length() > 40.0 and absf(rad_to_deg(angle_difference(r.bot.get_aim_direction(Vector2.ZERO).angle(), vers.angle()))) < 3.0:
				visee_vers_zone[0] = true
	_check("il passe en enquête après le délai de réaction, pas avant (%.2f s pour 0,3 s)" % t_enquete[0],
		t_enquete[0] >= 0.3 - 2.0 * PAS and t_enquete[0] <= 0.3 + 0.1)
	_check("il marche vers la zone : de %.0f px à %.0f px du son" % [d_avant, distance_min[0]], distance_min[0] < d_avant - 120.0 or distance_min[0] < 120.0)
	_check("il REGARDE la zone pendant l'enquête (la consigne de visée pointe vers la mémoire)", visee_vers_zone[0])
	_check("il n'a pas tiré : sa prudence (audace 0 px) ne l'autorise pas à tirer sur une zone entendue", r.tireur.tirs.is_empty())
	# La mémoire s'efface au bout de `delai_oubli` : retour à la patrouille.
	await _derouler(r, 600)
	var etats := r.noms_des_etats()
	_check("la mémoire s'efface : retour à la patrouille (états : %s)" % str(etats),
		r.bot.etat == Bot.Etat.PATROUILLE and etats.has(Bot.Etat.ENQUETE) and etats[etats.size() - 1] == Bot.Etat.PATROUILLE)
	r.liberer()

	print("\n[Combat, recherche, oubli : la machine à états, de bout en bout]")
	var rp := _rig(_profil(Profil.Difficulte.NORMAL, {"delai_reaction": 0.3, "audace_zone_px": 0.0, "delai_oubli": 3.0}, false), c(8, 15), c(14, 15), 6)
	await _derouler(rp, 6)
	rp.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(rp, 90)
	var etats_p := rp.noms_des_etats()
	_check("vu : le bot passe en combat (états : %s)" % str(etats_p), rp.bot.etat == Bot.Etat.COMBAT)
	_check("… en combat il tient sa place (il ne marche pas)", rp.bot.get_movement_vector() == Vector2.ZERO)
	rp.cible.eteindre_la_torche()
	rp.cible.global_position = c(14, 22)
	await _derouler(rp, 120)
	etats_p = rp.noms_des_etats()
	_check("la cible disparaît : il la CHERCHE à sa dernière place connue (états : %s)" % str(etats_p), etats_p.has(Bot.Etat.RECHERCHE))
	_check("… il marche vers la dernière place où il l'a vue (14, 15), pas vers sa vraie place (14, 22)",
		rp.tireur.global_position.distance_to(c(14, 15)) < rp.tireur.global_position.distance_to(c(14, 22)) or rp.tireur.global_position.distance_to(c(14, 15)) < 80.0)
	await _derouler(rp, 600)
	etats_p = rp.noms_des_etats()
	_check("la mémoire s'efface : retour à la patrouille, dans l'ordre patrouille → combat → recherche → patrouille (%s)" % str(etats_p),
		etats_p == [Bot.Etat.PATROUILLE, Bot.Etat.COMBAT, Bot.Etat.RECHERCHE, Bot.Etat.PATROUILLE], str(etats_p))
	_check("… et la gâchette est relâchée, la mémoire vide", not rp.bot.is_shoot_pressed()
		and not rp.bot.perception.memoire.connue(rp.bot.perception.maintenant()))
	rp.liberer()

	# La réapparition (`reinitialiser`) rend le bot à la patrouille, gâchette comprise.
	var rr := _rig(_profil(Profil.Difficulte.NORMAL, {"delai_reaction": 0.1}), c(8, 15), c(14, 15), 6)
	await _derouler(rr, 6)
	rr.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(rr, 40)
	_check("(avant la réapparition) il est en combat", rr.bot.etat == Bot.Etat.COMBAT)
	rr.bot.reinitialiser()
	_check("`reinitialiser()` : patrouille, mémoire vide, gâchette et recharge relâchées",
		rr.bot.etat == Bot.Etat.PATROUILLE and not rr.bot.is_shoot_pressed() and not rr.bot.is_reload_pressed()
		and not rr.bot.perception.memoire.connue(rr.bot.perception.maintenant()))
	rr.liberer()


# ---------------------------------------------------------------------------
# L'AUDACE : tirer, ou non, sur ce qu'on n'a fait qu'entendre
# ---------------------------------------------------------------------------

func _l_audace() -> void:
	print("\n[La prudence : tirer sur une zone entendue, ou non — la même pour les trois difficultés (S4)]")
	var audio: Node = root.get_node("AudioManager")
	var proche := {}
	var lointain := {}
	var entendus_loin := {}
	for d in [Profil.Difficulte.FACILE, Profil.Difficulte.NORMAL, Profil.Difficulte.DIFFICILE]:
		var tirs_proche := 0
		var tirs_lointain := 0
		var sons_loin := 0
		for graine in [2, 3, 4]:
			# Un pas à 350 px : une zone de ~55 px de rayon. « Tire si vu ou entendu » : les trois difficultés tirent dessus.
			var r := _rig(_profil(d, {}, true), c(8, 15), c(34, 25), graine)
			await _derouler(r, 6)
			audio.son_localise.emit(_evenement("footstep", c(18, 15), 0))
			await _derouler(r, 240)
			tirs_proche += r.tireur.tirs.size()
			r.liberer()
			# Un pas à ~980 px (28 cases) : une zone de plusieurs centaines de pixels, bien au-delà de l'audace : aucun ne tire dessus.
			var l := _rig(_profil(d, {}, true), c(2, 4), c(34, 25), graine)
			await _derouler(l, 6)
			audio.son_localise.emit(_evenement("footstep", c(30, 4), 0))
			await _derouler(l, 240)
			tirs_lointain += l.tireur.tirs.size()
			sons_loin += l.bot.perception.sons_entendus
			l.liberer()
		proche[d] = tirs_proche
		lointain[d] = tirs_lointain
		entendus_loin[d] = sons_loin
		print("    · difficulté %d : %d coups sur un pas entendu à 350 px, %d sur un pas à ~980 px (trois graines)" % [d, tirs_proche, tirs_lointain])
	for d in [Profil.Difficulte.FACILE, Profil.Difficulte.NORMAL, Profil.Difficulte.DIFFICILE]:
		_check("(difficulté %d) sur un pas entendu à 350 px — « adversaire qui tire si vu ou ENTENDU » — il tire" % d, proche[d] > 0, str(proche))
		_check("(difficulté %d) … le pas à 980 px est bel et bien ENTENDU (une zone gardée, sinon l'absence de tir ne prouverait rien)" % d,
			entendus_loin[d] == 3, str(entendus_loin))
		_check("(difficulté %d) … mais il ne tire pas dessus : sa zone est trop vague pour valoir de se trahir" % d, lointain[d] == 0, str(lointain))


# ---------------------------------------------------------------------------
# UN PROFIL QUI N'AGIT PAS : le bot de S1 et de S2
# ---------------------------------------------------------------------------

func _un_profil_qui_n_agit_pas() -> void:
	print("\n[Un profil qui n'agit pas, ou qui n'a pas le droit de tirer : inchangé]")
	# Perçoit (S2) sans `agit` : il voit la lampe, ne réagit à rien.
	var s2 := _profil(Profil.Difficulte.DIFFICILE, {"agit": false, "tire": false})
	var r := _rig(s2, c(20, 15), c(24, 15), 3)
	await _derouler(r, 6)
	r.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(r, 240)
	_check("un profil de S2 (perçoit, n'agit pas) VOIT la lampe… ", r.bot.perception.pas_vus > 0)
	_check("… et n'en fait rien : patrouille, aucun coup, ni gâchette ni recharge", r.bot.etat == Bot.Etat.PATROUILLE and r.tireur.tirs.is_empty()
		and not r.bot.is_shoot_pressed() and not r.bot.is_reload_pressed())
	r.liberer()
	# Agit sans tirer : il se tourne et poursuit, jamais de coup.
	var veille := _profil(Profil.Difficulte.DIFFICILE, {"tire": false})
	var rv := _rig(veille, c(20, 15), c(24, 15), 3)
	await _derouler(rv, 6)
	rv.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(rv, 300)
	_check("un bot qui agit sans tirer passe en combat… ", rv.noms_des_etats().has(Bot.Etat.COMBAT))
	_check("… et ne tire jamais, même la cible éclairée en face (%d coups)" % rv.tireur.tirs.size(), rv.tireur.tirs.is_empty() and rv.bot.coups_tires == 0)
	rv.liberer()


# ---------------------------------------------------------------------------
# LE JEU MONTÉ
# ---------------------------------------------------------------------------

## Une cible qui « appuie sur les touches » sans toucher à rien : sa torche et sa posture sont ce que le test décide.
class Poupee extends InputProvider:
	var torche := false
	var visee := Vector2.RIGHT

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_flashlight_pressed() -> bool:
		return torche


func _libelle_du_cran(ui: Node, cran: int) -> String:
	return _libelle_d_une_entree(ui._entree_cran[cran])


func _libelle_d_une_entree(btn: Button) -> String:
	for rangee in btn.get_children():
		for enfant in rangee.get_children():
			if enfant is Label and String((enfant as Label).text) not in ["›", "—"]:
				return String((enfant as Label).text)
	return ""


func _le_jeu_monte() -> void:
	print("\n=== LE JEU MONTÉ : le cran 3, lu de l'interface ===")
	var reglages := root.get_node("GameSettings")
	var cartes := root.get_node("MapData")
	reglages.mode_iso = true
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	var ui: Node = main.ui
	main._on_main_menu_requested()
	await _images(2)

	# --- L'interface : le cran 3 et sa difficulté
	print("\n--- L'écran d'entraînement : le cran 3 et ses difficultés ---")
	_check("les trois crans ont leurs valeurs (0, 1, 2) et le troisième existe", ui.CRAN_CIBLE_IMMOBILE == 0 and ui.CRAN_ADVERSAIRE_MOBILE == 1
		and ui.CRAN_ADVERSAIRE_QUI_TIRE == 2)
	_check("les difficultés de l'écran portent les entiers de `ProfilBot.Difficulte` (l'écran ne connaît pas le bot : une garde les compare)",
		ui.DIFFICULTE_FACILE == Profil.Difficulte.FACILE and ui.DIFFICULTE_NORMALE == Profil.Difficulte.NORMAL
		and ui.DIFFICULTE_DIFFICILE == Profil.Difficulte.DIFFICILE)
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	_check("par défaut : la cible immobile est prise, et la difficulté est NORMAL", ui.selected_training_cran() == ui.CRAN_CIBLE_IMMOBILE
		and ui.selected_training_difficulte() == ui.DIFFICULTE_NORMALE)
	_check("l'entrée « ADVERSAIRE QUI TIRE » existe, sans coche", ui._entree_cran.has(ui.CRAN_ADVERSAIRE_QUI_TIRE)
		and _libelle_du_cran(ui, ui.CRAN_ADVERSAIRE_QUI_TIRE) == "ADVERSAIRE QUI TIRE", _libelle_du_cran(ui, ui.CRAN_ADVERSAIRE_QUI_TIRE))
	_check("l'entrée de difficulté dit « DIFFICULTÉ : NORMAL »", _libelle_d_une_entree(ui._entree_difficulte) == "DIFFICULTÉ : NORMAL",
		_libelle_d_une_entree(ui._entree_difficulte))
	ui._on_hub_action("cran_tireur")
	await _images(1)
	_check("l'appui sur « ADVERSAIRE QUI TIRE » le prend : coche sur lui, plus sur les deux autres",
		ui.selected_training_cran() == ui.CRAN_ADVERSAIRE_QUI_TIRE
		and _libelle_du_cran(ui, ui.CRAN_ADVERSAIRE_QUI_TIRE).begins_with("✓")
		and not _libelle_du_cran(ui, ui.CRAN_CIBLE_IMMOBILE).begins_with("✓")
		and not _libelle_du_cran(ui, ui.CRAN_ADVERSAIRE_MOBILE).begins_with("✓"))
	var vus: Array[String] = []
	for _i in 3:
		ui._on_hub_action("difficulte_tireur")
		vus.append(_libelle_d_une_entree(ui._entree_difficulte))
	_check("la difficulté tourne : DIFFICILE, FACILE, NORMAL (puis recommence) et le libellé la dit : %s" % str(vus),
		vus == ["DIFFICULTÉ : DIFFICILE", "DIFFICULTÉ : FACILE", "DIFFICULTÉ : NORMAL"], str(vus))
	_check("… et elle ne change pas de cran", ui.selected_training_cran() == ui.CRAN_ADVERSAIRE_QUI_TIRE)
	ui._on_hub_action("cran_mobile")
	await _images(1)
	_check("reprendre un autre cran ne perd pas la difficulté choisie", ui.selected_training_difficulte() == ui.DIFFICULTE_NORMALE)
	ui._on_hub_action("cran_tireur")

	# --- Le bot, monté au profil de chaque difficulté, lancé par le geste du joueur
	print("\n--- Le lancement : le bot est monté au profil de la difficulté lue à l'écran ---")
	cartes.select_map(cartes.DEFAULT_MAP_ID)
	for d in [Profil.Difficulte.FACILE, Profil.Difficulte.NORMAL, Profil.Difficulte.DIFFICILE]:
		while ui.selected_training_difficulte() != d:
			ui._on_hub_action("difficulte_tireur")
		main.graine_du_bot = 99
		ui._on_hub_action("entrainement")
		await _images(3)
		var bot: Node = main.p2.get_node_or_null("BotP2")
		var attendu := Profil.pour_adversaire_qui_tire(d)
		_check("(difficulté %d) J2 est piloté par `BotP2`, au profil de la difficulté (délai %.2f s)" % [d, attendu.delai_reaction],
			bot != null and bot is Bot and main.p2.input_provider == bot and is_equal_approx(bot.profil.delai_reaction, attendu.delai_reaction)
			and is_equal_approx(bot.profil.erreur_visee_deg, attendu.erreur_visee_deg)
			and is_equal_approx(bot.profil.vitesse_visee, attendu.vitesse_visee) and bot.profil.tire and bot.profil.agit)
		_check("(difficulté %d) il VOIT et il ENTEND : sa perception est montée" % d, bot != null and bot.perception != null
			and bot.profil.voit and bot.profil.entend)
		_check("(difficulté %d) la cible immobile est cachée, J2 visible et solide" % d, not main.training_target.visible
			and main.p2.visible and main.p2.get_collision_layer_value(1))
		main._on_main_menu_requested()
		await _images(2)
		ui.hub.push(ui.SCREEN_TRAINING)
		await _images(2)

	# --- La carte d'essai, et la mise en scène : le joueur est une poupée, le bot le profil normal immobile
	print("\n--- Le jeu réel : honnêteté et tirs ---")
	while ui.selected_training_difficulte() != ui.DIFFICULTE_NORMALE:
		ui._on_hub_action("difficulte_tireur")
	ui._on_hub_action("entrainement")
	await _images(3)
	await _poser_la_carte_du_jeu(main)
	var poupee := Poupee.new()
	poupee.name = "PoupeeCombat"
	main._set_player_input_provider(main.p1, poupee)
	# Le bot : le profil NORMAL, immobile (il pense, il ne marche pas), posé au centre ; le joueur à 6 cases en face.
	var profil_normal := Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
	profil_normal.deplacement = Profil.Deplacement.IMMOBILE
	var balles := [0]
	var compter := func(_n: Node) -> void: balles[0] += 1
	main.bullet_container.child_entered_tree.connect(compter)
	await _poser_la_scene(main, c(20, 20), c(26, 20), profil_normal)
	var bot: BotInputProvider = main.p2.input_provider as BotInputProvider
	_check("la mise en scène : le bot est posé, immobile, au profil normal, de la perception montée",
		bot != null and bot.perception != null and bot.profil.deplacement == Profil.Deplacement.IMMOBILE)
	_check("p1 est une poupée sans torche : dans le noir", not main.p1.flashlight_on)

	# Le noir : cinq secondes, zéro balle.
	balles[0] = 0
	await _images(300)
	_check("(jeu réel) un joueur immobile dans le noir, en ligne de vue, à 6 cases : zéro balle en 5 s (%d), le bot patrouille, ne perçoit rien" % balles[0],
		balles[0] == 0 and bot.etat == Bot.Etat.PATROUILLE and bot.perception.pas_vus == 0 and bot.coups_tires == 0,
		"%d balles, état %d, %d vues" % [balles[0], bot.etat, bot.perception.pas_vus])

	# Derrière la paroi : torche allumée de l'autre côté (colonne 30, lignes 14 à 27).
	await _poser_la_scene(main, c(26, 20), c(34, 20), profil_normal)
	bot = main.p2.input_provider as BotInputProvider
	poupee.torche = true
	poupee.visee = Vector2.LEFT
	balles[0] = 0
	await _images(300)
	_check("(jeu réel) torche allumée derrière une paroi pleine : zéro balle en 5 s (%d), le bot ne la perçoit pas" % balles[0],
		balles[0] == 0 and bot.etat == Bot.Etat.PATROUILLE and bot.perception.pas_vus == 0,
		"%d balles, état %d, %d vues" % [balles[0], bot.etat, bot.perception.pas_vus])

	# En ligne de vue : torche allumée, il tire — après son délai de réaction.
	await _eteindre(poupee)
	await _poser_la_scene(main, c(20, 20), c(26, 20), profil_normal)
	bot = main.p2.input_provider as BotInputProvider
	await _images(30)
	_check("(jeu réel) avant d'allumer : le bot n'a rien perçu, n'a rien tiré", bot.perception.pas_vus == 0 and balles[0] == 0 and bot.coups_tires == 0,
		"%d vues (%s), %d balles, %d coups, lumières %s" % [bot.perception.pas_vus, str(bot.perception.derniere_vue), balles[0], bot.coups_tires,
		str(bot.perception.noms_des_lumieres)])
	balles[0] = 0
	poupee.torche = true
	poupee.visee = Vector2.LEFT
	var t_vue := [-1.0]
	var t_balle := [-1.0]
	var images := 0
	for _i in 600:
		await process_frame
		images += 1
		if t_vue[0] < 0.0 and bot.perception.pas_vus > 0:
			t_vue[0] = float(images) * PAS
		if t_balle[0] < 0.0 and balles[0] > 0:
			t_balle[0] = float(images) * PAS
			break
	_check("(jeu réel) torche allumée en ligne de vue : le bot la perçoit (%.2f s) puis tire (%.2f s)" % [t_vue[0], t_balle[0]],
		t_vue[0] > 0.0 and t_balle[0] > 0.0)
	_check("(jeu réel) … la première balle part au plus tôt un délai de réaction (%.2f s) après la première perception : %.2f s" % [
		profil_normal.delai_reaction, t_balle[0] - t_vue[0]], t_balle[0] - t_vue[0] >= profil_normal.delai_reaction - 3.0 * PAS)
	var touche := [false]
	var morts := [0]
	var etait_mort := [false]
	for _i in 900:
		await process_frame
		if main.p1.hp < 100.0:
			touche[0] = true
		if main.p1.dead and not etait_mort[0]:
			morts[0] += 1
		etait_mort[0] = main.p1.dead
	_check("(jeu réel) en quinze secondes de plus il a tiré plusieurs balles (%d)" % balles[0], balles[0] >= 3)
	_check("(jeu réel) et sa visée atteint le joueur éclairé : le joueur a perdu de la vie (%d fois abattu)" % morts[0], touche[0])

	# Le cran 2 ne tire toujours jamais, même devant une torche allumée.
	print("\n--- Le cran 2 ne tire toujours jamais ---")
	var cran2 := Profil.pour_entrainement_mobile()
	cran2.deplacement = Profil.Deplacement.IMMOBILE
	cran2.voit = true
	cran2.entend = true
	await _eteindre(poupee)
	await _poser_la_scene(main, c(20, 20), c(26, 20), cran2)
	var bot2: BotInputProvider = main.p2.input_provider as BotInputProvider
	poupee.torche = true
	poupee.visee = Vector2.LEFT
	balles[0] = 0
	await _images(480)
	_check("(jeu réel) un bot du cran 2 (qui agit : non), même doué de vue et d'ouïe, devant une torche allumée : zéro balle en 8 s",
		balles[0] == 0 and bot2.coups_tires == 0 and not bot2.is_shoot_pressed() and bot2.perception.pas_vus > 0,
		"%d balles, %d vues" % [balles[0], bot2.perception.pas_vus])
	var cran2_vrai := Profil.pour_entrainement_mobile()
	_check("… et le vrai profil du cran 2 ne perçoit rien du tout (sourd et aveugle)", not cran2_vrai.voit and not cran2_vrai.entend and not cran2_vrai.agit and not cran2_vrai.tire)

	# La recharge dans le jeu réel : un chargeur vide, au calme.
	print("\n--- La recharge, dans le jeu réel ---")
	await _eteindre(poupee)
	await _poser_la_scene(main, c(20, 20), c(34, 33), profil_normal)
	main.p2.current_ammo = 0
	var recharge_vue := [false]
	for _i in 180:
		await process_frame
		if main.p2.is_reloading:
			recharge_vue[0] = true
	_check("(jeu réel) un bot au chargeur vide recharge, et le chargeur redevient plein (%d / %d)" % [main.p2.current_ammo, main.p2.current_weapon.max_ammo],
		recharge_vue[0] and main.p2.current_ammo == main.p2.current_weapon.max_ammo)
	main.bullet_container.child_entered_tree.disconnect(compter)

	# La mort du JOUEUR : il revient au bout de ~2 s, loin du bot.
	print("\n--- Le joueur abattu revient, loin du bot ---")
	await _eteindre(poupee)
	await _poser_la_scene(main, c(20, 20), c(26, 20), profil_normal)
	await _images(30)
	main.p1.take_damage(500.0, main.p2)
	await _images(2)
	_check("abattu, le joueur est mort", main.p1.dead and main.p1.hp == 0.0)
	_check("… la manche n'est pas finie : il n'y en a pas (entraînement)", not main.round_active and main.training_mode)
	await _images(int(1.5 / PAS))
	_check("1,5 s plus tard, il est encore mort", main.p1.dead)
	await _images(int(0.8 / PAS))
	_check("2,3 s plus tard, il est revenu : vivant, plein de vie", not main.p1.dead and main.p1.hp == 100.0)
	_check("… ses visuels que la mort avait cachés sont rendus", main.p1.visual.visible and main.p1.visual_ptr.visible
		and main.p1.visual_dim.visible and main.p1.visual_reveal.visible and main.p1.get_node("VisualColored").visible)
	_check("… munitions pleines", main.p1.current_ammo == main.p1.current_weapon.max_ammo)
	var nav_jeu := Nav.depuis_carte(cartes.get_selected())
	var d_bot: float = main.p1.global_position.distance_to(main.p2.global_position)
	var plus_loin := 0.0
	for cc in nav_jeu.cases_atteignables(Nav.case_du_monde(main.p1.global_position)):
		plus_loin = maxf(plus_loin, Nav.centre_de_la_case(cc).distance_to(main.p2.global_position))
	_check("… revenu loin du bot : %.0f px, sur %.0f possibles" % [d_bot, plus_loin], d_bot >= 0.6 * plus_loin)
	_check("… sur une case praticable", nav_jeu.est_praticable(Nav.case_du_monde(main.p1.global_position)))
	main.p1.take_damage(500.0, main.p2)
	await _images(int(2.3 / PAS))
	_check("abattu une seconde fois, il revient aussi", not main.p1.dead and main.p1.hp == 100.0)

	# Retour à la cible immobile, puis à l'écran scindé : J2 retrouve son fournisseur local.
	print("\n--- Après le cran 3 : la cible immobile, puis l'écran scindé ---")
	main._apply_network_mode()
	cartes.select_map(cartes.DEFAULT_MAP_ID)
	main._on_main_menu_requested()
	await _images(2)
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	ui._on_hub_action("cran_cible")
	ui._on_hub_action("entrainement")
	await _images(3)
	_check("retour à la cible immobile : le bot a disparu, la cible est visible, J2 caché", main.p2.get_node_or_null("BotP2") == null
		and main.training_target.visible and not main.p2.visible and main._bot_p2 == null)
	main._on_main_menu_requested()
	await _images(2)
	main._on_replay_requested()
	await _images(3)
	var f2: Variant = main.p2.input_provider
	_check("un match en écran scindé lancé ensuite : J2 reprend son fournisseur local, plein de vie, vivant",
		f2 is LocalInputProvider and main.p2.hp == 100.0 and not main.p2.dead and main.p2.visible)
	_check("… et le fournisseur de J1 est un fournisseur local, pas la poupée du test", main.p1.input_provider is LocalInputProvider)
	main._on_main_menu_requested()
	await _images(2)
	cartes.select_map(cartes.DEFAULT_MAP_ID)


## Éteint la torche de la poupée et laisse à la lumière le temps de mourir : une torche qu'on coupe s'éteint en quelques images, et un
## bot posé devant la verrait encore — la brève lueur qu'il aurait vue, il a le droit d'y réagir.
func _eteindre(poupee: Poupee) -> void:
	poupee.torche = false
	await _images(30)


## Pose la carte d'essai (la paroi pleine) sur l'entraînement en cours.
func _poser_la_carte_du_jeu(main: Node) -> void:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(CARTE_JEU))
	var valide: Dictionary = Codec.validate(json.data as Dictionary)
	root.get_node("MapData").current_map_data = valide["data"]
	main.rebuild_arena()
	await _images(5)


## Met en scène : J1 (la poupée) en `pos_joueur`, le bot en `pos_bot` au `profil` donné — un bot NEUF, qui n'a rien perçu — et le
## cran de l'entraînement posé (la cible immobile cachée). Laisse trois images à la physique.
func _poser_la_scene(main: Node, pos_bot: Vector2, pos_joueur: Vector2, profil: ProfilBot) -> void:
	main._poser_l_adversaire(profil)
	main.p2.global_position = pos_bot
	main.p2.velocity = Vector2.ZERO
	main.p2.rotation = (pos_joueur - pos_bot).angle()
	main.p1.global_position = pos_joueur
	main.p1.velocity = Vector2.ZERO
	main.p1.rotation = PI
	main.p1.hp = 100.0
	main.p1.dead = false
	main.p2.hp = 100.0
	main.p2.dead = false
	main.p1.reset_step_tracker()
	main.p2.reset_step_tracker()
	var bot: BotInputProvider = main.p2.input_provider as BotInputProvider
	if bot != null:
		bot.reinitialiser()
	main.p2.current_ammo = main.p2.current_weapon.max_ammo
	main.p2.is_reloading = false
	main.p2.shoot_cooldown = 0.0
	await _images(3)
