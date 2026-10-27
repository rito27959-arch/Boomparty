import 'dart:async';
import 'dart:math' as math;

import '../knowledge/answer_validator.dart';
import '../knowledge/knowledge_repository.dart';
import '../knowledge/text_normalizer.dart';

class Player {
  Player({required this.id, required this.name, this.avatar = 0, this.score = 0, this.lives = 3});
  final String id;
  String name;
  int avatar;
  int score;
  int lives;
  bool get eliminated => lives <= 0;
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

/// En mode Extrême, une explosion coûte une vie (élimination à 0) ;
/// dans les autres modes, elle coûte un point.
bool usesLives(GameMode m) => m == GameMode.extreme;

/// Consigne de la manche (catégorie simple ou défi à plusieurs réponses).
class RoundPrompt {
  const RoundPrompt({required this.categoryId, required this.categoryName, required this.prompt, this.challenge});
  final String categoryId;
  final String categoryName;
  final KbPrompt prompt;
  final KbChallenge? challenge;
  String get lead => prompt.lead;
  String get keyword => prompt.keyword;
  String get tail => prompt.tail;
}

sealed class GameEvent {
  const GameEvent();
}

class RoundStarted extends GameEvent {
  const RoundStarted(this.player, this.prompt, this.round);
  final Player player;
  final RoundPrompt prompt;
  final int round;
}

class TurnStarted extends GameEvent {
  const TurnStarted(this.player, this.prompt);
  final Player player;
  final RoundPrompt prompt;
}

class AnswerAccepted extends GameEvent {
  const AnswerAccepted(this.player, this.decision, {this.fast = false, this.streak = 0});
  final Player player;
  final AnswerDecision decision;
  final bool fast;
  final int streak;
  String get word => decision.spokenText;
}

class AnswerRepeated extends GameEvent {
  const AnswerRepeated(this.player, this.decision, this.usedWords);
  final Player player;
  final AnswerDecision decision;
  final List<String> usedWords;
  String get word => decision.spokenText;

  /// Vrai si le joueur a utilisé un synonyme d'un mot déjà cité (frigo / réfrigérateur).
  bool get isSynonym {
    const n = TextNormalizer();
    final prev = decision.previousAnswer;
    return prev != null && n.singular(n.normalize(prev)) != n.singular(n.normalize(decision.spokenText));
  }
}

/// Réponse refusée (hors catégorie ou inconnue) : le tour continue.
class AnswerRejected extends GameEvent {
  const AnswerRejected(this.player, this.decision);
  final Player player;
  final AnswerDecision decision;
  String get word => decision.spokenText;
}

/// Transcription incertaine ou réponse ambiguë : on fait répéter, sans pénalité.
class AnswerNeedsRepeat extends GameEvent {
  const AnswerNeedsRepeat(this.player, this.decision);
  final Player player;
  final AnswerDecision decision;
}

/// Défi à plusieurs réponses : résultat détaillé.
class ChallengeAnswered extends GameEvent {
  const ChallengeAnswered(this.player, this.result);
  final Player player;
  final ChallengeResult result;
}

/// Émis quand le joueur traîne : la bombe panique.
class TooSlow extends GameEvent {
  const TooSlow(this.player, this.fuseLeft);
  final Player player;
  final double fuseLeft; // 0..1
}

class Exploded extends GameEvent {
  const Exploded(this.loser, {this.eliminated = false});
  final Player loser;
  final bool eliminated;
}

class GameFinished extends GameEvent {
  const GameFinished(this.ranking, this.rounds, this.explosions);
  final List<Player> ranking;
  final int rounds, explosions;
  Player get winner => ranking.first;
}

/// Moteur de règles BOOM PARTY (BOOM CORE ENGINE). Ne connaît ni l'interface,
/// ni les animations, ni l'audio : il reçoit des réponses et le temps qui
/// passe, valide via le moteur de connaissances et émet des [GameEvent].
class GameEngine {
  GameEngine({
    required List<Player> players,
    required this.kb,
    required List<String> gameCategories,
    this.mode = GameMode.cultureGenerale,
    this.totalRounds = 12,
    this.slowAfter = 7,
    this.challengeEvery = 4,
    List<String>? onlyKbCategories,
    math.Random? random,
  })  : assert(players.length >= 2 && players.length <= 12, 'De 2 à 12 joueurs'),
        players = List.unmodifiable(players),
        _rng = random ?? math.Random(),
        validator = BoomAnswerValidator(kb),
        challenges = ChallengeValidator(kb) {
    _categories = onlyKbCategories != null
        ? [for (final id in onlyKbCategories) if (kb.categories[id] != null) kb.categories[id]!]
        : [for (final g in gameCategories) ...kb.forGameCategory(g)];
    if (_categories.isEmpty) _categories = kb.categories.values.toList();
    _challengePool = [for (final c in kb.challenges.values) if (_categories.any((k) => k.id == c.categoryId)) c];
  }

  final List<Player> players;
  final KnowledgeRepository kb;
  final BoomAnswerValidator validator;
  final ChallengeValidator challenges;
  final GameMode mode;
  final int totalRounds;
  final double slowAfter; // secondes sans bonne réponse avant « Trop lent »
  final int challengeEvery; // une manche sur N est un défi à plusieurs réponses (0 = jamais)
  final math.Random _rng;
  late List<KbCategory> _categories;
  late List<KbChallenge> _challengePool;

  final _events = StreamController<GameEvent>.broadcast(sync: true);
  Stream<GameEvent> get events => _events.stream;

  final BoomAnswerMemory memory = BoomAnswerMemory();
  int round = 0;
  int explosions = 0;
  int _turn = 0;
  int _streak = 0;
  late RoundPrompt prompt;
  double fuseTotal = 0, fuseLeft = 0, _sinceAnswer = 0;
  bool _slowSent = false;
  bool running = false;
  bool finished = false;

