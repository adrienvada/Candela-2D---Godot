## La garde de l'ÉQUIPEMENT du bot — chantier SOLO, étape S9 : il se sert de ses outils comme un joueur, et n'en tire AUCUNE information.
##
## Adrien, 2026-10-02 : « l'adversaire doit être honnête ». S9 donne au bot une torche qu'il allume et éteint à propos, une prudence (changer de
## place après un tir, s'accroupir pour approcher un son), la fusée et le gadget de sa classe. Cette suite prouve ce qui ne doit pas bouger :
##
##   • **L'HONNÊTETÉ** — aucun outil ne donne d'information. Un bot équipé de tout, devant un joueur dans le noir (derrière un mur, ou
##     silencieux), ne lance rien, ne pose rien, n'allume rien, et le texte de `equipement_bot.gd` ne lit nulle part l'autre joueur.
##   • **LES RÈGLES** — la torche (éteinte tant qu'il n'a rien perçu, allumée pour fouiller, éteinte pour s'approcher), la posture, le repli
##     après un tir, la fusée (vers une zone ENTENDUE, jamais vers une cible vue), et chacun des dix gadgets, posé au moins une fois dans une
##     mise en scène adaptée — d'abord sur des corps factices, puis dans le vrai jeu, par le vrai `player.gd`.
##   • **LES PROFILS SANS ÉQUIPEMENT N'ONT PAS CHANGÉ** — mêmes commandes, à la graine près, que le bot de S4 : la suite compare le flux de
##     commandes (`tools/flux_commandes_bot.gd`) à des empreintes relevées sur le code d'AVANT S9.
##
## ## Deux couches, comme `test_bot_combat`
##
##   1. **Des corps factices** (`FauxEquipe` : l'essentiel de `player.gd` — visée, cadence, recharge, posture, et l'appui des touches de fusée
##      et de gadget, que le corps vrai transmet au nœud d'arbitrage) avec le VRAI fournisseur et le VRAI nœud de perception. Un faux nœud
##      d'arbitrage (`FauxJeu`) tient la réserve : fusées, gadget, recharge d'une minute.
##   2. **Le jeu monté** (`main.tscn`, vrai `Player`, vrai `GameState`, vrais gadgets et vraie fusée, **à pas d'image fixe**) : chacune des dix
##      classes est mise en scène, et son gadget naît dans l'arène, posé par le bot, au bon endroit.
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`). Les compteurs passent par des TABLEAUX (une lambda capture un entier par copie).
##
## **Sabotée** (la règle du dépôt) : la liste est dans la ROADMAP, section SOLO, S9.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_bot_equipement.gd [-- --empreintes]
extends SceneTree

const Flux := preload("res://tools/flux_commandes_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Bot := preload("res://bot_input_provider.gd")
const Equip := preload("res://equipement_bot.gd")
const Nav := preload("res://navigation_bot.gd")
const Memoire := preload("res://memoire_bot.gd")
const Percep := preload("res://perception_bot.gd")
const Codec := preload("res://map_codec.gd")
const ClasseDonnees := preload("res://class_data.gd")
const ProfilGadget := preload("res://gadget_profile.gd")

const PAS := 1.0 / 60.0
const TUILE := 35.0

## Les empreintes du flux de commandes des profils SANS équipement, relevées sur le code de S4 (`f113da8`) avec `tools/flux_commandes_bot.gd`
## — avant la moindre ligne de S9. Une clé : « profil/graine ». ⚠️ **Elles ne se « mettent à jour » pas pour faire taire la suite** : une
## empreinte qui bouge dit qu'un profil sans équipement n'a plus les mêmes commandes.
const EMPREINTES := {
	"entrainement_mobile/7": "dbf9b3198d0bad3231845da4ec434ecf",
	"entrainement_mobile/21": "4c1d245d3de75ceac9e19ad4c52b6d91",
	"facile/7": "ebc9592efb5650cd2ca7313ddd2f9428",
	"facile/21": "37220503006c5619c2eaeda6c197dc02",
	"normal/7": "a95239b295e46a05b6b3d4cc79a706ad",
	"normal/21": "3a865f33a428fd296fdb7e62c1bdb0b6",
	"difficile/7": "157607bd0c09783389acf4900c25d57a",
	"difficile/21": "ba535cbe1e1a7139b2e6497a30342825",
	"pnj_immobile_sourd_aveugle/7": "4b59af81f47c9e8425d76d4d38c357fa",
	"pnj_immobile_voit_lent/7": "24ce64dfbd036113e1d396f0705c634d",
	"pnj_immobile_voit_lent/21": "cee85c538af20944d74257982ff1c449",
	"pnj_immobile_entend_tres_lent/7": "f29eb55b5617f68da262f8cf35cca548",
	"pnj_immobile_entend_tres_lent/21": "9c783a51a234d119a0f2dbc27e8cd1c4",
	"pnj_libre_voit_entend_facile/7": "ebc9592efb5650cd2ca7313ddd2f9428",
	"pnj_zone_voit_entend_normal/7": "00a0ba323f33d9c5d486a5a74dc9d7da",
	"pnj_zone_voit_entend_normal/21": "d78248be5b8f6b61bcd12ac6de77fd9c",
	"boss/7": "a95239b295e46a05b6b3d4cc79a706ad",
	"boss/21": "3a865f33a428fd296fdb7e62c1bdb0b6",
}

var _failures := 0
var _verifications := 0
var _arme: WeaponData = null
var _navigation: NavigationBot = null


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
	await process_frame
	if OS.get_cmdline_user_args().has("--empreintes"):
		await _relever_les_empreintes()
		quit(0)
		return
	print("=== LE BOT S'ÉQUIPE, HONNÊTEMENT (S9) ===")
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe, "lancer avec --fixed-fps 60")
	if not horloge_fixe:
		_sortir()
		return
	var statiques := Flux.poser_les_statiques()
	_arme = WeaponData.new()
	_arme.max_ammo = 6
	_arme.cooldown = 0.16
	_navigation = Nav.depuis_carte(Flux.carte())
	_les_constantes_recopiees()
	_les_profils()
	_la_torche_pure()
	_la_posture_pure()
	_la_fusee_pure()
	_les_gadgets_purs()
	_le_repli_pur()
	_le_texte()
	await _les_empreintes()
	await _la_torche_en_marche()
	await _la_posture_en_marche()
	await _le_repli_en_marche()
	await _la_fusee_en_marche()
	await _les_dix_gadgets_sur_des_corps_factices()
	await _la_bobine_et_le_puis()
	await _l_honnetete_de_l_equipement()
	await _la_perception_sous_gadget()
	Flux.rendre_les_statiques(statiques)
	await _le_jeu_monte()
	_sortir()


func _sortir() -> void:
	print("\n%d vérifications" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


func _images(n: int) -> void:
	for _i in n:
		await process_frame


static func c(x: int, y: int) -> Vector2:
	return Flux.c(x, y)


## Les empreintes à reporter dans `EMPREINTES` : à lancer SUR LE CODE D'AVANT (le profil sans équipement n'a pas changé tant qu'elles égalent
## celles de S4). `-- --empreintes` imprime une ligne par cas.
func _relever_les_empreintes() -> void:
	for cle in _cas_des_empreintes():
		var nom: String = cle.split("/")[0]
		var graine := int(cle.split("/")[1])
		var p := Flux.sans_equipement(_profil_de_l_empreinte(nom))
		var r: Dictionary = await Flux.rejouer(self, p, graine)
		print("\"%s\": \"%s\"," % [cle, r["digest"]])


func _cas_des_empreintes() -> Array:
	return EMPREINTES.keys()


func _profil_de_l_empreinte(nom: String) -> ProfilBot:
	match nom:
		"entrainement_mobile":
			return Profil.pour_entrainement_mobile()
		"facile":
			return Profil.pour_adversaire_qui_tire(Profil.Difficulte.FACILE)
		"normal":
			return Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
		"difficile":
			return Profil.pour_adversaire_qui_tire(Profil.Difficulte.DIFFICILE)
		"boss":
			return Profil.boss()
	return Profil.pnj_nomme(nom.trim_prefix("pnj_"))


# ---------------------------------------------------------------------------
# Les corps factices : ce que `player.gd` fait des commandes, et ce que le nœud d'arbitrage fait des appuis
# ---------------------------------------------------------------------------

## La BOBINE du grésillement, vue du nœud d'arbitrage : un interrupteur.
class FausseBobine extends Node:
	var actif := false
	var poseur_id := 1

	func est_basculable() -> bool:
		return true


## Le nœud d'arbitrage factice (`GameState`) : la réserve de fusées, la recharge d'une minute du gadget, la bobine posée. Dans le groupe
## `game_state`, comme le vrai : c'est là que le fournisseur va lire SA réserve.
class FauxJeu extends Node:
	var fusees := 1
	var gadget_libre := true
	var bobine: FausseBobine = null

	func _ready() -> void:
		add_to_group("game_state")

	func fusee_disponible(_pid: int) -> bool:
		return fusees > 0

	func gadget_disponible(_pid: int) -> bool:
		return gadget_libre

	func gadget_basculable_de(_pid: int) -> Node:
		return bobine


## Un tireur factice qui transmet aussi les appuis de fusée et de gadget : sur le FRONT montant, mains libres (`shoot_cooldown` nul), comme
## `player.gd`. Il garde ce qui est parti : les fusées (instant, cap, place), les poses (slug, cap, place), les bascules de la bobine.
class FauxEquipe extends Flux.FauxTireur:
	var jeu: FauxJeu = null
	var slug := ""
	var lancers: Array[Dictionary] = []
	var poses: Array[Dictionary] = []
	var bascules: Array[float] = []
	var _fusee_avant := false
	var _gadget_avant := false

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if input_provider == null or jeu == null:
			return
		var fusee := input_provider.is_flare_pressed()
		if fusee and not _fusee_avant and shoot_cooldown <= 0.0 and jeu.fusee_disponible(player_id):
			lancers.append({"t": t, "rotation": rotation, "pos": global_position})
			shoot_cooldown = 0.6
			jeu.fusees -= 1
		_fusee_avant = fusee
		var gadget := input_provider.is_gadget_pressed()
		if gadget and not _gadget_avant:
			if jeu.bobine != null:
				jeu.bobine.actif = not jeu.bobine.actif
				bascules.append(t)
			elif shoot_cooldown <= 0.0 and jeu.gadget_disponible(player_id):
				poses.append({"t": t, "rotation": rotation, "pos": global_position, "slug": slug})
				shoot_cooldown = 0.3
				jeu.gadget_libre = false
				if slug == "gresillement":
					jeu.bobine = FausseBobine.new()
					jeu.add_child(jeu.bobine)
		_gadget_avant = gadget


class Rig extends RefCounted:
	var scene: Node2D
	var tireur: FauxEquipe
	var cible: Flux.FauxJoueur
	var bot: BotInputProvider
	var jeu: FauxJeu
	## Le journal d'états du bot : une entrée à chaque CHANGEMENT d'état.
	var etats: Array = []
	var _dernier := -1

	func suivre() -> void:
		if bot.etat != _dernier:
			_dernier = bot.etat
			etats.append([tireur.t, bot.etat])

	## Libère la scène SUR-LE-CHAMP : un `queue_free` laisse les corps de la situation d'avant dans le groupe `players` et dans le groupe
	## `game_state` jusqu'à la fin de l'image (« Un corps libéré par `queue_free()`… », Pièges connus).
	func liberer() -> void:
		if scene != null and is_instance_valid(scene):
			scene.get_parent().remove_child(scene)
			scene.free()


## Une arme de classe : un `ClassData` dont le gadget est `slug` (ou aucun si `slug` est vide). Le fichier du gadget n'est pas chargé : le bot
## ne lit que le slug et `est_livre()`.
func _classe(slug: String) -> WeaponData:
	var a := ClasseDonnees.new()
	a.max_ammo = 6
	a.cooldown = 0.16
	if slug != "":
		var g := ProfilGadget.new()
		g.slug = slug
		g.implementation = "res://gadget_%s.gd" % slug
		a.gadget = g
	return a


## Monte une situation : un tireur factice piloté par le VRAI fournisseur, une cible factice, un faux nœud d'arbitrage. `profil` règle le bot ;
## `slug` : le gadget de sa classe ("" : aucun) ; `pos_bot`, `pos_cible` en pixels ; `vers` : où le tireur regarde au départ.
func _rig(profil: ProfilBot, slug: String, pos_bot: Vector2, pos_cible: Vector2, graine: int = 7, vers: Vector2 = Vector2.RIGHT) -> Rig:
	var r := Rig.new()
	r.scene = Node2D.new()
	r.scene.name = "SceneEquipement"
	root.add_child(r.scene)
	r.jeu = FauxJeu.new()
	r.jeu.name = "FauxJeu"
	r.scene.add_child(r.jeu)
	var arme := _classe(slug)
	r.tireur = FauxEquipe.new(arme)
	r.tireur.jeu = r.jeu
	r.tireur.slug = slug
	r.cible = Flux.FauxJoueur.new(arme)
	r.scene.add_child(r.tireur)
	r.scene.add_child(r.cible)
	r.tireur.global_position = pos_bot
	r.tireur.rotation = vers.angle()
	r.cible.global_position = pos_cible
	r.cible.rotation = PI
	r.bot = Bot.new()
	r.bot.configurer(profil, _navigation, graine)
	r.tireur.input_provider = r.bot
	r.tireur.add_child(r.bot)
	return r


## Un profil de test : NORMAL, SANS équipement (les champs de S9 éteints), immobile par défaut ; `changements` pose les champs voulus.
func _profil(changements: Dictionary = {}, immobile: bool = true) -> ProfilBot:
	var p := Flux.sans_equipement(Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL))
	if immobile:
		p.deplacement = Profil.Deplacement.IMMOBILE
	for k in changements:
		p.set(k, changements[k])
	return p


func _derouler(r: Rig, n: int, jusqua: Callable = Callable()) -> void:
	for _i in n:
		await physics_frame
		r.suivre()
		if jusqua.is_valid() and bool(jusqua.call()):
			return


## Un pas entendu à `pos` : le VRAI signal de l'audio, tel que le nœud de perception le reçoit.
func _son(famille: String, pos: Vector2, emetteur: int = 0) -> void:
	var audio: Node = root.get_node("AudioManager")
	audio.son_localise.emit(Flux.evenement(audio, famille, pos, emetteur))


# ---------------------------------------------------------------------------
# Les constantes recopiées
# ---------------------------------------------------------------------------

func _les_constantes_recopiees() -> void:
	print("\n[Les nombres recopiés ne dérivent pas]")
	_check("les états de `EquipementBot` sont ceux de `BotInputProvider.Etat`",
		Equip.ETAT_PATROUILLE == Bot.Etat.PATROUILLE and Equip.ETAT_ENQUETE == Bot.Etat.ENQUETE
		and Equip.ETAT_RECHERCHE == Bot.Etat.RECHERCHE and Equip.ETAT_COMBAT == Bot.Etat.COMBAT)
	var joueur: GDScript = load("res://player.gd")
	var facteur: float = float(joueur.get_script_constant_map()["FACTEUR_VITESSE_ACCROUPI"])
	_check("le facteur d'un accroupi est celui du joueur (%.2f)" % facteur, is_equal_approx(Equip.FACTEUR_ACCROUPI, facteur))
	var base: GDScript = load("res://gadget_base.gd")
	_check("les 96 px de pose que le bot suppose sont `GadgetBase.PORTEE_POSE`",
		is_equal_approx(float(base.get_script_constant_map()["PORTEE_POSE"]), 96.0))
	var fusee: GDScript = load("res://fusee_modele.gd")
	var cm: Dictionary = fusee.get_script_constant_map()
	var portee_libre := float(cm["VITESSE_LANCER"]) * float(cm["VITESSE_LANCER"]) / (2.0 * float(cm["FROTTEMENT_VOL"]))
	_check("la portée libre d'une fusée (%.0f px, v²/2f) tient dans les distances de lancer du bot [%.0f, %.0f]" % [
		portee_libre, Equip.FUSEE_DISTANCE_MIN, Equip.FUSEE_DISTANCE_MAX],
		portee_libre >= Equip.FUSEE_DISTANCE_MIN and portee_libre <= Equip.FUSEE_DISTANCE_MAX)
	_check("le désarmement d'un lancer (%.1f s) dépasse le seuil avec lequel le bot le reconnaît (%.1f s)" % [
		float(cm["DESARMEMENT"]), Bot.DESARMEMENT_MINIMAL_FUSEE], float(cm["DESARMEMENT"]) > Bot.DESARMEMENT_MINIMAL_FUSEE)


# ---------------------------------------------------------------------------
# Les profils
# ---------------------------------------------------------------------------

func _les_profils() -> void:
	print("\n[Les profils : sans équipement, rien n'a changé ; le boss sait se servir de son gadget]")
	var neuf := Profil.new()
	_check("un profil neuf n'a aucun outil : tous les champs de S9 sont éteints",
		not neuf.torche_tactique and not neuf.torche_en_patrouille and neuf.repli_apres_tir_s == 0.0
		and neuf.accroupi_pres_du_son_px == 0.0 and not neuf.lance_des_fusees and not neuf.utilise_le_gadget and not neuf.est_equipe())
	_check("le profil du cran 2 (« adversaire mobile ») n'a aucun outil : sa torche est fixe et éteinte",
		not Profil.pour_entrainement_mobile().est_equipe() and not Profil.pour_entrainement_mobile().torche_allumee)
	var tous := true
	var intrus := ""
	for nom in Profil.noms_du_catalogue():
		if Profil.pnj_nomme(nom).est_equipe():
			tous = false
			intrus = nom
	_check("les 64 PNJ du catalogue (le sourd et aveugle compris) n'ont aucun outil : l'initiation ne change pas", tous, intrus)
	var f := Profil.pour_adversaire_qui_tire(Profil.Difficulte.FACILE)
	var n := Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
	var d := Profil.pour_adversaire_qui_tire(Profil.Difficulte.DIFFICILE)
	var b := Profil.boss()
	_check("le boss porte les outils du profil NORMAL, champ pour champ",
		b.torche_tactique == n.torche_tactique and b.torche_en_patrouille == n.torche_en_patrouille
		and is_equal_approx(b.torche_rayon_fouille_px, n.torche_rayon_fouille_px) and is_equal_approx(b.repli_apres_tir_s, n.repli_apres_tir_s)
		and is_equal_approx(b.accroupi_pres_du_son_px, n.accroupi_pres_du_son_px) and b.lance_des_fusees == n.lance_des_fusees
		and b.utilise_le_gadget == n.utilise_le_gadget)
	_check("le boss — NORMAL — se sert du gadget de sa classe (« il doit savoir se servir de chacun des dix gadgets »)",
		b.utilise_le_gadget and n.utilise_le_gadget and d.utilise_le_gadget)
	_check("les outils ne changent NI la perception NI les réflexes : les champs de S3 et de S4 sont ceux de la table unique",
		f.voit and f.entend and n.voit and n.entend and d.voit and d.entend and is_equal_approx(n.delai_reaction, 0.26)
		and is_equal_approx(d.delai_reaction, 0.235) and is_equal_approx(f.delai_reaction, 0.40) and is_equal_approx(n.precision_auditive, 1.0)
		and is_equal_approx(d.precision_auditive, 1.0))
	_check("FACILE n'a pas plus d'outils que NORMAL, ni NORMAL que DIFFICILE (la difficulté monte avec l'équipement)",
		_nombre_d_outils(f) <= _nombre_d_outils(n) and _nombre_d_outils(n) <= _nombre_d_outils(d))
	# Les trois difficultés gardent leurs mêmes champs de perception et de déplacement, équipées ou non.
	var communs := ["voit", "entend", "precision_auditive", "delai_oubli", "deplacement", "allure", "torche_allumee", "agit", "tire", "audace_zone_px"]
	var identiques := true
	for champ in communs:
		if f.get(champ) != n.get(champ) or n.get(champ) != d.get(champ):
			identiques = false
	_check("les trois difficultés ont toujours les mêmes champs de perception, de déplacement, d'audace (équipées ou non)", identiques)


static func _nombre_d_outils(p: ProfilBot) -> int:
	var k := 0
	for u in [p.torche_tactique, p.repli_apres_tir_s > 0.0, p.accroupi_pres_du_son_px > 0.0, p.lance_des_fusees, p.utilise_le_gadget]:
		if u:
			k += 1
	return k


# ---------------------------------------------------------------------------
# La torche (pure)
# ---------------------------------------------------------------------------

func _la_torche_pure() -> void:
	print("\n[La torche : éteinte tant qu'il n'a rien perçu, allumée pour fouiller, éteinte pour s'approcher]")
	var fixe := _profil({"torche_allumee": true})
	_check("sans torche tactique, la torche est FIXE : allumée reste allumée, éteinte reste éteinte, quoi qu'il perçoive",
		Equip.torche_voulue(fixe, Equip.ETAT_PATROUILLE, false, INF, false, false)
		and Equip.torche_voulue(fixe, Equip.ETAT_ENQUETE, true, 900.0, false, false)
		and not Equip.torche_voulue(_profil({"torche_allumee": false}), Equip.ETAT_COMBAT, true, 100.0, true, false))
	var p := _profil({"torche_tactique": true, "torche_rayon_fouille_px": 300.0})
	_check("tactique : jamais allumée en patrouille — un bot prudent ne se trahit pas pour rien",
		not Equip.torche_voulue(p, Equip.ETAT_PATROUILLE, false, INF, false, false))
	_check("… sauf un profil qui le dit (`torche_en_patrouille`)",
		Equip.torche_voulue(_profil({"torche_tactique": true, "torche_en_patrouille": true}), Equip.ETAT_PATROUILLE, false, INF, false, false))
	_check("enquête, loin de la zone (500 px > 300) : éteinte — il s'approche dans le noir",
		not Equip.torche_voulue(p, Equip.ETAT_ENQUETE, true, 500.0, false, false))
	_check("enquête, à portée de fouiller (250 px ≤ 300) : allumée",
		Equip.torche_voulue(p, Equip.ETAT_ENQUETE, true, 250.0, false, false))
	_check("recherche (la cible perdue de vue) : la même règle — loin éteinte, près allumée",
		not Equip.torche_voulue(p, Equip.ETAT_RECHERCHE, true, 500.0, false, false) and Equip.torche_voulue(p, Equip.ETAT_RECHERCHE, true, 250.0, false, false))
	_check("hystérésis : allumée à 340 px elle reste allumée (limite 360), à 370 elle s'éteint ; éteinte à 340 elle ne s'allume pas",
		Equip.torche_voulue(p, Equip.ETAT_ENQUETE, true, 340.0, true, false) and not Equip.torche_voulue(p, Equip.ETAT_ENQUETE, true, 370.0, true, false)
		and not Equip.torche_voulue(p, Equip.ETAT_ENQUETE, true, 340.0, false, false))
	_check("sans trace en mémoire, ou avec un rayon de fouille nul : éteinte",
		not Equip.torche_voulue(p, Equip.ETAT_ENQUETE, false, 100.0, true, false)
		and not Equip.torche_voulue(_profil({"torche_tactique": true, "torche_rayon_fouille_px": 0.0}), Equip.ETAT_ENQUETE, true, 10.0, false, false))
	_check("combat : INCHANGÉE — allumée elle reste allumée (éteindre en plein tir ferait perdre la cible qu'elle révèle), éteinte il ne l'allume pas",
		Equip.torche_voulue(p, Equip.ETAT_COMBAT, true, 100.0, true, false) and not Equip.torche_voulue(p, Equip.ETAT_COMBAT, true, 100.0, false, false))
	_check("en repli : TOUJOURS éteinte — il s'éloigne d'un endroit que son tir a trahi",
		not Equip.torche_voulue(p, Equip.ETAT_COMBAT, true, 100.0, true, true) and not Equip.torche_voulue(p, Equip.ETAT_ENQUETE, true, 100.0, true, true))


func _la_posture_pure() -> void:
	print("\n[La posture : s'accroupir pour approcher un son]")
	var p := _profil({"accroupi_pres_du_son_px": 450.0})
	_check("enquête sur une trace d'OUÏE à 400 px : accroupi",
		Equip.accroupi_voulu(p, Equip.ETAT_ENQUETE, Memoire.Source.OUIE, true, 400.0, false))
	_check("… pas à 500 px, sauf s'il l'est déjà (hystérésis 40 px : jusqu'à 490)",
		not Equip.accroupi_voulu(p, Equip.ETAT_ENQUETE, Memoire.Source.OUIE, true, 500.0, false)
		and Equip.accroupi_voulu(p, Equip.ETAT_ENQUETE, Memoire.Source.OUIE, true, 480.0, true)
		and not Equip.accroupi_voulu(p, Equip.ETAT_ENQUETE, Memoire.Source.OUIE, true, 500.0, true))
	_check("jamais sur une trace de VUE, jamais en combat, en recherche ni en patrouille, jamais sans trace",
		not Equip.accroupi_voulu(p, Equip.ETAT_ENQUETE, Memoire.Source.VUE, true, 100.0, false)
		and not Equip.accroupi_voulu(p, Equip.ETAT_COMBAT, Memoire.Source.OUIE, true, 100.0, false)
		and not Equip.accroupi_voulu(p, Equip.ETAT_RECHERCHE, Memoire.Source.OUIE, true, 100.0, false)
		and not Equip.accroupi_voulu(p, Equip.ETAT_PATROUILLE, Memoire.Source.OUIE, true, 100.0, false)
		and not Equip.accroupi_voulu(p, Equip.ETAT_ENQUETE, Memoire.Source.OUIE, false, 100.0, false))
	_check("distance nulle du profil : jamais accroupi (le bot de S4 ne s'accroupissait pas)",
		not Equip.accroupi_voulu(_profil(), Equip.ETAT_ENQUETE, Memoire.Source.OUIE, true, 10.0, false))


# ---------------------------------------------------------------------------
# La fusée (pure)
# ---------------------------------------------------------------------------

func _situation_de_fusee(changements: Dictionary = {}) -> Dictionary:
	var s := {
		"profil": _profil({"lance_des_fusees": true}), "etat": Equip.ETAT_ENQUETE, "source": Memoire.Source.OUIE, "connue": true,
		"distance": 350.0, "rayon": 80.0, "confiance": 0.9, "ecart_deg": 3.0, "vu": false, "libre": true,
		"fusee_disponible": true, "mains_libres": true,
	}
	for k in changements:
		s[k] = changements[k]
	return s


func _la_fusee_pure() -> void:
	print("\n[La fusée : vers une zone ENTENDUE qu'il ne voit pas, jamais vers une cible vue]")
	_check("la situation de base — une zone entendue à 350 px, nette, en face, dégagée, une fusée en réserve — la fait lancer",
		Equip.fusee_voulue(_situation_de_fusee()))
	var refus := {
		"le profil ne lance pas de fusée": {"profil": _profil()},
		"plus de fusée en réserve": {"fusee_disponible": false},
		"les mains occupées (tir, pose, désarmement)": {"mains_libres": false},
		"patrouille : il n'a rien perçu": {"etat": Equip.ETAT_PATROUILLE},
		"combat : il voit sa cible": {"etat": Equip.ETAT_COMBAT},
		"recherche : une place VUE qu'il vient de perdre": {"etat": Equip.ETAT_RECHERCHE},
		"la trace est une VUE, pas un son": {"source": Memoire.Source.VUE},
		"la cible est vue à cet instant": {"vu": true},
		"trop près (230 px < 240) : la fusée l'éclairerait lui": {"distance": 230.0},
		"trop loin (480 px > 470) : elle s'allumerait plus près de lui que de la zone": {"distance": 480.0},
		"zone trop vaste (330 px > 320) : elle ne l'éclairerait qu'en partie": {"rayon": 330.0},
		"trace presque oubliée (confiance 0,2)": {"confiance": 0.2},
		"un mur entre lui et la zone (la fusée rebondirait)": {"libre": false},
		"de travers (11° > 10°) : elle part droit devant le corps": {"ecart_deg": 11.0},
		"sans trace en mémoire": {"connue": false},
	}
	for raison in refus:
		_check("pas de fusée : %s" % raison, not Equip.fusee_voulue(_situation_de_fusee(refus[raison])))
	_check("aux limites exactes (240 px, 470 px, 320 px, 10°) elle part encore",
		Equip.fusee_voulue(_situation_de_fusee({"distance": 240.0})) and Equip.fusee_voulue(_situation_de_fusee({"distance": 470.0}))
		and Equip.fusee_voulue(_situation_de_fusee({"rayon": 320.0})) and Equip.fusee_voulue(_situation_de_fusee({"ecart_deg": 10.0})))


# ---------------------------------------------------------------------------
# Les gadgets (purs)
# ---------------------------------------------------------------------------

## Une situation qui satisfait la règle de `slug`, au milieu de sa fenêtre de distance.
func _situation_de_gadget(slug: String, changements: Dictionary = {}) -> Dictionary:
	var r: Dictionary = Equip.GADGETS[slug]
	var fenetre: Array = r["distance"]
	var s := {
		"etat": (r["etats"] as Array)[0], "connue": true, "distance": (float(fenetre[0]) + float(fenetre[1])) * 0.5, "ecart_deg": 5.0, "libre": true,
		"vu": int(r["vu"]) == 1, "lampe_vue": bool(r["lampe"]), "touche_depuis": 0.5 if bool(r["touche"]) else INF,
		"rafale_depuis": 0.3 if bool(r["apres_rafale"]) else INF, "gadget_disponible": true, "mains_libres": true,
	}
	for k in changements:
		s[k] = changements[k]
	return s


func _les_gadgets_purs() -> void:
	print("\n[Les dix gadgets : une règle chacun, comptée contre le catalogue du jeu]")
	var jeu: GDScript = load("res://game_state.gd")
	var catalogue: Dictionary = jeu.get_script_constant_map()["IMPLEMENTATIONS"]
	var slugs: Array = catalogue.keys()
	slugs.sort()
	var regles: Array = Equip.GADGETS.keys()
	regles.sort()
	_check("le catalogue du jeu compte dix gadgets", slugs.size() == 10, str(slugs))
	_check("les règles du bot sont EXACTEMENT les gadgets du catalogue : un onzième gadget sans règle, ou une règle sans gadget, fait rougir (%s)" % str(regles),
		slugs == regles, "catalogue %s ≠ règles %s" % [str(slugs), str(regles)])
	var chaque := true
	var detail := ""
	for slug in Equip.GADGETS:
		var r: Dictionary = Equip.GADGETS[slug]
		var f: Array = r["distance"]
		var ok := String(r["pourquoi"]).length() > 20 and (r["etats"] as Array).size() > 0 and float(f[0]) > 0.0 and float(f[0]) < float(f[1]) \
			and [Equip.PUIS_RIEN, Equip.PUIS_RECUL, Equip.PUIS_DEDANS].has(String(r["puis"])) and [-1, 0, 1].has(int(r["vu"]))
		for e in r["etats"]:
			ok = ok and int(e) != Equip.ETAT_PATROUILLE
		if not ok:
			chaque = false
			detail = slug
	_check("chaque règle dit POURQUOI, sa fenêtre de distance est bien formée, et AUCUNE ne pose en patrouille (il n'a rien perçu)", chaque, detail)
	for slug in Equip.GADGETS:
		_check("« %s » : la situation qui satisfait sa règle le fait poser" % slug, Equip.gadget_voulu(slug, _situation_de_gadget(slug)))
	for slug in Equip.GADGETS:
		var r: Dictionary = Equip.GADGETS[slug]
		var f: Array = r["distance"]
		var refus := {
			"plus de gadget en réserve (recharge d'une minute)": {"gadget_disponible": false},
			"les mains occupées": {"mains_libres": false},
			"patrouille": {"etat": Equip.ETAT_PATROUILLE},
			"sans trace en mémoire": {"connue": false},
			"trop près": {"distance": float(f[0]) - 1.0},
			"trop loin": {"distance": float(f[1]) + 1.0},
			"de travers (26° > 25°)": {"ecart_deg": 26.0},
			"un mur entre lui et la place visée": {"libre": false},
		}
		var tout_refuse := true
		var qui := ""
		for raison in refus:
			if Equip.gadget_voulu(slug, _situation_de_gadget(slug, refus[raison])):
				tout_refuse = false
				qui = raison
		_check("« %s » : refusé dans huit cas (réserve, mains, patrouille, trace, trop près, trop loin, de travers, mur)" % slug, tout_refuse, qui)
	# Les conditions propres à chaque règle.
	_check("poussière, torche fantôme, poudre, mine : posés quand il n'a RIEN vu — jamais sur une cible vue",
		not Equip.gadget_voulu("poussiere", _situation_de_gadget("poussiere", {"vu": true}))
		and not Equip.gadget_voulu("torche_fantome", _situation_de_gadget("torche_fantome", {"vu": true}))
		and not Equip.gadget_voulu("poudre_contact", _situation_de_gadget("poudre_contact", {"vu": true}))
		and not Equip.gadget_voulu("mine_magnesium", _situation_de_gadget("mine_magnesium", {"vu": true})))
	_check("leurre, suie, braises : posés sur une cible VUE — pas sur une zone entendue",
		not Equip.gadget_voulu("leurre", _situation_de_gadget("leurre", {"vu": false}))
		and not Equip.gadget_voulu("cartouche_suie", _situation_de_gadget("cartouche_suie", {"vu": false}))
		and not Equip.gadget_voulu("nappe_braises", _situation_de_gadget("nappe_braises", {"vu": false})))
	_check("le leurre ne se pose qu'APRÈS une rafale (0,8 s) ; la suie qu'après un coup reçu (2 s)",
		not Equip.gadget_voulu("leurre", _situation_de_gadget("leurre", {"rafale_depuis": 0.9}))
		and not Equip.gadget_voulu("leurre", _situation_de_gadget("leurre", {"rafale_depuis": INF}))
		and not Equip.gadget_voulu("cartouche_suie", _situation_de_gadget("cartouche_suie", {"touche_depuis": 2.1}))
		and not Equip.gadget_voulu("cartouche_suie", _situation_de_gadget("cartouche_suie", {"touche_depuis": INF})))
	_check("l'ombre habitée et le voile exigent la TORCHE de la cible, VUE (« la torche trahit ») : sans elle, pas de pose",
		not Equip.gadget_voulu("ombre_habitee", _situation_de_gadget("ombre_habitee", {"lampe_vue": false}))
		and not Equip.gadget_voulu("voile", _situation_de_gadget("voile", {"lampe_vue": false})))
	_check("la poussière, jamais en combat (le nuage boucherait aussi sa vue) ; la suie, la poudre, la mine : seulement dans leurs états",
		not Equip.gadget_voulu("poussiere", _situation_de_gadget("poussiere", {"etat": Equip.ETAT_COMBAT}))
		and not Equip.gadget_voulu("mine_magnesium", _situation_de_gadget("mine_magnesium", {"etat": Equip.ETAT_COMBAT}))
		and not Equip.gadget_voulu("cartouche_suie", _situation_de_gadget("cartouche_suie", {"etat": Equip.ETAT_ENQUETE}))
		and not Equip.gadget_voulu("poudre_contact", _situation_de_gadget("poudre_contact", {"etat": Equip.ETAT_COMBAT})))
	_check("la mine et la suie demandent un geste de plus (reculer, se mettre dedans) ; les huit autres, aucun",
		Equip.puis_de("mine_magnesium") == Equip.PUIS_RECUL and Equip.puis_de("cartouche_suie") == Equip.PUIS_DEDANS
		and Equip.puis_de("voile") == Equip.PUIS_RIEN and Equip.puis_de("gresillement") == Equip.PUIS_RIEN and Equip.puis_de("inconnu") == Equip.PUIS_RIEN)
	_check("un slug inconnu ne pose rien", not Equip.gadget_voulu("inconnu", _situation_de_gadget("voile")))
	# La bobine : un interrupteur.
	_check("la bobine s'allume quand la torche de la cible est VUE et que la place visée est à moins de 330 px",
		Equip.bobine_voulue(Equip.ETAT_COMBAT, true, 300.0, true, false) and Equip.bobine_voulue(Equip.ETAT_ENQUETE, true, 100.0, true, false))
	_check("… pas sans torche vue, pas à 340 px, pas en patrouille ni sans trace",
		not Equip.bobine_voulue(Equip.ETAT_COMBAT, true, 300.0, false, false) and not Equip.bobine_voulue(Equip.ETAT_COMBAT, true, 340.0, true, false)
		and not Equip.bobine_voulue(Equip.ETAT_PATROUILLE, true, 100.0, true, false) and not Equip.bobine_voulue(Equip.ETAT_COMBAT, false, 100.0, true, false))
	_check("allumée, elle reste allumée en combat à moins de 330 px même quand la lampe a cligné ; elle s'éteint quand rien ne la justifie plus",
		Equip.bobine_voulue(Equip.ETAT_COMBAT, true, 300.0, false, true) and not Equip.bobine_voulue(Equip.ETAT_RECHERCHE, true, 300.0, false, true)
		and not Equip.bobine_voulue(Equip.ETAT_PATROUILLE, false, INF, false, true))


# ---------------------------------------------------------------------------
# Le repli (pur)
# ---------------------------------------------------------------------------

func _le_repli_pur() -> void:
	print("\n[Le repli : hors de l'axe, hors de la vue du tireur quand la carte le permet]")
	var monde := Percep.monde_de_la_carte(Flux.carte())
	var pos := c(10, 15)
	var menace := c(20, 15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lateral_ok := true
	var recul_ok := true
	var detail := ""
	for _i in 30:
		var cl := Equip.case_de_repli(_navigation, monde, pos, menace, Equip.Repli.LATERAL, rng)
		var vers := Nav.centre_de_la_case(cl) - pos
		if cl.x < 0 or vers.length() < Equip.DISTANCE_REPLI_LATERAL.x - 0.01 or vers.length() > Equip.DISTANCE_REPLI_LATERAL.y + 0.01 \
				or absf((menace - pos).angle_to(vers)) < deg_to_rad(Equip.ANGLE_REPLI_LATERAL_DEG) - 0.001:
			lateral_ok = false
			detail = "case %s, %.0f px" % [str(cl), vers.length()]
		var cr := Equip.case_de_repli(_navigation, monde, pos, menace, Equip.Repli.RECUL, rng)
		var vr := Nav.centre_de_la_case(cr) - pos
		if cr.x < 0 or vr.length() < Equip.DISTANCE_REPLI_RECUL.x - 0.01 or vr.length() > Equip.DISTANCE_REPLI_RECUL.y + 0.01 \
				or absf((menace - pos).angle_to(vr)) < deg_to_rad(Equip.ANGLE_REPLI_RECUL_DEG) - 0.001:
			recul_ok = false
			detail = "recul : case %s, %.0f px" % [str(cr), vr.length()]
	_check("30 repli de côté : toujours à 3-7 cases, à plus de 60° de l'axe vers la menace", lateral_ok, detail)
	_check("30 reculs : toujours à 5-10 cases, à plus de 140° de l'axe (le dos à la menace)", recul_ok, detail)
	# Préférence pour une case que la menace ne voit pas : la paroi pleine (x = 26, y de 8 à 21) cache la case de l'autre côté.
	var pos2 := c(25, 14)
	var menace2 := c(30, 14)
	var cachees := 0
	var vues := 0
	for _i in 30:
		var cl := Equip.case_de_repli(_navigation, monde, pos2, menace2, Equip.Repli.LATERAL, rng)
		if cl.x < 0:
			continue
		if Percep.segment_degage(menace2, Nav.centre_de_la_case(cl), monde):
			vues += 1
		else:
			cachees += 1
	_check("quand une case cachée existe il la préfère (%d cachées, %d vues sur 30)" % [cachees, vues], cachees > 0 and cachees >= vues)
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 5
	r2.seed = 5
	var a := Equip.case_de_repli(_navigation, monde, pos, menace, Equip.Repli.LATERAL, r1)
	var b := Equip.case_de_repli(_navigation, monde, pos, menace, Equip.Repli.LATERAL, r2)
	_check("même graine, même case : le seul tirage du repli est celui qu'on lui donne", a == b)
	# Aucune case : un bot enfermé dans une cellule d'une case ne se replie pas.
	var cellule := Codec.new_map("cellule", Vector2i(5, 5))
	cellule["floor"] = Codec.encode_runs([Vector2i(2, 2)] as Array[Vector2i])
	var nav_c := Nav.depuis_carte(cellule)
	var cl_c := Equip.case_de_repli(nav_c, Percep.monde_de_la_carte(cellule), c(2, 2), c(2, 2) + Vector2(100, 0), Equip.Repli.LATERAL, rng)
	_check("dans une cellule d'une case, aucun repli : `(-1, -1)`", cl_c == Vector2i(-1, -1), str(cl_c))


# ---------------------------------------------------------------------------
# Le texte : ce que ces fichiers ne lisent jamais
# ---------------------------------------------------------------------------

func _code_de(chemin: String) -> String:
	var texte := FileAccess.get_file_as_string(chemin)
	var code := ""
	for ligne in texte.split("\n"):
		if not String(ligne).strip_edges().begins_with("#"):
			code += ligne + "\n"
	return code


func _le_texte() -> void:
	print("\n[Le texte : l'équipement ne lit jamais l'autre joueur]")
	var code := _code_de("res://equipement_bot.gd")
	for interdit in ["\"players\"", "get_nodes_in_group", "find_child", "get_node(", "get_node_or_null(", "global_position", ".position", "flashlight",
			"muzzle_flash", "get_parent"]:
		_check("le code d'`equipement_bot.gd` ne contient pas « %s »" % interdit, not code.contains(interdit))
	var recherches := code.count("_in_group(")
	_check("la SEULE recherche de nœud est celle du nœud d'arbitrage (`GROUPE_DU_JEU`, « game_state ») : %d" % recherches,
		recherches == 1 and code.contains("get_first_node_in_group(GROUPE_DU_JEU)") and code.contains("const GROUPE_DU_JEU := \"game_state\""))
	var provider := _code_de("res://bot_input_provider.gd")
	for interdit in ["get_nodes_in_group", "get_first_node_in_group", "get_tree()", "\"players\"", "find_child", "get_node(", "get_node_or_null("]:
		_check("le code du fournisseur d'entrées, outils compris, ne contient pas « %s »" % interdit, not provider.contains(interdit))
	# Chaque champ de S9 est LU (« Un champ que personne ne lit ne se corrige pas tout seul »).
	for champ in ["torche_tactique", "torche_en_patrouille", "torche_rayon_fouille_px", "repli_apres_tir_s", "accroupi_pres_du_son_px", "lance_des_fusees",
			"utilise_le_gadget"]:
		_check("`profil.%s` est lu par le fournisseur ou par ses règles" % champ,
			provider.contains("profil." + champ) or code.contains("profil." + champ))
	_check("la torche tactique, la posture, la fusée et le gadget sont des COMMANDES du fournisseur : `is_flashlight_pressed`, `is_crouch_pressed`, `is_flare_pressed`, `is_gadget_pressed`",
		provider.contains("func is_flashlight_pressed") and provider.contains("func is_crouch_pressed") and provider.contains("func is_flare_pressed")
		and provider.contains("func is_gadget_pressed"))


# ---------------------------------------------------------------------------
# Les profils sans équipement n'ont pas changé
# ---------------------------------------------------------------------------

func _les_empreintes() -> void:
	print("\n[Les profils sans équipement : le flux de commandes est celui de S4, à la graine près]")
	var tout := true
	var detail := ""
	var nb := 0
	for cle in EMPREINTES:
		var nom: String = cle.split("/")[0]
		var graine := int(cle.split("/")[1])
		var p := Flux.sans_equipement(_profil_de_l_empreinte(nom))
		var r: Dictionary = await Flux.rejouer(self, p, graine)
		nb += 1
		if String(r["digest"]) != String(EMPREINTES[cle]):
			tout = false
			detail += " %s (%s)" % [cle, r["digest"]]
	_check("les %d flux de commandes (840 pas chacun : déplacement, visée, gâchette, recharge, torche, fusée, gadget, posture) égalent ceux du code de S4" % nb,
		tout, detail)
	# Un profil équipé, lui, change — la preuve que l'empreinte voit bien les nouvelles commandes.
	var equipe := Flux.sans_equipement(Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL))
	equipe.torche_tactique = true
	equipe.torche_rayon_fouille_px = 600.0
	var r2: Dictionary = await Flux.rejouer(self, equipe, 7)
	_check("… et un profil à torche tactique n'a PAS la même empreinte (celle-ci voit la commande de torche)", String(r2["digest"]) != String(EMPREINTES["normal/7"]))


# ---------------------------------------------------------------------------
# La torche, en marche
# ---------------------------------------------------------------------------

func _la_torche_en_marche() -> void:
	print("\n[La torche, en marche : éteinte, puis allumée à portée de fouiller, puis éteinte quand rien ne reste]")
	var p := _profil({"torche_tactique": true, "torche_rayon_fouille_px": 300.0}, false)
	var r := _rig(p, "", c(6, 15), c(34, 25), 5)
	await _derouler(r, 30)
	_check("avant tout bruit : la torche est éteinte (le bot prudent ne se trahit pas pour rien)", not r.tireur.flashlight.enabled and not r.bot.is_flashlight_pressed())
	_son("footstep", c(20, 15))
	var allumee_loin := [false]
	var d_a_l_allumage := [-1.0]
	var allumee_en_enquete := [false]
	for _i in 600:
		await physics_frame
		r.suivre()
		if r.bot.etat == Bot.Etat.ENQUETE and r.bot.perception.memoire.connue(r.bot.perception.maintenant()):
			var d := r.tireur.global_position.distance_to(r.bot.perception.memoire.position)
			if r.tireur.flashlight.enabled:
				allumee_en_enquete[0] = true
				if d_a_l_allumage[0] < 0.0:
					d_a_l_allumage[0] = d
				if d > p.torche_rayon_fouille_px + Equip.HYSTERESIS_TORCHE_PX + 8.0:
					allumee_loin[0] = true
	_check("en enquête, la torche ne brûle JAMAIS au-delà de la limite de fouille (300 px + 60 d'hystérésis) : il s'approche dans le noir", not allumee_loin[0])
	_check("… elle s'allume pourtant, à %.0f px de la zone qu'il fouille" % d_a_l_allumage[0], allumee_en_enquete[0] and d_a_l_allumage[0] <= p.torche_rayon_fouille_px + 8.0)
	await _derouler(r, 600)
	_check("la mémoire s'efface (retour en patrouille) et la torche s'éteint avec elle", r.bot.etat == Bot.Etat.PATROUILLE and not r.tireur.flashlight.enabled,
		"état %d, torche %s" % [r.bot.etat, str(r.tireur.flashlight.enabled)])
	r.liberer()
	# La torche FIXE d'avant S9 : inchangée.
	var allume := _rig(_profil({"torche_allumee": true}), "", c(6, 15), c(34, 25), 5)
	await _derouler(allume, 30)
	_check("un profil à torche fixe allumée garde sa torche allumée en patrouille (le bot de S4)", allume.tireur.flashlight.enabled and allume.bot.is_flashlight_pressed())
	allume.liberer()
	var eteint := _rig(_profil({"torche_allumee": false}), "", c(6, 15), c(34, 25), 5)
	await _derouler(eteint, 30)
	_son("footstep", c(12, 15))
	await _derouler(eteint, 200)
	_check("… et à torche fixe éteinte, il ne l'allume jamais, même en enquête", not eteint.tireur.flashlight.enabled and eteint.bot.etat == Bot.Etat.ENQUETE)
	eteint.liberer()


# ---------------------------------------------------------------------------
# La posture, en marche
# ---------------------------------------------------------------------------

func _la_posture_en_marche() -> void:
	print("\n[La posture, en marche : accroupi pour approcher un son, au quart de la vitesse]")
	var p := _profil({"accroupi_pres_du_son_px": 450.0}, false)
	var r := _rig(p, "", c(6, 15), c(34, 25), 5)
	await _derouler(r, 30)
	_check("avant tout bruit : debout", not r.tireur.accroupi)
	_son("footstep", c(20, 15))
	var debout_trop_pres := [false]
	var accroupi_trop_loin := [false]
	var accroupi_vu := [false]
	var positions: Array[Vector2] = []
	var images_en_enquete := 0
	for _i in 360:
		await physics_frame
		r.suivre()
		var mem: MemoireBot = r.bot.perception.memoire
		images_en_enquete = images_en_enquete + 1 if r.bot.etat == Bot.Etat.ENQUETE else 0
		# Les trois premières images d'une enquête sont laissées : la commande suit l'état d'un pas, le corps d'un pas de plus.
		if images_en_enquete > 3 and mem.connue(r.bot.perception.maintenant()):
			var d := r.tireur.global_position.distance_to(mem.position)
			if r.tireur.accroupi:
				accroupi_vu[0] = true
				positions.append(r.tireur.global_position)
				if d > p.accroupi_pres_du_son_px + Equip.HYSTERESIS_ACCROUPI_PX + 8.0:
					accroupi_trop_loin[0] = true
			elif d < p.accroupi_pres_du_son_px - 8.0:
				debout_trop_pres[0] = true
	_check("il s'accroupit en enquête, à portée du son", accroupi_vu[0])
	_check("… jamais au-delà de 450 px (+ 40 d'hystérésis) de la zone", not accroupi_trop_loin[0])
	_check("… et jamais debout à moins de 450 px de la zone qu'il approche", not debout_trop_pres[0])
	var vitesse := 0.0
	if positions.size() > 70:
		vitesse = positions[10].distance_to(positions[70]) / (60.0 * PAS)
	_check("accroupi, il avance au quart de sa vitesse : %.0f px/s pour 0,7 × 260 × 0,25 = 45" % vitesse, vitesse > 30.0 and vitesse < 60.0)
	_check("… et son anti-blocage, informé du facteur, n'a pas crié au blocage (%d)" % r.bot.blocages_total, r.bot.blocages_total == 0)
	await _derouler(r, 700)
	_check("la mémoire effacée, il se relève", r.bot.etat == Bot.Etat.PATROUILLE and not r.tireur.accroupi)
	r.liberer()
	var sans := _rig(_profil({}, false), "", c(6, 15), c(34, 25), 5)
	await _derouler(sans, 30)
	_son("footstep", c(20, 15))
	var jamais := [true]
	for _i in 360:
		await physics_frame
		if sans.tireur.accroupi:
			jamais[0] = false
	_check("un profil sans `accroupi_pres_du_son_px` ne s'accroupit jamais (le bot de S4)", jamais[0])
	sans.liberer()


# ---------------------------------------------------------------------------
# Le repli, en marche
# ---------------------------------------------------------------------------

func _le_repli_en_marche() -> void:
	print("\n[Le repli : après une rafale, il change de place et ne tire pas pendant ce temps]")
	var p := _profil({"repli_apres_tir_s": 1.0}, false)
	var r := _rig(p, "", c(8, 15), c(14, 15), 6)
	await _derouler(r, 6)
	r.cible.allumer_la_torche(Vector2.LEFT)
	var t_repli := [-1.0]
	var pos_depart := [Vector2.ZERO]
	var deplacement_max := [0.0]
	for _i in 600:
		await physics_frame
		r.suivre()
		if t_repli[0] < 0.0 and r.bot.replis >= 1:
			t_repli[0] = r.tireur.t
			pos_depart[0] = r.tireur.global_position
		if t_repli[0] >= 0.0 and r.tireur.t - t_repli[0] <= 1.0:
			deplacement_max[0] = maxf(deplacement_max[0], r.tireur.global_position.distance_to(pos_depart[0]))
	var tirs_dans_le_repli := 0
	var tirs_apres := 0
	for tir in r.tireur.tirs:
		var dt: float = float(tir["t"]) - t_repli[0]
		if dt > 0.05 and dt < 1.0:
			tirs_dans_le_repli += 1
		elif dt >= 1.0:
			tirs_apres += 1
	_check("une rafale est suivie d'un repli (%d repli)" % r.bot.replis, r.bot.replis >= 1 and t_repli[0] > 0.0)
	_check("il change VRAIMENT de place : %.0f px parcourus dans la seconde qui suit" % deplacement_max[0], deplacement_max[0] > 70.0)
	_check("… et ne tire PAS pendant le repli (%d coup dans la seconde qui suit)" % tirs_dans_le_repli, tirs_dans_le_repli == 0)
	_check("… puis il reprend le combat : %d coups après le repli" % tirs_apres, tirs_apres >= 2)
	r.liberer()
	# Un bot IMMOBILE ne se replie pas : une statue ne change pas de place.
	var statue := _rig(_profil({"repli_apres_tir_s": 1.0}, true), "", c(8, 15), c(14, 15), 6)
	await _derouler(statue, 6)
	statue.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(statue, 360)
	_check("un bot immobile qui tire ne se replie jamais (%d tirs, %d replis, place inchangée)" % [statue.tireur.tirs.size(), statue.bot.replis],
		statue.tireur.tirs.size() >= 2 and statue.bot.replis == 0 and statue.tireur.global_position.distance_to(c(8, 15)) < 1.0)
	statue.liberer()
	# Sans `repli_apres_tir_s`, le bot tient sa place en combat, comme avant.
	var tient := _rig(_profil({}, false), "", c(8, 15), c(14, 15), 6)
	await _derouler(tient, 6)
	tient.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(tient, 120, func() -> bool: return tient.bot.etat == Bot.Etat.COMBAT)
	var place_au_combat := tient.tireur.global_position
	await _derouler(tient, 360)
	_check("sans prudence d'après tir, il tient sa place en combat (le bot de S4) : %d tirs, %d replis, %.1f px parcourus" % [
		tient.tireur.tirs.size(), tient.bot.replis, tient.tireur.global_position.distance_to(place_au_combat)],
		tient.tireur.tirs.size() >= 2 and tient.bot.replis == 0 and tient.tireur.global_position.distance_to(place_au_combat) < 2.0)
	tient.liberer()


# ---------------------------------------------------------------------------
# La fusée, en marche
# ---------------------------------------------------------------------------

func _la_fusee_en_marche() -> void:
	print("\n[La fusée : vers une zone entendue, pas vers une cible vue]")
	var p := _profil({"lance_des_fusees": true})
	var r := _rig(p, "", c(6, 15), c(34, 25), 5)
	await _derouler(r, 30)
	_son("footstep", c(16, 15))
	await _derouler(r, 120)
	var memoire: MemoireBot = r.bot.perception.memoire
	var cap_voulu := (memoire.position - r.tireur.global_position).angle()
	_check("une zone entendue à 350 px, en face, dégagée : une fusée part (%d)" % r.tireur.lancers.size(), r.tireur.lancers.size() == 1 and r.bot.fusees_lancees == 1)
	if r.tireur.lancers.size() > 0:
		var l: Dictionary = r.tireur.lancers[0]
		var ecart := absf(rad_to_deg(angle_difference(float(l["rotation"]), cap_voulu)))
		_check("… droit devant lui, vers la zone qu'il a ENTENDUE (écart %.1f° avec sa mémoire)" % ecart, ecart <= Equip.FUSEE_ANGLE_MAX_DEG + 1.0)
	_check("… une seule : la réserve est vide (%d)" % r.jeu.fusees, r.jeu.fusees == 0)
	_son("footstep", c(16, 15))
	await _derouler(r, 200)
	_check("un deuxième bruit ne lui en fait pas lancer une deuxième : le bot lit sa réserve", r.tireur.lancers.size() == 1)
	r.liberer()
	# Une cible VUE : aucune fusée, à la même distance.
	var vu := _rig(p, "", c(6, 15), c(16, 15), 5)
	await _derouler(vu, 6)
	vu.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(vu, 420)
	_check("une cible VUE (sa torche allumée, à 350 px, en face) : aucune fusée en 7 s (état %d, %d vues)" % [vu.bot.etat, vu.bot.perception.pas_vus],
		vu.tireur.lancers.is_empty() and vu.bot.perception.pas_vus > 0 and vu.jeu.fusees == 1)
	vu.liberer()
	var refus := {
		"trop près (150 px)": [c(10, 15), c(6, 15)],
		"trop loin (700 px)": [c(26, 5), c(6, 5)],
		"un mur entre lui et la zone": [c(30, 15), c(22, 15)],
	}
	for raison in refus:
		var s := _rig(p, "", refus[raison][1], c(34, 25), 5)
		await _derouler(s, 30)
		_son("footstep", refus[raison][0])
		await _derouler(s, 240)
		_check("zone entendue, mais %s : aucune fusée (état %d, %d sons entendus)" % [raison, s.bot.etat, s.bot.perception.sons_entendus],
			s.tireur.lancers.is_empty() and s.bot.perception.sons_entendus > 0 and s.bot.etat == Bot.Etat.ENQUETE)
		s.liberer()
	var sans_stock := _rig(p, "", c(6, 15), c(34, 25), 5)
	sans_stock.jeu.fusees = 0
	await _derouler(sans_stock, 30)
	_son("footstep", c(16, 15))
	await _derouler(sans_stock, 240)
	_check("sans fusée en réserve : aucune", sans_stock.tireur.lancers.is_empty() and sans_stock.bot.etat == Bot.Etat.ENQUETE)
	sans_stock.liberer()
	var sans_profil := _rig(_profil({}), "", c(6, 15), c(34, 25), 5)
	await _derouler(sans_profil, 30)
	_son("footstep", c(16, 15))
	await _derouler(sans_profil, 240)
	_check("un profil qui ne lance pas de fusée n'en lance pas, réserve pleine (le bot de S4)", sans_profil.tireur.lancers.is_empty() and sans_profil.jeu.fusees == 1)
	sans_profil.liberer()


# ---------------------------------------------------------------------------
# Les dix gadgets, sur des corps factices
# ---------------------------------------------------------------------------

## La mise en scène « adaptée » de chaque gadget : ce que le bot doit percevoir pour que sa règle le pose.
##   • `entendu`   — un pas entendu à 9 cases en face ; la cible, elle, est loin et dans le noir ;
##   • `vu`        — la cible, à 9 cases en face, allume sa torche vers le bot : il la VOIT (sa lampe) ;
##   • `vu_touche` — comme `vu`, et le bot vient d'être touché.
const MISES_EN_SCENE := {
	"gresillement": "vu", "leurre": "vu", "poussiere": "entendu", "torche_fantome": "entendu", "cartouche_suie": "vu_touche",
	"nappe_braises": "vu", "poudre_contact": "entendu", "ombre_habitee": "vu", "mine_magnesium": "entendu", "voile": "vu",
}


## Joue la mise en scène de `slug` jusqu'à ce que le bot ait posé (ou 8 s). Rend le `Rig`, vivant : l'appelant le libère.
func _poser_la_scene(slug: String, changements: Dictionary = {}, immobile: bool = true, graine: int = 5, mode: String = "", son: Vector2 = Vector2(542.5, 542.5)) -> Rig:
	if mode == "":
		mode = String(MISES_EN_SCENE[slug])
	var p := _profil({"utilise_le_gadget": true}, immobile)
	for k in changements:
		p.set(k, changements[k])
	var cible_loin := c(34, 25)
	var r := _rig(p, slug, c(6, 15), cible_loin if mode == "entendu" else c(15, 15), graine)
	await _derouler(r, 6)
	if mode == "entendu":
		await _derouler(r, 24)
		_son("footstep", son)
	else:
		r.cible.allumer_la_torche(Vector2.LEFT)
	var touche := [false]
	for i in 480:
		await physics_frame
		r.suivre()
		if mode == "vu_touche" and not touche[0] and r.bot.etat == Bot.Etat.COMBAT:
			touche[0] = true
			r.tireur.hp = 85.0
		if r.bot.gadgets_poses >= 1:
			break
	return r


func _les_dix_gadgets_sur_des_corps_factices() -> void:
	print("\n[Les dix gadgets, chacun posé au moins une fois dans la mise en scène de sa règle (corps factices, le vrai fournisseur)]")
	for slug in Equip.GADGETS:
		var r := await _poser_la_scene(slug)
		var pose: Dictionary = r.tireur.poses[0] if r.tireur.poses.size() > 0 else {}
		_check("« %s » (%s) : posé, une fois, par la touche du gadget (%d pose, état %d)" % [slug, MISES_EN_SCENE[slug], r.tireur.poses.size(), r.bot.etat],
			r.tireur.poses.size() == 1 and String(pose.get("slug", "")) == slug and r.bot.gadgets_poses == 1 and int(r.bot.poses_par_gadget.get(slug, 0)) == 1)
		if not pose.is_empty():
			var vers := (r.bot.perception.memoire.position - (pose["pos"] as Vector2)).angle()
			var ecart := absf(rad_to_deg(angle_difference(float(pose["rotation"]), vers)))
			_check("« %s » : posé FACE à la place qu'il vise (%.0f° d'écart avec sa mémoire, 25° permis) — le gadget se plante 96 px devant" % [slug, ecart],
				ecart <= Equip.ANGLE_POSE_DEG + 3.0)
		await _derouler(r, 300)
		_check("« %s » : une seule pose en 5 s de plus — la recharge d'une minute est celle du jeu, et le bot la lit" % slug, r.tireur.poses.size() == 1)
		r.liberer()
	# Les refus : sans le profil, sans réserve, sans gadget de classe — dans la mise en scène même qui fait poser.
	for slug in ["leurre", "poussiere", "voile"]:
		var sans_profil := await _poser_la_scene(slug, {"utilise_le_gadget": false})
		await _derouler(sans_profil, 120)
		_check("« %s » : un profil qui n'utilise pas son gadget ne pose rien (le bot de S4)" % slug, sans_profil.tireur.poses.is_empty())
		sans_profil.liberer()
		var prise := _rig(_profil({"utilise_le_gadget": true}), slug, c(6, 15), c(34, 25), 5)
		prise.jeu.gadget_libre = false
		await _derouler(prise, 30)
		_son("footstep", c(15, 15))
		prise.cible.allumer_la_torche(Vector2.LEFT)
		await _derouler(prise, 400)
		_check("« %s » : gadget pas rechargé (la minute n'est pas écoulée) : aucune pose" % slug, prise.tireur.poses.is_empty())
		prise.liberer()
	var sans_classe := _rig(_profil({"utilise_le_gadget": true}), "", c(6, 15), c(15, 15), 5)
	await _derouler(sans_classe, 6)
	sans_classe.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(sans_classe, 400)
	_check("une arme sans gadget de classe : le bot ne pose rien, même en combat sur une cible vue", sans_classe.tireur.poses.is_empty() and sans_classe.bot.etat == Bot.Etat.COMBAT)
	sans_classe.liberer()
	# Les règles ne se déclenchent QUE dans leur mise en scène : la poussière sur une cible vue, le voile sans torche vue.
	var poussiere_vue := await _poser_la_scene("poussiere", {}, true, 5, "vu")
	await _derouler(poussiere_vue, 240)
	_check("la poussière, face à une cible VUE (combat) : jamais posée — le nuage boucherait aussi sa vue", poussiere_vue.tireur.poses.is_empty())
	poussiere_vue.liberer()
	var voile_entendu := await _poser_la_scene("voile", {}, true, 5, "entendu")
	await _derouler(voile_entendu, 240)
	_check("le voile, devant un son seulement (aucune torche vue) : jamais posé", voile_entendu.tireur.poses.is_empty())
	voile_entendu.liberer()
	var suie_sans_coup := await _poser_la_scene("cartouche_suie", {}, true, 5, "vu")
	await _derouler(suie_sans_coup, 240)
	_check("la suie, sans coup reçu : jamais posée (elle est faite pour disparaître)", suie_sans_coup.tireur.poses.is_empty())
	suie_sans_coup.liberer()


# ---------------------------------------------------------------------------
# La bobine, et ce que le bot fait après avoir posé
# ---------------------------------------------------------------------------

func _la_bobine_et_le_puis() -> void:
	print("\n[La bobine s'allume et s'éteint ; la mine le fait reculer ; la suie le fait entrer dans son nuage]")
	var r := await _poser_la_scene("gresillement")
	_check("le Parasite pose sa bobine", r.tireur.poses.size() == 1 and r.jeu.bobine != null)
	await _derouler(r, 150)
	_check("la torche de la cible est vue à portée : la même touche ALLUME la bobine (%d bascule, actif : %s)" % [r.tireur.bascules.size(),
		str(r.jeu.bobine.actif if r.jeu.bobine != null else false)], r.tireur.bascules.size() >= 1 and r.jeu.bobine != null and r.jeu.bobine.actif)
	r.cible.eteindre_la_torche()
	r.cible.global_position = c(34, 25)
	await _derouler(r, 900)
	_check("la cible disparue (état %d), elle est ÉTEINTE : on ne brûle pas la batterie pour rien (%d bascules)" % [r.bot.etat, r.tireur.bascules.size()],
		r.jeu.bobine != null and not r.jeu.bobine.actif and r.tireur.bascules.size() >= 2)
	r.liberer()
	# La mine : il pose, puis il RECULE (le flash aveugle à 460 px, poseur compris).
	# Un bot qui MARCHE vers la zone la traverse vite : le son vient de plus loin (385 px) que pour un bot immobile, pour que la fenêtre de la mine tienne.
	var son_pos := c(17, 15)
	var mine := await _poser_la_scene("mine_magnesium", {}, false, 5, "", son_pos)
	_check("la mine est posée (mobile : %d pose)" % mine.tireur.poses.size(), mine.tireur.poses.size() == 1)
	var pose_pos: Vector2 = (mine.tireur.poses[0]["pos"] as Vector2) if mine.tireur.poses.size() > 0 else Vector2.ZERO
	await _derouler(mine, 160)
	var recul := pose_pos.distance_to(son_pos) < mine.tireur.global_position.distance_to(son_pos)
	_check("… et il RECULE : %d repli, de %.0f px à %.0f px de la zone entendue" % [mine.bot.replis, pose_pos.distance_to(son_pos),
		mine.tireur.global_position.distance_to(son_pos)], mine.bot.replis >= 1 and recul and mine.tireur.global_position.distance_to(pose_pos) > 100.0)
	mine.liberer()
	# La suie : il pose, puis il entre dans son nuage (96 px devant lui) et y reste.
	var suie := await _poser_la_scene("cartouche_suie", {}, false)
	_check("la suie est posée (mobile : %d pose)" % suie.tireur.poses.size(), suie.tireur.poses.size() == 1)
	if suie.tireur.poses.size() > 0:
		var pose: Dictionary = suie.tireur.poses[0]
		var centre: Vector2 = (pose["pos"] as Vector2) + Vector2.from_angle(float(pose["rotation"])) * 96.0
		var d_min := [INF]
		for _i in 150:
			await physics_frame
			suie.suivre()
			d_min[0] = minf(d_min[0], suie.tireur.global_position.distance_to(centre))
		_check("… et il entre dans le nuage : il s'en est approché à %.0f px de son centre (%d repli)" % [d_min[0], suie.bot.replis],
			suie.bot.replis >= 1 and d_min[0] < 30.0)
	suie.liberer()


# ---------------------------------------------------------------------------
# L'honnêteté de l'équipement
# ---------------------------------------------------------------------------

func _l_honnetete_de_l_equipement() -> void:
	print("\n[L'honnêteté : équipé de tout, le bot n'use d'aucun outil sur ce qu'il ne perçoit pas]")
	var tout := {"utilise_le_gadget": true, "lance_des_fusees": true, "torche_tactique": true, "torche_rayon_fouille_px": 600.0, "repli_apres_tir_s": 1.0,
		"accroupi_pres_du_son_px": 600.0}
	var mauvais := ""
	for slug in Equip.GADGETS:
		# Un joueur immobile dans le noir, à 9 cases, en face : silencieux, sans torche.
		var noir := _rig(_profil(tout, true), slug, c(6, 15), c(15, 15), 9)
		await _derouler(noir, 480)
		if not (noir.tireur.poses.is_empty() and noir.tireur.lancers.is_empty() and not noir.tireur.flashlight.enabled and not noir.tireur.accroupi
				and noir.bot.replis == 0 and noir.bot.etat == Bot.Etat.PATROUILLE and noir.bot.perception.pas_vus == 0 and noir.bot.fusees_lancees == 0):
			mauvais += " %s(noir)" % slug
		noir.liberer()
		# Sa torche allumée DERRIÈRE la paroi pleine (colonne 26) : le modèle ne la voit pas, le bot n'en sait rien.
		var mur := _rig(_profil(tout, true), slug, c(20, 15), c(32, 15), 9)
		await _derouler(mur, 6)
		mur.cible.allumer_la_torche(Vector2.LEFT)
		await _derouler(mur, 480)
		if not (mur.tireur.poses.is_empty() and mur.tireur.lancers.is_empty() and not mur.tireur.flashlight.enabled and not mur.tireur.accroupi
				and mur.bot.replis == 0 and mur.bot.etat == Bot.Etat.PATROUILLE and mur.bot.perception.pas_vus == 0):
			mauvais += " %s(mur)" % slug
		mur.liberer()
	_check("dix classes équipées de tout, devant un joueur dans le noir puis derrière une paroi : ni pose, ni fusée, ni torche, ni accroupi, ni repli, en 8 s chacun", mauvais == "", mauvais)
	# Un bot qui MARCHE (une ZONE à l'ouest) et dont la cible reste dans le noir à l'autre bout : aucun outil non plus.
	var en_zone := _profil(tout, false)
	en_zone.deplacement = Profil.Deplacement.ZONE
	en_zone.zone = Rect2i(1, 1, 18, 12)
	var libre := _rig(en_zone, "voile", c(5, 5), c(36, 26), 21)
	var excursion := [0.0]
	for _i in 900:
		await physics_frame
		libre.suivre()
		excursion[0] = maxf(excursion[0], libre.tireur.global_position.distance_to(c(5, 5)))
	_check("un bot équipé qui patrouille, la cible dans le noir à l'autre bout : aucun outil (il a marché %.0f px)" % excursion[0],
		libre.tireur.poses.is_empty() and libre.tireur.lancers.is_empty() and not libre.tireur.flashlight.enabled and libre.bot.replis == 0
		and libre.bot.perception.pas_vus == 0 and excursion[0] > 150.0)
	libre.liberer()
	# Un son ENTENDU est une information légitime : la même équipe, devant un pas, s'en sert (la fusée part).
	var entend := _rig(_profil(tout, true), "mine_magnesium", c(6, 15), c(34, 25), 9)
	await _derouler(entend, 30)
	_son("footstep", c(16, 15))
	await _derouler(entend, 240)
	_check("… mais devant un pas ENTENDU, la même équipe s'en sert : fusée lancée, mine posée, accroupi (%d fusée, %d pose)" % [entend.tireur.lancers.size(), entend.tireur.poses.size()],
		entend.tireur.lancers.size() == 1 and entend.tireur.poses.size() == 1)
	entend.liberer()


# ---------------------------------------------------------------------------
# Le jeu monté
# ---------------------------------------------------------------------------

## La CARTE du jeu monté : celle de la perception (S2), 48 × 40, une paroi pleine en colonne 30 (lignes 14 à 27).
const CARTE_JEU := "res://tools/cartes/perception_essai.json"

## Un « joueur » qui n'appuie sur rien d'autre que ce que le test décide : sa torche, sa marche (un va-et-vient, dont les PAS s'entendent —
## le signal de son du jeu les annonce comme ceux de n'importe qui), sa visée.
class Poupee extends InputProvider:
	var torche := false
	var visee := Vector2.RIGHT
	var marche := Vector2.ZERO
	## Un va-et-vient de `periode` secondes : la poupée marche d'un côté puis de l'autre, et reste donc à la même distance du bot, à peu près.
	var va_et_vient := Vector2.ZERO
	var periode := 0.6
	var _t := 0.0

	func _physics_process(delta: float) -> void:
		_t += delta

	func get_movement_vector() -> Vector2:
		if va_et_vient != Vector2.ZERO:
			return va_et_vient if int(floor(_t / periode)) % 2 == 0 else -va_et_vient
		return marche

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_flashlight_pressed() -> bool:
		return torche


func _le_jeu_monte() -> void:
	print("\n=== LE JEU MONTÉ : le vrai joueur, le vrai GameState, les vrais gadgets et la vraie fusée ===")
	var reglages := root.get_node("GameSettings")
	var cartes := root.get_node("MapData")
	# La vue de dessus : la simulation (corps, balles, sons, lumière, gadgets) est la même, et elle va deux fois plus vite (voir `banc_bot_duel.gd`).
	reglages.mode_iso = false
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	main._on_main_menu_requested()
	await _images(2)
	var ui: Node = main.ui
	cartes.select_map(cartes.DEFAULT_MAP_ID)
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	ui._on_hub_action("cran_tireur")
	main.graine_du_bot = 99
	ui._on_hub_action("entrainement")
	await _images(3)
	await _poser_la_carte_du_jeu(main)
	var poupee := Poupee.new()
	poupee.name = "PoupeeEquipement"
	main._set_player_input_provider(main.p1, poupee)

	# --- Le profil du cran 3 : chaque difficulté porte ses outils, lus de l'écran
	print("\n--- Le cran 3 monte le bot avec les outils de sa difficulté ---")
	for d in [Profil.Difficulte.FACILE, Profil.Difficulte.NORMAL, Profil.Difficulte.DIFFICILE]:
		var attendu := Profil.pour_adversaire_qui_tire(d)
		await _poser_la_scene_reelle(main, poupee, attendu, 0, c(20, 20), c(29, 20))
		var bot: BotInputProvider = main.p2.input_provider as BotInputProvider
		_check("(difficulté %d) le bot porte les outils du profil de la difficulté (%d outils)" % [d, _nombre_d_outils(attendu)],
			bot != null and bot.profil.est_equipe() == attendu.est_equipe() and bot.profil.torche_tactique == attendu.torche_tactique
			and bot.profil.utilise_le_gadget == attendu.utilise_le_gadget and bot.profil.lance_des_fusees == attendu.lance_des_fusees
			and is_equal_approx(bot.profil.repli_apres_tir_s, attendu.repli_apres_tir_s))

	# --- Les dix gadgets, posés par le vrai joueur, dans la vraie arène
	print("\n--- Les dix classes : chaque gadget naît dans l'arène, posé par le bot, devant lui ---")
	for i in 10:
		var classe: Object = main.weapon_for_index(i)
		var slug: String = classe.gadget.slug
		var mode := String(MISES_EN_SCENE[slug])
		var p := Flux.sans_equipement(Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL))
		p.deplacement = Profil.Deplacement.IMMOBILE
		p.utilise_le_gadget = true
		await _poser_la_scene_reelle(main, poupee, p, i, c(20, 20), c(29, 20))
		var bot: BotInputProvider = main.p2.input_provider as BotInputProvider
		if mode == "entendu":
			poupee.torche = false
			poupee.va_et_vient = Vector2.UP
			poupee.periode = 0.5
		else:
			poupee.va_et_vient = Vector2.ZERO
			poupee.torche = true
			poupee.visee = Vector2.LEFT
		var pose: Node = null
		var touche := false
		for _i in 720:
			await process_frame
			main.p1.hp = 100.0
			main.p1.dead = false
			if mode == "vu_touche" and not touche and bot.etat == Bot.Etat.COMBAT:
				touche = true
				main.p2.take_damage(10.0, main.p1)
			pose = _gadget_de(main, 1)
			if pose != null:
				break
		_check("(%s, classe %d, %s) le gadget naît dans l'arène : posé par le bot (joueur 2), par `GameState`, sous le bon nom" % [slug, i, mode],
			pose != null and String(pose.get("slug")) == slug and int(pose.get("poseur_id")) == 1,
			"bot : %d poses, état %d ; gadget trouvé : %s" % [bot.gadgets_poses, bot.etat, "aucun" if pose == null else "%s (slug « %s », poseur %s)" % [pose.name, str(pose.get("slug")), str(pose.get("poseur_id"))]])
		if pose != null:
			var devant: float = (pose as Node2D).global_position.distance_to(main.p2.global_position)
			var vers_j1: Vector2 = (main.p1.global_position - main.p2.global_position).normalized()
			var dec: Vector2 = ((pose as Node2D).global_position - main.p2.global_position).normalized()
			_check("(%s) … à %.0f px du bot, du côté où il visait (%.0f° d'écart avec la place de J1 — le test, lui, a le droit de la connaître)" % [
				slug, devant, rad_to_deg(vers_j1.angle_to(dec))], devant > 60.0 and devant < 130.0 and absf(rad_to_deg(vers_j1.angle_to(dec))) < 40.0)
			var attente: float = float(main.attente_gadget(1))
			_check("(%s) … la recharge d'une minute est armée (%.0f s)" % [slug, attente], attente > 55.0)
		if pose != null:
			await _images(8)
			_la_perception_sous_ce_gadget(slug, bot, pose, main)
		await _images(112)
		var nb := 0
		for g in get_nodes_in_group("gadgets"):
			if is_instance_valid(g) and int(g.get("poseur_id")) == 1:
				nb += 1
		_check("(%s) … et il n'en pose qu'un : %d de plus en deux secondes" % [slug, nb], nb <= 1)

	# --- La fusée : le vrai joueur la lance, la vraie fusée naît, vers une zone entendue
	print("\n--- La fusée, dans le vrai jeu ---")
	var p_fusee := Flux.sans_equipement(Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL))
	p_fusee.deplacement = Profil.Deplacement.IMMOBILE
	p_fusee.lance_des_fusees = true
	await _poser_la_scene_reelle(main, poupee, p_fusee, 0, c(20, 20), c(29, 20))
	var bot_f: BotInputProvider = main.p2.input_provider as BotInputProvider
	poupee.va_et_vient = Vector2.UP
	poupee.periode = 0.5
	var fusee: Node = null
	for _i in 480:
		await process_frame
		main.p1.hp = 100.0
		main.p1.dead = false
		fusee = _fusee_de(1)
		if fusee != null:
			break
	_check("un pas ENTENDU à ~330 px : le bot lance une fusée, le vrai joueur la lance, la vraie fusée naît (tireur : joueur 2)",
		fusee != null and int(fusee.get("shooter_id")) == 1, "%d fusées lancées par le bot, état %d" % [bot_f.fusees_lancees, bot_f.etat])
	if fusee != null:
		var vers_zone: Vector2 = (main.p1.global_position - main.p2.global_position).normalized()
		var cap: Vector2 = Vector2.from_angle(main.p2.rotation)
		_check("… droit devant lui, vers le son (%.0f° d'écart avec la place de J1)" % rad_to_deg(vers_zone.angle_to(cap)), absf(rad_to_deg(vers_zone.angle_to(cap))) < 25.0)
	await _images(240)
	_check("… et une seule : sa réserve (1 pour le Parasite) est vide, le bot la lit (%d fusée en vol ou posée)" % get_nodes_in_group("fusees").filter(
		func(f: Node) -> bool: return is_instance_valid(f) and int(f.get("shooter_id")) == 1).size(),
		get_nodes_in_group("fusees").filter(func(f: Node) -> bool: return is_instance_valid(f) and int(f.get("shooter_id")) == 1).size() <= 1)

	# --- La torche et la posture : le vrai joueur les applique
	print("\n--- La torche tactique et l'accroupissement, dans le vrai jeu ---")
	var p_torche := Flux.sans_equipement(Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL))
	p_torche.deplacement = Profil.Deplacement.IMMOBILE
	p_torche.torche_tactique = true
	p_torche.torche_rayon_fouille_px = 250.0
	p_torche.accroupi_pres_du_son_px = 400.0
	await _poser_la_scene_reelle(main, poupee, p_torche, 0, c(20, 20), c(30, 20))
	var bot_t: BotInputProvider = main.p2.input_provider as BotInputProvider
	_check("avant tout bruit : torche éteinte, debout", not main.p2.flashlight_on and not main.p2.accroupi)
	poupee.va_et_vient = Vector2.UP
	poupee.periode = 0.5
	var accroupi_vu := false
	var torche_vue := false
	var torche_loin := false
	var memoire_avant := Vector2.INF
	for _i in 420:
		await process_frame
		main.p1.hp = 100.0
		main.p1.dead = false
		if bot_t.etat == Bot.Etat.ENQUETE and bot_t.perception.memoire.connue(bot_t.perception.maintenant()):
			var m: Vector2 = bot_t.perception.memoire.position
			var d: float = main.p2.global_position.distance_to(m)
			if main.p2.accroupi:
				accroupi_vu = true
			# Un nouveau son déplace la zone d'un coup ; la commande de torche la suit d'un pas : on ne juge pas l'image du saut.
			if main.p2.flashlight_on:
				torche_vue = true
				if d > 250.0 + Equip.HYSTERESIS_TORCHE_PX + 15.0 and m.is_equal_approx(memoire_avant):
					torche_loin = true
			memoire_avant = m
	_check("le son entendu à ~350 px (immobile, sur place) : le vrai joueur s'accroupit (posture réelle, `accroupi`)", accroupi_vu)
	_check("… et sa torche ne brûle jamais au-delà de la limite de fouille", not torche_loin)
	_check("… la torche s'allume pourtant : il fouille (le test ne la juge pas plus : sa lumière est celle d'un joueur, il se trahit comme lui)", torche_vue or not accroupi_vu)

	# --- Le repli : le vrai joueur change de place après sa rafale
	print("\n--- Le repli après un tir, dans le vrai jeu ---")
	var p_repli := Flux.sans_equipement(Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL))
	p_repli.deplacement = Profil.Deplacement.LIBRE
	p_repli.repli_apres_tir_s = 1.0
	await _poser_la_scene_reelle(main, poupee, p_repli, 0, c(20, 20), c(26, 20))
	var bot_r: BotInputProvider = main.p2.input_provider as BotInputProvider
	poupee.torche = true
	poupee.visee = Vector2.LEFT
	var depart_repli := Vector2.INF
	var parcouru := 0.0
	var t_repli := -1
	for i in 600:
		await process_frame
		main.p1.hp = 100.0
		main.p1.dead = false
		if t_repli < 0 and bot_r.replis >= 1:
			t_repli = i
			depart_repli = main.p2.global_position
		if t_repli >= 0 and i - t_repli <= 60:
			parcouru = maxf(parcouru, main.p2.global_position.distance_to(depart_repli))
	_check("une rafale réelle (%d coups) est suivie d'un repli, et le vrai corps change de place : %.0f px en une seconde" % [bot_r.coups_tires, parcouru],
		bot_r.replis >= 1 and parcouru > 60.0)

	# --- L'honnêteté, dans le vrai jeu
	print("\n--- L'honnêteté : le bot équipé de tout, devant un joueur dans le noir ---")
	var p_tout := Flux.sans_equipement(Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL))
	p_tout.deplacement = Profil.Deplacement.IMMOBILE
	p_tout.utilise_le_gadget = true
	p_tout.lance_des_fusees = true
	p_tout.torche_tactique = true
	p_tout.torche_rayon_fouille_px = 600.0
	p_tout.repli_apres_tir_s = 1.0
	p_tout.accroupi_pres_du_son_px = 600.0
	for i in [8, 9, 1, 3]:
		var slug: String = main.weapon_for_index(i).gadget.slug
		await _poser_la_scene_reelle(main, poupee, p_tout, i, c(20, 20), c(29, 20))
		var bot_h: BotInputProvider = main.p2.input_provider as BotInputProvider
		var torche := false
		var accroupi := false
		for _i in 420:
			await process_frame
			main.p1.hp = 100.0
			main.p1.dead = false
			torche = torche or main.p2.flashlight_on
			accroupi = accroupi or main.p2.accroupi
		_check("(%s) un joueur immobile et silencieux dans le noir, en ligne de vue : ni gadget, ni fusée, ni torche, ni accroupi en 7 s" % slug,
			_gadget_de(main, 1) == null and _fusee_de(1) == null and not torche and not accroupi and bot_h.replis == 0 and bot_h.perception.pas_vus == 0,
			"%d poses, %d fusées, torche %s" % [bot_h.gadgets_poses, bot_h.fusees_lancees, str(torche)])
		poupee.torche = true
		poupee.visee = Vector2.LEFT
		await _poser_la_scene_reelle(main, poupee, p_tout, i, c(26, 20), c(36, 20))
		bot_h = main.p2.input_provider as BotInputProvider
		poupee.torche = true
		poupee.visee = Vector2.LEFT
		for _i in 420:
			await process_frame
			main.p1.hp = 100.0
			main.p1.dead = false
			torche = torche or main.p2.flashlight_on
		_check("(%s) sa torche allumée DERRIÈRE la paroi pleine : le bot n'en sait rien — ni gadget, ni fusée, ni torche" % slug,
			_gadget_de(main, 1) == null and _fusee_de(1) == null and not main.p2.flashlight_on and bot_h.perception.pas_vus == 0)
		poupee.torche = false

	await _retirer_les_gadgets_et_fusees(main)
	poupee.va_et_vient = Vector2.ZERO
	poupee.torche = false
	main._on_main_menu_requested()
	await _images(2)
	cartes.select_map(cartes.DEFAULT_MAP_ID)
	main.queue_free()
	await _images(3)


## Ce que le nœud de perception du bot retient du gadget qu'il vient de poser, dans le vrai jeu (voir `PerceptionBotNoeud._lire_les_gadgets`).
const PERCEPTION_SOUS_GADGET := {
	"gresillement": "innocent", "mine_magnesium": "innocent", "nappe_braises": "innocent", "poudre_contact": "innocent",
	"voile": "obstacle", "ombre_habitee": "obstacle", "leurre": "obstacle", "torche_fantome": "obstacle",
	"cartouche_suie": "volume", "poussiere": "volume",
}


func _la_perception_sous_ce_gadget(slug: String, bot: BotInputProvider, pose: Node, main: Node) -> void:
	var monde: Dictionary = bot.perception.monde
	var obstacles: Array = monde.get("obstacles", [])
	match String(PERCEPTION_SOUS_GADGET[slug]):
		"innocent":
			_check("(%s) le gadget ne bouche rien : le bot n'est pas aveugle, aucun obstacle (la mine, les braises, la poudre, la bobine ne coupent pas la lumière)" % slug,
				not bool(monde["aveugle"]) and obstacles.is_empty())
		"volume":
			_check("(%s) un nuage : le bot est aveugle par la lumière tant qu'il tient (le modèle ne sait pas le rendre)" % slug, bool(monde["aveugle"]))
		"obstacle":
			_check("(%s) un occluder : le bot n'est PAS aveugle, son ombre est un obstacle (%d polygone) — il voit moins que la lumière, plus aveugle qu'elle" % [slug, obstacles.size()],
				not bool(monde["aveugle"]) and obstacles.size() >= 1)
			# Le polygone est celui du gadget, dans le monde : son centre est près de l'origine du gadget (l'étoile du leurre déborde un peu).
			var proche := false
			for poly in obstacles:
				var centre := Vector2.ZERO
				for pt in poly:
					centre += pt
				centre /= float((poly as PackedVector2Array).size())
				if centre.distance_to((pose as Node2D).global_position) < 30.0:
					proche = true
			_check("(%s) … et ce polygone est posé à la place du gadget (en coordonnées du monde)" % slug, proche)
			if slug == "voile" or slug == "ombre_habitee":
				_la_geometrie_contre_le_moteur(slug, main, monde)


## Le polygone d'ombre qui entre dans le modèle est-il celui que le MOTEUR prend pour le gadget ? Le voile et la plaque ont pour collision exactement
## la forme de leur ombre : un rayon de physique qui les rencontre doit être un segment que le modèle tient pour coupé (jamais un segment manqué),
## et un segment que le modèle coupe doit être un rayon que le moteur arrête — à un frôlement près.
func _la_geometrie_contre_le_moteur(slug: String, main: Node, monde: Dictionary) -> void:
	var espace: PhysicsDirectSpaceState2D = main.p1.get_world_2d().direct_space_state
	var geo := preload("res://map_geometry.gd")
	var polys: Array = monde["obstacles"]
	var centre := Vector2.ZERO
	var n := 0
	for pt in polys[0]:
		centre += pt
		n += 1
	centre /= float(maxi(n, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var manques := 0
	var en_trop := 0
	var coupes := 0
	for _i in 400:
		var a := centre + Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
		var b := centre + Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
		if Geometry2D.is_point_in_polygon(a, polys[0]) or Geometry2D.is_point_in_polygon(b, polys[0]):
			continue
		var q := PhysicsRayQueryParameters2D.create(a, b)
		q.collision_mask = geo.GADGET_LAYER | geo.GADGET_BLOQUANT_LAYER
		q.collide_with_areas = false
		var moteur := not espace.intersect_ray(q).is_empty()
		var modele := Percep.obstacle_sur(a, b, monde)
		coupes += 1 if modele else 0
		if moteur and not modele:
			manques += 1
		if modele and not moteur:
			# Un frôlement : le modèle prend un demi-pixel de marge, le moteur aucune.
			var d := INF
			var p: PackedVector2Array = polys[0]
			for i in p.size():
				var q1 := Geometry2D.get_closest_points_between_segments(a, b, p[i], p[(i + 1) % p.size()])
				d = minf(d, q1[0].distance_to(q1[1]))
			if d > 1.0:
				en_trop += 1
	_check("(%s) contre le MOTEUR : sur 400 segments (%d coupés par le modèle), le moteur n'en arrête aucun que le modèle laisse passer (%d), et le modèle n'en coupe aucun que le moteur laisse passer hors frôlement (%d)" % [
		slug, coupes, manques, en_trop], manques == 0 and en_trop == 0 and coupes > 20)


## Le gadget posé par le joueur `pid` (0 ou 1) dans l'arène, ou `null`.
func _gadget_de(_main: Node, pid: int) -> Node:
	for g in get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion() and int(g.get("poseur_id")) == pid:
			return g
	return null


## La fusée lancée par le joueur `pid` (0 ou 1), ou `null`.
func _fusee_de(pid: int) -> Node:
	for f in get_nodes_in_group("fusees"):
		if is_instance_valid(f) and not f.is_queued_for_deletion() and int(f.get("shooter_id")) == pid:
			return f
	return null


## Retire sur-le-champ les gadgets et les fusées de l'arène : un gadget d'une scène ne doit pas survivre dans la suivante.
func _retirer_les_gadgets_et_fusees(main: Node) -> void:
	for groupe in ["gadgets", "fusees"]:
		for g in get_nodes_in_group(groupe):
			if is_instance_valid(g) and g.get_parent() != null:
				g.get_parent().remove_child(g)
				g.free()
	# La recharge d'une minute et la réserve de fusées sont des états du jeu : on les rend, comme une manche neuve le ferait.
	for pid in 2:
		main._gadget_attente[pid] = 0.0
		main._gadgets_poses_par[pid] = 0
		main._fusees_restantes[pid] = main._stock_fusees(main.p1 if pid == 0 else main.p2)
	await _images(2)


## Pose la carte d'essai (la paroi pleine) sur l'entraînement en cours.
func _poser_la_carte_du_jeu(main: Node) -> void:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(CARTE_JEU))
	var valide: Dictionary = Codec.validate(json.data as Dictionary)
	root.get_node("MapData").current_map_data = valide["data"]
	main.rebuild_arena()
	await _images(5)


## Met en scène dans le vrai jeu : J1 (la poupée) en `pos_joueur`, le bot en `pos_bot` au `profil` donné — un bot NEUF — portant la classe
## `classe_idx`. Laisse de quoi à la physique et à la lumière de la scène d'avant pour mourir.
##
## ⚠️ **L'ORDRE compte** : la recharge d'une minute et la réserve de fusées sont rendues APRÈS la pose du bot neuf. Rendues avant, le bot de la
## scène d'avant — encore là, sa mémoire pleine d'une cible — reposait son gadget dans les images qui suivent, et la scène suivante
## trouvait « un gadget du poseur 2 » qui n'était pas celui de sa classe (relevé en écrivant cette garde : quatre scènes sur dix).
func _poser_la_scene_reelle(main: Node, poupee: Poupee, profil: ProfilBot, classe_idx: int, pos_bot: Vector2, pos_joueur: Vector2) -> void:
	poupee.torche = false
	poupee.va_et_vient = Vector2.ZERO
	poupee.marche = Vector2.ZERO
	await _images(45)
	main._poser_l_adversaire(profil)
	main.p2.equip_weapon(main.weapon_for_index(classe_idx))
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
	await _retirer_les_gadgets_et_fusees(main)
	await _images(10)


# ---------------------------------------------------------------------------
# La perception sous gadget : voir moins que la lumière, jamais plus
# ---------------------------------------------------------------------------

## Un gadget factice : ce que le nœud de perception lit d'un gadget posé (le groupe, `occulte_la_lumiere`, des enfants `LightOccluder2D`).
class FauxGadget extends Node2D:
	var occulte_la_lumiere := true
	var poseur_id := 1

	func _ready() -> void:
		add_to_group("gadgets")


## Un gadget factice à occluder : une bande de `demi` (x) × `epaisseur` (y) autour de son origine, dans son repère.
class FauxGadgetOccluder extends FauxGadget:
	var demi := Vector2(84.0, 6.5)

	func _ready() -> void:
		super._ready()
		var occ := LightOccluder2D.new()
		occ.name = "Occluder"
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-demi.x, -demi.y), Vector2(demi.x, -demi.y), Vector2(demi.x, demi.y), Vector2(-demi.x, demi.y)])
		poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
		occ.occluder = poly
		add_child(occ)


## Un gadget en volume : il porte une `opacite`, comme `GadgetVolume`.
class FauxVolume extends FauxGadget:
	var opacite := 0.5

	func _init() -> void:
		occulte_la_lumiere = false


func _la_perception_sous_gadget() -> void:
	print("\n[La perception sous gadget : des murs minces pour ceux qui ont un occluder, aveugle pour les nuages — jamais plus que la lumière]")
	var monde := Percep.monde_de_la_carte(Flux.carte())
	var bande: PackedVector2Array = PackedVector2Array([Vector2(-6.5, -84.0), Vector2(6.5, -84.0), Vector2(6.5, 84.0), Vector2(-6.5, 84.0)])
	for i in bande.size():
		bande[i] += c(10, 15)
	# --- La géométrie : un segment coupe un polygone, ou non
	_check("un segment qui TRAVERSE la bande la coupe ; un segment qui passe à côté, non",
		Percep.segment_coupe_polygone(c(6, 15), c(14, 15), bande) and not Percep.segment_coupe_polygone(c(6, 5), c(14, 5), bande))
	_check("un point de départ ou d'arrivée DANS le polygone coupe (du côté du noir)",
		Percep.segment_coupe_polygone(c(10, 15), c(14, 20), bande) and Percep.segment_coupe_polygone(c(4, 4), c(10, 15), bande))
	_check("un segment qui FRÔLE l'arête (à moins d'un demi-pixel) coupe encore ; à deux pixels, non",
		Percep.segment_coupe_polygone(c(10, 15) + Vector2(6.5 + 0.3, -300.0), c(10, 15) + Vector2(6.5 + 0.3, 300.0), bande)
		and not Percep.segment_coupe_polygone(c(10, 15) + Vector2(6.5 + 2.0, -300.0), c(10, 15) + Vector2(6.5 + 2.0, 300.0), bande))
	_check("un polygone dégénéré (moins de trois points) ne coupe rien",
		not Percep.segment_coupe_polygone(c(6, 15), c(14, 15), PackedVector2Array([c(10, 14), c(10, 16)])))
	# Jamais un segment manqué : 600 segments au hasard, contre un échantillonnage fin du polygone.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var manques := 0
	var en_trop := 0
	for _i in 600:
		var a := c(10, 15) + Vector2(rng.randf_range(-260.0, 260.0), rng.randf_range(-260.0, 260.0))
		var b := c(10, 15) + Vector2(rng.randf_range(-260.0, 260.0), rng.randf_range(-260.0, 260.0))
		var echantillon := false
		for k in 801:
			if Geometry2D.is_point_in_polygon(a.lerp(b, float(k) / 800.0), bande):
				echantillon = true
				break
		var coupe := Percep.segment_coupe_polygone(a, b, bande)
		if echantillon and not coupe:
			manques += 1
		# Une coupe que l'échantillon ne voit pas n'est tolérée que pour un segment très proche de la bande (le pas de l'échantillon).
		if coupe and not echantillon and Geometry2D.get_closest_point_to_segment(c(10, 15), a, b).distance_to(c(10, 15)) > 90.0:
			en_trop += 1
	_check("600 segments au hasard : AUCUN n'est manqué par la géométrie (%d), et aucune coupe n'est fantaisiste (%d)" % [manques, en_trop], manques == 0 and en_trop == 0)
	# --- Le modèle de vue : une lampe, la bande entre la lampe et l'œil
	var avec := monde.duplicate()
	avec["obstacles"] = [bande]
	var bot := {"position": c(6, 15), "visee": Vector2.RIGHT, "accroupi": false}
	var lampe := Percep.lumiere_lampe("lampe", c(15, 15), 24.0)
	var cible := {"position": c(15, 15), "accroupi": false}
	_check("sans obstacle, la lampe de la cible est vue (le témoin)", bool(Percep.voir(bot, cible, [lampe], monde)["vu"]))
	_check("la bande entre l'œil et la lampe : elle n'est plus vue (le modèle voit MOINS, jamais plus)", not bool(Percep.voir(bot, cible, [lampe], avec)["vu"]))
	var hors := monde.duplicate()
	hors["obstacles"] = [PackedVector2Array([c(10, 4), c(11, 4), c(11, 6), c(10, 6)])]
	_check("la même bande hors de la ligne : la lampe est vue", bool(Percep.voir(bot, cible, [lampe], hors)["vu"]))
	var eclair := Percep.lumiere_disque("eclair", c(15, 15), 100.0, 24.0)
	_check("un éclair qui éclaire la cible, la bande entre la lumière et le corps : pas vu — et sans la bande, vu",
		bool(Percep.voir(bot, cible, [eclair], monde)["vu"]) and not bool(Percep.voir(bot, cible, [eclair], avec)["vu"]))
	var eclair_derriere := Percep.lumiere_disque("eclair", c(18, 15), 120.0, 24.0)
	var bande2: PackedVector2Array = PackedVector2Array([Vector2(-6.5, -84.0), Vector2(6.5, -84.0), Vector2(6.5, 84.0), Vector2(-6.5, 84.0)])
	for i in bande2.size():
		bande2[i] += c(16, 15)
	var derriere := monde.duplicate()
	derriere["obstacles"] = [bande2]
	_check("une lumière DERRIÈRE la cible, la bande entre elle et le corps : la cible n'est pas éclairée de ce côté-là — pas vue",
		bool(Percep.voir(bot, cible, [eclair_derriere], monde)["vu"]) and not bool(Percep.voir(bot, cible, [eclair_derriere], derriere)["vu"]))
	_check("une carte seule n'a pas d'obstacle : `monde_de_la_carte` porte une liste vide", (monde["obstacles"] as Array).is_empty())

	# --- Le nœud : ce qu'il lit des gadgets posés
	var r := _rig(_profil({"utilise_le_gadget": false}), "", c(6, 15), c(15, 15), 5)
	await _derouler(r, 6)
	r.cible.allumer_la_torche(Vector2.LEFT)
	await _derouler(r, 12)
	var noeud: PerceptionBotNoeud = r.bot.perception
	_check("le témoin : la torche de la cible, à 9 cases en face, est vue par le nœud", bool(noeud.derniere_vue["vu"]) and not bool(noeud.monde["aveugle"]))
	var mine := FauxGadget.new()
	mine.occulte_la_lumiere = false
	r.scene.add_child(mine)
	await _derouler(r, 6)
	_check("un gadget qui ne bouche rien (la mine, la nappe de braises, la poudre, le grésillement) : le bot voit comme avant, sans obstacle",
		bool(noeud.derniere_vue["vu"]) and not bool(noeud.monde["aveugle"]) and (noeud.monde["obstacles"] as Array).is_empty())
	mine.free()
	var voile := FauxGadgetOccluder.new()
	voile.rotation = PI * 0.5
	r.scene.add_child(voile)
	voile.global_position = c(10, 15)
	await _derouler(r, 6)
	_check("un gadget à occluder (le voile) entre lui et la lampe : le bot n'est PAS aveugle, la bande est un obstacle, et il ne voit plus la lampe",
		not bool(noeud.monde["aveugle"]) and (noeud.monde["obstacles"] as Array).size() == 1 and not bool(noeud.derniere_vue["vu"]),
		"aveugle %s, %d obstacles, vu %s" % [str(noeud.monde["aveugle"]), (noeud.monde["obstacles"] as Array).size(), str(noeud.derniere_vue["vu"])])
	var poly: PackedVector2Array = (noeud.monde["obstacles"] as Array)[0] if (noeud.monde["obstacles"] as Array).size() > 0 else PackedVector2Array()
	var rect := Rect2(poly[0], Vector2.ZERO)
	for pt in poly:
		rect = rect.expand(pt)
	_check("… en coordonnées du MONDE : la bande tournée d'un quart de tour, centrée sur le gadget (%.0f × %.0f px, centre %s)" % [rect.size.x, rect.size.y,
		str(rect.get_center().round())], absf(rect.size.x - 13.0) < 0.5 and absf(rect.size.y - 168.0) < 0.5 and rect.get_center().distance_to(c(10, 15)) < 0.5)
	voile.global_position = c(10, 4)
	await _derouler(r, 6)
	_check("le voile poussé hors de la ligne : la lampe est revue", bool(noeud.derniere_vue["vu"]) and not bool(noeud.monde["aveugle"]))
	voile.free()
	var nuage := FauxVolume.new()
	r.scene.add_child(nuage)
	await _derouler(r, 6)
	_check("un gadget en VOLUME (suie, poussière) : le bot est aveugle par la lumière (il voit moins, jamais plus)",
		bool(noeud.monde["aveugle"]) and not bool(noeud.derniere_vue["vu"]))
	var avant: int = noeud.sons_entendus
	noeud._sur_un_son(Flux.evenement(root.get_node("AudioManager"), "footstep", c(12, 15), 0))
	_check("… et il entend toujours", noeud.sons_entendus == avant + 1)
	nuage.free()
	var inconnu := FauxGadget.new()
	r.scene.add_child(inconnu)
	await _derouler(r, 6)
	_check("un gadget qui bouche la lumière sans qu'on sache lire son ombre : le bot est aveugle (voir moins est le seul parti honnête)",
		bool(noeud.monde["aveugle"]) and not bool(noeud.derniere_vue["vu"]))
	inconnu.free()
	await _derouler(r, 6)
	_check("tous les gadgets retirés : la vue revient, aucun obstacle", bool(noeud.derniere_vue["vu"]) and not bool(noeud.monde["aveugle"])
		and (noeud.monde["obstacles"] as Array).is_empty())
	r.liberer()
