class_name IntroPlanches
extends CanvasLayer

## DA6.6 — L'intro narrative cinématique (Style Roman Graphique Brutaliste).
##
## Un homme arrive dans un lieu souterrain sans qu'on sache pourquoi, s'équipe,
## allume sa torche, et découvre que le faisceau qui lui montre l'adversaire
## dessine son ombre sur le mur. Le storyboard complet est dans
## `docs/INTRO_PLANCHES.md` ; ce fichier en assure la mise en scène grand spectacle.
##
## ## Évolution Cinématique « Rendu Très Cher » & Google Flow / Veo 3.1
##
## 1. **Moteur Hybride Vidéo & Motion Comic** :
##    Supporte nativement les cinématiques générées via Google Flow / Veo 3.1
##    (`.ogv` / `VideoStreamTheora`). Si une vidéo est absente, bascule
##    immédiatement et de façon transparente sur l'animation 2.5D Ken Burns
##    des illustrations haute résolution.
##
## 2. **Transitions à double tampon (Cross-Dissolve continu)** :
##    Deux slots (`_slots[0]` et `_slots[1]`) alternent à chaque planche.
##    L'image ou la vidéo sortante s'estompe sous la nouvelle, évitant
##    toute coupure au noir intempestive.
##    - Transition Planche 3 → 4 (Allumage) : claquement d'interrupteur,
##      flash lumineux et micro-secousse de cadre.
##    - Transition Planche 5 → 6 (Extinction) : coupure franche au noir
##      d'encre, focalisation sur la braise mourante.
##
## 3. **Typographie et titres haute couture** :
##    Cartouche roman graphique d'encre sombre, filets d'or ambré et coins
##    de massicot. Titres gravés en *Big Shoulders Display* avec tracking étendu
##    (11 px), incandescence halogène et décélération majestueuse.
##
## 4. **Sound design synchronisé** :
##    Ambiance souterraine, claquements mécaniques de torche (`torch_on`,
##    `torch_off`), frappes d'imprimerie lourdes sur les textes, et montée du logo.
##
## 5. **Chute & Climax : Le Wordmark CANDELA** :
##    Ferme DA6.5 en révélant le wordmark incandescent officiel avec son halo
##    additif avant de passer la main au menu principal.

signal terminee

const Charte := preload("res://charte.gd")

## La couche : au-dessus de `ui.gd`, qui vit en couche 1 par défaut.
const COUCHE := 128

## Durée standard d'une planche (environ 15 s au total pour les 6 planches).
const DUREE_PLANCHE := 2.5

## Durée du fondu croisé cinématographique entre deux planches.
const DUREE_FONDU := 0.55

## Durée de la révélation finale du wordmark CANDELA.
const DUREE_WORDMARK := 2.6

## Fraction de la largeur d'écran occupée par le wordmark.
const PART_ENSEIGNE := 0.44

## Les six planches, dans l'ordre canonique, avec liens vidéos Veo 3.1.
const PLANCHES: Array[Dictionary] = [
	{
		"image": "res://assets/ui/ill_intro_descente.png",
		"video": "res://assets/video/intro/01_descente.ogv",
		"duree": 2.4,
		"texte": "",
	},
	{
		"image": "res://assets/ui/ill_intro_seuil.png",
		"video": "res://assets/video/intro/02_seuil.ogv",
		"duree": 2.0,
		"texte": "",
	},
	{
		"image": "res://assets/ui/ill_intro_dotation.png",
		"video": "res://assets/video/intro/03_dotation.ogv",
		"duree": 2.4,
		"texte": "",
	},
	{
		"image": "res://assets/ui/ill_intro_allumage.png",
		"video": "res://assets/video/intro/04_allumage.ogv",
		"duree": 2.0,
		"texte": "",
	},
	{
		"image": "res://assets/ui/ill_intro_prix.png",
		"video": "res://assets/video/intro/05_prix.ogv",
		"duree": 2.6,
		"texte": "VOIR SANS ÊTRE VU.",
	},
	{
		"image": "res://assets/ui/ill_intro_extinction.png",
		"video": "res://assets/video/intro/06_extinction.ogv",
		"duree": 2.6,
		"texte": "TUER SANS ÊTRE TUÉ.",
	},
]

