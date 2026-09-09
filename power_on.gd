class_name PowerOn
extends CanvasLayer

## DA6.5 — le lancement du jeu comme un allumage.
##
## « Logo, souffle, lumière. » Le jeu s'ouvrait sur son menu, déjà éclairé, déjà
## complet — la seule chose qu'un jeu dont le sujet EST l'allumage ne devrait
## jamais faire. Cette séquence tient trois secondes et ne raconte qu'une chose :
## quelqu'un vient d'appuyer sur l'interrupteur.
##
## ## Ce qu'elle est, physiquement
##
## Un filament. Pas un fondu, pas un logo qui apparaît : une source de lumière
## qui monte en température, dépasse, retombe, et se stabilise — la courbe d'une
## ampoule à incandescence, qui est exactement la lumière que ce jeu a choisie
## (`Charte.HALOGENE`, « la température d'une torche »). Le wordmark n'apparaît
## pas : il est **révélé** par cette lumière, comme tout le reste du jeu.
##
## ## Trois choses apprises en l'écrivant
##
## ⚠️ **Un `Light2D` ne sert à rien ici.** Réflexe évident — le jeu est fait de
## lumières 2D — et faux : une `PointLight2D` a besoin d'une surface à éclairer,
## et il n'y a que du noir. La montée se peint donc dans le `modulate` du
## wordmark et dans l'alpha d'un halo dessiné. La lumière du menu, elle, existe
## déjà (M13, la torche du curseur) : la séquence lui passe la main.
##
## ⚠️ **Elle est SAUTABLE dès la première image.** Une séquence d'ouverture se
## regarde une fois et se subit mille fois. Trois secondes non sautables au
## quinzième lancement de la journée, c'est trois secondes retirées à quelqu'un
## qui voulait jouer — et pendant un développement, c'est le sentiment que le
## jeu résiste. N'importe quelle touche la termine, immédiatement.
##
## ⚠️ **Elle ne bloque rien derrière elle.** Le menu est monté, vivant et prêt
## dessous pendant toute la séquence ; l'allumage n'est qu'un voile. Faire
## attendre la construction de l'interface la ferait apparaître d'un bloc à la
## fin — un à-coup, juste après une animation soignée.
##
## ## Ce qui manque, et qui est marqué *(C)* dans la fiche
##
## **Le souffle.** La fiche dit « logo, souffle, lumière » : le souffle est un
## son — un tube qui s'amorce, un ronflement de secteur qui monte et se coupe.
## Le crochet est posé (`AudioManager.play_ui("ui_power_on")`, muet tant que le
## fichier n'existe pas, comme tous les crochets audio de ce dépôt) ; le fichier
## est une commande. Sans lui la séquence est visuellement complète et
## silencieuse.

const Charte := preload("res://charte.gd")

## Au-dessus de tout, y compris de l'affiche de fin — rien ne peut légitimement
## se produire pendant l'allumage.
const COUCHE := 200

## La montée du filament. 0,9 s : en deçà, l'œil lit un fondu ; au-delà, il lit
## une attente.
const D_MONTEE := 0.9
## Le dépassement, puis la stabilisation — la surchauffe brève d'un tube.
const D_DEPASSEMENT := 0.18
const D_RETOMBEE := 0.5
## La tenue, le temps de lire le mot.
const D_TENUE := 0.55
const D_SORTIE := 0.45

## L'énergie de crête, au-dessus de 1 : c'est le dépassement qui fait un
## allumage plutôt qu'une apparition.
const CRETE := 1.35

## Fraction de la largeur de l'écran occupée par le wordmark.
const PART_ENSEIGNE := 0.44

signal terminee

var _fini := false
var _tw: Tween
var _enseigne: TextureRect
var _halo: Control


## Lance la séquence. Rend `null` — et ne pose rien — si le wordmark est
## introuvable : un allumage sans logo est un écran noir de trois secondes, et
## personne ne saurait dire que c'est voulu.
static func lancer(parent: Node) -> PowerOn:
	if not ResourceLoader.exists(Charte.CHEMIN_ENSEIGNE):
		return null
	var couche := PowerOn.new()
	couche.name = "PowerOn"
	couche.layer = COUCHE
	parent.add_child(couche)
	couche._composer()
	return couche


func _composer() -> void:
	var fond := ColorRect.new()
	fond.color = Charte.NOIR
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fond)

	var hote := Control.new()
	hote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hote)

	var ecran := _ecran()

	# Le halo : un rectangle additif derrière le mot, qui EST la source. Dessiné
	# et non texturé — une texture de halo serait un dégradé radial
	# mathématiquement parfait, c'est-à-dire le défaut nommé en tête du chantier
	# DA (« chaque valeur par défaut visible dit : personne n'a choisi ça »).
	var halo := _Halo.new()
	_halo = halo
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hote.add_child(halo)

	var enseigne := TextureRect.new()
	_enseigne = enseigne
	enseigne.texture = load(Charte.CHEMIN_ENSEIGNE)
	enseigne.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enseigne.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enseigne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enseigne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var largeur := ecran.x * PART_ENSEIGNE
	var marge_h := (ecran.x - largeur) * 0.5
	enseigne.offset_left = marge_h
	enseigne.offset_right = -marge_h
	hote.add_child(enseigne)

	# Tout part de zéro : l'écran est éteint, pas sombre.
	enseigne.modulate = Color(Charte.HALOGENE, 0.0)
	halo.energie = 0.0

	AudioManager.play_ui("ui_power_on")

	var tw := create_tween()
	_tw = tw
	# La montée : ENTREE (lente au départ) — un filament ne s'allume pas
	# linéairement, il hésite puis prend.
	Charte.animer_via(tw, func(v: float) -> void: _poser(enseigne, halo, v),
		0.0, CRETE, D_MONTEE, Charte.Courbe.ENTREE)
	Charte.animer_via(tw, func(v: float) -> void: _poser(enseigne, halo, v),
		CRETE, 0.86, D_DEPASSEMENT, Charte.Courbe.SORTIE)
	Charte.animer_via(tw, func(v: float) -> void: _poser(enseigne, halo, v),
		0.86, 1.0, D_RETOMBEE, Charte.Courbe.SORTIE)
	tw.tween_interval(D_TENUE)
	tw.tween_callback(terminer)

	set_process_unhandled_input(true)


