import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../logic/format.dart';
import 'icons.dart';
import 'level_mark.dart';
import 'pressable.dart';

/// An exercise in a list: equipment glyph, name, equipment and dose, level.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({super.key, required this.exercise, required this.onOpen, this.quiet = false});

  final Exercise exercise;
  final VoidCallback onOpen;

  /// Lighter name, for secondary lists.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    return Pressable(
      onTap: onOpen,
      builder: (pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: V.pad, vertical: 12),
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00000000),
          border: const Border(bottom: BorderSide(color: V.line)),
        ),
        child: Row(
          children: [
            VIcon(VIcons.equipment(ex.equipment), color: V.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.name,
                    style: quiet
                        ? VT.ui(15, weight: FontWeight.w500, height: 1.3, em: -0.01)
                        : VT.ui(16, weight: FontWeight.w600, height: 1.3, em: -0.01),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        catalog.equipmentLabel[ex.equipment]!,
                        style: VT.ui(13, height: 1.35, color: V.muted),
                      ),
                      Text(doseText(ex.dose), style: VT.mono(12, height: 1.35, color: V.muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            LevelMark(level: ex.level),
          ],
        ),
      ),
    );
  }
}
