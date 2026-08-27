## Le relevé balistique de la killcam tient-il à tous les zooms, et à tous les
## angles de tir ?
##
## **Ce banc mesure ce qu'aucun œil ne peut vérifier en regardant une killcam.**
## Le tir fatal arrive une fois, penché d'un angle quelconque, sous une caméra
## qui interpole son zoom entre 0,7× et 2,8× pendant le ralenti. Constater à
## l'écran qu'une cote se retourne demanderait de rejouer la bonne mort au bon
## instant ; ici c'est une boucle sur trente-six angles.
##
## ## Les quatre propriétés, et pourquoi chacune est un RAPPORT
##
## 1. **L'annotation se compense du zoom.** L'écart entre le trait et la ligne de
##    cote, mesuré **en pixels d'écran**, doit être le même à 0,7× et à 2,8×.
##    C'est la propriété qui distingue une annotation d'un décor : une cote posée
##    en pixels locaux ferait 8 px au dézoom et 73 au zoom serré, sur le même tir.
##    Sixième occurrence du motif du 2026-08-19 — *une valeur absolue là où il
##    fallait un rapport*.
##
## 2. **La géométrie, elle, ne s'en compense PAS.** L'écart des chevrons reste en
##    pixels monde, et le contrôle l'exige explicitement. Ce n'est pas une
##    exception à la règle 1, c'est son revers : leur densité à l'écran devient
##    proportionnelle à la distance réellement parcourue, ce qu'un relevé doit
##    dire. Sans ce contrôle, « tout compenser » passerait pour une correction.
##
## 3. **La cote reste du côté HAUT de l'écran, à tous les angles.** En repère
##    local, « au-dessus du trait » veut dire deux choses opposées selon qu'on
##    tire vers la droite ou vers la gauche : la cote basculerait sous le trait au
##    milieu d'une killcam, et le texte se lirait à l'envers. Le contrôle balaie
##    le tour complet.
##
## 4. **Les chevrons pointent vers la balle.** Un segment n'a pas d'orientation ;
##    deux joueurs face à face laissent le même trait. Les ailes doivent être en
##    arrière de la pointe — sinon le relevé dit le contraire de ce qui s'est
##    passé, ce qui est pire que de ne rien dire.
##
## 5. **Un seul tir est relevé, et il se dessine AVANT l'action** (DA4.6, second
##    lot). Le pré-tracé est le geste demandé par Adrien : on retrace la
##    trajectoire, puis on rejoue et l'on voit la balle la suivre. Le banc tient
##    l'ordre — la ligne pousse de l'origine vers l'impact et non l'inverse —, et
##    la durée en temps RÉEL, qui ne doit pas dépendre du ralenti.
##
## ⚠️ **Le sujet est chargé par son CHEMIN, jamais nommé.** Nommer une classe dans
## un banc lancé par `--script` en fait une dépendance de **compilation** : Godot
## la compilerait avant qu'aucun autoload existe. Piège payé le 2026-08-26 par
## `tools/test_bandeau_fatal.gd`, dont la note de tête porte le détail.

extends SceneTree

var _ok := 0
var _ko := 0

## Les deux bornes du zoom de killcam, lues dans `game_state.gd` : 0,7 au
## dézoom de lecture, 2,8 au serré du ralenti.
const ZOOMS := [0.7, 1.0, 1.3, 2.0, 2.8]


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


func _proche(a: float, b: float, quoi: String, tol: float = 0.01) -> void:
	_check(absf(a - b) <= tol, "%s : %.4f attendu %.4f" % [quoi, a, b])


# ---------------------------------------------------------------------------
# 1. L'ANNOTATION SE COMPENSE DU ZOOM
# ---------------------------------------------------------------------------

