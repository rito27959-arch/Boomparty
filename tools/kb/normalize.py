"""Normalisation partagée — DOIT rester identique à lib/knowledge/text_normalizer.dart
(vérifié par tools/kb/normalize_cases.json, rejoué côté Dart dans les tests)."""
import re
import unicodedata

LIGATURES = {'œ': 'oe', 'æ': 'ae', 'ß': 'ss', 'Œ': 'oe', 'Æ': 'ae'}
# déterminants/articles retirés UNIQUEMENT en tête (les noms propres gardent leur
# forme complète grâce aux alias stockés avec et sans article)
LEADING = ['de la ', "de l'", 'les ', 'le ', 'la ', "l'", 'un ', 'une ', 'des ', 'du ', "d'", 'de ',
           'mon ', 'ma ', 'mes ', 'ton ', 'ta ', 'tes ', 'son ', 'sa ', 'ses ', 'ce ', 'cet ', 'cette ', 'ces ']
FILLERS = ['euh', 'heu', 'hum', 'ben', 'bah', 'alors', 'bon', 'ok', 'okay', 'donc', 'voila',
           'c est', 'je dis', 'je pense', 'je crois', 'moi je dis', 'mmh', 'hein']


def fold(text: str) -> str:
    """minuscules, sans accents ni ligatures, ponctuation → espaces, apostrophes conservées."""
    s = ''.join(LIGATURES.get(c, c) for c in text)
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c)).lower()
    s = s.replace('’', "'").replace('`', "'").replace('‘', "'")
    s = re.sub(r"[^a-z0-9' ]+", ' ', s)
    s = re.sub(r"'\s*", "' ", s)          # « l'eau » → « l' eau »
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def strip_fillers(s: str) -> str:
    changed = True
    while changed:
        changed = False
        for f in FILLERS:
            if s == f:
                return ''
            if s.startswith(f + ' '):
                s = s[len(f) + 1:]
                changed = True
            if s.endswith(' ' + f):
                s = s[:-len(f) - 1]
                changed = True
    return s.strip()


def strip_leading(s: str) -> str:
    """Retire un déterminant en tête (un seul passage, pas au milieu)."""
    for a in LEADING:
        a2 = a.replace("'", "' ") if a.endswith("'") else a
        if s.startswith(a2) and len(s) > len(a2):
            return s[len(a2):].strip()
    return s


def normalize(text: str) -> str:
    """Forme canonique d'une saisie : pliage + retrait des hésitations + article de tête."""
    return strip_leading(strip_fillers(fold(text)))


def singular_word(w: str) -> str:
    if len(w) <= 3:
        return w
    if w.endswith('eaux') or w.endswith('eux') and len(w) > 4:
        return w[:-1]
    if w.endswith('aux') and len(w) > 4:
        return w[:-3] + 'al'
    if w.endswith('s') or w.endswith('x'):
        return w[:-1]
    return w


def singular(s: str) -> str:
    return ' '.join(singular_word(w) for w in s.split(' '))


def plural_word(w: str) -> str:
    if w.endswith(('s', 'x', 'z')):
        return w
    if w.endswith('al') and len(w) > 3:
        return w[:-2] + 'aux'
    if w.endswith(('eau', 'au', 'eu')):
        return w + 'x'
    return w + 's'


def plural(s: str) -> str:
    """Pluriel naïf du premier mot (« pomme de terre » → « pommes de terre ») et des mots simples."""
    words = s.split(' ')
    if len(words) == 1:
        return plural_word(words[0])
    # composés : on accorde le premier nom (et le second s'il n'y a pas de préposition)
    if any(p in words for p in ('de', 'a', 'au', 'en', "d'", "l'")):
        return ' '.join([plural_word(words[0])] + words[1:])
    return ' '.join(plural_word(w) for w in words)
