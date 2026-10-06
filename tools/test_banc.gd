## Le banc de cadence peut-il encore démarrer ?
##
## **Il ne le pouvait plus depuis la refonte des menus, et personne ne le savait.**
## `bench_framerate.gd` lisait `_ui.btn_mode_local`, disparu quand les modes sont
## devenus des entrées du hub : il s'ouvrait, levait une erreur de script,
## n'entrait jamais dans le duel et restait ouvert sans rien mesurer. Découvert
## le 2026-08-18, à la minute où le chiffre était demandé.
##
## La cause n'est pas la ligne, c'est la couverture : **le banc ouvre une fenêtre,
## donc il ne peut être dans aucune suite headless** — et rien ne signalait sa
## péremption. Un outil de mesure hors couverture se périme en silence.
##
## Cette suite ne mesure rien et n'ouvre rien. Elle vérifie seulement que les
## appuis du banc sur le jeu existent encore. C'est peu, et c'est exactement ce
## qui manquait : le banc aurait échoué ici, en headless, le jour de la refonte —
## au lieu d'échouer une semaine plus tard devant quelqu'un qui attendait un
## résultat.
##
## Lancer : godot --headless --path . --script res://tools/test_banc.gd
extends SceneTree

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

## Le corps d'une fonction de shader, de sa signature à l'accolade fermante de colonne 0 ; vide si la signature manque.
static func _fonction_de_shader(texte: String, signature: String) -> String:
	var debut := texte.find(signature)
	if debut < 0:
		return ""
	var fin := texte.find("\n}\n", debut)
	return texte.substr(debut, fin - debut) if fin > 0 else ""

## Les lignes de CODE de `void fragment()` d'un shader : sans commentaires, sans espaces de tête, sans les accolades seules.
## L'accolade de fin se trouve en comptant, pas en cherchant « \n}\n » : un fragment contient des blocs.
static func _lignes_du_fragment(texte: String) -> PackedStringArray:
	var debut := texte.find("void fragment() {")
	if debut < 0:
		return PackedStringArray()
	var niveau := 0
	var fin := -1
	for i in range(debut, texte.length()):
		var ch := texte[i]
		if ch == "{":
			niveau += 1
		elif ch == "}":
			niveau -= 1
			if niveau == 0:
				fin = i
				break
	if fin < 0:
		return PackedStringArray()
	var lignes := PackedStringArray()
	for l in texte.substr(debut, fin - debut + 1).split("\n"):
		var code := l.get_slice("//", 0).strip_edges()
		if code != "" and code not in ["{", "}", "} else {", "void fragment() {"]:
			lignes.append(code)
	return lignes

## Répète `geste` à chaque image jusqu'à ce que `n` pas de physique soient passés :
## c'est le rythme du banc (il écrit après `process_frame`), et c'est au pas de
## physique que `player.gd` décide de la lampe.
func _pendant_pas_de_physique(n: int, geste: Callable) -> void:
	var cible := Engine.get_physics_frames() + n
	while Engine.get_physics_frames() < cible:
		geste.call()
		await process_frame
	geste.call()
	await process_frame

func _torche_du_banc(Banc: GDScript, main: Node, ui: Node) -> void:
	# Le lancement du banc, au mot près (`bench_framerate.gd::_ready`).
	#
	# ⚠️ **Jamais `NetworkManager.GameMode` écrit en toutes lettres ici.** Nommer
	# l'autoload dans ce fichier compile `network_manager.gd` en même temps que
	# lui, AVANT que les autoloads du plugin EOS existent : « Identifier not found:
	# HLobbies », puis 5 418 `SCRIPT ERROR` en cascade (payé le 2026-09-14, en
	# écrivant ce contrôle). C'est le piège de l'en-tête — `load` et non `preload`
	# — sous une autre forme : on passe par le nœud, qui existe à l'exécution.
	var reseau: Node = root.get_node("NetworkManager")
	var modes: Dictionary = reseau.get_script().get_script_constant_map()["GameMode"]
	ui._intended_mode = modes["LOCAL_SPLITSCREEN"]
	main._on_replay_requested()
	var limite := Time.get_ticks_msec() + 15000
	while not (main.round_active and main.countdown_left <= 0.0) \
			and Time.get_ticks_msec() < limite:
		await process_frame
	_check("la manche du banc démarre et sort du décompte",
		main.round_active and main.countdown_left <= 0.0,
		"round_active=%s countdown_left=%.2f" % [main.round_active, main.countdown_left])
	if not main.round_active:
		return
	var joueurs: Array = [main.p1, main.p2]

	# 1. Le geste du banc : la gâchette tenue. La lampe doit s'allumer ET le rester.
	await _pendant_pas_de_physique(6, func():
		for p in joueurs:
			Banc.tenir_la_torche(p, true))
	_check("torche demandée allumée : la lampe des deux joueurs l'est après les pas de physique",
		joueurs.all(func(p): return p.flashlight_on and p.flashlight.enabled),
		"J1 enabled=%s J2 enabled=%s" % [main.p1.flashlight.enabled, main.p2.flashlight.enabled])

	# 2. Lâchée (`--sans-torches`) : éteinte, fondu D3 compris — et aucun verrou du
	# cran plein ne doit la garder allumée.
	await _pendant_pas_de_physique(30, func():
		for p in joueurs:
			Banc.tenir_la_torche(p, false))
	_check("torche demandée éteinte : la lampe l'est, sans verrou resté enclenché",
		joueurs.all(func(p): return not p.flashlight.enabled),
		"J1 enabled=%s J2 enabled=%s" % [main.p1.flashlight.enabled, main.p2.flashlight.enabled])

	# 3. Le contre-test : l'ANCIEN geste doit échouer ici, sinon ce contrôle ne
	# saurait pas rougir le jour où le banc y reviendrait.
	await _pendant_pas_de_physique(6, func():
		for p in joueurs:
			p.flashlight_on = true)
	_check("contre-test : écrire flashlight_on n'allume PAS la lampe (le jeu l'écrase)",
		joueurs.all(func(p): return not p.flashlight.enabled),
		"l'écriture directe tient désormais — revoir tenir_la_torche() et ce contrôle")

