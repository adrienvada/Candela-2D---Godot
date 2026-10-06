## Chantier RR, étape RR1 — le rendu en jeu sans la pâte roman graphique (Adrien, 2026-10-05 : « Q83, je préfère "brute,
## sans paliers" », puis « Essayons de voir les graphismes en annulant, en jeu (pas dans les menus) cette pâte roman
## graphique : visons un style plus réaliste. Plus fluide. Plus oppressant »).
##
##   • **Q83 : la pâte brute par défaut**, aux TROIS endroits où le défaut est écrit — `Presentation3D.PATE_PAR_DEFAUT`,
##     `VoxelCorps.STYLE_PAR_DEFAUT`, `VoxelObjets.STYLE_PAR_DEFAUT` : un seul en retard, et la première image d'un corps ou
##     d'un objet neuf sortirait en lavis. `--pate D` remet le rendu d'avant (le nom se lit encore).
##   • **L'encre en jeu** (`IsoMateriaux.encre_active` ; RR1 l'essayait sous `--sans-encre`) : sur des matériaux neufs accordés par les
##     fonctions mêmes du jeu (`accorder_mur`, `accorder_corps`, `IsoNuageVoxel.poser_style`), l'encre NOIRE part, et elle
##     seule — la matière, la température, le contact, le liseré du sommet (la lumière de la face) restent. Sans le drapeau,
##     le jeu d'avant, réglage pour réglage. `MurEncre` ne trace plus son trait halogène : lu dans son `_draw` (le headless ne
##     rastérise rien, la planche de RR1 le montre).
##
## Étape RR2 — **la lumière peinte** (`pate_courbe`, `iso_pate.gdshaderinc` ; miroir `IsoPate.courbe`) : au-dessus de son pied
## les mi-tons et les cœurs sont relevés, le cœur pâli vers le blanc ; sous lui, rien ne bouge. Gardé ici : les propriétés
## (force 0 inerte, rien sous le pied, luminance jamais plus basse et croissante, rien au-delà du blanc), un effet RÉEL sur la
## luminance de l'OCTET (posée d'abord sur la valeur décodée, la courbe ne touchait presque rien — l'algèbre seule ne l'aurait
## pas vu, une garde nommée le voit), l'accord du shader et du miroir, et la force posée par les matériaux du jeu.
##
## Étape RR3 — **l'encre devient l'exception** (Q90 = (b) : sans drapeau, aucune encre ; `--avec-encre` la remet, et le trait
## des murs avec elle ; `--sans-encre` l'emporte toujours) et **la lueur des LED au pied des murs** la remplace (`lumiere_des_led`,
## `IsoMateriaux.lueur_led`, `Presentation3D._accorder_la_lueur_led`) : posée par le matériau du jeu, nulle sous l'encre ou
## `--sans-lueur-led`, la même fonction dans le mur et le mur éclairé, la couleur de la bande relue à chaque image.
##
## Jouée cinq fois par `run_suites.sh` : sans drapeau (`test_rendu_rr`), `test_rendu_rr_avec_encre` (`--avec-encre`),
## `test_rendu_rr_sans_encre` (`--sans-encre --encre-essai` : le retrait doit l'emporter), `test_rendu_rr_sans_courbe`
## (`--sans-courbe`), `test_rendu_rr_sans_lueur` (`--sans-lueur-led`).
## Lancer : godot --headless --path . --script res://tools/test_rendu_rr.gd [-- --avec-encre | --sans-encre | --sans-courbe | --sans-lueur-led]
extends SceneTree

