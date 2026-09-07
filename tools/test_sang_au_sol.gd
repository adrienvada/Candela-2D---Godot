extends SceneTree

## **La tache de sang tombe-t-elle SUR le corps, ou avant lui ?**
##
## Relevé par Adrien le 2026-09-07 en jouant : « les taches de sang au sol sont
## mal positionnées : elles démarrent souvent AVANT le sprite du joueur touché ».
##
## Le défaut se compose de trois faits qui, séparément, sont chacun raisonnable :
## `bullet.gd` transmet le point d'**entrée** (le bord du corps du côté du
## tireur, 18 px en amont du centre), `blood_stain.gd` posait le nœud **à** ce
## point, et `_draw()` dessinait la planche **centrée** dessus. Une planche de
## 160 px de large agrandie jusqu'à ×1,25 remontait donc jusqu'à **100 px vers le
## tireur**, pour un joueur qui en fait 18 de rayon : la moitié de l'éclaboussure
## était peinte entre le tireur et sa victime.
##
## ⚠️ **L'oracle est écrit ici, à la main, jamais lu sur le code.** `MARGE_AMONT`
## ci-dessous n'est pas `blood_stain.ANCRAGE_AVAL` déguisé : c'est une borne
## indépendante, dérivée du seul fait qui ne bouge pas — la taille du corps
## relevée sur `player.tscn`. Sans cette séparation, élargir la constante que le
## code utilise ferait passer ce banc au vert **en supprimant exactement ce qu'il
## protège**. La leçon est déjà payée deux fois dans `tools/`.
##
## ⚠️ **`blood_stain.gd` n'est jamais NOMMÉ, il est chargé par son chemin.**
## Nommer une classe dans un banc lancé par `--script` en fait une dépendance de
## **compilation** : Godot la compile avant que le moindre autoload soit
## enregistré, et le banc ne compile plus. Même piège, même parade que
## `tools/test_bandeau_fatal.gd`.

## La tache n'a pas le droit de remonter de plus de ceci en amont du point
## d'impact, en pixels.
##
## **D'où vient ce nombre :** le point d'impact est le bord d'entrée du corps, et
## le corps fait 18 px de rayon (`player.tscn`, polygone de -18 à +18). Tolérer
## un rayon, c'est accepter qu'une tache lèche le côté du corps par où la balle
## est entrée — ce qui reste lisible — et refuser tout ce qui va plus loin. Le
## défaut d'origine remontait à 100 px : il échoue de très loin.
const MARGE_AMONT := 18.0

## Taille de la plus grande planche, en pixels, telle qu'elle sort du fichier.
## Relevée sur `assets/decals/sang_1.png` — pas demandée au code.
const PLANCHE_MAX := Vector2(160.0, 130.0)

## Agrandissement maximal tiré au sort par `setup()`.
const ECHELLE_MAX := 1.25

var _ok := 0
var _ko := 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_ok += 1
		print("  ✓ %s" % label)
	else:
		_ko += 1
		printerr("  ✗ %s%s" % [label, "  → " + detail if detail != "" else ""])


func _init() -> void:
	# Différé : `_init()` qui lèverait n'atteindrait jamais `quit()`, et un banc
	# qui ne sort pas est pire qu'un banc rouge — un rouge se voit, un silence se
	# confond avec « ça travaille ».
	call_deferred("_run")


## De combien la tache remonte en amont du point d'impact, en pixels, mesuré
## **en monde** sur les quatre coins du rectangle dessiné.
##
## Ce calcul est celui du banc, pas une recopie de l'oracle du code : il compose
## la pose et le rectangle comme le moteur le fait, puis projette sur l'axe du
## tir. Un résultat positif veut dire « ça remonte », négatif « tout est en aval ».
func _remontee_amont(sang: GDScript, impact: Vector2, direction: Vector2,
		taille: Vector2) -> float:
	var t: Transform2D = sang.pose(impact, direction)
	var r: Rect2 = sang.rectangle_de_la_tache(taille)
	var pire := -INF
	for coin: Vector2 in [r.position, r.position + Vector2(r.size.x, 0.0),
			r.position + Vector2(0.0, r.size.y), r.end]:
		# Projection sur l'axe du tir, depuis le point d'impact : négatif = aval.
		var le_long := (t * coin - impact).dot(direction.normalized())
		pire = maxf(pire, -le_long)
	return pire


