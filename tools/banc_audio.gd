## Banc de dosage du son — S2 (portée) et S3 (occlusion par les murs).
##
## **Pourquoi ce banc existe, et pourquoi il n'est pas optionnel.** Doser un
## réglage sonore en éditant une constante, relançant le jeu et rejouant une
## manche, c'est une itération par minute et une mémoire d'oreille perdue entre
## deux essais — l'oreille ne juge pas dans l'absolu, elle juge des ÉCARTS. Ce
## régime est exactement celui qui a laissé l'éblouissement non fonctionnel
## pendant deux mois sans que personne s'en aperçoive. La règle inscrite en
## feuille de route en découle : **aucun dosage n'est demandé à Adrien sans le
## moyen de l'entendre.**
##
## Ce que le banc reproduit fidèlement, et c'est la seule chose qui compte : il
## appelle `AudioManager` lui-même. Il ne recopie ni le mixage, ni le choix de
## bus, ni la portée. Un banc qui réimplémente ce qu'il mesure fait régler
## quelque chose qui n'est pas le jeu — `apercu_torche` l'a payé le 2026-08-25
## avec un repli qui imitait ce qu'il remplaçait.
##
## Lancer : godot --path . tools/banc_audio.tscn
extends Node2D

const PAS_SOURCE := 240.0
const PERIODE_PAS := 0.42

## L'arène du banc est la carte que le jeu charge par défaut, construite par le
## même `MapGeometry` : mêmes murs, même couche de collision, donc la même
## réponse au rayon d'occlusion que pendant une manche.
var _grille: Vector2i = Vector2i(20, 20)
var _source: Node2D
var _oreille_porteur: Node2D
var _etiquette: Label
var _minuteur: float = 0.0
var _son_courant: String = "footstep"
var _auto: bool = true

## L'A/B : le réglage mis de côté, et celui qu'on écoute. Comparer, c'est
## revenir — un réglage jugé sans son prédécesseur immédiat est jugé contre un
## souvenir.
var _memoire := {}

## ============================================================================
## S6 — LES TROIS FAÇONS D'ÉCOUTER UN ÉCRAN PARTAGÉ
## ============================================================================
##
## En « 1v1 écrans scindés », **deux joueurs partagent une seule paire
## d'enceintes**. Toute oreille posée sur l'un renseigne l'autre depuis une tête
## qui n'est pas la sienne. Trois issues, et c'est un choix de jeu, pas un
## réglage — d'où ce banc plutôt qu'une décision au raisonnement.
##
## - **POINT_FIXE** — ce que fait le jeu aujourd'hui : aucun auditeur, Godot
##   retombe sur le centre de l'écran virtuel. Symétrique donc équitable, mais le
##   panoramique dit la position **sur la carte** et non par rapport à soi : une
##   information fausse plutôt qu'absente.
## - **MILIEU** — une oreille au milieu des deux joueurs. Symétrique aussi, et
##   elle dit quelque chose de vrai : la position relative au **centre du duel**.
## - **SOMME** — une oreille par joueur, chacune sur sa vue. **C'est le
##   comportement natif du moteur** : `AudioStreamPlayer2D` boucle sur tous les
##   viewports auditeurs de son monde et **somme une sortie par viewport**. Le
##   plus proche l'emporte tout seul, sa copie étant simplement plus forte —
##   aucun arbitrage à écrire.
##
## ⚠️ **Ce que le mode SOMME casse, et il faut l'entendre pour le juger :
## l'occlusion cesse de fonctionner.** `est_occulte` teste le trajet vers UNE
## oreille ; avec deux, il faudrait étouffer la copie de J1 sans toucher à celle
## de J2 — impossible avec une seule voix et un seul bus. Il faudrait deux voix
## par son, dans un pool de seize que les pas saturent déjà. **Ce n'est pas un
## défaut du banc, c'est la conséquence structurelle du mode**, et c'est
## probablement l'argument qui tranchera S6.
enum Ecoute { POINT_FIXE, MILIEU, SOMME }
var _mode: Ecoute = Ecoute.POINT_FIXE
var _j1: Node2D
var _j2: Node2D
var _vue_a: SubViewport
var _vue_b: SubViewport
var _oreille_a: AudioListener2D
var _oreille_b: AudioListener2D

