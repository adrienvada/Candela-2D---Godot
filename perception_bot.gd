class_name PerceptionBot
extends RefCounted

## Ce que le bot PERÇOIT — chantier SOLO, étape S2. Des fonctions pures : une scène décrite en données entre,
## un verdict sort. Aucun nœud, aucun autoload, aucune physique : une suite en `--script` le charge seule
## (`tools/test_bot_perception.gd`), et le nœud qui l'alimente en jeu est `perception_bot_noeud.gd`.
##
## ## La règle qui prime (Adrien, 2026-10-02)
##
## « L'adversaire doit être honnête : ne percevoir que les sons et la lumière, avec une précision plus ou moins
## bonne sur chaque son. » **La difficulté vient des réflexes, jamais de l'information.**
##
## **Le modèle n'a le droit de se tromper que dans un sens : voir MOINS que la lumière, jamais plus.** Chaque
## décision ci-dessous qui hésite tranche donc du côté du noir : un mur qui touche le rayon par son coin le coupe, une
## lumière ne compte que sur un corps ENTIER dans le cadre, un seuil est pris bien en deçà de ce que le capteur lit
## déjà. Et tout ce qu'on ne sait pas rendre fidèlement est laissé DEHORS, et dit :
##   • la **rétrodiffusion** (la lueur qu'une torche allumée verse sur le corps de son porteur, et sur les murs près de
##     lui) : le modèle ne l'a pas — il voit donc moins que la lumière dans le halo d'une torche allumée ;
##   • le **faisceau dans l'air** (Q41) et le sol que la torche éclaire : rien de ce qu'ils montrent n'est le corps ;
##   • les **gadgets** (S9 les a modélisés autant qu'on pouvait le faire SANS voir plus que la lumière) : ceux qui portent un OCCLUDER —
##     le voile, l'ombre habitée, le leurre, la torche fantôme — entrent dans `monde["obstacles"]` comme des murs minces (leur
##     polygone, tel que le moteur l'ombre : `obstacle_sur`) ; ceux qui ne touchent pas à la lumière — la mine, la nappe de braises, la
##     poudre, le grésillement, dont l'effet sur une lampe est déjà dans l'énergie qu'elle rend — ne changent rien. **Restent aveugles** :
##     un gadget en VOLUME (suie, poussière : un nuage qui efface ce qui s'y tient, et que le modèle ne sait pas rendre) et tout gadget
##     dont on n'a pas su lire l'ombre — le nœud rend alors le bot AVEUGLE par la lumière (`monde["aveugle"]`), il entend toujours ;
##   • la **fumée de fusée** : elle ne cache pas le corps (« jamais d'invisibilité dans la lumière », une masse sombre le
##     remplace à la même place), donc la position reste connue — mais pas l'identité ni la visée ; le bot ne les lit
##     de toute façon jamais ;
##   • une fusée EN VOL (la comète : trop d'énergie variable, trop de hauteur) : seules les fusées posées comptent.
##
## ## Quatre morceaux
##
##   1. **Le cadre** (`cadre_de_vue`, `dans_le_cadre`) : ce qu'un joueur verrait à l'écran depuis la place du bot — le
##      rectangle de sol de la vue unique (`PorteeEcran.demi_empreinte`), avancé vers la visée (`RegardDuel`), tourné du
##      lacet. Hors de ce rectangle, rien n'est vu, éclairé ou non.
##   2. **Les murs** (`segment_degage`, `ligne_de_vue`) : un parcours de grille CASE PAR CASE, jamais des pas fixes
##      (« Parcourir la grille case par case, pas par pas fixes », Pièges connus), sur la même grille que la collision
##      et l'occlusion (`MapGeometry.build_grid`, murs HAUTS seulement). Les murs BAS suivent la règle du jeu
##      (`MursBas.franchit_regle`) : un mur bas ne porte un occluder que pour une lumière plus basse que lui (la torche
##      d'un accroupi), et la zone morte finie qu'il laisse derrière lui à une lumière debout est rendue par le matériau
##      du sol — le modèle la lit dans la même fonction que la balle et l'éblouissement, jamais dans une copie.
##   3. **Les lumières** (`lumiere_cone`, `lumiere_disque`, `lumiere_lampe`, `voir`) : une LISTE d'entrées. S5 y a posé les
##      plafonniers sans refonte : un disque, de hauteur donnée — et déclarée (`par_hauteur`), ce qui change la règle des murs bas.
##   4. **L'ouïe** (`ecouter`) : une zone d'incertitude, jamais la place exacte.
##
## ## Les chiffres de ce fichier sont des chiffres de DÉPART
##
## Chacun dit son statut à côté de lui : *mesuré* (relevé au banc `tools/banc_perception_bot.gd` contre les capteurs
## réels) ou *départ* (posé par prudence, à confirmer). Aucun n'a été réglé « pour que le bot soit bon » : un réglage de
## difficulté vit dans `ProfilBot`, jamais ici.

