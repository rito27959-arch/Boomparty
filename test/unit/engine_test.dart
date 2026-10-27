import 'dart:math';

import 'package:boom_party/engine/game_engine.dart';
import 'package:boom_party/engine/normalizer.dart';
import 'package:boom_party/engine/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const norm = WordNormalizer();

  group('WordNormalizer', () {
    test('accents, casse, articles, pluriels', () {
      expect(norm.normalize('Le Réfrigérateur'), norm.normalize('refrigerateurs'));
      expect(norm.normalize("l'éléphant"), 'elephant');
      expect(norm.normalize('Chevaux'), 'cheval');
      expect(norm.normalize('gâteaux'), 'gateau');
      expect(norm.normalize('  une   Chaise !'), 'chaise');
    });
  });

  GameEngine make({int rounds = 2}) {
    final players = [Player(id: 'a', name: 'Emma'), Player(id: 'b', name: 'Léo'), Player(id: 'c', name: 'Max')];
    final objets = categories.firstWhere((c) => c.id == 'objets');
    return GameEngine(players: players, selected: [objets], totalRounds: rounds, random: Random(1));
  }

  test('bonne réponse : +1 point et la bombe passe au joueur suivant', () {
    final e = make()..start();
    final first = e.current;
    expect(e.submit('Table'), AnswerOutcome.correct);
    expect(first.score, 1);
    expect(e.current, isNot(first));
  });

  test('mot déjà dit : refusé, même joueur, liste des mots fournie', () {
    final e = make()..start();
    final events = <GameEvent>[];
    e.events.listen(events.add);
    e.submit('Chaise');
    final p = e.current;
    expect(e.submit('chaises'), AnswerOutcome.alreadySaid);
    expect(e.current, p);
    final rep = events.whereType<AnswerRepeated>().single;
    expect(rep.usedWords, ['Chaise']);
  });

  test('réponse hors catégorie : invalide, aucun point', () {
    final e = make()..start();
    expect(e.submit('girafe'), AnswerOutcome.invalid);
    expect(e.players.every((p) => p.score == 0), isTrue);
  });

  test('mèche écoulée : explosion, le porteur perd 1 point (minimum 0)', () {
    final e = make()..start();
    final events = <GameEvent>[];
    e.events.listen(events.add);
    e.submit('table'); // joueur 1 marque
    final holder = e.current;
    holder.score = 3;
    e.tick(e.fuseLeft + 0.1);
    final ex = events.whereType<Exploded>().single;
    expect(ex.loser, holder);
    expect(holder.score, 2);
    expect(e.running, isFalse);
    expect(events.whereType<TooSlow>(), isNotEmpty);
  });

  test('fin de partie après le nombre de manches, classement trié', () {
    final e = make(rounds: 2)..start();
    final events = <GameEvent>[];
    e.events.listen(events.add);
    e.submit('lampe');
    for (var r = 0; r < 2; r++) {
      e.tick(1000);
      e.continueAfterExplosion();
    }
    final f = events.whereType<GameFinished>().single;
    expect(f.rounds, 2);
    expect(f.explosions, 2);
    expect(f.ranking.first.score >= f.ranking.last.score, isTrue);
    expect(e.finished, isTrue);
  });

  test('toutes les consignes ont des mots et un mot-clé', () {
    for (final c in categories) {
      for (final p in c.prompts) {
        expect(p.words, isNotEmpty);
        expect(p.keyword, isNotEmpty);
      }
    }
  });
}
