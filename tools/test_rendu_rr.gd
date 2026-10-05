## Chantier RR, étape RR1 — le rendu en jeu sans la pâte roman graphique (Adrien, 2026-10-05 : « Q83, je préfère "brute,
## sans paliers" », puis « Essayons de voir les graphismes en annulant, en jeu (pas dans les menus) cette pâte roman
## graphique : visons un style plus réaliste. Plus fluide. Plus oppressant »).
##
##   • **Q83 : la pâte brute par défaut**, aux TROIS endroits où le défaut est écrit — `Presentation3D.PATE_PAR_DEFAUT`,
##     `VoxelCorps.STYLE_PAR_DEFAUT`, `VoxelObjets.STYLE_PAR_DEFAUT` : un seul en retard, et la première image d'un corps ou
##     d'un objet neuf sortirait en lavis. `--pate D` remet le rendu d'avant (le nom se lit encore).
##   • **L'essai sans encre** (`--sans-encre`, `IsoMateriaux.encre_active`) : sur des matériaux neufs accordés par les
##     fonctions mêmes du jeu (`accorder_mur`, `accorder_corps`, `IsoNuageVoxel.poser_style`), l'encre NOIRE part, et elle
##     seule — la matière, la température, le contact, le liseré du sommet (la lumière de la face) restent. Sans le drapeau,
##     le jeu d'avant, réglage pour réglage. `MurEncre` ne trace plus son trait halogène : lu dans son `_draw` (le headless ne
##     rastérise rien, la planche de RR1 le montre).
##
## Jouée deux fois par `run_suites.sh` : sans drapeau (`test_rendu_rr`) puis avec (`test_rendu_rr_sans_encre`, après `--`,
## AVEC `--encre-essai` : l'essai sans encre doit l'emporter).
## Lancer : godot --headless --path . --script res://tools/test_rendu_rr.gd [-- --sans-encre]
extends SceneTree

const IsoPate := preload("res://iso_pate.gd")

var _failures := 0
var _verifications := 0


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
	print("=== RR1 — LE RENDU EN JEU SANS LA PÂTE ROMAN GRAPHIQUE ===")
	await process_frame
	var sans_encre := DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_SANS_ENCRE)
	print("  (essai sans encre : %s)" % ("OUI, " + IsoMateriaux.DRAPEAU_SANS_ENCRE if sans_encre else "non — le jeu par défaut"))
	_la_pate_par_defaut()
	_l_encre_des_murs(sans_encre)
	_l_encre_des_corps(sans_encre)
	_l_encre_de_la_fumee(sans_encre)
	_le_trait_des_murs(sans_encre)
	print("%d vérifications, %d échec(s)" % [_verifications, _failures])
	quit(1 if _failures > 0 else 0)


func _constante(chemin: String, nom: String) -> Variant:
	return (load(chemin) as GDScript).get_script_constant_map().get(nom)


# ---------------------------------------------------------------------------
# Q83 — LA BRUTE PAR DÉFAUT, PARTOUT OÙ LE DÉFAUT EST ÉCRIT
# ---------------------------------------------------------------------------

func _la_pate_par_defaut() -> void:
	print("— Q83 : la pâte brute par défaut")
	var brute := IsoPate.BRUTE
	var presentation: Variant = _constante("res://presentation_3d.gd", "PATE_PAR_DEFAUT")
	var corps: Variant = _constante("res://voxel_corps.gd", "STYLE_PAR_DEFAUT")
	var objets: Variant = _constante("res://voxel_objets.gd", "STYLE_PAR_DEFAUT")
	_check("la présentation part en brute (PATE_PAR_DEFAUT = %s)" % str(presentation), presentation == brute)
	_check("un corps voxel neuf part en brute, comme le jeu (STYLE_PAR_DEFAUT = %s)" % str(corps), corps == brute,
		"un défaut en retard : la première image d'un corps neuf sortirait dans une autre pâte")
	_check("un objet voxel neuf part en brute, comme le jeu (STYLE_PAR_DEFAUT = %s)" % str(objets), objets == brute)
	_check("« --pate D » remet le lavis (le rendu d'avant, pour comparer)", IsoPate.style_depuis_nom("D") == IsoPate.LAVIS)
	_check("« --pate brute » désigne la brute", IsoPate.style_depuis_nom("brute") == brute)
	# La brute rend la couleur reçue telle quelle (miroir processeur de `pate()`) : ni palier, ni grain, ni désaturation.
	var ok := true
	for l: float in [0.0, 0.01, 0.03, 0.2, 0.5, 1.0]:
		var c := Vector3(0.8, 0.6, 0.4) * l
		var rendue: Vector3 = IsoPate.pate(c, l, brute, Vector2(13.0, 7.0), Vector2.ZERO, l, 0.1)
		ok = ok and rendue.is_equal_approx(c)
	_check("la brute rend la lumière reçue telle quelle, à toute intensité", ok)


# ---------------------------------------------------------------------------
# L'ESSAI SANS ENCRE — CE QUI PART, CE QUI RESTE
# ---------------------------------------------------------------------------

