extends SceneTree

## Q58 (Adrien, 2026-10-01 vers 09:10 : « Q58 : il faudrait qu'à l'allumage la fusée illumine loin effectivement ») — À
## L'ALLUMAGE, LE HALO DE LA FUSÉE PORTE AUSSI LOIN QUE LES TORCHES, puis revient à son empreinte habituelle avant la braise.
##
## Ce que cette garde tient (headless, sans pixel ; l'image se prouve sous Xvfb, `tools/banc_lumieres.gd --plans=q58`) :
## - LA COURBE (`FuseeModele.part_allumage_a`, `rayon_halo_a`), relue ici contre ses propres nombres, jamais contre la
##   fonction : 0 en vol ; 1 de l'atterrissage au quart du plein feu ; un `smoothstep` jusqu'aux trois quarts ; 0 ensuite —
##   rouge long (4 s : 1 s tenue, retour à 3 s) et plein feu de 2 s ; continue après l'allumage, jamais croissante ; le halo
##   jamais au-delà de la portée d'allumage, jamais sous son empreinte habituelle, et l'empreinte habituelle à tout âge quand
##   l'allumage est éteint ;
## - LA RÈGLE (`GameSettings.rayon_allumage_fusee`, `fusee_allumage_du_duel`) : la portée des torches au bord le plus proche
##   (468 px à ×1,5, `PorteeEcran.portee_au_bord`), la même en ligne quoi que dise la machine ; `--sans-fusee-allumage` en
##   débogage seulement, et jamais en ligne ; posée au démarrage (`accorder_au_mode`) ;
## - EN JEU, une vraie fusée de match qui vole, rebondit et se pose : en vol, l'empreinte du vol ; posée, l'empreinte de
##   l'allumage dès la première image, puis la courbe à chaque âge ; l'énergie, la couleur et `energie_relative` (ce que lit
##   l'éblouissement) les mêmes qu'avec l'allumage éteint ; les ombres (murs et murets) et les masques de portée (les deux
##   vues : J1 = J2) inchangés ; et le masque de la lumière s'éteint avant le bord de son empreinte (rien au-delà du rayon) ;
## - LA KILLCAM, par son chemin (`_maj_fusees_killcam`) : à chaque âge, la même empreinte qu'en match ; en vol, celle du vol.
##
## ⚠️ `fusee.gd` nomme des autoloads : cette garde ne nomme JAMAIS la classe dans son code (voir `test_fusee_killcam.gd`).
##
## Lancer : godot --headless --path . --script res://tools/test_fusee_allumage.gd

const Modele := preload("res://fusee_modele.gd")
const Reglages := preload("res://settings_manager.gd")

const GRAINE := 5858
## La portée des torches à ×1,5 (`test_portee_ecran`) : la portée d'allumage attendue.
const PORTEE_TORCHES := 468.0
## Les âges où l'on compare (secondes de combustion) : l'allumage, la tenue, la descente, le retour, la braise, l'agonie, le
## résidu.
const AGES := [0.0, 0.25, 0.5, 0.99, 1.25, 1.5, 2.0, 2.5, 2.9, 3.0, 3.5, 4.0, 6.0, 12.5, 16.0]
## Le pas de la continuité (une image à 120 i/s) et le saut le plus grand toléré d'une image à l'autre, en part du rayon.
const PAS := 1.0 / 120.0
const SAUT_MAX := 0.02

var _failures := 0
var _verifications := 0
var _vol := 0.0
var _sol := 0.0


class Instantane:
	var fusees: Array = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


## La part attendue, écrite ici à la main (jamais tirée de `part_allumage_a`) : 1 jusqu'au quart du plein feu, un
## smoothstep jusqu'aux trois quarts, 0 ensuite ; 0 en vol.
static func _part_attendue(age: float, plein_feu: float) -> float:
	if age < 0.0:
		return 0.0
	var a := 0.25 * plein_feu
	var b := 0.75 * plein_feu
	if age <= a:
		return 1.0
	if age >= b:
		return 0.0
	var t := (age - a) / (b - a)
	return 1.0 - t * t * (3.0 - 2.0 * t)


