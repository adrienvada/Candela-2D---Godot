## Les lumières 3D de la vue iso — chantier ISO12, lot 0 (plan-delta accepté par la session cloud, 2026-09-15 22:15).
##
## **Un MIROIR, pas une seconde logique.** Chaque lumière 3D recopie, à chaque image, une source Light2D du jeu :
## allumée ou non, énergie, couleur, position, hauteur. La liste des sources est FERMÉE :
## - la torche (`Flashlight`) et le flash de tir (`MuzzleFlash`) de chaque joueur ;
## - leurs doubles de killcam (`GhostPN/Light`, `GhostPN/Flash`), pilotés par l'instantané ;
## - le halo des fusées (`Halo`), la lueur des braises (`Lueur`), l'embrasement de la mine (`Embrasement`) et le
##   faisceau de la torche fantôme (`Faisceau`).
## - la RÉTRODIFFUSION : `BodyLight` de chaque joueur et le `Halo` de la torche fantôme (drapeau `retrodiffusion`).
##   ⚠️ Écartée au plan, rendue après la première passe du banc (2026-09-15 22:45) : sans elle, la vue 3D montrait MOINS que
##   la 2D — le halo qui trahit le porteur et le corps de J2 disparaissaient. La bride empêche d'en montrer plus, rien
##   n'empêchait d'en montrer moins ; le rendu Compatibility ne simule pas la lumière qui revient d'une surface.
## JAMAIS : `ambient_light` (la silhouette de soi, lumière privée d'une vue), les échos privés. Aucune lumière qui ne soit une source
## du jeu : le noir absolu tient par construction, et la bride (`sol_iso_eclaire`, `mur_iso_eclaire`) le garantit pixel
## par pixel — là où la lightmap de la vue dit 0, la couleur vaut 0.
##
## **Équité** : les constantes d'énergie par type de source sont les mêmes pour les deux joueurs et les deux vues, sans
## curseur. Le cône 3D est un peu plus large et un peu plus long que le cône 2D : le bord visible appartient à la bride,
## la 3D ne doit pas dessiner un second bord dans le cône.
##
## Pas de `class_name` : chargé par son chemin, lisible par les suites en `--script` sans import préalable.
extends Node3D

const TUILE := 35.0
## ISO12 v27 — les poids de luminance de la pâte, recopiés de `PATE_POIDS` (`iso_pate.gdshaderinc`) : l'intensité d'une
## lampe au dénominateur du relief se mesure avec la luminance même qui lit R. `tools/test_banc.gd` vérifie qu'ils concordent.
const POIDS_PATE := Vector3(0.2126, 0.7152, 0.0722)
## Le cône 3D dépasse le cône 2D de cinq degrés, adouci (décision de la session cloud, 22:15).
const CONE_EN_PLUS_DEG := 5.0
## L'angle plancher d'un spot de torche. ⚠️ Preuve rejouée du 2026-09-15 (23:48) : le faisceau de 5° du Braconnier, en spot de 10°,
## ne touchait le sol qu'à ~130 px devant la lampe et la bande proche restait noire en 3D alors que la 2D la montre. Le bord
## visible du cône est celui de la bride : le spot 3D doit seulement COUVRIR toute la zone du cône 2D, de la lampe au bout.
const CONE_PLANCHER_DEG := 45.0
const ATTENUATION_ANGULAIRE := 2.0
## La portée 3D dépasse un peu la portée 2D, pour la même raison.
const PORTEE_EN_PLUS := 1.15
## La torche vise le point du sol à cette fraction de sa portée. ⚠️ Penchée de 8° seulement (première passe du banc), elle
## ne touchait le sol qu'à ~250 px devant la lampe : le sol entre le porteur et le mur restait noir.
const VISEE_AU_SOL_PORTEE := 0.5
## Les types de source. Les énergies sont calibrées au banc (`tools/banc_lumiere3d.gd`) : une par type, pour tous.
const TYPES := ["torche", "flash", "fusee", "braise", "mine", "torche_fantome", "retrodiffusion"]
## Calibrées au banc le 2026-09-15. Cinquième passe rapide (bandeau de LED figé), luminance moyenne là où la 2D est éclairée,
## 3D sur 2D : cône de torche 1,06 à 1,29 avec 6, halo de fusée 0,77 à 0,84 avec 20, rétrodiffusion 1,10 avec 1. Puis ramenées
## vers 1,0 ± 0,1 (demande de la session cloud, 23:42) : torche 3,6 et fusée 52, à revérifier au banc.
## Les mêmes pour les deux joueurs et les deux vues : c'est de l'équité, pas un réglage.
var energie_par_type := {"torche": 3.6, "flash": 3.6, "fusee": 52.0, "braise": 52.0, "mine": 52.0, "torche_fantome": 3.6,
	"retrodiffusion": 0.8}
