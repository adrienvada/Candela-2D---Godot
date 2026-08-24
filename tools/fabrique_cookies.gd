extends SceneTree

## Cuit les cookies de torche depuis une planche générée (DA2.1).
##
## ## Ce que l'outil fait, et pourquoi ainsi
##
## **La planche ne devient pas le cookie : elle le module.** La géométrie — angle
## du cône, portée, fondu de bord — reste dans le code ; la planche n'apporte que
## la *matière* (cœur, corona, stries, irrégularité). C'est ce qui laisse les
## quatre armes gratuites : `torch_angle_deg` reste vivant, et une planche peinte
## pour un faisceau large sert aussi bien l'arbalète à 5°.
##
## **L'échantillonnage est POLAIRE**, et c'est le cœur de l'affaire. Pour chaque
## pixel de sortie on calcule sa distance `u` et son angle `v` *normalisé par le
## demi-angle de l'arme*, puis on lit la planche en `(u, v)` — sa largeur devient
## la portée, sa hauteur devient l'ouverture. L'ouverture propre de la planche
## n'a donc aucune importance : elle s'étire ou se comprime sur celle de l'arme.
## Sans ça, il faudrait une planche peinte par arme.
##
## **Le profil radial de la planche est divisé avant d'être appliqué.** Une
## planche générée porte déjà son atténuation (elle s'éteint vers la droite) ; la
## multiplier telle quelle par l'atténuation du code l'appliquerait deux fois, et
## le faisceau mourrait à mi-course. On isole donc la STRUCTURE — la planche
## divisée par sa propre moyenne colonne par colonne, ce qui la recentre sur 1,0
## — et le curseur `profil` décide ensuite laquelle des deux atténuations on
## garde.
##
## ## À `matiere=0`, la sortie retrouve le cookie actuel — à un demi-pixel près
##
## `matiere=0, profil=0, portee=1, bord=1` reprend la formule de
## `WeaponData.get_torch_texture()` : `1 - u` pour la portée,
## `clamp((demi - angle) * 8, 0, 1)` pour le bord, le halo à 0,15 sur les 20 %
## proches de l'émetteur. **C'est délibéré :** toute différence visible en jeu
## devient imputable à un curseur qu'on a bougé, jamais à un changement qu'on n'a
## pas vu passer.
##
## ⚠️ **Ce n'est pas une égalité au bit près, et la mesure vaut mieux que la
## promesse.** Comparé au cookie actuel à 512² : écart moyen de **0,13 sur 255**,
## et **899 pixels sur 262 144** au-delà de 8/255. Ils dessinent un **liseré d'un
## pixel le long des deux bords du cône**, maximal à l'émetteur et s'effaçant
## vers la portée.
##
## La cause est une convention d'échantillonnage, pas une formule : `WeaponData`
## lit les pixels en coordonnées entières avec le centre POSÉ SUR un pixel
## (255 → -1, 256 → 0, 257 → +1, donc asymétrique d'un demi-pixel) ; ici on lit
## au centre de chaque pixel, le centre de la texture tombant entre deux
## (255 → -0,5, 256 → +0,5). Sur une texture de taille paire, c'est cette
## seconde convention qui est symétrique. **La différence est donc dans le bon
## sens, mais elle existe : un cookie cuit ici n'est pas le même fichier que
## celui d'aujourd'hui, il est son équivalent recentré.**
##
## ## La planche ne peut que RETIRER de la lumière — et pourquoi
##
## Un cookie ne décide pas seulement de l'allure du faisceau : il décide de la
## **quantité de lumière** jetée et surtout de la **distance** à laquelle elle
## porte. Dans un jeu dont la règle est « être vu, c'est être mort », c'est de
## l'équilibrage, pas de la décoration.
##
## ⚠️ **Le premier jet conservait l'énergie TOTALE, et c'était le mauvais
## invariant.** Le total était juste ; sa répartition s'était effondrée. Mesuré
## le long de l'axe du faisceau, alpha du centre au bord :
##
## ```
## actuel  250 233 227 219 211 ... 28 20 11  4
## premier 243 255 255 255 255 ... 140 117 95 74     <- saturé, et 18x trop clair au bord
## ```
##
## Le masque saturait à 255 sur les deux tiers de sa longueur et valait encore 74
## là où l'original vaut 4. **Une torche qui porte dix-huit fois plus loin n'est
## pas la même arme.** C'est Adrien qui l'a vu à l'écran, en une phrase — « ça
## éclaire beaucoup trop loin » — là où mon contrôle d'énergie totale annonçait
## 100 %. Le compteur `ECRETE` le disait pourtant depuis le début ; je l'avais lu
## comme un détail.
##
## **La cause est un plafond.** Un masque ne dépasse pas 1,0. La planche veut
## poser deux à trois fois la référence sur l'axe ; l'excédent est raboté, le
## cœur devient une barre blanche, et remettre l'énergie perdue ne fait
## qu'aggraver le rabotage.
##
## **D'où l'invariant retenu : la structure est divisée par le SOMMET de son
## anneau, jamais par sa moyenne.** Elle vaut donc 1 à l'angle le plus clair et
## moins ailleurs. Conséquence, vraie par construction et non par réglage :
##
## > **le cookie cuit n'éclaire JAMAIS plus que celui qu'il remplace, à aucune
## > distance et sous aucun angle.**
##
## La portée est alors identique au chiffre près, et la planche ne peut plus
## s'exprimer qu'en creusant — ce qui est exactement la façon dont un vrai
## faisceau se lit : une corona plus sombre que le cœur, des bords mangés.
##
## **Le prix est explicite, et il s'imprime.** Creuser retire de la lumière : à
## `--matiere 0.5` il reste environ 65 % du total d'origine, à 0,8 environ 42 %.
## Chaque ligne de sortie l'affiche. `--energie radial` ou `totale` remet
## l'énergie à niveau si on le veut un jour — au prix de l'écrêtage qui a causé
## ce défaut, donc en le sachant.
##
## ## Deux pièges qui coûtent cher
##
## ⚠️ **`torch_angle_deg` est un DEMI-angle.** `WeaponData` compare
## `abs(dir.angle()) <= deg_to_rad(torch_angle_deg)` : la pompe à 60° ouvre un
## cône de 120°. Le lire comme un angle total diviserait toutes les ouvertures
## par deux, et le jeu resterait jouable — donc personne ne le verrait.
##
## ⚠️ **Le RVB sort en blanc pur, l'alpha porte l'intensité.** Depuis que la
## teinte a été déplacée sur `flashlight.color` (`player.gd`), le cookie est un
## masque. Y remettre l'halogène teinterait deux fois.
##
## ## Pourquoi hors ligne
##
## La fabrique actuelle tourne au premier équipement : 262 144 itérations de
## GDScript, et 1 048 576 à la taille visée. C'est la classe de défaut déjà payée
## une fois avec le shader compilé au premier mort — un hoquet pile sur l'action
## décisive. Cuit ici, chargé là-bas.
##
## ## Usage
##
## ```
## godot --headless --path . --script res://tools/fabrique_cookies.gd -- \
##     --planche A4_bis_04.jpg --etiquette bis04
## ```
##
## Curseurs : `--matiere 0..1` `--profil 0..1` `--contraste` `--bord` `--portee`
## `--halo` `--debut`. Planche par arme : `--planche-pompe A4_bis_01.jpg`.
## `--energie libre` laisse la lumière changer ; `--taille` change la résolution.

