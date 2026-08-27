extends Node2D

## Le banc du VOILE d'éblouissement — le régler, pas en choisir un.
##
## ## À quoi il sert
##
## « Imagine que notre vue, notre UI, c'est entièrement une caméra éblouie par
## une lampe. C'était ça le voile blanc » (Adrien, 2026-08-27). Le voile est
## aujourd'hui un aplat ; il doit devenir cette caméra-là — **tout le cadre qui
## blanchit**, plus fort au centre, avec des lueurs et des flares qui bougent
## dedans et qui penchent du côté de l'éblouisseur.
##
##   `1` le voile          `0` l'aplat d'aujourd'hui, le témoin
##
## ⚠️ **Ce banc a d'abord proposé TROIS candidats, et c'était une erreur de
## lecture.** « Je voulais juste remplacer le voile d'éblouissement » : la
## demande était un réglage, pas un choix. Trois propositions côte à côte
## répondaient à une question que personne n'avait posée, et le banc y perdait
## sa lisibilité — on ne savait plus ce qu'on regardait.
##
## **Le témoin, lui, reste et compte.** Sans aller-retour immédiat vers ce qui
## existe déjà, on juge une nouveauté contre le souvenir qu'on a de l'ancienne.
## Le `0` est aussi ce qui permet de répondre « non », qui est une réponse.
##
## ## Ce qu'il montre EN PLUS du voile, et pourquoi c'est nécessaire
##
## Le halo et le flou de `brouillage.gd`, par leur appareil de production
## (`brouillage_vue.gd`), instancié tel quel. **Un voile jugé seul serait jugé
## faux** : il vit désormais au-dessus d'un halo qui éclaire et d'une ellipse qui
## floute, et c'est leur somme que le joueur reçoit. La touche `B` les coupe,
## pour savoir ce qui vient de qui.
##
## ## Ce qu'il ne fait PAS
##
## Il ne mesure aucune performance de tir, contrairement à `banc_brouillage`. Le
## voile ne cache pas l'adversaire — le halo et le flou s'en chargent, et cette
## répartition est une décision actée du 2026-08-25. Compter des tirs ici
## mesurerait le halo en croyant mesurer le voile.
##
## **Il mesure en revanche l'OPACITÉ MOYENNE** (touche `E`), et c'est le seul
## nombre qui compte pour la suite. L'aplat vaut 0,3 partout ; un voile creusé
## qui culminerait à 0,3 pèserait beaucoup moins lourd. Sans ce relevé, le
## nouveau voile passerait pour « à peu près pareil » tout en allégeant en
## silence une mécanique qui coûte 40 % de vitesse.
##
## Lancer : `godot --path . res://tools/banc_voile.tscn`

const Charte := preload("res://charte.gd")
const Brouillage := preload("res://brouillage.gd")
const Eblouissement := preload("res://eblouissement.gd")
const SHADER_VOILE := preload("res://voile_eblouissement.gdshader")
const APPAREIL_BROUILLAGE := preload("res://brouillage_vue.gd")

## Le joueur ébloui. Une classe et non un `Node2D` nu : `brouillage_vue.maj()`
## lit `regardeur.dazzle_amount`, et un nœud qui ne porte pas la propriété rend
## `null` — que `float()` refuse. Le banc doit présenter à l'appareil de
## production exactement ce que la production lui présente.
class Regardeur extends Node2D:
	var dazzle_amount: float = 0.0


## Le polygone du joueur, recopié de `player.tscn` — seize côtés, rayon 18.
## Recopié et non chargé : instancier `player.tscn` amènerait
## `MultiplayerSynchronizer`, `LocalInputProvider` et `MapGeometry`, donc les
## autoloads, pour dessiner un disque.
##
## ⚠️ **`static var` et non `const`, et le piège était DÉJÀ consigné dans
## `banc_brouillage.gd` — je l'ai repayé quand même.** GDScript refuse un
## `PackedVector2Array` en constante : l'appel de constructeur n'est pas
## repliable. Et le refus est une erreur d'**analyse**, donc la scène tourne
## SANS script, ne dessine rien et sort proprement en 0 : le banc s'ouvre sur
## un écran noir et personne ne sait pourquoi. Attrapé ici par `test_banc`,
## qui est exactement ce pour quoi ces `preconditions_manquantes()` existent.
static var CORPS: PackedVector2Array = PackedVector2Array([
	Vector2(18, 0), Vector2(16.63, 6.89), Vector2(12.73, 12.73), Vector2(6.89, 16.63),
	Vector2(0, 18), Vector2(-6.89, 16.63), Vector2(-12.73, 12.73), Vector2(-16.63, 6.89),
	Vector2(-18, 0), Vector2(-16.63, -6.89), Vector2(-12.73, -12.73), Vector2(-6.89, -16.63),
	Vector2(0, -18), Vector2(6.89, -16.63), Vector2(12.73, -12.73), Vector2(16.63, -6.89),
])

const NOMS_MODE := [
	"0 · aplat (témoin — ce que le jeu fait aujourd'hui)",
	"1 · le voile — lavis plein écran + lueurs + flares",
]

## Les uniformes entiers. Le banc range tout en `float` — un seul type, une
## seule boucle de poussée — et ne reconvertit qu'ici, au moment d'écrire.
const ENTIERS := ["mode", "lueurs_n", "flares_n", "fantomes_n"]

