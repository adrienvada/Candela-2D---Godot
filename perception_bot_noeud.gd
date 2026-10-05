class_name PerceptionBotNoeud
extends Node2D

## L'état de la perception d'un bot, en jeu — chantier SOLO, étape S2. Ce nœud ne fait que percevoir et se souvenir, et le
## montrer (débogage). **Depuis S3, `BotInputProvider` en lit `memoire` et `derniere_vue` pour agir** (tourner, enquêter, tirer) —
## et RIEN d'autre : la frontière de l'honnêteté ci-dessous est ce qui l'autorise.
##
## Il fait trois choses, et le calcul n'est dans aucune :
##   1. à chaque pas de physique, il décrit à `PerceptionBot.voir` ce que la lumière montre du joueur adverse — la liste
##      des LUMIÈRES CONNUES, relue sur les nœuds vivants — et garde ce qui est vu dans la mémoire ;
##   2. il s'abonne à `AudioManager.son_localise` et garde de chaque son entendu une ZONE, jamais la place exacte
##      (`PerceptionBot.ecouter`) ;
##   3. il porte, s'il est demandé (`--perception-bot`), un affichage de débogage.
##
## ## Ce qui entre, et ce qui sort — la frontière de l'honnêteté
##
## Pour décrire la LUMIÈRE, le nœud lit l'état réel de l'adversaire (sa place, sa torche, son éclair, sa posture) : c'est la
## physique de la scène, la même que celle que le moteur de rendu lit, et que le modèle filtre. **Rien de cela ne sort.**
## Ce que le reste du bot lira — `memoire`, `derniere_vue`, `zones_recentes` — ne contient que ce que le modèle a vu (la
## place du corps éclairé, ou de la lampe) ou entendu (une zone décentrée). `test_bot_perception` garde qu'un bot dans le
## noir, derrière un mur ou sourd n'apprend rien de la place de l'adversaire.
##
## ## Sans nom d'autoload
##
## `AudioManager` s'atteint par son chemin (`/root/AudioManager`), à l'exécution : nommer l'autoload ferait compiler ce
## fichier avant qu'il n'existe dans une suite lancée en `--script` (piège du 2026-08-18).

