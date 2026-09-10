extends "res://tools/photographe.gd"

## DA7.2 — le cinéaste : **le photographe dont l'obturateur reste ouvert.**
##
## Le trailer était bloqué sur « aucune capture vidéo n'existe ». C'était faux :
## **Godot sait filmer depuis toujours** (`--write-movie`, cadence fixe forcée,
## `--quit-after` pour compter les images) — personne n'avait regardé. Il ne
## manquait donc pas un outil de capture, il manquait la **mise en scène**, et
## elle existait déjà : c'est celle du photographe.
##
## D'où ce fichier, qui n'a presque rien à lui. Il hérite de tout — sélection des
## plans, préconditions, éclairage, marionnettes, cadrage — et **surcharge une
## seule fonction** : `_prendre()`. Là où le photographe tient l'état puis
## déclenche, le cinéaste tient l'état et ne déclenche jamais : le moteur écrit
## chaque image tout seul.
##
## ## Un plan par lancement, et c'est délibéré
##
## Le mode film enregistre **tout** ce qui passe à l'écran, amorçage compris. Un
## seul lancement pour douze plans filmerait aussi les onze transitions. On lance
## donc le jeu une fois par plan, et on découpe. Coût : quelques secondes de
## démarrage par plan. Gain : un plan raté ne coûte que lui-même, et l'ordre du
## montage se change sans retourner quoi que ce soit.
##
## ## Comment le montage sait où couper
##
## Le cinéaste imprime deux repères sur la sortie standard :
##
##     CINEASTE debut <id> <image>
##     CINEASTE fin   <id> <image>
##
## `Engine.get_frames_drawn()` compte les images DESSINÉES, et le mode film force
## une cadence fixe : l'image *n* est donc exactement à *n / fps* secondes du
## début du fichier. `run_trailer.sh` n'a plus qu'à découper à ces bornes. C'est
## exact, et ça ne dépend d'aucune horloge murale — un ordinateur chargé rend le
## même film.
##
## ⚠️ **Le sans-écran ne peut pas filmer.** Mesuré : le mode s'active, puis
## abandonne sur `Parameter "t" is null` — il n'y a aucune texture à écrire. Il
## faut une vraie fenêtre. `run_trailer.sh` s'en charge et le dit.
##
## ⚠️ **Le son est coupé**, hérité du photographe. Une séance tire des dizaines
## de coups de feu, et le montage pose sa propre musique. La piste audio du
## fichier existe mais elle est muette : `run_trailer.sh` la jette.

const Charte := preload("res://charte.gd")

## Durée par défaut d'un plan, en secondes.
const DUREE_DEFAUT := 4.0

## Ce qu'on laisse couler avant et après le plan, pour que le montage ait de quoi
## fondre sans mordre sur le sujet.
const MARGE := 0.35

var _duree := DUREE_DEFAUT

## La cadence du film, PASSÉE et non devinée.
##
## Elle doit valoir exactement le `--fixed-fps` du moteur, sinon les repères
## d'image ne correspondent plus aux secondes du fichier et le montage coupe à
## côté. La lire depuis `Engine` serait une supposition de plus sur un mode que
## personne n'avait employé ici : `run_trailer.sh` la donne, une seule fois, aux
## deux endroits.
var _fps := 60.0


## ⚠️ LE DÉCOMPTE D'AVANT-MANCHE EST ÉCOURTÉ, ET CE N'EST PAS UN DÉTAIL.
##
## Le photographe démarre une VRAIE partie locale pour chaque séance : écran de
## salon, lancement, puis attente que le décompte 3-2-1 s'achève. Pour une
## photo, c'est trois secondes d'horloge. **Pour un film, ce sont deux cents
## images ENREGISTRÉES** — encodées une par une, entre 60 et 950 ms chacune
## selon la charge du poste — et **jetées au montage**, puisque aucun plan ne
## commence avant.
##
## Autrement dit : la moitié du temps de tournage servait à filmer un écran que
## personne ne verrait jamais. On fait donc tomber le décompte à zéro dès qu'une
## manche s'ouvre.
##
## On ne le supprime pas, on l'écourte : la manche démarre normalement, avec sa
## logique intacte. C'est seulement le temps d'attente qui disparaît.
func _process(_delta: float) -> void:
	if _main == null or not is_instance_valid(_main):
		return
	if _main.round_active and _main.countdown_left > 0.0:
		_main.countdown_left = 0.0


