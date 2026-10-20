import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/app/theme.dart';
import 'package:vitalize/demo/demo_data.dart';
import 'package:vitalize/demo/exercise_demo.dart';
import 'package:vitalize/demo/exercise_demo_for.dart';
import 'package:vitalize/demo/motion.dart';
import 'package:vitalize/widgets/back_bar.dart';

import 'support/harness.dart';

const _id = 'back-squat';

/// The colour a caption is heading to (lit: ink, unlit: faint).
Color? _caption(WidgetTester tester, String text) => tester
    .widget<AnimatedDefaultTextStyle>(
      find.ancestor(of: find.text(text), matching: find.byType(AnimatedDefaultTextStyle)).first,
    )
    .style
    .color;

Widget _demo({double? still, bool fill = false}) => ExerciseDemo(
  demo: demoFor(_id)!,
  primary: const ['quadriceps', 'gluteal'],
  secondary: const ['hamstring'],
  still: still,
  fill: fill,
);

/// Pumps past the caption fade so only the demo's own loop can ask for more frames.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(setUpApp);

  group('timing', () {
    test('holds at each end and eases between them', () {
      final d = demoFor(_id)!;
      expect(d.hold, 0.55);
      expect(d.move, 1.35);
      expect(periodOf(d), closeTo(3.8, 1e-9));
      expect(phaseAt(d, 0.3), 0);
      expect(phaseAt(d, 0.55 + 1.35 / 2), closeTo(0.5, 1e-9));
      expect(phaseAt(d, 0.55 + 1.35 * 0.25), closeTo(easeInOutCubic(0.25), 1e-9));
      expect(phaseAt(d, 0.55 + 1.35 + 0.3), 1);
      expect(phaseAt(d, 2 * 0.55 + 1.35 + 1.35 / 2), closeTo(0.5, 1e-9));
      expect(phaseAt(d, 3.79), closeTo(0, 1e-4));
    });

    test('a cycle runs round from 0 to 1', () {
      final d = demoFor('burpee')!;
      expect(d.cycle, isTrue);
      expect(periodOf(d), d.move);
      expect(phaseAt(d, d.move / 4), closeTo(0.25, 1e-9));
    });

    test('the ease is the smooth in-out cubic', () {
      expect(easeInOutCubic(0), 0);
      expect(easeInOutCubic(0.25), closeTo(0.0625, 1e-12));
      expect(easeInOutCubic(0.5), 0.5);
      expect(easeInOutCubic(0.75), closeTo(0.9375, 1e-12));
      expect(easeInOutCubic(1), 1);
    });
  });

  testWidgets('loops between the two captions', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(Padding(padding: const EdgeInsets.all(20), child: _demo())),
    );
    final phases = demoFor(_id)!.phases;
    expect(_caption(tester, phases[0]), V.ink);
    expect(_caption(tester, phases[1]), V.faint);
    // past the hold and most of the way down
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_caption(tester, phases[0]), V.faint);
    expect(_caption(tester, phases[1]), V.ink);
    // and back up again
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_caption(tester, phases[0]), V.ink);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('tap pauses and resumes', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(Padding(padding: const EdgeInsets.all(20), child: _demo())),
    );
    final phases = demoFor(_id)!.phases;
    expect(find.bySemanticsLabel('Dừng chuyển động'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Dừng chuyển động'));
    await _settle(tester);
    expect(find.bySemanticsLabel('Tiếp tục chuyển động'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(_caption(tester, phases[0]), V.ink);
    await tester.tap(find.bySemanticsLabel('Tiếp tục chuyển động'));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_caption(tester, phases[1]), V.ink);
  });

  testWidgets('a still frame does not animate', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(Padding(padding: const EdgeInsets.all(20), child: _demo(still: 1))),
    );
    await _settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_caption(tester, demoFor(_id)!.phases[1]), V.ink);
  });

  testWidgets('reduced motion shows the end of the move, still', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Padding(padding: const EdgeInsets.all(20), child: _demo()),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_caption(tester, demoFor(_id)!.phases[1]), V.ink);
  });

  testWidgets('stops off screen and starts again when scrolled into view', (tester) async {
    await usePhone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      await appFrame(
        SingleChildScrollView(
          controller: controller,
          child: Column(children: [const SizedBox(height: 1500), _demo()]),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    controller.jumpTo(1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
    controller.jumpTo(0);
    await tester.pump();
    await _settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('stops in a hidden tab', (tester) async {
    await usePhone(tester);
    Widget tabs(int index) =>
        IndexedStack(index: index, children: [const SizedBox.expand(), _demo()]);
    await tester.pumpWidget(await appFrame(tabs(0)));
    await _settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(await appFrame(tabs(1)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('runs once its screen has slid in, and stops when covered', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        Builder(
          builder: (context) => GestureDetector(
            onTap: () =>
                Navigator.of(context)
                    .push(vRoute(Padding(padding: const EdgeInsets.all(20), child: _demo()))),
            child: const SizedBox.expand(child: Text('mở')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    // the slide-in, then the loop keeps going on its own
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.binding.hasScheduledFrame, isTrue);
    final phases = demoFor(_id)!.phases;
    final before = _caption(tester, phases[1]);
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_caption(tester, phases[1]), isNot(before));
    // covered by another screen
    Navigator.of(tester.element(find.byType(ExerciseDemo))).push(vRoute(const SizedBox.expand()));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await _settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('fill takes the parent height and leaves out the captions', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(Center(child: SizedBox(height: 420, width: 360, child: _demo(fill: true)))),
    );
    expect(tester.getSize(find.byType(ExerciseDemo)), const Size(360, 420));
    expect(find.text(demoFor(_id)!.phases[0]), findsNothing);
  });

  testWidgets('ExerciseDemoFor shows the demo for an id, and nothing without one', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      await appFrame(
        const Column(
          children: [
            ExerciseDemoFor(id: 'no-such-move', primary: [], secondary: []),
            ExerciseDemoFor(id: 'plank', primary: ['abs'], secondary: ['obliques']),
          ],
        ),
      ),
    );
    expect(find.byType(ExerciseDemo), findsOneWidget);
    expect(tester.getSize(find.byType(ExerciseDemoFor).first), Size.zero);
  });
}
