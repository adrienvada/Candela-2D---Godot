extends SceneTree

## Le coup de feu — chantier TIR, étapes A et B (2026-10-05).
##
## Adrien, le 2026-10-05 : « Je n'aime pas le rendu des balles. Cela fait un gros rond, lumineux, inélégant », puis
## « elle doit être plus subtile », puis « il faudrait surtout qu'il y ait un muzzle flash qui se voit et qui éclaire ».
## Choisi sur maquette le même jour : persistance 28 ms, sillage 48 %, flash de 400 px de rayon, balle sans lumière.
##
## Ce que ce fichier tient, sur le VRAI jeu monté (`main.tscn`) :
##   A. **l'aiguille** — la planche (un pourtour transparent pour le miroir iso, une tête chaude et une queue froide),
##      sa longueur (`vitesse × 28 ms`, qui couvre un pas de physique pour CHAQUE classe : c'est ce qui fait filer la
##      balle au lieu de sauter), sa pose par `position` et jamais par `offset` (le miroir iso ne lit pas l'offset),
##      le sillage (1,5 px, 48 %, 800 px au plus), l'enfoncement à l'impact, le fil du tir fatal, les traits qui
##      repartent du rebond, l'arbalète inchangée, et aucune lumière portée par la balle ;
##   B. **le flash** — 800 px d'empreinte sur le masque `ECLAT` (déjà dans l'atlas des lumières), ombré, blanc au coup
##      puis ambre, `(1 − k)²` ; l'étoile de bouche, la petite lumière d'encre d'avant, gardée parce qu'en iso c'est
##      elle qui dessine l'étoile du coup ; l'éclat dessiné à 120 px ; plus aucune lumière CRÉÉE par un tir (l'écho au
##      sol est retiré).
##
## Ce qu'il ne vérifie PAS : que ce soit beau. Adrien en juge à l'écran (captures envoyées avec la PR).
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_coup_de_feu.gd
## (`--fixed-fps 60` : une image, un pas de physique — les longueurs se comptent en pas.)

var _echecs := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ " + label)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LE COUP DE FEU (chantier TIR, 2026-10-05) ===")
	_test_feu()
	_test_planche()
	var gs: Node = load("res://main.tscn").instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame
	await _test_aiguille_en_vol(gs)
	_test_toutes_les_classes_filent(gs)
	await _test_enfoncement(gs)
	await _test_fil_fatal(gs)
	_test_rebond()
	await _test_arbalete(gs)
	await _test_flash(gs)
	gs.queue_free()
	await process_frame
	if _echecs == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


# ---------------------------------------------------------------------------
# La rampe et la planche
# ---------------------------------------------------------------------------

func _test_feu() -> void:
	print("— Charte.feu")
	_check("chaleur 1 : l'halogène", Charte.feu(1.0).is_equal_approx(Charte.HALOGENE))
	_check("chaleur 0,5 : l'ambre", Charte.feu(0.5).is_equal_approx(Charte.AMBRE))
	_check("chaleur 0 : le carmin", Charte.feu(0.0).is_equal_approx(Charte.CARMIN))
	_check("bornée hors de [0, 1]", Charte.feu(2.0).is_equal_approx(Charte.HALOGENE)
		and Charte.feu(-1.0).is_equal_approx(Charte.CARMIN))


