## ISO13 — le personnage détaillé à l'essai (`--corps-detaille` ; le pistolet le 2026-09-24, les six classes à bouteille depuis
## Q29, 2026-09-25 ; chantier d'ISO7 Beauté).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : éteint par défaut ; sans lui, le pistolet garde ses dix boîtes et le shader d'origine, qui ne déclare
##   rien du détail ;
## - **les accessoires** : le kit de chaque classe à bouteille (onze boîtes sur le pistolet, dix sur l'Occulteur et le Spectre,
##   neuf sur les trois autres), aucune sur les quatre classes sans bouteille ; des demi-tailles distinctes entre elles et de
##   celles du corps (le shader les reconnaît à leur taille) ; le compte d'appels de dessin et de triangles ajoutés ;
## - **la bandoulière dans le torse** (Q29, le défaut de l'essai) : largeur comprise, dans le rectangle de la face du torse,
##   pour chaque classe — et la garde VUE ROUGIR sur la longueur de l'essai du 24/09 ;
## - **la silhouette** : pour chaque classe détaillée, le corps seul, accessoires compris, dans le couloir de 17,5 px (sous la
##   zone de touche de 18 px), debout et accroupi, à seize visées — et la garde VUE ROUGIR : une boîte posée hors du couloir est bien refusée ;
## - **la visibilité** : les couleurs des accessoires, à un rapport ≤ 1 du gris de la classe ; la matière peinte ne fait
##   qu'assombrir (pores et marbrage < 1) ; albédo seul, ni `light()` ni émission ; `Protocol.VERSION` 18.
##
## Ce qu'elle ne prouve pas : l'image. La planche du pistolet (banc des lumières et banc des corps) la mesure.
##
## Lancer : godot --headless --path . --script res://tools/test_corps_detail.gd
extends SceneTree

const PLANCHER := 44
const TUILE_PX := 35.0
const COULOIR_PX := 17.5
const TOUCHE_PX := 18.0
## Q29 — le kit de chaque classe détaillée (voir `VoxelCatalogue.KIT_DETAIL`).
const KIT := {"pistolet": 11, "occulteur": 10, "spectre": 10, "sentinelle": 9, "incendiaire": 9, "allumeur": 9}
const SANS_BOUTEILLE := ["fusil", "pompe", "arbalete", "fumiste"]

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
	print("=== ISO13 — LE PERSONNAGE DÉTAILLÉ À L'ESSAI ===")
	await process_frame
	var racine := Node3D.new()
	root.add_child(racine)
	_le_drapeau(racine)
	_les_accessoires(racine)
	_la_bandouliere(racine)
	_la_silhouette(racine)
	_la_visibilite()
	VoxelCatalogue.forcer_detail = -1
	VoxelCatalogue.forcer_tenue = "-"
	racine.queue_free()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _corps(racine: Node3D, slug: String, detail: bool) -> VoxelCorps:
	VoxelCatalogue.forcer_tenue = "sombre3"
	VoxelCatalogue.forcer_detail = 1 if detail else 0
	var c := VoxelCorps.new()
	racine.add_child(c)
	c.construire(slug)
	return c


func _noms(sh: Shader) -> Array:
	var noms := []
	for u in sh.get_shader_uniform_list():
		noms.append(String(u["name"]))
	return noms


