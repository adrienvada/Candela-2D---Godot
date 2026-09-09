# Le trailer de 60 secondes — découpage

*Item **DA7.2**. Inscrit le 2026-09-09.*

⚠️ **Ce document est un découpage, pas un montage.** Il nomme, plan par plan,
l'état de jeu à filmer — avec les identifiants du catalogue de
`tools/photographe.gd`, qui les épingle par une suite depuis `5c4040f`. **Il
manque une capture vidéo** : le photographe rend des images fixes. Tant qu'il
n'y a pas de quoi enregistrer une séquence, ce découpage se lit, il ne
s'exécute pas.

## La grille : le montage est calé sur la musique existante

Le stem de menu est à **170 BPM**. Il n'y a donc rien à choisir : la grille est
déjà là.

| grandeur | durée |
|---|---|
| un temps | 60 / 170 = **0,353 s** |
| une mesure (4 temps) | **1,412 s** |
| une phrase (8 mesures) | **11,29 s** |
| 60 secondes | **42,5 mesures** |

> *Rectification.* Un message de cette session a d'abord écrit « une coupe
> toutes les 4 mesures = 1,41 s ». **1,41 s est une mesure, pas quatre** —
> quatre mesures font 5,65 s. Le chiffre était juste, l'unité fausse, et
> l'erreur aurait donné un montage quatre fois trop lent. Corrigé ici.

Cinq phrases de 8 mesures = 56,5 s, plus une queue de 3,5 s. La **densité de
coupe** monte phrase après phrase — une coupe toutes les 4 mesures au début,
toutes les mesures à l'avant-dernière. Ce n'est pas un effet de style : c'est
la courbe d'une manche.

## Le découpage

### Phrase 1 — LE NOIR (0:00 → 0:11,3 · coupe toutes les 4 mesures)

| plan | durée | contenu |
|---|---|---|
| noir | 4 mes. | Écran noir complet. Un pas, puis un second. Rien à voir — **et c'est la première promesse tenue.** |
| `jeu/05-torche` | 4 mes. | La torche s'allume. Le cône s'ouvre sur du béton vide. |

### Phrase 2 — LA RÈGLE (0:11,3 → 0:22,6 · coupe toutes les 2 mesures)

| plan | contenu |
|---|---|
| `jeu/03-duel` | Le cône trouve une silhouette au fond. |
| `jeu/06-retrodiffusion` | Deux cônes se recouvrent : il est là, on ne le voit pas encore. |
| `jeu/07-flash-de-tir` | Le tir imprime le décor une fraction de seconde. |
| `jeu/02-ecran-scinde` | Deux faisceaux opposés, chacun ignorant l'autre. |

### Phrase 3 — LES ARMES (0:22,6 → 0:33,9 · coupe toutes les 2 mesures)

`jeu/11-armes-pistolet` → `12-armes-fusil` → `13-armes-pompe` →
`14-armes-arbalete`, dans cet ordre. **L'ordre est celui de la portée
croissante**, pas celui du menu : le spectateur voit le cône s'allonger et se
resserrer de plan en plan, et comprend le compromis sans qu'on le lui dise.
Un cartouche par plan, au pochoir : *0,85 · 0,96 · 0,53 · 1,87 écran*.

### Phrase 4 — L'ESCALADE (0:33,9 → 0:45,2 · coupe à chaque mesure)

Huit plans d'une mesure : `jeu/01-decompte`, `jeu/10-fusee`,
`jeu/09-eblouissement`, `jeu/08-sang`, `cartes/03-plans-map-002-l-usine`,
`jeu/15-entrainement`, `jeu/04-hud`, `fins/01-killcam`.

⚠️ **`09-eblouissement` et `04-hud` se filment à l'ÉCRAN, pas dans la vue** :
le voile et le HUD vivent dans un `CanvasLayer` et n'existent pas dans la
texture d'une sous-vue. La règle vaut pour tout plan d'interface, et elle est
déjà appliquée dans le catalogue de DA6.

### Phrase 5 — LA MORT (0:45,2 → 0:56,5)

| plan | durée | contenu |
|---|---|---|
| `fins/02-gel-fatal` | 3 mes. | **Le seul arrêt du film.** Le gel, daté et signé. La musique tient, l'image non. |
| `fins/03-affiche` | 5 mes. | L'écran de victoire composé en affiche. |

### Queue (0:56,5 → 1:00 · 2,5 mesures)

Retour au noir. Le wordmark émerge en braise, la devise dessous —
**VOIR SANS ÊTRE VU. TUER SANS ÊTRE TUÉ.** — puis, sur une seule ligne, la
plateforme et l'adresse.

## Les trois règles qui tiennent le montage

1. **Aucun plan ne montre deux choses.** Le jeu se lit à une information par
   image ; un trailer qui empile trahit sa propre thèse.
2. **La première seconde est noire.** C'est contre-intuitif pour un trailer, et
   c'est exactement pourquoi ça marche : le spectateur cherche, ne trouve rien,
   et découvre la mécanique du jeu avant d'en voir une image.
3. **Rien qui n'existe dans le moteur.** Pas de plan composé, pas de cadrage
   impossible, pas de ralenti absent du jeu. La contrainte est la même que pour
   l'intro en planches (DA6.6) — et c'est la même raison : promettre un plan que
   le jeu ne rend pas, c'est le défaut « généré par défaut » transposé au
   montage.

## Ce qui manque pour tourner

- **Une capture vidéo.** Le photographe rend des images fixes ; il faudrait
  soit un enregistrement d'écran piloté, soit une extension de l'outil. C'est le
  seul vrai blocage.
- **Le stem de menu isolé**, en fichier, pour caler le montage.
- **Un cartouche au pochoir** pour les chiffres de la phrase 3 : la fonte du
  jeu existe, l'habillage reste à faire.