## Les réglages, dans l'ordre où l'on veut les toucher : d'abord le voile
## lui-même — c'est lui qu'Adrien décrit comme « une caméra éblouie » —, puis ce
## qui se pose dessus.
##
## ⚠️ **Une seule liste, et c'est un retour en arrière assumé.** Elle était
## découpée par candidat, parce qu'il y avait trois candidats. Il n'y en a plus
## qu'un : « je voulais juste remplacer le voile d'éblouissement » (Adrien,
## 2026-08-27). Trois propositions côte à côte répondaient à une question que
## personne n'avait posée, et elles coûtaient la lisibilité du banc.
const REGLAGES := [
	["PLANCHER (le voile partout)", "plancher", 0.0, 1.0, 0.02],
	["CIME (le voile au centre)", "cime", 0.0, 1.0, 0.02],
	["largeur du lavis", "largeur", 0.2, 5.0, 0.1],
	["courbe du lavis", "courbe", 0.2, 4.0, 0.1],
	["nombre de lueurs", "lueurs_n", 0.0, 4.0, 1.0],
	["intensité des lueurs", "lueurs_intensite", 0.0, 1.5, 0.02],
	["échelle des lueurs", "lueurs_echelle", 0.1, 4.0, 0.05],
	["INCLINAISON des lueurs", "lueurs_derive", 0.0, 1.5, 0.02],
	["souffle des lueurs", "lueurs_souffle", 0.0, 0.6, 0.02],
	["nombre de flares", "flares_n", 0.0, 8.0, 1.0],
	["intensité des flares", "flares_intensite", 0.0, 1.5, 0.02],
	["longueur des flares", "flares_longueur", 0.2, 6.0, 0.1],
	["largeur des flares", "flares_largeur", 0.02, 1.0, 0.02],
	["INCLINAISON des flares", "flares_penche", 0.0, 1.0, 0.05],
	["scintillement des flares", "flares_scintille", 0.0, 1.0, 0.02],
	["TREMBLEMENT (la main)", "tremble_ampl", 0.0, 0.6, 0.005],
	["tremblement — lent (Hz)", "tremble_hz_a", 0.0, 4.0, 0.05],
	["tremblement — rapide (Hz)", "tremble_hz_b", 0.0, 8.0, 0.05],
	["nombre de fantômes", "fantomes_n", 0.0, 6.0, 1.0],
	["intensité des fantômes", "fantomes_intensite", 0.0, 1.5, 0.02],
	["écart des fantômes", "fantomes_ecart", 0.05, 1.5, 0.02],
	["taille des fantômes", "fantomes_taille", 0.02, 1.0, 0.01],
	["CÔTÉ des fantômes (−1 = réel)", "fantomes_cote", -1.0, 1.0, 2.0],
	["force du grain", "grain_force", 0.0, 0.5, 0.005],
	["rafraîchissement du grain", "grain_hz", 0.0, 60.0, 2.0],
]

## Portée du faisceau du banc, en pixels. Le banc **ne recopie pas l'arsenal** —
## `game_state.gd` et `banc_brouillage.gd` le font déjà tous les deux, et une
## troisième copie serait une troisième chose à tenir à jour. Le voile ne dépend
## d'aucune arme : le faisceau n'est ici que le décor qui rend l'éblouissement
## visible et crédible. Ses deux paramètres se règlent donc directement, ce qui
## couvre plus de cas que quatre préréglages figés.
var _cone_deg: float = 35.0
var _echelle_torche: float = 1.6

## L'arme du banc, construite UNE FOIS et refaite seulement quand le cône bouge.
##
## ⚠️ **Elle était reconstruite à chaque image, et c'était un défaut, pas une
## maladresse.** `get_torch_texture()` fabrique le cookie du faisceau ; une
## `WeaponData` neuve à chaque image le refabrique à chaque image, et
## `lumiere_recue()` relit son image dans la foulée. Le banc se serait mis à
## ramer précisément quand on lui demande de juger une animation — c'est-à-dire
## qu'il aurait fait passer son propre coût pour un défaut du voile.
##
## C'est la même famille que la texture de halo de `banc_brouillage`, refaite
## uniquement au changement de netteté et jamais dans `_rendre`.
var _arme: WeaponData

## Les deux textures du voile. **Fabriquées ici si elles n'existent pas sur
## disque, et remplacées sans une ligne de shader si elles y sont.**
##
## C'est tout l'intérêt d'être passé par des textures plutôt que par des
## formules : le jour où une vraie photo de flare arrive — d'une session
## d'assets, ou d'un cliché d'Adrien —, elle se substitue à celle qu'on
## fabrique. Le shader ne sait pas d'où elles viennent.
##
## ⚠️ **Elles doivent être NOIRES sur tout leur pourtour.** Le shader les
## échantillonne hors de leurs bornes en permanence, et `repeat_disable` étire le
## texel du bord à l'infini : un bord non nul peindrait une bande sur la moitié
## de l'écran.
const CHEMIN_LUEUR := "res://assets/sprites/voile_lueur.png"
const CHEMIN_FLARE := "res://assets/sprites/voile_flare.png"
const CHEMIN_FANTOME := "res://assets/sprites/voile_fantome.png"
var _lueur_tex: Texture2D
var _flare_tex: Texture2D
var _fantome_tex: Texture2D
var _textures_fournies: bool = false

# --- état vivant ------------------------------------------------------------
var _mode: int = 1
var _dazzle: float = 0.0
var _temps: float = 0.0
var _fige: bool = false          ## Geler le temps pour juger une image FIXE.
var _auto: bool = true           ## Niveau mesuré depuis le faisceau, ou forcé.
var _niveau_manuel: float = 0.8
var _orbite: bool = true         ## L'éblouisseur tourne-t-il tout seul ?
var _distance: float = 320.0
var _angle: float = -1.2         ## Relèvement de l'éblouisseur, en radians.
var _brouillage_actif: bool = true

## La photocopie d'écran du flou : `RECT` (ce que fait la production) ou plein
## cadre. **Touche `M`, et c'est un instrument de diagnostic, pas un réglage.**
##
## ⚠️ **`RECT` produit un polygone à arêtes franches près du joueur**, signalé
## par Adrien le 2026-08-27 et reproduit ici : le flou lit des texels que la
## photocopie n'a pas rafraîchis, donc l'image d'une position PRÉCÉDENTE, et la
## frontière de la zone recopiée se dessine en dur. En plein cadre il disparaît.
##
## Le banc démarre sur `RECT` **exprès** : c'est ce que le jeu fait, et un banc
## qui corrigerait silencieusement un défaut de production le rendrait
## invisible. `M` sert à répondre « ça vient de là » en une touche.
var _copie_plein_cadre: bool = false
var _etalonnage: bool = false    ## En cours de relevé : le monde est caché.
## En train de tirer la planche de contact. **Sans ce drapeau, `_process`
## repasserait derrière la planche à chaque image** — il rappellerait `_rendre()`
## avec le relèvement courant et l'on capturerait douze fois la même chose.
var _planche_active: bool = false
var _dernier_releve: String = ""
var _reglage: int = 0
var _touche_inconnue: String = ""

## Les valeurs vives des uniformes. **Elles naissent des défauts déclarés DANS
## le shader**, jamais d'une seconde table écrite ici : deux tables de défauts
## divergent, et l'écart ne se voit sur aucune capture. Le banc ne fait que
## déplacer des nombres, et il imprime en sortant ceux qu'il a atteints.
var _val: Dictionary = {}

# --- nœuds ------------------------------------------------------------------
var _monde: Node2D
var _camera: Camera2D
var _regardeur: Regardeur
var _porteur: Node2D
var _torche: PointLight2D
var _silhouette: Node2D
var _appareil: Node
var _voile: ColorRect
var _mat: ShaderMaterial
var _couche_texte: CanvasLayer
var _panneau: Label
var _aide: Label


