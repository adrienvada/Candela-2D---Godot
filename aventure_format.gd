class_name AventureFormat
extends RefCounted

## Le FORMAT de l'aventure et son validateur — chantier SOLO, étape S6.
##
## L'aventure est faite de DONNÉES, écrites à la main par des sessions (l'éditeur de cartes n'est pas étendu : « on verra
## ensuite »). Un chapitre est un dossier ; un niveau est une salle, un fichier. Ce fichier dit ce que ces fichiers peuvent
## contenir, et REFUSE tout le reste.
##
## ## Pourquoi un validateur strict, et jamais un repli
##
## Une salle mal écrite doit se VOIR, pas devenir en silence une autre salle. Un profil de PNJ inconnu qui deviendrait « un PNJ
## par défaut », une case hors de la carte ramenée au sol le plus proche, un plafonnier de rayon 40 borné à 9 sans rien dire : chacun
## donnerait un niveau jouable et FAUX, que personne ne saurait corriger parce que rien ne l'aurait signalé. Ici, chaque défaut est
## une phrase (`valider_*` rend la liste), `charger_chapitre` la crie (`push_error`, une ligne par défaut) et rend vide : le chapitre
## n'apparaît pas, il n'est pas joué de travers. Même contrat que `ProfilBot.pnj_nomme` (`null` sur un nom inconnu).
##
## ## L'arborescence
##
## ```
## res://assets/solo/                  ← LECTURE SEULE, comme res://assets/maps/ (aucun code ne l'écrit)
##   chapitre_00/
##     chapitre.json                   ← le manifeste
##     niveau_01.json … niveau_10.json ← une salle par fichier
##   chapitre_01/ …
## ```
##
## ## Le manifeste (`chapitre.json`)
##
## ```json
## { "version": 1, "numero": 0, "titre": "L'initiation",
##   "classe_debloquee": "pistolet", "classe_imposee": "pistolet",
##   "niveaux": ["niveau_01.json", "niveau_02.json", "…"] }
## ```
## - `numero` : 0 à 10. Onze chapitres (Adrien, 2026-10-02) : l'initiation, puis dix.
## - `classe_debloquee` : le SLUG DU CODE de la classe que la fin du chapitre offre (`ClassData.slug()` : le Parasite est
##   `pistolet`, l'Illusionniste `fusil`, le Braconnier `arbalete`, le Terrassier `pompe`). **L'ordre est celui du rang en ligne**
##   (`ORDRE_DES_CLASSES`) : le chapitre N offre la classe de rang N+1. Le chapitre 10 n'en offre AUCUNE (« on verra plus tard
##   ce qu'on gagne », SOLO-Q8) : la clé y est absente ou vide, et la renseigner est refusé.
## - `classe_imposee` (facultatif) : le chapitre se joue dans cette classe, quelle que soit celle qu'on a choisie. Le chapitre 0
##   l'exige — il PRÊTE le Parasite, qu'il donne au boss.
## - `niveaux` : la liste ordonnée des fichiers du même dossier. Le dernier est le BOSS, et lui seul.
##
## ## Un niveau
##
## ```json
## { "version": 1,
##   "titre": "Le premier pas",
##   "intention": "Une silhouette sous la lampe. Avance, vise, tire.",
##   "boss": false,
##   "carte": { "version": 4, "grid_size": {"x": 16, "y": 16}, "floor": "…", "walls": "…", "low_walls": "" },
##   "joueur": { "case": [3, 8], "orientation": 0 },
##   "plafonniers": [ { "case": [12, 8], "rayon": 4.0, "intensite": 1.2 } ],
##   "pnj": [ { "case": [12, 8], "orientation": 180, "profil": "immobile_sourd_aveugle" } ] }
## ```
## - `carte` : une carte de `map_codec.gd` (v4, runs RLE), EMBARQUÉE — jamais un renvoi vers `assets/maps/`, dont aucune carte de
##   duel n'est ainsi touchée. Les points d'apparition se disent dans `joueur` : un `spawn_p1` qui les contredit est refusé, et
##   `spawn_p2` est ignoré (J2 n'existe pas en aventure : le jeu le gare, caché, sous le premier PNJ).
## - `joueur` : `case` (praticable) et `orientation` en DEGRÉS (0 : vers l'est, positif : vers le bas de l'écran, le sens de
##   `rotation` dans Godot).
## - `plafonniers` (facultatif) : le format de `Plafonnier.poser` — `case`, `rayon` (cases), `intensite`, `teinte` ; chaque valeur
##   doit être DANS ses bornes (un plafonnier n'est pas borné en silence).
## - `pnj` : au moins un ; chacun a une `case` praticable, une `orientation`, un `profil` (le NOM du catalogue,
##   `ProfilBot.noms_du_catalogue()` — jamais une suite de champs), et selon son déplacement : une `ronde` (au moins deux cases,
##   toutes praticables et atteignables) ou une `zone` (`[x, y, largeur, hauteur]` en cases, qui contient la case du PNJ).
##   `classe` (facultatif) : le slug de sa classe — la classe par défaut, le Parasite, sinon.
##   `equipe` (facultatif, booléen) : vrai, le PNJ s'ÉQUIPE comme un bot de son palier (`ProfilBot.equiper_un_pnj`) et se sert du gadget
##   de la classe qu'il porte. Faux ou absent : aucun outil, comme tout PNJ du catalogue. Refusée sur un PNJ sourd et aveugle (il n'agit
##   pas) et sur le boss (son profil est déjà équipé). Pas de clé : exactement le PNJ d'avant (S8).
## - `boss` : vrai pour le dernier niveau du chapitre. Il porte alors UN seul PNJ, de profil `boss` (le profil d'entraînement
##   NORMAL : `ProfilBot.boss()`), et sa `classe` est celle que le chapitre débloque.
##
## ## Sans dépendance
##
## Ni autoload ni nœud : une suite en `--script` charge ce fichier seul (`tools/test_aventure_format.gd`). Les cases sont celles de
## la grille de la carte ; « praticable » est la définition du bot (`NavigationBot.est_praticable` : libre, et pas prise en étau
## entre deux solides — un corps de 36 px n'y passe pas).

