import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'design/tokens.dart';
import 'screens/home_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/game_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/players_screen.dart';
import 'screens/not_built_screen.dart';

class BoomPartyApp extends StatelessWidget {
  const BoomPartyApp({super.key, this.initialRoute = AppRoutes.home});
  final String initialRoute;

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.home: (_) => const HomeScreen(),
    AppRoutes.modes: (_) => const ModesScreen(),
    AppRoutes.players: (_) => const PlayersScreen(),
    AppRoutes.categories: (_) => const CategoriesScreen(),
    AppRoutes.game: (_) => const GameScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOOM PARTY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: BoomText.ui,
        scaffoldBackgroundColor: BoomColors.cream,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFC21A)),
      ),
      initialRoute: initialRoute,
      routes: routes,
      // Écrans pas encore construits : signalés explicitement, jamais simulés.
      onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => NotBuiltScreen(route: s.name ?? '?')),
    );
  }
}
