## ISO14 — le banc d'équité du lacet : 0° contre 45°, trois options de caméra, six cartes (headless).
##
## **La règle a été fixée par la session cloud AVANT tout chiffre** (2026-09-24, 01:44 ; ROADMAP, Décisions
## actées, « ISO14 — la règle du banc d'équité ») : ce banc la calcule, il ne la choisit pas.
##
## Trois options, pour un lacet L : **A** les deux joueurs à L ; **B** J2 à L + 180° ; **C** J2 à −L (l'image de
## la caméra de J1 dans le miroir gauche-droite). Une option est ÉQUITABLE sur une carte si :
##   (0) pour les deux caméras : aucune case de sol entièrement invisible, aucune position où un corps
##       (rayon 18 px, disque de 25 points) soit entièrement caché — et la plus longue portion cachée imprimée ;
##   (a) l'écart de part cachée entre les deux moitiés ≤ 1 point, et ≤ l'écart d'aujourd'hui (0°, A) + 0,5 ;
##   (b) autour de chaque apparition (6 cases), écart ≤ 1 point ;
##   (e) L'ABRI CACHÉ : pour chaque joueur, la part des couples (p de sa moitié, 5 × 5 points par case ; q centre
##       d'une case de la moitié adverse) où p est à l'abri de q — le segment [p, q] coupe un mur à moins d'1,5
##       case de p — ET caché sur l'écran de l'adversaire : écart ≤ 1 point.
## (d) la part cachée totale à 45° contre 0° est une INFORMATION (le prix de l'angle, le même pour les deux).
## La garde (4) : à 0°, le calcul général (`IsoGeometrie.part_cachee_case`) rend les chiffres d'`analyser_equite`.
##
## ⚠️ **« La moitié de Ji » se lit SUR L'ÉCRAN DE SON ADVERSAIRE** : c'est là qu'elle cache Ji. Et (e) imprime deux
## chiffres : le joint (la règle telle qu'écrite aux Décisions actées) et le conditionnel (parmi les couples
## abrités, la part cachée — la lecture du plan). Le verdict se prend sur le joint.
##
## Chiffres prévus par le prototype Python `docs/iso/iso14/proto_equite.py` (2026-09-24, 04:43) : ce banc doit rendre
## les mêmes, et l'imprime carte par carte contre `reference_prototype.json` (`_comparer_au_prototype`). Aucune fenêtre,
## aucune cadence — de la géométrie.
##
## Lancer : godot --headless --path . --script res://tools/banc_equite.gd [-- --carte=<slug>]
## Sort en 1 si la garde (4) échoue ou si une carte ne se lit pas ; les verdicts ne font pas échouer le banc.
extends SceneTree

const TANGAGE := 52.0
const LIGNES := 8
const ABRI_CASES := 1.5
const RAYON_APPARITION := 6.0

