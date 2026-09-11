## MurLed — le bandeau lumineux qui respire le long des murs. PROTOTYPE.
##
## Demande d'Adrien (2026-09-10) : « une légère bande de lumière faible à rythme
## lent, comme une respiration, qui révèle ce qui est proche des murs — comme si
## les murs avaient un bandeau LED tout le long d'eux ». Ce n'est PAS un décor :
## la bande éclaire le sol ET les joueurs, donc elle rend périodiquement visibles
## les planques le long des murs. Elle reste derrière un drapeau tant qu'Adrien
## ne l'a pas jugée en jeu.
##
## Activation : `--led-murs` au lancement (tout build), ou F7 en cours de partie
## (build debug seulement). `--led-murs-fige[=f]` la tient à la fraction `f` du
## sommet (1 par défaut), sans respirer — pour juger l'aspect ou photographier.
## Sans drapeau, rien n'est créé hors debug ; en debug la lumière existe, pour
## que F7 puisse l'allumer, mais reste `enabled = false`.
##
## ⚠️ **L'intensité passe par la COULEUR, jamais par l'énergie.** C'est le défaut
## qu'Adrien a vu au premier essai : « ça fait apparaître les murs comme des
## traits blancs d'un coup, puis ils s'éteignent ». Le liseré
## (`shimmer_murs.gdshader`) et l'adversaire (`player_enemy_light.gdshader`) ont
## leur propre `light()`, qui lisait `LIGHT_COLOR` sans jamais le multiplier par
## `LIGHT_ENERGY`. Mesuré au banc isolé : énergie 0,05, 0,20 ou 0,50, le liseré
## restait à ~168/255 et l'adversaire à 60 — seul le sol, rendu par l'éclairage
## par défaut, suivait. Dosée par la couleur, les trois suivent.
##
## Depuis, le liseré applique l'énergie (décision d'Adrien, même jour), et le
## corps adverse aussi dans un commit séparé, que la décision doit confirmer.
## La couleur reste pourtant le levier : `player_rim_light.gdshader` (le corps du
## joueur local, que la bande éclaire aussi) et `blood_shader.gdshader`
## l'ignorent encore, et une énergie fixe à 1 rend la bande juste sous tous.
##
## ⚠️ **UNE seule lumière pour toute la carte, et c'est la contrainte qui fonde le
## module.** Godot n'applique pas plus de 15 lumières à un même `CanvasItem`, et
## un quadrant de `TileMapLayer` (560 px) en est un — ROADMAP, « Pièges connus »,
## *Une lumière à énergie zéro compte quand même*. Des lumières posées le long
## des murs crèveraient ce plafond dès la première salle. Ici la forme de la
## bande est dans la TEXTURE, cuite depuis la grille des murs : la lumière coûte
## 1 sur 15, partout.
##
## Pas d'ombre : la bande n'existe que du côté ouvert de chaque mur (plus un
## léger débord, pour que le liseré l'accroche). Elle ne traverse aucun mur.
##
## **Équité en ligne** : la phase se lit sur l'horloge de manche que l'hôte recale
## chez le client (`rpc_sync_time`), jamais sur l'horloge propre de chaque
## machine — sinon l'un verrait son adversaire éclairé pendant que l'autre se
## croirait dans le noir.
class_name MurLed
extends PointLight2D

const NOM := "MurLed"
const DRAPEAU := "--led-murs"
const DRAPEAU_FIGE := "--led-murs-fige"

# --- Résolution de la texture ------------------------------------------------
## Texels par case de 35 px au mieux (≈ 4,4 px) : assez pour le retrait de 5 px
## contre la face. Descend sur les grandes cartes pour que la texture tienne sous
## TAILLE_MAX_TEXTURE px de côté — et sa cuisson sous deux secondes, une fois par
## carte grâce au cache.
const TEXELS_PAR_CASE_MAX := 8
const TEXELS_PAR_CASE_MIN := 4
const TAILLE_MAX_TEXTURE := 512

# --- Profil de la bande, distances en fraction de case (35 px) ---------------
# Une LED posée au pied d'un mur éclaire le sol devant elle, pas l'arête du mur :
# le profil est donc RETENU contre la face (FACE), culmine un peu plus loin
# (RETRAIT), puis s'éteint doucement (PORTEE). Sans cette retenue, le liseré,
# bien plus réactif que le sol sombre (~13 fois au banc), l'emporte et la bande
# se lit comme un trait blanc au lieu d'une lueur au sol.

