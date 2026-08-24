## Voir et être vu dans le noir — la règle géométrique, isolée.
##
## **C'est la mécanique centrale du jeu, et elle n'avait aucun test.** L'étude de
## robustesse du 2026-08-16 le relevait déjà : les suites s'arrêtaient à la
## géométrie des occluders, très en amont du moment où un joueur en éblouit un
## autre. Tout le reste du dépôt est couvert ; la seule chose dont dépend
## l'intérêt du jeu ne l'était pas.
##
## Un fichier sans dépendance, et pas trois lignes de plus dans `game_state.gd` :
## celui-ci nomme des autoloads, donc ne compile pas en mode `--script`, et une
## suite qui le charge annonce « tous les tests passent » sur des appels morts
## (piège consigné le 2026-08-18).
extends RefCounted

## Demi-angle du faisceau, en cosinus — 0,866 vaut 30°, soit un cône de 60°.
##
## Le nombre était écrit en dur dans le contrôle d'éblouissement, deux fois, sans
## dire ce qu'il valait en degrés. Un cône plus large rendrait la torche moins
## coûteuse à allumer : c'est un réglage d'équilibre, il mérite un nom. Depuis le
## 2026-08-18 il n'est plus qu'un DÉFAUT : le cône réel vient de l'arme portée
## (`WeaponData.cos_demi_cone`), et il varie de 5° pour l'arbalète à 60° pour le
## pompe.
const COS_DEMI_CONE := 0.866

## La cible est-elle dans le faisceau de la source ?
##
## `avant` est l'axe du porteur (`global_transform.x`), déjà normalisé par le
## moteur. Le test est un produit scalaire : aucune racine, aucun arc-cosinus.
static func dans_le_cone(avant: Vector2, depuis: Vector2, vers: Vector2,
		cos_demi_cone: float = COS_DEMI_CONE) -> bool:
	# Deux corps exactement superposés : `direction_to` rend le vecteur nul et le
	# produit scalaire vaut 0, donc « hors du cône » — ce qui voudrait dire qu'une
	# torche n'éclaire pas ce qui est collé à elle. La collision l'empêche en
	# pratique ; on le traite quand même, parce qu'un faux silencieux sur une
	# entrée dégénérée est exactement ce qui ne se remarque jamais.
	if depuis.is_equal_approx(vers):
		return true
	return avant.dot(depuis.direction_to(vers)) > cos_demi_cone

## Quelle PART de son faisceau la source verse dans les yeux de la cible : 0
## hors du cône ou hors de portée, 1 dans l'axe et à bout portant.
##
## Reproduit l'atténuation de la texture de torche (`WeaponData.get_torch_texture`) :
## linéaire en distance, avec le même fondu sur l'arête du cône. **Le mécanisme
## doit suivre ce que l'écran montre.** Avant le 2026-08-18 il n'en tenait aucun
## compte : cône de 30° écrit en dur pour toutes les armes et portée infinie.
## Le pompe éclaire à 60° de demi-angle et n'éblouissait que dans les 30
## premiers ; l'arbalète, faisceau de 5°, éblouissait 25° au-delà du sien ; et
## les quatre armes aveuglaient d'un bout à l'autre de la carte, là où le
## faisceau ne pose plus un photon. Un éblouissement qui frappe où la lumière
## n'est pas se lit comme un défaut du jeu, pas comme une règle.
##
## `portee` et `cos_demi_cone` viennent de l'arme portée, jamais d'ici : ce
## fichier ne connaît pas les armes, et c'est ce qui le rend testable seul.
static func intensite_recue(avant: Vector2, depuis: Vector2, vers: Vector2,
		portee: float, cos_demi_cone: float = COS_DEMI_CONE) -> float:
	if portee <= 0.0:
		return 0.0
	if not dans_le_cone(avant, depuis, vers, cos_demi_cone):
		return 0.0
	var distance := depuis.distance_to(vers)
	if distance >= portee:
		return 0.0
	# Collés l'un à l'autre : plein feu, même raison que dans `dans_le_cone` —
	# une entrée dégénérée ne doit pas rendre « pas éclairé ».
	if distance < 0.001:
		return 1.0
	# Le fondu d'arête de la texture, en radians : nul sur le bord du cône,
	# plein sept degrés plus au centre. Recopié du rendu à dessein — deux
	# formules pour un même faisceau finiraient par diverger sans que rien ne
	# le dise.
	var ecart := acos(clampf(avant.dot(depuis.direction_to(vers)), -1.0, 1.0))
	var demi := acos(clampf(cos_demi_cone, -1.0, 1.0))
	var arete := clampf((demi - ecart) * 8.0, 0.0, 1.0)
	return (1.0 - distance / portee) * arete


