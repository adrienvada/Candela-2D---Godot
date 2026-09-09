# Presskit — Candela

*Item **DA7.3**. Inscrit le 2026-09-09. Ce document est la **source** du
presskit : les textes définitifs, la sélection d'images et ce qui manque
encore. Il ne remplace pas la page publiée.*

⚠️ **Six champs ne peuvent pas être remplis par une session** et sont marqués
`À TRANCHER` : ils engagent Adrien (nom d'éditeur, contact public, prix, date,
plateformes annoncées, licence des images). Ne pas les deviner : un presskit
dont un champ est inventé fait perdre la confiance sur tous les autres.

## Fiche express

| Champ | Valeur |
|---|---|
| Titre | **Candela** |
| Développeur | Adrien Vada Djerbetian — développement solo |
| Éditeur | `À TRANCHER` (auto-édition ?) |
| Plateformes | macOS, Windows *(des préréglages d'export existent aussi pour le Web — `À TRANCHER` : l'annonce-t-on ?)* |
| Date de sortie | `À TRANCHER` — le jeu est en 0.3.1, en développement |
| Prix | `À TRANCHER` |
| Joueurs | 2 — en ligne, ou à deux sur la même machine |
| Langues | Français |
| Moteur | Godot 4.7 |
| Site | https://claude.ai/code/artifact/de476ec0-33c9-4874-9201-a8c93283737c *(provisoire — DA7.4)* |
| Contact presse | `À TRANCHER` — une adresse dédiée, pas l'adresse personnelle |

## Les descriptions

**Une phrase (accroche, ≤ 20 mots)**

> Un duel à deux dans le noir absolu, où le faisceau qui vous montre l'adversaire
> lui montre où vous êtes.

**Court (≈ 50 mots — capsule de boutique, annuaires)**

> Candela est un duel en vue de dessus dans l'obscurité totale. Vous avez une
> lampe torche et une arme ; votre adversaire aussi. Il n'y a ni carte, ni
> marqueur, ni contour d'ennemi : la seule information est la lumière, et toute
> lumière que vous produisez vous désigne. Voir sans être vu, tuer sans être tué.

**Long (≈ 150 mots — dossier de presse, page de boutique)**

> Candela est un duel à deux joueurs en vue de dessus, joué dans le noir absolu.
> Chacun tient une lampe torche et une arme. Il n'y a pas de mini-carte, pas de
> marqueur d'ennemi, pas de silhouette détourée dans l'ombre : tout ce que vous
> savez de l'autre, vous l'avez appris de la lumière — la vôtre, la sienne, ou
> celle que son tir a laissée une fraction de seconde sur les murs.
>
> C'est ce qui fait la tension du jeu. Éclairer, c'est voir ; éclairer, c'est
> être vu. Chaque seconde de torche allumée est un renseignement pris et un
> renseignement donné, et les bons joueurs passent une grande partie du match
> dans le noir complet.
>
> Quatre armes, qui ne diffèrent pas seulement par les dégâts mais par la
> quantité de vous-même qu'elles montrent au reste de la carte. Des manches
> courtes, un éditeur de cartes, une killcam qui rejoue **votre** version de la
> scène — celle que votre lumière à vous a éclairée.

## Points saillants

- **La lumière est la seule information.** Aucune assistance à la lecture : pas
  de mini-carte, pas de marqueur, pas de détourage. Un mur arrête la lumière
  comme il arrête une balle.
- **Trois signaux, et rien d'autre** : votre torche, le flash de tir, et la
  rétrodiffusion — ce que la lumière de l'autre laisse sur les murs autour de
  vous.
- **Quatre armes qui se paient en visibilité.** Portées de faisceau, en largeurs
  d'écran : pompe 0,53 · pistolet 0,85 · fusil 0,96 · **arbalète 1,87**.
  L'arbalète est la seule à éclairer au-delà de ce que son porteur peut voir.
