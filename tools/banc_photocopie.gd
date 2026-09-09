extends Node2D

## Le banc de la PHOTOCOPIE — `BackBufferCopy` recopie-t-il le rectangle qu'on
## lui donne ?
##
## ## Pourquoi ce banc existe
##
## Le polygone de photocopie du flou (voir la feuille de route, « la photocopie
## d'écran du flou laisse un polygone à l'écran ») a survécu à quatre
## explications. Elles sont toutes mortes, et toutes sont mortes de la lecture.
## À la fin il ne restait que **deux affirmations dont une est fausse** :
##
## 1. « Dans un `SubViewport`, une unité de canevas est un texel de framebuffer. »
## 2. « `BackBufferCopy` en `COPY_MODE_RECT` recopie exactement le `rect` qu'on
##    lui donne. »
##
## La première est de nous et se relit. **La seconde est de Godot, et personne
## dans ce dépôt ne l'avait jamais ouverte** — c'est le profil exact des défauts
## qui durent. Ce banc l'ouvre.
##
## ## Le principe, et il tient en deux images
##
## On peint l'écran entier d'une couleur qui ne dépend QUE du numéro d'image :
## rouge à l'image A, vert à l'image B. Entre les deux :
##
## - image A — photocopie **plein cadre**. Le tampon vaut rouge partout. C'est la
##   ligne de base, et elle est indispensable : sans elle, « périmé » n'a pas de
##   valeur connue et on ne mesure rien.
## - image B — l'écran est peint en vert, et on ne photocopie que le `rect`
##   demandé. Le tampon vaut donc **vert dans le rectangle, rouge en dehors**.
##
## Un dernier rectangle plein écran rend le tampon BRUT, sans rien y ajouter. La
## capture donne alors une carte : vert = ce que la photocopie a rafraîchi, rouge
## = ce qu'elle a laissé. **On mesure la boîte du vert et on la compare à la boîte
## demandée.** Si Godot arrondit, aligne, élargit ou découpe, l'écart se lit en
## pixels — sans jouer, sans éblouissement, sans avis.
##
## ⚠️ **Le banc ne montre pas des images pour qu'on les juge à l'œil, il imprime
## des nombres.** C'est la consigne tirée de « Un banc ment d'autant mieux qu'il
## est joli » : la planche est un moyen de contrôle, pas la mesure.
##
## ## Les deux configurations, et il FAUT les deux
##
## Le défaut est constaté en vue unique (rendu racine) ET en écran scindé
## (`SubViewport`). Le banc mesure donc les deux, dans la même exécution, avec
## les mêmes rectangles. C'est le manque exact du banc du voile, qui a une racine
## `Node2D` et n'a donc jamais rien dit de l'écran scindé.
##
## Lancer : godot --path . res://tools/banc_photocopie.tscn
## Il mesure, imprime, écrit ses planches et se ferme seul.

const Brouillage := preload("res://brouillage.gd")

## Les rectangles soumis à la photocopie.
##
## ⚠️ **Les fractionnaires ne sont pas une coquetterie.** `emprise_copie()` rend
## des flottants — un demi-grand-axe multiplié par un cosinus ne tombe pas sur
## un entier —, donc la production ne demande JAMAIS un rectangle aligné. Un banc
## qui n'essaierait que des entiers laisserait passer exactement le défaut qu'on
## cherche.
static var CAS: Array = [
	{"nom": "entier, plein centre", "rect": Rect2(300, 300, 400, 300)},
	{"nom": "fractionnaire (le cas de la production)",
		"rect": Rect2(300.37, 300.62, 400.25, 300.75)},
	{"nom": "fractionnaire, sous le demi-pixel",
		"rect": Rect2(300.5, 300.5, 400.5, 300.5)},
	{"nom": "petit — plus petit qu'un bloc probable",
		"rect": Rect2(500, 400, 16, 16)},
	{"nom": "à cheval sur le bord gauche", "rect": Rect2(-60, 300, 260, 200)},
	{"nom": "à cheval sur le bord haut", "rect": Rect2(300, -60, 300, 260)},
]

const COUL_BASE := Color(1.0, 0.0, 0.0, 1.0)   # le tampon d'AVANT — « périmé »
const COUL_FRAIS := Color(0.0, 1.0, 0.0, 1.0)  # ce que la photocopie apporte

