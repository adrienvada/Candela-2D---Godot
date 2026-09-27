# L'écart du jeu à ses illustrations — rapport

Session cloud, branche `claude/cloud-ecart-illustrations`, partie d'`origin/integration-iso14` (60e5c6d), le 27/09/2026
entre ~02:30 et ~05:30 (heure de Paris). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». **Aucun défaut du jeu
ne change** : un outil de prise (`tools/photo_ecart.gd`) et des documents, rien d'autre.

## Pour Adrien, en cinq lignes

1. Ouvre `planche.html` : pour chacune des vingt illustrations, l'image, le jeu tel qu'il est, le jeu avec tous les essais
   de la nuit, et un tableau de ce qui manque. Six illustrations (menus, intro) n'ont aucune scène de jeu qui leur ressemble.
2. Le plus grand écart n'est pas un détail : les dessins sont des plans à hauteur d'homme, où l'on voit loin dans une
   pénombre grise ; le jeu est vu de haut, dans le noir. Ces deux différences-là, il ne faut PAS les combler.
3. Ce qui changerait le plus l'image sans rien trahir : une lumière de lampe plus claire et plus pâle, des personnages
   sombres au lieu de clairs, des murs et un sol plus meublés.
4. Les essais de la nuit vont dans le bon sens et n'allument jamais le noir, mais à la taille du jeu ils se voient peu :
   des hachures, un contour, une perle à la lampe, des mots sombres sur les murs et au sol, une fusée plus rose que rouge.
5. Trois choix sont à toi : la clarté de la lampe, la clarté de ton propre personnage, et le retour (ou non) du faisceau
   visible dans l'air.

## Ce qui a été fait

