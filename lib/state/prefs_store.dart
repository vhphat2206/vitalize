import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/haptics.dart';

enum Sex { male, female }

enum Goal { lose, maintain, gain }

/// Leaves a nullable field unchanged in [Profile.copyWith].
const _keep = Object();

class Profile {
  const Profile({
    this.name = '',
    this.sex,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.goal = Goal.maintain,
    this.level = 1,
    this.daysPerWeek = 3,
  });

  factory Profile.fromJson(Map<String, dynamic> j) {
    const d = Profile();
    return Profile(
      name: j['name'] as String? ?? d.name,
      sex: j['sex'] == null ? null : Sex.values.byName(j['sex'] as String),
      birthYear: j['birthYear'] as int?,
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      goal: j['goal'] == null ? d.goal : Goal.values.byName(j['goal'] as String),
      level: j['level'] as int? ?? d.level,
      daysPerWeek: j['daysPerWeek'] as int? ?? d.daysPerWeek,
    );
  }

  final String name;
  final Sex? sex;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final Goal goal;

  /// 1 = new to it, 2 = used to it, 3 = advanced.
  final int level;

  /// Training sessions per week, 1–7.
  final int daysPerWeek;

  Profile copyWith({
    String? name,
    Object? sex = _keep,
    Object? birthYear = _keep,
    Object? heightCm = _keep,
    Object? weightKg = _keep,
    Goal? goal,
    int? level,
    int? daysPerWeek,
  }) => Profile(
    name: name ?? this.name,
    sex: identical(sex, _keep) ? this.sex : sex as Sex?,
    birthYear: identical(birthYear, _keep) ? this.birthYear : birthYear as int?,
    heightCm: identical(heightCm, _keep) ? this.heightCm : heightCm as double?,
    weightKg: identical(weightKg, _keep) ? this.weightKg : weightKg as double?,
    goal: goal ?? this.goal,
    level: level ?? this.level,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'sex': sex?.name,
    'birthYear': birthYear,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goal': goal.name,
    'level': level,
    'daysPerWeek': daysPerWeek,
  };
}

class Reminder {
  const Reminder({
    this.enabled = false,
    this.days = const [0, 2, 4],
    this.hour = 18,
    this.minute = 0,
  });

  factory Reminder.fromJson(Map<String, dynamic> j) {
    const d = Reminder();
    return Reminder(
      enabled: j['enabled'] as bool? ?? d.enabled,
      days: j['days'] == null ? d.days : List<int>.from(j['days'] as List),
      hour: j['hour'] as int? ?? d.hour,
      minute: j['minute'] as int? ?? d.minute,
    );
  }

  final bool enabled;

  /// 0 = Monday … 6 = Sunday.
  final List<int> days;
  final int hour;
  final int minute;

  Reminder copyWith({bool? enabled, List<int>? days, int? hour, int? minute}) => Reminder(
    enabled: enabled ?? this.enabled,
    days: days ?? this.days,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'days': days,
    'hour': hour,
    'minute': minute,
  };
}

class Settings {
  const Settings({this.haptics = true, this.keepAwake = true, this.reminder = const Reminder()});

  factory Settings.fromJson(Map<String, dynamic> j) {
    const d = Settings();
    return Settings(
      haptics: j['haptics'] as bool? ?? d.haptics,
      keepAwake: j['keepAwake'] as bool? ?? d.keepAwake,
      reminder: j['reminder'] == null
          ? d.reminder
          : Reminder.fromJson(j['reminder'] as Map<String, dynamic>),
    );
  }

  /// Haptic ticks from the session timer and when saving.
  final bool haptics;

  /// Keep the screen awake while a session timer runs.
  final bool keepAwake;
  final Reminder reminder;

  Settings copyWith({bool? haptics, bool? keepAwake, Reminder? reminder}) => Settings(
    haptics: haptics ?? this.haptics,
    keepAwake: keepAwake ?? this.keepAwake,
    reminder: reminder ?? this.reminder,
  );

  Map<String, dynamic> toJson() => {
    'haptics': haptics,
    'keepAwake': keepAwake,
    'reminder': reminder.toJson(),
  };
}

/// The profile and settings, kept on the device.
class PrefsStore extends ChangeNotifier {
  PrefsStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        // Read over the defaults so fields added in later versions get a value.
        _profile = Profile.fromJson(j['profile'] as Map<String, dynamic>? ?? const {});
        _settings = Settings.fromJson(j['settings'] as Map<String, dynamic>? ?? const {});
      } catch (_) {
        // Damaged prefs fall back to the defaults.
      }
    }
    Haptics.enabled = _settings.haptics;
  }

  static const _key = 'vitalize.prefs.v1';
  final SharedPreferences _prefs;

  Profile _profile = const Profile();
  Settings _settings = const Settings();

  Profile get profile => _profile;
  Settings get settings => _settings;

  void updateProfile(Profile p) {
    _profile = p;
    _save();
  }

  void updateSettings(Settings s) {
    _settings = s;
    Haptics.enabled = s.haptics;
    _save();
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({'profile': _profile.toJson(), 'settings': _settings.toJson()}),
    );
    notifyListeners();
  }
}
