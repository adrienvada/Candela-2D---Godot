## Banc de MIXAGE — le niveau de chaque famille de sons, jugé à l'oreille.
##
## **Ce banc n'est pas `banc_audio`, et la différence est nette.** `banc_audio`
## règle les lois GLOBALES du son — facteur de portée, courbe de distance, force
## d'occlusion, filet de sortie — c'est-à-dire une poignée de nombres qui valent
## pour tout le jeu. Celui-ci règle le NIVEAU DE CHAQUE FAMILLE, une trentaine de
## valeurs, sur 89 fichiers. Les mélanger ferait un outil où l'on cherche.
##
## Quatre décisions d'Adrien le façonnent (2026-08-28) :
##
## - **Trois salles**, parce que trois natures de son ne se jugent pas au même
##   endroit. Un `ui_tick` réglé dans une arène ne veut rien dire : il n'a pas de
##   lieu, pas de distance, pas de mur. Une nappe ne se juge ni par son niveau ni
##   par sa portée mais par **ce qu'elle masque**.
## - **Par famille**, pas par fichier : une vingtaine de décisions au lieu de
##   quatre-vingt-neuf. C'est aussi ce qui préserve les écarts de loudness entre
##   les prises d'une même famille — décision du 2026-08-26.
## - **Le niveau seul** en salles 2 et 3 : un son d'interface et une nappe n'ont
##   pas de portée. Afficher une molette inopérante est pire que ne rien
##   afficher — on croit avoir réglé quelque chose.
## - **Écriture continue dans `user://`**, plus le vidage terminal à la sortie.
##   Une séance sur quatre-vingt-neuf sons ne tient pas en une fois, et une
##   fermeture brutale ne doit rien coûter.
##
## ⚠️ **Le banc APPELLE `AudioManager`, il ne le recopie pas.** Il ne refait ni le
## choix de bus, ni l'atténuation, ni l'occlusion, ni le tirage de variante. Un
## banc qui réimplémente ce qu'il mesure fait régler quelque chose qui n'est pas
## le jeu — `apercu_torche` l'a payé le 2026-08-25.
##
## Lancer : godot --path . tools/banc_mixage.tscn
extends Node2D

const FICHIER_SEANCE := "user://banc_mixage.json"
const PERIODE_AUTO := 1.10
const PAS_NIVEAU := 0.5
const PAS_PORTEE := 0.05

