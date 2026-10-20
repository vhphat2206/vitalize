import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../screens/body_screen.dart';
import '../screens/food_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/routines_screen.dart';
import '../screens/week_screen.dart';
import '../widgets/floor.dart';
import '../widgets/icons.dart';
import 'tabs.dart';
import 'theme.dart';

/// The five tabs. They stay mounted, so the body view keeps its selection when you come back.
/// Pushed screens (vRoute) slide in over all of this, tab bar included.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<TabNav>().tab;
    return Floor(
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: tab.index,
              children: const [
                BodyScreen(),
                RoutinesScreen(),
                FoodScreen(),
                WeekScreen(),
                ProfileScreen(),
              ],
            ),
          ),
          const _TabBar(),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  static final _tabs = [
    (AppTab.body, 'Cơ thể', VIcons.tabBody),
    (AppTab.routines, 'Bài tập', VIcons.tabRoutines),
    (AppTab.food, 'Ăn uống', VIcons.tabFood),
    (AppTab.week, 'Tuần này', VIcons.tabWeek),
    (AppTab.profile, 'Hồ sơ', VIcons.tabProfile),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<TabNav>();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: V.tabBarH + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: V.tabBar,
        border: Border(top: BorderSide(color: V.line)),
      ),
      child: Row(
        children: [
          for (final (tab, label, glyph) in _tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: nav.tab == tab,
                label: label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => nav.go(tab),
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: nav.tab == tab ? V.ink : V.faint),
                    duration: const Duration(milliseconds: 200),
                    curve: V.easeSwift,
                    builder: (context, color, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        VIcon(glyph, color: color),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: VT.ui(
                            11,
                            weight: FontWeight.w500,
                            height: 1,
                            color: color!,
                            em: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
