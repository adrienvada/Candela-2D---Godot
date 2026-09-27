# Le point de braise de la fusée, rouge après le plein feu (session cloud « fusée-point », branche `claude/cloud-fusee-point`)

*27/09/2026, heure de Paris. Planche : [`planche.html`](planche.html) (autonome, images en chemins relatifs).*

## Pour Adrien, en cinq lignes

1. **Le point de la fusée fait maintenant ce que tu as choisi** : presque blanc pendant tout le plein feu (2 s, ou 4 s avec le rouge long), puis **rouge** jusqu'au bout — il sortait jaune pâle.
2. Le blanc ne déborde plus : avant, il durait une demi-seconde de trop, et il **revenait** pendant l'agonie de la fusée, à chaque sursaut.
3. Dans le noir, le point brille exactement comme avant (même taille, même éclat, pour les deux joueurs) ; seul change ce qu'il fait sur le sol éclairé : il reste rouge au lieu de jaunir.
4. **Un choix à regarder** : tout à la fin (le résidu, après 15 s), le point est un petit point rouge SOMBRE sur un sol à peine orangé, là où c'était une petite tache orange un peu plus claire que le sol. Image : `comparaison_points_3_5_13_16.jpg` (les deux derniers carrés).
5. La lumière de la fusée n'a pas changé, ni le noir ailleurs ; la correction tient en une fonction, vérifiée par un test qui échoue sur l'ancien code.

## État

- **Correction** : commit `78fb380` (pour Gadgets, message écrit pour lui). `iso_volumes.gd`, `_suivre_coeur_fusee` et une fonction pure `couleur_coeur_fusee`.
- **Garde** : `tools/test_iso_gadgets.gd`, « Le point de braise, acte par acte » (dans une suite déjà au lot de `run_suites.sh`).
- **Suite complète** : `GODOT=/usr/local/bin/godot ./tools/run_suites.sh` sur `78fb380` → **« tout passe, sans erreur de script (621 s) »**.
- **Planche** avant/après, défaut et rouge long, 11 âges de 0,5 à 16 s : ce dossier.
- **Poussé** jusqu'à `2898277`. Le rapport, la planche et ce qui suit sont **committés, pas poussés** : Adrien a demandé en cours de session d'attendre le feu vert de la session gestionnaire pour pousser.

## Les deux écarts, établis

Mesures sur l'image (llvmpipe, ~1/255 près du Mac), point isolé par différence avec la même prise SANS le point (voir « Mesurer »).

### D1 — le point jaune pâle après le plein feu : deux causes empilées
| défaut, à 3,5 s (braise) | couleur |
|---|---|
| sol sous le point, sans le point | (165, 108, 62) — 27°, orange |
| **ce que le halo ajoute, seul** (avec − sans) | **(170, 154, 53) — 52°, jaune-orangé** |
| le point à l'image | (230, 219, 123) — 54°, sat. 0,47 |

1. **Le halo seul est déjà jaune-orangé** : il prenait la couleur de la LUMIÈRE, qui à la braise est l'ambre (`Charte.AMBRE`, par la température), sous un éclat de 1,5.
2. **L'additif sur un sol orange** : le rouge plafonne (230, la courbe de sortie), le vert et le bleu montent encore — le mécanisme qu'ISO10 1c avait déjà corrigé pour la lueur au sol (`halo_iso_melange.gdshader`).

### D3 — le blanc qui déborde, et qui revient
- Défaut : encore blanc (230, 230, 229) au **premier pas de la braise (2,017 s) et à 2,5 s** ; avec le rouge long, à **4,017 s**. Le blanc suivait l'énergie relative (`smoothstep(0.6, 0.95, relative)`), qui glisse 1,5 s dans la braise.
- **D3 bis, nouveau** : à **13 s (agonie, sur un sursaut)**, le point redevenait presque blanc (230, 230, 216) — l'énergie remonte à 2,5 / 3 = 0,83 à chaque sursaut. La garde l'a vu sur le vieux code (12,567 s, 12,926 s, 13,268 s…), la planche le confirme.

## La correction, et son pourquoi