func _ready() -> void:
	# Lu ici et pas dans le parent : c'est le seul réglage propre au cinéaste.
	var args := OS.get_cmdline_user_args()
	_duree = maxf(0.5, float(_valeur(args, "--duree", str(DUREE_DEFAUT))))
	_fps = maxf(1.0, float(_valeur(args, "--fps", "60")))

	# ⚠️ LE CARTON NE CHARGE PAS LE JEU, et c'est tout son intérêt : une phrase
	# sur du noir n'a besoin ni d'arène, ni de joueurs, ni de préconditions. Il
	# sort donc AVANT `super()`, qui monterait `main.tscn` pour rien — huit
	# secondes de démarrage par carton, pour afficher une ligne de texte.
	var texte := _valeur(args, "--carton", "")
	if texte != "":
		await _jouer_un_carton(texte)
		return
	if _drapeau(args, "--enseigne"):
		await _jouer_l_enseigne()
		return
	super()


## L'ENSEIGNE — le logo naît d'un noir, et sa lumière vacille.
##
## C'est DA7.8 pris à l'envers. L'enseigne du menu est un pochoir rétroéclairé
## dont la lumière MEURT quand personne ne joue ; ici elle NAÎT, et le vacillement
## est le même — irrégulier, jamais périodique. Un clignotement régulier serait
## une diode ; une flamme a des ratés qu'on ne peut pas prévoir.
##
## Trois temps, et le dernier n'est pas décoratif : la lumière **se stabilise**.
## Une enseigne qui vacille jusqu'au bout dirait qu'elle va s'éteindre — or ici
## elle s'installe, c'est le début du film.
func _jouer_l_enseigne() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 200
	add_child(couche)

	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	couche.add_child(fond)

	var enseigne := TextureRect.new()
	enseigne.texture = load(Charte.CHEMIN_ENSEIGNE)
	enseigne.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enseigne.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enseigne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Une marge franche : le wordmark est large, et il respire mieux qu'il ne
	# remplit. C'est aussi ce que fait le site.
	var marge := 0.16
	enseigne.anchor_left = marge
	enseigne.anchor_right = 1.0 - marge
	enseigne.anchor_top = 0.30
	enseigne.anchor_bottom = 0.70
	enseigne.offset_left = 0.0
	enseigne.offset_right = 0.0
	enseigne.offset_top = 0.0
	enseigne.offset_bottom = 0.0
	enseigne.modulate.a = 0.0
	couche.add_child(enseigne)

	var images := maxi(1, int(round(_duree * _fps)))
	var etat := {"prochain": 0.0, "creux": 0.0}
	var depart := Engine.get_frames_drawn()
	print("CINEASTE debut enseigne %d" % depart)
	await _tenir_images(images, func() -> void:
		var t: float = clampf(float(Engine.get_frames_drawn() - depart) / float(images), 0.0, 1.0)
		var delta: float = 1.0 / _fps
		# 1. La montée, lente et amortie : la lumière monte comme un filament,
		#    vite au début puis de plus en plus doucement.
		var base: float = 1.0 - pow(1.0 - clampf(t / 0.42, 0.0, 1.0), 2.2)
		# 2. Le vacillement, sur la première moitié seulement.
		etat["prochain"] = float(etat["prochain"]) - delta
		if float(etat["prochain"]) <= 0.0 and t < 0.62:
			etat["prochain"] = randf_range(0.18, 0.55)
			etat["creux"] = randf_range(0.15, 0.45)
		etat["creux"] = maxf(0.0, float(etat["creux"]) - delta * 3.2)
		# 3. La stabilisation : le vacillement s'éteint tout seul avec le temps.
		var reste: float = clampf((0.68 - t) / 0.68, 0.0, 1.0)
		enseigne.modulate.a = clampf(base - float(etat["creux"]) * reste, 0.0, 1.0))
	print("CINEASTE fin enseigne %d" % Engine.get_frames_drawn())
	_sortir(0)


