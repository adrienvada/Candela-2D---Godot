extends SceneTree

## Recuire un sprite le redimensionne-t-il à l'écran ? (chantier R, étape R6)
##
## **Ce banc existe pour rendre une recuisson GRATUITE.** La décision du
## 2026-08-25 est de recuire toutes les familles d'assets à ×2 : en vue unique le
## duel est rendu à la résolution de la fenêtre depuis le chantier R, et une
## tuile de 35 px tombe à 0,5 texel par pixel en plein écran. Sur-échantillonner
## se règle par mipmaps et coûte de la mémoire ; sous-échantillonner ne se règle
## par rien, aucun filtre ne restitue un détail absent.
##
## Mais recuire n'est gratuit que **là où la taille de la TEXTURE a été
## découplée de l'empreinte en MONDE**. Les lumières l'ont depuis DA2.2
## (`LightTextures.poser()`, verrouillé à quatre résolutions par
## `test_lumieres.gd`). Les sprites ne l'avaient pas : `_poser_sprite()` bâtissait
## son quad à `texture.get_width()`, donc un `fusil.png` recuit de 82 à 164 px
## aurait **doublé la taille du joueur** — et personne n'aurait relié ça à un
## paramètre de cuisson.
##
## ⚠️ **Le dégât ne se serait pas arrêté à la taille.** Le roulis de marche de
## DA2.4 vaut `ROULIS_MARCHE` unités de MONDE. Un joueur deux fois plus grand
## aurait gardé le même roulis, donc une démarche **deux fois plus discrète**,
## sans qu'une ligne de la marche ait bougé. Un réglage calibré à l'œil serait
## devenu faux à cause d'un paramètre de cuisson : c'est le genre de régression
## qu'on ne relie jamais à sa cause.
##
## ## L'égalité exigée, et pourquoi elle est le bon contrôle
##
## Le banc n'a pas d'avis sur la BONNE taille du joueur — elle relève d'un
## arbitrage d'Adrien (« 36 px d'épaules, exactement le diamètre du `Polygon2D`
## qu'il remplace »). Il exige seulement que l'empreinte en monde **ne bouge
## pas** : la table ci-dessous fige ce que chaque arme occupe aujourd'hui.
##
## Recuire à ×2 sans passer `DENSITE_SPRITES` à 2,0 double les empreintes → rouge.
## Passer `DENSITE_SPRITES` à 2,0 sans recuire les divise par deux → rouge aussi.
## **Les deux doivent bouger ensemble, et rien d'autre ne le dirait.** C'est la
## forme de `test_torches.gd` : elle attrape ce qui a bougé quand il ne fallait
## pas, et ce qui n'a pas bougé quand il le fallait.

## ⚠️ **Pas de `preload("res://player.gd")` — il ne compile pas en `--script`.**
## Le fichier référence `NetworkManager` au niveau de la classe, et les autoloads
## n'existent pas dans ce mode : mesuré, ça sort
## « Identifier not found: NetworkManager ». C'est le piège consigné le
## 2026-08-18, et c'est la raison pour laquelle `test_torches.gd` lit lui aussi
## le TEXTE de `game_state.gd` plutôt que ses valeurs. On lit donc les deux
## constantes dans la source — ce qui est le bon niveau de contrôle de toute
## façon : **c'est par le texte que le défaut reviendrait**, quelqu'un changeant
## un nombre sans penser à la recuisson.

## Empreinte au sol de chaque arme, en unités de MONDE. Ce ne sont PAS des
## tailles de fichier : elles s'en déduisent, et cesseront de leur être égales
## le jour de la recuisson.
const EMPREINTES := {
	"fusil": 82.0,
	"pompe": 78.0,
	"pistolet": 62.0,
	"arbalete": 56.0,
}

var _echecs := 0
var _total := 0


func _init() -> void:
	var source := _lire("res://player.gd")
	if source == "":
		_vrai("player.gd lisible", false)
		_verdict()
		return
	# La densité vit dans `Charte` depuis qu'elle sert quatre familles — voir
	# `charte.gd`. Une valeur posée quatre fois finit par diverger.
	var charte := _lire("res://charte.gd")
	var densite := _nombre(charte, "const DENSITE_ASSETS := ")
	var roulis := _nombre(source, "const ROULIS_MARCHE := ")
	_vrai("Charte déclare une densité d'assets",
		not is_nan(densite) and densite > 0.0)
	# ⚠️ Une densité locale rouvrirait la porte : quatre copies, quatre dérives.
	_vrai("player.gd ne redéclare pas sa propre densité",
		not source.contains("const DENSITE_SPRITES :="))
	_vrai("player.gd déclare une amplitude de roulis", not is_nan(roulis))
	if is_nan(densite) or is_nan(roulis):
		_verdict()
		return

	for slug in EMPREINTES:
		var chemin := "res://assets/sprites/%s.png" % slug
		if not ResourceLoader.exists(chemin):
			_vrai("sprite présent : %s" % slug, false)
			continue
		var tex: Texture2D = load(chemin)
		if tex == null:
			_vrai("sprite chargé : %s" % slug, false)
			continue
		_vrai("%s : sprite carré (%dx%d)" % [slug, tex.get_width(), tex.get_height()],
			tex.get_width() == tex.get_height())
		var vue: float = float(tex.get_width()) / densite
		var attendue: float = EMPREINTES[slug]
		_vrai("%s : empreinte %.1f au lieu de %.1f unités de monde"
			% [slug, vue, attendue], is_equal_approx(vue, attendue))

	# ⚠️ **La preuve que recuire ne déplacera rien**, faite sans monter un
	# `Player` : à densité double, une texture double rend la même empreinte.
	# C'est le contrôle que `_poser_sprite()` seul ne permettait pas d'écrire,
	# et son absence est ce qui a laissé le piège en place.
	for slug in EMPREINTES:
		var attendue: float = EMPREINTES[slug]
		var largeur_x2 := int(attendue * 2.0)
		_vrai("%s : recuit ×2, l'empreinte tiendrait (%.1f)" % [slug, attendue],
			is_equal_approx(float(largeur_x2) / 2.0, attendue))

	_test_le_quad_passe_par_l_empreinte(source)
	_test_les_decals_divisent_aussi()
	_test_le_roulis_reste_proportionne(roulis)
	_verdict()


