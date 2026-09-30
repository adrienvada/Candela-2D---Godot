class_name IsoVolumes
extends Node3D

## Gadgets et lumières en iso — les VOLUMES (étape 3), les LUEURS (étape 4) et la toile du voile (étape 5).
##
## `MiroirsIso` lève ce qui a un corps (voxels) ; ce fichier élève ce qui n'en a pas mais a une épaisseur
## ou une hauteur : les nuages (suie, poussière, fumée de fusée), les nappes (braises, poudre), les sources
## qui brûlent au-dessus du sol (la comète d'une fusée en vol, sa lueur posée, les braises, la lentille de
## la torche fantôme, l'éclair de la mine, l'éclat de bouche) et l'anneau de l'onde de mort.
##
## ## Une image, jamais une valeur de jeu
##
## Rien ici n'est lu par la simulation, la balle, l'éblouissement, les capteurs ni les lightmaps : un
## volume lit la lightmap sous lui (`volume_iso.gdshader`), une lueur recopie l'énergie d'une lumière 2D
## (`halo_iso.gdshader`). Couper `images_actives` retire tout sans qu'aucune de ces valeurs change —
## `tools/test_iso_gadgets.gd` le prouve. Aucune `Light3D`.
##
## ## Trois règles d'équité, tenues par construction — dans le MONDE
##
## - **Noir absolu** : un volume vaut la lightmap sous lui (0 sans lumière) ; une lueur vaut l'énergie de
##   sa lumière (0 lumière éteinte). L'anneau de l'onde et la toile sont les seuls dessins sans lumière, et
##   ils l'étaient déjà en vue de dessus (l'onde est non éclairée ; la toile recopie la lightmap).
##   ⚠️ **Tenu dans le monde, pas démontré à l'écran** (corrigé le 2026-09-24). Une couche EN HAUTEUR est
##   dessinée plus haut que le sol qu'elle lit (parallaxe, tangage 52°) et peut tomber sur un pixel noir :
##   mesuré pour le faisceau d'ISO13 (307 pixels isolés à 0,45 de densité, 15 couches posées au sol).
##   Pour la fumée de la fusée et les autres nuages, allumés par défaut, la question est OUVERTE : les
##   deux instruments essayés n'ont pas su répondre (`docs/iso/iso13/plan_lots_d_e.md`). Cette règle a
##   été écrite le 2026-09-15 en ne regardant que le monde.
## - **Les deux joueurs** : chaque couche lit la lightmap de la caméra qui la dessine, comme le sol ; les
##   lueurs sont celles de sources que les deux vues montrent déjà (masques de lumière 1|2|4, dessins non
##   éclairés visibles des deux).
## - **Jamais plus caché qu'en vue de dessus** : les couches se dessinent AVANT les corps
##   (`PRIORITE_VOLUME`) ; l'effacement dans un nuage reste celui de l'opacité du corps (ISO2b).
##
## ⚠️ **Aucun nom de classe du jeu** (`Fusee`, `Bullet`, `Player`, `Gadget*`) : ils nomment des autoloads, et
## une suite headless compile la présentation avant eux (piège d'ISO4). Tout se reconnaît par propriété.

const SHADER_VOLUME := preload("res://volume_iso.gdshader")
const SHADER_HALO := preload("res://halo_iso.gdshader")
## ISO10, 1c — la lueur au sol de la fusée posée, en mélange et non en addition (voir `halo_iso.gdshaderinc`).
const SHADER_HALO_MELANGE := preload("res://halo_iso_melange.gdshader")
const SHADER_TRAIT := preload("res://quad_iso.gdshader")
const OndeDeMort := preload("res://kill_shockwave.gd")

const TUILE := 35.0
## Sous les corps (profondeur -1, couleur 0) : un nuage ne recouvre jamais un corps.
const PRIORITE_VOLUME := -2
## La couche 3D commune aux deux caméras (`Presentation3D.CALQUE_COMMUN`).
const CALQUE := 1
## Au-dessus du sol projeté, jamais dedans (`MiroirsIso.HAUTEUR_QUAD_PX`).
const PLANCHER_PX := 0.8

## Les volumes des gadgets, par slug : hauteur (tuiles), nombre de couches, opacité d'une couche au cœur.
## Hauteurs du brief ; densités dosées au banc (`tools/banc_iso_gadgets.gd`).
const VOLUMES := {
	"cartouche_suie": {"hauteur": 0.8, "couches": 4, "densite": 0.34},
	"poussiere": {"hauteur": 0.4, "couches": 3, "densite": 0.16},
	"nappe_braises": {"hauteur": 0.1, "couches": 2, "densite": 0.40},
	"poudre_contact": {"hauteur": 0.1, "couches": 2, "densite": 0.34},
}
const VOLUME_FUSEE := {"hauteur": 1.0, "couches": 4, "densite": 0.26}

## Le cœur chaud à la lampe : sa taille en pixels de monde, et sa hauteur au-dessus du sol.
const TAILLE_COEUR_LAMPE := 7.0
const HAUTEUR_COEUR_LAMPE := 0.20
## Q41 — LE RAYON DANS L'AIR, ALLUMÉ PAR DÉFAUT (Adrien, 2026-09-28 vers 15:25 : « Q41 : faisceau visible dans l'air ») ; essai
## de la session cloud « faisceau-air », rendu LUMINEUX par la session « faisceau-visible » (`FAISCEAU_LUMINEUX`).
## Les conditions de son retour (ROADMAP, 2026-09-24) tiennent : ses couches restent SOUS la hauteur des murets (0,40 tuile :
## 0,12 / 0,24 / 0,36), donc aucune hauteur rendue à la lampe ; il porte TOUJOURS le masque pochoir (rien ne tombe hors de la
## lumière du sol à l'écran) ; sa densité se règle (`--faisceau-air=<densité>`). Elle vaut ici l'opacité d'une couche en
## mélange ADDITIF : trois couches ajoutent chacune la lumière lue sous elles × cette densité. 1,20, choisie à l'image parmi
## 0,35 / 0,70 / 1,20 / 2,0 (session « faisceau-visible », 2026-09-28) : le cœur du cône gagne ~36/255, le bord ~4 ; à 0,70 le
## rayon se devinait à peine, à 2,0 il lavait la tache. Voir `docs/iso/cloud/faisceau-visible/RAPPORT.md`.
const VOLUME_FAISCEAU_AIR := {"hauteur": 0.36, "couches": 3, "densite": 1.20}
## Sa clé de suivi, à côté du cœur chaud (1) : un joueur porte les deux.
const CLE_FAISCEAU_AIR := 3

## La toile du voile, debout : la hauteur de ses piquets (`VoxelObjet.VOILE_PIQUET`).
const HAUTEUR_TOILE := 0.15
## Les points incandescents de la nappe de braises.
const POINTS_BRAISES := 16
## La lentille de la torche fantôme : là où le fût se termine (`VoxelObjet.TORCHE_TETE_Y` + demi-tête).
const HAUTEUR_LENTILLE := 0.20
const HAUTEUR_ECLAIR_MINE := 0.14

## Tout couper — la preuve que ces images ne sont que des images. Relu à chaque image.
var images_actives := true
## ISO12 — INSTRUMENTS DE BANC (spécification d'ISO7 Gadgets, 2026-09-23 ; `tools/bench_framerate.gd`), pour répartir le coût de
## cadence d'une fusée entre ses parties. Jamais posés en jeu ; chacun est lu en UN seul endroit, nommé.
## `volumes_actifs` faux : pas de volume de fumée iso (lu dans `_suivre_fusee`).
var volumes_actifs := true
## `lueurs_actives` faux : ni la lueur posée ni les deux lueurs de la comète (lu dans `_suivre_fusee` et `_suivre_comete`).
var lueurs_actives := true
## `couches_fusee` ≥ 0 : le nombre de couches du volume de la fusée, plafonné à `VOLUME_FUSEE["couches"]` ; −1 : le défaut.
## ⚠️ `_couches()` ne fait que CRÉER, jamais détruire : à poser AVANT que la fusée soit suivie (ou suivi d'un `vider()`), et à ne
## jamais changer en cours de relevé — un volume déjà construit garderait ses couches, sans rien dire.
var couches_fusee := -1
## ISO13, lot E — éteint par défaut, comme tout drapeau d'un lot en cours.
var faisceaux_actifs := false
## Q41 — le rayon dans l'air, ALLUMÉ par défaut ; `--sans-faisceau-air` l'éteint (build de débogage seulement). Relu à chaque
## image (un banc peut le basculer sur place).
var faisceau_air := true
## Chantier des lumières de la 0.8.0, L3 (Q46, Adrien, 2026-09-29) — le POINT LUMINEUX à la lentille de chaque torche tenue,
## ALLUMÉ par défaut ; `--sans-point-lumineux` l'éteint, en build de débogage seulement (un joueur ne choisit pas ce que
## l'adversaire montre). Relu à chaque image. Voir `_suivre_lentilles_des_joueurs`.
var point_lumineux := true
## `--faisceau-air=0.3` force la densité d'une couche (au cœur, lampe à pleine énergie) ; 0 : celle de `VOLUME_FAISCEAU_AIR`.
var densite_faisceau_air := 0.0
## L'allègement de la 0.8.0 (Adrien, 2026-09-30, 15:36 : « Oui allège d'abord avant de publier la 0.8 ») — le rayon TAILLÉ à
## son cône : ses couches sont des éventails autour de la lampe qui ne couvrent que là où le cookie peut dessiner, au lieu des
## carrés posés sur toute la texture de la lampe à son échelle. La MÊME image (voir `_tailler_faisceau_air`).
## `--faisceau-air-carre` rend les carrés d'avant, en build de débogage seulement : pour les bancs et la preuve à l'image.
## Relu à chaque image (la preuve le bascule sur place).
var faisceau_taille := true
## L'allègement de la 0.8.0 — LE JUGE du rayon taillé lui aussi : une OPTION, éteinte, parce qu'elle change l'image. Le juge
## écrit « noir » dans le pochoir avec la marge du rayon (16/255), plus large que celle de la fumée (8/255), et la fumée ne se
## dessine pas là où le pochoir le dit : sur tout son disque, le juge du rayon taisait donc les volutes de fumée posées sur un
## sol entre 8 et 16/255, hors du cône compris (preuve à l'image, 2026-09-30 : 1 235 pixels, jusqu'à 25/255, dont 1 196
## reviennent exactement à l'image sans rayon). Taillé, il ne les tait plus hors du cône — et l'image s'allège de ~8 % sous
## llvmpipe. `--faisceau-juge-taille` l'allume, en build de débogage seulement : c'est à Adrien d'en décider.
var faisceau_juge_taille := false
## L'allègement de la 0.8.0 — INSTRUMENT DE PREUVE, jamais posé en jeu, lu en UN seul endroit (`_suivre_faisceau_air`) : ≥ 0,
## l'âge du grain du rayon, figé (secondes), pour que deux prises d'une même scène — carrés puis éventails — se comparent au
## pixel (`tools/loupe_faisceau_taille.gd`) ; −1 : l'horloge, comme en jeu.
var age_faisceau_fige := -1.0
## ISO13, Q31 voie A — le masque de la fumée : chaque couche de volume passe à la variante FUMEE_MASQUE
## de son shader, qui la tait là où ce que le pixel montre est affiché noir (voir `volume_iso.gdshader`). ÉTEINT PAR DÉFAUT
## depuis le 2026-09-26 (ordre 416 du cloud) : allumé le 2026-09-25 (Q31 : « le noir d'abord », prix 3 % au plus), il
## échoue au prix sur l'état intégré — 45° B et usure au défaut, il rend 0,863 de la cadence (M0 80, M1 69) — et Q31
## revient à Adrien avec ce prix. La preuve à l'image reste acquise. `--fumee-masque` l'allume ; `--sans-fumee-masque`
## reste accepté et ne change rien. À poser AVANT que les couches naissent, comme `couches_fusee` — une couche déjà créée
## garde son shader (les bancs basculent par `poser_masque_fumee`).
## **Q31 (Adrien, 2026-09-28 : « peu importe, prends le plus léger ») — ALLUMÉ PAR DÉFAUT depuis la 0.7.0, dans la forme qui
## fait le moins de travail : V5, « le juge ajusté » (`forme_masque = 5`, session cloud masque-fumée-2 : même image que le
## pochoir, V5 contient V4 qui contient le pochoir).** `--sans-fumee-masque` l'éteint, en build de débogage seulement : éteint,
## la fumée allume des pixels hors de la lumière, ce qu'un joueur ne doit pas pouvoir choisir.
var masque_fumee := true
## Session cloud « masque-fumée » (2026-09-27) — LA FORME du masque, quand il est allumé : 0, celle de Gadgets (le masque de
## `--fumee-masque`, tel quel) ; 1 à 3, les formes moins chères de `volume_masque_compact.gdshaderinc`, chacune derrière son
## drapeau (`FORMES_MASQUE`), qui allume aussi le masque. ÉTEINTES par défaut : sans l'un de ces drapeaux, rien ne change.
## Chacune ajoute une idée à la précédente, pour qu'une série en miroir attribue le prix à chaque idée.
## Depuis la 0.7.0 (Q31), la forme par défaut est 5 (V5) ; les drapeaux de forme choisissent toujours la leur.
var forme_masque := 5
## Q34 = C (Adrien, 2026-09-26) — le point de braise de la fusée POSÉE, PAR DÉFAUT. En 2D, le cœur incandescent (`fusee.gd`,
## `EMPREINTE_COEUR`, 16 px) « se voit dans le noir complet parce qu'il EST la source » : c'est une information de jeu, la
## position de la fusée. En iso, le voxel le remplace (ISO3 vague 3, d641b48 ; ISO4, 77941df) et ne l'émet pas ; ce point le
## rend, par un halo d'ici et non par le voxel, comme la comète en vol (10 px). 2 (défaut) : presque blanc pendant le plein
## feu, puis de la couleur de la lumière (rouge, orange) ; 1 : `--fusee-coeur`, toujours de la couleur de la lumière ;
## 0 : `--sans-fusee-coeur`, le choix d'ISO3/ISO4. La règle « jamais de blanc » (`fusee.gd`, FU2.1) reste entière pour la
## LUMIÈRE : l'exception ne vaut que pour ce point, qui n'éclaire rien. La vue de dessus garde son point rouge.
var coeur_fusee := 2

