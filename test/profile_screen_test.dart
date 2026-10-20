import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/app/shell.dart';
import 'package:vitalize/app/tabs.dart';
import 'package:vitalize/app/theme.dart';
import 'package:vitalize/screens/profile_screen.dart';
import 'package:vitalize/screens/settings_screen.dart';
import 'package:vitalize/state/prefs_store.dart';
import 'package:vitalize/widgets/stepper.dart';

import 'support/harness.dart';

const _filled = Profile(
  name: 'Minh Anh',
  sex: Sex.male,
  birthYear: 1998,
  heightCm: 170,
  weightKg: 65.5,
  goal: Goal.gain,
);

/// The profile tab above a stand-in for the tab bar, as the shell lays it out.
class _Tab extends StatelessWidget {
  const _Tab();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Expanded(child: ProfileScreen()),
      Container(
        height: V.tabBarH + MediaQuery.paddingOf(context).bottom,
        decoration: const BoxDecoration(
          color: V.tabBar,
          border: Border(top: BorderSide(color: V.line)),
        ),
      ),
    ],
  );
}

/// The web app's screenshot size (402×874 at 2x, no safe areas), to compare side by side.
Future<void> useWebPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(804, 1748);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<PrefsStore> _show(WidgetTester tester, {Profile? profile, bool web = true}) async {
  if (web) {
    await useWebPhone(tester);
  } else {
    await usePhone(tester);
  }
  late PrefsStore store;
  await tester.pumpWidget(
    await appFrame(
      const _Tab(),
      seed: (log, prefs) {
        store = prefs;
        if (profile != null) prefs.updateProfile(profile);
      },
    ),
  );
  // The tab plays its entrance when it comes into view.
  tester.element(find.byType(ProfileScreen)).read<TabNav>().go(AppTab.profile);
  await tester.pump();
  return store;
}

Future<void> _settle(WidgetTester tester) => tester.pump(const Duration(seconds: 2));

