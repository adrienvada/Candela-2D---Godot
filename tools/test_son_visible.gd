extends SceneTree

## Le son rendu visible — le MODÈLE (`son_visible.gd`), sans scène.
## Lancer : godot --headless --path . --script res://tools/test_son_visible.gd
##
## Ce qu'elle garde, dans l'ordre des décisions d'Adrien du 2026-09-29 :
## - les deux ancres : le pas de course tout près fait 10°, le pas accroupi 180° ;
## - la distance, les murs, la fumée et la salle ÉLARGISSENT, jamais l'inverse ;
## - l'allure au stick baisse le bruit sans jamais valoir la posture (Q47) ;
## - le code couleur (Q48) : une teinte par sorte, toutes distinctes, toutes
##   tenues par la charte (saturation, pas de vert, ni le bleu de « soi » ni le
##   rouge du voile de dégâts) ;
## - la géométrie du bord : un liseré reste sur le bord de l'écran, coins compris ;
## - la FORME D'ONDE (Adrien, 2026-09-29 : « un long son très réverbéré doit durer
##   autant que le son, et un son très court et étouffé doit durer très peu ») : le
##   liseré suit l'enveloppe du fichier joué (VU-mètre : attaque immédiate, relâchement
##   de 50 ms), puis la traîne de la salle (déclin de 60 dB en RT60 secondes, départ
##   fixé par le wet et la résonance de la sorte), s'ÉLARGIT pendant la traîne, et vit
##   tant que son niveau PERÇU reste au-dessus du seuil — raisonné en dB, jamais en
##   fraction d'une durée. Derrière un mur le direct baisse plus que la traîne, une
##   source continue est plate, et le pic garde les ancres et les paliers d'avant.
##
## La partie qui a besoin des autoloads — chaque famille d'`AudioManager` a sa
## sorte, l'émission par l'entonnoir, les vues de J1 et de J2 — vit dans
## `test_son_visible_jeu.gd` ; le lien de la table d'enveloppes aux WAV, dans
## `test_enveloppes_sons.gd`.

const SV := preload("res://son_visible.gd")
const C := preload("res://charte.gd")

var _ok := 0
var _ko := 0


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


func _proche(a: float, b: float, quoi: String, tol := 0.01) -> void:
	_check(absf(a - b) <= tol, "%s : %.4f attendu, %.4f obtenu" % [quoi, b, a])


const PORTEE := 1000.0
const CAT := SV.Categorie


func _p(cat: int, niveau: float, distance: float, portee := PORTEE, part := 0.0,
		fumee := 0.0, wet := 0.0, diag := 0.0) -> Dictionary:
	return SV.percevoir(cat, niveau, distance, portee, part, fumee, wet, diag)


# --- Les deux ancres d'Adrien ---------------------------------------------------

func _test_ancres() -> void:
	var course := _p(CAT.PAS, SV.NIVEAU_NET_DB, 0.0)
	_proche(float(course["largeur"]), 10.0, "le pas de course au contact fait 10°")
	# « lorsque le joueur ennemi marche rapidement PRÈS du joueur » : à 60 px,
	# la précision est encore celle de l'ancre.
	var pres := _p(CAT.PAS, SV.NIVEAU_NET_DB, 60.0)
	_check(float(pres["largeur"]) <= 12.0,
		"le pas de course à 60 px reste sous 12° (%.1f°)" % float(pres["largeur"]))
	var accroupi := _p(CAT.PAS, SV.NIVEAU_FLOU_DB, 0.0, PORTEE * 0.5)
	_proche(float(accroupi["largeur"]), 180.0, "le pas accroupi au contact fait 180°")
	# « très très très léger » : bien moins de la moitié du pas de course.
	_check(float(accroupi["alpha"]) < 0.2, "le pas accroupi est très léger (alpha %.3f)" % float(accroupi["alpha"]))
	_check(float(accroupi["alpha"]) < float(course["alpha"]) * 0.5,
		"le pas accroupi pèse moins de la moitié du pas de course")
	var tir := _p(CAT.TIR, SV.NIVEAU_FORT_DB, 0.0)
	_proche(float(tir["largeur"]), 10.0, "le tir au contact fait 10°")
	_proche(float(tir["alpha"]), SV.ALPHA_MAX, "le tir au contact est le plus présent")
	_proche(float(tir["epaisseur"]), SV.EPAISSEUR_MAX_PX, "le tir au contact est le plus épais")
	_check(SV.PERTE_DISTANCE_DB < 0.0, "la distance coûte")
	_proche(SV.NIVEAU_SEUIL_DB, -31.0, "le seuil dérive des deux ancres")


# --- La distance, les murs, la fumée, la salle ----------------------------------

