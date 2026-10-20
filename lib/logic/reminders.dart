import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/prefs_store.dart';

/// What [Reminders.sync] ended up doing.
enum ReminderStatus {
  /// One weekly notification per chosen day is scheduled.
  scheduled,

  /// Reminders are off, or no day is chosen: nothing is scheduled.
  off,

  /// Notifications are not allowed yet. Asking again can still show the system dialog
  /// (on Android after a first "Don't allow").
  denied,

  /// Notifications are blocked for Vitalize: the system will not ask again, only the phone's
  /// Settings can allow them.
  permanentlyDenied,

  /// Not running on a phone (tests, desktop): there is nothing to schedule.
  unsupported,
}

/// Weekly training reminders: a local notification on each chosen weekday at the chosen time,
/// in the phone's own time zone. The phone keeps them across launches and restarts.
class Reminders {
  Reminders();

  /// The app's reminders. Tests swap in a fake.
  static Reminders instance = Reminders();

  /// One notification id per weekday (4100 = Monday … 4106 = Sunday), so changing the days
  /// replaces them cleanly.
  static const _baseId = 4100;

  static const _title = 'Đến giờ tập rồi';
  static const _body = 'Mở Vitalize, chọn nhóm cơ hôm nay và bắt đầu.';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'training-reminders',
      'Nhắc lịch tập',
      channelDescription: 'Nhắc đi tập vào những ngày và giờ đã chọn.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  bool _zonesLoaded = false;

  /// The sync still running, if any. Syncs run one after another, so two quick changes
  /// cannot interleave their cancel and schedule calls (or open two permission dialogs).
  Future<void>? _running;

  /// Local notifications only exist in the phone app.
  bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Replaces every scheduled training reminder with the ones [reminder] describes. Asks for
  /// permission to notify first when it is needed and [ask] is true; at start-up the app
  /// syncs with [ask] false, so no dialog pops up before the user has done anything.
  Future<ReminderStatus> sync(Reminder reminder, {bool ask = true}) {
    final previous = _running;
    final result = previous == null
        ? _sync(reminder, ask: ask)
        : previous.then((_) => _sync(reminder, ask: ask));
    _running = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<ReminderStatus> _sync(Reminder r, {required bool ask}) async {
    if (!supported) return ReminderStatus.unsupported;
    await (_ready ??= _init());

    // Start from a clean slate: drop the reminders scheduled before.
    for (var day = 0; day < 7; day++) {
      await _plugin.cancel(id: _baseId + day);
    }
    if (!r.enabled || r.days.isEmpty) return ReminderStatus.off;

    switch (await notificationPermission(ask: ask)) {
      case PermissionStatus.granted || PermissionStatus.provisional || PermissionStatus.limited:
        break; // allowed: schedule below
      case PermissionStatus.denied:
        return ReminderStatus.denied;
      case PermissionStatus.permanentlyDenied || PermissionStatus.restricted:
        return ReminderStatus.permanentlyDenied;
    }

    // The time zone database is only needed to schedule: load it the first time. Read the
    // phone's zone on every sync, as it may have travelled since the last one.
    if (!_zonesLoaded) {
      tzdata.initializeTimeZones();
      _zonesLoaded = true;
    }
    tz.setLocalLocation(await _localLocation());
    for (final day in r.days) {
      await _plugin.zonedSchedule(
        id: _baseId + day,
        title: _title,
        body: _body,
        scheduledDate: nextReminderTime(day, r.hour, r.minute, tz.TZDateTime.now(tz.local)),
        notificationDetails: _details,
        // A reminder does not need to-the-second timing, so no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repeat every week on that weekday at that time.
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
    return ReminderStatus.scheduled;
  }

  /// Whether Vitalize may show notifications, with permission_handler. When [ask] is true and
  /// the system still allows it, this shows the system dialog and returns the user's answer.
  Future<PermissionStatus> notificationPermission({bool ask = true}) async {
    if (!supported) return PermissionStatus.denied;

    // 1. Check first: no dialog when the answer is already known.
    final status = await Permission.notification.status;
    if (status.isGranted || status.isProvisional) return status;

    // 2. Blocked in Settings (or by Screen Time on iOS): the system shows no dialog any more,
    //    only the phone's Settings can change it.
    if (status.isPermanentlyDenied || status.isRestricted || !ask) return status;

    // 3. Not decided yet (or "Don't allow" once on Android): show the system dialog.
    //    Answers: granted, denied (Android: may ask once more) or permanentlyDenied.
    return Permission.notification.request();
  }

  /// At start-up: schedules the reminders again in the phone's current time zone, which may
  /// have changed since they were set. Never asks for permission; nothing to do when off.
  Future<void> refreshAtLaunch(Reminder reminder) async {
    if (!reminder.enabled || !supported) return;
    try {
      await sync(reminder, ask: false);
    } catch (e) {
      debugPrint('Training reminders were not refreshed: $e');
    }
  }

  /// Whether notifications are allowed right now; never shows a dialog.
  Future<bool> notificationsAllowed() async {
    final status = await notificationPermission(ask: false);
    return status.isGranted || status.isProvisional;
  }

  /// Opens Vitalize's page in the phone's Settings, where notifications can be allowed.
  Future<bool> openSettings() => openAppSettings();

  Future<void> _init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked through permission_handler when reminders are turned on, not
        // when the plugin starts.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// The phone's time zone. An unknown name (an old alias, a bare "GMT+7") falls back to a zone
  /// with the same offset right now.
  Future<tz.Location> _localLocation() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(zone.identifier);
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offset) return location;
      }
      return tz.UTC;
    }
  }
}

/// The next reminder for [day] (0 = Monday … 6 = Sunday) at [hour]:[minute] after [now], in
/// [now]'s time zone. Built from the calendar date, not by adding 24-hour days, so a daylight
/// saving change in between keeps the wall-clock time.
tz.TZDateTime nextReminderTime(int day, int hour, int minute, tz.TZDateTime now) {
  // DateTime.weekday counts 1 = Monday … 7 = Sunday.
  final ahead = (day + 1 - now.weekday) % 7;
  final at = tz.TZDateTime(now.location, now.year, now.month, now.day + ahead, hour, minute);
  return at.isAfter(now)
      ? at
      : tz.TZDateTime(now.location, now.year, now.month, now.day + ahead + 7, hour, minute);
}
