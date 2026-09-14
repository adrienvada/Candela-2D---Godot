## Suite headless du chantier MURS BAS ET ACCROUPI, étape MB0.
## Lancer : godot --headless --path . --script res://tools/test_murs_bas.gd
##
## Ce qu'elle garde, et ce qu'elle ne peut pas garder.
##
## - **La géométrie** (`murs_bas_geometrie.gd`) : la longueur de zone morte aux
##   valeurs limites, la symétrie des deux côtés d'un mur, un accroupi à L + ε
##   visible et à L − ε invisible, la torche d'un accroupi qui bute, la tête
##   debout jamais cachée, plusieurs murs en série, le déterminisme.
## - **Ce qui du prototype se vérifie sans rendu** : les masques de chaque piste,
##   la balle qui passe au-dessus d'un accroupi dans la zone morte et le touche
##   au-delà, le pas de marche (mur haut, mur bas, enjambement lent), les bornes
##   des réglages, les scènes du contrôle d'accord, les constantes recopiées.
## - **Pas le rendu.** Rien ne se rastérise en headless : l'accord entre l'écran
##   et `franchit()`, le noir absolu et le coût se prouvent en fenêtre, par
##   `proto_murs_bas.tscn -- --auto`. Cette suite ne le remplace pas.
extends SceneTree

const Geo := preload("res://tools/murs_bas_geometrie.gd")

var _failures := 0
var _proto_script: GDScript


func _init() -> void:
	print("=== Test murs bas (MB0) ===")
	_test_longueur()
	_test_accroupi_autour_de_L()
	_test_symetrie()
	_test_tete_et_torche()
	_test_murs_en_serie()
	_test_cas_limites_du_segment()
	_test_determinisme()
	_test_constantes_recopiees()
	_test_shader_traduit_la_regle()
	_proto_script = load("res://tools/proto_murs_bas.gd")
	_test_masques_de_piste()
	_test_tir()
	_test_marche()
	_test_reglages()
	_test_scenes_d_accord.call_deferred()


func _finir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


# Un mur bas horizontal de 6 tuiles sur 1, au milieu d'un grand vide.
func _mur() -> Rect2:
	return Rect2(Vector2(0, 0), Vector2(6, 1) * Geo.TUILE)

const H_MUR := Geo.HAUTEUR_MUR_BAS * Geo.TUILE
const H_ACC := Geo.HAUTEUR_ACCROUPI * Geo.TUILE
const H_DEB := Geo.HAUTEUR_DEBOUT * Geo.TUILE
const ALPHA := Geo.ANGLE_FRANCHISSEMENT


func _test_longueur() -> void:
	print("\n— longueur de la zone morte —")
	var l := Geo.longueur_zone_morte(H_MUR, 0.0, 45.0)
	_check("à 45°, L_sol = h", absf(l - H_MUR) < 1e-4, "L=%f h=%f" % [l, H_MUR])
	_check("L_accroupi = (h − c) / tan α",
		absf(Geo.longueur_zone_morte(H_MUR, H_ACC, 30.0) - (H_MUR - H_ACC) / tan(deg_to_rad(30.0))) < 1e-4)
	_check("une cible aussi haute que le mur : L = 0", Geo.longueur_zone_morte(H_MUR, H_MUR, ALPHA) == 0.0)
	_check("une tête plus haute que le mur : L = 0", Geo.longueur_zone_morte(H_MUR, H_DEB, ALPHA) == 0.0)
	_check("angle au-dessus de 89° borné : L finie et petite",
		Geo.longueur_zone_morte(H_MUR, 0.0, 90.0) == Geo.longueur_zone_morte(H_MUR, 0.0, Geo.ANGLE_MAX)
		and Geo.longueur_zone_morte(H_MUR, 0.0, 90.0) < H_MUR * 0.02)
	_check("angle nul borné à 1° : L finie",
		is_finite(Geo.longueur_zone_morte(H_MUR, 0.0, 0.0))
		and Geo.longueur_zone_morte(H_MUR, 0.0, 0.0) == Geo.longueur_zone_morte(H_MUR, 0.0, Geo.ANGLE_MIN))
	_check("L décroît quand α monte",
		Geo.longueur_zone_morte(H_MUR, 0.0, 10.0) > Geo.longueur_zone_morte(H_MUR, 0.0, 20.0))
	# Les valeurs proposées au jalon, recalculées ici : si quelqu'un change une
	# constante, ce contrôle dit ce qu'Adrien voit changer.
	var l_sol := Geo.longueur_zone_morte(Geo.HAUTEUR_MUR_BAS, 0.0, ALPHA)
	var l_acc := Geo.longueur_zone_morte(Geo.HAUTEUR_MUR_BAS, Geo.HAUTEUR_ACCROUPI, ALPHA)
	_check("valeurs proposées : L_sol ≈ 3 tuiles, L_accroupi ≈ 1,5 tuile",
		absf(l_sol - 3.0) < 0.05 and absf(l_acc - 1.5) < 0.05, "L_sol=%.3f L_acc=%.3f" % [l_sol, l_acc])


