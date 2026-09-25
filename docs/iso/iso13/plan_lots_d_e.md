# ISO13 — lots D (la fusée) et E (le faisceau) : où le code devra changer

Préparation faite le 2026-09-24 **sans lancer Godot**, sur l'ordre de la session cloud, et sans
toucher à l'arbre de mesure (`b193420`). Ce document dit *où* et *pourquoi*, pas encore *quoi* : rien
n'est modifié tant que les lots ne sont pas ouverts.

La cible est l'évaluation « Le jeu contre ses illustrations » (session cloud, évaluation 1), qui range
les deux familles en **Manque**.

## Ce que l'évaluation demande

**Fusée** — l'illustration : lumière rouge saturée qui teint les murs et le sol proches, cœur blanc,
étincelles, fumée dense rouge sombre. Le jeu : halo rose, fumée pastel beige, peu de rouge sur le
décor, cœur qui ne brille pas.

**Faisceau** — l'illustration : le rayon se voit dans l'air, cœur blanc-jaune à la lampe, poussière
qui scintille. Le jeu : le cône éclaire le sol, bords nets ; ni rayon, ni poussière, ni cœur chaud.

## Lot D — la fusée : trois endroits, et un qu'il ne faut pas toucher

**Ce qu'il ne faut pas toucher** : `fusee_modele.gd` **ne connaît aucune couleur**, et sa doc le dit —
« l'appelant mappe sur ses couleurs (Charte) ; le modèle ne connaît pas la charte, il doit rester sans
dépendance ». Les paliers, la durée des actes et `temperature_a()` vivent là et restent intacts : le
garde-fou « tes paliers (trois de fumée, quatre de halo) » est donc tenu **par construction**, à
condition de ne rien écrire de coloré dans ce fichier.

Les trois endroits sont tous dans `fusee.gd` :

1. **Le rouge sur le décor** — `COULEUR_DETRESSE := Color(0.96, 0.293, 0.334)` (ligne 25), mêlée vers
   `Charte.AMBRE` selon la température, sert de couleur à la `Light2D`. C'est elle qui teint les murs
   et le sol. ⚠️ **Cette couleur entre dans la lightmap**, donc dans le relief iso et dans tout ce qui
   lit la lumière : la saturer n'est pas un geste d'image isolé, et l'effet se juge au banc, pas à
   l'œil.
2. **La fumée** — `nappe.modulate = Color(0.94, 0.56, 0.27, 0.0)` (ligne 263) est exactement le
   « pastel beige » que l'évaluation nomme. La densité, elle, passe par `alpha_fumee_a()` du modèle
   (sans couleur) et par le `modulate` ; la piste est donc la teinte ici, la densité par le facteur
   appliqué, jamais par un palier du modèle.
3. **Le cœur** — `_coeur.modulate` reprend *la couleur de la lumière* (ligne 617). D'où « un cœur qui
   ne brille pas » : il ne peut pas être plus clair que son halo. Un cœur blanc demande de le
   **découpler** de la couleur de la lumière. Les étincelles n'existent pas encore.

## Lot E — le faisceau : la machinerie existe déjà, et ce qu'elle garantit vraiment

`iso_volumes.gd` élève « ce qui n'a pas de corps mais une épaisseur ou une hauteur » — nuages, nappes,
sources qui brûlent au-dessus du sol. **Le rayon dans l'air et les grains de poussière sont exactement
cela.** Trois propriétés de ce fichier en font le bon endroit, et pas un endroit choisi par commodité :

- **Rien n'y est lu par la simulation**, ni la balle, ni l'éblouissement, ni les capteurs, ni les
  lightmaps. Le garde-fou « les règles de l'éblouissement inchangées » est tenu sans vigilance.
- **Le noir absolu y est tenu DANS LE MONDE** : un volume vaut la lightmap sous lui, donc 0 sans
  lumière. ⚠️ Ce point a d'abord dit « par construction », sans réserve : **c'est faux à l'écran**, où
  une couche en hauteur est décalée par la parallaxe. Voir « Mesures du 2026-09-24 » plus bas.