## Abscisse du centre de masse alpha d'une planche, en fraction de sa largeur.
##
## ⚠️ **Le quatrième fait du diagnostic, et celui qui explique « souvent »
## plutôt que « toujours ».** Les deux planches n'ont pas leur masse au même
## endroit : `sang_1` est à peu près centrée, `sang_2` porte la sienne franchement
## d'un côté. Une tache sur deux est donc pire que l'autre, et un contrôle qui ne
## regarderait que le rectangle passerait à côté.
func _centre_de_masse(chemin: String) -> float:
	var tex: Texture2D = load(chemin)
	if tex == null:
		return -1.0
	var img := tex.get_image()
	var somme := 0.0
	var pondere := 0.0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var a := img.get_pixel(x, y).a
			somme += a
			pondere += a * float(x)
	if somme <= 0.0:
		return -1.0
	return (pondere / somme) / float(img.get_width())


func _run() -> void:
	print("=== LA TACHE DE SANG TOMBE SUR LE CORPS, PAS AVANT ===")
	await process_frame

	# Par chemin, jamais par nom de classe — voir la note en tête de fichier.
	var sang: GDScript = load("res://blood_stain.gd")
	if sang == null:
		printerr("✗ blood_stain.gd introuvable ou ne compile pas")
		quit(1)
		return

	# Le pire cas réel : la plus grande planche, agrandie au maximum.
	var taille_max := PLANCHE_MAX * ECHELLE_MAX

	print("\n[Aucun pixel ne remonte vers le tireur, quelle que soit la direction]")
	# Huit directions, dont deux obliques : la rotation ne doit pas rouvrir le
	# défaut par un côté. Le point d'impact est volontairement hors de l'origine,
	# pour attraper une pose qui oublierait la translation.
	var impact := Vector2(640.0, 360.0)
	for degres: float in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		var dir := Vector2.RIGHT.rotated(deg_to_rad(degres))
		var remontee := _remontee_amont(sang, impact, dir, taille_max)
		_check("tir à %.0f° : la tache ne remonte pas de plus de %.0f px"
				% [degres, MARGE_AMONT],
			remontee <= MARGE_AMONT,
			"%.1f px en amont du point d'impact" % remontee)

	print("\n[Et la planche la plus petite ne triche pas non plus]")
	# `sang_2` fait 160×64 : moins haute, aussi longue. Une correction qui
	# dépendrait de la hauteur passerait ici et raterait là.
	var remontee_fine := _remontee_amont(sang, impact, Vector2.RIGHT,
		Vector2(160.0, 64.0) * ECHELLE_MAX)
	_check("la planche fine reste elle aussi en aval",
		remontee_fine <= MARGE_AMONT,
		"%.1f px en amont" % remontee_fine)

	print("\n[La tache couvre bien le corps, elle ne le saute pas]")
	# Le contre-test de l'oracle ci-dessus. Sans lui, pousser la planche à 500 px
	# en aval passerait tous les contrôles précédents avec les honneurs — et le
	# sang apparaîtrait dans le vide, loin derrière le mort. Ce qu'on veut n'est
	# pas « le plus loin possible », c'est « à partir du corps ».
	var r: Rect2 = sang.rectangle_de_la_tache(taille_max)
	_check("la tache commence à moins d'un diamètre de corps de l'impact",
		r.position.x <= 36.0,
		"elle commence à %.1f px en aval" % r.position.x)

	print("\n[La masse de chaque planche tombe en aval du point d'impact]")
	# Le rectangle peut être en aval alors que la peinture, elle, reste groupée
	# du côté amont : c'est précisément le cas de `sang_2`. On mesure donc où le
	# poids de l'encre atterrit, pas seulement où le cadre commence.
	for chemin: String in ["res://assets/decals/sang_1.png",
			"res://assets/decals/sang_2.png"]:
		var fraction := _centre_de_masse(chemin)
		if fraction < 0.0:
			_check("%s : planche lisible" % chemin.get_file(), false,
				"texture absente ou vide (lancer --import ?)")
			continue
		var masse_x := r.position.x + fraction * r.size.x
		_check("%s : sa masse est en aval de l'impact" % chemin.get_file(),
			masse_x >= 0.0,
			"masse à %.0f%% de la planche, soit %.1f px (négatif = en amont)"
				% [fraction * 100.0, masse_x])

	print("\n[Le nœud réel se pose là où `pose()` le dit]")
	# La boucle fermée : sans ce contrôle, `pose()` pourrait décrire une pose que
	# `setup()` n'applique pas, et tout le reste du banc mesurerait une fiction.
	var arene := Node2D.new()
	arene.name = "AreneDeBanc"
	root.add_child(arene)
	var tache := Node2D.new()
	tache.name = "TacheDeBanc"
	tache.set_script(sang)
	# Même ordre qu'en jeu (`bullet.gd::_spawn_hit_effects`) : ajouté d'abord,
	# `setup()` ensuite. `_ready()` tourne donc AVANT `setup()`.
	arene.add_child(tache)
	var dir_essai := Vector2.RIGHT.rotated(deg_to_rad(30.0))
	tache.setup(impact, dir_essai)
	var attendue: Transform2D = sang.pose(impact, dir_essai)
	_check("le nœud est posé au point d'impact",
		tache.position.is_equal_approx(attendue.origin),
		"%s au lieu de %s" % [str(tache.position), str(attendue.origin)])
	_check("et tourné dans l'axe du tir",
		is_equal_approx(tache.rotation, attendue.get_rotation()),
		"%.4f au lieu de %.4f" % [tache.rotation, attendue.get_rotation()])

	print("\n[La copie J2 hérite de TOUT ce que `_draw()` lit]")
	# ⚠️ **`duplicate()` ne recopie pas les variables de script.** Le piège a
	# déjà coûté cher exactement ici : sous le dessin procédural, la copie J2
	# naissait avec zéro goutte et **le joueur 2 n'a jamais vu une seule tache**,
	# sans que rien ne le signale. Toute variable neuve lue par `_draw()` doit
	# être reportée à la main dans `_create_p2_duplicate()`, et ce contrôle est
	# ce qui le rappellera au suivant.
	await process_frame # `_create_p2_duplicate` est différé.
	var copies := tache.get_tree().get_nodes_in_group("blood_p2")
	_check("la copie J2 existe", copies.size() == 1,
		"%d copie(s) trouvée(s)" % copies.size())
	if copies.size() == 1:
		var p2: Node2D = copies[0]
		_check("elle est au même endroit et dans le même axe",
			p2.position.is_equal_approx(tache.position)
				and is_equal_approx(p2.rotation, tache.rotation),
			"%s / %.4f" % [str(p2.position), p2.rotation])
		_check("elle voit le viewport J2 et son ambiance",
			p2.visibility_layer == 4 and p2.light_mask == (1 | 32),
			"couche %d, masque %d" % [p2.visibility_layer, p2.light_mask])
		# Les trois variables que `_draw()` lit dans la branche peinte, plus
		# `_drops` pour la branche de repli. Une de moins et J2 dessine du vide.
		_check("elle a reçu la planche", p2.get("_texture") == tache.get("_texture"))
		_check("elle a reçu le cœur", p2.get("_coeur") == tache.get("_coeur"))
		_check("elle a reçu l'agrandissement",
			is_equal_approx(float(p2.get("_echelle")), float(tache.get("_echelle"))),
			"%.3f au lieu de %.3f"
				% [float(p2.get("_echelle")), float(tache.get("_echelle"))])
		_check("elle a reçu les gouttes du repli",
			(p2.get("_drops") as Array).size() == (tache.get("_drops") as Array).size(),
			"%d au lieu de %d" % [(p2.get("_drops") as Array).size(),
				(tache.get("_drops") as Array).size()])

	if _ko == 0:
		print("\n✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("\n✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
