extends Node2D

## Le banc de la MARCHE — voir la démarche, et juger DA2.4 à l'œil.
##
## Lancer : `godot --path . tools/banc_marche.tscn`
##
## ## Ce que ce banc existe pour montrer
##
## DA2.4 a été livrée sans frames peintes : le corps **roule sur le pied
## porteur**, en translation le long de l'axe local Y, d'amplitude dérivée du
## même accumulateur de distance que le son du pas. Les trente-deux PNG
## `*_marche_*.png` versionnés le 2026-08-27 sont, eux, ceux de la mauvaise
## caméra. **Le banc met les deux côte à côte au lieu de le raconter.**
##
## Trois marcheurs, la même trajectoire, la même vitesse, le même compteur :
##
## 1. **LE JEU** — sprite statique + roulis. Ce que le duel affiche aujourd'hui.
## 2. **PLANCHE, TAILLE NATIVE** — les quatre images peintes jouées sur le même
##    compteur de distance. C'est là que les deux défauts se voient : la caméra
##    (vue oblique contre vue de dessus) et l'échelle (48 px contre 82).
## 3. **PLANCHE, REMISE À L'ÉCHELLE** — les mêmes images ramenées à l'empreinte
##    du sprite statique. Elle **sépare les deux reproches** : ce qui reste
##    faux ici est un problème de caméra, pas de cuisson.
##
## ⚠️ **La ligne de visée est le seul juge de l'obstacle n°2.** Elle part du
## centre dans la direction de `rotation` — l'information la plus chère du jeu.
## Si l'arme peinte pointe ailleurs qu'elle, le sprite ment sur la visée douze
## fois par seconde. C'est l'argument qui a écarté les frames, et il ne se
## tranche pas par le raisonnement : il se regarde.
##
## ## Éclairage
##
## **Le banc est éclairé par défaut, et c'est délibéré.** Le jeu est noir absolu
## et sa `CanvasModulate` rendrait ce banc illisible — on ne juge pas une
## démarche à travers le cône d'une torche. `L` bascule vers l'éclairage du jeu
## quand on veut vérifier que ce qu'on a réglé survit à l'obscurité.
##
## ## Aucun nombre n'est recopié
##
## Le seuil de pas (45 px) et la vitesse (260 px/s) sont **lus dans le texte de
## `player.gd`** au démarrage, et le bandeau dit lesquels il a lus. Un banc qui
## recopierait ces valeurs montrerait une cadence que le jeu n'a plus, sans
## jamais le signaler — c'est exactement le défaut qui a coûté la moitié de son
## effet à `RETARD_REMANENCE` le 2026-08-26. Si la lecture échoue, le bandeau le
## dit en rouge au lieu de retomber sur un défaut silencieux.

const Charte := preload("res://charte.gd")

const SPRITES := "res://assets/sprites/"
const ARMES := ["pistolet", "pompe", "fusil", "arbalete"]
const POSES := 4

## Le roulis, recopié de `player.gd` — mais ces deux-là sont des CONSTANTES
## nommées, pas des littéraux enfouis : un `grep ROULIS_MARCHE` les relie, ce
## qui n'était pas le cas du seuil de pas ni de la vitesse.
const ROULIS_MARCHE := 1.6
const ROULIS_RETOUR := 30.0

const RAYON_TRAJET := 300.0
const LIGNES_Y := [-190.0, 10.0, 210.0]
const PORTEE_VISEE := 110.0

enum Motif { ALLER_RETOUR, CERCLE, IMMOBILE }
const NOMS_MOTIF := ["aller-retour", "cercle", "immobile"]

# --- valeurs lues dans player.gd -------------------------------------------
var _seuil_pas := 45.0
var _vitesse := 260.0
var _lecture_ok := true
var _lecture_detail := ""

# --- état -------------------------------------------------------------------
var _marche := true
var _motif: int = Motif.ALLER_RETOUR
var _arme := 0
var _silhouette := false
var _eclairage_jeu := false
var _visee_libre := false
var _facteur_vitesse := 1.0
var _roulis_sur_planche := true

var _t := 0.0
var _distance := 0.0          ## accumulateur de distance, comme dans player.gd
var _pas := 0                  ## nombre de pas franchis
var _cote := 1                 ## le pied porteur, alterné à chaque pas
var _roulis := 0.0
var _pos_precedente := Vector2.ZERO
var _visee := 0.0

var _marcheurs: Array = []
## Les quatre poses préchargées, avec leur échelle. Recalculées à chaque
## changement d'arme ou de version — jamais dans `_process`. Un `load()` par
## image passe par le cache de Godot et ne se voit pas au profileur, mais il
## cache aussi une erreur de chemin derrière un repli silencieux.
var _poses: Array = []
var _echelles: Array = []
var _legende: Label
var _releve: Label
var _modulate: CanvasModulate


