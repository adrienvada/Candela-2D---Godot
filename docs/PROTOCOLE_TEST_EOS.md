# Tests EOS — deux instances sur une seule machine

Le Device ID d'Epic est lié à la **machine**, pas au processus : deux instances
lancées normalement sur le même Mac obtiennent le même PUID et ne peuvent donc
pas s'affronter. L'argument `--eos-ephemeral` force une identité jetable
(destruction puis recréation du Device ID) qui lève ce blocage.

`--eos-ephemeral` est **ignoré hors build debug** (`OS.is_debug_build()`), et
tant qu'il est actif un bandeau orange le rappelle en haut de l'écran. Il ne
peut pas s'armer chez un joueur.

## Prérequis

`res://eos_credentials.gd` doit exister (voir `eos_credentials.example.gd`). Ce
fichier n'est pas versionné : sans lui, le jeu démarre normalement mais reste en
« Epic : non configuré » et seul le transport réseau local est utilisable.

## Banc d'essai transport (`tools/test_transport.tscn`)

Exerce uniquement la couche réseau : salon, code, connexion P2P, RPC, sonde de
synchronisation à 30 Hz. C'est lui qui répond à « en quel mode Godot envoie-t-il
les paquets du `MultiplayerSynchronizer` ».

```bash
godot --headless --path . res://tools/test_transport.tscn -- --host --eos-ephemeral --spy --duration 10
```

Il affiche `CODE: XXXXXX`. Dans un second terminal :

```bash
godot --headless --path . res://tools/test_transport.tscn -- --join XXXXXX --eos-ephemeral --duration 10
```

Options utiles :

| Argument | Effet |
| --- | --- |
| `--transport enet` | Bascule sur ENet (`--join <IP>` au lieu du code) |
| `--no-eos` | N'initialise pas EOS du tout (debug hors ligne) |
| `--spy` | Relève le mode de transfert de chaque paquet sortant (hôte) |
| `--max-fps N` | Bride la boucle : le tick EOS suit la cadence d'image |
| `--extra-tick` | Ajoute un tick EOS par pas physique (expérience de mesure) |
| `--eos-verbose` | Journaux du plugin en niveau INFO |

Le mouchard `--spy` ne peut s'intercaler qu'**avant** toute connexion :
réaffecter `multiplayer_peer` purge la liste des pairs de la MultiplayerAPI.
C'est pourquoi il n'est branché que côté hôte en EOS.

## Match complet (`tools/test_online_match.tscn`)

Lance le jeu entier (`main.tscn`) et le pilote par les vrais boutons du menu :
sélection du mode, code de salon, décompte, manche, kill, écran de fin, rematch.

```bash
godot --headless --path . res://tools/test_online_match.tscn -- --host --eos-ephemeral
godot --headless --path . res://tools/test_online_match.tscn -- --join XXXXXX --eos-ephemeral
```

Variantes : `--local` (écran partagé, aucun réseau) et
`--host|--join <IP> --transport enet --no-eos` (réseau local).

## Sortie propre (`tools/test_quit_path.tscn`)

Vérifie que fermer la fenêtre relâche bien la plateforme EOS avant que l'arbre
se termine. Sans cette séquence, le processus meurt sur un segfault.

```bash
godot --headless --path . res://tools/test_quit_path.tscn -- --eos-ephemeral
```

## File d'appariement (`tools/test_queue.tscn`)

Interroge la file de la Phase 8 contre le **vrai** service : publication d'un
ticket, puis recherche filtrée sur l'attribut de classement. Il répond à la
question dont dépend tout l'élargissement par fourchettes — EOS accepte-t-il un
filtre **entier** avec `GreaterThanOrEqual` / `LessThanOrEqual` ?

```bash
godot --headless --path . res://tools/test_queue.tscn -- --eos-ephemeral
```

