extends SceneTree

## La planche de marche — ce qui a été validé à l'œil, tenu par la mesure.
##
## Lancer : godot --headless --path . --script res://tools/test_planche_marche.gd
##
## ## Pourquoi cette suite existe
##
## Adrien a validé les 32 planches `*_marche_*.png` au banc le 2026-08-27, après
## qu'une session les a régénérées sur cinq contraintes. Quatre de ces cinq ont
## été vérifiées **à la main**, une seule fois, dans une session qui s'est
## terminée. **Rien ne les tenait.** Une régénération, une retouche, une
## recuisson : les quatre garanties tombaient sans qu'une ligne ne rougisse, et
## la validation d'Adrien reposait sur des mesures qui n'existaient nulle part
## dans le dépôt.
##
## Les trois tentatives précédentes avaient toutes été rendues comme des succès.
## C'est la raison d'être de ce fichier : **un lot d'images ne se déclare pas
## conforme, il se mesure.**
##
## ## La référence est le SPRITE STATIQUE, jamais un nombre
##
## Aucune dimension n'est écrite ici. Chaque pose est comparée au
## `<arme>.png` correspondant, relu à l'exécution. C'est ce qui fait que cette
## suite survit à la recuisson ×2 décidée le 2026-08-25 : le jour où les statiques
## doubleront, elle exigera que les planches doublent avec eux, sans qu'on ait
## rien à réécrire. Un nombre figé ici serait la même faute que le seuil `6` de
## `test_audit_menus`, qui comptait une action sans jamais la nommer.
##
## ⚠️ **Un échec peut donc accuser le statique et non la planche.** Chaque message
## nomme les DEUX valeurs pour qu'on voie tout de suite laquelle a bougé — sans
## quoi cette suite rougirait au nom d'un innocent, ce que la ROADMAP a déjà
## consigné deux fois.
##
## ## Les images sont lues SUR LE DISQUE, pas à travers le cache d'import
##
## Premier jet : `load()` puis `get_image()`, pour voir « ce que le jeu verra » et
## attraper au passage un réglage d'import fautif. **Écarté, et le contre-exemple
## est le meilleur argument :** le cache d'import ne rend que ce qui a été importé
## la dernière fois. Quelqu'un qui régénère les 32 planches et lance la suite sans
## réimporter obtiendrait un **vert sur les anciennes images** — la suite
## validerait exactement le lot qu'elle est censée refuser, et le dirait avec
## aplomb.
##
## On lit donc les octets du fichier et on les décode en mémoire — le fichier tel
## qu'il est maintenant. Le cache d'import, lui, est déjà couvert par
## `test_sprites`, qui passe par `load()` : les deux chemins sont tenus, chacun
## par la suite dont c'est le sujet.
##
## ⚠️ **Pas `Image.load_from_file()` non plus**, bien qu'il lise le disque : il
## émet un avertissement par appel — « this will not work on export » — soit 96
## lignes et 96 traces d'appel pour un lot vert. Un contrôle qui hurle en
## réussissant apprend au lecteur à ne plus lire sa sortie, et c'est ce qui rend
## un vrai cri invisible le jour où il arrive.
##
## ## Ce qui n'est PAS vérifié ici, et ne peut pas l'être
##
## La caméra — vue de dessus stricte contre trois-quarts — et la beauté. Ce sont
## les deux choses qui se jugent à l'œil, au banc `tools/banc_marche.tscn`. Cette
## suite tient ce qui est mesurable ; elle ne remplace pas le regard d'Adrien,
## elle l'empêche d'être annulé en silence.

const ARMES := ["pistolet", "pompe", "fusil", "arbalete"]
const POSES := 4
const SPRITES := "res://assets/sprites/"

## Seuil d'opacité au-delà duquel un pixel « existe ». Bas exprès : on cherche
## l'étendue de ce qui se VOIT, pas la silhouette pleine. L'occluder de
## `player.gd`, lui, coupe à 0,35 parce qu'il cherche un corps qui arrête la
## lumière — deux questions différentes, deux seuils différents, et c'est normal.
const SEUIL_ALPHA := 0.06

var _echecs := 0
var _total := 0


func _init() -> void:
	_juger_le_cablage()
	for arme in ARMES:
		var statique := _image(SPRITES + arme + ".png")
		var statique_sil := _image(SPRITES + arme + "_silhouette.png")
		if statique == null or statique_sil == null:
			_vrai("%s : sprite statique lisible (la référence de tout le reste)" % arme, false)
			continue
		var ref := _bout_de_canon(statique)
		for n in range(1, POSES + 1):
			_juger(arme, n, statique, ref)
	_verdict()


