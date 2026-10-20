import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/app/tabs.dart';
import 'package:vitalize/screens/food_screen.dart';
import 'package:vitalize/screens/week_screen.dart';

import 'food_week_support.dart';
import 'support/harness.dart';

/// The shell keeps tabs mounted in an IndexedStack; this one holds only the two tabs under test.
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<TabNav>().tab;
    return IndexedStack(
      index: switch (tab) {
        AppTab.food => 1,
        AppTab.week => 2,
        _ => 0,
      },
      children: [
        const SizedBox.expand(),
        FoodScreen(now: testNow),
        WeekScreen(now: testNow),
      ],
    );
  }
}

void main() {
  setUpAll(setUpApp);

  testWidgets('a tab replays its entrance each time it is shown', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const _Tabs()));
    final nav = Provider.of<TabNav>(tester.element(find.byType(_Tabs)), listen: false);
    double rise(String title) => tester
        .widget<FractionalTranslation>(
          find
              .ancestor(
                of: find.text(title, skipOffstage: false),
                matching: find.byType(FractionalTranslation, skipOffstage: false),
              )
              .first, // the nearest: the title's own, not a route transition's
        )
        .translation
        .dy;

    // hidden at start: held before its entrance
    await tester.pump(const Duration(seconds: 3));
    expect(rise('Ăn uống'), closeTo(1.05, 0.001));

    for (var round = 0; round < 2; round++) {
      nav.go(AppTab.food);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rise('Ăn uống'), greaterThan(0.2), reason: 'still rising (round $round)');
      await tester.pump(const Duration(seconds: 2));
      expect(rise('Ăn uống'), 0);

      nav.go(AppTab.week);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rise('Tuần này'), greaterThan(0.2));
      await tester.pump(const Duration(seconds: 2));
      expect(rise('Tuần này'), 0);
    }

    // a screen pushed over the tab and popped again doesn't replay it
    nav.go(AppTab.food);
    await tester.pump(const Duration(seconds: 2));
    final navigator = Navigator.of(tester.element(find.byType(FoodScreen)));
    navigator.push(PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.expand()));
    await tester.pump(const Duration(seconds: 1));
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(rise('Ăn uống'), 0);
  });
}
