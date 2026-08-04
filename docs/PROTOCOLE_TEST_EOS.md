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

## Test à deux machines réelles

Ces trois bancs valident tout ce qui peut l'être depuis une seule machine —
c'est-à-dire tout sauf le franchissement de NAT. Pour cela, le protocole du
projet de validation reste valable : deux postes, deux connexions Internet
distinctes, relever `CONNECTION_TYPE` (DIRECT ou RELAYÉ), le RTT et la perte de
paquets. En jeu, ces trois valeurs sont lisibles dans le panneau **F3**.
