## La garde du FORMAT de l'aventure et de sa progression — chantier SOLO, étape S6.
##
## Sans partie montée (`--script`, aucun nœud) : le validateur (`aventure_format.gd`) accepte le chapitre d'essai
## (`tools/aventure_essai/`, jamais `assets/solo/`) et REFUSE chaque défaut — un cas par règle, chacun avec le mot qui le nomme ;
## l'ordre des classes débloquées suit le rang ; un chapitre sans boss final est refusé ; aucune carte de duel n'est touchée ; et la
## progression (`aventure_progression.gd`) ouvre les chapitres et les niveaux dans l'ordre, débloque les classes dans l'ordre du
## rang, et ne perd pas en silence un fichier illisible.
##
## **Sabotée règle par règle** (la règle du dépôt : une garde « refuse » ne se croit qu'après l'avoir vue rougir) — la liste est dans la
## ROADMAP, section SOLO, S6.
##
## Les cris VOULUS (`push_error` d'un refus) sont comptés : `CRIS ATTENDUS` en fin de sortie — un refus qui cesserait de crier
## ferait rougir le lanceur.
##
## Lancer : godot --headless --path . --script res://tools/test_aventure_format.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")
const Profil := preload("res://profil_bot.gd")

const ESSAI := "res://tools/aventure_essai/chapitre_00"
const TEMP := "user://test_aventure_format"

var _failures := 0
var _verifications := 0
## Les `push_error` que cette suite provoque exprès, comptés à la main : un cri attendu est une égalité, pas une tolérance.
var _cris := 0

var _manifeste: Dictionary = {}
var _niveaux: Array = []


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
	print("=== LE FORMAT DE L'AVENTURE (S6) ===")
	var empreinte_cartes := _empreinte_des_cartes_de_duel()
	_le_chapitre_d_essai()
	_refus_du_manifeste()
	_refus_du_niveau()
	_refus_du_chapitre()
	_l_equipement_d_un_pnj()
	_ordre_des_classes()
	_chargement_et_catalogue()
	_progression()
	_aucune_carte_de_duel_touchee(empreinte_cartes)
	_nettoyer()
	print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
	print("CRIS ATTENDUS: %d" % _cris)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# LE CHAPITRE D'ESSAI : ce que le validateur accepte
# ---------------------------------------------------------------------------

func _le_chapitre_d_essai() -> void:
	print("\n--- Le chapitre d'essai est accepté ---")
	var lu := Format.lire_chapitre(ESSAI)
	_check("le chapitre d'essai se lit sans erreur de fichier", bool(lu["ok"]), str(lu["erreurs"]))
	_manifeste = lu["manifeste"]
	_niveaux = lu["niveaux"]
	_check("le manifeste dit 3 niveaux (deux salles et un boss)", _niveaux.size() == 3, str(_niveaux.size()))
	var defauts := Format.valider_chapitre(_manifeste, _niveaux)
	_check("le validateur ne trouve AUCUN défaut au chapitre d'essai", defauts.is_empty(), str(defauts))
	var attendu_dix := Format.valider_chapitre(_manifeste, _niveaux, 10)
	_check("… mais lui en trouve un quand on exige dix salles (le chapitre livré en compte dix)",
		attendu_dix.size() == 1 and attendu_dix[0].contains("10 salles exigées"), str(attendu_dix))
	var charge := Format.charger_chapitre(ESSAI, 0)
	_check("`charger_chapitre` rend le chapitre prêt à jouer", not charge.is_empty() and int(charge["numero"]) == 0
		and (charge["niveaux"] as Array).size() == 3, str(charge.keys()))
	if charge.is_empty():
		return
	var n1: Dictionary = charge["niveaux"][0]
	_check("le niveau préparé porte sa carte, sa case de départ et ses PNJ en types du jeu",
		n1["joueur"]["case"] == Vector2i(3, 8) and n1["pnj"][0]["case"] == Vector2i(12, 8)
		and is_equal_approx(float(n1["pnj"][0]["rotation"]), PI) and n1["plafonniers"][0]["case"] == Vector2i(12, 8),
		str(n1["joueur"]))
	_check("sa carte porte les apparitions (J1 au joueur, J2 sous le premier PNJ)",
		n1["carte"]["spawn_p1"] == {"x": 3, "y": 8} and n1["carte"]["spawn_p2"] == {"x": 12, "y": 8}, str(n1["carte"].get("spawn_p1")))
	var n2: Dictionary = charge["niveaux"][1]
	var ronde := Format.profil_du_pnj(n2["pnj"][0])
	_check("la ronde se pose sur le profil, dans l'ordre", ronde.deplacement == Profil.Deplacement.RONDE
		and ronde.points_ronde == [Vector2i(14, 3), Vector2i(14, 10), Vector2i(5, 10), Vector2i(5, 3)], str(ronde.points_ronde))
	var zone := Format.profil_du_pnj(n2["pnj"][1])
	_check("la zone se pose sur le profil", zone.deplacement == Profil.Deplacement.ZONE and zone.zone == Rect2i(10, 8, 6, 4), str(zone.zone))
	var boss := Format.profil_du_pnj(charge["niveaux"][2]["pnj"][0])
	var norm := Profil.boss()
	_check("le boss est le profil `ProfilBot.boss()` (NORMAL, voit, entend, tire)", boss.voit and boss.entend and boss.tire
		and boss.deplacement == norm.deplacement and is_equal_approx(boss.delai_reaction, norm.delai_reaction))
	_check("un profil est NEUF à chaque appel (la tentative d'après ne partage rien avec la précédente)",
		Format.profil_du_pnj(n2["pnj"][0]) != ronde)
	_check("le PNJ qui ne dit pas sa classe porte la classe par défaut (le Parasite)", n1["pnj"][0]["classe"] == "pistolet")
	_check("la dernière salle est le boss, et seule elle", charge["niveaux"][2]["boss"] and not charge["niveaux"][0]["boss"]
		and not charge["niveaux"][1]["boss"])


