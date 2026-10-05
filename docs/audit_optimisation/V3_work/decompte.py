# Décompte de l'image d'impact d'une volée de pompe : multiplicités PROUVÉES (comptage), coûts unitaires ESTIMÉS (µs).
# (bas, haut) en microsecondes. Aucune mesure : tout coût unitaire est un raisonnement sur Godot 4.x, voir V_V3.md §4.
U = {
  "son":            (80, 250),   # un son positionnel (play_sfx_2d + _annoncer + liseré + voix), AUD-03
  "particule":      (20, 50),    # emit() d'une particule, tout compris (écritures + redessin différé), JOU-01
  "advance_part":   (4, 8),      # advance() d'une particule neuve pour l'image courante, JOU-03/04
  "physique_part":  (2, 6),      # première intégration + synchro d'un corps neuf (à mesurer)
  "eclat_noeud":    (30, 60),    # WallImpact : new + set_script + setup(exists+load) + add_child + _ready
  "eclat_plafond":  (100, 250),  # + éviction au plafond (2 tris de groupe + boucle de 90)
  "tache_noeud":    (60, 120),   # BloodStain : idem + ShaderMaterial.new + exists x2 + load x2
  "tache_plafond":  (120, 250),  # + éviction au plafond (2 tris + boucle de 120)
  "copie_j2":       (40, 80),    # _create_p2_duplicate : duplicate() + 2-6 set + add_child
  "draws3":         (10, 25),    # 3 _draw par trace (original, J2, peinture) - 2 pour un éclat, ~4-10 chacun pour une tache
  "copie_peinture": (104, 208),  # iso : _copier (duplicate + get_property_list ~70 dicts) + _arrivee
  "fondu":          (15, 30),    # _fade_and_destroy : create_tween + 2 animer + chain + callback
  "nombre":         (150, 600),  # _spawn_damage_number (Label + FontVariation neuf + 5 tweeners) - JOU-05, NON VÉRIFIÉ ici
  "degats":         (71, 176),   # take_damage + rpc_update_hp : rumble, camera_hit_kick, noter_pv_perdus, hit_light, vignette, low_health, RPC
  "maths":          (5, 10),     # _hit_player : falloff
  "curseur":        (2, 4),
}
def add(a, b): return (a[0]+b[0], a[1]+b[1])
def mul(a, n): return (a[0]*n, a[1]*n)
def ms(t): return f"{t[0]/1000:.2f}-{t[1]/1000:.2f}"

def mur(n, iso=True, plafond=False):
    lignes = []
    lignes.append(("sons play_wall_impact", n, mul(U["son"], n)))
    lignes.append(("curseur eclats_impact", n, mul(U["curseur"], n)))
    lignes.append((f"{12*n} etincelles (emit SPARK)", 12*n, mul(U["particule"], 12*n)))
    lignes.append(("WallImpact (noeud+setup)", n, mul(U["eclat_noeud"], n)))
    lignes.append(("copie J2 differee", n, mul(U["copie_j2"], n)))
    lignes.append(("_draw x2-3", n, mul((6, 15), n)))
    if iso:
        lignes.append(("copie peinture iso", n, mul(U["copie_peinture"], n)))
    lignes.append(("fondu de balle", n, mul(U["fondu"], n)))
    lignes.append(("advance des neuves", 12*n, mul(U["advance_part"], 12*n)))
    lignes.append(("physique des neuves", 12*n, mul(U["physique_part"], 12*n)))
    if plafond:
        lignes.append(("eviction au plafond (90)", n, mul(U["eclat_plafond"], n)))
    return lignes

def corps(n, iso=True, plafond=False):
    lignes = []
    lignes.append(("sons play_hit + play_breath_hit", 2*n, mul(U["son"], 2*n)))
    lignes.append(("curseurs", 2*n, mul(U["curseur"], 2*n)))
    lignes.append((f"{25*n} gouttes (emit BLOOD 15+10)", 25*n, mul(U["particule"], 25*n)))
    lignes.append(("BloodStain x2 (noeud+setup)", 2*n, mul(U["tache_noeud"], 2*n)))
    lignes.append(("copie J2 differee", 2*n, mul(U["copie_j2"], 2*n)))
    lignes.append(("_draw x3", 2*n, mul((12, 30), 2*n)))
    if iso:
        lignes.append(("copie peinture iso", 2*n, mul(U["copie_peinture"], 2*n)))
    lignes.append(("chiffre de degats (JOU-05, non verifie)", n, mul(U["nombre"], n)))
    lignes.append(("take_damage + rpc_update_hp", n, mul(U["degats"], n)))
    lignes.append(("_hit_player maths", n, mul(U["maths"], n)))
    lignes.append(("fondu de balle", n, mul(U["fondu"], n)))
    lignes.append(("advance des neuves", 25*n, mul(U["advance_part"], 25*n)))
    lignes.append(("physique des neuves", 25*n, mul(U["physique_part"], 25*n)))
    if plafond:
        lignes.append(("eviction au plafond (120)", 2*n, mul(U["tache_plafond"], 2*n)))
    return lignes

def total(l):
    t = (0, 0)
    for _, _, c in l: t = add(t, c)
    return t

for titre, f, args in [
    ("MUR 5 plombs, iso, sans plafond", mur, (5, True, False)),
    ("MUR 5 plombs, iso, au plafond", mur, (5, True, True)),
    ("MUR 5 plombs, 2D (sans peinture iso), sans plafond", mur, (5, False, False)),
    ("MUR 3 plombs, iso, sans plafond", mur, (3, True, False)),
    ("MUR 1 plomb, iso, sans plafond", mur, (1, True, False)),
    ("CORPS 1 plomb, iso, sans plafond", corps, (1, True, False)),
    ("CORPS 1 plomb, iso, au plafond", corps, (1, True, True)),
    ("CORPS 1 plomb, 2D, sans plafond", corps, (1, False, False)),
    ("CORPS 3 plombs, iso, sans plafond", corps, (3, True, False)),
    ("CORPS 5 plombs (contact), iso, sans plafond", corps, (5, True, False)),
]:
    L = f(*args)
    t = total(L)
    print(f"{titre:55s} {ms(t)} ms")

print()
for titre, f, args in [("MUR 5 plombs iso", mur, (5, True, False)), ("CORPS 1 plomb iso", corps, (1, True, False))]:
    L = f(*args)
    t = total(L)
    print(titre)
    for nom, n, c in L:
        print(f"   {nom:45s} x{n:<4d} {ms(c):>12s} ms   ({c[0]/t[0]*100:4.1f} % / {c[1]/t[1]*100:4.1f} %)")
    print("   TOTAL", ms(t))