func _ready() -> void:
	var data: Dictionary = MapData.get_selected()
	if data.is_empty():
		MapData.select_map(MapData.DEFAULT_MAP_ID)
		data = MapData.get_selected()
	_grille = MapCodec.get_grid_size(data)
	MapGeometry.build_collisions(data, self)
	AudioManager.accorder_a_la_carte(_grille, CandelaTileSet.TILE_SIZE)

	var centre := Vector2(_grille) * Vector2(CandelaTileSet.TILE_SIZE) * 0.5

	# Le porteur d'oreille tient lieu de joueur. `poser_oreille` reparente le
	# pool sur SON PARENT : il lui en faut donc un, comme `Players` en jeu.
	_oreille_porteur = Node2D.new()
	_oreille_porteur.name = "PorteurOreille"
	add_child(_oreille_porteur)
	var tete := Node2D.new()
	tete.name = "Tete"
	tete.global_position = centre
	_oreille_porteur.add_child(tete)
	AudioManager.poser_oreille(tete)

	# Les deux joueurs du banc. En mode MILIEU, la tête d'`AudioManager` se pose
	# entre eux ; en mode SOMME, chacun porte sa propre oreille.
	_j1 = Node2D.new()
	_j1.name = "J1"
	_j1.global_position = centre + Vector2(-260, 120)
	add_child(_j1)
	_j2 = Node2D.new()
	_j2.name = "J2"
	_j2.global_position = centre + Vector2(260, -120)
	add_child(_j2)

	# Deux vues qui PARTAGENT le monde du banc — exactement ce que fait
	# `game_state.gd:309` avec `vp2.world_2d = vp1.world_2d`. Elles ne rendent
	# rien : seule leur qualité d'auditrices nous intéresse, et **l'écoute suit le
	# viewport auquel le listener est attaché, pas celui qui rend.**
	for nom in ["VueA", "VueB"]:
		var v := SubViewport.new()
		v.name = nom
		v.world_2d = get_world_2d()
		v.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(v)
		var porte := Node2D.new()
		v.add_child(porte)
		var o := AudioListener2D.new()
		porte.add_child(o)
		if nom == "VueA":
			_vue_a = v
			_oreille_a = o
		else:
			_vue_b = v
			_oreille_b = o

	_source = Node2D.new()
	_source.name = "Source"
	_source.global_position = centre + Vector2(300, 0)
	add_child(_source)

	var cam := Camera2D.new()
	cam.global_position = centre
	cam.zoom = Vector2(0.75, 0.75)
	add_child(cam)
	cam.make_current()

	var couche := CanvasLayer.new()
	add_child(couche)
	_etiquette = Label.new()
	_etiquette.position = Vector2(16, 12)
	_etiquette.add_theme_font_size_override("font_size", 15)
	couche.add_child(_etiquette)
	AudioManager.appliquer_force_occlusion(AudioManager.force_occlusion)
	_appliquer_mode()
	_memoriser()

## Pose l'écoute demandée. Idempotente : rejouée à chaque changement de mode et à
## chaque déplacement des joueurs.
##
## **Le point qui ne se devine pas :** la racine est auditrice par défaut
## (`SceneTree` la déclare telle au démarrage). En mode SOMME il faut donc la
## **couper**, sinon une TROISIÈME sortie s'ajoute aux deux — celle du point
## fixe, c'est-à-dire précisément le défaut qu'on cherche à quitter, mêlé au
## reste et parfaitement audible.
func _appliquer_mode() -> void:
	var racine := get_tree().root
	match _mode:
		Ecoute.POINT_FIXE:
			AudioManager.rendre_oreille()
			racine.audio_listener_enable_2d = true
			_vue_a.audio_listener_enable_2d = false
			_vue_b.audio_listener_enable_2d = false
		Ecoute.MILIEU:
			_vue_a.audio_listener_enable_2d = false
			_vue_b.audio_listener_enable_2d = false
			racine.audio_listener_enable_2d = true
			var tete := _tete()
			if tete != null:
				tete.global_position = (_j1.global_position + _j2.global_position) * 0.5
				AudioManager.poser_oreille(tete)
		Ecoute.SOMME:
			AudioManager.rendre_oreille()
			racine.audio_listener_enable_2d = false
			_oreille_a.global_position = _j1.global_position
			_oreille_b.global_position = _j2.global_position
			_vue_a.audio_listener_enable_2d = true
			_vue_b.audio_listener_enable_2d = true
			_oreille_a.make_current()
			_oreille_b.make_current()

