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
