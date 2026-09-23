"""ISO12 v27 — l'analyse de la recette du relief normalisé (banc `--v27`).

Usage : python3 analyse_v27.py JOURNAL_DU_BANC DOSSIER_DES_CAPTURES DOSSIER_DE_SORTIE

Chaque cadrage du banc (`BANC_LUMIERE3D v27 cadrage=… variante=…`) porte cinq prises au plus : `reference2d` (la vue d'ISO11,
lumière 3D éteinte), `masque` (blanc là où L2D > 0), `sans_ombres`, `ombres`, et pour le cumul `sabotage` (bride coupée).
Pour chaque prise 3D, contre la référence 2D, PIL seul, tous les pixels :

- **ROUGE** — lumineux en 3D (luminance > 6) là où le masque est noir ET la 2D invisible (≤ 8). Il en faut zéro. La ligne de
  séparation de l'écran scindé (±4 px au centre) est comptée à part. **Le sabotage doit, lui, faire monter le rouge** : un
  contrôle qui resterait à zéro bride coupée ne mesurerait rien.
- **(a)** — le rapport des luminances BRUTES 3D / 2D, sommées sur les pixels visibles en 2D : image entière, et dans une
  fenêtre de 200×112 autour de chaque ancre (la zone exacte d'une loupe ×4). Cible 1,0 ± 0,15.
  ⚠️ **Brut, et non normalisé chacun sur son maximum** comme au lot 0 ter : la v27 rend `albédo × L2D × R` et la 2D
  `albédo × L2D`, donc le rapport brut EST R. Normaliser chaque image sur son maximum ferait dépendre (a) du pixel le plus
  chaud de la 3D — une face écrêtée à 1,66 dégonflerait tout le reste de 40 % et un sol parfait lirait 0,6.
- **(b)** — parmi les pixels où la 2D normalisée (sur le maximum de la 2D) est sous 0,15, la part où la 3D, sur la MÊME
  échelle, dépasse 0,25. Cible < 1 %. Les pixels noirs dans les deux images sont hors population : ils ne diraient rien et
  dilueraient tout. La population est imprimée à côté de la part.
- **BLANCS** — pixels dont les trois canaux sont ≥ 250, 3D contre 2D (la 2D en avait 14 sur le cadrage de la fusée).
- **TEINTE et SATURATION** autour de chaque fusée (fenêtre de 120 px), sur les pixels visibles en 2D, 3D contre 2D.
- **LE SEUIL AU POINT NOIR, DANS LES DEUX SENS** (arbitrage de la session cloud, 2026-09-23, 00:30) — « moins » : visible en 2D
  (> 8) et noir en 3D (≤ 2), rapporté aux pixels visibles en 2D ; attendu ≈ 0 sans ombres, et c'est aussi LA PREUVE INVERSE
  sous ombres, cible < 1 %. « plus » : noir en 2D (≤ 8) et lumineux en 3D (> 12), rapporté aux pixels noirs en 2D ; cible
  < 0,01 %. Ni masque ni séparation : ce sont les deux écarts qu'un seuil mal posé produirait.
- **L'IDENTITÉ** (principe d'identité, session cloud, 2026-09-23, 02:17) — la prise 3D contre la 2D, PAR CANAL : les pixels
  dont un canal s'écarte de plus de 1/255, et l'écart maximal. À `--relief-plancher=1`, la 3D EST la 2D : il en faut zéro,
  avec et sans ombres. C'est la condition de tous les autres chiffres.
- **LES OMBRES AJOUTENT-ELLES DE LA LUMIÈRE ?** — pixels où la prise « ombres » dépasse « sans ombres » de plus de 4 : une
  ombre ne peut qu'ôter. Lu sur tous les cadrages, et d'abord sur `une_lumiere` et `deux_lumieres`.

Les recadrages vont dans `DOSSIER_DE_SORTIE/loupes` : 800×450 à 1:1 autour de chaque ancre, et ×4 au plus proche voisin
(200×112 agrandis) autour des corps, des faces et des fusées. Un `v27.json` porte tous les chiffres, pour la planche.
"""
import colorsys
import json
import math
import os
import re
import sys

from PIL import Image, ImageChops

journal, captures, sortie = sys.argv[1], sys.argv[2], sys.argv[3]
loupes = os.path.join(sortie, "loupes")
os.makedirs(loupes, exist_ok=True)

SEUIL_LUMINEUX = 6
SEUIL_MASQUE = 2
SEUIL_NOIR = 2
SEUIL_VISIBLE = 8
SEUIL_BLANC = 250
SEUIL_OMBRE_PLUS = 4
SEUIL_PLUS_3D = 12
CIBLE_MOINS = 1.0          # %, la preuve inverse
CIBLE_PLUS = 0.01          # %
L4, H4 = 200, 112          # la source d'une loupe ×4
L1, H1 = 800, 450          # une loupe à 1:1
FENETRE_FUSEE = 120
CIBLE_A = (0.85, 1.15)


