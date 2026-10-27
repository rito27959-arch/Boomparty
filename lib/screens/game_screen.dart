import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_routes.dart';
import '../character/bomb_game.dart';
import '../design/avatars.dart';
import '../design/candy_button.dart';
import '../design/cartoon_title.dart';
import '../design/scenes.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../engine/game_engine.dart';
import '../game/game_controller.dart';
import '../services/answer_input.dart';
import '../services/settings_store.dart';
import '../state/app_state.dart';

/// Écrans 5 à 10 : une seule route de jeu dont l'affichage suit la phase
/// du [GameController]. La bombe (Flame) reste la même instance d'un état
/// à l'autre pour la continuité de l'animation.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.controller, this.frozen = false});

  /// Contrôleur injecté (tests/captures). Sinon créé à partir de [AppState].
  final GameController? controller;

  /// Fige le temps (captures déterministes).
  final bool frozen;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final GameController ctl;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _explodeToken = 0;
  Phase _seenPhase = Phase.listening;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      ctl = widget.controller!;
    } else {
      final st = AppState.instance;
      final settings = SettingsStore.instance;
      ctl = GameController(
        engine: GameEngine(players: st.players, selected: st.categoriesForGame, mode: st.mode),
        input: SpeechAnswerInput(),
        audio: settings.buildAudio(),
        reducedMotion: settings.reducedMotion,
        vibrations: settings.vibrations,
      )..start();
    }
    _seenPhase = ctl.phase;
    ctl.addListener(_onPhase);
    _ticker = createTicker((now) {
      final dt = (now - _last).inMicroseconds / 1e6;
      _last = now;
      if (dt > 0 && dt < 0.25) ctl.tick(dt);
    });
    if (!widget.frozen) _ticker.start();
  }

  void _onPhase() {
    if (ctl.phase == _seenPhase) {
      setState(() {});
      return;
    }
    if (ctl.phase == Phase.exploding) _explodeToken++;
    if (ctl.phase == Phase.finished) {
      AppState.instance.lastResult = ctl.result;
      Navigator.pushReplacementNamed(context, AppRoutes.leaderboard);
    }
    setState(() => _seenPhase = ctl.phase);
  }

  @override
  void dispose() {
    _ticker.dispose();
    ctl.removeListener(_onPhase);
    if (widget.controller == null) {
      ctl.input.dispose();
      ctl.engine.dispose();
      ctl.dispose();
    }
    super.dispose();
  }

  BombPlacement get _placement => switch (ctl.phase) {
        Phase.listening => const BombPlacement(feet: Offset(0.51, 0.811), bodyWidth: 0.65),
        Phase.correct => const BombPlacement(feet: Offset(0.46, 0.681), bodyWidth: 0.69),
        Phase.repeated || Phase.invalid => const BombPlacement(feet: Offset(0.49, 0.687), bodyWidth: 0.72),
        Phase.tooSlow || Phase.exploding => const BombPlacement(feet: Offset(0.46, 0.716), bodyWidth: 0.6),
        Phase.exploded || Phase.finished => const BombPlacement(feet: Offset(0.5, 0.70), bodyWidth: 0.56),
      };

  @override
  Widget build(BuildContext context) {
    final p = ctl.phase;
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = c.biggest;
        return Stack(children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey(_bgKey(p)), child: _background(p)),
            ),
          ),
          Positioned.fill(
            child: BombStage(
              placement: _placement,
              state: ctl.bombState,
              explodeToken: _explodeToken,
              reducedMotion: ctl.reducedMotion,
            ),
          ),
          ..._foreground(context, p, size),
        ]);
      }),
    );
  }

  String _bgKey(Phase p) => switch (p) {
        Phase.listening => 'room',
        Phase.correct => 'green',
        Phase.repeated || Phase.invalid => 'red',
        _ => 'orange',
      };

  Widget _background(Phase p) => switch (p) {
        Phase.listening => const CustomPaint(painter: RoomScenePainter()),
        Phase.correct => const CustomPaint(
            painter: BurstScenePainter(
              center: Color(0xFFF2FB58), inner: Color(0xFF9BE42C), outer: Color(0xFF0F9A42),
              ray: Color(0x33FFFFAA), focus: Alignment(-0.05, 0.0),
              bottomClouds: [Color(0xFFFFB13B), Color(0xFFFF6E8A), Color(0xFF7F6DD8), Color(0xFF5E86E0)],
              sparkles: [Color(0xFFFFD42A), Color(0xFF9B6BFF), Color(0xFFFF5FA8), Color(0xFF4FC3FF)],
            )),
        Phase.repeated || Phase.invalid => const CustomPaint(
            painter: BurstScenePainter(
              center: Color(0xFFFF8A6A), inner: Color(0xFFF6384F), outer: Color(0xFF9A1424),
              ray: Color(0x22FFFFFF), focus: Alignment(0, -0.15),
              sparkles: [Color(0xFFFFD42A), Color(0xFFFF9A3A)], seed: 4,
            )),
        Phase.exploded || Phase.finished => const CustomPaint(
            painter: BurstScenePainter(
              center: Color(0xFFFFF0A0), inner: Color(0xFFFFA42A), outer: Color(0xFF5E2A5C),
              ray: Color(0x33FFE7A0), focus: Alignment(0, -0.1), rays: 22,
              bottomClouds: [Color(0xFF8E5A8E), Color(0xFF6E4A7A), Color(0xFF8E5A8E)],
              sparkles: [Color(0xFF3A2A40), Color(0xFFFF7A2A)], seed: 9,
            )),
        _ => const CustomPaint(
            painter: BurstScenePainter(
              center: Color(0xFFFFE07A), inner: Color(0xFFFF9A2E), outer: Color(0xFF7A2E5A),
              ray: Color(0x30FFF2B0), focus: Alignment(-0.1, 0.05), rays: 20,
              bottomClouds: [Color(0xFFE0558E), Color(0xFF8E3FC8), Color(0xFF6A2FB0)],
              sparkles: [Color(0xFFFFD42A), Color(0xFF8E5AF0), Color(0xFF3AC8E0), Color(0xFFFF6A3A)], seed: 6,
            )),
      };

  List<Widget> _foreground(BuildContext context, Phase p, Size size) => switch (p) {
        Phase.listening => _listening(context, RefScale(size, 230, 536)),
        Phase.correct => _correct(RefScale(size, 196, 536)),
        Phase.repeated || Phase.invalid => _repeated(RefScale(size, 194, 536), invalid: p == Phase.invalid),
        Phase.tooSlow || Phase.exploding => _tooSlow(RefScale(size, 216, 440)),
        Phase.exploded || Phase.finished => _exploded(RefScale(size, 248, 452)),
      };

  // ---------- 05 : écoute ----------
  List<Widget> _listening(BuildContext context, RefScale r) {
    final k = r.k;
    final pr = ctl.engine.prompt;
    return [
      _Header(r: r, player: ctl.player, twoLines: true, avatarX: 90, textX: 113, y: 52, showGear: true),
      Positioned(
        left: r.x(16), right: r.x(18), top: r.y(94),
        child: SpeechBubble(
          angle: -0.06, tailX: 0.36, radius: 20 * k,
          padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 12 * k, 12 * k),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(pr.lead, style: BoomText.ui800(13 * k, color: const Color(0xFF1A1440))),
            CartoonTitle(pr.keyword,
                fontSize: 27 * k, fill: const [Color(0xFFFF8A2A), Color(0xFFF2501E)], outline: Colors.white,
                strokeWidth: 2 * k, depth: 0.1, height: 1.05),
            Text(pr.tail, textAlign: TextAlign.center, style: BoomText.ui700(10.5 * k, color: const Color(0xFF1A1440))),
          ]),
        ),
      ),
      Positioned(
        left: r.x(15), right: r.x(18), top: r.y(413), height: r.y(42),
        child: MicWave(level: ctl.input.level, frozen: widget.frozen),
      ),
      Positioned(
        left: r.x(26), right: r.x(28), top: r.y(466), height: r.y(56),
        child: GestureDetector(
          onTap: () => _typeAnswer(context),
          child: SpeechBubble(
            tailX: 0.78, radius: 26 * k,
            padding: EdgeInsets.zero,
            child: Center(
              child: ValueListenableBuilder<String>(
                valueListenable: ctl.input.partial,
                builder: (_, partial, __) => Text(
                  partial.isEmpty ? "Je t'écoute !" : partial,
                  overflow: TextOverflow.ellipsis,
                  style: BoomText.ui800(18.5 * k, color: const Color(0xFF1A1440)),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _typeAnswer(BuildContext context) async {
    final t = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ta réponse', style: BoomText.ui800(20)),
        content: TextField(controller: t, autofocus: true, style: BoomText.ui600(18), onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, t.text), child: Text('Valider', style: BoomText.ui800(16)))],
      ),
    );
    if (word != null) ctl.answer(word);
  }

  // ---------- 06 : bonne réponse ----------
  List<Widget> _correct(RefScale r) {
    final k = r.k;
    return [
      Positioned(
        left: r.x(16), width: r.x(152), top: r.y(62),
        child: SpeechBubble(
          angle: -0.05, tailX: 0.46, radius: 22 * k,
          padding: EdgeInsets.fromLTRB(10 * k, 12 * k, 10 * k, 16 * k),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CartoonTitle('Super !', fontSize: 27 * k, fill: const [Color(0xFF2BC24A), Color(0xFF12902E)], outline: Colors.white, strokeWidth: 2 * k, depth: 0.1),
            SizedBox(height: 2 * k),
            Text('${ctl.lastWord} !', textAlign: TextAlign.center, style: BoomText.ui800(12 * k, color: const Color(0xFF16502A))),
          ]),
        ),
      ),
      Positioned(left: r.x(128), top: r.y(332), child: _Badge(size: 58 * k, color: const Color(0xFF16B33A), icon: Icons.check_rounded)),
      Positioned(left: r.x(70), top: r.y(372), width: r.x(48), height: r.x(48), child: const _Star()),
      Positioned(
        left: r.x(45), width: r.x(105), top: r.y(424), height: r.y(42),
        child: CandyButton(
          height: r.y(38), depth: r.y(4), radius: r.y(19),
          top: BoomColors.yellowTop, bottom: BoomColors.yellowBottom, edge: BoomColors.yellowEdge,
          onPressed: null,
          child: Text('+1 point', style: BoomText.ui800(15 * k)),
        ),
      ),
    ];
  }

  // ---------- 07 : déjà dit (et 08 : hors catégorie) ----------
  List<Widget> _repeated(RefScale r, {required bool invalid}) {
    final k = r.k;
    final words = ctl.engine.usedWords;
    return [
      Positioned(left: r.x(10), top: r.y(40), child: _WhiteChevron(size: 20 * k)),
      Positioned(
        left: r.x(16), width: r.x(166), top: r.y(58),
        child: SpeechBubble(
          angle: -0.04, tailX: 0.3, radius: 22 * k,
          padding: EdgeInsets.fromLTRB(10 * k, 12 * k, 10 * k, 14 * k),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CartoonTitle(invalid ? 'Hmm…' : 'Oups !',
                fontSize: 25 * k, fill: const [Color(0xFFFF4F6E), Color(0xFFE21A44)], outline: Colors.white, strokeWidth: 2 * k, depth: 0.1),
            SizedBox(height: 3 * k),
            Text(invalid ? '« ${ctl.lastWord} » ne rentre pas\ndans la catégorie !' : 'Ce mot a déjà été dit !',
                textAlign: TextAlign.center, style: BoomText.ui800(10.6 * k, color: const Color(0xFFE21A44))),
          ]),
        ),
      ),
      Positioned(left: r.x(138), top: r.y(162), child: _Badge(size: 46 * k, color: const Color(0xFFE8263F), icon: Icons.close_rounded)),
      Positioned(
        left: 0, right: 0, top: r.y(350), bottom: 0,
        child: Container(
          padding: EdgeInsets.fromLTRB(14 * k, 16 * k, 14 * k, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE0E5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18 * k)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mots déjà cités :', style: BoomText.ui800(9.8 * k, color: const Color(0xFF1E1838))),
            SizedBox(height: 8 * k),
            Wrap(spacing: 5 * k, runSpacing: 6 * k, children: [
              for (final w in words)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 4 * k),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12 * k),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
                  ),
                  child: Text(w, style: BoomText.ui600(9.8 * k, color: const Color(0xFF1E1838))),
                ),
            ]),
          ]),
        ),
      ),
      Positioned(
        left: r.x(15), right: r.x(15), top: r.y(460),
        child: CandyButton(
          height: r.y(42), depth: r.y(4),
          top: const Color(0xFFFF6A72), bottom: const Color(0xFFF0323F), edge: const Color(0xFFB81E2E),
          onPressed: ctl.retry,
          child: Text('Réessaie !', style: BoomText.ui800(16 * k, color: Colors.white)),
        ),
      ),
    ];
  }

  // ---------- 09 : trop lent / compte à rebours ----------
  List<Widget> _tooSlow(RefScale r) {
    final k = r.k;
    return [
      _Header(r: r, player: ctl.player, twoLines: false, avatarX: 66, textX: 87, y: 30, showGear: false),
      Positioned(
        left: r.x(22), width: r.x(172), top: r.y(58),
        child: SpeechBubble(
          angle: -0.05, tailX: 0.4, radius: 20 * k,
          padding: EdgeInsets.fromLTRB(8 * k, 12 * k, 8 * k, 14 * k),
          child: Text('Trop lent...\nÇA VA EXPLOSER !',
              textAlign: TextAlign.center, style: BoomText.ui800(15.5 * k, color: const Color(0xFFE81E3A), height: 1.15)),
        ),
      ),
      Positioned(
        left: r.x(14), right: r.x(16), top: r.y(292), height: r.y(30),
        child: FuseBar(fraction: ctl.fuse),
      ),
    ];
  }

  // ---------- 10 : explosion ----------
  List<Widget> _exploded(RefScale r) {
    final k = r.k;
    final name = ctl.loser?.name ?? '';
    return [
      Positioned(
        left: r.x(26), width: r.x(198), top: r.y(46), height: r.y(64),
        child: Transform.rotate(
          angle: -0.1,
          child: FittedBox(
            child: CartoonTitle('BOOOOM !', fontSize: 80, fill: const [Color(0xFFFFE04A), Color(0xFFF79A12)], outline: const Color(0xFF4A1A10)),
          ),
        ),
      ),
      Positioned(
        left: 0, right: 0, top: r.y(312),
        child: Text("C'est $name\nqui perd 1 point !",
            textAlign: TextAlign.center,
            style: BoomText.ui800(13.5 * k, color: const Color(0xFF2A1A3A), height: 1.15).copyWith(shadows: [
              for (final o in const [Offset(1, 1), Offset(-1, 1), Offset(1, -1), Offset(-1, -1)])
                Shadow(color: Colors.white.withValues(alpha: 0.85), offset: o * k, blurRadius: 1.5 * k),
            ])),
      ),
      Positioned(
        left: r.x(22), right: r.x(22), top: r.y(374),
        child: CandyButton(
          height: r.y(42), depth: r.y(4),
          top: BoomColors.yellowTop, bottom: BoomColors.yellowBottom, edge: BoomColors.yellowEdge,
          onPressed: ctl.continueAfterExplosion,
          child: Text('Continuer', style: BoomText.ui800(16.5 * k)),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.r, required this.player, required this.twoLines, required this.avatarX, required this.textX, required this.y, required this.showGear});
  final RefScale r;
  final Player player;
  final bool twoLines, showGear;
  final double avatarX, textX, y;

  @override
  Widget build(BuildContext context) {
    final k = r.k;
    final shadow = [Shadow(color: Colors.black.withValues(alpha: 0.35), offset: Offset(0, 1 * k), blurRadius: 2 * k)];
    return Positioned(
      left: 0, right: 0, top: r.y(y) - 18 * k, height: 36 * k,
      child: Stack(children: [
        if (twoLines) Positioned(left: 11 * k, top: 7 * k, child: RoundBackButton(size: 22 * k)),
        Positioned(
          left: (avatarX - 18) * k, top: 0,
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.6 * k)),
            child: PlayerAvatar(index: player.avatar, size: (twoLines ? 34 : 28) * k),
          ),
        ),
        Positioned(
          left: textX * k, top: twoLines ? 1 * k : 6 * k,
          child: Text(twoLines ? 'Tour de\n${player.name}' : 'Tour de ${player.name}',
              style: BoomText.ui800((twoLines ? 11.5 : 11) * k, color: Colors.white, height: 1.05).copyWith(shadows: shadow)),
        ),
        if (showGear)
          Positioned(
            right: 13 * k, top: 7 * k,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
              child: Container(
                width: 22 * k, height: 22 * k,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.25)),
                child: Icon(Icons.settings_rounded, color: Colors.white, size: 16 * k),
              ),
            ),
          ),
      ]),
    );
  }
}