const Geometrie := preload("res://map_geometry.gd")
const Tuiles := preload("res://candela_tileset.gd")
const Murs := preload("res://murs_bas.gd")
## La règle de la hauteur des murs bas, celle du SHADER (`mb_dans_la_zone_morte`) : une lumière qui déclare une vraie hauteur
## (un plafonnier) la suit, là où la règle du jeu (`Murs.franchit_regle`, « un même angle ») est celle des lumières tenues.
const RenduMurs := preload("res://murs_bas_rendu.gd")
const Son := preload("res://son_visible.gd")
const Regard := preload("res://regard_duel.gd")
const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")
const Vision_ := preload("res://vision.gd")
const Brouillage_ := preload("res://brouillage.gd")

## Les trois genres de lumière que le modèle connaît.
##
## - `CONE` : un faisceau (la torche du bot, et un jour celle d'un PNJ) — la cible est éclairée si le cookie de l'arme
##   verse assez de lumière sur son corps ;
## - `DISQUE` : une tache centrée sur un point, de rayon donné — l'éclair d'un tir, la fusée, le halo de proximité, le
##   plafonnier ;
## - `LAMPE` : une source qu'on VOIT, pas ce qu'elle éclaire — la lampe de la torche de la cible. Son porteur est trahi
##   quand le bot a une ligne de vue sur elle : c'est ce que dit « la torche trahit ».
##
## ⚠️ Valeurs ajoutées en fin d'enum, jamais renumérotées.
enum Genre { CONE, DISQUE, LAMPE }

## Le rayon du corps d'un joueur — celui de sa zone de touche (`MursBas.RAYON_CORPS`). Le corps tient dans le cadre
## ENTIER pour compter, et son point le plus proche d'une lumière est celui qu'on juge.
const RAYON_CORPS := 18.0

## Le zoom, le décalage vers la visée et le lacet de la VUE UNIQUE — la caméra que le brief donne au bot. Copies de
## `GameSettings.ZOOM_VUE_UNIQUE`, `DECALAGE_VISEE_DEFAUT` et `LACET_DEFAUT` : **un nombre recopié dérive**, donc
## `test_bot_perception` les relit sur l'autoload vivant et rougit à la moindre différence.
const ZOOM_VUE_UNIQUE := 1.5
const DECALAGE_VISEE := 0.15
const LACET_DEFAUT := 45.0

## Le seuil de LUMIÈRE que verse un cône sur le point le plus éclairé du corps — la valeur du cookie
## (`WeaponData.lumiere_recue`, 0 à 1) —, au-dessus duquel le corps compte pour éclairé. **Mesuré, et pris très en
## deçà du capteur** : le capteur du corps lit `min(1, 4 × énergie × valeur)` ; à l'énergie pleine de la torche (2,5) il
## dépasse 0,1 dès que le cookie vaut 0,01. 0,15 laisse donc le bord entier du faisceau dans le noir du modèle.
const SEUIL_CONE := 0.15

## Les fractions du rayon d'une texture de lumière que le modèle tient pour ÉCLAIRÉES — *départ*, vérifié au banc
## (`banc_perception_bot` : aucune prise où le modèle voit un capteur noir) : le masque peint tombe à zéro au bord et le
## capteur lit quasi 0 sur le dernier quart ; 0,6 reste dans le plein.
const FRACTION_DISQUE := 0.6

## La part du rayon de la TEXTURE d'un plafonnier (`Plafonnier.rayon_px`) que le modèle tient pour éclairée. Même masque peint que la
## fusée (`LightTextures.RETRODIFFUSION`), donc même valeur que `FRACTION_DISQUE`, et **la même prudence, jamais optimisée**. *Mesuré*
## (`tools/banc_perception_bot.gd`, famille `plafonnier`, 42 prises : trois énergies de 0,6 à 3,0, sept distances, deux caps) : le
## capteur du corps éclaire encore (≥ 0,10) à 90 % du rayon à TOUTES les énergies permises — le modèle, qui s'arrête à 60 % du rayon
## plus le bord du corps (18 px), y laisse donc une marge de plus d'un quart du rayon. Aucune prise « le modèle voit, le capteur est
## noir ». La marge n'est pas à rendre : c'est elle qui tient quand le matériau du jeu changera.
const FRACTION_PLAFONNIER := 0.6

## Une lampe qui brûle à moins que ça (énergie, en part de la pleine énergie de la torche) ne trahit pas : elle
## s'allume ou s'éteint, le grésillement la coupe, la respiration la creuse.
const PART_LAMPE_MIN := 0.4

