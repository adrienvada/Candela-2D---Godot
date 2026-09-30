extends SceneTree

## L'ALLÈGEMENT DE LA 0.8.0 — le rayon dans l'air (Q41) taillé à son cône (Adrien, 2026-09-30, 15:36 : « Oui allège d'abord
## avant de publier la 0.8 »), puis Q75 (Adrien, 2026-09-30 20:17 : « A+d »). Voir `IsoVolumes._tailler_faisceau_air`.
##
## Les couches du rayon étaient des carrés posés sur la texture de la lampe à son échelle ; ce sont désormais des éventails qui
## ne couvrent que là où le cookie peut dessiner, et leur juge aussi depuis Q75 (A : taillé, il ne tait plus la fumée hors du
## cône). Et le rayon s'arrête à la longueur de l'ancienne torche (Q75, D : la portée de la 0.7.1, classe par classe), en
## douceur, sans que la lumière au sol ni la portée ne bougent. Ce que cette garde tient (headless : sans pixel ; l'image se
## prouve sous Xvfb, `tools/loupe_faisceau_taille.gd`, `tools/loupe_faisceau_q75.gd` et leurs scripts d'analyse) :
## - la règle : couches taillées, juge taillé (A) et rayon court (D) par défaut ; `--faisceau-air-carre`,
##   `--faisceau-juge-disque` et `--faisceau-air-long` en build de débogage seulement ; le juge taillé n'est pas réécrit par
##   `_poser_juge` (sinon le maillage changerait deux fois par image) ;
## - **D, la longueur** : `WeaponData.portee_sans_ecran` rend, pour les dix classes du catalogue, la portée de la 0.7.1 relue
##   dans son code (`torch_scale × 256 × 0,75`, de 192 à 672 px), et `portee_torche` celle de la règle de l'écran (depuis
##   Q76, le bord le plus proche, 468 px, pour toutes) : le rayon va au plus court des deux ; le shader éteint la couche
##   par un `smoothstep` sur le dernier quart de SA longueur, avant de jeter le fragment (la ligne lue dans le source) ; ce
##   fondu ne saute jamais de plus de 5 % d'un pixel de monde au suivant, même sur la couche la plus courte de la classe la
##   plus courte (« sans coupure nette ») ;
## - **l'enveloppe CONTIENT le cookie, au texel près**, pour les dix cookies livrés : recalculée ici TEXEL PAR TEXEL, sans le
##   code du jeu (chaque texel non nul, élargi du demi-texel que lit le filtre bilinéaire), aucun secteur ne va plus loin que
##   l'enveloppe que le jeu pose ;
## - **l'éventail contient l'enveloppe** (chaque corde reste au-delà de son arc) et **l'éventail du juge contient l'enveloppe
##   dilatée** de la parallaxe (des points promenés à la distance de dilatation autour du bord de l'enveloppe, dans seize
##   directions, y tombent tous) ;
## - le gain est réel : l'éventail couvre une petite part du carré d'avant (sinon « taillé » ne taillerait rien), et en PLAGES
##   de quelques degrés, pas un triangle par degré (tous se touchent à la lampe : un bloc de pixels que plusieurs triangles
##   recouvrent passe dans le shader une fois par triangle — à un triangle par degré, l'éventail n'allégeait rien, mesuré) ;
## - **D, les éventails** : pour chaque cookie, à la longueur de sa classe sous la portée du jeu (468 px depuis Q76),
##   l'éventail des couches contient l'enveloppe arrêtée à cette longueur et s'arrête lui-même là (un point de l'axe 2 % plus
##   loin est dehors) — ou, pour les classes que la 0.7.1 portait plus loin que la portée (la Sentinelle, le Braconnier),
##   reste l'éventail entier —, et l'éventail du juge contient cette enveloppe dilatée de la parallaxe ;
## - EN JEU (écran scindé, 45° B ; le Terrassier à J1, coupé à 192 px, le Braconnier à J2, que la portée de Q76 ne laisse
##   plus couper) : les dix classes rendent la longueur de la 0.7.1 et portent à la portée du jeu ; les couches portent
##   l'éventail de leur longueur, tourné comme la lampe ; un point du cône en deçà de la longueur y tombe, un point derrière
##   la lampe n'y tombe pas (le sens de la rotation) ; chaque couche reçoit sa longueur (la même part de son rayon : le dôme
##   de la 0.7.1) et son fondu, et le juge — l'éventail dilaté, tourné, à l'échelle — ne juge qu'à ces longueurs ; basculés
##   sur place :
##   `faisceau_air_court` (le rayon long revient : longueur 1e9, éventail entier, juge à plein rayon), `faisceau_taille` (les
##   carrés d'avant, le rayon toujours court), `faisceau_juge_taille` (le disque d'avant, sans rotation) — puis chacun
##   rétabli.
##
## Lancer : godot --headless --path . --script res://tools/test_allegement_faisceau.gd

const COOKIES := ["pompe", "arbalete", "pistolet", "fusil", "allumeur", "incendiaire", "fumiste", "occulteur", "spectre",
	"sentinelle"]