var retrodiffusion := true
## ISO12 — l'atténuation par type (`omni_attenuation` / `spot_attenuation`, 1 = inverse du carré, 0 = plat).
##
## ⚠️ **L'ATTÉNUATION PLATE A ÉTÉ ESSAYÉE PUIS RÉFUTÉE PAR LA MESURE (lot 0 quater).** Elle venait du principe « la 2D donne
## l'intensité, la 3D ne donne que le relief », et le principe est juste — c'est le mécanisme qui ne l'était pas. Aplatir
## supprime ce qui empêche plusieurs lampes de s'additionner au-delà du blanc : la fusée est passée à **42 932 pixels blancs
## contre 14 en 2D**, dès l'énergie ×1,0 (donc pas à cause d'un niveau trop haut). Et le rapport 3D/2D ne pouvait pas devenir
## constant : `lumière3D(x)` dépend du nombre de lampes qui atteignent le point, si bien que +70 % d'énergie a ÉLARGI l'écart
## entre cadrages (0,36-0,77 → 0,40-0,99) au lieu de le refermer.
##
## ⚠️ **ET POURTANT : DÉCROISSANCE NULLE, SOUS LE RELIEF NORMALISÉ** (session cloud, 2026-09-22, 23:46). Ce n'est pas le retour
## de l'atténuation plate réfutée ci-dessus : celle-là laissait les lampes s'ADDITIONNER au-delà du blanc sous le Lambert brut.
## Sous le relief, la couleur vaut albédo × L2D × R — l'intensité vient de L2D, et la décroissance ne fait plus que PONDÉRER les
## lampes entre elles dans R ; la fenêtre de portée du moteur, (1 − (d/r)⁴)², efface toujours une lampe au bord de sa portée.
## Et c'est mesuré : à décroissance 1, le numérateur du moteur ne suivait pas d^(−1) dans nos unités (R croissait de 1,1 à 11,5
## le long d'un cône) ; à 0, moteur et dénominateur coïncident sur le sol à 5 % près. La table reste la poignée : un type absent
## vaut 0, spots compris (`spot_attenuation`, posé à chaque image dans `_torche`).
var attenuation_par_type := {}
var ombres := true
## ISO12 L4 — INSTRUMENT DE BANC : toutes les énergies de type à 1,0. Depuis la v27, `energie_par_type` n'est plus une
## luminosité — elle se simplifie dans R pour une lampe seule — mais un POIDS entre lampes : 52 contre 3,6 fait peser une
## fusée quarante fois ce qu'elle pèse en 2D face à une torche, et le modelé du cône peut disparaître là où les deux se
## rencontrent. Le défaut se décide sur la planche, pas ici (ISO7 Gadgets, session cloud, 2026-09-23).
var energies_neutres := false
## Le plancher global du dénominateur, en GDScript : vaut le défaut de `relief_epsilon` dans l'include (garde croisée dans
## `tools/test_banc.gd`).
const RELIEF_EPSILON := 0.02
## ISO12 v27 — LE BIAIS D'OMBRE, EN PIXELS. Les défauts de Godot sont pensés en mètres ; ici une unité vaut un pixel, et ils
## valaient une fraction de pixel, moins qu'un texel de carte d'ombre : la face d'un mur qui REGARDE la torche se faisait de
## l'ombre à elle-même — noire, rayée. Balayé au banc le 2026-09-22 (face avec ombres sur face sans ombres ; « rayures » =
## écart-type des moyennes de lignes, 1,7 sans ombres) : défaut 0,007 ; 12 px 0,816 rayée (51,6) ; 14 px 1,025 encore rayée
## (36,2) ; **16 px 1,063 sans rayure (1,7)** ; 20 px 1,052 ; 40 px 1,070. Le biais normal seul n'y suffit pas (4 px : 0,047).
## Le décollement de l'ombre d'un corps à 16 px : 1 px à l'écran (34 → 33), accepté jusqu'à 3. Posé à chaque image dans
## `_recopier` : une valeur posée sur la lampe ailleurs serait écrasée à l'image suivante.
var biais_ombre := 16.0
## Économies du brief, dans l'ordre : `ombres_omni` faux — pas d'ombre sur les omni (fusées, flashs, braises, mine,
## rétrodiffusion : six faces par omni et par image) ; `ombres_torches_joueurs_seules` vrai — une seule lumière ombrée par
## joueur, sa torche (la torche fantôme perd la sienne).
var ombres_omni := true
var ombres_torches_joueurs_seules := false
## `OmniLight3D.SHADOW_CUBE` : le seul mode d'ombre omni du rendu Compatibility (le double paraboloïde y est refusé à
## chaque image — premier passage du banc, 2026-09-15 22:45).
var mode_ombre_omni := OmniLight3D.SHADOW_CUBE

