"""Port Python du rattrapage du validateur Dart (BoomAnswerValidator) :
correspondance exacte, sous-séquences, puis approchée (phonétique / distance)
dans le vocabulaire de la catégorie active. Sert au banc d'essai « en jeu »."""
import re
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'kb'))
from normalize import fold, normalize, singular, strip_leading  # noqa: E402

RULES = [('eaux', 'o'), ('eau', 'o'), ('aux', 'o'), ('au', 'o'), ('ph', 'f'), ('qu', 'k'), ('ck', 'k'),
         ('ch', 'C'), ('sh', 'C'), ('gn', 'N'), ('ge', 'je'), ('gi', 'ji'), ('ce', 'se'), ('ci', 'si'),
         ('ai', 'e'), ('ei', 'e'), ('er', 'e'), ('ez', 'e'), ('et', 'e'), ('an', 'A'), ('am', 'A'),
         ('en', 'A'), ('em', 'A'), ('on', 'O'), ('om', 'O'), ('in', 'I'), ('im', 'I'), ('ain', 'I'),
         ('ein', 'I'), ('un', 'I'), ('ou', 'U'), ('oi', 'wa'), ('y', 'i'), ('c', 'k'), ('q', 'k'),
         ('h', ''), ('z', 's'), ('x', 'ks'), ('w', 'v')]


def phonetic(s):
    s = s.replace(' ', '').replace("'", '')
    for a, b in RULES:
        s = s.replace(a, b)
    s = re.sub(r'[stdpe]+$', '', s)
    return ''.join(c for i, c in enumerate(s) if i == 0 or c != s[i - 1])


def dist(a, b, mx=3):
    if abs(len(a) - len(b)) > mx:
        return mx + 1
    d = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
    for i in range(len(a) + 1):
        d[i][0] = i
    for j in range(len(b) + 1):
        d[0][j] = j
    for i in range(1, len(a) + 1):
        for j in range(1, len(b) + 1):
            c = 0 if a[i - 1] == b[j - 1] else 1
            v = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + c)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                v = min(v, d[i - 2][j - 2] + 1)
            d[i][j] = v
    return d[len(a)][len(b)]


class Matcher:
    def __init__(self, db_path):
        db = sqlite3.connect(db_path)
        self.alias = {}
        for cid, n in db.execute('SELECT concept_id, normalized_alias FROM aliases'):
            self.alias.setdefault(n, set()).add(cid)
        self.members = {}
        for cat, cid in db.execute('SELECT category_id, concept_id FROM category_concepts'):
            self.members.setdefault(cat, set()).add(cid)
        self.cat_alias = {}
        for n, ids in self.alias.items():
            for cid in ids:
                for cat, m in self.members.items():
                    if cid in m:
                        self.cat_alias.setdefault(cat, []).append((n, phonetic(n), cid))

    def categories_of(self, word):
        ids = self.alias.get(normalize(word), set()) | self.alias.get(singular(normalize(word)), set())
        return [c for c, m in self.members.items() if ids & m], ids

    def resolve(self, text, cat):
        n = normalize(text)
        if not n:
            return None
        cands = {n, singular(n), fold(text)}
        w = n.split(' ')
        for ln in range(len(w) - 1, 0, -1):
            for i in range(len(w) - ln + 1):
                cands.add(strip_leading(' '.join(w[i:i + ln])))
        for c in cands:
            for cid in self.alias.get(c, set()) | self.alias.get(singular(c), set()):
                if cid in self.members.get(cat, ()):
                    return cid
        if len(n) < 4:
            return None
        key, mx = phonetic(n), (2 if len(n) >= 9 else 1)
        best = None
        for a, ph, cid in self.cat_alias.get(cat, []):
            if abs(len(a) - len(n)) > mx + 1:
                continue
            score = 0 if (len(key) >= 3 and ph == key) else dist(n, a, mx)
            if score <= mx and (best is None or score < best[0]):
                best = (score, cid)
        return best[1] if best else None
