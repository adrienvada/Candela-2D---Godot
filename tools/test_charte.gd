extends SceneTree

## La charte tient-elle ses propres règles ?
##
## **Une charte n'est pas un document, c'est une contrainte** — sinon c'est une
## intention, et ce dépôt a payé quatre fois en deux jours le prix d'une
## intention écrite au passé. Ce banc rend la contrainte mécanique :
##
## - les **sept** couleurs obéissent aux règles dures (saturation plafonnée,
##   aucune valeur pure sauf le noir du monde) ;
## - les **dérivées** valent exactement leur formule. Elles sont écrites en
##   littéral — GDScript ne sait pas appeler `lerp()` dans une constante — et
##   c'est ici qu'on vérifie que le littéral n'a pas été retouché sans elle ;
## - **le vert n'entre pas dans l'arène**, contrôlé en lisant les fichiers du
##   monde plutôt qu'en s'en remettant à la discipline ;
## - les **fontes font ce qu'on croit qu'elles font**. Deux propriétés se posent
##   sans effet et sans erreur — l'axe de graisse par clé chaîne, et `tnum` sur
##   une fonte qui ne l'a pas. Les deux sont donc vérifiées par la MESURE, jamais
##   par la lecture du réglage.

const C := preload("res://charte.gd")

## Les fichiers où vit le monde : ce que la torche éclaire, et rien de l'interface.
## Le vert y est interdit — voir `_test_pas_de_vert_dans_l_arene()`.
const FICHIERS_MONDE := [
	"res://player.gd",
	"res://bullet.gd",
	"res://blood_stain.gd",
	"res://footprint.gd",
	"res://candela_tileset.gd",
	"res://light_textures.gd",
	"res://particle_pool.gd",
	"res://kill_shockwave.gd",
	"res://pump_shockwave.gd",
	"res://weapon_data.gd",
	"res://training_target.gd",
	"res://training_target_visual.gd",
	"res://map_geometry.gd",
]

var _ok := 0
var _ko := 0


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


func _proche(a: float, b: float, quoi: String, tol := 0.0005) -> void:
	_check(absf(a - b) <= tol, "%s : %.6f attendu, %.6f obtenu" % [quoi, b, a])


func _couleur_egale(a: Color, b: Color, quoi: String) -> void:
	var d := maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)),
		maxf(absf(a.b - b.b), absf(a.a - b.a)))
	_check(d <= 0.0005, "%s : %s attendu, %s obtenu (écart %.5f)" % [quoi, b, a, d])


## Les trois canaux seulement, l'opacité mise de côté.
##
## **Godot multiplie l'alpha comme le reste** : `ROUGE * 0.58` rend un rouge
## sombre *et à moitié transparent*. Les dérivées de la charte sont opaques —
## une teinte assombrie n'est pas une teinte effacée — donc la formule porte sur
## la couleur, pas sur l'opacité. Ce banc l'a relevé à son premier lancement,
## ce qui est exactement ce qu'on lui demande.
static func _rvb(c: Color) -> Color:
	return Color(c.r, c.g, c.b)


## Saturation HSV : c'est elle que plafonne la règle 1, pas la « vivacité »
## ressentie. Un plafond sur une grandeur nommée se vérifie ; un plafond sur une
## impression se négocie à chaque fois.
static func _saturation(c: Color) -> float:
	var maxi := maxf(c.r, maxf(c.g, c.b))
	var mini := minf(c.r, minf(c.g, c.b))
	return 0.0 if maxi <= 0.0 else (maxi - mini) / maxi


## Luminance perceptuelle. Le vert pèse davantage que le bleu : une moyenne naïve
## dirait que le territoire de J2 est plus sombre que celui de J1.
static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


# --- Les règles dures --------------------------------------------------------

func _test_saturation_plafonnee() -> void:
	var sept := {
		"HALOGENE": C.HALOGENE, "AMBRE": C.AMBRE, "VERT": C.VERT,
		"BLEU": C.BLEU, "ROUGE": C.ROUGE, "ACIER": C.ACIER,
	}
	for nom: String in sept:
		var s := _saturation(sept[nom])
		_check(s <= 0.7501, "%s dépasse le plafond de saturation : %.3f" % [nom, s])
	_check(_saturation(C.NOIR) == 0.0, "NOIR devrait être achromatique")