## La part la plus grande du carré d'avant (côté 2 en unités locales, aire 4) que l'éventail d'un cookie peut couvrir. Mesurée
## le 2026-09-30 : du Terrassier (cône de 60°) à ~0,18, au Braconnier (10°) à ~0,05 ; la borne garde le gain.
const PART_MAX_DU_CARRE := 0.25
## Q75, D — LA PORTÉE DE LA 0.7.1, relue dans son code (`2501cb9`, `game_state.gd` et `weapon_data.gd`) : `portee_torche()`
## y valait `512 × 0,5 × torch_scale × facteur_portee`, sans plancher, `facteur_portee` à 0,75 (`GameSettings`) ; torch_scale
## 1,6 (le Parasite, la valeur par défaut), 1,8, 1,0, 3,5, 1,5, 1,4, 2,6, 1,3, 1,2, 1,4. En pixels de monde, par cookie.
const LONGUEURS_071 := {
	"pistolet": 307.2, "fusil": 345.6, "pompe": 192.0, "arbalete": 672.0, "fumiste": 288.0, "incendiaire": 268.8,
	"sentinelle": 499.2, "occulteur": 249.6, "allumeur": 230.4, "spectre": 268.8,
}
## La portée du jeu depuis Q76 : le bord le plus proche de la vue unique à ×1,5 (`test_portee_ecran`), pour les dix classes
## (728 px au coin, sous L1 et Q75). La garde en jeu vérifie que c'est bien celle que le jeu pose.
const PORTEE_DU_JEU := 468.0
## Le saut le plus grand que le fondu du bout du rayon peut faire d'un pixel de monde au suivant (part de l'opacité).
const SAUT_MAX_DU_FONDU := 0.05
## Le plus de triangles qu'un éventail de couche peut compter : des PLAGES (dix degrés au plus), pas un triangle par degré — tous
## se touchent à la lampe, et un bloc de pixels que plusieurs triangles recouvrent passe dans le shader une fois par triangle.
const TRIANGLES_MAX := 60

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
	print("=== L'ALLÈGEMENT DE LA 0.8.0 : LE RAYON TAILLÉ À SON CÔNE ===")
	await process_frame
	_regles()
	_enveloppes()
	await _en_jeu()
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _regles() -> void:
	print("\n--- La règle ---")
	var v := IsoVolumes.new()
	_check("couches taillées par défaut", v.faisceau_taille)
	_check("Q75, A : le juge du rayon taillé par défaut (en disque, il taisait la fumée hors du cône)", v.faisceau_juge_taille)
	_check("Q75, D : le rayon dans l'air à la longueur de l'ancienne torche par défaut", v.faisceau_air_court)
	v.free()
	var source := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("--faisceau-air-carre ne vaut qu'en build de débogage",
		source.contains("elif arg == DRAPEAU_FAISCEAU_CARRE and OS.is_debug_build():\n\t\t\tfaisceau_taille = false"))
	_check("--faisceau-juge-disque (le disque d'avant Q75) ne vaut qu'en build de débogage",
		source.contains("elif arg == DRAPEAU_FAISCEAU_JUGE_DISQUE and OS.is_debug_build():\n\t\t\tfaisceau_juge_taille = false"))
	_check("--faisceau-air-long (le rayon d'avant Q75) ne vaut qu'en build de débogage",
		source.contains("elif arg == DRAPEAU_FAISCEAU_AIR_LONG and OS.is_debug_build():\n\t\t\tfaisceau_air_court = false"))
	_check("`_poser_juge` ne pose ni disque ni échelle sur un juge taillé",
		source.contains("\tif not e.get(\"juge_taille\", false):\n\t\tjuge.mesh = _disque() if ajuste else _plan\n"
			+ "\t\tjuge.scale = Vector3(demi * 2.0, 1.0, demi * 2.0)\n"))
	var i_poser := source.find("\t_poser_couches(e, lampe.global_position, rayon")
	var i_tailler := source.find(
		"\t_tailler_faisceau_air(e, lampe.texture, rayon, lampe.global_rotation, plafond_du_faisceau(j, rayon))")
	_check("le rayon est taillé APRÈS `_poser_couches` (position, échelle et uniformes restent les siens), à sa longueur",
		i_poser > 0 and i_tailler > i_poser)
	_regles_de_longueur()