func _test_l_annotation_tient_sa_taille_ecran(releve: GDScript) -> void:
	var ecarts: Array[float] = []
	var epaisseurs: Array[float] = []
	for z: float in ZOOMS:
		var g: Dictionary = releve.geometrie_du_releve(400.0, z, 0.0)
		var trace: Array = g["trace"]
		var cote: Array = g["cote"]
		# L'écart local, ramené en pixels d'écran : c'est lui qui doit être
		# constant, pas l'écart local.
		var ecart_local: float = absf(cote[0].y - trace[0].y)
		ecarts.append(ecart_local * z)
		epaisseurs.append(float(g["epaisseur"]) * z)

	for i in range(1, ecarts.size()):
		_proche(ecarts[i], ecarts[0],
			"l'écart de la cote à %.1f× ne fait pas la même taille d'écran qu'à %.1f×"
				% [ZOOMS[i], ZOOMS[0]], 0.05)

	_proche(ecarts[0], releve.COTE_ECART,
		"l'écart d'écran ne vaut pas COTE_ECART", 0.05)

	# L'épaisseur suit la même règle — sauf sous son plancher d'un pixel, qui
	# existe pour qu'un trait ne disparaisse jamais complètement.
	for i in range(1, epaisseurs.size()):
		var plancher: bool = epaisseurs[i] <= 1.001 * ZOOMS[i] \
			or epaisseurs[0] <= 1.001 * ZOOMS[0]
		if plancher:
			continue
		_proche(epaisseurs[i], epaisseurs[0],
			"l'épaisseur à %.1f× ne fait pas la même taille d'écran" % ZOOMS[i],
			0.05)

	# Et le texte : le facteur d'échelle doit être exactement l'inverse du zoom,
	# sinon la contre-échelle de `draw_set_transform` ne s'annule pas avec la
	# caméra et la cote se rend floue ou en escalier.
	for z: float in ZOOMS:
		var g: Dictionary = releve.geometrie_du_releve(400.0, z, 0.0)
		_proche(float(g["echelle_texte"]) * z, 1.0,
			"l'échelle du texte à %.1f× ne s'annule pas avec la caméra" % z)


# ---------------------------------------------------------------------------
# 2. LA GÉOMÉTRIE NE S'EN COMPENSE PAS
# ---------------------------------------------------------------------------

func _test_les_chevrons_sont_en_pixels_monde(releve: GDScript) -> void:
	var reference: Array = []
	for z: float in ZOOMS:
		var g: Dictionary = releve.geometrie_du_releve(400.0, z, 0.0)
		var ch: Array = g["chevrons"]
		if reference.is_empty():
			reference = ch
			continue
		_check(ch.size() == reference.size(),
			"le nombre de chevrons change avec le zoom (%d à %.1f× contre %d)"
				% [ch.size(), z, reference.size()])
		if ch.size() != reference.size():
			continue
		for i in ch.size():
			_proche((ch[i] as Vector2).x, (reference[i] as Vector2).x,
				"le chevron %d s'est déplacé avec le zoom" % i)

	# Le pas est bien celui annoncé, et la densité dit la distance.
	var court: Dictionary = releve.geometrie_du_releve(100.0, 1.0, 0.0)
	var long: Dictionary = releve.geometrie_du_releve(400.0, 1.0, 0.0)
	_check((long["chevrons"] as Array).size()
			> (court["chevrons"] as Array).size(),
		"un tir long ne porte pas plus de chevrons qu'un tir court")

	var ch2: Array = long["chevrons"]
	if ch2.size() >= 2:
		_proche((ch2[1] as Vector2).x - (ch2[0] as Vector2).x,
			releve.CHEVRON_PAS, "le pas des chevrons n'est pas CHEVRON_PAS")

	# Le garde-fou : une portée aberrante ne fait pas boucler `_draw`.
	var enorme: Dictionary = releve.geometrie_du_releve(1000000.0, 1.0, 0.0)
	_check((enorme["chevrons"] as Array).size() <= releve.CHEVRON_MAX,
		"le plafond de chevrons ne tient pas : %d posés"
			% (enorme["chevrons"] as Array).size())


# ---------------------------------------------------------------------------
# 3. LA COTE RESTE EN HAUT DE L'ÉCRAN, À TOUS LES ANGLES
# ---------------------------------------------------------------------------