- **Aucune `Light3D`** : le rayon ne serait pas une lumière de plus, donc pas un coût de lampe.

Le cœur chaud près de la lampe relève en revanche de `player.gd` (`flashlight`, lignes 1187 et 1953),
au même titre que le cœur de la fusée : c'est une source, pas un volume.

## Ce que la mesure de cette nuit donne au chantier

Le cas le plus lourd — **le pompe sous une fusée** — est mesuré depuis le 2026-09-24 sur `b193420` :
**médiane 85, 1 % bas médian 77**, les huit prises au-dessus de 60 (§ 14 de
`docs/iso/iso12/mesurer_une_cadence.md`). C'est la référence contre laquelle tout ajout d'image de ces
deux lots devra se comparer, dans les mêmes conditions et avec le même protocole.

⚠️ **Ce paragraphe a d'abord dit que l'évaluation se trompait** en appelant cette marge « pas encore
mesurée ». C'était moi qui me trompais : je lisais la **version 1** (23:57), écrite avant la mesure,
et la version 2 (00:37) la porte déjà. Une page qui se met à jour à chaque livraison n'a pas de
« contenu » mais un contenu *daté* — on corrige la version qu'on a lue, pas la page. Même leçon qu'au
paragraphe audio de `CLAUDE.md` : un constat daté vieillit sans prévenir, y compris en une demi-heure.

## L'ordre que je propose, et pourquoi

Le faisceau (E) avant la fusée (D). Non par facilité, mais parce que E s'ajoute dans un fichier dont
les règles d'équité sont tenues dans le monde sans toucher à la lumière (à l'écran, voir plus bas), tandis que D
modifie une couleur **qui entre dans la lightmap** — donc dans le relief, les capteurs et l'image des
deux joueurs. Faire E d'abord, c'est livrer une planche et un coût mesuré avant d'ouvrir le sujet qui
peut déplacer autre chose que lui-même.

## La contrainte du lot D, posée par le cloud avant qu'une ligne soit écrite

**Ce que lisent la visibilité, les capteurs et l'éblouissement ne doit pas bouger.** Donc, palier par
palier, la lumière de la fusée **garde sa luminance dans la lightmap**, et seule la teinte *visible*
change : les nappes, le décor, et un cœur découplé de sa lumière. Si ce n'est pas tenable — et ce
n'est pas évident, puisque saturer une couleur à luminance constante contraint fortement la teinte —,
la marche à suivre est de **mesurer les lectures de ces trois consommateurs, par palier, avant et
après**, et de laisser le cloud trancher sur les chiffres plutôt que sur une impression.

Les paliers et le rouge de détresse au départ restent : décisions d'Adrien, non rouvertes ici.

## La planche du lot E

La capture 1:1 à côté des illustrations de **l'accueil** et de **l'intro « allumage »**, avant et
après, le noir absolu vérifié, et le coût mesuré contre la série au pompe sous une fusée — 85 de
médiane, 77 au 1 % bas médian — qui est désormais la référence.

Drapeaux éteints dans les deux cas, et chaque lot livre sa planche : la capture 1:1 à côté de
l'illustration nommée, **avant et après**, avec le paragraphe « ce qui manque encore ».

## État du lot E au 2026-09-24, 01:05 : écrit, lot vert, mesure en attente

Le rayon et le cœur chaud sont dans `iso_volumes.gd`, derrière `--faisceau`, **éteint par défaut**.
Le lot complet passe (435 s).

Trois choix, et leurs raisons :

- **Le masque du rayon est la texture de la lampe elle-même.** Le cône ne peut donc pas diverger de
  la lumière : il suit l'arme, la portée et toute modification future sans qu'on revienne ici.
- **Les grains de poussière ne sont pas des particules.** C'est le grain que `volume_iso.gdshader`
  applique déjà à l'alpha, animé par `age` : la poussière scintille sans un seul objet de plus, donc
  sans coût d'objet ni d'appel de dessin.
