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
## - la géométrie du bord : un liseré reste sur le bord de l'écran, coins compris.
##
## La partie qui a besoin des autoloads — chaque famille d'`AudioManager` a sa
## sorte, l'émission par l'entonnoir, les vues de J1 et de J2 — vit dans
## `test_son_visible_jeu.gd`.

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
	_check(SV.profil(0.6, 1.0) > SV.profil(0.6, 0.0), "un liseré flou a les bords plus pleins")


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
	var poids: PackedFloat32Array = b["poids"]
	_check(bords.size() == dedans.size() and bords.size() == poids.size(), "bande cohérente")
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


func _init() -> void:
	print("=== Son rendu visible — le modèle ===")
	_test_ancres()
	_test_elargissements()
	_test_allure()
	_test_sortes()
	_test_couleurs()
	_test_enveloppe()
	_test_geometrie()
	if _ko == 0:
		print("✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
