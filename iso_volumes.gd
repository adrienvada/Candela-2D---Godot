class_name IsoVolumes
extends Node3D

## Gadgets et lumières en iso — les VOLUMES (étape 3), les LUEURS (étape 4) et la toile du voile (étape 5).
##
## `MiroirsIso` lève ce qui a un corps (voxels) ; ce fichier élève ce qui n'en a pas mais a une épaisseur
## ou une hauteur : les nuages (suie, poussière, fumée de fusée), les nappes (braises, poudre), les sources
## qui brûlent au-dessus du sol (la comète d'une fusée en vol, sa lueur posée, les braises, la lentille de
## la torche fantôme, l'éclair de la mine, l'éclat de bouche) et l'anneau de l'onde de mort.
##
## ## Une image, jamais une valeur de jeu
##
## Rien ici n'est lu par la simulation, la balle, l'éblouissement, les capteurs ni les lightmaps : un
## volume lit la lightmap sous lui (`volume_iso.gdshader`), une lueur recopie l'énergie d'une lumière 2D
## (`halo_iso.gdshader`). Couper `images_actives` retire tout sans qu'aucune de ces valeurs change —
## `tools/test_iso_gadgets.gd` le prouve. Aucune `Light3D`.
##
## ## Trois règles d'équité, tenues par construction — dans le MONDE
##
## - **Noir absolu** : un volume vaut la lightmap sous lui (0 sans lumière) ; une lueur vaut l'énergie de
##   sa lumière (0 lumière éteinte). L'anneau de l'onde et la toile sont les seuls dessins sans lumière, et
##   ils l'étaient déjà en vue de dessus (l'onde est non éclairée ; la toile recopie la lightmap).
##   ⚠️ **Tenu dans le monde, pas démontré à l'écran** (corrigé le 2026-09-24). Une couche EN HAUTEUR est
##   dessinée plus haut que le sol qu'elle lit (parallaxe, tangage 52°) et peut tomber sur un pixel noir :
##   mesuré pour le faisceau d'ISO13 (307 pixels isolés à 0,45 de densité, 15 couches posées au sol).
##   Pour la fumée de la fusée et les autres nuages, allumés par défaut, la question est OUVERTE : les
##   deux instruments essayés n'ont pas su répondre (`docs/iso/iso13/plan_lots_d_e.md`). Cette règle a
##   été écrite le 2026-09-15 en ne regardant que le monde.
## - **Les deux joueurs** : chaque couche lit la lightmap de la caméra qui la dessine, comme le sol ; les
##   lueurs sont celles de sources que les deux vues montrent déjà (masques de lumière 1|2|4, dessins non
##   éclairés visibles des deux).
## - **Jamais plus caché qu'en vue de dessus** : les couches se dessinent AVANT les corps
##   (`PRIORITE_VOLUME`) ; l'effacement dans un nuage reste celui de l'opacité du corps (ISO2b).
##
## ⚠️ **Aucun nom de classe du jeu** (`Fusee`, `Bullet`, `Player`, `Gadget*`) : ils nomment des autoloads, et
## une suite headless compile la présentation avant eux (piège d'ISO4). Tout se reconnaît par propriété.

const SHADER_VOLUME := preload("res://volume_iso.gdshader")
const SHADER_HALO := preload("res://halo_iso.gdshader")
## ISO10, 1c — la lueur au sol de la fusée posée, en mélange et non en addition (voir `halo_iso.gdshaderinc`).
const SHADER_HALO_MELANGE := preload("res://halo_iso_melange.gdshader")
const SHADER_TRAIT := preload("res://quad_iso.gdshader")
const OndeDeMort := preload("res://kill_shockwave.gd")

const TUILE := 35.0
## Sous les corps (profondeur -1, couleur 0) : un nuage ne recouvre jamais un corps.
const PRIORITE_VOLUME := -2
## La couche 3D commune aux deux caméras (`Presentation3D.CALQUE_COMMUN`).
const CALQUE := 1
## Au-dessus du sol projeté, jamais dedans (`MiroirsIso.HAUTEUR_QUAD_PX`).
const PLANCHER_PX := 0.8

## Les volumes des gadgets, par slug : hauteur (tuiles), nombre de couches, opacité d'une couche au cœur.
## Hauteurs du brief ; densités dosées au banc (`tools/banc_iso_gadgets.gd`).
const VOLUMES := {
	"cartouche_suie": {"hauteur": 0.8, "couches": 4, "densite": 0.34},
	"poussiere": {"hauteur": 0.4, "couches": 3, "densite": 0.16},
	"nappe_braises": {"hauteur": 0.1, "couches": 2, "densite": 0.40},
	"poudre_contact": {"hauteur": 0.1, "couches": 2, "densite": 0.34},
}
const VOLUME_FUSEE := {"hauteur": 1.0, "couches": 4, "densite": 0.26}

## Le cœur chaud à la lampe : sa taille en pixels de monde, et sa hauteur au-dessus du sol.
const TAILLE_COEUR_LAMPE := 7.0
const HAUTEUR_COEUR_LAMPE := 0.20

## La toile du voile, debout : la hauteur de ses piquets (`VoxelObjet.VOILE_PIQUET`).
const HAUTEUR_TOILE := 0.15
## Les points incandescents de la nappe de braises.
const POINTS_BRAISES := 16
## La lentille de la torche fantôme : là où le fût se termine (`VoxelObjet.TORCHE_TETE_Y` + demi-tête).
const HAUTEUR_LENTILLE := 0.20
const HAUTEUR_ECLAIR_MINE := 0.14

