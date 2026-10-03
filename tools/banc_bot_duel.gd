## Le banc de JEU du bot — chantier SOLO, étape S4 : de quoi faire s'affronter un bot et un joueur type, en simulation.
##
## Ce fichier est la BIBLIOTHÈQUE du banc (le moteur de duel, le joueur type, les mises en scène, les statistiques) ; il ne
## se lance pas. Trois fichiers s'en servent :
##   • `tools/banc_bot_difficulte.gd`  — le banc : la matrice complète, ses tableaux, ses cibles (long, hors des suites) ;
##   • `tools/test_banc_bot.gd`        — la garde courte des suites : l'ORDRE des difficultés, des bornes larges, le catalogue ;
##   • (à la main) un duel isolé, pour rejouer une graine.
##
## ## Ce que le banc simule — le vrai jeu, pas une maquette
##
## `main.tscn` monté, en entraînement, **vrais corps, vraie physique, vraies balles, vrais sons, vraie lumière** : un duel est un
## morceau de partie, joué à pas d'image fixe (`--fixed-fps 60`, une image = un pas de physique) et DÉTERMINISTE par graine (même
## graine, même duel — la garde le rejoue). Il ne mesure AUCUNE cadence : un banc de jeu simule des parties (consigne d'Adrien).
## Les deux camps « appuient sur les touches » : J1 est le joueur type (`JoueurType`), J2 le bot de la difficulté testée. Le duel
## s'arrête à la PREMIÈRE mort : un duel est un affrontement, pas une série de manches.
##
## **Trois précautions, chacune payée une fois** (ROADMAP, Pièges connus) : le duck des pas est remis à l'heure du JEU (`AudioManager` le
## mesure à l'horloge murale, et le banc tourne douze fois plus vite que le jeu) ; le jeu attend, entre deux duels, que ce que le duel
## d'avant a lancé s'éteigne (`IMAGES_D_ATTENTE`) avant de remettre quoi que ce soit ; et UN SEUL `Duel` par processus (un second
## monterait un second `main.tscn`). Rejouable d'un processus à l'autre (les écarts de 0,02 px d'autrefois étaient le flux du tirage global : voir la quatrième précaution).
## **Et une quatrième, payée le 2026-10-03** : le flux du `randf()`/`randi()` global est reseedé à CHAQUE IMAGE du duel (`_figer_le_tirage`) — le
## jeu tire hors du duel, au rythme d'accumulateurs qu'aucun duel ne remet à zéro, et la graine du gadget du bot en dépend.
## La vue de dessus est le défaut : la simulation y est identique à la vue iso (24 duels comparés), et elle va deux fois plus vite.
##
## ## Le joueur type : honnête lui aussi
##
## Un joueur de référence qui saurait où est le bot dans le noir ne mesurerait rien (il battrait toujours un bot lent). `JoueurType`
## n'est donc PAS un script qui connaît la carte : c'est le même `BotInputProvider` que celui du bot, donc la même perception
## (`PerceptionBotNoeud` : ce que la lumière lui montre, ce que ses oreilles lui donnent — une zone, jamais la place exacte), la même
## mémoire qui s'efface, la même machine à états, les mêmes règles de corps — réglé avec des RÉFLEXES HUMAINS (`profil_humain`) et
## quatre COMPORTEMENTS (`COMPORTEMENTS`), puisqu'un joueur ne joue pas comme un bot : la torche, la posture, l'immobilité, le
## changement de place après un tir. Ce que ça ne prouve pas : un humain cherche mieux qu'un tirage au hasard de cases (il longe
## les murs, il écoute avant d'avancer) — le joueur type est un étalon STABLE et comparable d'un réglage à l'autre, pas un portrait.
##
## ## Le temps de réaction humain de référence
##
## **0,25 s** : le temps de réaction à un signal visuel net, mesuré dans la littérature pour des joueurs entraînés (200 à 300 ms ;
## les tests de réflexes grand public donnent 250 ms de médiane). L'erreur de visée du joueur type — 6° au premier instant, 1,5°
## au mieux après une seconde de visée — est celle d'un joueur qui vise à la souris sans repère. Chiffres de RÉFÉRENCE, non
## mesurés sur un humain de ce jeu : ce que le banc compare, c'est le bot à ce joueur-là.
extends RefCounted

const Profil := preload("res://profil_bot.gd")
const Bot := preload("res://bot_input_provider.gd")
const Nav := preload("res://navigation_bot.gd")
const Memoire := preload("res://memoire_bot.gd")
const Codec := preload("res://map_codec.gd")

const PAS := 1.0 / 60.0

## Les graines des tirages : l'ordre de départ d'un duel est fixé par (carte, graine), jamais par l'horloge.
const GRAINE_BASE := 20261002

## Le temps de réaction humain de référence, en secondes. Voir l'en-tête.
const REACTION_HUMAINE := 0.25
## Le temps de réaction d'un débutant (la mise en scène du catalogue des PNJ) : il n'a jamais vu un joueur éclairé dans le noir.
const REACTION_DEBUTANT := 0.5
## Celui d'un joueur qui vient de finir l'initiation : entre le débutant et l'habitué.
const REACTION_INTERMEDIAIRE := 0.35