func _ready() -> void:
	_lire_les_valeurs_du_jeu()
	_monter_les_marcheurs()
	_monter_le_bandeau()
	var cam := Camera2D.new()
	cam.name = "Vue"
	add_child(cam)
	cam.make_current()
	_pos_precedente = _position_sur_le_trajet(0.0)


## Lit `player.gd` comme un TEXTE, pas comme une classe : le fichier nomme des
## autoloads, et le charger depuis un banc le rendrait dépendant de l'ordre de
## démarrage pour deux nombres. On veut ces deux nombres, pas le fichier.
func _lire_les_valeurs_du_jeu() -> void:
	var src := FileAccess.get_file_as_string("res://player.gd")
	if src.is_empty():
		_lecture_ok = false
		_lecture_detail = "player.gd illisible"
		return
	var manques := PackedStringArray()
	var seuil := _extraire(src, "var step_dist := ([0-9]+(?:\\.[0-9]+)?)")
	if is_nan(seuil):
		manques.append("seuil de pas")
	else:
		_seuil_pas = seuil
	var vit := _extraire(src, "@export var speed: float = ([0-9]+(?:\\.[0-9]+)?)")
	if is_nan(vit):
		manques.append("vitesse")
	else:
		_vitesse = vit
	if manques.size() > 0:
		_lecture_ok = false
		_lecture_detail = "non lu dans player.gd : " + ", ".join(manques)


func _extraire(src: String, motif: String) -> float:
	var rx := RegEx.new()
	rx.compile(motif)
	var trouve := rx.search(src)
	if trouve == null:
		return NAN
	return float(trouve.get_string(1))


# ---------------------------------------------------------------------------
# LES TROIS MARCHEURS
# ---------------------------------------------------------------------------

func _monter_les_marcheurs() -> void:
	var titres := [
		"LE JEU — sprite statique + roulis sur le pied porteur",
		"PLANCHE PEINTE — taille native (mauvaise caméra ET mauvaise échelle)",
		"PLANCHE PEINTE — remise à l'échelle du sprite statique",
	]
	for i in 3:
		var racine := Node2D.new()
		racine.name = "Marcheur%d" % (i + 1)
		add_child(racine)

		# Sprite2D et non Polygon2D : le jeu passe par un polygone pour ses cinq
		# vues et son occluder ; ici on ne juge que l'image et sa cadence.
		var img := Sprite2D.new()
		img.name = "Image"
		racine.add_child(img)

		var visee := Line2D.new()
		visee.name = "Visee"
		visee.width = 1.5
		visee.default_color = Charte.AMBRE
		visee.points = PackedVector2Array([Vector2.ZERO, Vector2(PORTEE_VISEE, 0.0)])
		racine.add_child(visee)

		var etiquette := Label.new()
		etiquette.name = "Titre"
		etiquette.text = titres[i]
		etiquette.add_theme_font_size_override("font_size", 13)
		etiquette.add_theme_color_override("font_color", Charte.DIM)
		add_child(etiquette)

		_marcheurs.append({"racine": racine, "image": img, "visee": visee,
			"titre": etiquette, "mode": i})
	_charger_les_textures()


func _charger_les_textures() -> void:
	var slug: String = ARMES[_arme]
	var suffixe := "_silhouette" if _silhouette else ""
	var statique := _texture(SPRITES + slug + suffixe + ".png")
	if statique == null:
		push_error("banc_marche : sprite statique absent — %s" % slug)
		return
	var largeur_statique := float(statique.get_width())

	_poses.clear()
	_echelles.clear()
	for pose in range(1, POSES + 1):
		var t := _texture(_chemin_pose(slug, suffixe, pose))
		_poses.append(t)
		# L'échelle se calcule POSE PAR POSE : rien ne garantit que les quatre
		# images d'une planche aient la même largeur, et une échelle prise sur
		# la première ferait respirer le joueur au rythme des poses.
		_echelles.append(largeur_statique / float(t.get_width()) if t != null else 1.0)

	for m in _marcheurs:
		var img: Sprite2D = m["image"]
		if m["mode"] == 0:
			img.texture = statique
			img.scale = Vector2.ONE
		else:
			img.texture = _poses[0] if _poses[0] != null else statique
			img.scale = Vector2.ONE * (_echelles[0] if m["mode"] == 2 else 1.0)


func _chemin_pose(slug: String, suffixe: String, pose: int) -> String:
	# La planche suit `<arme>_marche_<n>` et son `_silhouette` : c'est la
	# convention que `player.gd` attend, et c'est précisément ce qui rend ces
	# fichiers dangereux — ils sont câblables par accident.
	return SPRITES + "%s_marche_%d%s.png" % [slug, pose, suffixe]


