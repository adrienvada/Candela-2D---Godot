#!/usr/bin/env python3
"""
Générateur des 16 SVG de prompts manette au style « Roman Graphique Brutaliste » de Candela 2D.
- Arêtes géométriques vives et angles coupés (chanfreins à 45°).
- Traits noirs d'encre épais (2.5px à 3px minimum sur les contours).
- Suppression totale des dégradés mous et des arrondis flous.
- Hachures d'ombre au pochoir d'atelier clandestin (trame diagonale à 45°).
- Palette stricte de la Charte : Noir d'encre #000000, Surface sombre #101216, Acier #B3C2D1, Halogène #FAEDE0, Ambre #F5B03D, Diode Bleue #4B90E2, Diode Rouge #F24954, Diode Verte #44D976, Magenta #D65CB8.
"""
import os

PROMPTS_DIR = "assets/ui/prompts"
os.makedirs(PROMPTS_DIR, exist_ok=True)

# Helper pour l'en-tête et pied SVG
def svg_wrap(width, height, content):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">
{content}
</svg>
'''

# 1. CROSS (X)
cross_content = '''  <!-- Fond octogonal chanfreiné à 45° avec trait d'encre noir épais -->
  <polygon points="7,1 17,1 23,7 23,17 17,23 7,23 1,17 1,7" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre au pochoir d'atelier clandestin -->
  <g stroke="#000000" stroke-width="1.8" stroke-linecap="square">
    <line x1="14" y1="21" x2="21" y2="14"/>
    <line x1="11" y1="22" x2="22" y2="11"/>
    <line x1="15" y1="22" x2="22" y2="15"/>
    <line x1="18" y1="22" x2="22" y2="18"/>
  </g>

  <!-- Biseau d'acier intérieur -->
  <polygon points="7.5,2.5 16.5,2.5 21.5,7.5 21.5,16.5 16.5,21.5 7.5,21.5 2.5,16.5 2.5,7.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Ombre d'encre décalée pour la croix -->
  <polygon points="17.2,7.8 15.2,5.8 12.0,9.0 8.8,5.8 6.8,7.8 10.0,11.0 6.8,14.2 8.8,16.2 12.0,13.0 15.2,16.2 17.2,14.2 14.0,11.0" fill="#000000" transform="translate(1.2, 1.2)"/>

  <!-- Symbole Croix tranchée d'arène -->
  <polygon points="17.2,7.8 15.2,5.8 12.0,9.0 8.8,5.8 6.8,7.8 10.0,11.0 6.8,14.2 8.8,16.2 12.0,13.0 15.2,16.2 17.2,14.2 14.0,11.0" fill="#4B90E2" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>'''

# 2. CIRCLE (O)
circle_content = '''  <!-- Fond octogonal chanfreiné à 45° -->
  <polygon points="7,1 17,1 23,7 23,17 17,23 7,23 1,17 1,7" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre au pochoir -->
  <g stroke="#000000" stroke-width="1.8" stroke-linecap="square">
    <line x1="14" y1="21" x2="21" y2="14"/>
    <line x1="11" y1="22" x2="22" y2="11"/>
    <line x1="15" y1="22" x2="22" y2="15"/>
    <line x1="18" y1="22" x2="22" y2="18"/>
  </g>

  <!-- Biseau d'acier intérieur -->
  <polygon points="7.5,2.5 16.5,2.5 21.5,7.5 21.5,16.5 16.5,21.5 7.5,21.5 2.5,16.5 2.5,7.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Ombre d'encre décalée pour l'anneau octogonal -->
  <polygon points="9,5 15,5 19,9 19,15 15,19 9,19 5,15 5,9" fill="#000000" transform="translate(1.2, 1.2)"/>

  <!-- Anneau octogonal franc (suppression du rond mou) -->
  <polygon points="9,5 15,5 19,9 19,15 15,19 9,19 5,15 5,9" fill="#F24954" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>
  <polygon points="10,7.5 14,7.5 16.5,10 16.5,14 14,16.5 10,16.5 7.5,14 7.5,10" fill="#101216" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>'''

# 3. SQUARE (Carré)
square_content = '''  <!-- Fond octogonal chanfreiné à 45° -->
  <polygon points="7,1 17,1 23,7 23,17 17,23 7,23 1,17 1,7" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre au pochoir -->
  <g stroke="#000000" stroke-width="1.8" stroke-linecap="square">
    <line x1="14" y1="21" x2="21" y2="14"/>
    <line x1="11" y1="22" x2="22" y2="11"/>
    <line x1="15" y1="22" x2="22" y2="15"/>
    <line x1="18" y1="22" x2="22" y2="18"/>
  </g>

  <!-- Biseau d'acier intérieur -->
  <polygon points="7.5,2.5 16.5,2.5 21.5,7.5 21.5,16.5 16.5,21.5 7.5,21.5 2.5,16.5 2.5,7.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Ombre d'encre décalée pour le carré -->
  <rect x="6" y="6" width="12" height="12" fill="#000000" transform="translate(1.2, 1.2)"/>

  <!-- Carré géométrique strict aux angles vifs 90° -->
  <rect x="6" y="6" width="12" height="12" fill="#D65CB8" stroke="#000000" stroke-width="1.2"/>
  <rect x="8.5" y="8.5" width="7" height="7" fill="#101216" stroke="#000000" stroke-width="1.2"/>'''

# 4. TRIANGLE (Triangle)
triangle_content = '''  <!-- Fond octogonal chanfreiné à 45° -->
  <polygon points="7,1 17,1 23,7 23,17 17,23 7,23 1,17 1,7" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre au pochoir -->
  <g stroke="#000000" stroke-width="1.8" stroke-linecap="square">
    <line x1="14" y1="21" x2="21" y2="14"/>
    <line x1="11" y1="22" x2="22" y2="11"/>
    <line x1="15" y1="22" x2="22" y2="15"/>
    <line x1="18" y1="22" x2="22" y2="18"/>
  </g>

  <!-- Biseau d'acier intérieur -->
  <polygon points="7.5,2.5 16.5,2.5 21.5,7.5 21.5,16.5 16.5,21.5 7.5,21.5 2.5,16.5 2.5,7.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Ombre d'encre décalée pour le triangle -->
  <polygon points="12,4.8 19.5,17.5 4.5,17.5" fill="#000000" transform="translate(1.2, 1.2)"/>

  <!-- Triangle acéré incisif -->
  <polygon points="12,4.8 19.5,17.5 4.5,17.5" fill="#44D976" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>
  <polygon points="12,8.5 16.5,15.5 7.5,15.5" fill="#101216" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>'''

# 5. DPAD_UP
dpad_up_content = '''  <!-- Cartouche D-Pad Haut biseauté -->
  <polygon points="3,7 8,1 16,1 21,7 21,22 3,22" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre pochoir -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="15" y1="21" x2="20" y2="16"/>
    <line x1="12" y1="21" x2="20" y2="13"/>
    <line x1="17" y1="21" x2="20" y2="18"/>
  </g>

  <!-- Bord intérieur d'acier -->
  <polygon points="4.5,7.5 8.5,2.5 15.5,2.5 19.5,7.5 19.5,20.5 4.5,20.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Flèche chevron d'avertissement montante -->
  <polygon points="12,4 17,10 14,10 14,16 10,16 10,10 7,10" fill="#000000" transform="translate(1, 1)"/>
  <polygon points="12,4 17,10 14,10 14,16 10,16 10,10 7,10" fill="#FAEDE0" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>
  
  <!-- Encoche pochoir d'atelier -->
  <line x1="12" y1="6" x2="12" y2="13" stroke="#101216" stroke-width="1.5"/>'''

# 6. DPAD_DOWN
dpad_down_content = '''  <!-- Cartouche D-Pad Bas biseauté -->
  <polygon points="3,1 21,1 21,16 16,22 8,22 3,16" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre pochoir -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="15" y1="20" x2="20" y2="15"/>
    <line x1="12" y1="20" x2="20" y2="12"/>
    <line x1="17" y1="20" x2="20" y2="17"/>
  </g>

  <!-- Bord intérieur d'acier -->
  <polygon points="4.5,2.5 19.5,2.5 19.5,15.5 15.5,20.5 8.5,20.5 4.5,15.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Flèche chevron descendante -->
  <polygon points="12,19 7,13 10,13 10,7 14,7 14,13 17,13" fill="#000000" transform="translate(1, 1)"/>
  <polygon points="12,19 7,13 10,13 10,7 14,7 14,13 17,13" fill="#FAEDE0" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>
  
  <!-- Encoche pochoir d'atelier -->
  <line x1="12" y1="17" x2="12" y2="10" stroke="#101216" stroke-width="1.5"/>'''

# 7. DPAD_LEFT
dpad_left_content = '''  <!-- Cartouche D-Pad Gauche biseauté -->
  <polygon points="7,3 1,8 1,16 7,21 22,21 22,3" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre pochoir -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="15" y1="20" x2="21" y2="14"/>
    <line x1="18" y1="20" x2="21" y2="17"/>
  </g>

  <!-- Bord intérieur d'acier -->
  <polygon points="7.5,4.5 2.5,8.5 2.5,15.5 7.5,19.5 20.5,19.5 20.5,4.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Flèche chevron gauche -->
  <polygon points="4,12 10,7 10,10 16,10 16,14 10,14 10,17" fill="#000000" transform="translate(1, 1)"/>
  <polygon points="4,12 10,7 10,10 16,10 16,14 10,14 10,17" fill="#FAEDE0" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>
  
  <!-- Encoche pochoir d'atelier -->
  <line x1="6" y1="12" x2="13" y2="12" stroke="#101216" stroke-width="1.5"/>'''

# 8. DPAD_RIGHT
dpad_right_content = '''  <!-- Cartouche D-Pad Droite biseauté -->
  <polygon points="1,3 16,3 22,8 22,16 16,21 1,21" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre pochoir -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="15" y1="20" x2="20" y2="15"/>
    <line x1="17" y1="20" x2="21" y2="16"/>
  </g>

  <!-- Bord intérieur d'acier -->
  <polygon points="2.5,4.5 15.5,4.5 20.5,8.5 20.5,15.5 15.5,19.5 2.5,19.5" fill="none" stroke="#2B333D" stroke-width="1"/>

  <!-- Flèche chevron droite -->
  <polygon points="19,12 13,7 13,10 7,10 7,14 13,14 13,17" fill="#000000" transform="translate(1, 1)"/>
  <polygon points="19,12 13,7 13,10 7,10 7,14 13,14 13,17" fill="#FAEDE0" stroke="#000000" stroke-width="1.2" stroke-linejoin="miter"/>
  
  <!-- Encoche pochoir d'atelier -->
  <line x1="17" y1="12" x2="10" y2="12" stroke="#101216" stroke-width="1.5"/>'''

# 9. L1
l1_content = '''  <!-- Plaque L1 chanfreinée aux 4 coins style tôle rivetée -->
  <polygon points="5,1 23,1 27,5 27,15 23,19 5,19 1,15 1,5" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre d'atelier -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="18" y1="18" x2="25" y2="11"/>
    <line x1="21" y1="18" x2="26" y2="13"/>
    <line x1="15" y1="18" x2="24" y2="9"/>
  </g>

  <!-- Rivets d'acier aux coins -->
  <rect x="3" y="3" width="1.8" height="1.8" fill="#707B88"/>
  <rect x="23.2" y="3" width="1.8" height="1.8" fill="#707B88"/>

  <!-- Typographie pochoir L1 d'arène clandestine -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8">
    <!-- L au pochoir avec encoche -->
    <path d="M7,5 L10,5 L10,12 L13.5,12 L13.5,14.5 L7,14.5 Z"/>
    <!-- 1 au pochoir avec biseau franc -->
    <path d="M17,6.8 L18.8,5 L20.5,5 L20.5,14.5 L18,14.5 L18,7.8 L16.5,8.8 Z"/>
  </g>'''

# 10. R1
r1_content = '''  <!-- Plaque R1 chanfreinée aux 4 coins style tôle rivetée -->
  <polygon points="5,1 23,1 27,5 27,15 23,19 5,19 1,15 1,5" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures d'ombre d'atelier -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="18" y1="18" x2="25" y2="11"/>
    <line x1="21" y1="18" x2="26" y2="13"/>
    <line x1="15" y1="18" x2="24" y2="9"/>
  </g>

  <!-- Rivets d'acier aux coins -->
  <rect x="3" y="3" width="1.8" height="1.8" fill="#707B88"/>
  <rect x="23.2" y="3" width="1.8" height="1.8" fill="#707B88"/>

  <!-- Typographie pochoir R1 d'arène clandestine -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8">
    <!-- R anguleux au pochoir -->
    <path d="M6.5,5 L12,5 L13.5,6.8 L13.5,9.2 L12,11 L10,11 L13.5,14.5 L10.5,14.5 L7.8,11.5 L6.5,11.5 L6.5,14.5 L4,14.5 L4,5 Z M6.5,7 L6.5,9.5 L10.5,9.5 L11,9 L11,7.5 L10.5,7 Z"/>
    <!-- 1 au pochoir avec biseau franc -->
    <path d="M17,6.8 L18.8,5 L20.5,5 L20.5,14.5 L18,14.5 L18,7.8 L16.5,8.8 Z"/>
  </g>'''

# 11. L2
l2_content = '''  <!-- Cartouche gâchette L2 industrielle biseautée -->
  <polygon points="5,1 23,1 27,6 25,18 21,22 7,22 3,18 1,6" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Stries de grip en chevrons d'encre -->
  <g stroke="#000000" stroke-width="1.6" stroke-linecap="square">
    <line x1="4" y1="4" x2="24" y2="4"/>
    <line x1="17" y1="21" x2="24" y2="14"/>
    <line x1="20" y1="21" x2="25" y2="16"/>
  </g>

  <!-- Typographie pochoir L2 -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8">
    <!-- L -->
    <path d="M6,7 L8.8,7 L8.8,13.5 L12.5,13.5 L12.5,16 L6,16 Z"/>
    <!-- 2 anguleux avec découpe pochoir -->
    <path d="M15,9 L19,7 L21.5,7 L21.5,11 L18,13.5 L22,13.5 L22,16 L15,16 L15,13.8 L19,11 L19,9.5 L16.8,9.5 L15,10.5 Z"/>
  </g>'''

# 12. R2
r2_content = '''  <!-- Cartouche gâchette R2 industrielle biseautée -->
  <polygon points="5,1 23,1 27,6 25,18 21,22 7,22 3,18 1,6" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Stries de grip en chevrons d'encre -->
  <g stroke="#000000" stroke-width="1.6" stroke-linecap="square">
    <line x1="4" y1="4" x2="24" y2="4"/>
    <line x1="17" y1="21" x2="24" y2="14"/>
    <line x1="20" y1="21" x2="25" y2="16"/>
  </g>

  <!-- Typographie pochoir R2 -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8">
    <!-- R anguleux -->
    <path d="M5.5,7 L11,7 L12.5,8.8 L12.5,11 L11,12.5 L9.5,12.5 L12.5,16 L9.5,16 L7.2,13 L5.5,13 L5.5,16 L3,16 L3,7 Z M5.5,9 L5.5,11 L10,11 L10.5,10.5 L10.5,9.5 L10,9 Z"/>
    <!-- 2 anguleux avec découpe pochoir -->
    <path d="M15,9 L19,7 L21.5,7 L21.5,11 L18,13.5 L22,13.5 L22,16 L15,16 L15,13.8 L19,11 L19,9.5 L16.8,9.5 L15,10.5 Z"/>
  </g>'''

# 13. L3
l3_content = '''  <!-- Cartouche Joystick L3 avec biseau d'acier -->
  <polygon points="7,1 17,1 23,7 23,17 17,23 7,23 1,17 1,7" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures pochoir -->
  <g stroke="#000000" stroke-width="1.8" stroke-linecap="square">
    <line x1="14" y1="21" x2="21" y2="14"/>
    <line x1="17" y1="21" x2="22" y2="16"/>
  </g>

  <!-- Croix de visée du stick -->
  <line x1="12" y1="2" x2="12" y2="4.5" stroke="#707B88" stroke-width="1.5"/>
  <line x1="12" y1="19.5" x2="12" y2="22" stroke="#707B88" stroke-width="1.5"/>
  <line x1="2" y1="12" x2="4.5" y2="12" stroke="#707B88" stroke-width="1.5"/>
  <line x1="19.5" y1="12" x2="22" y2="12" stroke="#707B88" stroke-width="1.5"/>

  <!-- Lettrage pochoir L3 -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8">
    <path d="M5.5,7 L8.5,7 L8.5,14 L12.5,14 L12.5,16.5 L5.5,16.5 Z"/>
    <path d="M14.5,7 L20,7 L20,10.5 L17.5,11.5 L20,12.5 L20,16.5 L14.5,16.5 L14.5,14 L17.5,14 L17.5,12.5 L15.5,12.5 L15.5,10.5 L17.5,10.5 L17.5,9 L14.5,9 Z"/>
  </g>'''

# 14. R3
r3_content = '''  <!-- Cartouche Joystick R3 avec biseau d'acier -->
  <polygon points="7,1 17,1 23,7 23,17 17,23 7,23 1,17 1,7" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures pochoir -->
  <g stroke="#000000" stroke-width="1.8" stroke-linecap="square">
    <line x1="14" y1="21" x2="21" y2="14"/>
    <line x1="17" y1="21" x2="22" y2="16"/>
  </g>

  <!-- Croix de visée du stick -->
  <line x1="12" y1="2" x2="12" y2="4.5" stroke="#707B88" stroke-width="1.5"/>
  <line x1="12" y1="19.5" x2="12" y2="22" stroke="#707B88" stroke-width="1.5"/>
  <line x1="2" y1="12" x2="4.5" y2="12" stroke="#707B88" stroke-width="1.5"/>
  <line x1="19.5" y1="12" x2="22" y2="12" stroke="#707B88" stroke-width="1.5"/>

  <!-- Lettrage pochoir R3 -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8">
    <path d="M5,7 L10.5,7 L12,8.8 L12,11 L10.5,12.5 L9,12.5 L12,16.5 L9,16.5 L6.8,13.5 L5,13.5 L5,16.5 L2.5,16.5 L2.5,7 Z M5,9 L5,11.5 L9.5,11.5 L10,11 L10,9.5 L9.5,9 Z"/>
    <path d="M14.5,7 L20,7 L20,10.5 L17.5,11.5 L20,12.5 L20,16.5 L14.5,16.5 L14.5,14 L17.5,14 L17.5,12.5 L15.5,12.5 L15.5,10.5 L17.5,10.5 L17.5,9 L14.5,9 Z"/>
  </g>'''

# 15. OPTIONS
options_content = '''  <!-- Plaque Options métallique rectangulaire avec chanfreins -->
  <polygon points="4,1 24,1 27,4 27,16 24,19 4,19 1,16 1,4" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures pochoir à 45° -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="18" y1="18" x2="25" y2="11"/>
    <line x1="21" y1="18" x2="26" y2="13"/>
  </g>

  <!-- Rivets d'acier aux coins -->
  <rect x="2.8" y="2.8" width="1.5" height="1.5" fill="#707B88"/>
  <rect x="23.7" y="2.8" width="1.5" height="1.5" fill="#707B88"/>

  <!-- Trois barres industrielles franches au pochoir (Menu brutaliste) -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8">
    <polygon points="7,5.5 21,5.5 19.5,7.8 7,7.8"/>
    <polygon points="7,9.2 19.5,9.2 18,11.5 7,11.5"/>
    <polygon points="7,12.9 18,12.9 16.5,15.2 7,15.2"/>
  </g>'''

# 16. SHARE
share_content = '''  <!-- Plaque Share métallique rectangulaire avec chanfreins -->
  <polygon points="4,1 24,1 27,4 27,16 24,19 4,19 1,16 1,4" fill="#101216" stroke="#000000" stroke-width="2.5" stroke-linejoin="miter"/>
  
  <!-- Hachures pochoir à 45° -->
  <g stroke="#000000" stroke-width="1.5" stroke-linecap="square">
    <line x1="18" y1="18" x2="25" y2="11"/>
    <line x1="21" y1="18" x2="26" y2="13"/>
  </g>

  <!-- Rivets d'acier aux coins -->
  <rect x="2.8" y="2.8" width="1.5" height="1.5" fill="#707B88"/>
  <rect x="23.7" y="2.8" width="1.5" height="1.5" fill="#707B88"/>

  <!-- Pictogramme pochoir d'émission / balise de partage -->
  <g fill="#FAEDE0" stroke="#000000" stroke-width="0.8" stroke-linejoin="miter">
    <!-- Balise centrale carrée -->
    <rect x="7" y="7.5" width="4.5" height="4.5"/>
    <!-- Chevrons émetteurs tranchants vers la droite -->
    <polygon points="14,6 17,6 20,10 17,14 14,14 17,10"/>
  </g>'''

FILES = {
    "cross.svg": (24, 24, cross_content),
    "circle.svg": (24, 24, circle_content),
    "square.svg": (24, 24, square_content),
    "triangle.svg": (24, 24, triangle_content),
    "dpad_up.svg": (24, 24, dpad_up_content),
    "dpad_down.svg": (24, 24, dpad_down_content),
    "dpad_left.svg": (24, 24, dpad_left_content),
    "dpad_right.svg": (24, 24, dpad_right_content),
    "l1.svg": (28, 20, l1_content),
    "r1.svg": (28, 20, r1_content),
    "l2.svg": (28, 24, l2_content),
    "r2.svg": (28, 24, r2_content),
    "l3.svg": (24, 24, l3_content),
    "r3.svg": (24, 24, r3_content),
    "options.svg": (28, 20, options_content),
    "share.svg": (28, 20, share_content),
}

for filename, (w, h, c) in FILES.items():
    filepath = os.path.join(PROMPTS_DIR, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(svg_wrap(w, h, c))
    print(f"Généré : {filepath} ({w}x{h})")

print("16/16 SVG Roman Graphique Brutaliste générés avec succès !")
