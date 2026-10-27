import 'knowledge_repository.dart';
import 'text_normalizer.dart';

enum AnswerStatus { accepted, duplicate, wrongCategory, unknown, ambiguous, recognitionError }

/// Décision structurée, explicable, produite pour chaque réponse.
class AnswerDecision {
  const AnswerDecision({
    required this.status,
    required this.spokenText,
    this.conceptId,
    this.canonicalConcept,
    this.previousAnswer,
    this.alternatives = const [],
    this.confidence = 1.0,
    this.matchedAlias,
    required this.message,
  });

  final AnswerStatus status;
  final String spokenText;
  final String? conceptId;
  final String? canonicalConcept;

  /// Pour un doublon : la formulation déjà acceptée (ex. « réfrigérateur » pour « frigo »).
  final String? previousAnswer;

  /// Pour une ambiguïté : les concepts possibles.
  final List<String> alternatives;
  final double confidence;
  final String? matchedAlias;
  final String message;

  bool get isAccepted => status == AnswerStatus.accepted;

  /// Les erreurs de reconnaissance et les ambiguïtés ne pénalisent jamais le joueur.
  bool get needsRepeat => status == AnswerStatus.recognitionError || status == AnswerStatus.ambiguous;

  Map<String, Object?> toJson() => {
        'status': status.name,
        'spokenText': spokenText,
        'canonicalConcept': canonicalConcept,
        'conceptId': conceptId,
        'previousAnswer': previousAnswer,
        'alternatives': alternatives,
        'confidence': confidence,
        'message': message,
      };
}

/// Mémoire des réponses d'une manche, par concept canonique.
class BoomAnswerMemory {
  final Map<String, String> _used = {}; // conceptId → formulation acceptée
  final List<AnswerDecision> history = []; // toute la partie (stats, humour)

  bool contains(String conceptId) => _used.containsKey(conceptId);
  String? firstSpoken(String conceptId) => _used[conceptId];
  List<String> get usedWords => _used.values.toList();
  int get length => _used.length;

  void _commit(AnswerDecision d) {
    if (d.isAccepted && d.conceptId != null) _used[d.conceptId!] = d.spokenText;
  }

  /// Nouvelle manche indépendante : les concepts redeviennent disponibles.
  void newRound() => _used.clear();
}

/// Valide une réponse contre la catégorie active et la mémoire de la manche.
class BoomAnswerValidator {
  BoomAnswerValidator(this.kb);

  final KnowledgeRepository kb;
  static const _n = TextNormalizer();

  /// Seuil sous lequel une transcription est considérée comme peu fiable.
  static const minAsrConfidence = 0.35;

  /// Valide et, si la réponse est acceptée, l'enregistre dans la mémoire —
  /// en une seule opération synchrone (aucun doublon possible entre deux appels).
  AnswerDecision validateAndCommit(String spoken, String categoryId, BoomAnswerMemory memory, {double? asrConfidence}) {
    final d = validate(spoken, categoryId, memory, asrConfidence: asrConfidence);
    memory._commit(d);
    memory.history.add(d);
    return d;
  }

