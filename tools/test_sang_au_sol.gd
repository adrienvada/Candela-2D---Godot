extends SceneTree

## **La grosse flaque tombe-t-elle sous le personnage ?**
##
## Relevé par Adrien le 2026-09-07 en jouant : « les taches de sang au sol sont
## mal positionnées : elles démarrent souvent AVANT le sprite du joueur touché ».
##
## **Puis, la règle, de lui aussi, quand la première correction lui a été
## montrée :** « il faut que le centre de la plus grosse tache (la plus grosse
## forme rouge assez ronde sur chacune) soit sous le personnage, et que la tache
## soit orientée — surtout la longue — de sorte que la traînée soit dans la
## direction du tir. »
##
## ⚠️ **Ce banc a d'abord porté un autre oracle, et c'est instructif.** Il
## bornait la remontée d'encre vers le tireur : « aucun pixel ne remonte de plus
## de 18 px en amont du point d'impact ». C'était un **proxy** — plausible,
## mesurable, vert une fois corrigé, et FAUX comme spécification. Une
## éclaboussure projette dans toutes les directions, l'arrière compris ; borner
## les pixels interdisait de poser la flaque là où elle doit être. Ce qui doit
## tomber sur le corps, c'est la **masse**, pas l'enveloppe. Un oracle qui décrit
## un symptôme mesurable au lieu de la propriété voulue passe au vert en
## empêchant la bonne correction.
##
## ⚠️ **La flaque est RE-MESURÉE ici sur les vraies planches**, par transformée
## de distance, et jamais lue dans la table `FLAQUES` que le code utilise. C'est
## tout l'objet du banc : recuire un décal sans corriger cette table doit faire
## rougir, pas déplacer les taches en silence.
##
## ⚠️ **`blood_stain.gd` n'est jamais NOMMÉ, il est chargé par son chemin.**
## Nommer une classe dans un banc lancé par `--script` en fait une dépendance de
## **compilation** : Godot la compile avant que le moindre autoload soit
## enregistré, et le banc ne compile plus. Même piège, même parade que
## `tools/test_bandeau_fatal.gd`.

## Rayon du corps du joueur, en pixels.
##
## **Relevé sur `player.tscn`** — le polygone de collision va de -18 à +18 — et
## non lu sur `bullet.gd::PLAYER_BODY_RADIUS` ni sur `blood_stain.DIAMETRE_CORPS`.
## Le point d'impact étant le bord d'ENTRÉE, le centre du corps est exactement à
## cette distance en aval : c'est là que la flaque est attendue.
const RAYON_CORPS := 18.0

## Tolérance sur ce placement, en pixels. Une flaque de 21 px de rayon posée à
## 8 px près reste franchement sous un corps qui en fait 18 : au-delà, elle
## commence à déborder d'un côté de façon visible.
const TOLERANCE := 8.0

## Seuil d'alpha au-dessus duquel on considère qu'il y a de la matière.
const SEUIL := 0.5

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