func _test_aucune_valeur_pure() -> void:
	# NOIR est exclu, et son exception est écrite dans la charte : l'écran de
	# calibration mesure le point de noir du joueur sur lui.
	var sept := {
		"HALOGENE": C.HALOGENE, "AMBRE": C.AMBRE, "VERT": C.VERT,
		"BLEU": C.BLEU, "ROUGE": C.ROUGE, "ACIER": C.ACIER,
	}
	for nom: String in sept:
		var c: Color = sept[nom]
		for canal in [c.r, c.g, c.b]:
			_check(canal > 0.0 and canal < 1.0,
				"%s porte un canal pur (%s) — règle 2" % [nom, c])


# --- Les dérivées valent leur formule ----------------------------------------

func _test_derivees() -> void:
	_couleur_egale(_rvb(C.CARMIN), _rvb(C.ROUGE * 0.58), "CARMIN = ROUGE × 0,58")
	_couleur_egale(_rvb(C.DIM), _rvb(C.ACIER * 0.70), "DIM = ACIER × 0,70")
	_couleur_egale(C.LINE, C.NOIR.lerp(C.ACIER, 0.27), "LINE = NOIR→ACIER 27 %")
	_couleur_egale(C.SOL_A, C.NOIR.lerp(C.ACIER, 0.145), "SOL_A = NOIR→ACIER 14,5 %")
	_couleur_egale(C.SOL_A_ARETE, C.NOIR.lerp(C.ACIER, 0.18), "SOL_A_ARETE = NOIR→ACIER 18 %")
	_couleur_egale(C.SOL_B, C.NOIR.lerp(C.ACIER, 0.30), "SOL_B = NOIR→ACIER 30 %")
	_couleur_egale(C.SOL_B_ARETE, C.NOIR.lerp(C.ACIER, 0.38), "SOL_B_ARETE = NOIR→ACIER 38 %")
	_couleur_egale(_rvb(C.ADVERSAIRE), _rvb(C.HALOGENE * C.K_ADVERSAIRE),
		"ADVERSAIRE = HALOGENE × K")
	# Les deux fonds portent un alpha propre : on compare les canaux séparément.
	var s := C.NOIR.lerp(C.ACIER, 0.08)
	_couleur_egale(Color(C.SURFACE.r, C.SURFACE.g, C.SURFACE.b),
		Color(s.r, s.g, s.b), "SURFACE = NOIR→ACIER 8 %")
	_proche(C.SURFACE.a, 0.92, "alpha de SURFACE")
	var b := C.NOIR.lerp(C.ACIER, 0.02)
	_couleur_egale(Color(C.BACKDROP.r, C.BACKDROP.g, C.BACKDROP.b),
		Color(b.r, b.g, b.b), "BACKDROP = NOIR→ACIER 2 %")
	_proche(C.BACKDROP.a, 0.96, "alpha de BACKDROP")


## **Le contrôle d'équité, et le seul de ce banc qui protège le jeu et non l'œil.**
##
## L'adversaire vu depuis l'autre écran a changé de teinte, jamais de quantité de
## lumière. Un coefficient retouché « parce que ça rendait mieux » ferait ici du
## rouge, avant d'avoir avantagé qui que ce soit en ligne.
func _test_equite_de_l_adversaire() -> void:
	_proche(_luminance(C.ADVERSAIRE), _luminance(Color(0.7, 0.7, 0.7)),
		"luminance de l'adversaire (équité)", 0.001)


# --- Le vert n'entre pas dans l'arène ----------------------------------------

## Vert au sens de la règle 3 : une teinte que l'œil nommerait verte. Les gris et
## les blancs cassés en sont exclus par le seuil de saturation, sans quoi le
## contrôle rougirait sur `Color(0.7, 0.7, 0.7)`.
static func _est_vert(c: Color) -> bool:
	if _saturation(c) < 0.18:
		return false
	var h := c.h * 360.0
	return h >= 80.0 and h <= 165.0


