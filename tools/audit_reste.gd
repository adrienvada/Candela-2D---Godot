## Audit : que reste-t-il à faire, et qu'est-ce qui a glissé sans qu'on le voie ?
##
## Ce script répond mécaniquement à la question « est-ce fini ? ». Sans lui, la
## réponse dépend de qui lit la feuille de route et de ce qu'il a en tête ce
## jour-là — et une boucle de travail autonome qui s'auto-évalue à l'estime finit
## par se déclarer terminée alors qu'il reste des chantiers entiers.
##
## Il ne juge pas la qualité : il compte. Ce qu'il sait voir est étroit et sûr,
## et c'est délibéré — un audit qui prétend tout voir n'est plus cru.
##
## Ce qu'il détecte, et pourquoi chaque contrôle existe :
##
## 1. **Suites non enregistrées.** Une suite de tests présente dans `tools/` mais
##    absente de la boucle du README et de la CI ne tourne jamais. Le cas s'est
##    produit deux fois : trois fichiers à mettre à jour à la main pour une seule
##    suite ajoutée, et rien ne signale l'oubli. C'est le contrôle qui a motivé
##    ce script.
## 2. **Travail déclaré ouvert** dans la feuille de route.
## 3. **Décisions en attente d'Adrien** — elles bloquent du travail sans que
##    personne ne soit en tort.
## 4. **Ressources manquantes**, via `AssetManifest`.
##
## Sortie 0 s'il ne reste rien d'implémentable sans décision humaine, 2 sinon.
## Jamais 1 : ce n'est pas un test, il n'échoue pas, il rapporte.
##
## Lancer : godot --headless --path . --script res://tools/audit_reste.gd
extends SceneTree

const ROADMAP := "res://docs/ROADMAP.md"
const RUNNER := "res://tools/run_suites.sh"
const WORKFLOW_CI := "res://.github/workflows/tests.yml"
const TOOLS_DIR := "res://tools/"

## Suites qui ne sont pas des suites : bancs d'essai et outils.
const NOT_A_SUITE: Array[String] = [
	"test_transport", "test_online_match", "test_quit_path",
]

var _restant: int = 0
var _bloque: int = 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Les autoloads et les class_name (AssetManifest) ne sont pas encore
	# enregistrés dans `_init` — piège connu du dépôt.
	await process_frame

	print("=== Audit — que reste-t-il ? ===")
	_audit_suites()
	_audit_roadmap()
	_audit_decisions()
	_audit_assets()

	print("\n" + "—".repeat(60))
	if _restant == 0:
		print("Rien d'implémentable en attente.")
		if _bloque > 0:
			print("%d point(s) bloqué(s) sur une décision ou une ressource humaine." % _bloque)
		print("→ La boucle peut passer à la phase de proposition (voir docs/BOUCLE.md).")
	else:
		print("%d chantier(s) implémentable(s) restant(s)." % _restant)
		if _bloque > 0:
			print("%d autre(s) bloqué(s) côté humain." % _bloque)
		print("→ La boucle continue : rien à inventer tant qu'il reste à faire.")

	quit(0 if _restant == 0 else 2)

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text

# ---------------------------------------------------------------------------

## Une suite qui existe mais que personne ne lance ne protège de rien. Elle est
## pire qu'absente : elle donne l'impression d'une couverture.
func _audit_suites() -> void:
	print("\n[Suites de tests enregistrées]")
	var dir := DirAccess.open(TOOLS_DIR)
	if dir == null:
		print("  ! dossier tools/ illisible")
		return

	# Les noms de suites vivent désormais dans le lanceur, que le README et la CI
	# appellent tous deux. Un seul endroit à tenir à jour, donc un seul à auditer.
	var runner := _read(RUNNER)
	var orphelines: Array[String] = []

	for file_name in dir.get_files():
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		var suite := file_name.trim_suffix(".gd")
		if NOT_A_SUITE.has(suite):
			continue
		# Une suite avec sa propre scène se lance autrement : on la reconnaît à
		# sa présence dans la CI, quelle que soit la forme de l'appel.
		if not runner.contains(suite):
			orphelines.append(suite)

	if orphelines.is_empty():
		print("  ✓ toutes les suites sont dans tools/run_suites.sh")
	else:
		for o in orphelines:
			print("  ! absente du lanceur : ", o)
			_restant += 1

## Compte les phases et étapes encore ouvertes. On lit les marqueurs, pas la
## prose : un audit qui interprète le français se trompe.
func _audit_roadmap() -> void:
	print("\n[Feuille de route — travail ouvert]")
	var text := _read(ROADMAP)
	if text == "":
		print("  ! feuille de route illisible")
		return

	var ouverts: Array[String] = []
	for line in text.split("\n"):
		var l := String(line)
		if not (l.begins_with("## ") or l.begins_with("### ") or l.begins_with("**Étape")):
			continue
		if l.contains("🔵") or l.contains("🟡") or l.contains("EN COURS") or l.contains("À FAIRE"):
			if l.contains("✅") or l.contains("CLOSE"):
				continue
			ouverts.append(l.strip_edges().left(88))

	if ouverts.is_empty():
		print("  ✓ aucune phase ni étape marquée ouverte")
	else:
		for o in ouverts:
			print("  → ", o)
			_restant += 1

## Ce qui attend Adrien n'est pas du travail en retard : c'est du travail
## légitimement suspendu. Le distinguer évite de croire le projet en panne.
func _audit_decisions() -> void:
	print("\n[En attente d'une décision humaine]")
	var text := _read(ROADMAP)
	var compte := 0
	for line in text.split("\n"):
		var l := String(line).strip_edges()
		# Les items D1..D7 de l'étude de game feel, un par puce.
		if l.begins_with("- **D") and l.length() > 6 and l[5].is_valid_int():
			compte += 1
	if compte == 0:
		print("  ✓ aucune décision en attente")
	else:
		print("  → %d item(s) suspendus à un arbitrage (info de jeu ou coût d'images)" % compte)
		_bloque += compte

func _audit_assets() -> void:
	print("\n[Ressources]")
	var absents := AssetManifest.missing().size()
	var vides := AssetManifest.placeholders().size()
	if absents == 0 and vides == 0:
		print("  ✓ toutes les ressources attendues sont là")
		return
	print("  → %d absente(s), %d présente(s) mais vide(s)" % [absents, vides])
	print("    Aucun agent ne peut les produire : elles attendent Adrien.")
	_bloque += absents + vides