## Le rayon minimal d'une zone d'incertitude, en pixels : le bot ne reçoit jamais la place exacte d'un son, même d'un
## tir tout près et avec la meilleure oreille. Un corps fait 18 de rayon ; la zone ne descend pas sous un corps.
const RAYON_ZONE_MIN := 20.0
## La part du rayon de la zone dont son CENTRE s'écarte au plus de la vérité — sous 1 : la zone contient toujours la
## vraie position (on ne ment pas au bot, on le brouille), et jamais en son centre (`DECENTRAGE_MIN`).
const DECENTRAGE := 0.8
const DECENTRAGE_MIN := 0.1

## En deçà de cette distance, un son n'a rien qui puisse l'occulter : « un son à bout portant ne peut pas être occulté »
## (Pièges connus, 2026-09-09) — les trois rayons parallèles de l'audio balaient un couloir de 48 px.
const OCCLUSION_ECART_LATERAL := 24.0
const OCCLUSION_DISTANCE_MIN := 2.0 * OCCLUSION_ECART_LATERAL

const _EPSILON_COIN := 1.0e-9

## À quelle distance, en pixels, un segment qui frôle un polygone d'ombre le coupe encore (S9) : du côté du noir.
const TOLERANCE_OBSTACLE := 0.5

## L'ÉBLOUISSEMENT (S9b) : ce qu'il retire à la vue du bot, traduit depuis ce qu'il retire à l'écran d'un joueur.
##
## Sur l'écran d'un joueur ébloui, **le CORPS de l'adversaire s'efface** (`Brouillage.opacite` : l'alpha de sa silhouette tombe à zéro dès
## que l'éblouissement atteint la moitié de son maximum, et le voile blanc couvre le reste) — et **sa lampe reste** (le mode LAMPE, choix
## d'Adrien : on ne perd pas la source qui éblouit). Le modèle fait de même, et jamais plus : un bot ébloui ne reconnaît plus un corps dont
## l'opacité, pour un joueur au même éblouissement, passerait sous `OPACITE_MIN_CORPS` ; il ne le voit donc ni par un cône, ni par un
## disque (halo, éclair, fusée, plafonnier). Il voit toujours la lampe d'une torche qui brûle dans son cadre.
## **0,5 : une silhouette à moitié effacée n'est plus une silhouette.** Un joueur la distingue encore ; le bot, non — voir MOINS que la
## lumière, jamais plus. Atteint dès ~0,09 d'éblouissement : au-dessus de la rétrodiffusion de sa propre torche (0,06, opacité 0,65), donc
## une torche allumée n'aveugle pas son bot, mais sous un faisceau ou un éclair de tir de près il perd le corps de la cible un instant.
## *Départ*, non mesuré au capteur : le banc rejoue le modèle contre `Brouillage.opacite`, la fonction même de l'écran.
const OPACITE_MIN_CORPS := 0.5

## Le bot, à cet éblouissement (0 à 1), distingue-t-il encore le corps de l'adversaire ? Lu sur `Brouillage.opacite`, la fonction que
## l'écran applique à la silhouette ; à éblouissement nul, toujours vrai (`opacite(0)` vaut 1).
static func corps_distinct(ebloui: float) -> bool:
	return Brouillage_.opacite(clampf(ebloui, 0.0, 1.0)) >= OPACITE_MIN_CORPS


# ---------------------------------------------------------------------------
# LE MONDE
# ---------------------------------------------------------------------------

## Le monde que le modèle regarde, tiré d'une carte (`map_codec.gd`) : la grille des murs HAUTS (les seuls qui arrêtent
## toute lumière), la taille d'une case, et les rectangles des murs bas (la règle de `MursBas`).
##
## Les murs HAUTS seulement, jamais la grille de solidité du bot (`MapGeometry.build_solid_grid`) : le vide hors sol y
## est solide, et il ne porte aucun occluder — « on doit pouvoir se tirer dessus d'une rive à l'autre d'un gouffre ».
## Un modèle qui comptait le vide comme un mur verrait MOINS, ce qui serait honnête mais faux : il masquerait la
## moitié de la carte à un bot qui y voit la lumière passer.
static func monde_de_la_carte(data: Dictionary) -> Dictionary:
	return {
		"murs": Geometrie.build_grid(data, Geometrie.Kind.WALLS),
		"tuile": float(Tuiles.TILE_SIZE.x),
		"murs_bas": Geometrie.rects_monde(data, Geometrie.Kind.LOW_WALLS),
		"aveugle": false,
		# S9 : les polygones d'ombre des gadgets posés (voile, ombre habitée, leurre, torche fantôme), en coordonnées du MONDE — des
		# `PackedVector2Array`. Vide hors partie : une carte seule n'a que ses murs.
		"obstacles": [],
	}


