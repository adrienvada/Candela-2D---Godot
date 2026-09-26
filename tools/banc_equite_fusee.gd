## LE BANC D'ÉQUITÉ DE LA FUSÉE — Q35 = B (Adrien, 2026-09-26), le rouge long à 4 s contre le défaut à 2 s, À DURÉE TOTALE
## ÉGALE (ordre 412 : la braise perd les 2 s que le plein feu gagne ; `FuseeModele.poser_rouge_long`). La première lecture (la
## braise gardée, la fusée vivant 22 s) a échoué ici le 2026-09-26 sur l'aire cachée × temps, +155,18 pour une borne de
## 131,31 : la fumée gonfle sur toute la vie, les 2 s de plus se vivaient plus larges. Chiffres dans la ROADMAP.
##
##   godot --headless --path . --script res://tools/banc_equite_fusee.gd
##
## Headless, sur le MODÈLE PUR (`FuseeModele`, `Eblouissement`, le masque de sa lumière) : ce que la fusée éclaire et ce
## qu'elle cache, et combien de temps, pour les deux joueurs. Sort 0 si le verdict passe, 1 sinon.
##
## LE VERDICT, fixé par la session cloud AVANT les chiffres (ordre 410, 26/09 21:46) :
##  (a) symétrie exacte : à distances égales, le lanceur et l'adversaire ont les mêmes valeurs, ligne par ligne ;
##  (b) le rouge long n'ajoute que ses deux secondes : chaque durée change au plus de 2 s ; chaque aire × temps change au
##      plus de ce que donnent 2 s de plein feu de plus (la lumière : 2 s × l'aire éclairée au plein feu ; la fumée : 2 s ×
##      l'aire cachée par la fumée pleine), calculé à part sur le modèle.
##
## LES MESURES, et ce qu'elles supposent (déclaré, à juger avec les chiffres) :
##  (i) LA LUMIÈRE reçue à la distance d : énergie × masque de la lumière (`LightTextures.RETRODIFFUSION`, trois paliers
##      d'alpha, 440 px d'empreinte comme `fusee.gd`) × luminance de sa couleur (rouge de détresse → ambre, selon la
##      température) ; LISIBLE si elle atteint 0,10, le seuil d'apparition de Q32. Durées à 100, 200 et 300 px ; aire
##      éclairée × temps.
##  (ii) LA FUMÉE : l'occultation de `fusee.gd` (`occultation_pour` : opacité × (1 − smoothstep(0,55 ; 1 ; d / rayon))) ;
##      CACHÉ si elle atteint 0,5. Durées au centre, à 100 et à 150 px ; aire cachée × temps.
##  (iii) LES DEUX JOUEURS : le lanceur et l'adversaire, placés à la même distance de part et d'autre de la fusée.
##  (iv) L'ÉBLOUISSEMENT : la valeur intégrée (`Eblouissement.integrer`) de la source de proximité de `game_state.gd`
##      (rayon 400, gain = énergie relative) ; aucune constante de palier dans le jeu, donc trois BANDES déclarées ici
##      (0,25, 0,5, 0,75) ; durées au-dessus de chacune, à 100, 200 et 300 px.
## CE QU'IL NE MESURE PAS : les murs, les lignes de vue et le choix de la position — le modèle pur n'en a pas. Une
## asymétrie de jeu viendrait de là, pas de la fusée.
extends SceneTree

const Modele := preload("res://fusee_modele.gd")
const Ebl := preload("res://eblouissement.gd")
const Ch := preload("res://charte.gd")

const DT := 1.0 / 120.0
const SEUIL_LISIBLE := 0.10          # Q32 : l'apparition des dix classes
const SEUIL_CACHE := 0.5
const BANDES := [0.25, 0.5, 0.75]
const RAYON_EBLOUISSEMENT := 400.0   # `GameState.RAYON_EBLOUISSEMENT_FUSEE`
const EMPREINTE_LUMIERE := 440.0     # `fusee.gd`
const GRAINE := 4242                 # les mêmes sursauts d'agonie pour les deux variantes
const TUILE2 := 35.0 * 35.0
const DISTANCES_LUMIERE := [100.0, 200.0, 300.0]
const DISTANCES_FUMEE := [0.0, 100.0, 150.0]
const DISTANCES_EBLOUISSEMENT := [100.0, 200.0, 300.0]

