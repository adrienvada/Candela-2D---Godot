#!/usr/bin/env python3
"""Assemble le site de Candela, en deux modes.

    python3 assembler.py                    -> candela.html, autonome (data: URI)
    python3 assembler.py --fichiers <dir>   -> <dir>/index.html + <dir>/images/

**Pourquoi deux modes, et pas un seul.** L'artefact publié n'accepte AUCUNE
image distante : tout doit voyager dans le fichier, d'où les 3 Mo de base64.
GitHub Pages n'a pas cette contrainte, et y servir un seul fichier de 3 Mo
ferait retélécharger toutes les images à chaque visite au lieu de les laisser
au cache du navigateur. Le gabarit est le même ; seule la résolution des jetons
d'image change.
"""
import base64, io, pathlib, shutil, sys

RACINE = pathlib.Path(__file__).parent

def uri(nom: str) -> str:
    c = (RACINE / nom).read_bytes()
    mime = "image/png" if nom.endswith(".png") else "image/jpeg"
    return f"data:{mime};base64," + base64.b64encode(c).decode("ascii")

IMAGES = {
    # les trois illustrations pleine largeur
    "{{IMG_SCINDE}}": "ill_ecran_scinde.jpg",
    "{{IMG_COMPETITIF}}": "ill_competitif.jpg",
    "{{IMG_QUITTER}}": "ill_quitter.jpg",
    # la vitrine : huit captures, sans légende
    "{{G_DUEL}}": "hero-duel.jpg",
    "{{G_TORCHE}}": "sig-05-torche.jpg",
    "{{G_RETRO}}": "sig-06-retrodiffusion.jpg",
    "{{G_FLASH}}": "sig-07-flash-de-tir.jpg",
    "{{G_SCINDE}}": "gal-scinde.jpg",
    "{{G_FUSEE}}": "gal-fusee.jpg",
    "{{G_EBLOUI}}": "gal-eblouissement.jpg",
    "{{G_GEL}}": "gal-gel.jpg",
}
# Les icônes de plateforme sont FACULTATIVES : tant qu'elles n'existent pas,
# le bouton se lit très bien avec son seul lettrage. Rien ne casse.
ICONES = {
    "{{ICO_MAC}}": ("icone_macos.png", "macOS"),
    "{{ICO_WIN}}": ("icone_windows.png", "Windows"),
}

# --- Le mode -----------------------------------------------------------------
sortie = None
if "--fichiers" in sys.argv:
    i = sys.argv.index("--fichiers")
    if i + 1 >= len(sys.argv):
        sys.exit("--fichiers attend un dossier de sortie")
    sortie = pathlib.Path(sys.argv[i + 1]).expanduser()

def lien(nom: str) -> str:
    """Résout un jeton d'image : data: URI en autonome, chemin relatif en fichiers."""
    if sortie is None:
        return uri(nom)
    dossier = sortie / "images"
    dossier.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(RACINE / nom, dossier / nom)
    return f"images/{nom}"

src = (RACINE / "candela.tpl.html").read_text(encoding="utf-8")
for cle, fic in IMAGES.items():
    assert cle in src, f"jeton absent du gabarit : {cle}"
    src = src.replace(cle, lien(fic))

poses = []
for cle, (fic, nom) in ICONES.items():
    assert cle in src, f"jeton absent du gabarit : {cle}"
    if (RACINE / fic).exists():
        src = src.replace(cle, f'<img class="glyphe" src="{lien(fic)}" alt="">')
        poses.append(nom)
    else:
        src = src.replace(cle, "")

src = src.replace("  --gap: clamp(0.5rem, 1.4vw, 1rem);",
                  '  --gap: clamp(0.5rem, 1.4vw, 1rem);\n  --img-duel: url("' + lien("hero-duel.jpg") + '");')

assert "{{" not in src, "jeton non résolu"

if sortie is None:
    (RACINE / "candela.html").write_text(src, encoding="utf-8")
    print(f"autonome : {len(src)//1024} Ko — icônes posées : {', '.join(poses) or 'aucune'}")
else:
    # Le gabarit est un FRAGMENT : l'artefact lui pose son propre squelette.
    # Servi par Pages, il lui faut le sien — et il doit être exact, pas décoratif.
    page = (
        "<!doctype html>\n<html lang=\"fr\">\n<head>\n"
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<meta name="description" content="Un duel à deux dans le noir absolu. '
        'Le faisceau qui vous montre l\u2019adversaire lui montre où vous êtes.">\n'
        '<meta property="og:title" content="Candela">\n'
        '<meta property="og:description" content="Un duel à deux dans le noir absolu.">\n'
        '<meta property="og:image" content="images/hero-duel.jpg">\n'
        '<style>html{color-scheme:dark}body{margin:0}img{max-width:100%}</style>\n'
        "</head>\n<body>\n" + src + "\n</body>\n</html>\n"
    )
    sortie.mkdir(parents=True, exist_ok=True)
    (sortie / "index.html").write_text(page, encoding="utf-8")
    # Sans ce fichier, Jekyll traite le dossier et ignore tout nom commençant
    # par un souligné. Rien n'en porte aujourd'hui ; c'est une garantie, pas un
    # correctif.
    (sortie / ".nojekyll").write_text("", encoding="utf-8")
    # `.git` exclu : le dossier de sortie est un dépôt, et compter ses objets
    # ferait annoncer un poids de page qui double à chaque génération.
    poids = sum(f.stat().st_size for f in sortie.rglob("*")
                if f.is_file() and ".git" not in f.parts)
    print(f"fichiers : {sortie} — {poids//1024} Ko au total, "
          f"icônes posées : {', '.join(poses) or 'aucune'}")