## LE CARTON — une phrase sur du noir, dans la fonte du jeu.
##
## ffmpeg n'a pas `drawtext` sur ce poste : il ne sait pas écrire. Le texte doit
## donc venir d'ailleurs, et le moteur est le bon ailleurs — il a la fonte de
## l'enseigne (`BigShouldersDisplay`), la palette de la charte, et il rend le
## même texte que le jeu. Un carton fabriqué dans un autre outil aurait une
## autre typographie, et ça se verrait.
##
## Le mot monte et redescend en fondu : un carton qui apparaît d'un coup coupe
## le film, un carton qui monte le tient.
func _jouer_un_carton(texte: String) -> void:
	var couche := CanvasLayer.new()
	couche.layer = 200
	add_child(couche)

	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	couche.add_child(fond)

	var mot := Label.new()
	mot.text = texte
	mot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mot.offset_left = 140.0
	mot.offset_right = -140.0
	mot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fonte := load("res://assets/fonts/BigShouldersDisplay.ttf") as Font
	if fonte != null:
		mot.add_theme_font_override("font", fonte)
	# 150 et non 96 : le film sort en 1280 de large, et un carton se lit de loin.
	mot.add_theme_font_size_override("font_size", 150)
	mot.add_theme_color_override("font_color", Charte.HALOGENE)
	mot.modulate.a = 0.0
	couche.add_child(mot)

	var images := maxi(1, int(round(_duree * _fps)))
	var depart := Engine.get_frames_drawn()
	print("CINEASTE debut carton %d" % depart)
	await _tenir_images(images, func() -> void:
		var t: float = clampf(float(Engine.get_frames_drawn() - depart) / float(images), 0.0, 1.0)
		# Un tiers pour monter, un tiers en pleine lumière, un tiers pour partir.
		mot.modulate.a = clampf(t / 0.3, 0.0, 1.0) * clampf((1.0 - t) / 0.3, 0.0, 1.0))
	print("CINEASTE fin carton %d" % Engine.get_frames_drawn())
	_sortir(0)


## Tient l'état du plan pendant toute sa durée, sans jamais capturer.
##
## Toute la différence avec le photographe tient dans les deux lignes qui
## manquent à la fin : pas de `_capturer()`, pas de `_ecrire()`. Le moteur écrit
## déjà chaque image.
func _prendre(plan: Dictionary, tenir := Callable(), repos := -1.0) -> void:
	if plan.is_empty():
		return
	# `repos` est le temps de stabilisation que le photographe s'accorde avant de
	# déclencher : on le garde tel quel, mais on ne le compte PAS dans le plan.
	# Un décor qui se met en place n'est pas du film.
	var stabilisation: float = _repos if repos < 0.0 else repos
	await _laisser_couler(stabilisation, tenir)

	var id := String(plan.get("id", "?"))
	await _laisser_couler(MARGE, tenir)
	print("CINEASTE debut %s %d" % [id, Engine.get_frames_drawn()])
	if CHOREGRAPHIES.has(id):
		await _jouer(id, tenir)
	else:
		await _laisser_couler(_duree, tenir)
	print("CINEASTE fin %s %d" % [id, Engine.get_frames_drawn()])
	await _laisser_couler(MARGE, tenir)


## Les plans qui se JOUENT au lieu de se tenir. Les autres restent des poses —
## un décor, une carte, une affiche n'ont rien à jouer.
const CHOREGRAPHIES := {
	"torche": "_fouiller",
	"duel": "_se_chercher",
	"retrodiffusion": "_se_croiser",
	"flash-de-tir": "_tirer_dans_le_noir",
	"gel-fatal": "_abattre",
}


