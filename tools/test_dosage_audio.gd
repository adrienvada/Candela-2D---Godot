## S2 (la portée se dérive de la carte) et S3 (un mur étouffe) tiennent leurs
## promesses — au niveau où elles sont vérifiables sans oreille humaine.
##
## **Ce que cette suite peut prouver, et ce qu'elle ne peut pas.** En headless le
## pilote audio est muet : aucun test ne dira si le son est *bien dosé*, et c'est
## la raison d'être du banc (`tools/banc_audio.tscn`). Ce qui se prouve ici, ce
## sont les **règles** — qu'un pas ne porte pas aussi loin qu'un tir, qu'une
## portée suive la taille de la carte, qu'un tir joué par son chemin compte comme
## un tir, et qu'un bus explicitement demandé ne soit jamais détourné.
##
## Le partage est celui de `test_pool_sfx.gd`, et pour la même raison : un
## arbitrage qu'on ne peut pas tester est un arbitrage dont on découvre les
## défauts à l'oreille, en match, une seule fois — sans savoir ce qu'on vient
## d'entendre.
##
## Lancer : godot --headless --path . --script res://tools/test_dosage_audio.gd
extends SceneTree

const AM := preload("res://audio_manager.gd")

var _failures: int = 0
## Contrôles réellement exécutés. **Compté, jamais annoncé d'avance.**
##
## La première version de cette suite imprimait « 22/22 » en soustrayant les
## échecs d'un total écrit en dur — et elle l'a imprimé pendant que les vingt-deux
## contrôles échouaient à s'exécuter, le script sous test ne compilant pas. Un
## total constant ne mesure pas le travail fait, il le décrit d'avance : c'est
## une sortie plausible, la famille de défauts que ce chantier documente. Ici, le
## nombre affiché ne peut pas dépasser ce qui a tourné.
var _checks: int = 0
## Un contrôle qui n'a pas pu s'exécuter est un ÉCHEC, pas une absence.
var _attendus: int = 57

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("test_dosage_audio")
	_test_diagonale()
	_test_portee_par_son()
	_test_portee_suit_la_carte()
	_test_bus()
	_test_oreille_entrainement()
	await _test_le_mur_arrete_vraiment()
	_test_le_banc_se_pilote_en_azerty()
	await _test_l_entrainement_entend_vraiment()
	# Deux conditions, pas une : tous les contrôles exécutés doivent passer, ET
	# ils doivent tous s'être exécutés. Une erreur de script interrompt la
	# fonction de test en cours sans interrompre la suite — c'est un piège déjà
	# payé ici le 2026-08-18, et il rend une suite verte sur du travail non fait.
	var manquants := _attendus - _checks
	if manquants != 0:
		printerr("  ✗ ", absi(manquants), " contrôle(s) ",
			"non exécuté(s) — script interrompu" if manquants > 0 else "de plus qu'annoncé")
		_failures += absi(manquants)
	print("test_dosage_audio : ", _checks - _failures, "/", _attendus)
	quit(1 if _failures > 0 else 0)