class _WhiteChevron extends StatelessWidget {
  const _WhiteChevron({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Icon(Icons.chevron_left_rounded, size: size, color: const Color(0xFFFFE07A)),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.size, required this.color, required this.icon});
  final double size;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: size * 0.15, offset: Offset(0, size * 0.06))],
        ),
        padding: EdgeInsets.all(size * 0.08),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.66),
        ),
      );
}

class _Star extends StatelessWidget {
  const _Star();
  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _StarPainter());
}

class _StarPainter extends CustomPainter {
  const _StarPainter();
  @override
  void paint(Canvas c, Size s) {
    final path = Path();
    final o = s.center(Offset.zero);
    for (var i = 0; i < 10; i++) {
      final a = -1.5708 + i * 0.6283;
      final rr = i.isEven ? s.width * 0.5 : s.width * 0.22;
      final p = o + Offset(rr * _cos(a), rr * _sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path.shift(Offset(0, s.height * 0.04)), Paint()..color = const Color(0x40000000));
    c.drawPath(path, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE04A), Color(0xFFF59E0B)]).createShader(Offset.zero & s));
  }

  static double _cos(double a) => _sinCos(a, true);
  static double _sin(double a) => _sinCos(a, false);
  static double _sinCos(double a, bool cos) {
    // évite un import dart:math supplémentaire dans ce fichier
    return cos ? Offset.fromDirection(a).dx : Offset.fromDirection(a).dy;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Onde sonore du micro : barres en dégradé jaune → violet → bleu.
class MicWave extends StatefulWidget {
  const MicWave({super.key, required this.level, this.frozen = false});
  final ValueListenable<double> level;
  final bool frozen;

  @override
  State<MicWave> createState() => _MicWaveState();
}

class _MicWaveState extends State<MicWave> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (!widget.frozen) _a.repeat();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC2A1A2E),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0x55FFFFFF), width: 1),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_a, widget.level]),
        builder: (_, __) => CustomPaint(painter: _WavePainter(_a.value, widget.level.value)),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.level);
  final double t, level;

  @override
  void paint(Canvas c, Size s) {
    const n = 46;
    final pad = s.height * 0.5;
    final usable = s.width - pad * 2;
    final bw = usable / n * 0.55;
    final shader = const LinearGradient(colors: [Color(0xFFFFD21F), Color(0xFFFF9A2A), Color(0xFFE05AE8), Color(0xFF8E6BFF), Color(0xFF3EA2FF)])
        .createShader(Offset.zero & s);
    final p = Paint()..shader = shader;
    final lv = 0.15 + level * 0.85;
    for (var i = 0; i < n; i++) {
      final x = pad + usable * (i + 0.5) / n;
      final env = 1 - ((i - n * 0.32).abs() / (n * 0.7)).clamp(0.0, 1.0) * 0.6;
      final wob = 0.5 + 0.5 * Offset.fromDirection(i * 1.7 + t * 6.283 * 2).dy * Offset.fromDirection(i * 0.53 - t * 6.283).dx;
      final hgt = s.height * 0.78 * (0.12 + 0.88 * env * wob * lv);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, s.height / 2), width: bw, height: hgt), Radius.circular(bw)), p);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t || old.level != level;
}

/// Jauge de mèche (écran 09) : pastille rouge + 10 segments.
class FuseBar extends StatelessWidget {
  const FuseBar({super.key, required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      final lit = (fraction * 10).ceil().clamp(0, 10);
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3A2430),
          borderRadius: BorderRadius.circular(h),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        padding: EdgeInsets.all(h * 0.14),
        child: Row(children: [
          Container(
            width: h * 0.72, height: h * 0.72,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            padding: EdgeInsets.all(h * 0.08),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8263F)),
              child: Icon(Icons.timer_outlined, color: Colors.white, size: h * 0.4),
            ),
          ),
          SizedBox(width: h * 0.16),
          for (var i = 0; i < 10; i++)
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: h * 0.04),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h * 0.12),
                  gradient: i < lit
                      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFC23A), Color(0xFFF2861A)])
                      : null,
                  color: i < lit ? null : const Color(0xFF5E4250),
                ),
              ),
            ),
        ]),
      );
    });
  }
}