## Les appuis de ce banc sur le jeu, vérifiables sans ouvrir de fenêtre.
##
## Même discipline que `bench_framerate` et `planche_eblouissement` : un outil
## qui ouvre une fenêtre ne peut être dans aucune suite headless, donc il se
## périme en silence — sauf s'il NOMME ce dont il dépend sous une forme qu'une
## suite peut lire. Le banc de cadence a mis une semaine à s'apercevoir qu'il ne
## démarrait plus ; c'est cette semaine-là que cette fonction achète.
##
## ⚠️ **Ce sont les UNIFORMES qui sont fragiles ici**, et leur péremption est
## silencieuse d'une façon particulière : un réglage renommé dans le shader ne
## casse rien — le banc part simplement de zéro sur ce réglage-là, et l'on juge
## un effet éteint en croyant juger un effet raté.
##
## `chemin_shader` n'existe que pour le CONTRE-TEST, et il n'est pas décoratif :
## une vérification incapable de rougir rend toujours une liste vide et passe
## pour verte à jamais. Les deux autres bancs l'obtiennent en recevant `null` à
## la place de l'arbre ; celui-ci ne reçoit rien, donc il faut lui donner une
## prise. `ResourceLoader.exists` plutôt qu'un `load` qui échoue : un chemin
## bidon ferait crier le moteur dans une suite qui, elle, doit rester muette.
static func preconditions_manquantes(
		chemin_shader: String = "res://voile_eblouissement.gdshader") -> Array[String]:
	var absents: Array[String] = []

	var shader: Shader = null
	if ResourceLoader.exists(chemin_shader):
		shader = load(chemin_shader)
	if shader == null:
		absents.append("le shader du voile a disparu (%s)" % chemin_shader)
	else:
		var connus := {}
		for u in shader.get_shader_uniform_list(true):
			connus[String(u["name"])] = true
		var attendus := ["mode", "niveau", "teinte", "relevement", "aspect",
			"temps", "lueur_tex", "flare_tex", "fantome_tex"]
		for r in REGLAGES:
			attendus.append(String(r[1]))
		for nom in attendus:
			if not connus.has(nom):
				absents.append("uniforme « %s » absent du shader du voile" % nom)

	var appareil: GDScript = load("res://brouillage_vue.gd")
	if appareil == null:
		absents.append("brouillage_vue.gd a disparu")
	else:
		var sonde: Node = appareil.new()
		for methode in ["maj", "eteindre"]:
			if not sonde.has_method(methode):
				absents.append("BrouillageVue.%s() a disparu" % methode)
		sonde.free()

	var arme := WeaponData.new()
	for methode in ["lumiere_recue", "get_torch_texture", "echelle_torche"]:
		if not arme.has_method(methode):
			absents.append("WeaponData.%s() a disparu" % methode)

	return absents


func _ready() -> void:
	var refus := RenduCommun.refus_headless()
	if refus != "":
		push_error("banc_voile : %s" % refus)
		print("banc_voile : refus — %s" % refus)
		get_tree().quit(1)
		return
	var manquants := preconditions_manquantes()
	if not manquants.is_empty():
		push_error("banc_voile : appuis manquants — %s" % "; ".join(manquants))
	RenderingServer.set_default_clear_color(Charte.NOIR)
	_forger_textures()
	_lire_defauts()
	_batir_monde()
	_batir_ecran()
	_poser_arme()
	if "--planche" in OS.get_cmdline_user_args():
		_planche()
		return
	print("--- banc du voile — 0 témoin · 1/2/3 les candidats · Échap pour sortir ---")
	for nom in manquants:
		print("  ⚠ ", nom)


## La PLANCHE DE CONTACT : chaque candidat, à trois relèvements, en images.
##
## `godot --path . res://tools/banc_voile.tscn -- --planche`
##
## ## Pourquoi elle existe, et ce qu'elle ne remplace pas
##
## Elle ne remplace **rien** du banc : un flare se juge en mouvement, et trois
## des quatre candidats ne sont que du mouvement. Elle répond à une question
## plus modeste et préalable — **est-ce que ça dessine seulement quelque
## chose ?** Un shader qui rend du noir, un cœur ovale, un voile posé sous le
## halo : tout cela se voit sur une image fixe, et n'a aucune raison de coûter à
## Adrien le lancement d'un banc.
##
## ⚠️ **Les relèvements ne sont PAS symétriques, et c'est délibéré.** Le halo du
## chantier brouillage s'est posé cent pixels à côté de sa cible pendant une
## journée parce que son unique capture de contrôle avait l'émetteur pile
## au-dessus du canon — le seul point où l'erreur horizontale s'annule. **Une
## capture de contrôle ne se prend pas sur un cas symétrique**, la symétrie étant
## exactement ce qui annule les erreurs qu'on cherche. D'où 0°, 145° et −65°.
func _planche() -> void:
	_planche_active = true
	# Le panneau et l'aide sont du mobilier de banc : sur une planche ils ne font
	# que masquer un coin de ce qu'on vient regarder. Le nom du fichier porte
	# déjà le mode et le relèvement.
	_couche_texte.visible = false
	var dossier := "user://planches_voile"
	DirAccess.make_dir_recursive_absolute(dossier)
	_orbite = false
	_auto = false
	_niveau_manuel = 0.85
	_fige = true
	_temps = 4.37  # Un instant quelconque, mais le MÊME pour les deux modes.
	var releves: Array[String] = []
	# ⚠️ **Chaque cas est tiré DEUX FOIS : avec le halo et le flou, puis sans.**
	# C'est la seule façon de répondre à « ça vient d'où ? » sur une image fixe.
	# Adrien a signalé un polygone à arêtes franches près du joueur ; il était
	# visible en mode TÉMOIN, donc pas dans le voile — et sans cette paire, on ne
	# peut que le supposer.
	for b in [true, false]:
		_brouillage_actif = b
		for m in 2:
			for a in [0.0, 145.0, -65.0]:
				_mode = m
				_angle = deg_to_rad(a)
				_bouger_eblouisseur(0.0)
				_integrer(0.0)
				_rendre()
			# ⚠️ **Trois images, et la troisième n'est pas de la superstition.**
			# Le flou du brouillage lit une photocopie d'écran ; la première
			# image après un changement de mode en porte encore la trace du mode
			# précédent. Deux images suffisaient à poser les paramètres, pas à
			# purger ce que le tampon gardait.
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				var nom := "%s/voile-mode%d-%+04d-%s.png" % [dossier, m, int(a),
					"avec-brouillage" if b else "voile-seul"]
				img.save_png(nom)
				releves.append(nom)
			# ⚠️ **On imprime la GÉOMÉTRIE avec l'image.** Une planche se juge à
			# l'œil, et l'œil ne sait pas dire « l'éblouisseur est à 145° » : il
			# dit « la lumière est à gauche ». Sans ces trois nombres, une erreur
			# de repère se lit comme un choix esthétique.
				var vers_ecran := get_viewport().get_canvas_transform()
				print("  mode %d  %-16s demandé %+7.1f°  relèvement %+7.1f°  "
					% [m, "avec brouillage" if b else "voile seul", a,
						rad_to_deg((_porteur.global_position
							- _regardeur.global_position).angle())]
					+ "monde %s  écran %s (centre %s)" % [
						_porteur.global_position,
						vers_ecran * _porteur.global_position,
						get_viewport().get_visible_rect().size * 0.5])
	print("--- planche du voile : %d images ---" % releves.size())
	print("  ", ProjectSettings.globalize_path(dossier))
	for m in 2:
		print("  mode %d — %s" % [m, NOMS_MODE[m]])
	get_tree().quit()