## Lit les fichiers du monde et refuse toute couleur verte qui s'y trouverait.
##
## **Contrôlé sur le texte des fichiers, pas sur des valeurs exportées**, parce
## que c'est ainsi que le défaut arriverait : quelqu'un écrit un `Color(...)` à
## la main dans une particule, et rien ne le signale. La règle vaut donc pour ce
## qui est écrit, et pas seulement pour ce que la charte expose.
func _test_pas_de_vert_dans_l_arene() -> void:
	var motif := RegEx.new()
	motif.compile(r"Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)")
	var lus := 0
	for chemin: String in FICHIERS_MONDE:
		if not FileAccess.file_exists(chemin):
			# Un fichier disparu ne fait pas échouer : il fait perdre la
			# couverture, ce qui est pire. On le dit.
			printerr("  ! fichier du monde introuvable, plus surveillé : %s" % chemin)
			_ko += 1
			continue
		lus += 1
		var texte := FileAccess.get_file_as_string(chemin)
		var ligne := 0
		for l in texte.split("\n"):
			ligne += 1
			for m in motif.search_all(l):
				var c := Color(float(m.get_string(1)), float(m.get_string(2)),
					float(m.get_string(3)))
				_check(not _est_vert(c),
					"%s:%d — vert dans l'arène : %s (règle 3)" % [chemin, ligne, c])
	_check(lus == FICHIERS_MONDE.size(), "tous les fichiers du monde ont été lus")


# --- Les courbes -------------------------------------------------------------

## L'extinction rend-elle bien ce que le dépôt faisait AVANT d'être converti ?
##
## ⚠️ **Le contrôle décisif de DA4.13, et il ne porte pas sur la charte.** Il
## compare `EXTINCTION` à `TRANS_EXPO`+`EASE_OUT` **de Godot**, c'est-à-dire à ce
## que les sept animations d'extinction faisaient avant la conversion. Un
## chantier dont le but est de passer par le vocabulaire de la maison doit être
## **neutre en sensation par construction** : s'il change ce qu'on voit, ce n'est
## plus un chantier de vocabulaire, et personne ne reliera jamais « le flash de
## coup est devenu mou » à une migration de tweens trois semaines plus tard.
##
## L'oracle est donc EXTÉRIEUR à ce qu'on vérifie — c'est Godot lui-même. Un
## contrôle qui comparerait `EXTINCTION` à ses propres points de Bézier ne
## dirait rien.
func _test_l_extinction_ne_change_pas_ce_qu_on_voyait() -> void:
	var tw := create_tween()
	var pire := 0.0
	var ou := 0.0
	var t := 0.0
	while t <= 1.0:
		var maison: float = C.courbe(C.Courbe.EXTINCTION, t)
		var godot: float = tw.interpolate_value(0.0, 1.0, t, 1.0,
			Tween.TRANS_EXPO, Tween.EASE_OUT)
		var ecart := absf(maison - godot)
		if ecart > pire:
			pire = ecart
			ou = t
		t += 0.02
	tw.kill()
	var tw2 := create_tween()

	# 4 % : l'écart d'une approximation de Bézier à une exponentielle vraie. Au
	# delà, ce n'est plus la même courbe et la conversion changerait la sensation.
	_check(pire < 0.04,
		"EXTINCTION s'écarte de %.3f de `expo out` en t=%.2f : la conversion "
		% [pire, ou] + "de DA4.13 ne serait plus neutre")

	# ⚠️ **La quatrième courbe doit GAGNER son existence, en chiffres.** Le premier
	# jet de ce contrôle exigeait qu'elle soit « assez différente » d'`ENTREE`, et
	# il rougissait à 0,042 d'écart. C'était la mauvaise question : deux sens
	# distincts ont le droit de partager une forme voisine, et l'exiger différente
	# aurait poussé à la déformer POUR le banc. La bonne question est : colle-t-elle
	# mieux à ce qu'elle remplace ?
	#
	# Mesuré : `ENTREE` s'écarte de 0,048 d'`expo out`, `EXTINCTION` de 0,012 —
	# quatre fois plus près. C'est ce rapport qui la justifie, pas un écart.
	var ecart_entree := 0.0
	t = 0.0
	while t <= 1.0:
		var g: float = tw2.interpolate_value(0.0, 1.0, t, 1.0,
			Tween.TRANS_EXPO, Tween.EASE_OUT)
		ecart_entree = maxf(ecart_entree, absf(C.courbe(C.Courbe.ENTREE, t) - g))
		t += 0.02
	_check(pire < ecart_entree * 0.5,
		("EXTINCTION (%.4f d'expo out) ne colle pas nettement mieux qu'ENTREE " +
		"(%.4f) : elle ne gagne pas son existence") % [pire, ecart_entree])

	# ⚠️ **Et le contre-exemple, qui est le fait le plus utile de ce contrôle.**
	# `SORTIE` s'écarte de 0,87 d'`expo out`. C'est l'ordre de grandeur de ce
	# qu'aurait coûté la conversion « par le sens du mot » : une extinction posée
	# sur `SORTIE` ne se serait pas éteinte, elle serait restée pleine puis aurait
	# disparu d'un coup. Le nombre est ici pour qu'on n'ait plus à en discuter.
	var ecart_sortie := 0.0
	t = 0.0
	while t <= 1.0:
		var g: float = tw2.interpolate_value(0.0, 1.0, t, 1.0,
			Tween.TRANS_EXPO, Tween.EASE_OUT)
		ecart_sortie = maxf(ecart_sortie, absf(C.courbe(C.Courbe.SORTIE, t) - g))
		t += 0.02
	_check(ecart_sortie > 0.5,
		"SORTIE ne s'écarte que de %.3f d'expo out : si les deux se ressemblent, "
		% ecart_sortie + "la quatrième courbe n'avait pas lieu d'être")
	tw2.kill()


