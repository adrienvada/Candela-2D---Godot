class_name IsoNuageVoxel
extends RefCounted

## Les nuages en voxels de la vue iso — chantier « Gadgets en volume ». GV1 (2026-09-30) : à l'essai ; GV1bis (le même
## jour, Q67) : LE RENDU PAR DÉFAUT de la suie, de la poussière et de la fumée de la fusée, en voxels « gros », avec l'encre
## du roman graphique et le relief tiré du dessin. `--fumee-couches` rend les couches d'avant (`volume_iso.gdshader`).
##
## Adrien, 2026-09-30 : « J'aimerais également que tous les gadgets (je me souviens de la fumée occultante) soient
## davantage en 3D. Là on est pris entre le graphisme BD et la 3D voxel. Il faut quelque chose de plus uniforme avec le
## nouveau graphisme. » Puis, vers 15:50 (Q67) : « Oui la fumée en gros. Mais trouve un moyen de la rendre quand même un peu
## avec des traits sombres comme le faisait le style roman graphique. » Le shader (`nuage_voxel_iso.gdshader`) explique tout :
## densité, relief, encre, noir absolu, ordre de dessin.
##
## GV2 (2026-10-01, à l'essai, éteint par défaut) : les NAPPES AU SOL — la nappe de braises et la poudre de contact — dans
## la même langue (`NAPPES`) : un tas bas de cubes fins, ou seulement leurs braises en cubes (`VARIANTES_NAPPES`).
##
## Ce fichier ne fait que la GÉOMÉTRIE, les RÉGLAGES et les IMAGES DÉRIVÉES : la grille de cellules d'un nuage, rangée pour
## une caméra ; les uniformes lus sur le nuage 2D à chaque image ; l'aplat, le relief et l'encre d'un dessin, les planches
## réduites de la fusée. `IsoVolumes` décide quand un nuage est en voxels (les drapeaux) et tient ses nœuds, comme ceux des
## couches ; le juge du masque est le sien.
##
## ## Une grille par TYPE de nuage, par taille de voxel et par côté de caméra — partagée
##
## Une grille est un `MultiMesh` : un appel de dessin, des milliers de cubes. Elle ne dépend que du rayon maximal du nuage, de
## sa hauteur, du côté du voxel et de l'ordre de la caméra : toutes les suies du monde partagent la même, et un nuage neuf ne
## coûte qu'un nœud. Son origine est calée sur la grille du monde (un multiple du voxel) : deux nuages voisins ont des cubes
## alignés, comme les dalles et les murs.
##
## ⚠️ **Aucun nom de classe du jeu** (`Fusee`, `GameState`, `Gadget*`) : ils nomment des autoloads, et une suite headless
## compile la présentation avant eux (piège d'ISO4). Tout se lit par propriété.