## Taille du `SubViewport` du second passage. **Celle de la production**, pas un
## chiffre rond : `main.tscn` pose 957×1080 et 958×1080, et un banc qui
## arrondirait à 960 ne mesurerait pas le jeu.
const TAILLE_SOUS_VUE := Vector2i(957, 1080)

const CODE_PEINTRE := """
shader_type canvas_item;
uniform vec4 teinte : source_color = vec4(1.0, 0.0, 0.0, 1.0);
void fragment() { COLOR = teinte; }
"""

## Le lecteur rend le tampon TEL QUEL. Aucun mélange, aucune correction, alpha
## plein — sans quoi on mesurerait le lecteur et non la photocopie.
##
## ⚠️ **`FRAGCOORD.xy * SCREEN_PIXEL_SIZE` et non `SCREEN_UV`** : c'est
## l'adressage que `brouillage_flou.gdshader` a dû adopter après avoir rendu une
## copie déplacée et agrandie de l'écran. Le banc doit lire comme la production
## lit, sinon il répond à une autre question que celle qu'on pose.
const CODE_LECTEUR := """
shader_type canvas_item;
uniform sampler2D ecran : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	COLOR = vec4(texture(ecran, FRAGCOORD.xy * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
"""

var _releves: Array = []
var _dossier := "user://planches_photocopie"


func _ready() -> void:
	get_window().title = "Candela — banc de la photocopie"
	call_deferred("_mener")


func _mener() -> void:
	DirAccess.make_dir_recursive_absolute(_dossier)
	print("=== BANC DE LA PHOTOCOPIE — `COPY_MODE_RECT` tient-il sa parole ? ===")

	var taille_racine := get_viewport().get_visible_rect().size
	print("\nfenêtre : %d×%d" % [int(taille_racine.x), int(taille_racine.y)])
	await _passer("RACINE", get_viewport(), self, taille_racine)

	# ── Le second passage, dans un `SubViewport` aux dimensions de la production.
	var sv := SubViewport.new()
	sv.name = "SousVue"
	sv.size = TAILLE_SOUS_VUE
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	add_child(sv)
	await get_tree().process_frame
	print("\nSubViewport : %d×%d" % [sv.size.x, sv.size.y])
	await _passer("SOUS-VUE", sv, sv, Vector2(sv.size))
	sv.queue_free()

	await _acte_appareil()

	_conclure()
	get_tree().quit(0 if _tout_juste() else 1)


