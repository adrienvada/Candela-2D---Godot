# Mettre à jour un jeu déjà installé

> Ce document dit **comment** une version part dans la nature et comment un jeu
> installé la reçoit. `docs/ROADMAP.md` dit *pourquoi* (Phase 9).

Le joueur ouvre le menu, choisit **MISE À JOUR**, appuie une fois, et le jeu se
ferme, s'installe et se rouvre. Tout le reste de ce fichier est ce qu'il a fallu
pour que cette phrase soit vraie sans jamais casser l'installation de personne.

## Ce qui est tranché, et ne se rediscute pas sans raison

| Décision | Pourquoi |
|---|---|
| **Refus poli** (Adrien, 2026-08-18) | Une version de retard ne bloque rien : ni le démarrage, ni l'écran scindé, ni l'éditeur de cartes. Ce qui cesse — trouver un adversaire — a déjà cessé tout seul, `Protocol.accepts()` refusant symétriquement. L'écran le **nomme**. Un jeu qui refuse de démarrer transforme une gêne en panne. |
| **Rien sans signature valide** | Un fichier écrit par `HTTPRequest` ne porte pas l'attribut de quarantaine de macOS : aucun système ne vérifiera à notre place ce que ce code fait exécuter. Le jeu porte un classement ELO ; un manifeste substitué en chemin ferait tourner n'importe quel binaire sous l'identité du joueur. |
| **Jamais automatique** | La vérification est silencieuse, l'installation est un geste. Un jeu compétitif qui se met à jour tout seul change le comportement d'une arme entre deux manches d'une même soirée. |
| **Publier est un geste humain** | La CI ne publie que sur un tag `vX.Y.Z` posé à la main. Une version partie ne se rattrape pas : les jeux installés la trouveront encore dans deux ans. |
| **Deux chemins, tranchés à la publication** | Le jeu ne choisit pas de stratégie : il prend le paquet le moins cher que le manifeste rend applicable. Au moment de publier, on sait si le changement touche au moteur ; le jeu installé, lui, ne peut pas le savoir. |

## Les pièces

| Fichier | Rôle |
|---|---|
| `update_manifest.gd` | Juge : lire l'annonce, comparer les versions, choisir le paquet, vérifier la signature. Aucun réseau, aucun disque — donc entièrement testable. |
| `update_installer.gd` | Pose : décompresser, échanger les dossiers, relancer. Le seul fichier qui sache ce qu'est un `.app` ou un dossier Windows. |
| `update_manager.gd` | Autoload `UpdateManager`. Enchaîne, et met en mots ce que l'écran affiche. |
| `patch_loader.gd` | Autoload `PatchLoader`, **déclaré en premier**. Monte le correctif `.pck` avant tout le reste. |
| `screen_update.gd` | Écran du hub. N'a aucune énumération d'états recopiée : il affiche ce que le gestionnaire lui donne. |
| `tools/fabrique_manifeste.sh` | Fabrique le manifeste depuis les fichiers exportés. N'invente aucune valeur. |
| `.github/workflows/release.yml` | Sur tag : vérifie, teste, exporte, signe, publie. |
| `tools/test_mise_a_jour.gd` | La suite : 110 contrôles, dont la chaîne de signature et le script d'échange. |

## À faire une fois — jalon H8, et rien ne marche avant

Le jeu est livré **sans clé de vérification** : il démarre normalement, l'écran
affiche « mises à jour non configurées », et rien ne se télécharge. Dégradation
franche, même patron que `eos_credentials.gd` absent.

```bash
openssl genrsa -out candela_maj_privee.pem 4096
openssl rsa -in candela_maj_privee.pem -pubout -out candela_maj_publique.pem
```

1. **La publique** se recopie dans `update_manager.gd`, constante `CLE_PUBLIQUE`,
   en chaîne multiligne (`"""…"""`), les lignes `BEGIN`/`END` comprises. Elle est
   faite pour être publiée : elle est en clair dans le dépôt, c'est normal.
2. **La privée** devient le secret GitHub `CANDELA_MAJ_CLE_PRIVEE`
   (Settings → Secrets and variables → Actions). Elle ne va nulle part ailleurs :
   ni dans le dépôt, ni par mail, ni dans un message. Même règle que
   `CLIENT_SECRET` d'EOS, et même conséquence si elle fuite — on republie une
   paire, et les builds déjà installés cessent de se mettre à jour.

