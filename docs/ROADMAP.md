# Candela 2D — Feuille de route

> **Ce document a été simplifié le 2026-08-19.** Il faisait 5219 lignes et
> mélangeait tout : l'état du jeu, des journaux de mesure, des débats
> techniques réglés depuis longtemps. Devenu illisible, même pour s'y
> retrouver vite. Il dit maintenant l'essentiel, en langage simple.
>
> **Rien n'a été jeté.** Tout l'ancien contenu — le détail technique, le
> pourquoi de chaque décision, les journaux de mesure — reste dans
> [docs/ROADMAP_ARCHIVE_2026-08-19.md](ROADMAP_ARCHIVE_2026-08-19.md), qui
> **continue d'être tenu à jour** par les sessions de travail : c'est là que
> va le détail complet d'un nouveau piège ou d'une nouvelle décision, pas
> ici. Ce document court y renvoie chaque fois que le détail compte, et ne
> reçoit qu'un résumé d'une ligne si le sujet le justifie.
>
> Toute session de travail le lit avant d'agir et le met à jour avant de
> conclure. Protocole de mise à jour : voir [README.md](../README.md). Avant
> d'écrire dans un fichier du jeu, lire aussi
> [docs/JOURNAL_SESSIONS.md](JOURNAL_SESSIONS.md) — plusieurs sessions
> travaillent en même temps, et c'est ce fichier qui dit qui tient quoi.
>
> Dernière mise à jour : 2026-08-19

---

## Le jeu, en une minute

Un duel à deux joueurs, vu de dessus, dans le noir complet. La seule chose
qu'on voit, c'est la lumière : sa propre torche (qui éclaire, mais trahit où
on est), l'éclair d'un tir, le reflet d'une lumière sur un mur. **Être vu,
c'est être mort.** Une partie dure 5 minutes, en une seule manche.

Chaque décision de conception se juge à deux critères : le jeu doit rester
**simple à prendre en main et prenant**, et rester **fluide, honnête et sans
triche possible** quand on joue en ligne contre quelqu'un.

---

## Où en est le jeu, aujourd'hui

**Toute la construction du jeu est terminée.** Les huit grandes étapes du
projet (voir le tableau plus bas) sont closes côté programmation. Ce qui
reste n'est plus du code à écrire, mais :

