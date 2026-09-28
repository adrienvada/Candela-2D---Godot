# Intégration à blanc — iso11-menus + iso12-corps dans integration-iso14

> Session cloud, branche `claude/cloud-integration-blanc`, 2026-09-28, de 02:04 à ~03:20 (heures de Paris).
> **Terminée.** Base `a30a407` ; fusions `8f81a53` (iso11) et `244cb88` (iso12) ; commit du photographe `fde7346`
> (à NE PAS reprendre).

## Pour Adrien, en cinq lignes

1. Les deux chantiers en attente (les gadgets de la fusée et les personnages détaillés) se rassemblent sans casse avec l'état d'aujourd'hui.
2. Il y a eu quatre petits désaccords entre les fichiers, tous tranchés sans rien jeter ; le détail est écrit ci-dessous pour qu'Iso 1 refasse les mêmes gestes sur ton Mac.
3. Rien n'a été perdu : j'ai vérifié ligne à ligne que tout ce que chaque chantier ajoutait est encore là.
4. Le jeu par défaut ne change pas : vue à 45° avec le joueur 2 de l'autre côté, murs abîmés, caméra comme avant ; les personnages détaillés et la fusée « rouge long » restent éteints.
5. Tous les tests automatiques passent, et les images montrent le jeu à 45° avec le nouveau point rouge de la fusée quand elle retombe en braise.

## Pour Iso 1 — les gestes, dans l'ordre

```bash
git fetch origin integration-iso14 iso11-menus iso12-corps
git checkout integration-iso14            # a30a407
git merge-base HEAD origin/iso11-menus    # 28152c5 (pas besoin d'approfondir le clone)
git merge-base HEAD origin/iso12-corps    # 5d9ef55
git merge --no-ff origin/iso11-menus      # 3 conflits, voir § Fusion 1
git merge --no-ff origin/iso12-corps      # 1 conflit, voir § Fusion 2
```

Résultat de référence sur cette branche : fusion 1 = `8f81a53`, fusion 2 = `244cb88`.
Pour comparer ta fusion à la mienne : `git diff 244cb88 HEAD -- . ':!docs/iso/cloud'` doit être vide.

### Fusion 1 — `origin/iso11-menus` (0568441)

Trois fichiers en conflit. Fait clé : integration-iso14 porte déjà, **recopiés** (pas fusionnés), les premiers
commits d'iso11 (Q34 = C `ef61a79` → `170ad78`, Q35 `a179374` → `efca0fe`, bande des faces `3155395` → `ef758bd`,
preuve du masque `0dd3350` → `b126c38`). Git ne voit donc pas qu'ils sont communs, et les commits suivants d'iso11
(`88dbfb0` le point rouge, `a8fa892`, `298dfa6`, `0568441`) réécrivent des lignes que le côté integration-iso14
porte dans leur **version antérieure**. Dans ces cas, la version d'iso11 contient celle d'integration-iso14 et la
remplace : ce n'est pas « prendre un côté en bloc », c'est garder la suite du même texte (vérifié ligne à ligne, voir
§ Anti-perte).

