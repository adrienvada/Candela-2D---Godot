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
## BF1 (2026-09-07) — les deux autres cotes de l'écran, relevées de la même
## façon : `main.tscn` pour la hauteur des vues, `project.godot` pour l'aire 2D
## de la fenêtre en `keep`, que la racine adopte depuis le chantier R. **Toutes
## trois écrites ici et jamais lues sur le code** — un banc qui lit la constante
## qu'il surveille passe au vert le jour où on supprime ce qu'il protège.
const HAUTEUR_VUE := 1080.0
const VUE_RACINE := 1920.0

## L'élévation de la plaque au-dessus du cadavre, montée comprise, telle que
## `die()` la calcule pour le corps de fonte du jeu : 30 px de garde + 100 px de
## montée + la moitié des 82 px du mot. Écrite en clair : le banc dicte la
## valeur, il ne la demande pas.
const ELEVATION_ORACLE := 171.0

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
	# ⚠️ **Un script qui ne compile PAS n'est pas `null`.** Relevé le 2026-09-07
	# en travaillant sur BF2 : une erreur d'inférence dans `player.gd` a rendu un
	# `GDScript` bien vivant mais vide, le garde `== null` n'a rien vu, et l'appel
	# suivant a levé « Nonexistent function » — **au milieu de `_run()`, donc
	# avant `quit()`**. Le banc a tourné en boucle sans jamais sortir. C'est le
	# piège que ce fichier décrit vingt lignes plus haut, resté ouvert parce que
	# le garde ne testait qu'une des deux façons d'échouer. `can_instantiate()`
	# est faux dès que la compilation a échoué, et c'est celle-là qui manquait.
	if joueur == null or not joueur.can_instantiate():
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

	# ==================================================================
	# BF1 (2026-09-07) — LE CADRAGE : la plaque tient-elle dans la vue de
	# celui qui REGARDE, et non dans celle de celui qui meurt ?
	#
	# DA4.4 avait réglé la largeur du bandeau ; sa position n'a jamais été mise
	# en cause. Le code posait le mot à l'aplomb du cadavre et supposait qu'on
	# meurt là où l'on regarde — vrai du mourant, faux de celui qui tue à 900 px.
	# ==================================================================

	# La vue la plus étroite du jeu, centrée sur l'origine. C'est le décor de
	# tous les contrôles qui suivent, sauf mention contraire.
	var scindee := Rect2(-VUE_SCINDEE * 0.5, -HAUTEUR_VUE * 0.5,
		VUE_SCINDEE, HAUTEUR_VUE)

	print("\n[La plaque FINALE tient dans la vue, d'où que vienne le cadavre]")
	# ⚠️ **La plaque finale, pas celle de la naissance.** Le bandeau enfle et
	# monte de 100 px en 1,5 s : un cadrage juste au départ sort du cadre une
	# seconde plus tard, et c'est précisément le piège que ce bloc surveille.
	var directions := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1),
		Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1),
		Vector2(-1, -1)]
	for texte: String in libelles:
		var g: Dictionary = joueur.geometrie_du_bandeau(texte, fonte, corps)
		var finale: Vector2 = g["plaque"] * float(g["enfle"])
		var tout_dedans := true
		var pire := ""
		for d: Vector2 in directions:
			var mort: Vector2 = d.normalized() * 2000.0
			var c: Dictionary = joueur.cadrage_du_bandeau(mort, scindee,
				finale, ELEVATION_ORACLE)
			var plaque_rect := Rect2(c["centre"] - finale * 0.5, finale)
			if not scindee.encloses(plaque_rect):
				tout_dedans = false
				pire = "cadavre en %s → plaque %s hors de %s" \
					% [str(d), str(plaque_rect), str(scindee)]
		_check("« %s » : la plaque finale reste dans la vue scindée" % texte,
			tout_dedans, pire)

	print("\n[Dans la vue du MORT, le cadrage ne déplace rien]")
	# La caméra du mourant est sur lui : l'ancre est déjà au milieu de sa vue.
	# C'est la garantie de non-régression du chantier — ce qu'Adrien a validé de
	# ce côté-là doit rester au pixel près.
	for texte: String in libelles:
		var g: Dictionary = joueur.geometrie_du_bandeau(texte, fonte, corps)
		var finale: Vector2 = g["plaque"] * float(g["enfle"])
		var c: Dictionary = joueur.cadrage_du_bandeau(Vector2.ZERO, scindee,
			finale, ELEVATION_ORACLE)
		var attendu := Vector2(0.0, -ELEVATION_ORACLE)
		_check("« %s » : le mort voit son bandeau à sa place d'avant" % texte,
			c["centre"].is_equal_approx(attendu) and c["bord"] == Vector2i.ZERO
				and not c["hors_champ"],
			"centre %s au lieu de %s, bord %s"
				% [str(c["centre"]), str(attendu), str(c["bord"])])

	print("\n[Le cadavre hors champ : la boîte s'accroche, la flèche pointe]")
	var geo_court: Dictionary = joueur.geometrie_du_bandeau("FATAL", fonte, corps)
	var finale_court: Vector2 = geo_court["plaque"] * float(geo_court["enfle"])
	var loin := Vector2(2000.0, 0.0)
	var cd: Dictionary = joueur.cadrage_du_bandeau(loin, scindee, finale_court,
		ELEVATION_ORACLE)
	_check("un cadavre à 2000 px est déclaré hors champ", bool(cd["hors_champ"]))
	_check("la boîte s'accroche au bord DROIT", cd["bord"].x == 1,
		"bord %s" % str(cd["bord"]))
	_check("la flèche est unitaire",
		is_equal_approx(cd["direction"].length(), 1.0),
		"%.4f" % cd["direction"].length())
	_check("et elle pointe le cadavre depuis la boîte",
		cd["direction"].dot((loin - cd["centre"]).normalized()) > 0.999,
		"produit scalaire %.4f"
			% cd["direction"].dot((loin - cd["centre"]).normalized()))
	# L'inverse, et il compte autant : un cadavre visible ne mérite pas qu'on le
	# désigne du doigt. Pointer ce qu'on voit déjà, c'est du bruit.
	var proche: Dictionary = joueur.cadrage_du_bandeau(Vector2(300.0, 200.0),
		scindee, finale_court, ELEVATION_ORACLE)
	_check("un cadavre visible n'a AUCUNE flèche",
		not proche["hors_champ"] and proche["direction"] == Vector2.ZERO)

	print("\n[Le cadrage lit la vue qu'on lui donne, pas une constante]")
	# ⚠️ **Les deux modes n'ont pas la même vue** : 957 px par vue en écran
	# scindé, 1920 px d'aire 2D quand le chantier R rend le duel dans la racine.
	# Un cadavre à 700 px du regard tient dans la seconde et pas dans la
	# première ; si les deux appels répondaient pareil, le cadrage aurait une
	# largeur en dur quelque part.
	var racine := Rect2(-VUE_RACINE * 0.5, -HAUTEUR_VUE * 0.5,
		VUE_RACINE, HAUTEUR_VUE)
	var a_700 := Vector2(700.0, 0.0)
	var en_racine: Dictionary = joueur.cadrage_du_bandeau(a_700, racine,
		finale_court, ELEVATION_ORACLE)
	var en_scinde: Dictionary = joueur.cadrage_du_bandeau(a_700, scindee,
		finale_court, ELEVATION_ORACLE)
	_check("en vue unique (1920), un cadavre à 700 px ne fait rien bouger",
		en_racine["bord"].x == 0 and is_equal_approx(en_racine["centre"].x, 700.0),
		"bord %s, centre %s" % [str(en_racine["bord"]), str(en_racine["centre"])])
	_check("en écran scindé (957), le MÊME cadavre accroche le bord",
		en_scinde["bord"].x == 1 and en_scinde["centre"].x < 700.0,
		"bord %s, centre %s" % [str(en_scinde["bord"]), str(en_scinde["centre"])])

	print("\n[Le cadrage vise l'ARRIVÉE : il tient quelle que soit l'élévation]")
	# Le bandeau monte pendant sa vie. Si le cadrage ne comptait que le départ,
	# une élévation plus grande le ferait sortir par le haut — et une seconde
	# plus tard, quand plus personne ne regarde le banc.
	for elev: float in [ELEVATION_ORACLE, 271.0, 520.0]:
		var c: Dictionary = joueur.cadrage_du_bandeau(Vector2(0.0, 400.0),
			scindee, finale_court, elev)
		var r := Rect2(c["centre"] - finale_court * 0.5, finale_court)
		_check("à %.0f px d'élévation, la plaque tient encore" % elev,
			scindee.encloses(r), str(r))
	# Et la constante que `die()` emploie doit bien être celle du tween : 100 px,
	# écrits ici à la main. Les deux ne peuvent plus diverger sans rougir.
	_check("la montée du bandeau vaut les 100 px de son tween",
		is_equal_approx(float(joueur.MONTEE_BANDEAU), 100.0),
		"%.1f" % float(joueur.MONTEE_BANDEAU))

	print("\n[Les deux dégénérescences, qu'aucun essai à la main ne rencontre]")
	# Une vue de taille nulle vaut « je ne sais pas cadrer » : c'est le filet de
	# `die()` quand les caméras ne sont pas encore debout, pas un cas d'erreur.
	var vide: Dictionary = joueur.cadrage_du_bandeau(Vector2(500.0, 500.0),
		Rect2(), finale_court, ELEVATION_ORACLE)
	_check("une vue de taille nulle rend l'ancre telle quelle",
		vide["centre"].is_equal_approx(Vector2(500.0, 500.0 - ELEVATION_ORACLE))
			and not vide["hors_champ"], str(vide["centre"]))
	# Une vue plus étroite que la plaque renverserait les bornes du `clampf` :
	# on recentre, la plaque déborde des deux côtés à parts égales.
	var etroite := Rect2(-100.0, -HAUTEUR_VUE * 0.5, 200.0, HAUTEUR_VUE)
	var serre: Dictionary = joueur.cadrage_du_bandeau(Vector2(900.0, 0.0),
		etroite, finale_court, ELEVATION_ORACLE)
	_check("une vue plus étroite que la plaque la recentre",
		is_equal_approx(serre["centre"].x, 0.0)
			and is_finite(serre["centre"].x) and is_finite(serre["centre"].y),
		str(serre["centre"]))

	if _ko == 0:
		print("\n✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("\n✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