func _test_elargissements() -> void:
	var avant := _p(CAT.PAS, SV.NIVEAU_NET_DB, 0.0)
	for r in [0.2, 0.4, 0.6, 0.8]:
		var p := _p(CAT.PAS, SV.NIVEAU_NET_DB, PORTEE * r)
		_check(float(p["largeur"]) > float(avant["largeur"]),
			"plus loin, plus large (r = %.1f)" % r)
		_check(float(p["alpha"]) < float(avant["alpha"]), "plus loin, plus léger (r = %.1f)" % r)
		avant = p
	# Au bout de sa portée, le pas de course n'a plus de direction.
	var au_bout := _p(CAT.PAS, SV.NIVEAU_NET_DB, PORTEE * 0.999)
	_check(float(au_bout["largeur"]) > 179.0, "le pas de course au bout de sa portée : 180°")
	# Au-delà de la portée, le moteur audio le rend muet — le liseré aussi.
	_check(_p(CAT.TIR, 0.0, PORTEE).is_empty(), "au-delà de la portée, rien")
	_check(_p(CAT.TIR, 0.0, PORTEE * 1.5).is_empty(), "loin au-delà de la portée, rien")
	# Le pas accroupi s'efface exactement au bout de sa portée (moitié moindre).
	var bas := _p(CAT.PAS, SV.NIVEAU_FLOU_DB, PORTEE * 0.5 * 0.999, PORTEE * 0.5)
	_check(bas.is_empty() or float(bas["alpha"]) < 0.001,
		"le pas accroupi s'éteint au bout de sa portée")

	var net := _p(CAT.PAS, SV.NIVEAU_NET_DB, 200.0)
	var p_prec := net
	for part in [1.0 / 3.0, 2.0 / 3.0, 1.0]:
		var p := _p(CAT.PAS, SV.NIVEAU_NET_DB, 200.0, PORTEE, part)
		_check(float(p["largeur"]) > float(p_prec["largeur"]), "un mur élargit (part %.2f)" % part)
		_check(float(p["alpha"]) < float(p_prec["alpha"]), "un mur affaiblit (part %.2f)" % part)
		_check(float(p["douceur"]) > float(p_prec["douceur"]), "un mur adoucit le bord (part %.2f)" % part)
		p_prec = p
	var fume := _p(CAT.PAS, SV.NIVEAU_NET_DB, 200.0, PORTEE, 0.0, -3.0)
	_check(float(fume["largeur"]) > float(net["largeur"]), "la fumée élargit")
	# Une fumée « positive » n'existe pas : elle ne peut pas préciser un son.
	var faux := _p(CAT.PAS, SV.NIVEAU_NET_DB, 200.0, PORTEE, 0.0, 3.0)
	_proche(float(faux["largeur"]), float(net["largeur"]), "une fumée positive est ignorée")

	# La salle : « la reverb des sons d'impact peut rendre plus flous les liserés ».
	var diag := 900.0
	var sec := _p(CAT.IMPACT, -3.0, 700.0, 1400.0, 0.0, 0.0, 0.0, diag)
	var reverbere := _p(CAT.IMPACT, -3.0, 700.0, 1400.0, 0.0, 0.0, 0.42, diag)
	_check(float(reverbere["largeur"]) > float(sec["largeur"]) * 1.3,
		"la salle élargit un impact lointain (%.1f° → %.1f°)" % [float(sec["largeur"]), float(reverbere["largeur"])])
	_check(float(reverbere["duree"]) > float(sec["duree"]), "la salle allonge la traîne d'un impact")
	var pres_reverbere := _p(CAT.IMPACT, -3.0, 30.0, 1400.0, 0.0, 0.0, 0.42, diag)
	_check(float(pres_reverbere["largeur"]) < float(reverbere["largeur"]),
		"tout près, la salle brouille moins que loin (le direct domine)")
	var pas_sec := _p(CAT.PAS, -13.0, 300.0, 1000.0, 0.0, 0.0, 0.0, diag)
	var pas_rev := _p(CAT.PAS, -13.0, 300.0, 1000.0, 0.0, 0.0, 0.42, diag)
	var imp_sec := _p(CAT.IMPACT, -13.0, 300.0, 1000.0, 0.0, 0.0, 0.0, diag)
	var imp_rev := _p(CAT.IMPACT, -13.0, 300.0, 1000.0, 0.0, 0.0, 0.42, diag)
	_check(float(imp_rev["largeur"]) / float(imp_sec["largeur"])
			> float(pas_rev["largeur"]) / float(pas_sec["largeur"]),
		"la salle brouille un impact plus qu'un pas, à niveau égal")
	# Jamais au-delà du demi-écran.
	var tout := _p(CAT.TIR, SV.NIVEAU_SEUIL_DB + 1.0, 900.0, 1000.0, 1.0, -3.0, 0.42, diag)
	_check(tout.is_empty() or float(tout["largeur"]) <= SV.LARGEUR_MAX_DEG + 0.001, "la largeur plafonne à 180°")


# --- L'allure (Q47) ----------------------------------------------------------------

func _test_allure() -> void:
	_proche(SV.ecart_allure_db(1.0), 0.0, "pleine allure : aucun écart")
	_proche(SV.ecart_allure_db(0.0), SV.PAS_LENT_DB, "à l'arrêt : l'écart du pas lent")
	_proche(SV.ecart_allure_db(2.0), 0.0, "une allure au-delà de 1 est bornée")
	_proche(SV.ecart_allure_db(-1.0), SV.PAS_LENT_DB, "une allure négative est bornée")
	var prec := _p(CAT.PAS, SV.NIVEAU_NET_DB + SV.ecart_allure_db(1.0), 100.0)
	for a in [0.75, 0.5, 0.25, 0.0]:
		var p := _p(CAT.PAS, SV.NIVEAU_NET_DB + SV.ecart_allure_db(a), 100.0)
		_check(float(p["largeur"]) > float(prec["largeur"]), "plus lent, plus large (allure %.2f)" % a)
		_check(float(p["alpha"]) < float(prec["alpha"]), "plus lent, plus léger (allure %.2f)" % a)
		prec = p
	# S'accroupir reste LE moyen d'être au minimum : le pas debout le plus lent,
	# au contact, reste plus net et plus présent que le pas accroupi au contact.
	var lent := _p(CAT.PAS, SV.NIVEAU_NET_DB + SV.PAS_LENT_DB, 0.0)
	var accroupi := _p(CAT.PAS, SV.NIVEAU_FLOU_DB, 0.0, PORTEE * 0.5)
	_check(float(lent["largeur"]) < float(accroupi["largeur"]), "le pas lent debout reste plus net qu'accroupi")
	_check(float(lent["alpha"]) > float(accroupi["alpha"]), "le pas lent debout reste plus présent qu'accroupi")
	_check(SV.NIVEAU_NET_DB + SV.PAS_LENT_DB > SV.NIVEAU_FLOU_DB,
		"le pas lent debout reste au-dessus du niveau accroupi")


# --- Les sortes et le code couleur (Q48) ---------------------------------------------

func _test_sortes() -> void:
	_check(SV.categorie_de("footstep_a") == CAT.PAS, "footstep_a → pas")
	_check(SV.categorie_de("shoot") == CAT.TIR, "shoot → tir")
	_check(SV.categorie_de("ricochet") == CAT.RICOCHET, "ricochet → ricochet")
	_check(SV.categorie_de("wall_impact") == CAT.IMPACT, "wall_impact → impact")
	_check(SV.categorie_de("hit_center") == CAT.CORPS, "hit_center → corps")
	_check(SV.categorie_de("fusee_atterrit") == CAT.FUSEE, "fusee_atterrit → fusée")
	_check(SV.categorie_de("gadget_mine_pose") == CAT.GADGET, "un son de gadget futur trouve sa sorte")
	_check(SV.categorie_de("inconnu_total") == CAT.AUTRE, "un son inconnu → autre")
	_check(SV.categorie_de("ambience") == -1, "la salle ne dessine rien")
	_check(SV.categorie_de("") == -1, "un flux sans nom ne dessine rien")
	_check(SV.percevoir(-1, 0.0, 0.0, PORTEE).is_empty(), "une sorte muette ne perçoit rien")
	for cat in CAT.values():
		_check(SV.RESONANCE.has(cat), "résonance de la sorte %s" % CAT.keys()[cat])
		_check(SV.DUREE.has(cat), "durée de la sorte %s" % CAT.keys()[cat])


static func _saturation(c: Color) -> float:
	var maxi := maxf(c.r, maxf(c.g, c.b))
	var mini := minf(c.r, minf(c.g, c.b))
	return 0.0 if maxi <= 0.0 else (maxi - mini) / maxi


