class_name Protocol
## Le numéro que deux jeux comparent avant de se parler — Phase 8, étape 8.9.
##
## Deux versions du jeu qui ne parlent pas exactement la même langue ne plantent
## pas : elles jouent, chacune dans sa réalité. Le pire défaut du netcode est
## celui qui ne lève rien.
##
## ## Le carnet, et le rappel
##
## `VERSION` est tenu **à la main**, et c'est délibéré (décision d'Adrien,
## 2026-08-18). Lui seul porte une intention : savoir si un changement casse la
## compatibilité est un jugement, pas un calcul. Une empreinte automatique
## changerait sur un simple renommage sans conséquence, et interdirait à jamais
## de dire « ce changement-ci passe, laissez-les jouer ».
##
## Sa faiblesse est l'oubli, et elle est réelle : le jour où on modifie un RPC
## sans toucher au numéro, deux jeux incompatibles se croient d'accord — et le
## garde-fou est muet exactement quand il fallait qu'il parle.
##
## D'où `WIRE_WITNESS` : le témoin de ce à quoi ressemblait le fil la dernière
## fois qu'on a regardé. `tools/test_protocole.gd` le recalcule et compare. Si le
## fil a bougé sans que `VERSION` bouge, la suite passe au rouge et dit quoi
## faire. **Le numéro reste une décision humaine ; l'oubli, lui, est mécanisé.**
##
## ## Ce que le numéro couvre
##
## Tout ce qui est visible sur le fil, en **un seul** numéro : formes des RPC,
## version du codec de carte, noms des attributs de salon EOS. Pas un numéro par
## sous-système — un joueur n'a pas à savoir lequel diffère, et deux numéros
## finiraient par se contredire.
##
## ## Comment on l'incrémente
##
## D'un, à chaque fois que le fil change. Jamais de saut, jamais de retour : les
## versions publiées dans la nature ne se rattrapent pas.