var miroirs: Node = null      # MiroirsIso : il tient le registre des dessins retirés des lightmaps
var _suivis := {}             # "instance_id:cle" de la source -> Dictionary
var _plan := PlaneMesh.new()
var _disque_juge: ArrayMesh = null
var _quad := QuadMesh.new()
var _masques := false


## ISO13, lot E — le drapeau du faisceau. ⚠️ Il se passe APRÈS `--`, comme `--corps=` : la lecture se
## fait sur les arguments UTILISATEUR. Lu ici plutôt que dans un banc pour qu'il porte partout — jeu,
## banc de cadence, photographe — sans qu'aucun d'eux n'ait à le connaître.
const DRAPEAU_FAISCEAU := "--faisceau"
## Q41 — le rayon dans l'air, distinct du cœur seul : la garde de `--faisceau` (aucune couche) reste vraie mot pour mot.
const DRAPEAU_FAISCEAU_AIR := "--faisceau-air"
## Q41 — l'éteindre : build de débogage seulement, comme `--sans-fumee-masque` (un joueur ne choisit pas l'image de l'adversaire).
const DRAPEAU_SANS_FAISCEAU_AIR := "--sans-faisceau-air"
## L'allègement de la 0.8.0 — les carrés d'avant (`faisceau_taille` faux), build de débogage seulement.
const DRAPEAU_FAISCEAU_CARRE := "--faisceau-air-carre"
## L'allègement de la 0.8.0 — l'option du juge taillé (`faisceau_juge_taille`), build de débogage seulement.
const DRAPEAU_FAISCEAU_JUGE_TAILLE := "--faisceau-juge-taille"
const DRAPEAU_SANS_POINT_LUMINEUX := "--sans-point-lumineux"
const DRAPEAU_MASQUE_FUMEE := "--fumee-masque"
const DRAPEAU_SANS_MASQUE_FUMEE := "--sans-fumee-masque"
## Les formes du masque (voir `forme_masque` et `volume_masque_compact.gdshaderinc`) : 1, la même réponse écrite une fois par
## surface (MASQUE_COMPACT) ; 2, + la bande du sol resserrée (MASQUE_RESSERRE) ; 3, + le pochoir : un juge par volume pose la
## question une fois par pixel, les couches ne la posent plus (MASQUE_POCHOIR). Session cloud « masque-fumée-2 » (2026-09-28) :
## 4, + les certitudes du sol tirées de la lumière lue seule, avant la pâte et la matière (MASQUE_LUMIERE) ; 5, + le juge
## ajusté à son volume : un disque, au lieu du carré, qui ne rastérise plus les coins où aucune couche ne dessine
## (MASQUE_AJUSTE : aucun code GLSL à lui ; il nomme la variante, pour qu'une prise prouve son bras par ce que le jeu dit).
const FORMES_MASQUE := {"--fumee-masque-compact": 1, "--fumee-masque-resserre": 2, "--fumee-masque-pochoir": 3,
	"--fumee-masque-lumiere": 4, "--fumee-masque-ajuste": 5}
const FORME_POCHOIR := 3
const FORME_AJUSTEE := 5
## Le juge ajusté est un polygone régulier CIRCONSCRIT à son disque (apothème 0,5 à l'échelle 1, comme le plan de côté 1) :
## seize côtés, 1,9 % de plus que le disque en rayon, 1,3 % en aire.
const COTES_JUGE := 16
const DEFINES_FORMES := [[], ["MASQUE_COMPACT"], ["MASQUE_COMPACT", "MASQUE_RESSERRE"],
	["MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR"],
	["MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR", "MASQUE_LUMIERE"],
	["MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR", "MASQUE_LUMIERE", "MASQUE_AJUSTE"]]
const NOMS_FORMES := ["celle de Gadgets", "compacte (MASQUE_COMPACT)", "compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE)",
	"pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR)",
	"lumière d'abord, pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR, MASQUE_LUMIERE)",
	"juge ajusté, lumière d'abord, pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR, "
	+ "MASQUE_LUMIERE, MASQUE_AJUSTE)"]
## Le juge du pochoir est dessiné juste AVANT les couches : il doit avoir écrit le pochoir quand elles le lisent.
const PRIORITE_JUGE := PRIORITE_VOLUME - 1
const DRAPEAU_COEUR_FUSEE := "--fusee-coeur"
const DRAPEAU_COEUR_FUSEE_BLANC := "--fusee-coeur-blanc"
const DRAPEAU_SANS_COEUR_FUSEE := "--sans-fusee-coeur"
## Le cœur presque blanc de l'essai : celui de l'illustration « Créer en ligne » (254, 238, 238), mesuré par la session
## cloud sur l'original. La sortie 3D le plafonne à ~230 (la courbe d'écran, voir la ROADMAP).
const COULEUR_COEUR_BLANC := Color(1.0, 0.93, 0.93)
## Le rouge du point après le plein feu (Q34 = C, « puis rouge ») : le rouge de détresse de la lumière au départ,
## `Fusee.COULEUR_DETRESSE`, recopié et non nommé — `fusee.gd` nomme des autoloads, et le nommer ici empêcherait ce script
## de compiler sous `--script` (les suites). `test_iso_gadgets` garde l'égalité des deux.
const COULEUR_COEUR_ROUGE := Color(0.96, 0.293, 0.334)
## LE PLANCHER de l'éclat du point (Adrien, 2026-09-29 : « Le point rouge : oui, dans la 0.8.0 », à la question « le point rouge de la
## fusée, quand elle retombe en braise, est 3,6 fois moins lumineux que l'ancien point orange, et le repère se perd : le rendre aussi
## lumineux que sa lumière, en gardant le rouge ? »). Depuis Q34 = C le point est du rouge de détresse, en MÉLANGE, à l'éclat de la
## lumière (`énergie / 0,8 × opacité du cœur 2D`) : au résidu (16 s, énergie 0,2) il valait 0,167 du rouge — (39, 10, 12) à l'image,
## plus sombre que le sol qu'éclaire la fusée et trois à quatre fois moins clair que l'ancien point orange, qui s'ADDITIONNAIT au sol.
## Son éclat ne descend donc plus sous `PLANCHER_ECLAT_PAR_ENERGIE × l'énergie de la lumière` (borné à 1 : un rouge ne porte pas plus
## que lui-même). **La règle** : à chaque âge après le plein feu, le point vaut au moins sa lumière PLUS ce que l'ancien point y
## ajoutait — `luma(lumière) × (min(énergie, 1) + min(éclat d'avant, 1))` — dans la limite de ce que le rouge peut porter. Un sol n'est
## jamais plus clair que la lumière qui le frappe et l'ancien point s'y ajoutait : un point qui COUVRE le sol et vaut cette somme n'est
## plus sombre que l'ancien sur aucun sol. Au résidu (l'ambre, 0,715 ; l'éclat d'avant valant énergie / 1,2), la somme est
## 1,633 × (1 + 1/1,2) = 2,994 fois l'énergie en éclat du point ; 3,5 laisse 17 % de marge.
## **Ce qui ne bouge pas** : le plein feu (presque blanc, éclat 1,5) et le braise (énergie ≥ 1,2 : éclat plein, le rouge à son maximum
## — c'est là que la lumière, l'ambre × 1,2, est plus claire que ne peut l'être un rouge saturé, et « en gardant le rouge » l'emporte) ;
## la lumière du jeu (le point n'éclaire rien) ; la couleur du point (rouge à tout éclat : teinte 356°, saturation ≥ 0,69).
## Preuves : `tools/test_point_braise.gd` (la règle, à chaque pas, sans fenêtre), `tools/test_iso_gadgets.gd` (le vrai halo), et à
## l'image `tools/planche_braise.gd` — `docs/iso/braise/`.
const PLANCHER_ECLAT_PAR_ENERGIE := 3.5
## La taille du cœur posé : celle du cœur de la comète (`_suivre_comete`), en pixels de monde.
const TAILLE_COEUR_FUSEE := 10.0
## Sa hauteur : au sommet de la braise du voxel (`VoxelObjet.FUSEE_BRAISE_Y0` + sa hauteur), un peu au-dessus. À la hauteur de
## la lumière (0,15 tuile), il tombait DANS le voxel, qui en masquait le centre : un anneau autour de la tige, pas un point
## (premier essai, 2026-09-25 21:50).
const HAUTEUR_COEUR_FUSEE_PX := (VoxelObjet.FUSEE_BRAISE_Y0 + VoxelObjet.FUSEE_BRAISE.y) * TUILE + 0.3 * TAILLE_COEUR_FUSEE


func _init() -> void:
	name = "Volumes"
	_plan.size = Vector2.ONE
	_quad.size = Vector2.ONE
	for arg in DrapeauxDeLancement.arguments():
		if arg == DRAPEAU_FAISCEAU:
			faisceaux_actifs = true
		elif arg == DRAPEAU_FAISCEAU_AIR:
			faisceau_air = true
		elif arg.begins_with(DRAPEAU_FAISCEAU_AIR + "="):
			faisceau_air = true
			densite_faisceau_air = maxf(0.0, float(arg.trim_prefix(DRAPEAU_FAISCEAU_AIR + "=")))
		elif arg == DRAPEAU_SANS_FAISCEAU_AIR and OS.is_debug_build():
			faisceau_air = false
		elif arg == DRAPEAU_FAISCEAU_CARRE and OS.is_debug_build():
			faisceau_taille = false
		elif arg == DRAPEAU_FAISCEAU_JUGE_TAILLE and OS.is_debug_build():
			faisceau_juge_taille = true
		elif arg == DRAPEAU_SANS_POINT_LUMINEUX and OS.is_debug_build():
			point_lumineux = false
		elif arg == DRAPEAU_MASQUE_FUMEE:
			masque_fumee = true
		elif arg == DRAPEAU_SANS_MASQUE_FUMEE and OS.is_debug_build():
			masque_fumee = false
		elif FORMES_MASQUE.has(arg):
			masque_fumee = true
			forme_masque = int(FORMES_MASQUE[arg])
		elif arg == DRAPEAU_COEUR_FUSEE:
			coeur_fusee = 1
		elif arg == DRAPEAU_COEUR_FUSEE_BLANC:
			coeur_fusee = 2
		elif arg == DRAPEAU_SANS_COEUR_FUSEE:
			coeur_fusee = 0
	if faisceaux_actifs:
		print("[faisceau] allumé — le cœur chaud seul, sans rayon")
	# Les deux états s'impriment : une prise prouve le sien par ce que le JEU dit, jamais par la commande.
	if faisceau_air:
		print("[faisceau air] allumé — %d couches lumineuses (additives) sous %.2f tuile (murets %.2f), densité %.3f, masque pochoir forcé"
			% [int(VOLUME_FAISCEAU_AIR["couches"]), float(VOLUME_FAISCEAU_AIR["hauteur"]), MapGeometry.HAUTEUR_MUR_BAS,
			densite_du_faisceau_air()])
		# L'allègement de la 0.8.0 : la forme des couches et du juge, dite par le JEU (une prise prouve son bras par cette ligne).
		print("[faisceau air] %s" % (("taillé à son cône — couches en éventail, juge %s (allègement de la 0.8.0)"
			% ("en éventail aussi (%s, option, build de débogage)" % DRAPEAU_FAISCEAU_JUGE_TAILLE if faisceau_juge_taille
				else "en disque, comme avant")) if faisceau_taille
			else "en carrés, comme avant l'allègement (%s, build de débogage)" % DRAPEAU_FAISCEAU_CARRE))
	else:
		print("[faisceau air] éteint (%s)" % DRAPEAU_SANS_FAISCEAU_AIR)
	if coeur_fusee != 2:
		print("[fusée cœur] %s" % ("éteint (%s)" % DRAPEAU_SANS_COEUR_FUSEE if coeur_fusee == 0
			else "de la couleur de la lumière, sans le blanc (%s)" % DRAPEAU_COEUR_FUSEE))
	# L'état éteint s'imprime aussi : la référence d'une série se prouve par ce que le JEU dit, jamais par la commande.
	if not masque_fumee:
		print("[fumée masque] éteint (%s, build de débogage) — le shader des volumes d'avant" % DRAPEAU_SANS_MASQUE_FUMEE)