## La portée de référence est la diagonale de la carte, pas son côté : une carte
## large et plate n'a pas la même distance maximale qu'une carte carrée de même
## surface.
func _test_diagonale() -> void:
	print(" diagonale")
	var d20 := AM.diagonale_carte(Vector2i(20, 20), Vector2i(35, 35))
	_check("20×20 en tuiles de 35 → ~990 px", absf(d20 - 989.95) < 0.5, str(d20))
	var d24 := AM.diagonale_carte(Vector2i(24, 24), Vector2i(35, 35))
	_check("une carte plus grande porte plus loin", d24 > d20, "%f vs %f" % [d24, d20])

	# ⚠️ **Ce contrôle comparait une copie à une copie.** Il vérifiait que la
	# constante `PORTEE_CARTE_DEFAUT` (989,95, écrite à la main) valait
	# `diagonale_carte(Vector2i(20, 20), Vector2i(35, 35))` — dont les deux
	# littéraux étaient eux aussi écrits ici. Le jour où `CandelaTileSet.TILE_SIZE`
	# change, les deux restent faux ENSEMBLE et la suite reste verte : **un
	# garde-fou qui compare une copie à une copie ne garde rien.** Il interroge
	# maintenant la vraie source, et la constante a laissé place à une dérivation.
	_check("le repli se dérive de la VRAIE taille de tuile",
		absf(AM.portee_carte_defaut()
			- AM.diagonale_carte(AM.GRILLE_DEFAUT, CandelaTileSet.TILE_SIZE)) < 0.001,
		"%f contre %f" % [AM.portee_carte_defaut(),
			AM.diagonale_carte(AM.GRILLE_DEFAUT, CandelaTileSet.TILE_SIZE)])
	# Et la grille annoncée est bien celle de la carte que le jeu charge par
	# défaut : sans ce contrôle, la dérivation serait exacte sur une carte
	# imaginaire.
	var md := root.get_node_or_null(^"/root/MapData")
	if md != null:
		md.select_map(md.DEFAULT_MAP_ID)
		var reelle: Vector2i = MapCodec.get_grid_size(md.get_selected())
		_check("la grille par défaut est celle de la carte par défaut",
			reelle == AM.GRILLE_DEFAUT, "%s contre %s" % [reelle, AM.GRILLE_DEFAUT])
	var plate := AM.diagonale_carte(Vector2i(40, 10), Vector2i(35, 35))
	var carree := AM.diagonale_carte(Vector2i(20, 20), Vector2i(35, 35))
	_check("à surface égale, la carte plate porte plus loin", plate > carree,
		"%f vs %f" % [plate, carree])

## Le classement des portées dit ce que le son APPREND, comme celui des
## priorités. Un tir traverse la carte ; un pas est un indice de proximité.
func _test_portee_par_son() -> void:
	print(" portée par son")
	_check("le tir porte le plus loin",
		AM.portee_relative_de("shoot") > AM.portee_relative_de("flesh_impact"))
	_check("le coup au but porte plus loin que l'impact de mur",
		AM.portee_relative_de("flesh_impact") > AM.portee_relative_de("wall_impact"))
	_check("le pas porte le moins loin",
		AM.portee_relative_de("wall_impact") > AM.portee_relative_de("footstep"))
	_check("le tir dépasse la carte", AM.portee_relative_de("shoot") > 1.0)
	_check("le pas ne couvre pas la moitié de la carte",
		AM.portee_relative_de("footstep") < 0.5)

	# Le piège de V4.1, repayé ici : depuis que chaque arme a ses variantes, un
	# tir arrive AUSSI sous forme de chemin. Une table interrogée par la seule
	# clé « shoot » aurait rendu la portée par défaut — un tir qui porte comme un
	# impact, sans qu'aucune erreur ne le dise.
	var chemin := AM.chemin_tir("pistolet", 1)
	_check("un tir joué par son CHEMIN porte comme un tir",
		is_equal_approx(AM.portee_relative_de(chemin), AM.portee_relative_de("shoot")),
		"%f contre %f" % [AM.portee_relative_de(chemin), AM.portee_relative_de("shoot")])
	_check("un son inconnu prend le défaut",
		is_equal_approx(AM.portee_relative_de("cliquetis_imaginaire"),
			AM.PORTEE_RELATIVE_DEFAUT))
	# ⚠️ **Le classement ne doit plus dépendre du DOSSIER.** `est_un_tir` répondait
	# vrai pour tout chemin sous `assets/audio/weapons/` — si bien que déposer un
	# fichier dans un répertoire était une décision de gameplay. Ces contrôles
	# éprouvent les sons qui n'existent pas encore : une queue de tir, une
	# variante de distance, un rechargement. Ils vivront dans le même dossier, et
	# aucun ne doit devenir un tir.
	_check("une queue de tir n'est PAS un tir",
		not AM.est_un_tir(AM.DIR_ARMES + "weapon_pistolet_tail.wav"))
	_check("une variante de distance non plus",
		not AM.est_un_tir(AM.DIR_ARMES + "weapon_pistolet_lointain.wav"))
	_check("un rechargement non plus",
		not AM.est_un_tir(AM.DIR_ARMES + "weapon_reload_pompe.wav"))
	_check("le percuteur non plus",
		not AM.est_un_tir(AM.chemin_percuteur("pistolet")))
	# Et ce que `chemin_tir` construit reste reconnu, pour les quatre variantes.
	var toutes := true
	for v in range(1, AM.VARIANTES_TIR + 1):
		if not AM.est_un_tir(AM.chemin_tir("pompe", v)):
			toutes = false
	_check("les quatre variantes que chemin_tir fabrique sont des tirs", toutes)
	_check("la clé générique d'avant V4.1 reste un tir", AM.est_un_tir("shoot"))

	_check("un flux sans clé prend le défaut",
		is_equal_approx(AM.portee_relative_de(AudioStreamWAV.new()),
			AM.PORTEE_RELATIVE_DEFAUT))

