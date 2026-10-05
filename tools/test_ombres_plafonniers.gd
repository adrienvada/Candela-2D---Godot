## OMBRES, OM5 — l'ombre FINIE des corps sous les plafonniers (Q88, décision d'Adrien du 2026-10-05 : « Ombre »).
##
## Trois étages :
##   • **la règle pure** (`OmbresCorps.ombre`, jumelle de `om_ombre_des_corps` dans `ombres_corps_zone.gdshaderinc`) : la longueur
##     D · H / (h − H) sur l'axe, l'élargissement (le haut du cylindre se projette × h / (h − H)), l'accroupi (sa hauteur de
##     posture, celle des murets), une lampe qui ne dépasse pas la tête, la plus forte ombre et pas la somme, une force nulle ;
##   • **les shaders** : le sol et le décor portent l'include et retirent l'ombre de LEUR éclairage, tableaux à la taille des
##     constantes ;
##   • **la poussée, dans une vraie salle d'aventure** (`GameState._pousser_ombres_des_corps`) : le plafonnier et les corps arrivent
##     au matériau du sol de la vue de J1, à l'écran ; un corps caché ou mort n'y est plus ; un PNJ effacé par l'éblouissement qu'il cause
##     n'a plus qu'une ombre aussi pâle que lui ; un leurre en a une ; sans plafonnier, « aucune lampe ».
## Que le pixel suive la règle ne se voit qu'en fenêtre : le banc des ombres (`tools/planche_ombres.gd`, famille `om5`).
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_ombres_plafonniers.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")

const ESSAI := "res://tools/aventure_essai"
const SOLO_DE_LA_SUITE := "user://test_ombres_plafonniers_solo.cfg"
const PH_JEU := 1
## La lampe et le corps de la règle pure : une tuile de 35 px, le plafonnier à 1,5 tuile, un corps debout d'une tuile.
const TUILE := 35.0
const H_LAMPE := 52.5
const H_DEBOUT := 35.0

var _failures := 0
var _verifications := 0
var main: Node = null
var prog: AventureProgression = null
var chapitre: Dictionary = {}
var brut: Dictionary = {}


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
	print("=== OMBRES, OM5 : L'OMBRE FINIE DES CORPS SOUS LES PLAFONNIERS ===")
	await process_frame
	_la_regle_pure()
	_les_shaders()
	var fichier := ProjectSettings.globalize_path(SOLO_DE_LA_SUITE)
	if FileAccess.file_exists(SOLO_DE_LA_SUITE):
		DirAccess.remove_absolute(fichier)
	root.get_node("GameSettings").mode_iso = false
	Format.racine = ESSAI
	Format.niveaux_attendus = 0
	Format.oublier_le_cache()
	chapitre = Format.charger_chapitre(ESSAI.path_join("chapitre_00"), 0)
	brut = Format.lire_chapitre(ESSAI.path_join("chapitre_00"))
	_check("(le chapitre d'essai se charge)", not chapitre.is_empty() and not brut.is_empty())
	if chapitre.is_empty() or brut.is_empty():
		_sortir()
		return
	prog = Progression.new(SOLO_DE_LA_SUITE)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	main.ui.aventure_progression = prog
	main.archiver_les_matchs = false
	await _la_poussee_dans_une_salle()
	_sortir()


# ---------------------------------------------------------------------------
# LA RÈGLE PURE
# ---------------------------------------------------------------------------

## Un corps de la règle : `Vector4(x, y, rayon, hauteur)`.
func _corps(x: float, h: float = H_DEBOUT, y: float = 0.0) -> Vector4:
	return Vector4(x, y, OmbresCorps.RAYON_CORPS, h)


