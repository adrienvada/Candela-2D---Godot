# L'équité du capteur entre les dix classes — la cause (session cloud ombre-classes, 2026-09-27)

> **État : terminé.** Suite complète verte dans le cloud (`GODOT=/usr/local/bin/godot ./tools/run_suites.sh` : « tout
> passe, sans erreur de script (614s) », code 0, `test_ombre_ronde` compris). Tous les commits sont poussés sur
> `claude/cloud-ombre-classes`.

## Pour Adrien, en cinq lignes

1. Au même endroit, sous la même torche, certaines classes reçoivent jusqu'à 11 % de lumière de moins que d'autres
   (le Braconnier est le plus sombre, le Spectre le plus clair). J'en ai trouvé la cause, et elle est prouvée.
2. La cause : chaque corps fait de l'ombre à lui-même. Son ombre a la forme de son arme (ta décision du 26 août), et
   le jeu mesure la lumière que reçoit un corps sur un petit disque sous lui ; une arme large cache plus de ce disque.
3. La preuve : si on donne à toutes les classes la même ombre ronde, l'écart tombe à zéro, exactement, aux trois
   distances mesurées. Un simple calcul de géométrie retrouve aussi les chiffres du jeu, sans rien régler à la main.
4. Rien n'a changé dans le jeu : l'essai est un drapeau éteint, qui ne marche qu'en version de test et jamais en ligne.
5. Trois voies sont décrites plus bas, avec leurs images ; chacune change quelque chose que tu verras, et chacune
   demande de refaire le réglage du seuil (0,10) sur ton Mac. Je n'en choisis aucune.

## La réponse courte

| Place (capteur du Parasite) | Ombre d'aujourd'hui (étoile de la silhouette) | Ombre ronde de 12 (`--ombre-ronde`) | Aucune ombre propre | Ombre ronde de 18 (le cercle d'avant) |
|---|---|---|---|---|
| mi-distance (0,28) | 0,2529 à 0,2860 — **écart 11,6 %** | 0,3386 pour les dix — **écart 0** | 0,4939 pour les dix — écart 0 | **0 pour les dix** |
| bord 0,15 | 0,1362 à 0,1501 — écart 9,3 % | 0,1779 — écart 0 | 0,2450 — écart 0 | 0 |
| bord 0,10 | 0,0920 à 0,1039 — **écart 11,4 %** | 0,1237 — écart 0 | 0,1577 — écart 0 | 0 |

Écart = (plus haut − plus bas) / plus haut, entre les dix classes. Un seul processus, les mêmes places, la même
torche, J2 de profil, sans le personnage détaillé ; vue iso 45° B. Les valeurs « étoile » sont celles de la planche Q33
à la quatrième décimale (Terrassier 0,0930, Braconnier 0,0920, Fumiste 0,0955, Sentinelle 0,0972, Spectre 0,1039) :
le banc reproduit bien l'écart qu'elle a trouvé.

**L'hypothèse de Beauté est confirmée, et au-delà de ce qu'elle annonçait** : l'écart ne diminue pas, il disparaît —
égalité au dix-millième aux trois places, pour le rond de 12 comme sans ombre propre. Rien d'autre (position du
disque, lumière sur le côté du corps, profil de la torche) ne différencie les classes : sans leur ombre propre, les dix
capteurs lisent exactement la même chose.

## Ce que dit le code (lu AVANT de coder)

- **Où le capteur lit.** `capteur_corps.gd` : une sous-vue 256×256 (128 px de monde) qui partage le `World2D` du duel
  et ne dessine qu'un disque blanc de rayon 18 sous le corps, en « lumière seule », avec le masque de lumière du sprite
  qu'il remplace. Le corps 3D (`corps_iso.gdshader`) lit ce disque sur un anneau de rayon
  `min(RAYON_CORPS_PX + 1, 18 − 3) = 15` px (`presentation_3d.gd:1108`), chaque fragment dans SA direction
  (`lecture_au_bord = 1`).
