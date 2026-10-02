class_name AventurePartie
extends Node

## Le MOTEUR de l'aventure — chantier SOLO, étape S6 : une partie d'aventure, de la première salle d'un chapitre à son boss.
##
## Il charge un niveau (la carte, les plafonniers, le joueur, les PNJ), regarde la salle se jouer, et décide de la suite :
##
##   • **tous les PNJ morts → la salle est gagnée** : un court délai (on voit tomber le dernier), puis le carton de la salle
##     suivante ; à la fin du dixième — le boss — le chapitre est gagné, sa classe est débloquée, on revient à l'écran de l'aventure ;
##   • **le joueur mort → on recommence LA SALLE** (pas le chapitre) : tous les PNJ remis à leur départ, la carte et les plafonniers
##     inchangés. Pas de manche, pas de killcam, pas de score ;
##   • **la pause** et « quitter » sont ceux de l'entraînement : `GameState._on_main_menu_requested` démonte la partie (`demonter`).
##
## Rien de classé : aucun forfait, rien dans `match_history.json`, aucun ELO ; rien ne transite sur le réseau (`protocol.gd` n'a pas
## bougé, aucun RPC, aucun `if transport == …`).
##
## ## Les PNJ sont de VRAIS joueurs
##
## Chacun est un `Player` (`PNJ_<i>`, `player_id` 1, `est_pnj` vrai) piloté par un `BotInputProvider` (`BotPNJ_<i>`) au profil du
## catalogue que dit le niveau (`ProfilBot.pnj_nomme`) ou au profil du boss. Il subit les règles du joueur : vitesse, murs, balles,
## munitions, recharge. Sa perception ne vise QUE le joueur humain (`PerceptionBotNoeud._adversaire` ignore les PNJ) ; ses balles
## traversent les autres PNJ et il ne les blesse pas (`Player.take_damage`) — une même équipe, décidé le geste le plus simple.
## `GameState.figurants` les liste : la vue iso (`Presentation3D`) leur donne un corps chacun.
##
## ## Le carton, et ce qui fige le monde
##
## À chaque salle (la première, la suivante, une reprise) un carton couvre l'écran (`AventureCarton`) le temps `DUREE_CARTON`. Pendant
## ce temps `GameState.countdown_left` est positif : comme au décompte d'une manche, plus aucun `Player` ne bouge, ne vise ni ne tire
## — ni le joueur ni les PNJ. Au retrait du carton chaque bot repart d'une mémoire vide.
##
## ## Le temps
##
## Tout se compte dans `_physics_process`, à pas de physique : sous `--fixed-fps 60` une suite simule la partie image par image, et
## la pause (l'arbre en pause) la gèle sans rien de plus.

const FormatT := preload("res://aventure_format.gd")
const ProgressionT := preload("res://aventure_progression.gd")
const CartonT := preload("res://aventure_carton.gd")

## La salle gagnée (`chapitre`, `index` de 0), la salle recommencée, le chapitre fini — pour les suites et pour qui voudra s'y accrocher.
signal salle_gagnee(chapitre: int, index: int)
signal salle_recommencee(chapitre: int, index: int)
signal chapitre_termine(chapitre: int)

enum Phase { CARTON, JEU, SALLE_GAGNEE, JOUEUR_ABATTU, CHAPITRE_FINI }

## Chiffres de DÉPART : jugés par personne (« jamais joué »), à régler en jouant.
## Le carton d'une salle, en secondes — assez pour lire une phrase, pas pour s'impatienter.
const DUREE_CARTON := 2.4
## Après le dernier PNJ abattu : le temps de voir la salle vide, avant le carton suivant.
const DELAI_APRES_VICTOIRE := 1.4
## Après la mort du joueur : le temps que l'effet de mort se joue, avant la reprise.
const DELAI_APRES_MORT := 1.8
## Le carton de fin de chapitre.
const DUREE_CARTON_FIN := 3.4