## Les quatre comportements du joueur type — chacun est une façon de jouer, pas un niveau : le banc moyenne sur les quatre, et
## montre chacun à part (une difficulté qui n'écraserait que l'un d'eux est un réglage à revoir).
##   • `avance_torche`    — torche allumée, il va de case en case à pleine allure et tire sur ce qu'il voit ou entend ;
##   • `ecoute`           — torche éteinte, immobile : il attend, il écoute, il ne tire que sur ce qu'il situe ;
##   • `accroupi_lent`    — torche éteinte, accroupi (le quart de la vitesse, le pas le plus discret du jeu) ;
##   • `tire_puis_bouge`  — la torche ne brûle que pendant qu'il est ENGAGÉ (il a perçu l'adversaire) ; après chaque rafale il
##                          l'éteint et change de place dans le noir avant de reprendre le combat (l'éclair du tir trahit : ce
##                          qu'on apprend au niveau 0.7 de l'initiation). Première version : torche allumée en permanence — il
##                          courait en pleine lumière, trahi à chaque pas, et ne gagnait que 23 à 27 % de ses duels contre NORMAL
##                          (56 % ensuite) : un étalon qui ne sait pas se cacher ne mesure pas un joueur qui change de place.
const COMPORTEMENTS := {
	"avance_torche": {"torche": true, "accroupi": false, "deplacement": Profil.Deplacement.LIBRE, "relocalise": false},
	"ecoute": {"torche": false, "accroupi": false, "deplacement": Profil.Deplacement.IMMOBILE, "relocalise": false},
	"accroupi_lent": {"torche": false, "accroupi": true, "deplacement": Profil.Deplacement.LIBRE, "relocalise": false},
	"tire_puis_bouge": {"torche": false, "torche_engagee": true, "accroupi": false, "deplacement": Profil.Deplacement.LIBRE, "relocalise": true},
	"avance_sans_torche": COMPORTEMENT_BRUYANT,
}
## Un cinquième comportement, HORS de la moyenne (il n'est pas dans `ORDRE_COMPORTEMENTS`) : `avance_sans_torche` — torche éteinte, à
## pleine allure : un joueur qui ne se cache pas dans le noir et qu'on ENTEND. C'est la situation qui fait tirer le bot sur un son ;
## `test_banc_bot` s'en sert pour prouver que les trois difficultés tirent « si vu ou entendu » dans le vrai jeu, pas seulement sur
## des corps factices.
const COMPORTEMENT_BRUYANT := {"torche": false, "accroupi": false, "deplacement": Profil.Deplacement.LIBRE, "relocalise": false}

## L'ordre d'affichage et de comptage des comportements.
const ORDRE_COMPORTEMENTS := ["avance_torche", "ecoute", "accroupi_lent", "tire_puis_bouge"]

## Combien de temps, après une rafale, le joueur type `tire_puis_bouge` s'éloigne avant de reprendre le combat, en secondes.
const DUREE_RELOCALISATION := 1.5
## Le facteur de vitesse d'un accroupi (`Player.FACTEUR_VITESSE_ACCROUPI`) : recopié pour que le fournisseur ne juge pas « bloqué »
## un corps qui avance bien à son allure.
const FACTEUR_ACCROUPI := 0.25

## Combien de pas de physique on laisse au jeu pour retomber au calme entre deux duels (lumières, immobilisation, effets de mort).
const IMAGES_DE_CALME := 24
## Combien on en laisse AVANT de toucher à quoi que ce soit : ce que le duel d'avant a lancé doit s'éteindre là où il est né. Le
## tintement d'une douille est joué 0,3 à 0,5 s après le tir par un minuteur (`Player._tinter_la_douille`) ; un joueur remis sur
## pied entre-temps le faisait sonner À SA NOUVELLE PLACE, au premier instant du duel suivant — un bot l'entendait, d'un duel à
## l'autre, selon l'instant exact du dernier tir. 60 images = 1 s, le double du plus long minuteur.
const IMAGES_D_ATTENTE := 60


## Le profil de RÉFLEXES du joueur type : ceux d'un joueur humain de référence (voir l'en-tête). Voit, entend, agit, tire — c'est un
## joueur —, la perception de n'importe quel profil (précision auditive 1), mais une mémoire plus longue que celle du bot (8 s) : un
## humain n'oublie pas aussi vite une silhouette entrevue.
static func profil_humain(comportement: Dictionary, reflexes: String = "humain") -> ProfilBot:
	var p := ProfilBot.new()
	p.deplacement = comportement["deplacement"]
	p.allure = 1.0
	p.torche_allumee = bool(comportement["torche"])
	p.voit = true
	p.entend = true
	p.agit = true
	p.tire = true
	p.precision_auditive = 1.0
	p.delai_oubli = 8.0
	# Une ronde, pour les mises en scène où le joueur type doit traverser une salle plutôt que tirer ses cases au hasard.
	for c in comportement.get("points_ronde", []):
		p.points_ronde.append(c as Vector2i)
	if reflexes == "intermediaire":
		# Un joueur qui vient de finir l'initiation : plus vif qu'un débutant, pas encore un habitué du jeu.
		p.delai_reaction = REACTION_INTERMEDIAIRE
		p.erreur_visee_deg = 8.0
		p.erreur_visee_min_deg = 2.5
		p.duree_resserrement = 1.2
		p.vitesse_visee = 8.0
		p.tolerance_tir_deg = 6.0
		p.tirs_par_rafale = 2
		p.pause_entre_rafales = 0.6
		p.audace_zone_px = 80.0
	elif reflexes == "debutant":
		# Un débutant : il met le double à réagir, vise large et tire quand il croit viser juste ; il n'ose pas sur un son vague.
		p.delai_reaction = REACTION_DEBUTANT
		p.erreur_visee_deg = 10.0
		p.erreur_visee_min_deg = 3.0
		p.duree_resserrement = 1.5
		p.vitesse_visee = 6.0
		p.tolerance_tir_deg = 8.0
		p.tirs_par_rafale = 1
		p.pause_entre_rafales = 0.6
		p.audace_zone_px = 60.0
	else:
		p.delai_reaction = REACTION_HUMAINE
		p.erreur_visee_deg = 6.0
		p.erreur_visee_min_deg = 1.5
		p.duree_resserrement = 1.0
		p.vitesse_visee = 10.0
		p.tolerance_tir_deg = 5.0
		p.tirs_par_rafale = 2
		p.pause_entre_rafales = 0.5
		p.audace_zone_px = 100.0
	return p