## Le quad ne se bâtit plus sur la largeur brute.
##
## Contrôle sur le TEXTE, et légitime ici pour la raison de `test_torches.gd` :
## c'est par le texte que le défaut reviendrait, quelqu'un recopiant un
## `get_width()` qui « marchait ». Sur le code seul — un commentaire qui
## explique de ne pas le faire contient forcément le motif interdit.
func _test_le_quad_passe_par_l_empreinte(texte: String) -> void:
	var i := texte.find("func _poser_sprite")
	if i < 0:
		_vrai("player.gd pose un sprite", false)
		return
	var suite := texte.substr(i)
	var fin := suite.find("\nfunc ", 1)
	var corps := _sans_commentaires(suite if fin < 0 else suite.substr(0, fin))
	_vrai("le quad passe par empreinte_sprite()",
		corps.contains("empreinte_sprite("))
	_vrai("le quad ne se bâtit pas sur la largeur brute",
		not corps.contains("Vector2(t_peint.get_width()"))


## Les décals aussi, sinon la recuisson casse deux familles sur quatre.
##
## ⚠️ **Non listés par R6 jusqu'au 2026-08-25.** `blood_stain.gd` et
## `wall_impact.gd` dessinaient à `_texture.get_size() * _echelle`, où `_echelle`
## n'est qu'une variation ALÉATOIRE (0,75-1,25 pour le sang, 0,22-0,34 pour les
## éclats) : la taille de base était celle du FICHIER. Recuits à ×2, taches de
## sang et éclats de mur auraient doublé à l'écran — sans erreur, sans warning,
## et sans qu'on relie ça à un paramètre de cuisson.
##
## Trouvés en relisant avec la lunette que DA4 a nommée — *une valeur absolue là
## où il faut un rapport* —, après que la même relecture eut donné le viseur.
func _test_les_decals_divisent_aussi() -> void:
	for chemin in ["res://blood_stain.gd", "res://wall_impact.gd"]:
		var texte := _lire(chemin)
		if texte == "":
			_vrai("%s lisible" % chemin.get_file(), false)
			continue
		var code := _sans_commentaires(texte)
		# Toute taille tirée d'une texture doit être divisée. On cherche la
		# forme fautive plutôt que la forme correcte : c'est elle qui reviendrait.
		var brut := code.contains("get_size() * _echelle\n") \
			or code.contains("get_size() * _echelle)")
		_vrai("%s : aucune taille brute de texture" % chemin.get_file(), not brut)
		_vrai("%s : divise par la densité" % chemin.get_file(),
			code.contains("Charte.DENSITE_ASSETS"))


## Le roulis de marche reste-t-il proportionné au corps ?
##
## ⚠️ **Ce contrôle est un LIEN, pas une mesure.** `ROULIS_MARCHE` (DA2.4) a été
## calibré à l'œil contre un corps d'environ 17 unités de large. Il n'existe
## aucune formule qui donnerait sa « bonne » valeur — mais il existe un rapport
## qui, s'il change, invalide le calibrage sans rien casser de visible. On borne
## donc ce rapport : entre 1 % et 4 % de l'empreinte de l'arme la plus large.
## Aujourd'hui : 1,6 / 82 = 1,95 %.
func _test_le_roulis_reste_proportionne(roulis: float) -> void:
	var plus_large := 0.0
	for slug in EMPREINTES:
		plus_large = maxf(plus_large, EMPREINTES[slug])
	var part: float = roulis / plus_large
	_vrai("le roulis vaut %.2f %% du plus grand sprite (bornes 1 à 4 %%)"
		% [part * 100.0], part >= 0.01 and part <= 0.04)


## Premier nombre qui suit `cle`. NAN si la clé manque — une constante disparue
## doit échouer, pas passer pour un zéro. (Même helper que `test_torches.gd`.)
func _nombre(texte: String, cle: String) -> float:
	var i := texte.find(cle)
	if i < 0:
		return NAN
	var reste := texte.substr(i + cle.length(), 24)
	var brut := ""
	for c in reste:
		if c.is_valid_int() or c == "." or (brut == "" and c == "-"):
			brut += c
		else:
			break
	return NAN if brut == "" else float(brut)


func _verdict() -> void:
	print("test_sprites : %d/%d" % [_total - _echecs, _total])
	quit(1 if _echecs > 0 else 0)


func _sans_commentaires(bloc: String) -> String:
	var sortie := ""
	for l in bloc.split("\n"):
		var nette := l
		var d := nette.find("#")
		if d >= 0:
			nette = nette.substr(0, d)
		if nette.strip_edges() != "":
			sortie += nette + "\n"
	return sortie


func _lire(chemin: String) -> String:
	var f := FileAccess.open(chemin, FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _vrai(quoi: String, ok: bool) -> void:
	_total += 1
	if not ok:
		_echecs += 1
		printerr("  ÉCHEC %s" % quoi)