- **Le drapeau se lit sur les arguments utilisateur**, dans `IsoVolumes._init()`, et non dans un banc :
  il porte ainsi partout — jeu, banc de cadence, photographe — sans qu'aucun d'eux n'ait à le connaître.

⚠️ **Le point d'équité, qui était le vrai risque du lot — et que ce paragraphe a d'abord déclaré
réglé.** Il disait : « il ne le peut pas : une couche vaut la lightmap sous elle ». C'est vrai dans le
monde, faux à l'écran, et la mesure l'a montré dès que la densité a monté (plus bas). La garde de
`tools/test_iso_gadgets.gd` reste utile — elle empêche qu'on remplace le masque par une forme à soi —
mais elle ne voit aucun pixel, et elle ne prouvait donc pas ce que ce paragraphe lui faisait prouver.

**La mesure attend deux choses**, dans cet ordre, sur ordre de la session cloud : la fusion de la garde
de Beauté dans `iso12-lumiere3d` — sans elle le chemin par défaut paie un aller-retour `pow` du
mannequin même éteint, et la référence ne serait plus le jeu d'avant —, puis **une seule fenêtre** pour
les deux lots : référence, E seul, A seul, E et A ensemble, au pompe sous une fusée, en miroir. Règle
posée d'avance : une variante tient si le rapport de ses médianes au défaut atteint 0,970 et si la
médiane de ses 1 % bas dépasse 60.

## Le photographe sait viser (`--visee=x,y`)

Ajouté au photographe le 2026-09-24, **sur autorisation explicite de la session cloud** : c'est le
fichier d'un autre chantier (DA6), et la règle est de signaler, pas de corriger. Le drapeau est
strictement additif — sans lui, `VISEE` garde (1,0 ; 0,36) et les cinq usages lisent la même valeur
qu'avant, donc aucune planche déjà prise ne change.

**Pourquoi il fallait ce drapeau** : le photographe vise dans une seule direction, choisie pour la
composition (« le cône traverse le cadre en biais, ce qui se recadre en carré sans perdre sa pointe »).
Or le feuilletage d'un volume fait de plans empilés se juge dans son **pire cas**, le rayon suivant
l'axe vertical de l'écran, où le décalage des couches s'ajoute à la longueur du rayon. Choisir une
densité sur la seule visée de composition, c'était choisir deux fois.

⚠️ Une visée nulle ou mal formée **échoue** au lieu de retomber en silence sur la composition : une
planche prise dans une direction qu'on croit avoir choisie serait un faux résultat crédible.

## Mesures du 2026-09-24, 01:30 → 01:48 : le rayon ne se lit pas, et le noir casse à l'écran

Plan `torche`, trois densités × trois visées (`--visee`, ajouté pour cela), chacune contre une
référence sans faisceau. « Isolés » : pixels noirs dans la référence, non noirs avec le faisceau, et
à plus de 2 px de toute lumière de la référence.

    visée   densité   médiane dans le cône   couverture   pixels isolés dans le noir
    bas     0,08      2/255                   7 %           2
    bas     0,22      2/255                  10 %         160
    bas     0,45      3/255                  16 %         313
    haut    0,08      1/255                   7 %           1
    haut    0,22      2/255                   9 %         151
    haut    0,45      3/255                  16 %         307
    côté    0,08      2/255                   8 %           1
    côté    0,22      2/255                  11 %         154
    côté    0,45      3/255                  18 %         307

**Deux conclusions.** Le rayon ne se lit dans aucune : 3/255 de médiane au mieux. Et le noir absolu
casse d'autant plus que la densité monte, dans les trois visées.

**La cause, établie par intervention et non déduite**, visée haut à 0,45 :

    contrôle, deux références sans faisceau     1     ← le bruit d'un lancement à l'autre
    faisceau tel quel                          307
    couches posées au sol                       15    ← la parallaxe retirée
    lissage de la lightmap coupé               400    ← le flou n'y est pour rien