const ProfilT := preload("res://profil_bot.gd")
const NavigationT := preload("res://navigation_bot.gd")
const CodecT := preload("res://map_codec.gd")
const PlafonnierT := preload("res://plafonnier.gd")

const VERSION := 1

## Onze chapitres, de 0 à 10.
const CHAPITRE_MAX := 10
## Un chapitre livré compte dix salles, dont le boss (Adrien, 2026-10-02).
const NIVEAUX_PAR_CHAPITRE := 10

## Le slug de la classe que chaque chapitre (0 à 9) débloque : l'ORDRE DU RANG en ligne — Parasite 1, Fumiste 2, Illusionniste 3,
## Braconnier 4, Terrassier 5, Incendiaire 6, Sentinelle 7, Occulteur 8, Allumeur 9, Spectre 10. Les slugs sont ceux du code
## (`ClassData.slug()`) : `tools/test_aventure_partie.gd` les confronte au catalogue du jeu (rang = indice + 1).
const ORDRE_DES_CLASSES: Array[String] = ["pistolet", "fumiste", "fusil", "arbalete", "pompe", "incendiaire", "sentinelle",
	"occulteur", "allumeur", "spectre"]

## La classe d'un PNJ qui n'en dit pas : la classe par défaut (le bot « porte la classe par défaut », décision d'Adrien).
const CLASSE_PAR_DEFAUT := "pistolet"

## Combien de PNJ et de plafonniers au plus dans une salle : les corps supplémentaires de la vue iso et leurs capteurs sont en
## nombre fini (`Presentation3D.FIGURANTS_MAX`), et une salle de plus de huit lumières n'est pas une salle d'initiation.
const PNJ_MAX := 8
const PLAFONNIERS_MAX := 8
## La longueur de la phrase d'intention : une phrase, pas un paragraphe.
const INTENTION_MAX := 200

## Le profil que seul un niveau de boss peut porter.
const PROFIL_BOSS := "boss"

const _CLES_MANIFESTE := ["version", "numero", "titre", "classe_debloquee", "classe_imposee", "niveaux"]
const _CLES_MANIFESTE_REQUISES := ["version", "numero", "titre", "niveaux"]
const _CLES_NIVEAU := ["version", "titre", "intention", "boss", "carte", "joueur", "plafonniers", "pnj"]
const _CLES_NIVEAU_REQUISES := ["version", "titre", "intention", "carte", "joueur", "pnj"]
const _CLES_JOUEUR := ["case", "orientation"]
const _CLES_PNJ := ["case", "orientation", "profil", "classe", "equipe", "ronde", "zone", "temperament"]
const _CLES_PLAFONNIER := ["case", "rayon", "intensite", "teinte"]

## Où l'on cherche les chapitres livrés. Les suites la déplacent vers `res://tools/aventure_essai` : le chapitre d'essai n'entre
## JAMAIS dans `assets/solo/`.
static var racine := "res://assets/solo"
## Combien de salles un chapitre doit compter pour être accepté par `chapitres_livres` (0 : aucune exigence — le chapitre d'essai).
static var niveaux_attendus := NIVEAUX_PAR_CHAPITRE
static var _cache: Dictionary = {}


# ---------------------------------------------------------------------------
# LE MANIFESTE
# ---------------------------------------------------------------------------

