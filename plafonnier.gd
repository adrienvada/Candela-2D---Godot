class_name Plafonnier
extends Node2D

## Le plafonnier — chantier SOLO, étape S5 (2026-10-02).
##
## Adrien : « Les lumières fixes ne s'éteignent pas. Ce sont des plafonniers. Il faut les implémenter. » Une lumière POSÉE,
## PERMANENTE et INDESTRUCTIBLE, qui dessine au sol une flaque de lumière cernée de noir. Elle n'a ni cône, ni
## éblouissement, ni bouton : pas de collision, pas de vie, rien que la balle, le pas ou le gadget puisse éteindre.
##
## ## Trois rôles qui ne valent qu'ENSEMBLE
##
##   1. **Il MONTRE les corps qui s'y tiennent** — au joueur comme à la vue iso, par les capteurs (`CapteurCorps`) : la portée
##      de sa lumière est `DECOR | ENNEMI | JOUEUR_LOCAL`, les trois canaux que reçoivent le sol, les murs, le sprite adverse,
##      les capteurs croisés et le capteur de soi. **C'est une lumière NEUTRE** : les deux joueurs, dans les deux vues, la
##      reçoivent de la même façon — jamais un canal de vue (16, 32), qui n'éclairerait qu'un écran.
##   2. **Il TRAHIT le joueur qui le traverse** : le modèle de vue du bot (`PerceptionBotNoeud._lumieres`) le compte parmi ses
##      lumières connues, comme un disque ; sans lui, le bot verrait moins que la lumière, et la salle ne jouerait pas.
##   3. **Il PORTE OMBRE** : les murs hauts le coupent comme ils coupent la torche, pour TOUS les corps et le sol
##      (`CanauxLumiere.masque_ombre_neutre_pour_les_corps`).
##
## ## Les murs bas : il passe par-dessus (décision, et pourquoi)
##
## Un plafonnier est EN HAUTEUR : `HAUTEUR_TUILES` = 1,5, la hauteur d'une fusée au lancer (`MursBasRendu.HAUTEUR_FUSEE_LANCER`).
## Les murs hauts (1,25 tuile) l'arrêtent — « un mur haut arrête tout, quelle que soit la hauteur de la source » (`MursBas`),
## et une salle est une pièce fermée —, mais un mur BAS (0,4 tuile) ne l'arrête pas : la lumière passe par-dessus et le matériau
## du sol dessine la zone morte FINIE que sa hauteur laisse derrière lui (`mb_dans_la_zone_morte`, la règle « par hauteur » :
## `D × (h_mur − h_cible) / (h_source − h_mur)`, la même que la fusée en vol). **Pourquoi pas la règle de la torche** (« un même
## angle », zone constante de 58 px au sol) : la torche est tenue par un corps et suit la règle du jeu ; une source qui a une
## hauteur déclarée suit la géométrie de sa hauteur — c'est ce que pose `MursBasRendu.poser_hauteur_source`, qui retire aussi le
## bit d'ombre des murs bas (une source plus haute qu'eux n'y bute pas). Le modèle du bot lit la MÊME fonction que le shader
## (`MursBasRendu.eclaire_par_hauteur`) : la règle de la torche lui ferait voir 58 px là où la géométrie en cache jusqu'à 109 px
## (à 300 px du mur) — voir plus que la lumière.
##
## ## Allumer seulement ce qui est proche — PAR CONSTRUCTION, et NON MESURÉ
##
## Chaque plafonnier est une lumière à ombres de plus. Il ne brûle donc que si un joueur est assez près pour que sa flaque
## puisse entrer dans SON écran : distance au joueur ≤ `rayon + portée de vue` pour s'allumer, `+ HYSTERESIS_PX` de plus
## pour s'éteindre (sans cela, un joueur qui hésite sur la limite le ferait clignoter). La portée de vue est celle du cadrage
## LE PLUS LARGE que le jeu livre (`ZOOM_LE_PLUS_LARGE`, l'écran scindé à ×1,25 ; `PorteeEcran.portee_minimale` : le coin de
## l'écran, avancé vers la visée) plus `MARGE_VUE_PX` : **un plafonnier éteint ne peut donc jamais être à l'écran d'un joueur
## qui s'y tient assez près pour que sa flaque s'y voie.** Ce que l'on gagne est exactement ce que la distance interdit au
## joueur de voir ; ce qu'on ne gagne pas, c'est de la cadence — **aucun relevé n'a été fait (consigne d'Adrien) : le coût est
## livré NON MESURÉ**, et dans une salle de 24 × 24 cases tous les plafonniers sont à portée, donc allumés. Un joueur qui règle
## un zoom plus large que celui-là (`--zoom=1.0`, débogage) doit abaisser `zoom_de_reference`.
##
## ## Aucun autoload, aucun nœud de jeu
##
## Ce fichier ne nomme aucun autoload : il se charge sous `--script`. Il n'est posé que par `Plafonnier.poser` (le solo, un banc,
## une suite) — **jamais par une carte de duel**, et rien ne transite sur le réseau (`protocol.gd` n'a pas bougé).

