import '../state/log_store.dart';
import 'nutrition.dart';

/// Totals for some meal items, applying each item's servings.
Macros itemsTotals(Iterable<MealItem> items) => sumMacros(
  items.map(
    (i) =>
        Macros(kcal: i.food.kcal, protein: i.food.protein, carb: i.food.carb, fat: i.food.fat) *
        i.servings,
  ),
);

/// Totals for one meal.
Macros mealTotals(LoggedMeal meal) => itemsTotals(meal.items);

/// Meal slot that fits the time of day.
MealSlot slotForTime(DateTime d) {
  final h = d.hour;
  if (h >= 4 && h < 10) return MealSlot.breakfast;
  if (h >= 10 && h < 15) return MealSlot.lunch;
  if (h >= 17 && h < 22) return MealSlot.dinner;
  return MealSlot.snack;
}

/// The slots as the slot picker shows them.
const slotOptions = [
  (MealSlot.breakfast, 'Sáng'),
  (MealSlot.lunch, 'Trưa'),
  (MealSlot.dinner, 'Tối'),
  (MealSlot.snack, 'Phụ'),
];