const IsoPate := preload("res://iso_pate.gd")
const Charte := preload("res://charte.gd")

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
	print("=== RR — LE RENDU EN JEU : LA BRUTE (RR1), LA LUMIÈRE PEINTE (RR2), L'ENCRE EN EXCEPTION ET LA LUEUR DES LED (RR3) ===")
	await process_frame
	var sans_encre := not IsoMateriaux.encre_active()
	print("  (encre : %s)" % ("aucune — le jeu" if sans_encre else "OUI, demandée (" + " ".join(
		DrapeauxDeLancement.arguments()) + ")"))
	var sans_courbe := DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_SANS_COURBE)
	print("  (sans la courbe : %s)" % ("OUI, " + IsoMateriaux.DRAPEAU_SANS_COURBE if sans_courbe else "non — le jeu par défaut"))
	_l_encre_par_defaut()
	_la_pate_par_defaut()
	_l_encre_des_murs(sans_encre)
	_l_encre_des_corps(sans_encre)
	_l_encre_de_la_fumee(sans_encre)
	_le_trait_des_murs(sans_encre)
	_la_courbe_au_miroir()
	_la_courbe_dans_les_shaders()
	_la_courbe_des_materiaux(sans_courbe)
	_la_lueur_des_led_dans_les_shaders()
	_la_lueur_des_led_posee()
	print("%d vérifications, %d échec(s)" % [_verifications, _failures])
	quit(1 if _failures > 0 else 0)


func _constante(chemin: String, nom: String) -> Variant:
	return (load(chemin) as GDScript).get_script_constant_map().get(nom)


## Un réglage lu sur un matériau : -1 s'il n'a jamais été posé. `float(null)` est une ERREUR DE SCRIPT, qui arrête la fonction
## sans faire échouer aucune vérification (le test sortait en 0) — vu par le sabotage « accorder_mur oublie la courbe ».
func _reglage(mat: ShaderMaterial, nom: String) -> float:
	var v: Variant = mat.get_shader_parameter(nom)
	return float(v) if v != null else -1.0


# ---------------------------------------------------------------------------
# RR3 (Q90 = b) — L'ENCRE EST L'EXCEPTION
# ---------------------------------------------------------------------------

func _l_encre_par_defaut() -> void:
	print("— RR3 : l'encre est l'exception (Q90 = (b))")
	var avec := DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_AVEC_ENCRE)
	var essai := DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_ENCRE_ESSAI)
	var sans := DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_SANS_ENCRE)
	if not avec and not essai and not sans:
		_check("sans drapeau d'encre, le jeu n'en pose aucune", not IsoMateriaux.encre_active())
	if avec and not sans:
		_check("--avec-encre la remet", IsoMateriaux.encre_active())
	if sans:
		_check("--sans-encre l'emporte sur tout autre drapeau", not IsoMateriaux.encre_active())
	# La règle, lue dans son code (les drapeaux d'une exécution n'en jouent qu'un cas) : le retrait d'abord, puis l'un des deux.
	var corps := _fonction(FileAccess.get_file_as_string("res://iso_materiaux.gd"), "static func encre_active() -> bool:")
	_check("la règle : --sans-encre d'abord, puis --avec-encre ou --encre-essai, sinon aucune encre",
		corps.contains("if DrapeauxDeLancement.present(DRAPEAU_SANS_ENCRE):\n\t\treturn false")
		and corps.contains("return DrapeauxDeLancement.present(DRAPEAU_AVEC_ENCRE) or DrapeauxDeLancement.present(DRAPEAU_ENCRE_ESSAI)"),
		corps)


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
		_check("avec encre : les arêtes, comme avant RR3 (%.1f px, reste %.2f)" % [px, reste],
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
		_check("avec encre : les arêtes des voxels, comme avant RR3 (%.2f px)" % largeur,
			is_equal_approx(largeur, IsoMateriaux.ENCRE_VOXEL_PX))
	_check("le modelé des corps reste", is_equal_approx(float(corps.get_shader_parameter("modele")), 1.0))
	# `run_suites.sh` joue `--sans-encre` AVEC `--encre-essai` : la préséance se joue pour de vrai.
	if DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_SANS_ENCRE) and DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_ENCRE_ESSAI):
		_check("l'encre renforcée, demandée aussi (--encre-essai), cède à --sans-encre",
			not IsoMateriaux.encre_essai_active() and not IsoMateriaux.encre_active())