const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")

## La taille d'une case, en pixels de monde (`CandelaTileSet.TILE_SIZE`, relue par la garde).
const TUILE_PX := 35.0

## Le groupe où chaque plafonnier se range, que le modèle de vue du bot et le miroir de lumières de la vue iso lisent.
const GROUPE := "plafonniers"
## Le nœud qui les porte dans l'arène : `poser` le crée, `retirer` l'ôte. `GameState.rebuild_arena` ne le connaît pas.
const NOM_CONTENEUR := "Plafonniers"

## La hauteur de la lampe, en tuiles — au-dessus des murets (0,4), au-dessous du plafond d'une salle de 1,25 de murs hauts
## qu'elle éclaire de l'intérieur : c'est celle d'une fusée au lancer, que le shader des murs bas traite déjà.
const HAUTEUR_TUILES := 1.5

## Le rayon de la lumière, en CASES : `rayon_px = rayon × tuile` est le rayon de la TEXTURE de la lumière (son empreinte est le
## double). La flaque visible s'arrête un peu avant (le masque peint tombe à zéro vers les trois quarts de son rayon), et le modèle
## du bot n'en compte qu'une part (`PerceptionBot.FRACTION_PLAFONNIER`). Bornes : sous 1,5 case, la flaque ne tient pas un corps ;
## au-delà de 9, elle dépasse un écran.
const RAYON_PAR_DEFAUT := 4.0
const RAYON_MIN := 1.5
const RAYON_MAX := 9.0
## L'énergie de la lumière. 1,2 est celle de la braise d'une fusée (`FuseeModele.ENERGIE_BRAISE`) : un plafonnier éclaire, il
## n'éblouit pas. Bornées parce que le modèle du bot n'est vérifié contre les capteurs que sur cette plage (le banc).
const INTENSITE_PAR_DEFAUT := 1.2
const INTENSITE_MIN := 0.6
const INTENSITE_MAX := 3.0
## La teinte : l'halogène de la charte — « toute source de lumière de Candela est une flamme ou un filament » (`Charte.HALOGENE`).
const TEINTE_PAR_DEFAUT := Charte.HALOGENE

## Le zoom de la vue la plus large livrée (l'écran scindé) : `GameSettings.ZOOM_ECRAN_SCINDE` — une garde le relit sur
## l'autoload vivant (`tools/test_plafonniers.gd`). Statique : le solo en vue unique est à ×1,5, plus serré ; un zoom plus large
## se déclare ici.
const ZOOM_LE_PLUS_LARGE := 1.25
static var zoom_de_reference := ZOOM_LE_PLUS_LARGE
## Le décalage de la caméra vers la visée (`GameSettings.DECALAGE_VISEE_DEFAUT`), relu de même.
const DECALAGE_VISEE := 0.15
## Ce qu'on ajoute à la portée de vue : le lissage de la caméra, une flaque qui déborde par son bord adouci, un joueur qui
## court (900 px/s de balle, 260 de course : un pas de physique en fait 4).
const MARGE_VUE_PX := 100.0
## La largeur de l'hystérésis : on éteint 120 px plus loin qu'on ne s'allume.
const HYSTERESIS_PX := 120.0

# Paramètres, posés AVANT `add_child` (patron de `Bullet` et `Fusee`).
var indice := 0
## Le rayon de la texture de la lumière, en pixels de monde.
var rayon_px := RAYON_PAR_DEFAUT * TUILE_PX
var intensite := INTENSITE_PAR_DEFAUT
var teinte := TEINTE_PAR_DEFAUT
## La hauteur de la lampe, en pixels (`HAUTEUR_TUILES × tuile`) : ce que lit le modèle du bot.
var hauteur_px := HAUTEUR_TUILES * TUILE_PX

var halo: PointLight2D = null
var allume := true


# ---------------------------------------------------------------------------
# LES DONNÉES — ce que S6 appelle
# ---------------------------------------------------------------------------

