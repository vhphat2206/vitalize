import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/screens/exercise_screen.dart';
import 'package:vitalize/screens/routine_screen.dart';
import 'package:vitalize/screens/week_screen.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/widgets/body_figure.dart';

import 'food_week_support.dart';
import 'support/harness.dart';

LogStore _log(WidgetTester tester) =>
    Provider.of<LogStore>(tester.element(find.byType(WeekScreen)), listen: false);

void main() {
  setUpAll(setUpApp);

  testWidgets('an empty week', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(WeekScreen(now: testNow)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('19/10 – 25/10'), findsOneWidget);
    expect(
      find.text(
        'Tuần này chưa có gì. Mở một bài tập và bấm “Ghi một hiệp”, cơ bạn tập sẽ đỏ dần trên '
        'hình.',
      ),
      findsOneWidget,
    );
    for (final t in ['1–5 hiệp', '6–11', '12 trở lên']) {
      expect(find.text(t), findsOneWidget);
    }
    await snap(tester, 'week-empty');
    await expectLater(find.byType(WeekScreen), matchesGoldenFile('goldens/week_empty.png'));
  });

  testWidgets('a week of training', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(WeekScreen(now: testNow), seed: seedStores));
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.text(
        'Bạn đã ghi 21 hiệp, nhiều nhất cho đùi trước. Chưa có hiệp nào cho đùi sau. '
        '2 buổi tập ngắn đã xong.',
      ),
      findsOneWidget,
    );
    final tones = tester.widget<BodyFigure>(find.byType(BodyFigure).first).tones;
    expect(tones['quadriceps'], Tone.vol3, reason: '12 sets');
    expect(tones['chest'], Tone.vol2, reason: '6 sets');
    expect(tones['upper-back'], Tone.vol1);
    expect(tones.containsKey('hamstring'), isFalse);
    // newest day first, sessions before sets
    final tuesday = tester.getTopLeft(find.text('Thứ Ba 20/10')).dy;
    final monday = tester.getTopLeft(find.text('Thứ Hai 19/10')).dy;
    expect(tuesday, lessThan(monday));
    expect(find.text('Chủ nhật 18/10'), findsNothing, reason: 'last week');
    expect(
      tester.getTopLeft(find.text('Core 12 phút')).dy,
      lessThan(tester.getTopLeft(find.text('Squat tạ đòn').first).dy),
    );
    expect(find.text('12 phút'), findsOneWidget);
    expect(find.text('6 phút'), findsOneWidget);
    expect(find.text('45 giây'), findsOneWidget);
    expect(find.text('60 kg × 5'), findsNWidgets(3));
    await snap(tester, 'week');
    await expectLater(find.byType(WeekScreen), matchesGoldenFile('goldens/week.png'));

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, 'week-log');
  });

  testWidgets('delete a set, undo; open an exercise and a routine', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(WeekScreen(now: testNow), seed: seedStores));
    await tester.pump(const Duration(seconds: 2));
    final plank = find.text('Plank');
    await tester.ensureVisible(plank);
    await tester.pump();
    final count = _log(tester).sets.length;
    // the trash button on the plank's row
    final trash = find.bySemanticsLabel('Xoá hiệp này');
    final row = tester.getCenter(plank).dy;
    final mine = trash.evaluate().firstWhere(
      (e) => ((tester.getCenter(find.byWidget(e.widget)).dy) - row).abs() < 30,
    );
    await tester.tap(find.byWidget(mine.widget));
    await tester.pump();
    expect(_log(tester).sets.length, count - 1);
    expect(find.text('Plank'), findsNothing);
    expect(find.text('Đã xoá một hiệp'), findsOneWidget);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pump();
    expect(_log(tester).sets.length, count);
    expect(find.text('Plank'), findsOneWidget);

    // (the pushed screens animate demos forever, so pump fixed times instead of settling)
    await tester.tap(find.text('Plank'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<ExerciseScreen>(find.byType(ExerciseScreen)).id, 'plank');
    Navigator.of(tester.element(find.byType(ExerciseScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ExerciseScreen), findsNothing);

    await tester.ensureVisible(find.text('Core 12 phút'));
    await tester.tap(find.text('Core 12 phút'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<RoutineScreen>(find.byType(RoutineScreen)).id, 'core-12');
  });

  test('the week in a sentence', () {
    expect(weekSentence(0, 2, {}), '2 buổi tập ngắn đã xong.');
    expect(
      weekSentence(2, 0, {'biceps': 2, 'forearm': 1}),
      'Bạn đã ghi 2 hiệp, nhiều nhất cho tay trước. Chưa có hiệp nào cho ngực, vai, lưng xô, '
      'mông, đùi trước và đùi sau.',
    );
    // ties go to the muscle logged first
    expect(
      weekSentence(1, 0, {
        'triceps': 1,
        'chest': 1,
        'deltoids': 1,
        'upper-back': 1,
        'quadriceps': 1,
        'hamstring': 1,
        'gluteal': 0.5,
      }),
      'Bạn đã ghi 1 hiệp, nhiều nhất cho tay sau.',
    );
  });
}