func _juger(arme: String, n: int, statique: Image, ref: Dictionary) -> void:
	var nom := "%s_marche_%d" % [arme, n]
	var peint := _image(SPRITES + nom + ".png")
	var sil := _image(SPRITES + nom + "_silhouette.png")

	# 1 — COMPLÉTUDE. Une pose absente ne doit pas se lire comme une pose juste :
	# sans ce contrôle, tout le reste serait sauté en silence pour ce nom-là.
	_vrai("%s : la pose et sa silhouette existent" % nom, peint != null and sil != null)
	if peint == null or sil == null:
		return

	# 2 — ÉCHELLE. Le lot rejeté faisait 56 px pour trois armes sur quatre là où
	# les statiques s'échelonnent de 56 à 82. Ce n'était pas une taille fausse :
	# c'était **l'échelonnement des armes qui disparaissait**, et lire l'arme
	# adverse décide du duel. Le joueur devenait illisible pendant qu'il marche.
	_vrai("%s : %dx%d au lieu de %dx%d (celle du statique)"
			% [nom, peint.get_width(), peint.get_height(),
				statique.get_width(), statique.get_height()],
		peint.get_width() == statique.get_width()
			and peint.get_height() == statique.get_height())

	# 3 — L'ARME NE PIVOTE PAS, ET SA PORTÉE EST INTACTE.
	#
	# ⚠️ **C'est le seul contrôle qui remplace un œil, et c'est l'obstacle qui
	# avait écarté la planche précédente.** `rotation` dit où le joueur vise :
	# c'est l'information la plus chère du jeu. Une arme peinte inclinée la
	# contredit douze fois par seconde, et **ça ne se voit pas sur une image
	# fixe** — il faut la comparer au statique.
	#
	# Le bout du canon est le pixel opaque le plus AVANT (axe +X, l'axe de visée).
	# Deux grandeurs, et il faut les deux : son abscisse dit la PORTÉE, son
	# centre en Y dit le PIVOT. Une arme inclinée garderait la première et
	# perdrait la seconde.
	#
	# Zéro écart toléré, parce que zéro est ce qui a été mesuré le 2026-08-27.
	# Une tolérance qu'on ne sait pas justifier est une porte qu'on laisse ouverte.
	#
	# ⚠️ **Seul CE contrôle-ci se saute quand la taille est fausse**, et rien
	# d'autre : comparer deux abscisses sur deux toiles de tailles différentes ne
	# veut rien dire. Le magenta et la silhouette, eux, ne dépendent pas de la
	# taille — les sauter aussi ferait rendre la moitié des défauts par lot, et
	# on découvrirait le second en réparant le premier. **Un contrôle rend tout
	# ce qu'il peut voir en une passe**, sinon il transforme une correction en
	# série de manches.
	if peint.get_width() == statique.get_width():
		var bout := _bout_de_canon(peint)
		_vrai("%s : bout du canon en x=%d au lieu de %d — la portée a bougé"
				% [nom, bout["x"], ref["x"]], bout["x"] == ref["x"])
		_vrai("%s : bout du canon centré en y=%.1f au lieu de %.1f — l'arme a pivoté"
				% [nom, bout["y"], ref["y"]], is_equal_approx(bout["y"], ref["y"]))

	# 4 — PROPRETÉ. Le lot rejeté portait des bavures magenta cuites dans l'image,
	# reste du générateur. Elles se voient à l'œil nu — mais personne ne regarde
	# les 32 planches une par une à chaque régénération.
	var magenta := _pixels_magenta(peint)
	_vrai("%s : %d pixel(s) magenta — résidu de génération" % [nom, magenta],
		magenta == 0)

	# 5 — LA SILHOUETTE ÉPOUSE LE PEINT.
	#
	# ⚠️ Ce n'est pas une redondance : la silhouette alimente l'occluder de
	# lumière ET la vue que l'ADVERSAIRE a de vous. Une silhouette qui déborde
	# projette une ombre que le corps ne justifie pas ; une silhouette en retrait
	# laisse passer la lumière à travers un morceau de joueur. Dans un jeu dont
	# toute l'information est la lumière, c'est une information fausse.
	var ecart := _ecart_de_masque(peint, sil)
	_vrai("%s : %d pixel(s) d'écart entre la silhouette et le peint" % [nom, ecart],
		ecart == 0)


