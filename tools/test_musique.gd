## La musique est branchée sur de vrais flux, et tous tombent sur la grille.
##
## Ce que cette suite protège, et pourquoi elle n'existait pas plus tôt : le
## système musical a vécu deux mois **câblé sur du vide**. `AudioManager` chargeait
## `main_stream_interactive.tres`, y trouvait quatre clips, basculait de l'un à
## l'autre, ouvrait et fermait ses couches — et ne jouait rien, parce que les flux
## embarqués étaient les silences produits par `generate_music_streams.gd`
## (retiré depuis). Aucune
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
	_test_filet_de_sortie()
	_test_aucun_fichier_muet()
	_test_dosage()
	_test_percuteur()
	_test_annonceur()
	_test_stingers_regle()
	_test_oreille()
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

## Qui entend quoi a la fin d'une manche.
##
## Une ponctuation qui se trompe de camp **felicite le perdant**, et rien ne le
## signale : le fichier existe, il se charge, il sort. C'est pour ca que la regle
## est une fonction pure et qu'elle est eprouvee ici plutot qu'a l'oreille, une
## fois, en match.
## Le percuteur a vide, et le piege qu'il tend au pool.
##
## Les fichiers `weapon_dry_*` vivent dans le meme dossier que les tirs. Or
## `est_un_tir()` reconnait un coup de feu **a son prefixe de chemin** : sans
## exclusion, un clic a vide aurait pris la priorite d'un tir ET declenche le
## duck des pas (V4.15). Un joueur martelant une detente vide aurait efface les
## pas de son adversaire — l'inverse exact de ce que ce son raconte.
##
## Rien n'aurait leve d'erreur : le clic se serait entendu, les pas auraient
## juste ete un peu plus bas. Encore une sortie plausible.
## Le dosage jugé par Adrien au banc le 2026-08-26.
##
## **Ce que ce contrôle protège n'est pas une valeur, c'est un JUGEMENT.** Ces
## nombres ne se déduisent d'aucun raisonnement — ils ont été entendus. Un jour
## quelqu'un les trouvera bizarres (les portées se tiennent en un mouchoir, un
## coup au but porte aussi peu qu'un pas) et voudra « remettre de l'ordre ». Les
## rapports ci-dessous sont là pour que ce quelqu'un se cogne à une suite rouge
## avant de le faire, et aille lire pourquoi.
##
## Les contrôles portent sur des RAPPORTS, jamais sur les valeurs exactes : un
## dosage doit pouvoir être repris au banc sans casser sa propre garde. Ce qui
## est verrouillé, c'est la FORME de la décision.
func _test_dosage() -> void:
	print("\n[Le dosage jugé au banc, 2026-08-26]")
	var p := func(c): return AM.PORTEE_RELATIVE.get(c, AM.PORTEE_RELATIVE_DEFAUT)
	var n := func(c): return AM.NIVEAU_RELATIF.get(c, AM.NIVEAU_RELATIF_DEFAUT)

	# LA règle posée par Adrien, et la plus facile à défaire par mégarde :
	# être touché ne doit pas trahir plus que marcher.
	_check("le coup au but ne porte pas plus loin qu'un pas",
		p.call("flesh_impact") <= p.call("footstep"),
		"impact %.2f vs pas %.2f" % [p.call("flesh_impact"), p.call("footstep")])

	# ... mais il reste FORT. C'est le couple qui fait la décision : intime et
	# lourd. Séparer les deux moitiés viderait la règle de son sens.
	_check("et pourtant il pèse plus qu'un pas",
		n.call("flesh_impact") > n.call("footstep"),
		"%.1f dB vs %.1f dB" % [n.call("flesh_impact"), n.call("footstep")])

	# Le percuteur trahit un peu plus qu'un pas — jugé contre lui, pas seul.
	_check("le percuteur porte un peu plus qu'un pas",
		p.call("weapon_dry") > p.call("footstep"))
	_check("mais moins qu'un tir",
		p.call("weapon_dry") < p.call("shoot"))

	# Le tir reste la référence de niveau : tout se place sous lui.
	_check("le tir est le zéro des niveaux",
		is_equal_approx(n.call("shoot"), 0.0), "%.1f" % n.call("shoot"))
	for cle in ["footstep", "wall_impact", "flesh_impact", "weapon_dry"]:
		_check("%s pèse moins que le tir" % cle, n.call(cle) < n.call("shoot"))

	# La forme de la séance : les portées se sont resserrées, les niveaux se sont
	# étalés. C'est LA position de conception, et elle se lit dans les écarts.
	var portees := []
	var niveaux := []
	for cle in ["footstep", "flesh_impact", "wall_impact", "shoot", "weapon_dry"]:
		portees.append(float(p.call(cle)))
		niveaux.append(float(n.call(cle)))
	var ecart_portee: float = portees.max() / portees.min()
	var ecart_niveau: float = niveaux.max() - niveaux.min()
	_check("les portées se tiennent en un mouchoir (rapport < 2)",
		ecart_portee < 2.0, "rapport %.2f" % ecart_portee)
	_check("les niveaux, eux, s'étalent franchement (> 10 dB)",
		ecart_niveau > 10.0, "%.1f dB" % ecart_niveau)

	# Les deux molettes globales, tranchées la veille. La courbe surtout : elle
	# est l'INVERSE de ce que le raisonnement avait produit, donc la première
	# qu'un futur « corrigeons ça » remettrait à 2,0.
	_check("le facteur de portée est celui d'Adrien (1,80)",
		is_equal_approx(AM.FACTEUR_PORTEE_DEFAUT, 1.8),
		"%.2f" % AM.FACTEUR_PORTEE_DEFAUT)
	_check("la courbe reste sous 1 — le son PRÉSENT presque partout",
		AM.COURBE_DISTANCE_DEFAUT < 1.0, "%.2f" % AM.COURBE_DISTANCE_DEFAUT)
	_check("la force du mur est celle jugée au banc (0,45)",
		is_equal_approx(AM.FORCE_OCCLUSION_DEFAUT, 0.45),
		"%.2f" % AM.FORCE_OCCLUSION_DEFAUT)

	# Et la vérification qui aurait attrapé mon erreur du percuteur : une portée
	# relative ne se juge pas seule, elle se multiplie par le facteur global.
	# Aucun son ne doit couvrir la carte entière — sinon sa portée ne dit plus rien.
	var diag := AM.diagonale_carte(AM.GRILLE_DEFAUT, CandelaTileSet.TILE_SIZE)
	for cle in ["footstep", "flesh_impact", "weapon_dry"]:
		var absolue: float = diag * float(p.call(cle)) * AM.FACTEUR_PORTEE_DEFAUT
		_check("%s : porte moins que 1,5 diagonale" % cle,
			absolue < diag * 1.5, "%.0f px pour une carte de %.0f" % [absolue, diag])