1. **Fusions** dans cette branche, dans l'ordre demandé — `origin/claude/cloud-essais` (d827a57),
   `origin/claude/cloud-enseignes` (8b4c852), `origin/claude/cloud-fusee-rouge` (3bd8ed9) : **aucun conflit textuel**, ni
   dans le code ni dans `docs/ROADMAP.md`. Les points d'ancrage des neuf drapeaux, relus par `grep` après les fusions :
   `--faisceau` (`iso_volumes.gd`), `--mannequin` et `--corps-detaille` (`voxel_catalogue.gd`), `--pochoirs-essai`
   (`arena_decor.gd`), `--encre-essai` (`iso_materiaux.gd`), `--tuyaux-essai` (`tuyaux_iso.gd`, construit par
   `presentation_3d.gd:_construire_les_tuyaux`), `--enseignes-essai` (`enseignes_iso.gd`, construit par
   `presentation_3d.gd:_construire_les_enseignes` — les deux constructions, venues de deux branches, sont bien appelées
   côte à côte dans la reconstruction des murs), `--fusee-rouge-long` (`fusee_modele.gd`), `--fusee-rouge-sang`
   (`fusee_couleur.gd`). Les deux corrections du photographe pour Xvfb (0c67705) étaient déjà portées par la base
   (`a8bba4f`) : rien à réappliquer (le `git apply` demandé échoue justement parce qu'elles y sont).
   **Suite complète verte après les fusions** : 140 bancs OK, « tout passe, sans erreur de script (668 s) », EXIT 0.
2. **Un outil de prise**, `tools/photo_ecart.gd` (+ `.tscn`), héritier de `tools/photo_essais.gd` (lui-même héritier du
   photographe, qui n'est pas touché). Il reprend la graine du hasard, le repos compté en images de jeu, les LED figées et
   le congé de l'intro en planches. Onze scènes sur le Cloître (seule carte qui porte pochoirs, tuyaux et enseignes), au
   cadrage du jeu — **1920×1080, lacet 45° B, caméra au zoom ×1,5** (lus dans le journal : « lacet de J1 : 45.0° · zoom
   caméra : 1.5 ») : `duel`, `noir` (torches éteintes), `scinde`, `sol` (le pochoir « ZONE 1 »), `mur` (la face la plus
   meublée de tuyaux), `arena` et `zone` (devant une enseigne que la caméra dessine), `impacts` (trois tirs dans le mur),
   `fusee1` et `fusee2` (1,5 s et 4 s après le lancer), `entrainement`. J'ai vérifié à l'œil la première image de chaque
   séance : aucune intro en surimpression.
3. **Trois lancements** : `defaut`, `temoin` (le même, pour le bruit), `tous` (les neuf drapeaux). Le bruit entre deux
   lancements identiques est minuscule — 0 à 364 pixels sur deux millions, **0 pixel noir allumé** hors de l'écran scindé
   (4) — ce qui rend les écarts des essais lisibles.
4. **Mesures** (`mesurer.py` → `mesures.json`), **planche** (`planche.py` → `planche.html`, `ILLUSTRATIONS.md`), le contenu
   des tableaux dans `analyse.py`. Images JPEG qualité 85 dans `img/` (6,8 Mo en tout) : les vingt illustrations à 1024 de
   large, les prises à 1920×1080, et une **loupe** par scène (le tiers de l'écran centré sur la lumière de la prise par
   défaut, agrandi deux fois, **même cadre** pour défaut et essais).

### Pourquoi « tous » et pas un par un

La tâche demandait le jeu par défaut contre le jeu « avec tous les essais ». Chaque essai seul a déjà sa planche
(`docs/iso/cloud/essais/`, `enseignes/`, `fusee-rouge/`) ; ici la question est l'écart **total** à l'illustration, donc
l'image la plus proche que la nuit sache produire. Deux essais éteints existent en plus et ne sont PAS dans « tous », faute
d'avoir été demandés : `--fumee-masque` (le noir sous la fumée, qui l'assombrit, non la rapproche) et les variantes du
point de braise (`--fusee-coeur`, `--fusee-coeur-blanc`). L'usure des murs n'est plus un essai : elle est **au défaut**
(Q30 = A, `iso_materiaux.gd:171`), donc présente dans les deux colonnes.

## Les chiffres qui résument l'écart

Luminance Rec. 709 des valeurs sRGB, 0..255. Détail par image dans `mesures.json`.

| | illustrations (les 19 autres que l'extinction) | le jeu, duel par défaut | le jeu, tous les essais |
|---|---|---|---|
| médiane de l'image | 4 à 51 (16 à 51 hors « le prix », noir à moitié) | **0** | 0 |
| 9ᵉ décile | 85 à 232 | **28** | 28 |
| 1 % le plus clair (la lumière) | 138 à 251, couleur crème (≈ 220-250, 180-240, 110-220) | **126**, ocre (172, 144, 99) | 126 |
| part de l'image au-dessus du noir (7,5) | 48 à 85 % | 45 % (le vide autour de la carte est à 0) | 45 % |
| corps du joueur local | ardoise sombre, ~40-60 | **bleu glacier, ~138** (115, 143, 162) | idem, cerné de noir |

L'extinction, à part : noire à 93 %.

**Lecture.** Ce qui éloigne le plus le jeu des dessins tient en trois nombres : les dessins montrent une pénombre
lisible partout (médiane 16-51 contre 0, hors « le prix ») — c'est ce que le jeu ne doit pas faire ; leur lumière est plus claire et plus
pâle (1 % le plus clair ~230 crème contre 126 ocre) — c'est ce qu'il peut faire ; leurs personnages sont sombres et le
nôtre est clair — il peut aussi.

## Ce que les essais changent, mesuré

Des essais au défaut, au même instant (même graine, même image de jeu) : **10 000 à 19 000 pixels changent par scène**,
presque tous **plus sombres** (hachures de l'encre, contours, tuyaux, enseignes et pochoirs sombres) ; **175 à 450 plus
clairs** (la perle du cœur chaud à la lampe, ~13 px, et son reflet). Aucun pixel noir ne s'allume dans les scènes de duel,
de mur, de sol, d'enseigne, d'impacts et d'entraînement (0) ; **1** dans la scène torches éteintes (au niveau du bruit) ;
**80** en écran scindé (bruit : 4) — la perle du cœur chaud à la lampe de J2, déjà signalée par la session « essais »
(133 pixels, même cause). À la fusée, le rouge long garde à 4 s une lumière que le défaut a déjà laissé jaunir : 65 000
pixels plus clairs et 876 pixels noirs allumés **par la lumière de la fusée elle-même** (plus longtemps forte, elle porte
plus loin) — ce n'est pas une fuite du noir, c'est l'essai.

**À la taille du jeu, les essais se voient peu** : à 1920×1080 plein cadre, l'image « tous » se distingue à peine de
l'image par défaut ; il faut la loupe pour lire les enseignes, les pochoirs et les tuyaux. C'est cohérent avec leur
règle (plus sombres que la surface qui les porte), et c'est le prix de cette règle.

## Illustration par illustration

Le détail — description, images, tableau par thème et verdict devant les invariants — est dans `planche.html` (et en texte
dans [`ILLUSTRATIONS.md`](ILLUSTRATIONS.md)). En bref :

| illustration | scène du jeu | ce qui en est le plus loin |
|---|---|---|
| accueil | `arena` | le cadrage ; la pénombre lisible ; la lampe crème ; les douilles de décor (contredit) |
| amical | `zone` | le « ZONE 4 » BLANC (le jeu le peint sombre, à raison) ; deux cônes dans l'air |
| amical_ligne | `mur` | baies de serveurs à LED cyan ; câbles au plafond (le jeu n'a pas de plafond) |
| amical_local | — | armurerie à écrans verts : un décor de menu |
| competitif | `impacts` | couleurs d'ambiance (rouge, cyan) ; douilles en nappe (contredit) |
| creer_ligne | `fusee1` | le rouge SANG, sombre (contredit, établi par la session « fusée rouge ») ; fumée sombre en rouleaux |
| creer_local | `sol` | marquages BLANCS au sol (le jeu : noirs à 45 %) ; chaînes ; mezzanine |
| ecran_scinde | `scinde` | une couleur de torche par joueur (équité à mesurer) ; plafond, poutres |
| entrainement | `entrainement` | une lampe fixe au plafond ; le tapis de douilles (ici sans enjeu) |
| intro_allumage | `impacts` | le faisceau poussiéreux dans l'air ; le béton pâle sous la lampe — la plus proche du jeu |
| intro_descente | — | un escalier : le jeu n'a pas de niveaux |
| intro_dotation | — | un gros plan d'objets |
| intro_extinction | `noir` | l'illustration est PLUS noire que le jeu (les LED des murs n'y sont pas) |
| intro_prix | `duel` | l'ombre portée géante du joueur (contredit : elle suppose une lumière derrière lui) |
| intro_seuil | `arena` | une porte, et la lumière d'une autre pièce |
| mise_a_jour, retour | — | la porte du coffre « VAULT 07 » : métaphores de menu |
| quitter | — | une lampe restée allumée au sol, sans joueur |
| rejoindre_ligne | `mur` | les faisceaux de câbles serrés ; une source bleue fixe |
| rejoindre_local | `sol` | **le même fichier que creer_local**, octet pour octet (md5 `783d77a2…`) |

## Ce que les illustrations montrent et que le jeu ne DOIT pas montrer

C'est la moitié de la réponse, et elle revient dans presque chaque tableau :

1. **La pénombre lisible partout.** Murs, sols, plafonds se lisent en gris loin de toute lampe (médiane 16-51). Le jeu
   repose sur le contraire : hors de la lumière, rien. À ne pas combler.
2. **Le plan à hauteur d'homme.** Le personnage à 60-80 % de la hauteur, un couloir qui s'enfonce, un plafond. Le jeu est
   vu de haut, et c'est ce qui le rend jouable et équitable (chacun voit autant autour de soi). Les menus, l'intro, la
   killcam et l'écran de fin peuvent emprunter ce cadrage ; le duel non.
3. **Du clair posé sur du sombre sans lumière** : le « ZONE 4 » et les marquages blancs, le panneau ARENA clair, les
   douilles en laiton qui brillent, les LED cyan qui n'éclaireraient rien. Le jeu les rend sombres (enseignes, pochoirs),
   comme le veut la règle des pochoirs.
4. **Les douilles et les impacts de décor.** Dans le jeu, une douille ou un impact est une **information** (on a tiré ici).
   En semer d'avance mentirait au joueur. Seule exception honnête : l'entraînement.
5. **Les ombres portées impossibles** (intro_prix) et le **rouge sang** sombre de la fusée, qui ferait voir moins sous une
   lumière que les deux joueurs partagent.

## La synthèse : les cinq manques qui changeraient le plus l'image

Classés par ce qu'ils changent à l'image (combien d'illustrations les montrent), parmi ceux qu'on peut combler. Les
coûts sont comptés **en dessins** comme l'a fait la session « Budget » (`origin/claude/cloud-budget`,
`docs/iso/cloud/budget/RAPPORT.md`, `tools/cloud_budget/`) : appels de dessin par image, primitives, passes. **Ce sont des
estimations par analogie avec ses mesures, pas des mesures** : je n'ai pas lancé son instrument sur ces manques, qui
n'existent pas encore. Aucun coût par pixel (celui des shaders) ne se voit dans ces comptes ; il se mesure sur le Mac.

| # | manque | illustrations | coût en dessins (estimé) | invariants | décision d'Adrien ? |
|---|---|---|---|---|---|
| 1 | **Une lumière de lampe plus claire et plus pâle dans le cône** : le sol et les murs éclairés vers 200-240 crème au lieu de ~126 ocre | 10 (toutes celles qui montrent une lampe) | **0 appel, 0 primitive** : l'énergie et la couleur de la lumière, l'albédo des matières (comme Q34/Q35 : 0) | compatible : rien ne sort du cône. À surveiller : l'éblouissement et la lecture d'un adversaire dans le cône (plus de contraste) | **oui** — c'est le calibrage de la torche (portée ISO8, éblouissement) |
| 2 | **Des personnages sombres cernés d'un liseré clair du côté de la lumière** (luminance ~50 au lieu de ~138 pour le joueur local) | 16 | **0 appel** : tout dans le shader des corps, comme le mannequin (0 au budget) | compatible : plus sombre est toujours permis ; le liseré seulement du côté d'une lumière réelle | **oui** — le joueur doit se retrouver à l'œil sur son écran : sa propre lisibilité est un choix de jeu |
| 3 | **Le faisceau visible dans l'air, avec sa poussière** | 9 | +2 à +6 appels par vue (des couches de volume par torche ; le cœur chaud seul en coûte +2 par vue) et du remplissage transparent sur une grande surface — **à mesurer au Mac** | **contredit en l'état** : essayé et retiré le 2026-09-24 (il salit le noir avant de se voir, 3/255 au mieux ; parallaxe et lissage établis) | **oui** — la ROADMAP le lui renvoie déjà (hauteur de la lampe face aux murets) |
| 4 | **Des murs meublés** : portes rivetées, boîtiers électriques, grilles, faisceaux de câbles serrés — au-delà des tuyaux et des enseignes de l'essai | 11 | par famille, un maillage fusionné : **+1 appel par vue** (+2 en écran scindé), mais des primitives — les tuyaux seuls **triplent** celles de la scène 3D (+13 800, jusqu'à +20 000) | compatible, si chaque objet reste plus sombre que le mur, sans géométrie qui cache un corps | non pour l'essai (derrière un drapeau) ; **oui** pour allumer tuyaux et enseignes |
| 5 | **Un sol jonché et marqué** : gravats épars, chaînes, bandes de marquage, lettres — les pochoirs de l'essai en sont le début | 13, douilles comprises (5 sans elles : gravats, chaînes, marquages) | **0 appel** : cuit dans la peinture du sol, comme les pochoirs (93 = 93 au budget) | compatible **sans** douilles de décor (contredit : fausse information) et sans marquage clair | **oui** pour allumer les pochoirs ; non pour un essai de gravats |

**Hors classement**, parce qu'il ne faut pas les combler dans le duel : le cadrage à hauteur d'homme et la pénombre
lisible (voir plus haut). **Juste après les cinq** : l'encre (l'essai la porte déjà ; ce qui manque, des arêtes plus
épaisses partout, se mesure en pixels, pas en dessins) ; la fumée sombre de la fusée (0 appel, compatible seulement si
elle ne s'allume que dans la lumière de la fusée — la garantie du masque de fumée, éteint) ; les lumières d'ambiance
colorées fixes (cyan, vert, rouge) — chacune est une lumière de plus, et une lumière 2D à ombre ajoute une passe que le
compteur d'appels ne voit pas (budget : « la passe d'ombre d'une lumière 2D n'entre pas dans le compteur ») ; et une
lumière fixe change le jeu (qui passe devant se voit) : **décision d'Adrien**.

## Pièges et défauts découverts, à reporter dans la feuille de route

1. **Deux illustrations sont un seul fichier.** `assets/ui/ill_creer_local.png` et `assets/ui/ill_rejoindre_local.png`
   ont la même empreinte (`md5sum assets/ui/ill_*.png | sort | uniq -w32 -D`). Si les deux écrans devaient différer, l'un
   manque ; sinon, le doublon pèse pour rien dans l'export. Signalé, pas corrigé (hors tâche).
2. **Six illustrations d'intro sont à 2048×1280, pas 1024×640** (`ill_intro_*`). La consigne parlait de « vingt
   illustrations 1024×640 » ; quiconque les compare au pixel doit le savoir. Signalé, pas corrigé.
3. **Le `git apply` des corrections du photographe (0c67705) échoue sur `integration-iso14`** : elles y sont déjà
   (`a8bba4f`). Une consigne future qui le demande devrait dire « si absentes » — le vérifier par
   `git log --oneline -3 -- tools/photographe.gd`.
4. **Un `user://` à part pour les séances de photos** (`XDG_DATA_HOME=…`) : lancées en même temps que la suite complète,
   elles ne partagent ainsi ni réglages ni fichiers avec elle. Coût : un `user://` neuf joue l'intro — `photo_ecart.gd` la
   congédie comme `photo_essais.gd`.
5. **Le bruit entre deux lancements, avec graine et `--fixed-fps 60`, est quasi nul** (0 à 364 pixels par scène,
   **0 pixel à la fusée à 4 s**) : le protocole de `photo_essais.gd` tient, et un écart de dix mille pixels entre deux
   lancements est un vrai écart.

## Pour tout refaire

```bash
git fetch origin claude/cloud-ecart-illustrations && git checkout claude/cloud-ecart-illustrations
godot --headless --path . --import                       # la première fois
pip install pillow numpy                                  # pour les mesures
# Les trois lancements (~10 min chacun sous llvmpipe), les mesures, la planche :
XDG_DATA_HOME=$PWD/.xdg GODOT=/usr/local/bin/godot ./docs/iso/cloud/ecart-illustrations/lancer.sh
# Ou une seule séance, quelques scènes :
GODOT_ARGS= xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_ecart.tscn -- \
    --no-eos --led-murs-fige --sortie=user://ecart/essai --scenes=duel,arena [--faisceau …]
# Les mesures et la planche seules, sur des prises existantes :
ECART_SOURCE="<dossier user://ecart>" python3 docs/iso/cloud/ecart-illustrations/mesurer.py
python3 docs/iso/cloud/ecart-illustrations/planche.py
# La suite complète :
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
```

Sur le Mac : `ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/ecart-illustrations/lancer.sh`,
la fenêtre au premier plan.

## Ce que je n'ai PAS pu prouver

- **Les coûts de la synthèse** sont des estimations par analogie avec les mesures de la session « Budget » ; aucun des
  cinq manques n'existe, rien n'a été compté. Et rien de ce qui se paie au pixel (shaders des corps, remplissage d'un
    faisceau, éblouissement) ne se voit dans un compte de dessins : **cadence à mesurer sur le Mac**.
- **Aucune cadence** : le cloud tourne à quelques images par seconde ; aucun chiffre de ce rapport n'en est une.
- **Les couleurs** valent à ~1/255 du Mac (rendu llvmpipe) ; l'**éblouissement** et le **geste des corps** ne valent rien
  ici (les corps respirent à l'horloge du processeur ; le bruit mesuré entre lancements reste pourtant faible).
- **La scène la plus proche est un choix** : j'ai pris onze scènes que l'outil sait poser au même instant pour deux
  lancements. Une autre carte, un autre angle de torche, un autre instant de fusée auraient pu être plus proches de
  certaines illustrations ; la loupe corrige en partie l'échelle, pas le choix.
- **« Quitter »** (une lampe allumée au sol, sans joueur) aurait peut-être une scène proche en fin de manche ; l'outil ne
  sait pas la poser au même instant pour deux lancements, je ne l'ai pas tentée.
- **La mise en page sur téléphone** de `planche.html` : vérifiée à 1400 px de large ; à 390 px, Chromium sans tête rend
  une fenêtre d'au moins ~500 px et coupe la capture — la règle d'une colonne sous 800 px est posée, mais je ne l'ai pas
  vue rendue à la vraie largeur d'un téléphone.
- **Les verdicts « compatible / contredit »** sont des lectures des invariants écrits (CLAUDE.md, ROADMAP, consignes), pas
  des décisions : ceux qui disent « à condition » attendent Adrien.