## Le carnet. À incrémenter dès que quoi que ce soit change sur le fil.
##
## 1 — état du 2026-08-18 au matin : douze RPC, codec de carte v3, attributs de
##     salon d'origine. Jamais publié.
## 2 — la poignée de main elle-même : `rpc_hello` et l'attribut de salon `PROTO`.
##     Un build v1 n'a pas `rpc_hello` ; il ne répond donc jamais, et c'est
##     `_check_hello_arrived` qui le refuse — le silence est un refus.
## 5 — `rpc_send_inputs` perd son sixième argument (2026-08-26) : un client v4
##     enverrait six valeurs à un hôte v5 qui en attend cinq. **Rupture franche, donc le numéro monte** — c'est
##     exactement le cas que ce carnet existe pour attraper, et le témoin du fil
##     l'a signalé avant qu'on y pense.
## 6 — `rpc_send_inputs` regagne un sixième argument, le bit de fusée éclairante
##     (chantier FUSÉE, 2026-09-01), et `rpc_spawn_fusee` apparaît. Même rupture
##     franche que la v5, dans l'autre sens — et le témoin l'a encore signalée
##     avant qu'on y pense.
## 7 — `rpc_spawn_fusee` troque sa cible (Vector2) contre un angle (float) :
##     la fusée REBONDIT sur les murs au lieu de les survoler (FU2.1, décision
##     d'Adrien au premier essai), le vol se simule localement des deux côtés.
##     Un hôte v6 enverrait une cible qu'un client v7 lirait comme un angle.
## 8 — `rpc_send_inputs` gagne un septième argument, le bit de rechargement
##     (chantier MUNITIONS & RECHARGE, 2026-09-07).
## 9 — `rpc_eteindre_fusee` apparaît (chantier FUSÉE, étape FU5, 2026-09-08) :
##     un hôte qui l'appelle parle à un client v8 qui n'a jamais entendu ce nom
##     et ne répond donc jamais — le silence est un refus, comme pour `rpc_hello`.
## 10 — `rpc_countdown_launch` apparaît (2026-09-09) : l'hôte d'un match apparié
##      classé en avertit désormais le client quand les deux « prêt » abrègent
##      la fenêtre de choix, au lieu de ne collapser que son propre décompte —
##      voir « Deux prêts, un seul départ » aux Pièges connus de la ROADMAP. Un
##      client v9 ignore ce nom et ne répond donc jamais, comme pour
##      `rpc_eteindre_fusee`.
## 11 — `rpc_send_inputs` gagne un huitième argument, le bit de GADGET (chantier
##      CLASSES, 2026-09-09). Rupture franche, comme les v5 et v6 : un client v10
##      enverrait sept valeurs à un hôte v11 qui en attend huit. L'argument porte
##      une valeur par défaut, donc GDScript ne dirait rien — c'est le témoin du
##      fil qui l'attrape, et c'est exactement ce pour quoi il existe.
## 12 — la table rang → classe entre en vigueur (chantier CLASSES, 2026-09-09).
##      La FORME du fil ne bouge pas : `weapon_idx` reste un entier. C'est son
##      SENS qui change — l'intervalle passe de 0-3 à 0-9, et un index qui valait
##      « fusil » en v11 peut valoir autre chose en v12.
##
##      ⚠️ **C'est exactement le cas de la v7**, où `rpc_spawn_fusee` troquait une
##      cible contre un angle : rien ne casse à la lecture, les deux jeux
##      s'entendent, et chacun équipe une classe différente. Le pire défaut du
##      netcode est celui qui ne lève rien.
## 13 — `rpc_spawn_gadget` apparaît (chantier CLASSES, étape 10, 2026-09-09).
##      Même famille que la v9 : un hôte v13 appelle un nom qu'un client v12 n'a
##      jamais entendu. Ce qui rend cette rupture-là coûteuse est ce qu'elle
##      laisse derrière — **l'hôte aurait un occluder que le client n'a pas.**
##      Le client verrait donc la lumière traverser une bâche que l'hôte
##      considère opaque, et chacun jouerait sa propre carte sans qu'une seule
##      ligne d'erreur ne le dise.
## 14 — `rpc_allumer_gadget` apparaît (chantier CLASSES, étape 12, 2026-09-09) :
##      la mine au magnésium, déclenchée par l'hôte, que les deux pairs doivent
##      voir prendre feu au même instant. Même famille que les v9 et v13 — un
##      hôte v14 appelle un nom qu'un client v13 n'a jamais entendu.
##
##      ⚠️ Et ce qu'elle laisse derrière est pire que pour un gadget posé : la
##      mine BRÛLE chez l'hôte, donc elle aveugle — l'éblouissement étant
##      répliqué, le client verrait sa vue blanchir devant un boîtier éteint.
## 15 — `rpc_stock_fusees` apparaît (chantier CLASSES, étape 18, 2026-09-09) : la
##      réserve de fusées devient PROPRE À LA CLASSE, et deux d'entre elles la
##      rechargent. L'arithmétique reste chez l'hôte — deux accumulateurs locaux
##      dérivent d'un demi-RTT à chaque consommation, voir `flare_profile.gd` —,
##      mais le résultat doit voyager : sans lui, le client garderait un compte
##      figé et sa prédiction du désarmement se tromperait au premier lancer
##      d'une fusée regagnée.
##
##      ⚠️ Le SENS de la réserve change aussi, comme à la v12 : elle valait un
##      pour tout le monde, elle vaut désormais de zéro (le Spectre) à trois (le
##      Terrassier). Un hôte v15 et un client v14 s'entendraient sur le fil et
##      compteraient deux réserves différentes.
## 16 — le tir devient SEMI-AUTOMATIQUE pour neuf classes sur dix (décision
##      d'Adrien, 2026-09-10). La FORME du fil ne change pas — le bit de tir
##      reste un booléen tenu —, mais son SENS si, comme aux v12 et v15 : un
##      appui ne vaut plus qu'un tir. Or le client PRÉDIT ses tirs. Un client
##      v15 face à un hôte v16 prédirait une rafale que l'hôte refuserait, et
##      afficherait des balles qui n'existent nulle part.
##
##      ⚠️ Et `rpc_spawn_bullet` code désormais les DIX classes (0 à 9) au lieu
##      des quatre armes d'origine. Même signature, donc même empreinte — mais un
##      client v15 décoderait 4 à 9 comme le Parasite, ce qu'il faisait déjà pour
##      les six classes neuves avant que le défaut ne soit trouvé.
##
##      ⚠️ Et les GADGETS, dans la même version (non publiée entre-temps) :
##      `rpc_spawn_gadget` gagne la GRAINE de l'onde du grésillement, tirée par
##      l'hôte — deux pairs qui tireraient chacun la leur verraient deux pannes ;
##      `rpc_etat_gadget` apparaît, qui porte l'allumage d'un gadget basculable ET
##      la batterie de son poseur. Ici la FORME du fil change : l'empreinte a été
##      recalculée après avoir tranché que le numéro restait 16.
##
##      Et, après la revue du même jour : `rpc_spawn_gadget` porte aussi l'état
##      initial et la batterie DÉCIDÉS PAR L'HÔTE (relus chez chaque pair, ils
##      divergeaient), et `rpc_detruire_gadget` apparaît — la destruction d'un
##      gadget devient autoritaire, le client n'encaisse plus rien.
##
##      Et le VOILE arrête désormais les joueurs (même version, toujours non
##      publiée). Le fil ne bouge pas, le sens si : un client d'avant prédirait
##      qu'il le traverse, et l'hôte le retiendrait — une correction par contact.
## 17 — le SENS change (étape 27 du chantier DIX CLASSES, 2026-09-11, décisions
##      d'Adrien), puis la FORME (étape 28, lot C, plus bas). À l'étape 27, aucun
##      RPC n'était ajouté ni modifié. Mais cinq règles que les deux pairs doivent
##      partager :
##      - la torche fantôme balaie selon un plan de gestes tiré de la GRAINE de
##        `rpc_spawn_gadget` (elle la jetait jusqu'ici) : un pair v16 dessinerait
##        son ancien sinus pendant que l'hôte v17 éblouit selon le nouveau plan ;
##      - les gadgets diffus ne sont plus touchés par les balles : la balle les
##        traversait déjà, mais un hôte v16 les abîmait au passage et les
##        détruisait ; un v17 ne les rencontre plus. Et une balle n'éteint plus
##        la fusée : un client v16 y prédirait une balle arrêtée que l'hôte v17
##        laisse passer ;
##      - la suie cache le corps de qui s'y tient, et étouffe la lampe qu'on y
##        tient — éblouissement arbitré par l'hôte compris (`facteur_de_lampe`) :
##        un client v16 afficherait un adversaire v17 caché dans la suie, et
##        rendrait pleine une lampe que l'hôte v17 étouffe ;
##      - la lampe de l'arbalète est deux fois plus lumineuse, et son
##        éblouissement avec : un v16 face à un v17 ne verrait pas la même lampe ;
##      - la fausse torche obéit à la règle de lampe d'une vraie (la suie
##        l'étouffe, le grésillement la fait sauter), rendu et éblouissement ; et
##        l'éblouissement lit l'OMBRE du leurre, pas son disque de touche : un
##        client v16 dessinerait allumée une fausse torche que l'hôte v17 étouffe.
##
##      Et à l'étape 28 (même version, toujours non publiée) : la nappe de braises
##      pâlit chez les DEUX pairs — elle ne pâlissait que chez l'hôte — et son
##      éblouissement, arbitré par l'hôte, suit cette lueur
##      (`GadgetBase.energie_relative`). Le fil ne bouge pas, le sens si : un
##      client v16 rendrait à pleine lueur une nappe dont l'hôte v17 fait baisser
##      l'éblouissement. Les tics de brûlure ne sont PAS une règle partagée :
##      l'hôte les décide, `rpc_update_hp` les porte.
##
##      Et la MINE, au lot A2 de la même étape (2026-09-12) : rien à partager, et
##      c'est la raison qui compte. Sa lumière suit `reste²` chez les DEUX pairs
##      depuis l'étape 12 (`GadgetMine._physics_process()`) et elle n'a pas changé ;
##      seul l'hôte en tire l'éblouissement, désormais par le gain plutôt que par un
##      rayon qui rétrécissait, et il le réplique. Un client v16 dessine exactement
##      la même flamme qu'un v17 : c'est l'arbitrage qui bouge, pas le rendu.
##
##      Et, même étape : l'ombre habitée arrête balles et regard par sa PLAQUE
##      (36 × 6), la même que son ombre, et non plus par le disque de 18 du socle.
##      Le fil ne bouge pas, le sens si : un client v16 arrêterait ses balles
##      prédites sur l'ancien disque (`bullet.gd` les simule chez lui) quand l'hôte
##      v17 les laisse passer. Le point de pose, lui, change chez l'hôte SEUL — le
##      poseur exclu du rayon, le voile reculé hors des corps ou refusé faute de
##      place — et il voyageait déjà dans `rpc_spawn_gadget` : rien à partager.
##
##      Et, lot C de la même étape (2026-09-11, décision d'Adrien : dire quand
##      revient la prochaine fusée, par une jauge sans texte), la FORME change
##      dans la même version, toujours non publiée — v0.5.0 est sortie en 16 :
##      `rpc_stock_fusees` gagne l'ATTENTE restante avant la prochaine fusée.
##      L'hôte l'envoie à chaque changement de réserve — regain, lancer,
##      changement de classe — et le client la décompte entre deux envois, sans
##      estimer. Entre un pair d'avant ce lot et un pair d'après, le paquet porte
##      deux valeurs là où l'autre en attend trois, ou l'inverse : l'appel est
##      refusé par le moteur, au mieux une ligne dans une console que personne
##      ne lit, et le compte des fusées du client se fige. Le nouvel argument n'a
##      PAS de valeur par défaut : c'est elle qui rendait GDScript muet à la v11,
##      et un appelant oublié doit lever une erreur de script que `run_suites.sh`
##      attrape. Le témoin l'a signalé ; le numéro reste 17, l'empreinte
##      recalculée APRÈS l'avoir tranché.
##
##      Et, le même jour (étape 28, lot E : la télémétrie des gadgets), la FORME
##      change encore sous le même numéro, qui n'est toujours pas publié.
##      `rpc_update_hp` gagne la CAUSE de la perte (balle ou braises), et
##      `rpc_detruire_gadget` celle de la mort du gadget (balle ou fin de vie) : le
##      client ne pouvait distinguer ni l'une ni l'autre, et une télémétrie déduite
##      chez lui aurait donné deux archives différentes pour un même match. Un pair
##      d'avant ce lot enverrait deux arguments là où l'on en attend trois : le
##      paquet serait refusé, et la barre de vie du client se figerait. Ni l'un ni
##      l'autre n'a de valeur par défaut, pour la raison de la v11. Le témoin l'a
##      signalé ; le numéro reste 17, l'empreinte recalculée APRÈS l'avoir tranché.
##
##      Et, lot G de la même étape (2026-09-12, arbitrage d'Adrien : « oui, qu'il
##      ait l'ombre d'un corps »), le SENS change sans que la FORME bouge —
##      l'empreinte reste donc intacte, et le témoin doit rester vert. Le LEURRE
##      porte désormais les couches d'ombre d'un CORPS : l'étoile de sa silhouette
##      sur la couche du corps de son poseur, un disque de torse sur celle de son
##      torse. Deux règles que les deux pairs doivent partager :
##      - il ne fait plus d'ombre sous les lumières dont le masque d'ombre ne
##        contient que le décor — fusée au sol, mine, nappe de braises, halo de la
##        torche fantôme, lumière d'impact. Un pair d'avant ce lot dessine une
##        ombre de corps là où un pair d'après n'en dessine aucune : les deux ne
##        voient pas la même arène, et l'un démasque en éclairant un leurre que
##        l'autre croit intact ;
##      - l'éblouissement suit cette ombre : la torche et le flash de tir du poseur
##        traversent son propre leurre (`GadgetBase.fait_ombre_aux_lumieres_de()`),
##        et jusqu'ici, planter un leurre devant soi éteignait sa propre torche. ⚠️
##        **Le client ne prédit RIEN de cet éblouissement** — `_maj_eblouissement()`
##        et `_flash_de_tir()` sortent d'emblée en `ONLINE_CLIENT`, et `player.gd`
##        recopie `net_dazzle`, la valeur que l'hôte réplique. Ce qui bouge est donc
##        l'ARBITRAGE de l'hôte, pas une prédiction du client : exactement le
##        raisonnement de la mine au lot A2 — le rendu ne bouge pas, l'arbitrage si.
##        (La première rédaction disait ici « un client v16 prédirait un adversaire
##        épargné » : faux, et écrit sans relire ces trois fonctions — la faute
##        exacte dont cette étape a corrigé quatre exemplaires.)
##      Rien de neuf ne voyage : les deux occluders naissent de `poseur_id` et de
##      `classe_du_poseur`, que `rpc_spawn_gadget` porte déjà.
##
##      Et, lot H de la même étape (2026-09-12, décision d'Adrien : « le comptage des
##      mines devient exact avant la publication »), la FORME change **une dernière
##      fois sous ce numéro** : `rpc_allumer_gadget` gagne la CAUSE de l'allumage —
##      passage ou balle. Même famille que le lot E : le client ne peut pas la
##      déduire, il n'encaisse aucune balle et ne voit de la mine que son feu. Sans
##      elle, la télémétrie devait retrancher les mines abattues des allumages, ce qui
##      ne donnait qu'un MAJORANT — une mine abattue meurt 1,6 s plus tard, et le match
##      archivé avant ne lui compte aucune mort. Un pair d'avant ce lot enverrait un
##      argument là où l'on en attend deux : le paquet serait refusé par le moteur, et
##      la mine s'allumerait chez l'hôte seul — c'est-à-dire un client aveuglé devant
##      un boîtier éteint, le défaut même que la v14 décrit. L'argument n'a PAS de
##      valeur par défaut, pour la raison de la v11. Le témoin l'a signalé ; le numéro
##      reste 17, l'empreinte recalculée APRÈS l'avoir tranché.
##
##      ⚠️ **C'est le dernier moment où cette correction coûte zéro** : la v17 n'est
##      toujours pas publiée (v0.5.0 est sortie en 16), et ce lot est le dernier avant
##      la 0.6.0. Après le tag, le même correctif imposerait un protocole 18 et une
##      coupure entre joueurs — c'est la raison du calendrier, pas une commodité.
##
## ## ⛔ LA v17 EST PUBLIÉE — depuis **v0.6.0, le 2026-09-12**
##
## Tout ce qui précède a été écrit pendant que ce numéro était encore libre, et neuf
## passages ci-dessus disent « non publiée », « toujours pas publiée », « une dernière
## fois sous ce numéro ». **Ces phrases étaient vraies à l'écriture et sont fausses
## depuis le tag.** Elles restent là parce qu'elles racontent pourquoi chaque
## changement a pu se faire sous un seul numéro ; elles ne sont plus une permission.
##
## Ce qui change concrètement, à partir de maintenant : le fil de la v17 est installé
## chez des joueurs. **Toute modification de FORME — un argument ajouté, retiré,
## réordonné, changé de type — impose `VERSION = 18`**, et coupe la population en deux
## moitiés qui ne se voient pas jusqu'à ce que les deux côtés aient mis à jour. Ce
## n'est pas une erreur à éviter, c'est un coût à assumer sciemment : `accepts()`
## refuse symétriquement, le jeu ne plante pas, ne dit rien de faux, il refuse
## poliment — et personne ne voit le défaut, ni chez soi (on tourne toujours sur le
## dernier code) ni dans les suites (elles n'ont pas de population).
##
## Le rappel qui l'attrape avant qu'il parte : `tools/verifier_publication.sh`, à
## lancer AVANT de poser un tag. Il refuse une mineure inchangée quand ce numéro a
## bougé — 0.6.x → 0.7.0 pour un fil qui change, 0.6.1 pour tout le reste.
const VERSION := 17

