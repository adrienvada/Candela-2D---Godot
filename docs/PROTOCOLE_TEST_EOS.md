# Avant tout — rendre `godot` disponible

Les commandes de ce document commencent par `godot`. **Ce raccourci n'existe pas
par défaut sur le poste d'Adrien** : le binaire vit dans le bundle de
l'application, et un copier-coller répond `command not found: godot`. À poser une
fois pour toutes, dans zsh :

```bash
echo 'alias godot="/Applications/Godot.app/Contents/MacOS/Godot"' >> ~/.zshrc && source ~/.zshrc
```

Contrôle : `godot --version` doit répondre `4.7.1.stable.official`.

Sans cet alias, remplacer `godot` par le chemin complet dans chaque commande :
`/Applications/Godot.app/Contents/MacOS/Godot`.

**Second piège, indépendant du premier :** `--path .` désigne le dossier où se
trouve le terminal, pas le projet — et le chemin du dépôt contient deux espaces
(`Projets jeux`, `Candela - Godot`). Un `cd` sans guillemets échoue sans rien
dire, et la commande part alors du dossier maison, où il n'y a aucun projet
Godot : symptôme « il ne se passe rien ». Se placer dans le projet une fois,
guillemets compris :

```bash
cd "/Users/vada/Desktop/Projets jeux/Candela - Godot/candela-2d"
```

Toutes les commandes qui suivent supposent ces deux points réglés.

---

# Ce qu'il reste à essayer — état au 2026-08-18

Ce document décrit **six** essais. Trois sont faits ; inutile de les refaire sauf
si l'on touche à ce qu'ils couvrent.

| Essai | État |
|---|---|
| Banc transport | ✅ fait |
| File d'appariement, découverte croisée | ✅ fait — deux identités se voient à travers le filtre |
| **Match complet à deux fenêtres** (code de salon) | ✅ **fait le 2026-08-18** — vert des deux côtés, code 0 : porte PRÊT, manche, killcam, écran de fin, rematch |
| **Appariement automatique à deux fenêtres** | 🔴 **à faire — c'est le prochain** |
| **H1 — deux machines, deux réseaux** | 🔴 à faire, contre-vérification due depuis les correctifs |
| Sortie propre | ✅ fait |

**Et hors de ce document, trente secondes :** vérifier **Échap** et **F3** en jeu.
Trois tentatives pilotées ont échoué sans conclure — c'est le dernier contrôle
qu'aucun agent ne sait faire.

## Ce qu'on lit désormais dans une trace

Depuis l'étape 8.9, la poignée de main écrit une ligne **quand elle réussit**,
une par connexion :

```
NetworkManager: poignée de main — protocole 2 accepté
```

Son absence dans un essai à deux instances est un signal : soit les deux copies
ne sont pas à jour, soit le paquet n'est pas passé. Un échec, lui, coupe le lien
avec un message rédigé pour le joueur — et le **silence** du pair est traité
comme un refus au bout de 8 secondes.

---

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

## Match complet (`tools/test_online_match.tscn`) ✅ validé le 2026-08-18

Lance le jeu entier (`main.tscn`) et le pilote par les vrais boutons du menu :
sélection du mode, code de salon, décompte, manche, kill, écran de fin, rematch.

**Résultat obtenu :** vert des deux côtés, `EXIT_CODE: 0`, ping applicatif 26 ms.
Ce qui est désormais prouvé contre le vrai service, et n'a pas à être re-prouvé :
le code se crée et se transmet, `PRÊT` reste grisé tant que l'hôte est seul et
s'ouvre à l'arrivée de l'adversaire, **aucune manche ne démarre à la connexion**,
la killcam rejoue 3/3 balles, le lien tient après elle, et le rematch relance une
manche.

Deux erreurs subsistent dans la trace et ne sont pas des défauts :
`packet_sequence.is_null()` et `states[…].playback.is_null()` viennent de l'audio
câblé sur des fichiers qui n'existent pas encore. Elles disparaîtront avec les
assets.

```bash
godot --headless --path . res://tools/test_online_match.tscn -- --host --eos-ephemeral
godot --headless --path . res://tools/test_online_match.tscn -- --join XXXXXX --eos-ephemeral
```

Variantes : `--local` (écran partagé, aucun réseau) et
`--host|--join <IP> --transport enet --no-eos` (réseau local).

## Sortie propre (`tools/test_quit_path.tscn`) ✅ validé le 2026-08-18