## Taille de sortie par défaut. 1024 vise 1,75 pixel d'écran par texel au
## `torch_scale` le plus grand (3,5) ; le 512 actuel en couvre 3,5. Réglable par
## `--taille`, ce qui sert surtout à comparer une cuisson au cookie d'origine,
## qui fait 512.
const TAILLE_DEFAUT := 1024
const SOURCES := "res://assets/sources/torche/"
const SORTIE := "res://assets/torche/"

## Les quatre armes viennent de `tools/torches.gd`, partagé avec l'aperçu : deux
## tables auraient divergé au premier réglage, et le banc aurait montré autre
## chose que ce qu'on cuit.
const Torches := preload("res://tools/torches.gd")

## Le halo court de l'émetteur, repris tel quel de `WeaponData` : 20 % de la
## portée, ouvert à 80°, plafonné à 0,15.
const HALO_PORTEE := 0.2
const HALO_OUVERTURE_DEG := 80.0

## Nombre de pas du profil radial. 512 sur une portée de 512 pixels : un pas par
## pixel, inutile d'aller plus fin.
const PROFIL_PAS := 512

## Demi-fenêtre du lissage de l'enveloppe, en pas de profil. 12 sur 512 couvre
## ~2,3 % du rayon : assez pour noyer le tressautement du maximum, trop peu pour
## effacer la forme du faisceau.
const LISSAGE := 12

