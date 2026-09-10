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
## (build debug seulement). Sans l'un ni l'autre, rien n'est créé hors debug ; en
## debug la lumière existe, pour que F7 puisse l'allumer, mais reste
## `enabled = false`.
##
## ⚠️ **UNE seule lumière pour toute la carte, et c'est la contrainte qui fonde le
## module.** Godot n'applique pas plus de 15 lumières à un même `CanvasItem`, et
## un quadrant de `TileMapLayer` (560 px) en est un — ROADMAP, « Pièges connus »,
## *Une lumière à énergie zéro compte quand même*. Des lumières posées le long
## des murs crèveraient ce plafond dès la première salle, et le halo tranché net
## de la fusée reviendrait. Ici la forme de la bande est dans la TEXTURE, cuite
## une fois depuis la grille des murs : la lumière coûte 1 sur 15, partout.
##
## Pas d'ombre : la bande n'existe que du côté ouvert de chaque mur (plus un
## débord de quelques pixels, pour que le liseré l'accroche). Elle ne peut donc
## pas traverser un mur, et aucun occluder n'est à calculer.
##
## **Équité en ligne** : la phase se lit sur l'horloge de manche que l'hôte recale
## chez le client (`rpc_sync_time`), jamais sur l'horloge propre de chaque
## machine — sinon l'un verrait son adversaire éclairé pendant que l'autre se
## croirait dans le noir.
class_name MurLed
extends PointLight2D

const NOM := "MurLed"
const DRAPEAU := "--led-murs"
## Tient la bande à son sommet, sans respirer (build debug seulement). Pour
## juger l'aspect ou photographier : pendant le décompte l'horloge de manche est
## arrêtée à 0, donc au creux — le photographe n'y voyait rien.
const DRAPEAU_FIGE := "--led-murs-fige"

## Texels par case de 35 px : un texel ≈ 2,9 px, lissé par le filtrage linéaire.
## 12 et non 35 : une carte de 128 cases pèserait sinon 22 Mo de texture.
const TEXELS_PAR_CASE := 12
## Portée de la bande depuis la face du mur, en fraction de case (≈ 28 px).
## ⚠️ Doit rester ≤ 1 : la cuisson ne regarde que les huit voisines d'une case.
const PORTEE := 0.8
## Débord à l'intérieur du mur, en fraction de case (≈ 3,5 px). Le liseré est
## peint au bord de la tuile : sans débord, la bande s'arrêterait juste avant lui
## et le filament ne respirerait pas avec elle.
const DEBORD := 0.1

## Tempo de la musique (`AudioManager.BPM`), recopié et non lu : l'autoload
## n'existe pas dans une suite headless. `test_mur_led` vérifie que les deux
## disent la même chose.
const BPM_MUSIQUE := 170.0
## Une respiration = quatre mesures, seize temps ≈ 5,65 s.
const PERIODE := 16.0 * 60.0 / BPM_MUSIQUE
## Énergie au sommet de l'inspiration. Faible exprès, et à doser en connaissant
## `player_enemy_light.gdshader` : il multiplie la lumière reçue par 4 avant de
## plafonner au gris plein. À 0,22 × ACIER, un adversaire collé au mur monte à
## ~70 % de son gris — une silhouette, pas un joueur pris dans une torche.
const PIC := 0.22
## Blanc froid : la seule lumière du jeu qui ne vient ni d'un feu ni d'un
## filament halogène doit se lire comme telle.
const COULEUR := Charte.ACIER

## Verdict partagé par toutes les reconstructions d'arène : F7 survit à un
## rematch. Lu une seule fois — la ligne de commande ne change pas en cours de vie.
static var _actif := false
static var _actif_lu := false

## Rend le temps écoulé de la manche, ou une valeur négative hors manche.
var horloge: Callable
var _temps_local := 0.0
var _f7_tenue := false

static var _fige := false

static func est_actif() -> bool:
	if not _actif_lu:
		_actif_lu = true
		var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
		_fige = DRAPEAU_FIGE in args and OS.is_debug_build()
		_actif = DRAPEAU in args or _fige
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
	var led := MurLed.new()
	led.name = NOM
	led.horloge = horloge_manche
	led.texture = ImageTexture.create_from_image(cuire(murs))
	led.position = rect_monde(murs, tuile).get_center()
	led.texture_scale = tuile.x / TEXELS_PAR_CASE
	led.color = COULEUR
	led.energy = 0.0
	led.enabled = false
	led.shadow_enabled = false
	# Sol et murs (1), sprite adverse (2), joueur local (4) : les mêmes cibles
	# que la torche. Visibilité par défaut (1) : les deux vues la dessinent.
	led.range_item_cull_mask = 1 | 2 | 4
	parent.add_child(led)
	return led

