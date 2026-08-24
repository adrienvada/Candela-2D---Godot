## Voir et être vu dans le noir — le premier test de la mécanique centrale.
##
## L'étude de robustesse du 2026-08-16 relevait le trou et il est resté ouvert :
## « la mécanique centrale du jeu n'a aucun test automatique ; les suites
## s'arrêtent à la géométrie des occluders, très en amont du gameplay ». Trente
## suites couvraient le codec, les menus, le réseau, le classement — et rien ne
## couvrait la seule chose dont dépend l'intérêt du jeu.
##
## Deux moitiés, parce que la règle en a deux :
##
## 1. **Le cône**, pur, sans moteur : la cible est-elle dans le faisceau ?
## 2. **L'occlusion**, dans un vrai monde physique construit par `MapGeometry` :
##    un mur arrête-t-il le faisceau, une fosse le laisse-t-elle passer ?
##
## La seconde moitié compte autant que la première. Un cône juste sur une carte
## sans occlusion donnerait un jeu où l'on se voit à travers les murs — et c'est
## un défaut déjà rencontré ici, consigné dans `map_geometry.gd` : collision et
## occlusion doivent être produites ENSEMBLE, sans quoi la torche traverse.
##
## Lancer : godot --headless --path . --script res://tools/test_vision.gd
extends SceneTree

const Vision := preload("res://vision.gd")

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== VOIR ET ÊTRE VU ===")
	_test_cone()
	_test_intensite()
	_test_intensite_texture()
	await _test_occlusion()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

# ---------------------------------------------------------------------------
# LE CÔNE
# ---------------------------------------------------------------------------

func _test_cone() -> void:
	print("\n[Le faisceau]")
	var origine := Vector2.ZERO
	var avant := Vector2.RIGHT

	_check("droit devant, la cible est éclairée",
		Vision.dans_le_cone(avant, origine, Vector2(100, 0)))
	_check("droit derrière, non",
		not Vision.dans_le_cone(avant, origine, Vector2(-100, 0)))
	_check("perpendiculaire, non",
		not Vision.dans_le_cone(avant, origine, Vector2(0, 100)))

	# La bordure du cône est le réglage d'équilibre : 30° de demi-angle. Un test
	# de part et d'autre fige la valeur — la déplacer sans le vouloir rendrait la
	# torche moins coûteuse à allumer, et c'est tout le jeu qui bouge.
	var dedans := Vector2.RIGHT.rotated(deg_to_rad(29.0)) * 100.0
	var dehors := Vector2.RIGHT.rotated(deg_to_rad(31.0)) * 100.0
	_check("29° est dans le faisceau", Vision.dans_le_cone(avant, origine, dedans))
	_check("31° est hors du faisceau",
		not Vision.dans_le_cone(avant, origine, dehors))
	# Symétrique : un faisceau qui pencherait d'un côté serait un avantage muet
	# pour qui tourne dans le bon sens.
	_check("le cône est symétrique",
		Vision.dans_le_cone(avant, origine, Vector2(dedans.x, -dedans.y))
		and not Vision.dans_le_cone(avant, origine, Vector2(dehors.x, -dehors.y)))

	# L'orientation du porteur compte, pas seulement la position relative.
	_check("tourner le porteur change ce qu'il éclaire",
		Vision.dans_le_cone(Vector2.UP, origine, Vector2(0, -100))
		and not Vision.dans_le_cone(Vector2.UP, origine, Vector2(100, 0)))

	# Entrée dégénérée : deux corps superposés. Un « false » ici voudrait dire
	# qu'une torche n'éclaire pas ce qui est collé à elle.
	_check("superposés, la cible est dans le faisceau",
		Vision.dans_le_cone(avant, origine, origine))

# ---------------------------------------------------------------------------
# L'INTENSITÉ REÇUE — le faisceau n'est pas un interrupteur
# ---------------------------------------------------------------------------