## Le dernier verdict d'occlusion, calculé en physique et relu partout ailleurs.
##
## **Sans ce cache, le banc ne testait rien.** Il interrogeait l'occlusion depuis
## `_process` — pour dessiner, pour l'affichage, pour jouer — et un rayon ne se
## lance QUE pendant une frame de physique : chaque appel tombait sur le repli
## « je ne sais pas, donc je ne retire rien ». Les sons partaient tous en direct,
## l'écran affichait « mur entre les deux : non » à travers un mur épais, et le
## test d'occlusion était incompréhensible parce qu'il n'avait pas lieu.
##
## **Le compteur de replis a révélé le défaut à l'écran, avant tout diagnostic :
## 29 286 replis en une poignée de secondes.** C'est exactement ce pour quoi il
## avait été écrit — un repli qui ne se distingue pas de la réussite déplace le
## diagnostic au lieu de dégrader le service. Sans lui, on aurait cherché le
## défaut dans le bus, le mixage ou le masque de collision.
##
## À noter, parce que ça aurait pu être bien pire : **le jeu, lui, était sain.**
## Les pas et les tirs partent de `_physics_process` (`player.gd`), donc
## l'occlusion s'y calcule pour de bon. Le défaut était dans l'outil de mesure,
## pas dans ce qu'il mesure — un banc qui reproduit en panne le défaut qu'il
## traque, piège déjà consigné le 2026-08-24.
var _occulte: bool = false

func _physics_process(delta: float) -> void:
	_suivre_les_joueurs()
	# En mode SOMME, `est_occulte` n'a aucune oreille unique à interroger : il
	# rend `false`, et l'affichage le dit en clair plutôt que de laisser croire
	# qu'aucun mur ne s'interpose.
	_occulte = AudioManager.est_occulte(_source.global_position)
	if _auto_un_coup:
		_auto_un_coup = false
		_jouer()
	if _auto:
		_minuteur -= delta
		if _minuteur <= 0.0:
			_minuteur = PERIODE_PAS
			_jouer()

func _process(delta: float) -> void:
	_deplacer_source(delta)
	queue_redraw()
	AudioManager.poser_limiteur()
	_suivre_crete()
	_etiquette.text = _texte()

## Les oreilles suivent les joueurs qu'on déplace, sans quoi le mode se réglerait
## une fois pour toutes à l'ouverture du banc.
func _suivre_les_joueurs() -> void:
	match _mode:
		Ecoute.MILIEU:
			var tete := _tete()
			if tete != null:
				tete.global_position = (_j1.global_position + _j2.global_position) * 0.5
		Ecoute.SOMME:
			_oreille_a.global_position = _j1.global_position
			_oreille_b.global_position = _j2.global_position
		_:
			pass