## Déroule la chorégraphie `id` sur toute la durée du plan.
##
## `t` va de 0 à 1 : une chorégraphie ne connaît donc pas les secondes, et
## rallonger un plan ne la casse pas — elle s'étire avec lui.
func _jouer(id: String, tenir: Callable) -> void:
	var troupe := _distribuer()
	# ⚠️ Le photographe remet les deux joueurs à 100 PV À CHAQUE IMAGE — c'est
	# ce qui empêche une séance de perdre son sujet. Pour le plan fatal, il faut
	# lui désobéir : sans ça on tire, on touche, et personne ne tombe jamais.
	var laisser_mourir := id == "gel-fatal"
	var images := maxi(1, int(round(_duree * _fps)))
	var methode := String(CHOREGRAPHIES[id])
	var depart := Engine.get_frames_drawn()
	await _tenir_images(images, func() -> void:
		var t: float = clampf(float(Engine.get_frames_drawn() - depart) / float(images), 0.0, 1.0)
		call(methode, troupe, t)
		# ⚠️ ON N'APPELLE PAS `tenir`, ET C'EST LE CORRECTIF LE PLUS VISIBLE DU
		# FILM. Le `tenir` du photographe replace J2 PAR RAPPORT À J1 à chaque
		# image — c'est ce qui cadre une photo de duel, et c'est exactement ce
		# qu'il ne faut pas filmer : à l'écran, J2 semblait suivre la lampe de
		# J1 comme une ombre. Les deux doivent bouger indépendamment.
		#
		# On garde seulement `_vivants()`, qui les maintient debout sans les
		# déplacer — sauf sur le plan fatal, où quelqu'un doit pouvoir tomber.
		if not laisser_mourir:
			_vivants())


## LA FOUILLE — un homme seul avance dans le noir en balayant devant lui.
##
## Le balayage est la seule chose que ce jeu demande vraiment de comprendre :
## on ne voit que là où l'on pointe, et le faisceau met du temps à couvrir. Le
## montrer coûte trois secondes de mouvement ; le raconter aurait coûté une
## phrase que personne n'aurait crue.
func _fouiller(troupe: Array, t: float) -> void:
	if troupe.is_empty():
		return
	var lui: Comedien = troupe[0]
	lui.torche = true
	# Un aller-retour complet sur la durée du plan, amorti aux extrémités : un
	# balayage à vitesse constante a l'air mécanique, une main ralentit en bout
	# de course.
	var angle: float = sin(t * TAU) * deg_to_rad(38.0)
	lui.visee = VISEE.normalized().rotated(angle)
	# Il avance, doucement, et s'arrête sur la fin — comme quelqu'un qui a vu
	# quelque chose.
	lui.deplacement = Vector2.RIGHT * (0.0 if t > 0.78 else 0.55)
	if troupe.size() > 1:
		var autre: Comedien = troupe[1]
		autre.torche = false
		autre.deplacement = Vector2.ZERO


## SE CHERCHER — deux hommes se cherchent, et ne se trouvent pas.
##
## Les deux balaient, à des rythmes PREMIERS entre eux (3 et 5 quarts de tour) :
## leurs faisceaux ne se synchronisent jamais, et aucun spectateur ne peut lire
## une relation entre les deux. C'est ce qui donne deux volontés au lieu d'une.
func _se_chercher(troupe: Array, t: float) -> void:
	if troupe.is_empty():
		return
	var lui: Comedien = troupe[0]
	lui.torche = true
	lui.visee = VISEE.normalized().rotated(sin(t * TAU * 0.75) * deg_to_rad(42.0))
	lui.deplacement = Vector2(0.5, sin(t * TAU * 0.5) * 0.4)
	if troupe.size() > 1:
		var autre: Comedien = troupe[1]
		autre.torche = true
		# Rythme, amplitude, axe et trajet : tout diffère. Rien ici ne dépend
		# de ce que fait l'autre.
		autre.visee = Vector2.LEFT.rotated(cos(t * TAU * 1.25 + 1.1) * deg_to_rad(55.0))
		autre.deplacement = Vector2(-0.35, cos(t * TAU * 0.8 + 2.2) * 0.5)