const TUILE := 35.0
## Les deux tailles de voxel : un quart de tuile (8,75 px : la tête, le torse d'un corps) ou un huitième (4,4 px : un bras,
## une jambe). « gros » est le défaut, décidé par Adrien (Q67, 2026-09-30 : « Oui la fumée en gros ») ; « fin » reste pour
## les bancs (`--fumee-voxels=fin`).
const VARIANTES := {"gros": TUILE / 4.0, "fin": TUILE / 8.0}
const VARIANTE_PAR_DEFAUT := "gros"
## Par nuage : sa densité de voxels (× la densité lue), l'opacité d'un cube, et son rayon MAXIMAL en pixels de monde (la
## grille le couvre ; la densité fait le reste). La suie est « dense et petite », la poussière « large et mince » — mais
## pas à 0,5 : sous la torche, les côtés de ses marches, à moitié transparents sur un sol aussi clair, ne se voyaient plus
## (troisième passage du banc). Le rayon de la fusée : `FuseeModele.RAYON_FUMEE` × `FUMEE_GONFLE` (250 px), recopié —
## `fusee_modele.gd` compile sans autoload, mais le lire ici ferait dépendre la présentation du modèle ;
## `tools/test_fumee_voxel.gd` garde l'égalité.
const NUAGES := {
	"cartouche_suie": {"densite": 1.0, "alpha": 0.9, "rayon_max": 92.0},
	"poussiere": {"densite": 0.72, "alpha": 0.7, "rayon_max": 168.0},
	"fusee": {"densite": 1.0, "alpha": 0.82, "rayon_max": 250.0},
}
## GV2 — LES NAPPES AU SOL EN VOXELS, À L'ESSAI (`IsoVolumes.nappes_voxel`, `--nappes-voxels` ; éteint par défaut : rien ne
## devient le défaut sans le mot d'Adrien). La suite acceptée de Q70 (Adrien, 2026-09-30 : « oui ») — « les nappes au sol :
## les braises en petits cubes rougeoyants qui scintillent, les traces de poudre en grains » —, dans la langue de la fumée
## en cubes : la même grille, le même shader, la même encre (les VOLUTES de leur dessin, Q73), le même relief (la clarté du
## dessin), la même règle du noir. Par nappe : la densité de voxels, l'opacité d'un cube (une nappe est de la MATIÈRE, pas un
## voile : pleine), le rayon maximal (son image : 136 px pour les braises, 220 pour la poudre), la hauteur en tuiles (les
## charbons d'un quart de tuile ; la poudre d'un huitième, la hauteur d'une semelle), le côté de ses cubes (un huitième de
## tuile : des charbons et des grains, pas des blocs — la taille d'un bras de corps) et la part de HASARD dans la hauteur de
## ses colonnes (`grain`, tirée de la case : la même pour les deux vues et les deux machines). `lumineuse` : la nappe est
## une lumière PEINTE (`GadgetBase.materiau_peint_lumineux` : le décor ne l'éclaire pas, son image est sa lueur) — elle GARDE
## son dessin sous ses cubes (pas d'aplat), et chaque cube le lit au pied de sa colonne SANS lissage (`LISSAGE_LUMINEUSE`) :
## la couleur du jeu publié, fissures, cœur et sol chaud qu'elle laisse voir en pâlissant compris. Les deux nappes prennent
## la température GRADUÉE du sol (ISO7b), et non celle d'un nuage : ce sont des dessins AU SOL, que le jeu publié montre par
## le sol (`materiau`).
const NAPPES := {
	"nappe_braises": {"densite": 1.0, "alpha": 1.0, "rayon_max": 70.0, "hauteur": 0.25, "voxel": "fin", "grain": 0.35,
		"lumineuse": true},
	"poudre_contact": {"densite": 1.0, "alpha": 1.0, "rayon_max": 112.0, "hauteur": 0.125, "voxel": "fin", "grain": 0.5,
		"lumineuse": false},
}
## Les deux variantes de l'essai, sur les mêmes planches : « tas » — la nappe elle-même en tas bas de cubes (sous eux, le
## dessin de la poudre passe en APLAT FLOU, `aplat_flou` ; celui des braises reste, `lumineuse`), ses braises des cubes du
## tas qui rougeoient ; « braises » — la nappe reste au
## sol, son dessin et ses couches, et ses braises SEULES deviennent des cubes. Dans les deux, les traces de la poudre sont des
## grains qui luisent (`IsoVolumes._suivre_traces`).
const VARIANTES_NAPPES := ["tas", "braises"]
const VARIANTE_NAPPES_PAR_DEFAUT := "tas"
## Le nombre de braises d'une nappe : celui des lueurs qu'elles remplacent (`IsoVolumes.POINTS_BRAISES`, gardé égal par la
## suite).
const BRAISES_MAX := 16
## Le modelé des faces et l'encre des arêtes (en valeur affichée) : le dessus porte la lumière lue ; les deux côtés vus
## l'assombrissent, à gauche et à droite de l'écran. L'encre est celle des corps (`IsoMateriaux.ENCRE_VOXEL_PX`), plus
## claire — un nuage n'est pas un objet dur — et ne borde que les CÔTÉS : encré, chaque dessus dessinait son carré, et le
## nuage devenait une grille (voir le shader).
const FACE_DESSUS := 1.0
const FACE_GAUCHE := 0.8
const FACE_DROITE := 0.62
const ENCRE_RESTE := 0.55
## GV1bis — L'ENCRE du roman graphique sur les cubes (`encre_style` du shader) : trois variantes proposées à Adrien, le trait
## de GV1 et « aucune » pour les bancs. Voir `nuage_voxel_iso.gdshader`. **Q73 (Adrien, 2026-10-01 : « Q73 : volutes »)** :
## les VOLUTES, le trait du dessin drapé sur le tas ; les autres restent pour les bancs (`--fumee-encre=`).
const ENCRES := {"aretes": 1, "volutes": 2, "hachures": 3, "cotes": 0, "aucune": -1}
## Les trois variantes du roman graphique, dans l'ordre des planches.
const ENCRES_GV1BIS := ["aretes", "volutes", "hachures"]
const ENCRE_PAR_DEFAUT := "volutes"
## GV1bis — LE RELIEF des bouffées (`relief_style`) : la clarté des volutes du dessin (Q69) ou le bruit de GV1.
const RELIEFS := {"dessin": 1, "bruit": 0}
const RELIEF_PAR_DEFAUT := "dessin"
## Le trait du roman graphique : plus large que celui des corps (0,9 px) — un nuage de 184 px de large, pas un bras —, aussi
## noir que l'encre d'essai des murs (`IsoMateriaux.ENCRE_ARETE_RESTE_ESSAI`, 0,12), sous LEUR plancher (« allumé reste
## allumé » : `IsoMateriaux.ENCRE_PLANCHER_AFFICHE`, 16/255 en valeur affichée). **Q74 (Adrien, 2026-10-01 : « Q74 : on
## garde »)** : un trait graphite plutôt que noir d'encre — aucun plancher plus bas pour la fumée seule ; la lueur faible
## d'un nuage, qui est une information, ne s'éteint pas sous un trait.
const TRAIT_PX := 1.5
const TRAIT_RESTE := 0.12
## La dérive lente du dessin (relief et volutes) : ± 6 % du rayon (5,5 px pour la suie, 10 pour la poussière).
const DERIVE_DESSIN := 0.06
## Le pas des hachures : 5 px de monde (à 3,5, une trame fine qui se lisait comme une toile).
const HACHURE_PAS_PX := 5.0
## L'encre d'un dessin : 1 sous 0,04 de luminance (le noir des traits), 0 au-dessus de 0,12 (le gris le plus sombre des
## fonds de la suie). Mesuré sur les deux dessins : 31 % de l'image de la suie est de l'encre, 10 % de celle de la poussière.
const ENCRE_LUM_BAS := 0.04
const ENCRE_LUM_HAUT := 0.12
## Le relief d'un dessin : sa luminance moyennée sur 8 × 8 pixels (trois réductions de moitié) — les bouffées du dessin
## (20 à 40 px) survivent, le trait d'encre (2 à 4 px) se fond en creux.
const RELIEF_REDUCTIONS := 3
## Les planches des nappes de la fusée, réduites à 256 px au plus (≈ 2 px de monde par texel).
const PLANCHE_PX := 256
const SEUIL_TAILLE := 0.1
## La densité où un cube remplit sa case : au-delà, les cubes du corps du nuage sont pleins et jointifs (voir le shader).
const PLEIN_TAILLE := 0.45
## Le cœur plein du profil radial des cubes (celui des couches : 0,45) et le rayon de la lumière lissée (celui des couches :
## 0,18 × le rayon) — voir `nuage_voxel_iso.gdshader`. 1 : AUCUN profil, les cubes vont jusqu'au bord de l'image. La masse
## reste dessinée au sol (en aplat) : partout où son image a de l'alpha sans cube au-dessus, on la voyait déborder en liseré
## autour du tas (0,45 puis 0,7 aux deux premiers passages du banc).
const COEUR := 1.0
const LISSAGE := 0.18
## Le dôme : en haut du nuage, son rayon est resserré de 22 % (celui des couches, `IsoVolumes._poser_couches`, et du shader).
const RESSERRE := 0.22

