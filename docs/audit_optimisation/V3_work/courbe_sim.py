# Simulation exacte (doubles) de Charte._bezier_y : comptage des appels de fonction GDScript
# et erreur d'une table linéaire à N échantillons.
import math

NEWTON = 6
EPS = 1e-6
POINTS = {
    "ENTREE":     (0.16, 0.84, 0.24, 1.0),
    "SORTIE":     (0.55, 0.0, 0.85, 0.30),
    "REBOND":     (0.34, 1.56, 0.44, 1.0),
    "EXTINCTION": (0.16, 1.0, 0.3, 1.0),
}

def axe(t, a1, a2):
    u = 1.0 - t
    return 3.0*u*u*t*a1 + 3.0*u*t*t*a2 + t*t*t

def pente(t, a1, a2):
    u = 1.0 - t
    return 3.0*u*u*a1 + 6.0*u*t*(a2-a1) + 3.0*t*t*(1.0-a2)

def bezier_y(x, x1, y1, x2, y2):
    """renvoie (y, nb_appels_axe, nb_appels_pente, passes_newton, bissection?)"""
    calls_axe = 0
    calls_pente = 0
    t = x
    passes = 0
    for _ in range(NEWTON):
        ecart = axe(t, x1, x2) - x; calls_axe += 1
        passes += 1
        if abs(ecart) < EPS:
            y = axe(t, y1, y2); calls_axe += 1
            return y, calls_axe, calls_pente, passes, False
        p = pente(t, x1, x2); calls_pente += 1
        if abs(p) < EPS:
            break
        t -= ecart / p
    bas, haut = 0.0, 1.0
    t = x
    it = 0
    while haut - bas > EPS:
        calls_axe += 1
        it += 1
        if axe(t, x1, x2) < x:
            bas = t
        else:
            haut = t
        t = (bas + haut) * 0.5
    y = axe(t, y1, y2); calls_axe += 1
    return y, calls_axe, calls_pente, passes + it, True

def courbe(nom, t):
    t = min(max(t, 0.0), 1.0)
    return bezier_y(t, *POINTS[nom])

N = 2001
for nom in POINTS:
    tot_axe = tot_pente = 0
    maxcalls = 0
    fallback = 0
    hist = {}
    for i in range(N):
        t = i/(N-1)
        y, ca, cp, passes, bis = courbe(nom, t)
        tot_axe += ca; tot_pente += cp
        maxcalls = max(maxcalls, ca+cp)
        if bis: fallback += 1
        hist[passes] = hist.get(passes, 0) + 1
    moy = (tot_axe+tot_pente)/N
    print(f"{nom:10s} appels moyens _bezier_axe+_pente = {moy:5.2f} (axe {tot_axe/N:4.2f}, pente {tot_pente/N:4.2f}), max {maxcalls}, replis bissection {fallback}/{N}, passes {dict(sorted(hist.items()))}")

# erreur d'une table linéaire de K échantillons
def err_table(nom, K, fine=20001):
    # échantillons à t_i = i/(K-1)
    ys = [courbe(nom, i/(K-1))[0] for i in range(K)]
    worst = 0.0
    for j in range(fine):
        t = j/(fine-1)
        x = t*(K-1)
        i = min(int(x), K-2)
        f = x - i
        approx = ys[i]*(1-f) + ys[i+1]*f
        exact = courbe(nom, t)[0]
        worst = max(worst, abs(approx-exact))
    return worst

for nom in POINTS:
    print(nom, "erreur max table 257 :", "%.2e" % err_table(nom, 257), " table 129 :", "%.2e" % err_table(nom, 129), " table 513 :", "%.2e" % err_table(nom, 513))