## Tout couper — la preuve que ces images ne sont que des images. Relu à chaque image.
var images_actives := true
## ISO12 — INSTRUMENTS DE BANC (spécification d'ISO7 Gadgets, 2026-09-23 ; `tools/bench_framerate.gd`), pour répartir le coût de
## cadence d'une fusée entre ses parties. Jamais posés en jeu ; chacun est lu en UN seul endroit, nommé.
## `volumes_actifs` faux : pas de volume de fumée iso (lu dans `_suivre_fusee`).
var volumes_actifs := true
## `lueurs_actives` faux : ni la lueur posée ni les deux lueurs de la comète (lu dans `_suivre_fusee` et `_suivre_comete`).
var lueurs_actives := true
## `couches_fusee` ≥ 0 : le nombre de couches du volume de la fusée, plafonné à `VOLUME_FUSEE["couches"]` ; −1 : le défaut.
## ⚠️ `_couches()` ne fait que CRÉER, jamais détruire : à poser AVANT que la fusée soit suivie (ou suivi d'un `vider()`), et à ne
## jamais changer en cours de relevé — un volume déjà construit garderait ses couches, sans rien dire.
var couches_fusee := -1
## ISO13, lot E — éteint par défaut, comme tout drapeau d'un lot en cours.
var faisceaux_actifs := false
## ISO13, Q31 voie A — le masque de la fumée : chaque couche de volume passe à la variante FUMEE_MASQUE
## de son shader, qui la tait là où ce que le pixel montre est affiché noir (voir `volume_iso.gdshader`). ALLUMÉ PAR DÉFAUT
## depuis le 2026-09-25 (Q31 : « le noir d'abord », prix 3 % au plus, preuve à l'image passée) ; `--sans-fumee-masque`
## l'éteint — la référence de toute série de cadence sur la fumée. À poser AVANT que les couches naissent, comme
## `couches_fusee` — une couche déjà créée garde son shader (les bancs basculent par `poser_masque_fumee`).
var masque_fumee := true
## Q34 = C (Adrien, 2026-09-26) — le point de braise de la fusée POSÉE, PAR DÉFAUT. En 2D, le cœur incandescent (`fusee.gd`,
## `EMPREINTE_COEUR`, 16 px) « se voit dans le noir complet parce qu'il EST la source » : c'est une information de jeu, la
## position de la fusée. En iso, le voxel le remplace (ISO3 vague 3, d641b48 ; ISO4, 77941df) et ne l'émet pas ; ce point le
## rend, par un halo d'ici et non par le voxel, comme la comète en vol (10 px). 2 (défaut) : presque blanc pendant le plein
## feu, puis de la couleur de la lumière (rouge, orange) ; 1 : `--fusee-coeur`, toujours de la couleur de la lumière ;
## 0 : `--sans-fusee-coeur`, le choix d'ISO3/ISO4. La règle « jamais de blanc » (`fusee.gd`, FU2.1) reste entière pour la
## LUMIÈRE : l'exception ne vaut que pour ce point, qui n'éclaire rien. La vue de dessus garde son point rouge.
var coeur_fusee := 2

var miroirs: Node = null      # MiroirsIso : il tient le registre des dessins retirés des lightmaps
var _suivis := {}             # "instance_id:cle" de la source -> Dictionary
var _plan := PlaneMesh.new()
var _quad := QuadMesh.new()
var _masques := false


## ISO13, lot E — le drapeau du faisceau. ⚠️ Il se passe APRÈS `--`, comme `--corps=` : la lecture se
## fait sur les arguments UTILISATEUR. Lu ici plutôt que dans un banc pour qu'il porte partout — jeu,
## banc de cadence, photographe — sans qu'aucun d'eux n'ait à le connaître.
const DRAPEAU_FAISCEAU := "--faisceau"
const DRAPEAU_MASQUE_FUMEE := "--fumee-masque"
const DRAPEAU_SANS_MASQUE_FUMEE := "--sans-fumee-masque"
const DRAPEAU_COEUR_FUSEE := "--fusee-coeur"
const DRAPEAU_COEUR_FUSEE_BLANC := "--fusee-coeur-blanc"
const DRAPEAU_SANS_COEUR_FUSEE := "--sans-fusee-coeur"
## Le cœur presque blanc de l'essai : celui de l'illustration « Créer en ligne » (254, 238, 238), mesuré par la session
## cloud sur l'original. La sortie 3D le plafonne à ~230 (la courbe d'écran, voir la ROADMAP).
const COULEUR_COEUR_BLANC := Color(1.0, 0.93, 0.93)
## La taille du cœur posé : celle du cœur de la comète (`_suivre_comete`), en pixels de monde.
const TAILLE_COEUR_FUSEE := 10.0
## Sa hauteur : au sommet de la braise du voxel (`VoxelObjet.FUSEE_BRAISE_Y0` + sa hauteur), un peu au-dessus. À la hauteur de
## la lumière (0,15 tuile), il tombait DANS le voxel, qui en masquait le centre : un anneau autour de la tige, pas un point
## (premier essai, 2026-09-25 21:50).
const HAUTEUR_COEUR_FUSEE_PX := (VoxelObjet.FUSEE_BRAISE_Y0 + VoxelObjet.FUSEE_BRAISE.y) * TUILE + 0.3 * TAILLE_COEUR_FUSEE


func _init() -> void:
	name = "Volumes"
	_plan.size = Vector2.ONE
	_quad.size = Vector2.ONE
	for arg in OS.get_cmdline_user_args():
		if arg == DRAPEAU_FAISCEAU:
			faisceaux_actifs = true
		elif arg == DRAPEAU_MASQUE_FUMEE:
			masque_fumee = true
		elif arg == DRAPEAU_SANS_MASQUE_FUMEE:
			masque_fumee = false
		elif arg == DRAPEAU_COEUR_FUSEE:
			coeur_fusee = 1
		elif arg == DRAPEAU_COEUR_FUSEE_BLANC:
			coeur_fusee = 2
		elif arg == DRAPEAU_SANS_COEUR_FUSEE:
			coeur_fusee = 0
	if faisceaux_actifs:
		print("[faisceau] allumé — le cœur chaud seul, sans rayon")
	if coeur_fusee != 2:
		print("[fusée cœur] %s" % ("éteint (%s)" % DRAPEAU_SANS_COEUR_FUSEE if coeur_fusee == 0
			else "de la couleur de la lumière, sans le blanc (%s)" % DRAPEAU_COEUR_FUSEE))
	# L'état éteint s'imprime aussi : la référence d'une série se prouve par ce que le JEU dit, jamais par la commande.
	if not masque_fumee:
		print("[fumée masque] éteint (%s) — le shader des volumes d'avant" % DRAPEAU_SANS_MASQUE_FUMEE)


