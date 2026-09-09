class_name Exporteur
extends RefCounted

## DA6.4 — transformer une composition en fichier image.
##
## Une carte de fin de soirée qui ne sort pas du jeu n'est pas partageable ; elle
## est jolie. Ce fichier est le seul endroit qui sache écrire un PNG à partir
## d'un `Control`, et il ne connaît ni la carte, ni le bilan, ni la soirée —
## on lui donne une fabrique et une taille.
##
## ## Pourquoi un `SubViewport` et non une capture d'écran
##
## Capturer l'écran donnerait l'image à la résolution de la fenêtre, au format de
## la fenêtre, avec ce qui traîne dessous. Composer dans un `SubViewport` donne
## **la taille qu'on veut** — 1080×1350, le portrait que les fils d'actualité ne
## recadrent pas — quelle que soit la fenêtre, y compris en 720p.
##
## ⚠️ **Deux images d'attente, et ce n'est pas de la superstition.** Un
## `SubViewport` fraîchement peuplé n'a rien dessiné : lire sa texture tout de
## suite rend un cadre vide ou noir. La première image monte l'arbre et calcule
## la mise en page des conteneurs, la seconde la dessine. Le piège est le même
## que celui de `frame_post_draw` déjà consigné pour les outils de rendu, sous
## une autre forme.
##
## ## Où le fichier atterrit, et pourquoi pas dans `user://` seulement
##
## `user://` est un chemin que personne ne connaît — sur macOS il vit à sept
## dossiers de profondeur sous `~/Library/Application Support`. Une image qu'on
## ne retrouve pas n'est pas partagée. On vise donc le dossier IMAGES du système,
## et `user://partages/` n'est que le repli quand il n'existe pas ou refuse
## l'écriture (build sandboxé, système exotique).
##
## **Le chemin réellement employé est RENDU**, jamais supposé : l'appelant
## l'affiche. Dire « enregistré » sans dire où est la façon la plus sûre de
## produire un fichier que personne n'ouvrira.

## Le sous-dossier créé dans le dossier Images du système.
const DOSSIER_SYSTEME := "Candela"

## Le repli, dans l'espace du jeu.
const DOSSIER_REPLI := "user://partages"


## Écrit un PNG d'une composition et rend son chemin absolu, ou `""` en cas
## d'échec.
##
## `fabrique` prend une `Vector2` (la taille) et rend un `Control` neuf. Une
## FABRIQUE et non un nœud existant : un `Control` déjà affiché ne peut pas être
## dans deux arbres à la fois, et le déplacer dans le `SubViewport` le ferait
## disparaître de l'écran au moment même où le joueur le regarde.
static func png(hote: Node, fabrique: Callable, taille: Vector2i,
		prefixe: String) -> String:
	if hote == null or not hote.is_inside_tree():
		return ""
	var vue := SubViewport.new()
	vue.size = taille
	vue.transparent_bg = false
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	# Hors de l'écran, et sans entrée : cette vue ne doit ni s'afficher ni voler
	# le clavier au menu pendant la seconde où elle existe.
	vue.handle_input_locally = false
	hote.add_child(vue)

	var contenu: Control = fabrique.call(Vector2(taille))
	if contenu == null:
		vue.queue_free()
		return ""
	vue.add_child(contenu)

	await hote.get_tree().process_frame
	await hote.get_tree().process_frame

	var texture := vue.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	vue.queue_free()
	if image == null:
		return ""

	var chemin := _chemin_de_sortie(prefixe)
	if chemin == "":
		return ""
	return chemin if image.save_png(chemin) == OK else ""


## Le fichier à écrire, dossier créé, nom horodaté — ou `""` si aucun des deux
## emplacements n'accepte d'être créé.
##
## Horodaté à la SECONDE : deux exports de la même soirée ne doivent pas
## s'écraser, et un joueur qui exporte deux fois veut souvent comparer.
static func _chemin_de_sortie(prefixe: String) -> String:
	var nom := "%s-%s.png" % [prefixe, Time.get_datetime_string_from_system()
		.replace(":", "").replace("-", "").replace("T", "-")]
	for dossier in _dossiers_candidats():
		if dossier == "":
			continue
		if DirAccess.make_dir_recursive_absolute(dossier) != OK \
				and not DirAccess.dir_exists_absolute(dossier):
			continue
		return dossier.path_join(nom)
	return ""


static func _dossiers_candidats() -> Array[String]:
	var out: Array[String] = []
	var images := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if images != "":
		out.append(images.path_join(DOSSIER_SYSTEME))
	out.append(ProjectSettings.globalize_path(DOSSIER_REPLI))
	return out


## Le chemin tel qu'on le MONTRE — abrégé par `~`, et pas plus.
##
## Un chemin absolu de macOS occupe cent dix caractères et déborde de toute
## ligne d'interface ; n'en montrer que le nom de fichier ne dit pas où chercher.
## Le tilde est le seul raccourci que tout le monde sait relire.
static func lisible(chemin: String) -> String:
	if chemin == "":
		return ""
	var foyer := OS.get_environment("HOME")
	if foyer != "" and chemin.begins_with(foyer):
		return "~" + chemin.substr(foyer.length())
	return chemin