## Ce que la torche verse VRAIMENT dans les yeux d'en face, entre 0 et 1.
##
## `dans_le_cone` seul ne suffisait pas, et c'est ce qui rendait
## l'éblouissement faux même une fois son arithmétique réparée : le cône était
## écrit en dur à 30° pour les quatre armes, et rien ne bornait la distance.
func _test_intensite() -> void:
	print("\n[L'intensité reçue]")
	var avant := Vector2.RIGHT
	var o := Vector2.ZERO
	const PORTEE := 500.0

	_check("dans l'axe et tout près, presque tout passe",
		Vision.intensite_recue(avant, o, Vector2(10, 0), PORTEE) > 0.9)
	_check("plus loin, moins",
		Vision.intensite_recue(avant, o, Vector2(400, 0), PORTEE)
		< Vision.intensite_recue(avant, o, Vector2(100, 0), PORTEE))
	_check("au bout de la portée, plus rien",
		is_zero_approx(Vision.intensite_recue(avant, o, Vector2(PORTEE, 0), PORTEE)))
	# LE contre-test de la portée : sans lui, on éblouissait d'un bout à l'autre
	# de la carte, très au-delà du dernier photon du faisceau.
	_check("et rien non plus bien au-delà",
		is_zero_approx(Vision.intensite_recue(avant, o, Vector2(4000, 0), PORTEE)))
	_check("hors du cône, rien",
		is_zero_approx(Vision.intensite_recue(avant, o, Vector2(0, 300), PORTEE)))
	_check("derrière, rien",
		is_zero_approx(Vision.intensite_recue(avant, o, Vector2(-100, 0), PORTEE)))

	# Le cône vient de l'ARME. Le pompe éclaire à 60° de demi-angle, l'arbalète
	# à 5° : une cible à 40° de l'axe est en plein dans le faisceau du premier
	# et hors de celui du second. Avec la constante de 30° écrite en dur, le
	# pompe n'éblouissait que dans la moitié de sa flaque et l'arbalète
	# éblouissait vingt-cinq degrés au-delà de son trait de lumière.
	var cible := Vector2(cos(deg_to_rad(40.0)), sin(deg_to_rad(40.0))) * 200.0
	_check("le faisceau large du pompe éblouit à 40° de son axe",
		Vision.intensite_recue(avant, o, cible, PORTEE, cos(deg_to_rad(60.0))) > 0.0)
	_check("le trait de l'arbalète, non",
		is_zero_approx(Vision.intensite_recue(avant, o, cible, PORTEE, cos(deg_to_rad(5.0)))))

	# Superposés : plein feu, même raison que dans `dans_le_cone` — un faux
	# silencieux sur une entrée dégénérée ne se remarque jamais.
	_check("deux corps superposés : plein feu",
		is_equal_approx(Vision.intensite_recue(avant, o, o, PORTEE), 1.0))
	_check("une portée nulle n'éblouit personne",
		is_zero_approx(Vision.intensite_recue(avant, o, Vector2(10, 0), 0.0)))

# ---------------------------------------------------------------------------
# L'INTENSITÉ LUE DANS LA TEXTURE — la lecture de production
# ---------------------------------------------------------------------------