## Rectangle monde couvert par la grille (bordure comprise) : l'indice (0, 0)
## est la cellule de carte (-BORDER, -BORDER), comme dans `build_collisions()`.
static func rect_monde(murs: Array, tuile: Vector2) -> Rect2:
	var larg := murs.size()
	var haut := (murs[0] as Array).size() if larg > 0 else 0
	return Rect2(-tuile * MapGeometry.BORDER, Vector2(larg, haut) * tuile)

## Intensité de la bande à l'instant `t` (secondes), de 0 à PIC.
static func energie(t: float) -> float:
	var souffle := 0.5 - 0.5 * cos(TAU * t / PERIODE)
	# Au carré : le creux dure plus que le sommet, comme une respiration au
	# repos — l'expiration s'attarde, l'inspiration passe.
	return PIC * souffle * souffle

## Cuit le masque de la bande : blanc, l'intensité dans l'alpha, comme les
## masques peints de `light_textures.gd`. Une case ne dépend que d'elle-même et
## de ses huit voisines ; les motifs sont donc calculés une fois par voisinage
## (au plus 512) puis recopiés.
static func cuire(murs: Array) -> Image:
	var larg := murs.size()
	var haut := (murs[0] as Array).size() if larg > 0 else 0
	var t := TEXELS_PAR_CASE
	var img := Image.create_empty(maxi(larg, 1) * t, maxi(haut, 1) * t, false, Image.FORMAT_RGBA8)
	# Blanc transparent et non noir transparent : le filtrage linéaire mélange
	# aussi la couleur, et un fond noir assombrirait le bord de la bande.
	img.fill(Color(1, 1, 1, 0))
	var motifs := {}
	for ix in larg:
		for iy in haut:
			var cle := _cle(murs, ix, iy)
			# 0 : aucun mur autour ; 511 : mur plein de tous côtés. Rien à peindre.
			if cle == 0 or cle == 511:
				continue
			if not motifs.has(cle):
				motifs[cle] = _motif(cle)
			img.blit_rect(motifs[cle], Rect2i(0, 0, t, t), Vector2i(ix * t, iy * t))
	return img

## Voisinage 3×3 d'une case, un bit par case : (dy + 1) × 3 + (dx + 1), la case
## elle-même au bit 4. Hors grille = pas de mur.
static func _cle(murs: Array, ix: int, iy: int) -> int:
	var cle := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := ix + dx
			var y := iy + dy
			if x < 0 or y < 0 or x >= murs.size() or y >= (murs[x] as Array).size():
				continue
			if murs[x][y]:
				cle |= 1 << ((dy + 1) * 3 + dx + 1)
	return cle

static func _motif(cle: int) -> Image:
	var t := TEXELS_PAR_CASE
	var motif := Image.create_empty(t, t, false, Image.FORMAT_RGBA8)
	var mur_ici := (cle & (1 << 4)) != 0
	for v in t:
		for u in t:
			var p := Vector2((u + 0.5) / t, (v + 0.5) / t)
			# Hors d'un mur : distance au mur le plus proche. Dans un mur :
			# distance à la case ouverte la plus proche. Les deux valent 0 sur la
			# face, ce qui raccorde les deux profils sans couture.
			var d := INF
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var voisin_mur := (cle & (1 << ((dy + 1) * 3 + dx + 1))) != 0
					if voisin_mur != mur_ici:
						d = minf(d, _distance_case(p, Vector2(dx, dy)))
			var a := 0.0
			if mur_ici:
				a = clampf(1.0 - d / DEBORD, 0.0, 1.0)
			else:
				var x := clampf(1.0 - d / PORTEE, 0.0, 1.0)
				a = x * x
			motif.set_pixel(u, v, Color(1, 1, 1, a))
	return motif

## Distance du point `p` (repère de la case, 0..1) à la case voisine `c`.
static func _distance_case(p: Vector2, c: Vector2) -> float:
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
	var t: float = horloge.call() if horloge.is_valid() else -1.0
	if t < 0.0:
		# Hors manche (salon d'attente) : horloge propre, sans enjeu d'équité.
		_temps_local += delta
		t = _temps_local
	energy = PIC if _fige else energie(t)
	# Énergie zéro n'est pas éteinte : à 0, la lumière occuperait quand même sa
	# place parmi les 15 (Pièges connus). Au creux, on l'éteint vraiment.
	enabled = energy > 0.002