## AUCUN fichier du barème ne doit être muet.
##
## ⚠️ **Ce contrôle existe parce que j'ai livré un fichier vide et que mes propres
## tests l'ont laissé passer.** `voice/defeat.wav` — la voix qui annonce la
## défaite — contenait 0,76 s de silence numérique : un pic de **1 sur 32768**,
## soit −90 dBFS. Tout joueur qui perdait un match n'entendait rien.
##
## **Ce que mes tests vérifiaient, et pourquoi ça ne suffisait pas.** Pour les
## voix, je contrôlais `ResourceLoader.exists()` — le fichier est là, la clé
## résout, le chemin est bon. Trois vérités qui ne disent rien du contenu. Pour
## les stingers j'avais pourtant écrit « porte du son » en mesurant la durée...
## mais une durée non nulle ne prouve rien non plus : le fichier durait 0,76 s.
##
## **Et le manifeste ne pouvait pas le voir** : sa détection de bouche-trou
## compare une TAILLE exacte (160 032 octets, celle des flux générés). Un silence
## d'une autre taille passe à travers — c'est l'angle mort déjà relevé sur
## `music_intro.ogg` le 2026-08-24, et il vient de coûter une seconde fois.
##
## Le seul contrôle qui tranche est celui-ci : **ouvrir les données et regarder
## si quelque chose bouge.** Un son se mesure, il ne se déduit pas d'un chemin.
## Le filet de sortie (DA3.9), et surtout : qu'il reste MUET en jeu normal.
##
## **La propriété qui compte n'est pas qu'un limiteur existe, c'est qu'il ne
## serve presque jamais.** Dans un duel où le son est la seule information, un
## limiteur qui mord à chaque tir baisserait les pas de l'adversaire — il
## retirerait ce que le jeu donne à entendre, au moment précis où ça compte.
## Même famille que la règle du voile : ce qui protège le confort ne doit pas
## moduler ce qui renseigne.
##
## D'où le contrôle central : **le pic le plus fort du dépôt, une fois la marge
## appliquée, doit passer SOUS le plafond.** Un son seul ne réveille jamais le
## filet ; seules les sommes le réveillent.
func _test_filet_de_sortie() -> void:
	print("\n[Le filet de sortie : il doit rester muet]")

	# LE contrôle. Si la marge se raccourcit ou qu'un son plus fort arrive, le
	# filet se met à mixer — et personne ne l'entendra comme tel.
	_check("un son SEUL, même le plus fort, ne réveille pas le filet",
		not AM.reveille_le_filet(AM.PIC_MAX_DEPOT_DB, AM.MARGE_DB, AM.PLAFOND_DB),
		"pic %+.1f + marge %+.1f = %+.1f, plafond %+.1f" % [
			AM.PIC_MAX_DEPOT_DB, AM.MARGE_DB,
			AM.PIC_MAX_DEPOT_DB + AM.MARGE_DB, AM.PLAFOND_DB])

	# ... mais une SOMME doit le réveiller, sinon il ne sert à rien. Deux sons au
	# pic maximum font +6 dB : c'est le cas qu'il existe pour attraper.
	_check("mais deux sons simultanés le réveillent",
		AM.reveille_le_filet(AM.PIC_MAX_DEPOT_DB + 6.0, AM.MARGE_DB, AM.PLAFOND_DB))

	# La marge doit couvrir le dépôt réel. Ce contrôle rougit le jour où Adrien
	# livre un son plus fort que tout ce qui existe — et c'est le bon moment
	# pour le savoir, pas six mois plus tard à l'oreille.
	_check("la marge couvre le pic le plus fort du dépôt",
		AM.PIC_MAX_DEPOT_DB + AM.MARGE_DB <= AM.PLAFOND_DB)
	_check("le plafond laisse de la place aux dépassements inter-échantillons",
		AM.PLAFOND_DB < 0.0, "%+.1f" % AM.PLAFOND_DB)

	# La marge est une TRANSLATION : elle ne doit toucher aucun rapport jugé au
	# banc. Le vérifier revient à vérifier qu'elle vit ailleurs que dans la table.
	var source := FileAccess.get_file_as_string("res://audio_manager.gd")
	_check("la marge ne vit pas dans la table des niveaux",
		not source.contains("MARGE_DB,\n\t\"footstep\""))
	_check("le limiteur est posé par le CODE, pas seulement par le fichier de bus",
		source.contains("poser_limiteur()"))

	# Un seul filet, et sur Master. Un limiteur sur SFX mordrait sur les tirs,
	# donc baisserait les pas qui partagent ce bus : le défaut déplacé d'un cran.
	_check("le filet vit sur Master", AM.BUS_MASTER == "Master")

