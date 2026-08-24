## La musique est branchée sur de vrais flux, et tous tombent sur la grille.
##
## Ce que cette suite protège, et pourquoi elle n'existait pas plus tôt : le
## système musical a vécu deux mois **câblé sur du vide**. `AudioManager` chargeait
## `main_stream_interactive.tres`, y trouvait quatre clips, basculait de l'un à
## l'autre, ouvrait et fermait ses couches — et ne jouait rien, parce que les flux
## embarqués étaient les silences produits par `generate_music_streams.gd`. Aucune
## erreur, aucun test rouge : un jeu muet et un jeu dont on a coupé le volume ne se
## distinguent pas.
##
## D'où les deux contrôles qui comptent ici, et qui ne se déduisent pas l'un de
## l'autre :
##
## 1. **Un flux non vide** derrière chaque clip. C'est le défaut d'origine.
## 2. **Une longueur en nombre ENTIER de temps** à 170 BPM. C'est le défaut
##    suivant, celui qu'on n'entend qu'au deuxième tour de boucle : un stem qui
##    dure 63,9 temps se décale d'un vingtième de temps à chaque passage, et les
##    transitions `fade_beats` du flux interactif tombent à côté. Un MP3 ne sait
##    pas rendre autre chose qu'un multiple de 1152 échantillons — c'est pour ça
##    que les sources sont recalées à l'import, et c'est ce recalage-ci qu'on
##    vérifie.
##
## Lancer : godot --headless --path . --script res://tools/test_musique.gd
extends SceneTree

const AM := preload("res://audio_manager.gd")
const CHEMIN_INTERACTIF := "res://assets/audio/music/main_stream_interactive.tres"
const DIR_MUSIQUE := "res://assets/audio/music/"

## Un échantillon à 48 kHz vaut 0,0028 temps à 170 BPM. La tolérance couvre
## l'arrondi inévitable (64 temps = 1 084 235,29 échantillons), pas davantage :
## un stem faux d'un centième de temps doit rougir.
const TOLERANCE_TEMPS := 0.01

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
	print("=== MUSIQUE ===")
	_test_flux_interactif()
	_test_couches_du_match()
	_test_ouverture()
	_test_armes()
	_test_stingers()
	_test_manifeste()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

## Le contrôle central : ce flux dure-t-il un nombre entier de temps, et
## porte-t-il quelque chose ?
func _verifier_flux(nom: String, flux: AudioStream, temps_attendus: int) -> void:
	if flux == null:
		_check("%s : le flux existe" % nom, false, "null")
		return
	var duree := flux.get_length()
	# Un flux vide rend 0 s. C'est exactement l'état dans lequel le jeu a vécu.
	_check("%s : porte du son" % nom, duree > 0.0, "%.4f s" % duree)
	if duree <= 0.0:
		return
	var temps := duree / AM.PERIODE_BEAT
	_check("%s : %d temps pile" % [nom, temps_attendus],
		absf(temps - float(temps_attendus)) < TOLERANCE_TEMPS,
		"%.4f temps (%.4f s)" % [temps, duree])
	_check("%s : annoncé à %d BPM" % [nom, int(AM.BPM)],
		is_equal_approx(flux.get("bpm"), AM.BPM), str(flux.get("bpm")))

func _test_flux_interactif() -> void:
	print("\n[Le flux interactif]")
	_check("la ressource existe", ResourceLoader.exists(CHEMIN_INTERACTIF))
	var res = load(CHEMIN_INTERACTIF)
	_check("c'est bien un AudioStreamInteractive", res is AudioStreamInteractive)
	if not (res is AudioStreamInteractive):
		return

	# Les noms ne sont pas décoratifs : `AudioManager.play_music("music_menu")`
	# retire le préfixe et bascule PAR NOM. Un clip renommé ne lève rien, il ne
	# bascule simplement plus.
	var noms := []
	for i in res.clip_count:
		noms.append(String(res.get_clip_name(i)))
	for attendu in ["intro", "menu", "match", "victory"]:
		_check("le clip « %s » existe" % attendu, attendu in noms, str(noms))

	for i in res.clip_count:
		var nom := String(res.get_clip_name(i))
		var flux = res.get_clip_stream(i)
		if flux is AudioStreamSynchronized:
			continue  # traité par _test_couches_du_match
		var temps := 16 if nom in ["intro", "victory"] else 64
		_verifier_flux("clip " + nom, flux, temps)
		# Le menu boucle, l'intro et la victoire enchaînent sur le menu : une
		# intro qui boucle ne rendrait jamais la main.
		var doit_boucler := nom == "menu"
		_check("clip %s : boucle=%s" % [nom, doit_boucler],
			bool(flux.get("loop")) == doit_boucler)

