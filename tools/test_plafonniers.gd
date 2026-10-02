## La garde des PLAFONNIERS — chantier SOLO, étape S5 : la lumière posée, permanente, indestructible des salles de l'aventure.
##
## Adrien, 2026-10-02 : « Les lumières fixes ne s'éteignent pas. Ce sont des plafonniers. Il faut les implémenter. » Trois rôles qui
## ne valent qu'ensemble : le plafonnier MONTRE les corps qui s'y tiennent, TRAHIT le joueur qui le traverse (le modèle de vue du
## bot le compte), et PORTE OMBRE (les murs hauts le coupent, un mur bas non — il est en hauteur). Cette suite est la moitié
## HEADLESS de la preuve ; l'autre moitié — la lumière réelle, lue sur les capteurs des corps — est
## `tools/banc_perception_bot.tscn` (familles `plafonnier`, `plafonnier_mur`, `plafonnier_bas`), qui ouvre une fenêtre.
##
## Ce que la suite vérifie, **sans monter de partie** (`--script`, une carte fabriquée, des corps factices) :
##
##   • LA POSE DEPUIS DES DONNÉES — `Plafonnier.poser` : les noms (`Plafonnier_<i>`, l'indice DANS la liste), la place (le centre de
##     la case), les bornes du rayon et de l'énergie, la teinte par défaut, l'idempotence, la voix haute devant une entrée invalide ;
##   • LES CANAUX — la portée `DECOR | ENNEMI | JOUEUR_LOCAL` (jamais un canal de vue ni un bit de capteur de soi), les ombres
##     ACTIVÉES, leur masque (les murs, le sprite adverse, les deux capteurs de soi — jamais la couche d'ombre d'un corps), la
##     hauteur de la lampe (au-dessus des murets : pas de bit d'ombre des murs bas) ;
##   • L'INDESTRUCTIBLE — ni collision, ni vie : rien n'y répond au tir ;
##   • L'ALLUMAGE PAR PROXIMITÉ — loin de tout joueur il est éteint, près il brûle, et l'hystérésis l'empêche de clignoter ; **un
##     plafonnier éteint n'est jamais à l'écran d'un joueur** (la portée de vue couvre le cadre le plus large, dans toute visée) ;
##   • AUCUNE POSE DANS UNE CARTE DE DUEL — aucune carte livrée n'en porte, aucun fichier de jeu n'en pose, et le vrai jeu monté sur
##     chaque carte livrée n'en a aucun ;
##   • LA PERCEPTION — une cible sous un plafonnier, en ligne de vue, est VUE ; la même derrière un mur haut ne l'est pas ; hors de la
##     flaque, rien ; un mur bas la cache par la géométrie de la hauteur de la lampe, pas par l'angle de la torche ; un bot derrière
##     un mur ne voit pas ce que le plafonnier éclaire ; un plafonnier éteint ou trop faible n'entre pas dans le modèle ;
##   • LA VUE ISO — le miroir de lumières 3D porte le plafonnier à sa hauteur, au plus deux par joueur, et le luminaire s'allume avec sa
##     lumière.
##
## **Sabotée famille par famille** (la règle du dépôt : une garde « jamais » ne se croit qu'après l'avoir vue rougir) — la liste est
## dans la ROADMAP, section SOLO, S5.
##
## Lancer : godot --headless --path . --script res://tools/test_plafonniers.gd
extends SceneTree

