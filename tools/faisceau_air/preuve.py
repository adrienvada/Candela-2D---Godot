#!/usr/bin/env python3
"""LE RAYON DANS L'AIR, À L'IMAGE (Q41, session cloud « faisceau-air », 2026-09-28).

Lit les prises du plan `loupe-faisceau-air` (tools/loupe_faisceau_air.gd) et le journal du photographe, et rend, bloc par
bloc (adv, sien, s1, s2, eq-*) :
  1. LE NOIR : les pixels noirs (0,0,0) dans TOUTES les A du bloc (cinq prises sans rayon) ; la fuite d'une prise B est le
     nombre de ces pixels qu'elle allume (un canal > 0). Critère écrit d'avance : 0 pour chaque B. Les pixels où les A
     diffèrent entre elles (la scène qui bouge : corps, grain) sont l'ensemble INSTABLE, compté à part et exclu ;
  2. LE ZÉRO NON VIDE : combien de pixels noirs dans les A, dans tout l'écran et dans un carré de 300 px autour du cône ;
  3. LA DENSITÉ QUI SE LIT : B − A (le canal le plus fort, en /255), moyenné sur 15 × 15 px au milieu du cône et à son bord
     (points imprimés par le plan, lignes `FAISCEAU`), et la distribution de B − A sur les pixels que le rayon change ;
  4. PLUS CLAIR QUE SON SOL ? le plus clair du rayon (B) contre le plus clair du sol éclairé sans lui (A), dans le cône ;
et écrit, dans <sortie> : la carte du noir (rouge : fuite ; gris : pixel non noir dans les A), la différence ×8, et les
loupes ×3 (A et B) au milieu du cône, en JPEG.

    python3 tools/faisceau_air/preuve.py <dossier des prises> <journal> <sortie> [<étiquette>]

Sort 1 si une prise B allume un pixel noir, ou si un zéro est vide. numpy et Pillow requis."""
import glob, json, os, re, sys
import numpy as np
from PIL import Image

D, JOURNAL, S = sys.argv[1], sys.argv[2], sys.argv[3]
ETIQ = sys.argv[4] if len(sys.argv) > 4 else ""
ID = "loupe-faisceau-air"
os.makedirs(S, exist_ok=True)


def lire(suffixe):
    f = glob.glob(os.path.join(D, "*%s-%s.png" % (ID, suffixe)))
    return np.asarray(Image.open(f[0]).convert("RGB")).astype(np.int16) if f else None


points = {}
for ligne in open(JOURNAL, encoding="utf-8", errors="replace"):
    m = re.search(r"FAISCEAU %s-(\S+) lampe_de J(\d) vue (\d) lampe (-?\d+) (-?\d+) milieu (-?\d+) (-?\d+) bord (-?\d+) (-?\d+)"
                  % ID, ligne)
    if m:
        points.setdefault(m.group(1), []).append({"j": int(m.group(2)), "vue": int(m.group(3)),
            "lampe": (int(m.group(4)), int(m.group(5))), "milieu": (int(m.group(6)), int(m.group(7))),
            "bord": (int(m.group(8)), int(m.group(9)))})

blocs = sorted({os.path.basename(f).split(ID + "-")[1].rsplit("-", 1)[0]
                for f in glob.glob(os.path.join(D, "*%s-*.png" % ID))})
ok = True
rapport = {}


def patch(img, xy, r=7):
    x, y = xy
    h, w = img.shape[:2]
    return img[max(0, y - r):min(h, y + r + 1), max(0, x - r):min(w, x + r + 1)]