func nombre_de_suivis() -> int:
	return _suivis.size()


## L'entrée suivie pour un nœud 2D, ou `{}`. Clés : `genre` (« volume », « fumee », « comete », « lueur »,
## « braises », « lentille », « eclair », « eclat », « onde », « toile »), `noeuds` (les `MeshInstance3D`),
## `mats` (leurs matériaux), `retires` (les dessins 2D sortis des lightmaps).
## `cle` : 0 pour l'entrée principale d'une source (volume, fumée, comète, onde, éclat), 1 pour sa lueur
## (lueur posée, braises, lentille, éclair), 2 pour la toile du voile.
func suivi_de(noeud: Object, cle: int = 0) -> Dictionary:
	return _suivis.get(_cle(noeud, cle), {}) if noeud != null else {}


static func _cle(source: Object, cle: int) -> String:
	return "%d:%d" % [source.get_instance_id(), cle]


func suivis() -> Array:
	return _suivis.values()


func masquer(masques: bool) -> void:
	_masques = masques


## Une image. `main` : le jeu ; `vues` : ids des vues projetées ; `presentation` : pour les corps voxel.
func suivre(main: Node, vues: Array, style: int, presentation: Node) -> void:
	if not images_actives:
		vider()
		return
	var vus := {}
	var conteneur: Node = main.get("bullet_container")
	if conteneur != null:
		for noeud in conteneur.get_children():
			if not (noeud is Node2D) or (noeud as Node).is_queued_for_deletion():
				continue
			if "_atterrie" in noeud and "graine" in noeud:
				_suivre_fusee(noeud as Node2D, vus)
			elif "poseur_id" in noeud and "slug" in noeud:
				_suivre_gadget(noeud as Node2D, String(noeud.get("slug")), vus)
	var arene := main.get("arena") as Node
	if arene != null:
		for noeud in arene.get_children():
			if noeud.get_script() == OndeDeMort:
				_suivre_onde(noeud as Node2D, vus)
	_suivre_eclats(main, presentation, vus)
	if point_lumineux:
		_suivre_lentilles_des_joueurs(main, presentation, vus)
	if faisceaux_actifs:
		for j in [main.get("p1"), main.get("p2")]:
			if j is Node2D and not (j as Node).is_queued_for_deletion():
				_suivre_faisceau(j as Node2D, vus)
	if faisceau_air:
		for j in [main.get("p1"), main.get("p2")]:
			if j is Node2D and not (j as Node).is_queued_for_deletion():
				_suivre_faisceau_air(j as Node2D, vus)
	for id in _suivis.keys():
		if not vus.has(id):
			_retirer(id)
	_pousser_lightmaps(main, vues, style)


func vider() -> void:
	for id in _suivis.keys():
		_retirer(id)


# ---------------------------------------------------------------------------
# LES VOLUMES — étape 3
# ---------------------------------------------------------------------------

func _suivre_gadget(g: Node2D, slug: String, vus: Dictionary) -> void:
	if VOLUMES.has(slug):
		var visuel := g.get_node_or_null(^"Visuel") as Sprite2D
		var spec: Dictionary = VOLUMES[slug]
		var e := _entree(g, "volume", vus)
		_couches(e, int(spec["couches"]))
		var tex: Texture2D = visuel.texture if visuel != null else null
		var demi := float(g.get("rayon")) if "rayon" in g else 60.0
		if tex != null:
			demi = maxf(tex.get_width() * absf(visuel.global_scale.x), tex.get_height() * absf(visuel.global_scale.y)) * 0.5
		var opacite := Presentation3D.opacite_rendue(visuel) if visuel != null else 0.0
		_poser_couches(e, g.global_position, demi, float(spec["hauteur"]), float(spec["densite"]) * opacite,
			tex, visuel.global_rotation if visuel != null else 0.0, float(g.get_instance_id() % 97),
			float(g.call("age")) if g.has_method("age") else 0.0)
	match slug:
		"nappe_braises":
			_suivre_braises(g, vus)
		"torche_fantome":
			_suivre_lentille(g, vus)
		"mine_magnesium":
			_suivre_eclair(g, vus)
		"voile":
			_suivre_toile(g, vus)


func _suivre_fusee(f: Node2D, vus: Dictionary) -> void:
	var lumiere := f.get_node_or_null(^"Halo") as Light2D
	var energie := lumiere.energy if lumiere != null and lumiere.enabled else 0.0
	if not bool(f.get("_atterrie")):
		_suivre_comete(f, lumiere, energie, vus)
		return
	# Posée : la fumée en volume, et une lueur basse qui pulse avec ce qu'elle brûle.
	var alpha := float(f.call("alpha_fumee")) if f.has_method("alpha_fumee") else 0.0
	if volumes_actifs and alpha > 0.0:
		var e := _entree(f, "fumee", vus)
		_couches(e, int(VOLUME_FUSEE["couches"]) if couches_fusee < 0
			else clampi(couches_fusee, 0, int(VOLUME_FUSEE["couches"])))
		_poser_couches(e, f.global_position, float(f.call("rayon_fumee")), float(VOLUME_FUSEE["hauteur"]),
			float(VOLUME_FUSEE["densite"]) * alpha, null, 0.0, float(int(f.get("graine")) % 97),
			maxf(float(f.call("age_combustion")), 0.0))
	if not lueurs_actives:
		return
	var relative := float(f.call("energie_relative")) if f.has_method("energie_relative") else 0.0
	var lueur := _entree(f, "lueur", vus, 1)
	# ISO10, 1c — en mélange : le rouge de détresse ne s'additionne plus au sol rougi (rose, puis blanc).
	_halos(lueur, 1, SHADER_HALO_MELANGE)
	var h := MursBasRendu.HAUTEUR_FUSEE_AU_SOL * TUILE
	var taille := TUILE * (0.6 + 0.6 * relative)
	_poser_halo(lueur, 0, Vector3(f.global_position.x, h, f.global_position.y), taille,
		lumiere.color if lumiere != null else Color.WHITE, 0.45 * relative, 0)
	if coeur_fusee > 0:
		_suivre_coeur_fusee(f, lumiere, energie, vus)


## Q34 (`coeur_fusee`) — le cœur de la fusée posée, comme celui de la comète : un halo à bord franc (forme 1), dont l'éclat
## suit l'énergie et le cœur 2D (ses sursauts d'agonie, son extinction) — et ne tombe JAMAIS sous l'opacité du cœur 2D :
## repris tel quel de la comète (énergie / 0,8 × opacité), il s'effaçait au résidu (0,02), là où le point de braise 2D se
## voit encore — parité avec la 2D (session cloud, 21:54). La lumière du jeu ne change pas : ce halo s'ajoute à l'image
## 3D, il n'éclaire rien.
##
## Q34 = C, la variante 2 (défaut) : presque blanc pendant le plein feu, et SEULEMENT pendant lui, puis ROUGE à tous les
## âges jusqu'au résidu (`couleur_coeur_fusee`). Session cloud « fusée-point », 2026-09-27 — deux écarts à l'image :
## - D1, le point sortait JAUNE PÂLE (230, 230, 146) dès la braise : il prenait la couleur de la LUMIÈRE, orange à la
##   braise (température), et s'ADDITIONNAIT à un sol déjà orange sous un éclat jusqu'à 1,5 — le rouge plafonnait, le
##   vert montait (le mécanisme de la lueur au sol, ISO10 1c). Il est désormais du rouge de détresse, et en MÉLANGE.
## - D3, le blanc débordait d'environ 0,5 s : il suivait l'énergie relative (`smoothstep(0.6, 0.95, relative)`), qui
##   glisse 1,5 s dans la braise, et remontait même sur les sursauts d'agonie (2,5 / 3 = 0,83). Il suit l'ACTE.
## Le mélange est dosé pour que, sur le NOIR, l'image soit celle de l'additif : la couverture est
## `max(éclat, 1)` et la couleur `rouge × min(éclat, 1)`, et comme la forme reste dans [0, 1],
## `rouge × min(é, 1) × clamp(forme × max(é, 1))` = `rouge × clamp(forme × é)`, ce que l'additif posait sur un fond noir.
## Même taille, même repère à distance ; ce qu'il fait au sol éclairé : il le couvre au lieu de s'y ajouter, et reste rouge.
##
## **2026-09-29 (Adrien : « Le point rouge : oui, dans la 0.8.0 ») — l'éclat a un PLANCHER** (`eclat_coeur_fusee`) : à l'agonie et
## au résidu le point rouge, de l'éclat du cœur 2D, valait trois à quatre fois moins que l'ancien point orange et se perdait. Il vaut
## maintenant au moins sa lumière plus ce que l'ancien point y ajoutait, dans la limite de ce que le rouge peut porter
## (`PLANCHER_ECLAT_PAR_ENERGIE`). Le plein feu et le braise ne bougent pas.
func _suivre_coeur_fusee(f: Node2D, lumiere: Light2D, energie: float, vus: Dictionary) -> void:
	var c := _entree(f, "coeur", vus, 2)
	_halos(c, 1, SHADER_HALO_MELANGE)
	var coeur := f.get_node_or_null(^"Coeur") as CanvasItem
	var opacite := coeur.modulate.a if coeur != null else 1.0
	var eclat := eclat_coeur_fusee(energie, opacite)
	var acte := FuseeModele.acte_a(float(f.call("age_combustion"))) if f.has_method("age_combustion") \
		else FuseeModele.Acte.BRAISE
	var couleur := couleur_coeur_fusee(coeur_fusee, acte, lumiere.color if lumiere != null else Color.WHITE)
	couleur = Color(couleur.r * minf(eclat, 1.0), couleur.g * minf(eclat, 1.0), couleur.b * minf(eclat, 1.0))
	_poser_halo(c, 0, Vector3(f.global_position.x, HAUTEUR_COEUR_FUSEE_PX, f.global_position.y), TAILLE_COEUR_FUSEE,
		couleur, maxf(eclat, 1.0) if eclat > 0.002 else 0.0, 1)


## L'éclat du point de braise (`_suivre_coeur_fusee` le prend d'ici) : l'ancien éclat — l'énergie de la lumière / 0,8 × l'opacité du
## cœur 2D, jamais sous cette opacité (parité avec la 2D) —, ou le plancher `PLANCHER_ECLAT_PAR_ENERGIE × énergie` (borné à 1), le plus
## grand des deux. `energie` vaut 0 quand la lumière est éteinte : le plancher tombe avec elle, et le point ne reste pas allumé sans sa
## lumière. Pure, pour la garde de la suite (`tools/test_point_braise.gd`).
static func eclat_coeur_fusee(energie: float, opacite: float) -> float:
	var ancien := maxf(clampf(energie / 0.8, 0.0, 1.5) * opacite, opacite)
	return maxf(ancien, clampf(PLANCHER_ECLAT_PAR_ENERGIE * energie, 0.0, 1.0))


## La couleur du point de braise, avant l'éclat : pure, pour la garde de la suite. Variante 2 (défaut, Q34 = C) : le
## presque-blanc au plein feu, le rouge de détresse de la lumière (`COULEUR_COEUR_ROUGE`) à tous les actes suivants ;
## variante 1 (`--fusee-coeur`) : la couleur de la lumière, comme avant.
static func couleur_coeur_fusee(variante: int, acte: FuseeModele.Acte, couleur_lumiere: Color) -> Color:
	if variante < 2:
		return couleur_lumiere
	return COULEUR_COEUR_BLANC if acte == FuseeModele.Acte.PLEIN_FEU else COULEUR_COEUR_ROUGE