static func _ecart(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _test_couleurs() -> void:
	var toutes: Array[Color] = []
	for cat in CAT.values():
		var c := SV.couleur(cat)
		var nom: String = CAT.keys()[cat]
		_check(is_equal_approx(c.a, 1.0), "%s : couleur opaque (l'opacité est celle du liseré)" % nom)
		_check(_saturation(c) <= 0.7501, "%s : saturation %.3f sous le plafond" % [nom, _saturation(c)])
		# Règle 3 : pas de vert dans l'arène — même critère que test_charte.
		var vert := _saturation(c) >= 0.18 and c.g > c.r and c.g > c.b
		_check(not vert, "%s : pas de vert (%s)" % [nom, c])
		_check(_ecart(c, C.BLEU) > 0.25, "%s : loin du bleu de « soi »" % nom)
		_check(_ecart(c, C.ROUGE) > 0.1, "%s : distinct du rouge du voile de dégâts" % nom)
		toutes.append(c)
	var mini := INF
	var paire := ""
	for i in toutes.size():
		for j in range(i + 1, toutes.size()):
			var e := _ecart(toutes[i], toutes[j])
			if e < mini:
				mini = e
				paire = "%s / %s" % [CAT.keys()[i], CAT.keys()[j]]
	_check(mini >= 0.1, "toutes les sortes se distinguent (écart minimal %.3f, %s)" % [mini, paire])
	_check(SV.couleur(CAT.TIR) == C.HALOGENE, "le tir a la couleur du flash de bouche")


# --- La vie d'un liseré et son profil -------------------------------------------------

func _test_enveloppe() -> void:
	_proche(SV.enveloppe(0.0, 0.5), 0.0, "enveloppe à la naissance")
	_proche(SV.enveloppe(SV.ATTAQUE_S, 0.5), 1.0, "enveloppe au sommet de l'attaque")
	_check(SV.enveloppe(0.3, 0.5) < SV.enveloppe(0.15, 0.5), "l'enveloppe décroît")
	_proche(SV.enveloppe(0.5, 0.5), 0.0, "enveloppe éteinte au terme")
	_proche(SV.enveloppe(0.7, 0.5), 0.0, "enveloppe éteinte après le terme")
	_proche(SV.profil(0.0, 0.0), 1.0, "profil plein au centre")
	_proche(SV.profil(1.0, 0.0), 0.0, "profil nul au bord")
	_proche(SV.profil(0.5, 0.0), 1.0, "un liseré net a un cœur plein (plateau)")
	_check(SV.profil(0.3, 1.0) < SV.profil(0.3, 0.0), "un liseré flou n'a plus de plateau : il fond dès son cœur")
	_check(SV.profil(0.95, 0.0) < 0.1, "un liseré net fond vite à son bord")
	# La présence, par paliers sur les ancres.
	_proche(SV.presence_de(SV.NIVEAU_SEUIL_DB), 0.0, "présence nulle au seuil")
	_proche(SV.presence_de(SV.NIVEAU_FLOU_DB), SV.PRESENCE_FLOU, "présence du pas accroupi")
	_proche(SV.presence_de(SV.NIVEAU_NET_DB), SV.PRESENCE_NET, "présence du pas de course")
	_proche(SV.presence_de(SV.NIVEAU_FORT_DB), 1.0, "présence du tir")
	_proche(SV.presence_de(SV.NIVEAU_FORT_DB + 6.0), 1.0, "au-delà du tir, la présence plafonne")
	var prec := -1.0
	var croissante := true
	for i in 41:
		var db := lerpf(SV.NIVEAU_SEUIL_DB - 3.0, SV.NIVEAU_FORT_DB + 3.0, float(i) / 40.0)
		var pr := SV.presence_de(db)
		croissante = croissante and pr >= prec - 0.000001
		prec = pr
	_check(croissante, "la présence ne décroît jamais quand le son monte")


# --- La géométrie du bord ---------------------------------------------------------------

func _test_geometrie() -> void:
	var cadre := Rect2(0, 0, 1920, 1080)
	var centre := Vector2(960, 540)
	var droite := SV.point_du_bord(centre, 0.0, cadre)
	_check(droite.distance_to(Vector2(1920, 540)) < 0.5, "vers la droite : le bord droit (%s)" % droite)
	var haut := SV.point_du_bord(centre, -PI / 2.0, cadre)
	_check(haut.distance_to(Vector2(960, 0)) < 0.5, "vers le haut : le bord haut (%s)" % haut)
	var diag := SV.point_du_bord(centre, PI / 4.0, cadre)
	_check(diag.distance_to(Vector2(1500, 1080)) < 0.5, "à 45° vers le bas : le bord bas (%s)" % diag)
	# Un auditeur hors champ est ramené dans le cadre : le liseré reste à l'écran.
	var dehors := SV.point_du_bord(Vector2(-300, 540), PI, cadre)
	_check(cadre.grow(0.5).has_point(dehors), "origine hors champ : le point reste au bord")

	# Une bande de 90° à cheval sur le coin haut-droit, depuis un joueur décentré.
	var o := Vector2(900, 600)
	var b := SV.bande(o, -PI / 4.0, 90.0, cadre, 12.0, 0.0)
	var bords: PackedVector2Array = b["bords"]
	var dedans: PackedVector2Array = b["dedans"]
	var milieu: PackedVector2Array = b["milieu"]
	var poids: PackedFloat32Array = b["poids"]
	_check(bords.size() == dedans.size() and bords.size() == poids.size() and bords.size() == milieu.size(),
		"bande cohérente")
	var entre := true
	for i in bords.size():
		var d_milieu := bords[i].distance_to(milieu[i])
		var d_dedans := bords[i].distance_to(dedans[i])
		entre = entre and d_milieu <= d_dedans + 0.001 and absf(d_milieu - 12.0 * SV.EPAISSEUR_PLEINE) < 0.01
	_check(entre, "l'anneau plein s'arrête à %.0f %% de l'épaisseur, avant le fondu" % (SV.EPAISSEUR_PLEINE * 100.0))
	_check(bords.size() >= 31, "bande assez fine (%d points pour 90°)" % bords.size())
	var sur_le_bord := true
	var continu := true
	var passe_le_coin := false
	for i in bords.size():
		var p := bords[i]
		var au_bord := absf(p.x) < 0.5 or absf(p.x - 1920.0) < 0.5 or absf(p.y) < 0.5 or absf(p.y - 1080.0) < 0.5
		sur_le_bord = sur_le_bord and au_bord
		_check(cadre.grow(0.5).has_point(dedans[i]), "point intérieur %d dans le cadre" % i)
		_check(dedans[i].distance_to(p) <= 12.01, "épaisseur tenue au point %d" % i)
		passe_le_coin = passe_le_coin or p.distance_to(Vector2(1920, 0)) < 0.5
		if i > 0:
			# Deux points voisins sont sur un MÊME côté : aucun segment ne coupe un coin.
			var q := bords[i - 1]
			var meme_x := absf(p.x - q.x) < 0.5 and (absf(p.x) < 0.5 or absf(p.x - 1920.0) < 0.5)
			var meme_y := absf(p.y - q.y) < 0.5 and (absf(p.y) < 0.5 or absf(p.y - 1080.0) < 0.5)
			continu = continu and (meme_x or meme_y)
	_check(sur_le_bord, "tous les points de bord sont sur le bord")
	_check(continu, "aucun segment de la bande ne coupe un coin")
	_check(passe_le_coin, "le coin haut-droit est un point de la bande")
	_proche(poids[0], 0.0, "profil nul au premier bord de la bande")
	_proche(poids[poids.size() - 1], 0.0, "profil nul au second bord de la bande")
	var max_poids := 0.0
	for w in poids:
		max_poids = maxf(max_poids, w)
	_check(max_poids > 0.99, "profil plein au centre de la bande")

	_proche(SV.angle_a_l_ecran(Vector2(0, 0), Vector2(10, 0)), 0.0, "angle vers la droite")
	_proche(SV.angle_a_l_ecran(Vector2(0, 0), Vector2(0, 10)), PI / 2.0, "angle vers le bas (sens horaire)")
	_check(is_nan(SV.angle_a_l_ecran(Vector2(5, 5), Vector2(5, 5))), "un son sur soi n'a pas d'angle")


# --- La forme d'onde : le liseré suit le son, puis la salle ----------------------------

const PAS := SV.Enveloppes.PAS_S
const SFX := "res://assets/audio/sfx/"
const ARMES := "res://assets/audio/weapons/"


static func _plat(n: int, db := 0.0) -> Array:
	var a: Array = []
	for i in n:
		a.append(db)
	return a


## Une enveloppe qui perd `par_pas` dB à chaque pas de 10 ms.
static func _pente(n: int, par_pas: float) -> Array:
	var a: Array = []
	for i in n:
		a.append(-par_pas * float(i))
	return a


## `n_on` valeurs pleines, puis le silence : un son qui s'arrête net.
static func _coupe(n_on: int, n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append(0.0 if i < n_on else -90.0)
	return a


## Une trace animée par une enveloppe SYNTHÉTIQUE (dB sous le pic, un pas de 10 ms), au
## contact, dans la salle décrite : exactement ce que `son_visible_vue.gd` range dans une trace.
func _trace(cat: int, niveau: float, db: Array, wet := 0.0, room := 0.15, damp := 0.22,
		pitch := 1.0, part := 0.0) -> Dictionary:
	var p := _p(cat, niveau, 0.0, PORTEE, part, 0.0, wet, 900.0)
	if p.is_empty():
		return {"p": p}
	var vu := SV.lisser_vu(db, PAS)
	var vie := SV.vie_de(cat, p, vu, pitch, part, wet, SV.rt60_de(room, damp))
	return {"largeur": p["largeur"], "alpha": p["alpha"], "epaisseur": p["epaisseur"],
		"douceur": p["douceur"], "duree": vie["duree"], "vie": vie, "p": p}


## La trace d'un VRAI fichier de la table, telle que la vue la construit depuis l'événement.
func _trace_reelle(chemin: String, cat: int, niveau: float, wet := 0.0, room := 0.15,
		pitch := 1.0, part := 0.0, distance := 0.0) -> Dictionary:
	var p := _p(cat, niveau, distance, PORTEE, part, 0.0, wet, 900.0)
	if p.is_empty():
		return {"p": p}
	var vie := SV.animer(cat, p, {"chemin": chemin, "pitch": pitch, "wet": wet, "room_size": room,
		"damping": 0.22}, part)
	if vie.is_empty():
		return {"p": p}
	return {"largeur": p["largeur"], "alpha": p["alpha"], "epaisseur": p["epaisseur"],
		"douceur": p["douceur"], "duree": vie["duree"], "vie": vie, "p": p}


func _test_vu() -> void:
	_proche(SV.RELACHEMENT_VU_S, 0.05, "le relâchement est de 50 ms")
	var pente := SV.DB_PAR_TAU * PAS / SV.RELACHEMENT_VU_S
	var vu := SV.lisser_vu([0.0, -40.0, -40.0, -40.0, -40.0], PAS)
	_proche(vu[0], 0.0, "VU : un pic est montré d'un coup")
	_proche(vu[1], -pente, "VU : il retombe de %.2f dB par pas de 10 ms" % pente, 0.001)
	_proche(vu[2], -2.0 * pente, "VU : et continue à la même pente", 0.001)
	var montee := SV.lisser_vu([-50.0, -50.0, 0.0, -50.0], PAS)
	_proche(montee[2], 0.0, "VU : l'attaque est immédiate")
	var db := [-3.0, -20.0, -1.0, -30.0, -30.0, -2.0, -40.0, -40.0]
	var lisse := SV.lisser_vu(db, PAS)
	var jamais_sous := true
	for i in db.size():
		jamais_sous = jamais_sous and lisse[i] >= db[i] - 0.0001
	_check(jamais_sous, "VU : jamais sous le signal, donc jamais un pic coupé")
	# Pas de clignotement : entre deux clics à 40 ms, le niveau ne tombe pas au plancher.
	var clics := _plat(20, -45.0)
	clics[5] = 0.0
	clics[9] = 0.0
	var l2 := SV.lisser_vu(clics, PAS)
	_check(l2[5] == 0.0 and l2[9] == 0.0, "VU : chaque clic est montré à sa hauteur")
	_check(l2[7] > -8.0, "VU : entre deux clics à 40 ms, la bande ne retombe pas (%.1f dB)" % l2[7])
	_check(l2[15] < l2[9] - 8.0, "VU : mais elle retombe, à sa pente, une fois les clics passés (%.1f dB)" % l2[15])


func _test_salle() -> void:
	_check(SV.rt60_de(0.06, 0.22) < SV.rt60_de(0.15, 0.22) and SV.rt60_de(0.15, 0.22) < SV.rt60_de(0.35, 0.22),
		"le hangar réverbère plus longtemps que le sas")
	_check(SV.rt60_de(0.2, 0.35) < SV.rt60_de(0.2, 0.18), "des murs qui absorbent raccourcissent la réverbération")
	_proche(SV.rt60_de(SV.ROOM_SIZE_MIN, SV.DAMPING_REF), SV.RT60_MIN_S, "le plus petit sas : le RT60 minimal")
	_proche(SV.rt60_de(SV.ROOM_SIZE_MAX, SV.DAMPING_REF), SV.RT60_MAX_S, "le plus grand hangar : le RT60 maximal")
	var borne := true
	for room in [0.06, 0.15, 0.231, 0.35]:
		for damp in [0.18, 0.22, 0.35]:
			var t := SV.rt60_de(room, damp)
			borne = borne and t > 0.3 and t < 2.0
	_check(borne, "toutes les salles du jeu ont un RT60 entre 0,3 et 2 s")
	for cat in CAT.values():
		var tr := SV.traine_db(0.35, cat)
		_check(tr <= SV.TRAINE_PLAFOND_DB and tr >= SV.TRAINE_PLANCHER_DB,
			"traîne de %s dans ses bornes (%.1f dB)" % [CAT.keys()[cat], tr])
	_check(SV.traine_db(0.42, CAT.TIR) > SV.traine_db(0.24, CAT.TIR), "plus de wet, traîne plus haute")
	_check(SV.traine_db(0.35, CAT.TIR) > SV.traine_db(0.35, CAT.PAS), "un tir fait sonner la salle plus qu'un pas")
	_proche(SV.traine_db(0.42, CAT.TIR), linear_to_db(0.42), "la traîne d'un tir part de 20·log10(wet)", 0.001)
	_proche(SV.traine_db(0.42, CAT.PAS), linear_to_db(0.42 * 0.2), "… celle d'un pas, de 20·log10(wet × 0,2)", 0.001)
	_check(SV.traine_db(0.0, CAT.TIR) == SV.TRAINE_PLANCHER_DB, "sans réverbération, pas de traîne")


func _test_vie_pic() -> void:
	# Au pic, c'est EXACTEMENT ce que `percevoir` a rendu : les ancres et les paliers ne bougent pas.
	var exact := true
	var vus := 0
	for cat in [CAT.TIR, CAT.PAS, CAT.IMPACT, CAT.RECHARGE]:
		for niveau in [0.0, -8.0, -13.0, -22.0]:
			var t := _trace(cat, niveau, _pente(50, 0.5), 0.35, 0.23)
			if t["p"].is_empty():
				continue
			vus += 1
			var e := SV.etat(t, 0.0)
			exact = exact and not e.is_empty() \
				and absf(float(e["alpha"]) - float(t["p"]["alpha"])) < 0.0001 \
				and absf(float(e["epaisseur"]) - float(t["p"]["epaisseur"])) < 0.001 \
				and absf(float(e["largeur"]) - float(t["p"]["largeur"])) < 0.001 \
				and absf(float(e["douceur"]) - float(t["p"]["douceur"])) < 0.0001
	_check(vus >= 12, "assez de cas pour croire à l'égalité (%d)" % vus)
	_check(exact, "au pic, opacité, épaisseur, largeur et bord sont ceux de percevoir")
	# Le pic d'un fichier qui commence par du silence (les pas ont ~100 ms de vide avant le
	# coup) n'est pas sauté : à l'instant du coup, la présence est celle du modèle.
	var env := _plat(30, -50.0)
	env[11] = 0.0
	var t2 := _trace(CAT.PAS, SV.NIVEAU_NET_DB, env, 0.35, 0.23)
	var e2 := SV.etat(t2, 11.0 * PAS)
	_proche(float(e2["alpha"]), float(t2["p"]["alpha"]), "le coup d'un pas retardé de 110 ms a la présence du modèle", 0.0001)
	_check(float(SV.etat(t2, 0.0)["alpha"]) < 0.01, "… et avant lui le liseré attend, comme l'oreille")


func _test_suit_l_enveloppe() -> void:
	# « Un tir claque puis décroît » : pas à pas, le niveau perçu est celui du pic moins la
	# retombée du fichier. Salle sèche : rien d'autre ne parle.
	var t := _trace(CAT.TIR, 0.0, _pente(100, 1.0))
	var niv: PackedFloat32Array = t["vie"]["niveaux"]
	_proche(niv[0], 0.0, "attaque immédiate : dès le premier pas, le niveau du pic")
	var suit := true
	for k in 25:
		suit = suit and absf(niv[k] + float(k)) < 0.01
	_check(suit, "le niveau perçu suit l'enveloppe du fichier, pas à pas")
	var prec := 2.0
	var decroit := true
	for k in 30:
		var a := float(SV.etat(t, float(k) * PAS)["alpha"])
		decroit = decroit and a <= prec + 0.00001
		prec = a
	_check(decroit, "le liseré décroît avec le son (jamais de rebond sans raison)")
	# Un rechargement montre ses CLICS : deux pics dans un froissement, à 100 ms.
	var clics := _plat(60, -45.0)
	clics[20] = -15.0
	clics[30] = 0.0
	clics[59] = 0.0
	var tc := _trace(CAT.RECHARGE, -8.0, clics, 0.0)
	var a_clic := float(SV.etat(tc, 30.0 * PAS)["alpha"])
	var a_entre := float(SV.etat(tc, 45.0 * PAS)["alpha"])
	var a_frou := float(SV.etat(tc, 5.0 * PAS)["alpha"])
	_check(a_clic > 0.5, "le clic se voit (alpha %.2f)" % a_clic)
	_check(a_frou == 0.0, "le froissement, 45 dB plus bas, ne se voit pas (alpha %.3f)" % a_frou)
	_check(a_entre < a_clic * 0.5, "entre deux clics la bande retombe (%.2f contre %.2f)" % [a_entre, a_clic])


func _test_vie_en_db() -> void:
	# LE critère : la vie tient au niveau PERÇU, pas à une fraction de la durée. Même fichier
	# (perd 1 dB toutes les 10 ms), quatre niveaux au pic.
	var env := _pente(100, 1.0)
	var fort := _trace(CAT.TIR, 0.0, env)
	var pas_course := _trace(CAT.PAS, SV.NIVEAU_NET_DB, env)
	var faible := _trace(CAT.PAS, SV.NIVEAU_FLOU_DB, env)
	_proche(float(pas_course["duree"]), 0.18, "un pas de course (−13 dB) a 18 dB à perdre avant le seuil : %.2f s" % float(pas_course["duree"]), 0.011)
	_proche(float(faible["duree"]), 0.09, "un pas accroupi (−22 dB) n'en a que 9 : %.2f s" % float(faible["duree"]), 0.011)
	_proche(float(fort["duree"]), 0.31, "un tir (0 dB) en a 31 : %.2f s" % float(fort["duree"]), 0.011)
	_check(float(fort["duree"]) > float(pas_course["duree"]) and float(pas_course["duree"]) > float(faible["duree"]),
		"plus faible, plus bref — à fichier identique")
	# Derrière un mur : -5 dB, donc 5 dB de moins à perdre.
	var mur := _trace(CAT.PAS, SV.NIVEAU_NET_DB, env, 0.0, 0.15, 0.22, 1.0, 1.0)
	_check(float(mur["duree"]) < float(pas_course["duree"]) - 0.03, "derrière un mur, le même pas dure moins (%.2f s contre %.2f s)"
		% [float(mur["duree"]), float(pas_course["duree"])])
	# Et un fichier de durée fixe ne donne PAS une durée fixe.
	var d := {}
	for niveau in [0.0, -6.0, -13.0, -22.0, -28.0]:
		var t := _trace(CAT.TIR, niveau, env)
		d[snappedf(float(t["duree"]), 0.001)] = true
	_check(d.size() == 5, "cinq niveaux, cinq durées : la durée n'est pas une fraction de celle du fichier (%d)" % d.size())


func _test_court_et_long() -> void:
	# Adrien : « un long son très réverbéré doit durer autant que le son, et un son très
	# court et étouffé doit durer très peu. »
	var court := _trace(CAT.PAS, SV.NIVEAU_FLOU_DB, _plat(8), 0.24, 0.06, 0.22, 1.0, 1.0)
	var long := _trace(CAT.TIR, 0.0, _plat(120), 0.42, 0.35)
	_check(float(court["duree"]) < 0.15, "un son de 80 ms, étouffé (accroupi, derrière un mur, petit sas) : %.2f s" % float(court["duree"]))
	_check(float(long["duree"]) >= 1.2 - 0.011,
		"un son de 1,2 s en grande salle dure AU MOINS autant que lui : %.2f s" % float(long["duree"]))
	_check(float(long["duree"]) < SV.DUREE_MAX_S, "… mais reste sous le plafond (%.2f s)" % float(long["duree"]))
	_check(float(long["duree"]) > 8.0 * float(court["duree"]), "l'écart entre les deux est d'un ordre de grandeur")


func _test_traine() -> void:
	# Un son qui s'arrête net : ce qui suit est la salle, et rien d'autre. 30 pas pleins = 0,3 s.
	var sas := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.24, 0.06)
	var salle := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.35, 0.231)
	var hangar := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.42, 0.35)
	_check(float(sas["duree"]) > 0.30 + 0.05, "une traîne prolonge le son, même dans un sas (%.2f s)" % float(sas["duree"]))
	_check(float(salle["duree"]) > float(sas["duree"]) + 0.05, "plus la salle est grande, plus la traîne est longue : sas %.2f s, salle %.2f s"
		% [float(sas["duree"]), float(salle["duree"])])
	_check(float(hangar["duree"]) > float(salle["duree"]) + 0.05, "… hangar %.2f s" % float(hangar["duree"]))
	_check(float(hangar["duree"]) > 0.3 + 0.4, "un tir en grande salle dure le temps du son plus sa traîne (%.2f s)" % float(hangar["duree"]))

	# La traîne décline à la vitesse du RT60 de la salle : 60 dB en `rt60` secondes.
	# [wet, room_size, premier pas mesuré, dernier] — assez après la fin du VU-mètre du direct.
	for cas in [[0.42, 0.35, 45, 65], [0.35, 0.231, 45, 60]]:
		var t := _trace(CAT.TIR, 0.0, _coupe(30, 30), cas[0], cas[1])
		var niv: PackedFloat32Array = t["vie"]["niveaux"]
		var rt60 := SV.rt60_de(cas[1], 0.22)
		var pente := (niv[cas[2]] - niv[cas[3]]) / (float(cas[3] - cas[2]) * PAS)
		_proche(pente, 60.0 / rt60, "la traîne décline de 60 dB en %.2f s (salle %.2f) : %.1f dB/s" % [rt60, cas[1], pente], 0.5)
	# Elle part d'un niveau fixé par le wet et la RÉSONANCE de la sorte : le pic, plus
	# 20·log10(wet × résonance), puis le déclin. Dans le hangar, 16 pas après la fin du son.
	var tir := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.42, 0.35)
	var corps := _trace(CAT.CORPS, 0.0, _coupe(30, 30), 0.42, 0.35)
	var rt60_h := SV.rt60_de(0.35, 0.22)
	var descente := 60.0 / rt60_h * PAS
	var attendu := SV.traine_db(0.42, CAT.TIR) - descente * 16.0
	_proche(float(tir["vie"]["niveaux"][45]), attendu, "la traîne d'un tir part du pic + 20·log10(wet) (%.1f dB attendu)" % attendu, 0.05)
	_proche(float(tir["vie"]["niveaux"][45]) - float(corps["vie"]["niveaux"][45]), 20.0 * log(1.0 / 0.5) / log(10.0),
		"… et la résonance de la sorte la règle : un tir sonne 6 dB au-dessus d'un corps touché", 0.05)
	# Un pas ne fait presque pas sonner la salle : sa traîne est sous le seuil, il n'est jamais prolongé.
	var pas_salle := _trace(CAT.PAS, SV.NIVEAU_NET_DB, _coupe(11, 11), 0.42, 0.35)
	var pas_sec := _trace(CAT.PAS, SV.NIVEAU_NET_DB, _coupe(11, 11), 0.0, 0.35)
	_check(absf(float(pas_salle["duree"]) - float(pas_sec["duree"])) < 0.011,
		"la salle ne prolonge pas un pas (%.2f s dans le hangar, %.2f s sans salle)" % [float(pas_salle["duree"]), float(pas_sec["duree"])])