## ## Les trois garde-fous de l'émetteur
##
## Près de la pointe du cône, la planche n'a presque rien à dire : `u -> 0` lit
## sa colonne de gauche, et l'espace polaire y étale une poignée de pixels
## sources sur tout un disque centré sur le joueur. Diviser par un profil proche
## de zéro y amplifie le bruit de la planche sans limite — c'est de
## l'arithmétique, pas une impression.
##
## Trois bornes, et chacune traite une cause distincte :
##
## - `PLANCHER_PROFIL` empêche le dénominateur de tomber vers zéro ;
## - `MATIERE_DEBUT_DEFAUT` fait entrer la matière **progressivement** sur les premiers
##   pour-cent du rayon. C'est le seul des trois qui traite la vraie cause : là
##   où la planche ne sait rien, on garde la géométrie du code plutôt que
##   d'amplifier son bruit.
##
## ⚠️ **Et il y a une seconde cause, qui n'est pas du bruit : les planches
## générées DESSINENT une lentille.** Les trois `A4_bis` portent une ellipse
## brillante collée à leur bord gauche — le reflet du réflecteur, que le modèle
## rend parce qu'on lui a demandé une torche. En polaire, cette colonne-là
## s'étale sur tout un disque autour du joueur. Aucun filtre ne la rattrape :
## c'est du contenu, et il n'a rien à faire là. D'où `--debut`, réglable par
## planche puisque l'ellipse n'occupe pas la même largeur sur chacune.
##
## ⚠️ **Ce qu'il ne faut PAS croire, parce que je l'ai cru :** aucune des trois
## variantes ne grésille au-delà de ce que fait déjà le cookie actuel. Mesuré
## dans la zone du joueur, écart-type des hautes fréquences sur 255 — actuel
## **6,48**, bis04 **6,52**, bis01 **6,39**, bis02 **5,76**. L'impression
## contraire venait d'un agrandissement au filtre point, qui transforme un
## texel en pavé. **Juger un masque de lumière à un zoom sans interpolation, c'est
## juger l'outil de mesure.**
## Nombre d'anneaux du contrôle d'énergie radiale. 256 sur un rayon de 512 :
## deux pixels par anneau, assez fin pour suivre l'atténuation, assez large pour
## que chaque anneau contienne de quoi moyenner.
const RAYON_PAS := 256

const PLANCHER_PROFIL := 0.02
const MATIERE_DEBUT_DEFAUT := 0.12