func nombre_de_suivis() -> int:
	return _suivis.size()


## L'entrée suivie pour un nœud 2D, ou `{}`. Clés : `genre` (« volume », « fumee », « comete », « lueur »,
## « braises », « lentille », « eclair », « eclat », « onde », « toile »), `noeuds` (les `MeshInstance3D`),
## `mats` (leurs matériaux), `retires` (les dessins 2D sortis des lightmaps).
## `cle` : 0 pour l'entrée principale d'une source (volume, fumée, comète, onde, éclat), 1 pour sa lueur
## (lueur posée, braises, lentille, éclair), 2 pour la toile du voile.
func suivi_de(noeud: Object, cle: int = 0) -> Dictionary:
	return _suivis.get(_cle(noeud, cle), {}) if noeud != null else {}


static func _cle(source: Object, cle: int) -> String:
	return "%d:%d" % [source.get_instance_id(), cle]


func suivis() -> Array:
	return _suivis.values()


func masquer(masques: bool) -> void:
	_masques = masques


## Une image. `main` : le jeu ; `vues` : ids des vues projetées ; `presentation` : pour les corps voxel.
func suivre(main: Node, vues: Array, style: int, presentation: Node) -> void:
	if not images_actives:
		vider()
		return
	var vus := {}
	var conteneur: Node = main.get("bullet_container")
	if conteneur != null:
		for noeud in conteneur.get_children():
			if not (noeud is Node2D) or (noeud as Node).is_queued_for_deletion():
				continue
			if "_atterrie" in noeud and "graine" in noeud:
				_suivre_fusee(noeud as Node2D, vus)
			elif "poseur_id" in noeud and "slug" in noeud:
				_suivre_gadget(noeud as Node2D, String(noeud.get("slug")), vus)
	var arene := main.get("arena") as Node
	if arene != null:
		for noeud in arene.get_children():
			if noeud.get_script() == OndeDeMort:
				_suivre_onde(noeud as Node2D, vus)
	_suivre_eclats(main, presentation, vus)
	if faisceaux_actifs:
		for j in [main.get("p1"), main.get("p2")]:
			if j is Node2D and not (j as Node).is_queued_for_deletion():
				_suivre_faisceau(j as Node2D, vus)
	for id in _suivis.keys():
		if not vus.has(id):
			_retirer(id)
	_pousser_lightmaps(main, vues, style)


func vider() -> void:
	for id in _suivis.keys():
		_retirer(id)


# ---------------------------------------------------------------------------
# LES VOLUMES — étape 3
# ---------------------------------------------------------------------------

func _suivre_gadget(g: Node2D, slug: String, vus: Dictionary) -> void:
	if VOLUMES.has(slug):
		var visuel := g.get_node_or_null(^"Visuel") as Sprite2D
		var spec: Dictionary = VOLUMES[slug]
		var e := _entree(g, "volume", vus)
		_couches(e, int(spec["couches"]))
		var tex: Texture2D = visuel.texture if visuel != null else null
		var demi := float(g.get("rayon")) if "rayon" in g else 60.0
		if tex != null:
			demi = maxf(tex.get_width() * absf(visuel.global_scale.x), tex.get_height() * absf(visuel.global_scale.y)) * 0.5
		var opacite := Presentation3D.opacite_rendue(visuel) if visuel != null else 0.0
		_poser_couches(e, g.global_position, demi, float(spec["hauteur"]), float(spec["densite"]) * opacite,
			tex, visuel.global_rotation if visuel != null else 0.0, float(g.get_instance_id() % 97),
			float(g.call("age")) if g.has_method("age") else 0.0)
	match slug:
		"nappe_braises":
			_suivre_braises(g, vus)
		"torche_fantome":
			_suivre_lentille(g, vus)
		"mine_magnesium":
			_suivre_eclair(g, vus)
		"voile":
			_suivre_toile(g, vus)


func _suivre_fusee(f: Node2D, vus: Dictionary) -> void:
	var lumiere := f.get_node_or_null(^"Halo") as Light2D
	var energie := lumiere.energy if lumiere != null and lumiere.enabled else 0.0
	if not bool(f.get("_atterrie")):
		_suivre_comete(f, lumiere, energie, vus)
		return
	# Posée : la fumée en volume, et une lueur basse qui pulse avec ce qu'elle brûle.
	var alpha := float(f.call("alpha_fumee")) if f.has_method("alpha_fumee") else 0.0
	if volumes_actifs and alpha > 0.0:
		var e := _entree(f, "fumee", vus)
		_couches(e, int(VOLUME_FUSEE["couches"]) if couches_fusee < 0
			else clampi(couches_fusee, 0, int(VOLUME_FUSEE["couches"])))
		_poser_couches(e, f.global_position, float(f.call("rayon_fumee")), float(VOLUME_FUSEE["hauteur"]),
			float(VOLUME_FUSEE["densite"]) * alpha, null, 0.0, float(int(f.get("graine")) % 97),
			maxf(float(f.call("age_combustion")), 0.0))
	if not lueurs_actives:
		return
	var relative := float(f.call("energie_relative")) if f.has_method("energie_relative") else 0.0
	var lueur := _entree(f, "lueur", vus, 1)
	# ISO10, 1c — en mélange : le rouge de détresse ne s'additionne plus au sol rougi (rose, puis blanc).
	_halos(lueur, 1, SHADER_HALO_MELANGE)
	var h := MursBasRendu.HAUTEUR_FUSEE_AU_SOL * TUILE
	var taille := TUILE * (0.6 + 0.6 * relative)
	_poser_halo(lueur, 0, Vector3(f.global_position.x, h, f.global_position.y), taille,
		lumiere.color if lumiere != null else Color.WHITE, 0.45 * relative, 0)
	if coeur_fusee > 0:
		_suivre_coeur_fusee(f, lumiere, energie, relative, vus)