func _texture(chemin: String) -> Texture2D:
	if not ResourceLoader.exists(chemin):
		return null
	return load(chemin)


# ---------------------------------------------------------------------------
# LE BANDEAU
# ---------------------------------------------------------------------------

func _monter_le_bandeau() -> void:
	var couche := CanvasLayer.new()
	couche.name = "Bandeau"
	add_child(couche)

	_legende = Label.new()
	_legende.position = Vector2(18, 14)
	_legende.add_theme_font_size_override("font_size", 13)
	_legende.add_theme_color_override("font_color", Charte.DIM)
	_legende.text = ("ESPACE marche/arrêt   M motif   TAB / 1-4 arme   O roulis planche   S peint/silhouette   "
		+ "L éclairage du jeu   A visée libre   +/- vitesse   R reset   ÉCHAP quitter")
	couche.add_child(_legende)

	_releve = Label.new()
	_releve.position = Vector2(18, 38)
	_releve.add_theme_font_size_override("font_size", 14)
	_releve.add_theme_color_override("font_color", Charte.HALOGENE)
	couche.add_child(_releve)


# ---------------------------------------------------------------------------
# LA BOUCLE
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _marche:
		_t += delta * _facteur_vitesse

	var pos := _position_sur_le_trajet(_t)
	var parcouru := pos.distance_to(_pos_precedente)
	_pos_precedente = pos

	# Le compteur du jeu, à l'identique : une DISTANCE, jamais une horloge.
	# C'est ce qui fait tomber ensemble le son, l'empreinte et le roulis.
	if parcouru > 0.001:
		_distance += parcouru
		while _distance >= _seuil_pas:
			_distance -= _seuil_pas
			_pas += 1
			_cote = -_cote

	var vise_roulis := 0.0
	if parcouru > 0.001:
		vise_roulis = sin(_distance / _seuil_pas * PI) * ROULIS_MARCHE * float(_cote)
	_roulis = move_toward(_roulis, vise_roulis, ROULIS_RETOUR * delta)

	var direction := _direction_sur_le_trajet(_t)
	if _visee_libre:
		var souris := get_global_mouse_position()
		_visee = (souris - pos).angle()
	else:
		_visee = direction

	var pose := (_pas % POSES) + 1
	for m in _marcheurs:
		var racine: Node2D = m["racine"]
		var img: Sprite2D = m["image"]
		racine.position = Vector2(pos.x, LIGNES_Y[int(m["mode"])] + pos.y)
		racine.rotation = _visee
		# Le roulis est une TRANSLATION le long de l'axe local Y.
		img.position.y = _roulis if (m["mode"] == 0 or _roulis_sur_planche) else 0.0
		if m["mode"] != 0 and _poses.size() == POSES:
			var t: Texture2D = _poses[pose - 1]
			if t != null:
				img.texture = t
				img.scale = Vector2.ONE * (_echelles[pose - 1] if m["mode"] == 2 else 1.0)
		var titre: Label = m["titre"]
		titre.position = Vector2(-RAYON_TRAJET - 60.0,
			LIGNES_Y[int(m["mode"])] - 76.0)

	_rafraichir_le_releve(pose)
	queue_redraw()


func _position_sur_le_trajet(t: float) -> Vector2:
	var v := _vitesse
	match _motif:
		Motif.IMMOBILE:
			return Vector2.ZERO
		Motif.CERCLE:
			var ang := t * v / RAYON_TRAJET
			return Vector2(cos(ang), sin(ang) * 0.35) * RAYON_TRAJET
		_:
			# Aller-retour à vitesse CONSTANTE — une sinusoïde ralentirait aux
			# extrémités et la cadence des pas y mentirait.
			var periode := 4.0 * RAYON_TRAJET / v
			var phase := fmod(t, periode) / periode
			var x := (phase * 4.0 - 1.0) if phase < 0.5 else (3.0 - phase * 4.0)
			return Vector2(x * RAYON_TRAJET, 0.0)


func _direction_sur_le_trajet(t: float) -> float:
	var a := _position_sur_le_trajet(t)
	var b := _position_sur_le_trajet(t + 0.02)
	var d := b - a
	return d.angle() if d.length() > 0.001 else _visee


func _rafraichir_le_releve(pose: int) -> void:
	var etat := "marche" if _marche else "ARRÊT"
	var source := "lus dans player.gd" if _lecture_ok else "⚠ " + _lecture_detail
	_releve.add_theme_color_override("font_color",
		Charte.HALOGENE if _lecture_ok else Charte.ROUGE)
	_releve.text = ("%s · %s · %s · %s%s · %.0f px/s (×%.2f) · roulis planche: %s"
		% [etat, NOMS_MOTIF[_motif], ARMES[_arme],
			"silhouette" if _silhouette else "peint",
			" · éclairage du jeu" if _eclairage_jeu else "",
			_vitesse * _facteur_vitesse, _facteur_vitesse,
			"OUI" if _roulis_sur_planche else "NON (planches pures)"]
		+ "\nseuil %0.0f px (%s) · pas n°%d · pied %s · accumulé %5.1f px · roulis %+.2f · image %d/%d"
		% [_seuil_pas, source, _pas, "gauche" if _cote > 0 else "droit",
			_distance, _roulis, pose, POSES])