## La taille réelle de l'écran, disponible IMMÉDIATEMENT.
##
## ⚠️ **`Control.size` vaut zéro tant que la mise en page n'a pas eu lieu**, et
## une composition bâtie dans la foulée d'un `add_child()` la lit donc à zéro.
## Le repli « 1920×1080 » qui traînait ici marchait par coïncidence sur la
## fenêtre de développement et donnait des marges d'un tiers trop larges en
## 1280×720. Le viewport, lui, connaît sa taille avant tout le monde.
func _ecran() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)


## **Tenir la pose.** Coupe l'animation et fige la séquence à son état établi,
## sans la terminer. C'est ce que le photographe demande (`tools/photographe.gd`,
## plan `power-on`) : la séquence dure deux secondes et démarre au lancement du
## jeu, si bien qu'un outil qui monte le jeu, vérifie ses appuis et prépare son
## dossier arrive **après la fin** — la première prise a rendu le menu, pas
## l'allumage.
##
## Attendre au bon moment aurait marché une fois sur deux, selon la vitesse de
## la machine. Demander au sujet de ne plus bouger marche toujours.
func figer() -> void:
	if _fini:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_poser(_enseigne, _halo, 1.0)


func _poser(enseigne: TextureRect, halo: Control, v: float) -> void:
	if not is_instance_valid(enseigne):
		return
	enseigne.modulate = Color(Charte.HALOGENE, clampf(v, 0.0, 1.0))
	# Le halo suit la crête AU-DELÀ de 1, là où le mot sature : c'est lui qui
	# porte le dépassement, et c'est pour ça qu'on le voit.
	if is_instance_valid(halo):
		halo.energie = v


## Fin de la séquence : le voile s'efface sur le menu déjà vivant dessous.
func terminer() -> void:
	if _fini:
		return
	_fini = true
	set_process_unhandled_input(false)
	var tw := create_tween()
	var premier := true
	for enfant in get_children():
		var c := enfant as CanvasItem
		if c == null:
			continue
		if not premier:
			tw.parallel()
		premier = false
		Charte.animer(tw, c, "modulate:a", c.modulate.a, 0.0, D_SORTIE,
			Charte.Courbe.ENTREE)
	tw.tween_callback(func() -> void:
		terminee.emit()
		queue_free())


func _unhandled_input(evenement: InputEvent) -> void:
	if _fini:
		return
	var geste: bool = evenement is InputEventKey and evenement.pressed \
		and not evenement.echo
	geste = geste or (evenement is InputEventMouseButton and evenement.pressed)
	geste = geste or (evenement is InputEventJoypadButton and evenement.pressed)
	if not geste:
		return
	get_viewport().set_input_as_handled()
	terminer()


## Le halo, dessiné à la main.
##
## Un empilement de rectangles de plus en plus larges et de moins en moins
## opaques, en fondu additif : la lueur d'un tube derrière un mot. Le nombre de
## couches est petit exprès — un dégradé trop lisse redevient le dégradé parfait
## qu'on cherche à éviter, et l'escalier léger EST la signature.
class _Halo extends Control:
	## Douze couches, et un fondu ADDITIF. Le premier jet en empilait sept en
	## fondu normal : chacune recouvrait la précédente, si bien que la plus large
	## et la plus pâle peignait par-dessus toutes les autres — le résultat était
	## un **rectangle gris** posé derrière le mot, pas une lueur. En additif, les
	## couches s'accumulent au centre et s'effacent vers les bords : c'est ce que
	## fait la lumière.
	const COUCHES := 12
	const HAUTEUR := 0.30
	const LARGEUR := 0.72
	## L'alpha d'une couche, avant la décroissance.
	##
	## La somme au centre vaut `GRAIN × Σ(1−t)²` sur les douze couches, soit
	## `GRAIN × 3,51`. À 0,06 cela fait **0,21** — en additif sur du noir, une
	## lueur chaude qu'on voit sans qu'elle devienne un aplat qu'on lit.
	##
	## ⚠️ Le premier chiffre était 0,022, posé avec un commentaire qui annonçait
	## « 0,26 au centre » : la somme y était calculée SANS la décroissance au
	## carré, et le halo valait en réalité 0,08 — invisible. Une constante dont
	## le commentaire fait l'arithmétique doit la faire juste, sans quoi c'est le
	## commentaire qu'on relit au lieu de mesurer.
	const GRAIN := 0.06

	var energie: float = 0.0:
		set(v):
			energie = v
			queue_redraw()

	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		if energie <= 0.001 or size.x <= 0.0:
			return
		var centre := size * 0.5
		for i in COUCHES:
			var t := float(i + 1) / float(COUCHES)
			var demi := Vector2(size.x * LARGEUR * t, size.y * HAUTEUR * t) * 0.5
			# Décroissance au carré : une lueur ne s'éteint pas linéairement, et
			# le linéaire est précisément ce qui donnait un bord franc.
			var chute: float = (1.0 - t) * (1.0 - t)
			var a: float = clampf(energie, 0.0, 1.4) * GRAIN * chute
			draw_rect(Rect2(centre - demi, demi * 2.0),
				Color(Charte.HALOGENE, a), true)