func _le_drapeau(racine: Node3D) -> void:
	print("— le drapeau : éteint par défaut")
	VoxelCatalogue.forcer_detail = -1
	_check("--corps-detaille n'est pas sur la ligne de commande de la suite", not VoxelCatalogue.detail_actif())
	var sans := _corps(racine, "pistolet", false)
	_check("sans drapeau : le pistolet garde ses dix boîtes (%d)" % sans.nombre_de_boites(), sans.nombre_de_boites() == 10
		and sans.details().is_empty())
	_check("sans drapeau : le shader d'origine, qui ne déclare rien du détail",
		sans.materiau().shader == load("res://corps_iso.gdshader") and not _noms(sans.materiau().shader).has("detail"))
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var v := IsoMateriaux.variante_definie(load(chemin), "CORPS_DETAIL")
		var noms := _noms(v)
		_check("%s : la variante CORPS_DETAIL compile et déclare le détail" % chemin.get_file(),
			noms.has("detail") and noms.has("detail_demi") and noms.has("detail_matiere"))
	var m := ShaderMaterial.new()
	m.shader = load("res://corps_iso_eclaire.gdshader")
	VoxelCatalogue.forcer_detail = 1
	IsoMateriaux.accorder_corps(m)
	_check("accorder_corps garde la variante après un changement de shader (la lumière 3D)", m.shader.code.contains("#define CORPS_DETAIL\n"))
	VoxelCatalogue.forcer_detail = 0
	var m2 := ShaderMaterial.new()
	m2.shader = load("res://corps_iso.gdshader")
	IsoMateriaux.accorder_corps(m2)
	_check("drapeau éteint : accorder_corps laisse le shader d'origine", m2.shader == load("res://corps_iso.gdshader"))


func _les_accessoires(racine: Node3D) -> void:
	print("— les accessoires modelés")
	_check("les classes détaillées sont les six classes à bouteille, et chacune a son kit",
		VoxelCatalogue.CLASSES_DETAILLEES.size() == KIT.size()
		and KIT.keys().all(func(k): return VoxelCatalogue.CLASSES_DETAILLEES.has(k) and VoxelCatalogue.KIT_DETAIL.has(k)))
	var sans_rien := true
	for c in SANS_BOUTEILLE:
		sans_rien = sans_rien and _corps(racine, c, true).details().is_empty()
	_check("les quatre classes sans bouteille n'en portent aucun (leur tour vient après)", sans_rien)
	for slug in KIT:
		_le_kit(racine, slug, int(KIT[slug]))


func _le_kit(racine: Node3D, slug: String, attendus: int) -> void:
	var avec := _corps(racine, slug, true)
	var sans := _corps(racine, slug, false)
	var n_sans := sans.nombre_de_boites()
	_check("%s détaillé : %d accessoires (%d boîtes en tout)" % [slug, avec.details().size(), avec.nombre_de_boites()],
		avec.details().size() == attendus and avec.nombre_de_boites() == n_sans + attendus)
	# Les demi-tailles : celles des accessoires, et celles des boîtes du corps sans eux.
	var du_corps := []
	for b in sans.boites():
		du_corps.append(((b as MeshInstance3D).mesh as BoxMesh).size * 0.5)
	var confondues := []
	for b in avec.details():
		var d: Vector3 = ((b as MeshInstance3D).mesh as BoxMesh).size * 0.5
		for r in du_corps:
			if d.distance_to(r) < 0.001:
				confondues.append(String((b as Node).name))
	var tailles := {}
	for b in avec.details():
		tailles[String((b as Node).name).rstrip("0123456789")] = ((b as MeshInstance3D).mesh as BoxMesh).size
	var distinctes := {}
	for k in tailles:
		distinctes[str(tailles[k])] = true
	var n_shader := int(avec.materiau().get_shader_parameter("detail_n"))
	# Le coût : chaque accessoire, une boîte de couleur et son double de profondeur ; 12 triangles chacune.
	var mi_avec := avec.find_children("*", "MeshInstance3D", true, false).size()
	var mi_sans := sans.find_children("*", "MeshInstance3D", true, false).size()
	print("  %s : %d sortes, detail_n = %d ; COÛT %d appels de dessin, %d triangles de plus par corps"
		% [slug, tailles.size(), n_shader, mi_avec - mi_sans, (mi_avec - mi_sans) * 12])
	_check("%s : aucune taille confondue avec le corps, une par sorte, toutes connues du shader (%d ≤ 10), %d appels de plus"
		% [slug, n_shader, mi_avec - mi_sans],
		confondues.is_empty() and tailles.size() == distinctes.size() and n_shader == distinctes.size() and n_shader <= 10
		and mi_avec - mi_sans == 2 * attendus, str(confondues))
	_check("%s : chaque accessoire suit une pièce animée (torse, bouteille, arme)" % slug,
		avec.details().all(func(b): return ["Torse", "Bouteille", "Arme"].has(String((b as Node).get_parent().name))))