func _test_couches_du_match() -> void:
	print("\n[Les quatre couches du match]")
	var res = load(CHEMIN_INTERACTIF)
	if not (res is AudioStreamInteractive):
		return
	var sync: AudioStreamSynchronized = null
	for i in res.clip_count:
		if String(res.get_clip_name(i)) == "match":
			sync = res.get_clip_stream(i) as AudioStreamSynchronized
			break
	_check("le clip « match » est un flux synchronisé", sync != null)
	if sync == null:
		return

	# AudioManager adresse les couches par INDICE : 0-1-2 pour l'intensité
	# (set_music_intensity), 3 pour le pouls (update_low_health). Un ordre changé
	# ouvrirait la mauvaise couche, sans rien signaler.
	_check("quatre couches", sync.stream_count == 4, str(sync.stream_count))
	if sync.stream_count < 4:
		return
	var noms := ["base", "batterie", "arpège", "pouls"]
	for i in 4:
		# Le pouls bat à la mesure, les trois autres tiennent la boucle entière.
		_verifier_flux("couche %d (%s)" % [i, noms[i]], sync.get_sync_stream(i),
			4 if i == 3 else 64)

	# L'état au repos. AudioManager suppose de trouver la base ouverte et le reste
	# fermé : `set_music_intensity(0)` ne rouvre rien, il ne fait que descendre.
	_check("au repos, la base est ouverte",
		is_equal_approx(sync.get_sync_stream_volume(0), 0.0),
		"%.1f dB" % sync.get_sync_stream_volume(0))
	for i in range(1, 4):
		_check("au repos, la couche %d (%s) est fermée" % [i, noms[i]],
			sync.get_sync_stream_volume(i) <= -60.0,
			"%.1f dB" % sync.get_sync_stream_volume(i))