func _test_courbes() -> void:
	for q in [C.Courbe.ENTREE, C.Courbe.SORTIE, C.Courbe.REBOND,
			C.Courbe.EXTINCTION]:
		_proche(C.courbe(q, 0.0), 0.0, "courbe %d part de 0" % q)
		_proche(C.courbe(q, 1.0), 1.0, "courbe %d arrive à 1" % q)

	# L'entrée et la sortie restent dans le cadre ; le rebond, non, et c'est lui.
	var crete_rebond := 0.0
	var t := 0.0
	while t <= 1.0:
		var e := C.courbe(C.Courbe.ENTREE, t)
		var s := C.courbe(C.Courbe.SORTIE, t)
		_check(e >= -0.001 and e <= 1.001, "ENTREE sort du cadre en t=%.2f (%.3f)" % [t, e])
		_check(s >= -0.001 and s <= 1.001, "SORTIE sort du cadre en t=%.2f (%.3f)" % [t, s])
		crete_rebond = maxf(crete_rebond, C.courbe(C.Courbe.REBOND, t))
		t += 0.02
	_check(crete_rebond > 1.02,
		"REBOND ne dépasse pas — sans dépassement ce n'est plus un rebond (crête %.3f)" % crete_rebond)

	# Ce qui sépare vraiment les deux premières : l'entrée a déjà fait le gros du
	# chemin au quart du temps, la sortie s'attarde. Vérifier seulement les bornes
	# les laisserait interchangeables.
	_check(C.courbe(C.Courbe.ENTREE, 0.25) > 0.5,
		"ENTREE devrait avoir dépassé la moitié au quart du temps")
	_check(C.courbe(C.Courbe.SORTIE, 0.25) < 0.15,
		"SORTIE devrait à peine avoir bougé au quart du temps")

	# Monotonie de l'entrée : un aller-retour y passerait pour un défaut d'affichage.
	var precedent := -1.0
	t = 0.0
	while t <= 1.0:
		var v := C.courbe(C.Courbe.ENTREE, t)
		_check(v >= precedent - 0.001, "ENTREE recule en t=%.2f" % t)
		precedent = v
		t += 0.02