func _run() -> void:
	print("=== LE BANC PEUT-IL DÉMARRER ===")
	await process_frame
	# `load` et non `preload` : le banc nomme `NetworkManager`, et un `preload` en
	# tête de fichier le compilerait AVANT que les autoloads existent. L'échec ne
	# s'arrête pas à lui — il se propage à tout ce qui dépend d'eux, et main.tscn
	# arrive alors sans ses scripts, donc « tout a disparu ». C'est la troisième
	# forme du même piège dans la journée : ce qui est chargé tôt est compilé tôt.
	var Banc: GDScript = load("res://tools/bench_framerate.gd")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: Node = main.get_node_or_null("UI")

	var manquants: Array[String] = Banc.preconditions_manquantes(ui, main)
	_check("tous les appuis du banc existent encore", manquants.is_empty(),
		"; ".join(manquants))

	# Le contre-test : la vérification doit savoir DÉTECTER une disparition,
	# sinon elle rendrait toujours une liste vide et passerait pour verte.
	var vides: Array[String] = Banc.preconditions_manquantes(null, null)
	_check("et elle sait dire quand ils manquent", not vides.is_empty())

	# Le MODE MENUS a ses propres appuis, et il est né avec eux — c'est la
	# consigne tirée de la panne du duel : un outil qu'aucune suite ne peut
	# exécuter doit au moins exposer ses hypothèses sous une forme qu'une suite
	# peut vérifier. Les deux listes sont séparées parce que les deux modes ne
	# touchent pas au même jeu : une liste commune se plaindrait de l'absence
	# d'une arme dans un banc qui n'en tire aucune.
	var manquants_menus: Array[String] = Banc.preconditions_menus(ui)
	_check("les appuis du mode menus existent encore", manquants_menus.is_empty(),
		"; ".join(manquants_menus))
	var vides_menus: Array[String] = Banc.preconditions_menus(null)
	_check("et le mode menus sait dire quand ils manquent",
		not vides_menus.is_empty())

	# Chantier ISO — la variante `--iso` (relevé de fin de chantier) a ses propres appuis : les réglages
	# qu'elle pose pour l'exécution et les tailles de lightmap de la présentation.
	var manquants_iso: Array[String] = Banc.preconditions_iso(root.get_node_or_null("GameSettings"))
	_check("les appuis de la variante --iso existent encore", manquants_iso.is_empty(),
		"; ".join(manquants_iso))
	_check("et la variante --iso sait dire quand ils manquent",
		not (Banc.preconditions_iso(null) as Array).is_empty())

	# OM6 — le MODE SOLO du banc de cadence (`--solo=<chapitre>.<salle>`, chantier OMBRES) et ses trois interrupteurs de lumière : même
	# raison et même remède. Il ouvre une fenêtre, donc aucune suite ne peut l'exécuter ; il pose une partie d'aventure, lit ses bots, la
	# perception qu'ils ont de J1 et les lumières de chaque corps — beaucoup d'appuis, tous nommés ici.
	var manquants_solo: Array[String] = Banc.preconditions_solo(ui, main)
	_check("tous les appuis du mode solo du banc de cadence existent encore", manquants_solo.is_empty(),
		"; ".join(manquants_solo))
	_check("et le mode solo sait dire quand ils manquent", not (Banc.preconditions_solo(null, null) as Array).is_empty())
	_verifier_le_solo_du_banc(Banc, main)
	_verifier_les_reglages_d_ombre(Banc, main)

	# La planche de l'éblouissement, même raison et même remède : elle ouvre une
	# fenêtre, donc aucune suite ne peut l'exécuter — mais une suite peut lire
	# ses hypothèses. Elle en a beaucoup plus que le banc de cadence, parce
	# qu'elle pilote une manche entière au lieu de traverser des écrans : deux
	# joueurs, une arme, une touche de torche, un modèle d'éblouissement.
	var Planche: GDScript = load("res://tools/planche_eblouissement.gd")
	var manquants_eb: Array[String] = Planche.preconditions_manquantes(ui, main)
	_check("tous les appuis de la planche d'éblouissement existent encore",
		manquants_eb.is_empty(), "; ".join(manquants_eb))
	var vides_eb: Array[String] = Planche.preconditions_manquantes(null, null)
	_check("et elle sait dire quand ils manquent", not vides_eb.is_empty())

	# Le banc du voile, même raison et même remède. Ses appuis ne sont pas ceux
	# des deux autres : il ne traverse aucun écran et ne pilote aucune manche —
	# il ne dépend que du shader du voile, de l'appareil de brouillage et de la
	# lumière reçue. **Ce sont les uniformes du shader qui sont fragiles** : un
	# réglage renommé laisserait le banc partir de zéro sur ce réglage-là,
	# c'est-à-dire juger un effet éteint en croyant juger un défaut.
	var Voile: GDScript = load("res://tools/banc_voile.gd")
	var manquants_voile: Array[String] = Voile.preconditions_manquantes()
	_check("tous les appuis du banc du voile existent encore",
		manquants_voile.is_empty(), "; ".join(manquants_voile))
	var vides_voile: Array[String] = Voile.preconditions_manquantes(
		"res://un_shader_qui_n_existe_pas.gdshader")
	_check("et il sait dire quand ils manquent", not vides_voile.is_empty())

	# Le banc des MURS BAS (MB3c), même raison et même remède. Il pilote une manche
	# en écran scindé puis en vue unique, et lit des internes : la poussée de la
	# zone morte, le rendu racine, les lampes et l'éblouissement des joueurs. Et
	# ses scènes supposent la carte d'essai telle qu'elle est (cinq murs bas).
	var MursBancs: GDScript = load("res://tools/banc_murs_bas.gd")
	var manquants_mb: Array[String] = MursBancs.preconditions_manquantes(ui, main)
	_check("tous les appuis du banc des murs bas existent encore",
		manquants_mb.is_empty(), "; ".join(manquants_mb))
	var vides_mb: Array[String] = MursBancs.preconditions_manquantes(null, null)
	_check("et il sait dire quand ils manquent", not vides_mb.is_empty())

	# Le banc de la VUE DU BOT contre les capteurs (SOLO S2), même raison et même remède. Il monte un vrai duel sur sa carte
	# d'essai, pose le nœud de perception du jeu sur J2 et lit le capteur du corps de J1 dans la vue de J2 : il dépend donc des
	# lumières du joueur, de `Presentation3D._capteurs`, de la fusée, de `CameraIso.vers_sol` et des fichiers de la perception.
	var BancPerception: GDScript = load("res://tools/banc_perception_bot.gd")
	var manquants_perception: Array[String] = BancPerception.preconditions_perception(ui, main)
	_check("tous les appuis du banc de la perception du bot existent encore",
		manquants_perception.is_empty(), "; ".join(manquants_perception))
	var vides_perception: Array[String] = BancPerception.preconditions_perception(null, null)
	_check("et il sait dire quand ils manquent", not vides_perception.is_empty())

	# LE PHOTOGRAPHE, même raison et même remède : il ouvre une fenêtre, donc
	# aucune suite ne peut l'exécuter — mais une suite peut lire ses hypothèses.
	# Il en a plus que les autres parce qu'il touche à tout : les menus, une
	# manche entière, la mort, le shader des illustrations, les miniatures de
	# cartes. C'est précisément ce qui le rend fragile — et ce qui rend cette
	# liste utile.
	var Photo: GDScript = load("res://tools/photographe.gd")
	var manquants_photo: Array[String] = Photo.preconditions_manquantes(ui, main)
	_check("tous les appuis du photographe existent encore",
		manquants_photo.is_empty(), "; ".join(manquants_photo))
	var vides_photo: Array[String] = Photo.preconditions_manquantes(null, null)
	_check("et il sait dire quand ils manquent", not vides_photo.is_empty())

	# ⚠️ **DEUX ILLUSTRATIONS POUR UNE MÊME CLÉ : LE PHOTOGRAPHE EN GARDE UNE, ET
	# C'EST L'ORDRE ALPHABÉTIQUE QUI TRANCHE.** Son garde est juste — sans lui, la
	# seconde planche écraserait la première. Ce qui manquait, c'est que le
	# départage est MUET : `ill_creer.png` passait avant `ill_creer_ligne.png`
	# parce que le point vaut moins que le souligné, et la planche d'illustrations
	# a montré l'ANCIEN dessin à la place de celui que le jeu affiche, pour
	# « créer » comme pour « rejoindre ». Une semaine sans que rien ne le dise, et
	# trouvé par hasard en vérifiant si trois fichiers étaient morts (2026-09-23).
	#
	# Le piège revient au prochain fichier oublié, et il a une seconde bouche :
	# `cle_canonique()` retombe sur `ill_accueil` pour tout nom inconnu, si bien
	# qu'une illustration ajoutée sans entrée dans `POIS` masque l'accueil ou se
	# fait masquer par lui, selon son nom.
	#
	# La garde lit la liste du photographe LUI-MÊME plutôt que de recopier son
	# filtre : un filtre recopié diverge le jour où il change le sien.
	# Typé à la main : `GDScript.new()` rend un `Variant`, et ce dépôt traite
	# l'inférence depuis un Variant comme une erreur.
	var photographe: Node = Photo.new()
	var collisions: Array[String] = _collisions_de_cles(photographe._illustrations())
	photographe.free()
	_check("aucune illustration n'en masque une autre sur la planche",
		collisions.is_empty(), "; ".join(collisions))
	# Une garde qu'on n'a jamais vue rougir ne prouve rien : on lui repasse le cas
	# qui a réellement eu lieu.
	_check("et la garde sait dire quand deux illustrations se masquent",
		not _collisions_de_cles(["res://assets/ui/ill_creer.png",
			"res://assets/ui/ill_creer_ligne.png"]).is_empty())

	# ISO12 — le crochet que la LOUPE appelle chez le photographe (`p._poser_la_lumiere_3d()`, `tools/loupe.gd`), pour allumer
	# la lumière 3D bridée pendant les cadrages de l'adversaire. L'appel est inter-fichier sur une variable typée `Node` :
	# GDScript le résout dynamiquement, donc **rien ne le vérifie avant la séance**, et un renommage sortirait des images de
	# la vue d'ISO11 sous le nom « avec lumière 3D ». La garde ne couvre que le CALLEE : elle attrape le renommage du
	# photographe, pas une faute de frappe dans la loupe.
	var texte_photo := FileAccess.get_file_as_string("res://tools/photographe.gd")
	_check("le photographe expose encore _poser_la_lumiere_3d() pour la loupe",
		texte_photo.contains("func _poser_la_lumiere_3d("),
		"la loupe l'appelle en inter-fichier, sans contrôle à la compilation")
	var texte_loupe := FileAccess.get_file_as_string("res://tools/loupe.gd")
	_check("et la loupe l'appelle encore",
		texte_loupe.contains("_poser_la_lumiere_3d("),
		"sans cet appel, les cadrages « adversaire » sortent en vue d'ISO11")

	# ISO12 v27 — LE RELIEF, même faiblesse et pire conséquence. `presentation_3d.gd` demande au miroir la liste des lampes
	# pour le dénominateur du relief, et il ne peut le faire QUE par son nom, en texte : `_lumieres` est typé `Node3D`, et
	# `lumieres_iso.gd` ne déclare aucun `class_name` — il n'existe aucun type à écrire. Rien ne vérifie donc cet appel avant
	# l'exécution.
	#
	# ⚠️ **Et l'échec serait MUET.** `call()` sur une méthode absente rend `null` : `lampes` vide, `relief_nb` à 0, et la garde
	# du dénominateur vide rend alors proprement le Lambert d'avant la v27. Le relief aurait DISPARU, le lot resterait vert, et
	# les planches auraient seulement l'air « un peu plates ». C'est la forme exacte du `has_method()` du 2026-09-09.
	var texte_miroir := FileAccess.get_file_as_string("res://lumieres_iso.gd")
	_check("le miroir expose encore decrire_pour_relief() pour le relief",
		texte_miroir.contains("func decrire_pour_relief("),
		"sans elle, relief_nb tombe à 0 et le relief disparaît SANS rougir le lot")
	var texte_pose := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("et la présentation la demande encore",
		texte_pose.contains("decrire_pour_relief"),
		"sans cet appel, les lampes ne sont jamais posées et le relief est muet")
	# Le troisième fil : la pose doit être APPELÉE, et À CHAQUE IMAGE, juste après que le miroir a suivi ses lampes. La première
	# version de ce contrôle vérifiait « appelée depuis la bride » : c'était vrai, et ne prouvait rien — la bride ne tourne pas
	# à chaque image, la liste restait vide ou figée (revue d'ISO7 Beauté, 2026-09-22). Un texte ne prouve pas l'image : le
	# juge du relief est le banc (`--v27`), ceci n'empêche qu'une régression textuelle.
	var i_suivre := texte_pose.find("_lumieres.call(\"suivre\", _main, _voxels)")
	var i_relief := texte_pose.find("_accorder_le_relief()", i_suivre) if i_suivre >= 0 else -1
	var i_led := texte_pose.find("_accorder_la_led()", i_suivre) if i_suivre >= 0 else -1
	_check("et _accorder_le_relief() est appelée à chaque image, après le suivi des lampes",
		i_suivre >= 0 and i_relief > i_suivre and i_relief < i_led,
		"posée ailleurs qu'à chaque image, la liste des lampes serait celle d'une autre image")
	# Le canal mort ne doit pas revenir : SPECULAR_AMOUNT est la propriété de la LAMPE, pas une sortie de fragment().
	for nom_shader in ["sol_iso_eclaire", "mur_iso_eclaire", "corps_iso_eclaire"]:
		var texte_shader := FileAccess.get_file_as_string("res://%s.gdshader" % nom_shader)
		_check("%s passe le dénominateur par le varying, jamais par SPECULAR_AMOUNT" % nom_shader,
			texte_shader.contains("relief_d = relief_denominateur(") and not texte_shader.contains("SPECULAR_AMOUNT"),
			"SPECULAR_AMOUNT vaut 2 × light_specular de la lampe : le relief y serait éteint sans erreur")
	# Les poids de luminance du miroir doivent être ceux de la pâte : sinon R ne vaut plus 1 sur un sol plat.
	var texte_pate := FileAccess.get_file_as_string("res://iso_pate.gdshaderinc")
	_check("le miroir mesure l'intensité aux poids de la pâte",
		texte_pate.contains("vec3(0.2126, 0.7152, 0.0722)") and texte_miroir.contains("Vector3(0.2126, 0.7152, 0.0722)"),
		"des poids différents décaleraient R de la couleur des lampes")
	# Le plancher du relief et la couleur de la L2D (décisions (2) et (3), 2026-09-23) : posés à chaque image par la présentation,
	# et lus par les TROIS matériaux éclairés — un shader qui oublierait l'émission du plancher garderait ses faces noires.
	var plancher_lu := texte_pose.contains("set_shader_parameter(\"relief_plancher\", relief_plancher_3d)") \
		and texte_pose.contains("set_shader_parameter(\"relief_couleur_l2d\", relief_couleur_l2d_3d)")
	for nom_eclaire in ["sol_iso_eclaire", "mur_iso_eclaire", "corps_iso_eclaire"]:
		var texte_eclaire := FileAccess.get_file_as_string("res://%s.gdshader" % nom_eclaire)
		plancher_lu = plancher_lu and texte_eclaire.contains("EMISSION = relief_emission_plancher(EMISSION, ALBEDO);")
		if nom_eclaire != "corps_iso_eclaire":
			plancher_lu = plancher_lu and texte_eclaire.contains("relief_chroma(brute)")
	_check("le plancher du relief et la couleur de la L2D sont posés, et chaque matériau éclairé les lit", plancher_lu,
		"sans plancher, un adversaire que la 2D éclaire perd un quart de sa silhouette en 3D")
	# LE PRINCIPE D'IDENTITÉ (session cloud, 2026-09-23, 02:17) : l'albédo 3D est la couleur du chemin 2D, par les MÊMES
	# fonctions — recopiées dans les shaders éclairés plutôt qu'extraites dans un include, pour ne toucher ni aux shaders de la
	# vue d'ISO11 ni à ceux des corps. Une copie qui dériverait d'un seul caractère ferait diverger la 3D de la 2D EN SILENCE :
	# cette garde la compare octet pour octet, et vérifie que le fragment éclairé l'appelle bien.
	var paires := [
		["sol_iso", "sol_iso_eclaire", ["float ton_du_sol(vec2 p)", "vec3 lightmap_pateuse_sol(vec2 p, vec2 motif, float aa, bool deux)",
			"float contact_des_corps(vec2 p)"], "vec3 c2d = lightmap_pateuse_sol(px_lu, px, aa, deux);"],
		# Chantier RR, RR3 — et la lueur des LED au pied des murs (Q90 = (b)), copiée à l'identique.
		["mur_iso", "mur_iso_eclaire", ["vec3 lightmap_pateuse_lue(vec3 c, vec2 motif, float aa)", "vec3 lumiere_des_led(vec2 px, vec3 ref)"],
			"identite_2d ? lightmap_pateuse_lue(brute, motif, aa)"],
		["corps_iso", "corps_iso_eclaire", ["vec3 lumiere_du_capteur("], "c2d = min(pate(base2d, pate_luminance(base2d), style, motif, vec2(0.0), recue, aa), base2d);"],
	]
	var identiques := true
	var ecarts: PackedStringArray = []
	for paire in paires:
		var texte_2d := FileAccess.get_file_as_string("res://%s.gdshader" % paire[0])
		var texte_3d := FileAccess.get_file_as_string("res://%s.gdshader" % paire[1])
		for signature in paire[2]:
			var f2 := _fonction_de_shader(texte_2d, signature)
			if f2 == "" or f2 != _fonction_de_shader(texte_3d, signature):
				identiques = false
				ecarts.append("%s / %s : %s" % [paire[0], paire[1], signature])
		if not texte_3d.contains(paire[3]):
			identiques = false
			ecarts.append("%s n'appelle plus le chemin 2D" % paire[1])
	_check("le principe d'identité : les fonctions du chemin 2D, recopiées dans les shaders éclairés, y sont identiques",
		identiques, "; ".join(ecarts))
	# ISO12 L2 — LE CORPS DU FRAGMENT, pas seulement ses fonctions. Le sol et les murs éclairés recopient AUSSI les étapes du
	# fragment 2D : matière, dalles, encre des arêtes, liseré, contact au pied, température, contact des corps. Une étape
	# ajoutée à `sol_iso` ou `mur_iso` sans l'être au shader éclairé ferait diverger la 3D de la 2D en silence — la garde
	# ci-dessus ne voit que les fonctions. Ici, chaque ligne de code du fragment 2D doit se retrouver dans le fragment éclairé,
	# telle quelle ou sous l'un des renommages et remplacements DÉCLARÉS (l'identité y devient un choix `identite_2d ? … :
	# bride_de(…)`). Ce que la garde ne voit pas : l'ORDRE des étapes, et une ligne présente dans une autre branche.
	var fragments := [
		["sol_iso", "sol_iso_eclaire", {"c": "c2d", "brute": "brute2d"}, {}],
		["mur_iso", "mur_iso_eclaire", {}, {
			"c = lightmap_pateuse(monde.xz, motif, aa, deux);":
				"c = identite_2d ? lightmap_pateuse(monde.xz, motif, aa, deux) : bride_de(brute, motif, aa);",
			"c = pate_facteur(lightmap_pateuse_lue(brute, motif, aa), lisere);":
				"c = pate_facteur(identite_2d ? lightmap_pateuse_lue(brute, motif, aa) : bride_de(brute, motif, aa), lisere);",
			"c = lightmap_pateuse_lue(brute, motif, aa);":
				"c = identite_2d ? lightmap_pateuse_lue(brute, motif, aa) : bride_de(brute, motif, aa);",
		}],
	]
	var absentes: PackedStringArray = []
	for f in fragments:
		var lignes_2d := _lignes_du_fragment(FileAccess.get_file_as_string("res://%s.gdshader" % f[0]))
		var lignes_3d := _lignes_du_fragment(FileAccess.get_file_as_string("res://%s.gdshader" % f[1]))
		if lignes_2d.is_empty() or lignes_3d.is_empty():
			absentes.append("%s : fragment introuvable" % f[0])
			continue
		for l in lignes_2d:
			var renommee := l
			for ancien in (f[2] as Dictionary):
				var re := RegEx.new()
				re.compile("\\b%s\\b" % ancien)
				renommee = re.sub(renommee, String(f[2][ancien]), true)
			# ⚠️ Une ligne que le renommage CHANGE ne vaut que renommée : le sol éclairé garde son ancien chemin (hors identité),
			# qui porte `c = pate_facteur(c, contact_des_corps(px));` mot pour mot — retirer le contact de la branche d'identité
			# serait passé pour présent (vu en écrivant cette garde, sabotage à l'appui).
			if renommee != l:
				if renommee in lignes_3d:
					continue
			elif l in lignes_3d:
				continue
			elif (f[3] as Dictionary).has(l) and String(f[3][l]) in lignes_3d:
				continue
			absentes.append("%s : « %s »" % [f[0], l])
	_check("le principe d'identité : chaque étape du fragment 2D du sol et des murs est dans le fragment éclairé",
		absentes.is_empty(), "; ".join(absentes))
	# ISO12 — le pied de lampe : à gain nul, zéro SANS lire les textures (la sortie en tête) ; à gain non nul, il éclaire
	# encore (la lecture, pondérée par le gain, et l'appel dans l'émission de l'ancien chemin sont toujours là). La condition
	# inversée — `> 0.0` — éteindrait le pied pour tout gain utile, et la garde la refuse (mutation vue rougir, 2026-09-23).
	var sol_eclaire := FileAccess.get_file_as_string("res://sol_iso_eclaire.gdshader")
	var pied := _fonction_de_shader(sol_eclaire, "vec3 lire_pied_lampe(vec2 px)")
	var tete := pied.find("if (pied_lampe_gain <= 0.0) {\n\t\treturn vec3(0.0);\n\t}")
	_check("le pied de lampe : zéro sans lecture à gain nul, et il éclaire encore à gain non nul",
		tete >= 0 and tete < pied.find("texture(pied_lampe_texture")
		and pied.contains("somme += texture(pied_lampe_texture, uv).a * pied_lampe_couleur * h.z * pied_lampe_gain;")
		and sol_eclaire.contains("lire_pied_lampe(px_lu)"),
		"sortie en tête absente, placée après la lecture, ou condition inversée")
	# Au plus huit lampes miroir (session cloud, 03:50) : le plafond existe, vaut huit, et `suivre` l'applique À CHAQUE IMAGE.
	# Sans lui, neuf lampes et plus faisaient du dénominateur et des lampes appariées par le moteur deux jeux différents.
	_check("le miroir plafonne à huit lampes allumées, à chaque image",
		texte_miroir.contains("const LAMPES_MAX := 8") and texte_miroir.contains("	_plafonner(LAMPES_MAX)"),
		"au-delà de huit lampes, le sol s'éclaircissait de 8 % sans ombres")
	# LE GO RÉDUIT (session cloud, 2026-09-23, 04:45) : la lumière 3D éteinte par défaut, sans ombres portées par défaut, et
	# jamais allumée en écran scindé hors banc. Une ligne qui sauterait rallumerait en jeu une variante qui ne tient pas la cadence.
	_check("la lumière 3D : éteinte par défaut, sans ombres portées, jamais en écran scindé hors banc",
		texte_pose.contains("var lumiere_3d := false") and texte_pose.contains("var ombres_3d := false")
		and texte_pose.contains("var lumiere_3d_ecran_scinde := false")
		and texte_pose.contains("active = active and (not _scinde or lumiere_3d_ecran_scinde)"),
		"en écran scindé, A gardait 38 à 82 % du 1 % bas du jeu sans lumière 3D")
	# Les instruments de la fusée (ISO7 Gadgets, 2f06b1b) vivent dans le code du JEU, pas du banc : leurs défauts doivent rester
	# « tout dessiner » (session cloud, 05:30). Un défaut qui sauterait retirerait une part de la fusée en match, sans erreur.
	var texte_volumes := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("les instruments de la fusée dessinent tout par défaut (volumes, lueurs, toutes les couches)",
		texte_volumes.contains("var volumes_actifs := true") and texte_volumes.contains("var lueurs_actives := true")
		and texte_volumes.contains("var couches_fusee := -1"),
		"un défaut changé couperait le volume, les lueurs ou des couches de la fusée en jeu")
	# ISO12 L1 : le plancher d'angle des spots de torche, et sa variable de banc qui le vaut par défaut.
	_check("le plancher des spots de torche vaut 75°, et la variable de banc le reprend par défaut",
		texte_miroir.contains("const CONE_PLANCHER_DEG := 75.0") and texte_miroir.contains("var cone_plancher_deg := CONE_PLANCHER_DEG"),
		"à 45°, jusqu'à 2 % de l'empreinte 2D sortait du spot : couture de relief sur les faces proches")
	# ε par lampe (L4) : le miroir plafonne h/portée au plancher global, qui doit valoir le défaut de l'include ; et l'include
	# doit le LIRE dans direction.w, sans quoi ε par lampe serait calculé puis ignoré sans erreur.
	var texte_relief := FileAccess.get_file_as_string("res://iso_relief.gdshaderinc")
	_check("le plancher ε du miroir vaut celui de l'include, et l'include lit ε par lampe",
		texte_miroir.contains("const RELIEF_EPSILON := 0.02") and texte_relief.contains("uniform float relief_epsilon = 0.02;")
		and texte_relief.contains("relief_direction[i].w > 0.0 ? relief_direction[i].w : relief_epsilon")
		and texte_pose.contains("lampe.get(\"epsilon\", 0.0)"),
		"braises et mine, posées à 1,75 px, retomberaient à 0,515 et 0,337 au bord de leur halo")

	# Le catalogue lui-même. **Une image dont l'identifiant est en double
	# écraserait l'autre en silence** : les deux fichiers portent le nom de leur
	# identifiant, et le manifeste décrirait la survivante sous les deux fiches.
	# Le reste tient à ce que le manifeste et la planche promettent : un titre et
	# un `pourquoi` sous chaque vignette — une image de communication dont
	# personne ne sait plus à quoi elle servait est une image perdue.
	var vus := {}
	var doublons: Array[String] = []
	var muets: Array[String] = []
	var familles_inconnues: Array[String] = []
	var sources_inconnues: Array[String] = []
	for plan in Photo.catalogue():
		var id := String(plan.get("id", ""))
		if vus.has(id):
			doublons.append(id)
		vus[id] = true
		if String(plan.get("titre", "")) == "" or String(plan.get("pourquoi", "")) == "":
			muets.append(id)
		if not Photo.FAMILLES.has(String(plan.get("famille", ""))):
			familles_inconnues.append(id)
		if not ["ecran", "vue", "propre"].has(String(plan.get("source", ""))):
			sources_inconnues.append(id)
	_check("aucun identifiant de plan en double", doublons.is_empty(),
		", ".join(doublons))
	_check("chaque plan dit son titre et à quoi il sert", muets.is_empty(),
		", ".join(muets))
	_check("chaque plan appartient à une famille connue",
		familles_inconnues.is_empty(), ", ".join(familles_inconnues))
	_check("chaque plan nomme une source connue", sources_inconnues.is_empty(),
		", ".join(sources_inconnues))

	# ⚠️ **Les identifiants de plan sont devenus un CONTRAT, le 2026-09-09.**
	#
	# La session DA7 nomme ses plans de trailer et ses instructions de presskit
	# par ces identifiants-là, pour qu'ils soient directement commandables à
	# `run_photos.sh` plutôt qu'à réinterpréter. Un `--plan=duel` écrit dans un
	# découpage de trailer et un `"id": "duel"` écrit dans ce catalogue sont
	# désormais la même chaîne, tenue aux deux bouts par personne.
	#
	# **Renommer un plan ne casserait rien de visible ici** : l'outil rendrait
	# simplement une image de moins, et le document d'en face désignerait un plan
	# qui n'existe plus. C'est le motif que ce dépôt appelle « se périme en
	# silence », et c'est exactement ce que cette suite existe pour attraper.
	#
	# Le contrôle porte sur la PRÉSENCE, pas sur l'égalité : ajouter un plan reste
	# libre — c'est retirer ou renommer qui doit faire rougir une suite et obliger
	# celui qui le fait à prévenir.
	var promis: Array[String] = ["accueil", "salon-local", "personnalisation",
		"reglages", "cadre-rang", "cadre-profil", "cadre-historique", "power-on",
		"code-de-salon", "artworks", "plans", "decompte", "duel", "torche",
		"retrodiffusion", "flash-de-tir", "eblouissement", "fusee", "sang",
		"armes", "hud", "ecran-scinde", "entrainement", "killcam", "gel-fatal",
		"affiche", "soiree", "verdict-victoire", "verdict-defaite",
		"verdict-egalite", "bilan"]
	var disparus: Array[String] = []
	for id in promis:
		if not vus.has(id):
			disparus.append(id)
	_check("aucun identifiant de plan promis au-dehors n'a disparu",
		disparus.is_empty(), ", ".join(disparus)
		+ " — prévenir la session qui les nomme avant de renommer")

	# ⚠️ **Et depuis le 2026-09-09, le photographe a un HÉRITIER.**
	#
	# `tools/cineaste.gd` fait `extends "res://tools/photographe.gd"` et ne
	# surcharge que `_prendre()` : là où le photographe tient l'état puis
	# déclenche, le cinéaste tient l'état et ne déclenche jamais, le moteur
	# écrivant chaque image. Rien n'est copié — c'est délibéré, et c'est ce qui
	# évite deux mises en scène qui divergent.
	#
	# **Le prix de ce choix est que des membres PRIVÉS deviennent une interface.**
	# Un `_valeur` renommé en `_argument` ne casse rien ici, ne rougit nulle part,
	# et fait tomber le trailer. Le préfixe souligné dit « n'y touchez pas » à un
	# lecteur ; il ne dit rien à une suite. Celle-ci le dit.
	var empruntes: Array[String] = ["_prendre", "_valeur", "_drapeau", "_vivants",
		"_sortir"]
	var perdus: Array[String] = []
	var connus := {}
	for m in Photo.get_script_method_list():
		connus[m["name"]] = true
	for nom in empruntes:
		if not connus.has(nom):
			perdus.append(nom)
	# `_pantins` et `Marionnette` ne sont pas des méthodes : l'un est une
	# variable, l'autre une classe interne. On les interroge autrement.
	var texte := FileAccess.get_file_as_string("res://tools/photographe.gd")
	for motif in ["var _pantins", "class Marionnette"]:
		if not texte.contains(motif):
			perdus.append(motif)
	_check("les membres dont hérite tools/cineaste.gd existent encore",
		perdus.is_empty(), ", ".join(perdus)
		+ " — prévenir la session DA7 avant de renommer")

	# OMBRES, OM0 — LE BANC DES OMBRES (`tools/planche_ombres.gd`, chantier OMBRES, 2026-10-04). Même raison et même remède que
	# le photographe : il ouvre une fenêtre (Xvfb), aucune suite ne peut l'exécuter, et un outil hors couverture se périme en
	# silence. Il pose une salle d'aventure, fige ses PNJ, relit la lightmap et les capteurs : ses appuis sont nommés ici.
	var Ombres: GDScript = load("res://tools/planche_ombres.gd")
	var manquants_ombres: Array[String] = Ombres.preconditions_manquantes(ui, main)
	_check("tous les appuis du banc des ombres existent encore",
		manquants_ombres.is_empty(), "; ".join(manquants_ombres))
	_check("et il sait dire quand ils manquent",
		not (Ombres.preconditions_manquantes(null, null) as Array).is_empty())
	# Son catalogue : chaque plan nomme une salle qui existe, un PNJ que cette salle a, une classe qui existe — sans quoi le banc
	# refuse le plan en séance, devant quelqu'un qui attendait une planche.
	var fautes_ombres := _fautes_du_catalogue_des_ombres(Ombres.plans())
	_check("le catalogue du banc des ombres ne nomme que des salles, des PNJ et des classes qui existent",
		fautes_ombres.is_empty(), "; ".join(fautes_ombres))
	_check("et la garde du catalogue sait dire quand un plan nomme une salle absente",
		not _fautes_du_catalogue_des_ombres([{"id": "faux", "salle": [0, 99], "cible": 0}]).is_empty())
	# Il hérite du photographe, comme le cinéaste : ces membres PRIVÉS sont son interface.
	var empruntes_ombres: Array[String] = ["_valeur", "_drapeau", "_lire_taille", "_poser_la_fenetre", "_attendre",
		"_attendre_disparition", "_sortir", "_commit"]
	var perdus_ombres: Array[String] = []
	for nom in empruntes_ombres:
		if not connus.has(nom):
			perdus_ombres.append(nom)
	for motif in ["var _pantins", "class Marionnette", "var _main", "var _dossier", "var _taille", "const Commun"]:
		if not texte.contains(motif):
			perdus_ombres.append(motif)
	_check("les membres dont hérite tools/planche_ombres.gd existent encore",
		perdus_ombres.is_empty(), ", ".join(perdus_ombres) + " — prévenir le chantier OMBRES avant de renommer")

	# ⚠️ **L'état que le banc DEMANDE est-il celui que le joueur GARDE ?**
	#
	# Le banc écrivait `p.flashlight_on = true` et annonçait « torches allumées » ;
	# `player.gd` réécrit ce drapeau depuis la gâchette à chaque pas de physique,
	# avant d'allumer la lampe. Du 2026-08-15 au 2026-09-14, **chaque relevé a donc
	# été pris lampes éteintes**, et aucune suite ne pouvait le voir : les appuis
	# ci-dessus vérifient que le banc DÉMARRE, pas que sa charge est celle qu'il dit.
	#
	# Ce contrôle joue une vraie manche — le chemin du banc, rien de forcé — et lit
	# `flashlight.enabled`, la lampe réelle, jamais le drapeau que le banc écrit.
	await _torche_du_banc(Banc, main, ui)

	main.queue_free()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