## L'intro au lancement, et une seule fois.
##
## Ce que ça protège tient à un détail que personne n'a de raison de soupçonner :
## `music_player.play()` démarre le flux à son CLIP INITIAL, pas au clip qu'on
## demande. Tant que l'intro est le clip 0, démarrer suffit à la jouer — et
## demander autre chose dans la foulée suffit à la tuer. Elle a vécu ainsi, sortie
## un tiers de seconde par le repli ANY→ANY, sans qu'aucune erreur ne le dise.
##
## Trois propriétés, et les trois sont nécessaires : l'intro doit être le clip
## initial (sinon démarrer ne la joue pas), elle doit ENCHAÎNER seule (sinon la
## musique s'arrête après cinq secondes et demie), et l'enchaînement doit partir
## de la FIN et non du prochain temps (sinon elle est coupée comme avant, cette
## fois sans qu'on sache pourquoi).
func _test_ouverture() -> void:
	print("\n[L'ouverture : l'intro, une fois]")
	var res = load(CHEMIN_INTERACTIF)
	if not (res is AudioStreamInteractive):
		return
	var initial := int(res.initial_clip)
	_check("le clip initial est l'intro",
		initial >= 0 and initial < res.clip_count
			and String(res.get_clip_name(initial)) == "intro",
		"clip %d" % initial)

	var intro := -1
	var menu := -1
	for i in res.clip_count:
		var n := String(res.get_clip_name(i))
		if n == "intro":
			intro = i
		elif n == "menu":
			menu = i
	if intro < 0 or menu < 0:
		return

	_check("l'intro enchaîne toute seule",
		int(res.get_clip_auto_advance(intro)) == AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
	_check("et elle enchaîne sur le menu",
		int(res.get_clip_auto_advance_next_clip(intro)) == menu)

	# Sans transition explicite, c'est le repli ANY→ANY qui s'applique — et il
	# part au PROCHAIN TEMPS. C'est très exactement ce qui coupait l'intro.
	_check("la transition intro → menu est explicite", res.has_transition(intro, menu))
	if not res.has_transition(intro, menu):
		return
	_check("elle part de la fin de l'intro, pas du prochain temps",
		int(res.get_transition_from_time(intro, menu))
			== AudioStreamInteractive.TRANSITION_FROM_TIME_END,
		str(res.get_transition_from_time(intro, menu)))
	_check("et le menu repart de son début",
		int(res.get_transition_to_time(intro, menu))
			== AudioStreamInteractive.TRANSITION_TO_TIME_START,
		str(res.get_transition_to_time(intro, menu)))

	# Le démarrage doit passer par la fonction qui NE DEMANDE RIEN. Un
	# `play_music("music_menu")` ici rejouerait le défaut à l'identique.
	var source := FileAccess.get_file_as_string("res://game_state.gd")
	_check("GameState ouvre par demarrer_musique_au_lancement()",
		source.contains("AudioManager.demarrer_musique_au_lancement()"))
	_check("et ne redemande pas le menu au lancement",
		not source.contains('add_to_group("game_state")\n\tAudioManager.play_music'))

## Les quatre variantes de tir par arme.
##
## Ce que ça protège, et pourquoi ce n'est pas qu'un contrôle de présence : le
## chemin d'un son de tir est CONSTRUIT (`weapon_<slug>_<nn>.wav`) à partir du
## slug de l'arme. Un fichier mal numéroté, un slug mal orthographié, une arme
## renommée — et `get_audio_stream` rend `null`, `play_weapon_shot` retombe sur
## le son générique, et **le jeu continue de tirer normalement**. On n'entend pas
## un défaut, on entend l'ancien son : la seule chose qui aurait changé, c'est
## qu'une arme cesse d'avoir sa voix, sans que rien ne le dise.
func _test_armes() -> void:
	print("\n[Les tirs : quatre variantes par arme]")
	for slug in ["pistolet", "fusil", "pompe", "arbalete"]:
		var manquantes := PackedStringArray()
		var stereo := PackedStringArray()
		for i in range(1, AM.VARIANTES_TIR + 1):
			var chemin := AM.chemin_tir(slug, i)
			if not ResourceLoader.exists(chemin):
				manquantes.append(chemin.get_file())
				continue
			var flux = load(chemin)
			# Un tir se joue en 2D positionnel, et dans ce jeu SAVOIR D'OÙ vient
			# le coup est l'information. Un flux stéréo dans un lecteur
			# positionnel dilue le panoramique : la source cesse d'être un point.
			if flux is AudioStreamWAV and flux.stereo:
				stereo.append(chemin.get_file())
		_check("%s : ses %d variantes sont là" % [slug, AM.VARIANTES_TIR],
			manquantes.is_empty(), str(manquantes))
		_check("%s : toutes en mono" % slug, stereo.is_empty(), str(stereo))

	# Le nommage, vérifié sur la forme et pas sur un exemple : c'est lui qui fait
	# le lien entre le slug d'une arme et son fichier.
	_check("le chemin est bien formé",
		AM.chemin_tir("pompe", 3) == "res://assets/audio/weapons/weapon_pompe_03.wav",
		AM.chemin_tir("pompe", 3))

	# V4.15 : les pas reculent sous le tir. La règle interrogeait la clé
	# « shoot » ; un tir arrive désormais aussi par son CHEMIN, et la laisser
	# telle quelle aurait rendu le duck muet sans rien casser de visible.
	_check("un tir joué par sa clé est reconnu", AM.est_un_tir("shoot"))
	_check("un tir joué par son chemin aussi",
		AM.est_un_tir(AM.chemin_tir("fusil", 1)))
	_check("un pas n'est pas un tir", not AM.est_un_tir("footstep"))
	_check("un flux anonyme n'est pas un tir", not AM.est_un_tir(null))
	_check("et un tir garde la priorité d'un tir",
		AM.priorite_de(AM.chemin_tir("fusil", 1)) == AM.priorite_de("shoot"))

	# Les deux appelants doivent passer par le tirage au sort. Un
	# `play_sfx_2d_random_pitch("shoot", …)` resté en place rejouerait le son
	# unique pour les quatre armes, sans que rien ne le signale.
	for fichier in ["res://player.gd", "res://game_state.gd"]:
		var source := FileAccess.get_file_as_string(fichier)
		_check("%s tire par play_weapon_shot" % fichier.get_file(),
			source.contains("AudioManager.play_weapon_shot("))
		_check("%s ne joue plus le son générique" % fichier.get_file(),
			not source.contains('play_sfx_2d_random_pitch("shoot"'))

func _test_stingers() -> void:
	print("\n[Les stingers]")
	# Une ponctuation qui boucle est un bourdon : c'est le seul défaut de cette
	# famille qu'on ne peut pas rattraper au mixage.
	for entree in [["sting_kill", 4], ["sting_kill_match", 4],
			["sting_defeat", 8], ["sting_draw", 8]]:
		var nom: String = entree[0]
		var chemin := DIR_MUSIQUE + nom + ".ogg"
		if not ResourceLoader.exists(chemin):
			_check("%s : présent" % nom, false, chemin)
			continue
		var flux = load(chemin)
		_verifier_flux(nom, flux, int(entree[1]))
		_check("%s : ne boucle pas" % nom, not bool(flux.get("loop")))

func _test_manifeste() -> void:
	print("\n[Le manifeste ne signale plus de bouche-trou musical]")
	# `AssetManifest` reconnaît un flux vide à sa taille exacte. Les fichiers
	# livrés en pèsent une autre : le drapeau doit être tombé tout seul.
	var restants := PackedStringArray()
	for f in AssetManifest.placeholders():
		if String(f).begins_with("music_") or String(f).begins_with("sting_"):
			restants.append(f)
	_check("aucun flux vide en musique", restants.is_empty(), str(restants))

	var absents := PackedStringArray()
	for entree in AssetManifest.EXPECTED:
		var fichier := String(entree["f"])
		if String(entree["d"]) != DIR_MUSIQUE:
			continue
		if not AssetManifest.exists(entree):
			absents.append(fichier)
	_check("aucun fichier musical absent", absents.is_empty(), str(absents))
