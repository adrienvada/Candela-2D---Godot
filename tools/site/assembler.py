#!/usr/bin/env python3
"""Assemble le site de Candela : gabarit + images en data-URI -> candela.html."""
import base64, io, pathlib, sys

RACINE = pathlib.Path(__file__).parent

def uri(nom: str) -> str:
    c = (RACINE / nom).read_bytes()
    mime = "image/png" if nom.endswith(".png") else "image/jpeg"
    return f"data:{mime};base64," + base64.b64encode(c).decode("ascii")

IMAGES = {
    "{{IMG_SCINDE}}": "ill_ecran_scinde.jpg",
    "{{IMG_COMPETITIF}}": "ill_competitif.jpg",
    "{{IMG_QUITTER}}": "ill_quitter.jpg",
    "{{SIG_TORCHE}}": "sig-05-torche.jpg",
    "{{SIG_RETRO}}": "sig-06-retrodiffusion.jpg",
    "{{SIG_FLASH}}": "sig-07-flash-de-tir.jpg",
}
# Les icônes de plateforme sont FACULTATIVES : tant qu'elles n'existent pas,
# le bouton se lit très bien avec son seul lettrage. Rien ne casse.
ICONES = {
    "{{ICO_MAC}}": ("icone_macos.png", "macOS"),
    "{{ICO_WIN}}": ("icone_windows.png", "Windows"),
}

src = (RACINE / "candela.tpl.html").read_text(encoding="utf-8")
for cle, fic in IMAGES.items():
    assert cle in src, f"jeton absent du gabarit : {cle}"
    src = src.replace(cle, uri(fic))

poses = []
for cle, (fic, nom) in ICONES.items():
    assert cle in src, f"jeton absent du gabarit : {cle}"
    if (RACINE / fic).exists():
        src = src.replace(cle, f'<img class="glyphe" src="{uri(fic)}" alt="">')
        poses.append(nom)
    else:
        src = src.replace(cle, "")

src = src.replace("  --gap: clamp(0.5rem, 1.4vw, 1rem);",
                  '  --gap: clamp(0.5rem, 1.4vw, 1rem);\n  --img-duel: url("' + uri("hero-duel.jpg") + '");')

assert "{{" not in src, "jeton non résolu"
(RACINE / "candela.html").write_text(src, encoding="utf-8")
print(f"écrit : {len(src)//1024} Ko — icônes posées : {', '.join(poses) or 'aucune'}")
