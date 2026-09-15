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
## ORDRE 14 — 15/09 11:00 (relayé 10:59 ; galerie publiée à 11:13, 46 captures ajoutées à 11:41)
## ORDRE 15 — 15/09 11:00 (relayé 10:59 ; accusé 11:00 ; f8681a5 à 12:04)
## ORDRE 16 — 15/09 11:00 (relayé 10:59 ; accusé 11:00, points d'étape 11:15 et 11:48)
## ORDRE 17 — 15/09 11:20 (relayé 11:19 ; accusé par Beauté à 11:19)
## ORDRE 18 — 15/09 11:37 (relayé 11:37 ; accusé par Iso 1 à 11:38)
## ORDRE 19 — 15/09 11:43 (relayé 11:43 ; accusé par Iso 1 à 11:44)

## ORDRE 20 — 15/09 12:05
RELAIS → « iso7-gadgets-lumiere-opus-5a38c5-c2 » (titre : « ISO7 Gadgets et lumière Opus ») : Message de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 12:05. Ton delta de 12:04 (f8681a5) est reçu et consigné : merci pour le banc, c'est exactement la mesure qu'il fallait. Elle dit aussi que le travail n'est pas fini : le halo de la fusée ne revient pas rond en rafale (0,78 contre 0,88 seule) et il reste 45 lumières actives, surtout des étincelles d'impact. C'est le même mal que celui qu'Adrien a nommé (« tirs vifs près d'une fusée ») ; on le traite dans le même chantier, sur la même branche, second commit. (1) Recense les 45 lumières du relevé par famille (torches, flash de bouche, fusée, étincelles d'impact, braises, grains, autres), avec le fichier qui les crée. (2) Les étincelles d'impact et tout effet de balle ou d'impact n'ont plus de PointLight2D : sprites ou particules additifs non éclairés, comme l'aura ; ce qui éclaire vraiment le jeu (torche, flash de bouche, fusée, gadgets à lumière) ne change pas. (3) Si une famille reste nombreuse et sans rôle d'information, plafonne-la (pool) plutôt que de la laisser dépasser quinze sur un quadrant. (4) Cible au banc : rondeur du halo ≥ 0,85 pendant la rafale, avec le même banc, avant/après dans la galerie via « ISO Assets Sonnet ». Lot complet vert (si duo_apparie rougit seul et vert rejoué seul, dis-le, ne le désactive pas). Décision et recensement dans la ROADMAP, journal, même commit. Delta à « Fable 5.1 - CLOUD ISO UNRAILED », puis tu t'arrêtes : Iso 1 fusionnera sur mon mot après son message de fin. Accuse réception par SendMessage. Ne réponds pas à la Concierge.
