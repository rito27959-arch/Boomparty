"""Construit la base de connaissances SQLite de BOOM PARTY.

Sources :
- Wikidata (CC0 1.0) : concepts, libellés et alias français (= synonymes), formes
  féminines (P2521), popularité (sitelinks).
- Listes d'amorçage écrites pour BOOM PARTY (kb_config.py).

Étapes : contrôle des QID de classes → requêtes SPARQL par catégorie →
libellés/alias par lots → fusion des listes manuelles par domaine → fusion des
quasi-doublons → génération des pluriels / formes sans article → SQLite indexé
→ rapport de validation (JSON + Markdown).

    python build_kb.py <sortie.db> <rapport_dir> [--offline]

--offline : n'utilise que les listes manuelles (pour tester sans Internet).
"""
import json
import re
import sqlite3
import sys
import time
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from kb_config import CATEGORIES, CHALLENGES, CLASSES, EXCLUDE_PATTERN, EXCLUDE_QIDS  # noqa: E402
from normalize import fold, normalize, plural, strip_leading  # noqa: E402

ENDPOINT = 'https://query.wikidata.org/sparql'
UA = 'BoomPartyKB/1.0 (https://github.com/rito27959-arch/Boomparty; game knowledge base build)'

DOMAIN = {
    'animaux': 'animal', 'animaux_ferme': 'animal', 'pays': 'lieu', 'capitales': 'lieu', 'villes_france': 'lieu',
    'objets_maison': 'objet', 'objets_cuisine': 'objet', 'fruits': 'aliment', 'legumes': 'aliment',
    'plats': 'aliment', 'boissons': 'aliment', 'metiers': 'metier', 'sports': 'sport', 'vehicules': 'vehicule',
    'instruments': 'instrument', 'vetements': 'vetement', 'couleurs': 'couleur', 'corps': 'corps',
    'genres_films': 'genre_film', 'genres_musique': 'genre_musique', 'elements': 'element',
}


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', fold(s)).strip('_')


class Wikidata:
    def __init__(self):
        import requests
        self.s = requests.Session()
        self.s.headers['User-Agent'] = UA
        self.s.headers['Accept'] = 'application/sparql-results+json'

    def query(self, q, retries=4):
        for k in range(retries):
            try:
                r = self.s.get(ENDPOINT, params={'query': q}, timeout=120)
                if r.status_code == 429:
                    time.sleep(10 * (k + 1))
                    continue
                r.raise_for_status()
                return r.json()['results']['bindings']
            except Exception as e:  # noqa: BLE001
                print('  ! SPARQL', type(e).__name__, str(e)[:200], flush=True)
                time.sleep(5 * (k + 1))
        raise RuntimeError('requête SPARQL en échec')

    def check_classes(self):
        values = ' '.join(f'wd:{q}' for q in CLASSES)
        rows = self.query(f'SELECT ?c ?l WHERE {{ VALUES ?c {{ {values} }} ?c rdfs:label ?l FILTER(lang(?l)="en") }}')
        got = {r['c']['value'].rsplit('/', 1)[1]: r['l']['value'] for r in rows}
        bad = {q: (exp, got.get(q)) for q, exp in CLASSES.items() if (got.get(q) or '').lower() != exp.lower()}
        return got, bad

    def details(self, qids):
        """Libellé FR, alias FR, forme féminine FR, nom scientifique, libellé EN."""
        out = {}
        qids = list(qids)
        for i in range(0, len(qids), 250):
            chunk = qids[i:i + 250]
            values = ' '.join(f'wd:{q}' for q in chunk)
            q = f"""
            SELECT ?item ?label ?alias ?fem ?taxon ?en WHERE {{
              VALUES ?item {{ {values} }}
              OPTIONAL {{ ?item rdfs:label ?label FILTER(lang(?label)="fr") }}
              OPTIONAL {{ ?item skos:altLabel ?alias FILTER(lang(?alias)="fr") }}
              OPTIONAL {{ ?item wdt:P2521 ?fem FILTER(lang(?fem)="fr") }}
              OPTIONAL {{ ?item wdt:P225 ?taxon }}
              OPTIONAL {{ ?item rdfs:label ?en FILTER(lang(?en)="en") }}
            }}"""
            for r in self.query(q):
                qid = r['item']['value'].rsplit('/', 1)[1]
                d = out.setdefault(qid, {'label': None, 'aliases': set(), 'female': set(), 'taxon': set(), 'en': None})
                if 'label' in r:
                    d['label'] = r['label']['value']
                if 'alias' in r:
                    d['aliases'].add(r['alias']['value'])
                if 'fem' in r:
                    d['female'].add(r['fem']['value'])
                if 'taxon' in r:
                    d['taxon'].add(r['taxon']['value'])
                if 'en' in r:
                    d['en'] = r['en']['value']
            time.sleep(1.0)
        return out