## Mouvements caméra 2.5D (Ken Burns) utilisés en fallback ou modulation.
const MOTIONS: Array[Dictionary] = [
	{"scale_deb": 1.04, "scale_fin": 1.00, "pos_deb": Vector2(0.0, -18.0), "pos_fin": Vector2(0.0, 12.0)},
	{"scale_deb": 1.00, "scale_fin": 1.05, "pos_deb": Vector2(0.0, 0.0), "pos_fin": Vector2(-12.0, -6.0)},
	{"scale_deb": 1.04, "scale_fin": 1.00, "pos_deb": Vector2(16.0, -6.0), "pos_fin": Vector2(-16.0, 6.0)},
	{"scale_deb": 1.03, "scale_fin": 1.00, "pos_deb": Vector2(0.0, 0.0), "pos_fin": Vector2(-10.0, 0.0)},
	{"scale_deb": 1.05, "scale_fin": 1.00, "pos_deb": Vector2(-15.0, 0.0), "pos_fin": Vector2(15.0, 0.0)},
	{"scale_deb": 1.02, "scale_fin": 1.00, "pos_deb": Vector2(0.0, 0.0), "pos_fin": Vector2(0.0, 6.0)},
]

var _fond: ColorRect
var _pivot_camera: Control
var _slots: Array[_SlotPlanche] = []
var _slot_actif: int = 0
var _image: TextureRect
var _cadre: MenuComicPanel
var _particules: MenuParticlesAmbiance

var _cartouche_titre: _CartoucheGraphique
var _ombre_lettrage: Label
var _lettrage: Label

var _wordmark_hote: Control
var _wordmark_halo: _Halo
var _wordmark_image: TextureRect

var _indice: Label

var _index := -1
var _reste := 0.0
var _temps := 0.0
var _en_cours := false
var _en_climax := false
var _fondu: Tween
var _motion_tweens: Array[Tween] = [null, null]


## Vrai si les six planches sont présentes sur le disque.
static func disponible() -> bool:
	for planche in PLANCHES:
		if not ResourceLoader.exists(String(planche.get("image", ""))):
			return false
	return true


func _init() -> void:
	name = "IntroPlanches"
	layer = COUCHE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construire()
	set_process(false)