const IsoVolumesT := preload("res://iso_volumes.gd")

## instance_id de la Light2D → Light3D.
var _pool := {}
## ISO12 — l'instant (`Time.get_ticks_usec`) du PREMIER allumage de chaque sorte de lampe (clé : le type du miroir). Dans le
## rendu Compatibility, une lampe sans ombre entre dans la passe de base de chaque objet qu'elle touche et en fait compiler une
## variante (omni ou spot) ; une lampe à ombre ajoute une passe additive par sorte et sa passe d'ombre (lu dans le source de
## Godot par la session cloud, 2026-09-23). Le banc de cadence date sa pire image contre ces instants : une pire image qui
## tombe sur un premier allumage est une COMPILATION, pas un coût de régime — et en match, elle tomberait au premier tir.
var premiers_allumages := {}


## Une image. `main` : le jeu ; `voxels` : les corps voxel de la présentation (pour le bout de l'arme).
func suivre(main: Node, voxels: Array) -> void:
	var vus := {}
	for j in 2:
		var joueur = main.p1 if j == 0 else main.p2
		if not is_instance_valid(joueur):
			continue
		var corps: Variant = voxels[j] if j < voxels.size() else null
		var arme: WeaponData = joueur.get("current_weapon")
		# En PIXELS : `MursBas.hauteur_de_posture` rend la hauteur du canon, celle que la balle et la lumière du jeu lisent
		# (debout, une tuile ; accroupi, sous le muret — « la torche d'un accroupi bute sur le mur »).
		var hauteur_px := MursBas.hauteur_de_posture(bool(joueur.get("accroupi")))
		_torche(joueur.get_node_or_null(^"Flashlight") as Light2D, arme, hauteur_px, "torche", vus)
		_omni(joueur.get_node_or_null(^"MuzzleFlash") as Light2D, "flash", _bout(corps, joueur, hauteur_px), vus)
		if retrodiffusion:
			var retro := joueur.get_node_or_null(^"BodyLight") as Light2D
			if retro != null:
				var pr := retro.global_position
				_omni(retro, "retrodiffusion", Vector3(pr.x, hauteur_px, pr.y), vus)
	for j in 2:
		var fantome := main.get("ghost_p%d" % (j + 1)) as Node2D
		if fantome == null or not fantome.visible:
			continue
		var snap = main.get("current_snap")
		var arme_rejouee: WeaponData = snap.get("p%d_weapon" % (j + 1)) if snap != null else null
		var accroupi_rejoue: bool = bool(snap.get("p%d_accroupi" % (j + 1))) if snap != null else false
		var h_px := MursBas.hauteur_de_posture(accroupi_rejoue)
		_torche(fantome.get_node_or_null(^"Light") as Light2D, arme_rejouee, h_px, "torche", vus)
		var flash_rejoue := fantome.get_node_or_null(^"Flash") as Light2D
		if flash_rejoue != null:
			var pf := flash_rejoue.global_position
			_omni(flash_rejoue, "flash", Vector3(pf.x, h_px, pf.y), vus)
	var conteneur: Node = main.get("bullet_container")
	if conteneur != null:
		for noeud in conteneur.get_children():
			if not (noeud is Node2D) or (noeud as Node).is_queued_for_deletion():
				continue
			if "_atterrie" in noeud and "graine" in noeud:
				_omni(noeud.get_node_or_null(^"Halo") as Light2D, "fusee", null, vus)
			elif "poseur_id" in noeud and "slug" in noeud:
				_omni(noeud.get_node_or_null(^"Lueur") as Light2D, "braise", null, vus)
				_omni(noeud.get_node_or_null(^"Embrasement") as Light2D, "mine", null, vus)
				var faisceau := noeud.get_node_or_null(^"Faisceau") as Light2D
				if faisceau != null:
					_torche(faisceau, noeud.get("classe_du_poseur") as WeaponData,
						MursBas.HAUTEUR_DEBOUT * 0.6 * TUILE, "torche_fantome", vus)
				var halo := noeud.get_node_or_null(^"Halo") as Light2D
				if retrodiffusion and halo != null and faisceau != null:
					var ph := halo.global_position
					_omni(halo, "retrodiffusion", Vector3(ph.x, MursBas.HAUTEUR_DEBOUT * 0.6 * TUILE, ph.y), vus)
	for id in _pool.keys():
		if not vus.has(id):
			(_pool[id] as Node).queue_free()
			_pool.erase(id)
	_plafonner(LAMPES_MAX)