func _test_la_cote_ne_se_retourne_jamais(releve: GDScript) -> void:
	var fautifs: Array[String] = []
	var degeneres := 0
	for pas in 36:
		var angle := TAU * float(pas) / 36.0
		var g: Dictionary = releve.geometrie_du_releve(400.0, 1.0, angle)
		var cote: Array = g["cote"]
		var trace: Array = g["trace"]
		# Le décalage local, vu du monde : sa composante Y doit être négative
		# (l'écran a son Y vers le bas), donc la cote est au-dessus du trait.
		var decalage: Vector2 = (cote[0] - trace[0]).rotated(angle)
		if absf(decalage.y) < 0.001:
			# Tir vertical : la cote est de côté, ni haut ni bas. Le cas existe,
			# il n'est pas fautif — mais il doit rester RARE, sinon la formule
			# a basculé en dégénérée partout.
			degeneres += 1
			continue
		if decalage.y > 0.0:
			fautifs.append("%d°" % int(rad_to_deg(angle)))

	_check(fautifs.is_empty(),
		"la cote passe SOUS le trait à ces angles : %s" % ", ".join(fautifs))
	_check(degeneres <= 2,
		"%d angles rendent une cote sans côté : la formule est dégénérée"
			% degeneres)

	# Et l'ancre du texte doit être du MÊME côté que la ligne de cote — une
	# valeur posée de l'autre côté du trait désignerait un objet qui n'existe pas.
	for pas in 12:
		var angle := TAU * float(pas) / 12.0
		var g: Dictionary = releve.geometrie_du_releve(400.0, 1.0, angle)
		var cote: Array = g["cote"]
		var milieu: Vector2 = (cote[0] + cote[1]) * 0.5
		var ancre: Vector2 = g["ancre_texte"]
		_check(signf(ancre.y) == signf(milieu.y) or absf(milieu.y) < 0.001,
			"à %d° l'ancre du texte (%.1f) et la cote (%.1f) sont de deux côtés"
				% [int(rad_to_deg(angle)), ancre.y, milieu.y])


# ---------------------------------------------------------------------------
# 4. LES CHEVRONS POINTENT VERS LA BALLE
# ---------------------------------------------------------------------------

func _test_les_chevrons_disent_le_sens(releve: GDScript) -> void:
	var g: Dictionary = releve.geometrie_du_releve(400.0, 1.0, 0.0)
	var l: float = g["chevron_l"]
	var h: float = g["chevron_h"]
	_check(l > 0.0 and h > 0.0, "un chevron sans dimensions ne se voit pas")

	# La balle est en (0,0) et le départ en -X : les ailes doivent donc être en
	# ARRIÈRE de la pointe, c'est-à-dire à un x plus petit.
	_check(l > 0.0,
		"les ailes du chevron ne sont pas en arrière de sa pointe")

	# Tous les chevrons sont sur le trait, entre le départ et la balle.
	var chevrons: Array = g["chevrons"]
	_check(not chevrons.is_empty(), "aucun chevron sur un tir de 400 px")
	for p: Vector2 in chevrons:
		_check(p.x >= -400.0 and p.x <= 0.0,
			"un chevron est hors du segment parcouru (x = %.1f)" % p.x)
		_proche(p.y, 0.0, "un chevron n'est pas sur le trait")


# ---------------------------------------------------------------------------
# 5. LE SEUIL DE COTE
# ---------------------------------------------------------------------------

func _test_pas_de_cote_sur_un_moignon(releve: GDScript) -> void:
	var court: Dictionary = releve.geometrie_du_releve(
		releve.COTE_MINIMUM - 1.0, 1.0, 0.0)
	_check(not court["cote_visible"],
		"une cote est posée sous le seuil, là où ses obliques ne tiennent pas")

	var long: Dictionary = releve.geometrie_du_releve(
		releve.COTE_MINIMUM + 1.0, 1.0, 0.0)
	_check(long["cote_visible"], "aucune cote au-dessus du seuil")

	# ⚠️ Le seuil est en pixels MONDE et doit le rester : il dit « ce tir est
	# trop court pour être coté », une propriété du tir et non du cadrage. S'il
	# suivait le zoom, la même mort montrerait sa cote ou pas selon l'instant.
	for z: float in ZOOMS:
		var g: Dictionary = releve.geometrie_du_releve(
			releve.COTE_MINIMUM + 1.0, z, 0.0)
		_check(g["cote_visible"],
			"la visibilité de la cote dépend du zoom (%.1f×)" % z)