## Les défauts, lus dans le shader lui-même.
##
## `RenderingServer.shader_get_parameter_default` est le seul chemin qui ne
## recopie rien : la valeur affichée au banc EST celle que la production
## utiliserait si personne ne touchait à rien. Une table de défauts écrite ici
## aurait fait mentir le banc le jour où le shader change — et un banc qui ment
## sur son point de départ fait rejuger un réglage qu'on croyait connaître.
func _lire_defauts() -> void:
	var rid := SHADER_VOILE.get_rid()
	var noms: Array = []
	for r in REGLAGES:
		noms.append(String(r[1]))
	for nom in noms:
		var defaut = RenderingServer.shader_get_parameter_default(rid, nom)
		if defaut == null:
			# Le cri du repli muet : sans lui, un uniforme renommé partirait
			# silencieusement de zéro et l'on jugerait un effet éteint.
			push_error("banc_voile : le shader n'a pas de défaut pour « %s »" % nom)
			_val[nom] = 0.0
		else:
			_val[nom] = float(defaut)


## Les deux textures : celles du disque si elles y sont, sinon fabriquées.
func _forger_textures() -> void:
	if ResourceLoader.exists(CHEMIN_LUEUR) and ResourceLoader.exists(CHEMIN_FLARE) \
			and ResourceLoader.exists(CHEMIN_FANTOME):
		_lueur_tex = load(CHEMIN_LUEUR)
		_flare_tex = load(CHEMIN_FLARE)
		_fantome_tex = load(CHEMIN_FANTOME)
		_textures_fournies = _lueur_tex != null and _flare_tex != null \
			and _fantome_tex != null
		if _textures_fournies:
			return
	_lueur_tex = _forger_lueur()
	_flare_tex = _forger_flare()
	_fantome_tex = _forger_fantome()


## Une lueur ronde : blanche au centre, rigoureusement noire au bord.
##
## Deux termes et non un : un cœur serré `(1−r)^4` pour la brûlure, et un halo
## large `(1−r)^1,4` pour ce qui bave autour. Une seule puissance donne soit une
## bille dure, soit une tache molle — jamais les deux, et c'est les deux qu'on
## voit d'une lampe braquée dans un objectif.
func _forger_lueur(taille: int = 256) -> ImageTexture:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var c := float(taille - 1) * 0.5
	for y in taille:
		for x in taille:
			var r := Vector2(float(x) - c, float(y) - c).length() / c
			var t := clampf(1.0 - r, 0.0, 1.0)
			var v := pow(t, 4.0) * 0.75 + pow(t, 1.4) * 0.35
			img.set_pixel(x, y, Color(1, 1, 1, 1) * minf(v, 1.0))
	return ImageTexture.create_from_image(_border_noir(img))


## Une traînée horizontale : vive sur l'axe, éteinte partout ailleurs.
##
## ⚠️ **Le profil EN TRAVERS est beaucoup plus creusé que le profil EN
## LONG** — `^6` contre `^1,8`. C'est ce rapport qui fait une traînée plutôt
## qu'une ellipse : l'œil lit une traînée à sa finesse, pas à sa longueur.
##
## L'irrégularité vient d'un peigne de sinus le long de l'axe. Sans elle, la
## traînée est un trait parfait — donc un trait DESSINÉ, pas une aberration
## d'optique. C'est le même défaut de fond que le halo qui était un cercle
## parfait : ce qui est trop régulier se lit comme une forme, et une forme est
## une chose de plus à lire.
func _forger_flare(larg: int = 512, haut: int = 64) -> ImageTexture:
	var img := Image.create(larg, haut, false, Image.FORMAT_RGBA8)
	for y in haut:
		var v := absf(float(y) / float(haut - 1) * 2.0 - 1.0)
		var travers := pow(clampf(1.0 - v, 0.0, 1.0), 6.0)
		for x in larg:
			var u := float(x) / float(larg - 1) * 2.0 - 1.0
			var long := pow(clampf(1.0 - absf(u), 0.0, 1.0), 1.8)
			var peigne := 0.72 + 0.28 * sin(u * 37.0) * sin(u * 11.3 + 1.7)
			img.set_pixel(x, y, Color(1, 1, 1, 1) * clampf(long * travers * peigne, 0.0, 1.0))
	return ImageTexture.create_from_image(_border_noir(img))