## Le débord d'une boîte tournée de `angle` autour de z, centrée en `centre` (repère du torse), hors du rectangle de la face :
## x dans [−lt/2, lt/2], y dans [0, ht]. 0 si elle tient.
func _debord(taille: Vector3, centre: Vector3, angle: float, lt: float, ht: float) -> float:
	var dx := taille.x * 0.5 * absf(cos(angle)) + taille.y * 0.5 * absf(sin(angle))
	var dy := taille.x * 0.5 * absf(sin(angle)) + taille.y * 0.5 * absf(cos(angle))
	return maxf(0.0, maxf(maxf(absf(centre.x) + dx - lt * 0.5, centre.y + dy - ht), -(centre.y - dy)))


func _la_bandouliere(racine: Node3D) -> void:
	print("— la bandoulière dans le torse (le défaut de l'essai)")
	for slug in KIT:
		var c := _corps(racine, slug, true)
		var f := VoxelCatalogue.fiche(slug)
		var lt := float(f["largeur_torse"]) * float(f["echelle"])
		var ht := float(f["hauteur_torse"])
		var pire := 0.0
		for nom in ["Bandouliere", "Cartouche1", "Cartouche2", "Cartouche3"]:
			var b := c.find_child(nom, true, false) as MeshInstance3D
			pire = maxf(pire, _debord((b.mesh as BoxMesh).size, b.position, b.rotation.z, lt, ht))
		_check("%s : la bandoulière et ses cartouches, largeur comprise, dans la face du torse (débord %.4f tuile)" % [slug, pire],
			pire <= 0.0001)
	# La garde vue rougir : la longueur de l'essai du 24/09 (lt / cos × 0,98, sans la largeur) déborde.
	var f := VoxelCatalogue.fiche("pistolet")
	var lt := float(f["largeur_torse"]) * float(f["echelle"])
	var ht := float(f["hauteur_torse"])
	var angle := atan(-0.9 * (ht * 0.5) / (lt * 0.5))
	var ancienne := lt / cos(angle) * 0.98
	var debord := _debord(Vector3(ancienne, VoxelCorps.LARGEUR_BANDOULIERE, 0.014), Vector3(0, ht * 0.5, 0), angle, lt, ht)
	_check("la garde rougit sur la longueur de l'essai (%.3f → débord %.4f tuile ; aujourd'hui %.3f)"
		% [ancienne, debord, VoxelCorps.longueur_bandouliere(lt, ht, angle, VoxelCorps.LARGEUR_BANDOULIERE)], debord > 0.005)


## Le pire rayon du corps seul (accessoires compris), debout et accroupi, à seize visées, en pixels du monde.
func _pire_rayon(c: VoxelCorps) -> float:
	var pire := 0.0
	for k in 16:
		var visee := Vector2.DOWN.rotated(TAU * float(k) / 16.0)
		var etat := {"position": Vector2.ZERO, "visee": visee, "vitesse": Vector2.ZERO, "torche": true, "arme": c.slug(),
			"tir": false, "touche": false, "mort": false, "t": 0.0}
		c.poser(etat)
		pire = maxf(pire, c.rayon_empreinte(true))
		etat["accroupi"] = true
		etat["t"] = 1.0
		c.poser(etat)
		pire = maxf(pire, c.rayon_empreinte(true))
	return pire * TUILE_PX