## Mesure d'une planche : où est sa plus grosse flaque, et où est sa masse.
##
## « La plus grosse forme rouge assez ronde » se lit : **le centre du plus grand
## disque qui tient dans la matière**. C'est une transformée de distance — on
## calcule, pour chaque pixel plein, sa distance au vide, et on garde le maximum.
## Deux passes de chanfrein (5/7 pour l'orthogonal/diagonal, l'approximation
## classique de la distance euclidienne à 2 % près) suffisent et restent lisibles.
##
## Rend `{ "flaque": Vector2 (fraction), "rayon": px, "masse": Vector2 (fraction) }`,
## ou un dictionnaire vide si la planche est illisible.
func _mesurer(chemin: String) -> Dictionary:
	var tex: Texture2D = load(chemin)
	if tex == null:
		return {}
	var img := tex.get_image()
	var l := img.get_width()
	var h := img.get_height()
	const LOIN := 1 << 20
	var d := PackedInt32Array()
	d.resize(l * h)

	var somme := 0.0
	var pondere := Vector2.ZERO
	for y in range(h):
		for x in range(l):
			var a := img.get_pixel(x, y).a
			somme += a
			pondere += Vector2(x, y) * a
			d[y * l + x] = LOIN if a >= SEUIL else 0

	# Passe avant : haut-gauche vers bas-droite.
	for y in range(h):
		for x in range(l):
			var i := y * l + x
			if d[i] == 0:
				continue
			var v := d[i]
			if y > 0: v = mini(v, d[i - l] + 5)
			if x > 0: v = mini(v, d[i - 1] + 5)
			if y > 0 and x > 0: v = mini(v, d[i - l - 1] + 7)
			if y > 0 and x < l - 1: v = mini(v, d[i - l + 1] + 7)
			d[i] = v
	# Passe arrière : bas-droite vers haut-gauche.
	var meilleur := 0
	var ou := Vector2i.ZERO
	for y in range(h - 1, -1, -1):
		for x in range(l - 1, -1, -1):
			var i := y * l + x
			if d[i] == 0:
				continue
			var v := d[i]
			if y < h - 1: v = mini(v, d[i + l] + 5)
			if x < l - 1: v = mini(v, d[i + 1] + 5)
			if y < h - 1 and x < l - 1: v = mini(v, d[i + l + 1] + 7)
			if y < h - 1 and x > 0: v = mini(v, d[i + l - 1] + 7)
			d[i] = v
			if v > meilleur:
				meilleur = v
				ou = Vector2i(x, y)

	if somme <= 0.0 or meilleur == 0:
		return {}
	return {
		"flaque": (Vector2(ou) + Vector2(0.5, 0.5)) / Vector2(l, h),
		"rayon": float(meilleur) / 5.0,
		"masse": (pondere / somme) / Vector2(l, h),
	}