## Les défauts du manifeste d'un chapitre — vide s'il est bon. Ne lit aucun fichier.
static func valider_manifeste(m: Dictionary) -> Array[String]:
	var e: Array[String] = []
	_cles(m, _CLES_MANIFESTE, _CLES_MANIFESTE_REQUISES, "manifeste", e)
	if m.has("version") and not (_est_entier(m["version"]) and int(m["version"]) == VERSION):
		e.append("manifeste : « version » vaut %d (reçu %s)" % [VERSION, str(m["version"])])
	var numero := -1
	if m.has("numero"):
		if _est_entier(m["numero"]) and int(m["numero"]) >= 0 and int(m["numero"]) <= CHAPITRE_MAX:
			numero = int(m["numero"])
		else:
			e.append("manifeste : « numero » est un entier de 0 à %d (reçu %s)" % [CHAPITRE_MAX, str(m["numero"])])
	if m.has("titre") and not _texte_non_vide(m["titre"]):
		e.append("manifeste : « titre » est un texte non vide")
	# La classe débloquée : celle du rang, ou AUCUNE pour le chapitre 10.
	var offerte: Variant = m.get("classe_debloquee", "")
	if numero >= 0:
		if numero == CHAPITRE_MAX:
			if offerte != null and String(offerte) != "":
				e.append("manifeste : le chapitre %d n'offre aucune classe (« on verra plus tard », SOLO-Q8) — « classe_debloquee » est vide ou absente" % CHAPITRE_MAX)
		elif not m.has("classe_debloquee") or not (offerte is String):
			e.append("manifeste : le chapitre %d débloque « %s » — « classe_debloquee » est requise" % [numero, ORDRE_DES_CLASSES[numero]])
		elif String(offerte) != ORDRE_DES_CLASSES[numero]:
			e.append("manifeste : le chapitre %d débloque « %s », l'ordre du rang en ligne (reçu « %s »)" % [numero, ORDRE_DES_CLASSES[numero], String(offerte)])
	if m.has("classe_imposee"):
		var imposee: Variant = m["classe_imposee"]
		if not (imposee is String) or not ORDRE_DES_CLASSES.has(String(imposee)):
			e.append("manifeste : « classe_imposee » est un slug de classe connu (reçu %s)" % str(imposee))
	if numero == 0 and String(m.get("classe_imposee", "")) != ORDRE_DES_CLASSES[0]:
		e.append("manifeste : le chapitre 0 PRÊTE le Parasite (« classe_imposee » : « %s »)" % ORDRE_DES_CLASSES[0])
	if m.has("niveaux"):
		var liste: Variant = m["niveaux"]
		if not (liste is Array) or (liste as Array).is_empty():
			e.append("manifeste : « niveaux » est une liste non vide de fichiers")
		else:
			var vus := {}
			for f in (liste as Array):
				if not (f is String) or not String(f).ends_with(".json") or String(f).contains("/") or String(f).contains("\\") \
						or String(f).contains("..") or String(f) == "chapitre.json":
					e.append("manifeste : « niveaux » ne cite que des fichiers .json du dossier (reçu %s)" % str(f))
				elif vus.has(f):
					e.append("manifeste : le niveau « %s » est cité deux fois" % String(f))
				vus[f] = true
	return e


# ---------------------------------------------------------------------------
# UN NIVEAU
# ---------------------------------------------------------------------------

## Les défauts d'un niveau — vide s'il est bon. Ne lit aucun fichier. `niveau` est le dictionnaire du JSON.
static func valider_niveau(niveau: Dictionary) -> Array[String]:
	var e: Array[String] = []
	_cles(niveau, _CLES_NIVEAU, _CLES_NIVEAU_REQUISES, "niveau", e)
	if niveau.has("version") and not (_est_entier(niveau["version"]) and int(niveau["version"]) == VERSION):
		e.append("niveau : « version » vaut %d (reçu %s)" % [VERSION, str(niveau["version"])])
	if niveau.has("titre") and not _texte_non_vide(niveau["titre"]):
		e.append("niveau : « titre » est un texte non vide")
	if niveau.has("intention"):
		if not _texte_non_vide(niveau["intention"]):
			e.append("niveau : « intention » est une phrase non vide")
		elif String(niveau["intention"]).length() > INTENTION_MAX:
			e.append("niveau : « intention » est UNE phrase (%d signes au plus, reçu %d)" % [INTENTION_MAX, String(niveau["intention"]).length()])
	if niveau.has("boss") and not (niveau["boss"] is bool):
		e.append("niveau : « boss » est vrai ou faux (reçu %s)" % str(niveau["boss"]))
	var boss := niveau.get("boss", false) is bool and bool(niveau.get("boss", false))

	# --- Le joueur
	var case_joueur: Variant = null
	if niveau.has("joueur"):
		var j: Variant = niveau["joueur"]
		if not (j is Dictionary):
			e.append("joueur : un dictionnaire { case, orientation } (reçu %s)" % type_string(typeof(j)))
		else:
			_cles(j, _CLES_JOUEUR, ["case"], "joueur", e)
			if (j as Dictionary).has("case"):
				case_joueur = _lire_case(j["case"])
				if case_joueur == null:
					e.append("joueur : « case » est [x, y] en entiers (reçu %s)" % str(j["case"]))
			if (j as Dictionary).has("orientation") and not _est_nombre_fini(j["orientation"]):
				e.append("joueur : « orientation » est un nombre de degrés (reçu %s)" % str(j["orientation"]))

	# --- La carte : embarquée, et validée par le codec du jeu
	var navigation: NavigationBot = null
	if niveau.has("carte"):
		var c: Variant = niveau["carte"]
		if not (c is Dictionary):
			e.append("carte : un dictionnaire de map_codec.gd (reçu %s)" % type_string(typeof(c)))
		else:
			var lue := _carte_normalisee(niveau, e)
			if not lue.is_empty():
				navigation = NavigationT.depuis_carte(lue)

	# --- Le reste se juge sur la carte : sans elle, rien à dire des cases
	if navigation != null and case_joueur != null:
		_case_praticable(navigation, case_joueur, "joueur", e)
	var plafonniers: Variant = niveau.get("plafonniers", [])
	if niveau.has("plafonniers"):
		if not (plafonniers is Array):
			e.append("plafonniers : une liste (reçu %s)" % type_string(typeof(plafonniers)))
		else:
			if (plafonniers as Array).size() > PLAFONNIERS_MAX:
				e.append("plafonniers : %d au plus (reçu %d)" % [PLAFONNIERS_MAX, (plafonniers as Array).size()])
			for i in (plafonniers as Array).size():
				_valider_plafonnier(plafonniers[i], i, navigation, e)
	if niveau.has("pnj"):
		var liste: Variant = niveau["pnj"]
		if not (liste is Array) or (liste as Array).is_empty():
			e.append("pnj : une liste d'au moins un PNJ — on l'emporte en éliminant tout le monde, une salle vide est gagnée d'avance")
		else:
			if (liste as Array).size() > PNJ_MAX:
				e.append("pnj : %d au plus (reçu %d)" % [PNJ_MAX, (liste as Array).size()])
			var cases_prises := {}
			if case_joueur != null:
				cases_prises[case_joueur] = "le joueur"
			for i in (liste as Array).size():
				_valider_pnj(liste[i], i, boss, navigation, cases_prises, e)
			_valider_boss(liste, boss, e)
	return e


