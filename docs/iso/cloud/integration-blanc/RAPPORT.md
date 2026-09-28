# Intégration à blanc — iso11-menus + iso12-corps dans integration-iso14

> Session cloud, branche `claude/cloud-integration-blanc`, 2026-09-28 (heures de Paris).
> **En cours** : fusions faites et vérifiées ; suite et planche à venir.

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