/// Lets a sheet or route animation run: the first frame starts its clock.
Future<void> _wait(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(setUpApp);

  testWidgets('empty profile asks for body data', (tester) async {
    await _show(tester);
    await _settle(tester);
    expect(find.text('Bạn'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.text('Đang giữ dáng, tập 3 buổi mỗi tuần.'), findsOneWidget);
    expect(
      find.text(
        'Thêm giới tính, năm sinh, chiều cao, cân nặng để Vitalize tính lượng ăn mỗi ngày cho bạn.',
      ),
      findsOneWidget,
    );
    expect(find.text('Chưa nhập'), findsNWidgets(4));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_empty.png'));
  });

  testWidgets('filled profile shows the daily targets', (tester) async {
    await _show(tester, profile: _filled);
    await _settle(tester);
    expect(find.text('MA'), findsOneWidget);
    expect(find.text('Minh Anh'), findsOneWidget);
    expect(find.text('Đang tăng cơ, tập 3 buổi mỗi tuần.'), findsOneWidget);
    expect(find.text('2.430 kcal'), findsOneWidget);
    expect(find.text('118 g'), findsOneWidget);
    expect(find.text('337 g'), findsOneWidget);
    expect(find.text('68 g'), findsOneWidget);
    final age = DateTime.now().year - 1998;
    expect(find.text('1998 ($age tuổi)'), findsOneWidget);
    expect(find.text('170 cm'), findsOneWidget);
    expect(find.text('65,5 kg'), findsOneWidget);
    expect(find.text('Tăng cơ'), findsOneWidget);
    expect(find.text('Mới tập'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_filled.png'));
  });

  testWidgets('filled profile on a phone with safe areas', (tester) async {
    await _show(tester, profile: _filled, web: false);
    await _settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_phone.png'));
  });

  testWidgets('entrance: head and targets come in after the rows', (tester) async {
    await _show(tester);
    await tester.pump(const Duration(milliseconds: 80));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/profile_entrance_80ms.png'),
    );
    await tester.pump(const Duration(milliseconds: 220));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/profile_entrance_300ms.png'),
    );
    await _settle(tester);
  });

  group('editors', () {
    Future<void> open(WidgetTester tester, String row, {Profile? profile}) async {
      await _show(tester, profile: profile);
      await _settle(tester);
      await tester.tap(find.text(row).first);
      await _wait(tester);
    }

    testWidgets('name', (tester) async {
      await _show(tester);
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Đổi tên'));
      await _wait(tester);
      // The focus ring fades in once the field has taken focus.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Tên của bạn'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_name.png'));
      await tester.enterText(find.byType(TextField), '  Trần   Thu Hà  ');
      await tester.tap(find.text('Lưu'));
      await _wait(tester);
      expect(find.text('Trần   Thu Hà'), findsOneWidget);
      expect(find.text('TH'), findsOneWidget);
    });

    testWidgets('sex saves on tap', (tester) async {
      final prefs = await _showAndOpen(tester, open, 'Giới tính');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_sex.png'));
      await tester.tap(find.text('Nữ'));
      await _wait(tester);
      expect(prefs.profile.sex, Sex.female);
      expect(find.text('Dùng để ước tính năng lượng cơ thể đốt mỗi ngày.'), findsNothing);
      expect(find.text('Nữ'), findsOneWidget);
    });

    testWidgets('birth year steps and saves on Lưu', (tester) async {
      final prefs = await _showAndOpen(tester, open, 'Năm sinh');
      expect(find.text('1998'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_year.png'));
      await tester.tap(find.bySemanticsLabel('Tăng năm sinh'));
      await tester.pump();
      expect(prefs.profile.birthYear, isNull);
      await tester.tap(find.text('Lưu'));
      await _wait(tester);
      expect(prefs.profile.birthYear, 1999);
    });

    testWidgets('weight steps by half a kilo', (tester) async {
      final prefs = await _showAndOpen(tester, open, 'Cân nặng', profile: _filled);
      expect(find.text('65,5'), findsOneWidget);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_weight.png'));
      await tester.tap(find.bySemanticsLabel('Tăng cân nặng'));
      await tester.pump();
      expect(find.text('66'), findsOneWidget);
      await tester.tap(find.text('Lưu'));
      await _wait(tester);
      expect(prefs.profile.weightKg, 66);
      expect(find.text('66 kg'), findsOneWidget);
    });

    testWidgets('height and days use their own ranges', (tester) async {
      await _showAndOpen(tester, open, 'Chiều cao');
      final stepper = tester.widget<VStepper>(find.byType(VStepper));
      expect((stepper.value, stepper.min, stepper.max, stepper.unit), (165, 120, 220, 'cm'));
    });

    testWidgets('goal saves on tap', (tester) async {
      final prefs = await _showAndOpen(tester, open, 'Mục tiêu');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_goal.png'));
      await tester.tap(find.text('Giảm mỡ'));
      await _wait(tester);
      expect(prefs.profile.goal, Goal.lose);
      expect(find.text('Đang giảm mỡ, tập 3 buổi mỗi tuần.'), findsOneWidget);
    });

    testWidgets('level saves on tap', (tester) async {
      final prefs = await _showAndOpen(tester, open, 'Trình độ');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_level.png'));
      await tester.tap(find.text('Nâng cao'));
      await _wait(tester);
      expect(prefs.profile.level, 3);
    });

    testWidgets('sessions a week', (tester) async {
      final prefs = await _showAndOpen(tester, open, 'Số buổi mỗi tuần');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_days.png'));
      await tester.tap(find.bySemanticsLabel('Tăng số buổi'));
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await _wait(tester);
      expect(prefs.profile.daysPerWeek, 4);
      expect(find.text('Đang giữ dáng, tập 4 buổi mỗi tuần.'), findsOneWidget);
    });
  });

  testWidgets('in the shell, the entrance replays each time the tab comes into view', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await tester.pump(const Duration(seconds: 2));
    double targetsOpacity() => tester
        .widget<Opacity>(
          find.ancestor(of: find.text('Mỗi ngày nên ăn'), matching: find.byType(Opacity)).first,
        )
        .opacity;

    await tester.tap(find.text('Hồ sơ'));
    await tester.pump();
    expect(targetsOpacity(), 0);
    await tester.pump(const Duration(seconds: 2));
    expect(targetsOpacity(), 1);

    // Away and back: the tab animates in again, as on the web.
    await tester.tap(find.text('Cơ thể').last); // the tab, not the group title
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Hồ sơ'));
    await tester.pump();
    expect(targetsOpacity(), 0);
    await tester.pump(const Duration(seconds: 2));
    expect(targetsOpacity(), 1);
  });

  testWidgets('a long name and large text still fit', (tester) async {
    await usePhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      await appFrame(
        const _Tab(),
        seed: (log, prefs) => prefs.updateProfile(
          _filled.copyWith(name: 'Nguyễn Thị Phương Thảo Nguyên Khánh Linh', daysPerWeek: 7),
        ),
      ),
    );
    tester.element(find.byType(ProfileScreen)).read<TabNav>().go(AppTab.profile);
    await tester.pump();
    await _settle(tester);
    expect(find.text('KL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sliders button opens the settings', (tester) async {
    await _show(tester);
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Cài đặt'));
    await _wait(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}

/// Shows the profile and opens the sheet behind [row]; returns the prefs to check saves.
Future<PrefsStore> _showAndOpen(
  WidgetTester tester,
  Future<void> Function(WidgetTester, String, {Profile? profile}) open,
  String row, {
  Profile? profile,
}) async {
  await open(tester, row, profile: profile);
  return tester.element(find.byType(ProfileScreen)).read<PrefsStore>();
}