## Intensité relative contre la face du mur, et dans le débord.
const FACE := 0.3
## Distance du sommet de la bande à la face (≈ 5 px).
const RETRAIT := 0.15
## Distance où la bande s'éteint (≈ 157 px). Trois fois la première portée
## (1,5 case), demande d'Adrien du 2026-09-11 : « que la respiration éclaire
## trois fois plus loin du mur ».
const PORTEE := 4.5
## Débord à l'intérieur du mur (≈ 3,5 px) : le liseré est peint au bord de la
## tuile, sans débord il ne respirerait pas avec la bande.
const DEBORD := 0.1

## Tempo de la musique (`AudioManager.BPM`), recopié et non lu : l'autoload
## n'existe pas dans une suite headless. `test_mur_led` vérifie que les deux
## disent la même chose.
const BPM_MUSIQUE := 170.0
## Une respiration = six mesures, vingt-quatre temps ≈ 8,5 s. C'était quatre
## mesures (≈ 5,65 s) ; Adrien l'a voulue 1,5 fois plus lente le 2026-09-11, et
## six mesures la gardent calée sur la musique.
const PERIODE := 24.0 * 60.0 / BPM_MUSIQUE
## Facteur de couleur au sommet de l'inspiration, réglé au banc isolé — voir la
## ROADMAP pour les mesures qui le justifient.
const PIC := 1.2
## Sous ce facteur la lumière est éteinte, pas laissée à zéro : à zéro elle
## occuperait quand même sa place parmi les 15 (Pièges connus).
const SEUIL := 0.004
## L'ambre de la charte. La charte sépare deux familles : le MONDE est chaud, et
## le froid « LED » est réservé à l'appareil — HUD, interface. La bande éclaire
## le monde, elle en prend donc la couleur, malgré son nom. Et l'ambre y dit
## déjà deux choses justes : ce qui brûle, et la mise en garde — la bande dit
## « ici, on te voit ». (La première version portait ACIER, la couleur du
## boîtier de l'appareil : une teinte d'interface dans l'arène.)
const COULEUR := Charte.AMBRE

## Distance « infinie » de la transformée : finie, pour que les soustractions de
## l'algorithme restent des nombres.
const LOIN := 1.0e12

## Verdict partagé par toutes les reconstructions d'arène : F7 survit à un
## rematch. Lu une seule fois — la ligne de commande ne change pas en cours de vie.
static var _actif := false
static var _actif_lu := false
## Fraction du sommet tenue par `--led-murs-fige[=f]` ; négative = respire.
static var _fige := -1.0

## La dernière texture cuite, et la grille dont elle vient. `rebuild_arena()`
## reconstruit l'arène à CHAQUE manche : sans ce cache, la cuisson se payerait
## au début de chaque manche au lieu d'une fois par carte.
static var _cache_cle := 0
static var _cache_texture: ImageTexture

## Rend le temps écoulé de la manche, ou une valeur négative hors manche.
var horloge: Callable
var _temps_local := 0.0
var _f7_tenue := false

static func est_actif() -> bool:
	if not _actif_lu:
		_actif_lu = true
		var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
		for arg in args:
			if arg == DRAPEAU_FIGE:
				_fige = 1.0
			elif arg.begins_with(DRAPEAU_FIGE + "="):
				_fige = clampf(float(arg.get_slice("=", 1)), 0.0, 1.0)
		if not OS.is_debug_build():
			_fige = -1.0
		_actif = DRAPEAU in args or _fige >= 0.0
	return _actif