var _alpha: PackedFloat32Array = []  # le profil radial du masque, 0 → 1 (rayon)
var _echec := false


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/halo/retrodiffusion_corona.png"))
	if img == null or img.is_empty():
		printerr("✗ masque de la lumière illisible")
		quit(1)
		return
	var w := img.get_width()
	var cy := img.get_height() / 2
	for x in range(w / 2, w):
		_alpha.append(img.get_pixel(x, cy).a)
	var avant := Modele.duree_plein_feu > Modele.DUREE_PLEIN_FEU
	Modele.poser_rouge_long(false)
	var defaut := _mesurer()
	Modele.poser_rouge_long(true)
	var long := _mesurer()
	Modele.poser_rouge_long(avant)
	_rapport(defaut, long)
	quit(1 if _echec else 0)


func _masque(d: float) -> float:
	var r := d / (EMPREINTE_LUMIERE * 0.5)
	if r >= 1.0:
		return 0.0
	return _alpha[mini(int(r * _alpha.size()), _alpha.size() - 1)]


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## La lumière reçue à `d` à l'âge `t` (voir l'en-tête).
func _lumiere(d: float, e: float, t: float) -> float:
	var couleur := Color(0.96, 0.293, 0.334).lerp(Ch.AMBRE, Modele.temperature_a(t))  # `fusee.gd`, COULEUR_DETRESSE
	return e * _masque(d) * _lum(couleur)


func _occultation(d: float, t: float) -> float:
	var a := Modele.alpha_fumee_a(t)
	var r := Modele.RAYON_FUMEE * Modele.echelle_fumee_a(t)
	if a <= 0.0 or d >= r:
		return 0.0
	return a * (1.0 - smoothstep(0.55, 1.0, d / r))


## Une variante : les durées et les aires × temps, pour un observateur à la distance d, d'un côté puis de l'autre.
func _mesurer() -> Dictionary:
	var fen := Modele.fenetres_agonie(GRAINE)
	var fin := Modele.duree_combustion()
	var m := {"vie": fin}
	for cote in ["lanceur", "adversaire"]:
		var signe := -1.0 if cote == "lanceur" else 1.0
		# Toutes les lignes, même celles qui restent à zéro : le tableau entier (ordre 410).
		for d in DISTANCES_LUMIERE:
			m["%s lisible à %d px (s)" % [cote, int(d)]] = 0.0
		for d in DISTANCES_FUMEE:
			m["%s caché à %d px (s)" % [cote, int(d)]] = 0.0
		for d in DISTANCES_EBLOUISSEMENT:
			for b in BANDES:
				m["%s ébloui ≥ %.2f à %d px (s)" % [cote, b, int(d)]] = 0.0
		var ebl := {}
		for d in DISTANCES_EBLOUISSEMENT:
			ebl[d] = 0.0
		var t := 0.0
		while t < fin:
			var e := Modele.energie_a(t, fen)
			var rel := clampf(e / Modele.ENERGIE_PLEIN_FEU, 0.0, 1.0) if e > 0.005 else 0.0
			for d in DISTANCES_LUMIERE:
				# La position : de part et d'autre de la fusée ; le modèle ne dépend que de la distance (symétrie à prouver).
				var dd := Vector2(signe * d, 0.0).length()
				if _lumiere(dd, e, t) >= SEUIL_LISIBLE:
					m["%s lisible à %d px (s)" % [cote, int(d)]] = m.get("%s lisible à %d px (s)" % [cote, int(d)], 0.0) + DT
			for d in DISTANCES_FUMEE:
				var dd := Vector2(signe * d, 0.0).length()
				if _occultation(dd, t) >= SEUIL_CACHE:
					m["%s caché à %d px (s)" % [cote, int(d)]] = m.get("%s caché à %d px (s)" % [cote, int(d)], 0.0) + DT
			for d in DISTANCES_EBLOUISSEMENT:
				var dd := Vector2(signe * d, 0.0).length()
				var plafond := Ebl.plafond_pour(Ebl.intensite_proximite(dd, RAYON_EBLOUISSEMENT)) \
					* Ebl.gain_taille(RAYON_EBLOUISSEMENT) * rel
				ebl[d] = Ebl.integrer(ebl[d], plafond, DT)
				for b in BANDES:
					if ebl[d] >= b:
						var k := "%s ébloui ≥ %.2f à %d px (s)" % [cote, b, int(d)]
						m[k] = m.get(k, 0.0) + DT
			t += DT
	# Les aires × temps ne dépendent pas du côté : une seule ligne chacune.
	var t2 := 0.0
	var aire_lum := 0.0
	var aire_fum := 0.0
	while t2 < fin:
		var e := Modele.energie_a(t2, fen)
		aire_lum += _aire_lumiere(e, t2) * DT
		aire_fum += _aire_cachee(t2) * DT
		t2 += DT
	m["aire éclairée × temps (tuiles²·s)"] = aire_lum / TUILE2
	m["aire cachée × temps (tuiles²·s)"] = aire_fum / TUILE2
	return m