## Le joueur type : un `BotInputProvider` aux réflexes humains, avec ce qu'un joueur fait et pas un bot — la torche, la posture, le
## changement de place. **Il ne lit toujours jamais l'adversaire** : tout ce qu'il sait vient de son nœud de perception.
class JoueurType extends BotInputProvider:
	var comportement: Dictionary = {}
	var _pause_vue := -INF

	func is_flashlight_pressed() -> bool:
		if bool(comportement.get("torche_engagee", false)):
			return etat != Etat.PATROUILLE
		return bool(comportement.get("torche", false))

	func is_crouch_pressed() -> bool:
		return bool(comportement.get("accroupi", false))

	## Accroupi, le corps avance au quart de sa vitesse : l'anti-blocage du bot compare la distance parcourue à celle d'un corps à
	## pleine marche, et jugerait bloqué un accroupi qui avance bien.
	func avancer(delta: float, position: Vector2, vitesse: float = VITESSE_DE_MARCHE) -> void:
		var v := vitesse * (FACTEUR_ACCROUPI if is_crouch_pressed() else 1.0)
		super.avancer(delta, position, v)

	## Après chaque rafale, `tire_puis_bouge` quitte le combat et marche ailleurs : la machine à états ne peut pas remonter à
	## `COMBAT` avant `DUREE_RELOCALISATION` (le départ du délai de réaction est repoussé), et la patrouille choisit un autre coin.
	func _penser(delta: float, corps: Node2D) -> void:
		super._penser(delta, corps)
		if not bool(comportement.get("relocalise", false)) or perception == null:
			return
		if _pause_jusqu != _pause_vue:
			_pause_vue = _pause_jusqu
			if _pause_jusqu > -INF and etat != Etat.PATROUILLE:
				_entrer_dans(Etat.PATROUILLE, corps)
				_reaction_depuis = perception.maintenant() + DUREE_RELOCALISATION


## Une SALLE, comme celles de l'aventure (16 à 24 cases de côté, une seule pièce) : un sol rectangulaire de `largeur` × `hauteur`
## cases ceint d'un mur plein, le joueur à l'ouest et l'adversaire à l'est. Fabriquée ici, jamais lue d'un fichier : le moteur de
## l'aventure (S6) n'existe pas encore, et le banc ne doit pas dépendre d'un format qu'il ne connaît pas.
static func carte_salle(largeur: int = 22, hauteur: int = 18) -> Dictionary:
	var d := Codec.new_map("salle", Vector2i(largeur + 2, hauteur + 2))
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	for y in hauteur + 2:
		for x in largeur + 2:
			if x == 0 or y == 0 or x == largeur + 1 or y == hauteur + 1:
				murs.append(Vector2i(x, y))
			else:
				sol.append(Vector2i(x, y))
	d["floor"] = Codec.encode_runs(sol)
	d["walls"] = Codec.encode_runs(murs)
	d["spawn_p1"] = {"x": 2, "y": 1 + hauteur / 2}
	d["spawn_p2"] = {"x": largeur - 1, "y": 1 + hauteur / 2}
	return d


## ── La mise en scène du CATALOGUE des PNJ : un débutant entre dans une salle ─────────────────────────────────────────────────
##
## Une salle de `SALLE_L` × `SALLE_H` cases. Le joueur (un DÉBUTANT : réflexes `REACTION_DEBUTANT`, la torche allumée — le pire cas, la
## lampe trahit) entre par l'ouest et balaie la salle par une ronde ; le PNJ attend à l'est, à une hauteur tirée par la graine. Ce que
## le banc lit : si le débutant gagne, combien de temps le PNJ met entre le moment où il perçoit et son premier coup, et ce que le
## débutant reçoit. Un PNJ « très lent » doit laisser à un débutant le temps de réagir ; un PNJ sourd et aveugle ne doit jamais tirer.
const SALLE_L := 22
const SALLE_H := 18
## Les deux façons dont le débutant traverse la salle : debout (ses pas s'entendent), ou accroupi (le pas le plus discret du jeu). Dans
## les deux la torche brûle : sans elle il ne verrait pas le PNJ, et la mise en scène ne mesurerait plus un combat.
const COMPORTEMENTS_DEBUTANT := {
	"debout": {"torche": true, "accroupi": false, "deplacement": Profil.Deplacement.RONDE, "relocalise": false,
		"points_ronde": [Vector2i(18, 9), Vector2i(18, 4), Vector2i(4, 4), Vector2i(4, 15), Vector2i(18, 15)]},
	"accroupi": {"torche": true, "accroupi": true, "deplacement": Profil.Deplacement.RONDE, "relocalise": false,
		"points_ronde": [Vector2i(18, 9), Vector2i(18, 4), Vector2i(4, 4), Vector2i(4, 15), Vector2i(18, 15)]},
}