func _test_accroupi_autour_de_L() -> void:
	print("\n— un accroupi à L ± ε —")
	var mur := _mur()
	var l := Geo.longueur_zone_morte(H_MUR, H_ACC, ALPHA)
	var src := Vector2(mur.get_center().x, -3.0 * Geo.TUILE)
	for eps: float in [0.5, 2.0, 10.0]:
		var loin := Vector2(src.x, mur.end.y + l + eps)
		var pres := Vector2(src.x, mur.end.y + l - eps)
		_check("ε = %.1f px : visible à L + ε" % eps,
			Geo.franchit(src, loin, H_DEB, H_ACC, [mur], H_MUR, ALPHA))
		_check("ε = %.1f px : invisible à L − ε" % eps,
			not Geo.franchit(src, pres, H_DEB, H_ACC, [mur], H_MUR, ALPHA))
	# La distance se compte le long du RAYON : en oblique, la même profondeur
	# perpendiculaire est plus longue sur le rayon, donc on sort plus tôt.
	var oblique_src := Vector2(mur.position.x + 20.0, -3.0 * Geo.TUILE)
	var dir := Vector2(1, 1).normalized()
	var fin := Geo.fin_de_zone_morte(oblique_src, dir, 1000.0, mur, H_MUR, H_ACC, ALPHA)
	_check("en oblique : juste après la fin annoncée, visible",
		fin > 0.0 and Geo.franchit(oblique_src, oblique_src + dir * (fin + 1.0), H_DEB, H_ACC, [mur], H_MUR, ALPHA))
	_check("en oblique : juste avant, invisible",
		not Geo.franchit(oblique_src, oblique_src + dir * (fin - 1.0), H_DEB, H_ACC, [mur], H_MUR, ALPHA))
	_check("L ne dépend pas de la distance de la source au mur (« un même angle »)",
		Geo.franchit(Vector2(src.x, -20.0 * Geo.TUILE), Vector2(src.x, mur.end.y + l + 1.0), H_DEB, H_ACC, [mur], H_MUR, ALPHA)
		and not Geo.franchit(Vector2(src.x, -20.0 * Geo.TUILE), Vector2(src.x, mur.end.y + l - 1.0), H_DEB, H_ACC, [mur], H_MUR, ALPHA))


func _test_symetrie() -> void:
	print("\n— symétrie des deux côtés du mur —")
	var mur := _mur()
	var cy := mur.get_center().y
	var cx := mur.get_center().x
	var desaccords := 0
	var essais := 0
	for dx in range(-150, 151, 25):
		for dist_src in [40.0, 90.0, 200.0]:
			for prof in range(0, 120, 7):
				# Nord → sud, et son miroir sud → nord par rapport à l'axe du mur.
				var s1 := Vector2(cx + dx, mur.position.y - dist_src)
				var c1 := Vector2(cx - dx * 0.3, mur.end.y + prof)
				var s2 := Vector2(s1.x, 2.0 * cy - s1.y)
				var c2 := Vector2(c1.x, 2.0 * cy - c1.y)
				essais += 1
				if Geo.franchit(s1, c1, H_DEB, H_ACC, [mur], H_MUR, ALPHA) != \
						Geo.franchit(s2, c2, H_DEB, H_ACC, [mur], H_MUR, ALPHA):
					desaccords += 1
	_check("miroir nord/sud : même verdict (%d cas)" % essais, desaccords == 0, "%d désaccords" % desaccords)
	# Et la règle 2 : la même lumière, du côté de l'accroupi, l'éclaire.
	var acc := Vector2(cx, mur.end.y + 10.0)
	_check("règle 2 : caché depuis l'autre côté",
		not Geo.franchit(Vector2(cx, mur.position.y - 100.0), acc, H_DEB, H_ACC, [mur], H_MUR, ALPHA))
	_check("règle 2 : éclairé par une lumière de son côté",
		Geo.franchit(Vector2(cx + 60.0, mur.end.y + 120.0), acc, H_DEB, H_ACC, [mur], H_MUR, ALPHA))


