import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/haptics.dart';
import '../app/theme.dart';
import '../app/toast.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../logic/format.dart';
import '../logic/meals.dart';
import '../logic/search.dart';
import '../state/log_store.dart';
import '../widgets/controls.dart';
import '../widgets/icons.dart';
import '../widgets/meal_editor.dart';
import '../widgets/pressable.dart';
import 'food/meal_parts.dart';

/// Add a meal by hand: search the common foods, tap to add, adjust the portions, pick the slot,
/// save. Saved meals have the source `manual`.
class FoodPickScreen extends StatefulWidget {
  const FoodPickScreen({super.key});

  @override
  State<FoodPickScreen> createState() => _FoodPickScreenState();
}

class _FoodPickScreenState extends State<FoodPickScreen> {
  final _query = TextEditingController();
  List<MealItem> _items = [];
  MealSlot _slot = slotForTime(DateTime.now());

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// A food tapped again gets half a serving more instead of a second row.
  void _add(FoodItem food) {
    final i = _items.indexWhere((it) => it.food.name == food.name);
    setState(() {
      _items = i < 0
          ? [..._items, MealItem(food: food)]
          : [
              for (final (j, it) in _items.indexed)
                j == i ? it.withServings(it.servings + 0.5) : it,
            ];
    });
    Haptics.tick();
  }

  void _save() {
    final log = context.read<LogStore>();
    final meal = log.addMeal(slot: _slot, items: _items, source: 'manual');
    Haptics.success();
    Toast.show(
      context,
      'Đã lưu ${mealSlotLabel[_slot]!.toLowerCase()}, ${formatNumber(mealTotals(meal).kcal)} kcal',
      actionLabel: 'Hoàn tác',
      onAction: () => log.removeMeal(meal.id),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final found = [
      for (final f in catalog.foods)
        if (query.isEmpty || matchesVi(f.name, query)) f,
    ];
    return MealScaffold(
      title: 'Thêm món',
      footer: _items.isEmpty
          ? null
          : PrimaryButton(
              label: 'Lưu vào ${mealSlotLabel[_slot]!.toLowerCase()}',
              onPressed: _save,
            ),
      children: [
        Text('Bạn đã ăn gì?', style: mealTitleStyle),
        const SizedBox(height: 16),
        _SearchBox(controller: _query, onChanged: () => setState(() {})),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 24),
          MealEditor(items: _items, onChanged: (items) => setState(() => _items = items)),
          const SizedBox(height: 22),
          SlotPicker(label: 'Lưu vào', value: _slot, onChanged: (s) => setState(() => _slot = s)),
        ],
        const SizedBox(height: 26),
        SectionTitle(query.isEmpty ? 'Món thường gặp' : 'Kết quả cho "$query"'),
        if (found.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('Chưa có món này trong danh sách.', style: VT.ui(14.5, color: V.muted)),
          ),
        for (final f in found) _FoodOption(food: f, onTap: () => _add(f)),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = VT.ui(17, weight: FontWeight.w500, height: 1);
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(V.rControl),
      borderSide: BorderSide(color: color, width: width),
      gapPadding: 0,
    );
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: text,
      decoration: InputDecoration(
        hintText: 'Tìm món: phở, ức gà, chuối…',
        hintStyle: text.copyWith(color: V.faint),
        filled: true,
        fillColor: V.bg3,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18.5),
        enabledBorder: ring(V.lineStrong, 1),
        focusedBorder: ring(V.accent, 1.5),
      ),
    );
  }
}

/// One food in the list: name and portion, its energy, and a plus.
class _FoodOption extends StatelessWidget {
  const _FoodOption({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Thêm ${food.name}',
    excludeSemantics: true,
    child: Pressable(
      onTap: onTap,
      builder: (pressed) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: pressed ? V.bg3 : const Color(0x00000000),
          border: const Border(bottom: BorderSide(color: V.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: VT.ui(16, weight: FontWeight.w500, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(food.portion, style: VT.ui(13.5, color: V.muted)),
                ],
              ),
            ),
            Text('${formatNumber(food.kcal)} kcal', style: VT.mono(13.5, color: V.muted)),
            const SizedBox(width: 12),
            const VIcon(VIcons.plus, size: 20, color: V.accent),
          ],
        ),
      ),
    ),
  );
}
