## La couleur de la lumière de la fusée, à chaque température — et l'ESSAI du rouge sang (session cloud « fusée-rouge »,
## 2026-09-27), derrière `--fusee-rouge-sang`, ÉTEINT par défaut.
##
## Sans le drapeau, `couleur_a` rend exactement ce que `fusee.gd` calculait (`COULEUR_DETRESSE.lerp(AMBRE, température)`),
## la même expression : rien ne change, au bit près (`tools/test_fusee_rouge_sang.gd`).
##
## ## Pourquoi un fichier à part
##
## `fusee.gd` dépend de l'autoload `NetworkManager` : une garde lancée par `--script` ne peut pas le compiler (voir
## `test_iso_beaute.gd`, qui lit sa couleur dans son TEXTE). Ce fichier ne dépend que de la charte : la garde l'appelle.
##
## ## Le rouge sang, et ce qu'il garde
##
## Le sol éclairé par la fusée tire vers l'orange (4 à 14° à l'image, 5,5° dans la lightmap) parce que la lumière 2D
## MULTIPLIE le brun des tuiles, (1 ; 0,94 ; 0,62) une fois divisé par la lumière (ROADMAP, ISO13, « Les 8° vers
## l'orange ») : le bleu du sol y perd 38 %, son vert 6 %, et le vert passe devant le bleu. L'illustration
## (`assets/ui/ill_creer_ligne.png`) montre un sol à 353° : le bleu devant le vert. Le rouge sang retire du vert à la
## lumière et lui donne du bleu, assez pour que le sol passe à 353°, sous trois contraintes posées AVANT les mesures :
##  - le canal ROUGE ne bouge pas (0,96) : c'est le canal maximal, celui que lit le capteur du corps adverse
##    (`capteur_adverse.gdshader`, max(R, G, B) × énergie) — sa lecture est donc identique, à tout âge ;
##  - la LUMINANCE de la couleur ne bouge pas (Rec. 709, à 0,03 % près) : c'est ce que lisent le capteur de son propre
##    corps (`capteur_local.gdshader` puis `pate_luminance`) et le seuil commun des dix classes (Q32, 0,10) ;
##  - l'ÉNERGIE ne bouge pas : l'éblouissement ne lit qu'elle (`Fusee.energie_relative`).
## Calcul, sur le brun des tuiles : sol (0,96 ; 0,256 ; 0,335), teinte 353,3°, luminance du sol −1,2 % ; la lumière
## elle-même est à 337° (un rouge framboise, jamais blanc : FU2.1). La braise garde l'ambre : le raccord glisse du rouge
## sang vers lui, et le rouge reste à 0,96 tout du long.
extends RefCounted

const Ch := preload("res://charte.gd")

const COULEUR_SANG := Color(0.96, 0.272, 0.54)
const DRAPEAU_ROUGE_SANG := "--fusee-rouge-sang"
## **Q36 (Adrien, 2026-09-28 : « le rouge le plus proche de l'illustration ») — LE DÉFAUT depuis la 0.7.0.** Lu une fois au
## chargement, comme `FuseeModele.duree_plein_feu`. Visuel seulement : la simulation n'en dépend pas, la luminance du sol non
## plus (seule la teinte bouge). `--sans-fusee-rouge-sang` rend le corail d'avant, en build de débogage seulement ;
## `--fusee-rouge-sang` reste accepté, sans effet. Le rouge vraiment SOMBRE de l'illustration n'est pas celui-ci : il
## changerait ce que le jeu montre (un sol plus sombre montre moins), et n'a pas été proposé.
const DRAPEAU_SANS_ROUGE_SANG := "--sans-fusee-rouge-sang"
static var rouge_sang: bool = not (OS.is_debug_build() and DrapeauxDeLancement.present(DRAPEAU_SANS_ROUGE_SANG))


## Pour les gardes : posé ou retiré sur place.
static func poser_rouge_sang(actif: bool) -> void:
	rouge_sang = actif


## La couleur de la lumière à une température (0 = plein feu, 1 = braise). `detresse` est `Fusee.COULEUR_DETRESSE`,
## passée par l'appelant : la constante reste où `test_iso_beaute.gd` la lit.
static func couleur_a(temperature: float, detresse: Color) -> Color:
	var depart := COULEUR_SANG if rouge_sang else detresse
	return depart.lerp(Ch.AMBRE, temperature)