- **Le blanc suit l'ACTE** (`FuseeModele.acte_a(age_combustion)` = PLEIN_FEU), plus l'énergie : blanc exactement pendant le plein feu, jamais après, aux deux variantes, sursauts compris.
- **Après, le rouge de détresse** (`COULEUR_COEUR_ROUGE` = `Fusee.COULEUR_DETRESSE`, (0,96 ; 0,293 ; 0,334)) : le rouge de la lumière au départ, celui que Q34 = C appelle « puis rouge ». Il est **recopié** et non nommé : nommer `Fusee` dans `iso_volumes.gd` l'empêche de compiler sous `--script` (`fusee.gd` nomme `NetworkManager`) — premier essai, `test_iso_gadgets` en erreur de compilation. La garde tient l'égalité des deux constantes.
- **Le halo du point passe en MÉLANGE** (le shader existant de la lueur au sol ; aucun shader modifié), dosé pour que **sur le noir l'image soit celle d'avant, au pixel près** : couverture `max(éclat, 1)`, couleur `rouge × min(éclat, 1)`. La forme du disque restant dans [0, 1], `rouge × min(é, 1) × clamp(forme × max(é, 1))` = `rouge × clamp(forme × é)`, ce que l'additif posait sur un fond noir. La garde le vérifie à quatre formes, à chaque âge.
- **Pourquoi le mélange et pas seulement le rouge** : un rouge additif sur un sol orange sature pareil (à la braise, (165,108,62) + (221,70,79) → (230,178,141), 22°, sat. 0,39 : ni rouge ni saturé). Il fallait que le point **couvre** le sol.
- **Ce qui ne bouge pas** : la Light2D (orange à la braise ; la garde le vérifie), la comète en vol, la lueur au sol et tous les autres halos, les masques de lumière de `player.gd`. `Protocol.VERSION` reste **18** (vérifié par `test_iso_gadgets`, « Protocol.VERSION reste 18 », et `git diff` de `protocol.gd` vide) : le point est un dessin de la vue iso, il ne touche à aucune donnée échangée.
- **La variante 1** (`--fusee-coeur`, « toujours de la couleur de la lumière ») garde sa couleur ; elle passe aussi en mélange (même nœud, même shader), sans effet sur le noir. Décidé ainsi pour ne pas garder deux nœuds de halo pour un drapeau d'essai.
- **Équité** : la couleur ne dépend que de l'âge et de l'énergie de la fusée, rien du joueur qui regarde ; le halo est le même pour les deux vues. Non photographié du côté de J2 (voir « Pas prouvé »).

## Ce que montre la planche

Vue de J1, lacet 45°, zoom ×1,5, 1920×1080, Cloître (la scène de la loupe), fusée posée dans le noir hors de la torche de J1. Âges pilotés en temps de jeu, un demi-pas au-delà des bornes (« 2,0 » = 2,0167 s, le premier pas de la braise).

| âge (lu) | défaut avant | défaut **après** | rouge long avant | rouge long **après** |
|---|---|---|---|---|
| 0,5 (plein feu) | (230,230,229) blanc | (230,214,213) presque blanc | blanc | presque blanc |
| 1,5 (plein feu) | blanc | presque blanc | blanc | presque blanc |
| 2,017 | **blanc** (braise !) | **(221,71,79) 357° 0,68 rouge** | blanc (plein feu) | presque blanc (plein feu) |
| 2,5 | **(230,227,222) blanc** | rouge 356° 0,68 | blanc (plein feu) | presque blanc |
| 3,017 | (230,190,130) 36° | rouge 356° 0,68 | blanc (plein feu) | presque blanc |
| 3,5 | **(230,219,123) jaune** | rouge 356° 0,68 | blanc (plein feu) | presque blanc |
| 4,017 | jaune | rouge | **blanc** (braise !) | **rouge 356° 0,68** |
| 5,017 | jaune | rouge | (230,190,130) 36° | rouge |
| 8,017 | jaune | rouge | jaune | rouge |
| 13,017 (agonie, sursaut) | **(230,230,216) presque blanc** | rouge 357° 0,68 | **presque blanc** | rouge |
| 16,017 (résidu) | (82,55,26) 31° orange | (39,10,12) 356° 0,74 rouge sombre | orange | rouge sombre |