## Q75, D — la longueur, sans le jeu : la part de la portée, ses crans, l'enveloppe arrêtée, le shader et son fondu.
func _regles_de_longueur() -> void:
	print("\n--- Q75, D : la longueur de l'ancienne torche ---")
	_check("le plafond : la longueur de la 0.7.1 en part de la portée (192 sur 468 px), 1 quand elle l'atteint ou la dépasse "
		+ "(672 sur 468 : le rayon va jusqu'à la portée)",
		is_equal_approx(IsoVolumes.plafond_de_longueur(192.0, PORTEE_DU_JEU), 192.0 / PORTEE_DU_JEU)
		and IsoVolumes.plafond_de_longueur(672.0, PORTEE_DU_JEU) == 1.0
		and IsoVolumes.plafond_de_longueur(PORTEE_DU_JEU, PORTEE_DU_JEU) == 1.0)
	var crans_ok := true
	for p: float in [0.001, 192.0 / PORTEE_DU_JEU, 0.5, 672.0 / 727.6, 0.99999, 1.0]:
		var c := IsoVolumes.cran_de_longueur(p)
		crans_ok = crans_ok and float(c) / float(IsoVolumes.CRANS_DE_LONGUEUR) >= p \
			and float(c - 1) / float(IsoVolumes.CRANS_DE_LONGUEUR) < p and c <= IsoVolumes.CRANS_DE_LONGUEUR
	_check("le cran d'un plafond l'arrondit PAR EXCÈS au 1/%d (un éventail un peu plus long couvre toujours)"
		% IsoVolumes.CRANS_DE_LONGUEUR, crans_ok and IsoVolumes.cran_de_longueur(1.0) == IsoVolumes.CRANS_DE_LONGUEUR)
	var env := PackedFloat32Array([0.0, 0.1, 0.5, 0.95, 1.0])
	var cap := IsoVolumes.enveloppe_plafonnee(env, 0.3)
	_check("l'enveloppe arrêtée : chaque secteur au plus au plafond, intact en deçà",
		cap == PackedFloat32Array([0.0, 0.1, 0.3, 0.3, 0.3]) and IsoVolumes.enveloppe_plafonnee(env, 1.0) == env)
	var shader := FileAccess.get_file_as_string("res://volume_iso.gdshader")
	var ligne := "a *= 1.0 - smoothstep(longueur_air * (1.0 - fondu_air), longueur_air, length(px - nuage_centre));"
	var i_ligne := shader.find(ligne)
	var i_def := shader.rfind("#ifdef FAISCEAU_LUMINEUX", i_ligne)
	var i_grain := shader.find("a *= 0.7 + 0.3 * pate_bruit(")
	var i_clamp := shader.find("a = clamp(a, 0.0, 1.0);")
	_check("le shader éteint la couche du rayon (FAISCEAU_LUMINEUX) sur le dernier quart de sa longueur, AVANT de jeter le "
		+ "fragment (après le grain, avant `a <= 0,003`)", i_ligne > 0 and i_def > i_grain and i_ligne > i_def
		and i_ligne < i_clamp and shader.find("#endif", i_ligne) < i_clamp)
	var i_q75 := shader.find("#ifdef FAISCEAU_LUMINEUX\n// Q75")
	_check("sans longueur posée, aucune coupure : `longueur_air` vaut 1e9 par défaut, sous FAISCEAU_LUMINEUX seulement",
		i_q75 > 0 and shader.find("uniform float longueur_air = 1.0e9;") > i_q75
		and shader.find("#endif", i_q75) > shader.find("uniform float longueur_air = 1.0e9;"))
	# « Sans coupure nette » : le fondu du shader, recalculé pixel de monde par pixel de monde sur la couche la plus courte (la
	# plus haute, 0,78 de la longueur) de la classe la plus courte (le Terrassier, 192 px).
	var longueur := 192.0 * (1.0 - 0.22)
	var saut := 0.0
	var avant := 1.0
	for r in range(0, int(longueur) + 2):
		var f := 1.0 - smoothstep(longueur * (1.0 - IsoVolumes.FONDU_AIR), longueur, float(r))
		saut = maxf(saut, avant - f)
		avant = f
	_check("le fondu va de 1 à 0 sans jamais sauter de plus de %.0f %% d'un pixel de monde au suivant (%.1f %% au plus, "
		% [SAUT_MAX_DU_FONDU * 100.0, saut * 100.0] + "couche haute du Terrassier, %.0f px)" % longueur,
		saut <= SAUT_MAX_DU_FONDU and avant == 0.0 and IsoVolumes.FONDU_AIR > 0.0)