func _l_encre_de_la_fumee(sans_encre: bool) -> void:
	print("— l'encre de la fumée")
	var nuage := ShaderMaterial.new()
	nuage.shader = load("res://nuage_voxel_iso.gdshader")
	IsoNuageVoxel.poser_style(nuage, IsoNuageVoxel.ENCRE_PAR_DEFAUT, IsoNuageVoxel.RELIEF_PAR_DEFAUT)
	var style := int(nuage.get_shader_parameter("encre_style"))
	var aucune := int(IsoNuageVoxel.ENCRES["aucune"])
	var attendu := aucune if sans_encre else int(IsoNuageVoxel.ENCRES[IsoNuageVoxel.ENCRE_PAR_DEFAUT])
	_check("%s : l'encre de la fumée est « %s » (%d)" % ["sans encre" if sans_encre else "avec encre",
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
	_check("%s : le trait %s" % ["sans encre" if sans_encre else "avec encre", "part" if sans_encre else "se trace"],
		IsoMateriaux.encre_active() == not sans_encre)


# ---------------------------------------------------------------------------
# RR2 — LA LUMIÈRE PEINTE
# ---------------------------------------------------------------------------

## Un nuancier : des gris, l'ambre des torches, la braise, le rouge de la fusée, le carmin, un bleu — chacun à toutes les
## intensités, jusqu'au-delà du blanc (une lightmap additive peut le dépasser).
func _nuancier() -> Array[Vector3]:
	var teintes: Array[Vector3] = [Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.78, 0.45), Vector3(1.0, 0.6, 0.2),
		Vector3(1.0, 0.12, 0.12), Vector3(0.7, 0.05, 0.2), Vector3(0.3, 0.5, 1.0)]
	var couleurs: Array[Vector3] = []
	for teinte: Vector3 in teintes:
		for i in 61:
			couleurs.append(teinte * (float(i) / 40.0))
	return couleurs


func _la_courbe_au_miroir() -> void:
	print("— RR2 : la lumière peinte, au miroir (`IsoPate.courbe`)")
	var force := IsoMateriaux.COURBE_LUMIERE
	_check("la force du jeu est une vraie force, dans ]0, 1] (%.2f)" % force, force > 0.0 and force <= 1.0)
	var noir := 8.0 / 255.0
	_check("le pied (%.3f, %.1f/255 écrit) est au-dessus du point noir écrit (8/255), avec marge" % [IsoPate.COURBE_PIED,
		IsoPate.COURBE_PIED * 255.0], IsoPate.COURBE_PIED >= 1.5 * noir,
		"un pied au niveau du noir laisserait la courbe faire entrer ou sortir un pixel du noir")
	_check("pied < genou < 1 et blanc < 1 : la courbe a une forme", IsoPate.COURBE_PIED < IsoPate.COURBE_GENOU
		and IsoPate.COURBE_GENOU < 1.0 and IsoPate.COURBE_BLANC < 1.0)
	var inerte := true
	var sous_le_pied := true
	var jamais_plus_bas := true
	var sous_le_blanc := true
	var zero := true
	var pire := ""
	for f: float in [0.35, force, 1.0]:
		for c: Vector3 in _nuancier():
			var r := IsoPate.courbe(c, f)
			inerte = inerte and IsoPate.courbe(c, 0.0) == c
			var l := IsoPate.luminance(c)
			if l <= IsoPate.COURBE_PIED:
				sous_le_pied = sous_le_pied and r == c
			if IsoPate.luminance(r) < l - 0.000001:
				jamais_plus_bas = false
				pire = "%s → %s" % [str(c), str(r)]
			# Une couleur affichable le reste : le relèvement ne fabrique pas de surexposition.
			if c[0] <= 1.0 and c[1] <= 1.0 and c[2] <= 1.0:
				for i in 3:
					sous_le_blanc = sous_le_blanc and r[i] <= 1.000001
		zero = zero and IsoPate.courbe(Vector3.ZERO, f) == Vector3.ZERO
	_check("force 0 : la lumière telle quelle, à toute couleur et toute intensité", inerte)
	_check("sous le pied, la lumière telle quelle : la lueur faible (l'information) et le noir ne bougent pas", sous_le_pied)
	_check("0 → 0 : le noir absolu reste noir", zero)
	_check("au-dessus du pied, la luminance ne descend jamais (aucun pixel n'entre dans le noir)", jamais_plus_bas, pire)
	_check("une couleur affichable le reste : aucune composante poussée au-delà du blanc", sous_le_blanc)
	# Croissante : une lumière plus forte reste plus claire, à toute teinte — l'ordre des lumières, c'est l'information.
	var croissante := true
	for teinte: Vector3 in [Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.6, 0.2), Vector3(1.0, 0.12, 0.12)]:
		var avant := -1.0
		for i in 401:
			var l := IsoPate.luminance(IsoPate.courbe(teinte * (float(i) / 400.0), force))
			croissante = croissante and l >= avant - 0.000001
			avant = l
	_check("croissante : une lumière plus forte reste plus claire, gris, ambre et rouge (pas de 1/400)", croissante)
	# L'effet existe, et il est sur l'OCTET : un gris de 100/255 (le cœur d'une flaque de plafonnier au banc) monte d'au moins
	# 20/255. Posée sur la valeur décodée (le premier câblage), la courbe le laissait à 100 : décodé, il ne valait que 0,13.
	var cœur := Vector3.ONE * (100.0 / 255.0)
	var monte := (IsoPate.luminance(IsoPate.courbe(cœur, force)) - IsoPate.luminance(cœur)) * 255.0
	_check("un cœur de flaque à 100/255 monte d'au moins 20/255 (%.1f) : la courbe agit sur l'octet" % monte, monte >= 20.0,
		"une courbe posée sur la valeur décodée laisse ce gris en place")
	# Et une flaque à 40/255 (son bord) bouge peu : le dégradé se creuse, c'est le cœur qui monte.
	var bord := Vector3.ONE * (40.0 / 255.0)
	var bouge := (IsoPate.luminance(IsoPate.courbe(bord, force)) - IsoPate.luminance(bord)) * 255.0
	_check("le bord de la flaque (40/255) bouge moins que le cœur (%.1f contre %.1f)" % [bouge, monte],
		bouge < monte * 0.5)
	# Le cœur pâlit vers le blanc, mais seulement d'une lumière neutre : la fusée rouge garde son rouge, l'ambre des LED le sien.
	var halogene := Vector3(1.0, 0.92, 0.8) * 0.9
	var rouge := Vector3(1.0, 0.12, 0.12) * 0.95
	var h := IsoPate.courbe(halogene, force)
	var r := IsoPate.courbe(rouge, force)
	var ecart_h := (h.x - h.z) / h.x
	var ecart_r := (r.x - r.y) / r.x
	_check("le cœur d'une lumière halogène pâlit (écart de teinte %.3f → %.3f)" % [(halogene.x - halogene.z) / halogene.x,
		ecart_h], ecart_h < (halogene.x - halogene.z) / halogene.x - 0.02)
	_check("la fusée rouge garde son rouge (écart de teinte %.3f → %.3f)" % [(rouge.x - rouge.y) / rouge.x, ecart_r],
		is_equal_approx(ecart_r, (rouge.x - rouge.y) / rouge.x))
	# Le rouge de la fusée (luminance 0,29) n'atteint jamais le seuil du blanchiment : seul l'ambre des LED, vif (0,72), dit si
	# le poids de neutralité tient — vu par le sabotage qui le retire, que la fusée laissait passer.
	var ambre := Vector3(Charte.AMBRE.r, Charte.AMBRE.g, Charte.AMBRE.b)
	var a := IsoPate.courbe(ambre, force)
	_check("l'ambre des LED, vif (luminance %.2f), garde sa teinte (%.3f → %.3f)" % [IsoPate.luminance(ambre),
		(ambre.x - ambre.z) / ambre.x, (a.x - a.z) / a.x], IsoPate.luminance(ambre) > IsoPate.COURBE_BLANC
		and is_equal_approx((a.x - a.z) / a.x, (ambre.x - ambre.z) / ambre.x))