static func _valider_plafonnier(p: Variant, i: int, navigation: NavigationBot, e: Array[String]) -> void:
	var ctx := "plafonnier %d" % i
	if not (p is Dictionary):
		e.append("%s : un dictionnaire (reçu %s)" % [ctx, type_string(typeof(p))])
		return
	var d: Dictionary = p
	_cles(d, _CLES_PLAFONNIER, ["case"], ctx, e)
	# Le format de `Plafonnier.poser` : la même vérité, pas une seconde.
	var defaut := PlafonnierT.valider(d)
	if defaut != "":
		e.append("%s : %s" % [ctx, defaut])
		return
	var c: Variant = _lire_case(d["case"])
	if c == null:
		e.append("%s : « case » est [x, y] en entiers (reçu %s)" % [ctx, str(d["case"])])
	elif navigation != null:
		var cc: Vector2i = c
		if cc.x < 0 or cc.y < 0 or cc.x >= navigation.taille.x or cc.y >= navigation.taille.y:
			e.append("%s : la case %s est hors de la carte (%d × %d)" % [ctx, str(cc), navigation.taille.x, navigation.taille.y])
		elif not navigation.est_libre(cc):
			e.append("%s : la case %s est un mur ou du vide — la lampe y serait dans la pierre" % [ctx, str(cc)])
	# Les bornes sont DITES, jamais appliquées en silence (`Plafonnier.normaliser` borne, et ce ne serait plus la salle écrite).
	if d.has("rayon") and (float(d["rayon"]) < PlafonnierT.RAYON_MIN or float(d["rayon"]) > PlafonnierT.RAYON_MAX):
		e.append("%s : « rayon » est entre %s et %s cases (reçu %s)" % [ctx, str(PlafonnierT.RAYON_MIN), str(PlafonnierT.RAYON_MAX), str(d["rayon"])])
	if d.has("intensite") and (float(d["intensite"]) < PlafonnierT.INTENSITE_MIN or float(d["intensite"]) > PlafonnierT.INTENSITE_MAX):
		e.append("%s : « intensite » est entre %s et %s (reçu %s)" % [ctx, str(PlafonnierT.INTENSITE_MIN), str(PlafonnierT.INTENSITE_MAX), str(d["intensite"])])
	if d.has("teinte") and not (d["teinte"] is String and Color.html_is_valid(String(d["teinte"]))):
		e.append("%s : « teinte » est un texte HTML « #rrggbb » (reçu %s)" % [ctx, str(d["teinte"])])


static func _valider_pnj(p: Variant, i: int, boss: bool, navigation: NavigationBot, cases_prises: Dictionary, e: Array[String]) -> void:
	var ctx := "pnj %d" % i
	if not (p is Dictionary):
		e.append("%s : un dictionnaire (reçu %s)" % [ctx, type_string(typeof(p))])
		return
	var d: Dictionary = p
	_cles(d, _CLES_PNJ, ["case", "profil"], ctx, e)
	var c: Variant = null
	if d.has("case"):
		c = _lire_case(d["case"])
		if c == null:
			e.append("%s : « case » est [x, y] en entiers (reçu %s)" % [ctx, str(d["case"])])
		elif navigation != null:
			_case_praticable(navigation, c, ctx, e)
			if cases_prises.has(c):
				e.append("%s : la case %s est déjà prise par %s" % [ctx, str(c), cases_prises[c]])
			else:
				cases_prises[c] = "le pnj %d" % i
	if d.has("orientation") and not _est_nombre_fini(d["orientation"]):
		e.append("%s : « orientation » est un nombre de degrés (reçu %s)" % [ctx, str(d["orientation"])])
	if d.has("classe") and not (d["classe"] is String and ORDRE_DES_CLASSES.has(String(d["classe"]))):
		e.append("%s : « classe » est un slug de classe connu — %s (reçu %s)" % [ctx, ", ".join(ORDRE_DES_CLASSES), str(d["classe"])])
	if d.has("equipe") and not (d["equipe"] is bool):
		e.append("%s : « equipe » est vrai ou faux (reçu %s)" % [ctx, str(d["equipe"])])
	# Le tempérament (2026-10-04) : un nom de `ProfilBot.NOMS_TEMPERAMENT`. Refusé sur le boss (réglé au banc) et sur un PNJ qui n'agit pas.
	if d.has("temperament") and not (d["temperament"] is String and ProfilT.NOMS_TEMPERAMENT.has(String(d["temperament"]))):
		e.append("%s : « temperament » est l'un de %s (reçu %s)" % [ctx, ", ".join(ProfilT.NOMS_TEMPERAMENT.keys()), str(d["temperament"])])
	if not d.has("profil"):
		return
	if not (d["profil"] is String):
		e.append("%s : « profil » est le NOM d'un profil du catalogue (reçu %s)" % [ctx, str(d["profil"])])
		return
	var nom := String(d["profil"])
	var deplacement := -1
	if nom == PROFIL_BOSS:
		if not boss:
			e.append("%s : le profil « boss » n'existe que dans le niveau de boss (« boss » : true)" % ctx)
		if d.has("equipe"):
			e.append("%s : « equipe » est refusée sur le boss — son profil est déjà équipé (le gadget de sa classe)" % ctx)
		if d.has("temperament"):
			e.append("%s : « temperament » est refusé sur le boss — il est réglé au banc, tel quel" % ctx)
		deplacement = ProfilT.Deplacement.LIBRE
	else:
		var profil := ProfilT.pnj_nomme(nom)
		if profil == null:
			e.append("%s : profil inconnu « %s » — un nom de ProfilBot.noms_du_catalogue() (immobile_sourd_aveugle, ronde_voit_lent…), ou « boss »" % [ctx, nom])
			return
		deplacement = profil.deplacement
		if (d.get("equipe", false) is bool and d.get("equipe", false)) and not profil.agit:
			e.append("%s : « equipe » est refusée sur « %s » — un PNJ sourd et aveugle n'agit pas, il n'aurait aucun usage de ses outils" % [ctx, nom])
		if d.has("temperament") and not profil.agit:
			e.append("%s : « temperament » est refusé sur « %s » — un PNJ sourd et aveugle n'agit pas, il n'a pas de caractère à montrer" % [ctx, nom])
	# Ses points de ronde et sa zone, selon son déplacement : chacun DOIT exister quand il sert, et ne doit pas exister sinon.
	if deplacement == ProfilT.Deplacement.RONDE:
		_valider_ronde(d, c, ctx, navigation, e)
	elif d.has("ronde"):
		e.append("%s : « ronde » ne se pose que sur un profil de ronde (« %s » ne fait pas de ronde)" % [ctx, nom])
	if deplacement == ProfilT.Deplacement.ZONE:
		_valider_zone(d, c, ctx, navigation, e)
	elif d.has("zone"):
		e.append("%s : « zone » ne se pose que sur un profil de zone (« %s » ne s'y tient pas)" % [ctx, nom])