## Le câblage, lu dans le TEXTE de `player.gd`.
##
## ⚠️ **Par le texte, parce qu'il n'y a pas d'autre chemin.** `player.gd` nomme
## des autoloads : le charger ici sortirait « Identifier not found:
## NetworkManager », piège consigné le 2026-08-18 et déjà contourné de la même
## façon par `test_sprites` et `test_torches`. Et surtout : **le lot ne rend
## rien**. Aucune suite ne dessine, donc rien d'autre ne peut dire que la planche
## est effectivement posée sur les cinq vues — un câblage retiré passerait tous
## les contrôles du dépôt en silence.
func _juger_le_cablage() -> void:
	var src := FileAccess.get_file_as_string("res://player.gd")
	if src.is_empty():
		_vrai("player.gd lisible", false)
		return

	# 1 — La planche est bien chargée. Sans ce contrôle, câbler puis décâbler ne
	# se verrait nulle part : les 32 images resteraient vertes, inutilisées.
	_vrai("player.gd charge les quatre poses de la planche",
		src.contains("_marche_%d.png") and src.contains("_marche_%d_silhouette.png"))

	# 2 — ⚠️ **L'occluder ne se recalcule PAS par pose**, et c'est la décision du
	# chantier. Le refaire à chaque pas coûterait un décodage d'image et 32 rayons
	# plusieurs fois par seconde — mais surtout l'ombre portée changerait de forme
	# quatre fois par cycle, ce qui se lirait comme un défaut. Un seul appel dans
	# tout le fichier : celui du changement d'arme.
	_vrai("l'occluder n'est accordé qu'une fois, au changement d'arme (%d appel(s))"
			% src.count("_accorder_occluder_a_la_silhouette("),
		src.count("_accorder_occluder_a_la_silhouette(") == 2)

	# 3 — ⚠️ **L'échange de pose ne reconstruit ni quad ni UV**, et c'est ce qui
	# rend le câblage bon marché : `_calculate_uvs()` dérive les UV des bornes du
	# POLYGONE, donc tant que la pose a les dimensions du statique — ce que cette
	# suite exige par ailleurs — poser la texture suffit. Quelqu'un qui
	# « réparerait » ça en rajoutant un recalcul paierait cinq recalculs par pas,
	# pour rien, et personne ne relierait la perte de cadence à ce geste.
	var corps := _corps_de(src, "func _poser_pose(")
	_vrai("`_poser_pose` existe dans player.gd", corps != "")
	if corps != "":
		_vrai("`_poser_pose` ne recalcule ni quad ni UV",
			not corps.contains("_calculate_uvs") and not corps.contains(".polygon ="))


## Le corps d'une fonction : de sa signature à la prochaine ligne non indentée.
func _corps_de(src: String, signature: String) -> String:
	var d := src.find(signature)
	if d < 0:
		return ""
	var sortie := ""
	var lignes := src.substr(d).split("\n")
	for i in lignes.size():
		var l: String = lignes[i]
		if i > 0 and l != "" and not l.begins_with("\t"):
			break
		sortie += l + "\n"
	return sortie


## Le pixel opaque le plus avant, et le centre vertical de la colonne qu'il occupe.
func _bout_de_canon(img: Image) -> Dictionary:
	var l := img.get_width()
	var h := img.get_height()
	for x in range(l - 1, -1, -1):
		var ys := PackedInt32Array()
		for y in h:
			if img.get_pixel(x, y).a > SEUIL_ALPHA:
				ys.append(y)
		if ys.size() > 0:
			return {"x": x, "y": (float(ys[0]) + float(ys[ys.size() - 1])) * 0.5}
	return {"x": -1, "y": -1.0}


## Magenta : rouge et bleu francs, vert nettement en retrait des deux. Les écarts
## sont larges — on cherche une bavure de générateur, pas une teinte de la charte.
func _pixels_magenta(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > SEUIL_ALPHA and c.r > 0.43 and c.b > 0.43 \
					and c.g < c.r - 0.18 and c.g < c.b - 0.18:
				n += 1
	return n


## Nombre de pixels où l'un est opaque et l'autre non — dans les deux sens.
func _ecart_de_masque(a: Image, b: Image) -> int:
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return a.get_width() * a.get_height()
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if (a.get_pixel(x, y).a > SEUIL_ALPHA) != (b.get_pixel(x, y).a > SEUIL_ALPHA):
				n += 1
	return n


## Rend `null` plutôt que de crier : l'absence est un cas que le contrôle n°1
## nomme, et un `push_error` ici doublerait le message sans rien apprendre.
func _image(chemin: String) -> Image:
	if not FileAccess.file_exists(chemin):
		return null
	var octets := FileAccess.get_file_as_bytes(chemin)
	if octets.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(octets) != OK:
		return null
	return img


func _vrai(quoi: String, ok: bool) -> void:
	_total += 1
	if not ok:
		_echecs += 1
		printerr("  ÉCHEC %s" % quoi)


func _verdict() -> void:
	print("test_planche_marche : %d/%d" % [_total - _echecs, _total])
	quit(1 if _echecs > 0 else 0)
