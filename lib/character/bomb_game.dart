import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bomb_state.dart';

/// Cache partagé des spritesheets de la bombe : chargées une seule fois.
class BombAssets {
  BombAssets._();
  static final images = Images(prefix: 'assets/sprites/');
  static Map<String, dynamic>? _meta;
  static Future<void>? _loading;

  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    _meta = jsonDecode(await rootBundle.loadString('assets/sprites/bomb_animations.json')) as Map<String, dynamic>;
    final states = _meta!['states'] as Map<String, dynamic>;
    await images.loadAll([for (final s in states.values) (s as Map)['image'] as String]);
  }

  static Map<String, dynamic> get meta => _meta!;
}

/// Description de l'endroit où la bombe est posée dans l'écran,
/// exprimée en fractions de la zone de jeu (indépendant de la résolution).
class BombPlacement {
  const BombPlacement({required this.feet, required this.bodyWidth, this.mirror = false});

  /// Position des pieds (fraction de la largeur/hauteur de l'écran).
  final Offset feet;

  /// Largeur du corps en fraction de la largeur de l'écran.
  final double bodyWidth;
  final bool mirror;
}

class BombGame extends FlameGame {
  BombGame({
    required this.placement,
    BombState initialState = BombState.idle,
    this.confetti = 0,
    this.seed = 7,
  }) : _initialState = initialState;

  final BombPlacement placement;
  final BombState _initialState;
  final int confetti;
  final int seed;
  late final BombCharacter bomb;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await BombAssets.ensureLoaded();
    if (confetti > 0) add(ConfettiField(count: confetti, seed: seed));
    bomb = BombCharacter(_initialState);
    add(bomb);
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout();
  }

  void _layout() {
    // largeur du corps dans une frame source = 244 px sur 420 (mesuré)
    final k = size.x * placement.bodyWidth / 244.0;
    bomb
      ..size = Vector2(420 * k, 500 * k)
      ..position = Vector2(size.x * placement.feet.dx, size.y * placement.feet.dy);
    if (placement.mirror && !bomb.isFlippedHorizontally) bomb.flipHorizontally();
  }

  void setState(BombState s) => bomb.react(s);
}

class BombCharacter extends SpriteAnimationGroupComponent<BombState> {
  BombCharacter(BombState initial)
      : _initial = initial,
        super(anchor: const Anchor(0.5, 0.97));

  final BombState _initial;
  double _t = 0;
  double _stateT = 0;

  @override
  Future<void> onLoad() async {
    final meta = BombAssets.meta;
    final fw = (meta['frameWidth'] as num).toDouble();
    final fh = (meta['frameHeight'] as num).toDouble();
    final sheets = meta['states'] as Map<String, dynamic>;
    final anims = <BombState, SpriteAnimation>{};
    for (final st in BombState.values) {
      final m = sheets[st.sheet] as Map<String, dynamic>;
      anims[st] = SpriteAnimation.fromFrameData(
        BombAssets.images.fromCache(m['image'] as String),
        SpriteAnimationData.sequenced(
          amount: m['frames'] as int,
          stepTime: (m['stepTime'] as num).toDouble(),
          textureSize: Vector2(fw, fh),
          loop: m['loop'] as bool,
        ),
      );
    }
    animations = anims;
    current = _initial;
  }

  void react(BombState s) {
    if (current == s) return;
    current = s;
    _stateT = 0;
  }

  /// Mouvement secondaire procédural (respiration, sautillement, tremblement)
  /// appliqué par-dessus les frames dessinées, pour éviter un rendu figé.
  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _stateT += dt;
    double sx = 1, sy = 1, dy = 0, rot = 0;
    switch (current) {
      case BombState.idle || BombState.listening || BombState.talking:
        final b = math.sin(_t * 2 * math.pi / 2.4); // respiration ~2.4 s
        sy = 1 + 0.018 * b;
        sx = 1 - 0.012 * b;
      case BombState.happy || BombState.celebration || BombState.laughing:
        final p = (_t * 1.6) % 1.0; // saut avec squash à la réception
        final h = math.sin(p * math.pi);
        dy = -0.06 * h;
        final land = p < 0.12 ? 1 - p / 0.12 : 0.0;
        sy = 1 - 0.07 * land + 0.03 * h;
        sx = 1 + 0.06 * land - 0.02 * h;
      case BombState.panic || BombState.countdown:
        final amp = current == BombState.countdown ? (0.01 + 0.03 * math.min(1.0, _stateT / 6)) : 0.035;
        rot = amp * math.sin(_t * 47);
        sx = 1 + amp * 0.6 * math.sin(_t * 31);
      case BombState.angry:
        sy = 1 + 0.02 * math.sin(_t * 9);
      case BombState.confused:
        rot = -0.12 * math.min(1.0, _stateT / 0.35);
      case BombState.explosion || BombState.defeated || null:
        break;
    }
    scale = Vector2(sx * (isFlippedHorizontally ? -1 : 1), sy);
    angle = rot;
    _bounceOffset = dy * size.y;
  }

  double _bounceOffset = 0;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(0, _bounceOffset);
    super.render(canvas);
    canvas.restore();
  }
}

/// Confettis flottants (nombre borné, aucune allocation par frame).
class ConfettiField extends Component with HasGameReference<FlameGame> {
  ConfettiField({required this.count, required this.seed});
  final int count;
  final int seed;

  static const _palette = [
    Color(0xFFFF4F9A), Color(0xFFFFC81E), Color(0xFF8C5CF0), Color(0xFF39CFC4),
    Color(0xFFFF8A2A), Color(0xFF4FA3FF), Color(0xFF6BD86B),
  ];

  late final List<_Piece> _pieces;
  final Paint _paint = Paint();

  @override
  Future<void> onLoad() async {
    final r = math.Random(seed);
    _pieces = List.generate(count, (_) {
      return _Piece(
        x: r.nextDouble(),
        y: r.nextDouble() * 0.62,
        w: 9 + r.nextDouble() * 10,
        h: 6 + r.nextDouble() * 6,
        rot: r.nextDouble() * math.pi,
        spin: (r.nextDouble() - 0.5) * 2,
        vy: 0.004 + r.nextDouble() * 0.01,
        color: _palette[r.nextInt(_palette.length)],
      );
    });
  }

  @override
  void update(double dt) {
    for (final p in _pieces) {
      p.y += p.vy * dt;
      p.rot += p.spin * dt;
      if (p.y > 0.62) p.y -= 0.62;
    }
  }

  @override
  void render(Canvas canvas) {
    final s = game.size;
    for (final p in _pieces) {
      canvas.save();
      canvas.translate(p.x * s.x, p.y * s.y);
      canvas.rotate(p.rot);
      _paint.color = p.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h), const Radius.circular(2)),
        _paint,
      );
      canvas.restore();
    }
  }
}

class _Piece {
  _Piece({required this.x, required this.y, required this.w, required this.h, required this.rot, required this.spin, required this.vy, required this.color});
  double x, y, rot;
  final double w, h, spin, vy;
  final Color color;
}

/// Widget Flutter qui héberge le jeu Flame de la bombe.
class BombStage extends StatefulWidget {
  const BombStage({super.key, required this.placement, this.state = BombState.idle, this.confetti = 0});
  final BombPlacement placement;
  final BombState state;
  final int confetti;

  @override
  State<BombStage> createState() => _BombStageState();
}

class _BombStageState extends State<BombStage> {
  late final BombGame _game = BombGame(placement: widget.placement, initialState: widget.state, confetti: widget.confetti);

  @override
  void didUpdateWidget(covariant BombStage old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state && _game.isLoaded) _game.setState(widget.state);
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