func _test_portee_suit_la_carte() -> void:
	print(" la portée suit la carte et le facteur")
	var petite := AM.diagonale_carte(Vector2i(12, 12), Vector2i(35, 35))
	var grande := AM.diagonale_carte(Vector2i(32, 32), Vector2i(35, 35))
	var p_petite := AM.portee_absolue("footstep", petite, 1.0)
	var p_grande := AM.portee_absolue("footstep", grande, 1.0)
	_check("un pas porte plus loin sur une grande carte", p_grande > p_petite,
		"%f contre %f" % [p_grande, p_petite])
	_check("le rapport suit exactement celui des cartes",
		absf(p_grande / p_petite - grande / petite) < 0.001)
	_check("le facteur de dosage multiplie",
		absf(AM.portee_absolue("shoot", petite, 2.0)
			- 2.0 * AM.portee_absolue("shoot", petite, 1.0)) < 0.001)
	# `max_distance` à zéro rend un son inaudible partout : le plancher évite
	# qu'un facteur poussé au minimum sur une carte minuscule éteigne le jeu
	# pendant un dosage, ce qui se lirait comme une panne.
	_check("jamais de portée nulle, même au facteur plancher",
		AM.portee_absolue("footstep", 1.0, 0.0001) >= 1.0)

func _test_bus() -> void:
	print(" choix du bus")
	_check("dégagé → bus de jeu",
		AM.bus_pour(AM.BUS_SFX, false) == AM.BUS_SFX)
	_check("occulté → bus d'occlusion",
		AM.bus_pour(AM.BUS_SFX, true) == AM.BUS_SFX_OCCLUS)
	# Sans cette garde, régler le volume dans les options ferait passer les
	# aperçus de l'écran audio par la réverb d'occlusion — un son de test qui ne
	# ressemble plus à ce qu'il teste.
	_check("un bus explicite n'est JAMAIS détourné, même occulté",
		AM.bus_pour("Master", true) == "Master")
	_check("le bus annonceur non plus",
		AM.bus_pour("Speaker", true) == "Speaker")
	_check("le bus d'occlusion n'est pas le bus de jeu",
		AM.BUS_SFX_OCCLUS != AM.BUS_SFX)

	# Le bus doit exister dans `default_bus_layout.tres`, sinon Godot rend la
	# voix muette sans lever d'erreur — exactement le mode de défaillance que ce
	# chantier documente.
	_check("le bus d'occlusion existe dans le layout",
		AudioServer.get_bus_index(AM.BUS_SFX_OCCLUS) != -1)
	var idx := AudioServer.get_bus_index(AM.BUS_SFX_OCCLUS)
	if idx != -1:
		# Il ENVOIE dans SFX, et pas dans Master : c'est ce qui garde le curseur
		# « Effets » aux commandes des sons occultés, et c'est aussi la chaîne
		# physique — la pièce d'à côté, puis la vôtre.
		_check("il envoie dans le bus de jeu, pas dans Master",
			String(AudioServer.get_bus_send(idx)) == AM.BUS_SFX,
			String(AudioServer.get_bus_send(idx)))
			# **Le jeu doit APPLIQUER la force, pas seulement la déclarer.** Elle ne
		# l'était que par le banc : en match, le bus gardait les valeurs cuites
		# dans le `.tres` — coupure à 620 Hz quand le banc à 0,55 en produisait
		# 2470, soit quatre fois plus étouffé en jouant qu'en dosant. Un dosage
		# fait à l'oreille se serait perdu entre l'outil et le match, sans
		# erreur. Ce contrôle compare le bus réel à ce que la force annonce.
		var gestionnaire := root.get_node_or_null(^"/root/AudioManager")
		var force: float = 0.0 if gestionnaire == null else float(gestionnaire.force_occlusion)
		var filtre := AudioServer.get_bus_effect(idx, 0) as AudioEffectFilter
		_check("le bus est accordé à la force déclarée",
			gestionnaire != null and filtre != null
				and absf(filtre.cutoff_hz - AM.coupure_occlusion_pour(force)) < 1.0,
			"%.0f Hz dans le bus contre %.0f Hz annoncés" % [
				0.0 if filtre == null else filtre.cutoff_hz,
				AM.coupure_occlusion_pour(force)])
	_check("il porte un passe-bas et une réverb",
			AudioServer.get_bus_effect_count(idx) >= 2)

