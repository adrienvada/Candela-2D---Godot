extends SceneTree

## L'allègement de la 0.8.0 — les éventails du rayon, pour la planche (`tools/faisceau_taille/planche_eventails.py`) : pour chacun
## des dix cookies livrés, l'enveloppe (`IsoVolumes.enveloppe_de_l_image`), les sommets de l'éventail des couches et de celui
## du juge taillé (`faisceau_juge_taille` : une option à l'allègement, le défaut depuis Q75 ; le rayon entier, sans Q75 D), à la
## portée du bord de l'écran (728 px), dans le repère du maillage (le carré d'avant y va de −0,5 à 0,5), et la part du carré
## que chacun couvre. Aucune règle ici : c'est le code du jeu, lu et écrit en JSON.
##
## Lancer : godot --headless --path . --script res://tools/faisceau_taille/eventails.gd -- <sortie.json>

const COOKIES := ["pompe", "arbalete", "pistolet", "fusil", "allumeur", "incendiaire", "fumiste", "occulteur", "spectre",
	"sentinelle"]
const PORTEE := 728.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie := args[0] if not args.is_empty() else "user://eventails.json"
	var tout := {}
	for slug: String in COOKIES:
		var tex := load("res://assets/torche/cookie_%s.png" % slug) as Texture2D
		var env := IsoVolumes.enveloppe_de_l_image(tex.get_image())
		var couche := _sommets(IsoVolumes.eventail(env))
		var juge := _sommets(IsoVolumes.eventail(IsoVolumes.enveloppe_dilatee(env, IsoVolumes.decalage_du_juge() / PORTEE)))
		tout[slug] = {"couche": couche, "juge": juge, "part_couche": _aire(couche), "part_juge": _aire(juge)}
		# Le disque ajusté d'avant (V5, `_poser_juge`) : seize côtés d'apothème (portée + haut − h₀) / portée × 0,5.
		var apotheme := 0.5 * (PORTEE + IsoVolumes.decalage_du_juge() - IsoVolumes.MARGE_JUGE_PX) / PORTEE
		var disque := float(IsoVolumes.COTES_JUGE) * apotheme * apotheme * tan(PI / float(IsoVolumes.COTES_JUGE))
		print("%-12s couches %.3f du carré d'avant ; juge %.3f du carré, %.3f de son disque d'avant (%.3f)" % [slug,
			_aire(couche), _aire(juge), _aire(juge) / disque, disque])
	var f := FileAccess.open(sortie, FileAccess.WRITE)
	f.store_string(JSON.stringify(tout))
	f.close()
	print("écrit : %s" % ProjectSettings.globalize_path(sortie))
	quit(0)


func _sommets(m: ArrayMesh) -> Array:
	# Le contour de l'éventail, dans l'ordre des angles : les sommets de bord des triangles (lampe, A, B), A puis B.
	var out := []
	if m.get_surface_count() == 0:
		return out
	var tableaux := m.surface_get_arrays(0)
	var v: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX]
	var paires := []
	for t in range(0, idx.size(), 3):
		paires.append([Vector2(v[idx[t + 1]].x, v[idx[t + 1]].z), Vector2(v[idx[t + 2]].x, v[idx[t + 2]].z)])
	paires.sort_custom(func(a, b) -> bool: return fposmod((a[0] as Vector2).angle(), TAU) < fposmod((b[0] as Vector2).angle(), TAU))
	for p in paires:
		# Une plage vide entre deux triangles : le contour repasse par la lampe.
		if not out.is_empty() and not Vector2(out[-1][0], out[-1][1]).is_equal_approx(p[0]):
			out.append([0.0, 0.0])
		out.append([p[0].x, p[0].y])
		out.append([p[1].x, p[1].y])
	return out


func _aire(pts: Array) -> float:
	# L'aire du contour (lacet de Gauss) : l'éventail est étoilé autour de la lampe.
	var s := 0.0
	for i in pts.size():
		var a := Vector2(pts[i][0], pts[i][1])
		var b := Vector2(pts[(i + 1) % pts.size()][0], pts[(i + 1) % pts.size()][1])
		s += a.cross(b) * 0.5
	return absf(s)