## Q34 (`coeur_fusee`) — le cœur de la fusée posée, comme celui de la comète : un halo à bord franc (forme 1), de la
## couleur de la lumière, dont l'éclat suit l'énergie et le cœur 2D (ses sursauts d'agonie, son extinction) — et ne tombe
## JAMAIS sous l'opacité du cœur 2D : repris tel quel de la comète (énergie / 0,8 × opacité), il s'effaçait au résidu (0,02),
## là où le point de braise 2D se voit encore — parité avec la 2D (session cloud, 21:54). Au plein feu
## seulement, la variante 2 le pousse vers le presque-blanc ; il revient au rouge quand l'énergie retombe vers la braise.
## La lumière du jeu ne change pas : ce halo s'ajoute à l'image 3D, il n'éclaire rien.
func _suivre_coeur_fusee(f: Node2D, lumiere: Light2D, energie: float, relative: float, vus: Dictionary) -> void:
	var c := _entree(f, "coeur", vus, 2)
	_halos(c, 1)
	var coeur := f.get_node_or_null(^"Coeur") as CanvasItem
	var opacite := coeur.modulate.a if coeur != null else 1.0
	var couleur := lumiere.color if lumiere != null else Color.WHITE
	if coeur_fusee >= 2:
		couleur = couleur.lerp(COULEUR_COEUR_BLANC, smoothstep(0.6, 0.95, relative))
	_poser_halo(c, 0, Vector3(f.global_position.x, HAUTEUR_COEUR_FUSEE_PX, f.global_position.y), TAILLE_COEUR_FUSEE,
		couleur, maxf(clampf(energie / 0.8, 0.0, 1.5) * opacite, opacite), 1)


## La comète : la fusée en vol, à la hauteur de sa lumière. Le cœur et le corps dessinés sortent des
## lightmaps pendant le vol (ils y étaient décalés de 18 px factices) ; posée, `MiroirsIso` les reprend.
func _suivre_comete(f: Node2D, lumiere: Light2D, energie: float, vus: Dictionary) -> void:
	var e := _entree(f, "comete", vus)
	for nom in ["Coeur", "Corps"]:
		var s := f.get_node_or_null(NodePath(nom)) as CanvasItem
		if s != null:
			_retirer_dessin(e, s)
	if not lueurs_actives:
		return
	_halos(e, 2)
	var h := float(f.call("hauteur_source")) * TUILE if f.has_method("hauteur_source") else 0.0
	var coeur := f.get_node_or_null(^"Coeur") as CanvasItem
	var couleur := lumiere.color if lumiere != null else Color.WHITE
	var eclat := clampf(energie / 0.8, 0.0, 1.5) * (coeur.modulate.a if coeur != null else 1.0)
	var p := Vector3(f.global_position.x, maxf(h, PLANCHER_PX), f.global_position.y)
	_poser_halo(e, 0, p, 10.0, couleur, eclat, 1)
	_poser_halo(e, 1, p, 46.0, couleur, 0.4 * eclat, 0)


# ---------------------------------------------------------------------------
# LES LUEURS — étape 4
# ---------------------------------------------------------------------------

## Les braises : un tapis de points incandescents, à la lueur de la nappe. Positions tirées de l'identité
## du nœud (mêmes pour les deux vues), scintillement tiré de l'âge du gadget.
func _suivre_braises(g: Node2D, vus: Dictionary) -> void:
	var e := _entree(g, "braises", vus, 1)
	_halos(e, POINTS_BRAISES)
	var lueur := g.get_node_or_null(^"Lueur") as Light2D
	var nappe := g.get_node_or_null(^"Visuel") as CanvasItem
	var part := 0.0
	if lueur != null and lueur.enabled:
		part = clampf(lueur.energy / 1.8, 0.0, 1.0)
	part *= Presentation3D.opacite_rendue(nappe) if nappe != null else 1.0
	var rayon := float(g.get("rayon")) if "rayon" in g else 68.0
	var age := float(g.call("age")) if g.has_method("age") else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(g.global_position.round()))
	for i in POINTS_BRAISES:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * rayon * 0.75
		var phase := rng.randf() * TAU
		var p := g.global_position + Vector2(cos(a), sin(a)) * r
		var scintille := 0.65 + 0.35 * sin(age * (2.0 + rng.randf() * 3.0) + phase)
		_poser_halo(e, i, Vector3(p.x, 1.5 + rng.randf() * 2.5, p.y), 3.0 + rng.randf() * 2.0,
			Charte.AMBRE, part * scintille, 1)


func _suivre_lentille(g: Node2D, vus: Dictionary) -> void:
	var e := _entree(g, "lentille", vus, 1)
	_halos(e, 1)
	var lentille := g.get_node_or_null(^"Lentille") as CanvasItem
	if lentille != null:
		_retirer_dessin(e, lentille)
	var faisceau := g.get_node_or_null(^"Faisceau") as Light2D
	var part := clampf(faisceau.energy / 2.5, 0.0, 1.0) if faisceau != null and faisceau.enabled else 0.0
	var p := g.to_global(Vector2(10.0, 0.0))
	_poser_halo(e, 0, Vector3(p.x, HAUTEUR_LENTILLE * TUILE, p.y), 5.0,
		lentille.get("color") if lentille != null else Charte.HALOGENE, part, 1)


