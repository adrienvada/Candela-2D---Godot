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
