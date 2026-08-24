extends SceneTree

## Les torches disent-elles la même chose dans les deux endroits qui les portent ?
##
## **Ce banc existe parce que j'ai créé la divergence qu'il surveille.** Les
## portées arbitrées par Adrien le 2026-08-24 ont d'abord vécu dans
## `tools/torches.gd` — table d'outillage, partagée par la cuisson et l'aperçu —
## pendant que `game_state.gd` portait encore les anciennes. Le banc d'aperçu
## affichait donc autre chose que le jeu, et rien ne l'aurait dit une fois
## l'avertissement retiré de l'étiquette.
##
## Les deux ne peuvent pas fusionner : `game_state.gd` construit ses armes
## impérativement et nomme des autoloads, donc ne se charge pas en `--script`
## (piège consigné le 2026-08-18). La table d'outillage doit rester lisible hors
## du jeu. **Deux copies sont donc inévitables ; leur divergence ne l'est pas.**
##
## ## Ce qu'il vérifie, et pourquoi ainsi
##
## Il lit le **TEXTE** de `game_state.gd` et de `weapon_data.gd`, pas leurs
## valeurs exportées — c'est le motif de `test_charte.gd` pour le vert dans
## l'arène. La raison est la même : c'est par le texte que le défaut arriverait,
## quelqu'un changeant un `torch_scale` à la main sans penser à l'outillage.
##
## Le pistolet est le cas particulier qui compte : `game_state.gd` ne lui écrit
## rien, il hérite des défauts de `WeaponData`. C'est délibéré — une valeur posée
## deux fois finit par différer — mais ça veut dire que ses nombres se lisent
## dans l'autre fichier.
##
## ## Ce qu'il ne vérifie pas
##
## Que les valeurs soient BONNES. Elles relèvent d'un arbitrage d'Adrien, pas
## d'une mesure. Ce banc n'a d'avis que sur leur égalité — c'est une **égalité
## exigée**, la forme de contrôle qui attrape ce qui est resté identique alors
## que ça aurait dû bouger, et l'inverse.

const Torches := preload("res://tools/torches.gd")
const WD := preload("res://weapon_data.gd")

## Penchement haut/bas maximal toléré sur un cookie. Voir `_test_penchement()`
## pour la dérivation : au-dessus du plancher du procédé (0,25 %), sous le seuil
## de perception (1 à 2 % au mieux, bien pire dans le noir).
const PENCHEMENT_MAX := 0.01

var _echecs := 0
var _total := 0