## ISO13, lot E — LE CŒUR CHAUD À LA LAMPE, et lui seul.
##
## Le lot devait aussi rendre le RAYON visible dans l'air. **Il s'arrête**, sur décision de la session cloud
## (2026-09-24, 02:03), et il n'en reste rien ici — pas une densité à zéro, qui poserait encore des couches
## et coûterait sans rien dessiner. Trois raisons, mesurées (`docs/iso/iso13/plan_lots_d_e.md`) :
## - il ne se lit à aucune densité : 3/255 de médiane dans le cône au mieux ;
## - il salit le noir dès qu'il commence à se voir : une couche EN HAUTEUR est dessinée plus haut que le
##   sol qu'elle lit (parallaxe, tangage 52°) — 307 pixels isolés dans le noir à 0,45, 15 couches posées
##   au sol, 1 de bruit ;
## - il rendrait à la lampe une hauteur qu'une décision d'Adrien lui refuse face aux murets (2026-09-15).
## Ce qu'il faudrait pour qu'il revienne est écrit à la ROADMAP.
##
## Le cœur, lui, est une lueur à la lampe même, comme la lentille de la torche fantôme : une source, pas
## un volume, et il ressemble aux deux illustrations (accueil, intro « allumage »).
func _suivre_faisceau(j: Node2D, vus: Dictionary) -> void:
	var lampe := j.get_node_or_null(^"Flashlight") as PointLight2D
	if lampe == null or not lampe.enabled or lampe.energy <= 0.0:
		return
	var centre := lampe.global_position
	var part := clampf(lampe.energy / 2.5, 0.0, 1.0)
	var c := _entree(j, "coeur_lampe", vus, 1)
	_halos(c, 1)
	_poser_halo(c, 0, Vector3(centre.x, HAUTEUR_COEUR_LAMPE * TUILE, centre.y),
		TAILLE_COEUR_LAMPE, lampe.color, part, 1)


func _suivre_eclair(g: Node2D, vus: Dictionary) -> void:
	var feu := g.get_node_or_null(^"Embrasement") as Light2D
	var part := clampf(feu.energy / 6.0, 0.0, 1.0) if feu != null and feu.enabled else 0.0
	var e := _entree(g, "eclair", vus, 1)
	_halos(e, 2)
	var p := Vector3(g.global_position.x, HAUTEUR_ECLAIR_MINE * TUILE, g.global_position.y)
	_poser_halo(e, 0, p, 70.0, Charte.HALOGENE, 0.55 * part, 0)
	_poser_halo(e, 1, p, 12.0, Charte.HALOGENE, part, 1)


## L'éclat de bouche au bout de l'arme du corps voxel : le dessin 2D sort des lightmaps (il y était couché
## au canon) et sa lueur se lève à la hauteur de l'arme. Sans corps voxel, au canon, à hauteur de torse.
func _suivre_eclats(main: Node, presentation: Node, vus: Dictionary) -> void:
	var voxels: Array = presentation.get("_voxels") if presentation != null and "_voxels" in presentation else []
	for j in 2:
		var joueur = main.p1 if j == 0 else main.p2
		if not is_instance_valid(joueur):
			continue
		var bouche := (joueur as Node).get_node_or_null(^"Muzzle") as Node2D
		var eclat := bouche.get_node_or_null(^"EclatDessine") as Sprite2D if bouche != null else null
		if eclat == null:
			continue
		var e := _entree(eclat, "eclat", vus, 1)
		_halos(e, 2)
		_retirer_dessin(e, eclat)
		var flash := (joueur as Node).get_node_or_null(^"MuzzleFlash") as Light2D
		var part := Presentation3D.opacite_rendue(eclat)
		if flash == null or not flash.enabled:
			part = 0.0
		var bout: Variant = _bout_de_l_arme(voxels[j] if j < voxels.size() else null)
		if bout == null:
			bout = Vector3(bouche.global_position.x, MursBas.HAUTEUR_DEBOUT * 0.6 * TUILE, bouche.global_position.y)
		_poser_halo(e, 0, bout, 30.0, eclat.modulate, 0.8 * part, 0)
		_poser_halo(e, 1, bout, 8.0, eclat.modulate, part, 1)


## Le bout de l'arme du corps voxel, en pixels du monde 3D, ou `null`.
##
## `VoxelCorps.pointe_arme()` (ISO Corps, vague 5, sur `iso-corps`) le dit depuis le maillage réel de l'arme
## à chaque pose ; tant que cette vague n'est pas fusionnée, on lit la boîte sous le pivot `Torse/Arme`.
static func _bout_de_l_arme(corps: Variant) -> Variant:
	if not (corps is Node3D) or not is_instance_valid(corps) or not (corps as Node3D).is_visible_in_tree():
		return null
	if (corps as Node3D).has_method("pointe_arme"):
		# `global_transform` tel quel (précisé par ISO Corps) : l'ancre à l'échelle d'une tuile y est déjà
		# composée, la position sort en pixels du monde 3D. Aucune conversion ici.
		var pointe: Dictionary = (corps as Node3D).call("pointe_arme")
		return pointe.get("position", null)
	var pivot := (corps as Node3D).get_node_or_null(^"Torse/Arme") as Node3D
	if pivot == null:
		return null
	for enfant in pivot.get_children():
		if enfant is MeshInstance3D:
			# La boîte de l'arme est centrée à mi-longueur devant son pivot : le bout est au double.
			return pivot.global_transform * ((enfant as MeshInstance3D).position * 2.0)
	return null


