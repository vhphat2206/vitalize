import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/theme.dart';
import '../logic/format.dart';
import '../logic/meals.dart';
import '../logic/nutrition.dart';
import '../state/log_store.dart';
import 'icons.dart';
import 'pressable.dart';

/// 1 → "1 phần", 1.5 → "1,5 phần".
String servingsText(double s) =>
    '${(s == s.roundToDouble() ? s.toInt().toString() : s.toString()).replaceAll('.', ',')} phần';

/// Dishes found in a photo: adjust each portion in half servings, drop anything the AI got
/// wrong, and see the total.
class MealEditor extends StatelessWidget {
  const MealEditor({super.key, required this.items, required this.onChanged});

  final List<MealItem> items;
  final ValueChanged<List<MealItem>> onChanged;

  @override
  Widget build(BuildContext context) {
    final total = itemsTotals(items);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: V.lineStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed)
            _FoodRow(
              item: item,
              canRemove: items.length > 1,
              onServings: (s) => onChanged([
                for (final (j, it) in items.indexed) j == i ? it.withServings(s) : it,
              ]),
              onRemove: () => onChanged([...items]..removeAt(i)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text('Tổng', style: VT.ui(16, weight: FontWeight.w600, height: 1.3)),
                    ),
                    Text(
                      '${formatNumber(total.kcal)} kcal',
                      style: VT.mono(20, weight: FontWeight.w500, height: 1.3),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _Macros(total, height: 1.3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.item,
    required this.canRemove,
    required this.onServings,
    required this.onRemove,
  });

  final MealItem item;
  final bool canRemove;
  final ValueChanged<double> onServings;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final f = item.food;
    final s = item.servings;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: V.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(f.name, style: VT.ui(17, weight: FontWeight.w600, height: 1.3)),
              ),
              const SizedBox(width: 12),
              Text('${formatNumber(f.kcal * s)} kcal', style: VT.mono(14, height: 1.5)),
            ],
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              style: VT.ui(13.5, color: V.muted),
              children: [
                TextSpan(text: '${f.portion}, khoảng '),
                TextSpan(
                  text: '${formatNumber(f.grams)} g',
                  style: VT.mono(12.5, height: 1.5, color: V.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _Macros(Macros(protein: f.protein * s, carb: f.carb * s, fat: f.fat * s)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                container: true,
                label: 'Khẩu phần ${f.name}',
                child: Container(
                  height: 40,
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(V.rControl),
                    border: Border.all(color: V.lineStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepButton(
                        glyph: VIcons.minus,
                        label: 'Bớt nửa phần',
                        onTap: s <= 0.5 ? null : () => onServings(math.max(0.5, s - 0.5)),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 78),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            servingsText(s),
                            textAlign: TextAlign.center,
                            style: VT.ui(14, weight: FontWeight.w500, height: 1),
                          ),
                        ),
                      ),
                      _StepButton(
                        glyph: VIcons.plus,
                        label: 'Thêm nửa phần',
                        onTap: s >= 4 ? null : () => onServings(math.min(4, s + 0.5)),
                      ),
                    ],
                  ),
                ),
              ),
              if (canRemove)
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const VIcon(VIcons.close, size: 16, color: V.muted),
                          const SizedBox(width: 6),
                          Text('Bỏ món này', style: VT.ui(13.5, color: V.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Đạm 46 g   Tinh bột 0 g   Béo 6 g"
class _Macros extends StatelessWidget {
  const _Macros(this.m, {this.height = 1.5});

  final Macros m;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = VT.mono(12, height: height, color: V.muted);
    return Wrap(
      spacing: 14,
      children: [
        Text('Đạm ${formatNumber(m.protein)} g', style: style),
        Text('Tinh bột ${formatNumber(m.carb)} g', style: style),
        Text('Béo ${formatNumber(m.fat)} g', style: style),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.glyph, required this.label, required this.onTap});

  final VGlyph glyph;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    child: Pressable(
      onTap: onTap,
      builder: (_) => SizedBox(
        width: 40,
        height: 40,
        child: Center(child: VIcon(glyph, size: 18, color: onTap == null ? V.faint : V.ink)),
      ),
    ),
  );
}
