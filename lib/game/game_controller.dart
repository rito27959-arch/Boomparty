import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../character/bomb_state.dart';
import '../engine/game_engine.dart';
import '../services/answer_input.dart';
import '../services/audio_director.dart';

enum Phase { listening, correct, repeated, invalid, tooSlow, exploding, exploded, finished }

/// Relie le moteur de règles, la saisie (voix/clavier), l'audio et l'affichage.
/// L'interface lit [phase] et [bombState] ; elle ne décide jamais des règles.
class GameController extends ChangeNotifier {
  GameController({required this.engine, required this.input, AudioDirector? audio, this.reducedMotion = false, this.vibrations = true})
      : audio = audio ?? AudioDirector.silent() {
    _sub = engine.events.listen(_onEvent);
    _inSub = input.answers.listen(answer);
  }

  final GameEngine engine;
  final AnswerInput input;
  final AudioDirector audio;
  final bool reducedMotion;
  final bool vibrations;
  late final StreamSubscription<GameEvent> _sub;
  late final StreamSubscription<String> _inSub;

  Phase phase = Phase.listening;
  String lastWord = '';
  Player? loser;
  GameFinished? result;
  double _phaseT = 0;
  bool _slowPending = false;

  static const correctPause = 1.3;
  static const explosionDuration = 1.6;

  Player get player => engine.current;
  double get fuse => engine.fuseFraction;

  BombState get bombState => switch (phase) {
        // la bombe pose la question (parle) puis écoute le joueur
        Phase.listening => _phaseT < 1.6 ? BombState.talking : BombState.listening,
        Phase.correct => BombState.happy,
        Phase.repeated => BombState.angry,
        Phase.invalid => BombState.confused,
        Phase.tooSlow => BombState.panic,
        Phase.exploding => _phaseT < 0.55 ? BombState.countdown : BombState.explosion,
        Phase.exploded || Phase.finished => BombState.defeated,
      };

  void start({int? firstPlayer}) {
    engine.start(firstPlayer: firstPlayer);
    input.start();
  }

  void answer(String word) {
    if (phase == Phase.exploding || phase == Phase.exploded || phase == Phase.finished) return;
    engine.submit(word);
  }

  void retry() {
    if (phase == Phase.repeated || phase == Phase.invalid) _set(Phase.listening);
  }

  void continueAfterExplosion() {
    if (phase != Phase.exploded) return;
    engine.continueAfterExplosion();
  }

  void tick(double dt) {
    final before = bombState;
    _phaseT += dt;
    engine.tick(dt);
    if (phase == Phase.listening && before != bombState) notifyListeners();
    if (phase == Phase.correct && _phaseT >= correctPause) {
      _set(_slowPending ? Phase.tooSlow : Phase.listening);
      _slowPending = false;
    } else if (phase == Phase.exploding) {
      final before = bombState;
      if (_phaseT >= explosionDuration) {
        _set(Phase.exploded);
      } else if (before != bombState) {
        notifyListeners();
      }
    }
  }

  void _onEvent(GameEvent e) {
    switch (e) {
      case TurnStarted():
        if (phase != Phase.correct) _set(Phase.listening);
        audio.cue(VoiceCue.yourTurn, name: e.player.name);
      case AnswerAccepted():
        lastWord = e.word;
        _slowPending = false;
        _set(Phase.correct);
        audio.cue(VoiceCue.correct);
        if (vibrations) HapticFeedback.lightImpact();
      case AnswerRepeated():
        lastWord = e.word;
        _set(Phase.repeated);
        audio.cue(VoiceCue.repeated);
        if (vibrations) HapticFeedback.mediumImpact();
      case AnswerRejected():
        lastWord = e.word;
        _set(Phase.invalid);
        audio.cue(VoiceCue.invalid);
      case TooSlow():
        if (phase == Phase.correct) {
          _slowPending = true;
        } else if (phase == Phase.listening) {
          _set(Phase.tooSlow);
        }
        audio.cue(VoiceCue.hurry);
      case Exploded():
        loser = e.loser;
        _set(Phase.exploding);
        input.stop();
        audio.cue(VoiceCue.explosion);
        if (vibrations) {
          HapticFeedback.heavyImpact();
          Future<void>.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact);
        }
      case GameFinished():
        result = e;
        _set(Phase.finished);
        audio.cue(VoiceCue.celebration);
    }
    if (e is TurnStarted && phase == Phase.listening) input.start();
  }

  void _set(Phase p) {
    phase = p;
    _phaseT = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    _inSub.cancel();
    input.stop();
    super.dispose();
  }
}