## **`animer()` atteint-il vraiment la propriété qu'on lui nomme ?**
##
## Le contrôle qui manquait, et son absence a coûté un écran de menu entièrement
## invisible : `Object.set("modulate:a", …)` ne lève rien et ne fait rien, alors
## que `tween_property` accepte ce chemin. Une bonne moitié des animations du
## dépôt sont écrites avec un sous-chemin — il fallait donc en exercer un.
##
## Le contrôle porte sur la VALEUR OBTENUE, jamais sur l'appel : c'est la même
## règle que pour `tnum` et l'axe de graisse, et c'est la troisième fois dans ce
## seul fichier qu'elle attrape quelque chose.
## `custom_step()` n'applique rien tant que l'arbre n'a pas tourné une image :
## un `Tween` fraîchement créé n'est pas encore démarré, et le pas manuel se
## perd en silence. Deux frames d'abord, puis un pas franc — et surtout **pas**
## une attente d'images pour mesurer, qui mesurerait la machine.
func _test_animer_atteint_un_sous_chemin() -> void:
	var hote := Node2D.new()
	var plat := Node2D.new()
	root.add_child(hote)
	root.add_child(plat)
	hote.modulate.a = 0.0
	plat.rotation = 0.0
	var tween := hote.create_tween()
	C.animer(tween, hote, "modulate:a", 0.0, 1.0, C.D_MOYEN, C.Courbe.ENTREE)
	# Et une propriété simple, pour que le correctif du chemin n'ait pas cassé
	# le cas courant.
	var t2 := plat.create_tween()
	C.animer(t2, plat, "rotation", 0.0, 2.0, C.D_COURT, C.Courbe.SORTIE)

	await process_frame
	await process_frame

	tween.custom_step(C.D_MOYEN * 0.5)
	var milieu := hote.modulate.a
	tween.custom_step(C.D_MOYEN)
	var fin := hote.modulate.a
	t2.custom_step(C.D_COURT * 2.0)

	_check(milieu > 0.01, "animer() n'a pas bougé la sous-propriété (milieu = %.3f)" % milieu)
	_proche(fin, 1.0, "animer() n'atteint pas sa valeur d'arrivée", 0.01)
	_proche(plat.rotation, 2.0, "animer() sur une propriété simple", 0.01)

	hote.queue_free()
	plat.queue_free()


## **`animer_via()` atteint-il l'appel, et le fait-il suivre la COURBE ?**
##
## Deux choses à prouver, et la seconde est celle qui compte. Qu'un `Callable`
## soit appelé se voit ; qu'il reçoive une valeur **courbée** ne se voit pas —
## un jour où `interpoler()` serait court-circuitée, l'animation deviendrait
## linéaire, tout continuerait de fonctionner, et personne ne saurait dire
## pourquoi l'écran a l'air moins vivant.
##
## Le contrôle est donc posé à **un quart du parcours** : `ENTREE` y dépasse
## déjà la moitié de sa course (c'est ce que vérifie `_test_courbes`), là où une
## interpolation linéaire vaudrait exactement 0,25. Un écart qu'aucune tolérance
## raisonnable ne confond.
func _test_animer_via_atteint_l_appel() -> void:
	var hote := Node2D.new()
	root.add_child(hote)
	var recu: Array[float] = []
	var sonde := func(v: float) -> void:
		recu.append(v)

	var tween := hote.create_tween()
	C.animer_via(tween, sonde, 0.0, 1.0, C.D_MOYEN, C.Courbe.ENTREE)

	await process_frame
	await process_frame

	tween.custom_step(C.D_MOYEN * 0.25)
	var au_quart := recu[-1] if not recu.is_empty() else -1.0
	tween.custom_step(C.D_MOYEN)
	var fin := recu[-1] if not recu.is_empty() else -1.0

	_check(not recu.is_empty(), "animer_via() n'a jamais appelé son Callable")
	_check(au_quart > 0.5,
		"animer_via() n'applique pas la courbe : au quart, %.3f (linéaire = 0,25)"
			% au_quart)
	_proche(fin, 1.0, "animer_via() n'atteint pas sa valeur d'arrivée", 0.01)

	# Un `Callable` lié à un objet libéré doit être ignoré, pas appelé. C'est le
	# pendant du `is_instance_valid()` d'`animer()`, et la raison pour laquelle
	# le garde-fou emploie `is_valid()`.
	var mort := Node2D.new()
	root.add_child(mort)
	var tw2 := hote.create_tween()
	C.animer_via(tw2, Callable(mort, "set_rotation"), 0.0, 1.0, C.D_COURT)
	mort.free()
	await process_frame
	tw2.custom_step(C.D_COURT)
	_check(true, "animer_via() survit à un Callable dont l'objet est mort")

	hote.queue_free()