func _la_regle_pure() -> void:
	print("\n--- La règle : un cylindre sous une lampe haute, son ombre finie ---")
	var lampe := Vector3(0.0, 0.0, H_LAMPE)
	var r := OmbresCorps.RAYON_CORPS
	var d := 2.0 * TUILE
	var c := [_corps(d)]
	var f := [1.0]
	# Le centre du cylindre se projette à d · h / (h − H), son haut garde un rayon × h / (h − H) : le bord au loin.
	var echelle := H_LAMPE / (H_LAMPE - H_DEBOUT)
	var bord := (d + r) * echelle
	_check("la longueur sur l'axe : D · H / (h − H) = %.1f px pour un corps debout à deux tuiles (le double de D)" % \
		OmbresCorps.longueur(d, H_DEBOUT, H_LAMPE), is_equal_approx(OmbresCorps.longueur(d, H_DEBOUT, H_LAMPE), 2.0 * d))
	_check("une lampe qui ne dépasse pas la tête ne donne pas d'ombre finie (INF)",
		OmbresCorps.longueur(d, H_DEBOUT, H_DEBOUT) == INF)
	_check("entre la lampe et le corps, le sol est éclairé", OmbresCorps.ombre(lampe, Vector2(d - r - 2.0, 0.0), c, f) == 0.0)
	_check("sous le corps, et derrière lui jusqu'au bord de son ombre (%.0f px), le sol est dans l'ombre" % bord,
		OmbresCorps.ombre(lampe, Vector2(d, 0.0), c, f) == 1.0 and OmbresCorps.ombre(lampe, Vector2(d * echelle, 0.0), c, f) == 1.0
		and OmbresCorps.ombre(lampe, Vector2(bord - 2.0, 0.0), c, f) == 1.0)
	_check("… et pas au-delà : l'ombre est FINIE (à %.0f px, éclairé)" % (bord + 2.0),
		OmbresCorps.ombre(lampe, Vector2(bord + 2.0, 0.0), c, f) == 0.0)
	var large := r * echelle
	_check("elle s'élargit en s'éloignant : au bout, %.0f px de demi-largeur au lieu de %.0f au pied" % [large, r],
		OmbresCorps.ombre(lampe, Vector2(d * echelle, large - 2.0), c, f) == 1.0
		and OmbresCorps.ombre(lampe, Vector2(d * echelle, large + 2.0), c, f) == 0.0
		and OmbresCorps.ombre(lampe, Vector2(d, r + 2.0), c, f) == 0.0)
	var h_acc := MursBas.hauteur_de_posture(true)
	var c_acc := [_corps(d, h_acc)]
	var bord_acc := (d + r) * H_LAMPE / (H_LAMPE - h_acc)
	_check("accroupi (la hauteur de posture des murets, %.1f px), l'ombre ne dépasse le corps que de %.1f px" % [h_acc,
		bord_acc - (d + r)], OmbresCorps.ombre(lampe, Vector2(bord_acc - 1.0, 0.0), c_acc, f) == 1.0
		and OmbresCorps.ombre(lampe, Vector2(bord_acc + 1.0, 0.0), c_acc, f) == 0.0
		and OmbresCorps.ombre(lampe, Vector2(bord - 2.0, 0.0), c_acc, f) == 0.0)
	_check("une lumière sans hauteur (une torche, z = 0) n'est jamais touchée",
		OmbresCorps.ombre(Vector3(0.0, 0.0, 0.0), Vector2(d * echelle, 0.0), c, f) == 0.0)
	_check("une lampe plus basse que la tête : pas d'ombre finie, et ce n'est pas un plafonnier — rien",
		OmbresCorps.ombre(Vector3(0.0, 0.0, H_DEBOUT - 1.0), Vector2(d * echelle, 0.0), c, f) == 0.0)
	# Deux corps dont les ombres se recouvrent : la plus forte, jamais la somme.
	var deux := [_corps(d), _corps(d + 10.0)]
	_check("deux ombres qui se recouvrent : la plus forte (0,7), pas la somme",
		is_equal_approx(OmbresCorps.ombre(lampe, Vector2(d * echelle, 0.0), deux, [0.4, 0.7]), 0.7))
	_check("un corps de force nulle (effacé dans la vue) ne fait pas d'ombre",
		OmbresCorps.ombre(lampe, Vector2(d * echelle, 0.0), c, [0.0]) == 0.0)
	_check("un corps à moitié effacé fait une ombre à moitié", is_equal_approx(
		OmbresCorps.ombre(lampe, Vector2(d * echelle, 0.0), c, [0.5]), 0.5))
	# Les constantes que l'on recopie, et les tableaux.
	var p3d := (load("res://presentation_3d.gd") as GDScript).get_script_constant_map()
	_check("le rayon du cylindre est celui du « corps grossier » de la présentation (%.0f px)" % OmbresCorps.RAYON_CORPS,
		is_equal_approx(float(p3d["RAYON_CORPS_PX"]), OmbresCorps.RAYON_CORPS))
	var fmt := (load("res://aventure_format.gd") as GDScript).get_script_constant_map()
	_check("les tableaux tiennent une salle : %d plafonniers (le format en permet %d), %d corps (1 joueur + %d PNJ + leurres)" % [
		OmbresCorps.LAMPES_MAX, int(fmt["PLAFONNIERS_MAX"]), OmbresCorps.CORPS_MAX, int(p3d["FIGURANTS_MAX"])],
		OmbresCorps.LAMPES_MAX >= int(fmt["PLAFONNIERS_MAX"]) and OmbresCorps.CORPS_MAX >= 1 + int(p3d["FIGURANTS_MAX"]))