func _la_courbe_dans_les_shaders() -> void:
	print("— RR2 : la courbe dans les shaders")
	var inc := FileAccess.get_file_as_string("res://iso_pate.gdshaderinc")
	# Les constantes du shader sont celles du miroir.
	for paire: Array in [["PATE_COURBE_PIED", IsoPate.COURBE_PIED], ["PATE_COURBE_GENOU", IsoPate.COURBE_GENOU],
			["PATE_COURBE_BLANC", IsoPate.COURBE_BLANC]]:
		var cle := "const float %s = " % paire[0]
		var i := inc.find(cle)
		var valeur := inc.substr(i + cle.length(), inc.find(";", i) - i - cle.length()) if i >= 0 else ""
		_check("%s du shader = celui du miroir (%s)" % [paire[0], valeur],
			valeur.is_valid_float() and is_equal_approx(valeur.to_float(), float(paire[1])))
	var debut := inc.find("vec3 pate_courbe(vec3 c, float force) {")
	var fin := inc.find("\n}\n", debut)
	var corps := inc.substr(debut, fin - debut) if debut >= 0 else ""
	_check("`pate_courbe` existe dans l'include partagé", debut >= 0)
	_check("`pate_courbe` lit la luminance de l'octet, jamais la valeur décodée (`pate_vers_affiche`)",
		corps.contains("float s = pate_luminance(c);") and not corps.contains("pate_vers_affiche")
		and not corps.contains("pate_depuis_affiche"))
	# Les cinq matériaux qui la portent : déclarée, appelée une fois, AVANT la température.
	for paire: Array in [["res://sol_iso.gdshader", "c = pate_courbe(c, courbe);"],
			["res://mur_iso.gdshader", "c = pate_courbe(c, courbe);"],
			["res://sol_iso_eclaire.gdshader", "c2d = pate_courbe(c2d, courbe);"],
			["res://mur_iso_eclaire.gdshader", "c = pate_courbe(c, courbe);"],
			["res://nuage_voxel_iso.gdshader", "col = pate_courbe(col, courbe);"]]:
		var code := FileAccess.get_file_as_string(paire[0])
		var appel: String = paire[1]
		var i_appel := code.find(appel)
		var i_temperature := code.find("pate_temperature", maxi(i_appel, 0))
		_check("%s : `courbe` déclarée, appelée une fois, avant la température" % paire[0].get_file(),
			code.contains("uniform float courbe") and i_appel > 0 and code.count(appel) == 1
			and i_temperature > i_appel and code.count("pate_courbe(") == 1,
			"appel %d, température %d" % [i_appel, i_temperature])