# ---------------------------------------------------------------------------
# LES REFUS : un cas par règle
# ---------------------------------------------------------------------------

## Un niveau d'essai, copie profonde : la mutation d'un cas ne déborde jamais sur le suivant.
func _niveau(i: int = 0) -> Dictionary:
	return (_niveaux[i] as Dictionary).duplicate(true)


## Le cas doit être refusé, et l'un des défauts doit dire `mot` — « refusé » seul ne dirait pas POURQUOI, et un refus pour une autre
## raison que celle qu'on teste passerait pour la bonne.
func _refuse_niveau(nom: String, niveau: Dictionary, mot: String) -> void:
	var defauts := Format.valider_niveau(niveau)
	var trouve := false
	for d in defauts:
		trouve = trouve or d.contains(mot)
	_check("refusé : %s" % nom, trouve, "attendu « %s » — %s" % [mot, str(defauts)])


func _refuse_manifeste(nom: String, m: Dictionary, mot: String) -> void:
	var defauts := Format.valider_manifeste(m)
	var trouve := false
	for d in defauts:
		trouve = trouve or d.contains(mot)
	_check("refusé : %s" % nom, trouve, "attendu « %s » — %s" % [mot, str(defauts)])


func _refus_du_manifeste() -> void:
	print("\n--- Les refus du manifeste ---")
	var m := func() -> Dictionary: return _manifeste.duplicate(true)
	var x: Dictionary = m.call()
	x["numero"] = 11
	_refuse_manifeste("un numéro de chapitre hors de 0 à 10", x, "« numero »")
	x = m.call()
	x["titre"] = "  "
	_refuse_manifeste("un titre vide", x, "« titre »")
	x = m.call()
	x["classe_debloquee"] = "fumiste"
	_refuse_manifeste("une classe débloquée qui contredit l'ordre du rang (chapitre 0 → pistolet)", x, "l'ordre du rang")
	x = m.call()
	x.erase("classe_debloquee")
	_refuse_manifeste("une classe débloquée absente (chapitre 0)", x, "« classe_debloquee » est requise")
	x = m.call()
	x["numero"] = 10
	x["classe_debloquee"] = "spectre"
	_refuse_manifeste("une classe offerte par le chapitre 10 (il n'en offre aucune)", x, "n'offre aucune classe")
	x = m.call()
	x["classe_imposee"] = "licorne"
	_refuse_manifeste("une classe imposée inconnue", x, "« classe_imposee »")
	x = m.call()
	x.erase("classe_imposee")
	_refuse_manifeste("le chapitre 0 qui ne prête pas le Parasite", x, "PRÊTE le Parasite")
	x = m.call()
	x["niveaux"] = []
	_refuse_manifeste("une liste de niveaux vide", x, "« niveaux »")
	x = m.call()
	x["niveaux"] = ["niveau_01.json", "niveau_01.json"]
	_refuse_manifeste("un niveau cité deux fois", x, "cité deux fois")
	x = m.call()
	x["niveaux"] = ["../autre/niveau.json"]
	_refuse_manifeste("un niveau hors du dossier du chapitre", x, "fichiers .json du dossier")
	x = m.call()
	x["bonus"] = 3
	_refuse_manifeste("une clé inconnue (la faute de frappe n'est pas une option ignorée)", x, "clé inconnue « bonus »")
	x = m.call()
	x["version"] = 2
	_refuse_manifeste("une version inconnue", x, "« version »")
	# Le chapitre 10 sans classe est valide, lui.
	x = m.call()
	x["numero"] = 10
	x.erase("classe_debloquee")
	x.erase("classe_imposee")
	_check("le chapitre 10 sans classe offerte est accepté (« on verra plus tard »)", Format.valider_manifeste(x).is_empty(), str(Format.valider_manifeste(x)))