# ---------------------------------------------------------------------------
# 6. UN SEUL TIR, ET LE TRACÉ PRÉCÈDE L'ACTION
# ---------------------------------------------------------------------------

## ⚠️ **Une killcam rejoue TOUT ce qui a été tiré dans sa fenêtre.** Coter chaque
## balle empilerait des cotes sur des tirs manqués, et *ce qui annote partout
## n'annote plus rien*. Relevé par Adrien avant même d'avoir vu l'écran.
##
## ⚠️ **Et le relevé ne peut PAS vivre dans la balle** — c'est ce que le second
## lot a découvert en essayant. Le tracé doit précéder l'action, or **une balle
## ne sait pas où elle va** : elle connaît son départ et sa direction, jamais son
## impact. Seul le rejeu le sait. Le contrôle interdit donc à `bullet.gd` de
## reprendre la géométrie : deux dessins du même relevé finiraient par diverger.
func _test_le_releve_ne_vit_pas_dans_la_balle() -> void:
	var balle := FileAccess.get_file_as_string("res://bullet.gd")
	_check(not balle.contains("geometrie_du_releve"),
		"bullet.gd redessine le relevé : il ne peut pas le tracer AVANT lui-même")
	_check(balle.contains("draw_dashed_line"),
		"bullet.gd a perdu sa traînée V6.2")

	# ⚠️ **Une seule balle laisse un trait.** Les tirs manqués du rejeu en
	# laissaient chacun un, et l'écran montrait plusieurs lignes presque
	# parallèles dont une seule était la bonne — au point qu'Adrien a cru, à
	# raison de ce qu'il voyait, que « la balle ne suit pas la trajectoire ».
	# Deux traits qui se ressemblent sont pires qu'un seul faux.
	var b: Node2D = load("res://bullet.gd").new()
	_check(not bool(b.get("est_le_tir_fatal")),
		"une balle se croit fatale par défaut : toutes laisseraient un trait")
	b.free()
	var dessin := balle.split("func _draw()")
	_check(dessin.size() == 2
			and dessin[1].split("draw_dashed_line")[0].contains("est_le_tir_fatal"),
		"le tracé de bullet.gd ne se réserve pas au tir fatal")

	var rejeu := FileAccess.get_file_as_string("res://replay_system.gd")
	_check(rejeu.contains("func index_du_tir_fatal"),
		"ReplaySystem ne sait pas désigner le tir fatal par son indice")

	# ⚠️ Il ne doit y avoir qu'UNE façon de désigner le tir fatal : son propre
	# commentaire l'annonçait depuis V6.2 — deux façons finiraient par désigner
	# deux tirs différents.
	var corps := rejeu.split("func trajectoire_fatale()")
	_check(corps.size() == 2 and corps[1].split("func ")[0]
			.contains("index_du_tir_fatal()"),
		"trajectoire_fatale() redésigne le tir fatal au lieu de réutiliser l'indice")