## L'onde de mort : l'anneau couché au sol, testé en profondeur. Le dessin 2D sort des lightmaps.
func _suivre_onde(onde: Node2D, vus: Dictionary) -> void:
	var e := _entree(onde, "onde", vus)
	_retirer_dessin(e, onde)
	if (e["noeuds"] as Array).is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Onde"
		mi.mesh = ImmediateMesh.new()
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_TRAIT
		mat.set_shader_parameter("avec_texture", false)
		mat.set_shader_parameter("couleur", OndeDeMort.RING_COLOR)
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)
	var mi: MeshInstance3D = e["noeuds"][0]
	var anneau: Vector2 = OndeDeMort.anneau_a(float(onde.get("_age")))
	var m := mi.mesh as ImmediateMesh
	m.clear_surfaces()
	mi.visible = anneau.y > 0.0 and not _masques
	if not mi.visible:
		return
	var c := onde.global_position
	var r0 := maxf(anneau.x - anneau.y * 0.5, 0.0)
	var r1 := anneau.x + anneau.y * 0.5
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in OndeDeMort.SEGMENTS + 1:
		var a := TAU * i / OndeDeMort.SEGMENTS
		var d := Vector2(cos(a), sin(a))
		m.surface_set_uv(Vector2(float(i) / OndeDeMort.SEGMENTS, 0.0))
		m.surface_add_vertex(Vector3(c.x + d.x * r0, MiroirsIso.HAUTEUR_QUAD_PX, c.y + d.y * r0))
		m.surface_set_uv(Vector2(float(i) / OndeDeMort.SEGMENTS, 1.0))
		m.surface_add_vertex(Vector3(c.x + d.x * r1, MiroirsIso.HAUTEUR_QUAD_PX, c.y + d.y * r1))
	m.surface_end()


# ---------------------------------------------------------------------------
# LA TOILE DU VOILE — étape 5
# ---------------------------------------------------------------------------

## La toile, debout entre ses piquets : un ruban qui suit l'ondulation de la `Line2D` et montre la lightmap
## au pied de chaque point — la toile telle que la lampe l'éclaire. Le dessin 2D reste dans la lightmap :
## c'est lui qu'elle recopie.
func _suivre_toile(g: Node2D, vus: Dictionary) -> void:
	var toile := g.get_node_or_null(^"Visuel") as Line2D
	if toile == null or toile.points.size() < 2:
		return
	var e := _entree(g, "toile", vus, 2)
	if (e["noeuds"] as Array).is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Toile"
		mi.mesh = ImmediateMesh.new()
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := _materiau_volume()
		mat.set_shader_parameter("ruban", true)
		mat.set_shader_parameter("densite", 0.92)
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)
	var mi: MeshInstance3D = e["noeuds"][0]
	mi.visible = toile.is_visible_in_tree()
	var m := mi.mesh as ImmediateMesh
	m.clear_surfaces()
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var xf := toile.global_transform
	for i in toile.points.size():
		var p: Vector2 = xf * toile.points[i]
		var u := float(i) / float(toile.points.size() - 1)
		m.surface_set_uv(Vector2(u, 1.0))
		m.surface_add_vertex(Vector3(p.x, PLANCHER_PX, p.y))
		m.surface_set_uv(Vector2(u, 0.0))
		m.surface_add_vertex(Vector3(p.x, HAUTEUR_TOILE * TUILE, p.y))
	m.surface_end()


# ---------------------------------------------------------------------------
# LA MÉCANIQUE COMMUNE
# ---------------------------------------------------------------------------

## `cle` distingue plusieurs entrées pour une même source (la fumée et la lueur d'une fusée posée).
func _entree(source: Object, genre: String, vus: Dictionary, cle: int = 0) -> Dictionary:
	var id := _cle(source, cle)
	vus[id] = true
	var e: Dictionary = _suivis.get(id, {})
	if e.is_empty() or e["genre"] != genre:
		_retirer(id)
		e = {"genre": genre, "source": weakref(source), "noeuds": [], "mats": [], "retires": []}
		_suivis[id] = e
	return e


## Une fois par processus : la ligne qui atteste le masque dans le journal, lue sur la variante réellement posée — même forme
## que « [usure] allumée ».
static var _masque_annonce := false
## La variante masquée des volumes, une fois posée. ⚠️ `_pousser_lightmaps` choisit ses matériaux PAR LEUR SHADER : sans elle
## dans son filtre, une couche masquée ne reçoit AUCUNE lightmap et lit la texture par défaut — la fumée s'éclaire partout
## (premier sandwich, 2026-09-25 09:21 : 73 609 pixels fautifs contre 12 855 sans masque, la fumée presque trois fois plus
## claire dans la lumière).
var _shader_masque: Shader = null


func _materiau_volume() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_VOLUME
	if masque_fumee:
		_poser_masque(mat, true)
	mat.render_priority = PRIORITE_VOLUME
	# Raccords de la vague — la teinte chaude du sol et des murs (ISO7), nulle sans beauté.
	mat.set_shader_parameter("temperature", IsoMateriaux.TEMPERATURE if IsoMateriaux.beaute_active() else 0.0)
	return mat


## ISO13, Q31 — le masque posé sur une couche (ou retiré), sur place : la variante, son facteur, et la ligne qui l'atteste.
func _poser_masque(mat: ShaderMaterial, actif: bool) -> void:
	if not actif:
		mat.shader = SHADER_VOLUME
		return
	mat.shader = variante_masque(IsoMateriaux.usure_essai_active())
	_shader_masque = mat.shader
	_recopier_le_mur(mat)
	if not _masque_annonce:
		_masque_annonce = true
		print("[fumée masque] allumé — variante FUMEE_MASQUE posée (%s) ; point noir de l'écran 3D : %s ; usure %s"
			% ["#define FUMEE_MASQUE dans son code" if mat.shader.code.contains("#define FUMEE_MASQUE\n")
			else "⚠ SANS le #define : variante manquée", POINT_NOIR_ANNONCE,
			"recopiée (#define USURE_ESSAI, comme le sol)" if mat.shader.code.contains("#define USURE_ESSAI\n")
			else "éteinte, comme le sol"])