const CHEMIN_SHADER := "res://nuage_voxel_iso.gdshader"
## Chargé au premier nuage en voxels, jamais avant : sans le drapeau, le jeu ne charge pas ce shader.
static var _shader: Shader = null
static var _shader_fusee: Shader = null
## Les grilles partagées : "clé" → MultiMesh ; et les maillages de trois faces par côté de caméra.
static var _grilles := {}
static var _mailles := {}


static func shader(fusee: bool) -> Shader:
	if _shader == null:
		_shader = load(CHEMIN_SHADER) as Shader
		_shader_fusee = IsoMateriaux.variante_definie(_shader, "NUAGE_FUSEE")
	return _shader_fusee if fusee else _shader


## L'APLAT d'une masse de nuage (suie, poussière), pendant l'essai : la même image — même taille, même alpha, donc même
## forme et même présence —, peinte de sa couleur moyenne (pondérée par l'alpha) au lieu du dessin encré.
##
## ⚠️ **Pourquoi la masse 2D change d'image sous l'essai, et rien d'autre.** Au premier passage du banc, les traits d'encre
## du dessin BD restaient visibles À TRAVERS les cubes : dans la lightmap, un trait est un pixel NOIR au sol, et le masque
## de la fumée interdit — à raison — d'allumer un pixel noir ; les cubes s'y taisaient donc, en rangées de trous. Aucun volume
## ne peut couvrir un dessin encré couché sous lui. L'aplat garde tout ce que le jeu lit de la masse (sa forme, sa lueur, son
## fondu, `occultation_pour` qui ne lit que la géométrie) et retire le dessin : sous les cubes, la lightmap ne porte plus que
## la LUMIÈRE du nuage. La vue de dessus (`--2d`) n'est pas touchée : `IsoVolumes` ne tourne qu'en iso, et rend l'image
## d'origine dès que l'essai s'éteint ou que le nuage part.
static var _aplats := {}


