## Test headless des corps voxel (`voxel_corps.gd` + `voxel_catalogue.gd`) —
## chantier ISO, étape ISO3 (vague 0 : les dix corps ; vague 1 : accroupi et
## enjambement).
##
## Ce que la suite garantit :
##   • les dix classes du CATALOGUE se construisent, neuf boîtes chacune ;
##   • le catalogue ne dérive pas des dix classes réelles de `game_state.gd` ;
##   • `poser(etat)` est déterministe : même état → même pose, à l'identique,
##     accroupi et enjambement compris ;
##   • aucune partie du corps ne passe sous le sol, hors la pose de mort ;
##   • le cycle de marche est continu : deux `t` voisins ne sautent pas de pose ;
##   • la pose de mort finale est bien couchée (rotation figée) ;
##   • la hauteur accroupie (sommet de la tête) tombe dans la fourchette
##     0,5-0,6 de la hauteur debout, pour les dix classes ;
##   • l'angle de la jambe qui enjambe progresse de façon monotone avec
##     `etat.enjambe` — jamais de retour en arrière pendant le geste ;
##   • le matériau rend un noir strict à `lumiere_recue = 0` (couleur non nulle,
##     mais le facteur qui la multiplie l'est), accroupi et enjambement compris ;
##   • ni `voxel_corps.gd` ni `voxel_catalogue.gd` n'appellent `randi`/`randf`.
##
## Lancer : godot --headless --path . --script res://tools/test_voxel_corps.gd
extends SceneTree

const PLANCHER := 40
const EPSILON := 0.0005
## Fourchette du brief ISO3 vague 1 pour la hauteur accroupie (fraction de la
## hauteur debout). Une marge de 0,01 des deux côtés absorbe l'arrondi flottant
## sans élargir la fourchette que le brief a posée.
const ACCROUPI_MIN := 0.49
const ACCROUPI_MAX := 0.61

var _failures: int = 0
var _verifications: int = 0


func _init() -> void:
	print("=== Test des corps voxel (ISO3) ===")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var VoxelCorps: GDScript = load("res://voxel_corps.gd")
	var VoxelCatalogue: GDScript = load("res://voxel_catalogue.gd")
	_check("voxel_corps.gd se charge", VoxelCorps != null)
	_check("voxel_catalogue.gd se charge", VoxelCatalogue != null)
	if VoxelCorps == null or VoxelCatalogue == null:
		_terminer()
		return

	_test_aucun_hasard()
	_test_catalogue_a_jour(VoxelCatalogue)

	var slugs: PackedStringArray = VoxelCatalogue.slugs()
	_check("dix classes dans le catalogue (%d)" % slugs.size(), slugs.size() == 10)

	var hauteur_debout: float = float(VoxelCatalogue.SQUELETTE["y0_tete"]) \
		+ float(VoxelCatalogue.SQUELETTE["hauteur_tete"])

	var boites_de_reference := -1
	for slug in slugs:
		boites_de_reference = _test_classe(VoxelCorps, slug, boites_de_reference, hauteur_debout)

	_check("au moins %d vérifications ont réellement tourné" % PLANCHER,
		_verifications >= PLANCHER, "%d" % _verifications)
	_terminer()


func _terminer() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	_verifications += 1
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


# ---------------------------------------------------------------------------
# UNE CLASSE
# ---------------------------------------------------------------------------

func _test_classe(VoxelCorps: GDScript, slug: String, boites_attendues: int,
		hauteur_debout: float) -> int:
	print("\n[%s]" % slug)
	var corps: Node3D = VoxelCorps.new()
	root.add_child(corps)

	var ok: bool = corps.construire(slug)
	_check("construction réussie", ok)
	if not ok:
		root.remove_child(corps)
		corps.free()
		return boites_attendues

	_check("neuf boîtes (%d)" % corps.nombre_de_boites(), corps.nombre_de_boites() == 9,
		"%d" % corps.nombre_de_boites())
	if boites_attendues < 0:
		boites_attendues = corps.nombre_de_boites()
	else:
		_check("même nombre de boîtes que les classes précédentes",
			corps.nombre_de_boites() == boites_attendues)

	_test_determinisme(corps)
	_test_hors_du_sol(corps)
	_test_marche_continue(corps)
	_test_mort_couchee(corps)
	_test_noir_absolu(corps)
	_test_accroupi(corps, hauteur_debout)
	_test_enjambement(corps)

	root.remove_child(corps)
	corps.free()
	return boites_attendues


# ---------------------------------------------------------------------------
# DÉTERMINISME
# ---------------------------------------------------------------------------