- **En ligne sans configuration.** Un code de salon à six caractères, la
  traversée de NAT gérée : l'adversaire n'ouvre aucun port.
- **Écran scindé sur une machine**, deux vues, chacun ne voyant que ses propres
  lumières.
- **Éditeur de cartes**, avec un code de partage en texte qui tient dans un
  message.
- **Killcam personnelle** : chacun rejoue son propre enregistrement. Les deux
  versions d'une même mort n'ont pas à concorder — et c'est le sujet du jeu.
- **Dix rangs classés**, d'*Aveugle* à *Candela*, nommés en intensités de
  lumière croissantes.

## La sélection d'images

Toutes disponibles en 3840×2160, plus découpes carrée et 9:16, produites par
`tools/photographe.gd` (session DA6). Les noms ci-dessous sont ceux du catalogue
de l'outil : ils se recommandent tels quels.

### Les cinq à envoyer si on n'en envoie que cinq

| Plan | Ce qu'il montre | Pourquoi celui-là |
|---|---|---|
| `jeu/03-duel` | Un cône de lumière dans le noir, une silhouette dedans. | **L'image du jeu.** 90 % de cadre noir : elle dit la promesse avant la première phrase de texte. Déjà en fond du site. |
| `jeu/06-retrodiffusion` | Deux cônes qui se recouvrent en partie. | La seule image qui montre le mécanisme central — savoir que l'autre est là sans le voir. |
| `jeu/07-flash-de-tir` | Le décor illuminé une fraction de seconde par un tir. | « Tirer, c'est parler », en une image. |
| `fins/02-gel-fatal` | Le moment de la mort, gelé, daté et signé. | Le moment qu'un joueur partage de lui-même (DA6.2). |
| `fins/03-affiche` | L'écran de victoire composé en affiche. | L'objet que la presse recadre le plus volontiers (DA6.1). |

### Le lot complet, par famille

- **`jeu/` (15 plans)** — `01-decompte`, `02-ecran-scinde`, `03-duel`, `04-hud`,
  `05-torche`, `06-retrodiffusion`, `07-flash-de-tir`, `08-sang`,
  `09-eblouissement`, `10-fusee`, `11-armes-pistolet` à `14-armes-arbalete`,
  `15-entrainement`.
- **`fins/` (8 plans)** — `01-killcam`, `02-gel-fatal`, `03-affiche`,
  `04-bilan`, `05-verdict-victoire`, `06-verdict-defaite`,
  `07-verdict-egalite`, `08-soiree`.
- **`cartes/` (7 plans)** — les plans des cartes livrées et d'une carte joueur.

⚠️ **Deux réserves signalées par DA6, à ne pas perdre :**

1. **Les plans de carte ne sont pas des captures** mais des schémas peints par
   `MapThumbnail`, et ils restent à ~1024 px quelle que soit la taille demandée.
   Pour un presskit c'est probablement ce qu'on veut ; les présenter comme des
   captures serait faux.
2. **Les découpes carrée et 9:16 sont centrées.** Sur les plans où le sujet est
   excentré, il faut demander une ancre par plan plutôt que rogner après coup.

Et une règle qui ne se devine pas : **tout plan montrant le voile
d'éblouissement, le HUD, la killcam ou le tampon du kill doit être pris à
l'écran, jamais dans la texture de la sous-vue** — ces éléments vivent dans un
`CanvasLayer` et sont absents de la vue. Le catalogue applique déjà la règle ;
elle est ici pour qui composerait une image à la main.

## Ce qui manque encore

| Manque | Qui peut le faire |
|---|---|
| Le trailer de 60 s | DA7.2 — découpage écrivable, montage à faire |
| La capsule de boutique | DA7.1 — gabarits connus, image à générer |
| Un logo en fichier séparé (PNG transparent + SVG) | dérivable de DA1.6 |
| Les six champs `À TRANCHER` ci-dessus | Adrien |
| Une adresse de contact presse | Adrien |
| La licence d'usage des images par la presse | Adrien |
