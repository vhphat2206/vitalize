// Stills of a varied set of demos at the start, middle and end of the move, laid out like the
// web app's demo lab (tools/demo-lab: 300 px columns, 16 apart) so they can be compared with it.
//
// For a closer look, write them as PNGs at 2x into a folder instead (DEMO_IDS picks others):
//   flutter test test/demo_golden_test.dart \
//     --dart-define=DEMO_SCALE=2 --dart-define=DEMO_OUT=/abs/path/to/folder
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/app/theme.dart';
import 'package:vitalize/data/catalog.dart';
import 'package:vitalize/data/models.dart';
import 'package:vitalize/demo/demo_data.dart';
import 'package:vitalize/demo/exercise_demo.dart';

import 'support/harness.dart';

const _ids = [
  'back-squat',
  'barbell-bench-press',
  'pull-up', // back view
  'russian-twist', // front view, twist
  'cable-woodchop',
  'side-step-touch', // knees bent towards the camera
  'crunch', // curl
  'deadlift', // barbell
  'cable-crunch', // cable in front
  'seated-cable-row', // seat and board
  'burpee', // cycle
];
const _frames = [0.0, 0.5, 1.0];

/// With DEMO_OUT, other moments can be picked: --dart-define=DEMO_FRAMES=0.2,0.4,0.8
const _pickFrames = String.fromEnvironment('DEMO_FRAMES');

const _scale = int.fromEnvironment('DEMO_SCALE', defaultValue: 1) * 1.0;
const _out = String.fromEnvironment('DEMO_OUT');

/// With DEMO_OUT, other demos can be picked: --dart-define=DEMO_IDS=chin-up,pec-deck
const _pick = String.fromEnvironment('DEMO_IDS');

/// The muscles the demo lab paints: an exercise's own, or a routine move's (the last one listed).
(List<MuscleId>, List<MuscleId>) _muscles(String id) {
  final ex = catalog.exerciseById[id];
  if (ex != null) return (ex.primary, ex.secondary);
  RoutineMove? move;
  for (final r in catalog.routines) {
    for (final m in r.moves) {
      if (m.id == id) move = m;
    }
  }
  return (move?.muscles ?? const [], const []);
}

void main() {
  setUpAll(setUpApp);

  final ids = _out.isNotEmpty && _pick.isNotEmpty ? _pick.split(',') : _ids;
  final frames = _out.isNotEmpty && _pickFrames.isNotEmpty
      ? [for (final f in _pickFrames.split(',')) double.parse(f)]
      : _frames;
  for (final id in ids) {
    testWidgets('demo $id', (tester) async {
      tester.view.physicalSize = const Size(948, 380);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (primary, secondary) = _muscles(id);
      const key = ValueKey('demos');
      final row = SizedBox(
        width: 948,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, f) in frames.indexed) ...[
              if (i > 0) const SizedBox(width: 16),
              SizedBox(
                width: 300,
                child: ExerciseDemo(
                  demo: demoFor(id)!,
                  primary: primary,
                  secondary: secondary,
                  still: f,
                ),
              ),
            ],
          ],
        ),
      );
      await tester.pumpWidget(
        await appFrame(
          Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(color: V.bg, child: row),
            ),
          ),
        ),
      );
      if (_out.isNotEmpty) {
        // A close-up for comparing by eye, not a golden.
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: _scale);
          final png = await image.toByteData(format: ImageByteFormat.png);
          File('$_out/$id.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
        return;
      }
      await expectLater(find.byKey(key), matchesGoldenFile('goldens/demo_$id.png'));
    });
  }
}
