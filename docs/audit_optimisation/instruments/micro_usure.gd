## Le coût de `IsoMateriaux.image_proximite_usure` (V4 § « levier 1 », CAR-05 / GEO) — micro-banc CPU headless, INSTRUMENT TEMPORAIRE.
##
## Appelé à chaque `Presentation3D._construire_les_murs` (donc à chaque départ de manche, sous `_usure`, vrai par défaut). V4 estime 0,05-0,3 s par
## départ de duel et 0,4-2,3 s pour la salle 8.9, « la majeure partie du départ de duel » ; l'appel n'a jamais été chronométré.
## Pour chaque carte livrée et pour chaque salle d'aventure demandée : le temps de `image_grille` seule, puis de `image_proximite_usure`
## (1re exécution, puis médiane de 5), et la taille de l'image.
##
## godot --headless --path . --script res://tools/micro_usure.gd -- --no-eos [--salles=8:9,7:9,0:9]
extends SceneTree

const Format := preload("res://aventure_format.gd")


func _init() -> void:
	call_deferred("_run")


static func _med(a: Array) -> float:
	var t := a.duplicate()
	t.sort()
	return float(t[t.size() / 2])


func _mesurer(titre: String, data: Dictionary) -> void:
	var g0 := Time.get_ticks_usec()
	var grille := IsoMateriaux.image_grille(data)
	var g1 := Time.get_ticks_usec()
	var essais: Array[float] = []
	var premiere := 0.0
	var taille := Vector2i.ZERO
	for i in 6:
		var t0 := Time.get_ticks_usec()
		var img := IsoMateriaux.image_proximite_usure(data)
		var t1 := Time.get_ticks_usec()
		if i == 0:
			premiere = (t1 - t0) / 1000.0
			taille = img.get_size()
		else:
			essais.append((t1 - t0) / 1000.0)
	var cases := grille.get_size()
	print("  %-34s grille %3d×%-3d (%6d cases) · image de proximité %4d×%-4d (%.2f Mpx) · image_grille %.1f ms · proximité : 1re %.1f ms, médiane de 5 : %.1f ms (min %.1f, max %.1f)" % [
		titre, cases.x, cases.y, cases.x * cases.y, taille.x, taille.y, taille.x * taille.y / 1.0e6, (g1 - g0) / 1000.0, premiere, _med(essais), essais.min(), essais.max()])


func _run() -> void:
	await process_frame
	var md: Node = root.get_node("MapData")
	print("=== COÛT DE image_proximite_usure — headless, par carte (ms ; machine : Xeon 2,8 GHz, plus lent que le M3) ===")
	for entree in md.list_maps():
		if md.select_map(String(entree["id"])):
			_mesurer("carte « %s »" % String(entree.get("name", entree["id"])), md.get_selected())
	var arg := "8:9,7:9,0:9"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--salles="):
			arg = String(a).substr(9)
	var salles := arg.split(",")
	Format.racine = "res://assets/solo"
	Format.oublier_le_cache()
	for cs in salles:
		var p := String(cs).split(":")
		var chap := int(p[0])
		var salle := int(p[1])
		var chapitre: Dictionary = Format.charger_chapitre("res://assets/solo/chapitre_%02d" % chap)
		if chapitre.is_empty():
			print("  ✗ chapitre %d illisible" % chap)
			continue
		var niveau: Dictionary = (chapitre["niveaux"] as Array)[salle - 1]
		_mesurer("solo %d.%d « %s »" % [chap, salle, String(niveau.get("titre", ""))], niveau["carte"])
	quit(0)
