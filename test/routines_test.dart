import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/app/theme.dart';
import 'package:vitalize/data/catalog.dart';
import 'package:vitalize/demo/exercise_demo_for.dart';
import 'package:vitalize/screens/player_screen.dart';
import 'package:vitalize/screens/routine_screen.dart';
import 'package:vitalize/screens/routines/appear.dart';
import 'package:vitalize/screens/routines/text_wrap.dart';
import 'package:vitalize/screens/routines_screen.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/state/prefs_store.dart';
import 'package:vitalize/widgets/back_bar.dart';

import 'support/harness.dart';

/// Full-screen PNGs for eyeballing against the web app, written only when VITALIZE_SHOTS names
/// a folder.
Future<void> shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['VITALIZE_SHOTS'];
  if (dir == null) return;
  final element = find.byType(MaterialApp).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// A strip of the screen (logical pixels), for goldens that leave out the exercise demo, which
/// is drawn by another part of the app.
Future<ui.Image> strip(WidgetTester tester, double top, double bottom) async {
  final element = find.byType(MaterialApp).evaluate().single;
  late ui.Image out;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final ratio = image.height / tester.view.physicalSize.height * tester.view.devicePixelRatio;
    final src = Rect.fromLTRB(0, top * ratio, image.width.toDouble(), bottom * ratio);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(image, src, Offset.zero & src.size, Paint());
    out = await recorder.endRecording().toImage(src.width.round(), src.height.round());
  });
  return out;
}

/// The phone's haptics, as the platform channel sees them.
List<String> recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
    call,
  ) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

const _light = 'HapticFeedbackType.lightImpact';
const _medium = 'HapticFeedbackType.mediumImpact';

/// The routines tab as the shell shows it: above a tab bar.
Widget routinesTab() => Column(
  children: [
    const Expanded(child: RoutinesScreen()),
    Container(height: V.tabBarH + 34, color: V.tabBar),
  ],
);

/// Scrolls [finder] to the middle of its scroll view, clear of the bar on top.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

String clockText(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => RegExp(r'^\d+:\d\d$').hasMatch(s));
  return texts.single;
}