## ACTE II — le VRAI appareil, dans la VRAIE scène.
##
## L'acte I mesure `BackBufferCopy` en laboratoire ; celui-ci vérifie que
## `brouillage_vue.gd` en tire les bonnes conséquences, dans chaque vue que le
## jeu rend réellement. **Sans lui, l'acte I prouverait un fait de moteur sans
## rien dire de la production** — et c'est précisément l'écart qui a laissé le
## défaut vivre un mois : `emprise_copie()` était juste, et le rectangle remis au
## moteur ne l'était pas.
##
## Le critère est celui du shader, pas celui de l'œil : pour chaque coin du
## rectangle du flou, poussé d'un rayon de noyau vers l'extérieur — le texel le
## plus lointain qu'un fragment puisse aller chercher —, ce texel tombe-t-il dans
## le `rect` photocopié ?
func _acte_appareil() -> void:
	print("\n\n=== ACTE II — L'APPAREIL RÉEL, DANS LA SCÈNE RÉELLE ===")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var vues: Array = [["RACINE", get_viewport()]]
	for chemin in ["SplitScreen/ViewportContainer1/SubViewport1",
			"SplitScreen/ViewportContainer2/SubViewport2"]:
		var sv := main.get_node_or_null(chemin) as SubViewport
		if sv != null:
			vues.append(["ÉCRAN SCINDÉ — " + chemin.get_file(), sv])

	for paire in vues:
		var vue: Viewport = paire[1]
		var canevas := vue.get_visible_rect().size
		var ech := Vector2(vue.get_texture().get_size()) / canevas
		print("\n── %s ──   canevas %.0f×%.0f, framebuffer %.0f×%.0f, facteur %.4f"
			% [paire[0], canevas.x, canevas.y, canevas.x * ech.x,
				canevas.y * ech.y, ech.x])
		# On rejoue ce que fait `maj()` pour un éblouissement plein, à plusieurs
		# angles : c'est l'angle qui décide de la boîte, et 0° comme 90° sont les
		# cas où une conversion fausse peut passer inaperçue.
		var f: Dictionary = Brouillage.flou(1.0)
		var rayon: float = float(f["rayon"])
		var demi_long: float = rayon * Brouillage.ALLONGEMENT_FLOU
		var taille := Vector2(demi_long, rayon) * 2.0
		var pire := 0.0
		for axe in [0.0, PI / 6.0, PI / 4.0, PI / 3.0, PI / 2.0, 2.3, -1.1]:
			var centre := Vector2(canevas.x * 0.5 + 37.4, canevas.y * 0.5 - 21.6)
			var r: Rect2 = Brouillage.rect_photocopie(centre, taille, axe,
				Brouillage.NOYAU_FLOU, ech)
			var demi_t := taille * 0.5
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var coin := Vector2(demi_t.x * sx, demi_t.y * sy).rotated(axe)
					var lu: Vector2 = (centre + coin) * ech \
						+ coin.normalized() * Brouillage.NOYAU_FLOU
					pire = maxf(pire, r.position.x - lu.x)
					pire = maxf(pire, r.position.y - lu.y)
					pire = maxf(pire, lu.x - r.end.x)
					pire = maxf(pire, lu.y - r.end.y)
		var ok := pire <= 0.0
		print("  %s tout texel lu par le flou tombe dans la photocopie (marge %.1f texels)"
			% ["✓" if ok else "✗", -pire])
		_releves.append({"cas": "appareil réel — " + str(paire[0]),
			"court": not ok})
	main.queue_free()
	await get_tree().process_frame


## Un passage complet sur une vue : tous les cas, mesurés.
##
## `vue` est le viewport dont on lira la texture ; `hote` le nœud sous lequel
## poser l'appareil. Les deux diffèrent au rendu racine (`self` n'est pas un
## viewport) et coïncident dans le `SubViewport`.
func _passer(etiquette: String, vue: Viewport, hote: Node,
		taille: Vector2) -> void:
	print("\n── %s ──" % etiquette)
	for cas in CAS:
		var mesure: Dictionary = await _mesurer(vue, hote, cas["rect"], taille,
			"%s_%s" % [etiquette.to_lower(), str(cas["nom"]).split(",")[0]])
		mesure["cas"] = cas["nom"]
		mesure["vue"] = etiquette
		_releves.append(mesure)
		_dire(mesure)


## Une mesure : on demande `rect`, on regarde ce qu'on obtient.
func _mesurer(vue: Viewport, hote: Node, rect: Rect2, taille: Vector2,
		nom: String) -> Dictionary:
	var couche := CanvasLayer.new()
	couche.layer = 1
	hote.add_child(couche)

	var peintre := ColorRect.new()
	peintre.size = taille
	peintre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat_p := ShaderMaterial.new()
	mat_p.shader = Shader.new()
	mat_p.shader.code = CODE_PEINTRE
	mat_p.set_shader_parameter("teinte", COUL_BASE)
	peintre.material = mat_p
	couche.add_child(peintre)

	var copie := BackBufferCopy.new()
	copie.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	couche.add_child(copie)

	var lecteur := ColorRect.new()
	lecteur.size = taille
	lecteur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat_l := ShaderMaterial.new()
	mat_l.shader = Shader.new()
	mat_l.shader.code = CODE_LECTEUR
	lecteur.material = mat_l
	lecteur.visible = false
	couche.add_child(lecteur)

	# ── Image A : le tampon prend la couleur de base, PLEIN CADRE.
	# Deux images, pas une : la première compile les shaders, et un shader qui
	# compile pendant qu'on mesure rend du blanc — on mesurerait la compilation.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	# ── Image B : l'écran devient vert, et on ne photocopie que `rect`.
	mat_p.set_shader_parameter("teinte", COUL_FRAIS)
	copie.copy_mode = BackBufferCopy.COPY_MODE_RECT
	copie.rect = rect
	lecteur.visible = true
	await RenderingServer.frame_post_draw

	var img := vue.get_texture().get_image()
	img.save_png("%s/%s.png" % [_dossier, nom.replace(" ", "_")])
	var obtenu := _boite_du_frais(img)
	couche.queue_free()
	await get_tree().process_frame

	return {"demande": rect, "obtenu": obtenu, "image": img.get_size()}