func _la_courbe_des_materiaux(sans_courbe: bool) -> void:
	print("— RR2 : la force posée par les matériaux du jeu")
	var attendu := 0.0 if sans_courbe else IsoMateriaux.COURBE_LUMIERE
	var quoi := "sans courbe : 0" if sans_courbe else "par défaut : %.2f" % attendu
	var sol := ShaderMaterial.new()
	sol.shader = load("res://sol_iso.gdshader")
	IsoMateriaux.accorder_sol(sol)
	_check("le sol (%s)" % quoi, is_equal_approx(_reglage(sol, "courbe"), attendu))
	var mur := ShaderMaterial.new()
	mur.shader = load("res://mur_iso.gdshader")
	IsoMateriaux.accorder_mur(mur)
	_check("les murs (%s)" % quoi, is_equal_approx(_reglage(mur, "courbe"), attendu))
	# La variante éclairée (`lumiere_3d`) reprend le matériau du mur : le réglage tient au changement de shader.
	mur.shader = load("res://mur_iso_eclaire.gdshader")
	IsoMateriaux.accorder_mur(mur)
	_check("les murs éclairés (%s)" % quoi, is_equal_approx(_reglage(mur, "courbe"), attendu))
	var nuage := IsoNuageVoxel.materiau("cartouche_suie", 0, 4.0, 20.0, 0)
	_check("la fumée (%s)" % quoi, is_equal_approx(_reglage(nuage, "courbe"), attendu))
	# Sans beauté, la courbe s'éteint comme la température (lu dans le code : la suite ne rejoue pas `--sans-beaute` ici).
	var source := FileAccess.get_file_as_string("res://iso_materiaux.gd")
	var i := source.find("static func courbe_lumiere() -> float:")
	_check("sans beauté, aucune courbe (`courbe_lumiere` rend 0 hors beauté)",
		i >= 0 and source.substr(i, 200).contains("if not beaute_active() or"))