func _test_tete_et_torche() -> void:
	print("\n— tête debout, torche accroupie —")
	var mur := _mur()
	var cx := mur.get_center().x
	var src := Vector2(cx, mur.position.y - 100.0)
	_check("règle 1 : une tête debout collée derrière le mur est vue",
		Geo.franchit(src, Vector2(cx, mur.end.y + 1.0), H_DEB, H_DEB, [mur], H_MUR, ALPHA))
	_check("règle 1 : le sol juste derrière est dans l'ombre",
		not Geo.franchit(src, Vector2(cx, mur.end.y + 1.0), H_DEB, 0.0, [mur], H_MUR, ALPHA))
	_check("règle 5 : la torche d'un accroupi bute, même sur une tête debout",
		not Geo.franchit(src, Vector2(cx, mur.end.y + 1.0), H_ACC, H_DEB, [mur], H_MUR, ALPHA))
	_check("règle 5 : …et à toute distance",
		not Geo.franchit(src, Vector2(cx, mur.end.y + 5000.0), H_ACC, 0.0, [mur], H_MUR, ALPHA))
	_check("une source à la hauteur exacte du mur ne franchit pas",
		not Geo.franchit(src, Vector2(cx, mur.end.y + 5000.0), H_MUR, 0.0, [mur], H_MUR, ALPHA))
	_check("la torche accroupie éclaire tout ce qui est de son côté",
		Geo.franchit(src, Vector2(cx + 30.0, mur.position.y - 5.0), H_ACC, 0.0, [mur], H_MUR, ALPHA))
	var haut := Rect2(Vector2(0, 300), Vector2(6, 1) * Geo.TUILE)
	_check("un mur haut arrête une tête debout",
		not Geo.visible(Vector2(cx, 200), Vector2(cx, 400), H_DEB, H_DEB, [haut], [], H_MUR, ALPHA))


func _test_murs_en_serie() -> void:
	print("\n— deux murs bas sur le même rayon —")
	# C'est le cas qui a écarté la piste B (trois lumières, additive et
	# soustractive) avant même d'être écrite : sa décomposition n'ombre que le
	# premier mur. La formule, elle, doit ombrer derrière CHACUN.
	var l := Geo.longueur_zone_morte(H_MUR, 0.0, ALPHA)
	var m1 := Rect2(Vector2(0, 0), Vector2(6, 1) * Geo.TUILE)
	var m2 := Rect2(Vector2(0, Geo.TUILE + l + 60.0), Vector2(6, 1) * Geo.TUILE)
	var src := Vector2(m1.get_center().x, -100.0)
	var murs := [m1, m2]
	_check("entre les deux zones mortes : sol éclairé",
		Geo.franchit(src, Vector2(src.x, m1.end.y + l + 30.0), H_DEB, 0.0, murs, H_MUR, ALPHA))
	_check("derrière le second mur : sol à l'ombre",
		not Geo.franchit(src, Vector2(src.x, m2.end.y + 5.0), H_DEB, 0.0, murs, H_MUR, ALPHA))
	_check("au-delà du second : éclairé",
		Geo.franchit(src, Vector2(src.x, m2.end.y + l + 5.0), H_DEB, 0.0, murs, H_MUR, ALPHA))
	_check("l'ordre des murs ne change rien",
		Geo.franchit(src, Vector2(src.x, m2.end.y + 5.0), H_DEB, 0.0, [m2, m1], H_MUR, ALPHA) ==
		Geo.franchit(src, Vector2(src.x, m2.end.y + 5.0), H_DEB, 0.0, murs, H_MUR, ALPHA))