- **Pourquoi l'ombre du corps tombe sur son propre capteur.** La torche porte dans ses ombres la couche d'occluder de
  l'adversaire (`player.gd:805`, `shadow_item_cull_mask = 1 | 2 | COUCHE_OCCLUDER_ADVERSE`). Ce masque filtre aussi
  ce qui REÇOIT l'ombre (piège de la ROADMAP du 2026-09-14), et le disque du capteur adverse porte le canal 2 : il la
  reçoit. Une Light2D ombre tout point plus loin de la lampe que le premier bord d'occluder sur son rayon, intérieur
  compris : le capteur n'est éclairé que sur la part de l'anneau qui est DEVANT le bord de l'occluder de son propre
  corps, vu depuis la torche.
- **Où l'occluder prend la silhouette.** `player.gd:996`, à chaque `equip_weapon()` :
  `_accorder_occluder_a_la_silhouette(t_sil)` → `Charte.ombre_de_silhouette()` (`charte.gd`) : une étoile de 32 rayons,
  chacun jusqu'au pixel le plus lointain d'alpha > 0,35 de `<arme>_silhouette.png`. Largeur du corps ET arme.
- **La forme d'avant, et une date à corriger.** Avant `aa392a8` (**2026-08-26**), l'occluder était un cercle de
  16 côtés, rayon 18, sur la couche 4 — que la torche ne portait PAS (`shadow_item_cull_mask = 1 | 2`). **Aucun corps
  n'ombrait donc la torche avant le 26 août** : ce cercle n'a jamais été vu sous une torche. Les deux changements —
  une couche d'ombre par joueur pour que la torche ombre l'adversaire, et l'occluder en silhouette — sont arrivés dans
  le MÊME commit, sur le verdict d'Adrien : « c'est nul, l'occlusion ne se fait pas selon le sprite ». Le 2026-09-11
  (`af237ac`), la forme n'a fait que déménager dans `Charte` pour que le leurre fasse le même trou : c'est cette date
  que cite la ROADMAP de Beauté, mais la décision est du 26 août.
- `Protocol.VERSION` = **18** (`protocol.gd:289`), inchangé.

## Le drapeau d'essai (éteint par défaut)

`--ombre-ronde[=R]` (`charte.gd`, `Charte.rayon_ombre_ronde` / `ombre_ronde` / `ombre_du_corps`, lu par
`player._accorder_occluder_a_la_silhouette`) :