## Unique point d'entrée, appelé par `rebuild_arena()` après les collisions.
## Remplace le bandeau précédent (rematch, changement de carte). Rend `null` hors
## debug sans drapeau : le coût se réduit alors à ce test.
static func poser(data: Dictionary, parent: Node, horloge_manche: Callable) -> MurLed:
	var precedent := parent.get_node_or_null(NOM)
	if precedent != null:
		# Retrait immédiat : `queue_free()` seul ne libère le nom qu'en fin
		# d'image, et le nouveau bandeau hériterait d'un nom suffixé.
		parent.remove_child(precedent)
		precedent.queue_free()
	if not est_actif() and not OS.is_debug_build():
		return null

	var murs := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var zone := rect_monde(murs, tuile)
	var led := MurLed.new()
	led.name = NOM
	led.horloge = horloge_manche
	led.texture = texture_pour(murs)
	led.position = zone.get_center()
	led.texture_scale = zone.size.x / led.texture.get_width()
	led.shadow_enabled = false
	# Sol et murs (1), sprite adverse (2), joueur local (4) : les mêmes cibles
	# que la torche. Visibilité par défaut (1) : les deux vues la dessinent.
	led.range_item_cull_mask = 1 | 2 | 4
	led.regler(0.0)
	parent.add_child(led)
	return led

## La texture de la bande pour cette grille, cuite une seule fois par carte.
static func texture_pour(murs: Array) -> ImageTexture:
	var cle := hash(murs)
	if _cache_texture == null or cle != _cache_cle:
		_cache_texture = ImageTexture.create_from_image(cuire(murs))
		_cache_cle = cle
	return _cache_texture

## Pose l'intensité : 0 = creux, 1 = sommet. Énergie fixe, couleur dosée — voir
## l'en-tête.
func regler(fraction: float) -> void:
	var k := PIC * clampf(fraction, 0.0, 1.0)
	energy = 1.0
	color = Color(COULEUR.r * k, COULEUR.g * k, COULEUR.b * k, 1.0)
	enabled = k > SEUIL

## Rectangle monde couvert par la grille (bordure comprise) : l'indice (0, 0)
## est la cellule de carte (-BORDER, -BORDER), comme dans `build_collisions()`.
static func rect_monde(murs: Array, tuile: Vector2) -> Rect2:
	var larg := murs.size()
	var haut := (murs[0] as Array).size() if larg > 0 else 0
	return Rect2(-tuile * MapGeometry.BORDER, Vector2(larg, haut) * tuile)

## Respiration à l'instant `t` (secondes) : 0 au creux, 1 au sommet.
static func souffle(t: float) -> float:
	var s := 0.5 - 0.5 * cos(TAU * t / PERIODE)
	# Au carré : le creux dure plus que le sommet, comme une respiration au
	# repos — l'expiration s'attarde, l'inspiration passe.
	return s * s

## Intensité relative de la bande à la distance `d` (en cases) d'un mur, côté
## ouvert.
static func profil(d: float) -> float:
	if d >= PORTEE:
		return 0.0
	if d < RETRAIT:
		return lerpf(FACE, 1.0, smoothstep(0.0, 1.0, d / RETRAIT))
	var x := 1.0 - (d - RETRAIT) / (PORTEE - RETRAIT)
	return x * x

static func texels_par_case(larg: int, haut: int) -> int:
	return clampi(TAILLE_MAX_TEXTURE / maxi(maxi(larg, haut), 1),
		TEXELS_PAR_CASE_MIN, TEXELS_PAR_CASE_MAX)

## Cuit le masque de la bande : blanc, l'intensité dans l'alpha, comme les
## masques peints de `light_textures.gd`.
##
## La distance de chaque texel au mur le plus proche vient d'une transformée de
## distance euclidienne exacte (Felzenszwalb, deux passes séparables) : son coût
## ne dépend que du nombre de texels, pas de la portée. La première version ne
## lisait que les huit cases voisines et mettait les motifs en cache ; à 4,5
## cases de portée il aurait fallu un voisinage de 11 × 11 cases, et presque
## chaque case de la carte en aurait eu un différent.
static func cuire(murs: Array) -> Image:
	var larg := murs.size()
	var haut := (murs[0] as Array).size() if larg > 0 else 0
	if larg == 0 or haut == 0:
		var vide := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		vide.fill(Color(1, 1, 1, 0))
		return vide
	var t := texels_par_case(larg, haut)
	var w := larg * t
	var h := haut * t
	# Sites de la transformée : les texels qui tombent dans un mur.
	var carres := PackedFloat64Array()
	carres.resize(w * h)
	for y in h:
		for x in w:
			carres[y * w + x] = 0.0 if murs[x / t][y / t] else LOIN
	_transformee(carres, w, h)
	# Blanc partout, l'intensité dans l'alpha : un fond noir transparent
	# assombrirait le bord de la bande au filtrage linéaire.
	var octets := PackedByteArray()
	octets.resize(w * h * 4)
	octets.fill(255)
	var debord := FACE * clampf(1.0 - 0.5 / (DEBORD * t), 0.0, 1.0)
	for y in h:
		for x in w:
			var i := y * w + x
			var a := 0.0
			if murs[x / t][y / t]:
				# Le débord fait moins d'un texel : il ne touche que l'anneau de
				# texels du mur au contact de l'ouvert, à un demi-texel de la face.
				if _touche_l_ouvert(murs, x, y, t, w, h):
					a = debord
			else:
				# Distance centre à centre au texel de mur le plus proche, moins
				# un demi-texel : la distance à la FACE du mur.
				a = profil(maxf(sqrt(carres[i]) - 0.5, 0.0) / t)
			octets[i * 4 + 3] = roundi(a * 255.0)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, octets)