C'est la **parallaxe** : une couche lit la lightmap du sol sous elle, mais, en hauteur et sous un
tangage de 52°, elle est dessinée plus haut à l'écran que ce sol — sur des pixels où il peut être
noir. La lumière du sol la plus proche d'un pixel isolé est trois fois plus souvent **en dessous**
qu'au-dessus (142 contre 50, 150 contre 46, 138 contre 33), ce qui est la signature attendue.

**Ce que « tenu par construction » voulait dire, et ce qu'il fallait dire.** La lecture de la
lightmap garantit le noir **dans le monde** : une couche vaut zéro au-dessus d'un sol noir. Elle ne le
garantit pas **à l'écran**. La planche `ef2fae1` l'avait « vérifié » dans le seul cas qui passait
(0,08, visée de composition) ; la garde de `tools/test_iso_gadgets.gd` ne voit aucun pixel et ne
pouvait pas le prouver.

**Une tension avec une décision d'Adrien**, non tranchée ici : les lampes du joueur n'ont pas de
hauteur face aux murets (ROADMAP, 2026-09-15), sans quoi elles dessinent « vu, pas touché ». Un rayon
dont les couches montent à 0,45 tuile, au-dessus des murets de 0,40, leur en redonne une à l'image.

**État** : `--faisceau` reste éteint, aucune densité n'est retenue. La densité se règle désormais au
lancement (`--faisceau=0,22`) et le faisceau l'annonce (« [faisceau] allumé — densité par couche »),
ce qui prouve que le drapeau a porté.

### La fumée de la fusée, allumée par défaut : question ouverte, deux instruments sans réponse

Elle suit le même patron de couches, et monte à une tuile. Deux tentatives :

- **Entre deux lancements**, la lumière de la fusée elle-même varie : sans aucun volume, deux
  lancements donnent jusqu'à **253** pixels « isolés ». Les écarts mesurés avec la fumée (0, 1, 1, 99
  selon la paire) sont dans ce bruit. Indécidable.
- **Dans le même lancement**, la loupe `loupe-fusee-suie` coupe les volumes à âge figé : 0 pixel
  isolé — mais **aucun pixel noir dans le cadre**, que la fusée éclaire entièrement. Le zéro est vide.

Pour répondre, il faut une prise **plein cadre, dans le même lancement**, volumes coupés puis
rétablis, cadrée sur le **bord** de la lumière de la fusée. Ce serait une étape du photographe
(DA6) : signalé, pas construit.

## Décision du 2026-09-24, 02:03 : le rayon s'arrête

La session cloud tranche sur la planche publiée (https://claude.ai/artifact/L3B4q5bD3QKsiiya8NrLmR) :
**`--faisceau` = le cœur chaud à la lampe, seul.** Le rayon est retiré du code — pas mis à densité
nulle, ce qui poserait encore des couches, les paierait, et laisserait une réécriture les rallumer sans
que rien ne rougisse. La garde de `tools/test_iso_gadgets.gd` vérifie désormais qu'aucune couche n'est
posée sur le chemin du drapeau. Le réglage de densité au lancement (`--faisceau=0,22`) part avec lui.

Le cœur, lui, est posé à 0,20 tuile, **sous** les murets de 0,40 : il ne redonne pas de hauteur à la
lampe. Et il était déjà allumé dans toutes les prises à 0,08, qui n'ont montré que le bruit (1 à 2
pixels isolés) : il ne salit pas le noir.

Ce qu'il faudrait pour que le rayon revienne est à la ROADMAP (Pièges connus, « Une garantie vraie dans
le monde n'est pas vraie à l'écran »).

## Mesures du 2026-09-24 après-midi : la fumée en sandwich, et ce que coûtent A et E

### La fumée de la fusée semble salir le noir comme le rayon — non établi