  AnswerDecision validate(String spoken, String categoryId, BoomAnswerMemory memory, {double? asrConfidence}) {
    final text = spoken.trim();
    final normalized = _n.normalize(text);
    if (normalized.isEmpty || (asrConfidence != null && asrConfidence < minAsrConfidence)) {
      return AnswerDecision(
        status: AnswerStatus.recognitionError,
        spokenText: text,
        confidence: asrConfidence ?? 0,
        message: "Je n'ai pas bien entendu. Répète, s'il te plaît !",
      );
    }

    // 1) correspondance exacte (forme normalisée, puis singulier, puis forme complète avec article)
    final candidates = <String>{normalized, _n.singular(normalized), _n.fold(text)};
    // 2) la transcription peut contenir des mots en trop : on essaie aussi les sous-séquences
    final words = normalized.split(' ');
    if (words.length > 1) {
      for (var len = words.length - 1; len >= 1; len--) {
        for (var i = 0; i + len <= words.length; i++) {
          final sub = words.sublist(i, i + len).join(' ');
          candidates.add(_n.stripLeading(sub));
        }
      }
    }
    final inCat = <String, String>{}; // concept → alias
    final outCat = <String, String>{};
    for (final c in candidates) {
      final ids = kb.aliasIndex[c] ?? kb.aliasIndex[_n.singular(c)];
      if (ids == null) continue;
      for (final id in ids) {
        if (kb.inCategory(id, categoryId)) {
          inCat.putIfAbsent(id, () => c);
        } else {
          outCat.putIfAbsent(id, () => c);
        }
      }
      if (inCat.isNotEmpty && c == normalized) break; // la forme complète prime
    }

    if (inCat.isNotEmpty) return _decide(text, inCat, categoryId, memory, 1.0);

    // 3) recherche approchée (erreurs de transcription) dans la catégorie
    final fuzzy = _fuzzy(normalized, categoryId);
    if (fuzzy.isNotEmpty) return _decide(text, fuzzy, categoryId, memory, 0.75);

    if (outCat.isNotEmpty) {
      final best = _mostPopular(outCat.keys);
      return AnswerDecision(
        status: AnswerStatus.wrongCategory,
        spokenText: text,
        conceptId: best,
        canonicalConcept: kb.concepts[best]?.name,
        matchedAlias: outCat[best],
        message: '« ${kb.concepts[best]?.name} » ne fait pas partie de la catégorie « ${kb.categories[categoryId]?.name} ».',
      );
    }
    return AnswerDecision(
      status: AnswerStatus.unknown,
      spokenText: text,
      message: 'Je ne connais pas « $text » dans cette catégorie.',
    );
  }

  AnswerDecision _decide(String text, Map<String, String> found, String categoryId, BoomAnswerMemory memory, double confidence) {
    final ids = found.keys.toList()..sort((a, b) => (kb.concepts[b]?.popularity ?? 0).compareTo(kb.concepts[a]?.popularity ?? 0));
    // ambiguïté : plusieurs concepts distincts plausibles et de popularité comparable
    if (ids.length > 1) {
      final p0 = kb.concepts[ids[0]]?.popularity ?? 0;
      final p1 = kb.concepts[ids[1]]?.popularity ?? 0;
      final sameName = _n.normalize(kb.concepts[ids[0]]!.name) == _n.normalize(kb.concepts[ids[1]]!.name);
      if (!sameName && p1 >= p0 * 0.6) {
        // si l'un des deux est déjà utilisé, l'autre est forcément visé
        final free = ids.where((id) => !memory.contains(id)).toList();
        if (free.length == 1) return _single(text, free.first, found[free.first]!, memory, confidence);
        return AnswerDecision(
          status: AnswerStatus.ambiguous,
          spokenText: text,
          alternatives: [for (final id in ids.take(3)) kb.concepts[id]!.name],
          confidence: confidence,
          message: 'Tu veux dire ${ids.take(3).map((id) => '« ${kb.concepts[id]!.name} »').join(' ou ')} ?',
        );
      }
    }
    return _single(text, ids.first, found[ids.first]!, memory, confidence);
  }

  AnswerDecision _single(String text, String id, String alias, BoomAnswerMemory memory, double confidence) {
    final name = kb.concepts[id]?.name ?? text;
    if (memory.contains(id)) {
      final prev = memory.firstSpoken(id)!;
      return AnswerDecision(
        status: AnswerStatus.duplicate,
        spokenText: text,
        conceptId: id,
        canonicalConcept: name,
        previousAnswer: prev,
        matchedAlias: alias,
        confidence: confidence,
        message: _n.normalize(prev) == _n.normalize(text)
            ? '« $prev » a déjà été dit.'
            : '« $text » et « $prev », c\'est la même chose : déjà cité !',
      );
    }
    return AnswerDecision(
      status: AnswerStatus.accepted,
      spokenText: text,
      conceptId: id,
      canonicalConcept: name,
      matchedAlias: alias,
      confidence: confidence,
      message: '« $name » validé !',
    );
  }