## Une case de la grille est-elle un mur haut ? Hors de la grille : non (la ceinture est une fosse, pas un mur).
static func mur_a(monde: Dictionary, c: Vector2i) -> bool:
	var murs: Array = monde["murs"]
	var ix := c.x + Geometrie.BORDER
	if ix < 0 or ix >= murs.size():
		return false
	var colonne: Array = murs[ix]
	var iy := c.y + Geometrie.BORDER
	if iy < 0 or iy >= colonne.size():
		return false
	return colonne[iy]


## Le segment `a → b` ne touche-t-il aucun mur HAUT ?
##
## **Un parcours de grille case par case** (Amanatides et Woo) : une frontière de case franchie par pas, jamais des pas
## fixes qui lisent la même case plusieurs fois et manquent l'entrée d'un coin. Exact : la même réponse qu'un test
## segment-rectangle sur les rectangles fusionnés de `MapGeometry`, vérifiée par la suite sur chaque carte livrée.
##
## **Du côté du noir, partout où il y a un doute** : un point de départ ou d'arrivée DANS un mur coupe ; un segment qui
## passe EXACTEMENT par un coin de mur coupe (les deux cases voisines comptent).
static func segment_degage(a: Vector2, b: Vector2, monde: Dictionary) -> bool:
	var t: float = monde["tuile"]
	var ca := Vector2i(floori(a.x / t), floori(a.y / t))
	var cb := Vector2i(floori(b.x / t), floori(b.y / t))
	if mur_a(monde, ca) or mur_a(monde, cb):
		return false
	if ca == cb:
		return true
	var d := b - a
	var sx := 0 if d.x == 0.0 else (1 if d.x > 0.0 else -1)
	var sy := 0 if d.y == 0.0 else (1 if d.y > 0.0 else -1)
	# Le paramètre (0 → 1) où le segment franchit la prochaine frontière verticale puis horizontale, et l'écart entre
	# deux franchissements du même axe.
	var tmax_x := INF
	var tdelta_x := INF
	if sx != 0:
		tmax_x = (float(ca.x + (1 if sx > 0 else 0)) * t - a.x) / d.x
		tdelta_x = t / absf(d.x)
	var tmax_y := INF
	var tdelta_y := INF
	if sy != 0:
		tmax_y = (float(ca.y + (1 if sy > 0 else 0)) * t - a.y) / d.y
		tdelta_y = t / absf(d.y)
	var c := ca
	# Garde-fou : jamais plus de cases que la distance de Manhattan n'en demande (+ les coins) — un flottant mal arrondi
	# ne doit pas faire tourner la boucle.
	var garde := absi(cb.x - ca.x) + absi(cb.y - ca.y) + 4
	while c != cb and garde > 0:
		garde -= 1
		if absf(tmax_x - tmax_y) <= _EPSILON_COIN:
			# Par un coin exactement : les deux cases voisines du coin comptent, on touche l'une ou l'autre.
			if mur_a(monde, Vector2i(c.x + sx, c.y)) or mur_a(monde, Vector2i(c.x, c.y + sy)):
				return false
			c += Vector2i(sx, sy)
			tmax_x += tdelta_x
			tmax_y += tdelta_y
		elif tmax_x < tmax_y:
			c.x += sx
			tmax_x += tdelta_x
		else:
			c.y += sy
			tmax_y += tdelta_y
		if mur_a(monde, c):
			return false
	return true


## Le segment `a → b` coupe-t-il l'un des OBSTACLES du monde — le polygone d'ombre d'un gadget posé (S9) ? Un point de départ ou d'arrivée
## DANS un polygone coupe ; un segment qui ne fait que le TOUCHER, à un demi-pixel près, coupe aussi : **du côté du noir au moindre
## doute**, comme pour les murs. Le polygone est celui que le moteur donne à l'occluder : un point est dans l'ombre d'une lumière quand
## le segment qui l'y relie le traverse, et c'est exactement ce test.
static func obstacle_sur(a: Vector2, b: Vector2, monde: Dictionary) -> bool:
	var obstacles: Array = monde.get("obstacles", [])
	for poly in obstacles:
		if segment_coupe_polygone(a, b, poly as PackedVector2Array):
			return true
	return false


## Le segment `a → b` coupe-t-il ce polygone (à `TOLERANCE_OBSTACLE` près) ?
static func segment_coupe_polygone(a: Vector2, b: Vector2, poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	if Geometry2D.is_point_in_polygon(a, poly) or Geometry2D.is_point_in_polygon(b, poly):
		return true
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		if Geometry2D.segment_intersects_segment(a, b, p, q) != null:
			return true
		# Un frôlement : une extrémité de l'arête à un demi-pixel du segment, ou l'inverse (intersection manquée par un arrondi).
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= TOLERANCE_OBSTACLE \
				or Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) <= TOLERANCE_OBSTACLE \
				or Geometry2D.get_closest_point_to_segment(a, p, q).distance_to(a) <= TOLERANCE_OBSTACLE \
				or Geometry2D.get_closest_point_to_segment(b, p, q).distance_to(b) <= TOLERANCE_OBSTACLE:
			return true
	return false