static func aplat(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var cle := tex.get_instance_id()
	if _aplats.has(cle):
		return _aplats[cle]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	# La couleur moyenne, pondérée par l'alpha : l'image prémultipliée, réduite de moitié en moitié jusqu'à un pixel.
	var moy := img.duplicate() as Image
	moy.premultiply_alpha()
	while moy.get_width() > 1 or moy.get_height() > 1:
		moy.shrink_x2()
	var m := moy.get_pixel(0, 0)
	var couleur := Color(m.r / m.a, m.g / m.a, m.b / m.a) if m.a > 0.001 else Color.BLACK
	var d := img.get_data()
	var r := couleur.r8
	var g := couleur.g8
	var b := couleur.b8
	for i in range(0, d.size(), 4):
		d[i] = r
		d[i + 1] = g
		d[i + 2] = b
	var out := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
	var t := ImageTexture.create_from_image(out)
	_aplats[cle] = t
	return t


## GV1bis — LE RELIEF ET L'ENCRE d'un dessin de masse (Q69, Q67) : une image de la taille et de l'ALPHA du dessin (la forme
## du nuage ne bouge pas), qui porte en ROUGE la clarté de ses volutes — sa luminance (les poids de la pâte) moyennée sur
## 8 × 8 pixels, puis étirée entre ses 10e et 90e centiles sur le dessin opaque : une bouffée claire monte, un trait d'encre
## creuse — et en VERT son encre (le noir de ses traits, `ENCRE_LUM_BAS` à `ENCRE_LUM_HAUT`). Le shader lit l'alpha pour la
## densité, le rouge pour le sommet des colonnes, le vert pour les volutes. Le dessin d'origine, jamais l'aplat : c'est le
## dessin qui a des volutes. Une fois par texture et par processus (le cache se clé sur la TEXTURE — pas une graine).
static var _reliefs := {}


static func relief(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var cle := tex.get_instance_id()
	if _reliefs.has(cle):
		return _reliefs[cle]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var n := w * h
	# 1. Au pixel : la luminance, prémultipliée par l'alpha (rouge) avec l'alpha (vert), pour la moyenne ; l'encre.
	var pm := PackedByteArray()
	pm.resize(n * 4)
	var encre := PackedByteArray()
	encre.resize(n)
	var pente := 1.0 / (ENCRE_LUM_HAUT - ENCRE_LUM_BAS)
	for i in n:
		var k := i * 4
		var a := d[k + 3]
		var lum := (0.2126 * d[k] + 0.7152 * d[k + 1] + 0.0722 * d[k + 2]) / 255.0
		pm[k] = roundi(lum * a)
		pm[k + 1] = a
		pm[k + 3] = 255
		if a >= 128:
			encre[i] = roundi(255.0 * (1.0 - clampf((lum - ENCRE_LUM_BAS) * pente, 0.0, 1.0)))
	# 2. La moyenne : trois réductions de moitié (8 × 8 pixels), remontées en bicubique.
	var flou := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, pm)
	for k in RELIEF_REDUCTIONS:
		flou.shrink_x2()
	flou.resize(w, h, Image.INTERPOLATE_CUBIC)
	var fd := flou.get_data()
	# 3. La clarté moyenne (la luminance moyenne ÷ l'alpha moyen), et ses centiles sur le dessin opaque.
	var clarte := PackedFloat32Array()
	clarte.resize(n)
	var opaques := PackedFloat32Array()
	for i in n:
		var k := i * 4
		var c := float(fd[k]) / float(fd[k + 1]) if fd[k + 1] > 12 else 0.0
		clarte[i] = c
		if d[k + 3] >= 128:
			opaques.append(c)
	opaques.sort()
	var bas := opaques[int(opaques.size() * 0.1)] if not opaques.is_empty() else 0.0
	var haut := opaques[int(opaques.size() * 0.9)] if not opaques.is_empty() else 1.0
	var echelle := 255.0 / maxf(haut - bas, 0.01)
	var sortie := PackedByteArray()
	sortie.resize(n * 4)
	for i in n:
		var k := i * 4
		sortie[k] = clampi(roundi((clarte[i] - bas) * echelle), 0, 255)
		sortie[k + 1] = encre[i]
		sortie[k + 3] = d[k + 3]
	var t := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, sortie))
	_reliefs[cle] = t
	return t


## GV1bis — une PLANCHE de nappe de la fusée RÉDUITE à `PLANCHE_PX` (moyennes de moitié en moitié, sur l'image prémultipliée
## puis rendue à ses couleurs) : lue au pas d'un voxel, la planche de 2048 px ne donnait qu'un texel par case — la densité
## sautait d'une case à l'autre, et les paliers ne se traçaient pas. Même forme, mêmes paliers, à la finesse du voxel.
static var _planches := {}