func _test_determinisme(corps: Node3D) -> void:
	_verifier_determinisme(corps, {
		"position": Vector2(140.0, -60.0), "visee": Vector2(0.7, -0.7),
		"vitesse": Vector2(180.0, 40.0), "torche": true, "arme": corps.slug(),
		"tir": true, "touche": true, "mort": false, "accroupi": false, "enjambe": 0.0,
		"t": 0.37,
	}, "même état → même pose (marche/tir/touché)")
	_verifier_determinisme(corps, {
		"position": Vector2(-30.0, 90.0), "visee": Vector2(-1.0, 0.0),
		"vitesse": Vector2(55.0, 0.0), "torche": true, "arme": corps.slug(),
		"tir": false, "touche": false, "mort": false, "accroupi": true, "enjambe": 0.0,
		"t": 0.08,
	}, "même état → même pose (accroupi, en transition)")
	_verifier_determinisme(corps, {
		"position": Vector2(0.0, 0.0), "visee": Vector2(0.0, 1.0),
		"vitesse": Vector2.ZERO, "torche": true, "arme": corps.slug(),
		"tir": false, "touche": false, "mort": false, "accroupi": false, "enjambe": 0.63,
		"t": 0.0,
	}, "même état → même pose (enjambement)")


func _verifier_determinisme(corps: Node3D, etat: Dictionary, label: String) -> void:
	corps.poser(etat)
	var a := _empreinte(corps)
	# Un second dictionnaire, distinct en mémoire mais identique en valeur :
	# la pureté se juge sur l'état, jamais sur l'objet qui le porte.
	var etat2 := etat.duplicate(true)
	corps.poser(etat2)
	var b := _empreinte(corps)
	_check(label, a == b, "%s ≠ %s" % [str(a), str(b)])


## Toutes les transformations qui comptent, réduites à des nombres comparables.
func _empreinte(corps: Node3D) -> Array:
	var out: Array = []
	_empreinte_recursive(corps, out)
	out.append(corps.materiau().get_shader_parameter("lumiere_recue"))
	return out


func _empreinte_recursive(n: Node3D, out: Array) -> void:
	out.append(n.position)
	out.append(n.rotation)
	out.append(n.scale)
	out.append(n.visible)
	for enfant in n.get_children():
		if enfant is Node3D:
			_empreinte_recursive(enfant, out)


# ---------------------------------------------------------------------------
# RIEN SOUS LE SOL (hors mort)
# ---------------------------------------------------------------------------

func _test_hors_du_sol(corps: Node3D) -> void:
	var pire := INF
	for vitesse in [Vector2.ZERO, Vector2(220.0, 0.0), Vector2(0.0, -260.0)]:
		for i in 12:
			var t := i * 0.11
			corps.poser({
				"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": vitesse,
				"torche": true, "arme": corps.slug(), "tir": (i % 5 == 0),
				"touche": (i % 4 == 0), "mort": false, "t": t,
			})
			pire = minf(pire, _y_minimum(corps))
	_check("aucune partie sous le sol hors mort (min y = %.4f)" % pire, pire >= -EPSILON,
		"%.4f" % pire)


func _y_minimum(n: Node3D) -> float:
	var pire: float = n.global_transform.origin.y
	if n is MeshInstance3D:
		var aabb: AABB = (n as MeshInstance3D).get_aabb()
		var bas := n.to_global(Vector3(0.0, aabb.position.y, 0.0))
		pire = minf(pire, bas.y)
	for enfant in n.get_children():
		if enfant is Node3D:
			pire = minf(pire, _y_minimum(enfant))
	return pire


# ---------------------------------------------------------------------------
# MARCHE CONTINUE
# ---------------------------------------------------------------------------

func _test_marche_continue(corps: Node3D) -> void:
	var dt := 0.001
	var saut_max := 0.0
	var precedent := NAN
	for i in 200:
		var t := i * 0.01
		corps.poser({
			"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2(240.0, 0.0),
			"torche": true, "arme": corps.slug(), "tir": false, "touche": false,
			"mort": false, "t": t,
		})
		var angle_a: float = corps.get_node("JambeDroite").rotation.x
		corps.poser({
			"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2(240.0, 0.0),
			"torche": true, "arme": corps.slug(), "tir": false, "touche": false,
			"mort": false, "t": t + dt,
		})
		var angle_b: float = corps.get_node("JambeDroite").rotation.x
		if not is_nan(precedent):
			saut_max = maxf(saut_max, absf(angle_b - angle_a))
		precedent = angle_b
	# À vitesse constante, un pas de temps de 1 ms ne peut faire bouger un angle
	# borné à ±0,42 rad que d'une fraction infime : 0,05 rad laisse une marge
	# large sans laisser passer un vrai saut de pose (un changement de branche
	# donnerait un écart de l'ordre de l'amplitude elle-même).
	_check("cycle de marche continu (saut max %.4f rad)" % saut_max, saut_max < 0.05,
		"%.4f" % saut_max)