# ---------------------------------------------------------------------------
# LE DÉCOR — une grille au PAS, pas une grille décorative
# ---------------------------------------------------------------------------

func _draw() -> void:
	var demi := Vector2(RAYON_TRAJET + 160.0, 330.0)
	draw_rect(Rect2(-demi, demi * 2.0), Charte.SOL_B)

	var x := -demi.x
	while x <= demi.x:
		var fort := absf(fmod(x, _seuil_pas * 4.0)) < 0.5
		draw_line(Vector2(x, -demi.y), Vector2(x, demi.y),
			Charte.SOL_A if fort else Charte.SOL_A_ARETE, 1.0)
		x += _seuil_pas
	for y in LIGNES_Y:
		draw_line(Vector2(-demi.x, y), Vector2(demi.x, y), Charte.SOL_A, 1.0)


# ---------------------------------------------------------------------------
# LES COMMANDES
# ---------------------------------------------------------------------------

func _unhandled_input(evt: InputEvent) -> void:
	if not (evt is InputEventKey) or not evt.pressed or evt.echo:
		return
	var key_ev := evt as InputEventKey
	var kc := key_ev.keycode
	var pk := key_ev.physical_keycode
	
	match kc:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			_marche = not _marche
		KEY_M:
			_motif = (_motif + 1) % NOMS_MOTIF.size()
			_remettre_a_zero()
		KEY_S:
			_silhouette = not _silhouette
			_charger_les_textures()
		KEY_O:
			_roulis_sur_planche = not _roulis_sur_planche
		KEY_L:
			_basculer_eclairage()
		KEY_A:
			_visee_libre = not _visee_libre
		KEY_R:
			_remettre_a_zero()
		KEY_TAB:
			_arme = (_arme + 1) % ARMES.size()
			_charger_les_textures()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_facteur_vitesse = minf(_facteur_vitesse + 0.25, 3.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_facteur_vitesse = maxf(_facteur_vitesse - 0.25, 0.25)
		_:
			if pk >= KEY_1 and pk <= KEY_4:
				_arme = pk - KEY_1
				_charger_les_textures()
			elif pk >= KEY_KP_1 and pk <= KEY_KP_4:
				_arme = pk - KEY_KP_1
				_charger_les_textures()
			elif kc >= KEY_1 and kc <= KEY_4:
				_arme = kc - KEY_1
				_charger_les_textures()
			elif kc >= KEY_KP_1 and kc <= KEY_KP_4:
				_arme = kc - KEY_KP_1
				_charger_les_textures()
			else:
				var txt := key_ev.as_text()
				if txt == "1" or txt == "&":
					_arme = 0
					_charger_les_textures()
				elif txt == "2" or txt == "é" or txt == "É":
					_arme = 1
					_charger_les_textures()
				elif txt == "3" or txt == '"':
					_arme = 2
					_charger_les_textures()
				elif txt == "4" or txt == "'":
					_arme = 3
					_charger_les_textures()


func _remettre_a_zero() -> void:
	_t = 0.0
	_distance = 0.0
	_pas = 0
	_cote = 1
	_roulis = 0.0
	_pos_precedente = _position_sur_le_trajet(0.0)


## L'éclairage du jeu, à la demande. Une `CanvasModulate` presque noire plus une
## lampe par marcheur : ce n'est pas la torche du duel, c'est de quoi vérifier
## qu'une démarche réglée en pleine lumière tient encore dans le noir.
func _basculer_eclairage() -> void:
	_eclairage_jeu = not _eclairage_jeu
	if _eclairage_jeu:
		_modulate = CanvasModulate.new()
		_modulate.name = "NoirDuJeu"
		_modulate.color = Color(0.10, 0.10, 0.11)
		add_child(_modulate)
		for m in _marcheurs:
			var lampe := PointLight2D.new()
			lampe.name = "Lampe"
			lampe.texture = _texture_de_halo()
			lampe.energy = 1.4
			lampe.color = Charte.HALOGENE
			lampe.texture_scale = 1.6
			(m["racine"] as Node2D).add_child(lampe)
	else:
		if _modulate != null:
			_modulate.queue_free()
			_modulate = null
		for m in _marcheurs:
			var racine: Node2D = m["racine"]
			if racine.has_node("Lampe"):
				racine.get_node("Lampe").queue_free()


func _texture_de_halo() -> Texture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
