import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'text_normalizer.dart';

class Concept {
  const Concept({required this.id, required this.name, required this.popularity, required this.source});
  final String id;
  final String name;
  final int popularity;
  final String source;
}

class KbCategory {
  const KbCategory({required this.id, required this.name, required this.gameCategory, required this.prompts});
  final String id;
  final String name;

  /// Tuile de l'écran « Choix de catégorie » (animaux, pays, objets…).
  final String gameCategory;
  final List<KbPrompt> prompts;
}

class KbPrompt {
  const KbPrompt(this.lead, this.keyword, this.tail);
  final String lead, keyword, tail;
  String get sentence => '$lead $keyword $tail';
}

class KbChallenge {
  const KbChallenge({required this.id, required this.categoryId, required this.count, this.firstLetter, required this.prompt});
  final String id;
  final String categoryId;
  final int count;
  final String? firstLetter;
  final KbPrompt prompt;
}

/// Base de connaissances (SQLite, construite par tools/kb/build_kb.py).
/// La base est lue une fois puis indexée en mémoire : les recherches pendant
/// la partie sont instantanées et n'accèdent plus au disque.
class KnowledgeRepository {
  KnowledgeRepository._();

  static const norm = TextNormalizer();

  final Map<String, Concept> concepts = {};
  final Map<String, KbCategory> categories = {};
  final Map<String, KbChallenge> challenges = {};

  /// forme normalisée → identifiants de concepts
  final Map<String, Set<String>> aliasIndex = {};

  /// catégorie → concepts membres
  final Map<String, Set<String>> members = {};

  /// catégorie → (forme normalisée, clé phonétique, concept) pour la recherche approchée
  final Map<String, List<(String, String, String)>> fuzzyIndex = {};

  /// concept → alias affichables
  final Map<String, List<String>> displayAliases = {};

  final Map<String, String> meta = {};

  static KnowledgeRepository open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return KnowledgeRepository._().._load(db);
    } finally {
      db.dispose();
    }
  }

  /// Copie la base embarquée (bytes de l'asset) puis l'ouvre.
  static Future<KnowledgeRepository> fromBytes(List<int> bytes, String cacheDir) async {
    final f = File('$cacheDir/boom_kb.db');
    if (!f.existsSync() || f.lengthSync() != bytes.length) {
      await f.writeAsBytes(bytes, flush: true);
    }
    return open(f.path);
  }

  void _load(Database db) {
    for (final r in db.select('SELECT id, canonical_name, popularity, source FROM concepts')) {
      concepts[r['id'] as String] = Concept(
        id: r['id'] as String,
        name: r['canonical_name'] as String,
        popularity: r['popularity'] as int,
        source: (r['source'] as String?) ?? '',
      );
    }
    for (final r in db.select('SELECT concept_id, alias, normalized_alias FROM aliases')) {
      final cid = r['concept_id'] as String;
      aliasIndex.putIfAbsent(r['normalized_alias'] as String, () => {}).add(cid);
      displayAliases.putIfAbsent(cid, () => []).add(r['alias'] as String);
    }
    final prompts = <String, List<KbPrompt>>{};
    for (final r in db.select('SELECT category_id, lead, keyword, tail FROM category_prompts')) {
      prompts.putIfAbsent(r['category_id'] as String, () => []).add(KbPrompt(r['lead'] as String, r['keyword'] as String, r['tail'] as String));
    }
    for (final r in db.select('SELECT id, name, game_category FROM categories')) {
      final id = r['id'] as String;
      categories[id] = KbCategory(id: id, name: r['name'] as String, gameCategory: r['game_category'] as String, prompts: prompts[id] ?? const []);
    }
    for (final r in db.select('SELECT category_id, concept_id FROM category_concepts')) {
      members.putIfAbsent(r['category_id'] as String, () => {}).add(r['concept_id'] as String);
    }
    for (final r in db.select('SELECT id, category_id, count, first_letter, lead, keyword, tail FROM challenges')) {
      challenges[r['id'] as String] = KbChallenge(
        id: r['id'] as String,
        categoryId: r['category_id'] as String,
        count: r['count'] as int,
        firstLetter: r['first_letter'] as String?,
        prompt: KbPrompt(r['lead'] as String, r['keyword'] as String, r['tail'] as String),
      );
    }
    for (final r in db.select('SELECT key, value FROM meta')) {
      meta[r['key'] as String] = (r['value'] as String?) ?? '';
    }
    // index approché par catégorie
    final byConcept = <String, List<String>>{};
    aliasIndex.forEach((n, ids) {
      for (final id in ids) {
        byConcept.putIfAbsent(id, () => []).add(n);
      }
    });
    members.forEach((cat, ids) {
      final list = <(String, String, String)>[];
      for (final id in ids) {
        for (final n in byConcept[id] ?? const <String>[]) {
          list.add((n, norm.phonetic(n), id));
        }
      }
      fuzzyIndex[cat] = list;
    });
  }

  bool inCategory(String conceptId, String categoryId) => members[categoryId]?.contains(conceptId) ?? false;

  /// Catégories de la base reliées à une tuile du jeu.
  List<KbCategory> forGameCategory(String game) => [for (final c in categories.values) if (c.gameCategory == game) c];
}
