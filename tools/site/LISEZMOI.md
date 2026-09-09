# Le site d'une page — source (DA7.4)

`candela.tpl.html` est le gabarit, `assembler.py` y injecte les images en
`data:` URI et produit `candela.html`, un fichier autonome qu'on publie tel quel.

```bash
cd tools/site && python3 assembler.py
```

## Pourquoi un assembleur, et pas un site à fichiers séparés

La page est publiée comme artefact, où **seules les polices Google sont
chargeables depuis l'extérieur** : aucune image distante ne passe. Tout doit
donc voyager dans le fichier. L'assembleur existe pour que le gabarit reste
lisible malgré ça — on n'édite jamais les mégaoctets de base64 à la main.

## Les images attendues, et d'où elles viennent

L'assembleur les cherche **à côté de lui**. Elles ne sont pas versionnées : ce
sont des dérivés, et deux d'entre elles viennent de `user://`, hors dépôt.

| Fichier attendu | Source | Fabrication |
|---|---|---|
| `hero-duel.jpg` | `user://presskit/jeu/03-duel.png` (`tools/photographe.gd`) | `sips -s format jpeg -Z 2000` |
| `sig-05-torche.jpg`, `sig-06-retrodiffusion.jpg`, `sig-07-flash-de-tir.jpg` | `user://presskit/jeu/<plan>@carre.png` | `sips -s format jpeg -Z 900` |
| `ill_ecran_scinde.jpg`, `ill_competitif.jpg`, `ill_quitter.jpg` | **`assets/ui/`** | `sips -s format jpeg -Z 1400` |
| `icone_macos.png`, `icone_windows.png` | `assets/ui/` | telles quelles |

⚠️ **Les illustrations se prennent dans `assets/ui/`, jamais dans
`tools/captures/`.** Ce dernier porte les mêmes noms et il est versionné, mais
ce sont des rendus figés d'un outil retiré, antérieurs à la refonte Roman
Graphique Brutaliste. Voir « Pièges connus » dans la ROADMAP — l'erreur a été
faite, et elle produit une page parfaitement plausible.

Les deux icônes sont **facultatives** : si elles manquent, l'assembleur pose des
boutons au seul lettrage, et rien ne casse.

## Ce qui est écrit en dur, et qui vieillit

Les liens de téléchargement passent par `releases/latest/download/`, donc ils
suivent les sorties tout seuls. En revanche le **tampon de version** (`v0.3.1`)
et sa date sont dans le gabarit : à changer à chaque sortie. La date est là
exprès — un numéro daté vieillit honnêtement, un numéro nu finit par mentir.