## Une ligne de vue, de `a` (à la hauteur `h_a`, en pixels) à `b` (hauteur `h_b`) : ni mur haut, ni mur bas qui la coupe.
##
## Les hauteurs sont celles de la POSTURE (`MursBas.hauteur_de_posture`) ou d'une source posée : debout, on voit par-dessus
## un mur bas ; accroupi, ou une fusée au sol, on bute dessus. `a` est la SOURCE du rayon (l'œil, la lampe), `b` ce qu'il
## atteint — la zone morte d'un mur bas se compte depuis sa face de sortie vers `b`.
static func ligne_de_vue(a: Vector2, b: Vector2, h_a: float, h_b: float, monde: Dictionary) -> bool:
	if not segment_degage(a, b, monde) or obstacle_sur(a, b, monde):
		return false
	var bas: Array = monde["murs_bas"]
	if bas.is_empty():
		return true
	return Murs.franchit_regle(a, b, h_a, h_b, bas)


## La ligne de vue d'une LUMIÈRE `l` jusqu'à un point `b` de hauteur `h_b` : les murs hauts, puis les murs bas — par la règle de
## la hauteur de la lumière si elle en déclare une (`par_hauteur`), par celle du jeu sinon. L'œil du bot, lui, passe toujours par
## `ligne_de_vue` : un corps ne déclare pas de hauteur de source.
static func ligne_de_la_lumiere(l: Dictionary, b: Vector2, h_b: float, monde: Dictionary) -> bool:
	var a: Vector2 = l["origine"]
	if not bool(l.get("par_hauteur", false)):
		return ligne_de_vue(a, b, float(l["hauteur"]), h_b, monde)
	if not segment_degage(a, b, monde) or obstacle_sur(a, b, monde):
		return false
	var bas: Array = monde["murs_bas"]
	if bas.is_empty():
		return true
	return RenduMurs.eclaire_par_hauteur(a, b, float(l["hauteur"]), h_b, Murs.forme_de_lumiere(bas), Murs.hauteur_mur())


# ---------------------------------------------------------------------------
# LE CADRE
# ---------------------------------------------------------------------------

## Ce qu'un joueur verrait à l'écran depuis la place du bot : le rectangle de sol de la vue unique, centré sur le joueur
## plus le décalage vers sa visée (`RegardDuel`), orienté du lacet.
##
## `reglages` (tous facultatifs) : `zoom`, `decalage`, `lacet` (degrés), `tangage` (degrés), `vue` (la vue logique, en
## pixels) et `decalage_lisse` (le décalage que la caméra a EFFECTIVEMENT atteint, `Vector2` — le nœud le fait suivre
## la visée comme le jeu le fait pour un joueur, `RegardDuel.lisser`). Sans lui, le regard est « posé » : le décalage a
## rejoint sa cible.
##
## ⚠️ **La caméra arrêtée au bord de la carte n'est pas modélisée** (`RegardDuel.centre_du_regard`) : elle déplace le
## cadre VERS l'intérieur de la carte, jamais vers l'extérieur — le cadre du modèle est donc toujours contenu dans le
## cadre réel sur la carte : il voit moins, jamais plus.
static func cadre_de_vue(position: Vector2, visee: Vector2, reglages: Dictionary = {}) -> Dictionary:
	var zoom := float(reglages.get("zoom", ZOOM_VUE_UNIQUE))
	var vue: Vector2 = reglages.get("vue", Portee.VUE_UNIQUE)
	var decalage := float(reglages.get("decalage", DECALAGE_VISEE))
	var tangage := float(reglages.get("tangage", Iso.TANGAGE_DEG))
	var lacet := float(reglages.get("lacet", LACET_DEFAUT))
	var decale: Vector2
	if reglages.has("decalage_lisse"):
		decale = reglages["decalage_lisse"]
	else:
		decale = Regard.decalage_vise(visee, decalage, vue, zoom)
	return {
		"centre": position + decale,
		"demi": Portee.demi_empreinte(vue, zoom, tangage),
		"lacet": lacet,
	}


## Le point est-il dans le cadre, à `marge` pixels près du bord (positive : plus étroit) ?
##
## L'écran tourne du lacet : un point du monde se lit à l'écran tourné de `+lacet` (la caméra 2D est tournée de `−lacet`,
## `GameState.orienter_camera_2d`) — `tools/banc_perception_bot.gd` le vérifie contre les vraies caméras.
static func dans_le_cadre(point: Vector2, cadre: Dictionary, marge: float = 0.0) -> bool:
	var demi: Vector2 = cadre["demi"]
	var l := (point - (cadre["centre"] as Vector2)).rotated(deg_to_rad(float(cadre["lacet"])))
	return absf(l.x) <= demi.x - marge and absf(l.y) <= demi.y - marge


