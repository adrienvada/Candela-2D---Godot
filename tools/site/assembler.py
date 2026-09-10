#!/usr/bin/env python3
"""Assemble le site de Candela, en deux modes.

    python3 assembler.py                    -> candela.html, autonome (data: URI)
    python3 assembler.py --fichiers <dir>   -> <dir>/index.html + <dir>/images/

**Pourquoi deux modes, et pas un seul.** L'artefact publié n'accepte AUCUNE
image distante : tout doit voyager dans le fichier, d'où les mégaoctets de
base64. GitHub Pages n'a pas cette contrainte, et y servir un fichier unique
ferait retélécharger toutes les images à chaque visite au lieu de les laisser au
cache du navigateur. Le gabarit est le même ; seule la résolution des jetons
d'image change.

Chaque jeton porte une LISTE de candidats : le premier qui existe gagne. C'est
ce qui permet d'écrire la page avant que les images commandées n'arrivent —
elle se replie sur une illustration déjà présente, et l'annonce à la
génération plutôt que de tomber.
"""
import base64, io, pathlib, shutil, sys

RACINE = pathlib.Path(__file__).parent

IMAGES = {
    # Les dix fonds de scène. Les six premiers sont les planches de l'intro
    # (DA6.6) ; les autres viennent du jeu ou d'illustrations de menu.
    "{{F_DESCENTE}}":   ["pl-descente.jpg"],
    "{{F_SEUIL}}":      ["pl-seuil.jpg"],
    "{{F_PRIX}}":       ["pl-prix.jpg"],
    # Trois fonds commandés pour le site. Tant qu'ils n'existent pas, repli sur
    # une illustration de menu : la page ne dépend jamais d'une image en route.
    "{{F_ARMES}}":      ["fond_armes.jpg", "bg-competitif.jpg"],
    "{{F_RANGS}}":      ["fond_rangs.jpg", "bg-quitter.jpg"],
    "{{F_PORTE}}":      ["fond_telecharger.jpg", "bg-ecran_scinde.jpg"],
    "{{F_EXTINCTION}}": ["pl-extinction.jpg"],
    # La vitrine : sept captures de partie, sans légende.
    "{{G_DUEL}}":   ["hero-duel.jpg"],
    "{{G_TORCHE}}": ["sig-05-torche.jpg"],
    "{{G_RETRO}}":  ["sig-06-retrodiffusion.jpg"],
    "{{G_FLASH}}":  ["sig-07-flash-de-tir.jpg"],
    "{{G_SCINDE}}": ["gal-scinde.jpg"],
    "{{G_FUSEE}}":  ["gal-fusee.jpg"],
    "{{G_EBLOUI}}": ["gal-eblouissement.jpg"],
}

# Les icônes de plateforme sont FACULTATIVES : sans elles, le bouton se lit très
# bien avec son seul lettrage, et rien ne casse.
ICONES = {
    "{{ICO_MAC}}": ("icone_macos.png", "macOS"),
    "{{ICO_WIN}}": ("icone_windows.png", "Windows"),
}


def uri(nom: str) -> str:
    contenu = (RACINE / nom).read_bytes()
    mime = "image/png" if nom.endswith(".png") else "image/jpeg"
    return f"data:{mime};base64," + base64.b64encode(contenu).decode("ascii")


sortie = None
if "--fichiers" in sys.argv:
    i = sys.argv.index("--fichiers")
    if i + 1 >= len(sys.argv):
        sys.exit("--fichiers attend un dossier de sortie")
    sortie = pathlib.Path(sys.argv[i + 1]).expanduser()


def lien(nom: str) -> str:
    """data: URI en mode autonome, chemin relatif en mode fichiers."""
    if sortie is None:
        return uri(nom)
    dossier = sortie / "images"
    dossier.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(RACINE / nom, dossier / nom)
    return f"images/{nom}"


src = (RACINE / "candela.tpl.html").read_text(encoding="utf-8")

replis = []
for cle, candidats in IMAGES.items():
    if cle not in src:
        sys.exit(f"jeton absent du gabarit : {cle}")
    choisi = next((c for c in candidats if (RACINE / c).exists()), None)
    if choisi is None:
        sys.exit(f"aucun candidat présent pour {cle} : {candidats}")
    if choisi != candidats[0]:
        replis.append(f"{candidats[0]} → {choisi}")
    src = src.replace(cle, lien(choisi))

poses = []
for cle, (fichier, nom) in ICONES.items():
    if cle not in src:
        sys.exit(f"jeton absent du gabarit : {cle}")
    if (RACINE / fichier).exists():
        src = src.replace(cle, f'<img class="glyphe" src="{lien(fichier)}" alt="">')
        poses.append(nom)
    else:
        src = src.replace(cle, "")