| Fichier | Côté integration-iso14 | Côté iso11-menus | Résolution | Pourquoi |
|---|---|---|---|---|
| `iso_volumes.gd`, commentaire et signature de `_suivre_coeur_fusee` | commentaire « Q34 … de la couleur de la lumière … Au plein feu seulement, la variante 2 le pousse vers le presque-blanc » ; signature `(f, lumiere, energie, relative, vus)` | commentaire Q34 + D1/D3 (le point rouge en mélange, le blanc qui suit l'ACTE) ; signature `(f, lumiere, energie, vus)` | **iso11** | Le côté integration-iso14 ne différait de la base que par « ESSAI » → « Q34 », qu'iso11 porte aussi. La signature doit suivre l'appel, qu'iso11 a changé sans conflit (`_suivre_coeur_fusee(f, lumiere, energie, vus)`) et le corps, qui n'utilise plus `relative`. Garder l'ancienne signature casserait la compilation. |
| `tools/test_iso_gadgets.gd`, `_le_coeur_de_la_fusee` | la garde de l'appel avec `relative` et « de la couleur de la lumière » (texte de la base) | la garde de l'appel sans `relative`, « la taille et l'éclat de celui de la comète » | **iso11** | Le côté integration-iso14 est le texte de la base, identique ; sa garde du défaut (`coeur_fusee = 2`, `--sans-fusee-coeur`), juste au-dessus, est hors du conflit et reste. |
| `docs/ROADMAP.md`, tableau des décisions (l. ~2437) | cinq lignes : masque éteint (ordre 416), `main` poussé à 76fe78f, Q28 = A, Q30 = A, Q17 = B, Q16/Q24 | une ligne : masque éteint sur iso11 aussi (ordre 437) | **les deux**, integration-iso14 d'abord | Ajouts indépendants. |
| `docs/ROADMAP.md`, tête de « Pièges connus » | deux pièges du 2026-09-27 (drapeau sans `--` ; glissement en diagonale) | rien | **integration-iso14** | iso11 n'ajoute rien ici. |
| `docs/ROADMAP.md`, paragraphe de la bande des faces | « … calcul réduit. Son prix se remesure sur l'état intégré. » | « … calcul réduit. **Son prix ne suffit pas** : remesuré … 0,838 … » | **iso11** | Même phrase de `3155395`, qu'iso11 a complétée par la mesure qu'elle annonçait. |
| `docs/ROADMAP.md`, Q34 = C | « puis de la couleur de la lumière, EST LE DÉFAUT » | « puis ROUGE, EST LE DÉFAUT (corrigé le 2026-09-27 … `78fb380` …) » | **iso11** | Texte d'`ef61a79`, corrigé par iso11 ; le code fusionné fait bien le rouge. |
| `docs/ROADMAP.md`, fin de Q35 | « 3,5 s ; puis Adrien le juge en jouant. » | la même phrase + « Le jeu dit s'il est en essai » + « Le prix de cadence du rouge long : TIENT (1,024) » | **iso11** | Préfixe exact du côté iso11. |

Date d'en-tête : 2026-09-27 (integration-iso14 ; iso11 disait 2026-09-25) — fusionnée sans conflit.

### Fusion 2 — `origin/iso12-corps` (cef9d93)

Un seul fichier en conflit ; le code (`iso_materiaux.gd`, `voxel_catalogue.gd`, touchés des deux côtés) fusionne
sans conflit textuel.

| Fichier | Côté intégration (après fusion 1) | Côté iso12-corps | Résolution | Pourquoi |
|---|---|---|---|---|
| `docs/ROADMAP.md`, l. 7 | `Dernière mise à jour : 2026-09-27` | `2026-09-26` | **2026-09-27** | La plus récente, comme demandé. |
| `docs/ROADMAP.md`, tête de « Pièges connus » | ~150 lignes de pièges (drapeau sans `--`, glissement en diagonale, masque, série de cadence, patch par variante…) | un piège : « Une pré-passe de profondeur et sa couleur doivent être LE MÊME programme » | **les deux**, intégration d'abord, une ligne vide entre | Ajouts indépendants. |

⚠️ **iso12-corps part d'une base plus ancienne** (lacet 0° « A »), mais **ne touche pas `settings_manager.gd`** depuis
son ancêtre commun `5d9ef55` : la fusion garde donc les défauts d'integration-iso14 sans qu'on ait à trancher. Vérifié
après fusion (§ Valeurs par défaut).

## Anti-perte — ce que chaque branche ajoute est-il encore là ?

**Méthode, mécanique et reproductible** (le piège du 2026-09-09 : une fusion sans conflit n'est pas une fusion sans
perte). Pour chaque fichier qu'une branche touche depuis l'ancêtre commun, chaque ligne non vide qu'elle AJOUTE doit
exister, telle quelle, dans le fichier fusionné :

```bash
# perte.sh BASE BRANCHE — à lancer dans l'arbre fusionné
for f in $(git diff --name-only $1 $2); do
  git diff $1 $2 -- "$f" | grep '^+' | grep -v '^+++' | sed 's/^+//' | grep -v '^[[:space:]]*$' | sort -u > /tmp/_aj
  n=0; while IFS= read -r l; do grep -qxF -- "$l" "$f" || { n=$((n+1)); echo "  $f: $l"; }; done < /tmp/_aj
  echo "$f : $(wc -l </tmp/_aj) lignes ajoutées, $n manquantes"
done
```

| Contrôle | Résultat |
|---|---|
| `perte.sh 28152c5 origin/iso11-menus` après la fusion 1 | **10 fichiers, 738 lignes ajoutées, 0 manquante** (ROADMAP 59, fusee.gd 7, fusee_modele.gd 27, iso_volumes.gd 62, banc_equite_fusee.gd 185, preuve_masque_fumee.py 158, .sh 57, test_fusee.gd 23, test_iso_gadgets.gd 135, volume_masque.gdshaderinc 25) |
| Même contrôle pour integration-iso14 (`28152c5..a30a407`) sur les 3 fichiers en conflit | iso_volumes.gd : 1 ligne absente ; test_iso_gadgets.gd : 0 ; ROADMAP : 4. **Les cinq sont les versions antérieures qu'iso11 a réécrites** (tableau de la fusion 1) : l'en-tête « … de la couleur de la lumière » du commentaire de `_suivre_coeur_fusee`, « puis de la couleur de la lumière, EST LE / DÉFAUT** … », « Son prix se remesure sur l'état intégré. », « 3,5 s ; puis Adrien le juge en jouant. » |
| `perte.sh 5d9ef55 origin/iso12-corps` après la fusion 2 | **10 fichiers, 668 lignes ajoutées, 1 manquante** : `> Dernière mise à jour : 2026-09-26`, remplacée par 2026-09-27 (voulu). corps_iso.gdshader 30, corps_iso_eclaire.gdshader 30, JOURNAL_SESSIONS 5, ROADMAP 146, iso_corps_detail.gdshaderinc 23, iso_materiaux.gd 16, banc_corps.gd 40, test_corps_detail.gd 176, voxel_catalogue.gd 53, voxel_corps.gd 149 |
| Même contrôle pour le côté intégration (`5d9ef55..8f81a53`) sur les fichiers d'iso12 | ROADMAP 309, iso_materiaux.gd 21, voxel_catalogue.gd 4 : **0 manquante** |

**Points d'ancrage, par `grep` dans l'arbre fusionné** (tous présents) :

| Ancre | Branche | Où |
|---|---|---|
| `--fusee-rouge-long` (`DRAPEAU_ROUGE_LONG`, `poser_rouge_long`) | iso11 | fusee_modele.gd, test_fusee.gd, test_iso_gadgets.gd |
| `_suivre_coeur_fusee(f, lumiere, energie, vus)` | iso11 | iso_volumes.gd, test_iso_gadgets.gd |
| `couleur_coeur_fusee`, `COULEUR_COEUR_ROUGE`, `SHADER_HALO_MELANGE` | iso11 | iso_volumes.gd, test_iso_gadgets.gd |
| `masque_fumee := false` | les deux | iso_volumes.gd |
| `coeur_fusee := 2`, `--sans-fusee-coeur` | les deux | iso_volumes.gd, test_iso_gadgets.gd |
| `--corps-detaille` (`DRAPEAU_DETAIL`, `forcer_detail := -1`) | iso12 | voxel_catalogue.gd, voxel_corps.gd, iso_materiaux.gd, les deux shaders de corps, iso_corps_detail.gdshaderinc, test_corps_detail.gd |
| `CORPS_DETAIL_MATIERE` | iso12 | voxel_corps.gd, voxel_catalogue.gd, iso_materiaux.gd, iso_corps_detail.gdshaderinc, test_corps_detail.gd |
| `forcer_matiere` | iso12 | voxel_catalogue.gd, banc_corps.gd, test_corps_detail.gd |
| `passe_profondeur` (le piège de la pré-passe) ; `--sans-profondeur` | iso12 | voxel_corps.gd, les deux shaders, iso_corps_detail.gdshaderinc, iso_materiaux.gd, test_corps_detail.gd ; banc_corps.gd |
| Garde D4 : `if not OS.is_debug_build(): return` dans `_input` | integration-iso14 | presentation_3d.gd:2045 |

## Valeurs par défaut après la fusion (vérifiées au code)

| Valeur | Attendu (integration-iso14) | Trouvé | Où |
|---|---|---|---|
| `LACET_DEFAUT` | 45,0 | **45.0** | settings_manager.gd:152 |
| `OPTION_LACET_DEFAUT` | "B" | **"B"** | settings_manager.gd:153 |
| Usure (Q30) | allumée sauf `--sans-usure` | **`return not args.has(DRAPEAU_SANS_USURE)`** | iso_materiaux.gd:172-173 |
| `DECALAGE_VISEE_DEFAUT` | 0,15 | **0.15** | settings_manager.gd:132 |
| `ZOOM_DUEL_DEFAUT` | 1,5 | **1.5** | settings_manager.gd:129 |
| Masque de la fumée | éteint | **`masque_fumee := false`** | iso_volumes.gd |
| Point de braise (Q34 = C) | 2 : blanc au plein feu, rouge après | **`coeur_fusee := 2`** | iso_volumes.gd |
| Rouge long (Q35) | éteint | **`duree_plein_feu` = long seulement si `--fusee-rouge-long`** | fusee_modele.gd:45 |
| Personnage détaillé | éteint | **`forcer_detail := -1`, lit `--corps-detaille`** | voxel_catalogue.gd:490-491 |

`settings_manager.gd` et `presentation_3d.gd` sont identiques à a30a407 (`git diff a30a407 244cb88 --
settings_manager.gd presentation_3d.gd` est vide).

## Suite complète

`GODOT=/usr/local/bin/godot ./tools/run_suites.sh` sur `244cb88` (les deux fusions, avant le commit du photographe) :
**137 suites OK, code 0, « tout passe, sans erreur de script (594s) »**. Journal complet :
[`suite_244cb88.log`](suite_244cb88.log). Les `CLIENT OK (coupé, code 137)` des bancs duo sont le client tué à
dessein par le lanceur (ils sortent OK).

## La planche (photographe, sous Xvfb, 1920×1080)

Deux séances, toutes deux sur l'arbre fusionné plus le commit du photographe (manifeste : `commit 90327e8`,
`mode_rendu "iso lacet 45° B"`). La première image de chaque séance a été regardée **avant** toute mesure : pas d'intro
(le `user://` neuf a été préparé avec `intro_vue=true`, voir les commandes).

