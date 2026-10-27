import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../design/candy_button.dart';
import '../design/category_icons.dart';
import '../design/screen_chrome.dart';
import '../design/tokens.dart';
import '../engine/word_bank.dart';
import '../state/app_state.dart';

/// Écran 4 — Choix de catégorie. Référence : reference/04_categories.png (204 × 536).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CatStyle {
  const _CatStyle(this.top, this.bottom, this.edge, this.label, {this.dark = false});
  final Color top, bottom, edge;
  final String? label;
  final bool dark;
}

const _styles = <String, _CatStyle>{
  'animaux': _CatStyle(Color(0xFFC07BFA), Color(0xFF9A52F2), Color(0xFF7436D0), 'Animaux'),
  'pays': _CatStyle(Color(0xFF3ED6FB), Color(0xFF14AEF2), Color(0xFF0D7FC4), 'Pays'),
  'objets': _CatStyle(Color(0xFFFFD83A), Color(0xFFFFAF1A), Color(0xFFE08508), 'Objets', dark: true),
  'nourriture': _CatStyle(Color(0xFFFF8A35), Color(0xFFF5463C), Color(0xFFC92A2A), 'Nourriture'),
  'metiers': _CatStyle(Color(0xFF39A2FF), Color(0xFF1E6CF0), Color(0xFF184FC0), 'Métiers'),
  'sports': _CatStyle(Color(0xFF5BE25E), Color(0xFF1DBA4A), Color(0xFF138A36), 'Sports'),
  'films': _CatStyle(Color(0xFFCB6CF8), Color(0xFF9C3DF0), Color(0xFF7426C4), 'Films / Séries'),
  'musique': _CatStyle(Color(0xFF8A7BFF), Color(0xFF5B48F0), Color(0xFF3F2EC4), 'Musique'),
  'vehicules': _CatStyle(Color(0xFFCBE6FF), Color(0xFFA9D2F7), Color(0xFF86B4E0), null),
  'autres': _CatStyle(Color(0xFFFFF4A8), Color(0xFFFFE67A), Color(0xFFE9C850), 'Autres', dark: true),
};

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    return PastelScreen(
      refW: 204,
      refH: 536,
      title: 'Choix de catégorie',
      titleCenterX: 103,
      titleSize: 14.5,
      decor: PastelDecor.pinkCloudRight,
      builder: (context, r) {
        final k = r.k;
        final list = categories
            .where((c) => _query.isEmpty || c.label.toLowerCase().contains(_query.toLowerCase()))
            .toList();
        return [
          // recherche
          Positioned(
            left: r.x(7), right: r.x(7), top: r.y(82), height: r.y(31),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(r.y(16)),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(children: [
                SizedBox(width: 10 * k),
                Icon(Icons.search_rounded, size: 14 * k, color: const Color(0xFF7D6FA0)),
                SizedBox(width: 5 * k),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: BoomText.ui600(9.2 * k),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Rechercher une catégorie...',
                      hintStyle: BoomText.ui600(9.2 * k, color: const Color(0xFF8C7FB0)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          // grille
          Positioned(
            left: r.x(7), right: r.x(7), top: r.y(125), bottom: 0,
            child: ListenableBuilder(
              listenable: st,
              builder: (context, _) => GridView.builder(
                padding: EdgeInsets.only(bottom: st.selectedCategories.isEmpty ? r.y(20) : r.y(90)),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: r.y(7),
                  crossAxisSpacing: r.x(6),
                  mainAxisExtent: r.y(78),
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  final s = _styles[c.id]!;
                  final sel = st.selectedCategories.contains(c.id);
                  return CandyCard(
                    top: s.top, bottom: s.bottom, edge: s.edge, radius: 14 * k, depth: r.y(3),
                    selected: sel,
                    onTap: () => st.toggleCategory(c.id),
                    child: Stack(children: [
                      Align(
                        alignment: Alignment(0, s.label == null ? 0.1 : -0.45),
                        child: CategoryIcon(c.id, size: (s.label == null ? 52 : 40) * k),
                      ),
                      if (s.label != null)
                        Align(
                          alignment: const Alignment(0, 0.82),
                          child: Text(s.label!,
                              style: BoomText.ui800(12 * k, color: s.dark ? const Color(0xFF2A1A10) : Colors.white).copyWith(
                                  shadows: s.dark ? null : [Shadow(color: Colors.black.withValues(alpha: 0.25), offset: Offset(0, 1 * k), blurRadius: 1.5 * k)])),
                        ),
                      if (sel)
                        Positioned(
                          right: 6 * k, top: 6 * k,
                          child: Container(
                            width: 16 * k, height: 16 * k,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            child: Icon(Icons.check_rounded, size: 12 * k, color: const Color(0xFF1DBA4A)),
                          ),
                        ),
                    ]),
                  );
                },
              ),
            ),
          ),
          // bouton jouer : n'apparaît que quand au moins une catégorie est choisie
          ListenableBuilder(
            listenable: st,
            builder: (context, _) => st.selectedCategories.isEmpty
                ? const SizedBox.shrink()
                : Positioned(
                    left: r.x(14), right: r.x(14), bottom: r.y(16),
                    child: CandyButton(
                      height: r.y(44), depth: r.y(4),
                      top: BoomColors.yellowTop, bottom: BoomColors.yellowBottom, edge: BoomColors.yellowEdge,
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.game),
                      child: Text('Lancer la partie (${st.selectedCategories.length})', style: BoomText.ui800(15 * k)),
                    ),
                  ),
          ),
        ];
      },
    );
  }
}