Sa réussite consiste à **disparaître** : NetworkManager reprend la notification de
fermeture, relâche la plateforme et appelle `quit()`. Jusqu'au 2026-08-18 il ne
disait donc rien en cas de succès, et le silence était indiscernable d'un banc
qui n'aurait rien exécuté. Il annonce désormais :

```
  ✓ la fermeture a été prise en charge, la plateforme relâchée avant l'arbre
✓ Tous les tests passent
EXIT_CODE: 0
```

Les trois erreurs `packet_sequence.is_null()` en tête de sortie sont les fichiers
de musique absents, pas un défaut du banc.

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

# Salon ouvert depuis le menu — test à deux fenêtres

Depuis `0e16a27`, le salon s'ouvre **avant** le match : un bouton dans le panneau
de droite, la liste des joueurs au-dessus, et le code affiché pendant qu'on est
encore dans le menu.

**Ce que ce test cherche.** L'hôte peut désormais être devant sa liste de joueurs
quand l'adversaire arrive — sans être passé par le chemin qui prépare la partie.
Le client, lui, démarre sa manche dès la connexion. Si la préparation côté hôte
manque, **P2 reste piloté par le clavier de l'hôte au lieu des commandes reçues,
et l'hôte joue derrière son propre menu.** C'est le scénario à provoquer.

## Commencer par le réseau local

Même logique de salon sans Epic dans les pattes : ni identité éphémère, ni code à
recopier, ni délai de recherche. Si ça casse là, ce n'est pas le réseau.

Deux fenêtres, sans drapeau :

```bash
godot --path . --resolution 720x405 --position 0,120
```

```bash
godot --path . --resolution 720x405 --position 760,120
```

**A (hôte)** — `1V1 AMICAL` → `MATCH PRIVÉ EN LOCAL` → `CRÉER`, puis
**CRÉER LE SALON** dans le panneau de droite. Le bouton passe à `SALON OUVERT` et
se grise, la liste affiche « Vous — hôte » et « En attente d'un adversaire… », et
l'adresse IP s'affiche. **Aucune partie n'a démarré** — c'est tout l'objet du
changement.

**B (invité)** — `1V1 AMICAL` → `MATCH PRIVÉ EN LOCAL` → `REJOINDRE`, saisir
`127.0.0.1` à droite, puis `REJOINDRE LE SALON`.

**Revenir sur A sans y toucher** : la ligne doit passer à
**« Adversaire — connecté »** pendant que l'hôte est encore dans son menu. C'est
le contrôle central — la liste de joueurs vit en dehors de la partie.

Puis `LANCER LE MATCH` sur A.

## Les quatre contrôles

1. **P2 répond-il au bon clavier ?** Faire bouger le joueur de la fenêtre B : il
   doit bouger chez A aussi. S'il ne répond qu'au clavier de A, c'est le défaut
   décrit en tête.
2. **L'hôte est-il sorti de son menu ?** Aucun reste de menu par-dessus la partie.
3. **Le salon ne se réouvre pas par-dessus le pair.** `CRÉER LE SALON` puis
   `LANCER LE MATCH` : si le lancement réhébergeait, il remplacerait le pair vivant
   et B serait éjecté au démarrage.
4. **Quitter l'écran referme le salon.** Recommencer, et faire `‹ RETOUR` chez A
   **avant** que B ne rejoigne : B doit alors échouer à se connecter. Un code
   publié derrière soi ferait attendre un adversaire devant une porte que plus
   personne ne garde.

## Puis la variante Internet