## Pour chaque cookie livré : l'enveloppe recalculée texel par texel, puis les deux éventails.
func _enveloppes() -> void:
	print("\n--- L'enveloppe et les éventails, pour les dix cookies livrés ---")
	var n := IsoVolumes.SECTEURS_FAISCEAU
	var pas := TAU / float(n)
	for slug: String in COOKIES:
		var tex := load("res://assets/torche/cookie_%s.png" % slug) as Texture2D
		var img := tex.get_image() if tex != null else null
		if img == null:
			_check("%s : le cookie se lit" % slug, false)
			continue
		if img.is_compressed():
			img.decompress()
		var t0 := Time.get_ticks_usec()
		var env := IsoVolumes.enveloppe_de_l_image(img)
		var duree_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var exacte := _enveloppe_exacte(img, n)
		var pire := -INF
		var secteur := -1
		for s in n:
			if exacte[s] - env[s] > pire:
				pire = exacte[s] - env[s]
				secteur = s
		_check("%s : l'enveloppe du jeu contient le cookie texel par texel (%d secteurs, pire marge %+.5f au secteur %d ; calculée en %.1f ms)"
			% [slug, n, -pire, secteur, duree_ms], pire <= 0.0)
		var eventail := IsoVolumes.eventail(env)
		var pts := _par_secteur(eventail, n)
		var corde_ok := true
		var detail := ""
		for s in n:
			if env[s] <= 0.0:
				continue
			# L'arc de l'enveloppe (unités locales ; le maillage en vaut la moitié), de bord à bord du secteur : dans l'éventail.
			for f: float in [0.0, 0.25, 0.5, 0.75, 0.999]:
				var q := Vector2.from_angle(pas * (float(s) + f)) * env[s] * (1.0 - 1e-6)
				if not _dans(pts, q * 0.5, n):
					corde_ok = false
					detail = "secteur %d : le point de l'arc à %.3f du secteur, rayon %.5f, est dehors" % [s, f, env[s]]
					break
			if not corde_ok:
				break
		_check("%s : l'arc de l'enveloppe est dans l'éventail, secteur par secteur (chaque corde au-delà)" % slug, corde_ok, detail)
		# Le carré d'avant est le plan de côté 1 : son aire vaut 1 dans le repère du maillage.
		var aire := _aire(eventail)
		_check("%s : l'éventail couvre %.3f du carré d'avant (≤ %.2f), en %d triangles (≤ %d : des plages, pas un par degré)"
			% [slug, aire.x, PART_MAX_DU_CARRE, int(aire.y), TRIANGLES_MAX],
			aire.x > 0.0 and aire.x <= PART_MAX_DU_CARRE and int(aire.y) <= TRIANGLES_MAX)
		# Le juge : l'enveloppe dilatée de la parallaxe, pour la portée du coin (728 px, L1), celle du bord le plus proche
		# (468 px, Q76) et une courte (192 px).
		for portee: float in [728.0, PORTEE_DU_JEU, 192.0]:
			var d := IsoVolumes.decalage_du_juge() / portee
			var dehors := _hors_du_juge(env, IsoVolumes.eventail(IsoVolumes.enveloppe_dilatee(env, d)), d, n)
			_check("%s : l'éventail du juge contient l'enveloppe dilatée de la parallaxe (portée %.0f px, %d point(s) dehors)"
				% [slug, portee, int(dehors[0])], int(dehors[0]) == 0, String(dehors[1]))
		_longueur_du_cookie(slug, env, eventail, img, n)


## Q75, D — les éventails d'un cookie à la longueur de SA classe dans la 0.7.1, sous la portée du jeu (Q76 : 468 px) : celui
## des couches contient l'enveloppe arrêtée à cette longueur et s'arrête lui-même là — ou, si la 0.7.1 portait plus loin que
## la portée, est l'éventail entier (rien à couper) ; celui du juge (bâti comme en jeu, à la portée entière arrondie par
## défaut) contient cette enveloppe dilatée de la parallaxe.
func _longueur_du_cookie(slug: String, env: PackedFloat32Array, entier: ArrayMesh, img: Image, n: int) -> void:
	var pas := TAU / float(n)
	var longueur := float(LONGUEURS_071.get(slug, 0.0))
	var plafond := IsoVolumes.plafond_de_longueur(longueur, PORTEE_DU_JEU)
	var cran := float(IsoVolumes.cran_de_longueur(plafond)) / float(IsoVolumes.CRANS_DE_LONGUEUR)
	var env_c := IsoVolumes.enveloppe_plafonnee(env, cran)
	var court := IsoVolumes.eventail(env_c)
	var pts := _par_secteur(court, n)
	var dedans := true
	var detail := ""
	for s in n:
		if env_c[s] <= 0.0:
			continue
		for f: float in [0.0, 0.25, 0.5, 0.75, 0.999]:
			var q := Vector2.from_angle(pas * (float(s) + f)) * env_c[s] * (1.0 - 1e-6)
			if not _dans(pts, q * 0.5, n):
				dedans = false
				detail = "secteur %d : le point de l'arc à %.3f du secteur, rayon %.5f, est dehors" % [s, f, env_c[s]]
				break
		if not dedans:
			break
	# Le bout de l'axe : 2 % au-delà de la longueur, dans le cône d'avant (le cookie y éclaire encore), hors de l'éventail court.
	var axe := _plus_loin_sur_l_axe(img)
	var bout := Vector2(cran * 1.02, 0.0)
	var ancien := _par_secteur(entier, n)
	var arrete := bout.x < axe and _dans(ancien, bout * 0.5, n) and not _dans(pts, bout * 0.5, n)
	var aires := [_aire(court).x, _aire(entier).x]
	if plafond >= 1.0:
		# La 0.7.1 portait plus loin que la portée du jeu : rien à couper, l'éventail entier.
		_check("%s : la 0.7.1 portait à %.1f px, au-delà de la portée (%.0f) — rien à couper, l'éventail est l'entier (aire %.4f)"
			% [slug, longueur, PORTEE_DU_JEU, float(aires[0])], dedans and cran >= 1.0
			and is_equal_approx(float(aires[0]), float(aires[1])), detail)
	else:
		_check("%s : à la longueur de la 0.7.1 (%.1f px, %.4f de la portée, cran %.4f), l'éventail des couches contient "
			% [slug, longueur, plafond, cran] + "l'enveloppe arrêtée et s'arrête là (l'axe à %.3f : dans l'éventail entier, "
			% bout.x + "hors du court) ; aire %.4f contre %.4f" % aires, dedans and arrete
			and float(aires[0]) < float(aires[1]), detail)
	var d := IsoVolumes.decalage_du_juge() / floorf(PORTEE_DU_JEU)
	var dehors := _hors_du_juge(env_c, IsoVolumes.eventail(IsoVolumes.enveloppe_dilatee(env_c, d)), d, n)
	_check("%s : à cette longueur, l'éventail du juge contient l'enveloppe arrêtée dilatée de la parallaxe (%d point(s) dehors)"
		% [slug, int(dehors[0])], int(dehors[0]) == 0, String(dehors[1]))