func _test_elargissement() -> void:
	var t := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.42, 0.35)
	var largeur_pic := float(t["largeur"])
	_proche(largeur_pic, 10.0, "un tir au contact : 10°, comme avant")
	_proche(float(SV.etat(t, 0.15)["largeur"]), largeur_pic, "pendant le son, la largeur ne bouge pas", 0.2)
	# Pendant la traîne, elle s'ouvre — vers la largeur diffuse, sans jamais la dépasser ni se refermer.
	var prec := 0.0
	var monte := true
	var atteint := 0.0
	var age := 0.30
	while age < float(t["duree"]) - 0.005:
		var e := SV.etat(t, age)
		monte = monte and float(e["largeur"]) >= prec - 0.0001 and float(e["largeur"]) <= SV.LARGEUR_MAX_DEG + 0.0001
		prec = float(e["largeur"])
		atteint = maxf(atteint, prec)
		age += 0.01
	_check(monte, "pendant la traîne la largeur croît sans jamais se refermer")
	_check(atteint > largeur_pic * 4.0, "… et finit bien plus large que le pic (%.0f° pour %.0f°)" % [atteint, largeur_pic])
	var e_fin := SV.etat(t, float(t["duree"]) - 0.02)
	_check(float(e_fin["diffus"]) > 0.9 and float(e_fin["douceur"]) > 0.9,
		"en fin de traîne, plus de direction (diffus %.2f) et un bord tout en fondu" % float(e_fin["diffus"]))
	# Une salle plus réverbérante brouille plus vite : à 100 ms de la fin du son, le hangar est
	# plus diffus que le sas.
	var sas := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.24, 0.06)
	_check(float(SV.etat(t, 0.40)["diffus"]) > float(SV.etat(sas, 0.40)["diffus"]),
		"dans le hangar la traîne brouille plus vite que dans le sas (%.2f contre %.2f)"
		% [float(SV.etat(t, 0.40)["diffus"]), float(SV.etat(sas, 0.40)["diffus"])])
	# Une traîne qu'on ne voit pas n'élargit rien : un pas dans le hangar garde sa largeur.
	var pas := _trace(CAT.PAS, SV.NIVEAU_NET_DB, _coupe(11, 11), 0.42, 0.35)
	var tous := true
	var a := 0.0
	while a < float(pas["duree"]) - 0.005:
		tous = tous and absf(float(SV.etat(pas, a)["largeur"]) - float(pas["largeur"])) < 0.001
		a += 0.01
	_check(tous, "un pas ne s'élargit pas dans la salle : sa traîne est sous le seuil")