func _run() -> void:
	print("=== Q58 : À L'ALLUMAGE, LA FUSÉE ILLUMINE LOIN ===")
	await process_frame
	_courbe()
	_regle()
	await _en_jeu()


func _courbe() -> void:
	print("\n--- La courbe (le modèle pur) ---")
	var long_avant := Modele.duree_plein_feu > Modele.DUREE_PLEIN_FEU
	var rayon_avant: float = Modele.rayon_allumage
	for long in [true, false]:
		Modele.poser_rouge_long(long)
		var p := Modele.duree_plein_feu
		var nom := "plein feu de %.0f s" % p
		var ecart_max := 0.0
		var saut_max := 0.0
		var croissante := false
		var age := -0.5
		var age_precedent := -1.0
		var precedente := Modele.part_allumage_a(-0.5)
		while age < Modele.duree_combustion():
			var part := Modele.part_allumage_a(age)
			ecart_max = maxf(ecart_max, absf(part - _part_attendue(age, p)))
			# Après l'allumage seulement : le saut de 0 à 1 À l'atterrissage EST l'allumage.
			if age_precedent >= 0.0:
				saut_max = maxf(saut_max, absf(part - precedente))
				croissante = croissante or part > precedente + 1e-6
			precedente = part
			age_precedent = age
			age += PAS
		_check("%s : la part suit la courbe écrite (0 en vol, 1 jusqu'à %.1f s, retour fini à %.1f s, avant la braise à %.0f s) "
			% [nom, 0.25 * p, 0.75 * p, p] + "— écart %.6f" % ecart_max, ecart_max < 1e-4)
		_check("%s : continue après l'allumage (saut %.4f par image au plus) et jamais croissante" % [nom, saut_max],
			saut_max < SAUT_MAX and not croissante)
		_check("%s : 0 en vol, 1 à l'atterrissage (l'allumage)" % nom,
			Modele.part_allumage_a(-0.01) == 0.0 and Modele.part_allumage_a(0.0) == 1.0)
		_check("%s : plus rien dès le dernier quart du plein feu, ni dans la braise, l'agonie ou le résidu" % nom,
			Modele.part_allumage_a(0.75 * p) == 0.0 and Modele.part_allumage_a(p) == 0.0
			and Modele.part_allumage_a(p + Modele.duree_braise + 1.0) == 0.0
			and Modele.part_allumage_a(Modele.duree_combustion() - 0.1) == 0.0)
	Modele.poser_rouge_long(long_avant)
	# Le rayon du halo : entre l'empreinte habituelle et la portée d'allumage, jamais hors.
	var pose := 220.0
	Modele.rayon_allumage = PORTEE_TORCHES
	var hors := false
	var age := 0.0
	while age < Modele.duree_combustion():
		var r := Modele.rayon_halo_a(age, pose)
		hors = hors or r > PORTEE_TORCHES + 1e-3 or r < pose - 1e-3
		age += PAS
	_check("le halo reste entre son empreinte habituelle (%.0f px) et la portée d'allumage (%.0f px), à tout âge"
		% [pose, PORTEE_TORCHES], not hors)
	_check("à l'allumage %.1f px, à 1 s %.1f px, à 3 s %.1f px (l'empreinte habituelle)" % [Modele.rayon_halo_a(0.0, pose),
		Modele.rayon_halo_a(1.0, pose), Modele.rayon_halo_a(3.0, pose)],
		is_equal_approx(Modele.rayon_halo_a(0.0, pose), PORTEE_TORCHES)
		and is_equal_approx(Modele.rayon_halo_a(1.0, pose), PORTEE_TORCHES)
		and is_equal_approx(Modele.rayon_halo_a(3.0, pose), pose))
	Modele.rayon_allumage = 0.0
	_check("allumage éteint (rayon 0) : l'empreinte habituelle à tout âge, l'allumage compris",
		is_equal_approx(Modele.rayon_halo_a(0.0, pose), pose) and is_equal_approx(Modele.rayon_halo_a(1.5, pose), pose))
	Modele.rayon_allumage = 100.0
	_check("un allumage plus court que le halo ne le rapetisse pas", is_equal_approx(Modele.rayon_halo_a(0.0, pose), pose))
	Modele.rayon_allumage = rayon_avant