## [points dehors, premier exemple] : le bord de chaque secteur de `env` (l'arc et les deux rayons), promené de `d` dans seize
## directions, doit tomber dans l'éventail `juge`.
func _hors_du_juge(env: PackedFloat32Array, juge_m: ArrayMesh, d: float, n: int) -> Array:
	var pas := TAU / float(n)
	var juge := _par_secteur(juge_m, n)
	var hors := 0
	var exemple := ""
	for s in n:
		if env[s] <= 0.0:
			continue
		var bords: Array[Vector2] = []
		for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
			bords.append(Vector2.from_angle(pas * (float(s) + f)) * env[s])
		for f in [0.0, 0.25, 0.5, 0.75]:
			bords.append(Vector2.from_angle(pas * float(s)) * env[s] * f)
			bords.append(Vector2.from_angle(pas * float(s + 1)) * env[s] * f)
		for q: Vector2 in bords:
			for k in 16:
				var p := q + Vector2.from_angle(TAU * float(k) / 16.0) * d
				if not _dans(juge, p * 0.5, n):
					hors += 1
					if exemple.is_empty():
						exemple = "secteur %d, point (%.4f, %.4f)" % [s, p.x, p.y]
	return [hors, exemple]


## L'enveloppe EXACTE, texel par texel, sans le code du jeu : chaque texel d'alpha non nul, élargi d'un demi-texel (la portée du
## filtre bilinéaire), étend chaque secteur qu'il touche jusqu'à son coin le plus loin (plafonné à 1, où la couche se tait).
func _enveloppe_exacte(img: Image, n: int) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(n)
	env.fill(0.0)
	var a := img.duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	var w := a.get_width()
	var h := a.get_height()
	var data := a.get_data()
	var utile := a.get_used_rect()
	var pas := TAU / float(n)
	for y in range(utile.position.y, utile.end.y):
		for x in range(utile.position.x, utile.end.x):
			if data[(y * w + x) * 4 + 3] == 0:
				continue
			var x0 := (float(x) - 0.5) * 2.0 / float(w) - 1.0
			var x1 := (float(x) + 1.5) * 2.0 / float(w) - 1.0
			var y0 := (float(y) - 0.5) * 2.0 / float(h) - 1.0
			var y1 := (float(y) + 1.5) * 2.0 / float(h) - 1.0
			var loin := minf(1.0, sqrt(maxf(x0 * x0, x1 * x1) + maxf(y0 * y0, y1 * y1)))
			if x0 <= 0.0 and x1 >= 0.0 and y0 <= 0.0 and y1 >= 0.0:
				for s in n:
					env[s] = maxf(env[s], loin)
				continue
			# Les angles des quatre coins, ramenés au plus près de celui du premier : l'arc qu'ils couvrent.
			var ref := atan2(y0, x0)
			var lo := 0.0
			var hi := 0.0
			for c in [Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
				var dlt := angle_difference(ref, atan2(c.y, c.x))
				lo = minf(lo, dlt)
				hi = maxf(hi, dlt)
			var s0 := int(floor((ref + lo) / pas))
			var s1 := int(floor((ref + hi) / pas))
			for s in range(s0, s1 + 1):
				var k := posmod(s, n)
				env[k] = maxf(env[k], loin)
	return env


## Les triangles d'un éventail, relus DANS LE MAILLAGE et rangés par secteur de 1° : pour chaque secteur, les deux sommets de
## bord [A, B] (x, z du maillage) du triangle qui le couvre, ou [] si aucun. Chaque triangle est (lampe, A, B), A et B sur des
## bords de secteur, A avant B dans le sens des angles.
func _par_secteur(m: ArrayMesh, n: int) -> Array:
	var out := []
	out.resize(n)
	for s in n:
		out[s] = []
	if m.get_surface_count() == 0:
		return out
	var tableaux := m.surface_get_arrays(0)
	var v: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX]
	var pas := TAU / float(n)
	for t in range(0, idx.size(), 3):
		var a := Vector2(v[idx[t + 1]].x, v[idx[t + 1]].z)
		var b := Vector2(v[idx[t + 2]].x, v[idx[t + 2]].z)
		var s := posmod(int(round(fposmod(a.angle(), TAU) / pas)), n)
		var fin := posmod(int(round(fposmod(b.angle(), TAU) / pas)), n)
		while s != fin:
			out[s] = [a, b]
			s = (s + 1) % n
	return out


## Le point `p` (repère du maillage, x et z) est-il dans l'éventail ? Le triangle de son secteur, puis sa corde.
func _dans(tris: Array, p: Vector2, n: int) -> bool:
	if p.length() < 1e-9:
		return true
	var s := posmod(int(floor(fposmod(p.angle(), TAU) / (TAU / float(n)))), n)
	var t: Array = tris[s]
	if t.is_empty():
		return false
	var a: Vector2 = t[0]
	var b: Vector2 = t[1]
	return (b - a).cross(p - a) >= -1e-9


