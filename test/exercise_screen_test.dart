import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/app/toast.dart';
import 'package:vitalize/screens/exercise_screen.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/widgets/back_bar.dart';
import 'package:vitalize/widgets/icons.dart';
import 'package:vitalize/widgets/stepper.dart';

import 'support/harness.dart';

Finder get _screen => find.byType(ExerciseScreen).first;

/// The part of the screen in [area] (logical pixels), everything drawn over it included: for
/// goldens that leave out the animated demo, which has its own tests.
Future<ui.Image> _region(WidgetTester tester, Rect area) async {
  final dpr = tester.view.devicePixelRatio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(
    () => layer.toImage(
      Rect.fromLTWH(area.left * dpr, area.top * dpr, area.width * dpr, area.height * dpr),
      pixelRatio: 1 / dpr,
    ),
  );
  return image!;
}

/// Lets [ms] pass in 60 Hz frames.
Future<void> _frames(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The page's own vertical scroll position.
ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
    )
    .position;

Finder _stepper(String label) => find.byWidgetPredicate((w) => w is VStepper && w.label == label);

/// The value of the stepper labelled [label].
double _stepperValue(WidgetTester tester, String label) =>
    tester.widget<VStepper>(_stepper(label)).value;

/// Taps the + (or −) of the stepper labelled [label], and lets a frame pass.
Future<void> _step(WidgetTester tester, String label, {bool up = true}) async {
  await tester.tap(
    find.descendant(
      of: _stepper(label),
      matching: find.byWidgetPredicate(
        (w) => w is VIcon && w.glyph == (up ? VIcons.plus : VIcons.minus),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  setUpAll(setUpApp);

  testWidgets('the page reads top to bottom like the web one', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const ExerciseScreen(id: 'barbell-bench-press')));
    // the head of the page, above the demo
    const head = Rect.fromLTWH(0, 0, 402, 236);
    await _frames(tester, 200);
    await expectLater(
      await _region(tester, head),
      matchesGoldenFile('goldens/exercise_entering.png'),
    );
    await _frames(tester, 2000);
    await expectLater(await _region(tester, head), matchesGoldenFile('goldens/exercise_head.png'));
    for (final t in ['Tạ đòn', 'Đã quen', 'Đẩy ngực tạ đòn', 'Barbell bench press']) {
      expect(find.text(t), findsWidgets);
    }
    for (final t in ['Hiệp', 'Lần mỗi hiệp', '6–10', 'Nghỉ', '2 phút']) {
      expect(find.text(t), findsOneWidget);
    }
    // the bar fills in, with the name, once the page scrolls under it
    expect(tester.widget<BackBar>(find.byType(BackBar)).solid, isFalse);
    _scroll(tester).jumpTo(700);
    await _frames(tester, 500);
    expect(tester.widget<BackBar>(find.byType(BackBar)).solid, isTrue);
    await expectLater(_screen, matchesGoldenFile('goldens/exercise_steps.png'));
    _scroll(tester).jumpTo(_scroll(tester).maxScrollExtent);
    await _frames(tester, 500);
    expect(find.text('Cùng nhóm cơ'), findsOneWidget);
    expect(find.text('Tài liệu tham khảo'), findsOneWidget);
    await expectLater(_screen, matchesGoldenFile('goldens/exercise_end.png'));
  });

  testWidgets('a note, and no English line when the names match', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const ExerciseScreen(id: 'push-up')));
    await _frames(tester, 2000);
    expect(find.text('Chưa làm được 8 lần thì chống tay lên ghế hoặc mép bàn.'), findsOneWidget);
    _scroll(tester).jumpTo(700);
    await _frames(tester, 500);
    await expectLater(_screen, matchesGoldenFile('goldens/exercise_note.png'));

    await tester.pumpWidget(await appFrame(const ExerciseScreen(id: 'plank')));
    await _frames(tester, 2000);
    expect(find.text('Plank'), findsWidgets);
    expect(find.text('Plank', skipOffstage: false), findsNWidgets(2)); // the name and the bar's
    expect(find.text('Giây mỗi hiệp'), findsOneWidget);
  });

  testWidgets('logging a set: weight and reps, then undo from the toast', (tester) async {
    await usePhone(tester);
    late LogStore log;
    await tester.pumpWidget(
      await appFrame(const ExerciseScreen(id: 'barbell-bench-press'), seed: (l, _) => log = l),
    );
    await _frames(tester, 2000);
    expect(find.text('Hôm nay'), findsNothing);

    await tester.tap(find.text('Ghi một hiệp'));
    await _frames(tester, 800);
    expect(_stepperValue(tester, 'Mức tạ'), 20);
    expect(_stepperValue(tester, 'Số lần'), 6);
    expect(find.text('Thời gian'), findsNothing);
    await _step(tester, 'Mức tạ');
    await _step(tester, 'Mức tạ');
    await _frames(tester, 200);
    expect(_stepperValue(tester, 'Mức tạ'), 25);
    await expectLater(
      await _region(tester, const Rect.fromLTWH(0, 490, 402, 384)),
      matchesGoldenFile('goldens/exercise_log.png'),
    );

    await tester.tap(find.text('Lưu hiệp'));
    await _frames(tester, 800);
    expect(log.sets, hasLength(1));
    expect(log.sets.single.kg, 25);
    expect(log.sets.single.reps, 6);
    expect(log.sets.single.seconds, isNull);
    expect(find.text('Lưu hiệp'), findsNothing);
    expect(find.text('Đã ghi 25 kg × 6'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('25 kg × 6'), findsOneWidget);
    await expectLater(
      await _region(tester, const Rect.fromLTWH(0, 700, 402, 174)),
      matchesGoldenFile('goldens/exercise_logged.png'),
    );

    // the next set starts from the last one
    await tester.tap(find.text('Ghi một hiệp'));
    await _frames(tester, 800);
    expect(_stepperValue(tester, 'Mức tạ'), 25);
    await _step(tester, 'Số lần', up: false);
    await tester.tap(find.text('Lưu hiệp'));
    await _frames(tester, 800);
    expect(find.text('25 kg × 5'), findsOneWidget);
    expect(find.text('Đã ghi 25 kg × 5'), findsOneWidget);

    await tester.tap(find.text('Hoàn tác'));
    await _frames(tester, 300);
    expect(log.sets, hasLength(1));
    expect(find.text('25 kg × 5'), findsNothing);
    expect(find.text('25 kg × 6'), findsOneWidget);
  });

  testWidgets('a hold logs seconds only, a bar exercise reps only', (tester) async {
    await usePhone(tester);
    late LogStore log;
    await tester.pumpWidget(
      await appFrame(const ExerciseScreen(id: 'plank'), seed: (l, _) => log = l),
    );
    await _frames(tester, 1500);
    await tester.tap(find.text('Ghi một hiệp'));
    await _frames(tester, 800);
    expect(find.text('Mức tạ'), findsNothing);
    expect(find.text('Số lần'), findsNothing);
    expect(_stepperValue(tester, 'Thời gian'), 30);
    await _step(tester, 'Thời gian');
    await _step(tester, 'Thời gian');
    await tester.pump();
    expect(_stepperValue(tester, 'Thời gian'), 40);
    await tester.tap(find.text('Lưu hiệp'));
    await _frames(tester, 800);
    expect(log.sets.single.seconds, 40);
    expect(log.sets.single.reps, isNull);
    expect(log.sets.single.kg, isNull);
    expect(find.text('Đã ghi 40 giây'), findsOneWidget);
    Toast.hide();

    await tester.pumpWidget(
      await appFrame(const ExerciseScreen(id: 'chest-dip'), seed: (l, _) => log = l),
    );
    await _frames(tester, 1500);
    await tester.tap(find.text('Ghi một hiệp'));
    await _frames(tester, 800);
    expect(find.text('Mức tạ'), findsNothing);
    expect(_stepperValue(tester, 'Số lần'), 6);
    await tester.tap(find.text('Lưu hiệp'));
    await _frames(tester, 800);
    expect(log.sets.single.reps, 6);
    expect(log.sets.single.kg, isNull);
    expect(find.text('Đã ghi 6 lần'), findsOneWidget);
    Toast.hide(); // its timer would outlive the test
  });

  testWidgets("yesterday's set seeds the form but is not today's", (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        const ExerciseScreen(id: 'barbell-bench-press'),
        seed: (log, _) {
          log.restoreSet(
            LoggedSet(
              id: 'y',
              exerciseId: 'barbell-bench-press',
              at: DateTime.now().subtract(const Duration(days: 1)),
              kg: 42.5,
              reps: 8,
            ),
          );
        },
      ),
    );
    await _frames(tester, 1500);
    expect(find.text('Hôm nay'), findsNothing);
    await tester.tap(find.text('Ghi một hiệp'));
    await _frames(tester, 800);
    expect(_stepperValue(tester, 'Mức tạ'), 42.5);
    expect(_stepperValue(tester, 'Số lần'), 8);
  });

  testWidgets('a related exercise opens over this one', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const ExerciseScreen(id: 'barbell-bench-press')));
    await _frames(tester, 1500);
    _scroll(tester).jumpTo(_scroll(tester).maxScrollExtent);
    await _frames(tester, 300);
    await tester.tap(find.text('Dips ngực'));
    await _frames(tester, 1000);
    final screens = tester.widgetList<ExerciseScreen>(
      find.byType(ExerciseScreen, skipOffstage: false),
    );
    expect(screens.map((s) => s.id), ['barbell-bench-press', 'chest-dip']);
  });
}