func _test_occlusion_traine() -> void:
	# Derrière un mur, la part DIRECTE baisse plus que la traîne.
	var libre := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.42, 0.35)
	var mur := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.42, 0.35, 0.22, 1.0, 1.0)
	var nl: PackedFloat32Array = libre["vie"]["niveaux"]
	var nm: PackedFloat32Array = mur["vie"]["niveaux"]
	var chute_directe := nl[0] - nm[0]
	# Assez après la fin du VU-mètre du direct pour que la salle seule parle.
	var chute_traine := nl[60] - nm[60]
	_proche(chute_directe, -SV.PERTE_OCCLUSION_DB, "un mur retire au direct sa pénalité entière (%.1f dB)" % chute_directe, 0.01)
	_check(chute_traine > 0.0 and chute_traine < chute_directe - 1.0,
		"… et à la traîne moins (%.1f dB contre %.1f)" % [chute_traine, chute_directe])
	_proche(chute_traine, -SV.PERTE_OCCLUSION_DB * SV.TRAINE_OCCLUSION, "… la part TRAINE_OCCLUSION de la pénalité", 0.05)
	# Donc, derrière un mur, la traîne pèse relativement PLUS dans ce qu'on voit.
	_check(nm[60] - nm[0] > nl[60] - nl[0], "derrière un mur, la traîne est relativement plus forte que le direct")