  Map<String, String> _fuzzy(String normalized, String categoryId) {
    if (normalized.length < 4) return const {};
    final key = _n.phonetic(normalized);
    final maxD = normalized.length >= 9 ? 2 : 1;
    final best = <String, (int, String)>{};
    for (final (alias, ph, id) in kb.fuzzyIndex[categoryId] ?? const <(String, String, String)>[]) {
      if ((alias.length - normalized.length).abs() > maxD + 1) continue;
      final phonMatch = key.length >= 3 && ph == key;
      final d = TextNormalizer.distance(normalized, alias, max: maxD);
      if (d <= maxD || phonMatch) {
        final score = phonMatch ? 0 : d;
        if (!best.containsKey(id) || best[id]!.$1 > score) best[id] = (score, alias);
      }
    }
    if (best.isEmpty) return const {};
    final top = best.values.map((v) => v.$1).reduce((a, b) => a < b ? a : b);
    return {for (final e in best.entries) if (e.value.$1 == top) e.key: e.value.$2};
  }

  String _mostPopular(Iterable<String> ids) =>
      ids.reduce((a, b) => (kb.concepts[a]?.popularity ?? 0) >= (kb.concepts[b]?.popularity ?? 0) ? a : b);
}

/// Défi à plusieurs réponses : « Cite trois pays commençant par M ».
class ChallengeValidator {
  ChallengeValidator(this.kb) : _v = BoomAnswerValidator(kb);
  final KnowledgeRepository kb;
  final BoomAnswerValidator _v;
  static const _n = TextNormalizer();

  /// Découpe la transcription en propositions (séparateurs « et », virgules,
  /// « puis »…) et valide chacune. Le défi n'est réussi que si toutes les
  /// conditions sont remplies ; rien n'est mémorisé sinon.
  ChallengeResult validate(String spoken, KbChallenge ch, BoomAnswerMemory memory) {
    final parts = _split(spoken);
    final decisions = <AnswerDecision>[];
    final seen = <String>{};
    for (final p in parts) {
      var d = _v.validate(p, ch.categoryId, memory);
      if (d.isAccepted) {
        if (seen.contains(d.conceptId)) {
          d = AnswerDecision(status: AnswerStatus.duplicate, spokenText: p, conceptId: d.conceptId, canonicalConcept: d.canonicalConcept,
              previousAnswer: d.canonicalConcept, message: '« ${d.canonicalConcept} » est répété dans ta réponse.');
        } else if (ch.firstLetter != null && !_n.fold(d.canonicalConcept!).startsWith(ch.firstLetter!) &&
            !_n.fold(p).startsWith(ch.firstLetter!)) {
          d = AnswerDecision(status: AnswerStatus.wrongCategory, spokenText: p, conceptId: d.conceptId, canonicalConcept: d.canonicalConcept,
              message: '« ${d.canonicalConcept} » ne commence pas par ${ch.firstLetter!.toUpperCase()}.');
        } else {
          seen.add(d.conceptId!);
        }
      }
      decisions.add(d);
    }
    final ok = decisions.where((d) => d.isAccepted).toList();
    final success = ok.length >= ch.count;
    if (success) {
      for (final d in ok.take(ch.count)) {
        memory._commit(d);
      }
    }
    memory.history.addAll(decisions);
    return ChallengeResult(success: success, decisions: decisions, needed: ch.count);
  }

  List<String> _split(String spoken) {
    final s = spoken.replaceAll(RegExp(r'\s+(et|puis|ensuite|aussi)\s+', caseSensitive: false), ',');
    final parts = s.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length > 1) return parts;
    // pas de séparateur : segmentation gloutonne par les alias connus
    final words = _n.normalize(spoken).split(' ');
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      var matched = 1;
      for (var len = (words.length - i).clamp(1, 5); len >= 1; len--) {
        final cand = words.sublist(i, i + len).join(' ');
        if (kb.aliasIndex.containsKey(cand) || kb.aliasIndex.containsKey(_n.singular(cand))) {
          matched = len;
          break;
        }
      }
      out.add(words.sublist(i, i + matched).join(' '));
      i += matched;
    }
    return out.where((w) => _n.normalize(w).isNotEmpty).toList();
  }
}

class ChallengeResult {
  const ChallengeResult({required this.success, required this.decisions, required this.needed});
  final bool success;
  final List<AnswerDecision> decisions;
  final int needed;
  int get validCount => decisions.where((d) => d.isAccepted).length;
}