## Les familles à juger, dans l'ordre où on les rencontre.
##
## `f` est la clé de dosage — celle que `AudioManager.famille_de()` rend, et
## **c'est tout l'enjeu** : le banc dose sous ce nom, le jeu résout sous ce nom.
## Un banc qui doserait sous un autre nom serait muet sans le dire.
##
## `jeu` dit comment fabriquer un son de cette famille. Il ne rend pas une clé
## fixe mais **ce que le jeu jouerait vraiment** — un chemin de variante pour les
## familles qui en ont. C'est ainsi que le banc exerce la même résolution que la
## partie.
const FAMILLES: Array[Dictionary] = [
	# ---- Salle 1 : l'arène. Niveau ET portée. -----------------------------
	# Le repli d'avant V5.7 : il ne joue que si une variante manque, mais il PEUT
	# jouer — donc il se juge. Une famille qui peut s'entendre et qu'aucun banc
	# n'atteint est un reglage que personne ne peut plus corriger a l'oreille.
	{"f": "footstep", "salle": 1, "titre": "Pas — repli d'avant V5.7"},
	{"f": "footstep_a", "salle": 1, "titre": "Pas — sol A du damier"},
	{"f": "footstep_b", "salle": 1, "titre": "Pas — sol B du damier"},
	{"f": "shoot", "salle": 1, "titre": "Coup de feu (16 prises)"},
	{"f": "weapon_dry", "salle": 1, "titre": "Percuteur à vide"},
	{"f": "hit_center", "salle": 1, "titre": "Coup au but — centre"},
	{"f": "hit_edge", "salle": 1, "titre": "Coup au but — bord"},
	{"f": "flesh_impact", "salle": 1, "titre": "Impact chair (repli d'avant V4.2)"},
	{"f": "wall_impact", "salle": 1, "titre": "Balle qui MEURT sur le mur"},
	{"f": "ricochet", "salle": 1, "titre": "Balle qui REPART (fusil)"},
	{"f": "shell", "salle": 1, "titre": "Douille"},
	{"f": "wall_brush", "salle": 1, "titre": "Frôlement de mur"},
	{"f": "bolt_flight", "salle": 1, "titre": "Frôlement du carreau"},
	# La fusée éclairante (FU1-FU2.1). **Le rebond et l'atterrissage sont deux
	# familles et non une**, pour la raison même qui sépare `ricochet` de
	# `wall_impact` : le rebond dit « la lumière va encore bouger », l'atterrissage
	# dit « c'est ici, définitivement ». Dans un jeu dont la seule information est
	# la lumière, savoir si l'éclairage est stabilisé change ce qu'on fait dans la
	# seconde.
	{"f": "fusee_lancer", "salle": 1, "titre": "Fusée — mise à feu"},
	{"f": "fusee_rebond", "salle": 1, "titre": "Fusée — rebond (elle bouge encore)"},
	{"f": "fusee_atterrit", "salle": 1, "titre": "Fusée — elle se pose (définitif)"},
	{"f": "fusee_eteinte", "salle": 1, "titre": "Fusée — extinction (piétinée ou abattue)"},
	# ---- Salle 2 : l'interface. Niveau seul. ------------------------------
	{"f": "button_click", "salle": 2, "titre": "Validation"},
	{"f": "ui_tick", "salle": 2, "titre": "Navigation"},
	{"f": "ui_ready_ping", "salle": 2, "titre": "Prêt"},
	{"f": "count", "salle": 2, "titre": "Décompte 3-2-1"},
	{"f": "ui_type_impact", "salle": 2, "titre": "Titre de fin"},
	{"f": "ui_score_pawn", "salle": 2, "titre": "Pion de score"},
	{"f": "ui_glass_break", "salle": 2, "titre": "Série brisée"},
	{"f": "ui_vhs_rewind", "salle": 2, "titre": "Rembobinage killcam"},
	{"f": "ui_keystroke", "salle": 2, "titre": "Frappe du code"},
	{"f": "ui_power_on", "salle": 2, "titre": "Connexion"},
	{"f": "voix", "salle": 2, "titre": "Annonceur (bus Speaker)"},
	{"f": "sting", "salle": 2, "titre": "Ponctuations de fin"},
	# ---- Salle 3 : les nappes. Niveau seul, jugées au MASQUAGE. -----------
	{"f": "ambience", "salle": 3, "titre": "Présence de la salle"},
	{"f": "dazzle_ringing", "salle": 3, "titre": "Acouphène d'éblouissement"},
	{"f": "tinnitus_death", "salle": 3, "titre": "Acouphène de mort"},
	# En salle 3 et pas en salle 1 : la combustion est une NAPPE continue, jouée
	# sur une voix dédiée hors du pool. Elle ne se juge donc pas à son niveau mais
	# à ce qu'elle MASQUE — et une fusée qui couvre les pas de l'adversaire n'est
	# pas un habillage, c'est une arme. C'est un arbitrage d'équilibrage, et le
	# banc est l'instrument qui le tranche.
	{"f": "fusee_combustion", "salle": 3, "titre": "Fusée — combustion (nappe)"},
]

const NOMS_SALLES := {
	1: "ARÈNE — positionnel",
	2: "INTERFACE — sans lieu",
	3: "NAPPES — jugées au masquage",
}

var _grille: Vector2i = Vector2i(20, 20)
var _centre: Vector2
var _source: Node2D
var _etiquette: Label
var _minuteur: float = 0.0
var _salle: int = 1
var _index: int = 0
var _auto: bool = true
var _juges: Dictionary = {}
var _memoire: Dictionary = {}
var _armes := ["pistolet", "fusil", "pompe", "arbalete"]

