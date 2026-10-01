extends SceneTree

## Q72 (Adrien, 2026-09-30 : « Q72 : corrige aussi ») — LA FUSÉE POSÉE DE LA KILLCAM ÉCLAIRE COMME EN MATCH.
##
## La killcam ne rejoue pas le vol : `GameState._maj_fusees_killcam` construit une fusée neuve (`is_replay`) et lui applique
## l'âge de l'instantané (`appliquer_age`), sans jamais passer par `_atterrir`. Sa lumière gardait l'empreinte du VOL
## (`Fusee.EMPREINTE_VOL`, 160 px au lieu de 440) : dans la mort qu'on revoit, une fusée posée éclairait un disque presque
## trois fois plus petit qu'en match. Ce que cette garde tient, sur le VRAI chemin de la killcam (headless, sans pixel) :
## - une vraie fusée de match, lancée dans une vraie manche, qui vole, rebondit et se pose ; à un âge donné, sa lumière :
##   texture et échelle (l'empreinte), masque d'ombre, hauteur de source, énergie, couleur, masques de portée ;
## - la fusée que la killcam reconstruit depuis un instantané de ce même âge, à la même place : la MÊME lumière, valeur par
##   valeur (le masque et la hauteur étaient déjà ceux d'une fusée posée, posés par `_ready` : vérifié ici) ;
## - rien d'autre ne bouge : une fusée EN VOL dans la killcam (âge négatif) garde l'empreinte du vol, comme en match, et
##   passe à celle du sol quand l'âge rejoué devient celui d'une fusée posée.
##
## ⚠️ `fusee.gd` nomme des autoloads : cette garde ne nomme JAMAIS la classe dans son code (sous `--script`, la compiler avant
## que les autoloads existent la casse pour tout le processus — « Nonexistent function 'prechauffer' »). Le script se charge
## à l'exécution (`load`), et ses constantes se lisent dans sa table.
##
## Lancer : godot --headless --path . --script res://tools/test_fusee_killcam.gd

const GRAINE := 4242
## L'âge de combustion auquel on compare (secondes) : plein feu passé, fumée installée.
const AGE := 3.0

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


