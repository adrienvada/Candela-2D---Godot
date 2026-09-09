class_name GadgetLeurre
extends GadgetBase

## Le leurre inerte — gadget de l'Illusionniste, chantier CLASSES, étape 15.
##
## ## Ce qu'il est, et pourquoi il n'a rien à inventer
##
## *« Il fait croire à un corps qui n'est pas là. Le leurre ne se distingue d'un
## joueur que trop tard. »*
##
## Dans ce jeu, on ne voit jamais l'homme : **on voit le trou qu'il fait dans la
## lumière.** Un leurre convaincant n'a donc pas à ressembler à un joueur — il
## doit faire *le même trou* et porter *la même silhouette*. C'est ce qu'il fait,
## littéralement : le disque d'occlusion de 18 px du joueur, et la texture de
## silhouette de la classe qui l'a posé.
##
## ⚠️ **Rien n'est peint pour lui, et c'est le point.** Un sprite de leurre
## dessiné à part serait un sprite de plus à tenir d'accord avec celui du
## joueur ; le jour où l'un des deux changerait, le leurre cesserait de tromper
## sans qu'une seule erreur ne se lève. Il emprunte l'asset du joueur, comme la
## torche fantôme emprunte le cookie de sa classe.
##
## ## Ce qu'il ne fait PAS
##
## Il ne bouge pas, n'éclaire pas, ne tire pas et ne fait aucun bruit. C'est un
## leurre **inerte** — le nom que le catalogue lui donne depuis le premier jour.
## Un leurre qui bougerait serait un second joueur à simuler et à répliquer ;
## celui-ci ne coûte rien au fil, parce qu'il ne fait rien.
##
## ## Une balle suffit
##
## Et c'est ce qui l'équilibre : le démasquer coûte un tir, donc un flash, donc
## sa propre position. L'Illusionniste ne gagne pas parce que le leurre survit —
## il gagne parce que l'autre a tiré.

## Le rayon du corps. **18 px, exactement celui du joueur** : `player.gd` écrit
## « 18.0 is exactly the player radius » à côté de son propre occluder. Un leurre
## qui découperait un trou d'une autre taille se démasquerait à l'ombre.
const RAYON_CORPS := 18.0


func _init() -> void:
	rayon = RAYON_CORPS
	# Un corps arrête une balle. C'est aussi la seule façon de le démasquer.
	arrete_les_balles = true
	# Une balle, et il tombe. Voir la note de tête : ce n'est pas une fragilité,
	# c'est le prix que l'adversaire paie pour savoir.
	pv = 1.0
	eblouit = false
	# Il regarde là où le poseur visait : on plante un leurre en le tournant vers
	# ce qu'on veut faire croire qu'il surveille.
	angle_pose = 0.0


## Le visuel : la SILHOUETTE de la classe du poseur, montée comme `player.gd`
## monte la sienne — un `Polygon2D` texturé, dimensionné par `empreinte_sprite()`.
##
## ⚠️ **La silhouette, jamais l'image peinte.** C'est ce que l'adversaire voit
## d'un vrai joueur (`visual_enemy` porte `t_sil`) ; lui montrer l'image peinte
## ferait du leurre la seule chose de l'arène qui se distingue d'un corps — soit
## exactement l'inverse du but.
##
## ⚠️ Et `empreinte_sprite()` plutôt que la largeur brute de la texture : c'est le
## piège que le chantier R a levé le 2026-08-25, recuire un asset
## redimensionnerait le corps.
func _monter_visuel() -> void:
	if classe_du_poseur == null:
		push_error("GadgetLeurre : aucune classe posée, pas de silhouette")
		return
	var chemin := "res://assets/sprites/%s_silhouette.png" % classe_du_poseur.slug()
	if not ResourceLoader.exists(chemin):
		# Aucun repli : un disque de secours redonnerait une forme plausible, et
		# une forme plausible se prend pour une intention.
		push_error("GadgetLeurre : silhouette absente — %s" % chemin)
		return
	var tex: Texture2D = load(chemin)

	# ⚠️ `Charte` et non `Player` : nommer `Player` depuis un gadget ferait
	# cesser `tools/test_classes.gd` de compiler — `player.gd` nomme un
	# autoload, et une suite en `--script` n'en a aucun. La fonction a déménagé
	# dans la charte pour cette raison ; voir sa note là-bas.
	var demi := Vector2(Charte.empreinte_sprite(tex.get_width()),
		Charte.empreinte_sprite(tex.get_height())) * 0.5
	var corps := Polygon2D.new()
	corps.name = "Visuel"
	corps.polygon = PackedVector2Array([
		Vector2(-demi.x, -demi.y), Vector2(demi.x, -demi.y),
		Vector2(demi.x, demi.y), Vector2(-demi.x, demi.y)])
	corps.texture = tex
	# ⚠️ **La teinte de l'adversaire, et elle n'est pas décorative.** La
	# silhouette est BLANCHE ; `Polygon2D.color` la multiplie, et `player.gd`
	# écrit pourquoi : *« `Charte.ADVERSAIRE` est calibrée en luminance pour
	# l'équité »*. Sans cette ligne le leurre sortait blanc sous la torche — plus
	# lumineux qu'un vrai corps, donc reconnaissable du premier coup d'œil, ce
	# qui est l'inverse exact de son métier. Constaté en capture.
	corps.color = Charte.ADVERSAIRE
	corps.uv = PackedVector2Array([
		Vector2.ZERO, Vector2(tex.get_width(), 0.0),
		Vector2(tex.get_width(), tex.get_height()), Vector2(0.0, tex.get_height())])
	# ⚠️ **Les trois couches à la fois**, là où un joueur en choisit une par vue.
	# Un leurre n'appartient à personne : s'il ne s'allumait que sur la couche des
	# ennemis, son poseur ne le verrait jamais et le planterait à l'aveugle ; s'il
	# ne s'allumait que sur celle du joueur local, l'adversaire ne le verrait pas
	# du tout et il ne tromperait personne.
	corps.light_mask = 1 | 2 | 4
	corps.z_index = 6
	add_child(corps)