## `intensite_recue` ci-dessus n'est plus qu'un repli : le jeu LIT le pixel du
## faisceau. Ces contrôles portent donc sur ce qui tourne réellement.
##
## **Et ils sont écrits pour ne pas être auto-référentiels**, ce qui était le
## défaut des précédents : « 29° dedans, 31° dehors » teste la constante contre
## elle-même et reste vert quelles que soient les armes — il l'est resté pendant
## que les quatre divergeaient. Ici, chaque contrôle confronte l'échantillon à
## une propriété de l'ARME (son angle, sa luminosité, sa portée), jamais à la
## formule qui a servi à peindre l'image.
func _test_intensite_texture() -> void:
	print("\n[L'intensité lue dans la texture]")
	var avant := Vector2.RIGHT
	var o := Vector2.ZERO

	# --- Le repère, sur une image synthétique : rapide, et l'attendu est connu
	# au pixel près. Une vraie texture de torche coûte 262 144 itérations.
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.0))
	img.set_pixel(48, 32, Color(1, 1, 1, 0.5)) # 16 px à droite du centre
	img.set_pixel(32, 48, Color(1, 1, 1, 0.25)) # 16 px « sous » le centre

	# **`is_equal_approx` ne convient pas ici, et les quatre premiers contrôles
	# ont d'abord échoué pour ça.** Un alpha de `FORMAT_RGBA8` est quantifié sur
	# 8 bits : 0,5 en ressort à 128/255 = 0,50196, et `is_equal_approx` compare à
	# ~1e-6. L'échec ressemblait trait pour trait à un repère faux — c'est-à-dire
	# au seul défaut que ces contrôles existent pour attraper. D'où une tolérance
	# nommée, plus large que la quantification et bien plus fine que l'erreur
	# qu'on traque : un repère retourné donne 0,25 au lieu de 0,5, jamais 0,502.
	var lu_est := func(v: float, attendu: float) -> bool: return absf(v - attendu) < 0.01

	_check("le centre de l'image est la position du porteur",
		is_zero_approx(Vision.intensite_texture(img, avant, o, o, 1.0)))
	_check("devant le porteur, on lit le pixel de devant",
		lu_est.call(Vision.intensite_texture(img, avant, o, Vector2(16, 0), 1.0), 0.5))
	# Le sens du repère perpendiculaire : c'est LA ligne où une erreur de signe
	# retournerait le faisceau sans que rien ne le dise, un cône étant symétrique.
	# Sur une image asymétrique, elle se voit.
	_check("le repère perpendiculaire n'est pas retourné",
		lu_est.call(Vision.intensite_texture(img, avant, o, Vector2(0, 16), 1.0), 0.25))
	# La rotation du porteur : mêmes positions relatives, autre orientation.
	_check("tourner le porteur change ce qu'il verse",
		lu_est.call(Vision.intensite_texture(img, Vector2.UP, o, Vector2(0, -16), 1.0), 0.5))

	# --- L'ÉCHELLE VIENT DE L'IMAGE, et c'est un piège consigné : `texture_scale`
	# multiplie la taille PROPRE de la texture, donc un cookie de 1024² porte deux
	# fois plus loin qu'un 512² à `torch_scale` égal. Le contrôle fige la
	# propriété plutôt que la constante.
	_check("à l'échelle 2, le même pixel se lit deux fois plus loin",
		lu_est.call(Vision.intensite_texture(img, avant, o, Vector2(32, 0), 2.0), 0.5))
	_check("hors de l'image, plus rien",
		is_zero_approx(Vision.intensite_texture(img, avant, o, Vector2(1000, 0), 1.0)))
	# Les entrées dégénérées ne doivent pas rendre une pénalité fantôme.
	_check("sans image, rien", is_zero_approx(
		Vision.intensite_texture(null, avant, o, Vector2(16, 0), 1.0)))
	_check("une échelle nulle n'éblouit personne",
		is_zero_approx(Vision.intensite_texture(img, avant, o, Vector2(16, 0), 0.0)))

	# --- Sur de VRAIES textures d'armes : c'est là que se joue ce que la copie
	# manquait.
	#
	# ⚠️ **`torch_cookie` n'est pas décoratif ici.** Depuis DA2.1, l'image n'est
	# plus fabriquée d'après les champs de l'arme : elle est CHARGÉE d'après ce
	# nom. Une arme construite avec les bons angles mais sans son cookie lit
	# celui du pistolet — et le contrôle mesure alors une autre arme que celle
	# qu'il croit décrire. C'est arrivé à la fusion des deux lots : la
	# « luminosité de l'arme » lisait 0,498 au lieu de 0,105, parce que
	# l'arbalète portait le faisceau du pistolet. Les angles et l'échelle
	# restent posés — ils servent à `portee_torche()` et au repli — mais **c'est
	# le nom qui décide des pixels.**
	var arbalete := WeaponData.new()
	arbalete.torch_cookie = "arbalete"
	arbalete.torch_angle_deg = 5.0
	arbalete.torch_scale = 3.5
	arbalete.torch_brightness = 0.3
	var pompe := WeaponData.new()
	pompe.torch_cookie = "pompe"
	pompe.torch_angle_deg = 60.0
	pompe.torch_scale = 1.0

	var img_arb := arbalete.image_torche()
	var img_pompe := pompe.image_torche()
	_check("une arme sait rendre l'image de son faisceau",
		img_arb != null and img_pompe != null)

	# **`torch_brightness` arrive enfin jusqu'à la pénalité.** C'était l'une des
	# trois divergences du 2026-08-24 : l'arbalète a un faisceau trois fois plus
	# sombre que les autres et éblouissait exactement comme le pistolet, parce
	# que la formule ignorait un paramètre qui n'existait que dans l'alpha.
	# Attendu à mi-portée dans l'axe : (1 - 0,5) × fondu(5°) × 0,3.
	var mi_arb: float = arbalete.portee_torche() * 0.5
	var lu: float = Vision.intensite_texture(img_arb, avant, o,
		Vector2(mi_arb, 0), arbalete.echelle_torche())
	var attendu: float = 0.5 * clampf(deg_to_rad(5.0) * 8.0, 0.0, 1.0) * 0.3
	_check("la luminosité de l'arme est dans ce qu'elle inflige (%.3f ≈ %.3f)"
		% [lu, attendu], absf(lu - attendu) < 0.02, "%f vs %f" % [lu, attendu])

	# **Le cône vient de l'arme, sans qu'on le lui demande.** À 40° de l'axe et à
	# la même fraction de portée : en plein dans la flaque du pompe, hors du
	# trait de l'arbalète. Aucune constante n'intervient — c'est le pixel.
	var d_pompe: float = pompe.portee_torche() * 0.5
	var c_pompe := Vector2.RIGHT.rotated(deg_to_rad(40.0)) * d_pompe
	var c_arb := Vector2.RIGHT.rotated(deg_to_rad(40.0)) * mi_arb
	_check("le faisceau large du pompe éblouit à 40° de son axe",
		Vision.intensite_texture(img_pompe, avant, o, c_pompe, pompe.echelle_torche()) > 0.0)
	_check("le trait de l'arbalète, non",
		is_zero_approx(Vision.intensite_texture(img_arb, avant, o, c_arb,
			arbalete.echelle_torche())))

	# **Le halo entre dans le calcul, et il faut le savoir.** La texture porte,
	# outre le cône, un halo faible sur les 20 % proches de l'émetteur et
	# jusqu'à 80° : quelqu'un de collé à une torche allumée EST vu, même hors du
	# faisceau. La formule l'ignorait. Ce contrôle ne juge pas si c'est
	# souhaitable — il empêche que ça change sans que personne le remarque.
	var colle: float = Vision.intensite_texture(img_pompe, avant, o,
		Vector2.RIGHT.rotated(deg_to_rad(75.0)) * (pompe.portee_torche() * 0.1),
		pompe.echelle_torche())
	_check("le halo de proximité éblouit hors du cône (%.3f)" % colle, colle > 0.0)
	_check("mais faiblement", colle < 0.2, str(colle))