func _la_silhouette(racine: Node3D) -> void:
	print("— la silhouette dans le couloir")
	for slug in KIT:
		var r_sans := _pire_rayon(_corps(racine, slug, false))
		var r_avec := _pire_rayon(_corps(racine, slug, true))
		print("  SILHOUETTE %s, corps seul : %.2f px sans accessoires, %.2f px avec" % [slug, r_sans, r_avec])
		_check("%s : accessoires compris, dans le couloir (%.2f ≤ %.1f px), sous la zone de touche (%.0f px), pas plus large (%.2f)"
			% [slug, r_avec, COULOIR_PX, TOUCHE_PX, r_sans],
			r_avec <= COULOIR_PX + 0.01 and r_avec < TOUCHE_PX and r_avec <= r_sans + 0.01)
	# La garde vue rougir : l'étui du pistolet déplacé à 0,6 tuile du centre doit être refusé par la même mesure.
	var faux := _corps(racine, "pistolet", true)
	var etui := faux.find_child("Etui", true, false) as Node3D
	etui.position = Vector3(0.6, etui.position.y, etui.position.z)
	var r_faux := _pire_rayon(faux)
	_check("la garde rougit sur une boîte hors du couloir (%.2f px > %.1f)" % [r_faux, COULOIR_PX], r_faux > COULOIR_PX + 0.01)


func _la_visibilite() -> void:
	print("— la visibilité : la couleur, jamais plus claire")
	var sous := true
	for slug in KIT:
		var l := VoxelCatalogue.luminance_affichee(VoxelCatalogue.fiche(slug)["couleur"])
		var p := VoxelCatalogue.palette_details(slug, "sombre3", "froide")
		sous = sous and p.size() == 3
		for cle in p:
			sous = sous and VoxelCatalogue.luminance_affichee(p[cle]) <= l + 0.002
	_check("cuir, laiton et métal à un rapport ≤ 1 du gris de leur classe, pour les six", sous)
	_check("aucune couleur d'accessoire en gris ni en portraits (l'essai est celui de la V3)",
		VoxelCatalogue.palette_details("pistolet", "").is_empty() and VoxelCatalogue.palette_details("pistolet", "portraits").is_empty())
	var inc := FileAccess.get_file_as_string("res://iso_corps_detail.gdshaderinc")
	_check("tout sous #ifdef CORPS_DETAIL", inc.find("#ifdef CORPS_DETAIL") < inc.find("uniform float detail")
		and inc.strip_edges().ends_with("#endif"))
	_check("la matière peinte n'assombrit que (pores 0,62 et marbrage 0,86 < 1, multipliés à la fiche)",
		inc.contains("const float DETAIL_PORE = 0.62;") and inc.contains("const float DETAIL_MARBRE = 0.86;")
		and inc.contains("return c * mix(1.0, k, detail_matiere);"))
	_check("les pores s'effacent à la taille du duel (entiers sous 0,3 pixel du monde par pixel d'écran, nuls au-dessus de 0,5)",
		inc.contains("float fondu = 1.0 - smoothstep(0.3, 0.5, ecran);"))
	_check("albédo seul : l'include n'écrit ni ALBEDO, ni EMISSION, ni light()",
		not inc.contains("ALBEDO") and not inc.contains("EMISSION") and not inc.contains("void light"))
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var code := FileAccess.get_file_as_string(chemin)
		var lumiere := code.substr(code.find("void light()")) if code.contains("void light()") else ""
		_check("%s : le détail sur la fiche seule, sous le drapeau ; light() ne le connaît pas" % chemin.get_file(),
			code.contains("#ifdef CORPS_DETAIL\n\t// ISO13 — les accessoires modelés et la matière peinte : la fiche seule, assombrie jamais éclaircie.\n\tfiche = detail_fiche(")
			and not lumiere.contains("detail"))
	_check("Protocol.VERSION reste 18 : rien sur le fil", FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))
