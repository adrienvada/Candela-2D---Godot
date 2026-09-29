extends SceneTree

## Les enveloppes de sons (`enveloppes_sons.gd`) suivent les WAV du jeu.
## Lancer : godot --headless --path . --script res://tools/test_enveloppes_sons.gd
##
## Chantier SON VISIBLE (0.8.0), Adrien, 2026-09-29 : « il faudrait que les liserés
## s'animent en fonction du son ». Le liseré lit l'enveloppe du fichier joué dans une table
## PRÉCALCULÉE hors ligne (`tools/enveloppes_sons.py`) : les WAV sont importés en QOA, donc
## illisibles au jeu, et un export ne contient pas les sources.
##
## Une table précalculée peut MENTIR sans rien casser : un son remplacé sans relancer le
## script animerait le liseré sur la forme de l'ancien, un son ajouté sans enveloppe
## retomberait sur la durée par sorte. Rien ne rougirait — c'est exactement ce que cette
## suite guette :
##
## - la table couvre EXACTEMENT les WAV de `sfx/` et `weapons/` que le jeu peut jouer en
##   positionnel (hors interface, décompte, acouphènes, ambiance, torche) ;
## - **chaque famille que le liseré dessine a toutes ses variantes dans la table** — lues
##   dans `AudioManager`, pas dans une liste recopiée ici ;
## - l'empreinte (taille + SHA-256) de chaque source est celle de la table : un WAV changé
##   demande « régénérer avec tools/enveloppes_sons.py » ;
## - la durée de la table est celle du flux que le moteur charge, et le chemin du flux est
##   la clé de la table (c'est ce que `AudioManager` annonce au liseré).

const SV := preload("res://son_visible.gd")

## Les WAV qui ne se jouent jamais en positionnel : la même liste que `EXCLUS` de
## `tools/enveloppes_sons.py` — les deux se contrôlent par l'égalité des ensembles.
const EXCLUS: Array[String] = ["ui_", "count_", "button_click", "tinnitus_", "ambience_", "torch_"]
const DOSSIERS: Array[String] = ["res://assets/audio/sfx/", "res://assets/audio/weapons/"]
const ARMES: Array[String] = ["pistolet", "fusil", "pompe", "arbalete"]
const REGENERER := "régénérer avec tools/enveloppes_sons.py"

var _failures := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ENVELOPPES DE SONS — la table suit les WAV ===")
	await process_frame
	var audio := root.get_node("AudioManager")
	var table: Dictionary = SV.Enveloppes.ENVELOPPES
	_couverture_des_fichiers(table)
	_couverture_de_l_audio(audio, table)
	_empreintes(table)
	_flux_du_moteur(audio, table)
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec — %s" % [_failures, REGENERER])
	quit(1 if _failures > 0 else 0)


func _exclu(nom: String) -> bool:
	for p in EXCLUS:
		if nom.begins_with(p):
			return true
	return false


## Les WAV que le script couvre : ceux de `sfx/` et `weapons/`, hors exclusions.
func _wav_attendus() -> Dictionary:
	var trouves := {}
	for dossier in DOSSIERS:
		for f in DirAccess.get_files_at(dossier):
			if f.ends_with(".wav") and not _exclu(f):
				trouves[dossier + f] = true
	return trouves


func _couverture_des_fichiers(table: Dictionary) -> void:
	print("\n--- La table couvre exactement les WAV positionnels du dépôt ---")
	var attendus := _wav_attendus()
	_check("le dépôt a des WAV positionnels à couvrir (%d)" % attendus.size(), attendus.size() >= 50)
	var sans_enveloppe: Array = []
	for chemin in attendus:
		if not table.has(chemin):
			sans_enveloppe.append(chemin.get_file())
	_check("aucun WAV positionnel sans enveloppe — %s" % REGENERER, sans_enveloppe.is_empty(), str(sans_enveloppe))
	var en_trop: Array = []
	for chemin in table:
		if not attendus.has(chemin):
			en_trop.append(String(chemin).get_file())
	_check("aucune enveloppe pour un fichier qui n'existe plus ou qui ne se joue pas — %s" % REGENERER,
		en_trop.is_empty(), str(en_trop))


