import 'package:flutter/widgets.dart';

import '../data/models.dart';
import 'demo_data.dart';
import 'exercise_demo.dart';

/// The animated demo of an exercise or routine move, with its two captions underneath (or, with
/// [fill], filling the parent's height without captions, as in the workout player). Nothing when
/// the id has no demo.
class ExerciseDemoFor extends StatelessWidget {
  const ExerciseDemoFor({
    super.key,
    required this.id,
    required this.primary,
    required this.secondary,
    this.fill = false,
  });

  final String id;
  final List<MuscleId> primary;
  final List<MuscleId> secondary;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final demo = demoFor(id);
    if (demo == null) return const SizedBox.shrink();
    // A new move starts its loop from the beginning.
    return ExerciseDemo(
      key: ValueKey(id),
      demo: demo,
      primary: primary,
      secondary: secondary,
      fill: fill,
    );
  }
}
