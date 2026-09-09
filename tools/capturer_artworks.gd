extends Node

const MenuArtworkScript := preload("res://menu_artwork.gd")
const OUTPUT_DIR := "tools/captures"

func _ready() -> void:
	print("Démarrage de la capture des 15 artworks via SubViewport...")
	_capturer_tout()

func _capturer_tout() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir_recursive(OUTPUT_DIR)
	
	var artworks: Array[String] = [
		"assets/ui/ill_accueil.png",
		"assets/ui/ill_amical.png",
		"assets/ui/ill_amical_ligne.png",
		"assets/ui/ill_amical_local.png",
		"assets/ui/ill_competitif.png",
		"assets/ui/ill_ecran_scinde.png",
		"assets/ui/ill_entrainement.png",
		"assets/ui/apercu_personnalisation.png",
		"assets/ui/ill_mise_a_jour.png",
		"assets/ui/ill_quitter.png",
		"assets/ui/ill_creer_ligne.png",
		"assets/ui/ill_rejoindre_ligne.png",
		"assets/ui/ill_creer_local.png",
		"assets/ui/ill_rejoindre_local.png",
		"assets/ui/ill_retour.png"
	]
	
	var sub_viewport := SubViewport.new()
	sub_viewport.size = Vector2i(1024, 640)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(sub_viewport)
	
	var rect := TextureRect.new()
	rect.size = Vector2(1024, 640)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	sub_viewport.add_child(rect)
	
	var shader := load("res://menu_artwork.gdshader") as Shader
	
	for path in artworks:
		if not ResourceLoader.exists(path):
			print("Fichier manquant : ", path)
			continue
		
		var tex := load(path) as Texture2D
		rect.texture = tex
		
		var mat := ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat
		
		var cle := MenuArtworkScript.cle_canonique(path)
		var poi := MenuArtworkScript.poi_pour(path)
		var effet := MenuArtworkScript.effet_pour(path)
		
		mat.set_shader_parameter("ambient_exposure", 0.28)
		mat.set_shader_parameter("torch_pos", poi)
		mat.set_shader_parameter("torch_radius", 0.45)
		mat.set_shader_parameter("torch_intensity", 1.0)
		mat.set_shader_parameter("reveal_progress", 1.0)
		mat.set_shader_parameter("effect_mode", effet)
		mat.set_shader_parameter("effect_time", 2.0)
		mat.set_shader_parameter("effect_strength", 1.0)
		mat.set_shader_parameter("mode_flou_total", 0.0)
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		var img := sub_viewport.get_texture().get_image()
		if img != null:
			var out_path := "%s/%s.png" % [OUTPUT_DIR, cle]
			img.save_png(out_path)
			print("Capturé : ", out_path)
		else:
			printerr("Échec capture pour : ", cle)
	
	print("Captures terminées avec succès.")
	get_tree().quit(0)