## ISO12 v27 — AU PLUS HUIT LAMPES MIROIR ALLUMÉES À LA FOIS (décision de la session cloud, 2026-09-23, 03:50) : les huit plus
## intenses, départagées par ordre d'apparition dans le pool ; les autres ÉTEINTES en 3D. Leur lumière reste dans la couleur 2D
## (principe d'identité) : l'équité n'y perd rien. Au-delà de huit, le dénominateur du relief (huit lampes, triées par intensité)
## et les lampes que le moteur apparie à chaque objet (`max_lights_per_object`, 8) n'étaient plus le même jeu : au banc, neuf
## lampes et plus éclaircissaient le sol de 8 % sans ombres, et de 15 000 à 70 000 px avec (lampe dominante comprise).
const LAMPES_MAX := 8


## L'intensité d'une lampe telle que le relief la pèse : énergie × luminance de sa couleur LINÉARISÉE, aux poids de la pâte.
func _intensite(l: Light3D) -> float:
	var c := l.light_color.srgb_to_linear()
	return l.light_energy * POIDS_PATE.dot(Vector3(c.r, c.g, c.b))


func _plafonner(n: int) -> void:
	var allumees: Array = []
	for l: Light3D in _pool.values():
		if l.visible:
			allumees.append(l)
	if allumees.size() <= n:
		return
	# `sort_custom` n'est pas stable : l'ordre d'apparition départage explicitement les égalités d'intensité.
	var rang := {}
	for k in allumees.size():
		rang[allumees[k]] = k
	allumees.sort_custom(func(a, b) -> bool:
		var ia := _intensite(a)
		var ib := _intensite(b)
		return ia > ib if ia != ib else int(rang[a]) < int(rang[b]))
	for k in range(n, allumees.size()):
		(allumees[k] as Light3D).visible = false


## Combien de lumières 3D allumées cette image — le banc le compare au plafond par maillage.
func allumees() -> int:
	var n := 0
	for l: Light3D in _pool.values():
		if l.visible:
			n += 1
	return n


func _torche(source: Light2D, arme: WeaponData, hauteur_px: float, type: String, vus: Dictionary) -> void:
	if source == null or arme == null:
		return
	var l := _lumiere(source, true, vus) as SpotLight3D
	if not _recopier(source, l, type):
		return
	l.shadow_enabled = ombres and not (ombres_torches_joueurs_seules and type != "torche")
	var p := source.global_position
	var devant := Vector2.RIGHT.rotated(source.global_rotation)
	l.global_position = Vector3(p.x, hauteur_px, p.y)
	var au_sol := devant * arme.portee_torche() * VISEE_AU_SOL_PORTEE
	var cible := Vector3(p.x + au_sol.x, 0.0, p.y + au_sol.y)
	l.look_at(cible, Vector3.UP)
	l.spot_angle = clampf(maxf(arme.torch_angle_deg + CONE_EN_PLUS_DEG, CONE_PLANCHER_DEG), 1.0, 89.0)
	l.spot_angle_attenuation = ATTENUATION_ANGULAIRE
	l.spot_attenuation = float(attenuation_par_type.get(type, 0.0))
	l.spot_range = arme.portee_torche() * PORTEE_EN_PLUS