func _refus_du_niveau() -> void:
	print("\n--- Les refus d'un niveau ---")
	var n := _niveau()
	_check("le niveau d'essai de départ est sans défaut", Format.valider_niveau(n).is_empty(), str(Format.valider_niveau(n)))

	n = _niveau()
	n["pnj"][0]["profil"] = "bidule_voit_lent"
	_refuse_niveau("un profil de PNJ inconnu (jamais un PNJ par défaut)", n, "profil inconnu « bidule_voit_lent »")
	n = _niveau()
	n["pnj"][0]["profil"] = "immobile_voit_ultra_rapide"
	_refuse_niveau("un palier de réflexes inconnu", n, "profil inconnu")
	n = _niveau()
	n["pnj"][0]["profil"] = 3
	_refuse_niveau("un profil qui n'est pas un nom", n, "NOM d'un profil")
	n = _niveau()
	n["pnj"][0]["profil"] = "boss"
	_refuse_niveau("le profil boss hors du niveau de boss", n, "n'existe que dans le niveau de boss")

	n = _niveau()
	n["pnj"][0]["case"] = [99, 99]
	_refuse_niveau("un PNJ hors de la carte", n, "hors de la carte")
	n = _niveau()
	n["pnj"][0]["case"] = [0, 0]
	_refuse_niveau("un PNJ dans un mur (case non praticable)", n, "pas praticable")
	n = _niveau()
	n["pnj"][0]["case"] = "ici"
	_refuse_niveau("une case qui n'est pas [x, y]", n, "« case » est [x, y]")
	n = _niveau()
	n["pnj"][0]["case"] = [3, 8]
	_refuse_niveau("un PNJ sur la case du joueur", n, "déjà prise par le joueur")
	n = _niveau(1)
	n["pnj"][1]["case"] = n["pnj"][0]["case"]
	_refuse_niveau("deux PNJ sur la même case", n, "déjà prise")
	n = _niveau()
	n["joueur"]["case"] = [0, 0]
	_refuse_niveau("un joueur dans un mur", n, "joueur : la case")
	n = _niveau()
	n["joueur"]["case"] = [-1, 4]
	_refuse_niveau("un joueur hors de la carte", n, "hors de la carte")
	n = _niveau()
	n["pnj"][0]["orientation"] = "nord"
	_refuse_niveau("une orientation qui n'est pas un nombre", n, "« orientation »")

	n = _niveau(1)
	n["pnj"][0].erase("ronde")
	_refuse_niveau("une ronde sans points", n, "ronde sans points")
	n = _niveau(1)
	n["pnj"][0]["ronde"] = [[14, 3]]
	_refuse_niveau("une ronde d'un seul point", n, "ronde sans points")
	n = _niveau(1)
	n["pnj"][0]["ronde"] = [[14, 3], [0, 0]]
	_refuse_niveau("un point de ronde dans un mur", n, "point de ronde 1")
	n = _niveau(1)
	n["pnj"][1]["ronde"] = [[12, 9], [13, 9]]
	_refuse_niveau("une ronde posée sur un profil de zone", n, "« ronde » ne se pose que sur un profil de ronde")
	n = _niveau(1)
	n["pnj"][1].erase("zone")
	_refuse_niveau("une zone sans rectangle", n, "une zone sans rectangle")
	n = _niveau(1)
	n["pnj"][1]["zone"] = [10, 8, 0, 4]
	_refuse_niveau("une zone vide", n, "est vide")
	n = _niveau(1)
	n["pnj"][1]["zone"] = [10, 8, 40, 4]
	_refuse_niveau("une zone qui sort de la carte", n, "sort de la carte")
	n = _niveau(1)
	n["pnj"][1]["zone"] = [2, 2, 3, 3]
	_refuse_niveau("une zone qui ne contient pas la case du PNJ", n, "ne contient pas la case du PNJ")
	n = _niveau(1)
	n["pnj"][0]["zone"] = [1, 1, 4, 4]
	_refuse_niveau("une zone posée sur un profil de ronde", n, "« zone » ne se pose que sur un profil de zone")

	n = _niveau()
	n["pnj"] = []
	_refuse_niveau("une salle sans PNJ (on l'emporte en éliminant tout le monde)", n, "au moins un PNJ")
	n = _niveau()
	n.erase("pnj")
	_refuse_niveau("un niveau sans clé « pnj »", n, "« pnj » absente")
	n = _niveau()
	n["pnj"][0]["classe"] = "licorne"
	_refuse_niveau("une classe de PNJ inconnue", n, "« classe » est un slug de classe connu")
	n = _niveau()
	n["pnj"][0]["armure"] = 3
	_refuse_niveau("une clé de PNJ inconnue", n, "clé inconnue « armure »")
	n = _niveau()
	for k in 8:
		n["pnj"].append({"case": [4 + k, 3], "orientation": 0, "profil": "immobile_sourd_aveugle"})
	_refuse_niveau("plus de huit PNJ", n, "8 au plus")

	n = _niveau()
	n["plafonniers"][0]["rayon"] = 40.0
	_refuse_niveau("un plafonnier au rayon hors bornes (il ne serait pas borné en silence)", n, "« rayon »")
	n = _niveau()
	n["plafonniers"][0]["intensite"] = 0.0
	_refuse_niveau("un plafonnier à l'intensité hors bornes", n, "« intensite »")
	n = _niveau()
	n["plafonniers"][0]["case"] = [0, 0]
	_refuse_niveau("un plafonnier dans la pierre", n, "dans la pierre")
	n = _niveau()
	n["plafonniers"][0]["case"] = [99, 1]
	_refuse_niveau("un plafonnier hors de la carte", n, "hors de la carte")
	n = _niveau()
	n["plafonniers"][0]["teinte"] = "chaud"
	_refuse_niveau("une teinte qui n'est pas du HTML", n, "« teinte »")
	n = _niveau()
	n["plafonniers"][0].erase("case")
	_refuse_niveau("un plafonnier sans case", n, "sans « case »")
	n = _niveau()
	n["plafonniers"] = 3
	_refuse_niveau("des plafonniers qui ne sont pas une liste", n, "plafonniers : une liste")

	n = _niveau()
	n["carte"].erase("floor")
	_refuse_niveau("une carte sans sol (refusée par le codec)", n, "map_codec.gd")
	n = _niveau()
	n["carte"]["version"] = 99
	_refuse_niveau("une carte d'une version trop récente", n, "map_codec.gd")
	n = _niveau()
	n["carte"] = "CANDELA-xyz"
	_refuse_niveau("une carte qui n'est pas un dictionnaire (renvoyer vers un code ou un fichier n'est pas l'embarquer)", n, "carte : un dictionnaire")
	n = _niveau()
	n["carte"]["spawn_p1"] = {"x": 9, "y": 9}
	_refuse_niveau("un spawn_p1 qui contredit la case du joueur", n, "contredit « joueur.case »")
	n = _niveau()
	n["carte"]["floor"] = "1,1,3"
	_refuse_niveau("une carte trop petite pour une salle", n, "Sol dessiné")
	n = _niveau()
	n["carte"]["spawn_p1"] = {"x": 3, "y": 8}
	n["carte"]["spawn_p2"] = {"x": 0, "y": 0}
	_check("un spawn_p1 d'accord et un spawn_p2 quelconque sont acceptés (J2 est garé sous le premier PNJ)",
		Format.valider_niveau(n).is_empty(), str(Format.valider_niveau(n)))

	n = _niveau()
	n["titre"] = ""
	_refuse_niveau("un titre vide", n, "« titre »")
	n = _niveau()
	n["intention"] = "x".repeat(300)
	_refuse_niveau("une intention qui n'est pas UNE phrase (trop longue)", n, "UNE phrase")
	n = _niveau()
	n["boss"] = "oui"
	_refuse_niveau("un « boss » qui n'est pas vrai ou faux", n, "« boss »")
	n = _niveau()
	n["version"] = 7
	_refuse_niveau("une version de niveau inconnue", n, "« version »")
	n = _niveau()
	n["difficulte"] = "dur"
	_refuse_niveau("une clé de niveau inconnue", n, "clé inconnue « difficulte »")

	n = _niveau(2)
	_check("le niveau de boss d'essai est sans défaut", Format.valider_niveau(n).is_empty(), str(Format.valider_niveau(n)))
	n["pnj"].append({"case": [5, 5], "orientation": 0, "profil": "immobile_sourd_aveugle"})
	_refuse_niveau("un boss qui n'est pas SEUL dans sa salle", n, "UN seul PNJ")
	n = _niveau(2)
	n["pnj"][0]["profil"] = "libre_voit_entend_normal"
	_refuse_niveau("un niveau de boss dont le PNJ n'a pas le profil boss", n, "a le profil « boss »")
	n = _niveau(2)
	n["pnj"][0].erase("classe")
	_refuse_niveau("un boss sans classe", n, "« classe » est requise")