func _test_cas_limites_du_segment() -> void:
	print("\n— cas limites du segment —")
	var r := Rect2(0, 0, 100, 20)
	_check("segment qui ne touche pas : -1", Geo.sortie_du_rect(Vector2(-10, -50), Vector2(200, -40), r) < 0.0)
	_check("cible posée SUR le mur : pas derrière", Geo.sortie_du_rect(Vector2(50, -50), Vector2(50, 10), r) < 0.0)
	_check("source dans le mur : ne compte pas sa propre sortie comme franchissement",
		Geo.sortie_du_rect(Vector2(50, 10), Vector2(50, 100), r) > 0.0)
	_check("segment parallèle à une face, dehors : -1", Geo.sortie_du_rect(Vector2(-10, -1), Vector2(200, -1), r) < 0.0)
	_check("segment vertical qui traverse : t de sortie exact",
		absf(Geo.sortie_du_rect(Vector2(50, -80), Vector2(50, 120), r) - 0.5) < 1e-5)
	_check("mur haut : segment qui rase l'extérieur ne touche pas",
		not Geo.coupe_un_mur_haut(Vector2(-10, -1), Vector2(200, -1), [r]))


func _test_determinisme() -> void:
	print("\n— déterminisme —")
	var murs := [Rect2(0, 0, 210, 35), Rect2(300, -100, 35, 175), Rect2(-200, 150, 140, 35)]
	var sources := []
	var cibles := []
	for k in 12:
		sources.append(Vector2(-250 + 45 * k, -220 + 13 * k))
		cibles.append(Vector2(-240 + 51 * k, 260 - 17 * k))
	var a := Geo.empreinte_balayage(sources, cibles, H_DEB, H_ACC, murs, H_MUR, ALPHA)
	var b := Geo.empreinte_balayage(sources, cibles, H_DEB, H_ACC, murs, H_MUR, ALPHA)
	var inverses := murs.duplicate()
	inverses.reverse()
	var c := Geo.empreinte_balayage(sources, cibles, H_DEB, H_ACC, inverses, H_MUR, ALPHA)
	_check("deux balayages identiques, même empreinte", a == b)
	_check("murs dans l'autre ordre, même empreinte", a == c)
	var d := Geo.empreinte_balayage(sources, cibles, H_DEB, H_ACC, murs, H_MUR, ALPHA + 3.0)
	_check("témoin : un autre angle change l'empreinte (le contrôle peut échouer)", a != d)


func _test_constantes_recopiees() -> void:
	print("\n— constantes recopiées, reliées à leur original —")
	_check("TUILE = CandelaTileSet.TILE_SIZE", _lire_nombre("res://candela_tileset.gd",
		"const TILE_SIZE    := Vector2i(") == Geo.TUILE)
	_check("RETRAIT_OCCLUDER = MapGeometry.OCCLUDER_INSET", _lire_nombre("res://map_geometry.gd",
		"const OCCLUDER_INSET := ") == 3.0)
	_check("VITESSE_DEBOUT = player.gd speed", _lire_nombre("res://player.gd",
		"@export var speed: float = ") == 260.0)
	_check("contrat ISO1 : quatre hauteurs nommées, en tuiles, et ordonnées",
		Geo.HAUTEUR_ACCROUPI < Geo.HAUTEUR_MUR_BAS and Geo.HAUTEUR_MUR_BAS < Geo.HAUTEUR_DEBOUT
		and Geo.HAUTEUR_DEBOUT <= Geo.HAUTEUR_MUR_HAUT)


## Le nombre qui suit `prefixe` sur la ligne qui le porte, ou NAN.
func _lire_nombre(chemin: String, prefixe: String) -> float:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return NAN
	for ligne in f.get_as_text().split("\n"):
		var i := ligne.find(prefixe)
		if i >= 0:
			var reste := ligne.substr(i + prefixe.length())
			var n := ""
			for ch in reste:
				if ch in "0123456789.":
					n += ch
				else:
					break
			return float(n) if n != "" else NAN
	return NAN


