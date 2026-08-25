extends SceneTree

## Le viseur vise-t-il, et n'y a-t-il qu'un seul pointeur ? (DA2.11)
##
## **Ce banc surveille une absence, et c'est ce qui le rend nécessaire.** DA2.11
## n'était pas un habillage : le dépôt ne contenait **aucun** viseur — zéro
## occurrence de `crosshair`, `viseur`, `reticule`, aucun
## `set_custom_mouse_cursor`, aucun réglage de `mouse_mode`. Le jeu affichait
## donc la flèche de macOS pendant les matchs, dans un jeu dont toute la
## proposition est « la seule information est la lumière ». Personne ne l'avait
## relevé en six mois parce qu'**on ne cherche pas une absence** : il n'y a pas
## de nom à grep. Une fois comblée, elle peut se re-creuser sans bruit — un
## fichier déplacé, un `visibility_layer` recopié, une sortie de menu oubliée.
##
## ## Ce qu'il MESURE sur l'image
##
## 1. **Le centre est vide.** Un viseur qui remplit son milieu masque
##    exactement ce qu'on regarde. Mesuré : vide jusqu'au rayon 16 px sur 24 de
##    demi-largeur, soit un trou de 32 px de diamètre. Plancher à 12.
## 2. **Il ne penche pas.** Les quatre quadrants pèsent 24,90 à 25,11 % de
##    l'encre — 0,11 % d'écart au quart parfait. Ce n'est pas de la coquetterie :
##    un viseur dont la masse penche d'un côté déporte la visée de qui s'y fie,
##    et personne ne saurait dire pourquoi il rate. Plafond à 1 %, neuf fois la
##    valeur observée, bien sous ce qu'un œil rattrape.
## 3. **Les coins sont à zéro.** Sinon le viseur traîne sa boîte avec lui, et
##    dans le noir absolu un carré translucide est un objet.
##
## ## Ce qu'il lit dans le TEXTE, et pourquoi c'est légitime ici
##
## Le motif vient de `test_torches.gd` et de `test_charte.gd` : **c'est par le
## texte que ces deux défauts-là reviendraient**, quelqu'un recopiant un bloc
## qui marchait ailleurs. Monter un `Player` en `--script` demanderait ses
## autoloads et son arène ; le contrôle n'existerait alors pas du tout, et
## l'absence de contrôle est le sujet même de ce banc.
##
## 4. ⚠️ **Deux couches de visibilité DISTINCTES.** L'écran partagé est
##    permanent, y compris en ligne : sans `visibility_layer` explicite — 2 pour
##    la vue de J1, 4 pour celle de J2 — le viseur de chacun s'affiche **dans
##    les deux vues**, et chaque joueur voit l'autre viser. C'est le défaut exact
##    payé sur le flash de mort le 2026-08-17.
## 5. ⚠️ **La flèche du système se dérive, elle ne s'appaire pas.** Le drapeau
##    `_is_main_menu` bascule en quatre endroits ; un masquage posé d'un côté et
##    une restauration de l'autre suffit à laisser la souris invisible **dans les
##    menus**, où plus rien ne serait cliquable. Ce banc exige que la valeur soit
##    recalculée dans `_process`, jamais posée à la sortie d'un chemin.

const VISEUR := "res://assets/viseur/viseur.png"

## Rayon vide minimal au centre, en pixels. Mesuré 16 sur l'image livrée.
const TROU_MIN := 12
## Écart maximal d'un quadrant au quart parfait. Mesuré 0,11 %.
const PENCHEMENT_MAX := 0.01

var _echecs := 0
var _total := 0


func _init() -> void:
	_test_image()
	_test_deux_vues()
	_test_une_seule_fleche()
	print("test_viseur : %d/%d" % [_total - _echecs, _total])
	quit(1 if _echecs > 0 else 0)


func _test_image() -> void:
	if not ResourceLoader.exists(VISEUR):
		_vrai("viseur present : %s" % VISEUR, false)
		return
	var tex: Texture2D = load(VISEUR)
	_vrai("viseur charge", tex != null)
	if tex == null:
		return
	var l := tex.get_width()
	var h := tex.get_height()
	_vrai("viseur carre (%dx%d)" % [l, h], l == h)
	var img := tex.get_image()
	if img == null:
		_vrai("image du viseur lisible", false)
		return

	# Le trou central : rayon du premier pixel encré.
	var cx := float(l) / 2.0 - 0.5
	var cy := float(h) / 2.0 - 0.5
	var trou := l
	var encre := 0.0
	for y in h:
		for x in l:
			var a := img.get_pixel(x, y).a
			encre = maxf(encre, a)
			if a > 0.0:
				trou = mini(trou, int(sqrt(pow(x - cx, 2.0) + pow(y - cy, 2.0))))
	_vrai("viseur non vide", encre > 0.0)
	_vrai("trou central de rayon %d px (plancher %d)" % [trou, TROU_MIN],
		trou >= TROU_MIN)

	# Le penchement : masse d'encre par quadrant.
	var q := [0.0, 0.0, 0.0, 0.0]
	for y in h:
		for x in l:
			var i := (0 if x < l / 2 else 1) + (0 if y < h / 2 else 2)
			q[i] += img.get_pixel(x, y).a
	var total: float = q[0] + q[1] + q[2] + q[3]
	if total <= 0.0:
		_vrai("viseur : encre mesurable", false)
	else:
		var pire := 0.0
		for v in q:
			pire = maxf(pire, absf(float(v) / total - 0.25))
		_vrai("viseur penche de %.2f %% (plafond %.0f %%)"
			% [pire * 100.0, PENCHEMENT_MAX * 100.0], pire <= PENCHEMENT_MAX)

	# Les coins : pas de boîte.
	var coins := (img.get_pixel(0, 0).a + img.get_pixel(l - 1, 0).a
		+ img.get_pixel(0, h - 1).a + img.get_pixel(l - 1, h - 1).a)
	_vrai("coins du viseur transparents (alpha total %.3f)" % coins,
		is_zero_approx(coins))


