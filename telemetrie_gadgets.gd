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
## gadget (par balle ou en fin de vie), les allumages (par passage ou par balle,
## depuis le lot H), les bascules du grésillement, les PV infligés par les braises,
## et les morts survenues dans les `FENETRE_EFFET_S` secondes qui suivent un EFFET
## de gadget.
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
## - Pour la mine, `allumages_passage` et `allumages_balle` sont **deux comptes
##   exacts**, et non plus un majorant (lot H, 2026-09-12, décision d'Adrien).
##   L'ORDRE d'allumage porte lui-même sa cause (`GadgetBase.ALLUMAGE_BALLE`), tirée
##   du gadget chez l'hôte et rejouée telle quelle chez le client : personne n'a plus
##   à la déduire d'une soustraction.
##   ⚠️ **Ce que cette soustraction avait de faux, et pourquoi elle est partie** :
##   une mine touchée ne meurt pas, elle demande l'allumage (`gadget_mine.gd`), et
##   elle meurt de son embrasement `GadgetMine.DUREE_EMBRASEMENT` (1,6 s) plus tard.
##   Si le match était archivé avant — et c'est le cas qui compte, une mort dans la
##   foulée de la mine — ou si la manche purgeait ses gadgets d'ici là
##   (`_do_start_round`, qui les libère sans passer par `detruire()`), la mine abattue
##   n'avait aucune mort au bloc et passait pour un passage. La cause voyage
##   désormais avec l'ordre, donc aucune de ces deux courses ne la décide.
## - **Reste approché, et ce n'est pas propre à la mine** : les colonnes de MORT ne
##   comptent que les gadgets passés par `detruire()` AVANT l'archive. **Trois sorties
##   n'y passent pas**, et la troisième est la plus fréquente des trois (liste rétablie
##   en revue le 2026-09-12 : la première rédaction n'avait gardé que le premier cas,
##   alors que les deux autres sont ordinaires) :
##   1. un gadget **encore debout à la fin du match** — une mine qui brûle, une nappe
##      qui fume ;
##   2. un gadget **purgé au départ de manche** (`GameState._do_start_round`, qui vide
##      `bullet_container` au `queue_free()`) : dans un BO3, tout gadget vivant à la
##      fin d'une manche quitte ainsi le match, et la télémétrie court sur le MATCH ;
##   3. un gadget **REMPLACÉ** (`_do_spawn_gadget`, « un gadget debout par joueur »,
##      `queue_free()` sans `detruire()`) : avec une recharge de 60 s dans un match de
##      5 min, c'est le cas ordinaire et non un bord. Le match B de la suite le joue
##      exactement — une mine abattue, puis remplacée pendant son embrasement, laisse
##      `morts_balle` à 0.
##   Dans les trois cas c'est une **absence**, pas une attribution fausse : aucun compte
##   ne dit plus autre chose que ce qu'il compte, et c'est toute la différence avec
##   l'ancien `allumages − morts_balle`, qui transformait cette absence en un passage
##   inventé. Un lecteur qui veut des morts de gadget exhaustives ne les trouvera pas
##   ici ; ce que ces colonnes disent, c'est **comment** meurent celles qui meurent.
## - **Angle mort assumé** : les gadgets passifs, et une bobine allumée depuis plus de
##   `FENETRE_EFFET_S`, ne sont vus que par leur pose ou leur bascule.
## - `version` et `fenetre_s` voyagent dans le bloc : N et la définition d'« effet »
##   peuvent se réajuster sans mélanger les échantillons.
##
## Comptabilité pure, SANS autoload, testée à froid par
## `tools/test_telemetrie_gadgets.gd` (piège « Une suite en `--script` ne doit pas
## charger `game_state.gd` »). L'horloge est PASSÉE par `game_state.gd`.