var _largeur := 0
var _hauteur := 0
var _luminance := PackedFloat32Array()
var _profil := PackedFloat32Array()
## Le PLUS BRILLANT de la planche à chaque distance, en travers du cône. C'est
## par lui qu'on divise la structure : elle vaut alors 1 à l'angle le plus clair
## et moins ailleurs, donc la planche ne peut que RETIRER de la lumière.
var _sommet := PackedFloat32Array()
var _profil_max := 0.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var planche_defaut := _arg(args, "--planche", "")
	if planche_defaut == "":
		_erreur("Aucune planche. Exemple : --planche A4_bis_04.jpg")
		quit(1)
		return

	var etiquette := _arg(args, "--etiquette", "")
	var taille := int(_arg(args, "--taille", str(TAILLE_DEFAUT)))
	var reglages := {
		"matiere": float(_arg(args, "--matiere", "0.5")),
		"profil": float(_arg(args, "--profil", "0.0")),
		"contraste": float(_arg(args, "--contraste", "1.0")),
		"bord": float(_arg(args, "--bord", "1.0")),
		"portee": float(_arg(args, "--portee", "1.0")),
		"halo": float(_arg(args, "--halo", "0.15")),
		"energie": _arg(args, "--energie", "libre"),
		"debut": float(_arg(args, "--debut", str(MATIERE_DEBUT_DEFAUT))),
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))

	print("Planche par défaut : %s — sortie %d²" % [planche_defaut, taille])
	print("Curseurs : %s" % str(reglages))

	var planche_courante := ""
	var code := 0
	for arme in Torches.ARMES:
		var planche: String = _arg(args, "--planche-" + str(arme["fichier"]), planche_defaut)
		if planche != planche_courante:
			if not _charger_planche(planche):
				code = 1
				break
			planche_courante = planche
		if not _cuire(arme, planche, etiquette, taille, reglages):
			code = 1
			break
	quit(code)


## Charge une planche, la ramène en luminance, retire un éventuel cadre clair,
## puis calcule son profil radial. Passe par `FileAccess` plutôt que par `load()`
## : `assets/sources/` porte un `.gdignore`, donc Godot n'y importe rien — et
## c'est voulu, ces images sont des sources, pas des ressources de jeu.
func _charger_planche(nom: String) -> bool:
	var chemin := ProjectSettings.globalize_path(SOURCES + nom)
	if not FileAccess.file_exists(chemin):
		_erreur("Planche introuvable : %s" % chemin)
		return false

	var octets := FileAccess.get_file_as_bytes(chemin)
	var img := Image.new()
	var err := OK
	if nom.to_lower().ends_with(".png"):
		err = img.load_png_from_buffer(octets)
	elif nom.to_lower().ends_with(".jpg") or nom.to_lower().ends_with(".jpeg"):
		err = img.load_jpg_from_buffer(octets)
	else:
		_erreur("Format non géré : %s (png ou jpg)" % nom)
		return false
	if err != OK:
		_erreur("Lecture impossible : %s (code %d)" % [nom, err])
		return false

	img.convert(Image.FORMAT_RGBA8)
	var rogne := _cadre_a_rogner(img)
	if rogne > 0:
		img = img.get_region(Rect2i(rogne, rogne,
			img.get_width() - rogne * 2, img.get_height() - rogne * 2))
		print("  cadre clair rogné : %d px sur chaque bord" % rogne)

	_largeur = img.get_width()
	_hauteur = img.get_height()
	var donnees := img.get_data()
	_luminance = PackedFloat32Array()
	_luminance.resize(_largeur * _hauteur)
	# Rec. 709. La planche est censée être en niveaux de gris ; si une teinte a
	# survécu à la génération, c'est ici qu'elle disparaît.
	for i in range(_largeur * _hauteur):
		var o := i * 4
		_luminance[i] = (donnees[o] * 0.2126 + donnees[o + 1] * 0.7152
			+ donnees[o + 2] * 0.0722) / 255.0

	_calculer_profil()
	print("Planche %s : %dx%d, profil max %.3f" % [nom, _largeur, _hauteur, _profil_max])
	return true


## Détecte un cadre clair — le modèle rend parfois une photo encadrée de blanc —
## en avançant depuis le bord tant que la ligne moyenne reste claire. Rogne le
## même nombre de pixels sur les quatre côtés : un cadre asymétrique
## décentrerait l'émetteur, ce qui coûte plus cher que quelques pixels perdus.
func _cadre_a_rogner(img: Image) -> int:
	var h := img.get_height()
	var w := img.get_width()
	var maxi := int(min(w, h) * 0.06)
	var rogne := 0
	while rogne < maxi:
		var somme := 0.0
		for x in range(0, w, 8):
			var c := img.get_pixel(x, rogne)
			somme += (c.r + c.g + c.b) / 3.0
		if somme / float(w / 8) < 0.5:
			break
		rogne += 1
	return rogne