## **Les écrans parlent-ils encore l'ancienne langue ?** (DA4.13)
##
## DA1.8 a livré trois courbes maison et un point d'entrée unique pour remplacer
## les `TRANS_*` de Godot. **Livrer un vocabulaire ne fait pas qu'on le parle** :
## au 2026-08-25 le dépôt comptait 7 appels à `Charte.animer()` contre 31
## `set_trans()`. Rien ne tenait l'écart, donc il ne se réduisait pas.
##
## ⚠️ **Ce contrôle lit la SOURCE, et c'est assumé ici.** Le dépôt se méfie à
## juste titre des bancs qui lisent le code plutôt que l'écran — c'est un motif
## consigné trois fois. L'exception tient à ce qu'on mesure : la courbe qu'une
## animation emprunte **est** une propriété du texte, pas du pixel. On ne peut
## pas la relever sur un rendu sans réimplémenter un profileur d'animation.
##
## ⚠️ **Le domaine « game feel » est HORS périmètre, pas exempté.**
## `player.gd`, `bullet.gd`, `game_state.gd` et `audio_manager.gd` appartiennent
## à une autre session (voir `docs/JOURNAL_SESSIONS.md`) : les convertir serait
## une refonte opportuniste sur des fichiers qu'on ne tient pas. Le jour où cette
## session le décide, il suffit de les retirer de la liste ci-dessous.
## ⚠️ **Vide depuis le 2026-08-27, et c'est la fin de DA4.13.**
##
## Elle a porté quatre noms — `player.gd`, `bullet.gd`, `game_state.gd`,
## `audio_manager.gd` — non par oubli mais par **frontière de domaine** : ce sont
## les fichiers de « game feel », et un chantier d'interface n'y entre pas de sa
## propre initiative. Les vingt et une dernières courbes de Godot y vivaient.
##
## Adrien a levé la frontière le 2026-08-27 (« finalise 4.13 »). La liste reste
## déclarée plutôt que supprimée : **elle est le point d'entrée du jour où une
## exception redeviendra nécessaire**, et un tableau vide qui porte son
## explication vaut mieux qu'une exception réinventée sans elle.
const _HORS_PERIMETRE: Array[String] = []

func _test_les_ecrans_parlent_la_langue_de_la_maison() -> void:
	var fautifs: Array[String] = []
	var d := DirAccess.open("res://")
	if d == null:
		_check(false, "impossible d'ouvrir res:// pour l'audit des courbes")
		return
	for f in d.get_files():
		if not f.ends_with(".gd") or _HORS_PERIMETRE.has(f):
			continue
		var texte := FileAccess.get_file_as_string("res://" + f)
		if texte.contains("set_trans(Tween.TRANS_"):
			fautifs.append(f)
	_check(fautifs.is_empty(),
		"ces écrans emploient encore les courbes de Godot : %s"
			% ", ".join(fautifs))


func _test_durees() -> void:
	_proche(C.D_COURT, 0.09, "durée courte")
	_proche(C.D_MOYEN, 0.18, "durée moyenne")
	_proche(C.D_LONG, 0.30, "durée longue")


# --- Les fontes font-elles ce qu'on croit ? ----------------------------------

func _test_polices_presentes() -> void:
	var absentes := C.polices_manquantes()
	_check(absentes.is_empty(), "fontes absentes : %s" % str(absentes))