## Ce que dit une entrée de la liste, en clair : `""` si elle est valide, le défaut sinon. Une entrée :
##   `case`      : `Vector2i`, ou `[x, y]` (le JSON rend des flottants) — la case où pend la lampe, à son centre ;
##   `rayon`     : en CASES, facultatif (`RAYON_PAR_DEFAUT`), borné à [`RAYON_MIN`, `RAYON_MAX`] ;
##   `intensite` : facultative (`INTENSITE_PAR_DEFAUT`), bornée à [`INTENSITE_MIN`, `INTENSITE_MAX`] ;
##   `teinte`    : facultative, une `Color` ou un texte HTML (`"#f8e8cc"`) — `TEINTE_PAR_DEFAUT` sinon.
static func valider(entree: Variant) -> String:
	if not (entree is Dictionary):
		return "une entrée de plafonnier est un dictionnaire (reçu %s)" % type_string(typeof(entree))
	var d: Dictionary = entree
	if not d.has("case"):
		return "un plafonnier sans « case »"
	var c: Variant = d["case"]
	var ok := c is Vector2i or (c is Array and (c as Array).size() == 2 and _est_un_nombre((c as Array)[0])
		and _est_un_nombre((c as Array)[1]))
	if not ok:
		return "« case » est un Vector2i ou [x, y] (reçu %s)" % str(c)
	for cle in ["rayon", "intensite"]:
		if d.has(cle) and not _est_un_nombre(d[cle]):
			return "« %s » est un nombre (reçu %s)" % [cle, str(d[cle])]
	if d.has("teinte") and not (d["teinte"] is Color or d["teinte"] is String):
		return "« teinte » est une Color ou un texte HTML (reçu %s)" % str(d["teinte"])
	return ""


static func _est_un_nombre(v: Variant) -> bool:
	return v is float or v is int


## L'entrée normalisée : la place du centre de la case (pixels de monde), le rayon et l'énergie bornés, la teinte.
static func normaliser(entree: Dictionary) -> Dictionary:
	var tuile := TUILE_PX
	var c: Variant = entree["case"]
	var cx := (c as Vector2i).x if c is Vector2i else int((c as Array)[0])
	var cy := (c as Vector2i).y if c is Vector2i else int((c as Array)[1])
	var teinte_voulue: Variant = entree.get("teinte", TEINTE_PAR_DEFAUT)
	return {
		"case": Vector2i(cx, cy),
		"position": (Vector2(cx, cy) + Vector2(0.5, 0.5)) * tuile,
		"rayon": clampf(float(entree.get("rayon", RAYON_PAR_DEFAUT)), RAYON_MIN, RAYON_MAX),
		"intensite": clampf(float(entree.get("intensite", INTENSITE_PAR_DEFAUT)), INTENSITE_MIN, INTENSITE_MAX),
		"teinte": teinte_voulue if teinte_voulue is Color else Color.from_string(String(teinte_voulue), TEINTE_PAR_DEFAUT),
	}


## **Pose une liste de plafonniers dans l'arène** — l'appel de S6 (et des bancs) : `parent` est `GameState.arena` ; `liste` est
## un tableau d'entrées (`valider`). Rend les plafonniers posés, dans l'ordre de la liste (`Plafonnier_<i>`, `i` étant l'indice
## DANS la liste : une entrée invalide est refusée à voix haute, `push_error`, et son indice n'est pas réutilisé).
##
## Idempotente : elle retire d'abord le conteneur d'un appel précédent (`retirer`) — changer de salle n'empile rien. Les
## plafonniers sont allumés ou éteints d'emblée selon les joueurs présents (`actualiser`), sans attendre le premier pas de
## physique : sans cela, la flaque d'une salle entrée apparaîtrait une image après l'écran.
static func poser(parent: Node, liste: Array) -> Array[Plafonnier]:
	var poses: Array[Plafonnier] = []
	if parent == null:
		push_error("Plafonnier.poser : pas de parent")
		return poses
	retirer(parent)
	var conteneur := Node2D.new()
	conteneur.name = NOM_CONTENEUR
	parent.add_child(conteneur)
	for i in liste.size():
		var defaut := valider(liste[i])
		if defaut != "":
			push_error("Plafonnier.poser : entrée %d refusée — %s" % [i, defaut])
			continue
		var n := normaliser(liste[i])
		var p := Plafonnier.new()
		p.name = "Plafonnier_%d" % i
		p.indice = i
		p.rayon_px = float(n["rayon"]) * TUILE_PX
		p.intensite = float(n["intensite"])
		p.teinte = n["teinte"]
		p.hauteur_px = HAUTEUR_TUILES * TUILE_PX
		p.position = n["position"]
		conteneur.add_child(p)
		poses.append(p)
	for p in poses:
		p.actualiser()
	return poses