## La règle de l'oreille demande « y a-t-il exactement un auditeur devant
## l'écran », pas « suis-je en ligne ». L'entraînement est le seul mode qui
## sépare les deux — et c'est la deuxième fois que le dépôt paie cette confusion
## sur ce mode précis.
func _test_oreille_entrainement() -> void:
	print(" l'oreille et l'entraînement")
	_check("hôte en ligne : l'oreille suit", AM.oreille_suit(0, false))
	_check("client en ligne : l'oreille suit", AM.oreille_suit(1, false))
	_check("écran partagé : l'oreille ne suit personne", not AM.oreille_suit(-1, false))
	_check("entraînement : l'oreille suit", AM.oreille_suit(-1, true))
	# S6 — l'écran partagé écoute par DEUX oreilles (décision d'Adrien,
	# 2026-08-25). Les trois cas doivent rester exhaustifs et exclusifs : un mode
	# qui tomberait dans aucun des deux jouerait sans oreille du tout, et un mode
	# qui tomberait dans les deux en poserait trois.
	_check("écran partagé : on écoute par la somme", AM.ecoute_somme(-1, false))
	_check("en ligne : pas de somme", not AM.ecoute_somme(0, false)
		and not AM.ecoute_somme(1, false))
	_check("entraînement : pas de somme", not AM.ecoute_somme(-1, true))
	_check("aucun mode ne tombe entre les deux règles",
		AM.ecoute_somme(-1, false) != AM.oreille_suit(-1, false)
		and AM.ecoute_somme(0, false) != AM.oreille_suit(0, false)
		and AM.ecoute_somme(-1, true) != AM.oreille_suit(-1, true))
	_check("le porteur par défaut est J1, pas J2", AM.index_porteur(-1) == 0)
	_check("le client en ligne porte l'oreille sur J2", AM.index_porteur(1) == 1)
	_check("l'hôte la porte sur J1", AM.index_porteur(0) == 0)