## Un fantôme d'objectif : le disque à IRIS, avec son liseré.
##
## ⚠️ **Il est HEXAGONAL, et ce n'est pas de la coquetterie.** Un fantôme rond
## est une bulle ; un fantôme à six côtés est le diaphragme de l'objectif qu'on
## regarde à travers. C'est le détail qui fait dire « photo » plutôt que
## « effet » — et c'est précisément ce qu'Adrien demande aux fantômes
## d'apporter (2026-08-27).
##
## Trois termes : un intérieur presque plat et faible, un liseré vif au bord, et
## une chute franche au-delà. Le liseré est le plus important des trois : sans
## lui on obtient une tache, et une tache de plus ne fait pas un objectif.
func _forger_fantome(taille: int = 256) -> ImageTexture:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var c := float(taille - 1) * 0.5
	for y in taille:
		for x in taille:
			var p := Vector2(float(x) - c, float(y) - c) / c
			# Rayon HEXAGONAL : on ramène l'angle dans un sixième de tour et on
			# divise par l'apothème. `r = 1` est alors le bord de l'hexagone,
			# quel que soit l'angle.
			var ang := fposmod(p.angle(), PI / 3.0) - PI / 6.0
			# ⚠️ **Le `/ 0,78` est ce qui garde le pourtour NOIR, et son absence a
			# blanchi tout l'écran.** Sans lui, les côtés plats de l'hexagone
			# tombent pile sur le bord de la texture : le liseré y vaut encore
			# 0,27, et `repeat_disable` étire ce texel à l'infini — quatre
			# fantômes ajoutaient donc 0,27 chacun SUR TOUTE L'IMAGE.
			#
			# Le shader porte l'avertissement en toutes lettres (« les textures
			# DOIVENT être noires sur tout leur pourtour »). Je l'ai écrit pour
			# les deux premières et violé sur la troisième — un avertissement ne
			# protège que ce qu'on pense à relire.
			var r := p.length() * cos(ang) / cos(PI / 6.0) / 0.78
			# ⚠️ **Un fantôme est un disque REMPLI à liseré, pas un fil de fer.**
			# Le premier jet donnait 0,22 d'intérieur contre 0,85 de liseré : à
			# l'écran, une chaîne de contours hexagonaux nets, qui se lit comme
			# du dessin vectoriel et non comme une photo. C'est l'inverse du but,
			# puisque les fantômes n'ont été ajoutés que pour « augmenter le
			# réalisme » (Adrien, 2026-08-27).
			#
			# Trois termes désormais, et l'ordre de leurs poids est le réglage :
			# un intérieur franc, un liseré plus discret que lui, et un léger
			# dégradé qui empêche l'intérieur d'être un aplat — un aplat parfait
			# est aussi peu photographique qu'un contour parfait.
			var interieur := 0.34 * (1.0 - smoothstep(0.72, 1.0, r))
			var degrade := 0.10 * clampf(1.0 - r, 0.0, 1.0)
			var lisere := 0.46 * exp(-pow((r - 0.95) / 0.055, 2.0))
			var v := clampf(interieur + degrade + lisere, 0.0, 1.0) \
				* (1.0 - smoothstep(1.0, 1.08, r))
			img.set_pixel(x, y, Color(1, 1, 1, 1) * v)
	return ImageTexture.create_from_image(_border_noir(img))



## La CEINTURE : le pourtour d'une texture, forcé à noir.
##
## ⚠️ **Ce n'est pas de la prudence, c'est un garde-fou payé.** Le shader
## échantillonne les trois textures largement hors de leurs bornes, et
## `repeat_disable` y étire le texel du bord. Un seul texel non nul sur un bord
## se répand donc sur une moitié d'écran — c'est arrivé au fantôme, et l'image
## est sortie ENTIÈREMENT BLANCHE, ce qui ne ressemble à aucun défaut de forme et
## n'oriente donc vers rien.
##
## Une formule peut oublier de s'annuler au bord ; deux pixels de ceinture, non.
func _border_noir(img: Image) -> Image:
	var l := img.get_width()
	var h := img.get_height()
	for x in l:
		for y in [0, 1, h - 2, h - 1]:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in h:
		for x in [0, 1, l - 2, l - 1]:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


func _batir_monde() -> void:
	_monde = Node2D.new()
	_monde.name = "Monde"
	add_child(_monde)

	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)

	# ⚠️ **LA NUIT. Sans elle, le banc ment sur la seule chose qui compte.**
	#
	# `arena.tscn` porte un `CanvasModulate` à `Charte.NOIR` : dans le jeu, rien
	# n'est visible hors des lumières. Sans lui, le sol se dessine à pleine
	# valeur partout et les torches ne font que l'éclaircir — on juge alors un
	# voile blanc posé sur du gris, quand le jeu le pose sur du noir. Le
	# contraste n'est pas le même, donc l'opacité jugée ne l'est pas non plus.
	#
	# ⚠️ **`tools/banc_brouillage.gd` n'en a PAS**, constaté le 2026-08-27 —
	# signalé, pas corrigé : il appartient à un autre chantier, et le corriger
	# rendrait discutables les quatre arbitrages d'Adrien du 2026-08-25 (halo à
	# 150 px, voile à 0,3, gain à 2,0), tous rendus sur ce sol-là.
	var nuit := CanvasModulate.new()
	nuit.name = "Nuit"
	nuit.color = Charte.NOIR
	_monde.add_child(nuit)

	# Le sol. Il ne sert qu'à une chose, et elle est essentielle : sans texture au
	# sol, un faisceau qui balaie ne se VOIT pas balayer, et l'éblouissement
	# n'aurait plus de cause visible à l'écran.
	var sol := Sprite2D.new()
	sol.name = "Sol"
	sol.texture = _damier()
	sol.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sol.region_enabled = true
	sol.region_rect = Rect2(0, 0, 4096, 2560)
	sol.light_mask = 1
	sol.z_index = -20
	_monde.add_child(sol)

	for coin in [Vector2(-780, -420), Vector2(780, -420),
			Vector2(-780, 420), Vector2(780, 420)]:
		_bloc(coin, Vector2(170, 170))

	# L'éblouisseur : le porteur du faisceau, et une silhouette pour qu'il ait un
	# corps. Le halo de `brouillage_vue` se pose sur lui.
	_porteur = Node2D.new()
	_porteur.name = "Porteur"
	_monde.add_child(_porteur)

	_torche = PointLight2D.new()
	_torche.name = "Torche"
	_torche.shadow_enabled = true
	_torche.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	_torche.shadow_item_cull_mask = 1
	_torche.range_item_cull_mask = 1 | 2
	_torche.energy = 2.5
	_torche.color = Charte.HALOGENE
	_torche.position = Vector2(30, 0)
	_porteur.add_child(_torche)

	_silhouette = Node2D.new()
	_silhouette.name = "Silhouette"
	_silhouette.z_index = 10
	_porteur.add_child(_silhouette)
	# Sa propre petite lumière, comme le `body_light` du joueur dans le jeu :
	# sans elle, l'éblouisseur est un trou noir au bout de son propre faisceau.
	var lueur := PointLight2D.new()
	lueur.name = "Lueur"
	lueur.shadow_enabled = false
	lueur.range_item_cull_mask = 2
	lueur.energy = 1.1
	lueur.color = Charte.HALOGENE
	lueur.texture = _rond(96)
	_silhouette.add_child(lueur)
	var corps := Polygon2D.new()
	corps.polygon = CORPS
	corps.color = Charte.HALOGENE
	corps.light_mask = 2
	_silhouette.add_child(corps)

	# Le joueur ébloui, au centre. Non ombré : c'est le repère du banc, et s'il
	# s'éteignait avec le reste on ne saurait plus où est « soi ».
	_regardeur = Regardeur.new()
	_regardeur.name = "Regardeur"
	_regardeur.z_index = 10
	_monde.add_child(_regardeur)
	var non_ombre := CanvasItemMaterial.new()
	non_ombre.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var moi := Polygon2D.new()
	moi.polygon = CORPS
	moi.color = Charte.BLEU
	moi.material = non_ombre
	_regardeur.add_child(moi)
	var canon := Line2D.new()
	canon.points = PackedVector2Array([Vector2(18, 0), Vector2(46, 0)])
	canon.width = 4.0
	canon.default_color = Charte.BLEU
	canon.material = non_ombre
	_regardeur.add_child(canon)

	# L'appareil de PRODUCTION, instancié tel quel — halo et flou compris.
	# Le banc ne réécrit pas ce qu'il veut juger autour.
	_appareil = APPAREIL_BROUILLAGE.new()
	_appareil.name = "BrouillageVue"
	add_child(_appareil)


