import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../app/toast.dart';
import '../logic/format.dart';
import '../state/log_store.dart';
import '../widgets/controls.dart';
import '../widgets/meal_editor.dart';
import 'food/meal_parts.dart';
import 'food/meal_thumb.dart';

/// A saved meal: change portions or the slot (saved as you go), or delete it.
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  /// The meal as it was when deleted here, still shown while the screen slides away.
  LoggedMeal? _leaving;

  void _remove(LoggedMeal meal) {
    final log = context.read<LogStore>();
    setState(() => _leaving = meal);
    final removed = log.removeMeal(meal.id);
    Navigator.of(context).pop();
    if (removed != null) {
      Toast.show(
        context,
        'Đã xoá bữa ăn',
        actionLabel: 'Hoàn tác',
        onAction: () => log.restoreMeal(removed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = context.watch<LogStore>();
    final meal = log.meals.where((m) => m.id == widget.id).firstOrNull ?? _leaving;
    if (meal == null) return const MealMessage('Bữa ăn này đã bị xoá.');
    final label = mealSlotLabel[meal.slot]!;

    return MealScaffold(
      title: label,
      footer: SizedBox(
        height: 50,
        child: GhostButton(
          label: 'Xoá bữa ăn này',
          danger: true,
          expand: true,
          onPressed: () => _remove(meal),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              if (meal.photo != null) ...[
                Semantics(
                  image: true,
                  label: 'Ảnh món ăn đã lưu',
                  child: MealThumb(meal: meal, size: 84, radius: 6),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(label, style: mealTitleStyle)),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: VT.ui(14, color: V.muted),
                        children: [
                          TextSpan(text: '${dayTitle(meal.at)}, '),
                          TextSpan(
                            text: timeText(meal.at),
                            style: VT.mono(13, height: 1.5, color: V.muted),
                          ),
                          if (meal.source == 'demo') const TextSpan(text: ', kết quả mẫu'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        MealEditor(
          items: meal.items,
          onChanged: (items) => log.updateMeal(meal.copyWith(items: items)),
        ),
        const SizedBox(height: 22),
        SlotPicker(
          label: 'Bữa',
          value: meal.slot,
          onChanged: (slot) => log.updateMeal(meal.copyWith(slot: slot)),
        ),
      ],
    );
  }
}
