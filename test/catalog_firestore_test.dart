import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/data/catalog.dart';

// Its own file: the catalog loads once per test isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the exercise catalog comes from Firestore when it has one', () async {
    Future<dynamic> read(String name) async =>
        jsonDecode(await rootBundle.loadString('assets/data/$name.json'));

    // Laid out as tool/seed_firestore.dart does it.
    final db = FakeFirebaseFirestore();
    for (final name in ['exercises', 'routines', 'moves']) {
      for (final (i, item) in (await read(name) as List).indexed) {
        await db.collection(name).doc(item['id'] as String).set({
          ...item as Map<String, dynamic>,
          'order': i,
        });
      }
    }
    final muscles = await read('muscles') as Map<String, dynamic>;
    for (final (i, m) in (muscles['muscles'] as List).indexed) {
      await db.collection('muscles').doc(m['id'] as String).set({
        ...m as Map<String, dynamic>,
        'order': i,
      });
    }
    await db.collection('meta').doc('muscleOrder').set(muscles['order'] as Map<String, dynamic>);
    await db
        .collection('meta')
        .doc('equipment')
        .set(await read('equipment') as Map<String, dynamic>);
    await db.collection('exercises').doc('plank').update({'name': 'Plank (Firestore)'});

    final catalog = await Catalog.load(db: db);
    final bundled = await read('exercises') as List;
    expect(catalog.exerciseById['plank']!.name, 'Plank (Firestore)');
    expect([for (final e in catalog.exercises) e.id], [for (final e in bundled) e['id']]);
    expect(catalog.muscles, hasLength((muscles['muscles'] as List).length));
    expect(catalog.equipmentLabel['barbell'], 'Tạ đòn');
    expect(catalog.routineById['warm-up']!.moves.first.id, 'arm-circles');
    // Not in Firestore: still from the app's assets.
    expect(catalog.demos, isNotEmpty);
  });
}
