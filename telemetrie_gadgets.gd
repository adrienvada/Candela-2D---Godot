extends RefCounted
class_name TelemetrieGadgets

## Ce que les gadgets ont FAIT pendant un match — étape 28 du chantier DIX CLASSES,
## lot E (suggestion 8, PE5 ; retenue par Adrien le 2026-09-11).
##
## ## Pourquoi
##
## H11 est ouvert : les dix gadgets n'ont jamais servi en match, et l'archive disait
## le résultat, les classes et les conditions, rien de ce que les gadgets avaient
## fait. Un gadget qui ne sert jamais, ou qui ne tue jamais personne, ne se voyait
## qu'en regardant jouer. Ce fichier compte, par joueur : les poses, les morts de
## gadget (par balle ou en fin de vie), les allumages, les bascules du grésillement,
## les PV infligés par les braises, et les morts survenues dans les
## `FENETRE_EFFET_S` secondes qui suivent un EFFET de gadget.
##
## ## Compté chez les DEUX pairs, depuis les mêmes ordres
##
## Chaque compteur avance dans une fonction que les deux pairs exécutent pour le
## même événement, dans le même ordre : `rpc_spawn_gadget`, `rpc_allumer_gadget`,
## `rpc_etat_gadget`, `Player.rpc_update_hp` (tous `call_local`), et, pour la mort
## d'un gadget, `_sur_gadget_detruit` chez l'hôte et l'ORDRE `rpc_detruire_gadget`
## chez le client — **jamais sur une décision locale du client**, qui retire aussi
## ses gadgets à son propre minuteur de fin de vie. Les deux archives d'un match en
## ligne disent donc la même chose.
##
## ⚠️ **Exception écrite** : les deux compteurs de FENÊTRE (`morts_*_apres_effet`)
## datent les événements à leur ARRIVÉE. Les deux archives ne peuvent y diverger que
## si une mort tombe, à la gigue du lien près, pile à `FENETRE_EFFET_S` d'un effet.
## La requête de cohérence de `docs/SUPABASE.md` le détecte sur le terrain.
##
## ## Ce qu'est un EFFET
##
## Le moment où un gadget change la partie, par un événement reçu des deux côtés :
## la POSE (sauf celle d'un gadget basculable posé éteint, qui n'agit pas encore) —
## c'est le seul événement discret des gadgets passifs ; l'ALLUMAGE de la mine,
## qu'il vienne d'un passage ou d'une balle ; la BASCULE VERS ALLUMÉ du grésillement ;
## chaque PV infligé par les BRAISES, à qui que ce soit, poseur compris. Ne sont PAS
## des effets : l'extinction (voulue ou imposée par la batterie), la mort du gadget,
## son remplacement — dans ces trois cas le gadget cesse d'agir.
##
## ## Lire les chiffres
##
## - Pour la mine, `allumages` compte aussi les mines ABATTUES : une mine touchée ne
##   meurt pas, elle demande l'allumage (`gadget_mine.gd`). Les mines déclenchées par
##   un passage valent donc **au plus** `allumages − morts_balle` (une mine déjà
##   allumée n'encaisse plus, elle n'est jamais comptée abattue).
##   ⚠️ **Un MAJORANT, pas un compte** (revue du 2026-09-11) : une mine abattue meurt
##   de son embrasement, `GadgetMine.DUREE_EMBRASEMENT` (1,6 s) plus tard. Si le match
##   est archivé avant — et c'est le cas qui compte, une mort dans la foulée de la
##   mine — ou si la manche purge ses gadgets d'ici là (`_do_start_round`, qui les
##   libère sans passer par `detruire()`), aucune mort n'est comptée et la mine
##   abattue passe pour un passage. Les allumages et les compteurs de fenêtre, eux,
##   sont exacts. La porter exactement demanderait que l'ordre d'allumage dise
##   lui-même « par balle » : le fil changerait encore, c'est à Adrien de le trancher.
## - **Angle mort assumé** : les gadgets passifs, et une bobine allumée depuis plus de
##   `FENETRE_EFFET_S`, ne sont vus que par leur pose ou leur bascule.
## - `version` et `fenetre_s` voyagent dans le bloc : N et la définition d'« effet »
##   peuvent se réajuster sans mélanger les échantillons.
##
## Comptabilité pure, SANS autoload, testée à froid par
## `tools/test_telemetrie_gadgets.gd` (piège « Une suite en `--script` ne doit pas
## charger `game_state.gd` »). L'horloge est PASSÉE par `game_state.gd`.

## Version du BLOC, indépendante du schéma de `MatchRecord` — la même règle que
## `ConditionsDeMatch.VERSION`.
const VERSION := 1

## N, en secondes. 5 s couvrent l'embrasement de la mine (1,6 s) et le temps de
## l'exploiter ; elles restent sous la plus courte vie d'un gadget continu (la
## poussière, 7,5 s) et très en dessous de la recharge (60 s) : au plus une pose
## par fenêtre.
const FENETRE_EFFET_S := 5.0

