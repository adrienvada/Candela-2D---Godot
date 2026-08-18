class_name RenduCommun
extends RefCounted

## Ce que la planche de contact et les contrôles de rendu ont en commun.
##
## ## Pourquoi ces deux outils existent
##
## Le dépôt compte quarante-deux suites headless, six scénarios à deux instances,
## des contrôles sur des états, des comptes, des transitions — et **rien du tout
## sur ce qui s'affiche**. En deux jours, deux défauts purement visuels sont
## passés au travers : un cadre de menu entièrement noir, et un joueur planté en
## bas de l'écran avec une caméra qui ne le suivait pas. Les deux ont été trouvés
## par Adrien, à l'œil.
##
## La formule de la session voisine, qui résume les deux : **on mesure ce qui
## s'écrit, pas ce qui se voit.**
##
## ## Pourquoi ils ne peuvent pas rejoindre le lanceur
##
## `--headless` ne rastérise rien : `RenderingServer.frame_post_draw` n'y est
## **jamais émis** et l'attendre suspend le processus pour toujours (piège déjà
## payé sur la séquence de fin). Ces deux outils exigent donc une vraie fenêtre,
## et se lancent à part — avant une livraison, pas à chaque commit.
##
## **Ils refusent de tourner en headless plutôt que d'y pendre.** C'est la règle
## tirée du banc de cadence : un outil qui ne peut pas travailler doit le dire et
## sortir, jamais rester ouvert à ne rien faire.

## Un outil de rendu peut-il travailler ici ? Rend la raison, ou une chaîne vide.
static func refus_headless() -> String:
	if DisplayServer.get_name() == "headless":
		return "le serveur d'affichage est 'headless' : rien n'est rastérisé, " \
			+ "aucune image ne peut être lue et `frame_post_draw` n'est jamais émis"
	return ""

## Les appuis de ces outils sur le jeu, vérifiables avant de rendre quoi que ce
## soit. Même discipline que `bench_framerate.preconditions_manquantes()` : un
## outil hors couverture se périme en silence, donc il nomme ce dont il dépend.
static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents
	for prop in ["hub", "game_over_panel"]:
		if not prop in ui:
			absents.append("UI.%s a disparu" % prop)
	for methode in ["show_main_menu"]:
		if not ui.has_method(methode):
			absents.append("UI.%s() a disparu" % methode)
	for prop in ["p1", "cam1", "training_mode"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	if not main.has_method("_on_training_requested"):
		absents.append("GameState._on_training_requested() a disparu")
	var hub = ui.get("hub") if "hub" in ui else null
	if hub == null:
		absents.append("UI.hub est nul")
	elif not hub.has_method("push") or not hub.has_method("has_screen"):
		absents.append("MenuHub.push()/has_screen() ont disparu")
	return absents

## L'image de la frame réellement affichée, ou `null` si elle ne vient pas.
##
## `frame_post_draw` et non `process_frame` : la seconde rend la main **avant**
## que le rendu ait eu lieu, et l'image lue serait celle d'avant. C'est la même
## erreur d'un cran que lire une valeur après avoir lancé son fondu.
##
## **Et sous budget, jamais en attente nue.** macOS bride le rendu d'une fenêtre
## qui n'est pas au premier plan — au point que `frame_post_draw` peut ne plus
## venir du tout. Un `await` nu suspend alors l'outil pour toujours, et c'est le
## pire des trois états connus : une suite rouge crie, une suite absente ne dit
## rien, **une suite qui pend ne dit rien ET bloque tout ce qui suit**. Rendre
## `null` laisse l'appelant le dire et continuer.
static func capturer(arbre: SceneTree, budget_ms: int = 4000) -> Image:
	var rendu := [false]
	var cb := func() -> void: rendu[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var fin := Time.get_ticks_msec() + budget_ms
	while not rendu[0] and Time.get_ticks_msec() < fin:
		await arbre.process_frame
	if not rendu[0]:
		if RenderingServer.frame_post_draw.is_connected(cb):
			RenderingServer.frame_post_draw.disconnect(cb)
		return null
	var texture := arbre.root.get_texture()
	return texture.get_image() if texture != null else null

## Luminance moyenne d'une région, en 0..1. `zone` est en pixels d'écran.
##
## Échantillonnée en grille plutôt que pixel à pixel : sur une région de menu, mille
## points disent la même chose qu'un million et se lisent en une milliseconde.
static func luminance_moyenne(img: Image, zone: Rect2i, pas: int = 4) -> float:
	if img == null:
		return -1.0
	var cadre := Rect2i(Vector2i.ZERO, img.get_size())
	zone = zone.intersection(cadre)
	if zone.size.x <= 0 or zone.size.y <= 0:
		return -1.0
	var total := 0.0
	var n := 0
	var y := zone.position.y
	while y < zone.end.y:
		var x := zone.position.x
		while x < zone.end.x:
			var c := img.get_pixel(x, y)
			# Luminance perceptuelle : le vert pèse davantage que le bleu, et dans
			# un jeu qui joue le cyan contre le rouge, une moyenne naïve dirait que
			# le territoire de J2 est plus sombre que celui de J1.
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
			x += pas
		y += pas
	return total / float(n) if n > 0 else -1.0

## Écart-type de la luminance d'une région. **C'est lui qui distingue « noir » de
## « vide »** : un cadre éteint et un cadre plein de texte peuvent avoir la même
## moyenne, jamais la même dispersion.
static func contraste(img: Image, zone: Rect2i, pas: int = 4) -> float:
	if img == null:
		return -1.0
	var moyenne := luminance_moyenne(img, zone, pas)
	if moyenne < 0.0:
		return -1.0
	var cadre := Rect2i(Vector2i.ZERO, img.get_size())
	zone = zone.intersection(cadre)
	var somme := 0.0
	var n := 0
	var y := zone.position.y
	while y < zone.end.y:
		var x := zone.position.x
		while x < zone.end.x:
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			somme += (l - moyenne) * (l - moyenne)
			n += 1
			x += pas
		y += pas
	return sqrt(somme / float(n)) if n > 0 else -1.0