func _ready() -> void:
	var data: Dictionary = MapData.get_selected()
	if data.is_empty():
		MapData.select_map(MapData.DEFAULT_MAP_ID)
		data = MapData.get_selected()
	_grille = MapCodec.get_grid_size(data)
	MapGeometry.build_collisions(data, self)
	AudioManager.accorder_a_la_carte(_grille, CandelaTileSet.TILE_SIZE)
	AudioManager.poser_limiteur()
	_centre = Vector2(_grille) * Vector2(CandelaTileSet.TILE_SIZE) * 0.5

	# L'oreille est posée comme en jeu — sinon le panoramique et la distance
	# jugés ici ne seraient pas ceux de la partie.
	var porteur := Node2D.new()
	porteur.name = "PorteurOreille"
	add_child(porteur)
	var tete := Node2D.new()
	tete.name = "Tete"
	porteur.add_child(tete)
	tete.global_position = _centre
	AudioManager.poser_oreille(tete)

	_source = Node2D.new()
	_source.name = "Source"
	add_child(_source)
	_source.global_position = _centre + Vector2(300, 0)

	var cam := Camera2D.new()
	cam.position = _centre
	add_child(cam)
	cam.make_current()

	var couche := CanvasLayer.new()
	add_child(couche)
	_etiquette = Label.new()
	_etiquette.position = Vector2(24, 20)
	_etiquette.add_theme_font_size_override("font_size", 15)
	couche.add_child(_etiquette)

	_charger_seance()
	_aller_a_la_salle(1)

## ============================================================================
## LA SÉANCE — ÉCRITE À CHAQUE GESTE
## ============================================================================
##
## ⚠️ **À chaque geste, pas à la sortie.** Une séance de quatre-vingt-neuf sons
## ne tient pas en une fois : elle se reprend, et elle survit à une fermeture
## brutale. Un réglage qui n'existe qu'en mémoire n'est pas un réglage — c'est
## la même règle que le dépôt applique déjà aux dosages de `banc_audio`.
func _charger_seance() -> void:
	if not FileAccess.file_exists(FICHIER_SEANCE):
		return
	var f := FileAccess.open(FICHIER_SEANCE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	for cle in d.get("niveau", {}):
		AudioManager.doser_niveau(cle, float(d["niveau"][cle]))
	for cle in d.get("portee", {}):
		AudioManager.doser_portee(cle, float(d["portee"][cle]))
	for cle in d.get("juges", []):
		_juges[String(cle)] = true
	print("[banc] séance reprise : %d famille(s) déjà jugée(s)" % _juges.size())

func _ecrire_seance() -> void:
	var niveaux := {}
	var portees := {}
	for fam in FAMILLES:
		var cle: String = fam["f"]
		niveaux[cle] = AudioManager.niveau_dose(cle)
		if int(fam["salle"]) == 1:
			portees[cle] = AudioManager.portee_dosee(cle)
	var f := FileAccess.open(FICHIER_SEANCE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"niveau": niveaux, "portee": portees, "juges": _juges.keys(),
	}, "\t"))

## ============================================================================
## CE QUE LE JEU JOUERAIT VRAIMENT
## ============================================================================
##
## ⚠️ **Pas une clé fixe : ce que la partie joue.** Un banc qui jouerait
## `weapon_shoot.wav` pendant que le jeu joue `weapon_fusil_02.wav` ferait régler
## un son que personne n'entend — défaut réel, vécu jusqu'au 2026-08-28, où le
## dosage se cherchait sous le CHEMIN et non sous la famille.
## TOUS les sons qu'une famille peut produire.
##
## **Statique et exhaustive à dessein** : le banc en tire un au hasard, la suite
## les vérifie tous. Deux listes — une pour jouer, une pour tester — auraient
## garanti qu'un son échappe au contrôle le jour où on l'ajoute à une seule.
const ARMES := ["pistolet", "fusil", "pompe", "arbalete"]

static func sons_de(famille: String) -> Array[String]:
	var r: Array[String] = []
	if AudioManager.VARIANTES_SFX.has(famille):
		for i in int(AudioManager.VARIANTES_SFX[famille]):
			r.append(AudioManager.chemin_variante(famille, i + 1))
		return r
	if famille == "shoot":
		for a in ARMES:
			for i in AudioManager.VARIANTES_TIR:
				r.append(AudioManager.chemin_tir(a, i + 1))
		return r
	if famille == "weapon_dry":
		for a in ARMES:
			r.append(AudioManager.chemin_percuteur(a))
		return r
	if AudioManager.FAMILLES_DE_CLES.has(famille):
		for c in AudioManager.FAMILLES_DE_CLES[famille]:
			r.append(String(c))
		return r
	r.append(famille)
	return r

func _un_son_de(famille: String) -> String:
	var sons := sons_de(famille)
	return "" if sons.is_empty() else sons.pick_random()

