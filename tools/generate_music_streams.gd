@tool
extends EditorScript

# Ce script génère automatiquement les ressources AudioStreamInteractive (Séquenceur)
# et AudioStreamSynchronized (Couches verticales) pour Candela 2D.
#
# UTILISATION :
# 1. Dans l'éditeur Godot, ouvre ce script.
# 2. Fais "Fichier -> Run" (ou File -> Run, raccourci : Ctrl+Shift+X).
# 3. Les fichiers seront générés dans res://assets/audio/music/ !

func _run() -> void:
	print("Génération du système musical interactif pour Candela 2D...")
	print("Génération du système musical interactif pour Candela 2D...")
	
	var dir = DirAccess.open("res://assets/audio")
	if not dir:
		DirAccess.make_dir_recursive_absolute("res://assets/audio/music")
	
	# --- 1. Création du flux synchronisé (Logique Verticale) ---
	var sync_stream = AudioStreamSynchronized.new()
	sync_stream.stream_count = 4
	
	# On crée des streams vides ou on charge les fichiers s'ils existent
	var base_stream = AudioStreamOggVorbis.new()
	var drums_stream = AudioStreamOggVorbis.new()
	var arp_stream = AudioStreamOggVorbis.new()
	
	var heartbeat_path := "res://assets/audio/music/music_match_heartbeat.ogg"
	var heartbeat_stream: AudioStream = null
	if ResourceLoader.exists(heartbeat_path):
		heartbeat_stream = load(heartbeat_path)
	else:
		heartbeat_stream = AudioStreamOggVorbis.new()
	
	sync_stream.set_sync_stream(0, base_stream)
	sync_stream.set_sync_stream_volume(0, 0.0) # Base active
	
	sync_stream.set_sync_stream(1, drums_stream)
	sync_stream.set_sync_stream_volume(1, -60.0) # Mute par défaut
	
	sync_stream.set_sync_stream(2, arp_stream)
	sync_stream.set_sync_stream_volume(2, -60.0) # Mute par défaut
	
	sync_stream.set_sync_stream(3, heartbeat_stream)
	sync_stream.set_sync_stream_volume(3, -60.0) # Heartbeat mute par défaut (s'active quand la santé est basse)
	
	# --- 2. Création du flux interactif principal (Logique Horizontale) ---
	var interactive = AudioStreamInteractive.new()
	interactive.clip_count = 3
	
	var menu_stream = AudioStreamOggVorbis.new()
	var victory_stream = AudioStreamOggVorbis.new()
	
	interactive.set_clip_name(0, "menu")
	interactive.set_clip_stream(0, menu_stream)
	
	interactive.set_clip_name(1, "match")
	interactive.set_clip_stream(1, sync_stream) # On assigne le SyncStream au clip Match !
	
	interactive.set_clip_name(2, "victory")
	interactive.set_clip_stream(2, victory_stream)
	
	# --- 3. Transitions pour 170 BPM ---
	# menu -> match : Au prochain temps (Next Beat) pour que ce soit punchy
	interactive.add_transition(0, 1, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT, AudioStreamInteractive.TRANSITION_TO_TIME_SAME_POSITION, AudioStreamInteractive.FADE_CROSS, 0.5)
	
	# match -> victory : A la prochaine mesure (Next Bar) pour finir proprement le motif
	interactive.add_transition(1, 2, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_CROSS, 1.0)
	
	# Retour au menu
	interactive.add_transition(2, 0, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT, AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_CROSS, 1.0)
	interactive.add_transition(1, 0, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT, AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_CROSS, 1.0)
	
	# Fallback (Auto)
	interactive.add_transition(AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT, AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_CROSS, 0.5)
	
	# Sauvegarde finale
	var err = ResourceSaver.save(interactive, "res://assets/audio/music/main_stream_interactive.tres")
	if err == OK:
		print("✅ Succès ! Ressource sauvegardée sous res://assets/audio/music/main_stream_interactive.tres")
		print("-> Tu peux l'ouvrir dans l'éditeur et y glisser tes fichiers .ogg (base, drums, arp, etc) !")
	else:
		print("❌ Erreur lors de la sauvegarde : ", err)