## La comète : la fusée en vol, à la hauteur de sa lumière. Le cœur et le corps dessinés sortent des
## lightmaps pendant le vol (ils y étaient décalés de 18 px factices) ; posée, `MiroirsIso` les reprend.
func _suivre_comete(f: Node2D, lumiere: Light2D, energie: float, vus: Dictionary) -> void:
	var e := _entree(f, "comete", vus)
	for nom in ["Coeur", "Corps"]:
		var s := f.get_node_or_null(NodePath(nom)) as CanvasItem
		if s != null:
			_retirer_dessin(e, s)
	if not lueurs_actives:
		return
	_halos(e, 2)
	var h := float(f.call("hauteur_source")) * TUILE if f.has_method("hauteur_source") else 0.0
	var coeur := f.get_node_or_null(^"Coeur") as CanvasItem
	var couleur := lumiere.color if lumiere != null else Color.WHITE
	var eclat := clampf(energie / 0.8, 0.0, 1.5) * (coeur.modulate.a if coeur != null else 1.0)
	var p := Vector3(f.global_position.x, maxf(h, PLANCHER_PX), f.global_position.y)
	_poser_halo(e, 0, p, 10.0, couleur, eclat, 1)
	_poser_halo(e, 1, p, 46.0, couleur, 0.4 * eclat, 0)


# ---------------------------------------------------------------------------
# LES LUEURS — étape 4
# ---------------------------------------------------------------------------

## Les braises : un tapis de points incandescents, à la lueur de la nappe. Positions tirées de l'identité
## du nœud (mêmes pour les deux vues), scintillement tiré de l'âge du gadget.
func _suivre_braises(g: Node2D, vus: Dictionary) -> void:
	var e := _entree(g, "braises", vus, 1)
	_halos(e, POINTS_BRAISES)
	var lueur := g.get_node_or_null(^"Lueur") as Light2D
	var nappe := g.get_node_or_null(^"Visuel") as CanvasItem
	var part := 0.0
	if lueur != null and lueur.enabled:
		part = clampf(lueur.energy / 1.8, 0.0, 1.0)
	part *= Presentation3D.opacite_rendue(nappe) if nappe != null else 1.0
	var rayon := float(g.get("rayon")) if "rayon" in g else 68.0
	var age := float(g.call("age")) if g.has_method("age") else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(g.global_position.round()))
	for i in POINTS_BRAISES:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * rayon * 0.75
		var phase := rng.randf() * TAU
		var p := g.global_position + Vector2(cos(a), sin(a)) * r
		var scintille := 0.65 + 0.35 * sin(age * (2.0 + rng.randf() * 3.0) + phase)
		_poser_halo(e, i, Vector3(p.x, 1.5 + rng.randf() * 2.5, p.y), 3.0 + rng.randf() * 2.0,
			Charte.AMBRE, part * scintille, 1)


func _suivre_lentille(g: Node2D, vus: Dictionary) -> void:
	var e := _entree(g, "lentille", vus, 1)
	_halos(e, 1)
	var lentille := g.get_node_or_null(^"Lentille") as CanvasItem
	if lentille != null:
		_retirer_dessin(e, lentille)
	var faisceau := g.get_node_or_null(^"Faisceau") as Light2D
	var part := clampf(faisceau.energy / 2.5, 0.0, 1.0) if faisceau != null and faisceau.enabled else 0.0
	var p := g.to_global(Vector2(10.0, 0.0))
	_poser_halo(e, 0, Vector3(p.x, HAUTEUR_LENTILLE * TUILE, p.y), 5.0,
		lentille.get("color") if lentille != null else Charte.HALOGENE, part, 1)


## ISO13, lot E — LE CŒUR CHAUD À LA LAMPE, et lui seul.
##
## Le lot devait aussi rendre le RAYON visible dans l'air. **Il s'arrête**, sur décision de la session cloud
## (2026-09-24, 02:03), et il n'en reste rien ici — pas une densité à zéro, qui poserait encore des couches
## et coûterait sans rien dessiner. Trois raisons, mesurées (`docs/iso/iso13/plan_lots_d_e.md`) :
## - il ne se lit à aucune densité : 3/255 de médiane dans le cône au mieux ;
## - il salit le noir dès qu'il commence à se voir : une couche EN HAUTEUR est dessinée plus haut que le
##   sol qu'elle lit (parallaxe, tangage 52°) — 307 pixels isolés dans le noir à 0,45, 15 couches posées
##   au sol, 1 de bruit ;
## - il rendrait à la lampe une hauteur qu'une décision d'Adrien lui refuse face aux murets (2026-09-15).
## Ce qu'il faudrait pour qu'il revienne est écrit à la ROADMAP.
##
## Le cœur, lui, est une lueur à la lampe même, comme la lentille de la torche fantôme : une source, pas
## un volume, et il ressemble aux deux illustrations (accueil, intro « allumage »).
func _suivre_faisceau(j: Node2D, vus: Dictionary) -> void:
	var lampe := j.get_node_or_null(^"Flashlight") as PointLight2D
	if lampe == null or not lampe.enabled or lampe.energy <= 0.0:
		return
	var centre := lampe.global_position
	var part := clampf(lampe.energy / 2.5, 0.0, 1.0)
	var c := _entree(j, "coeur_lampe", vus, 1)
	_halos(c, 1)
	_poser_halo(c, 0, Vector3(centre.x, HAUTEUR_COEUR_LAMPE * TUILE, centre.y),
		TAILLE_COEUR_LAMPE, lampe.color, part, 1)


## Q41 — LE RAYON DE LA TORCHE DANS L'AIR, ALLUMÉ PAR DÉFAUT et LUMINEUX (Adrien, 2026-09-28 ; `--sans-faisceau-air` l'éteint
## en build de débogage). Essai de la session cloud « faisceau-air », rendu lumineux par la session « faisceau-visible » :
## ses couches AJOUTENT la lumière lue sous elles (`FAISCEAU_LUMINEUX`, mélange additif) — l'exception qu'Adrien accorde au
## faisceau seul à « rien de plus clair que la surface qui le porte ».
##
## Le rayon retiré le 2026-09-24 (`d8e928a`, `4afbc3c`), repris avec ce qui l'avait fait retirer :
## - **la forme est la texture de la lampe elle-même**, tournée comme elle : le cône ne peut pas diverger de la lumière ;
## - **les couches sont celles de tout volume** : chacune lit la lightmap de la caméra qui la dessine, sans gain — le rayon
##   d'un adversaire ne montre que la lumière que ce joueur voit déjà au sol, et vaut zéro hors de sa lumière DANS LE MONDE ;
## - **sous les murets** (`VOLUME_FAISCEAU_AIR`, 0,36 < 0,40 tuile) : il ne rend pas à la lampe la hauteur que la décision
##   d'Adrien du 2026-09-15 lui refuse ;
## - **le masque pochoir, toujours** (`FORME_POCHOIR`, quel que soit le masque de la fumée) : À L'ÉCRAN, une couche se tait là
##   où ce que le pixel montre derrière elle s'affiche noir — c'est ce qui manquait le 24/09 (le lissage et la parallaxe
##   posaient le rayon sur du noir). La fumée n'en est pas touchée, et la bascule des bancs ne touche pas au rayon.
## La poussière est le grain que le shader applique déjà à l'alpha, animé par `age` : pas un objet de plus.
##
## **L'allègement de la 0.8.0** (`faisceau_taille`, défaut) : ses couches sont TAILLÉES au cône du cookie
## (`_tailler_faisceau_air`) au lieu d'être des carrés posés sur toute la texture de la lampe à son échelle ; son juge garde
## son disque (`faisceau_juge_taille`, une option éteinte : elle change la fumée).
func _suivre_faisceau_air(j: Node2D, vus: Dictionary) -> void:
	var lampe := j.get_node_or_null(^"Flashlight") as PointLight2D
	# L'allègement : l'enveloppe du cookie et les éventails se calculent dès que le joueur est là (au décompte, lampe éteinte),
	# une fois par cookie (et par portée pour le juge) — jamais à l'image où la lampe s'allume, où ce serait un hoquet.
	if faisceau_taille and lampe != null and lampe.texture != null:
		_eventails_du_faisceau(lampe.texture, _portee_du_faisceau(lampe), faisceau_juge_taille)
	if lampe == null or not lampe.enabled or lampe.energy <= 0.0 or lampe.texture == null:
		return
	# La portée du cône, en pixels de monde : la texture, à son échelle, centrée sur la lampe.
	var rayon := _portee_du_faisceau(lampe)
	if rayon <= 1.0:
		return
	var part := clampf(lampe.energy / 2.5, 0.0, 1.0)
	var e := _entree(j, "faisceau_air", vus, CLE_FAISCEAU_AIR)
	_couches(e, int(VOLUME_FAISCEAU_AIR["couches"]), FORME_POCHOIR, true)
	# L'allègement, option du juge taillé : il se pose dans `_tailler_faisceau_air`, et `_poser_juge` n'y pose alors ni son
	# disque ni son échelle (sinon le maillage changerait deux fois par image).
	if faisceau_taille and faisceau_juge_taille:
		e["juge_taille"] = true
	else:
		e.erase("juge_taille")
	_poser_couches(e, lampe.global_position, rayon, float(VOLUME_FAISCEAU_AIR["hauteur"]),
		densite_du_faisceau_air() * part, lampe.texture, lampe.global_rotation,
		float(j.get_instance_id() % 97),
		age_faisceau_fige if age_faisceau_fige >= 0.0 else float(Time.get_ticks_msec()) * 0.001)
	_tailler_faisceau_air(e, lampe.texture, rayon, lampe.global_rotation)


## La portée du rayon, en pixels de monde : la demi-largeur de la texture de la lampe, à son échelle.
static func _portee_du_faisceau(lampe: PointLight2D) -> float:
	return 0.5 * float(lampe.texture.get_width()) * lampe.texture_scale


# ---------------------------------------------------------------------------
# L'ALLÈGEMENT DE LA 0.8.0 — le rayon taillé à son cône
# ---------------------------------------------------------------------------
#
# Adrien, 2026-09-30, 15:36 : « Oui allège d'abord avant de publier la 0.8 ». La série du Mac (Gadgets, 14:25) rendait la 0.8.0
# 0,81 à 0,87 fois moins rapide que la 0.7.1 ; la piste était écrite depuis L1 : les couches du rayon et leur juge étaient des
# CARRÉS posés sur la texture de la lampe à son échelle (le plan de côté 1, le disque du juge), donc leur surface suit le carré de
# la portée — et la portée va au bord de l'écran depuis L1 : deux joueurs × (trois couches + un juge) qui couvraient tout
# l'écran, là où le cookie n'allume qu'un cône (60° au plus depuis L1bis) et le halo court de l'émetteur (~80°, 20 % de la
# portée). Chaque fragment hors du cône se rastérisait, payait son shader jusqu'au `discard` (opacité nulle), et le juge y payait
# le jugement ENTIER du pochoir.
#
# **Ce qui change** : le MAILLAGE des couches seulement, jamais une valeur. Elles deviennent des éventails autour de la lampe,
# tournés avec elle, qui couvrent exactement là où le cookie peut rendre une opacité non nulle (l'enveloppe, filtre bilinéaire
# compris). **Pourquoi l'image est la même** : un fragment calcule tout depuis sa position dans le MONDE (`monde`, le cookie
# relu par `nuage_centre`, `nuage_rayon` et `nuage_angle`), jamais depuis le maillage qui le porte ; chaque fragment gardé
# calcule donc ce qu'il calculait (à l'arrondi près de l'interpolation, qui suit les triangles : ±1/255 sur quelques pixels),
# et chaque fragment retiré se jetait (opacité nulle hors du cookie, `forme` nulle au-delà du disque). Preuve à l'image :
# `tools/loupe_faisceau_taille.gd` ; garde : `tools/test_allegement_faisceau.gd`.
#
# ⚠️ **Le juge, lui, garde son disque** (`faisceau_juge_taille` : une option, éteinte). Taillé à son tour (l'enveloppe dilatée
# de la parallaxe), il ne rendait pas la même image : le pochoir qu'il écrit est lu par TOUS les volumes, et sa marge (16/255)
# est plus large que celle de la fumée (8/255) — sur tout son disque, il taisait les volutes d'une fusée posées sur un sol
# entre 8 et 16/255, hors du cône compris. La fumée n'est pas du ressort de l'allègement : l'option attend Adrien.