func _les_shaders() -> void:
	print("\n--- Les shaders : le sol et le décor retirent l'ombre de LEUR éclairage ---")
	var include := "#include \"res://ombres_corps_zone.gdshaderinc\""
	var retrait := "* (1.0 - om_ombre_des_corps(LIGHT_POSITION, LIGHT_VERTEX))"
	for chemin in ["res://murs_bas_sol.gdshader", "res://murs_bas_decor.gdshader"]:
		var source := FileAccess.get_file_as_string(chemin)
		_check("%s inclut l'ombre des corps et la retire de sa lumière" % chemin.get_file(),
			source.contains(include) and source.contains(retrait))
		var s := load(chemin) as Shader
		_check("%s compile (uniformes de l'include visibles)" % chemin.get_file(), s != null and _a_l_uniforme(s, "om_corps"))
	var inc := FileAccess.get_file_as_string("res://ombres_corps_zone.gdshaderinc")
	_check("les tableaux de l'include ont la taille des constantes",
		inc.contains("uniform vec2 om_lampes[%d];" % OmbresCorps.LAMPES_MAX)
		and inc.contains("uniform vec4 om_corps[%d];" % OmbresCorps.CORPS_MAX)
		and inc.contains("uniform float om_corps_force[%d];" % OmbresCorps.CORPS_MAX))
	_check("seuls les plafonniers, reconnus à leur position, sont touchés", inc.contains("distance(om_lampes[l], source.xy)"))
	# Les capteurs ne reçoivent pas l'ombre : le modèle de vue du bot ne la connaît pas (OM5 ne touche que le sol et le décor).
	for chemin in ["res://player_rim_light.gdshader", "res://player_enemy_light.gdshader"]:
		_check("%s ne la porte pas (les corps ne la reçoivent pas)" % chemin.get_file(),
			not FileAccess.get_file_as_string(chemin).contains("ombres_corps_zone"))


func _a_l_uniforme(s: Shader, nom: String) -> bool:
	for u in s.get_shader_uniform_list():
		if String(u["name"]) == nom:
			return true
	return false


# ---------------------------------------------------------------------------
# LA POUSSÉE, DANS UNE VRAIE SALLE
# ---------------------------------------------------------------------------

