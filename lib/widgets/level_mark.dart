import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../data/catalog.dart';

/// Three rising bars, filled up to the level. Reads like a load indicator, not a star rating.
class LevelMark extends StatelessWidget {
  const LevelMark({super.key, required this.level, this.withLabel = false, this.color = V.muted});

  final int level;
  final bool withLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = catalog.levelLabel[level]!;
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: const Size(14, 12), painter: _Bars(level, color)),
          if (withLabel) ...[const SizedBox(width: 6), Text(label, style: VT.ui(13, color: color))],
        ],
      ),
    );
  }
}

class _Bars extends CustomPainter {
  const _Bars(this.level, this.color);

  final int level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(i * 5.0, 8.0 - i * 4, 3.4, 4.0 + i * 4);
      final on = i < level;
      final c = on ? color : color.withValues(alpha: color.a * 0.45);
      if (on) canvas.drawRect(r, Paint()..color = c);
      canvas.drawRect(
        r,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_Bars old) => old.level != level || old.color != color;
}