## La même question, posée à la TEXTURE plutôt qu'à une formule qui la recopie.
##
## **C'est la lecture à préférer partout, et `intensite_recue` ci-dessus n'est
## plus que le repli** — pour une arme sans texture, et pour les tests qui
## veulent une géométrie pure sans image à fabriquer.
##
## ### Pourquoi la copie ne pouvait pas tenir
##
## Le commentaire d'à côté dit « recopié du rendu à dessein — deux formules pour
## un même faisceau finiraient par diverger ». Le risque était juste, le remède
## était le mauvais : **une copie garantit que deux nombres restent égaux, pas
## qu'ils veulent dire la même chose.** Trois divergences en sont sorties, toutes
## mesurées à l'écran le 2026-08-24, et aucune n'a jamais fait rougir une suite :
##
## - **`torch_brightness` n'arrivait pas jusqu'ici.** Il est cuit dans l'alpha de
##   la texture ; la formule l'ignorait. L'arbalète, dont le faisceau est trois
##   fois plus sombre que les autres, éblouissait exactement comme le pistolet —
##   l'arme furtive l'était partout sauf dans ce qu'elle inflige.
## - **Le cône était écrit en dur à 30°** pour quatre armes qui vont de 5 à 60.
## - **Le profil peint des cookies tombe à la moitié dans les flancs** (mesuré à
##   0,49-0,73 de la formule sur `bis04`). La formule aurait puni pour une
##   lumière qui n'est plus là.
##
## Un pixel ne peut pas diverger de lui-même, et il porte tout à la fois :
## l'angle de l'arme, sa portée, sa luminosité, la matière peinte du cookie.
##
## ### Deux conséquences qui ne se devinent pas
##
## **L'échelle vient de l'image, pas d'une constante.** `texture_scale` multiplie
## la taille PROPRE de la texture : un cookie de 1024² porte deux fois plus loin
## qu'un 512² à `torch_scale` égal. En lisant `img.get_size()`, la pénalité suit
## la portée réelle quelle que soit la résolution — il n'y a rien à compenser.
##
## **Le halo entre dans le calcul, et il pèse moins qu'on ne le craint.** La
## texture porte, outre le cône, un halo faible (0,15) sur les 20 % proches de
## l'émetteur et jusqu'à **80°** — pas au-delà. La formule l'ignorait ; le pixel
## ne l'ignore pas. Mesuré plutôt que redouté (2026-08-24) : **0,004 de lumière
## brute à 75° et à un dixième de portée, soit 0,06 de pénalité après la courbe,
## et exactement 0,000 dans le dos** aux trois armes. C'est cohérent avec ce
## qu'on voit — quelqu'un de collé à une torche allumée est un peu éclairé — et
## trop faible pour déplacer un duel. Les deux valeurs sont relevées à chaque
## passage de `planche_eblouissement`, poste « dans-le-dos », pour qu'un cookie
## peint qui élargirait ce halo ne passe pas inaperçu.
static func intensite_texture(img: Image, avant: Vector2, depuis: Vector2,
		vers: Vector2, echelle: float) -> float:
	if img == null or echelle <= 0.0:
		return 0.0
	var taille := img.get_size()
	if taille.x <= 0 or taille.y <= 0:
		return 0.0
	# Du monde vers le repère du faisceau : `avant` est l'axe +x de la texture,
	# et son +y est `Vector2(-y, x)` — c'est-à-dire `avant.rotated(PI/2)`, la
	# colonne y de la transformée du nœud, celle que le moteur emploie pour
	# poser la texture.
	#
	# **Surtout PAS `orthogonal()`, qui rend `Vector2(y, -x)` : l'autre sens.**
	# Écrit ainsi au premier jet, et rattrapé par le contrôle du repère —
	# celui-là même dont le commentaire annonçait que c'était la seule ligne où
	# une erreur de signe passerait inaperçue. Elle serait passée : les quatre
	# textures actuelles sont **symétriques en y**, donc un faisceau retourné
	# rend exactement les mêmes valeurs. Le jour où un cookie peint cesserait de
	# l'être, la pénalité se serait posée du mauvais côté du faisceau, sans que
	# rien ne bouge dans aucune suite.
	var v := vers - depuis
	var local := Vector2(v.dot(avant), v.dot(Vector2(-avant.y, avant.x)))
	var px := Vector2(taille) * 0.5 + local / echelle
	if px.x < 0.0 or px.y < 0.0 or px.x >= float(taille.x) or px.y >= float(taille.y):
		return 0.0
	return clampf(img.get_pixelv(Vector2i(px)).a, 0.0, 1.0)