func _refus_du_chapitre() -> void:
	print("\n--- Les refus du chapitre ---")
	var m: Dictionary = _manifeste.duplicate(true)
	var ns: Array = _niveaux.duplicate(true)
	# Un chapitre sans boss final.
	var sans_boss := ns.duplicate(true)
	sans_boss[2]["boss"] = false
	var d := Format.valider_chapitre(m, sans_boss)
	_check("refusé : un chapitre sans boss final", _dit(d, "un chapitre sans boss final est refusé"), str(d))
	# Un boss au milieu.
	var boss_milieu := ns.duplicate(true)
	boss_milieu[0] = ns[2].duplicate(true)
	d = Format.valider_chapitre(m, boss_milieu)
	_check("refusé : un boss au milieu du chapitre", _dit(d, "jamais au milieu"), str(d))
	# Le boss d'une autre classe que celle qu'on débloque.
	var autre_classe := ns.duplicate(true)
	autre_classe[2]["pnj"][0]["classe"] = "fumiste"
	d = Format.valider_chapitre(m, autre_classe)
	_check("refusé : un boss d'une autre classe que celle que le chapitre débloque", _dit(d, "classe que le chapitre débloque"), str(d))
	# Un défaut de niveau est signalé AVEC son fichier.
	var defaut_niveau := ns.duplicate(true)
	defaut_niveau[1]["pnj"][0]["profil"] = "inconnu_voit_lent"
	d = Format.valider_chapitre(m, defaut_niveau)
	_check("un défaut de niveau est dit AVEC son fichier (niveau_02.json)", _dit(d, "niveau_02.json : pnj 0"), str(d))
	# Le nombre de fichiers lus.
	d = Format.valider_chapitre(m, [ns[0]])
	_check("refusé : moins de niveaux lus que de fichiers cités", _dit(d, "fichiers cités"), str(d))
	# Un dossier sur disque : un niveau absent, un JSON illisible.
	_nettoyer()
	DirAccess.make_dir_recursive_absolute(TEMP.path_join("chapitre_00"))
	var dossier := TEMP.path_join("chapitre_00")
	_ecrire(dossier.path_join("chapitre.json"), m)
	_ecrire(dossier.path_join("niveau_01.json"), ns[0])
	_ecrire(dossier.path_join("niveau_02.json"), ns[1])
	var lu := Format.lire_chapitre(dossier)
	_check("un niveau cité et absent du disque est un défaut de lecture", not bool(lu["ok"]) and _dit(lu["erreurs"], "fichier absent : niveau_03.json"), str(lu["erreurs"]))
	_ecrire_texte(dossier.path_join("niveau_03.json"), "{ ceci n'est pas du JSON")
	lu = Format.lire_chapitre(dossier)
	_check("un JSON illisible est un défaut de lecture, avec sa ligne", not bool(lu["ok"]) and _dit(lu["erreurs"], "JSON illisible"), str(lu["erreurs"]))
	var avant := _cris
	_cris += 1
	var charge := Format.charger_chapitre(dossier, 0)
	_check("`charger_chapitre` d'un chapitre défectueux rend VIDE (il n'est pas joué de travers)", charge.is_empty())
	# Un chapitre dont un profil est faux : un seul défaut, un seul cri (le décompte de CRIS ATTENDUS).
	_ecrire(dossier.path_join("niveau_03.json"), ns[2])
	var faux: Dictionary = ns[1].duplicate(true)
	faux["pnj"][0]["profil"] = "inconnu_voit_lent"
	_ecrire(dossier.path_join("niveau_02.json"), faux)
	_cris += 1
	charge = Format.charger_chapitre(dossier, 0)
	_check("un profil inconnu dans un fichier : le chapitre n'est pas chargé", charge.is_empty())
	_check("… et chaque défaut est CRIÉ (push_error) : un cri par défaut", _cris - avant == 2)
	# Le dossier réparé est accepté (le refus venait bien du profil).
	_ecrire(dossier.path_join("niveau_02.json"), ns[1])
	charge = Format.charger_chapitre(dossier, 0)
	_check("le même dossier, réparé, est accepté", not charge.is_empty())


# ---------------------------------------------------------------------------
# L'ÉQUIPEMENT D'UN PNJ : la clé « equipe » (S8)
# ---------------------------------------------------------------------------