# ---------------------------------------------------------------------------
# MORT
# ---------------------------------------------------------------------------

func _test_mort_couchee(corps: Node3D) -> void:
	corps.poser({
		"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
		"torche": false, "arme": "", "tir": false, "touche": false,
		"mort": true, "t": 3.0,
	})
	var angle := corps.rotation.x
	_check("pose de mort finale couchée (rotation.x = %.3f)" % angle,
		absf(angle - deg_to_rad(-90.0)) < 0.01, "%.3f" % angle)

	# Figée : au-delà du dernier palier, `t` qui continue de courir ne doit
	# plus rien changer — sans quoi un corps mort continuerait de « tomber ».
	corps.poser({
		"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
		"torche": false, "arme": "", "tir": false, "touche": false,
		"mort": true, "t": 30.0,
	})
	_check("pose de mort figée au-delà du dernier palier",
		absf(corps.rotation.x - angle) < 0.0001)


# ---------------------------------------------------------------------------
# NOIR ABSOLU
# ---------------------------------------------------------------------------

func _test_noir_absolu(corps: Node3D) -> void:
	var mat: ShaderMaterial = corps.materiau()
	var lumiere: float = mat.get_shader_parameter("lumiere_recue")
	_check("lumiere_recue à 0 par défaut", lumiere == 0.0, "%s" % str(lumiere))
	var couleur: Color = mat.get_shader_parameter("couleur_fiche")
	_check("la couleur de la fiche n'est pas déjà noire (sinon le test ne prouve rien)",
		couleur.r + couleur.g + couleur.b > 0.01)
	# Le shader fait `ALBEDO = couleur_fiche.rgb * lumiere_recue` : à lumière
	# nulle, l'algèbre suffit à garantir le noir — la preuve par le pixel réel
	# est le travail du banc (`--lumiere 0`, non headless, voir sa suite).
	corps.definir_lumiere(0.5)
	corps.definir_lumiere(0.0)
	_check("definir_lumiere(0.0) ramène bien lumiere_recue à 0",
		mat.get_shader_parameter("lumiere_recue") == 0.0)


# ---------------------------------------------------------------------------
# ACCROUPI (ISO3 vague 1)
# ---------------------------------------------------------------------------

## Hauteur du sommet de la tête, pleinement accroupi, rapportée à la hauteur
## debout : doit tomber dans la fourchette 0,5-0,6 que le brief a posée
## (« à toi de trouver ce qui se lit »). `t = 1.0` dépasse largement
## `DUREE_TRANSITION_ACCROUPI` (150 ms) : la posture est stabilisée, pas en
## transition.
func _test_accroupi(corps: Node3D, hauteur_debout: float) -> void:
	corps.poser({
		"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
		"torche": true, "arme": corps.slug(), "tir": false, "touche": false,
		"mort": false, "accroupi": true, "enjambe": 0.0, "t": 1.0,
	})
	var sommet: float = corps.sommet_tete()
	var facteur := sommet / hauteur_debout
	_check("hauteur accroupie dans la fourchette 0,5-0,6 (%.3f)" % facteur,
		facteur >= ACCROUPI_MIN and facteur <= ACCROUPI_MAX, "%.3f" % facteur)

	# Le noir absolu doit survivre au changement de posture : le matériau est
	# unique par corps (voir `materiau()`), une posture ne doit ni le remplacer
	# ni contourner l'uniform qui le gouverne.
	corps.definir_lumiere(0.7)
	corps.definir_lumiere(0.0)
	var mat: ShaderMaterial = corps.materiau()
	_check("noir strict à lumiere_recue = 0, accroupi",
		mat.get_shader_parameter("lumiere_recue") == 0.0)

	# Se relever est instantané par construction (voir `_facteur_accroupi`) :
	# à `t = 0` avec `accroupi = false`, aucune trace de l'accroupi ne doit
	# rester — c'est exactement le bogue que le premier jet de cette fonction
	# a laissé passer (facteur = 1 au lieu de 0), trouvé au banc rapide plutôt
	# qu'à cette suite : elle le verrouille maintenant pour de bon.
	corps.poser({
		"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
		"torche": true, "arme": corps.slug(), "tir": false, "touche": false,
		"mort": false, "accroupi": false, "enjambe": 0.0, "t": 0.0,
	})
	var sommet_debout: float = corps.sommet_tete()
	_check("relevé immédiat (t=0, accroupi=false) → hauteur debout (%.3f)"
			% (sommet_debout / hauteur_debout),
		absf(sommet_debout - hauteur_debout) < 0.01, "%.4f" % sommet_debout)


