// UN GRAIN DE POUDRE QUI LUIT, dans la vue iso — chantier « Gadgets en volume », GV2 (2026-10-01, à l'essai sous
// `--nappes-voxels`, éteint par défaut). Adrien, Q70 (2026-09-30 : « oui ») : « les traces de poudre en grains ».
//
// Une trace de la poudre de contact (`gadget_poudre.gd`, `nouvelle_trace` : un trait de 12 × 3 px qui luit vert phosphore,
// non éclairé et ADDITIF, et s'éteint en huit secondes) devient trois petits cubes alignés sur elle (`IsoVolumes._suivre_traces`,
// un `MultiMesh` pour toutes les traces, la couleur et l'éclat de chaque trace dans la couleur de son instance). Ce qu'elle
// était en 2D, elle le reste : une LUEUR — elle s'ajoute à ce qui est dessous, de sa couleur à son éclat rendu (son fondu, la
// charge des pieds), et rien d'autre ; éteinte (éclat 0), elle n'ajoute rien. Les deux joueurs la voient (Adrien,
// 2026-09-11 : l'intrus voit ses pas et sait qu'il est repéré) : un seul maillage, sur le calque commun. Le modelé d'un cube :
// le dessus plein, les deux côtés vus un peu moins (0,8 et 0,62, ceux des nuages), à gauche et à droite de l'écran de la
// caméra qui dessine — le grain se lit comme un cube, pas comme une tache.
//
// En valeurs affichées, comme les lueurs (`halo_iso.gdshaderinc`) : le spatial ne convertit pas sous `gl_compatibility`.
// Non éclairé, additif, profondeur lue (un mur le cache), jamais écrite ; aucune `Light3D`.
shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

varying flat vec3 v_couleur;

void vertex() {
	// La normale de la face dans le monde (l'instance est tournée autour de la verticale et mise à l'échelle par axe : une
	// face de la boîte garde son axe).
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float face = 1.0;
	if (n.y < 0.5) {
		float cote = dot(n, INV_VIEW_MATRIX[0].xyz);
		face = cote > 0.3 ? 0.62 : (cote < -0.3 ? 0.8 : 0.71);
	}
	v_couleur = COLOR.rgb * clamp(COLOR.a, 0.0, 1.0) * face;
}

void fragment() {
	ALBEDO = v_couleur;
	// Écrite, l'opacité fait passer le grain par le rendu des transparents (après les volumes), et l'addition est entière.
	ALPHA = 1.0;
}