def champs(ligne):
    d = {}
    tete = ligne.split(" ancres=")[0]
    for m in re.finditer(r"(\w+)=(\S+)", tete):
        d[m.group(1)] = m.group(2)
    a = ligne.find(" ancres=")
    if a >= 0:
        try:
            d["ancres"] = json.loads(ligne[a + len(" ancres="):])
        except json.JSONDecodeError:
            d["ancres"] = {}
    return d


cadrages = {}
for l in open(journal, encoding="utf-8", errors="replace").read().splitlines():
    if l.startswith("BANC_LUMIERE3D v27 "):
        c = champs(l)
        cadrages.setdefault(c["cadrage"], {})[c["variante"]] = c


def lum(img):
    return img.convert("L").tobytes()


def blancs(img):
    r, g, b = img.split()
    mini = ImageChops.darker(ImageChops.darker(r, g), b)
    return sum(mini.histogram()[SEUIL_BLANC:])


def fenetre(xy, l, h, w, hh):
    x0 = min(max(0, xy[0] - l // 2), w - l)
    y0 = min(max(0, xy[1] - h // 2), hh - h)
    return (x0, y0, x0 + l, y0 + h)


def mesures(l2, l3, masque, w, scinde, max2, boite=None):
    """(a), (b) et le rouge, sur l'image entière ou dans une boîte."""
    x0, y0, x1, y1 = boite if boite else (0, 0, w, len(l2) // w)
    s2 = s3 = 0
    rouges = separation = 0
    pop_b = hors_b = 0
    vis2 = moins = noirs2 = plus = 0
    seuil_b2 = 0.15 * max2
    seuil_b3 = 0.25 * max2
    for y in range(y0, y1):
        base = y * w
        for x in range(x0, x1):
            i = base + x
            a2 = l2[i]
            a3 = l3[i]
            if not (scinde and abs(x - w // 2) <= 4):
                if a2 > SEUIL_VISIBLE:
                    vis2 += 1
                    if a3 <= SEUIL_NOIR:
                        moins += 1
                else:
                    noirs2 += 1
                    if a3 > SEUIL_PLUS_3D:
                        plus += 1
            if a2 > SEUIL_VISIBLE:
                s2 += a2
                s3 += a3
            elif masque is not None and masque[i] < SEUIL_MASQUE and a3 > SEUIL_LUMINEUX:
                if scinde and abs(x - w // 2) <= 4:
                    separation += 1
                else:
                    rouges += 1
            if a2 < seuil_b2 and not (a2 <= SEUIL_NOIR and a3 <= SEUIL_NOIR):
                pop_b += 1
                if a3 > seuil_b3:
                    hors_b += 1
    return {
        "a": (s3 / s2) if s2 else None,
        "b_part": (100.0 * hors_b / pop_b) if pop_b else 0.0,
        "b_population": pop_b,
        "b_hors": hors_b,
        "rouge": rouges,
        "separation": separation,
        "moins_px": moins,
        "moins_part": (100.0 * moins / vis2) if vis2 else 0.0,
        "plus_px": plus,
        "plus_part": (100.0 * plus / noirs2) if noirs2 else 0.0,
    }


# ⚠️ BRUT, et non décodé en sRGB. MESURÉ (2026-09-22, émission de constantes sur le sol) : la vue 3D écrit la valeur du shader
# TELLE QUELLE sur l'octet — 0,25 émis se relit 0,25 en brut, et 0,050 si l'on décode en sRGB (0,25^2,2). Décoder élevait
# donc chaque rapport à la puissance 2,2 : un R de 0,8 se lisait 0,61, un R de 1,2 se lisait 1,49. La première mesure du
# correctif l'a payé : des « R ≈ 0,44 » et des anneaux qui n'étaient que l'instrument.
LUT_LIN = [c / 255.0 for c in range(256)]


def lum_lin(img):
    """La luminance de chaque pixel, aux poids de la pâte, EN VALEUR DU SHADER : l'octet brut (voir `LUT_LIN`)."""
    r, g, b = (c.tobytes() for c in img.convert("RGB").split())
    return [0.2126 * LUT_LIN[x] + 0.7152 * LUT_LIN[y] + 0.0722 * LUT_LIN[z] for x, y, z in zip(r, g, b)]


def r_banc(l3, ln, visible, w, boite=None):
    """R LU À L'IMAGE : la prise relief allumé sur la même prise relief neutralisé (R = 1 forcé), en linéaire, sur les pixels
    que la prise neutralisée montre (> 8 à l'écran). Ni la référence 2D ni la pâte n'y entrent : seul le relief diffère."""
    x0, y0, x1, y1 = boite if boite else (0, 0, w, len(ln) // w)
    s3 = sn = 0.0
    for y in range(y0, y1):
        base = y * w
        for x in range(x0, x1):
            i = base + x
            if visible[i] > SEUIL_VISIBLE:
                s3 += l3[i]
                sn += ln[i]
    return (s3 / sn) if sn > 0 else None


def identite(ref, img):
    """Pixels dont un canal au moins s'écarte de plus de 1/255 entre la 3D et la 2D, et l'écart maximal (octets bruts)."""
    r, g, b = ImageChops.difference(ref, img).split()
    ecart = ImageChops.lighter(ImageChops.lighter(r, g), b)
    h = ecart.histogram()
    return sum(h[2:]), max(k for k in range(256) if h[k]) if any(h) else 0


def teinte(img, l2, w, boite):
    x0, y0, x1, y1 = boite
    crop = img.crop(boite).convert("RGB").getdata()
    hs = ss = n = 0.0
    k = 0
    cx = cy = 0.0
    for y in range(y0, y1):
        for x in range(x0, x1):
            px = crop[k]
            k += 1
            if l2[y * w + x] <= SEUIL_VISIBLE:
                continue
            h, s, v = colorsys.rgb_to_hsv(px[0] / 255.0, px[1] / 255.0, px[2] / 255.0)
            # La teinte est circulaire : on moyenne le vecteur, pas l'angle.
            cx += math.cos(2 * math.pi * h) * s
            cy += math.sin(2 * math.pi * h) * s
            ss += s
            n += 1
    if not n:
        return None
    h = (math.atan2(cy, cx) / (2 * math.pi)) % 1.0
    return {"teinte_deg": round(360.0 * h, 1), "saturation": round(ss / n, 3), "px": int(n)}


def loupe(img, xy, nom, x4):
    w, h = img.size
    img.crop(fenetre(xy, L1, H1, w, h)).save(os.path.join(loupes, nom + ".png"))
    if x4:
        img.crop(fenetre(xy, L4, H4, w, h)).resize((L1, H1), Image.NEAREST).save(os.path.join(loupes, nom + "_x4.png"))


resultats = {}
print("ISO12 v27 — la recette du relief normalisé\n")
for nom in sorted(cadrages):
    prises = cadrages[nom]
    if "reference2d" not in prises:
        print("%s : pas de référence 2D, ignoré" % nom)
        continue
    scinde = "_v27_" not in nom
    # ⚠️ Une comparaison pixel à pixel n'a de sens que sous LA MÊME caméra : le banc imprime où tombe J1 à chaque prise.
    cameras = {v: p.get("camera") for v, p in prises.items() if p.get("camera")}
    xy_cam = [tuple(int(c) for c in s.split(",")) for s in cameras.values()]
    # Un pixel de tolérance : l'arrondi de la projection oscille d'un pixel sur une caméra posée.
    if xy_cam and max(max(abs(a[0] - b[0]), abs(a[1] - b[1])) for a in xy_cam for b in xy_cam) > 1:
        print("=" * 110)
        print("%s : CAMÉRA DIFFÉRENTE d'une prise à l'autre %s — cadrage REFUSÉ, aucune comparaison pixel à pixel" % (nom, cameras))
        continue
    ref = Image.open(os.path.join(captures, prises["reference2d"]["fichier"])).convert("RGB")
    w, h = ref.size
    l2 = lum(ref)
    max2 = max(1, max(l2))
    masque = lum(Image.open(os.path.join(captures, prises["masque"]["fichier"]))) if "masque" in prises else None
    ancres = prises["reference2d"].get("ancres", {})
    res = {"scinde": scinde, "blancs_2d": blancs(ref), "max2d": max2, "prises": {}}
    for nom_a, xy in ancres.items():
        loupe(ref, xy, "%s__reference2d__%s" % (nom, nom_a), True)
    print("=" * 110)
    print("%s  (%s, lumières 3D : %s, relief_max %s)" % (nom, "écran scindé" if scinde else "vue unique",
          prises.get("ombres", {}).get("lumieres3d", "?"), prises.get("ombres", {}).get("relief_max", "?")))
    print("  2D : %d px blancs, maximum %d" % (res["blancs_2d"], max2))
    images3 = {}
    neutre_lin = neutre_vis = None
    if "neutre" in prises:
        img_n = Image.open(os.path.join(captures, prises["neutre"]["fichier"])).convert("RGB")
        neutre_lin = lum_lin(img_n)
        neutre_vis = lum(img_n)
        # La prise à R = 1 forcé passe par la garde (émission = albédo) : sous le principe d'identité, elle EST la 2D.
        res["identite_neutre"] = identite(ref, img_n)
        print("  neutre (R = 1 forcé) — identité : %d px à plus de 1/255 de la 2D, écart max %d" % res["identite_neutre"])
        for nom_a, xy in ancres.items():
            loupe(img_n, xy, "%s__neutre__%s" % (nom, nom_a), True)
    for variante in ("sans_ombres", "ombres", "sabotage"):
        if variante not in prises:
            continue
        img = Image.open(os.path.join(captures, prises[variante]["fichier"])).convert("RGB")
        images3[variante] = img
        l3 = lum(img)
        m = mesures(l2, l3, masque, w, scinde, max2)
        m["blancs"] = blancs(img)
        m["identite_px"], m["identite_max"] = identite(ref, img)
        m["zones"] = {}
        l3_lin = lum_lin(img) if neutre_lin is not None else None
        m["R"] = r_banc(l3_lin, neutre_lin, neutre_vis, w) if l3_lin is not None else None
        for nom_a, xy in ancres.items():
            z = mesures(l2, l3, masque, w, scinde, max2, fenetre(xy, L4, H4, w, h))
            z["R"] = r_banc(l3_lin, neutre_lin, neutre_vis, w, fenetre(xy, L4, H4, w, h)) if l3_lin is not None else None
            m["zones"][nom_a] = z
            loupe(img, xy, "%s__%s__%s" % (nom, variante, nom_a), True)
        for nom_a, xy in ancres.items():
            if nom_a.startswith("fusee"):
                boite = fenetre(xy, FENETRE_FUSEE, FENETRE_FUSEE, w, h)
                m.setdefault("fusee", {})[nom_a] = {"3d": teinte(img, l2, w, boite), "2d": teinte(ref, l2, w, boite)}
        res["prises"][variante] = m
        a = m["a"]
        ok_a = a is not None and CIBLE_A[0] <= a <= CIBLE_A[1]
        print("  %-12s R lu %s · (a) image %s %s · (b) %.2f %% de %d px %s · ROUGE %d%s · blancs %d"
              % (variante, "%.3f" % m["R"] if m["R"] is not None else "—",
                 "%.3f" % a if a is not None else "—", "OK" if ok_a else "HORS 1,0 ± 0,15",
                 m["b_part"], m["b_population"], "OK" if m["b_part"] < 1.0 else "AU-DESSUS DE 1 %",
                 m["rouge"], (" (+%d sur la séparation)" % m["separation"]) if m["separation"] else "", m["blancs"]))
        print("      seuil : moins %d px = %.3f %% des visibles en 2D %s · plus %d px = %.4f %% des noirs en 2D %s"
              % (m["moins_px"], m["moins_part"], "OK" if m["moins_part"] < CIBLE_MOINS else "AU-DESSUS DE 1 %",
                 m["plus_px"], m["plus_part"], "OK" if m["plus_part"] < CIBLE_PLUS else "AU-DESSUS DE 0,01 %"))
        print("      identité : %d px à plus de 1/255 de la 2D (%.3f %%), écart max %d"
              % (m["identite_px"], 100.0 * m["identite_px"] / (w * h), m["identite_max"]))
        for nom_a, z in m["zones"].items():
            az = z["a"]
            print("      %-12s R lu %s · (a) %s · (b) %.2f %% de %d px · rouge %d · moins %d · plus %d"
                  % (nom_a, "%.3f" % z["R"] if z.get("R") is not None else "—",
                     "%.3f" % az if az is not None else "—  (rien de visible en 2D)", z["b_part"],
                     z["b_population"], z["rouge"], z["moins_px"], z["plus_px"]))
        for nom_a, t in m.get("fusee", {}).items():
            print("      %-12s teinte/saturation 3D %s contre 2D %s" % (nom_a, t["3d"], t["2d"]))
    if "ombres" in images3 and "sans_ombres" in images3:
        lo = lum(images3["ombres"])
        ls = lum(images3["sans_ombres"])
        plus = sum(1 for a, b in zip(lo, ls) if a > b + SEUIL_OMBRE_PLUS)
        moins = sum(1 for a, b in zip(lo, ls) if b > a + SEUIL_OMBRE_PLUS)
        res["ombres_plus_claires_px"] = plus
        res["ombres_plus_sombres_px"] = moins
        print("  OMBRES : %d px plus CLAIRS avec ombres qu'sans (> +%d) — il en faut zéro ; %d px plus sombres"
              % (plus, SEUIL_OMBRE_PLUS, moins))
    resultats[nom] = res

with open(os.path.join(sortie, "v27.json"), "w", encoding="utf-8") as f:
    json.dump(resultats, f, ensure_ascii=False, indent=1)
print("\nchiffres dans %s, loupes dans %s" % (os.path.join(sortie, "v27.json"), loupes))
