"""Joue une partie sur l'appareil adb (émulateur CI) : menus → catégorie → partie
→ réponses tapées au clavier → explosion. Sauvegarde une capture et l'état du
processus à chaque étape, pour repérer un plantage ou un écran bloqué.

    python3 tools/smoke_play.py <dossier_sortie>
"""
import re
import subprocess
import sys
import time
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else 'out')
OUT.mkdir(parents=True, exist_ok=True)
PKG = 'com.boomparty.boom_party'
log = []


def adb(*a, capture=True):
    return subprocess.run(['adb', *a], capture_output=capture, text=True, timeout=60).stdout


def shot(name):
    with open(OUT / f'jeu_{name}.png', 'wb') as f:
        f.write(subprocess.run(['adb', 'exec-out', 'screencap', '-p'], capture_output=True, timeout=60).stdout)
    alive = adb('shell', 'pidof', PKG).strip()
    log.append(f'{name}: processus={"vivant " + alive if alive else "MORT"}')
    print(log[-1], flush=True)
    return bool(alive)


def nodes():
    adb('shell', 'uiautomator', 'dump', '/sdcard/ui.xml')
    xml = adb('shell', 'cat', '/sdcard/ui.xml')
    out = []
    for m in re.finditer(r'<node [^>]*?(?:text|content-desc)="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
        out.append((m.group(1), (int(m.group(2)) + int(m.group(4))) // 2, (int(m.group(3)) + int(m.group(5))) // 2))
    for m in re.finditer(r'<node [^>]*?content-desc="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
        out.append((m.group(1), (int(m.group(2)) + int(m.group(4))) // 2, (int(m.group(3)) + int(m.group(5))) // 2))
    return out


def tap_text(pattern, fallback=None, wait=2.5):
    for label, x, y in nodes():
        if re.search(pattern, label, re.I | re.S):
            adb('shell', 'input', 'tap', str(x), str(y))
            log.append(f'  tap « {label[:40]!r} » ({x},{y})')
            time.sleep(wait)
            return True
    if fallback:
        w, h = map(int, re.findall(r'(\d+)x(\d+)', adb('shell', 'wm', 'size'))[-1])
        adb('shell', 'input', 'tap', str(int(w * fallback[0])), str(int(h * fallback[1])))
        log.append(f'  « {pattern} » introuvable → tap relatif {fallback}')
        time.sleep(wait)
        return True
    log.append(f'  « {pattern} » introuvable')
    return False


def type_answer(word):
    tap_text(r"Je t'écoute|écoute", fallback=(0.5, 0.92), wait=1.5)
    adb('shell', 'input', 'text', word.replace(' ', '%s'))
    time.sleep(0.5)
    tap_text(r'^Valider$', wait=1.2)


try:
    time.sleep(3)
    shot('00_accueil')
    tap_text(r'^Jouer$', fallback=(0.5, 0.71))
    shot('01_modes')
    tap_text(r'Culture générale', fallback=(0.5, 0.25))
    shot('02_joueurs')
    tap_text(r'^Continuer$', fallback=(0.5, 0.93))
    shot('03_categories')
    tap_text(r'^Objets$', fallback=(0.75, 0.42))
    tap_text(r'Lancer la partie', fallback=(0.5, 0.94), wait=2.5)
    shot('04_partie')
    for i, w in enumerate(['table', 'refrigerateur', 'frigo', 'elephant', 'chaise']):
        type_answer(w)
        shot(f'05_reponse_{i}_{w}')
        time.sleep(1.5)
    time.sleep(45)  # la mèche finit par exploser
    shot('06_apres_attente')
    tap_text(r'Continuer|Manche suivante|Suivant', wait=4)
    shot('07_suite')
finally:
    (OUT / 'jeu_journal.txt').write_text('\n'.join(log) + '\n')