## Le pré-tracé pousse-t-il de l'ORIGINE vers l'impact ?
##
## C'est l'ordre qui porte tout le geste : un tracé qui recule depuis l'impact
## montrerait la fin avant le début, ce qui est exactement l'inverse de ce qu'on
## veut faire comprendre.
func _test_le_pretrace_pousse_vers_l_impact(releve: GDScript) -> void:
	var n: Node2D = releve.new()
	root.add_child(n)
	var depart := Vector2(100.0, 100.0)
	var arrivee := Vector2(500.0, 100.0)
	_check(n.poser(depart, arrivee), "le relevé refuse une trajectoire valide")
	_check(not n.poser(depart, depart + Vector2(0.2, 0.0)),
		"le relevé accepte une trajectoire de longueur nulle")

	n.poser(depart, arrivee)
	_check(is_equal_approx(n.progression, 0.0),
		"le pré-tracé ne commence pas à zéro")

	# La tête du tracé, en coordonnées monde, à trois instants.
	var tetes: Array[float] = []
	for t: float in [0.25, 0.5, 1.0]:
		n.avancer(t)
		tetes.append(depart.x + (arrivee - depart).length() * n.progression)

	for i in range(1, tetes.size()):
		_check(tetes[i] > tetes[i - 1],
			"la tête du tracé recule entre deux instants (%.1f puis %.1f)"
				% [tetes[i - 1], tetes[i]])
	_proche(tetes[-1], arrivee.x, "le tracé complet n'atteint pas l'impact", 0.5)

	# L'action reprise : la ligne reste ENTIÈRE, et s'atténue.
	n.passer_derriere()
	_proche(n.progression, 1.0, "le relevé n'est pas entier une fois derrière")
	_check(n.en_arriere_plan, "le relevé ne passe pas en arrière-plan")
	_check(releve.ATTENUATION > 0.0 and releve.ATTENUATION < 1.0,
		"l'atténuation efface le relevé ou ne l'atténue pas : %.2f"
			% releve.ATTENUATION)
	n.queue_free()


## Le relevé reste-t-il INVISIBLE avant que le pré-tracé commence ?
##
## ⚠️ **Le défaut qui a échappé au premier banc, et pourquoi.** Les contrôles
## ci-dessus éprouvent des GESTES isolés — poser, avancer, passer derrière — et
## chacun était juste. Le défaut vivait dans la SÉQUENCE : `pretrace_en_cours()`
## rendait `false` aussi bien avant qu'après, l'appelant prenait donc la branche
## « c'est fini » dès la première image de la killcam et posait la ligne entière
## trois secondes trop tôt. Relevé par Adrien à l'écran le 2026-08-27.
##
## **Un banc qui vérifie chaque geste ne vérifie pas leur ordre.** Celui-ci
## exige les trois moments, et surtout qu'ils soient TROIS : un état à trois
## valeurs rangé dans un booléen perd celui du milieu ou celui du bord, et rien
## dans le langage ne le signale.
func _test_le_releve_ne_se_montre_pas_avant_l_heure(releve: GDScript) -> void:
	var script: GDScript = load("res://replay_system.gd")
	var r: Node = script.new()

	# L'état de départ, avant toute lecture, doit être AVANT — ni PENDANT ni
	# APRÈS. C'est le contrôle qui aurait attrapé le défaut.
	_check(r.pretrace_etat() == r.Pretrace.AVANT,
		"le pré-tracé se croit terminé avant d'avoir commencé : le relevé "
		+ "s'affichera entier dès la première image de la killcam")

	# Et les trois valeurs doivent être distinctes, sinon l'énumération ne
	# distingue rien de plus qu'un booléen.
	var valeurs := [r.Pretrace.AVANT, r.Pretrace.PENDANT, r.Pretrace.APRES]
	var uniques := {}
	for v: int in valeurs:
		uniques[v] = true
	_check(uniques.size() == 3,
		"les trois moments du pré-tracé ne sont pas distincts")
	r.free()

	# Côté relevé : armé mais pas encore tracé, il ne montre rien. `progression`
	# à zéro est la seule chose qui l'en empêche.
	var n: Node2D = releve.new()
	root.add_child(n)
	n.poser(Vector2(100.0, 100.0), Vector2(500.0, 100.0))
	_check(is_equal_approx(n.progression, 0.0),
		"un relevé fraîchement posé a déjà une progression : il se verrait")
	_check(not n.en_arriere_plan,
		"un relevé fraîchement posé se croit déjà derrière")
	n.queue_free()


