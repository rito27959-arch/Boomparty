import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bomb_state.dart';

/// Spritesheets de la bombe (rendues dans Blender, voir tools/blender/).
/// Chargement à la demande par état, avec un mode « qualité basse » qui
/// décode les planches à 50 % pour les appareils modestes (mémoire GPU ÷ 4).
class BombAssets {
  BombAssets._();
  static final images = Images(prefix: 'assets/sprites/');
  static Map<String, dynamic>? _meta;
  static Future<void>? _metaLoading;
  static final Map<String, Future<void>> _sheets = {};

  /// 1.0 = pleine résolution ; 0.5 = qualité basse.
  static double quality = 1.0;

  static Future<void> ensureMeta() => _metaLoading ??= () async {
        _meta = jsonDecode(await rootBundle.loadString('assets/sprites/bomb_animations.json')) as Map<String, dynamic>;
      }();

  /// Compatibilité : charge les métadonnées et l'état de repos.
  static Future<void> ensureLoaded() async {
    await ensureMeta();
    await ensureStates({BombState.idle});
  }

  static Future<void> ensureStates(Iterable<BombState> states) async {
    await ensureMeta();
    await Future.wait([for (final s in states) _loadSheet(s.sheet)]);
  }

  static bool isReady(BombState s) => images.containsKey(sheetOf(s)['image'] as String);

  static Map<String, dynamic> sheetOf(BombState s) =>
      (meta['states'] as Map<String, dynamic>)[s.sheet] as Map<String, dynamic>;

  static Future<void> _loadSheet(String sheet) => _sheets[sheet] ??= () async {
        final name = ((meta['states'] as Map<String, dynamic>)[sheet] as Map<String, dynamic>)['image'] as String;
        if (quality >= 0.99) {
          await images.load(name);
          return;
        }
        final data = await rootBundle.load('assets/sprites/$name');
        final probe = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final full = (await probe.getNextFrame()).image;
        final w = (full.width * quality).round();
        full.dispose();
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: w);
        images.add(name, (await codec.getNextFrame()).image);
      }();

  /// Libère les planches qui ne servent plus (changement d'écran).
  static void release(Iterable<BombState> keep) {
    final keepSheets = {for (final s in keep) s.sheet};
    for (final sheet in _sheets.keys.toList()) {
      if (keepSheets.contains(sheet)) continue;
      final name = ((meta['states'] as Map<String, dynamic>)[sheet] as Map<String, dynamic>)['image'] as String;
      images.clear(name);
      _sheets.remove(sheet);
    }
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
    this.tint,
    this.preload = const {},
  }) : _initialState = initialState;

  /// États à charger dès l'ouverture de l'écran (en plus de l'état initial).
  final Set<BombState> preload;

  final ColorFilter? tint;

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
    await BombAssets.ensureStates({_initialState, ...preload});
    if (confetti > 0) add(ConfettiField(count: confetti, seed: seed));
    bomb = BombCharacter(_initialState);
    if (tint != null) bomb.paint.colorFilter = tint;
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
        super(anchor: const Anchor(0.5, 0.955));

  final BombState _initial;
  double _t = 0;
  double _stateT = 0;

  @override
  Future<void> onLoad() async {
    animations = {_initial: _build(_initial)};
    current = _initial;
  }

  SpriteAnimation _build(BombState st) {
    final meta = BombAssets.meta;
    final q = BombAssets.quality;
    final m = BombAssets.sheetOf(st);
    final fw = (meta['frameWidth'] as num).toDouble() * q;
    final fh = (meta['frameHeight'] as num).toDouble() * q;
    return SpriteAnimation.fromFrameData(
      BombAssets.images.fromCache(m['image'] as String),
      SpriteAnimationData.sequenced(
        amount: m['frames'] as int,
        amountPerRow: (m['columns'] as int?) ?? (m['frames'] as int),
        stepTime: (m['stepTime'] as num).toDouble(),
        textureSize: Vector2(fw, fh),
        loop: m['loop'] as bool,
      ),
    );
  }

  BombState? _pending;

  void react(BombState s) {
    if (current == s && _pending == null) return;
    if (!BombAssets.isReady(s)) {
      _pending = s;
      BombAssets.ensureStates({s}).then((_) {
        if (_pending == s) react(s);
      });
      return;
    }
    _pending = null;
    final anims = Map<BombState, SpriteAnimation>.from(animations ?? {});
    anims[s] ??= _build(s);
    animations = anims;
    current = s;
    animationTicker?.reset();
    _stateT = 0;
  }

  /// Les frames Blender contiennent déjà l'animation complète (anticipation,
  /// squash & stretch, follow-through). Ici on ajoute seulement :
  /// - un petit « pop » de transition quand l'état change (évite les coupes sèches) ;
  /// - l'accélération du tic-tac pendant le compte à rebours.
  @override
  void update(double dt) {
    final speed = current == BombState.countdown ? 1.0 + math.min(1.5, _stateT / 4) : 1.0;
    super.update(dt * speed);
    _t += dt;
    _stateT += dt;
    final pop = math.max(0.0, 1 - _stateT / 0.18);
    final k = math.sin(pop * math.pi) * 0.06;
    scale = Vector2((1 + k) * (isFlippedHorizontally ? -1 : 1), 1 - k);
    angle = 0;
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

/// Flash plein écran + onde de choc, superposés à l'explosion rendue dans
/// Blender (boule de feu, fumée et débris sont dans les frames « explosion »).
/// Durée bornée, puis auto-suppression. Flash désactivé en mouvement réduit.
class ExplosionFx extends Component {
  ExplosionFx({required this.center, required this.radius, this.reducedMotion = false});
  final Vector2 center;
  final double radius;
  final bool reducedMotion;
  double _t = 0;
  final Paint _p = Paint();

  @override
  void update(double dt) {
    _t += dt;
    if (_t > 0.7) removeFromParent();
  }

  @override
  void render(Canvas c) {
    final o = Offset(center.x, center.y);
    if (!reducedMotion && _t < 0.18) {
      _p
        ..style = PaintingStyle.fill
        ..color = Color.fromRGBO(255, 250, 220, 0.85 * (1 - _t / 0.18));
      c.drawCircle(o, radius * (1 + _t * 10), _p);
    }
    if (_t < 0.6) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08 * (1 - _t / 0.6)
        ..color = Color.fromRGBO(255, 255, 255, 0.8 * (1 - _t / 0.6));
      c.drawCircle(o, radius * (0.6 + _t * 5), _p);
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
  const BombStage({
    super.key,
    required this.placement,
    this.state = BombState.idle,
    this.confetti = 0,
    this.animatePlacement = true,
    this.explodeToken = 0,
    this.reducedMotion = false,
    this.tint,
    this.preload = const {},
  });

  /// États chargés dès l'ouverture (évite un temps de chargement au changement d'état).
  final Set<BombState> preload;
  final BombPlacement placement;
  final BombState state;
  final int confetti;
  final bool animatePlacement;

  /// Incrémenter cette valeur déclenche une explosion.
  final int explodeToken;
  final bool reducedMotion;

  /// Teinte du skin choisi (null = bombe classique).
  final ColorFilter? tint;

  @override
  State<BombStage> createState() => _BombStageState();
}

class _BombStageState extends State<BombStage> {
  late final BombGame _game = BombGame(
      placement: widget.placement, initialState: widget.state, confetti: widget.confetti, tint: widget.tint, preload: widget.preload);

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
