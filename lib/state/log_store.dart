import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/models.dart';
import 'cloud.dart';

/// A time as stored: a Firestore timestamp, or epoch milliseconds.
DateTime _time(Object? v) =>
    v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(v as int);

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
      at = _time(j['at']),
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
    'at': Timestamp.fromDate(at),
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
      at = _time(j['at']),
      seconds = j['seconds'] as int;

  final String id;
  final String routineId;
  final DateTime at;

  /// Time actually spent, in seconds.
  final int seconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'routineId': routineId,
    'at': Timestamp.fromDate(at),
    'seconds': seconds,
  };
}

enum MealSlot { breakfast, lunch, dinner, snack }

const mealSlotLabel = {
  MealSlot.breakfast: 'Bữa sáng',
  MealSlot.lunch: 'Bữa trưa',
  MealSlot.dinner: 'Bữa tối',
  MealSlot.snack: 'Bữa phụ',
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
      at = _time(j['at']),
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
    'at': Timestamp.fromDate(at),
    'slot': slot.name,
    'items': [for (final i in items) i.toJson()],
    'photo': ?photo,
    'source': source,
  };
}

/// Logged sets, finished sessions and meals, kept in Cloud Firestore with the signed-in user
/// (`users/{uid}/sets`, `…/sessions`, `…/meals`). Firestore also keeps them on the phone, so the
/// log works offline and catches up when the phone is back online.
///
/// Changes show at once: each method updates the lists here, then writes to Firestore, whose
/// snapshots keep the lists in step afterwards.
class LogStore extends ChangeNotifier {
  LogStore(this._user) {
    _user.then(_listen);
  }

  static const _photoDays = 30;

  final Future<UserDoc> _user;
  final _random = Random();
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false;

  List<LoggedSet> _sets = [];
  List<LoggedSession> _sessions = [];
  List<LoggedMeal> _meals = [];

  List<LoggedSet> get sets => List.unmodifiable(_sets);
  List<LoggedSession> get sessions => List.unmodifiable(_sessions);
  List<LoggedMeal> get meals => List.unmodifiable(_meals);

  void _listen(UserDoc user) {
    if (_disposed) return;
    _subscriptions.addAll([
      _watch(user.collection('sets'), LoggedSet.fromJson, (v) => _sets = v),
      _watch(user.collection('sessions'), LoggedSession.fromJson, (v) => _sessions = v),
      _watch(user.collection('meals'), LoggedMeal.fromJson, (v) {
        _meals = v;
        _dropOldPhotos();
      }),
    ]);
  }

  StreamSubscription<Object?> _watch<T>(
    CollectionReference<Map<String, dynamic>> collection,
    T Function(Map<String, dynamic>) read,
    void Function(List<T>) keep,
  ) => collection.orderBy('at').snapshots().listen((snapshot) {
    final items = <T>[];
    for (final doc in snapshot.docs) {
      try {
        items.add(read({...doc.data(), 'id': doc.id}));
      } catch (_) {
        // A damaged entry is left out rather than crashing the app.
      }
    }
    keep(items);
    notifyListeners();
  }, onError: (Object e) => debugPrint('Reading ${collection.id} failed: $e'));

  /// Photos are small JPEGs inside the meal; after 30 days only the foods are kept.
  void _dropOldPhotos() {
    final cutoff = DateTime.now().subtract(const Duration(days: _photoDays));
    for (final meal in _meals) {
      if (meal.photo != null && meal.at.isBefore(cutoff)) {
        _write((u) => u.collection('meals').doc(meal.id).update({'photo': FieldValue.delete()}));
      }
    }
  }

  /// Runs [write] once signed in. Writes start in the order they were made; offline, Firestore
  /// queues them and sends them later.
  void _write(Future<void> Function(UserDoc user) write) {
    _user.then(write).catchError((Object e) => debugPrint('Saving to Firestore failed: $e'));
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
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
    restoreSet(set);
    return set;
  }

  LoggedSet? removeSet(String id) {
    final found = _sets.where((s) => s.id == id).firstOrNull;
    _sets = _sets.where((s) => s.id != id).toList();
    notifyListeners();
    _write((u) => u.collection('sets').doc(id).delete());
    return found;
  }

  void restoreSet(LoggedSet set) {
    _sets = [..._sets, set]..sort((a, b) => a.at.compareTo(b.at));
    notifyListeners();
    _write((u) => u.collection('sets').doc(set.id).set(set.toJson()));
  }

  void addSession({required String routineId, required int seconds}) => restoreSession(
    LoggedSession(id: _newId(), routineId: routineId, at: DateTime.now(), seconds: seconds),
  );

  void restoreSession(LoggedSession session) {
    _sessions = [..._sessions, session]..sort((a, b) => a.at.compareTo(b.at));
    notifyListeners();
    _write((u) => u.collection('sessions').doc(session.id).set(session.toJson()));
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
    restoreMeal(meal);
    return meal;
  }

  void updateMeal(LoggedMeal meal) {
    _meals = [for (final m in _meals) m.id == meal.id ? meal : m];
    notifyListeners();
    _write((u) => u.collection('meals').doc(meal.id).set(meal.toJson()));
  }

  LoggedMeal? removeMeal(String id) {
    final found = _meals.where((m) => m.id == id).firstOrNull;
    _meals = _meals.where((m) => m.id != id).toList();
    notifyListeners();
    _write((u) => u.collection('meals').doc(id).delete());
    return found;
  }

  void restoreMeal(LoggedMeal meal) {
    _meals = [..._meals, meal]..sort((a, b) => a.at.compareTo(b.at));
    notifyListeners();
    _write((u) => u.collection('meals').doc(meal.id).set(meal.toJson()));
  }

  /// Wipe the training log, the meals, or everything.
  void clear({bool training = false, bool meals = false}) {
    final doomed = [
      if (training) ...[
        for (final s in _sets) ('sets', s.id),
        for (final s in _sessions) ('sessions', s.id),
      ],
      if (meals)
        for (final m in _meals) ('meals', m.id),
    ];
    if (training) {
      _sets = [];
      _sessions = [];
    }
    if (meals) _meals = [];
    notifyListeners();
    _write((u) async {
      // A batch takes at most 500 writes.
      for (var i = 0; i < doomed.length; i += 500) {
        final batch = u.firestore.batch();
        for (final (collection, id) in doomed.skip(i).take(500)) {
          batch.delete(u.collection(collection).doc(id));
        }
        await batch.commit();
      }
    });
  }
}