## Pose la ronde ou la zone d'un PNJ mobile dans la moitié est de la salle : un PNJ du catalogue n'a ni points ni rectangle (c'est
## le niveau qui les donne), et un PNJ de ronde sans points ne bouge pas.
static func poser_dans_la_salle(p: ProfilBot) -> ProfilBot:
	if p.deplacement == Profil.Deplacement.RONDE:
		p.points_ronde.clear()
		for c in [Vector2i(16, 5), Vector2i(20, 5), Vector2i(20, 14), Vector2i(16, 14)]:
			p.points_ronde.append(c)
	elif p.deplacement == Profil.Deplacement.ZONE:
		p.zone = Rect2i(15, 3, 7, 13)
	return p


## Monte le jeu sur la salle.
func monter_la_salle() -> bool:
	return await monter("", carte_salle(SALLE_L, SALLE_H))


## Un duel dans la salle : `pnj` (un ProfilBot du catalogue), `comportement` (`debout` ou `accroupi`), `graine`.
func duel_salle(pnj: ProfilBot, comportement: String, graine: int, duree_max: float = 60.0, reflexes: String = "debutant") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_BASE + graine * 6151
	var dy := rng.randi_range(-4, 4)
	return await duel({
		"profil_bot": poser_dans_la_salle(pnj), "comportement": COMPORTEMENTS_DEBUTANT[comportement], "reflexes": reflexes,
		"graine": graine, "duree_max": duree_max,
		"placement": {
			"joueur": Nav.centre_de_la_case(Vector2i(2, 1 + SALLE_H / 2)), "bot": Nav.centre_de_la_case(Vector2i(SALLE_L - 1, 1 + SALLE_H / 2 + dy)),
			"cap_joueur": 0.0, "cap_bot": PI,
		},
	})


## Un fournisseur muet : les deux corps l'ont entre deux duels, le temps de retomber au calme.
class Muet extends InputProvider:
	pass


## Le joueur type, monté et configuré, prêt à être posé sur un corps.
static func fabriquer_le_joueur(comportement: Dictionary, navigation: NavigationBot, graine: int, reflexes: String = "humain") -> JoueurType:
	var j := JoueurType.new()
	j.name = "JoueurType"
	j.comportement = comportement
	j.configurer(profil_humain(comportement, reflexes), navigation, graine)
	return j


# ---------------------------------------------------------------------------
# LE MOTEUR : le jeu monté, et un duel à la fois
# ---------------------------------------------------------------------------

var arbre: SceneTree
var main: Node = null
var ui: Node = null
var _nav: NavigationBot = null
## Les balles tirées dans le duel en cours, par tireur : [j1, j2]. Un tableau : une lambda capture un entier par COPIE.
var _balles := [0, 0]
## La disposition qui a fait les statistiques : la distance de départ, en pixels, que `placer_au_hasard` vise.
var distance_depart_min := 450.0
var distance_depart_max := 1000.0


func _init(l_arbre: SceneTree) -> void:
	arbre = l_arbre


## Monte le vrai jeu et le met en entraînement sur la carte `id` (un slug ou un identifiant du catalogue de `MapData`), ou, si
## `donnees` n'est pas vide, sur cette carte fabriquée. Rend faux si le jeu ne peut pas se monter.
func monter(id: String = "default", donnees: Dictionary = {}, iso: bool = false) -> bool:
	var reglages := arbre.root.get_node("GameSettings")
	var cartes := arbre.root.get_node("MapData")
	# La vue de dessus par défaut : la SIMULATION est la même (corps, balles, sons, lumière), seuls les visuels voxel changent, et
	# le banc en gagne la moitié de son temps. `--iso` du banc rejoue sous la vue du jeu publié.
	reglages.mode_iso = iso
	if main == null:
		main = (load("res://main.tscn") as PackedScene).instantiate()
		arbre.root.add_child(main)
		for _i in 3:
			await arbre.process_frame
		ui = main.ui
	else:
		main._on_main_menu_requested()
		for _i in 2:
			await arbre.process_frame
	var fabriquee: Dictionary = {}
	if donnees.is_empty():
		if not cartes.select_map(id):
			return false
	else:
		var valide: Dictionary = Codec.validate(donnees)
		if not bool(valide.get("ok", false)):
			push_error("banc_bot_duel : carte fabriquée invalide : %s" % str(valide.get("error", valide)))
			return false
		fabriquee = valide["data"]
	ui.hub.push(ui.SCREEN_TRAINING)
	for _i in 2:
		await arbre.process_frame
	ui._on_hub_action("cran_tireur")
	main.graine_du_bot = GRAINE_BASE
	ui._on_hub_action("entrainement")
	for _i in 3:
		await arbre.process_frame
	if not fabriquee.is_empty():
		# ⚠️ APRÈS le lancement, jamais avant : `_on_training_requested` re-sélectionne la carte choisie à l'écran et écrase
		# `current_map_data`. Posée avant, la carte fabriquée était silencieusement remplacée par celle d'avant (la salle du catalogue
		# tournait sur l'arène standard, ou sur la dernière carte livrée) — c'est ce que `test_bot_combat` fait, dans cet ordre.
		cartes.current_map_data = fabriquee
		main.rebuild_arena()
		for _i in 5:
			await arbre.process_frame
	_nav = Nav.depuis_carte(cartes.get_selected())
	if not fabriquee.is_empty() and String(_nav.carte.get("id", "")) != String(fabriquee.get("id", "")):
		push_error("banc_bot_duel : la carte fabriquée n'est pas celle du jeu monté")
		return false
	_neutraliser_les_corps()
	for _i in IMAGES_DE_CALME:
		await arbre.physics_frame
	return main.training_mode