func _regle() -> void:
	print("\n--- La règle (GameSettings) ---")
	var attendu := PorteeEcran.portee_au_bord(PorteeEcran.VUE_UNIQUE, 1.5, 0.15, CameraIso.TANGAGE_DEG)
	var r := Reglages.rayon_allumage_fusee(true, 1.5, 0.15)
	_check("la portée d'allumage est celle des torches, au bord le plus proche de la vue unique (%.1f px)" % r,
		is_equal_approx(r, attendu) and absf(r - PORTEE_TORCHES) < 0.05)
	_check("éteint : 0 (l'empreinte habituelle)", Reglages.rayon_allumage_fusee(false, 1.5, 0.15) == 0.0)
	_check("en ligne, toujours — quoi que dise la machine ; hors ligne, le choix local",
		Reglages.fusee_allumage_du_duel(true, false) and Reglages.fusee_allumage_du_duel(true, true)
		and Reglages.fusee_allumage_du_duel(false, true) and not Reglages.fusee_allumage_du_duel(false, false))
	var reglages := root.get_node("GameSettings")
	_check("allumé par défaut", bool(reglages.get("_fusee_allumage_locale")))
	var source := FileAccess.get_file_as_string("res://settings_manager.gd")
	_check("--sans-fusee-allumage ne vaut qu'en build de débogage",
		source.contains("OS.is_debug_build() and _arguments().has(DRAPEAU_SANS_FUSEE_ALLUMAGE)"))
	_check("posée au démarrage : la fusée du jeu porte à %.1f px à l'allumage" % float(Modele.rayon_allumage),
		absf(float(Modele.rayon_allumage) - PORTEE_TORCHES) < 0.05)