## (Re)construit l'arme du banc et pose son cookie sur la torche. Appelé au
## démarrage et aux seuls changements de cône — jamais dans `_rendre`.
func _poser_arme() -> void:
	_arme = WeaponData.new()
	_arme.name = "Banc"
	_arme.torch_cookie = "pistolet"
	_arme.torch_angle_deg = _cone_deg
	_arme.torch_scale = _echelle_torche
	_arme.torch_brightness = 1.0
	_torche.texture = _arme.get_torch_texture()
	_torche.texture_scale = _arme.echelle_torche()


func _bloc(centre: Vector2, taille: Vector2) -> void:
	var mur := Polygon2D.new()
	mur.polygon = PackedVector2Array([
		centre + Vector2(-taille.x, -taille.y) * 0.5,
		centre + Vector2(taille.x, -taille.y) * 0.5,
		centre + Vector2(taille.x, taille.y) * 0.5,
		centre + Vector2(-taille.x, taille.y) * 0.5,
	])
	mur.color = Charte.ACIER
	mur.light_mask = 1
	_monde.add_child(mur)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = mur.polygon
	occ.occluder = poly
	_monde.add_child(occ)


## Le sol, aux deux gris de la charte — et non à deux gris inventés ici. Sous la
## nuit, on ne le voit que là où une lumière tombe : c'est tout son intérêt,
## puisqu'un faisceau qui balaie ne se VOIT balayer que s'il a une matière à
## révéler.
func _damier() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var pair := ((x < 64) == (y < 64))
			img.set_pixel(x, y, Charte.SOL_A if pair else Charte.SOL_A_ARETE)
	return ImageTexture.create_from_image(img)


func _rond(taille: int) -> ImageTexture:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var c := float(taille) * 0.5
	for x in taille:
		for y in taille:
			var r := Vector2(float(x) - c, float(y) - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, pow(maxf(1.0 - r, 0.0), 2.0)))
	return ImageTexture.create_from_image(img)


func _batir_ecran() -> void:
	# ⚠️ **Le voile passe AU-DESSUS du halo, et cet ordre est celui du jeu.**
	# `brouillage_vue` occupe les couches 1 (flou) et 2 (halo) ; en écran scindé
	# elles vivent dans le `SubViewport`, donc sous tout ce que la racine dessine
	# — dont le voile, qui est dans `ui.gd`. Poser le voile sous le halo ici
	# donnerait un rendu que le jeu ne produit jamais.
	var couche := CanvasLayer.new()
	couche.name = "CoucheVoile"
	couche.layer = 3
	add_child(couche)

	_voile = ColorRect.new()
	_voile.name = "Voile"
	_voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_VOILE
	_voile.material = _mat
	couche.add_child(_voile)

	_couche_texte = CanvasLayer.new()
	_couche_texte.name = "Texte"
	_couche_texte.layer = 4
	add_child(_couche_texte)
	_panneau = _etiquette(_couche_texte, Vector2(24, 20), Charte.T_COURANT)
	_aide = _etiquette(_couche_texte, Vector2(24, 880), Charte.T_MENTION)
	_aide.modulate = Charte.DIM
	_aide.text = _texte_aide()


## Une étiquette sur fond OPAQUE.
##
## ⚠️ **Le voile blanchit l'écran par-dessus tout**, y compris le panneau : un
## `Label` nu devient illisible exactement quand on a besoin de le lire, c'est-à-
## dire à fort éblouissement. La leçon est celle de `banc_brouillage` — un
## contraste qui dépend du voile finit toujours par céder quelque part.
func _etiquette(parent: CanvasLayer, ou: Vector2, taille: int) -> Label:
	var cadre := PanelContainer.new()
	cadre.position = ou
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := StyleBoxFlat.new()
	fond.bg_color = Charte.BACKDROP
	fond.set_content_margin_all(Charte.GAP_XS)
	fond.set_corner_radius_all(4)
	cadre.add_theme_stylebox_override("panel", fond)
	parent.add_child(cadre)

	var lab := Label.new()
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var police := Charte.police_ui(Charte.POIDS_COURANT)
	if police != null:
		lab.add_theme_font_override("font", police)
	lab.add_theme_font_size_override("font_size", taille)
	lab.add_theme_color_override("font_color", Charte.ACIER)
	cadre.add_child(lab)
	return lab


func _process(delta: float) -> void:
	if _etalonnage or _planche_active:
		return
	if not _fige:
		_temps += delta
	_bouger_eblouisseur(delta)
	_integrer(delta)
	_rendre()
	_maj_panneau()


## L'éblouisseur tourne autour du joueur, ou se pose là où va la souris.
##
## **La souris est le mode qui répond à la question du chantier.** « Le flare
## vient-il bien de la droite quand il est à droite ? » se vérifie en posant
## l'éblouisseur à droite et en regardant — pas en attendant qu'une orbite
## repasse par là.
func _bouger_eblouisseur(delta: float) -> void:
	# ⚠️ **`_planche_active` d'abord, et l'oubli a produit douze images
	# identiques.** Couper l'orbite ne veut pas dire « ne bouge plus » : ça veut
	# dire « suis la souris ». La planche posait donc son relèvement, et la
	# ligne suivante l'écrasait aussitôt par la position du curseur — les
	# quatre modes, aux trois angles, tous rendus au même endroit, et rien dans
	# les images ne le disait. C'est le prix imprimé avec chaque capture depuis
	# (relèvement demandé contre relèvement obtenu) qui l'a montré en une ligne.
	if _planche_active:
		pass
	elif _orbite:
		_angle += delta * 0.35
	else:
		# ⚠️ **La souris pilote la POSITION, pas seulement l'angle.** Elle ne
		# donnait que le cap, et la distance restait clouée sur `Z/X` : on
		# promenait le curseur, l'éblouisseur tournait sur son rail, la lumière
		# reçue ne bougeait pas d'un pouce — donc ni l'éblouissement, ni le flou,
		# ni le halo. Adrien l'a dit d'un mot : « le flou ne varie même plus en
		# fonction de ma distance ». Il ne l'avait jamais fait.
		var vers := get_global_mouse_position()
		if vers.length() > 1.0:
			_angle = vers.angle()
			_distance = clampf(vers.length(), 60.0, 900.0)
	_porteur.global_position = Vector2.RIGHT.rotated(_angle) * _distance
	# Il braque toujours sa torche sur le joueur : c'est la situation à juger,
	# pas une situation moyenne.
	# Sa silhouette tourne AVEC lui, comme dans le jeu : elle est enfant du
	# porteur, et c'est ce qu'on veut — un corps qui regarde ailleurs que sa
	# propre lampe serait le seul détail faux d'une scène qu'on juge à l'œil.
	_porteur.rotation = (_regardeur.global_position - _porteur.global_position).angle()