## Le rayon touche-t-il vraiment un mur ?
##
## **Une géométrie fabriquée ici, et pas la carte du jeu.** Un premier essai
## balayait la vraie carte et comptait les points vus : 98 contre 2 depuis le
## centre, 10 contre 90 depuis un coin. Ces chiffres prouvent que le rayon est
## branché, et **rien de plus** — ils décrivent la forme d'une carte, pas la
## règle. Le jour où quelqu'un redessine `default.json`, un tel contrôle vire au
## rouge sans qu'aucun défaut n'existe, ou pire, reste vert en masquant le
## contraire. Un mur, deux points, une réponse : ça, c'est reproductible.
##
## Ce contrôle-ci est le seul de la suite qui touche la physique. Il vaut le
## détour parce qu'il couvre ce que les fonctions pures ne peuvent pas voir : le
## masque de collision (`MapGeometry.WALL_LAYER` — un autre masque et le mur
## deviendrait transparent au son tout en arrêtant les balles), et le fait
## qu'`est_occulte` réponde bien pendant une frame de physique.
func _test_le_mur_arrete_vraiment() -> void:
	print(" le mur arrête vraiment (physique)")
	var am := root.get_node_or_null(^"/root/AudioManager")
	if am == null:
		_check("l'autoload AudioManager est là", false)
		return

	var monde := Node2D.new()
	root.add_child(monde)
	var porteur := Node2D.new()
	monde.add_child(porteur)
	var tete := Node2D.new()
	tete.global_position = Vector2.ZERO
	porteur.add_child(tete)
	am.poser_oreille(tete)

	var source := Vector2(400, 0)
	await physics_frame
	await physics_frame
	_check("on répond bien depuis une frame de physique", Engine.is_in_physics_frame())
	_check("sans mur, le son passe en direct", not am.est_occulte(source))

	var mur := StaticBody2D.new()
	mur.collision_layer = MapGeometry.WALL_LAYER
	mur.collision_mask = 0
	var forme := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	forme.shape = rect
	forme.position = Vector2(200, 0)
	mur.add_child(forme)
	monde.add_child(mur)
	await physics_frame
	await physics_frame
	_check("un mur entre les deux : le son est occulté", am.est_occulte(source))
	_check("et il part alors sur le bus d'occlusion",
		AM.bus_pour(AM.BUS_SFX, am.est_occulte(source)) == AM.BUS_SFX_OCCLUS)

	# Le doute joue en direct : occlusion coupée, on n'étouffe plus rien, même
	# derrière le mur. C'est ce que le banc utilise pour son A/B.
	am.occlusion_active = false
	_check("occlusion coupée : le mur n'étouffe plus", not am.est_occulte(source))
	am.occlusion_active = true

	# Et sans oreille posée, on ne peut pas répondre — donc on ne retire rien.
	am.rendre_oreille()
	_check("sans oreille, aucun son n'est étouffé", not am.est_occulte(source))

	# ⏳ **PROVISOIRE, et il faut le dire ici plutôt que de le laisser deviner.**
	# La session « résolution d'affichage » tient le même invariant dans
	# `tools/test_rendu_racine.gd`, sur le montage RÉEL du jeu (racine, `vp1`,
	# `vp2`) alors que celui-ci l'éprouve sur un monde fabriqué. **Un même
	# invariant à deux endroits finit par diverger** — le sien est le bon, et
	# celui-ci disparaîtra le jour où sa branche atterrira. Il reste en attendant
	# parce que la retirer avant ouvrirait une fenêtre sans aucune protection sur
	# un défaut qui vient d'être payé deux fois.
	_check("une oreille posée n'en laisse qu'UNE dans le monde",
		_compter_auditeurs(am) == 1, "%d viewports auditeurs" % _compter_auditeurs(am))

	monde.queue_free()

## Combien de viewports se déclarent auditeurs du monde où vit le pool ?
##
## **L'invariant qui compte, et il n'est pas évident : il en faut exactement UN.**
## `AudioStreamPlayer2D` boucle sur tous les viewports auditeurs de son `World2D`
## et **somme une sortie par viewport**. Deux auditeurs dont un sans
## `AudioListener2D`, et chaque son sort deux fois — une copie juste, une copie
## depuis le centre de l'écran virtuel, c'est-à-dire le défaut d'origine remis
## par-dessus le correctif. Le symptôme ne serait pas un silence mais **un son
## parfaitement audible**, +3 dB et panoramique brouillé : personne ne dirait
## « c'est cassé », on dirait « c'est bizarre ».
##
## Ce contrôle existe parce que le chantier R (résolution de rendu) envisage de
## donner au viewport racine le `world_2d` du jeu. Fait sans couper l'écoute de
## la racine, ce montage produit exactement ce défaut-là.
func _compter_auditeurs(am: Node) -> int:
	var n := 0
	if root.is_audio_listener_2d():
		n += 1
	for enfant in root.get_children():
		if enfant is SubViewport and (enfant as SubViewport).is_audio_listener_2d():
			n += 1
	return n