Mêmes gestes par `MATCH PRIVÉ EN LIGNE`, avec `-- --eos-ephemeral` sur les deux
fenêtres, la seconde lancée seulement après `EOS prêt` dans la console de la
première (voir l'étape 1 de la section suivante). Le code à six caractères
apparaît un instant **après** l'ouverture du salon : il arrive par
`lobby_code_ready`, ce n'est pas un blocage.

*Piège levé le 2026-08-18, à ne pas rechercher :* les deux écrans du salon local
se déclaraient auparavant « écran partagé ». Tout le bloc lobby était masqué — ni
bouton, ni adresse, ni liste — et `LANCER LE MATCH` y démarrait une partie en
écran partagé. Corrigé par `_apply_lobby_intent()`, qui pose enfin mode **et**
transport depuis la navigation.

---

# Appariement automatique — test à deux fenêtres

Dernière inconnue de la Phase 8. La **découverte** est prouvée par le banc
ci-dessus ; ne le sont pas la jointure, la poignée de main par
engagement-révélation, l'accord des deux camps sur qui héberge, et la connexion.
Ces quatre-là ne s'exercent que par le jeu.

## La recherche n'ouvre pas d'écran — elle rend la main

**Depuis `c7b0940`, chercher un match n'est plus une destination.** L'appui sur
l'entrée lance la file et rend aussitôt la main : la recherche continue pendant
qu'on parcourt les menus, et c'est un **bandeau en haut de l'écran**
(`match_banner.gd`) qui dit où elle en est. `screen_matchmaking.gd` existe encore
au dépôt mais n'est plus atteint par le hub.

Conséquence pour cette séance : **tout se lit dans le bandeau**, jamais dans un
écran dédié. Ses deux boutons gardent des places fixes — l'engagement d'un côté,
le retrait de l'autre — pour qu'un bouton n'échange jamais son sens sous le
doigt : `ANNULER` pendant la recherche, puis `CONFIRMER` / `REFUSER` quand un
adversaire est trouvé.

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

Dans chaque fenêtre : `Accueil` → `1V1 AMICAL` → `CHERCHER UN MATCH EN LIGNE`.
**L'appui suffit** — il n'y a pas d'écran à ouvrir ensuite. Le bandeau apparaît
en haut et le menu reste utilisable.

**Commencer par l'amical.** La file classée filtre sur une fourchette : une
variable de plus pour rien tant que le reste n'est pas établi.

Première passe immédiate, puis une toutes les 2 s. Une recherche infructueuse
coûte ~3 s chez Epic : raisonner en pas de 5 secondes, pas en instantané.

**À vérifier au passage, puisque c'est la raison d'être du bandeau :** naviguer
dans les menus pendant que la recherche tourne. Elle ne doit ni s'arrêter ni
disparaître de l'écran.

### Étape 5 — le contrôle qui compte

À « Adversaire trouvé », **lire qui héberge dans les deux bandeaux**. Ils doivent
nommer **le même hôte**. S'ils se contredisent, c'est un vrai défaut : chaque
machine calcule la désignation avec elle-même en premier, et personne n'ouvrirait
la connexion.

### Étape 6 — confirmer des deux côtés, en moins de 15 s

`CONFIRMER` dans les deux bandeaux. Au-delà de l'échéance, l'absence de réponse
est traitée comme un refus — par conception, pour ne jamais attendre un signal
qui ne viendra pas.

### Étape 7 — le match part tout seul

**Personne n'appuie sur « lancer ».** `game_state.gd` écoute `match_ready` et
bascule les deux machines dans la partie. La carte est **tirée au hasard**
(`MapData.select_random_map()`), elle ne sera donc pas celle du menu — c'est
voulu.

Le contrôle décisif est le même que pour les salons : **faire bouger le joueur
d'une fenêtre et vérifier qu'il bouge dans l'autre.** Si l'un des deux ne répond
qu'au clavier de sa propre fenêtre, les commandes ne circulent pas.

Ensuite, duel ordinaire : torche, tirs, dégâts, killcam des deux côtés.

## Ce que cette séance ne prouvera pas

**L'élargissement par paliers.** Deux identités éphémères n'ont aucun
classement : les deux files partent alors sans filtre de fourchette. Les paliers
±60 / ±120 / ±240 / ±480 demandent des profils classés — c'est une autre séance.

## Si ça ne marche pas

| Symptôme | Piste |
| --- | --- |
| « Appariement indisponible » dans le bandeau | EOS pas prêt, ou transport ENet. F3 doit dire `Epic : prêt` |
| Aucun bandeau après l'appui | L'autoload `Matchmaker` ou le bandeau ne sont pas dans l'arbre |
| Les deux PUID sont identiques | Fenêtres lancées trop près l'une de l'autre ; recommencer en attendant `EOS prêt` |
| Les deux cherchent sans se trouver | Le banc à deux instances ci-dessus isole le problème sans interface |
| « Adversaire trouvé » puis plus rien | Probablement un **ticket fantôme** : attendre le délai de garde de 45 s avant de conclure |
| Une seule fenêtre trouve l'autre | Normal un instant : dans un couple, un seul des deux a le droit de rejoindre |
| Les deux nomment un hôte différent | **Le vrai défaut à documenter** — relever les deux PUID et les deux journaux |
| Les deux confirment, rien ne démarre | Le lien s'établit mais personne ne quitte le menu : regarder l'écoute de `match_ready` dans `game_state.gd` |
| Un joueur ne répond qu'à son propre clavier | Les commandes ne circulent pas — même défaut que pour les salons |

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