## L'éblouissement par le vrai chemin — le pixel du faisceau, la courbe, le
## modèle temporel. Aucune des trois étapes n'est réécrite ici.
func _integrer(delta: float) -> void:
	if not _auto:
		_dazzle = _niveau_manuel
		_regardeur.dazzle_amount = _dazzle
		return
	var avant := Vector2.RIGHT.rotated(_porteur.rotation)
	var brut := _arme.lumiere_recue(avant, _porteur.global_position,
		_regardeur.global_position)
	_dazzle = Eblouissement.integrer(_dazzle, Eblouissement.plafond_pour(brut), delta)
	_regardeur.dazzle_amount = _dazzle


func _rendre() -> void:
	if _brouillage_actif and not _etalonnage:
		_appareil.maj(_regardeur, _porteur)
	else:
		_appareil.eteindre()
	# Après `maj`, qui repose le `rect` à chaque image.
	var copie := _appareil.get_node_or_null("CoucheFlou/CopieEcran") as BackBufferCopy
	if copie != null:
		copie.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if _copie_plein_cadre \
			else BackBufferCopy.COPY_MODE_RECT

	var taille := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("mode", _mode)
	_mat.set_shader_parameter("niveau", _dazzle)
	_mat.set_shader_parameter("temps", _temps)
	_mat.set_shader_parameter("teinte", Vector3(
		Charte.HALOGENE.r, Charte.HALOGENE.g, Charte.HALOGENE.b))
	# ⚠️ **Le relèvement se prend depuis le JOUEUR vers l'ÉBLOUISSEUR.** Pris à
	# l'envers, le voile penche du côté opposé — un effet parfaitement cohérent
	# et parfaitement faux, du même genre que « l'intensité vient du regardeur,
	# la position de l'émetteur » qui a coûté une soirée au chantier brouillage.
	_mat.set_shader_parameter("relevement",
		(_porteur.global_position - _regardeur.global_position).angle())
	_mat.set_shader_parameter("aspect",
		taille.x / maxf(taille.y, 1.0))
	_mat.set_shader_parameter("lueur_tex", _lueur_tex)
	_mat.set_shader_parameter("flare_tex", _flare_tex)
	_mat.set_shader_parameter("fantome_tex", _fantome_tex)
	for nom in _val.keys():
		if nom in ENTIERS:
			_mat.set_shader_parameter(nom, int(round(float(_val[nom]))))
		else:
			_mat.set_shader_parameter(nom, float(_val[nom]))


## L'ÉTALONNAGE — le seul nombre qui compte pour la suite.
##
## Le voile est rendu seul, sur du noir pur, à éblouissement maximal ; l'image
## est relue et l'on en tire l'opacité MOYENNE et l'opacité de POINTE.
##
## ⚠️ **Sans ce relevé, la refonte allège une pénalité sans le dire.** L'aplat
## vaut 0,3 partout, donc sa moyenne EST 0,3. Un voile creusé qui culminerait à
## 0,3 en son centre vaudrait peut-être 0,08 en moyenne — soit un quart de ce
## qu'Adrien a jugé au banc le 2026-08-25. À l'œil, les deux « se ressemblent » ;
## en jeu, l'un gêne et l'autre non.
##
## Le fond est noir pur et le voile est de teinte connue : la valeur du canal
## rouge d'un pixel vaut `teinte.r × alpha`, donc l'alpha se retrouve par une
## division. Aucune formule du shader n'est réécrite — on lit ce qui a été
## dessiné, exactement comme `Vision.intensite_texture` lit le pixel du faisceau
## au lieu de recopier sa courbe.
func _etalonner() -> void:
	if _etalonnage:
		return
	_etalonnage = true
	var niveau_avant := _dazzle
	var monde_avant := _monde.visible
	_monde.visible = false
	# ⚠️ **Le panneau aussi**, et il n'est pas dans le monde. Ses deux étiquettes
	# ont un fond OPAQUE quasi noir : laissées à l'écran, elles baissent la
	# moyenne relevée d'autant de pixels qu'elles couvrent — un relevé faux, plus
	# bas que la vérité, et rien dans le nombre ne dirait d'où vient l'écart.
	var texte_avant := _couche_texte.visible
	_couche_texte.visible = false
	_appareil.eteindre()
	_mat.set_shader_parameter("niveau", 1.0)
	# Deux images : la première applique les changements, la seconde les rend.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var somme := 0.0
	var pointe := 0.0
	var n := 0
	# Un pixel sur quatre en x et en y : seize fois moins de lecture pour une
	# moyenne qui ne bouge pas de plus d'un millième sur une image aussi lisse.
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			var a: float = img.get_pixel(x, y).r / maxf(Charte.HALOGENE.r, 1e-4)
			somme += a
			pointe = maxf(pointe, a)
			n += 1
			y += 4
		x += 4
	var moyenne := somme / maxf(float(n), 1.0)
	_dernier_releve = "mode %d · moyenne %.3f · pointe %.3f  (l'aplat vaut %.3f partout)" % [
		_mode, moyenne, pointe, _val.get("facteur", Brouillage.VOILE_FACTEUR)]
	print("étalonnage — ", _dernier_releve)
	_monde.visible = monde_avant
	_couche_texte.visible = texte_avant
	_dazzle = niveau_avant
	_etalonnage = false


