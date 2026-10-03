## Le BANC DE JEU de la difficulté du bot — chantier SOLO, étape S4. Il règle les profils : jamais une constante éditée à l'aveugle.
##
## Il fait s'affronter le bot de chaque difficulté (`ProfilBot.pour_adversaire_qui_tire`) à un JOUEUR TYPE honnête (même perception
## que le bot, réflexes humains de référence : 0,25 s de réaction, une erreur de visée humaine — voir `banc_bot_duel.gd`), sur les
## cartes livrées, avec quatre comportements de joueur, et imprime pour chaque difficulté :
##
##   • le TAUX DE VICTOIRE du joueur type (parmi les duels qui ont une issue) ;
##   • le TEMPS MOYEN jusqu'au premier coup qu'il reçoit ;
##   • la PART des tirs du bot déclenchés sur un SON (le cran 3 s'appelle « tire si vu ou entendu ») ;
##   • la PRÉCISION du bot : la part de ses tirs qui touchent.
##
## **Il ne mesure aucune cadence** (consigne d'Adrien) : un banc de jeu simule des parties. Un duel est un morceau de partie du vrai
## jeu monté, à pas d'image fixe, déterministe par graine ; il s'arrête à la première mort.
##
## ## Lancer (headless, `--fixed-fps 60` obligatoire : il refuse de conclure sans)
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/banc_bot_difficulte.gd -- [options]
##
## Options (après `--`) :
##   --duels=N              graines par case (carte × difficulté × comportement), 6 par défaut ; `--depuis=K` : la première graine (1 par défaut)
##   --cartes=a,b           identifiants de cartes livrées ; toutes par défaut (`--liste` les imprime)
##   --difficultes=f,n,d    facile, normal, difficile ; les trois par défaut
##   --comportements=a,b    parmi avance_torche, ecoute, accroupi_lent, tire_puis_bouge ; les quatre par défaut
##   --duree-max=S          secondes avant de déclarer un duel nul, 75 par défaut
##   --iso                  rejoue sous la vue iso du jeu publié (la simulation est la même ; deux fois plus lent)
##   --reflexes=R           le joueur type : `humain` (0,25 s de réaction, la référence, par défaut), `intermediaire` (0,35 s : un joueur qui
##                          vient de finir l'initiation) ou `debutant` (0,5 s)
##   --surcharge=c=v,c=v    règle des champs du ProfilBot de TOUS les bots du lot (exploration : `delai_reaction=0.3,tirs_par_rafale=2`) ;
##   --surcharge-facile=… (ou -normal, -difficile) : les mêmes, pour une seule difficulté
##   --part=i/n             ne joue que les duels d'indice i modulo n (pour répartir sur plusieurs processus)
##   --brut=fichier.json    écrit les enregistrements bruts d'un lot ; `--agreger=a.json,b.json` les fusionne et résume, sans jeu
##   --trace                ajoute à chaque enregistrement brut la trace du duel (positions, état du bot, vies), pour traquer un défaut de déterminisme
##   --classe=N             la classe du BOT, un index du catalogue (0 Parasite — le défaut —, 1 Illusionniste… 9 Spectre) : son gadget est celui qu'il pose (S9)
##   --sans-equipement      éteint les outils du bot (torche tactique, prudence, fusée, gadget) : le bot de S4, pour comparer « avant / après »
##   --catalogue            joue la mise en scène du CATALOGUE des PNJ (un débutant qui entre dans une salle) au lieu des duels
##
## Sortie : code 0 ; ce banc n'est pas un test (il imprime, il ne juge pas). La garde courte des suites est `test_banc_bot.gd`.
extends SceneTree

const Duel := preload("res://tools/banc_bot_duel.gd")
const Profil := preload("res://profil_bot.gd")
const Flux := preload("res://tools/flux_commandes_bot.gd")

const NOMS_DIFFICULTE := {"facile": Profil.Difficulte.FACILE, "normal": Profil.Difficulte.NORMAL, "difficile": Profil.Difficulte.DIFFICILE}


func _init() -> void:
	call_deferred("_run")


func _options() -> Dictionary:
	var o := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if not s.begins_with("--"):
			continue
		var i := s.find("=")
		if i < 0:
			o[s.substr(2)] = "1"
		else:
			o[s.substr(2, i - 2)] = s.substr(i + 1)
	return o