## Un texel de mur dont un voisin direct est ouvert. Hors grille = ouvert, comme
## le vide qui borde la carte.
static func _touche_l_ouvert(murs: Array, x: int, y: int, t: int, w: int, h: int) -> bool:
	for e in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var vx: int = x + e.x
		var vy: int = y + e.y
		if vx < 0 or vy < 0 or vx >= w or vy >= h:
			return true
		if not murs[vx / t][vy / t]:
			return true
	return false

## Transformée de distance euclidienne au carré, en place : colonnes puis lignes.
static func _transformee(g: PackedFloat64Array, w: int, h: int) -> void:
	var f := PackedFloat64Array()
	f.resize(maxi(w, h))
	for x in w:
		for y in h:
			f[y] = g[y * w + x]
		var d := _transformee_1d(f, h)
		for y in h:
			g[y * w + x] = d[y]
	for y in h:
		for x in w:
			f[x] = g[y * w + x]
		var d := _transformee_1d(f, w)
		for x in w:
			g[y * w + x] = d[x]

## Transformée 1D (Felzenszwalb & Huttenlocher) : enveloppe inférieure des
## paraboles centrées sur chaque site, puis lecture de l'enveloppe.
static func _transformee_1d(f: PackedFloat64Array, n: int) -> PackedFloat64Array:
	var d := PackedFloat64Array()
	d.resize(n)
	var v := PackedInt32Array()
	v.resize(n)
	var z := PackedFloat64Array()
	z.resize(n + 1)
	var k := 0
	v[0] = 0
	z[0] = -INF
	z[1] = INF
	for q in range(1, n):
		var s := ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0 * (q - v[k]))
		while s <= z[k]:
			k -= 1
			s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0 * (q - v[k]))
		k += 1
		v[k] = q
		z[k] = s
		z[k + 1] = INF
	k = 0
	for q in n:
		while z[k + 1] < q:
			k += 1
		var e := q - v[k]
		d[q] = e * e + f[v[k]]
	return d

## Distance du point `p` (repère de la case, 0..1) à la case voisine `c`.
static func distance_case(p: Vector2, c: Vector2) -> float:
	var ecart := Vector2(
		maxf(maxf(c.x - p.x, p.x - (c.x + 1.0)), 0.0),
		maxf(maxf(c.y - p.y, p.y - (c.y + 1.0)), 0.0))
	return ecart.length()

func _process(delta: float) -> void:
	# F7 par scrutation et non par `_unhandled_input` : le bandeau vit dans le
	# monde d'un SubViewport, qui ne reçoit pas les événements quand le rendu
	# passe par la racine (vue unique, chantier R).
	if OS.is_debug_build():
		var tenue := Input.is_key_pressed(KEY_F7)
		if tenue and not _f7_tenue:
			_actif = not est_actif()
			print("MurLed : bandeau LED %s (F7)" % ("allumé" if _actif else "éteint"))
		_f7_tenue = tenue
	if not est_actif():
		enabled = false
		return
	if _fige >= 0.0:
		regler(_fige)
		return
	var t: float = horloge.call() if horloge.is_valid() else -1.0
	if t < 0.0:
		# Hors manche (salon d'attente) : horloge propre, sans enjeu d'équité.
		_temps_local += delta
		t = _temps_local
	regler(souffle(t))
