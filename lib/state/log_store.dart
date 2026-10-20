import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

class LoggedSet {
  const LoggedSet({
    required this.id,
    required this.exerciseId,
    required this.at,
    this.kg,
    this.reps,
    this.seconds,
  });

  LoggedSet.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      exerciseId = j['exerciseId'] as String,
      at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      kg = (j['kg'] as num?)?.toDouble(),
      reps = j['reps'] as int?,
      seconds = j['seconds'] as int?;

  final String id;
  final String exerciseId;
  final DateTime at;
  final double? kg;
  final int? reps;
  final int? seconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'at': at.millisecondsSinceEpoch,
    'kg': ?kg,
    'reps': ?reps,
    'seconds': ?seconds,
  };
}

class LoggedSession {
  const LoggedSession({
    required this.id,
    required this.routineId,
    required this.at,
    required this.seconds,
  });

  LoggedSession.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      routineId = j['routineId'] as String,
      at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      seconds = j['seconds'] as int;

  final String id;
  final String routineId;
  final DateTime at;

  /// Time actually spent, in seconds.
  final int seconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'routineId': routineId,
    'at': at.millisecondsSinceEpoch,
    'seconds': seconds,
  };
}

enum MealSlot { breakfast, lunch, dinner, snack }

const mealSlotLabel = {
  MealSlot.breakfast: 'Bữa sáng',
  MealSlot.lunch: 'Bữa trưa',
  MealSlot.dinner: 'Bữa tối',
  MealSlot.snack: 'Ăn vặt',
};

/// A food in a logged meal: the analysed portion times [servings] (0.5, 1, 1.5 …).
class MealItem {
  const MealItem({required this.food, this.servings = 1});

  MealItem.fromJson(Map<String, dynamic> j)
    : food = FoodItem.fromJson(j),
      servings = (j['servings'] as num).toDouble();

  final FoodItem food;
  final double servings;

  MealItem withServings(double s) => MealItem(food: food, servings: s);

  Map<String, dynamic> toJson() => {...food.toJson(), 'servings': servings};
}

class LoggedMeal {
  const LoggedMeal({
    required this.id,
    required this.at,
    required this.slot,
    required this.items,
    required this.source,
    this.photo,
  });

  LoggedMeal.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      slot = MealSlot.values.byName(j['slot'] as String),
      items = [for (final i in j['items'] as List) MealItem.fromJson(i as Map<String, dynamic>)],
      photo = j['photo'] as String?,
      source = j['source'] as String;

  final String id;
  final DateTime at;
  final MealSlot slot;
  final List<MealItem> items;

  /// Small JPEG, base64; dropped after 30 days to keep storage small.
  final String? photo;

  /// `ai` when analysed by the model, `demo` for a sample result.
  final String source;

  LoggedMeal copyWith({
    DateTime? at,
    MealSlot? slot,
    List<MealItem>? items,
    String? photo,
    bool dropPhoto = false,
  }) => LoggedMeal(
    id: id,
    at: at ?? this.at,
    slot: slot ?? this.slot,
    items: items ?? this.items,
    photo: dropPhoto ? null : (photo ?? this.photo),
    source: source,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'slot': slot.name,
    'items': [for (final i in items) i.toJson()],
    'photo': ?photo,
    'source': source,
  };
}

/// Logged sets, finished sessions and meals, kept on the device.
class LogStore extends ChangeNotifier {
  LogStore(this._prefs) {
    _load();
  }

  static const _key = 'vitalize.log.v1';
  static const _photoDays = 30;

  final SharedPreferences _prefs;
  final _random = Random();

  List<LoggedSet> _sets = [];
  List<LoggedSession> _sessions = [];
  List<LoggedMeal> _meals = [];

  List<LoggedSet> get sets => List.unmodifiable(_sets);
  List<LoggedSession> get sessions => List.unmodifiable(_sessions);
  List<LoggedMeal> get meals => List.unmodifiable(_meals);

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final cutoff = DateTime.now().subtract(const Duration(days: _photoDays));
      _sets = [
        for (final s in j['sets'] as List? ?? []) LoggedSet.fromJson(s as Map<String, dynamic>),
      ];
      _sessions = [
        for (final s in j['sessions'] as List? ?? [])
          LoggedSession.fromJson(s as Map<String, dynamic>),
      ];
      _meals = [
        for (final m in j['meals'] as List? ?? [])
          () {
            final meal = LoggedMeal.fromJson(m as Map<String, dynamic>);
            return meal.at.isBefore(cutoff) ? meal.copyWith(dropPhoto: true) : meal;
          }(),
      ];
    } catch (_) {
      // A damaged log starts empty rather than crashing the app.
    }
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'sets': [for (final s in _sets) s.toJson()],
        'sessions': [for (final s in _sessions) s.toJson()],
        'meals': [for (final m in _meals) m.toJson()],
      }),
    );
    notifyListeners();
  }

  String _newId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(1 << 30).toRadixString(36)}';

  LoggedSet addSet({required String exerciseId, double? kg, int? reps, int? seconds}) {
    final set = LoggedSet(
      id: _newId(),
      exerciseId: exerciseId,
      at: DateTime.now(),
      kg: kg,
      reps: reps,
      seconds: seconds,
    );
    _sets = [..._sets, set];
    _save();
    return set;
  }

  LoggedSet? removeSet(String id) {
    final found = _sets.where((s) => s.id == id).firstOrNull;
    _sets = _sets.where((s) => s.id != id).toList();
    _save();
    return found;
  }

  void restoreSet(LoggedSet set) {
    _sets = [..._sets, set]..sort((a, b) => a.at.compareTo(b.at));
    _save();
  }

  void addSession({required String routineId, required int seconds}) {
    _sessions = [
      ..._sessions,
      LoggedSession(id: _newId(), routineId: routineId, at: DateTime.now(), seconds: seconds),
    ];
    _save();
  }

  LoggedMeal addMeal({
    required MealSlot slot,
    required List<MealItem> items,
    required String source,
    String? photo,
  }) {
    final meal = LoggedMeal(
      id: _newId(),
      at: DateTime.now(),
      slot: slot,
      items: items,
      photo: photo,
      source: source,
    );
    _meals = [..._meals, meal];
    _save();
    return meal;
  }

  void updateMeal(LoggedMeal meal) {
    _meals = [for (final m in _meals) m.id == meal.id ? meal : m];
    _save();
  }

  LoggedMeal? removeMeal(String id) {
    final found = _meals.where((m) => m.id == id).firstOrNull;
    _meals = _meals.where((m) => m.id != id).toList();
    _save();
    return found;
  }

  void restoreMeal(LoggedMeal meal) {
    _meals = [..._meals, meal]..sort((a, b) => a.at.compareTo(b.at));
    _save();
  }

  /// Wipe the training log, the meals, or everything.
  void clear({bool training = false, bool meals = false}) {
    if (training) {
      _sets = [];
      _sessions = [];
    }
    if (meals) _meals = [];
    _save();
  }
}
