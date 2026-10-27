// Rendu réel de chaque écran à résolution contrôlée puis export PNG
// dans build/captures/, comparé ensuite à reference/ par tools/compare.py.
import 'dart:io';
import 'dart:ui' as ui;

import 'dart:math';

import 'package:boom_party/character/bomb_game.dart';
import 'package:boom_party/character/bomb_state.dart';
import 'package:boom_party/engine/game_engine.dart';
import 'package:boom_party/knowledge/knowledge_repository.dart';
import 'package:boom_party/game/game_controller.dart';
import 'package:boom_party/screens/celebration_screen.dart';
import 'package:boom_party/screens/customize_screen.dart';
import 'package:boom_party/screens/game_screen.dart';
import 'package:boom_party/screens/leaderboard_screen.dart';
import 'package:boom_party/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boom_party/services/answer_input.dart';
import 'package:boom_party/screens/home_screen.dart';
import 'package:boom_party/screens/categories_screen.dart';
import 'package:boom_party/screens/modes_screen.dart';
import 'package:boom_party/screens/players_screen.dart';
import 'package:flutter/foundation.dart';
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

/// Classement de démonstration identique à la maquette.
List<Player> demoRanking() => [
      for (final (n, a, sc) in [('Emma', 0, 12), ('Léo', 1, 10), ('Sarah', 2, 8), ('Inès', 4, 6), ('Max', 3, 4)])
        Player(id: n, name: n, avatar: a, score: sc),
    ];

/// Base de connaissances embarquée (la même que dans l'application).
final kb = KnowledgeRepository.open('assets/knowledge/boom_kb.db');

/// Partie réelle pilotée par le moteur, mise dans l'état voulu.
GameController scenario(void Function(GameController c) drive, {int first = 0}) {
  final players = [
    for (final (i, n) in ['Emma', 'Léo', 'Sarah', 'Max', 'Inès'].indexed) Player(id: 'p$i', name: n, avatar: i),
  ];
  final input = ManualAnswerInput()..debugLevel = 0.85;
  final c = GameController(
    engine: GameEngine(players: players, kb: kb, gameCategories: const ['objets'], onlyKbCategories: const ['objets_maison'],
        challengeEvery: 0, random: Random(3)),
    input: input,
    vibrations: false,
    expressive: false, // états de la maquette, indépendants du tirage des répliques
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
          c.answer(HeardAnswer(w));
        }
      }))),
  Shot('07_deja_dit', 194, 536, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        for (final w in ['Table', 'Chaise', 'Réfrigérateur', 'Télévision', 'chaise']) {
          c.answer(HeardAnswer(w));
          c.tick(GameController.correctPause + 0.01);
        }
      }))),
  Shot('08_hors_categorie', 194, 536, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        c.answer(const HeardAnswer('Table'));
        c.tick(GameController.correctPause + 0.01);
        c.answer(const HeardAnswer('éléphant'));
      }))),
  Shot('15_repete', 194, 536, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        c.answer(const HeardAnswer('table', confidence: 0.1));
        c.tick(0.6);
      }))),
  Shot('09_trop_lent', 216, 440, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        c.tick(c.engine.fuseTotal * 0.72);
      }, first: 3))),
  Shot('10_explosion', 248, 452, Colors.white, (_) => GameScreen(frozen: true, controller: scenario((c) {
        c.tick(c.engine.fuseTotal + 0.1);
        c.tick(GameController.explosionDuration + 0.1);
      }, first: 3)), settleMs: 1800),
  Shot('11_classement', 222, 450, Color(0xFF14123A), (_) => LeaderboardScreen(ranking: demoRanking())),
  Shot('12_personnalisation', 294, 450, Color(0xFF14123A), (_) => const CustomizeScreen()),
  Shot('13_parametres', 248, 450, Color(0xFF14123A), (_) => const SettingsScreen()),
  Shot('14_celebration', 238, 450, Colors.white, (_) => CelebrationScreen(result: GameFinished(demoRanking(), 12, 8))),
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
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  for (final s in shots) {
    testWidgets('capture ${s.name}', (tester) async {
      await tester.runAsync(() => BombAssets.ensureStates(BombState.values));
      final logicalH = logicalWidth * s.refH / s.refW;
      tester.view.physicalSize = Size(logicalWidth * dpr, logicalH * dpr);
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);

      final errors = <String>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.toString());
      final prevErrorWidget = ErrorWidget.builder;
      ErrorWidget.builder = (d) {
        errors.add(d.toString());
        return Container(color: const Color(0xFFFF00FF), child: Text(d.exceptionAsString(), style: const TextStyle(fontSize: 10)));
      };
      addTearDown(() {
        FlutterError.onError = prevOnError;
        ErrorWidget.builder = prevErrorWidget;
      });
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(builder: (ctx) => Stack(children: [
                s.build(ctx),
                Positioned(left: 0, right: 0, top: 0, child: Material(type: MaterialType.transparency, child: StatusBarSim(color: s.statusColor))),
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
      final ex = tester.takeException();
      if (ex != null) errors.add(ex.toString());
      var log = errors.isEmpty ? 'OK' : errors.join('\n\n');
      // Contrôle automatique : débordements de mise en page (bandes jaunes/noires
      // en debug, et peinture interrompue dans les captures).
      final tree = key.currentContext!.findRenderObject()!.toStringDeep(minLevel: DiagnosticLevel.info);
      final overflow = RegExp(r'^.*OVERFLOWING.*\$', multiLine: true).allMatches(tree).map((m) => m.group(0)!.trim()).toList();
      if (overflow.isNotEmpty) log += '\n\nDÉBORDEMENTS :\n${overflow.join('\n')}';
      File('build/captures/${s.name}.log').writeAsStringSync(log);
    });
  }
}