## Les secteurs de l'enveloppe, autour de la lampe : 1° chacun, 0° sur l'axe du cookie (celui de la lampe), vers +y de la
## texture ensuite (le sens du shader : `local` est `d` tourné de −`nuage_angle`).
const SECTEURS_FAISCEAU := 360
## Les blocs de texels lus d'un coup : l'image réduite par moyennes, en flottants (`shrink_x2`), vaut non nul sur un bloc si et
## seulement si l'un de ses texels l'est. Huit texels : l'enveloppe déborde le cône d'au plus ~2° à mi-portée.
const BLOC_ENVELOPPE := 8
## Le filtre bilinéaire du cookie (`masque`, `filter_linear`, sans mipmaps) lit un texel jusqu'à un demi-texel au-delà de son
## bord ; un texel entier, pour la marge.
const MARGE_TEXELS := 1.0
## Le juge (à la hauteur de la couche la plus haute) voit chaque couche décalée de (haut − h) / tan(tangage), moins que
## haut − h tant que le tangage dépasse 45° (52° aujourd'hui) — la borne du disque ajusté (`_poser_juge`) ; un pixel de monde de
## plus, pour la marge.
const MARGE_JUGE_PX := 1.0
## La dilatation du juge ne lit les secteurs voisins que jusqu'à cet écart (20°) ; au-delà, ce qu'ils ajoutent tient dans le
## disque de rayon décalage / sin(20°) autour de la lampe, posé d'office.
const ECART_DILATATION := 0.3490658503988659
## Les plages de l'éventail (`eventail`) : au plus dix secteurs par triangle (la corde s'écarte alors de l'arc de 0,4 % au
## plus), d'enveloppe voisine à 10 % près — ou toutes au ras de la lampe (sous 2 % du rayon), où l'écart ne coûte rien.
const SECTEURS_PAR_TRIANGLE := 10
const ECART_DE_PLAGE := 0.1
const RAYON_NEGLIGEABLE := 0.02
## Enveloppe par cookie (Texture2D -> PackedFloat32Array), éventail des couches par cookie (Texture2D -> ArrayMesh), éventail
## du juge par cookie et par portée entière (Texture2D -> {portée: ArrayMesh}). Une fois par processus : les cookies vivent tout
## le jeu (`WeaponData`), et la portée d'une torche ne change qu'avec la classe ou le mode (`accorder_au_mode`).
static var _enveloppes := {}
static var _eventails := {}
static var _eventails_juge := {}


## Taille les couches du rayon (ou leur rend les carrés d'avant, `faisceau_taille` faux) et, en option, son juge
## (`e["juge_taille"]`, posé par `_suivre_faisceau_air`). Appelée APRÈS `_poser_couches` : la position, l'échelle des couches
## (2 × leur rayon) et tous les uniformes restent les siens ; le juge en disque, lui, vient d'y être posé par `_poser_juge`.
func _tailler_faisceau_air(e: Dictionary, tex: Texture2D, rayon: float, angle: float) -> void:
	var noeuds: Array = e["noeuds"]
	var juge: MeshInstance3D = e.get("juge") if is_instance_valid(e.get("juge")) else null
	var juge_taille: bool = e.get("juge_taille", false)
	if juge != null and not juge_taille and juge.rotation != Vector3.ZERO:
		juge.rotation = Vector3.ZERO
	if not faisceau_taille:
		for mi: MeshInstance3D in noeuds:
			if mi.mesh != _plan:
				mi.mesh = _plan
			if mi.rotation != Vector3.ZERO:
				mi.rotation = Vector3.ZERO
		return
	var maillages := _eventails_du_faisceau(tex, rayon, juge_taille)
	# Le plan de côté 1 tourné de −angle autour de la verticale : son +x va sur l'axe de la lampe, son +z sur son côté +y
	# (d = R(angle)·local, la rotation du shader lue à l'envers). L'échelle (2 × rayon de la couche) est celle du carré.
	var tourne := Vector3(0.0, -angle, 0.0)
	for mi: MeshInstance3D in noeuds:
		if mi.mesh != maillages[0]:
			mi.mesh = maillages[0]
		mi.rotation = tourne
	if juge != null and juge_taille:
		if juge.mesh != maillages[1]:
			juge.mesh = maillages[1]
		juge.scale = Vector3(rayon * 2.0, 1.0, rayon * 2.0)
		juge.rotation = tourne


## [éventail des couches, éventail du juge ou null] pour ce cookie (et cette portée, pour le juge), calculés une fois.
static func _eventails_du_faisceau(tex: Texture2D, rayon: float, juge: bool) -> Array:
	var env := enveloppe_du_cookie(tex)
	if not _eventails.has(tex):
		_eventails[tex] = eventail(env)
	if not juge:
		return [_eventails[tex], null]
	var par_portee: Dictionary = _eventails_juge.get(tex, {})
	# La portée ENTIÈRE, arrondie par défaut : un rayon plus petit dilate plus (décalage / rayon), donc l'éventail d'une portée
	# un peu plus courte couvre toujours celle-ci.
	var cle := maxi(1, int(floor(rayon)))
	if not par_portee.has(cle):
		par_portee[cle] = eventail(enveloppe_dilatee(env, decalage_du_juge() / float(cle)))
		_eventails_juge[tex] = par_portee
	return [_eventails[tex], par_portee[cle]]


## Le décalage le plus grand entre une couche et son juge, vu de la caméra, en pixels de monde : haut − h de la couche la plus
## basse (la borne du disque ajusté, `_poser_juge`), plus `MARGE_JUGE_PX`.
static func decalage_du_juge() -> float:
	var haut := maxf(PLANCHER_PX, float(VOLUME_FAISCEAU_AIR["hauteur"]) * TUILE)
	var bas := maxf(PLANCHER_PX, float(VOLUME_FAISCEAU_AIR["hauteur"]) * TUILE / float(int(VOLUME_FAISCEAU_AIR["couches"])))
	return haut - bas + MARGE_JUGE_PX


## L'enveloppe du cookie `tex`, calculée une fois par texture et par processus (`enveloppe_de_l_image`).
static func enveloppe_du_cookie(tex: Texture2D) -> PackedFloat32Array:
	if _enveloppes.has(tex):
		return _enveloppes[tex]
	var env := enveloppe_de_l_image(tex.get_image() if tex != null else null)
	_enveloppes[tex] = env
	return env


## L'ENVELOPPE d'un cookie : pour chacun des `SECTEURS_FAISCEAU` secteurs autour de son centre (la lampe), le rayon jusqu'où
## il peut rendre une opacité non nulle, en unités du disque de la couche (1 = son rayon ; la couche se tait au-delà, `forme` y
## est nulle). Par blocs de `BLOC_ENVELOPPE` texels (l'image réduite par moyennes en flottants : un bloc est non nul si et
## seulement si l'un de ses texels l'est), chaque bloc non nul élargi de `MARGE_TEXELS` puis étendu à tous les secteurs qu'il
## touche, à la distance de son coin le plus loin : une borne, jamais un manque. Sans image lisible : le disque entier
## (aucun allègement, la même image).
static func enveloppe_de_l_image(img: Image) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(SECTEURS_FAISCEAU)
	if img == null or img.is_empty():
		env.fill(1.0)
		return env
	env.fill(0.0)
	var a := img.duplicate() as Image
	if a.is_compressed() and a.decompress() != OK:
		env.fill(1.0)
		return env
	var w := a.get_width()
	var h := a.get_height()
	# En flottants : une moyenne de valeurs positives n'y tombe jamais à zéro (en octets, (1 + 0 + 0 + 0 + 2) >> 2 = 0). Un
	# format sans alpha se lit à 1 partout : l'enveloppe y vaut le disque entier, comme le shader (`texture(masque).a` = 1).
	a.convert(Image.FORMAT_RGBAF)
	var bloc := 1
	while bloc < BLOC_ENVELOPPE and a.get_width() % 2 == 0 and a.get_height() % 2 == 0 and a.get_width() > 1 \
			and a.get_height() > 1:
		a.shrink_x2()
		bloc *= 2
	var aw := a.get_width()
	var ah := a.get_height()
	var donnees := a.get_data().to_float32_array()
	# Un texel vaut 2 / w en unités locales (`local` va de −1 à 1 sur la texture : uv = local × 0,5 + 0,5).
	var sx := 2.0 / float(w)
	var sy := 2.0 / float(h)
	for by in ah:
		for bx in aw:
			if donnees[(by * aw + bx) * 4 + 3] <= 0.0:
				continue
			_etendre(env, (float(bx * bloc) - MARGE_TEXELS) * sx - 1.0, (float(by * bloc) - MARGE_TEXELS) * sy - 1.0,
				(float((bx + 1) * bloc) + MARGE_TEXELS) * sx - 1.0, (float((by + 1) * bloc) + MARGE_TEXELS) * sy - 1.0)
	return env