# ---------------------------------------------------------------------------
# ENJAMBEMENT (ISO3 vague 1)
# ---------------------------------------------------------------------------

## L'angle de la jambe qui enjambe (toujours `JambeDroite`, voir
## `_poser_enjambe`) doit progresser de façon monotone avec `etat.enjambe` :
## la jambe balaie de l'arrière vers l'avant sans jamais reculer pendant le
## geste. C'est la lecture que ce fichier retient du « x » du brief — un
## sommet cartésien littéral resterait presque immobile ici, la rotation
## est la grandeur qui varie effectivement et sans ambiguïté (voir l'en-tête
## de classe de `voxel_corps.gd`, section Enjambement).
##
## ⚠️ L'échantillonnage commence STRICTEMENT après 0, jamais à 0 : `enjambe`
## à exactement 0 n'est pas le début du geste, c'est son absence — `poser()`
## retombe alors sur la marche/le repos (« 0 = pas d'enjambement », le brief),
## une pose sans rapport avec l'arc de l'enjambée. Un premier jet de ce test
## incluait ce point et a rougi sur un saut qui n'en était pas un : la jambe
## passe légitimement de sa pose de repos (0°) au début de l'arc (≈ -70°)
## quand `enjambe` quitte 0, un seul et unique désaccord au tout premier pas,
## jamais pendant le geste lui-même.
func _test_enjambement(corps: Node3D) -> void:
	var precedent := -INF
	var monotone := true
	var n := 20
	for i in n:
		var e := float(i + 1) / float(n)
		corps.poser({
			"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO,
			"torche": true, "arme": corps.slug(), "tir": false, "touche": false,
			"mort": false, "accroupi": false, "enjambe": e, "t": 0.0,
		})
		var angle: float = corps.get_node("JambeDroite").rotation.x
		if angle < precedent - EPSILON:
			monotone = false
		precedent = angle
	_check("enjambement monotone (JambeDroite ne recule jamais)", monotone)

	corps.definir_lumiere(0.4)
	corps.definir_lumiere(0.0)
	var mat: ShaderMaterial = corps.materiau()
	_check("noir strict à lumiere_recue = 0, en pleine enjambée",
		mat.get_shader_parameter("lumiere_recue") == 0.0)


# ---------------------------------------------------------------------------
# LE CATALOGUE NE DÉRIVE PAS DES VRAIES CLASSES
# ---------------------------------------------------------------------------

func _test_catalogue_a_jour(VoxelCatalogue: GDScript) -> void:
	var src := FileAccess.get_file_as_string("res://game_state.gd")
	if src.is_empty():
		_check("game_state.gd lisible pour comparer les slugs", false)
		return
	var rx := RegEx.new()
	rx.compile("_classe\\(\"([a-z_]+)\"")
	var attendus := PackedStringArray(["pistolet", "fusil", "pompe", "arbalete"])
	for m in rx.search_all(src):
		attendus.append(m.get_string(1))
	var attendus_tries := attendus.duplicate()
	attendus_tries.sort()
	var catalogue_tries: PackedStringArray = VoxelCatalogue.slugs()
	catalogue_tries.sort()
	_check("le catalogue iso porte exactement les classes de game_state.gd (%d)"
			% attendus_tries.size(),
		attendus_tries == catalogue_tries,
		"attendu %s, catalogue %s" % [str(attendus_tries), str(catalogue_tries)])


# ---------------------------------------------------------------------------
# AUCUN HASARD
# ---------------------------------------------------------------------------

func _test_aucun_hasard() -> void:
	for chemin in ["res://voxel_corps.gd", "res://voxel_catalogue.gd"]:
		var src := FileAccess.get_file_as_string(chemin)
		_check("%s lisible" % chemin, not src.is_empty())
		# Lignes de CODE seulement : les commentaires du fichier nomment ces
		# fonctions en toutes lettres pour expliquer qu'il ne les appelle pas,
		# ce qui ferait mordre une recherche naïve sur le texte entier.
		var suspect := false
		for ligne in src.split("\n"):
			var code := ligne.strip_edges().split("#")[0]
			if code.contains("randi") or code.contains("randf") or code.contains("randomize"):
				suspect = true
				break
		_check("%s n'appelle aucun hasard" % chemin, not suspect)
