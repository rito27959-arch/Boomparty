import 'dart:math';

import 'package:boom_party/character/bomb_state.dart';
import 'package:boom_party/engine/game_engine.dart';
import 'package:boom_party/engine/word_bank.dart';
import 'package:boom_party/game/game_controller.dart';
import 'package:boom_party/services/answer_input.dart';
import 'package:boom_party/services/audio_director.dart';
import 'package:flutter_test/flutter_test.dart';

GameController make({int rounds = 2}) {
  final players = [Player(id: 'a', name: 'Emma'), Player(id: 'b', name: 'Max')];
  return GameController(
    engine: GameEngine(players: players, selected: [categories.firstWhere((c) => c.id == 'objets')], totalRounds: rounds, random: Random(2)),
    input: ManualAnswerInput(),
    vibrations: false,
  )..start(firstPlayer: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('mot répété → colère, Réessaie → écoute', () {
    final c = make();
    c.answer('table');
    c.tick(2);
    c.answer('tables');
    expect(c.phase, Phase.repeated);
    expect(c.bombState, BombState.angry);
    c.retry();
    expect(c.phase, Phase.listening);
  });

  test('hors catégorie → confusion', () {
    final c = make();
    c.answer('girafe');
    expect(c.phase, Phase.invalid);
    expect(c.bombState, BombState.confused);
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
    expect(c.audio.history, containsAllInOrder([VoiceCue.hurry, VoiceCue.explosion, VoiceCue.celebration]));
  });

  test('sous-titre personnalisé de la réplique', () {
    final a = AudioDirector.silent();
    a.cue(VoiceCue.explosion);
    a.cue(VoiceCue.yourTurn, name: 'Léo');
    expect(a.subtitle.value, 'À toi, Léo !');
  });
}
