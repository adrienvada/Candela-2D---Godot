shader_type canvas_item;

// Les nappes de fumée de la fusée éclairante — chantier FUSÉE, étape FU2.1.
//
// **La densité de la fumée se lit dans la LUMINANCE de la planche, pas dans
// son alpha**, et c'est ce shader qui les réconcilie. La raison est pratique :
// une planche détourée arrive avec un alpha quasi BINAIRE — le détourage sait
// séparer le sujet du fond, il ne sait pas dire qu'une volute est plus mince
// qu'une autre. La finesse, elle, survit dans le gris. Sans cette ligne, la
// fumée serait un disque à bord franc, et le dégradé centre/bords — qui est
// toute la cachette de la mécanique — disparaîtrait.
//
// ⚠️ **La règle est IDEMPOTENTE, et c'est ce qui la rend sûre** : une planche
// correctement peinte (blanche, densité déjà dans l'alpha) a une luminance de
// 1, donc son alpha n'est pas touché. Le jour où une planche arrive dans les
// règles, rien ici ne la dégrade — on ne paie ce shader que quand on en a
// besoin. Aucune convention nouvelle n'est donc imposée à qui fournit un asset.
//
// La TEINTE, elle, ne vient jamais de la planche : elle vient des lumières du
// jeu et du `modulate` du sprite — même règle que les masques de lumière
// (`light_textures.gd`), pour qu'une fumée éclairée à la braise soit ambrée et
// la même fumée éclairée à la torche reste grise.

// Refonte roman graphique, lot 3 (2026-09-11) : la densité est ramenée à
// TROIS paliers (0,35 / 0,65 / 1,0, sous 0,15 rien). Une volute de planche a
// deux ou trois valeurs de gris, pas un dégradé — la part molle des volutes
// mesurait 0,45 et 0,24. Ce shader ne touche que les NAPPES, le dessin de la
// fumée ; le voile à trous (`fumee_fusee.gdshader`), qui porte l'occultation
// que le jeu lit, garde son dégradé.
void fragment() {
	vec4 planche = texture(TEXTURE, UV);
	float densite = max(planche.r, max(planche.g, planche.b));
	float palier = step(0.15, densite) * 0.35 + step(0.45, densite) * 0.30
		+ step(0.75, densite) * 0.35;
	COLOR = vec4(COLOR.rgb, COLOR.a * planche.a * palier);
}
