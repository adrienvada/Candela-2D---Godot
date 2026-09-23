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

⚠️ L'évaluation de la session cloud dit cette marge « pas encore mesurée » : **elle l'est**, depuis
00:34. À corriger à sa prochaine mise à jour.

## L'ordre que je propose, et pourquoi

Le faisceau (E) avant la fusée (D). Non par facilité, mais parce que E s'ajoute dans un fichier dont
les trois règles d'équité sont tenues par construction et sans toucher à la lumière, tandis que D
modifie une couleur **qui entre dans la lightmap** — donc dans le relief, les capteurs et l'image des
deux joueurs. Faire E d'abord, c'est livrer une planche et un coût mesuré avant d'ouvrir le sujet qui
peut déplacer autre chose que lui-même.

Drapeaux éteints dans les deux cas, et chaque lot livre sa planche : la capture 1:1 à côté de
l'illustration nommée, **avant et après**, avec le paragraphe « ce qui manque encore ».