func _test_planche() -> void:
	print("— La planche de l'aiguille")
	var tex: Texture2D = load("res://assets/decals/aiguille.png")
	_check("aiguille.png se charge (sinon : tools/fabrique_aiguille.gd, puis --import)", tex != null)
	if tex == null:
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	_check("256 × 20", w == 256 and h == 20, "%d × %d" % [w, h])
	# Le pourtour : le miroir iso échantillonne en `repeat_enable` + linéaire ; un bord opaque bave sur l'autre bout.
	var pire := 0.0
	for x in w:
		pire = maxf(pire, maxf(img.get_pixel(x, 0).a, img.get_pixel(x, h - 1).a))
	for y in h:
		pire = maxf(pire, maxf(img.get_pixel(0, y).a, img.get_pixel(w - 1, y).a))
	_check("pourtour d'un texel transparent (le miroir iso répète la texture)", pire == 0.0, "%.3f" % pire)
	var axe := h / 2
	var tete := img.get_pixel(w - 6, axe)
	var milieu := img.get_pixel(w / 2, axe)
	var queue := img.get_pixel(20, axe)
	_check("la tête brûle (opacité ≥ 0,95)", tete.a >= 0.95, "%.3f" % tete.a)
	_check("la queue s'éteint (opacité ≤ 0,25)", queue.a <= 0.25, "%.3f" % queue.a)
	# Le refroidissement le long du trait, lu au rapport vert / rouge : 0,93 pour l'halogène, 0,72 pour l'ambre, 0,31
	# pour le carmin. (Le bleu ne le dirait pas : le carmin en a plus que l'ambre.)
	var chaleur := func(c: Color) -> float: return c.g / maxf(c.r, 0.001)
	_check("blanche à la tête, plus chaude que le milieu", chaleur.call(tete) > chaleur.call(milieu),
		"%.2f contre %.2f" % [chaleur.call(tete), chaleur.call(milieu)])
	_check("et le milieu plus chaud que la queue", chaleur.call(milieu) > chaleur.call(queue),
		"%.2f contre %.2f" % [chaleur.call(milieu), chaleur.call(queue)])
	var monotone := true
	var avant := 2.0
	for i in 12:
		var x := w - 6 - i * 20
		var a := img.get_pixel(x, axe).a
		if a > avant + 0.02:
			monotone = false
		avant = a
	_check("l'opacité ne remonte jamais de la tête vers la queue", monotone)
	# Subtile : au bord de la planche (2 texels de l'axe = 1 px de monde au-delà du corps), plus de blanc.
	var bord := img.get_pixel(w - 6, axe - 6)
	_check("la gaine ne blanchit pas (bord de la tête sous 0,5 d'opacité)", bord.a < 0.5, "%.3f" % bord.a)
	# RR5 — le jumeau fondu, celui que le jeu charge : même planche, même tête, opacité en dégradé.
	var fondu: Texture2D = load("res://assets/fondu/decals/aiguille.png")
	_check("le jumeau fondu se charge (assets/fondu/decals/aiguille.png)", fondu != null)
	if fondu != null:
		var imf := fondu.get_image()
		if imf.is_compressed():
			imf.decompress()
		_check("même planche : 256 × 20", imf.get_width() == w and imf.get_height() == h)
		_check("même tête brûlante (≥ 0,95)", imf.get_pixel(w - 6, axe).a >= 0.95, "%.3f" % imf.get_pixel(w - 6, axe).a)
		_check("même pourtour transparent", imf.get_pixel(0, axe).a == 0.0 and imf.get_pixel(w - 1, axe).a == 0.0
			and imf.get_pixel(w / 2, 0).a == 0.0 and imf.get_pixel(w / 2, h - 1).a == 0.0)


# ---------------------------------------------------------------------------
# A — l'aiguille sur une vraie balle
# ---------------------------------------------------------------------------

## Une vraie balle, comme `GameState._spawn_bullet` la monte, loin de tout mur.
func _balle(gs: Node, idx: int, depart := Vector2(20000.0, 20000.0), cap := 0.0) -> Node2D:
	var b: Node2D = gs.bullet_scene.instantiate()
	b.global_position = depart
	b.rotation = cap
	b.direction = Vector2.from_angle(cap)
	b.source_player = gs.p1
	b.weapon = gs.weapon_for_index(idx)
	gs.bullet_container.add_child(b)
	return b


func _longueur(aura: Sprite2D) -> float:
	return aura.scale.x * float(aura.texture.get_width())