## Le point noir de la sortie 3D, tel que la couche le prend (`POINT_NOIR_ECRIT` de `volume_masque.gdshaderinc`) : imprimé
## avec la ligne du masque, pour qu'une prise dise quelle règle a porté.
const POINT_NOIR_ANNONCE := "écrit sous 8/255 → noir (rampes du 2026-09-25 : 7 → 0, 8 → 1)"
## Les réglages du SOL (`sol_iso.gdshader`) que la couche recopie, sous le nom qu'ils portent chez elle (préfixe `sol_`, le
## mur et la fumée ayant déjà une matière et une température) ; et la température des MURS (préfixe `mur_`).
const PARAMETRES_DU_SOL := {"texture_sol": "sol_texture_sol", "periode_sol_px": "sol_periode_sol_px",
	"force_matiere": "sol_force_matiere", "dalle_px": "sol_dalle_px", "joint_dalle_px": "sol_joint_dalle_px",
	"joint_dalle_reste": "sol_joint_dalle_reste", "temperature": "sol_temperature",
	"temperature_seuil_bas": "sol_temperature_seuil_bas", "temperature_seuil_haut": "sol_temperature_seuil_haut",
	"neutre_avant_pate": "sol_neutre_avant_pate", "dalles": "dalles", "joint_2d_px": "joint_2d_px",
	"contact_corps_rayon_px": "contact_corps_rayon_px", "contact_corps_reste": "contact_corps_reste"}
const TEMPERATURE_DU_MUR := {"temperature": "mur_temperature", "temperature_seuil_bas": "mur_temperature_seuil_bas",
	"temperature_seuil_haut": "mur_temperature_seuil_haut", "neutre_avant_pate": "mur_neutre_avant_pate"}
## Le contact des corps bouge à chaque image : recopié par `_pousser_lightmaps`.
const CONTACT_PAR_IMAGE := ["contact_corps_1", "contact_corps_2"]
## L'USURE, quand elle est allumée : l'interrupteur et la proximité des murs viennent du SOL ; les impacts viennent du MUR, qui
## les reçoit à chaque éclat — recopiés à chaque image avec le contact.
const USURE_DU_SOL := ["usure", "usure_proximite"]
const USURE_DU_MUR := ["usure_impacts", "usure_impacts_n"]
## Les réglages du mur, RECOPIÉS depuis le matériau même des murs de la présentation (la grille de la carte, la peinture, la
## matière des faces, leur pied et leur contact) : la couche juge une face comme `mur_iso.gdshader` la calcule, avec les
## MÊMES valeurs. Sans présentation (une suite headless), la grille reste inactive et seul le sol est jugé.
const PARAMETRES_DU_MUR := ["pied", "texture_face", "periode_face_px", "force_matiere", "contact_px", "contact_reste",
	"grille_murs", "grille_active", "grille_origine_px", "grille_cases", "tuile_px", "peinture", "peinture_active",
	"peinture_origine_px", "peinture_taille_px", "peinture_etalon_px", "peinture_plancher_px"]


func _recopier_le_mur(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("mur_haut_px", MapGeometry.HAUTEUR_MUR_HAUT * TUILE)
	mat.set_shader_parameter("muret_px", MapGeometry.HAUTEUR_MUR_BAS * TUILE)
	var pres := Presentation3D.instance()
	var mur: ShaderMaterial = pres.get("_mat_mur") if pres != null else null
	if mur == null:
		return
	for nom: String in PARAMETRES_DU_MUR:
		mat.set_shader_parameter(nom, mur.get_shader_parameter(nom))
	for nom: String in TEMPERATURE_DU_MUR:
		mat.set_shader_parameter(TEMPERATURE_DU_MUR[nom], mur.get_shader_parameter(nom))
	# Et le SOL de la vue de J1 (`_mat_sols[0]`) : la couche calcule la couleur qu'il écrit.
	var sols: Array = pres.get("_mat_sols")
	if not sols.is_empty() and sols[0] != null:
		for nom: String in PARAMETRES_DU_SOL:
			mat.set_shader_parameter(PARAMETRES_DU_SOL[nom], (sols[0] as ShaderMaterial).get_shader_parameter(nom))
		for nom: String in USURE_DU_SOL:
			mat.set_shader_parameter(nom, (sols[0] as ShaderMaterial).get_shader_parameter(nom))


## La variante masquée des volumes, avec ou sans l'usure. ⚠️ PARITÉ : elle porte USURE_ESSAI si et seulement si le sol la
## porte — le même interrupteur (`IsoMateriaux.usure_essai_active`), lu au même endroit. Sans elle, une usure allumée au sol
## (Q30) assombrirait un sol que la fumée croirait éclairé : la fumée resterait sur un pixel que l'écran montre noir.
static func variante_masque(usure: bool) -> Shader:
	var v := IsoMateriaux.variante_definie(SHADER_VOLUME, "FUMEE_MASQUE")
	return IsoMateriaux.variante_definie(v, "USURE_ESSAI") if usure else v


## ISO13, Q31 — la bascule des bancs : le masque allumé ou éteint sur les couches DÉJÀ posées, au même instant, sans rien
## recréer (la preuve en un seul processus compare la même fumée avec et sans lui).
func poser_masque_fumee(actif: bool) -> void:
	masque_fumee = actif
	for e: Dictionary in _suivis.values():
		for m in e["mats"]:
			var s := (m as ShaderMaterial).shader
			if s == SHADER_VOLUME or (s != null and s == _shader_masque):
				_poser_masque(m as ShaderMaterial, actif)


func _couches(e: Dictionary, n: int) -> void:
	while (e["noeuds"] as Array).size() < n:
		var mi := MeshInstance3D.new()
		mi.name = "Couche%d" % (e["noeuds"] as Array).size()
		mi.mesh = _plan
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := _materiau_volume()
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)


