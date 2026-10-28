import 'dart:convert';
import 'dart:io';

import 'package:boom_party/knowledge/answer_validator.dart';
import 'package:boom_party/knowledge/knowledge_repository.dart';
import 'package:boom_party/knowledge/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const n = TextNormalizer();
  late KnowledgeRepository kb;
  late BoomAnswerValidator v;

  setUpAll(() {
    kb = KnowledgeRepository.open('assets/knowledge/boom_kb.db');
    v = BoomAnswerValidator(kb);
  });

  test('normalisation identique à la version Python du pipeline', () {
    final cases = jsonDecode(File('test/unit/fixtures/normalize_cases.json').readAsStringSync()) as List;
    for (final c in cases.cast<Map<String, dynamic>>()) {
      expect(n.fold(c['input'] as String), c['fold'], reason: 'fold(${c['input']})');
      expect(n.normalize(c['input'] as String), c['normalize'], reason: 'normalize(${c['input']})');
      expect(n.singular(n.normalize(c['input'] as String)), c['singular'], reason: 'singular(${c['input']})');
    }
  });

  test('la base contient les catégories jouables et des milliers d’alias', () {
    expect(kb.categories.keys, containsAll(['animaux', 'pays', 'objets_maison', 'objets_cuisine', 'metiers', 'sports']));
    expect(kb.aliasIndex.length, greaterThan(1500));
    for (final c in kb.categories.values) {
      expect(kb.members[c.id], isNotEmpty, reason: c.id);
      expect(c.prompts, isNotEmpty, reason: c.id);
    }
  });

  test('scénario de la directive : cuisine, frigo = réfrigérateur, éléphant hors catégorie', () {
    final m = BoomAnswerMemory();
    const cat = 'objets_cuisine';
    expect(v.validateAndCommit('Casserole !', cat, m).status, AnswerStatus.accepted);
    expect(v.validateAndCommit('Réfrigérateur !', cat, m).status, AnswerStatus.accepted);
    final frigo = v.validateAndCommit('Frigo !', cat, m);
    expect(frigo.status, AnswerStatus.duplicate);
    expect(frigo.previousAnswer, 'Réfrigérateur');
    expect(v.validateAndCommit('Fourchette !', cat, m).status, AnswerStatus.accepted);
    final el = v.validateAndCommit('Éléphant !', cat, m);
    expect(el.status, AnswerStatus.wrongCategory);
    expect(m.length, 3); // les réponses refusées ne sont pas mémorisées
  });

  test('formulations naturelles : articles, pluriels, hésitations', () {
    final m = BoomAnswerMemory();
    expect(v.validate('Un réfrigérateur.', 'objets_maison', m).status, AnswerStatus.accepted);
    expect(v.validate('Le frigo.', 'objets_maison', m).status, AnswerStatus.accepted);
    expect(v.validate('Une télé.', 'objets_maison', m).canonicalConcept, isNotNull);
    expect(v.validate('Des casseroles.', 'objets_cuisine', m).status, AnswerStatus.accepted);
    expect(v.validate('Le Cameroun.', 'pays', m).status, AnswerStatus.accepted);
    expect(v.validate('Une voiture.', 'vehicules', m).status, AnswerStatus.accepted);
    expect(v.validate('Un ordinateur portable.', 'objets_maison', m).status, AnswerStatus.accepted);
    expect(v.validate('Une table à manger.', 'objets_maison', m).status, AnswerStatus.accepted);
    expect(v.validate('euh… le chien', 'animaux', m).status, AnswerStatus.accepted);
  });

  test('télé / télévision / téléviseur = même concept ; casserole ≠ poêle', () {
    final m = BoomAnswerMemory();
    v.validateAndCommit('télévision', 'objets_maison', m);
    expect(v.validate('télé', 'objets_maison', m).status, AnswerStatus.duplicate);
    expect(v.validate('téléviseur', 'objets_maison', m).status, AnswerStatus.duplicate);
    final m2 = BoomAnswerMemory();
    v.validateAndCommit('casserole', 'objets_cuisine', m2);
    expect(v.validate('poêle', 'objets_cuisine', m2).status, AnswerStatus.accepted);
    final m3 = BoomAnswerMemory();
    v.validateAndCommit('lion', 'animaux', m3);
    expect(v.validate('tigre', 'animaux', m3).status, AnswerStatus.accepted);
  });

  test('orange : fruit et couleur restent deux concepts', () {
    final a = v.validate('orange', 'fruits', BoomAnswerMemory());
    final b = v.validate('orange', 'couleurs', BoomAnswerMemory());
    expect(a.status, AnswerStatus.accepted);
    expect(b.status, AnswerStatus.accepted);
    expect(a.conceptId, isNot(b.conceptId));
  });

  test('erreur de reconnaissance : jamais pénalisante', () {
    final m = BoomAnswerMemory();
    expect(v.validate('', 'animaux', m).status, AnswerStatus.recognitionError);
    expect(v.validate('euh', 'animaux', m).status, AnswerStatus.recognitionError);
    expect(v.validate('chien', 'animaux', m, asrConfidence: 0.1).status, AnswerStatus.recognitionError);
    expect(v.validate('chien', 'animaux', m).needsRepeat, isFalse);
  });

  test('transcription approximative reconnue avec une confiance réduite', () {
    final d = v.validate('réfrijérateur', 'objets_maison', BoomAnswerMemory());
    expect(d.status, AnswerStatus.accepted);
    expect(d.confidence, lessThan(1));
  });

  test('mot inconnu', () {
    expect(v.validate('xylotrombone', 'animaux', BoomAnswerMemory()).status, AnswerStatus.unknown);
  });

  test('défi « trois pays commençant par M »', () {
    final ch = kb.challenges['pays_m']!;
    final cv = ChallengeValidator(kb);
    final m = BoomAnswerMemory();
    expect(cv.validate('Maroc, Mali et Mexique', ch, m).success, isTrue);
    expect(m.length, 3);
    final m2 = BoomAnswerMemory();
    expect(cv.validate('Maroc, Maroc et Mali', ch, m2).success, isFalse);
    expect(m2.length, 0);
    expect(cv.validate('Maroc, Brésil et Mali', ch, BoomAnswerMemory()).success, isFalse);
    expect(cv.validate('Maroc Mali Mexique', ch, BoomAnswerMemory()).success, isTrue);
  });
}