## Version du BLOC, indépendante du schéma de `MatchRecord` — la même règle que
## `ConditionsDeMatch.VERSION` : le jour où une clé change ici, un lecteur sait à
## quelle forme il a affaire sans que tout le journal change de version.
##
## 2 (étape 28, lot H, 2026-09-12) — `allumages` se scinde en `allumages_passage` et
## `allumages_balle`. La règle du fichier s'applique telle quelle : les deux formes
## ne se mélangent pas, on filtre dessus. ⚠️ **Et il existe bel et bien des blocs en
## version 1**, malgré une base où rien n'est encore arrivé : le journal local d'un
## poste de test en porte, et `RankedIdentity` renvoie les matchs classés jamais
## accusés en repassant par `MatchRecord.conditions_a_envoyer()` — un bloc v1 peut
## donc arriver au serveur après ce lot, avec son ancienne clé, que le tamis laissera
## tomber sans refuser le rapport.
##
## ⚠️ **Ce nombre voyage jusqu'à une requête SQL** : celle de `docs/SUPABASE.md`
## (section PE5) filtre en dur sur `version = 2` pour ne pas agréger deux formes. Le
## contrôle qui les tient ensemble est dans `tools/test_telemetrie_gadgets.gd`, avec
## `FORME_TEMOIN` — sans quoi rien ne rougissait quand ce numéro revenait à 1 et la
## requête documentée ne rendait plus une seule ligne, sans un mot (revue du
## 2026-09-12, défaut reproduit).
const VERSION := 2

## Le témoin de la FORME du bloc — l'empreinte de `COMPTEURS + CUMULS`, triée, telle
## que `tools/test_telemetrie_gadgets.gd` la recalcule. Le patron de
## `Protocol.WIRE_WITNESS`, et pour la même raison : `VERSION` ne se garde pas toute
## seule. Changer une clé sans toucher au numéro ferait partir la forme neuve sous
## l'ancienne étiquette, et la requête de `docs/SUPABASE.md` mélangerait deux formes —
## exactement ce que `version` existe pour empêcher.
##
## ⚠️ **L'ordre des gestes** : quand la suite rougit, elle imprime l'empreinte neuve.
## On tranche D'ABORD le numéro (faut-il monter `VERSION` ? faut-il suivre la requête
## SQL et `GADGET_NUMBERS` ?), on recopie l'empreinte ENSUITE. Recopier d'abord, c'est
## reverdir sans avoir décidé.
const FORME_TEMOIN := "cc2fb1e62e89104b"

## N, en secondes. 5 s couvrent l'embrasement de la mine (1,6 s) et le temps de
## l'exploiter ; elles restent sous la plus courte vie d'un gadget continu (la
## poussière, 7,5 s) et très en dessous de la recharge (60 s) : au plus une pose
## par fenêtre.
const FENETRE_EFFET_S := 5.0

## ⚠️ **Mêmes clés que `GADGET_NUMBERS`** (`supabase/functions/_shared/match_report.ts`) :
## `tools/test_telemetrie_gadgets.gd` compare les deux listes, dans les deux sens. Une
## clé ajoutée d'un seul côté tomberait sans bruit au tamis du serveur.
##
## ⚠️ **Toucher à cette liste, c'est changer la FORME du bloc** : `FORME_TEMOIN`
## rougira, et il demande de trancher `VERSION` — et la requête de `docs/SUPABASE.md`
## qui filtre dessus — avant de recopier l'empreinte.
const COMPTEURS: Array[String] = ["poses", "morts_balle", "morts_fin_de_vie",
	"allumages_passage", "allumages_balle", "bascules_allume", "bascules_eteint",
	"batterie_vide", "morts_adverses_apres_effet", "morts_propres_apres_effet"]
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


## L'allumage d'un gadget — la mine, qu'on l'ait abordée ou abattue. Les deux cas
## comptent à part depuis le lot H, et `par_balle` vient de l'ORDRE : le client ne
## saurait pas le calculer, il n'encaisse aucune balle.
##
## ⚠️ **Aucune valeur par défaut**, et c'est délibéré : un appelant qui oublierait la
## cause rangerait tout en « passage », c'est-à-dire exactement le faux que ce lot
## corrige, et sans un mot. Les deux causes restent un EFFET — la mine change la
## partie qu'on l'ait enjambée ou tirée.
func allumage(pid: int, t: float, par_balle: bool) -> void:
	if not _valide(pid):
		return
	_cotes[pid]["allumages_balle" if par_balle else "allumages_passage"] += 1
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