func _run() -> void:
	var o := _options()
	if o.has("agreger"):
		var records: Array = []
		for f in String(o["agreger"]).split(","):
			records.append_array(_lire_brut(String(f)))
		_imprimer(records)
		quit(0)
		return
	await process_frame
	var f0 := Engine.get_physics_frames()
	for _i in 30:
		await process_frame
	if absi(int(Engine.get_physics_frames() - f0) - 30) > 1:
		printerr("✗ l'horloge n'est pas fixe : lancer avec --fixed-fps 60 (sans lui, une « seconde simulée » ne vaut rien)")
		quit(1)
		return
	var duel := Duel.new(self)
	var cartes_livrees := _cartes_livrees()
	if o.has("liste"):
		for c in cartes_livrees:
			print("%s  (%s)" % [c["id"], c["name"]])
		quit(0)
		return
	if o.has("catalogue"):
		await _catalogue(duel, o)
		quit(0)
		return
	var ids: Array = []
	if o.has("cartes"):
		for c in String(o["cartes"]).split(","):
			ids.append(String(c))
	else:
		for c in cartes_livrees:
			ids.append(String(c["id"]))
	var difficultes: Array = []
	var noms_d := String(o.get("difficultes", "facile,normal,difficile")).split(",")
	for nom in noms_d:
		difficultes.append(nom)
	var comportements: Array = []
	for nom in String(o.get("comportements", ",".join(Duel.ORDRE_COMPORTEMENTS))).split(","):
		comportements.append(String(nom))
	var graines := int(o.get("duels", "6"))
	var depuis := int(o.get("depuis", "1"))
	var duree_max := float(o.get("duree-max", "75"))
	var part := String(o.get("part", "0/1")).split("/")
	var i_part := int(part[0])
	var n_part := maxi(int(part[1]), 1)

	var records: Array = []
	var indice := 0
	var t0 := Time.get_ticks_msec()
	for id in ids:
		var monte := false
		for nom_d in difficultes:
			for comp in comportements:
				for g in range(depuis, depuis + graines):
					indice += 1
					if (indice - 1) % n_part != i_part:
						continue
					if not monte:
						if not await duel.monter(id, {}, o.has("iso")):
							printerr("✗ le jeu ne se monte pas sur la carte %s" % id)
							quit(1)
							return
						monte = true
					var profil := Profil.pour_adversaire_qui_tire(NOMS_DIFFICULTE[nom_d])
					if o.has("sans-equipement"):
						Flux.sans_equipement(profil)
					_surcharger(profil, String(o.get("surcharge", "")) + "," + String(o.get("surcharge-" + nom_d, "")))
					var spec := {
						"profil_bot": profil, "reflexes": String(o.get("reflexes", "humain")),
						"comportement": Duel.COMPORTEMENTS[comp], "graine": g, "duree_max": duree_max,
					}
					if o.has("classe"):
						spec["classe"] = int(o["classe"])
					var trace: Array = []
					if o.has("trace"):
						spec["trace"] = trace
					var r := await duel.duel(spec)
					if o.has("trace"):
						r["trace"] = trace
					r["carte"] = id
					r["difficulte"] = nom_d
					r["comportement"] = comp
					records.append(r)
		print("  carte %s faite (%d duels, %.0f s)" % [id, records.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	if o.has("brut"):
		_ecrire_brut(String(o["brut"]), records)
	_imprimer(records)
	print("\n%d duels en %.0f s (horloge du processus, pas du jeu)" % [records.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


## `--surcharge=delai_reaction=0.3,tirs_par_rafale=2` : règle des champs du profil, pour explorer un réglage sans éditer le fichier.
## Un champ entier garde son type (`tirs_par_rafale`), les autres sont des flottants.
func _surcharger(profil: ProfilBot, texte: String) -> void:
	if texte == "":
		return
	for paire in texte.split(",", false):
		var kv := String(paire).split("=")
		if kv.size() != 2 or profil.get(kv[0]) == null:
			printerr("✗ surcharge inconnue : %s" % paire)
			continue
		var actuel: Variant = profil.get(kv[0])
		if actuel is bool:
			profil.set(kv[0], ["1", "true", "vrai", "oui"].has(kv[1]))
		else:
			profil.set(kv[0], int(kv[1]) if actuel is int else float(kv[1]))


func _cartes_livrees() -> Array:
	var sortie: Array = []
	for entree in root.get_node("MapData").list_maps():
		if String(entree["source"]) == "builtin":
			sortie.append({"id": String(entree["id"]), "name": String(entree["name"])})
	return sortie


func _ecrire_brut(chemin: String, records: Array) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		printerr("✗ impossible d'écrire %s" % chemin)
		return
	f.store_string(JSON.stringify(records))
	f.close()


func _lire_brut(chemin: String) -> Array:
	var t := FileAccess.get_file_as_string(chemin)
	var j := JSON.new()
	if j.parse(t) != OK or not (j.data is Array):
		printerr("✗ %s illisible" % chemin)
		return []
	return j.data


## Les tableaux : par difficulté (la ligne qui compte), puis par comportement du joueur type, puis par carte.
func _imprimer(records: Array) -> void:
	print("\n=== PAR DIFFICULTÉ (moyenne des comportements du joueur type et des cartes ; référence humaine : %.2f s, intermédiaire %.2f s, débutant %.2f s) ===" % [
		Duel.REACTION_HUMAINE, Duel.REACTION_INTERMEDIAIRE, Duel.REACTION_DEBUTANT])
	print("%-10s %6s %9s %9s %12s %10s %10s %10s %10s %8s   %s" % ["", "duels", "victoire", "nuls", "1er coup reçu", "fenêtre", "jamais tchd", "tirs/son", "précision", "durée",
		"fusées/gadgets/replis par duel"])
	for nom_d in ["facile", "normal", "difficile"]:
		var lot := records.filter(func(r: Dictionary) -> bool: return String(r["difficulte"]) == nom_d)
		if lot.is_empty():
			continue
		_ligne(nom_d, lot)
	print("\n=== PAR COMPORTEMENT DU JOUEUR TYPE (victoire du joueur type, par difficulté) ===")
	print("%-18s %10s %10s %10s" % ["", "facile", "normal", "difficile"])
	for comp in _comportements_vus(records):
		var cellules: Array[String] = []
		for nom_d in ["facile", "normal", "difficile"]:
			var lot := records.filter(func(r: Dictionary) -> bool: return String(r["difficulte"]) == nom_d and String(r["comportement"]) == comp)
			cellules.append("—" if lot.is_empty() else "%s (%d)" % [Duel.pct(Duel.resumer(lot)["victoire"]), lot.size()])
		print("%-18s %10s %10s %10s" % [comp, cellules[0], cellules[1], cellules[2]])
	print("\n=== PAR COMPORTEMENT (part des tirs du bot déclenchés sur un SON / précision du bot, par difficulté) ===")
	print("%-18s %16s %16s %16s" % ["", "facile", "normal", "difficile"])
	for comp in _comportements_vus(records):
		var cellules: Array[String] = []
		for nom_d in ["facile", "normal", "difficile"]:
			var lot := records.filter(func(r: Dictionary) -> bool: return String(r["difficulte"]) == nom_d and String(r["comportement"]) == comp)
			if lot.is_empty():
				cellules.append("—")
			else:
				var s := Duel.resumer(lot)
				cellules.append("%s / %s" % [Duel.pct(s["tirs_sur_son"]), Duel.pct(s["precision"])])
		print("%-18s %16s %16s %16s" % [comp, cellules[0], cellules[1], cellules[2]])
	print("\n=== PAR CARTE (victoire du joueur type, par difficulté) ===")
	var ids: Array[String] = []
	for r in records:
		if not ids.has(String(r["carte"])):
			ids.append(String(r["carte"]))
	for id in ids:
		var cellules: Array[String] = []
		for nom_d in ["facile", "normal", "difficile"]:
			var lot := records.filter(func(r: Dictionary) -> bool: return String(r["difficulte"]) == nom_d and String(r["carte"]) == id)
			cellules.append("—" if lot.is_empty() else "%s (%d)" % [Duel.pct(Duel.resumer(lot)["victoire"]), lot.size()])
		print("%-18s %10s %10s %10s" % [id, cellules[0], cellules[1], cellules[2]])


## Les comportements présents dans le lot, dans l'ordre du banc (puis les autres, dans l'ordre où on les rencontre).
func _comportements_vus(records: Array) -> Array[String]:
	var vus: Array[String] = []
	for comp in Duel.COMPORTEMENTS:
		for r in records:
			if String(r["comportement"]) == comp:
				vus.append(comp)
				break
	return vus


func _ligne(nom: String, lot: Array) -> void:
	var s := Duel.resumer(lot)
	print("%-10s %6d %9s %9s %12s %10s %10s %10s %10s %8s   %.2f / %.2f / %.2f" % [nom, s["n"], Duel.pct(s["victoire"]), Duel.pct(s["nuls_part"]),
		Duel.sec(s["premier_coup_recu"]), Duel.sec(s["fenetre"]), Duel.pct(s["jamais_touche"]), Duel.pct(s["tirs_sur_son"]),
		Duel.pct(s["precision"]), Duel.sec(s["duree_moyenne"]), s["fusees"], s["poses"], s["replis"]])



## Les PNJ à juger, dans l'ordre où l'aventure les rencontre : les cinq de l'initiation, leurs frères des autres paliers, puis les
## déplacements des chapitres suivants, puis le boss.
static func _pnj_a_juger() -> Array[String]:
	var noms: Array[String] = ["immobile_sourd_aveugle"]
	for s in ["voit", "entend", "voit_entend"]:
		for pa in ["tres_lent", "lent", "facile", "normal"]:
			noms.append("immobile_%s_%s" % [s, pa])
	for d in ["ronde", "zone", "libre"]:
		for pa in ["lent", "normal"]:
			noms.append("%s_voit_entend_%s" % [d, pa])
	return noms


## Le catalogue des PNJ : pour chacun, `--duels` graines par comportement du débutant, dans la salle de la mise en scène.
func _catalogue(duel: RefCounted, o: Dictionary) -> void:
	var n := int(o.get("duels", "16"))
	var noms: Array[String] = []
	if o.has("pnj"):
		for nom in String(o["pnj"]).split(","):
			noms.append(String(nom))
	else:
		noms = _pnj_a_juger()
	if not await duel.monter_la_salle():
		printerr("✗ le jeu ne se monte pas sur la salle")
		quit(1)
		return
	print("=== LE CATALOGUE DES PNJ : un joueur « %s », torche allumée, traverse une salle de %d × %d cases ===" % [
		String(o.get("reflexes", "debutant")), Duel.SALLE_L, Duel.SALLE_H])
	print("%-30s %-9s %5s %9s %9s %12s %14s %10s" % ["PNJ", "débutant", "duels", "gagne", "PNJ tire", "perçu→1er tir", "perçu→1er coup", "coups reçus"])
	var part := String(o.get("part", "0/1")).split("/")
	var indice := -1
	for nom in noms:
		indice += 1
		if indice % maxi(int(part[1]), 1) != int(part[0]):
			continue
		for comp in ["debout", "accroupi"]:
			var lot: Array = []
			for g in range(1, n + 1):
				var pnj := ProfilBot.pnj_nomme(nom)
				_surcharger(pnj, String(o.get("surcharge", "")))
				lot.append(await duel.duel_salle(pnj, comp, g, 60.0, String(o.get("reflexes", "debutant"))))
			_ligne_pnj(nom, comp, lot)


func _ligne_pnj(nom: String, comp: String, lot: Array) -> void:
	var gagnes := 0
	var tire := 0
	var s_lat := 0.0
	var n_lat := 0
	var s_fen := 0.0
	var n_fen := 0
	var coups := 0
	for r in lot:
		if String(r["issue"]) == "joueur":
			gagnes += 1
		if int(r["tirs_bot"]) > 0:
			tire += 1
		var tp := float(r["t_premiere_perception_bot"])
		if tp >= 0.0 and float(r["t_premier_tir_bot"]) >= 0.0:
			s_lat += float(r["t_premier_tir_bot"]) - tp
			n_lat += 1
		if tp >= 0.0 and float(r["t_coup_recu"]) >= 0.0:
			s_fen += float(r["t_coup_recu"]) - tp
			n_fen += 1
		coups += int(r["touches_bot"])
	var n := float(lot.size())
	print("%-30s %-9s %5d %9s %9s %12s %14s %10.2f" % [nom, comp, lot.size(), Duel.pct(gagnes / n), Duel.pct(tire / n),
		Duel.sec(s_lat / n_lat if n_lat > 0 else NAN), Duel.sec(s_fen / n_fen if n_fen > 0 else NAN), coups / n])
