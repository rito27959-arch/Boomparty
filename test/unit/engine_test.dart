import 'dart:math';

import 'package:boom_party/engine/game_engine.dart';
import 'package:boom_party/knowledge/answer_validator.dart';
import 'package:boom_party/knowledge/knowledge_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KnowledgeRepository kb;
  setUpAll(() => kb = KnowledgeRepository.open('assets/knowledge/boom_kb.db'));

  GameEngine make({int rounds = 2, GameMode mode = GameMode.cultureGenerale, int challengeEvery = 0}) {
    final players = [Player(id: 'a', name: 'Emma'), Player(id: 'b', name: 'Léo'), Player(id: 'c', name: 'Max')];
    return GameEngine(
      players: players, kb: kb, gameCategories: const ['objets'], onlyKbCategories: const ['objets_cuisine'],
      totalRounds: rounds, mode: mode, challengeEvery: challengeEvery, random: Random(1),
    );
  }

  test('consigne tirée de la base de connaissances', () {
    final e = make()..start();
    expect(e.prompt.categoryId, 'objets_cuisine');
    expect(e.prompt.keyword, isNotEmpty);
    expect(e.vocabulary(), contains('casserole'));
  });

  test('bonne réponse : +1 point et la bombe passe au joueur suivant', () {
    final e = make()..start();
    final first = e.current;
    expect(e.submit('Une casserole !')!.status, AnswerStatus.accepted);
    expect(first.score, 1);
    expect(e.current, isNot(first));
  });

  test('synonyme déjà dit (frigo après réfrigérateur) : refusé, même joueur, sans pénalité', () {
    final e = make()..start();
    final events = <GameEvent>[];
    e.events.listen(events.add);
    e.submit('réfrigérateur');
    final p = e.current;
    final d = e.submit('le frigo')!;
    expect(d.status, AnswerStatus.duplicate);
    expect(d.previousAnswer, 'réfrigérateur');
    expect(e.current, p);
    expect(p.score, 0);
    final rep = events.whereType<AnswerRepeated>().single;
    expect(rep.isSynonym, isTrue);
    expect(rep.usedWords, ['réfrigérateur']);
  });

  test('casserole et poêle sont deux réponses distinctes', () {
    final e = make()..start();
    expect(e.submit('casserole')!.status, AnswerStatus.accepted);
    expect(e.submit('poêle')!.status, AnswerStatus.accepted);
  });

  test('hors catégorie : refusé, aucun point, le tour continue', () {
    final e = make()..start();
    final p = e.current;
    expect(e.submit('éléphant')!.status, AnswerStatus.wrongCategory);
    expect(e.players.every((x) => x.score == 0), isTrue);
    expect(e.current, p);
  });

  test('transcription incertaine : on fait répéter, rien n’est mémorisé, le chrono continue', () {
    final e = make()..start();
    final events = <GameEvent>[];
    e.events.listen(events.add);
    final before = e.fuseLeft;
    expect(e.submit('casserole', asrConfidence: 0.2)!.status, AnswerStatus.recognitionError);
    expect(events.whereType<AnswerNeedsRepeat>(), hasLength(1));
    expect(e.usedWords, isEmpty);
    e.tick(1);
    expect(e.fuseLeft, closeTo(before - 1, 1e-9));
    expect(e.submit('casserole')!.status, AnswerStatus.accepted);
  });

  test('hypothèses alternatives de la reconnaissance : la première valide est retenue', () {
    final e = make()..start();
    final d = e.submit('casse rôle', alternatives: ['casserole'])!;
    expect(d.status, AnswerStatus.accepted);
    expect(d.canonicalConcept, 'casserole');
  });

  test('défi à plusieurs réponses : « trois pays commençant par M »', () {
    final players = [Player(id: 'a', name: 'Emma'), Player(id: 'b', name: 'Léo')];
    final e = GameEngine(players: players, kb: kb, gameCategories: const ['pays'], onlyKbCategories: const ['pays'],
        challengeEvery: 1, random: Random(4))
      ..start();
    expect(e.prompt.challenge, isNotNull);
    final events = <GameEvent>[];
    e.events.listen(events.add);
    final ch = e.prompt.challenge!;
    final good = ch.firstLetter == 'm' ? 'Mali, Maroc et Mexique' : 'Belgique, Brésil et Bénin';
    e.submit(good);
    final r = events.whereType<ChallengeAnswered>().single.result;
    expect(r.success, isTrue, reason: r.decisions.map((d) => d.message).join(' | '));
  });

  test('mèche écoulée : explosion, le porteur perd 1 point (minimum 0)', () {
    final e = make()..start();
    final events = <GameEvent>[];
    e.events.listen(events.add);
    e.submit('fourchette');
    final holder = e.current;
    holder.score = 3;
    e.tick(e.fuseLeft + 0.1);
    final ex = events.whereType<Exploded>().single;
    expect(ex.loser, holder);
    expect(holder.score, 2);
    expect(e.running, isFalse);
    expect(events.whereType<TooSlow>(), isNotEmpty);
  });

  test('mode Extrême : vies, élimination, fin quand il ne reste qu’un joueur', () {
    final e = make(rounds: 99, mode: GameMode.extreme)..start(firstPlayer: 0);
    final events = <GameEvent>[];
    e.events.listen(events.add);
    while (!e.finished) {
      e.tick(1000);
      e.continueAfterExplosion();
    }
    expect(e.activePlayers.length, lessThan(2));
    expect(events.whereType<Exploded>().where((x) => x.eliminated), isNotEmpty);
  });

  test('fin de partie après le nombre de manches, classement trié, mémoire remise à zéro', () {
    final e = make(rounds: 2)..start();
    final events = <GameEvent>[];
    e.events.listen(events.add);
    e.submit('louche');
    expect(e.usedWords, ['louche']);
    e.tick(1000);
    e.continueAfterExplosion();
    expect(e.usedWords, isEmpty);
    e.tick(1000);
    e.continueAfterExplosion();
    final f = events.whereType<GameFinished>().single;
    expect(f.rounds, 2);
    expect(f.explosions, 2);
    expect(f.ranking.first.score >= f.ranking.last.score, isTrue);
  });
}