  Player get current => players[_turn % players.length];
  double get fuseFraction => fuseTotal == 0 ? 0 : (fuseLeft / fuseTotal).clamp(0, 1);
  List<String> get usedWords => memory.usedWords;
  /// Formulations connues pour la catégorie de la manche (vocabulaire
  /// favorisé par la reconnaissance vocale).
  Iterable<String> vocabulary() sync* {
    for (final id in kb.members[prompt.categoryId] ?? const <String>{}) {
      yield* kb.displayAliases[id] ?? const <String>[];
    }
  }

  List<Player> get activePlayers => [for (final p in players) if (!usesLives(mode) || !p.eliminated) p];

  void start({int? firstPlayer}) {
    round = 0;
    explosions = 0;
    finished = false;
    for (final p in players) {
      p.score = 0;
      p.lives = 3;
    }
    _turn = firstPlayer ?? _rng.nextInt(players.length);
    _nextRound();
  }

  void _nextRound() {
    round++;
    memory.newRound();
    _streak = 0;
    final useChallenge = challengeEvery > 0 && _challengePool.isNotEmpty && round % challengeEvery == 0;
    if (useChallenge) {
      final ch = _challengePool[_rng.nextInt(_challengePool.length)];
      prompt = RoundPrompt(categoryId: ch.categoryId, categoryName: kb.categories[ch.categoryId]!.name, prompt: ch.prompt, challenge: ch);
    } else {
      final cat = _categories[_rng.nextInt(_categories.length)];
      prompt = RoundPrompt(categoryId: cat.id, categoryName: cat.name, prompt: cat.prompts[_rng.nextInt(cat.prompts.length)]);
    }
    final (lo, hi) = fuseRange[mode]!;
    fuseTotal = lo + _rng.nextDouble() * (hi - lo);
    fuseLeft = fuseTotal;
    _sinceAnswer = 0;
    _slowSent = false;
    _skipEliminated();
    running = true;
    _events.add(RoundStarted(current, prompt, round));
  }

  void _skipEliminated() {
    if (!usesLives(mode)) return;
    var guard = 0;
    while (current.eliminated && guard++ < players.length) {
      _turn++;
    }
  }

  void _passTurn() {
    _turn++;
    _skipEliminated();
    _sinceAnswer = 0;
    _slowSent = false;
    _events.add(TurnStarted(current, prompt));
  }

  /// Soumet une réponse (transcription vocale ou saisie). [asrConfidence] :
  /// confiance de la reconnaissance vocale, si connue.
  /// [alternatives] : autres hypothèses de la reconnaissance vocale ; on retient
  /// la première qui est acceptée (sinon un doublon, sinon l'hypothèse principale).
  AnswerDecision? submit(String raw, {double? asrConfidence, List<String> alternatives = const []}) {
    if (!running) return null;
    final p = current;
    if (prompt.challenge != null) {
      var r = challenges.validate(raw, prompt.challenge!, memory);
      for (final alt in alternatives) {
        if (r.success) break;
        final r2 = challenges.validate(alt, prompt.challenge!, memory);
        if (r2.success) r = r2;
      }
      _events.add(ChallengeAnswered(p, r));
      if (r.success) {
        p.score += r.needed;
        _passTurn();
      }
      return r.decisions.isEmpty ? null : r.decisions.first;
    }
    var chosen = raw;
    if (alternatives.isNotEmpty) {
      final options = [raw, ...alternatives];
      final ds = [for (final o in options) validator.validate(o, prompt.categoryId, memory, asrConfidence: asrConfidence)];
      final i = ds.indexWhere((d) => d.status == AnswerStatus.accepted);
      final j = ds.indexWhere((d) => d.status == AnswerStatus.duplicate);
      chosen = options[i >= 0 ? i : (j >= 0 ? j : 0)];
    }
    final d = validator.validateAndCommit(chosen, prompt.categoryId, memory, asrConfidence: asrConfidence);
    switch (d.status) {
      case AnswerStatus.accepted:
        p.score += 1;
        _streak++;
        _events.add(AnswerAccepted(p, d, fast: _sinceAnswer < 2.0, streak: _streak));
        _passTurn();
      case AnswerStatus.duplicate:
        _events.add(AnswerRepeated(p, d, usedWords));
      case AnswerStatus.wrongCategory || AnswerStatus.unknown:
        _events.add(AnswerRejected(p, d));
      case AnswerStatus.recognitionError || AnswerStatus.ambiguous:
        _events.add(AnswerNeedsRepeat(p, d));
    }
    return d;
  }

  /// Fait avancer le temps de [dt] secondes. La bombe ne s'arrête jamais
  /// pendant la manche, même pendant les répétitions.
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
      if (usesLives(mode)) {
        loser.lives = math.max(0, loser.lives - 1);
      } else {
        loser.score = math.max(0, loser.score - 1);
      }
      _events.add(Exploded(loser, eliminated: usesLives(mode) && loser.eliminated));
    }
  }

  /// Appelé par l'interface après l'écran d'explosion.
  void continueAfterExplosion() {
    if (running || finished) return;
    final enoughPlayers = !usesLives(mode) || activePlayers.length >= 2;
    if (round >= totalRounds || !enoughPlayers) {
      finished = true;
      _events.add(GameFinished(ranking, round, explosions));
    } else {
      _turn++;
      _nextRound();
    }
  }

  List<Player> get ranking => [...players]
    ..sort((a, b) => usesLives(mode) ? (b.lives * 1000 + b.score).compareTo(a.lives * 1000 + a.score) : b.score.compareTo(a.score));

  void dispose() => _events.close();
}