## L'entraînement pose-t-il vraiment son oreille ? **En montant le vrai jeu.**
##
## ⚠️ **Ce contrôle remplace un contrôle TEXTUEL, et le remplacement est le
## sujet.** `test_musique` comptait les occurrences de `_accorder_oreille()` dans
## la source de `game_state.gd` — au moins trois, une définition et deux appels.
## Il attestait d'une FORME d'implémentation, pas d'un sens : rouge sur une
## refonte correcte, vert sur une refonte qui aurait cassé l'entraînement en
## gardant ses trois occurrences. **Un contrôle textuel dit « quelque chose est
## branché là », jamais « la bonne chose est branchée là »** — famille consignée
## trois fois le 2026-08-25.
##
## Celui-ci monte `main.tscn`, appelle le vrai `_on_training_requested()`, et
## regarde où est l'oreille. C'est plus lent et c'est le prix du sens.
##
## Le piège qu'il garde, et qui ne se devine pas : l'entraînement passe par
## `_do_start_round`, **qui remet `training_mode` à faux avant de rendre la
## main**. Une règle qui lit ce drapeau depuis l'intérieur du démarrage lit
## toujours « non ». Les correctifs précédents auraient été posés, justes, et
## sans aucun effet.
func _test_l_entrainement_entend_vraiment() -> void:
	print(" l'entraînement pose vraiment son oreille (jeu monté)")
	var principal = load("res://main.tscn").instantiate()
	root.add_child(principal)
	await physics_frame
	await physics_frame

	principal._on_training_requested()
	await physics_frame
	await physics_frame

	var am := root.get_node_or_null(^"/root/AudioManager")
	_check("une oreille est posée en entraînement",
		am != null and am._oreille != null and is_instance_valid(am._oreille))
	if am != null and am._oreille != null and is_instance_valid(am._oreille):
		_check("elle est sur le joueur que l'on regarde",
			am._oreille.get_parent() == principal.p1,
			String(am._oreille.get_parent().name))
		_check("et elle est courante dans sa vue", am._oreille.is_current())
	# L'invariant du doublement : la racine ne doit PAS rester auditrice en plus
	# de la vue de jeu, sinon chaque son sort deux fois — une copie juste, une
	# copie depuis le point fixe hors de la carte.
	var auditeurs := 0
	if root.is_audio_listener_2d():
		auditeurs += 1
	for v in [principal.vp1, principal.vp2]:
		if v != null and (v as Viewport).is_audio_listener_2d():
			auditeurs += 1
	_check("exactement UN auditeur, pas deux", auditeurs == 1, "%d auditeurs" % auditeurs)
	# Et le son doit atteindre une voix : une oreille bien posée sur un pool resté
	# dans l'autre monde ne s'entendrait pas davantage.
	var voix: AudioStreamPlayer2D = am.play_sfx_2d("footstep", principal.p1.global_position)
	_check("un pas trouve une voix, dans le monde du joueur",
		voix != null and voix.get_world_2d() == principal.p1.get_world_2d())

	principal.queue_free()
	await physics_frame

## Le banc se pilote-t-il sur le clavier d'Adrien ?
##
## **Il ne se pilotait pas.** Écrit avec un `match` sur `keycode`, il attendait
## `KEY_1` ; sur l'AZERTY d'Adrien la rangée du haut produit `&`, `é`, `"` sans
## Maj, donc `KEY_AMPERSAND`, et les touches ne faisaient simplement **rien**.
## Aucune erreur, aucun test rouge : un banc qui a l'air cassé, dans un lot dont
## le banc est justement la livraison qui compte.
##
## `physical_keycode` désigne la position sur un clavier US quelle que soit la
## disposition. Le contrôle est textuel faute de pouvoir simuler une disposition
## en headless — grossier, mais il attrape la seule régression qui compte : le
## retour à `keycode`.
func _test_le_banc_se_pilote_en_azerty() -> void:
	print(" le banc se pilote sur un clavier français")
	var source := FileAccess.get_file_as_string("res://tools/banc_audio.gd")
	_check("le banc lit la POSITION des touches",
		source.contains("k.physical_keycode"))
	_check("... et jamais leur étiquette",
		not source.contains("match k.keycode"),
		"un match sur keycode est revenu : injouable en AZERTY")
