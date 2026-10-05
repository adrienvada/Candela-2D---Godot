#!/usr/bin/env python3
"""Fabrique un « arbre de variante » : un projet Godot fait de liens symboliques vers le worktree (jamais modifié), sauf quelques fichiers
RETOUCHÉS, copiés en vrai et patchés par remplacement de texte exact. Le patch est écrit en clair dans <dest>.diff (le rapport le cite).

Usage : faire_arbre.py <dest> <nom de la retouche>[,<nom>…]
Retouches connues :
  plancher_flou    brouillage_vue.gd : `maj()` traite un éblouissement <= 0,0601 comme 0 (le flou, sa copie de tampon et le halo s'éteignent)
  plancher_voile   ui.gd : `_poser_voile()` traite un niveau <= 0,0601 comme 0 ET pose `rect.modulate.a = 0` (un item de modulation < 0,007 est
                   écarté du dessin par le moteur : le ColorRect garde sa place dans le conteneur — voir le piège de `_forger_voile` —, mais ne
                   se rastérise plus)
"""
import difflib
import os
import pathlib
import shutil
import sys

WT = pathlib.Path("/home/user/Candela-2D---Godot/.claude/worktrees/agent-a26bf5b2f4d2b80a3")
dest = pathlib.Path(sys.argv[1])
noms = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] else []