func _aire_lumiere(e: float, t: float) -> float:
	var r := 0.0
	var d := 0.0
	while d < EMPREINTE_LUMIERE * 0.5:
		if _lumiere(d, e, t) >= SEUIL_LISIBLE:
			r = d
		d += 1.0
	return PI * r * r


func _aire_cachee(t: float) -> float:
	var r := 0.0
	var d := 0.0
	var lim := Modele.RAYON_FUMEE * Modele.FUMEE_GONFLE
	while d < lim:
		if _occultation(d, t) >= SEUIL_CACHE:
			r = d
		d += 1.0
	return PI * r * r


func _rapport(a: Dictionary, b: Dictionary) -> void:
	# Les bornes de (b), calculées à part : 2 s de plein feu de plus.
	var borne_lum := 2.0 * _aire_lumiere(Modele.ENERGIE_PLEIN_FEU, 0.0) / TUILE2
	var borne_fum := 2.0 * _aire_cachee(Modele.FUMEE_MONTEE + 0.001) / TUILE2
	var borne_duree := 2.0 + 2.0 * DT
	print("\n[Le banc d'équité de la fusée — défaut (plein feu 2 s) contre rouge long (4 s, la braise 2 s plus courte)]")
	print("vie de la fusée : %.2f s contre %.2f s" % [a["vie"], b["vie"]])
	print("bornes de (b) : durée ≤ %.2f s ; aire éclairée ≤ %.2f tuiles²·s ; aire cachée ≤ %.2f tuiles²·s" % [borne_duree, borne_lum, borne_fum])
	# Pour information, pas pour le verdict : la fumée gonfle sur toute la vie (`echelle_fumee_a` rapporte l'âge à la durée
	# de combustion), si bien que 2 s de plus se vivent avec une fumée plus large que celle de 3 s. La même borne à sa taille
	# la plus grande (× FUMEE_GONFLE) :
	var r_max := 0.0
	var d_max := 0.0
	while d_max < Modele.RAYON_FUMEE:
		if 1.0 - smoothstep(0.55, 1.0, d_max / Modele.RAYON_FUMEE) >= SEUIL_CACHE:
			r_max = d_max
		d_max += 1.0
	print("(pour information) la même borne, fumée à sa taille la plus grande : %.2f tuiles²·s"
		% [2.0 * PI * pow(r_max * Modele.FUMEE_GONFLE, 2.0) / TUILE2])
	var cles: Array = []
	for k in a.keys() + b.keys():
		if k != "vie" and not cles.has(k):
			cles.append(k)
	cles.sort()
	print("%-52s %10s %10s %10s  %s" % ["mesure", "défaut", "rouge long", "écart", "(b)"])
	for k: String in cles:
		var va: float = a.get(k, 0.0)
		var vb: float = b.get(k, 0.0)
		var borne := borne_lum if k.begins_with("aire éclairée") else (borne_fum if k.begins_with("aire cachée") else borne_duree)
		var ok := absf(vb - va) <= borne + 1e-6
		if not ok:
			_echec = true
		print("%-52s %10.2f %10.2f %+10.2f  %s" % [k, va, vb, vb - va, "✓" if ok else "✗ au-delà de %.2f" % borne])
	# (a) la symétrie : chaque ligne du lanceur égale celle de l'adversaire, dans les deux variantes.
	var asym := 0
	for m: Dictionary in [a, b]:
		for k: String in m.keys():
			if k.begins_with("lanceur"):
				var j := "adversaire" + k.substr(7)
				if absf(float(m[k]) - float(m.get(j, 0.0))) > 1e-9:
					asym += 1
					print("✗ asymétrie : %s = %.3f, %s = %.3f" % [k, m[k], j, m.get(j, 0.0)])
	if asym > 0:
		_echec = true
	print("(a) symétrie exacte, lanceur contre adversaire : %s" % ("TIENT" if asym == 0 else "ÉCHOUE (%d lignes)" % asym))
	print("VERDICT : %s" % ("PASSE" if not _echec else "ÉCHOUE"))
