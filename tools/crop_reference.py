"""Extrait chaque écran de la maquette en image de référence (bornes vérifiées visuellement)."""
import sys
from PIL import Image
SCREENS = {
 '01_accueil':        (8, 12, 232, 556),
 '02_modes_de_jeu':   (244, 12, 458, 548),
 '03_joueurs':        (468, 12, 664, 548),
 '04_categories':     (674, 12, 878, 548),
 '05_jeu_ecoute':     (888, 12, 1118, 548),
 '06_bonne_reponse':  (1128, 12, 1324, 548),
 '07_deja_dit':       (1334, 12, 1528, 548),
 '09_trop_lent':      (8, 572, 224, 1012),
 '10_explosion':      (236, 560, 484, 1012),
 '11_classement':     (494, 562, 716, 1012),
 '12_personnalisation':(726, 562, 1020, 1012),
 '13_parametres':     (1030, 562, 1278, 1012),
 '14_celebration':    (1290, 562, 1528, 1012),
}
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
for k, box in SCREENS.items():
    im.crop(box).save(f'{out}/{k}.png')
