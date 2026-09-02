extends Node

## Les trois propriétés de l'IMAGE que le jeu doit tenir.
##
## **Trois, pas trente, et chacune attachée à un défaut qui s'est réellement
## produit.** C'est le seul bon critère pour décider laquelle écrire : une
## assertion inventée par précaution finit par gêner sans avoir jamais rien
## attrapé.
##
## ## Des propriétés, jamais des images
##
## La réponse évidente — comparer à des captures de référence — est la mauvaise.
## Une image de référence casse à chaque changement légitime : un effet ajusté,
## une police, un pixel de marge. **Un contrôle qui casse tout le temps finit
## ignoré**, et on l'a vérifié trois fois en deux jours sur des contrôles bien
## plus stables que celui-là.
##
## Une propriété, elle, énonce quelque chose qu'on sait vrai du jeu. Elle survit
## à la refonte de ce qu'elle regarde.
##
## ## Ce qui a besoin de pixels, et ce qui n'en a pas besoin
##
## Deux des trois lisent l'image. La troisième — le joueur est-il au centre —
## **est de la géométrie** : comparer la caméra au joueur est plus sûr et plus
## simple que de chercher un sprite dans des pixels. On ne rastérise que ce qui
## l'exige.
##
## Lancer : godot --path . res://tools/test_rendu.tscn

const Commun := preload("res://tools/rendu_commun.gd")

## Le cadre de droite porte du texte : sa dispersion de luminance ne peut pas
## être nulle. C'est ce qui distingue « éteint » de « vide » — un cadre noir et
## un cadre plein ont la même moyenne possible, jamais le même contraste.
const CONTRASTE_MIN := 0.010
## L'arène est un jeu dans le noir. Au-delà, ce n'est plus le même jeu.
const LUMINANCE_ARENE_MAX := 0.10
## Le sol du damier, noir du `CanvasModulate` levé. Le seuil est posé ENTRE deux
## ordres de grandeur, jamais calibré sur l'un d'eux : mesuré le 2026-08-27,
## 0,00098 recouvert contre 0,29545 peint, à l'entraînement ; 0,036 contre 0,280
## côté hôte et 0,033 contre 0,278 côté client dans un duel ENet.
const LUMINANCE_SOL_MIN := 0.05
## Le joueur doit tenir dans la moitié centrale de sa vue.
const ECART_CENTRE_MAX := 0.25

var _failures := 0
var _main: Node
var _ui: Node

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _ready() -> void:
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ les contrôles de rendu ne peuvent pas travailler ici : ", refus)
		printerr("  Lancer SANS --headless : godot --path . res://tools/test_rendu.tscn")
		_sortir(1)
		return

	print("=== Ce qui se voit ===")
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")

	var manquants: Array[String] = Commun.preconditions_manquantes(_ui, _main)
	if not manquants.is_empty():
		printerr("✗ les contrôles ne peuvent pas démarrer :")
		for m in manquants:
			printerr("    · ", m)
		_sortir(1)
		return

	await _cadre_de_droite()
	await _entrainement_centre()
	await _entrainement_sol_peint()
	await _arene_reste_noire()

	if _failures == 0:
		print("\n✓ Tous les contrôles passent")
	else:
		printerr("\n✗ %d contrôle(s) en échec" % _failures)
	_sortir(1 if _failures > 0 else 0)


## **Le défaut du 2026-08-19 : « je ne vois plus le cadre à droite des menus, et
## ce qu'il contient. Tout est noir. »** Deux effets relisaient l'écran, validés
## au banc de cadence sans que personne ne les regarde.
##
## **Contre-testé le jour même, et c'est ce qui donne sa valeur à ce contrôle :**
## en remettant `UI.RELECTURE_ECRAN` à `true`, il tombe — écart-type 0,0075 contre
## un plancher à 0,010. Il attrape donc le défaut réel, et pas seulement l'absence
## de défaut. Une assertion qu'on n'a jamais vue échouer ne prouve rien.
func _cadre_de_droite() -> void:
	print("\n[Le cadre de droite montre quelque chose]")
	_ui.show_main_menu()
	await _reposer(0.8)

	var cadre = _ui.hub.right_panel() if _ui.hub.has_method("right_panel") else null
	if cadre == null:
		_check("le cadre de droite est atteignable", false, "MenuHub.right_panel() absent")
		return
	var zone := Rect2i((cadre as Control).get_global_rect())
	var img: Image = await Commun.capturer(get_tree())
	var contraste := Commun.contraste(img, zone)
	# Un cadre qui porte un titre et un texte a forcément du relief. Zéro
	# dispersion veut dire un aplat — c'est-à-dire éteint, quelle que soit sa
	# couleur.
	_check("le cadre a du relief, donc du contenu visible",
		contraste >= CONTRASTE_MIN, "écart-type de luminance %.4f" % contraste)


## **Le défaut du 2026-08-19 : en entraînement, le joueur était en bas de l'écran
## et la caméra ne le suivait pas.** Le suivi était accroché à `round_active`,
## que l'entraînement désarme exprès.
##
## Géométrie et non pixels : on demande à la caméra où elle regarde, pas à
## l'image où est le joueur.
func _entrainement_centre() -> void:
	print("\n[La caméra regarde le joueur]")
	if not _main.has_method("_on_training_requested"):
		_check("l'entraînement est atteignable", false)
		return
	_main._on_training_requested()
	await _reposer(0.8)
	_mesurer_centrage("à l'entrée en entraînement")

	# Puis on le déplace : c'est le seul moyen de voir si la caméra SUIT, et
	# c'est précisément ce qui manquait.
	_main.p1.global_position += Vector2(300.0, 220.0)
	await _reposer(0.8)
	_mesurer_centrage("après un déplacement du joueur")