func _famille_courante() -> Dictionary:
	var liste := _familles_de_la_salle()
	if liste.is_empty():
		return {}
	return liste[clampi(_index, 0, liste.size() - 1)]

func _familles_de_la_salle() -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	for f in FAMILLES:
		if int(f["salle"]) == _salle:
			r.append(f)
	return r

func _jouer() -> void:
	var fam := _famille_courante()
	if fam.is_empty():
		return
	var son := _un_son_de(String(fam["f"]))
	if son == "":
		return
	if _salle == 1:
		AudioManager.play_sfx_2d(son, _source.global_position)
	elif String(fam["f"]) == "voix":
		AudioManager.play_speaker(son)
	else:
		AudioManager.play_sfx(son)

## Salle 3 — un pas de référence SOUS la nappe.
##
## ⚠️ **C'est le seul contrôle qui juge vraiment une nappe.** Une nappe ne se
## juge pas à son niveau mais à ce qu'elle MASQUE : dans un duel où le son est la
## seule information, une ambiance qui couvre les pas de l'adversaire retire au
## joueur ce que le jeu lui donne à entendre. Le bon niveau est celui où la
## nappe s'entend et où le pas reste lisible dessous.
func _pas_de_reference() -> void:
	AudioManager.play_footstep(_source.global_position, Vector2i.ZERO)

func _process(delta: float) -> void:
	if _salle == 1:
		_source.global_position = get_global_mouse_position()
	if _auto:
		_minuteur -= delta
		if _minuteur <= 0.0:
			_minuteur = PERIODE_AUTO
			_jouer()
	_etiquette.text = _texte()

func _texte() -> String:
	var fam := _famille_courante()
	if fam.is_empty():
		return "aucune famille dans cette salle"
	var cle: String = fam["f"]
	var liste := _familles_de_la_salle()
	var lignes := [
		"SALLE %d — %s        [1] [2] [3] pour changer" % [_salle, NOMS_SALLES[_salle]],
		"",
		"  %s%s   (%d/%d)" % ["✓ " if _juges.has(cle) else "  ", fam["titre"],
			_index + 1, liste.size()],
		"  famille « %s »" % cle,
		"",
		"  NIVEAU   %+6.1f dB      ↑ / ↓" % AudioManager.niveau_dose(cle),
	]
	if _salle == 1:
		var d := _source.global_position.distance_to(_centre)
		lignes.append("  PORTÉE   %6.2f  =  %.0f px      ← / →"
			% [AudioManager.portee_dosee(cle), AudioManager.portee_courante(cle)])
		lignes.append("  la souris place la source — distance %.0f px" % d)
	else:
		lignes.append("  (pas de portée : ce son n'a pas de lieu)")
	lignes.append("")
	if _salle == 3:
		lignes.append("  [O] un PAS sous la nappe — le seul juge qui vaille")
	lignes.append("  TAB / B famille suivante-précédente · ESPACE rejouer · [V] jugée")
	lignes.append("  [X] mémoriser  [C] comparer  [N] valeur d'origine  ÉCHAP sortir")
	lignes.append("")
	lignes.append("  jugées : %d / %d" % [_juges.size(), FAMILLES.size()])
	return "\n".join(lignes)

## Touches lues par POSITION PHYSIQUE, et limitées à celles qui ne bougent pas
## d'une disposition à l'autre. Voir la note de `banc_audio.gd` : le banc y a été
## injouable en AZERTY sans qu'une seule erreur ne le dise.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var fam := _famille_courante()
	var cle: String = String(fam.get("f", ""))
	match k.physical_keycode:
		KEY_1: _aller_a_la_salle(1)
		KEY_2: _aller_a_la_salle(2)
		KEY_3: _aller_a_la_salle(3)
		KEY_UP: _regler_niveau(cle, PAS_NIVEAU)
		KEY_DOWN: _regler_niveau(cle, -PAS_NIVEAU)
		KEY_RIGHT: _regler_portee(cle, PAS_PORTEE)
		KEY_LEFT: _regler_portee(cle, -PAS_PORTEE)
		KEY_TAB: _pas_de_famille(1)
		KEY_B: _pas_de_famille(-1)
		KEY_SPACE:
			_minuteur = PERIODE_AUTO
			_jouer()
		KEY_V:
			if cle != "":
				_juges[cle] = true
				_ecrire_seance()
		KEY_N: _remettre_origine(cle)
		KEY_X: _memoriser(cle)
		KEY_C: _comparer(cle)
		KEY_O:
			if _salle == 3:
				_pas_de_reference()
		KEY_ESCAPE:
			_vider_dans_le_terminal()
			get_tree().quit()