Future<void> seconds(WidgetTester tester, double s) async {
  // A frame every 100 ms, like a slow phone.
  for (var i = 0; i < (s * 10).round(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(setUpApp);

  final wakelock = <bool>[];
  setUp(() {
    wakelock.clear();
    PlayerScreen.wakelock = (on) async => wakelock.add(on);
  });

  group('Bài tập tab', () {
    testWidgets('lists the routines with time, moves and rounds', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(routinesTab()));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Buổi tập ngắn'), findsOneWidget);
      for (final r in catalog.routines) {
        expect(find.text(r.name), findsOneWidget);
      }
      expect(find.text('5 phút'), findsNWidgets(3));
      expect(find.text('12 phút'), findsNWidgets(2));
      expect(find.text('18 phút'), findsOneWidget);
      expect(find.text('2 vòng'), findsWidgets);
      expect(find.text('3 vòng'), findsOneWidget);
      await shot(tester, 'routines');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/routines.png'));
    });

    testWidgets('rows rise in one after another', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(routinesTab()));
      await tester.pump(const Duration(milliseconds: 230));
      await shot(tester, 'routines-entrance');
      final rows = tester
          .widgetList<FadeTransition>(
            find.descendant(of: find.byType(Appear), matching: find.byType(FadeTransition)),
          )
          .map((f) => f.opacity.value)
          .toList();
      // header text, then six rows with later delays
      expect(rows.length, 7);
      for (var i = 2; i < rows.length; i++) {
        expect(rows[i], lessThanOrEqualTo(rows[i - 1]));
      }
      expect(rows.last, 0);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('replays its entrance when the tab is shown again', (tester) async {
      await usePhone(tester);
      var index = 0;
      late StateSetter set;
      await tester.pumpWidget(
        await appFrame(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return IndexedStack(index: index, children: const [SizedBox(), RoutinesScreen()]);
            },
          ),
        ),
      );
      double title() => tester
          .widget<SlideTransition>(
            find
                .ancestor(
                  of: find.text('Buổi tập ngắn', skipOffstage: false),
                  matching: find.byType(SlideTransition, skipOffstage: false),
                )
                .first,
          )
          .position
          .value
          .dy;
      // Hidden at start: waits in its start state.
      await tester.pump(const Duration(seconds: 2));
      expect(title(), closeTo(1.05, 1e-9));
      set(() => index = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(title(), inExclusiveRange(0, 1.05));
      await tester.pump(const Duration(seconds: 2));
      expect(title(), 0);
      set(() => index = 0);
      await tester.pump();
      set(() => index = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(title(), inExclusiveRange(0, 1.05));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('no entrance when the system asks for less motion', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(
        await appFrame(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: routinesTab(),
            ),
          ),
        ),
      );
      await tester.pump();
      final fades = tester.widgetList<FadeTransition>(
        find.descendant(of: find.byType(Appear), matching: find.byType(FadeTransition)),
      );
      expect(fades.map((f) => f.opacity.value), everyElement(1.0));
    });

    testWidgets('a row opens its routine', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(routinesTab()));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Core 12 phút'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RoutineScreen), findsOneWidget);
      expect(find.text('Mỗi vòng'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Routine', () {
    testWidgets('top of the screen', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(const RoutineScreen(id: 'warm-up')));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining('6 động tác, nghỉ 10 giây giữa các động tác. Không cần dụng cụ.'),
        findsOneWidget,
      );
      expect(find.text('Các động tác'), findsOneWidget);
      await shot(tester, 'routine');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/routine.png'));
    });

    testWidgets('rounds in the facts and the list title', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(const RoutineScreen(id: 'core-12')));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining(
          '6 động tác, lặp lại 2 vòng, nghỉ 20 giây giữa các động tác. Cần một tấm thảm.',
        ),
        findsOneWidget,
      );
      expect(find.text('Mỗi vòng'), findsOneWidget);
    });

    testWidgets('one move open at a time, with its demo and guides', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(const RoutineScreen(id: 'warm-up')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ExerciseDemoFor), findsNothing);

      await tester.tap(find.text('Xoay khớp vai'));
      await tester.pump();
      expect(find.byType(ExerciseDemoFor), findsOneWidget);
      expect(tester.widget<ExerciseDemoFor>(find.byType(ExerciseDemoFor)).id, 'arm-circles');
      expect(find.text('Tài liệu tham khảo'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widgetList<AnimatedRotation>(find.byType(AnimatedRotation)).map((r) => r.turns),
        [0.5, 0, 0, 0, 0, 0],
      );

      await reveal(tester, find.text('Xoay hông'));
      await tester.tap(find.text('Xoay hông'));
      await tester.pump();
      expect(find.byType(ExerciseDemoFor), findsOneWidget);
      expect(tester.widget<ExerciseDemoFor>(find.byType(ExerciseDemoFor)).id, 'hip-circles');

      await reveal(tester, find.text('Xoay hông'));
      await tester.tap(find.text('Xoay hông'));
      await tester.pump();
      expect(find.byType(ExerciseDemoFor), findsNothing);
    });

    testWidgets('the bar fills in once the content scrolls under it', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(const RoutineScreen(id: 'warm-up')));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<BackBar>(find.byType(BackBar)).solid, isFalse);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump(); // the bar learns it is scrolled past...
      await tester.pump(const Duration(seconds: 1)); // ...and fills in
      expect(tester.widget<BackBar>(find.byType(BackBar)).solid, isTrue);
      await shot(tester, 'routine-scrolled');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/routine_scrolled.png'),
      );
    });

    testWidgets('Bắt đầu opens the player', (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(await appFrame(const RoutineScreen(id: 'warm-up')));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Bắt đầu'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.text('Chuẩn bị'), findsOneWidget);
      // Leave the player so its clock stops.
      await tester.tap(find.bySemanticsLabel('Dừng buổi tập'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlayerScreen), findsNothing);
    });
  });

  group('Player', () {
    testWidgets('get ready, work, rest, with the clock and haptics', (tester) async {
      await usePhone(tester);
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(await appFrame(const PlayerScreen(id: 'warm-up')));
      expect(clockText(tester), '0:05');
      await tester.pump(); // the clock starts
      expect(find.text('Chuẩn bị'), findsOneWidget);
      expect(find.text('Xoay khớp vai'), findsOneWidget);
      expect(wakelock, [true]);

      await seconds(tester, 1.5);
      expect(clockText(tester), '0:04');
      expect(haptics, isEmpty);
      await shot(tester, 'player-ready');
      // The demo between them is drawn by lib/demo and checked by its own tests.
      await expectLater(
        await strip(tester, 0, 275),
        matchesGoldenFile('goldens/player_ready_top.png'),
      );
      await expectLater(
        await strip(tester, 648, 874),
        matchesGoldenFile('goldens/player_ready_bottom.png'),
      );

      // 0:03, 0:02, 0:01 tick; then the move starts with a bump.
      await seconds(tester, 3.5);
      expect(haptics, [_light, _light, _light, _medium]);
      expect(find.text('Động tác 1 trên 6'), findsOneWidget);
      expect(clockText(tester), '0:40');

      await seconds(tester, 1.5);
      expect(clockText(tester), '0:39');
      await shot(tester, 'player-work');
      await expectLater(
        await strip(tester, 0, 275),
        matchesGoldenFile('goldens/player_work_top.png'),
      );

      // The rest after the first move shows the next one.
      await tester.pump(const Duration(seconds: 39));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Nghỉ, rồi tới'), findsOneWidget);
      expect(find.text('Xoay hông'), findsOneWidget);
      expect(clockText(tester), '0:10');
      await seconds(tester, 1.5);
      await shot(tester, 'player-rest');
      await expectLater(
        await strip(tester, 0, 250),
        matchesGoldenFile('goldens/player_rest_top.png'),
      );
    });

    testWidgets('pause holds the clock, play carries on', (tester) async {
      await usePhone(tester);
      recordHaptics(tester);
      await tester.pumpWidget(await appFrame(const PlayerScreen(id: 'warm-up')));
      await tester.pump();
      await seconds(tester, 6.5);
      expect(clockText(tester), '0:39');

      await tester.tap(find.bySemanticsLabel('Tạm dừng'));
      await tester.pump();
      expect(find.bySemanticsLabel('Tiếp tục'), findsOneWidget);
      expect(wakelock.last, isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(clockText(tester), '0:39');
      await seconds(tester, 0.5);
      await shot(tester, 'player-paused');
      await expectLater(
        await strip(tester, 648, 874),
        matchesGoldenFile('goldens/player_paused_bottom.png'),
      );

      await tester.tap(find.bySemanticsLabel('Tiếp tục'));
      await tester.pump();
      expect(wakelock.last, isTrue);
      await seconds(tester, 1);
      expect(clockText(tester), '0:38');
    });

    testWidgets('skip and previous move', (tester) async {
      await usePhone(tester);
      final haptics = recordHaptics(tester);
      await tester.pumpWidget(await appFrame(const PlayerScreen(id: 'core-12')));
      await tester.pump();
      await seconds(tester, 1);

      // From get-ready, skip goes straight to the first move.
      await tester.tap(find.bySemanticsLabel('Bỏ qua động tác'));
      await tester.pump();
      expect(find.text('Plank'), findsOneWidget);
      expect(find.textContaining('Vòng'), findsOneWidget);
      expect(clockText(tester), '0:40');
      expect(haptics.last, _medium);

      await tester.tap(find.bySemanticsLabel('Bỏ qua động tác'));
      await tester.pump();
      expect(find.text('Dead bug'), findsOneWidget);

      // Early in a move, previous goes back a move...
      await seconds(tester, 2);
      await tester.tap(find.bySemanticsLabel('Động tác trước'));
      await tester.pump();
      expect(find.text('Plank'), findsOneWidget);
      // ...later in it, it restarts the move.
      await seconds(tester, 5);
      expect(clockText(tester), '0:35');
      await tester.tap(find.bySemanticsLabel('Động tác trước'));
      await tester.pump();
      expect(find.text('Plank'), findsOneWidget);
      expect(clockText(tester), '0:40');

      // From get-ready nothing is earlier: previous restarts the countdown.
      await tester.tap(find.bySemanticsLabel('Động tác trước'));
      await tester.pump();
      expect(find.text('Chuẩn bị'), findsOneWidget);
      expect(clockText(tester), '0:05');
    });

    testWidgets('finishing records the session once', (tester) async {
      await usePhone(tester);
      recordHaptics(tester);
      late LogStore store;
      final start = DateTime(2026, 10, 20, 18);
      var wall = start;
      PlayerScreen.wallClock = () => wall;
      addTearDown(() => PlayerScreen.wallClock = DateTime.now);
      await tester.pumpWidget(
        await appFrame(const PlayerScreen(id: 'warm-up'), seed: (log, _) => store = log),
      );
      await tester.pump();
      // get-ready, then six moves, skipped one by one
      for (var i = 0; i < 7; i++) {
        await seconds(tester, 0.5);
        wall = wall.add(const Duration(seconds: 42));
        await tester.tap(find.bySemanticsLabel('Bỏ qua động tác'));
        await tester.pump();
      }
      expect(find.text('Xong.'), findsOneWidget);
      expect(
        find.text(
          'Bạn vừa tập hết khởi động trước buổi tập trong 5 phút. Buổi này đã được ghi vào '
          'tuần của bạn.',
        ),
        findsOneWidget,
      );
      expect(store.sessions, hasLength(1));
      expect(store.sessions.single.routineId, 'warm-up');
      expect(store.sessions.single.seconds, 294);
      expect(wakelock.last, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(store.sessions, hasLength(1));
      await shot(tester, 'player-done');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_done.png'));
    });

    testWidgets('the whole routine runs through on its own', (tester) async {
      await usePhone(tester);
      final haptics = recordHaptics(tester);
      late LogStore store;
      await tester.pumpWidget(
        await appFrame(const PlayerScreen(id: 'desk-reset'), seed: (log, _) => store = log),
      );
      await tester.pump();
      final r = catalog.routineById['desk-reset']!;
      // ready + every move and rest, a frame each 250 ms
      final total = 5 + r.seconds;
      for (var i = 0; i < total * 4 + 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('Xong.'), findsOneWidget);
      expect(store.sessions, hasLength(1));
      // a bump for each new step: 6 moves and 5 rests
      expect(haptics.where((h) => h == _medium), hasLength(11));
    });

    testWidgets('keeps the screen on only when asked', (tester) async {
      await usePhone(tester);
      recordHaptics(tester);
      await tester.pumpWidget(
        await appFrame(
          const PlayerScreen(id: 'warm-up'),
          seed: (_, prefs) => prefs.updateSettings(prefs.settings.copyWith(keepAwake: false)),
        ),
      );
      await tester.pump();
      await seconds(tester, 1);
      expect(wakelock, isEmpty);
    });

    testWidgets('closing lets the screen sleep and records nothing', (tester) async {
      await usePhone(tester);
      recordHaptics(tester);
      late LogStore store;
      await tester.pumpWidget(
        await appFrame(
          Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => const PlayerScreen(id: 'warm-up'))),
                child: const Text('open'),
              ),
            ),
          ),
          seed: (log, _) => store = log,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await seconds(tester, 1);
      expect(wakelock, [true]);
      await tester.tap(find.bySemanticsLabel('Dừng buổi tập'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlayerScreen), findsNothing);
      expect(wakelock, [true, false]);
      expect(store.sessions, isEmpty);
    });
  });

  test('prefs default to keeping the screen on', () {
    expect(const Settings().keepAwake, isTrue);
  });

  // Breaks measured in the web app (Chrome), which Flutter reproduces with the same fonts.
  group('line breaks like the web app', () {
    List<String> lines(String text, TextStyle style, double width, WrapStyle wrap) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      );
      final out = linesAt(painter, wrapWidth(painter, width, wrap));
      painter.dispose();
      return out;
    }

    test('balance evens out titles', () {
      final title = VT.display(31, height: 1.18, em: -0.02);
      final name = VT.display(34, height: 1.15, em: -0.02);
      expect(lines('Khởi động trước buổi tập', title, 362, WrapStyle.balance), [
        'Khởi động',
        'trước buổi tập',
      ]);
      expect(lines('Lưng và cổ cho dân văn phòng', title, 362, WrapStyle.balance), [
        'Lưng và cổ cho',
        'dân văn phòng',
      ]);
      expect(lines('Giãn bắp chân vào tường', name, 362, WrapStyle.balance), [
        'Giãn bắp chân',
        'vào tường',
      ]);
      expect(lines('Plank nghiêng', name, 362, WrapStyle.balance), ['Plank nghiêng']);
    });

    test('pretty never leaves a word alone on the last line', () {
      final cue = VT.ui(16).copyWith(letterSpacing: bodyTracking);
      final small = VT.ui(14, height: 1.45, em: 0);
      expect(
        lines('Xoay tròn hai tay, vòng to dần. Đổi chiều ở giữa.', cue, 362, WrapStyle.pretty),
        ['Xoay tròn hai tay, vòng to dần. Đổi chiều', 'ở giữa.'],
      );
      expect(
        lines('Bụng và lưng dưới chắc hơn cho các bài tạ nặng.', small, 294, WrapStyle.pretty),
        ['Bụng và lưng dưới chắc hơn cho các bài', 'tạ nặng.'],
      );
      expect(lines('Nâng hông, siết mông hai giây ở đỉnh.', small, 243.25, WrapStyle.pretty), [
        'Nâng hông, siết mông hai giây',
        'ở đỉnh.',
      ]);
      // Already fine: left as it is.
      expect(
        lines(
          'Ngồi xuống, bật chân ra sau, bật về, nhảy lên. Mới tập thì bước thay vì bật.',
          small,
          243.25,
          WrapStyle.pretty,
        ),
        ['Ngồi xuống, bật chân ra sau, bật', 'về, nhảy lên. Mới tập thì bước thay', 'vì bật.'],
      );
    });
  });
}
