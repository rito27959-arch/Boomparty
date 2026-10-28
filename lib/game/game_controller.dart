import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../character/bomb_state.dart';
import '../engine/game_engine.dart';
import '../knowledge/answer_validator.dart';
import '../personality/personality_engine.dart';
import '../services/answer_input.dart';
import '../speech/reaction_speaker.dart';

enum Phase { listening, correct, repeated, invalid, unclear, tooSlow, exploding, exploded, finished }

/// Chaîne complète : GameEvent → analyse du contexte → personnalité →
/// sélection de réplique → voix → animation. L'interface lit [phase],
/// [bombState] et [feedback] ; elle ne décide jamais des règles.
class GameController extends ChangeNotifier {
  GameController({
    required this.engine,
    required this.input,
    PersonalityEngine? personality,
    ReactionSpeaker? speaker,
    this.reducedMotion = false,
    this.vibrations = true,
    this.expressive = true,
  })  : personality = personality ?? PersonalityEngine(),
        speaker = speaker ?? SilentSpeaker() {
    _sub = engine.events.listen(_onEvent);
    _inSub = input.answers.listen(answer);
    this.speaker.speaking.addListener(_onSpeaking);
  }

  final GameEngine engine;
  final AnswerInput input;
  final PersonalityEngine personality;
  final ReactionSpeaker speaker;
  final bool reducedMotion;
  final bool vibrations;

  /// Si vrai, l'émotion de la réplique choisie pilote l'animation (rire,
  /// colère…) ; sinon l'état visuel dépend seulement de la phase.
  final bool expressive;

  late final StreamSubscription<GameEvent> _sub;
  late final StreamSubscription<HeardAnswer> _inSub;

  Phase phase = Phase.listening;
  String lastWord = '';
  Player? loser;
  GameFinished? result;
  AnswerDecision? lastDecision;
  ChallengeResult? lastChallenge;
  Reaction? lastReaction;

  /// Toutes les réactions de la partie (tests, statistiques).
  final List<Reaction> reactions = [];
  double _phaseT = 0;
  double _speakingFor = 0;
  static const maxSpeakingSeconds = 12.0;
  bool _slowPending = false;

  static const correctPause = 1.3;
  static const feedbackPause = 2.6; // retour automatique à l'écoute
  static const explosionDuration = 1.6;

  Player get player => engine.current;
  double get fuse => engine.fuseFraction;
  bool get speaking => speaker.speaking.value;

  BombState get bombState {
    final emo = expressive ? lastReaction?.emotion : null;
    return switch (phase) {
      // la bombe pose la question (parle) puis écoute le joueur
      Phase.listening => (speaking || (speaker is SilentSpeaker && _phaseT < 1.6)) ? BombState.talking : BombState.listening,
      Phase.correct => emo == BombState.laughing || emo == BombState.celebration ? emo! : BombState.happy,
      Phase.repeated => emo == BombState.laughing ? BombState.laughing : BombState.angry,
      Phase.invalid => emo == BombState.angry || emo == BombState.laughing ? emo! : BombState.confused,
      Phase.unclear => _phaseT < 0.5 ? BombState.thinking : BombState.confused,
      Phase.tooSlow => BombState.panic,
      Phase.exploding => _phaseT < 0.55 ? BombState.countdown : BombState.explosion,
      Phase.exploded || Phase.finished => BombState.defeated,
    };
  }

  /// Titre et texte de la bulle des écrans « déjà dit », « hors catégorie »
  /// et « répète ».
  (String, String) get feedback {
    final d = lastDecision;
    switch (phase) {
      case Phase.repeated:
        final prev = d?.previousAnswer;
        if (prev != null && TextFold.differs(prev, d!.spokenText)) {
          return ('Oups !', '« ${_short(d.spokenText)} » = « $prev »\nDéjà dit !');
        }
        return ('Oups !', 'Ce mot a déjà été dit !');
      case Phase.invalid:
        if (lastChallenge != null) {
          final bad = lastChallenge!.decisions.where((x) => !x.isAccepted).firstOrNull;
          return ('Hmm…', bad?.message ?? 'Il en faut ${lastChallenge!.needed} !');
        }
        if (d?.status == AnswerStatus.unknown) return ('Hmm…', 'Je ne connais pas\n« ${_short(lastWord)} » !');
        return ('Hmm…', '« ${_short(lastWord)} » ne rentre pas\ndans la catégorie !');
      case Phase.unclear:
        if (d?.status == AnswerStatus.ambiguous && d!.alternatives.length >= 2) {
          return ('Hein ?', 'Tu veux dire\n${d.alternatives.take(2).join(' ou ')} ?');
        }
        return ('Hein ?', "Je n'ai pas bien compris…\nRépète !");
      default:
        return ('', '');
    }
  }

  static String _short(String s) => s.length > 22 ? '${s.substring(0, 21)}…' : s;

  void start({int? firstPlayer}) {
    _react(ReactionEvent.gameStart);
    engine.start(firstPlayer: firstPlayer);
    input.start();
  }

  void answer(HeardAnswer a) {
    if (phase == Phase.exploding || phase == Phase.exploded || phase == Phase.finished) return;
    engine.submit(a.text, asrConfidence: a.confidence, alternatives: a.alternatives);
  }

  /// Saisie de secours au clavier (le chrono continue pendant la saisie).
  void typed(String word) => answer(HeardAnswer(word));

  void retry() {
    if (phase == Phase.repeated || phase == Phase.invalid || phase == Phase.unclear) _set(Phase.listening);
  }

  void continueAfterExplosion() {
    if (phase != Phase.exploded) return;
    engine.continueAfterExplosion();
  }

