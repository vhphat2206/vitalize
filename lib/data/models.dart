// Content types, parsed from the JSON assets exported from the web app (tool/export_data.ts).

typedef MuscleId = String;

/// `front` or `back` of the body figure.
typedef BodySide = String;

class Muscle {
  Muscle.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      latin = j['latin'] as String,
      role = j['role'] as String,
      sides = List<String>.from(j['sides'] as List),
      fibre = (j['fibre'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );

  final MuscleId id;

  /// Vietnamese name shown in the UI.
  final String name;

  /// Anatomical (Latin) name, shown as a quiet subtitle.
  final String latin;

  /// What the muscle does, in one plain sentence.
  final String role;

  /// Views of the body where the muscle is drawn and can be tapped.
  final List<BodySide> sides;

  /// Direction the fibres run, degrees, for the shape drawn on the left of the screen in each
  /// view (0 = horizontal, 90 = vertical). The right shape is mirrored.
  final Map<BodySide, double> fibre;
}

class Dose {
  Dose.fromJson(Map<String, dynamic> j)
    : sets = j['sets'] as String,
      target = j['target'] as String,
      unit = j['unit'] as String,
      perSide = j['perSide'] as bool? ?? false,
      rest = j['rest'] as int;

  /// Working sets, e.g. "3" or "3–4".
  final String sets;

  /// Reps or seconds per set, e.g. "8–12".
  final String target;

  /// `reps` or `seconds`.
  final String unit;

  /// The target applies to each side (one arm, one leg).
  final bool perSide;

  /// Rest between sets, seconds.
  final int rest;
}

class Reference {
  Reference.fromJson(Map<String, dynamic> j)
    : title = j['title'] as String,
      source = j['source'] as String,
      url = j['url'] as String;

  /// What the page covers, in Vietnamese.
  final String title;

  /// Publisher and language, e.g. "ACE, tiếng Anh".
  final String source;
  final String url;
}

List<Reference> _refs(Object? list) => [
  for (final r in (list as List?) ?? const []) Reference.fromJson(r as Map<String, dynamic>),
];

class Exercise {
  Exercise.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      nameEn = j['nameEn'] as String,
      equipment = j['equipment'] as String,
      level = j['level'] as int,
      primary = List<String>.from(j['primary'] as List),
      secondary = List<String>.from(j['secondary'] as List),
      dose = Dose.fromJson(j['dose'] as Map<String, dynamic>),
      steps = List<String>.from(j['steps'] as List),
      mistakes = List<String>.from(j['mistakes'] as List),
      note = j['note'] as String?,
      refs = _refs(j['refs']);

  final String id;
  final String name;
  final String nameEn;

  /// barbell, dumbbell, kettlebell, cable, machine, bar or bodyweight.
  final String equipment;

  /// 1 = new to it, 2 = used to it, 3 = advanced.
  final int level;
  final List<MuscleId> primary;
  final List<MuscleId> secondary;
  final Dose dose;
  final List<String> steps;
  final List<String> mistakes;

  /// An easier or safer way in, when there is one worth saying.
  final String? note;

  /// The guides the technique was checked against.
  final List<Reference> refs;
}

class RoutineMove {
  RoutineMove.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      seconds = j['seconds'] as int,
      cue = j['cue'] as String,
      muscles = List<String>.from(j['muscles'] as List);

  /// The exercise this move is, or the warm-up, stretch or cardio move it is.
  final String id;
  final String name;

  /// Work time in seconds.
  final int seconds;

  /// What to do, said the way a coach would say it out loud.
  final String cue;
  final List<MuscleId> muscles;
}

class Routine {
  Routine.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      purpose = j['purpose'] as String,
      equipment = j['equipment'] as String,
      rounds = j['rounds'] as int,
      rest = j['rest'] as int,
      moves = [for (final m in j['moves'] as List) RoutineMove.fromJson(m as Map<String, dynamic>)];

  final String id;
  final String name;

  /// Who it is for and when to do it.
  final String purpose;
  final String equipment;
  final int rounds;

  /// Rest after each move, seconds.
  final int rest;
  final List<RoutineMove> moves;

  /// Total length: every move in every round, with rest after each move except the last.
  int get seconds {
    final perRound = moves.fold(0, (sum, m) => sum + m.seconds);
    final steps = moves.length * rounds;
    return perRound * rounds + rest * (steps - 1);
  }

  List<MuscleId> get muscles => {for (final m in moves) ...m.muscles}.toList();
}

/// A warm-up, stretch or cardio move from the routines that isn't one of the exercises.
class Move {
  Move.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      refs = _refs(j['refs']);

  final String id;
  final String name;
  final List<Reference> refs;
}

/// One anatomical region of the body artwork. `left`/`right` are as drawn on screen.
class BodyPart {
  BodyPart.fromJson(Map<String, dynamic> j)
    : slug = j['slug'] as String,
      common = List<String>.from(j['common'] as List),
      left = List<String>.from(j['left'] as List),
      right = List<String>.from(j['right'] as List);

  final String slug;
  final List<String> common;
  final List<String> left;
  final List<String> right;
}

class BodyView {
  BodyView.fromJson(Map<String, dynamic> j)
    : viewBox = [for (final n in (j['viewBox'] as String).split(RegExp(r'\s+'))) double.parse(n)],
      outline = j['outline'] as String,
      parts = [for (final p in j['parts'] as List) BodyPart.fromJson(p as Map<String, dynamic>)];

  /// x, y, width, height.
  final List<double> viewBox;
  final String outline;
  final List<BodyPart> parts;
}

/// One food in a meal, per the analysed portion.
class FoodItem {
  const FoodItem({
    required this.name,
    required this.portion,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  FoodItem.fromJson(Map<String, dynamic> j)
    : name = j['name'] as String,
      portion = j['portion'] as String,
      grams = (j['grams'] as num).toDouble(),
      kcal = (j['kcal'] as num).toDouble(),
      protein = (j['protein'] as num).toDouble(),
      carb = (j['carb'] as num).toDouble(),
      fat = (j['fat'] as num).toDouble();

  final String name;

  /// How much, in words: "1 tô vừa".
  final String portion;
  final double grams;
  final double kcal;
  final double protein;
  final double carb;
  final double fat;

  Map<String, dynamic> toJson() => {
    'name': name,
    'portion': portion,
    'grams': grams,
    'kcal': kcal,
    'protein': protein,
    'carb': carb,
    'fat': fat,
  };
}
