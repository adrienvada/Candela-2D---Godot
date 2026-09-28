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