## Étend l'enveloppe au rectangle [x0, x1] × [y0, y1] (unités locales) : chaque secteur qu'il touche vu de la lampe va au moins
## jusqu'à son coin le plus loin (plafonné à 1). Un rectangle qui contient la lampe touche tous les secteurs.
static func _etendre(env: PackedFloat32Array, x0: float, y0: float, x1: float, y1: float) -> void:
	var n := env.size()
	var loin := minf(1.0, sqrt(maxf(x0 * x0, x1 * x1) + maxf(y0 * y0, y1 * y1)))
	if x0 <= 0.0 and x1 >= 0.0 and y0 <= 0.0 and y1 >= 0.0:
		for s in n:
			env[s] = maxf(env[s], loin)
		return
	# Hors de la lampe, le rectangle se voit sous moins d'un demi-tour : ses coins, relus autour de la direction de son centre.
	var axe := atan2((y0 + y1) * 0.5, (x0 + x1) * 0.5)
	var lo := INF
	var hi := -INF
	for c: Vector2 in [Vector2(x0, y0), Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
		var d := wrapf(atan2(c.y, c.x) - axe, -PI, PI)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	var pas := TAU / float(n)
	for s in range(int(floor((axe + lo) / pas)), int(floor((axe + hi) / pas)) + 1):
		var k := posmod(s, n)
		env[k] = maxf(env[k], loin)


## L'enveloppe DILATÉE de `d` (unités locales) — ce que couvre l'enveloppe quand chacun de ses points peut glisser de `d` dans
## n'importe quelle direction (la parallaxe du juge, dans les deux vues). Pour chaque secteur, le plus loin qu'y porte chaque
## secteur voisin (`portee_dilatee`, à l'écart angulaire le plus petit entre les deux), jusqu'à `ECART_DILATATION` ; au-delà, un
## disque de d / sin(écart), qui les contient tous.
static func enveloppe_dilatee(env: PackedFloat32Array, d: float) -> PackedFloat32Array:
	var n := env.size()
	var pas := TAU / float(n)
	var fenetre := int(ceil(ECART_DILATATION / pas)) + 1
	var plancher := d / sin(ECART_DILATATION)
	var sortie := PackedFloat32Array()
	sortie.resize(n)
	for s in n:
		var m := plancher
		for k in range(-fenetre, fenetre + 1):
			var r := env[posmod(s + k, n)]
			if r > 0.0:
				m = maxf(m, portee_dilatee(r, maxf(0.0, float(absi(k) - 1)) * pas, d))
		sortie[s] = m
	return sortie


## Le plus loin que porte, dans une direction à `ecart` (radians) d'un segment partant de la lampe et long de `r`, ce segment
## épaissi de `d` : un disque de rayon `d` promené le long du segment. Au-delà d'un quart de tour, seul le disque de la lampe.
static func portee_dilatee(r: float, ecart: float, d: float) -> float:
	if ecart <= 0.0:
		return r + d
	if ecart >= PI * 0.5:
		return d
	var s := sin(ecart)
	var c := cos(ecart)
	if r * s <= d * c:
		return r * c + sqrt(maxf(0.0, d * d - r * r * s * s))
	return d / s


## L'ÉVENTAIL qui contient l'enveloppe `env` : la lampe au centre et un triangle par PLAGE — une suite d'au plus
## `SECTEURS_PAR_TRIANGLE` secteurs non vides d'enveloppe voisine (à `ECART_DE_PLAGE` près) —, dont les deux sommets sont au
## plus grand rayon de la plage divisé par cos(demi-plage) : la corde reste au-delà de l'arc. Un sommet partagé par deux plages
## prend le plus grand des deux rayons voulus, et les triangles le partagent par indice (aucune jonction en T : aucun pixel
## dessiné deux fois, aucun oublié). Dans le repère du plan de côté 1 (`_plan`) : un rayon de 1 (celui de la couche) y vaut 0,5,
## l'échelle du nœud reste 2 × rayon.
##
## ⚠️ **Des plages, pas un triangle par degré** : tous les triangles d'un éventail se touchent à la lampe, et un bloc de pixels
## que plusieurs triangles recouvrent passe dans le shader une fois PAR triangle (le rastériseur ombre par blocs de 2 × 2 au
## moins, dérivées obligent). À un triangle par degré, un bloc à 100 px de la lampe en chevauche trois, et l'éventail entier
## repassait ~1,5 fois dans le shader — autant que le carré n'en gagnait (mesuré sous llvmpipe, 2026-09-30).
static func eventail(env: PackedFloat32Array) -> ArrayMesh:
	var n := env.size()
	var pas := TAU / float(n)
	# Les plages, parcourues depuis le premier secteur qui suit un secteur vide (aucune ne chevauche alors le départ) ; sans
	# secteur vide (le juge), depuis 0 — la dernière plage s'arrête au départ.
	var depart := 0
	for i in n:
		if env[i] <= 0.0:
			depart = (i + 1) % n
			break
	var plages: Array[Vector3i] = []   # [premier secteur, nombre de secteurs, indice dans `hauts`]
	var hauts := PackedFloat32Array()
	var k := 0
	while k < n:
		var i := (depart + k) % n
		if env[i] <= 0.0:
			k += 1
			continue
		var lo := env[i]
		var hi := env[i]
		var long := 1
		while long < SECTEURS_PAR_TRIANGLE and k + long < n:
			var v := env[(depart + k + long) % n]
			if v <= 0.0:
				break
			var nlo := minf(lo, v)
			var nhi := maxf(hi, v)
			# Voisines : à `ECART_DE_PLAGE` près, ou toutes sous `RAYON_NEGLIGEABLE` (au ras de la lampe).
			if nhi > nlo * (1.0 + ECART_DE_PLAGE) and nhi > RAYON_NEGLIGEABLE:
				break
			lo = nlo
			hi = nhi
			long += 1
		plages.append(Vector3i(i, long, hauts.size()))
		hauts.append(hi / cos(pas * float(long) * 0.5) * 0.5)
		k += long
	# Un sommet par bord de plage, au plus grand rayon que lui demandent les deux plages qui s'y touchent.
	var voulu := {}   # secteur de bord -> rayon (repère du maillage)
	for p in plages:
		for b in [p.x, (p.x + p.y) % n]:
			voulu[b] = maxf(float(voulu.get(b, 0.0)), hauts[p.z])
	var sommets := PackedVector3Array([Vector3.ZERO])
	var indice := {}
	for b: int in voulu:
		indice[b] = sommets.size()
		var a := pas * float(b)
		sommets.append(Vector3(cos(a) * float(voulu[b]), 0.0, sin(a) * float(voulu[b])))
	var indices := PackedInt32Array()
	for p in plages:
		indices.append_array([0, indice[p.x], indice[(p.x + p.y) % n]])
	var normales := PackedVector3Array()
	normales.resize(sommets.size())
	normales.fill(Vector3.UP)
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	if not indices.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	return m


## La densité d'une couche du rayon : celle du drapeau si on en cherche une, sinon la constante.
func densite_du_faisceau_air() -> float:
	return densite_faisceau_air if densite_faisceau_air > 0.0 else float(VOLUME_FAISCEAU_AIR["densite"])


func _suivre_eclair(g: Node2D, vus: Dictionary) -> void:
	var feu := g.get_node_or_null(^"Embrasement") as Light2D
	var part := clampf(feu.energy / 6.0, 0.0, 1.0) if feu != null and feu.enabled else 0.0
	var e := _entree(g, "eclair", vus, 1)
	_halos(e, 2)
	var p := Vector3(g.global_position.x, HAUTEUR_ECLAIR_MINE * TUILE, g.global_position.y)
	_poser_halo(e, 0, p, 70.0, Charte.HALOGENE, 0.55 * part, 0)
	_poser_halo(e, 1, p, 12.0, Charte.HALOGENE, part, 1)


## L'éclat de bouche au bout de l'arme du corps voxel : le dessin 2D sort des lightmaps (il y était couché
## au canon) et sa lueur se lève à la hauteur de l'arme. Sans corps voxel, au canon, à hauteur de torse.
func _suivre_eclats(main: Node, presentation: Node, vus: Dictionary) -> void:
	var voxels: Array = presentation.get("_voxels") if presentation != null and "_voxels" in presentation else []
	for j in 2:
		var joueur = main.p1 if j == 0 else main.p2
		if not is_instance_valid(joueur):
			continue
		var bouche := (joueur as Node).get_node_or_null(^"Muzzle") as Node2D
		var eclat := bouche.get_node_or_null(^"EclatDessine") as Sprite2D if bouche != null else null
		if eclat == null:
			continue
		var e := _entree(eclat, "eclat", vus, 1)
		_halos(e, 2)
		_retirer_dessin(e, eclat)
		var flash := (joueur as Node).get_node_or_null(^"MuzzleFlash") as Light2D
		var part := Presentation3D.opacite_rendue(eclat)
		if flash == null or not flash.enabled:
			part = 0.0
		var bout: Variant = _bout_de_l_arme(voxels[j] if j < voxels.size() else null)
		if bout == null:
			bout = Vector3(bouche.global_position.x, MursBas.HAUTEUR_DEBOUT * 0.6 * TUILE, bouche.global_position.y)
		_poser_halo(e, 0, bout, 30.0, eclat.modulate, 0.8 * part, 0)
		_poser_halo(e, 1, bout, 8.0, eclat.modulate, part, 1)


## Chantier des lumières de la 0.8.0, L3 — LE POINT LUMINEUX À LA LENTILLE (Q46, Adrien, 2026-09-29 : « le point lumineux
## doit être visible si la source de la lumière est visible dans la vue du joueur […] Si son corps est devant, on ne voit
## pas le point lumineux »).
##
## Deux lueurs (le cœur franc, et un halo doux autour) posées au bout du fût de la torche du corps voxel
## (`VoxelCorps.pointe_torche`, le point d'où part la lumière depuis L2), à l'énergie de SA lampe : lampe éteinte ou
## grésillante, point éteint ou faible — le noir absolu tient. Ce qu'on voit, c'est la source elle-même, que la lumière 2D
## ne dessine pas (une lampe n'éclaire pas sa propre lentille).
##
## **Visible seulement si la lentille l'est, depuis la caméra de CE joueur** — deux conditions, chacune tenue là où elle
## se juge :
## - **le verre regarde-t-il la caméra ?** Une lampe vue de dos montre son culot, pas sa lumière. Le shader
##   (`lentille_orientee`, `halo_iso.gdshaderinc`) pèse chaque lueur par l'orientation de la lentille face à la caméra
##   QUI DESSINE : en écran scindé, chaque vue a sa caméra (J2 à 225°), et chacune juge pour elle — aucune différence J1/J2.
##   La même formule, en GDScript, pour les gardes : `visibilite_lentille`.
## - **quelque chose est-il devant ?** La profondeur : les lueurs lisent le tampon de profondeur où le corps voxel, le
##   fût de la torche et les murs 3D sont déjà écrits. Le corps devant la lampe la cache ; le mur aussi.
## Ni la simulation, ni l'éblouissement, ni les capteurs ne lisent ces lueurs : une image, comme toutes celles d'ici.
func _suivre_lentilles_des_joueurs(main: Node, presentation: Node, vus: Dictionary) -> void:
	var voxels: Array = presentation.get("_voxels") if presentation != null and "_voxels" in presentation else []
	for j in 2:
		var joueur = main.p1 if j == 0 else main.p2
		if not is_instance_valid(joueur) or (joueur as Node).is_queued_for_deletion():
			continue
		var lampe := (joueur as Node).get_node_or_null(^"Flashlight") as Light2D
		var corps: Variant = voxels[j] if j < voxels.size() else null
		if lampe == null or not (corps is Node3D) or not is_instance_valid(corps) \
				or not (corps as Node3D).is_visible_in_tree() or not (corps as Node3D).has_method("pointe_torche"):
			continue
		var part := clampf(lampe.energy / 2.5, 0.0, 1.0) if lampe.enabled and lampe.is_visible_in_tree() else 0.0
		var pointe: Dictionary = (corps as Node3D).call("pointe_torche")
		if part <= 0.0 or pointe.is_empty():
			continue
		var e := _entree(joueur as Object, "lentille_joueur", vus, CLE_LENTILLE_JOUEUR)
		_halos(e, 2)
		var direction: Vector3 = pointe["direction"]
		# Posé juste devant le verre : le fût de la torche, derrière, ne le coupe pas.
		var p: Vector3 = (pointe["position"] as Vector3) + direction * AVANT_DU_VERRE_PX
		_poser_halo(e, 0, p, TAILLE_HALO_LENTILLE, lampe.color, INTENSITE_HALO_LENTILLE * part, 0)
		_poser_halo(e, 1, p, TAILLE_POINT_LENTILLE, lampe.color, part, 1)
		for mat: ShaderMaterial in e["mats"]:
			mat.set_shader_parameter("lentille_orientee", true)
			mat.set_shader_parameter("direction_lentille", direction)


## L3 — le point : un cœur franc de 5 px (la lentille de la torche fantôme en fait 5 aussi) et un halo doux de 16 px au tiers
## de sa force. Points de départ, à doser sur les images avec Adrien.
const TAILLE_POINT_LENTILLE := 5.0
const TAILLE_HALO_LENTILLE := 16.0
const INTENSITE_HALO_LENTILLE := 0.35
## Devant le verre, en pixels : assez pour que le fût (derrière) ne coupe pas le cœur, assez peu pour que le corps, s'il est
## devant la lampe, le cache encore.
const AVANT_DU_VERRE_PX := 0.6
## La clé de suivi du point, à côté du cœur chaud (1) et du rayon (3) : un joueur porte les trois.
const CLE_LENTILLE_JOUEUR := 4
## L3 — la LENTILLE vue de face, de profil, de dos : `lisse(DOS, FACE, cos)`, où `cos` est le cosinus entre l'avant de la
## lentille et la direction qui va vers la caméra. La caméra iso plonge de 52° : même visée droit sur elle, le cosinus ne
## dépasse pas cos 52° = 0,62. Pleine vue de face et jusqu'à ~45° de côté ; de profil (0), un reste (16 %) — un verre
## rasant se voit encore, en filet ; de dos (au-delà de −0,1), rien. **Recopié dans le shader** (`halo_iso.gdshaderinc`) :
## `tools/test_point_lumineux.gd` vérifie que les deux disent la même chose.
const LENTILLE_DOS := -0.1
const LENTILLE_FACE := 0.3


## L3 — la part visible d'une lentille orientée `direction` vue d'une caméra dont l'axe arrière (vers la caméra, `basis.z`)
## est `vers_camera` : 1 de face, 0 de dos. La formule du shader, en GDScript.
static func visibilite_lentille(direction: Vector3, vers_camera: Vector3) -> float:
	return smoothstep(LENTILLE_DOS, LENTILLE_FACE, direction.normalized().dot(vers_camera.normalized()))


## Le bout de l'arme du corps voxel, en pixels du monde 3D, ou `null`.
##
## `VoxelCorps.pointe_arme()` (ISO Corps, vague 5, sur `iso-corps`) le dit depuis le maillage réel de l'arme
## à chaque pose ; tant que cette vague n'est pas fusionnée, on lit la boîte sous le pivot `Torse/Arme`.
static func _bout_de_l_arme(corps: Variant) -> Variant:
	if not (corps is Node3D) or not is_instance_valid(corps) or not (corps as Node3D).is_visible_in_tree():
		return null
	if (corps as Node3D).has_method("pointe_arme"):
		# `global_transform` tel quel (précisé par ISO Corps) : l'ancre à l'échelle d'une tuile y est déjà
		# composée, la position sort en pixels du monde 3D. Aucune conversion ici.
		var pointe: Dictionary = (corps as Node3D).call("pointe_arme")
		return pointe.get("position", null)
	var pivot := (corps as Node3D).get_node_or_null(^"Torse/Arme") as Node3D
	if pivot == null:
		return null
	for enfant in pivot.get_children():
		if enfant is MeshInstance3D:
			# La boîte de l'arme est centrée à mi-longueur devant son pivot : le bout est au double.
			return pivot.global_transform * ((enfant as MeshInstance3D).position * 2.0)
	return null


## L'onde de mort : l'anneau couché au sol, testé en profondeur. Le dessin 2D sort des lightmaps.
func _suivre_onde(onde: Node2D, vus: Dictionary) -> void:
	var e := _entree(onde, "onde", vus)
	_retirer_dessin(e, onde)
	if (e["noeuds"] as Array).is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Onde"
		mi.mesh = ImmediateMesh.new()
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_TRAIT
		mat.set_shader_parameter("avec_texture", false)
		mat.set_shader_parameter("couleur", OndeDeMort.RING_COLOR)
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)
	var mi: MeshInstance3D = e["noeuds"][0]
	var anneau: Vector2 = OndeDeMort.anneau_a(float(onde.get("_age")))
	var m := mi.mesh as ImmediateMesh
	m.clear_surfaces()
	mi.visible = anneau.y > 0.0 and not _masques
	if not mi.visible:
		return
	var c := onde.global_position
	var r0 := maxf(anneau.x - anneau.y * 0.5, 0.0)
	var r1 := anneau.x + anneau.y * 0.5
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in OndeDeMort.SEGMENTS + 1:
		var a := TAU * i / OndeDeMort.SEGMENTS
		var d := Vector2(cos(a), sin(a))
		m.surface_set_uv(Vector2(float(i) / OndeDeMort.SEGMENTS, 0.0))
		m.surface_add_vertex(Vector3(c.x + d.x * r0, MiroirsIso.HAUTEUR_QUAD_PX, c.y + d.y * r0))
		m.surface_set_uv(Vector2(float(i) / OndeDeMort.SEGMENTS, 1.0))
		m.surface_add_vertex(Vector3(c.x + d.x * r1, MiroirsIso.HAUTEUR_QUAD_PX, c.y + d.y * r1))
	m.surface_end()