## Les propriétés de données d'un profil, par nom : de quoi comparer deux profils champ à champ sans en oublier un que S9 ajouterait.
func _champs_du_profil(p: ProfilBot) -> Dictionary:
	var sortie := {}
	for prop: Dictionary in p.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (int(prop["usage"]) & PROPERTY_USAGE_STORAGE) != 0:
			sortie[String(prop["name"])] = p.get(String(prop["name"]))
	return sortie


## Les champs qui diffèrent entre deux profils (leurs noms), pour dire CE qui a changé.
func _ecarts(a: ProfilBot, b: ProfilBot) -> Array[String]:
	var ca := _champs_du_profil(a)
	var cb := _champs_du_profil(b)
	var sortie: Array[String] = []
	for k in ca:
		if ca[k] != cb.get(k):
			sortie.append(String(k))
	return sortie


## Le niveau `n_niveau` de l'essai (copie), dont le PNJ `i` est posé sur le profil `nom`, avec « equipe » s'il est donné.
func _pnj_equipe(n_niveau: int, i: int, nom: String, equipe: Variant = null) -> Dictionary:
	var n := _niveau(n_niveau)
	n["pnj"][i]["profil"] = nom
	if equipe != null:
		n["pnj"][i]["equipe"] = equipe
	return n


## Le palier que dit la fin d'un nom du catalogue, lu SANS `palier_du_nom` : la garde ne se sert pas de ce qu'elle juge.
func _palier_attendu(nom: String) -> int:
	if nom.ends_with("sourd_aveugle"):
		return -1
	for nom_palier: String in Profil._NOMS_PALIER:
		if nom.ends_with("_" + nom_palier):
			return int(Profil._NOMS_PALIER[nom_palier])
	return -2


func _l_equipement_d_un_pnj() -> void:
	print("\n--- L'équipement d'un PNJ : « equipe » (S8) ---")
	# Accepté : un PNJ qui AGIT — immobile, en ronde, en zone — peut s'équiper ; « equipe » faux (ou absent) ne change rien.
	for cas: Array in [[1, 0, "ronde_voit_lent"], [1, 1, "zone_voit_facile"], [0, 0, "immobile_voit_entend_lent"], [1, 0, "ronde_entend_normal"]]:
		var accepte := _pnj_equipe(cas[0], cas[1], cas[2], true)
		_check("accepté : « equipe » vrai sur %s" % cas[2], Format.valider_niveau(accepte).is_empty(), str(Format.valider_niveau(accepte)))
	var n := _pnj_equipe(1, 0, "ronde_voit_lent", false)
	_check("accepté : « equipe » faux (aucun outil, comme sans la clé)", Format.valider_niveau(n).is_empty(), str(Format.valider_niveau(n)))
	# Refusé.
	n = _pnj_equipe(1, 0, "ronde_voit_lent", "oui")
	_refuse_niveau("« equipe » qui n'est pas un booléen (un texte)", n, "« equipe » est vrai ou faux")
	n = _pnj_equipe(1, 0, "ronde_voit_lent", 1)
	_refuse_niveau("« equipe » qui n'est pas un booléen (un entier)", n, "« equipe » est vrai ou faux")
	n = _pnj_equipe(0, 0, "immobile_sourd_aveugle", true)
	_refuse_niveau("« equipe » sur un PNJ sourd et aveugle immobile (il n'agit pas)", n, "« equipe » est refusée sur « immobile_sourd_aveugle »")
	n = _pnj_equipe(1, 0, "ronde_sourd_aveugle", true)
	_refuse_niveau("« equipe » sur un PNJ sourd et aveugle en ronde", n, "un PNJ sourd et aveugle n'agit pas")
	n = _pnj_equipe(1, 1, "zone_sourd_aveugle", true)
	_refuse_niveau("« equipe » sur un PNJ sourd et aveugle en zone", n, "un PNJ sourd et aveugle n'agit pas")
	n = _niveau(2)
	n["pnj"][0]["equipe"] = true
	_refuse_niveau("« equipe » sur le boss (son profil est déjà équipé)", n, "« equipe » est refusée sur le boss")
	n = _pnj_equipe(1, 0, "ronde_voit_lent", true)
	n["pnj"][0]["equipee"] = true
	_refuse_niveau("la faute de frappe « equipee » reste une clé inconnue", n, "clé inconnue « equipee »")

	# Le palier d'un nom : une seule lecture, pour les soixante-quatre noms du catalogue.
	var palier_ok := true
	var detail := ""
	for nom in Profil.noms_du_catalogue():
		var lu := Profil.palier_du_nom(nom)
		if lu != _palier_attendu(nom):
			palier_ok = false
			detail += " %s:%d≠%d" % [nom, lu, _palier_attendu(nom)]
	_check("`palier_du_nom` rend le palier de chacun des 64 noms du catalogue (-1 pour le sourd et aveugle)", palier_ok and Profil.noms_du_catalogue().size() == 64, detail)
	_check("… et -1 pour un nom hors catalogue", Profil.palier_du_nom("bidule_voit_lent") == -1 and Profil.palier_du_nom("boss") == -1 and Profil.palier_du_nom("") == -1)

	# Ce que le profil devient. Sans la clé : EXACTEMENT le PNJ du catalogue d'avant (mêmes champs, donc même graine, mêmes commandes).
	var entree_sans: Dictionary = Format.preparer_niveau(_pnj_equipe(1, 0, "ronde_voit_lent"))["pnj"][0]
	var sans := Format.profil_du_pnj(entree_sans)
	var catalogue := Profil.pnj_nomme("ronde_voit_lent")
	catalogue.points_ronde.assign(entree_sans["ronde"])
	_check("sans la clé : le profil est EXACTEMENT celui du catalogue, champ pour champ, et n'a aucun outil",
		_ecarts(sans, catalogue).is_empty() and not sans.est_equipe(), str(_ecarts(sans, catalogue)))
	var entree_faux: Dictionary = Format.preparer_niveau(_pnj_equipe(1, 0, "ronde_voit_lent", false))["pnj"][0]
	_check("« equipe » faux : le même profil, sans outil", _ecarts(Format.profil_du_pnj(entree_faux), sans).is_empty() and not bool(entree_faux["equipe"]))
	for nom in ["immobile_sourd_aveugle", "immobile_voit_tres_lent", "immobile_entend_lent", "zone_voit_entend_facile", "libre_voit_entend_normal"]:
		var pnj_catalogue := Profil.pnj_nomme(nom)
		var entree := {"profil_nom": nom, "ronde": [] as Array[Vector2i], "zone": Rect2i(), "classe": "pistolet"}
		var profil := Format.profil_du_pnj(entree)
		_check("sans la clé, %s est le catalogue tel quel (aucun outil)" % nom, _ecarts(profil, pnj_catalogue).is_empty() and not profil.est_equipe())

	# Avec la clé : le gadget, à tous les paliers ; les outils du palier, à NORMAL et au-dessus ; jamais un champ de perception, de réflexe ou de déplacement.
	var entree_equipe: Dictionary = Format.preparer_niveau(_pnj_equipe(1, 0, "ronde_voit_lent", true))["pnj"][0]
	_check("la clé survit à `preparer_niveau`", bool(entree_equipe["equipe"]))
	var equipe := Format.profil_du_pnj(entree_equipe)
	_check("avec la clé, un PNJ LENT se sert du gadget de sa classe — et de rien d'autre (la table de S9 ne dit rien du palier LENT)",
		equipe.utilise_le_gadget and equipe.est_equipe() and not equipe.torche_tactique and equipe.repli_apres_tir_s == 0.0
		and equipe.accroupi_pres_du_son_px == 0.0 and not equipe.lance_des_fusees)
	_check("… et il reste exactement le même PNJ pour tout le reste : perception, réflexes, déplacement, allure, ronde",
		_ecarts(equipe, sans) == (["utilise_le_gadget"] as Array[String]), str(_ecarts(equipe, sans)))
	var normal := Format.profil_du_pnj({"profil_nom": "ronde_voit_entend_normal", "ronde": [] as Array[Vector2i], "zone": Rect2i(), "classe": "fusil", "equipe": true})
	var attendu_normal := Profil.pnj_nomme("ronde_voit_entend_normal")
	Profil.equiper_pour_le_palier(attendu_normal, Profil.Palier.NORMAL)
	attendu_normal.utilise_le_gadget = true
	_check("un PNJ NORMAL équipé reçoit ce que S9 donne au palier NORMAL (torche tactique, repli, gadget)",
		normal.torche_tactique and normal.repli_apres_tir_s > 0.0 and normal.utilise_le_gadget and _ecarts(normal, attendu_normal).is_empty(), str(_ecarts(normal, attendu_normal)))
	var difficile := Format.profil_du_pnj({"profil_nom": "zone_voit_entend_difficile", "ronde": [] as Array[Vector2i], "zone": Rect2i(0, 0, 4, 4), "classe": "fusil", "equipe": true})
	_check("… et un PNJ DIFFICILE ce qu'elle donne au palier DIFFICILE (fusée et posture comprises)", difficile.lance_des_fusees and difficile.accroupi_pres_du_son_px > 0.0 and difficile.utilise_le_gadget)
	var boss := Format.profil_du_pnj({"profil_nom": "boss", "ronde": [] as Array[Vector2i], "zone": Rect2i(), "classe": "fumiste", "equipe": true})
	_check("le boss garde son profil réglé à sa classe, « equipe » n'y change rien", _ecarts(boss, Profil.boss("fumiste")).is_empty())
	# Un profil n'est jamais partagé d'un appel à l'autre : équiper l'un n'équipe pas le suivant.
	var apres := Format.profil_du_pnj(entree_sans)
	_check("équiper un PNJ n'équipe pas le suivant (un profil neuf à chaque appel)", not apres.est_equipe() and apres != equipe)