## Les fichiers qu'`AudioManager` peut jouer sous chaque famille que le liseré dessine.
func _sons_dessines(audio: Node) -> Dictionary:
	var consts: Dictionary = audio.get_script().get_script_constant_map()
	var sons := {}   # chemin ou clé → famille
	for cle in consts["SOUNDS"]:
		var chemin := String(consts["SOUNDS"][cle])
		if chemin.ends_with(".wav"):
			sons[String(cle)] = audio.famille_de(String(cle))
	for fam in consts["VARIANTES_SFX"]:
		for i in int(consts["VARIANTES_SFX"][fam]):
			sons[audio.chemin_variante(fam, i + 1)] = String(fam)
	for slug in ARMES:
		for v in int(consts["VARIANTES_TIR"]):
			sons[audio.chemin_tir(slug, v + 1)] = "shoot"
		sons[audio.chemin_percuteur(slug)] = "weapon_dry"
	return sons


func _dessine(fam: String) -> bool:
	return SV.CATEGORIE_DE_FAMILLE.has(fam) or fam.begins_with(SV.PREFIXE_GADGET)


func _couverture_de_l_audio(audio: Node, table: Dictionary) -> void:
	print("\n--- Chaque son que le liseré dessine a son enveloppe ---")
	var sons := _sons_dessines(audio)
	var vus := 0
	var sans: Array = []
	for cle in sons:
		if not _dessine(String(sons[cle])):
			continue
		vus += 1
		var flux: AudioStream = audio.get_audio_stream(cle)
		if flux == null:
			sans.append("%s (le moteur ne le charge pas)" % cle)
			continue
		if not table.has(flux.resource_path):
			sans.append("%s → %s" % [cle, flux.resource_path])
	_check("des sons dessinés à vérifier (%d)" % vus, vus >= 50)
	_check("chacun est chargé par le moteur SOUS un chemin que la table connaît — %s" % REGENERER,
		sans.is_empty(), str(sans))
	# Les familles muettes ne dessinent rien : pas d'enveloppe exigée, mais pas de piège non plus.
	for fam in SV.FAMILLES_MUETTES:
		_check("la famille muette « %s » ne dessine rien" % fam, SV.categorie_de(fam) == -1)


func _empreintes(table: Dictionary) -> void:
	print("\n--- Chaque source est celle que la table a vue (taille + SHA-256) ---")
	var manquants: Array = []
	var changes: Array = []
	for chemin in table:
		if not FileAccess.file_exists(chemin):
			manquants.append(String(chemin).get_file())
			continue
		var e: Dictionary = table[chemin]
		var taille := FileAccess.get_file_as_bytes(chemin).size()
		if taille != int(e["taille"]) or FileAccess.get_sha256(chemin) != String(e["sha256"]):
			changes.append(String(chemin).get_file())
	_check("toutes les sources de la table existent", manquants.is_empty(), str(manquants))
	_check("aucune source n'a changé depuis le calcul — %s" % REGENERER, changes.is_empty(), str(changes))


func _flux_du_moteur(audio: Node, table: Dictionary) -> void:
	print("\n--- La table dit la durée du flux que le moteur joue ---")
	var ecarts: Array = []
	var testes := 0
	for chemin in table:
		var flux: AudioStream = audio.get_audio_stream(chemin)
		if flux == null:
			ecarts.append("%s : non chargé" % String(chemin).get_file())
			continue
		testes += 1
		var duree := float(table[chemin]["duree"])
		# Une image de QOA (20 ms de son) au plus : le moteur arrondit à ses blocs.
		if absf(flux.get_length() - duree) > 0.025:
			ecarts.append("%s : table %.3f s, moteur %.3f s" % [String(chemin).get_file(), duree, flux.get_length()])
	_check("%d flux chargés, tous de la durée de leur enveloppe (à 25 ms près)" % testes, ecarts.is_empty(), str(ecarts))
	# La forme de la table : le pas et la fenêtre que le générateur a écrits.
	_check("la table est au pas du modèle (10 ms)", is_equal_approx(SV.Enveloppes.PAS_S, 0.01))
	_check("… et de fenêtre 20 ms", is_equal_approx(SV.Enveloppes.FENETRE_S, 0.02))
