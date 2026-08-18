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
## Le nombre était écrit en dur dans `_check_dazzle`, deux fois, sans dire ce
## qu'il valait en degrés. Un cône plus large rendrait la torche moins coûteuse
## à allumer : c'est un réglage d'équilibre, il mérite un nom.
const COS_DEMI_CONE := 0.866

## La cible est-elle dans le faisceau de la source ?
##
## `avant` est l'axe du porteur (`global_transform.x`), déjà normalisé par le
## moteur. Le test est un produit scalaire : aucune racine, aucun arc-cosinus.
static func dans_le_cone(avant: Vector2, depuis: Vector2, vers: Vector2) -> bool:
	# Deux corps exactement superposés : `direction_to` rend le vecteur nul et le
	# produit scalaire vaut 0, donc « hors du cône » — ce qui voudrait dire qu'une
	# torche n'éclaire pas ce qui est collé à elle. La collision l'empêche en
	# pratique ; on le traite quand même, parce qu'un faux silencieux sur une
	# entrée dégénérée est exactement ce qui ne se remarque jamais.
	if depuis.is_equal_approx(vers):
		return true
	return avant.dot(depuis.direction_to(vers)) > COS_DEMI_CONE