## Le viseur reste-t-il dans la vue de son joueur ?
func _test_deux_vues() -> void:
	var joueur := _lire("res://player.gd")
	if joueur == "":
		_vrai("player.gd lisible", false)
		return
	var i := joueur.find("func _monter_viseur")
	_vrai("player.gd monte un viseur", i >= 0)
	if i < 0:
		return
	# Le corps de la fonction : jusqu'à la prochaine déclaration en colonne 0.
	var suite := joueur.substr(i)
	var fin := suite.find("\nfunc ", 1)
	var corps := suite if fin < 0 else suite.substr(0, fin)
	# ⚠️ **On isole LA LIGNE, pas le corps.** Un `corps.contains("2")` passerait
	# au vert sur le `Vector2` d'à côté : le contrôle serait vert par accident,
	# c'est-à-dire faux. On lit l'affectation elle-même.
	var ligne := ""
	for l in corps.split("\n"):
		if l.contains("visibility_layer"):
			ligne = l
			break
	_vrai("le viseur pose un visibility_layer", ligne != "")
	# 2 = vue de J1, 4 = vue de J2. Les DEUX doivent y être : un viseur qui
	# poserait la même couche pour les deux joueurs s'afficherait dans les deux
	# vues, ce que ce banc existe pour interdire.
	_vrai("le viseur distingue les deux vues (2 et 4) — lu : %s" % ligne.strip_edges(),
		ligne.contains("2") and ligne.contains("4"))
	var monte := false
	for l in joueur.split("\n"):
		if l.contains("_monter_viseur()") and not l.contains("func "):
			monte = true
			break
	_vrai("le viseur est monte, pas seulement declare", monte)


## N'y a-t-il qu'un seul pointeur à l'écran ?
func _test_une_seule_fleche() -> void:
	var interface := _lire("res://ui.gd")
	if interface == "":
		_vrai("ui.gd lisible", false)
		return
	_vrai("ui.gd regle le mode de la souris", interface.contains("Input.mouse_mode"))
	_vrai("la fleche est masquee quelque part",
		interface.contains("MOUSE_MODE_HIDDEN"))
	_vrai("la fleche revient dans les menus",
		interface.contains("MOUSE_MODE_VISIBLE"))
	# ⚠️ Le contrôle qui compte : la valeur se recalcule à chaque image. Un
	# `Input.mouse_mode = ...` posé au fil des chemins de sortie, sans dérivation
	# dans `_process`, est précisément la forme qui laisse la souris invisible
	# dans les menus le jour où un chemin est oublié.
	var i := interface.find("func _suivre_le_curseur_systeme")
	_vrai("la fleche se derive dans une fonction dediee", i >= 0)
	# ⚠️ **Chercher le nom ne suffit pas : la ligne `func` le contient déjà.**
	# Premier jet de ce banc — `interface.contains("_suivre_le_curseur_systeme()")`
	# — vert même après avoir retiré l'appel de `_process`, donc incapable
	# d'échouer tant que la fonction existe. On exige l'APPEL : une ligne
	# indentée qui n'est pas la déclaration.
	var appelee := false
	for l in interface.split("\n"):
		if l.contains("_suivre_le_curseur_systeme()") and not l.contains("func "):
			appelee = true
			break
	_vrai("la derivation est appelee, pas seulement declaree", appelee)
	if i >= 0:
		var suite := interface.substr(i)
		var fin := suite.find("\nfunc ", 1)
		var corps := suite if fin < 0 else suite.substr(0, fin)
		_vrai("la derivation lit l'ecran affiche", corps.contains("_is_main_menu"))


func _lire(chemin: String) -> String:
	var f := FileAccess.open(chemin, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _vrai(quoi: String, ok: bool) -> void:
	_total += 1
	if not ok:
		_echecs += 1
		printerr("  ÉCHEC %s" % quoi)
