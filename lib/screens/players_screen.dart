import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../design/avatars.dart';
import '../design/candy_button.dart';
import '../design/illustrations.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../engine/game_engine.dart';
import '../state/app_state.dart';

/// Écran 3 — Joueurs. Référence : reference/03_joueurs.png (196 × 536).
class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  static const rowH = 56.0; // hauteur de ligne (px référence)

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    return PastelScreen(
      refW: 196,
      refH: 536,
      title: 'Joueurs',
      titleCenterX: 96,
      builder: (context, r) => [
        Positioned(
          left: r.x(8), right: r.x(8), top: r.y(82), bottom: r.y(536 - 420),
          child: ListenableBuilder(
            listenable: st,
            builder: (context, _) => Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(r.x(14)),
              ),
              child: CustomScrollView(slivers: [
                SliverReorderableList(
                  itemCount: st.players.length,
                  onReorder: st.reorderPlayers,
                  itemBuilder: (context, i) => _PlayerRow(
                    key: ValueKey(st.players[i].id),
                    index: i,
                    player: st.players[i],
                    r: r,
                    height: r.y(rowH),
                  ),
                ),
                SliverToBoxAdapter(child: _AddRow(r: r, height: r.y(rowH))),
              ]),
            ),
          ),
        ),
        Positioned(
          left: r.x(12), right: r.x(12), top: r.y(458),
          child: CandyButton(
            height: r.y(44), depth: r.y(4),
            top: BoomColors.pinkTop, bottom: BoomColors.pinkBottom, edge: BoomColors.pinkEdge,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.categories),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Continuer', style: BoomText.ui800(16 * r.k, color: Colors.white)),
              SizedBox(width: r.x(12)),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: r.x(17)),
            ]),
          ),
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({super.key, required this.index, required this.player, required this.r, required this.height});
  final int index;
  final Player player;
  final RefScale r;
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = r.k;
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: height,
        child: Stack(children: [
          if (index > 0)
            Positioned(left: 56 * k, right: 12 * k, top: 0, child: Container(height: 1, color: const Color(0x1F6B4FA0))),
          Row(children: [
            SizedBox(width: 6 * k),
            PlayerAvatar(index: player.avatar, size: 46 * k),
            SizedBox(width: 9 * k),
            Expanded(child: Text(player.name, style: BoomText.ui700(12.5 * k), overflow: TextOverflow.ellipsis)),
            if (index == 0)
              SizedBox(width: 26 * k, height: 22 * k, child: const CustomPaint(painter: CrownPainter()))
            else
              _CircleIconButton(
                size: 24 * k,
                icon: Icons.edit_outlined,
                onTap: () => _rename(context),
              ),
            SizedBox(width: 9 * k),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.all(4 * k),
                child: Icon(Icons.menu_rounded, size: 16 * k, color: const Color(0xFF9C8FB8)),
              ),
            ),
            SizedBox(width: 6 * k),
          ]),
        ]),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name = await askName(context, initial: player.name, title: 'Modifier le joueur');
    if (name != null) AppState.instance.renamePlayer(player, name);
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.r, required this.height});
  final RefScale r;
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = r.k;
    return InkWell(
      onTap: () async {
        final name = await askName(context, title: 'Ajouter un joueur');
        if (name != null) AppState.instance.addPlayer(name);
      },
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned(left: 56 * k, right: 12 * k, top: 0, child: Container(height: 1, color: const Color(0x1F6B4FA0))),
          Row(children: [
            SizedBox(width: 14 * k),
            Container(
              width: 30 * k, height: 30 * k,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3B9BFF), Color(0xFF1767D8)]),
                boxShadow: [BoxShadow(color: Color(0x332F80ED), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 22 * k),
            ),
            SizedBox(width: 17 * k),
            Text('Ajouter un joueur', style: BoomText.ui600(11.5 * k)),
          ]),
        ]),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.size, required this.icon, required this.onTap});
  final double size;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE6F3)),
          child: Icon(icon, size: size * 0.6, color: const Color(0xFF2C2350)),
        ),
      );
}

Future<String?> askName(BuildContext context, {String initial = '', required String title}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BoomColors.creamLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: BoomText.ui800(20)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        maxLength: 16,
        textCapitalization: TextCapitalization.words,
        style: BoomText.ui600(18),
        decoration: const InputDecoration(hintText: 'Prénom'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: BoomText.ui700(16))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctl.text.trim().isEmpty ? null : ctl.text.trim()),
          child: Text('OK', style: BoomText.ui800(16, color: BoomColors.pinkBottom)),
        ),
      ],
    ),
  );
}