static func planche(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var cle := tex.get_instance_id()
	if _planches.has(cle):
		return _planches[cle]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() <= PLANCHE_PX:
		_planches[cle] = tex
		return tex
	img.premultiply_alpha()
	while img.get_width() > PLANCHE_PX:
		img.shrink_x2()
	var d := img.get_data()
	for k in range(0, d.size(), 4):
		var a := d[k + 3]
		if a > 0 and a < 255:
			var f := 255.0 / float(a)
			d[k] = mini(255, roundi(d[k] * f))
			d[k + 1] = mini(255, roundi(d[k + 1] * f))
			d[k + 2] = mini(255, roundi(d[k + 2] * f))
	var t := ImageTexture.create_from_image(Image.create_from_data(img.get_width(), img.get_height(), false,
		Image.FORMAT_RGBA8, d))
	_planches[cle] = t
	return t


## Au lancement (la fumée en voxels est le défaut) : le shader, sa variante de la fusée, les aplats et les reliefs des deux
## dessins, les planches réduites de la fusée — pour qu'aucun ne se prépare au premier nuage (une masse de 336 px se
## repeint en ~0,1 s de GDScript : un à-coup pile au moment où l'on pose la fumée). Le shader, lui, se COMPILE à son premier
## dessin, dans le pilote : ce coût-là n'est pas pris ici, et ce qu'il vaut sur le pilote d'Apple, le cloud (llvmpipe) ne
## peut pas le dire.
static func prechauffer() -> void:
	if _prechauffe:
		return
	_prechauffe = true
	var debut := Time.get_ticks_usec()
	shader(false)
	for nom in ["cartouche_suie", "poussiere"]:
		var chemin := "res://assets/sprites/gadget_%s.png" % nom
		if ResourceLoader.exists(chemin):
			var dessin := load(chemin) as Texture2D
			aplat(dessin)
			relief(dessin)
	for chemin in PLANCHES_FUSEE:
		if ResourceLoader.exists(chemin):
			planche(load(chemin) as Texture2D)
	# Ce que coûte le préchauffage, une fois par processus : une prise le lit dans le journal.
	print("[fumée voxel] préchauffé en %d ms (shader, aplats, reliefs, planches réduites)"
		% roundi(float(Time.get_ticks_usec() - debut) / 1000.0))


static var _prechauffe := false


## Les planches que `fusee.gd` peut poser sur ses nappes (`_texture_nappe`) : réduites au lancement.
const PLANCHES_FUSEE := ["res://assets/sprites/fusee_volute_2.png", "res://assets/sprites/fusee_volute_3.png",
	"res://assets/sprites/fusee_volute_1.png", "res://assets/sprites/fusee_volute.png"]


## Le shader des voxels a-t-il été chargé dans ce processus ? Faux tant qu'aucun nuage en voxels n'a été posé : sans le
## drapeau, jamais (`tools/test_fumee_voxel.gd` le vérifie).
static func shader_charge() -> bool:
	return _shader != null


static func est_un_shader_de_nuage(s: Shader) -> bool:
	return s != null and _shader != null and (s == _shader or s == _shader_fusee)


static func cote_voxel(variante: String) -> float:
	return float(VARIANTES.get(variante, VARIANTES[VARIANTE_PAR_DEFAUT]))


## Les réglages d'un type : un nuage (`NUAGES`) ou, GV2, une nappe (`NAPPES`).
static func reglages_de(type: String) -> Dictionary:
	return NUAGES[type] if NUAGES.has(type) else NAPPES[type]


## GV2 — ce type est-il une nappe au sol ?
static func est_nappe(type: String) -> bool:
	return NAPPES.has(type)


## Le côté du voxel d'un type : celui de la variante de la fumée pour un nuage ; le sien, toujours, pour une nappe.
static func voxel_de(type: String, variante: String) -> float:
	return cote_voxel(String((NAPPES[type] as Dictionary)["voxel"])) if NAPPES.has(type) else cote_voxel(variante)


## Le nombre de rangées de voxels d'un nuage de `hauteur_px` : au moins une, arrondi au plus proche.
static func rangees(hauteur_px: float, voxel: float) -> int:
	return maxi(1, roundi(hauteur_px / voxel))


## Le côté d'une caméra : le signe de sa direction de vue en x et en z (0 si elle regarde de profil, à moins de 3°).
static func cote_camera(avant: Vector3) -> Vector2i:
	return Vector2i(0 if absf(avant.x) < 0.05 else (1 if avant.x > 0.0 else -1),
		0 if absf(avant.z) < 0.05 else (1 if avant.z > 0.0 else -1))


## La direction de vue d'une caméra iso de lacet `lacet_deg` (tangage de `CameraIso`), pour une vue sans caméra à lire.
static func avant_de_lacet(lacet_deg: float, tangage_deg: float = CameraIso.TANGAGE_DEG) -> Vector3:
	return -Basis.from_euler(Vector3(deg_to_rad(-tangage_deg), deg_to_rad(lacet_deg), 0.0)).z


## Les cellules d'un nuage, relatives à l'origine de sa grille, rangées pour une caméra de côté `cote` : du plus loin au plus
## proche (chaque axe parcouru depuis son côté loin — la caméra regarde vers le bas : les cellules basses d'abord).
## `rayon` : le rayon maximal ; une cellule est gardée si son centre est à moins de `rayon` + une demi-diagonale du centre,
## pour une origine calée à au plus une demi-case du centre vrai.
##
## LE DÔME : à la hauteur d'une rangée (`f`, sa fraction de la hauteur du nuage), la densité ne vit que dans le rayon
## resserré du shader (× 1 − `RESSERRE` f, le dôme des couches) ; une case au-delà ne portera jamais de cube. Chaque rangée
## ne garde donc que son disque : un cinquième des cases en moins, et avec elles leurs douze sommets à chaque image, pour la
## même image.
static func cellules(rayon: float, rangs: int, voxel: float, cote: Vector2i) -> PackedVector3Array:
	var n := ceili(rayon / voxel) + 1
	var xs := range(-n, n) if cote.x <= 0 else range(n - 1, -n - 1, -1)
	var zs := range(-n, n) if cote.y <= 0 else range(n - 1, -n - 1, -1)
	var sortie := PackedVector3Array()
	for iy in rangs:
		var portee := rayon * (1.0 - RESSERRE * (float(iy) + 0.5) / float(rangs)) + voxel * 1.5
		for iz: int in zs:
			for ix: int in xs:
				var p := Vector3((float(ix) + 0.5) * voxel, (float(iy) + 0.5) * voxel, (float(iz) + 0.5) * voxel)
				if Vector2(p.x, p.z).length() <= portee:
					sortie.append(p)
	return sortie


## La grille partagée d'un type de nuage, pour une taille de voxel et un côté de caméra.
static func grille(type: String, hauteur_px: float, voxel: float, cote: Vector2i) -> MultiMesh:
	var rayon := float(reglages_de(type)["rayon_max"])
	var rangs := rangees(hauteur_px, voxel)
	var cle := "%s:%.3f:%d:%d,%d" % [type, voxel, rangs, cote.x, cote.y]
	if _grilles.has(cle):
		return _grilles[cle]
	var cells := cellules(rayon, rangs, voxel, cote)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = maille(cote)
	mm.instance_count = cells.size()
	# Le tampon d'un coup (douze flottants par instance : la base en lignes, puis l'origine) plutôt qu'instance par instance.
	var tampon := PackedFloat32Array()
	tampon.resize(cells.size() * 12)
	for i in cells.size():
		var p := cells[i]
		var k := i * 12
		tampon[k] = voxel
		tampon[k + 3] = p.x
		tampon[k + 5] = voxel
		tampon[k + 7] = p.y
		tampon[k + 10] = voxel
		tampon[k + 11] = p.z
	mm.buffer = tampon
	_grilles[cle] = mm
	return mm


## Le cube de côté 1, réduit aux faces qu'une caméra de côté `cote` voit : le dessus, et un côté par axe où elle ne
## regarde pas de profil. Les faces vues de dos ne seraient jamais dessinées (`cull_back`) : autant ne pas les calculer.
static func maille(cote: Vector2i) -> ArrayMesh:
	var cle := "%d,%d" % [cote.x, cote.y]
	if _mailles.has(cle):
		return _mailles[cle]
	var faces: Array[Vector3] = [Vector3.UP]
	if cote.x != 0:
		faces.append(Vector3(-float(cote.x), 0.0, 0.0))
	if cote.y != 0:
		faces.append(Vector3(0.0, 0.0, -float(cote.y)))
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	for n: Vector3 in faces:
		# Deux axes du plan de la face, dans l'ordre qui la tourne vers l'extérieur (`cull_back` : sens des aiguilles vu de face).
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		var base := sommets.size()
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			sommets.append(n * 0.5 + (u * s.x + v * s.y) * 0.5)
			normales.append(n)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	_mailles[cle] = m
	return m


## L'origine de la grille d'un nuage centré en `centre` : le coin de voxel le plus proche (calée sur le monde).
static func origine(centre: Vector2, voxel: float) -> Vector3:
	return Vector3(roundf(centre.x / voxel) * voxel, 0.0, roundf(centre.y / voxel) * voxel)


## Un matériau de nuage pour une vue : le shader (fusée ou gadget), la vue, les constantes du type ; l'encre et le relief
## (`poser_style`).
static func materiau(type: String, vue_id: int, voxel: float, hauteur_px: float, priorite: int,
		encre: String = ENCRE_PAR_DEFAUT, relief_de: String = RELIEF_PAR_DEFAUT) -> ShaderMaterial:
	var spec := reglages_de(type)
	var mat := ShaderMaterial.new()
	mat.shader = shader(type == "fusee")
	mat.render_priority = priorite
	mat.set_shader_parameter("vue_deux", vue_id == 1)
	mat.set_shader_parameter("voxel_px", voxel)
	mat.set_shader_parameter("nuage_hauteur_px", float(rangees(hauteur_px, voxel)) * voxel)
	mat.set_shader_parameter("alpha_voxel", float(spec["alpha"]))
	mat.set_shader_parameter("seuil_taille", SEUIL_TAILLE)
	mat.set_shader_parameter("plein_taille", PLEIN_TAILLE)
	mat.set_shader_parameter("grille_portee", float(spec["rayon_max"]) + voxel * 1.5)
	mat.set_shader_parameter("nuage_coeur", COEUR)
	mat.set_shader_parameter("face_dessus", FACE_DESSUS)
	mat.set_shader_parameter("face_gauche", FACE_GAUCHE)
	mat.set_shader_parameter("face_droite", FACE_DROITE)
	mat.set_shader_parameter("encre_px", IsoMateriaux.ENCRE_VOXEL_PX if IsoMateriaux.beaute_active() else 0.0)
	mat.set_shader_parameter("encre_reste", ENCRE_RESTE)
	mat.set_shader_parameter("trait_px", TRAIT_PX)
	mat.set_shader_parameter("trait_reste", TRAIT_RESTE)
	mat.set_shader_parameter("trait_plancher", IsoMateriaux.ENCRE_PLANCHER_AFFICHE)
	mat.set_shader_parameter("derive_dessin", DERIVE_DESSIN)
	mat.set_shader_parameter("hachure_pas_px", HACHURE_PAS_PX)
	mat.set_shader_parameter("temperature", IsoMateriaux.TEMPERATURE if IsoMateriaux.beaute_active() else 0.0)
	mat.set_shader_parameter("temperature_seuil_bas", 0.0)
	mat.set_shader_parameter("temperature_seuil_haut", 0.0)
	# Chantier RR, RR2 — la lumière peinte, comme le sol et les murs qu'elle recouvre (`IsoMateriaux.courbe_lumiere`).
	mat.set_shader_parameter("courbe", IsoMateriaux.courbe_lumiere())
	# GV2 — une nappe ne coule pas : ni la respiration de ses cubes, ni la dérive de son dessin ; ses colonnes prennent leur
	# part de hasard (`grain`). Posés pour tous, nuages compris : un réglage se lit sur le matériau, jamais sur un défaut.
	var nappe := est_nappe(type)
	mat.set_shader_parameter("respiration", 0.0 if nappe else 1.0)
	mat.set_shader_parameter("grain", float(spec.get("grain", 0.0)))
	if nappe:
		mat.set_shader_parameter("derive_dessin", 0.0)
		# Un dessin AU SOL : la température graduée du sol (ISO7b), celle que le jeu publié lui donne — sous celle d'un nuage,
		# l'anneau de pierre de la nappe de braises sortait gris (quatrième passage du banc de GV2).
		var beaute := IsoMateriaux.beaute_active()
		mat.set_shader_parameter("temperature", IsoMateriaux.TEMPERATURE_GRADUEE if beaute else 0.0)
		mat.set_shader_parameter("temperature_seuil_bas", IsoMateriaux.TEMPERATURE_SEUIL_BAS)
		mat.set_shader_parameter("temperature_seuil_haut", IsoMateriaux.TEMPERATURE_SEUIL_HAUT if beaute else 0.0)
	poser_style(mat, encre, relief_de)
	return mat


## L'encre et le relief d'un matériau de nuage, sur place (les bancs basculent d'une variante à l'autre dans la même
## image). L'encre suit la beauté, comme celle des murs et des corps : `--sans-beaute`, aucune.
static func poser_style(mat: ShaderMaterial, encre: String, relief_de: String) -> void:
	mat.set_shader_parameter("encre_style", int(ENCRES.get(encre, ENCRES[ENCRE_PAR_DEFAUT]))
		if IsoMateriaux.beaute_active() else int(ENCRES["aucune"]))
	# Chantier RR — l'encre est l'exception depuis RR3 (Q90 = (b), `IsoMateriaux.encre_active`, `--avec-encre`) : sans elle,
	# aucune, quelle que soit l'encre demandée. À part, et après : la ligne du dessus est celle que `test_fumee_voxel` garde.
	if not IsoMateriaux.encre_active():
		mat.set_shader_parameter("encre_style", int(ENCRES["aucune"]))
	mat.set_shader_parameter("relief_style", int(RELIEFS.get(relief_de, RELIEFS[RELIEF_PAR_DEFAUT])))


## Le rendu de GV1 tel qu'il a été planché (le trait clair des côtés, le relief du bruit, les planches entières de la
## fusée) : ce que la planche de GV1bis met à côté des encres, et le retour possible.
static func est_gv1(encre: String, relief_de: String) -> bool:
	return encre == "cotes" and relief_de == "bruit"


## Les réglages d'un nuage de GADGET (suie, poussière), lus sur sa masse 2D : son image (`masque` : le relief de son dessin,
## `relief`, dont l'alpha est celui de la masse) et son angle, son rayon, sa vie, son âge (l'horloge : `age()` du gadget,
## que la killcam rejoue).
static func poser_gadget(mat: ShaderMaterial, type: String, centre: Vector2, rayon: float, masque: Texture2D, angle: float,
		vie: float, age: float) -> void:
	mat.set_shader_parameter("nuage_centre", centre)
	mat.set_shader_parameter("nuage_rayon", rayon)
	mat.set_shader_parameter("lissage_px", maxf(rayon * LISSAGE, float(mat.get_shader_parameter("voxel_px"))))
	mat.set_shader_parameter("masque", masque)
	mat.set_shader_parameter("avec_masque", masque != null)
	mat.set_shader_parameter("nuage_angle", angle)
	mat.set_shader_parameter("nuage_vie", clampf(vie, 0.0, 1.0) * float(reglages_de(type)["densite"]))
	mat.set_shader_parameter("age", age)


## GV2 — LES BRAISES d'une nappe : leurs points `[Vector4(x, z au sol, phase, vitesse)]` (au plus `BRAISES_MAX`), l'éclat de
## la lumière de la nappe (0 : lumière éteinte, braises éteintes), la couleur de la lueur, et si la nappe reste au sol (la
## variante « braises » : ses braises SEULES sont des cubes). Le scintillement se calcule dans le shader, à l'âge du nuage.
static func poser_braises(mat: ShaderMaterial, points: Array, eclat: float, couleur: Color, seulement: bool) -> void:
	var tableau := PackedVector4Array()
	tableau.resize(BRAISES_MAX)
	var n := mini(points.size(), BRAISES_MAX)
	for k in n:
		tableau[k] = points[k]
	mat.set_shader_parameter("nb_braises", n)
	mat.set_shader_parameter("braises", tableau)
	mat.set_shader_parameter("braises_eclat", maxf(eclat, 0.0))
	mat.set_shader_parameter("braises_couleur", Vector3(couleur.r, couleur.g, couleur.b))
	mat.set_shader_parameter("seulement_braises", seulement)


## GV2 — le lissage de la lumière d'une nappe peinte lumineuse : AUCUN — chaque cube prend la lightmap au pied de sa
## colonne, la nappe telle que le jeu publié la montre. Sous un aplat flou et lissé (la règle de la fumée), la nappe de
## braises sortait uniforme, sans charbons ni fissures ; tirée de son dessin seul, elle perdrait le sol qu'elle laisse voir
## en pâlissant (passages du banc de GV2).
const LISSAGE_LUMINEUSE := 0.0


## GV2 — L'APLAT FLOU d'une nappe en tas : son dessin moyenné sur 8 × 8 pixels (les trois réductions du relief, sur l'image
## prémultipliée, puis rendu à ses couleurs), sous l'alpha d'ORIGINE — même forme, même présence. Sous les cubes, la lightmap
## ne porte plus les traits fins du dessin (un trait noir sous un cube : le masque de la fumée refuse d'y peindre, le « en
## trous » de GV1, Q68), mais elle garde sa LUMIÈRE : le clair de la poudre, que l'aplat de la fumée (une seule couleur,
## Q68) aurait éteint. Pour la poudre seule : la nappe de braises, peinte lumineuse, garde son dessin (`NAPPES`). Une fois
## par texture et par processus.
static var _aplats_flous := {}


static func aplat_flou(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var cle := tex.get_instance_id()
	if _aplats_flous.has(cle):
		return _aplats_flous[cle]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var flou := img.duplicate() as Image
	flou.premultiply_alpha()
	for k in RELIEF_REDUCTIONS:
		flou.shrink_x2()
	flou.resize(w, h, Image.INTERPOLATE_CUBIC)
	var d := img.get_data()
	var fd := flou.get_data()
	var sortie := PackedByteArray()
	sortie.resize(d.size())
	for k in range(0, d.size(), 4):
		var a := fd[k + 3]
		if a > 0:
			var f := 255.0 / float(a)
			sortie[k] = mini(255, roundi(fd[k] * f))
			sortie[k + 1] = mini(255, roundi(fd[k + 1] * f))
			sortie[k + 2] = mini(255, roundi(fd[k + 2] * f))
		sortie[k + 3] = d[k + 3]
	var t := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, sortie))
	_aplats_flous[cle] = t
	return t