const Percep := preload("res://perception_bot.gd")
const Noeud := preload("res://perception_bot_noeud.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Murs := preload("res://murs_bas.gd")
const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")
const MiroirT := preload("res://lumieres_iso.gd")

const TUILE := 35.0

var _failures := 0
var _verifications := 0
var _data: Dictionary = {}
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
	print("=== LES PLAFONNIERS (S5) ===")
	var statiques := _poser_les_statiques_du_jeu()
	_data = _carte()
	_arme = WeaponData.new()
	_constantes_du_jeu()
	_donnees()
	await _la_pose()
	await _les_canaux()
	await _indestructible()
	await _allumage()
	_hors_des_cartes_de_duel_statique()
	await _hors_des_cartes_de_duel_vivant()
	_modele_pur()
	await _perception()
	await _miroir_iso()
	await _luminaire_iso()
	_restaurer_les_statiques(statiques)
	print("\n%d vérifications" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# La mise en place
# ---------------------------------------------------------------------------

## Les portées des torches sont des statiques posées au démarrage d'une manche (voir `test_bot_perception`) : on pose celles du jeu.
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


## La carte des situations — la même que `test_bot_perception` : 40 × 30 cases de sol, une paroi pleine en x = 26 (y de 8 à 21) et
## un mur BAS en x = 33 (y de 10 à 19).
func _carte() -> Dictionary:
	var d := Codec.new_map("plafonniers", Vector2i(40, 30))
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	var bas: Array[Vector2i] = []
	for y in 30:
		for x in 40:
			sol.append(Vector2i(x, y))
	for y in range(8, 22):
		murs.append(Vector2i(26, y))
	for y in range(10, 20):
		bas.append(Vector2i(33, y))
	d["floor"] = Codec.encode_runs(sol)
	d["walls"] = Codec.encode_runs(murs)
	d["low_walls"] = Codec.encode_runs(bas)
	return d


static func c(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * TUILE, (float(y) + 0.5) * TUILE)


## Un corps factice : l'interface que `PerceptionBotNoeud` lit, et le groupe « players » que le plafonnier regarde.
class FauxJoueur extends Node2D:
	var player_id := 0
	var accroupi := false
	var dead := false
	var current_weapon: WeaponData = null
	var flashlight := PointLight2D.new()
	var ambient_light := PointLight2D.new()
	var muzzle_flash := PointLight2D.new()

	func _init(id: int, arme: WeaponData) -> void:
		player_id = id
		current_weapon = arme
		name = "Faux%d" % id
		flashlight.enabled = false
		muzzle_flash.enabled = false
		ambient_light.enabled = false
		for l in [flashlight, ambient_light, muzzle_flash]:
			add_child(l)
		LightTextures.poser(ambient_light, LightTextures.AMBIANTE, LightTextures.EMPREINTE_AMBIANTE)
		LightTextures.poser(muzzle_flash, LightTextures.FLASH[0], LightTextures.EMPREINTE_FLASH)

	func _ready() -> void:
		add_to_group("players")


## Un faux `GameState` : ce que le miroir de lumières iso et les volumes lisent de lui.
class FauxMain extends Node:
	var p1: Node2D = null
	var p2: Node2D = null
	var ghost_p1: Node2D = null
	var ghost_p2: Node2D = null
	var current_snap = null
	var bullet_container := Node2D.new()

	func _init() -> void:
		name = "FauxMain"
		bullet_container.name = "Balles"
		add_child(bullet_container)


## Une scène neuve, à l'origine, sous la racine.
func _scene(nom: String) -> Node2D:
	var s := Node2D.new()
	s.name = nom
	root.add_child(s)
	return s


func _images(n: int) -> void:
	for i in n:
		await physics_frame


# ---------------------------------------------------------------------------
# Ce que la suite relit sur le jeu vivant
# ---------------------------------------------------------------------------

func _constantes_du_jeu() -> void:
	print("\n[Les constantes, relues sur le jeu vivant]")
	var reglages: Node = root.get_node("GameSettings")
	_check("la tuile de `Plafonnier` est celle de la carte (CandelaTileSet.TILE_SIZE)", Plafonnier.TUILE_PX == float(CandelaTileSet.TILE_SIZE.x))
	_check("le zoom de référence est celui de l'écran scindé, le plus large livré (GameSettings.ZOOM_ECRAN_SCINDE)",
		is_equal_approx(Plafonnier.ZOOM_LE_PLUS_LARGE, float(reglages.ZOOM_ECRAN_SCINDE))
		and Plafonnier.ZOOM_LE_PLUS_LARGE <= float(reglages.ZOOM_VUE_UNIQUE))
	_check("le décalage vers la visée est celui du jeu (GameSettings.DECALAGE_VISEE_DEFAUT)",
		is_equal_approx(Plafonnier.DECALAGE_VISEE, float(reglages.DECALAGE_VISEE_DEFAUT)))
	_check("la hauteur du plafonnier dépasse celle des murets (0,4) et la fusée au lancer l'égale (MursBasRendu.HAUTEUR_FUSEE_LANCER)",
		Plafonnier.HAUTEUR_TUILES > MapGeometry.HAUTEUR_MUR_BAS and is_equal_approx(Plafonnier.HAUTEUR_TUILES, MursBasRendu.HAUTEUR_FUSEE_LANCER))
	_check("… et elle est au-dessus des murs hauts eux-mêmes (1,25) : une lampe de plafond, qu'ils coupent par règle, non par hauteur",
		Plafonnier.HAUTEUR_TUILES > MapGeometry.HAUTEUR_MUR_HAUT)
	_check("l'énergie par défaut est celle de la braise d'une fusée (FuseeModele.ENERGIE_BRAISE)",
		is_equal_approx(Plafonnier.INTENSITE_PAR_DEFAUT, FuseeModele.ENERGIE_BRAISE))
	_check("la teinte par défaut est l'halogène de la charte (Charte.HALOGENE)", Plafonnier.TEINTE_PAR_DEFAUT == Charte.HALOGENE)
	_check("les bornes se tiennent : min ≤ défaut ≤ max, pour le rayon et l'énergie",
		Plafonnier.RAYON_MIN <= Plafonnier.RAYON_PAR_DEFAUT and Plafonnier.RAYON_PAR_DEFAUT <= Plafonnier.RAYON_MAX
		and Plafonnier.INTENSITE_MIN <= Plafonnier.INTENSITE_PAR_DEFAUT and Plafonnier.INTENSITE_PAR_DEFAUT <= Plafonnier.INTENSITE_MAX)
	_check("la portée du modèle du bot (FRACTION_PLAFONNIER) reste sous la fraction que le masque éclaire (0,75 de son rayon)",
		Percep.FRACTION_PLAFONNIER > 0.0 and Percep.FRACTION_PLAFONNIER <= 0.75)


# ---------------------------------------------------------------------------
# Les données
# ---------------------------------------------------------------------------

func _donnees() -> void:
	print("\n[Les données : ce qu'une entrée dit]")
	_check("une entrée complète est valide", Plafonnier.valider({"case": Vector2i(3, 4), "rayon": 4.0, "intensite": 1.0}) == "")
	_check("« case » en [x, y] flottants (le JSON) est valide", Plafonnier.valider({"case": [3.0, 4.0]}) == "")
	_check("sans « case » : refusé", Plafonnier.valider({"rayon": 4.0}) != "")
	_check("« case » à trois nombres : refusé", Plafonnier.valider({"case": [1, 2, 3]}) != "")
	_check("« case » en texte : refusé", Plafonnier.valider({"case": "3,4"}) != "")
	_check("« rayon » en texte : refusé", Plafonnier.valider({"case": [1, 2], "rayon": "grand"}) != "")
	_check("une entrée qui n'est pas un dictionnaire : refusée", Plafonnier.valider(42) != "")
	_check("« teinte » en nombre : refusée", Plafonnier.valider({"case": [1, 2], "teinte": 3}) != "")
	var n := Plafonnier.normaliser({"case": [3.0, 4.0]})
	_check("normalisée sans rien d'autre : la case, le centre de la case en pixels, le défaut du rayon, de l'énergie et de la teinte",
		n["case"] == Vector2i(3, 4) and (n["position"] as Vector2).is_equal_approx(c(3, 4))
		and is_equal_approx(float(n["rayon"]), Plafonnier.RAYON_PAR_DEFAUT)
		and is_equal_approx(float(n["intensite"]), Plafonnier.INTENSITE_PAR_DEFAUT) and n["teinte"] == Plafonnier.TEINTE_PAR_DEFAUT, str(n))
	var trop := Plafonnier.normaliser({"case": [0, 0], "rayon": 99.0, "intensite": 99.0})
	var peu := Plafonnier.normaliser({"case": [0, 0], "rayon": 0.0, "intensite": 0.0})
	_check("un rayon et une énergie hors bornes sont ramenés aux bornes (le banc n'a éprouvé le modèle que sur la plage permise)",
		is_equal_approx(float(trop["rayon"]), Plafonnier.RAYON_MAX) and is_equal_approx(float(trop["intensite"]), Plafonnier.INTENSITE_MAX)
		and is_equal_approx(float(peu["rayon"]), Plafonnier.RAYON_MIN) and is_equal_approx(float(peu["intensite"]), Plafonnier.INTENSITE_MIN))
	var teinte := Plafonnier.normaliser({"case": [0, 0], "teinte": "#ff8000"})["teinte"] as Color
	_check("une teinte en texte HTML devient une couleur", teinte.is_equal_approx(Color("#ff8000")), str(teinte))


# ---------------------------------------------------------------------------
# La pose
# ---------------------------------------------------------------------------

func _la_pose() -> void:
	print("\n[La pose depuis des données]")
	var arene := _scene("Arene")
	var liste := [
		{"case": Vector2i(5, 6), "rayon": 4.0, "intensite": 1.0},
		{"case": [12.0, 9.0]},
		{"case": [20, 20], "rayon": 6.5, "intensite": 2.0, "teinte": "#ffcc88"},
	]
	var poses := Plafonnier.poser(arene, liste)
	_check("trois entrées, trois plafonniers", poses.size() == 3)
	var conteneur := arene.get_node_or_null(Plafonnier.NOM_CONTENEUR)
	_check("sous un conteneur nommé « %s »" % Plafonnier.NOM_CONTENEUR, conteneur != null and conteneur.get_child_count() == 3)
	for i in poses.size():
		_check("le plafonnier %d porte un nom EXPLICITE (Plafonnier_%d), jamais un nom généré" % [i, i],
			String(poses[i].name) == "Plafonnier_%d" % i and not String(poses[i].name).contains("@"))
	await _images(2)
	_check("placés au centre de leur case, en coordonnées du monde",
		poses[0].global_position.is_equal_approx(c(5, 6)) and poses[1].global_position.is_equal_approx(c(12, 9))
		and poses[2].global_position.is_equal_approx(c(20, 20)), str([poses[0].global_position, poses[1].global_position, poses[2].global_position]))
	_check("ils sont dans le groupe « %s »" % Plafonnier.GROUPE, get_nodes_in_group(Plafonnier.GROUPE).size() == 3)
	var h0: PointLight2D = poses[0].halo
	var h2: PointLight2D = poses[2].halo
	_check("chacun porte une lumière « Halo » (le nom que lisent le miroir iso et le modèle du bot)",
		h0 != null and h0.name == "Halo" and poses[0].get_node_or_null("Halo") == h0)
	_check("rayon : 4 cases → une texture de 8 cases d'empreinte (le rayon au sol, par `LightTextures.poser`, jamais un `texture_scale` à la main)",
		is_equal_approx(float(h0.texture.get_width()) * h0.texture_scale, 2.0 * 4.0 * TUILE),
		str(float(h0.texture.get_width()) * h0.texture_scale))
	_check("rayon par défaut et rayon donné : 4 et 6,5 cases",
		is_equal_approx(float(poses[1].halo.texture.get_width()) * poses[1].halo.texture_scale, 2.0 * Plafonnier.RAYON_PAR_DEFAUT * TUILE)
		and is_equal_approx(float(h2.texture.get_width()) * h2.texture_scale, 2.0 * 6.5 * TUILE))
	_check("énergie : donnée (1,0 et 2,0) ou par défaut",
		is_equal_approx(h0.energy, 1.0) and is_equal_approx(poses[1].halo.energy, Plafonnier.INTENSITE_PAR_DEFAUT) and is_equal_approx(h2.energy, 2.0))
	_check("teinte : l'halogène par défaut, la couleur donnée sinon",
		poses[1].halo.color == Charte.HALOGENE and h2.color.is_equal_approx(Color("#ffcc88")))
	_check("la lumière est une lumière de décor posée : allumée, à ombres, de couleur chaude et sobre (rien de saturé)",
		h0.enabled and h0.shadow_enabled and Charte.HALOGENE.s < 0.3)

	# Idempotente : une seconde pose REMPLACE la première.
	var seconde := Plafonnier.poser(arene, [{"case": [1, 1]}])
	await _images(2)
	_check("poser une seconde liste remplace la première : un conteneur, un plafonnier, un seul dans le groupe",
		arene.get_children().filter(func(n: Node) -> bool: return n.name == Plafonnier.NOM_CONTENEUR).size() == 1
		and seconde.size() == 1 and get_nodes_in_group(Plafonnier.GROUPE).size() == 1, str(get_nodes_in_group(Plafonnier.GROUPE).size()))
	Plafonnier.retirer(arene)
	_check("`retirer` les ôte du groupe tout de suite — avant que `queue_free` n'agisse : le modèle du bot ne les verrait plus d'une image",
		get_nodes_in_group(Plafonnier.GROUPE).is_empty() and arene.get_node_or_null(Plafonnier.NOM_CONTENEUR) == null)
	await _images(2)

	# Une entrée invalide : refusée À VOIX HAUTE, et son indice n'est pas réutilisé.
	print("CRIS ATTENDUS: 1")
	var avec_une_mauvaise := Plafonnier.poser(arene, [{"case": [2, 2]}, {"rayon": 3.0}, {"case": [4, 4]}])
	await _images(2)
	_check("une entrée sans case est refusée (un `push_error`) : deux plafonniers posés sur trois entrées", avec_une_mauvaise.size() == 2)
	_check("… et le troisième garde SON indice : « Plafonnier_2 », pas « Plafonnier_1 » (S6 retrouve ses plafonniers par leur place dans le niveau)",
		avec_une_mauvaise.size() == 2 and String(avec_une_mauvaise[1].name) == "Plafonnier_2")
	Plafonnier.retirer(arene)
	var vide := Plafonnier.poser(arene, [])
	_check("une liste vide pose un conteneur vide, sans erreur", vide.is_empty())
	Plafonnier.retirer(arene)
	arene.queue_free()
	await _images(2)


# ---------------------------------------------------------------------------
# Les canaux, les ombres, la hauteur
# ---------------------------------------------------------------------------

func _les_canaux_de(p: Plafonnier, etiquette: String) -> void:
	var l := p.halo
	var portee := l.range_item_cull_mask
	var ombre := l.shadow_item_cull_mask
	var interdits_en_portee := {
		"le canal de vue de J1 (16)": CanauxLumiere.canal_de_vue(0), "le canal de vue de J2 (32)": CanauxLumiere.canal_de_vue(1),
		"la couche d'ombre du corps de J2 (8)": CanauxLumiere.couche_ombre_corps(1),
		"le bit récepteur de J1 (128)": CanauxLumiere.recepteur_retro(0), "le bit récepteur de J2 (256)": CanauxLumiere.recepteur_retro(1)}
	_check("%s : la portée est DECOR | ENNEMI | JOUEUR_LOCAL — sol et murs, sprite adverse et capteurs croisés, joueur local (une lumière NEUTRE)" % etiquette,
		portee == (CanauxLumiere.DECOR | CanauxLumiere.ENNEMI | CanauxLumiere.JOUEUR_LOCAL), str(portee))
	var fautifs: Array[String] = []
	for nom: String in interdits_en_portee:
		if (portee & int(interdits_en_portee[nom])) != 0:
			fautifs.append(nom)
	_check("%s : aucun canal de vue ni bit de capteur de soi dans sa portée (`test_ombre_propre` les interdit : une lumière ne doit pas n'éclairer qu'UN joueur)" % etiquette,
		fautifs.is_empty(), str(fautifs))
	_check("%s : les ombres sont ACTIVÉES (sans elles la lumière traverserait les murs, et la mécanique centrale du jeu disparaîtrait)" % etiquette, l.shadow_enabled)
	_check("%s : le masque d'ombre est celui des lumières neutres (`CanauxLumiere.masque_ombre_neutre_pour_les_corps`)" % etiquette,
		ombre & CanauxLumiere.masque_ombre_neutre_pour_les_corps() == CanauxLumiere.masque_ombre_neutre_pour_les_corps())
	_check("%s : …il contient l'occluder des MURS (1)" % etiquette, (ombre & CanauxLumiere.DECOR) != 0)
	_check("%s : …le canal du sprite adverse et des capteurs croisés (2) : sans lui le corps d'en face est « éclairé en entier » à travers un mur"
		% etiquette, (ombre & CanauxLumiere.ENNEMI) != 0)
	_check("%s : …les deux bits des capteurs de SOI (128 et 256) : chaque joueur reçoit l'ombre des murs sur son propre corps" % etiquette,
		(ombre & CanauxLumiere.recepteur_retro(0)) != 0 and (ombre & CanauxLumiere.recepteur_retro(1)) != 0)
	_check("%s : …mais JAMAIS la couche d'ombre d'un corps (4, 8) ni d'un torse (16, 32) : un plafonnier ne plonge pas son éclairé dans sa propre ombre"
		% etiquette, (ombre & (CanauxLumiere.couche_ombre_corps(0) | CanauxLumiere.couche_ombre_corps(1)
			| CanauxLumiere.couche_ombre_torse(0) | CanauxLumiere.couche_ombre_torse(1))) == 0, str(ombre))
	_check("%s : …et PAS le bit des murs bas (64) : une lampe de plafond passe par-dessus (`poser_hauteur_source` le retire)" % etiquette,
		(ombre & CanauxLumiere.COUCHE_OMBRE_MUR_BAS) == 0, str(ombre))
	_check("%s : la lampe est à sa hauteur déclarée (1,5 tuile = 52,5 px), lue par le shader des murs bas et le miroir iso" % etiquette,
		is_equal_approx(l.height, Plafonnier.HAUTEUR_TUILES * TUILE) and is_equal_approx(MursBasRendu.hauteur_source(l), Plafonnier.HAUTEUR_TUILES),
		str(l.height))
	_check("%s : elle déclare une hauteur plus haute que les murets : le modèle du bot la juge par la géométrie de cette hauteur" % etiquette,
		l.height > Murs.hauteur_mur())


func _les_canaux() -> void:
	print("\n[Les canaux, les ombres, la hauteur — conformes à `canaux_lumiere.gd`]")
	var arene := _scene("ArenePourLesCanaux")
	var poses := Plafonnier.poser(arene, [{"case": [5, 5]}, {"case": [10, 10], "rayon": 8.0, "intensite": 3.0}])
	await _images(2)
	for i in poses.size():
		_les_canaux_de(poses[i], "Plafonnier_%d" % i)
	# Le masque neutre se compare à ce que les récepteurs portent VRAIMENT.
	var recepteurs := {
		"le sprite adverse de J1 (masque_vue_adverse)": CanauxLumiere.masque_vue_adverse(0),
		"le sprite adverse de J2": CanauxLumiere.masque_vue_adverse(1),
		"le capteur de soi de J1 (masque_de_soi)": CanauxLumiere.masque_de_soi(0),
		"le capteur de soi de J2": CanauxLumiere.masque_de_soi(1)}
	var masque := CanauxLumiere.masque_ombre_neutre_pour_les_corps()
	for nom: String in recepteurs:
		_check("le masque d'ombre croise celui de %s : l'ombre des murs lui est donnée" % nom, (masque & int(recepteurs[nom])) != 0,
			"%d & %d" % [masque, int(recepteurs[nom])])
	# Et la portée éclaire les mêmes récepteurs.
	for nom: String in recepteurs:
		_check("la portée du plafonnier éclaire %s" % nom, (poses[0].halo.range_item_cull_mask & int(recepteurs[nom])) != 0)
	Plafonnier.retirer(arene)
	arene.queue_free()
	await _images(2)


# ---------------------------------------------------------------------------
# L'indestructible
# ---------------------------------------------------------------------------

func _indestructible() -> void:
	print("\n[Indestructible : rien ne répond au tir ni au pas]")
	var arene := _scene("AreneIndestructible")
	var poses := Plafonnier.poser(arene, [{"case": [5, 5]}])
	await _images(2)
	var p: Plafonnier = poses[0]
	var corps := p.find_children("*", "CollisionObject2D", true, false)
	var formes := p.find_children("*", "CollisionShape2D", true, false)
	_check("aucune collision (ni corps, ni zone, ni forme) : une balle le traverse, un pas ne le heurte pas", corps.is_empty() and formes.is_empty())
	_check("aucune vie, aucun point de dégât : le script ne déclare ni `hp` ni `take_damage`",
		not ("hp" in p) and not p.has_method("take_damage") and not p.has_method("subir") and not p.has_method("eteindre"))
	_check("rien n'y éteint la lumière que la proximité : pas de méthode pour l'éteindre, pas de bouton",
		not p.has_method("toggle") and not p.has_method("set_enabled") and not p.has_method("eteindre"))
	_check("ses seuls enfants : « Halo », la lumière", p.get_child_count() == 1 and p.get_child(0) == p.halo)
	Plafonnier.retirer(arene)
	arene.queue_free()
	await _images(2)


# ---------------------------------------------------------------------------
# L'allumage par proximité
# ---------------------------------------------------------------------------

func _allumage() -> void:
	print("\n[L'allumage par proximité]")
	var portee := Plafonnier.portee_de_vue_px()
	var centre := Vector2(2000.0, 2000.0)
	var r := 150.0
	var on := Plafonnier.rayon_d_allumage_px(r)
	var off := on + Plafonnier.HYSTERESIS_PX
	_check("le rayon d'allumage est celui de la flaque plus la portée de vue", is_equal_approx(on, r + portee))
	_check("la portée de vue dépasse le coin de l'écran du cadrage le plus large, avancé vers la visée (PorteeEcran.portee_minimale)",
		portee >= Portee.portee_minimale(Portee.VUE_UNIQUE, Plafonnier.zoom_de_reference, Plafonnier.DECALAGE_VISEE, Iso.TANGAGE_DEG) + Plafonnier.MARGE_VUE_PX - 0.01)
	_check("loin de tout joueur, un plafonnier éteint est éteint", not Plafonnier.doit_etre_allume(false, centre, r, [centre + Vector2(off + 500.0, 0.0)]))
	_check("juste sous le seuil d'allumage, il s'allume", Plafonnier.doit_etre_allume(false, centre, r, [centre + Vector2(on - 1.0, 0.0)]))
	_check("juste au-dessus du seuil d'allumage, il reste éteint", not Plafonnier.doit_etre_allume(false, centre, r, [centre + Vector2(on + 1.0, 0.0)]))
	_check("L'HYSTÉRÉSIS : allumé, il ne s'éteint pas entre le seuil d'allumage et celui d'extinction",
		Plafonnier.doit_etre_allume(true, centre, r, [centre + Vector2(on + Plafonnier.HYSTERESIS_PX * 0.5, 0.0)]))
	_check("… et s'éteint au-delà", not Plafonnier.doit_etre_allume(true, centre, r, [centre + Vector2(off + 1.0, 0.0)]))
	_check("… tandis qu'éteint, au même endroit, il reste éteint : pas de clignotement sur la limite",
		not Plafonnier.doit_etre_allume(false, centre, r, [centre + Vector2(on + Plafonnier.HYSTERESIS_PX * 0.5, 0.0)]))
	_check("deux joueurs : le plus proche décide", Plafonnier.doit_etre_allume(false, centre, r,
		[centre + Vector2(off + 900.0, 0.0), centre + Vector2(0.0, on - 5.0)]))
	_check("sans aucun joueur connu il BRÛLE : éteindre sans savoir ferait disparaître une salle qu'un banc regarde sans joueur",
		Plafonnier.doit_etre_allume(false, centre, r, []))
	_check("une flaque plus large s'allume de plus loin (le rayon compte)",
		Plafonnier.rayon_d_allumage_px(300.0) > Plafonnier.rayon_d_allumage_px(100.0))

	# Un plafonnier éteint n'est JAMAIS à l'écran d'un joueur qui est à portée de le voir : pour toute visée, les quatre coins du
	# cadre (le modèle du bot et, au pixel près, la caméra réelle) sont à moins de la portée de vue du joueur.
	var pire := 0.0
	for k in 72:
		var visee := Vector2.from_angle(TAU * float(k) / 72.0)
		var cadre := Percep.cadre_de_vue(Vector2.ZERO, visee, {"zoom": Plafonnier.zoom_de_reference})
		var demi: Vector2 = cadre["demi"]
		for coin in [Vector2(-demi.x, -demi.y), Vector2(demi.x, -demi.y), demi, Vector2(-demi.x, demi.y)]:
			var monde: Vector2 = (cadre["centre"] as Vector2) + (coin as Vector2).rotated(-deg_to_rad(float(cadre["lacet"])))
			pire = maxf(pire, monde.length())
	_check("pour 72 visées, le coin le plus lointain du cadre (zoom %.2f) est à %.0f px du joueur, sous la portée de vue (%.0f px)"
		% [Plafonnier.zoom_de_reference, pire, portee], pire <= portee, "%.1f > %.1f" % [pire, portee])
	# Le cadrage de vue UNIQUE du jeu (×1,5, plus serré) est lui aussi couvert.
	var pire_unique := 0.0
	for k in 72:
		var visee := Vector2.from_angle(TAU * float(k) / 72.0)
		var cadre := Percep.cadre_de_vue(Vector2.ZERO, visee, {})
		var demi: Vector2 = cadre["demi"]
		for coin in [Vector2(-demi.x, -demi.y), Vector2(demi.x, -demi.y), demi, Vector2(-demi.x, demi.y)]:
			var monde: Vector2 = (cadre["centre"] as Vector2) + (coin as Vector2).rotated(-deg_to_rad(float(cadre["lacet"])))
			pire_unique = maxf(pire_unique, monde.length())
	_check("… et le cadrage de la vue unique (×1,5) : %.0f px" % pire_unique, pire_unique <= portee)

	# Sur le nœud vivant, avec de faux joueurs du groupe « players ».
	var scene := _scene("SceneAllumage")
	var j1 := FauxJoueur.new(0, _arme)
	scene.add_child(j1)
	j1.global_position = Vector2(100.0, 100.0)
	var poses := Plafonnier.poser(scene, [{"case": [5, 5], "rayon": 4.0}, {"case": [200, 5], "rayon": 4.0}])
	await _images(2)
	_check("un joueur à proximité : le plafonnier proche brûle", poses[0].halo.enabled and poses[0].allume)
	_check("… et le plafonnier à 7 000 px est ÉTEINT (une lumière à ombres de moins)", not poses[1].halo.enabled and not poses[1].allume,
		str(poses[1].global_position.distance_to(j1.global_position)))
	# Le joueur s'approche : l'éloigné s'allume au seuil.
	j1.global_position = poses[1].global_position - Vector2(on_de(poses[1]) - 1.0, 0.0)
	await _images(2)
	_check("le joueur arrive sous le seuil d'allumage du second : il s'allume", poses[1].halo.enabled)
	_check("… et le premier, maintenant trop loin, s'éteint", not poses[0].halo.enabled)
	# L'hystérésis, sur le nœud.
	j1.global_position = poses[1].global_position - Vector2(on_de(poses[1]) + Plafonnier.HYSTERESIS_PX * 0.5, 0.0)
	await _images(2)
	_check("le joueur recule dans la bande d'hystérésis : le second reste allumé (pas de clignotement)", poses[1].halo.enabled)
	j1.global_position = poses[1].global_position - Vector2(on_de(poses[1]) + Plafonnier.HYSTERESIS_PX + 5.0, 0.0)
	await _images(2)
	_check("il recule au-delà : le second s'éteint", not poses[1].halo.enabled)
	# Un joueur mort compte encore (la killcam regarde sa place) ; un joueur absent du groupe non — mais sans AUCUN joueur, on brûle.
	j1.queue_free()
	await _images(3)
	_check("sans plus aucun joueur dans le groupe, les deux brûlent (par prudence)", poses[0].halo.enabled and poses[1].halo.enabled)
	Plafonnier.retirer(scene)
	scene.queue_free()
	await _images(2)


func on_de(p: Plafonnier) -> float:
	return Plafonnier.rayon_d_allumage_px(p.rayon_px)


# ---------------------------------------------------------------------------
# Aucune pose dans une carte de duel
# ---------------------------------------------------------------------------

func _cartes_livrees() -> Dictionary:
	var sortie := {}
	var dossier := DirAccess.open("res://assets/maps")
	if dossier == null:
		return sortie
	var fichiers := Array(dossier.get_files())
	fichiers.sort()
	for f: String in fichiers:
		if not f.ends_with(".json"):
			continue
		var fichier := FileAccess.open("res://assets/maps/" + f, FileAccess.READ)
		var json := JSON.new()
		if json.parse(fichier.get_as_text()) != OK:
			continue
		var r: Dictionary = Codec.validate(json.data as Dictionary)
		if r["ok"]:
			sortie[f] = {"brut": json.data, "valide": r["data"]}
	return sortie


## Les fichiers de jeu qui NOMMENT la pose. Aujourd'hui : aucun. S6 y ajoutera son moteur d'aventure — et cette liste, À LA MAIN : un
## fichier de plus qui pose des plafonniers doit être un choix, jamais un effet de bord (« il n'entre dans les cartes de duel que
## si Adrien le demande, avec une montée de `Protocol.VERSION` »).
const POSEURS_AUTORISES: Array[String] = []


func _hors_des_cartes_de_duel_statique() -> void:
	print("\n[Aucune pose dans une carte de duel : les données et le code]")
	var cartes := _cartes_livrees()
	_check("le catalogue livre plusieurs cartes", cartes.size() >= 5, str(cartes.size()))
	var avec: Array[String] = []
	for f: String in cartes:
		for racine: Dictionary in [cartes[f]["brut"], cartes[f]["valide"]]:
			for cle in racine.keys():
				if String(cle).to_lower().contains("plafonnier") or String(cle).to_lower().contains("luminaire"):
					avec.append("%s : %s" % [f, cle])
	_check("aucune carte livrée ne porte de clé « plafonnier » ni « luminaire » (le format de carte ne les connaît pas)", avec.is_empty(), str(avec))
	_check("le format de carte (`MapCodec`) ne sait pas les écrire : aucun nom de plafonnier dans `map_codec.gd`",
		not FileAccess.get_file_as_string("res://map_codec.gd").to_lower().contains("plafonnier"))
	var poseurs: Array[String] = []
	var scannes := 0
	for f in DirAccess.get_files_at("res://"):
		if not f.ends_with(".gd") or f == "plafonnier.gd":
			continue
		scannes += 1
		var texte := FileAccess.get_file_as_string("res://" + f)
		for ligne in texte.split("\n"):
			var nette: String = ligne.strip_edges()
			if nette.begins_with("#"):
				continue
			if nette.contains("Plafonnier.poser(") or nette.contains("Plafonnier.new(") or nette.contains("plafonnier.gd\").new"):
				if not POSEURS_AUTORISES.has(f):
					poseurs.append("%s : %s" % [f, nette])
	_check("aucun fichier de jeu (%d scannés) ne pose de plafonnier : seul le solo le fera, et il s'inscrira à la main dans POSEURS_AUTORISES" % scannes,
		scannes > 100 and poseurs.is_empty(), str(poseurs))
	_check("`protocol.gd` ne dit rien des plafonniers : rien ne transite sur le réseau",
		not FileAccess.get_file_as_string("res://protocol.gd").to_lower().contains("plafonnier"))
	var reseau := FileAccess.get_file_as_string("res://network_manager.gd").to_lower()
	_check("`network_manager.gd` non plus", not reseau.contains("plafonnier"))
	_check("et le script du plafonnier ne nomme ni RPC, ni pair, ni transport", not _contient_un_mot_reseau(FileAccess.get_file_as_string("res://plafonnier.gd")))


func _contient_un_mot_reseau(texte: String) -> bool:
	for ligne in texte.split("\n"):
		var nette: String = ligne.strip_edges()
		if nette.begins_with("#"):
			continue
		for mot in ["@rpc", "multiplayer", "NetworkManager", ".rpc(", "ENet", "EOS"]:
			if nette.contains(mot):
				return true
	return false


## Le VRAI jeu, monté, sur chaque carte livrée : en duel local, puis à l'entraînement — aucun plafonnier dans le groupe, aucun conteneur
## dans l'arène.
func _hors_des_cartes_de_duel_vivant() -> void:
	print("\n[Aucune pose dans une carte de duel : le jeu monté, sur chaque carte livrée]")
	var cartes: Node = root.get_node("MapData")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set("archiver_les_matchs", false)
	await _images(3)
	var livrees: Array[Dictionary] = []
	for entree in cartes.list_maps():
		if String(entree["source"]) == "builtin":
			livrees.append(entree)
	_check("le catalogue livre plusieurs cartes", livrees.size() >= 5, str(livrees.size()))
	for entree in livrees:
		var id := String(entree["id"])
		cartes.select_map(id)
		main._on_main_menu_requested()
		await _images(2)
		main._on_replay_requested()
		await _images(3)
		var arene: Node = main.get("arena")
		_check("« %s », en duel : aucun plafonnier dans le groupe, aucun conteneur dans l'arène" % String(entree["name"]),
			get_nodes_in_group(Plafonnier.GROUPE).is_empty() and arene.get_node_or_null(Plafonnier.NOM_CONTENEUR) == null
			and main.get("round_active") == true)
	# L'entraînement.
	cartes.select_map(String(livrees[0]["id"]))
	main._on_main_menu_requested()
	await _images(2)
	main.get("ui").hub.push(main.get("ui").SCREEN_TRAINING)
	await _images(2)
	main.get("ui")._on_hub_action("entrainement")
	await _images(3)
	_check("à l'entraînement : aucun plafonnier non plus", main.get("training_mode") == true and get_nodes_in_group(Plafonnier.GROUPE).is_empty())
	main._on_main_menu_requested()
	await _images(2)
	main.queue_free()
	await _images(3)


# ---------------------------------------------------------------------------
# La perception : le modèle pur
# ---------------------------------------------------------------------------

func _modele_pur() -> void:
	print("\n[La perception : le disque d'un plafonnier, des fonctions pures]")
	var monde := Percep.monde_de_la_carte(_data)
	var h_lampe := Plafonnier.HAUTEUR_TUILES * TUILE
	# Un mur bas en x = 33 (de 1155 à 1190 px, rentré de 3 px : sortie à 1187), y de 10 à 19 (350 à 700 px).
	var y := c(30, 15).y
	var plafonnier := Percep.lumiere_disque("plafonnier", Vector2(c(27, 15).x, y), 400.0, h_lampe, true)
	var sortie_x := 33.0 * TUILE + TUILE - Murs.RETRAIT_LUMIERE
	var d_sortie: float = sortie_x - (plafonnier["origine"] as Vector2).x
	var zone_lampe := MursBasRendu.zone_morte_source(d_sortie, h_lampe, Murs.hauteur_mur(), Murs.hauteur_de_posture(true))
	var zone_torche := Murs.longueur_zone_morte(Murs.hauteur_mur(), Murs.hauteur_de_posture(true), Murs.ANGLE_FRANCHISSEMENT)
	_check("(la situation : à %.0f px du muret, la zone morte d'un accroupi est de %.1f px pour la lampe du plafonnier, %.1f px pour la règle de la torche)"
		% [d_sortie, zone_lampe, zone_torche], zone_lampe > zone_torche + 10.0)
	# Le modèle juge le point du corps le plus proche de la lampe (18 px devant le centre) ET le centre : pour que la règle de la
	# torche laisse passer les deux, le centre est à plus de `zone_torche + 18`.
	var k := zone_torche + Percep.RAYON_CORPS + 4.0
	_check("(… et le point le plus proche d'un corps centré à %.0f px derrière le muret, soit %.0f px, y est encore dans la zone de la lampe)"
		% [k, k - Percep.RAYON_CORPS], k - Percep.RAYON_CORPS < zone_lampe)
	var accroupi := Vector2(sortie_x + k, y)
	_check("un accroupi à %.0f px derrière le mur bas, par son bord proche DANS la zone morte de la lampe haute (%.0f px) mais hors de celle de la torche (%.0f) : le plafonnier ne l'éclaire PAS"
		% [k, zone_lampe, zone_torche], not Percep.eclaire(plafonnier, accroupi, Murs.hauteur_de_posture(true), monde))
	var tenue := Percep.lumiere_disque("tenue", Vector2(c(27, 15).x, y), 400.0, h_lampe, false)
	_check("(le même disque jugé par la règle de la torche l'éclairerait : la règle par hauteur n'est pas un détail)",
		Percep.eclaire(tenue, accroupi, Murs.hauteur_de_posture(true), monde))
	var assez_loin := Vector2(sortie_x + zone_lampe + Percep.RAYON_CORPS + 8.0, y)
	_check("hors de la zone morte, le même accroupi est éclairé", Percep.eclaire(plafonnier, assez_loin, Murs.hauteur_de_posture(true), monde))
	var debout := Vector2(sortie_x + 6.0, y)
	_check("un corps DEBOUT collé derrière le mur bas est éclairé : la lampe passe par-dessus, et une tête dépasse le muret",
		Percep.eclaire(plafonnier, debout, Murs.hauteur_de_posture(false), monde))
	var mur_haut := Percep.lumiere_disque("plafonnier", c(28, 15), 400.0, h_lampe, true)
	_check("un mur HAUT coupe le plafonnier, si haut qu'il pende : la paroi entre la lampe et le corps, rien",
		not Percep.eclaire(mur_haut, c(25, 15), Murs.hauteur_de_posture(false), monde))
	_check("… et du même côté de la paroi, la lampe éclaire", Percep.eclaire(mur_haut, c(30, 15), Murs.hauteur_de_posture(false), monde))
	var sans_hauteur := Percep.lumiere_disque("ancien", c(23, 15), 100.0, 175.0)
	_check("un disque sans `par_hauteur` (le halo, l'éclair, la fusée) garde sa règle : la clé est fausse par défaut",
		not bool(sans_hauteur["par_hauteur"]))


# ---------------------------------------------------------------------------
# La perception : le nœud, sur de vrais plafonniers
# ---------------------------------------------------------------------------

## Pose les corps, un plafonnier de la liste, et un nœud de perception sur le bot ; rend [scène, bot, cible, nœud, plafonniers].
func _situation(bot_c: Vector2, cible_c: Vector2, liste: Array) -> Array:
	var scene := _scene("ScenePlafonniers")
	var bot := FauxJoueur.new(1, _arme)
	var cible := FauxJoueur.new(0, _arme)
	scene.add_child(bot)
	scene.add_child(cible)
	bot.global_position = bot_c
	cible.global_position = cible_c
	cible.rotation = PI
	var profil := Profil.new()
	profil.voit = true
	profil.entend = false
	var noeud := Noeud.new()
	noeud.configurer(profil, _data, bot, 7)
	bot.add_child(noeud)
	var poses := Plafonnier.poser(scene, liste)
	return [scene, bot, cible, noeud, poses]


func _fin(situation: Array) -> void:
	var scene: Node = situation[0]
	Plafonnier.retirer(scene)
	scene.queue_free()


func _perception() -> void:
	print("\n[La perception : le nœud du bot sur de vrais plafonniers]")
	# 1. Une cible SOUS un plafonnier, en ligne de vue : vue, par le plafonnier, à sa place exacte.
	var s := _situation(c(20, 15), c(23, 13), [{"case": [23, 15], "rayon": 5.0}])
	await _images(6)
	var noeud: PerceptionBotNoeud = s[3]
	var cible: Node2D = s[2]
	_check("le plafonnier entre dans la liste des lumières connues du modèle (Plafonnier_0)", noeud.noms_des_lumieres.has("Plafonnier_0"),
		str(noeud.noms_des_lumieres))
	_check("une cible sous le plafonnier (70 px de lui), en ligne de vue, dans le cadre : VUE — et par lui seul",
		bool(noeud.derniere_vue["vu"]) and (noeud.derniere_vue["par"] as Array) == ["Plafonnier_0"], str(noeud.derniere_vue))
	_check("… à sa place exacte : le corps éclairé donne sa position (la mémoire garde une trace de VUE)",
		(noeud.derniere_vue["position"] as Vector2).is_equal_approx(cible.global_position) and noeud.memoire.connue(noeud._t))
	var entrees: Array = noeud.call("_plafonniers")
	var lumiere_vivante: PointLight2D = (s[4][0] as Plafonnier).halo
	_check("le nœud décrit le plafonnier au modèle comme un DISQUE de la lumière VIVANTE : sa place, sa hauteur (52,5 px), %.0f %% de son rayon, et il DÉCLARE sa hauteur (`par_hauteur`)"
		% (Percep.FRACTION_PLAFONNIER * 100.0), entrees.size() == 1 and int(entrees[0]["genre"]) == Percep.Genre.DISQUE
		and (entrees[0]["origine"] as Vector2).is_equal_approx(lumiere_vivante.global_position)
		and is_equal_approx(float(entrees[0]["hauteur"]), Plafonnier.HAUTEUR_TUILES * TUILE)
		and is_equal_approx(float(entrees[0]["rayon"]), 5.0 * TUILE * Percep.FRACTION_PLAFONNIER)
		and bool(entrees[0]["par_hauteur"]) and String(entrees[0]["nom"]) == "Plafonnier_0", str(entrees))
	# 2. Hors de la flaque : rien.
	cible.global_position = c(23, 25)
	await _images(6)
	_check("la même cible à 350 px du plafonnier, hors de sa flaque : rien n'est vu", not bool(noeud.derniere_vue["vu"]), str(noeud.derniere_vue))
	noeud.reinitialiser()
	await _images(6)
	_check("… et la mémoire du bot reste VIDE : il n'a rien vu, il n'a rien entendu (aucun plafonnier ni lampe n'éclaire la cible)",
		not noeud.memoire.connue(noeud._t))
	# 3. Un bord de flaque : au-delà du rayon retenu, non.
	var r_modele := 5.0 * TUILE * Percep.FRACTION_PLAFONNIER
	# Le modèle juge le point du corps le plus proche de la lampe : 18 px devant le centre.
	cible.global_position = c(23, 15) + Vector2(0.0, r_modele + Percep.RAYON_CORPS - 8.0)
	await _images(6)
	_check("le bord du corps à 8 px DANS le rayon retenu par le modèle (%.0f px) : vue" % r_modele, bool(noeud.derniere_vue["vu"]))
	cible.global_position = c(23, 15) + Vector2(0.0, r_modele + Percep.RAYON_CORPS + 8.0)
	await _images(6)
	_check("à 8 px AU-DELÀ : non", not bool(noeud.derniere_vue["vu"]))
	# 4. Un plafonnier éteint (le joueur trop loin) n'entre pas dans le modèle : l'honnêteté tient quoi que fasse l'allumage.
	var p0: Plafonnier = s[4][0]
	# Le plafonnier réécrit `enabled` à chaque pas (la proximité) : on le gèle pour poser l'état sans lui.
	p0.set_physics_process(false)
	p0.halo.enabled = false
	cible.global_position = c(23, 13)
	await _images(4)
	_check("un plafonnier ÉTEINT n'entre pas dans le modèle : le bot ne voit pas la cible (voir moins, jamais plus)",
		not noeud.noms_des_lumieres.has("Plafonnier_0") and not bool(noeud.derniere_vue["vu"]))
	p0.halo.enabled = true
	p0.halo.energy = Plafonnier.INTENSITE_MIN * 0.5
	await _images(4)
	_check("une énergie sous le minimum permis (le banc n'a éprouvé le modèle que sur la plage) n'entre pas non plus",
		not noeud.noms_des_lumieres.has("Plafonnier_0"))
	p0.halo.energy = Plafonnier.INTENSITE_PAR_DEFAUT
	await _images(4)
	_check("remise à l'énergie par défaut, elle revient", noeud.noms_des_lumieres.has("Plafonnier_0") and bool(noeud.derniere_vue["vu"]))
	_fin(s)
	await _images(2)

	# 5. Le mur HAUT : plafonnier de l'autre côté de la paroi pleine (x = 26), la cible de ce côté-ci, DANS le rayon retenu.
	s = _situation(c(20, 15), c(25, 15), [{"case": [28, 15], "rayon": 6.0}])
	await _images(6)
	noeud = s[3]
	var d_mur := c(25, 15).distance_to(c(28, 15))
	_check("(la situation : la cible est à %.0f px du plafonnier, dans le rayon retenu de %.0f px)" % [d_mur, 6.0 * TUILE * Percep.FRACTION_PLAFONNIER],
		d_mur <= 6.0 * TUILE * Percep.FRACTION_PLAFONNIER)
	_check("la MÊME cible, dans la flaque mais DERRIÈRE un mur haut, le bot de l'autre côté : PAS vue — le mur coupe le plafonnier comme la torche",
		not bool(noeud.derniere_vue["vu"]) and not noeud.memoire.connue(noeud._t), str(noeud.derniere_vue))
	# Le témoin, dans la même situation sans mur : la cible à la même distance du plafonnier, au nord (hors de la paroi, qui s'arrête
	# à y = 8), le bot dans son champ : vue — c'est bien le mur qui la cachait.
	var cible_mur: Node2D = s[2]
	var bot_mur: Node2D = s[1]
	bot_mur.global_position = c(28, 5)
	cible_mur.global_position = c(28, 15) + Vector2(0.0, -d_mur)
	await _images(6)
	_check("le témoin : à la même distance (%.0f px) du plafonnier mais sans mur entre elle et le bot, la cible est vue — c'est le mur qui la cachait"
		% d_mur, bool(noeud.derniere_vue["vu"]), str(noeud.derniere_vue))
	# 6. Un bot DERRIÈRE un mur ne voit pas ce que le plafonnier éclaire de l'autre côté : le plafonnier éclaire, la ligne de vue manque.
	_fin(s)
	await _images(2)
	s = _situation(c(20, 15), c(28, 13), [{"case": [28, 15], "rayon": 6.0}])
	await _images(6)
	noeud = s[3]
	_check("une cible dans la flaque, de l'autre côté de la paroi que le bot : éclairée, mais pas vue (le bot n'a pas de ligne de vue)",
		not bool(noeud.derniere_vue["vu"]) and not noeud.memoire.connue(noeud._t), str(noeud.derniere_vue))
	var bot_b: Node2D = s[1]
	bot_b.global_position = c(28, 5)
	await _images(6)
	_check("le même bot, passé du côté du plafonnier (au nord, ligne dégagée) : il la voit", bool(noeud.derniere_vue["vu"]), str(noeud.derniere_vue))
	_fin(s)
	await _images(2)

	# 7. Le mur bas, sur de vrais nœuds : le plafonnier à 3 cases du muret, une cible debout derrière : vue ; accroupie dedans : non.
	s = _situation(c(30, 15), c(35, 15), [{"case": [31, 15], "rayon": 8.0}])
	await _images(6)
	noeud = s[3]
	_check("le plafonnier à 4 cases en deçà d'un mur bas, une cible DEBOUT derrière : vue (une tête dépasse le muret, la lampe passe par-dessus)",
		bool(noeud.derniere_vue["vu"]) and (noeud.derniere_vue["par"] as Array).has("Plafonnier_0"), str(noeud.derniere_vue))
	(s[2] as FauxJoueur).accroupi = true
	(s[2] as FauxJoueur).global_position = Vector2(33.0 * TUILE + TUILE - Murs.RETRAIT_LUMIERE + 10.0, c(30, 15).y)
	await _images(6)
	_check("la cible ACCROUPIE à 10 px derrière le mur bas, dans sa zone morte : pas vue", not bool(noeud.derniere_vue["vu"]), str(noeud.derniere_vue))
	_fin(s)
	await _images(2)

	# 8. Plusieurs plafonniers : la cible dans la flaque de l'un seulement est vue par celui-là.
	s = _situation(c(20, 15), c(23, 13), [{"case": [3, 3], "rayon": 3.0}, {"case": [23, 15], "rayon": 5.0}, {"case": [30, 25], "rayon": 3.0}])
	await _images(6)
	noeud = s[3]
	_check("trois plafonniers : la cible est vue, par le SEUL qui l'éclaire (Plafonnier_1, l'indice dans la liste)",
		bool(noeud.derniere_vue["vu"]) and (noeud.derniere_vue["par"] as Array) == ["Plafonnier_1"], str(noeud.derniere_vue))
	_fin(s)
	await _images(2)

	# 9. L'honnêteté de bout en bout : un bot SANS plafonnier dans une salle noire ne sait rien.
	s = _situation(c(20, 15), c(23, 13), [])
	await _images(30)
	noeud = s[3]
	_check("sans plafonnier, la même scène est noire : le bot ne voit rien et sa mémoire est vide", not bool(noeud.derniere_vue["vu"]) and not noeud.memoire.connue(noeud._t))
	_fin(s)
	await _images(2)


# ---------------------------------------------------------------------------
# La vue iso
# ---------------------------------------------------------------------------

func _miroir_iso() -> void:
	print("\n[La vue iso : le miroir de lumières 3D]")
	_check("le miroir connaît le type « plafonnier » (la liste des types et la table des énergies)",
		MiroirT.TYPES.has("plafonnier"))
	var miroir: Node3D = MiroirT.new()
	root.add_child(miroir)
	var poids := float((miroir.get("energie_par_type") as Dictionary)["plafonnier"])
	var poids_torche := float((miroir.get("energie_par_type") as Dictionary)["torche"])
	_check("son poids 3D, à l'énergie MAXIMALE d'un plafonnier (%.1f), reste sous celui d'une torche à pleine énergie (%.1f) : un plafonnier ne chasse jamais une torche des huit places"
		% [poids * Plafonnier.INTENSITE_MAX, poids_torche * 2.5], poids * Plafonnier.INTENSITE_MAX < poids_torche * 2.5)
	var main := FauxMain.new()
	root.add_child(main)
	var j1 := FauxJoueur.new(0, _arme)
	var j2 := FauxJoueur.new(1, _arme)
	main.add_child(j1)
	main.add_child(j2)
	main.p1 = j1
	main.p2 = j2
	j1.global_position = c(5, 5)
	j2.global_position = c(6, 5)
	var arene := Node2D.new()
	main.add_child(arene)
	var poses := Plafonnier.poser(arene, [{"case": [5, 6]}, {"case": [8, 6]}, {"case": [10, 6]}, {"case": [250, 6]}])
	await _images(2)
	miroir.call("suivre", main, [])
	var pool: Dictionary = miroir.get("_pool")
	var omnis: Array[OmniLight3D] = []
	for l in pool.values():
		if l is OmniLight3D:
			omnis.append(l)
	_check("deux joueurs côte à côte, quatre plafonniers dont un éteint (7 000 px) : deux lampes 3D (au plus %d par joueur, les plus proches)"
		% MiroirT.PLAFONNIERS_PAR_JOUEUR, omnis.size() == MiroirT.PLAFONNIERS_PAR_JOUEUR, str(omnis.size()))
	var h := Plafonnier.HAUTEUR_TUILES * TUILE
	var tous_hauts := omnis.size() > 0
	for l in omnis:
		tous_hauts = tous_hauts and absf(l.global_position.y - h) < 0.01
	_check("posées à la HAUTEUR de la lampe 2D (52,5 px) : une omni qui flotte au plafond, pas au sol", tous_hauts,
		str(omnis.map(func(l: OmniLight3D) -> float: return l.global_position.y)))
	var proche := pool.get(poses[0].halo.get_instance_id()) as OmniLight3D
	_check("la plus proche des joueurs est de celles-là, à sa place 2D, à sa couleur et à son énergie × le poids du type",
		proche != null and Vector2(proche.global_position.x, proche.global_position.z).is_equal_approx(poses[0].global_position)
		and proche.light_color == poses[0].halo.color
		and is_equal_approx(proche.light_energy, poses[0].halo.energy * float((miroir.get("energie_par_type") as Dictionary)["plafonnier"])))
	_check("un plafonnier au-delà des deux plus proches n'est pas mirroré (reste éclairé en 2D, sans relief)", not pool.has(poses[2].halo.get_instance_id()))
	_check("le plafonnier éteint (loin de tout joueur) n'a pas de lampe 3D", not pool.has(poses[3].halo.get_instance_id()))
	_check("la lampe 3D couvre le disque au sol : sa portée contient le rayon de la lumière 2D (la sphère contient le disque)",
		proche != null and proche.omni_range >= poses[0].rayon_px)
	# Un plafonnier qui s'éteint : sa lampe 3D s'éteint avec lui.
	poses[0].halo.enabled = false
	miroir.call("suivre", main, [])
	_check("un plafonnier qui s'éteint retire sa lampe 3D (le noir absolu tient)", not (miroir.get("_pool") as Dictionary).has(poses[0].halo.get_instance_id()))
	Plafonnier.retirer(arene)
	miroir.call("suivre", main, [])
	_check("retirés de l'arène, plus aucune lampe 3D : le miroir se vide", (miroir.get("_pool") as Dictionary).is_empty())
	miroir.queue_free()
	main.queue_free()
	await _images(2)


func _luminaire_iso() -> void:
	print("\n[La vue iso : le luminaire]")
	var main := FauxMain.new()
	root.add_child(main)
	var arene := Node2D.new()
	main.add_child(arene)
	var j1 := FauxJoueur.new(0, _arme)
	main.add_child(j1)
	j1.global_position = c(5, 5)
	var poses := Plafonnier.poser(arene, [{"case": [5, 6]}, {"case": [250, 6]}])
	await _images(2)
	var volumes := IsoVolumes.new()
	root.add_child(volumes)
	var vus := {}
	volumes.call("_suivre_plafonniers", main, vus)
	var e: Dictionary = volumes.suivi_de(poses[0], 1)
	_check("le plafonnier allumé a son luminaire (deux lueurs : le point franc et le halo doux)",
		not e.is_empty() and String(e["genre"]) == "plafonnier" and (e["noeuds"] as Array).size() == 2, str(e.keys()))
	var point: MeshInstance3D = (e["noeuds"] as Array)[1] if not e.is_empty() else null
	_check("posé au-dessus de sa flaque, à la hauteur de la lampe (52,5 px), à sa place 2D",
		point != null and absf(point.position.y - Plafonnier.HAUTEUR_TUILES * TUILE) < 0.01
		and Vector2(point.position.x, point.position.z).is_equal_approx(poses[0].global_position))
	_check("il est VISIBLE tant que sa lumière brûle", point != null and point.visible)
	_check("le plafonnier éteint (loin de tout joueur) n'a PAS de luminaire : rien ne reste allumé sans sa lumière",
		(volumes.suivi_de(poses[1], 1)).is_empty())
	poses[0].halo.enabled = false
	vus.clear()
	volumes.call("_suivre_plafonniers", main, vus)
	_check("sa lumière éteinte, le luminaire n'est plus dans les entrées vues (le suivi le retirera à la fin de l'image)", not vus.has(IsoVolumes._cle(poses[0], 1)))
	poses[0].halo.enabled = true
	poses[0].halo.energy = 0.0
	vus.clear()
	volumes.call("_suivre_plafonniers", main, vus)
	_check("une énergie nulle : pas de luminaire non plus", not vus.has(IsoVolumes._cle(poses[0], 1)))
	Plafonnier.retirer(arene)
	volumes.queue_free()
	main.queue_free()
	await _images(2)
