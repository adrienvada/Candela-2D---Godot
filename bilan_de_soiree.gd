class_name BilanDeSoiree
extends RefCounted

## Ce qu'une soirée de jeu a produit — V6.10, socle de DA6.3 et DA6.4.
##
## « Ce soir : 7 matchs, 4-3, arme favorite : pompe. » La phrase est de la fiche
## V6.10 ; ce fichier la calcule, et rien d'autre. La carte qui la montre vit
## dans `carte_de_soiree.gd`, l'image qu'on en exporte dans `exporteur.gd`.
##
## ## Un fichier à part, et pour la raison de `serie_de_session.gd`
##
## Une comptabilité ne dépend de rien : ni du réseau, ni de l'audio, ni de l'état
## d'un match. **Ce qui ne dépend de rien se relit à froid et doit pouvoir se
## tester à froid** — `game_state.gd` référence des autoloads par leur nom, ne
## compile pas en mode `--script`, et une suite qui le charge voit ses appels
## échouer sans que le compteur bouge. Le piège est déjà consigné.
##
## ## Ce qui compte comme « ce soir », et pourquoi ce n'est pas « aujourd'hui »
##
## L'historique persiste entre deux lancements : `match_history.json` garde deux
## cents matchs. Une soirée, elle, est **une séance devant l'écran**. Le repère
## est donc l'horodatage du DÉMARRAGE du jeu, passé par l'appelant — pas la date
## du jour, qui rangerait dans la même soirée deux séances séparées de dix
## heures, et qui couperait en deux celle qui passe minuit.
##
## ## Ce que la carte ne dira pas, et c'est délibéré
##
## Rien sur l'adversaire nommé, rien sur le classement, rien sur l'ELO. Une carte
## de fin de soirée se regarde entre gens qui viennent de jouer ensemble ; y
## mettre un score de progression en ferait un relevé de performance, et c'est
## l'écran PROFIL qui en a la charge.

## Le seuil de la fiche V6.10 : « au retour menu après ≥ 3 matchs ». En deçà, il
## n'y a pas de soirée — il y a un match, et l'écran de fin l'a déjà dit.
const SEUIL_MATCHS := 3

## Un match plus court que ça n'est pas un match : abandon immédiat, connexion
## qui tombe, essai de deux secondes. Le compter fausserait la durée moyenne et
## la « plus courte » — qui est justement une ligne qu'on aime lire.
const DUREE_PLANCHER := 5.0


## Le bilan d'une soirée, à partir de l'historique brut.
##
## `depuis_iso` est l'horodatage de démarrage du jeu, au format de
## `Time.get_datetime_string_from_system(true, true)` — comparable en tant que
## CHAÎNE, l'ISO 8601 étant ordonné lexicographiquement. C'est la seule raison
## pour laquelle on peut se passer d'une conversion ici.
##
## `local_idx` vaut -1 en écran partagé : il n'y a pas de « toi » quand les deux
## joueurs regardent le même écran, et le bilan se dit alors par joueur.
static func de_la_soiree(historique: Array, local_idx: int,
		depuis_iso: String) -> Dictionary:
	var retenus: Array[Dictionary] = []
	for entree in historique:
		if not entree is Dictionary:
			continue
		var e: Dictionary = entree
		if depuis_iso != "" and String(e.get("horodatage", "")) < depuis_iso:
			continue
		if float(e.get("duree", 0.0)) < DUREE_PLANCHER:
			continue
		retenus.append(e)

	var bilan := {
		"matchs": retenus.size(),
		"assez": retenus.size() >= SEUIL_MATCHS,
		"victoires": 0, "defaites": 0, "nulles": 0,
		"duree_totale": 0.0,
		"plus_court": -1.0,
		"plus_long": -1.0,
		"arme": "", "arme_n": 0,
		"carte": "", "carte_n": 0,
		"serie": 0,
		"local_idx": local_idx,
	}
	if retenus.is_empty():
		return bilan

	var armes := {}
	var cartes := {}
	var serie := 0
	for e in retenus:
		var duree := float(e.get("duree", 0.0))
		bilan["duree_totale"] = float(bilan["duree_totale"]) + duree
		if bilan["plus_court"] < 0.0 or duree < float(bilan["plus_court"]):
			bilan["plus_court"] = duree
		if duree > float(bilan["plus_long"]):
			bilan["plus_long"] = duree

		# L'issue du point de vue de qui regarde. En ligne le journal la porte
		# déjà (`issue`), écrite par la seule fonction qui la calcule ; en écran
		# partagé elle n'existe pas, et le vainqueur numéroté est la seule
		# vérité disponible. Recalculer l'issue en ligne à partir du vainqueur
		# serait un second calcul qui finirait par diverger du premier.
		var gagne := false
		var nulle := bool(e.get("egalite", false)) or int(e.get("vainqueur", -1)) < 0
		if local_idx >= 0:
			var issue := String(e.get("issue", ""))
			if issue != "":
				gagne = issue == "win"
				nulle = issue == "draw"
			else:
				gagne = int(e.get("vainqueur", -1)) == local_idx
		else:
			gagne = int(e.get("vainqueur", -1)) == 0

		if nulle:
			bilan["nulles"] = int(bilan["nulles"]) + 1
			serie = 0
		elif gagne:
			bilan["victoires"] = int(bilan["victoires"]) + 1
			serie += 1
			bilan["serie"] = maxi(int(bilan["serie"]), serie)
		else:
			bilan["defaites"] = int(bilan["defaites"]) + 1
			serie = 0

		# L'arme favorite est CELLE DU JOUEUR, pas celle du match : en ligne on
		# ne choisit que la sienne, et en écran partagé compter les deux dirait
		# « l'arme la plus jouée sur ce canapé », ce qui est aussi ce qu'on veut.
		for cle in _armes_a_compter(e, local_idx):
			if cle != "":
				armes[cle] = int(armes.get(cle, 0)) + 1
		var carte := String(e.get("carte", ""))
		if carte != "":
			cartes[carte] = int(cartes.get(carte, 0)) + 1

	var top_arme := sommet(armes)
	bilan["arme"] = top_arme["nom"]
	bilan["arme_n"] = top_arme["n"]
	var top_carte := sommet(cartes)
	bilan["carte"] = top_carte["nom"]
	bilan["carte_n"] = top_carte["n"]
	return bilan


