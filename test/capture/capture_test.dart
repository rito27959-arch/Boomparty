// Rendu réel de chaque écran à résolution contrôlée puis export PNG
// dans build/captures/, comparé ensuite à reference/ par tools/compare.py.
import 'dart:io';
import 'dart:ui' as ui;

import 'dart:math';

import 'package:boom_party/character/bomb_game.dart';
import 'package:boom_party/engine/game_engine.dart';
import 'package:boom_party/engine/word_bank.dart';
import 'package:boom_party/game/game_controller.dart';
import 'package:boom_party/screens/game_screen.dart';
import 'package:boom_party/services/answer_input.dart';
import 'package:boom_party/screens/home_screen.dart';
import 'package:boom_party/screens/categories_screen.dart';
import 'package:boom_party/screens/modes_screen.dart';
import 'package:boom_party/screens/players_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'status_bar_sim.dart';

class Shot {
  const Shot(this.name, this.refW, this.refH, this.statusColor, this.build, {this.settleMs = 600});
  final String name;
  final double refW, refH;
  final Color statusColor;
  final WidgetBuilder build;
  final int settleMs;
}

/// Partie réelle pilotée par le moteur, mise dans l'état voulu.
GameController scenario(void Function(GameController c) drive, {int first = 0}) {
  final players = [
    for (final (i, n) in ['Emma', 'Léo', 'Sarah', 'Max', 'Inès'].indexed) Player(id: 'p$i', name: n, avatar: i),
  ];
  final input = ManualAnswerInput()..debugLevel = 0.85;
  final c = GameController(
    engine: GameEngine(players: players, selected: [categories.firstWhere((x) => x.id == 'objets')], random: Random(3)),
    input: input,
    vibrations: false,
  )..start(firstPlayer: first);
  drive(c);
  return c;
}

final shots = <Shot>[
  Shot('01_accueil', 224, 544, Color(0xFF241F33), (_) => const HomeScreen()),
  Shot('02_modes_de_jeu', 214, 536, Color(0xFF14123A), (_) => const ModesScreen()),
  Shot('03_joueurs', 196, 536, Color(0xFF14123A), (_) => const PlayersScreen()),
  Shot('04_categories', 204, 536, Color(0xFF14123A), (_) => const CategoriesScreen()),
  Shot('05_jeu_ecoute', 230, 536, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {}))),
  Shot('06_bonne_reponse', 196, 536, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        for (final w in ['Table', 'Chaise', 'Réfrigérateur']) {
          c.answer(w);
        }
      }))),
  Shot('07_deja_dit', 194, 536, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        for (final w in ['Table', 'Chaise', 'Réfrigérateur', 'Télévision', 'chaise']) {
          c.answer(w);
          c.tick(GameController.correctPause + 0.01);
        }
      }))),
  Shot('09_trop_lent', 216, 440, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        c.tick(c.engine.fuseTotal * 0.72);
      }, first: 3))),
  Shot('10_explosion', 248, 452, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        c.tick(c.engine.fuseTotal + 0.1);
        c.tick(GameController.explosionDuration + 0.1);
      }, first: 3)), settleMs: 1800),
];

const logicalWidth = 390.0;
const dpr = 2.0;

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await l.load();
  }

  await family('Lilita', ['assets/fonts/LilitaOne_400Regular.ttf']);
  await family('Baloo', [
    for (final w in ['500Medium', '600SemiBold', '700Bold', '800ExtraBold']) 'assets/fonts/Baloo2_$w.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  for (final s in shots) {
    testWidgets('capture ${s.name}', (tester) async {
      await tester.runAsync(BombAssets.ensureLoaded);
      final logicalH = logicalWidth * s.refH / s.refW;
      tester.view.physicalSize = Size(logicalWidth * dpr, logicalH * dpr);
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(builder: (ctx) => Stack(children: [
                s.build(ctx),
                Positioned(left: 0, right: 0, top: 0, child: StatusBarSim(color: s.statusColor)),
              ])),
        ),
      ));
      // laisse Flame terminer onLoad et avancer les animations
      for (var i = 0; i < s.settleMs ~/ 50; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: dpr);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      final out = File('build/captures/${s.name}.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!);
    });
  }
}