⚠️ **`--path .` désigne le dossier du terminal, pas le projet.** Le chemin du
dépôt contient deux espaces (`Projets jeux`, `Candela - Godot`) : un `cd` sans
guillemets échoue silencieusement et la commande se lance alors depuis le
dossier maison, où il n'y a aucun projet Godot — d'où un « il ne se passe
rien ». La forme qui marche depuis n'importe où :

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/vada/Desktop/Projets jeux/Candela - Godot/candela-2d" res://tools/test_queue.tscn -- --eos-ephemeral
```

### Deux instances — la découverte croisée

Une instance seule ne prouve que l'acceptation de la requête : son propre ticket
ne lui est pas rendu, et zéro candidat est le résultat **attendu**. Pour savoir
si une identité voit le ticket d'une autre, il faut deux instances qui se
chevauchent. Le ticket ne vit qu'environ quatre secondes entre sa publication et
son retrait : **décaler les lancements de 2 secondes**, pas davantage.

```bash
PROJ="/Users/vada/Desktop/Projets jeux/Candela - Godot/candela-2d"
G="/Applications/Godot.app/Contents/MacOS/Godot"
"$G" --headless --path "$PROJ" res://tools/test_queue.tscn -- --eos-ephemeral > /tmp/A.log 2>&1 &
sleep 2
"$G" --headless --path "$PROJ" res://tools/test_queue.tscn -- --eos-ephemeral > /tmp/B.log 2>&1 &
wait
grep -E "puid|en file|candidat" /tmp/A.log /tmp/B.log
```

**Relevé du 2026-08-18** — deux PUID distincts (`0002…6377`, `0002…ae35`), deux
tickets, et **1 candidat vu de chaque côté** dans la fourchette [940, 1060]. La
découverte croisée fonctionne donc contre le vrai service, à travers le filtre
entier borné des deux côtés.

Deux choses apprises en le faisant, qui ne se devinent pas :

- **2 secondes d'écart suffisent** entre deux lancements éphémères. La règle
  « les espacer » ne disait pas combien ; aucune collision de Device ID à ce
  rythme.
- **Un ticket fermé traîne ~1 minute dans l'index d'Epic.** Mesuré sans le
  chercher : un troisième lancement solo, juste après, a trouvé 1 candidat —
  un fantôme — puis 0 deux minutes plus tard. La recherche proposera donc
  parfois un adversaire mort ; la jointure échoue, et le délai de garde de 45 s
  l'écarte. C'est prévu par la conception, pas un défaut.

---

# Appariement automatique — test à deux fenêtres

Dernière inconnue de la Phase 8. La **découverte** est prouvée par le banc
ci-dessus ; ne le sont pas la jointure, la poignée de main par
engagement-révélation, l'accord des deux camps sur qui héberge, et la connexion.
Ces quatre-là ne s'exercent que par le jeu.

## ⚠️ Prérequis bloquant — à vérifier avant de sortir deux fenêtres

**Les deux entrées « CHERCHER UN MATCH EN LIGNE » doivent être ouvertes.** Au
2026-08-18 elles sont encore grisées dans `ui.gd` : `SCREEN_MATCHMAKING` est
déclaré et attaché au hub, mais **aucun `push` ne mène à l'écran**, et les deux
entrées portent un motif `NOT_YET`. L'écran de recherche est donc inatteignable,
et la séance ne peut pas avoir lieu.

Le raccordement demande que les deux entrées visent `SCREEN_MATCHMAKING` et que
le mode soit posé au passage — une seule instance d'écran sert les deux files,
et `ScreenMatchmaking.set_ranked_queue(bool)` existe pour ça.

Vérification en trente secondes avant de préparer quoi que ce soit : lancer le
jeu, `1V1 AMICAL`, et regarder si l'entrée est cliquable.

## Déroulé

### Étape 1 — la première fenêtre

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/vada/Desktop/Projets jeux/Candela - Godot/candela-2d" --resolution 720x405 --position 0,120 -- --eos-ephemeral
```

**Attendre `NetworkManager: EOS prêt (puid …)` dans sa console** avant de lancer
la seconde. Deux identités éphémères démarrées ensemble se marchent dessus et la
seconde repart sans identité Epic.

### Étape 2 — la seconde fenêtre

Même commande, `--position 760,120`.

### Étape 3 — comparer les deux PUID

**S'ils sont identiques, on s'arrête là.** L'éphémère n'a pas pris, chaque
fenêtre prendrait le ticket de l'autre pour le sien, et rien de ce qui suit
n'aurait de sens.

### Étape 4 — lancer les deux recherches

Dans chaque fenêtre : `Accueil` → `1V1 AMICAL` → `CHERCHER UN MATCH EN LIGNE`,
puis le bouton `CHERCHER UN MATCH`.

**Commencer par l'amical.** La file classée filtre sur une fourchette : une
variable de plus pour rien tant que le reste n'est pas établi.

Première passe immédiate, puis une toutes les 2 s. Une recherche infructueuse
coûte ~3 s chez Epic : raisonner en pas de 5 secondes, pas en instantané.

### Étape 5 — le contrôle qui compte

À « Adversaire trouvé », **lire qui héberge dans les deux fenêtres**. Elles
doivent nommer **le même hôte**. Si elles se contredisent, c'est un vrai défaut :
chaque machine calcule la désignation avec elle-même en premier, et personne
n'ouvrirait la connexion.