| Image | Ce qu'elle prouve |
|---|---|
| [`1_duel_45B_torches_allumees.jpg`](img/1_duel_45B_torches_allumees.jpg) | Le duel à 45° (les murs en diagonale), corps en aplats gris-bleu (le personnage détaillé est éteint), le noir hors des lumières. |
| [`2_ecran_scinde_45B_J2_cote_oppose.jpg`](img/2_ecran_scinde_45B_J2_cote_oppose.jpg) | L'option B : la vue de J2 (à droite) tournée de 180° par rapport à celle de J1. |
| [`3_torche_seule.jpg`](img/3_torche_seule.jpg) | La torche seule dans le noir, à 45°. |
| [`4_torches_eteintes_repere.jpg`](img/4_torches_eteintes_repere.jpg) | Torches éteintes (plan « repère ») : il ne reste que le HUD, les repères du poseur et le halo du joueur. |
| [`5_fusee_plein_feu.jpg`](img/5_fusee_plein_feu.jpg) | La fusée à 1,2 s, au plein feu : lumière rouge, cœur presque blanc. |
| [`6_fusee_braise_point_rouge.jpg`](img/6_fusee_braise_point_rouge.jpg) et [`7_point_rouge_loupe_x6.jpg`](img/7_point_rouge_loupe_x6.jpg) | La même fusée plus tard (dernier plan de la séance 2, « arbalète »), lumière passée à l'orange de la braise : **le point est ROUGE** sur le sol jaune-orange. Mesure : cœur (rayon 4 px) **(238, 174, 114)**, anneau à 20-30 px (252, 219, 115) : le point baisse le vert de 45 et le rouge de 14 par rapport à son entourage. Avant `88dbfb0` il était jaune pâle (D1 de la ROADMAP) : un point additif sur ce sol aurait monté le vert, pas baissé. |

