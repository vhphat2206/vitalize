import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/data/catalog.dart';
import 'package:vitalize/data/models.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/state/prefs_store.dart';

/// "Now" in the food and week tests: Tuesday 20 October 2026, 12:30.
final testNow = DateTime(2026, 10, 20, 12, 30);

/// Monday of [testNow]'s week plus [day] days, at [h]:[m].
DateTime weekAt(int day, int h, int m) => DateTime(2026, 10, 19 + day, h, m);

final mealPhotoBytes = File('test/fixtures/meal_photo.jpg').readAsBytesSync();

/// A 220 px thumbnail, base64, as a saved meal keeps it.
final mealThumbBase64 = base64Encode(File('test/fixtures/meal_thumb.jpg').readAsBytesSync());

FoodItem sample(String name) =>
    catalog.sampleMeals.expand((m) => m).firstWhere((f) => f.name == name);

/// Today's meals (and one from yesterday), oldest first.
List<LoggedMeal> seedMeals() => [
  LoggedMeal(
    id: 'm-yesterday',
    at: weekAt(0, 19, 0),
    slot: MealSlot.dinner,
    items: [MealItem(food: sample('Phở bò tái'))],
    photo: mealThumbBase64,
    source: 'demo',
  ),
  LoggedMeal(
    id: 'm-breakfast',
    at: weekAt(1, 7, 40),
    slot: MealSlot.breakfast,
    items: [MealItem(food: sample('Bánh mì thịt'))],
    photo: mealThumbBase64,
    source: 'demo',
  ),
  LoggedMeal(
    id: 'm-snack',
    at: weekAt(1, 10, 5),
    slot: MealSlot.snack,
    items: [MealItem(food: sample('Gỏi cuốn tôm thịt'))],
    source: 'ai',
  ),
  LoggedMeal(
    id: 'm-lunch',
    at: weekAt(1, 12, 15),
    slot: MealSlot.lunch,
    items: [
      MealItem(food: sample('Cơm tấm sườn nướng')),
      MealItem(food: sample('Trứng ốp la'), servings: 1.5),
    ],
    photo: mealThumbBase64,
    source: 'demo',
  ),
];

/// This week's training (and a set from last week that must not count).
Map<String, Object> seedTraining() {
  var n = 0;
  Map<String, Object?> set(DateTime at, String ex, {double? kg, int? reps, int? seconds}) => {
    'id': 's${n++}',
    'exerciseId': ex,
    'at': at.millisecondsSinceEpoch,
    'kg': ?kg,
    'reps': ?reps,
    'seconds': ?seconds,
  };
  final sets = [
    set(weekAt(-1, 10, 0), 'push-up', reps: 15),
    set(weekAt(0, 18, 5), 'barbell-bench-press', kg: 40, reps: 8),
    set(weekAt(0, 18, 9), 'barbell-bench-press', kg: 40, reps: 8),
    set(weekAt(0, 18, 13), 'barbell-bench-press', kg: 45, reps: 6),
    set(weekAt(0, 18, 20), 'incline-dumbbell-press', kg: 16, reps: 10),
    set(weekAt(0, 18, 24), 'incline-dumbbell-press', kg: 16, reps: 10),
    set(weekAt(0, 18, 28), 'incline-dumbbell-press', kg: 16, reps: 9),
    set(weekAt(0, 18, 35), 'lat-pulldown', kg: 35, reps: 10),
    set(weekAt(0, 18, 39), 'lat-pulldown', kg: 35, reps: 10),
    for (final m in [15, 20, 25]) set(weekAt(1, 7, m), 'back-squat', kg: 60, reps: 5),
    for (final m in [32, 36, 40, 44, 48]) set(weekAt(1, 7, m), 'leg-press', kg: 100, reps: 10),
    for (final m in [52, 56]) set(weekAt(1, 7, m), 'leg-extension', kg: 30, reps: 12),
    for (final m in [0, 4]) set(weekAt(1, 8, m), 'leg-extension', kg: 30, reps: 12),
    set(weekAt(1, 8, 10), 'plank', seconds: 45),
  ];
  final sessions = [
    {
      'id': 'r0',
      'routineId': 'warm-up',
      'at': weekAt(0, 7, 0).millisecondsSinceEpoch,
      'seconds': 367,
    },
    {
      'id': 'r1',
      'routineId': 'core-12',
      'at': weekAt(1, 6, 50).millisecondsSinceEpoch,
      'seconds': 720,
    },
  ];
  return {'sets': sets, 'sessions': sessions};
}

/// A profile with body data, so the food tab shows targets.
const seedProfile = {
  'name': '',
  'sex': 'male',
  'birthYear': 1998,
  'heightCm': 172,
  'weightKg': 68,
  'goal': 'maintain',
  'level': 1,
  'daysPerWeek': 3,
};

/// Fills [appFrame]'s stores: the training log, and the profile when [profile] is set.
void seedStores(LogStore log, PrefsStore prefs, {bool training = true, bool profile = false}) {
  if (training) {
    final t = seedTraining();
    for (final s in t['sets']! as List) {
      log.restoreSet(LoggedSet.fromJson(s as Map<String, dynamic>));
    }
    for (final s in t['sessions']! as List) {
      log.restoreSession(LoggedSession.fromJson(s as Map<String, dynamic>));
    }
  }
  if (profile) prefs.updateProfile(Profile.fromJson(seedProfile));
}

/// Decodes every image on screen (image codecs run outside the fake test clock).
Future<void> loadImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

/// When VITALIZE_SNAP_DIR is set, also saves the screen at 2x there, to compare with the web
/// app's screenshots side by side.
Future<void> snap(WidgetTester tester, String name) async {
  final dir = Platform.environment['VITALIZE_SNAP_DIR'];
  if (dir == null) return;
  var ro = tester.renderObject(find.byType(Overlay).first);
  while (!ro.isRepaintBoundary) {
    ro = ro.parent!;
  }
  final layer = ro.debugLayer! as OffsetLayer;
  // The boundary may be the root view, which paints in physical pixels.
  final ratio =
      2 * tester.view.physicalSize.width / tester.view.devicePixelRatio / ro.paintBounds.width;
  await tester.runAsync(() async {
    final image = await layer.toImage(ro.paintBounds, pixelRatio: ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