func _mesurer_centrage(quand: String) -> void:
	var vue: Viewport = _main.cam1.get_viewport()
	if vue == null:
		_check("la vue de la caméra existe (%s)" % quand, false)
		return
	var taille: Vector2 = vue.get_visible_rect().size
	if taille.x <= 0.0 or taille.y <= 0.0:
		_check("la vue a une taille (%s)" % quand, false)
		return
	var ecart: Vector2 = (_main.p1.global_position - _main.cam1.global_position) / taille
	_check("le joueur est au centre de sa vue, %s" % quand,
		absf(ecart.x) <= ECART_CENTRE_MAX and absf(ecart.y) <= ECART_CENTRE_MAX,
		"écart (%.2f, %.2f) de la demi-vue" % [ecart.x, ecart.y])


## **Le défaut du 2026-08-27 : en vue unique, le duel était dessiné PUIS
## RECOUVERT.** Le `Background` noir plein cadre et les deux conteneurs de vue —
## qui peignent la texture GELÉE de leur `SubViewport` — rejoignent le canvas du
## duel quand la racine en adopte le `World2D`, et se dessinent par-dessus
## l'arène. Écran entièrement noir à l'entraînement ET en ligne, des deux côtés
## du lien ; seul l'écran scindé y échappait.
##
## **Aucun état ne le trahissait.** `test_rendu_racine.gd` est resté vert de bout
## en bout — mondes, masques de cull, caméras, `update_mode` : tout était juste.
## `_entrainement_centre()`, deux fonctions plus haut, aussi : la caméra était
## parfaitement placée sur un écran où l'on ne voyait rien. Il fallait un pixel.
##
## **Et il fallait un PLANCHER.** `_arene_reste_noire()` est la seule assertion en
## pixels qui regarde l'arène, et c'est un plafond : 0,00098 le passait cent fois.
## C'est la forme exacte du trou — on savait dire « pas trop clair », jamais
## « quelque chose est là ».
##
## On lève le noir du `CanvasModulate` pour mesurer : sinon on mesure un halo de
## torche, donc l'orientation du joueur et son éblouissement, au lieu de mesurer
## si le sol arrive à l'écran. Levé, la question devient binaire.
##
## **Contre-testé le 2026-08-28** — c'est ce qui donne sa valeur au contrôle du
## cadre de droite, et ce contrôle-ci ne vaut pas moins cher : en neutralisant
## `_accorder_la_peinture_de_la_racine()`, il tombe à 0,00098 contre un plancher
## à 0,05. Il attrape donc le défaut réel, pas seulement son absence.
func _entrainement_sol_peint() -> void:
	print("\n[En vue unique, le sol arrive vraiment à l'écran]")
	if not _main._rendu_racine:
		_check("l'entraînement rend bien par la racine", false,
			"ce contrôle n'a plus de sujet — le duel repasse par son SubViewport")
		return
	var mod: CanvasModulate = _main.arena.get_node_or_null("CanvasModulate")
	if mod == null:
		_check("le CanvasModulate de l'arène est atteignable", false)
		return
	# On cherche des TUILES, pas un halo : un sol dessiné devient évident, un sol
	# recouvert reste invisible.
	var noir: Color = mod.color
	mod.color = Color.WHITE
	await _reposer(0.6)
	var img: Image = await Commun.capturer(get_tree())
	# Rendu AVANT `_arene_reste_noire()`, qui affirme l'inverse sur la même arène.
	mod.color = noir
	if img == null:
		_check("une image est lisible", false, "la fenêtre est-elle au premier plan ?")
		return
	# Zone dérivée de l'image et non écrite en dur : la fenêtre change de taille,
	# et un rectangle fixe mentirait en silence.
	var centre := img.get_size() / 2
	var zone := Rect2i(centre - Vector2i(250, 250), Vector2i(500, 500))
	var lum := Commun.luminance_moyenne(img, zone, 2)
	_check("le sol du duel n'est pas recouvert", lum >= LUMINANCE_SOL_MIN,
		"luminance moyenne %.5f au centre (recouvert : ~0,001)" % lum)
	await _reposer(0.4)


## **La promesse du jeu, et le seul de ces contrôles qui ne vienne pas d'un
## défaut : « le noir reste noir ».** Toute la conception en dépend — un effet
## qui éclaircirait le fond ne casserait aucun test, ne lèverait aucune erreur,
## et changerait le jeu.
##
## ⚠️ **Il ne se suffit pas, et il a fallu un écran noir pour s'en apercevoir.**
## C'est un plafond ; `_entrainement_sol_peint()` est son plancher. Les deux
## disent ensemble ce qu'aucun ne dit seul : sombre, mais pas vide.
func _arene_reste_noire() -> void:
	print("\n[Le noir reste noir]")
	await _reposer(0.4)
	var img: Image = await Commun.capturer(get_tree())
	if img == null:
		_check("une image est lisible", false)
		return
	# La moitié basse, hors du HUD qui est lumineux par nature.
	var taille := img.get_size()
	var zone := Rect2i(0, int(taille.y * 0.45), taille.x, int(taille.y * 0.5))
	var lum := Commun.luminance_moyenne(img, zone)
	_check("l'arène reste sombre", lum >= 0.0 and lum <= LUMINANCE_ARENE_MAX,
		"luminance moyenne %.4f" % lum)


func _reposer(secondes: float) -> void:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame


func _sortir(code: int) -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
		return
	get_tree().quit(code)