func _test_aucun_fichier_muet() -> void:
	print("\n[Aucun fichier du barème n'est muet]")
	# On passe TOUT ce que SOUNDS sait résoudre, plus les variantes construites.
	var chemins := PackedStringArray()
	for cle in AM.SOUNDS:
		chemins.append(String(AM.SOUNDS[cle]))
	for slug in ["pistolet", "fusil", "pompe", "arbalete"]:
		chemins.append(AM.chemin_percuteur(slug))
		for i in range(1, AM.VARIANTES_TIR + 1):
			chemins.append(AM.chemin_tir(slug, i))

	var muets := PackedStringArray()
	var testes := 0
	for chemin in chemins:
		if not ResourceLoader.exists(chemin):
			continue  # absent : c'est la règle « câbler, taire » — pas un défaut
		# Les conteneurs (`AudioStreamInteractive`, `AudioStreamSynchronized`)
		# n'ont pas de contenu propre : leur longueur vaut 0 par nature, et les
		# juger muets serait un faux positif. Leurs clips sont vérifiés ailleurs.
		if not chemin.ends_with(".wav"):
			continue
		testes += 1
		if _wav_muet(chemin):
			muets.append(String(chemin).get_file())

	_check("au moins vingt .wav ont été ouverts", testes >= 20, str(testes))
	_check("aucun n'est muet", muets.is_empty(), str(muets))