## Les couches, de juste au-dessus du sol à `hauteur` tuiles : le rayon se resserre en montant (un nuage
## se lit en dôme) et chaque couche est plus légère que celle d'en dessous.
func _poser_couches(e: Dictionary, centre: Vector2, rayon: float, hauteur: float, densite: float,
		masque: Texture2D, angle: float, graine: float, age: float) -> void:
	var n := (e["noeuds"] as Array).size()
	for i in n:
		var f := float(i) / float(maxi(n - 1, 1))
		var mi: MeshInstance3D = e["noeuds"][i]
		var r := rayon * (1.0 - 0.22 * f)
		mi.position = Vector3(centre.x, maxf(PLANCHER_PX, hauteur * TUILE * float(i + 1) / float(n)), centre.y)
		mi.scale = Vector3(r * 2.0, 1.0, r * 2.0)
		mi.visible = densite > 0.0
		var mat: ShaderMaterial = e["mats"][i]
		mat.set_shader_parameter("nuage_centre", centre)
		mat.set_shader_parameter("nuage_rayon", r)
		mat.set_shader_parameter("nuage_angle", angle)
		mat.set_shader_parameter("densite", densite * (1.0 - 0.45 * f))
		mat.set_shader_parameter("masque", masque)
		mat.set_shader_parameter("avec_masque", masque != null)
		mat.set_shader_parameter("nuage_graine", graine + float(i) * 7.0)
		mat.set_shader_parameter("age", age)


func _halos(e: Dictionary, n: int, shader: Shader = SHADER_HALO) -> void:
	while (e["noeuds"] as Array).size() < n:
		var mi := MeshInstance3D.new()
		mi.name = "Lueur%d" % (e["noeuds"] as Array).size()
		mi.mesh = _quad
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)


func _poser_halo(e: Dictionary, i: int, position_px: Vector3, taille_px: float, couleur: Color,
		intensite: float, forme: int) -> void:
	var mi: MeshInstance3D = e["noeuds"][i]
	mi.position = position_px
	mi.scale = Vector3.ONE * maxf(taille_px, 0.001)
	mi.visible = intensite > 0.002 and not _masques
	var mat: ShaderMaterial = e["mats"][i]
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("intensite", intensite)
	mat.set_shader_parameter("forme", forme)


## Sort un dessin 2D des lightmaps, par le registre de `MiroirsIso` (une seule main sur `visibility_layer`).
func _retirer_dessin(e: Dictionary, item: CanvasItem) -> void:
	if (e["retires"] as Array).has(item):
		return
	if miroirs != null:
		miroirs.call("_retirer_de_la_lightmap", item)
	e["retires"].append(item)


func _retirer(id: String) -> void:
	var e: Dictionary = _suivis.get(id, {})
	if e.is_empty():
		return
	for item in e["retires"]:
		# Un dessin que le miroir d'un objet posé a repris (le cœur d'une fusée qui vient d'atterrir)
		# reste à lui : c'est lui qui le rendra.
		if miroirs != null and is_instance_valid(item) and not bool(miroirs.call("tient_le_dessin", item)):
			miroirs.call("_rendre_a_la_lightmap", item)
	for mi in e["noeuds"]:
		if is_instance_valid(mi):
			(mi as Node).queue_free()
	_suivis.erase(id)


## Les lightmaps et leur repère, poussés aux matériaux qui les lisent — la même lecture que le sol
## (`Presentation3D._suivre`), pour les vues projetées et non gelées.
func _pousser_lightmaps(main: Node, vues: Array, style: int) -> void:
	var mats: Array = []
	for e: Dictionary in _suivis.values():
		for m in e["mats"]:
			var s := (m as ShaderMaterial).shader
			if s == SHADER_VOLUME or (s != null and s == _shader_masque):
				mats.append(m)
	if mats.is_empty():
		return
	# Le contact des corps change à chaque image : recopié du sol de la vue de J1 sur les couches masquées.
	if _shader_masque != null:
		var pres := Presentation3D.instance()
		var sols: Array = pres.get("_mat_sols") if pres != null else []
		if not sols.is_empty() and sols[0] != null:
			var mur: ShaderMaterial = pres.get("_mat_mur")
			for m in mats:
				if (m as ShaderMaterial).shader == _shader_masque:
					for nom: String in CONTACT_PAR_IMAGE:
						(m as ShaderMaterial).set_shader_parameter(nom, (sols[0] as ShaderMaterial).get_shader_parameter(nom))
					if mur != null and _shader_masque.code.contains("#define USURE_ESSAI\n"):
						for nom: String in USURE_DU_MUR:
							(m as ShaderMaterial).set_shader_parameter(nom, mur.get_shader_parameter(nom))
	var textures := [main.vp1.get_texture(), main.vp2.get_texture()]
	for id in vues:
		var vue: SubViewport = main.vp1 if id == 0 else main.vp2
		if vue.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			continue
		var canevas: Transform2D = vue.canvas_transform
		var taille := Vector2(vue.size_2d_override) if vue.size_2d_override != Vector2i.ZERO else Vector2(vue.size)
		var n := int(id) + 1
		for m: ShaderMaterial in mats:
			m.set_shader_parameter("lumiere_%d" % n, textures[id])
			m.set_shader_parameter("canevas_%d_x" % n, canevas.x)
			m.set_shader_parameter("canevas_%d_y" % n, canevas.y)
			m.set_shader_parameter("canevas_%d_o" % n, canevas.origin)
			m.set_shader_parameter("taille_%d" % n, taille)
			m.set_shader_parameter("style", style)