def good_alias(a, taxon_names):
    if not a or len(a) < 2 or len(a) > 40:
        return False
    if any(ch in a for ch in '()[]:/;|"«»') or re.search(r'\d', a):
        return False
    if len(a.split()) > 5:
        return False
    if a.isupper() and len(a) <= 5:          # sigles : seulement s'ils viennent des listes manuelles
        return False
    if a in taxon_names:                      # nom scientifique latin
        return False
    if re.search(r'[^\w\s\'\-éèêëàâäîïôöùûüçœæ’.]', a.lower()):
        return False
    return True


def main():
    db_path, report_dir = Path(sys.argv[1]), Path(sys.argv[2])
    offline = '--offline' in sys.argv
    report_dir.mkdir(parents=True, exist_ok=True)
    report = {'categories': {}, 'warnings': [], 'sources': {}}

    concepts = {}                     # id → {name, source, source_id, popularity, aliases: {norm: (alias, kind)}}
    cat_members = defaultdict(dict)   # cat_id → {concept_id: source}

    def add_alias(cid, text, kind):
        n = normalize(text)
        if not n:
            return
        concepts[cid]['aliases'].setdefault(n, (text, kind))
        # variantes : pluriel, et sans article de tête pour les noms qui en ont un
        p = plural(n)
        if p != n:
            concepts[cid]['aliases'].setdefault(p, (text, 'plural'))
        f = fold(text)
        if f != n:
            concepts[cid]['aliases'].setdefault(f, (text, 'with_article'))

    wd = None
    if not offline:
        wd = Wikidata()
        got, bad = wd.check_classes()
        report['sources']['wikidata_class_check'] = got
        if bad:
            raise SystemExit(f'QID de classes incorrects : {bad}')
        print('classes Wikidata vérifiées', flush=True)

    # 1) pools Wikidata par catégorie
    pools = {}
    for cat in CATEGORIES:
        pool = {}
        if wd:
            for q in cat['queries']:
                try:
                    rows = wd.query(q)
                except RuntimeError:
                    report['warnings'].append(f"{cat['id']}: requête en échec, catégorie limitée aux listes manuelles")
                    rows = []
                for r in rows:
                    qid = r['item']['value'].rsplit('/', 1)[1]
                    pool[qid] = max(pool.get(qid, 0), int(r['sl']['value']))
                time.sleep(1.0)
        pools[cat['id']] = pool
        print(f"{cat['id']}: {len(pool)} entités Wikidata", flush=True)

    all_qids = {q for p in pools.values() for q in p}
    details = wd.details(all_qids) if wd else {}

    # index par domaine : forme normalisée → QID (pour rattacher les listes manuelles)
    domain_index = defaultdict(dict)
    for cat in CATEGORIES:
        dom = DOMAIN[cat['id']]
        for qid, sl in pools[cat['id']].items():
            d = details.get(qid)
            if not d or not d['label']:
                continue
            if qid in EXCLUDE_QIDS or re.search(EXCLUDE_PATTERN, d['label'], re.I) or \
                    (cat.get('exclude') and re.search(cat['exclude'], d['label'], re.I)):
                report['warnings'].append(f"{cat['id']}: exclu « {d['label']} » [{qid}]")
                continue
            if d['label'] in d['taxon'] or (d['taxon'] and re.fullmatch(r'[A-Z][a-z]+ [a-z]+', d['label'])):
                continue                     # pas de nom vernaculaire français : inutilisable en jeu
            if qid not in concepts:
                concepts[qid] = {'name': d['label'], 'source': 'wikidata', 'source_id': qid, 'popularity': sl, 'aliases': {}}
                add_alias(qid, d['label'], 'label')
                for a in d['aliases']:
                    if good_alias(a, d['taxon']):
                        add_alias(qid, a, 'alias')
                for f in d['female']:
                    if good_alias(f, set()):
                        add_alias(qid, f, 'female')
            cat_members[cat['id']][qid] = 'wikidata'
            for n in concepts[qid]['aliases']:
                prev = domain_index[dom].get(n)
                if prev is None or concepts[prev]['popularity'] < sl:
                    domain_index[dom][n] = qid

    # 2) listes manuelles, rattachées au concept Wikidata du même domaine s'il existe
    for cat in CATEGORIES:
        dom = DOMAIN[cat['id']]
        for words in cat['seeds']:
            canon = words[0]
            norms = [normalize(w) for w in words]
            cid = next((domain_index[dom][n] for n in norms if n in domain_index[dom]), None)
            if cid is None:
                cid = f'm:{dom}:{slug(canon)}'
                if cid not in concepts:
                    concepts[cid] = {'name': canon, 'source': 'boomparty', 'source_id': None, 'popularity': 1000, 'aliases': {}}
            else:
                concepts[cid]['popularity'] = max(concepts[cid]['popularity'], 1000)  # vocabulaire courant
                concepts[cid]['name'] = canon  # le mot courant de la liste sert de nom affiché
            for w in words:
                add_alias(cid, w, 'seed')
                domain_index[dom][normalize(w)] = cid
            cat_members[cat['id']][cid] = 'seed' if cid.startswith('m:') else 'wikidata+seed'

    # 3) fusion des quasi-doublons dans une catégorie (même nom canonique normalisé)
    merged = 0
    for cat_id, members in cat_members.items():
        by_name = defaultdict(list)
        for cid in members:
            by_name[normalize(concepts[cid]['name'])].append(cid)
        for name, ids in by_name.items():
            if len(ids) < 2:
                continue
            ids.sort(key=lambda c: -concepts[c]['popularity'])
            keep = ids[0]
            for other in ids[1:]:
                for n, v in concepts[other]['aliases'].items():
                    concepts[keep]['aliases'].setdefault(n, v)
                members.pop(other, None)
                merged += 1
    report['merged_duplicates'] = merged

    # 4) ambiguïtés : un même alias → plusieurs concepts d'une même catégorie
    ambiguous = []
    for cat_id, members in cat_members.items():
        seen = defaultdict(set)
        for cid in members:
            for n in concepts[cid]['aliases']:
                seen[n].add(cid)
        for n, ids in seen.items():
            if len(ids) > 1:
                ambiguous.append({'category': cat_id, 'alias': n, 'concepts': sorted(concepts[c]['name'] + ' [' + c + ']' for c in ids)})
    report['ambiguous_aliases'] = ambiguous

    # 5) SQLite
    if db_path.exists():
        db_path.unlink()
    db = sqlite3.connect(db_path)
    db.executescript("""
    CREATE TABLE concepts (id TEXT PRIMARY KEY, canonical_name TEXT NOT NULL, language TEXT NOT NULL,
                           source TEXT, source_id TEXT, popularity INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE aliases (id INTEGER PRIMARY KEY, concept_id TEXT NOT NULL, alias TEXT NOT NULL,
                          normalized_alias TEXT NOT NULL, language TEXT NOT NULL, kind TEXT NOT NULL);
    CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, language TEXT NOT NULL, game_category TEXT NOT NULL);
    CREATE TABLE category_concepts (category_id TEXT NOT NULL, concept_id TEXT NOT NULL, source TEXT NOT NULL,
                                    PRIMARY KEY(category_id, concept_id));
    CREATE TABLE category_prompts (category_id TEXT NOT NULL, lead TEXT NOT NULL, keyword TEXT NOT NULL, tail TEXT NOT NULL);
    CREATE TABLE challenges (id TEXT PRIMARY KEY, category_id TEXT NOT NULL, count INTEGER NOT NULL,
                             first_letter TEXT, lead TEXT NOT NULL, keyword TEXT NOT NULL, tail TEXT NOT NULL);
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
    CREATE INDEX idx_alias_norm ON aliases(normalized_alias);
    CREATE INDEX idx_alias_concept ON aliases(concept_id);
    CREATE INDEX idx_cc_concept ON category_concepts(concept_id);
    """)
    used = {cid for m in cat_members.values() for cid in m}
    for cid in sorted(used):
        c = concepts[cid]
        db.execute('INSERT INTO concepts VALUES (?,?,?,?,?,?)', (cid, c['name'], 'fr', c['source'], c['source_id'], c['popularity']))
        for n, (text, kind) in sorted(c['aliases'].items()):
            db.execute('INSERT INTO aliases(concept_id, alias, normalized_alias, language, kind) VALUES (?,?,?,?,?)',
                       (cid, text, n, 'fr', kind))
    for cat in CATEGORIES:
        db.execute('INSERT INTO categories VALUES (?,?,?,?)', (cat['id'], cat['name'], 'fr', cat['game']))
        for cid, src in cat_members[cat['id']].items():
            db.execute('INSERT INTO category_concepts VALUES (?,?,?)', (cat['id'], cid, src))
        for lead, kw, tail in cat['prompts']:
            db.execute('INSERT INTO category_prompts VALUES (?,?,?,?)', (cat['id'], lead, kw, tail))
    for ch in CHALLENGES:
        lead, kw, tail = ch['prompt']
        db.execute('INSERT INTO challenges VALUES (?,?,?,?,?,?,?)', (ch['id'], ch['category'], ch['count'], ch['first_letter'], lead, kw, tail))
    meta = {
        'built_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'sources': 'Wikidata (CC0 1.0) ; listes BOOM PARTY',
        'offline_build': str(offline),
        'normalizer_version': '1',
    }
    for k, v in meta.items():
        db.execute('INSERT INTO meta VALUES (?,?)', (k, v))
    db.commit()
    db.execute('VACUUM')
    db.close()

    # 6) rapport
    for cat in CATEGORIES:
        members = cat_members[cat['id']]
        names = sorted((concepts[c]['name'] for c in members), key=lambda s: fold(s))
        top = sorted(members, key=lambda c: -concepts[c]['popularity'])
        report['categories'][cat['id']] = {
            'concepts': len(members),
            'from_wikidata': sum(1 for s in members.values() if 'wikidata' in s),
            'from_seeds_only': sum(1 for s in members.values() if s == 'seed'),
            'aliases': sum(len(concepts[c]['aliases']) for c in members),
            'sample_popular': [concepts[c]['name'] for c in top[:25]],
            'sample_least_popular': [concepts[c]['name'] + f" ({concepts[c]['popularity']})" for c in top[-25:]],
            'all_names': names,
        }
    report['totals'] = {'concepts': len(used), 'aliases': sum(len(concepts[c]['aliases']) for c in used)}
    (report_dir / 'kb_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1))
    md = ['# Rapport de la base de connaissances', '', f"Concepts : {report['totals']['concepts']} — alias : {report['totals']['aliases']}",
          f"Quasi-doublons fusionnés : {merged} — alias ambigus : {len(ambiguous)}", '',
          '| catégorie | concepts | Wikidata | listes seules | alias |', '|---|---|---|---|---|']
    for cid, r in report['categories'].items():
        md.append(f"| {cid} | {r['concepts']} | {r['from_wikidata']} | {r['from_seeds_only']} | {r['aliases']} |")
    md += ['', '## Avertissements'] + [f'- {w}' for w in report['warnings']]
    md += ['', '## Ambiguïtés (extrait)'] + [f"- {a['category']} : « {a['alias']} » → {', '.join(a['concepts'])}" for a in ambiguous[:80]]
    for cid, r in report['categories'].items():
        md += ['', f'## {cid} — les moins populaires (à vérifier)', ', '.join(r['sample_least_popular'])]
    (report_dir / 'kb_report.md').write_text('\n'.join(md))
    print('\n'.join(md[:30]))


if __name__ == '__main__':
    main()
