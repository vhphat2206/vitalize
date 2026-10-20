import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:vitalize/logic/reminders.dart';
import 'package:vitalize/state/prefs_store.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('nextReminderTime', () {
    late tz.Location hcm;
    setUp(() => hcm = tz.getLocation('Asia/Ho_Chi_Minh'));
    tz.TZDateTime at(int month, int day, int hour, int minute, [tz.Location? place]) =>
        tz.TZDateTime(place ?? hcm, 2026, month, day, hour, minute);

    test('19 Oct 2026 is a Monday', () {
      expect(at(10, 19, 9, 0).weekday, DateTime.monday);
    });

    test('a later day this week', () {
      // Monday 10:00 → Wednesday (day 2) at 18:00.
      expect(nextReminderTime(2, 18, 0, at(10, 19, 10, 0)), at(10, 21, 18, 0));
    });

    test('today, while the time is still ahead', () {
      expect(nextReminderTime(0, 18, 0, at(10, 19, 10, 0)), at(10, 19, 18, 0));
    });

    test('today, once the time has passed: next week', () {
      expect(nextReminderTime(0, 18, 0, at(10, 19, 19, 0)), at(10, 26, 18, 0));
      expect(nextReminderTime(0, 18, 0, at(10, 19, 18, 0)), at(10, 26, 18, 0));
    });

    test('Sunday is day 6', () {
      expect(nextReminderTime(6, 7, 30, at(10, 19, 10, 0)), at(10, 25, 7, 30));
    });

    test('across a daylight saving change the wall-clock time stays', () {
      final berlin = tz.getLocation('Europe/Berlin');
      // Friday 27 March 2026 in winter time; clocks go forward on Sunday the 29th.
      final next = nextReminderTime(0, 18, 0, at(3, 27, 20, 0, berlin));
      expect((next.day, next.hour, next.minute), (30, 18, 0));
      expect(next.timeZoneOffset, const Duration(hours: 2));
    });
  });

  test('off the phone there is nothing to schedule', () async {
    final reminders = Reminders();
    expect(await reminders.sync(const Reminder(enabled: true)), ReminderStatus.unsupported);
    expect(await reminders.notificationsAllowed(), isFalse);
    await reminders.refreshAtLaunch(const Reminder(enabled: true));
  });
}