## Moyenne de la planche colonne par colonne, dans l'espace polaire. C'est
## l'atténuation propre de la planche ; on la divise ensuite pour n'en garder que
## la structure.
func _calculer_profil() -> void:
	_profil = PackedFloat32Array()
	_profil.resize(PROFIL_PAS)
	_sommet = PackedFloat32Array()
	_sommet.resize(PROFIL_PAS)
	_profil_max = 0.0
	for i in range(PROFIL_PAS):
		var u := (float(i) + 0.5) / float(PROFIL_PAS)
		var somme := 0.0
		var pic := 0.0
		var n := 256
		for j in range(n):
			var v := (float(j) + 0.5) / float(n) * 2.0 - 1.0
			var g := _echantillon(u, v)
			somme += g
			pic = maxf(pic, g)
		var moy := somme / float(n)
		_profil[i] = moy
		_sommet[i] = pic
		if moy > _profil_max:
			_profil_max = moy
	if _profil_max <= 0.0:
		_profil_max = 1.0
	_profil = _lisser(_profil)
	_sommet = _lisser(_sommet)


## Moyenne glissante sur la distance.
##
## ⚠️ **Sans elle, le faisceau des armes à cône fin se couvre de BANDES.** Le
## sommet est un maximum d'échantillons : il tressaute d'une distance à l'autre,
## au gré du grain de la planche. Sur un cône large ce tressautement se dilue
## dans la largeur ; sur les 10° du fusil il n'y a plus de largeur où le diluer,
## et chaque sursaut devient un anneau clair ou sombre en travers du faisceau.
## Défaut vu à l'écran par Adrien avant d'être compris ici.
##
## La vraie enveloppe d'un faisceau est lisse : ce qui tressaute est du bruit de
## mesure, pas de la matière. On le retire donc de l'ENVELOPPE, sans toucher à la
## structure elle-même — le grain reste, ses anneaux disparaissent.
func _lisser(source: PackedFloat32Array) -> PackedFloat32Array:
	var sortie := PackedFloat32Array()
	var n := source.size()
	sortie.resize(n)
	for i in range(n):
		var somme := 0.0
		var compte := 0
		for j in range(i - LISSAGE, i + LISSAGE + 1):
			if j >= 0 and j < n:
				somme += source[j]
				compte += 1
		sortie[i] = somme / float(compte)
	return sortie


