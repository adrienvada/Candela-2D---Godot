// Le disque du capteur d'un OBJET DEBOUT (ISO4, `CapteurCorps` créé pour un gadget ou une fusée posée).
//
// ⚠️ **Miroir de la lumière par défaut du moteur**, celle que prennent les sprites des gadgets
// (`GadgetBase._poser_sprite` : aucun matériau, `light_mask` du décor) — et non la courbe du sprite
// ennemi (`capteur_adverse.gdshader`, ×4 puis plafond) ni l'aplat du joueur (`capteur_local`). Un objet
// posé reçoit la lumière comme le décor : son voxel la reçoit de même.
//
// Seule différence : « lumière seule », comme les deux autres disques — zéro sans lumière, quel que
// soit le `CanvasModulate` de l'arène (13 à 17/255 mesurés au banc ISO2 sans ce mode).
shader_type canvas_item;
render_mode light_only;