func _omni(source: Light2D, type: String, position_3d: Variant, vus: Dictionary) -> void:
	if source == null:
		return
	var l := _lumiere(source, false, vus) as OmniLight3D
	if not _recopier(source, l, type):
		return
	# La rétrodiffusion ne s'ombre pas : c'est la lumière qui revient sur le porteur, que son propre corps ne bouche pas. ⚠️ Preuve
	# rejouée (23:48) : ombrée, l'omni posée contre le corps voxel de J2 plongeait son propre halo dans l'ombre de ce corps.
	# ⚠️ Le FLASH DE TIR non plus (L4, ISO7 Gadgets). La 2D porte une règle NOMMÉE — « la torche et le flash de tir d'un joueur
	# n'ombrent jamais son propre corps » (`fait_ombre_aux_lumieres_de`, masque `1 | COUCHE_OCCLUDER_ADVERSE`) — que le miroir
	# ne reproduisait nulle part. Or `_eclairer_le_corps` fait porter ombre à toutes les boîtes de couleur dès la lumière 3D
	# allumée : l'omni posée AU BOUT DE L'ARME plongeait le tireur et le sol devant lui dans l'ombre de son propre corps —
	# le défaut de la rétrodiffusion du 2026-09-15 (23:48), sur la source la plus décisive du duel.
	l.shadow_enabled = ombres and ombres_omni and not ombres_torches_joueurs_seules \
		and type != "retrodiffusion" and type != "flash"
	if position_3d is Vector3:
		l.global_position = position_3d
	else:
		var h := MursBasRendu.hauteur_source(source)
		var p := source.global_position
		l.global_position = Vector3(p.x, maxf(h, MursBasRendu.HAUTEUR_AU_RAS_DU_SOL) * TUILE, p.y)
	var rayon := 64.0
	if source.texture != null:
		rayon = float(source.texture.get_width()) * source.texture_scale * 0.5
	# ISO12 L4 — LA PORTÉE EST UNE SPHÈRE, LE RAYON 2D UN DISQUE AU SOL (ISO7 Gadgets) : à la hauteur h, la sphère n'atteint le
	# sol que sur sqrt(portée² − h²), et `rayon × 1,15` laissait un anneau NOIR là où la 2D éclaire (flash 11,4 px au sol pour
	# 32 de rayon ; fusée au lancer 75,5 pour 80) — la garde rendait R = 1 sur une lumière nulle. La sphère doit CONTENIR le
	# disque. Sous le relief normalisé, agrandir une portée ne change rien à l'image déjà éclairée (l'atténuation se simplifie
	# dans R) : cela n'ajoute que l'anneau manquant.
	var h_px := l.global_position.y
	l.omni_range = sqrt(rayon * rayon + h_px * h_px) * PORTEE_EN_PLUS
	l.omni_attenuation = float(attenuation_par_type.get(type, 0.0))
	l.omni_shadow_mode = mode_ombre_omni


## Recopie l'état commun ; faux si la lumière est éteinte cette image.
func _recopier(source: Light2D, l: Light3D, type: String) -> bool:
	var allumee := source.enabled and source.is_visible_in_tree() and source.energy > 0.001
	l.visible = allumee
	if not allumee:
		return false
	if not premiers_allumages.has(type):
		premiers_allumages[type] = Time.get_ticks_usec()
	l.light_color = source.color
	l.light_energy = source.energy * (1.0 if energies_neutres else float(energie_par_type.get(type, 1.0)))
	l.shadow_enabled = ombres
	l.shadow_bias = biais_ombre
	l.light_specular = 0.0
	return true


func _lumiere(source: Light2D, spot: bool, vus: Dictionary) -> Light3D:
	var id := source.get_instance_id()
	vus[id] = true
	var l: Light3D = _pool.get(id, null)
	if l == null or not is_instance_valid(l) or (l is SpotLight3D) != spot:
		if l != null and is_instance_valid(l):
			l.queue_free()
		l = SpotLight3D.new() if spot else OmniLight3D.new()
		l.name = "%s_%d" % [source.name, id]
		add_child(l)
		_pool[id] = l
	return l


## Le bout de l'arme du corps voxel ; à défaut, le canon à hauteur de posture.
func _bout(corps: Variant, joueur: Node2D, hauteur_px: float) -> Vector3:
	var bout: Variant = IsoVolumesT._bout_de_l_arme(corps)
	if bout is Vector3:
		return bout
	var bouche := joueur.get_node_or_null(^"Muzzle") as Node2D
	var p := bouche.global_position if bouche != null else joueur.global_position
	return Vector3(p.x, hauteur_px, p.y)


