## Relevés de rendu de l'audit M — INSTRUMENT TEMPORAIRE, jamais commité.
##
## À chaque image mesurée (`image()`), pour la racine et chaque SubViewport : les infos de rendu du serveur
## (`RenderingServer.viewport_get_render_info`) — visible / ombre / canvas × objets / primitives / appels de dessin — et les compteurs
## globaux. En fin de mesure (`rapport()`) : le tableau des viewports (taille, mode de mise à jour, script), les familles, la liste des
## lumières 2D allumées (nom, ombre, taille, masques), les occulteurs, les particules.
extends RefCounted

var vues: Array = []
var rec: Dictionary = {}
var tot_obj: Array[int] = []
var tot_prim: Array[int] = []
var tot_dc: Array[int] = []
var dt_ms: Array[float] = []
var proc_ms: Array[float] = []
var phys_ms: Array[float] = []
var _t_prec := -1
var _arbre: SceneTree = null


func armer(arbre: SceneTree) -> void:
	_arbre = arbre
	vues.clear()
	rec.clear()
	var tous: Array = [arbre.root]
	for n in arbre.root.find_children("*", "SubViewport", true, false):
		tous.append(n)
	var k := 0
	for v in tous:
		var vp := v as Viewport
		var nom := String(vp.get_path()) if vp != arbre.root else "racine"
		if rec.has(nom):
			nom += "#%d" % k
		k += 1
		vues.append({"vp": vp, "rid": vp.get_viewport_rid(), "nom": nom})
		var r := {}
		for t in 3:
			for i in 3:
				r["%d_%d" % [t, i]] = []
		rec[nom] = r


## Une fois par image mesurée.
func image() -> void:
	var maintenant := Time.get_ticks_usec()
	if _t_prec >= 0:
		dt_ms.append((maintenant - _t_prec) / 1000.0)
		proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		tot_obj.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		tot_prim.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		tot_dc.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		for e in vues:
			var r: Dictionary = rec[e["nom"]]
			for t in 3:
				for i in 3:
					(r["%d_%d" % [t, i]] as Array).append(RenderingServer.viewport_get_render_info(e["rid"], t, i))
	_t_prec = maintenant