def loupe(img, xy, taille=(266, 150)):
    x, y = xy
    h, w = img.shape[:2]
    x0 = min(max(0, x - taille[0] // 2), w - taille[0])
    y0 = min(max(0, y - taille[1] // 2), h - taille[1])
    return Image.fromarray(img[y0:y0 + taille[1], x0:x0 + taille[0]].astype(np.uint8)).resize(
        (taille[0] * 3, taille[1] * 3), Image.NEAREST)


for bloc in blocs:
    A = [lire("%s-%s" % (bloc, s)) for s in ["a", "a1", "a2", "a3", "a4"]]
    A = [a for a in A if a is not None]
    Bs = sorted({os.path.basename(f).split("%s-%s-" % (ID, bloc))[1][:-4]
                 for f in glob.glob(os.path.join(D, "*%s-%s-b*.png" % (ID, bloc)))})
    if not A or not Bs:
        continue
    a0 = A[0]
    noir = np.all(np.stack([np.all(a == 0, axis=2) for a in A]), axis=0)
    instable = np.zeros(noir.shape, bool)
    for a in A[1:]:
        instable |= np.any(a != a0, axis=2)
    # dilaté d'un pixel
    d = instable.copy()
    d[1:] |= instable[:-1]; d[:-1] |= instable[1:]; d[:, 1:] |= instable[:, :-1]; d[:, :-1] |= instable[:, 1:]
    instable = d
    noir_stable = noir & ~instable
    h, w = noir.shape
    moities = [("fenêtre", slice(0, w))] if bloc not in ("s1", "s2") else [("J1 (gauche)", slice(0, w // 2)),
                                                                         ("J2 (droite)", slice(w // 2, w))]
    r = {"pixels_noirs_A": int(noir_stable.sum()), "instables": int(instable.sum()), "prises": {}}
    print("\n== %s %s : %d pixels noirs dans les %d A (hors instables), %d instables (A entre elles, dilaté 1 px)"
          % (ETIQ, bloc, noir_stable.sum(), len(A), instable.sum()))
    for nom, sl in moities:
        print("   %s : %d pixels noirs" % (nom, noir_stable[:, sl].sum()))
    for b_nom in Bs:
        B = lire("%s-%s" % (bloc, b_nom))
        diff = B - a0
        allume = np.any(B > 0, axis=2)
        fuite = noir_stable & allume
        change = np.any(np.abs(diff) > 0, axis=2) & ~instable
        gain = diff.max(axis=2)
        pr = {"fuite": int(fuite.sum()), "fuite_max": int(B[fuite].max()) if fuite.any() else 0,
              "pixels_changes": int(change.sum())}
        for nom, sl in moities:
            pr["fuite " + nom] = int(fuite[:, sl].sum())
        if change.any():
            g = gain[change]
            pr["gain_median"] = float(np.median(g)); pr["gain_p90"] = float(np.percentile(g, 90))
            pr["gain_max"] = int(g.max()); pr["gain_min"] = int(g.min())
            pr["plus_clairs_que_A"] = int((gain[change] > 0).sum())
            pr["plus_sombres_que_A"] = int((diff.min(axis=2)[change] < 0).sum())
            lum_b = B.max(axis=2)[change]; lum_a = a0.max(axis=2)
            # le sol le plus clair du cône sans le rayon : le max de A sur les pixels que le rayon change, dilatés de 20 px
            zone = change.copy()
            for _ in range(20):
                z = zone.copy(); z[1:] |= zone[:-1]; z[:-1] |= zone[1:]; z[:, 1:] |= zone[:, :-1]; z[:, :-1] |= zone[:, 1:]
                zone = z
            pr["max_B_rayon"] = int(lum_b.max()); pr["max_A_cone"] = int(lum_a[zone].max())
            # Le cœur et le bord du cône, lus sur l'image : parmi les pixels que le rayon change et que le sol éclaire (A ≥ 8),
            # le quart le plus clair du sol sans rayon (le cœur) et le quart le plus sombre (le bord). Les points projetés
            # (`FAISCEAU … bord`) tombaient hors du cône : il est plus étroit que le demi-angle de l'arme (la texture s'éteint).
            eclaire = change & (lum_a >= 8)
            if eclaire.sum() > 100:
                va = lum_a[eclaire]; dg = diff.max(axis=2)[eclaire]
                q1, q3 = np.percentile(va, 25), np.percentile(va, 75)
                pr["coeur"] = {"A": round(float(va[va >= q3].mean()), 1), "B-A": round(float(dg[va >= q3].mean()), 2)}
                pr["bord_image"] = {"A": round(float(va[va <= q1].mean()), 1), "B-A": round(float(dg[va <= q1].mean()), 2)}
        for pt in points.get("%s-%s" % (bloc, b_nom), []):
            for cle in ["milieu"]:
                xy = pt[cle]
                if 0 <= xy[0] < w and 0 <= xy[1] < h:
                    pb, pa = patch(B, xy), patch(a0, xy)
                    pr["J%d vue %d %s" % (pt["j"], pt["vue"], cle)] = {
                        "B-A": round(float((pb - pa).max(axis=2).mean()), 2), "A": round(float(pa.max(axis=2).mean()), 1),
                        "B": round(float(pb.max(axis=2).mean()), 1)}
        r["prises"][b_nom] = pr
        verdict = "✓" if pr["fuite"] == 0 else "✗"
        if pr["fuite"] != 0:
            ok = False
        print("   %s %s : fuite %d%s ; %d pixels changés, B−A médiane %s p90 %s max %s (min %s) ; %s"
              % (verdict, b_nom, pr["fuite"], (" (max %d/255)" % pr["fuite_max"]) if pr["fuite"] else "",
                 pr["pixels_changes"], pr.get("gain_median"), pr.get("gain_p90"), pr.get("gain_max"), pr.get("gain_min"),
                 " ; ".join("%s : B−A %s (A %s → B %s)" % (k, v["B-A"], v["A"], v["B"]) for k, v in pr.items()
                            if isinstance(v, dict) and "B" in v)))
        if "coeur" in pr:
            print("      cœur du cône (A %s) : B−A %s /255 ; bord du cône (A %s) : B−A %s /255"
                  % (pr["coeur"]["A"], pr["coeur"]["B-A"], pr["bord_image"]["A"], pr["bord_image"]["B-A"]))
        if "max_B_rayon" in pr:
            print("      le plus clair du rayon %d/255, le plus clair du sol du cône sans lui %d/255 (%s)"
                  % (pr["max_B_rayon"], pr["max_A_cone"], "pas plus clair" if pr["max_B_rayon"] <= pr["max_A_cone"]
                     else "PLUS CLAIR"))
        # Les images : la carte du noir, la différence ×8, les loupes ×3.
        carte = np.zeros_like(a0)
        carte[~noir_stable] = (60, 60, 60)
        carte[instable] = (0, 0, 90)
        carte[fuite] = (255, 0, 0)
        Image.fromarray(carte.astype(np.uint8)).save(os.path.join(S, "%s%s_%s_noir.jpg" % (ETIQ, bloc, b_nom)), quality=85)
        dd = np.clip(np.abs(diff) * 8, 0, 255)
        Image.fromarray(dd.astype(np.uint8)).save(os.path.join(S, "%s%s_%s_diffx8.jpg" % (ETIQ, bloc, b_nom)), quality=85)
        Image.fromarray(B.astype(np.uint8)).save(os.path.join(S, "%s%s_%s.jpg" % (ETIQ, bloc, b_nom)), quality=88)
        for pt in points.get("%s-%s" % (bloc, b_nom), []):
            loupe(B, pt["milieu"]).save(os.path.join(S, "%s%s_%s_loupe_J%d_v%d.jpg" % (ETIQ, bloc, b_nom, pt["j"], pt["vue"])),
                                        quality=88)
            if b_nom == "b":
                loupe(a0, pt["milieu"]).save(os.path.join(S, "%s%s_a_loupe_J%d_v%d.jpg" % (ETIQ, bloc, pt["j"], pt["vue"])),
                                             quality=88)
    Image.fromarray(a0.astype(np.uint8)).save(os.path.join(S, "%s%s_a.jpg" % (ETIQ, bloc)), quality=88)
    if noir_stable.sum() == 0:
        print("   ✗ le zéro est VIDE : aucun pixel noir dans les A de ce bloc — la fuite n'y est pas jugeable")
        if bloc != "sien":
            ok = False
    rapport[bloc] = r

json.dump(rapport, open(os.path.join(S, "%smesures.json" % ETIQ), "w"), ensure_ascii=False, indent=1)
print("\n%s" % ("✓ aucune prise du rayon n'allume un pixel noir" if ok else "✗ au moins une prise allume du noir, ou un zéro est vide"))
sys.exit(0 if ok else 1)