func _init() -> void:
	var jeu := _lire("res://game_state.gd")
	var arme := _lire("res://weapon_data.gd")
	if jeu == "" or arme == "":
		printerr("test_torches : fichier source illisible")
		quit(1)
		return

	for t in Torches.ARMES:
		var fichier: String = t["fichier"]
		if fichier == "pistolet":
			# Pas de ligne dans `game_state.gd` : il hérite des défauts.
			_egal(fichier, "angle", t["angle"],
				_nombre(arme, "@export var torch_angle_deg: float = "))
			_egal(fichier, "echelle", t["echelle"],
				_nombre(arme, "@export var torch_scale: float = "))
			_egal(fichier, "brillance", t["brillance"],
				_nombre(arme, "@export var torch_brightness: float = "))
			_vrai("pistolet : cookie par défaut nommé",
				arme.contains('@export var torch_cookie: String = "pistolet"'))
			continue

		var prefixe := "weapon_%s." % fichier
		_egal(fichier, "angle", t["angle"], _nombre(jeu, prefixe + "torch_angle_deg = "))
		_egal(fichier, "echelle", t["echelle"], _nombre(jeu, prefixe + "torch_scale = "))
		_vrai("%s : cookie nommé dans game_state" % fichier,
			jeu.contains('%storch_cookie = "%s"' % [prefixe, fichier]))
		# `torch_brightness` n'est écrit que là où il n'est pas 1,0.
		var b: float = t["brillance"]
		if not is_equal_approx(b, 1.0):
			_egal(fichier, "brillance", b, _nombre(jeu, prefixe + "torch_brightness = "))

	# Le cookie cuit doit exister, sinon la torche est un carré lumineux.
	for t in Torches.ARMES:
		var chemin := "res://assets/torche/cookie_%s.png" % t["fichier"]
		_vrai("cookie present : %s" % chemin.get_file(), ResourceLoader.exists(chemin))

	# ⚠️ **Qu'un fichier existe ne dit pas que le code sait le charger.** Le
	# premier jet de ce banc s'arrêtait à `ResourceLoader.exists()` : il aurait
	# passé au vert avec un `torch_cookie` mal orthographié, un import manquant
	# ou une méthode qui rend `null`. On exerce donc le vrai chemin —
	# `get_torch_texture()` puis `echelle_torche()` — sur les quatre armes.
	#
	# `WeaponData` est une `Resource` sans autoload : elle se charge en
	# `--script`, contrairement à `game_state.gd`. C'est ce qui rend ce contrôle
	# possible ici plutôt qu'en jeu, où il n'aurait jamais été écrit.
	for t in Torches.ARMES:
		var w := WD.new()
		w.torch_cookie = t["fichier"]
		w.torch_scale = t["echelle"]
		var tex := w.get_torch_texture()
		_vrai("%s : texture chargee" % t["fichier"], tex != null)
		if tex == null:
			continue
		_vrai("%s : cookie carre" % t["fichier"], tex.get_width() == tex.get_height())
		# L'empreinte au sol, en unités de monde, doit valoir `512 x torch_scale`
		# quelle que soit la résolution du fichier. C'est le piège de la portée,
		# rendu mécanique : recuire en 2048² ne devra rien déplacer.
		var empreinte := float(tex.get_width()) * w.echelle_torche()
		var attendue: float = WD.TAILLE_COOKIE_REFERENCE * float(t["echelle"])
		_vrai("%s : empreinte %d au lieu de %d" % [t["fichier"], empreinte, attendue],
			is_equal_approx(empreinte, attendue))

	_test_penchement()
	_test_personne_ne_choisit_l_echelle(jeu)

	print("test_torches : %d/%d" % [_total - _echecs, _total])
	quit(1 if _echecs > 0 else 0)


## Un cookie penche-t-il d'un côté ?
##
## **`test_vision.gd` le dit depuis le premier jour : « un faisceau qui
## pencherait d'un côté serait un avantage muet pour qui tourne dans le bon
## sens ».** C'était garanti tant que la texture était calculée — la formule
## emploie `abs(angle)`, donc la symétrie était une propriété de la
## construction. **Un cookie peint ne la garantit plus par rien.**
##
## Mesuré sur les quatre cookies actuels : ils penchent de 0,22 à 0,25 %, la
## moitié haute étant la plus claire. C'est le plancher qu'impose la planche
## source, elle-même asymétrique.
##
## ## Le seuil, et d'où il sort
##
## **1 %**, et il n'est pas choisi au doigt mouillé :
##
## - **le plancher observé est 0,25 %.** Un seuil doit passer au-dessus, sinon
##   il rougit sur ce que le procédé produit normalement — quatre fois la marge ;
## - **le plafond est perceptuel.** La loi de Weber situe le plus petit écart de
##   luminance discernable autour de 1 à 2 % dans de bonnes conditions ; dans le
##   noir quasi total où se joue Candela, il est bien pire. Un seuil à 1 % rougit
##   donc **avant** que quiconque puisse en tirer un avantage.
##
## Ce que ce contrôle attrape n'est pas le cookie d'aujourd'hui : c'est le
## suivant. Une planche peinte à la main, un skin de DA7.6, une génération
## refaite — rien de tout ça n'est symétrique par construction, et rien ne le
## dirait. **Il date le moment où un asset cesse d'être neutre.**
func _test_penchement() -> void:
	for t in Torches.ARMES:
		var w := WD.new()
		w.torch_cookie = t["fichier"]
		var img := w.image_torche()
		if img == null:
			_vrai("%s : image lisible pour le penchement" % t["fichier"], false)
			continue
		var h := img.get_height()
		var l := img.get_width()
		var haut := 0.0
		var bas := 0.0
		# Une grille suffit : on cherche un biais d'ensemble, pas un pixel.
		var pas := maxi(1, l / 256)
		for y in range(0, h / 2, pas):
			for x in range(0, l, pas):
				haut += img.get_pixel(x, y).a
				bas += img.get_pixel(x, h - 1 - y).a
		var total := haut + bas
		if total <= 0.0:
			_vrai("%s : cookie non vide" % t["fichier"], false)
			continue
		var penche: float = absf(haut - bas) / total * 2.0
		_vrai("%s : penche de %.2f %% (plafond %.0f %%)"
			% [t["fichier"], penche * 100.0, PENCHEMENT_MAX * 100.0],
			penche <= PENCHEMENT_MAX)


