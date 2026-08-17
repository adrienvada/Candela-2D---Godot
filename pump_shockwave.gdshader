shader_type canvas_item;
// Non éclairé : l'anneau relit un tampon d'écran DÉJÀ éclairé et assombri.
// Le repasser dans l'éclairage 2D (ou le CanvasModulate noir de l'arène)
// éteindrait l'effet — même raison d'être que ghost_unshaded.gdshader.
render_mode unshaded;

// filter_linear SANS mipmap : demander des mipmaps sur hint_screen_texture
// impose de régénérer toute la chaîne à chaque copie du back buffer — un
// coût permanent pour un déplacement de quelques pixels qui n'en tire rien.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// Rayon courant de l'anneau et déplacement maximal, en PIXELS ; animés à
// chaque frame par pump_shockwave.gd.
uniform float radius_px = 0.0;
uniform float amplitude_px = 0.0;
// Demi-épaisseur de l'anneau, en pixels.
uniform float ring_half_px = 20.0;
// Demi-côté du quad porteur, en pixels. DOIT valoir PumpShockwave.QUAD_HALF :
// c'est lui qui reconvertit l'UV local (0..1) en distance monde.
uniform float quad_half_px = 128.0;

void fragment() {
	// Position du fragment par rapport au centre de l'onde, en pixels monde,
	// reconstruite depuis l'UV LOCAL du quad. Pourquoi pas un centre en
	// SCREEN_UV passé en uniform : les deux SubViewport rendent le même monde
	// avec deux caméras, le même point monde n'a donc pas le même SCREEN_UV à
	// gauche et à droite — un uniform unique serait faux dans l'une des vues.
	// L'UV local, lui, est identique partout. Les caméras étant à zoom 1.0 en
	// manche, un pixel monde vaut un pixel écran.
	vec2 local_px = (UV - vec2(0.5)) * 2.0 * quad_half_px;
	float dist = length(local_px);

	// Profil d'anneau : 1.0 pile sur le rayon, 0.0 à ring_half_px de part et
	// d'autre ; élevé au carré pour fondre les bords (pas de cassure nette).
	float band = 1.0 - min(abs(dist - radius_px) / ring_half_px, 1.0);
	band *= band;

	// Déplacement radial : on relit le tampon PLUS PRÈS du centre pour
	// l'afficher ici — l'air paraît comprimé puis poussé vers l'extérieur.
	// Hors de l'anneau band = 0 : lecture identité, strictement invisible.
	vec2 dir = local_px / max(dist, 0.001);
	vec2 offset_uv = dir * (band * amplitude_px) * SCREEN_PIXEL_SIZE;
	COLOR = texture(screen_texture, SCREEN_UV - offset_uv);
}