static func _valider_ronde(d: Dictionary, case_pnj: Variant, ctx: String, navigation: NavigationBot, e: Array[String]) -> void:
	if not d.has("ronde"):
		e.append("%s : une ronde sans points — « ronde » liste au moins deux cases" % ctx)
		return
	var pts: Variant = d["ronde"]
	if not (pts is Array) or (pts as Array).size() < 2:
		e.append("%s : une ronde sans points — « ronde » liste au moins deux cases [x, y] (reçu %s)" % [ctx, str(pts)])
		return
	for k in (pts as Array).size():
		var pt: Variant = _lire_case(pts[k])
		if pt == null:
			e.append("%s : le point de ronde %d est [x, y] en entiers (reçu %s)" % [ctx, k, str(pts[k])])
		elif navigation != null:
			_case_praticable(navigation, pt, "%s, point de ronde %d" % [ctx, k], e)
			# Un point que le PNJ n'atteindrait jamais serait sauté par le bot, en silence : la ronde ne serait plus celle qu'on a écrite.
			if case_pnj != null and navigation.est_praticable(case_pnj) and navigation.est_praticable(pt) \
					and not navigation.cases_atteignables(case_pnj).has(pt):
				e.append("%s : le point de ronde %d %s n'est pas atteignable depuis la case du PNJ %s" % [ctx, k, str(pt), str(case_pnj)])


static func _valider_zone(d: Dictionary, case_pnj: Variant, ctx: String, navigation: NavigationBot, e: Array[String]) -> void:
	if not d.has("zone"):
		e.append("%s : une zone sans rectangle — « zone » est [x, y, largeur, hauteur]" % ctx)
		return
	var z: Variant = d["zone"]
	var ok: bool = z is Array and (z as Array).size() == 4
	if ok:
		for v in (z as Array):
			ok = ok and _est_entier(v)
	if not ok:
		e.append("%s : « zone » est [x, y, largeur, hauteur] en entiers (reçu %s)" % [ctx, str(z)])
		return
	var r := Rect2i(int(z[0]), int(z[1]), int(z[2]), int(z[3]))
	if r.size.x < 1 or r.size.y < 1:
		e.append("%s : la zone %s est vide — un profil de zone dont le rectangle est vide se comporterait en profil libre" % [ctx, str(r)])
		return
	if navigation != null and (r.position.x < 0 or r.position.y < 0 or r.end.x > navigation.taille.x or r.end.y > navigation.taille.y):
		e.append("%s : la zone %s sort de la carte (%d × %d)" % [ctx, str(r), navigation.taille.x, navigation.taille.y])
	if case_pnj != null and not r.has_point(case_pnj):
		e.append("%s : la zone %s ne contient pas la case du PNJ %s — il y naît" % [ctx, str(r), str(case_pnj)])


static func _valider_boss(liste: Array, boss: bool, e: Array[String]) -> void:
	if not boss:
		return
	if liste.size() != 1:
		e.append("boss : le niveau de boss porte UN seul PNJ (« juste un bot en mode moyen »), reçu %d" % liste.size())
		return
	var p: Variant = liste[0]
	if p is Dictionary:
		if String((p as Dictionary).get("profil", "")) != PROFIL_BOSS:
			e.append("boss : le PNJ du niveau de boss a le profil « %s » (reçu %s)" % [PROFIL_BOSS, str((p as Dictionary).get("profil", ""))])
		if not (p as Dictionary).has("classe"):
			e.append("boss : le boss porte la classe du chapitre — « classe » est requise")