## Ce flux contient-il quelque chose ?
##
## Lit les données réelles plutôt que la durée. Un `AudioStreamWAV` expose ses
## octets ; un Ogg ne les expose pas, on retombe alors sur la durée — imparfait,
## mais c'est le seul angle disponible et les Ogg du dépôt sont tous mesurés
## par ailleurs.
## Ce fichier contient-il quelque chose ?
##
## **Lit le FICHIER SOURCE sur le disque, pas la ressource importée** — et c'est
## le coeur du contrôle, pas un détail. Godot importe les `.wav` en QOA :
## `AudioStreamWAV.data` ne contient alors plus du PCM mais un flux compressé,
## que rien ne permet d'inspecter échantillon par échantillon. Ma première
## version lisait ces octets comme du 16 bits signé, y trouvait du bruit de
## compression, et **déclarait vivant un fichier vide** — le défaut même qu'elle
## était censée attraper, reproduit à l'intérieur de son garde-fou.
##
## Lire la source règle ça, et vaut mieux pour une autre raison : c'est ce
## qu'Adrien a livré qu'on veut juger, pas ce que l'importeur en a fait.
##
## ⚠️ **Limite assumée : ne couvre que les `.wav`.** Un `.ogg` est compressé à la
## source, il faudrait le décoder. Les Ogg du dépôt sont vérifiés autrement — la
## suite exige d'eux une durée exacte en temps musicaux, ce qu'un fichier vide
## n'a aucune raison d'avoir. Un contrôle qui ne couvre pas tout et le dit vaut
## mieux qu'un contrôle qui prétend tout couvrir.
static func _wav_muet(chemin: String) -> bool:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return false
	var octets := f.get_buffer(f.get_length())
	f.close()
	if octets.size() < 44:
		return true
	# On cherche le morceau « data » du RIFF plutôt que de supposer un en-tête de
	# 44 octets : les exports portent souvent des morceaux LIST ou fact avant lui.
	var debut := -1
	var i := 12
	while i + 8 <= octets.size():
		var nom := octets.slice(i, i + 4).get_string_from_ascii()
		var taille := octets.decode_u32(i + 4)
		if nom == "data":
			debut = i + 8
			break
		i += 8 + taille + (taille & 1)
	if debut < 0:
		return false
	# 16 bits signés. Un seul échantillon au-dessus de -60 dBFS (32/32768) suffit
	# à prouver que le fichier vit ; un souffle de fond dépasse largement ce seuil.
	var j := debut
	while j + 1 < octets.size():
		if absi(octets.decode_s16(j)) > 32:
			return false
		j += 2 * 8  # un échantillon sur huit : on cherche un pic, pas une moyenne
	return true

