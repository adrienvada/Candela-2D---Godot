extends SceneTree

## **Le bandeau FATAL tient-il dans l'écran ?**
##
## Relevé par Adrien le 2026-08-26 en écran scindé : `FATAL — ARBALÈTE` sortait
## du cadre à droite. Quatre littéraux — offset, pivot, plaque, agrandissement —
## avaient été calibrés pour le mot « FATAL » seul, 130 px de large, et devenaient
## faux dès qu'une arme signait le kill.
##
## ⚠️ **Ce banc n'existait pas et ne POUVAIT pas exister** : le calcul vivait
## dispersé dans `die()`, donc il fallait tuer un joueur pour l'exécuter.
## `Player.geometrie_du_bandeau()` lui donne un nom, et c'est cette extraction —
## autant que les rapports qu'elle contient — qui est la correction.
##
## ⚠️ **L'oracle est écrit ici, pas demandé au code.** La largeur d'une vue en
## écran scindé (957 px) est relevée sur `main.tscn`, pas sur la constante que le
## code utilise : sinon élargir la constante ferait passer le banc au vert en
## supprimant précisément ce qu'il protège. Leçon payée deux fois aujourd'hui.

const VUE_SCINDEE := 957.0

var _ok := 0
var _ko := 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_ok += 1
		print("  ✓ %s" % label)
	else:
		_ko += 1
		printerr("  ✗ %s%s" % [label, "  → " + detail if detail != "" else ""])


## ⚠️ **`Player` n'est jamais NOMMÉ ici, et c'est ce qui rend ce banc possible.**
##
## Premier jet : `Player.geometrie_du_bandeau(...)`. Résultat —
## `Compile Error: Identifier not found: NetworkManager`, levé dans `player.gd`.
##
## Nommer `Player` dans un banc lancé par `--script` en fait une **dépendance de
## compilation** : Godot compile `player.gd` pendant qu'il compile le banc, donc
## **avant que le moindre autoload soit enregistré** — et `player.gd` nomme
## `NetworkManager`. Différer `_init()` ne change rien : la faute est commise à
## la compilation, pas à l'exécution. C'est ce qui distingue ce piège de celui,
## déjà consigné, de `test_audit_menus.gd` — là c'était l'ordre d'exécution, ici
## c'est l'ordre de compilation, et le second se répare autrement.
##
## Le script est donc chargé **par son chemin, à l'exécution**, une fois l'arbre
## debout. Aucun identifiant de classe, aucune dépendance de compilation.
##
## ⚠️ Et il échouait de la pire façon : `_init()` levait avant d'atteindre
## `quit()`, donc **le processus Godot ne se terminait jamais**. Deux instances
## ont tourné en boucle sans rien dire. **Un banc qui ne sort pas est pire qu'un
## banc rouge** — un rouge se voit, un silence se confond avec « ça travaille ».
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LE BANDEAU FATAL TIENT DANS L'ÉCRAN ===")
	await process_frame
	# Par chemin, jamais par nom de classe — voir la note ci-dessus.
	var joueur: GDScript = load("res://player.gd")
	if joueur == null:
		printerr("✗ player.gd introuvable ou ne compile pas")
		quit(1)
		return
	var fonte := Charte.police_display(Charte.POIDS_ENSEIGNE)
	if fonte == null:
		printerr("✗ fonte d'affichage absente")
		quit(1)
		return
	var corps := Charte.T_ENSEIGNE

	# Tous les libellés que le jeu peut écrire : le mot seul, et le mot signé par
	# chacune des quatre armes. Écrits en clair — un banc qui les lirait depuis
	# `weapon_data` ne dirait plus rien le jour où le catalogue se vide.
	var libelles := ["FATAL", "FATAL — PISTOLET", "FATAL — FUSIL",
		"FATAL — POMPE", "FATAL — ARBALÈTE"]

	print("\n[Le mot et son cartouche restent dans la vue la plus étroite]")
	for texte: String in libelles:
		var g: Dictionary = joueur.geometrie_du_bandeau(texte, fonte, corps)
		var plaque: Vector2 = g["plaque"]
		var enfle: float = g["enfle"]
		# Centré sur le joueur : l'étendue se répartit de part et d'autre.
		var demi := plaque.x * enfle * 0.5
		_check("« %s » tient dans une vue scindée" % texte,
			demi <= VUE_SCINDEE * 0.5,
			"%.0f px de chaque côté pour %.0f disponibles"
				% [demi, VUE_SCINDEE * 0.5])

	print("\n[Le cartouche déborde du mot, comme son commentaire le promet]")
	for texte: String in libelles:
		var g: Dictionary = joueur.geometrie_du_bandeau(texte, fonte, corps)
		var mot: Vector2 = g["mot"]
		var plaque: Vector2 = g["plaque"]
		# Le défaut d'origine : une plaque de 300 px pour un mot de 438.
		_check("« %s » : la plaque est plus large que son mot" % texte,
			plaque.x > mot.x, "plaque %.0f, mot %.0f" % [plaque.x, mot.x])

	print("\n[La marge est constante, la plaque non]")
	# C'est la propriété qui distingue un cartouche d'un surlignage : la bordure
	# a la même épaisseur partout, quel que soit ce qu'elle entoure.
	var court: Dictionary = joueur.geometrie_du_bandeau("FATAL", fonte, corps)
	var long: Dictionary = joueur.geometrie_du_bandeau("FATAL — ARBALÈTE", fonte, corps)
	_check("la marge ne dépend pas de la longueur du texte",
		court["marge"] == long["marge"],
		"%s puis %s" % [str(court["marge"]), str(long["marge"])])
	_check("la plaque, elle, suit le texte",
		long["plaque"].x > court["plaque"].x,
		"%.0f puis %.0f" % [court["plaque"].x, long["plaque"].x])

	print("\n[Le mot seul rend EXACTEMENT ce qui a été validé le 2026-08-25]")
	# La correction ne doit rien changer à l'écran qu'Adrien a vu et accepté :
	# elle fait tenir les autres cas, elle ne redessine pas celui-ci.
	_check("« FATAL » garde son cartouche d'environ 300 × 150",
		absf(court["plaque"].x - 300.0) < 25.0
			and absf(court["plaque"].y - 150.0) < 25.0,
		"%.0f × %.0f" % [court["plaque"].x, court["plaque"].y])
	_check("« FATAL » garde son agrandissement de 1,5",
		is_equal_approx(float(court["enfle"]), 1.5),
		"%.3f" % float(court["enfle"]))

	print("\n[Un texte absurde rétrécit au lieu de sortir du cadre]")
	# Le garde-fou qui manquait : ce n'est pas le nom d'une arme d'aujourd'hui,
	# c'est celui de l'arme que quelqu'un ajoutera.
	var enorme: Dictionary = joueur.geometrie_du_bandeau(
		"FATAL — LANCE-GRENADES MULTIPLE DE SIÈGE", fonte, corps)
	_check("un libellé très long est borné",
		float(enorme["enfle"]) < 1.5, "%.3f" % float(enorme["enfle"]))
	_check("et il tient quand même dans la vue",
		enorme["plaque"].x * float(enorme["enfle"]) * 0.5 <= VUE_SCINDEE * 0.5,
		"%.0f px de chaque côté"
			% (enorme["plaque"].x * float(enorme["enfle"]) * 0.5))

	if _ko == 0:
		print("\n✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("\n✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
