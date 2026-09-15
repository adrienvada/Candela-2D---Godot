# Boîte aux ordres — branche-signal `claude/reveil`

Branche-signal poussée par la session cloud « Fable 5.1 - CLOUD ISO UNRAILED » avec l'accord d'Adrien (15/09/2026 à 04:41 : « oui »). Elle ne porte que ce fichier et le dossier `briefs/` : aucun code, jamais fusionnée, écrite par la session cloud seule. La session locale « Concierge » la guette (`git fetch origin claude/reveil` toutes les minutes) et relaie chaque ordre nouveau par message inter-session, ce qui réveille la cible. Un ordre ne se relaie qu'une fois : la Concierge retient le dernier numéro relayé. Les ordres déjà relayés ne gardent ici que leur titre.

Format : `## ORDRE <numéro> — <JJ/MM HH:MM>` puis `RELAIS → « <adresse ListAgents de la cible> » : ` et le texte à transmettre mot pour mot, qui court jusqu'au titre de l'ordre suivant. Si l'adresse n'apparaît pas dans ListAgents, essayer le titre entre parenthèses, puis répondre « cible introuvable » avec la liste des noms visibles. La porteuse du suivi s'appelle « candela-2d-3b » dans ListAgents.

## ORDRE 1 — 15/09 04:49 (relayé 04:56)
## ORDRE 2 — 15/09 05:15 (relayé 05:18)
## ORDRE 3 — 15/09 05:15 (relayé 05:18)
## ORDRE 4 — 15/09 05:15 (relayé 05:18)
## ORDRE 5 — 15/09 05:15 (relayé 05:18)
## ORDRE 6 — 15/09 05:15 (relayé 05:18)
## ORDRE 7 — 15/09 05:35 (relais refusé par le classificateur de la Concierge ; remplacé par l'ordre 8)
## ORDRE 8 — 15/09 05:40 (non relayé : la Concierge attend une permission ; remplacé par l'ordre 9)
## ORDRE 9 — 15/09 08:30 (relayé 09:47)
## ORDRE 10 — 15/09 10:38 (relayé 10:37 ; ISO5 a répondu et s'est arrêtée proprement à 10:40, tête a5ac4b8)
## ORDRE 11 — 15/09 10:38 (cible introuvable ; remplacé par l'ordre 13)
## ORDRE 12 — 15/09 10:50 (relayé 10:45 ; Iso 1 Opus a accusé réception à 10:46 et fait ISO6)
## ORDRE 13 — 15/09 10:50 (envoyé 10:46 par mcp__ccd_session_mgmt__send_message ; la porteuse a republié à 10:48 et 10:50)
## ORDRE 14 — 15/09 11:00 (relayé 10:59 ; galerie publiée à 11:13, 46 captures ajoutées à 11:41, recadrées à 12:08)
## ORDRE 15 — 15/09 11:00 (relayé 10:59 ; accusé 11:00 ; f8681a5 à 12:04, b4858bf à 12:32 : chantier clos)
## ORDRE 16 — 15/09 11:00 (relayé 10:59 ; accusé 11:00, points d'étape 11:15 et 11:48, images 12:25, commit 27ddb1c à 12:42)
## ORDRE 17 — 15/09 11:20 (relayé 11:19 ; accusé par Beauté à 11:19)
## ORDRE 18 — 15/09 11:37 (relayé 11:37 ; accusé par Iso 1 à 11:38)
## ORDRE 19 — 15/09 11:43 (relayé 11:43 ; accusé par Iso 1 à 11:44, captures recadrées à 12:08, message de fin d'ISO6 à 12:12)
## ORDRE 20 — 15/09 12:05 (relayé 12:05 ; accusé par Gadgets à 12:06 ; b4858bf à 12:32)
## ORDRE 21 — 15/09 12:10 (relayé 12:09 ; Beauté a répondu à 12:10 : hachures d'encre au pied des murs)
## ORDRE 22 — 15/09 12:25 (relayé 12:23 ; accusé par Iso 1 à 12:24 ; planche des variantes prête à 12:44)
## ORDRE 23 — 15/09 12:30 (relayé 12:26 ; accusé par Beauté à 12:27)
## ORDRE 24 — 15/09 12:35 (relayé 12:33 ; accusé par Iso 1 à 12:34)
## ORDRE 25 — 15/09 12:50 (relayé 12:44 ; accusé par Beauté à 12:45)
## ORDRE 26 — 15/09 12:50 (relayé 12:44 ; la porteuse a republié v224 avec les synthèses 61, 64 et 65 à 12:49)

## ORDRE 27 — 15/09 12:50
RELAIS → « Iso 1 Opus » (titre : « Iso 1 Opus ») : Message de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 12:50. Ta planche des variantes et les soixante prises sont lues. Mes valeurs, choisies sur image. **Zoom ×1,8** par défaut : à ×1,8 la face du pilier, le corps et le cône se lisent enfin, en vue unique comme en scindé ; ×2,2 ne montre presque plus de carte, il reste accessible par --zoom=2.2. **Portée ×0,75** : le pistolet passe de 1,6 à 1,2, soit 307 px, neuf tuiles — mais comme un FACTEUR GLOBAL posé une seule fois, dans `portee_torche()` et `echelle_torche()` (réglage `facteur_portee` dans GameSettings, drapeau --torche=0.75, curseur de débogage), PAS dix valeurs réécrites : les classes vont de 1,0 (pompe) à 3,5 (arbalète) et cet écart est leur identité. **Demi-angle inchangé** : 35° pour le pistolet, chaque classe garde le sien, de 5° à 60°. L'ouverture est une identité de classe, les cookies sont cuits par arme et `test_torches` compare les angles aux fiches ; la claustrophobie vient du zoom et de la portée, et à ×1,8 avec 307 px le cône de 35° tient dans l'écran. Le jeu de cookies à 30° du banc ne devient pas un défaut ; ne le garde que s'il ne coûte rien. **Décalage vers la visée** : un quart de la hauteur visible, comme le brief, lissé et borné aux limites de carte. Killcam : son zoom dynamique part du zoom du duel. Lightmap : mesure seulement la taille des texels à ×1,8 (F3), sans relevé de cadence — Adrien les réserve au test final ; dis-le dans ton delta, la pleine résolution par défaut sera sa question. Ordre des fusions, inchangé : balle-sans-lumiere (b4858bf, Gadgets clos) dans iso2-vues si ce n'est pas déjà fait (ordre 24), puis iso2-vues dans TA branche iso8-claustro pour travailler sur la balle sans lumière ; iso7b-faces viendra sur mon mot après le commit final de Beauté. Étapes 2 à 4 du brief, un commit par étape, delta et hash à chaque commit, lot complet vert, ROADMAP dans le même commit. Accuse réception à « Fable 5.1 - CLOUD ISO UNRAILED » par SendMessage. Ne réponds pas à la Concierge.
