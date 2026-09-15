# Galerie iso — donner des yeux à la session cloud (brief de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 15/09/2026 11:00, sur demande d'Adrien de 10:55)

Adrien, réveillé, demande que la session cloud confronte le jeu réel aux planches du DA (tes livraisons) et qu'elle ait « un moyen de prendre des images en jeu ». La session cloud n'a ni Mac ni Godot : elle lit des artefacts. Tu vas donc publier une **galerie**, un artefact HTML, que la session cloud lit avec son outil. Tu fais tout depuis TON worktree, sans jamais entrer dans le worktree d'ISO5 / Iso 1 (`prompt-iso2-3e1d2e`, tenu par « Iso 1 Opus » pour ISO6) : les objets git sont partagés entre worktrees, `git show <commit>:<chemin> > <fichier>` te donne n'importe quel fichier d'`iso2-vues` sans y mettre les pieds.

## Ce que la galerie contient

1. **Tes planches** : toutes les `docs/iso/planches_gemini/**/planche_*_synthese.jpg` (toutes vagues), plus les images unitaires qui servent de référence au jeu : E1 « la promesse du jeu en iso » (les trois variantes, la variante 2 retenue en premier), le gabarit trois vues des classes, les textures plates, les gadgets, l'habillage (hub, portraits, HUD, killcam, fins, icônes dont l'icône de torche 49ee29e), fumées et comète, intro.
2. **Les planches du jeu** sur `iso2-vues` à **a5ac4b8** : `git ls-tree --name-only a5ac4b8 docs/iso/` puis, pour chaque `planche_*.jpg|png`, `git show a5ac4b8:docs/iso/<nom> > <dossier>/<nom>`.
3. **Les captures en jeu** s'il y en a : le dossier le plus récent du photographe (`~/Library/Application Support/Godot/app_userdata/Candela 2D/photos/`, manifeste + JPEG), tel quel.

## Comment publier

Outil `Artifact`, un fichier HTML « Galerie iso » : page sombre, une section par groupe (DA / jeu / captures), chaque image avec sa légende (nom de fichier, commit ou vague, ce qu'elle montre), et **les paires DA ↔ jeu côte à côte** quand elles se répondent : E1 ↔ planche_iso7 ; classes ↔ planche_corps_v5 ; habillage ↔ planche_habillage ; gadgets et fumées ↔ planche_iso_gadgets et planche_lumieres_hauteur ; killcam ↔ planche_iso5.

- Si ton outil `Artifact` accepte le paramètre `files` : mets les JPEG à côté de la page (chemins relatifs, par exemple `img/E1_promesse_02.jpg`), page légère, images à leur taille d'origine (≤ 15 Mo chacune).
- Sinon : embarque-les en data URI dans la page, JPEG qualité 80, largeur maximale 1600 px (PIL ou ImageMagick), et coupe en plusieurs pages si une page dépasse 14 Mo (« Galerie iso 1/2 », « 2/2 »).
- Envoie l'URL (ou les URL) à « Fable 5.1 - CLOUD ISO UNRAILED » par SendMessage, avec la liste des images publiées. Pour compléter plus tard : republie la MÊME URL (même chemin de fichier dans ta session, ou paramètre `url`), jamais un second artefact.

## Ensuite : tu es le service d'images de la vague

Chaque session de chantier (Beauté, Gadgets, Iso 1) qui produit des captures t'envoie leurs chemins absolus par SendMessage ; tu les ajoutes à la galerie (section datée, légende, paire DA ↔ jeu si elle existe) et tu préviens la session cloud avec l'URL. Tu ne lances pas Godot, tu ne touches à aucune branche ni aucun worktree d'une autre session, tu ne pousses rien. Heure de Paris par `date`. Accuse réception à « Fable 5.1 - CLOUD ISO UNRAILED » dès lecture de ce fichier, puis envoie l'URL dès la première publication, sans attendre que tout soit parfait : la session cloud a besoin de voir vite, la galerie s'enrichit après.