func _test_percuteur() -> void:
	print("\n[Le percuteur a vide]")
	for slug in ["pistolet", "fusil", "pompe", "arbalete"]:
		var chemin := AM.chemin_percuteur(slug)
		_check("%s : son percuteur est la" % slug,
			ResourceLoader.exists(chemin), chemin)
		if ResourceLoader.exists(chemin):
			var flux = load(chemin)
			# Positionnel comme les tirs, donc mono : un clic a vide dit « je
			# suis la », et une source stereo cesse d'etre un point.
			#
			# Les VOIX, elles, ne sont pas concernees : l'annonceur passe par un
			# `AudioStreamPlayer` global, sans panoramique. Les forcer en mono
			# n'aurait rien gagne et aurait jete la largeur du mixage.
			_check("%s : en mono" % slug,
				not (flux is AudioStreamWAV and flux.stereo))

	_check("le chemin est bien forme",
		AM.chemin_percuteur("pompe")
			== "res://assets/audio/weapons/weapon_dry_pompe.wav",
		AM.chemin_percuteur("pompe"))

	# LE controle qui compte.
	_check("un clic a vide N'EST PAS un tir",
		not AM.est_un_tir(AM.chemin_percuteur("fusil")))
	_check("... alors qu'un vrai tir du meme dossier en est un",
		AM.est_un_tir(AM.chemin_tir("fusil", 1)))
	# ⚠️ Ce controle a d'abord affirme que le percuteur n'avait PAS la priorite
	# d'un tir. C'etait faux, et pour une raison qui vaut d'etre gardee : un son
	# inconnu du bareme recoit `SFX_PRIORITE_DEFAUT`, qui vaut 2 — exactement la
	# valeur de `shoot`. Le percuteur a donc bien la meme priorite, non par
	# heritage mais par le defaut, et c'est **voulu** : le bareme place le son
	# anonyme au-dessus des pas et en dessous du recit. Ce qu'il fallait
	# verifier, c'est le duck, pas le rang.
	# Le dosage : un percuteur porte PEU et pese PEU. Sans ligne dediee il
	# prendrait le defaut (1,0 x diagonale, 0 dB) et s'entendrait d'un bout a
	# l'autre de la carte — pour un clic, ce serait une annonce.
	var pc := AM.chemin_percuteur("fusil")
	_check("il porte moins loin qu'un impact de mur",
		AM.portee_relative_de(pc) < AM.portee_relative_de("wall_impact"),
		"%.2f" % AM.portee_relative_de(pc))
	_check("mais plus loin qu'un pas",
		AM.portee_relative_de(pc) > AM.portee_relative_de("footstep"))
	_check("il ne prend PAS la portee par defaut",
		not is_equal_approx(AM.portee_relative_de(pc), AM.PORTEE_RELATIVE_DEFAUT))
	_check("et il pese moins qu'un tir",
		AM.niveau_relatif_de(pc) < AM.niveau_relatif_de("shoot"),
		"%.1f dB" % AM.niveau_relatif_de(pc))

	_check("il se place au-dessus des pas",
		AM.priorite_de(AM.chemin_percuteur("fusil")) > AM.priorite_de("footstep"))
	_check("et en dessous du coup au but",
		AM.priorite_de(AM.chemin_percuteur("fusil")) < AM.priorite_de("flesh_impact"))

## L'annonceur : a qui parle-t-il, et que dit-il ?
##
## La regle d'Adrien : en ecran scindé l'annonceur NOMME le vainqueur, partout
## ailleurs il s'adresse a celui qui ecoute. Se tromper de cote ici, c'est
## annoncer « le joueur 2 a gagne » a quelqu'un qui joue seul, ou pire, feliciter
## le perdant. Rien ne leverait d'erreur : un fichier existe, il sort.
func _test_annonceur() -> void:
	print("\n[L'annonceur : a qui il parle]")
	# Ecran scindé : deux joueurs, memes haut-parleurs, il faut NOMMER.
	_check("ecran scindé, J1 gagne -> spk_p1_wins",
		AM.voix_de_fin(0, -1, false, 55.0) == "spk_p1_wins")
	_check("ecran scindé, J2 gagne -> spk_p2_wins",
		AM.voix_de_fin(1, -1, false, 55.0) == "spk_p2_wins")
	# Et il NOMME meme sur un sans-faute : la variante ne doit pas manger
	# l'information de qui a gagne, qui est la seule utile a deux devant l'ecran.
	_check("ecran scindé : la variante ne remplace pas le nom",
		AM.voix_de_fin(0, -1, false, AM.PV_MAX) == "spk_p1_wins")

	# En ligne : il s'adresse a celui qui ecoute.
	_check("en ligne, je gagne -> win", AM.voix_de_fin(0, 0, false, 55.0) == "win")
	_check("en ligne, je perds -> defeat",
		AM.voix_de_fin(0, 1, false, 55.0) == "defeat")
	_check("et dans l'autre sens",
		AM.voix_de_fin(1, 1, false, 55.0) == "win"
			and AM.voix_de_fin(1, 0, false, 55.0) == "defeat")

	# Les variantes, et leur exclusion mutuelle.
	_check("intact -> sans faute",
		AM.voix_de_fin(0, 0, false, AM.PV_MAX) == "spk_perfect")
	_check("au ras -> de justesse",
		AM.voix_de_fin(0, 0, false, AM.PV_DE_JUSTESSE) == "spk_close_call")
	_check("entre les deux -> win tout court",
		AM.voix_de_fin(0, 0, false, 50.0) == "win")
	# Le perdant n'herite d'aucune variante : ses PV ne sont pas ceux du vainqueur.
	_check("le vaincu entend defeat quels que soient les PV",
		AM.voix_de_fin(0, 1, false, AM.PV_MAX) == "defeat"
			and AM.voix_de_fin(0, 1, false, 1.0) == "defeat")

	# L'egalite passe avant tout le reste, des deux cotes.
	for idx in [-1, 0, 1]:
		_check("egalite -> spk_draw (local_idx %d)" % idx,
			AM.voix_de_fin(-1, idx, false, 0.0) == "spk_draw")

	# Toutes les cles doivent resoudre vers un fichier reel.
	for cle in ["spk_fight", "spk_draw", "spk_p1_wins", "spk_p2_wins",
			"win", "defeat", "spk_perfect", "spk_close_call"]:
		_check("la cle %s designe un fichier present" % cle,
			ResourceLoader.exists(String(AM.SOUNDS.get(cle, ""))),
			String(AM.SOUNDS.get(cle, "(absente de SOUNDS)")))

	# La regle doit DERIVER d'ecoute_somme, pas la recopier : deux predicats
	# paralleles divergent le jour ou l'on n'en corrige qu'un.
	var source := FileAccess.get_file_as_string("res://audio_manager.gd")
	_check("voix_de_fin s'appuie sur ecoute_somme",
		source.contains("if ecoute_somme(local_idx, entrainement):"))