func _en_jeu() -> void:
	print("\n--- En jeu : une vraie fusée de match, puis la killcam ---")
	var Script: GDScript = load("res://fusee.gd")
	var constantes := Script.get_script_constant_map()
	_vol = float(constantes["EMPREINTE_VOL"])
	_sol = float(constantes["EMPREINTE_LUMIERE"])
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var reseau := root.get_node("NetworkManager")
	main.ui._intended_mode = int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
	main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(main))
	for j in [main.p1, main.p2]:
		(j as Node).set_physics_process(false)
	var reglages := root.get_node("GameSettings")
	# En ligne : l'allumage vaut, même si la machine l'a éteint ; hors ligne, il suit la machine. Puis l'état d'avant.
	reglages.set("_fusee_allumage_locale", false)
	reglages.accorder_au_mode(true)
	var en_ligne: float = Modele.rayon_allumage
	reglages.accorder_au_mode(false, true)
	var hors_ligne_eteint: float = Modele.rayon_allumage
	reglages.set("_fusee_allumage_locale", true)
	reglages.accorder_au_mode(false, true)
	_check("en ligne la fusée s'allume loin même si la machine l'a éteint (%.1f px) ; hors ligne, éteint : %.1f"
		% [en_ligne, hors_ligne_eteint], absf(en_ligne - PORTEE_TORCHES) < 0.05 and hors_ligne_eteint == 0.0)
	_check("rétabli : %.1f px en écran scindé (la portée de la vue unique)" % float(Modele.rayon_allumage),
		absf(float(Modele.rayon_allumage) - PORTEE_TORCHES) < 0.05)

	# Une vraie fusée de match, lancée au centre de la carte.
	var centre: Vector2 = main._carte_px.get_center()
	var f: Node2D = Script.new()
	f.set("depart", centre)
	f.set("direction", Vector2.RIGHT)
	f.set("graine", GRAINE)
	f.set("shooter_id", 1)
	f.set("joueurs", [main.p1, main.p2])
	f.name = "FuseeDeMatch"
	main.bullet_container.add_child(f)
	var lumiere := f.get_node("Halo") as PointLight2D
	await physics_frame
	_check("en vol, l'empreinte du vol (%.0f px) : l'allumage n'y touche pas" % _vol,
		is_equal_approx(_empreinte(lumiere), _vol), str(_empreinte(lumiere)))
	var fin := Time.get_ticks_msec() + 15000
	while not bool(f.call("est_allumee_au_sol")) and Time.get_ticks_msec() < fin:
		await physics_frame
	_check("la fusée de match vole, rebondit et se pose", bool(f.call("est_allumee_au_sol")))
	var age0 := float(f.call("age_combustion"))
	var e0 := _empreinte(lumiere)
	_check("posée, dès sa première image (âge %.3f s) : l'empreinte de l'allumage, %.1f px (la portée des torches × 2)"
		% [age0, e0], absf(e0 - 2.0 * PORTEE_TORCHES) < 0.5, str(e0))
	# Le vrai chemin du match (`_physics_process`), dans la descente : l'empreinte de son âge.
	while float(f.call("age_combustion")) < 1.6 and Time.get_ticks_msec() < fin + 5000:
		await physics_frame
	var age_d := float(f.call("age_combustion"))
	var e_d := _empreinte(lumiere)
	var attendue_d := 2.0 * _rayon_attendu(age_d)
	_check("au fil du match, dans la descente (âge %.3f s) : %.1f px, la courbe dit %.1f" % [age_d, e_d, attendue_d],
		absf(e_d - attendue_d) < 0.5)
	_check("pendant l'allumage, les ombres (murs et murets) et les masques de portée ne bougent pas (J1 = J2 : les deux vues)",
		lumiere.shadow_enabled and lumiere.shadow_item_cull_mask == int(Script.call("masque_ombre", true))
		and lumiere.range_item_cull_mask == (1 | 2 | 4))
	f.set_physics_process(false)
	var lieu := f.global_position

	# À chaque âge : le match (`forcer_age`, le chemin des bancs) et la killcam (`_maj_fusees_killcam`) contre la courbe.
	var ecart_match := 0.0
	var ecart_killcam := 0.0
	var detail := ""
	var energie_ok := true
	for age: float in AGES:
		f.call("forcer_age", age)
		var em := _empreinte(lumiere)
		var attendue := 2.0 * _rayon_attendu(age)
		ecart_match = maxf(ecart_match, absf(em - attendue))
		var snap := Instantane.new()
		snap.fusees = [{"graine": GRAINE, "pos": lieu, "age": age, "shooter": 1}]
		main._maj_fusees_killcam(snap)
		var rejouee: Node2D = main._fusees_killcam.get(GRAINE)
		var ek := _empreinte(rejouee.get_node("Halo") as PointLight2D) if rejouee != null else -1.0
		ecart_killcam = maxf(ecart_killcam, absf(ek - em))
		if absf(em - attendue) > 0.5 or absf(ek - em) > 0.5:
			detail += "%.2f s : match %.1f, killcam %.1f, courbe %.1f ; " % [age, em, ek, attendue]
		# L'énergie et ce que lit l'éblouissement : ceux du modèle, l'allumage n'y touche pas.
		var fenetres: Array = Modele.fenetres_agonie(GRAINE)
		var intensite: float = float(reglages.current_effect("fusee_agonie"))
		var e_attendue := Modele.energie_a(age, fenetres, intensite)
		energie_ok = energie_ok and is_equal_approx(lumiere.energy, e_attendue) \
			and is_equal_approx(float(f.call("energie_relative")), clampf(e_attendue / Modele.ENERGIE_PLEIN_FEU, 0.0, 1.0))
		main._purger_fusees_killcam()
	_check("à %d âges, de l'allumage au résidu, la fusée de match suit la courbe (écart %.3f px)" % [AGES.size(), ecart_match],
		ecart_match < 0.5, detail)
	_check("et la killcam rend la même empreinte que le match, au même âge (écart %.3f px)" % ecart_killcam,
		ecart_killcam < 0.5, detail)
	_check("l'énergie et `energie_relative` (l'éblouissement) sont ceux du modèle à chaque âge : l'allumage élargit, il ne brille "
		+ "pas davantage", energie_ok)
	# En vol dans la killcam : l'empreinte du vol ; puis posée : celle de l'allumage.
	var snap_vol := Instantane.new()
	snap_vol.fusees = [{"graine": GRAINE + 1, "pos": lieu, "age": -1.0, "shooter": 2}]
	main._maj_fusees_killcam(snap_vol)
	var k_vol: Node2D = main._fusees_killcam.get(GRAINE + 1)
	var e_kv := _empreinte(k_vol.get_node("Halo") as PointLight2D) if k_vol != null else -1.0
	snap_vol.fusees = [{"graine": GRAINE + 1, "pos": lieu, "age": 0.5, "shooter": 2}]
	main._maj_fusees_killcam(snap_vol)
	var e_kp := _empreinte(k_vol.get_node("Halo") as PointLight2D) if k_vol != null else -1.0
	_check("killcam : en vol l'empreinte du vol (%.0f px), puis posée à 0,5 s celle de l'allumage (%.0f px)" % [e_kv, e_kp],
		is_equal_approx(e_kv, _vol) and absf(e_kp - 2.0 * PORTEE_TORCHES) < 0.5)
	main._purger_fusees_killcam()
	# L'allumage éteint (le drapeau de débogage) : la fusée de la 0.8.0, son empreinte habituelle dès l'allumage.
	var rayon := Modele.rayon_allumage
	Modele.rayon_allumage = 0.0
	f.call("forcer_age", 0.5)
	var e_eteint := _empreinte(lumiere)
	var energie_eteint := lumiere.energy
	Modele.rayon_allumage = rayon
	f.call("forcer_age", 0.5)
	_check("allumage éteint : à 0,5 s l'empreinte habituelle (%.0f px), à la même énergie (%.2f) qu'allumé (%.2f)"
		% [e_eteint, energie_eteint, lumiere.energy], is_equal_approx(e_eteint, _sol)
		and is_equal_approx(energie_eteint, lumiere.energy))
	# Rien au-delà du rayon : le masque de la lumière s'éteint avant le bord de son empreinte.
	var tex := lumiere.texture
	var img := tex.get_image() if tex != null else null
	if img != null and img.is_compressed():
		img.decompress()
	var bord_allume := 0.0
	if img != null:
		var w := img.get_width()
		var cy := img.get_height() / 2
		for x in range(w / 2, w):
			if img.get_pixel(x, cy).a > 0.0:
				bord_allume = float(x - w / 2 + 1) / float(w / 2)
	_check("le masque de la lumière s'éteint avant le bord de son empreinte (dernier texel allumé à %.3f du rayon) : à "
		% bord_allume + "l'allumage, rien au-delà de %.0f px" % PORTEE_TORCHES, bord_allume > 0.5 and bord_allume <= 1.0)
	f.queue_free()
	_fin(main)


## Le rayon attendu à cet âge : la portée des torches, puis l'empreinte habituelle, selon la part écrite ici.
func _rayon_attendu(age: float) -> float:
	var part := _part_attendue(age, Modele.duree_plein_feu)
	return lerpf(_sol * 0.5, PORTEE_TORCHES, part)


static func _empreinte(l: PointLight2D) -> float:
	return float(l.texture.get_width()) * l.texture_scale if l != null and l.texture != null else 0.0


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	return true


func _fin(main: Node) -> void:
	main.queue_free()
	await process_frame
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