  void tick(double dt) {
    final before = bombState;
    _phaseT += dt;
    engine.tick(dt);
    speaker.lipSync.tick();
    // garde-fou : si la bombe semble parler trop longtemps, on rouvre le micro
    _speakingFor = speaking ? _speakingFor + dt : 0;
    if (_speakingFor > maxSpeakingSeconds && input.muted) input.muted = false;
    if (phase == Phase.correct && _phaseT >= correctPause) {
      _set(_slowPending ? Phase.tooSlow : Phase.listening);
      _slowPending = false;
    } else if ((phase == Phase.repeated || phase == Phase.invalid || phase == Phase.unclear) && _phaseT >= feedbackPause) {
      _set(Phase.listening);
    } else if (phase == Phase.exploding && _phaseT >= explosionDuration) {
      _set(Phase.exploded);
    } else if (before != bombState) {
      notifyListeners();
    }
  }

  void _onSpeaking() {
    // jamais de transcription de la voix de la bombe
    input.muted = speaker.speaking.value;
    notifyListeners();
  }

  void _react(ReactionEvent e, [ReactionContext ctx = const ReactionContext()]) {
    final r = personality.react(e, ctx);
    lastReaction = r;
    reactions.add(r);
    unawaited(speaker.speak(r, personality.profile));
  }

  void _onEvent(GameEvent e) {
    switch (e) {
      case RoundStarted():
        _set(Phase.listening);
        _react(ReactionEvent.roundStart, ReactionContext(name: e.player.name, category: e.prompt.categoryName));
        unawaited(input.setVocabulary(engine.vocabulary()));
        input.start();
      case TurnStarted():
        if (phase != Phase.correct) _set(Phase.listening);
        // après une bonne réponse, la réplique « bravo » suffit : pas de « à toi » par-dessus
        if (phase != Phase.correct) _react(ReactionEvent.yourTurn, ReactionContext(name: e.player.name));
      case AnswerAccepted():
        lastWord = e.decision.canonicalConcept ?? e.word;
        lastDecision = e.decision;
        lastChallenge = null;
        _slowPending = false;
        final ev = e.streak >= 3
            ? ReactionEvent.acceptedStreak
            : e.fast
                ? ReactionEvent.acceptedFast
                : ReactionEvent.accepted;
        _react(ev, ReactionContext(name: e.player.name, word: lastWord, streak: e.streak));
        _set(Phase.correct);
        if (vibrations) HapticFeedback.lightImpact();
      case AnswerRepeated():
        lastWord = e.word;
        lastDecision = e.decision;
        lastChallenge = null;
        _react(e.isSynonym ? ReactionEvent.duplicateSynonym : ReactionEvent.duplicate,
            ReactionContext(name: e.player.name, word: e.word, previous: e.decision.previousAnswer));
        _set(Phase.repeated);
        if (vibrations) HapticFeedback.mediumImpact();
      case AnswerRejected():
        lastWord = e.word;
        lastDecision = e.decision;
        lastChallenge = null;
        _react(e.decision.status == AnswerStatus.unknown ? ReactionEvent.unknown : ReactionEvent.wrongCategory,
            ReactionContext(name: e.player.name, word: e.word, category: engine.prompt.categoryName));
        _set(Phase.invalid);
      case AnswerNeedsRepeat():
        // transcription incertaine : aucune pénalité, le chrono continue
        lastWord = e.decision.spokenText;
        lastDecision = e.decision;
        lastChallenge = null;
        _react(e.decision.status == AnswerStatus.ambiguous ? ReactionEvent.ambiguous : ReactionEvent.recognitionError,
            ReactionContext(name: e.player.name, word: e.decision.spokenText, alternatives: e.decision.alternatives.take(2).toList()));
        _set(Phase.unclear);
      case ChallengeAnswered():
        lastChallenge = e.result;
        lastDecision = null;
        if (e.result.success) {
          lastWord = e.result.decisions.where((d) => d.isAccepted).map((d) => d.canonicalConcept).join(', ');
          _react(ReactionEvent.acceptedStreak, ReactionContext(name: e.player.name, word: lastWord, streak: e.result.needed));
          _set(Phase.correct);
          if (vibrations) HapticFeedback.lightImpact();
        } else if (e.result.decisions.isEmpty || e.result.decisions.every((d) => d.status == AnswerStatus.recognitionError)) {
          _react(ReactionEvent.recognitionError, ReactionContext(name: e.player.name));
          _set(Phase.unclear);
        } else {
          final dup = e.result.decisions.where((d) => d.status == AnswerStatus.duplicate).firstOrNull;
          _react(dup != null ? ReactionEvent.duplicate : ReactionEvent.wrongCategory,
              ReactionContext(name: e.player.name, word: (dup ?? e.result.decisions.first).spokenText, category: engine.prompt.categoryName));
          _set(Phase.invalid);
        }
      case TooSlow():
        if (phase == Phase.correct) {
          _slowPending = true;
        } else if (phase == Phase.listening) {
          _set(Phase.tooSlow);
        }
        _react(ReactionEvent.hurry, ReactionContext(name: e.player.name));
      case Exploded():
        loser = e.loser;
        _react(ReactionEvent.explosion, ReactionContext(name: e.loser.name));
        _set(Phase.exploding);
        input.stop();
        if (vibrations) {
          HapticFeedback.heavyImpact();
          Future<void>.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact);
        }
      case GameFinished():
        result = e;
        _react(ReactionEvent.gameEnd, ReactionContext(name: e.winner.name));
        _set(Phase.finished);
    }
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
    speaker.speaking.removeListener(_onSpeaking);
    input.stop();
    super.dispose();
  }
}

/// Petit utilitaire : deux formulations diffèrent-elles (hors casse/accents) ?
class TextFold {
  static String _f(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-zà-ÿœæ]'), '');
  static bool differs(String a, String b) => _f(a) != _f(b);
}