# ---------------------------------------------------------------------------
# LES LUMIÈRES CONNUES
# ---------------------------------------------------------------------------

## Un faisceau. `arme` (un `WeaponData`) donne la valeur de cookie réelle (`lumiere_recue` : l'angle, la portée, la
## luminosité et la matière du cookie dans le même pixel) ; sans arme, `portee` et `demi_angle` (radians) donnent le cône
## analytique de `Vision.intensite_recue` — la référence que le cookie valide à 0,3 % près.
static func lumiere_cone(nom: String, origine: Vector2, avant: Vector2, hauteur: float, arme: Object = null,
		portee: float = 0.0, demi_angle: float = 0.0) -> Dictionary:
	return {"genre": Genre.CONE, "nom": nom, "origine": origine, "avant": avant.normalized(), "hauteur": hauteur,
		"arme": arme, "portee": portee, "cos": cos(demi_angle)}


## Une tache : `rayon` est le rayon que le modèle tient pour ÉCLAIRÉ (déjà réduit de `FRACTION_DISQUE` par l'appelant,
## ou fixé par lui — un plafonnier a son rayon) ; `hauteur` la hauteur de la source, en pixels.
##
## `par_hauteur` : la lumière déclare une VRAIE hauteur (`MursBasRendu.poser_hauteur_source`, comme un plafonnier ou une fusée en
## l'air) : un mur bas ne l'arrête alors que par la géométrie de cette hauteur (`MursBasRendu.eclaire_par_hauteur`), la fonction même
## que lit le shader des corps. Faux (le défaut : le halo, l'éclair, la torche — des lumières TENUES, sans hauteur posée), c'est la
## règle du jeu, « un même angle » (`MursBas.franchit_regle`). Les deux règles ne donnent pas la même zone morte : une source
## haute en laisse moins près du mur et plus loin de lui, et employer la mauvaise ferait voir à travers la zone que le shader noircit.
static func lumiere_disque(nom: String, origine: Vector2, rayon: float, hauteur: float, par_hauteur: bool = false) -> Dictionary:
	return {"genre": Genre.DISQUE, "nom": nom, "origine": origine, "rayon": rayon, "hauteur": hauteur,
		"par_hauteur": par_hauteur}


## Une lampe qu'on VOIT : son porteur est trahi tant que le bot a une ligne de vue sur elle, dans le cadre.
static func lumiere_lampe(nom: String, origine: Vector2, hauteur: float) -> Dictionary:
	return {"genre": Genre.LAMPE, "nom": nom, "origine": origine, "hauteur": hauteur}


## La valeur de lumière qu'un cône verse sur un point : celle du cookie réel si l'arme en a un, sinon le cône analytique.
static func intensite_cone(l: Dictionary, point: Vector2) -> float:
	var arme: Object = l.get("arme")
	if arme != null:
		return float(arme.call("lumiere_recue", l["avant"], l["origine"], point))
	return Vision_.intensite_recue(l["avant"], l["origine"], point, float(l["portee"]), float(l["cos"]))


## Les points du corps où l'on juge la lumière : son centre, et cinq points de son bord du côté de la lumière — celui qui
## lui fait face, et deux de chaque côté. C'est ce que lit le capteur de corps (le maximum d'un anneau de rayon 17), côté
## lumière : le point le plus éclairé d'un corps éclairé d'un côté.
static func points_du_corps(centre: Vector2, vers_la_lumiere: Vector2) -> Array[Vector2]:
	var sortie: Array[Vector2] = [centre]
	var dir := vers_la_lumiere - centre
	if dir.length() < 0.001:
		return sortie
	var base := dir.angle()
	for ecart in [-90.0, -45.0, 0.0, 45.0, 90.0]:
		sortie.append(centre + Vector2.from_angle(base + deg_to_rad(ecart)) * (RAYON_CORPS - 1.0))
	return sortie


