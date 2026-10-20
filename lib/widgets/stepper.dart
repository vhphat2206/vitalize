import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import 'icons.dart';
import 'pressable.dart';

/// Big, thumb-sized − and + around a number: usable with sweaty hands between sets.
class VStepper extends StatelessWidget {
  const VStepper({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.step,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.format,
  });

  final String label;
  final String unit;
  final double value;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double v)? format;

  void _set(double v) => onChanged(((v * 100).round() / 100).clamp(min, max));

  String _text(double v) =>
      format?.call(v) ?? (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${_text(value)} $unit',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: VT.ui(13, weight: FontWeight.w600, height: 1, color: V.muted),
        ),
        const SizedBox(height: 8),
        Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V.rControl),
            border: Border.all(color: V.lineStrong),
          ),
          child: Row(
            children: [
              _Btn(
                glyph: VIcons.minus,
                label: 'Giảm ${label.toLowerCase()}',
                enabled: value > min,
                onTap: () => _set(value - step),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border.symmetric(vertical: BorderSide(color: V.line)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(_text(value), style: VT.mono(30, weight: FontWeight.w500, height: 1)),
                      const SizedBox(width: 6),
                      Text(unit, style: VT.ui(13, color: V.muted)),
                    ],
                  ),
                ),
              ),
              _Btn(
                glyph: VIcons.plus,
                label: 'Tăng ${label.toLowerCase()}',
                enabled: value < max,
                onTap: () => _set(value + step),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.glyph,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final VGlyph glyph;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: label,
    child: Pressable(
      onTap: enabled ? onTap : null,
      builder: (pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        color: pressed ? V.bg3 : const Color(0x00000000),
        alignment: Alignment.center,
        child: VIcon(glyph, size: 22, color: enabled ? V.ink : V.faint),
      ),
    ),
  );
}
