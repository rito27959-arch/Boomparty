import 'dart:async';
import 'dart:math' as math;

import 'normalizer.dart';
import 'word_bank.dart';

class Player {
  Player({required this.id, required this.name, this.avatar = 0, this.score = 0});
  final String id;
  String name;
  int avatar;
  int score;
}

enum GameMode { cultureGenerale, completementFou, entreAmis, reflexes, extreme }

/// Durée de mèche (secondes) par mode : tirée au hasard dans l'intervalle,
/// inconnue des joueurs.
const fuseRange = <GameMode, (double, double)>{
  GameMode.cultureGenerale: (25, 45),
  GameMode.completementFou: (20, 40),
  GameMode.entreAmis: (25, 45),
  GameMode.reflexes: (12, 25),
  GameMode.extreme: (8, 18),
};

enum AnswerOutcome { correct, alreadySaid, invalid, ignored }

sealed class GameEvent {
  const GameEvent();
}

class TurnStarted extends GameEvent {
  const TurnStarted(this.player, this.prompt);
  final Player player;
  final Prompt prompt;
}

class AnswerAccepted extends GameEvent {
  const AnswerAccepted(this.player, this.word);
  final Player player;
  final String word;
}

class AnswerRepeated extends GameEvent {
  const AnswerRepeated(this.player, this.word, this.usedWords);
  final Player player;
  final String word;
  final List<String> usedWords;
}

class AnswerRejected extends GameEvent {
  const AnswerRejected(this.player, this.word);
  final Player player;
  final String word;
}

/// Émis quand le joueur traîne : la bombe panique.
class TooSlow extends GameEvent {
  const TooSlow(this.player, this.fuseLeft);
  final Player player;
  final double fuseLeft; // 0..1
}

class Exploded extends GameEvent {
  const Exploded(this.loser);
  final Player loser;
}

class GameFinished extends GameEvent {
  const GameFinished(this.ranking, this.rounds, this.explosions);
  final List<Player> ranking;
  final int rounds, explosions;
  Player get winner => ranking.first;
}

/// Moteur de règles BOOM PARTY. Ne connaît ni l'interface ni les animations :
/// il reçoit des réponses et le temps qui passe, et émet des [GameEvent].
class GameEngine {
  GameEngine({
    required List<Player> players,
    required List<WordCategory> selected,
    this.mode = GameMode.cultureGenerale,
    this.totalRounds = 12,
    this.slowAfter = 7,
    math.Random? random,
  })  : assert(players.length >= 2, 'Il faut au moins 2 joueurs'),
        assert(selected.isNotEmpty),
        players = List.unmodifiable(players),
        _rng = random ?? math.Random(),
        _prompts = [for (final c in selected) ...c.prompts];

  final List<Player> players;
  final GameMode mode;
  final int totalRounds;
  final double slowAfter; // secondes sans bonne réponse avant « Trop lent »
  final math.Random _rng;
  final List<Prompt> _prompts;
  static const _norm = WordNormalizer();

  final _events = StreamController<GameEvent>.broadcast(sync: true);
  Stream<GameEvent> get events => _events.stream;

  int round = 0;
  int explosions = 0;
  int _turn = 0;
  late Prompt prompt;
  late Set<String> _accepted;
  final List<String> usedWords = [];
  final Set<String> _usedNorm = {};
  double fuseTotal = 0, fuseLeft = 0, _sinceAnswer = 0;
  bool _slowSent = false;
  bool running = false;
  bool finished = false;

  Player get current => players[_turn % players.length];
  double get fuseFraction => fuseTotal == 0 ? 0 : (fuseLeft / fuseTotal).clamp(0, 1);

  void start({int? firstPlayer}) {
    round = 0;
    explosions = 0;
    finished = false;
    for (final p in players) {
      p.score = 0;
    }
    _turn = firstPlayer ?? _rng.nextInt(players.length);
    _nextRound();
  }

  void _nextRound() {
    round++;
    prompt = _prompts[_rng.nextInt(_prompts.length)];
    _accepted = {for (final w in prompt.words) _norm.normalize(w)};
    usedWords.clear();
    _usedNorm.clear();
    final (lo, hi) = fuseRange[mode]!;
    fuseTotal = lo + _rng.nextDouble() * (hi - lo);
    fuseLeft = fuseTotal;
    _sinceAnswer = 0;
    _slowSent = false;
    running = true;
    _events.add(TurnStarted(current, prompt));
  }

  AnswerOutcome submit(String raw) {
    if (!running || raw.trim().isEmpty) return AnswerOutcome.ignored;
    final n = _norm.normalize(raw);
    if (_usedNorm.contains(n)) {
      _events.add(AnswerRepeated(current, raw.trim(), List.unmodifiable(usedWords)));
      return AnswerOutcome.alreadySaid;
    }
    if (!_accepted.contains(n)) {
      _events.add(AnswerRejected(current, raw.trim()));
      return AnswerOutcome.invalid;
    }
    _usedNorm.add(n);
    usedWords.add(_display(raw));
    current.score += 1;
    _events.add(AnswerAccepted(current, usedWords.last));
    _turn++;
    _sinceAnswer = 0;
    _slowSent = false;
    _events.add(TurnStarted(current, prompt));
    return AnswerOutcome.correct;
  }

  static String _display(String raw) {
    final t = raw.trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  /// Fait avancer le temps de [dt] secondes.
  void tick(double dt) {
    if (!running) return;
    fuseLeft -= dt;
    _sinceAnswer += dt;
    if (!_slowSent && (_sinceAnswer >= slowAfter || fuseFraction < 0.25)) {
      _slowSent = true;
      _events.add(TooSlow(current, fuseFraction));
    }
    if (fuseLeft <= 0) {
      fuseLeft = 0;
      running = false;
      explosions++;
      final loser = current;
      loser.score = math.max(0, loser.score - 1);
      _events.add(Exploded(loser));
    }
  }

  /// Appelé par l'interface après l'écran d'explosion.
  void continueAfterExplosion() {
    if (running || finished) return;
    if (round >= totalRounds) {
      finished = true;
      _events.add(GameFinished(ranking, round, explosions));
    } else {
      _nextRound();
    }
  }

  List<Player> get ranking => [...players]..sort((a, b) => b.score.compareTo(a.score));

  void dispose() => _events.close();
}
