import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalize/state/cloud.dart';
import 'package:vitalize/state/log_store.dart';
import 'package:vitalize/state/prefs_store.dart';

void main() {
  late FakeFirebaseFirestore db;
  late UserDoc user;

  setUp(() {
    db = FakeFirebaseFirestore();
    user = db.collection('users').doc('u1');
  });

  group('LogStore', () {
    test('a logged set shows at once and is saved under the user', () async {
      final log = LogStore(Future.value(user));
      final set = log.addSet(exerciseId: 'push-up', reps: 12);
      expect(log.sets.single.id, set.id);
      await pumpEventQueue();
      final doc = await user.collection('sets').doc(set.id).get();
      expect(doc.data(), {
        'id': set.id,
        'exerciseId': 'push-up',
        'at': Timestamp.fromDate(set.at),
        'reps': 12,
      });
      expect(log.sets.single.reps, 12);
    });

    test('entries written elsewhere show up, damaged ones are left out', () async {
      final log = LogStore(Future.value(user));
      await pumpEventQueue();
      final sets = user.collection('sets');
      await sets.doc('b').set({
        'exerciseId': 'plank',
        'at': Timestamp.fromDate(DateTime(2026, 10, 20, 7, 30)),
        'seconds': 45,
      });
      await sets.doc('a').set({
        'exerciseId': 'push-up',
        'at': Timestamp.fromDate(DateTime(2026, 10, 20, 7)),
        'reps': 10,
      });
      // No exercise: the store can't read it.
      await sets.doc('broken').set({
        'at': Timestamp.fromDate(DateTime(2026, 10, 20, 8)),
        'reps': 5,
      });
      await pumpEventQueue();
      expect([for (final s in log.sets) s.id], ['a', 'b']);
      expect(log.sets.last.seconds, 45);
    });

    test('removing a set and taking it back', () async {
      final log = LogStore(Future.value(user));
      final set = log.addSet(exerciseId: 'push-up', reps: 12);
      await pumpEventQueue();
      final removed = log.removeSet(set.id)!;
      expect(log.sets, isEmpty);
      await pumpEventQueue();
      expect((await user.collection('sets').doc(set.id).get()).exists, isFalse);
      log.restoreSet(removed);
      await pumpEventQueue();
      expect((await user.collection('sets').doc(set.id).get()).exists, isTrue);
      expect(log.sets.single.id, set.id);
    });

    test('clearing the training log keeps the meals', () async {
      final log = LogStore(Future.value(user))
        ..addSet(exerciseId: 'push-up', reps: 12)
        ..addSession(routineId: 'warm-up', seconds: 300)
        ..addMeal(slot: MealSlot.lunch, items: const [], source: 'demo');
      await pumpEventQueue();
      log.clear(training: true);
      await pumpEventQueue();
      expect((await user.collection('sets').get()).docs, isEmpty);
      expect((await user.collection('sessions').get()).docs, isEmpty);
      expect((await user.collection('meals').get()).docs, hasLength(1));
      expect(log.sets, isEmpty);
      expect(log.meals, hasLength(1));
    });

    test('what is logged before signing in is saved once signed in', () async {
      final signedIn = Completer<UserDoc>();
      final log = LogStore(signedIn.future);
      final set = log.addSet(exerciseId: 'push-up', reps: 10);
      expect(log.sets, hasLength(1));
      signedIn.complete(user);
      await pumpEventQueue();
      expect((await user.collection('sets').doc(set.id).get()).exists, isTrue);
      expect(log.sets.single.id, set.id);
    });
  });

  test('the profile goes to Firestore, the settings stay on the phone', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final prefs = PrefsStore(sp, Future.value(user));
    prefs.updateProfile(prefs.profile.copyWith(name: 'An', heightCm: 170.0, goal: Goal.gain));
    prefs.updateSettings(prefs.settings.copyWith(haptics: false));
    await pumpEventQueue();
    final doc = (await user.get()).data()!;
    expect(doc.keys, ['profile']);
    expect(doc['profile'], containsPair('name', 'An'));
    expect(
      sp.getString('vitalize.prefs.v1'),
      allOf(contains('"haptics":false'), isNot(contains('An'))),
    );

    final later = PrefsStore(sp, Future.value(user));
    await pumpEventQueue();
    expect(later.profile.name, 'An');
    expect(later.profile.goal, Goal.gain);
    expect(later.settings.haptics, isFalse);
  });
}