## Le témoin. Empreinte du fil au moment où `VERSION` a été fixé.
##
## Il ne se modifie **jamais seul** : quand la suite le déclare périmé, on décide
## d'abord si `VERSION` doit monter, puis on recopie ici l'empreinte que la suite
## affiche. Le recopier sans avoir tranché la question du numéro ne fait que
## rendre le rappel silencieux.
## ⚠️ **Recalculé après la fusion de `main`, pas recopié depuis l'une des deux
## branches.** Les deux jeux de changements se combinent : le fil d'après la
## fusion n'est ni celui de `main` (v10) ni celui du chantier (v14 avant
## renumérotation). La question du numéro a été tranchée d'abord — les cinq
## entrées du chantier deviennent 11 à 15 —, l'empreinte recopiée ensuite.
const WIRE_WITNESS := "81c84826a51f737c"

## Fichiers portant des RPC. Une liste explicite plutôt qu'un balayage du dépôt :
## un fichier oublié rendrait le témoin vert alors que le fil a bougé, et c'est
## le seul mode de défaillance qui compte ici. Ajouter un RPC dans un fichier
## absent de cette liste doit être impossible à faire par inadvertance — d'où la
## vérification croisée de la suite, qui refuse tout `@rpc` hors de ces fichiers.
const RPC_SOURCES: Array[String] = [
	"res://game_state.gd",
	"res://network_manager.gd",
	"res://player.gd",
]

## Refuser dans les deux sens, sans « le plus récent tolère le plus ancien ».
##
## Le build ancien ne peut pas savoir ce que le nouveau a changé : sa tolérance
## serait une supposition. La symétrie est la seule règle que les deux côtés
## peuvent appliquer avec la même information — et deux jeux qui refusent pour la
## même raison peuvent l'expliquer pareil.
static func accepts(peer_version: int) -> bool:
	return peer_version == VERSION

## Ce qu'on montre au joueur quand ça ne colle pas. Il n'a pas à connaître le
## numéro : il a à savoir quoi faire.
static func mismatch_message(peer_version: int) -> String:
	if peer_version <= 0:
		return "Votre adversaire utilise une version du jeu trop ancienne pour se présenter."
	var qui := "la vôtre" if peer_version < VERSION else "celle de votre adversaire"
	return ("Vos deux jeux ne sont pas dans la même version : %s est plus ancienne. "
		+ "Mettez à jour des deux côtés avant de rejouer.") % qui
