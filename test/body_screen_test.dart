import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/app/shell.dart';
import 'package:vitalize/app/tabs.dart';
import 'package:vitalize/screens/body/brand.dart';
import 'package:vitalize/screens/exercise_screen.dart';
import 'package:vitalize/widgets/body_figure.dart';

import 'support/harness.dart';

Finder get _shell => find.byType(Shell);

/// Lets [time] pass in 60 Hz frames, so animations that start others run as on a phone.
Future<void> _frames(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The figure as painted: its side and the tones it was given.
BodyFigure _figure(WidgetTester tester) => tester.widget<BodyFigure>(find.byType(BodyFigure));

void main() {
  setUpAll(setUpApp);

  testWidgets('the outline draws itself, then the strip of names comes in', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await _frames(tester, 600);
    await expectLater(_shell, matchesGoldenFile('goldens/body_intro.png'));
    await _frames(tester, 3000);
    await expectLater(_shell, matchesGoldenFile('goldens/body.png'));
  });

  testWidgets('a muscle opens its sheet; the header snaps it; the filter narrows it', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await _frames(tester, 3000);

    await tester.tap(find.text('Ngực'));
    await _frames(tester);
    expect(_figure(tester).tones, {'chest': Tone.primary});
    expect(find.text('Đẩy tay ra trước và khép tay vào thân.'), findsOneWidget);
    expect(find.text('Pectoralis major'), findsOneWidget);
    await expectLater(_shell, matchesGoldenFile('goldens/body_half.png'));

    // a tap on the header opens it all the way, another brings it back
    await tester.tap(find.text('Pectoralis major'));
    await _frames(tester);
    await expectLater(_shell, matchesGoldenFile('goldens/body_full.png'));

    await tester.tap(find.text('Tạ đòn').first);
    await _frames(tester, 200);
    await expectLater(_shell, matchesGoldenFile('goldens/body_filter_in.png'));
    await _frames(tester);
    expect(find.text('Đẩy ngực tạ đòn'), findsOneWidget);
    expect(find.text('Đẩy ngực dốc lên tạ đơn'), findsNothing);
    expect(find.text('Bài khác cũng dùng tới ngực'), findsOneWidget);
    await expectLater(_shell, matchesGoldenFile('goldens/body_filter.png'));

    await tester.tap(find.text('Pectoralis major'));
    await _frames(tester);

    // another muscle on the figure, while the sheet is half open: the filter resets
    final figure = tester.getRect(find.byType(BodyFigure));
    await tester.tapAt(Offset(figure.center.dx, figure.top + figure.height * 0.44));
    await _frames(tester);
    expect(_figure(tester).tones, {'abs': Tone.primary});
    expect(find.text('Rectus abdominis'), findsOneWidget);
    expect(find.text('Gập bụng'), findsOneWidget);
    await expectLater(_shell, matchesGoldenFile('goldens/body_abs.png'));

    // close: the sheet slides away, then the selection clears
    await tester.tap(find.bySemanticsLabel('Đóng'));
    await _frames(tester, 120);
    await expectLater(_shell, matchesGoldenFile('goldens/body_closing.png'));
    await _frames(tester);
    expect(_figure(tester).tones, isEmpty);
    expect(find.text('Chạm vào nhóm cơ bạn muốn tập.'), findsOneWidget);
    // the strip scrolled the last muscle picked into the middle while it was hidden
    expect(tester.getCenter(find.text('Bụng')).dx, moreOrLessEquals(201, epsilon: 2));
  });

  testWidgets('a tap beside the muscles closes the sheet', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await _frames(tester, 3000);
    await tester.tap(find.text('Vai'));
    await _frames(tester);
    expect(_figure(tester).tones, {'deltoids': Tone.primary});
    // the head is not a muscle
    final figure = tester.getRect(find.byType(BodyFigure));
    await tester.tapAt(Offset(figure.center.dx, figure.top + figure.height * 0.06));
    await _frames(tester);
    expect(_figure(tester).tones, isEmpty);
  });

  testWidgets('the header drags: a flick up opens it, a flick down closes it', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await _frames(tester, 3000);
    await tester.tap(find.text('Ngực'));
    await _frames(tester);
    const head = 'Pectoralis major';
    final halfTop = tester.getTopLeft(find.text(head)).dy;

    // the list scrolls inside the sheet, and the filters sideways, without moving the sheet
    await tester.drag(find.text('Đẩy ngực tạ đòn'), const Offset(0, -120));
    await _frames(tester, 600);
    expect(tester.getTopLeft(find.text(head)).dy, halfTop);
    final chip = tester.getTopLeft(find.text('Tất cả'));
    await tester.drag(find.text('Tất cả'), const Offset(-60, 0));
    await _frames(tester, 600);
    expect(tester.getTopLeft(find.text('Tất cả')).dx, lessThan(chip.dx));
    expect(tester.getTopLeft(find.text(head)).dy, halfTop);

    await tester.fling(find.text(head), const Offset(0, -200), 1500);
    await _frames(tester);
    final fullTop = tester.getTopLeft(find.text(head)).dy;
    expect(fullTop, lessThan(halfTop - 250));

    // a slow drag settles on the nearest stop
    final gesture = await tester.startGesture(tester.getCenter(find.text(head)));
    for (var i = 1; i <= 30; i++) {
      await gesture.moveBy(const Offset(0, 10), timeStamp: Duration(milliseconds: 40 * i));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up(timeStamp: const Duration(milliseconds: 1240));
    await _frames(tester);
    expect(tester.getTopLeft(find.text(head)).dy, moreOrLessEquals(halfTop, epsilon: 1));

    await tester.fling(find.text(head), const Offset(0, 200), 1500);
    await _frames(tester);
    expect(find.text(head).hitTestable(), findsNothing);
    expect(_figure(tester).tones, isEmpty);
  });

  testWidgets('turning the body squeezes the figure and swaps the side', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await _frames(tester, 3000);
    await tester.tap(find.text('Sau'));
    await _frames(tester, 90);
    await expectLater(_shell, matchesGoldenFile('goldens/body_turning.png'));
    expect(_figure(tester).side, 'front');
    await _frames(tester, 140);
    expect(_figure(tester).side, 'back');
    await _frames(tester);
    await expectLater(_shell, matchesGoldenFile('goldens/body_back.png'));

    await tester.ensureVisible(find.text('Mông'));
    await tester.tap(find.text('Mông'));
    await _frames(tester);
    expect(_figure(tester).tones, {'gluteal': Tone.primary});
    await expectLater(_shell, matchesGoldenFile('goldens/body_glutes.png'));

    // the glutes are not on the front: turning closes the sheet
    await tester.tap(find.text('Trước'));
    await _frames(tester);
    expect(_figure(tester).side, 'front');
    expect(_figure(tester).tones, isEmpty);
  });

  testWidgets('a row opens the exercise', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await _frames(tester, 3000);
    await tester.tap(find.text('Ngực'));
    await _frames(tester);
    await tester.tap(find.text('Đẩy ngực tạ đòn'));
    await _frames(tester);
    expect(find.byType(ExerciseScreen), findsOneWidget);
    expect(tester.widget<ExerciseScreen>(find.byType(ExerciseScreen)).id, 'barbell-bench-press');
  });

  testWidgets('coming back to the tab plays its entrance again, as on the web', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(await appFrame(const Shell()));
    await _frames(tester, 3000);
    double brandOpacity() => tester
        .widgetList<Opacity>(
          find.ancestor(of: find.byType(Wordmark), matching: find.byType(Opacity)),
        )
        .fold(1.0, (o, w) => o * w.opacity);
    expect(brandOpacity(), 1);

    final nav = tester.element(_shell).read<TabNav>();
    nav.go(AppTab.week);
    await _frames(tester, 500);
    nav.go(AppTab.body);
    await _frames(tester, 32);
    expect(brandOpacity(), lessThan(0.1));
    await _frames(tester, 1500);
    expect(brandOpacity(), 1);
  });
}