- du **contenu** à fournir (des sons, de la musique, des idées d'armes),
- des **vérifications humaines** que seul Adrien peut faire (jouer, tester
  sur deux ordinateurs),
- des **finitions d'ambiance** encore en cours (voir plus bas).

---

## ⚠️ Un bug connu, pas encore corrigé

**Sur l'hôte, si l'adversaire quitte la partie, plus personne ne peut le
rejoindre.** L'écran continue pourtant d'afficher le code du salon, comme si
on pouvait encore s'y connecter. Repéré et mesuré le 2026-08-19, pas encore
réparé. Détail technique : [archive, « Famille 4.1 »](ROADMAP_ARCHIVE_2026-08-19.md).

---

## Les huit grandes étapes

| # | Étape | Où ça en est |
|---|---|---|
| 1 | Jouer à deux sur le même écran | ✅ Terminé |
| 2 | Jouer en ligne, un des deux ordinateurs fait office d'arbitre | ✅ Terminé |
| 3 | Se connecter à un ami sur Internet (via Epic, le service qui gère ça) | ✅ Terminé, testé sur deux vraies machines |
| 4 | Classement en ligne (identité, historique des matchs, ELO) | ✅ Terminé, en service depuis le 2026-08-16 |
| 5 | Les menus du jeu | ✅ Terminé |
| 6 | Les rangs (Aveugle, Bougie, etc.) | ✅ Terminé |
| 7 | Débloquer des armes en montant de rang | ✅ Le mécanisme est fini. **Il manque juste les armes elles-mêmes** pour les rangs 5 à 10 — une question de contenu, pas de code |
| 8 | Trouver un adversaire automatiquement | ✅ Terminé côté code. **Reste un seul test humain** : lancer le jeu sur deux fenêtres à la fois pour vérifier que deux joueurs se trouvent bien |

Détail technique de chaque étape : [archive, section « État des phases »](ROADMAP_ARCHIVE_2026-08-19.md).

---

## Ce qu'il reste à faire

### Ce qu'Adrien seul peut fournir ou décider

1. **76 fichiers audio** — sons et musiques. Aucune IA ne peut les créer ;
   liste précise dans l'onglet ASSETS du suivi de projet. À commencer par les
   5 musiques : c'est le plus long à produire, et beaucoup de choses du jeu
   les attendent déjà.
2. **Les armes des rangs 5 à 10** — six armes à inventer (nom, effet). La
   mécanique de déblocage les attend déjà.
3. **Tester le jeu sur deux fenêtres en même temps** pour vérifier que deux
   joueurs se trouvent automatiquement (dernier test de l'étape 8).
4. **Tester sur deux vrais ordinateurs**, sur deux connexions Internet
   différentes — à refaire depuis les derniers correctifs.
5. **Rejouer une partie de temps en temps** pour donner un avis sur le
   ressenti : aucune IA ne peut juger si le jeu est amusant.

### Ce qu'une session peut faire seule, sans attendre Adrien

- Continuer les **finitions d'ambiance** (« game feel ») : sons de torche,
  effets à la mort, animations de menu. Beaucoup sont déjà faits ; le détail
  est dans l'archive, section « Game feel ».
- Des petites réparations de code repérées en cours de route (« chantiers de
  robustesse » dans l'archive), sans urgence.

---

## Erreurs déjà commises — pour ne pas les refaire

**Chaque ligne ci-dessous est une erreur qui a déjà coûté du temps une fois.**
Certaines ont recoûté du temps une seconde fois parce qu'elles n'étaient
écrites qu'ici, dans un document devenu trop long pour être relu. Le titre
suffit souvent à faire revenir le souvenir ; le détail complet (pourquoi,
comment ça a été trouvé) est à un clic, dans l'archive :

- **Un test qui passe ne veut pas dire que la fonctionnalité marche.** Un
  système d'éblouissement du joueur n'a jamais fonctionné, alors que ses
  tests étaient verts depuis le début — ils ne vérifiaient que la moitié qui
  marchait.
- **Un chiffre de performance mesuré une seule fois n'est pas fiable.** Le
  compteur d'images par seconde de Godot ne se met à jour qu'une fois par
  seconde ; le mesurer plus souvent donne des faux résultats qui se
  ressemblent tous.
- **Un commentaire décrit ce qu'on voulait faire, pas forcément ce que le code
  fait vraiment.** Un commentaire affirmait qu'un écran se rouvrait « dans
  tous les cas » ; ce n'était pas vrai, et ça a fait perdre deux passages de
  travail avant qu'on aille vérifier avec le jeu plutôt qu'avec le texte.
- **Ne jamais couper le jeu en ligne d'un coup sec.** Il faut le laisser se
  fermer proprement, sinon il plante au démarrage suivant.
- **Deux sessions qui travaillent sur le même fichier en même temps créent des
  doublons.** Une même fonctionnalité (la trajectoire affichée après une
  mort) a été codée deux fois, par deux sessions différentes, sans qu'aucune
  ne le sache.
- **Un fichier technique généré automatiquement par Godot (`.uid`) doit être
  sauvegardé avec le reste du code.** Sinon, chaque ordinateur en invente un
  différent et ça sème la confusion.
- **Un document qui dit une fausse information est pire qu'un document
  vide.** Plusieurs fois, cette feuille de route a annoncé du travail comme
  « à faire » alors qu'il était déjà fait (ou l'inverse) — ça fait perdre du
  temps à tout le monde.

Liste complète, avec toutes les explications : [archive, section « Pièges
connus »](ROADMAP_ARCHIVE_2026-08-19.md).

---

## Décisions déjà prises — pour ne pas les rouvrir sans raison

Liste complète et détaillée dans l'archive (section « Décisions actées »).
Les plus importantes :

- Pas de serveur dédié : c'est un des deux joueurs qui héberge la partie.
- Une seule manche par match, 5 minutes.
- On rejoint une partie d'ami avec un code, pas une liste de salons.
- Pas de limite d'images par seconde : plus le jeu va vite, moins on sent de
  retard en ligne.
- Le rang de départ est le plus bas de l'échelle (Aveugle I) : personne ne
  peut descendre en dessous.
- Les deux joueurs d'un match classé ont accès aux mêmes armes (celles du
  moins bien classé des deux), pour que ce soit équitable.
- Un abandon en cours de partie compte comme une défaite.
- Tout le travail se fait directement sur la branche principale (`main`),
  plus de branches séparées par chantier.

---

## Pour aller plus loin

- **Le détail complet, technique, de tout ce qui précède** :
  [docs/ROADMAP_ARCHIVE_2026-08-19.md](ROADMAP_ARCHIVE_2026-08-19.md).
- **Le suivi visuel du projet, pour Adrien** :
  [suivi de projet](https://claude.ai/code/artifact/ba2ce690-309e-4d87-b72b-3ace1a1b681e).
- **Comment travailler sur ce dépôt à plusieurs sessions** :
  [README.md](../README.md) et [docs/JOURNAL_SESSIONS.md](JOURNAL_SESSIONS.md).