func _la_poussee_dans_une_salle() -> void:
	print("\n--- Dans une vraie salle : le plafonnier et les corps arrivent au sol de la vue de J1 ---")
	_check("la poussée est accrochée juste avant le dessin, comme la zone morte",
		RenderingServer.frame_pre_draw.is_connected(main._pousser_ombres_des_corps))
	var niveau: Dictionary = (brut["niveaux"][0] as Dictionary).duplicate(true)
	niveau["plafonniers"] = [{"case": [10, 8], "rayon": 4.0, "intensite": 1.2}]
	niveau["pnj"] = [{"case": [12, 8], "orientation": 180, "profil": "immobile_sourd_aveugle", "classe": "fusil"}]
	niveau["boss"] = false
	var defauts := Format.valider_niveau(niveau)
	_check("(le niveau fabriqué par la suite est lui-même valide)", defauts.is_empty(), str(defauts))
	var c := chapitre.duplicate(true)
	c["niveaux"] = [Format.preparer_niveau(niveau)]
	c["niveaux"][0]["fichier"] = "fabrique.json"
	var partie: Node = await _demarrer(c)
	var pnj: Array = partie.pnj
	_check("(un PNJ dans la salle)", pnj.size() == 1)
	if pnj.size() != 1:
		await _quitter()
		return
	var pnj0: Node2D = pnj[0]
	var j1: Node2D = main.p1
	# Le PNJ allume le plafonnier en approchant (`Plafonnier.actualiser`) ; on rapproche J1 aussi.
	j1.global_position = pnj0.global_position + Vector2(-140.0, 0.0)
	await _images(4)
	var lampes := OmbresCorps.lampes_allumees(self)
	_check("(le plafonnier est allumé)", lampes.size() == 1)
	main._pousser_ombres_des_corps()
	var mats: Array = main._materiaux_zone_morte[0]
	_check("(la vue de J1 a ses matériaux de sol et de décor)", not mats.is_empty())
	if mats.is_empty() or lampes.size() != 1:
		await _quitter()
		return
	var m: ShaderMaterial = mats[0]
	var ecran := _ecran()
	var echelle := ecran.get_scale().x
	var l_ecran: Vector2 = (m.get_shader_parameter("om_lampes") as PackedVector2Array)[0]
	_check("le plafonnier arrive à l'écran, à sa position (écart %.3f px)" % l_ecran.distance_to(ecran * lampes[0]),
		int(m.get_shader_parameter("om_nb_lampes")) == 1 and l_ecran.distance_to(ecran * lampes[0]) < 0.01)
	var corps := _corps_pousses(m)
	var c_j1: Variant = _cherche(corps, ecran * j1.global_position)
	var c_pnj: Variant = _cherche(corps, ecran * pnj0.global_position)
	_check("J1 et le PNJ arrivent, chacun à sa place, et rien d'autre (J2 est caché en aventure) — %d corps" % corps.size(),
		corps.size() == 2 and c_j1 != null and c_pnj != null)
	if c_pnj != null:
		var v: Vector4 = c_pnj["v"]
		_check("le PNJ debout : son rayon et sa hauteur à l'écran (%.1f, %.1f), sa force 1" % [v.z, v.w],
			is_equal_approx(v.z, OmbresCorps.RAYON_CORPS * echelle)
			and is_equal_approx(v.w, MursBas.hauteur_de_posture(false) * echelle) and is_equal_approx(float(c_pnj["f"]), 1.0))
	# Tous les matériaux de la vue reçoivent la même chose.
	var memes := true
	for autre: ShaderMaterial in mats:
		memes = memes and int(autre.get_shader_parameter("om_nb_corps")) == int(m.get_shader_parameter("om_nb_corps"))
	_check("le sol et le décor de la vue reçoivent les mêmes corps", memes)
	# Accroupi : la hauteur de la posture.
	j1.set("accroupi", true)
	main._pousser_ombres_des_corps()
	ecran = _ecran()
	var c_acc: Variant = _cherche(_corps_pousses(m), ecran * j1.global_position)
	_check("J1 accroupi : la hauteur de sa posture (%.1f px à l'écran)" % (float(c_acc["v"].w) if c_acc != null else -1.0),
		c_acc != null and is_equal_approx(float(c_acc["v"].w), MursBas.hauteur_de_posture(true) * echelle))
	j1.set("accroupi", false)
	# Un PNJ qui éblouit J1 s'efface à ses yeux (Q81) : son ombre pâlit avec lui — elle ne le trahit pas.
	j1.apply_dazzle(1.0, pnj0)
	await _images(1)
	main._pousser_ombres_des_corps()
	ecran = _ecran()
	var opacite := Presentation3D_opacite(pnj0)
	var c_ebl: Variant = _cherche(_corps_pousses(m), ecran * pnj0.global_position)
	_check("le PNJ qui éblouit J1 s'efface à ses yeux (%.3f) : son ombre n'a plus que cette force" % opacite,
		opacite < 0.5 and (c_ebl == null or absf(float(c_ebl["f"]) - opacite) < 0.001))
	j1.dazzle_amount = 0.0
	await _images(30)
	# Un corps caché n'a plus d'ombre ; rendu visible, il la retrouve.
	pnj0.visible = false
	main._pousser_ombres_des_corps()
	ecran = _ecran()
	_check("un PNJ caché n'est plus poussé (il ne trahit rien par son ombre)",
		_cherche(_corps_pousses(m), ecran * pnj0.global_position) == null)
	pnj0.visible = true
	# Un mort n'en fait pas (OM4a) — par `_en_jeu`, pas seulement par l'opacité : `die()` cache aujourd'hui ses sprites, d'où une
	# force nulle que la poussée écarte d'elle-même ; un corps `dead` qu'on laisserait visible (un cadavre au sol) ne doit pas
	# trahir sa place pour autant. Posé sans `die()` et rendu aussitôt, sans image entre les deux : rien d'autre ne le lit.
	pnj0.dead = true
	main._pousser_ombres_des_corps()
	ecran = _ecran()
	_check("un PNJ mort n'est pas poussé, même si son sprite restait visible (`_en_jeu`, OM4a)",
		_cherche(_corps_pousses(m), ecran * pnj0.global_position) == null)
	pnj0.dead = false
	# Le leurre du PNJ (l'Illusionniste) : un corps qui imite, il a donc une ombre.
	var slot: int = pnj0.slot_de_reserve()
	main._gadgets_poses_par[slot] = 0
	main._gadget_attente[slot] = 0.0
	main.spawn_gadget(pnj0, pnj0.global_position + Vector2(0.0, 50.0), 0.0)
	await _images(2)
	var leurre: Node2D = null
	for g in main.bullet_container.get_children():
		if _est_de(g, "res://gadget_leurre.gd"):
			leurre = g
	_check("(le PNJ Illusionniste pose son leurre)", leurre != null)
	if leurre != null:
		main._pousser_ombres_des_corps()
		ecran = _ecran()
		_check("le leurre a une ombre, comme un corps debout — sans elle, il se trahirait sous la lampe",
			_cherche(_corps_pousses(m), ecran * leurre.global_position) != null)
		leurre.queue_free()
		await _images(1)
	# Sans plafonnier : « aucune lampe », une fois.
	Plafonnier_retirer()
	await _images(1)
	main._pousser_ombres_des_corps()
	_check("sans plafonnier, le sol apprend « aucune lampe » (et plus rien n'est poussé ensuite)",
		int(m.get_shader_parameter("om_nb_lampes")) == 0 and main._ombres_corps_vides_poussees)
	await _quitter()