func _test_stingers_regle() -> void:
	print("\n[La ponctuation de fin : qui entend quoi]")
	# Egalite : le match s'acheve au temps, les deux entendent la meme chose.
	_check("egalite -> sting_draw pour l'hote",
		AM.stinger_de_fin(-1, true, 0) == "sting_draw")
	_check("egalite -> sting_draw pour le client",
		AM.stinger_de_fin(-1, true, 1) == "sting_draw")
	_check("egalite -> sting_draw en ecran partage",
		AM.stinger_de_fin(-1, true, -1) == "sting_draw")

	# Decision d'Adrien : un kill non decisif s'entend DES DEUX COTES.
	_check("kill non decisif : le tueur l'entend",
		AM.stinger_de_fin(0, false, 0) == "sting_kill")
	_check("kill non decisif : LA VICTIME AUSSI",
		AM.stinger_de_fin(0, false, 1) == "sting_kill")

	# Kill decisif : chacun sa nouvelle.
	_check("kill decisif : le vainqueur entend le kill de match",
		AM.stinger_de_fin(0, true, 0) == "sting_kill_match")
	_check("kill decisif : le vaincu entend sa defaite",
		AM.stinger_de_fin(0, true, 1) == "sting_defeat")
	_check("et dans l'autre sens aussi",
		AM.stinger_de_fin(1, true, 0) == "sting_defeat"
			and AM.stinger_de_fin(1, true, 1) == "sting_kill_match")

	# En ecran partage personne n'est « le » vaincu a la sortie audio : les deux
	# joueurs partagent les haut-parleurs. Meme raison que `torche_comptee`.
	_check("ecran partage : jamais de sting de defaite",
		AM.stinger_de_fin(0, true, -1) == "sting_kill_match"
			and AM.stinger_de_fin(1, true, -1) == "sting_kill_match")

	# Les quatre cles doivent resoudre vers un fichier reel, sinon la regle
	# designe un son qui ne sortira pas.
	for cle in ["sting_kill", "sting_kill_match", "sting_defeat", "sting_draw"]:
		_check("la cle %s designe un fichier present" % cle,
			ResourceLoader.exists(String(AM.SOUNDS.get(cle, ""))),
			String(AM.SOUNDS.get(cle, "(absente de SOUNDS)")))

