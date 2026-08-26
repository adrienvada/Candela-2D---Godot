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
## ⚠️ **`bullet.gd` est chargé par son CHEMIN, jamais nommé.** Nommer `Bullet`
## dans un banc lancé par `--script` en ferait une dépendance de **compilation** :
## Godot le compilerait avant qu'aucun autoload existe, et il nomme
## `WeaponData`. Piège payé le 2026-08-26 par `tools/test_bandeau_fatal.gd`, dont
## la note de tête porte le détail.

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

func _test_l_annotation_tient_sa_taille_ecran(balle: GDScript) -> void:
	var ecarts: Array[float] = []
	var epaisseurs: Array[float] = []
	for z: float in ZOOMS:
		var g: Dictionary = balle.geometrie_du_releve(400.0, z, 0.0)
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

	_proche(ecarts[0], balle.COTE_ECART,
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
		var g: Dictionary = balle.geometrie_du_releve(400.0, z, 0.0)
		_proche(float(g["echelle_texte"]) * z, 1.0,
			"l'échelle du texte à %.1f× ne s'annule pas avec la caméra" % z)


# ---------------------------------------------------------------------------
# 2. LA GÉOMÉTRIE NE S'EN COMPENSE PAS
# ---------------------------------------------------------------------------

func _test_les_chevrons_sont_en_pixels_monde(balle: GDScript) -> void:
	var reference: Array = []
	for z: float in ZOOMS:
		var g: Dictionary = balle.geometrie_du_releve(400.0, z, 0.0)
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
	var court: Dictionary = balle.geometrie_du_releve(100.0, 1.0, 0.0)
	var long: Dictionary = balle.geometrie_du_releve(400.0, 1.0, 0.0)
	_check((long["chevrons"] as Array).size()
			> (court["chevrons"] as Array).size(),
		"un tir long ne porte pas plus de chevrons qu'un tir court")

	var ch2: Array = long["chevrons"]
	if ch2.size() >= 2:
		_proche((ch2[1] as Vector2).x - (ch2[0] as Vector2).x,
			balle.CHEVRON_PAS, "le pas des chevrons n'est pas CHEVRON_PAS")

	# Le garde-fou : une portée aberrante ne fait pas boucler `_draw`.
	var enorme: Dictionary = balle.geometrie_du_releve(1000000.0, 1.0, 0.0)
	_check((enorme["chevrons"] as Array).size() <= balle.CHEVRON_MAX,
		"le plafond de chevrons ne tient pas : %d posés"
			% (enorme["chevrons"] as Array).size())


# ---------------------------------------------------------------------------
# 3. LA COTE RESTE EN HAUT DE L'ÉCRAN, À TOUS LES ANGLES
# ---------------------------------------------------------------------------

func _test_la_cote_ne_se_retourne_jamais(balle: GDScript) -> void:
	var fautifs: Array[String] = []
	var degeneres := 0
	for pas in 36:
		var angle := TAU * float(pas) / 36.0
		var g: Dictionary = balle.geometrie_du_releve(400.0, 1.0, angle)
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
		var g: Dictionary = balle.geometrie_du_releve(400.0, 1.0, angle)
		var cote: Array = g["cote"]
		var milieu: Vector2 = (cote[0] + cote[1]) * 0.5
		var ancre: Vector2 = g["ancre_texte"]
		_check(signf(ancre.y) == signf(milieu.y) or absf(milieu.y) < 0.001,
			"à %d° l'ancre du texte (%.1f) et la cote (%.1f) sont de deux côtés"
				% [int(rad_to_deg(angle)), ancre.y, milieu.y])


# ---------------------------------------------------------------------------
# 4. LES CHEVRONS POINTENT VERS LA BALLE
# ---------------------------------------------------------------------------

func _test_les_chevrons_disent_le_sens(balle: GDScript) -> void:
	var g: Dictionary = balle.geometrie_du_releve(400.0, 1.0, 0.0)
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

func _test_pas_de_cote_sur_un_moignon(balle: GDScript) -> void:
	var court: Dictionary = balle.geometrie_du_releve(
		balle.COTE_MINIMUM - 1.0, 1.0, 0.0)
	_check(not court["cote_visible"],
		"une cote est posée sous le seuil, là où ses obliques ne tiennent pas")

	var long: Dictionary = balle.geometrie_du_releve(
		balle.COTE_MINIMUM + 1.0, 1.0, 0.0)
	_check(long["cote_visible"], "aucune cote au-dessus du seuil")

	# ⚠️ Le seuil est en pixels MONDE et doit le rester : il dit « ce tir est
	# trop court pour être coté », une propriété du tir et non du cadrage. S'il
	# suivait le zoom, la même mort montrerait sa cote ou pas selon l'instant.
	for z: float in ZOOMS:
		var g: Dictionary = balle.geometrie_du_releve(
			balle.COTE_MINIMUM + 1.0, z, 0.0)
		_check(g["cote_visible"],
			"la visibilité de la cote dépend du zoom (%.1f×)" % z)


# ---------------------------------------------------------------------------
# 6. UN SEUL TIR PORTE LE RELEVÉ
# ---------------------------------------------------------------------------

## ⚠️ **Une killcam rejoue TOUT ce qui a été tiré dans sa fenêtre.** Coter chaque
## balle empilerait des cotes sur des tirs manqués, et *ce qui annote partout
## n'annote plus rien*. Relevé par Adrien avant même d'avoir vu l'écran.
##
## Le contrôle porte sur les deux bouts de la chaîne : la balle a bien un drapeau
## qui NAÎT à faux — une balle de manche réelle ne doit rien coter, même si
## quelqu'un lui pose `is_replay` — et le rejeu sait désigner le tir fatal par
## son INDICE, pas seulement par ses coordonnées.
func _test_un_seul_tir_est_releve(balle: GDScript) -> void:
	var b: Node2D = balle.new()
	_check(not bool(b.get("releve")),
		"une balle naît avec le relevé ACTIF : une manche réelle serait cotée")
	b.free()

	var rejeu: GDScript = load("res://replay_system.gd")
	_check(rejeu != null and rejeu.new().has_method("index_du_tir_fatal"),
		"ReplaySystem ne sait pas désigner le tir fatal par son indice")

	# ⚠️ Et il ne doit y avoir qu'UNE façon de le désigner : `trajectoire_fatale`
	# doit s'appuyer sur le même indice, sinon les deux finiront par désigner deux
	# tirs différents — c'est ce que son propre commentaire annonçait depuis V6.2.
	var source := FileAccess.get_file_as_string("res://replay_system.gd")
	var corps := source.split("func trajectoire_fatale()")
	_check(corps.size() == 2 and corps[1].split("func ")[0]
			.contains("index_du_tir_fatal()"),
		"trajectoire_fatale() redésigne le tir fatal au lieu de réutiliser l'indice")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Le relevé balistique ===")
	await process_frame
	var balle: GDScript = load("res://bullet.gd")
	if balle == null:
		printerr("✗ bullet.gd introuvable")
		quit(1)
		return

	_test_un_seul_tir_est_releve(balle)
	_test_l_annotation_tient_sa_taille_ecran(balle)
	_test_les_chevrons_sont_en_pixels_monde(balle)
	_test_la_cote_ne_se_retourne_jamais(balle)
	_test_les_chevrons_disent_le_sens(balle)
	_test_pas_de_cote_sur_un_moignon(balle)

	print("--- %d contrôles, %d échec(s) ---" % [_ok + _ko, _ko])
	quit(1 if _ko > 0 else 0)