# ---------------------------------------------------------------------------
# UN CHAPITRE : le manifeste, ses niveaux, et ce qui ne se juge qu'ensemble
# ---------------------------------------------------------------------------

## Les défauts d'un chapitre chargé : son manifeste, chacun de ses niveaux (préfixés de leur fichier), et les règles qui lient les
## deux — le dernier niveau est le boss, et lui seul ; le boss porte la classe que le chapitre débloque. `niveaux` : les
## dictionnaires JSON, dans l'ordre du manifeste. `attendus` : le nombre de salles exigé (0 : aucune exigence).
static func valider_chapitre(manifeste: Dictionary, niveaux: Array, attendus: int = 0) -> Array[String]:
	var e: Array[String] = valider_manifeste(manifeste)
	var fichiers: Array = manifeste.get("niveaux", []) if manifeste.get("niveaux", []) is Array else []
	if niveaux.size() != fichiers.size():
		e.append("chapitre : %d fichiers cités, %d niveaux lus" % [fichiers.size(), niveaux.size()])
		return e
	if attendus > 0 and niveaux.size() != attendus:
		e.append("chapitre : %d salles exigées (le dixième est le boss), %d écrites" % [attendus, niveaux.size()])
	var offerte := String(manifeste.get("classe_debloquee", "")) if manifeste.get("classe_debloquee", "") is String else ""
	for i in niveaux.size():
		var n: Variant = niveaux[i]
		var nom := String(fichiers[i]) if fichiers[i] is String else "niveau %d" % i
		if not (n is Dictionary):
			e.append("%s : un dictionnaire JSON" % nom)
			continue
		for defaut in valider_niveau(n):
			e.append("%s : %s" % [nom, defaut])
		var est_boss: bool = (n as Dictionary).get("boss", false) is bool and bool((n as Dictionary).get("boss", false))
		var dernier := i == niveaux.size() - 1
		if dernier and not est_boss:
			e.append("%s : le dernier niveau d'un chapitre est le BOSS (« boss » : true) — un chapitre sans boss final est refusé" % nom)
		elif not dernier and est_boss:
			e.append("%s : un niveau de boss n'est jamais au milieu d'un chapitre (« boss » : false hors du dernier)" % nom)
		if est_boss and offerte != "":
			var pnj: Variant = (n as Dictionary).get("pnj", [])
			if pnj is Array and (pnj as Array).size() == 1 and (pnj[0] is Dictionary) \
					and String((pnj[0] as Dictionary).get("classe", "")) != offerte:
				e.append("%s : le boss porte la classe que le chapitre débloque, « %s » (reçu « %s »)" % [nom, offerte, String((pnj[0] as Dictionary).get("classe", ""))])
	return e


## Lit un chapitre sur disque SANS le juger : `{ ok, erreurs, manifeste, niveaux }` (`niveaux` : les dictionnaires, dans l'ordre).
## Une erreur de lecture (fichier absent, JSON illisible) est un défaut comme un autre.
static func lire_chapitre(dossier: String) -> Dictionary:
	var sortie := {"ok": false, "erreurs": [] as Array[String], "manifeste": {}, "niveaux": [], "dossier": dossier}
	var erreurs: Array[String] = sortie["erreurs"]
	var manifeste := _lire_json(dossier.path_join("chapitre.json"), erreurs)
	if manifeste.is_empty():
		return sortie
	sortie["manifeste"] = manifeste
	var fichiers: Variant = manifeste.get("niveaux", [])
	if fichiers is Array:
		for f in (fichiers as Array):
			if f is String and not String(f).contains("/") and not String(f).contains(".."):
				sortie["niveaux"].append(_lire_json(dossier.path_join(String(f)), erreurs))
			else:
				sortie["niveaux"].append({})
	sortie["ok"] = erreurs.is_empty()
	return sortie


## Charge un chapitre prêt à jouer, ou VIDE s'il a le moindre défaut — chacun est crié (`push_error`), un par ligne.
## `{ numero, titre, classe_debloquee, classe_imposee, dossier, niveaux: [niveau préparé] }`.
static func charger_chapitre(dossier: String, attendus: int = -1) -> Dictionary:
	var lu := lire_chapitre(dossier)
	var erreurs: Array[String] = []
	erreurs.append_array(lu["erreurs"])
	var manifeste: Dictionary = lu["manifeste"]
	if not manifeste.is_empty() and erreurs.is_empty():
		erreurs.append_array(valider_chapitre(manifeste, lu["niveaux"], niveaux_attendus if attendus < 0 else attendus))
	if not erreurs.is_empty():
		for defaut in erreurs:
			push_error("AventureFormat : %s — %s" % [dossier, defaut])
		return {}
	var chapitre := {
		"numero": int(manifeste["numero"]),
		"titre": String(manifeste["titre"]),
		"classe_debloquee": String(manifeste.get("classe_debloquee", "")),
		"classe_imposee": String(manifeste.get("classe_imposee", "")),
		"dossier": dossier,
		"niveaux": [],
	}
	var fichiers: Array = manifeste["niveaux"]
	for i in fichiers.size():
		var prepare := preparer_niveau((lu["niveaux"] as Array)[i])
		prepare["fichier"] = String(fichiers[i])
		(chapitre["niveaux"] as Array).append(prepare)
	return chapitre


