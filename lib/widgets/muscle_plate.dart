import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../logic/sides.dart';
import 'body_figure.dart';

/// One or two small figures with the worked muscles painted, plus a written legend.
class MusclePlate extends StatelessWidget {
  const MusclePlate({
    super.key,
    required this.primary,
    required this.secondary,
    this.height = 280,
    this.legend = true,
  });

  final List<MuscleId> primary;
  final List<MuscleId> secondary;

  /// Height of each figure.
  final double height;
  final bool legend;

  @override
  Widget build(BuildContext context) {
    final tones = <MuscleId, Tone>{
      for (final m in secondary) m: Tone.secondary,
      for (final m in primary) m: Tone.primary,
    };
    final sides = sidesFor(primary, secondary);
    final figures = SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, side) in sides.indexed) ...[
            if (i > 0) const SizedBox(width: 18),
            BodyFigure(side: side, tones: tones),
          ],
        ],
      ),
    );
    if (!legend) return Center(child: figures);
    final key = _Legend(primary: primary, secondary: secondary);
    // A single view leaves room for the legend beside it.
    if (sides.length == 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          figures,
          const SizedBox(width: 16),
          Expanded(child: key),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: figures),
        const SizedBox(height: 16),
        key,
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.primary, required this.secondary});

  final List<MuscleId> primary;
  final List<MuscleId> secondary;

  String _names(List<MuscleId> ids) => ids.map((id) => catalog.muscleById[id]!.name).join(', ');

  Widget _entry(Widget swatch, String key, String names) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(top: 3), child: swatch),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: VT.ui(13, weight: FontWeight.w600, height: 1.4, color: V.muted),
            ),
            const SizedBox(height: 2),
            Text(names, style: VT.ui(14, height: 1.4)),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _entry(const _Swatch(hatched: false), 'Cơ chính', _names(primary)),
      if (secondary.isNotEmpty) ...[
        const SizedBox(height: 10),
        _entry(const _Swatch(hatched: true), 'Cơ phụ', _names(secondary)),
      ],
    ],
  );
}

/// Solid green for primary muscles, green stripes for secondary ones.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.hatched});

  final bool hatched;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox.square(
      dimension: 14,
      child: hatched
          ? const CustomPaint(painter: _StripePainter())
          : const ColoredBox(color: V.accent),
    ),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = V.muscle);
    final p = Paint()
      ..color = V.accent
      ..strokeWidth = 1.6;
    for (var x = -size.height; x < size.width + size.height; x += 4.4) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height * 0.58, 0), p);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}
