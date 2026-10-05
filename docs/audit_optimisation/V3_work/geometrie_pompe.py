import math
STEP = 10000.0/60.0           # px parcourus au premier (et seul) tick d'un plomb : 166.67
ANGLES = [0.0, 20.0, -20.0, 60.0, -60.0]
R_BALLE = 4.0
R_CORPS = 18.0                # polygone du joueur : 16-gone de rayon 18 (+ nez à 28 px, ignoré ici)
MUZZLE = 28.0

def dist_pt_seg(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx-ax, by-ay
    L2 = dx*dx+dy*dy
    t = max(0.0, min(1.0, ((px-ax)*dx+(py-ay)*dy)/L2))
    cx, cy = ax+t*dx, ay+t*dy
    return math.hypot(px-cx, py-cy)

print("== Corps : nombre de plombs qui touchent, selon la distance D entre les CENTRES (tireur visant le centre) ==")
prev = None
for D in range(36, 260):
    L = D - MUZZLE
    n = 0
    for a in ANGLES:
        th = math.radians(a)
        A = (0.0, 0.0)
        B = (STEP*math.cos(th), STEP*math.sin(th))
        if dist_pt_seg((L, 0.0), A, B) <= R_CORPS + R_BALLE:
            n += 1
    if n != prev:
        print(f"  D >= {D:3d} px (muzzle->centre {L:5.1f}) : {n} plomb(s)")
        prev = n

print("\n== Mur plat perpendiculaire à la visée : nombre de plombs qui touchent, selon la distance w muzzle->mur ==")
prev = None
for w in range(1, 200):
    n = 0
    for a in ANGLES:
        th = math.radians(a)
        c = math.cos(th)
        if c <= 0: continue
        s_hit = (w - R_BALLE)/c      # trajet du centre de la balle quand elle touche le mur
        if s_hit <= STEP + 1e-9:
            n += 1
    if n != prev:
        print(f"  w >= {w:3d} px : {n} plomb(s)")
        prev = n