### Étape 6 — confirmer des deux côtés, en moins de 15 s

Au-delà, l'échéance traite l'absence de réponse comme un refus — par conception,
pour ne jamais attendre un signal qui ne viendra pas.

### Étape 7 — le match

À partir de là c'est le duel ordinaire, déjà validé en Phase 3 : déplacements,
torche, tirs, dégâts des deux côtés.

## Ce que cette séance ne prouvera pas

**L'élargissement par paliers.** Deux identités éphémères n'ont aucun
classement : les deux files partent alors sans filtre de fourchette. Les paliers
±60 / ±120 / ±240 / ±480 demandent des profils classés — c'est une autre séance.

## Si ça ne marche pas

| Symptôme | Piste |
| --- | --- |
| « Appariement automatique indisponible » | EOS pas prêt, ou transport ENet. F3 doit dire `Epic : prêt` |
| Les deux PUID sont identiques | Fenêtres lancées trop près l'une de l'autre ; recommencer en attendant `EOS prêt` |
| Les deux cherchent sans se trouver | Le banc à deux instances ci-dessus isole le problème sans interface |
| « Adversaire trouvé » puis plus rien | Probablement un **ticket fantôme** : attendre le délai de garde de 45 s avant de conclure |
| Une seule fenêtre trouve l'autre | Normal un instant : dans un couple, un seul des deux a le droit de rejoindre |
| Les deux nomment un hôte différent | **Le vrai défaut à documenter** — relever les deux PUID et les deux journaux |

Le focus clavier reste sur la dernière fenêtre cliquée : cliquer dans une fenêtre
avant d'y appuyer sur quoi que ce soit. Et les deux instances partagent le même
`user://`, donc le même `match_history.json` — n'y lire aucun « chaque camp a
bien archivé le sien ».

---

# H1 — Test à deux machines, deux réseaux

Ces trois bancs valident tout ce qui peut l'être depuis une seule machine —
c'est-à-dire tout sauf **le franchissement de NAT**. Deux instances locales
obtiennent toujours `Lien DIRECT`, ce qui ne prouve rien : elles ne traversent
rien.

C'est le dernier jalon de la Phase 3, et il ne peut pas être automatisé.

## Ce qu'on cherche à savoir

1. Deux joueurs sur deux connexions Internet différentes se rejoignent-ils ?
2. Le lien est-il **DIRECT** (punchthrough réussi) ou **RELAYÉ** (repli sur
   l'infrastructure d'Epic) ? Les deux sont des succès ; le relais coûte
   seulement un peu de latence.
3. Quelle latence réelle, et le jeu reste-t-il jouable à cette latence ?
4. Que se passe-t-il quand une machine disparaît brutalement ?

## Prérequis — à faire AVANT le jour du test

Sur les deux machines :

1. **Godot 4.7.1** installé (même version des deux côtés).
2. **Le dépôt cloné, sur la même branche et le même commit** :
   ```bash
   git clone https://github.com/adrienvada/Candela-2D---Godot.git
   cd Candela-2D---Godot
   git checkout main
   git pull
   ```
   ⚠️ Les deux machines doivent être **au même commit**. Le code de salon est
   cherché dans un bucket qui dépend du jeu et de sa version : deux builds
   différents ne se verraient pas, et le symptôme (« code introuvable ») ne
   dirait pas pourquoi.
3. **`eos_credentials.gd` copié à la main** sur la seconde machine. Il est
   ignoré par git, il n'arrive donc pas avec le clone. Clé USB ou AirDrop —
   **jamais par mail ni messagerie** : il contient le Client Secret.
4. Vérifier que le jeu démarre sur chaque machine et que **F3** affiche
   `Transport EOS | Epic : prêt`. Si c'est `non configuré`, l'étape 3 a échoué.

**Ne PAS utiliser `--eos-ephemeral`.** Deux machines distinctes ont naturellement
deux identités Epic : le drapeau ne sert qu'à contourner le partage de Device ID
sur un seul poste, et il fausserait le test.

## Lire le panneau F3

En jeu, `F3` affiche deux lignes. Celle qui compte ici :

```
RÉSEAU | Transport EOS | Epic : prêt | Salon BE3YAR | Lien DIRECT | NAT modéré | PUID 000235…5da4
```

| Champ | Ce qu'il dit |
| --- | --- |
| `Lien` | **DIRECT** = punchthrough réussi · **RELAYÉ** = repli Epic · **AUCUN** = échec |
| `NAT` | Type de NAT local : ouvert / modéré / strict |
| `Salon` | Le code partagé |