func _neutraliser_les_corps() -> void:
	for corps in [main.p1, main.p2]:
		_liberer_le_fournisseur(corps)
		var muet := Muet.new()
		corps.input_provider = muet
		corps.add_child(muet)


## Retire SUR-LE-CHAMP le fournisseur d'un corps : un `queue_free()` le laisse vivre jusqu'à la fin de l'image, abonné au signal de
## son — « un `queue_free` laisse les corps dans leur groupe jusqu'à la fin de l'image » (Pièges connus, S3).
func _liberer_le_fournisseur(corps: Node) -> void:
	var f: Variant = corps.get("input_provider")
	if f != null and is_instance_valid(f):
		var n := f as Node
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.free()
	corps.set("input_provider", null)


## Tout ce que le duel d'avant a laissé : balles, traces au sol (sang, éclats, douilles), vie, munitions, posture, torche.
func _remettre_au_calme() -> void:
	_neutraliser_les_corps()
	for _i in IMAGES_D_ATTENTE:
		await arbre.physics_frame
	for b in main.bullet_container.get_children():
		main.bullet_container.remove_child(b)
		b.free()
	for groupe in main.GROUPES_DES_TRACES:
		for n in arbre.get_nodes_in_group(groupe):
			if is_instance_valid(n) and n.get_parent() != null:
				n.get_parent().remove_child(n)
				n.free()
	main._reapparaitre_le_joueur()
	main._reapparaitre_le_bot()
	for corps in [main.p1, main.p2]:
		corps.is_reloading = false
		corps.shoot_cooldown = 0.0
		corps.velocity = Vector2.ZERO
	main._bot_reapparition = -1.0
	main._joueur_reapparition = -1.0
	_rendre_les_reserves()
	for _i in IMAGES_DE_CALME:
		await arbre.physics_frame


## Fige le TIRAGE du jeu pour ce duel : (carte, graine) doit fixer tout ce que le jeu tire au `randf()` / `randi()` GLOBAL — la dispersion
## d'une balle, la hauteur d'une note, **la graine du gadget que pose le bot** (`GameState._poser_gadget` : `randi()`, d'où dépend la forme
## d'onde du Parasite, donc la lumière des torches, donc l'éblouissement, donc tout le duel).
##
## ⚠️ **Un seul `seed()` au départ ne suffit pas** : le jeu tire AUSSI hors des événements du duel, au rythme d'accumulateurs que rien ne
## remet à zéro d'un duel à l'autre — la poussière du faisceau (3 tirages toutes les `DUST_INTERVAL`, `Player._dust_accum`), le minuteur
## d'ambiance (`AudioManager._ambiance_timer`, 7 à 18 s). Leur PHASE à l'entrée du duel décalait le flux de quelques tirages avant la pose
## du gadget : même graine, graine de gadget différente (3567825414 contre 1987688319, mesuré), onde différente, duel différent. Deux
## remèdes, qui valent ensemble : (1) remettre ces accumulateurs à neuf ici ; (2) **reseeder à chaque image** (voir `duel`), si bien
## qu'un accumulateur qu'on ne connaît pas encore ne décale jamais que l'image où il tire, jamais tout le reste du duel.
func _figer_le_tirage() -> void:
	for corps in [main.p1, main.p2]:
		corps.set("_dust_accum", 0.0)
		corps.set("_torch_breath_t", 0.0)
	var audio: Node = arbre.root.get_node("AudioManager")
	var minuteur: Variant = audio.get("_ambiance_timer")
	if minuteur != null and not (minuteur as Timer).is_stopped():
		(minuteur as Timer).start(float((audio.get_script() as Script).get_script_constant_map()["AMBIANCE_ATTENTE_MAX"]))


## La graine du premier gadget que le bot a posé dans le duel en cours (-1 : aucun), lue À LA POSE (`compter`, dans `duel`) et non à la fin.
## ⚠️ Lue à la fin du duel, elle valait -1 dès que le gadget n'était plus debout — et une balle du joueur type le détruit souvent avant
## que le duel finisse : le relevé ne voyait alors plus rien, la garde « même tirage » comparait -1 à -1 et rougissait (S9b, 2026-10-03,
## à l'intégration). Le gadget n'est pas encore dans le groupe « gadgets » quand il entre dans le conteneur (`_ready` joue après
## `child_entered_tree`) : on le reconnaît à son `poseur_id`, que la pose lui donne AVANT l'entrée, comme sa graine.
var _graine_gadget_bot: int = -1


## Remet l'ÉCHELLE d'un corps à exactement 1 et son inclinaison à 0. **Un corps qui bouge ne garde pas la sienne** : `move_and_slide`
## réécrit sa transformation (`set_global_transform`), `Node2D` en RELIT rotation, échelle et inclinaison dans la matrice (en simple
## précision), et chaque relecture arrondit un peu : l'échelle dérive d'un pas (mesuré : 1 → 0,99999905 → 0,9999979 sur le joueur au fil des
## duels, 0,99999994 → 0,9999976 sur le bot dès le premier démarrage). Rien ne la remet à 1 d'un duel à l'autre : le duel rejoué ne repartait
## donc pas du même état, et sa rotation différait d'UN ULP dès la 6e image (2,136379004 contre 2,136378765). Seul, cet écart ne change pas
## l'issue d'un duel (mesuré : traces égales sans ce remède), mais un banc qui REJOUE ne doit pas partir d'un état qui dérive. Pas un défaut du
## jeu qu'on corrige ici : l'écart est de l'ordre du millionième, et `rotation = 0` à chaque manche le cache.
static func redresser_le_corps(corps: Node2D) -> void:
	corps.scale = Vector2.ONE
	corps.skew = 0.0