func _construire() -> void:
	_fond = ColorRect.new()
	_fond.name = "Fond"
	_fond.color = Charte.NOIR
	_fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fond)

	_pivot_camera = Control.new()
	_pivot_camera.name = "PivotCamera"
	_pivot_camera.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pivot_camera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pivot_camera)

	_slots.clear()
	for i in 2:
		var slot := _SlotPlanche.new()
		slot.name = "SlotPlanche_%d" % i
		slot.modulate.a = 0.0
		slot.texture_rect.material = _fabriquer_materiau()
		_pivot_camera.add_child(slot)
		_slots.append(slot)

	_image = _slots[0].texture_rect

	_particules = MenuParticlesAmbiance.new()
	_particules.name = "ParticulesIntro"
	_particules.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_particules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particules)

	_cadre = MenuComicPanel.new()
	add_child(_cadre)

	# Cartouche typographique façon roman graphique haute couture
	_cartouche_titre = _CartoucheGraphique.new()
	_cartouche_titre.name = "CartoucheTitre"
	_cartouche_titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartouche_titre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cartouche_titre.offset_left = -460.0
	_cartouche_titre.offset_right = 460.0
	_cartouche_titre.offset_top = -140.0
	_cartouche_titre.offset_bottom = -72.0
	_cartouche_titre.modulate.a = 0.0
	add_child(_cartouche_titre)

	var fonte: Font = null
	if ResourceLoader.exists(Charte.CHEMIN_DISPLAY):
		fonte = load(Charte.CHEMIN_DISPLAY) as Font

	_ombre_lettrage = Label.new()
	_ombre_lettrage.name = "OmbreLettrage"
	_ombre_lettrage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ombre_lettrage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ombre_lettrage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ombre_lettrage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ombre_lettrage.offset_top = 2.0
	_ombre_lettrage.offset_bottom = 2.0
	_ombre_lettrage.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.95))
	_ombre_lettrage.add_theme_font_size_override("font_size", 46)
	_ombre_lettrage.add_theme_constant_override("character_spacing", 11)
	if fonte != null:
		_ombre_lettrage.add_theme_font_override("font", fonte)
	_cartouche_titre.add_child(_ombre_lettrage)

	_lettrage = Label.new()
	_lettrage.name = "Lettrage"
	_lettrage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lettrage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lettrage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lettrage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lettrage.add_theme_color_override("font_color", Charte.HALOGENE)
	_lettrage.add_theme_font_size_override("font_size", 46)
	_lettrage.add_theme_constant_override("character_spacing", 11)
	if fonte != null:
		_lettrage.add_theme_font_override("font", fonte)
	_cartouche_titre.add_child(_lettrage)

	# Climax Wordmark CANDELA (ferme DA6.5)
	_wordmark_hote = Control.new()
	_wordmark_hote.name = "WordmarkHote"
	_wordmark_hote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wordmark_hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wordmark_hote.modulate.a = 0.0
	add_child(_wordmark_hote)

	_wordmark_halo = _Halo.new()
	_wordmark_halo.name = "WordmarkHalo"
	_wordmark_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wordmark_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wordmark_hote.add_child(_wordmark_halo)

	if ResourceLoader.exists(Charte.CHEMIN_ENSEIGNE):
		_wordmark_image = TextureRect.new()
		_wordmark_image.name = "WordmarkImage"
		_wordmark_image.texture = load(Charte.CHEMIN_ENSEIGNE) as Texture2D
		_wordmark_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_wordmark_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_wordmark_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_wordmark_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ecran := _ecran()
		var largeur := ecran.x * PART_ENSEIGNE
		var marge_h := (ecran.x - largeur) * 0.5
		_wordmark_image.offset_left = marge_h
		_wordmark_image.offset_right = -marge_h
		_wordmark_image.modulate = Color(Charte.HALOGENE, 0.0)
		_wordmark_hote.add_child(_wordmark_image)

	# Indice permanent de sortie immédiate
	_indice = Label.new()
	_indice.name = "IndicePasser"
	_indice.text = "UNE TOUCHE POUR PASSER"
	_indice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_indice.offset_left = -360.0
	_indice.offset_top = -56.0
	_indice.offset_right = -Charte.GAP_L
	_indice.offset_bottom = -Charte.GAP_L
	_indice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_indice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indice.add_theme_color_override("font_color", Charte.DIM)
	_indice.add_theme_font_size_override("font_size", 14)
	add_child(_indice)


func _ecran() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)


func _fabriquer_materiau() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := load("res://menu_artwork.gdshader") as Shader
	if shader == null:
		return mat
	mat.shader = shader
	mat.set_shader_parameter("mode_flou_total", 0.0)
	mat.set_shader_parameter("ambient_exposure", 0.28)
	mat.set_shader_parameter("torch_radius", 0.45)
	mat.set_shader_parameter("torch_intensity", 1.0)
	mat.set_shader_parameter("reveal_progress", 1.0)
	mat.set_shader_parameter("effect_strength", 1.0)
	return mat


# ---------------------------------------------------------------------------
# Déroulé cinématographique
# ---------------------------------------------------------------------------

## Joue la séquence narrative.
func jouer() -> void:
	if _en_cours:
		return
	_en_cours = true
	_en_climax = false
	_index = -1
	_temps = 0.0
	_wordmark_hote.modulate.a = 0.0
	_cartouche_titre.modulate.a = 0.0
	for slot in _slots:
		slot.modulate.a = 0.0
		slot.arreter_video()
	show()
	set_process(true)
	_jouer_son("res://assets/audio/sfx/ambience_01.wav")
	_planche_suivante()


## Vrai si la séquence est en cours de lecture.
func en_cours() -> bool:
	return _en_cours