Et sur l'autre ligne : `FPS`, `Ping`. **Photographier ou capturer cette ligne à
chaque scénario, sur les deux machines** — c'est le résultat du test.

## Déroulé

### Étape 0 — Répétition sur le même réseau (10 min)

Les deux machines sur le même Wi-Fi. Le but n'est pas de tester le NAT mais de
vérifier que la manipulation est rodée avant de compliquer.

- Machine A : `1V1 EN LIGNE` → `CRÉER SALON` → noter le code affiché.
- Machine B : `1V1 EN LIGNE` → `REJOINDRE` → saisir le code.
- Jouer un BO1 complet : décompte, manche, kill, killcam, écran de fin, rematch.

Si ça ne marche pas ici, inutile d'aller plus loin — le problème n'est pas le NAT.

### Étape 1 — S1 : deux réseaux domestiques distincts

Machine A sur ta connexion, machine B ailleurs (chez quelqu'un, ou en partage de
connexion mobile).

Relever, **dans les deux sens** (A héberge, puis B héberge) :

- Le lien s'établit-il ? En combien de temps ? *(1-3 s = punchthrough direct ;
  au-delà de 10 s = bascule sur relais)*
- `Lien` : DIRECT ou RELAYÉ ?
- `NAT` de chaque côté.
- `Ping` affiché, une fois la manche lancée.

⚠️ **Tester les deux sens est important** : la traversée de NAT n'est pas
symétrique, un sens peut réussir là où l'autre échoue.

### Étape 2 — S3 : les deux machines en partage de connexion mobile

**C'est le scénario qui compte.** Les opérateurs mobiles utilisent souvent du
CGNAT — le cas le plus défavorable, celui où le punchthrough direct échoue et
où EOS doit basculer sur son relais. Si ça marche ici, ça marchera partout.

Mêmes relevés qu'à l'étape 1. Un `Lien RELAYÉ` **est un succès** : c'est le
filet de sécurité d'Epic qui joue son rôle. Ce qu'on ne veut pas voir, c'est
`AUCUN`.

Si tu ne peux monter qu'un seul scénario, choisis celui-ci.

### Étape 3 — Déconnexion brutale

En pleine manche, **couper le Wi-Fi** d'une machine (pas quitter le jeu :
couper le réseau).

- Combien de temps avant que l'autre machine s'en aperçoive ?
- Revient-elle proprement en attente, avec un message clair ?
- Peut-on relancer un salon derrière sans redémarrer le jeu ?

EOS peut être bien plus lent qu'ENet à déclarer un pair mort. La valeur observée
est un réglage de délai à ajuster ensuite — c'est une mesure, pas un échec.

### Étape 4 — Ressenti (jalon H3)

Tant que tu as deux machines et un adversaire humain, joue **plusieurs manches
pour de vrai**. C'est la première fois que tout le travail de la Phase 2 est
éprouvé en conditions réelles : tir prédit, compensation de latence,
interpolation de l'adversaire.

Questions à te poser pendant que tu joues :

- Le tir part-il **instantanément** quand tu appuies ?
- L'adversaire se déplace-t-il de façon fluide, ou par saccades ?
- Quand tu tires sur lui alors qu'il est bien aligné sur ton écran, **touches-tu** ?
- Meurs-tu parfois « derrière un mur », sans comprendre ?
- Les manches sont-elles tendues, ou les deux joueurs tournent-ils en rond dans
  le noir ?

## Ce qu'il faut rapporter

Pour chaque scénario (S1 A→B, S1 B→A, S3 A→B, S3 B→A) :

| Scénario | Connexion ? | Délai | Lien | NAT A / NAT B | Ping | Jouable ? |
| --- | --- | --- | --- | --- | --- | --- |

Plus : le délai de détection de déconnexion, et tes impressions de jeu.

## Si ça ne marche pas

| Symptôme | Piste |
| --- | --- |
| `Epic : non configuré` | `eos_credentials.gd` absent ou mal recopié |
| « Code introuvable » | Codes différents ? Machines pas au même commit ? Salon expiré ? Une recherche infructueuse prend ~3 s, laisse-la finir |
| Salon trouvé mais `Lien AUCUN` | **Le vrai échec à documenter** : relever les deux types de NAT et les journaux des deux côtés |
| Connexion très lente puis OK | Normal : c'est la bascule sur relais |
| Le jeu se ferme mal | Relever le code de sortie, `tools/test_quit_path.tscn` couvre ce chemin |

En cas d'échec, **ne pas improviser de correctif sur place** : relever les faits
et les journaux, le diagnostic se fera après.
