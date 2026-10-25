import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/logic/reminders.dart';
import 'package:vitalize/screens/settings_screen.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/state/prefs_store.dart';
import 'package:vitalize/widgets/back_bar.dart';

import 'support/harness.dart';

/// Reminders without a phone: answers what the test says and records what was asked.
class FakeReminders extends Reminders {
  FakeReminders(this.answer);

  ReminderStatus Function(Reminder r) answer;
  final synced = <Reminder>[];
  bool allowed = false;
  int settingsOpened = 0;

  @override
  Future<ReminderStatus> sync(Reminder reminder, {bool ask = true}) async {
    synced.add(reminder);
    return reminder.enabled ? answer(reminder) : ReminderStatus.off;
  }

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// The web app's screenshot size (402×874 at 2x, no safe areas), to compare side by side.
Future<void> useWebPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(804, 1748);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Two sets and one short session in the training log, no meals.
void _someTraining(LogStore log, PrefsStore prefs) {
  log.addSet(exerciseId: 'bench-press', kg: 40, reps: 8);
  log.addSet(exerciseId: 'bench-press', kg: 40, reps: 8);
  log.addSession(routineId: 'warmup', seconds: 300);
}

Future<void> _show(
  WidgetTester tester, {
  void Function(LogStore log, PrefsStore prefs)? seed,
  bool web = true,
}) async {
  if (web) {
    await useWebPhone(tester);
  } else {
    await usePhone(tester);
  }
  await tester.pumpWidget(await appFrame(const SettingsScreen(), seed: seed));
  await tester.pump(const Duration(seconds: 2));
}

/// Lets a sheet or route animation run: the first frame starts its clock.
Future<void> _wait(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.pump();
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

PrefsStore _prefs(WidgetTester tester) =>
    tester.element(find.byType(SettingsScreen)).read<PrefsStore>();

void main() {
  setUpAll(setUpApp);
  tearDown(() => Reminders.instance = Reminders());

  testWidgets('settings, as first opened', (tester) async {
    await _show(tester, seed: _someTraining);
    expect(find.text('Rung khi đếm giờ'), findsOneWidget);
    expect(find.text('2 hiệp và 1 buổi tập ngắn'), findsOneWidget);
    expect(find.text('Chưa có gì để xoá'), findsOneWidget);
    // Not on a phone here: reminders say where they work.
    expect(find.text('Nhắc lịch chỉ chạy trong app trên điện thoại.'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_default.png'));
  });

  testWidgets('settings on a phone with safe areas', (tester) async {
    await _show(tester, seed: _someTraining, web: false);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_phone.png'));
  });

  testWidgets('large text still fits', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    Reminders.instance = FakeReminders((_) => ReminderStatus.permanentlyDenied);
    await _show(tester, seed: _someTraining, web: false);
    await tester.tap(find.text('Nhắc tôi đi tập'));
    await _wait(tester);
    await _scrollToEnd(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggles save the settings', (tester) async {
    await _show(tester);
    await tester.tap(find.text('Rung khi đếm giờ'));
    await tester.tap(find.text('Giữ màn hình sáng'));
    await tester.pump();
    final s = _prefs(tester).settings;
    expect((s.haptics, s.keepAwake), (false, false));
  });

  testWidgets('reminder on: days, time and the schedule note', (tester) async {
    final fake = Reminders.instance = FakeReminders((_) => ReminderStatus.scheduled);
    await _show(tester, seed: _someTraining);
    await tester.tap(find.text('Nhắc tôi đi tập'));
    await _wait(tester);
    expect(fake.synced.last.enabled, isTrue);
    expect(find.text('Sẽ nhắc lúc 18:00 vào T2, T4, T6.'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);

    await tester.tap(find.text('CN'));
    await tester.tap(find.text('T4'));
    await _wait(tester);
    expect(_prefs(tester).settings.reminder.days, [0, 4, 6]);
    expect(fake.synced.last.days, [0, 4, 6]);
    expect(find.text('Sẽ nhắc lúc 18:00 vào T2, T6, CN.'), findsOneWidget);

    await tester.tap(find.text('Giờ nhắc'));
    await _wait(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_time.png'));
    await tester.tap(find.bySemanticsLabel('Tăng giờ'));
    await tester.tap(find.bySemanticsLabel('Tăng phút'));
    await tester.pump();
    await tester.tap(find.text('Lưu giờ nhắc'));
    await _wait(tester);
    final r = _prefs(tester).settings.reminder;
    expect((r.hour, r.minute), (19, 5));
    expect(find.text('Sẽ nhắc lúc 19:05 vào T2, T6, CN.'), findsOneWidget);
  });

  testWidgets('reminder on, as the web shows it', (tester) async {
    await _show(tester, seed: _someTraining);
    await tester.tap(find.text('Nhắc tôi đi tập'));
    await _wait(tester);
    expect(_prefs(tester).settings.reminder.enabled, isTrue);
    expect(find.text('Nhắc lịch chỉ chạy trong app trên điện thoại.'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_reminder.png'));
  });

  testWidgets('notifications blocked: reminder goes back off, Settings can allow them', (
    tester,
  ) async {
    final fake = Reminders.instance = FakeReminders((_) => ReminderStatus.permanentlyDenied);
    await _show(tester);
    await tester.tap(find.text('Nhắc tôi đi tập'));
    await _wait(tester);
    expect(_prefs(tester).settings.reminder.enabled, isFalse);
    expect(find.textContaining('Thông báo của Vitalize đang tắt'), findsOneWidget);
    expect(find.text('Giờ nhắc'), findsNothing);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_blocked.png'));

    await tester.tap(find.text('Mở Cài đặt'));
    expect(fake.settingsOpened, 1);

    // Back from Settings with notifications allowed: the reminder turns itself on.
    fake
      ..allowed = true
      ..answer = (_) => ReminderStatus.scheduled;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _wait(tester);
    expect(_prefs(tester).settings.reminder.enabled, isTrue);
    expect(find.textContaining('Thông báo của Vitalize đang tắt'), findsNothing);
    expect(find.text('Sẽ nhắc lúc 18:00 vào T2, T4, T6.'), findsOneWidget);
  });

  testWidgets('notifications turned off in Settings while reminders are on', (tester) async {
    final fake = Reminders.instance = FakeReminders((_) => ReminderStatus.scheduled);
    await _show(tester);
    await tester.tap(find.text('Nhắc tôi đi tập'));
    await _wait(tester);
    expect(find.text('Sẽ nhắc lúc 18:00 vào T2, T4, T6.'), findsOneWidget);

    fake.answer = (_) => ReminderStatus.permanentlyDenied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _wait(tester);
    expect(_prefs(tester).settings.reminder.enabled, isFalse);
    expect(find.textContaining('Thông báo của Vitalize đang tắt'), findsOneWidget);
  });

  testWidgets('notifications refused once: can ask again or open Settings', (tester) async {
    Reminders.instance = FakeReminders((_) => ReminderStatus.denied);
    await _show(tester);
    await tester.tap(find.text('Nhắc tôi đi tập'));
    await _wait(tester);
    expect(_prefs(tester).settings.reminder.enabled, isFalse);
    expect(find.textContaining('Bạn chưa cho phép Vitalize gửi thông báo'), findsOneWidget);
    expect(find.text('Mở Cài đặt'), findsOneWidget);

    // Back from elsewhere still without permission: nothing changes.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _wait(tester);
    expect(_prefs(tester).settings.reminder.enabled, isFalse);

    // Turning it on again hides the message while asking.
    (Reminders.instance as FakeReminders).answer = (_) => ReminderStatus.scheduled;
    await tester.tap(find.text('Nhắc tôi đi tập'));
    await _wait(tester);
    expect(find.textContaining('Bạn chưa cho phép'), findsNothing);
    expect(_prefs(tester).settings.reminder.enabled, isTrue);
  });

  testWidgets('info rows open and close, version at the end', (tester) async {
    // As in the web screenshots: reminder on, scrolled to the end.
    await _show(
      tester,
      seed: (log, prefs) {
        _someTraining(log, prefs);
        final s = prefs.settings;
        prefs.updateSettings(s.copyWith(reminder: s.reminder.copyWith(enabled: true)));
      },
    );
    await _scrollToEnd(tester);
    // Scrolled under it, the back bar turns solid and shows the title.
    final title = find.descendant(of: find.byType(BackBar), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(title).opacity, 1);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_bottom.png'));
    await tester.tap(find.text('Lưu ý sức khỏe'));
    await _scrollToEnd(tester);
    expect(find.textContaining('không thay cho lời khuyên của bác sĩ'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_health.png'));
    await tester.tap(find.text('Nguồn và giấy phép'));
    await _scrollToEnd(tester);
    expect(find.textContaining('không thay cho lời khuyên của bác sĩ'), findsNothing);
    expect(find.textContaining('react-native-body-highlighter'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_licences.png'));
  });

  testWidgets('clearing the training log asks first', (tester) async {
    await _show(tester, seed: _someTraining);
    await _scrollToEnd(tester);
    await tester.tap(find.text('Lưu ý sức khỏe'));
    await tester.tap(find.text('Nguồn và giấy phép'));
    await _scrollToEnd(tester);
    // Nothing to clear: the meal row does nothing.
    await tester.tap(find.text('Xoá nhật ký ăn uống'));
    await _wait(tester);
    expect(find.text('Xoá nhật ký ăn uống?'), findsNothing);

    await tester.tap(find.text('Xoá nhật ký tập'));
    await _wait(tester);
    expect(find.text('Xoá nhật ký tập?'), findsOneWidget);
    expect(
      find.text('Xoá hết 3 mục đã ghi (hiệp tập và buổi tập ngắn). Không khôi phục lại được.'),
      findsOneWidget,
    );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_confirm.png'));

    await tester.tap(find.text('Thôi, giữ lại'));
    await _wait(tester);
    final log = tester.element(find.byType(SettingsScreen)).read<LogStore>();
    expect(log.sets, hasLength(2));

    await tester.tap(find.text('Xoá nhật ký tập'));
    await _wait(tester);
    await tester.tap(find.text('Xoá hết'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(log.sets, isEmpty);
    expect(log.sessions, isEmpty);
    expect(find.text('Đã xoá nhật ký tập'), findsOneWidget);
    expect(find.text('Chưa có gì để xoá'), findsNWidgets(2));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_cleared.png'));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('clearing meals', (tester) async {
    await _show(
      tester,
      seed: (log, prefs) => log.addMeal(slot: MealSlot.lunch, items: const [], source: 'demo'),
    );
    expect(find.text('1 bữa ăn'), findsOneWidget);
    await tester.tap(find.text('Xoá nhật ký ăn uống'));
    await _wait(tester);
    expect(find.text('Xoá hết 1 bữa ăn đã lưu. Không khôi phục lại được.'), findsOneWidget);
    await tester.tap(find.text('Xoá hết'));
    await _wait(tester);
    expect(tester.element(find.byType(SettingsScreen)).read<LogStore>().meals, isEmpty);
    expect(find.text('Đã xoá nhật ký ăn uống'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
