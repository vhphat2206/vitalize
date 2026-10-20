import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../data/models.dart';

/// The animated demo of an exercise or routine move, with its two captions underneath (or, with
/// [fill], filling the parent's height without captions, as in the workout player).
/// Placeholder until the demo rig is ported.
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
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: V.bg2,
        border: Border.all(color: V.line),
        borderRadius: BorderRadius.circular(V.rControl),
      ),
    ),
  );
}