## ISO12 v27 — LES LAMPES, POUR LE DÉNOMINATEUR DU RELIEF : la liste FERMÉE, telle qu'elle est cette image.
##
## Le relief divise ce que `light()` accumule par ce que les mêmes lampes donneraient sur un sol plat, SANS ombre. Ce
## dénominateur se calcule dans le shader, donc il faut lui passer les lampes : position, intensité, portée, atténuation, et
## pour un spot son cône et sa direction.
##
## ⚠️ **Huit au plus, triées par intensité décroissante** : le moteur n'en fait passer que huit par objet
## (`rendering/limits/opengl/max_lights_per_object`), et un dénominateur qui porterait sur d'autres lampes que le numérateur
## donnerait un rapport faux — plus lumineux là où le dénominateur oublie une lampe, plus sombre là où il en ajoute une.
func decrire_pour_relief() -> Array:
	var out: Array = []
	for l in _pool.values():
		if not is_instance_valid(l):
			continue
		var lumiere := l as Light3D
		if not lumiere.visible:
			continue
		var spot := lumiere is SpotLight3D
		# ⚠️ En LINÉAIRE, aux poids de la pâte (défaut 6 de la revue) : le moteur éclaire avec la couleur linéarisée, et la pâte
		# lit la lumière avec `PATE_POIDS`. En sRGB et Rec. 601, le halo de fusée tombait 35 % sous la 2D et le tri des huit
		# lampes était faussé d'autant.
		var c := lumiere.light_color.srgb_to_linear()
		var luminance := POIDS_PATE.dot(Vector3(c.r, c.g, c.b))
		var intensite := lumiere.light_energy * luminance
		if intensite <= 0.0:
			continue
		var avant := -(lumiere as Node3D).global_transform.basis.z
		var p3: Vector3 = (lumiere as Node3D).global_position
		var portee_l: float = (lumiere as SpotLight3D).spot_range if spot else (lumiere as OmniLight3D).omni_range
		out.append({
			"pos": p3,
			"intensite": intensite,
			"portee": portee_l,
			# ISO12 L4 — ε PAR LAMPE (ISO7 Gadgets) : la plus petite élévation que cette lampe puisse avoir DANS SA PROPRE PORTÉE,
			# h/portée, pour que le plancher ne morde jamais sur le sol qu'elle éclaire. Braises et mine sont posées à 1,75 px :
			# ε = 0,02 y mordait dès 87,5 px, et le bord de leur halo tombait à 0,515 et 0,337. Le `min` n'est pas un ornement : la
			# valeur brute vaut 0,477 pour un flash de tir et multiplierait par vingt-quatre le dénominateur d'un mur situé
			# AU-DESSUS de la lampe. Le plancher ne peut que baisser — braises 0,00895, mine 0,00585, les autres gardent 0,02.
			"epsilon": maxf(minf(p3.y / maxf(portee_l, 0.0001), RELIEF_EPSILON), 1e-4),
			"attenuation": (lumiere as SpotLight3D).spot_attenuation if spot else (lumiere as OmniLight3D).omni_attenuation,
			"cos_demi": cos(deg_to_rad((lumiere as SpotLight3D).spot_angle)) if spot else -1.0,
			"direction": avant if spot else Vector3.ZERO,
			# ⚠️ L'INVERSE de `spot_angle_attenuation` : Godot 4.7 (Compatibility) passe `inv_spot_attenuation = 1 /
			# spot_angle_attenuation` au shader (`drivers/gles3/rasterizer_scene_gles3.cpp`), et c'est lui l'exposant du cône.
			# Recopié tel quel (2 au lieu de 0,5), le dénominateur éclairait bien plus que le moteur loin de l'axe du cône : sous
			# la torche, R valait ~0,3 à 60 px de la lampe, ~0,8 à 120 px, 1 seulement près de l'axe au loin (mesuré au banc,
			# 2026-09-23, masque de sol) — le sol plat sous une torche 6 à 11 % plus sombre que la 2D. L'omni (fusée), sans
			# cône, n'était pas touchée.
			"exposant_cone": 1.0 / maxf((lumiere as SpotLight3D).spot_angle_attenuation, 0.001) if spot else 1.0,
		})
	out.sort_custom(func(a, b) -> bool: return float(a["intensite"]) > float(b["intensite"]))
	return out.slice(0, 8)
