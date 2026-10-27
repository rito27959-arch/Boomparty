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

  BombPlacement placement;
  BombPlacement? _from;
  double _blend = 1;
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
    final t = Curves.easeInOutCubic.transform(_blend.clamp(0, 1));
    final a = _from ?? placement;
    final bw = a.bodyWidth + (placement.bodyWidth - a.bodyWidth) * t;
    final feet = Offset.lerp(a.feet, placement.feet, t)!;
    final k = size.x * bw / 244.0;
    bomb
      ..size = Vector2(420 * k, 500 * k)
      ..position = Vector2(size.x * feet.dx, size.y * feet.dy);
    if (placement.mirror != bomb.isFlippedHorizontally) bomb.flipHorizontally();
  }

  /// Déplace la bombe vers une nouvelle place (transition douce de 0,35 s).
  void moveTo(BombPlacement p, {bool animate = true}) {
    if (p.feet == placement.feet && p.bodyWidth == placement.bodyWidth && p.mirror == placement.mirror) return;
    _from = animate && isLoaded ? placement : null;
    placement = p;
    _blend = animate ? 0 : 1;
    if (isLoaded) _layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_blend < 1) {
      _blend = (_blend + dt / 0.35).clamp(0, 1);
      _layout();
    }
  }

  /// Explosion cartoon : flash, onde de choc, débris, étincelles, fumée.
  void explode({bool reducedMotion = false}) {
    final c = Vector2(bomb.position.x, bomb.position.y - bomb.size.y * 0.37);
    add(ExplosionFx(center: c, radius: bomb.size.x * 0.6, reducedMotion: reducedMotion));
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

/// Effet d'explosion à durée de vie bornée (≈1,6 s) puis auto-suppression.
class ExplosionFx extends Component {
  ExplosionFx({required this.center, required this.radius, this.reducedMotion = false});
  final Vector2 center;
  final double radius;
  final bool reducedMotion;
  double _t = 0;
  late final List<_Bit> _bits;
  final Paint _p = Paint();

  static const _debris = Color(0xFF2A2230);
  static const _sparks = [Color(0xFFFFE14D), Color(0xFFFFA51F), Color(0xFFFF6A1A)];

  @override
  Future<void> onLoad() async {
    final r = math.Random(42);
    final n = reducedMotion ? 16 : 46;
    _bits = List.generate(n, (i) {
      final a = r.nextDouble() * 2 * math.pi;
      final sp = radius * (1.2 + r.nextDouble() * 2.6);
      final kind = i % 3; // 0 débris, 1 étincelle, 2 fumée
      return _Bit(
        kind: kind,
        x: center.x, y: center.y,
        vx: math.cos(a) * sp * (kind == 2 ? 0.25 : 1),
        vy: math.sin(a) * sp * (kind == 2 ? 0.25 : 1) - (kind == 2 ? radius * 0.3 : 0),
        size: radius * (kind == 2 ? 0.25 + r.nextDouble() * 0.25 : 0.04 + r.nextDouble() * 0.07),
        rot: r.nextDouble() * 6, spin: (r.nextDouble() - 0.5) * 12,
        color: kind == 0 ? _debris : kind == 1 ? _sparks[i % 3] : const Color(0xFF8C7F86),
      );
    });
  }

  @override
  void update(double dt) {
    _t += dt;
    for (final b in _bits) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.kind == 0) b.vy += radius * 4 * dt; // gravité des débris
      b.vx *= 1 - 1.6 * dt;
      b.vy *= b.kind == 0 ? 1 : 1 - 1.6 * dt;
      b.rot += b.spin * dt;
    }
    if (_t > 1.8) removeFromParent();
  }

  @override
  void render(Canvas c) {
    final o = Offset(center.x, center.y);
    // flash bref (désactivé en mouvement réduit)
    if (!reducedMotion && _t < 0.18) {
      _p.color = Color.fromRGBO(255, 250, 220, 1 - _t / 0.18);
      c.drawCircle(o, radius * (1 + _t * 10), _p);
    }
    // boule de feu orange/jaune
    if (_t < 0.9) {
      final k = Curves.easeOutBack.transform((_t / 0.35).clamp(0, 1));
      final fade = _t < 0.5 ? 1.0 : 1 - (_t - 0.5) / 0.4;
      _p.shader = RadialGradient(colors: [
        Color.fromRGBO(255, 248, 200, fade),
        Color.fromRGBO(255, 190, 40, fade),
        Color.fromRGBO(255, 110, 20, fade * 0.9),
        const Color(0x00FF5A10),
      ], stops: const [0, 0.35, 0.7, 1]).createShader(Rect.fromCircle(center: o, radius: radius * 1.5 * k + 1));
      c.drawCircle(o, radius * 1.5 * k + 1, _p);
      _p.shader = null;
    }
    // onde de choc
    if (_t < 0.6) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08 * (1 - _t / 0.6)
        ..color = Color.fromRGBO(255, 255, 255, 0.8 * (1 - _t / 0.6));
      c.drawCircle(o, radius * (0.6 + _t * 5), _p);
      _p.style = PaintingStyle.fill;
    }
    for (final b in _bits) {
      final life = b.kind == 2 ? (1 - _t / 1.8) : (1 - _t / 1.2);
      if (life <= 0) continue;
      _p.color = b.color.withValues(alpha: life.clamp(0, 1) * (b.kind == 2 ? 0.7 : 1));
      if (b.kind == 2) {
        c.drawCircle(Offset(b.x, b.y), b.size * (1 + _t * 1.5), _p);
      } else {
        c.save();
        c.translate(b.x, b.y);
        c.rotate(b.rot);
        if (b.kind == 0) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size * 2, height: b.size * 1.4), Radius.circular(b.size * 0.3)), _p);
        } else {
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size * 2.4, height: b.size * 0.6), _p);
        }
        c.restore();
      }
    }
  }
}

class _Bit {
  _Bit({required this.kind, required this.x, required this.y, required this.vx, required this.vy, required this.size, required this.rot, required this.spin, required this.color});
  final int kind;
  double x, y, vx, vy, rot;
  final double size, spin;
  final Color color;
}

class _Piece {
  _Piece({required this.x, required this.y, required this.w, required this.h, required this.rot, required this.spin, required this.vy, required this.color});
  double x, y, rot;
  final double w, h, spin, vy;
  final Color color;
}

/// Widget Flutter qui héberge le jeu Flame de la bombe.
class BombStage extends StatefulWidget {
  const BombStage({
    super.key,
    required this.placement,
    this.state = BombState.idle,
    this.confetti = 0,
    this.animatePlacement = true,
    this.explodeToken = 0,
    this.reducedMotion = false,
  });
  final BombPlacement placement;
  final BombState state;
  final int confetti;
  final bool animatePlacement;

  /// Incrémenter cette valeur déclenche une explosion.
  final int explodeToken;
  final bool reducedMotion;

  @override
  State<BombStage> createState() => _BombStageState();
}

class _BombStageState extends State<BombStage> {
  late final BombGame _game = BombGame(placement: widget.placement, initialState: widget.state, confetti: widget.confetti);

  @override
  void didUpdateWidget(covariant BombStage old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state && _game.isLoaded) _game.setState(widget.state);
    _game.moveTo(widget.placement, animate: widget.animatePlacement);
    if (widget.explodeToken != old.explodeToken && widget.explodeToken > 0 && _game.isLoaded) {
      _game.explode(reducedMotion: widget.reducedMotion);
    }
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