## GV2 — sous l'essai seulement : le shader, les aplats flous et les reliefs des deux dessins de nappes — pour qu'aucun ne se
## prépare à la première nappe posée.
static func prechauffer_nappes() -> void:
	if _nappes_prechauffees:
		return
	_nappes_prechauffees = true
	var debut := Time.get_ticks_usec()
	shader(false)
	for nom: String in NAPPES:
		var chemin := "res://assets/sprites/gadget_%s.png" % nom
		if ResourceLoader.exists(chemin):
			var dessin := load(chemin) as Texture2D
			# L'aplat flou ne sert qu'à une nappe éclairée par le décor (la poudre) : la nappe de braises garde son dessin.
			if not bool(NAPPES[nom]["lumineuse"]):
				aplat_flou(dessin)
			relief(dessin)
	print("[nappes voxel] préchauffé en %d ms (shader, aplats flous, reliefs)"
		% roundi(float(Time.get_ticks_usec() - debut) / 1000.0))


static var _nappes_prechauffees := false


## Les uniformes du voile de la fusée que le nuage recopie, sous le même nom que dans `fumee_fusee.gdshader` (sauf les trois
## que le préfixe `voile_` distingue de ceux du nuage).
const VOILE_MEME_NOM := ["nb_masses", "masses", "masse_rayon_uv", "masse_opacite", "nb_trous", "trous", "nb_tunnels",
	"tunnels_entree", "tunnels_sortie", "tunnel_force", "tunnel_sombre", "tunnel_largeur_uv"]