# ---------------------------------------------------------------------------
# LA TOILE DU VOILE — étape 5
# ---------------------------------------------------------------------------

## La toile, debout entre ses piquets : un ruban qui suit l'ondulation de la `Line2D` et montre la lightmap
## au pied de chaque point — la toile telle que la lampe l'éclaire. Le dessin 2D reste dans la lightmap :
## c'est lui qu'elle recopie.
func _suivre_toile(g: Node2D, vus: Dictionary) -> void:
	var toile := g.get_node_or_null(^"Visuel") as Line2D
	if toile == null or toile.points.size() < 2:
		return
	var e := _entree(g, "toile", vus, 2)
	if (e["noeuds"] as Array).is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Toile"
		mi.mesh = ImmediateMesh.new()
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := _materiau_volume()
		mat.set_shader_parameter("ruban", true)
		if masque_fumee and forme_masque >= FORME_POCHOIR:
			_poser_masque(mat, true)
		mat.set_shader_parameter("densite", 0.92)
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)
	var mi: MeshInstance3D = e["noeuds"][0]
	mi.visible = toile.is_visible_in_tree()
	var m := mi.mesh as ImmediateMesh
	m.clear_surfaces()
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var xf := toile.global_transform
	for i in toile.points.size():
		var p: Vector2 = xf * toile.points[i]
		var u := float(i) / float(toile.points.size() - 1)
		m.surface_set_uv(Vector2(u, 1.0))
		m.surface_add_vertex(Vector3(p.x, PLANCHER_PX, p.y))
		m.surface_set_uv(Vector2(u, 0.0))
		m.surface_add_vertex(Vector3(p.x, HAUTEUR_TOILE * TUILE, p.y))
	m.surface_end()


# ---------------------------------------------------------------------------
# LA MÉCANIQUE COMMUNE
# ---------------------------------------------------------------------------

## `cle` distingue plusieurs entrées pour une même source (la fumée et la lueur d'une fusée posée).
func _entree(source: Object, genre: String, vus: Dictionary, cle: int = 0) -> Dictionary:
	var id := _cle(source, cle)
	vus[id] = true
	var e: Dictionary = _suivis.get(id, {})
	if e.is_empty() or e["genre"] != genre:
		_retirer(id)
		e = {"genre": genre, "source": weakref(source), "noeuds": [], "mats": [], "retires": []}
		_suivis[id] = e
	return e


## Une fois par processus : la ligne qui atteste le masque dans le journal, lue sur la variante réellement posée — même forme
## que « [usure] allumée ».
static var _masque_annonce := false
## La variante masquée des volumes, une fois posée. ⚠️ `_pousser_lightmaps` choisit ses matériaux PAR LEUR SHADER : sans elle
## dans son filtre, une couche masquée ne reçoit AUCUNE lightmap et lit la texture par défaut — la fumée s'éclaire partout
## (premier sandwich, 2026-09-25 09:21 : 73 609 pixels fautifs contre 12 855 sans masque, la fumée presque trois fois plus
## claire dans la lumière).
var _shader_masque: Shader = null
## Toutes les variantes des FORMES posées (couches, juges, rubans) : les filtres qui choisissent les matériaux de fumée par leur
## shader doivent les reconnaître toutes (même piège que `_shader_masque`). Vide sans drapeau de forme.
var _formes_posees := {}