# ---------------------------------------------------------------------------
# RR3 (Q90 = b) — LA LUEUR DES LED AU PIED DES MURS
# ---------------------------------------------------------------------------

const LIGNE_PART := "float part_led = clamp(pate_luminance(lumiere_des_led(monde.xz + n * pied, peinture_ref)) / max(pate_luminance(brute), 0.0001), 0.0, 1.0);"
const LIGNE_LUEUR := "c = pate_facteur(c, 1.0 + led_lueur * exp(-hauteur_face / led_lueur_px) * part_led);"


func _la_lueur_des_led_dans_les_shaders() -> void:
	print("— RR3 : la lueur des LED dans les shaders des murs")
	var mur := FileAccess.get_file_as_string("res://mur_iso.gdshader")
	var eclaire := FileAccess.get_file_as_string("res://mur_iso_eclaire.gdshader")
	var tous := true
	for u in ["uniform sampler2D led_texture", "uniform bool led_active", "uniform vec2 led_origine_px", "uniform vec2 led_taille_px",
			"uniform vec3 led_couleur", "uniform float led_lueur", "uniform float led_lueur_px"]:
		tous = tous and mur.contains(u) and eclaire.contains(u)
	_check("le mur du jeu et le mur éclairé déclarent la bande et la lueur", tous)
	var f_mur := _fonction(mur, "vec3 lumiere_des_led(vec2 px, vec3 ref) {")
	var f_eclaire := _fonction(eclaire, "vec3 lumiere_des_led(vec2 px, vec3 ref) {")
	_check("`lumiere_des_led` : la même dans les deux murs", f_mur != "" and f_mur == f_eclaire)
	# Le noir absolu : rien sans bande allumée, rien sans lueur — la sortie EN TÊTE, avant toute lecture.
	_check("`lumiere_des_led` rend 0 sans bande ou sans lueur, avant toute lecture, et 0 hors du rectangle de la bande",
		f_mur.find("if (!led_active || led_lueur <= 0.0) {\n\t\treturn vec3(0.0);\n\t}") > 0
		and f_mur.find("if (!led_active || led_lueur <= 0.0)") < f_mur.find("textureLod(")
		and f_mur.contains("if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {\n\t\treturn vec3(0.0);")
		and f_mur.contains("return textureLod(led_texture, uv, 0.0).a * led_couleur * ref;"))
	# La ligne : sur la face verticale, après la matière, l'encre et le contact, avant la courbe et la température.
	var i_ligne := mur.find(LIGNE_LUEUR)
	var i_matiere := mur.find("c = pate_matiere_et_encre(c, matiere * lambert * contact, encre_arete_reste")
	var i_courbe := mur.find("c = pate_courbe(c, courbe);")
	_check("mur du jeu : la lueur se pose sur la face, après la matière et le contact, avant la courbe — une fois",
		i_ligne > 0 and mur.count(LIGNE_LUEUR) == 1 and i_matiere > 0 and i_matiere < i_ligne and i_ligne < i_courbe,
		"matière %d, lueur %d, courbe %d" % [i_matiere, i_ligne, i_courbe])
	# Un FACTEUR sur la lumière lue, pondéré par la part de la bande dans cette lumière : jamais un terme (`c +=`), qui
	# éclairerait une face que la lightmap laisse noire — la règle d'ISO7, gardée aussi par `test_iso_beaute`.
	var i_part := mur.find(LIGNE_PART)
	_check("mur du jeu : la lueur relève la PART de la bande dans la lumière reçue (lue juste avant), sans terme ajouté",
		i_part > i_matiere and i_part < i_ligne and mur.count(LIGNE_PART) == 1 and not mur.contains("c += ")
		and eclaire.count(LIGNE_PART) == 1)
	var i_identite := eclaire.find("if (identite_2d) {\n\t\t\t// Chantier RR, RR3")
	_check("mur éclairé : la même ligne, au chemin 2D seulement (l'ancien chemin a sa LED en émission)",
		eclaire.count(LIGNE_LUEUR) == 1 and i_identite > 0 and eclaire.find(LIGNE_LUEUR) > i_identite)


