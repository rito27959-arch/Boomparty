import 'dart:math';

import 'package:boom_party/character/bomb_state.dart';
import 'package:boom_party/engine/game_engine.dart';
import 'package:boom_party/game/game_controller.dart';
import 'package:boom_party/knowledge/knowledge_repository.dart';
import 'package:boom_party/personality/personality_engine.dart';
import 'package:boom_party/services/answer_input.dart';
import 'package:boom_party/speech/reaction_speaker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

late KnowledgeRepository kb;

GameController make({int rounds = 2, bool expressive = false, ReactionSpeaker? speaker}) {
  final players = [Player(id: 'a', name: 'Emma'), Player(id: 'b', name: 'Max')];
  return GameController(
    engine: GameEngine(players: players, kb: kb, gameCategories: const ['objets'], onlyKbCategories: const ['objets_maison'],
        totalRounds: rounds, challengeEvery: 0, random: Random(2)),
    input: ManualAnswerInput(),
    personality: PersonalityEngine(random: Random(5)),
    speaker: speaker,
    vibrations: false,
    expressive: expressive,
  )..start(firstPlayer: 0);
}

/// Haut-parleur de test : « parle » jusqu'à ce qu'on l'arrête.
class FakeSpeaker extends SilentSpeaker {
  final talking = ValueNotifier(false);
  @override
  ValueListenable<bool> get speaking => talking;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => kb = KnowledgeRepository.open('assets/knowledge/boom_kb.db'));

  test('la voix (micro/clavier) alimente le moteur et la bombe réagit', () async {
    final c = make();
    (c.input as ManualAnswerInput).submit('table');
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, Phase.correct);
    expect(c.bombState, BombState.happy);
    c.tick(GameController.correctPause + 0.01);
    expect(c.phase, Phase.listening);
    expect(c.player.name, 'Max');
  });

  test('synonyme répété → colère + texte « frigo = réfrigérateur », Réessaie → écoute', () {
    final c = make();
    c.typed('réfrigérateur');
    c.tick(2);
    c.typed('frigo');
    expect(c.phase, Phase.repeated);
    expect(c.bombState, BombState.angry);
    expect(c.feedback.$2, contains('réfrigérateur'));
    expect(c.reactions.last.event, ReactionEvent.duplicateSynonym);
    c.retry();
    expect(c.phase, Phase.listening);
  });

  test('hors catégorie → confusion, retour automatique à l’écoute', () {
    final c = make();
    c.typed('girafe');
    expect(c.phase, Phase.invalid);
    expect(c.bombState, BombState.confused);
    c.tick(GameController.feedbackPause + 0.01);
    expect(c.phase, Phase.listening);
  });

  test('transcription incertaine → « répète », réflexion puis confusion, aucune pénalité', () {
    final c = make();
    c.answer(const HeardAnswer('table', confidence: 0.1));
    expect(c.phase, Phase.unclear);
    expect(c.bombState, BombState.thinking);
    c.tick(0.6);
    expect(c.bombState, BombState.confused);
    expect(c.engine.players.every((p) => p.score == 0), isTrue);
    expect(c.engine.usedWords, isEmpty);
  });

  test('la bombe ne s’écoute jamais : micro coupé pendant qu’elle parle', () {
    final s = FakeSpeaker();
    final c = make(speaker: s);
    s.talking.value = true;
    expect(c.input.muted, isTrue);
    expect(c.bombState, BombState.talking);
    s.talking.value = false;
    expect(c.input.muted, isFalse);
  });

  test('chaîne événement → personnalité → réplique : prénoms et mots insérés', () {
    final c = make();
    expect(c.reactions.map((r) => r.event), containsAllInOrder([ReactionEvent.gameStart, ReactionEvent.roundStart]));
    expect(c.reactions[1].text, isNot(contains('{')));
    c.typed('canapé');
    expect(c.reactions.last.event, anyOf(ReactionEvent.accepted, ReactionEvent.acceptedFast));
  });

  test('séquence complète : panique → explosion → étourdie → fin de partie', () {
    final c = make(rounds: 1);
    c.tick(c.engine.fuseTotal * 0.8);
    expect(c.phase, Phase.tooSlow);
    expect(c.bombState, BombState.panic);
    c.tick(c.engine.fuseTotal);
    expect(c.phase, Phase.exploding);
    expect(c.loser?.name, 'Emma');
    c.tick(GameController.explosionDuration + 0.01);
    expect(c.phase, Phase.exploded);
    expect(c.bombState, BombState.defeated);
    c.continueAfterExplosion();
    expect(c.phase, Phase.finished);
    expect(c.result?.rounds, 1);
    expect(c.reactions.map((r) => r.event), containsAllInOrder([ReactionEvent.hurry, ReactionEvent.explosion, ReactionEvent.gameEnd]));
  });

  test('personnalités : jamais deux fois la même réplique d’affilée sur 30 tirages', () {
    for (final p in PersonalityId.values) {
      final e = PersonalityEngine(profile: p, random: Random(9));
      String? last;
      for (var i = 0; i < 30; i++) {
        final r = e.react(ReactionEvent.duplicate, const ReactionContext(name: 'Léo', word: 'frigo', previous: 'réfrigérateur'));
        if (e.poolSize(ReactionEvent.duplicate) > 1) expect(r.line.id, isNot(last));
        expect(r.text, isNot(contains('{')));
        last = r.line.id;
      }
    }
  });
}
