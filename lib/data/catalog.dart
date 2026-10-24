import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// All the app's content, loaded once at start-up. The exercise catalog (exercises, muscles,
/// equipment, routines, moves) comes from Cloud Firestore when [load] is given a database; the
/// body artwork, the demos and the sample meals always come from the JSON assets.
class Catalog {
  Catalog._({
    required this.muscles,
    required this.muscleOrder,
    required this.equipmentLabel,
    required this.levelLabel,
    required this.exercises,
    required this.routines,
    required this.moves,
    required this.body,
    required this.sampleMeals,
    required this.demos,
    required this.rigParts,
  }) : muscleById = {for (final m in muscles) m.id: m},
       exerciseById = {for (final e in exercises) e.id: e},
       routineById = {for (final r in routines) r.id: r},
       moveById = {for (final m in moves) m.id: m};

  /// Set by [load]; every screen reads from here.
  static late final Catalog instance;

  final List<Muscle> muscles;
  final Map<MuscleId, Muscle> muscleById;

  /// Order of the muscle strip under the figure, head to toe, per side.
  final Map<BodySide, List<MuscleId>> muscleOrder;
  final Map<String, String> equipmentLabel;
  final Map<int, String> levelLabel;
  final List<Exercise> exercises;
  final Map<String, Exercise> exerciseById;
  final List<Routine> routines;
  final Map<String, Routine> routineById;
  final List<Move> moves;
  final Map<String, Move> moveById;

  /// Body artwork, `front` and `back`.
  final Map<BodySide, BodyView> body;

  /// Sample analysis results for the meal scanner's demo mode.
  final List<List<FoodItem>> sampleMeals;

  /// Exercise demos as exported (see lib/demo for the format), by exercise or move id.
  final Map<String, dynamic> demos;

  /// The demo mannequin's body parts per view (see lib/demo).
  final Map<String, dynamic> rigParts;

  /// The guides behind an exercise or a routine move.
  List<Reference> refsFor(String id) => exerciseById[id]?.refs ?? moveById[id]?.refs ?? const [];

  /// With [db], the catalog is read from Firestore: from the server when it answers within a few
  /// seconds, else from Firestore's copy on the phone, else (first launch offline, or nothing
  /// seeded yet) from the assets the app ships with.
  static Future<Catalog> load({FirebaseFirestore? db}) async {
    final cloud = db == null ? null : await _fromFirestore(db);
    Future<dynamic> read(String name) async =>
        cloud?[name] ?? jsonDecode(await rootBundle.loadString('assets/data/$name.json'));

    final muscles = await read('muscles') as Map<String, dynamic>;
    final equipment = await read('equipment') as Map<String, dynamic>;
    final body = await read('body') as Map<String, dynamic>;

    final catalog = Catalog._(
      muscles: [
        for (final m in muscles['muscles'] as List) Muscle.fromJson(m as Map<String, dynamic>),
      ],
      muscleOrder: (muscles['order'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      ),
      equipmentLabel: Map<String, String>.from(equipment['labels'] as Map),
      levelLabel: (equipment['levels'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      ),
      exercises: [
        for (final e in await read('exercises') as List)
          Exercise.fromJson(e as Map<String, dynamic>),
      ],
      routines: [
        for (final r in await read('routines') as List) Routine.fromJson(r as Map<String, dynamic>),
      ],
      moves: [
        for (final m in await read('moves') as List) Move.fromJson(m as Map<String, dynamic>),
      ],
      body: {
        for (final side in ['front', 'back'])
          side: BodyView.fromJson(body[side] as Map<String, dynamic>),
      },
      sampleMeals: [
        for (final meal in await read('sample_meals') as List)
          [for (final f in meal as List) FoodItem.fromJson(f as Map<String, dynamic>)],
      ],
      demos: await read('demos') as Map<String, dynamic>,
      rigParts: await read('rig_parts') as Map<String, dynamic>,
    );
    instance = catalog;
    return catalog;
  }

  /// The catalog as laid out by tool/seed_firestore.dart, in the shape of the JSON assets, or
  /// null when Firestore has none to give.
  static Future<Map<String, Object>?> _fromFirestore(FirebaseFirestore db) async {
    for (final source in [Source.server, Source.cache]) {
      final options = GetOptions(source: source);
      Future<List<Map<String, dynamic>>> list(String collection) async {
        final snapshot = await db.collection(collection).orderBy('order').get(options);
        return [
          for (final doc in snapshot.docs) {...doc.data()}..remove('order'),
        ];
      }

      Future<Map<String, dynamic>> meta(String id) async =>
          (await db.collection('meta').doc(id).get(options)).data() ?? const {};

      try {
        final [
          exercises as List<Map<String, dynamic>>,
          muscles as List<Map<String, dynamic>>,
          routines as List<Map<String, dynamic>>,
          moves as List<Map<String, dynamic>>,
          muscleOrder as Map<String, dynamic>,
          equipment as Map<String, dynamic>,
        ] = await Future.wait<Object>([
          list('exercises'),
          list('muscles'),
          list('routines'),
          list('moves'),
          meta('muscleOrder'),
          meta('equipment'),
        ]).timeout(const Duration(seconds: 6));
        final lists = [exercises, muscles, routines, moves];
        if (lists.any((l) => l.isEmpty) || muscleOrder.isEmpty || equipment.isEmpty) continue;
        debugPrint('Catalog from Firestore (${source.name})');
        return {
          'exercises': exercises,
          'muscles': {'muscles': muscles, 'order': muscleOrder},
          'routines': routines,
          'moves': moves,
          'equipment': equipment,
        };
      } catch (e) {
        debugPrint('Catalog not available from Firestore (${source.name}): $e');
      }
    }
    return null;
  }
}

/// Shorthand for [Catalog.instance].
Catalog get catalog => Catalog.instance;
