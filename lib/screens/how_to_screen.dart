import 'package:flutter/material.dart';

import '../design/screen_chrome.dart';
import '../design/tokens.dart';

/// « Comment jouer ? » (lien du menu d'accueil ; pas d'écran dédié dans la maquette).
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static const _rules = [
    ('💣', 'La bombe passe de joueur en joueur. Sa mèche a une durée secrète.'),
    ('🗣️', 'À ton tour, dis à voix haute un mot de la catégorie demandée.'),
    ('✅', 'Bonne réponse : +1 point et la bombe passe au joueur suivant.'),
    ('🔁', 'Mot déjà dit ou hors catégorie : réessaie, la mèche continue de brûler !'),
    ('💥', 'Si la bombe explose dans tes mains, tu perds 1 point.'),
    ('🏆', 'Après toutes les manches, le meilleur score remporte la soirée.'),
  ];

  @override
  Widget build(BuildContext context) => PastelScreen(
        refW: 214,
        refH: 536,
        title: 'Comment jouer ?',
        titleCenterX: 112,
        builder: (context, r) => [
          Positioned(
            left: r.x(12), right: r.x(12), top: r.y(84), bottom: r.y(20),
            child: ListView(children: [
              for (final (e, t) in _rules)
                Container(
                  margin: EdgeInsets.only(bottom: r.y(8)),
                  padding: EdgeInsets.all(10 * r.k),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12 * r.k)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e, style: TextStyle(fontSize: 16 * r.k)),
                    SizedBox(width: 8 * r.k),
                    Expanded(child: Text(t, style: BoomText.ui600(10.5 * r.k, height: 1.25))),
                  ]),
                ),
            ]),
          ),
        ],
      );
}
