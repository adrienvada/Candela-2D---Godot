extends SceneTree

## Les masques peints des lumières tiennent-ils leurs invariants ? (DA2.2, DA2.3)
##
## **Ce banc existe parce qu'un commentaire l'a promis avant qu'il n'existe.**
## `light_textures.gd::poser()` affirme que « personne d'autre ne doit écrire
## `texture_scale` sur une lumière peinte — `tools/test_lumieres.gd` l'exige ».
## La phrase a été écrite le 2026-08-24 alors que le fichier n'existait pas :
## une garantie qui ne tenait à rien, c'est-à-dire la cinquième forme de faux
## vert relevée cette nuit-là. Ce fichier la relie.
##
## ## Ce qu'il vérifie, et pourquoi ces quatre-là
##
## 1. **Les masques chargent.** Un PNG cuit mais pas importé par Godot est
##    invisible à `ResourceLoader`, et `poser()` se rabat alors sur le dégradé
##    — en criant, mais le jeu tourne. Le contrôle attrape l'oubli d'import.
## 2. **Le coin est noir.** C'est l'invariant propre aux halos, qui n'existait
##    pas pour les cookies de torche : un masque radial est lu tel quel, donc
##    une planche encore claire dans ses angles ferait un **carré lumineux** en
##    plein jeu. Mesuré à la cuisson, exigé ici.
## 3. **`poser()` tient l'empreinte**, quelle que soit la résolution du fichier.
##    C'est le piège de DA2.1 rendu mécanique : recuire en 512² ne devra rien
##    déplacer.
## 4. **Aucun fichier de jeu n'écrit `texture_scale` sur une lumière peinte.**
##    Contrôle sur le TEXTE, comme `test_torches` et `test_charte` : c'est par
##    le texte que le défaut reviendrait, quelqu'un recopiant une ligne qui
##    marchait ailleurs.
##
## Ce qu'il ne vérifie PAS : que les masques soient beaux. Adrien les a choisis
## à l'écran le 2026-08-24 ; ce banc n'a d'avis que sur leurs propriétés.

const LT := preload("res://light_textures.gd")

## Les lumières peintes et l'empreinte que chacune doit tenir.
const ATTENDUS := [
	["RETRODIFFUSION", LT.RETRODIFFUSION, LT.EMPREINTE_RETRODIFFUSION],
	["AMBIANTE", LT.AMBIANTE, LT.EMPREINTE_AMBIANTE],
	["ECLAT", LT.ECLAT, 256.0],
]

## Les lumières dont l'échelle passe obligatoirement par `poser()`. La torche est
## absente **et c'est voulu** : son échelle vient de `WeaponData.echelle_torche()`,
## garantie par `test_torches.gd`. Deux chemins, deux gardiens, aucun trou.
const PEINTES := ["body_light", "ambient_light", "muzzle_flash", "ground_flash", "hit_light"]

var _echecs := 0
var _total := 0


func _init() -> void:
	var chemins: Array = []
	for a in ATTENDUS:
		chemins.append([a[0], a[1]])
	for i in LT.FLASH.size():
		chemins.append(["FLASH[%d]" % i, LT.FLASH[i]])

	for c in chemins:
		var nom: String = c[0]
		var chemin: String = c[1]
		_vrai("%s : present (%s)" % [nom, chemin.get_file()], ResourceLoader.exists(chemin))
		if not ResourceLoader.exists(chemin):
			continue
		var tex: Texture2D = load(chemin)
		_vrai("%s : charge" % nom, tex != null)
		if tex == null:
			continue
		_vrai("%s : carre (%dx%d)" % [nom, tex.get_width(), tex.get_height()],
			tex.get_width() == tex.get_height())
		_coin_noir(nom, tex)

	_test_empreinte()
	_test_personne_ne_choisit_l_echelle()

	print("test_lumieres : %d/%d" % [_total - _echecs, _total])
	quit(1 if _echecs > 0 else 0)


## Les quatre coins, hors du disque inscrit, doivent être à alpha 0.
##
## Le seuil est **zéro strict, pas « faible »** : la cuisson met exactement 0
## hors du disque (`anneaux[i] == -1`), donc toute valeur non nulle signale que
## le fichier n'a pas été produit par `fabrique_cookies.gd --mode radial` — un
## PNG déposé à la main, par exemple.
func _coin_noir(nom: String, tex: Texture2D) -> void:
	var img := tex.get_image()
	if img == null:
		_vrai("%s : image lisible" % nom, false)
		return
	if img.is_compressed():
		img.decompress()
	var n := img.get_width()
	var pire := 0.0
	for p in [Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		pire = maxf(pire, img.get_pixel(p.x, p.y).a)
	_vrai("%s : coins a %.3f d'alpha (exige 0)" % [nom, pire], pire == 0.0)


## `poser()` doit rendre l'empreinte au sol indépendante de la résolution.
func _test_empreinte() -> void:
	for a in ATTENDUS:
		var nom: String = a[0]
		var chemin: String = a[1]
		if not ResourceLoader.exists(chemin):
			continue
		for empreinte in [64.0, 150.0, 256.0, 400.0]:
			var l := PointLight2D.new()
			LT.poser(l, chemin, empreinte)
			var au_sol := float(l.texture.get_width()) * l.texture_scale
			_vrai("%s : empreinte %d rendue %.1f" % [nom, int(empreinte), au_sol],
				is_equal_approx(au_sol, empreinte))
			l.free()


## Aucun fichier de jeu ne règle `texture_scale` sur une lumière peinte.
func _test_personne_ne_choisit_l_echelle() -> void:
	for fichier in ["res://player.gd", "res://particle_pool.gd", "res://game_state.gd"]:
		var f := FileAccess.open(fichier, FileAccess.READ)
		if f == null:
			continue
		var texte := f.get_as_text()
		for lumiere in PEINTES:
			_vrai("%s ne regle pas %s.texture_scale" % [fichier.get_file(), lumiere],
				not texte.contains("%s.texture_scale" % lumiere))


func _vrai(quoi: String, ok: bool) -> void:
	_total += 1
	if not ok:
		_echecs += 1
		printerr("  ÉCHEC %s" % quoi)
