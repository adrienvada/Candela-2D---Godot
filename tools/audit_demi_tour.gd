## L'audit du JUMEAU PAR LE DEMI-TOUR : le tableau décor × carte, « juste » ou les orphelins (`tools/demi_tour.gd`).
## Un outil, pas une suite : il sort toujours 0. Ce sont les gardes de chaque décor qui rougissent.
##
## Lancer : godot --headless --path . --script res://tools/audit_demi_tour.gd
extends SceneTree

const DemiTour := preload("res://tools/demi_tour.gd")


func _init() -> void:
	call_deferred("_run")


func _ligne(decor: String, carte: String, total: int, orphelins: Array) -> void:
	var etat := "juste" if orphelins.is_empty() else "%d orphelin(s) : %s" % [orphelins.size(), ", ".join(orphelins)]
	print("| %s | %s | %d | %s |" % [decor, carte, total, etat])


func _run() -> void:
	await process_frame
	var cartes := DemiTour.cartes()
	var ids := cartes.keys()
	ids.sort()
	print("| décor | carte | objets | par le demi-tour |")
	print("|---|---|---|---|")
	for id in ids:
		var d: Dictionary = cartes[id]
		var nom := "%s (%s)" % [String(d.get("name", id)), id]
		var g := MapCodec.get_grid_size(d)
		var pochoirs: Array = ArenaDecor.POCHOIRS_ESSAI.get(id, [])
		_ligne("pochoirs", nom, pochoirs.size(), DemiTour.orphelins_pochoirs(pochoirs, g))
		var marques: Array = ArenaDecor.SOL_MARQUE_ESSAI.get(id, [])
		_ligne("sol marqué", nom, marques.size(), DemiTour.orphelins_sol_marque(marques, g))
		var t := TuyauxIso.construire(d)
		var meublees := {}
		for i in (t["face_de_sommet"] as PackedInt32Array):
			meublees[i] = true
		_ligne("tuyaux (faces meublées)", nom, meublees.size(), DemiTour.orphelins_tuyaux(d, t))
		var e := EnseignesIso.construire(d)
		_ligne("enseignes", nom, (e["enseignes"] as Array).size(), DemiTour.orphelins_enseignes(d, e))
		var m := MursMeublesIso.construire(d)
		_ligne("murs meublés", nom, (m["objets"] as Array).size(), DemiTour.orphelins_murs_meubles(d, m))
	quit(0)
