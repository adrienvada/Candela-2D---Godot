# Consignes communes — lecture de la ROADMAP pour l'audit d'optimisation (2026-10-04)

Un audit d'optimisation complet de Candela 2D (Godot 4.7, GDScript, renderer `gl_compatibility`, duel 1v1
dans le noir où la seule information est la lumière) est en cours. Des sous-agents auditent le code, domaine
par domaine. Le projet impose de lire `docs/ROADMAP.md` **en entier** avant d'agir ; le fichier fait 2,9 Mo
(34 455 lignes), trop pour un seul contexte : il est donc lu par tronçons, un sous-agent par tronçon.
Ton tronçon est dans ton message de mission.

Dépôt : `/home/user/Candela-2D---Godot`. Dossier de travail (le SEUL où tu écris) :
`docs/audit_optimisation/roadmap/`

## Règles

- **Lecture seule** : ne modifie aucun fichier du dépôt, aucune commande git qui écrit, **ne lance pas Godot**
  (un autre agent mesure la cadence sur cette machine).
- **Lis ton tronçon EN ENTIER**, par morceaux successifs (outil Read avec `offset`/`limit`, 300 à 500 lignes à
  la fois), de la première à la dernière ligne. Ne saute rien : un fait de performance se cache souvent dans un
  chantier dont le titre n'en parle pas (un piège de mesure dans un chantier audio, un coût de rendu dans un
  chantier de menus…).
- Recopie les chiffres **exactement**, avec leur unité, leur machine, leur scène et leur date. N'invente rien,
  ne généralise pas, ne « corrige » pas la ROADMAP. Si deux passages se contredisent, cite les deux.
- Une entrée = une puce, qui commence par le numéro de ligne de la ROADMAP (`l. 12345`).

## Ce qu'il faut extraire

- **A. MESURES** — cadence (fps, 1 % bas, médianes), temps d'image, ms par poste, appels de dessin, nombre de
  lumières/nœuds/particules, mémoire, bande passante, temps de chargement ou de compilation — avec la machine
  (Mac M3, cloud llvmpipe…), la scène, la méthode, la date.
- **B. DÉCISIONS** — optimisations adoptées ou REFUSÉES (et pourquoi) ; réglages imposés (résolution, zoom,
  cadence physique, renderer, plafonds) ; compromis visuels ou de gameplay tranchés par Adrien.
- **C. PIÈGES** — erreurs déjà payées qui touchent la performance, ou qui piégeraient une optimisation (un nœud
  masqué qui rend encore, un shader compilé à la volée, une mesure faussée, un cache qui se périme…).
- **D. INVARIANTS À NE PAS CASSER** — ce qui ressemble à une optimisation possible mais est proscrit (équité en
  ligne, lisibilité de la lumière, oreille audio, nommage des nœuds pour les RPC, déterminisme des bancs…).
- **E. PISTES DE PERFORMANCE OUVERTES** — idées notées mais non faites, questions ouvertes, mesures demandées,
  dettes connues.
- **F. MÉTHODES ET OUTILS** — bancs (`tools/…`), drapeaux de lancement, protocoles de mesure, et leurs pièges.

Si ton tronçon ne contient rien pour une catégorie, écris « rien dans ce tronçon ».

## Livrable

1. Écris ton extraction dans `roadmap/<ton identifiant>.md` (dossier de travail ci-dessus), sous les six titres
   A à F, précédés d'une ligne qui dit les lignes lues (première et dernière) — la preuve que le tronçon a été lu
   en entier.
2. Ta **réponse finale** : le chemin du fichier, puis les **12 faits les plus importants pour un audit
   d'optimisation** (une ligne chacun, numéro de ligne en tête). Rien d'autre.