func _test_pitch() -> void:
	# Un son joué plus vite dure moins longtemps : la durée se divise par le pitch.
	var lent := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.0, 0.15, 0.22, 0.5)
	var normal := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.0, 0.15, 0.22, 1.0)
	var vite := _trace(CAT.TIR, 0.0, _coupe(30, 30), 0.0, 0.15, 0.22, 2.0)
	_check(float(lent["duree"]) > 1.8 * float(normal["duree"]) and float(vite["duree"]) < 0.6 * float(normal["duree"]),
		"la durée se divise par le pitch : %.2f s à 0,5, %.2f s à 1, %.2f s à 2"
		% [float(lent["duree"]), float(normal["duree"]), float(vite["duree"])])
	# Et le pic n'est jamais sauté entre deux pas, quel que soit le pitch.
	var env := _plat(20, -50.0)
	env[7] = 0.0
	var ok := true
	for pitch in [0.8, 0.96, 1.0, 1.04, 1.08, 1.3]:
		var t := _trace(CAT.PAS, SV.NIVEAU_NET_DB, env, 0.0, 0.15, 0.22, pitch)
		var niv: PackedFloat32Array = t["vie"]["niveaux"]
		ok = ok and absf(niv[7] - SV.NIVEAU_NET_DB) < 0.01
	_check(ok, "le pic est atteint au pas du coup, à tout pitch (l'échantillonnage suit la grille de la table)")