## Le pré-tracé dure-t-il en temps RÉEL, indépendamment du ralenti ?
##
## ⚠️ **Le piège est `Engine.time_scale = 0`.** Il gèlerait l'action — et
## gèlerait aussi le `delta` qui fait avancer le compte à rebours, puisque
## celui-ci arrive déjà multiplié par l'échelle. La killcam resterait suspendue
## POUR TOUJOURS, sans erreur et sans rien à l'écran qui l'explique.
func _test_le_pretrace_est_en_temps_reel() -> void:
	var rejeu := FileAccess.get_file_as_string("res://replay_system.gd")
	_check(rejeu.contains("PRETRACE_ECHELLE"),
		"le pré-tracé n'a pas d'échelle de temps dédiée")
	_check(not rejeu.contains("Engine.time_scale = 0.0"),
		"une échelle de temps nulle gèlerait le compte à rebours du pré-tracé")

	var script: GDScript = load("res://replay_system.gd")
	var r: Node = script.new()
	_check(float(r.get("PRETRACE_ECHELLE")) > 0.0,
		"PRETRACE_ECHELLE vaut zéro : la killcam resterait suspendue")
	_check(float(r.get("PRETRACE_POUSSE")) > 0.0
			and float(r.get("PRETRACE_LECTURE")) > 0.0,
		"le pré-tracé n'a pas de durée")
	# Le tracé se lit avant de repartir : la pousse ne doit pas manger tout le
	# temps disponible, sinon l'action reprend à l'instant où la ligne se ferme.
	_check(float(r.get("PRETRACE_LECTURE")) > 0.0,
		"aucun temps de lecture entre la fin du tracé et la reprise")
	r.free()


## L'échelle métrique : le nombre affiché est-il celui qu'on croit ?
func _test_l_echelle_metrique() -> void:
	var e: GDScript = load("res://echelle.gd")
	_check(e != null, "echelle.gd introuvable")
	if e == null:
		return
	# ⚠️ **Dérivée, jamais posée** : l'échelle doit sortir du rayon du joueur et
	# de la largeur d'épaules, sinon personne ne peut plus la corriger.
	_proche(float(e.PX_PAR_METRE),
		(float(e.JOUEUR_RAYON_PX) * 2.0) / float(e.EPAULES_M),
		"PX_PAR_METRE n'est pas dérivée de ses deux termes")
	_proche(float(e.metres(float(e.PX_PAR_METRE))), 1.0,
		"un mètre de pixels ne fait pas un mètre")

	# Le rayon du joueur doit rester celui de `player.gd`, sinon l'échelle ment.
	var joueur := FileAccess.get_file_as_string("res://player.gd")
	_check(joueur.contains("18.0"),
		"player.gd n'emploie plus 18.0 : l'ancre de l'échelle a bougé")

	_check(e.ecrire(30.0).ends_with("CM"),
		"sous le mètre, la distance doit se lire en centimètres : %s"
			% e.ecrire(30.0))
	_check(e.ecrire(300.0).contains(","),
		"entre 1 et 10 m, une décimale et une VIRGULE : %s" % e.ecrire(300.0))
	_check(not e.ecrire(2000.0).contains(","),
		"au-delà de 10 m, aucune décimale : %s" % e.ecrire(2000.0))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Le relevé balistique ===")
	await process_frame
	var releve: GDScript = load("res://releve_balistique.gd")
	if releve == null:
		printerr("✗ releve_balistique.gd introuvable")
		quit(1)
		return

	_test_le_releve_ne_vit_pas_dans_la_balle()
	_test_le_pretrace_pousse_vers_l_impact(releve)
	_test_le_releve_ne_se_montre_pas_avant_l_heure(releve)
	_test_le_pretrace_est_en_temps_reel()
	_test_l_echelle_metrique()
	_test_l_annotation_tient_sa_taille_ecran(releve)
	_test_les_chevrons_sont_en_pixels_monde(releve)
	_test_la_cote_ne_se_retourne_jamais(releve)
	_test_les_chevrons_disent_le_sens(releve)
	_test_pas_de_cote_sur_un_moignon(releve)

	print("--- %d contrôles, %d échec(s) ---" % [_ok + _ko, _ko])
	quit(1 if _ko > 0 else 0)