## Le tag entier de l'axe de graisse est bien celui de `wght`.
func _test_tag_wght() -> void:
	var ts := TextServerManager.get_primary_interface()
	_check(ts.name_to_tag("wght") == C.TAG_WGHT,
		"TAG_WGHT vaut %d, name_to_tag('wght') rend %d" % [C.TAG_WGHT, ts.name_to_tag("wght")])


## **L'axe de graisse agit-il, ou est-il seulement écrit ?**
##
## `variation_opentype` accepte une clé en chaîne, la conserve, la relit — et
## n'en fait rien. Le seul contrôle qui distingue les deux cas est de mesurer
## deux graisses et d'exiger qu'elles diffèrent. Sans lui, le dépôt aurait
## remplacé son faux gras par un autre faux gras.
func _test_axe_de_graisse_agit() -> void:
	for nom in ["display", "ui"]:
		var basse: Font = (C.police_display(200) if nom == "display" else C.police_ui(200))
		var haute: Font = (C.police_display(900) if nom == "display" else C.police_ui(900))
		if basse == null or haute == null:
			_check(false, "fonte %s introuvable pour le contrôle de graisse" % nom)
			continue
		var lb := basse.get_string_size("CANDELA", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var lh := haute.get_string_size("CANDELA", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		_check(absf(lh - lb) > 1.0,
			"fonte %s : wght 200 et 900 rendent la même chasse (%.1f) — l'axe n'est pas appliqué"
				% [nom, lb])


## **Les chiffres sont-ils tabulaires ?**
##
## La question de DA4.2, et elle ne se pose pas au réglage. Poser
## `opentype_features = {"tnum": 1}` sur une fonte qui n'a pas la fonctionnalité
## ne fait rien et ne dit rien — c'est ce qui a écarté le premier candidat. On
## mesure donc les dix chiffres : un chrono ne doit pas se déplacer en passant
## de 1 à 0.
func _test_chiffres_tabulaires() -> void:
	var f := C.police_ui(C.POIDS_APPUI)
	if f == null:
		_check(false, "fonte d'interface introuvable")
		return
	var mini := INF
	var maxi := -INF
	for d in range(10):
		var l := f.get_string_size(str(d).repeat(9), HORIZONTAL_ALIGNMENT_LEFT,
			-1, C.T_APPUI).x
		mini = minf(mini, l)
		maxi = maxf(maxi, l)
	_check(maxi - mini < 0.01,
		"chiffres non tabulaires : de %.1f à %.1f px pour neuf chiffres" % [mini, maxi])


func _test_echelle_typographique() -> void:
	var echelle := [C.T_MENTION, C.T_COURANT, C.T_APPUI, C.T_TITRE,
		C.T_VERDICT, C.T_ENSEIGNE]
	for i in range(1, echelle.size()):
		_check(echelle[i] > echelle[i - 1],
			"l'échelle typographique doit être strictement croissante (rang %d)" % i)
	# Six tailles, et le nombre compte : c'est lui qui empêche d'en ajouter une
	# « juste pour ce cas-là ». Le dépôt en portait vingt-cinq.
	_check(echelle.size() == 6, "l'échelle doit compter exactement six tailles")
	# Le décompte est une dérivée, pas un septième cran.
	_check(C.T_DECOMPTE == C.T_ENSEIGNE * 2,
		"T_DECOMPTE doit valoir exactement deux fois l'enseigne")


func _init() -> void:
	print("=== Charte visuelle ===")
	_test_saturation_plafonnee()
	_test_aucune_valeur_pure()
	_test_derivees()
	_test_equite_de_l_adversaire()
	_test_pas_de_vert_dans_l_arene()
	_test_courbes()
	_test_l_extinction_ne_change_pas_ce_qu_on_voyait()
	await _test_animer_atteint_un_sous_chemin()
	await _test_animer_via_atteint_l_appel()
	_test_les_ecrans_parlent_la_langue_de_la_maison()
	_test_durees()
	_test_polices_presentes()
	_test_tag_wght()
	_test_axe_de_graisse_agit()
	_test_chiffres_tabulaires()
	_test_echelle_typographique()
	if _ko == 0:
		print("✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)