func _test_aiguille_en_vol(gs: Node) -> void:
	print("— L'aiguille en vol (pistolet)")
	var b := _balle(gs, 0)
	var aura := b.get_node(^"Aura") as Sprite2D
	var core := b.get_node(^"Core") as Line2D
	_check("au départ, l'aiguille est cachée (rien derrière la tête)", not aura.visible)
	_check("l'aiguille porte la planche cuite, par le masque d'effet (fondue en jeu, encrée sous --sans-fondu)",
		aura.texture == LightTextures.masque(IsoMateriaux.masque_d_effet(b.CHEMIN_AIGUILLE)))
	_check("pas de PointLight2D sur la balle (« balle sans lumière »)", b.find_children("*", "Light2D", true, false).is_empty())
	# Jusqu'au premier pas de la balle (le signal `physics_frame` part AVANT les `_physics_process`).
	for i in 4:
		await physics_frame
		if b.global_position.distance_to(b.spawn_pos) > 0.0:
			break
	var pas: float = b.weapon.bullet_speed / 60.0
	var parcouru: float = b.global_position.distance_to(b.spawn_pos)
	_check("en vol, l'aiguille se montre", aura.visible)
	_check("au premier pas (%.0f px), compressée sur ce qui a été parcouru" % parcouru,
		parcouru < b.longueur_d_aiguille() and absf(_longueur(aura) - parcouru) < 0.5, "%.1f" % _longueur(aura))
	for i in 3:
		await physics_frame
	var attendu: float = b.weapon.bullet_speed * b.PERSISTANCE
	_check("pleine : vitesse × 28 ms = %.0f px" % attendu, absf(_longueur(aura) - attendu) < 0.5,
		"%.1f" % _longueur(aura))
	_check("336 px au pistolet, la longueur de référence de la planche", absf(attendu - 336.0) < 0.01)
	_check("plus longue qu'un pas de physique (%.0f px) : la balle file au lieu de sauter" % pas, attendu > pas)
	_check("posée par position, centrée derrière la tête", aura.position.is_equal_approx(Vector2(-attendu * 0.5, 0.0)),
		str(aura.position))
	_check("et jamais par offset (le miroir iso ne le lit pas)", aura.offset == Vector2.ZERO and aura.centered)
	var centre_attendu: Vector2 = b.global_position - b.direction * attendu * 0.5
	_check("le centre GLOBAL du sprite, celui que lit MiroirsIso._poser_rect, est derrière la balle",
		aura.global_position.distance_to(centre_attendu) < 0.5)
	_check("hauteur de 10 px de monde", absf(aura.scale.y * aura.texture.get_height() - b.HAUTEUR_AIGUILLE) < 0.01)
	_check("modulate neutre : la couleur est dans la planche", is_equal_approx(aura.modulate.r, 1.0)
		and is_equal_approx(aura.modulate.g, 1.0) and is_equal_approx(aura.modulate.b, 1.0))
	_check("additive et non éclairée, comme la traçante", aura.material == core.material and aura.material != null
		and (aura.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	print("— Le sillage")
	_check("1,5 px", is_equal_approx(core.width, 1.5), "%.2f" % core.width)
	_check("ambre à 48 %", core.default_color.is_equal_approx(Color(Charte.AMBRE, 0.48)), str(core.default_color))
	parcouru = b.global_position.distance_to(b.spawn_pos)
	var pts := core.points
	_check("ancré au départ (%.0f px parcourus)" % parcouru,
		pts.size() == 2 and absf(pts[1].x + minf(parcouru, 800.0)) < 0.5, str(pts))
	for i in 3:
		await physics_frame
	pts = core.points
	_check("800 px au plus, comme la traçante d'avant", absf(pts[1].x + 800.0) < 0.5, str(pts))
	b.queue_free()


func _test_toutes_les_classes_filent(gs: Node) -> void:
	print("— Chaque classe file")
	for i in range(10):
		var w: WeaponData = gs.weapon_for_index(i)
		if not w.emits_light:
			continue
		var l := w.bullet_speed * 0.028
		_check("%s : aiguille %.0f px ≥ pas de %.0f px" % [w.slug(), l, w.bullet_speed / 60.0], l >= w.bullet_speed / 60.0)


func _test_enfoncement(gs: Node) -> void:
	print("— À l'impact, l'aiguille s'enfonce")
	var b := _balle(gs, 0)
	for i in 4:
		await physics_frame
	var aura := b.get_node(^"Aura") as Sprite2D
	var core := b.get_node(^"Core") as Line2D
	var avant := _longueur(aura)
	var point: Vector2 = b.global_position + b.direction * 50.0
	b._fade_and_destroy(point)
	_check("la tête se pose au point touché", b.global_position.is_equal_approx(point))
	_check("l'aiguille garde d'abord sa longueur", aura.visible and absf(_longueur(aura) - avant) < 1.0)
	await process_frame
	await process_frame
	var milieu := _longueur(aura) if aura.visible else 0.0
	_check("deux images après, elle a raccourci (%.0f → %.0f px)" % [avant, milieu], milieu < avant)
	_check("sans s'éteindre : opacité intacte", aura.modulate.a > 0.99, "%.3f" % aura.modulate.a)
	_check("elle reste collée à la tête : son bout avant est au point touché",
		absf(aura.position.x + milieu * 0.5) < 0.5)
	for i in 3:
		await process_frame
	_check("au bout de 48 ms, elle est entrée (cachée)", not is_instance_valid(aura) or not aura.visible)
	if is_instance_valid(core):
		_check("le sillage, lui, s'éteint sur place (80 ms, EXTINCTION)", core.modulate.a < 0.5, "%.3f" % core.modulate.a)
	for i in 4:
		await process_frame
	_check("et la balle est libérée", not is_instance_valid(b))


func _test_fil_fatal(gs: Node) -> void:
	print("— Le fil du tir fatal")
	var b := _balle(gs, 0)
	for i in 4:
		await physics_frame
	var aura := b.get_node(^"Aura") as Sprite2D
	var core := b.get_node(^"Core") as Line2D
	var longueur := _longueur(aura)
	b._flare_trail()
	b._fade_and_destroy(b.global_position)
	_check("le fil : 2 px, et non la largeur triplée d'avant", is_equal_approx(core.width, 2.0), "%.2f" % core.width)
	_check("blanc au coup (Charte.feu(1))", Color(core.modulate, 1.0).is_equal_approx(Color(Charte.HALOGENE, 1.0)),
		str(core.modulate))
	for i in 10:
		await process_frame
	_check("l'aiguille reste plantée, pleine longueur", is_instance_valid(aura) and aura.visible
		and absf(_longueur(aura) - longueur) < 1.0)
	_check("en refroidissant : plus rouge que bleue à mi-course", core.modulate.b < core.modulate.r * 0.6,
		str(core.modulate))
	for i in 16:
		await process_frame
	_check("éteint en 0,35 s, puis libéré", not is_instance_valid(b))


func _test_rebond() -> void:
	print("— Le rebond")
	# Sur le TEXTE, comme `test_torches` : c'est en recopiant une ligne que le défaut reviendrait.
	var texte := FileAccess.get_file_as_string("res://bullet.gd")
	var i := texte.find("spawn_pos = global_position # Reset trail origin")
	var j := texte.find("_etirer_les_traits()", i)
	var k := texte.find("_rompre_tunnel(hit_point)", i)
	_check("les traits repartent du rebond dès l'image du rebond (pas à travers le mur)", i >= 0 and j > i and j < k)


func _test_arbalete(gs: Node) -> void:
	print("— L'arbalète ne change pas")
	var b := _balle(gs, 3)
	await physics_frame
	await physics_frame
	var aura := b.get_node(^"Aura") as Sprite2D
	var core := b.get_node(^"Core") as Line2D
	_check("pas d'aiguille", not aura.visible)
	_check("son carreau d'acier, éclairé (matériau par défaut)", core.material == null)
	_check("à sa couleur et sa largeur de classe", core.default_color.is_equal_approx(b.weapon.bullet_color)
		and is_equal_approx(core.width, b.weapon.bullet_width))
	b._flare_trail()
	_check("au tir fatal, il triple de largeur comme avant", is_equal_approx(core.width, b.weapon.bullet_width * 3.0))
	b.queue_free()


# ---------------------------------------------------------------------------
# B — le flash qui éclaire
# ---------------------------------------------------------------------------

func _test_flash(gs: Node) -> void:
	print("— Le flash de bouche")
	var j: Node2D = gs.p1
	j.equip_weapon(gs.weapon_for_index(0))
	var flash := j.muzzle_flash as PointLight2D
	var lumieres_avant := j.find_children("*", "Light2D", true, false).size()
	j.trigger_shoot_visuals()
	var empreinte := float(flash.texture.get_width()) * flash.texture_scale
	_check("800 px d'empreinte (400 de rayon)", absf(empreinte - 800.0) < 0.5, "%.1f" % empreinte)
	_check("sur le masque ECLAT, déjà tenu par l'atlas des lumières", flash.texture == LightTextures.masque(LightTextures.ECLAT))
	_check("ombré", flash.shadow_enabled)
	_check("allumé au coup", flash.enabled)
	var pic: float = j.current_weapon.muzzle_flash_intensity * EffectPolicy.curseur("flash_de_tir") * j.PIC_DU_FLASH
	_check("pic = intensité × 1,8 (%.2f)" % pic, is_equal_approx(flash.energy, pic), "%.3f" % flash.energy)
	_check("blanc au coup", flash.color.is_equal_approx(Charte.HALOGENE), str(flash.color))
	j._poser_le_flash(0.5, pic)
	_check("à mi-durée : (1 − k)², soit le quart", is_equal_approx(flash.energy, pic * 0.25), "%.3f" % flash.energy)
	_check("et déjà ambre", flash.color.is_equal_approx(Charte.AMBRE), str(flash.color))
	_check("un tir ne CRÉE plus de lumière (l'écho au sol est retiré)",
		j.find_children("*", "Light2D", true, false).size() == lumieres_avant)
	var etoile := j.etoile_de_bouche as PointLight2D
	_check("l'étoile de bouche : la lumière d'avant, nommée", etoile != null and etoile.name == "EtoileDeBouche")
	_check("allumée au coup, à l'intensité de l'arme", etoile.enabled
		and is_equal_approx(etoile.energy, j.current_weapon.muzzle_flash_intensity * EffectPolicy.curseur("flash_de_tir")),
		"%.3f" % etoile.energy)
	var cote_etoile := float(etoile.texture.get_width()) * etoile.texture_scale
	_check("à son empreinte d'avant : 64 px", absf(cote_etoile - 64.0) < 0.5, "%.1f" % cote_etoile)
	_check("sur l'image d'encre de l'amorce", etoile.texture == LightTextures.masque(LightTextures.FLASH[0]))
	_check("ombrée par les mêmes masques que le grand flash", etoile.shadow_enabled
		and etoile.shadow_item_cull_mask == flash.shadow_item_cull_mask
		and etoile.range_item_cull_mask == flash.range_item_cull_mask)
	_check("au canon, comme le grand flash", etoile.position == flash.position)
	var eclat: Sprite2D = j._eclat_de_bouche()
	var cote := float(eclat.texture.get_width()) * eclat.scale.x
	_check("l'éclat dessiné : 120 px", absf(cote - 120.0) < 0.5, "%.1f" % cote)
	for i in 12:
		await process_frame
	_check("éteint au bout de la durée de l'arme", not flash.enabled)
	_check("l'étoile aussi", not etoile.enabled)
	# L'arbalète : son flash reste un souffle, l'intensité de classe le règle seule.
	j.equip_weapon(gs.weapon_for_index(3))
	j.trigger_shoot_visuals()
	_check("arbalète : pic à 0,1 × 1,8", is_equal_approx(flash.energy, 0.1 * EffectPolicy.curseur("flash_de_tir") * j.PIC_DU_FLASH),
		"%.3f" % flash.energy)
	for i in 6:
		await process_frame
	# Texte : personne ne remet les images d'encre sur la LUMIÈRE (une texture inédite = l'atlas reconstruit).
	var texte := FileAccess.get_file_as_string("res://player.gd")
	_check("player.gd ne pose plus FLASH[...] sur la lumière de bouche",
		not texte.contains("poser(muzzle_flash, LightTextures.FLASH") and not texte.contains("poser(muzzle_flash, chemin"))
	_check("ni l'écho au sol", not texte.contains("PointLight2D.new()\n\tLightTextures.poser(ground_flash"))
