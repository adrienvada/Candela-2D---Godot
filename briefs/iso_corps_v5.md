# ISO CORPS — vague 5 : les dix corps sur le gabarit du DA (brief de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED », 15/09/2026 vers 05:25, sur mandat d'Adrien de 05:00)

Pour « ISO Corps Sonnet », branche `iso-corps`, ton worktree habituel. Ta vague 4 (ebde701) est fusionnée dans `iso2-vues` (26417a8) ; la zone de touche reste à 18 px (décision d'Adrien, 04:5x) : ton rayon de 24,4 px est une information, pas une contrainte.

## L'objectif

Adrien : « appuie-toi sur les créations de la session assets » et « un jeu qui s'approche de la qualité technique des visuels générés par Gemini ». ISO Assets a livré (vague 2, commit 033c35d de `claude/iso-assets-gemini-boards-4e8d33`) un gabarit de proportions « corps voxel épais, esprit Unrailed 2, trois vues » et les dix classes en deux frises de cinq (`docs/iso/planches_gemini/classes/planche_classes_synthese.jpg`), différenciées par carrure et par arme. Les armes de six classes récentes y sont une supposition tirée de `voxel_catalogue.gd` : ISO Assets t'a demandé de les confirmer — réponds-lui d'abord (une ligne par classe : nom de l'arme, forme, où elle se porte), elle corrigera sa frise.

## Ce que tu fais

1. **Mesure le gabarit** comme tu as mesuré la palette pour la vague 4 : rapport largeur/hauteur/profondeur par classe, carrure, taille de la tête, longueur de l'arme, ce qui fait la silhouette de chaque classe sur la frise à 52°. Écris les écarts avec le catalogue actuel (vague 4, ×1,6) dans ta ROADMAP avant de toucher.
2. **Vague 5 du catalogue** : chaque classe se rapproche de sa frise — carrure, tête (casque, capuche, masque : une ou deux boîtes de plus si elles font la silhouette), sac, arme conforme à ce que tu as confirmé — en gardant les règles : corps seul ≤ 17,5 px d'empreinte (couloir d'une tuile), hauteur debout 0,9400, postures et gestes inchangés (accroupi, enjambement, dix gestes de gadget), noir absolu, interface d'uniforms d'ISO2b intacte, `construire(slug, epaisseur)` intact. Publie l'empreinte et le rayon par classe comme en vague 4.
3. **La pâte** : « ISO7 Beauté Opus » écrit la fonction de style dans `iso_pate.gdshaderinc` et t'enverra le contrat de l'uniform `style` de `corps_iso.gdshader`. Branche-le quand son message arrive (contour d'encre, bandes de lumière), pas avant ; ta suite prouve que le noir absolu et l'équité tiennent avec la pâte (max 0 à lumière 0 ; même valeur pour les deux capteurs).
4. **La position de l'arme** : « ISO7 Gadgets et lumière Opus » a besoin, pour le flash de bouche en iso, d'un point d'arme par corps (position et direction de la bouche dans le repère du corps) ; expose-le dans `voxel_corps.gd` (une fonction, documentée) et dis-le-lui par message.
5. **Preuves et livraison** : suite verte, sabotage, planche `docs/iso/planche_corps_v5.png` (les dix corps sous lampe 0,8, en regard de la frise du DA, avant/après), ROADMAP et journal, lot complet vert, commit dont le message contient « vague 5 ». Delta à la session cloud. ISO5 fusionnera `iso-corps` une quatrième fois sur le mot de la session cloud.

Rappels : un seul lot à la fois sur le Mac (`pgrep -x Godot`, un message aux autres avant et après ; six sessions partagent la machine) ; tu ne fusionnes rien ; pas de push ; heure de Paris ; ne finis jamais un tour en attendant : Monitor.