## `GameState`, et ce qu'on lui demande : voir `GameState.aventure_*`.
var jeu: Node = null
var chapitre: Dictionary = {}
var index := 0
var classe_slug := ""
var progression: AventureProgression = null
var phase: int = Phase.CARTON
## Les PNJ de la salle en cours, dans l'ordre du niveau.
var pnj: Array[Player] = []
## Combien de fois la salle en cours a été commencée (1 : la première fois).
var essais := 1
## Combien de fois le joueur est tombé depuis le début de la partie.
var morts := 0
## Les salles gagnées depuis le début de la partie (une reprise ne recompte pas).
var salles_gagnees := 0
## Vrai dès que le chapitre est fini ; la partie attend alors le retour à l'écran de l'aventure.
var chapitre_fini := false

var _t := 0.0
var _carton: AventureCarton = null
var _rng := RandomNumberGenerator.new()
## La carte qui était choisie avant la partie, rendue au retour : l'aventure ne change pas le choix du joueur dans la galerie.
var _carte_avant := ""
var _demontee := false


## Commence une partie. `jeu` : `GameState`. `chapitre` : un chapitre CHARGÉ (`AventureFormat.charger_chapitre`). `index` : la salle
## de départ (de 0). `classe` : le slug de la classe du joueur — celle que le chapitre impose, si elle l'est (`classe_pour_jouer`).
## Rend faux si la salle ne se pose pas.
func demarrer(un_jeu: Node, un_chapitre: Dictionary, un_index: int, une_classe: String, une_progression: AventureProgression = null) -> bool:
	name = "Aventure"
	jeu = un_jeu
	chapitre = un_chapitre
	index = un_index
	classe_slug = une_classe
	progression = une_progression if une_progression != null else ProgressionT.new()
	if chapitre.is_empty() or index < 0 or index >= (chapitre["niveaux"] as Array).size():
		push_error("AventurePartie : pas de salle %d dans ce chapitre" % index)
		return false
	if _index_de_classe(classe_slug) < 0:
		push_error("AventurePartie : classe inconnue « %s »" % classe_slug)
		return false
	# Les mêmes règles que l'écran, tenues ICI aussi : une partie lancée par le code (une suite, un futur raccourci) n'a pas le droit
	# de jouer ce que l'écran refuserait — une salle fermée, une classe qu'on n'a pas gagnée, une autre que celle qu'un chapitre prête.
	var chap := int(chapitre["numero"])
	if not progression.niveau_ouvert(chap, index):
		push_error("AventurePartie : la salle %d.%d est fermée (la précédente n'est pas réussie)" % [chap, index + 1])
		return false
	var imposee := String(chapitre["classe_imposee"])
	if imposee != "" and classe_slug != imposee:
		push_error("AventurePartie : le chapitre %d se joue dans « %s » (reçu « %s »)" % [chap, imposee, classe_slug])
		return false
	if imposee == "" and not progression.classe_debloquee(classe_slug):
		push_error("AventurePartie : la classe « %s » n'est pas débloquée" % classe_slug)
		return false
	_carte_avant = String(MapData.selected_map_id)
	if _carte_avant == MapData.ID_AVENTURE:
		_carte_avant = MapData.DEFAULT_MAP_ID
	_carton = CartonT.new()
	jeu.add_child(_carton)
	_rng.seed = int(jeu.graine_du_bot) if int(jeu.graine_du_bot) >= 0 else randi()
	return _poser_la_salle()


## Le niveau en cours, tel que `AventureFormat.preparer_niveau` le rend.
func niveau() -> Dictionary:
	return (chapitre["niveaux"] as Array)[index]


func _index_de_classe(slug: String) -> int:
	var classes: Array = jeu.classes()
	for i in classes.size():
		if String((classes[i] as ClassData).slug()) == slug:
			return i
	return -1


# ---------------------------------------------------------------------------
# POSER UNE SALLE
# ---------------------------------------------------------------------------