const VOILE_PREFIXE := {"alpha_globale": "voile_alpha_globale", "graine": "voile_graine", "age": "voile_age"}


## Les réglages de la fumée d'une FUSÉE, lus sur ce qu'elle peint en 2D à cette image : son voile (volutes, masses, trous,
## tunnels) et ses nappes (planche, rotation, taille, opacité). `voile` : son `Sprite2D` « Voile » ; `nappes` : les siens.
##
## `reduites` (GV1bis) : chaque nappe prend sa planche RÉDUITE (`planche`) au lieu de la planche entière.
static func poser_fusee(mat: ShaderMaterial, centre: Vector2, rayon: float, voile: Sprite2D, nappes: Array,
		age: float, reduites: bool = true) -> void:
	mat.set_shader_parameter("nuage_centre", centre)
	mat.set_shader_parameter("nuage_rayon", rayon)
	mat.set_shader_parameter("lissage_px", maxf(rayon * LISSAGE, float(mat.get_shader_parameter("voxel_px"))))
	mat.set_shader_parameter("nuage_vie", float((NUAGES["fusee"] as Dictionary)["densite"]))
	mat.set_shader_parameter("age", age)
	var mv := voile.material as ShaderMaterial if voile != null else null
	if mv != null and voile.is_visible_in_tree():
		for nom: String in VOILE_MEME_NOM:
			mat.set_shader_parameter(nom, mv.get_shader_parameter(nom))
		for nom: String in VOILE_PREFIXE:
			mat.set_shader_parameter(VOILE_PREFIXE[nom], mv.get_shader_parameter(nom))
		mat.set_shader_parameter("voile_diametre", float(voile.texture.get_width()) * absf(voile.global_scale.x)
			if voile.texture != null else rayon * 2.0)
	else:
		mat.set_shader_parameter("voile_alpha_globale", 0.0)
	var n := 0
	var reglages := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for s in nappes:
		var nappe := s as Sprite2D
		if nappe == null or nappe.texture == null or not nappe.is_visible_in_tree() or n >= 3:
			continue
		mat.set_shader_parameter("nappe_%d" % (n + 1), planche(nappe.texture) if reduites else nappe.texture)
		reglages[n] = Vector3(nappe.global_rotation, float(nappe.texture.get_width()) * absf(nappe.global_scale.x),
			Presentation3D.opacite_rendue(nappe))
		n += 1
	mat.set_shader_parameter("nb_nappes", n)
	mat.set_shader_parameter("nappes", PackedVector3Array(reglages))