func _run() -> void:
	print("=== LA GROSSE FLAQUE TOMBE SOUS LE PERSONNAGE ===")
	await process_frame

	# Par chemin, jamais par nom de classe — voir la note en tête de fichier.
	var sang: GDScript = load("res://blood_stain.gd")
	if sang == null:
		printerr("✗ blood_stain.gd introuvable ou ne compile pas")
		quit(1)
		return

	var planches: Array = sang.ECLABOUSSURES
	var mesures := {}

	print("\n[Chaque planche a bien une flaque franche à trouver]")
	for chemin: String in planches:
		var m := _mesurer(chemin)
		mesures[chemin] = m
		_check("%s : une flaque est identifiable" % chemin.get_file(),
			not m.is_empty() and float(m.get("rayon", 0.0)) >= 6.0,
			"planche illisible, vide, ou sans masse franche (lancer --import ?)")
		if not m.is_empty():
			print("      flaque à %.1f %% de la largeur, rayon %.1f px ; masse à %.1f %%"
				% [m["flaque"].x * 100.0, m["rayon"], m["masse"].x * 100.0])

	print("\n[La traînée part dans la direction du tir]")
	# La planche est dessinée pointant vers la droite et `pose()` la tourne dans
	# l'axe de la balle : +X est donc l'aval. Si la masse d'encre est en aval de
	# la flaque, c'est que la queue s'étire derrière l'impact — le sens voulu.
	# Une planche recuite à l'envers, ou ajoutée dans le mauvais sens, échoue ici.
	for chemin: String in planches:
		var m: Dictionary = mesures[chemin]
		if m.is_empty():
			continue
		_check("%s : sa traînée s'étire vers l'aval" % chemin.get_file(),
			m["masse"].x >= m["flaque"].x,
			"masse à %.1f %% mais flaque à %.1f %% — la planche pointe à l'envers"
				% [m["masse"].x * 100.0, m["flaque"].x * 100.0])

	print("\n[Une tache posée en jeu met sa flaque sous le corps]")
	# ⚠️ On monte de VRAIES taches et on laisse `setup()` tirer sa planche au
	# sort, au lieu d'appeler la fonction pure sur des valeurs choisies : ce qui
	# est éprouvé ici est le chemin complet — le tirage, la table `FLAQUES`, la
	# pose, le rectangle — et pas seulement l'arithmétique.
	var arene := Node2D.new()
	arene.name = "AreneDeBanc"
	root.add_child(arene)

	var impact := Vector2(640.0, 360.0)
	var direction := Vector2.RIGHT.rotated(deg_to_rad(30.0))
	var vues := {}
	var derniere: Node2D = null
	# Assez d'essais pour voir les deux planches : la probabilité d'en manquer
	# une est de 2^-29. Un plafond, pas une boucle infinie.
	for essai in range(30):
		var t := Node2D.new()
		t.name = "TacheDeBanc%d" % essai
		t.set_script(sang)
		# Même ordre qu'en jeu (`bullet.gd::_spawn_hit_effects`) : ajouté
		# d'abord, `setup()` ensuite. `_ready()` tourne donc AVANT `setup()`.
		arene.add_child(t)
		t.setup(impact, direction)
		var tex: Texture2D = t.get("_texture")
		if tex == null:
			continue
		var chemin: String = tex.resource_path
		if vues.has(chemin):
			# ⚠️ Libérée, donc PAS retenue comme `derniere` : garder une
			# référence vers une instance en cours de suppression a fait planter
			# ce banc **sans qu'il sorte** — l'erreur levait avant `quit()`, le
			# processus tournait indéfiniment, et le chien de garde du lanceur
			# était seul à s'en apercevoir. Exactement le piège consigné en tête
			# de `tools/test_bandeau_fatal.gd`.
			t.release()
			continue
		vues[chemin] = true
		derniere = t

		var m: Dictionary = mesures.get(chemin, {})
		if m.is_empty():
			continue
		# Ce que `_draw()` dessine réellement, reconstitué pas à pas.
		var taille: Vector2 = tex.get_size() * float(t.get("_echelle")) \
			/ Charte.DENSITE_ASSETS
		var rect: Rect2 = sang.rectangle_de_la_tache(taille, t.get("_ancre"))
		# Où atterrit le centre de la flaque MESURÉE, dans le repère du tir.
		var centre: Vector2 = rect.position + taille * m["flaque"]
		_check("%s : sa flaque tombe sous le corps" % chemin.get_file(),
			absf(centre.x - RAYON_CORPS) <= TOLERANCE
				and absf(centre.y) <= TOLERANCE,
			"flaque à (%.1f, %.1f), attendue à (%.1f, 0) à %.0f px près"
				% [centre.x, centre.y, RAYON_CORPS, TOLERANCE])

		# Et en MONDE : la pose du nœud ne doit pas défaire ce placement.
		var monde: float = (t.global_transform * centre - impact) \
			.dot(direction.normalized())
		_check("%s : et cela tient une fois le nœud tourné" % chemin.get_file(),
			absf(monde - RAYON_CORPS) <= TOLERANCE,
			"%.1f px en aval de l'impact au lieu de %.1f" % [monde, RAYON_CORPS])

	_check("les deux planches ont été exercées", vues.size() == planches.size(),
		"%d sur %d vues en 30 essais" % [vues.size(), planches.size()])

	print("\n[Le nœud réel se pose là où `pose()` le dit]")
	if derniere == null or not is_instance_valid(derniere):
		_check("une tache a survécu pour être inspectée", false,
			"aucune instance vivante")
		printerr("\n✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
		return
	# La boucle fermée : sans ce contrôle, `pose()` pourrait décrire une pose que
	# `setup()` n'applique pas, et tout le reste du banc mesurerait une fiction.
	var attendue: Transform2D = sang.pose(impact, direction)
	_check("le nœud est posé au point d'impact",
		derniere.position.is_equal_approx(attendue.origin),
		"%s au lieu de %s" % [str(derniere.position), str(attendue.origin)])
	_check("et tourné dans l'axe du tir",
		is_equal_approx(derniere.rotation, attendue.get_rotation()),
		"%.4f au lieu de %.4f" % [derniere.rotation, attendue.get_rotation()])

	print("\n[La copie J2 hérite de TOUT ce que `_draw()` lit]")
	# ⚠️ **`duplicate()` ne recopie pas les variables de script.** Le piège a
	# déjà coûté cher exactement ici : sous le dessin procédural, la copie J2
	# naissait avec zéro goutte et **le joueur 2 n'a jamais vu une seule tache**,
	# sans que rien ne le signale. `_ancre` est arrivée avec la règle du
	# 2026-09-07 — c'est très exactement le genre de variable que ce bloc oublie,
	# et son oubli n'aurait dérangé personne d'autre que le joueur 2.
	await process_frame # `_create_p2_duplicate` est différé.
	var copies := get_nodes_in_group("blood_p2")
	_check("chaque tache a sa copie J2", copies.size() == vues.size(),
		"%d copie(s) pour %d tache(s)" % [copies.size(), vues.size()])
	for p2: Node2D in copies:
		var mere: Node2D = null
		for n: Node2D in arene.get_children():
			if n.is_in_group("blood_stain") and n.position.is_equal_approx(p2.position) \
					and n.get("_texture") == p2.get("_texture"):
				mere = n
				break
		if mere == null:
			_check("copie J2 rattachée à son original", false, "orpheline")
			continue
		_check("elle voit le viewport J2 et son ambiance",
			p2.visibility_layer == 4 and p2.light_mask == (1 | 32),
			"couche %d, masque %d" % [p2.visibility_layer, p2.light_mask])
		# Les variables que `_draw()` lit. Une seule de moins et J2 dessine du
		# vide, ou dessine au mauvais endroit — sans rien signaler.
		_check("elle a reçu la planche", p2.get("_texture") == mere.get("_texture"))
		_check("elle a reçu le cœur", p2.get("_coeur") == mere.get("_coeur"))
		_check("elle a reçu l'agrandissement",
			is_equal_approx(float(p2.get("_echelle")), float(mere.get("_echelle"))),
			"%.3f au lieu de %.3f"
				% [float(p2.get("_echelle")), float(mere.get("_echelle"))])
		_check("elle a reçu l'ancre de la flaque",
			(p2.get("_ancre") as Vector2).is_equal_approx(mere.get("_ancre")),
			"%s au lieu de %s" % [str(p2.get("_ancre")), str(mere.get("_ancre"))])
		_check("elle a reçu les gouttes du repli",
			(p2.get("_drops") as Array).size() == (mere.get("_drops") as Array).size())

	print("\n[La table du code correspond aux planches livrées]")
	# Le contrôle qui rend la table `FLAQUES` maintenable : elle est comparée aux
	# planches RÉELLES, mesurées ci-dessus. Recuire un décal en changeant sa
	# composition fait rougir ici, au lieu de décaler les taches en silence.
	var table: Array = sang.FLAQUES
	_check("un centre de flaque par planche", table.size() == planches.size(),
		"%d pour %d planches" % [table.size(), planches.size()])
	for i in range(mini(table.size(), planches.size())):
		var m: Dictionary = mesures[planches[i]]
		if m.is_empty():
			continue
		var ecart: Vector2 = (table[i] as Vector2) - (m["flaque"] as Vector2)
		# En fraction : 2 % de 160 px valent 3 px, sous la tolérance de placement.
		_check("%s : la table dit où est vraiment sa flaque"
				% (planches[i] as String).get_file(),
			ecart.length() <= 0.02,
			"table %s, mesuré %s" % [str(table[i]), str(m["flaque"])])

	if _ko == 0:
		print("\n✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("\n✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