func _aller_a_la_salle(n: int) -> void:
	_salle = n
	_index = 0
	_minuteur = 0.0

func _pas_de_famille(sens: int) -> void:
	var liste := _familles_de_la_salle()
	if liste.is_empty():
		return
	_index = posmod(_index + sens, liste.size())
	_minuteur = 0.0

func _regler_niveau(cle: String, delta_db: float) -> void:
	if cle == "":
		return
	AudioManager.doser_niveau(cle, AudioManager.niveau_dose(cle) + delta_db)
	_ecrire_seance()

## La portée ne se règle qu'en salle 1. **Le refus est silencieux à dessein** :
## l'affichage dit déjà qu'il n'y a pas de portée ici, et une molette qui répond
## là où elle n'a pas de sens ferait croire à un réglage.
func _regler_portee(cle: String, delta: float) -> void:
	if cle == "" or _salle != 1:
		return
	AudioManager.doser_portee(cle, AudioManager.portee_dosee(cle) + delta)
	_ecrire_seance()

func _remettre_origine(cle: String) -> void:
	if cle == "":
		return
	AudioManager.doser_niveau(cle, AudioManager.niveau_relatif_de(cle))
	AudioManager.doser_portee(cle, AudioManager.portee_relative_de(cle))
	_juges.erase(cle)
	_ecrire_seance()

## L'A/B. Comparer, c'est revenir — un réglage jugé sans son prédécesseur
## immédiat est jugé contre un souvenir.
func _memoriser(cle: String) -> void:
	if cle == "":
		return
	_memoire[cle] = [AudioManager.niveau_dose(cle), AudioManager.portee_dosee(cle)]

func _comparer(cle: String) -> void:
	if cle == "" or not _memoire.has(cle):
		return
	var garde: Array = [AudioManager.niveau_dose(cle), AudioManager.portee_dosee(cle)]
	var m: Array = _memoire[cle]
	AudioManager.doser_niveau(cle, m[0])
	AudioManager.doser_portee(cle, m[1])
	_memoire[cle] = garde
	_ecrire_seance()

## ============================================================================
## LA SORTIE — PRÊTE À APPLIQUER, ET HONNÊTE SUR CE QUI N'A PAS ÉTÉ JUGÉ
## ============================================================================
##
## ⚠️ **Ce qui n'a pas été entendu est listé à part.** Un bloc de trente nombres
## dont on ne sait pas lesquels ont été jugés se recopie en entier, et les
## valeurs par défaut deviennent alors des décisions que personne n'a prises.
## C'est exactement ce qui est arrivé au percuteur le 2026-08-26.
func _vider_dans_le_terminal() -> void:
	_ecrire_seance()
	var non_juges: Array[String] = []
	print("\n" + "=".repeat(70))
	print("SÉANCE DE MIXAGE — à recopier dans audio_manager.gd")
	print("=".repeat(70))
	print("\nconst NIVEAU_RELATIF: Dictionary = {")
	for fam in FAMILLES:
		var cle: String = fam["f"]
		if not _juges.has(cle):
			non_juges.append(cle)
			continue
		print("\t\"%s\": %.1f," % [cle, AudioManager.niveau_dose(cle)])
	print("}")
	print("\nconst PORTEE_RELATIVE: Dictionary = {")
	for fam in FAMILLES:
		var cle: String = fam["f"]
		if int(fam["salle"]) != 1 or not _juges.has(cle):
			continue
		print("\t\"%s\": %.2f," % [cle, AudioManager.portee_dosee(cle)])
	print("}")
	if non_juges.is_empty():
		print("\nToutes les familles ont été jugées.")
	else:
		print("\n⚠️ NON JUGÉES (%d) — elles gardent leur valeur d'origine, qui" \
			% non_juges.size())
		print("   n'a jamais été entendue contre les autres :")
		for c in non_juges:
			print("     %s" % c)
	print("\nSéance conservée dans %s — le banc reprendra ici." % FICHIER_SEANCE)
	print("=".repeat(70) + "\n")