## Lecture bilinéaire de la planche en coordonnées polaires normalisées :
## `u` de 0 (émetteur) à 1 (portée maximale), `v` de -1 à 1 en travers du cône.
func _echantillon(u: float, v: float) -> float:
	var px: float = clampf(u, 0.0, 1.0) * float(_largeur - 1)
	var py: float = clampf(v * 0.5 + 0.5, 0.0, 1.0) * float(_hauteur - 1)
	var x0 := int(px)
	var y0 := int(py)
	var x1: int = mini(x0 + 1, _largeur - 1)
	var y1: int = mini(y0 + 1, _hauteur - 1)
	var fx := px - float(x0)
	var fy := py - float(y0)
	var a := _luminance[y0 * _largeur + x0]
	var b := _luminance[y0 * _largeur + x1]
	var c := _luminance[y1 * _largeur + x0]
	var d := _luminance[y1 * _largeur + x1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _cuire(arme: Dictionary, planche: String, etiquette: String, taille: int,
		r: Dictionary) -> bool:
	var demi_deg: float = arme["angle"]
	var demi := deg_to_rad(demi_deg)
	var brillance: float = arme["brillance"]

	# Largeur du fondu de bord, exprimée en `v`. La formule d'origine
	# — `clamp((demi - angle) * 8, 0, 1)` — donne un fondu de `1 / (8 * demi)` en
	# v. Pour l'arbalète (5°) cette largeur dépasse 1 : le cône est alors un
	# fondu de part en part, sans cœur plat. C'est le comportement actuel, on le
	# reproduit plutôt que de le « corriger ».
	var largeur_bord: float = maxf(1.0 / (8.0 * demi), 0.001) * r["bord"]
	var halo_ouverture := deg_to_rad(HALO_OUVERTURE_DEG)

	var centre := float(taille) * 0.5
	var rayon := float(taille) * 0.5
	var pixels := PackedFloat32Array()
	pixels.resize(taille * taille)

	# Deux sommes PAR ANNEAU : celle du masque qu'on cuit, celle du masque à
	# `matiere=0` — le cookie d'aujourd'hui. Leur rapport, anneau par anneau,
	# donne le facteur qui conserve la PORTÉE et pas seulement le total.
	var somme := PackedFloat64Array()
	somme.resize(RAYON_PAS)
	var somme_parite := PackedFloat64Array()
	somme_parite.resize(RAYON_PAS)
	var anneaux := PackedInt32Array()
	anneaux.resize(taille * taille)
	anneaux.fill(-1)

	for y in range(taille):
		var dy := float(y) + 0.5 - centre
		for x in range(taille):
			var dx := float(x) + 0.5 - centre
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= rayon:
				continue
			var u := dist / rayon
			var angle := atan2(dy, dx)
			var angle_abs := absf(angle)
			var v := angle / demi

			var intensite := 0.0
			var intensite_parite := 0.0
			if absf(v) <= 1.0:
				var fondu_bord: float = clampf((1.0 - absf(v)) / largeur_bord, 0.0, 1.0)
				# Atténuation du code : `1 - u`, exactement comme aujourd'hui.
				var att_code: float = pow(1.0 - u, r["portee"])
				# Atténuation de la planche, ramenée sur 0..1.
				var i_profil: int = clampi(int(u * PROFIL_PAS), 0, PROFIL_PAS - 1)
				var p := _profil[i_profil]
				var att_planche := p / _profil_max
				var att: float = lerpf(att_code, att_planche, r["profil"])

				# Structure seule : la planche débarrassée de son atténuation,
				# donc centrée sur 1,0. `max` au dénominateur évite d'exploser
				# là où la planche est noire.
				var structure := 1.0
				if r["matiere"] > 0.0:
					var g := _echantillon(u, v)
					# Divisé par le SOMMET de l'anneau, pas par sa moyenne : la
					# structure vaut alors 1 là où la planche est la plus claire
					# et moins partout ailleurs. Le masque reste donc TOUJOURS
					# sous le cookie d'origine — jamais plus de lumière nulle
					# part, à aucune distance.
					var pic: float = _sommet[i_profil]
					structure = g / maxf(pic, _profil_max * PLANCHER_PROFIL)
					if r["contraste"] != 1.0:
						structure = pow(maxf(structure, 0.0), r["contraste"])
					structure = clampf(structure, 0.0, 1.0)
					# La matière entre en fondu : nulle à l'émetteur, pleine au
					# delà de `MATIERE_DEBUT`. Voir les garde-fous plus haut.
					var poids: float = r["matiere"] * smoothstep(0.0, r["debut"], u)
					structure = lerpf(1.0, structure, poids)

				intensite = att * fondu_bord * structure
				intensite_parite = att_code * fondu_bord

			# Halo court, repris de `WeaponData` : `max`, pas addition.
			if u < HALO_PORTEE and angle_abs <= halo_ouverture:
				var halo_fondu: float = clampf((halo_ouverture - angle_abs) * 4.0, 0.0, 1.0)
				var halo_i: float = pow(1.0 - u / HALO_PORTEE, 2.5) * r["halo"] * halo_fondu
				intensite = maxf(intensite, halo_i)
				intensite_parite = maxf(intensite_parite, halo_i)

			var idx := y * taille + x
			var anneau: int = clampi(int(u * RAYON_PAS), 0, RAYON_PAS - 1)
			pixels[idx] = intensite
			anneaux[idx] = anneau
			somme[anneau] += intensite
			somme_parite[anneau] += intensite_parite

	# Un facteur par anneau. Le mode décide de ce qu'on conserve :
	#   `radial` (défaut) — l'énergie de CHAQUE anneau, donc la portée ;
	#   `totale`          — la somme globale seulement ;
	#   `libre`           — rien.
	var facteurs := PackedFloat64Array()
	facteurs.resize(RAYON_PAS)
	facteurs.fill(1.0)
	var mode: String = r["energie"]

	if mode == "totale":
		var tot := 0.0
		var tot_parite := 0.0
		for k in range(RAYON_PAS):
			tot += somme[k]
			tot_parite += somme_parite[k]
		if tot > 0.0:
			facteurs.fill(tot_parite / tot)
	elif mode == "radial":
		for k in range(RAYON_PAS):
			if somme[k] > 0.0:
				facteurs[k] = somme_parite[k] / somme[k]

	# Le facteur naïf vise juste AVANT écrêtage. Or la matière fait dépasser 1,0
	# au cœur : une partie de l'énergie qu'on croyait poser est rabotée, et le
	# masque sort plus sombre que la cible — mesuré à 87 % au premier jet. On
	# corrige par itération, en resommant ce qui survit réellement. Quatre tours
	# suffisent, la suite converge vite.
	if mode != "libre":
		for _tour in range(4):
			var retenu := PackedFloat64Array()
			retenu.resize(RAYON_PAS)
			for i in range(taille * taille):
				var k := anneaux[i]
				if k >= 0:
					retenu[k] += minf(pixels[i] * facteurs[k], 1.0)
			for k in range(RAYON_PAS):
				if retenu[k] > 0.0:
					facteurs[k] *= somme_parite[k] / retenu[k]

	var octets := PackedByteArray()
	octets.resize(taille * taille * 4)
	var ecrete := 0
	for i in range(taille * taille):
		var o := i * 4
		octets[o] = 255
		octets[o + 1] = 255
		octets[o + 2] = 255
		var k := anneaux[i]
		var val := 0.0
		if k >= 0:
			val = pixels[i] * facteurs[k] * brillance
		if val > 1.0:
			ecrete += 1
			val = 1.0
		octets[o + 3] = int(round(maxf(val, 0.0) * 255.0))

	var img := Image.create_from_data(taille, taille, false, Image.FORMAT_RGBA8, octets)
	var suffixe := "" if etiquette == "" else "_" + etiquette
	var nom_fichier := "cookie_%s%s.png" % [arme["fichier"], suffixe]
	var chemin := ProjectSettings.globalize_path(SORTIE + nom_fichier)
	var err := img.save_png(chemin)
	if err != OK:
		_erreur("Écriture impossible : %s (code %d)" % [chemin, err])
		return false
	# L'énergie n'est plus rattrapée : elle DESCEND, puisque la planche ne peut
	# que retirer. On l'imprime donc, parce qu'une baisse silencieuse serait
	# exactement le défaut qu'on vient de corriger dans l'autre sens.
	var tot := 0.0
	var tot_parite := 0.0
	for k in range(RAYON_PAS):
		tot += somme[k]
		tot_parite += somme_parite[k]
	var part := 100.0 * tot / maxf(tot_parite, 1e-9)
	print("  %-9s  demi-angle %5.1f°  planche %-16s  lumiere %5.1f%% de l'actuel%s  ->  %s"
		% [arme["nom"], demi_deg, planche, part,
			"" if ecrete == 0 else "  ECRETE:%d" % ecrete, nom_fichier])
	return true


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	for i in range(args.size() - 1):
		if args[i] == nom:
			return args[i + 1]
	return defaut


func _erreur(message: String) -> void:
	printerr("fabrique_cookies : " + message)