## Le shader ne peut pas s'exécuter ici. Ce contrôle ne prouve donc PAS qu'il
## calcule juste (le contrôle d'accord en fenêtre le prouve) : il attrape la
## dérive la plus probable, un cas limite ou un seuil modifié d'un seul côté.
func _test_shader_traduit_la_regle() -> void:
	print("\n— le shader porte les mêmes cas limites que la géométrie —")
	var f := FileAccess.open("res://tools/proto_murs_bas.gdshader", FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	var sans_espaces := src.replace(" ", "").replace("\t", "")
	_check("sortie rejetée hors de ]0, 1[", sans_espaces.contains("if(te>ts||ts<=0.0||ts>=1.0)"))
	_check("zone morte comptée le long du rayon depuis la sortie",
		sans_espaces.contains("(1.0-t)*longueur<zone_morte"))
	_check("un corps se juge en son centre", sans_espaces.contains("vec2cible=au_centre?centre:LIGHT_VERTEX.xy;"))
	_check("64 murs au plus, comme le prototype en pousse", sans_espaces.contains("uniformvec4murs[64];"))


func _test_masques_de_piste() -> void:
	print("\n— masques des pistes —")
	var P = _proto_script
	var a: Dictionary = P.masques_de_piste(0, false)
	var b_deb: Dictionary = P.masques_de_piste(1, false)
	var b_acc: Dictionary = P.masques_de_piste(1, true)
	var c_deb: Dictionary = P.masques_de_piste(2, false)
	var c_acc: Dictionary = P.masques_de_piste(2, true)
	var bit_bas: int = P.BIT_MUR_BAS
	_check("A : toute lumière voit les occluders des murs bas", a["ombre_lumiere"] & bit_bas != 0)
	_check("A : le corps debout n'est ombré par RIEN (le défaut que la piste porte)",
		a["corps_debout"] & a["ombre_lumiere"] == 0)
	_check("B debout : polygones finis, pas les murs pleins",
		b_deb["ombre_lumiere"] & P.BIT_ZONE_FINIE != 0 and b_deb["ombre_lumiere"] & bit_bas == 0)
	_check("B accroupi : murs pleins", b_acc["ombre_lumiere"] & bit_bas != 0)
	_check("C debout : la torche ne voit pas les murs bas pleins (le shader s'en charge)",
		c_deb["ombre_lumiere"] & bit_bas == 0 and c_deb["shader"])
	_check("C accroupi : la torche bute sur les murs bas pleins", c_acc["ombre_lumiere"] & bit_bas != 0)
	_check("C : les deux corps reçoivent l'ombre des murs hauts",
		c_deb["corps_debout"] & c_deb["ombre_lumiere"] & P.BIT_DECOR != 0
		and c_deb["corps_accroupi"] & c_deb["ombre_lumiere"] & P.BIT_DECOR != 0)
	var poly: PackedVector2Array = P.polygone_zone_finie(Vector2(0, -100), Rect2(-50, 0, 100, 20), 60.0)
	_check("B : le polygone fini couvre le mur et s'étend au-delà",
		Geometry2D.is_point_in_polygon(Vector2(0, 10), poly) and Geometry2D.is_point_in_polygon(Vector2(0, 70), poly)
		and not Geometry2D.is_point_in_polygon(Vector2(0, 120), poly))


func _test_tir() -> void:
	print("\n— la balle, même vérité que la lumière —")
	var P = _proto_script
	var mur := _mur()
	var cx := mur.get_center().x
	var l := Geo.longueur_zone_morte(H_MUR, H_ACC, ALPHA)
	var src := Vector2(cx, mur.position.y - 120.0)
	var dir := Vector2.DOWN
	var acc_pres := {"nom": "pres", "centre": Vector2(cx, mur.end.y + l - 10.0), "rayon": 13.0, "hauteur": H_ACC}
	var acc_loin := {"nom": "loin", "centre": Vector2(cx, mur.end.y + l + 40.0), "rayon": 13.0, "hauteur": H_ACC}
	var r: Dictionary = P.resoudre_tir(src, dir, H_DEB, [acc_pres, acc_loin], [], [mur], H_MUR, ALPHA)
	_check("tireur debout : passe au-dessus de l'accroupi dans la zone morte",
		"pres" in r["passe_au_dessus"], r["texte"])
	_check("…et touche l'accroupi au-delà (règle 3)", r["touche"] == "loin", r["texte"])
	var seul: Dictionary = P.resoudre_tir(src, dir, H_DEB, [acc_pres], [], [mur], H_MUR, ALPHA)
	_check("accroupi seul dans la zone morte : rien touché", seul["touche"] == "", seul["texte"])
	var r_acc: Dictionary = P.resoudre_tir(src, dir, H_ACC, [acc_loin], [], [mur], H_MUR, ALPHA)
	_check("tireur accroupi : la balle s'arrête sur le mur bas", r_acc["touche"] == ""
		and absf(r_acc["distance"] - 120.0) < 0.5, r_acc["texte"])
	var debout := {"nom": "tete", "centre": Vector2(cx, mur.end.y + 5.0), "rayon": 18.0, "hauteur": H_DEB}
	var r_deb: Dictionary = P.resoudre_tir(src, dir, H_DEB, [debout], [], [mur], H_MUR, ALPHA)
	_check("tireur debout : touche un debout collé derrière le mur (règle 1)", r_deb["touche"] == "tete", r_deb["texte"])
	# La balle et la lumière disent la même chose, point par point le long d'un rayon.
	var desaccords := 0
	for k in range(0, 300, 3):
		var c := {"nom": "c", "centre": Vector2(cx, mur.end.y + 20.0 + k), "rayon": 1.0, "hauteur": H_ACC}
		var tir: Dictionary = P.resoudre_tir(src, dir, H_DEB, [c], [], [mur], H_MUR, ALPHA)
		var lumiere := Geo.franchit(src, c["centre"], H_DEB, H_ACC, [mur], H_MUR, ALPHA)
		if (tir["touche"] == "c") != lumiere:
			desaccords += 1
	_check("ce qui se voit est ce qui se paie : 100 profondeurs, 0 désaccord", desaccords == 0,
		"%d désaccords" % desaccords)


func _test_marche() -> void:
	print("\n— marche, accroupi, enjambement —")
	var P = _proto_script
	var bas := [Rect2(100, -100, 35, 200)]
	var haut := [Rect2(-135, -100, 35, 200)]
	var dt := 1.0 / 60.0
	var libre: Dictionary = P.pas_de_marche(Vector2.ZERO, Vector2.RIGHT, dt, false, false, [], [], 0.45)
	_check("debout : 260 px/s", absf(libre["position"].x - 260.0 * dt) < 1e-3)
	var accroupi: Dictionary = P.pas_de_marche(Vector2.ZERO, Vector2.RIGHT, dt, true, false, [], [], 0.45)
	_check("accroupi : ralenti fortement (×0,45)", absf(accroupi["position"].x - 117.0 * dt) < 1e-3)
	var contre := Vector2(100 - 18.5, 0)
	var bloque: Dictionary = P.pas_de_marche(contre, Vector2.RIGHT, dt, false, false, haut, bas, 0.45)
	_check("mur bas sans « croix » : bloqué", bloque["position"] == contre)
	var pos := contre
	var t := 0.0
	var vu_enjambe := false
	var vitesse_max := 0.0
	while pos.x < 100 + 35 + 18.5 and t < 5.0:
		var r: Dictionary = P.pas_de_marche(pos, Vector2.RIGHT, dt, false, true, haut, bas, 0.45)
		if r["enjambe"]:
			vu_enjambe = true
			vitesse_max = maxf(vitesse_max, r["vitesse"])
		pos = r["position"]
		t += dt
	_check("avec « croix » : il passe de l'autre côté", pos.x >= 100 + 35 + 18.5, "x=%f après %.2f s" % [pos.x, t])
	_check("lentement : à 65 px/s pendant le chevauchement", vu_enjambe and absf(vitesse_max - 65.0) < 1e-3,
		"vitesse=%f" % vitesse_max)
	_check("un mur haut ne s'enjambe jamais",
		P.pas_de_marche(Vector2(-100 + 18.5, 0), Vector2.LEFT, dt, false, true, haut, bas, 0.45)["position"]
		== Vector2(-100 + 18.5, 0))


func _test_reglages() -> void:
	print("\n— bornes des réglages à chaud —")
	var P = _proto_script
	var v := {"h_bas": 0.5, "h_accroupi": 0.25, "angle": 9.5, "facteur_accroupi": 0.45}
	var r: Dictionary = P.regler("h_accroupi", 10.0, v)
	_check("un accroupi reste plus bas que le mur", r["h_accroupi"] < r["h_bas"])
	r = P.regler("h_bas", -10.0, v)
	_check("un mur bas reste plus haut que l'accroupi", r["h_bas"] > v["h_accroupi"])
	r = P.regler("h_bas", 10.0, v)
	_check("un mur bas reste plus bas qu'une tête debout", r["h_bas"] < Geo.HAUTEUR_DEBOUT)
	r = P.regler("angle", 1000.0, v)
	_check("l'angle reste dans ses bornes", r["angle"] == Geo.ANGLE_MAX)
	r = P.regler("facteur_accroupi", -10.0, v)
	_check("la vitesse accroupie ne tombe pas à zéro", r["facteur_accroupi"] > 0.0)
	r = P.regler("angle", 0.5, v)
	_check("un pas de réglage ne touche que sa valeur", r["angle"] == 10.0 and r["h_bas"] == 0.5)


## Instancie le prototype pour de vrai (sans rendu) et vérifie que ses scènes
## d'accord mettent en scène ce que leurs noms annoncent.
func _test_scenes_d_accord() -> void:
	print("\n— les scènes du contrôle d'accord —")
	var proto: Node2D = load("res://tools/proto_murs_bas.tscn").instantiate()
	root.add_child(proto)
	await process_frame
	var scenes: Array = proto.scenes_d_accord()
	var h_mur := Geo.en_pixels(proto.h_bas)
	var hauts: Array = proto._murs_hauts
	var bas: Array = proto._murs_bas
	_check("quatre scènes", scenes.size() == 4)
	var s0: Dictionary = scenes[0]
	var s1: Dictionary = scenes[1]
	var s2: Dictionary = scenes[2]
	var s3: Dictionary = scenes[3]
	_check("scène 1 : l'accroupi est caché (L − 12)",
		not Geo.visible(s0["torche"], s0["accroupi"], H_DEB, H_ACC, hauts, bas, h_mur, proto.angle))
	_check("scène 1 : le debout derrière le mur bas est vu",
		Geo.visible(s0["torche"], s0["debout"], H_DEB, H_DEB, hauts, bas, h_mur, proto.angle))
	_check("scène 2 : l'accroupi est vu (L + 12)",
		Geo.visible(s1["torche"], s1["accroupi"], H_DEB, H_ACC, hauts, bas, h_mur, proto.angle))
	_check("scène 3 : l'accroupi est éclairé de son côté",
		Geo.visible(s2["torche"], s2["accroupi"], H_DEB, H_ACC, hauts, bas, h_mur, proto.angle))
	_check("scène 3 : le debout est derrière un mur HAUT, donc caché",
		not Geo.visible(s2["torche"], s2["debout"], H_DEB, H_DEB, hauts, bas, h_mur, proto.angle)
		and Geo.coupe_un_mur_haut(s2["torche"], s2["debout"], hauts))
	_check("scène 4 : torche accroupie, le debout derrière le mur bas est caché",
		s3["torche_accroupie"] and not Geo.visible(s3["torche"], s3["debout"], H_ACC, H_DEB, hauts, bas, h_mur, proto.angle))
	var portee: float = proto.PORTEE_TORCHE * 0.8
	var dans_portee := true
	for s: Dictionary in scenes:
		for cle in ["debout", "accroupi"]:
			if (s[cle] as Vector2).distance_to(s["torche"]) > portee:
				dans_portee = false
	_check("toutes les cibles sont dans la partie plate de la torche (sinon le verdict viendrait de la portée)",
		dans_portee)
	_check("64 murs bas au plus (taille du tableau du shader)", bas.size() <= 64)
	proto.queue_free()
	_finir()