## Retire les plafonniers que `poser` a posés sous `parent` (le conteneur et tout ce qu'il porte), tout de suite : ils sortent
## du groupe avant que `queue_free` n'agisse, sans quoi le modèle du bot les verrait encore une image.
static func retirer(parent: Node) -> void:
	if parent == null:
		return
	var ancien := parent.get_node_or_null(NOM_CONTENEUR)
	if ancien == null:
		return
	parent.remove_child(ancien)
	ancien.queue_free()


# ---------------------------------------------------------------------------
# L'ALLUMAGE PAR PROXIMITÉ — pur, pour la garde
# ---------------------------------------------------------------------------

## Jusqu'où le cadrage montre le sol depuis un joueur : le coin de l'écran, avancé vers la visée, au zoom le plus large, plus la
## marge. Le pire cas : le joueur vise vers un coin.
static func portee_de_vue_px() -> float:
	return Portee.portee_minimale(Portee.VUE_UNIQUE, zoom_de_reference, DECALAGE_VISEE, Iso.TANGAGE_DEG) + MARGE_VUE_PX


## La distance sous laquelle un plafonnier de rayon `rayon_px` s'ALLUME : sa flaque peut alors entrer dans l'écran.
static func rayon_d_allumage_px(rayon_px_: float) -> float:
	return rayon_px_ + portee_de_vue_px()


## Le plafonnier doit-il brûler ? `etait_allume` : son état courant — l'hystérésis. `positions` : celles des joueurs. **Sans
## aucun joueur connu, il brûle** : éteindre sans savoir ferait disparaître une salle qu'un banc ou une suite regarde sans joueur.
static func doit_etre_allume(etait_allume: bool, centre: Vector2, rayon_px_: float, positions: Array) -> bool:
	if positions.is_empty():
		return true
	var seuil := rayon_d_allumage_px(rayon_px_) + (HYSTERESIS_PX if etait_allume else 0.0)
	for p: Vector2 in positions:
		if centre.distance_to(p) <= seuil:
			return true
	return false


# ---------------------------------------------------------------------------
# LE NŒUD
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group(GROUPE)
	# Hors de la hiérarchie : la place est celle du MONDE, que l'arène soit décalée ou non (patron de `Fusee`).
	set_as_top_level(true)
	global_position = position
	halo = PointLight2D.new()
	# « Halo », comme la fusée : le miroir de la vue iso et le modèle du bot cherchent ce nom.
	halo.name = "Halo"
	LightTextures.poser(halo, LightTextures.RETRODIFFUSION, 2.0 * rayon_px)
	halo.color = teinte
	halo.energy = intensite
	# Une lumière NEUTRE : le sol et les murs (1), les sprites adverses et capteurs croisés (2), le joueur local (4). Jamais un
	# canal de vue (16, 32) ni l'un des bits des capteurs de soi (8, 128, 256) : `tools/test_ombre_propre.gd` les interdit.
	halo.range_item_cull_mask = CanauxLumiere.DECOR | CanauxLumiere.ENNEMI | CanauxLumiere.JOUEUR_LOCAL
	# Les ombres, pour tous les corps : voir `masque_ombre_neutre_pour_les_corps`. Cela ne dit rien des murs bas, qui se règle
	# juste après par la hauteur.
	halo.shadow_enabled = true
	halo.shadow_item_cull_mask = CanauxLumiere.masque_ombre_neutre_pour_les_corps()
	halo.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	# La hauteur, APRÈS le masque d'ombre : `poser_hauteur_source` lit le masque qu'on vient de poser, et retire le bit des murs bas
	# (une source plus haute qu'eux ne bute pas dessus).
	MursBasRendu.poser_hauteur_source(halo, HAUTEUR_TUILES)
	add_child(halo)
	actualiser()


func _physics_process(_delta: float) -> void:
	actualiser()


## Allume ou éteint la lumière selon les joueurs présents. Le nœud ne lit que les positions du groupe « players » : rien du réseau.
func actualiser() -> void:
	if halo == null or not is_inside_tree():
		return
	var positions: Array = []
	for j in get_tree().get_nodes_in_group("players"):
		if j is Node2D and is_instance_valid(j) and not (j as Node).is_queued_for_deletion():
			positions.append((j as Node2D).global_position)
	var doit := doit_etre_allume(allume, global_position, rayon_px, positions)
	allume = doit
	halo.enabled = doit