La chaîne `openssl` → `Crypto.verify()` de Godot a été **vérifiée en exécution**
(RSA-4096, SHA-256, PKCS#1 v1.5, signature détachée en base64) : une signature
produite par la commande ci-dessus est acceptée, un octet modifié dans le
manifeste est refusé.

## Publier une version complète

1. Monter `config/version` dans `project.godot`.
2. Si le fil a bougé, monter `Protocol.VERSION` — c'est un jugement, pas un
   calcul ; `tools/test_protocole.gd` ne fait que rappeler qu'il faut le porter.
3. Commiter, puis poser le tag : `git tag v0.2.0 && git push origin v0.2.0`.
4. La CI vérifie que le tag et `config/version` disent la même chose, passe
   **toutes** les suites, exporte Windows et macOS, fabrique le manifeste, le
   signe et publie.

Le jeu installé lit toujours la même adresse :
`…/releases/latest/download/manifeste.json`. GitHub la redirige vers la dernière
publication ; aucun jeu n'a jamais besoin de connaître un numéro de version pour
trouver la suivante.

## Publier un correctif léger

Godot 4.7 sait exporter un pack de correctif : il ne contient que les fichiers
qui ont changé.

```bash
# Le pack du socle publié, gardé de l'export précédent.
godot --headless --path . --export-pack "Windows Desktop" build/socle-0.1.0.pck
# Puis, après les modifications :
godot --headless --path . --export-patch "Windows Desktop" build/candela-0.1.1.pck \
      --patches build/socle-0.1.0.pck
```

Puis, dans le manifeste : `--pck build/candela-0.1.1.pck:0.1.0:0.1.0`. Les deux
versions sont l'intervalle de socles sur lesquels le correctif s'applique.
**Le cas normal est `socle_min == socle_max`** : élargir l'intervalle est la
seule façon de fabriquer un mélange que personne n'a jamais exécuté.

Un correctif est monté par `PatchLoader` au démarrage suivant, avant tout autre
autoload. Le jeu affiche alors « vous jouez en 0.1.1 (installé : 0.1.0, plus un
correctif) » : la version montrée est **celle du code qui s'exécute**, jamais
celle du fichier installé, sans quoi un rapport de bug désigne la mauvaise.

### Ce qu'un correctif ne peut pas changer — et ce n'est pas négociable

- **le moteur Godot** ni les modèles d'exportation ;
- **l'addon EOS** : une GDExtension charge une bibliothèque native déclarée au
  démarrage depuis `res://` ;
- **la liste des autoloads**, lue dans le `project.godot` du socle ;
- **`project.godot`** en général, y compris l'Input Map.

Tout cela demande un remplacement complet. Publier un correctif qui en a besoin
est un défaut de publication : le jeu ne peut pas le rattraper.

## Ce que le joueur voit

L'entrée **MISE À JOUR** de l'accueil. Selon le cas : « Vous avez la dernière
version », « Version 0.2.0 disponible — 90 Mo », une barre de progression, puis
« Prêt à installer ». Un seul bouton, jamais grisé : quand il n'y a rien à
proposer il disparaît, et une phrase prend sa place.

S'il manque une version pour jouer en ligne, une ligne orange le dit — et rien
d'autre ne change.

## Quand ça se passe mal

| Symptôme | Où regarder |
|---|---|
| Le jeu ne s'est pas relancé après l'installation | `user://maj/echange.log`, écrit par le script d'échange |
| Le jeu est revenu à la version précédente | Normal : le script remet l'ancienne installation en place si la nouvelle ne s'installe pas. L'ancienne est gardée sous `<installation>.ancien` jusqu'au premier démarrage réussi de la nouvelle |
| « Le correctif précédent a empêché le jeu de démarrer » | Le témoin `user://maj/en_essai` a survécu à un démarrage : le correctif a été mis en quarantaine (`*.suspect`) et le jeu est reparti sur son socle |
| macOS : « glissez Candela dans Applications » | Le jeu tourne depuis un emplacement temporaire en lecture seule (translocation). Ce n'est pas contournable depuis le jeu |
| Windows : « dossier où il n'a pas le droit d'écrire » | Installation sous `C:\Program Files\`. Déplacer le jeu dans un dossier personnel |
| Tout couper | Lancer avec `--sans-maj` : plus aucune vérification automatique |

## Ce qui n'a pas encore été éprouvé pour de vrai

À dire franchement plutôt qu'à laisser croire :

- **l'échange de bundle n'a jamais tourné sur une vraie machine.** Le script est
  vérifié par lecture (il attend la fermeture, garde l'ancienne installation,
  sait revenir en arrière) ; l'exécution réelle demande un jeu exporté, installé,
  et une version publiée. C'est un jalon humain ;
- **la première installation macOS reste non signée et non notarisée** (H4).
  Elle passe par « Ouvrir quand même » dans les Réglages Système. Les mises à
  jour suivantes, elles, ne repassent pas devant Gatekeeper ;
- **l'export macOS depuis un runner Linux** est écrit dans la CI mais n'a pas
  encore produit de `.app` ouvert sur un Mac.