# --- La durée du film, LUE sur le fichier -------------------------------------
# Elle était écrite à la main dans le gabarit — « Quarante-trois secondes » — et
# le film a changé trois fois dans la soirée. Un chiffre recopié se périme sans
# prévenir ; celui-ci se relit à chaque génération.
if "{{DUREE_FILM}}" in src:
    duree_mots = "Le film"
    film = RACINE / "film.mp4"
    if film.exists():
        try:
            import subprocess
            secondes = float(subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "csv=p=0", str(film)],
                capture_output=True, text=True, check=True).stdout.strip())
            unites = ["zéro", "une", "deux", "trois", "quatre", "cinq", "six", "sept",
                      "huit", "neuf", "dix", "onze", "douze", "treize", "quatorze",
                      "quinze", "seize"]
            n = int(round(secondes))
            if n < len(unites):
                mot = unites[n]
            elif n < 70:
                dizaines = {20: "vingt", 30: "trente", 40: "quarante", 50: "cinquante", 60: "soixante"}
                d, u = (n // 10) * 10, n % 10
                if u == 0:
                    mot = dizaines[d]
                elif u == 1:
                    mot = dizaines[d] + " et une"
                else:
                    mot = dizaines[d] + "-" + unites[u]
            else:
                mot = str(n)
            duree_mots = mot[0].upper() + mot[1:] + "<br>secondes"
        except Exception:
            pass
    src = src.replace("{{DUREE_FILM}}", duree_mots)

# --- Le film ------------------------------------------------------------------
# Il pèse six mégaoctets : embarqué en data-URI, il ferait basculer la page
# autonome à treize mégaoctets, très près du plafond de l'artefact — et pour un
# fichier que la plupart des lecteurs ne liront pas. Les deux modes divergent
# donc ici, et c'est le seul endroit où ils divergent :
#
#   fichiers  -> un vrai <video>, avec affiche et `preload="none"`
#   autonome  -> l'affiche seule, cliquable vers le site
#
# La page publiée reste donc complète, et l'artefact reste léger.
SITE = "https://adrienvada.fr/candela-2d/"
if "{{FILM}}" in src:
    if sortie is not None and (RACINE / "film.mp4").exists():
        dossier = sortie / "videos"
        dossier.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(RACINE / "film.mp4", dossier / "film.mp4")
        src = src.replace("{{FILM}}",
            f'<video controls preload="none" poster="{lien("film-affiche.jpg")}">'
            f'<source src="videos/film.mp4" type="video/mp4">'
            f'Votre navigateur ne sait pas lire cette vidéo — '
            f'<a href="videos/film.mp4">la télécharger</a>.</video>')
    else:
        src = src.replace("{{FILM}}",
            f'<a href="{SITE}"><img class="film-affiche" src="{lien("film-affiche.jpg")}" '
            f'alt="Une image du film : un cône de torche révèle une silhouette au fond d’un couloir."></a>')

if "{{" in src:
    sys.exit("jeton non résolu dans le gabarit")

suffixe = ""
if replis:
    suffixe = " — REPLIS : " + " ; ".join(replis)

if sortie is None:
    (RACINE / "candela.html").write_text(src, encoding="utf-8")
    print(f"autonome : {len(src)//1024} Ko — icônes : {', '.join(poses) or 'aucune'}{suffixe}")
else:
    # Le gabarit est un FRAGMENT : l'artefact lui pose son propre squelette.
    # Servi par Pages, il lui faut le sien — et il doit être exact.
    page = (
        '<!doctype html>\n<html lang="fr">\n<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<meta name="description" content="Un duel à deux dans le noir absolu. '
        'Le faisceau qui vous montre l’adversaire lui montre où vous êtes.">\n'
        '<meta property="og:title" content="Candela">\n'
        '<meta property="og:description" content="Un duel à deux dans le noir absolu.">\n'
        '<meta property="og:image" content="images/hero-duel.jpg">\n'
        '<style>html{color-scheme:dark}body{margin:0}img{max-width:100%}</style>\n'
        "</head>\n<body>\n" + src + "\n</body>\n</html>\n"
    )
    sortie.mkdir(parents=True, exist_ok=True)
    (sortie / "index.html").write_text(page, encoding="utf-8")
    # Sans ce fichier, Jekyll traite le dossier et ignore tout nom commençant
    # par un souligné. Rien n'en porte aujourd'hui : c'est une garantie.
    (sortie / ".nojekyll").write_text("", encoding="utf-8")
    # `.git` exclu du compte : le dossier de sortie est un dépôt, et compter ses
    # objets ferait annoncer un poids de page qui double à chaque génération.
    poids = sum(f.stat().st_size for f in sortie.rglob("*")
                if f.is_file() and ".git" not in f.parts)
    print(f"fichiers : {sortie} — {poids//1024} Ko au total, "
          f"icônes : {', '.join(poses) or 'aucune'}{suffixe}")