## (Re)construit la salle `index` : l'arène, les plafonniers, le joueur à sa case, des PNJ NEUFS à leur départ, puis le carton.
## C'est aussi la reprise après une mort : « tous les PNJ remis à leur départ, plafonniers et carte inchangés » — la carte et les
## plafonniers sont ceux du même niveau, relus ; les PNJ sont des corps neufs, de profils neufs.
func _poser_la_salle() -> bool:
	var n := niveau()
	_retirer_les_pnj()
	var etiquette := "%d.%d · %s" % [int(chapitre["numero"]), index + 1, String(n["titre"])]
	if not bool(jeu.aventure_poser_la_salle(n, _index_de_classe(classe_slug), etiquette)):
		return false
	# Les plafonniers APRÈS l'arène : `rebuild_arena` ne connaît pas leur conteneur, `poser` retire celui d'avant (idempotente).
	Plafonnier.poser(jeu.arena, n["plafonniers"])
	_creer_les_pnj(n)
	jeu.figurants = pnj
	phase = Phase.CARTON
	_t = 0.0
	var total := (chapitre["niveaux"] as Array).size()
	_carton.montrer("CHAPITRE %d  ·  SALLE %d / %d%s" % [int(chapitre["numero"]), index + 1, total,
		"  ·  BOSS" if bool(n["boss"]) else ("  ·  ESSAI %d" % essais if essais > 1 else "")],
		String(n["titre"]), String(n["intention"]))
	jeu.countdown_left = DUREE_CARTON
	return true


func _creer_les_pnj(n: Dictionary) -> void:
	var navigation := NavigationBot.depuis_carte(n["carte"])
	var entrees: Array = n["pnj"]
	for i in entrees.size():
		var e: Dictionary = entrees[i]
		var p: Player = jeu.player_scene.instantiate()
		p.name = "PNJ_%d" % i
		p.player_id = 1
		p.est_pnj = true
		var bot := BotInputProvider.new()
		bot.name = "BotPNJ_%d" % i
		bot.configurer(FormatT.profil_du_pnj(e), navigation, _rng.randi())
		# Le fournisseur posé AVANT l'entrée dans l'arbre : `Player._ready` ne fabrique pas un fournisseur local qu'il faudrait
		# libérer aussitôt.
		p.input_provider = bot
		p.add_child(bot)
		jeu.players_node.add_child(p)
		p.set_multiplayer_authority(1)
		var classe_pnj := _index_de_classe(String(e["classe"]))
		p.equip_weapon(jeu.weapon_for_index(classe_pnj if classe_pnj >= 0 else 0))
		p.global_position = NavigationBot.centre_de_la_case(e["case"])
		p.rotation = float(e["rotation"])
		p.hp = 100.0
		p.reset_step_tracker()
		p.reset_flashlight_latch()
		p.reset_posture()
		pnj.append(p)


## Retire les PNJ de la salle d'avant — TOUT DE SUITE : un `queue_free()` les laisserait dans le groupe `players` jusqu'à la fin de
## l'image, et le bot de la salle suivante (ou la perception d'un autre) les prendrait pour un joueur (« Pièges connus »).
func _retirer_les_pnj() -> void:
	for p in pnj:
		if is_instance_valid(p):
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			p.queue_free()
	pnj.clear()
	if jeu != null:
		jeu.figurants = pnj


# ---------------------------------------------------------------------------
# LA SALLE SE JOUE
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _demontee or jeu == null:
		return
	_t += delta
	match phase:
		Phase.CARTON:
			_regler_le_carton(DUREE_CARTON)
			if _t >= DUREE_CARTON:
				_commencer_a_jouer()
		Phase.JEU:
			_regarder_la_salle()
		Phase.SALLE_GAGNEE:
			if _t >= DELAI_APRES_VICTOIRE:
				_salle_suivante()
		Phase.JOUEUR_ABATTU:
			if _t >= DELAI_APRES_MORT:
				recommencer_la_salle()
		Phase.CHAPITRE_FINI:
			_regler_le_carton(DUREE_CARTON_FIN)
			if _t >= DUREE_CARTON_FIN:
				_retour_a_l_ecran()
	_ranger_les_morts()


func _regler_le_carton(duree: float) -> void:
	jeu.countdown_left = maxf(duree - _t, 0.0)
	_carton.regler(1.0 - _t / duree)