## `forme` ≥ 0 : une forme du masque IMPOSÉE à ces couches, quel que soit le masque de la fumée (le rayon de Q41) ; −1 : le
## masque de la fumée décide, comme avant.
func _materiau_volume(forme := -1, lumineux := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_VOLUME
	if forme >= 0:
		_poser_forme_imposee(mat, forme, lumineux)
	elif masque_fumee:
		_poser_masque(mat, true)
	mat.render_priority = PRIORITE_VOLUME
	# Raccords de la vague — la teinte chaude du sol et des murs (ISO7), nulle sans beauté.
	mat.set_shader_parameter("temperature", IsoMateriaux.TEMPERATURE if IsoMateriaux.beaute_active() else 0.0)
	return mat


## ISO13, Q31 — le masque posé sur une couche (ou retiré), sur place : la variante, son facteur, et la ligne qui l'atteste.
func _poser_masque(mat: ShaderMaterial, actif: bool) -> void:
	if not actif:
		mat.shader = SHADER_VOLUME
		return
	mat.shader = variante_masque(IsoMateriaux.usure_essai_active())
	if forme_masque > 0:
		# Le ruban (la toile du voile) ne se masque dans aucune forme (`!ruban`) : sous le pochoir, il garde la forme d'avant,
		# sans test de pochoir — le juge ne le connaît pas.
		var forme := forme_masque
		if forme >= FORME_POCHOIR and mat.get_shader_parameter("ruban") == true:
			forme = FORME_POCHOIR - 1
		mat.shader = variante_forme(mat.shader, forme)
		_formes_posees[mat.shader] = true
	_shader_masque = mat.shader
	_recopier_le_mur(mat)
	if not _masque_annonce:
		_masque_annonce = true
		print("[fumée masque] allumé — variante FUMEE_MASQUE posée (%s) ; point noir de l'écran 3D : %s ; usure %s"
			% ["#define FUMEE_MASQUE dans son code" if mat.shader.code.contains("#define FUMEE_MASQUE\n")
			else "⚠ SANS le #define : variante manquée", POINT_NOIR_ANNONCE,
			"recopiée (#define USURE_ESSAI, comme le sol)" if mat.shader.code.contains("#define USURE_ESSAI\n")
			else "éteinte, comme le sol"])
		# La forme, lue elle aussi dans le code de la variante réellement posée : une prise prouve son bras par cette ligne.
		print("[fumée masque] forme : %s" % forme_annoncee(mat.shader))


## Q41 — la forme du masque IMPOSÉE à des couches (le rayon dans l'air) : la variante, sans toucher à `_shader_masque` (qui
## nomme la variante de la FUMÉE, et que ses filtres reconnaissent) ; `_formes_posees` suffit aux filtres pour la reconnaître.
static var _forme_imposee_annoncee := false


## `lumineux` : Q41, le rayon de la lampe — la variante `FAISCEAU_LUMINEUX` (mélange additif) par-dessus la forme ; le juge du
## pochoir, lui, garde la sienne (il n'écrit aucune couleur).
func _poser_forme_imposee(mat: ShaderMaterial, forme: int, lumineux := false) -> void:
	mat.shader = variante_forme(variante_masque(IsoMateriaux.usure_essai_active()), forme)
	if lumineux:
		mat.shader = IsoMateriaux.variante_definie(mat.shader, "FAISCEAU_LUMINEUX")
	_formes_posees[mat.shader] = true
	_recopier_le_mur(mat)
	if not _forme_imposee_annoncee:
		_forme_imposee_annoncee = true
		print("[faisceau air] masque : %s" % forme_annoncee(mat.shader))


## Le point noir de la sortie 3D, tel que la couche le prend (`POINT_NOIR_ECRIT` de `volume_masque.gdshaderinc`) : imprimé
## avec la ligne du masque, pour qu'une prise dise quelle règle a porté.
const POINT_NOIR_ANNONCE := "écrit sous 8/255 → noir (rampes du 2026-09-25 : 7 → 0, 8 → 1)"
## Les réglages du SOL (`sol_iso.gdshader`) que la couche recopie, sous le nom qu'ils portent chez elle (préfixe `sol_`, le
## mur et la fumée ayant déjà une matière et une température) ; et la température des MURS (préfixe `mur_`).
const PARAMETRES_DU_SOL := {"texture_sol": "sol_texture_sol", "periode_sol_px": "sol_periode_sol_px",
	"force_matiere": "sol_force_matiere", "dalle_px": "sol_dalle_px", "joint_dalle_px": "sol_joint_dalle_px",
	"joint_dalle_reste": "sol_joint_dalle_reste", "temperature": "sol_temperature",
	"temperature_seuil_bas": "sol_temperature_seuil_bas", "temperature_seuil_haut": "sol_temperature_seuil_haut",
	"neutre_avant_pate": "sol_neutre_avant_pate", "dalles": "dalles", "joint_2d_px": "joint_2d_px",
	"contact_corps_rayon_px": "contact_corps_rayon_px", "contact_corps_reste": "contact_corps_reste"}
const TEMPERATURE_DU_MUR := {"temperature": "mur_temperature", "temperature_seuil_bas": "mur_temperature_seuil_bas",
	"temperature_seuil_haut": "mur_temperature_seuil_haut", "neutre_avant_pate": "mur_neutre_avant_pate"}
## Le contact des corps bouge à chaque image : recopié par `_pousser_lightmaps`.
const CONTACT_PAR_IMAGE := ["contact_corps_1", "contact_corps_2"]
## L'USURE, quand elle est allumée : l'interrupteur et la proximité des murs viennent du SOL ; les impacts viennent du MUR, qui
## les reçoit à chaque éclat — recopiés à chaque image avec le contact.
const USURE_DU_SOL := ["usure", "usure_proximite"]
const USURE_DU_MUR := ["usure_impacts", "usure_impacts_n"]
## Les réglages du mur, RECOPIÉS depuis le matériau même des murs de la présentation (la grille de la carte, la peinture, la
## matière des faces, leur pied et leur contact) : la couche juge une face comme `mur_iso.gdshader` la calcule, avec les
## MÊMES valeurs. Sans présentation (une suite headless), la grille reste inactive et seul le sol est jugé.
const PARAMETRES_DU_MUR := ["pied", "texture_face", "periode_face_px", "force_matiere", "contact_px", "contact_reste",
	"grille_murs", "grille_active", "grille_origine_px", "grille_cases", "tuile_px", "peinture", "peinture_active",
	"peinture_origine_px", "peinture_taille_px", "peinture_etalon_px", "peinture_plancher_px"]


func _recopier_le_mur(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("mur_haut_px", MapGeometry.HAUTEUR_MUR_HAUT * TUILE)
	mat.set_shader_parameter("muret_px", MapGeometry.HAUTEUR_MUR_BAS * TUILE)
	var pres := Presentation3D.instance()
	var mur: ShaderMaterial = pres.get("_mat_mur") if pres != null else null
	if mur == null:
		return
	for nom: String in PARAMETRES_DU_MUR:
		mat.set_shader_parameter(nom, mur.get_shader_parameter(nom))
	for nom: String in TEMPERATURE_DU_MUR:
		mat.set_shader_parameter(TEMPERATURE_DU_MUR[nom], mur.get_shader_parameter(nom))
	# Et le SOL de la vue de J1 (`_mat_sols[0]`) : la couche calcule la couleur qu'il écrit.
	var sols: Array = pres.get("_mat_sols")
	if not sols.is_empty() and sols[0] != null:
		for nom: String in PARAMETRES_DU_SOL:
			mat.set_shader_parameter(PARAMETRES_DU_SOL[nom], (sols[0] as ShaderMaterial).get_shader_parameter(nom))
		for nom: String in USURE_DU_SOL:
			mat.set_shader_parameter(nom, (sols[0] as ShaderMaterial).get_shader_parameter(nom))


## La variante masquée des volumes, avec ou sans l'usure. ⚠️ PARITÉ : elle porte USURE_ESSAI si et seulement si le sol la
## porte — le même interrupteur (`IsoMateriaux.usure_essai_active`), lu au même endroit. Sans elle, une usure allumée au sol
## (Q30) assombrirait un sol que la fumée croirait éclairé : la fumée resterait sur un pixel que l'écran montre noir.
static func variante_masque(usure: bool) -> Shader:
	var v := IsoMateriaux.variante_definie(SHADER_VOLUME, "FUMEE_MASQUE")
	return IsoMateriaux.variante_definie(v, "USURE_ESSAI") if usure else v


## La forme du masque (`forme_masque`) sur une variante masquée : ses #define, ajoutés dans l'ordre (chacun compilé une fois).
static func variante_forme(masque: Shader, forme: int) -> Shader:
	var v := masque
	for d: String in DEFINES_FORMES[clampi(forme, 0, DEFINES_FORMES.size() - 1)]:
		v = IsoMateriaux.variante_definie(v, d)
	return v


## Le nom de la forme que porte un shader de fumée, lu dans son code (jamais dans la ligne de commande).
static func forme_annoncee(sh: Shader) -> String:
	var forme := 0
	for k in range(DEFINES_FORMES.size() - 1, 0, -1):
		if (DEFINES_FORMES[k] as Array).all(func(d: String) -> bool: return sh.code.contains("#define %s\n" % d)):
			forme = k
			break
	return NOMS_FORMES[forme]


## ISO13, Q31 — la bascule des bancs : le masque allumé ou éteint sur les couches DÉJÀ posées, au même instant, sans rien
## recréer (la preuve en un seul processus compare la même fumée avec et sans lui).
func poser_masque_fumee(actif: bool) -> void:
	masque_fumee = actif
	for e: Dictionary in _suivis.values():
		# Le rayon de Q41 porte sa forme imposée : la bascule de la FUMÉE ne le touche pas.
		if e.has("forme_imposee"):
			continue
		for m in e["mats"]:
			var s := (m as ShaderMaterial).shader
			if s == SHADER_VOLUME or (s != null and s == _shader_masque) or _formes_posees.has(s):
				_poser_masque(m as ShaderMaterial, actif)


func _couches(e: Dictionary, n: int, forme := -1, lumineux := false) -> void:
	if forme >= 0:
		e["forme_imposee"] = forme
	if lumineux:
		e["lumineux"] = true
	while (e["noeuds"] as Array).size() < n:
		var mi := MeshInstance3D.new()
		mi.name = "Couche%d" % (e["noeuds"] as Array).size()
		mi.mesh = _plan
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := _materiau_volume(forme, lumineux)
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)


## Les couches, de juste au-dessus du sol à `hauteur` tuiles : le rayon se resserre en montant (un nuage
## se lit en dôme) et chaque couche est plus légère que celle d'en dessous.
func _poser_couches(e: Dictionary, centre: Vector2, rayon: float, hauteur: float, densite: float,
		masque: Texture2D, angle: float, graine: float, age: float) -> void:
	var n := (e["noeuds"] as Array).size()
	for i in n:
		var f := float(i) / float(maxi(n - 1, 1))
		var mi: MeshInstance3D = e["noeuds"][i]
		var r := rayon * (1.0 - 0.22 * f)
		mi.position = Vector3(centre.x, maxf(PLANCHER_PX, hauteur * TUILE * float(i + 1) / float(n)), centre.y)
		mi.scale = Vector3(r * 2.0, 1.0, r * 2.0)
		mi.visible = densite > 0.0
		var mat: ShaderMaterial = e["mats"][i]
		mat.set_shader_parameter("nuage_centre", centre)
		mat.set_shader_parameter("nuage_rayon", r)
		mat.set_shader_parameter("nuage_angle", angle)
		mat.set_shader_parameter("densite", densite * (1.0 - 0.45 * f))
		mat.set_shader_parameter("masque", masque)
		mat.set_shader_parameter("avec_masque", masque != null)
		mat.set_shader_parameter("nuage_graine", graine + float(i) * 7.0)
		mat.set_shader_parameter("age", age)
	_poser_juge(e, centre, rayon, hauteur, densite, n)


## Session cloud « masque-fumée » (2026-09-27) — LE JUGE DU POCHOIR (`--fumee-masque-pochoir`), un par volume : un plan à la
## hauteur de la plus haute couche, qui pose la question du masque une fois par pixel et écrit le pochoir (voir
## `volume_masque_compact.gdshaderinc`). Il couvre le disque de chaque couche vu depuis sa hauteur : le rayon de vue s'y
## décale de Δh / tan(tangage), moins que Δh tant que le tangage dépasse 45° (52° aujourd'hui, gardé par la suite) ; un carré
## de demi-côté rayon + hauteur les contient donc toutes, dans les deux vues. Sans la forme pochoir, aucun juge n'existe.
func _poser_juge(e: Dictionary, centre: Vector2, rayon: float, hauteur: float, densite: float, n: int) -> void:
	var juge: MeshInstance3D = e.get("juge") if is_instance_valid(e.get("juge")) else null
	var pochoir := int(e.get("forme_imposee", -1)) >= FORME_POCHOIR or (masque_fumee and forme_masque >= FORME_POCHOIR)
	if not (pochoir and n > 0):
		if juge != null:
			juge.visible = false
		return
	if juge == null:
		juge = MeshInstance3D.new()
		juge.name = "Juge"
		juge.mesh = _plan
		juge.layers = CALQUE
		juge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = _variante_juge_de(e)
		mat.render_priority = PRIORITE_JUGE
		_formes_posees[mat.shader] = true
		_recopier_le_mur(mat)
		juge.material_override = mat
		add_child(juge)
		e["juge"] = juge
		e["juge_forme"] = forme_masque
	elif int(e.get("juge_forme", FORME_POCHOIR)) != forme_masque:
		# Session cloud « masque-fumée-2 » : la forme a changé sous un juge déjà posé (les bancs basculent sur place, entre
		# le pochoir et ce qui s'y ajoute) — il prend la variante de la nouvelle forme ; ses paramètres restent.
		var mj := juge.material_override as ShaderMaterial
		mj.shader = _variante_juge_de(e)
		_formes_posees[mj.shader] = true
		e["juge_forme"] = forme_masque
	var haut := maxf(PLANCHER_PX, hauteur * TUILE)
	var demi := rayon + haut
	var rayons := Vector4.ZERO
	var hauteurs := Vector4.ZERO
	# V5 (juge ajusté) : le disque de la couche i, vu depuis le juge, est décalé de (haut − h_i) / tan(tangage), moins que
	# haut − h_i tant que le tangage dépasse 45° ; il tient donc dans le disque de rayon r_i + (haut − h_i) autour du centre.
	var portee := 0.0
	for i in mini(n, 4):
		var f := float(i) / float(maxi(n - 1, 1))
		rayons[i] = rayon * (1.0 - 0.22 * f)
		hauteurs[i] = maxf(PLANCHER_PX, hauteur * TUILE * float(i + 1) / float(n))
		portee = maxf(portee, rayons[i] + haut - hauteurs[i])
	var ajuste := forme_masque >= FORME_AJUSTEE
	if ajuste:
		demi = portee
	# L'allègement de la 0.8.0, option du juge taillé (`faisceau_juge_taille`) : le rayon de Q41 pose alors SON juge, taillé à
	# son cône (`_tailler_faisceau_air`) — ni disque ni carré ici, sans quoi le maillage changerait deux fois par image.
	if not e.get("juge_taille", false):
		juge.mesh = _disque() if ajuste else _plan
		juge.scale = Vector3(demi * 2.0, 1.0, demi * 2.0)
	juge.position = Vector3(centre.x, haut, centre.y)
	juge.visible = densite > 0.0
	var m := juge.material_override as ShaderMaterial
	m.set_shader_parameter("nuage_centre", centre)
	m.set_shader_parameter("juge_rayons", rayons)
	m.set_shader_parameter("juge_hauteurs", hauteurs)


## Session cloud « masque-fumée-2 » (2026-09-28) — V5 : le polygone du juge ajusté, construit une fois, dans le plan horizontal,
## centré, d'apothème 0,5 (le même repère que le plan de côté 1 : l'échelle est le diamètre).
func _disque() -> ArrayMesh:
	if _disque_juge != null:
		return _disque_juge
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var r := 0.5 / cos(PI / COTES_JUGE)
	for k in COTES_JUGE:
		var a0 := TAU * float(k) / float(COTES_JUGE)
		var a1 := TAU * float(k + 1) / float(COTES_JUGE)
		sommets.append_array([Vector3.ZERO, Vector3(cos(a0) * r, 0.0, sin(a0) * r), Vector3(cos(a1) * r, 0.0, sin(a1) * r)])
		normales.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	_disque_juge = ArrayMesh.new()
	_disque_juge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	return _disque_juge


## Le juge d'une entrée : celui de la forme du moment ; pour le faisceau LUMINEUX (Q41), plus `FAISCEAU_LUMINEUX_JUGE` — sa marge
## au point noir (16/255 au lieu de 8, `volume_masque.gdshaderinc`) : une couche additive ne pardonne pas la lisière.
func _variante_juge_de(e: Dictionary) -> Shader:
	var v := variante_juge(IsoMateriaux.usure_essai_active(), forme_masque)
	return IsoMateriaux.variante_definie(v, "FAISCEAU_LUMINEUX_JUGE") if e.get("lumineux", false) else v


## La variante du juge : la forme (pochoir ou au-delà), plus MASQUE_POCHOIR_JUGE (il écrit le pochoir au lieu de le lire).
static func variante_juge(usure: bool, forme: int = FORME_POCHOIR) -> Shader:
	return IsoMateriaux.variante_definie(variante_forme(variante_masque(usure), maxi(forme, FORME_POCHOIR)),
		"MASQUE_POCHOIR_JUGE")


func _halos(e: Dictionary, n: int, shader: Shader = SHADER_HALO) -> void:
	while (e["noeuds"] as Array).size() < n:
		var mi := MeshInstance3D.new()
		mi.name = "Lueur%d" % (e["noeuds"] as Array).size()
		mi.mesh = _quad
		mi.layers = CALQUE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mi.material_override = mat
		add_child(mi)
		e["noeuds"].append(mi)
		e["mats"].append(mat)


func _poser_halo(e: Dictionary, i: int, position_px: Vector3, taille_px: float, couleur: Color,
		intensite: float, forme: int) -> void:
	var mi: MeshInstance3D = e["noeuds"][i]
	mi.position = position_px
	mi.scale = Vector3.ONE * maxf(taille_px, 0.001)
	mi.visible = intensite > 0.002 and not _masques
	var mat: ShaderMaterial = e["mats"][i]
	mat.set_shader_parameter("couleur", couleur)
	mat.set_shader_parameter("intensite", intensite)
	mat.set_shader_parameter("forme", forme)


## Sort un dessin 2D des lightmaps, par le registre de `MiroirsIso` (une seule main sur `visibility_layer`).
func _retirer_dessin(e: Dictionary, item: CanvasItem) -> void:
	if (e["retires"] as Array).has(item):
		return
	if miroirs != null:
		miroirs.call("_retirer_de_la_lightmap", item)
	e["retires"].append(item)


func _retirer(id: String) -> void:
	var e: Dictionary = _suivis.get(id, {})
	if e.is_empty():
		return
	for item in e["retires"]:
		# Un dessin que le miroir d'un objet posé a repris (le cœur d'une fusée qui vient d'atterrir)
		# reste à lui : c'est lui qui le rendra.
		if miroirs != null and is_instance_valid(item) and not bool(miroirs.call("tient_le_dessin", item)):
			miroirs.call("_rendre_a_la_lightmap", item)
	for mi in e["noeuds"]:
		if is_instance_valid(mi):
			(mi as Node).queue_free()
	if is_instance_valid(e.get("juge")):
		(e["juge"] as Node).queue_free()
	_suivis.erase(id)


## Les lightmaps et leur repère, poussés aux matériaux qui les lisent — la même lecture que le sol
## (`Presentation3D._suivre`), pour les vues projetées et non gelées.
func _pousser_lightmaps(main: Node, vues: Array, style: int) -> void:
	var mats: Array = []
	for e: Dictionary in _suivis.values():
		for m in e["mats"]:
			var s := (m as ShaderMaterial).shader
			if s == SHADER_VOLUME or (s != null and s == _shader_masque) or _formes_posees.has(s):
				mats.append(m)
		var juge: Variant = e.get("juge")
		if juge != null and is_instance_valid(juge) and (juge as MeshInstance3D).visible:
			mats.append((juge as MeshInstance3D).material_override)
	if mats.is_empty():
		return
	# Le contact des corps change à chaque image : recopié du sol de la vue de J1 sur les couches masquées.
	if _shader_masque != null or not _formes_posees.is_empty():
		var pres := Presentation3D.instance()
		var sols: Array = pres.get("_mat_sols") if pres != null else []
		if not sols.is_empty() and sols[0] != null:
			var mur: ShaderMaterial = pres.get("_mat_mur")
			for m in mats:
				if (m as ShaderMaterial).shader == _shader_masque or _formes_posees.has((m as ShaderMaterial).shader):
					for nom: String in CONTACT_PAR_IMAGE:
						(m as ShaderMaterial).set_shader_parameter(nom, (sols[0] as ShaderMaterial).get_shader_parameter(nom))
					if mur != null and (m as ShaderMaterial).shader.code.contains("#define USURE_ESSAI\n"):
						for nom: String in USURE_DU_MUR:
							(m as ShaderMaterial).set_shader_parameter(nom, mur.get_shader_parameter(nom))
	var textures := [main.vp1.get_texture(), main.vp2.get_texture()]
	for id in vues:
		var vue: SubViewport = main.vp1 if id == 0 else main.vp2
		if vue.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			continue
		var canevas: Transform2D = vue.canvas_transform
		var taille := Vector2(vue.size_2d_override) if vue.size_2d_override != Vector2i.ZERO else Vector2(vue.size)
		var n := int(id) + 1
		for m: ShaderMaterial in mats:
			m.set_shader_parameter("lumiere_%d" % n, textures[id])
			m.set_shader_parameter("canevas_%d_x" % n, canevas.x)
			m.set_shader_parameter("canevas_%d_y" % n, canevas.y)
			m.set_shader_parameter("canevas_%d_o" % n, canevas.origin)
			m.set_shader_parameter("taille_%d" % n, taille)
			m.set_shader_parameter("style", style)