## La souris place les deux points, et c'est mieux que des flèches.
##
## Les flèches servent désormais aux molettes ; mais surtout, **on juge une
## spatialisation en pointant**, pas en pilotant un curseur à vitesse constante.
## Bouton gauche : la source suit. Bouton droit : l'oreille se déplace — c'est ce
## qui permet d'écouter la même source depuis les deux côtés d'un mur sans rien
## déplacer d'autre.
##
## Relâché, rien ne bouge : un réglage se juge sur un son immobile, en tournant
## une seule molette à la fois.
func _deplacer_source(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_source.global_position = get_global_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_j1.global_position = get_global_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_j2.global_position = get_global_mouse_position()

## Une touche est lue hors physique : jouer tout de suite ferait partir le son en
## direct, quel que soit le mur. On attend le prochain tic — un vingtième de
## seconde que l'oreille ne remarque pas, et le verdict est vrai.
func _jouer_au_prochain_tic() -> void:
	_minuteur = 0.0
	_auto_un_coup = true

var _auto_un_coup: bool = false

## Ce qu'il faut REELLEMENT passer a `play_sfx_2d` pour ce son.
##
## ⚠️ **Toutes les cles de barème ne sont pas des cles de `SOUNDS`.** Le
## percuteur est indexe `"weapon_dry"` dans `PORTEE_RELATIVE` et
## `NIVEAU_RELATIF`, mais il se joue par CHEMIN (`weapon_dry_<arme>.wav`) — la
## cle seule ne resout aucun flux. Le banc affichait donc 0,55 / -9 dB, des
## chiffres justes, pour un son qui ne sortait pas. **Des valeurs plausibles sur
## un silence** : la troisieme forme du meme defaut, apres « l'outil ne mesure
## pas le jeu » et « la molette ne pilote que le banc ».
func _flux_courant() -> Variant:
	if _son_courant == "weapon_dry":
		return AudioManager.chemin_percuteur("pistolet")
	return _son_courant

func _jouer() -> void:
	AudioManager.play_sfx_2d_random_pitch(_flux_courant(), _source.global_position,
		0.95, 1.05)

## Le dessin dit ce que l'oreille ne peut pas prouver : où est le rayon, et s'il
## touche un mur. Sans lui, un son occulté et un son lointain se ressemblent, et
## on doserait l'un en croyant régler l'autre.
func _draw() -> void:
	var tete := _tete()
	if tete == null:
		return
	var couleur := Charte.ROUGE if _occulte else Charte.ACIER
	if _mode == Ecoute.SOMME:
		# Deux traits, deux oreilles : on voit d'un coup laquelle est la plus
		# proche, donc laquelle domine la somme.
		draw_line(_source.global_position, _j1.global_position, Charte.BLEU, 2.0)
		draw_line(_source.global_position, _j2.global_position, Charte.ROUGE, 2.0)
	else:
		draw_line(_source.global_position, tete.global_position, couleur, 2.0)
		draw_circle(tete.global_position, 9.0, Charte.AMBRE)
	draw_circle(_j1.global_position, 9.0, Charte.BLEU)
	draw_circle(_j2.global_position, 9.0, Charte.ROUGE)
	draw_circle(_source.global_position, 7.0, couleur)
	var portee: float = AudioManager.portee_courante(_son_courant)
	draw_arc(tete.global_position, portee, 0.0, TAU, 96, couleur, 1.0)

func _tete() -> Node2D:
	if _oreille_porteur.get_child_count() == 0:
		return null
	return _oreille_porteur.get_child(0) as Node2D

## La crete de Master, en dBFS, et depuis combien de temps elle n'a pas depasse.
##
## **C'est le seul juge fiable du filet.** Un limiteur qui mord sur un
## transitoire de tir ne s'entend pas comme une distorsion : il s'entend comme
## « la musique a hoquete », et on cherche le defaut ailleurs. Le temoin dit ce
## que l'oreille ne peut pas prouver.
var _crete_max: float = -99.0
var _crete_depuis: float = 0.0

func _suivre_crete() -> void:
	var idx := AudioServer.get_bus_index(AudioManager.BUS_MASTER)
	if idx == -1:
		return
	var c := maxf(AudioServer.get_bus_peak_volume_left_db(idx, 0),
		AudioServer.get_bus_peak_volume_right_db(idx, 0))
	if c > _crete_max:
		_crete_max = c
		_crete_depuis = 0.0
	else:
		_crete_depuis += get_process_delta_time()

func _texte_filet() -> String:
	var mord := AudioManager.reveille_le_filet(
		AudioManager.PIC_MAX_DEPOT_DB, AudioManager.marge_db, AudioManager.plafond_db)
	return "marge %+.1f dB · plafond %+.1f dB · crête %+.1f dBFS · %s" % [
		AudioManager.marge_db, AudioManager.plafond_db, _crete_max,
		"⚠ MORD SUR UN SON SEUL" if mord else "filet muet sur un son seul"]

func _texte() -> String:
	var tete := _tete()
	var dist := 0.0 if tete == null else _source.global_position.distance_to(tete.global_position)
	var portee: float = AudioManager.portee_courante(_son_courant)
	var lignes := [
		"BANC AUDIO — dosage S2 (portée) et S3 (occlusion)",
		"",
		"  CLIC GAUCHE : source · CLIC DROIT : oreille    ↑/↓ portée globale  %.2f" % AudioManager.facteur_portee,
		"  1 pas · 2 tir · 3 impact mur · 0 percuteur     ←/→ courbe          %.2f" % AudioManager.courbe_distance,
		"  4/5 niveau du son · 6/7 portée du son          8/9 force du mur    %.2f" % AudioManager.force_occlusion,
		"  ESPACE jouer · TAB auto (%s) · O occlusion (%s)" % [
			"ON" if _auto else "OFF",
			"ON" if AudioManager.occlusion_active else "OFF"],
		"  X mémoriser · C comparer · ÉCHAP quitter",
		"  M/P marge du filet · L/K plafond              %s" % _texte_filet(),
		"  CLIC DROIT J1 · CLIC MILIEU J2 · E : écoute      %s" % _nom_mode(),
		"      %s" % _detail_mode(),
		"",
		"  LES QUATRE SONS, tels qu'ils sont dosés en ce moment :",
		"    %s pas          niveau %+6.1f dB   portée %5.0f px  %s" % [
			"▶" if _son_courant == "footstep" else " ",
			AudioManager.niveau_dose("footstep"), AudioManager.portee_courante("footstep"),
			_aveu_de_bareme("footstep")],
		"    %s tir          niveau %+6.1f dB   portée %5.0f px  %s" % [
			"▶" if _son_courant == "shoot" else " ",
			AudioManager.niveau_dose("shoot"), AudioManager.portee_courante("shoot"),
			_aveu_de_bareme("shoot")],
		"    %s impact mur   niveau %+6.1f dB   portée %5.0f px  %s" % [
			"▶" if _son_courant == "wall_impact" else " ",
			AudioManager.niveau_dose("wall_impact"), AudioManager.portee_courante("wall_impact"),
			_aveu_de_bareme("wall_impact")],
		"    %s percuteur    niveau %+6.1f dB   portée %5.0f px  %s" % [
			"▶" if _son_courant == "weapon_dry" else " ",
			AudioManager.niveau_dose("weapon_dry"), AudioManager.portee_courante("weapon_dry"),
			_aveu_de_bareme("weapon_dry")],
		"",
		"  son                  %s" % _son_courant,
		"  distance             %5.0f px" % dist,
		"  portée de ce son     %5.0f px   (diagonale carte %.0f × relative %.2f × facteur %.2f)" % [
			portee, AudioManager.portee_carte(),
			AudioManager.portee_dosee(_son_courant), AudioManager.facteur_portee],
		"  coupure du mur       %5.0f Hz  ·  perte %.1f dB" % [
			AudioManager.coupure_occlusion_pour(AudioManager.force_occlusion),
			AudioManager.OCCLUSION_PERTE_MAX_DB * AudioManager.force_occlusion],
		"  atténuation estimée  %s" % _db_estime(dist, portee),
		"  mur entre les deux   %s" % ("OUI — bus SFX_Occlus" if _occulte else "non — bus SFX"),
		"  replis hors physique %d" % AudioManager.occlusions_hors_frame,
		"",
		"  mémoire : %s" % _texte_memoire(),
	]
	return "\n".join(lignes)

## L'atténuation que Godot appliquera, en décibels — la même formule que le
## moteur, écrite ici pour être LUE, pas pour être appliquée. C'est un afficheur,
## jamais une source de vérité : le son qui sort reste celui d'`AudioManager`.
func _db_estime(dist: float, portee: float) -> String:
	if dist >= portee:
		return "silence (hors portée)"
	var lineaire: float = pow(1.0 - dist / portee, AudioManager.courbe_distance)
	if lineaire <= 0.0001:
		return "silence"
	return "%.1f dB" % (20.0 * (log(lineaire) / log(10.0)))

## Dit en clair qu'un son n'est PAS au barème, donc qu'il affiche des valeurs
## par défaut et non les siennes.
##
## **Sans cet aveu, on doserait une valeur qui n'est pas celle du jeu.** Le
## percuteur est câblé dans un worktree voisin qui n'a pas encore atterri : tant
## qu'il n'est pas là, ses lignes de `PORTEE_RELATIVE` et `NIVEAU_RELATIF`
## n'existent pas ici, et le banc montre 1,0 × diagonale à 0 dB. C'est
## exactement la confusion que ce banc a déjà payée — l'outil montrait une chose
## et le jeu en jouait une autre — et elle ne se voit pas : un chiffre par défaut
## ressemble à un chiffre choisi.
func _aveu_de_bareme(cle: String) -> String:
	if not AudioManager.PORTEE_RELATIVE.has(cle):
		return "⚠ pas au barème — valeurs par défaut"
	# **Et surtout : le fichier existe-t-il ?** Un son au barème mais sans flux
	# affiche des chiffres justes et ne sort pas. C'est la regle du depot
	# — cabler, taire, diagnostiquer — dont il ne restait que les deux premiers
	# tiers : le banc fait enfin le troisieme.
	var flux: Variant = AudioManager.chemin_percuteur("pistolet") if cle == "weapon_dry" else cle
	if AudioManager.get_audio_stream(flux) == null:
		return "⚠ AUCUN FICHIER — muet"
	return ""

func _nom_mode() -> String:
	match _mode:
		Ecoute.POINT_FIXE: return "POINT FIXE (le jeu aujourd'hui)"
		Ecoute.MILIEU: return "MILIEU des deux joueurs"
		_: return "SOMME — une oreille par joueur"

func _detail_mode() -> String:
	match _mode:
		Ecoute.POINT_FIXE:
			return "le panoramique dit où le son est SUR LA CARTE, pas par rapport à vous"
		Ecoute.MILIEU:
			return "une image cohérente, centrée sur le duel"
		_:
			return "le plus proche domine — mais L'OCCLUSION NE FONCTIONNE PLUS (une voix, deux oreilles)"

func _memoriser() -> void:
	_memoire = {
		"facteur": AudioManager.facteur_portee,
		"courbe": AudioManager.courbe_distance,
		"occlusion": AudioManager.occlusion_active,
		"force": AudioManager.force_occlusion,
	}

func _texte_memoire() -> String:
	if _memoire.is_empty():
		return "(vide)"
	return "facteur %.2f · courbe %.2f · mur %.2f · occlusion %s" % [
		_memoire["facteur"], _memoire["courbe"], _memoire.get("force", 0.0),
		"ON" if _memoire["occlusion"] else "OFF"]

func _comparer() -> void:
	if _memoire.is_empty():
		return
	var f := AudioManager.facteur_portee
	var c := AudioManager.courbe_distance
	var o := AudioManager.occlusion_active
	var fo := AudioManager.force_occlusion
	AudioManager.facteur_portee = _memoire["facteur"]
	AudioManager.courbe_distance = _memoire["courbe"]
	AudioManager.occlusion_active = _memoire["occlusion"]
	AudioManager.appliquer_force_occlusion(_memoire.get("force", fo))
	_memoire = {"facteur": f, "courbe": c, "occlusion": o, "force": fo}

## Les touches sont lues par leur POSITION PHYSIQUE, pas par leur étiquette.
##
## **Le banc était injouable sur le clavier d'Adrien, qui est en AZERTY.** Sur
## cette disposition la rangée du haut produit `&`, `é`, `"` sans Maj : un
## `match` sur `keycode` recevait `KEY_AMPERSAND` et n'a jamais vu `KEY_1`. Rien
## n'était en erreur — les touches ne faisaient simplement rien, ce qui se lit
## comme un banc cassé.
##
## `physical_keycode` désigne l'emplacement sur un clavier US, quelle que soit la
## disposition : la touche en haut à gauche de la rangée des chiffres rend
## `KEY_1` en AZERTY comme en QWERTY, **sans Maj**.
##
## Reste un piège que la position ne règle pas : une lettre change de place d'une
## disposition à l'autre (le `W` physique est le `Z` d'un AZERTY, le `A` physique
## son `Q`). Les touches retenues ici sont donc **celles qui ne bougent pas** —
## `O`, `X`, `C`, `B`, les flèches, Tab, Espace, Échap — et l'affichage nomme ce
## qu'Adrien a réellement sous les doigts. La disposition d'un banc n'est pas un
## détail de confort : un outil de dosage qu'on ne peut pas piloter ne dose rien.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_UP: AudioManager.facteur_portee = clampf(AudioManager.facteur_portee + 0.05, 0.1, 4.0)
		KEY_DOWN: AudioManager.facteur_portee = clampf(AudioManager.facteur_portee - 0.05, 0.1, 4.0)
		KEY_LEFT: AudioManager.courbe_distance = clampf(AudioManager.courbe_distance - 0.1, 0.2, 6.0)
		KEY_RIGHT: AudioManager.courbe_distance = clampf(AudioManager.courbe_distance + 0.1, 0.2, 6.0)
		KEY_O: AudioManager.occlusion_active = not AudioManager.occlusion_active
		KEY_1: _son_courant = "footstep"
		KEY_2: _son_courant = "shoot"
		KEY_3: _son_courant = "wall_impact"
		# Le percuteur a vide (V4.4). **Il ne se juge pas seul, il se juge contre
		# les pas** — les deux disent « je suis la » a courte portee, et la seule
		# question qui compte est laquelle des deux trahit le plus. L'ordre a
		# tenir sous la molette, propose par la session DA3 qui l'a cable : plus
		# discret qu'un tir de loin, plus net qu'un pas de pres. C'est un geste
		# DELIBERE, pas une consequence du deplacement.
		KEY_0: _son_courant = "weapon_dry"
		# 4/5 et 6/7 dosent LE SON COURANT, pas l'ensemble. C'est ce qui manquait
		# pour regler des RAPPORTS : « les tirs plus forts que le reste, les pas
		# beaucoup plus attenues » ne se dose pas avec une molette globale.
		KEY_4: AudioManager.doser_niveau(_son_courant,
			AudioManager.niveau_dose(_son_courant) - 1.0)
		KEY_5: AudioManager.doser_niveau(_son_courant,
			AudioManager.niveau_dose(_son_courant) + 1.0)
		KEY_6: AudioManager.doser_portee(_son_courant,
			AudioManager.portee_dosee(_son_courant) - 0.05)
		KEY_7: AudioManager.doser_portee(_son_courant,
			AudioManager.portee_dosee(_son_courant) + 0.05)
		# 8/9 : a quel point un mur etouffe. UNE molette pour la coupure et la
		# perte de niveau, parce que c'est une seule dimension perceptive.
		KEY_8: AudioManager.appliquer_force_occlusion(AudioManager.force_occlusion - 0.05)
		KEY_9: AudioManager.appliquer_force_occlusion(AudioManager.force_occlusion + 0.05)
		# DA3.9 — la marge et le plafond du filet de sortie. **Le temoin de crete
		# compte plus que les molettes** : il dit si le filet mord, ce qu'aucune
		# oreille ne sait juger de facon fiable sur un transitoire de tir.
		KEY_M: AudioManager.marge_db = clampf(AudioManager.marge_db - 0.5, -12.0, 0.0)
		KEY_P: AudioManager.marge_db = clampf(AudioManager.marge_db + 0.5, -12.0, 0.0)
		KEY_L: AudioManager.plafond_db = clampf(AudioManager.plafond_db - 0.1, -6.0, 0.0)
		KEY_K: AudioManager.plafond_db = clampf(AudioManager.plafond_db + 0.1, -6.0, 0.0)
		KEY_TAB: _auto = not _auto
		KEY_X: _memoriser()
		KEY_C: _comparer()
		KEY_SPACE: _jouer_au_prochain_tic()
		KEY_E:
			_mode = ((_mode + 1) % 3) as Ecoute
			_appliquer_mode()
		KEY_ESCAPE:
			# La racine redevient auditrice en partant : le mode SOMME la coupe,
			# et la laisser coupée derrière soi rendrait muet tout ce qui joue
			# hors match — menus compris — sans qu'aucune erreur ne le dise.
			get_tree().root.audio_listener_enable_2d = true
			get_tree().quit()
