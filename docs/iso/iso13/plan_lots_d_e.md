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

## Lot E — le faisceau : la machinerie existe déjà, et elle garantit le noir absolu

`iso_volumes.gd` élève « ce qui n'a pas de corps mais une épaisseur ou une hauteur » — nuages, nappes,
sources qui brûlent au-dessus du sol. **Le rayon dans l'air et les grains de poussière sont exactement
cela.** Trois propriétés de ce fichier en font le bon endroit, et pas un endroit choisi par commodité :

- **Rien n'y est lu par la simulation**, ni la balle, ni l'éblouissement, ni les capteurs, ni les
  lightmaps. Le garde-fou « les règles de l'éblouissement inchangées » est tenu sans vigilance.
- **Le noir absolu y est tenu par construction** : un volume vaut la lightmap sous lui, donc 0 sans
  lumière. « Rien hors de la lumière » n'est alors pas une précaution mais une conséquence — et
  `tools/test_iso_gadgets.gd` le prouve déjà.
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
les trois règles d'équité sont tenues par construction et sans toucher à la lumière, tandis que D
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

⚠️ **Le point d'équité, qui était le vrai risque du lot.** Un rayon visible dans l'air pourrait
révéler où vise l'adversaire là où le sol ne le montre pas. Il ne le peut pas : une couche vaut la
lightmap sous elle. Le rayon d'un adversaire n'apparaît donc que là où sa lumière est **déjà** dans ma
lightmap — là où je vois déjà le sol éclairé. Hors du cône et derrière un mur, la couche vaut zéro.
La garantie vient du fichier, pas de la vigilance, et `tools/test_iso_gadgets.gd` vérifie désormais
qu'une réécriture ne la casse pas en silence — notamment qu'on ne remplace pas le masque par une forme
à soi, ce qui casserait l'équité **sans casser l'image**, donc sans que personne le voie.

**La mesure attend deux choses**, dans cet ordre, sur ordre de la session cloud : la fusion de la garde
de Beauté dans `iso12-lumiere3d` — sans elle le chemin par défaut paie un aller-retour `pow` du
mannequin même éteint, et la référence ne serait plus le jeu d'avant —, puis **une seule fenêtre** pour
les deux lots : référence, E seul, A seul, E et A ensemble, au pompe sous une fusée, en miroir. Règle
posée d'avance : une variante tient si le rapport de ses médianes au défaut atteint 0,970 et si la
médiane de ses 1 % bas dépasse 60.
