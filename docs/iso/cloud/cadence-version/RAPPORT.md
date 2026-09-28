# Mesurer la cadence par version — rapport de la session cloud « cadence-version »

> Branche `claude/cloud-cadence-version`, partie de `origin/integration-iso14` (`a30a407`), 2026-09-28, de 06:41 à
> @@FIN@@ (Paris). **État : fait.** Rien ne change dans le jeu : une règle, deux outils, leurs essais, les tableaux du tri.

## Pour Adrien, en cinq lignes

@@CINQ@@

## La fiche pour le Mac (Iso 1)

**La première série : `a30a407` (la référence) contre la prochaine version intégrée** — la fusion d'iso11-menus et
d'iso12-corps que la session « intégration à blanc » a préparée (`244cb88` ; ta propre fusion doit lui être identique :
`git diff 244cb88 HEAD -- . ':!docs/iso/cloud'` vide). Le tri du cloud la classe **neutre** (§ 2) : vue unique seulement.

```bash
# 0. L'outil dans son propre arbre (on ne touche pas à l'arbre des autres sessions)
git fetch origin claude/cloud-cadence-version integration-iso14      # + la branche de la version à mesurer
git worktree add ~/candela-arbres.noindex/outil origin/claude/cloud-cadence-version
cd ~/candela-arbres.noindex/outil

# 1. AVANT la série, hors du verrou : les deux arbres (~/candela-arbres.noindex/<hash>) et leur import
tools/cadence/serie_version.sh --preparer a30a407 <tête B>           # quelques minutes ; refuse si l'import modifie un fichier suivi

# 2. La série, ≈ 28 min sans refus
mkdir /tmp/candela-mac.lock
tools/cadence/serie_version.sh a30a407 <tête B> /tmp/serie-version-<date>
rmdir /tmp/candela-mac.lock
```

`<tête B>` : un hash, une branche (`origin/…`) ou `244cb88`. `GODOT` vaut par défaut
`/Applications/Godot.app/Contents/MacOS/Godot` ; `ARBRES` par défaut `~/candela-arbres.noindex` (Spotlight ignore les
dossiers en `.noindex`). L'écran scindé : `SCINDE=1` (seulement si le tri a classé « lourde » une nouveauté de géométrie).

**Durée.** 5 min de repos initial, puis sept prises d'environ 3 min 20 (90 s sans Godot, le lancement, 30 s de chauffe du
banc, 60 s de mesure) : **≈ 28 min**. Chaque prise refusée par la porte : +3 min 20. La prolongation, si elle se déclenche :
+6 min 40 (≈ 35 min).

**Ce que le lanceur fait, dans l'ordre.** Il vérifie le verrou, qu'aucun Godot n'est ouvert, et que chaque arbre existe,
est importé, est à sa tête et n'a aucun fichier suivi modifié. Repos initial relevé (charge de Claude Helper). Puis une
chauffe A non comptée et `A B B A A B` ; avant chaque prise : 90 s sans aucun Godot, l'état thermique du Mac (il attend
qu'il soit « normal », dix minutes au plus), personne devant le Mac (navigateur, lecteur, son). Chaque prise :
`Godot --path <arbre du bras> res://tools/bench_framerate.tscn -- --seconds 60 --max-fps 0 --fusee --vue-unique
--classe=pompe` — **les mêmes arguments aux deux bras, aucun drapeau** : une version se mesure avec ses défauts.

**Ce qu'il refuse.**

| il refuse la PRISE (et la refait à sa place, quatre fois au plus) | il ARRÊTE la série (faute de montage) |
|---|---|
| un processus étranger au-dessus de 20 % d'un cœur dans la fenêtre mesurée (Godot, WindowServer, top, kernel_task exceptés) | un arbre absent, pas importé, pas à sa tête, ou avec un fichier suivi modifié — relu avant ET après chaque prise |
| Claude Helper (tous ses processus sommés) au-dessus de 30 % | une erreur de shader ou de script au journal |
| | « Rendu : iso lacet 45° B » absent (réglable : `RENDU=`), ou les joueurs pas au pompe |
| | des lignes d'état du jeu (`[usure] …`, `[fumée masque] …`…) qui changent d'une prise à l'autre d'un même bras |
| | une médiane illisible ; quelqu'un devant le Mac ; un Mac qui ne refroidit pas ; une cinquième reprise de la même prise |

**Comment lire le verdict** (fin de `serie.txt`) :

    A  prises 01_A 04_A 05_A   médianes [..]  1 % bas [..]  → médiane .. · 1 % bas médian .. · Claude Helper ..
    B  prises 02_B 03_B 06_B   …
    A tient dans 5 % : oui … · bras équilibrés : oui (écart … points)
    rapport B/A 0.9xx (+x.xx ms par image) · 1 % bas médian de B ..
    VERDICT : B TIENT | B NE TIENT PAS (règle 278 : rapport ≥ 0,970 ET 1 % bas médian > 60)
    lignes d'état propres à A (« < ») et à B (« > ») — ce que la version change, dit par le jeu

- **B TIENT** → B devient la référence de la version suivante.
- **B NE TIENT PAS** → chercher la coupable (règle, § 6) : retirer la nouveauté que le tri classe la plus lourde, et une
  série courte A contre B′.
- **SANS VERDICT** (les A ne tiennent pas dans 5 %, ou Claude Helper diffère de plus de 2 points entre les bras) → la série
  est à refaire, pas à lire.
- **« verdict PROVISOIRE … » puis « ⤷ PROLONGATION »** → le rapport tombait entre 0,958 et 0,982 : un bloc `B A` de plus a
  été pris, et **seul le verdict qui suit compte**. Jamais de second bloc.
- Les prises refaites portent `_r1`, `_r2`… : le verdict ne lit que celles que la porte a acceptées.

@@SUITE@@