- `--ombre-ronde` seul = **12, le disque du torse** (`Charte.RAYON_TORSE`, déjà l'occluder de la rétrodiffusion).
  Pourquoi pas le cercle d'avant (18) : il contient tout l'anneau lu (15 px), donc le capteur lit 0 — prévu dans le
  premier commit, puis **mesuré : 0,0000 pour les dix classes aux trois places**. Il égalise en rendant tout le monde
  invisible sous la torche ; il reste accessible par `--ombre-ronde=18`, pour le montrer.
- Deux verrous, comme `--zoom` : **build de débogage seulement, et jamais en ligne** (`NetworkManager.current_mode`
  autre que `LOCAL_SPLITSCREEN` → étoile). Un joueur ne peut pas changer l'ombre que l'autre voit.
- `Charte.ombre_ronde_forcee` permet à un outil de basculer dans le même processus ; mêmes verrous.
- Ne touche ni aux masques de lumière de `player.gd`, ni à la simulation (les occluders sont visuels : balles,
  collisions et éblouissement passent par la physique), ni au protocole.
- **Garde** : `tools/test_ombre_ronde.gd`, ajoutée à `run_suites.sh`. Règle pure (release, en ligne, valeurs, bornes,
  préfixe voisin) et vrais joueurs de `main.tscn` : éteint, l'occluder de J1 et de J2 est, pour les dix classes,
  l'étoile de leur silhouette **sommet par sommet** ; allumé, le rond ; allumé mais en ligne, l'étoile ; éteint à
  nouveau, l'étoile. Lancée avec `--ombre-ronde`, elle rougit (vérifié) : elle ne passe pas par construction.
- Limite de l'essai : le leurre garde son étoile (il lit `ombre_de_silhouette` directement). Sous le drapeau, un leurre
  se distinguerait d'un corps. Sans importance pour une mesure ; à savoir si quelqu'un joue avec le drapeau.

## La mesure (`tools/planche_ombre.gd`)

Un héritier de `planche_q33.gd` (dont les prises ne sont pas touchées). Mêmes places que Q33, retrouvées au
dixième de pixel (mi 153,6 px, b15 255,0, b10 285,0, noir 413,6 de J1), trouvées une fois avec le Parasite et l'ombre
d'aujourd'hui. Puis pour chaque classe de J2, cinq ombres, dans le même processus :

- `etoile` (aujourd'hui), `rond12`, `rond18` (par `Charte.ombre_ronde_forcee`, J2 rééquipé) ;
- `sans` : l'occluder de J2 caché (ce que lirait le capteur de la voie b) ;
- `couche` : l'étoile gardée, `visibility_layer` à 0 — pour savoir si le moteur trie les occluders par le masque de la
  vue. **Non** : ses dix mesures sont celles de l'étoile au dix-millième, et l'ombre au sol reste. (Ça ferme une
  façon simple de faire la voie b, voir plus bas.)
- un contrôle : l'étoile reprise en fin de classe, après les quatre autres modes. **Identique au dix-millième** pour
  les dix classes : aucun mode ne laisse de trace.

Le tableau complet, classe par classe : `tableau.md` ; les nombres : `chiffres.json`.

## Le calcul géométrique (`analyse_ombre.py`)

Pour chaque classe et chaque place : les 64 points de l'anneau lu (rayon 15), la torche et l'occluder de J2 en
coordonnées du monde (relevés par le banc). Un point est éclairé si le segment torche → point ne traverse pas
l'occluder et n'est pas dedans. Niveau prédit = moyenne du profil SANS ombre propre (mode `sans`, même place)
× éclairé. **Aucun paramètre ajusté.**

| Classe | part de l'anneau éclairée (étoile) | mi : mesuré / prédit | b10 : mesuré / prédit |
|---|---|---|---|
| Spectre | 0,562 | 0,2860 / 0,2794 | 0,1039 / 0,1018 |
| Parasite | 0,547 | 0,2794 / 0,2794 | 0,0997 / 0,0997 |
| Illusionniste | 0,547 | 0,2794 / 0,2794 | 0,0997 / 0,0997 |
| Allumeur | 0,547 | 0,2794 / 0,2794 | 0,0997 / 0,0997 |
| Occulteur | 0,531 | 0,2729 / 0,2729 | 0,0997 / 0,0976 |
| Incendiaire | 0,531 | 0,2794 / 0,2726 | 0,0997 / 0,0972 |
| Sentinelle | 0,531 | 0,2725 / 0,2726 | 0,0972 / 0,0972 |
| Braconnier | 0,500 | 0,2587 / 0,2587 | 0,0920 / 0,0920 |
| Terrassier | 0,484 | 0,2529 / 0,2529 | 0,0930 / 0,0907 |
| Fumiste | 0,469 | 0,2598 / 0,2463 | 0,0955 / 0,0884 |
| **toutes, rond de 12** | **0,688** | 0,3386 | 0,1237 |
| toutes, rond de 18 | 0,000 | 0 | 0 |

Erreur moyenne de la prédiction : 0,003 (mi), 0,004 (b15), 0,002 (b10) ; corrélation 0,92 / 0,92 / 0,87. Sept classes
sur dix sont prédites exactement à mi-distance. Le reste (jusqu'à 0,013, Fumiste) n'est pas expliqué — pistes :
l'échantillonnage à 64 points contre une étoile à 32 rayons, la résolution de la carte d'ombre de Godot, l'arrondi
des texels du capteur. L'ordre des classes est le bon à deux inversions près (Fumiste, Terrassier). Le capteur lit
des paliers : l'ombre n'est pas filtrée (`SHADOW_FILTER_NONE`), un point de l'anneau est éclairé ou non, d'où les
nombreuses égalités à 0,0997.

## La vue de dessus (`--2d`) — en géométrie, pas en rendu

L'outil photographique est construit pour la vue iso (il lit `Presentation3D`) ; le faire tourner en `--2d` demandait
plus d'une heure (un autre chemin de capture et un autre comptage). J'ai donc répondu à la même question en géométrie,
avec les MÊMES positions, torche et occluders relevés par le banc : la part des pixels du sprite adverse (sa
silhouette, alpha > 0,35) que la torche atteint sans traverser l'occluder du corps.

| Classe | b10, étoile : part (pixels) | b10, rond 12 : part (pixels) |
|---|---|---|
| Spectre | 0,127 (76/600) | 0,263 (158) |
| Sentinelle | 0,104 (68/656) | 0,276 (181) |
| Parasite | 0,102 (56/549) | 0,268 (147) |
| Terrassier | 0,085 (58/680) | 0,316 (215) |
| Illusionniste | 0,072 (45/624) | 0,317 (198) |
| Allumeur | 0,066 (40/602) | 0,271 (163) |
| Occulteur | 0,062 (39/634) | 0,267 (169) |
| Fumiste | 0,062 (40/641) | 0,298 (191) |
| Braconnier | 0,045 (23/509) | 0,285 (145) |
| Incendiaire | 0,025 (15/608) | 0,225 (137) |

Ce que ça dit : **en vue de dessus, l'écart est bien plus grand qu'en iso** — de 15 à 76 pixels éclairés (×5) avec
l'étoile, là où le capteur iso ne varie que de 11 %. L'étoile ne laisse qu'un liseré côté lampe (le « 7 % du corps
éclairé » de la ROADMAP du 2026-09-14 est dans cette fourchette), et la largeur de ce liseré dépend entièrement des
creux de la silhouette. **Et le rond n'y égalise PAS** : le sprite garde sa forme, la part hors du disque de 12 aussi ;
de 137 à 215 pixels. En vue de dessus, seule une règle sur le sprite lui-même (pas sur l'occluder) égaliserait.
Ce n'est pas un rendu : ni la courbe du shader du sprite ennemi, ni l'opacité, ni le filtrage ne sont comptés. Pour
le prouver à l'image, il faudrait un héritier du photographe qui prenne la vue 2D (`_capturer_la_vue` sans iso) et
compte les pixels du sprite de J2 comme Q33 compte ceux du corps.

## Les trois voies (pour Adrien — aucune n'est choisie)

Images : `planche.html` (dix classes, places b10 et mi, à 1:1 en 240×240 — le corps et son ombre au sol — puis loupe
×3) et `apercu_voies.jpg` (le Terrassier à mi-distance, d'un coup d'œil), prises à 45° B ; les mêmes à 0° dans `lacet0/planche.html`.

### (a) Garder — la décision du 26 août : l'ombre a la forme de l'arme

- **À l'image** : rien ne change.
- **Équité** : au seuil, 11 % d'écart de lumière entre classes au même endroit. Traduit en distance : au bord de la
  torche la lumière chute de 0,15 à 0,10 en 30 px ; 11 % de lumière en moins, c'est apparaître **quelques pixels plus
  tard** (≈ 7 px sur une portée de 307, estimé depuis la pente du relevé entre 0,15 et 0,10 — non mesuré directement). Les classes les plus sombres
  sous la torche : Braconnier, Terrassier, Fumiste ; la plus claire : Spectre. La vue de dessus a le même effet, plus
  fort (voir plus haut).
- **0° / 45°** : le capteur est calculé dans le monde 2D ; il ne dépend pas du lacet de la caméra (vérifié, voir
  « 0° et 45° »). Ce qui change avec le lacet est la part du corps tournée vers la caméra.
- **Noir absolu** : inchangé (état d'aujourd'hui).
- **Au Mac** : rien, sauf si Adrien veut voir l'écart au seuil sur son GPU.

### (b) Le capteur d'un corps ignore sa propre ombre ; l'ombre au sol garde la forme de l'arme

- **Capteur** (mode `sans`) : les dix classes égales (0,1577 à la place où le Parasite lit 0,0997 aujourd'hui,
  **+58 %**). Tout le monde apparaît plus tôt, plus loin : le seuil 0,10 (Q32) est à recaler.
- **À l'image** : le corps n'a plus d'ombre propre, **il est éclairé tout autour, dos compris** (le disque du capteur
  est éclairé à 100 %, contre 31 à 37 % aujourd'hui) — le liseré côté lampe, qui est la signature de la torche depuis
  le 14/09, disparaît du corps. C'est le prix le plus visible de cette voie. L'ombre au sol, elle, garderait l'étoile ;
  la planche montre le mode `sans`, où l'ombre au sol a disparu aussi : **l'image exacte de la voie b n'existe pas
  encore**, faute d'implémentation.
- **Comment la faire** : pas par la couche de visibilité de l'occluder (mesuré : le moteur l'ignore pour les
  ombres). Il faudrait une lumière jumelle par torche (et par halo, qui ombre aussi le corps d'en face) qui n'éclaire
  QUE les capteurs, avec les murs seuls dans ses ombres ; ou une lecture du capteur hors de la silhouette. Les deux
  touchent aux masques de lumière de `player.gd` ou au capteur — hors de ma tâche, et à décider.
- **0° / 45°** : identique au capteur (2D). **Noir absolu** : une ombre en moins n'ajoute de la lumière que là où la
  torche porte ; mesuré en mode `sans`, les pixels allumés en plus sont dans l'ombre qui disparaît derrière J2, à
  277 px au plus du corps à l'écran, dans le faisceau.
- **Au Mac** : la cadence (une lumière ombrée de plus par torche et par halo, dans chaque vue), et le recalage du seuil.

### (c) L'occluder rond du torse (12) pour toutes les classes

- **Capteur** : les dix égales (0,1237 à la place b10, **+24 %** sur le Parasite d'aujourd'hui). Seuil à recaler.
- **À l'image** : le corps garde une ombre propre (le côté opposé à la torche reste sombre, liseré conservé mais plus
  large), et **l'ombre au sol devient ronde** : l'arme ne fait plus d'ombre — c'est exactement ce qu'Adrien a refusé
  le 26 août (« l'occlusion ne se fait pas selon le sprite »). Planche : colonne `rond12`, ombre au sol plus étroite
  derrière le Terrassier ou le Fumiste.
- **Vue de dessus** : n'égalise PAS (de 137 à 215 pixels éclairés, voir plus haut).
- **Le rond de 18 (le cercle d'avant) est exclu** : capteur 0, tout le monde invisible sous la torche.
- **0° / 45°** : identique au capteur. **Noir absolu** : même raisonnement que (b), pixels en plus dans l'ombre qui
  rétrécit, 277 px au plus du corps à l'écran.
- **Au Mac** : le recalage du seuil ; la cadence ne devrait pas bouger (un polygone de 32 sommets remplace un autre),
  mais cela se mesure, ne se suppose pas.

(Une quatrième voie existe et n'est pas explorée : un facteur de capteur par classe, que la ROADMAP de Beauté évoque
« si l'écart persiste ». Il compenserait une forme par un chiffre, et devrait suivre toute retouche de silhouette.)

## 0° et 45°

Deux passes complètes, même commande, l'une à 45° B (défaut), l'autre avec `--lacet=0` : **les 160 mesures du
capteur sont identiques au bit près** (écart maximal 0). C'est attendu — le capteur est rendu dans le monde 2D, sous
le corps, sans caméra iso — et c'est maintenant vérifié : l'écart entre classes (11,4 % au bord 0,10 avec l'étoile) et
son annulation (0 avec le rond de 12, 0 sans ombre propre) valent aux deux angles. Ce qui change avec l'angle, c'est
l'image : quelle face du corps et quelle part de l'ombre au sol se voient. Planche à 0° : `lacet0/planche.html`
(mêmes découpes). J2 en lacet B regarde depuis le côté opposé : sa vue lit ses propres capteurs (`CapteurVue2…`),
symétriques par construction, non mesurés ici (voir « pas pu prouver »).

## Pour tout refaire

```bash
# Outils (une fois)
godot --version   # 4.7.stable ; sinon le zip officiel, lié en /usr/local/bin/godot
godot --headless --path . --import
pip install numpy pillow

# La garde du drapeau
godot --headless --path . --script res://tools/test_ombre_ronde.gd

# Les mesures (≈ 1 h par passe dans le cloud, 4 cœurs) — dans user://ombre45 et user://ombre0
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/planche_ombre.tscn -- \
  --sortie=user://ombre45 --led-murs-fige=0.5
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/planche_ombre.tscn -- \
  --sortie=user://ombre0 --led-murs-fige=0.5 --lacet=0
#   --classes=pistolet,pompe  pour quelques classes ; --sans-images pour les chiffres seuls

# Tableau, chiffres, découpes, planche
python3 docs/iso/cloud/ombre-classes/analyse_ombre.py \
  "$HOME/.local/share/godot/app_userdata/Candela 2D/ombre45" docs/iso/cloud/ombre-classes

# Essayer le drapeau en jeu (build de débogage, hors ligne)
godot --path . -- --ombre-ronde        # le torse, 12
godot --path . -- --ombre-ronde=18     # le cercle d'avant : corps invisibles sous la torche
```

Sur le Mac : sans `xvfb-run` ni `--fixed-fps 60`, dossier
`~/Library/Application Support/Godot/app_userdata/Candela 2D/ombre45`.

## Ce que je n'ai PAS pu prouver

- **Rien sur le GPU du Mac.** Tout vient de llvmpipe. Les égalités (écart 0 avec le rond) tiennent à une propriété
  géométrique qui ne dépend pas du GPU ; les niveaux absolus, eux, se revérifient au Mac. Aucune cadence mesurée.
- **Le miroir** : seule la torche de J1 sur le corps de J2, vue de J1, est mesurée. La torche de J2 sur le corps de J1,
  vue de J2 (lacet B), est symétrique par construction (couches `4 << id`, masques miroir vérifiés par
  `test_iso_vues`), mais pas mesurée ici.
- **Une seule orientation de J2** (de profil) et une seule ligne de tir. Face à la torche ou de dos, la part de
  l'anneau cachée change pour chaque classe, et l'écart aussi (peut-être plus grand : le canon est long).
- **Le reste de la prédiction géométrique** (jusqu'à 0,013 pour le Fumiste) n'est pas expliqué.
- **La vue de dessus** n'est qu'une géométrie, pas un rendu.
- **L'image de la voie b** n'existe pas (voir plus haut).
- **La scène « noir »** n'est pas reprise sous chaque ombre : la place est hors de portée de la torche (413 px pour une
  portée de 307), aucune forme d'occluder ne peut y apporter de lumière ; raisonné, pas mesuré.
- **Le halo de proximité** (`ambient_light`) ombre lui aussi le corps d'en face (`masque_ombre_halo`) : même effet
  attendu collé à l'adversaire, non mesuré.

## Défauts vus hors de ma tâche (signalés, pas corrigés)

- La base n'avait pas de `.uid` pour `tools/planche_q33.gd` ni pour `volume_masque.gdshaderinc` (le dépôt en
  versionne 531) : l'import les a créés, je les ai committés à part (`4915c6d`), aucun code touché.

## À reporter dans la feuille de route (par l'intégration)

- **Décision en attente d'Adrien** : l'écart du capteur entre classes (11 % au seuil, iso) est l'ombre propre de
  chaque corps sur son capteur ; trois voies décrites ici. Tant qu'il n'a pas tranché, le seuil commun de Q32
  n'est commun qu'à 11 % près.
- **Date à corriger** dans le paragraphe de Beauté : l'occluder en silhouette est du 2026-08-26 (`aa392a8`), pas du
  2026-09-11 (`af237ac`, simple déménagement).
- **Piège** : `LightOccluder2D.visibility_layer` ne soustrait pas un occluder aux ombres d'une sous-vue dont le
  `canvas_cull_mask` l'exclut (Godot 4.7, mesuré : capteur identique au dix-millième, ombre au sol inchangée). On ne
  peut pas faire « ce capteur ignore cet occluder » par les couches de visibilité.
- **Piège** : un occluder rond de rayon ≥ 15 (l'anneau lu par le corps) éteint entièrement le capteur de son propre
  corps sous une torche. Le cercle « d'avant » (18) n'est pas une forme de repli possible.
- **Outil** : `tools/planche_ombre.gd` + `analyse_ombre.py`, le drapeau `--ombre-ronde` et sa garde
  `test_ombre_ronde` (dans `run_suites.sh`).