func _unhandled_key_input(evenement: InputEvent) -> void:
	if not (evenement is InputEventKey) or not evenement.pressed or evenement.echo:
		return
	# ⚠️ **Les chiffres se lisent sur la touche PHYSIQUE, les lettres sur
	# l'étiquette**, et ce n'est pas une incohérence. Sur l'AZERTY d'Adrien la
	# rangée de chiffres porte `& é " '` : `keycode` y rend `KEY_AMPERSAND` pour
	# `1`, et quatre touches de mode de `banc_brouillage` sont restées muettes
	# pour cette raison. En position physique, cette rangée est toujours
	# `KEY_0`…`KEY_9`. Les lettres, elles, sont l'inverse : la touche marquée `A`
	# d'un AZERTY est un `KEY_Q` physique, et lire le physique ferait mentir
	# l'aide affichée à l'écran.
	var phys: int = evenement.physical_keycode
	if phys >= KEY_0 and phys <= KEY_1:
		_mode = phys - KEY_0
		_touche_inconnue = ""
		return

	match evenement.keycode:
		KEY_TAB:
			var n := REGLAGES.size()
			var sens := -1 if evenement.shift_pressed else 1
			_reglage = posmod(_reglage + sens, n)
		KEY_LEFT: _bouger_reglage(-1)
		KEY_RIGHT: _bouger_reglage(1)
		KEY_UP:
			_auto = false
			_niveau_manuel = minf(1.0, _niveau_manuel + 0.05)
		KEY_DOWN:
			_auto = false
			_niveau_manuel = maxf(0.0, _niveau_manuel - 0.05)
		KEY_A: _auto = not _auto
		KEY_O: _orbite = not _orbite
		KEY_SPACE: _fige = not _fige
		KEY_B: _brouillage_actif = not _brouillage_actif
		KEY_Z: _distance = maxf(140.0, _distance - 20.0)
		KEY_X: _distance = minf(560.0, _distance + 20.0)
		KEY_C:
			_cone_deg = clampf(_cone_deg - 5.0, 5.0, 80.0)
			_poser_arme()
		KEY_V:
			_cone_deg = clampf(_cone_deg + 5.0, 5.0, 80.0)
			_poser_arme()
		KEY_M: _copie_plein_cadre = not _copie_plein_cadre
		KEY_E: _etalonner()
		KEY_R: _lire_defauts()
		KEY_ESCAPE:
			_transcrire()
			get_tree().quit()
		KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT, KEY_CAPSLOCK:
			# ⚠️ **Un modificateur SEUL n'est pas une touche sans effet.** Le
			# panneau annonçait « touche sans effet — étiquette 4194327 » quand
			# Adrien appuyait sur Cmd pour capturer son écran : un avertissement
			# qui se déclenche sur un geste normal apprend à ignorer les
			# avertissements.
			return
		_:
			# **Une touche qui ne fait rien ne doit pas se taire.** Le banc voisin
			# a été livré avec quatre touches muettes, et le rapport ne pouvait
			# rien dire de plus que « ça ne marche pas » : rien à l'écran ne
			# disait ce que la touche avait envoyé.
			_touche_inconnue = "touche sans effet — étiquette %d, physique %d" % [
				evenement.keycode, evenement.physical_keycode]
			return
	_touche_inconnue = ""


func _bouger_reglage(sens: int) -> void:
	var r: Array = REGLAGES[_reglage % REGLAGES.size()]
	var nom := String(r[1])
	_val[nom] = clampf(float(_val.get(nom, 0.0)) + float(r[4]) * float(sens),
		float(r[2]), float(r[3]))


func _maj_panneau() -> void:
	var r: Array = REGLAGES[_reglage % REGLAGES.size()]
	var lignes := [
		NOMS_MODE[_mode],
		"RÉGLAGE  ‹ %s  %.3f ›   (Tab / Maj+Tab)" % [r[0], float(_val.get(String(r[1]), 0.0))],
		"",
		"éblouissement  %.2f  (%s)        temps  %s" % [
			_dazzle, "mesuré" if _auto else "forcé", "FIGÉ" if _fige else "court"],
		# ⚠️ **`wrapf` et non `rad_to_deg` nu.** L'orbite ajoute sans jamais
		# retrancher : le panneau annonçait « +2949° », qui n'est pas faux mais
		# qu'aucun œil ne convertit en « en haut à gauche ». Un banc se lit d'un
		# coup d'œil ou ne se lit pas.
		"éblouisseur    %s   à %.0f px, %+.0f°" % [
			"orbite" if _orbite else "à la souris", _distance,
			wrapf(rad_to_deg(_angle), -180.0, 180.0)],
		"faisceau       cône ±%.0f°" % _cone_deg,
		"halo et flou   %s%s" % ["oui" if _brouillage_actif else "COUPÉS",
			"   ⚠ photocopie PLEIN CADRE (M) — pas ce que fait le jeu"
			if _copie_plein_cadre else "   photocopie RECT (M) — comme le jeu"],
		"textures       %s" % ("fournies (assets)" if _textures_fournies else "fabriquées ici"),
	]
	if _dernier_releve != "":
		lignes += ["", "étalonnage : " + _dernier_releve]
	if _touche_inconnue != "":
		lignes += ["", _touche_inconnue]
	_panneau.text = "\n".join(lignes)


## Ce qu'il faudra transcrire dans le shader. Un banc n'est qu'un endroit où l'on
## bouge des nombres ; la valeur retenue doit revenir dans le modèle, sinon la
## production ne fait pas ce qui a été jugé. Même règle que `Brouillage.GAIN`,
## qui vit dans le modèle et non au banc pour cette raison exacte.
func _transcrire() -> void:
	print("\n=== banc du voile — à transcrire dans voile_eblouissement.gdshader ===")
	print("mode retenu : ", NOMS_MODE[_mode])
	var noms := _val.keys()
	noms.sort()
	for nom in noms:
		if nom in ENTIERS:
			print("  uniform int %-24s = %d;" % [nom, int(round(float(_val[nom])))])
		else:
			print("  uniform float %-22s = %.4f;" % [nom, float(_val[nom])])
	if _dernier_releve == "":
		print("\n⚠ AUCUN ÉTALONNAGE — l'opacité moyenne du voile retenu est inconnue.")
		print("  L'aplat d'aujourd'hui vaut %.2f PARTOUT ; un voile creusé qui" % Brouillage.VOILE_FACTEUR)
		print("  culmine à cette valeur pèse beaucoup moins lourd. Touche E.")
	else:
		print("\nétalonnage : ", _dernier_releve)


func _texte_aide() -> String:
	return "0 témoin (l'aplat d'aujourd'hui)   1 le voile   " \
		+ "Tab choisir un réglage   ←/→ le régler\n" \
		+ "A auto/forcé   ↑/↓ niveau   O orbite / souris (la souris pose la " \
		+ "POSITION)   Espace figer le temps   Z/X distance   C/V cône\n" \
		+ "B couper halo et flou   M photocopie RECT / plein cadre   " \
		+ "E étalonner (opacité moyenne)   R remettre les défauts   " \
		+ "Échap transcrire et sortir"
