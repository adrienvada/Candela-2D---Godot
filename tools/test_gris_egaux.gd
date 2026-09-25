## ISO13, Q32 — les dix classes à la même lumière (décision d'Adrien, 2026-09-25 10:28 ; chantier d'ISO7 Beauté).
##
## Ce que la suite prouve, sans fenêtre :
## - **la table** : `VoxelCatalogue.GRIS_EGAUX` porte un facteur pour chacune des dix classes, tous sous le plafond, et c'est
##   lui que la fiche d'un corps applique — le rang ne décide plus (sauf `--gris=rangs`, pour comparer) ;
## - **ce qui imite un corps suit son gris** : le leurre est un corps de la classe de son poseur (même fiche), les fantômes de
##   la killcam sont les corps des joueurs, et la plaque de l'ombre habitée prend le gris de l'Occulteur, jamais son rang ;
## - **les objets** gardent leur rang (ils ne sont pas des corps) ;
## - **la garde rougit** : aux rangs (simulés), l'Occulteur perd le gris de la table — et la plaque le suit toujours.
##
## Ce qu'elle ne prouve pas : la lumière d'apparition. Le balayage du banc des corps la mesure, classe par classe.
##
## Lancer : godot --headless --path . --script res://tools/test_gris_egaux.gd
extends SceneTree

const PLANCHER := 8

var _echecs := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ %s" % label)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ISO13, Q32 — LES DIX CLASSES À LA MÊME LUMIÈRE ===")
	await process_frame
	VoxelCatalogue.forcer_gris_facteur = -1.0
	var manquantes := []
	var trop := []
	for s in VoxelCatalogue.slugs():
		if not VoxelCatalogue.GRIS_EGAUX.has(s):
			manquantes.append(s)
		elif float(VoxelCatalogue.GRIS_EGAUX[s]) > 1.0 or float(VoxelCatalogue.GRIS_EGAUX[s]) <= 0.0:
			trop.append(s)
	_check("un facteur pour chacune des dix classes", manquantes.is_empty(), str(manquantes))
	_check("tous dans ]0, 1] : aucun corps plus clair que le plafond (Charte.DIM)", trop.is_empty(), str(trop))
	var applique := true
	for s in VoxelCatalogue.slugs():
		var f := VoxelCatalogue.fiche(s)
		var attendu: Color = VoxelCatalogue.GRIS_PLAFOND * float(VoxelCatalogue.GRIS_EGAUX.get(s, 0.0))
		applique = applique and (f["couleur"] as Color).is_equal_approx(attendu)
	_check("la fiche d'un corps applique la table, pas le rang", applique)
	_check("--gris=rangs n'est pas sur la ligne de commande de la suite",
		not OS.get_cmdline_user_args().has(VoxelCatalogue.DRAPEAU_GRIS_RANGS))
	# Ce qui imite un corps.
	var ombre: Color = VoxelCatalogueObjets.fiche("ombre")["couleur"]
	var occ: Color = VoxelCatalogue.fiche("occulteur")["couleur"]
	_check("la plaque de l'ombre habitée a le gris de l'Occulteur (%s = %s)" % [ombre, occ], ombre.is_equal_approx(occ))
	var miroirs := FileAccess.get_file_as_string("res://miroirs_iso.gd")
	_check("le leurre est un corps de la classe de son poseur (même fiche, même gris)",
		miroirs.contains("corps.construire(_classe_du_leurre(noeud))"))
	# La garde vue rougir : aux rangs (`--gris=rangs`, simulé), l'Occulteur retrouve son rang 0 et la table ne décide plus —
	# la vérification « la fiche applique la table » tomberait.
	VoxelCatalogue._gris_rangs_ligne = 1
	var occ_rang: Color = VoxelCatalogue.fiche("occulteur")["couleur"]
	var ombre_rang: Color = VoxelCatalogueObjets.fiche("ombre")["couleur"]
	VoxelCatalogue._gris_rangs_ligne = -1
	_check("la garde rougit aux rangs : l'Occulteur n'y a plus le gris de la table, et la plaque le suit encore",
		not occ_rang.is_equal_approx(occ) and occ_rang.is_equal_approx(VoxelCatalogue.GRIS_PLAFOND * VoxelCatalogue._facteur_gris(0))
		and ombre_rang.is_equal_approx(occ_rang))
	# Les objets qui n'imitent pas un corps gardent leur rang.
	var mine: Color = VoxelCatalogueObjets.fiche("mine")["couleur"]
	_check("les autres objets gardent leur rang (la mine : rang 2)",
		mine.is_equal_approx(VoxelCatalogueObjets.GRIS_PLAFOND * VoxelCatalogueObjets._facteur_gris(2)))
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)
