# Le sol marqué, deuxième passage — les points allumés dans le noir

Session cloud, branche `claude/cloud-sol-marque-2`, partie d'`origin/claude/cloud-sol-marque` (9e398d5), le 28/09/2026.
Lancée par la session coordinatrice « CLOUD ISO UNRAILED ».

## Plan (écrit à 07:25, avant tout code)

1. **Reproduire** le défaut de l'évaluation 11 (`docs/iso/cloud/ecart-11/RAPPORT.md` § 4 : torches éteintes, Croisée,
   taches jaunes de 2 à 5 px sur le liseré du sommet d'un mur haut, avec `--sol-marque-essai` seul en cause).
2. **La cause, par une prise dédiée, écrite AVANT la correction** : quelle marque, à quelle distance de l'arête, quelle
   peinture au point où le liseré lit la lumière (`mur_iso.gdshader`, `lire_lumiere_moyenne(… d_bord + pied …)`,
   `pied = 8` posé par `presentation_3d.gd`, quatre lectures à ±0,625 et ±1,875 px le long de l'arête).
   Premier constat, lu dans le code : la garde de l'essai tient les marques à **12 px** des cases de mur, et le liseré lit
   à **8 px** de l'arête, dans une peinture à 1 texel par pixel de monde, filtrée linéairement. Sur le papier, 4 px de
   marge : il faut donc trouver ce que le papier ne voit pas (une emprise plus large que promise, une arête qui n'est pas
   celle d'une case de mur, un autre calque de peinture).
3. **Corriger dans l'essai seulement** (tenir les marques loin des points de lecture, filtrage compté), avec une garde
   headless sur les six cartes. Le shader des murs n'est pas touché : si la division par la peinture est la vraie cause,
   c'est écrit ici pour Gadgets.
4. **Les pochoirs** (`--pochoirs-essai`) : même calcul, même prise ; signalés s'ils peuvent faire la même tache.
5. **La preuve** : six cartes, 45° B, vue unique et écran scindé, torches éteintes, prises A/B/A' ; torches allumées,
   rien de plus clair que la surface qui porte ; drapeau éteint, rien ne change au bit ; suite complète verte.

## État

- [ ] reproduction
- [ ] cause établie
- [ ] correction et garde
- [ ] pochoirs
- [ ] preuves six cartes
- [ ] suite complète