const Percep := preload("res://perception_bot.gd")
const Memoire := preload("res://memoire_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Murs := preload("res://murs_bas.gd")
const Regard := preload("res://regard_duel.gd")
const Portee := preload("res://portee_ecran.gd")
const Charte_ := preload("res://charte.gd")

## Le drapeau de lancement qui montre ce que le bot perçoit : le cadre de son écran, la mémoire, les zones entendues, la
## ligne de vue. Débogage : il force `voit` et `entend` pour l'AFFICHAGE seulement (le nœud travaille sur une copie du
## profil) — le comportement du bot ne change pas. Se passe après `--` comme tous les drapeaux du jeu.
const DRAPEAU_DEBOGAGE := "--perception-bot"

## La hauteur d'une fusée posée (`MursBasRendu.HAUTEUR_FUSEE_AU_SOL`, en tuiles) : recopiée ici pour que ce fichier ne
## charge pas le rendu des murs bas ; `test_bot_perception` la compare à l'original.
const HAUTEUR_FUSEE_AU_SOL_TUILES := 0.15

## Combien de zones entendues on garde pour l'affichage.
const ZONES_GARDEES := 8
## Combien de temps une zone reste affichée, en secondes.
const DUREE_ZONE_AFFICHEE := 1.5

var profil: ProfilBot = null
var monde: Dictionary = {}
var corps: Node2D = null
var memoire: MemoireBot = null
## La dernière vue : `vu`, `dans_le_cadre`, `par`, `position` (voir `PerceptionBot.voir`) — sans plus.
var derniere_vue: Dictionary = {"vu": false, "dans_le_cadre": false, "par": [], "position": Vector2.ZERO}
## Les dernières zones entendues : `centre`, `rayon`, `t`, `famille`.
var zones_recentes: Array[Dictionary] = []
## Combien de sons ont été entendus, et de pas de vue réussis — pour les tests.
var sons_entendus := 0
var pas_vus := 0
## Les lumières décrites au dernier pas (leurs noms, pour le débogage et les tests).
var noms_des_lumieres: Array[String] = []
## Vrai : l'affichage de débogage est monté.
var debogage := false

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _decalage_lisse := Vector2.ZERO
var _cadre: Dictionary = {}
var _abonne := false


## Règle la perception. `carte` : le dictionnaire de `map_codec.gd` ; `le_corps` : le joueur que le bot pilote ;
## `graine` : même graine, mêmes tirages de zone.
func configurer(un_profil: ProfilBot, carte: Dictionary, le_corps: Node2D, graine: int = 0, deboguer: bool = false) -> void:
	profil = un_profil
	monde = Percep.monde_de_la_carte(carte)
	corps = le_corps
	_rng.seed = graine
	memoire = Memoire.new(profil.delai_oubli)
	debogage = deboguer
	name = "Perception"
	# Posé hors de la hiérarchie du corps : l'affichage se dessine en coordonnées du MONDE, et sa propre transformation ne
	# doit rien devoir à celle du joueur (qui tourne).
	top_level = true
	if debogage:
		z_index = 4000
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m


## L'horloge de la perception, en secondes : celle de SA physique, le temps de la mémoire (`MemoireBot`). Le fournisseur d'entrées
## s'y réfère pour dater ses réflexes — un seul temps pour tout ce que le bot sait.
func maintenant() -> float:
	return _t


## Oublie tout : à la mort, à la réapparition (`BotInputProvider.reinitialiser`).
func reinitialiser() -> void:
	if memoire != null:
		memoire.oublier()
	zones_recentes.clear()
	derniere_vue = {"vu": false, "dans_le_cadre": false, "par": [], "position": Vector2.ZERO}
	_decalage_lisse = Vector2.ZERO


func _ready() -> void:
	set_physics_process(true)
	if profil != null and profil.entend:
		var son := get_node_or_null("/root/AudioManager")
		if son != null and son.has_signal("son_localise") and not son.is_connected("son_localise", _sur_un_son):
			son.connect("son_localise", _sur_un_son)
			_abonne = true


func _exit_tree() -> void:
	if _abonne:
		var son := get_node_or_null("/root/AudioManager")
		if son != null and son.is_connected("son_localise", _sur_un_son):
			son.disconnect("son_localise", _sur_un_son)
		_abonne = false


# ---------------------------------------------------------------------------
# OUÏR
# ---------------------------------------------------------------------------

func _sur_un_son(evenement: Dictionary) -> void:
	if profil == null or not profil.entend or not _corps_vivant():
		return
	var zone := Percep.ecouter(evenement, _bot(), monde, _rng, profil.precision_auditive)
	if zone.is_empty():
		return
	sons_entendus += 1
	memoire.noter_son(zone["centre"], zone["rayon"], _t)
	# On garde la ZONE, jamais l'événement : la place exacte du son ne survit pas à cette fonction.
	zones_recentes.append({"centre": zone["centre"], "rayon": zone["rayon"], "t": _t, "famille": zone["famille"]})
	while zones_recentes.size() > ZONES_GARDEES:
		zones_recentes.pop_front()


# ---------------------------------------------------------------------------
# VOIR
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if profil == null or memoire == null:
		return
	_t += delta
	if not _corps_vivant():
		return
	if profil.voit:
		_voir(delta)
	if debogage:
		queue_redraw()


func _voir(delta: float) -> void:
	var bot := _bot()
	# Le regard suit la visée comme celui d'un joueur (`GameState._maj_cameras`) : même lissage, donc même cadre à chaque
	# instant — y compris les ~120 ms où la caméra d'un joueur rattrape un demi-tour.
	var vue := Portee.VUE_UNIQUE
	var vise := Regard.decalage_vise(bot["visee"], Percep.DECALAGE_VISEE, vue, Percep.ZOOM_VUE_UNIQUE)
	_decalage_lisse = Regard.lisser(_decalage_lisse, vise, delta)
	var reglages := {"decalage_lisse": _decalage_lisse}
	_cadre = Percep.cadre_de_vue(bot["position"], bot["visee"], reglages)
	_lire_les_gadgets()
	# Son propre éblouissement, comme un joueur lit son propre écran : un bot que la torche ou l'éclair d'en face aveugle voit moins (S9b).
	var yeux: Variant = corps.get("dazzle_amount")
	monde["ebloui"] = float(yeux) if yeux != null else 0.0
	var adversaire := _adversaire()
	# OMBRES, OM1 (Q81) — l'éblouissement ne cache au bot que le corps qui l'éblouit (`Player.source_du_brouillage`), comme à un joueur.
	# Lu comme le reste de ce nœud lit le corps, sans exiger un `Player` : les corps factices des suites n'ont ni éblouissement
	# (lu à 0 plus haut) ni source, et sans éblouissement la question ne se pose pas. ⚠️ Ce repli ne doit pas cacher la disparition
	# de la méthode chez un vrai joueur : `test_ombres_regles` (OM1) vérifie, sur un vrai corps, qu'un bot ébloui par sa cible le
	# sait et par une vraie fusée non ; `test_aventure_boss`, qu'il en perd alors le corps — et pas ébloui par autre chose.
	var source_vue: Variant = corps.call("source_du_brouillage") if corps.has_method("source_du_brouillage") else null
	monde["ebloui_par_la_cible"] = adversaire != null and source_vue == adversaire
	var lumieres := _lumieres(adversaire)
	noms_des_lumieres.clear()
	for l in lumieres:
		noms_des_lumieres.append(String(l["nom"]))
	if adversaire == null:
		derniere_vue = {"vu": false, "dans_le_cadre": false, "par": [], "position": Vector2.ZERO}
		return
	var cible := {"position": adversaire.global_position, "accroupi": bool(adversaire.get("accroupi"))}
	derniere_vue = Percep.voir(bot, cible, lumieres, monde, reglages)
	if derniere_vue["vu"]:
		pas_vus += 1
		memoire.noter_vue(derniere_vue["position"], _t)


## Le bot, tel que le modèle le voit : sa place, son identité (pour filtrer ses propres sons), sa posture, sa visée.
func _bot() -> Dictionary:
	return {
		"position": corps.global_position,
		"id": int(corps.get("player_id")),
		"accroupi": bool(corps.get("accroupi")),
		"visee": corps.global_transform.x.normalized(),
	}


func _corps_vivant() -> bool:
	return corps != null and is_instance_valid(corps) and not bool(corps.get("dead"))


## L'adversaire : l'autre joueur du groupe, présent et vivant. `null` s'il n'y en a pas (la cible immobile, hors jeu).
##
## **Jamais un PNJ de l'aventure** (SOLO, S6) : une salle en porte plusieurs, tous dans le groupe `players`, et « le premier autre joueur
## du groupe » aurait pu être le voisin — un PNJ qui aurait guetté, vu et tiré sur un autre PNJ, au lieu du joueur. L'adversaire d'un
## PNJ est le joueur humain, et lui seul ; celui du bot de l'entraînement, J1, l'est toujours (aucun des deux n'est un PNJ).
func _adversaire() -> Node2D:
	for n in get_tree().get_nodes_in_group("players"):
		if n != corps and n is Node2D and is_instance_valid(n) and (n as Node2D).visible and not bool(n.get("dead")) \
				and n.get("est_pnj") != true:
			return n
	return null


## Ce que le modèle sait des gadgets posés (S9) — voir « Ce qu'on laisse dehors » dans `perception_bot.gd`. Trois cas, et le doute va du côté
## du noir :
##   • un gadget en VOLUME (il porte une `opacite` : la suie, la poussière — `GadgetVolume`, que ce fichier ne peut pas nommer : il doit se
##     charger en `--script`) efface ce qui s'y tient : le modèle ne sait pas le rendre, le bot est
##     AVEUGLE par la lumière tant qu'il en est un de posé (il entend toujours) ;
##   • un gadget qui porte un OCCLUDER (`occulte_la_lumiere` : le voile, l'ombre habitée, le leurre, la torche fantôme) est un mur mince :
##     son polygone d'ombre, tel que le moteur le lit, entre dans `monde["obstacles"]`. S'il n'en a pas su donner un — un gadget d'un genre
##     que ce code ne connaît pas —, le bot est AVEUGLE : voir moins que la lumière est le seul parti honnête ;
##   • les autres (la mine, la nappe de braises, la poudre, le grésillement) ne bouchent ni n'étouffent rien : leur effet sur une lampe est
##     déjà dans l'énergie qu'elle rend (`_lampe_brule`). Leur lumière propre (le flash, les braises), le modèle ne la connaît pas : il voit
##     moins, jamais plus.
func _lire_les_gadgets() -> void:
	var aveugle := false
	var obstacles: Array = []
	for g in get_tree().get_nodes_in_group("gadgets"):
		if not is_instance_valid(g) or (g as Node).is_queued_for_deletion():
			continue
		# ⚠️ Pas `has_method("occultation_pour")` : le SOCLE de tous les gadgets la définit (elle rend 0), et chaque gadget serait un volume.
		if g.get("opacite") != null:
			aveugle = true
			continue
		if not bool(g.get("occulte_la_lumiere")):
			continue
		var polygones := _polygones_d_ombre(g as Node)
		if polygones.is_empty():
			aveugle = true
		obstacles.append_array(polygones)
	monde["aveugle"] = aveugle
	monde["obstacles"] = obstacles


## Les polygones d'ombre d'un gadget, en coordonnées du MONDE : chaque `LightOccluder2D` enfant (la bande du voile, la plaque de l'ombre
## habitée, le disque d'une torche fantôme, le disque de torse d'un leurre) et, pour le leurre, son étoile — qui n'est plus un enfant direct,
## elle vit dans sa propre canvas (`EtoileDeCorps`) : on prend l'étoile que le leurre garde dans SON repère. Vide si rien n'est lisible.
func _polygones_d_ombre(g: Node) -> Array:
	var sortie: Array = []
	var xf: Transform2D = (g as Node2D).global_transform if g is Node2D else Transform2D.IDENTITY
	for enfant in g.get_children():
		if enfant is LightOccluder2D and (enfant as LightOccluder2D).occluder != null:
			var occ := enfant as LightOccluder2D
			var poly := occ.occluder.polygon
			if poly.size() >= 3:
				sortie.append(occ.global_transform * poly)
	var etoile: Variant = g.get("_etoile")
	if etoile is PackedVector2Array and (etoile as PackedVector2Array).size() >= 3:
		sortie.append(xf * (etoile as PackedVector2Array))
	return sortie


# ---------------------------------------------------------------------------
# LES LUMIÈRES CONNUES, relues sur les nœuds vivants
# ---------------------------------------------------------------------------

func _hauteur(joueur: Node) -> float:
	return Murs.hauteur_de_posture(bool(joueur.get("accroupi")))


## La lampe d'un joueur brûle-t-elle assez pour trahir ? Allumée ET à plus de `PART_LAMPE_MIN` de sa pleine énergie : elle
## s'allume, s'éteint, grésille et respire — un filet ne trahit pas.
func _lampe_brule(joueur: Node) -> bool:
	var lampe = joueur.get("flashlight")
	if lampe == null or not (lampe is Light2D):
		return false
	return (lampe as Light2D).enabled and (lampe as Light2D).energy >= Percep.PART_LAMPE_MIN * 2.5


## Le rayon d'une lumière peinte, en pixels de monde : la largeur de sa texture × son échelle, sur deux.
func _rayon_de(lumiere: Light2D) -> float:
	if lumiere == null or lumiere.texture == null:
		return 0.0
	return float(lumiere.texture.get_width()) * float((lumiere as PointLight2D).texture_scale) * 0.5


## Une lumière ronde allumée, en entrée du modèle — ou rien si elle ne brûle pas assez.
func _disque(nom: String, lumiere: Light2D, hauteur: float, energie_min: float, source_vue: bool = false) -> Array:
	if lumiere == null or not lumiere.enabled or lumiere.energy < energie_min:
		return []
	var r := _rayon_de(lumiere) * Percep.FRACTION_DISQUE
	if r <= 0.0:
		return []
	return [Percep.lumiere_disque(nom, lumiere.global_position, r, hauteur, false, source_vue)]


## La liste des lumières que le modèle connaît, au pas de physique courant.
##
##   • la TORCHE du bot (un cône) ; son HALO de proximité (il révèle l'ennemi collé à soi : « ma lueur ne me trahit pas »
##     est une règle de l'ADVERSAIRE, le halo du bot, lui, l'éclaire — `CanauxLumiere.canal_de_vue`) ; son ÉCLAIR de tir ;
##   • la LAMPE de la cible, quand sa torche brûle : elle est trahie à sa lampe ; son ÉCLAIR de tir, qui éclaire son corps ;
##   • les FUSÉES posées et allumées ;
##   • les PLAFONNIERS allumés (S5, groupe « plafonniers ») : un disque de plus, qui déclare sa vraie hauteur — un mur bas ne le
##     coupe que par la géométrie de cette hauteur, comme le shader.
##
## ⚠️ Laissées DEHORS, pour voir moins que la lumière : la rétrodiffusion, le faisceau dans l'air, la torche de la cible
## sur ce qu'elle éclaire, les fusées en vol, les gadgets en volume (le bot est alors aveugle, voir `_lire_les_gadgets`).
func _lumieres(adversaire: Node2D) -> Array:
	var sortie: Array = []
	var tuile := Percep.Tuiles.TILE_SIZE.x
	# La torche du bot : un cône, posé à sa lampe (la lumière part de la lentille, pas du centre du corps).
	if _lampe_brule(corps) and corps.get("current_weapon") != null:
		var lampe := corps.get("flashlight") as Light2D
		sortie.append(Percep.lumiere_cone("torche_du_bot", lampe.global_position, corps.global_transform.x,
			_hauteur(corps), corps.get("current_weapon")))
	sortie.append_array(_disque("halo_du_bot", corps.get("ambient_light") as Light2D, _hauteur(corps), 0.2))
	sortie.append_array(_disque("eclair_du_bot", corps.get("muzzle_flash") as Light2D, _hauteur(corps), 0.3))
	if adversaire != null:
		if _lampe_brule(adversaire):
			var lampe_adv := adversaire.get("flashlight") as Light2D
			sortie.append(Percep.lumiere_lampe("lampe_de_la_cible", lampe_adv.global_position, _hauteur(adversaire)))
		# `source_vue` : ébloui, le bot ne distingue plus le corps que cet éclair éclaire, mais il voit l'éclair (S9b).
		sortie.append_array(_disque("eclair_de_la_cible", adversaire.get("muzzle_flash") as Light2D,
			_hauteur(adversaire), 0.3, true))
	for f in get_tree().get_nodes_in_group("fusees"):
		if not is_instance_valid(f) or not f.has_method("est_allumee_au_sol") or not f.est_allumee_au_sol():
			continue
		if f.has_method("energie_relative") and f.energie_relative() < 0.1:
			continue
		var halo := (f as Node).get_node_or_null("Halo") as Light2D
		if halo == null or not halo.enabled:
			continue
		sortie.append_array(_disque("fusee", halo, HAUTEUR_FUSEE_AU_SOL_TUILES * float(tuile), 0.0))
	sortie.append_array(_plafonniers())
	return sortie


## Les plafonniers (S5) : un disque par plafonnier ALLUMÉ, de la hauteur et du rayon de la LUMIÈRE vivante — jamais de ses
## paramètres de pose : le modèle lit ce que le moteur dessine. Un plafonnier éteint (loin de tout joueur, voir
## `Plafonnier.doit_etre_allume`) n'éclaire personne et n'entre pas : voir moins que la lumière, jamais plus. Une énergie sous
## `Plafonnier.INTENSITE_MIN` n'entre pas non plus : le banc n'a éprouvé le rayon retenu que sur la plage permise.
func _plafonniers() -> Array:
	var sortie: Array = []
	for p in get_tree().get_nodes_in_group(Plafonnier.GROUPE):
		if not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
			continue
		var halo := (p as Node).get_node_or_null("Halo") as PointLight2D
		if halo == null or not halo.enabled or halo.energy < Plafonnier.INTENSITE_MIN or halo.height <= 0.0:
			continue
		var r := _rayon_de(halo) * Percep.FRACTION_PLAFONNIER
		if r <= 0.0:
			continue
		sortie.append(Percep.lumiere_disque(String((p as Node).name), halo.global_position, r, halo.height, true))
	return sortie


# ---------------------------------------------------------------------------
# LE DÉBOGAGE
# ---------------------------------------------------------------------------

## Ce que le bot perçoit, en coordonnées du monde : le cadre de son écran (ce qu'un joueur verrait depuis sa place), la
## ligne de vue quand il voit, la mémoire (un cercle qui s'efface avec la confiance), les zones entendues.
func _draw() -> void:
	if not debogage or memoire == null or not _corps_vivant():
		return
	if not _cadre.is_empty():
		var c: Vector2 = _cadre["centre"]
		var d: Vector2 = _cadre["demi"]
		var a := -deg_to_rad(float(_cadre["lacet"]))
		var coins := PackedVector2Array()
		for k in [Vector2(-d.x, -d.y), Vector2(d.x, -d.y), Vector2(d.x, d.y), Vector2(-d.x, d.y), Vector2(-d.x, -d.y)]:
			coins.append(c + (k as Vector2).rotated(a))
		draw_polyline(coins, Color(Charte_.ACIER, 0.35), 3.0)
	var ici := corps.global_position
	if bool(derniere_vue.get("vu", false)):
		var p: Vector2 = derniere_vue["position"]
		draw_line(ici, p, Color(Charte_.HALOGENE, 0.8), 3.0)
		draw_arc(p, 26.0, 0.0, TAU, 24, Color(Charte_.HALOGENE, 0.9), 4.0)
	for z in zones_recentes:
		var age := _t - float(z["t"])
		if age > DUREE_ZONE_AFFICHEE:
			continue
		var alpha := 0.7 * (1.0 - age / DUREE_ZONE_AFFICHEE)
		draw_arc(z["centre"], float(z["rayon"]), 0.0, TAU, 40, Color(Charte_.AMBRE, alpha), 3.0)
	if memoire.connue(_t):
		var conf := memoire.confiance(_t)
		var teinte := Charte_.HALOGENE if memoire.source == Memoire.Source.VUE else Charte_.ROUGE
		var m: Vector2 = memoire.position
		draw_arc(m, maxf(memoire.rayon_a(_t), 10.0), 0.0, TAU, 40, Color(teinte, 0.15 + 0.6 * conf), 2.0)
		draw_line(m + Vector2(-8, 0), m + Vector2(8, 0), Color(teinte, 0.4 + 0.5 * conf), 3.0)
		draw_line(m + Vector2(0, -8), m + Vector2(0, 8), Color(teinte, 0.4 + 0.5 * conf), 3.0)
