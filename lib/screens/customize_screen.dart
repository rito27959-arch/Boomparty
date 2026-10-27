import 'package:flutter/material.dart';

import '../design/illustration.dart';
import '../character/skins.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../screens/settings_screen.dart' show CandySwitch;
import '../services/settings_store.dart';
import '../services/wallet.dart';

/// Écran 12 — Personnalisation. Référence : reference/12_personnalisation.png (294 × 450).
class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({super.key});

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;
    final wallet = Wallet.instance;
    return PastelScreen(
      refW: 294,
      refH: 450,
      title: 'Personnalisation',
      titleCenterX: 148,
      headerY: 37,
      titleSize: 13.5,
      decor: PastelDecor.pinkCloudRight,
      builder: (context, r) {
        final k = r.k;
        const tabs = ['Bombes', 'Arrières-plans', 'Effets'];
        const tabX = [(14.0, 98.0), (102.0, 198.0), (202.0, 282.0)];
        return [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: r.x(tabX[i].$1), width: r.x(tabX[i].$2 - tabX[i].$1), top: r.y(64), height: r.y(30),
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == i ? const Color(0xFF3D2A5E) : const Color(0xFFF6E3DA),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: _tab == i ? const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))] : null,
                  ),
                  child: Text(tabs[i], style: BoomText.ui700(10.5 * k, color: _tab == i ? Colors.white : const Color(0xFF2A2048))),
                ),
              ),
            ),
          Positioned(
            left: r.x(12), right: r.x(11), top: r.y(106), bottom: 0,
            child: ListenableBuilder(
              listenable: Listenable.merge([settings, wallet]),
              builder: (context, _) => switch (_tab) {
                0 => _skins(r, settings, wallet),
                1 => _backgrounds(k),
                _ => _effects(k, settings),
              },
            ),
          ),
        ];
      },
    );
  }

  Widget _skins(RefScale r, SettingsStore settings, Wallet wallet) {
    final k = r.k;
    return GridView.builder(
      padding: EdgeInsets.only(bottom: r.y(20)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisExtent: r.y(101), crossAxisSpacing: r.x(10), mainAxisSpacing: r.y(11),
      ),
      itemCount: bombSkins.length,
      itemBuilder: (context, i) {
        final s = bombSkins[i];
        final owned = wallet.isUnlocked(s.id, s.price);
        final equipped = settings.skin == s.id;
        return GestureDetector(
          onTap: () async {
            if (!owned) {
              final ok = await wallet.buy(s.id, s.price);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Il te faut ${s.price} gemmes (tu en as ${wallet.gems}). Joue des parties pour en gagner !'),
                ));
                return;
              }
            }
            settings.update((x) => x.skin = s.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13 * k),
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: owned ? [s.cardTop, s.cardBottom] : [Color.lerp(s.cardTop, Colors.grey, 0.35)!, Color.lerp(s.cardBottom, Colors.grey, 0.35)!],
              ),
              border: Border.all(color: equipped ? Colors.white : Colors.white.withValues(alpha: 0.5), width: (equipped ? 2.5 : 1) * k),
              boxShadow: const [BoxShadow(color: Color(0x2A000000), blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12 * k),
              child: Stack(children: [
                Positioned(
                  left: 6 * k, right: 6 * k, top: 2 * k, bottom: 22 * k,
                  child: Illustration('skin_${s.id}', scale: 1.25, alignment: Alignment.bottomCenter),
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0, height: (equipped ? 30 : 24) * k,
                  child: Container(
                    color: equipped ? const Color(0xCC2E6B1E) : Colors.black.withValues(alpha: owned ? 0.0 : 0.35),
                    alignment: Alignment.center,
                    child: owned
                        ? Text(equipped ? '${s.label}\nÉquipée' : s.label,
                            textAlign: TextAlign.center,
                            style: BoomText.ui800((equipped ? 10 : 12) * k, color: Colors.white, height: 1.0)
                                .copyWith(shadows: [Shadow(color: Colors.black.withValues(alpha: 0.4), offset: Offset(0, 1 * k), blurRadius: 2 * k)]))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(width: 15 * k, height: 15 * k, child: const Illustration('gem')),
                            SizedBox(width: 3 * k),
                            Text('${s.price}', style: BoomText.ui800(12 * k, color: Colors.white)),
                          ]),
                  ),
                ),
                if (!owned)
                  Positioned(
                    right: 6 * k, top: 6 * k,
                    child: Icon(Icons.lock_rounded, size: 14 * k, color: const Color(0xFFFFC21A)),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _backgrounds(double k) => Padding(
        padding: EdgeInsets.only(top: 6 * k),
        child: Text(
          "Décor disponible : Salon chaleureux (utilisé en jeu).\n"
          "Ressource manquante : aucun autre décor n'a été fourni dans les maquettes.",
          style: BoomText.ui600(10 * k, color: const Color(0xFF3A2E5C)),
        ),
      );

  Widget _effects(double k, SettingsStore s) => Column(children: [
        Row(children: [
          Expanded(child: Text('Mouvements et flashs réduits', style: BoomText.ui700(11 * k))),
          CandySwitch(value: s.reducedMotion, onChanged: (v) => s.update((x) => x.reducedMotion = v), width: 34 * k),
        ]),
        SizedBox(height: 6 * k),
        Text("Réduit le flash et le nombre de particules de l'explosion.", style: BoomText.ui600(9 * k, color: const Color(0xFF6B5E8A))),
        SizedBox(height: 16 * k),
        Row(children: [
          Expanded(child: Text('Graphismes allégés', style: BoomText.ui700(11 * k))),
          CandySwitch(value: s.lowGraphics, onChanged: (v) => s.update((x) => x.lowGraphics = v), width: 34 * k),
        ]),
        SizedBox(height: 6 * k),
        Text('Pour les téléphones modestes : animations en demi-résolution (mémoire ÷ 4). '
            'Pris en compte au prochain lancement.', style: BoomText.ui600(9 * k, color: const Color(0xFF6B5E8A))),
      ]);
}
