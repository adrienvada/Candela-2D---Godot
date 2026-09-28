#!/usr/bin/env python3
"""Le schéma des dix ombres propres (session cloud ombre-orientation, 2026-09-27).

    python3 docs/iso/cloud/ombre-orientation/schema_etoiles.py <dossier orient45> <sortie>

Écrit `etoiles.svg` : pour chaque classe, l'étoile de son occluder (relevée par le banc, repère du corps, J2 regardant
vers le haut), l'anneau lu (15 px) et, pour chacune des huit directions de la torche, les points de l'anneau que la
torche éclaire (rayons parallèles, le calcul de `ombre_compensee.gd`). Aucune donnée inventée : les polygones sont ceux
du journal.
"""
import json, math, os, sys

sys.path.insert(0, os.path.dirname(__file__))
from analyse_orientation import local, part_parallele, ORIENTS, NOMS_O, R_LU  # noqa: E402
from analyse_ombre import NOMS, ORDRE  # noqa: E402

THETA = {"face": 0, "diag_face_g": 45, "profil_g": 90, "diag_dos_g": 135, "dos": 180, "diag_dos_d": 225,
         "profil_d": 270, "diag_face_d": 315}


def main():
    src, dst = sys.argv[1], sys.argv[2]
    j = json.load(open(os.path.join(src, "journal.json")))
    polys = {}
    for p in j["prises"]:
        if p["mode"] == "etoile" and p["scene"] == "b10" and p["orientation"] == "profil_g" and not p.get("controle"):
            polys[p["classe"]] = local(p)
    classes = [c for c in ORDRE if c in polys]
    # Une vignette par classe et par orientation : 10 lignes × 8 colonnes. Dans le repère du corps, la visée est +x ;
    # on tourne de −90° pour que J2 regarde vers le haut. La torche vient de la direction « visée tournée de −θ ».
    cw, ch, ech = 92, 92, 1.45
    L = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" font-family="system-ui" font-size="11">' % (
        130 + cw * 8, 40 + ch * len(classes)), '<rect width="100%" height="100%" fill="#111"/>']
    for k, o in enumerate(ORIENTS):
        L.append('<text x="%d" y="16" fill="#bbb" text-anchor="middle">%s</text>' % (130 + cw * k + cw / 2, o))
    for i, c in enumerate(classes):
        y0 = 40 + ch * i
        L.append('<text x="8" y="%d" fill="#ddd">%s</text>' % (y0 + ch / 2 + 4, NOMS[c]))
        for k, o in enumerate(ORIENTS):
            cx, cy = 130 + cw * k + cw / 2, y0 + ch / 2

            def ecran(x, y):
                # repère du corps (visée +x) → écran (visée vers le haut)
                return cx + y * ech, cy - x * ech
            pts = " ".join("%.1f,%.1f" % ecran(x, y) for x, y in polys[c])
            L.append('<polygon points="%s" fill="#3a3a3a" stroke="#888" stroke-width="0.6"/>' % pts)
            # La torche : direction « vers la torche » dans le repère du corps = visée tournée de −θ (J2 vise
            # (vers la torche) tournée de +θ).
            th = -math.radians(THETA[o])
            w = (math.cos(th), math.sin(th))
            part = part_parallele(polys[c], w)
            for a in range(64):
                ang = 2 * math.pi * a / 64
                x, y = math.cos(ang) * R_LU, math.sin(ang) * R_LU
                # même règle que part_parallele, point par point
                lit = part_parallele_point(polys[c], w, (x, y))
                ex, ey = ecran(x, y)
                L.append('<circle cx="%.1f" cy="%.1f" r="1.3" fill="%s"/>' % (ex, ey, "#f5c542" if lit else "#402020"))
            tx, ty = ecran(w[0] * 30, w[1] * 30)
            L.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#f5c542" stroke-width="1" '
                     'stroke-dasharray="2 2"/>' % (tx, ty, *ecran(w[0] * 20, w[1] * 20)))
            L.append('<text x="%d" y="%d" fill="#aaa" font-size="9" text-anchor="middle">%.0f %%</text>' % (
                cx, y0 + ch - 4, 100 * part))
    L.append("</svg>")
    open(os.path.join(dst, "etoiles.svg"), "w").write("\n".join(L))


def part_parallele_point(poly, w, p):
    o = (w[1], -w[0])
    t, s = p[0] * o[0] + p[1] * o[1], p[0] * w[0] + p[1] * w[1]
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        ta, tb = a[0] * o[0] + a[1] * o[1], b[0] * o[0] + b[1] * o[1]
        if (ta <= t) == (tb <= t):
            continue
        sa, sb = a[0] * w[0] + a[1] * w[1], b[0] * w[0] + b[1] * w[1]
        if sa + (sb - sa) * (t - ta) / (tb - ta) > s:
            return False
    return True


if __name__ == "__main__":
    main()