## OM6 — le MODE SOLO du banc de cadence, SANS fenêtre : la lecture de ses arguments, le poste de J1 sur la vraie salle 8.9, J1 qui tient sa
## visée, et les trois interrupteurs de lumière joués sur des nœuds fabriqués ici. Ce que la suite ne peut pas voir : le rendu (Xvfb) et la
## fusillade elle-même (elle demande des images, des PNJ qui tirent).
func _verifier_le_solo_du_banc(Banc: GDScript, main: Node) -> void:
	# 1. Les arguments : un drapeau lu de travers fait mesurer autre chose, sans un mot.
	_check("--solo=8.9 se lit : le chapitre 8, l'index 8 (la 9e salle, niveau_09.json)", Banc.lire_la_salle("8.9") == [8, 8],
		str(Banc.lire_la_salle("8.9")))
	_check("--solo=0.1 est la première salle du chapitre 0", Banc.lire_la_salle("0.1") == [0, 0])
	var mal_lues: Array[String] = []
	for texte in ["", "8", "8.", ".9", "8.0", "8.11", "11.1", "a.b", "8.9.1", "8,9", "-1.1", " 8.9"]:
		if not (Banc.lire_la_salle(texte) as Array).is_empty():
			mal_lues.append("« %s »" % texte)
	_check("une salle mal écrite ou hors du catalogue est refusée", mal_lues.is_empty(), ", ".join(mal_lues))
	_check("la salle 8.9 est le fichier que dit la ROADMAP, et il existe",
		Banc.chemin_de_la_salle(8, 8) == "res://assets/solo/chapitre_08/niveau_09.json" and FileAccess.file_exists(Banc.chemin_de_la_salle(8, 8)),
		Banc.chemin_de_la_salle(8, 8))
	_check("--solo-poste se lit en case, et refuse ce qui n'en est pas une",
		Banc.lire_le_poste("38,20") == Vector2i(38, 20) and Banc.lire_le_poste("38") == Vector2i(-1, -1)
		and Banc.lire_le_poste("a,b") == Vector2i(-1, -1) and Banc.lire_le_poste("-3,4") == Vector2i(-1, -1))
	var nu: Variant = Banc.valeur_egal(PackedStringArray(["--solo=8.9", "--seconds", "20", "--solo", "--x="]), "--solo")
	_check("un drapeau nu vaut « » (le dernier l'emporte), un drapeau absent null",
		nu is String and String(nu) == "" and Banc.valeur_egal(PackedStringArray(["--seconds", "20"]), "--solo") == null
		and String(Banc.valeur_egal(PackedStringArray(["--solo=1.1", "--solo=2.2"]), "--solo")) == "2.2")
	var bons := PackedStringArray(["--solo=8.9", "--sans-ombres-2d", "--sans-capteurs", "--sans-halos-pnj", "--solo-poste=38,20",
		"--solo-graine=7", "--seconds", "20", "--physique", "8", "--seuil-lent", "1", "--lightmap", "1080p", "--temps-par-vue"])
	_check("--solo accepte ses réglages, ses interrupteurs et les options communes du banc",
		(Banc.refus_du_solo(bons) as Array).is_empty(), "; ".join(Banc.refus_du_solo(bons)))
	var acceptes_a_tort: Array[String] = []
	for f in Banc.DRAPEAUX_DU_DUEL:
		if (Banc.refus_du_solo(PackedStringArray(["--solo=8.9", f])) as Array).is_empty():
			acceptes_a_tort.append(f)
	if (Banc.refus_du_solo(PackedStringArray(["--solo=8.9", "--classe=pompe"])) as Array).is_empty():
		acceptes_a_tort.append("--classe=")
	_check("--solo refuse chaque drapeau du duel (les lire sans les appliquer mesurerait autre chose)", acceptes_a_tort.is_empty(),
		", ".join(acceptes_a_tort))
	# La liste ci-dessus se lit dans la constante qu'elle contrôle : retirer un drapeau de `DRAPEAUX_DU_DUEL` le retirerait aussi du
	# contrôle (vu au sabotage). Ce contrôle-ci est COMPLET : tout drapeau que `_ready()` lit est accepté par le solo (la courte liste
	# ci-dessous, ses propres drapeaux et les options communes) ou refusé par lui. Un drapeau du duel ajouté plus tard à `_ready()` sans
	# l'être à `DRAPEAUX_DU_DUEL` serait lu par le duel et IGNORÉ par le solo, en silence.
	var texte_ready := FileAccess.get_file_as_string("res://tools/bench_framerate.gd")
	var i_ready := texte_ready.find("func _ready() -> void:")
	var i_suite := texte_ready.find("\nfunc ", i_ready + 10)
	var corps_ready := texte_ready.substr(i_ready, i_suite - i_ready)
	var communs := ["--seconds", "--max-fps", "--physique", "--iso", "--lightmap", "--seuil-lent", "--temps-par-vue", "--solo",
		"--solo-poste", "--solo-graine", "--sans-ombres-2d", "--sans-capteurs", "--sans-halos-pnj",
		# OM3c (Q85) : deux réglages d'ombre, valables en duel comme en solo.
		"--atlas-ombres", "--pcf5"]
	var lus: Array[String] = []
	var oublies: Array[String] = []
	for m in RegEx.create_from_string("\"(--[a-z0-9-]+)").search_all(corps_ready):
		var drapeau := m.get_string(1)
		if drapeau in communs or drapeau in lus:
			continue
		lus.append(drapeau)
		var essai := "--classe=pompe" if drapeau == "--classe" else drapeau
		if (Banc.refus_du_solo(PackedStringArray(["--solo=8.9", essai])) as Array).is_empty():
			oublies.append(drapeau)
	_check("tout drapeau du duel que le banc lit est refusé par --solo (sinon le solo l'ignorerait en silence)",
		oublies.is_empty() and lus.size() >= 15, "oubliés : %s ; %d drapeaux du duel lus" % [", ".join(oublies), lus.size()])
	_check("--sans-halos-pnj, --solo-poste et --solo-graine sans --solo sont refusés : un duel n'a ni PNJ ni salle",
		not (Banc.refus_du_solo(PackedStringArray(["--sans-halos-pnj"])) as Array).is_empty()
		and not (Banc.refus_du_solo(PackedStringArray(["--solo-poste=3,3"])) as Array).is_empty()
		and not (Banc.refus_du_solo(PackedStringArray(["--solo-graine=3"])) as Array).is_empty())
	_check("une salle absente, un poste ou une graine illisibles sont refusés",
		not (Banc.refus_du_solo(PackedStringArray(["--solo=8.99"])) as Array).is_empty()
		and not (Banc.refus_du_solo(PackedStringArray(["--solo=8.9", "--solo-poste=x"])) as Array).is_empty()
		and not (Banc.refus_du_solo(PackedStringArray(["--solo=8.9", "--solo-graine=x"])) as Array).is_empty())
	_check("un duel garde ses drapeaux, et accepte --sans-ombres-2d et --sans-capteurs",
		(Banc.refus_du_solo(PackedStringArray(["--vue-unique", "--fusee", "--classe=pompe", "--sans-ombres-2d", "--sans-capteurs"])) as Array).is_empty())

	# 2. Le poste de J1, sur la vraie salle 8.9 : le modèle de vue des bots, pas une distance devinée.
	var Format: GDScript = load("res://aventure_format.gd")
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string(Banc.chemin_de_la_salle(8, 8)))
	var niveau: Dictionary = Format.preparer_niveau(brut)
	var poste: Dictionary = Banc.choisir_le_poste(niveau)
	_check("en 8.9, le poste de J1 est vu au départ d'au moins un PNJ qui voit et tire (sinon la salle se mesure vide)",
		int(poste.get("vus", 0)) >= 1, str(poste))
	_check("… et il n'est pas le coin d'où le niveau fait partir J1", poste.get("case") != niveau["joueur"]["case"], str(poste.get("case")))
	_check("une case imposée qui est un mur est refusée, avec sa raison", Banc.choisir_le_poste(niveau, Vector2i(0, 0)).has("erreur"))
	var rejoue: Dictionary = Banc.choisir_le_poste(niveau, poste["case"])
	_check("une case imposée est jugée comme les autres : la même case rend le même nombre de PNJ qui la voient",
		int(rejoue.get("vus", -1)) == int(poste["vus"]), str(rejoue))

	# 3. J1 tient sa visée : un fournisseur local (le jeu y retrouve la manette et le cran de la torche) dont la visée n'est pas la souris.
	var Poste: GDScript = Banc.get_script_constant_map()["PosteDeJ1"]
	var fournisseur = Poste.new()
	fournisseur.visee = Vector2(0.0, 1.0)
	_check("J1 au poste vise là où le banc le dit, quelle que soit la souris, et reste un fournisseur local de la torche",
		fournisseur.get_aim_direction(Vector2(500.0, 500.0)) == Vector2(0.0, 1.0) and "action_torch" in fournisseur and "device_id" in fournisseur)
	fournisseur.free()

	# 4. Les trois interrupteurs, joués sur des nœuds fabriqués ici (le balayage ne touche que ce sous-arbre).
	var Inter: GDScript = Banc.get_script_constant_map()["Interrupteurs"]
	var scene := Node2D.new()
	scene.name = "EssaiInterrupteurs"
	root.add_child(scene)
	var existante := PointLight2D.new()
	existante.shadow_enabled = true
	scene.add_child(existante)
	var ombres = Inter.new()
	ombres.sans_ombres_2d = true
	ombres.armer(self, [], null, null, scene)
	_check("--sans-ombres-2d éteint l'ombre de ce qui existe — et JAMAIS `enabled`, que lit la perception des bots",
		not existante.shadow_enabled and existante.enabled and ombres.lumieres_eteintes_au_depart == 1, "ombre %s, enabled %s"
		% [existante.shadow_enabled, existante.enabled])
	var nee := PointLight2D.new()
	nee.shadow_enabled = true
	scene.add_child(nee)
	var nee_sans := PointLight2D.new()
	nee_sans.shadow_enabled = false
	scene.add_child(nee_sans)
	_check("une lumière NÉE après l'armement est éteinte à son entrée dans l'arbre (node_added), `enabled` intact ; celle née sans ombre est comptée née, pas éteinte",
		not nee.shadow_enabled and nee.enabled and ombres.lumieres_nees == 2 and ombres.lumieres_nees_a_ombre == 1,
		"nées %d dont %d à ombre" % [ombres.lumieres_nees, ombres.lumieres_nees_a_ombre])
	nee.shadow_enabled = true
	var bilan: Dictionary = ombres.finir()
	_check("la vérification de la fin voit une lumière qui a repris son ombre, et la rend comme un défaut",
		(bilan["lumieres_a_ombre"] as Array).size() == 1 and not (ombres.defauts(bilan) as Array).is_empty(), str(bilan))
	_check("… et débranche son crochet de naissance (finir)", not node_added.is_connected(Callable(ombres, "_sur_un_noeud")))
	nee.shadow_enabled = false
	# Un drapeau ne règle que sa lumière : --sans-capteurs ne touche à aucune ombre.
	var seul_capteurs = Inter.new()
	seul_capteurs.sans_capteurs = true
	seul_capteurs.armer(self, [], null, null, scene)
	var intacte := PointLight2D.new()
	intacte.shadow_enabled = true
	scene.add_child(intacte)
	_check("--sans-capteurs ne touche à aucune lumière : chaque interrupteur ne règle que le sien",
		intacte.shadow_enabled and seul_capteurs.lumieres_nees == 0 and seul_capteurs.lumieres_eteintes_au_depart == 0)
	# Les capteurs : le jeu les rallume à chaque image, seul le crochet de dessin tient l'arrêt.
	var Capteur: GDScript = load("res://capteur_corps.gd")
	var capteur = Capteur.creer(0, 0, root.world_2d, 8, 1, null)
	scene.add_child(capteur)
	_check("un capteur de corps NÉ après l'armement est mis à l'arrêt à son entrée dans l'arbre",
		capteur.render_target_update_mode == SubViewport.UPDATE_DISABLED and seul_capteurs.capteurs_nes == 1)
	capteur.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_check("contre-test : le jeu le rallume (`Presentation3D._suivre`, à chaque image) et rien d'autre ne le rend alors à l'arrêt",
		capteur.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	seul_capteurs.avant_le_rendu()
	_check("le crochet de dessin le remet à l'arrêt, et compte les fois où le jeu l'avait rallumé",
		capteur.render_target_update_mode == SubViewport.UPDATE_DISABLED and seul_capteurs.capteurs_repris == 1)
	capteur.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bilan_capteurs: Dictionary = seul_capteurs.finir()
	_check("la vérification de la fin voit un capteur resté actif, et le rend comme un défaut",
		int(bilan_capteurs["capteurs_actifs"]) == 1 and not (seul_capteurs.defauts(bilan_capteurs) as Array).is_empty(), str(bilan_capteurs))
	# Les halos de PNJ : ceux des PNJ seulement. J1 se fait passer pour un PNJ le temps du contrôle.
	var j1: Node = main.p1
	var halo: PointLight2D = j1.ambient_light
	var halo_allume: bool = halo.enabled
	var ombre_du_halo: bool = halo.shadow_enabled
	halo.shadow_enabled = true
	var pas_un_pnj = Inter.new()
	pas_un_pnj.sans_halos_pnj = true
	pas_un_pnj.armer(self, [j1], null, null, scene)
	_check("--sans-halos-pnj ne touche pas le halo d'un joueur qui n'est pas un PNJ", halo.shadow_enabled and pas_un_pnj.halos_pnj.is_empty())
	j1.est_pnj = true
	var halos = Inter.new()
	halos.sans_halos_pnj = true
	halos.armer(self, [j1], null, null, scene)
	_check("--sans-halos-pnj éteint l'ombre du halo d'un PNJ (`ambient_light`), sans toucher à `enabled`",
		not halo.shadow_enabled and halo.enabled == halo_allume and halos.halos_pnj.size() == 1 and halos.halos_pnj_eteints == 1)
	j1.est_pnj = false
	halo.shadow_enabled = ombre_du_halo
	# L'étiquette d'une lumière : les numéros effacés, les anonymes nommés « · ».
	var pnj_3 := Node2D.new()
	pnj_3.name = "PNJ_3"
	scene.add_child(pnj_3)
	var anonyme := PointLight2D.new()
	pnj_3.add_child(anonyme)
	var nommee := PointLight2D.new()
	nommee.name = "Flashlight"
	pnj_3.add_child(nommee)
	_check("l'étiquette d'une lumière efface les numéros et nomme les lumières sans nom « · » (sept PNJ, une ligne)",
		Inter.etiquette_de(nommee) == "PNJ_#/Flashlight" and Inter.etiquette_de(anonyme) == "PNJ_#/·",
		"%s ; %s" % [Inter.etiquette_de(nommee), Inter.etiquette_de(anonyme)])
	# La règle des trois : aucune écriture de `enabled` dans la classe des interrupteurs (le texte, en plus des contrôles ci-dessus).
	var texte_banc := FileAccess.get_file_as_string("res://tools/bench_framerate.gd")
	var debut := texte_banc.find("class Interrupteurs extends RefCounted")
	var texte_classe := texte_banc.substr(debut) if debut >= 0 else ""
	_check("la classe des interrupteurs n'écrit jamais `enabled` (seul `shadow_enabled` se règle)",
		debut >= 0 and not texte_classe.contains(".enabled =") and not texte_classe.contains(".enabled="))
	for i in [ombres, seul_capteurs, pas_un_pnj, halos]:
		i.desarmer()
	scene.free()

## OMBRES, OM3c (Q85, Q83) — les réglages d'ombre que les deux bancs posent à l'exécution, SANS fenêtre : la lecture des arguments du
## banc de cadence, les lumières que Q85 filtre (`tools/reglages_ombres.gd`, partagé avec le banc des ombres), le PCF5 posé puis rendu
## sans toucher à `enabled` ni à `shadow_enabled`, sa vérification de fin ; et l'ancre des variantes de la pâte D. Ce que la suite ne
## voit pas : l'image (Xvfb) — la planche de Q83 et Q85 la montre, et le banc refuse une variante qui ne change aucun pixel.
func _verifier_les_reglages_d_ombre(Banc: GDScript, main: Node) -> void:
	var Reglages: GDScript = load("res://tools/reglages_ombres.gd")
	# 1. Les arguments : un réglage lu de travers ferait mesurer l'atlas du projet sous le nom d'un autre.
	var bons := PackedStringArray(["--atlas-ombres=4096", "--pcf5"])
	_check("--atlas-ombres=4096 et --pcf5 forment une prise valide (duel comme solo)",
		(Banc.refus_des_reglages(bons) as Array).is_empty() and (Banc.refus_des_reglages(PackedStringArray(["--pcf5=1.5"])) as Array).is_empty(),
		"; ".join(Banc.refus_des_reglages(bons)))
	var mal_lus: Array[String] = []
	for a in ["--atlas-ombres=abc", "--atlas-ombres=3000", "--atlas-ombres=128", "--atlas-ombres=32768", "--atlas-ombres", "--pcf5=-1",
			"--pcf5=doux"]:
		if (Banc.refus_des_reglages(PackedStringArray([a])) as Array).is_empty():
			mal_lus.append(a)
	_check("un atlas qui n'est pas une puissance de deux de 256 à 16384, ou un lissage qui n'est pas un nombre positif, est refusé",
		mal_lus.is_empty(), ", ".join(mal_lus))
	# Et le banc les refuse AVANT tout le reste, avec les refus du solo : une fonction juste que `_ready()` n'appelle pas ne refuse rien.
	var texte_banc_q85 := FileAccess.get_file_as_string("res://tools/bench_framerate.gd")
	var debut_ready := texte_banc_q85.find("func _ready() -> void:")
	var corps_ready_q85 := texte_banc_q85.substr(debut_ready, texte_banc_q85.find("\nfunc ", debut_ready + 10) - debut_ready)
	_check("le banc de cadence passe ses arguments par `refus_des_reglages` dans `_ready()`, avec les refus du solo",
		corps_ready_q85.contains("refus_solo.append_array(refus_des_reglages(args))"))
	# 2. Les lumières que Q85 filtre : la torche et le halo d'un corps, le halo d'un plafonnier — rien d'autre.
	var j1: Node = main.p1
	var scene := Node2D.new()
	scene.name = "EssaiReglagesOmbres"
	root.add_child(scene)
	# Un VRAI plafonnier (son `_ready` le range dans son groupe et crée son halo), pas un nœud qui en imiterait les appuis.
	var plafonnier: Node2D = (load("res://plafonnier.gd") as GDScript).new()
	scene.add_child(plafonnier)
	var halo_plafonnier: Variant = plafonnier.get("halo")
	var lumieres: Array = Reglages.lumieres_de_q85(self, [j1])
	var halos_des_plafonniers: Array = get_nodes_in_group("plafonniers").map(func(p) -> Variant: return p.get("halo"))
	var etrangeres: Array = []
	for l in lumieres:
		if l != j1.flashlight and l != j1.ambient_light and not halos_des_plafonniers.has(l):
			etrangeres.append(l)
	_check("Q85 filtre la torche et le halo de chaque corps et le halo de chaque plafonnier — ni le flash, ni l'écho, ni la rétrodiffusion",
		halo_plafonnier is PointLight2D and lumieres.has(j1.flashlight) and lumieres.has(j1.ambient_light) and lumieres.has(halo_plafonnier)
		and etrangeres.is_empty() and not lumieres.has(j1.body_light) and not lumieres.has(j1.muzzle_flash),
		"%d lumières, %d étrangère(s)" % [lumieres.size(), etrangeres.size()])
	# 3. Le PCF5 posé par la classe des interrupteurs, puis vérifié, puis rendu ; `enabled` et `shadow_enabled` intacts.
	var Inter: GDScript = Banc.get_script_constant_map()["Interrupteurs"]
	var torche: PointLight2D = j1.flashlight
	var avant := [torche.enabled, torche.shadow_enabled, torche.shadow_filter, torche.shadow_filter_smooth]
	var filtre = Inter.new()
	filtre.pcf5 = true
	filtre.atlas_ombres = 4096
	_check("les réglages d'ombre rendent les interrupteurs actifs et se lisent dans le libellé de la charge",
		filtre.actif() and "atlas d'ombres 4096" in filtre.noms_des_retraits() and "PCF5, lissage 1.0" in filtre.noms_des_retraits(),
		str(filtre.noms_des_retraits()))
	filtre.armer(self, [], j1, null, scene)
	_check("--pcf5 pose le PCF5 au lissage léger sur la torche, sans toucher à `enabled` ni à `shadow_enabled`",
		torche.shadow_filter == PointLight2D.SHADOW_FILTER_PCF5 and is_equal_approx(torche.shadow_filter_smooth, 1.0)
		and torche.enabled == avant[0] and torche.shadow_enabled == avant[1]
		and (halo_plafonnier as PointLight2D).shadow_filter == PointLight2D.SHADOW_FILTER_PCF5,
		"filtre %d, lissage %.2f" % [torche.shadow_filter, torche.shadow_filter_smooth])
	torche.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	var bilan: Dictionary = filtre.finir()
	_check("la vérification de la fin voit une lumière qui a perdu son PCF5, et la rend comme un défaut",
		int(bilan["pcf5_tenues"]) == int(bilan["pcf5_vivantes"]) - 1 and not (filtre.defauts(bilan) as Array).is_empty(), str(bilan))
	Reglages.poser_le_filtre(lumieres, false)
	_check("rendu au jeu : aucun filtre, lissage nul (ce que `player.gd` et `plafonnier.gd` posent)",
		torche.shadow_filter == avant[2] and is_equal_approx(torche.shadow_filter_smooth, avant[3])
		and j1.ambient_light.shadow_filter == PointLight2D.SHADOW_FILTER_NONE)
	Reglages.poser_l_atlas(Reglages.atlas_du_projet())
	_check("l'atlas du projet est celui que le jeu rend (2048) et Q85 propose 4096",
		Reglages.atlas_du_projet() == 2048 and Reglages.ATLAS_PROPOSE == 4096, str(Reglages.atlas_du_projet()))
	scene.free()
	# 4. Q83 — l'ancre des variantes de la pâte D : une fois et une seule dans le fichier, et la garde sait dire quand elle manque.
	var Ombres: GDScript = load("res://tools/planche_ombres.gd")
	var code_pate := FileAccess.get_file_as_string("res://iso_pate.gdshaderinc")
	var ancre: String = Ombres.ANCRE_LAVIS
	_check("l'ancre des variantes de Q83 (les paliers e2 et e3 de la pâte D) est dans iso_pate.gdshaderinc, une fois",
		Ombres.faute_de_l_ancre_du_lavis(code_pate) == "", Ombres.faute_de_l_ancre_du_lavis(code_pate))
	_check("… et la garde sait dire quand elle manque, ou quand elle y est deux fois",
		Ombres.faute_de_l_ancre_du_lavis(code_pate.replace(ancre, "")) != "" and Ombres.faute_de_l_ancre_du_lavis(code_pate + ancre) != "")
	var variantes: Dictionary = Ombres.VARIANTES_LAVIS
	var fautes: Array[String] = []
	for v in ["a", "b", "c"]:
		var t := String(variantes.get(v, ""))
		if t == "" or t == ancre or not t.contains("\tfloat q = 0.3 * smoothstep(e_1 - a, e_1 + a, l)\n") or not t.contains("float e_3 = "):
			fautes.append(v)
	_check("les trois variantes remplacent les paliers e2 et e3 et gardent e1 tel quel (« dans tous les cas e1 et son pochoir restent »)",
		fautes.is_empty() and variantes.size() == 3, ", ".join(fautes))


## Les plans du banc des ombres qui nomment une salle absente, un PNJ que leur salle n'a pas ou une classe inconnue. Séparée de
## son appel pour être vérifiable, comme `_collisions_de_cles`.
static func _fautes_du_catalogue_des_ombres(plans: Array) -> Array[String]:
	var fautes: Array[String] = []
	var ids := {}
	for plan in plans:
		var id := String(plan.get("id", ""))
		if ids.has(id):
			fautes.append("identifiant en double : %s" % id)
		ids[id] = true
		var salle: Array = plan.get("salle", [])
		if salle.size() != 2:
			fautes.append("%s : salle illisible" % id)
			continue
		var chemin := "res://assets/solo/chapitre_%02d/niveau_%02d.json" % [int(salle[0]), int(salle[1]) + 1]
		if not FileAccess.file_exists(chemin):
			fautes.append("%s : pas de salle %d.%d (%s)" % [id, int(salle[0]), int(salle[1]) + 1, chemin])
			continue
		var niveau = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		var pnj: Array = (niveau as Dictionary).get("pnj", []) if niveau is Dictionary else []
		for cle in ["cible", "ebloui_par"]:
			if plan.has(cle) and int(plan[cle]) >= pnj.size():
				fautes.append("%s : la salle %d.%d n'a pas de PNJ n° %d (%d en tout)" % [id, int(salle[0]),
					int(salle[1]) + 1, int(plan[cle]), pnj.size()])
		if plan.has("classe") and not FileAccess.file_exists("res://assets/sprites/%s_silhouette.png" % String(plan["classe"])):
			fautes.append("%s : pas de silhouette pour la classe « %s »" % [id, String(plan["classe"])])
	return fautes


## Les illustrations qui se ramènent à une même clé canonique, nommées par paires.
##
## Séparée de son appel pour être vérifiable : une garde qui ne peut pas être
## mise en défaut sur commande ne dit pas si elle marche.
static func _collisions_de_cles(chemins: Array) -> Array[String]:
	var par_cle := {}
	var collisions: Array[String] = []
	for chemin in chemins:
		var cle: String = MenuArtwork.cle_canonique(String(chemin))
		if par_cle.has(cle):
			collisions.append("%s et %s se ramènent tous deux à « %s »" % [
				String(par_cle[cle]).get_file(), String(chemin).get_file(), cle])
		else:
			par_cle[cle] = chemin
	return collisions
