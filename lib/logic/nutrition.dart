import '../state/prefs_store.dart';

class Macros {
  const Macros({this.kcal = 0, this.protein = 0, this.carb = 0, this.fat = 0});

  final double kcal;
  final double protein;
  final double carb;
  final double fat;

  Macros operator +(Macros o) => Macros(
    kcal: kcal + o.kcal,
    protein: protein + o.protein,
    carb: carb + o.carb,
    fat: fat + o.fat,
  );

  Macros operator *(double k) =>
      Macros(kcal: kcal * k, protein: protein * k, carb: carb * k, fat: fat * k);
}

Macros sumMacros(Iterable<Macros> items) => items.fold(const Macros(), (t, m) => t + m);

/// Activity multiplier for the Mifflin–St Jeor estimate, from training sessions per week.
double activityFactor(int daysPerWeek) {
  if (daysPerWeek <= 1) return 1.2;
  if (daysPerWeek <= 3) return 1.375;
  if (daysPerWeek <= 5) return 1.55;
  return 1.725;
}

double _goalKcal(Goal goal, double tdee) => switch (goal) {
  Goal.lose => tdee - 400,
  Goal.maintain => tdee,
  Goal.gain => tdee + 250,
};

/// Protein per kg of body weight: higher when cutting, to hold on to muscle.
double _proteinPerKg(Goal goal) => switch (goal) {
  Goal.lose => 2.0,
  Goal.maintain => 1.6,
  Goal.gain => 1.8,
};

/// Daily targets from the profile, or null while body data is missing.
/// Energy: Mifflin–St Jeor BMR × activity, adjusted for the goal, never below a safe floor.
/// Fat is 25 % of energy; carbohydrate takes what is left after protein and fat.
Macros? dailyTargets(Profile p, {int? year}) {
  final sex = p.sex, birthYear = p.birthYear, height = p.heightCm, weight = p.weightKg;
  if (sex == null || birthYear == null || height == null || weight == null) {
    return null;
  }
  final age = (year ?? DateTime.now().year) - birthYear;
  final bmr = 10 * weight + 6.25 * height - 5 * age + (sex == Sex.male ? 5 : -161);
  final tdee = bmr * activityFactor(p.daysPerWeek);
  final floor = sex == Sex.male ? 1500 : 1200;
  final kcal = ((_goalKcal(p.goal, tdee) / 10).round() * 10).clamp(floor, 1 << 31).toDouble();
  final protein = (weight * _proteinPerKg(p.goal)).roundToDouble();
  final fat = (kcal * 0.25 / 9).roundToDouble();
  final carb = ((kcal - protein * 4 - fat * 9) / 4).round().clamp(0, 1 << 31).toDouble();
  return Macros(kcal: kcal, protein: protein, carb: carb, fat: fat);
}