## Rend aux deux joueurs ce qu'une manche neuve leur rend : la recharge d'une minute du gadget, la batterie de la bobine, la réserve de fusées
## de leur classe (S9). Sans cela, le gadget posé dans un duel manquerait au suivant — un banc d'outils mesurerait une minute de recharge.
func _rendre_les_reserves() -> void:
	for pid in 2:
		var joueur: Node = main.p1 if pid == 0 else main.p2
		main._gadget_attente[pid] = 0.0
		main._gadgets_poses_par[pid] = 0
		main._batterie[pid] = 1.0
		main._fusees_restantes[pid] = main._stock_fusees(joueur)
		main._fusees_accumulateur[pid] = 0.0


## Les cases d'un duel pris au hasard sur la carte montée : le joueur n'importe où, le bot à une distance de départ moyenne de lui
## (ni nez à nez, ni aux deux bouts de la carte : le duel doit se produire en quelques dizaines de secondes). Rend `{}` s'il n'y a pas
## deux cases à cette distance. Les tirages ne dépendent que de la graine : (carte, graine) fixe le duel.
func placer_au_hasard(graine: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE_BASE + graine * 7919
	var depart := _nav.case_praticable_proche(Nav.case_du_monde(main._get_spawn_position(0)))
	var cases := _nav.cases_atteignables(depart)
	if cases.size() < 2:
		return {}
	var a: Vector2i = cases[rng.randi_range(0, cases.size() - 1)]
	var pa := Nav.centre_de_la_case(a)
	var proches: Array[Vector2i] = []
	var plus_loin := a
	var d_max := 0.0
	for c in cases:
		var d := Nav.centre_de_la_case(c).distance_to(pa)
		if d >= distance_depart_min and d <= distance_depart_max:
			proches.append(c)
		if d > d_max:
			d_max = d
			plus_loin = c
	var b: Vector2i = proches[rng.randi_range(0, proches.size() - 1)] if not proches.is_empty() else plus_loin
	return {
		"joueur": pa, "bot": Nav.centre_de_la_case(b),
		"cap_joueur": rng.randf_range(-PI, PI), "cap_bot": rng.randf_range(-PI, PI),
	}


## UN DUEL. `spec` : `profil_bot` (le ProfilBot du bot), `comportement` (un des `COMPORTEMENTS`, ou toute autre table de même forme),
## `reflexes` (« humain » par défaut, « intermediaire » ou « debutant »), `graine`, `duree_max` (secondes), `placement` (`placer_au_hasard`, ou un
## dictionnaire de même forme : `joueur`, `bot`, `cap_joueur`, `cap_bot`). Rend l'enregistrement du duel (`issue`, les instants des
## premiers coups, les tirs et touches de chaque camp, ce qui a déclenché chaque tir du bot…).
func duel(spec: Dictionary) -> Dictionary:
	var graine: int = int(spec.get("graine", 1))
	var duree_max: float = float(spec.get("duree_max", 75.0))
	var placement: Dictionary = spec.get("placement", {})
	if placement.is_empty():
		placement = placer_au_hasard(graine)
	await _remettre_au_calme()
	# Ce que le duel d'avant a laissé DEBOUT (gadgets posés, fusées) : doit être nul — la garde de `test_banc_bot` le lit.
	var restes := arbre.get_nodes_in_group("gadgets").size() + arbre.get_nodes_in_group("fusees").size()
	# Les tirages du jeu (dispersion des balles, sons) repartent de la graine : même graine, même duel.
	seed(GRAINE_BASE + graine * 104729)
	var p1: Node2D = main.p1
	var p2: Node2D = main.p2
	_figer_le_tirage()
	# AVANT de poser les caps : un corps repart d'une échelle EXACTEMENT 1 (voir `redresser_le_corps`).
	redresser_le_corps(p1)
	redresser_le_corps(p2)
	p1.global_position = placement["joueur"]
	p1.rotation = float(placement["cap_joueur"])
	main.graine_du_bot = GRAINE_BASE ^ (graine * 31)
	main._poser_l_adversaire(spec["profil_bot"])
	# S9 : la CLASSE du bot (`classe`, un index du catalogue). Absente : le Parasite, comme à l'entraînement. Sa réserve de fusées et son gadget
	# sont ceux de la classe, rendus pleins.
	# S9b : toujours équipée — la réapparition du bot garde désormais la classe qu'il porte (elle ne rend plus l'index 0), et un duel sans
	# `classe` doit être celui du Parasite même après un duel d'une autre classe dans le même processus.
	p2.equip_weapon(main.weapon_for_index(int(spec.get("classe", 0))))
	_rendre_les_reserves()
	# `--vie=N` du banc (exploration) : la vie du bot, pour mesurer ce qu'un point de vie de plus vaut face à une arme qui n'a pas de quoi tuer en un chargeur.
	# La vie du profil du bot (`ProfilBot.vie`, 100 sauf un boss réglé), sauf l'exploration de `--vie=N`, qui la remplace.
	p2.hp = float(spec["vie"]) if spec.has("vie") else float((spec["profil_bot"] as ProfilBot).vie)
	p2.global_position = placement["bot"]
	p2.rotation = float(placement["cap_bot"])
	p2.velocity = Vector2.ZERO
	p1.reset_step_tracker()
	p2.reset_step_tracker()
	var bot: BotInputProvider = p2.input_provider as BotInputProvider
	bot.reinitialiser()
	_liberer_le_fournisseur(p1)
	var joueur := fabriquer_le_joueur(spec["comportement"], main._navigation_bot, GRAINE_BASE ^ (graine * 17), String(spec.get("reflexes", "humain")))
	p1.input_provider = joueur
	p1.add_child(joueur)

	_balles = [0, 0]
	_graine_gadget_bot = -1
	var compter := func(n: Node) -> void:
		if _graine_gadget_bot == -1 and "poseur_id" in n and "graine" in n and int(n.get("poseur_id")) == int(p2.get("player_id")):
			_graine_gadget_bot = int(n.get("graine"))
		var src: Variant = n.get("source_player")
		if src == p1:
			_balles[0] += 1
		elif src == p2:
			_balles[1] += 1
	main.bullet_container.child_entered_tree.connect(compter)

	var r := {
		"graine": graine, "issue": "nul", "t_fin": duree_max,
		"t_coup_recu": -1.0, "t_coup_donne": -1.0,
		"tirs_bot": 0, "touches_bot": 0, "tirs_joueur": 0, "touches_joueur": 0,
		"tirs_bot_vue": 0, "tirs_bot_son": 0, "tirs_bot_perdu": 0,
		"t_premier_tir_bot": -1.0, "t_premiere_perception_bot": -1.0, "t_premiere_perception_joueur": -1.0,
		"distance_depart": (placement["joueur"] as Vector2).distance_to(placement["bot"]),
		"vues_bot": 0,
		"fusees_bot": 0, "poses_bot": 0, "replis_bot": 0, "bascules_bot": 0,
		"restes_au_depart": restes,
	}
	var hp1 := float(p1.hp)
	var hp2 := float(p2.hp)
	var gachette_avant := false
	var t := 0.0
	# Le DUCK des pas après un tir se mesure, dans `AudioManager`, à l'horloge MURALE (0,3 s). À pas d'image fixe, déroulé à ~700
	# images par seconde, 0,3 s de mur font ~4 s de jeu : après le moindre tir, les pas resteraient étouffés douze fois trop longtemps,
	# et d'autant plus que la machine est rapide — le banc ne serait ni fidèle au jeu ni rejouable d'une machine à l'autre. On le
	# remet donc à l'heure du JEU : à chaque image, le dernier tir est reculé de ce que le jeu a écoulé depuis lui.
	var audio: Node = arbre.root.get_node("AudioManager")
	audio.set("_dernier_tir", -1000.0)
	var t_dernier_tir := -1.0
	var balles_vues := 0
	var image := 0
	while t < duree_max:
		await arbre.physics_frame
		t += PAS
		image += 1
		# Le tirage du jeu repart d'une graine PAR IMAGE : voir `_figer_le_tirage`.
		seed(GRAINE_BASE + graine * 104729 + image * 7907)
		if _balles[0] + _balles[1] != balles_vues:
			balles_vues = _balles[0] + _balles[1]
			t_dernier_tir = t
		if t_dernier_tir >= 0.0:
			audio.set("_dernier_tir", Time.get_ticks_msec() / 1000.0 - (t - t_dernier_tir))
		# Les coups : une perte de vie est une balle de l'autre camp (personne ne se blesse soi-même ici).
		if float(p1.hp) < hp1:
			r["touches_bot"] += 1
			if float(r["t_coup_recu"]) < 0.0:
				r["t_coup_recu"] = t
		if float(p2.hp) < hp2:
			r["touches_joueur"] += 1
			if float(r["t_coup_donne"]) < 0.0:
				r["t_coup_donne"] = t
		hp1 = float(p1.hp)
		hp2 = float(p2.hp)
		# Ce qui a déclenché un tir du bot : au front montant de sa gâchette, ce que sa mémoire tenait.
		var presse := bot.is_shoot_pressed()
		if presse and not gachette_avant and bot.perception != null:
			var vu := bool(bot.perception.derniere_vue.get("vu", false))
			if vu:
				r["tirs_bot_vue"] += 1
			elif bot.perception.memoire.source == Memoire.Source.OUIE:
				r["tirs_bot_son"] += 1
			else:
				r["tirs_bot_perdu"] += 1
		gachette_avant = presse
		# Pour traquer un défaut de déterminisme : la trace du duel, toutes les six images (`spec["trace"]`, un tableau à remplir).
		if spec.has("trace") and int(round(t / PAS)) % 6 == 0:
			(spec["trace"] as Array).append([snappedf(t, 0.001), snappedf(p1.global_position.x, 0.01), snappedf(p1.global_position.y, 0.01),
				snappedf(p2.global_position.x, 0.01), snappedf(p2.global_position.y, 0.01), bot.etat, float(p1.hp), float(p2.hp)])
		if float(r["t_premier_tir_bot"]) < 0.0 and _balles[1] > 0:
			r["t_premier_tir_bot"] = t
		if bot.perception != null:
			if float(r["t_premiere_perception_bot"]) < 0.0 and (bot.perception.pas_vus > 0 or bot.perception.sons_entendus > 0):
				r["t_premiere_perception_bot"] = t
				var zs: Array = bot.perception.zones_recentes
				r["premiere_perception_bot"] = "vue" if bot.perception.pas_vus > 0 else ("son:" + (String(zs[0]["famille"]) if not zs.is_empty() else "?"))
			r["vues_bot"] = bot.perception.pas_vus
		if joueur.perception != null and float(r["t_premiere_perception_joueur"]) < 0.0 \
				and (joueur.perception.pas_vus > 0 or joueur.perception.sons_entendus > 0):
			r["t_premiere_perception_joueur"] = t
		if bool(p1.dead) or bool(p2.dead):
			r["issue"] = "bot" if bool(p1.dead) else "joueur"
			r["t_fin"] = t
			break
	r["tirs_bot"] = _balles[1]
	r["tirs_joueur"] = _balles[0]
	r["fusees_bot"] = bot.fusees_lancees
	r["poses_bot"] = bot.gadgets_poses
	r["replis_bot"] = bot.replis
	r["bascules_bot"] = bot.bascules_gadget
	# La graine du premier gadget posé par le bot, tirée au `randi()` GLOBAL du jeu : elle ne dépend que de (carte, graine) si le tirage
	# est bien figé (voir `_figer_le_tirage`) — la garde de `test_banc_bot` la compare d'un passage à l'autre. Lue à la pose (voir plus haut).
	r["graine_gadget_bot"] = _graine_gadget_bot
	main.bullet_container.child_entered_tree.disconnect(compter)
	return r


# ---------------------------------------------------------------------------
# LES STATISTIQUES
# ---------------------------------------------------------------------------

## Le résumé d'un lot de duels : les quatre grandeurs du banc, et ce qu'il faut pour les lire.
##   • `victoire` : part des duels que le joueur type GAGNE, parmi ceux qui ont une issue ; `nuls` : la part des duels sans issue ;
##   • `premier_coup_recu` : le temps moyen, en secondes, jusqu'au premier coup que le joueur type reçoit (parmi les duels où il
##     en reçoit un) ; `fenetre` : le même, compté depuis la première perception du bot (ce qui retire la recherche, qui ne dépend pas
##     des réflexes) ; `jamais_touche` : la part des duels où il n'en reçoit aucun ;
##   • `tirs_sur_son` : la part des tirs du bot déclenchés sur un son (ni vu ni perdu de vue) ;
##   • `precision` : la part des tirs du bot qui touchent.
static func resumer(records: Array) -> Dictionary:
	var n := records.size()
	var gagnes := 0
	var perdus := 0
	var nuls := 0
	var somme_recu := 0.0
	var n_recu := 0
	var tirs := 0
	var touches := 0
	var son := 0
	var vue := 0
	var perdu := 0
	var somme_fin := 0.0
	var somme_fenetre := 0.0
	var n_fenetre := 0
	var fusees := 0
	var poses := 0
	var replis := 0
	for r in records:
		match String(r["issue"]):
			"joueur":
				gagnes += 1
			"bot":
				perdus += 1
			_:
				nuls += 1
		if float(r["t_coup_recu"]) >= 0.0:
			somme_recu += float(r["t_coup_recu"])
			n_recu += 1
			# La FENÊTRE : du premier instant où le bot perçoit quelque chose au premier coup que le joueur reçoit. Le temps depuis le
			# départ mêle la recherche (qui ne dépend pas des réflexes) et la réaction (qui en dépend) ; la fenêtre ne garde que la seconde.
			var tp := float(r["t_premiere_perception_bot"])
			if tp >= 0.0 and float(r["t_coup_recu"]) >= tp:
				somme_fenetre += float(r["t_coup_recu"]) - tp
				n_fenetre += 1
		tirs += int(r["tirs_bot"])
		touches += int(r["touches_bot"])
		fusees += int(r.get("fusees_bot", 0))
		poses += int(r.get("poses_bot", 0))
		replis += int(r.get("replis_bot", 0))
		son += int(r["tirs_bot_son"])
		vue += int(r["tirs_bot_vue"])
		perdu += int(r["tirs_bot_perdu"])
		somme_fin += float(r["t_fin"])
	var decides := gagnes + perdus
	return {
		"n": n, "gagnes": gagnes, "perdus": perdus, "nuls": nuls,
		"victoire": float(gagnes) / float(decides) if decides > 0 else NAN,
		"nuls_part": float(nuls) / float(maxi(n, 1)),
		"premier_coup_recu": somme_recu / float(n_recu) if n_recu > 0 else NAN,
		"fenetre": somme_fenetre / float(n_fenetre) if n_fenetre > 0 else NAN,
		"jamais_touche": float(n - n_recu) / float(maxi(n, 1)),
		"tirs_bot": tirs,
		"tirs_sur_son": float(son) / float(maxi(son + vue + perdu, 1)),
		"tirs_sur_vue": float(vue) / float(maxi(son + vue + perdu, 1)),
		"precision": float(touches) / float(maxi(tirs, 1)),
		"duree_moyenne": somme_fin / float(maxi(n, 1)),
		"fusees": float(fusees) / float(maxi(n, 1)), "poses": float(poses) / float(maxi(n, 1)), "replis": float(replis) / float(maxi(n, 1)),
	}


## Une grandeur en texte : un pourcentage, ou un tiret quand elle n'existe pas.
static func pct(x: float) -> String:
	return "—" if is_nan(x) else "%3.0f %%" % (100.0 * x)


static func sec(x: float) -> String:
	return "—" if is_nan(x) else "%.1f s" % x