## La lumière `l` éclaire-t-elle le corps de centre `pos` et de hauteur `h_c` ? La lumière doit atteindre le point jugé SANS
## mur (ni haut, ni bas selon la hauteur de la source) ET le centre du corps : deux rayons, du côté du noir.
##
## Un `LAMPE` n'éclaire rien : il se voit (`voir`).
static func eclaire(l: Dictionary, pos: Vector2, h_c: float, monde: Dictionary) -> bool:
	var genre: int = l["genre"]
	if genre == Genre.LAMPE:
		return false
	var origine: Vector2 = l["origine"]
	var h_l: float = l["hauteur"]
	if genre == Genre.DISQUE:
		# Le point du corps le plus proche de la tache : si elle ne l'atteint pas, elle n'éclaire rien du corps.
		var vers := origine - pos
		var proche := pos if vers.length() <= RAYON_CORPS else pos + vers.normalized() * RAYON_CORPS
		if origine.distance_to(proche) > float(l["rayon"]):
			return false
		return ligne_de_la_lumiere(l, proche, h_c, monde) and ligne_de_la_lumiere(l, pos, h_c, monde)
	# CONE
	if not ligne_de_vue(origine, pos, h_l, h_c, monde):
		return false
	for p in points_du_corps(pos, origine):
		if intensite_cone(l, p) >= SEUIL_CONE and ligne_de_vue(origine, p, h_l, h_c, monde):
			return true
	return false


# ---------------------------------------------------------------------------
# VOIR
# ---------------------------------------------------------------------------

## Ce que le bot voit de sa cible, et par quoi.
##
##   `bot`    : `position`, `visee` (unitaire), `accroupi` ;
##   `cible`  : `position`, `accroupi` ;
##   `lumieres` : la liste des lumières connues (`lumiere_cone`, `lumiere_disque`, `lumiere_lampe`) ;
##   `monde`  : `monde_de_la_carte` ; `monde["aveugle"]` vrai ne laisse rien voir (gadget qu'on ne sait pas modéliser) ;
##              `monde["ebloui"]` (0 à 1, absent : 0) : l'éblouissement du bot — au-delà de `OPACITE_MIN_CORPS` il ne voit plus le corps, que la lampe.
##
## **Une cible est vue si, et seulement si**, l'une des lumières la révèle :
##   • un `CONE` ou un `DISQUE` l'éclaire (`eclaire`) ET le bot a une ligne de vue sur son corps ET son corps tient
##     ENTIER dans le cadre ;
##   • une `LAMPE` est dans le cadre ET le bot a une ligne de vue sur elle — la cible est trahie à la lampe, pas au corps.
##
## Rend `vu` (bool), `dans_le_cadre` (le corps l'est), `par` (les noms des lumières qui l'ont révélée) et `position` :
## **ce qui a été VU** — le centre du corps s'il est éclairé (précis), la lampe sinon (à 17 px du centre).
static func voir(bot: Dictionary, cible: Dictionary, lumieres: Array, monde: Dictionary,
		reglages: Dictionary = {}) -> Dictionary:
	var res := {"vu": false, "dans_le_cadre": false, "par": [], "position": Vector2.ZERO}
	if bool(monde.get("aveugle", false)):
		return res
	var oeil: Vector2 = bot["position"]
	var h_oeil := Murs.hauteur_de_posture(bool(bot.get("accroupi", false)))
	var pos: Vector2 = cible["position"]
	var h_c := Murs.hauteur_de_posture(bool(cible.get("accroupi", false)))
	var cadre := cadre_de_vue(oeil, bot.get("visee", Vector2.ZERO), reglages)
	var corps_dans_le_cadre := dans_le_cadre(pos, cadre, RAYON_CORPS)
	res["dans_le_cadre"] = corps_dans_le_cadre
	# S9b : un bot ébloui ne distingue plus le corps (voir `OPACITE_MIN_CORPS`) ; sa vue de la LAMPE, plus bas, ne change pas.
	var corps_visible := corps_dans_le_cadre and corps_distinct(float(monde.get("ebloui", 0.0))) \
		and ligne_de_vue(oeil, pos, h_oeil, h_c, monde)
	var par: Array = []
	var lampe_vue := Vector2.INF
	for l in lumieres:
		var genre: int = l["genre"]
		if genre == Genre.LAMPE:
			var o: Vector2 = l["origine"]
			if dans_le_cadre(o, cadre) and ligne_de_vue(oeil, o, h_oeil, float(l["hauteur"]), monde):
				par.append(String(l["nom"]))
				if lampe_vue == Vector2.INF:
					lampe_vue = o
		elif corps_visible and eclaire(l, pos, h_c, monde):
			par.append(String(l["nom"]))
	if par.is_empty():
		return res
	res["vu"] = true
	res["par"] = par
	# Le corps éclairé donne sa place précise ; une lampe seule ne donne que la sienne.
	var eclaire_le_corps := false
	for l in lumieres:
		if int(l["genre"]) != Genre.LAMPE and par.has(String(l["nom"])):
			eclaire_le_corps = true
			break
	res["position"] = pos if eclaire_le_corps else lampe_vue
	return res


# ---------------------------------------------------------------------------
# ENTENDRE
# ---------------------------------------------------------------------------