## La transformation du monde vers l'écran de la vue de J1, celle de la poussée — À CHAQUE contrôle : la caméra suit J1.
func _ecran() -> Transform2D:
	var rendu: Node = main._viewport_du_monde(0)
	var cible: Viewport = rendu as Viewport if rendu is Viewport else main.get_window()
	return cible.get_final_transform() * cible.get_canvas_transform()


## Les corps qu'un matériau a reçus : `{v: Vector4, f: float}`.
func _corps_pousses(m: ShaderMaterial) -> Array:
	var n := int(m.get_shader_parameter("om_nb_corps"))
	var t: PackedVector4Array = m.get_shader_parameter("om_corps")
	var f: PackedFloat32Array = m.get_shader_parameter("om_corps_force")
	var sortie: Array = []
	for i in n:
		sortie.append({"v": t[i], "f": f[i]})
	return sortie


func _cherche(corps: Array, position_ecran: Vector2) -> Variant:
	for c in corps:
		if Vector2(c["v"].x, c["v"].y).distance_to(position_ecran) < 0.01:
			return c
	return null


## `Presentation3D.opacite_du_corps(pnj, false)`, lu par l'arbre : nommer la présentation dans une suite `--script` la ferait
## compiler avant ses autoloads (piège consigné).
func Presentation3D_opacite(corps: Node) -> float:
	var p3d := load("res://presentation_3d.gd") as GDScript
	return float(p3d.call("opacite_du_corps", corps, false))


func Plafonnier_retirer() -> void:
	var p := load("res://plafonnier.gd") as GDScript
	p.call("retirer", main.arena)


func _demarrer(c: Dictionary) -> Node:
	main.graine_du_bot = 4242
	main.demarrer_l_aventure(c, 0, "pistolet", prog)
	await _images(3)
	var partie: Node = main.aventure
	var fin := 300
	while partie.phase != PH_JEU and fin > 0:
		await process_frame
		fin -= 1
	return partie


func _quitter() -> void:
	main._on_main_menu_requested()
	await _images(3)


func _est_de(n: Object, chemin: String) -> bool:
	return n != null and n.get_script() != null and (n.get_script() as Script).resource_path == chemin


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