func _la_lueur_des_led_posee() -> void:
	print("— RR3 : la lueur des LED, posée par le jeu")
	var encre := IsoMateriaux.encre_active()
	var sans := DrapeauxDeLancement.present(IsoMateriaux.DRAPEAU_SANS_LUEUR_LED)
	var attendu := 0.0 if encre or sans else IsoMateriaux.LUEUR_LED
	var pourquoi := "l'encre est là, et son trait" if encre else ("--sans-lueur-led" if sans else "le jeu")
	_check("la lueur du jeu est une vraie lueur (facteur %.1f au ras du sol sur la part de la bande, retombé à 1/e à %.0f px)" % [
		IsoMateriaux.LUEUR_LED, IsoMateriaux.LUEUR_LED_PX], IsoMateriaux.LUEUR_LED > 1.0 and IsoMateriaux.LUEUR_LED_PX > 0.0)
	for chemin in ["res://mur_iso.gdshader", "res://mur_iso_eclaire.gdshader"]:
		var mur := ShaderMaterial.new()
		mur.shader = load(chemin)
		IsoMateriaux.accorder_mur(mur)
		_check("%s : lueur %.1f (%s)" % [chemin.get_file(), attendu, pourquoi],
			is_equal_approx(_reglage(mur, "led_lueur"), attendu)
			and is_equal_approx(_reglage(mur, "led_lueur_px"), IsoMateriaux.LUEUR_LED_PX))
	var regle := _fonction(FileAccess.get_file_as_string("res://iso_materiaux.gd"), "static func lueur_led() -> float:")
	_check("sans beauté, et sous l'encre (le trait reprend sa place), aucune lueur",
		regle.contains("if not beaute_active() or encre_active() or DrapeauxDeLancement.present(DRAPEAU_SANS_LUEUR_LED):\n\t\treturn 0.0"))
	# La présentation : la bande de CETTE image, relue sur la lumière, à chaque image, lumière 3D allumée ou non.
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	var i_suivre := pres.find("func _suivre() -> void:")
	var i_appel := pres.find("_accorder_la_lueur_led()", i_suivre)
	var i_lumieres := pres.find("if _lumieres != null:", i_suivre)
	_check("la présentation repose la bande à chaque image (`_suivre`), hors de la branche de la lumière 3D",
		i_suivre > 0 and i_appel > i_suivre and i_appel < i_lumieres and pres.find("\nfunc ", i_suivre + 1) > i_lumieres)
	var accorder := _fonction(pres, "func _accorder_la_lueur_led() -> void:")
	_check("…relue sur la lumière : sa couleur × son énergie, NOIRE éteinte ou cachée",
		accorder.contains("if led.enabled and led.is_visible_in_tree():")
		and accorder.contains("couleur = Vector3(led.color.r, led.color.g, led.color.b) * led.energy")
		and accorder.contains("var couleur := Vector3.ZERO")
		and accorder.contains("_mat_mur.set_shader_parameter(\"led_couleur\", couleur)"))


## Le texte d'une fonction (shader ou script) : de sa signature à la première ligne vide qui la suit.
func _fonction(texte: String, signature: String) -> String:
	var i := texte.find(signature)
	if i < 0:
		return ""
	var fin := texte.find("\n\n", i)
	return texte.substr(i, (fin if fin >= 0 else texte.length()) - i)