func _l_encre_des_murs(sans_encre: bool) -> void:
	print("— l'encre des murs")
	var mur := ShaderMaterial.new()
	mur.shader = load("res://mur_iso.gdshader")
	IsoMateriaux.accorder_mur(mur)
	var px := float(mur.get_shader_parameter("encre_arete_px"))
	var reste := float(mur.get_shader_parameter("encre_arete_reste"))
	if sans_encre:
		# La largeur seule ne suffit pas : le dessus d'un muret la relève à un pixel (`max(encre_arete_px, px_monde)`).
		_check("sans encre : l'arête d'un mur ne s'assombrit plus (reste %.2f, largeur %.1f px)" % [reste, px],
			is_equal_approx(reste, 1.0) and px == 0.0)
	else:
		_check("par défaut : l'encre des arêtes, comme avant (%.1f px, reste %.2f)" % [px, reste],
			is_equal_approx(px, IsoMateriaux.ENCRE_ARETE_PX) and is_equal_approx(reste, IsoMateriaux.ENCRE_ARETE_RESTE))
	# Ce qui n'est pas de l'encre ne bouge pas, avec ou sans le drapeau.
	_check("la matière des faces reste", is_equal_approx(float(mur.get_shader_parameter("force_matiere")),
		IsoMateriaux.FORCE_MATIERE_MUR))
	_check("le liseré du sommet reste — la lumière de la face, pas un trait",
		is_equal_approx(float(mur.get_shader_parameter("lisere_sommet_px")), IsoMateriaux.LISERE_SOMMET_PX))
	_check("la température reste", is_equal_approx(float(mur.get_shader_parameter("temperature")),
		IsoMateriaux.TEMPERATURE_GRADUEE))
	_check("le contact au pied reste", is_equal_approx(float(mur.get_shader_parameter("contact_px")), IsoMateriaux.CONTACT_PX))
	_check("les murets restent", is_equal_approx(float(mur.get_shader_parameter("seuil_muret_px")), IsoMateriaux.SEUIL_MURET_PX))


func _l_encre_des_corps(sans_encre: bool) -> void:
	print("— l'encre des corps, des objets et du leurre")
	var corps := ShaderMaterial.new()
	corps.shader = load("res://corps_iso.gdshader")
	IsoMateriaux.accorder_corps(corps)
	var largeur := float(corps.get_shader_parameter("encre_arete"))
	if sans_encre:
		_check("sans encre : les arêtes des voxels ne sont plus tracées (%.2f px)" % largeur, largeur == 0.0)
	else:
		_check("par défaut : l'encre des voxels, comme avant (%.2f px)" % largeur,
			is_equal_approx(largeur, IsoMateriaux.ENCRE_VOXEL_PX))
	_check("le modelé des corps reste", is_equal_approx(float(corps.get_shader_parameter("modele")), 1.0))
	# `run_suites.sh` joue la variante sans encre AVEC `--encre-essai` : la préséance se joue pour de vrai.
	if sans_encre and DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_ENCRE_ESSAI):
		_check("l'encre renforcée, demandée aussi (--encre-essai), cède à l'essai sans encre",
			not IsoMateriaux.encre_essai_active())
	elif sans_encre:
		print("  (préséance sur --encre-essai non jouée : le drapeau n'est pas passé)")


func _l_encre_de_la_fumee(sans_encre: bool) -> void:
	print("— l'encre de la fumée")
	var nuage := ShaderMaterial.new()
	nuage.shader = load("res://nuage_voxel_iso.gdshader")
	IsoNuageVoxel.poser_style(nuage, IsoNuageVoxel.ENCRE_PAR_DEFAUT, IsoNuageVoxel.RELIEF_PAR_DEFAUT)
	var style := int(nuage.get_shader_parameter("encre_style"))
	var aucune := int(IsoNuageVoxel.ENCRES["aucune"])
	var attendu := aucune if sans_encre else int(IsoNuageVoxel.ENCRES[IsoNuageVoxel.ENCRE_PAR_DEFAUT])
	_check("%s : l'encre de la fumée est « %s » (%d)" % ["sans encre" if sans_encre else "par défaut",
		"aucune" if sans_encre else IsoNuageVoxel.ENCRE_PAR_DEFAUT, style], style == attendu)
	# Même une encre demandée nommément cède à l'essai (`--fumee-encre=hachures --sans-encre` : aucune).
	IsoNuageVoxel.poser_style(nuage, "hachures", IsoNuageVoxel.RELIEF_PAR_DEFAUT)
	var demandee := int(nuage.get_shader_parameter("encre_style"))
	_check("une encre de fumée demandée nommément %s" % ("cède à l'essai" if sans_encre else "se pose"),
		demandee == (aucune if sans_encre else int(IsoNuageVoxel.ENCRES["hachures"])))


func _le_trait_des_murs(sans_encre: bool) -> void:
	print("— le trait halogène des masses de murs (MurEncre, lu par la lightmap)")
	# Le headless ne rastérise rien : on lit `_draw`. Le lavis (une ombre de contact) doit précéder la garde, le trait la suivre.
	var source := FileAccess.get_file_as_string("res://mur_encre.gd")
	var debut := source.find("func _draw() -> void:")
	var fin := source.find("\nfunc ", debut + 1)
	var corps_draw := source.substr(debut, fin - debut) if debut >= 0 else ""
	var garde := corps_draw.find("if not IsoMateriaux.encre_active():")
	var lavis := corps_draw.find("_dessiner_lavis(")
	var pos_trait := corps_draw.find("_dessiner_trait(")
	_check("MurEncre._draw se garde de l'essai sans encre AVANT de tracer, APRÈS le lavis",
		garde > 0 and lavis >= 0 and lavis < garde and pos_trait > garde,
		"garde %d, lavis %d, trait %d" % [garde, lavis, pos_trait])
	_check("la garde rend la main (aucun trait sous elle)",
		corps_draw.substr(garde, corps_draw.find("\n", corps_draw.find("\n", garde) + 1) - garde).contains("return"))
	_check("%s : le trait %s" % ["sans encre" if sans_encre else "par défaut", "part" if sans_encre else "se trace"],
		IsoMateriaux.encre_active() == not sans_encre)