## Le carton se retire, le monde se remet en marche : chaque bot repart d'une mémoire vide (il n'a rien perçu, il était figé).
func _commencer_a_jouer() -> void:
	jeu.countdown_left = 0.0
	_carton.cacher()
	for p in pnj:
		if is_instance_valid(p) and p.input_provider is BotInputProvider:
			(p.input_provider as BotInputProvider).reinitialiser()
	phase = Phase.JEU
	_t = 0.0


## Un tour de garde : le joueur est-il tombé ? tous les PNJ le sont-ils ? Le joueur d'abord : s'ils tombent ensemble, la salle est
## perdue — il n'y a pas de victoire d'un mort.
func _regarder_la_salle() -> void:
	if bool(jeu.p1.dead):
		morts += 1
		phase = Phase.JOUEUR_ABATTU
		_t = 0.0
		return
	if _tous_morts():
		phase = Phase.SALLE_GAGNEE
		_t = 0.0


func _tous_morts() -> bool:
	if pnj.is_empty():
		return false
	for p in pnj:
		if is_instance_valid(p) and not bool(p.dead):
			return false
	return true


## Un PNJ abattu n'est plus ni un corps ni un obstacle : `Player.die()` cache ses sprites et éteint ses lampes, mais ne touche pas à
## sa collision — un cadavre invisible arrêterait les balles et bloquerait le passage. Il sort du jeu, et reste dans le groupe
## (la présentation iso lit `visible`).
func _ranger_les_morts() -> void:
	for p in pnj:
		if is_instance_valid(p) and bool(p.dead) and p.visible:
			p.set_collision_layer_value(1, false)
			p.set_collision_mask_value(1, false)
			p.hide()


## Recommence la salle en cours — la mort du joueur. Public : les suites s'en servent aussi.
func recommencer_la_salle() -> void:
	essais += 1
	var chap := int(chapitre["numero"])
	if _poser_la_salle():
		salle_recommencee.emit(chap, index)


func _salle_suivante() -> void:
	var chap := int(chapitre["numero"])
	var total := (chapitre["niveaux"] as Array).size()
	progression.reussir_niveau(chap, index)
	salles_gagnees += 1
	salle_gagnee.emit(chap, index)
	if index + 1 < total:
		index += 1
		essais = 1
		_poser_la_salle()
		return
	# Le boss est tombé : le chapitre est fini, sa classe est à nous.
	progression.terminer_chapitre(chap)
	chapitre_fini = true
	phase = Phase.CHAPITRE_FINI
	_t = 0.0
	var classe := FormatT.classe_du_chapitre(chap)
	var libelle := _libelle_de_la_classe(classe)
	_carton.montrer("CHAPITRE %d  ·  TERMINÉ" % chap, String(chapitre["titre"]),
		("%s est à vous. Choisissez-la, à l'écran de l'aventure." % libelle) if classe != "" else "")
	jeu.countdown_left = DUREE_CARTON_FIN
	chapitre_termine.emit(chap)


func _libelle_de_la_classe(slug: String) -> String:
	for c in jeu.classes():
		if String((c as ClassData).slug()) == slug:
			return String((c as ClassData).libelle)
	return slug


## Le chapitre est fini : retour à l'écran de l'aventure, par le chemin du retour au menu (qui démonte cette partie).
func _retour_a_l_ecran() -> void:
	jeu.aventure_finie()


# ---------------------------------------------------------------------------
# DÉMONTER
# ---------------------------------------------------------------------------

## Rend le jeu comme il était : les PNJ retirés (tout de suite), les plafonniers retirés, le carton parti, la carte du joueur rendue.
## Appelée par `GameState._quitter_l_aventure` — retour au menu, ou départ d'un duel ou d'un entraînement.
func demonter() -> void:
	if _demontee:
		return
	_demontee = true
	_retirer_les_pnj()
	if jeu != null and is_instance_valid(jeu.arena):
		Plafonnier.retirer(jeu.arena)
	if is_instance_valid(_carton):
		if _carton.get_parent() != null:
			_carton.get_parent().remove_child(_carton)
		_carton.queue_free()
	_carton = null
	if _carte_avant != "":
		MapData.select_map(_carte_avant)
	if jeu != null:
		jeu.countdown_left = 0.0