## L'aire de l'éventail, en unités du maillage (le carré d'avant y vaut 1), et le nombre de ses triangles.
func _aire(m: ArrayMesh) -> Vector2:
	if m.get_surface_count() == 0:
		return Vector2.ZERO
	var tableaux := m.surface_get_arrays(0)
	var v: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX]
	var s := 0.0
	for t in range(0, idx.size(), 3):
		var a := Vector2(v[idx[t + 1]].x, v[idx[t + 1]].z)
		var b := Vector2(v[idx[t + 2]].x, v[idx[t + 2]].z)
		s += absf(a.cross(b)) * 0.5
	return Vector2(s, idx.size() / 3)


func _en_jeu() -> void:
	print("\n--- En jeu : écran scindé à 45° B, le Terrassier à J1 (coupé), le Braconnier à J2 (jusqu'à la portée) ---")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var reseau := root.get_node("NetworkManager")
	main.ui._intended_mode = int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
	main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(main))
	var pres := root.get_node_or_null("Presentation3D")
	var miroirs: Object = pres.get("_miroirs") if pres != null else null
	var volumes: Node = miroirs.get("volumes") if miroirs != null else null
	if volumes == null:
		_check("les volumes iso existent", false)
		return
	# Q75, D — les dix classes du catalogue : la longueur de la 0.7.1 ; et la portée du jeu (Q76 : plancher et plafond au
	# bord le plus proche) pour toutes.
	var plancher := WeaponData.portee_plancher
	var classes_ok := true
	var detail := ""
	var vues := 0
	for c: ClassData in main.classes():
		var attendue := float(LONGUEURS_071.get(String(c.slug()), -1.0))
		vues += 1 if attendue > 0.0 else 0
		if absf(c.portee_sans_ecran() - attendue) > 0.01 or not is_equal_approx(c.portee_torche(), plancher):
			classes_ok = false
			detail = "%s : sans la règle %.2f (0.7.1 : %.2f), portée %.2f (bord %.2f)" % [c.slug(),
				c.portee_sans_ecran(), attendue, c.portee_torche(), plancher]
	_check("les dix classes rendent la longueur de la 0.7.1 (de 192 à 672 px), et portent toutes au bord le plus proche "
		+ "(%.1f px, plancher et plafond : Q76)" % plancher, classes_ok and vues == 10
		and absf(plancher - PORTEE_DU_JEU) < 0.5 and is_equal_approx(WeaponData.portee_plafond, plancher), detail)
	for c: ClassData in main.classes():
		if String(c.slug()) == "pompe":
			main.p1.equip_weapon(c)
		elif String(c.slug()) == "arbalete":
			main.p2.equip_weapon(c)
	for p in [main.p1, main.p2]:
		(p as Node).set_physics_process(false)
	var lampes: Array = [main.p1.get_node("Flashlight"), main.p2.get_node("Flashlight")]
	# Lampes éteintes : l'enveloppe et les éventails se préparent déjà (au décompte), jamais à l'image où la lampe s'allume.
	for l: PointLight2D in lampes:
		l.enabled = false
	# Deux images : les classes viennent de changer (`equip_weapon`), et le suivi des volumes passe après ce code-ci.
	await process_frame
	await process_frame
	var prets := true
	var manque := ""
	for pid in 2:
		var l: PointLight2D = lampes[pid]
		var j: Node2D = [main.p1, main.p2][pid]
		var portee := 0.5 * float(l.texture.get_width()) * l.texture_scale
		var cran := IsoVolumes.cran_de_longueur(volumes.call("plafond_du_faisceau", j, portee))
		var cle := Vector2i(cran, maxi(1, int(floor(portee))))
		var couches := (IsoVolumes._eventails.get(l.texture, {}) as Dictionary)
		var juges := (IsoVolumes._eventails_juge.get(l.texture, {}) as Dictionary)
		if not (IsoVolumes._enveloppes.has(l.texture) and couches.has(cran) and juges.has(cle)):
			prets = false
			manque += "J%d : cran %d, clé %s ; couches %s, juge %s. " % [pid + 1, cran, str(cle), str(couches.keys()),
				str(juges.keys())]
	_check("lampes éteintes, l'enveloppe et les deux éventails de chaque cookie, à sa longueur, sont déjà prêts", prets, manque)
	var centre: Vector2 = main._carte_px.get_center()
	main.p1.global_position = centre
	main.p2.global_position = centre + Vector2(-140, 70)
	for pid in 2:
		var j: Node2D = [main.p1, main.p2][pid]
		var lampe: PointLight2D = lampes[pid]
		var arme := j.get("current_weapon") as WeaponData
		var qui := "J%d (%s)" % [pid + 1, arme.slug()]
		var portee := 0.5 * float(lampe.texture.get_width()) * lampe.texture_scale
		# La longueur ATTENDUE se tire de la 0.7.1 (la table relue dans son code), jamais de la fonction du jeu : chaque
		# vérification qui suit la compare à ce que le jeu pose. Au plus court de la 0.7.1 et de la portée (Q76).
		var plafond := minf(1.0, float(LONGUEURS_071[arme.slug()]) / portee)
		var du_jeu: float = volumes.call("plafond_du_faisceau", j, portee)
		_check("%s : le rayon s'arrête à %.4f de la portée (%.1f px sur %.1f), au plus court de la 0.7.1 (%.1f) et de la portée"
			% [qui, du_jeu, portee * du_jeu, portee, float(LONGUEURS_071[arme.slug()])], is_equal_approx(du_jeu, plafond))
		for angle in [0.9, -2.3]:
			j.rotation = angle
			j.set("flashlight_on", true)
			lampe.enabled = true
			lampe.energy = 2.5
			await process_frame
			await process_frame
			var e: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
			if e.is_empty():
				_check("%s (visée %.1f) : le rayon est posé" % [qui, angle], false)
				continue
			_verifier_taille(e, lampe, "%s, visée %.1f rad" % [qui, angle], volumes, true, plafond)
		# Sur place, D : le rayon long d'avant Q75 (aucune coupure, l'éventail entier), puis le court.
		volumes.set("faisceau_air_court", false)
		await process_frame
		var e_long: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e_long.is_empty():
			_verifier_taille(e_long, lampe, "%s, `faisceau_air_court` coupé sur place" % qui, volumes, true, 1.0)
		volumes.set("faisceau_air_court", true)
		await process_frame
		var e_court: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e_court.is_empty():
			_verifier_taille(e_court, lampe, "%s, rayon court rétabli" % qui, volumes, true, plafond)
		# Sur place : les carrés d'avant (le rayon reste court : D ne dépend pas de l'allègement), puis les éventails.
		volumes.set("faisceau_taille", false)
		await process_frame
		var e2: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		var carres := not e2.is_empty()
		if carres:
			for mi: MeshInstance3D in e2["noeuds"]:
				var mat := mi.material_override as ShaderMaterial
				var longueur_attendue := float(mat.get_shader_parameter("nuage_rayon")) * plafond if plafond < 1.0 \
					else IsoVolumes.LONGUEUR_AIR_SANS_COUPURE
				carres = carres and mi.mesh is PlaneMesh and mi.rotation == Vector3.ZERO and is_equal_approx(
					float(mat.get_shader_parameter("longueur_air")), longueur_attendue)
			var juge: MeshInstance3D = e2.get("juge")
			# Le juge d'avant : le disque ajusté (forme 5, le défaut depuis la 0.7.0), sans rotation.
			carres = carres and juge != null and juge.mesh == volumes.call("_disque") and juge.rotation == Vector3.ZERO
		_check("%s : `faisceau_taille` coupé sur place, les carrés d'avant reviennent (plan, disque, sans rotation), le rayon "
			% qui + "toujours à sa longueur", carres)
		volumes.set("faisceau_taille", true)
		await process_frame
		var e3: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e3.is_empty():
			_verifier_taille(e3, lampe, "%s, éventails rétablis sur place" % qui, volumes, true, plafond)
		# Sur place, A : le juge en disque d'avant Q75, puis l'éventail rendu.
		volumes.set("faisceau_juge_taille", false)
		await process_frame
		var e4: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e4.is_empty():
			_verifier_taille(e4, lampe, "%s, `faisceau_juge_taille` coupé sur place" % qui, volumes, false, plafond)
		volumes.set("faisceau_juge_taille", true)
		await process_frame
		var e5: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e5.is_empty():
			_verifier_taille(e5, lampe, "%s, juge taillé rétabli" % qui, volumes, true, plafond)
		j.set("flashlight_on", false)
		lampe.enabled = false
		await process_frame
		await process_frame
	main.queue_free()
	await process_frame