func _planche_suivante() -> void:
	_index += 1
	if _index >= PLANCHES.size():
		_lancer_climax_wordmark()
		return

	var planche: Dictionary = PLANCHES[_index]
	var chemin_image := String(planche.get("image", ""))
	if not ResourceLoader.exists(chemin_image):
		push_warning("IntroPlanches : planche absente, sautée — " + chemin_image)
		_planche_suivante()
		return

	# Alternance de slots pour fondu croisé fluide et ininterrompu
	var idx_sortant := _slot_actif
	var idx_entrant := 1 - _slot_actif
	_slot_actif = idx_entrant

	var slot_sortant: _SlotPlanche = _slots[idx_sortant]
	var slot_entrant: _SlotPlanche = _slots[idx_entrant]
	_image = slot_entrant.texture_rect

	# Configuration de l'image de base
	slot_entrant.texture_rect.texture = load(chemin_image) as Texture2D
	var cle := MenuArtwork.cle_canonique(chemin_image)
	var mat := slot_entrant.texture_rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("torch_pos", MenuArtwork.poi_pour(cle))
		mat.set_shader_parameter("effect_mode", MenuArtwork.effet_pour(cle))
		mat.set_shader_parameter("torch_intensity", 1.0)

	# Gestion vidéo Veo 3.1 / Google Flow
	var chemin_video := String(planche.get("video", ""))
	var a_video := false
	if chemin_video != "" and ResourceLoader.exists(chemin_video):
		var flux := load(chemin_video) as VideoStream
		if flux != null:
			slot_entrant.jouer_video(flux)
			a_video = true
	if not a_video:
		slot_entrant.arreter_video()
		_appliquer_motion(idx_entrant, _index)
	else:
		slot_entrant.scale = Vector2.ONE
		slot_entrant.position = Vector2.ZERO

	if _particules != null:
		_particules.definir_illustration(cle)

	var duree_planche: float = float(planche.get("duree", DUREE_PLANCHE))
	_reste = duree_planche

	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = create_tween()
	_fondu.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fondu.set_parallel(true)

	# Transitions visuelles et sonores spécifiques
	if _index == 3:
		# L'ALLUMAGE : impact franc du cône sur le béton, flash et secousse
		_jouer_son("torch_on")
		if mat != null:
			mat.set_shader_parameter("torch_intensity", 2.2)
			Charte.animer_via(_fondu, func(v: float) -> void:
				if is_instance_valid(mat):
					mat.set_shader_parameter("torch_intensity", v)
			, 2.2, 1.0, 0.35, Charte.Courbe.EXTINCTION)
		_secousse_camera(slot_entrant)
		slot_entrant.modulate.a = 0.0
		Charte.animer(_fondu, slot_entrant, "modulate:a", 0.0, 1.0, 0.2, Charte.Courbe.ENTREE)
		Charte.animer(_fondu, slot_sortant, "modulate:a", slot_sortant.modulate.a, 0.0, 0.25, Charte.Courbe.SORTIE)
	elif _index == 5:
		# L'EXTINCTION : coupe nette au noir, la torche s'éteint, survie de la braise
		_jouer_son("torch_off")
		slot_sortant.modulate.a = 0.0
		slot_sortant.arreter_video()
		slot_entrant.modulate.a = 0.0
		Charte.animer(_fondu, slot_entrant, "modulate:a", 0.0, 1.0, DUREE_FONDU, Charte.Courbe.ENTREE)
	else:
		# Fondu croisé continu sans rupture noire
		slot_entrant.modulate.a = 0.0
		Charte.animer(_fondu, slot_entrant, "modulate:a", 0.0, 1.0, DUREE_FONDU, Charte.Courbe.ENTREE)
		Charte.animer(_fondu, slot_sortant, "modulate:a", slot_sortant.modulate.a, 0.0, DUREE_FONDU, Charte.Courbe.SORTIE)

	_fondu.chain().tween_callback(func() -> void:
		slot_sortant.arreter_video()
	)

	# Mise en scène du titre / cartouche
	var texte := String(planche.get("texte", ""))
	_lettrage.text = texte
	_ombre_lettrage.text = texte
	if texte != "":
		_cartouche_titre.modulate.a = 0.0
		_cartouche_titre.scale = Vector2(0.96, 0.96)
		_cartouche_titre.pivot_offset = _cartouche_titre.size * 0.5
		Charte.animer(_fondu, _cartouche_titre, "modulate:a", 0.0, 1.0, 0.5, Charte.Courbe.ENTREE) \
			.set_delay(DUREE_FONDU)
		Charte.animer(_fondu, _cartouche_titre, "scale", Vector2(0.96, 0.96), Vector2(1.0, 1.0), 0.7, Charte.Courbe.ENTREE) \
			.set_delay(DUREE_FONDU)
		_fondu.tween_callback(func() -> void:
			_jouer_son("ui_presse")
		).set_delay(DUREE_FONDU)
	else:
		if _cartouche_titre.modulate.a > 0.0:
			Charte.animer(_fondu, _cartouche_titre, "modulate:a", _cartouche_titre.modulate.a, 0.0, 0.3, Charte.Courbe.SORTIE)

	if _cadre != null:
		_cadre.reveler(1.0, DUREE_FONDU)


