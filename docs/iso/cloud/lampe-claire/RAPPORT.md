# Une lampe plus claire et plus pâle — essai `--lampe-claire` (session cloud « lampe-claire », Q40)

*28/09/2026, à partir de 02:05 (heure de Paris). Branche `claude/cloud-lampe-claire`, base `origin/integration-iso14`
(a30a407). **Rapport en cours : ceci est le plan, poussé avant tout code.***

## Le plan

1. **Qui lit la lumière de la torche** (établi dans le code, AVANT de coder — tableau ci-dessous, à compléter).
2. **L'endroit où agir** : la SORTIE des matériaux 3D du sol et des murs (`sol_iso.gdshader`, `mur_iso.gdshader`, et
   leurs jumeaux éclairés), après toute lecture de la lightmap. Une courbe d'affichage : identité sous un genou (le bord
   du cône et le noir ne bougent pas au bit), puis relevée vers la crème de l'halogène au cœur du cône, pondérée par la
   neutralité de la lumière lue (une fusée rouge ou une LED ambre gardent leur teinte). Rien d'autre ne change : ni la
   couleur de la `PointLight2D`, ni son énergie, ni sa texture, ni la matière 2D.
3. **La garde headless** : drapeau éteint ⇒ le shader et les uniformes identiques au bit ; la courbe est identité sous le
   genou, monotone, 0 → 0.
4. **Les chiffres** (Xvfb, photographe) : six cartes à 45° B et écran scindé — luminance du sol éclairé (médiane, 99ᵉ
   centile), teinte ; capteurs des dix classes au bord de la lumière ; éblouissement ; noir torches éteintes.
5. **La planche** : aujourd'hui / l'essai / illustrations à lampe, 1:1 et loupe ×3.

## Qui lit la lumière de la torche (première lecture, 02:25)

| lecteur | fichier | ce qu'il lit | touché par une courbe à la sortie du sol 3D ? |
|---|---|---|---|
| capteur du corps **adverse** | `capteur_corps.gd`, `capteur_adverse.gdshader` | sa propre sous-vue 2D (disque blanc, masque du sprite) : `max(R,G,B) × énergie ×4`, plafonné | **non** : autre sous-vue, autre shader, la 3D n'y entre pas |
| capteur de **son propre** corps | `capteur_local.gdshader` | idem, `LIGHT_COLOR × COLOR` | **non** |
| seuil Q32 (0,10) | `corps_iso.gdshader`, `voxel_catalogue.gd` | la luminance de `fiche × capteur` | **non** |
| éblouissement | `game_state._sources_eblouissantes`, `eblouissement.gd` | torche allumée, portée de l'arme, direction ; énergie relative pour la fusée | **non** : géométrie et énergie, aucun pixel |
| point noir de la lightmap (8/255) | `iso_lightmap.gdshaderinc` (`seuil_noir_2d`) | la luminance de la lightmap LUE | **non** : en amont de la courbe |
| point noir de la sortie 3D (`POINT_NOIR_ECRIT`) | `volume_masque.gdshaderinc` | ce que le sol et les murs ÉCRIVENT, recalculé, pour taire la fumée sur le noir | **identique par construction** si la courbe est l'identité sous le genou (≫ 8/255) |
| son | `AudioManager.set_player_torch` | allumée / éteinte | **non** |