# ---------------------------------------------------------------------------
# L'ORDRE DES CLASSES
# ---------------------------------------------------------------------------

func _ordre_des_classes() -> void:
	print("\n--- L'ordre des classes suit le rang ---")
	_check("dix classes, une par chapitre de 0 à 9", Format.ORDRE_DES_CLASSES.size() == 10)
	var nominal := ["pistolet", "fumiste", "fusil", "arbalete", "pompe", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
	var ok := true
	for c in 10:
		ok = ok and Format.classe_du_chapitre(c) == nominal[c]
	_check("le chapitre N offre la classe de rang N+1 (Parasite, Fumiste, Illusionniste, Braconnier, Terrassier, Incendiaire, Sentinelle, Occulteur, Allumeur, Spectre)", ok)
	_check("le chapitre 10 n'offre aucune classe", Format.classe_du_chapitre(10) == "" and Format.classe_du_chapitre(11) == "" and Format.classe_du_chapitre(-1) == "")
	# Chaque manifeste du bon rang est accepté, chaque autre refusé.
	var tous := true
	var aucun_autre := true
	for c in 10:
		var m: Dictionary = _manifeste.duplicate(true)
		m["numero"] = c
		m["classe_debloquee"] = nominal[c]
		m.erase("classe_imposee")
		if c == 0:
			m["classe_imposee"] = "pistolet"
		tous = tous and Format.valider_manifeste(m).is_empty()
		var decale: Dictionary = m.duplicate(true)
		decale["classe_debloquee"] = nominal[(c + 1) % 10]
		aucun_autre = aucun_autre and not Format.valider_manifeste(decale).is_empty()
	_check("les dix manifestes à la classe de leur rang sont acceptés", tous)
	_check("… et la classe du chapitre voisin (le désordre) est refusée pour chacun", aucun_autre)
	# Les classes débloquées par la progression : toujours dans l'ordre du rang, même si le fichier les a notées autrement.
	var chemin := TEMP.path_join("desordre.cfg")
	DirAccess.make_dir_recursive_absolute(TEMP)
	var cfg := ConfigFile.new()
	cfg.set_value("progression", "classes_debloquees", ["fumiste", "inconnue", "pistolet", "fumiste", "fusil"])
	cfg.save(chemin)
	var p := Progression.new(chemin)
	_check("les classes débloquées sortent dans l'ORDRE DU RANG, sans doublon ni classe inconnue",
		_memes(p.classes_debloquees(), ["pistolet", "fumiste", "fusil"]), str(p.classes_debloquees()))


# ---------------------------------------------------------------------------
# LE CHARGEMENT ET LE CATALOGUE DES CHAPITRES LIVRÉS
# ---------------------------------------------------------------------------

func _chargement_et_catalogue() -> void:
	print("\n--- Le catalogue des chapitres ---")
	var racine_avant: String = Format.racine
	var attendus_avant: int = Format.niveaux_attendus
	Format.oublier_le_cache()
	# S7 (2026-10-03) a écrit le chapitre 0, S8 les chapitres 1 et suivants : `assets/solo` livre ceux-là, et pas un de plus. Sans cri : un chapitre
	# mal écrit ne se chargerait pas, et `CRIS ATTENDUS` resterait à sa valeur.
	_check("`assets/solo` livre le chapitre 0 de S7 et les chapitres de S8 (1), et eux seuls, sans un cri",
		Format.chapitres_livres().keys() == [0, 1], str(Format.chapitres_livres().keys()))
	Format.racine = "res://tools/aventure_essai"
	Format.niveaux_attendus = 0
	Format.oublier_le_cache()
	var livres: Dictionary = Format.chapitres_livres()
	_check("posée sur le dossier d'essai, la racine livre le chapitre 0", livres.keys() == [0], str(livres.keys()))
	_check("… relu depuis le cache au deuxième appel (même objet)", Format.chapitres_livres() == livres)
	_cris += 1
	Format.niveaux_attendus = 10
	Format.oublier_le_cache()
	_check("avec la règle livrée (dix salles), le chapitre d'essai de trois salles n'est PAS livré — et le dit", Format.chapitres_livres().is_empty())
	# Un numéro qui contredit le nom du dossier.
	Format.niveaux_attendus = 0
	var racine_temp := TEMP.path_join("racine")
	DirAccess.make_dir_recursive_absolute(racine_temp.path_join("chapitre_03"))
	for f in ["chapitre.json", "niveau_01.json", "niveau_02.json", "niveau_03.json"]:
		DirAccess.copy_absolute(ESSAI.path_join(f), racine_temp.path_join("chapitre_03").path_join(f))
	Format.racine = racine_temp
	Format.oublier_le_cache()
	_cris += 1
	_check("un manifeste dont le numéro (0) contredit son dossier (chapitre_03) n'est pas livré", Format.chapitres_livres().is_empty())
	Format.racine = racine_avant
	Format.niveaux_attendus = attendus_avant
	Format.oublier_le_cache()


# ---------------------------------------------------------------------------
# LA PROGRESSION
# ---------------------------------------------------------------------------

func _progression() -> void:
	print("\n--- La progression ---")
	DirAccess.make_dir_recursive_absolute(TEMP)
	var chemin := TEMP.path_join("solo.cfg")
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)
	var p := Progression.new(chemin)
	_check("sans fichier : une progression vide (rien de réussi, aucune classe)", p.classes_debloquees().is_empty()
		and p.chapitres_termines() == 0 and not p.fichier_illisible)
	_check("le chapitre 0 est ouvert, le 1 non", p.chapitre_ouvert(0) and not p.chapitre_ouvert(1) and not p.chapitre_ouvert(11))
	_check("dans un chapitre, le premier niveau est ouvert, le deuxième non", p.niveau_ouvert(0, 0) and not p.niveau_ouvert(0, 1))
	_check("un niveau d'un chapitre fermé est fermé, même le premier", not p.niveau_ouvert(1, 0))
	_check("sans rien choisi, on joue la classe par défaut (le Parasite prêté)", p.classe_pour_jouer("") == "pistolet" and p.classe_choisie() == "")
	_cris += 1
	_check("réussir un niveau fermé est refusé (et crié)", not p.reussir_niveau(0, 1) and not p.niveau_reussi(0, 1))
	_check("réussir le premier niveau ouvre le deuxième, et l'écrit", p.reussir_niveau(0, 0) and p.niveau_ouvert(0, 1) and FileAccess.file_exists(chemin))
	_check("… sans ouvrir le troisième", not p.niveau_ouvert(0, 2))
	_check("réussir deux fois le même niveau n'ajoute rien", p.reussir_niveau(0, 0) and _memes(p.niveaux_reussis(0), [0]))
	_check("le prochain niveau à jouer est le premier non réussi", p.prochain_niveau(0, 3) == 1)
	_cris += 1
	_check("finir un chapitre fermé est refusé (et crié) : les classes ne se débloquent pas dans le désordre", not p.terminer_chapitre(1)
		and p.classes_debloquees().is_empty())
	_check("finir le chapitre 0 le termine, ouvre le 1 et débloque le PARASITE", p.terminer_chapitre(0) and p.chapitre_termine(0)
		and p.chapitre_ouvert(1) and _memes(p.classes_debloquees(), ["pistolet"]), str(p.classes_debloquees()))
	_check("… et la classe se choisit parmi les débloquées", p.choisir_classe("pistolet") and p.classe_choisie() == "pistolet")
	_cris += 1
	_check("une classe non débloquée ne se choisit pas (et le crie)", not p.choisir_classe("fumiste") and p.classe_choisie() == "pistolet")
	_check("finir le chapitre 1 débloque le FUMISTE, après le Parasite", p.terminer_chapitre(1) and _memes(p.classes_debloquees(), ["pistolet", "fumiste"]))
	_check("un chapitre qui IMPOSE une classe la fait jouer, quel que soit le choix", p.classe_pour_jouer("pistolet") == "pistolet"
		and p.choisir_classe("fumiste") and p.classe_pour_jouer("pistolet") == "pistolet" and p.classe_pour_jouer("") == "fumiste")
	# Les dix chapitres, dans l'ordre, jusqu'au chapitre 10 qui n'offre rien.
	for c in range(2, 11):
		p.terminer_chapitre(c)
	_check("dix chapitres finis débloquent les dix classes, dans l'ordre du rang", _memes(p.classes_debloquees(), Format.ORDRE_DES_CLASSES),
		str(p.classes_debloquees()))
	_check("le chapitre 10 fini ne débloque rien de plus", p.chapitres_termines() == 11 and p.classes_debloquees().size() == 10)
	# Relue d'un autre processus : tout survit.
	var relue := Progression.new(chemin)
	_check("la progression survit à une relecture du fichier", relue.chapitres_termines() == 11 and relue.niveau_reussi(0, 0)
		and relue.classe_choisie() == "fumiste" and relue.classes_debloquees().size() == 10)
	# Le choix noté d'une classe qui n'est plus débloquée ne joue pas.
	var cfg := ConfigFile.new()
	cfg.set_value("progression", "classe_choisie", "spectre")
	var chemin2 := TEMP.path_join("choix_non_gagne.cfg")
	cfg.save(chemin2)
	_check("un choix noté pour une classe qu'on n'a pas gagnée est ignoré (le fichier ne fait pas gagner)", Progression.new(chemin2).classe_choisie() == "")
	# Illisible : crié, mis de côté.
	var chemin3 := TEMP.path_join("abime.cfg")
	_ecrire_texte(chemin3, "[progression\nclasses = ((")
	_cris += 1
	var abime := Progression.new(chemin3)
	_check("un fichier PRÉSENT mais illisible est crié, mis de côté, et la progression repart vide",
		abime.fichier_illisible and abime.classes_debloquees().is_empty() and FileAccess.file_exists(chemin3 + ".illisible"))
	_check("le fichier de progression du joueur n'est pas celui d'une suite (`user://solo.cfg` n'est jamais écrit ici)", chemin != Progression.CHEMIN_PAR_DEFAUT)