## SE CROISER — les deux faisceaux se frôlent sans que personne ne s'arrête.
func _se_croiser(troupe: Array, t: float) -> void:
	if troupe.is_empty():
		return
	var lui: Comedien = troupe[0]
	lui.torche = true
	lui.visee = VISEE.normalized().rotated(deg_to_rad(lerpf(-30.0, 30.0, t)))
	lui.deplacement = Vector2(0.45, -0.2)
	if troupe.size() > 1:
		var autre: Comedien = troupe[1]
		autre.torche = true
		# Il balaie dans l'AUTRE sens : les cônes se croisent une fois, au
		# milieu du plan, et repartent chacun de son côté.
		autre.visee = Vector2.LEFT.rotated(deg_to_rad(lerpf(34.0, -34.0, t)))
		autre.deplacement = Vector2(-0.4, 0.3)


## TIRER DANS LE NOIR — on tire sur ce qu'on croit avoir vu.
##
## Personne ne vise personne : c'est le propos. Deux hommes qui tirent vers un
## mouvement, chacun à son propre rythme, et le flash est la seule lumière.
func _tirer_dans_le_noir(troupe: Array, t: float) -> void:
	if troupe.is_empty():
		return
	var lui: Comedien = troupe[0]
	# Il a ÉTEINT sa torche pour ne pas se désigner — et tire à l'aveugle.
	lui.torche = t < 0.18
	lui.visee = VISEE.normalized().rotated(sin(t * TAU * 0.6) * deg_to_rad(18.0))
	lui.deplacement = Vector2(0.3, sin(t * TAU * 1.3) * 0.5)
	lui.tire = fposmod(t * 5.0, 1.0) < 0.2
	if troupe.size() > 1:
		var autre: Comedien = troupe[1]
		autre.torche = false
		autre.visee = Vector2.LEFT.rotated(cos(t * TAU * 0.9 + 0.7) * deg_to_rad(22.0))
		autre.deplacement = Vector2(-0.25, cos(t * TAU * 1.1) * 0.45)
		# Cadence différente, décalée : deux tireurs, pas un écho.
		autre.tire = fposmod(t * 3.5 + 0.31, 1.0) < 0.16


## LE COUP FATAL — on tire jusqu'à ce que l'autre tombe, et le jeu s'arrête.
##
## Le gel n'est pas monté : c'est le jeu qui fige, tout seul, comme en partie.
func _abattre(troupe: Array, t: float) -> void:
	if troupe.is_empty():
		return
	var lui: Comedien = troupe[0]
	lui.torche = true
	lui.visee = VISEE.normalized()
	lui.deplacement = Vector2.ZERO
	lui.tire = t > 0.18 and t < 0.55
	if troupe.size() > 1:
		var autre: Comedien = troupe[1]
		autre.torche = false
		autre.deplacement = Vector2.ZERO


## Laisse passer `secondes` en maintenant l'état à chaque image.
##
## On compte en IMAGES et non en millisecondes d'horloge : sous `--write-movie`
## le temps du moteur est simulé à cadence fixe, et une attente en temps réel
## donnerait un plan de durée imprévisible — long sur une machine lente, court
## sur une rapide. C'est le piège inverse de celui du rejeu, qui dimensionnait
## un tampon en nombre d'images alors qu'il lui fallait des secondes : ici il
## faut des images, parce que c'est l'image qui est l'unité du fichier.
func _laisser_couler(secondes: float, tenir: Callable) -> void:
	await _tenir_images(int(round(secondes * _fps)), tenir)


