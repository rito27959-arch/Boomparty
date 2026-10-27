import 'package:boom_party/design/tokens.dart';
import 'package:flutter/material.dart';

/// Barre d'état simulée « 9:41 » de la maquette, utilisée UNIQUEMENT pour les
/// captures de comparaison (sur Android, la vraie barre système s'affiche).
class StatusBarSim extends StatelessWidget {
  const StatusBarSim({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final k = w / 224;
    return SizedBox(
      height: 22 * k,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14 * k),
        child: Row(children: [
          Text('9:41', style: BoomText.ui700(7.5 * k, color: color)),
          const Spacer(),
          for (var i = 0; i < 4; i++)
            Container(
              width: 1.6 * k, height: (2.2 + i * 1.2) * k, margin: EdgeInsets.only(left: 0.8 * k, top: 2 * k),
              color: color, alignment: Alignment.bottomCenter,
            ),
          SizedBox(width: 3 * k),
          Icon(Icons.wifi, size: 7 * k, color: color),
          SizedBox(width: 3 * k),
          Container(
            width: 11 * k, height: 5 * k, margin: EdgeInsets.only(top: 1.5 * k),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5 * k)),
          ),
        ]),
      ),
    );
  }
}