static func med(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := a.duplicate()
	t.sort()
	return float(t[t.size() / 2])


static func moy(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()


static func mini_(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var m := INF
	for x in a:
		m = minf(m, float(x))
	return m


static func maxi_(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m


func rapport(main: Node) -> String:
	var l: PackedStringArray = []
	l.append("=== [M] SONDE DE RENDU (%d images mesurées) ===" % dt_ms.size())
	if dt_ms.is_empty():
		return "\n".join(l)
	var reste := moy(dt_ms) - moy(proc_ms) - moy(phys_ms)
	l.append("[M] temps réel d'une image : moyenne %.1f ms, médiane %.1f, max %.1f" % [moy(dt_ms), med(dt_ms), maxi_(dt_ms)])
	l.append("[M] TIME_PROCESS (scripts+process, sans rendu) : moyenne %.2f ms · TIME_PHYSICS_PROCESS : moyenne %.2f ms · le reste (rendu, synchro) : %.1f ms (%.1f %% de l'image)"
		% [moy(proc_ms), moy(phys_ms), reste, 100.0 * reste / maxf(moy(dt_ms), 0.001)])
	l.append("[M] compteurs globaux du serveur de rendu par image (médiane / min / max) : appels de dessin %d / %d / %d · objets %d / %d / %d · primitives %d / %d / %d"
		% [int(med(tot_dc)), int(mini_(tot_dc)), int(maxi_(tot_dc)), int(med(tot_obj)), int(mini_(tot_obj)), int(maxi_(tot_obj)),
		int(med(tot_prim)), int(mini_(tot_prim)), int(maxi_(tot_prim))])
	l.append("[M] mémoire : vidéo %.1f Mo (textures %.1f, tampons %.1f) · statique %.1f Mo · nœuds %d · objets %d · ressources %d · orphelins %d" % [
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	l.append_array(_recensement(main))
	l.append_array(_tableau_des_vues())
	l.append_array(_lumieres_allumees())
	return "\n".join(l)


func _recensement(main: Node) -> PackedStringArray:
	var l: PackedStringArray = []
	var racine := _arbre.root
	var pl := 0
	var pl_on := 0
	var pl_ombre := 0
	var d2 := 0
	var l3 := 0
	var occ := 0
	var occ_pts := 0
	for n in racine.find_children("*", "Light2D", true, false):
		if n is PointLight2D:
			pl += 1
			if (n as PointLight2D).enabled and (n as PointLight2D).is_visible_in_tree():
				pl_on += 1
				if (n as PointLight2D).shadow_enabled:
					pl_ombre += 1
		else:
			d2 += 1
	for n in racine.find_children("*", "Light3D", true, false):
		if (n as Light3D).visible:
			l3 += 1
	for n in racine.find_children("*", "LightOccluder2D", true, false):
		occ += 1
		var o := (n as LightOccluder2D).occluder
		if o != null:
			occ_pts += o.polygon.size()
	var gpu := 0
	var cpu := 0
	for n in racine.find_children("*", "GPUParticles2D", true, false):
		if (n as GPUParticles2D).emitting:
			gpu += 1
	for n in racine.find_children("*", "GPUParticles3D", true, false):
		if (n as GPUParticles3D).emitting:
			gpu += 1
	for n in racine.find_children("*", "CPUParticles2D", true, false):
		if (n as CPUParticles2D).emitting:
			cpu += 1
	var ci := racine.find_children("*", "CanvasItem", true, false).size()
	var mi3 := racine.find_children("*", "MeshInstance3D", true, false).size()
	var mm3 := racine.find_children("*", "MultiMeshInstance3D", true, false).size()
	var part := 0
	if main != null and is_instance_valid(main):
		part = main.particle_pool.active_count()
	l.append("[M] recensement final : PointLight2D %d (allumées %d, dont à ombre %d) · autres Light2D %d · Light3D visibles %d · LightOccluder2D %d (%d sommets) · bassin de particules actives %d / %d · GPUParticles émettant %d · CPUParticles2D émettant %d · CanvasItem %d · MeshInstance3D %d · MultiMeshInstance3D %d · nœuds au total %d"
		% [pl, pl_on, pl_ombre, d2, l3, occ, occ_pts, part, ParticlePool.MAX_ACTIVE, gpu, cpu, ci, mi3, mm3, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	# Les effets d'écran, indépendants du matériel : combien de BackBufferCopy VISIBLES (une copie de tampon par usage — sur un GPU à tuiles,
	# chacune coupe la passe de rendu), et quels shaders de canvas VISIBLES (par fichier de shader), avec le plus grand rectangle visé.
	var bbc := 0
	var bbc_noms: PackedStringArray = []
	for n in racine.find_children("*", "BackBufferCopy", true, false):
		if (n as BackBufferCopy).is_visible_in_tree():
			bbc += 1
			bbc_noms.append(String((n as Node).name))
	var par_shader := {}
	for n in racine.find_children("*", "CanvasItem", true, false):
		var c := n as CanvasItem
		if c.material is ShaderMaterial and c.is_visible_in_tree() and c.modulate.a >= 0.007 and (c.material as ShaderMaterial).shader != null:
			var f := (c.material as ShaderMaterial).shader.resource_path.get_file()
			if f == "":
				f = "(shader sans fichier)"
			var aire := 0.0
			if c is Control:
				aire = (c as Control).size.x * (c as Control).size.y
			if not par_shader.has(f):
				par_shader[f] = [0, 0.0]
			par_shader[f][0] += 1
			par_shader[f][1] = maxf(par_shader[f][1], aire)
	var lignes_shaders: PackedStringArray = []
	for f in par_shader:
		lignes_shaders.append("%s ×%d (plus grand Control %.2f Mpx)" % [f, par_shader[f][0], par_shader[f][1] / 1e6])
	lignes_shaders.sort()
	l.append("[M] BackBufferCopy visibles : %d (%s)" % [bbc, ", ".join(bbc_noms)])
	l.append("[M] shaders de canvas visibles (CanvasItem avec ShaderMaterial) : " + " · ".join(lignes_shaders))
	return l


func _tableau_des_vues() -> PackedStringArray:
	var l: PackedStringArray = []
	l.append("[M] viewports (racine + SubViewport), infos de rendu du serveur par image (médiane sur les images mesurées) ; V = visible, O = ombre, C = canvas ; o/p/d = objets / primitives / appels de dessin")
	l.append("[M]   %-58s %-11s %-9s %-22s %6s %6s %6s %6s %6s %6s %6s %6s %6s" % ["viewport", "taille", "mode", "script", "Vo", "Vp", "Vd", "Oo", "Op", "Od", "Co", "Cp", "Cd"])
	var n_actifs := 0
	var px := 0
	for e in vues:
		var vp := e["vp"] as Viewport
		if not is_instance_valid(vp):
			continue
		var r: Dictionary = rec[e["nom"]]
		var mode := "-"
		var actif := true
		if vp is SubViewport:
			var m := (vp as SubViewport).render_target_update_mode
			mode = ["DISABLED", "ONCE", "VISIBLE", "PARENT", "ALWAYS"][clampi(m, 0, 4)]
			actif = m != SubViewport.UPDATE_DISABLED
		var sz := Vector2i(vp.get_visible_rect().size) if vp != _arbre.root else DisplayServer.window_get_size()
		if vp is SubViewport:
			sz = (vp as SubViewport).size
		var script_nom := ""
		var sc: Script = (vp as Node).get_script()
		if sc != null:
			script_nom = String(sc.get_global_name()) if String(sc.get_global_name()) != "" else sc.resource_path.get_file()
		if actif:
			n_actifs += 1
			px += sz.x * sz.y
		l.append("[M]   %-58s %-11s %-9s %-22s %6d %6d %6d %6d %6d %6d %6d %6d %6d" % [String(e["nom"]).right(58), "%d×%d" % [sz.x, sz.y], mode, script_nom,
			int(med(r["0_0"])), int(med(r["0_1"])), int(med(r["0_2"])), int(med(r["1_0"])), int(med(r["1_1"])), int(med(r["1_2"])),
			int(med(r["2_0"])), int(med(r["2_1"])), int(med(r["2_2"]))])
	l.append("[M] viewports recensés : %d, dont qui rendent (mode ≠ DISABLED) : %d, pour %.2f Mpx de surface de rendu cumulée (racine comprise)" % [vues.size(), n_actifs, px / 1e6])
	var fam := {}
	for e in vues:
		var vp := e["vp"] as Viewport
		if not is_instance_valid(vp):
			continue
		var sc: Script = (vp as Node).get_script()
		var cle := "racine" if vp == _arbre.root else (String(sc.get_global_name()) if sc != null and String(sc.get_global_name()) != "" else ("SubViewport:" + String((vp as Node).name).rstrip("0123456789@")))
		var actif := true
		var sz := Vector2i(vp.get_visible_rect().size)
		if vp is SubViewport:
			actif = (vp as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED
			sz = (vp as SubViewport).size
		if not fam.has(cle):
			fam[cle] = [0, 0, 0]
		fam[cle][0] += 1
		if actif:
			fam[cle][1] += 1
			fam[cle][2] += sz.x * sz.y
	for cle in fam:
		l.append("[M]   famille %-30s : %d viewports, %d rendent, %.3f Mpx" % [cle, fam[cle][0], fam[cle][1], fam[cle][2] / 1e6])
	return l


## Les PointLight2D allumées : de quoi dire « 2 halos en duel, dont 1 sans récepteur », « 7-8 halos + plafonniers en solo ».
func _lumieres_allumees() -> PackedStringArray:
	var l: PackedStringArray = []
	l.append("[M] PointLight2D allumées et visibles (nom · parent · ombre · taille de texture × échelle · énergie · masque d'éclairage · masque d'ombre) :")
	var racine := _arbre.root
	var n_tot := 0
	for n in racine.find_children("*", "PointLight2D", true, false):
		var p := n as PointLight2D
		if not (p.enabled and p.is_visible_in_tree()):
			continue
		n_tot += 1
		var taille := 0.0
		if p.texture != null:
			taille = float(p.texture.get_width()) * p.texture_scale
		var parent := String(p.get_parent().name) if p.get_parent() != null else "?"
		l.append("[M]    %-28s %-26s ombre=%s %5.0f px  E=%.2f  éclaire=%d  ombre_masque=%d" % [String(p.name).left(28), parent.left(26),
			"oui" if p.shadow_enabled else "non", taille, p.energy, p.range_item_cull_mask, p.shadow_item_cull_mask])
	l.append("[M]    (%d lumières listées)" % n_tot)
	return l