func _run() -> void:
	print("=== Q72 : LA FUSÉE POSÉE DE LA KILLCAM ÉCLAIRE COMME EN MATCH ===")
	await process_frame
	var Script: GDScript = load("res://fusee.gd")
	var constantes := Script.get_script_constant_map()
	_vol = float(constantes["EMPREINTE_VOL"])
	_sol = float(constantes["EMPREINTE_LUMIERE"])
	_check("les deux empreintes diffèrent (sinon rien ne se prouve) : vol %.0f px, sol %.0f px" % [_vol, _sol],
		not is_equal_approx(_vol, _sol))
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
	var en_vol := _releve(lumiere)
	_check("en vol, la fusée de match éclaire avec l'empreinte du vol (%.0f px)" % _vol,
		is_equal_approx(en_vol["empreinte"], _vol), str(en_vol))
	var fin := Time.get_ticks_msec() + 15000
	while not bool(f.call("est_allumee_au_sol")) and Time.get_ticks_msec() < fin:
		await physics_frame
	_check("la fusée de match vole, rebondit et se pose", bool(f.call("est_allumee_au_sol")))
	while float(f.call("age_combustion")) < AGE and Time.get_ticks_msec() < fin + 10000:
		await physics_frame
	# Le relevé du match, puis l'instantané du même instant : l'âge exact et la position.
	f.set_physics_process(false)
	var age := float(f.call("age_combustion"))
	var lieu := f.global_position
	var match_ := _releve(lumiere)
	print("  · match : âge %.3f s, %s" % [age, str(match_)])
	_check("posée, la fusée de match éclaire avec l'empreinte du sol (%.0f px)" % _sol,
		is_equal_approx(match_["empreinte"], _sol), str(match_))
	# La killcam, par SON chemin : `_maj_fusees_killcam` avec un instantané. ⚠️ Relue AUSSITÔT, sans attendre d'image : hors
	# d'un rejeu, `GameState._process` purge les fusées de killcam dès l'image suivante (la fin d'un rejeu). La fusée est
	# construite, posée dans l'arbre (`_ready`) et vieillie (`appliquer_age`) pendant l'appel lui-même.
	var snap := Instantane.new()
	snap.fusees = [{"graine": GRAINE, "pos": lieu, "age": age, "shooter": 1}]
	main._maj_fusees_killcam(snap)
	var rejouee: Node2D = main._fusees_killcam.get(GRAINE)
	_check("la killcam a reconstruit la fusée (is_replay)", rejouee != null and is_instance_valid(rejouee)
		and bool(rejouee.get("is_replay")))
	if rejouee == null or not is_instance_valid(rejouee):
		_fin(main)
		return
	var killcam := _releve(rejouee.get_node("Halo") as PointLight2D)
	print("  · killcam : %s" % str(killcam))
	for cle in ["empreinte", "texture", "masque_ombre", "hauteur", "energie", "couleur", "allumee", "portee", "ombres"]:
		var a = match_[cle]
		var b = killcam[cle]
		var egal: bool = is_equal_approx(a, b) if a is float else (a.is_equal_approx(b) if a is Color else a == b)
		_check("posée, au même âge : « %s » est le même en killcam qu'en match (%s)" % [cle, str(b)], egal,
			"match %s, killcam %s" % [str(a), str(b)])
	main._purger_fusees_killcam()
	await process_frame
	# En vol dans la killcam : l'empreinte du vol, comme en match ; puis l'âge d'une fusée posée : celle du sol.
	var snap_vol := Instantane.new()
	snap_vol.fusees = [{"graine": GRAINE + 1, "pos": lieu, "age": -1.0, "shooter": 2}]
	main._maj_fusees_killcam(snap_vol)
	var en_vol_k: Node2D = main._fusees_killcam.get(GRAINE + 1)
	var vol_k := _releve(en_vol_k.get_node("Halo") as PointLight2D) if en_vol_k != null else {}
	_check("en vol dans la killcam, l'empreinte reste celle du vol, comme en match (%.0f px)" % _vol,
		not vol_k.is_empty() and is_equal_approx(vol_k["empreinte"], en_vol["empreinte"]), str(vol_k))
	# Q58 — à 3,5 s, l'allumage est fini : l'empreinte du sol est l'habituelle. Celle des âges de l'allumage, en match comme
	# en killcam, est gardée par `test_fusee_allumage`.
	snap_vol.fusees = [{"graine": GRAINE + 1, "pos": lieu, "age": 3.5, "shooter": 2}]
	main._maj_fusees_killcam(snap_vol)
	var posee_k := _releve(en_vol_k.get_node("Halo") as PointLight2D) if en_vol_k != null else {}
	_check("la même fusée de killcam, à l'âge d'une fusée posée, passe à l'empreinte du sol (%.0f px)" % _sol,
		not posee_k.is_empty() and is_equal_approx(posee_k["empreinte"], _sol), str(posee_k))
	_fin(main)


## Ce qui fait la lumière d'une fusée : l'empreinte (largeur de la texture × échelle, en pixels de monde), la texture,
## le masque d'ombre, la hauteur de la source (tuiles), l'énergie, la couleur, allumée ou non, la portée, les ombres.
func _releve(l: PointLight2D) -> Dictionary:
	return {"empreinte": float(l.texture.get_width()) * l.texture_scale if l.texture != null else 0.0,
		"texture": l.texture.resource_path if l.texture != null and l.texture.resource_path != "" else str(l.texture),
		"masque_ombre": l.shadow_item_cull_mask, "hauteur": MursBasRendu.hauteur_source(l), "energie": l.energy,
		"couleur": l.color, "allumee": l.enabled, "portee": l.range_item_cull_mask, "ombres": l.shadow_enabled}


func _fin(main: Node) -> void:
	main.queue_free()
	await process_frame
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


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