## Les couches portent l'éventail du cookie à sa longueur, tourné comme la lampe ; un point du cône en deçà de la longueur
## (repris du cookie lui-même) tombe dans le maillage de chaque couche, un point derrière la lampe n'y tombe pas ; chaque couche
## s'éteint à `plafond` de son rayon (Q75, D ; 1 : aucune coupure) ; le juge ne juge qu'à ces longueurs, et porte l'éventail
## dilaté (`juge_taille`, Q75, A) ou le disque d'avant.
func _verifier_taille(e: Dictionary, lampe: PointLight2D, qui: String, volumes: Node, juge_taille: bool,
		plafond: float) -> void:
	var n := IsoVolumes.SECTEURS_FAISCEAU
	var cran := IsoVolumes.cran_de_longueur(plafond)
	var eventail: ArrayMesh = (IsoVolumes._eventails.get(lampe.texture, {}) as Dictionary).get(cran)
	var noeuds: Array = e["noeuds"]
	var portee := 0.5 * float(lampe.texture.get_width()) * lampe.texture_scale
	var ok := eventail != null and noeuds.size() == int(IsoVolumes.VOLUME_FAISCEAU_AIR["couches"])
	var devant := true
	var derriere := true
	var pts := _par_secteur(eventail, n) if eventail != null else []
	var img := lampe.texture.get_image()
	# Le point le plus loin du cookie sur son axe (en deçà de la longueur), et le même derrière la lampe, en unités locales.
	var axe := minf(_plus_loin_sur_l_axe(img), plafond * 0.999)
	var longueurs := true
	var detail := ""
	var rayons := Vector4.ZERO
	for i in noeuds.size():
		var mi: MeshInstance3D = noeuds[i]
		ok = ok and mi.mesh == eventail and is_equal_approx(mi.rotation.y, -lampe.global_rotation) \
			and is_zero_approx(mi.rotation.x) and is_zero_approx(mi.rotation.z)
		var mat := mi.material_override as ShaderMaterial
		var r := float(mat.get_shader_parameter("nuage_rayon"))
		var angle := float(mat.get_shader_parameter("nuage_angle"))
		var centre: Vector2 = mat.get_shader_parameter("nuage_centre")
		if i < 4:
			rayons[i] = r * plafond
		# Le monde que le shader associe à ce point du cookie : d = R(angle)·local, px = centre + r·d.
		for local: Vector2 in [Vector2(axe, 0.0), Vector2(axe * 0.5, 0.0)]:
			var monde := centre + local.rotated(angle) * r
			var dans_le_maillage: Vector3 = mi.global_transform.affine_inverse() * Vector3(monde.x, mi.global_position.y, monde.y)
			devant = devant and _dans(pts, Vector2(dans_le_maillage.x, dans_le_maillage.z), n)
		var dos := centre + Vector2(-0.5, 0.0).rotated(angle) * r
		var dos_m: Vector3 = mi.global_transform.affine_inverse() * Vector3(dos.x, mi.global_position.y, dos.y)
		derriere = derriere and not _dans(pts, Vector2(dos_m.x, dos_m.z), n)
		# Q75, D : la longueur de la couche (la même part de son rayon : le dôme) et son fondu.
		var longueur := float(mat.get_shader_parameter("longueur_air"))
		var attendue := r * plafond if plafond < 1.0 else IsoVolumes.LONGUEUR_AIR_SANS_COUPURE
		if not (is_equal_approx(longueur, attendue)
				and is_equal_approx(float(mat.get_shader_parameter("fondu_air")), IsoVolumes.FONDU_AIR)):
			longueurs = false
			detail = "couche %d : longueur %.3f, attendue %.3f ; fondu %s" % [i, longueur, attendue,
				str(mat.get_shader_parameter("fondu_air"))]
	_check("%s : les couches portent l'éventail du cookie à sa longueur (cran %d), tourné comme la lampe" % [qui, cran], ok)
	_check("%s : un point du cône (l'axe, à %.2f puis à mi-chemin) tombe dans chaque couche" % [qui, axe], devant)
	_check("%s : un point derrière la lampe n'y tombe pas (le sens de la rotation)" % qui, derriere)
	_check("%s : chaque couche s'éteint à %s" % [qui, ("%.4f de son rayon (%.1f px pour la plus basse), fondu %.2f"
		% [plafond, portee * plafond, IsoVolumes.FONDU_AIR]) if plafond < 1.0 else "l'infini (aucune coupure)"],
		longueurs, detail)
	var juge: MeshInstance3D = e.get("juge")
	var jr: Vector4 = (juge.material_override as ShaderMaterial).get_shader_parameter("juge_rayons") if juge != null \
		else Vector4.ZERO
	var jr_ok := juge != null
	for i in mini(noeuds.size(), 4):
		jr_ok = jr_ok and is_equal_approx(jr[i], rayons[i])
	_check("%s : le juge ne juge qu'où une couche peut dessiner (`juge_rayons` %s)" % [qui, str(jr)], jr_ok,
		"attendu %s" % str(rayons))
	if not juge_taille:
		# Le juge d'avant Q75 : le disque ajusté (forme 5, le défaut depuis la 0.7.0), sans rotation.
		_check("%s : le juge rend son disque, visible et sans rotation" % qui,
			juge != null and juge.visible and juge.mesh == volumes.call("_disque") and juge.rotation == Vector3.ZERO)
		return
	var attendu: ArrayMesh = (IsoVolumes._eventails_juge.get(lampe.texture, {}) as Dictionary).get(
		Vector2i(cran, maxi(1, int(floor(portee)))))
	_check("%s : le juge porte l'éventail dilaté à la portée (%.0f px) et à la longueur, visible, tourné et à l'échelle"
		% [qui, portee], juge != null and juge.visible and attendu != null and juge.mesh == attendu
		and is_equal_approx(juge.rotation.y, -lampe.global_rotation)
		and juge.scale.is_equal_approx(Vector3(portee * 2.0, 1.0, portee * 2.0)))


## Le texel non nul le plus loin sur l'axe du cookie (+x depuis le centre), en unités locales.
func _plus_loin_sur_l_axe(img: Image) -> float:
	var a := img.duplicate() as Image
	if a.is_compressed():
		a.decompress()
	var y := a.get_height() / 2
	for x in range(a.get_width() - 1, a.get_width() / 2, -1):
		if a.get_pixel(x, y).a > 0.0:
			return (float(x) + 0.5) * 2.0 / float(a.get_width()) - 1.0
	return 0.5


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	return true