## Personne ne choisit l'échelle d'échantillonnage à la place de l'arme.
##
## ⚠️ **Le même défaut s'est produit TROIS FOIS le 2026-08-24**, dans
## `game_state.gd`, `tools/test_vision.gd` et `tools/planche_eblouissement.gd` :
## chacun passait `torch_scale` à `Vision.intensite_texture()` là où le rendu
## emploie `echelle_torche()`. Identiques jusqu'aux cookies 1024², simple et
## double depuis.
##
## `WeaponData.lumiere_recue()` a fermé la cause en cessant de poser la question.
## Ce contrôle ferme la porte : **un fichier de jeu ne doit plus appeler
## `intensite_texture` directement.** Les bancs le peuvent — `test_vision`
## éprouve la primitive elle-même, et c'est légitime : il lui passe des échelles
## artificielles pour vérifier qu'elle en tient compte.
##
## Contrôle sur le TEXTE, comme le vert interdit dans l'arène de `test_charte` :
## c'est par le texte que le défaut reviendrait, quelqu'un recopiant un appel
## qui marchait ailleurs.
func _test_personne_ne_choisit_l_echelle(jeu: String) -> void:
	_vrai("game_state n'appelle plus intensite_texture directement",
		not jeu.contains("Vision.intensite_texture("))
	var planche := _lire("res://tools/planche_eblouissement.gd")
	if planche != "":
		_vrai("la planche d'éblouissement passe par l'arme",
			not planche.contains("Vision.intensite_texture("))


func _lire(chemin: String) -> String:
	var f := FileAccess.open(chemin, FileAccess.READ)
	return "" if f == null else f.get_as_text()


## Premier nombre qui suit `cle` dans le texte. Rend NAN si la clé est absente —
## une clé disparue doit échouer, pas passer silencieusement pour un zéro.
func _nombre(texte: String, cle: String) -> float:
	var i := texte.find(cle)
	if i < 0:
		return NAN
	var reste := texte.substr(i + cle.length(), 24)
	var brut := ""
	for c in reste:
		if c.is_valid_int() or c == "." or (brut == "" and c == "-"):
			brut += c
		else:
			break
	return NAN if brut == "" else float(brut)


func _egal(arme: String, champ: String, attendu: float, trouve: float) -> void:
	_total += 1
	if is_nan(trouve):
		_echecs += 1
		printerr("  ÉCHEC %s.%s : introuvable dans la source" % [arme, champ])
	elif not is_equal_approx(attendu, trouve):
		_echecs += 1
		printerr("  ÉCHEC %s.%s : torches.gd dit %s, la source dit %s"
			% [arme, champ, attendu, trouve])


func _vrai(quoi: String, ok: bool) -> void:
	_total += 1
	if not ok:
		_echecs += 1
		printerr("  ÉCHEC %s" % quoi)