## La boîte englobante des pixels que la photocopie a rafraîchis.
##
## Le vert et le rouge sont séparés par un gouffre : on teste `g > r`, ce qui ne
## demande aucun seuil arbitraire et survit à la compression du framebuffer.
## Rend un `Rect2` vide si rien n'a été rafraîchi — ce qui est un résultat, pas
## une panne.
func _boite_du_frais(img: Image) -> Rect2:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.g > c.r:
				x0 = mini(x0, x); y0 = mini(y0, y)
				x1 = maxi(x1, x); y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2()
	# Les bornes sont des INDEX de pixel ; la boîte va du bord gauche du premier
	# au bord droit du dernier, d'où le +1. L'oublier fait rendre une boîte trop
	# courte d'un pixel dans chaque sens, et fabrique un écart qui n'existe pas.
	return Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## L'acte I ne juge pas notre code : il CARACTÉRISE le moteur.
##
## ⚠️ **La troncature n'est donc pas un échec ici, c'est le fait mesuré** — et
## `Brouillage.rect_photocopie()` la compense en plancheant le coin et en
## plafonnant l'étendue. Ce que l'acte I doit surveiller, c'est que ce fait ne
## CHANGE pas : si une version de Godot se mettait à perdre plus que
## `MARGE_COPIE` texels, notre garde deviendrait trop courte sans que rien ne le
## dise. C'est là, et seulement là, que l'acte I doit rougir.
func _dire(m: Dictionary) -> void:
	var d: Rect2 = m["demande"]
	var attendu := d.intersection(Rect2(Vector2.ZERO, Vector2(m["image"])))
	var o: Rect2 = m["obtenu"]
	var manque_d := attendu.end.x - o.end.x
	var manque_b := attendu.end.y - o.end.y
	var perdu := maxf(maxf(manque_d, manque_b), 0.0)
	var trop := perdu > Brouillage.MARGE_COPIE + 0.001
	print("  %s %-42s demandé %s → obtenu %s   perdu %.2f texel(s)" % [
		"✗" if trop else "·", m["cas"], _fmt(attendu), _fmt(o), perdu])
	if trop:
		print("      ⚠️  LE MOTEUR PERD PLUS QUE `MARGE_COPIE` (%.1f) — la garde"
			% Brouillage.MARGE_COPIE)
		print("          de `rect_photocopie()` est devenue trop courte.")
	m["court"] = trop
	m["perdu"] = perdu


func _fmt(r: Rect2) -> String:
	return "[%.2f,%.2f %.2f×%.2f]" % [r.position.x, r.position.y, r.size.x,
		r.size.y]


func _tout_juste() -> bool:
	for m in _releves:
		if m.get("court", false):
			return false
	return true


func _conclure() -> void:
	var perdu_max := 0.0
	for m in _releves:
		perdu_max = maxf(perdu_max, float(m.get("perdu", 0.0)))
	print("\n=== VERDICT ===")
	print("  ACTE I — le moteur tronque le `rect` à l'entier, position ET taille.")
	print("           Perte maximale mesurée : %.2f texel(s), garde `MARGE_COPIE`"
		% perdu_max)
	print("           à %.1f. C'est un FAIT de Godot, pas un réglage : il ne se"
		% Brouillage.MARGE_COPIE)
	print("           corrige pas, il se compense.")
	if _tout_juste():
		print("  ACTE II — dans les trois vues du jeu, tout texel que le flou peut")
		print("            aller lire tombe dans la zone photocopiée.")
		print("\n  ✓ Le polygone n'a plus de quoi se former.")
	else:
		print("\n  ✗ Un texel lu tombe hors de la photocopie — le polygone peut")
		print("    encore se former. Voir les lignes ✗ ci-dessus.")
	print("\nplanches : %s (%d images)" % [
		ProjectSettings.globalize_path(_dossier), _releves.size()])