RETOUCHES = {
    "plancher_flou": ("brouillage_vue.gd", [(
        "\tvar dazzle := float(regardeur.get(\"dazzle_amount\"))\n\tvar vue := get_viewport()\n",
        "\tvar dazzle := float(regardeur.get(\"dazzle_amount\"))\n"
        "\t# RETOUCHE DE MESURE (audit M, plancher_flou) : le plancher de la rétrodiffusion de sa propre torche (0,06) vaut 0 ici.\n"
        "\tif dazzle <= 0.0601:\n\t\tdazzle = 0.0\n"
        "\tvar vue := get_viewport()\n")]),
    "plancher_voile": ("ui.gd", [(
        "\t\tniveau = clampf(float(victime.dazzle_amount), 0.0, 1.0)\n",
        "\t\tniveau = clampf(float(victime.dazzle_amount), 0.0, 1.0)\n"
        "\t# RETOUCHE DE MESURE (audit M, plancher_voile) : un niveau au plancher de la rétrodiffusion (0,06) vaut 0, et le ColorRect\n"
        "\t# n'est plus dessiné (modulate.a = 0 : le moteur écarte l'item, mais il garde sa place dans le HBoxContainer).\n"
        "\tvar au_repos := niveau <= 0.0601\n"
        "\trect.modulate.a = 0.0 if au_repos else 1.0\n"
        "\tif au_repos:\n\t\tniveau = 0.0\n")]),
    "plancher_voile_quad": ("ui.gd", [(
        "\t\tniveau = clampf(float(victime.dazzle_amount), 0.0, 1.0)\n",
        "\t\tniveau = clampf(float(victime.dazzle_amount), 0.0, 1.0)\n"
        "\t# RETOUCHE DE MESURE (audit M, plancher_voile_quad) : un niveau au plancher de la rétrodiffusion (0,06) vaut 0 ; le voile reste\n"
        "\t# DESSINÉ (le quad plein écran, shader calme à niveau 0) — la lecture de V8 : « corps calme moins quad vide ».\n"
        "\tif niveau <= 0.0601:\n\t\tniveau = 0.0\n")]),
    "garde_theme": ("ui.gd", [
        ('\tnetwork_status_label.add_theme_color_override("font_color", tint)\n',
         '\t_couleur_si_change(network_status_label, "font_color", tint)\n'),
        ('\tping_label.add_theme_color_override("font_color", tint)\n',
         '\t_couleur_si_change(ping_label, "font_color", tint)\n'),
        ('\tlbl_f.add_theme_color_override("font_color",\n\t\tCOLOR_LUMIERE if n > 0 else COLOR_DIM)\n',
         '\t_couleur_si_change(lbl_f, "font_color",\n\t\tCOLOR_LUMIERE if n > 0 else COLOR_DIM)\n'),
        ('\tlbl_g.add_theme_color_override("font_color",\n\t\tCOLOR_LUMIERE if vif else COLOR_DIM)\n',
         '\t_couleur_si_change(lbl_g, "font_color",\n\t\tCOLOR_LUMIERE if vif else COLOR_DIM)\n'),
        ('\t\tpanel.add_theme_stylebox_override("panel", _plaques_de_cartouche(panel, active, player_color))\n\t\tvar hb := panel.get_child(0).get_child(0)\n',
         '\t\t_style_si_change(panel, "panel", _plaques_de_cartouche(panel, active, player_color))\n\t\tvar hb := panel.get_child(0).get_child(0)\n'),
        ('\t\tlb.add_theme_color_override("font_color",\n\t\t\tCOLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)\n',
         '\t\t_couleur_si_change(lb, "font_color",\n\t\t\tCOLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)\n'),
        ('\tpanel.add_theme_stylebox_override("panel", _plaques_de_cartouche(panel, active, player_color))\n\tvar marge := panel.get_child(0)\n',
         '\t_style_si_change(panel, "panel", _plaques_de_cartouche(panel, active, player_color))\n\tvar marge := panel.get_child(0)\n'),
        ('\t\tlabel.add_theme_color_override("font_color",\n\t\t\tCOLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)\n\tvar icon: TextureRect',
         '\t\t_couleur_si_change(label, "font_color",\n\t\t\tCOLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)\n\tvar icon: TextureRect'),
        ('func _plaques_de_cartouche(panel: PanelContainer, active: bool, player_color: Color) -> StyleBox:\n',
         '## RETOUCHE DE MESURE (audit M, garde_theme ; V2 B1 / HUD-02) : lecture avant écriture. Une surcharge de thème écrite avec la valeur\n'
         '## qu\'elle porte déjà notifie quand même le nœud (refaçonnage, tri différé du conteneur) : on ne l\'écrit que si elle change.\n'
         'func _couleur_si_change(c: Control, nom: StringName, v: Color) -> void:\n'
         '\tif c.has_theme_color_override(nom) and c.get_theme_color(nom) == v:\n\t\treturn\n'
         '\tc.add_theme_color_override(nom, v)\n\n\n'
         'func _style_si_change(c: Control, nom: StringName, s: StyleBox) -> void:\n'
         '\tif c.has_theme_stylebox_override(nom) and c.get_theme_stylebox(nom) == s:\n\t\treturn\n'
         '\tc.add_theme_stylebox_override(nom, s)\n\n\n'
         'func _plaques_de_cartouche(panel: PanelContainer, active: bool, player_color: Color) -> StyleBox:\n'),
    ]),
}

if dest.exists():
    shutil.rmtree(dest)
dest.mkdir(parents=True)
retouches = {}
for n in noms:
    if n not in RETOUCHES:
        sys.exit("retouche inconnue : %s" % n)
    f, subs = RETOUCHES[n]
    retouches.setdefault(f, []).extend(subs)

for e in sorted(os.listdir(WT)):
    if e in (".git", ".claude", ".github") or e in retouches:
        continue
    os.symlink(WT / e, dest / e)

diffs = []
for f, subs in retouches.items():
    src = (WT / f).read_text(encoding="utf-8")
    out = src
    for avant, apres in subs:
        if out.count(avant) != 1:
            sys.exit("✗ %s : « %s » trouvé %d fois" % (f, avant[:50].strip(), out.count(avant)))
        out = out.replace(avant, apres)
    (dest / f).write_text(out, encoding="utf-8")
    diffs.append("".join(difflib.unified_diff(src.splitlines(True), out.splitlines(True), "a/" + f, "b/" + f, n=2)))
pathlib.Path(str(dest) + ".diff").write_text("\n".join(diffs), encoding="utf-8")
print("arbre %s prêt (retouches : %s)" % (dest, ", ".join(noms) if noms else "aucune"))
print("\n".join(diffs))