## Les chapitres livrés : `{ numero: chapitre }`, ceux qui se chargent sans défaut. Un dossier mal écrit crie et n'apparaît pas ;
## un numéro qui contredit le nom de son dossier, ou qui figure deux fois, est refusé de même. Mis en cache : l'écran de l'aventure
## le relit à chaque ouverture, et valider coûte une grille de navigation par salle.
static func chapitres_livres() -> Dictionary:
	var cle := "%s|%d" % [racine, niveaux_attendus]
	if _cache.has(cle):
		return _cache[cle]
	var sortie := {}
	# Une racine absente est une aventure sans chapitre livré (S7 n'a pas encore écrit les salles), pas une erreur.
	if not DirAccess.dir_exists_absolute(racine):
		_cache[cle] = sortie
		return sortie
	var dossiers := DirAccess.get_directories_at(racine)
	dossiers.sort()
	for d in dossiers:
		if not d.begins_with("chapitre_") or not d.substr(9).is_valid_int():
			continue
		var chapitre := charger_chapitre(racine.path_join(d))
		if chapitre.is_empty():
			continue
		if int(chapitre["numero"]) != d.substr(9).to_int():
			push_error("AventureFormat : %s — le numéro du manifeste (%d) contredit le nom du dossier" % [d, int(chapitre["numero"])])
			continue
		if sortie.has(int(chapitre["numero"])):
			push_error("AventureFormat : %s — le chapitre %d existe déjà" % [d, int(chapitre["numero"])])
			continue
		sortie[int(chapitre["numero"])] = chapitre
	_cache[cle] = sortie
	return sortie


## Oublie les chapitres chargés : une suite qui change `racine` ou écrit un chapitre relit ensuite le disque.
static func oublier_le_cache() -> void:
	_cache.clear()


## La classe qu'offre la fin du chapitre `numero` : son slug, ou `""` (chapitre 10, ou numéro hors bornes).
static func classe_du_chapitre(numero: int) -> String:
	return ORDRE_DES_CLASSES[numero] if numero >= 0 and numero < ORDRE_DES_CLASSES.size() else ""


# ---------------------------------------------------------------------------
# UN NIVEAU PRÊT À JOUER
# ---------------------------------------------------------------------------

## Le niveau tel que le jeu le joue, tiré d'un niveau VALIDÉ (`valider_niveau` vide) : les cases en `Vector2i`, les angles en
## radians, la carte complétée de ses points d'apparition. Ne valide rien — appeler ceci sur un niveau refusé est une erreur de
## l'appelant, que `charger_chapitre` ne commet pas.
static func preparer_niveau(niveau: Dictionary) -> Dictionary:
	var joueur: Dictionary = niveau["joueur"]
	var cj: Vector2i = _lire_case(joueur["case"])
	var pnj: Array = []
	for p: Dictionary in niveau["pnj"]:
		var entree := {
			"case": _lire_case(p["case"]),
			"rotation": deg_to_rad(float(p.get("orientation", 180.0))),
			"profil_nom": String(p["profil"]),
			"classe": String(p.get("classe", CLASSE_PAR_DEFAUT)),
			"equipe": bool(p.get("equipe", false)),
			"temperament": String(p.get("temperament", "")),
			"ronde": [] as Array[Vector2i],
			"zone": Rect2i(),
		}
		for pt in p.get("ronde", []):
			(entree["ronde"] as Array[Vector2i]).append(_lire_case(pt))
		if p.has("zone"):
			var z: Array = p["zone"]
			entree["zone"] = Rect2i(int(z[0]), int(z[1]), int(z[2]), int(z[3]))
		pnj.append(entree)
	var plafonniers: Array = []
	for pl: Dictionary in niveau.get("plafonniers", []):
		var entree := pl.duplicate(true)
		entree["case"] = _lire_case(pl["case"])
		plafonniers.append(entree)
	var carte := _carte_avec_apparitions(niveau["carte"], cj, pnj[0]["case"])
	return {
		"titre": String(niveau["titre"]),
		"intention": String(niveau["intention"]),
		"boss": bool(niveau.get("boss", false)),
		"carte": carte,
		"joueur": {"case": cj, "rotation": deg_to_rad(float(joueur.get("orientation", 0.0)))},
		"plafonniers": plafonniers,
		"pnj": pnj,
	}


## Le profil d'un PNJ préparé : celui du catalogue (`ProfilBot.pnj_nomme`) ou le boss, ses points de ronde et sa zone posés.
## Neuf à chaque appel : un profil est une ressource que le bot ne doit pas partager avec la tentative d'avant.
static func profil_du_pnj(entree: Dictionary) -> ProfilBot:
	var nom := String(entree["profil_nom"])
	# Le boss est réglé à SA classe (`ProfilBot.REGLAGES_BOSS`, S9b) : la même entrée dit la classe qu'il porte et le profil qui la sert.
	var profil := ProfilT.boss(String(entree.get("classe", ""))) if nom == PROFIL_BOSS else ProfilT.pnj_nomme(nom)
	if profil == null:
		push_error("AventureFormat : profil de PNJ inconnu « %s »" % nom)
		return null
	# `equipe` : ce PNJ se sert des outils de son palier et du gadget de sa classe. Sans la clé, le profil du catalogue reste exactement celui d'avant.
	if bool(entree.get("equipe", false)) and nom != PROFIL_BOSS:
		ProfilT.equiper_un_pnj(profil, ProfilT.palier_du_nom(nom))
	# Le tempérament APRÈS l'équipement : il décide de la torche (le guetteur l'allume, l'embusqué l'éteint), par-dessus les outils.
	var temperament := String(entree.get("temperament", ""))
	if temperament != "" and nom != PROFIL_BOSS:
		ProfilT.appliquer_temperament(profil, int(ProfilT.NOMS_TEMPERAMENT[temperament]))
	profil.points_ronde.assign(entree["ronde"])
	profil.zone = entree["zone"]
	return profil