## L'oreille suit le joueur local — partout ou il n'y en a qu'un.
##
## ⚠️ **Cette section disait « en ligne seulement », et c'etait trop etroit.**
## Ce qui exclut l'ecran partage n'est pas d'etre en local : c'est que **deux
## joueurs y ecoutent les memes haut-parleurs**, si bien que suivre l'un
## donnerait a l'autre ses propres pas entendus depuis une tete qui n'est pas la
## sienne. L'entrainement est local ET solitaire — une vue, un joueur, une
## sortie — et il etait exclu avec l'ecran partage alors qu'il est le SEUL MODE
## SOLO du jeu, donc le seul ou l'on puisse doser un reglage sonore sans monter
## deux instances. Corrige le 2026-08-25 (session « spatialisation du son »),
## sur signalement croise entre sessions.
##
## C'est une regle d'EQUITE et pas de confort — donc elle se teste.
func _test_oreille() -> void:
	print("\n[L'oreille : partout ou il n'y a qu'un auditeur]")
	_check("en ligne, l'oreille suit l'hote", AM.oreille_suit(0))
	_check("en ligne, l'oreille suit le client", AM.oreille_suit(1))
	_check("en ecran partage, on n'y touche pas", not AM.oreille_suit(-1, false))
	_check("en entrainement, l'oreille suit", AM.oreille_suit(-1, true))
	# Le porteur, et c'est le defaut qui se cachait DERRIERE le premier : hors
	# ligne l'index vaut -1, et la forme naive `p1 if idx == 0 else p2` designait
	# alors J2 — cache et immobile en entrainement. L'oreille se serait posee sur
	# un fantome, et le symptome aurait ete « le panoramique ne bouge pas »,
	# c'est-a-dire le defaut d'avant sous un correctif qui a l'air pose.
	_check("hors ligne, le porteur est J1 et pas J2", AM.index_porteur(-1) == 0)
	_check("le client en ligne porte l'oreille sur J2", AM.index_porteur(1) == 1)

	# Le geste a trois pieces, et deux sur trois ne s'entendent pas seules. Ce
	# controle-ci verifie la troisieme, celle qu'on ne soupconne pas : un
	# SubViewport n'est PAS une oreille par defaut.
	var vue := SubViewport.new()
	get_root().add_child(vue)
	_check("un SubViewport n'est pas une oreille par defaut",
		not vue.audio_listener_enable_2d)
	vue.queue_free()

	# Et l'appelant doit bien poser les deux gestes ensemble.
	var source := FileAccess.get_file_as_string("res://game_state.gd")
	_check("GameState pose l'oreille au debut du match",
		source.contains("AudioManager.poser_oreille("))
	_check("... derriere la regle oreille_suit, pas en dur",
		source.contains("AudioManager.oreille_suit("))
	_check("GameState la rend a la fin",
		source.contains("AudioManager.rendre_oreille()"))
	_check("GameState joue la ponctuation de fin",
		source.contains("AudioManager.stinger_de_fin("))
	# Troisieme defaut de la meme chaine, et le plus silencieux : l'entrainement
	# passe par `_do_start_round`, qui remet `training_mode` a FAUX avant de
	# rendre la main. Une regle qui interroge le drapeau depuis l'interieur du
	# demarrage lit donc toujours « non ». Il faut un second appel, la ou le
	# drapeau est enfin vrai — sans quoi le correctif est pose et sans effet.
	# ⚠️ **Ce contrôle comptait `_accorder_oreille()` dans le TEXTE, et il a été
	# retiré le 2026-08-25.** Il exigeait au moins trois occurrences — une
	# définition, deux appels — c'est-à-dire une FORME d'implémentation et non un
	# sens. Il serait devenu rouge sur une refonte correcte, et vert sur une
	# refonte qui aurait cassé l'entraînement en gardant les trois occurrences.
	#
	# **Un contrôle textuel atteste d'un câblage, jamais d'un sens** : il dit
	# « quelque chose est branché là », jamais « la bonne chose est branchée là ».
	# La famille a été consignée trois fois dans la même journée, et celui-ci en
	# était. Le sens se vérifie en EXÉCUTANT — c'est fait dans
	# `tools/test_dosage_audio.gd`, qui monte `main.tscn`, entre réellement en
	# entraînement et regarde où est l'oreille.

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
