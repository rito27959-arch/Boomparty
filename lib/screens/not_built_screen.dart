import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Signale clairement un écran non encore implémenté (directive §13).
class NotBuiltScreen extends StatelessWidget {
  const NotBuiltScreen({super.key, required this.route});
  final String route;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: BoomColors.cream),
        body: Center(
          child: Text('Écran non implémenté : $route', style: BoomText.ui700(18)),
        ),
      );
}