func _test_continu() -> void:
	# La combustion de la fusée : une enveloppe plate de la durée de la période.
	var p := _p(CAT.FUSEE, -11.0, 200.0)
	var vie := SV.animer(CAT.FUSEE, p, {"continu": true, "periode": 0.6, "chemin": SFX + "fusee_combustion.wav"}, 0.0)
	_check(not vie.is_empty() and bool(vie["continu"]), "une source continue a sa vie plate")
	_check(float(vie["duree"]) >= 0.6 and float(vie["duree"]) <= 0.6 * 1.3, "elle dure la période, à peine plus (%.2f s)" % float(vie["duree"]))
	var t := {"largeur": p["largeur"], "alpha": p["alpha"], "epaisseur": p["epaisseur"], "douceur": p["douceur"],
		"duree": vie["duree"], "vie": vie}
	var a0 := SV.etat(t, 0.0)
	var plat := true
	for age in [0.05, 0.3, 0.55, 0.6, float(vie["duree"]) - 0.01]:
		var e := SV.etat(t, age)
		plat = plat and not e.is_empty() and absf(float(e["alpha"]) - float(a0["alpha"])) < 0.0001 \
			and absf(float(e["largeur"]) - float(a0["largeur"])) < 0.0001 \
			and absf(float(e["epaisseur"]) - float(a0["epaisseur"])) < 0.0001
	_check(plat, "plate : ni attaque, ni fondu, ni élargissement — pas de clignotement")
	_check(float(a0["alpha"]) > 0.0, "et visible (%.2f)" % float(a0["alpha"]))
	_proche(float(a0["alpha"]), float(p["alpha"]), "à la présence du modèle", 0.0001)
	# Sans période dite : celle par défaut.
	var defaut := SV.animer(CAT.FUSEE, p, {"continu": true}, 0.0)
	_proche(float(defaut["duree"]), SV.PERIODE_CONTINU_DEFAUT * SV.TOLERANCE_CONTINU, "sans période, celle de la combustion")
	# Elle ignore la forme d'onde du fichier : la boucle de trois secondes n'y change rien.
	var bref := SV.animer(CAT.FUSEE, p, {"continu": true, "periode": 0.6, "chemin": SFX + "shell_01.wav"}, 0.0)
	_check(bref["niveaux"] == vie["niveaux"], "le fichier ne compte pas pour une source continue")


func _test_repli() -> void:
	var p := _p(CAT.TIR, 0.0, 100.0, PORTEE, 0.0, 0.0, 0.35, 900.0)
	_check(SV.animer(CAT.TIR, p, {"chemin": "res://n_existe_pas.wav", "pitch": 1.0}, 0.0).is_empty(),
		"un son sans enveloppe n'a pas de vie animée : c'est le repli")
	_check(SV.animer(CAT.TIR, p, {"chemin": ""}, 0.0).is_empty(), "un flux sans chemin non plus")
	_check(SV.animer(CAT.TIR, p, {}, 0.0).is_empty(), "ni un événement d'avant les chemins")
	# Le repli retrouve l'enveloppe fixe et sa durée par sorte.
	var t := {"largeur": p["largeur"], "alpha": p["alpha"], "epaisseur": p["epaisseur"],
		"douceur": p["douceur"], "duree": p["duree"], "vie": {}}
	_proche(float(t["duree"]), float(SV.DUREE[CAT.TIR]) * (1.0 + SV.TRAINE_REVERB * 0.35 * float(SV.RESONANCE[CAT.TIR])),
		"la durée de repli est celle de la table, allongée par la salle")
	_proche(float(SV.etat(t, SV.ATTAQUE_S)["alpha"]), float(p["alpha"]), "le repli atteint son pic à la fin de l'attaque", 0.0001)
	_check(float(SV.etat(t, 0.01)["alpha"]) < float(p["alpha"]) * 0.2, "… et monte depuis zéro")
	_check(SV.etat(t, float(t["duree"]) + 0.01).is_empty(), "… puis s'éteint à son terme")
	_check(SV.etat({"duree": 0.5}, 0.1).size() > 0, "une trace minimale ne fait pas tomber le calcul")


func _test_determinisme_et_plafond() -> void:
	var a := _trace(CAT.TIR, -4.0, _pente(80, 0.7), 0.35, 0.231, 0.22, 1.037, 0.667)
	var b := _trace(CAT.TIR, -4.0, _pente(80, 0.7), 0.35, 0.231, 0.22, 1.037, 0.667)
	_check(a["vie"]["niveaux"] == b["vie"]["niveaux"] and a["vie"]["diffus"] == b["vie"]["diffus"]
		and a["duree"] == b["duree"], "mêmes entrées, même vie : les deux vues voient la même animation")
	# Le plafond : un son de 5 s à plein niveau ne vit pas plus de DUREE_MAX_S, et s'efface au lieu d'être coupé.
	var tres_long := _trace(CAT.TIR, 0.0, _plat(500), 0.42, 0.35)
	_proche(float(tres_long["duree"]), SV.DUREE_MAX_S, "un son de 5 s est plafonné", 0.011)
	var milieu := float(SV.etat(tres_long, 1.5)["alpha"])
	var bord := float(SV.etat(tres_long, SV.DUREE_MAX_S - 0.01)["alpha"])
	_check(bord < milieu * 0.25, "… et s'efface avant le plafond au lieu d'être coupé (%.2f puis %.2f)" % [milieu, bord])
	# Une enveloppe qui ne touche pas 0 dB est renormalisée à son pic : le pic reste le pic.
	var decale := _trace(CAT.TIR, -3.0, [-6.0, -8.0, -10.0, -12.0, -14.0])
	_proche(float(SV.etat(decale, 0.0)["alpha"]), float(decale["p"]["alpha"]), "une enveloppe décalée est renormalisée à son pic", 0.0001)