var Geo: GDScript
var _tuile := 35.0
var _bande := 0.0
var _echecs := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	Geo = load("res://iso_geometrie.gd")
	var Proto: GDScript = load("res://tools/proto_iso.gd")
	_tuile = float(CandelaTileSet.TILE_SIZE.y)
	_bande = Geo.bande_masquee_px(Geo.hauteur_mur_haut() * _tuile, TANGAGE)
	var voulue := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--carte="):
			voulue = a.trim_prefix("--carte=")
	print("=== BANC D'ÉQUITÉ DU LACET — tangage %s°, mur %s tuile, bande %.1f px, tuile %s px ==="
		% [TANGAGE, Geo.hauteur_mur_haut(), _bande, _tuile])
	var t_depart := Time.get_ticks_msec()
	var verdicts: Array = []
	for slug: String in Proto.cartes_livrees():
		if voulue != "" and slug != voulue:
			continue
		var data: Dictionary = Proto.charger_carte_livree(slug)
		if data.is_empty():
			printerr("✗ %s ne se lit pas" % slug)
			_echecs += 1
			continue
		verdicts.append_array(_carte(slug, data))
	if voulue == "":
		_corps_colle()
	print("\n=== VERDICTS À 45° ===")
	for v: String in verdicts:
		print(v)
	print("\n(%.1f s)" % ((Time.get_ticks_msec() - t_depart) / 1000.0))
	if _echecs > 0:
		printerr("✗ %d échec(s) — garde ou lecture" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _carte(slug: String, data: Dictionary) -> Array:
	var t_depart := Time.get_ticks_msec()
	var grille := MapCodec.get_grid_size(data)
	var murs := {}
	for c in MapCodec.get_wall_cells(data):
		murs[c] = true
	var sol: Array[Vector2i] = []
	for c in MapCodec.get_floor_cells(data):
		if not murs.has(c) and c.x >= 0 and c.y >= 0 and c.x < grille.x and c.y < grille.y:
			sol.append(c)
	var s1 := MapCodec.get_spawn(data, 0)
	var s2 := MapCodec.get_spawn(data, 1)
	print("\n=== %s — %d×%d, %d cases de sol, %d de mur, apparitions %s et %s ==="
		% [slug, grille.x, grille.y, sol.size(), murs.size(), s1, s2])
	_symetries(grille, murs, s1, s2)

	var poids := {}
	for c in sol:
		var d1 := Vector2(c).distance_squared_to(Vector2(s1))
		var d2 := Vector2(c).distance_squared_to(Vector2(s2))
		poids[c] = Vector2(1, 0) if d1 < d2 else (Vector2(0, 1) if d2 < d1 else Vector2(0.5, 0.5))

	# Les points p, 5 × 5 par case, et leurs abris contre les centres q de l'autre moitié : aucune caméra n'y
	# entre, c'est calculé une fois par carte.
	var points: Array[Vector2] = []
	var case_du_point: Array[Vector2i] = []
	for c in sol:
		for i in 5:
			for j in 5:
				points.append((Vector2(c) + Vector2((i + 0.5) / 5.0, (j + 0.5) / 5.0)) * _tuile)
				case_du_point.append(c)
	var proches := {}
	for c: Vector2i in murs:
		for ox in range(-2, 3):
			for oy in range(-2, 3):
				proches[c + Vector2i(ox, oy)] = true
	var abri_du_point: Array[Vector2] = []   # poids des couples abrités, par joueur
	var couples := Vector2.ZERO
	var couples_abrites := Vector2.ZERO
	var portee_abri := ABRI_CASES * _tuile
	var centres: Array[Vector2] = []
	var poids_q: Array[Vector2] = []
	for q_case in sol:
		centres.append((Vector2(q_case) + Vector2(0.5, 0.5)) * _tuile)
		poids_q.append(poids[q_case])
	for k in points.size():
		var c := case_du_point[k]
		var p := points[k]
		var wp: Vector2 = poids[c]
		var pres := proches.has(c)
		var a := Vector2.ZERO
		for iq in centres.size():
			var dq := centres[iq] - p
			var longueur := dq.length()
			var abrite := -1
			for i in 2:
				var w: float = wp[i] * poids_q[iq][1 - i]
				if w == 0.0:
					continue
				couples[i] += w
				if not pres or longueur < 1e-9:
					continue
				if abrite < 0:
					abrite = 0
					for passage in Geo.traverser(p, dq / longueur, minf(portee_abri, longueur), _tuile):
						if murs.has(passage[0]) and float(passage[2]) > float(passage[1]) + 1e-9:
							abrite = 1
							break
				if abrite == 1:
					a[i] += w
		abri_du_point.append(a)
		couples_abrites += a
	print("  abris : J1 à l'abri dans %.1f %% des couples, J2 dans %.1f %% (sans caméra)"
		% [100.0 * couples_abrites.x / couples.x, 100.0 * couples_abrites.y / couples.y])

	var releves := {}
	var ref_ecart := 0.0
	var verdicts: Array = []
	var mesures := {}
	for lacet: float in [0.0, 45.0]:
		for option in ["A", "B", "C"]:
			if lacet == 0.0 and option == "C":
				continue   # C = A à 0°
			var l1 := lacet
			var l2: float = lacet if option == "A" else (lacet + 180.0 if option == "B" else -lacet)
			var r1: Dictionary = _releve(l1, releves, sol, murs, points)
			var r2: Dictionary = _releve(l2, releves, sol, murs, points)
			# La moitié de J1 lue sur l'écran de J2 (r2), celle de J2 sur l'écran de J1 (r1).
			var m := Vector2(_moitie(0, r2, sol, poids), _moitie(1, r1, sol, poids))
			var ap := Vector2(_apparition(s1, r2, sol), _apparition(s2, r1, sol))
			var e := Vector2.ZERO
			var e_cond := Vector2.ZERO
			for i in 2:
				var ecran: Array = (r2 if i == 0 else r1)["points"]
				var num := 0.0
				for k in points.size():
					if ecran[k]:
						num += abri_du_point[k][i]
				e[i] = num / couples[i] if couples[i] > 0.0 else 0.0
				e_cond[i] = num / couples_abrites[i] if couples_abrites[i] > 0.0 else 0.0
			var ecart := absf(m.x - m.y) * 100.0
			if lacet == 0.0 and option == "A":
				ref_ecart = ecart
				_garde(data, r1, m)
			var ok0: bool = r1["invisibles"] == 0 and r2["invisibles"] == 0 and r1["corps"] == 0 and r2["corps"] == 0
			var oka := ecart <= 1.0 and ecart <= ref_ecart + 0.5
			var okb := absf(ap.x - ap.y) * 100.0 <= 1.0
			var oke := absf(e.x - e.y) * 100.0 <= 1.0
			var rates: PackedStringArray = []
			for paire in [["0", ok0], ["a", oka], ["b", okb], ["e", oke]]:
				if not paire[1]:
					rates.append(paire[0])
			var verdict := "ÉQUITABLE" if rates.is_empty() else "NON (%s)" % ",".join(rates)
			print(("  %3d° %s (J1 %4d°, J2 %4d°) : moitiés %5.2f / %5.2f %% (écart %4.2f)  apparitions %5.2f / %5.2f"
				+ "  abri caché %5.2f / %5.2f (sachant l'abri %5.2f / %5.2f)  invisibles %d/%d  corps cachés %d/%d"
				+ "  long. max %4.1f/%4.1f px  totale %5.2f/%5.2f %%  → %s")
				% [int(lacet), option, int(l1), int(l2), m.x * 100.0, m.y * 100.0, ecart, ap.x * 100.0, ap.y * 100.0,
				e.x * 100.0, e.y * 100.0, e_cond.x * 100.0, e_cond.y * 100.0,
				r1["invisibles"], r2["invisibles"], r1["corps"], r2["corps"],
				r1["longueur_max"], r2["longueur_max"], r1["totale"] * 100.0, r2["totale"] * 100.0, verdict])
			if lacet == 45.0:
				verdicts.append("EQUITE45 | %-20s | %s | %s" % [slug, option, verdict])
			mesures["%d%s" % [int(lacet), option]] = {
				"moitie_j1": m.x, "moitie_j2": m.y, "apparition_j1": ap.x, "apparition_j2": ap.y,
				"abri_j1": e.x, "abri_j2": e.y, "abri_cond_j1": e_cond.x, "abri_cond_j2": e_cond.y,
				"invisibles_j1": r1["invisibles"], "invisibles_j2": r2["invisibles"],
				"corps_j1": r1["corps"], "corps_j2": r2["corps"],
				"longueur_max_j1": r1["longueur_max"], "longueur_max_j2": r2["longueur_max"],
				"totale_j1": r1["totale"], "totale_j2": r2["totale"]}
	_comparer_au_prototype(slug, mesures)
	var r0: Dictionary = releves[0.0]
	var r45: Dictionary = releves[45.0]
	print("  (d) prix de l'angle : part totale cachée 45° / 0° = %.2f" % (float(r45["totale"]) / float(r0["totale"])))
	print("  (%.1f s)" % ((Time.get_ticks_msec() - t_depart) / 1000.0))
	return verdicts


## Ce que voit une caméra de lacet donné : la part cachée de chaque case, les points p cachés, les corps
## entièrement cachés. Mémorisé par lacet (B et C partagent la caméra de J1 avec A).
func _releve(lacet: float, releves: Dictionary, sol: Array[Vector2i], murs: Dictionary,
		points: Array[Vector2]) -> Dictionary:
	var cle := fposmod(lacet, 360.0)
	if lacet == 0.0 or lacet == 45.0:
		cle = lacet
	if releves.has(cle):
		return releves[cle]
	var d: Vector2 = Geo.vers_camera(lacet)
	var parts := {}
	var invisibles := 0
	var longueur_max := 0.0
	var totale := 0.0
	for c in sol:
		var r: Vector2 = Geo.part_cachee_case(c, d, murs, _bande, _tuile, LIGNES)
		parts[c] = r.x
		totale += r.x
		longueur_max = maxf(longueur_max, r.y)
		if r.x >= 1.0 - 1e-6:
			invisibles += 1
	var caches: Array[bool] = []
	for p in points:
		caches.append(Geo.point_cache(p, d, murs, _bande, _tuile))
	# Corps entièrement cachés : centres tous les 5 px, disque hors des murs, ses 25 points tous cachés.
	var disque: Array[Vector2] = [Vector2.ZERO]
	for anneau: Vector2 in [Vector2(9.0, 4.0), Vector2(18.0, 8.0)]:
		for k in int(anneau.y) * 2:
			disque.append(Vector2(anneau.x, 0.0).rotated(float(k) * PI / anneau.y))
	var corps := 0
	for c in sol:
		for i in 7:
			for j in 7:
				var centre := Vector2(c) * _tuile + Vector2(2.5 + 5.0 * i, 2.5 + 5.0 * j)
				var libre := true
				for o in disque:
					var pt := centre + o
					if murs.has(Vector2i(floori(pt.x / _tuile), floori(pt.y / _tuile))):
						libre = false
						break
				if not libre:
					continue
				var tout_cache := true
				for o in disque:
					if not Geo.point_cache(centre + o, d, murs, _bande, _tuile):
						tout_cache = false
						break
				if tout_cache:
					corps += 1
	var releve := {"parts": parts, "points": caches, "corps": corps, "invisibles": invisibles,
		"longueur_max": longueur_max, "totale": totale / float(sol.size())}
	releves[cle] = releve
	return releve


func _moitie(i: int, r: Dictionary, sol: Array[Vector2i], poids: Dictionary) -> float:
	var s := 0.0
	var cache := 0.0
	for c in sol:
		var w: float = (poids[c] as Vector2)[i]
		s += w
		cache += w * float(r["parts"][c])
	return cache / s if s > 0.0 else 0.0


func _apparition(s: Vector2i, r: Dictionary, sol: Array[Vector2i]) -> float:
	var n := 0
	var cache := 0.0
	for c in sol:
		if Vector2(c).distance_to(Vector2(s)) <= RAYON_APPARITION:
			n += 1
			cache += float(r["parts"][c])
	return cache / float(n) if n > 0 else 0.0


## La preuve que le portage n'a rien perdu (session cloud, 2026-09-24, 05:00) : les mêmes grandeurs, écrites par le
## prototype Python (`docs/iso/iso14/proto_equite.py`) dans `reference_prototype.json`, comparées une à une. Imprime
## l'écart maximal des parts (fractions) et des longueurs, et si les comptes (cases invisibles, corps cachés) sont
## identiques. Échec au-delà de 1e-4 sur une part ou d'une unité sur un compte : les deux calculs ne seraient plus le
## même (les vecteurs de Godot sont en simple précision, d'où la tolérance plutôt que l'égalité).
const REFERENCE_PROTOTYPE := "res://docs/iso/iso14/reference_prototype.json"
var _reference: Variant = null

func _comparer_au_prototype(slug: String, mesures: Dictionary) -> void:
	if _reference == null:
		var f := FileAccess.open(REFERENCE_PROTOTYPE, FileAccess.READ)
		_reference = JSON.parse_string(f.get_as_text()) if f != null else {}
		if _reference == null:
			_reference = {}
	var ref: Dictionary = (_reference as Dictionary).get(slug, {})
	if ref.is_empty():
		print("  prototype : aucune référence pour %s" % slug)
		return
	var ecart_part := 0.0
	var ecart_px := 0.0
	var comptes := 0
	var n := 0
	for cle: String in mesures:
		var a: Dictionary = mesures[cle]
		var b: Dictionary = ref.get(cle, {})
		for champ: String in a:
			if not b.has(champ):
				continue
			n += 1
			if champ.begins_with("invisibles") or champ.begins_with("corps"):
				comptes += absi(int(a[champ]) - int(b[champ]))
			elif champ.begins_with("longueur"):
				ecart_px = maxf(ecart_px, absf(float(a[champ]) - float(b[champ])))
			else:
				ecart_part = maxf(ecart_part, absf(float(a[champ]) - float(b[champ])))
	# LES VERDICTS, recalculés des deux côtés par la même règle (`_verdict_de`), sur les grandeurs du banc et sur
	# celles du prototype : un seul qui diffère fait échouer, quel que soit l'écart des parts.
	var verdicts_differents: PackedStringArray = []
	var ecart_0a_banc := absf(float(mesures.get("0A", {}).get("moitie_j1", 0.0)) - float(mesures.get("0A", {}).get("moitie_j2", 0.0))) * 100.0
	var ecart_0a_proto := absf(float(ref.get("0A", {}).get("moitie_j1", 0.0)) - float(ref.get("0A", {}).get("moitie_j2", 0.0))) * 100.0
	for cle: String in mesures:
		if not ref.has(cle):
			continue
		var v_banc := _verdict_de(mesures[cle], ecart_0a_banc)
		var v_proto := _verdict_de(ref[cle], ecart_0a_proto)
		if v_banc != v_proto:
			verdicts_differents.append("%s : banc %s, prototype %s" % [cle, v_banc, v_proto])
	# ⚠️ SEUIL DES PARTS À 1e-3 (0,1 point), et non plus 1e-4 — accordé par la session cloud (2026-09-24, 13:00) à une
	# condition DURE : un verdict ou un compte qui diffère fait échouer quel que soit l'écart des parts. Pourquoi 1e-4 ne
	# tenait pas : la seconde chaîne (12:49) a trouvé 2,5e-4 à 4,8e-4 sur cinq cartes, verdicts et comptes identiques —
	# des points p en simple précision (`Vector2`) posés sur un bord de case, caché d'un côté, visible de l'autre.
	var tenu := n > 0 and ecart_part <= 1e-3 and ecart_px <= 1e-3 and comptes == 0 and verdicts_differents.is_empty()
	# `%e` n'existe pas dans le formatage de GDScript (« unsupported format character », la première chaîne) :
	# `String.num_scientific`.
	print("  prototype : %s — %d grandeurs, écart max %s sur les parts, %s px sur les longueurs, comptes %s, verdicts %s"
		% ["MÊME CALCUL" if tenu else "ÉCART", n, String.num_scientific(ecart_part), String.num_scientific(ecart_px),
		"identiques" if comptes == 0 else "DIFFÉRENTS (%d)" % comptes,
		"identiques" if verdicts_differents.is_empty() else "DIFFÉRENTS : " + " ; ".join(verdicts_differents)])
	if not tenu:
		_echecs += 1


## Le verdict d'une option, depuis ses grandeurs (celles du banc ou celles du prototype) : la MÊME règle que celle
## imprimée par `_carte`, pour que la comparaison au prototype porte aussi sur les verdicts. `ecart_0a` : l'écart des
## moitiés à 0° en option A, en points, de la même source.
static func _verdict_de(g: Dictionary, ecart_0a: float) -> String:
	var ok0: bool = int(g.get("invisibles_j1", 0)) == 0 and int(g.get("invisibles_j2", 0)) == 0 \
		and int(g.get("corps_j1", 0)) == 0 and int(g.get("corps_j2", 0)) == 0
	var ecart := absf(float(g.get("moitie_j1", 0.0)) - float(g.get("moitie_j2", 0.0))) * 100.0
	var oka := ecart <= 1.0 and ecart <= ecart_0a + 0.5
	var okb := absf(float(g.get("apparition_j1", 0.0)) - float(g.get("apparition_j2", 0.0))) * 100.0 <= 1.0
	var oke := absf(float(g.get("abri_j1", 0.0)) - float(g.get("abri_j2", 0.0))) * 100.0 <= 1.0
	var rates: PackedStringArray = []
	for paire in [["0", ok0], ["a", oka], ["b", okb], ["e", oke]]:
		if not paire[1]:
			rates.append(paire[0])
	return "ÉQUITABLE" if rates.is_empty() else "NON (%s)" % ",".join(rates)


## La garde (4) : à 0°, option A, le calcul général rend `analyser_equite` (même caméra pour les deux moitiés).
func _garde(data: Dictionary, r0: Dictionary, m: Vector2) -> void:
	var ref: Dictionary = Geo.analyser_equite(data, Geo.hauteur_mur_haut(), TANGAGE)
	# 1e-6 et non 1e-9 : les `Vector2` de Godot sont en simple précision (première chaîne, 2026-09-24 12:38 — mêmes
	# chiffres à quatre décimales, « ÉCHEC » à 1e-9). Une vraie divergence se compte en points, pas en millionièmes.
	var ecart := maxf(absf(float(ref["part_sol"]) - float(r0["totale"])),
		maxf(absf(float(ref["part_j1"]) - m.x), absf(float(ref["part_j2"]) - m.y)))
	var ok := ecart < 1e-6 \
		and int(ref["cases_invisibles"]) == int(r0["invisibles"])
	print("  garde (4), 0° : %s — analyser_equite %.4f / %.4f / %.4f, calcul général %.4f / %.4f / %.4f (écart max %s)"
		% ["tenue" if ok else "ÉCHEC", ref["part_sol"], ref["part_j1"], ref["part_j2"], r0["totale"], m.x, m.y,
		String.num_scientific(ecart)])
	if not ok:
		_echecs += 1


## « Par construction » se vérifie : pour chaque symétrie de la grille, échange-t-elle les apparitions, et combien
## de murs n'ont pas de mur pour image.
func _symetries(grille: Vector2i, murs: Dictionary, s1: Vector2i, s2: Vector2i) -> void:
	var w := grille.x
	var h := grille.y
	var transformations := {
		"centrale": func(c: Vector2i) -> Vector2i: return Vector2i(w - 1 - c.x, h - 1 - c.y),
		"miroir gauche-droite": func(c: Vector2i) -> Vector2i: return Vector2i(w - 1 - c.x, c.y),
		"miroir haut-bas": func(c: Vector2i) -> Vector2i: return Vector2i(c.x, h - 1 - c.y),
	}
	if w == h:
		transformations["diagonale"] = func(c: Vector2i) -> Vector2i: return Vector2i(c.y, c.x)
		transformations["anti-diagonale"] = func(c: Vector2i) -> Vector2i: return Vector2i(h - 1 - c.y, w - 1 - c.x)
	for nom: String in transformations:
		var f: Callable = transformations[nom]
		var echange: bool = f.call(s1) == s2 and f.call(s2) == s1
		var hors := 0
		for c: Vector2i in murs:
			if not murs.has(f.call(c)):
				hors += 1
		print("  symétrie %-22s échange les apparitions : %-3s  murs hors symétrie : %d"
			% [nom, "oui" if echange else "non", hors])


## (0), la question de la session cloud (2026-09-24, 04:47) : un corps collé à un mur haut peut-il disparaître
## EN ENTIER sur l'écran de l'adversaire, DEBOUT ou ACCROUPI ?
##
## ⚠️ **Le préalable des cartes (plus haut) juge le DISQUE AU SOL de la zone de touche** — 18 px de RAYON (le corps de
## `player.tscn`), donc 36 de diamètre contre une bande de 34,2 : il ne peut jamais y tenir en entier derrière une face,
## d'où le zéro. Il ne dit rien du corps en hauteur. Ici, le vrai corps voxel posé (`voxel_corps.gd`, les dix classes,
## seize visées), collé à une face de mur infinie — son centre à la distance que la collision impose (le disque de
## 18 px, ou la pointe du canon à 28 px quand il vise le mur) —, et la caméra de l'adversaire derrière le mur, de face
## (0°) ou de biais (45° par rapport à la normale de la face). Un point à la hauteur z, à une distance horizontale s de
## la face sur le rayon de la caméra, est caché si `z + s × tan θ < H` ; une boîte est cachée si ses huit coins le
## sont (la région cachée est un demi-espace). Imprime le nombre de poses entièrement cachées et, pour la pose la mieux
## cachée, de combien de pixels son point le plus visible dépasse la ligne de crête du mur (négatif = caché).
func _corps_colle() -> void:
	var VoxelCorps: GDScript = load("res://voxel_corps.gd")
	var h_mur: float = Geo.hauteur_mur_haut() * _tuile
	var tan_t := tan(deg_to_rad(TANGAGE))
	print("\n=== (0) UN CORPS COLLÉ À UN MUR HAUT, EN HAUTEUR — voxel posé, dix classes, seize visées ===")
	for accroupi: bool in [false, true]:
		for biais_deg: float in [0.0, 45.0]:
			var caches := 0
			var poses := 0
			var meilleur := INF
			var meilleur_texte := ""
			for slug in VoxelCatalogue.slugs():
				var corps: Node3D = VoxelCorps.new()
				root.add_child(corps)
				if not corps.construire(slug):
					printerr("✗ corps %s non construit" % slug)
					_echecs += 1
					root.remove_child(corps)
					corps.free()
					continue
				for k in 16:
					var phi := float(k) * TAU / 16.0
					var visee := Vector2(cos(phi), sin(phi))
					corps.poser({"position": Vector2.ZERO, "visee": visee, "vitesse": Vector2.ZERO, "torche": true,
						"arme": slug, "tir": false, "touche": false, "mort": false, "accroupi": accroupi,
						"enjambe": 0.0, "t": 1.0})
					# La face du mur au sud (+z), la caméra de l'adversaire derrière elle ; le centre du corps à la
					# distance que la collision impose : le disque de 18 px, ou la pointe à 28 px quand il vise le mur.
					var face := maxf(18.0, 28.0 * visee.y)
					var depasse := -INF
					for m in _maillages_visibles(corps):
						var aabb := m.get_aabb()
						for i in 8:
							var coin: Vector3 = (m.global_transform * aabb.get_endpoint(i)) * _tuile
							var s := (face - coin.z) / cos(deg_to_rad(biais_deg))
							depasse = maxf(depasse, coin.y + s * tan_t - h_mur)
					poses += 1
					if depasse <= 0.0:
						caches += 1
					if depasse < meilleur:
						meilleur = depasse
						meilleur_texte = "%s, visée %d°" % [slug, int(rad_to_deg(phi))]
				root.remove_child(corps)
				corps.free()
			print("CORPS_COLLE | %-8s | caméra %2d° de la normale | %3d / %d poses entièrement cachées | la mieux cachée (%s) dépasse de %+.1f px"
				% ["ACCROUPI" if accroupi else "DEBOUT", int(biais_deg), caches, poses, meilleur_texte, meilleur])


func _maillages_visibles(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for enfant in n.get_children():
		if enfant is MeshInstance3D and (enfant as MeshInstance3D).is_visible_in_tree() \
				and (enfant as MeshInstance3D).mesh != null:
			out.append(enfant)
		out.append_array(_maillages_visibles(enfant))
	return out