func _lancer_climax_wordmark() -> void:
	if not ResourceLoader.exists(Charte.CHEMIN_ENSEIGNE):
		_terminer()
		return

	_en_climax = true
	_reste = DUREE_WORDMARK

	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = create_tween()
	_fondu.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fondu.set_parallel(true)

	# Effacement doux du titre et des planches au profit du noir absolu
	Charte.animer(_fondu, _cartouche_titre, "modulate:a", _cartouche_titre.modulate.a, 0.0, 0.4, Charte.Courbe.SORTIE)
	for slot in _slots:
		Charte.animer(_fondu, slot, "modulate:a", slot.modulate.a, 0.0, 0.6, Charte.Courbe.SORTIE)
		slot.arreter_video()

	_wordmark_hote.modulate.a = 1.0
	_wordmark_hote.scale = Vector2(0.95, 0.95)
	_wordmark_hote.pivot_offset = _ecran() * 0.5
	Charte.animer(_fondu, _wordmark_hote, "scale", Vector2(0.95, 0.95), Vector2(1.0, 1.0), DUREE_WORDMARK, Charte.Courbe.ENTREE)

	# Montée incandescente du filament du mot CANDELA
	Charte.animer_via(_fondu, func(v: float) -> void:
		if is_instance_valid(_wordmark_image):
			_wordmark_image.modulate = Color(Charte.HALOGENE, clampf(v, 0.0, 1.0))
		if is_instance_valid(_wordmark_halo):
			_wordmark_halo.energie = v
	, 0.0, 1.35, 1.1, Charte.Courbe.ENTREE)

	_jouer_son("ui_power_on")


func _appliquer_motion(idx_slot: int, idx_planche: int) -> void:
	if idx_planche < 0 or idx_planche >= MOTIONS.size():
		return
	var slot := _slots[idx_slot]
	var m: Dictionary = MOTIONS[idx_planche]
	var ecran := _ecran()
	slot.pivot_offset = ecran * 0.5

	var scale_deb: float = m.get("scale_deb", 1.0)
	var scale_fin: float = m.get("scale_fin", 1.0)
	var pos_deb: Vector2 = m.get("pos_deb", Vector2.ZERO)
	var pos_fin: Vector2 = m.get("pos_fin", Vector2.ZERO)

	slot.scale = Vector2(scale_deb, scale_deb)
	slot.position = pos_deb

	if _motion_tweens[idx_slot] != null and _motion_tweens[idx_slot].is_valid():
		_motion_tweens[idx_slot].kill()

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	Charte.animer(tw, slot, "scale", Vector2(scale_deb, scale_deb), Vector2(scale_fin, scale_fin), DUREE_PLANCHE, Charte.Courbe.ENTREE)
	Charte.animer(tw, slot, "position", pos_deb, pos_fin, DUREE_PLANCHE, Charte.Courbe.ENTREE)
	_motion_tweens[idx_slot] = tw


func _secousse_camera(slot: Control) -> void:
	var tw_shake := create_tween()
	tw_shake.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var base := slot.position
	tw_shake.tween_property(slot, "position", base + Vector2(4.0, -3.0), 0.04)
	tw_shake.tween_property(slot, "position", base + Vector2(-3.0, 2.0), 0.04)
	tw_shake.tween_property(slot, "position", base + Vector2(2.0, -1.0), 0.04)
	tw_shake.tween_property(slot, "position", base, 0.04)


func _process(delta: float) -> void:
	if not _en_cours:
		return
	_temps += delta

	var taille := _ecran()
	var souris_norm := Vector2(0.5, 0.5)
	if taille.x > 0.0 and taille.y > 0.0:
		var souris := get_viewport().get_mouse_position()
		souris_norm = souris / taille

	for slot in _slots:
		var mat := slot.texture_rect.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("effect_time", _temps)
			mat.set_shader_parameter("torch_pos", souris_norm)

	if _cadre != null:
		_cadre.set_torch_position_global(get_viewport().get_mouse_position())

	_reste -= delta
	if _reste <= 0.0:
		if _en_climax:
			_terminer()
		else:
			_planche_suivante()