Q34 = C, critère de la tâche (teinte 350° à 15°, saturation ≥ 0,6 après le plein feu) : **tenu à tous les âges après, dans les deux variantes** ; jamais tenu avant.

Le « presque blanc » passe de (230,230,229) à (230,214,213) : en mélange, il montre enfin la couleur voulue par Q34 (`COULEUR_COEUR_BLANC` = (1 ; 0,93 ; 0,93), celle de l'illustration) au lieu du blanc saturé de l'additif.

**Lisibilité sur le sol éclairé.** À la braise, rouge (221,71,79) sur orange (165,108,62) : lisible par la teinte, et plus clair que le sol (R 221 contre 165). Au sursaut d'agonie, rouge sur un sol jaune (190,168,87) : très lisible. **Au résidu, le contraste s'inverse** : (39,10,12) sur (46,27,13) — un point rouge plus sombre que son sol, là où l'ancien était une tache orange plus claire (82,55,26). Conséquence directe de la règle « même éclat » : sur le noir, l'éclat du résidu est 0,2, et couvrir le sol avec 0,2 × rouge l'assombrit. Le relever changerait l'éclat sur le noir ; laisser passer le sol le ramènerait vers l'orange (0,2 × rouge + 0,8 × sol = (47,25,13), ~20°). **À trancher par Adrien** si le résidu doit rester une tache plus claire que son sol.

## Le noir absolu, inchangé

Protocole de la session « Fusée » : torches éteintes, fumée coupée / rétablie / recoupée (A, B, A').
- **Fuites de fumée hors de la lumière** (noir dans A et A', allumé dans B) : **les mêmes avant et après**, à 20 pixels près sur 5 500 à 60 000 selon l'âge (tableau complet dans `mesures.json`, clé `noir_fuites`). C'est le défaut D2 connu (masque de la fumée éteint par défaut), que la correction ne touche pas.
- **Prise B avant contre après, pixel à pixel** (même âge, même variante, horloge fixe) : à chaque âge, tous les pixels qui changent sont **dans le disque du point (≤ 16 px)** ou **à plus de 500 px** de lui ; **aucun entre 16 et 500 px**. Les pixels lointains (3 à 269) sont le bruit d'un passage à l'autre : deux passages du MÊME code (défaut et rouge long à 0,5 s, état identique) diffèrent de 58 à 148 pixels, au même endroit (511-713 px du point).
- **Aucun pixel noir devenu allumé à 40 px du point** ou moins, à aucun âge.

## Décisions et leur pourquoi
- **La garde dans `test_iso_gadgets`** plutôt que dans `test_fusee.gd` : `test_fusee` ne charge que le modèle pur (`fusee.gd` ne compile pas sous `--script`) ; la garde a besoin d'une vraie fusée et du vrai halo, que `test_iso_gadgets` monte déjà. Pas de nouveau fichier à ajouter au lot.
- **Mutation** : l'ancien corps de fonction remis en place, la garde rougit sur 10 contrôles (blanc à 2,0 s, jaune/orange à la braise, blanc aux sursauts, additif). Remis ensuite.
- **L'outil de planche modifié** (`tools/loupe_fusee_ages.gd`, commit `539e333`) : âges à un demi-pas au-delà des bornes (le piège 3 de la session « Fusée »), âges 13 et 16 s ajoutés (agonie, résidu), et une **prise « sans le point »** au même instant. Pourquoi : l'ancienne mesure prenait « le pixel le plus lumineux près du point », qui sur un sol orange peut être le sol ; un point rouge sombre (résidu) y serait invisible. Les séries avant ET après sont prises avec cet outil.
- **La série « avant »** tourne dans un worktree détaché sur `539e333` (outil nouveau, jeu d'avant), la série « après » sur `78fb380`.
- **Les anciennes gardes de source** de `_le_coeur_de_la_fusee` qui décrivaient l'ancien comportement (lerp vers le blanc sur l'énergie, 5 arguments) sont réécrites : elles gardaient le défaut.

## Pièges découverts, à reporter dans la feuille de route
1. **Premier lancement du photographe dans un conteneur neuf : l'intro recouvre le jeu.** Mon premier passage « avant » a photographié l'intro (« UNE TOUCHE POUR PASSER ») puis le menu principal, à tous les âges, sans une erreur : `intro_vue` n'était pas encore dans `user://settings.cfg`. `run_photos.sh` sort en 0. Les géométries du journal (point au centre de l'écran, 960×540) le trahissaient. Un plan de photo devrait marquer l'intro vue, ou le dire. Signalé, non corrigé (hors tâche) : `tools/photographe.gd`.
2. **Nommer `Fusee` dans un script chargé par une suite `--script` le casse** (`fusee.gd` nomme un autoload) : erreur de compilation qui entraîne tout script qui en dépend. Recopier la constante et garder l'égalité par `load()` au test.
3. **Un point mesuré comme « le pixel le plus lumineux » ment dès qu'il n'est plus le plus lumineux** : isoler un dessin par la différence avec la même prise sans lui.
4. **Une couleur pilotée par l'énergie relative déborde de l'acte qu'elle veut marquer** : raccord de 1,5 s, et sursauts d'agonie qui la ramènent. Marquer un acte, c'est lire l'acte.

## Hors tâche, signalé
- `tools/loupe_fusee_ages.gd.uid` : généré par l'import, committé (comme les autres `.uid`).
- Le « pas prouvé » du rapport « Fusée » sur le plafond à 230/255 reste : ici aussi, rien ne dépasse 230.

## Refaire
```bash
git checkout claude/cloud-fusee-point
godot --headless --path . --import
# Conteneur neuf : lancer le jeu une fois (ou un plan) pour que l'intro soit marquée vue, sinon elle recouvre les photos.
# La garde
godot --headless --path . --script res://tools/test_iso_gadgets.gd
# La suite
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
# La planche : avant = 539e333 (dans un worktree), après = 78fb380 ou la tête ; deux variantes chacun
for v in defaut long; do
  extra=""; [ $v = long ] && extra="--fusee-rouge-long"
  xvfb-run -a -s "-screen 0 1920x1080x24" env GODOT=/usr/local/bin/godot GODOT_ARGS="--fixed-fps 60" \
    ./tools/run_photos.sh --plan=loupe-fusee-ages --taille=1920x1080 --zoom=1.5 --lacet=45 \
    --sortie=user://point-apres-$v $extra > /tmp/apres-$v.log 2>&1
done
U="$HOME/.local/share/godot/app_userdata/Candela 2D"
pip install pillow numpy
python3 docs/iso/cloud/fusee-point/mesurer.py \
  --passage "defaut-avant=/tmp/avant-defaut.log,$U/point-avant-defaut" --passage "defaut-apres=/tmp/apres-defaut.log,$U/point-apres-defaut" \
  --passage "long-avant=/tmp/avant-long.log,$U/point-avant-long" --passage "long-apres=/tmp/apres-long.log,$U/point-apres-long" \
  --sortie docs/iso/cloud/fusee-point
```

## Mesurer
`mesurer.py` : le point = les pixels qui diffèrent d'au moins 8/255 entre la prise avec et sans le point, dans 16 px autour de sa projection ; sa couleur = la moyenne, sur la prise avec, des 9 qui diffèrent le plus ; la « contribution » = la même moyenne sur (avec − sans). Teinte et saturation HSV. Fichiers : `<passage>/aX_Y-loupe.jpg` (640×360 à l'échelle 1), `<passage>/aX_Y-point.jpg` (48×48 ×6) ; `mesures.json`.

## Ce que je n'ai PAS pu prouver
- **Rien sur la cadence** (rendu logiciel ; interdit ici). Le mélange au lieu de l'additif ne change ni le nombre de nœuds ni de passes ; non mesuré.
- **Les couleurs à ~1/255 près du Mac** seulement.
- **La vue de J2 (lacet B)** n'est pas photographiée : l'équité tient par construction (la couleur ne lit que la fusée), pas par image.
- **L'ordre de dessin avec la fumée** : le point en mélange est trié avec les couches transparentes ; sur la planche il reste visible sous la fumée pleine (3,5 à 8 s), mais je n'ai pas cherché d'angle où une couche le recouvrirait.
- **La lisibilité à distance « en jeu »** : l'éclat sur le noir est identique au pixel près par construction et par la garde ; la lisibilité perçue, surtout au résidu (contraste inversé, voir plus haut), reste à juger à l'œil sur le Mac.