# ---------------------------------------------------------------------------
# PRIVÉ
# ---------------------------------------------------------------------------

## La carte du niveau, complétée de ses apparitions et normalisée par le codec ; vide (et un défaut dit) si elle est refusée. Les
## points d'apparition se disent dans `joueur` : un `spawn_p1` qui les contredit est un défaut ; `spawn_p2` est écrasé (J2 est garé
## sous le premier PNJ).
static func _carte_normalisee(niveau: Dictionary, e: Array[String]) -> Dictionary:
	var carte: Dictionary = niveau["carte"]
	var joueur: Variant = niveau.get("joueur", {})
	var case_joueur: Variant = _lire_case((joueur as Dictionary).get("case", null)) if joueur is Dictionary else null
	var pnj: Variant = niveau.get("pnj", [])
	var case_pnj: Variant = null
	if pnj is Array and not (pnj as Array).is_empty() and pnj[0] is Dictionary:
		case_pnj = _lire_case((pnj[0] as Dictionary).get("case", null))
	if carte.has("spawn_p1") and case_joueur != null:
		var s: Variant = carte["spawn_p1"]
		if not (s is Dictionary) or int((s as Dictionary).get("x", -999)) != (case_joueur as Vector2i).x \
				or int((s as Dictionary).get("y", -999)) != (case_joueur as Vector2i).y:
			e.append("carte : « spawn_p1 » contredit « joueur.case » %s — la place du joueur se dit dans « joueur » (reçu %s)" % [str(case_joueur), str(s)])
	var a_valider := _carte_avec_apparitions(carte, case_joueur if case_joueur != null else Vector2i.ZERO,
		case_pnj if case_pnj != null else Vector2i.ZERO)
	var verdict := CodecT.validate(a_valider)
	if not bool(verdict["ok"]):
		e.append("carte : refusée par map_codec.gd — %s" % String(verdict["error"]))
		return {}
	var data: Dictionary = verdict["data"]
	var jouable := CodecT.check_playable(data)
	for controle: Dictionary in jouable["checks"]:
		if bool(controle["blocking"]) and not bool(controle["passed"]):
			# Les apparitions de l'aventure sont jugées par `joueur` et `pnj` (plus bas, avec leurs mots) : le contrôle du codec
			# les redirait avec les siens, en doublon.
			if not String(controle["label"]).begins_with("Apparition"):
				e.append("carte : %s" % String(controle["label"]))
	return data


static func _carte_avec_apparitions(carte: Dictionary, case_joueur: Vector2i, case_pnj: Vector2i) -> Dictionary:
	var c := carte.duplicate(true)
	c["spawn_p1"] = {"x": case_joueur.x, "y": case_joueur.y}
	c["spawn_p2"] = {"x": case_pnj.x, "y": case_pnj.y}
	return c


static func _case_praticable(navigation: NavigationBot, c: Vector2i, ctx: String, e: Array[String]) -> void:
	if c.x < 0 or c.y < 0 or c.x >= navigation.taille.x or c.y >= navigation.taille.y:
		e.append("%s : la case %s est hors de la carte (%d × %d)" % [ctx, str(c), navigation.taille.x, navigation.taille.y])
	elif not navigation.est_praticable(c):
		e.append("%s : la case %s n'est pas praticable (mur, vide, ou couloir plus étroit que le corps)" % [ctx, str(c)])


## Les clés d'un dictionnaire : aucune inconnue (une faute de frappe est un défaut, pas une option ignorée), toutes les requises.
static func _cles(d: Dictionary, permises: Array, requises: Array, ctx: String, e: Array[String]) -> void:
	for k in d.keys():
		if not permises.has(String(k)):
			e.append("%s : clé inconnue « %s » (permises : %s)" % [ctx, String(k), ", ".join(permises)])
	for k in requises:
		if not d.has(k):
			e.append("%s : clé requise « %s » absente" % [ctx, k])


static func _lire_case(v: Variant) -> Variant:
	if v is Vector2i:
		return v
	if v is Array and (v as Array).size() == 2 and _est_entier((v as Array)[0]) and _est_entier((v as Array)[1]):
		return Vector2i(int((v as Array)[0]), int((v as Array)[1]))
	return null


static func _est_nombre_fini(v: Variant) -> bool:
	return (v is int) or (v is float and is_finite(float(v)))


static func _est_entier(v: Variant) -> bool:
	return (v is int) or (v is float and is_finite(float(v)) and is_equal_approx(float(v), roundf(float(v))))


static func _texte_non_vide(v: Variant) -> bool:
	return v is String and String(v).strip_edges() != ""


static func _lire_json(chemin: String, erreurs: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		erreurs.append("fichier absent : %s" % chemin.get_file())
		return {}
	var texte := FileAccess.get_file_as_string(chemin)
	var json := JSON.new()
	if json.parse(texte) != OK:
		erreurs.append("%s : JSON illisible, ligne %d — %s" % [chemin.get_file(), json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		erreurs.append("%s : un objet JSON est attendu à la racine" % chemin.get_file())
		return {}
	return json.data
