## La garde COURTE du banc de jeu du bot — chantier SOLO, étape S4. Les profils sont réglés au banc (`banc_bot_difficulte.gd`, long,
## hors des suites) ; cette suite en garde ce qui ne doit pas bouger, en quelques dizaines de secondes :
##
##   • **le catalogue** — chaque PNJ de l'aventure se construit, par son nom, avec les bons axes : le sourd et aveugle ne perçoit rien
##     et ne tire jamais, celui qui voit ne fait que voir, celui qui entend ne fait qu'entendre ; les paliers de réflexes se
##     rangent du plus lent au plus vif ; le boss est le profil NORMAL de l'entraînement ;
##   • **les trois difficultés** — mêmes champs de perception, de déplacement ET D'AUDACE (la difficulté règle QUAND et AVEC QUELLE
##     JUSTESSE le bot tire, jamais SI : S3 laissait FACILE sourd à un pas à 400 px) ;
##   • **le duel simulé** — déterministe par graine ; puis, sur une carte et quatre comportements de joueur type, **l'ORDRE** des
##     difficultés : le joueur type gagne plus souvent contre FACILE que contre NORMAL, plus contre NORMAL que contre DIFFICILE, avec
##     des BORNES LARGES (jamais un chiffre exact : ceux du banc sont des cibles à juger en jouant, pas des constantes) ;
##   • **les PNJ de l'initiation, dans une salle** — un débutant torche allumée bat le PNJ très lent presque toujours, le PNJ qui voit
##     met du temps à tirer, celui qui est sourd et aveugle ne tire jamais.
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`) : un duel est un nombre de pas de physique. La suite vérifie elle-même
## l'horloge et refuse de conclure sans elle.
##
## **Sabotée** (la règle du dépôt) : la liste est dans la ROADMAP, section SOLO, S4.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_banc_bot.gd
extends SceneTree

const Duel := preload("res://tools/banc_bot_duel.gd")
const Profil := preload("res://profil_bot.gd")
const Flux := preload("res://tools/flux_commandes_bot.gd")

var _failures := 0
var _verifications := 0
## UN SEUL banc de jeu pour toute la suite : un second `Duel` monterait un second `main.tscn` à côté du premier (deux jeux dans l'arbre).
var _duel: Duel = null


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
	print("=== LE BANC DE JEU DU BOT (S4) : catalogue, difficultés, duels ===")
	_duel = Duel.new(self)
	await process_frame
	_le_catalogue()
	_les_difficultes()
	_le_joueur_type_est_honnete()
	# Le banc long n'est dans aucune suite : qu'il compile encore (un banc hors couverture se périme en silence).
	var banc: GDScript = load("res://tools/banc_bot_difficulte.gd")
	_check("le banc long (`banc_bot_difficulte.gd`, hors des suites) compile encore", banc != null and banc.can_instantiate())
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	var horloge_fixe := absi(int(Engine.get_physics_frames() - f0) - 60) <= 1
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe, "lancer avec --fixed-fps 60")
	if horloge_fixe:
		await _les_duels()
		await _les_pnj_dans_la_salle()
	print("\n%d vérifications" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# LE CATALOGUE
# ---------------------------------------------------------------------------

func _axes(p: ProfilBot) -> String:
	return "dep=%d voit=%s entend=%s agit=%s tire=%s" % [p.deplacement, p.voit, p.entend, p.agit, p.tire]


func _le_catalogue() -> void:
	print("\n[Le catalogue des PNJ : chaque nom se construit, avec les bons axes]")
	var noms := Profil.noms_du_catalogue()
	var uniques := {}
	for n in noms:
		uniques[n] = true
	_check("le catalogue énumère 4 déplacements × (1 sourd et aveugle + 3 sens × 5 paliers) = 64 PNJ, tous différents (%d, %d)" % [noms.size(), uniques.size()],
		noms.size() == 64 and uniques.size() == 64)
	var tous_se_construisent := true
	var nom_fautif := ""
	for nom in noms:
		var p := Profil.pnj_nomme(nom)
		if p == null:
			tous_se_construisent = false
			nom_fautif = nom
	_check("chaque nom du catalogue se construit (`pnj_nomme`)", tous_se_construisent, nom_fautif)
	_check("un nom qui n'est pas du catalogue ne rend rien (un niveau mal écrit se voit)",
		Profil.pnj_nomme("") == null and Profil.pnj_nomme("immobile_voit") == null and Profil.pnj_nomme("vole_voit_lent") == null
		and Profil.pnj_nomme("immobile_voit_lentissime") == null and Profil.pnj_nomme("immobile_voit_lent_trop") == null)

	var axes_justes := true
	var detail := ""
	for nom in noms:
		var p := Profil.pnj_nomme(nom)
		if p == null:
			continue
		var morceaux := nom.split("_")
		var dep: int = {"immobile": Profil.Deplacement.IMMOBILE, "ronde": Profil.Deplacement.RONDE, "zone": Profil.Deplacement.ZONE,
			"libre": Profil.Deplacement.LIBRE}[morceaux[0]]
		var sourd := nom.ends_with("sourd_aveugle")
		var voit_att := not sourd and nom.contains("_voit")
		var entend_att := not sourd and nom.contains("entend")
		var ok := p.deplacement == dep and p.voit == voit_att and p.entend == entend_att and p.agit == (not sourd) and p.tire == (not sourd)
		if not ok:
			axes_justes = false
			detail = "%s : %s" % [nom, _axes(p)]
	_check("chaque PNJ a les axes que son nom dit : déplacement, voit, entend, agit, tire (le sourd et aveugle n'agit ni ne tire)", axes_justes, detail)

	# Les cinq PNJ de l'initiation, par leurs noms de fonction.
	var sa := Profil.pnj_immobile_sourd_aveugle()
	_check("PNJ de l'initiation — immobile, sourd et aveugle : ne perçoit rien, n'agit pas, ne tire JAMAIS",
		sa.deplacement == Profil.Deplacement.IMMOBILE and not sa.voit and not sa.entend and not sa.agit and not sa.tire, _axes(sa))
	var vt := Profil.pnj_immobile_voit_tres_lent()
	_check("PNJ de l'initiation — immobile qui voit et tire, réflexes TRÈS lents : voit, n'entend pas, tire",
		vt.deplacement == Profil.Deplacement.IMMOBILE and vt.voit and not vt.entend and vt.agit and vt.tire, _axes(vt))
	var vl := Profil.pnj_immobile_voit_lent()
	_check("PNJ de l'initiation — immobile qui voit et tire, réflexes lents : voit, n'entend pas, tire",
		vl.deplacement == Profil.Deplacement.IMMOBILE and vl.voit and not vl.entend and vl.agit and vl.tire, _axes(vl))
	var el := Profil.pnj_immobile_entend_lent()
	_check("PNJ de l'initiation — immobile qui entend et tire, réflexes lents : entend, ne voit pas, tire",
		el.deplacement == Profil.Deplacement.IMMOBILE and el.entend and not el.voit and el.agit and el.tire, _axes(el))
	var vel := Profil.pnj_immobile_voit_entend_lent()
	_check("PNJ de l'initiation — immobile qui voit et entend, lent : voit, entend, tire",
		vel.deplacement == Profil.Deplacement.IMMOBILE and vel.voit and vel.entend and vel.agit and vel.tire, _axes(vel))
	_check("… le très lent réagit plus lentement que le lent (%.2f s > %.2f s), vise moins bien et tire moins souvent" % [vt.delai_reaction, vl.delai_reaction],
		vt.delai_reaction > vl.delai_reaction and vt.erreur_visee_deg > vl.erreur_visee_deg and vt.pause_entre_rafales > vl.pause_entre_rafales)
	_check("… et les noms de fonction sont ceux du catalogue (immobile_voit_tres_lent, …)",
		Profil.nom_du_pnj(Profil.Deplacement.IMMOBILE, Profil.Sens.VUE, Profil.Palier.TRES_LENT) == "immobile_voit_tres_lent"
		and Profil.pnj_nomme("immobile_voit_tres_lent").delai_reaction == vt.delai_reaction
		and Profil.pnj_nomme("immobile_entend_lent").entend and Profil.pnj_nomme("immobile_voit_entend_lent").voit)

	# Les paliers de réflexes : du plus lent au plus vif, tous les champs dans le même sens.
	var pa: Array[ProfilBot] = []
	for palier in [Profil.Palier.TRES_LENT, Profil.Palier.LENT, Profil.Palier.FACILE, Profil.Palier.NORMAL, Profil.Palier.DIFFICILE]:
		pa.append(Profil.pnj(Profil.Deplacement.IMMOBILE, Profil.Sens.VUE, palier))
	var delais := true
	var erreurs := true
	var vitesses := true
	var tolerances := true
	var pauses := true
	for i in range(1, pa.size()):
		delais = delais and pa[i - 1].delai_reaction > pa[i].delai_reaction
		erreurs = erreurs and pa[i - 1].erreur_visee_deg > pa[i].erreur_visee_deg and pa[i - 1].erreur_visee_min_deg > pa[i].erreur_visee_min_deg
		vitesses = vitesses and pa[i - 1].vitesse_visee < pa[i].vitesse_visee
		tolerances = tolerances and pa[i - 1].tolerance_tir_deg >= pa[i].tolerance_tir_deg
		pauses = pauses and pa[i - 1].pause_entre_rafales > pa[i].pause_entre_rafales
	_check("les cinq paliers de réflexes se rangent du plus lent au plus vif : délai, erreur de visée (et plancher), vitesse de visée, tolérance, pause",
		delais and erreurs and vitesses and tolerances and pauses, "délais %s erreurs %s vitesses %s tolérances %s pauses %s" % [delais, erreurs, vitesses, tolerances, pauses])
	var meme_audace := true
	for p in pa:
		meme_audace = meme_audace and is_equal_approx(p.audace_zone_px, Profil.AUDACE_ZONE_PX)
	_check("… et ils partagent la même audace (la difficulté ne change pas SI le bot tire sur un son)", meme_audace)
	# Les déplacements des chapitres suivants.
	var ronde := Profil.pnj_nomme("ronde_voit_lent")
	var zone := Profil.pnj_nomme("zone_entend_normal")
	var libre := Profil.pnj_nomme("libre_voit_entend_difficile")
	_check("les chapitres suivants : ronde, zone et libre existent avec les mêmes paliers (allures 0,5 / 0,6 / 0,7)",
		ronde.deplacement == Profil.Deplacement.RONDE and zone.deplacement == Profil.Deplacement.ZONE and libre.deplacement == Profil.Deplacement.LIBRE
		and is_equal_approx(ronde.allure, 0.5) and is_equal_approx(zone.allure, 0.6) and is_equal_approx(libre.allure, 0.7)
		and is_equal_approx(libre.delai_reaction, Profil.pour_adversaire_qui_tire(Profil.Difficulte.DIFFICILE).delai_reaction))
	# Le boss.
	var boss := Profil.boss()
	var normal := Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
	var meme := true
	var champ_different := ""
	for prop in normal.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			if boss.get(prop["name"]) != normal.get(prop["name"]):
				meme = false
				champ_different = prop["name"]
	_check("le BOSS est le profil d'entraînement NORMAL, champ pour champ (« juste un bot en mode moyen »)", meme, champ_different)


# ---------------------------------------------------------------------------
# LE JOUEUR TYPE EST HONNÊTE
# ---------------------------------------------------------------------------

## Le joueur type est le même `BotInputProvider` que le bot, avec la torche, la posture et le changement de place en plus. **Il ne lit jamais
## l'adversaire** — ni son nœud, ni le groupe `players`, ni la scène — : un étalon qui saurait où est le bot dans le noir ne mesurerait rien. Le texte
## de sa classe, commentaires exclus, ne contient aucun de ces appels (la garde que `test_bot_combat` pose sur le fournisseur du bot).
func _le_joueur_type_est_honnete() -> void:
	print("\n[Le joueur type est honnête : il ne lit jamais l'adversaire]")
	var texte := FileAccess.get_file_as_string("res://tools/banc_bot_duel.gd")
	var debut := texte.find("class JoueurType extends BotInputProvider:")
	var fin := texte.find("class Muet extends InputProvider:")
	_check("la classe `JoueurType` se retrouve dans la bibliothèque du banc", debut >= 0 and fin > debut)
	var code := ""
	for ligne in texte.substr(debut, fin - debut).split("\n"):
		if not String(ligne).strip_edges().begins_with("#"):
			code += ligne + "\n"
	for interdit in ["get_nodes_in_group", "get_first_node_in_group", "get_tree()", "\"players\"", "find_child", "get_node(", "get_node_or_null(",
			"global_position", "main.p", "perception.monde"]:
		_check("le code du joueur type ne contient pas « %s » : il ne va pas chercher le bot" % interdit, not code.contains(interdit))


# ---------------------------------------------------------------------------
# LES TROIS DIFFICULTÉS
# ---------------------------------------------------------------------------

func _les_difficultes() -> void:
	print("\n[Les trois difficultés : seuls les réflexes changent]")
	var f := Profil.pour_adversaire_qui_tire(Profil.Difficulte.FACILE)
	var n := Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
	var d := Profil.pour_adversaire_qui_tire(Profil.Difficulte.DIFFICILE)
	var communs := ["voit", "entend", "precision_auditive", "delai_oubli", "deplacement", "allure", "torche_allumee", "agit", "tire", "audace_zone_px"]
	var pas_identique := ""
	for champ in communs:
		if f.get(champ) != n.get(champ) or n.get(champ) != d.get(champ):
			pas_identique = champ
	_check("les trois difficultés ont les mêmes champs de perception, de déplacement, d'AUDACE et d'agir : voit, entend, précision, oubli, déplacement, allure, torche, agit, tire, audace",
		pas_identique == "", pas_identique)
	_check("… elles VOIENT et ENTENDENT toutes les trois, et tirent (« adversaire qui tire si vu ou entendu »)", f.voit and f.entend and f.tire and n.voit and n.entend and n.tire and d.voit and d.entend and d.tire)
	_check("… et leur audace couvre un pas entendu à 400 px (zone de 68 px) : aucune n'est sourde aux sons proches",
		f.audace_zone_px >= 68.0 and n.audace_zone_px >= 68.0 and d.audace_zone_px >= 68.0)
	_check("les trois profils sont exactement ceux des paliers FACILE, NORMAL, DIFFICILE (une seule table de réflexes)",
		_reflexes_egaux(f, _du_palier(Profil.Palier.FACILE)) and _reflexes_egaux(n, _du_palier(Profil.Palier.NORMAL))
		and _reflexes_egaux(d, _du_palier(Profil.Palier.DIFFICILE)))
	_check("le délai de réaction décroît (%.2f > %.2f > %.2f s) et l'erreur de visée aussi (%.0f > %.0f > %.0f °)" % [
		f.delai_reaction, n.delai_reaction, d.delai_reaction, f.erreur_visee_deg, n.erreur_visee_deg, d.erreur_visee_deg],
		f.delai_reaction > n.delai_reaction and n.delai_reaction > d.delai_reaction
		and f.erreur_visee_deg > n.erreur_visee_deg and n.erreur_visee_deg > d.erreur_visee_deg)


func _du_palier(palier: int) -> ProfilBot:
	var p := ProfilBot.new()
	Profil.appliquer_les_reflexes(p, palier)
	return p


func _reflexes_egaux(a: ProfilBot, b: ProfilBot) -> bool:
	for champ in ["delai_reaction", "erreur_visee_deg", "erreur_visee_min_deg", "duree_resserrement", "vitesse_visee",
			"tolerance_tir_deg", "tirs_par_rafale", "pause_entre_rafales", "audace_zone_px"]:
		if a.get(champ) != b.get(champ):
			return false
	return true


# ---------------------------------------------------------------------------
# LES DUELS
# ---------------------------------------------------------------------------

## La carte et les graines de la forme courte. Choisies pour que la suite tienne en une minute : la Croisée et les quatre
## comportements du joueur type, `GRAINES` duels par case.
const CARTE_COURTE := "map_003"
const GRAINES := 4


func _les_duels() -> void:
	print("\n[Le duel simulé : déterministe, et les difficultés se rangent dans l'ordre]")
	var duel := _duel
	_check("le jeu se monte sur la carte « %s » (entraînement, cran 3)" % CARTE_COURTE, await duel.monter(CARTE_COURTE))
	# Déterminisme : le même duel, deux fois, donne le même enregistrement — avec un autre duel entre les deux (rien ne fuit d'un duel à l'autre).
	var normal := Profil.pour_adversaire_qui_tire(Profil.Difficulte.NORMAL)
	var a := await duel.duel({"profil_bot": normal, "comportement": Duel.COMPORTEMENTS["avance_torche"], "graine": 3, "duree_max": 40.0})
	await duel.duel({"profil_bot": Profil.pour_adversaire_qui_tire(Profil.Difficulte.FACILE), "comportement": Duel.COMPORTEMENTS["ecoute"], "graine": 9, "duree_max": 20.0})
	var b := await duel.duel({"profil_bot": normal, "comportement": Duel.COMPORTEMENTS["avance_torche"], "graine": 3, "duree_max": 40.0})
	var identiques := true
	for cle in ["issue", "t_fin", "t_coup_recu", "t_coup_donne", "tirs_bot", "touches_bot", "tirs_joueur", "touches_joueur", "t_premier_tir_bot"]:
		if a[cle] != b[cle]:
			identiques = false
	_check("même graine, même duel : issue %s à %.2f s, %d tirs du bot, %d touches (rejoué à l'identique, un autre duel entre les deux)" % [
		a["issue"], a["t_fin"], a["tirs_bot"], a["touches_bot"]], identiques, "%s / %s" % [str(a), str(b)])
	_check("un duel a une issue et des tirs de part et d'autre (le bot tire : %d coups ; le joueur type : %d)" % [a["tirs_bot"], a["tirs_joueur"]],
		a["issue"] != "nul" and int(a["tirs_bot"]) + int(a["tirs_joueur"]) > 0)

	var par_difficulte := {}
	# Tous les duels de la suite, pour la garde des FUITES d'un duel à l'autre (plus bas).
	var tous: Array = []
	for nom_d in ["facile", "normal", "difficile"]:
		var difficulte: int = {"facile": Profil.Difficulte.FACILE, "normal": Profil.Difficulte.NORMAL, "difficile": Profil.Difficulte.DIFFICILE}[nom_d]
		var lot: Array = []
		for comp in Duel.ORDRE_COMPORTEMENTS:
			for g in range(1, GRAINES + 1):
				lot.append(await duel.duel({"profil_bot": Profil.pour_adversaire_qui_tire(difficulte), "comportement": Duel.COMPORTEMENTS[comp],
					"graine": g, "duree_max": 60.0}))
		tous.append_array(lot)
		par_difficulte[nom_d] = Duel.resumer(lot)
		print("    · %s : %d duels, victoire du joueur type %s, 1er coup reçu %s, précision du bot %s, tirs sur un son %s, nuls %s" % [
			nom_d, lot.size(), Duel.pct(par_difficulte[nom_d]["victoire"]), Duel.sec(par_difficulte[nom_d]["premier_coup_recu"]),
			Duel.pct(par_difficulte[nom_d]["precision"]), Duel.pct(par_difficulte[nom_d]["tirs_sur_son"]), Duel.pct(par_difficulte[nom_d]["nuls_part"])])
	var vf: float = par_difficulte["facile"]["victoire"]
	var vn: float = par_difficulte["normal"]["victoire"]
	var vd: float = par_difficulte["difficile"]["victoire"]
	_check("L'ORDRE : le joueur type gagne plus souvent contre FACILE que contre NORMAL, et contre NORMAL que contre DIFFICILE (%.0f %% > %.0f %% > %.0f %%)" % [
		100.0 * vf, 100.0 * vn, 100.0 * vd], vf > vn and vn > vd)
	_check("… avec de l'écart : au moins 5 points de chaque côté (la différence se SENT ; le banc long en mesure ~20 et ~30)", vf - vn >= 0.05 and vn - vd >= 0.05)
	_check("bornes larges : FACILE se gagne (au moins 60 %%), DIFFICILE se perd plus qu'il ne se gagne (au plus 55 %%) — %.0f %% / %.0f %%" % [100.0 * vf, 100.0 * vd],
		vf >= 0.60 and vd <= 0.55)
	_check("NORMAL, le boss de chaque chapitre, est battable sans être donné : entre 30 %% et 90 %% (%.0f %%)" % (100.0 * vn), vn >= 0.30 and vn <= 0.90)
	var nuls_max := 0.0
	for nom_d in par_difficulte:
		nuls_max = maxf(nuls_max, float(par_difficulte[nom_d]["nuls_part"]))
	_check("presque aucun duel n'est nul (au plus 15 %% sur 60 s simulées, pire lot %.0f %%) : un banc qui ne tranche pas ne mesure rien" % (100.0 * nuls_max), nuls_max <= 0.15)
	var fp: float = par_difficulte["facile"]["precision"]
	var dp: float = par_difficulte["difficile"]["precision"]
	_check("le bot difficile touche plus souvent que le facile (%.0f %% contre %.0f %% de ses tirs)" % [100.0 * dp, 100.0 * fp], dp > fp)
	# « Tire si vu ou ENTENDU » dans le vrai jeu (décision d'Adrien) : un joueur qui marche dans le noir, qu'on n'entend que, fait tirer
	# les TROIS difficultés sur un son — pas seulement les corps factices de `test_bot_combat`. (S3 : FACILE n'y tirait jamais.)
	for nom_d in ["facile", "normal", "difficile"]:
		var difficulte: int = {"facile": Profil.Difficulte.FACILE, "normal": Profil.Difficulte.NORMAL, "difficile": Profil.Difficulte.DIFFICILE}[nom_d]
		var sur_un_son := 0
		var tirs := 0
		for g in range(1, GRAINES + 1):
			# ⚠️ S9 : les OUTILS éteints. Le DIFFICILE équipé lance une fusée vers ce qu'il a entendu : il le VOIT alors, et son tir n'est plus « sur un
			# son » — c'est ce que la fusée est faite pour. Ce contrôle garde la RÈGLE d'audace (tirer sur une zone entendue, pour les trois difficultés),
			# pas les outils : ceux-ci ont leur garde (`test_bot_equipement`).
			var r := await duel.duel({"profil_bot": Flux.sans_equipement(Profil.pour_adversaire_qui_tire(difficulte)), "comportement": Duel.COMPORTEMENT_BRUYANT,
				"graine": g, "duree_max": 60.0})
			tous.append(r)
			sur_un_son += int(r["tirs_bot_son"])
			tirs += int(r["tirs_bot"])
		_check("(%s) face à un joueur qui marche dans le noir, le bot tire sur un SON (%d tirs sur %d, déclenchés sans rien voir)" % [nom_d, sur_un_son, tirs],
			sur_un_son > 0)


	# Aucun duel ne commence par un SON que le duel d'avant a lancé : une douille sonne 0,3 à 0,5 s après le tir, et un joueur remis sur pied
	# la ferait sonner à sa NOUVELLE place, au premier instant du duel suivant. Aucun tir n'a pu partir en 0,15 s : un « shell » perçu si tôt est une fuite.
	var fuites := 0
	for r in tous:
		if String(r.get("premiere_perception_bot", "")).begins_with("son:shell") and float(r["t_premiere_perception_bot"]) < 0.15:
			fuites += 1
	_check("aucune fuite d'un duel à l'autre : sur %d duels, pas un ne commence par la douille du duel d'avant (%d)" % [tous.size(), fuites], fuites == 0)


# ---------------------------------------------------------------------------
# LES PNJ DE L'INITIATION, DANS UNE SALLE
# ---------------------------------------------------------------------------

const GRAINES_SALLE := 4


func _les_pnj_dans_la_salle() -> void:
	print("\n[Les PNJ de l'initiation : un débutant qui entre dans une salle]")
	var duel := _duel
	_check("le jeu se monte sur la salle (%d × %d cases)" % [Duel.SALLE_L, Duel.SALLE_H], await duel.monter_la_salle())
	var res := {}
	for nom in ["immobile_sourd_aveugle", "immobile_voit_tres_lent", "immobile_voit_lent"]:
		var lot: Array = []
		for g in range(1, GRAINES_SALLE + 1):
			lot.append(await duel.duel_salle(Profil.pnj_nomme(nom), "debout", g))
		res[nom] = lot
	var tirs_sourd := 0
	var gagne_sourd := 0
	for r in res["immobile_sourd_aveugle"]:
		tirs_sourd += int(r["tirs_bot"])
		if String(r["issue"]) == "joueur":
			gagne_sourd += 1
	_check("(immobile sourd et aveugle) il ne tire JAMAIS (%d balles en %d duels) et le débutant le bat à chaque fois (%d/%d)" % [
		tirs_sourd, GRAINES_SALLE, gagne_sourd, GRAINES_SALLE], tirs_sourd == 0 and gagne_sourd == GRAINES_SALLE)
	for nom in ["immobile_voit_tres_lent", "immobile_voit_lent"]:
		var gagnes := 0
		var somme_lat := 0.0
		var n_lat := 0
		for r in res[nom]:
			if String(r["issue"]) == "joueur":
				gagnes += 1
			if float(r["t_premiere_perception_bot"]) >= 0.0 and float(r["t_premier_tir_bot"]) >= 0.0:
				somme_lat += float(r["t_premier_tir_bot"]) - float(r["t_premiere_perception_bot"])
				n_lat += 1
		var lat := somme_lat / float(n_lat) if n_lat > 0 else NAN
		var minimum := 0.8 if nom == "immobile_voit_tres_lent" else 0.5
		_check("(%s) le débutant, torche allumée, le bat presque toujours (%d/%d) et le PNJ met %.1f s entre percevoir et son premier tir (au moins %.1f s : le temps de réagir)" % [
			nom, gagnes, GRAINES_SALLE, lat, minimum],
			gagnes >= GRAINES_SALLE - 1 and n_lat > 0 and lat >= minimum, "%d/%d, %.2f s sur %d duels" % [gagnes, GRAINES_SALLE, lat, n_lat])