# ---------------------------------------------------------------------------
# L'OCCLUSION — dans un vrai monde physique
# ---------------------------------------------------------------------------

## Une carte de 20×20 : sol partout, et une colonne de murs en x = 10.
func _carte_avec_mur() -> Dictionary:
	var sols: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	for x in 20:
		for y in 20:
			if x == 10:
				murs.append(Vector2i(x, y))
			else:
				sols.append(Vector2i(x, y))
	return {
		"grid_size": {"x": 20, "y": 20},
		"floor": MapCodec.encode_runs(sols),
		"walls": MapCodec.encode_runs(murs),
	}

## Même carte, mais la colonne est un TROU dans le sol : ni mur, ni sol, donc
## une fosse. Elle arrête le joueur et laisse passer la lumière.
func _carte_avec_fosse() -> Dictionary:
	var sols: Array[Vector2i] = []
	for x in 20:
		for y in 20:
			if x != 10:
				sols.append(Vector2i(x, y))
	return {
		"grid_size": {"x": 20, "y": 20},
		"floor": MapCodec.encode_runs(sols),
		"walls": "",
	}

func _centre_de(cellule: Vector2i) -> Vector2:
	var t := CandelaTileSet.TILE_SIZE
	return Vector2((cellule.x + 0.5) * t.x, (cellule.y + 0.5) * t.y)

## Le rayon de `game_state._ligne_de_vue` : couche des murs seulement.
func _faisceau_passe(espace: PhysicsDirectSpaceState2D, de: Vector2,
		vers: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(de, vers, MapGeometry.WALL_LAYER)
	return espace.intersect_ray(q).is_empty()

func _test_occlusion() -> void:
	print("\n[L'occlusion]")
	var monde := Node2D.new()
	root.add_child(monde)
	MapGeometry.build_collisions(_carte_avec_mur(), monde)
	# Les corps n'existent pour le serveur physique qu'après un pas de simulation.
	await physics_frame
	await physics_frame
	var espace := monde.get_world_2d().direct_space_state

	var gauche := _centre_de(Vector2i(5, 10))
	var droite := _centre_de(Vector2i(15, 10))
	_check("un mur arrête le faisceau", not _faisceau_passe(espace, gauche, droite))
	# Le contre-test compte autant : sans lui, un masque de collision erroné
	# ferait passer le premier contrôle en bloquant TOUT, y compris le vide.
	var voisin := _centre_de(Vector2i(7, 10))
	_check("sans mur entre eux, le faisceau passe",
		_faisceau_passe(espace, gauche, voisin))
	_check("le mur arrête aussi dans l'autre sens",
		not _faisceau_passe(espace, droite, gauche))

	monde.queue_free()

	# La fosse, elle, laisse passer — décision de conception écrite dans
	# `_ligne_de_vue` : « on peut éblouir son adversaire par-dessus un gouffre ».
	# Elle tient à ce que la fosse soit sur une AUTRE couche et ne produise aucun
	# occluder ; c'est ce que ce contrôle protège.
	var monde2 := Node2D.new()
	root.add_child(monde2)
	MapGeometry.build_collisions(_carte_avec_fosse(), monde2)
	await physics_frame
	await physics_frame
	var espace2 := monde2.get_world_2d().direct_space_state
	_check("une fosse laisse passer le faisceau",
		_faisceau_passe(espace2, gauche, droite))
	# Mais elle arrête bien le joueur : sans ça, « fosse » ne voudrait rien dire.
	var q := PhysicsRayQueryParameters2D.create(gauche, droite,
		MapGeometry.PLAYER_MASK)
	_check("mais elle arrête le joueur",
		not espace2.intersect_ray(q).is_empty())
	monde2.queue_free()