func _unhandled_input(event: InputEvent) -> void:
	if not _en_cours:
		return
	var appui := false
	if event is InputEventKey:
		appui = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		appui = event.pressed
	elif event is InputEventJoypadButton:
		appui = event.pressed
	if appui:
		get_viewport().set_input_as_handled()
		_terminer()


func _terminer() -> void:
	if not _en_cours:
		return
	_en_cours = false
	_en_climax = false
	set_process(false)
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	for tw in _motion_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	for slot in _slots:
		slot.arreter_video()
	hide()
	terminee.emit()


func _jouer_son(nom_ou_chemin: String) -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var tree := vp.get_tree()
	if tree == null or tree.root == null:
		return
	var am: Node = tree.root.get_node_or_null("AudioManager")
	if am != null and am.has_method("play_ui"):
		am.play_ui(nom_ou_chemin)


# ---------------------------------------------------------------------------
# Composants d'habillage graphique
# ---------------------------------------------------------------------------

## Conteneur pour une planche : combine le TextureRect sous-jacent et le VideoStreamPlayer.
class _SlotPlanche extends Control:
	var texture_rect: TextureRect
	var video_player: VideoStreamPlayer

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		texture_rect = TextureRect.new()
		texture_rect.name = "Texture"
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(texture_rect)

		video_player = VideoStreamPlayer.new()
		video_player.name = "Video"
		video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video_player.expand = true
		video_player.loop = false
		video_player.volume_db = -80.0
		video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
		video_player.hide()
		add_child(video_player)

	func jouer_video(flux: VideoStream) -> void:
		if flux != null:
			video_player.stream = flux
			video_player.show()
			video_player.play()
		else:
			arreter_video()

	func arreter_video() -> void:
		video_player.stop()
		video_player.hide()


## Cartouche texturé de roman graphique avec filets d'or ambré et repères de coupe.
class _CartoucheGraphique extends Control:
	const TAILLE_ONGLET := 7.0
	const COULEUR_FOND := Color(0.015, 0.015, 0.02, 0.88)
	const COULEUR_FILET := Color(0.96, 0.69, 0.24, 0.65)
	const COULEUR_ACCENT := Color(0.96, 0.69, 0.24, 0.95)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		# Plaque sombre d'encre de chine
		draw_rect(Rect2(Vector2.ZERO, size), COULEUR_FOND, true)

		# Filets horizontaux fins
		draw_line(Vector2.ZERO, Vector2(size.x, 0.0), COULEUR_FILET, 1.0)
		draw_line(Vector2(0.0, size.y), Vector2(size.x, size.y), COULEUR_FILET, 1.0)

		# Onglets de massicot aux quatre angles
		draw_line(Vector2.ZERO, Vector2(0.0, TAILLE_ONGLET), COULEUR_ACCENT, 1.5)
		draw_line(Vector2(size.x, 0.0), Vector2(size.x, TAILLE_ONGLET), COULEUR_ACCENT, 1.5)
		draw_line(Vector2(0.0, size.y - TAILLE_ONGLET), Vector2(0.0, size.y), COULEUR_ACCENT, 1.5)
		draw_line(Vector2(size.x, size.y - TAILLE_ONGLET), Vector2(size.x, size.y), COULEUR_ACCENT, 1.5)


## Halo additif pour l'incandescence du mot CANDELA.
class _Halo extends Control:
	const COUCHES := 12
	const HAUTEUR := 0.30
	const LARGEUR := 0.72
	const GRAIN := 0.06

	var energie: float = 0.0:
		set(v):
			energie = v
			queue_redraw()

	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		if energie <= 0.001 or size.x <= 0.0:
			return
		var centre := size * 0.5
		for i in COUCHES:
			var t := float(i + 1) / float(COUCHES)
			var demi := Vector2(size.x * LARGEUR * t, size.y * HAUTEUR * t) * 0.5
			var chute: float = (1.0 - t) * (1.0 - t)
			var a: float = clampf(energie, 0.0, 1.4) * GRAIN * chute
			draw_rect(Rect2(centre - demi, demi * 2.0),
				Color(0.98, 0.91, 0.80, a), true)