## La part d'un son que les murs occultent, pour UN auditeur : trois rayons parallèles, écartés de ±24 px, dont on compte
## ceux qu'un mur haut arrête — 0, 1/3, 2/3 ou 1. **La géométrie de `AudioManager.part_occultee_entre`**, jumelle sans
## physique : l'audio la calcule pour l'oreille du JOUEUR, ici elle l'est pour la place du BOT. Un son plus proche que
## `OCCLUSION_DISTANCE_MIN` n'est jamais occulté.
static func part_occultee(source: Vector2, auditeur: Vector2, monde: Dictionary) -> float:
	if source.distance_to(auditeur) < OCCLUSION_DISTANCE_MIN:
		return 0.0
	var perp := (auditeur - source).orthogonal().normalized() * OCCLUSION_ECART_LATERAL
	var touches := 0
	for decalage in [Vector2.ZERO, perp, -perp]:
		if not segment_degage(source + decalage, auditeur + decalage, monde):
			touches += 1
	return float(touches) / 3.0


## Ce que le bot tire d'un son annoncé par `AudioManager.son_localise`, ou `{}` s'il ne l'entend pas.
##
## **Le bot ne reçoit JAMAIS la position exacte.** Il reçoit une ZONE : un centre décalé au hasard de la vérité (dans un
## disque dont le rayon est `DECENTRAGE` fois celui de la zone — la zone contient donc toujours la vraie position, et ne
## la centre jamais) et un rayon. Le rayon vient de ce que le liseré dit AU JOUEUR (`SonVisible.percevoir` : la largeur
## angulaire, de 10° à 180°, que les ancres d'Adrien posent sur le niveau du son) : `distance × sin(largeur / 2)`, la
## demi-corde du cône d'incertitude à cette distance, divisée par `precision_auditive`, avec un plancher `RAYON_ZONE_MIN`
## qu'aucune précision ne franchit.
## Un joueur et un bot reçoivent ainsi la MÊME information d'un même son : seule la façon d'en user diffère.
##
## Ce qui en descend, sans rien écrire ici :
##   • **la famille** — un tir (0 dB) reste net partout, un pas (−13 dB) se brouille avec la distance et à bout de portée,
##     une douille (−16 dB, portée courte) tombe entre les deux ;
##   • **la distance** — un son perd `PERTE_DISTANCE_DB` sur toute sa portée, et le rayon suit la distance en plus ;
##   • **un mur** — `part_occultee` depuis la place du bot : −5 dB et une largeur ×1,6 (`FLOU_OCCLUSION`) ;
##   • **la fumée au point source** — `fumee_db` de l'événement, déjà calculé par l'audio ;
##   • **sa propre portée** — au-delà, `percevoir` ne rend rien ; en deçà du seuil d'audibilité non plus.
##
## `bot` : `position`, `id` (le `player_id` du corps du bot : ses propres sons ne comptent pas — un bot qui s'entendrait
## marcher se chercherait lui-même). Les sons de famille muette (la salle, le clic de torche) ne se dessinent pas et ne
## s'écoutent pas davantage : ils ne sont pas une information (`SonVisible.categorie_de`).
static func ecouter(evenement: Dictionary, bot: Dictionary, monde: Dictionary, rng: RandomNumberGenerator,
		precision: float = 1.0) -> Dictionary:
	if int(evenement.get("emetteur", -1)) == int(bot.get("id", -2)):
		return {}
	var categorie := Son.categorie_de(String(evenement.get("famille", "")))
	if categorie < 0:
		return {}
	var source: Vector2 = evenement["pos"]
	var auditeur: Vector2 = bot["position"]
	var distance := source.distance_to(auditeur)
	var portee := float(evenement.get("portee", 0.0))
	if portee <= 0.0 or distance >= portee:
		return {}
	var part := part_occultee(source, auditeur, monde)
	var percu: Dictionary = Son.percevoir(categorie, float(evenement.get("niveau_db", 0.0)), distance, portee, part,
		float(evenement.get("fumee_db", 0.0)), float(evenement.get("wet", 0.0)), float(evenement.get("diagonale", 0.0)))
	if percu.is_empty():
		return {}
	var largeur := float(percu["largeur"])
	var rayon := maxf(distance * sin(deg_to_rad(largeur * 0.5)) / maxf(precision, 0.05), RAYON_ZONE_MIN)
	# Un centre décalé de la vérité de `DECENTRAGE_MIN` à `DECENTRAGE` fois le rayon, dans une direction tirée au hasard.
	var ecart := rayon * DECENTRAGE * lerpf(DECENTRAGE_MIN, 1.0, sqrt(rng.randf()))
	var centre := source + Vector2.from_angle(rng.randf() * TAU) * ecart
	return {
		"centre": centre,
		"rayon": rayon,
		"famille": String(evenement.get("famille", "")),
		"categorie": categorie,
		"largeur": largeur,
		"occultation": part,
		"niveau_percu": float(percu["niveau_percu"]),
	}