func _test_table_et_vrais_sons() -> void:
	# La table est bien formée (la suite `test_enveloppes_sons` garde son lien aux WAV).
	var table: Dictionary = SV.Enveloppes.ENVELOPPES
	_check(table.size() >= 50, "la table porte les sons positionnels (%d)" % table.size())
	_proche(SV.Enveloppes.PAS_S, 0.01, "un pas de 10 ms")
	var bien_forme := true
	var pic_zero := true
	var longueur := true
	for chemin in table:
		var e: Dictionary = table[chemin]
		var db: Array = e["db"]
		var maxi := -999.0
		for x in db:
			bien_forme = bien_forme and float(x) <= 0.0 and float(x) >= SV.Enveloppes.PLANCHER_DB
			maxi = maxf(maxi, float(x))
		pic_zero = pic_zero and maxi == 0.0
		longueur = longueur and absi(db.size() - int(ceil(float(e["duree"]) / SV.Enveloppes.PAS_S))) <= 1
	_check(bien_forme, "chaque valeur est dans [plancher, 0] dB")
	_check(pic_zero, "chaque enveloppe est normalisée : son pic vaut 0 dB")
	_check(longueur, "chaque enveloppe couvre la durée de son fichier, à un pas près")

	# Vrais fichiers, salle par défaut de la carte (room 0,231 · wet 0,35).
	var pistolet := _trace_reelle(ARMES + "weapon_pistolet_01.wav", CAT.TIR, 0.0, 0.35, 0.231)
	var pompe := _trace_reelle(ARMES + "weapon_pompe_01.wav", CAT.TIR, 0.0, 0.35, 0.231)
	var pas := _trace_reelle(SFX + "footstep_a_01.wav", CAT.PAS, SV.NIVEAU_NET_DB, 0.35, 0.231)
	var accroupi := _trace_reelle(SFX + "footstep_a_01.wav", CAT.PAS, SV.NIVEAU_FLOU_DB, 0.35, 0.231)
	var recharge := _trace_reelle(ARMES + "weapon_reload_pistolet.wav", CAT.RECHARGE, -8.0, 0.35, 0.231)
	_check(pistolet.has("vie") and pompe.has("vie") and pas.has("vie") and accroupi.has("vie") and recharge.has("vie"),
		"les vrais fichiers ont une vie animée")
	_check(float(pistolet["duree"]) > 1.8 * float(pas["duree"]),
		"un tir vit bien plus longtemps qu'un pas (%.2f s contre %.2f s)" % [float(pistolet["duree"]), float(pas["duree"])])
	_check(float(pompe["duree"]) > float(pistolet["duree"]) + 0.3,
		"un fusil à pompe (1,4 s) plus qu'un pistolet (0,5 s) : %.2f s contre %.2f s" % [float(pompe["duree"]), float(pistolet["duree"])])
	_check(float(pas["duree"]) < 0.4, "un pas est un bref coup sourd : %.2f s" % float(pas["duree"]))
	_check(float(accroupi["duree"]) < float(pas["duree"]), "accroupi, encore plus bref (%.2f s)" % float(accroupi["duree"]))
	# Le pas attend son coup (~100 ms de silence dans le fichier), puis claque.
	_check(float(SV.etat(pas, 0.02)["alpha"]) < 0.05, "le pas n'est pas là avant son coup")
	var coup := 0.0
	for k in 30:
		coup = maxf(coup, float(SV.etat(pas, float(k) * 0.01).get("alpha", 0.0)))
	_proche(coup, float(pas["p"]["alpha"]), "au coup, le pas a la présence du modèle", 0.02)
	# Le rechargement montre son clic final, pas son froissement.
	var pic_recharge := 0.0
	var froissement := 0.0
	for k in 90:
		var e := SV.etat(recharge, float(k) * 0.01)
		if e.is_empty():
			continue
		if k < 40:
			froissement = maxf(froissement, float(e["alpha"]))
		pic_recharge = maxf(pic_recharge, float(e["alpha"]))
	_check(pic_recharge > 0.5 and froissement < 0.02,
		"le rechargement : clic visible (%.2f), froissement invisible (%.3f)" % [pic_recharge, froissement])
	# Court ET étouffé : le coup au but « de bord » (80 ms), dans un sas, derrière un mur.
	var bord_sas := _trace_reelle(SFX + "hit_edge.wav", CAT.CORPS, -7.0, 0.24, 0.06, 1.0, 1.0)
	_check(bord_sas.has("vie") and float(bord_sas["duree"]) < 0.2,
		"un coup de bord dans un sas, derrière un mur : très bref (%.2f s)" % float(bord_sas.get("duree", 9.0)))
	# Deux fois le même son, mêmes nombres.
	var pistolet2 := _trace_reelle(ARMES + "weapon_pistolet_01.wav", CAT.TIR, 0.0, 0.35, 0.231)
	_check(pistolet["vie"]["niveaux"] == pistolet2["vie"]["niveaux"], "un même fichier, un même liseré")
	# Un pitch de 1,04 raccourcit de 4 % ce qui est soutenu.
	var rapide := _trace_reelle(ARMES + "weapon_pompe_01.wav", CAT.TIR, 0.0, 0.0, 0.231, 1.04)
	var normal := _trace_reelle(ARMES + "weapon_pompe_01.wav", CAT.TIR, 0.0, 0.0, 0.231, 1.0)
	_check(float(rapide["duree"]) < float(normal["duree"]),
		"un son joué à 1,04 dure moins que joué à 1 (%.3f s contre %.3f s)" % [float(rapide["duree"]), float(normal["duree"])])


func _init() -> void:
	print("=== Son rendu visible — le modèle ===")
	_test_ancres()
	_test_elargissements()
	_test_allure()
	_test_sortes()
	_test_couleurs()
	_test_enveloppe()
	_test_geometrie()
	_test_vu()
	_test_salle()
	_test_vie_pic()
	_test_suit_l_enveloppe()
	_test_vie_en_db()
	_test_court_et_long()
	_test_traine()
	_test_elargissement()
	_test_occlusion_traine()
	_test_pitch()
	_test_continu()
	_test_repli()
	_test_determinisme_et_plafond()
	_test_table_et_vrais_sons()
	if _ko == 0:
		print("✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