`loupe-fusee-bord` (`f867ad7`), deux lancements sur `76fe78f`, l'instrument étant le diff même de ce
commit, posé puis retiré. La fenêtre entière, trois fois dans le même lancement : volumes coupés,
rétablis, recoupés ; la fusée seule, à la braise.

**L'instrument a d'abord rendu un zéro vide, et l'a dit** : les six prises ont 0 pixel noir. Dans la
scène de la loupe, ~40 % du cadre repose sur un plancher de 2 à 4/255 — très probablement le voile
d'éblouissement de J1 (0,06). En prenant « noir » = au plus 4/255 (un choix, pas une donnée) :

    lancement   bruit coupé-1 → coupé-2   bruit coupé-2 → coupé-1   fumée contre coupé-1   fumée contre coupé-2
    1                 89 867                     665                     18 641                  7 598
    2                101 606                     674                     20 240                  7 296

Contre la prise la plus tardive, la fumée ajoute ~7 400 pixels isolés quand la dérive inverse en donne
~670 ; et la lumière du sol est deux fois plus souvent **en dessous** de ces pixels qu'au-dessus (4 996
contre 2 506 ; 4 855 contre 2 333) — la signature de la parallaxe, plus faible que pour le rayon.
**Deux réserves empêchent de l'affirmer** : le noir redéfini, et une scène qui **dérive** au sein du
lancement (≈100 000 pixels s'éclaircissent entre la 1re et la 3e prise, toutes deux sans volumes : l'âge
« figé » de la fusée ne l'est probablement pas). Pour l'établir : une scène sans voile (torche de J1
éteinte) et une fusée réellement figée. C'est du jeu déjà allumé : signalé, pas corrigé ; la décision
est à Adrien.

### Les lots A et E ne coûtent rien de mesurable

Quinze prises sur `76fe78f` (témoin T = `b193420`), au pompe sous une fusée, vue unique, dans l'ordre
T D A E AE E AE T D A A AE D E T (position moyenne 8 pour chaque état). Aucune prise refusée ; le lot A
prouvé par une vérification initiale dans l'arbre mesuré et par la ligne de commande effective de chaque
prise, le lot E par la ligne qu'il imprime.

    état   médiane des médianes   1 % bas médian   contre sa référence
    T             88                   78
    D             89                   76            D/T = 1,011   tient
    A             88                   77            A/D = 0,989   tient
    E             88                   77            E/D = 0,989   tient
    AE            88                   78           AE/D = 0,989   tient

Spotlight était actif dans neuf fenêtres sur quinze (jusqu'à 91 %) sans effet lisible, et le témoin aux
positions 1, 8 et 15 donne 88, 88, 88 : aucune dérive.

## Mesures du 2026-09-24 au soir : la fuite de la fumée établie, sa cause prouvée, et un masque à zéro

### La fuite est établie

`loupe-fusee-bord-noir` (`cac6e05`) : les **deux torches éteintes**, pour que la scène ait un vrai noir
sans voile d'éblouissement, et cinq prises serrées dans le même lancement — fumée coupée, rétablie,
coupée, rétablie, coupée. La scène dérive, mais **dans un seul sens** : elle s'éclaircit (≈542 000
pixels dans un sens, 0 dans l'autre). On compare donc chaque prise avec fumée à la prise coupée
**suivante**, plus éclairée qu'elle : un pixel noir dans celle-ci ne peut pas devoir sa lumière à la
dérive. Sur `8cf2aa1`, deux lancements : **~10 700 pixels** noirs sans fumée sont éclairés avec elle
(10/255 en médiane, 31 au plus), à 0,5 % près d'un lancement à l'autre.

### La cause est le lissage, pas la parallaxe

La fuite déborde du disque éclairé dans **toutes** les directions (13 px en médiane, 59 au plus) :
l'échelle de `lire_lightmap_lissee`, qui lit la lumière sur un cercle de 0,18 × le rayon de la fumée.
Prouvé par intervention, sur `3a1c799`, un seul changement à la fois, deux lancements chacun :

    intervention                            pixels fautifs (1re prise)   (2e prise)
    aucune (référence du même tour)            10 222 · 11 154          4 678 · 4 408
    lissage coupé, couches en hauteur           2 613 ·  2 657          1 203 · 1 248     −75 %
    couches au sol, lissage gardé              10 665 · 11 756          3 564 · 3 617     parallaxe mineure
    garde : lumière BRUTE sous la couche nulle 11 750 · 11 693          4 359 · 4 264     aucun effet
    masque d'écran (sol et murs affichés noirs)     0 ·      0              0 ·     0     zéro

**La garde par la lumière brute ne fait rien**, et je l'avais recommandée sans l'avoir mesurée : sous
la fuite, la lumière n'est pas nulle, elle est faible — le sol, sombre, l'affiche à 0 ; la fumée, ambre
et claire, à quelques niveaux. Le **masque d'écran** tait la couche là où l'écran copié derrière elle
(`hint_screen_texture`, copié après l'opaque, avant le transparent, supporté en `gl_compatibility`) est
noir. Zéro aux deux lancements, sur une prise où 1,32 à 1,36 million de pixels sont noirs — un zéro non
vide —, et rien retiré à l'intérieur de la lumière. L'instrument (`poser.py`, quatre modes) n'est pas
commité : c'est du diagnostic. **Rien n'est changé dans le jeu** : la voie A de Q31 attend la réponse
d'Adrien et le coût en cadence du masque.

### Ce que coûte le masque : +0,70 ms par image

Six prises sous la porte stricte, pompe sous une fusée tenue en braise par le banc (fumée pleine toute
la prise), vue unique, M0 M1 M1 M0 M0 M1. **M0 est l'arbre propre** (`3a1c799`), pas l'instrument éteint :
un shader qui DÉCLARE `hint_screen_texture` fait copier l'écran même quand la branche qui le lit est
fermée, et un « masque éteint » aurait payé la copie. M1 : la même tête plus `poser.py` (empreinte du
diff `e78dfc58`), prouvé par la ligne « [diag fumée] mode « ecran » », qu'aucun M0 n'imprime. Deux prises
refusées et refaites (`duetexpertd` 57 %, `contactsd` 31 %).

    état   médianes        1 % bas         médiane des médianes   1 % bas médian
    M0     88 · 86 · 87    78 · 76 · 63           87                   76
    M1     82 · 82 · 82    60 · 66 · 67           82                   66

**0,943 : le masque ne tient pas la règle des 3 %**, et reste au-dessus de 60 au 1 % bas. C'est le coût
de **cet instrument** — la copie de l'écran, une lecture par pixel de fumée et par couche, et une boucle
de `set_shader_parameter` par image —, pas celui d'une version travaillée. Il chiffre la voie A de Q31 ;
il ne la tranche pas.

### L'usure (Q30) ne tient pas au calme

La première série (U0 U1 U1 U0 U0 U1 sur `3a1c799`, pompe sous une fusée, vue unique) rendait 0,977 —
mais deux des trois U0 avaient tourné sous « Creative Cloud » (47 % et 106 % d'un cœur) : sans verdict.
**Refaite sous la porte stricte** (voir `docs/iso/iso12/mesurer_une_cadence.md` §16), deux prises
refusées et refaites (`BackgroundShortcutRunner` 53 %, puis `backupd` 201 % — Time Machine), chaque U1
prouvé par la ligne « [usure] allumée — variante USURE_ESSAI posée » que le jeu imprime :

    état   médianes        1 % bas         médiane des médianes   1 % bas médian
    U0     89 · 89 · 89    76 · 69 · 79           89                   76
    U1     84 · 84 · 84    74 · 66 · 74           84                   74

**0,944 pour un seuil de 0,970 : +0,67 ms par image. L'usure ne tient pas la règle.** Le 1 % bas reste
à 74, jouable. La première série se trompait **dans le sens flatteur** : la pollution avait abaissé
deux U0, pas les U1. Une prise polluée ne fait pas que du bruit ; elle peut tourner le verdict.
