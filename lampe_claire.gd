extends RefCounted

## Q40 — LA LAMPE CLAIRE, À L'ESSAI (`--lampe-claire`, ÉTEINT par défaut ; session cloud « lampe-claire », 2026-09-28).
##
## Le sol et les murs que la lampe éclaire, relevés vers la crème des illustrations (~200-240/255) au lieu de l'ocre du
## jeu (~126), sans rien changer de ce que le jeu LIT de la lumière. La courbe vit dans `lampe_claire.gdshaderinc`, à la
## SORTIE des matériaux du sol et des murs de la vue iso — son en-tête dit pourquoi c'est l'endroit qui ne touche pas au
## jeu. Ce fichier ne fait que la poser sur ces matériaux : `force` à 0 (le défaut), le shader rend sa couleur telle quelle.
##
## Local, comme les autres essais d'image : n'entre dans aucun RPC ni dans aucun calcul de la simulation ;
## `Protocol.VERSION` ne bouge pas. Deux pairs dont un seul porte le drapeau jouent la même partie.
##
## Ne dépend d'aucun autoload : la garde headless (`tools/test_lampe_claire.gd`) le charge sous `--script`.

const DRAPEAU := "--lampe-claire"

## Les réglages de l'essai (voir l'en-tête de l'include pour la courbe). Calibrés au photographe, le 2026-09-28, sur le
## Cloître à 45° B. La luminance est ÉCRITE (≈ l'écran) : 0,08 ≈ 20/255, 0,40 ≈ 102/255 ; 126/255 → ~213/255.
const GENOU := Vector2(0.08, 0.40)
const GAMMA := 3.0
const PLAFOND := 0.96
const PALEUR := 0.8
## La crème : la couleur de la lampe elle-même (`Charte.HALOGENE`, recopiée ici pour la garde sous `--script`).
const CREME := Color(0.98, 0.91, 0.80)
const NEUTRE := Vector2(0.36, 0.50)


## La ligne « [lampe claire] allumée » n'est imprimée qu'une fois (l'essai se pose sur chaque matériau du sol et des murs).
static var _annoncee := false


## Le drapeau est-il posé sur la ligne de commande ?
static func demandee() -> bool:
	return OS.get_cmdline_user_args().has(DRAPEAU)


## Pose l'essai (allumé ou non) sur un matériau du sol ou des murs. Éteint, seule la force est posée, à 0 : c'est elle que
## le shader teste en tête, et c'est aussi sa valeur par défaut.
static func accorder(mat: ShaderMaterial, active: bool) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("lampe_claire", 1.0 if active else 0.0)
	if not active:
		return
	# La preuve pour la série de cadence des essais (session cloud « série-essais ») : posée, une fois par lancement.
	if not _annoncee:
		_annoncee = true
		print("[lampe claire] allumée — posée sur le sol et les murs (force 1)")
	mat.set_shader_parameter("lampe_claire_genou", GENOU)
	mat.set_shader_parameter("lampe_claire_gamma", GAMMA)
	mat.set_shader_parameter("lampe_claire_plafond", PLAFOND)
	mat.set_shader_parameter("lampe_claire_paleur", PALEUR)
	mat.set_shader_parameter("lampe_claire_creme", Vector3(CREME.r, CREME.g, CREME.b))
	mat.set_shader_parameter("lampe_claire_neutre", NEUTRE)


## La courbe du shader, en GDScript, pour la garde : la luminance écrite `x` (0..1) et la neutralité `n` de la lumière
## reçue → la luminance écrite après l'essai. Même formule, ligne pour ligne, que `lampe_claire_sur`.
static func luminance_ecrite(x: float, n: float, force := 1.0) -> float:
	if force <= 0.0:
		return x
	var w := force * smoothstep(GENOU.x, GENOU.y, x) * smoothstep(NEUTRE.x, NEUTRE.y, n)
	if w <= 0.0 or x <= 0.0:
		return x
	var h := maxf(x, PLAFOND * (1.0 - pow(1.0 - clampf(x, 0.0, 1.0), GAMMA)))
	return x + w * (h - x)