## ⚠️ **Mêmes clés que `GADGET_NUMBERS`** (`supabase/functions/_shared/match_report.ts`) :
## `tools/test_telemetrie_gadgets.gd` compare les deux listes, dans les deux sens. Une
## clé ajoutée d'un seul côté tomberait sans bruit au tamis du serveur.
const COMPTEURS: Array[String] = ["poses", "morts_balle", "morts_fin_de_vie",
	"allumages", "bascules_allume", "bascules_eteint", "batterie_vide",
	"morts_adverses_apres_effet", "morts_propres_apres_effet"]
## Des PV, jamais des appels : la brûlure se verse par tics, mais un compteur
## d'appels dépendrait encore du jour où le tic changera.
const CUMULS: Array[String] = ["pv_braises_adversaire", "pv_braises_soi"]

var _cotes: Array[Dictionary] = []
## L'instant du dernier effet de chaque joueur ; −∞ : aucun.
var _dernier_effet := PackedFloat64Array([-INF, -INF])


func _init() -> void:
	commencer()


## Repart de zéro — appelé par `GameState._do_start_round` au départ d'un MATCH.
func commencer() -> void:
	_cotes = [vierge(), vierge()]
	_dernier_effet = PackedFloat64Array([-INF, -INF])


## Un côté à zéro : toutes les clés, jamais une clé absente.
static func vierge() -> Dictionary:
	var d := {}
	for k in COMPTEURS:
		d[k] = 0
	for k in CUMULS:
		d[k] = 0.0
	return d


func _valide(pid: int) -> bool:
	return pid == 0 or pid == 1


func _effet(pid: int, t: float) -> void:
	_dernier_effet[pid] = t


## Une pose. `effet` FAUX pour un gadget basculable posé ÉTEINT (batterie sous le
## seuil) : il n'agit pas encore, et l'extinction n'est pas un effet non plus.
func pose(pid: int, t: float, effet: bool = true) -> void:
	if not _valide(pid):
		return
	_cotes[pid]["poses"] += 1
	if effet:
		_effet(pid, t)


## Une mort de gadget, attribuée à son poseur. Pas un effet : le gadget cesse d'agir.
func mort_de_gadget(pid: int, par_balle: bool) -> void:
	if not _valide(pid):
		return
	var cle := "morts_balle" if par_balle else "morts_fin_de_vie"
	_cotes[pid][cle] += 1


## L'allumage d'un gadget — la mine, qu'on l'ait abordée ou abattue.
func allumage(pid: int, t: float) -> void:
	if not _valide(pid):
		return
	_cotes[pid]["allumages"] += 1
	_effet(pid, t)


## Une bascule du gadget basculable. `batterie` est celle que l'ordre PORTE : à 0,0,
## c'est la coupure décidée par l'hôte (`_maj_reserves_gadgets`), pas un geste du
## joueur.
func bascule(pid: int, actif: bool, batterie: float, t: float) -> void:
	if not _valide(pid):
		return
	if actif:
		_cotes[pid]["bascules_allume"] += 1
		_effet(pid, t)
	elif batterie <= 0.0:
		_cotes[pid]["batterie_vide"] += 1
	else:
		_cotes[pid]["bascules_eteint"] += 1


## Des PV perdus par `victime`, infligés par `source` (−1 : personne). `par_braises`
## dit la CAUSE que `rpc_update_hp` porte. `mortel` : cette perte tue.
##
## ⚠️ L'effet est noté AVANT la mort : un dernier PV de braises tue à délai nul.
func pv_perdus(victime: int, source: int, par_braises: bool, pv: float,
		mortel: bool, t: float) -> void:
	if par_braises and _valide(source) and pv > 0.0:
		var cle := "pv_braises_soi" if source == victime else "pv_braises_adversaire"
		_cotes[source][cle] += pv
		_effet(source, t)
	if not mortel or not _valide(victime):
		return
	for pid in 2:
		if t - _dernier_effet[pid] <= FENETRE_EFFET_S:
			var cle := "morts_propres_apres_effet" if pid == victime \
				else "morts_adverses_apres_effet"
			_cotes[pid][cle] += 1


## Le bloc archivé. Chaque côté porte le slug de son GADGET.
##
## ⚠️ **Aucune clé ne contient « classe »** : au premier niveau de l'enregistrement,
## `classe` est le booléen « match classé » (carnet de `match_record.gd`). `joueur_local`
## vaut −1 hors ligne ; le serveur s'en sert pour ne lire que le côté du rapporteur.
func resume(gadget_j1: String, gadget_j2: String, joueur_local: int) -> Dictionary:
	var sortie := {"version": VERSION, "fenetre_s": FENETRE_EFFET_S,
		"joueur_local": joueur_local}
	for pid in 2:
		var d: Dictionary = _cotes[pid].duplicate()
		for k in CUMULS:
			d[k] = snappedf(float(d[k]), 0.01)
		d["gadget"] = gadget_j1 if pid == 0 else gadget_j2
		sortie["j1" if pid == 0 else "j2"] = d
	return sortie
