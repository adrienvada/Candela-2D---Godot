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

	main.queue_free()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