Le jeu dit lui-même ses défauts dans le journal ([`photos_seance1.log`](photos_seance1.log),
[`photos_seance2.log`](photos_seance2.log)) : `[usure] allumée`, `[fumée masque] éteint (le défaut depuis le
2026-09-26 …)`, **aucune** ligne `[fusée] rouge long` (imprimée à la première fusée quand l'essai est allumé), **aucune**
ligne `[fusée cœur]` (imprimée seulement hors du défaut 2).

## Commandes exactes pour tout refaire (cloud)

```bash
git fetch origin integration-iso14 iso11-menus iso12-corps
git checkout -B claude/cloud-integration-blanc origin/integration-iso14
git merge --no-ff origin/iso11-menus     # résoudre comme au tableau de la fusion 1
git merge --no-ff origin/iso12-corps     # résoudre comme au tableau de la fusion 2
godot --headless --path . --import
GODOT=/usr/local/bin/godot ./tools/run_suites.sh                     # 137 OK, ~10 min
# Le photographe pour le cloud (commit à part, pas pour le Mac) :
git fetch origin claude/cloud-photographe main
git diff 76fe78f 0c67705 -- tools/photographe.gd tools/loupe.gd tools/run_photos.sh | git apply
# Un user:// neuf où l'intro est déjà vue (sinon elle recouvre les prises) :
export XDG_DATA_HOME=$PWD/../xdg ; U="$XDG_DATA_HOME/godot/app_userdata/Candela 2D"; mkdir -p "$U"
printf '[display]\n\nintro_vue=true\n' > "$U/settings.cfg"
GODOT=/usr/local/bin/godot GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
  ./tools/run_photos.sh --plan=duel,ecran-scinde-duel,torche,repere,fusee,loupe-fusee-lissage-sans-suie --sortie=user://blanc
GODOT=/usr/local/bin/godot GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
  ./tools/run_photos.sh --plan=fusee,armes,impacts --sortie=user://blanc2
```

Sur le Mac, pour Iso 1 : seulement les deux `git merge` et leurs résolutions, puis `./tools/run_suites.sh`. **Ne pas
reprendre `fde7346`** (le photographe du cloud) ni le dossier `docs/iso/cloud/integration-blanc/`.

## Décisions prises seules, et pourquoi

- **Pas d'approfondissement du clone** : `git merge-base` a trouvé les ancêtres communs (28152c5, 5d9ef55) du premier coup.
- **Des « résolutions iso11 » qui ne sont pas des prises en bloc** : integration-iso14 porte des commits d'iso11 recopiés
  (cherry-pick), git les croit différents ; là où iso11 les a réécrits ensuite, sa version est la suite du même texte. Vérifié
  par `git show <commit d'origine>:docs/ROADMAP.md | grep` pour chacune des quatre lignes (§ Anti-perte).
- **La planche sans `photo_essais.gd`** : l'outil de `claude/cloud-essais` ne compile pas sur cette base (il précharge
  `res://tuyaux_iso.gd`, absent d'integration-iso14). Je ne l'ai pas committé ni corrigé (aucun code de moi) ; le photographe
  du dépôt suffit, et le `user://` préparé remplace le congé de l'intro.
- **Le point rouge pris sur un plan « armes »** : le photographe n'a pas de plan « fusée à la braise » en vue de jeu, et
  la loupe `loupe-fusee-lissage-sans-suie` ne montre pas le point (voir plus bas). Les plans qui suivent la fusée la
  gardent dans le cadre pendant sa vie de 20 s : le dernier tombe dans la braise.

## Ce que je n'ai PAS pu prouver

- **La cadence** : aucun chiffre ici, le cloud n'en donne pas (llvmpipe). Les deux branches l'ont mesurée sur le Mac chacune
  de son côté (iso11 : 1,024 ; iso12 : 0,976) ; **la cadence de l'état fusionné n'est pas mesurée**.
- **L'âge exact de la fusée** sur l'image 6 : le photographe ne l'écrit pas au manifeste. Je sais qu'elle est après le
  plein feu (lumière orange, et 4 prises après celle d’1,2 s), pas à quel acte (braise ou agonie).
- **Le blanc du plein feu au pixel** : sur l'image 5, la fumée couvre le point ; « presque blanc » s'y lit à l'œil, pas au pixel.
  La couleur exacte (blanc au plein feu, `COULEUR_COEUR_ROUGE` après) reste prouvée par la suite (`test_iso_gadgets`).
- **Le personnage détaillé ALLUMÉ** et le **rouge long ALLUMÉ** n'ont pas été photographiés : la tâche demandait le défaut.
  Leurs suites (`test_corps_detail`, `test_fusee`, `test_iso_gadgets`) passent sur la fusion.
- **Le noir absolu au pixel** (0 pixel allumé hors lumière) n'a pas été compté ; il n'est constaté qu'à l'œil sur les images 1 à 4.

## Signalés, non corrigés (hors de ma tâche)

1. **`tools/banc_equite_fusee.gd.uid` et `volume_masque.gdshaderinc.uid` n'existent dans aucune branche** : l'import les
   crée, non suivis (`git status` après `godot --headless --path . --import`). Les 531 autres `.uid` sont suivis ; un
   `.uid` régénéré diffère d'une machine à l'autre. À committer une fois, par qui tient ces fichiers (Gadgets).
2. **Commentaire périmé** dans `iso_volumes.gd:101` (fusion, venu d'iso11 tel quel) : « 2 (défaut) : presque blanc pendant le
   plein feu, puis de la couleur de la lumière (rouge, orange) » — depuis `88dbfb0`, c'est « puis ROUGE »
   (`COULEUR_COEUR_ROUGE`). Reproduire : `grep -n "rouge, orange" iso_volumes.gd`.
3. **La loupe `loupe-fusee-lissage-sans-suie` ne montre pas le point de braise** (ni blanc au plein feu, ni rouge à la braise) :
   on n'y voit que le voxel bleu. Soit le plan gèle la fusée d'une façon qui court-circuite `_suivre_coeur_fusee`, soit le halo
   est derrière le voxel à ce cadrage — non diagnostiqué. Reproduire : la première commande photo ci-dessus, images
   `loupe/01-…-ref-posee.png` et `04-…-ref-braise.png`.
4. **`tools/photo_essais.gd` (branche `claude/cloud-essais`) ne compile pas sur integration-iso14** : `Preload file
   "res://tuyaux_iso.gd" does not exist`. Il ne vaut que sur la branche qui porte les tuyaux.

## À reporter dans la ROADMAP (par l'intégration)

- **Piège : un commit recopié (cherry-pick) puis réécrit sur sa branche d'origine se lit, à la fusion, comme un conflit
  entre deux textes.** C'est l'ancienne version contre la nouvelle ; la résolution est la nouvelle, mais seulement après avoir
  prouvé que l'ancienne est bien l'ancêtre (`git show <commit d'origine>:fichier | grep`). Sinon, on garde les deux.
- **Une fusion se prouve sans perte mécaniquement** : chaque ligne ajoutée par chaque côté depuis l'ancêtre commun doit
  exister dans le fichier fusionné (script en § Anti-perte). Chaque absence doit avoir son explication écrite.