# ---------------------------------------------------------------------------
# AUCUNE CARTE DE DUEL TOUCHÉE
# ---------------------------------------------------------------------------

## Le md5 de chaque fichier de `res://assets/maps` : la preuve qu'aucune carte livrée n'a été écrite ni modifiée.
func _empreinte_des_cartes_de_duel() -> Dictionary:
	var sortie := {}
	for f in DirAccess.get_files_at("res://assets/maps"):
		sortie[f] = FileAccess.get_md5("res://assets/maps/" + f)
	return sortie


func _aucune_carte_de_duel_touchee(avant: Dictionary) -> void:
	print("\n--- Aucune carte de duel n'est touchée ---")
	var apres := _empreinte_des_cartes_de_duel()
	_check("`assets/maps` : les %d fichiers sont inchangés après tout ce qui précède" % avant.size(), avant.size() >= 5 and apres == avant)
	var renvoi := false
	for i in _niveaux.size():
		renvoi = renvoi or JSON.stringify(_niveaux[i]).contains("assets/maps")
	_check("les niveaux EMBARQUENT leur carte : aucun ne renvoie vers `assets/maps`", not renvoi)
	_check("`assets/solo` n'est écrit par aucun code : ni ce format ni la progression n'ouvrent un fichier en écriture sous `res://`",
		not _ecrit_sous_res("res://aventure_format.gd") and not _ecrit_sous_res("res://aventure_progression.gd"))
	_check("le chapitre d'essai vit dans `tools/` : le chapitre livré (`assets/solo/`) est un autre, de dix salles",
		DirAccess.dir_exists_absolute("res://tools/aventure_essai/chapitre_00")
		and (Format.chapitres_livres().get(0, {}) as Dictionary).get("niveaux", []).size() == 10)
	_check("le format de carte (`map_codec.gd`) n'a pas été touché pour l'aventure : il ne nomme ni niveau ni PNJ",
		not FileAccess.get_file_as_string("res://map_codec.gd").to_lower().contains("pnj"))


func _ecrit_sous_res(chemin: String) -> bool:
	for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
		var nette: String = ligne.strip_edges()
		if nette.begins_with("#"):
			continue
		if nette.contains("FileAccess.open(") and nette.contains("WRITE") and nette.contains("res://"):
			return true
	return false


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

## Deux listes de mêmes éléments dans le même ordre, typées ou non.
func _memes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _dit(defauts: Array, mot: String) -> bool:
	for d in defauts:
		if String(d).contains(mot):
			return true
	return false


func _ecrire(chemin: String, donnees: Dictionary) -> void:
	_ecrire_texte(chemin, JSON.stringify(donnees))


func _ecrire_texte(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


## Supprime ce que la suite a écrit sous `user://test_aventure_format` — et seulement cela.
func _nettoyer() -> void:
	_supprimer(TEMP)


func _supprimer(dossier: String) -> void:
	if not DirAccess.dir_exists_absolute(dossier):
		return
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(f))
	for d in DirAccess.get_directories_at(dossier):
		_supprimer(dossier.path_join(d))
	DirAccess.remove_absolute(dossier)