## Tient jusqu'à ce que `images` IMAGES AIENT ÉTÉ DESSINÉES.
##
## ⚠️ **TROIS VERSIONS ONT ÉTÉ ÉCRITES. VOICI POURQUOI C'EST CELLE-CI.**
##
## 1. *Compter les tours de boucle.* Juste pour les plans de jeu — la scène est
##    lourde, le moteur dessine à chaque tour. **Faux pour un carton** : la
##    scène est quasi vide, la boucle de traitement tourne des dizaines de fois
##    par image écrite, et un carton de 2,4 s sortait à 0,12 s. Sept images pour
##    cent quarante-quatre tours.
## 2. *Compter les images dessinées, garde-fou à vingt fois le compte.* La bonne
##    unité — l'unité du fichier EST l'image — mais la clôture était vingt fois
##    trop serrée, précisément parce que le rapport tours/images peut dépasser
##    cent. Le garde-fou coupait avant la fin, sans erreur et sans repère.
##    **La bonne solution a été jetée à cause de sa clôture.**
## 3. Celle-ci : la même unité, une clôture qui ne parle plus en tours mais en
##    TEMPS RÉEL. Une boucle qui n'avance pas se voit à l'horloge du mur, pas au
##    nombre de tours — et l'horloge du mur ne dépend pas de la charge du poste.
##
## La leçon, et elle vaut au-delà d'ici : **un garde-fou mal calibré condamne le
## code juste.** Le premier réflexe a été de changer la logique ; il fallait
## changer la limite.
func _tenir_images(images: int, par_image: Callable) -> void:
	var vise := Engine.get_frames_drawn() + maxi(1, images)
	# Deux minutes de temps réel : très au-delà de tout plan légitime, et sans
	# aucun rapport avec le nombre de tours.
	var limite := Time.get_ticks_msec() + 120000
	while Engine.get_frames_drawn() < vise:
		if par_image.is_valid():
			par_image.call()
		await get_tree().process_frame
		if Time.get_ticks_msec() > limite:
			push_warning("cinéaste : deux minutes sans atteindre %d images — on sort" % images)
			return


## Le cinéaste n'écrit aucune image : le manifeste et la planche du photographe
## n'auraient rien à décrire. Surchargé pour ne pas laisser derrière lui un
## manifeste vide qu'on prendrait pour une séance ratée.
func _ecrire(_plan: Dictionary, _img: Image) -> void:
	pass


# =============================================================================
# LE SCÉNARIO — ce qui manquait au premier jet
# =============================================================================
#
# ⚠️ **Le premier trailer était un diaporama, et la faute est ici.** Le cinéaste
# héritait de la mise en scène du photographe sans se demander si une POSE fait
# un PLAN. Elle ne le fait pas : la `Marionnette` du photographe rend un
# mouvement nul et ne tire jamais — elle existe pour qu'une image soit nette,
# pas pour qu'il se passe quelque chose. Quinze poses tenues trois secondes
# donnent quinze photographies à la suite.
#
# Un plan de film a besoin de trois choses qu'une photographie n'a pas : du
# MOUVEMENT, une CAUSE et une CONSÉQUENCE. D'où le comédien ci-dessous, qui
# marche et qui tire, et la chorégraphie qui le dirige image par image.


## Une marionnette qui joue. Tout ce que l'autre refuse de faire.
class Comedien extends Marionnette:
	var deplacement := Vector2.ZERO
	var tire := false
	var recharge := false
	var fusee := false

	func get_movement_vector() -> Vector2:
		return deplacement

	func is_shoot_pressed() -> bool:
		return tire

	func is_reload_pressed() -> bool:
		return recharge

	func is_flare_pressed() -> bool:
		return fusee


## Remplace les marionnettes du photographe par des comédiens.
##
## Même installation, même `_set_player_input_provider` : seul le fournisseur
## change. `player.gd` ne sait pas d'où viennent ses commandes — c'est le patron
## `InputProvider`, et c'est la première fois qu'on s'en sert pour faire JOUER
## quelqu'un plutôt que pour le tenir immobile.
func _distribuer() -> Array:
	var troupe: Array = []
	for j in [_main.p1, _main.p2]:
		if not is_instance_valid(j):
			continue
		var c := Comedien.new()
		c.name = "Comedien"
		c.visee = VISEE.normalized()
		_main._set_player_input_provider(j, c)
		troupe.append(c)
	_pantins.clear()
	for c in troupe:
		_pantins.append(c)
	return troupe