static func _armes_a_compter(e: Dictionary, local_idx: int) -> Array[String]:
	var a1 := String(e.get("arme_j1", ""))
	var a2 := String(e.get("arme_j2", ""))
	if local_idx == 0:
		return [a1]
	if local_idx == 1:
		return [a2]
	return [a1, a2]


## Le sommet d'un décompte : `{"nom": String, "n": int}`.
##
## ⚠️ **L'égalité se tranche par le NOM, pas par l'ordre d'arrivée.** Un
## `Dictionary` de Godot conserve l'ordre d'insertion : sans ce départage, deux
## armes jouées trois fois chacune donneraient un favori qui dépend de l'ordre
## des matchs — donc une carte qui change de réponse selon la soirée, pour la
## même soirée. Ce n'est pas une préférence esthétique : c'est ce qui rend la
## fonction testable.
static func sommet(comptes: Dictionary) -> Dictionary:
	var meilleur := ""
	var n := 0
	for cle in comptes.keys():
		var v := int(comptes[cle])
		if v > n or (v == n and (meilleur == "" or String(cle) < meilleur)):
			meilleur = String(cle)
			n = v
	return {"nom": meilleur, "n": n}


## La ligne que la fiche V6.10 promet, en une phrase.
##
## Elle existe pour que le TEXTE soit testable sans monter la moindre scène : la
## carte compose des colonnes, mais c'est cette phrase-là qu'on relit pour savoir
## si le bilan dit quelque chose.
static func phrase(bilan: Dictionary) -> String:
	var n := int(bilan.get("matchs", 0))
	if n == 0:
		return ""
	var bouts: Array[String] = []
	bouts.append("%d match%s" % [n, "s" if n > 1 else ""])
	if int(bilan.get("local_idx", -1)) >= 0:
		bouts.append("%d - %d" % [int(bilan.get("victoires", 0)),
			int(bilan.get("defaites", 0))])
	else:
		bouts.append("J1 %d - %d J2" % [int(bilan.get("victoires", 0)),
			int(bilan.get("defaites", 0))])
	var arme := String(bilan.get("arme", ""))
	if arme != "":
		bouts.append("arme favorite : %s" % arme.to_lower())
	return "Ce soir : " + ", ".join(bouts)


## Une durée en minutes lisibles. `MatchRecord.format_clock` donne `mm:ss`, ce
## qui est juste pour un match et illisible pour une soirée : « 47:12 » se lit
## comme quarante-sept minutes ou comme quarante-sept heures selon le lecteur.
static func duree_longue(secondes: float) -> String:
	var total := int(roundf(maxf(secondes, 0.0)))
	var h := total / 3600
	var m := (total % 3600) / 60
	if h > 0:
		return "%d h %02d" % [h, m]
	if m > 0:
		return "%d min" % m
	return "%d s" % total
